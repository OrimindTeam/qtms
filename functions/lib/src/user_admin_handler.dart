/// تنفيذ عمليات إدارة المستخدمين والأدوار — **الطرف الذي يلمس الشبكة**.
///
/// ★ **مفصول عن `user_admin.dart` عمداً**، بنفس منطق
/// `permission_sync_handler.dart`: كل قرار تفويض هناك في دوال خالصة تُختبَر
/// بلا سحابة؛ وهنا **الترتيب والأثر** وحدهما.
///
/// ★★ **وترتيب الأثر مقصود ولا يُعكَس — ويختلف باختلاف اتجاه الخطر:**
///
/// | العملية | الترتيب | لماذا هذا الاتجاه بالذات |
/// |---|---|---|
/// | **الإنشاء** | ① الحساب في الخدمة ② المعاملة (البطاقة والقيد) | **المعرّف يأتي من الخدمة**، فلا بطاقة بلا حساب. ⚠️ وفشل ② يترك حساباً **بلا بطاقة** ⟵ ★ **وهو بلا صلاحية إطلاقاً** (`ADR-0016`) — **خللٌ في الاتجاه الآمن** |
/// | **التعديل وكتابة الدور** | ① المعاملة وحدها | لا أثر على الخدمة أصلاً |
/// | **التعطيل** | ① المعاملة ② تعطيل الحساب في الخدمة | ⚠️ فشل ② يترك المستخدم **معطَّلاً في البطاقة نافذاً في الخدمة** — ⟵ ★ **والقاعدة تمنعه فوراً** (`perm()` تشترط `isActive`)، **فالمنع نافذ والنقص في إبطال الرمز وحده** |
///
/// ⛔★★ **ولا يُعكَس ترتيب التعطيل بحال:** لو عُطِّل الحساب في الخدمة أولاً
/// ثم فشلت المعاملة، **لَبقيت البطاقة `isActive: true` بلا قيد تدقيق**
/// ⟵ **تعطيلٌ وقع ولا أثر له في السجل**، وهو ما يمنعه `BR-M18-03`.
library;

import 'package:qtms_domain/qtms_domain.dart';
import 'package:shelf/shelf.dart';

import 'audited_transaction.dart';
import 'callable.dart';
import 'identity_gateway.dart';
import 'permission_sync.dart' show usersCollection;
import 'permission_sync_handler.dart';
import 'user_admin.dart';

/// اسم حقل سبب التعطيل في الحمولة.
const String disableReasonField = 'reason';

/// ★★ اسم حقل **سبب التعديل** في الحمولة — `ADR-0004` · `DEBT-21` ①.
///
/// ⚠️ **ومنفصل عن [disableReasonField] عمداً:** ذاك سبب **تعطيل حساب**
/// يُخزَّن في `disableReason` بالبطاقة ويُقرأ للمستخدم المعطَّل، وهذا سبب
/// **تعديل** يعيش في قيد التدقيق وحده. ⟵ **ودمجُهما يخلط سياقين.**
const String amendReasonField = 'amendReason';

/// منفّذ عمليات الإدارة.
final class UserAdminHandler {
  /// ينشئ المنفّذ بتبعياته — ★ **تُحقَن، فيُختبَر بلا سحابة**.
  const UserAdminHandler({
    required IdentityGateway identity,
    required AuditedTransaction transaction,
    required String ownerUserId,
  })  : _identity = identity,
        _transaction = transaction,
        _ownerUserId = ownerUserId;

  final IdentityGateway _identity;
  final AuditedTransaction _transaction;

  /// ★ **من إعداد البيئة لا من الحمولة** — راجع [UserAdminRequest.ownerUserId].
  final String _ownerUserId;

  /// ينفّذ [operation] على طلب HTTP خام.
  Future<Response> handle(
    Request httpRequest,
    UserAdminOperation operation,
  ) async {
    final CallableParse parsed = await parseCallableRequest(httpRequest);
    if (parsed is RejectedCallable) return callableFailure(parsed.error);
    final CallableRequest call = (parsed as ParsedCallable).request;

    try {
      return await _execute(call, operation);
    } on IdentityGatewayException catch (error) {
      return callableFailure(
        _mapIdentityFailure(error),
        detail: error.diagnostic,
      );
    } on TransactionContentionException catch (error) {
      // ⛔ ليس ابتلاعاً: يصل المستخدم رمز تعارض صريح فيُعيد المحاولة.
      return callableFailure(CallableError.concurrency, detail: '$error');
    }
  }

  Future<Response> _execute(
    CallableRequest call,
    UserAdminOperation operation,
  ) async {
    final AccountRecord actor = await _identity.verifyIdToken(call.idToken);
    final String? requestId = call.readString(requestIdField);
    if (requestId == null) {
      return callableFailure(CallableError.invalidArgument);
    }

    return switch (operation) {
      UserAdminOperation.createUser => await _create(call, actor, requestId),
      UserAdminOperation.updateUser =>
        await _profileWrite(call, actor, requestId, operation),
      UserAdminOperation.disableUser => await _disable(call, actor, requestId),
      UserAdminOperation.createRole ||
      UserAdminOperation.updateRole =>
        await _role(call, actor, requestId, operation),
      UserAdminOperation.deleteRole =>
        await _deleteRole(call, actor, requestId),
    };
  }

  // ═════════════════════════════════════════════════════════════════════
  // الإنشاء
  // ═════════════════════════════════════════════════════════════════════

  Future<Response> _create(
    CallableRequest call,
    AccountRecord actor,
    String requestId,
  ) async {
    final Outcome<ValidatedUserProfile> validated = _readProfile(call);
    if (validated is Failure<ValidatedUserProfile>) {
      return callableFailure(CallableError.invalidArgument);
    }
    final ValidatedUserProfile profile =
        (validated as Success<ValidatedUserProfile>).value;

    // ★★ **التفويض يُفحَص قبل إنشاء الحساب** — ⛔ ولا يُنشأ حسابٌ ثم يُرفَض
    //    الطلب، وإلا تراكمت حسابات يتيمة في خدمة المصادقة يُنشئها من لا
    //    يملك `userCreate` أصلاً. ⟵ **ولذلك يُخطَّط بمعرّف مؤقت أولاً.**
    final UserAdminPlan gate = planUserAdmin(
      _request(
        actor: actor,
        // ⚠️ المعرّف الحقيقي لم يوجد بعد — والتخطيط هنا **لفحص البوابة**،
        //    ويُعاد بالمعرّف الحقيقي بعد الإنشاء.
        targetId: _pendingTargetId,
        requestId: requestId,
        profile: profile,
      ),
      UserAdminOperation.createUser,
    );
    if (gate case UserAdminRejected(:final CallableError error)) {
      return callableFailure(error);
    }

    final String userId = await _identity.createAccount(
      email: profile.email,
      displayName: profile.name,
    );

    final UserAdminPlan plan = planUserAdmin(
      _request(
        actor: actor,
        targetId: userId,
        requestId: requestId,
        profile: profile,
      ),
      UserAdminOperation.createUser,
    );
    if (plan case UserAdminRejected(:final CallableError error)) {
      return callableFailure(error);
    }

    await _commit(plan as UserAdminAccepted);

    // ★ **ثم يضبط صاحبُه كلمتَه** — `authentication-policy.md` §5.
    //   ⛔ **ولا يُرجَع الرابط للمُستدعي:** «الإدارة تُعيد التعيين لا تقرأ».
    //   ⚠️ **وفشل الإرسال لا يُبطل الإنشاء:** الحساب والبطاقة قائمان فعلاً،
    //      ⟵ **وإعادة الإرسال إجراء مستقل** — أما التراجع فيحذف حساباً،
    //      **والحذف ممنوع** (`FR-M1-12`).
    await _identity.sendPasswordSetupLink(email: profile.email);

    return callableSuccess(<String, Object?>{
      'userId': userId,
      // ★ **ولا صلاحية له بعد** — المنح مسارُه `grantPermissions` بقواعده.
      'permissionsGranted': false,
      'passwordSetupLinkSent': true,
    });
  }

  // ═════════════════════════════════════════════════════════════════════
  // التعديل · التعطيل · الأدوار
  // ═════════════════════════════════════════════════════════════════════

  Future<Response> _profileWrite(
    CallableRequest call,
    AccountRecord actor,
    String requestId,
    UserAdminOperation operation,
  ) async {
    final String? targetUserId = call.readString(targetUserIdField);
    if (targetUserId == null) {
      return callableFailure(CallableError.invalidArgument);
    }
    final Outcome<ValidatedUserProfile> validated = _readProfile(call);
    if (validated is Failure<ValidatedUserProfile>) {
      return callableFailure(CallableError.invalidArgument);
    }

    final UserAdminPlan plan = planUserAdmin(
      _request(
        actor: actor,
        targetId: targetUserId,
        requestId: requestId,
        profile: (validated as Success<ValidatedUserProfile>).value,
        amendReason: call.readString(amendReasonField),
      ),
      operation,
    );
    return switch (plan) {
      UserAdminRejected(:final CallableError error) => callableFailure(error),
      UserAdminAccepted() => await _commitAndReport(plan, targetUserId),
    };
  }

  Future<Response> _disable(
    CallableRequest call,
    AccountRecord actor,
    String requestId,
  ) async {
    final String? targetUserId = call.readString(targetUserIdField);
    final String? reason = call.readString(disableReasonField);
    if (targetUserId == null || reason == null) {
      return callableFailure(CallableError.invalidArgument);
    }

    // ★ **قواعد التعطيل من طبقة النطاق** — ⛔ ولا تُعاد كتابتها هنا.
    final Outcome<ValidatedUserDisable> validated = validateUserDisable(
      UserDisableRequest(
        actorUserId: actor.userId,
        targetUserId: targetUserId,
        ownerUserId: _ownerUserId,
        reason: reason,
      ),
    );
    if (validated is Failure<ValidatedUserDisable>) {
      // ★ رفضُ قاعدةِ عملٍ **صلاحيةً لا خللَ مدخلات** — فالطلب سليم البنية
      //   وإنما يخالف `FR-M1-12` أو `BR-M1-02`.
      return callableFailure(CallableError.permissionMissing);
    }

    final UserAdminPlan plan = planUserAdmin(
      _request(
        actor: actor,
        targetId: targetUserId,
        requestId: requestId,
        disableReason:
            (validated as Success<ValidatedUserDisable>).value.reason,
      ),
      UserAdminOperation.disableUser,
    );
    return switch (plan) {
      UserAdminRejected(:final CallableError error) => callableFailure(error),
      UserAdminAccepted() => await _commitAndReport(plan, targetUserId),
    };
  }

  Future<Response> _role(
    CallableRequest call,
    AccountRecord actor,
    String requestId,
    UserAdminOperation operation,
  ) async {
    final String? roleId = call.readString('roleId');
    final String? name = call.readString('name');
    if (roleId == null || name == null) {
      return callableFailure(CallableError.invalidArgument);
    }
    // ★★ **قالب الصلاحيات صارم كصرامة المنح** — ⛔ **مفتاح مجهول يُبطل
    //   الطلب كله**: تخزينُ مفتاحٍ لا سطر له في الكتالوج هو ما يرفضه
    //   `BR-M1-07` نصّاً، ⟵ **ولا فرق بين قالبٍ وبطاقةٍ في هذا.**
    final Set<Permission>? template = _readTemplate(call);
    if (template == null) {
      return callableFailure(CallableError.invalidArgument);
    }
    final Outcome<ValidatedRole> validated = validateRole(
      name: name,
      description: call.readString('description'),
      permissions: template,
    );
    if (validated is Failure<ValidatedRole>) {
      return callableFailure(CallableError.invalidArgument);
    }

    final UserAdminPlan plan = planUserAdmin(
      _request(
        actor: actor,
        targetId: roleId,
        requestId: requestId,
        roleName: (validated as Success<ValidatedRole>).value,
        amendReason: call.readString(amendReasonField),
      ),
      operation,
    );
    return switch (plan) {
      UserAdminRejected(:final CallableError error) => callableFailure(error),
      UserAdminAccepted() => await _commitAndReport(plan, roleId),
    };
  }

  // ═════════════════════════════════════════════════════════════════════
  // ★★ حذف الدور — `IQ-018` (الخيار ب)
  // ═════════════════════════════════════════════════════════════════════

  /// ★★ **يحذف دوراً غير مُسنَد حذفاً فعلياً** — `IQ-018` · `FR-M1-03`.
  ///
  /// **ترتيب مقصود من ثلاث مراحل، ولا يُعكَس:**
  ///
  /// ① ★ **البوابة قبل المعاملة** — نقصُ `roleDelete` يُرفَض **بلا فتح
  ///    معاملة**، ⟵ **فلا أقفال تُحجَز لطلبٍ مرفوض أصلاً.**
  ///
  /// ② ★★ **القراءة والاستعلام داخل المعاملة معاً** — وهذا **جوهر حسم
  ///    `IQ-018`**: «يتحقق **فعلياً** من عدم وجود أي مستخدم يشير إلى
  ///    `roleId` … **ولا يعتمد على قيمة مخزنة أو افتراض محلي**». ⟵
  ///    **فالاستعلام على `users` يجري في المعاملة نفسها التي تحذف**،
  ///    ⛔ **لا قبلها بلقطةٍ تُصبح قديمة.**
  ///
  /// ③ **الحذف والقيد في التزام واحد** — `ADR-0013` القاعدة 1.
  ///
  /// ⚠️⚠️ **ونافذة تزامن معلَنة لا مُنكَرة** (`DEBT-23`): قواعد Firestore
  /// تُبطل المعاملة إذا **تغيّر مستندٌ قرأته**، ⛔ **لكنها لا تحجز مستنداً
  /// لم يوجد بعد**. ⟵ **فإسنادُ الدور لمستخدمٍ في اللحظة نفسها قد لا
  /// يُبطل هذا الحذف.** ★ **والأثر محدود ومعروف** — يبقى المستخدم بمرجع
  /// دورٍ محذوف، **وتعرضه الواجهة «بلا دور»** ⛔ ولا يفقد صلاحية واحدة
  /// (الصلاحيات في بطاقته لا في الدور — `ADR-0016`).
  Future<Response> _deleteRole(
    CallableRequest call,
    AccountRecord actor,
    String requestId,
  ) async {
    final String? roleId = call.readString('roleId');
    if (roleId == null) {
      return callableFailure(CallableError.invalidArgument);
    }

    // ① البوابة — ⛔ قبل أي معاملة.
    final UserAdminRequest gateRequest = _request(
      actor: actor,
      targetId: roleId,
      requestId: requestId,
      amendReason: call.readString(amendReasonField),
    );
    final UserAdminRejected? gate =
        userAdminGate(gateRequest, UserAdminOperation.deleteRole);
    if (gate != null) return callableFailure(gate.error);

    final String rolePath =
        _transaction.documentPath(rolesCollection, roleId);
    try {
      // ② + ③ — القراءة والاستعلام والحذف والقيد في معاملة واحدة.
      await _transaction.run<void>(
        readPaths: <String>[rolePath],
        queries: <DocumentQuery>[
          DocumentQuery(
            key: _assignedQueryKey,
            collectionId: usersCollection,
            fieldPath: userRoleIdField,
            equalTo: roleId,
            // ★ **السؤال «هل يوجد» لا «كم عددهم»** — والمُسنَد لواحدٍ
            //   والمُسنَد لعشرة **مرفوضان سواءً بسواء** (`FR-M1-03`).
            limit: 1,
          ),
        ],
        plan: (TransactionReads reads) {
          final UserAdminPlan plan = planUserAdmin(
            _request(
              actor: actor,
              targetId: roleId,
              requestId: requestId,
              amendReason: call.readString(amendReasonField),
              // ★★ **من الاستعلام الفعلي** — ⛔ لا من الحمولة ولا من كاش.
              roleAssignment: RoleAssignmentCensus.measured(
                reads.matches(_assignedQueryKey),
              ),
              roleBefore: reads.document(rolePath),
            ),
            UserAdminOperation.deleteRole,
          );
          if (plan case UserAdminRejected(:final CallableError error)) {
            // ★ **الرفض بعد القراءة يُبطل المعاملة صراحةً** — ⛔ ولا يكتب
            //   شيئاً، **ولا يُترك المعاملة معلَّقة** (راجع [AbortTransaction]).
            throw AbortTransaction(error);
          }
          return _writeOf(plan as UserAdminAccepted);
        },
      );
    } on AbortTransaction catch (aborted) {
      return callableFailure(aborted.reason as CallableError);
    }

    return callableSuccess(<String, Object?>{
      'roleId': roleId,
      // ★ **حُذف فعلاً** — ⛔ ولا «عُطِّل»: `IQ-018` يمنع تحويل الحذف تعطيلاً.
      'deleted': true,
      'tokenRefreshRequired': false,
    });
  }

  /// يقرأ قالب الصلاحيات من الحمولة — ⛔ **ومفتاح مجهول يُبطل الطلب**.
  ///
  /// ★ **والغياب قالبٌ فارغ لا رفض** — `FR-M1-04`: «الأدوار قوالب بداية لا
  /// قيود»، ⟵ **فدورٌ بلا صلاحيات دورُ بدايةٍ صحيح.**
  static Set<Permission>? _readTemplate(CallableRequest call) {
    final Object? raw = call.data[rolePermissionTemplateField];
    if (raw == null) return const <Permission>{};
    final List<String>? names =
        call.readStringList(rolePermissionTemplateField);
    if (names == null) return null;
    final Set<Permission> template = <Permission>{};
    for (final String name in names) {
      final Permission? key = _permissionByName(name);
      if (key == null) return null;
      template.add(key);
    }
    return template;
  }

  static Permission? _permissionByName(String name) {
    for (final Permission p in Permission.values) {
      if (p.name == name) return p;
    }
    return null;
  }

  /// مفتاح استعلام «من يشير إلى هذا الدور».
  static const String _assignedQueryKey = 'assignedUsers';

  // ═════════════════════════════════════════════════════════════════════
  // الأثر
  // ═════════════════════════════════════════════════════════════════════

  Future<Response> _commitAndReport(
    UserAdminAccepted plan,
    String targetId,
  ) async {
    await _commit(plan);

    // ★★ **بعد المعاملة لا قبلها** — راجع ترويسة الملف.
    if (plan.setAccountDisabled == true) {
      await _identity.setAccountDisabled(userId: targetId, disabled: true);
    }

    return callableSuccess(<String, Object?>{
      'id': targetId,
      // ★★ `ADR-0016`: الصلاحيات تسري فوراً، **والنطاق وحده في الرمز** —
      //   وهذه العمليات ⛔ **لا تمسّ النطاق إطلاقاً**، فلا تحديث لازم.
      'tokenRefreshRequired': false,
    });
  }

  Future<void> _commit(UserAdminAccepted plan) => _transaction.run<void>(
        // ⛔ لا قراءات: القيم «قبل» تأتي من خدمة المصادقة لا من الدفتر.
        readPaths: const <String>[],
        plan: (TransactionReads reads) => _writeOf(plan),
      );

  /// يحوّل خطة مقبولة إلى كتابة ذرّية — **كتابةً أو حذفاً**.
  static AuditedWrite<void> _writeOf(UserAdminAccepted plan) =>
      AuditedWrite<void>(
        documents: plan.deletesDocument
            ? const <PendingDocument>[]
            : <PendingDocument>[
                PendingDocument(
                  collectionId: plan.collectionId,
                  documentId: plan.documentId,
                  fields: plan.fields,
                  updateMask: plan.updateMask,
                ),
              ],
        // ★★ **الحذف والقيد في المعاملة نفسها** (`ADR-0013` القاعدة 1).
        deletions: plan.deletesDocument
            ? <PendingDeletion>[
                PendingDeletion(
                  collectionId: plan.collectionId,
                  documentId: plan.documentId,
                ),
              ]
            : const <PendingDeletion>[],
        entry: plan.entry,
        result: null,
      );

  UserAdminRequest _request({
    required AccountRecord actor,
    required String targetId,
    required String requestId,
    ValidatedUserProfile? profile,
    String? disableReason,
    String? amendReason,
    ValidatedRole? roleName,
    RoleAssignmentCensus? roleAssignment,
    Map<String, Object?>? roleBefore,
  }) =>
      UserAdminRequest(
        actor: actor,
        targetId: targetId,
        requestId: requestId,
        ownerUserId: _ownerUserId,
        profile: profile,
        disableReason: disableReason,
        amendReason: amendReason,
        roleName: roleName,
        roleAssignment: roleAssignment,
        roleBefore: roleBefore,
        targetIsOwner: targetId == _ownerUserId.trim(),
      );

  /// ★ معرّف نائب **لفحص البوابة قبل إنشاء الحساب** — ⛔ ولا يُكتب أبداً.
  ///
  /// ⚠️ **ولماذا ليس فارغاً:** الفحص ④ في `_gate` يرفض المعرّف الفارغ،
  /// ⟵ فلو مُرِّر الفراغ لَرُفض كل إنشاء **برمز مدخلاتٍ مضلِّل** بدل أن
  /// يُفحَص التفويضُ فعلاً.
  static const String _pendingTargetId = 'pending';

  static CallableError _mapIdentityFailure(IdentityGatewayException error) =>
      switch (error.failure) {
        IdentityFailure.invalidToken => CallableError.sessionExpired,
        IdentityFailure.accountNotFound => CallableError.invalidArgument,
        IdentityFailure.claimsTooLarge => CallableError.internal,
        // ★ `ERR_SETUP_011` — `FR-M1-01`: البريد فريد.
        IdentityFailure.emailAlreadyExists => CallableError.emailAlreadyExists,
      };

  /// يقرأ ملف المستخدم من الحمولة **ويمرّره على قواعد طبقة النطاق**.
  ///
  /// ★★ **و`extraFields` تحمل كل مفاتيح الحمولة** — ⟵ **فحقلٌ ممنوع
  /// (`password` · `deviceId`) يُرفَض الطلبُ به** (`FR-M1-02`)، ⛔ **ولا
  /// يُتجاهَل بصمت** فيظنّ المُرسِل أنه حُفظ.
  static Outcome<ValidatedUserProfile> _readProfile(CallableRequest call) =>
      validateUserProfile(
        UserProfileInput(
          name: call.readString('name') ?? '',
          email: call.readString('email') ?? '',
          phone: call.readString('phone'),
          roleId: call.readString('roleId'),
          extraFields: call.data.keys.toSet(),
        ),
      );
}

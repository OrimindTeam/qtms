/// مزامن الصلاحيات — **التخطيط الخالص** لعمليتي `grantPermissions`
/// و`setSourceScope`.
///
/// ★ **لماذا مفصولة عن الشبكة:** `ADR-0013` القاعدة 3 تجعل **فحص التفويض في
/// الكود** هو الحارس الوحيد لهذا المسار (فالدالة تعمل بامتياز إداري يتجاوز
/// قواعد الحماية). ★ **وحارسٌ لا يُختبَر بلا سحابة حارسٌ غير مُختبَر** — فكل
/// القرار هنا **دالة خالصة** تُشغَّل في اختبار وحدة عادي.
///
/// ⚠️ **وهذا بالضبط الأثر السلبي المعلَن في `ADR-0013`:** «كل قاعدة تفويض
/// تصير مكتوبة مرتين … **ويُلزم بمجموعة اختبارات تُشغَّل على الاثنين معاً**».
/// ★ **ولذلك لا تُعاد كتابة قواعد المنح هنا** — تُستدعى من طبقة النطاق
/// (`validatePermissionGrant`)، وهي نفسها التي يستدعيها التطبيق.
library;

import 'package:qtms_domain/qtms_domain.dart';

import 'callable.dart';
import 'identity_claims.dart';
import 'identity_gateway.dart';

/// اسم مجموعة المستخدمين — `data-dictionary.md` §1.
const String usersCollection = 'users';

/// حقل الصلاحيات في بطاقة المستخدم.
const String permissionsField = 'permissions';

/// حقل نطاق المصادر في بطاقة المستخدم.
const String sourceScopeField = 'sourceScope';

/// ★★ حقل حالة الحساب في البطاقة — `data-dictionary.md` §`users`.
///
/// ★ **ولماذا يُكتب في كل عملية تكتب `permissions` (`IQ-017`):** بعد أن صارت
/// `perm()` في `firestore.rules` تشترط `isActive == true`، **صارت بطاقةٌ
/// تحمل صلاحيات بلا هذا الحقل بطاقةً بلا صلاحية إطلاقاً**. ⟵ ⛔ **فلا يُكتب
/// `permissions` بدونه أبداً**، وإلا مَنَحَت العمليةُ صلاحيةً لا تسري.
const String userIsActiveField = 'isActive';

/// طلب مزامنة صلاحيات مُتحقَّق من هويتَي طرفيه.
final class PermissionSyncRequest {
  /// ينشئ الطلب.
  const PermissionSyncRequest({
    required this.actor,
    required this.target,
    required this.desired,
    required this.requestId,
    this.deviceInfo,
  });

  /// المُنفِّذ **بحالته الآن من خدمة المصادقة** لا من الرمز الذي أرسله.
  final AccountRecord actor;

  /// المستخدم المستهدَف.
  final AccountRecord target;

  /// الحالة المطلوبة بعد العملية.
  final DesiredAccess desired;

  /// ★ **معرّف مُولَّد على الجهاز** — «يمنع الازدواج عند إعادة الإرسال»
  /// (`api-overview.md` §4). وهو **معرّف قيد التدقيق نفسه**، فإعادة إرسال
  /// الطلب ذاته **تكتب فوق القيد نفسه ولا تُنشئ ثانياً**.
  final String requestId;

  /// وصف الجهاز للسجل — ⛔ بلا بيانات حساسة.
  final String? deviceInfo;
}

/// الحالة المطلوبة: صلاحيات ونطاق.
final class DesiredAccess {
  /// ينشئ الحالة المطلوبة.
  const DesiredAccess({required this.permissions, required this.scope});

  /// الصلاحيات المطلوب أن يملكها المستهدَف بعد العملية.
  final Set<Permission> permissions;

  /// النطاق المطلوب.
  final SourceScope scope;
}

/// نتيجة التخطيط — إما خطة كتابة وإما رفض مصنَّف.
sealed class PermissionSyncPlan {
  const PermissionSyncPlan();
}

/// رُفض الطلب قبل أي كتابة.
final class PermissionSyncRejected extends PermissionSyncPlan {
  /// ينشئ رفضاً.
  const PermissionSyncRejected(this.error);

  /// رمز الرفض من كتالوج الأخطاء.
  final CallableError error;
}

/// قُبل الطلب — وهذه حقوله وقيده ومطالباته.
final class PermissionSyncAccepted extends PermissionSyncPlan {
  /// ينشئ خطة مقبولة.
  const PermissionSyncAccepted({
    required this.userFields,
    required this.updateMask,
    required this.entry,
    required this.claims,
  });

  /// حقول بطاقة المستخدم المتغيّرة وحدها.
  final Map<String, Object?> userFields;

  /// ★ **قناع الكتابة** — ⛔ وبدونه تُمحى بقية حقول البطاقة (الاسم والبريد).
  final List<String> updateMask;

  /// قيد التدقيق المقابل — **يُكتب في المعاملة نفسها** (`ADR-0013` القاعدة 1).
  final AuditEntry entry;

  /// المطالبات التي ستُكتب في الرمز **بعد نجاح المعاملة**.
  final IdentityClaims claims;
}

/// نوع عملية المزامنة — يحدد الصلاحية المطلوبة وما يُكتب.
enum PermissionSyncOperation {
  /// `grantPermissions` — يشترط `permissionGrant` (`api-overview.md` §3.1).
  grantPermissions(Permission.permissionGrant),

  /// `setSourceScope` — يشترط `sourceScopeSet`، ★ **أخطر صلاحية في النظام**.
  setSourceScope(Permission.sourceScopeSet);

  const PermissionSyncOperation(this.requiredPermission);

  /// الصلاحية التي لا تُنفَّذ العملية بدونها.
  final Permission requiredPermission;
}

/// يخطّط عملية مزامنة — **دالة خالصة، وهي حارس التفويض الفعلي**.
///
/// ★ **ترتيب الفحوص مقصود** ويطابق ترتيب `validatePermissionGrant` في طبقة
/// النطاق: الحالة قبل الصلاحية، والصلاحية قبل محتوى الطلب — فلا يُفحَص محتوى
/// طلبٍ مرفوضٍ أصلاً.
PermissionSyncPlan planPermissionSync(
  PermissionSyncRequest request,
  PermissionSyncOperation operation,
) {
  final PermissionSyncRejected? gate = _gate(request, operation);
  if (gate != null) return gate;

  // ★ **قواعد المنح نفسها من طبقة النطاق لا من هنا** — نسختان تفترقان.
  //   ⚠️ ونطاق المُنفِّذ مضمون غير فارغ هنا: `_gate` يرفض من لا نطاق له.
  final Outcome<ApprovedGrant> validated = validatePermissionGrant(
    PermissionGrantRequest(
      actorUserId: request.actor.userId,
      actorPermissions: request.actor.claims.permissions,
      actorScope: request.actor.claims.sourceScope!,
      targetUserId: request.target.userId,
      requestedPermissions: request.desired.permissions,
      requestedScope: request.desired.scope,
    ),
  );
  return switch (validated) {
    Failure<ApprovedGrant>() =>
      PermissionSyncRejected(_classifyRejection(request)),
    Success<ApprovedGrant>(:final ApprovedGrant value) =>
      _buildPlan(request, operation, value),
  };
}

/// فحوص الحالة والصلاحية — ما يسبق محتوى الطلب.
PermissionSyncRejected? _gate(
  PermissionSyncRequest request,
  PermissionSyncOperation operation,
) {
  // ① «التعطيل فوري ونافذ» — `authentication-policy.md` §2 القاعدة 3.
  if (request.actor.disabled) {
    return const PermissionSyncRejected(CallableError.accountDisabled);
  }
  // ② الصلاحية الإدارية — `IQ-007` · الكتالوج §2.10.
  //    ⛔ ولا قاعدة حماية تحرس هذا؛ هذا السطر **هو** الحارس (`ADR-0013` ③).
  if (!request.actor.claims.has(operation.requiredPermission)) {
    return const PermissionSyncRejected(CallableError.permissionMissing);
  }
  // ③ ★ ولا يمنح من لا نطاق له أصلاً.
  //    ⚠️ حالةٌ حقيقية لا نظرية: **حساب المالك الأول قائم بلا صلاحيات ولا
  //    نطاق** حتى يمرّ بإجراء الإقلاع (`IQ-007`). وطبقة النطاق لا تُعبِّر عن
  //    «لا نطاق» أصلاً — `ScopedSources` يرفض القائمة الفارغة عمداً — فيُحسَم
  //    هنا بالمنع، وهو الافتراض الآمن.
  if (request.actor.claims.sourceScope == null) {
    return const PermissionSyncRejected(CallableError.permissionMissing);
  }
  // ④ معرّف الطلب إلزامي — وبدونه لا تتحقق اللاتكرارية عند إعادة الإرسال.
  if (request.requestId.trim().isEmpty) {
    return const PermissionSyncRejected(CallableError.invalidArgument);
  }
  return null;
}

/// يصنّف سبب رفض طبقة النطاق **للإبلاغ فقط** — ⛔ لا لإعادة الفحص.
///
/// ⚠️ **التمييز مقصود:** الحكم صدر في طبقة النطاق وحدها؛ وهذا يقرأ الشروط
/// نفسها ليختار **رمز الكتالوج المناسب** فقط. ولو انقلبت نتيجته لما غيّر
/// الرفضَ بل الرمزَ وحده.
CallableError _classifyRejection(PermissionSyncRequest request) {
  if (request.actor.userId == request.target.userId) {
    // «لا مستخدم يعدّل صلاحيات نفسه — ولو المالك» (`authentication-policy` §3).
    return CallableError.permissionMissing;
  }
  final bool beyond = request.desired.permissions
      .difference(request.actor.claims.permissions)
      .isNotEmpty;
  if (beyond) return CallableError.grantBeyondActor;
  // ما بقي توسيع نطاق فوق نطاق المُنفِّذ — `FR-M1-08`.
  return CallableError.sourceOutOfScope;
}

PermissionSyncAccepted _buildPlan(
  PermissionSyncRequest request,
  PermissionSyncOperation operation,
  ApprovedGrant approved,
) {
  final bool scopeOnly = operation == PermissionSyncOperation.setSourceScope;
  final IdentityClaims before = request.target.claims;
  final IdentityClaims after = IdentityClaims(
    permissions: scopeOnly ? before.permissions : approved.permissions,
    sourceScope: approved.scope,
    roleId: before.roleId,
  );

  final Map<String, Object?> changedAfter = <String, Object?>{
    if (!scopeOnly) permissionsField: _permissionMap(after.permissions),
    sourceScopeField: encodeScopeForStorage(after.sourceScope!),
  };
  final Map<String, Object?> changedBefore = <String, Object?>{
    if (!scopeOnly) permissionsField: _permissionMap(before.permissions),
    sourceScopeField: before.sourceScope == null
        ? null
        : encodeScopeForStorage(before.sourceScope!),
  };

  // ★★ `IQ-017`: **حقل مرآة يُكتب مع كل كتابة صلاحيات** — ⛔ لا تغييرٌ تُحدثه
  //    هذه العملية. مصدر حقيقته **خدمة المصادقة** (`target.disabled`)،
  //    والبطاقة إسقاطٌ عنه لا مصدر له — تماماً كما هي `permissions` إسقاطُ
  //    قرارِ المنح. ⟵ ★ **فالكتابة هنا لا تُعطِّل أحداً ولا تُفعِّله**، بل
  //    تضمن ألّا تخرج بطاقةٌ من هذه العملية تحمل صلاحيةً لا تسري.
  //
  // ⚠️ **ولماذا `!disabled` لا `true` ثابتة:** الثابتة **تُعيد تفعيل حسابٍ
  //    معطَّل بأثرٍ جانبي لمنح صلاحية** — وهو تصعيدُ امتيازٍ صامت.
  final Map<String, Object?> userFields = <String, Object?>{
    ...changedAfter,
    userIsActiveField: !request.target.disabled,
  };

  return PermissionSyncAccepted(
    userFields: userFields,
    updateMask: userFields.keys.toList(),
    claims: after,
    entry: AuditEntry(
      id: request.requestId.trim(),
      // ⚠️ قيمة مبدئية لا تُكتب — الكاتب يستبدلها بوقت المنصة. راجع
      //    `audited_transaction.dart`.
      occurredAt: DateTime.utc(1970),
      actor: AuditActor(
        userId: request.actor.userId,
        userName: request.actor.userName,
        // ★★★ **والبريد منسوخٌ وقت الحدث** — `AM-012` §3.
        userEmail: request.actor.userEmail,
      ),
      action: AuditAction.permissionChange,
      target: AuditTarget(
        entityType: userEntityType,
        entityId: request.target.userId,
      ),
      // ★ **القيد يوثّق ما غيّرته هذه العملية — ⛔ لا `isActive`.**
      //   ⚠️ **والفرق ليس تفصيلاً:** إدراج حقلٍ لم يتغيّر يجعل كل قيد منحٍ
      //   يبدو **تغييراً لحالة الحساب**، فيُغرق سجلَّ التدقيق بضجيج يُخفي
      //   التعطيلَ الحقيقي حين يقع. ★ **وتغيّرُ الحالة يُدوَّن في قيده هو**
      //   من `disableUser` (`FR-M1-12` · `FR-M1-14`).
      valuesBefore: changedBefore,
      valuesAfter: changedAfter,
      deviceInfo: request.deviceInfo,
    ),
  );
}

/// خريطة الصلاحيات كما تُخزَّن — **الممنوحة وحدها، والغائب مرفوض**.
Map<String, Object?> _permissionMap(Set<Permission> permissions) {
  final List<Permission> ordered = permissions.toList()
    ..sort((Permission a, Permission b) => a.index - b.index);
  return <String, Object?>{for (final Permission p in ordered) p.name: true};
}

/// يرمّز النطاق للتخزين — `'all'` أو قائمة مرتّبة.
///
/// ★ **الترتيب ثابت** فتُنتج المجموعة نفسها القيمة نفسها في كل تشغيل، وهو
/// شرط قابلية التكرار بلا أثر جانبي (`coding-standards.md` §2.7).
Object encodeScopeForStorage(SourceScope scope) => switch (scope) {
      AllSources() => allSourcesClaimValue,
      ScopedSources(:final Set<String> sourceIds) => sourceIds.toList()..sort(),
    };

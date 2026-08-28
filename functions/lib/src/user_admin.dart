/// إدارة المستخدمين والأدوار — **التخطيط الخالص** لعمليات `IQ-015`.
///
/// ★ **مفصول عن الشبكة بنفس منطق `permission_sync.dart`:** `ADR-0013`
/// القاعدة 3 تجعل **فحص التفويض في الكود** هو الحارس الوحيد لهذا المسار،
/// فالدالة تعمل بامتياز إداري يتجاوز قواعد الحماية. ★ **وحارسٌ لا يُختبَر
/// بلا سحابة حارسٌ غير مُختبَر** — فكل قرار هنا **دالة خالصة**.
///
/// ★ **وقواعد العمل نفسها من طبقة النطاق لا من هنا** (`user_administration.dart`
/// في `qtms_domain`) — ⛔ **ولا تُعاد كتابتها**، فنسختان تفترقان عند أول
/// تعديل فتصير الواجهة تسمح بما ترفضه السحابة.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔★★ **وما لا تفعله هذه العمليات عمداً — ولماذا:**
///
///   ① **لا تُنشئ كلمة مرور ولا تقرؤها ولا تعرضها.**
///      `authentication-policy.md` §5 يفرض ثلاثة معاً: ⛔ **لا كلمة مرور
///      افتراضية مشتركة** · **«تغييرها من صاحبها — والإدارة تُعيد التعيين
///      لا تقرأ»** · **«آلية استرجاع آمنة»**. ⟵ ★ **فالمسار الوحيد المتوافق
///      مع الثلاثة أن يضبطها صاحبها عبر رابط استرجاع** — ⛔ لا كلمةٌ عشوائية
///      تُعرَض للمدير (فيقرؤها)، ولا ثابتةٌ مشتركة (فتخالف الأولى صراحةً).
///
///   ② ★ **لا تمنح صلاحيةً ولا نطاقاً.** الإنشاء يُنشئ **حساباً وبطاقة**،
///      والمنح مسارُه `grantPermissions` و`setSourceScope` **بقواعدهما**
///      (`BR-M1-03`: لا يمنح المُنفِّذ ما لا يملك). ⛔ **ودمجُهما هنا كان
///      سيفتح طريقاً لمنحٍ بلا تلك القواعد** — أي التفافاً كاملاً عليها.
///
///   ③ ⛔ **لا تحذف مستخدماً ولا تحذف قيداً.** `FR-M1-12`: «المستخدم صاحب
///      حركات لا يُحذف نهائياً بل يُعطَّل فقط».
///
/// ✅★★ **والاستثناء الوحيد `deleteRole` — بحسم `IQ-018` (الخيار ب):**
/// **قالب دورٍ غير مُسنَد يُحذف حذفاً فعلياً**، ⛔ **ولا يُقاس عليه مستخدمٌ
/// ولا حركة ولا قيد**: تلك سجلات ذات تاريخ، **وهذا قالبٌ لا يشير إليه أحد.**
library;

import 'package:qtms_domain/qtms_domain.dart';

import 'callable.dart';
import 'identity_gateway.dart';
import 'permission_sync.dart';

/// مجموعة الأدوار — `data-dictionary.md` §`roles`.
const String rolesCollection = 'roles';

/// ★★ حقل قالب صلاحيات الدور — `data-dictionary.md` §`roles`.
const String rolePermissionTemplateField = 'permissionTemplate';

/// حقل سبب التعطيل في البطاقة — `data-dictionary.md` §`users`.
const String userDisableReasonField = 'disableReason';

/// ★★ حقل الدور في بطاقة المستخدم — `data-dictionary.md` §`users`.
///
/// ★ **وهو الحقل الذي يُستعلَم عنه لقياس إسناد الدور** (`IQ-018`) — ⟵
/// **فاسمه ثابتٌ في موضع واحد**، ⛔ **ولا نصٌّ حرفي متكرر ينزلق أحدُه.**
const String userRoleIdField = 'roleId';

/// نوع عملية الإدارة — يحدد الصلاحية التي لا تُنفَّذ العملية بدونها.
enum UserAdminOperation {
  /// `createUser` — يشترط `userCreate` (`FR-M1-01`).
  createUser(Permission.userCreate),

  /// `updateUser` — يشترط `userAmend` (`FR-M1-01` · `BR-M1-02`).
  updateUser(Permission.userAmend),

  /// `disableUser` — يشترط `userDisable` (`FR-M1-12`).
  disableUser(Permission.userDisable),

  /// `createRole` — يشترط `roleWrite` (`FR-M1-03`).
  createRole(Permission.roleWrite),

  /// `updateRole` — يشترط `roleWrite`، ★ **وسبباً نصياً** (`ADR-0004`).
  updateRole(Permission.roleWrite),

  /// ★★ `deleteRole` — يشترط `roleDelete`، ★ **وسبباً نصياً**، ★★ **وإحصاءً
  /// مقيساً يُثبت أن الدور غير مُسنَد** (`IQ-018` · `FR-M1-03`).
  ///
  /// ⛔ **وهي العملية الوحيدة في النظام التي تحذف مستنداً.**
  deleteRole(Permission.roleDelete);

  const UserAdminOperation(this.requiredPermission);

  /// الصلاحية التي لا تُنفَّذ العملية بدونها.
  final Permission requiredPermission;
}

/// نتيجة التخطيط — إما خطة كتابة وإما رفض مصنَّف.
sealed class UserAdminPlan {
  const UserAdminPlan();
}

/// رُفض الطلب قبل أي كتابة.
final class UserAdminRejected extends UserAdminPlan {
  /// ينشئ رفضاً.
  const UserAdminRejected(this.error);

  /// رمز الرفض من كتالوج الأخطاء.
  final CallableError error;
}

/// قُبل الطلب — وهذه حقوله وقيده وأثره على خدمة المصادقة.
final class UserAdminAccepted extends UserAdminPlan {
  /// ينشئ خطة مقبولة.
  const UserAdminAccepted({
    required this.collectionId,
    required this.documentId,
    required this.fields,
    required this.updateMask,
    required this.entry,
    this.setAccountDisabled,
    this.deletesDocument = false,
  });

  /// ★★ **هل الخطة حذفٌ للمستند بدل كتابته؟** — `IQ-018`.
  ///
  /// ⛔★★ **وهو `bool` صريح لا استنتاجٌ من `fields.isEmpty`:** الاستنتاج
  /// كان سيجعل **خطةَ كتابةٍ فرغت حقولُها بخطأٍ برمجي** تُنفَّذ **حذفاً**
  /// — ⟵ **أخطر انقلابِ نيّةٍ ممكن في هذا الملف.**
  final bool deletesDocument;

  /// المجموعة المكتوب فيها — `users` أو `roles`.
  final String collectionId;

  /// معرّف المستند.
  final String documentId;

  /// الحقول المتغيّرة وحدها.
  final Map<String, Object?> fields;

  /// ★ **قناع الكتابة** — ⛔ وبدونه تُمحى بقية حقول المستند.
  final List<String> updateMask;

  /// قيد التدقيق — **يُكتب في المعاملة نفسها** (`ADR-0013` القاعدة 1).
  final AuditEntry entry;

  /// ★★ الأثر المطلوب على **خدمة المصادقة** بعد نجاح المعاملة.
  ///
  /// `null` تعني **لا أثر**. و`true` تعني تعطيل الحساب في الخدمة نفسها —
  /// ★ **وهو الشطر الثاني من جواب `IQ-017` (الخيار ج)**: البطاقة تمنع
  /// الرمزَ **القائم**، والخدمة تمنع إصدارَ **الجديد**. ⟵ **والنافذتان
  /// تُغلقان معاً** ⛔ ولا يكفي أحدهما: القاعدة وحدها تترك الحساب قادراً
  /// على تجديد رمزه، والخدمة وحدها تترك رمزاً صالحاً يعمل حتى ينتهي.
  final bool? setAccountDisabled;
}

/// طلب إدارة مُتحقَّق من هوية مُنفِّذه.
final class UserAdminRequest {
  /// ينشئ الطلب.
  const UserAdminRequest({
    required this.actor,
    required this.targetId,
    required this.requestId,
    required this.ownerUserId,
    this.profile,
    this.disableReason,
    this.amendReason,
    this.roleName,
    this.roleDescription,
    this.targetIsOwner = false,
    this.deviceInfo,
    this.roleAssignment,
    this.roleBefore,
  });

  /// المُنفِّذ **بحالته الآن من خدمة المصادقة** لا من الرمز الذي أرسله.
  final AccountRecord actor;

  /// معرّف المستهدَف — مستخدماً كان أو دوراً.
  final String targetId;

  /// ★ **معرّف مُولَّد على الجهاز** — وهو **معرّف قيد التدقيق نفسه**،
  /// فإعادة الإرسال تكتب فوق القيد ولا تُنشئ ثانياً (`api-overview.md` §4).
  final String requestId;

  /// معرّف المالك — ★ **من إعداد البيئة** ⛔ **لا من الحمولة**.
  ///
  /// ⚠️ **ولو قُرئ من الحمولة لَصار أي مُستدعٍ قادراً على تسمية نفسه
  /// مالكاً** — تصعيدُ امتيازٍ كامل بسطر واحد (نفس منطق `owner_bootstrap`).
  final String ownerUserId;

  /// ملف المستخدم — لعمليتَي الإنشاء والتعديل.
  final ValidatedUserProfile? profile;

  /// سبب التعطيل مُتحقَّقاً منه — لعملية التعطيل.
  final String? disableReason;

  /// ★★ **سبب التعديل — إلزامي لكل عملية تعديل** (`ADR-0004` · `DEBT-21` ①).
  ///
  /// ⚠️ **ولا قيمة افتراضية له ولا نصّ مولَّد:** «تعديل من الشاشة» ليس
  /// سبباً — ★ **والسبب المولَّد آلياً يُفرِغ القيد من معناه** ويجعل سجل
  /// التدقيق صفوفاً متطابقة لا تُفسِّر شيئاً.
  final String? amendReason;

  /// اسم الدور — لعملية كتابة الدور.
  final ValidatedRole? roleName;

  /// وصف الدور — يُقرأ من [roleName] وهذا للتوثيق فقط.
  final String? roleDescription;

  /// هل المستهدَف هو المالك؟ — يُشتقّ من [ownerUserId] ويُمرَّر للوضوح.
  final bool targetIsOwner;

  /// وصف الجهاز للسجل — ⛔ بلا بيانات حساسة.
  final String? deviceInfo;

  /// ★★ **إحصاء الإسناد المقيس** — لعملية الحذف وحدها (`IQ-018`).
  ///
  /// ⛔★★ **و`null` تعني «لم يُقَس» ⟵ رفضٌ لا سماح:** الافتراض الآمن
  /// (القاعدة 6 في `security-requirements.md` §2). ★ **ولذلك لا قيمة
  /// افتراضية له**: نسيانُ الاستعلام **يُرفَض صراحةً** ⛔ ولا يُقرأ «غير
  /// مُسنَد».
  final RoleAssignmentCensus? roleAssignment;

  /// ★ حقول الدور **كما قُرئت داخل المعاملة** — تصير `valuesBefore` للقيد.
  ///
  /// ⚠️ **و`null` تعني «لا مستند»** ⟵ **رفضٌ أيضاً**: حذفُ ما لا يوجد ليس
  /// نجاحاً صامتاً، ★ **وقيدُ حذفٍ بلا «قبل» قيدٌ لا يقول شيئاً.**
  final Map<String, Object?>? roleBefore;
}

/// يخطّط عملية إدارة — **دالة خالصة، وهي حارس التفويض الفعلي**.
///
/// ★ **ترتيب الفحوص مقصود ويطابق `permission_sync.dart`:** الحالة قبل
/// الصلاحية، والصلاحية قبل محتوى الطلب — فلا يُفحَص محتوى طلبٍ مرفوضٍ أصلاً.
UserAdminPlan planUserAdmin(
  UserAdminRequest request,
  UserAdminOperation operation,
) {
  final UserAdminRejected? gate = _gate(request, operation);
  if (gate != null) return gate;

  return switch (operation) {
    UserAdminOperation.createUser => _planProfile(request, isCreate: true),
    UserAdminOperation.updateUser => _planProfile(request, isCreate: false),
    UserAdminOperation.disableUser => _planDisable(request),
    UserAdminOperation.createRole => _planRoleWrite(request, isCreate: true),
    UserAdminOperation.updateRole => _planRoleWrite(request, isCreate: false),
    UserAdminOperation.deleteRole => planRoleDeletion(request),
  };
}

/// ★★ فحوص الحالة والصلاحية وحدها — **تُستدعى قبل فتح المعاملة**.
///
/// ⚠️ **ولماذا مُصدَّرة:** حذف الدور يحتاج **قراءةً واستعلاماً داخل معاملة**
/// قبل أن يكتمل تخطيطه، ⟵ **وفتحُ معاملةٍ لطلبٍ يرفضه نقصُ الصلاحية هدرٌ
/// وقفلٌ بلا داعٍ**. ★ **والفحص نفسه لا يتكرر منطقاً** — [planUserAdmin]
/// تعيده كاملاً على الطلب المكتمل، ⛔ **فلا مسار يتخطّاه.**
UserAdminRejected? userAdminGate(
  UserAdminRequest request,
  UserAdminOperation operation,
) =>
    _gate(request, operation);

/// فحوص الحالة والصلاحية — ما يسبق محتوى الطلب.
UserAdminRejected? _gate(
  UserAdminRequest request,
  UserAdminOperation operation,
) {
  // ① «التعطيل فوري ونافذ» — `authentication-policy.md` §2 القاعدة 3.
  if (request.actor.disabled) {
    return const UserAdminRejected(CallableError.accountDisabled);
  }
  // ② الصلاحية الإدارية — ⛔ ولا قاعدة حماية تحرس هذا المسار؛ **هذا السطر
  //    هو الحارس** (`ADR-0013` القاعدة 3 · الكتالوج §2.10).
  if (!request.actor.claims.has(operation.requiredPermission)) {
    return const UserAdminRejected(CallableError.permissionMissing);
  }
  // ③ معرّف الطلب إلزامي — وبدونه لا تتحقق اللاتكرارية عند إعادة الإرسال.
  if (request.requestId.trim().isEmpty) {
    return const UserAdminRejected(CallableError.invalidArgument);
  }
  // ④ معرّف المستهدَف إلزامي.
  if (request.targetId.trim().isEmpty) {
    return const UserAdminRejected(CallableError.invalidArgument);
  }
  return null;
}

UserAdminPlan _planProfile(UserAdminRequest request, {required bool isCreate}) {
  final ValidatedUserProfile? profile = request.profile;
  if (profile == null) {
    return const UserAdminRejected(CallableError.invalidArgument);
  }

  // ⛔⛔★★★ **حارسُ السبب حُذف بـ`ADR-0020` (2026-08-27)** — ★ **السبب
  //    اختياريٌّ في كل عملية**، ⟵ **ولا رفضَ لغيابه.** ⛔ **ولا يُعبَّأ آلياً.**
  final String? amendReason = _optionalAmendReason(request, isCreate: isCreate);

  // ★★ حارس المالك — `BR-M1-02` · `FR-M1-11`. ⛔ **ويسري على التعديل لا
  //    الإنشاء**: لا معنى لـ«إنشاء حساب المالك من غيره» فالحساب لم يوجد بعد.
  if (!isCreate) {
    final Outcome<void> guard = validateOwnerAccountGuard(
      actorUserId: request.actor.userId,
      targetUserId: request.targetId,
      ownerUserId: request.ownerUserId,
    );
    if (guard is Failure<void>) {
      return const UserAdminRejected(CallableError.permissionMissing);
    }
  }

  final Map<String, Object?> after = <String, Object?>{
    'name': profile.name,
    'normalizedName': profile.normalizedName,
    'email': profile.email,
    'phone': profile.phone,
    userRoleIdField: profile.roleId,
  };

  // ★★ **الإنشاء يكتب `isActive: true` صراحةً** (`IQ-017`) — ⛔ وبطاقةٌ
  //    بلا هذا الحقل بطاقةٌ بلا صلاحية تسري مهما مُنِحت لاحقاً.
  // ⛔ **والتعديل لا يمسّه إطلاقاً** — فتعديلُ اسمٍ لا يُعيد تفعيل معطَّل،
  //    ومسار التعطيل والتفعيل عمليتُه هو.
  final Map<String, Object?> fields = <String, Object?>{
    ...after,
    if (isCreate) userIsActiveField: true,
    // ★ والصلاحيات خريطة فارغة عند الإنشاء — **الرفض الافتراضي**:
    //   ⛔ لا صلاحية إلا بمنحٍ صريح عبر `grantPermissions` بقواعده.
    if (isCreate) permissionsField: <String, Object?>{},
  };

  return UserAdminAccepted(
    collectionId: usersCollection,
    documentId: request.targetId,
    fields: fields,
    updateMask: fields.keys.toList(),
    entry: _entry(
      request: request,
      action: isCreate ? AuditAction.create : AuditAction.amend,
      reason: amendReason,
      entityType: userEntityType,
      entityId: request.targetId,
      // ⛔ **لا قيمة «قبل» عند الإنشاء** — ولا تُخترَع خريطة فارغة توهم بأن
      //   حقولاً كانت موجودة وتغيّرت.
      valuesBefore: isCreate ? const <String, Object?>{} : _unknownBefore(after),
      valuesAfter: after,
    ),
  );
}

UserAdminPlan _planDisable(UserAdminRequest request) {
  final String? reason = request.disableReason;
  if (reason == null || reason.trim().isEmpty) {
    return const UserAdminRejected(CallableError.invalidArgument);
  }

  final Map<String, Object?> after = <String, Object?>{
    userIsActiveField: false,
    userDisableReasonField: reason.trim(),
  };

  return UserAdminAccepted(
    collectionId: usersCollection,
    documentId: request.targetId,
    fields: after,
    updateMask: after.keys.toList(),
    // ★★ **والشطر الثاني من `IQ-017` الخيار ج** — راجع [UserAdminAccepted].
    setAccountDisabled: true,
    entry: _entry(
      request: request,
      // ★ **فعلٌ مستقل في المعجم لا «تعديل»** — فالتعطيل يُقرأ من السجل
      //   بذاته ⛔ ولا يختفي بين تعديلات الأسماء.
      action: AuditAction.disable,
      // ★ **سبب التعطيل هو سبب القيد نفسه** (`FR-M1-12`) — ⛔ ولا يُكتب
      //   في الحقل ويُغفَل في القيد، فيصير السجل يقول «عُطِّل» بلا لماذا.
      reason: reason.trim(),
      entityType: userEntityType,
      entityId: request.targetId,
      valuesBefore: <String, Object?>{userIsActiveField: true},
      valuesAfter: after,
    ),
  );
}

UserAdminPlan _planRoleWrite(UserAdminRequest request, {required bool isCreate}) {
  final ValidatedRole? role = request.roleName;
  if (role == null) {
    return const UserAdminRejected(CallableError.invalidArgument);
  }
  // ⛔⛔★★★ **حارسُ السبب حُذف بـ`ADR-0020`** — ★ **اختياريٌّ في كل عملية.**
  final String? amendReason = _optionalAmendReason(request, isCreate: isCreate);
  final Map<String, Object?> after = <String, Object?>{
    'name': role.name,
    'normalizedName': role.normalizedName,
    'description': role.description,
    // ★★ **قالب الصلاحيات** — `FR-M1-03` · `data-dictionary.md` §`roles`.
    //   ⚠️ **وقالبٌ لا منح**: كتابتُه لا تمنح أحداً شيئاً، ★ **والمنح
    //   مسارُه `grantPermissions` وحده بـ`BR-M1-03`** (راجع `ValidatedRole`).
    rolePermissionTemplateField: _templateMap(role.permissions),
  };
  return UserAdminAccepted(
    collectionId: rolesCollection,
    documentId: request.targetId,
    fields: after,
    updateMask: after.keys.toList(),
    entry: _entry(
      request: request,
      action: isCreate ? AuditAction.create : AuditAction.amend,
      reason: amendReason,
      entityType: roleEntityType,
      entityId: request.targetId,
      valuesBefore: isCreate ? const <String, Object?>{} : _unknownBefore(after),
      valuesAfter: after,
    ),
  );
}

/// ★★ يخطّط **حذف دور** — `IQ-018` (الخيار ب) · `FR-M1-03`.
///
/// ★ **دالة خالصة كغيرها**: الاستعلام والقراءة يقعان في المُنفِّذ **داخل
/// المعاملة**، ويصلان هنا في [UserAdminRequest.roleAssignment] و
/// [UserAdminRequest.roleBefore]. ⟵ **فالقرار يُختبَر بلا سحابة**، ★ **وهو
/// شرط `ADR-0013` القاعدة 3** («حارسٌ لا يُختبَر حارسٌ غير مُختبَر»).
///
/// **ترتيب الرفض مقصود:**
/// ① «قِيس الإسناد أصلاً؟» · ② «هل هو مُسنَد؟» · ③ «هل المستند موجود؟».
/// ⛔★★ **وفحصُ السبب كان أوّلَها حتى `ADR-0020`** — ★ **وسقط بلا بديل.**
UserAdminPlan planRoleDeletion(UserAdminRequest request) {
  // ⛔⛔★★★ **حارسُ السبب حُذف بـ`ADR-0020` (2026-08-27)** — ⚠️★★ **وكان
  //    الحذفُ أولى العمليات به:** ★ **المُعدَّل يبقى مستندُه للمراجعة
  //    والمحذوف لا يبقى** ⟵ **فدورٌ يختفي الآن بلا تفسير.** ★ **عُرِضت هذه
  //    الحجّة على المالك نصّاً قبل الاعتماد فاختار التعميم** — ⛔ **فهو ثمنٌ
  //    مقبولٌ بقرار لا بسهو** (`ADR-0020` §النتائج).
  final String? amendReason = _optionalAmendReason(request, isCreate: false);

  // ① ⛔★★ **لم يُقَس الإسناد ⟵ رفض** — ★ **وهذا الفحص هو حسم `IQ-018`
  //    نفسه**: «لا يعتمد على قيمة مخزنة أو افتراض محلي». ⟵ **فمسارٌ نسي
  //    الاستعلام يُرفَض صراحةً** ⛔ **ولا يُقرأ صمتُه «غير مُسنَد».**
  final RoleAssignmentCensus? census = request.roleAssignment;
  if (census == null) {
    return const UserAdminRejected(CallableError.internal);
  }

  // ② ★ **القاعدة من طبقة النطاق** — ⛔ ولا تُعاد كتابتها هنا.
  final Outcome<void> allowed = validateRoleDeletion(census);
  if (allowed is Failure<void>) {
    // ★ **رفضُ قاعدةِ عملٍ صلاحيةً لا خللَ مدخلات** — الطلب سليم البنية
    //   وإنما يخالف `FR-M1-03`. ⟵ **فتعرض الشاشة «ليس لديك صلاحية…»؟ لا:**
    //   الرمز `ERR_AUTH_001` عام، ★ **والشاشة تُميّز الحالة بنصّها هي**
    //   لأنها تعرف أنها طلبت حذفاً (راجع `roles_screen.dart`).
    return const UserAdminRejected(CallableError.roleAssigned);
  }

  // ③ ⛔ **لا حذف لما لا يوجد** — ★ **ونجاحٌ صامت هنا أسوأ من رفض**: يقول
  //    للمدير «حُذف» عن دورٍ لم يكن، **ويكتب قيداً بلا «قبل»** فيصير السجل
  //    يشهد على حذفٍ لا يُعرَف ماذا كان.
  final Map<String, Object?>? before = request.roleBefore;
  if (before == null || before.isEmpty) {
    // ⚠️ **والفارغ كالغائب هنا:** مستندٌ بلا حقول يُنتج قيداً بـ«قبل» فارغة،
    //    ⟵ **فيشهد السجل على حذفٍ لا يُعرَف ماذا كان** — وهو أسوأ من رفض.
    return const UserAdminRejected(CallableError.invalidArgument);
  }

  return UserAdminAccepted(
    collectionId: rolesCollection,
    documentId: request.targetId,
    // ⛔ **لا حقول ولا قناع** — الخطة حذفٌ لا كتابة.
    fields: const <String, Object?>{},
    updateMask: const <String>[],
    deletesDocument: true,
    entry: _entry(
      request: request,
      // ★★ **فعلٌ مستقل في المعجم** — ⛔ لا `cancel` (وسمٌ لا حذف).
      action: AuditAction.delete,
      reason: amendReason,
      entityType: roleEntityType,
      entityId: request.targetId,
      // ★★ **«قبل» من المستند المقروء فعلاً** — ⟵ **فالسجل يحفظ ما ضاع**،
      //   وهو ما يجعل الحذف قابلاً للمراجعة رغم أنه لا رجعة فيه.
      valuesBefore: before,
      // ★ **و«بعد» غيابٌ صريح** — ⛔ لا خريطة فارغة تُقرأ «لم يتغيّر شيء».
      valuesAfter: const <String, Object?>{roleDeletedMarker: true},
    ),
  );
}

/// ★ قالب الصلاحيات كما يُخزَّن — **الممنوحة وحدها والغائب `false`**.
///
/// ★ **بنفس صيغة `permissions` في بطاقة المستخدم** (`_permissionMap`)، ⟵
/// **فالمقارنة بين المستخدم ودوره تقرأ الشكل نفسه** ⛔ ولا تحويل بينهما.
///
/// ★ **والترتيب ثابت** — فنفس المجموعة تُنتج نفس الخريطة في كل تشغيل
/// (`coding-standards.md` §2.7)، ⟵ **وقيدُ التدقيق يبقى قابلاً للمقارنة.**
Map<String, Object?> _templateMap(Set<Permission> permissions) {
  final List<Permission> ordered = permissions.toList()
    ..sort((Permission a, Permission b) => a.index - b.index);
  return <String, Object?>{for (final Permission p in ordered) p.name: true};
}

/// ★ علامة «لم يعد المستند موجوداً» في `valuesAfter` — `IQ-018`.
///
/// ⚠️ **ولماذا علامة لا خريطة فارغة:** الفارغة تُقرأ في السجل **«لم يتغيّر
/// شيء»** ⟵ **فيبدو قيدُ الحذف قيداً بلا أثر**. ★ **والعلامة تقول الحقيقة
/// صراحةً**: الكيان لم يعد قائماً.
const String roleDeletedMarker = 'deleted';

/// ★★ سبب التعديل مقصوصاً، أو `null` إن غاب أو كان فراغات — `ADR-0020`.
///
/// ⛔ **والفراغات وحدها ليست سبباً** — ★ **فتُقرأ `null` لا نصّاً فارغاً**،
/// ⟵ **فلا يُخزَّن في القيد حقلٌ يبدو مملوءاً وهو خالٍ.**
/// ⚠️ **ولم يعد غيابُه يرفض شيئاً** (`ADR-0020`) — ★ **يُمرَّر كما هو.**
String? _optionalAmendReason(
  UserAdminRequest request, {
  required bool isCreate,
}) {
  if (isCreate) return null;
  final String? raw = request.amendReason?.trim();
  return (raw == null || raw.isEmpty) ? null : raw;
}

/// ★ «قبل» لحقولٍ **لم تُقرأ** — ⛔ ولا تُخترَع لها قيم.
///
/// ⚠️ **ولماذا `null` لا خريطة فارغة ولا القيم الجديدة:** القيد يوثّق
/// **ما تغيّر**، وكتابةُ القيمة الجديدة في خانة «قبل» **تُلغي معنى القيد
/// كله** فتجعل كل تعديل يبدو بلا تغيير. ★ **و`null` تقول الحقيقة صراحةً:
/// الحقل تغيّر وقيمته السابقة غير مقروءة في هذا المسار.**
Map<String, Object?> _unknownBefore(Map<String, Object?> after) =>
    <String, Object?>{for (final String key in after.keys) key: null};

AuditEntry _entry({
  required UserAdminRequest request,
  required AuditAction action,
  required String entityType,
  String? reason,
  required String entityId,
  required Map<String, Object?> valuesBefore,
  required Map<String, Object?> valuesAfter,
}) =>
    AuditEntry(
      id: request.requestId.trim(),
      // ⚠️ قيمة مبدئية لا تُكتب — الكاتب يستبدلها بوقت المنصة. راجع
      //    `audited_transaction.dart`.
      occurredAt: DateTime.utc(1970),
      actor: AuditActor(
        userId: request.actor.userId,
        userName: request.actor.userName,
      ),
      action: action,
      reason: reason,
      target: AuditTarget(entityType: entityType, entityId: entityId),
      valuesBefore: valuesBefore,
      valuesAfter: valuesAfter,
      deviceInfo: request.deviceInfo,
    );

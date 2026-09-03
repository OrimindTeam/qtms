/// إقلاع صلاحيات المالك الأول — **التخطيط الخالص**.
///
/// ★ **لماذا عملية منفصلة عن `grantPermissions`:** حلقة إقلاع مغلقة.
/// `grantPermissions` تشترط على مُنفِّذها امتلاك `permissionGrant`
/// (`permission_sync.dart` فحص ②)، **وحساب المالك الأول بلا صلاحيات
/// إطلاقاً** (`environments.md` §1.3). فلو مرّ الإقلاع عبرها لما ملك أحدٌ
/// الصلاحيةَ أبداً ولا أمكن منحها لأحد — **النظام يقفل على نفسه من أول يوم**.
///
/// ★ **وهذا بالضبط ما نصّ عليه جواب `IQ-007`** (الخيار أ): «تُمنَح له هذه
/// التسعة بإجراء تشغيلي موثَّق لمرة واحدة — ⛔ **لا من التطبيق ولا عبر
/// `grantPermissions` نفسها**» (`permissions-catalog.md` §2.10).
///
/// ⚠️ **واستثناؤها الوحيد المعلَن:** هذه العملية **تمنح المالكَ صلاحياتِ
/// نفسِه**، وهو ما تمنعه القاعدة العامة «لا مستخدم يعدّل صلاحيات نفسه — ولو
/// المالك» (`authentication-policy.md` §3). ★ **والاستثناء مقصود وموثَّق ولا
/// يتوسّع**: يقتصر على **حساب واحد بعينه** (المالك المسجَّل) وعلى **التسعة
/// الإدارية وحدها** و**مرة واحدة** — ⛔ ولا يمنح أي صلاحية تشغيلية ولا يمسّ
/// نطاق المصادر إطلاقاً.
library;

import 'package:qtms_domain/qtms_domain.dart';

import 'callable.dart';
import 'identity_claims.dart';
import 'identity_gateway.dart';
import 'permission_sync.dart';

/// طلب إقلاع مُتحقَّق من هوية مُنفِّذه.
final class OwnerBootstrapRequest {
  /// ينشئ الطلب.
  const OwnerBootstrapRequest({
    required this.actor,
    required this.registeredOwnerUserId,
    required this.requestId,
    this.deviceInfo,
  });

  /// المُستدعي **بحالته الآن من خدمة المصادقة** لا من الرمز الذي أرسله.
  final AccountRecord actor;

  /// معرّف المالك المسجَّل **قبل الاستدعاء** — من إعداد البيئة لا من الحمولة.
  ///
  /// ⛔ **ولا يُقرأ من الطلب إطلاقاً:** لو جاء من الحمولة لصار أي مُستدعٍ
  /// قادراً على تسمية نفسه مالكاً — وهو تصعيد امتياز كامل بسطر واحد.
  final String registeredOwnerUserId;

  /// ★ معرّف مُولَّد مسبقاً — وهو **معرّف قيد التدقيق نفسه**، فإعادة
  /// الاستدعاء بنفسه تكتب فوق القيد ولا تُنشئ ثانياً (`api-overview.md` §4).
  final String requestId;

  /// وصف الجهاز للسجل — ⛔ بلا بيانات حساسة.
  final String? deviceInfo;
}

/// نتيجة تخطيط الإقلاع.
sealed class OwnerBootstrapPlan {
  const OwnerBootstrapPlan();
}

/// رُفض الطلب قبل أي كتابة.
final class OwnerBootstrapRejected extends OwnerBootstrapPlan {
  /// ينشئ رفضاً.
  const OwnerBootstrapRejected(this.error);

  /// رمز الرفض من كتالوج الأخطاء.
  final CallableError error;
}

/// ★ **الإقلاع تمّ سابقاً** — ⛔ ولا كتابة ولا قيد تدقيق.
///
/// ★ **ولماذا نجاحٌ لا رفض:** الاستدعاء الثاني بنفس الطلب **لم يفشل**، بل
/// وجد الحالة المطلوبة قائمة. وهذا هو معنى «قابلية التكرار بلا أثر جانبي»
/// (`coding-standards.md` §2.7): **نفس الطلب يُنتج نفس الحالة النهائية**.
/// ⛔ **ولا يُكتب قيد تدقيق لتغيير لم يحدث** — القيد يوثّق تغييراً، وقيدٌ بلا
/// تغيير يُلوِّث السجل بضجيج يُخفي التغييرات الحقيقية.
final class OwnerBootstrapAlreadyDone extends OwnerBootstrapPlan {
  /// ينشئ نتيجة «تمّ سابقاً».
  const OwnerBootstrapAlreadyDone();
}

/// قُبل الطلب — وهذه حقوله وقيده ومطالباته.
final class OwnerBootstrapAccepted extends OwnerBootstrapPlan {
  /// ينشئ خطة مقبولة.
  const OwnerBootstrapAccepted({
    required this.userFields,
    required this.updateMask,
    required this.entry,
    required this.claims,
  });

  /// حقول بطاقة المستخدم المتغيّرة وحدها.
  final Map<String, Object?> userFields;

  /// ★ **قناع الكتابة** — ⛔ وبدونه تُمحى بقية حقول البطاقة.
  final List<String> updateMask;

  /// قيد التدقيق المقابل — **يُكتب في المعاملة نفسها** (`ADR-0013` القاعدة 1).
  final AuditEntry entry;

  /// المطالبات التي ستُكتب في الرمز **بعد نجاح المعاملة**.
  final IdentityClaims claims;
}

/// يخطّط إقلاع المالك — **دالة خالصة، وهي حارس التفويض الفعلي**.
///
/// ★ **ترتيب الفحوص مقصود:** الحالة ثم الهوية ثم محتوى الطلب — فلا يُفحَص
/// محتوى طلبٍ مرفوضٍ أصلاً.
OwnerBootstrapPlan planOwnerBootstrap(OwnerBootstrapRequest request) {
  // ① «التعطيل فوري ونافذ» — `authentication-policy.md` §2 القاعدة 3.
  if (request.actor.disabled) {
    return const OwnerBootstrapRejected(CallableError.accountDisabled);
  }

  // ② ★ الهوية وحدها هي التفويض هنا — ⛔ ولا صلاحية تُفحَص، إذ لا يملك
  //    المالكُ عند الإقلاع أيَّ صلاحية أصلاً. **وهذا السطر هو الحارس كلّه.**
  final String registered = request.registeredOwnerUserId.trim();
  if (registered.isEmpty || request.actor.userId != registered) {
    return const OwnerBootstrapRejected(CallableError.permissionMissing);
  }

  // ③ معرّف الطلب إلزامي — وبدونه لا تتحقق اللاتكرارية عند إعادة الإرسال.
  if (request.requestId.trim().isEmpty) {
    return const OwnerBootstrapRejected(CallableError.invalidArgument);
  }

  // ④ ★ تمّ سابقاً؟ — فلا كتابة ولا قيد.
  //
  // ⚠️⚠️ **والشرط الثاني ليس زينة — هو ما يمنع قفل المالك خارج نظامه
  //    (`IQ-017` · `DEBT-22`):** كانت هذه البوابة تنظر إلى الصلاحيات وحدها،
  //    ⟵ **فبطاقةُ المالك المُقلَعة قبل حقل `isActive` تُرجِع «تمّ سابقاً»
  //    ولا تُكتب أبداً**. وبعد أن صارت `perm()` تشترط `isActive == true`،
  //    ⛔ **يعني ذلك مالكاً بكل الصلاحيات ولا واحدة منها تسري** — ولا مسار
  //    لإصلاحه، لأن كل مسارات المنح تشترط صلاحية لا تسري له.
  //
  // ★ **ولذلك هذه العملية هي أداة الترحيل نفسها** كما نصّ جواب `IQ-017`
  //   («إجراء ترحيل/Bootstrap يملأ `isActive`»): **تُقلِع الناقص وتُصلح
  //   البطاقة القديمة**، ⛔ **ولا تلمس بطاقةً مكتملة** — وهو الحارس نفسه
  //   الذي تطبّقه تهيئة الحسابات: «يُنشئ الناقص ولا يلمس القائم».
  final IdentityClaims before = request.actor.claims;
  // ★★★ `IQ-023`: **المقياس صار كلَّ الكتالوج لا التسعة** — ⟵ **فبطاقةُ مالكٍ
  //    أُقلِعت بالتسعة وحدها تُصلَح لا تُترَك**، بنفس منطق `isActive` والنطاق.
  final bool permissionsComplete =
      before.permissions.containsAll(ownerBootstrapPermissions);
  final bool cardStateWritten = request.actor.cardIsActive == true;
  // ⚠️⚠️★★ **والشرط الثالث بنفس منطق الثاني حرفياً — `IQ-022`:** كانت هذه
  //    البوابة تنظر إلى الصلاحيات والحالة وحدهما، ⟵ **فبطاقةُ مالكٍ مُقلَعةٍ
  //    بلا نطاق تُرجِع «تمّ سابقاً» ولا تُكتب أبداً.** ⛔ **وذلك يعني مالكاً
  //    بكل الصلاحيات الإدارية لا يستطيع منح أحدٍ ولا نفسه** — لأن الفحص ③ في
  //    `permission_sync.dart` يرفض كل مزامنةٍ لفاعلٍ بلا نطاق، ★ **و`FR-M1-08`
  //    يمنعه من منح نفسه.** ⟵ ⛔ **حلقةٌ مغلقة تقفل البيئة على نفسها.**
  //    ★ **رُصدت حيّاً على التجريبية (2026-08-26) لا نظرياً.**
  final bool scopeWritten = before.sourceScope != null;
  if (permissionsComplete && cardStateWritten && scopeWritten) {
    return const OwnerBootstrapAlreadyDone();
  }

  return _buildPlan(request, before);
}

OwnerBootstrapAccepted _buildPlan(
  OwnerBootstrapRequest request,
  IdentityClaims before,
) {
  // ★ **اتحاد لا استبدال:** لو كان المالك يملك صلاحية سابقة، لا تُسحَب منه
  //   ضمناً. ⛔ والسحب فعلٌ صريح لا أثرٌ جانبي لإقلاع.
  final Set<Permission> after = <Permission>{
    ...before.permissions,
    ...ownerBootstrapPermissions,
  };

  final IdentityClaims claims = IdentityClaims(
    permissions: after,
    // ★★★ **ونطاقُ المالك `all` — `IQ-022` الخيار (أ) (2026-08-26).**
    //
    // ⚠️⚠️ **ولماذا انقلب القرار السابق («لا يُمَسّ النطاق»):** ثبت حيّاً أن
    //    تركَه فارغاً **يقفل البيئة على نفسها إلى الأبد**: المنح يشترط نطاقاً
    //    للمُنفِّذ (`permission_sync.dart` الفحص ③) · **والنطاق يُمنَح
    //    بـ`setSourceScope` وهي تشترطه أيضاً** · ⛔ **والمالك لا يمنح نفسه**
    //    (`FR-M1-08`). ⟵ **فلا مسار واحد يُنتِج أوّل نطاق في النظام.**
    //
    // ★ **واتحادٌ لا استبدال** — ⛔ فلا يُضيَّق نطاقٌ أوسع لو وُجد يوماً.
    sourceScope: before.sourceScope ?? const AllSources(),
    roleId: before.roleId,
  );

  final SourceScope afterScope = before.sourceScope ?? const AllSources();
  final Map<String, Object?> changedAfter = <String, Object?>{
    permissionsField: _permissionMap(after),
    // ★★ **والنطاق يُكتب مع الصلاحيات في المعاملة نفسها** (`IQ-022`) —
    //    ⛔ **ولا يُكتب أحدهما بلا الآخر**، وإلا بقيت الحلقة مفتوحة.
    sourceScopeField: encodeScopeForStorage(afterScope),
  };
  final Map<String, Object?> changedBefore = <String, Object?>{
    permissionsField: _permissionMap(before.permissions),
    sourceScopeField: before.sourceScope == null
        ? null
        : encodeScopeForStorage(before.sourceScope!),
  };

  // ★★ `IQ-017`: **حقل الحالة يُكتب مع الصلاحيات دائماً** — ⛔ ولا يُكتب
  //    `permissions` بدونه، وإلا مُنِحت صلاحيةٌ لا تسري (`perm()` تشترطه).
  //
  // ⚠️ **و`!disabled` لا `true` ثابتة** — وإن كانت `true` حتماً هنا لأن
  //    الفحص ① يرفض المعطَّل: ★ **الاشتقاق يبقى صحيحاً لو تغيّر ترتيب
  //    الفحوص يوماً**، والثابتة تصير كذبةً صامتة عندها.
  final Map<String, Object?> userFields = <String, Object?>{
    ...changedAfter,
    userIsActiveField: !request.actor.disabled,
  };

  return OwnerBootstrapAccepted(
    userFields: userFields,
    updateMask: userFields.keys.toList(),
    claims: claims,
    entry: AuditEntry(
      id: request.requestId.trim(),
      // ⚠️ قيمة مبدئية لا تُكتب — الكاتب يستبدلها بوقت المنصة.
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
        entityId: request.actor.userId,
      ),
      valuesBefore: changedBefore,
      valuesAfter: changedAfter,
      deviceInfo: request.deviceInfo,
    ),
  );
}

/// خريطة الصلاحيات كما تُخزَّن — **الممنوحة وحدها، والغائب مرفوض**.
///
/// ★ **الترتيب ثابت** فتُنتج المجموعة نفسها القيمة نفسها في كل تشغيل
/// (`coding-standards.md` §2.7).
Map<String, Object?> _permissionMap(Set<Permission> permissions) {
  final List<Permission> ordered = permissions.toList()
    ..sort((Permission a, Permission b) => a.index - b.index);
  return <String, Object?>{for (final Permission p in ordered) p.name: true};
}

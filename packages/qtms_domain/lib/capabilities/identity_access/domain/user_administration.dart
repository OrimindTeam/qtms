/// قواعد إدارة المستخدمين والأدوار — **قبل أي كتابة**.
///
/// ★ **المصدر:** `FR-M1-01` (حقول المستخدم) · `FR-M1-02` (⛔ لا حقل كلمة
/// مرور ولا معرّف جهاز) · `FR-M1-03` (**الدور المُسنَد لا يُحذف**) ·
/// `FR-M1-11` و`BR-M1-02` (**لا يُعدَّل حساب المالك ولا يُعطَّل إلا بواسطته**) ·
/// `FR-M1-12` (**التعطيل بسبب نصّي، والحذف مرفوض دائماً**) ·
/// `identity-access-design.md` §5 الحالات 2 و5 و6.
///
/// ★★ **ولماذا في طبقة النطاق لا في الدالة السحابية (`ADR-0012`):** هذه
/// **قواعد عمل** لا تفاصيل نقل — ★ **ويستهلكها التطبيق أيضاً** ليمنع الإرسالَ
/// المرفوض سلفاً بدل رحلة شبكة تنتهي برفض. ⛔ **ونسختان تفترقان عند أول
/// تعديل**، فتصير الواجهة تسمح بما ترفضه السحابة أو العكس.
///
/// ⚠️ **وهي لا تُجيب عن «من يُصرَّح له بالإدارة أصلاً»** — ذاك مفاتيح
/// الكتالوج (`userCreate` · `userAmend` · `userDisable` · `roleWrite` ·
/// `roleDelete`)، **وتُفحَص في الدالة السحابية صراحةً** (`ADR-0013` القاعدة 3).
/// ما هنا **يبقى صحيحاً أياً كان صاحب الصلاحية**.
library;

import '../../../core/errors/app_error.dart';
import '../../../core/outcome.dart';
import '../../../core/text_normalization.dart';
import 'permission.dart';

/// ⛔★★ الحقول التي **لا وجود لها في سجل المستخدم إطلاقاً** — `FR-M1-02`.
///
/// ★ **ولماذا قائمة صريحة تُرفَض لا حقولٌ تُتجاهَل بصمت:** التجاهل الصامت
/// يجعل الواجهةَ ترسل كلمة مرور **فتظنّ أنها حُفظت**، ⟵ **ويصير غيابها
/// مفاجأةً وقت الحاجة**. والرفض الصريح يكشف الخلل عند أول محاولة.
///
/// ⚠️ **والمقارنة تُطبَّع حالةَ الأحرف** — فـ`Password` و`deviceID` مرفوضان
/// كـ`password` و`deviceId` سواءً بسواء.
const Set<String> forbiddenUserFields = <String>{
  'password',
  'passwordhash',
  'deviceid',
};

/// الحدّ الأدنى والأقصى لطول الاسم — `data-dictionary.md` §`users`.
const int userNameMinLength = 2;

/// الحدّ الأقصى لطول الاسم.
const int userNameMaxLength = 50;

/// بيانات مستخدم كما تصل من الواجهة — **قبل أي تحقق**.
final class UserProfileInput {
  /// ينشئ المدخلات.
  const UserProfileInput({
    required this.name,
    required this.email,
    this.phone,
    this.roleId,
    this.extraFields = const <String>{},
  });

  /// الاسم المعروض.
  final String name;

  /// البريد/اسم الدخول — ★ **وتفرّده تفرضه خدمة المصادقة** لا هذا الملف.
  final String email;

  /// الهاتف — **اختياري**، ويُطبَّع بـ[normalizePhone] عند وجوده.
  final String? phone;

  /// الدور — **قالب بداية اختياري** (`FR-M1-04`: الأدوار قوالب لا قيود).
  final String? roleId;

  /// ★ أسماء أي حقول إضافية وصلت في الحمولة — **تُفحَص مقابل الممنوعات**.
  final Set<String> extraFields;
}

/// ملف مستخدم مُتحقَّق منه — **بقيمه المُطبَّعة كما تُكتب**.
final class ValidatedUserProfile {
  /// ينشئ الملف المُتحقَّق منه.
  const ValidatedUserProfile({
    required this.name,
    required this.normalizedName,
    required this.email,
    required this.phone,
    required this.roleId,
  });

  /// الاسم كما أدخله المستخدم — **مقصوص الأطراف**.
  final String name;

  /// ★ الاسم المُطبَّع — **مصدر حقيقة واحد للتطبيع** (`IQ-013`).
  final String normalizedName;

  /// البريد **بحروف صغيرة ومقصوص** — فلا يُنشأ حسابان بفارق حالة أحرف.
  final String email;

  /// الهاتف مُطبَّعاً، أو `null` إن لم يُدخَل.
  final String? phone;

  /// الدور، أو `null`.
  final String? roleId;
}

/// يفحص ملف مستخدم عند الإنشاء أو التعديل — `FR-M1-01` · `FR-M1-02`.
///
/// يُرجِع [Failure] بـ[ValidationError] برمز القاعدة المخالَفة، ⛔ **ولا
/// يرمي** (`error-handling-strategy.md` §3 القاعدة 3).
Outcome<ValidatedUserProfile> validateUserProfile(UserProfileInput input) {
  // ① ⛔ الحقول الممنوعة أولاً — **قبل أي فحص محتوى**، فوجودُ أيٍّ منها
  //    يُبطل الطلب كاملاً بغضّ النظر عن صحة بقيته.
  for (final String field in input.extraFields) {
    if (forbiddenUserFields.contains(field.trim().toLowerCase())) {
      return const Failure<ValidatedUserProfile>(ValidationError('FR-M1-02'));
    }
  }

  final String name = input.name.trim();
  if (name.length < userNameMinLength || name.length > userNameMaxLength) {
    return const Failure<ValidatedUserProfile>(ValidationError('FR-M1-01'));
  }

  final String email = input.email.trim().toLowerCase();
  if (!_looksLikeEmail(email)) {
    return const Failure<ValidatedUserProfile>(ValidationError('FR-M1-01'));
  }

  // ★ الهاتف اختياري — والفارغ يُعامَل كغائب ⛔ لا كقيمة فارغة تُخزَّن.
  final String? rawPhone = input.phone?.trim();
  final String? phone = (rawPhone == null || rawPhone.isEmpty)
      ? null
      : normalizePhone(rawPhone);

  final String? rawRole = input.roleId?.trim();
  return Success<ValidatedUserProfile>(
    ValidatedUserProfile(
      name: name,
      // ★ **من مصدر الحقيقة الواحد** (`IQ-013`) — ⛔ ولا تطبيع محلي هنا.
      normalizedName: normalizeName(name),
      email: email,
      phone: phone,
      roleId: (rawRole == null || rawRole.isEmpty) ? null : rawRole,
    ),
  );
}

/// ★★ الحد الأدنى لطول كلمة المرور الأولية — `authentication-policy.md` §5.
///
/// ⚠️★★ **وكان البند 🔶 «حد أدنى معقول» بلا رقم** — ⟵ **ورُقِّم صراحةً في
/// المستند نفسِه عند اعتماد `CR-005`** (2026-08-31): ⛔ **ولا رقمَ يُخترَع
/// في الكود بلا مستندٍ يحمله.**
const int initialPasswordMinLength = 8;

/// ⛔⛔★★★ **كلمة مرور أولية مُتحقَّق منها** — `CR-005`.
///
/// ★★★ **ولماذا نوعٌ مستقل لا `String` عارٍ — وهو حارسٌ لا زينة:**
///
/// ① ★ **لا تُبنى إلا من [validateInitialPassword]** — ⟵ **فلا تصل خدمةَ
///    المصادقة قيمةٌ لم تمرّ بالفحص**، ⛔ **ولا يكفي أن يتذكّر كلُّ مُستدعٍ
///    أن يفحص.**
/// ② ⛔⛔★★★ **و[toString] لا تكشف القيمة أبداً** — ★ **ورسائلُ الأخطاء
///    وسجلاتُ التشخيص تستدعيها ضمناً**: ⟵ **فسلسلةٌ عارية كانت تتسرّب إلى
///    سجلٍّ أو إلى `diagnostic` بلا أن يقصد أحد**، ⛔ **وهو ما تمنعه قاعدة
///    «لا كلمة مرور في أي مستند ولا كود ولا رسالة» نصّاً.**
///
/// ⛔⛔ **ولا تُخزَّن في أي دفتر ولا قيدِ تدقيق ولا تُرجَع في ردّ عملية** —
/// `FR-M1-02` قائمٌ بلا مساس: **لا حقل كلمة مرور في سجل المستخدم.**
final class InitialPassword {
  const InitialPassword._(this.value);

  /// ★ القيمة كما تُمرَّر لخدمة المصادقة — ⛔ **ولا تُقرأ لغير ذلك.**
  final String value;

  /// ⛔⛔★★★ **ولا تكشف القيمة** — راجع البند ② أعلاه.
  @override
  String toString() => 'InitialPassword(***)';
}

/// يفحص كلمة المرور الأولية وتأكيدَها — `CR-005` · `authentication-policy.md` §5.
///
/// ★ **والتأكيد جزءٌ من الفحص لا من الواجهة:** ⟵ **خطأٌ مطبعيٌّ في كلمةٍ
/// لا يقرؤها أحدٌ بعدها يُنشئ حساباً لا يستطيع صاحبُه دخولَه**، ⛔ **ولا
/// مسارَ لاكتشافه إلا شكوى المستخدم.**
///
/// ⚠️ **ولا تُقصّ الأطراف:** ★ **الفراغ محرفٌ صالح في كلمة المرور**،
/// ⟵ **وقصُّه يجعل ما يُخزَّن غيرَ ما كتبه المدير** ⛔ **فيفشل الدخول.**
Outcome<InitialPassword> validateInitialPassword({
  required String password,
  required String confirmation,
}) {
  if (password.length < initialPasswordMinLength) {
    return const Failure<InitialPassword>(ValidationError('CR-005'));
  }
  if (password != confirmation) {
    return const Failure<InitialPassword>(ValidationError('CR-005'));
  }
  return Success<InitialPassword>(InitialPassword._(password));
}

/// ★★ يفحص أن المُنفِّذ يملك حقّ المساس بحساب المستهدَف — `BR-M1-02`.
///
/// `FR-M1-11`: «**لا يُعدَّل حساب المالك ولا يُعطَّل إلا بواسطته**».
///
/// ⚠️ **وهذا قيدٌ يعلو على الصلاحية لا يُستبدَل بها:** من يملك `userAmend`
/// يعدّل كل حساب **إلا حساب المالك**. ⟵ ★ **وبدونه يصير `userAmend` طريقاً
/// لتعطيل المالك ثم الاستيلاء على النظام** — وهو أخطر تصعيد امتياز ممكن.
Outcome<void> validateOwnerAccountGuard({
  required String actorUserId,
  required String targetUserId,
  required String ownerUserId,
}) {
  final String owner = ownerUserId.trim();
  // ⛔ **مالكٌ غير معروف = منعٌ لا سماح** — الرفض الافتراضي (القاعدة 6).
  //    ★ ولو سُمح عند غياب المعرّف لصار **إسقاطُ الإعداد** طريقاً للالتفاف.
  if (owner.isEmpty) {
    return const Failure<void>(ValidationError('BR-M1-02'));
  }
  if (targetUserId != owner) return const Success<void>(null);
  // ★ المالك يعدّل حسابه هو — وهو الاستثناء الوحيد المنصوص عليه.
  if (actorUserId == owner) return const Success<void>(null);
  return const Failure<void>(ValidationError('BR-M1-02'));
}

/// طلب تعطيل مستخدم.
final class UserDisableRequest {
  /// ينشئ الطلب.
  const UserDisableRequest({
    required this.actorUserId,
    required this.targetUserId,
    required this.ownerUserId,
    required this.reason,
  });

  /// المُنفِّذ.
  final String actorUserId;

  /// المستهدَف بالتعطيل.
  final String targetUserId;

  /// معرّف المالك — من إعداد البيئة ⛔ لا من الحمولة.
  final String ownerUserId;

  /// ★ **السبب النصي إلزامي** — `FR-M1-12`.
  final String reason;
}

/// تعطيل مُتحقَّق منه — **بسببه المقصوص كما يُكتب**.
final class ValidatedUserDisable {
  /// ينشئ النتيجة.
  const ValidatedUserDisable({required this.targetUserId, required this.reason});

  /// المستهدَف.
  final String targetUserId;

  /// السبب مقصوص الأطراف — ⛔ وغير فارغ.
  final String reason;
}

/// يفحص طلب تعطيل — `FR-M1-12` · `BR-M1-02` · `identity-access-design.md` §5.
///
/// ★ **الترتيب مقصود:** «لا يعطّل نفسه» ثم حارس المالك ثم السبب — فالأولان
/// يمنعان الطلب كاملاً، ولا معنى لفحص سببِ طلبٍ مرفوضٍ أصلاً.
Outcome<ValidatedUserDisable> validateUserDisable(UserDisableRequest request) {
  // ① ⛔ **لا مستخدم يعطّل نفسه.** ★ ولا يقاس على «لا يعدّل صلاحيات نفسه»
  //    فحسب: تعطيلُ النفس **يقفل الحساب فوراً بلا رجعة من داخل التطبيق**،
  //    ⟵ ولو كان المُنفِّذ آخرَ من يملك `userDisable` **لَقفل النظام على
  //    نفسه**. ★ والمالك داخلٌ في المنع — فحسابه لا مسار لإعادة تفعيله.
  if (request.actorUserId == request.targetUserId) {
    return const Failure<ValidatedUserDisable>(ValidationError('FR-M1-12'));
  }

  // ② حارس المالك — `BR-M1-02`.
  final Outcome<void> guard = validateOwnerAccountGuard(
    actorUserId: request.actorUserId,
    targetUserId: request.targetUserId,
    ownerUserId: request.ownerUserId,
  );
  if (guard case Failure<void>(:final AppError error)) {
    return Failure<ValidatedUserDisable>(error);
  }

  // ③ ★ **السبب النصي غير الفارغ** — `FR-M1-12` · القاعدة 5 في
  //    `security-requirements.md` §2. ⛔ والفراغات وحدها ليست سبباً.
  final String reason = request.reason.trim();
  if (reason.isEmpty) {
    return const Failure<ValidatedUserDisable>(ValidationError('FR-M1-12'));
  }

  return Success<ValidatedUserDisable>(
    ValidatedUserDisable(targetUserId: request.targetUserId, reason: reason),
  );
}

/// ★★ **إحصاءٌ مقيس لمن يشير إلى الدور** — ⛔ **لا قيمةٌ مخزَّنة ولا كاش**.
///
/// ★ **وهو جوهر حسم `IQ-018` (الخيار ب، 2026-08-24):** «المقصود بـ**غير
/// مُسنَد** أن النظام **يتحقق فعلياً** من عدم وجود أي مستخدم يشير إلى
/// `roleId` قبل الحذف، **ولا يعتمد على قيمة مخزنة أو افتراض محلي**».
///
/// ⚠️⚠️ **ولذلك لا مُنشِئ افتراضي له ولا قيمة صفرية جاهزة:** لو أمكن بناؤه
/// «فارغاً» لصار **نسيانُ الاستعلام** طريقاً صامتاً إلى حذف دورٍ مُسنَد.
/// ⟵ ★ **فالمُنشِئ الوحيد اسمُه [RoleAssignmentCensus.measured]**، وهو
/// **يُلزم مُستدعيه بأن يذكر من أين جاءت القائمة.**
final class RoleAssignmentCensus {
  /// ينشئ الإحصاء من **نتيجة استعلامٍ فعلي** على `users`.
  ///
  /// [assignedUserIds] معرّفات المستخدمين الذين `roleId` لديهم هو الدور
  /// المعنيّ — ★ **كما أعادها الاستعلام** ⛔ لا كما ظنّتها الواجهة.
  const RoleAssignmentCensus.measured(this.assignedUserIds);

  /// المعرّفات المطابقة — ⚠️ **وقد تكون مقتطعة بحدّ الاستعلام**، فالسؤال
  /// «هل يوجد» لا «كم عددهم».
  final List<String> assignedUserIds;

  /// هل الدور مُسنَد فعلاً؟
  bool get isAssigned => assignedUserIds.isNotEmpty;
}

/// ★ يفحص حذف دور — `FR-M1-03`: **الدور المُسنَد لا يُحذف**.
///
/// ★★ **وبعد حسم `IQ-018` صار المرفوض هو الحذف وحده لا العملية:** الدور
/// **غير المُسنَد يُحذف حذفاً فعلياً** من قاعدة البيانات — ⛔ **بلا حقل
/// `isActive` للدور وبلا تحويل `roleDelete` إلى تعطيل.**
///
/// ⚠️ **ولماذا يبقى المُسنَد ممنوعاً:** الدور **قالب بداية** (`FR-M1-04`)،
/// وحذفُه مع إسنادِه يترك مستخدمين بمرجعٍ ميت — ⟵ **فتُعرَض أدوارهم فارغةً
/// ولا يُعرَف ما كان قالبهم**، وتنكسر «مقارنة المستخدم بدوره» (`FR-M1-16`).
/// ★ **ويستوي في المنع المُسنَدُ لواحد والمُسنَدُ لعشرة** — فالضرر واحد.
Outcome<void> validateRoleDeletion(RoleAssignmentCensus census) =>
    census.isAssigned
        ? const Failure<void>(ValidationError('FR-M1-03'))
        : const Success<void>(null);

/// دور مُتحقَّق منه — **بقيمه المُطبَّعة كما تُكتب**.
final class ValidatedRole {
  /// ينشئ الدور المُتحقَّق منه.
  ValidatedRole({
    required this.name,
    required this.normalizedName,
    required this.description,
    required Set<Permission> permissions,
  }) : permissions = Set<Permission>.unmodifiable(permissions);

  /// اسم الدور مقصوصاً.
  final String name;

  /// ★ الاسم المُطبَّع — **وعليه يُفحَص التفرّد** (`FR-M1-03`: الاسم فريد).
  final String normalizedName;

  /// الوصف، أو `null` — ★ **اختياري نصّاً** (`FR-M1-03`).
  final String? description;

  /// ★★ **قالب الصلاحيات** — `FR-M1-03`: «إنشاء دور **بقالب صلاحيات كامل**»
  /// (`data-dictionary.md` §`roles` — الحقل `permissionTemplate`).
  ///
  /// ⚠️⚠️ **وقالبٌ لا منحٌ — والفرق أمنيٌّ لا لفظي:** كتابة مفتاح هنا **لا
  /// تمنح أحداً شيئاً**. ⟵ ★ **المنح مسارُه `grantPermissions` وحده**،
  /// وهو الذي يفرض `BR-M1-03` («لا يمنح المُنفِّذ ما لا يملك») **على
  /// المانح لحظةَ المنح**. ⛔ **فلا تصعيد امتياز عبر قالب**: أخطرُ قالبٍ
  /// يبقى بلا أثر حتى يطبّقه **من يملك كل ما فيه أصلاً.**
  ///
  /// ★ **وهو أساس «مقارنة المستخدم بدوره»** (`FR-M1-05` · `FR-M1-16`).
  final Set<Permission> permissions;
}

/// يفحص إنشاء دور أو تعديله — `FR-M1-03`.
Outcome<ValidatedRole> validateRole({
  required String name,
  String? description,
  Set<Permission> permissions = const <Permission>{},
}) {
  final String trimmed = name.trim();
  if (trimmed.length < userNameMinLength ||
      trimmed.length > userNameMaxLength) {
    return const Failure<ValidatedRole>(ValidationError('FR-M1-03'));
  }
  final String? rawDescription = description?.trim();
  return Success<ValidatedRole>(
    ValidatedRole(
      name: trimmed,
      normalizedName: normalizeName(trimmed),
      // ★ **الوصف اختياري صراحةً** — والفارغ غيابٌ ⛔ لا نصٌّ فارغ يُخزَّن.
      description: (rawDescription == null || rawDescription.isEmpty)
          ? null
          : rawDescription,
      // ★ **والقالب الفارغ قالبٌ صحيح** — `FR-M1-04`: «الأدوار قوالب بداية
      //   لا قيود»، ⟵ **فدورٌ بلا صلاحيات دورُ بدايةٍ لا خطأ إدخال.**
      permissions: permissions,
    ),
  );
}

/// فحص بنيوي للبريد — ⛔ **وليس تحققاً من وجوده**.
///
/// ★ **متعمَّد البساطة:** التحقق الحقيقي من البريد **تملكه خدمة المصادقة**
/// (وهي التي تفرض تفرّده أيضاً)، ⟵ **وتعبيرٌ نمطي معقّد هنا يرفض بريداً
/// صحيحاً نادراً** ⛔ بلا أن يقبل واحداً خاطئاً تقبله الخدمة. فالغرض **منع
/// الخطأ الظاهر وحده**: لا فراغ · وعلامة واحدة · ونطاق بنقطة.
bool _looksLikeEmail(String value) {
  if (value.isEmpty || value.contains(' ')) return false;
  final List<String> parts = value.split('@');
  if (parts.length != 2) return false;
  final String local = parts[0];
  final String domain = parts[1];
  if (local.isEmpty || domain.isEmpty) return false;
  if (!domain.contains('.')) return false;
  // ⛔ نقطة في الطرف تعني نطاقاً ناقصاً (`name@site.`) — وهو خطأ ظاهر.
  return !domain.startsWith('.') && !domain.endsWith('.');
}

/// عقود مستودعات الهوية — ★ **تعريفاً لا تنفيذاً** (`ADR-0009`: «واجهات
/// المستودعات (تعريفاً لا تنفيذاً)» داخل طبقة النطاق).
///
/// ⛔ **ولا تعرف هذه الملفات أي حزمة منصة** — التنفيذ في
/// `lib/capabilities/identity_access/infrastructure/` (`ADR-0012`).
library;

import '../../../core/outcome.dart';
import 'auth_session.dart';
import 'permission.dart';
import 'source_scope.dart';
import 'user_administration.dart';

/// سبب رفض الدخول — ★ **تصنيفٌ لا نصّ**.
///
/// ⛔ **ولا رسالة عربية هنا:** `error-handling-strategy.md` §3 القاعدة 2
/// (**STATIC**) تُلزم أن تأتي كل رسالة من الكتالوج المعتمد، ⟵ **والربط
/// مسؤولية طبقة العرض وحدها.**
enum SignInRejection {
  /// بريد أو كلمة مرور غير صحيحة — أشيع حالة، ⛔ **ولا نصّ معتمد لها بعد.**
  invalidCredentials,

  /// الحساب معطَّل — `ERR_AUTH_004` · `authentication-policy.md` §7 البند 2.
  accountDisabled,

  /// قفل مؤقت بعد محاولات فاشلة — `ERR_AUTH_005` · `BR-M1-05`.
  lockedOut,

  /// لا اتصال — `ERR_CONN_001` · ⚠️ **والحفظ معطَّل أصلاً** (`ADR-0003`).
  noConnection,

  /// خدمات المنصة غائبة — `ERR_CONN_002` · `C-04` · `FR-SYS-27`.
  platformUnavailable,

  /// فشل غير متوقَّع — يُسجَّل تفصيلياً **بلا بيانات حساسة** (§3 القاعدة 4).
  unexpected,
}

/// نتيجة محاولة الدخول.
sealed class SignInResult {
  const SignInResult();
}

/// قُبلت المحاولة — ★ **والجلسة تصل عبر تدفّق الهوية لا من هنا**، فمصدر
/// حقيقة واحد لحالة الدخول.
final class SignInAccepted extends SignInResult {
  const SignInAccepted();
}

/// رُفضت المحاولة بسبب مصنَّف.
final class SignInRejected extends SignInResult {
  const SignInRejected(this.reason);

  final SignInRejection reason;
}

/// مستودع المصادقة — ⛔ **ولا يُخزِّن كلمة مرور** (`identity-access-design.md`
/// §2: «لا تُخزِّن كلمة مرور — تديرها خدمة المصادقة بالكامل»).
abstract interface class AuthRepository {
  /// تدفّق الهوية — `null` تعني **لا جلسة**.
  ///
  /// ★ **تدفّقٌ لا استعلام لحظي:** `FR-M1-15` تُلزم أن **يُبطل التعطيل
  /// الجلسة فوراً**، ⟵ **والدفع من الخدمة هو ما يجعل «فوراً» صحيحة.**
  Stream<AuthenticatedIdentity?> watchIdentity();

  /// محاولة دخول ببريد وكلمة مرور.
  Future<SignInResult> signIn({
    required String email,
    required String password,
  });

  /// خروج — **يُبطل الجلسة على الجهاز** (`authentication-policy.md` §4).
  Future<void> signOut();
}

/// مستودع بطاقة المستخدم — ★ **مصدر الصلاحيات بعد `ADR-0016`.**
abstract interface class UserCardRepository {
  /// تدفّق بطاقة [userId] — `null` تعني **بلا بطاقة ⟵ بلا صلاحية إطلاقاً**
  /// (`authentication-policy.md` §7 البند 7).
  ///
  /// ⚠️ **وتدفّقٌ لا قراءة واحدة عمداً:** سحب صلاحية أو تعطيل حساب **ينعكس
  /// في العملية التالية بلا إعادة دخول** (§3 · `ADR-0016`).
  ///
  /// ⛔ **ولا يقرأ بطاقة غيره:** القاعدة `allow read: if isSignedIn() &&
  /// request.auth.uid == userId` — ★ **وقراءة بطاقة أخرى تُرفَض من القاعدة**.
  Stream<UserCard?> watchCard(String userId);
}

/// ★★ **`IQ-015`: مستودع دليل المستخدمين** — قراءة بطاقات **غيرك**.
///
/// ⛔ **ومنفصل عن [UserCardRepository] عمداً ولا يُدمَج فيه:** ذاك يقرأ
/// **بطاقتك أنت** بشرط `request.auth.uid == userId` ⛔ **بلا صلاحية**،
/// وهذا يقرأ **بطاقات الآخرين** بشرط `perm('userView')`. ⟵ ★ **وشرطاهما في
/// القاعدة مختلفان**، فدمجُهما يُخفي أن أحدهما يحتاج صلاحية والآخر لا.
///
/// ⚠️ **وأثرٌ معلَن ومقبول بقرار `IQ-015`:** البطاقة **تحمل خريطة صلاحيات
/// صاحبها**، ⟵ **فمن يملك `userView` يرى صلاحيات الجميع.**
abstract interface class UserDirectoryRepository {
  /// تدفّق كل بطاقات المستخدمين — ⛔ **ويُرفَض كاملاً بلا `userView`**.
  ///
  /// ★ **تدفّقٌ لا قراءة واحدة**، فتعطيلُ مستخدمٍ من جهازٍ آخر **يظهر في
  /// القائمة فوراً** ⛔ بلا إعادة فتح الشاشة.
  Stream<List<UserCard>> watchAll();
}

/// ★ **`IQ-015`: مستودع إدارة المستخدمين** — `identity-access-design.md` §3.
///
/// ⛔★★ **وكل عملية هنا تمرّ بدالة سحابية مستدعاة** (`ADR-0013`) —
/// **ولا كتابة مباشرة على `users`**: القاعدة `allow write: if false`.
/// ⟵ ★ **فالواجهة تطلب ولا تكتب**، والقرار والقيد في السحابة معاً.
abstract interface class UserAdminRepository {
  /// ينشئ مستخدماً ويُرجِع معرّفه.
  ///
  /// ⛔ **ولا يمنح صلاحيةً** — المنح مسارُه [grantAccess] بقواعده.
  ///
  /// ⚠️★★★ **و[password] كلمةٌ أوليةٌ يضبطها المدير** — `CR-005` (2026-08-31):
  /// ⟵ **ويغيّرها صاحبُها متى شاء** ⛔ **بلا إجبارٍ عند أول دخول وبلا مهلة.**
  /// ⛔⛔ **ولا تُخزَّن في `users/{userId}` ولا في قيد التدقيق ولا تُرجَع في
  /// الردّ** — ★ **تعبر إلى خدمة المصادقة وحدها** (`FR-M1-02` قائم).
  ///
  /// ⚠️ **وكان المسارُ رابطَ استرجاعٍ يُرسَل** — ★ **والرابط باقٍ مساراً
  /// لتغييرها لاحقاً** ⛔ **ولم يعد المسارَ الوحيد لضبطها.**
  Future<Outcome<String>> create(
    ValidatedUserProfile profile, {
    required InitialPassword password,
  });

  /// يعدّل بيانات مستخدم — ★ **بسببٍ نصّي إلزامي** (`ADR-0004`).
  Future<Outcome<void>> update({
    required String userId,
    required ValidatedUserProfile profile,
    String? amendReason,
  });

  /// يعطّل مستخدماً — ★ **في البطاقة وخدمة المصادقة معاً** (`IQ-017`).
  ///
  /// ⛔ **ولا حذف إطلاقاً** (`FR-M1-12`).
  Future<Outcome<void>> disable({
    required String userId,
    required String reason,
  });

  /// يمنح صلاحيات ونطاقاً — ★ **بقواعد `BR-M1-03` و`FR-M1-08`**.
  Future<Outcome<void>> grantAccess({
    required String userId,
    required Set<Permission> permissions,
    required SourceScope scope,
  });
}

/// ★ **`IQ-015`: مستودع الأدوار** — `identity-access-design.md` §3.
///
/// ✅★★ **و[delete] فُتحت بحسم `IQ-018` (الخيار ب، 2026-08-24):** `roleDelete`
/// **حذفٌ فعلي للدور غير المُسنَد وحده** — ⛔ **لا تعطيل، ولا حقل حالة
/// للدور.** والدور المُسنَد **يُرفَض حذفه صراحةً**، ★ **والرفض في العملية
/// السحابية** ⛔ لا في الواجهة (`ADR-0013` القاعدة 3).
abstract interface class RoleAdminRepository {
  /// تدفّق الأدوار — ★ **مقروءة لكل مستخدم مُصادَق** (`allow read: if isSignedIn()`).
  Stream<List<RoleCard>> watchAll();

  /// ينشئ دوراً.
  Future<Outcome<void>> create(ValidatedRole role);

  /// يعدّل دوراً — ★ **بسببٍ نصّي إلزامي** (`ADR-0004`).
  Future<Outcome<void>> update({
    required String roleId,
    required ValidatedRole role,
    String? amendReason,
  });

  /// ★★ **يحذف دوراً غير مُسنَد حذفاً فعلياً** — `IQ-018` · `FR-M1-03`.
  ///
  /// ⛔★★ **ولا تفحص الواجهة الإسناد نيابةً عن السحابة:** الفحص **استعلامٌ
  /// فعلي على `users` داخل المعاملة** (`RoleAssignmentCensus.measured`)،
  /// ⟵ **فلا كاش ولا قيمة مخزَّنة تُقرِّر مصير مستند.**
  ///
  /// [amendReason] ★ **سبب نصّي إلزامي** — والحذف لا رجعة فيه، ⟵ **فقيدٌ
  /// بلا سبب يترك دوراً اختفى بلا تفسير.**
  Future<Outcome<void>> delete({
    required String roleId,
    String? amendReason,
  });
}

/// بطاقة دور — مستند `roles/{roleId}` (`data-dictionary.md` §`roles`).
///
/// ⛔★★ **ولا حقل «مُسنَد» فيها — وهذا حسمُ `IQ-018` حرفياً:** «⛔ ولا
/// يُنشأ حقل `isActive` للدور»، **و«لا يعتمد على قيمة مخزنة أو افتراض
/// محلي»**. ⟵ ★ **فالإسناد يُشتقّ من بيانات المستخدمين الفعلية** حيث
/// يُحتاج للعرض، **ويُقاس بالاستعلام** حيث يُحسَم به الحذف.
final class RoleCard {
  /// ينشئ البطاقة.
  RoleCard({
    required this.roleId,
    required this.name,
    this.description,
    Set<Permission> permissionTemplate = const <Permission>{},
  }) : permissionTemplate = Set<Permission>.unmodifiable(permissionTemplate);

  /// معرّف الدور.
  final String roleId;

  /// اسمه — **فريد**.
  final String name;

  /// وصفه — ★ **اختياري** (`FR-M1-03`).
  final String? description;

  /// ★★ **قالب صلاحياته** — `FR-M1-03` · `data-dictionary.md` §`roles`.
  ///
  /// ★ **وعليه تقوم «مقارنة المستخدم بدوره»** (`FR-M1-05` · `FR-M1-16`):
  /// ما زاد المستخدمُ على قالبه **منحٌ فردي**، وما نقص عنه **سحبٌ فردي**.
  ///
  /// ⚠️ **وقالبٌ لا منح** — راجع [ValidatedRole.permissions].
  final Set<Permission> permissionTemplate;
}

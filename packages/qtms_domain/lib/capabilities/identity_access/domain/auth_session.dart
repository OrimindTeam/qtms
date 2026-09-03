/// الجلسة المُصادَقة — ★ **تجميع مصدرَي الحقيقة بعد `ADR-0016`**.
///
/// ★ **ولماذا مصدران لا واحد:** `authentication-policy.md` §1 يفصلهما نصّاً:
/// **الصلاحيات** مصدرها **`users/{userId}.permissions`** ⛔ **لا الرمز**،
/// **ونطاق المصادر** مصدره **الرمز** (المطالبات) — ⟵ **فالجلسة تُبنى منهما
/// معاً، وأي طرف ناقص يُغيّر النتيجة.**
///
/// ⚠️ **وهذا الملف لا يُقرِّر تفويضاً** — `identity-access-design.md` §2:
/// «لا تُقرِّر تفويضاً — القرار في قواعد الحماية؛ ودورها **إظهار/إخفاء
/// فقط**». ★ **فكل `has()` هنا سؤال عرض**، ⛔ **والحماية الحقيقية في
/// `firestore.rules` وحدها** (`ADR-0002` · `RISK-02`).
library;

import '../../../core/errors/app_error.dart';
import '../../../core/outcome.dart';
import 'permission.dart';
import 'source_scope.dart';

/// ما تُعطيه خدمة المصادقة وحدها — ★ **الهوية ونطاق المصادر لا الصلاحيات.**
final class AuthenticatedIdentity {
  const AuthenticatedIdentity({
    required this.userId,
    required this.sourceScope,
    this.email,
  });

  /// معرّف المستخدم في خدمة المصادقة — وهو معرّف بطاقته أيضاً.
  final String userId;

  /// ★★★ **بريدُ الحساب كما تعرفه خدمة المصادقة** — `AM-012` §5.1.
  ///
  /// ═══════════════════════════════════════════════════════════════════════
  /// ⛔⛔★★★ **وهو المصدرُ الأوثق للبريد لا بطاقةُ `users/{userId}`:**
  /// ★ **هذا هو البريدُ الذي *يُسجَّل به الدخول فعلاً*** — ⟵ **وهو ما تحتاجه
  /// إعادةُ المصادقة عند تفعيل البصمة** ([`ADR-0024`] الشرط 4) **وعند تغيير
  /// كلمة المرور** ([`CR-012`]).
  ///
  /// ⚠️⚠️★★★ **وعطلٌ مقيسٌ حيّاً هو ما أضافه — ⛔ لا احتياط:** ★ **قِيست شاشةُ
  /// «الملف الشخصي» على المحاكي فظهرت *بلا سطر بريدٍ إطلاقاً*** — ⟵ **لأن
  /// حقل `email` غائبٌ في بطاقة ذلك الحساب**، ⛔ **بينما الحسابُ دخل ببريدٍ
  /// صحيحٍ قبل ثانية.** ⟹ ★ **فبطاقةُ الدفتر تصف المستخدم**، **وخدمةُ
  /// المصادقة تملك هويةَ دخوله** — ★ **والثانيةُ هي المطلوبة هنا.**
  ///
  /// ⛔⛔ **ولا قرارَ تفويضٍ يُبنى عليه** — ★ **الصلاحياتُ من البطاقة وحدها**
  /// (`ADR-0016`)، ⟵ **والبريدُ هويةُ دخولٍ وحقلُ عرض** ⛔ **لا مفتاحُ وصول.**
  /// ═══════════════════════════════════════════════════════════════════════
  final String? email;

  /// نطاق المصادر من المطالبات — ★ **الباقي في الرمز بعد `ADR-0016`.**
  ///
  /// ⚠️ **و`null` تعني «لا مصدر متاح» لا «كل المصادر»** — مرآةً لقراءة
  /// القاعدة `claims().get('sourceScope', [])` (`source_scope_claim.dart`).
  final SourceScope? sourceScope;
}

/// بطاقة المستخدم — مستند `users/{userId}` (`data-dictionary.md` §1).
final class UserCard {
  UserCard({
    required this.userId,
    required this.name,
    required Set<Permission> permissions,
    required this.isActive,
    this.email,
    this.roleId,
    this.roleName,
    this.disableReason,
    this.sourceScope,
  }) : permissions = Set<Permission>.unmodifiable(permissions);

  final String userId;
  final String name;
  final String? email;
  final String? roleId;
  final String? roleName;

  /// ★ **مصدر التفويض نفسه بعد `ADR-0016`** — تقرأها القاعدة بـ`get()`.
  final Set<Permission> permissions;

  final bool isActive;
  final String? disableReason;

  /// ★ **نطاق مصادره كما في بطاقته** — `data-dictionary.md` §`users`.
  ///
  /// ⚠️⚠️ **وهذه نسخةٌ للعرض لا مصدرُ تفويض:** `ADR-0016` يُبقي **النطاق
  /// النافذ في رمز الدخول** (`AuthenticatedIdentity.sourceScope`)، ⟵
  /// **وهذه تُقرأ لتُعرَض في شاشة تخصيص الصلاحيات وحدها** ⛔ **ولا يُقرَّر
  /// بها وصولٌ إلى مصدر أبداً.**
  ///
  /// `null` تعني **«لا نطاق في البطاقة»** ⛔ لا «كل المصادر».
  final SourceScope? sourceScope;
}

/// جلسة جاهزة للاستعمال في الشاشات.
final class AuthSession {
  AuthSession({
    required this.userId,
    required this.displayName,
    required Set<Permission> permissions,
    required this.sourceScope,
    this.email,
    this.roleName,
  }) : permissions = Set<Permission>.unmodifiable(permissions);

  final String userId;
  final String displayName;

  /// ★★★ **بريدُ صاحب الجلسة** — `AM-012` §5.1 · [`CR-012`] `FR-M1-16`.
  ///
  /// ⛔⛔★★★ **ومن بطاقته هو وحدَها** — ★ **ولا يُقرأ من غيرها:** ⟵ **وهو
  /// الحقلُ الذي تعرضه شاشةُ «الملف الشخصي» تحت الاسم**، ★ **ويُستعمل بريداً
  /// للدخول عند تفعيل البصمة** ([`ADR-0024`] الشرط 4).
  ///
  /// ⚠️ **و`null` تعني «لا بريد في البطاقة»** — ★ **حالةٌ ممكنة**: ⟵ **فلا
  /// يُعرَض سطرُ البريد أصلاً**، ⛔ **ولا يُكتب «بلا بريد» في شاشةِ صاحبه.**
  ///
  /// ⛔⛔ **ولا قرارَ تفويضٍ يُبنى عليه** — ★ **الصلاحياتُ من [permissions]**
  /// (`ADR-0016`)، ⟵ **والبريدُ حقلُ عرضٍ وهويةِ دخول** ⛔ **لا مفتاحُ وصول.**
  final String? email;

  final String? roleName;
  final Set<Permission> permissions;

  /// ⚠️ **`null` تعني «لا مصدر متاح»** — راجع [AuthenticatedIdentity].
  final SourceScope? sourceScope;

  /// هل يملك المستخدم [permission]؟ — ★ **سؤال عرض لا قرار تفويض.**
  bool has(Permission permission) => permissions.contains(permission);

  /// هل يقع [sourceId] ضمن نطاقه؟ — `FR-M1-07`.
  bool canAccessSource(String sourceId) =>
      sourceScope?.canAccessSource(sourceId) ?? false;
}

/// يبني الجلسة من الهوية والبطاقة — ★ **وهو موضع قاعدتين من
/// `authentication-policy.md` §7 لا تفصيل تنفيذ.**
///
/// ① **البند 2 — حساب معطَّل ⟵ رفض فوري:** يُرجِع [SessionError]،
/// ⟵ **وطبقة العرض تُخرِج المستخدم وتعرض `ERR_AUTH_004`** (`FR-M1-15`).
///
/// ② ★ **البند 7 — حساب بلا بطاقة ⟵ بلا صلاحية إطلاقاً:** ⛔ **وليس رفضاً
/// للجلسة.** ★ **وهذه ليست حالة نظرية:** حساب المالك نفسه يعيش بلا بطاقة
/// حتى يُشغَّل رَنبوك الإقلاع (`RB-bootstrap-owner-permissions.md`) —
/// ⟵ **فرفضُ الدخول كان سيمنع الإقلاع أصلاً**، والصحيح **دخولٌ بلا صلاحية**.
///
/// ⛔ **وبطاقة بمعرّف مغاير للهوية تُرفَض** — تعارضٌ لا يُتسامَح معه في
/// مصدر تفويض.
Outcome<AuthSession> resolveAuthSession({
  required AuthenticatedIdentity identity,
  required UserCard? card,
}) {
  if (card == null) {
    return Success<AuthSession>(
      AuthSession(
        userId: identity.userId,
        displayName: identity.userId,
        // ★ **والبريدُ من الهوية** — ⟵ **فحسابٌ بلا بطاقة يبقى معروفَ
        //   البريد** (حالةُ إقلاع المالك، البند ② أدناه).
        email: identity.email,
        permissions: const <Permission>{},
        sourceScope: identity.sourceScope,
      ),
    );
  }
  if (card.userId != identity.userId) {
    return const Failure<AuthSession>(SessionError());
  }
  if (!card.isActive) {
    return const Failure<AuthSession>(SessionError());
  }
  return Success<AuthSession>(
    AuthSession(
      userId: identity.userId,
      displayName: card.name,
      // ★★★ **والبريدُ من البطاقة، وإلا فمن خدمة المصادقة** — `AM-012` §5.1.
      //
      // ⛔⛔★★★ **والترتيبُ مقصود لا اعتباطي:** ★ **بطاقةُ الدفتر هي ما يراه
      //    المدير في شاشة المستخدمين** ⟵ **فهي الأولى متى وُجدت**، ★ **وبريدُ
      //    خدمة المصادقة احتياطٌ لا يسقط** — ⟵ **وحسابٌ سُجِّل بلا حقل بريدٍ
      //    في بطاقته يبقى معروفَ البريد في ملفّه الشخصي** (⚠️ **حالةٌ قِيست
      //    حيّاً على المحاكي 2026-09-02** ⛔ **لا مفترَضة**).
      email: card.email ?? identity.email,
      roleName: card.roleName,
      permissions: card.permissions,
      sourceScope: identity.sourceScope,
    ),
  );
}

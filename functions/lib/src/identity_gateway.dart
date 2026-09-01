/// بوابة خدمة المصادقة — **التحقق من رمز الدخول وكتابة المطالبات**.
///
/// ★ **لماذا عبر واجهة المنصة لا بفكّ الرمز محلياً:** فكّ رمز موقَّع محلياً
/// يستلزم مكتبة تعمّي وتحديثاً دورياً لمفاتيح النشر العامة، **وكلاهما سطح
/// خطأ أمني إضافي في أخطر مسار في النظام**. والاستدعاء هنا يجعل **الخدمة
/// نفسها** هي من يحكم على الرمز — بلا اعتمادية تعمية ولا مفاتيح نحفظها.
///
/// ⚠️ **مقايضته المعلَنة:** رحلة شبكة إضافية لكل استدعاء. **مقبولة** لأن
/// هذه العمليات نادرة (منح صلاحية · تحديد نطاق) لا في مسار الإدخال اليومي.
///
/// ★ **والاعتماد على بيانات الاعتماد الافتراضية (ADC)** — ⛔ لا مفتاح ولا
/// سرّ في أي ملف (`secrets-management-policy.md` · `coding-standards.md` §2.4).
///
/// ⚠️ **تحقق مطلوب قبل النشر الإنتاجي:** سلوك هذه الواجهة على رمز منتهٍ
/// وعلى حساب معطَّل **يُختبَر حيّاً** — والاختبارات هنا تغطي منطقنا لا وعد
/// المنصة (`authentication-policy.md` §7 البندان 1 و2).
library;

import 'package:googleapis/identitytoolkit/v3.dart' as idtk;
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:http/http.dart' as http;
import 'package:qtms_domain/qtms_domain.dart';

import 'identity_claims.dart';

/// ★ **رسائل خدمة المصادقة التي تعني «الرمز/الحساب لا الخدمة»** — وهي وحدها
/// ما يُصنَّف. ⛔ وما عداها **يُعاد رميه كما هو**.
///
/// ⚠️ **ولماذا قائمة صريحة لا «كل خطأ 400»:** تصنيفُ انقطاعٍ حقيقي في الخدمة
/// على أنه «جلسة منتهية» يُرسِل المستخدمَ ليُعيد الدخول مراراً بلا جدوى،
/// **ويُخفي عطلاً حقيقياً** عن السجل والمراقبة. فالابتلاع الواسع هنا أسوأ من
/// الخطأ الظاهر (`coding-standards.md` §2.5 · `error-handling-strategy.md`).
const Set<String> identityTokenFailureMessages = <String>{
  'INVALID_ID_TOKEN',
  'TOKEN_EXPIRED',
  'USER_NOT_FOUND',
  'INVALID_LOCAL_ID',
};

/// يصنّف خطأ خدمة المصادقة — **دالة خالصة تُختبَر بلا سحابة**.
///
/// يُرجِع `null` لما **لا يُصنَّف**، وهو ما يجب أن يُعاد رميه خاماً.
IdentityFailure? classifyIdentityApiError(Object error) {
  if (error is! idtk.DetailedApiRequestError) return null;
  // ⛔ خطأ خادم (5xx) عطلٌ لا مشكلةَ رمز — ولا يُصنَّف أبداً.
  if (error.status != 400 && error.status != 401) return null;
  final String message = (error.message ?? '').toUpperCase();
  for (final String known in identityTokenFailureMessages) {
    if (message.contains(known)) return IdentityFailure.invalidToken;
  }
  return null;
}

/// لقطة بطاقة المستخدم `users/{userId}` كما هي في الدفتر الآن.
final class UserCardSnapshot {
  /// ينشئ اللقطة.
  const UserCardSnapshot({
    required this.permissions,
    required this.isActiveField,
  });

  /// ★ **بطاقة غائبة أصلاً** — ⛔ بلا صلاحية وبلا حقل حالة.
  static const UserCardSnapshot absent = UserCardSnapshot(
    permissions: <Permission>{},
    isActiveField: null,
  );

  /// ★ **`ADR-0016`: صلاحياته من بطاقته** — ⛔ لا من رمزه.
  final Set<Permission> permissions;

  /// ★★ حقل `isActive` **كما هو حرفياً**، و`null` تعني **الحقل غائب**.
  ///
  /// ⚠️ **والتمييز بين «غائب» و«`false`» جوهري ولا يُطوى (`IQ-017`):**
  /// «غائب» بطاقةٌ **كُتبت قبل هذا الحقل** فتحتاج ترحيلاً، و«`false`»
  /// **قرار تعطيل صريح يُحترَم**. ⟵ **وطيُّهما في `bool` واحد يجعل الترحيلَ
  /// يُعيد تفعيل معطَّل**، وهو ما تمنعه هذه الحقيقة بالذات.
  final bool? isActiveField;
}

/// ★ **`ADR-0016`: قارئ بطاقة المستخدم** `users/{userId}`.
///
/// ⛔ **يُرجِع [UserCardSnapshot.absent] لمن لا بطاقة له** — الرفض الافتراضي
/// نفسه الذي تطبّقه القاعدة، ⛔ **ولا يرجع إلى الرمز أبداً**.
typedef UserCardReader = Future<UserCardSnapshot> Function(String userId);

/// حساب كما تعرفه خدمة المصادقة **لحظة الاستدعاء**.
final class AccountRecord {
  /// ينشئ سجلّ حساب.
  const AccountRecord({
    required this.userId,
    required this.userName,
    required this.claims,
    required this.disabled,
    this.cardIsActive,
    this.legacyClaimKeys = const <String>{},
  });

  /// معرّف الحساب في خدمة المصادقة — وهو `userId` في كل الدفاتر.
  final String userId;

  /// الاسم المعروض — ★ **يُنسَخ في قيد التدقيق وقت الحدث** (§2 الشرط 4).
  final String userName;

  /// صلاحياته ونطاقه **من الخدمة لا من الرمز الذي أرسله المُستدعي**.
  ///
  /// ★ **والفرق جوهري:** رمز بيد المستخدم قد يكون أُصدر قبل سحب صلاحية،
  /// فيحمل صلاحية سُحبت فعلاً. **والقراءة من الخدمة تقرأ الحالة الآن.**
  final IdentityClaims claims;

  /// ★ **يُفحَص في كل استدعاء** — «التعطيل فوري ونافذ» (`authentication-policy` §2).
  final bool disabled;

  /// ★★ حقل `isActive` **في بطاقته** — و`null` تعني **الحقل غائب** (`IQ-017`).
  ///
  /// ⚠️ **ولا يُخلط بـ[disabled]:** ذاك **حقيقة خدمة المصادقة**، وهذا
  /// **إسقاطها في الدفتر الذي تقرأه `perm()`**. ⟵ ★ **وافتراقهما هو
  /// العطل بعينه**: حسابٌ حيٌّ في الخدمة وبطاقتُه بلا `isActive`
  /// **مقفولٌ خارج نظامه**، وهو ما يرصده هذا الحقل ليُصلَح.
  final bool? cardIsActive;

  /// ★ مفاتيح صلاحيات وُجدت في **رمزه** — من رمز أُصدر قبل `ADR-0016`.
  /// ⛔ **تُتجاهَل ولا تُمنَح**، ✅ **وتُبلَّغ ولا تُبتلَع**.
  final Set<String> legacyClaimKeys;
}

/// فشل التحقق من الهوية — **مصنَّف لا نصّي**.
enum IdentityFailure {
  /// الرمز غير صالح أو منتهٍ — `ERR_AUTH_003`.
  invalidToken,

  /// لا حساب بهذا المعرّف.
  accountNotFound,

  /// حمولة المطالبات تجاوزت حدّ المنصة — `IQ-008`.
  claimsTooLarge,

  /// ★ البريد مسجَّل لحسابٍ آخر — `FR-M1-01` («البريد **فريد**»).
  emailAlreadyExists,
}

/// استثناء بوابة الهوية — يحمل تصنيفه لا نصّه.
final class IdentityGatewayException implements Exception {
  /// ينشئ الاستثناء بتصنيفه ووصفه التقني.
  const IdentityGatewayException(this.failure, [this.diagnostic]);

  /// التصنيف الذي يُترجَم إلى رمز كتالوج.
  final IdentityFailure failure;

  /// وصف **للسجل لا للعرض** — ⛔ بلا أي بيانات حساسة.
  final String? diagnostic;

  @override
  String toString() => 'IdentityGatewayException(${failure.name}): $diagnostic';
}

/// عميل رفيع على خدمة المصادقة.
final class IdentityGateway {
  /// ينشئ البوابة بواجهة جاهزة — ★ **يُحقَن في الاختبارات بمزيّف**.
  IdentityGateway({
    required idtk.IdentityToolkitApi api,
    UserCardReader? readUserCard,
  })  : _api = api,
        _readUserCard = readUserCard;

  /// ★ **`ADR-0016`: مصدر صلاحيات المُنفِّذ هو بطاقة المستخدم لا رمزه.**
  ///
  /// ⛔ **وغيابه يعني «بلا صلاحية»** — الرفض الافتراضي نفسه الذي تطبّقه
  /// القاعدة، ⛔ **لا رجوعاً صامتاً إلى الرمز** (وهو ما كان سيُبقي المسار
  /// القديم مفتوحاً).
  final UserCardReader? _readUserCard;

  /// يبني بوابة ببيانات الاعتماد الافتراضية للبيئة الحالية.
  static Future<IdentityGateway> connect({
    UserCardReader? readUserCard,
  }) async {
    final http.Client client = await auth.clientViaApplicationDefaultCredentials(
      scopes: <String>[idtk.IdentityToolkitApi.cloudPlatformScope],
    );
    return IdentityGateway(
      api: idtk.IdentityToolkitApi(client),
      readUserCard: readUserCard,
    );
  }

  final idtk.IdentityToolkitApi _api;

  /// يتحقق من رمز الدخول ويُرجِع صاحبه بحالته الحالية.
  ///
  /// ⛔ **يرمي [IdentityGatewayException] على رمز غير صالح** — ولا يُرجِع
  /// هوية مجهولة، لأن «كل عملية يجب أن تُنسَب لشخص»
  /// (`authentication-policy.md` §6).
  Future<AccountRecord> verifyIdToken(String idToken) async {
    final idtk.GetAccountInfoResponse response;
    try {
      response = await _api.relyingparty.getAccountInfo(
        idtk.IdentitytoolkitRelyingpartyGetAccountInfoRequest(idToken: idToken),
      );
    } on idtk.DetailedApiRequestError catch (error) {
      // ★ **رُصد بالتشغيل الحقيقي لا بالاختبار:** رمز غير صالح يجعل الخدمة
      //   نفسها ترمي `INVALID_ID_TOKEN`، فكان يتسرّب خاماً فيصل المستخدمَ
      //   **500 بلا رمز كتالوج** بدل `ERR_AUTH_003` — وهي أشيع حالة واقعية
      //   (رمز منتهٍ). ⛔ ولا يُبتلَع غيرُها: ما لا يُصنَّف يُعاد رميه كما هو.
      final IdentityFailure? failure = classifyIdentityApiError(error);
      if (failure == null) rethrow;
      throw IdentityGatewayException(failure, 'getAccountInfo: ${error.message}');
    }
    final idtk.UserInfo? user = _firstUser(response);
    if (user == null) {
      throw const IdentityGatewayException(
        IdentityFailure.invalidToken,
        'الرمز لم يُرجِع أي حساب',
      );
    }
    return _toRecord(user, await _cardOf(userIdOf(user)));
  }

  /// يقرأ حساباً بمعرّفه — **للهدف الذي تُعدَّل صلاحياته**.
  Future<AccountRecord> lookupByUserId(String userId) async {
    final idtk.GetAccountInfoResponse response;
    try {
      response = await _api.relyingparty.getAccountInfo(
        idtk.IdentitytoolkitRelyingpartyGetAccountInfoRequest(
          localId: <String>[userId],
        ),
      );
    } on idtk.DetailedApiRequestError catch (error) {
      // ★ هنا المُدخَل معرّفُ حساب لا رمزٌ — ففشل البحث **حسابٌ غير موجود**
      //   لا جلسةٌ منتهية، وتصنيفه بالأول يُضلِّل المُستدعي.
      if (classifyIdentityApiError(error) == null) rethrow;
      throw IdentityGatewayException(
        IdentityFailure.accountNotFound,
        'getAccountInfo(localId): ${error.message}',
      );
    }
    final idtk.UserInfo? user = _firstUser(response);
    if (user == null) {
      throw const IdentityGatewayException(
        IdentityFailure.accountNotFound,
        'لا حساب بهذا المعرّف',
      );
    }
    return _toRecord(user, await _cardOf(userIdOf(user)));
  }

  /// يكتب المطالبات المخصّصة — ★ **وهي المسار الوحيد لسريان الصلاحية**.
  ///
  /// `authentication-policy.md` §3: «**الصلاحية الجديدة تسري بعد تحديث
  /// الرمز** — والتطبيق يُحدّثه صراحةً».
  Future<void> writeClaims({
    required String userId,
    required IdentityClaims claims,
  }) async {
    final String encoded;
    try {
      encoded = claims.encode();
    } on ClaimsTooLargeException catch (error) {
      // ⛔ لا اقتطاع ولا تجاهل — يُرفَع مصنَّفاً ليصل المستخدم رمزاً واضحاً.
      throw IdentityGatewayException(
        IdentityFailure.claimsTooLarge,
        error.toString(),
      );
    }
    await _api.relyingparty.setAccountInfo(
      idtk.IdentitytoolkitRelyingpartySetAccountInfoRequest(
        localId: userId,
        customAttributes: encoded,
      ),
    );
  }

  /// ★★ يُنشئ حساباً في خدمة المصادقة ويُرجِع معرّفه — `FR-M1-01`.
  ///
  /// ⚠️★★★ **وبكلمةٍ أوليةٍ يضبطها المدير** — `CR-005` (2026-08-31):
  /// ⟵ **ويغيّرها صاحبُها متى شاء** ⛔ **بلا إجبارٍ عند أول دخول وبلا مهلة.**
  ///
  /// ⛔⛔★★★ **والقيمة لا تُسجَّل ولا تُرجَع ولا تدخل رسالةَ خطأ:** ★ **نوعُها
  /// [InitialPassword] لا يكشف نفسه في `toString`** — ⟵ **فلا تتسرّب إلى
  /// سجلٍّ ولا إلى `diagnostic`**، ⛔ **وهي قاعدة «لا كلمة مرور في أي مستند
  /// ولا كود ولا رسالة» الباقيةُ بحرفها** (`authentication-policy.md` §5).
  ///
  /// ⚠️ **وكان المسارُ رابطَ استرجاعٍ عبر [sendPasswordSetupLink]** — ★ **وهو
  /// باقٍ مساراً لتغييرها لاحقاً**، ⛔ **ولم يعد المسارَ الوحيد لضبطها.**
  Future<String> createAccount({
    required String email,
    required String displayName,
    required InitialPassword password,
  }) async {
    final idtk.SignupNewUserResponse response;
    try {
      response = await _api.relyingparty.signupNewUser(
        idtk.IdentitytoolkitRelyingpartySignupNewUserRequest(
          email: email,
          displayName: displayName,
          // ★★ **والقيمة تعبر من هنا إلى الخدمة ولا تُخزَّن في أي دفتر** —
          //    `FR-M1-02` قائم: **لا حقل كلمة مرور في سجل المستخدم.**
          password: password.value,
        ),
      );
    } on idtk.DetailedApiRequestError catch (error) {
      // ★ **أشيع فشل واقعي: بريد مسجَّل مسبقاً** (`FR-M1-01`: البريد فريد).
      //   ⟵ يُصنَّف صراحةً ⛔ ولا يتسرّب خاماً فيصل المستخدمَ 500 بلا معنى.
      final String message = (error.message ?? '').toUpperCase();
      if (message.contains('EMAIL_EXISTS')) {
        throw IdentityGatewayException(
          IdentityFailure.emailAlreadyExists,
          'signupNewUser: ${error.message}',
        );
      }
      rethrow;
    }
    final String? userId = response.localId;
    if (userId == null || userId.isEmpty) {
      throw const IdentityGatewayException(
        IdentityFailure.invalidToken,
        'signupNewUser لم يُرجِع معرّفاً',
      );
    }
    return userId;
  }

  /// ★★ يعطّل الحساب في خدمة المصادقة نفسها — **الشطر الثاني من `IQ-017`**.
  ///
  /// ★ **ولماذا هذا ولا يكفي `isActive` في البطاقة:** البطاقة تمنع الرمزَ
  /// **القائم** عند كل عملية (تقرؤها القاعدة)، **وهذا يمنع إصدارَ الجديد**
  /// ⟵ **فتُغلق النافذتان معاً**. ⛔ **والاكتفاء بأحدهما يترك ثغرة:**
  /// القاعدة وحدها تدع الحساب يجدّد رمزه ويدخل، والخدمة وحدها تدع رمزاً
  /// صالحاً يعمل حتى ينتهي — **وهي نافذة تصل ساعة في نظام ذمم**.
  Future<void> setAccountDisabled({
    required String userId,
    required bool disabled,
  }) async {
    await _api.relyingparty.setAccountInfo(
      idtk.IdentitytoolkitRelyingpartySetAccountInfoRequest(
        localId: userId,
        disableUser: disabled,
      ),
    );
  }

  /// ★ يُرسل رابط ضبط كلمة المرور لصاحب الحساب — `authentication-policy.md` §5.
  ///
  /// ⛔ **ولا يُرجِع الرابط للمُستدعي** — فالمدير لا يقرأ ما يضبط به غيرُه
  /// كلمتَه. ★ **«الإدارة تُعيد التعيين لا تقرأ»** حرفياً.
  Future<void> sendPasswordSetupLink({required String email}) async {
    await _api.relyingparty.getOobConfirmationCode(
      idtk.Relyingparty(email: email, requestType: 'PASSWORD_RESET'),
    );
  }

  /// ★ بطاقة المستخدم — ⛔ ومن لا قارئ له فلا صلاحية له.
  ///
  /// ⚠️ **الغياب منعٌ لا سماح**، وهو ما يجعل سلوك الدالة مطابقاً للقاعدة
  /// حرفياً (`ADR-0013` القاعدة 3: النسختان يجب أن تتطابقا).
  Future<UserCardSnapshot> _cardOf(String userId) async {
    final UserCardReader? reader = _readUserCard;
    if (reader == null) return UserCardSnapshot.absent;
    return reader(userId);
  }

  /// معرّف الحساب — ويرمي مصنَّفاً إن غاب.
  static String userIdOf(idtk.UserInfo user) {
    final String? id = user.localId;
    if (id == null || id.isEmpty) {
      throw const IdentityGatewayException(
        IdentityFailure.invalidToken,
        'حساب بلا معرّف',
      );
    }
    return id;
  }

  static idtk.UserInfo? _firstUser(idtk.GetAccountInfoResponse response) {
    final List<idtk.UserInfo>? users = response.users;
    if (users == null || users.isEmpty) return null;
    return users.first;
  }

  static AccountRecord _toRecord(
    idtk.UserInfo user,
    UserCardSnapshot card,
  ) {
    final String? userId = user.localId;
    if (userId == null || userId.isEmpty) {
      throw const IdentityGatewayException(
        IdentityFailure.invalidToken,
        'حساب بلا معرّف',
      );
    }
    final ClaimsDecoding decoded = IdentityClaims.decode(user.customAttributes);
    return AccountRecord(
      userId: userId,
      // ★ الاسم قد يغيب في حساب لم يُكمَل بعد — والبريد بديل مقروء، ⛔ ولا
      //   يُترك القيد بلا اسم لأن الشرط 4 يفرض نسخه وقت الحدث.
      userName: _resolveName(user),
      claims: IdentityClaims(
        // ★ ADR-0016: الصلاحيات من البطاقة لا من الرمز.
        permissions: card.permissions,
        sourceScope: decoded.claims.sourceScope,
        roleId: decoded.claims.roleId,
      ),
      disabled: user.disabled ?? false,
      // ★★ `IQ-017`: يُنقَل كما هو — ⛔ ولا يُطوى غيابُه في `false`.
      cardIsActive: card.isActiveField,
      legacyClaimKeys: decoded.legacyKeys,
    );
  }

  static String _resolveName(idtk.UserInfo user) {
    final String? displayName = user.displayName;
    if (displayName != null && displayName.trim().isNotEmpty) {
      return displayName.trim();
    }
    final String? email = user.email;
    if (email != null && email.trim().isNotEmpty) return email.trim();
    return user.localId ?? '';
  }
}

/// نطاق «كل المصادر» — يُعاد تصديره ليقرأه المُستدعي بلا استيراد ثانٍ.
const SourceScope allSourcesScope = AllSources();

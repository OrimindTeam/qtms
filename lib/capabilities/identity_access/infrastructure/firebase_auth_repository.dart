/// تنفيذ مستودع المصادقة على خدمة المنصة — `technology-stack.md` §1.
///
/// ⛔ **ولا تُخزَّن كلمة مرور ولا معرّف جهاز** (`identity-access-design.md` §2).
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:qtms_domain/qtms_domain.dart';

/// مستودع المصادقة الحقيقي.
final class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(this._auth);

  final FirebaseAuth _auth;

  /// ★ **`idTokenChanges` لا `authStateChanges` عمداً:** نطاق المصادر يعيش في
  /// المطالبات، ⟵ **وتحديثه يُصدر رمزاً جديداً بلا تغيّر حالة الدخول**.
  /// و`authStateChanges` **لا تُطلِق عندها**، فيبقى النطاق القديم في الواجهة
  /// (`authentication-policy.md` §3: «نطاق المصادر يسري بعد تحديث الرمز»).
  @override
  Stream<AuthenticatedIdentity?> watchIdentity() =>
      _auth.idTokenChanges().asyncMap(_toIdentity);

  Future<AuthenticatedIdentity?> _toIdentity(User? user) async {
    if (user == null) return null;
    final IdTokenResult token = await user.getIdTokenResult();
    return AuthenticatedIdentity(
      userId: user.uid,
      // ★★★ **بريدُ الدخول من خدمة المصادقة** — `AM-012` §5.1:
      //    ⟵ **وهو ما تحتاجه إعادةُ المصادقة** ([`ADR-0024`] الشرط 4).
      // ⛔ **والفراغُ يُقرأ غياباً لا نصّاً فارغاً.**
      email: (user.email?.trim().isEmpty ?? true) ? null : user.email!.trim(),
      sourceScope: parseSourceScopeClaim(token.claims?[sourceScopeClaimKey]),
    );
  }

  @override
  Future<SignInResult> signIn({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return const SignInAccepted();
    } on FirebaseAuthException catch (error) {
      return SignInRejected(mapSignInError(error.code));
    } on Object {
      // ⛔ لا يُبتلَع استثناء صامتاً (coding-standards §2.5) — يُصنَّف ويُبلَّغ.
      return const SignInRejected(SignInRejection.unexpected);
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();

  /// ★★★ **تغييرُ كلمة المرور** — [`CR-012`] · `AM-012` §5.3.
  ///
  /// ⛔⛔★★★ **وإعادةُ المصادقة أولاً بالكلمة الحالية** — ★ **`reauthenticateWithCredential`:**
  /// ⟵ **وخدمةُ المصادقة ترفض `updatePassword` على جلسةٍ قديمة أصلاً**
  /// (`requires-recent-login`)، ★ **وإعادتُها هنا تجعل الرفضَ مصنَّفاً
  /// «الحالية غير صحيحة»** ⛔ **بدل خطأٍ غامضٍ يقرؤه المستخدم عطلاً.**
  @override
  Future<SignInResult> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final User? user = _auth.currentUser;
    final String? email = user?.email;
    // ⛔ **ولا جلسةَ ولا بريد ⟵ رفضٌ مصنَّف** — ★ **ولا انهيار**، ⟵ **والحارسُ
    //   الحقيقي أن الشاشة لا تُفتَح بلا جلسة** (`router.dart`).
    if (user == null || email == null || email.isEmpty) {
      return const SignInRejected(SignInRejection.unexpected);
    }
    try {
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: email, password: currentPassword),
      );
      await user.updatePassword(newPassword);
      return const SignInAccepted();
    } on FirebaseAuthException catch (error) {
      return SignInRejected(mapSignInError(error.code));
    } on Object {
      // ⛔ لا يُبتلَع استثناء صامتاً (coding-standards §2.5) — يُصنَّف ويُبلَّغ.
      return const SignInRejected(SignInRejection.unexpected);
    }
  }
}

/// يُصنِّف رمز خطأ خدمة المصادقة إلى سبب رفض من طبقة النطاق.
///
/// ⚠️ **الاعتماد على رموز المنصة لا على نصوصها** — وهو الفارق عن `DEBT-19`:
/// هناك تُطابَق **رسالة** فتنكسر بتغيّر صياغتها، ★ **وهنا يُطابَق رمز
/// مُصنَّف** تُصدره الواجهة عمداً.
///
/// ⛔ **وما لا يُعرَف يُصنَّف [SignInRejection.unexpected]** — ★ **ولا يُقنَّع
/// بيانات اعتماد خاطئة**، فالعطل يبقى ظاهراً لا مطموساً.
SignInRejection mapSignInError(String code) {
  switch (code) {
    case 'invalid-credential':
    case 'invalid-email':
    case 'user-not-found':
    case 'wrong-password':
    // ★★ **وثلاثةٌ تخصّ تغييرَ كلمة المرور** — [`CR-012`]:
    //    ★ **وكلُّها تُقرأ «الحالية غير صحيحة أو الجلسة قديمة»** — ⟵ **وهي
    //    رسالةٌ واحدة للمستخدم: أعد إدخال كلمتك الحالية.**
    case 'requires-recent-login':
    case 'invalid-login-credentials':
      return SignInRejection.invalidCredentials;
    case 'user-disabled':
      return SignInRejection.accountDisabled;
    case 'too-many-requests':
      return SignInRejection.lockedOut;
    case 'network-request-failed':
      return SignInRejection.noConnection;
    default:
      return SignInRejection.unexpected;
  }
}

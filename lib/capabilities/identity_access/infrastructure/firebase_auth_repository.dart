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

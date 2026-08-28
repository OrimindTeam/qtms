/// حالة نموذج الدخول ومتحكّمه — **حالة نموذج** (`ADR-0010`: «قيم الحقول
/// والتحقق الاستباقي · عمر النموذج»).
///
/// ⛔ **ولا منطق أعمال في الشاشة** (`ADR-0010` القاعدة 1) — الشاشة تستدعي
/// [LoginController.submit] وتعرض الحالة، ⟵ **والتصنيف كله في الطبقات أدناه.**
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qtms_domain/qtms_domain.dart';

import 'session_providers.dart';

/// حالة نموذج الدخول.
sealed class LoginState {
  const LoginState();
}

/// في انتظار إدخال المستخدم.
final class LoginIdle extends LoginState {
  const LoginIdle();
}

/// المحاولة جارية — ★ **والزر مُعطَّل حتى تنتهي**، فلا محاولتان متزامنتان.
final class LoginSubmitting extends LoginState {
  const LoginSubmitting();
}

/// رُفضت المحاولة بسبب مصنَّف.
final class LoginRejected extends LoginState {
  const LoginRejected(this.reason);

  final SignInRejection reason;
}

/// متحكّم الدخول.
final NotifierProvider<LoginController, LoginState> loginControllerProvider =
    NotifierProvider<LoginController, LoginState>(LoginController.new);

/// ينفّذ محاولة الدخول ويحفظ حالتها.
///
/// ⚠️ **ولا يحمل الجلسة الناتجة** — ★ **الجلسة تصل من `sessionProvider`
/// وحده**، فمصدر حقيقة واحد لحالة الدخول ⛔ لا نسختان تفترقان.
class LoginController extends Notifier<LoginState> {
  @override
  LoginState build() => const LoginIdle();

  /// يحاول الدخول — ⛔ **ولا يُعيد المحاولة تلقائياً**: تكرار محاولة فاشلة
  /// **يقرّب القفل المؤقت** (`BR-M1-05`) بلا علم المستخدم.
  Future<void> submit({
    required String email,
    required String password,
  }) async {
    if (state is LoginSubmitting) return;
    state = const LoginSubmitting();

    final SignInResult result = await ref
        .read(authRepositoryProvider)
        .signIn(email: email, password: password);

    state = switch (result) {
      SignInAccepted() => const LoginIdle(),
      SignInRejected(reason: final SignInRejection reason) =>
        LoginRejected(reason),
    };
  }
}

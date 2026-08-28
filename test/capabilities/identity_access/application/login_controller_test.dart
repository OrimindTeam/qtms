/// متحكّم الدخول.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qtms/capabilities/identity_access/application/login_controller.dart';
import 'package:qtms/capabilities/identity_access/application/session_providers.dart';
import 'package:qtms_domain/qtms_domain.dart';

import '../../../support/fake_identity.dart';

void main() {
  late FakeAuthRepository auth;
  late ProviderContainer container;

  setUp(() {
    auth = FakeAuthRepository();
    container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(auth)],
    );
  });

  tearDown(() {
    container.dispose();
    auth.dispose();
  });

  test('البداية خاملة', () {
    expect(container.read(loginControllerProvider), isA<LoginIdle>());
  });

  test('★ القبول يعيدها خاملة — ⛔ ولا تحمل الجلسة', () async {
    await container
        .read(loginControllerProvider.notifier)
        .submit(email: 'a@b.c', password: 'x');

    expect(container.read(loginControllerProvider), isA<LoginIdle>());
  });

  test('★ الرفض يحفظ سببه مصنَّفاً', () async {
    auth.result = const SignInRejected(SignInRejection.lockedOut);

    await container
        .read(loginControllerProvider.notifier)
        .submit(email: 'a@b.c', password: 'x');

    final LoginState state = container.read(loginControllerProvider);
    expect(state, isA<LoginRejected>());
    expect((state as LoginRejected).reason, SignInRejection.lockedOut);
  });
}

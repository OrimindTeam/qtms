/// ★★★ **سياسةُ الدخول بالبصمة** — [`ADR-0024`] ⏳ **مقترح** · [`CR-012`] ⏳ ·
/// `AM-012` §5.2 و§5.3 و§6.
///
/// ⚠️⚠️ **وما تُثبته هذه الاختبارات:** أن **الشروط 2 و4 و5 و6 و7 و8 من
/// `ADR-0024` مُنفَّذةٌ فعلاً** — ⛔ **لا موصوفةٌ في نصّ.**
///
/// ⛔ **ولا تُثبت أن `local_auth` تعمل** — ★ **تلك قناةُ منصّةٍ تُقاس حيّاً
/// على المحاكي** (البروتوكول §د)، ⟵ **وهي وحدها ما لا يغطّيه هذا الملف.**
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qtms/capabilities/identity_access/application/biometric_providers.dart';
import 'package:qtms/capabilities/identity_access/application/session_providers.dart';
import 'package:qtms/core/device/biometric_gateway.dart';
import 'package:qtms/core/device/credential_vault.dart';
import 'package:qtms_domain/qtms_domain.dart';

import '../../../support/fake_identity.dart';

void main() {
  late FakeBiometricGateway gateway;
  late FakeCredentialVault vault;
  late FakeAuthRepository auth;
  late ProviderContainer container;

  setUp(() {
    gateway = FakeBiometricGateway();
    vault = FakeCredentialVault();
    auth = FakeAuthRepository();
    container = ProviderContainer(
      overrides: [
        biometricGatewayProvider.overrideWithValue(gateway),
        credentialVaultProvider.overrideWithValue(vault),
        authRepositoryProvider.overrideWithValue(auth),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(auth.dispose);
  });

  BiometricLoginController controller() =>
      container.read(biometricLoginControllerProvider);

  group('★★★ التفعيل — الشرطان 4 و5', () {
    test('✅ كلمةٌ صحيحةٌ ثم بصمةٌ مقبولة ⟵ تُحفَظ البيانات', () async {
      final BiometricOutcome outcome = await controller().enable(
        email: 'owner@qtms.test',
        password: 'goodPass1',
      );
      expect(outcome, BiometricOutcome.success);
      expect(vault.stored?.email, 'owner@qtms.test');
      expect(vault.stored?.password, 'goodPass1');
    });

    test(
      '⛔⛔★★★ الشرط 5: كلمةٌ خاطئة ⟵ لا تُحفَظ ولا تُطلَب بصمةٌ أصلاً',
      () async {
        // ★★ **وإلا حُفظت كلمةٌ خاطئة يفشل بها كلُّ دخولٍ لاحق** ⛔ **ولا
        //    يعرف المستخدم لماذا.**
        auth.result = const SignInRejected(SignInRejection.invalidCredentials);
        final BiometricOutcome outcome = await controller().enable(
          email: 'owner@qtms.test',
          password: 'wrong',
        );
        expect(outcome, BiometricOutcome.badPassword);
        expect(vault.stored, isNull);
        expect(gateway.authenticateCalls, 0);
      },
    );

    test('⛔⛔★★★ الشرط 4: بصمةٌ مرفوضة ⟵ لا تُحفَظ البيانات', () async {
      gateway.accepts = false;
      final BiometricOutcome outcome = await controller().enable(
        email: 'owner@qtms.test',
        password: 'goodPass1',
      );
      expect(outcome, BiometricOutcome.rejected);
      expect(vault.stored, isNull);
    });

    test('⛔ وجهازٌ لا يدعم ⟵ لا يُطلَب سرٌّ أصلاً', () async {
      gateway.state = BiometricAvailability.unsupported;
      expect(
        await controller().enable(email: 'a@b.c', password: 'x'),
        BiometricOutcome.unsupported,
      );
      // ★ **ولا مصادقةَ حيّة تُستهلك على قدرةٍ لا تعمل.**
      expect(auth.lastEmail, isNull);
      expect(vault.stored, isNull);
    });

    test('⚠️ وبلا بصمةٍ مسجَّلة ⟵ حالةٌ مستقلة يحلّها المستخدم', () async {
      gateway.state = BiometricAvailability.notEnrolled;
      expect(
        await controller().enable(email: 'a@b.c', password: 'x'),
        BiometricOutcome.notEnrolled,
      );
      expect(vault.stored, isNull);
    });
  });

  group('⛔⛔★★★ الإيقاف — الشرط 6: مسحٌ فعليٌّ فوري', () {
    test('★ الإطفاءُ يمسح ولا يكتفي برايةٍ منطقية', () async {
      vault.seed(
        const StoredCredentials(email: 'a@b.c', password: 'p'),
      );
      await controller().disable();
      expect(vault.clearCalls, 1);
      expect(vault.stored, isNull);
    });
  });

  group('★★★ الدخول — الشروط 2 و7 و11', () {
    setUp(() {
      vault.seed(
        const StoredCredentials(email: 'owner@qtms.test', password: 'stored1'),
      );
    });

    test('✅ بصمةٌ مقبولة ⟵ دخولٌ ببيانات الخزنة', () async {
      expect(await controller().signIn(), BiometricOutcome.success);
      expect(auth.lastEmail, 'owner@qtms.test');
      expect(auth.lastPassword, 'stored1');
    });

    test(
      '⛔⛔★★★ الشرط 2: لا تُقرأ الخزنة قبل نجاح المصادقة',
      () async {
        // ★★★ **جوهرُ الشرط:** ⟵ **قراءةٌ بلا مصادقةٍ تجعل التخزينَ نفسَه
        //    هو الثغرة** — ★ **فالحارسُ في مسار القراءة لا في مسار العرض.**
        gateway.accepts = false;
        expect(await controller().signIn(), BiometricOutcome.rejected);
        expect(vault.readCalls, 0);
        expect(auth.lastEmail, isNull);
      },
    );

    test('⛔ وجهازٌ لا يدعم ⟵ لا قراءةَ ولا دخول', () async {
      gateway.state = BiometricAvailability.unsupported;
      expect(await controller().signIn(), BiometricOutcome.unsupported);
      expect(vault.readCalls, 0);
      expect(gateway.authenticateCalls, 0);
    });

    test(
      '⛔⛔★★★ الشرط 7: كلمةٌ لم تعد صالحة ⟵ تُمسَح البيانات فوراً',
      () async {
        auth.result = const SignInRejected(SignInRejection.invalidCredentials);
        expect(await controller().signIn(), BiometricOutcome.badPassword);
        expect(vault.clearCalls, 1);
        expect(vault.stored, isNull);
      },
    );

    test(
      '⛔⛔★★★ الشرط 11: حسابٌ معطَّل ⟵ يُرفَض وتُمسَح البيانات',
      () async {
        // ★★ **والرفضُ من الخادم كما في المسار العادي** — ⛔ **ولا تلتفّ
        //    البصمةُ على «التعطيل فوريٌّ ونافذ»** (§2 القاعدة 3).
        auth.result = const SignInRejected(SignInRejection.accountDisabled);
        expect(await controller().signIn(), BiometricOutcome.badPassword);
        expect(vault.stored, isNull);
      },
    );

    test('⛔ وخزنةٌ خاوية ⟵ يُوجَّه المستخدم ولا يُدَّعى دخول', () async {
      await vault.clear();
      expect(await controller().signIn(), BiometricOutcome.noCredentials);
      expect(auth.lastEmail, isNull);
    });
  });

  group('★★★ الشرط 8 — تحديثُ المحفوظ بعد تغيير كلمة المرور', () {
    test('★ المُفعَّلُ يُحدَّث بالكلمة الجديدة', () async {
      vault.seed(
        const StoredCredentials(email: 'owner@qtms.test', password: 'old1'),
      );
      await controller().refreshStoredPassword('new2');
      expect(vault.stored?.password, 'new2');
      // ★ **والبريدُ لا يتغيّر** — ⛔ **ولا يُخترَع.**
      expect(vault.stored?.email, 'owner@qtms.test');
    });

    test(
      '⛔⛔★★★ ومن لم يُفعِّل لا يُنشَأ له حفظٌ — تخزينُ سرٍّ بلا إذنه',
      () async {
        // ★★★ **وهو أخطر ما يمكن أن يفعله هذا المتحكّم** — ⟵ **حفظُ كلمةِ
        //    من لم يطلب الميزة.**
        expect(vault.stored, isNull);
        await controller().refreshStoredPassword('new2');
        expect(vault.stored, isNull);
      },
    );
  });

  group('★★ حالةُ التفعيل تُقاس من الخزنة — ⛔ لا من رايةٍ مستقلة', () {
    test('★ خزنةٌ خاوية ⟵ غيرُ مُفعَّل', () async {
      expect(await container.read(biometricLoginEnabledProvider.future), false);
    });

    test('★ وبعد التفعيل ⟵ مُفعَّل', () async {
      await controller().enable(email: 'a@b.c', password: 'p');
      expect(await container.read(biometricLoginEnabledProvider.future), true);
    });
  });
}

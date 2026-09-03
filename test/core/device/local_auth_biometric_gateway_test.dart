/// ★★★ **بوابةُ البصمة فوق `local_auth`** — [`ADR-0024`] · `AM-012` §5.2.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **ولماذا وُجد هذا الملف — `DEBT-82` مقيسٌ لا مفترَض:**
/// ★ **هذه الطبقةُ لم تكن مُختبَرةً قطّ** — ⟵ **وهو ثاني عشرَ أوجهِ
/// `DEBT-37` حرفياً**: ★ **`local_auth` 3.x ترمي `LocalAuthException`
/// ⛔ لا `PlatformException`**، ★ **والبوابةُ كانت تمسك الثانية وحدَها**
/// ⟹ ⛔⛔ **فإلغاءُ المستخدم للبصمة كان يُسرِّب استثناءً غيرَ ممسوك إلى
/// الشاشة** — ★ **فيبقى المفتاحُ معطَّلاً والرسالةُ السابقةُ معروضةً بلا
/// تحديث** (**مقيسٌ على `Pixel_6_API_36` — 2026-09-02**).
///
/// ⛔ **ولا تُثبت هذه الاختبارات أن الحزمة نفسَها تعمل** — ★ **تلك قناةُ
/// منصّةٍ تُقاس حيّاً** (البروتوكول §د): ★ **تُثبت أن **ترجمةَ** مخرجاتها
/// إلى عقد `BiometricGateway` صحيحة** — ⟵ **وهو ما انكسر فعلاً.**
/// ═══════════════════════════════════════════════════════════════════════
library;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_platform_interface/types/auth_messages.dart';
import 'package:qtms/core/device/biometric_gateway.dart';
import 'package:qtms/core/device/local_auth_biometric_gateway.dart';

void main() {
  group('★★★ authenticate — ⛔ لا استثناء يعبر إلى المُستدعي', () {
    test('✅ نجاحٌ فعلي ⟵ true', () async {
      final gateway = LocalAuthBiometricGateway(
        _FakeLocalAuthentication(authenticateResult: true),
      );

      expect(await gateway.authenticate(reason: 'أكّد بصمتك'), isTrue);
    });

    test('⛔ فشلُ التحدّي بلا أثر ⟵ false', () async {
      final gateway = LocalAuthBiometricGateway(
        _FakeLocalAuthentication(authenticateResult: false),
      );

      expect(await gateway.authenticate(reason: 'أكّد بصمتك'), isFalse);
    });

    test(
      '⛔⛔★★★ `DEBT-82`: إلغاءُ المستخدم ⟵ false ⛔ لا استثناء',
      () async {
        // ★★ **هذا حرفياً ما وقع على المحاكي:**
        //    `LocalAuthException(code userCanceled, null, null)`.
        final gateway = LocalAuthBiometricGateway(
          _FakeLocalAuthentication(
            authenticateError: const LocalAuthException(
              code: LocalAuthExceptionCode.userCanceled,
            ),
          ),
        );

        expect(await gateway.authenticate(reason: 'أكّد بصمتك'), isFalse);
      },
    );

    test('⛔ عطلُ جهازٍ من الحزمة ⟵ false', () async {
      final gateway = LocalAuthBiometricGateway(
        _FakeLocalAuthentication(
          authenticateError: const LocalAuthException(
            code: LocalAuthExceptionCode.deviceError,
          ),
        ),
      );

      expect(await gateway.authenticate(reason: 'أكّد بصمتك'), isFalse);
    });

    test('⛔ `PlatformException` تبقى ممسوكةً كذلك ⟵ false', () async {
      // ★ **حارسٌ ثانٍ للإصدارات الأقدم من المُلحقات** — ⛔ **لم يُسقَط.**
      final gateway = LocalAuthBiometricGateway(
        _FakeLocalAuthentication(
          authenticateError: PlatformException(code: 'NotAvailable'),
        ),
      );

      expect(await gateway.authenticate(reason: 'أكّد بصمتك'), isFalse);
    });
  });

  group('★★ availability — الحالةُ ثلاثيةٌ لا `bool`', () {
    test('✅ جهازٌ مدعومٌ ببصمةٍ مسجَّلة ⟵ available', () async {
      final gateway = LocalAuthBiometricGateway(
        _FakeLocalAuthentication(
          deviceSupported: true,
          enrolled: <BiometricType>[BiometricType.fingerprint],
        ),
      );

      expect(await gateway.availability(), BiometricAvailability.available);
    });

    test('⚠️ مدعومٌ بلا بصمةٍ مسجَّلة ⟵ notEnrolled', () async {
      final gateway = LocalAuthBiometricGateway(
        _FakeLocalAuthentication(
          deviceSupported: true,
          enrolled: <BiometricType>[],
        ),
      );

      expect(await gateway.availability(), BiometricAvailability.notEnrolled);
    });

    test('⛔ جهازٌ غير مدعوم ⟵ unsupported', () async {
      final gateway = LocalAuthBiometricGateway(
        _FakeLocalAuthentication(deviceSupported: false),
      );

      expect(await gateway.availability(), BiometricAvailability.unsupported);
    });

    test(
      '⛔⛔★★ `DEBT-82`: `LocalAuthException` عند القياس ⟵ unsupported '
      '⛔ لا استثناء يُسقط شاشةَ الدخول',
      () async {
        final gateway = LocalAuthBiometricGateway(
          _FakeLocalAuthentication(
            availabilityError: const LocalAuthException(
              code: LocalAuthExceptionCode.unknownError,
            ),
          ),
        );

        expect(await gateway.availability(), BiometricAvailability.unsupported);
      },
    );

    test('⛔ `PlatformException` عند القياس ⟵ unsupported', () async {
      final gateway = LocalAuthBiometricGateway(
        _FakeLocalAuthentication(
          availabilityError: PlatformException(code: 'NoHardware'),
        ),
      );

      expect(await gateway.availability(), BiometricAvailability.unsupported);
    });
  });
}

/// ★ بديلٌ مزيَّف لـ`LocalAuthentication` — ⛔ **بلا قناةِ منصّة.**
final class _FakeLocalAuthentication implements LocalAuthentication {
  _FakeLocalAuthentication({
    this.authenticateResult = false,
    this.authenticateError,
    this.deviceSupported = true,
    this.enrolled = const <BiometricType>[],
    this.availabilityError,
  });

  final bool authenticateResult;
  final Exception? authenticateError;
  final bool deviceSupported;
  final List<BiometricType> enrolled;
  final Exception? availabilityError;

  @override
  Future<bool> authenticate({
    required String localizedReason,
    Iterable<AuthMessages> authMessages = const <AuthMessages>[],
    bool biometricOnly = false,
    bool sensitiveTransaction = true,
    bool persistAcrossBackgrounding = false,
  }) async {
    if (authenticateError != null) throw authenticateError!;
    return authenticateResult;
  }

  @override
  Future<bool> isDeviceSupported() async {
    if (availabilityError != null) throw availabilityError!;
    return deviceSupported;
  }

  @override
  Future<List<BiometricType>> getAvailableBiometrics() async {
    if (availabilityError != null) throw availabilityError!;
    return enrolled;
  }

  @override
  Future<bool> get canCheckBiometrics async => deviceSupported;

  @override
  Future<bool> stopAuthentication() async => false;
}

/// اختبارات إقلاع التطبيق — المخرَج 9 من «الخطوة صفر».
///
/// ★ تُشغَّل **بلا جهاز وبلا سحابة** لأن الإقلاع يستقبل اعتمادياته حقناً.
/// وهذا ما يجعل «التخزين المحلي مُعطَّل» **حقيقة مُثبَتة آلياً** لا ادعاءً
/// يُراجَع بالعين في كل إصدار.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qtms_domain/qtms_domain.dart';
import 'package:qtms/core/startup/app_startup.dart';

void main() {
  group('ADR-0003: التخزين المحلي مُعطَّل صراحةً', () {
    test('ADR-0003: الإعداد المعتمد يُعطِّل التخزين المحلي', () {
      expect(qtmsFirestoreSettings.persistenceEnabled, isFalse);
    });

    test('ADR-0003: الإقلاع يطبّق الإعداد المُعطِّل فعلاً لا إعداداً آخر', () async {
      Settings? applied;

      final StartupOutcome outcome = await bootstrapQtms(
        initializePlatform: () async {},
        configureFirestore: (Settings settings) => applied = settings,
      );

      expect(outcome, isA<StartupReady>());
      expect(applied, isNotNull);
      // ★ الجوهر: لا يكفي أن يُستدعى الإعداد — يجب أن تكون قيمته التعطيل.
      expect(applied!.persistenceEnabled, isFalse);
    });
  });

  group('C-04 · FR-SYS-27: غياب خدمات المنصة يُعلَن لا يُبتلَع', () {
    test('FR-SYS-27: فشل تهيئة المنصة يُصنَّف PlatformUnavailableError', () async {
      final StartupOutcome outcome = await bootstrapQtms(
        initializePlatform: () async => throw StateError('no play services'),
        configureFirestore: (_) {},
      );

      expect(outcome, isA<StartupFailed>());
      expect((outcome as StartupFailed).error, isA<PlatformUnavailableError>());
    });

    test('FR-SYS-27: ⛔ ولا يُطبَّق إعداد قاعدة البيانات بعد فشل المنصة', () async {
      var configured = false;

      await bootstrapQtms(
        initializePlatform: () async => throw StateError('no play services'),
        configureFirestore: (_) => configured = true,
      );

      expect(configured, isFalse);
    });

    test('NFR-SEC-02: الوصف التشخيصي لا يحمل نص الاستثناء ولا بيانات حساسة', () async {
      const String secret = '777123456';

      final StartupOutcome outcome = await bootstrapQtms(
        initializePlatform: () async => throw StateError('phone $secret'),
        configureFirestore: (_) {},
      );

      final AppError error = (outcome as StartupFailed).error;
      expect(error, isA<PlatformUnavailableError>());
      // ★ يُسجَّل نوع الخطأ لا رسالته — القاعدة 4 في error-handling-strategy §3.
      expect((error as PlatformUnavailableError).diagnostic, isNot(contains(secret)));
    });
  });

  group('فشل إعداد قاعدة البيانات يُصنَّف بنيةً تحتية لا منصةً غائبة', () {
    test('فشل تطبيق الإعداد يُرجِع InfrastructureError', () async {
      final StartupOutcome outcome = await bootstrapQtms(
        initializePlatform: () async {},
        configureFirestore: (_) => throw StateError('settings rejected'),
      );

      expect(outcome, isA<StartupFailed>());
      // ★ التمييز مقصود: خلطه بـPlatformUnavailableError يُرسل المستخدم
      //   لتغيير جهازه بسبب عطل ليس في جهازه.
      expect((outcome as StartupFailed).error, isA<InfrastructureError>());
    });
  });
}

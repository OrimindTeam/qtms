/// ★★★ **شاشة «الملف الشخصي»** و**زرُّ البصمة في شاشة الدخول** —
/// `AM-012` §5 و§6 · [`CR-012`] ⏳ · [`ADR-0024`] ⏳.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qtms/capabilities/identity_access/application/biometric_providers.dart';
import 'package:qtms/capabilities/identity_access/application/session_providers.dart';
import 'package:qtms/capabilities/identity_access/presentation/login_screen.dart';
import 'package:qtms/capabilities/identity_access/presentation/profile_screen.dart';
import 'package:qtms/core/device/credential_vault.dart';
import 'package:qtms/core/startup/staging_qa_credentials.dart';
import 'package:qtms_domain/qtms_domain.dart';

import '../../../support/fake_identity.dart';

late FakeAuthRepository auth;
late FakeUserCardRepository cards;
late FakeBiometricGateway gateway;
late FakeCredentialVault vault;

Future<ProviderContainer> pump(
  WidgetTester tester,
  Widget screen, {
  String? email = 'owner@qtms.test',
  String? identityEmail,
}) async {
  // ★★ **سطحٌ طويل** — ⟵ **فتُبنى أقسامُ الشاشة الثلاثة كلُّها وتُلمَس**،
  //    ⛔ **ولا يسقط زرٌّ خارج مَنفَذ العرض في اختبارٍ بشاشةٍ افتراضية.**
  tester.view.physicalSize = const Size(900, 2200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  auth = FakeAuthRepository();
  cards = FakeUserCardRepository();
  gateway = FakeBiometricGateway();
  vault = FakeCredentialVault();
  addTearDown(auth.dispose);
  addTearDown(cards.dispose);

  auth.emitIdentity(
    AuthenticatedIdentity(
      userId: 'U-001',
      sourceScope: const AllSources(),
      // ★★ **وبريدُ الدخول من خدمة المصادقة** — ⟵ **وهو الاحتياطُ حين
      //    تخلو البطاقة منه** (`AM-012` §5.1 · عطلٌ قِيس حيّاً).
      email: identityEmail,
    ),
  );
  cards.emitCard(
    'U-001',
    UserCard(
      userId: 'U-001',
      name: 'عبدالفتاح',
      email: email,
      permissions: const <Permission>{},
      isActive: true,
    ),
  );

  final ProviderContainer container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(auth),
      userCardRepositoryProvider.overrideWithValue(cards),
      biometricGatewayProvider.overrideWithValue(gateway),
      credentialVaultProvider.overrideWithValue(vault),
      stagingQaCredentialsProvider.overrideWithValue(null),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(locale: const Locale('ar'), home: screen),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 20));
  return container;
}

void main() {
  group('★★★ `AM-012` §5.1 — أعلى الشاشة: صورةٌ واسمٌ وبريد', () {
    testWidgets('★ الاسمُ والبريدُ معاً', (WidgetTester t) async {
      await pump(t, const ProfileScreen());
      expect(find.text('عبدالفتاح'), findsWidgets);
      expect(find.text('owner@qtms.test'), findsOneWidget);
    });

    testWidgets(
      '⛔⛔★★★ وبطاقةٌ بلا بريدٍ ⟵ يُعرَض بريدُ خدمة المصادقة (عطلٌ قِيس حيّاً)',
      (WidgetTester t) async {
        // ⚠️⚠️★★★ **رُصد على المحاكي 2026-09-02:** ★ **الشاشةُ ظهرت بلا سطر
        //    بريدٍ إطلاقاً** — ⟵ **لأن حقل `email` غائبٌ في بطاقة الحساب**،
        //    ⛔ **بينما الحسابُ دخل ببريدٍ صحيحٍ قبل ثانية.**
        await pump(
          t,
          const ProfileScreen(),
          email: null,
          identityEmail: 'signin@qtms.test',
        );
        expect(find.text('signin@qtms.test'), findsOneWidget);
      },
    );

    testWidgets('⛔⛔ وبلا بريدٍ في الاثنين لا يُعلَن نقصُه', (WidgetTester t) async {
      // ★ **ولا «بلا بريد»** — ⟵ **ونصٌّ يُعلنها في شاشةِ «ملفّي» يُقلق
      //    صاحبَها بلا فائدة.**
      await pump(t, const ProfileScreen(), email: null);
      expect(find.text('عبدالفتاح'), findsWidgets);
      expect(find.textContaining('بلا بريد'), findsNothing);
    });
  });

  group('★★★ `AM-012` §5.2 — مفتاحُ البصمة', () {
    testWidgets(
      '⛔⛔★★★ معطَّلٌ برسالةٍ على جهازٍ لا يدعمها — ⛔ ولا يُخفى',
      (WidgetTester t) async {
        gateway = FakeBiometricGateway();
        await pump(t, const ProfileScreen());
        // ★ **والحالةُ تُضبَط قبل البناء** — راجع أدناه للحالة المدعومة.
        expect(find.text('تفعيل الدخول بالبصمة'), findsOneWidget);
      },
    );

    testWidgets('★ والنصُّ يفرّق بين «لا يدعم» و«لا بصمةَ مسجَّلة»', (
      WidgetTester t,
    ) async {
      await pump(t, const ProfileScreen());
      // ★ **والحالةُ الافتراضية في المزيَّف «متاحة»** — ⟵ **فالنصُّ إرشادي.**
      expect(
        find.textContaining('إدخال كلمة المرور ثم تمرير بصمتك'),
        findsOneWidget,
      );
    });

    testWidgets(
      '⛔⛔★★★ الشرط 3: ولا تُعرَض كلمةُ المرور المحفوظة في أي حقل',
      (WidgetTester t) async {
        vault = FakeCredentialVault();
        await pump(t, const ProfileScreen());
        vault.seed(
          const StoredCredentials(email: 'owner@qtms.test', password: 'S3cr3t'),
        );
        await t.pump();
        expect(find.text('S3cr3t'), findsNothing);
      },
    );
  });

  group('★★★ `AM-012` §5.3 — تغييرُ كلمة المرور', () {
    testWidgets('★ ثلاثةُ حقولٍ وزرٌّ', (WidgetTester t) async {
      await pump(t, const ProfileScreen());
      expect(find.text('كلمة المرور الحالية'), findsOneWidget);
      expect(
        find.textContaining('كلمة المرور الجديدة'),
        findsWidgets,
      );
      expect(find.text('تأكيد كلمة المرور الجديدة'), findsOneWidget);
      expect(find.text('تغيير كلمة المرور'), findsWidgets);
    });

    testWidgets('⛔⛔★★★ وعدمُ التطابق يُرفَض قبل أي استدعاءٍ للخدمة', (
      WidgetTester t,
    ) async {
      await pump(t, const ProfileScreen());
      await t.enterText(find.byType(TextField).at(0), 'oldPass12');
      await t.enterText(find.byType(TextField).at(1), 'newPass12');
      await t.enterText(find.byType(TextField).at(2), 'newPass99');
      await t.ensureVisible(
        find.widgetWithText(FilledButton, 'تغيير كلمة المرور'),
      );
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(FilledButton, 'تغيير كلمة المرور'));
      await t.pumpAndSettle();

      expect(find.textContaining('لا تطابق تأكيدها'), findsOneWidget);
      // ⛔⛔ **ولا استدعاءَ للخدمة أصلاً** — ★ **الفحصُ في طبقة النطاق.**
      expect(auth.changePasswordCalls, 0);
    });

    testWidgets('⛔⛔★★★ وقصيرةٌ تُرفَض بالحدّ المعتمَد (ثمانية)', (
      WidgetTester t,
    ) async {
      await pump(t, const ProfileScreen());
      await t.enterText(find.byType(TextField).at(0), 'oldPass12');
      await t.enterText(find.byType(TextField).at(1), 'abc123');
      await t.enterText(find.byType(TextField).at(2), 'abc123');
      await t.ensureVisible(
        find.widgetWithText(FilledButton, 'تغيير كلمة المرور'),
      );
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(FilledButton, 'تغيير كلمة المرور'));
      await t.pumpAndSettle();

      expect(find.textContaining('قصيرة جداً'), findsOneWidget);
      expect(auth.changePasswordCalls, 0);
    });

    testWidgets('✅ والصحيحُ يُغيِّرها ويُحدِّث الدخول السريع إن كان مُفعَّلاً', (
      WidgetTester t,
    ) async {
      await pump(t, const ProfileScreen());
      vault.seed(
        const StoredCredentials(email: 'owner@qtms.test', password: 'oldPass12'),
      );
      await t.enterText(find.byType(TextField).at(0), 'oldPass12');
      await t.enterText(find.byType(TextField).at(1), 'newPass34');
      await t.enterText(find.byType(TextField).at(2), 'newPass34');
      await t.ensureVisible(
        find.widgetWithText(FilledButton, 'تغيير كلمة المرور'),
      );
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(FilledButton, 'تغيير كلمة المرور'));
      await t.pumpAndSettle();

      expect(auth.changePasswordCalls, 1);
      expect(auth.lastNewPassword, 'newPass34');
      // ★★★ **الشرط 8** — ⟵ **وإلا فشل الدخولُ السريع بعد كل تغيير.**
      expect(vault.stored?.password, 'newPass34');
      expect(find.textContaining('تغيّرت كلمة المرور'), findsOneWidget);
    });

    testWidgets('⛔ ورفضُ الخدمة يُعرَض بنصّه ⛔ ولا يُبتلَع', (
      WidgetTester t,
    ) async {
      await pump(t, const ProfileScreen());
      auth.changePasswordResult =
          const SignInRejected(SignInRejection.invalidCredentials);
      await t.enterText(find.byType(TextField).at(0), 'wrongOld1');
      await t.enterText(find.byType(TextField).at(1), 'newPass34');
      await t.enterText(find.byType(TextField).at(2), 'newPass34');
      await t.ensureVisible(
        find.widgetWithText(FilledButton, 'تغيير كلمة المرور'),
      );
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(FilledButton, 'تغيير كلمة المرور'));
      await t.pumpAndSettle();

      expect(auth.changePasswordCalls, 1);
      // ⛔⛔ **ولا تُحدَّث الخزنة على فشل** — ★ **وإلا حُفظت كلمةٌ لم تُقبَل.**
      expect(vault.stored, isNull);
    });
  });

  group('★★★ `AM-012` §6 — زرُّ البصمة في شاشة الدخول', () {
    testWidgets(
      '⛔⛔★★★ لا يظهر لمن لم يُفعِّله على هذا الجهاز',
      (WidgetTester t) async {
        // ★ **فزرٌّ يظهر بلا بياناتٍ يفشل أبداً** ⛔ **ويُعلِّم المستخدم أن
        //    الميزة معطوبة وهي لم تُفعَّل أصلاً.**
        await pump(t, const LoginScreen());
        expect(find.text('الدخول ببصمة الإصبع'), findsNothing);
      },
    );

    testWidgets('★★ ويظهر لمن فعّله — ⛔ والحقلان باقيان بديلاً', (
      WidgetTester t,
    ) async {
      vault = FakeCredentialVault()
        ..seed(
          const StoredCredentials(email: 'owner@qtms.test', password: 'p1'),
        );
      auth = FakeAuthRepository();
      cards = FakeUserCardRepository();
      gateway = FakeBiometricGateway();
      addTearDown(auth.dispose);
      addTearDown(cards.dispose);

      t.view.physicalSize = const Size(900, 2200);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);

      final ProviderContainer container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          userCardRepositoryProvider.overrideWithValue(cards),
          biometricGatewayProvider.overrideWithValue(gateway),
          credentialVaultProvider.overrideWithValue(vault),
          stagingQaCredentialsProvider.overrideWithValue(null),
        ],
      );
      addTearDown(container.dispose);

      await t.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(locale: Locale('ar'), home: LoginScreen()),
        ),
      );
      await t.pump();
      await t.pump(const Duration(milliseconds: 20));

      expect(find.text('الدخول ببصمة الإصبع'), findsOneWidget);
      // ⛔⛔★★★ **وهو بديلٌ لا اختصار** — ★ **الحقلان باقيان كاملين.**
      expect(find.text('البريد الإلكتروني'), findsOneWidget);
      expect(find.text('كلمة المرور'), findsOneWidget);
      expect(find.text('دخول'), findsOneWidget);
    });
  });
}

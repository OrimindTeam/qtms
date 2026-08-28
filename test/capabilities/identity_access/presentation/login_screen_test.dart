/// شاشة الدخول — ★ **نمط 8** (`ui-guidelines.md` §3).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qtms/capabilities/identity_access/application/session_providers.dart';
import 'package:qtms/capabilities/identity_access/presentation/login_screen.dart';
import 'package:qtms/core/design/brand.dart';
import 'package:qtms/core/messages/error_messages.dart';
import 'package:qtms/core/startup/staging_qa_credentials.dart';
import 'package:qtms_domain/qtms_domain.dart';

import '../../../support/fake_identity.dart';

void main() {
  late FakeAuthRepository auth;

  setUp(() => auth = FakeAuthRepository());
  tearDown(() => auth.dispose());

  Future<void> pumpLogin(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(auth)],
        child: const MaterialApp(
          locale: Locale('ar'),
          home: LoginScreen(),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('★ العناصر الأربعة لنمط 8: شعار وعنوان وحقلان وزر عريض', (
    WidgetTester tester,
  ) async {
    await pumpLogin(tester);

    expect(find.byType(BrandLogo), findsOneWidget);
    expect(find.text('تسجيل الدخول'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.widgetWithText(FilledButton, 'دخول'), findsOneWidget);
  });

  testWidgets(
      '⛔★★ AM-002: الشعار أصلُ العميل الفعلي — ⛔ ولا رمز محايد من عائلة الإطار',
      (WidgetTester tester) async {
    await pumpLogin(tester);

    // ★ الأصل نفسه — ⛔ لا «أي صورة»: اختبارٌ يقبل أي مسار لا يمنع العودة
    //   إلى عنصر نائب.
    final Image logo = tester.widget<Image>(
      find.descendant(of: find.byType(BrandLogo), matching: find.byType(Image)),
    );
    expect((logo.image as AssetImage).assetName, brandLogoAsset);

    // ⛔ ولا رمز محايد بقي في الشاشة، ولا التسمية المؤقتة 'QTMS'.
    expect(find.byIcon(Icons.account_balance_wallet_outlined), findsNothing);
    expect(find.bySemanticsLabel('QTMS'), findsNothing);
    // ★ وقارئ الشاشة يسمع اسم العميل.
    expect(find.bySemanticsLabel(appDisplayName), findsOneWidget);
  });

  testWidgets('⛔ والزر معطَّل حتى يكتمل الحقلان — بلا رسالة تحقّق مخترَعة', (
    WidgetTester tester,
  ) async {
    await pumpLogin(tester);

    FilledButton button() =>
        tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button().onPressed, isNull);

    await tester.enterText(find.byType(TextField).first, 'owner@example.com');
    await tester.pump();
    expect(button().onPressed, isNull, reason: 'كلمة المرور ما تزال فارغة');

    await tester.enterText(find.byType(TextField).last, 'secret');
    await tester.pump();
    expect(button().onPressed, isNotNull);
  });

  testWidgets('★ الضغط يُمرِّر ما كتبه المستخدم إلى المستودع', (
    WidgetTester tester,
  ) async {
    await pumpLogin(tester);
    await tester.enterText(find.byType(TextField).first, ' owner@example.com ');
    await tester.enterText(find.byType(TextField).last, 'secret');
    await tester.pump();

    await tester.tap(find.byType(FilledButton));
    await tester.pump();

    // ★ التشذيب في المستودع لا في الشاشة — والشاشة تُمرِّر النصّ كما هو.
    expect(auth.lastEmail, ' owner@example.com ');
  });

  testWidgets('★★ الرفض المُصنَّف يظهر برسالة الكتالوج حرفياً', (
    WidgetTester tester,
  ) async {
    auth.result = const SignInRejected(SignInRejection.accountDisabled);
    await pumpLogin(tester);
    await tester.enterText(find.byType(TextField).first, 'owner@example.com');
    await tester.enterText(find.byType(TextField).last, 'secret');
    await tester.pump();

    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    await tester.pump();

    expect(
      find.text(catalogText(CatalogMessage.accountDisabled)),
      findsOneWidget,
    );
  });

  testWidgets('★ والقفل المؤقت كذلك — BR-M1-05', (WidgetTester tester) async {
    auth.result = const SignInRejected(SignInRejection.lockedOut);
    await pumpLogin(tester);
    await tester.enterText(find.byType(TextField).first, 'owner@example.com');
    await tester.enterText(find.byType(TextField).last, 'secret');
    await tester.pump();

    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    await tester.pump();

    expect(
      find.text(catalogText(CatalogMessage.temporaryLock)),
      findsOneWidget,
    );
  });

  // ★★ **الاختبار التالي مقلوبٌ عن سابقه بحسم `IQ-016` (2026-08-24)** — كان
  //    يُثبت **غياب** النصّ عمداً، وصار يُثبت **ظهوره** بنصّ الكتالوج حرفياً.
  testWidgets(
    '✅★★ IQ-016: «بيانات دخول غير صحيحة» تعرض ERR_AUTH_008 حرفياً',
    (WidgetTester tester) async {
      auth.result = const SignInRejected(SignInRejection.invalidCredentials);
      await pumpLogin(tester);
      await tester.enterText(find.byType(TextField).first, 'owner@example.com');
      await tester.enterText(find.byType(TextField).last, 'wrong');
      await tester.pump();

      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      await tester.pump();

      expect(
        find.text(catalogText(CatalogMessage.invalidCredentials)),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    '✅★ IQ-016: «فشل غير متوقَّع» تعرض ERR_AUTH_009 ⛔ ولا تتّهم المستخدم',
    (WidgetTester tester) async {
      auth.result = const SignInRejected(SignInRejection.unexpected);
      await pumpLogin(tester);
      await tester.enterText(find.byType(TextField).first, 'owner@example.com');
      await tester.enterText(find.byType(TextField).last, 'secret');
      await tester.pump();

      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      await tester.pump();

      expect(
        find.text(catalogText(CatalogMessage.unexpectedSignInFailure)),
        findsOneWidget,
      );
      // ⛔ **ولا تُخلط بحالة البيانات الخاطئة** — وهو ما حذّر منه الخيار (ج).
      expect(
        find.text(catalogText(CatalogMessage.invalidCredentials)),
        findsNothing,
      );
    },
  );

  test('★ ولا حالة رفض بلا نصّ — كل قيم SignInRejection مغطّاة', () {
    for (final SignInRejection reason in SignInRejection.values) {
      expect(catalogText(signInRejectionMessage(reason)), isNotEmpty);
    }
  });

  // ═══════ خُطّاف اختبار المحاكي — `AM-005` · `DEBT-31` ═══════

  Future<void> pumpWithQa(
    WidgetTester tester,
    StagingQaCredentials? qa,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          stagingQaCredentialsProvider.overrideWithValue(qa),
        ],
        child: const MaterialApp(locale: Locale('ar'), home: LoginScreen()),
      ),
    );
    await tester.pump();
  }

  testWidgets('⛔ بلا خُطّاف: الحقلان فارغان والزر معطَّل', (
    WidgetTester tester,
  ) async {
    await pumpWithQa(tester, null);

    for (final TextField field
        in tester.widgetList<TextField>(find.byType(TextField))) {
      expect(field.controller!.text, isEmpty);
    }
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
  });

  testWidgets('✅★★ ومع الخُطّاف: الحقلان مملوءان والزر مُفعَّل', (
    WidgetTester tester,
  ) async {
    await pumpWithQa(
      tester,
      const StagingQaCredentials(email: 'qa@example.test', password: 'س'),
    );

    final List<TextField> fields =
        tester.widgetList<TextField>(find.byType(TextField)).toList();
    expect(fields[0].controller!.text, 'qa@example.test');
    expect(fields[1].controller!.text, 'س');
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
  });

  testWidgets('⛔⛔ ولا إرسال تلقائياً — الجلسة تبقى بلا محاولة دخول', (
    WidgetTester tester,
  ) async {
    await pumpWithQa(
      tester,
      const StagingQaCredentials(email: 'qa@example.test', password: 'س'),
    );
    await tester.pump(const Duration(seconds: 1));

    // ⟵ **قياسٌ على المستودع نفسه لا على الواجهة:** ★ **بقاء `lastEmail`
    //   فارغاً يعني أن الملء لم يستدعِ المتحكّم إطلاقاً**، ⛔ **لا مجرد أن
    //   الشاشة لم تتغيّر.**
    expect(auth.lastEmail, isNull);
  });
}

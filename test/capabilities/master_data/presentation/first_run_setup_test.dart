/// الإعداد التأسيسي — ★★★ **البوابة الإلزامية والنموذج الذي لا رجعة فيه**.
///
/// ⚠️⚠️ **وأخطر ما يُختبَر هنا ليس النجاح بل المنع:** `FR-M21-04` يجعلها
/// «**شاشة إلزامية لا يمكن تخطّيها**»، ⟵ **فلو تسرّبت شاشة عملٍ قبلها
/// لصار الإعداد اختيارياً بلا أن يظهر ذلك في أي نصّ.**
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qtms/capabilities/identity_access/application/session_providers.dart';
import 'package:qtms/capabilities/identity_access/presentation/home_shell.dart';
import 'package:qtms/capabilities/master_data/application/master_data_providers.dart';
import 'package:qtms/capabilities/master_data/presentation/first_run_setup_screen.dart';
import 'package:qtms/core/messages/error_messages.dart';
import 'package:qtms/core/startup/app_startup.dart';
import 'package:qtms/main.dart';
import 'package:qtms_domain/qtms_domain.dart';

import '../../../support/fake_identity.dart';
import '../../../support/fake_master_data.dart';

/// نبضات محدودة — ⛔ **ولا `pumpAndSettle`**: شاشة الانتظار تحمل مؤشّراً
/// دوّاراً لا ينتهي.
Future<void> settle(WidgetTester tester) async {
  for (int i = 0; i < 16; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// إعداد مكتوب — لاختبار الخروج من البوابة.
const AppSettingsCard writtenSettings = AppSettingsCard(
  businessName: 'وكالة محمد المحامي',
  currencySymbol: 'ر.ي',
  decimalPlaces: 0,
  thousandsSeparator: ',',
);

void main() {
  late FakeAuthRepository auth;
  late FakeUserCardRepository cards;
  late FakeMasterDataDirectory directory;
  late FakeMasterDataAdmin admin;

  setUp(() {
    auth = FakeAuthRepository();
    cards = FakeUserCardRepository();
    directory = FakeMasterDataDirectory();
    admin = FakeMasterDataAdmin();
  });

  tearDown(() {
    auth.dispose();
    cards.dispose();
    directory.dispose();
  });

  Widget app() => ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          userCardRepositoryProvider.overrideWithValue(cards),
          masterDataDirectoryProvider.overrideWithValue(directory),
          masterDataAdminProvider.overrideWithValue(admin),
        ],
        child: const QtmsApp(outcome: StartupReady()),
      );

  void signIn({Set<Permission> permissions = const <Permission>{}}) {
    auth.emitIdentity(
      const AuthenticatedIdentity(userId: 'U-001', sourceScope: AllSources()),
    );
    cards.emitCard('U-001', testCard(permissions: permissions));
  }

  testWidgets('★★★ FR-M21-04: المالك يُحبَس في الإعداد قبل كتابة البندين',
      (WidgetTester tester) async {
    signIn(permissions: const <Permission>{Permission.appSettingsWrite});
    directory.emitSettings(null);

    await tester.pumpWidget(app());
    await settle(tester);

    expect(find.byType(FirstRunSetupScreen), findsOneWidget);
    expect(find.byType(HomeShell), findsNothing);
  });

  testWidgets('⛔★★ ولا تُفتَح لمن لا يملك `appSettingsWrite` — فلا مخرَج له',
      (WidgetTester tester) async {
    // ⚠️⚠️ **وهذا ليس تخفيفاً للبوابة بل شرطها الثاني:** «عند أول تشغيل
    //    **بحساب المالك**». ⟵ **وحبسُ موظفٍ فيها يقفل عليه النظام** بلا
    //    مسارٍ لإتمامها.
    signIn(permissions: const <Permission>{Permission.userView});
    directory.emitSettings(null);

    await tester.pumpWidget(app());
    await settle(tester);

    expect(find.byType(FirstRunSetupScreen), findsNothing);
    expect(find.byType(HomeShell), findsOneWidget);
  });

  testWidgets('✅ وبعد كتابة البندين يُغادرها من تلقائه',
      (WidgetTester tester) async {
    signIn(permissions: const <Permission>{Permission.appSettingsWrite});
    directory.emitSettings(null);

    await tester.pumpWidget(app());
    await settle(tester);
    expect(find.byType(FirstRunSetupScreen), findsOneWidget);

    // ★ التدفّق حيّ — ⟵ **فوصول المستندين يُخرجه بلا ملاحة يدوية.**
    directory.emitSettings(writtenSettings);
    await settle(tester);

    expect(find.byType(FirstRunSetupScreen), findsNothing);
    expect(find.byType(HomeShell), findsOneWidget);
  });

  testWidgets('★★ والحفظ معطَّل حتى يُقرّ المستخدم صراحةً — FR-M21-04',
      (WidgetTester tester) async {
    signIn(permissions: const <Permission>{Permission.appSettingsWrite});
    directory.emitSettings(null);

    await tester.pumpWidget(app());
    await settle(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'اسم المحل'),
      'وكالة محمد المحامي',
    );
    await tester.pump();

    // ⛔ **بلا إقرار ⟵ الزر معطَّل فعلياً** لا تحذيراً.
    final Finder save = find.widgetWithText(FilledButton, 'حفظ الإعداد نهائياً');
    expect(tester.widget<FilledButton>(save).onPressed, isNull);


    // ⚠️ **الإقرار أسفل النموذج الطويل** — ⟵ يُمرَّر إليه أولاً، ⛔ فالنقر
    //    على ما هو خارج الإطار **لا يُصيب شيئاً بصمت**.
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    expect(tester.widget<FilledButton>(save).onPressed, isNotNull);

    await tester.ensureVisible(save);
    await tester.pump();
    await tester.tap(save);
    await settle(tester);

    expect(admin.calls, 1);
    expect(admin.lastSettings?.businessName, 'وكالة محمد المحامي');
    // ★★ **وصفرٌ حتماً** — `ADR-0015`.
    expect(admin.lastSettings?.decimalPlaces, 0);
  });

  testWidgets('⛔★★★ AT-65: رفض الكتابة الثانية يُعرَض بنصّه',
      (WidgetTester tester) async {
    signIn(permissions: const <Permission>{Permission.appSettingsWrite});
    directory.emitSettings(null);
    admin.failure = const InfrastructureError('ERR_SETUP_010');

    await tester.pumpWidget(app());
    await settle(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'اسم المحل'),
      'وكالة محمد المحامي',
    );
    await tester.pump();

    final Finder save = find.widgetWithText(FilledButton, 'حفظ الإعداد نهائياً');
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.ensureVisible(save);
    await tester.pump();
    await tester.tap(save);
    await settle(tester);

    // ★ **الطلب وصل فعلاً** — ⟵ فالرفض المعروض رفضُ السحابة لا صمتُ زرٍّ
    //   معطَّل، ⛔ **ولا يمرّ الاختبار لسبب خاطئ.**
    expect(admin.calls, 1);
    expect(
      find.text(catalogText(CatalogMessage.appSettingsAlreadyWritten)),
      findsOneWidget,
    );
  });

  testWidgets('⛔ ولا حقل لعدد الخانات العشرية في الشاشة — ADR-0015',
      (WidgetTester tester) async {
    signIn(permissions: const <Permission>{Permission.appSettingsWrite});
    directory.emitSettings(null);

    await tester.pumpWidget(app());
    await settle(tester);

    expect(find.textContaining('خانات عشرية'), findsNothing);
    expect(
      find.text('المبالغ أعداد صحيحة بالريال — بلا كسور عشرية.'),
      findsOneWidget,
    );
  });

  // ══════════════════════════════════════════════════════════════════════
  // ★★★ AM-018 — الرفضُ يُسمّي حقلَه · والنجاحُ يُرى · والفاصلُ قائم
  // ══════════════════════════════════════════════════════════════════════

  /// ★ يملأ النموذجَ ويُقرّ ثم يضغط الحفظ.
  Future<void> fillAndSave(
    WidgetTester tester, {
    String businessName = 'وكالة محمد المحامي',
    String? separator,
  }) async {
    await tester.enterText(
      find.widgetWithText(TextField, 'اسم المحل'),
      businessName,
    );
    if (separator != null) {
      await tester.enterText(
        find.widgetWithText(TextField, 'فاصل الآلاف'),
        separator,
      );
    }
    await tester.pump();
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    final Finder save =
        find.widgetWithText(FilledButton, firstRunSetupSaveLabel);
    await tester.ensureVisible(save);
    await tester.pump();
    await tester.tap(save);
  }

  testWidgets(
    '⛔⛔★★★ AM-018: رفضُ التحقق المحلي يُسمّي حقلَه — ⛔ لا رسالةٌ عامة',
    (WidgetTester tester) async {
      signIn(permissions: const <Permission>{Permission.appSettingsWrite});
      directory.emitSettings(null);

      await tester.pumpWidget(app());
      await settle(tester);

      // ⛔ **اسمٌ فارغ** — `FR-M21-01`.
      await fillAndSave(tester, businessName: '   ');
      await settle(tester);

      expect(admin.calls, 0);
      expect(find.textContaining('اسم المحل'), findsWidgets);
      // ⛔⛔ **ولا الرسالةُ العامة.**
      expect(
        find.text(catalogText(CatalogMessage.operationFailed)),
        findsNothing,
      );

      // ⛔ **وفاصلٌ بمحرفين** — `FR-M21-02`: ★ **ورسالةٌ أخرى غيرُ الأولى.**
      await tester.enterText(
        find.widgetWithText(TextField, 'اسم المحل'),
        'وكالة محمد المحامي',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'فاصل الآلاف'),
        '__',
      );
      await tester.pump();
      final Finder save =
          find.widgetWithText(FilledButton, firstRunSetupSaveLabel);
      await tester.ensureVisible(save);
      await tester.pump();
      await tester.tap(save);
      await settle(tester);

      expect(admin.calls, 0);
      expect(find.textContaining('فاصل الآلاف'), findsWidgets);
    },
  );

  testWidgets('★★ AM-018: ونجاحُ الحفظ يُعرَض قبل خروج الشاشة',
      (WidgetTester tester) async {
    signIn(permissions: const <Permission>{Permission.appSettingsWrite});
    directory.emitSettings(null);

    await tester.pumpWidget(app());
    await settle(tester);

    await fillAndSave(tester);
    await tester.pump();

    expect(admin.calls, 1);
    expect(find.text(firstRunSetupSavedMessage), findsOneWidget);
    await settle(tester);
  });

  testWidgets('★ AM-018: وفاصلٌ تحت عنوان «بيانات المنشأة» كشاشة الإعدادات',
      (WidgetTester tester) async {
    signIn(permissions: const <Permission>{Permission.appSettingsWrite});
    directory.emitSettings(null);

    await tester.pumpWidget(app());
    await settle(tester);

    // ★ **عنوانان ⟵ فاصلان** — ⛔ **ولا عنوانَ عائمٌ بلا حدّ.**
    expect(find.byType(Divider), findsNWidgets(2));
    final double titleY = tester.getRect(find.text('بيانات المنشأة')).bottom;
    final double dividerY = tester.getRect(find.byType(Divider).first).top;
    expect(dividerY, greaterThan(titleY));
  });
}

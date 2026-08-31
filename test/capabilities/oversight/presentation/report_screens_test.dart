/// شاشتا التقارير — `WU-011` (`M19`).
///
/// ⚠️⚠️ **وما تُثبته هذه الاختبارات وما لا تُثبته:** تُثبت أن **ما لا يملك
/// المستخدم مفتاحَ عائلته لا يُرسَم**، وأن **الاستعلام يقع على المصدر
/// والفترة اللذين اختارهما**، وأن **«كل المصادر» تُعدَّد مصادرَ لا تصل
/// غياباً** (`IQ-024` · `DEBT-40`)، وأن **القراءات المحكومة بشرطٍ مستقل
/// لا تُطلَب أصلاً بلا مفتاحها** (`ت-12` · `ADR-0017`).
///
/// ⛔⛔ **ولا تُثبت أن الأرقام محميّة** — ★ **ذاك شرطُ قراءة كلِّ مجموعةٍ في
/// `firestore.rules` مُختبَراً على المحاكي** (`RISK-02` · `DEBT-71`):
/// ⟵ **وبوابةُ الشاشة إخفاءٌ لا حماية** ⛔ **ولا يُدَّعى غيرُ ذلك.**
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qtms/capabilities/identity_access/application/session_providers.dart';
import 'package:qtms/capabilities/master_data/application/master_data_providers.dart';
import 'package:qtms/capabilities/oversight/application/report_providers.dart';
import 'package:qtms/capabilities/oversight/presentation/report_view_screen.dart';
import 'package:qtms/capabilities/oversight/presentation/reports_screen.dart';
import 'package:qtms_domain/qtms_domain.dart';

import '../../../support/fake_identity.dart';
import '../../../support/fake_master_data.dart';
import '../../../support/fake_oversight.dart';

late FakeReportDirectory reports;
late FakeMasterDataDirectory masterData;

/// ★ صاحبُ التقارير المخزنية وحدها — **أضيقُ حالةٍ مفيدة**.
const Set<Permission> inventoryReader = <Permission>{
  Permission.reportInventoryView,
};

Future<void> pumpScreen(
  WidgetTester tester,
  Widget screen, {
  Set<Permission> actorPermissions = inventoryReader,
  SourceScope? scope = const AllSources(),
}) async {
  final FakeAuthRepository auth = FakeAuthRepository();
  final FakeUserCardRepository cards = FakeUserCardRepository();
  auth.emitIdentity(
    AuthenticatedIdentity(
      userId: 'U-001',
      sourceScope: scope ?? const AllSources(),
    ),
  );
  cards.emitCard(
    'U-001',
    testCard(permissions: actorPermissions, sourceScope: scope),
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        userCardRepositoryProvider.overrideWithValue(cards),
        masterDataDirectoryProvider.overrideWithValue(masterData),
        masterDataAdminProvider.overrideWithValue(FakeMasterDataAdmin()),
        contactPickerProvider.overrideWithValue(null),
        reportDirectoryProvider.overrideWithValue(reports),
      ],
      child: MaterialApp(locale: const Locale('ar'), home: screen),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 20));
  // ★★ **ونبضتان بعدها لا واحدة** — ⟵ **الأولى تُوصِل قائمة المصادر،
  //    والثانية تبني التقرير عليها** (`effectiveReportSources`).
  await tester.pump(const Duration(milliseconds: 20));
  await tester.pump(const Duration(milliseconds: 20));
}

void main() {
  setUp(() {
    reports = FakeReportDirectory();
    masterData = FakeMasterDataDirectory();
    masterData.emitSources(<SourceCard>[
      SourceCard(
        sourceId: 'SRC-001',
        name: 'رداع',
        requiresSupplierOnIntake: false,
        isActive: true,
      ),
      SourceCard(
        sourceId: 'SRC-002',
        name: 'ماوية',
        requiresSupplierOnIntake: false,
        isActive: true,
      ),
    ]);
    masterData.emitDealers(const <DealerCard>[]);
    masterData.emitItems(const <ItemCard>[]);
    masterData.emitSuppliers(const <SupplierCard>[]);
    masterData.emitSettings(null);
  });

  group('★★★ قائمة التقارير — ⛔ وما لا مفتاحَ له لا يُرسَم', () {
    testWidgets('★ عائلةُ المستخدم وحدها تظهر بعنوانها',
        (WidgetTester tester) async {
      await pumpScreen(tester, const ReportsScreen());

      expect(find.text('التقارير المخزنية'), findsOneWidget);
      expect(find.text('حركة نوع تفصيلية'), findsOneWidget);
      expect(find.text('رصيد المخزون الحالي'), findsOneWidget);
      // ⛔⛔ **ولا عنوانٌ فوق فراغ** — العائلةُ الأخرى تختفي كلُّها.
      expect(find.text('التقارير المالية'), findsNothing);
      expect(find.text('المقبوضات'), findsNothing);
    });

    testWidgets('⛔ وبلا أي مفتاحٍ حالةٌ فارغة بسببها وخطوتها',
        (WidgetTester tester) async {
      await pumpScreen(
        tester,
        const ReportsScreen(),
        actorPermissions: const <Permission>{},
      );

      expect(find.text('لا تقرير ضمن صلاحياتك'), findsOneWidget);
      expect(find.textContaining('راجع المدير'), findsOneWidget);
    });
  });

  group('★★★ شاشة التقرير — الاستعلام بما اختاره المستخدم', () {
    testWidgets('★ رصيدُ المخزون يُبنى ويُعرَض بإجمالياته',
        (WidgetTester tester) async {
      reports.balances = <ItemDailyBalanceCard>[
        ItemDailyBalanceCard(
          sourceId: 'SRC-001',
          itemKey: 'ITM-1',
          itemName: 'شامي',
          stockDate: CalendarDay(2026, 8, 20),
          incoming: const PieceQuantity(PieceCount(60)),
          outgoing: const PieceQuantity(PieceCount(20)),
          balance: const PieceQuantity(PieceCount(40)),
        ),
      ];
      await pumpScreen(
        tester,
        const ReportViewScreen(report: ReportId.currentStock),
      );

      expect(find.text('شامي'), findsOneWidget);
      expect(find.text('عدد الأنواع'), findsOneWidget);
      // ★★ **والإجمالي يفصل الحبات عن الأوزان** (`GR-19`).
      expect(find.textContaining('40 حبة + 0.000 كجم'), findsWidgets);
      // ★ **وأولُ مصدرٍ في النطاق افتراضاً** — ⛔ **ولا استعلامَ بمصدرٍ آخر.**
      expect(reports.requestedSources.toSet(), <String>{'SRC-001'});
    });

    testWidgets('⛔⛔★★★ ولا يُعرَض جدولُ الطلب السابق أثناء إعادة الحساب',
        (WidgetTester tester) async {
      // ⛔⛔★★★ **`DEBT-74` — كشفه المحاكي وحده:** ★ **`AsyncValue` تحتفظ
      //    بقيمة الطلب السابق أثناء التحديث**، ⟵ **فظهر جدولُ «التوزيعات»
      //    بإجمالياته تحت عنوان «الضمارات» ثوانيَ كاملة** ⛔ **بلا مؤشّرٍ
      //    أن الأرقام ليست لهذا الطلب** — ★ **وهي أرقامٌ تُصدَّر إلى PDF.**
      reports.balances = <ItemDailyBalanceCard>[
        ItemDailyBalanceCard(
          sourceId: 'SRC-001',
          itemKey: 'ITM-1',
          itemName: 'شامي',
          stockDate: CalendarDay(2026, 8, 20),
          incoming: const PieceQuantity(PieceCount(60)),
          outgoing: const PieceQuantity(PieceCount(20)),
          balance: const PieceQuantity(PieceCount(40)),
        ),
      ];
      await pumpScreen(
        tester,
        const ReportViewScreen(report: ReportId.currentStock),
      );
      expect(find.text('شامي'), findsOneWidget);

      // ★ **وإعادةُ الحساب تُعلَّق** — ⟵ **فتقع النافذة التي فيها العطل.**
      reports.delay = const Duration(milliseconds: 200);
      await tester.tap(find.text('كل المصادر'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));

      // ⛔ **لا صفَّ ولا إجمالياً من الطلب السابق** — ★ **هيكلُ تحميلٍ مكانَه.**
      expect(find.text('شامي'), findsNothing);
      expect(find.text('عدد الأنواع'), findsNothing);

      // ✅ **ويعود بعد اكتمال البناء الجديد** — ★ **صفٌّ لكل مصدر.**
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('شامي'), findsNWidgets(2));
    });

    testWidgets('⛔⛔ و«كل المصادر» تُعدَّد مصادرَ ولا تصل غياباً',
        (WidgetTester tester) async {
      await pumpScreen(
        tester,
        const ReportViewScreen(report: ReportId.currentStock),
      );
      await tester.tap(find.text('كل المصادر'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));

      expect(reports.requestedSources, contains('SRC-001'));
      expect(reports.requestedSources, contains('SRC-002'));
    });

    testWidgets('★ وحالةٌ فارغة بسببها حين لا حركة في المدى',
        (WidgetTester tester) async {
      await pumpScreen(
        tester,
        const ReportViewScreen(report: ReportId.currentStock),
      );

      expect(find.text('لا حركة في هذا المدى'), findsOneWidget);
      expect(find.textContaining('وسّع الفترة'), findsOneWidget);
    });

    testWidgets('⛔ والرفضُ يُعرَض خطأً لا فراغاً', (WidgetTester tester) async {
      reports.failure = Exception('permission-denied');
      await pumpScreen(
        tester,
        const ReportViewScreen(report: ReportId.currentStock),
      );

      // ★★ **ورسالةُ الكتالوج لا نصٌّ محلي** (`error-handling-strategy.md`
      //    §3 القاعدة 2) — ★ **و«ممنوع» تُترجَم `PermissionError`.**
      expect(find.textContaining('ليس لديك صلاحية'), findsOneWidget);
    });

    testWidgets('★★ و`R-01` بلا نوعٍ مختار يقول ما ينقص',
        (WidgetTester tester) async {
      await pumpScreen(
        tester,
        const ReportViewScreen(report: ReportId.itemMovements),
      );

      expect(find.text('اختر ما يلزم لبناء التقرير'), findsOneWidget);
      expect(find.textContaining('اختر النوع'), findsOneWidget);
      // ⛔ **ولا استعلامَ يقع أصلاً** — ★ **فلا قراءةٌ بلا مفتاحِ نوع.**
      expect(reports.requestedSources, isEmpty);
    });
  });

  group('⛔⛔★★ القراءاتُ المحكومةُ بشرطٍ مستقل لا تُطلَب بلا مفتاحها', () {
    testWidgets('⛔ أسعارُ الضمارات لا تُقرأ بلا `distributionPriceView`',
        (WidgetTester tester) async {
      await pumpScreen(
        tester,
        const ReportViewScreen(report: ReportId.settlements),
        actorPermissions: const <Permission>{Permission.reportSalesView},
      );

      expect(reports.pricingRequested, isFalse);
    });

    testWidgets('✅ وتُقرأ لمن يملكه', (WidgetTester tester) async {
      await pumpScreen(
        tester,
        const ReportViewScreen(report: ReportId.settlements),
        actorPermissions: const <Permission>{
          Permission.reportSalesView,
          Permission.distributionPriceView,
        },
      );

      expect(reports.pricingRequested, isTrue);
    });

    testWidgets('⛔ وحالةُ الإيداع لا تُقرأ بلا `receiptDepositView`',
        (WidgetTester tester) async {
      await pumpScreen(
        tester,
        const ReportViewScreen(report: ReportId.receipts),
        actorPermissions: const <Permission>{Permission.reportFinancialView},
      );

      expect(reports.depositsRequested, isFalse);
    });
  });

  group('★★ زرُّ التصدير — بمفتاحه وحده', () {
    testWidgets('⛔ لا يظهر بلا `documentExport`', (WidgetTester tester) async {
      reports.balances = <ItemDailyBalanceCard>[
        ItemDailyBalanceCard(
          sourceId: 'SRC-001',
          itemKey: 'ITM-1',
          itemName: 'شامي',
          stockDate: CalendarDay(2026, 8, 20),
          incoming: const PieceQuantity(PieceCount(1)),
          outgoing: const PieceQuantity(PieceCount(0)),
          balance: const PieceQuantity(PieceCount(1)),
        ),
      ];
      await pumpScreen(
        tester,
        const ReportViewScreen(report: ReportId.currentStock),
      );

      expect(find.text('تصدير ومشاركة'), findsNothing);
    });

    testWidgets('✅ ويظهر لمن يملكه', (WidgetTester tester) async {
      reports.balances = <ItemDailyBalanceCard>[
        ItemDailyBalanceCard(
          sourceId: 'SRC-001',
          itemKey: 'ITM-1',
          itemName: 'شامي',
          stockDate: CalendarDay(2026, 8, 20),
          incoming: const PieceQuantity(PieceCount(1)),
          outgoing: const PieceQuantity(PieceCount(0)),
          balance: const PieceQuantity(PieceCount(1)),
        ),
      ];
      await pumpScreen(
        tester,
        const ReportViewScreen(report: ReportId.currentStock),
        actorPermissions: const <Permission>{
          Permission.reportInventoryView,
          Permission.documentExport,
        },
      );

      expect(find.text('تصدير ومشاركة'), findsOneWidget);
    });
  });

  group('⛔⛔★★ «كل المصادر» لصاحب النطاق الشامل وحدَه', () {
    testWidgets('⛔ ولا تُعرَض لصاحب نطاقٍ محدود',
        (WidgetTester tester) async {
      await pumpScreen(
        tester,
        const ReportViewScreen(report: ReportId.currentStock),
        scope: ScopedSources(const <String>{'SRC-001'}),
      );

      expect(find.text('رداع'), findsOneWidget);
      // ⟵ **و`canAccessSource('all')` لا تصدُق له** (`export_log.dart`)،
      //    ⛔ **فبطاقةُ الخيار كانت ستُنتج تصديراً مرفوضاً دائماً.**
      expect(find.text('كل المصادر'), findsNothing);
    });
  });
}

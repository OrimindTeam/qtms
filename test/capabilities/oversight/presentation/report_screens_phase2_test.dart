/// شاشتا التقارير — تقاريرُ المرحلة الثانية (`WU-018` · `M19`).
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⚠️⚠️ **وما تُثبته هذه الاختبارات وما لا تُثبته:** تُثبت أن **التقرير الذي
/// يُرَدُّ استعلامُه دائماً لا يُعرَض أصلاً** (مفاتيحُه الزائدة —
/// [ReportId.requiredPermissions])، وأن **`ledgerType` مُقيَّدٌ في الاستعلام
/// استعلامين لا واحد** ([`DEBT-89`])، وأن **تقارير اليوم الواحد بلا مدى**
/// ([`DEBT-94`])، وأن **رفضَ القراءة يصعد خطأً صريحاً لا «لا بيانات»**.
///
/// ⛔⛔ **ولا تُثبت أن الأرقام محميّة** — ★ **ذاك شرطُ قراءة كلِّ مجموعةٍ في
/// `firestore.rules` مُختبَراً على المحاكي** (`RISK-02` · `DEBT-71`).
/// ═══════════════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qtms/capabilities/financial_outflow/application/owner_ledger_providers.dart';
import 'package:qtms/capabilities/identity_access/application/session_providers.dart';
import 'package:qtms/capabilities/inventory/application/sack_valuation_providers.dart';
import 'package:qtms/capabilities/master_data/application/master_data_providers.dart';
import 'package:qtms/capabilities/oversight/application/report_providers.dart';
import 'package:qtms/capabilities/oversight/presentation/report_view_screen.dart';
import 'package:qtms/capabilities/oversight/presentation/reports_screen.dart';
import 'package:qtms_domain/qtms_domain.dart';

import '../../../support/fake_identity.dart';
import '../../../support/fake_master_data.dart';
import '../../../support/fake_oversight.dart';
import '../../../support/fake_owner_ledger.dart';
import '../../../support/fake_sack_valuation.dart';
import '../../../support/fake_sacks.dart';

late FakeReportDirectory reports;
late FakeMasterDataDirectory masterData;
late FakeCashMovementReader cashMovement;
late FakeSackValuationDirectory valuation;

Future<void> pumpScreen(
  WidgetTester tester,
  Widget screen, {
  required Set<Permission> actorPermissions,
}) async {
  final FakeAuthRepository auth = FakeAuthRepository();
  final FakeUserCardRepository cards = FakeUserCardRepository();
  auth.emitIdentity(
    const AuthenticatedIdentity(userId: 'U-001', sourceScope: AllSources()),
  );
  cards.emitCard('U-001', testCard(permissions: actorPermissions));

  // ★★ **وسطحٌ أطول من الافتراضي** — ⬛ **وليس تجميلاً:**
  // ⟵ **قائمة `ListView` لا تبني ما خرج عن الشاشة**، ★ **وعائلةٌ فيها
  //   ستةُ تقارير تتجاوز 800 بكسل** ⟹ **فيفشل البحث عن آخرها بلا أن
  //   يكون ثمَّ عيبٌ أصلاً.**
  await tester.binding.setSurfaceSize(const Size(900, 2200));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        userCardRepositoryProvider.overrideWithValue(cards),
        masterDataDirectoryProvider.overrideWithValue(masterData),
        masterDataAdminProvider.overrideWithValue(FakeMasterDataAdmin()),
        contactPickerProvider.overrideWithValue(null),
        reportDirectoryProvider.overrideWithValue(reports),
        cashMovementReaderProvider.overrideWithValue(cashMovement),
        sackValuationDirectoryProvider.overrideWithValue(valuation),
      ],
      child: MaterialApp(locale: const Locale('ar'), home: screen),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 20));
  await tester.pump(const Duration(milliseconds: 20));
  await tester.pump(const Duration(milliseconds: 20));
}

void main() {
  setUp(() {
    reports = FakeReportDirectory();
    cashMovement = FakeCashMovementReader();
    valuation = FakeSackValuationDirectory();
    masterData = FakeMasterDataDirectory();
    masterData.emitSources(<SourceCard>[
      SourceCard(
        sourceId: 'SRC-001',
        name: 'رداع',
        requiresSupplierOnIntake: false,
        isActive: true,
      ),
    ]);
    masterData.emitDealers(const <DealerCard>[]);
    masterData.emitItems(const <ItemCard>[]);
    masterData.emitSuppliers(<SupplierCard>[
      SupplierCard(
        supplierId: 'SUP-1',
        name: 'رعوي أول',
        phone: '770000000',
        isActive: true,
      ),
    ]);
    masterData.emitSettings(null);
  });

  tearDown(() => valuation.dispose());

  group('⛔⛔★★★ المفاتيحُ الزائدة — وتقريرٌ يُرَدُّ دائماً لا يُعرَض', () {
    testWidgets('⛔ `R-20` يختفي بلا `ownerLedgerView` رغم مفتاح العائلة',
        (WidgetTester tester) async {
      await pumpScreen(
        tester,
        const ReportsScreen(),
        actorPermissions: const <Permission>{Permission.reportFinancialView},
      );

      expect(find.text('المقبوضات'), findsOneWidget);
      expect(find.text('ضمار المالك اليومي'), findsNothing);
    });

    testWidgets('★ ويظهر بمفتاحه', (WidgetTester tester) async {
      await pumpScreen(
        tester,
        const ReportsScreen(),
        actorPermissions: const <Permission>{
          Permission.reportFinancialView,
          Permission.ownerLedgerView,
        },
      );

      expect(find.text('ضمار المالك اليومي'), findsOneWidget);
    });

    testWidgets('⛔ و`R-23` يشترط مفتاحَه المستقل فوق مفتاح العائلة',
        (WidgetTester tester) async {
      await pumpScreen(
        tester,
        const ReportsScreen(),
        actorPermissions: const <Permission>{
          Permission.reportOutflowView,
          Permission.withdrawalView,
          Permission.expenseView,
          Permission.ownerLedgerView,
        },
      );

      expect(find.text('سجل السحبيات (المالك)'), findsOneWidget);
      expect(find.text('الأثر النهائي على حساب المصدر'), findsNothing);
    });

    testWidgets('⛔⛔ وتقريرا السحبيات والخرجيات منفصلان بمفتاحيهما',
        (WidgetTester tester) async {
      await pumpScreen(
        tester,
        const ReportsScreen(),
        actorPermissions: const <Permission>{
          Permission.reportOutflowView,
          Permission.withdrawalView,
        },
      );

      expect(find.text('سجل السحبيات (المالك)'), findsOneWidget);
      // ⛔ **ومن يرى السحبيات لا يرى الخرجيات** — `FR-M19-07` · `GR-43`.
      expect(find.text('سجل الخرجيات (التشغيلية)'), findsNothing);
    });

    testWidgets('⛔⛔ و`R-27` يشترط مفتاحَي السحبيات والخرجيات معاً',
        (WidgetTester tester) async {
      await pumpScreen(
        tester,
        const ReportsScreen(),
        actorPermissions: const <Permission>{
          Permission.reportSupplierView,
          Permission.supplierFinanceView,
          Permission.withdrawalView,
        },
      );

      expect(find.text('حساب الرعوي لكل مصدر'), findsOneWidget);
      expect(find.text('تفكيك سعر جونية'), findsNothing);
    });

    testWidgets('⛔⛔ و`R-07` غيرُ معروضٍ أصلاً — لا كاتبَ للإتلاف بعد',
        (WidgetTester tester) async {
      await pumpScreen(
        tester,
        const ReportsScreen(),
        actorPermissions: const <Permission>{Permission.reportInventoryView},
      );

      expect(find.textContaining('الوزن الضائع'), findsNothing);
    });
  });

  group('⛔⛔★★★ `ledgerType` مُقيَّدٌ في الاستعلام — DEBT-89', () {
    testWidgets('★ سجلُّ السحبيات يستعلم السحبيات وحدها',
        (WidgetTester tester) async {
      reports.outflowCards = <OutflowCard>[
        OutflowCard(
          documentNumber: 'WDR-1',
          ledgerType: OutflowLedgerType.withdrawal,
          category: OutflowCategory.withdrawalCash,
          date: CalendarDay(2026, 9, 1),
          stockDate: CalendarDay(2026, 9, 1),
          sourceId: 'SRC-001',
          totalQatValue: Money.zero,
          totalCashValue: const Money(700),
          grandTotal: const Money(700),
          unpricedItemCount: 0,
          isCancelled: false,
          qatLines: const <OutflowCardQatLine>[],
          cashLines: const <OutflowCardCashLine>[],
        ),
      ];

      await pumpScreen(
        tester,
        const ReportViewScreen(report: ReportId.withdrawals),
        actorPermissions: const <Permission>{
          Permission.reportOutflowView,
          Permission.withdrawalView,
        },
      );

      // ★ **والمقياسُ نوعُ ما استُعلم به لا عددُ مرات البناء** — ⛔ **فالشاشة
      //   قد تُعيد البناء عند وصول قائمة المصادر.**
      expect(
        reports.requestedLedgerTypes.toSet(),
        <OutflowLedgerType>{OutflowLedgerType.withdrawal},
      );
      expect(find.text('WDR-1'), findsOneWidget);
    });

    testWidgets('★ وسجلُّ الخرجيات يستعلم الخرجيات وحدها',
        (WidgetTester tester) async {
      await pumpScreen(
        tester,
        const ReportViewScreen(report: ReportId.expenses),
        actorPermissions: const <Permission>{
          Permission.reportOutflowView,
          Permission.expenseView,
        },
      );

      expect(
        reports.requestedLedgerTypes.toSet(),
        <OutflowLedgerType>{OutflowLedgerType.expense},
      );
    });
  });

  group('★★ تقاريرُ اليوم الواحد — DEBT-94', () {
    testWidgets('⛔ حركةُ النقد بتاريخٍ واحد بلا «تغيير البداية»',
        (WidgetTester tester) async {
      await pumpScreen(
        tester,
        const ReportViewScreen(report: ReportId.cashMovement),
        actorPermissions: const <Permission>{Permission.reportFinancialView},
      );

      expect(find.text('تغيير البداية'), findsNothing);
      expect(find.text('تغيير التاريخ'), findsOneWidget);
      // ★★ **والاسم يقول أيَّ تاريخ** — `ui-guidelines.md` §2.
      expect(find.textContaining('تاريخ الحركة'), findsOneWidget);
    });

    testWidgets('★ والقارئُ يُستدعى بمصادر النطاق ذاتِها',
        (WidgetTester tester) async {
      await pumpScreen(
        tester,
        const ReportViewScreen(report: ReportId.cashMovement),
        actorPermissions: const <Permission>{Permission.reportFinancialView},
      );

      expect(cashMovement.lastSourceIds, <String>['SRC-001']);
      // ⛔ **ولا تُقرأ مستنداتُ الإيداع بلا مفتاحها** — `ADR-0017`.
      expect(cashMovement.lastReadsDeposit, isFalse);
    });
  });

  group('★★ `R-25` — فلترُ الرعوي محليٌّ', () {
    testWidgets('★ قائمةُ الرعية تُعرَض مع «كل الرعية»',
        (WidgetTester tester) async {
      reports.supplierRows = <SupplierLedgerRow>[
        const SupplierLedgerRow(
          sackId: 'SCK-1',
          supplierId: 'SUP-1',
          sourceId: 'SRC-001',
          sackRevenue: Money(1000),
          recalcVersion: 1,
          supplierName: 'رعوي أول',
          sackDisplayName: 'جونية 1',
          sackTax: Money(100),
          supplierNet: Money(900),
        ),
      ];

      await pumpScreen(
        tester,
        const ReportViewScreen(report: ReportId.supplierAccount),
        actorPermissions: const <Permission>{
          Permission.reportSupplierView,
          Permission.supplierFinanceView,
        },
      );

      expect(find.text('كل الرعية'), findsOneWidget);
      expect(find.text('رعوي أول'), findsWidgets);
      expect(find.text('جونية 1'), findsOneWidget);
    });
  });

  group('★★★ `R-27` — تفكيك سعر جونية', () {
    testWidgets('⛔ وبلا اختيار جونية رسالةٌ تقول ما ينقص',
        (WidgetTester tester) async {
      await pumpScreen(
        tester,
        const ReportViewScreen(report: ReportId.sackPriceBreakdown),
        actorPermissions: const <Permission>{
          Permission.reportSupplierView,
          Permission.withdrawalView,
          Permission.expenseView,
        },
      );

      expect(find.textContaining('اختر الجونية'), findsOneWidget);
    });

    testWidgets('★★ واختيارُها يقرأ حركاتِ يومِ مخزونها هي',
        (WidgetTester tester) async {
      final CalendarDay sackDay = CalendarDay(2026, 9, 1);
      reports.sackCards = <SackCard>[
        testSack(documentNumber: 'SCK-20260901-0001', stockDate: sackDay),
      ];
      valuation.setBreakdown(
        Success<List<SackRevenueContribution>>(<SackRevenueContribution>[
          testContribution(lineValue: 5000),
        ]),
      );

      await pumpScreen(
        tester,
        const ReportViewScreen(report: ReportId.sackPriceBreakdown),
        actorPermissions: const <Permission>{
          Permission.reportSupplierView,
          Permission.withdrawalView,
          Permission.expenseView,
        },
      );

      await tester.tap(find.text('عبدالفتاح - جونية رقم 1'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pump(const Duration(milliseconds: 20));

      expect(valuation.lastBreakdownSackId, 'SCK-20260901-0001');
      expect(valuation.lastBreakdownStockDate, sackDay);
      expect(find.text('سعر الجونية'), findsOneWidget);
    });

    testWidgets('⛔⛔ ورفضُ القراءة خطأٌ صريح — لا «لا بيانات»',
        (WidgetTester tester) async {
      final CalendarDay sackDay = CalendarDay(2026, 9, 1);
      reports.sackCards = <SackCard>[
        testSack(documentNumber: 'SCK-20260901-0001', stockDate: sackDay),
      ];
      valuation.setBreakdown(
        const Failure<List<SackRevenueContribution>>(PermissionError()),
      );

      await pumpScreen(
        tester,
        const ReportViewScreen(report: ReportId.sackPriceBreakdown),
        actorPermissions: const <Permission>{
          Permission.reportSupplierView,
          Permission.withdrawalView,
          Permission.expenseView,
        },
      );

      await tester.tap(find.text('عبدالفتاح - جونية رقم 1'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pump(const Duration(milliseconds: 20));

      expect(find.text('إعادة المحاولة'), findsOneWidget);
    });
  });
}

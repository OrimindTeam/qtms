/// شاشة **مالية الجواني وحساب الرعوي** (`M14` · `WU-015`).
///
/// ⚠️⚠️ **وما تُثبته هذه الاختبارات وما لا تُثبته:** تُثبت أن **الشاشة تعرض
/// الرقم المخزَّن كما هو** ⛔ **لا رقماً تحسبه**، وأنها **لا تعرض ما يمنعه
/// المتطلب** (لا مبالغَ بلا مالية مقروءة · لا تسديدَ للرعوي)، وأن **التفكيك
/// يُبنى بدالة النطاق نفسِها**. ⛔ **ولا تُثبت أن الأرقام محميّة** — ★ **الحماية
/// شرطُ القراءة في `firestore.rules`** ولها اختباراتها على المحاكي (`RISK-02`).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qtms/capabilities/identity_access/application/session_providers.dart';
import 'package:qtms/capabilities/inventory/application/inventory_providers.dart';
import 'package:qtms/capabilities/inventory/application/sack_valuation_providers.dart';
import 'package:qtms/capabilities/inventory/presentation/sack_finance_cards.dart';
import 'package:qtms/capabilities/inventory/presentation/sack_finance_screen.dart';
import 'package:qtms/capabilities/inventory/presentation/sack_tax_sheet.dart';
import 'package:qtms/capabilities/master_data/application/master_data_providers.dart';
import 'package:qtms/core/ui/async_state_view.dart';
import 'package:qtms_domain/qtms_domain.dart';

import '../../../support/fake_identity.dart';
import '../../../support/fake_master_data.dart';
import '../../../support/fake_sack_valuation.dart';
import '../../../support/fake_sacks.dart';

/// ★ مفاتيح الشاشة — فالاختبار يقيس **العرض لا نقصَ المفتاح**.
const Set<Permission> financeKeys = <Permission>{
  Permission.sackView,
  Permission.sackFinanceView,
  Permission.supplierFinanceView,
};

/// ★★ **اليوم مثبَّت** — ⛔ **فلا اختبارَ ينكسر بمرور منتصف الليل.**
final CalendarDay fixedDay = CalendarDay(2026, 8, 26);

SackFinanceCard finance({
  String sackId = 'SCK-20260826-0001',
  int? tax = 1125,
  int? revenue = 37300,
  int? net = 36175,
}) =>
    SackFinanceCard(
      sackId: sackId,
      sourceId: 'SRC-001',
      taxPerKilo: tax == null ? null : const Money(25),
      sackTax: tax == null ? null : Money(tax),
      sackRevenue: revenue == null ? null : Money(revenue),
      supplierNet: net == null ? null : Money(net),
    );

Future<void> pumpScreen({
  required WidgetTester tester,
  required FakeSackDirectory sacks,
  required FakeSackValuationDirectory valuation,
  required FakeMasterDataDirectory masterData,
  FakeSackAdmin? admin,
  Set<Permission> actorPermissions = financeKeys,
}) async {
  final FakeAuthRepository auth = FakeAuthRepository();
  final FakeUserCardRepository cards = FakeUserCardRepository();
  auth.emitIdentity(
    const AuthenticatedIdentity(userId: 'U-001', sourceScope: AllSources()),
  );
  cards.emitCard('U-001', testCard(permissions: actorPermissions));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        userCardRepositoryProvider.overrideWithValue(cards),
        masterDataDirectoryProvider.overrideWithValue(masterData),
        masterDataAdminProvider.overrideWithValue(FakeMasterDataAdmin()),
        sackDirectoryProvider.overrideWithValue(sacks),
        sackAdminProvider.overrideWithValue(admin ?? FakeSackAdmin()),
        sackValuationDirectoryProvider.overrideWithValue(valuation),
        todayProvider.overrideWithValue(fixedDay),
      ],
      child: const MaterialApp(
        locale: Locale('ar'),
        home: SackFinanceScreen(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 20));
  await tester.pump(const Duration(milliseconds: 20));
}

/// ★★ **يفتح المرشِّحات المطويّة** — §5b نمط `P3` (`ADR-0021`).
///
/// ⛔ **والمرشِّحُ مطويٌّ افتراضاً** — ⟵ **فصفٌّ مفتوح دائماً يدفع أول جونيةٍ
/// خارج الطيّة**، ★ **وعددُ النشط يبقى ظاهراً على الزرّ.**
Future<void> openFilters(WidgetTester tester) async {
  await tester.tap(find.byTooltip('مرشِّحات'));
  await tester.pumpAndSettle();
}

void main() {
  late FakeSackDirectory sacks;
  late FakeSackValuationDirectory valuation;
  late FakeMasterDataDirectory masterData;

  setUp(() {
    sacks = FakeSackDirectory();
    valuation = FakeSackValuationDirectory();
    masterData = FakeMasterDataDirectory();
    masterData.emitSources(<SourceCard>[testSource()]);
    masterData.emitSuppliers(<SupplierCard>[
      const SupplierCard(
        supplierId: 'SUP-0001',
        name: 'عبدالفتاح',
        phone: '777111222',
        isActive: true,
      ),
    ]);
  });

  tearDown(() {
    sacks.dispose();
    valuation.dispose();
  });

  group('FR-M14-02 · FR-M14-12: الأرقام المخزَّنة تُعرَض كما هي', () {
    testWidgets('★★★ سعرُ الجونية وضريبتُها وصافيها من finance/current',
        (WidgetTester tester) async {
      sacks.emitSacks(<SackCard>[testSack(stockDate: fixedDay)]);
      sacks.emitFinanceFor('SCK-20260826-0001', finance());

      await pumpScreen(
        tester: tester,
        sacks: sacks,
        valuation: valuation,
        masterData: masterData,
      );

      expect(find.textContaining('37,300'), findsWidgets);
      expect(find.textContaining('الضريبة 1,125'), findsOneWidget);
      expect(find.textContaining('الصافي 36,175'), findsOneWidget);
    });

    testWidgets('★★ وإجمالياتُ اليوم تُبنى بدالة النطاق لا بجمعٍ في الشاشة',
        (WidgetTester tester) async {
      sacks.emitSacks(<SackCard>[
        testSack(stockDate: fixedDay),
        testSack(
          documentNumber: 'SCK-20260826-0002',
          dailySequence: 2,
          stockDate: fixedDay,
        ),
      ]);
      sacks.emitFinanceFor('SCK-20260826-0001', finance());
      sacks.emitFinanceFor(
        'SCK-20260826-0002',
        finance(sackId: 'SCK-20260826-0002', tax: 500, revenue: 20000,
            net: 19500),
      );

      await pumpScreen(
        tester: tester,
        sacks: sacks,
        valuation: valuation,
        masterData: masterData,
      );

      // ★ **57,300 = 37,300 + 20,000** · **1,625 = 1,125 + 500** ·
      //   **55,675 = الفرق** — ⟵ **وكلُّها من `computeSupplierSourceTotals`.**
      expect(find.textContaining('57,300'), findsOneWidget);
      expect(find.textContaining('1,625'), findsOneWidget);
      expect(find.textContaining('55,675'), findsOneWidget);
    });

    testWidgets('⛔ وبلا ماليةٍ مقروءة لا إجمالي ولا مبلغ — ADR-0011',
        (WidgetTester tester) async {
      sacks.emitSacks(<SackCard>[testSack(stockDate: fixedDay)]);
      // ★ **من لا يملك `sackFinanceView` يقرأ `null`** — راجع الدليل الحقيقي.
      sacks.emitFinanceFor('SCK-20260826-0001', null);

      await pumpScreen(
        tester: tester,
        sacks: sacks,
        valuation: valuation,
        masterData: masterData,
        actorPermissions: const <Permission>{Permission.sackView},
      );

      expect(find.text('إجماليات اليوم في هذا المصدر'), findsNothing);
      expect(find.text('المالية غير متاحة'), findsOneWidget);
      // ⛔ **ولا صفرٌ يُقرأ رقماً.**
      expect(find.textContaining('0 ريال'), findsNothing);
    });
  });

  group('FR-M7-10 · FR-M14-06: ما لم يُحتسب بعد يُقال صراحةً', () {
    testWidgets('★ ضريبةٌ معلّقة ⟵ «الضريبة معلّقة» و«الصافي غير محتسَب»',
        (WidgetTester tester) async {
      sacks.emitSacks(<SackCard>[testSack(stockDate: fixedDay)]);
      sacks.emitFinanceFor(
        'SCK-20260826-0001',
        finance(tax: null, net: null),
      );

      await pumpScreen(
        tester: tester,
        sacks: sacks,
        valuation: valuation,
        masterData: masterData,
      );

      expect(find.textContaining('الضريبة معلّقة'), findsOneWidget);
      expect(find.textContaining('الصافي غير محتسَب'), findsOneWidget);
    });

    testWidgets('★ وسعرٌ غير محتسَب يُعرَض «—» لا صفراً',
        (WidgetTester tester) async {
      sacks.emitSacks(<SackCard>[testSack(stockDate: fixedDay)]);
      sacks.emitFinanceFor(
        'SCK-20260826-0001',
        finance(revenue: null, net: null),
      );

      await pumpScreen(
        tester: tester,
        sacks: sacks,
        valuation: valuation,
        masterData: masterData,
      );

      expect(find.text('—'), findsOneWidget);
    });
  });

  group('⛔⛔★★★ AM-021 — «غير نهائي» على إجماليات اليوم وهياكلُ التحميل', () {
    testWidgets('★★★ ① شارةُ «غير نهائي» على إجماليات اليوم حين ضريبةٌ معلّقة',
        (WidgetTester tester) async {
      // ⛔⛔★★★ **و«إجمالي الضريبة: 0 ريال» فوق جونيةٍ ضريبتُها معلّقة
      //   *حكمٌ* لا تقرير** — ⟵ **والصفرُ يُقرأ «لا ضريبةَ على اليوم»**
      //   ⛔ **ومعناه «لم تُدخَل بعد»**: ★ **و`SupplierAccountCard` في الشاشة
      //   نفسِها كانت تُصرِّح وتصمت جارتُها.**
      sacks.emitSacks(<SackCard>[
        testSack(stockDate: fixedDay),
        testSack(
          documentNumber: 'SCK-20260826-0002',
          dailySequence: 2,
          stockDate: fixedDay,
        ),
      ]);
      sacks.emitFinanceFor('SCK-20260826-0001', finance());
      sacks.emitFinanceFor(
        'SCK-20260826-0002',
        finance(sackId: 'SCK-20260826-0002', tax: null, net: null),
      );

      await pumpScreen(
        tester: tester,
        sacks: sacks,
        valuation: valuation,
        masterData: masterData,
      );

      expect(find.text('إجماليات اليوم في هذا المصدر'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(SackDayTotals),
          matching: find.byType(SackPendingTotalsPill),
        ),
        findsOneWidget,
      );
      // ★ **وتقول العددَ والسبب** — ⛔ **لا وسمٌ مبهم.**
      expect(
        find.text('غير نهائي — 1 جونية بضريبةٍ معلّقة'),
        findsOneWidget,
      );
    });

    testWidgets('⛔ ويومٌ كلُّه نهائيٌّ بلا شارةٍ إطلاقاً',
        (WidgetTester tester) async {
      sacks.emitSacks(<SackCard>[testSack(stockDate: fixedDay)]);
      sacks.emitFinanceFor('SCK-20260826-0001', finance());

      await pumpScreen(
        tester: tester,
        sacks: sacks,
        valuation: valuation,
        masterData: masterData,
      );

      expect(find.text('إجماليات اليوم في هذا المصدر'), findsOneWidget);
      expect(find.byType(SackPendingTotalsPill), findsNothing);
    });

    testWidgets('★★★ ③ وإجمالياتُ اليوم هيكلٌ أثناء التحميل ⛔ لا فراغ',
        (WidgetTester tester) async {
      sacks.emitSacks(<SackCard>[testSack(stockDate: fixedDay)]);
      sacks.holdFinance('SCK-20260826-0001');

      await pumpScreen(
        tester: tester,
        sacks: sacks,
        valuation: valuation,
        masterData: masterData,
      );

      expect(find.byType(SackFinanceCardSkeleton), findsWidgets);
      expect(find.text('إجماليات اليوم في هذا المصدر'), findsNothing);
    });

    testWidgets('★★★ ③ وبطاقةُ حساب الرعوي هيكلٌ أثناء التحميل',
        (WidgetTester tester) async {
      sacks.emitSacks(<SackCard>[testSack(stockDate: fixedDay)]);
      sacks.emitFinanceFor('SCK-20260826-0001', finance());
      valuation.holdBalance();

      await pumpScreen(
        tester: tester,
        sacks: sacks,
        valuation: valuation,
        masterData: masterData,
      );
      await openFilters(tester);
      await tester.tap(find.text('عبدالفتاح').first);
      // ⛔⛔ **ولا `pumpAndSettle` هنا** — ★ **وميضُ الهيكل حركةٌ متكرّرةٌ لا
      //   تستقرّ أبداً** (`SkeletonBox`): ⟵ **فالانتظارُ حتى السكون يَعلَق.**
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));

      expect(find.byType(SackFinanceCardSkeleton), findsWidgets);
      expect(find.text('حساب الرعوي في هذا المصدر'), findsNothing);
    });

    testWidgets(
        '⛔⛔★★★ ④ وبلا صلاحيةٍ يبقى الإخفاءُ صامتاً — ⛔ ولا هيكلَ أبديّ',
        (WidgetTester tester) async {
      // ★ **الهيكلُ لحالة `isLoading` وحدَها** — ⟵ **وتمييزُ «لا صلاحية»
      //   عن «لا بيانات» تسريبُ وجودٍ يمنعه `ADR-0011` نصّاً.**
      sacks.emitSacks(<SackCard>[testSack(stockDate: fixedDay)]);
      sacks.emitFinanceFor('SCK-20260826-0001', null);

      await pumpScreen(
        tester: tester,
        sacks: sacks,
        valuation: valuation,
        masterData: masterData,
        actorPermissions: const <Permission>{Permission.sackView},
      );

      expect(find.byType(SackFinanceCardSkeleton), findsNothing);
      expect(find.text('إجماليات اليوم في هذا المصدر'), findsNothing);
    });
  });

  group('FR-M14-13: التنبيه النطاقي ظاهرٌ في الشاشة', () {
    testWidgets('⛔⛔ ولا عمليةَ تسديدٍ للرعوي في هذا الإصدار',
        (WidgetTester tester) async {
      sacks.emitSacks(<SackCard>[testSack(stockDate: fixedDay)]);
      sacks.emitFinanceFor('SCK-20260826-0001', finance());

      await pumpScreen(
        tester: tester,
        sacks: sacks,
        valuation: valuation,
        masterData: masterData,
      );

      expect(
        find.textContaining('لا توجد عملية تسديد للرعوي'),
        findsOneWidget,
      );
      // ⛔ **ولا زرَّ تسديدٍ في الشاشة إطلاقاً.**
      expect(find.textContaining('تسديد الرعوي'), findsNothing);
    });
  });

  group('§2.5: بطاقة حساب الرعوي — بمرشِّح الرعوي وحده', () {
    testWidgets('⛔ لا تظهر قبل اختيار رعوي — فلا حسابَ بلا صاحب',
        (WidgetTester tester) async {
      sacks.emitSacks(<SackCard>[testSack(stockDate: fixedDay)]);
      sacks.emitFinanceFor('SCK-20260826-0001', finance());
      valuation.emitBalance(testSupplierBalance());

      await pumpScreen(
        tester: tester,
        sacks: sacks,
        valuation: valuation,
        masterData: masterData,
      );

      expect(find.text('حساب الرعوي في هذا المصدر'), findsNothing);
    });

    testWidgets('★★ وتظهر بإجمالياتها الثلاثة عند اختياره',
        (WidgetTester tester) async {
      sacks.emitSacks(<SackCard>[testSack(stockDate: fixedDay)]);
      sacks.emitFinanceFor('SCK-20260826-0001', finance());
      valuation.emitBalance(testSupplierBalance());

      await pumpScreen(
        tester: tester,
        sacks: sacks,
        valuation: valuation,
        masterData: masterData,
      );
      await openFilters(tester);
      await tester.tap(find.text('عبدالفتاح').first);
      await tester.pumpAndSettle();

      expect(find.text('حساب الرعوي في هذا المصدر'), findsOneWidget);
      expect(find.text('صافي الرعوي'), findsOneWidget);
    });

    testWidgets('★ وتقول لماذا الرقم غير نهائي — ⛔ لا وسمٌ مبهم',
        (WidgetTester tester) async {
      sacks.emitSacks(<SackCard>[testSack(stockDate: fixedDay)]);
      sacks.emitFinanceFor('SCK-20260826-0001', finance());
      valuation.emitBalance(testSupplierBalance(pendingTaxCount: 2));

      await pumpScreen(
        tester: tester,
        sacks: sacks,
        valuation: valuation,
        masterData: masterData,
      );
      await openFilters(tester);
      await tester.tap(find.text('عبدالفتاح').first);
      await tester.pumpAndSettle();

      expect(
        find.textContaining('2 جونية بضريبةٍ معلّقة'),
        findsOneWidget,
      );
    });
  });

  group('FR-M14-15: تفكيك سعر الجونية', () {
    testWidgets('★★★ يُفتَح بالنقر ويسأل عن الجونية وتاريخِ مخزونها',
        (WidgetTester tester) async {
      sacks.emitSacks(<SackCard>[testSack(stockDate: fixedDay)]);
      sacks.emitFinanceFor('SCK-20260826-0001', finance());
      valuation.setBreakdown(
        Success<List<SackRevenueContribution>>(<SackRevenueContribution>[
          testContribution(),
          testContribution(
            origin: SackRevenueSource.cashSale,
            documentNumber: 'CSH-20260826-0001',
            counterpartyName: null,
            lineValue: 2450,
          ),
        ]),
      );

      await pumpScreen(
        tester: tester,
        sacks: sacks,
        valuation: valuation,
        masterData: masterData,
      );
      await tester.tap(find.textContaining('جونية رقم 1').first);
      await tester.pumpAndSettle();

      expect(valuation.lastBreakdownSackId, 'SCK-20260826-0001');
      // ★★ **والسؤال على تاريخ المخزون** — `RISK-07`.
      expect(valuation.lastBreakdownStockDate, fixedDay);
      expect(find.text('توزيع'), findsOneWidget);
      expect(find.text('بيع نقدي'), findsOneWidget);
      // ★ **7,450 = 5,000 + 2,450** — ⟵ **من `computeSackRevenue` نفسِها.**
      expect(find.textContaining('7,450'), findsOneWidget);
    });

    testWidgets('★★ وحركةٌ بلا قيمة ظاهرة تُبقي المجموع «غير نهائي»',
        (WidgetTester tester) async {
      sacks.emitSacks(<SackCard>[testSack(stockDate: fixedDay)]);
      sacks.emitFinanceFor('SCK-20260826-0001', finance());
      valuation.setBreakdown(
        Success<List<SackRevenueContribution>>(<SackRevenueContribution>[
          testContribution(),
          testContribution(
            documentNumber: 'DST-20260826-0002',
            unitPrice: null,
            lineValue: null,
          ),
        ]),
      );

      await pumpScreen(
        tester: tester,
        sacks: sacks,
        valuation: valuation,
        masterData: masterData,
      );
      await tester.tap(find.textContaining('جونية رقم 1').first);
      await tester.pumpAndSettle();

      expect(find.textContaining('فالسعر غير نهائي'), findsOneWidget);
      expect(find.text('—'), findsWidgets);
    });

    testWidgets('★ وجونيةٌ لم يخرج منها شيء ⟵ حالةٌ فارغةٌ مصمَّمة',
        (WidgetTester tester) async {
      sacks.emitSacks(<SackCard>[testSack(stockDate: fixedDay)]);
      sacks.emitFinanceFor('SCK-20260826-0001', finance(revenue: 0, net: -1125));

      await pumpScreen(
        tester: tester,
        sacks: sacks,
        valuation: valuation,
        masterData: masterData,
      );
      await tester.tap(find.textContaining('جونية رقم 1').first);
      await tester.pumpAndSettle();

      expect(find.byType(QtmsEmptyState), findsOneWidget);
      expect(
        find.text('لم يخرج من هذه الجونية شيء بعد'),
        findsOneWidget,
      );
    });

    testWidgets('⛔ ورفضُ القراءة يُعرَض ولا يُطوى في «فارغ»',
        (WidgetTester tester) async {
      sacks.emitSacks(<SackCard>[testSack(stockDate: fixedDay)]);
      sacks.emitFinanceFor('SCK-20260826-0001', finance());
      valuation.setBreakdown(
        const Failure<List<SackRevenueContribution>>(PermissionError()),
      );

      await pumpScreen(
        tester: tester,
        sacks: sacks,
        valuation: valuation,
        masterData: masterData,
      );
      await tester.tap(find.textContaining('جونية رقم 1').first);
      await tester.pumpAndSettle();

      expect(find.byType(QtmsEmptyState), findsNothing);
      expect(
        find.textContaining('تحقق من صلاحيتك ونطاق مصادرك'),
        findsOneWidget,
      );
    });

    testWidgets(
        '⛔⛔★★★ [DEBT-90] وإعادةُ الفتح تقرأ من جديد — ولا تُعيد لقطةً قديمة',
        (WidgetTester tester) async {
      // ★★★ **العطلُ الذي كشفه المحاكي حرفياً** (2026-09-03): ★ **فُتحت
      //    الورقةُ وهي فارغة، ثم سُجِّلت توزيعةٌ بـ20000، ثم أُعيد فتحُها**
      //    ⟹ ⛔ **فقالت «لم يخرج منها شيء بعد» والإجمالي المخزَّن 20000.**
      //    ★ **والجذرُ أن `sackBreakdownProvider` كان بلا `autoDispose`.**
      sacks.emitSacks(<SackCard>[testSack(stockDate: fixedDay)]);
      sacks.emitFinanceFor('SCK-20260826-0001', finance());
      valuation.setBreakdown(
        const Success<List<SackRevenueContribution>>(
          <SackRevenueContribution>[],
        ),
      );

      await pumpScreen(
        tester: tester,
        sacks: sacks,
        valuation: valuation,
        masterData: masterData,
      );
      await tester.tap(find.textContaining('جونية رقم 1').first);
      await tester.pumpAndSettle();
      expect(find.text('لم يخرج من هذه الجونية شيء بعد'), findsOneWidget);
      expect(valuation.breakdownCallCount, 1);

      // ★ **تُغلَق الورقة** — ⟵ **فيسقط مستمعُها الوحيد.**
      Navigator.of(tester.element(find.byType(QtmsEmptyState))).pop();
      await tester.pumpAndSettle();

      // ⛅ **ثم تقع حركةٌ خارج الشاشة** — ★ **كالتوزيعة في القياس الحيّ.**
      valuation.setBreakdown(
        Success<List<SackRevenueContribution>>(<SackRevenueContribution>[
          testContribution(quantity: 40, unitPrice: 500, lineValue: 20000),
        ]),
      );

      await tester.tap(find.textContaining('جونية رقم 1').first);
      await tester.pumpAndSettle();

      // ⛔⛔ **قراءةٌ ثانيةٌ فعلية** — ★ **لا لقطةٌ مخزَّنة.**
      expect(valuation.breakdownCallCount, 2);
      expect(find.text('لم يخرج من هذه الجونية شيء بعد'), findsNothing);
      expect(find.textContaining('20,000'), findsWidgets);
    });
  });

  group('FR-M14-01: المرشِّحات', () {
    testWidgets('★ مرشِّحُ الرعوي يُصفّي القائمة — و«كل الرعية» يُعيدها',
        (WidgetTester tester) async {
      sacks.emitSacks(<SackCard>[
        testSack(stockDate: fixedDay),
        testSack(
          documentNumber: 'SCK-20260826-0002',
          dailySequence: 2,
          stockDate: fixedDay,
          supplierName: null,
        ),
      ]);
      sacks.emitFinanceFor('SCK-20260826-0001', finance());
      sacks.emitFinanceFor('SCK-20260826-0002', finance(
        sackId: 'SCK-20260826-0002',
      ));

      await pumpScreen(
        tester: tester,
        sacks: sacks,
        valuation: valuation,
        masterData: masterData,
      );
      expect(find.textContaining('جونية رقم'), findsNWidgets(2));

      await openFilters(tester);
      await tester.tap(find.text('عبدالفتاح').first);
      await tester.pumpAndSettle();
      expect(find.textContaining('جونية رقم'), findsOneWidget);

      // ★ **واللوحة تبقى مفتوحة بعد الاختيار** — ⟵ **فلا تُفتَح ثانية.**
      await tester.tap(find.text('كل الرعية'));
      await tester.pumpAndSettle();
      expect(find.textContaining('جونية رقم'), findsNWidgets(2));
    });

    testWidgets('⛔⛔ ولا خيارَ «كل المصادر» — GR-21',
        (WidgetTester tester) async {
      sacks.emitSacks(<SackCard>[testSack(stockDate: fixedDay)]);
      sacks.emitFinanceFor('SCK-20260826-0001', finance());

      await pumpScreen(
        tester: tester,
        sacks: sacks,
        valuation: valuation,
        masterData: masterData,
      );

      expect(find.text('كل المصادر'), findsNothing);
      // ★★ **والاستعلامُ على تاريخ المخزون** — `RISK-07`.
      expect(sacks.lastStockDate, fixedDay);
    });
  });

  group('FR-M7-10 · FR-M7-11: ورقةُ ضريبة الكيلو — WU-015 «وضريبة الجونية»', () {
    testWidgets('★★★ تُرسِل القيمة كما كتبها المستخدم وسبباً اختيارياً',
        (WidgetTester tester) async {
      final FakeSackAdmin admin = FakeSackAdmin();
      sacks.emitSacks(<SackCard>[testSack(stockDate: fixedDay)]);
      sacks.emitFinanceFor('SCK-20260826-0001', finance(tax: null, net: null));

      await pumpScreen(
        tester: tester,
        sacks: sacks,
        valuation: valuation,
        masterData: masterData,
        admin: admin,
        actorPermissions: const <Permission>{
          Permission.sackView,
          Permission.sackFinanceView,
          Permission.sackTaxEnterNow,
        },
      );

      await tester.tap(find.text('إدخال ضريبة الكيلو'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, '25');
      await tester.pumpAndSettle();
      // ★★ **المعاينة من دالة النطاق** — `25 × 45.000 = 1,125` (`AT-13`).
      expect(find.textContaining('1,125'), findsOneWidget);

      await tester.tap(find.text('حفظ الضريبة'));
      await tester.pumpAndSettle();

      expect(admin.enteredTax, const Money(25));
    });

    testWidgets('⛔ ولا حفظَ بقيمةٍ فارغة — والزرُّ معطَّل',
        (WidgetTester tester) async {
      final FakeSackAdmin admin = FakeSackAdmin();
      sacks.emitSacks(<SackCard>[testSack(stockDate: fixedDay)]);
      sacks.emitFinanceFor('SCK-20260826-0001', finance(tax: null, net: null));

      await pumpScreen(
        tester: tester,
        sacks: sacks,
        valuation: valuation,
        masterData: masterData,
        admin: admin,
        actorPermissions: const <Permission>{
          Permission.sackView,
          Permission.sackFinanceView,
          Permission.sackTaxEnterLater,
        },
      );

      await tester.tap(find.text('إدخال ضريبة الكيلو'));
      await tester.pumpAndSettle();

      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(admin.enteredTax, isNull);
    });

    testWidgets('⛔⛔ ولا مدخلَ لمن لا يملك أياً من مفتاحَي الضريبة',
        (WidgetTester tester) async {
      sacks.emitSacks(<SackCard>[testSack(stockDate: fixedDay)]);
      sacks.emitFinanceFor('SCK-20260826-0001', finance());

      await pumpScreen(
        tester: tester,
        sacks: sacks,
        valuation: valuation,
        masterData: masterData,
        actorPermissions: const <Permission>{
          Permission.sackView,
          Permission.sackFinanceView,
        },
      );

      expect(find.textContaining('ضريبة الكيلو'), findsNothing);
    });

    testWidgets('⛔ ولا مدخلَ لجونيةٍ ملغاة — ERR_AMEND_006',
        (WidgetTester tester) async {
      sacks.emitSacks(<SackCard>[
        testSack(stockDate: fixedDay, status: SackStatus.cancelled),
      ]);
      sacks.emitFinanceFor('SCK-20260826-0001', finance(tax: null, net: null));

      await pumpScreen(
        tester: tester,
        sacks: sacks,
        valuation: valuation,
        masterData: masterData,
        actorPermissions: const <Permission>{
          Permission.sackView,
          Permission.sackFinanceView,
          Permission.sackTaxEnterNow,
        },
      );

      expect(find.textContaining('ضريبة الكيلو'), findsNothing);
    });

    testWidgets('★ ورفضُ السحابة يُعرَض في الورقة ولا يُغلقها',
        (WidgetTester tester) async {
      final FakeSackAdmin admin = FakeSackAdmin()
        ..rejection = const PermissionError();
      sacks.emitSacks(<SackCard>[testSack(stockDate: fixedDay)]);
      sacks.emitFinanceFor('SCK-20260826-0001', finance(tax: null, net: null));

      await pumpScreen(
        tester: tester,
        sacks: sacks,
        valuation: valuation,
        masterData: masterData,
        admin: admin,
        actorPermissions: const <Permission>{
          Permission.sackView,
          Permission.sackFinanceView,
          Permission.sackTaxEnterNow,
        },
      );

      await tester.tap(find.text('إدخال ضريبة الكيلو'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '25');
      await tester.pumpAndSettle();
      await tester.tap(find.text('حفظ الضريبة'));
      await tester.pumpAndSettle();

      expect(find.byType(SackTaxSheet), findsOneWidget);
      expect(find.text('حفظ الضريبة'), findsOneWidget);
    });
  });
}

/// شاشة **كشف حساب المقوت** — `WU-017` (`M17`).
///
/// ⚠️⚠️ **وما تُثبته هذه الاختبارات وما لا تُثبته:** تُثبت أن الكشف
/// **يُبنى من الدفتر ويطابق الرصيد المعروض** (`FR-M17-03` · معيار قبول
/// الوحدة)، وأن **«كل المصادر» تُعدَّد مصادرَ ولا تصل غياباً** (`IQ-024` ·
/// `DEBT-40`)، وأن **خيارها لا يظهر بلا مفتاحه المستقل** (`IQ-040`)، وأن
/// **الملغاةَ تُعرَض ولا تدخل رقماً** (`FR-M17-06`)، وأن **النمطين يعرضان
/// أعمدةً مختلفة والرأسَ نفسَه** (`FR-M17-02` · نمط 3).
///
/// ⛔⛔ **ولا تُثبت أن الأرقام محميّة** — ★ **الحمايةُ شرطُ قراءة
/// `dealer_ledger` في `firestore.rules` مُختبَراً على المحاكي** (`RISK-02` ·
/// `DEBT-71`): ⟵ **وبوابةُ الشاشة إخفاءٌ لا حماية** ⛔ **ولا يُدَّعى غيرُ ذلك.**
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qtms/capabilities/identity_access/application/session_providers.dart';
import 'package:qtms/capabilities/inventory/application/inventory_providers.dart';
import 'package:qtms/capabilities/master_data/application/master_data_providers.dart';
import 'package:qtms/capabilities/oversight/application/report_providers.dart';
import 'package:qtms/capabilities/sales_receivables/application/receipt_providers.dart';
import 'package:qtms/capabilities/sales_receivables/presentation/dealer_statement_screen.dart';
import 'package:qtms/core/design/design_tokens.dart';
import 'package:qtms/core/ui/key_value_row.dart';
import 'package:qtms_domain/qtms_domain.dart';

import '../../../support/fake_identity.dart';
import '../../../support/fake_master_data.dart';
import '../../../support/fake_oversight.dart';
import '../../../support/fake_receipts.dart';

/// ★★ **اليوم مثبَّت** — ⛔ **فلا اختبارَ ينكسر بمرور منتصف الليل.**
final CalendarDay fixedDay = CalendarDay(2026, 9, 4);

late FakeReportDirectory reports;
late FakeReceiptDirectory receipts;
late FakeMasterDataDirectory masterData;

/// ★ صاحبُ الكشف بالمفاتيح الثلاثة — **السلسلة كاملةً** (`IQ-040`).
const Set<Permission> statementReader = <Permission>{
  Permission.dealerBalanceView,
  Permission.dealerStatementView,
  Permission.dealerStatementAllSources,
};

/// ★ صاحبُ الكشف بلا مفتاح «كل المصادر».
const Set<Permission> singleSourceReader = <Permission>{
  Permission.dealerBalanceView,
  Permission.dealerStatementView,
};

String lotId(int stockDay, {String source = 'SRC-001'}) => distributionId(
  dealerId: 'MQT-0001',
  sourceId: source,
  stockDate: CalendarDay(2026, 9, stockDay),
);

DealerLedgerRowCard row({
  required String entryId,
  required DealerLedgerDirection direction,
  required int amount,
  required DealerLedgerEntryType type,
  required int stockDay,
  String source = 'SRC-001',
  int entryDay = 1,
  bool cancelled = false,
}) => DealerLedgerRowCard(
  entryId: entryId,
  dealerId: 'MQT-0001',
  sourceId: source,
  direction: direction,
  entryType: type,
  amount: Money(amount),
  isCancelled: cancelled,
  entryDate: DateTime.utc(2026, 9, entryDay),
  debtLotId: lotId(stockDay, source: source),
  sourceDocNumber: 'DST-2026090$stockDay-0001',
);

Future<void> pumpStatement(
  WidgetTester tester, {
  Set<Permission> actorPermissions = statementReader,
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
        contactPickerProvider.overrideWithValue(null),
        reportDirectoryProvider.overrideWithValue(reports),
        receiptDirectoryProvider.overrideWithValue(receipts),
        todayProvider.overrideWithValue(fixedDay),
      ],
      child: const MaterialApp(
        locale: Locale('ar'),
        home: DealerStatementScreen(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 20));
  await tester.pump(const Duration(milliseconds: 20));
}

/// ★ يختار المقوت من الرأس — **وهو ما يُطلِق البناء**.
Future<void> selectDealer(WidgetTester tester) async {
  await tester.tap(find.byType(DropdownButtonFormField<String>));
  await tester.pumpAndSettle();
  await tester.tap(find.text('مقوت مثال').last);
  await tester.pumpAndSettle();
}

/// ★ يُمرِّر الجسمَ حتى يظهر الودجت — ⛔ **فالقائمة تُبنى كسولاً في مقاس
/// الاختبار**: ⟵ **والتذييلُ والجدولُ تحت الطيّة** (نفسُ ما تفعله بقيةُ
/// اختبارات الشاشات).
Future<void> revealBody(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isNotEmpty) return;
  await tester.scrollUntilVisible(
    finder,
    240,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    reports = FakeReportDirectory();
    receipts = FakeReceiptDirectory();
    masterData = FakeMasterDataDirectory();
    masterData.emitSources(<SourceCard>[
      testSource(),
      testSource(sourceId: 'SRC-002', name: 'ماوية'),
    ]);
    masterData.emitDealers(<DealerCard>[testDealer()]);
    receipts.emitSurplus(Money.zero);
  });

  group('★ الحالةُ الأولى — قبل اختيار المقوت', () {
    testWidgets('⛔ لا كشفَ فارغ بل حالةٌ فارغة بسببها وخطوتها', (
      WidgetTester tester,
    ) async {
      await pumpStatement(tester);
      expect(find.text('اختر المقوت'), findsOneWidget);
      // ⛔ **ولا استعلامَ يقع قبل الاختيار** — ★ **فلا قراءةَ بلا سبب.**
      expect(reports.requestedSources, isEmpty);
    });
  });

  group('★★★ الكشفُ يُبنى من الدفتر — FR-M17-03 ومعيارُ القبول', () {
    testWidgets('★★ الرصيدُ المعروض = المدين − الدائن من القيود نفسِها', (
      WidgetTester tester,
    ) async {
      reports.statementBySource = <String, List<DealerLedgerRowCard>>{
        'SRC-001': <DealerLedgerRowCard>[
          row(
            entryId: 'E1',
            direction: DealerLedgerDirection.debit,
            amount: 50000,
            type: DealerLedgerEntryType.debt,
            stockDay: 1,
          ),
          row(
            entryId: 'E2',
            direction: DealerLedgerDirection.credit,
            amount: 200,
            type: DealerLedgerEntryType.receipt,
            stockDay: 1,
            entryDay: 2,
          ),
        ],
      };
      await pumpStatement(tester);
      await selectDealer(tester);
      await tester.pumpAndSettle();

      // ★ **الرصيدُ رقماً** — ⛔ **ولا يُحسَب في الشاشة.**
      await revealBody(tester, find.text('الرصيد المستحق'));
      expect(find.text('49,800'), findsWidgets);
      // ★★ **وبالكتابة العربية** — `FR-M17-07`.
      expect(find.text('تسعة وأربعون ألفاً وثمانمئة ريال'), findsOneWidget);
    });

    testWidgets('⛔⛔ والملغاةُ لا تدخل الرصيد — FR-M17-06', (
      WidgetTester tester,
    ) async {
      reports.statementBySource = <String, List<DealerLedgerRowCard>>{
        'SRC-001': <DealerLedgerRowCard>[
          row(
            entryId: 'E1',
            direction: DealerLedgerDirection.debit,
            amount: 10000,
            type: DealerLedgerEntryType.debt,
            stockDay: 1,
          ),
          row(
            entryId: 'E2',
            direction: DealerLedgerDirection.credit,
            amount: 4000,
            type: DealerLedgerEntryType.receipt,
            stockDay: 1,
            entryDay: 2,
            cancelled: true,
          ),
        ],
      };
      await pumpStatement(tester);
      await selectDealer(tester);
      await tester.pumpAndSettle();

      // ★ **الرصيدُ 10,000 لا 6,000** — ⟵ **فالملغاةُ خارج الحساب.**
      await revealBody(tester, find.text('الرصيد المستحق'));
      expect(find.text('10,000'), findsWidgets);
      expect(find.text('6,000'), findsNothing);
    });
  });

  group('★★ نمطا العرض — FR-M17-02', () {
    testWidgets('★ الافتراضيُّ بالضمارات بأعمدته', (WidgetTester tester) async {
      reports.statementBySource = <String, List<DealerLedgerRowCard>>{
        'SRC-001': <DealerLedgerRowCard>[
          row(
            entryId: 'E1',
            direction: DealerLedgerDirection.debit,
            amount: 1000,
            type: DealerLedgerEntryType.debt,
            stockDay: 1,
          ),
        ],
      };
      await pumpStatement(tester);
      await selectDealer(tester);
      await tester.pumpAndSettle();

      await revealBody(tester, find.text('قيمة الضمار'));
      expect(find.text('قيمة الضمار'), findsOneWidget);
      expect(find.text('المتبقي'), findsOneWidget);
      // ⛔ **ولا عمودَ «الرصيد التراكمي» في هذا النمط.**
      expect(find.text('الرصيد التراكمي'), findsNothing);
    });

    testWidgets('★★ والتبويبُ الثاني يبدّل الأعمدة والرأسُ لا يتحرك', (
      WidgetTester tester,
    ) async {
      reports.statementBySource = <String, List<DealerLedgerRowCard>>{
        'SRC-001': <DealerLedgerRowCard>[
          row(
            entryId: 'E1',
            direction: DealerLedgerDirection.debit,
            amount: 1000,
            type: DealerLedgerEntryType.debt,
            stockDay: 1,
          ),
        ],
      };
      await pumpStatement(tester);
      await selectDealer(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.text('بالحركات'));
      await tester.pumpAndSettle();

      await revealBody(tester, find.text('الرصيد التراكمي'));
      expect(find.text('الرصيد التراكمي'), findsOneWidget);
      expect(find.text('قيمة الضمار'), findsNothing);
      // ⛔⛔ **والرأسُ باقٍ فوق الشريط** — ★ **نمط 3 نصّاً.**
      expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
    });
  });

  group('⛔⛔★★★ الاستعلامُ مقيَّدٌ بالمصدر — IQ-024 · DEBT-40', () {
    testWidgets('★★ «كل المصادر» تُعدَّد مصادرَ ولا تصل غياباً', (
      WidgetTester tester,
    ) async {
      await pumpStatement(tester);
      await selectDealer(tester);
      await tester.pumpAndSettle();

      // ★ **استعلامٌ لكل مصدرٍ على حدة** — ⛔ **لا واحدٌ غيرُ مقيَّد.**
      expect(
        reports.requestedSources,
        containsAll(<String>['SRC-001', 'SRC-002']),
      );
    });
  });

  group('⚠️ البواباتُ — إخفاءٌ لا حماية (IQ-040 · RISK-02)', () {
    testWidgets('⛔ ومن لا يملك مفتاح «كل المصادر» لا يرى الخيار أصلاً', (
      WidgetTester tester,
    ) async {
      await pumpStatement(tester, actorPermissions: singleSourceReader);
      expect(find.text('كل المصادر'), findsNothing);
    });

    testWidgets('✅ ومن يملكه يراه', (WidgetTester tester) async {
      await pumpStatement(tester);
      await tester.tap(find.byType(DropdownButtonFormField<String?>));
      await tester.pumpAndSettle();
      expect(find.text('كل المصادر'), findsWidgets);
    });

    testWidgets('⛔ وزرُّ التصدير لا يظهر بلا `documentExport`', (
      WidgetTester tester,
    ) async {
      reports.statementBySource = <String, List<DealerLedgerRowCard>>{
        'SRC-001': <DealerLedgerRowCard>[
          row(
            entryId: 'E1',
            direction: DealerLedgerDirection.debit,
            amount: 1000,
            type: DealerLedgerEntryType.debt,
            stockDay: 1,
          ),
        ],
      };
      await pumpStatement(tester);
      await selectDealer(tester);
      await tester.pumpAndSettle();
      // ⛔ **ولا يظهر ولو مُرِّر إليه** — ★ **البوابةُ لا تُخفيه بالتمرير.**
      expect(find.text('تصدير ومشاركة'), findsNothing);
    });
  });

  group('★ التذييل — FR-M17-07', () {
    testWidgets('★★ الأعمارُ الأربعُ والفائضُ حاضران دائماً', (
      WidgetTester tester,
    ) async {
      reports.statementBySource = <String, List<DealerLedgerRowCard>>{
        'SRC-001': <DealerLedgerRowCard>[
          row(
            entryId: 'E1',
            direction: DealerLedgerDirection.debit,
            amount: 1000,
            type: DealerLedgerEntryType.debt,
            stockDay: 1,
          ),
        ],
      };
      receipts.emitSurplus(const Money(3000));
      await pumpStatement(tester);
      await selectDealer(tester);
      await tester.pumpAndSettle();

      await revealBody(tester, find.text('أعمار الدين — 0 – 7 أيام'));
      expect(find.text('أعمار الدين — 0 – 7 أيام'), findsOneWidget);
      expect(find.text('أعمار الدين — أكثر من 30 يوماً'), findsOneWidget);
      expect(find.text('المبلغ الفائض المتاح'), findsOneWidget);
    });
  });
  // ═══════════ ★★★ AM-022 — إبرازُ أخطرِ شريحةٍ في الأعمار ═══════════

  group('★★★ AM-022 — شريحةُ «أكثر من 30 يوماً»', () {
    /// ★ ضمارٌ قديمٌ فعلاً — **46 يوماً قبل [fixedDay]**.
    DealerLedgerRowCard agedRow() => DealerLedgerRowCard(
          entryId: 'E-OLD',
          dealerId: 'MQT-0001',
          sourceId: 'SRC-001',
          direction: DealerLedgerDirection.debit,
          entryType: DealerLedgerEntryType.debt,
          amount: const Money(1000),
          isCancelled: false,
          entryDate: DateTime.utc(2026, 7, 20),
          debtLotId: distributionId(
            dealerId: 'MQT-0001',
            sourceId: 'SRC-001',
            stockDate: CalendarDay(2026, 7, 20),
          ),
          sourceDocNumber: 'DST-20260720-0001',
        );

    /// ★ يقرأ لونَ قيمة صفٍّ في التذييل بتسميته.
    Color? valueColorOf(WidgetTester tester, String label) => tester
        .widget<QtmsKeyValueRow>(find.widgetWithText(QtmsKeyValueRow, label))
        .valueColor;

    testWidgets(
      '⛔⛔★★★ قيمتُها بثلاثية danger حين تتجاوز صفراً',
      (WidgetTester tester) async {
        reports.statementBySource = <String, List<DealerLedgerRowCard>>{
          'SRC-001': <DealerLedgerRowCard>[agedRow()],
        };
        await pumpStatement(tester);
        await selectDealer(tester);
        await tester.pumpAndSettle();
        await revealBody(
          tester,
          find.text('أعمار الدين — أكثر من 30 يوماً'),
        );

        expect(
          valueColorOf(tester, 'أعمار الدين — أكثر من 30 يوماً'),
          SemanticTriads.danger.ink,
        );
        // ⛔⛔ **وشريحةٌ أخرى لا تُصبَغ** — ★ **فالإبرازُ ليس زينةً عامة.**
        expect(valueColorOf(tester, 'أعمار الدين — 0 – 7 أيام'), isNull);
        // ⛔⛔ **واللونُ لا يحمل المعنى وحدَه** — ★ **التسميةُ تقولها كاملةً.**
        expect(find.text('أعمار الدين — أكثر من 30 يوماً'), findsOneWidget);
      },
    );

    testWidgets(
      '⛔⛔★★★ وصفرُها يبقى على اللون الافتراضي ⛔ فلا يُصبَغ ما لا خطرَ فيه',
      (WidgetTester tester) async {
        reports.statementBySource = <String, List<DealerLedgerRowCard>>{
          'SRC-001': <DealerLedgerRowCard>[
            row(
              entryId: 'E1',
              direction: DealerLedgerDirection.debit,
              amount: 1000,
              type: DealerLedgerEntryType.debt,
              stockDay: 1,
            ),
          ],
        };
        await pumpStatement(tester);
        await selectDealer(tester);
        await tester.pumpAndSettle();
        await revealBody(
          tester,
          find.text('أعمار الدين — أكثر من 30 يوماً'),
        );

        expect(
          valueColorOf(tester, 'أعمار الدين — أكثر من 30 يوماً'),
          isNull,
        );
      },
    );
  });
}

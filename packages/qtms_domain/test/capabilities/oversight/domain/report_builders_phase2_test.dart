/// بناةُ تقارير المرحلة الثانية — `WU-018` (`M19`).
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⚠️⚠️ **وما تُثبته هذه الاختبارات وما لا تُثبته:** تُثبت أن **القيمة تُقرأ
/// كما كُتبت ولا تُشتقّ** (`ADR-0019`)، وأن **البند المحكوم يختفي كلياً**
/// (`E-29`)، وأن **المبلغ يُنسَب لمصدره وحدَه** (`FR-M19-02`)، وأن **الملغى
/// يُعرَض ولا يُحتسَب** (`A-14`)، وأن **الضريبة المعلّقة لا تُقرأ صفراً**
/// (`FR-M7-10`).
///
/// ⛔⛔ **ولا تُثبت أن الاستعلام مسموحٌ به** — ★ **ذاك في `firestore.rules`
/// ومُختبَرٌ على المحاكي** (`RISK-02`)، ⛔ **ولا يُغني أحدهما عن الآخر.**
/// ═══════════════════════════════════════════════════════════════════════
library;

import 'package:qtms_domain/qtms_domain.dart';
import 'package:test/test.dart';

final CalendarDay dayA = CalendarDay(2026, 9, 1);
final CalendarDay dayB = CalendarDay(2026, 9, 2);
final ReportPeriod span = ReportPeriod.of(from: dayA, to: dayB)!;

// ═════════════════════════════════════════════════════════════════════════
// تجهيزات
// ═════════════════════════════════════════════════════════════════════════

DistributionCard dist({
  required String id,
  required String dealerId,
  required String dealerName,
  int pieces = 10,
  double weight = 0,
  DistributionStatus status = DistributionStatus.priced,
  int unpriced = 0,
  List<ValidatedDistributionLine> lines = const <ValidatedDistributionLine>[],
}) =>
    DistributionCard(
      distributionId: id,
      documentNumber: 'DST-$id',
      sourceId: 'SRC-001',
      dealerId: dealerId,
      dealerName: dealerName,
      stockDate: dayA,
      entryDate: DateTime.utc(2026, 9, 1, 7),
      status: status,
      unpricedLineCount: unpriced,
      totalPieces: PieceCount(pieces),
      totalWeight: WeightKg(weight),
      lines: lines,
    );

CashSaleCard sale({
  String documentNumber = 'CSH-1',
  int pieces = 5,
  double weight = 0,
  int net = 500,
  CashSaleStatus status = CashSaleStatus.approved,
  List<ValidatedCashSaleLine> lines = const <ValidatedCashSaleLine>[],
  List<Money?> lineTotals = const <Money?>[],
}) =>
    CashSaleCard(
      documentNumber: documentNumber,
      sourceId: 'SRC-001',
      stockDate: dayA,
      entryDate: DateTime.utc(2026, 9, 1, 8),
      status: status,
      totalPieces: PieceCount(pieces),
      totalWeight: WeightKg(weight),
      netCashReceived: Money(net),
      lines: lines,
      lineTotals: lineTotals,
    );

DiscountCard discount({
  required List<DiscountCardLine> lines,
  bool isCancelled = false,
}) =>
    DiscountCard(
      documentNumber: 'DSC-1',
      date: dayA,
      dealerId: 'DLR-1',
      dealerName: 'مقوت',
      totalDebtAtEntry: const Money(10000),
      isCancelled: isCancelled,
      lines: lines,
      affectedSourceIds: <String>[
        for (final DiscountCardLine line in lines) line.sourceId,
      ],
    );

DiscountCardLine discountLine(String sourceId, int amount) => DiscountCardLine(
      debtLotId: 'DLR-1_${sourceId}_20260901',
      sourceId: sourceId,
      remainingBefore: const Money(9000),
      amount: Money(amount),
      remainingAfter: Money(9000 - amount),
    );

OutflowCard outflow({
  required OutflowLedgerType ledgerType,
  required OutflowCategory category,
  String documentNumber = 'WDR-1',
  int qat = 0,
  int cash = 0,
  int unpriced = 0,
  bool isCancelled = false,
  List<OutflowCardQatLine> qatLines = const <OutflowCardQatLine>[],
  List<OutflowCardCashLine> cashLines = const <OutflowCardCashLine>[],
}) =>
    OutflowCard(
      documentNumber: documentNumber,
      ledgerType: ledgerType,
      category: category,
      date: dayA,
      stockDate: dayA,
      sourceId: 'SRC-001',
      totalQatValue: Money(qat),
      totalCashValue: Money(cash),
      grandTotal: Money(qat + cash),
      unpricedItemCount: unpriced,
      isCancelled: isCancelled,
      qatLines: qatLines,
      cashLines: cashLines,
    );

OwnerLedgerSummary summary({
  required CalendarDay date,
  String sourceId = 'SRC-001',
  int credit = 0,
  int cash = 0,
  int settled = 0,
  int discounts = 0,
  int tax = 0,
  int withdrawals = 0,
  int expenses = 0,
  DateTime? retro,
}) =>
    computeOwnerLedgerSummary(
      sourceId: sourceId,
      date: date,
      contributions: OwnerLedgerContributions(
        credit: Money(credit),
        cash: Money(cash),
        settledOfDay: Money(settled),
        discounts: Money(discounts),
        tax: Money(tax),
        withdrawals: Money(withdrawals),
        expenses: Money(expenses),
      ),
      retroUpdatedAt: retro,
    );

SupplierLedgerRow supplierRow({
  required String sackId,
  required String supplierId,
  int revenue = 1000,
  int? tax = 100,
  int? net = 900,
  bool isRevenueFinal = true,
  bool isCancelled = false,
}) =>
    SupplierLedgerRow(
      sackId: sackId,
      supplierId: supplierId,
      sourceId: 'SRC-001',
      sackRevenue: Money(revenue),
      recalcVersion: 1,
      supplierName: 'رعوي $supplierId',
      sackDisplayName: 'جونية $sackId',
      sackTax: tax == null ? null : Money(tax),
      supplierNet: net == null ? null : Money(net),
      isRevenueFinal: isRevenueFinal,
      isCancelled: isCancelled,
    );

SackRevenueContribution contribution({
  required SackRevenueSource origin,
  int? lineValue = 300,
  bool isCancelled = false,
  bool isExcluded = false,
}) =>
    SackRevenueContribution(
      itemKey: 'ITM-1',
      itemName: 'صنف',
      origin: origin,
      documentNumber: 'DOC-1',
      quantity: const PieceQuantity(PieceCount(10)),
      unitPrice: const Money(30),
      lineValue: lineValue == null ? null : Money(lineValue),
      counterpartyName: 'جهة',
      isCancelled: isCancelled,
      isExcluded: isExcluded,
    );

CashMovementProjection movementOf({
  int sameDay = 0,
  int previous = 0,
  int surplus = 0,
  int cashSales = 0,
  int withdrawals = 0,
  int expenses = 0,
  int discounts = 0,
  int deposited = 0,
  OwnerLedgerVisibility visibility = OwnerLedgerVisibility.full,
}) =>
    projectCashMovement(
      computeCashMovement(
        date: dayA,
        contributions: CashMovementContributions(
          receivedForSameDayDebt: Money(sameDay),
          receivedForPreviousDays: Money(previous),
          receivedAsSurplus: Money(surplus),
          cashSales: Money(cashSales),
          withdrawals: Money(withdrawals),
          expenses: Money(expenses),
          discounts: Money(discounts),
          deposited: Money(deposited),
        ),
      ),
      visibility,
    );

CountedIntakeCard intake({
  required String documentNumber,
  String? supplierId,
  int quantity = 10,
  List<ValidatedCountedIntakeLine> lines =
      const <ValidatedCountedIntakeLine>[],
}) =>
    CountedIntakeCard(
      documentNumber: documentNumber,
      sourceId: 'SRC-001',
      stockDate: dayA,
      entryDate: DateTime.utc(2026, 9, 1, 6),
      status: CountedIntakeStatus.approved,
      totalQuantity: PieceCount(quantity),
      lines: lines,
      supplierId: supplierId,
    );

SackCard sackOf({required String documentNumber, required int sequence}) {
  const ValidatedSackWeights weights = ValidatedSackWeights(
    totalWeight: WeightKg(45),
    iceWeight: WeightKg(6.5),
    scrapWeight: WeightKg(1.2),
  );
  return SackCard(
    documentNumber: documentNumber,
    sourceId: 'SRC-001',
    stockDate: dayA,
    entryDate: DateTime.utc(2026, 9, 1, 6),
    dailySequence: sequence,
    displayName: sackDisplayName(dailySequence: sequence),
    status: SackStatus.approved,
    weights: weights,
    explanation: explainSackWeight(
      weights: weights,
      lines: const <ValidatedSackLine>[],
      lostWeightConfirmed: false,
    ),
    lostWeightConfirmed: false,
    lines: const <ValidatedSackLine>[],
  );
}

ItemDailyBalanceCard balanceOf({
  required String itemKey,
  required String name,
  required int pieces,
}) =>
    ItemDailyBalanceCard(
      sourceId: 'SRC-001',
      itemKey: itemKey,
      itemName: name,
      stockDate: dayA,
      incoming: PieceQuantity(PieceCount(pieces)),
      outgoing: const PieceQuantity(PieceCount.zero),
      balance: PieceQuantity(PieceCount(pieces)),
    );

String cellOf(ReportTable table, int row, int column) =>
    table.rows[row].cells[column];

String? totalOf(ReportTable table, String label) {
  for (final ExportField field in table.totals) {
    if (field.label == label) return field.value;
  }
  return null;
}

String? headerOf(ReportTable table, String label) {
  for (final ExportField field in table.header) {
    if (field.label == label) return field.value;
  }
  return null;
}

void main() {
  // ═══════════════════════════════════════════════════════════════════════
  group('★★ R-09 — ملخص التوزيع لكل مقوت', () {
    test('★ صفٌّ واحد لكل مقوت مهما تعددت مستنداته', () {
      final ReportTable table = buildDealerDistributionSummaryReport(
        period: span,
        distributions: <DistributionCard>[
          dist(id: '1', dealerId: 'D1', dealerName: 'أحمد', pieces: 10),
          dist(id: '2', dealerId: 'D1', dealerName: 'أحمد', pieces: 15),
          dist(id: '3', dealerId: 'D2', dealerName: 'بدر', pieces: 7),
        ],
      );
      expect(table.rows, hasLength(2));
      // ★ **مرتَّبٌ بالاسم** — ⟵ **فترتيبُ التقرير ثابت.**
      expect(cellOf(table, 0, 0), 'أحمد');
      expect(cellOf(table, 0, 1), '2');
      expect(cellOf(table, 0, 2), '25 حبة');
      expect(totalOf(table, 'عدد المقاوته'), '2');
    });

    test('⛔⛔ والملغاةُ مستبعَدةٌ من الجمع — وعددُها معلَنٌ في الترويسة', () {
      final ReportTable table = buildDealerDistributionSummaryReport(
        period: span,
        distributions: <DistributionCard>[
          dist(id: '1', dealerId: 'D1', dealerName: 'أحمد', pieces: 10),
          dist(
            id: '2',
            dealerId: 'D1',
            dealerName: 'أحمد',
            pieces: 99,
            status: DistributionStatus.cancelled,
          ),
        ],
      );
      expect(cellOf(table, 0, 2), '10 حبة');
      expect(headerOf(table, 'مستندات ملغاة مستبعَدة'), '1');
    });

    test('⛔⛔ وعمودُ القيمة لا يُرسَم بلا أسعارٍ مقروءة — ت-12', () {
      final ReportTable table = buildDealerDistributionSummaryReport(
        period: span,
        distributions: <DistributionCard>[
          dist(id: '1', dealerId: 'D1', dealerName: 'أحمد'),
        ],
      );
      expect(
        table.columns.map((ReportColumn c) => c.label),
        isNot(contains('قيمة الضمارات')),
      );
      expect(totalOf(table, 'إجمالي الضمارات'), isNull);
    });

    test('★ ويُرسَم لمن يقرؤها بقيمة الضمار المخزَّنة', () {
      final ReportTable table = buildDealerDistributionSummaryReport(
        period: span,
        distributions: <DistributionCard>[
          dist(id: '1', dealerId: 'D1', dealerName: 'أحمد'),
        ],
        pricing: <String, DistributionPricingCard>{
          '1': DistributionPricingCard(
            sourceId: 'SRC-001',
            debtValue: const Money(4500),
            unitPrices: const <Money?>[],
            lineTotals: const <Money?>[],
          ),
        },
        thousandsSeparator: '',
      );
      expect(totalOf(table, 'إجمالي الضمارات'), '4500');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('★★ R-11 — المبيعات النقدية المباشرة', () {
    test('★★ الإجمالياتُ تفصل الحبات عن الأوزان — GR-19', () {
      final ReportTable table = buildCashSalesReport(
        period: span,
        sales: <CashSaleCard>[
          sale(pieces: 20, net: 600),
          sale(documentNumber: 'CSH-2', pieces: 0, weight: 1.5, net: 400),
        ],
        thousandsSeparator: '',
      );
      expect(totalOf(table, 'إجمالي الحبات'), contains('20 حبة'));
      expect(totalOf(table, 'إجمالي الأوزان'), contains('1.500 كجم'));
      expect(totalOf(table, 'إجمالي المقبوض نقداً'), '1000');
    });

    test('⛔ والملغى يُعرَض مشطوباً ولا يدخل الإجمالي — A-14', () {
      final ReportTable table = buildCashSalesReport(
        period: span,
        sales: <CashSaleCard>[
          sale(net: 600),
          sale(
            documentNumber: 'CSH-2',
            net: 900,
            status: CashSaleStatus.cancelled,
          ),
        ],
        thousandsSeparator: '',
      );
      expect(table.rows, hasLength(2));
      expect(table.rows[1].isCancelled, isTrue);
      expect(totalOf(table, 'إجمالي المقبوض نقداً'), '600');
      expect(totalOf(table, 'عدد السندات'), '1');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('★★★ R-12 — المبيعات حسب النوع', () {
    test('⛔⛔★★★ القيمةُ تُقرأ كما كُتبت — ولا تُشتقّ من الكمية والسعر', () {
      // ★ **سطرٌ وزنيٌّ قيمتُه المخزَّنة 38 لا 37.5** (`ADR-0019` — الموضع ③):
      //   ⟵ **وإعادةُ الضرب هنا كانت تُنتج رقماً يخالف المستند.**
      final ReportTable table = buildSalesByItemReport(
        period: span,
        distributions: const <DistributionCard>[],
        cashSales: <CashSaleCard>[
          sale(
            pieces: 0,
            weight: 1.5,
            net: 38,
            lines: const <ValidatedCashSaleLine>[
              ValidatedCashSaleLine(
                itemId: 'ITM-1',
                itemName: 'سكرب',
                quantity: WeightQuantity(WeightKg(1.5)),
                unitPrice: Money(25),
                sackId: null,
                belowMinReason: null,
              ),
            ],
            lineTotals: const <Money?>[Money(38)],
          ),
        ],
        withValue: true,
        thousandsSeparator: '',
      );
      expect(cellOf(table, 0, 3), '38');
      expect(totalOf(table, 'إجمالي قيمة المبيعات'), '38');
    });

    test('★★ وسطرٌ بلا قيمةٍ مسجَّلة يُعَدُّ نقصاً ولا يُجمَع صفراً', () {
      final ReportTable table = buildSalesByItemReport(
        period: span,
        distributions: const <DistributionCard>[],
        cashSales: <CashSaleCard>[
          sale(
            lines: const <ValidatedCashSaleLine>[
              ValidatedCashSaleLine(
                itemId: 'ITM-1',
                itemName: 'صنف',
                quantity: PieceQuantity(PieceCount(5)),
                unitPrice: Money(20),
                sackId: null,
                belowMinReason: null,
              ),
            ],
            lineTotals: const <Money?>[],
          ),
        ],
        withValue: true,
        thousandsSeparator: '',
      );
      expect(table.incompleteCount, 1);
      expect(table.incompleteWarning, isNotNull);
      expect(totalOf(table, 'إجمالي قيمة المبيعات'), '0');
    });

    test('⛔⛔ وعمودُ القيمة يغيب بلا صلاحية الأسعار', () {
      final ReportTable table = buildSalesByItemReport(
        period: span,
        distributions: const <DistributionCard>[],
        cashSales: <CashSaleCard>[
          sale(
            lines: const <ValidatedCashSaleLine>[
              ValidatedCashSaleLine(
                itemId: 'ITM-1',
                itemName: 'صنف',
                quantity: PieceQuantity(PieceCount(5)),
                unitPrice: Money(20),
                sackId: null,
                belowMinReason: null,
              ),
            ],
            lineTotals: const <Money?>[Money(100)],
          ),
        ],
      );
      expect(
        table.columns.map((ReportColumn c) => c.label),
        isNot(contains('القيمة')),
      );
      // ⛔ **ولا يُحتسَب نقصٌ لعمودٍ غير معروض** — ★ **فالتحذير كان يظهر بلا
      //   أن يرى المستخدم موضعَه.**
      expect(table.incompleteCount, 0);
    });

    test('★ وكميةُ التوزيع وكميةُ البيع عمودان لا عمود', () {
      final ReportTable table = buildSalesByItemReport(
        period: span,
        distributions: <DistributionCard>[
          dist(
            id: '1',
            dealerId: 'D1',
            dealerName: 'أحمد',
            lines: const <ValidatedDistributionLine>[
              ValidatedDistributionLine(
                itemId: 'ITM-1',
                itemName: 'صنف',
                quantity: PieceQuantity(PieceCount(12)),
                sackId: null,
                unitPrice: null,
                note: null,
              ),
            ],
          ),
        ],
        cashSales: <CashSaleCard>[
          sale(
            lines: const <ValidatedCashSaleLine>[
              ValidatedCashSaleLine(
                itemId: 'ITM-1',
                itemName: 'صنف',
                quantity: PieceQuantity(PieceCount(3)),
                unitPrice: Money(20),
                sackId: null,
                belowMinReason: null,
              ),
            ],
            lineTotals: const <Money?>[Money(60)],
          ),
        ],
      );
      expect(cellOf(table, 0, 1), '12 حبة');
      expect(cellOf(table, 0, 2), '3 حبة');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('★★ R-13 — السطور غير المسعَّرة', () {
    test('★ صفُّه مستندٌ بعدد سطوره غير المسعَّرة', () {
      final ReportTable table = buildUnpricedLinesReport(
        period: span,
        distributions: <DistributionCard>[
          dist(
            id: '1',
            dealerId: 'D1',
            dealerName: 'أحمد',
            unpriced: 3,
            status: DistributionStatus.partiallyPriced,
          ),
          dist(id: '2', dealerId: 'D2', dealerName: 'بدر'),
        ],
      );
      expect(table.rows, hasLength(1));
      expect(cellOf(table, 0, 3), '3');
      expect(totalOf(table, 'إجمالي السطور غير المسعَّرة'), '3');
      expect(table.incompleteWarning, isNotNull);
    });

    test('★ والمقوتُ فلترٌ محليٌّ يُضيّق الصفوف', () {
      final ReportTable table = buildUnpricedLinesReport(
        period: span,
        distributions: <DistributionCard>[
          dist(id: '1', dealerId: 'D1', dealerName: 'أحمد', unpriced: 2),
          dist(id: '2', dealerId: 'D2', dealerName: 'بدر', unpriced: 4),
        ],
        dealerId: 'D2',
      );
      expect(table.rows, hasLength(1));
      expect(cellOf(table, 0, 2), 'بدر');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('★★★ R-15 — الخصومات', () {
    test('⛔⛔★★★ والمبلغُ المنسوبُ لمصدر التقرير وحدَه — FR-M19-02', () {
      final DiscountCard card = discount(
        lines: <DiscountCardLine>[
          discountLine('SRC-001', 300),
          discountLine('SRC-002', 700),
        ],
      );
      expect(discountAmountForSource(card, 'SRC-001'), const Money(300));
      // ★ **و«كل المصادر» تجمع السطور كلَّها** — ⟵ **ولا مصدرَ يُنسَب إليه خطأ.**
      expect(discountAmountForSource(card, null), const Money(1000));

      final ReportTable table = buildDiscountsReport(
        period: span,
        discounts: <DiscountCard>[card],
        sourceId: 'SRC-001',
        thousandsSeparator: '',
      );
      expect(cellOf(table, 0, 3), '300');
      expect(totalOf(table, 'إجمالي الخصومات'), '300');
    });

    test('⛔ والملغى يُعرَض ولا يدخل الإجمالي', () {
      final ReportTable table = buildDiscountsReport(
        period: span,
        discounts: <DiscountCard>[
          discount(lines: <DiscountCardLine>[discountLine('SRC-001', 300)]),
          discount(
            lines: <DiscountCardLine>[discountLine('SRC-001', 800)],
            isCancelled: true,
          ),
        ],
        sourceId: 'SRC-001',
        thousandsSeparator: '',
      );
      expect(table.rows[1].isCancelled, isTrue);
      expect(totalOf(table, 'إجمالي الخصومات'), '300');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('★★★ R-16 — حركة النقد في تاريخ', () {
    test('★★ الداخلُ والخارجُ والصافي بمعادلة design-overview §2.9', () {
      final ReportTable table = buildCashMovementReport(
        date: dayA,
        movement: movementOf(
          sameDay: 4000,
          previous: 1000,
          cashSales: 500,
          withdrawals: 900,
          expenses: 100,
        ),
        thousandsSeparator: '',
      );
      expect(cellOf(table, 0, 1), '5000');
      expect(cellOf(table, 5, 1), '5500');
      expect(totalOf(table, 'صافي النقد في اليد'), '4500');
      expect(totalOf(table, 'نسبة تغطية الخارج من المقبوض'), '20٪');
    });

    test('⛔⛔★★★ والبندُ المحكومُ يختفي كلياً — E-29 نصّاً', () {
      final ReportTable table = buildCashMovementReport(
        date: dayA,
        movement: movementOf(
          sameDay: 4000,
          withdrawals: 900,
          expenses: 100,
          visibility: const OwnerLedgerVisibility(
            showsWithdrawals: false,
            showsExpenses: true,
          ),
        ),
        thousandsSeparator: '',
      );
      final List<String> labels = <String>[
        for (final ReportRow row in table.rows) row.cells.first,
      ];
      expect(labels, isNot(contains('السحبيات')));
      expect(labels, contains('الخرجيات'));
      // ★★ **والخارجُ يُعاد بناؤه على ما يراه** — ⛔ **وإلا كشف المخفيَّ بالطرح.**
      expect(
        table.rows
            .firstWhere((ReportRow r) => r.cells.first == 'إجمالي النقد الخارج')
            .cells[1],
        '100',
      );
    });

    test('⛔⛔ و«لا مقبوضَ يُقاس عليه» ليست صفراً', () {
      final ReportTable table = buildCashMovementReport(
        date: dayA,
        movement: movementOf(withdrawals: 500),
        thousandsSeparator: '',
      );
      expect(
        totalOf(table, 'نسبة تغطية الخارج من المقبوض'),
        'لا مقبوض يُقاس عليه',
      );
    });

    test('⛔ وصفَّا الإيداع لا يظهران بلا صلاحية قراءتهما — ADR-0017', () {
      final ReportTable table = buildCashMovementReport(
        date: dayA,
        movement: movementOf(sameDay: 1000),
        thousandsSeparator: '',
      );
      final List<String> labels = <String>[
        for (final ReportRow row in table.rows) row.cells.first,
      ];
      expect(labels, isNot(contains('من المقبوض: لم يُودَع')));
    });

    test('★ وتنبيهُ فجوة النقد يظهر في الترويسة', () {
      final ReportTable table = buildCashMovementReport(
        date: dayA,
        movement: movementOf(sameDay: 1000, withdrawals: 900),
        readsDeposit: true,
        thousandsSeparator: '',
      );
      expect(headerOf(table, 'تنبيه'), isNotNull);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('★★★ R-20 — ضمار المالك اليومي', () {
    test('★ صفٌّ لكل يومٍ مرتَّبٌ تصاعدياً وإجمالياتٌ مجموعة', () {
      final ReportTable table = buildOwnerLedgerDailyReport(
        period: span,
        days: <OwnerLedgerProjection>[
          projectOwnerLedgerSummary(
            summary(date: dayB, credit: 2000, settled: 500),
            OwnerLedgerVisibility.full,
          ),
          projectOwnerLedgerSummary(
            summary(date: dayA, credit: 1000, settled: 200),
            OwnerLedgerVisibility.full,
          ),
        ],
        visibility: OwnerLedgerVisibility.full,
        thousandsSeparator: '',
      );
      expect(cellOf(table, 0, 1), '1000');
      expect(cellOf(table, 1, 1), '2000');
      expect(totalOf(table, 'إجمالي الضمار'), '3000');
      expect(totalOf(table, 'إجمالي الواصل'), '700');
      expect(totalOf(table, 'عدد الأيام'), '2');
    });

    test('⛔⛔ وعمودا السحبيات والخرجيات يختفيان لمن لا يملكهما', () {
      final ReportTable table = buildOwnerLedgerDailyReport(
        period: span,
        days: <OwnerLedgerProjection>[
          projectOwnerLedgerSummary(
            summary(date: dayA, credit: 1000, withdrawals: 300),
            const OwnerLedgerVisibility(
              showsWithdrawals: false,
              showsExpenses: false,
            ),
          ),
        ],
        visibility: const OwnerLedgerVisibility(
          showsWithdrawals: false,
          showsExpenses: false,
        ),
        thousandsSeparator: '',
      );
      final Iterable<String> labels =
          table.columns.map((ReportColumn c) => c.label);
      expect(labels, isNot(contains('السحبيات')));
      expect(labels, isNot(contains('الخرجيات')));
      // ★ **والصافي على ما يراه** — ⛔ **ولا يكشف المخفيَّ بالطرح.**
      expect(totalOf(table, 'الصافي النهائي'), '1000');
    });

    test('★★ ووسمُ الأثر الرجعي يظهر بأحدث طابعٍ في الفترة — FR-M19-06', () {
      final ReportTable table = buildOwnerLedgerDailyReport(
        period: span,
        days: <OwnerLedgerProjection>[
          projectOwnerLedgerSummary(
            summary(date: dayA, credit: 100),
            OwnerLedgerVisibility.full,
          ),
          projectOwnerLedgerSummary(
            summary(
              date: dayB,
              credit: 100,
              retro: DateTime.utc(2026, 9, 3, 5),
            ),
            OwnerLedgerVisibility.full,
          ),
        ],
        visibility: OwnerLedgerVisibility.full,
      );
      expect(headerOf(table, '⟳ مُحدَّث بأثر رجعي'), isNotNull);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('★★★ R-21 · R-22 — سجلا السحبيات والخرجيات', () {
    test('⛔⛔★★ وتقريران منفصلان برمزين مختلفين — FR-M19-07 · GR-43', () {
      final ReportTable withdrawals = buildOutflowLedgerReport(
        period: span,
        ledgerType: OutflowLedgerType.withdrawal,
        outflows: <OutflowCard>[
          outflow(
            ledgerType: OutflowLedgerType.withdrawal,
            category: OutflowCategory.withdrawalQat,
            qat: 1200,
          ),
        ],
        thousandsSeparator: '',
      );
      final ReportTable expenses = buildOutflowLedgerReport(
        period: span,
        ledgerType: OutflowLedgerType.expense,
        outflows: const <OutflowCard>[],
      );
      expect(withdrawals.report, ReportId.withdrawals);
      expect(expenses.report, ReportId.expenses);
      expect(totalOf(withdrawals, 'الإجمالي العام'), '1200');
    });

    test('★ والفئةُ تُضيّق الصفوف — FR-M22-19', () {
      final ReportTable table = buildOutflowLedgerReport(
        period: span,
        ledgerType: OutflowLedgerType.expense,
        outflows: <OutflowCard>[
          outflow(
            ledgerType: OutflowLedgerType.expense,
            category: OutflowCategory.expenseCash,
            documentNumber: 'EXP-1',
            cash: 500,
          ),
          outflow(
            ledgerType: OutflowLedgerType.expense,
            category: OutflowCategory.expenseShareCuts,
            documentNumber: 'EXP-2',
            cash: 800,
          ),
        ],
        category: OutflowCategory.expenseCash,
        thousandsSeparator: '',
      );
      expect(table.rows, hasLength(1));
      expect(cellOf(table, 0, 1), 'EXP-1');
      expect(headerOf(table, 'الفئة'), 'مبالغ مالية');
    });

    test('★★ وبندُ قاتٍ بلا سعرٍ يُعلَن نقصاً ويُوسَم في الصف', () {
      final ReportTable table = buildOutflowLedgerReport(
        period: span,
        ledgerType: OutflowLedgerType.withdrawal,
        outflows: <OutflowCard>[
          outflow(
            ledgerType: OutflowLedgerType.withdrawal,
            category: OutflowCategory.withdrawalQat,
            unpriced: 2,
          ),
        ],
      );
      expect(table.incompleteCount, 1);
      expect(cellOf(table, 0, 6), 'سعر غير نهائي');
    });

    test('⛔ والملغى يُعرَض ولا يدخل الإجماليات — A-14', () {
      final ReportTable table = buildOutflowLedgerReport(
        period: span,
        ledgerType: OutflowLedgerType.withdrawal,
        outflows: <OutflowCard>[
          outflow(
            ledgerType: OutflowLedgerType.withdrawal,
            category: OutflowCategory.withdrawalCash,
            cash: 700,
          ),
          outflow(
            ledgerType: OutflowLedgerType.withdrawal,
            category: OutflowCategory.withdrawalCash,
            documentNumber: 'WDR-2',
            cash: 900,
            isCancelled: true,
          ),
        ],
        thousandsSeparator: '',
      );
      expect(table.rows[1].isCancelled, isTrue);
      expect(totalOf(table, 'الإجمالي العام'), '700');
      expect(totalOf(table, 'عدد السندات'), '1');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('★★★ R-23 — الأثر النهائي على حساب المصدر', () {
    test('★ البنودُ الخمسة والأثرُ مجموعُ صوافي الأيام', () {
      final ReportTable table = buildSourceNetImpactReport(
        period: span,
        days: <OwnerLedgerProjection>[
          projectOwnerLedgerSummary(
            summary(
              date: dayA,
              credit: 5000,
              settled: 1000,
              tax: 200,
              withdrawals: 300,
              expenses: 100,
            ),
            OwnerLedgerVisibility.full,
          ),
        ],
        visibility: OwnerLedgerVisibility.full,
        thousandsSeparator: '',
      );
      // ⑩ = (5000 − 0 − 1000) − 0 − 200 − 300 − 100 = 3400
      expect(totalOf(table, 'الأثر النهائي على حساب المصدر'), '3400');
      final List<String> labels = <String>[
        for (final ReportRow row in table.rows) row.cells.first,
      ];
      expect(
        labels,
        containsAll(<String>[
          'إجمالي ضمار الفترة',
          'الواصل',
          'الخصومات',
          'الضريبة',
          'السحبيات',
          'الخرجيات',
        ]),
      );
    });

    test('⛔⛔ والبندُ المحكومُ لا يُعرَض ولا يدخل الأثر', () {
      const OwnerLedgerVisibility hidden = OwnerLedgerVisibility(
        showsWithdrawals: false,
        showsExpenses: false,
      );
      final ReportTable table = buildSourceNetImpactReport(
        period: span,
        days: <OwnerLedgerProjection>[
          projectOwnerLedgerSummary(
            summary(
              date: dayA,
              credit: 5000,
              settled: 1000,
              withdrawals: 300,
              expenses: 100,
            ),
            hidden,
          ),
        ],
        visibility: hidden,
        thousandsSeparator: '',
      );
      expect(totalOf(table, 'الأثر النهائي على حساب المصدر'), '4000');
      expect(table.rows, hasLength(4));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('★★ R-24 — تغطية السحبيات من المقبوض', () {
    test('⛔⛔★★ والنسبةُ على المقبوض لا على الواصل — GR-47', () {
      final ReportTable table = buildWithdrawalCoverageReport(
        date: dayA,
        movement: movementOf(sameDay: 2000, withdrawals: 500, expenses: 100),
        thousandsSeparator: '',
      );
      expect(cellOf(table, 0, 1), '2000');
      expect(totalOf(table, 'نسبة التغطية من المقبوض'), '30٪');
      expect(totalOf(table, 'صافي النقد في اليد'), '1400');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('★★★ R-25 — حساب الرعوي لكل مصدر', () {
    test('⛔⛔ والضريبةُ المعلّقة لا تُقرأ صفراً ولا تدخل الجمع', () {
      final ReportTable table = buildSupplierAccountReport(
        period: span,
        rows: <SupplierLedgerRow>[
          supplierRow(sackId: 'S1', supplierId: 'SUP-1'),
          supplierRow(
            sackId: 'S2',
            supplierId: 'SUP-1',
            revenue: 500,
            tax: null,
            net: null,
            isRevenueFinal: false,
          ),
        ],
        thousandsSeparator: '',
      );
      expect(cellOf(table, 1, 3), 'معلّقة');
      expect(cellOf(table, 1, 4), '—');
      expect(totalOf(table, 'إجمالي الضريبة'), '100');
      expect(totalOf(table, 'إجمالي أسعار الجواني'), '1500');
      expect(totalOf(table, 'جواني بضريبة معلّقة'), '1');
      expect(table.incompleteCount, 1);
    });

    test('★ والرعويُّ فلترٌ محليٌّ لا قيدُ استعلام', () {
      final ReportTable table = buildSupplierAccountReport(
        period: span,
        rows: <SupplierLedgerRow>[
          supplierRow(sackId: 'S1', supplierId: 'SUP-1'),
          supplierRow(sackId: 'S2', supplierId: 'SUP-2'),
        ],
        supplierId: 'SUP-2',
      );
      expect(table.rows, hasLength(1));
      expect(cellOf(table, 0, 1), 'جونية S2');
    });

    test('⛔ والملغاةُ تُعرَض ولا تُحتسَب — A-14', () {
      final ReportTable table = buildSupplierAccountReport(
        period: span,
        rows: <SupplierLedgerRow>[
          supplierRow(sackId: 'S1', supplierId: 'SUP-1'),
          supplierRow(sackId: 'S2', supplierId: 'SUP-1', isCancelled: true),
        ],
        thousandsSeparator: '',
      );
      expect(table.rows[1].isCancelled, isTrue);
      expect(cellOf(table, 1, 5), 'ملغاة');
      expect(totalOf(table, 'عدد الجواني'), '1');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('★★ R-26 — الضريبة المستحقة', () {
    test('★ صفٌّ لكل رعويٍّ بضريبته وعددِ معلّقاته', () {
      final ReportTable table = buildSupplierTaxReport(
        period: span,
        rows: <SupplierLedgerRow>[
          supplierRow(sackId: 'S1', supplierId: 'SUP-1', tax: 100),
          supplierRow(sackId: 'S2', supplierId: 'SUP-1', tax: 250),
          supplierRow(
            sackId: 'S3',
            supplierId: 'SUP-2',
            tax: null,
            net: null,
          ),
        ],
        thousandsSeparator: '',
      );
      expect(table.rows, hasLength(2));
      expect(cellOf(table, 0, 2), '350');
      expect(cellOf(table, 1, 2), '0');
      expect(cellOf(table, 1, 3), '1');
      expect(totalOf(table, 'إجمالي الضريبة المستحقة'), '350');
      expect(table.incompleteCount, 1);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('★★★ R-27 — تفكيك سعر جونية', () {
    test('★★ السعرُ من computeSackRevenue — والمستبعَدُ لا يدخله', () {
      final ReportTable table = buildSackPriceBreakdownReport(
        sackDisplayName: 'جونية 1',
        contributions: <SackRevenueContribution>[
          contribution(origin: SackRevenueSource.distribution),
          contribution(origin: SackRevenueSource.cashSale, lineValue: 200),
          contribution(
            origin: SackRevenueSource.withdrawal,
            lineValue: 999,
            isExcluded: true,
          ),
          contribution(
            origin: SackRevenueSource.expense,
            lineValue: 888,
            isCancelled: true,
          ),
        ],
        thousandsSeparator: '',
      );
      expect(totalOf(table, 'سعر الجونية'), '500');
      expect(totalOf(table, 'عدد الحركات الداخلة'), '2');
      expect(table.rows[2].isCancelled, isTrue);
      expect(table.rows[3].isCancelled, isTrue);
    });

    test('★★ والحركةُ الداخلةُ بلا قيمةٍ تجعل السعر غير نهائي', () {
      final ReportTable table = buildSackPriceBreakdownReport(
        sackDisplayName: 'جونية 1',
        contributions: <SackRevenueContribution>[
          contribution(origin: SackRevenueSource.distribution),
          contribution(origin: SackRevenueSource.cashSale, lineValue: null),
        ],
        thousandsSeparator: '',
      );
      expect(headerOf(table, 'حالة السعر'), contains('غير نهائي'));
      expect(table.incompleteCount, 1);
      expect(cellOf(table, 1, 6), '—');
    });

    test('★ والوجهةُ تُقرأ من النطاق لا من الشاشة', () {
      expect(SackRevenueSource.withdrawal.label, 'سحبية');
      final ReportTable table = buildSackPriceBreakdownReport(
        sackDisplayName: 'جونية 1',
        contributions: <SackRevenueContribution>[
          contribution(origin: SackRevenueSource.expense),
        ],
      );
      expect(cellOf(table, 0, 1), 'خرجية');
    });
  });
  // ═══════════════════════════════════════════════════════════════════════
  group('★★ [DEBT-72] — الفلاترُ المحلية المؤجَّلة من `WU-011`', () {
    test('① الرعوي يُضيّق الوارد عدداً — ولا استعلامَ جديد', () {
      final ReportTable table = buildCountedIntakesReport(
        period: span,
        intakes: <CountedIntakeCard>[
          intake(documentNumber: 'INC-1', supplierId: 'SUP-1', quantity: 10),
          intake(documentNumber: 'INC-2', supplierId: 'SUP-2', quantity: 40),
        ],
        supplierNames: const <String, String>{'SUP-1': 'رعوي أول'},
        supplierId: 'SUP-1',
      );
      expect(table.rows, hasLength(1));
      expect(cellOf(table, 0, 1), 'INC-1');
      expect(headerOf(table, 'الرعوي'), 'رعوي أول');
      // ★★ **والإجمالي على المعروض وحدَه** — ⛔ **لا على ما رُشِّح خارجه.**
      expect(totalOf(table, 'إجمالي الوارد'), contains('10 حبة'));
    });

    test('② الجونية تُضيّق الوارد جواني', () {
      final ReportTable table = buildSackIntakesReport(
        period: span,
        sacks: <SackCard>[
          sackOf(documentNumber: 'SCK-1', sequence: 1),
          sackOf(documentNumber: 'SCK-2', sequence: 2),
        ],
        sackId: 'SCK-2',
      );
      expect(table.rows, hasLength(1));
      expect(headerOf(table, 'الجونية'), isNotNull);
    });

    test('③ المقوت يُضيّق التوزيعات والضمارات معاً', () {
      final List<DistributionCard> cards = <DistributionCard>[
        dist(id: '1', dealerId: 'D1', dealerName: 'أحمد'),
        dist(id: '2', dealerId: 'D2', dealerName: 'بدر'),
      ];
      final ReportTable detail = buildDistributionsReport(
        period: span,
        distributions: cards,
        dealerId: 'D2',
      );
      final ReportTable settlements = buildSettlementsReport(
        period: span,
        distributions: cards,
        dealerNames: const <String, String>{'D2': 'بدر'},
        dealerId: 'D2',
      );
      expect(detail.rows, hasLength(1));
      expect(cellOf(detail, 0, 2), 'بدر');
      expect(settlements.rows, hasLength(1));
      expect(headerOf(settlements, 'المقوت'), 'بدر');
    });

    test('④ النوع يُضيّق رصيد المخزون ومتبقي اليوم', () {
      final List<ItemDailyBalanceCard> balances = <ItemDailyBalanceCard>[
        balanceOf(itemKey: 'ITM-1', name: 'بطوة', pieces: 20),
        balanceOf(itemKey: 'ITM-2', name: 'شامي', pieces: 30),
      ];
      final ReportTable stock = buildCurrentStockReport(
        stockDate: dayA,
        balances: balances,
        itemKey: 'ITM-2',
      );
      final ReportTable remainder = buildTodayRemainderReport(
        stockDate: dayA,
        balances: balances,
        itemKey: 'ITM-2',
      );
      expect(stock.rows, hasLength(1));
      expect(headerOf(stock, 'النوع'), 'شامي');
      // ⛔⛔ **والفلترُ يُصرِّح بنفسه ولو خلا الجدول** — ★ **بالاسم لا بالمفتاح.**
      final ReportTable empty = buildCurrentStockReport(
        stockDate: dayA,
        balances: const <ItemDailyBalanceCard>[],
        itemKey: 'ITM-9',
        itemName: 'نوعٌ بلا حركة',
      );
      expect(empty.rows, isEmpty);
      expect(headerOf(empty, 'النوع'), 'نوعٌ بلا حركة');
      expect(remainder.rows, hasLength(1));
      expect(totalOf(remainder, 'إجمالي المتبقي'), contains('30 حبة'));
    });

    test('⛔ وبلا فلترٍ يبقى كلُّ شيء كما كان — لا سلوكَ يتغيّر', () {
      final ReportTable table = buildCurrentStockReport(
        stockDate: dayA,
        balances: <ItemDailyBalanceCard>[
          balanceOf(itemKey: 'ITM-1', name: 'بطوة', pieces: 20),
          balanceOf(itemKey: 'ITM-2', name: 'شامي', pieces: 30),
        ],
      );
      expect(table.rows, hasLength(2));
      expect(headerOf(table, 'النوع'), isNull);
    });
  });
}

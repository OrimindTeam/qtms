/// بناةُ التقارير — `WU-011` (`M19`).
///
/// ⚠️⚠️ **وما تُثبته هذه الاختبارات وما لا تُثبته:** تُثبت أن **الإجماليات
/// تفصل الحبات عن الأوزان** (`GR-19`)، وأن **الملغى يُعرَض ولا يُحتسَب**
/// (`A-14`)، وأن **المقبوض يُنسَب لمصدره وحدَه** (`FR-M19-02`)، وأن
/// **الملفَّ المُصدَّر يطابق الجدول خليةً بخلية**.
///
/// ⛔⛔ **ولا تُثبت أن الاستعلام مسموحٌ به** — ★ **ذاك في `firestore.rules`
/// ومُختبَرٌ على المحاكي** (`RISK-02`)، ⛔ **ولا يُغني أحدهما عن الآخر.**
library;

import 'package:qtms_domain/qtms_domain.dart';
import 'package:test/test.dart';

final CalendarDay day1 = CalendarDay(2026, 8, 20);
final CalendarDay day2 = CalendarDay(2026, 8, 21);
final ReportPeriod period = ReportPeriod.of(from: day1, to: day2)!;

StockMovementCard movement({
  required MovementDirection direction,
  required StockQuantity quantity,
  bool isCancelled = false,
  CalendarDay? stockDate,
}) =>
    StockMovementCard(
      movementId: 'MOV-1',
      itemKey: 'ITM-1',
      itemName: 'صنف',
      direction: direction,
      quantity: quantity,
      balanceAfter: quantity,
      sourceDocumentType: SourceDocumentType.countedIntake,
      sourceDocumentNumber: 'INC-1',
      entryDate: DateTime.utc(2026, 8, 20, 6),
      isCancelled: isCancelled,
      isAmended: false,
      stockDate: stockDate ?? day1,
    );

ItemDailyBalanceCard balance({
  required String name,
  required StockQuantity value,
}) =>
    ItemDailyBalanceCard(
      sourceId: 'SRC-001',
      itemKey: name,
      itemName: name,
      stockDate: day1,
      incoming: value,
      outgoing: const PieceQuantity(PieceCount(0)),
      balance: value,
    );

ReceiptCard receipt({
  required List<ReceiptCardLine> lines,
  Money surplus = Money.zero,
  bool isCancelled = false,
}) =>
    ReceiptCard(
      documentNumber: 'RCP-1',
      date: day1,
      dealerId: 'DLR-1',
      dealerName: 'مقوت',
      surplusAmount: surplus,
      surplusScope: SurplusScope.general,
      totalDebtAtEntry: const Money(5000),
      isCancelled: isCancelled,
      lines: lines,
      affectedSourceIds: <String>[
        for (final ReceiptCardLine line in lines) line.sourceId,
      ],
    );

ReceiptCardLine line(String sourceId, int amount) => ReceiptCardLine(
      debtLotId: 'LOT-$sourceId',
      sourceId: sourceId,
      remainingBefore: Money(amount),
      amount: Money(amount),
      remainingAfter: Money.zero,
    );

/// ★ عدّادٌ يضمن معرّفاً فريداً لكل قيد — ⛔ **والرصيدُ الجاري يُفهرَس به.**
int _ledgerSeq = 0;

DealerLedgerRowCard ledgerRow({
  required DealerLedgerDirection direction,
  required int amount,
  DateTime? at,
  bool isCancelled = false,
  DealerLedgerEntryType? type = DealerLedgerEntryType.debt,
}) =>
    DealerLedgerRowCard(
      entryId: 'ENT-${_ledgerSeq++}',
      dealerId: 'DLR-1',
      sourceId: 'SRC-001',
      direction: direction,
      entryType: type,
      amount: Money(amount),
      isCancelled: isCancelled,
      entryDate: at,
      sourceDocNumber: 'DST-1',
    );

DistributionCard distribution({
  SettlementStatus? settlement,
  DistributionStatus status = DistributionStatus.priced,
  int unpriced = 0,
}) =>
    DistributionCard(
      distributionId: 'DLR-1_SRC-001_20260820',
      documentNumber: 'DST-1',
      sourceId: 'SRC-001',
      dealerId: 'DLR-1',
      dealerName: 'مقوت',
      stockDate: day1,
      entryDate: DateTime.utc(2026, 8, 20, 7),
      status: status,
      unpricedLineCount: unpriced,
      totalPieces: const PieceCount(40),
      totalWeight: const WeightKg(2.5),
      lines: const <ValidatedDistributionLine>[],
      settlementStatus: settlement,
    );

void main() {
  group('★★★ GR-19 — الحبّات والأوزان لا تُجمَع أبداً', () {
    test('⛔ إجمالياتُ حركة النوع سطرٌ لكلِّ وحدة', () {
      final ReportTable table = buildItemMovementsReport(
        period: period,
        itemName: 'صنف',
        movements: <StockMovementCard>[
          movement(
            direction: MovementDirection.incoming,
            quantity: const PieceQuantity(PieceCount(60)),
          ),
          movement(
            direction: MovementDirection.incoming,
            quantity: const WeightQuantity(WeightKg(1.5)),
          ),
        ],
      );
      final ExportField incoming = table.totals.first;
      expect(incoming.label, 'إجمالي الوارد');
      // ★ **«60 حبة + 1.500 كجم»** — ⛔ **ولا رقمَ واحدٌ يجمعهما.**
      expect(incoming.value, contains('60 حبة'));
      expect(incoming.value, contains('1.500 كجم'));
    });

    test('★★ والصفرُ يُكتب صراحةً — فالطرفُ الغائب معلومة', () {
      final ReportTable table = buildCurrentStockReport(
        stockDate: day1,
        balances: <ItemDailyBalanceCard>[
          balance(name: 'صنف', value: const PieceQuantity(PieceCount(10))),
        ],
      );
      expect(
        table.totals
            .firstWhere((ExportField f) => f.label == 'إجمالي الرصيد')
            .value,
        '10 حبة + 0.000 كجم',
      );
    });
  });

  group('⛔⛔ A-14 — الملغى يُعرَض ولا يدخل أي إجمالي', () {
    test('★ حركةٌ ملغاة تبقى صفّاً ولا تُحتسَب', () {
      final ReportTable table = buildItemMovementsReport(
        period: period,
        itemName: 'صنف',
        movements: <StockMovementCard>[
          movement(
            direction: MovementDirection.incoming,
            quantity: const PieceQuantity(PieceCount(60)),
          ),
          movement(
            direction: MovementDirection.incoming,
            quantity: const PieceQuantity(PieceCount(40)),
            isCancelled: true,
          ),
        ],
      );
      expect(table.rows.length, 2);
      expect(table.rows.last.isCancelled, isTrue);
      expect(table.countedRows, 1);
      expect(table.totals.first.value, contains('60 حبة'));
    });

    test('★ وكشفُ الحساب لا يجمع قيداً ملغى', () {
      final ReportTable table = buildDealerStatementReport(
        period: period,
        dealerName: 'مقوت',
        entries: <DealerLedgerRowCard>[
          ledgerRow(
            direction: DealerLedgerDirection.debit,
            amount: 1000,
            at: DateTime.utc(2026, 8, 20, 6),
          ),
          ledgerRow(
            direction: DealerLedgerDirection.debit,
            amount: 500,
            at: DateTime.utc(2026, 8, 20, 7),
            isCancelled: true,
          ),
        ],
      );
      expect(
        table.totals
            .firstWhere((ExportField f) => f.label == 'إجمالي المدين')
            .value,
        '1,000',
      );
    });
  });

  group('★★★ FR-M19-02 — لا رقم من مصدرٍ خارج التقرير', () {
    test('⛔ المقبوضُ في تقرير مصدرٍ سطورُ ذلك المصدر وحدَها', () {
      final ReceiptCard card = receipt(
        lines: <ReceiptCardLine>[line('SRC-001', 3000), line('SRC-002', 2000)],
        surplus: const Money(500),
      );
      expect(receiptAmountForSource(card, 'SRC-001'), const Money(3000));
      expect(receiptAmountForSource(card, 'SRC-002'), const Money(2000));
    });

    test('★★ و«كل المصادر» تجمع السطور والفائض معاً', () {
      final ReceiptCard card = receipt(
        lines: <ReceiptCardLine>[line('SRC-001', 3000), line('SRC-002', 2000)],
        surplus: const Money(500),
      );
      // ★ **والفائض جزءٌ من المقبوض** (`FR-M12-11`) — ⛔ **ولا يُنسَب لمصدر.**
      expect(receiptAmountForSource(card, null), const Money(5500));
    });

    test('★ والسند الملغى لا يدخل الإجمالي', () {
      final ReportTable table = buildReceiptsReport(
        period: period,
        receipts: <ReceiptCard>[
          receipt(lines: <ReceiptCardLine>[line('SRC-001', 3000)]),
          receipt(
            lines: <ReceiptCardLine>[line('SRC-001', 1000)],
            isCancelled: true,
          ),
        ],
        sourceId: 'SRC-001',
      );
      expect(table.rows.length, 2);
      expect(
        table.totals
            .firstWhere((ExportField f) => f.label == 'إجمالي المقبوض')
            .value,
        '3,000',
      );
    });
  });

  group('★★ R-10 — القيمةُ عمودٌ مشروطٌ بصلاحيتها', () {
    test('⛔ بلا أسعارٍ لا عمودَ قيمةٍ أصلاً — ⛔ ولا صفرٌ مكانه', () {
      final ReportTable table = buildSettlementsReport(
        period: period,
        distributions: <DistributionCard>[
          distribution(settlement: SettlementStatus.open),
        ],
      );
      expect(
        table.columns.map((ReportColumn c) => c.label),
        isNot(contains('قيمة الضمار')),
      );
      expect(table.rows.single.cells.length, table.columns.length);
    });

    test('★ ومع الأسعار يظهر العمود وإجماليه', () {
      final ReportTable table = buildSettlementsReport(
        period: period,
        distributions: <DistributionCard>[
          distribution(settlement: SettlementStatus.closed),
        ],
        pricing: <String, DistributionPricingCard>{
          'DLR-1_SRC-001_20260820': DistributionPricingCard(
            sourceId: 'SRC-001',
            debtValue: const Money(7500),
            unitPrices: const <Money?>[],
            lineTotals: const <Money?>[],
          ),
        },
      );
      expect(
        table.columns.map((ReportColumn c) => c.label),
        contains('قيمة الضمار'),
      );
      expect(
        table.totals
            .firstWhere((ExportField f) => f.label == 'إجمالي الضمارات')
            .value,
        '7,500',
      );
    });

    test('⛔⛔ وحالةٌ غائبة تُكتب «غير معروفة» — ⛔ ولا تُقرأ «مفتوح»', () {
      final ReportTable table = buildSettlementsReport(
        period: period,
        distributions: <DistributionCard>[distribution()],
      );
      expect(table.rows.single.cells, contains('غير معروفة'));
    });

    test('★★ وعددُ المستندات الناقصة من `unpricedLineCount` لا من تقدير', () {
      final ReportTable table = buildDistributionsReport(
        period: period,
        distributions: <DistributionCard>[
          distribution(unpriced: 2, status: DistributionStatus.partiallyPriced),
          distribution(),
        ],
      );
      expect(table.incompleteCount, 1);
      expect(table.incompleteWarning, contains('1 مستند بقيم ناقصة'));
    });
  });

  group('★★ R-02 — مرشِّح التوفّر قاعدةٌ في النطاق', () {
    test('★ «نفد» تُبقي ما رصيدُه صفر وحدَه', () {
      final ReportTable table = buildCurrentStockReport(
        stockDate: day1,
        balances: <ItemDailyBalanceCard>[
          balance(name: 'متوفر', value: const PieceQuantity(PieceCount(5))),
          balance(name: 'نافد', value: const PieceQuantity(PieceCount(0))),
        ],
        availability: StockAvailability.depleted,
      );
      expect(table.rows.single.cells.first, 'نافد');
    });

    test('★ ووزنٌ موجبٌ يُقرأ متوفراً', () {
      expect(stockIsAvailable(const WeightQuantity(WeightKg(0.5))), isTrue);
      expect(stockIsAvailable(const WeightQuantity(WeightKg.zero)), isFalse);
    });
  });

  group('★★★ R-19 — الكشفُ تصاعديٌّ ورصيدُه الختامي آخرُ حركة', () {
    test('★ الترتيبُ بتاريخ الإدخال تصاعدياً', () {
      final ReportTable table = buildDealerStatementReport(
        period: period,
        dealerName: 'مقوت',
        entries: <DealerLedgerRowCard>[
          ledgerRow(
            direction: DealerLedgerDirection.credit,
            amount: 400,
            at: DateTime.utc(2026, 8, 21, 9),
            type: DealerLedgerEntryType.receipt,
          ),
          ledgerRow(
            direction: DealerLedgerDirection.debit,
            amount: 1000,
            at: DateTime.utc(2026, 8, 20, 6),
          ),
        ],
      );
      expect(table.rows.first.cells, contains('ضمار'));
      expect(table.rows.last.cells, contains('قبض'));
      expect(
        table.totals
            .firstWhere((ExportField f) => f.label == 'الرصيد الختامي')
            .value,
        '600',
      );
    });

    test('⛔⛔★★★ والرصيدُ الختامي يُشتقّ من الدفتر لا من حقلٍ مخزَّن', () {
      // ⛔⛔★★★ **`DEBT-75` — قِيس على المحاكي:** ★ **كاتبُ التوزيع يكتب
      //    `balanceAfter` وكاتبُ القبض لا يكتبه** ⟵ **فكان كلُّ قيدِ قبضٍ
      //    يُقرأ صفراً**، ⟹ **و«الرصيد الختامي» صفراً بينما المدين ناقصَ
      //    الدائن 49,800** ⛔ **رقمٌ خاطئ يُصدَّر إلى يد العميل.**
      final ReportTable table = buildDealerStatementReport(
        period: period,
        dealerName: 'مقوت',
        entries: <DealerLedgerRowCard>[
          ledgerRow(
            direction: DealerLedgerDirection.debit,
            amount: 48000,
            at: DateTime.utc(2026, 8, 28, 6),
          ),
          // ★ **وآخرُ قيدٍ قبضٌ** — ⟵ **وهو بالضبط ما كان يُصفِّر الختامي.**
          ledgerRow(
            direction: DealerLedgerDirection.credit,
            amount: 5000,
            at: DateTime.utc(2026, 8, 29, 6),
            type: DealerLedgerEntryType.receipt,
          ),
        ],
      );
      expect(
        table.totals
            .firstWhere((ExportField f) => f.label == 'الرصيد الختامي')
            .value,
        '43,000',
      );
      // ★ **والرصيدُ الجاري يُعرَض على كل صف** — ⛔ **ولا صفرَ على القبض.**
      expect(table.rows.first.cells, contains('48,000'));
      expect(table.rows.last.cells, contains('43,000'));
    });

    test('★ والقيدُ الملغى لا يُحرِّك الرصيد الجاري ولا يُنسَب له رقم', () {
      final ReportTable table = buildDealerStatementReport(
        period: period,
        dealerName: 'مقوت',
        entries: <DealerLedgerRowCard>[
          ledgerRow(
            direction: DealerLedgerDirection.debit,
            amount: 1000,
            at: DateTime.utc(2026, 8, 20, 6),
          ),
          ledgerRow(
            direction: DealerLedgerDirection.debit,
            amount: 500,
            at: DateTime.utc(2026, 8, 20, 7),
            isCancelled: true,
          ),
        ],
      );
      expect(table.rows.last.cells, contains('—'));
      expect(
        table.totals
            .firstWhere((ExportField f) => f.label == 'الرصيد الختامي')
            .value,
        '1,000',
      );
    });

    test('⛔ ونوعُ قيدٍ مجهول يُسمّى مجهولاً ولا يُقرأ ضماراً', () {
      final ReportTable table = buildDealerStatementReport(
        period: period,
        dealerName: 'مقوت',
        entries: <DealerLedgerRowCard>[
          ledgerRow(
            direction: DealerLedgerDirection.debit,
            amount: 100,
            at: DateTime.utc(2026, 8, 20),
            type: null,
          ),
        ],
      );
      expect(table.rows.single.cells, contains('قيد غير معروف'));
      expect(table.rows.single.cells, isNot(contains('ضمار')));
    });
  });

  group('★ R-28 — كلُّ بندٍ نقصٌ بتعريفه', () {
    test('★ وعددُه هو تحذيرُ النواقص نفسُه', () {
      final ReportTable table = buildPendingEntriesReport(
        period: period,
        entries: <PendingEntryCard>[
          PendingEntryCard(
            id: 'P-1',
            kind: PendingDocumentKind.sack,
            documentId: 'SCK-1',
            readableTitle: 'جونية 1',
            sourceId: 'SRC-001',
            date: day1,
            missingField: 'ضريبة الكيلو',
          ),
        ],
      );
      expect(table.incompleteCount, 1);
      expect(table.rows.single.cells, contains('ضريبة الكيلو'));
    });
  });

  group('★★★ الملفُّ المُصدَّر يطابق الجدول خليةً بخلية', () {
    test('⛔ ولا يُعاد بناء رقمٍ فيه', () {
      final ReportTable table = buildCurrentStockReport(
        stockDate: day1,
        balances: <ItemDailyBalanceCard>[
          balance(name: 'صنف', value: const PieceQuantity(PieceCount(7))),
        ],
      );
      final ExportableDocument document = buildReportExport(
        business: const MessageBusiness(
          businessName: 'وكالة',
          thousandsSeparator: ',',
        ),
        table: table,
        sourceId: 'SRC-001',
        sourceName: 'رداع',
        entityId: 'R-02:20260820-20260820',
      );
      expect(document.title, 'رصيد المخزون الحالي');
      // ★★ **والمصدر أوّلُ صفٍّ في الترويسة** — ⛔ **ولا يسقط** (`CR-004`).
      expect(document.header.first.label, 'المصدر');
      expect(document.header.first.value, 'رداع');
      expect(document.columns, <String>['النوع', 'الوارد', 'الصادر', 'الرصيد']);
      expect(document.rows.single.cells, table.rows.single.cells);
      expect(document.totals, table.totals);
      // ★★ **ونوعُ الكيان له كاتبٌ في القائمة المعتمدة** — ⛔ **وإلا رُفض
      //    التصدير من `logExport`** (درسُ `WU-010` حرفياً).
      expect(document.entityType, reportEntityType);
      expect(auditEntityTypes, contains(document.entityType));
      expect(document.entityId, 'R-02:20260820-20260820');
    });
  });

  group('★★ الفترة — ⛔ ولا مدىً مقلوب', () {
    test('⛔ المقلوبُ يُرفَض ولا يُقلَب صامتاً', () {
      expect(ReportPeriod.of(from: day2, to: day1), isNull);
    });

    test('★ ونصُّها ومداها المضغوط', () {
      expect(period.label, 'من 2026/08/20 إلى 2026/08/21');
      expect(period.compactRange, '20260820-20260821');
      expect(ReportPeriod.singleDay(day1).label, '2026/08/20');
    });
  });

  group('★★ كتالوج التقارير', () {
    test('★ لكلِّ عائلةٍ مفتاحٌ مستقل — ⛔ ولا مفتاحَ مشترك', () {
      final Set<Permission> keys = <Permission>{
        for (final ReportFamily family in ReportFamily.values)
          family.requiredPermission,
      };
      expect(keys.length, ReportFamily.values.length);
    });

    test('★ وكلُّ تقريرٍ يُقرأ برمزه — والمجهولُ `null`', () {
      expect(ReportId.tryParse('R-01'), ReportId.itemMovements);
      expect(ReportId.tryParse('R-99'), isNull);
      expect(ReportId.tryParse(null), isNull);
    });

    test('★ وتقاريرُ العائلة بترتيب `FR-M19` §2', () {
      expect(
        reportsOfFamily(ReportFamily.financial),
        <ReportId>[
          ReportId.receipts,
          ReportId.dealerBalances,
          ReportId.dealerStatement,
        ],
      );
    });
  });
}

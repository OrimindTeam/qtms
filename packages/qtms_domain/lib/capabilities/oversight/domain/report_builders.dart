/// بناةُ التقارير — ★★★ **دوالُّ خالصة تحوّل البطاقاتِ المقروءة إلى جداول**.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **وكلُّ رقمٍ هنا مبنيٌّ من الدفتر أو المستند — ⛔ لا من ملخص**
/// (`ADR-0008` · معيارُ قبول `WU-011` نصّاً): ★ **والملخصاتُ مشتقّةٌ تُقرأ
/// للعرض السريع** ⛔ **ولا تُقرأ مصدرَ حقيقةٍ لتقرير.**
///
/// ⛔⛔★★★ **ولا جمعَ بين حبّةٍ وكيلوجرام في أي إجمالي** (`GR-19` ·
/// `FR-M19-05` · `E-31`) — ★ **والإجمالياتُ الكمّية كلُّها بـ[formatTotals]**،
/// ⟵ **وهي تفصل السطرين بنيوياً** ⛔ **فلا موضعَ لجمعٍ خاطئ أصلاً.**
///
/// ⛔⛔★★★ **والحركةُ الملغاة تُعرَض ولا تدخل أي إجمالي** (`A-14` · `GR-06` ·
/// `ADR-0004`) — ★ **فحذفُها يُخفي تاريخاً**، ⛔ **وإدخالُها يُفسِد رقماً.**
/// ═══════════════════════════════════════════════════════════════════════
///
/// ⚠️⚠️ **والتقارير المخزنية كلُّها على `stockDate`** — ⛔ **ولا `entryDate`
/// إلا في دفتر المقاوته وحدَه** (`R-19` — **دفترٌ مالي لا مخزني**):
/// ★ **وخلطُهما يُنتج أرقاماً خاطئة بصمت لا تظهر إلا مع تصريفٍ متأخر**
/// (`RISK-07` · `ADR-0006`).
library;

import '../../../core/calendar_day.dart';
import '../../../core/money.dart';
import '../../../core/quantity.dart';
import '../../inventory/domain/counted_intake.dart';
import '../../inventory/domain/inventory.dart';
import '../../inventory/domain/inventory_repository.dart';
import '../../inventory/domain/sack_intake.dart';
import '../../inventory/domain/sack_intake_repository.dart';
import '../../sales_receivables/domain/distribution.dart';
import '../../sales_receivables/domain/distribution_repository.dart';
import '../../sales_receivables/domain/receipt.dart';
import '../../sales_receivables/domain/receipt_repository.dart';
import 'export_documents.dart';
import 'message_templates.dart';
import 'pending_entry.dart';
import 'report_catalog.dart';
import 'report_repository.dart';
import 'report_table.dart';

// ═════════════════════════════════════════════════════════════════════════
// مرشِّحاتٌ لها قاعدةٌ — ★ **تعيش في النطاق لا في شاشة** (`ADR-0009`)
// ═════════════════════════════════════════════════════════════════════════

/// ★ حالةُ توفّر النوع في `R-02` — `FR-M19` §2 («متوفر/نفد»).
enum StockAvailability {
  /// متوفر — **رصيدٌ أكبر من صفر**.
  available('متوفر'),

  /// نفد — **رصيدٌ صفرٌ أو أقل**.
  depleted('نفد');

  const StockAvailability(this.label);

  /// الاسم المعروض.
  final String label;
}

/// ★ حالةُ رصيد المقوت في `R-17` — `FR-M19` §2 («الحالة»).
enum DealerBalanceState {
  /// عليه رصيد — **الرصيد ≠ صفر**.
  outstanding('عليه رصيد'),

  /// مُصفّى — **الرصيد صفر**.
  settled('مُصفّى');

  const DealerBalanceState(this.label);

  /// الاسم المعروض.
  final String label;
}

/// ★★ هل النوع متوفر؟ — **قاعدةٌ واحدة** ⛔ **لا مقارنةٌ في شاشة**
/// (`design-system.md` §5.1).
bool stockIsAvailable(StockQuantity balance) => switch (balance) {
      PieceQuantity(:final PieceCount count) => count.pieces > 0,
      WeightQuantity(:final WeightKg weight) => weight.kilograms > 0,
    };

/// ★★★ **المقبوضُ المنسوبُ لمصدرٍ بعينه** — `FR-M19-02` (`GR-23`).
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **ولماذا لا يُعرَض إجمالي السند كاملاً في تقرير مصدر:** ★ **سندُ
/// القبض يمسّ عدة مصادر** (`affectedSourceIds`) — ⟵ **وعرضُ إجماليه في
/// تقرير مصدرٍ واحد يُظهر رقماً من مصدرٍ خارج نطاق القارئ**، ⛔ **وهو نصُّ
/// `FR-M19-02` الحرِج: «لا يظهر فيه أي رقم من مصدر خارج نطاقه».**
///
/// ★★ **والفائض لا يُنسَب لمصدر** — ⛔ **ولا يدخل هذا الجمع:** ★ **نطاقُه قد
/// يكون عاماً** (`SurplusScope.general` — `FR-M12-11`)، ⟵ **ونسبتُه لمصدرٍ
/// بعينه كانت ستُضيف إليه مالاً لم يُسدَّد له.** ★ **ويظهر في تقرير «كل
/// المصادر» وحده** — ⟵ **حيث لا مصدرَ يُنسَب إليه خطأً.**
/// ═══════════════════════════════════════════════════════════════════════
Money receiptAmountForSource(ReceiptCard receipt, String? sourceId) {
  if (sourceId == null) {
    // ★ **«كل المصادر» — ولا مصدرَ يُنسَب إليه خطأ**: ⟵ **فالفائض جزءٌ من
    //   المقبوض** (`FR-M12-11` · `renderReceiptMessage`).
    Money total = receipt.surplusAmount;
    for (final ReceiptCardLine line in receipt.lines) {
      total = total + line.amount;
    }
    return total;
  }
  Money total = Money.zero;
  for (final ReceiptCardLine line in receipt.lines) {
    if (line.sourceId == sourceId) total = total + line.amount;
  }
  return total;
}

// ═════════════════════════════════════════════════════════════════════════
// `R-01` — حركة نوع تفصيلية
// ═════════════════════════════════════════════════════════════════════════

/// ★★ يبني `R-01` — **حركاتُ نوعٍ في فترة بالرصيد بعد كل حركة**.
///
/// ⚠️ **والملغاة تُعرَض موسومةً ولا تدخل الإجماليات** (`A-14`).
ReportTable buildItemMovementsReport({
  required ReportPeriod period,
  required String itemName,
  required List<StockMovementCard> movements,
}) {
  final List<StockMovementCard> counted = <StockMovementCard>[
    for (final StockMovementCard movement in movements)
      if (!movement.isCancelled) movement,
  ];
  return ReportTable(
    report: ReportId.itemMovements,
    header: <ExportField>[
      ExportField('الفترة', period.label),
      ExportField('النوع', itemName),
    ],
    columns: const <ReportColumn>[
      ReportColumn('تاريخ المخزون'),
      ReportColumn('الاتجاه'),
      ReportColumn('الكمية', numeric: true),
      ReportColumn('الرصيد بعد الحركة', numeric: true),
      ReportColumn('المستند'),
      ReportColumn('الحالة'),
    ],
    rows: <ReportRow>[
      for (final StockMovementCard movement in movements)
        ReportRow(
          <String>[
            _dayCell(movement.stockDate),
            _directionLabel(movement.direction),
            formatQuantity(movement.quantity),
            formatQuantity(movement.balanceAfter),
            movement.sourceDocumentNumber,
            _movementStateLabel(movement),
          ],
          isCancelled: movement.isCancelled,
        ),
    ],
    totals: <ExportField>[
      ExportField(
        'إجمالي الوارد',
        formatTotals(<StockQuantity>[
          for (final StockMovementCard movement in counted)
            if (movement.direction == MovementDirection.incoming)
              movement.quantity,
        ]),
      ),
      ExportField(
        'إجمالي الصادر',
        formatTotals(<StockQuantity>[
          for (final StockMovementCard movement in counted)
            if (movement.direction == MovementDirection.outgoing)
              movement.quantity,
        ]),
      ),
      ExportField('عدد الحركات', '${counted.length}'),
    ],
  );
}

// ═════════════════════════════════════════════════════════════════════════
// `R-02` — رصيد المخزون الحالي · `R-05` — متبقي اليوم لكل نوع
// ═════════════════════════════════════════════════════════════════════════

/// ★★ يبني `R-02` — **الوارد والصادر والرصيد لكل نوعٍ في يوم**.
///
/// ⛔⛔ **والإجمالياتُ ثلاثةُ أسطرٍ منفصلة** — ★ **وكلُّ سطرٍ يفصل الحبات
/// عن الأوزان بنفسه** (`GR-19`).
ReportTable buildCurrentStockReport({
  required CalendarDay stockDate,
  required List<ItemDailyBalanceCard> balances,
  StockAvailability? availability,
}) {
  final List<ItemDailyBalanceCard> visible = <ItemDailyBalanceCard>[
    for (final ItemDailyBalanceCard balance in balances)
      if (availability == null ||
          stockIsAvailable(balance.balance) ==
              (availability == StockAvailability.available))
        balance,
  ];
  return ReportTable(
    report: ReportId.currentStock,
    header: <ExportField>[
      ExportField('تاريخ المخزون', stockDate.formatReadable()),
      if (availability case final StockAvailability filter)
        ExportField('الحالة', filter.label),
    ],
    columns: const <ReportColumn>[
      ReportColumn('النوع'),
      ReportColumn('الوارد', numeric: true),
      ReportColumn('الصادر', numeric: true),
      ReportColumn('الرصيد', numeric: true),
    ],
    rows: <ReportRow>[
      for (final ItemDailyBalanceCard balance in visible)
        ReportRow(<String>[
          balance.itemName,
          formatQuantity(balance.incoming),
          formatQuantity(balance.outgoing),
          formatQuantity(balance.balance),
        ]),
    ],
    totals: <ExportField>[
      ExportField(
        'إجمالي الوارد',
        formatTotals(<StockQuantity>[
          for (final ItemDailyBalanceCard balance in visible) balance.incoming,
        ]),
      ),
      ExportField(
        'إجمالي الصادر',
        formatTotals(<StockQuantity>[
          for (final ItemDailyBalanceCard balance in visible) balance.outgoing,
        ]),
      ),
      ExportField(
        'إجمالي الرصيد',
        formatTotals(<StockQuantity>[
          for (final ItemDailyBalanceCard balance in visible) balance.balance,
        ]),
      ),
      ExportField('عدد الأنواع', '${visible.length}'),
    ],
  );
}

/// ★★ يبني `R-05` — **المتبقي وحده لكل نوعٍ في يوم**.
///
/// ⚠️ **ومصدرُه نفسُ مصدر `R-02`** — ★ **والفرقُ سؤالُهما:** «**ماذا جرى
/// اليوم؟**» مقابل «**ماذا بقي منه؟**»، ⟵ **فبناءُ أحدهما من الآخر بعمودٍ
/// مخفيّ كان يجعل تقريراً واحداً يجيب سؤالين** ⛔ **فلا يجيب أياً منهما.**
ReportTable buildTodayRemainderReport({
  required CalendarDay stockDate,
  required List<ItemDailyBalanceCard> balances,
}) =>
    ReportTable(
      report: ReportId.todayRemainder,
      header: <ExportField>[
        ExportField('تاريخ المخزون', stockDate.formatReadable()),
      ],
      columns: const <ReportColumn>[
        ReportColumn('النوع'),
        ReportColumn('المتبقي', numeric: true),
      ],
      rows: <ReportRow>[
        for (final ItemDailyBalanceCard balance in balances)
          ReportRow(<String>[
            balance.itemName,
            formatQuantity(balance.balance),
          ]),
      ],
      totals: <ExportField>[
        ExportField(
          'إجمالي المتبقي',
          formatTotals(<StockQuantity>[
            for (final ItemDailyBalanceCard balance in balances) balance.balance,
          ]),
        ),
        ExportField('عدد الأنواع', '${balances.length}'),
      ],
    );

// ═════════════════════════════════════════════════════════════════════════
// `R-03` — الوارد عدداً
// ═════════════════════════════════════════════════════════════════════════

/// ★★ يبني `R-03` — **مستنداتُ الوارد عدداً في الفترة**.
///
/// ⚠️ **والكمياتُ حبّاتٌ دائماً في هذه الوحدة** (`FR-M6`) — ⟵ **فلا سطرَ
/// أوزانٍ في إجمالياتها**، ★ **و[formatTotals] تكتبه «0.000 كجم» صراحةً**
/// ⛔ **ولا تحذفه**: ★ **فالصفرُ هنا معلومة** (`ui-guidelines.md` §3).
ReportTable buildCountedIntakesReport({
  required ReportPeriod period,
  required List<CountedIntakeCard> intakes,
  Map<String, String> supplierNames = const <String, String>{},
}) {
  final List<CountedIntakeCard> counted = <CountedIntakeCard>[
    for (final CountedIntakeCard intake in intakes)
      if (intake.status != CountedIntakeStatus.cancelled) intake,
  ];
  return ReportTable(
    report: ReportId.countedIntakes,
    header: <ExportField>[ExportField('الفترة', period.label)],
    columns: const <ReportColumn>[
      ReportColumn('تاريخ المخزون'),
      ReportColumn('رقم المستند'),
      ReportColumn('الرعوي'),
      ReportColumn('الإجمالي', numeric: true),
      ReportColumn('الحالة'),
    ],
    rows: <ReportRow>[
      for (final CountedIntakeCard intake in intakes)
        ReportRow(
          <String>[
            intake.stockDate.formatReadable(),
            intake.documentNumber,
            _supplierCell(intake.supplierId, supplierNames),
            formatQuantity(PieceQuantity(intake.totalQuantity)),
            intake.status == CountedIntakeStatus.cancelled ? 'ملغى' : 'معتمد',
          ],
          isCancelled: intake.status == CountedIntakeStatus.cancelled,
        ),
    ],
    totals: <ExportField>[
      ExportField(
        'إجمالي الوارد',
        formatTotals(<StockQuantity>[
          for (final CountedIntakeCard intake in counted)
            PieceQuantity(intake.totalQuantity),
        ]),
      ),
      ExportField('عدد المستندات', '${counted.length}'),
    ],
  );
}

// ═════════════════════════════════════════════════════════════════════════
// `R-04` — الوارد جواني
// ═════════════════════════════════════════════════════════════════════════

/// ★★ يبني `R-04` — **جواني الفترة بأوزانها**.
///
/// ⛔⛔★★ **والمطالبُ به محسوبٌ في النطاق** ([ValidatedSackWeights
/// .claimableWeight]) — ⛔ **ولا يُطرَح هنا من جديد**: ⟵ **ونسختان من
/// المعادلة تفترقان** (`coding-standards.md` §2.2).
///
/// ⛔ **ولا حقلَ ماليٍّ واحد هنا** — ★ **مالية الجونية في `finance/current`
/// بشرطِ قراءةٍ مستقل** (`ADR-0011` · `sackFinanceView`)، ⟵ **وتفكيكُ
/// سعرها تقريرٌ آخر** (`R-27` — **المرحلة الثانية**).
ReportTable buildSackIntakesReport({
  required ReportPeriod period,
  required List<SackCard> sacks,
}) {
  final List<SackCard> counted = <SackCard>[
    for (final SackCard sack in sacks)
      if (sack.status != SackStatus.cancelled) sack,
  ];
  return ReportTable(
    report: ReportId.sackIntakes,
    header: <ExportField>[ExportField('الفترة', period.label)],
    columns: const <ReportColumn>[
      ReportColumn('تاريخ المخزون'),
      ReportColumn('الجونية'),
      ReportColumn('الرعوي'),
      ReportColumn('الوزن الكلي', numeric: true),
      ReportColumn('الثلج', numeric: true),
      ReportColumn('السكرب', numeric: true),
      ReportColumn('المطالب به', numeric: true),
      ReportColumn('الحالة'),
    ],
    rows: <ReportRow>[
      for (final SackCard sack in sacks)
        ReportRow(
          <String>[
            sack.stockDate.formatReadable(),
            sack.displayName,
            sack.supplierName ?? 'بلا رعوي',
            formatQuantity(WeightQuantity(sack.weights.totalWeight)),
            formatQuantity(WeightQuantity(sack.weights.iceWeight)),
            formatQuantity(WeightQuantity(sack.weights.scrapWeight)),
            formatQuantity(WeightQuantity(sack.weights.claimableWeight)),
            sack.status == SackStatus.cancelled ? 'ملغاة' : 'معتمدة',
          ],
          isCancelled: sack.status == SackStatus.cancelled,
        ),
    ],
    totals: <ExportField>[
      ExportField(
        'إجمالي الوزن الكلي',
        formatTotals(<StockQuantity>[
          for (final SackCard sack in counted)
            WeightQuantity(sack.weights.totalWeight),
        ]),
      ),
      ExportField(
        'إجمالي المطالب به',
        formatTotals(<StockQuantity>[
          for (final SackCard sack in counted)
            WeightQuantity(sack.weights.claimableWeight),
        ]),
      ),
      ExportField('عدد الجواني', '${counted.length}'),
    ],
  );
}

// ═════════════════════════════════════════════════════════════════════════
// `R-08` — التوزيعات التفصيلية
// ═════════════════════════════════════════════════════════════════════════

/// ★★ يبني `R-08` — **توزيعاتُ الفترة بكمياتها**.
///
/// ⛔⛔★★★ **وعمودا الحبات والأوزان منفصلان ولا ثالثَ يجمعهما** (`GR-19` ·
/// `FR-M10-15`) — ★ **وهو نفسُ ما يفرضه ميزان شاشة التوزيع حرفياً.**
///
/// ⚠️⚠️ **ولا قيمةَ ضمارٍ هنا** — ★ **الأسعارُ في `pricing/current` بشرطِ
/// قراءةٍ مستقل** (`ADR-0011` · `ت-12`)، ⟵ **وقيمُ الضمارات تقريرُها
/// `R-10`** — ★ **وهناك تُقرأ لمن يملك `distributionPriceView` وحده.**
ReportTable buildDistributionsReport({
  required ReportPeriod period,
  required List<DistributionCard> distributions,
  Map<String, String> dealerNames = const <String, String>{},
}) {
  final List<DistributionCard> counted = <DistributionCard>[
    for (final DistributionCard card in distributions)
      if (card.status != DistributionStatus.cancelled) card,
  ];
  return ReportTable(
    report: ReportId.distributions,
    header: <ExportField>[ExportField('الفترة', period.label)],
    columns: const <ReportColumn>[
      ReportColumn('تاريخ المخزون'),
      ReportColumn('رقم المستند'),
      ReportColumn('المقوت'),
      ReportColumn('الحبات', numeric: true),
      ReportColumn('الأوزان', numeric: true),
      ReportColumn('الحالة'),
    ],
    rows: <ReportRow>[
      for (final DistributionCard card in distributions)
        ReportRow(
          <String>[
            card.stockDate.formatReadable(),
            card.documentNumber,
            dealerNames[card.dealerId] ?? card.dealerName,
            formatQuantity(PieceQuantity(card.totalPieces)),
            formatQuantity(WeightQuantity(card.totalWeight)),
            _distributionStatusLabel(card.status),
          ],
          isCancelled: card.status == DistributionStatus.cancelled,
        ),
    ],
    totals: <ExportField>[
      ExportField(
        'إجمالي الحبات',
        formatTotals(<StockQuantity>[
          for (final DistributionCard card in counted)
            PieceQuantity(card.totalPieces),
        ]),
      ),
      ExportField(
        'إجمالي الأوزان',
        formatTotals(<StockQuantity>[
          for (final DistributionCard card in counted)
            WeightQuantity(card.totalWeight),
        ]),
      ),
      ExportField('عدد التوزيعات', '${counted.length}'),
    ],
    // ★★ **مستنداتٌ بقيمٍ ناقصة = سطورٌ غير مسعَّرة** (`FR-M19-08` ·
    //    `FR-M10-08`) — ⛔ **ولا تقديرَ: العددُ من `unpricedLineCount`.**
    incompleteCount: counted
        .where((DistributionCard card) => card.hasUnpricedLines)
        .length,
  );
}

// ═════════════════════════════════════════════════════════════════════════
// `R-10` — الضمارات
// ═════════════════════════════════════════════════════════════════════════

/// ★★★ يبني `R-10` — **الضماراتُ بحالة تسويتها**.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **وعمودُ القيمة يظهر لمن يملك `distributionPriceView` وحدَه** —
/// ★ **و[pricing] فارغةٌ لغيره** (`ADR-0011` · `ت-12`): ⟵ **فالعمودُ لا
/// يُرسَم أصلاً** ⛔ **ولا يُرسَم فارغاً ولا بصفر** — ★ **وصفرٌ مكانَ مبلغٍ
/// محجوب يكذب، والفراغُ يبدو عطلاً** (`ui-guidelines.md` نمط 6).
///
/// ⚠️ **والحالةُ الغائبة تُكتب «غير معروفة»** ⛔ **ولا تُقرأ «مفتوح»**:
/// ⟵ **ضمارٌ مُصفّى يُعرَض مفتوحاً يُطالِب مقوتاً بما سدَّده.**
/// ═══════════════════════════════════════════════════════════════════════
ReportTable buildSettlementsReport({
  required ReportPeriod period,
  required List<DistributionCard> distributions,
  Map<String, DistributionPricingCard> pricing =
      const <String, DistributionPricingCard>{},
  Map<String, String> dealerNames = const <String, String>{},
  SettlementStatus? settlementStatus,
  String thousandsSeparator = ',',
}) {
  final bool withValue = pricing.isNotEmpty;
  final List<DistributionCard> counted = <DistributionCard>[
    for (final DistributionCard card in distributions)
      if (card.status != DistributionStatus.cancelled) card,
  ];
  Money total = Money.zero;
  for (final DistributionCard card in counted) {
    total = total + (pricing[card.distributionId]?.debtValue ?? Money.zero);
  }
  return ReportTable(
    report: ReportId.settlements,
    header: <ExportField>[
      ExportField('الفترة', period.label),
      if (settlementStatus case final SettlementStatus filter)
        ExportField('حالة التسوية', _settlementLabel(filter)),
    ],
    columns: <ReportColumn>[
      const ReportColumn('تاريخ المخزون'),
      const ReportColumn('رقم المستند'),
      const ReportColumn('المقوت'),
      const ReportColumn('حالة التسوية'),
      if (withValue) const ReportColumn('قيمة الضمار', numeric: true),
    ],
    rows: <ReportRow>[
      for (final DistributionCard card in distributions)
        ReportRow(
          <String>[
            card.stockDate.formatReadable(),
            card.documentNumber,
            dealerNames[card.dealerId] ?? card.dealerName,
            card.settlementStatus == null
                ? 'غير معروفة'
                : _settlementLabel(card.settlementStatus!),
            if (withValue)
              if (pricing[card.distributionId] case final DistributionPricingCard row)
                formatRiyals(row.debtValue, thousandsSeparator: thousandsSeparator)
              else
                'غير مسعَّر',
          ],
          isCancelled: card.status == DistributionStatus.cancelled,
        ),
    ],
    totals: <ExportField>[
      if (withValue)
        ExportField(
          'إجمالي الضمارات',
          formatRiyals(total, thousandsSeparator: thousandsSeparator),
        ),
      ExportField('عدد الضمارات', '${counted.length}'),
    ],
    incompleteCount: counted
        .where((DistributionCard card) => card.hasUnpricedLines)
        .length,
  );
}

// ═════════════════════════════════════════════════════════════════════════
// `R-14` — المقبوضات
// ═════════════════════════════════════════════════════════════════════════

/// ★★★ يبني `R-14` — **سنداتُ القبض في الفترة**.
///
/// ⛔⛔★★★ **والمبلغُ المعروض هو المنسوبُ لمصدر التقرير وحدَه**
/// ([receiptAmountForSource]) — `FR-M19-02`: ⟵ **فسندٌ يمسّ ثلاثة مصادر لا
/// يُظهر في تقرير أحدها ما سُدِّد للآخرَين.**
///
/// ⚠️ **وعمودُ الإيداع يظهر لمن يملك `receiptDepositView` وحدَه**
/// ([deposits] فارغةٌ لغيره) — `ADR-0017` · `FR-M12-16`.
ReportTable buildReceiptsReport({
  required ReportPeriod period,
  required List<ReceiptCard> receipts,
  String? sourceId,
  Map<String, DepositState> deposits = const <String, DepositState>{},
  DepositState? depositFilter,
  String thousandsSeparator = ',',
}) {
  final bool withDeposit = deposits.isNotEmpty;
  final List<ReceiptCard> visible = <ReceiptCard>[
    for (final ReceiptCard receipt in receipts)
      if (depositFilter == null ||
          deposits[receipt.documentNumber] == depositFilter)
        receipt,
  ];
  Money total = Money.zero;
  for (final ReceiptCard receipt in visible) {
    if (receipt.isCancelled) continue;
    total = total + receiptAmountForSource(receipt, sourceId);
  }
  return ReportTable(
    report: ReportId.receipts,
    header: <ExportField>[
      ExportField('الفترة', period.label),
      if (depositFilter case final DepositState filter)
        ExportField('حالة الإيداع البنكي', _depositLabel(filter)),
    ],
    columns: <ReportColumn>[
      const ReportColumn('التاريخ'),
      const ReportColumn('رقم السند'),
      const ReportColumn('المقوت'),
      const ReportColumn('المقبوض', numeric: true),
      if (withDeposit) const ReportColumn('الإيداع البنكي'),
      const ReportColumn('الحالة'),
    ],
    rows: <ReportRow>[
      for (final ReceiptCard receipt in visible)
        ReportRow(
          <String>[
            receipt.date.formatReadable(),
            receipt.documentNumber,
            receipt.dealerName,
            formatRiyals(
              receiptAmountForSource(receipt, sourceId),
              thousandsSeparator: thousandsSeparator,
            ),
            if (withDeposit)
              _depositLabel(
                deposits[receipt.documentNumber] ?? DepositState.notDeposited,
              ),
            receipt.isCancelled ? 'ملغى' : 'معتمد',
          ],
          isCancelled: receipt.isCancelled,
        ),
    ],
    totals: <ExportField>[
      ExportField(
        'إجمالي المقبوض',
        formatRiyals(total, thousandsSeparator: thousandsSeparator),
      ),
      ExportField(
        'عدد السندات',
        '${visible.where((ReceiptCard r) => !r.isCancelled).length}',
      ),
    ],
  );
}

// ═════════════════════════════════════════════════════════════════════════
// `R-17` — أرصدة المقاوته
// ═════════════════════════════════════════════════════════════════════════

/// ★★ يبني `R-17` — **أرصدةُ المقاوته في المصدر**.
///
/// ⚠️⚠️ **والرصيدُ السالب يُعرَض بإشارته** — ⛔ **ولا يُطوى إلى صفر**:
/// ★ **معناه «للمقوت عندنا»** (`formatRiyals`)، ⟵ **وطيُّه يُخفي التزاماً.**
ReportTable buildDealerBalancesReport({
  required List<DealerBalanceCard> balances,
  Map<String, String> dealerNames = const <String, String>{},
  DealerBalanceState? state,
  Money? minimumBalance,
  String thousandsSeparator = ',',
}) {
  final List<DealerBalanceCard> visible = <DealerBalanceCard>[
    for (final DealerBalanceCard card in balances)
      if (_balanceMatches(card, state, minimumBalance)) card,
  ];
  Money total = Money.zero;
  for (final DealerBalanceCard card in visible) {
    total = total + card.balance.balance;
  }
  return ReportTable(
    report: ReportId.dealerBalances,
    header: <ExportField>[
      if (state case final DealerBalanceState filter)
        ExportField('الحالة', filter.label),
      if (minimumBalance case final Money floor)
        ExportField(
          'الحد الأدنى للرصيد',
          formatRiyals(floor, thousandsSeparator: thousandsSeparator),
        ),
    ],
    columns: const <ReportColumn>[
      ReportColumn('المقوت'),
      ReportColumn('مدين', numeric: true),
      ReportColumn('دائن', numeric: true),
      ReportColumn('الرصيد', numeric: true),
    ],
    rows: <ReportRow>[
      for (final DealerBalanceCard card in visible)
        ReportRow(<String>[
          dealerNames[card.dealerId] ?? card.dealerId,
          formatRiyals(
            card.balance.totalDebit,
            thousandsSeparator: thousandsSeparator,
          ),
          formatRiyals(
            card.balance.totalCredit,
            thousandsSeparator: thousandsSeparator,
          ),
          formatRiyals(
            card.balance.balance,
            thousandsSeparator: thousandsSeparator,
          ),
        ]),
    ],
    totals: <ExportField>[
      ExportField(
        'إجمالي الأرصدة',
        formatRiyals(total, thousandsSeparator: thousandsSeparator),
      ),
      ExportField('عدد المقاوته', '${visible.length}'),
    ],
  );
}

// ═════════════════════════════════════════════════════════════════════════
// `R-19` — كشف حساب مقوت
// ═════════════════════════════════════════════════════════════════════════

/// ★★★ يبني `R-19` — **كشفُ حسابٍ مرتَّبٌ تصاعدياً بالرصيد بعد كل حركة**.
///
/// ⛔⛔★★ **والترتيبُ تصاعديٌّ هنا بخلاف بقية التقارير** — ★ **لأن الكشف
/// يُقرأ سلسلةً**: ⟵ **والرصيدُ الختامي هو رصيدُ آخر حركة**، ⛔ **وترتيبٌ
/// تنازلي كان يجعل «الرصيد بعد الحركة» يهبط كلما نزل القارئ.**
///
/// ⚠️ **والملغى يُعرَض ولا يدخل الإجماليات** (`A-14`).
ReportTable buildDealerStatementReport({
  required ReportPeriod period,
  required String dealerName,
  required List<DealerLedgerRowCard> entries,
  String thousandsSeparator = ',',
}) {
  final List<DealerLedgerRowCard> ordered = <DealerLedgerRowCard>[...entries]
    ..sort(_byEntryDate);
  final List<DealerLedgerRowCard> counted = <DealerLedgerRowCard>[
    for (final DealerLedgerRowCard entry in ordered)
      if (!entry.isCancelled) entry,
  ];
  Money debit = Money.zero;
  Money credit = Money.zero;
  // ⛔⛔★★★ **والرصيدُ الجاري يُشتقّ هنا من الدفتر** (`ADR-0008`) — ⛔ **ولا
  //    يُقرأ حقلاً مخزَّناً في القيد:** ⛅ **كاتبُ التوزيع يكتبه وكاتبُ القبض
  //    لا يكتبه** ([`receipt.dart`](../../../../../../functions/lib/src/receipt.dart))،
  //    ⟵ **فكان كلُّ قيدِ قبضٍ يُقرأ صفراً** ⟹ **و«الرصيد الختامي» صفراً
  //    بينما المدين ناقصَ الدائن 49,800** (`DEBT-75` · **قِيس على المحاكي**).
  final Map<String, Money> runningBalance = <String, Money>{};
  Money running = Money.zero;
  for (final DealerLedgerRowCard entry in counted) {
    if (entry.direction == DealerLedgerDirection.debit) {
      debit = debit + entry.amount;
      running = running + entry.amount;
    } else {
      credit = credit + entry.amount;
      running = running - entry.amount;
    }
    runningBalance[entry.entryId] = running;
  }
  return ReportTable(
    report: ReportId.dealerStatement,
    header: <ExportField>[
      ExportField('الفترة', period.label),
      ExportField('المقوت', dealerName),
    ],
    columns: const <ReportColumn>[
      ReportColumn('تاريخ الإدخال'),
      ReportColumn('البيان'),
      ReportColumn('المستند'),
      ReportColumn('مدين', numeric: true),
      ReportColumn('دائن', numeric: true),
      ReportColumn('الرصيد بعد الحركة', numeric: true),
    ],
    rows: <ReportRow>[
      for (final DealerLedgerRowCard entry in ordered)
        ReportRow(
          <String>[
            _instantCell(entry.entryDate),
            _entryTypeLabel(entry.entryType),
            entry.sourceDocNumber ?? 'بلا مستند',
            entry.direction == DealerLedgerDirection.debit
                ? formatRiyals(
                    entry.amount,
                    thousandsSeparator: thousandsSeparator,
                  )
                : '',
            entry.direction == DealerLedgerDirection.credit
                ? formatRiyals(
                    entry.amount,
                    thousandsSeparator: thousandsSeparator,
                  )
                : '',
            // ★ **والملغى لا يُحرِّك الرصيد** — ⛔ **فلا يُنسَب له رقم**
            //   (`A-14`): ⟵ **وشرطةٌ أصدقُ من رقمٍ لا معنى له.**
            if (runningBalance[entry.entryId] case final Money balance)
              formatRiyals(balance, thousandsSeparator: thousandsSeparator)
            else
              '—',
          ],
          isCancelled: entry.isCancelled,
        ),
    ],
    totals: <ExportField>[
      ExportField(
        'إجمالي المدين',
        formatRiyals(debit, thousandsSeparator: thousandsSeparator),
      ),
      ExportField(
        'إجمالي الدائن',
        formatRiyals(credit, thousandsSeparator: thousandsSeparator),
      ),
      ExportField(
        'الرصيد الختامي',
        formatRiyals(
          running,
          thousandsSeparator: thousandsSeparator,
        ),
      ),
      ExportField('عدد الحركات', '${counted.length}'),
    ],
  );
}

// ═════════════════════════════════════════════════════════════════════════
// `R-28` — الإدخالات المعلّقة
// ═════════════════════════════════════════════════════════════════════════

/// ★★ يبني `R-28` — **بنودُ المركز المعلّق في الفترة**.
///
/// ⚠️⚠️ **وهو تقريرٌ يُلاحق ولا يمنع** (`GR-50` · `FR-SYS-06`) — ★ **كشاشته
/// حرفياً**: ⟵ **ولا شيء فيه يوقف حفظاً ولا تصديراً.**
ReportTable buildPendingEntriesReport({
  required ReportPeriod period,
  required List<PendingEntryCard> entries,
  PendingDocumentKind? kind,
}) {
  final List<PendingEntryCard> visible = <PendingEntryCard>[
    for (final PendingEntryCard entry in entries)
      if (kind == null || entry.kind == kind) entry,
  ];
  return ReportTable(
    report: ReportId.pendingEntries,
    header: <ExportField>[
      ExportField('الفترة', period.label),
      if (kind case final PendingDocumentKind filter)
        ExportField('نوع المستند', filter.label),
    ],
    columns: const <ReportColumn>[
      ReportColumn('التاريخ'),
      ReportColumn('المستند'),
      ReportColumn('رقم المستند'),
      ReportColumn('القيمة الناقصة'),
    ],
    rows: <ReportRow>[
      for (final PendingEntryCard entry in visible)
        ReportRow(<String>[
          _dayCell(entry.date),
          entry.readableTitle,
          entry.documentNumber ?? 'بلا رقم',
          entry.missingField,
        ]),
    ],
    totals: <ExportField>[
      ExportField('عدد البنود المعلّقة', '${visible.length}'),
    ],
    // ★★ **وكلُّ بندٍ هنا قيمةٌ ناقصة بتعريفه** — `FR-SYS-01`:
    //    ⟵ **فعدُّها هو نفسُه تحذيرُ `FR-M19-08`** ⛔ **لا حسابٌ ثانٍ.**
    incompleteCount: visible.length,
  );
}

// ═════════════════════════════════════════════════════════════════════════
// نصوصُ الخلايا — ★ **مبنيّةٌ مرةً واحدة** ⛔ **ولا تُكرَّر في شاشة**
// ═════════════════════════════════════════════════════════════════════════

String _dayCell(CalendarDay? day) =>
    day == null ? 'بلا تاريخ' : day.formatReadable();

String _instantCell(DateTime? instant) => instant == null
    ? 'بلا تاريخ'
    : CalendarDay.fromUtc(instant.toUtc()).formatReadable();

String _directionLabel(MovementDirection direction) =>
    switch (direction) {
      MovementDirection.incoming => 'وارد',
      MovementDirection.outgoing => 'صادر',
    };

/// ★ حالةُ الحركة — **ملغاة أو مُعدَّلة أو عادية**.
///
/// ⛔ **ولا تُترك فارغة** — ★ **الفراغُ يُقرأ عطلاً**، ⟵ **و«عادية» تقول
/// إن الحركة فُحصت** (`ui-guidelines.md` §6).
String _movementStateLabel(StockMovementCard movement) {
  if (movement.isCancelled) return 'ملغاة';
  return movement.isAmended ? 'مُعدَّلة' : 'عادية';
}

String _distributionStatusLabel(DistributionStatus status) => switch (status) {
      DistributionStatus.approved => 'معتمدة',
      DistributionStatus.partiallyPriced => 'مسعَّرة جزئياً',
      DistributionStatus.priced => 'مسعَّرة',
      DistributionStatus.cancelled => 'ملغاة',
    };

String _settlementLabel(SettlementStatus status) => switch (status) {
      SettlementStatus.open => 'مفتوح',
      SettlementStatus.partiallyOpen => 'مفتوح جزئياً',
      SettlementStatus.closed => 'مغلق',
    };

String _depositLabel(DepositState state) => switch (state) {
      DepositState.notDeposited => 'لم يُودع',
      DepositState.deposited => 'أُودع',
    };

/// ★ بيانُ قيد دفتر المقاوته — ⛔ **والمجهول يُسمّى مجهولاً**.
///
/// ⚠️ **ولا يُقرأ «ضماراً» احتياطاً** — ★ **قيدٌ من إصدارٍ أحدث يُعرَض
/// باسمه الصحيح أو بلا اسم**، ⛔ **لا باسمٍ خاطئ يكذب على المدقّق.**
String _entryTypeLabel(DealerLedgerEntryType? type) => switch (type) {
      DealerLedgerEntryType.debt => 'ضمار',
      DealerLedgerEntryType.receipt => 'قبض',
      DealerLedgerEntryType.surplusApplication => 'تطبيق فائض',
      null => 'قيد غير معروف',
    };

String _supplierCell(String? supplierId, Map<String, String> names) {
  if (supplierId == null) return 'بلا رعوي';
  return names[supplierId] ?? supplierId;
}

/// ★ ترتيبٌ تصاعديٌّ بتاريخ الإدخال — **والغائبُ أقدمُ ما يكون**.
///
/// ⛔ **ولا يُسقَط القيد الغائبُ طابعُه** — ★ **يقع في رأس الكشف موسوماً**،
/// ⟵ **واختفاؤه كان يُخفي حركةً من حساب مقوت.**
int _byEntryDate(DealerLedgerRowCard a, DealerLedgerRowCard b) =>
    (a.entryDate ?? DateTime.utc(1970))
        .compareTo(b.entryDate ?? DateTime.utc(1970));

bool _balanceMatches(
  DealerBalanceCard card,
  DealerBalanceState? state,
  Money? minimumBalance,
) {
  final Money balance = card.balance.balance;
  if (state == DealerBalanceState.settled && !balance.isZero) return false;
  if (state == DealerBalanceState.outstanding && balance.isZero) return false;
  if (minimumBalance != null && balance < minimumBalance) return false;
  return true;
}

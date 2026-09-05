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
import '../../financial_outflow/domain/outflow.dart';
import '../../financial_outflow/domain/outflow_repository.dart';
import '../../financial_outflow/domain/owner_ledger_summary.dart';
import '../../inventory/domain/counted_intake.dart';
import '../../inventory/domain/disposal_repository.dart';
import '../../inventory/domain/inventory.dart';
import '../../inventory/domain/inventory_repository.dart';
import '../../inventory/domain/sack_intake.dart';
import '../../inventory/domain/sack_intake_repository.dart';
import '../../inventory/domain/sack_valuation.dart';
import '../../inventory/domain/sack_valuation_repository.dart';
import '../../sales_receivables/domain/cash_sale.dart';
import '../../sales_receivables/domain/cash_sale_repository.dart';
import '../../sales_receivables/domain/discount_repository.dart';
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
  String? itemKey,
  String? itemName,
}) {
  final List<ItemDailyBalanceCard> visible = <ItemDailyBalanceCard>[
    for (final ItemDailyBalanceCard balance in balances)
      if ((availability == null ||
              stockIsAvailable(balance.balance) ==
                  (availability == StockAvailability.available)) &&
          (itemKey == null || balance.itemKey == itemKey))
        balance,
  ];
  return ReportTable(
    report: ReportId.currentStock,
    header: <ExportField>[
      ExportField('تاريخ المخزون', stockDate.formatReadable()),
      if (availability case final StockAvailability filter)
        ExportField('الحالة', filter.label),
      // ⛔⛔★★ **والفلترُ يُصرِّح بنفسه ولو لم يبقَ صفٌّ واحد** — ★ **وإلا
      //   قُرئ الفراغُ عطلاً** (`ui-guidelines.md` §6): ⟵ **والاسمُ يصل
      //   جاهزاً من المزوّد** ⛔ **ولا يُعرَض مفتاحٌ تقني مكانه.**
      if (itemKey != null)
        ExportField(
          'النوع',
          itemName ?? (visible.isEmpty ? itemKey : visible.first.itemName),
        ),
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
  String? itemKey,
  String? itemName,
}) {
  final List<ItemDailyBalanceCard> visible = <ItemDailyBalanceCard>[
    for (final ItemDailyBalanceCard balance in balances)
      if (itemKey == null || balance.itemKey == itemKey) balance,
  ];
  return ReportTable(
    report: ReportId.todayRemainder,
    header: <ExportField>[
      ExportField('تاريخ المخزون', stockDate.formatReadable()),
      // ⛔⛔ **ويُصرِّح بنفسه ولو خلا الجدول** — راجع [buildCurrentStockReport].
      if (itemKey != null)
        ExportField(
          'النوع',
          itemName ?? (visible.isEmpty ? itemKey : visible.first.itemName),
        ),
    ],
    columns: const <ReportColumn>[
      ReportColumn('النوع'),
      ReportColumn('المتبقي', numeric: true),
    ],
    rows: <ReportRow>[
      for (final ItemDailyBalanceCard balance in visible)
        ReportRow(<String>[
          balance.itemName,
          formatQuantity(balance.balance),
        ]),
    ],
    totals: <ExportField>[
      ExportField(
        'إجمالي المتبقي',
        formatTotals(<StockQuantity>[
          for (final ItemDailyBalanceCard balance in visible) balance.balance,
        ]),
      ),
      ExportField('عدد الأنواع', '${visible.length}'),
    ],
  );
}

// ═════════════════════════════════════════════════════════════════════════
// `R-07` — الوزن الضائع والسكرب والإتلاف (`WU-020`)
// ═════════════════════════════════════════════════════════════════════════

/// ★★★ يبني `R-07` — **ثلاثةُ بنودٍ يجمعها أنها خروجٌ بلا استحقاق**.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **وما يجمعها قاعدةٌ واحدة لا تصنيفٌ شكليّ** (`A-15` ·
/// `design-overview.md` §2.2): ★ **الوزنُ الضائع والسكربُ والإتلاف ثلاثتُها
/// تخرج من الجونية أو المخزن ⛔ بلا أن يستحق الرعوي ثمنَها ولا أن تدخل سعرَ
/// الجونية** — ⟵ **ولذلك جمعها `FR-M19` §2 في تقريرٍ واحد بعنوانه هذا.**
///
/// ★★ **والوزنُ الضائع صفرٌ ما لم يُؤكَّد صراحةً** (`BR-M7-12` · `FR-M7-19`)
/// — ⛔ **ولا يُشتقّ من المتبقي هنا**: ⟵ **[SackWeightExplanation.lostWeight]
/// هي الدالةُ الوحيدة الحاكمة**، ⛔ **ولا يُعاد بناء الشرط في تقرير.**
///
/// ⛔⛔★★ **والملغى يُعرَض ولا يدخل إجمالياً** (`A-14`) — ★ **جونيةً كان أو
/// مستندَ إتلاف.**
///
/// ⚠️ **وفلترُ الرعوي على الجونية وحدها** — ★ **ومستندُ الإتلاف لا رعويَّ
/// له** (`data-dictionary.md` §`disposals`): ⟵ **فيُستبعَد كلُّه متى فُلتِر
/// برعويّ**، ⛔ **ولا يُنسَب لرعويٍّ بالتخمين من جونيته.**
/// ═══════════════════════════════════════════════════════════════════════
ReportTable buildWasteAndDisposalReport({
  required ReportPeriod period,
  required List<SackCard> sacks,
  required List<DisposalCard> disposals,
  Map<String, String> supplierNames = const <String, String>{},
  String? supplierId,
}) {
  final List<SackCard> visibleSacks = <SackCard>[
    for (final SackCard sack in sacks)
      if (supplierId == null || sack.supplierId == supplierId) sack,
  ];
  // ★ **ومستندُ الإتلاف لا رعويَّ له** — راجع ترويسة الدالة.
  final List<DisposalCard> visibleDisposals = <DisposalCard>[
    if (supplierId == null) ...disposals,
  ];

  final List<ReportRow> rows = <ReportRow>[];
  final List<StockQuantity> lostTotals = <StockQuantity>[];
  final List<StockQuantity> scrapTotals = <StockQuantity>[];
  final List<StockQuantity> disposedPieces = <StockQuantity>[];
  final List<StockQuantity> disposedWeights = <StockQuantity>[];

  for (final SackCard sack in visibleSacks) {
    final bool cancelled = sack.status == SackStatus.cancelled;
    if (sack.explanation.lostWeight.kilograms > 0) {
      rows.add(
        ReportRow(
          <String>[
            sack.stockDate.formatReadable(),
            'وزن ضائع',
            sack.displayName,
            sack.supplierName ?? 'بلا رعوي',
            formatQuantity(WeightQuantity(sack.explanation.lostWeight)),
            sack.lostWeightNote ?? '—',
          ],
          isCancelled: cancelled,
        ),
      );
      if (!cancelled) {
        lostTotals.add(WeightQuantity(sack.explanation.lostWeight));
      }
    }
    if (sack.weights.scrapWeight.kilograms > 0) {
      rows.add(
        ReportRow(
          <String>[
            sack.stockDate.formatReadable(),
            'سكرب',
            sack.displayName,
            sack.supplierName ?? 'بلا رعوي',
            formatQuantity(WeightQuantity(sack.weights.scrapWeight)),
            '—',
          ],
          isCancelled: cancelled,
        ),
      );
      if (!cancelled) {
        scrapTotals.add(WeightQuantity(sack.weights.scrapWeight));
      }
    }
  }

  for (final DisposalCard disposal in visibleDisposals) {
    for (final DisposalCardLine line in disposal.lines) {
      rows.add(
        ReportRow(
          <String>[
            disposal.stockDate.formatReadable(),
            'إتلاف',
            line.itemName,
            disposal.documentNumber,
            formatQuantity(line.quantity),
            disposal.reason ?? '—',
          ],
          isCancelled: disposal.isCancelled,
        ),
      );
      if (disposal.isCancelled) continue;
      switch (line.quantity) {
        case PieceQuantity():
          disposedPieces.add(line.quantity);
        case WeightQuantity():
          disposedWeights.add(line.quantity);
      }
    }
  }

  return ReportTable(
    report: ReportId.wasteAndDisposal,
    header: <ExportField>[
      ExportField('الفترة', period.label),
      if (supplierId case final String supplier)
        ExportField('الرعوي', supplierNames[supplier] ?? supplier),
    ],
    columns: const <ReportColumn>[
      ReportColumn('تاريخ المخزون'),
      ReportColumn('البند'),
      ReportColumn('الجونية أو النوع'),
      ReportColumn('الرعوي أو المستند'),
      ReportColumn('الكمية', numeric: true),
      ReportColumn('البيان'),
    ],
    rows: rows,
    totals: <ExportField>[
      ExportField('إجمالي الوزن الضائع', formatTotals(lostTotals)),
      ExportField('إجمالي السكرب', formatTotals(scrapTotals)),
      // ⛔⛔★★ **وإجمالياً الإتلاف منفصلان** — `GR-19` · `E-31`: ⟵ **فالمُتلَف
      //    قد يكون حبّاتٍ وقد يكون وزناً**، ⛔ **ولا يُجمعان.**
      ExportField(
        'إجمالي المُتلَف',
        formatTotals(<StockQuantity>[...disposedPieces, ...disposedWeights]),
      ),
      ExportField('عدد بنود الإتلاف', '${disposedPieces.length + disposedWeights.length}'),
    ],
  );
}

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
  String? supplierId,
  String? itemKey,
  String? itemName,
}) {
  // ★★ **وفلترا الرعوي والنوع محليّان** ([`DEBT-72`] ① و④) — ⛔ **بلا
  //    استعلامٍ جديد ولا فهرسٍ ثالث**: ⟵ **المستندُ يحمل `supplierId`
  //    وسطورُه تحمل النوع**، ★ **والصفحةُ مقروءةٌ أصلاً.**
  final List<CountedIntakeCard> visible = <CountedIntakeCard>[
    for (final CountedIntakeCard intake in intakes)
      if ((supplierId == null || intake.supplierId == supplierId) &&
          (itemKey == null || _intakeHasItem(intake, itemKey)))
        intake,
  ];
  final List<CountedIntakeCard> counted = <CountedIntakeCard>[
    for (final CountedIntakeCard intake in visible)
      if (intake.status != CountedIntakeStatus.cancelled) intake,
  ];
  return ReportTable(
    report: ReportId.countedIntakes,
    header: <ExportField>[
      ExportField('الفترة', period.label),
      if (supplierId case final String supplier)
        ExportField('الرعوي', supplierNames[supplier] ?? supplier),
      if (itemKey case final String item)
        ExportField('النوع', itemName ?? item),
    ],
    columns: const <ReportColumn>[
      ReportColumn('تاريخ المخزون'),
      ReportColumn('رقم المستند'),
      ReportColumn('الرعوي'),
      ReportColumn('الإجمالي', numeric: true),
      ReportColumn('الحالة'),
    ],
    rows: <ReportRow>[
      for (final CountedIntakeCard intake in visible)
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
  Map<String, String> supplierNames = const <String, String>{},
  String? supplierId,
  String? sackId,
}) {
  // ★★ **وفلترا الرعوي والجونية محليّان** ([`DEBT-72`] ① و②) — ⛔ **بلا
  //    استعلامٍ جديد**: ⟵ **الجونيةُ نفسُها في الصفحة المقروءة.**
  final List<SackCard> visible = <SackCard>[
    for (final SackCard sack in sacks)
      if ((supplierId == null || sack.supplierId == supplierId) &&
          (sackId == null || sack.documentNumber == sackId))
        sack,
  ];
  final List<SackCard> counted = <SackCard>[
    for (final SackCard sack in visible)
      if (sack.status != SackStatus.cancelled) sack,
  ];
  return ReportTable(
    report: ReportId.sackIntakes,
    header: <ExportField>[
      ExportField('الفترة', period.label),
      if (supplierId case final String supplier)
        ExportField('الرعوي', supplierNames[supplier] ?? supplier),
      if (sackId != null && visible.isNotEmpty)
        ExportField('الجونية', visible.first.displayName),
    ],
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
      for (final SackCard sack in visible)
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
  String? dealerId,
}) {
  // ★★ **وفلترُ المقوت محليّ** ([`DEBT-72`] ③) — ⛔ **بلا فهرسٍ ثالث:**
  //    ⟵ **`dealerId ↑ · stockDate ↓` قائمٌ لكنه بلا `sourceId`**،
  //    ⛔ **واستعلامٌ به وحدَه يُرفَض** (`storedInScope()` — `IQ-024`).
  final List<DistributionCard> visible = <DistributionCard>[
    for (final DistributionCard card in distributions)
      if (dealerId == null || card.dealerId == dealerId) card,
  ];
  final List<DistributionCard> counted = <DistributionCard>[
    for (final DistributionCard card in visible)
      if (card.status != DistributionStatus.cancelled) card,
  ];
  return ReportTable(
    report: ReportId.distributions,
    header: <ExportField>[
      ExportField('الفترة', period.label),
      if (dealerId case final String dealer)
        ExportField('المقوت', dealerNames[dealer] ?? dealer),
    ],
    columns: const <ReportColumn>[
      ReportColumn('تاريخ المخزون'),
      ReportColumn('رقم المستند'),
      ReportColumn('المقوت'),
      ReportColumn('الحبات', numeric: true),
      ReportColumn('الأوزان', numeric: true),
      ReportColumn('الحالة'),
    ],
    rows: <ReportRow>[
      for (final DistributionCard card in visible)
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
  String? dealerId,
  String thousandsSeparator = ',',
}) {
  final bool withValue = pricing.isNotEmpty;
  // ★★ **وفلترُ المقوت محليّ** ([`DEBT-72`] ③) — راجع [buildDistributionsReport].
  final List<DistributionCard> visible = <DistributionCard>[
    for (final DistributionCard card in distributions)
      if (dealerId == null || card.dealerId == dealerId) card,
  ];
  final List<DistributionCard> counted = <DistributionCard>[
    for (final DistributionCard card in visible)
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
      if (dealerId case final String dealer)
        ExportField('المقوت', dealerNames[dealer] ?? dealer),
    ],
    columns: <ReportColumn>[
      const ReportColumn('تاريخ المخزون'),
      const ReportColumn('رقم المستند'),
      const ReportColumn('المقوت'),
      const ReportColumn('حالة التسوية'),
      if (withValue) const ReportColumn('قيمة الضمار', numeric: true),
    ],
    rows: <ReportRow>[
      for (final DistributionCard card in visible)
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
// ★★★ زيادةُ `WU-018` — تقاريرُ المرحلة الثانية (أربعةَ عشرَ تقريراً)
// ═════════════════════════════════════════════════════════════════════════

/// ★★ **مبلغُ سند خصمٍ المنسوبُ لمصدرٍ بعينه** — `FR-M19-02` (`GR-23`).
///
/// ⛔⛔★★★ **ونظيرُ [receiptAmountForSource] حرفياً وللعلّة نفسِها:**
/// ★ **سندُ الخصم يمسّ عدة مصادر** (`affectedSourceIds` — `FR-M13-01`)،
/// ⟵ **وعرضُ إجماليه في تقرير مصدرٍ واحد يُظهر رقماً من مصدرٍ خارج نطاق
/// القارئ** ⛔ **وهو نصُّ `FR-M19-02` الحرِج.**
///
/// ⛔ **ولا فائضَ هنا أصلاً** — ★ **`FR-M13-05`: لا حقلَ فائضٍ في سند الخصم**،
/// ⟵ **فالجمعُ سطورٌ لا غير** (بخلاف سند القبض).
Money discountAmountForSource(DiscountCard discount, String? sourceId) {
  Money total = Money.zero;
  for (final DiscountCardLine line in discount.lines) {
    if (sourceId != null && line.sourceId != sourceId) continue;
    total = total + line.amount;
  }
  return total;
}

// ═════════════════════════════════════════════════════════════════════════
// `R-09` — ملخص التوزيع لكل مقوت
// ═════════════════════════════════════════════════════════════════════════

/// ★★ يبني `R-09` — **صفٌّ لكل مقوت بكمياته وقيمة ضماراته في الفترة**.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★ **والملغاةُ لا تدخل صفّاً مجمَّعاً ولا تُعرَض فيه** — ★ **وهذا
/// فارقُ التقرير المجمَّع عن التفصيلي** (`A-14`): ⟵ **الصفُّ هنا مجموعُ عدة
/// مستندات فلا يُشطَب**، ⛔ **ولو دخلت أفسدت رقماً بلا أن يظهر شطبٌ يفسّره.**
/// ★ **وعددُها يُعلَن في الترويسة صراحةً** — ⟵ **فالاستبعادُ مقروءٌ لا مكتوم.**
///
/// ⛔⛔★★★ **وعمودُ القيمة لمن يملك `distributionPriceView` وحدَه** —
/// ★ **بنفس [buildSettlementsReport] حرفياً** (`ADR-0011` · `ت-12`).
/// ═══════════════════════════════════════════════════════════════════════
ReportTable buildDealerDistributionSummaryReport({
  required ReportPeriod period,
  required List<DistributionCard> distributions,
  Map<String, DistributionPricingCard> pricing =
      const <String, DistributionPricingCard>{},
  Map<String, String> dealerNames = const <String, String>{},
  String thousandsSeparator = ',',
}) {
  final bool withValue = pricing.isNotEmpty;
  final List<DistributionCard> counted = <DistributionCard>[
    for (final DistributionCard card in distributions)
      if (card.status != DistributionStatus.cancelled) card,
  ];
  final Map<String, _DealerRollup> byDealer = <String, _DealerRollup>{};
  for (final DistributionCard card in counted) {
    final _DealerRollup rollup = byDealer.putIfAbsent(
      card.dealerId,
      () => _DealerRollup(dealerNames[card.dealerId] ?? card.dealerName),
    );
    rollup.documents++;
    rollup.pieces = rollup.pieces + card.totalPieces;
    rollup.weight = rollup.weight + card.totalWeight;
    rollup.value =
        rollup.value + (pricing[card.distributionId]?.debtValue ?? Money.zero);
    if (card.hasUnpricedLines) rollup.unpricedDocuments++;
  }
  final List<_DealerRollup> ordered = <_DealerRollup>[...byDealer.values]
    ..sort((_DealerRollup a, _DealerRollup b) => a.name.compareTo(b.name));
  Money total = Money.zero;
  for (final _DealerRollup rollup in ordered) {
    total = total + rollup.value;
  }
  final int cancelled = distributions.length - counted.length;

  return ReportTable(
    report: ReportId.dealerDistributionSummary,
    header: <ExportField>[
      ExportField('الفترة', period.label),
      // ★ **والمستبعَدُ يُعلَن** — ⛔ **ولا يختفي بلا أثر** (`A-14`).
      if (cancelled > 0) ExportField('مستندات ملغاة مستبعَدة', '$cancelled'),
    ],
    columns: <ReportColumn>[
      const ReportColumn('المقوت'),
      const ReportColumn('عدد التوزيعات', numeric: true),
      const ReportColumn('الحبات', numeric: true),
      const ReportColumn('الأوزان', numeric: true),
      if (withValue) const ReportColumn('قيمة الضمارات', numeric: true),
    ],
    rows: <ReportRow>[
      for (final _DealerRollup rollup in ordered)
        ReportRow(<String>[
          rollup.name,
          '${rollup.documents}',
          formatQuantity(PieceQuantity(rollup.pieces)),
          formatQuantity(WeightQuantity(rollup.weight)),
          if (withValue)
            formatRiyals(rollup.value, thousandsSeparator: thousandsSeparator),
        ]),
    ],
    totals: <ExportField>[
      ExportField(
        'إجمالي الحبات',
        formatTotals(<StockQuantity>[
          for (final _DealerRollup rollup in ordered)
            PieceQuantity(rollup.pieces),
        ]),
      ),
      ExportField(
        'إجمالي الأوزان',
        formatTotals(<StockQuantity>[
          for (final _DealerRollup rollup in ordered)
            WeightQuantity(rollup.weight),
        ]),
      ),
      if (withValue)
        ExportField(
          'إجمالي الضمارات',
          formatRiyals(total, thousandsSeparator: thousandsSeparator),
        ),
      ExportField('عدد المقاوته', '${ordered.length}'),
      ExportField('عدد التوزيعات', '${counted.length}'),
    ],
    incompleteCount: counted
        .where((DistributionCard card) => card.hasUnpricedLines)
        .length,
  );
}

/// ★ مجمّعُ مقوتٍ واحد في `R-09` — ⛔ **بنيةٌ داخلية لا تُصدَّر**.
final class _DealerRollup {
  _DealerRollup(this.name);

  final String name;
  int documents = 0;
  int unpricedDocuments = 0;
  PieceCount pieces = PieceCount.zero;
  WeightKg weight = WeightKg.zero;
  Money value = Money.zero;
}

// ═════════════════════════════════════════════════════════════════════════
// `R-11` — المبيعات النقدية المباشرة
// ═════════════════════════════════════════════════════════════════════════

/// ★★ يبني `R-11` — **سنداتُ البيع النقدي في الفترة بصافي مقبوضها**.
///
/// ⛔⛔★★ **وعلى `stockDate` لا تاريخ الإدخال** — ★ **بخلاف `R-16` وحدَه**
/// (`schema/cash-sales.md` القاعدة 8 · `FR-M15-16`): ⟵ **فسندٌ صُرف من مخزون
/// أمسِ يقع في تقرير أمس مخزنياً وفي صندوق اليوم نقدياً**، ⛔ **وخلطُهما
/// يُنتج رقمين لليوم نفسِه بلا أن يقول أيُّهما أيّ** (`RISK-07`).
///
/// ⚠️ **والملغى يُعرَض ولا يدخل الإجماليات** (`A-14`).
ReportTable buildCashSalesReport({
  required ReportPeriod period,
  required List<CashSaleCard> sales,
  String thousandsSeparator = ',',
}) {
  final List<CashSaleCard> counted = <CashSaleCard>[
    for (final CashSaleCard sale in sales)
      if (!sale.isCancelled) sale,
  ];
  Money total = Money.zero;
  for (final CashSaleCard sale in counted) {
    total = total + sale.netCashReceived;
  }
  return ReportTable(
    report: ReportId.cashSales,
    header: <ExportField>[ExportField('الفترة', period.label)],
    columns: const <ReportColumn>[
      ReportColumn('تاريخ المخزون'),
      ReportColumn('رقم المستند'),
      ReportColumn('الحبات', numeric: true),
      ReportColumn('الأوزان', numeric: true),
      ReportColumn('صافي المقبوض', numeric: true),
      ReportColumn('الحالة'),
    ],
    rows: <ReportRow>[
      for (final CashSaleCard sale in sales)
        ReportRow(
          <String>[
            sale.stockDate.formatReadable(),
            sale.documentNumber,
            formatQuantity(PieceQuantity(sale.totalPieces)),
            formatQuantity(WeightQuantity(sale.totalWeight)),
            formatRiyals(
              sale.netCashReceived,
              thousandsSeparator: thousandsSeparator,
            ),
            sale.isCancelled ? 'ملغى' : 'معتمد',
          ],
          isCancelled: sale.isCancelled,
        ),
    ],
    totals: <ExportField>[
      ExportField(
        'إجمالي الحبات',
        formatTotals(<StockQuantity>[
          for (final CashSaleCard sale in counted)
            PieceQuantity(sale.totalPieces),
        ]),
      ),
      ExportField(
        'إجمالي الأوزان',
        formatTotals(<StockQuantity>[
          for (final CashSaleCard sale in counted)
            WeightQuantity(sale.totalWeight),
        ]),
      ),
      ExportField(
        'إجمالي المقبوض نقداً',
        formatRiyals(total, thousandsSeparator: thousandsSeparator),
      ),
      ExportField('عدد السندات', '${counted.length}'),
    ],
  );
}

// ═════════════════════════════════════════════════════════════════════════
// `R-12` — المبيعات حسب النوع (كمية وقيمة)
// ═════════════════════════════════════════════════════════════════════════

/// ★★★ يبني `R-12` — **كميةُ كلِّ نوعٍ وقيمتُه من التوزيع والبيع النقدي معاً**.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **وقيمةُ السطر تُقرأ كما كُتبت ولا تُشتقّ من الكمية والسعر** —
/// ★ **نفسُ قاعدة [SackRevenueContribution.lineValue] حرفياً** (`ADR-0019`
/// — **الموضع الثالث للتقريب**): ⟵ **السطرُ الوزنيُّ مرَّ بالتقريب لحظةَ
/// حفظِ مستنده**، ⛔ **وإعادةُ ضربِه هنا تُنتج رقماً يخالف المستند بريالٍ
/// أو ريالين بلا إنذار.**
///
/// ⛔⛔★★ **وعمودُ القيمة يظهر لمن يقرأ الأسعار وحدَه** ([withValue]) —
/// ★ **وأسعارُ التوزيع في مستندٍ فرعي بشرطِ قراءةٍ مستقل** (`ADR-0011`):
/// ⟵ **فعمودٌ يجمع البيعَ النقدي وحدَه كان يُظهر مبيعاتٍ أقلَّ مما وقع**،
/// ⛔ **وهو أسوأ من إخفاء العمود كلِّه.**
///
/// ⛔⛔ **ولا جمعَ بين حبّةٍ وكيلوجرام** — ★ **كلُّ نوعٍ بوحدته وحدَها**
/// (`GR-19` · `FR-M19-05`): ⟵ **والصفُّ نوعٌ واحد فوحدتُه واحدة.**
/// ═══════════════════════════════════════════════════════════════════════
ReportTable buildSalesByItemReport({
  required ReportPeriod period,
  required List<DistributionCard> distributions,
  required List<CashSaleCard> cashSales,
  Map<String, DistributionPricingCard> pricing =
      const <String, DistributionPricingCard>{},
  bool withValue = false,
  String thousandsSeparator = ',',
}) {
  final Map<String, _ItemSalesRollup> byItem = <String, _ItemSalesRollup>{};
  int unknownValues = 0;

  for (final DistributionCard card in distributions) {
    if (card.status == DistributionStatus.cancelled) continue;
    final DistributionPricingCard? prices = pricing[card.distributionId];
    for (int i = 0; i < card.lines.length; i++) {
      final ValidatedDistributionLine line = card.lines[i];
      final _ItemSalesRollup rollup = byItem.putIfAbsent(
        line.itemId,
        () => _ItemSalesRollup(line.itemName),
      );
      rollup.addDistribution(line.quantity);
      final Money? value = prices == null
          ? null
          : (i < prices.lineTotals.length ? prices.lineTotals[i] : null);
      if (value == null) {
        if (withValue) unknownValues++;
      } else {
        rollup.value = rollup.value + value;
      }
    }
  }

  for (final CashSaleCard sale in cashSales) {
    if (sale.isCancelled) continue;
    for (int i = 0; i < sale.lines.length; i++) {
      final ValidatedCashSaleLine line = sale.lines[i];
      final _ItemSalesRollup rollup = byItem.putIfAbsent(
        line.itemId,
        () => _ItemSalesRollup(line.itemName),
      );
      rollup.addCashSale(line.quantity);
      final Money? value = sale.lineTotalAt(i);
      if (value == null) {
        if (withValue) unknownValues++;
      } else {
        rollup.value = rollup.value + value;
      }
    }
  }

  final List<_ItemSalesRollup> ordered = <_ItemSalesRollup>[...byItem.values]
    ..sort((_ItemSalesRollup a, _ItemSalesRollup b) =>
        a.name.compareTo(b.name));
  Money total = Money.zero;
  for (final _ItemSalesRollup rollup in ordered) {
    total = total + rollup.value;
  }

  return ReportTable(
    report: ReportId.salesByItem,
    header: <ExportField>[ExportField('الفترة', period.label)],
    columns: <ReportColumn>[
      const ReportColumn('النوع'),
      const ReportColumn('كمية التوزيع', numeric: true),
      const ReportColumn('كمية البيع النقدي', numeric: true),
      if (withValue) const ReportColumn('القيمة', numeric: true),
    ],
    rows: <ReportRow>[
      for (final _ItemSalesRollup rollup in ordered)
        ReportRow(<String>[
          rollup.name,
          rollup.distributedCell,
          rollup.cashSoldCell,
          if (withValue)
            formatRiyals(rollup.value, thousandsSeparator: thousandsSeparator),
        ]),
    ],
    totals: <ExportField>[
      if (withValue)
        ExportField(
          'إجمالي قيمة المبيعات',
          formatRiyals(total, thousandsSeparator: thousandsSeparator),
        ),
      ExportField('عدد الأنواع', '${ordered.length}'),
    ],
    // ★★ **وسطرٌ بلا قيمةٍ مسجَّلة قيمةٌ ناقصة** — `FR-M19-08`:
    //    ⟵ **فالرقمُ غيرُ نهائي ويُقال ذلك صراحةً** ⛔ **لا يُعرَض تامّاً.**
    incompleteCount: unknownValues,
  );
}

/// ★ مجمّعُ نوعٍ واحد في `R-12` — ⛔ **بنيةٌ داخلية لا تُصدَّر**.
final class _ItemSalesRollup {
  _ItemSalesRollup(this.name);

  final String name;
  final List<StockQuantity> _distributed = <StockQuantity>[];
  final List<StockQuantity> _cashSold = <StockQuantity>[];
  Money value = Money.zero;

  void addDistribution(StockQuantity quantity) => _distributed.add(quantity);

  void addCashSale(StockQuantity quantity) => _cashSold.add(quantity);

  String get distributedCell => _quantityCell(_distributed);

  String get cashSoldCell => _quantityCell(_cashSold);
}

// ═════════════════════════════════════════════════════════════════════════
// `R-13` — السطور غير المسعَّرة
// ═════════════════════════════════════════════════════════════════════════

/// ★★ يبني `R-13` — **مستنداتُ التوزيع التي فيها سطورٌ بلا سعر**.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **ولماذا صفُّه مستندٌ لا سطر — قيدٌ بنيويٌّ لا اختيار عرض:**
/// ★ **الأسعارُ معزولةٌ في `pricing/current` بشرطِ قراءةٍ مستقل** (`ADR-0011`
/// · `ت-12`)، ⟵ **والمستندُ الأب لا يحمل إلا `unpricedLineCount` عدداً**:
/// ⟹ **فتسميةُ السطر بعينه تلزمها قراءةُ الأسعار** ⛔ **ولا يراها من لا
/// يملك `distributionPriceView`** — ★ **وتقريرُ الملاحقة يجب أن يعمل لمن
/// يلاحق النواقص** ⛔ **لا لمن يرى المبالغ وحدَه.**
/// ⟵ ★ **والعددُ دقيقٌ للجميع** — **مصدرُه المستندُ نفسُه** ⛔ **لا تقدير.**
/// ═══════════════════════════════════════════════════════════════════════
ReportTable buildUnpricedLinesReport({
  required ReportPeriod period,
  required List<DistributionCard> distributions,
  Map<String, String> dealerNames = const <String, String>{},
  String? dealerId,
}) {
  final List<DistributionCard> visible = <DistributionCard>[
    for (final DistributionCard card in distributions)
      if (card.status != DistributionStatus.cancelled &&
          card.hasUnpricedLines &&
          (dealerId == null || card.dealerId == dealerId))
        card,
  ];
  int lines = 0;
  for (final DistributionCard card in visible) {
    lines += card.unpricedLineCount;
  }
  return ReportTable(
    report: ReportId.unpricedLines,
    header: <ExportField>[
      ExportField('الفترة', period.label),
      if (dealerId case final String dealer)
        ExportField('المقوت', dealerNames[dealer] ?? dealer),
    ],
    columns: const <ReportColumn>[
      ReportColumn('تاريخ المخزون'),
      ReportColumn('رقم المستند'),
      ReportColumn('المقوت'),
      ReportColumn('سطور بلا سعر', numeric: true),
      ReportColumn('حالة التسعير'),
    ],
    rows: <ReportRow>[
      for (final DistributionCard card in visible)
        ReportRow(<String>[
          card.stockDate.formatReadable(),
          card.documentNumber,
          dealerNames[card.dealerId] ?? card.dealerName,
          '${card.unpricedLineCount}',
          _distributionStatusLabel(card.status),
        ]),
    ],
    totals: <ExportField>[
      ExportField('عدد المستندات', '${visible.length}'),
      ExportField('إجمالي السطور غير المسعَّرة', '$lines'),
    ],
    incompleteCount: visible.length,
  );
}

// ═════════════════════════════════════════════════════════════════════════
// `R-15` — الخصومات
// ═════════════════════════════════════════════════════════════════════════

/// ★★ يبني `R-15` — **سنداتُ الخصم في الفترة بمبلغها المنسوب للمصدر**.
///
/// ⛔⛔★★★ **والمبلغُ خصمٌ لا مبلغٌ واصل** (`FR-M15-06-أ`) — ★ **ولا يدخل
/// الصندوق ولا يُطرَح من نقدٍ**: ⟵ **فتسميتُه «مقبوضاً» كانت تُظهر المقوتَ
/// وكأنه سدّد مالاً لم يدفعه** ⛔ **وهو أخطر ما في هذا التقرير.**
///
/// ⛔ **والمبلغُ المعروض هو المنسوبُ لمصدر التقرير وحدَه**
/// ([discountAmountForSource]) — `FR-M19-02`.
ReportTable buildDiscountsReport({
  required ReportPeriod period,
  required List<DiscountCard> discounts,
  String? sourceId,
  String thousandsSeparator = ',',
}) {
  final List<DiscountCard> counted = <DiscountCard>[
    for (final DiscountCard card in discounts)
      if (!card.isCancelled) card,
  ];
  Money total = Money.zero;
  for (final DiscountCard card in counted) {
    total = total + discountAmountForSource(card, sourceId);
  }
  return ReportTable(
    report: ReportId.discounts,
    header: <ExportField>[ExportField('الفترة', period.label)],
    columns: const <ReportColumn>[
      ReportColumn('التاريخ'),
      ReportColumn('رقم المستند'),
      ReportColumn('المقوت'),
      ReportColumn('مبلغ الخصم', numeric: true),
      ReportColumn('الحالة'),
    ],
    rows: <ReportRow>[
      for (final DiscountCard card in discounts)
        ReportRow(
          <String>[
            card.date.formatReadable(),
            card.documentNumber,
            card.dealerName,
            formatRiyals(
              discountAmountForSource(card, sourceId),
              thousandsSeparator: thousandsSeparator,
            ),
            card.isCancelled ? 'ملغى' : 'معتمد',
          ],
          isCancelled: card.isCancelled,
        ),
    ],
    totals: <ExportField>[
      ExportField(
        'إجمالي الخصومات',
        formatRiyals(total, thousandsSeparator: thousandsSeparator),
      ),
      ExportField('عدد السندات', '${counted.length}'),
    ],
  );
}

// ═════════════════════════════════════════════════════════════════════════
// `R-16` — حركة النقد في تاريخ
// ═════════════════════════════════════════════════════════════════════════

/// ★★★ يبني `R-16` — **صندوقُ يومٍ واحد: الداخل والخارج وما بقي في اليد**.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **والمقبوضُ ليس الواصل** (`GR-41` · `FR-M15-15`) — ★ **الأول
/// صندوقُ يومٍ والثاني ذمّةُ يوم**: ⟵ **وهما رقمان مختلفان لليوم نفسِه**،
/// ⛔ **وخلطُهما أشيعُ خطأٍ متوقَّع في هذا التقرير** (`reporting-design.md` §5).
///
/// ⛔⛔★★★ **والبندُ المحكومُ يختفي كلياً لمن لا يملك مفتاحه** — `E-29`
/// نصّاً («**البند يختفي كلياً من البطاقة *والنقد* وكل التقارير**»):
/// ⟵ **ولذلك تصل هنا [CashMovementProjection] مبنيّةً على صلاحيات قارئها**،
/// ⛔ **ولا يُفلتَر صفٌّ عرضاً** — ★ **فإجمالي الخارج يكشف المخفيَّ بالطرح.**
///
/// ⛔ **وحالةُ الإيداع لمن يملك `receiptDepositView` وحدَه** ([readsDeposit])
/// — ★ **وبدونه لا يُعرَض «لم يُودَع»** ⟵ **فصفرُ المودَع عنده يعني «لم
/// أقرأ» لا «لم يُودَع شيء»** ⛔ **وعرضُه كان يكذب** (`ADR-0017`).
/// ═══════════════════════════════════════════════════════════════════════
ReportTable buildCashMovementReport({
  required CalendarDay date,
  required CashMovementProjection movement,
  bool readsDeposit = false,
  String thousandsSeparator = ',',
}) {
  final CashMovementSummary summary = movement.summary;
  String money(Money amount) =>
      formatRiyals(amount, thousandsSeparator: thousandsSeparator);

  return ReportTable(
    report: ReportId.cashMovement,
    header: <ExportField>[
      ExportField('التاريخ', date.formatReadable()),
      // ★★ **وتنبيهُ فجوة النقد في الترويسة** — §9: ⟵ **الصافي في اليد
      //    أقلُّ مما لم يُودَع** ⛔ **ولا يُطوى في رقمٍ عابر.**
      if (movement.hasCashGap)
        const ExportField(
          'تنبيه',
          'الصافي في اليد أقل مما لم يُودَع من المقبوض',
        ),
    ],
    columns: const <ReportColumn>[
      ReportColumn('البند'),
      ReportColumn('المبلغ', numeric: true),
    ],
    rows: <ReportRow>[
      ReportRow(<String>[
        'المقبوض من المقاوته',
        money(summary.receivedFromDealers),
      ]),
      ReportRow(<String>[
        'منه: لضمارات هذا اليوم',
        money(summary.receivedForSameDayDebt),
      ]),
      ReportRow(<String>[
        'منه: لأيام سابقة',
        money(summary.receivedForPreviousDays),
      ]),
      ReportRow(<String>[
        'منه: فائض لم يُسدَّد',
        money(summary.receivedAsSurplus),
      ]),
      ReportRow(<String>['المبيعات النقدية', money(summary.cashSales)]),
      ReportRow(<String>['إجمالي النقد الداخل', money(summary.totalIn)]),
      if (movement.withdrawals case final Money withdrawals)
        ReportRow(<String>['السحبيات', money(withdrawals)]),
      if (movement.expenses case final Money expenses)
        ReportRow(<String>['الخرجيات', money(expenses)]),
      ReportRow(<String>['إجمالي النقد الخارج', money(movement.totalOut)]),
      // ⛔⛔ **والخصوماتُ للعلم ولا تُطرح** — `FR-M15-20`: ⟵ **لم يدخل نقدٌ
      //    أصلاً**، ★ **وذكرُها بلا هذا القيد كان يجعلها تبدو مصروفاً.**
      ReportRow(<String>[
        'الخصومات (للعلم — لا تُطرح)',
        money(summary.discounts),
      ]),
      if (readsDeposit) ...<ReportRow>[
        ReportRow(<String>['من المقبوض: أُودع', money(summary.deposited)]),
        ReportRow(<String>[
          'من المقبوض: لم يُودَع',
          money(summary.notDeposited),
        ]),
      ],
    ],
    totals: <ExportField>[
      ExportField('صافي النقد في اليد', money(movement.netInHand)),
      ExportField('نسبة تغطية الخارج من المقبوض', _coverageCell(movement)),
    ],
  );
}

// ═════════════════════════════════════════════════════════════════════════
// `R-20` — ضمار المالك اليومي
// ═════════════════════════════════════════════════════════════════════════

/// ★★★ يبني `R-20` — **صفٌّ لكل يومٍ ببنود ضمار المالك**.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **والبندان المحكومان عمودان يختفيان كلياً** — `E-29` · `FR-M15-10`:
/// ★ **ويصل كلُّ يومٍ هنا [OwnerLedgerProjection] مبنيّاً على صلاحيات قارئه**،
/// ⟵ **و«الصافي النهائي» الذي يراه مستخدمان مختلفا الصلاحيات قد يختلف رقمه**
/// — ★ **سلوكٌ مقصود لا خلل** (`owner-ledger-summary-design.md` §5).
///
/// ★★ **ووسمُ «⟳ مُحدَّث بأثر رجعي» يظهر هنا لأن له كاتباً فعلاً** — ★ **من
/// `WU-016`** (`retroUpdatedAt` في `daily_summaries` — `FR-M19-06`):
/// ⛔ **ولا يُعرَض في تقريرٍ لا مصدرَ للوسم فيه.**
/// ═══════════════════════════════════════════════════════════════════════
ReportTable buildOwnerLedgerDailyReport({
  required ReportPeriod period,
  required List<OwnerLedgerProjection> days,
  required OwnerLedgerVisibility visibility,
  String thousandsSeparator = ',',
}) {
  final List<OwnerLedgerProjection> ordered = <OwnerLedgerProjection>[...days]
    ..sort(
      (OwnerLedgerProjection a, OwnerLedgerProjection b) =>
          a.summary.date.compareTo(b.summary.date),
    );
  String money(Money amount) =>
      formatRiyals(amount, thousandsSeparator: thousandsSeparator);

  Money totalDebt = Money.zero;
  Money settled = Money.zero;
  Money discounts = Money.zero;
  Money tax = Money.zero;
  Money withdrawals = Money.zero;
  Money expenses = Money.zero;
  Money net = Money.zero;
  DateTime? retro;
  for (final OwnerLedgerProjection day in ordered) {
    totalDebt = totalDebt + day.summary.totalDebt;
    settled = settled + day.summary.settledOfDay;
    discounts = discounts + day.summary.discounts;
    tax = tax + day.summary.tax;
    withdrawals = withdrawals + (day.withdrawals ?? Money.zero);
    expenses = expenses + (day.expenses ?? Money.zero);
    net = net + day.netFinal;
    final DateTime? stamp = day.summary.retroUpdatedAt;
    if (stamp != null && (retro == null || stamp.isAfter(retro))) retro = stamp;
  }

  return ReportTable(
    report: ReportId.ownerLedgerDaily,
    header: <ExportField>[
      ExportField('الفترة', period.label),
      if (retro case final DateTime stamp)
        ExportField('⟳ مُحدَّث بأثر رجعي', _instantCell(stamp)),
    ],
    columns: <ReportColumn>[
      const ReportColumn('تاريخ المخزون'),
      const ReportColumn('إجمالي الضمار', numeric: true),
      const ReportColumn('الواصل', numeric: true),
      const ReportColumn('الخصومات', numeric: true),
      const ReportColumn('الباقي بعد الخصم', numeric: true),
      const ReportColumn('الضريبة', numeric: true),
      if (visibility.showsWithdrawals)
        const ReportColumn('السحبيات', numeric: true),
      if (visibility.showsExpenses)
        const ReportColumn('الخرجيات', numeric: true),
      const ReportColumn('الصافي النهائي', numeric: true),
    ],
    rows: <ReportRow>[
      for (final OwnerLedgerProjection day in ordered)
        ReportRow(<String>[
          day.summary.date.formatReadable(),
          money(day.summary.totalDebt),
          money(day.summary.settledOfDay),
          money(day.summary.discounts),
          money(day.summary.remainingAfterDiscount),
          money(day.summary.tax),
          if (day.withdrawals case final Money amount) money(amount),
          if (day.expenses case final Money amount) money(amount),
          money(day.netFinal),
        ]),
    ],
    totals: <ExportField>[
      ExportField('إجمالي الضمار', money(totalDebt)),
      ExportField('إجمالي الواصل', money(settled)),
      ExportField('إجمالي الخصومات', money(discounts)),
      ExportField('إجمالي الضريبة', money(tax)),
      if (visibility.showsWithdrawals)
        ExportField('إجمالي السحبيات', money(withdrawals)),
      if (visibility.showsExpenses)
        ExportField('إجمالي الخرجيات', money(expenses)),
      ExportField('الصافي النهائي', money(net)),
      ExportField('عدد الأيام', '${ordered.length}'),
    ],
  );
}

// ═════════════════════════════════════════════════════════════════════════
// `R-21` · `R-22` — سجل السحبيات وسجل الخرجيات
// ═════════════════════════════════════════════════════════════════════════

/// ★★★ يبني `R-21` أو `R-22` — **سنداتُ سجلٍّ واحدٍ في الفترة**.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **وبانٍ واحدٌ لتقريرين منفصلين تماماً — ولا تناقض:** ★ **`FR-M19-07`
/// و`GR-43` يشترطان **تقريرين منفصلين لكلٍّ صلاحيتُه**، ⟵ **وهذا محقَّقٌ في
/// [ReportId.withdrawals] و[ReportId.expenses] بمفتاحيهما المستقلين وفي
/// استعلامين مستقلين مُقيَّدين بـ`ledgerType`** ([`DEBT-89`]):
/// ⛔ **والممنوعُ تقريرٌ واحدٌ يجمع السجلّين بفلتر** — ★ **وهو ما لا يقع هنا:
/// [ledgerType] مُدخَلٌ إلزاميٌّ لا فلترٌ اختياري.**
/// ⟵ ★ **ومعادلةٌ واحدة لعرضٍ واحد** (`coding-standards.md` §2.2) — ⛔ **ونسخةٌ
/// ثانية بجدولٍ مطابق كانت تفترق عند أول عمودٍ يُضاف.**
/// ═══════════════════════════════════════════════════════════════════════
ReportTable buildOutflowLedgerReport({
  required ReportPeriod period,
  required OutflowLedgerType ledgerType,
  required List<OutflowCard> outflows,
  OutflowCategory? category,
  OutflowLineKind? lineKind,
  String thousandsSeparator = ',',
}) {
  final List<OutflowCard> visible = <OutflowCard>[
    for (final OutflowCard card in outflows)
      if ((category == null || card.category == category) &&
          (lineKind == null || _hasLineKind(card, lineKind)))
        card,
  ];
  final List<OutflowCard> counted = <OutflowCard>[
    for (final OutflowCard card in visible)
      if (!card.isCancelled) card,
  ];
  Money qat = Money.zero;
  Money cash = Money.zero;
  Money grand = Money.zero;
  for (final OutflowCard card in counted) {
    qat = qat + card.totalQatValue;
    cash = cash + card.totalCashValue;
    grand = grand + card.grandTotal;
  }
  String money(Money amount) =>
      formatRiyals(amount, thousandsSeparator: thousandsSeparator);

  return ReportTable(
    report: ledgerType == OutflowLedgerType.withdrawal
        ? ReportId.withdrawals
        : ReportId.expenses,
    header: <ExportField>[
      ExportField('الفترة', period.label),
      if (category case final OutflowCategory filter)
        ExportField('الفئة', filter.label),
      if (lineKind case final OutflowLineKind filter)
        ExportField('نوع البند', _lineKindLabel(filter)),
    ],
    columns: const <ReportColumn>[
      ReportColumn('تاريخ السند'),
      ReportColumn('رقم المستند'),
      ReportColumn('الفئة'),
      ReportColumn('قيمة القات', numeric: true),
      ReportColumn('المبالغ', numeric: true),
      ReportColumn('الإجمالي', numeric: true),
      ReportColumn('الحالة'),
    ],
    rows: <ReportRow>[
      for (final OutflowCard card in visible)
        ReportRow(
          <String>[
            card.date.formatReadable(),
            card.documentNumber,
            card.category.label,
            money(card.totalQatValue),
            money(card.totalCashValue),
            money(card.grandTotal),
            // ★ **وشارةُ «سعر غير نهائي» حالةٌ لا تُطوى** — `FR-M22-07`.
            card.isCancelled
                ? 'ملغى'
                : (card.unpricedItemCount > 0 ? 'سعر غير نهائي' : 'معتمد'),
          ],
          isCancelled: card.isCancelled,
        ),
    ],
    totals: <ExportField>[
      ExportField('إجمالي قيمة القات', money(qat)),
      ExportField('إجمالي المبالغ', money(cash)),
      ExportField('الإجمالي العام', money(grand)),
      ExportField('عدد السندات', '${counted.length}'),
    ],
    // ★★ **وبندُ قاتٍ بلا سعرٍ قيمةٌ ناقصة** — `FR-M19-08` · `FR-M22-07`.
    incompleteCount:
        counted.where((OutflowCard card) => card.unpricedItemCount > 0).length,
  );
}

// ═════════════════════════════════════════════════════════════════════════
// `R-23` — الأثر النهائي على حساب المصدر
// ═════════════════════════════════════════════════════════════════════════

/// ★★★ يبني `R-23` — **أثرُ الفترة كلِّها على حساب المصدر ببنوده الخمسة**.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ★★ **والبنودُ الخمسة من `reporting-design.md` §5 نصّاً:** **ضمار الفترة ·
/// الواصل · الضريبة · السحبيات · الخرجيات** — ★ **والخصوماتُ سادسٌ يعرضه
/// الملخّصُ نفسُه** (`OQ-001`: **الصافي مبنيٌّ على «بعد الخصم»**).
///
/// ⛔⛔★★★ **والصافي مجموعُ صوافي الأيام** — ⛔ **لا معادلةٌ جديدة تُكتب هنا:**
/// ★ **[projectOwnerLedgerSummary] هي الموضعُ الوحيد لبناء الصافي على
/// صلاحيات قارئه**، ⟵ **وجمعُها خطّيٌّ كجمع البطاقات بنداً ببند** (§11).
/// ═══════════════════════════════════════════════════════════════════════
ReportTable buildSourceNetImpactReport({
  required ReportPeriod period,
  required List<OwnerLedgerProjection> days,
  required OwnerLedgerVisibility visibility,
  String thousandsSeparator = ',',
}) {
  Money totalDebt = Money.zero;
  Money settled = Money.zero;
  Money discounts = Money.zero;
  Money tax = Money.zero;
  Money withdrawals = Money.zero;
  Money expenses = Money.zero;
  Money net = Money.zero;
  for (final OwnerLedgerProjection day in days) {
    totalDebt = totalDebt + day.summary.totalDebt;
    settled = settled + day.summary.settledOfDay;
    discounts = discounts + day.summary.discounts;
    tax = tax + day.summary.tax;
    withdrawals = withdrawals + (day.withdrawals ?? Money.zero);
    expenses = expenses + (day.expenses ?? Money.zero);
    net = net + day.netFinal;
  }
  String money(Money amount) =>
      formatRiyals(amount, thousandsSeparator: thousandsSeparator);

  return ReportTable(
    report: ReportId.sourceNetImpact,
    header: <ExportField>[ExportField('الفترة', period.label)],
    columns: const <ReportColumn>[
      ReportColumn('البند'),
      ReportColumn('المبلغ', numeric: true),
    ],
    rows: <ReportRow>[
      ReportRow(<String>['إجمالي ضمار الفترة', money(totalDebt)]),
      ReportRow(<String>['الواصل', money(settled)]),
      ReportRow(<String>['الخصومات', money(discounts)]),
      ReportRow(<String>['الضريبة', money(tax)]),
      if (visibility.showsWithdrawals)
        ReportRow(<String>['السحبيات', money(withdrawals)]),
      if (visibility.showsExpenses)
        ReportRow(<String>['الخرجيات', money(expenses)]),
    ],
    totals: <ExportField>[
      ExportField('الأثر النهائي على حساب المصدر', money(net)),
      ExportField('عدد الأيام', '${days.length}'),
    ],
  );
}

// ═════════════════════════════════════════════════════════════════════════
// `R-24` — تغطية السحبيات من المقبوض اليومي
// ═════════════════════════════════════════════════════════════════════════

/// ★★★ يبني `R-24` — **نسبةُ ما خرج من المقبوض في تاريخ**.
///
/// ⛔⛔★★★ **والنسبةُ على المقبوض لا على الواصل** (`GR-47` · `FR-M15-19`) —
/// ★ **لأن السحبيات تُصرف من النقد الموجود فعلاً لا من ذمّة اليوم**:
/// ⟵ **وقياسُها على الواصل كان يُظهر تغطيةً وهميةً في يومٍ ذمّتُه كبيرة
/// وصندوقُه فارغ.**
///
/// ⛔ **و«لا مقبوضَ يُقاس عليه» ليست صفراً** (§9) — ★ **والفرقُ معلومة:**
/// ⟵ **صفرُ التغطية يعني «قُبض ولم يخرج شيء»**، ⛔ **وغيابُها يعني «لم
/// يُقبَض أصلاً».**
ReportTable buildWithdrawalCoverageReport({
  required CalendarDay date,
  required CashMovementProjection movement,
  String thousandsSeparator = ',',
}) {
  String money(Money amount) =>
      formatRiyals(amount, thousandsSeparator: thousandsSeparator);

  return ReportTable(
    report: ReportId.withdrawalCoverage,
    header: <ExportField>[
      ExportField('التاريخ', date.formatReadable()),
      if (movement.hasCashGap)
        const ExportField(
          'تنبيه',
          'الصافي في اليد أقل مما لم يُودَع من المقبوض',
        ),
    ],
    columns: const <ReportColumn>[
      ReportColumn('البند'),
      ReportColumn('المبلغ', numeric: true),
    ],
    rows: <ReportRow>[
      ReportRow(<String>[
        'المقبوض من المقاوته',
        money(movement.summary.receivedFromDealers),
      ]),
      if (movement.withdrawals case final Money withdrawals)
        ReportRow(<String>['السحبيات', money(withdrawals)]),
      if (movement.expenses case final Money expenses)
        ReportRow(<String>['الخرجيات', money(expenses)]),
      ReportRow(<String>['إجمالي الخارج', money(movement.totalOut)]),
    ],
    totals: <ExportField>[
      ExportField('نسبة التغطية من المقبوض', _coverageCell(movement)),
      ExportField('صافي النقد في اليد', money(movement.netInHand)),
    ],
  );
}

// ═════════════════════════════════════════════════════════════════════════
// `R-25` — حساب الرعوي لكل مصدر
// ═════════════════════════════════════════════════════════════════════════

/// ★★★ يبني `R-25` — **جوانيُّ الرعية في المصدر بسعرها وضريبتها وصافيها**.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★ **والضريبةُ المعلّقة تُكتب «معلّقة» ولا تُقرأ صفراً** (`FR-M7-10`) —
/// ★ **وصافيها `null` كذلك**: ⟵ **فصفرُ الضريبة يعني «لا ضريبة عليها»**،
/// ⛔ **وغيابُها يعني «لم تُدخَل بعد»** — ★ **ورقمٌ يخلطهما يُنقِص مستحقاً.**
///
/// ★ **والصافي السالبُ حالةٌ واقعية** (`FR-M14-04`) — ⟵ **جونيةٌ لم تُصرَف
/// بعدُ وضريبتُها مستحقة**، ⛔ **ولا يُطوى في صفر.**
/// ═══════════════════════════════════════════════════════════════════════
ReportTable buildSupplierAccountReport({
  required ReportPeriod period,
  required List<SupplierLedgerRow> rows,
  String? supplierId,
  Map<String, String> supplierNames = const <String, String>{},
  String thousandsSeparator = ',',
}) {
  final List<SupplierLedgerRow> visible = <SupplierLedgerRow>[
    for (final SupplierLedgerRow row in rows)
      if (supplierId == null || row.supplierId == supplierId) row,
  ];
  final List<SupplierLedgerRow> counted = <SupplierLedgerRow>[
    for (final SupplierLedgerRow row in visible)
      if (!row.isCancelled) row,
  ];
  Money revenue = Money.zero;
  Money tax = Money.zero;
  Money net = Money.zero;
  int pendingTax = 0;
  for (final SupplierLedgerRow row in counted) {
    revenue = revenue + row.sackRevenue;
    if (row.sackTax case final Money value) {
      tax = tax + value;
    } else {
      pendingTax++;
    }
    if (row.supplierNet case final Money value) net = net + value;
  }
  String money(Money amount) =>
      formatRiyals(amount, thousandsSeparator: thousandsSeparator);

  return ReportTable(
    report: ReportId.supplierAccount,
    header: <ExportField>[
      ExportField('الفترة', period.label),
      if (supplierId case final String supplier)
        ExportField('الرعوي', supplierNames[supplier] ?? supplier),
    ],
    columns: const <ReportColumn>[
      ReportColumn('الرعوي'),
      ReportColumn('الجونية'),
      ReportColumn('سعر الجونية', numeric: true),
      ReportColumn('الضريبة', numeric: true),
      ReportColumn('صافي الرعوي', numeric: true),
      ReportColumn('الحالة'),
    ],
    rows: <ReportRow>[
      for (final SupplierLedgerRow row in visible)
        ReportRow(
          <String>[
            supplierNames[row.supplierId] ??
                row.supplierName ??
                row.supplierId,
            row.sackDisplayName ?? row.sackId,
            money(row.sackRevenue),
            row.sackTax == null ? 'معلّقة' : money(row.sackTax!),
            row.supplierNet == null ? '—' : money(row.supplierNet!),
            _supplierRowState(row),
          ],
          isCancelled: row.isCancelled,
        ),
    ],
    totals: <ExportField>[
      ExportField('إجمالي أسعار الجواني', money(revenue)),
      ExportField('إجمالي الضريبة', money(tax)),
      ExportField('إجمالي صافي الرعية', money(net)),
      ExportField('عدد الجواني', '${counted.length}'),
      if (pendingTax > 0)
        ExportField('جواني بضريبة معلّقة', '$pendingTax'),
    ],
    // ★★ **وجونيةٌ بضريبةٍ معلّقة أو سعرٍ غير نهائي قيمةٌ ناقصة** —
    //    `FR-M19-08` · `FR-M14-06`.
    incompleteCount: counted
        .where((SupplierLedgerRow row) =>
            row.sackTax == null || !row.isRevenueFinal)
        .length,
  );
}

// ═════════════════════════════════════════════════════════════════════════
// `R-26` — الضريبة المستحقة
// ═════════════════════════════════════════════════════════════════════════

/// ★★ يبني `R-26` — **الضريبةُ المستحقة لكل رعويٍّ في الفترة**.
///
/// ⛔⛔ **والجونيةُ المعلّقةُ ضريبتُها تُعَدُّ ولا تُجمَع** — ★ **فالرقمُ
/// المعروض ما استُحقَّ فعلاً**، ⟵ **وعددُ المعلّقات يقول كم بقي** ⛔ **بلا
/// تقدير** (`FR-M7-10`).
ReportTable buildSupplierTaxReport({
  required ReportPeriod period,
  required List<SupplierLedgerRow> rows,
  String? supplierId,
  Map<String, String> supplierNames = const <String, String>{},
  String thousandsSeparator = ',',
}) {
  final Map<String, _SupplierTaxRollup> bySupplier =
      <String, _SupplierTaxRollup>{};
  for (final SupplierLedgerRow row in rows) {
    if (row.isCancelled) continue;
    if (supplierId != null && row.supplierId != supplierId) continue;
    final _SupplierTaxRollup rollup = bySupplier.putIfAbsent(
      row.supplierId,
      () => _SupplierTaxRollup(
        supplierNames[row.supplierId] ?? row.supplierName ?? row.supplierId,
      ),
    );
    rollup.sacks++;
    if (row.sackTax case final Money value) {
      rollup.tax = rollup.tax + value;
    } else {
      rollup.pending++;
    }
  }
  final List<_SupplierTaxRollup> ordered = <_SupplierTaxRollup>[
    ...bySupplier.values,
  ]..sort((_SupplierTaxRollup a, _SupplierTaxRollup b) =>
      a.name.compareTo(b.name));
  Money tax = Money.zero;
  int pending = 0;
  for (final _SupplierTaxRollup rollup in ordered) {
    tax = tax + rollup.tax;
    pending += rollup.pending;
  }
  String money(Money amount) =>
      formatRiyals(amount, thousandsSeparator: thousandsSeparator);

  return ReportTable(
    report: ReportId.supplierTax,
    header: <ExportField>[
      ExportField('الفترة', period.label),
      if (supplierId case final String supplier)
        ExportField('الرعوي', supplierNames[supplier] ?? supplier),
    ],
    columns: const <ReportColumn>[
      ReportColumn('الرعوي'),
      ReportColumn('عدد الجواني', numeric: true),
      ReportColumn('الضريبة المستحقة', numeric: true),
      ReportColumn('جواني بضريبة معلّقة', numeric: true),
    ],
    rows: <ReportRow>[
      for (final _SupplierTaxRollup rollup in ordered)
        ReportRow(<String>[
          rollup.name,
          '${rollup.sacks}',
          money(rollup.tax),
          '${rollup.pending}',
        ]),
    ],
    totals: <ExportField>[
      ExportField('إجمالي الضريبة المستحقة', money(tax)),
      ExportField('عدد الرعية', '${ordered.length}'),
      if (pending > 0) ExportField('جواني بضريبة معلّقة', '$pending'),
    ],
    incompleteCount: pending,
  );
}

/// ★ مجمّعُ رعويٍّ واحد في `R-26` — ⛔ **بنيةٌ داخلية لا تُصدَّر**.
final class _SupplierTaxRollup {
  _SupplierTaxRollup(this.name);

  final String name;
  int sacks = 0;
  int pending = 0;
  Money tax = Money.zero;
}

// ═════════════════════════════════════════════════════════════════════════
// `R-27` — تفكيك سعر جونية
// ═════════════════════════════════════════════════════════════════════════

/// ★★★ يبني `R-27` — **كلُّ حركةٍ دخلت سعرَ الجونية ومقدارُ ما أضافته**.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **والسعرُ من [computeSackRevenue] وحدَها** — ★ **الموضعُ الوحيد
/// للمعادلة** (`BR-M14-01`): ⟵ **وجمعٌ يدويٌّ هنا كان يصير معادلةً ثانية
/// تفترق عن أصلها** ⛔ **وهو حرفياً ما يمنعه `coding-standards.md` §2.2.**
///
/// ⛔⛔ **والملغاةُ والمستبعَدةُ تُعرَض مشطوبةً ولا تدخل السعر** (`A-14` ·
/// `A-15`) — ★ **والإتلافُ والوزنُ الضائع وتسويةُ الجرد مستبعَدةٌ بطبيعتها**:
/// ⟵ **فحذفُها كان يُخفي حركةً وقعت فعلاً على الجونية.**
///
/// ⛔⛔★★ **ولا ضريبةَ ولا صافيَ هنا — وهو حدُّ نطاقٍ مقصود:** ★ **عنوانُ
/// التقرير في `FR-M19` §2 «تفكيك سعر جونية» وحدَه**، ⟵ **والضريبةُ والصافي
/// في `R-25` بمفتاحه `supplierFinanceView`**: ⛔ **وجرُّهما هنا كان يُلزم هذا
/// التقريرَ بمفتاحٍ ثالث** ★ **أو يعرض «معلّقة» لمن هي مُدخَلةٌ عنده لكنه لا
/// يقرؤها** ⛔ **وهو كذبٌ لا نقص.**
/// ═══════════════════════════════════════════════════════════════════════
ReportTable buildSackPriceBreakdownReport({
  required String sackDisplayName,
  required List<SackRevenueContribution> contributions,
  String thousandsSeparator = ',',
}) {
  final SackRevenue revenue = computeSackRevenue(contributions);
  String money(Money amount) =>
      formatRiyals(amount, thousandsSeparator: thousandsSeparator);

  return ReportTable(
    report: ReportId.sackPriceBreakdown,
    header: <ExportField>[
      ExportField('الجونية', sackDisplayName),
      if (!revenue.isFinal)
        ExportField(
          'حالة السعر',
          'غير نهائي — ${revenue.unpricedCount} حركة بلا قيمة مسجَّلة',
        ),
    ],
    columns: const <ReportColumn>[
      ReportColumn('النوع'),
      ReportColumn('الوجهة'),
      ReportColumn('المستند'),
      ReportColumn('الجهة'),
      ReportColumn('الكمية', numeric: true),
      ReportColumn('السعر', numeric: true),
      ReportColumn('القيمة', numeric: true),
    ],
    rows: <ReportRow>[
      for (final SackRevenueContribution row in contributions)
        ReportRow(
          <String>[
            row.itemName,
            row.origin.label,
            row.documentNumber,
            row.counterpartyName ?? 'بلا جهة',
            formatQuantity(row.quantity),
            row.unitPrice == null ? '—' : money(row.unitPrice!),
            row.lineValue == null ? '—' : money(row.lineValue!),
          ],
          // ★ **والمستبعَدةُ مشطوبةٌ كالملغاة** — ⛔ **وكلتاهما خارج السعر.**
          isCancelled: !row.isCountable,
        ),
    ],
    totals: <ExportField>[
      ExportField('سعر الجونية', money(revenue.total)),
      ExportField('عدد الحركات الداخلة', '${revenue.countedCount}'),
    ],
    // ★★ **وحركةٌ داخلةٌ بلا قيمةٍ مسجَّلة قيمةٌ ناقصة** — `FR-M19-08` ·
    //    `FR-M14-06` (`E-27`).
    incompleteCount: revenue.unpricedCount,
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
      // ★★ `WU-013` — ⛔ **ويُسمّى «خصم» لا «قبض»** (`FR-M15-06-أ`):
      //    ⟵ **فكشفُ الحساب هو أولُ موضعٍ يقرأ فيه المالك الرقمين**،
      //    ⛔ **وتسميتُه قبضاً كانت تُظهر المقوتَ وكأنه سدّد مالاً لم يدفعه.**
      DealerLedgerEntryType.discount => 'خصم',
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

/// ★ هل في المستند سطرٌ من هذا النوع؟ — **فلترُ النوع في `R-03`**
/// ([`DEBT-72`] ④).
bool _intakeHasItem(CountedIntakeCard intake, String itemKey) {
  for (final ValidatedCountedIntakeLine line in intake.lines) {
    if (line.itemId == itemKey) return true;
  }
  return false;
}

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

// ═════════════════════════════════════════════════════════════════════════
// ★★ مساعداتُ `WU-018` — ⛔ **خاصةٌ بهذا الملف ولا تُصدَّر**
// ═════════════════════════════════════════════════════════════════════════

/// ★★ خليةُ كميةٍ مجمَّعة **لصنفٍ واحد** — ⛔ **ولا جمعَ بين وحدتين**.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★ **ولماذا لا [formatTotals] دائماً هنا:** ★ **تلك تكتب السطرين معاً
/// أبداً** (`0 حبة + 12.500 كجم`) — ⟵ **وهو الصواب لإجمالي تقريرٍ يخلط
/// أنواعاً**، ⛔ **وضجيجٌ في خليةِ نوعٍ واحدٍ وحدتُه واحدة** (`FR-M5-03`:
/// **الوحدة جزءٌ من هوية النوع**). ★ **والخلطُ يبقى مستحيلاً بنيوياً:**
/// ⟵ **الوحدتان معاً تُفوَّضان إلى [formatTotals] نفسِها** ⛔ **فلا موضعَ
/// لجمعٍ خاطئ أصلاً** (`GR-19` · `FR-M19-05` · `E-31`).
/// ═══════════════════════════════════════════════════════════════════════
String _quantityCell(List<StockQuantity> quantities) {
  if (quantities.isEmpty) return formatQuantity(const PieceQuantity(PieceCount.zero));
  final bool hasPieces = quantities.any((StockQuantity q) => q is PieceQuantity);
  final bool hasWeight = quantities.any((StockQuantity q) => q is WeightQuantity);
  if (hasPieces && hasWeight) return formatTotals(quantities);
  if (hasWeight) {
    WeightKg total = WeightKg.zero;
    for (final StockQuantity quantity in quantities) {
      if (quantity case WeightQuantity(:final WeightKg weight)) {
        total = total + weight;
      }
    }
    return formatQuantity(WeightQuantity(total));
  }
  PieceCount total = PieceCount.zero;
  for (final StockQuantity quantity in quantities) {
    if (quantity case PieceQuantity(:final PieceCount count)) {
      total = total + count;
    }
  }
  return formatQuantity(PieceQuantity(total));
}

/// ★★ نصُّ نسبة التغطية — ⛔ **والغيابُ يُقال ولا يُكتب صفراً** (§9).
///
/// ★ **«لا مقبوضَ يُقاس عليه» ≠ «تغطيةٌ صفر»** — ⟵ **الأولى لم يُقبَض فيها
/// شيء**، **والثانية قُبض ولم يخرج شيء** ⛔ **ولا يقبل أحدهما مكان الآخر.**
String _coverageCell(CashMovementProjection movement) =>
    movement.coveragePercent == null
        ? 'لا مقبوض يُقاس عليه'
        : '${movement.coveragePercent}٪';

/// ★ هل في السند بندٌ من هذا النوع؟ — **فلترُ «نوع البند»** (`FR-M22-05`).
bool _hasLineKind(OutflowCard card, OutflowLineKind kind) => switch (kind) {
      OutflowLineKind.qat => card.qatLines.isNotEmpty,
      OutflowLineKind.amount || OutflowLineKind.other => card.cashLines
          .any((OutflowCardCashLine line) => line.kind == kind),
    };

/// ★ اسمُ نوع البند — **من `FR-M22-05` حرفياً** ⛔ **ولا مصطلح تقني**.
String _lineKindLabel(OutflowLineKind kind) => switch (kind) {
      OutflowLineKind.qat => 'قات',
      OutflowLineKind.amount => 'مبلغ مالي',
      OutflowLineKind.other => 'أخرى',
    };

/// ★ حالةُ سطر دفتر الرعية — ⛔ **ولا تُترك فارغة** (`ui-guidelines.md` §6).
///
/// ⚠️ **والترتيب مقصود:** ★ **الإلغاء يسبق «غير نهائي»** — ⟵ **فجونيةٌ ملغاة
/// لا يهمّ أنّ سعرها غير نهائي**، ⛔ **وعرضُ الثانية يُوهم أنها ما تزال حيّة.**
String _supplierRowState(SupplierLedgerRow row) {
  if (row.isCancelled) return 'ملغاة';
  if (!row.isRevenueFinal) return 'سعر غير نهائي';
  return row.sackTax == null ? 'ضريبة معلّقة' : 'نهائي';
}

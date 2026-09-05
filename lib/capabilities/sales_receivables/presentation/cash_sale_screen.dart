/// شاشة **البيع النقدي المباشر** (`M11`) — **نقدٌ فوري بلا دين**.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **وأخطر ما يجب ألّا يُخلَط في هذه الشاشة — `FR-M11-03` (`GR-33`):**
///
/// **البيع النقدي لا يمسّ حساب أي مقوت.** ⟵ **فلا حقلَ مقوتٍ في النموذج،
/// ولا رصيدَ يُعرَض، ولا ضمارَ يُنشأ** — ★ **والفرقُ عن التوزيع ليس في
/// الواجهة بل في الأثر:** ⛔ **توزيعةٌ تُقيِّد ديناً، وبيعٌ نقديٌّ يُنهي
/// العملية بقبض ثمنها.**
/// ═══════════════════════════════════════════════════════════════════════
///
/// ★★★ **والتسعير إلزاميٌّ داخل السند نفسه** (`FR-M11-04`) — ⛔ **ولا
/// «تسعير لاحق» هنا بخلاف التوزيع** (`FR-M10-08`): ⟵ **فحقلُ السعر بلا
/// حالةِ فراغٍ مشروعة**، ★ **والحفظ لا يُمكَّن قبل ملئه.**
///
/// ⛔⛔★★★ **والبيعُ دون الحد الأدنى ممنوعٌ للجميع بلا استثناء**
/// ([`CR-007`] المعتمد 2026-09-01 · `GR-34`) — ★ **والحفظُ يُعطَّل في الشاشة
/// قبل أي رحلةِ شبكة**، ⟵ **والسحابةُ ترفض بالقاعدة نفسِها**
/// (`_minimumPriceGate` · `ERR_PRICE_002`): ⛔ **ولو عُدِّلت الحمولة من خارج
/// التطبيق.** ⚠️ **ونصُّ `FR-M11-05` الأصلي كان يستثني حاملَ
/// `cashSaleBelowMinimum`** — ★ **وأُلغي الاستثناء بقرار المالك الصريح.**
///
/// ★★★ **وبنيتُها بنيةُ `AM-009` ⑦ نفسُها** — **سجلاتٌ وزرٌّ عائم**:
/// ① **مرشِّحُ مصدرٍ بـ«الكل»** ② **بحثٌ برقم السند** ③ **سجلاتٌ لكلٍّ
/// إجراءاتُه** ④ **وزرٌّ عائمٌ للإضافة** — ⛔ **ولا نموذجٌ مفتوحٌ يشغل الشاشة.**
///
/// ⛔⛔★★★ **ولا زرَّ حذفٍ إطلاقاً** — ★ **الإلغاءُ هو المكافئ المعتمَد**
/// (`GR-07` · `FR-M11-13`): **يَسِم السند وحركاته فتُستبعَد من كل الأرصدة**،
/// ⛔ **والفارقُ أن الأثر يبقى مقروءاً في سجل التدقيق.**
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show FilteringTextInputFormatter, TextInputFormatter;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qtms_domain/qtms_domain.dart';

import '../../../app/top_bar.dart';
import '../../../core/device/device_preference_providers.dart';
import '../../../core/design/design_tokens.dart';
import '../../../core/messages/error_messages.dart';
import '../../../core/ui/async_state_view.dart';
import '../../../core/ui/context_header.dart';
import '../../../core/ui/destructive_sheet.dart';
import '../../../core/ui/item_line_editor.dart';
import '../../../core/ui/key_value_row.dart';
import '../../../core/ui/live_summary.dart';
import '../../../core/ui/optional_reason.dart';
import '../../../core/ui/search_field.dart';
import '../../../core/ui/sticky_action_bar.dart';
import '../../identity_access/presentation/permission_gate.dart';
import '../../inventory/application/aged_remainder_providers.dart';
import '../../inventory/presentation/aged_remainder_screen.dart';
import '../../inventory/application/inventory_providers.dart';
import '../../inventory/presentation/inventory_widgets.dart';
import '../../master_data/application/master_data_providers.dart';
import '../../oversight/presentation/audit_trail_view.dart';
import '../application/cash_sale_providers.dart';

/// شاشة البيع النقدي — ★ **سجلاتٌ ومرشِّحان وزرٌّ عائم** (`AM-009` ⑦).
class CashSaleScreen extends ConsumerStatefulWidget {
  /// ينشئ الشاشة.
  const CashSaleScreen({super.key});

  @override
  ConsumerState<CashSaleScreen> createState() => _CashSaleScreenState();
}

class _CashSaleScreenState extends ConsumerState<CashSaleScreen> {
  /// ★ **بحثٌ برقم السند** — ⛔ **ولا بحثَ باسم مشترٍ**: `FR-M11-12`
  /// **«اسم المشتري حقلٌ غير موجود قصداً»** ⟵ **فلا شيءَ يُبحَث به سواه.**
  final TextEditingController _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    // 📦★★★ **وجهةُ التصريف المتأخر — تُفتَح ورقةً مثبَّتة** (`WU-019` ·
    //    `A1` من `UC-004`: **يُحتسب في «نقدي» ذلك اليوم**).
    //
    // ⛔⛔★★★ **والاستهلاك بعد أول إطار لا داخل [initState]** — `DEBT-68`:
    //    ★ **`take()` *تكتب* حالةً، وRiverpod يمنع الكتابة في دورة حياة
    //    الويدجت.**
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      if (!mounted) return;
      final AgedClearanceFocus? aged = ref.read(agedClearanceFocusProvider);
      if (aged == null) return;
      ref.read(agedClearanceFocusProvider.notifier).take();
      ref.read(sourceListFilterProvider.notifier).select(aged.sourceId);
      showCashSaleForm(
        context,
        sourceId: aged.sourceId,
        pinnedStockDate: aged.stockDate,
        pinnedItemKey: aged.itemKey,
      );
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final CalendarDay today = ref.watch(todayProvider);
    final String? filterId = ref.watch(sourceListFilterProvider);
    final List<SourceCard> sources = ref.watch(activeSourcesProvider);

    return Scaffold(
      appBar: const QtmsTopBar(screenTitle: 'البيع النقدي'),
      // ④ ★★★ **زرٌّ عائمٌ للإضافة** — `AM-009` ⑦.
      floatingActionButton: sources.isEmpty
          ? null
          : PermissionGate(
              permission: Permission.cashSaleCreate,
              child: FloatingActionButton.extended(
                onPressed: () => showCashSaleForm(
                  context,
                  sourceId: filterId ?? sources.first.sourceId,
                ),
                icon: const Icon(Icons.point_of_sale_outlined),
                label: const Text('بيع نقدي جديد'),
              ),
            ),
      body: Column(
        children: <Widget>[
          // ① ★★★ **رأس السياق بمرشِّح «كل المصادر»** — `AM-009` ③.
          QtmsContextHeader(
            sources: sources,
            selectedSourceId: filterId,
            allowAllSources: true,
            onSourceSelected: (String? id) =>
                ref.read(sourceListFilterProvider.notifier).select(id),
            day: today,
          ),
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: Spacing.screenPadding,
              vertical: Spacing.space8,
            ),
            child: QtmsSearchField(
              controller: _search,
              label: 'بحث برقم السند',
            ),
          ),
          Expanded(
            child: sources.isEmpty
                ? const QtmsEmptyState(spec: noSourceInScopeEmpty)
                : _CashSaleRecords(
                    sourceId: filterId,
                    day: today,
                    search: _search,
                    showSource: filterId == null,
                  ),
          ),
        ],
      ),
    );
  }
}

/// ★★★ سجلاتُ اليوم — **برقم السند**.
class _CashSaleRecords extends ConsumerWidget {
  const _CashSaleRecords({
    required this.sourceId,
    required this.day,
    required this.search,
    required this.showSource,
  });

  final String? sourceId;
  final CalendarDay day;
  final TextEditingController search;
  final bool showSource;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<CashSaleCard>> records = ref.watch(
      cashSaleListProvider(
        SourceListQuery(sourceId: sourceId, stockDate: day),
      ),
    );

    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: search,
      builder: (BuildContext context, TextEditingValue value, Widget? _) {
        final String needle = value.text.trim();
        return InventoryAsyncView<CashSaleCard>(
          value: records,
          emptyIcon: Icons.point_of_sale_outlined,
          emptyTitle: 'لا مبيعات نقدية اليوم',
          emptyLabel: 'ابدأ ببيعٍ نقدي — يُخصم من المخزون ويُقبَض ثمنه فوراً.',
          builder: (List<CashSaleCard> list) {
            final List<CashSaleCard> shown = needle.isEmpty
                ? list
                : <CashSaleCard>[
                    for (final CashSaleCard card in list)
                      if (card.documentNumber.contains(needle)) card,
                  ];
            if (shown.isEmpty) {
              return const QtmsNoMatch(
                message: 'لا سند بهذا الرقم في نتائج اليوم.',
              );
            }
            return ListView.separated(
              padding: const EdgeInsetsDirectional.all(Spacing.screenPadding),
              itemCount: shown.length,
              separatorBuilder: (BuildContext _, int _) =>
                  const SizedBox(height: Spacing.space8),
              itemBuilder: (BuildContext context, int index) =>
                  _CashSaleTile(card: shown[index], showSource: showSource),
            );
          },
        );
      },
    );
  }
}

/// ★★★ سجلُّ سندٍ واحد — **الرقمُ ثم الإجراءات الثلاثة.**
class _CashSaleTile extends ConsumerWidget {
  const _CashSaleTile({required this.card, required this.showSource});

  final CashSaleCard card;
  final bool showSource;

  @override
  Widget build(BuildContext context, WidgetRef ref) => InventoryTile(
        // ★★ **والعنوانُ رقمُ السند** — ⛔ **ولا مشترٍ يُسمّى** (`FR-M11-12`):
        //    ⟵ **فالمشتري عابرٌ بلا حساب.**
        title: card.documentNumber,
        leading: auditTrailLeading(
          ref,
          entityType: cashSaleEntityType,
          entityId: card.documentNumber,
          title: card.documentNumber,
          sourceId: card.sourceId,
        ),
        subtitle: <String>[
          if (showSource) ref.watch(sourceDisplayNameProvider(card.sourceId)),
          '${card.lines.length} نوع',
          '${card.netCashReceived.riyals} ريال',
        ].join(' · '),
        badges: <Widget>[
          if (card.isCancelled) const CancelledBadge(),
          if (card.amendCount > 0) const AmendedBadge(),
        ],
        actions: <Widget>[
          // ★ **عرض** — ⛔ **بلا صلاحية**: ★ **القراءة يحكمها النطاق وحده**
          //   في `firestore.rules` (`isSignedIn() && storedInScope()`).
          IconButton(
            onPressed: () => showCashSaleDetails(context, card: card),
            icon: const Icon(Icons.visibility_outlined),
            tooltip: 'عرض السند',
          ),
          if (!card.isCancelled)
            PermissionGate(
              permission: Permission.cashSaleAmend,
              child: IconButton(
                onPressed: () => showCashSaleForm(
                  context,
                  sourceId: card.sourceId,
                  documentNumber: card.documentNumber,
                ),
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'تعديل السند',
              ),
            ),
          // ⛔⛔★★★ **ولا زرَّ حذفٍ إطلاقاً** — راجع ترويسة الملف.
          if (!card.isCancelled)
            PermissionGate(
              permission: Permission.cashSaleCancel,
              child: IconButton(
                onPressed: () => showCancelCashSaleSheet(context, card: card),
                icon: const Icon(Icons.block_outlined),
                tooltip: 'إلغاء السند',
                color: SemanticTriads.danger.ink,
              ),
            ),
        ],
      );
}

// ═════════════════════════════════════════════════════════════════════════
// ورقة العرض
// ═════════════════════════════════════════════════════════════════════════

/// ★★ يفتح ورقة عرض السند — **قراءةٌ محضة**.
Future<void> showCashSaleDetails(
  BuildContext context, {
  required CashSaleCard card,
}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: SemanticColors.surface,
      builder: (BuildContext context) => CashSaleDetailsSheet(card: card),
    );

/// ورقة عرض السند.
///
/// ★★ **وصافي المقبوض من المستند نفسِه** — ⛔ **لا يُحسَب هنا**
/// (`ADR-0010` القاعدة 1 · `design-system.md` §5.1).
class CashSaleDetailsSheet extends ConsumerWidget {
  /// ينشئ الورقة.
  const CashSaleDetailsSheet({required this.card, super.key});

  /// السند المعروض.
  final CashSaleCard card;

  @override
  Widget build(BuildContext context, WidgetRef ref) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsetsDirectional.all(Spacing.space16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(card.documentNumber, style: TypeScale.titleLg),
              const SizedBox(height: Spacing.space12),
              QtmsKeyValueRow(
                label: 'المصدر',
                value: ref.watch(sourceDisplayNameProvider(card.sourceId)),
              ),
              const SizedBox(height: Spacing.space16),
              for (final ValidatedCashSaleLine line in card.lines)
                QtmsKeyValueRow(
                  label: line.itemName,
                  value: '${quantityLabel(line.quantity)} × '
                      '${line.unitPrice.riyals} = ${line.lineTotal.riyals} ريال',
                ),
              const SizedBox(height: Spacing.space16),
              // ⛔⛔★★ **والإجماليان منفصلان دائماً** (`GR-19` · `FR-M11-14`).
              QtmsKeyValueRow(
                label: 'إجمالي الحبات',
                value: '${card.totalPieces.pieces} حبة',
              ),
              QtmsKeyValueRow(
                label: 'إجمالي الأوزان',
                value: '${card.totalWeight.formatted()} كجم',
              ),
              QtmsKeyValueRow(
                label: 'صافي المقبوض',
                value: '${card.netCashReceived.riyals} ريال',
              ),
            ],
          ),
        ),
      );
}

// ═════════════════════════════════════════════════════════════════════════
// ورقة الإلغاء
// ═════════════════════════════════════════════════════════════════════════

/// يفتح ورقة إلغاء السند — ★ **والسببُ اختياريٌّ** (`ADR-0020`).
Future<void> showCancelCashSaleSheet(
  BuildContext context, {
  required CashSaleCard card,
}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: SemanticColors.surface,
      builder: (BuildContext context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: CancelCashSaleSheet(card: card),
      ),
    );

/// ورقة إلغاء السند.
class CancelCashSaleSheet extends ConsumerWidget {
  /// ينشئ الورقة.
  const CancelCashSaleSheet({required this.card, super.key});

  /// السند الملغى.
  final CashSaleCard card;

  @override
  Widget build(BuildContext context, WidgetRef ref) => QtmsDestructiveSheet(
        title: 'إلغاء السند ${card.documentNumber}',
        // ★ **الإلغاء وسمٌ لا حذف** — `GR-06` · `GR-07` · `FR-M11-13`.
        impact: 'الإلغاء يَسِم السند وحركاته ولا يحذف شيئاً، فتعود الكمية '
            'إلى رصيد اليوم ويُستبعَد المبلغ من مقبوضات النقد.',
        confirmLabel: 'تأكيد الإلغاء',
        reasonLabel: 'سبب الإلغاء (اختياري)',
        onConfirm: (DestructiveConfirmation confirmation) async {
          final Outcome<void> result =
              await ref.read(cashSaleAdminProvider).cancelCashSale(
                    documentNumber: card.documentNumber,
                    sourceId: card.sourceId,
                    cancelReason: blankToNull(confirmation.reason),
                  );
          return switch (result) {
            Failure<void>(:final AppError error) =>
              catalogText(appErrorMessage(error)),
            Success<void>() => null,
          };
        },
      );
}

// ═════════════════════════════════════════════════════════════════════════
// نموذج السند
// ═════════════════════════════════════════════════════════════════════════

/// ★★★ يفتح نموذج البيع النقدي — **إنشاءً أو تعديلاً**.
Future<void> showCashSaleForm(
  BuildContext context, {
  required String sourceId,
  String? documentNumber,
  CalendarDay? pinnedStockDate,
  String? pinnedItemKey,
}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: SemanticColors.surface,
      builder: (BuildContext context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: CashSaleFormSheet(
          sourceId: sourceId,
          documentNumber: documentNumber,
          pinnedStockDate: pinnedStockDate,
          pinnedItemKey: pinnedItemKey,
        ),
      ),
    );

/// ورقة نموذج البيع النقدي.
///
/// ⛔⛔★★★ **ولا حقلَ مقوتٍ ولا مشترٍ ولا خصم** — `FR-M11-03` · `FR-M11-12`:
/// ★ **والغياب البنيوي هو التنفيذ** ⛔ **لا شرطٌ يُفحَص عند الحفظ.**
class CashSaleFormSheet extends ConsumerStatefulWidget {
  /// ينشئ الورقة.
  const CashSaleFormSheet({
    required this.sourceId,
    this.documentNumber,
    this.pinnedStockDate,
    this.pinnedItemKey,
    super.key,
  });

  /// المصدر الابتدائي.
  final String sourceId;

  /// رقم السند عند التعديل — و`null` تعني **إنشاءً**.
  final String? documentNumber;

  /// ★★★ **تاريخُ مخزونٍ قديمٌ مثبَّت** — `FR-M8-12` (`WU-019`).
  ///
  /// ⛔⛔★★★ **و`null` هو الحالُ الأصلي: يومُ المنصّة** — ★ **ووجودُه يعني أن
  /// الورقة فُتحت من شاشة المتبقي المتأخر**، ⟵ **ويُحتسب البيعُ في «نقدي»
  /// ذلك اليوم لا اليوم الحالي** (`E-24`).
  final CalendarDay? pinnedStockDate;

  /// ★★ **النوعُ المثبَّت** — يُبذَر سطراً أول (`FR-M8-12`).
  final String? pinnedItemKey;

  @override
  ConsumerState<CashSaleFormSheet> createState() => _CashSaleFormSheetState();
}

class _CashSaleFormSheetState extends ConsumerState<CashSaleFormSheet> {
  final TextEditingController _reason = TextEditingController();
  late String _sourceId = widget.sourceId;

  /// ★★★ **سطورٌ يُنشئها المستخدم** — `AM-009` ④ (راجع [QtmsItemLineRow]).
  final List<_CashLine> _lines = <_CashLine>[];

  /// ★ معرّفُ ما بُذر منه — ⛔ **ولا يُعاد الملء عند كل بناء**: ⟵ **وإلا مسح
  /// ما يكتبه المستخدم كلما وصل تحديثٌ من جهازٍ آخر.**
  String? _seededId;

  /// ★ هل بُذر النوعُ المثبَّت؟ — ⛔ **ولا يُعاد بذرُه بعد حذفه.**
  bool _pinnedSeeded = false;

  bool _submitting = false;
  CatalogMessage? _rejection;

  @override
  void dispose() {
    _reason.dispose();
    for (final _CashLine line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  /// ★ نسبةُ ارتفاع الورقة — ⛔ **ولا رقمَ عارٍ في التخطيط**.
  static const double _sheetHeightRatio = 0.9;

  @override
  Widget build(BuildContext context) {
    // ★★★ **يومُ هذه الورقة** — ⛔ **يومُ المنصّة إلا في التصريف المتأخر**
    //    (`WU-019` · `FR-M8-12`): ⟵ **والأرصدةُ والحدودُ الدنيا كلُّها منه.**
    final CalendarDay today =
        widget.pinnedStockDate ?? ref.watch(todayProvider);
    final bool isAged = widget.pinnedStockDate != null;
    final List<SourceCard> sources = ref.watch(activeSourcesProvider);
    // ⛔⛔★★★ **والخياراتُ من أرصدة الدفتر لا من كتالوج الأنواع** —
    //    [`DEBT-86`] · `ADR-0007`: راجع [stockOptionsProvider].
    final List<StockOption> items = ref.watch(
      stockOptionsProvider(StockQuery(sourceId: _sourceId, stockDate: today)),
    );
    final CashSaleQuery query =
        CashSaleQuery(sourceId: _sourceId, stockDate: today);
    // ★★ **الحدود الدنيا تُراقَب لا تُقرأ لحظة الحفظ** — ⟵ **فالقراءة
    //    المتأخرة تجد التدفّق لم يُشترَك بعد فتعود فارغة**، ★ **فيسقط
    //    التنبيه كلُّه** (نفس درسِ الأسعار المقترَحة في `WU-006`).
    final Map<String, Money> minimums =
        ref.watch(minimumCashPricesProvider(query));

    final CashSaleCard? existing = switch (widget.documentNumber) {
      final String number => ref
          .watch(
            cashSaleByNumberProvider(
              CashSaleDocumentQuery(
                sourceId: _sourceId,
                documentNumber: number,
                stockDate: today,
              ),
            ),
          )
          .value,
      null => null,
    };
    _seedFrom(existing);
    // ★★★ **وبذرُ النوع المثبَّت سطراً أول** — `FR-M8-12`.
    _seedPinnedItem();

    final bool isAmend = widget.documentNumber != null;
    final bool isCancelled = existing?.isCancelled ?? false;

    // ★★ **تفضيلُ إظهار وزن الحبة** — `AM-012` §4.4: ⛔ **عرضٌ محضٌ**
    //    ⟵ **ولا يمسّ وحدةَ الكمية ولا أي حساب.**
    final bool showPieceWeight = ref.watch(showPieceWeightProvider);
    final List<QtmsItemOption> options = <QtmsItemOption>[
      for (final StockOption item in items)
        QtmsItemOption(
          id: item.itemKey,
          // ★★★ **«اسم النوع (المتبقّي منه)»** — ⟵ **فمن يختار نوعاً يرى كم
          //    بقي منه *في لحظة الاختيار*** ⛔ **لا بعد أن يكتب رقماً يُرفَض.**
          // ★★ **ووزنُ الحبة عند تفعيل الخيار** — `AM-012` §4.4.
          label: itemOptionLabel(
            item.itemName,
            item.balance,
            showPieceWeight: showPieceWeight,
            pieceWeightGrams: item.pieceWeightGrams,
          ),
        ),
    ];
    final Map<String, StockOption> itemsById = <String, StockOption>{
      for (final StockOption item in items) item.itemKey: item,
    };

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * _sheetHeightRatio,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsetsDirectional.all(Spacing.space16),
              child: Text(
                isAmend ? 'تعديل السند' : 'بيع نقدي جديد',
                style: TypeScale.titleLg,
              ),
            ),
            Flexible(
              child: ListView(
                padding: const EdgeInsetsDirectional.only(
                  start: Spacing.screenPadding,
                  end: Spacing.screenPadding,
                  bottom: Spacing.screenPadding,
                ),
                children: <Widget>[
                  DropdownButtonFormField<String>(
                    initialValue:
                        sources.any((SourceCard s) => s.sourceId == _sourceId)
                            ? _sourceId
                            : null,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'المصدر'),
                    items: <DropdownMenuItem<String>>[
                      for (final SourceCard source in sources)
                        DropdownMenuItem<String>(
                          value: source.sourceId,
                          child: Text(
                            source.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    // ⛔ **ومقفلٌ في التعديل** — ★ **ونقلُ سندٍ بين مصدرين
                    //    نقلٌ خارج النطاق** (`ADR-0005`).
                    // ⛔⛔★★★ **ومقفلٌ في التصريف المتأخر كذلك** —
                    //    `FR-M8-12`: **المصدر 🔒**.
                    onChanged: isAmend || isAged ? null : _onSourceChanged,
                  ),
                  const SizedBox(height: Spacing.space16),
                  // ⚠️★★★ **وشريطُ التنبيه البارز** — `FR-M8-12` نصّاً.
                  if (isAged) ...<Widget>[
                    AgedClearanceBanner(stockDate: today),
                    const SizedBox(height: Spacing.space16),
                  ],
                  if (isCancelled)
                    Text(
                      'هذا السند ملغى — لا يمكن تعديله.',
                      style: TypeScale.bodyMd
                          .copyWith(color: SemanticTriads.danger.ink),
                    )
                  else ...<Widget>[
                    Text(
                      'الأنواع',
                      style: TypeScale.label
                          .copyWith(color: SemanticColors.textSecondary),
                    ),
                    const SizedBox(height: Spacing.space8),
                    for (final (int index, _CashLine line) in _lines.indexed)
                      QtmsItemLineRow(
                        key: ValueKey<int>(line.seed),
                        options: optionsForRow(
                          all: options,
                          takenIds: <String?>[
                            for (final _CashLine other in _lines) other.itemId,
                          ],
                          ownId: line.itemId,
                        ),
                        selectedId: line.itemId,
                        onSelected: (String id) => setState(() {
                          line.itemId = id;
                          // ★★ **والحدُّ الأدنى يُملأ اقتراحاً عند الاختيار**
                          //    — ⟵ **فالبيعُ المعتاد بالحد الأدنى لا يُكتَب**،
                          //    ⛔ **والمستخدم يملك رفعَه أو خفضَه بصلاحيته.**
                          if (line.price.text.isEmpty) {
                            line.price.text =
                                minimums[id]?.riyals.toString() ?? '';
                          }
                        }),
                        onRemove: () =>
                            setState(() => _lines.removeAt(index).dispose()),
                        fields: <Widget>[
                          _quantityField(line, itemsById[line.itemId]),
                          _priceField(line, minimums[line.itemId]),
                        ],
                      ),
                    if (items.isEmpty)
                      Text(
                        // ★ **والعلّةُ رصيدٌ لا ربطٌ** — [`DEBT-86`].
                        'لا مخزون في هذا المصدر اليوم.',
                        style: TypeScale.bodyMd
                            .copyWith(color: SemanticColors.textSecondary),
                      ),
                    if (items.isNotEmpty)
                      QtmsAddLineButton(
                        onPressed: _lines.length >= items.length
                            ? null
                            : () => setState(() => _lines.add(_CashLine())),
                      ),
                    if (isAmend) ...<Widget>[
                      const SizedBox(height: Spacing.space16),
                      // ⛔⛔★★★ **ولا يُعبَّأ آلياً أبداً** — `ADR-0020` القيد ①.
                      TextField(
                        controller: _reason,
                        decoration: const InputDecoration(
                          labelText: 'سبب التعديل (اختياري)',
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
            if (!isCancelled)
              Builder(
                builder: (BuildContext context) {
                  final List<CashSaleLineInput> lines = _linesFor(itemsById);
                  // ★★ **والقياسُ بدالة النطاق وحدها** — ⛔ **لا شرطٌ محليّ.**
                  // ⛔⛔★★★ **ولا استثناءَ لأحد** ([`CR-007`] · 2026-09-01):
                  //    ★ **الحدُّ الأدنى حدٌّ فعليّ** — ⛔ **ولا يقرأ هذا
                  //    الشرطُ مفتاحَ صلاحيةٍ إطلاقاً**، ⟵ **والسحابةُ ترفض
                  //    بالقاعدة نفسِها** (`_minimumPriceGate`).
                  final bool hasBelowMinimum = lines.any(
                    (CashSaleLineInput line) => isBelowMinimumCashPrice(
                      unitPrice: line.unitPrice,
                      minCashPrice: minimums[line.itemId],
                    ),
                  );
                  return QtmsStickyActionBar(
                    summary: _totals(lines, minimums),
                    status: switch ((_rejection, hasBelowMinimum)) {
                      (final CatalogMessage message, _) =>
                        QtmsActionStatus.rejection(catalogText(message)),
                      // ⛔⛔ **ونصُّ الكتالوج نفسُه الذي تردّ به السحابة** —
                      //    `ERR_PRICE_002`: ⟵ **فالرسالةُ واحدةٌ قبل الإرسال
                      //    وبعده**، ⛔ **ولا نصَّ ثانٍ يُخترَع للشاشة.**
                      (null, true) => QtmsActionStatus.rejection(
                          catalogText(CatalogMessage.belowMinimumCashPrice),
                        ),
                      (null, false) => null,
                    },
                    primary: PermissionGate(
                      permission: isAmend
                          ? Permission.cashSaleAmend
                          : Permission.cashSaleCreate,
                      child: FilledButton.icon(
                        // ⛔⛔★★★ **ولا حفظَ دون الحد بلا مفتاحه** — راجع أعلاه.
                        onPressed: _submitting || hasBelowMinimum
                            ? null
                            : () => _submit(existing, itemsById),
                        icon: const Icon(Icons.save_outlined),
                        label: Text(isAmend ? 'حفظ التعديل' : 'حفظ السند'),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _quantityField(_CashLine line, StockOption? item) => TextField(
        controller: line.quantity,
        keyboardType: TextInputType.numberWithOptions(
          decimal: item?.unit == ItemUnit.kilogram,
        ),
        // ⛔★★ **والكسر مرفوض في المعدود من المُدخِل نفسه**
        //    (`BR-M6-06` · `ERR_STOCK_002`).
        inputFormatters: <TextInputFormatter>[
          if (item?.unit == ItemUnit.kilogram)
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
          else
            FilteringTextInputFormatter.digitsOnly,
        ],
        decoration: InputDecoration(
          labelText: 'الكمية',
          suffixText: item == null ? null : unitName(item.unit),
        ),
        onChanged: (String _) => setState(() {}),
      );

  /// ★★★ حقلُ السعر — ⛔ **إلزاميٌّ ولا حالةَ فراغٍ مشروعة** (`FR-M11-04`).
  ///
  /// ★★ **ونصُّ المساعدة يقول الحدَّ الأدنى صراحةً** — ⟵ **فمن يخفضه يعرف
  /// أنه يخفضه**، ⛔ **ولا يكتشفه برفضٍ بعد الحفظ.**
  Widget _priceField(_CashLine line, Money? minimum) {
    final Money? entered = Money.tryParseInput(line.price.text.trim());
    // ★★ **والمقارنة بدالة النطاق وحدها** — ⛔ **لا شرطٌ محليّ** (`GR-34`).
    final bool below = entered != null &&
        isBelowMinimumCashPrice(unitPrice: entered, minCashPrice: minimum);
    return TextField(
      controller: line.price,
      keyboardType: const TextInputType.numberWithOptions(),
      // ⛔★★ **ولا كسرَ في مبلغ** — `ADR-0015`.
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.digitsOnly,
      ],
      decoration: InputDecoration(
        labelText: 'السعر',
        suffixText: 'ريال',
        // ⛔⛔★★ **ونصّان قصيران عمداً — عطلٌ رُصد حيّاً على `Pixel_6_API_36`**
        //    (2026-09-01): ★ **الحقل نصفُ عرضِ الصفّ**، ⟵ **والنصُّ الطويل
        //    كان يُقصّ إلى «… لا يوجد …»** ⛔ **فيقرأ المستخدم نصفَ السبب.**
        //    ★ **والنصُّ الكامل يبقى في `ERR_PRICE_005` حين يصل من السحابة.**
        helperText: minimum == null
            ? 'غير مسعَّر — لا حدَّ له'
            : 'الحد الأدنى ${minimum.riyals}',
        errorText: below ? 'أقل من الحد الأدنى' : null,
      ),
      onChanged: (String _) => setState(() {}),
    );
  }

  /// ★★ يملأ الحقول من السند القائم **مرةً واحدة لكل مستند**.
  /// ★★ يبذر النوعَ المثبَّت مرةً واحدة — ⛔ **ولا يُعاد عند كل بناء.**
  void _seedPinnedItem() {
    final String? pinned = widget.pinnedItemKey;
    if (pinned == null || _pinnedSeeded) return;
    _pinnedSeeded = true;
    _lines.add(_CashLine()..itemId = pinned);
  }

  void _seedFrom(CashSaleCard? card) {
    if (card == null || _seededId == card.documentNumber) return;
    _seededId = card.documentNumber;
    for (final _CashLine line in _lines) {
      line.dispose();
    }
    _lines
      ..clear()
      ..addAll(<_CashLine>[
        for (final ValidatedCashSaleLine line in card.lines)
          _CashLine(
            itemId: line.itemKey,
            quantity: switch (line.quantity) {
              PieceQuantity(:final PieceCount count) => '${count.pieces}',
              WeightQuantity(:final WeightKg weight) => weight.formatted(),
            },
            price: '${line.unitPrice.riyals}',
          ),
      ]);
  }

  void _onSourceChanged(String? id) {
    if (id == null || id == _sourceId) return;
    setState(() {
      _sourceId = id;
      // ⛔ **وتبديلُ المصدر يُفرِغ السطور** — ★ **فالأنواع والحدود والمتبقّي
      //   كلُّها مشتقّةٌ من المصدر** (`A-01`).
      for (final _CashLine line in _lines) {
        line.dispose();
      }
      _lines.clear();
      _seededId = null;
      // ⛔ **ويُعاد بذرُ النوع المثبَّت** — `FR-M8-12` (**النوع 🔒**).
      //   ⚠️ **والمصدرُ مقفلٌ أصلاً في التصريف المتأخر** — ★ **فهذا حارسٌ
      //   ثانٍ لا مسارٌ متوقَّع.**
      _pinnedSeeded = false;
      _rejection = null;
    });
  }

  /// ★ السطور المكتوبة فعلاً — ⛔ **والفارغ ليس سطراً**.
  ///
  /// ⛔⛔★★ **وسطرٌ بلا سعرٍ لا يُبنى إطلاقاً** (`FR-M11-04`) — ⟵ **فلا يمرّ
  /// إلى التحقق سطرٌ «غير مسعَّر»**: ★ **والزرُّ يبقى بلا أثرٍ حتى يكتمل.**
  List<CashSaleLineInput> _linesFor(Map<String, StockOption> itemsById) {
    final List<CashSaleLineInput> lines = <CashSaleLineInput>[];
    for (final _CashLine line in _lines) {
      final StockOption? item = itemsById[line.itemId];
      if (item == null) continue;
      final StockQuantity? quantity =
          _quantityOf(item.unit, line.quantity.text.trim());
      if (quantity == null) continue;
      final Money? unitPrice = Money.tryParseInput(line.price.text.trim());
      if (unitPrice == null) continue;
      lines.add(
        CashSaleLineInput(
          // ★★ **ومفتاحُ الدفتر هو المُرسَل** — `ADR-0007` · [`DEBT-86`].
          itemId: item.itemKey,
          itemName: item.itemName,
          unit: item.unit,
          quantity: quantity,
          unitPrice: unitPrice,
        ),
      );
    }
    return lines;
  }

  /// ★ الكمية بوحدة النوع — و`null` لمُدخَلٍ لا يصلح لتلك الوحدة.
  static StockQuantity? _quantityOf(ItemUnit unit, String text) {
    if (text.isEmpty) return null;
    switch (unit) {
      case ItemUnit.piece:
        final PieceCount? count = PieceCount.tryParseInput(text);
        return count == null ? null : PieceQuantity(count);
      case ItemUnit.kilogram:
        final WeightKg? weight = WeightKg.tryParseInput(text);
        return weight == null ? null : WeightQuantity(weight);
    }
  }

  Future<void> _submit(
    CashSaleCard? card,
    Map<String, StockOption> itemsById,
  ) async {
    final Outcome<ValidatedCashSale> validated = validateCashSale(
      CashSaleInput(sourceId: _sourceId, lines: _linesFor(itemsById)),
    );
    if (validated is Failure<ValidatedCashSale>) {
      setState(() => _rejection = CatalogMessage.operationFailed);
      return;
    }
    final ValidatedCashSale sale =
        (validated as Success<ValidatedCashSale>).value;

    setState(() {
      _submitting = true;
      _rejection = null;
    });

    final CashSaleAdminRepository repository = ref.read(cashSaleAdminProvider);
    final Outcome<void> outcome = card == null
        // ★★★ **وتاريخُ المخزون يُرسَل في التصريف المتأخر وحده** (`WU-019`).
        ? await repository.createCashSale(
            sale,
            stockDate: widget.pinnedStockDate,
          )
        : await repository.amendCashSale(
            documentNumber: card.documentNumber,
            sale: sale,
            amendReason: blankToNull(_reason.text),
          );
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _rejection =
          outcome is Failure<void> ? appErrorMessage(outcome.error) : null;
    });
    // ★ **وورقةٌ نجحت تُغلَق** — ⛔ **ولا تبقى مفتوحةً على مستندٍ حُفظ**:
    //   ⟵ **فالسجلُّ في القائمة خلفها هو الدليل.**
    if (outcome is Success<void> && mounted) Navigator.of(context).pop();
  }
}

/// ★★★ **الملخّصُ المالي الثابت** — §5b نمط `P8` البند ⑦ (`ADR-0021`).
///
/// ⛔⛔★★ **والإجماليان منفصلان دائماً** (`GR-19` · `FR-M11-14`).
///
/// ⚠️⚠️ **وصافي المقبوض يُحسَب بدالة النطاق وحدها** ([computeNetCashReceived]
/// و[cashSaleLineTotal]) — ⛔ **ولا ضربَ ولا جمعَ في الشاشة**: ★ **وهو نصُّ
/// `ADR-0010` القاعدة 1 و`CLAUDE.md` («لا تكرار لأي معادلة خارج طبقة
/// النطاق»)** — ⟵ **والفرقُ عن التوزيع أن السطور هنا مسعَّرةٌ حتماً**
/// (`FR-M11-04`) ⟹ **فالرقمُ نهائيٌّ لا تقديري.**
Widget _totals(List<CashSaleLineInput> lines, Map<String, Money> minimums) {
  int pieces = 0;
  double kilograms = 0;
  bool below = false;
  final List<Money> totals = <Money>[];
  for (final CashSaleLineInput line in lines) {
    switch (line.quantity) {
      case PieceQuantity(:final PieceCount count):
        pieces += count.pieces;
      case WeightQuantity(:final WeightKg weight):
        kilograms += weight.kilograms;
    }
    totals.add(
      cashSaleLineTotal(quantity: line.quantity, unitPrice: line.unitPrice),
    );
    if (isBelowMinimumCashPrice(
      unitPrice: line.unitPrice,
      minCashPrice: minimums[line.itemId],
    )) {
      below = true;
    }
  }
  return QtmsLiveSummary(
    headline: 'صافي المقبوض: ${computeNetCashReceived(totals).riyals} ريال',
    details: <String>[
      'إجمالي الحبات: $pieces حبة',
      'إجمالي الأوزان: ${kilograms.toStringAsFixed(WeightKg.decimals)} كجم',
      if (below) 'سطرٌ دون الحد الأدنى — يلزم تصريحٌ بالبيع دونه',
    ],
    emphasis: null,
  );
}

/// تحرير سطرٍ محلي — **نوعٌ وكميةٌ وسعر.**
class _CashLine {
  _CashLine({this.itemId, String quantity = '', String price = ''})
      : quantity = TextEditingController(text: quantity),
        price = TextEditingController(text: price),
        seed = _nextSeed++;

  static int _nextSeed = 0;

  /// النوع — و`null` تعني **صفّاً لم يُختَر نوعُه بعد**.
  String? itemId;

  /// الكمية المكتوبة.
  final TextEditingController quantity;

  /// ★★★ السعر المكتوب — ⛔ **وفراغُه يُسقِط السطر** (`FR-M11-04`).
  final TextEditingController price;

  /// مفتاحٌ ثابت للصفّ — ⛔ **ولا الموضعُ مفتاحاً.**
  final int seed;

  void dispose() {
    quantity.dispose();
    price.dispose();
  }
}

/// شاشة **الإتلاف** (`M8` · `FR-M8-16`) — **نمط 4** (`ui-guidelines.md` §3):
/// نموذجٌ بحقولٍ مجمَّعةٍ وزرٍّ أساسيٍّ ثابتٍ أسفل.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **ولا حقلَ سعرٍ ولا مبلغٍ في هذه الشاشة إطلاقاً** — `FR-M8-16`
/// (`BR-M8-11` · `GR-29`): ★ **غيابٌ بنيويٌّ لا تعطيلٌ بصري**، ⟵ **فما لا
/// حقلَ له لا يُرسَل ولا يُكتَب.** ★ **وهذا فارقُها الجوهري عن السحبية**
/// (`M22`) **التي تُخرِج قاتاً بقيمةٍ تستحقّ للرعوي.**
///
/// ⚠️⚠️★★★ **والنافذةُ تحمل تحذيراً صريحاً** — `FR-M8-16` نصّاً: ⟵ **فما
/// يُتلَف لا يعود قيمةً ولا يستحقّ الرعوي ثمنَه** (`A-15`)، ★ **والمستخدمُ
/// يقرأ ذلك قبل الحفظ لا بعده.**
///
/// ⛔⛔★★★ **والخياراتُ من أرصدة دفتر اليوم لا من كتالوج الأنواع** —
/// [`DEBT-86`] · `ADR-0007` · `ADR-0008`: ⟵ **فسطرُ الجونية لا سجلَّ نوعٍ له**،
/// ★ **وبناؤها من الكتالوج يُخفيه من كل قائمة فيُرفَض إتلافُه.**
///
/// ★★★ **والإتلافُ ثالثُ إجراءات تصريف المتبقي المتأخر** (`FR-M8-11`) —
/// ⟵ **فالشاشةُ تُفتَح مثبَّتةً على (مصدر × نوع × تاريخ مخزون) قديم**،
/// ★ **وشريطُ التنبيه بنصّ `FR-M8-12` حرفياً** ⛔ **والمصدرُ مقفلٌ حينها.**
///
/// ⚠️⚠️ **وكل ما هنا عرضٌ لا حماية** — ★ **والرفض الحقيقي في السحابة**
/// (`ADR-0013` القاعدة 3 · `RISK-02`): `disposals` **مغلقة للكتابة**،
/// **والصلاحيةُ والنطاقُ وتاريخُ المخزون والرصيدُ كلُّها في `planDisposal`.**
/// ═══════════════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qtms_domain/qtms_domain.dart';

import '../../../app/top_bar.dart';
import '../../../core/design/design_tokens.dart';
import '../../../core/device/device_preference_providers.dart';
import '../../../core/messages/error_messages.dart';
import '../../../core/ui/async_state_view.dart';
import '../../../core/ui/item_line_editor.dart';
import '../../../core/ui/live_summary.dart';
import '../../../core/ui/sticky_action_bar.dart';
import '../../identity_access/application/session_providers.dart';
import '../../master_data/application/master_data_providers.dart';
import '../application/aged_remainder_providers.dart';
import '../application/disposal_providers.dart';
import '../application/inventory_providers.dart';
import 'aged_remainder_screen.dart' show AgedClearanceBanner;
import 'inventory_widgets.dart' show itemOptionLabel, unitName;

/// شاشة الإتلاف.
class DisposalScreen extends ConsumerStatefulWidget {
  /// ينشئ الشاشة.
  const DisposalScreen({super.key});

  @override
  ConsumerState<DisposalScreen> createState() => _DisposalScreenState();
}

class _DisposalScreenState extends ConsumerState<DisposalScreen> {
  String? _sourceId;

  /// ★★ **تاريخُ مخزونٍ مثبَّت** — ⛔ **و`null` تعني «مخزون اليوم»**.
  CalendarDay? _pinnedStockDate;
  String? _pinnedItemKey;

  @override
  void initState() {
    super.initState();
    // 📦★★★ **وجهةُ التصريف المتأخر — تُفتَح مثبَّتة** (`FR-M8-11` ③).
    //
    // ⛔⛔★★★ **والاستهلاك بعد أول إطار لا داخل [initState]** — `DEBT-68`:
    //    ★ **`take()` *تكتب* حالةً، وRiverpod يمنع الكتابة في دورة حياة
    //    الويدجت.**
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      if (!mounted) return;
      final AgedClearanceFocus? aged = ref.read(agedClearanceFocusProvider);
      if (aged == null) return;
      ref.read(agedClearanceFocusProvider.notifier).take();
      setState(() {
        _sourceId = aged.sourceId;
        _pinnedStockDate = aged.stockDate;
        _pinnedItemKey = aged.itemKey;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<SourceCard> sources = ref.watch(activeSourcesProvider);
    // ⚠️⚠️ **وإخفاءٌ لا حماية** (`RISK-02`) — ★ **والحارس `disposalGate`.**
    final bool canCreate =
        ref.watch(hasPermissionProvider(Permission.disposalCreate));

    return Scaffold(
      appBar: const QtmsTopBar(screenTitle: 'الإتلاف'),
      body: !canCreate
          ? const QtmsEmptyState(
              spec: EmptyStateSpec(
                icon: Icons.lock_outline,
                title: 'لا صلاحية',
                message: 'ليست لديك صلاحية تسجيل الإتلاف — راجع مالك النظام.',
              ),
            )
          : Column(
              children: <Widget>[
                _DisposalHeader(
                  sources: sources,
                  sourceId: _sourceId,
                  // ⛔⛔★★★ **والمصدر مقفلٌ في التصريف المتأخر** — `FR-M8-12`.
                  locked: _pinnedStockDate != null,
                  onSource: (String? value) =>
                      setState(() => _sourceId = value),
                ),
                const Divider(height: Sizes.borderWidth),
                Expanded(
                  child: _sourceId == null
                      ? const QtmsEmptyState(
                          spec: EmptyStateSpec(
                            icon: Icons.store_outlined,
                            title: 'اختر المصدر',
                            message: 'المصدر إلزامي في كل مستند إتلاف — '
                                'والمخزون مستقلٌّ في كل مصدر.',
                          ),
                        )
                      : _DisposalForm(
                          // ★ **مفتاحٌ مركّب** — ⟵ **فتبديلُ المصدر يُعيد
                          //   بناء النموذج بحالةٍ نظيفة.**
                          key: ValueKey<String>(
                            '${_sourceId}_${_pinnedStockDate?.format() ?? ''}',
                          ),
                          sourceId: _sourceId!,
                          pinnedStockDate: _pinnedStockDate,
                          pinnedItemKey: _pinnedItemKey,
                        ),
                ),
              ],
            ),
    );
  }
}

/// رأس الشاشة — **المصدر وحده** (`ADR-0005`).
class _DisposalHeader extends StatelessWidget {
  const _DisposalHeader({
    required this.sources,
    required this.sourceId,
    required this.locked,
    required this.onSource,
  });

  final List<SourceCard> sources;
  final String? sourceId;
  final bool locked;
  final ValueChanged<String?> onSource;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: Spacing.screenPadding,
          vertical: Spacing.space8,
        ),
        // ⛔⛔★★★ **ولا «كل المصادر» هنا** — ★ **المصدر مفردٌ إلزامي**:
        //    ⟵ **والحركةُ تقع على مخزون مصدرٍ واحد** (`A-01`).
        child: DropdownButtonFormField<String>(
          key: const Key('disposal-source'),
          initialValue: sourceId,
          decoration: const InputDecoration(labelText: 'المصدر'),
          items: <DropdownMenuItem<String>>[
            for (final SourceCard source in sources)
              DropdownMenuItem<String>(
                value: source.sourceId,
                child: Text(source.name),
              ),
          ],
          onChanged: locked ? null : onSource,
        ),
      );
}

/// نموذج مستند الإتلاف — ★ **حالةٌ محلية حتى الحفظ**.
class _DisposalForm extends ConsumerStatefulWidget {
  const _DisposalForm({
    required this.sourceId,
    this.pinnedStockDate,
    this.pinnedItemKey,
    super.key,
  });

  final String sourceId;
  final CalendarDay? pinnedStockDate;
  final String? pinnedItemKey;

  @override
  ConsumerState<_DisposalForm> createState() => _DisposalFormState();
}

class _DisposalFormState extends ConsumerState<_DisposalForm> {
  final List<_LineDraft> _lines = <_LineDraft>[];
  final TextEditingController _reason = TextEditingController();
  bool _saving = false;
  bool _seeded = false;
  /// ★★★ **نتيجةُ النداء الأخيرة — نصٌّ وحُكم** (`AM-021` ④).
  ///
  /// ⛔⛔★★★ **ولا `String` وحدَها كما كانت** — `design-system.md` §6-ز:
  /// ⟵ **فالنجاحُ والفشلُ كانا يُقرآن سواءً**، ★ **والمعنى كلُّه على رمزٍ
  /// إيموجي واحد** (`✅`/`❌`) ⛔ **يتبع خطَّ الجهاز ولا يُلوَّن ولا يرث
  /// المقاس** (§8 المحظور 12): ⟹ **والحكمُ اليومَ حقلٌ مستقلٌّ يُترجَم ثلاثيةً.**
  _DisposalStatus? _status;

  @override
  void dispose() {
    for (final _LineDraft draft in _lines) {
      draft.dispose();
    }
    _reason.dispose();
    super.dispose();
  }

  /// ★★ **بذرُ النوع المثبَّت مرةً واحدة** — `FR-M8-12`.
  void _seedPinned() {
    final String? pinned = widget.pinnedItemKey;
    if (pinned == null || _seeded) return;
    _seeded = true;
    _lines.add(_LineDraft()..itemId = pinned);
  }

  Map<String, StockOption> _itemsById(CalendarDay day) =>
      <String, StockOption>{
        for (final StockOption item in ref.read(
          stockOptionsProvider(
            StockQuery(sourceId: widget.sourceId, stockDate: day),
          ),
        ))
          item.itemKey: item,
      };

  Future<void> _save(CalendarDay day) async {
    final Map<String, StockOption> items = _itemsById(day);
    final List<DisposalLineInput> lines = <DisposalLineInput>[
      for (final _LineDraft draft in _lines)
        if (draft.toInput(items) case final DisposalLineInput line) line,
    ];

    if (lines.isEmpty) {
      setState(
        () => _status = const _DisposalStatus(
          message: 'أضف نوعاً واحداً على الأقل بكميةٍ أكبر من صفر.',
          succeeded: false,
        ),
      );
      return;
    }

    setState(() {
      _saving = true;
      _status = null;
    });

    final Outcome<String> result =
        await ref.read(disposalAdminProvider).createDisposal(
              sourceId: widget.sourceId,
              lines: lines,
              // ⛔⛔★★★ **ولا يُرسَل تاريخٌ إلا عند التثبيت** — ★ **ويومُ
              //    المخزون من المنصّة** (`GR-54` · `E-41`).
              stockDate: widget.pinnedStockDate,
              reason: _reason.text,
            );
    if (!mounted) return;
    setState(() {
      _saving = false;
      _status = switch (result) {
        Success<String>(:final String value) => _DisposalStatus(
            message: 'سُجِّل الإتلاف $value',
            succeeded: true,
          ),
        Failure<String>(:final AppError error) => _DisposalStatus(
            message: catalogText(appErrorMessage(error)),
            succeeded: false,
          ),
      };
      if (result is Success<String>) {
        for (final _LineDraft draft in _lines) {
          draft.dispose();
        }
        _lines.clear();
        _reason.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // ★★★ **يومُ هذه الشاشة** — ⛔ **يومُ المنصّة إلا في التصريف المتأخر**
    //    (`FR-M8-12`): ⟵ **والأرصدةُ كلُّها منه.**
    final CalendarDay day = widget.pinnedStockDate ?? ref.watch(todayProvider);
    final bool isAged = widget.pinnedStockDate != null;
    _seedPinned();

    final List<StockOption> items = ref.watch(
      stockOptionsProvider(
        StockQuery(sourceId: widget.sourceId, stockDate: day),
      ),
    );
    final Map<String, StockOption> itemsById = <String, StockOption>{
      for (final StockOption item in items) item.itemKey: item,
    };

    // ★★ **تفضيلُ إظهار وزن الحبة** — `AM-012` §4.4: ⛔ **عرضٌ محضٌ.**
    final bool showPieceWeight = ref.watch(showPieceWeightProvider);
    final List<QtmsItemOption> options = <QtmsItemOption>[
      for (final StockOption item in items)
        QtmsItemOption(
          id: item.itemKey,
          // ⛔⛔★★★ **والمتبقّي جزءٌ من نصّ الخيار** — `AM-009` ⑥: ⟵ **فمن
          //    يُتلِف يرى كم بقي منه *في لحظة الاختيار*.**
          label: itemOptionLabel(
            item.itemName,
            item.balance,
            showPieceWeight: showPieceWeight,
            pieceWeightGrams: item.pieceWeightGrams,
          ),
        ),
    ];

    final List<StockQuantity> quantities = <StockQuantity>[
      for (final _LineDraft draft in _lines)
        if (draft.quantityOf(itemsById) case final StockQuantity quantity)
          quantity,
    ];

    return Column(
      children: <Widget>[
        Expanded(
          child: ListView(
            padding: const EdgeInsetsDirectional.all(Spacing.screenPadding),
            children: <Widget>[
              // ⚠️★★★ **وشريطُ التنبيه البارز** — `FR-M8-12` نصّاً.
              if (isAged) ...<Widget>[
                AgedClearanceBanner(stockDate: day),
                const SizedBox(height: Spacing.space16),
              ],
              const _DisposalWarning(),
              const SizedBox(height: Spacing.space16),
              Text('الأنواع المُتلَفة', style: TypeScale.titleSm),
              const SizedBox(height: Spacing.space8),
              if (_lines.isEmpty)
                Text(
                  'لا نوعَ بعد — أضف ما خرج من المخزن تالفاً.',
                  style: TypeScale.caption,
                )
              else
                for (final _LineDraft draft in _lines)
                  QtmsItemLineRow(
                    key: ValueKey<_LineDraft>(draft),
                    options: optionsForRow(
                      all: options,
                      takenIds: <String?>[
                        for (final _LineDraft other in _lines) other.itemId,
                      ],
                      ownId: draft.itemId,
                    ),
                    selectedId: draft.itemId,
                    onSelected: (String id) =>
                        setState(() => draft.itemId = id),
                    onRemove: () => setState(() {
                      _lines.remove(draft);
                      draft.dispose();
                    }),
                    fields: <Widget>[
                      TextField(
                        key: Key('disposal-qty-${_lines.indexOf(draft)}'),
                        controller: draft.quantity,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'الكمية المُتلَفة',
                          suffixText: draft.itemId == null
                              ? null
                              : _unitOrNull(itemsById[draft.itemId]?.unit),
                        ),
                        onChanged: (String _) => setState(() {}),
                      ),
                      // ⛔⛔★★★ **ولا حقلَ سعرٍ هنا** — `FR-M8-16`: ★ **غيابٌ
                      //    بنيويٌّ لا حقلٌ معطَّل** (راجع ترويسة الملف).
                    ],
                  ),
              QtmsAddLineButton(
                key: const Key('disposal-add-line'),
                onPressed: () => setState(() => _lines.add(_LineDraft())),
              ),
              const SizedBox(height: Spacing.space16),
              TextField(
                key: const Key('disposal-reason'),
                controller: _reason,
                decoration: const InputDecoration(
                  labelText: 'سبب الإتلاف',
                  // ★★ **ويُوسَم «اختياري» صراحةً** — `ADR-0020` ·
                  //   `ui-guidelines.md` §2: ⛔ **ولا يُعبَّأ آلياً.**
                  helperText: 'اختياري — ولا يُكتب نيابةً عنك',
                ),
              ),
            ],
          ),
        ),
        QtmsStickyActionBar(
          summary: QtmsLiveSummary(
            // ⛔⛔★★★ **وحصيلةُ كمياتٍ لا مبالغ** — `FR-M8-16`: ★ **ولا رقمَ
            //    ماليٌّ واحدٌ في هذه الشاشة.**
            headline: 'إجمالي المُتلَف: ${_totalsLabel(quantities)}',
            details: <String>[
              'تاريخ المخزون: ${day.formatReadable()}',
              // ⛔⛔★★★ **وتذكيرٌ صريحٌ بأثره** — `A-15`.
              'بلا قيمة مالية ولا استحقاق للرعوي',
            ],
          ),
          // ★★★ **لافتةُ الحالة بثلاثيةٍ كاملة** — `AM-021` ④
          //    (`design-system.md` §6-ز): ★ **تعبئةٌ وحدٌّ ولونُ مقدّمةٍ
          //    وأيقونةٌ متجهية** ⛔ **لا نصٌّ عارٍ برمزٍ إيموجي.**
          status: switch (_status) {
            null => null,
            _DisposalStatus(succeeded: true, :final String message) =>
              QtmsActionStatus.success(message),
            _DisposalStatus(:final String message) =>
              QtmsActionStatus.rejection(message),
          },
          primary: FilledButton(
            key: const Key('disposal-save'),
            onPressed: _saving ? null : () => _save(day),
            child: Text(_saving ? 'جارٍ الحفظ…' : 'حفظ الإتلاف'),
          ),
        ),
      ],
    );
  }

  /// ★ إجماليان منفصلان — ⛔ **ولا تُجمع حبّةٌ مع كيلوجرام** (`GR-19`).
  static String _totalsLabel(List<StockQuantity> quantities) {
    int pieces = 0;
    double kilograms = 0;
    for (final StockQuantity quantity in quantities) {
      switch (quantity) {
        case PieceQuantity(:final PieceCount count):
          pieces += count.pieces;
        case WeightQuantity(:final WeightKg weight):
          kilograms += weight.kilograms;
      }
    }
    return '$pieces حبة · ${WeightKg(kilograms).formatted()} كجم';
  }

  static String? _unitOrNull(ItemUnit? unit) =>
      unit == null ? null : unitName(unit);
}

/// ⚠️★★★ **تحذيرُ النافذة الصريح** — `FR-M8-16` نصّاً.
///
/// ⛔⛔★★ **وليس زخرفةً:** ★ **الإتلافُ العمليةُ الوحيدة التي تُخرِج قاتاً
/// بلا مقابلٍ ولا استحقاق** (`A-15`) — ⟵ **ومستخدمٌ يظنّها «صرفاً» يُسقِط
/// إيراداً كان يستحقّه الرعوي.** ★ **والشريطُ لحالةٍ قائمة لا حدثٍ عابر**
/// (`design-system.md` §6.ز).
class _DisposalWarning extends StatelessWidget {
  const _DisposalWarning();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsetsDirectional.all(Spacing.space12),
        decoration: BoxDecoration(
          color: SemanticTriads.warning.soft,
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(color: SemanticTriads.warning.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // ⛔ **ولا معنى يُنقَل باللون وحده** — §8 المحظور الثاني عشر.
            Icon(
              Icons.warning_amber_outlined,
              size: Sizes.iconMd,
              color: SemanticTriads.warning.ink,
            ),
            const SizedBox(width: Spacing.space8),
            Expanded(
              child: Text(
                'الإتلاف يخرج من المخزون بلا أي قيمة مالية ولا استحقاق '
                'للرعوي — ولا يدخل في سعر الجونية ولا في تقارير المبيعات.',
                style: TypeScale.bodyMd
                    .copyWith(color: SemanticTriads.warning.ink),
              ),
            ),
          ],
        ),
      );
}

/// مسوّدةُ سطرٍ — ★ **حالةٌ محلية حتى الحفظ**.
class _LineDraft {
  final TextEditingController quantity = TextEditingController();
  String? itemId;

  void dispose() => quantity.dispose();

  /// ★ الكميةُ بوحدة النوع — و`null` **لمُدخَلٍ لا يصلح**.
  StockQuantity? quantityOf(Map<String, StockOption> items) {
    final String? id = itemId;
    if (id == null) return null;
    final StockOption? item = items[id];
    if (item == null) return null;
    final num? raw = num.tryParse(quantity.text.trim());
    if (raw == null || raw <= 0) return null;
    return switch (item.unit) {
      // ⛔ **والكسر يُرفَض للنوع المعدود** — `BR-M6-06`.
      ItemUnit.piece =>
        raw == raw.roundToDouble() ? PieceQuantity(PieceCount(raw.toInt())) : null,
      ItemUnit.kilogram => WeightQuantity(WeightKg(raw.toDouble())),
    };
  }

  /// ★ مُدخَلُ السطر — و`null` **لسطرٍ ناقص**.
  DisposalLineInput? toInput(Map<String, StockOption> items) {
    final String? id = itemId;
    if (id == null) return null;
    final StockOption? item = items[id];
    final StockQuantity? amount = quantityOf(items);
    if (item == null || amount == null) return null;
    return DisposalLineInput(
      itemId: id,
      // ★ **الاسمُ من الدفتر لا من كتالوجٍ** — [`DEBT-86`] ③.
      itemName: item.itemName,
      unit: item.unit,
      quantity: amount,
      // ★ **ومرجعُ الجونية تشتقّه السحابةُ من الدفتر** — [`DEBT-86`] ②:
      //   ⛔ **ولا حقلَ له في هذه الشاشة.**
    );
  }
}

/// ★★★ **نتيجةُ نداءِ الإتلاف — نصُّها وحُكمُها** (`AM-021` ④).
///
/// ⛔⛔★★★ **والحكمُ حقلٌ لا رمزٌ في النصّ** — `design-system.md` §6-ز:
/// ⟵ **فالشاشةُ تترجمه ثلاثيةً لونيةً كاملة** (`QtmsActionStatus`)،
/// ⛔ **ولا تُفتّش عن `✅` في أول النصّ لتعرف أنجح الفعلُ أم فشل.**
@immutable
class _DisposalStatus {
  const _DisposalStatus({required this.message, required this.succeeded});

  /// النصّ — ★ **من الكتالوج عند الفشل** ⛔ **ولا صياغةَ خطأٍ هنا.**
  final String message;

  /// ★ هل نجح النداء؟ — ⛔ **ولا حالةَ ثالثة: الغيابُ `null` في الحقل نفسِه.**
  final bool succeeded;
}

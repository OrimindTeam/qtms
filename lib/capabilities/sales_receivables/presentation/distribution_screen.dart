/// شاشة **التوزيع والضمار** (`M10`) — **أكثر العمليات تكراراً في اليوم**.
///
/// ★ **هدف الأداء: توزيعة معتادة في أقل من 30 ثانية** (`FR-M10`) — ⟵ **ولهذا
/// المقوت والمصدر في الأعلى، والسطور صفٌّ واحد لكل نوع**، ⛔ **ولا خطوات.**
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **وأخطر ما يُساء فهمه في هذه الشاشة — `ت-12` (`FR-M10-07`):**
///
/// **إخفاء عمود السعر لا يعني أن التوزيعة بلا سعر.** ⟵ **السعر يُطبَّق من
/// التسعير اليومي تلقائياً، وقيمة الضمار تُحتسب كاملة، والمديونية تُقيَّد
/// بها** — ★ **والمستخدم لا يراها فقط.**
///
/// ⟵ **ولهذا يُرسَل السعر المقترَح دائماً** حتى ممن لا يملك رؤيته:
/// [suggestedDistributionPricesProvider]، ⛔ **وإسقاطُه كان سيُنشئ ضماراً
/// بصفر لمقوتٍ استلم بضاعة.**
/// ═══════════════════════════════════════════════════════════════════════
///
/// ⚠️⚠️ **وكل ما هنا عرضٌ لا حماية** — ★ **والرفض الحقيقي في السحابة**
/// (`ADR-0013` القاعدة 3 · `RISK-02`): `distributions` **مغلقة للكتابة**،
/// **والصلاحية والنطاق والرصيد و`GR-18` وحارس السعر كلها في
/// `planDistribution`.**
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show FilteringTextInputFormatter, TextInputFormatter;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qtms_domain/qtms_domain.dart';

import '../../../core/design/design_tokens.dart';
import '../../../core/messages/error_messages.dart';
import '../../../core/ui/async_state_view.dart';
import '../../../core/ui/context_header.dart';
import '../../../core/ui/live_summary.dart';
import '../../../core/ui/skeleton.dart';
import '../../../core/ui/sticky_action_bar.dart';
import '../../master_data/application/master_data_providers.dart';
import '../../identity_access/application/session_providers.dart';
import '../../identity_access/presentation/permission_gate.dart';
import '../../inventory/application/inventory_providers.dart';
import '../../inventory/presentation/inventory_widgets.dart';
import '../../oversight/presentation/audit_trail_view.dart';
import '../application/distribution_providers.dart';
import '../../../core/ui/optional_reason.dart';

/// شاشة التوزيع.
class DistributionScreen extends ConsumerWidget {
  /// ينشئ الشاشة.
  const DistributionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CalendarDay today = ref.watch(todayProvider);
    final String? sourceId = ref.watch(selectedSourceProvider);
    final List<SourceCard> sources = ref.watch(activeSourcesProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: SemanticColors.surface,
        title: const Text('التوزيع', style: TypeScale.titleSm),
      ),
      body: Column(
        children: <Widget>[
          // ★★★ **رأس السياق الموحّد** — §5b نمط `P3` (`ADR-0021`).
          //
          // ⛔⛔★★ **وكان رأسُ هذه الشاشة أربعةَ مستويات** (منتقي مصدر +
          //    لافتةُ يوم + منتقي مقوت + فاصل) — ★ **على شاشةٍ هدفُها
          //    توزيعةٌ في أقل من 30 ثانية** (`FR-M10`): ⟵ **فصار مستويين.**
          QtmsContextHeader(
            sources: sources,
            selectedSourceId: sourceId,
            onSourceSelected: (String id) =>
                ref.read(selectedSourceProvider.notifier).select(id),
            day: today,
          ),
          Expanded(
            // ⛔⛔★★★ **ولا `SizedBox.shrink` حالةً لغياب المصدر** — §5b `P3`.
            child: sourceId == null
                ? QtmsEmptyState(
                    spec: sources.isEmpty
                        ? noSourceInScopeEmpty
                        : chooseSourceEmpty(),
                  )
                : _DistributionBody(
                    key: ValueKey<String>('$sourceId-$today'),
                    query: DistributionQuery(
                      sourceId: sourceId,
                      stockDate: today,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _DistributionBody extends ConsumerStatefulWidget {
  const _DistributionBody({required this.query, super.key});

  final DistributionQuery query;

  @override
  ConsumerState<_DistributionBody> createState() => _DistributionBodyState();
}

class _DistributionBodyState extends ConsumerState<_DistributionBody> {
  String? _dealerId;

  @override
  Widget build(BuildContext context) {
    final List<DealerCard> dealers = ref.watch(distributionDealersProvider);
    final String? dealerId = _dealerId;

    return Column(
      children: <Widget>[
        _DealerPicker(
          dealers: dealers,
          selected: dealerId,
          onSelected: (String id) => setState(() => _dealerId = id),
        ),
        const Divider(height: 1),
        Expanded(
          child: dealerId == null
              ? const _EmptyHint('اختر المقوت لبدء التوزيع')
              : _DistributionForm(
                  key: ValueKey<String>(dealerId),
                  query: widget.query,
                  dealerId: dealerId,
                  dealerName: dealers
                      .firstWhere(
                        (DealerCard d) => d.dealerId == dealerId,
                        orElse: () => dealers.first,
                      )
                      .name,
                ),
        ),
      ],
    );
  }
}

/// ★ منتقي المقوت — ⛔ **ولا يظهر فيه معطَّل** (`FR-M10-12`).
class _DealerPicker extends StatelessWidget {
  const _DealerPicker({
    required this.dealers,
    required this.selected,
    required this.onSelected,
  });

  final List<DealerCard> dealers;
  final String? selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.space16,
          vertical: Spacing.space8,
        ),
        child: DropdownButtonFormField<String>(
          initialValue: selected,
          decoration: const InputDecoration(labelText: 'المقوت'),
          items: <DropdownMenuItem<String>>[
            for (final DealerCard dealer in dealers)
              DropdownMenuItem<String>(
                value: dealer.dealerId,
                child: Text(dealer.name),
              ),
          ],
          onChanged: (String? value) {
            if (value != null) onSelected(value);
          },
        ),
      );
}

/// نموذج التوزيعة — ★ **حالةٌ محلية حتى الحفظ**.
///
/// ⚠️⚠️ **ويفتح الموجود للتعديل تلقائياً** — `FR-M10-01` (`E-04`):
/// «**عند المحاولة يُفتح المستند الموجود للتعديل ولا يُنشأ مستند ثانٍ**».
/// ⟵ ★ **والشاشة تعرف ذلك قبل الحفظ** بمراقبة المعرّف المركّب،
/// ⛔ **فلا تُرسل إنشاءً يُرفَض.**
class _DistributionForm extends ConsumerStatefulWidget {
  const _DistributionForm({
    required this.query,
    required this.dealerId,
    required this.dealerName,
    super.key,
  });

  final DistributionQuery query;
  final String dealerId;
  final String dealerName;

  @override
  ConsumerState<_DistributionForm> createState() => _DistributionFormState();
}

class _DistributionFormState extends ConsumerState<_DistributionForm> {
  final Map<String, _LineEdit> _edits = <String, _LineEdit>{};
  final TextEditingController _reason = TextEditingController();
  bool _submitting = false;
  bool _saved = false;
  CatalogMessage? _rejection;

  /// ★ المعرّف المركّب — **وهو ما يُفتَح به الموجود** (`GR-18`).
  String get _compositeId => distributionId(
        dealerId: widget.dealerId,
        sourceId: widget.query.sourceId,
        stockDate: widget.query.stockDate,
      );

  @override
  void dispose() {
    _reason.dispose();
    for (final _LineEdit edit in _edits.values) {
      edit.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ⛔⛔★★★ **ومن قائمة اليوم لا بقراءةٍ بالمعرّف** — راجع
    //    [dealerDistributionProvider]: **القراءة بالمعرّف تُرفَض على المستند
    //    الغائب**، ⟵ **وهو أشيعُ حالات `E-04`.**
    final AsyncValue<DistributionCard?> existing = ref.watch(
      dealerDistributionProvider(
        DealerDistributionQuery(
          sourceId: widget.query.sourceId,
          dealerId: widget.dealerId,
          stockDate: widget.query.stockDate,
        ),
      ),
    );
    final List<ItemCard> items =
        ref.watch(distributionItemsProvider(widget.query.sourceId));
    // ⛔⛔★★★ **ويُراقَب لا يُقرأ لحظة الحفظ** — ⟵ **فالقراءة المتأخرة كانت
    //   تجد التدفّق لم يُشترَك بعد فتعود فارغة**، ★ **فيُرسَل السطر بلا سعر
    //   وينشأ ضمارٌ بصفر لمقوتٍ استلم بضاعة** (`FR-M10-07`).
    final Map<String, Money> suggested =
        ref.watch(suggestedDistributionPricesProvider(widget.query));

    // ★ **تدفّقٌ لمستندٍ واحد لا لقائمة** — ⟵ **فلا يُستعمَل عارضُ القوائم**،
    //   ⛔ **والغياب حالةٌ طبيعية لا «فراغ» يُعرَض بلوحة.**
    return existing.when(
      // ⛔★★ **والهيكل العظمي وحده حالةً للتحميل** — `ui-guidelines.md` §هـ
      //    (بوابة الحِرفية البصرية): ⟵ **ولا مؤشّر دوّار خارج استثنائَيه.**
      loading: () => const SkeletonList(),
      error: (Object _, StackTrace _) => const _EmptyHint(
        'تحقق من صلاحيتك ونطاق مصادرك، ثم أعد المحاولة.',
      ),
      data: (DistributionCard? card) {
        _seedFrom(card, items);
        return _content(card, items, suggested);
      },
    );
  }

  /// ★★ يملأ الحقول من التوزيعة القائمة **مرةً واحدة** — `E-04`.
  ///
  /// ⛔ **ولا يُعيد الملء عند كل بناء** — ⟵ **وإلا مسح ما يكتبه المستخدم
  /// كلما وصل تحديثٌ من جهازٍ آخر.**
  void _seedFrom(DistributionCard? card, List<ItemCard> items) {
    if (card == null || _edits.isNotEmpty) return;
    for (final ValidatedDistributionLine line in card.lines) {
      _edits[line.itemKey] = _LineEdit(
        quantity: switch (line.quantity) {
          PieceQuantity(:final PieceCount count) => '${count.pieces}',
          WeightQuantity(:final WeightKg weight) => weight.formatted(),
        },
      );
    }
  }

  Widget _content(
    DistributionCard? card,
    List<ItemCard> items,
    Map<String, Money> suggested,
  ) {
    final bool isAmend = card != null;
    final bool isCancelled = card?.isCancelled ?? false;
    final AsyncValue<DistributionPricingCard?> pricing =
        ref.watch(distributionPricingProvider(_compositeId));
    final bool canSeePrices =
        ref.watch(hasPermissionProvider(Permission.distributionPriceView));

    // ★★★ **نمط `P8`** (`MASTER.md` §5b · `ADR-0021`): **الملخّصُ المالي
    //    والزرُّ الأساسي ثابتان أسفل الشاشة، والمدمّرُ في ذيل المحتوى.**
    if (isCancelled) {
      return const _EmptyHint('هذه التوزيعة ملغاة — لا يمكن تعديلها');
    }

    return Column(
      children: <Widget>[
        Expanded(
          child: ListView(
            padding: const EdgeInsetsDirectional.all(Spacing.screenPadding),
            children: <Widget>[
              if (isAmend)
                _ExistingBanner(card: card, sourceId: widget.query.sourceId),
              for (final ItemCard item in items)
                _LineRow(
                  item: item,
                  edit: _editFor(item.itemId),
                  onChanged: () => setState(() {}),
                ),
              if (isAmend) ...<Widget>[
                const SizedBox(height: Spacing.space16),
                // ⛔⛔★★★ **ولا يُعبَّأ آلياً أبداً** — `CLAUDE.md`: **ما لم
                //    يكتبه إنسانٌ لا يُرسَل** (`ADR-0020` القيد ①).
                TextField(
                  controller: _reason,
                  decoration: const InputDecoration(
                    labelText: 'سبب التعديل (اختياري)',
                  ),
                ),
              ],
              // ⑨ ⛔⛔★★★ **والمدمّر في ذيل المحتوى الممرَّر** — §5b `P8`:
              //    ★ **كان ملاصقاً لزرّ الحفظ بنفس العرض** ⟵ **وإصبعٌ
              //    مستعجلة تُخطئ بمقدار 8dp** ⛔ **على مستندٍ لا يُحذَف ولا
              //    يُتراجَع عن إلغائه.** ★ **وبلون `danger` واللفظُ صريح.**
              if (isAmend) ...<Widget>[
                const SizedBox(height: Spacing.space24),
                // ⛔★★ **ولا زر حذف إطلاقاً** — `GR-07`.
                PermissionGate(
                  permission: Permission.distributionCancel,
                  child: OutlinedButton.icon(
                    onPressed: _submitting ? null : () => _cancel(card),
                    icon: const Icon(Icons.block_outlined),
                    label: const Text('إلغاء التوزيعة'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: SemanticTriads.danger.ink,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        // ⑦⑧ ⛔⛔★★★ **والملخّصُ المالي ثابتٌ فوق الزرّ** — §5b `P8`:
        //    ★ **كان بعد كل الصفوف في محتوىً ممرَّر** ⟵ **فلا يُرى أثناء
        //    الإدخال أصلاً**، ⛔ **فيكتب المستخدم كمياتٍ وهو لا يرى قيمة
        //    الضمار التي يُقيّدها على المقوت** (`ت-12`).
        QtmsStickyActionBar(
          summary: _totals(
            _linesFor(items, suggested),
            // ⛔⛔★★ **والإجمالي المالي لمن يملك رؤيته وحده** (`ت-12`) —
            //    ★ **والمصدر مستند الأسعار لا حسابٌ محليّ**: ⟵ **فما يراه
            //    المستخدم هو ما كُتب فعلاً.**
            canSeePrices ? pricing.value?.debtValue : null,
          ),
          status: switch ((_rejection, _saved)) {
            (final CatalogMessage message, _) =>
              QtmsActionStatus.rejection(catalogText(message)),
            (null, true) => QtmsActionStatus.success('تم الحفظ.'),
            _ => null,
          },
          primary: PermissionGate(
            permission: isAmend
                ? Permission.distributionAmend
                : Permission.distributionCreate,
            child: FilledButton.icon(
              onPressed:
                  _submitting ? null : () => _submit(card, items, suggested),
              icon: const Icon(Icons.save_outlined),
              label: Text(isAmend ? 'حفظ التعديل' : 'حفظ التوزيعة'),
            ),
          ),
        ),
      ],
    );
  }

  _LineEdit _editFor(String itemId) =>
      _edits.putIfAbsent(itemId, _LineEdit.new);

  /// ★ السطور المكتوبة فعلاً — ⛔ **والفارغ ليس سطراً**.
  List<DistributionLineInput> _linesFor(
    List<ItemCard> items,
    Map<String, Money> suggested,
  ) {
    final List<DistributionLineInput> lines = <DistributionLineInput>[];
    for (final ItemCard item in items) {
      final _LineEdit? edit = _edits[item.itemId];
      final String text = edit?.quantity.text.trim() ?? '';
      if (text.isEmpty) continue;
      final StockQuantity? quantity = _quantityOf(item.unit, text);
      if (quantity == null) continue;
      lines.add(
        DistributionLineInput(
          itemId: item.itemId,
          itemName: item.name,
          unit: item.unit,
          quantity: quantity,
          // ★★ **ويُرسَل حتى لمن لا يراه** — راجع ترويسة الملف (`ت-12`).
          unitPrice: suggested[item.itemId],
        ),
      );
    }
    return lines;
  }

  /// ★ الكمية بوحدة النوع — و`null` لمُدخَلٍ لا يصلح لتلك الوحدة.
  ///
  /// ⛔★★ **والكسر يُرفَض للمعدود في النوع نفسه** (`BR-M6-06`).
  static StockQuantity? _quantityOf(ItemUnit unit, String text) {
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
    DistributionCard? card,
    List<ItemCard> items,
    Map<String, Money> suggested,
  ) async {
    final Outcome<ValidatedDistribution> validated = validateDistribution(
      DistributionInput(
        sourceId: widget.query.sourceId,
        dealerId: widget.dealerId,
        lines: _linesFor(items, suggested),
      ),
    );
    if (validated is Failure<ValidatedDistribution>) {
      setState(() => _rejection = CatalogMessage.operationFailed);
      return;
    }
    final ValidatedDistribution distribution =
        (validated as Success<ValidatedDistribution>).value;

    setState(() {
      _submitting = true;
      _rejection = null;
      _saved = false;
    });

    final DistributionAdminRepository repository =
        ref.read(distributionAdminProvider);
    final Outcome<void> outcome = card == null
        ? await repository.createDistribution(distribution)
        : await repository.amendDistribution(
            documentNumber: card.documentNumber,
            distribution: distribution,
            amendReason: blankToNull(_reason.text),
          );
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _saved = outcome is Success<void>;
      _rejection = outcome is Failure<void>
          ? appErrorMessage(outcome.error)
          : null;
    });
  }

  Future<void> _cancel(DistributionCard card) async {
    setState(() {
      _submitting = true;
      _rejection = null;
      _saved = false;
    });
    final Outcome<void> outcome =
        await ref.read(distributionAdminProvider).cancelDistribution(
              documentNumber: card.documentNumber,
              sourceId: card.sourceId,
              dealerId: card.dealerId,
              cancelReason: blankToNull(_reason.text),
            );
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _saved = outcome is Success<void>;
      _rejection = outcome is Failure<void>
          ? appErrorMessage(outcome.error)
          : null;
    });
  }
}

/// ★ صفّ نوعٍ واحد — **كميةٌ بوحدتها** ⛔ **بلا حقل سعر**.
///
/// ⛔⛔★★ **ولا عمود سعرٍ في هذه الشاشة إطلاقاً** — ★ **السعر من التسعير
/// اليومي** (`FR-M10-09`)، ⟵ **وتعديلُه شاشتُه هي التسعير**، ⛔ **وحقلٌ هنا
/// كان سيُلزم كل موزّع بصلاحية تسعير.**
class _LineRow extends StatelessWidget {
  const _LineRow({
    required this.item,
    required this.edit,
    required this.onChanged,
  });

  final ItemCard item;
  final _LineEdit edit;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: Spacing.space8),
        child: Row(
          children: <Widget>[
            Expanded(flex: 3, child: Text(item.name, style: TypeScale.bodyMd)),
            Expanded(
              flex: 2,
              child: TextField(
                controller: edit.quantity,
                keyboardType: TextInputType.numberWithOptions(
                  decimal: item.unit == ItemUnit.kilogram,
                ),
                // ⛔★★ **والكسر مرفوض في المعدود من المُدخِل نفسه**
                //    (`BR-M6-06` · `ERR_STOCK_002`).
                inputFormatters: <TextInputFormatter>[
                  if (item.unit == ItemUnit.piece)
                    FilteringTextInputFormatter.digitsOnly
                  else
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: InputDecoration(
                  isDense: true,
                  suffixText: unitName(item.unit),
                ),
                onChanged: (String _) => onChanged(),
              ),
            ),
          ],
        ),
      );
}

/// ★★★ **الملخّصُ المالي الثابت** — §5b نمط `P8` البند ⑦ (`ADR-0021`).
///
/// ⛔⛔★★ **والإجماليان منفصلان دائماً** (`GR-19` · `FR-M10-15`) — ★ **سطران
/// مستقلّان في [QtmsLiveSummary.details]** ⛔ **ولا سطرَ ثالثٌ يجمعهما.**
///
/// ★★ **وكان `Card` محلّياً** (`_Totals`) — ⟵ **وهو خامسُ صياغةٍ لملخّصٍ حيّ**:
/// ⛔ **والمحظور الحادي عشر يمنع النسخة الثانية فضلاً عن الخامسة** (§8).
///
/// ⚠️ **والجمعُ هنا عرضٌ لا معادلة** — ★ **مجموعُ ما كتبه المستخدمُ لحظتَه**،
/// ⛔ **ولا قاعدةَ عملٍ فيه** (`ADR-0010` القاعدة 1).
Widget _totals(List<DistributionLineInput> lines, Money? debtValue) {
  int pieces = 0;
  double kilograms = 0;
  for (final DistributionLineInput line in lines) {
    switch (line.quantity) {
      case PieceQuantity(:final PieceCount count):
        pieces += count.pieces;
      case WeightQuantity(:final WeightKg weight):
        kilograms += weight.kilograms;
    }
  }
  return QtmsLiveSummary(
    headline: 'إجمالي الحبات: $pieces حبة',
    details: <String>[
      'إجمالي الأوزان: ${kilograms.toStringAsFixed(WeightKg.decimals)} كجم',
    ],
    // ⛔⛔★★ **وقيمة الضمار لمن يملك رؤيتها وحده** (`ت-12`) —
    //    ★ **و`null` غيابٌ لا فراغ.**
    emphasis: switch (debtValue) {
      final Money value => 'قيمة الضمار: ${value.riyals} ريال',
      null => null,
    },
  );
}

/// ★★ شارة «يوجد توزيع — سيُفتح للتعديل» — `E-04` · `ERR_DIST_001`.
class _ExistingBanner extends ConsumerWidget {
  const _ExistingBanner({required this.card, required this.sourceId});

  final DistributionCard card;
  final String sourceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(
        color: SemanticColors.surfaceSunken,
        child: ListTile(
          // ★★ **أيقونة 🕘 السجل السياقي** — `FR-M18-10`.
          leading: auditTrailLeading(
            ref,
            entityType: distributionEntityType,
            entityId: card.distributionId,
            title: card.documentNumber,
            sourceId: sourceId,
          ),
          title: Text(card.documentNumber, style: TypeScale.bodyMd),
          subtitle: Text(
            'يوجد توزيع لهذا المقوت اليوم — فُتح للتعديل'
            '${card.amendCount > 0 ? ' · مُعدَّل ×${card.amendCount}' : ''}'
            '${card.hasUnpricedLines ? ' · ⏳ سعر غير نهائي' : ''}',
          ),
        ),
      );
}

// ⛔⛔★★ **ولافتتا الرفض والنجاح المحليّتان حُذفتا** — ★ **حلّ محلّهما
// [QtmsActionStatus] داخل الشريط الثابت** (§5b `P8`): ⟵ **فسقط معهما
// «✅» الإيموجي** (§9) ⛔ **وسقط قفزُ الزرّ عند ظهور اللافتة.**

class _EmptyHint extends StatelessWidget {
  const _EmptyHint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(Spacing.space24),
        child: Text(text, style: TypeScale.bodyMd),
      );
}

/// تحرير سطرٍ محلي.
class _LineEdit {
  _LineEdit({String quantity = ''})
      : quantity = TextEditingController(text: quantity);

  final TextEditingController quantity;

  void dispose() => quantity.dispose();
}

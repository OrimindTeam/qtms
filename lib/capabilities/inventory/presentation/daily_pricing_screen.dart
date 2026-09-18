/// شاشة **التسعير اليومي** (`M9`) — **نمط 2** (`ui-guidelines.md` §3).
///
/// ⛔★★ **ولا تعرض إلا ما له كمية في مخزون اليوم** — `FR-M9-02` (`BR-M9-01`
/// · `E-33`): «**النوع الذي لا كمية له اليوم لا يظهر ولا يُطالَب بتسعيره**».
/// ★ **والقائمة تُبنى من الرصيد** (`pricingRowsProvider`) ⛔ **لا من قائمة
/// الأنواع.**
///
/// ⛔★★ **ولا ترحيل تلقائي لأسعار أمس** — `FR-M9-01` (`GR-31`): **كل يوم
/// يبدأ بلا أسعار**. ★ **و«نسخ أسعار أمس» زرٌّ يملأ الحقول للمراجعة**
/// (`FR-M9-13`) — ⛔ **ولا يحفظ شيئاً حتى يضغط المستخدم «حفظ»**، ⟵ **فهو
/// «نسخٌ صريح بإرادة المستخدم لا ترحيل تلقائي صامت»** حرفياً.
///
/// ⚠️⚠️ **وكل ما هنا عرضٌ لا حماية** — ★ **والرفض الحقيقي في السحابة**
/// (`ADR-0013` القاعدة 3 · `RISK-02`): `daily_prices` **مغلقة للكتابة**،
/// **والصلاحية والنطاق والرصيد كلها تُفحَص في `planDailyPricing`.**
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show FilteringTextInputFormatter, TextInputFormatter;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qtms_domain/qtms_domain.dart';

import '../../../app/top_bar.dart';

import '../../../core/design/design_tokens.dart';
import '../../../core/messages/error_messages.dart';
import '../../../core/ui/async_state_view.dart';
import '../../../core/ui/context_header.dart';
import '../../../core/ui/filter_bar.dart';
import '../../../core/ui/sticky_action_bar.dart';
import '../../master_data/application/master_data_providers.dart';
import '../../identity_access/presentation/permission_gate.dart';
import '../application/inventory_providers.dart';
import 'inventory_widgets.dart';
import '../../../core/ui/optional_reason.dart';

/// ★ نصُّ زرّ الحفظ — ⛔ **ومصدرٌ واحد يقرؤه الزرُّ والاختبار.**
const String dailyPricingSaveLabel = 'حفظ أسعار اليوم';

/// ★★ نصُّ الزرّ أثناء النداء — `design-system.md` §6-ي البند ② (`AM-021` ②).
const String dailyPricingSavingLabel = 'جارٍ الحفظ…';

/// ★★ **عنوانُ الفراغ حين يكون سببُه المرشِّحَ وحدَه** — `AM-021` ③.
///
/// ⛔⛔★★★ **وهو ليس فراغَ البيانات** — `design-system.md` §هـ: ⟵ **ورسالةُ
/// «لا شيء يُسعَّر بعد» فوق يومٍ سُعِّر بالكامل تقول عكسَ الحقيقة تماماً**،
/// ⛔ **وتدفع المستخدمَ يسجّل وارداً لا يحتاجه.**
const String pricingFilteredEmptyTitle =
    'كل الأنواع مسعَّرة بالفعل ضمن هذا المرشِّح';

/// ★ رسالةُ ذلك الفراغ — **الخطوةُ التالية لا وصفُ الفراغ** (§6).
const String pricingFilteredEmptyLabel =
    'لا يبقى نوعٌ ينتظر التسعير هنا. اعرض الكل لمراجعة ما سُعِّر.';

/// ★ إجراءُ ذلك الفراغ — **رفعُ المرشِّح نفسِه** ⛔ **لا وجهةٌ في شاشةٍ أخرى.**
const String pricingFilteredEmptyAction = 'اعرض الكل';

/// شاشة التسعير اليومي.
class DailyPricingScreen extends ConsumerWidget {
  /// ينشئ الشاشة.
  const DailyPricingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CalendarDay today = ref.watch(todayProvider);
    final String? sourceId = ref.watch(selectedSourceProvider);
    final List<SourceCard> sources = ref.watch(activeSourcesProvider);
    final PricingStatusFilter filter = ref.watch(pricingFilterProvider);

    return Scaffold(
      appBar: QtmsTopBar(screenTitle: 'التسعير اليومي'),
      body: Column(
        children: <Widget>[
          // ★★★ **رأس السياق الموحّد** — §5b نمط `P3` (`ADR-0021`).
          //
          // ⛔⛔★★ **وكان رأسُ هذه الشاشة ثلاثةَ صفوف** (منتقٍ + لافتةُ يومٍ
          //    + صفُّ مرشِّحات) — ★ **وهو أثقلُ رأسٍ في التطبيق كما رُصد في
          //    جرد 2026-08-27**: ⟵ **فصار صفّاً واحداً والمرشِّحاتُ مطويّة.**
          QtmsContextHeader(
            sources: sources,
            selectedSourceId: sourceId,
            // ⛔ **وشاشةُ عمليةٍ على مصدرٍ واحد** — ★ **بلا خيار «الكل»**
            //   (`AM-009` ③ · `A-01`): ⟵ **و`null` لا تصل هنا أبداً.**
            onSourceSelected: (String? id) {
              if (id != null) ref.read(selectedSourceProvider.notifier).select(id);
            },
            day: today,
            filters: const _PricingFilterBar(),
            // ★ **«الكل» ليس مرشِّحاً نشطاً** — ⟵ **فلا يُعَدّ.**
            activeFilterCount: filter == PricingStatusFilter.all ? 0 : 1,
          ),
          Expanded(
            // ⛔⛔★★★ **ولا `SizedBox.shrink` حالةً لغياب المصدر** — §5b `P3`.
            child: sourceId == null
                ? QtmsEmptyState(
                    spec: sources.isEmpty
                        ? noSourceInScopeEmpty
                        : chooseSourceEmpty(),
                  )
                : _PricingForm(
                    key: ValueKey<String>('$sourceId-$today'),
                    query: PricingQuery(sourceId: sourceId, date: today),
                  ),
          ),
        ],
      ),
    );
  }
}

/// ★ شريط فلتر «حالة التسعير» — `FR-M9-05`.
///
/// ★★ **وصياغتُه [QtmsFilterBar]** (§5b · `ADR-0021`) — ⛔ **ولا شريطَ شرائحَ
/// محليٌّ بعد اليوم** (§8 المحظور الحادي عشر).
class _PricingFilterBar extends ConsumerWidget {
  const _PricingFilterBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PricingStatusFilter selected = ref.watch(pricingFilterProvider);
    // ★ **بلا حشوٍ خاصٍّ به** — ⟵ **فهو يسكن داخل رأس السياق الآن**،
    //   ⛔ **وحشوٌ مزدوج كان يُبعده عن حافّة الرأس.**
    return QtmsFilterBar(
      padded: false,
      groups: <List<QtmsFilterOption>>[
        <QtmsFilterOption>[
          for (final PricingStatusFilter filter in PricingStatusFilter.values)
            QtmsFilterOption(
              label: _filterLabel(filter),
              selected: filter == selected,
              onSelected: () =>
                  ref.read(pricingFilterProvider.notifier).select(filter),
            ),
        ],
      ],
    );
  }
}

/// ⛔ **بلا مصطلح تقني في الواجهة** (`ui-guidelines.md` §6).
String _filterLabel(PricingStatusFilter filter) => switch (filter) {
      PricingStatusFilter.all => 'الكل',
      PricingStatusFilter.priced => 'تم التسعير',
      PricingStatusFilter.unpriced => 'لم يتم',
    };

/// نموذج التسعير — ★ **حالةٌ محلية حتى الحفظ**.
///
/// ⚠️ **ولماذا محلية:** `FR-M9-13` يجعل «نسخ أسعار أمس» و«التسعير الجماعي»
/// **اقتراحاً يراجعه المستخدم قبل الحفظ** — ⟵ **فالكتابة عند الضغط وحده**،
/// ⛔ **ولا حفظٌ عند كل ضغطة مفتاح** يُغرق السحابة ويكتب ما لم يُقصَد.
class _PricingForm extends ConsumerStatefulWidget {
  const _PricingForm({required this.query, super.key});

  final PricingQuery query;

  @override
  ConsumerState<_PricingForm> createState() => _PricingFormState();
}

class _PricingFormState extends ConsumerState<_PricingForm> {
  /// ★ التحرير المحلي لكل نوع — **ما لم يُحرَّر يبقى على قيمته المخزَّنة**.
  final Map<String, _PriceEdit> _edits = <String, _PriceEdit>{};
  final TextEditingController _reason = TextEditingController();
  bool _submitting = false;
  CatalogMessage? _rejection;
  bool _saved = false;

  @override
  void dispose() {
    _reason.dispose();
    for (final _PriceEdit edit in _edits.values) {
      edit.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<PricingRow>> rows =
        ref.watch(filteredPricingRowsProvider(widget.query));

    // ⛔⛔★★★ **وفراغُ المرشِّح يُفصَل عن فراغ البيانات** — `AM-021` ③
    //    (`design-system.md` §هـ): ★ **والشرطُ مقيسٌ لا مُفترَض** — ⟵ **القائمةُ
    //    غيرُ المرشَّحة غيرُ فارغة والمعروضةُ فارغة**: ⛔ **ولا يكفي «المرشِّحُ
    //    ليس الكل»**، ★ **فيومٌ بلا مخزونٍ أصلاً فراغُه فراغُ بيانات.**
    final PricingStatusFilter filter = ref.watch(pricingFilterProvider);
    final bool filteredOut = filter != PricingStatusFilter.all &&
        (rows.value?.isEmpty ?? false) &&
        (ref.watch(pricingRowsProvider(widget.query)).value?.isNotEmpty ??
            false);

    return InventoryAsyncView<PricingRow>(
      value: rows,
      // ★ **«لا يوجد بعد» لا «ممنوع»** — والمنع له نصّه في `InventoryAsyncView`.
      emptyIcon: filteredOut ? Icons.filter_alt_off_outlined : Icons.sell_outlined,
      emptyTitle:
          filteredOut ? pricingFilteredEmptyTitle : 'لا شيء يُسعَّر بعد',
      emptyLabel: filteredOut
          ? pricingFilteredEmptyLabel
          : 'التسعير يتبع المخزون — سجّل وارداً أولاً ثم عُد لتسعيره.',
      emptyActionLabel: filteredOut ? pricingFilteredEmptyAction : null,
      onEmptyAction: filteredOut
          ? () => ref
              .read(pricingFilterProvider.notifier)
              .select(PricingStatusFilter.all)
          : null,
      // ★★★ **نمط `P4`** (`MASTER.md` §5b · `ADR-0021`): **شريطُ الإجراء
      //    الجماعي ثابتٌ فوق الصفوف، والصفوفُ تمرّ، وزرُّ الحفظ ثابتٌ أسفل.**
      builder: (List<PricingRow> list) => Column(
        children: <Widget>[
          // ③ ⛔⛔★★ **الإجراء الجماعي فوق الصفوف لا تحتها** — §5b `P4`:
          //    ★ **«نسخ أسعار أمس» يملأ الحقول**، ⟵ **وموضعُه بعدها كان
          //    يجعل المستخدم يكتشفه بعد أن عبّأ يدوياً.**
          _BulkBar(
            rows: list,
            query: widget.query,
            onCopy: (Map<String, DailyPriceCard> yesterday) =>
                _copyYesterday(list, yesterday),
          ),
          // ④ ★ **الصفوف بـ`builder`** — §7: ⛔ **لا `ListView(children:)`
          //    بعشرات الأنواع.** ★ **وحقلُ السبب آخرُ عنصرٍ ممرَّر** (⑤).
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsetsDirectional.all(Spacing.screenPadding),
              itemCount: list.length + 1,
              itemBuilder: (BuildContext context, int index) {
                if (index == list.length) return _reasonField();
                final PricingRow row = list[index];
                return Padding(
                  padding:
                      const EdgeInsetsDirectional.only(bottom: Spacing.space8),
                  child: _PricingTile(row: row, edit: _editOf(row)),
                );
              },
            ),
          ),
          // ⑥ ⛔⛔★★★ **وزرُّ الحفظ ثابتٌ أسفل الشاشة** — ⛔ **لا في ذيل
          //    قائمةٍ بعشرات الصفوف**: ⟵ **فلا يُطارَد بعد كل تحرير.**
          //    ★ **واللافتةُ داخل الشريط** ⟵ **فلا يقفز الزرُّ عند ظهورها.**
          //
          // ⚠️⚠️ **والبوابة إخفاءٌ لا حماية** (`RISK-02`) — ★ **والفحص
          //    الحقيقي `dailyPriceWrite` في `dailyPricingGate`.**
          QtmsStickyActionBar(
            status: switch ((_rejection, _saved)) {
              (final CatalogMessage message, _) =>
                QtmsActionStatus.rejection(catalogText(message)),
              (null, true) => QtmsActionStatus.success('حُفظت أسعار اليوم.'),
              _ => null,
            },
            primary: PermissionGate(
              permission: Permission.dailyPriceWrite,
              child: FilledButton(
                onPressed: _submitting ? null : () => _submit(list),
                // ⛔⛔★★★ **وبديلٌ مرئيٌّ داخل الزرّ أثناء النداء** —
                //    `design-system.md` §6-ي البند ② (`AM-021` ②): ⟵ **وكان
                //    التعطيلُ وحدَه** (البند ①)، ⛔ **وزرٌّ معطَّلٌ بلا بديلٍ
                //    يُقرأ ممنوعاً لا مشغولاً** — ★ **فاكتمل العقدُ بأربعته**:
                //    ★ **والرفضُ والنجاحُ في `status` أعلاه** (البند ④).
                child: Text(
                  _submitting ? dailyPricingSavingLabel : dailyPricingSaveLabel,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// ★★ حقل سبب التعديل — **ويظهر دائماً ولا يُخفى**.
  ///
  /// ⚠️ **ولماذا لا يُخفى حتى يتغيّر سعر:** الشاشة **لا تعرف أيُّ سعرٍ قائم
  /// فعلاً في اللحظة التي تُرسِل فيها** — ★ **والحَكَم سجلٌّ يُقرأ داخل
  /// المعاملة** (`changesStoredPrice`)، ⟵ **فحقلٌ ظاهرٌ دائماً أصدق من
  /// إخفاءٍ يعتمد على قراءةٍ قد تكون متأخرة**؛ ⛔ **والسحابة وحدها تقرر
  /// أواجبٌ هو أم لا.**
  Widget _reasonField() => TextField(
        controller: _reason,
        decoration: const InputDecoration(
          labelText: 'سبب التعديل (اختياري)',
        ),
        maxLines: 2,
      );

  /// ★★ **«نسخ أسعار أمس» — نسخٌ صريح بإرادة المستخدم** (`FR-M9-13`).
  ///
  /// ⛔★★ **ولا يحفظ شيئاً:** يملأ الحقول وحدها ⟵ **والمستخدم يراجع ثم
  /// يضغط «حفظ»**. ★ **وهذا هو الفرق الذي يفرضه `BR-M9-02` (`GR-31`)**
  /// بين **النسخ الصريح** و**الترحيل التلقائي الصامت** المرفوض.
  ///
  /// ⚠️ **ولا يُنسَخ سعرُ نوعٍ لا كمية له اليوم** — ★ **لأن القائمة نفسها
  /// مبنيّةٌ على رصيد اليوم** (`FR-M9-02`)، ⟵ **فما ليس فيها لا يُملأ له حقل.**
  void _copyYesterday(
    List<PricingRow> rows,
    Map<String, DailyPriceCard> yesterday,
  ) {
    setState(() {
      _rejection = null;
      _saved = false;
      for (final PricingRow row in rows) {
        final DailyPriceCard? previous = yesterday[row.itemKey];
        if (previous == null) continue;
        final _PriceEdit edit = _editOf(row);
        edit.fill(
          distribution: previous.distributionPrice,
          minimum: previous.minCashPrice,
        );
      }
    });
  }

  _PriceEdit _editOf(PricingRow row) => _edits.putIfAbsent(
        row.itemKey,
        () => _PriceEdit(
          distribution: row.distributionPrice,
          minimum: row.minCashPrice,
        ),
      );

  Future<void> _submit(List<PricingRow> rows) async {
    final List<DailyPriceLineInput> lines = <DailyPriceLineInput>[];
    for (final PricingRow row in rows) {
      final _PriceEdit edit = _editOf(row);
      final _Parsed distribution = edit.distributionValue;
      final _Parsed minimum = edit.minimumValue;
      // ⛔★★ **والكسر يُرفَض ولا يُقرَّب** — `ADR-0015` القاعدة 3.
      if (distribution.invalid || minimum.invalid) {
        setState(() => _rejection = CatalogMessage.fractionalMoney);
        return;
      }
      lines.add(
        DailyPriceLineInput(
          itemId: row.itemKey,
          itemName: row.itemName,
          unit: row.unit,
          distributionPrice: distribution.value,
          minCashPrice: minimum.value,
        ),
      );
    }

    if (lines.isEmpty) return;

    final Outcome<ValidatedDailyPriceBatch> validated = validateDailyPrices(
      DailyPriceBatchInput(sourceId: widget.query.sourceId, lines: lines),
    );
    if (validated is Failure<ValidatedDailyPriceBatch>) {
      setState(() => _rejection = _messageOf(validated.error));
      return;
    }

    setState(() {
      _submitting = true;
      _rejection = null;
      _saved = false;
    });

    final Outcome<void> result =
        await ref.read(dailyPricingRepositoryProvider).writeDailyPrices(
              batch: (validated as Success<ValidatedDailyPriceBatch>).value,
              amendReason: blankToNull(_reason.text),
            );

    if (!mounted) return;
    switch (result) {
      case Failure<void>(:final AppError error):
        setState(() {
          _submitting = false;
          _rejection = appErrorMessage(error);
        });
      case Success<void>():
        setState(() {
          _submitting = false;
          _saved = true;
        });
    }
  }

  /// ★ يترجم خطأ التحقق إلى رسالة الكتالوج.
  ///
  /// ⚠️ **و`BR-M9-06` يُعرَض بـ`ERR_MONEY_001`** — ★ **بنفس سابقة
  /// `BR-M6-06`** التي تُعرَض بـ`ERR_STOCK_002` للكسر وللكمية غير الموجبة
  /// معاً (`counted_intake_screen.dart`)، ⛔ **ولا يُخترَع رمزٌ ثالث.**
  static CatalogMessage _messageOf(AppError error) {
    if (error case ValidationError(:final String ruleCode)) {
      return switch (ruleCode) {
        'BR-M9-06' => CatalogMessage.fractionalMoney,
        _ => CatalogMessage.operationFailed,
      };
    }
    return appErrorMessage(error);
  }
}

/// ★★★ **شريط حالة التحرير والإجراء الجماعي** — §5b نمط `P4` البند ③.
///
/// ⛔⛔★★ **وعدّادُ غير المسعَّر ملخّصٌ حيٌّ لا زينة** — §5 يفرض «ملخّصاً حيّاً
/// للأثر» على نمط الإدخال: ⟵ **فيعرف المستخدم كم بقي قبل أن يمرّر**،
/// ⛔ **ولا يكتشف نوعاً منسيّاً بعد أن حفظ.**
///
/// ★ **والحالةُ من [PricingRow.complete]** — ⟵ **وهي تفوّض لـ`isPricingComplete`
/// في طبقة النطاق**، ⛔ **ولا قاعدةَ تسعيرٍ تُكتب هنا** (`ADR-0010` القاعدة 5).
class _BulkBar extends StatelessWidget {
  const _BulkBar({
    required this.rows,
    required this.query,
    required this.onCopy,
  });

  final List<PricingRow> rows;
  final PricingQuery query;
  final void Function(Map<String, DailyPriceCard>) onCopy;

  @override
  Widget build(BuildContext context) {
    final int done = rows.where((PricingRow row) => row.complete).length;
    // ★★ **وصياغتُه [QtmsBulkActionBar]** (§5b `P4` البند ③ · `ADR-0021`) —
    //    ⛔ **ولا شريطَ إجراءٍ جماعيٍّ محليٌّ بعد اليوم.**
    return QtmsBulkActionBar(
      // ★★ **أرقامٌ لاتينية** (`AM-003`) — ⛔ **ولا مصطلحَ تقني** (§6).
      headline: 'سُعِّر $done من ${rows.length}',
      action: _CopyYesterdayButton(query: query, onCopy: onCopy),
    );
  }
}

/// ★ زرّ «نسخ أسعار أمس» — `FR-M9-13`.
///
/// ⚠️ **ويُخفى إن لم يكن لأمس أسعار** — ⟵ **فزرٌّ لا يفعل شيئاً أسوأ من
/// غيابه**، ⛔ **ولا يُعرَض مُعطَّلاً بلا تفسير.**
class _CopyYesterdayButton extends ConsumerWidget {
  const _CopyYesterdayButton({required this.query, required this.onCopy});

  final PricingQuery query;
  final void Function(Map<String, DailyPriceCard>) onCopy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<DailyPriceCard>> yesterday = ref.watch(
      dailyPricesProvider(
        PricingQuery(
          sourceId: query.sourceId,
          // ★ **اليوم السابق من طبقة النطاق** — ⛔ **ولا حساب تاريخ في شاشة**.
          date: query.date.previousDay(),
        ),
      ),
    );
    final List<DailyPriceCard> cards = yesterday.value ?? const <DailyPriceCard>[];
    if (cards.isEmpty) return const SizedBox.shrink();

    return OutlinedButton.icon(
      onPressed: () => onCopy(<String, DailyPriceCard>{
        for (final DailyPriceCard card in cards) card.itemKey: card,
      }),
      icon: const Icon(Icons.content_copy_outlined),
      label: const Text('نسخ أسعار أمس'),
    );
  }
}

/// صفّ نوعٍ في شاشة التسعير — **رصيده وسعراه**.
class _PricingTile extends StatelessWidget {
  const _PricingTile({required this.row, required this.edit});

  final PricingRow row;
  final _PriceEdit edit;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(Spacing.space16),
        decoration: BoxDecoration(
          color: SemanticColors.surface,
          border: Border.all(color: SemanticColors.border),
          borderRadius: BorderRadius.circular(Radii.card),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(row.itemName, style: TypeScale.titleSm),
                ),
                // ★★ **الرصيد بوحدته** — `FR-M8-07` (`GR-19`): ⛔ **ولا رقم
                //    عارٍ يُغري بجمع الحبات مع الأوزان.**
                Text(quantityLabel(row.balance), style: TypeScale.bodyMd),
              ],
            ),
            const SizedBox(height: Spacing.space8),
            Row(
              children: <Widget>[
                Expanded(
                  child: _PriceField(
                    controller: edit.distribution,
                    // ★ **وحدة السعر تتبع وحدة النوع** — `FR-M9-06`.
                    label: 'سعر التوزيع لكل ${unitName(row.unit)}',
                  ),
                ),
                const SizedBox(width: Spacing.space8),
                Expanded(
                  child: _PriceField(
                    controller: edit.minimum,
                    label: 'الحد الأدنى لكل ${unitName(row.unit)}',
                  ),
                ),
              ],
            ),
          ],
        ),
      );
}

/// حقل سعر — ★ **أرقام لاتينية صحيحة وحدها** (`ADR-0015` · `AM-003`).
///
/// ⛔★★ **ولا فاصلة عشرية ولا إشارة سالب في لوحة المفاتيح أصلاً** — ★ **فالمنع
/// بنيوي قبل أن يكون رسالة**، ⟵ **والرسالة تبقى حارساً لما يصل من لصقٍ أو
/// لوحةِ مفاتيحَ أخرى.**
class _PriceField extends StatelessWidget {
  const _PriceField({required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: <TextInputFormatter>[
          FilteringTextInputFormatter.digitsOnly,
        ],
        decoration: InputDecoration(labelText: label),
      );
}

/// ★ تحرير سعرَي نوعٍ واحد — **ويبدأ من القيمة المخزَّنة**.
final class _PriceEdit {
  _PriceEdit({required Money? distribution, required Money? minimum})
      : distribution = TextEditingController(
          text: distribution == null ? '' : '${distribution.riyals}',
        ),
        minimum = TextEditingController(
          text: minimum == null ? '' : '${minimum.riyals}',
        );

  final TextEditingController distribution;
  final TextEditingController minimum;

  /// ★ يملأ الحقلين باقتراحٍ — ⛔ **ولا يحفظ** (راجع `_copyYesterday`).
  void fill({required Money? distribution, required Money? minimum}) {
    this.distribution.text =
        distribution == null ? '' : '${distribution.riyals}';
    this.minimum.text = minimum == null ? '' : '${minimum.riyals}';
  }

  /// سعر التوزيع المُحرَّر.
  _Parsed get distributionValue => _parse(distribution.text);

  /// الحد الأدنى المُحرَّر.
  _Parsed get minimumValue => _parse(minimum.text);

  void dispose() {
    distribution.dispose();
    minimum.dispose();
  }

  /// ★★ **الفارغ تفريغٌ مقصود ⛔ لا خطأ** — `schema/daily-prices.md`
  /// (`number | null`): ⟵ **فمن سعّر خطأً يُعيد النوع «غير مسعَّر»**.
  static _Parsed _parse(String raw) {
    final String text = raw.trim();
    if (text.isEmpty) return const _Parsed.cleared();
    final Money? money = Money.tryParseInput(text);
    return money == null ? const _Parsed.invalid() : _Parsed(money);
  }
}

/// ★ قيمةٌ مقروءة من حقل — **مُفرَّغة أو صالحة أو فاسدة**.
final class _Parsed {
  const _Parsed(this.value) : invalid = false;
  const _Parsed.cleared()
      : value = null,
        invalid = false;
  const _Parsed.invalid()
      : value = null,
        invalid = true;

  final Money? value;
  final bool invalid;
}

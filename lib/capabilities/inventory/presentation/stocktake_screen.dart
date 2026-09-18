/// شاشة **الجرد والتسويات** (`M16` · `FR-M16`) — **نمط 4**
/// (`ui-guidelines.md` §3): نموذجٌ بحقولٍ مجمَّعةٍ وزرٍّ أساسيٍّ ثابتٍ أسفل.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ★★★ **ومرحلتان لا واحدة — وهو جوهرُ هذه الشاشة:**
///
/// | المرحلة | ما يفعله المستخدم | المفتاح |
/// |---|---|---|
/// | ① **بدءُ الجرد** | يختار الأنواع المطلوب عدُّها ⟵ **فيُجمَّد رصيدُها الدفتري** (`FR-M16-03`) | `stocktakeWrite` |
/// | ② **الاعتماد** | يُدخِل **العدَّ الفعلي** لكل نوع ⟵ **فتُكتب التسويات** (`FR-M16-11`) | `stocktakeApprove` |
///
/// ⛔⛔★★★ **ولا يُعرَض الرصيدُ الدفتري حقلاً قابلاً للتحرير** — `FR-M16-01`
/// (🧮 🔒): ⟵ **يُقرأ من المستند المُجمَّد ويُعرَض نصّاً**، ★ **والمُدخَلُ
/// الوحيد هو العدُّ الفعلي** ⛔ **ولا يُرسَل الرصيدُ من الجهاز إطلاقاً.**
///
/// ⛔⛔★★★ **ولا حقلَ سعرٍ ولا مبلغٍ في هذه الشاشة إطلاقاً** — `BR-M16-03` ·
/// `AT-66`: ★ **غيابٌ بنيويٌّ لا تعطيلٌ بصري**، ⟵ **فتسويةُ الجرد لا تدخل
/// المبيعات ولا سعرَ الجونية ولا استحقاقَ الرعوي.**
///
/// ⛔⛔★★★ **والخياراتُ من أرصدة دفتر اليوم لا من كتالوج الأنواع** —
/// [`DEBT-86`] · `ADR-0007` · `ADR-0008`: ⟵ **فسطرُ الجونية لا سجلَّ نوعٍ له**،
/// ★ **وبناؤها من الكتالوج يُخفيه من كل قائمة فيُرفَض جردُه.**
///
/// ★★★ **وجردُ يومٍ سابق يُعرَض لمن يملك مفتاحَه وحده** (`FR-M16-08`) —
/// `ui-guidelines.md` §2: **«الصلاحيات تُخفي لا تُعطِّل»** ⛔ **فلا حقلَ
/// تاريخٍ معطَّلٌ لمن لا يملكه.**
///
/// ⚠️⚠️ **وكل ما هنا عرضٌ لا حماية** — ★ **والرفض الحقيقي في السحابة**
/// (`ADR-0013` القاعدة 3 · `RISK-02`): `stocktakes` **مغلقة للكتابة**،
/// **والصلاحيةُ والنطاقُ وتاريخُ المخزون والتجميدُ كلُّها في `planStocktake`.**
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
import '../../../core/ui/date_labels.dart';
import '../../../core/ui/live_summary.dart';
import '../../../core/ui/optional_reason.dart';
import '../../../core/ui/skeleton.dart';
import '../../../core/ui/destructive_sheet.dart';
import '../../../core/ui/sticky_action_bar.dart';
import '../../identity_access/application/session_providers.dart';
import '../../master_data/application/master_data_providers.dart';
import '../application/inventory_providers.dart';
import '../application/stocktake_providers.dart';
import 'inventory_widgets.dart' show itemOptionLabel, quantityLabel;

/// ★★ **تلميحُ الحقل الناقص** — `AM-021` ⑥.
const String stocktakeMissingCountHint = 'مطلوب — أدخل العدّ الفعلي';

/// ★★★ **رسالةُ رفضِ الاعتماد تُسمّي السطرَ الناقص** — `AM-021` ⑥.
///
/// ⛔⛔★★★ **ولا «أدخل العدّ لكل نوع» مجرَّدة** (`ui-guidelines.md` §6:
/// **رسالة خطأ مفيدة** = «**ما الشرط المخالَف وكيف يُصلَح**»): ⟵ **جردٌ
/// بعشرين سطراً كان يترك المستخدمَ يمسح القائمةَ يدوياً بحثاً عمّا نسي.**
///
/// ★★ **والاسمُ المعروض `ledgerItemDisplayName`** ([`DEBT-86`] ③) — ⛔ **لا
/// `itemKey` خاماً** (`design-system.md` §8 المحظور 13): ⟵ **فسطرُ الجونية
/// يُسمّى «عتود - جونية رقم 1»** ⛔ **لا بمفتاحٍ داخلي.**
///
/// ⛔ **ويُسمّى الأولُ وحدَه ويُعَدّ الباقي** — ⟵ **فرسالةٌ تسرد عشرين اسماً
/// لا تُقرأ**، ★ **والحدُّ اللوني على الحقول يدلّ على البقية في القائمة.**
///
/// ⚠️ **و[missing] لا تكون فارغةً عند الاستدعاء** — ★ **الحارسُ لا يُنادى
/// إلا بعد قياسها.**
String stocktakeMissingCountMessage(List<StocktakeCardLine> missing) {
  final String first = ledgerItemDisplayName(
    itemKey: missing.first.itemKey,
    itemName: missing.first.itemName,
  );
  if (missing.length == 1) {
    return 'أدخل العدّ الفعلي لـ«$first».';
  }
  final int others = missing.length - 1;
  return 'أدخل العدّ الفعلي لـ«$first» '
      'و$others ${others == 1 ? "سطرٍ آخر" : "سطراً آخر"} بلا عدّ.';
}

/// شاشة الجرد.
class StocktakeScreen extends ConsumerStatefulWidget {
  /// ينشئ الشاشة.
  const StocktakeScreen({super.key});

  @override
  ConsumerState<StocktakeScreen> createState() => _StocktakeScreenState();
}

class _StocktakeScreenState extends ConsumerState<StocktakeScreen> {
  String? _sourceId;

  @override
  Widget build(BuildContext context) {
    final List<SourceCard> sources = ref.watch(activeSourcesProvider);
    // ⚠️⚠️ **وإخفاءٌ لا حماية** (`RISK-02`) — ★ **والحارس `stocktakeGate`.**
    final bool canStart =
        ref.watch(hasPermissionProvider(Permission.stocktakeWrite));

    return Scaffold(
      appBar: const QtmsTopBar(screenTitle: 'الجرد'),
      body: !canStart
          ? const QtmsEmptyState(
              spec: EmptyStateSpec(
                icon: Icons.lock_outline,
                title: 'لا صلاحية',
                message: 'ليست لديك صلاحية تنفيذ الجرد — راجع مالك النظام.',
              ),
            )
          : Column(
              children: <Widget>[
                _SourceHeader(
                  sources: sources,
                  sourceId: _sourceId,
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
                            message: 'الجرد يقع على مصدرٍ واحد ويومٍ واحد — '
                                'والمخزون مستقلٌّ في كل مصدر.',
                          ),
                        )
                      : _StocktakeBody(
                          // ★ **مفتاحٌ بالمصدر** — ⟵ **فتبديلُه يُعيد بناء
                          //   النموذج بحالةٍ نظيفة.**
                          key: ValueKey<String>(_sourceId!),
                          sourceId: _sourceId!,
                        ),
                ),
              ],
            ),
    );
  }
}

/// رأس الشاشة — **المصدر وحده** (`BR-M16-04`).
class _SourceHeader extends StatelessWidget {
  const _SourceHeader({
    required this.sources,
    required this.sourceId,
    required this.onSource,
  });

  final List<SourceCard> sources;
  final String? sourceId;
  final ValueChanged<String?> onSource;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: Spacing.screenPadding,
          vertical: Spacing.space8,
        ),
        // ⛔⛔★★★ **ولا «كل المصادر» هنا** — ★ **المصدر مفردٌ إلزامي**:
        //    ⟵ **والجردُ يقع على مخزون مصدرٍ واحد** (`A-01` · `BR-M16-04`).
        child: DropdownButtonFormField<String>(
          key: const Key('stocktake-source'),
          initialValue: sourceId,
          decoration: const InputDecoration(labelText: 'المصدر'),
          items: <DropdownMenuItem<String>>[
            for (final SourceCard source in sources)
              DropdownMenuItem<String>(
                value: source.sourceId,
                child: Text(source.name),
              ),
          ],
          onChanged: onSource,
        ),
      );
}

/// جسمُ الشاشة — ★★★ **يختار المرحلة من حالة المستندات القائمة**.
///
/// ⛔⛔★★ **والمسوّدةُ القائمة تُقدَّم على بدء جردٍ جديد** — `FR-M16-06`:
/// ⟵ **فلا يُعرَض للمستخدم بدءٌ سيرفضه الخادم**، ★ **والرفضُ قائمٌ هناك
/// مع ذلك** (`ERR_STOCK_006`) ⛔ **فالشاشة تُرشد ولا تحرس.**
class _StocktakeBody extends ConsumerStatefulWidget {
  const _StocktakeBody({required this.sourceId, super.key});

  final String sourceId;

  @override
  ConsumerState<_StocktakeBody> createState() => _StocktakeBodyState();
}

/// ⛔⛔★★★ **ولافتةُ الحالة تعيش هنا لا في النموذجين** — ★ **عطلٌ رُصد على
/// المحاكي 2026-09-05:** ⟵ **الاعتمادُ الناجح يُغلِق المسوّدة فيُستبدَل
/// نموذجُ العدّ بنموذج البدء**، ⛔ **فتُتلَف حالتُه ومعها «اعتُمد الجرد …»**
/// — ★ **فيبدو للمستخدم أن شيئاً لم يحدث.** ⟹ **ورفعُها إلى الأب يُبقيها
/// عبر تبدّل المرحلة** (`ui-guidelines.md` §6: **تأكيدٌ صريح يذكر المستند**).
///
/// ⛔⛔★★★ **وهي `_StocktakeStatus` لا `String`** (`AM-021` §تصحيح · 2026-09-15)
/// — ★ **نظيرُ `_DisposalStatus` في شاشة الإتلاف حرفاً بحرف**: ⟵ **فالحكمُ
/// حقلٌ يُترجَم ثلاثيةً لونية** ⛔ **لا رمزٌ إيموجي في أول النصّ.**
class _StocktakeBodyState extends ConsumerState<_StocktakeBody> {
  _StocktakeStatus? _status;

  void _report(_StocktakeStatus? value) {
    if (!mounted) return;
    setState(() => _status = value);
  }

  @override
  Widget build(BuildContext context) {
    final String sourceId = widget.sourceId;
    final AsyncValue<List<StocktakeCard>> cards =
        ref.watch(stocktakesProvider(sourceId));
    // ★★ **الحالاتُ الأربع بمكوّناتها المعتمدة** — `design-system.md` §6.هـ:
    //    ⛔ **ولا مؤشّرَ دوّار وسط الشاشة** (§8 · بوابة الحِرفية البصرية).
    //
    // ⛔⛔★★ **والقائمةُ الفارغة ليست «حالةً فارغة» هنا** — ★ **بل مدخلُ
    //    البدء نفسُه**: ⟵ **فأولُ جردٍ على مصدرٍ يبدأ من لا شيء**،
    //    ⛔ **وحجبُه خلف «لا توجد بيانات» يترك الشاشةَ بلا مخرج.**
    // ⚠️⚠️ **والخطأ يُفحَص أولاً** — ★ **درسُ `AsyncStateView` نفسُه**:
    //    ⟵ **التدفّقُ المخفق يبقى `AsyncLoading` وهو يحمل الخطأ**،
    //    ⛔ **فتدور الدائرة أبداً ولا يرى الممنوعُ سببَ منعه** (`RISK-02`).
    if (cards.hasError) {
      return QtmsErrorState(
        message: readRejectionMessage,
        detail: cards.error?.toString(),
      );
    }
    final List<StocktakeCard>? items = cards.value;
    if (items == null) return const SkeletonList();

    final StocktakeCard? open = _openDraft(items);
    return open == null
        ? _StartForm(
            sourceId: sourceId,
            status: _status,
            onStatus: _report,
          )
        : _CountForm(
            key: ValueKey<String>(open.documentNumber),
            sourceId: sourceId,
            draft: open,
            status: _status,
            onStatus: _report,
          );
  }

  /// ★ أولُ مسوّدةٍ قائمة — ⛔ **وواحدةٌ لا أكثر بحكم `FR-M16-06`.**
  static StocktakeCard? _openDraft(List<StocktakeCard> cards) {
    for (final StocktakeCard card in cards) {
      if (card.isOpen) return card;
    }
    return null;
  }
}

// ═════════════════════════════════════════════════════════════════════════
// ① بدءُ الجرد — ★ **اختيارُ الأنواع وتجميدُ رصيدها**
// ═════════════════════════════════════════════════════════════════════════

class _StartForm extends ConsumerStatefulWidget {
  const _StartForm({
    required this.sourceId,
    required this.status,
    required this.onStatus,
  });

  final String sourceId;

  /// ★ لافتةُ الحالة المرفوعةُ إلى الأب — راجع [_StocktakeBodyState].
  final _StocktakeStatus? status;

  /// ★ يُبلِّغ الأبَ بالنتيجة — ⛔ **ولا حالةَ محليةً تُتلَف بتبدّل المرحلة.**
  final ValueChanged<_StocktakeStatus?> onStatus;

  @override
  ConsumerState<_StartForm> createState() => _StartFormState();
}

class _StartFormState extends ConsumerState<_StartForm> {
  final List<String?> _picked = <String?>[];
  final TextEditingController _reason = TextEditingController();
  CalendarDay? _priorDay;
  bool _saving = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final List<String> itemIds = <String>[
      for (final String? id in _picked) ?id,
    ];
    if (itemIds.isEmpty) {
      widget.onStatus(
        const _StocktakeStatus(
          message: 'اختر نوعاً واحداً على الأقل لجرده.',
          succeeded: false,
        ),
      );
      return;
    }

    setState(() => _saving = true);
    widget.onStatus(null);

    final Outcome<String> result =
        await ref.read(stocktakeAdminProvider).startStocktake(
              sourceId: widget.sourceId,
              itemIds: itemIds,
              // ⛔⛔★★★ **ولا يُرسَل تاريخٌ إلا عند التثبيت** — ★ **ويومُ
              //    المخزون من المنصّة** (`GR-54` · `E-41`).
              stockDate: _priorDay,
              reason: _reason.text,
            );
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (result is Success<String>) {
        _picked.clear();
        _reason.clear();
      }
    });
    widget.onStatus(
      switch (result) {
        Success<String>(:final String value) => _StocktakeStatus(
            message: 'بدأ الجرد $value',
            succeeded: true,
          ),
        Failure<String>(:final AppError error) => _StocktakeStatus(
            message: catalogText(appErrorMessage(error)),
            succeeded: false,
          ),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final CalendarDay today = ref.watch(todayProvider);
    final CalendarDay day = _priorDay ?? today;
    // ★★★ **ومفتاحُ جرد يومٍ سابق يُخفي الحقل ولا يُعطِّله** — `ui-guidelines.md`
    //    §2: ⟵ **فمن لا يملكه لا يرى تاريخاً قابلاً للتغيير أصلاً.**
    final bool canPriorDay =
        ref.watch(hasPermissionProvider(Permission.stocktakePriorDay));

    final List<StockOption> items = ref.watch(
      stockOptionsProvider(
        StockQuery(sourceId: widget.sourceId, stockDate: day),
      ),
    );
    final bool showPieceWeight = ref.watch(showPieceWeightProvider);
    final List<QtmsItemOption> options = <QtmsItemOption>[
      for (final StockOption item in items)
        QtmsItemOption(
          id: item.itemKey,
          // ⛔⛔★★★ **والرصيدُ الدفتري جزءٌ من نصّ الخيار** — `AM-009` ⑥:
          //    ⟵ **فمن يبدأ الجرد يرى ما سيُجمَّد قبل أن يُجمَّد.**
          label: itemOptionLabel(
            item.itemName,
            item.balance,
            showPieceWeight: showPieceWeight,
            pieceWeightGrams: item.pieceWeightGrams,
          ),
        ),
    ];

    return Column(
      children: <Widget>[
        Expanded(
          child: ListView(
            padding: const EdgeInsetsDirectional.all(Spacing.screenPadding),
            children: <Widget>[
              const _FreezeNotice(),
              const SizedBox(height: Spacing.space16),
              if (canPriorDay) ...<Widget>[
                _PriorDayRow(
                  day: day,
                  today: today,
                  onChanged: (CalendarDay picked) => setState(
                    () => _priorDay = picked == today ? null : picked,
                  ),
                ),
                const SizedBox(height: Spacing.space16),
              ] else
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                    bottom: Spacing.space16,
                  ),
                  child: Text(
                    'تاريخ المخزون المجرود: ${dayLabel(day)}',
                    style: TypeScale.bodyMd,
                  ),
                ),
              Text('الأنواع المطلوب جردها', style: TypeScale.titleSm),
              const SizedBox(height: Spacing.space8),
              if (_picked.isEmpty)
                Text(
                  'لا نوعَ بعد — أضف ما ستعدّه فعلياً في المخزن.',
                  style: TypeScale.caption,
                )
              else
                for (int index = 0; index < _picked.length; index++)
                  QtmsItemLineRow(
                    key: ValueKey<int>(index),
                    options: optionsForRow(
                      all: options,
                      takenIds: _picked,
                      ownId: _picked[index],
                    ),
                    selectedId: _picked[index],
                    onSelected: (String id) =>
                        setState(() => _picked[index] = id),
                    onRemove: () => setState(() => _picked.removeAt(index)),
                  ),
              QtmsAddLineButton(
                key: const Key('stocktake-add-line'),
                onPressed: () => setState(() => _picked.add(null)),
              ),
              const SizedBox(height: Spacing.space16),
              TextField(
                key: const Key('stocktake-reason'),
                controller: _reason,
                decoration: const InputDecoration(
                  labelText: 'سبب الجرد',
                  // ★★ **ويُوسَم «اختياري» صراحةً** — [`ADR-0020`] ·
                  //   `ui-guidelines.md` §2: ⛔ **ولا يُعبَّأ آلياً.**
                  helperText: 'اختياري — ولا يُكتب نيابةً عنك',
                ),
              ),
            ],
          ),
        ),
        QtmsStickyActionBar(
          summary: QtmsLiveSummary(
            headline: 'أنواعٌ مختارة: ${_picked.whereType<String>().length}',
            details: <String>[
              'تاريخ المخزون: ${dayLabel(day)}',
              // ⛔⛔★★★ **وحصيلةُ أنواعٍ لا مبالغ** — `BR-M16-03`.
              'يُجمَّد الرصيد الدفتري لحظة البدء',
            ],
          ),
          // ★★★ **لافتةُ الحالة بثلاثيةٍ كاملة** — `AM-021` ④
          //    (`design-system.md` §6-ز): ★ **تعبئةٌ وحدٌّ ولونُ مقدّمةٍ
          //    وأيقونةٌ متجهية** ⛔ **لا نصٌّ عارٍ برمزٍ إيموجي.**
          //    ⟵ **ونفسُ صيغة `disposal_screen.dart` حرفاً بحرف** (§8 المحظور 11).
          status: switch (widget.status) {
            null => null,
            _StocktakeStatus(succeeded: true, :final String message) =>
              QtmsActionStatus.success(message),
            _StocktakeStatus(:final String message) =>
              QtmsActionStatus.rejection(message),
          },
          primary: FilledButton(
            key: const Key('stocktake-start'),
            onPressed: _saving ? null : _start,
            child: Text(_saving ? 'جارٍ البدء…' : 'بدء الجرد'),
          ),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════
// ② الاعتماد — ★★★ **العدُّ الفعلي مقابل المُجمَّد**
// ═════════════════════════════════════════════════════════════════════════

class _CountForm extends ConsumerStatefulWidget {
  const _CountForm({
    required this.sourceId,
    required this.draft,
    required this.status,
    required this.onStatus,
    super.key,
  });

  final String sourceId;
  final StocktakeCard draft;

  /// ★ لافتةُ الحالة المرفوعةُ إلى الأب — راجع [_StocktakeBodyState].
  final _StocktakeStatus? status;

  /// ★ يُبلِّغ الأبَ بالنتيجة — ⛔ **ولا حالةَ محليةً تُتلَف بتبدّل المرحلة.**
  final ValueChanged<_StocktakeStatus?> onStatus;

  @override
  ConsumerState<_CountForm> createState() => _CountFormState();
}

class _CountFormState extends ConsumerState<_CountForm> {
  final Map<String, TextEditingController> _counts =
      <String, TextEditingController>{};
  final Map<String, TextEditingController> _reasons =
      <String, TextEditingController>{};
  final TextEditingController _reason = TextEditingController();

  /// ⛔⛔★★ **والفعلُ الجاري يُسمّى ولا يُخمَّن** — `ui-guidelines.md` §6
  /// («**فعل واضح في الزر**»): ⚠️ **رُصد على المحاكي 2026-09-05** — ⟵ **عَلَمٌ
  /// واحدٌ للحفظ كان يعرض «جارٍ الاعتماد…» أثناء *الإلغاء***، ⛔ **فيقرأ
  /// المستخدمُ أن مستنداً يُعتمَد وهو يُلغى.**
  _InFlight _inFlight = _InFlight.none;

  /// ★★★ **مفاتيحُ السطور التي بلا عدٍّ صالح عند آخر محاولةِ اعتمادٍ فاشلة**
  /// (`AM-021` ⑥).
  ///
  /// ⛔⛔★★★ **ولا تُملأ قبل المحاولة** — ★ **فنموذجٌ يفتح كلَّ سطوره بحدٍّ
  /// أحمر يُنذِر قبل أن يُخطئ المستخدم**: ⟵ **والحدُّ حينها زينةٌ لا إشارة**
  /// (`design-system.md` §3.4: ⛔ **«استخدامُ لونٍ دلاليٍّ كزينة»**).
  Set<String> _missingCounts = const <String>{};

  bool get _saving => _inFlight != _InFlight.none;

  @override
  void initState() {
    super.initState();
    for (final StocktakeCardLine line in widget.draft.lines) {
      _counts[line.itemKey] = TextEditingController();
      _reasons[line.itemKey] = TextEditingController();
    }
  }

  @override
  void dispose() {
    for (final TextEditingController controller in _counts.values) {
      controller.dispose();
    }
    for (final TextEditingController controller in _reasons.values) {
      controller.dispose();
    }
    _reason.dispose();
    super.dispose();
  }

  /// ★ العدُّ الفعلي لسطرٍ — و`null` **لمُدخَلٍ ناقصٍ أو غير صالح**.
  StockQuantity? _countOf(StocktakeCardLine line) {
    final num? raw = num.tryParse(_counts[line.itemKey]?.text.trim() ?? '');
    // ⛔ **والسالبُ مرفوض** — ★ **والصفرُ عدٌّ مشروع** (`FR-M16-07`).
    if (raw == null || raw < 0) return null;
    return switch (line.bookBalance.unit) {
      // ⛔ **والكسر يُرفَض للنوع المعدود** — `BR-M6-06`.
      ItemUnit.piece => raw == raw.roundToDouble()
          ? PieceQuantity(PieceCount(raw.toInt()))
          : null,
      ItemUnit.kilogram => WeightQuantity(WeightKg(raw.toDouble())),
    };
  }

  Future<void> _approve() async {
    final List<StocktakeCountInput> counts = <StocktakeCountInput>[
      for (final StocktakeCardLine line in widget.draft.lines)
        if (_countOf(line) case final StockQuantity actual)
          StocktakeCountInput(
            itemId: line.itemKey,
            unit: line.bookBalance.unit,
            actualCount: actual,
            differenceReason: _reasons[line.itemKey]?.text,
          ),
    ];

    // ⛔⛔★★★ **والحرسُ يُسمّي السطرَ الناقص ولا يكتفي بـ«لكل نوع»** —
    //    `AM-021` ⑥ (`ui-guidelines.md` §6: **رسالة خطأ مفيدة**): ⟵ **جردٌ
    //    بعشرين سطراً كان يترك المستخدمَ يمسح القائمةَ يدوياً بحثاً عمّا نسي.**
    //    ★ **والاسمُ المعروض `ledgerItemDisplayName`** ([`DEBT-86`] ③)
    //    ⛔ **لا `itemKey` خاماً** (`design-system.md` §8 المحظور 13).
    final List<StocktakeCardLine> missing = <StocktakeCardLine>[
      for (final StocktakeCardLine line in widget.draft.lines)
        if (_countOf(line) == null) line,
    ];
    if (missing.isNotEmpty) {
      setState(
        () => _missingCounts = <String>{
          for (final StocktakeCardLine line in missing) line.itemKey,
        },
      );
      widget.onStatus(
        _StocktakeStatus(
          message: stocktakeMissingCountMessage(missing),
          succeeded: false,
        ),
      );
      return;
    }

    setState(() {
      _inFlight = _InFlight.approving;
      // ★ **ونجاحُ الحرس يُطفئ حدودَه** — ⛔ **فلا يبقى أحمرَ بعد إصلاحه.**
      _missingCounts = const <String>{};
    });
    widget.onStatus(null);

    final Outcome<void> result =
        await ref.read(stocktakeAdminProvider).approveStocktake(
              documentNumber: widget.draft.documentNumber,
              sourceId: widget.sourceId,
              counts: counts,
              reason: _reason.text,
            );
    if (!mounted) return;
    setState(() => _inFlight = _InFlight.none);
    widget.onStatus(
      switch (result) {
        Success<void>() => _StocktakeStatus(
            message: 'اعتُمد الجرد ${widget.draft.documentNumber}',
            succeeded: true,
          ),
        Failure<void>(:final AppError error) => _StocktakeStatus(
            message: catalogText(appErrorMessage(error)),
            succeeded: false,
          ),
      },
    );
  }

  /// ⛔⛔★★★ **وإلغاءُ الجرد يمرّ بالورقة المدمّرة الموحّدة** — `AM-021` ⑤
  /// (`ADR-0021` `P6` · `design-system.md` §6-و).
  ///
  /// ⚠️⚠️ **وكان `TextButton` أحمرَ ينفّذ بضغطةٍ واحدة مباشرة** — ⛔ **بلا
  /// تأكيدٍ ولا مخرَج**: ⟵ **بينما إلغاءُ الوارد والجونية والتوزيعة والبيع
  /// النقدي كلُّها بالورقة** ⟹ **فمستوى الحمايةِ كان يتفاوت بين خمسِ عملياتٍ
  /// متكافئةِ الخطر على مستنداتٍ لا تُحذَف ولا يُتراجَع عن إلغائها** (`GR-07`).
  ///
  /// ⛔⛔★★★ **وسببُ الإلغاء يُكتَب في الورقة نفسِها لا في حقل النموذج** —
  /// ★ **و`_reason` صار للاعتماد وحدَه**: ⟵ **وكان الحقلُ الواحدُ يُرسَل
  /// للعمليتين معاً**، ⛔ **فمن كتب ملاحظةً على العدّ ثم ألغى أُرسلت ملاحظتُه
  /// سبباً للإلغاء** — ★ **وهو ما تمنعه القاعدةُ الباقية من [`ADR-0020`]:**
  /// **«ما لم يكتبه إنسانٌ *لهذه العملية* لا يُرسَل».**
  Future<void> _cancel() async {
    widget.onStatus(null);
    final DestructiveConfirmation? confirmation =
        await showQtmsDestructiveSheet(
      context,
      title: 'إلغاء الجرد ${widget.draft.documentNumber}',
      impact: 'الإلغاء يَسِم مسوّدة الجرد ولا يحذفها ولا يكتب تسويةً واحدة، '
          'ويفتح المصدر واليوم لجردٍ جديد.',
      confirmLabel: 'تأكيد إلغاء الجرد',
      reasonLabel: 'سبب الإلغاء (اختياري)',
      onConfirm: _submitCancel,
    );
    if (!mounted || confirmation == null) return;
    widget.onStatus(
      _StocktakeStatus(
        message: 'أُلغي الجرد ${widget.draft.documentNumber}',
        succeeded: true,
      ),
    );
  }

  /// ★ يُرجِع نصَّ الرفض — و`null` نجاحاً (عقد [DestructiveExecutor]).
  Future<String?> _submitCancel(DestructiveConfirmation confirmation) async {
    setState(() => _inFlight = _InFlight.cancelling);
    final Outcome<void> result =
        await ref.read(stocktakeAdminProvider).cancelStocktake(
              documentNumber: widget.draft.documentNumber,
              sourceId: widget.sourceId,
              // ⛔ **والفراغاتُ تُقرأ غياباً لا نصّاً فارغاً** ([`ADR-0020`]).
              cancelReason: blankToNull(confirmation.reason),
            );
    if (mounted) setState(() => _inFlight = _InFlight.none);
    return switch (result) {
      Success<void>() => null,
      Failure<void>(:final AppError error) =>
        catalogText(appErrorMessage(error)),
    };
  }

  @override
  Widget build(BuildContext context) {
    // ⚠️⚠️ **وإخفاءٌ لا حماية** — ★ **والحارس `stocktakeGate` بمفتاحه.**
    final bool canApprove =
        ref.watch(hasPermissionProvider(Permission.stocktakeApprove));
    final bool canCancel =
        ref.watch(hasPermissionProvider(Permission.stocktakeCancel));

    return Column(
      children: <Widget>[
        Expanded(
          child: ListView(
            padding: const EdgeInsetsDirectional.all(Spacing.screenPadding),
            children: <Widget>[
              _OpenDraftBanner(draft: widget.draft),
              const SizedBox(height: Spacing.space16),
              Text('العدّ الفعلي', style: TypeScale.titleSm),
              const SizedBox(height: Spacing.space8),
              for (final StocktakeCardLine line in widget.draft.lines)
                _CountRow(
                  key: ValueKey<String>(line.itemKey),
                  line: line,
                  count: _counts[line.itemKey]!,
                  reason: _reasons[line.itemKey]!,
                  difference: _differenceLabel(line),
                  // ★★ **حدٌّ لونيٌّ على الحقل الناقص وحدَه** — `AM-021` ⑥.
                  missingCount: _missingCounts.contains(line.itemKey),
                  onChanged: () => setState(() {}),
                ),
              const SizedBox(height: Spacing.space16),
              TextField(
                key: const Key('stocktake-approve-reason'),
                controller: _reason,
                decoration: const InputDecoration(
                  // ★★ **وتسميةٌ تقول لأيّ عمليةٍ هذا الحقل** — `AM-021` ⑤:
                  //   ⟵ **فسببُ الإلغاء صار في ورقته**، ⛔ **ولا يُرسَل هذا
                  //   الحقلُ لعمليتين مختلفتين.**
                  labelText: 'ملاحظة على الاعتماد',
                  helperText: 'اختياري — ولا يُكتب نيابةً عنك',
                ),
              ),
              if (canCancel) ...<Widget>[
                const SizedBox(height: Spacing.space16),
                // ★ **والمدمّر آخراً** — `design-system.md` §6.ج:
                //   ⛔ **و«إلغاء» لا «حذف»** (`GR-07`).
                TextButton(
                  key: const Key('stocktake-cancel'),
                  // ⛔⛔★★★ **ولا تنفيذَ بضغطةٍ واحدة** — `AM-021` ⑤:
                  //    ★ **الزرُّ يفتح ورقةَ التأكيد وحدَها** (راجع [_cancel]).
                  onPressed: _saving ? null : _cancel,
                  style: TextButton.styleFrom(
                    foregroundColor: SemanticTriads.danger.ink,
                  ),
                  child: Text('إلغاء الجرد ${widget.draft.documentNumber}'),
                ),
              ],
            ],
          ),
        ),
        QtmsStickyActionBar(
          summary: QtmsLiveSummary(
            headline: 'أنواعٌ مجرودة: ${widget.draft.lines.length}',
            details: <String>[
              'تاريخ المخزون: ${dayLabel(widget.draft.stockDate)}',
              'التسوية لا تدخل المبيعات ولا سعر الجونية ولا الرعوي',
            ],
          ),
          // ★★★ **لافتةُ الحالة بثلاثيةٍ كاملة** — `AM-021` ④
          //    (`design-system.md` §6-ز): ★ **تعبئةٌ وحدٌّ ولونُ مقدّمةٍ
          //    وأيقونةٌ متجهية** ⛔ **لا نصٌّ عارٍ برمزٍ إيموجي.**
          //    ⟵ **ونفسُ صيغة `disposal_screen.dart` حرفاً بحرف** (§8 المحظور 11).
          status: switch (widget.status) {
            null => null,
            _StocktakeStatus(succeeded: true, :final String message) =>
              QtmsActionStatus.success(message),
            _StocktakeStatus(:final String message) =>
              QtmsActionStatus.rejection(message),
          },
          primary: FilledButton(
            key: const Key('stocktake-approve'),
            // ★★ **ومن لا يملك الاعتماد لا يعتمد** (`FR-M16-09`) — ⟵ **وقد
            //    بدأ الجردَ بمفتاحٍ آخر**: ★ **فالزرُّ معطَّلٌ بنصّه المُعلَن**
            //    ⛔ **لا مخفيٌّ فيبدو النموذجُ بلا مخرج.**
            onPressed: _saving || !canApprove ? null : _approve,
            child: Text(
              switch ((canApprove, _inFlight)) {
                (false, _) => 'الاعتماد يحتاج صلاحية',
                (_, _InFlight.approving) => 'جارٍ الاعتماد…',
                // ★ **والإلغاءُ يُسمّى باسمه** — ⛔ **ولا «جارٍ الاعتماد».**
                (_, _InFlight.cancelling) => 'جارٍ الإلغاء…',
                (_, _InFlight.none) => 'اعتماد الجرد',
              },
            ),
          ),
        ),
      ],
    );
  }

  /// ★★★ **الفرقُ معروضاً** — و`null` **قبل إدخال عدٍّ صالح**.
  ///
  /// ⛔⛔★★ **ويُحسَب بدالة النطاق لا بطرحٍ في الشاشة** —
  /// `design-system.md` §5.1: ⟵ **ونسخةٌ ثانية من المعادلة تفترق عن حكم
  /// السحابة في أول حالةٍ حدّية** (`coding-standards.md` §2.2).
  String? _differenceLabel(StocktakeCardLine line) {
    final StockQuantity? actual = _countOf(line);
    if (actual == null) return null;
    final Outcome<StockQuantity> difference = stocktakeDifference(
      bookBalance: line.bookBalance,
      actualCount: actual,
    );
    return switch (difference) {
      Success<StockQuantity>(:final StockQuantity value) =>
        stocktakeAdjustment(value) == null
            ? 'مطابق'
            : '${value.isNegative ? "نقص" : "زيادة"} '
                '${quantityLabel(_absolute(value))}',
      Failure<StockQuantity>() => null,
    };
  }

  static StockQuantity _absolute(StockQuantity value) =>
      stocktakeAdjustment(value)?.quantity ?? value;
}

/// ★ الفعلُ الجاري في نموذج العدّ — ⛔ **ولا عَلَمَ واحدٌ لفعلين**.
enum _InFlight {
  /// لا فعلَ جارٍ.
  none,

  /// اعتمادٌ جارٍ.
  approving,

  /// إلغاءٌ جارٍ.
  cancelling,
}

/// صفُّ عدٍّ واحد — **النوع ورصيدُه المُجمَّد وعدُّه الفعلي وفرقُه**.
class _CountRow extends StatelessWidget {
  const _CountRow({
    required this.line,
    required this.count,
    required this.reason,
    required this.difference,
    required this.onChanged,
    this.missingCount = false,
    super.key,
  });

  final StocktakeCardLine line;
  final TextEditingController count;
  final TextEditingController reason;
  final String? difference;

  /// ★★ **هل سقط هذا السطر في آخر محاولةِ اعتماد؟** — `AM-021` ⑥.
  ///
  /// ⛔ **وافتراضُه `false`** — ★ **فالحدُّ إشارةٌ بعد الخطأ لا إنذارٌ قبله.**
  final bool missingCount;

  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.only(bottom: Spacing.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // ⛔⛔★★★ **والاسمُ المعروض هو المفتاح المركّب** — [`DEBT-86`] ③ ·
            //    [`ADR-0007`]: ⟵ **فسطرُ الجونية يُميَّز عن نوعِه المجرَّد**،
            //    ⛔ **و`itemName` المخزَّن وحدَه يعرض «عتود» لسطرَي جونيتين
            //    مختلفتين بلا تمييز** — ★ **وهو حرفياً الخيارُ 2 الذي رفضه
            //    `ADR-0007`.** ⚠️ **ورُصد على المحاكي لا في مراجعة.**
            Text(
              ledgerItemDisplayName(
                itemKey: line.itemKey,
                itemName: line.itemName,
              ),
              style: TypeScale.bodyMd,
            ),
            // 🔒 ★★★ **والرصيدُ الدفتري نصٌّ لا حقل** — `FR-M16-01`:
            //    ⟵ **مُجمَّدٌ لحظة البدء** ⛔ **ولا يُحرَّر ولا يُرسَل.**
            Text(
              'الرصيد الدفتري المُجمَّد: ${quantityLabel(line.bookBalance)}',
              style: TypeScale.caption,
            ),
            const SizedBox(height: Spacing.space8),
            TextField(
              key: Key('stocktake-count-${line.itemKey}'),
              controller: count,
              keyboardType: TextInputType.number,
              // ⛔⛔★★ **والحدُّ اللوني تعزيزٌ لا بديل** — §8 المحظور 12:
              //    ★ **الرسالةُ في الشريط تُسمّي السطرَ نصّاً**، ⟵ **والحدُّ
              //    يدلّ عليه في القائمة** ⛔ **ولا يحمل المعنى وحدَه.**
              decoration: InputDecoration(
                labelText: 'العدّ الفعلي',
                helperText: missingCount ? stocktakeMissingCountHint : null,
                helperStyle: missingCount
                    ? TypeScale.caption.copyWith(color: SemanticTriads.danger.ink)
                    : null,
                enabledBorder: missingCount
                    ? OutlineInputBorder(
                        borderRadius: BorderRadius.circular(Radii.md),
                        borderSide: BorderSide(
                          color: SemanticTriads.danger.border,
                          width: Sizes.borderWidth,
                        ),
                      )
                    : null,
              ),
              onChanged: (String _) => onChanged(),
            ),
            if (difference != null) ...<Widget>[
              const SizedBox(height: Spacing.space4),
              Text('الفرق: $difference', style: TypeScale.caption),
            ],
            const SizedBox(height: Spacing.space8),
            TextField(
              key: Key('stocktake-diff-reason-${line.itemKey}'),
              controller: reason,
              decoration: const InputDecoration(
                labelText: 'سبب الفرق',
                // ★★ **اختياريٌّ** — `FR-M16-04` · [`ADR-0020`]: ⛔ **وكان
                //   إلزامياً لكل فرق ≠ 0 قبل ذلك القرار.**
                helperText: 'اختياري — ولا يُكتب نيابةً عنك',
              ),
            ),
          ],
        ),
      );
}

/// ⚠️★★★ **تنبيهُ التجميد** — `FR-M16-03` نصّاً.
class _FreezeNotice extends StatelessWidget {
  const _FreezeNotice();

  @override
  Widget build(BuildContext context) => const _Notice(
        icon: Icons.lock_clock_outlined,
        text: 'بدء الجرد يُجمِّد الرصيد الدفتري للأنواع المختارة — '
            'والفرق يُحسَب عليه لا على رصيدٍ يتغيّر أثناء العدّ.',
      );
}

/// ★★ لافتةُ المسوّدة القائمة — `FR-M16-06`.
class _OpenDraftBanner extends StatelessWidget {
  const _OpenDraftBanner({required this.draft});

  final StocktakeCard draft;

  @override
  Widget build(BuildContext context) => _Notice(
        icon: Icons.pending_actions_outlined,
        text: 'جردٌ مفتوح ${draft.documentNumber} '
            'بتاريخ مخزون ${dayLabel(draft.stockDate)} — '
            'أتمَّه أو ألغِه قبل بدء جردٍ آخر على هذا المصدر واليوم.',
      );
}

/// ★ لافتةُ حالةٍ قائمة — **لا حدثٍ عابر** (`design-system.md` §6.ز).
class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text});

  final IconData icon;
  final String text;

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
            Icon(icon, size: Sizes.iconMd, color: SemanticTriads.warning.ink),
            const SizedBox(width: Spacing.space8),
            Expanded(
              child: Text(
                text,
                style:
                    TypeScale.bodyMd.copyWith(color: SemanticTriads.warning.ink),
              ),
            ),
          ],
        ),
      );
}

/// ★★ صفُّ تاريخ المخزون — `FR-M16-08`: ⛔ **ولا يقبل مستقبلياً أبداً**.
class _PriorDayRow extends StatelessWidget {
  const _PriorDayRow({
    required this.day,
    required this.today,
    required this.onChanged,
  });

  final CalendarDay day;
  final CalendarDay today;
  final ValueChanged<CalendarDay> onChanged;

  @override
  Widget build(BuildContext context) => Row(
        children: <Widget>[
          const Icon(Icons.event_outlined),
          const SizedBox(width: Spacing.space8),
          Expanded(
            child: Text(
              'تاريخ المخزون المجرود: ${dayLabel(day)}',
              style: TypeScale.bodyMd,
            ),
          ),
          TextButton(
            key: const Key('stocktake-date'),
            onPressed: () async {
              final DateTime? picked = await showDatePicker(
                context: context,
                initialDate: day.asUtcMidnight(),
                firstDate: DateTime.utc(today.year - 1),
                // ⛔⛔★★★ **والحدُّ الأعلى اليوم** — `FR-M16-08`:
                //    ★ **والمستقبلي مرفوضٌ في السحابة كذلك**،
                //    ⟵ **فالواجهة تُسهِّل** ⛔ **والحارس هناك.**
                lastDate: today.asUtcMidnight(),
              );
              if (picked != null) {
                onChanged(CalendarDay.fromUtc(picked.toUtc()));
              }
            },
            child: const Text('تغيير'),
          ),
        ],
      );
}

/// ★★★ **نتيجةُ نداءِ الجرد — نصُّها وحُكمُها** (`AM-021` ④ · **تصحيحٌ باعتمادك
/// 2026-09-15**).
///
/// ⛔⛔★★★ **والحكمُ حقلٌ لا رمزٌ في النصّ** — `design-system.md` §6-ز:
/// ⟵ **فالشاشةُ تترجمه ثلاثيةً لونيةً كاملة** (`QtmsActionStatus`)،
/// ⛔ **ولا تُفتّش عن `✅` في أول النصّ لتعرف أنجح الفعلُ أم فشل.**
///
/// ⚠️⚠️ **وكانت هذه الشاشةُ وحدَها باقيةً على النصّ العاري بعد `AM-021`** —
/// ★ **لأن نطاقَ الطلب حصر البند ④ في «الإتلاف»**: ⟹ **فرُفع البندُ للمالك
/// ولم يُنفَّذ صامتاً**، ✅ **ثم اعتمده صراحةً فنُفِّذ بالنمط المرجعي نفسِه**
/// (`_DisposalStatus`) ⛔ **بلا مكوّنٍ ولا نمطٍ موازٍ جديد** (§8 المحظور 11).
@immutable
class _StocktakeStatus {
  const _StocktakeStatus({required this.message, required this.succeeded});

  /// النصّ — ★ **من الكتالوج عند الفشل** ⛔ **ولا صياغةَ خطأٍ هنا.**
  final String message;

  /// ★ هل نجح النداء؟ — ⛔ **ولا حالةَ ثالثة: الغيابُ `null` في الحقل نفسِه.**
  final bool succeeded;
}

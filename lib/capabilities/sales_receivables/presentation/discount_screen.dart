/// شاشة **الخصومات** (`M13`) — **إسقاطُ دَينٍ بلا نقد**.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **وأخطر ما يُساء فهمه في هذه الشاشة — `FR-M15-06-أ`:**
///
/// **الخصمُ ليس قبضاً ولا يُدخَل كمبلغٍ واصل.** ⟵ **ما دفعه المقوت نقداً
/// وما أسقطه المالك عنه رقمان مختلفان** — ★ **وخلطُهما يُظهر المقوتَ وكأنه
/// سدّد مالاً لم يدفعه** فيُفسِد سجلَّ التزامه، ⛔ **ويُفقِد المالكَ معرفةَ
/// كم أسقط فعلاً.** ⟹ ★ **ولذلك شاشةٌ مستقلة ومسارٌ مستقل ومجموعةٌ مستقلة.**
///
/// ⛔⛔★★★ **ولا حقلَ فائضٍ في هذه الشاشة إطلاقاً** (`FR-M13-05` · `AT-35`) —
/// ★ **غيابٌ بنيويٌّ لا حقلٌ مُعطَّل**: ⟵ **والسحابةُ ترفض *وجود* المفتاح
/// بـ`ERR_DIST_009`** ⛔ **ولو أُرسل صفراً.**
/// ═══════════════════════════════════════════════════════════════════════
///
/// ⛔⛔★★★ **والتوزيع التلقائي اقتراحٌ لا قرار** — `FR-M13-07`: ⟵ **يُحسَب
/// محلياً، ويُعرَض في الحقول قابلاً للتعديل، ولا يُحفَظ إلا بضغطة المستخدم**
/// — ★ **وما يُرسَل هو ما في الحقول لحظة الحفظ** ⛔ **لا مخرَجُ الخوارزمية.**
///
/// ⚠️⚠️ **وكل ما هنا عرضٌ لا حماية** — ★ **والرفض الحقيقي في السحابة**
/// (`ADR-0013` القاعدة 3 · `RISK-02`): `discounts` **مغلقة للكتابة**،
/// **والصلاحية والنطاق والتاريخ والمبلغ كلها في `planDiscount`.**
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
import '../../../core/ui/date_labels.dart';
import '../../../core/ui/live_summary.dart';
import '../../../core/ui/skeleton.dart';
import '../../../core/ui/sticky_action_bar.dart';
import '../../inventory/application/inventory_providers.dart';
import '../../master_data/application/master_data_providers.dart';
import '../application/discount_providers.dart';
import '../application/receipt_providers.dart' show OpenDebtQuery;

/// شاشة الخصومات.
class DiscountScreen extends ConsumerStatefulWidget {
  /// ينشئ الشاشة.
  const DiscountScreen({super.key});

  @override
  ConsumerState<DiscountScreen> createState() => _DiscountScreenState();
}

class _DiscountScreenState extends ConsumerState<DiscountScreen> {
  String? _dealerId;

  /// ★ **المصدر المحدد أو `null` لـ«الكل»** — `FR-M13-01`.
  String? _sourceFilter;

  @override
  Widget build(BuildContext context) {
    final List<DealerCard> dealers =
        ref.watch(dealersProvider).value ?? const <DealerCard>[];
    final List<SourceCard> sources = ref.watch(activeSourcesProvider);
    final String? dealerId = _dealerId;

    return Scaffold(
      appBar: QtmsTopBar(screenTitle: 'الخصومات'),
      body: Column(
        children: <Widget>[
          _DiscountHeader(
            dealers: dealers,
            sources: sources,
            dealerId: dealerId,
            sourceFilter: _sourceFilter,
            onDealer: (String id) => setState(() => _dealerId = id),
            onSource: (String? id) => setState(() => _sourceFilter = id),
          ),
          const Divider(height: Sizes.borderWidth),
          Expanded(
            child: dealerId == null
                ? const QtmsEmptyState(
                    spec: EmptyStateSpec(
                      icon: Icons.person_search_outlined,
                      title: 'اختر المقوت',
                      message:
                          'اختر المقوت لعرض ضماراته المفتوحة وتسجيل الخصم.',
                    ),
                  )
                : _DiscountForm(
                    // ★★ **قائمةُ المصادر مُعدَّدة** — راجع [OpenDebtQuery]:
                    //    ⛔ **ولا «الكل» ضمنية تُرفَض في القاعدة.**
                    sourceIds: <String>[
                      if (_sourceFilter case final String only)
                        only
                      else
                        for (final SourceCard source in sources) source.sourceId,
                    ],
                    // ★ **مفتاحٌ مركّب** — ⟵ **فتبديلُ المقوت أو المصدر
                    //   يُعيد بناء النموذج بحالةٍ نظيفة**، ⛔ **ولا تبقى
                    //   مبالغُ مقوتٍ سابق في حقول مقوتٍ آخر.**
                    key: ValueKey<String>('${dealerId}_${_sourceFilter ?? '*'}'),
                    dealerId: dealerId,
                    sourceFilter: _sourceFilter,
                  ),
          ),
        ],
      ),
    );
  }
}

/// رأس الشاشة — **المقوت والمصدر** (`FR-M13-01`).
class _DiscountHeader extends StatelessWidget {
  const _DiscountHeader({
    required this.dealers,
    required this.sources,
    required this.dealerId,
    required this.sourceFilter,
    required this.onDealer,
    required this.onSource,
  });

  final List<DealerCard> dealers;
  final List<SourceCard> sources;
  final String? dealerId;
  final String? sourceFilter;
  final ValueChanged<String> onDealer;
  final ValueChanged<String?> onSource;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: Spacing.screenPadding,
          vertical: Spacing.space8,
        ),
        child: Column(
          children: <Widget>[
            DropdownButtonFormField<String>(
              key: const Key('discount-dealer'),
              initialValue: dealerId,
              decoration: const InputDecoration(labelText: 'المقوت'),
              items: <DropdownMenuItem<String>>[
                for (final DealerCard dealer in dealers)
                  DropdownMenuItem<String>(
                    value: dealer.dealerId,
                    child: Text(dealer.name),
                  ),
              ],
              onChanged: (String? value) {
                if (value != null) onDealer(value);
              },
            ),
            const SizedBox(height: Spacing.space8),
            // ★★ **والمصدر «محدد أو الكل»** — `FR-M13-01`: ⟵ **و«الكل»
            //    قيمةٌ أولى صريحة** ⛔ **لا غيابُ اختيار.**
            DropdownButtonFormField<String?>(
              key: const Key('discount-source'),
              initialValue: sourceFilter,
              decoration: const InputDecoration(labelText: 'المصدر'),
              items: <DropdownMenuItem<String?>>[
                const DropdownMenuItem<String?>(child: Text('كل المصادر')),
                for (final SourceCard source in sources)
                  DropdownMenuItem<String?>(
                    value: source.sourceId,
                    child: Text(source.name),
                  ),
              ],
              onChanged: onSource,
            ),
          ],
        ),
      );
}

/// نموذج السند — ★ **حالةٌ محلية حتى الحفظ**.
class _DiscountForm extends ConsumerStatefulWidget {
  const _DiscountForm({
    required this.dealerId,
    required this.sourceFilter,
    required this.sourceIds,
    super.key,
  });

  final String dealerId;
  final String? sourceFilter;

  /// ★ المصادر المُعدَّدة — راجع [OpenDebtQuery].
  final List<String> sourceIds;

  @override
  ConsumerState<_DiscountForm> createState() => _DiscountFormState();
}

class _DiscountFormState extends ConsumerState<_DiscountForm> {
  final Map<String, TextEditingController> _amounts =
      <String, TextEditingController>{};

  /// ★ مبلغٌ إجماليٌّ **للتوزيع التلقائي وحده** — ⛔ **ولا يُرسَل قط**.
  ///
  /// ⛔⛔★★★ **وليس «فائضاً»** (`FR-M13-05`) — ★ **حقلُ إدخالٍ محليٌّ يُغذّي
  /// الاقتراح**: ⟵ **وما يزيد عن الديون يُعرَض تنبيهاً «غير موزَّع»**،
  /// ⛔ **ولا يُحفَظ في أي مستند ولا يُرسَل في أي حمولة.**
  final TextEditingController _autoAmount = TextEditingController();

  CalendarDay? _date;
  bool _usedAutoAllocation = false;
  bool _saving = false;
  String? _status;

  @override
  void dispose() {
    for (final TextEditingController controller in _amounts.values) {
      controller.dispose();
    }
    _autoAmount.dispose();
    super.dispose();
  }

  TextEditingController _controllerFor(String lotId) =>
      _amounts.putIfAbsent(lotId, TextEditingController.new);

  Money _amountOf(String lotId) =>
      Money.tryParseInput(_controllerFor(lotId).text) ?? Money.zero;

  Money _totalOf(List<OpenDebtLot> lots) {
    Money total = Money.zero;
    for (final OpenDebtLot lot in lots) {
      total = total + _amountOf(lot.debtLotId);
    }
    return total;
  }

  /// ⛔⛔★★★ **هل يوجد سطرٌ يتجاوز متبقّيه؟** — **الحرس الرباعي ④**
  /// (`design-system.md` §6-ط · `AM-015` ⑥).
  ///
  /// ⚠️⚠️★★★ **والثلاثةُ قبله كانت قائمةً وحدَها:** ★ **`errorText` «يتجاوز
  /// المتبقي» يظهر على الحقل**، ⛔ **وزرُّ الحفظ يقبل الضغطَ رغمَه** ⟹
  /// **فيُرفَض الطلبُ من السحابة بعد رحلةِ شبكة.** ⟵ **وزرٌّ يقبل ما وسمه
  /// خطأً يُعلِّم المستخدمَ أن التحذيرَ زخرفة.**
  ///
  /// ⚠️★★ **والتعطيلُ عرضٌ لا حماية** (`RISK-02`) — ★ **والرفضُ الحقيقيُّ
  /// في السحابة كما هو** (`BR-M13-02`)، ⛔ **ولا يُسقِط هذا شرطاً منها.**
  bool _hasExceedingLine(List<OpenDebtLot> lots) => lots.any(
        (OpenDebtLot lot) => _amountOf(lot.debtLotId) > lot.remaining,
      );

  /// ★★★ **التوزيع التلقائي** — ⛔ **يملأ الحقول ولا يحفظ** (`FR-M13-07`).
  void _autoAllocate(List<OpenDebtLot> lots, Money amount) {
    // ★ **والمعادلة من طبقة النطاق** ([allocateDiscountAutomatically]) —
    //   ⛔ **ولا نسخة ثانية منها هنا** (`ADR-0009`).
    final DiscountAllocationProposal proposal =
        allocateDiscountAutomatically(amount: amount, openLots: lots);
    setState(() {
      for (final OpenDebtLot lot in lots) {
        _controllerFor(lot.debtLotId).text = '';
      }
      for (final DiscountLineInput line in proposal.lines) {
        _controllerFor(line.debtLotId).text = '${line.amount.riyals}';
      }
      _usedAutoAllocation = true;
      _status = proposal.unallocated.isZero
          ? null
          : '⚠️ ${formatRiyals(proposal.unallocated)} ريال لم تُوزَّع — '
              'المبلغ يتجاوز ما على المقوت في هذا النطاق.';
    });
  }

  Future<void> _save(List<OpenDebtLot> lots, CalendarDay today) async {
    final List<DiscountLineInput> lines = <DiscountLineInput>[
      for (final OpenDebtLot lot in lots)
        if (!_amountOf(lot.debtLotId).isZero)
          DiscountLineInput(
            debtLotId: lot.debtLotId,
            amount: _amountOf(lot.debtLotId),
          ),
    ];
    // ⛔⛔★★ **وسندٌ بلا سطرٍ يُرفَض هنا وفي السحابة معاً** — ★ **وهنا
    //    يفترق عن سند القبض**: ⟵ **لا فائضَ يُنقِذه** (`FR-M13-05`).
    if (lines.isEmpty) {
      setState(() => _status = '❌ أدخل مبلغ خصمٍ على ضمارٍ واحد على الأقل.');
      return;
    }

    setState(() {
      _saving = true;
      _status = null;
    });

    final Outcome<String> result =
        await ref.read(discountAdminProvider).createDiscount(
              dealerId: widget.dealerId,
              date: _date ?? today,
              lines: lines,
              sourceFilter: widget.sourceFilter,
              usedAutoAllocation: _usedAutoAllocation,
            );
    if (!mounted) return;
    setState(() {
      _saving = false;
      _status = switch (result) {
        Success<String>(:final String value) => '✅ حُفِظ سند الخصم $value',
        Failure<String>(:final AppError error) =>
          catalogText(appErrorMessage(error)),
      };
      if (result is Success<String>) {
        for (final TextEditingController controller in _amounts.values) {
          controller.clear();
        }
        _autoAmount.clear();
        _usedAutoAllocation = false;
      }
    });
    if (result is Success<String>) _refreshDerivedReads();
  }

  /// ⛔⛔★★★ **إبطالُ المشتقّات بعد كتابةٍ ناجحة — `DEBT-61` بعينه.**
  ///
  /// ★★ **ولماذا لا يكفي بثُّ المزوّد وهو `StreamProvider`:** ★ **بثُّه على
  /// مستندات `distributions` الأب** ⛔ **والمتبقي يُقرأ قراءةً مفردةً من
  /// `pricing/current`** — ⟵ **وسندُ الخصم لا يمسّ الأب إلا في
  /// `settlementStatus`**: ★ **والمبالغُ كلُّها في المستند الفرعي** (`IQ-027`).
  /// ⟹ ⛔⛔ **فيبقى «المتبقي» على قيمته قبل الخصم** — ★ **وأثرُه هنا أخطرُ
  /// منه في القبض**: ⟵ **يُخصَم مرتين فيسقط دَينٌ لم يُسقِطه المالك.**
  void _refreshDerivedReads() {
    ref.invalidate(
      openDiscountDebtLotsProvider(
        OpenDebtQuery(
          dealerId: widget.dealerId,
          sourceIds: widget.sourceIds,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final CalendarDay today = ref.watch(todayProvider);
    final AsyncValue<List<OpenDebtLot>> lotsAsync = ref.watch(
      openDiscountDebtLotsProvider(
        OpenDebtQuery(
          dealerId: widget.dealerId,
          sourceIds: widget.sourceIds,
        ),
      ),
    );

    return lotsAsync.when(
      // ⛔⛔★★ **الهيكل العظمي وحده حالةً للتحميل** — `design-system.md` §هـ.
      loading: () => const SkeletonList(),
      error: (Object error, StackTrace _) => QtmsErrorState(
        message: catalogText(CatalogMessage.operationFailed),
        detail: '$error',
      ),
      data: (List<OpenDebtLot> lots) => _body(lots, today),
    );
  }

  Widget _body(List<OpenDebtLot> lots, CalendarDay today) {
    final Money totalDebt = totalOpenDebt(lots);
    final Money total = _totalOf(lots);
    final bool exceeds = _hasExceedingLine(lots);
    final Money autoAmount =
        Money.tryParseInput(_autoAmount.text) ?? Money.zero;

    return Column(
      children: <Widget>[
        Expanded(
          child: ListView(
            padding: const EdgeInsetsDirectional.all(Spacing.screenPadding),
            children: <Widget>[
              // ★★ **إجمالي الديون فور اختيار المقوت** — `FR-M13-01`
              //    **قبل أي إدخال**.
              _DebtBanner(totalDebt: totalDebt, lotCount: lots.length),
              const SizedBox(height: Spacing.space12),
              _DateRow(
                date: _date ?? today,
                today: today,
                onChanged: (CalendarDay day) => setState(() => _date = day),
              ),
              const SizedBox(height: Spacing.space12),
              if (lots.isEmpty)
                const QtmsEmptyState(
                  spec: EmptyStateSpec(
                    icon: Icons.check_circle_outline,
                    title: 'لا ضمارات مفتوحة',
                    message: 'لا يوجد على هذا المقوت ضمارٌ مفتوح في هذا '
                        'النطاق — ولا شيء يُخصَم منه.',
                  ),
                )
              else ...<Widget>[
                for (final OpenDebtLot lot in lots)
                  _LotRow(
                    lot: lot,
                    controller: _controllerFor(lot.debtLotId),
                    onChanged: () => setState(() {}),
                  ),
                const SizedBox(height: Spacing.space12),
                _AutoAllocateField(
                  key: const Key('discount-auto-amount'),
                  controller: _autoAmount,
                  onChanged: () => setState(() {}),
                  onAllocate: autoAmount.isZero
                      ? null
                      : () => _autoAllocate(lots, autoAmount),
                ),
              ],
            ],
          ),
        ),
        QtmsStickyActionBar(
          summary: QtmsLiveSummary(
            // ⛔⛔★★★ **«المخصوم» لا «المقبوض»** — `FR-M15-06-أ`: ⟵ **والنصُّ
            //    نفسُه جزءٌ من الحارس**، ★ **فالمستخدم يقرأ ما يفعله.**
            headline: 'إجمالي الخصم: ${formatRiyals(total)} ريال',
            details: <String>[
              'عدد الضمارات المخصومة: ${_touchedCount(lots)}',
              // ★★ **وتذكيرٌ صريح أنه بلا نقد** — `schema/discounts.md` ④.
              'بلا أثر نقدي — لا يدخل الصندوق',
              // ★★ **الحرس الرباعي ③** — `design-system.md` §6-ط.
              if (exceeds) 'سطرٌ يتجاوز متبقّي ضماره — يلزم تصحيحُه قبل الحفظ',
            ],
            emphasis: 'الديون المفتوحة: ${formatRiyals(totalDebt)} ريال',
          ),
          status: switch ((_status, exceeds)) {
            (final String message, _) => Text(message, style: TypeScale.bodyMd),
            (null, true) => QtmsActionStatus.rejection(
                'سطرٌ يتجاوز متبقّي ضماره — صحّحه ليُفتَح الحفظ.',
              ),
            (null, false) => null,
          },
          primary: FilledButton(
            key: const Key('discount-save'),
            // ⛔⛔★★★ **الحرس الرباعي ④ — تعطيلٌ فعلي** (`AM-015` ⑥).
            onPressed: _saving || exceeds ? null : () => _save(lots, today),
            child: Text(_saving ? 'جارٍ الحفظ…' : 'حفظ سند الخصم'),
          ),
        ),
      ],
    );
  }

  int _touchedCount(List<OpenDebtLot> lots) {
    int count = 0;
    for (final OpenDebtLot lot in lots) {
      if (!_amountOf(lot.debtLotId).isZero) count++;
    }
    return count;
  }
}

/// ★★ لافتة إجمالي الديون — `FR-M13-01`.
class _DebtBanner extends StatelessWidget {
  const _DebtBanner({required this.totalDebt, required this.lotCount});

  final Money totalDebt;
  final int lotCount;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsetsDirectional.all(Spacing.space12),
        decoration: BoxDecoration(
          color: SemanticColors.surfaceSunken,
          border: Border.all(
            color: SemanticColors.border,
            width: Sizes.borderWidth,
          ),
          borderRadius: BorderRadius.circular(Radii.card),
        ),
        child: Row(
          children: <Widget>[
            const Icon(Icons.account_balance_wallet_outlined),
            const SizedBox(width: Spacing.space8),
            Expanded(
              child: Text(
                'إجمالي الديون على المقوت: ${formatRiyals(totalDebt)} ريال '
                '($lotCount ضمار مفتوح)',
                style: TypeScale.bodyMd,
              ),
            ),
          ],
        ),
      );
}

/// ★★ صفّ التاريخ — `FR-M13-06`: ⛔ **ولا يقبل مستقبلياً أبداً**.
class _DateRow extends StatelessWidget {
  const _DateRow({
    required this.date,
    required this.today,
    required this.onChanged,
  });

  final CalendarDay date;
  final CalendarDay today;
  final ValueChanged<CalendarDay> onChanged;

  @override
  Widget build(BuildContext context) => Row(
        children: <Widget>[
          const Icon(Icons.event_outlined),
          const SizedBox(width: Spacing.space8),
          Expanded(
            child: Text(
              'تاريخ السند: ${dayLabel(date)}',
              style: TypeScale.bodyMd,
            ),
          ),
          TextButton(
            key: const Key('discount-date'),
            onPressed: () async {
              final DateTime? picked = await showDatePicker(
                context: context,
                initialDate: date.asUtcMidnight(),
                firstDate: DateTime.utc(today.year - 1),
                // ⛔⛔★★★ **والحدُّ الأعلى اليوم** — `FR-M13-06`:
                //    ★ **والمستقبلي مرفوضٌ في السحابة كذلك** (`ERR_DIST_006`)،
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

/// صفّ ضمارٍ مفتوح — **المتبقي ومبلغ الخصم والمتبقي بعده** (`FR-M13-02`).
class _LotRow extends StatelessWidget {
  const _LotRow({
    required this.lot,
    required this.controller,
    required this.onChanged,
  });

  final OpenDebtLot lot;
  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final Money amount = Money.tryParseInput(controller.text) ?? Money.zero;
    final Money after = lot.remaining - amount;
    // ★★ **والتجاوز يُعرَض لحظياً** — ⛔ **والرفض الحقيقي في السحابة**
    //    (`BR-M13-02` · `ERR_DIST_005` · `RISK-02`).
    final bool exceeds = amount > lot.remaining;

    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: Spacing.space12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'ضمار ${dayLabel(lot.stockDate)} — مصدر ${lot.sourceId}',
            style: TypeScale.bodyMd,
          ),
          const SizedBox(height: Spacing.space4),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  // ★ **مفتاحٌ بالضمار** — ⟵ **فيُقرأ الحقل بمعرّفه**
                  //   ⛔ **لا بترتيبه بين الحقول المرئية.**
                  key: Key('discount-lot-${lot.debtLotId}'),
                  controller: controller,
                  keyboardType: TextInputType.number,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  decoration: InputDecoration(
                    // ⛔⛔★★★ **«الخصم» لا «الواصل»** — `FR-M15-06-أ`.
                    labelText: 'الخصم',
                    // ★★ **الحرس الرباعي ①** — `design-system.md` §6-ط.
                    //   ⛔ **ونصٌّ قصيرٌ عمداً** — راجع نظيرَه في المقبوضات.
                    helperText: 'المتبقي ${formatRiyals(lot.remaining)}',
                    errorText: exceeds ? 'يتجاوز المتبقي' : null,
                  ),
                  onChanged: (String _) => onChanged(),
                ),
              ),
              Expanded(
                child: Text(
                  'بعده: ${formatRiyals(after)}',
                  style: TypeScale.caption,
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// ★★ حقلُ التوزيع التلقائي — `FR-M13-07`.
///
/// ⛔⛔★★★ **وليس حقلَ فائض** — ★ **مبلغٌ محليٌّ يُغذّي الاقتراح وحده**:
/// ⟵ **لا يُرسَل ولا يُحفَظ**، ★ **وما يزيد عن الديون يُعرَض تنبيهاً**
/// ⛔ **لا رصيداً يُسدَّد منه لاحقاً** (`FR-M13-05`).
class _AutoAllocateField extends StatelessWidget {
  const _AutoAllocateField({
    required this.controller,
    required this.onChanged,
    required this.onAllocate,
    super.key,
  });

  final TextEditingController controller;
  final VoidCallback onChanged;
  final VoidCallback? onAllocate;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
            ],
            decoration: const InputDecoration(
              labelText: 'مبلغ للتوزيع التلقائي',
              helperText: 'يُوزَّع على الضمارات بالأقدم أولاً — للمراجعة قبل '
                  'الحفظ',
            ),
            onChanged: (String _) => onChanged(),
          ),
          const SizedBox(height: Spacing.space8),
          // ★★★ **ميزةٌ اختيارية** (`FR-M13-07`): ⛔ **واليدوي متاحٌ دائماً.**
          OutlinedButton.icon(
            key: const Key('discount-auto-allocate'),
            onPressed: onAllocate,
            icon: const Icon(Icons.auto_awesome_outlined),
            label: const Text('توزيع تلقائي (الأقدم أولاً)'),
          ),
        ],
      );
}

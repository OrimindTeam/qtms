/// شاشة **المقبوضات وحساب المقوت** (`M12`) — **تحصيلٌ نقديٌّ يومي**.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **وأخطر ما يُساء فهمه في هذه الشاشة — `FR-M12-14`:**
///
/// **التوزيع التلقائي اقتراحٌ لا قرار.** ⟵ **يُحسَب محلياً، ويُعرَض في
/// الحقول قابلاً للتعديل، ولا يُحفَظ إلا بضغطة المستخدم** — ★ **وما يُرسَل
/// هو ما في الحقول لحظة الحفظ** ⛔ **لا مخرَجُ الخوارزمية.**
/// ═══════════════════════════════════════════════════════════════════════
///
/// ⚠️⚠️ **والتمييز الحاكم `GR-41`** (`FR-M12-20`): **تاريخ السند هو «المقبوض
/// في تاريخ»** ⛔ **لا تاريخ الضمار المسدَّد** — ★ **ولذلك يظهر في الرأس
/// مستقلاً عن تواريخ الضمارات في السطور.**
///
/// ⚠️⚠️ **وكل ما هنا عرضٌ لا حماية** — ★ **والرفض الحقيقي في السحابة**
/// (`ADR-0013` القاعدة 3 · `RISK-02`): `receipts` **مغلقة للكتابة**،
/// **والصلاحية والنطاق والتاريخ والمبلغ كلها في `planReceipt`.**
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show FilteringTextInputFormatter, TextInputFormatter;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qtms_domain/qtms_domain.dart';

import '../../../core/design/design_tokens.dart';
import '../../../core/messages/error_messages.dart';
import '../../../core/ui/async_state_view.dart';
import '../../../core/ui/date_labels.dart';
import '../../../core/ui/live_summary.dart';
import '../../../core/ui/skeleton.dart';
import '../../../core/ui/sticky_action_bar.dart';
import '../../inventory/application/inventory_providers.dart';
import '../../master_data/application/master_data_providers.dart';
import '../application/receipt_providers.dart';

/// شاشة المقبوضات.
class ReceiptScreen extends ConsumerStatefulWidget {
  /// ينشئ الشاشة.
  const ReceiptScreen({super.key});

  @override
  ConsumerState<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends ConsumerState<ReceiptScreen> {
  String? _dealerId;

  /// ★ **المصدر المحدد أو `null` لـ«الكل»** — `FR-M12-04`.
  String? _sourceFilter;

  @override
  Widget build(BuildContext context) {
    final List<DealerCard> dealers =
        ref.watch(dealersProvider).value ?? const <DealerCard>[];
    final List<SourceCard> sources = ref.watch(activeSourcesProvider);
    final String? dealerId = _dealerId;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: SemanticColors.surface,
        title: const Text('المقبوضات', style: TypeScale.titleSm),
      ),
      body: Column(
        children: <Widget>[
          _ReceiptHeader(
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
                      message: 'اختر المقوت لعرض ضماراته المفتوحة وتسجيل القبض.',
                    ),
                  )
                : _ReceiptForm(
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

/// رأس الشاشة — **المقوت والمصدر** (`FR-M12-01` · `FR-M12-04`).
class _ReceiptHeader extends StatelessWidget {
  const _ReceiptHeader({
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
            // ★★ **والمصدر «محدد أو الكل»** — `FR-M12-04`: ⟵ **و«الكل»
            //    قيمةٌ أولى صريحة** ⛔ **لا غيابُ اختيار.**
            DropdownButtonFormField<String?>(
              initialValue: sourceFilter,
              decoration: const InputDecoration(labelText: 'المصدر'),
              items: <DropdownMenuItem<String?>>[
                const DropdownMenuItem<String?>(
                  child: Text('كل المصادر'),
                ),
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
class _ReceiptForm extends ConsumerStatefulWidget {
  const _ReceiptForm({
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
  ConsumerState<_ReceiptForm> createState() => _ReceiptFormState();
}

class _ReceiptFormState extends ConsumerState<_ReceiptForm> {
  final Map<String, TextEditingController> _amounts =
      <String, TextEditingController>{};
  final TextEditingController _surplus = TextEditingController();

  CalendarDay? _date;
  bool _usedAutoAllocation = false;
  bool _saving = false;
  String? _status;

  @override
  void dispose() {
    for (final TextEditingController controller in _amounts.values) {
      controller.dispose();
    }
    _surplus.dispose();
    super.dispose();
  }

  TextEditingController _controllerFor(String lotId) =>
      _amounts.putIfAbsent(lotId, TextEditingController.new);

  Money _amountOf(String lotId) =>
      Money.tryParseInput(_controllerFor(lotId).text) ?? Money.zero;

  Money get _surplusAmount => Money.tryParseInput(_surplus.text) ?? Money.zero;

  Money _totalOf(List<OpenDebtLot> lots) {
    Money total = _surplusAmount;
    for (final OpenDebtLot lot in lots) {
      total = total + _amountOf(lot.debtLotId);
    }
    return total;
  }

  /// ★★★ **التوزيع التلقائي** — ⛔ **يملأ الحقول ولا يحفظ** (`FR-M12-14`).
  void _autoAllocate(List<OpenDebtLot> lots, Money amount) {
    final AutoAllocationProposal proposal =
        proposeAutoAllocation(amount: amount, openLots: lots);
    setState(() {
      for (final OpenDebtLot lot in lots) {
        _controllerFor(lot.debtLotId).text = '';
      }
      for (final ReceiptLineInput line in proposal.lines) {
        _controllerFor(line.debtLotId).text = '${line.amount.riyals}';
      }
      _surplus.text =
          proposal.surplus.isZero ? '' : '${proposal.surplus.riyals}';
      _usedAutoAllocation = true;
    });
  }

  Future<void> _save(List<OpenDebtLot> lots, CalendarDay today) async {
    final List<ReceiptLineInput> lines = <ReceiptLineInput>[
      for (final OpenDebtLot lot in lots)
        if (!_amountOf(lot.debtLotId).isZero)
          ReceiptLineInput(
            debtLotId: lot.debtLotId,
            amount: _amountOf(lot.debtLotId),
          ),
    ];
    if (lines.isEmpty && _surplusAmount.isZero) {
      setState(() => _status = '❌ أدخل مبلغاً على ضمارٍ واحد على الأقل.');
      return;
    }

    setState(() {
      _saving = true;
      _status = null;
    });
    final Outcome<String> result =
        await ref.read(receiptAdminProvider).createReceipt(
              dealerId: widget.dealerId,
              date: _date ?? today,
              lines: lines,
              sourceFilter: widget.sourceFilter,
              surplusAmount: _surplusAmount,
              // ★★ **ونطاق الفائض يتبع فلتر السند** — `FR-M12-12`:
              //    ⟵ **فائضُ «الكل» عامٌّ، وفائضُ مصدرٍ يخصّه** (`E-13`).
              surplusScope: widget.sourceFilter == null
                  ? SurplusScope.general
                  : SurplusScope.source,
              usedAutoAllocation: _usedAutoAllocation,
            );
    if (!mounted) return;
    setState(() {
      _saving = false;
      _status = switch (result) {
        Success<String>(:final String value) => '✅ حُفِظ السند $value',
        Failure<String>(:final AppError error) =>
          catalogText(appErrorMessage(error)),
      };
      if (result is Success<String>) {
        for (final TextEditingController controller in _amounts.values) {
          controller.clear();
        }
        _surplus.clear();
        _usedAutoAllocation = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final CalendarDay today = ref.watch(todayProvider);
    final AsyncValue<List<OpenDebtLot>> lotsAsync = ref.watch(
      openDebtLotsProvider(
        OpenDebtQuery(
          dealerId: widget.dealerId,
          sourceIds: widget.sourceIds,
        ),
      ),
    );

    return lotsAsync.when(
      // ⛔⛔★★ **الهيكل العظمي وحده حالةً للتحميل** — `design-system.md` §هـ
      //    (**بوابة الحِرفية البصرية**): ⛔ **ولا مؤشّرَ دوّار.**
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

    return Column(
      children: <Widget>[
        Expanded(
          child: ListView(
            padding: const EdgeInsetsDirectional.all(Spacing.screenPadding),
            children: <Widget>[
              // ★★ **إجمالي الديون فور اختيار المقوت** — `FR-M12-03`
              //    **قبل أي إدخال** (`BR-M12-11`).
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
                    message:
                        'لا يوجد على هذا المقوت ضمارٌ مفتوح في هذا النطاق. '
                        'يمكنك تسجيل مبلغ فائض إن دفع مقدَّماً.',
                  ),
                )
              else ...<Widget>[
                for (final OpenDebtLot lot in lots)
                  _LotRow(
                    lot: lot,
                    controller: _controllerFor(lot.debtLotId),
                    onChanged: () => setState(() {}),
                  ),
                const SizedBox(height: Spacing.space8),
                // ★★★ **التوزيع التلقائي — ميزةٌ اختيارية** (`FR-M12-13`):
                //    ⛔ **واليدوي متاحٌ دائماً.**
                OutlinedButton.icon(
                  key: const Key('receipt-auto-allocate'),
                  onPressed: total.isZero
                      ? null
                      : () => _autoAllocate(lots, total),
                  icon: const Icon(Icons.auto_awesome_outlined),
                  label: const Text('توزيع تلقائي (الأقدم أولاً)'),
                ),
              ],
              const SizedBox(height: Spacing.space12),
              _SurplusField(
                key: const Key('receipt-surplus'),
                controller: _surplus,
                onChanged: () => setState(() {}),
                openDebt: totalDebt,
              ),
            ],
          ),
        ),
        QtmsStickyActionBar(
          summary: QtmsLiveSummary(
            headline: 'إجمالي المقبوض: ${total.riyals} ريال',
            details: <String>[
              'على الضمارات: ${(total - _surplusAmount).riyals} ريال',
              'فائض: ${_surplusAmount.riyals} ريال',
            ],
            emphasis: 'الديون المفتوحة: ${totalDebt.riyals} ريال',
          ),
          status: _status == null
              ? null
              : Text(_status!, style: TypeScale.bodyMd),
          primary: FilledButton(
            key: const Key('receipt-save'),
            onPressed: _saving ? null : () => _save(lots, today),
            child: Text(_saving ? 'جارٍ الحفظ…' : 'حفظ سند القبض'),
          ),
        ),
      ],
    );
  }
}

/// ★★ لافتة إجمالي الديون — `FR-M12-03` · `BR-M12-11`.
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
                'إجمالي الديون على المقوت: ${totalDebt.riyals} ريال '
                '($lotCount ضمار مفتوح)',
                style: TypeScale.bodyMd,
              ),
            ),
          ],
        ),
      );
}

/// ★★ صفّ التاريخ — `FR-M12-02`: ⛔ **ولا يقبل مستقبلياً أبداً**.
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
            child: Text('تاريخ السند: ${dayLabel(date)}',
                style: TypeScale.bodyMd),
          ),
          TextButton(
            onPressed: () async {
              final DateTime? picked = await showDatePicker(
                context: context,
                initialDate: date.asUtcMidnight(),
                firstDate: DateTime.utc(today.year - 1),
                // ⛔⛔★★★ **والحدُّ الأعلى اليوم** — `FR-M12-02`:
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

/// صفّ ضمارٍ مفتوح — **المتبقي والمبلغ الواصل والمتبقي بعده** (`FR-M12-05`).
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
    //    (`BR-M12-02` · `RISK-02`).
    final bool exceeds = amount > lot.remaining;

    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: Spacing.space12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            // ★ **بصيغة «ضمار {التاريخ} مصدر {المصدر}»** — `FR-M12-05`.
            'ضمار ${dayLabel(lot.stockDate)} — مصدر ${lot.sourceId}',
            style: TypeScale.bodyMd,
          ),
          const SizedBox(height: Spacing.space4),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'المتبقي: ${lot.remaining.riyals}',
                  style: TypeScale.caption,
                ),
              ),
              Expanded(
                child: TextField(
                  // ★ **مفتاحٌ بالضمار** — ⟵ **فيُقرأ الحقل بمعرّفه**
                  //   ⛔ **لا بترتيبه بين الحقول المرئية.**
                  key: Key('receipt-lot-${lot.debtLotId}'),
                  controller: controller,
                  keyboardType: TextInputType.number,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  decoration: InputDecoration(
                    labelText: 'الواصل',
                    errorText: exceeds ? 'يتجاوز المتبقي' : null,
                  ),
                  onChanged: (String _) => onChanged(),
                ),
              ),
              Expanded(
                child: Text(
                  'بعده: ${after.riyals}',
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

/// ★★ حقل المبلغ الإضافي (الفائض) — `FR-M12-09` · `E-12`.
class _SurplusField extends StatelessWidget {
  const _SurplusField({
    required this.controller,
    required this.onChanged,
    required this.openDebt,
    super.key,
  });

  final TextEditingController controller;
  final VoidCallback onChanged;
  final Money openDebt;

  @override
  Widget build(BuildContext context) {
    final Money surplus = Money.tryParseInput(controller.text) ?? Money.zero;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.digitsOnly,
          ],
          decoration: const InputDecoration(
            labelText: 'مبلغ إضافي (فائض)',
            helperText: 'يُسدَّد تلقائياً من أول ضمار قادم',
          ),
          onChanged: (String _) => onChanged(),
        ),
        // ★★★ **تنبيه `E-12` الصريح** — `FR-M12-10`: ⛔ **تنبيهٌ لا منع.**
        if (!surplus.isZero && !openDebt.isZero) ...<Widget>[
          const SizedBox(height: Spacing.space8),
          Text(
            '⚠️ يوجد ضمارات مفتوحة بقيمة ${openDebt.riyals}. '
            'هل تريد التوزيع التلقائي بدلاً من تسجيل المبلغ كفائض؟',
            style: TypeScale.caption,
          ),
        ],
      ],
    );
  }
}

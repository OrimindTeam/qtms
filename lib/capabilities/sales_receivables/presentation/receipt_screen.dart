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

import '../../../app/top_bar.dart';

import '../../../core/design/design_tokens.dart';
import '../../../core/messages/error_messages.dart';
import '../../../core/ui/async_state_view.dart';
import '../../../core/ui/date_labels.dart';
import '../../../core/ui/live_summary.dart';
import '../../../core/ui/skeleton.dart';
import '../../../core/ui/sticky_action_bar.dart';
import '../../inventory/application/inventory_providers.dart';
import '../../identity_access/application/session_providers.dart';
import '../../master_data/application/master_data_providers.dart';
import '../../oversight/application/messaging_providers.dart';
import '../../oversight/presentation/send_document_sheet.dart';
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
      appBar: QtmsTopBar(screenTitle: 'المقبوضات'),
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
                    // ★ **اسمُ المقوت للإيصال** — ⟵ **من القائمة المقروءة
                    //   أصلاً** ⛔ **بلا قراءةٍ إضافية.**
                    dealerName: dealers
                            .where((DealerCard d) => d.dealerId == dealerId)
                            .map((DealerCard d) => d.name)
                            .firstOrNull ??
                        '',
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
    required this.dealerName,
    required this.sourceFilter,
    required this.sourceIds,
    super.key,
  });

  final String dealerId;

  /// ★ اسمُ المقوت **كما يظهر في الإيصال** — `FR-M20-07` ③.
  final String dealerName;

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

  /// ★★ نتيجةُ آخر نداء — **نصٌّ ودرجةُ شدّة** (`AM-022`).
  ///
  /// ⛔⛔★★★ **وهي [_ReceiptStatus] لا `String`** — ★ **نظيرُ `_DisposalStatus`
  /// و`_StocktakeStatus` حرفاً بحرف** (`design-system.md` §6-ز): ⟵ **فالحكمُ
  /// حقلٌ تُترجمه الشاشةُ ثلاثيةً لونية** ⛔ **لا رمزٌ إيموجي في أول النصّ.**
  _ReceiptStatus? _status;

  /// ★★ آخر سندٍ حُفِظ في هذه الجلسة — **لإرساله أو تصديره** (`FR-M20-04`).
  ///
  /// ⛔⛔★★ **ولا يُبنى قبل الحفظ:** ★ **رقم السند من السحابة** (`naming-conventions.md`
  /// §5) — ⟵ **وإيصالٌ بلا رقمٍ يَعِد المقوتَ بمستندٍ لا وجود له.**
  ///
  /// ⚠️ **ويُمحى عند تغيّر المدخلات** — ★ **فلا يُرسَل إيصالُ سندٍ سابق
  /// بأرقامٍ صارت على الشاشة لغيره.**
  ReceiptMessageData? _lastVoucher;

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

  /// ⛔⛔★★★ **هل يوجد سطرٌ يتجاوز متبقّيه؟** — **الحرس الرباعي ④**
  /// (`design-system.md` §6-ط · `AM-015` ⑥).
  ///
  /// ⚠️⚠️★★★ **والثلاثةُ قبله كانت قائمةً وحدَها:** ★ **`errorText` «يتجاوز
  /// المتبقي» يظهر على الحقل**، ⛔ **وزرُّ الحفظ يقبل الضغطَ رغمَه** ⟹
  /// **فيُرفَض الطلبُ من السحابة بعد رحلةِ شبكة.** ⟵ **وزرٌّ يقبل ما وسمه
  /// خطأً يُعلِّم المستخدمَ أن التحذيرَ زخرفة.**
  ///
  /// ⚠️★★ **والتعطيلُ عرضٌ لا حماية** (`RISK-02`) — ★ **والرفضُ الحقيقيُّ
  /// في السحابة كما هو** (`BR-M12-02`)، ⛔ **ولا يُسقِط هذا شرطاً منها.**
  bool _hasExceedingLine(List<OpenDebtLot> lots) => lots.any(
        (OpenDebtLot lot) => _amountOf(lot.debtLotId) > lot.remaining,
      );

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
      setState(
        () => _status = const _ReceiptStatus(
          message: 'أدخل مبلغاً على ضمارٍ واحد على الأقل.',
          succeeded: false,
        ),
      );
      return;
    }

    setState(() {
      _saving = true;
      _status = null;
    });
    // ★ **يُلتقَط قبل الاستدعاء** — ⟵ **فالمزوّد يُبطَل بعد النجاح**
    //   (`_refreshDerivedReads`) **فتتغيّر قيم `lots` تحت أيدينا.**
    final Money openBefore =
        totalOpenRemaining(lots.map((OpenDebtLot lot) => lot.remaining));
    final Map<String, OpenDebtLot> lotsById = <String, OpenDebtLot>{
      for (final OpenDebtLot lot in lots) lot.debtLotId: lot,
    };
    final Money paidSurplus = _surplusAmount;
    final CalendarDay paidOn = _date ?? today;

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
        Success<String>(:final String value) => _ReceiptStatus(
            message: 'حُفِظ السند $value',
            succeeded: true,
          ),
        Failure<String>(:final AppError error) => _ReceiptStatus(
            message: catalogText(appErrorMessage(error)),
            succeeded: false,
          ),
      };
      if (result case Success<String>(:final String value)) {
        // ★★ **بياناتُ الإيصال تُبنى في طبقة النطاق** — ⛔ **ولا حسابَ هنا**
        //    (`design-system.md` §5.1).
        _lastVoucher = buildReceiptMessageData(
          dealerName: widget.dealerName,
          documentNumber: value,
          paidOn: paidOn,
          settled: <ReceiptSettlementInput>[
            for (final ReceiptLineInput line in lines)
              if (lotsById[line.debtLotId] case final OpenDebtLot lot)
                ReceiptSettlementInput(
                  stockDate: lot.stockDate,
                  remainingBefore: lot.remaining,
                  amount: line.amount,
                ),
          ],
          openRemainingBefore: openBefore,
          surplusAmount: paidSurplus,
        );
        for (final TextEditingController controller in _amounts.values) {
          controller.clear();
        }
        _surplus.clear();
        _usedAutoAllocation = false;
      }
    });
    if (result is Success<String>) _refreshDerivedReads();
  }

  /// ⛔⛔★★★ **إبطالُ المشتقّات بعد كتابةٍ ناجحة — `DEBT-61`.**
  ///
  /// ★★ **ولماذا لا يكفي بثُّ [openDebtLotsProvider] وحدَه وهو `StreamProvider`:**
  /// ★ **بثُّه على مستندات `distributions` الأب** ⛔ **والمتبقي يُقرأ قراءةً
  /// مفردةً من `pricing/current`** (`FirestoreReceiptDirectory._remainingOf`) —
  /// ⟵ **وسندُ القبض لا يمسّ الأب إطلاقاً**: ★ **يكتب `settledAmount`
  /// و`remaining` في المستند الفرعي وحده** (`IQ-027` · `ADR-0011`).
  /// ⟹ ⛔⛔ **فلا حدثَ بثٍّ يقع، ويبقى «المتبقي» على قيمته قبل القبض حتى
  /// إقلاعٍ جديد للتطبيق** — ★ **وهو أخطرُ ما يكون في شاشة تحصيلٍ نقدي:**
  /// ⟵ **يُقرأ ديناً قائماً فيُقبَض مرتين.**
  ///
  /// ⚠️★★ **وهذا علاجُ الكاتب لنفسه** — ⛔ **لا للكتابة الآتية من جهازٍ آخر:**
  /// ★ **تلك تبقى بلا بثٍّ حتى إعادة الدخول** ⟵ **والحدُّ معلَنٌ في `DEBT-61`**
  /// ⛔ **لا مُدَّعىً حلُّه.**
  void _refreshDerivedReads() {
    ref
      ..invalidate(
        openDebtLotsProvider(
          OpenDebtQuery(
            dealerId: widget.dealerId,
            sourceIds: widget.sourceIds,
          ),
        ),
      )
      // ★ **والفائضُ يتغيّر بالسند نفسِه** — `FR-M12-11`.
      ..invalidate(
        availableSurplusProvider(
          SurplusQuery(
            dealerId: widget.dealerId,
            scope: widget.sourceFilter == null
                ? SurplusScope.general
                : SurplusScope.source,
            sourceId: widget.sourceFilter,
          ),
        ),
      );
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
    final bool exceeds = _hasExceedingLine(lots);

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
              // ★★ **الإرسال والتصدير بعد الحفظ وحده** — `FR-M20-04` (`WU-010`).
              //
              // ⛔ **ولا يظهر قبله:** ★ **رقم السند من السحابة**، ⟵ **وإيصالٌ
              //    بلا رقمٍ يَعِد المقوتَ بمستندٍ لا وجود له.**
              if (_lastVoucher case final ReceiptMessageData voucher) ...<Widget>[
                const SizedBox(height: Spacing.space16),
                _ReceiptSendActions(
                  voucher: voucher,
                  dealerId: widget.dealerId,
                  // ★ **مصدرُ القيد للتسجيل** — ★ **وسندُ «الكل» يُنسَب إلى
                  //   `all`** كما يفعل كاتبُ القيد نفسُه (`api-overview.md`
                  //   §3.1-ح)، ⟵ **فلا يُنسَب لمصدرٍ دون البقية.**
                  sourceId: widget.sourceFilter ?? auditAllSourcesId,
                ),
              ],
            ],
          ),
        ),
        QtmsStickyActionBar(
          summary: QtmsLiveSummary(
            headline: 'إجمالي المقبوض: ${formatRiyals(total)} ريال',
            details: <String>[
              'على الضمارات: ${formatRiyals(total - _surplusAmount)} ريال',
              'فائض: ${formatRiyals(_surplusAmount)} ريال',
              // ★★ **الحرس الرباعي ③** — ⟵ **فالخرقُ مرئيٌّ ولو كان الحقلُ
              //   خارجَ الشاشة بعد التمرير** (`design-system.md` §6-ط).
              if (exceeds) 'سطرٌ يتجاوز متبقّي ضماره — يلزم تصحيحُه قبل الحفظ',
            ],
            emphasis: 'الديون المفتوحة: ${formatRiyals(totalDebt)} ريال',
          ),
          // ★★★ **لافتةُ الحالة بثلاثيةٍ كاملة** — `AM-022`
          //    (`design-system.md` §6-ز): ★ **تعبئةٌ وحدٌّ ولونُ مقدّمةٍ
          //    وأيقونةٌ متجهية** ⛔ **لا نصٌّ عارٍ برمزٍ إيموجي.**
          status: switch ((_status, exceeds)) {
            (_ReceiptStatus(succeeded: true, :final String message), _) =>
              QtmsActionStatus.success(message),
            (_ReceiptStatus(:final String message), _) =>
              QtmsActionStatus.rejection(message),
            (null, true) => QtmsActionStatus.rejection(
                'سطرٌ يتجاوز متبقّي ضماره — صحّحه ليُفتَح الحفظ.',
              ),
            (null, false) => null,
          },
          primary: FilledButton(
            key: const Key('receipt-save'),
            // ⛔⛔★★★ **الحرس الرباعي ④ — تعطيلٌ فعلي** (`AM-015` ⑥).
            onPressed: _saving || exceeds ? null : () => _save(lots, today),
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
                'إجمالي الديون على المقوت: ${formatRiyals(totalDebt)} ريال '
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
class _LotRow extends ConsumerWidget {
  const _LotRow({
    required this.lot,
    required this.controller,
    required this.onChanged,
  });

  final OpenDebtLot lot;
  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            //
            // ⛔⛔★★★ **والمصدرُ باسمه لا بمعرّفه** — `AM-022`
            //    (`ui-guidelines.md` §6): ⟵ **وكان «مصدر SRC-001» نصّاً
            //    تقنياً لا يعرفه موظّفُ الاستلام**، ★ **والمزوّد يقع على
            //    المعرّف عند غياب السجل** ⛔ **فلا سطرَ يفرغ.**
            'ضمار ${dayLabel(lot.stockDate)} — '
            'مصدر ${ref.watch(sourceDisplayNameProvider(lot.sourceId))}',
            style: TypeScale.bodyMd,
          ),
          const SizedBox(height: Spacing.space4),
          Row(
            children: <Widget>[
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
                    // ★★ **الحرس الرباعي ①** — **الحدُّ على الحقل نفسِه**
                    //   (`design-system.md` §6-ط · `AM-015` ⑥): ⟵ **فمن
                    //   يتجاوزه يعرف أنه يتجاوزه قبل أن يفعل.**
                    //
                    // ⛔⛔ **ونصٌّ قصيرٌ عمداً** — ★ **الحقل ثلثُ عرضِ الصفّ**،
                    //   ⟵ **والطويلُ يُقصّ فيقرأ المستخدم نصفَ السبب**
                    //   (عطلُ `Pixel_6_API_36` · 2026-09-01).
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
            '⚠️ يوجد ضمارات مفتوحة بقيمة ${formatRiyals(openDebt)}. '
            'هل تريد التوزيع التلقائي بدلاً من تسجيل المبلغ كفائض؟',
            style: TypeScale.caption,
          ),
        ],
      ],
    );
  }
}

/// ★★★ صفُّ إرسال سند القبض وتصديره — `M20` (`WU-010`).
///
/// ⛔⛔★★ **ولا يحسب شيئاً** — ★ **[ReceiptMessageData] مبنيّةٌ في طبقة
/// النطاق** (`buildReceiptMessageData`)، ⟵ **فالرسالةُ والملفُّ يخرجان من
/// مصدرٍ واحد** ⛔ **ولا يفترقان رقماً واحداً.**
class _ReceiptSendActions extends ConsumerWidget {
  const _ReceiptSendActions({
    required this.voucher,
    required this.dealerId,
    required this.sourceId,
  });

  final ReceiptMessageData voucher;
  final String dealerId;
  final String sourceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool canSend =
        ref.watch(hasPermissionProvider(Permission.messagingSend));
    final bool canExport =
        ref.watch(hasPermissionProvider(Permission.documentExport));
    // ★ **«الصلاحيات تُخفي لا تُعطِّل»** — `ui-guidelines.md` §2.
    if (!canSend && !canExport) return const SizedBox.shrink();

    final MessageBusiness business = ref.watch(messageBusinessProvider);
    final String sourceName = ref.watch(sourceDisplayNameProvider(sourceId));
    final String phone = ref
            .watch(dealersProvider)
            .value
            ?.where((DealerCard dealer) => dealer.dealerId == dealerId)
            .map((DealerCard dealer) => dealer.phone)
            .firstOrNull ??
        '';

    return OutlinedButton.icon(
      key: const Key('receipt-send'),
      onPressed: () => showQtmsSendSheet(
        context,
        document: SendableDocument(
          title: 'إرسال سند القبض',
          // ★ **قالبٌ واحد للسندات** — ⟵ **فلا يُعرَض اختيارٌ من واحد.**
          offersTemplateChoice: false,
          pricedTemplateAvailable: false,
          phone: phone,
          renderMessage: (MessageTemplate _) =>
              renderReceiptMessage(business: business, data: voucher),
          // ⛔ **ولا نسخةَ مختصرة للسند** — ★ **`FR-M20-13` يذكرها للتوزيع**
          //    (**«الإجمالي والرصيد»**)، ⛔ **والإيصالُ سطورُه هي مضمونه.**
          renderShortMessage: null,
          buildExport: (MessageTemplate _) => buildReceiptExport(
            business: business,
            data: voucher,
            sourceId: sourceId,
            sourceName: sourceName,
          ),
        ),
      ),
      icon: const Icon(Icons.send_outlined),
      label: const Text('إرسال أو تصدير'),
    );
  }
}

/// ★★ نتيجةُ نداءٍ في شاشة المقبوضات — **نصٌّ وحكم** (`AM-022`).
class _ReceiptStatus {
  const _ReceiptStatus({required this.message, required this.succeeded});

  /// النصّ — ★ **من الكتالوج عند الفشل** ⛔ **ولا صياغةَ خطأٍ هنا.**
  final String message;

  /// ★ هل نجح النداء؟ — ⛔ **ولا حالةَ ثالثة: الغيابُ `null` في الحقل نفسِه.**
  final bool succeeded;
}

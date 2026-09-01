/// شاشة **السحبيات والخرجيات** (`M22`) — **ما يخرج خارج دورة البيع**.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **سجلّان منفصلان في شاشةٍ واحدة** — `FR-M22` §1 نصّاً:
/// ★ **والفصلُ في الصلاحية والتصنيف والإجماليات** ⛔ **لا في الشاشة**
/// (`outflow-design.md` §2). ⟵ **ومبدِّلُ السجل أعلى النموذج يُعيد بناءه
/// بحالةٍ نظيفة** — ★ **فلا تبقى فئةُ سجلٍّ ولا بنودُه في سجلٍّ آخر.**
///
/// ⛔⛔★★★ **وسحبياتُ المالك بياناتٌ حسّاسة** (`GR-43` · `E-29`) — ★ **ومن
/// لا يملك `withdrawalCreate` لا يرى تبويبَها أصلاً**: ⟵ **وشاشةٌ تُفتَح
/// بسجلٍّ لا يملكه المستخدم كانت تعرض عليه ما لا يُسمح له بقراءته.**
///
/// ⛔⛔★★★ **والمصدر إلزاميٌّ قبل أي بند** (`GR-42` · `E-28`) — ★ **حتى
/// لسحبيات المالك الشخصية**: ⟵ **وزرُّ الحفظ لا يُفعَّل قبل اختياره**،
/// ⛔ **والسحابةُ ترفض بـ`ERR_OUT_001` على كل حال.**
///
/// ⛔⛔★★★ **ولا حقلَ مقوتٍ في هذه الشاشة إطلاقاً** (`FR-M22-04` · `GR-44`) —
/// ★ **غيابٌ بنيويٌّ**: ⟵ **فالسحبيةُ والخرجيةُ لا تمسّان ذمّةَ أحد**،
/// ⛔ **وحقلٌ واحدٌ هنا كان يفتح بابَ أخطرِ خطأٍ متوقَّع في الوحدة**
/// (`outflow-design.md` §10).
/// ═══════════════════════════════════════════════════════════════════════
///
/// ★★★ **والسعر اختياريٌّ في بند القات** (`FR-M22-07` · `E-27`) — ⛔ **بخلاف
/// البيع النقدي**: ⟵ **والحقلُ يُعطَّل لمن لا يملك مفتاح التسعير الآن**
/// (`FR-M22-08`)، ★ **والبندُ يدخل مركزَ الإدخالات المعلّقة** ⛔ **ولا
/// يمنع الحفظ.**
///
/// ⚠️⚠️ **وكل ما هنا عرضٌ لا حماية** — ★ **والرفض الحقيقي في السحابة**
/// (`ADR-0013` القاعدة 3 · `RISK-02`): `outflows` **مغلقة للكتابة**،
/// **والصلاحيةُ والنطاقُ والتاريخُ والرصيدُ كلُّها في `planOutflow`.**
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
import '../../../core/ui/item_line_editor.dart';
import '../../../core/ui/live_summary.dart';
import '../../../core/ui/sticky_action_bar.dart';
import '../../identity_access/application/session_providers.dart';
import '../../inventory/application/inventory_providers.dart';
import '../../inventory/presentation/inventory_widgets.dart'
    show itemOptionLabel, unitName;
import '../../master_data/application/master_data_providers.dart';
import '../application/outflow_providers.dart';

/// شاشة السحبيات والخرجيات.
class OutflowScreen extends ConsumerStatefulWidget {
  /// ينشئ الشاشة.
  const OutflowScreen({super.key});

  @override
  ConsumerState<OutflowScreen> createState() => _OutflowScreenState();
}

class _OutflowScreenState extends ConsumerState<OutflowScreen> {
  OutflowLedgerType? _ledgerType;
  String? _sourceId;

  /// ★★ السجلّات التي يملك المستخدم مفتاحَ إنشائها — `GR-43`.
  ///
  /// ⚠️ **وهذا إخفاءٌ لا حماية** (`RISK-02`) — ★ **والحارس في `outflowGate`.**
  List<OutflowLedgerType> _allowed(WidgetRef ref) => <OutflowLedgerType>[
        if (ref.watch(hasPermissionProvider(Permission.withdrawalCreate)))
          OutflowLedgerType.withdrawal,
        if (ref.watch(hasPermissionProvider(Permission.expenseCreate)))
          OutflowLedgerType.expense,
      ];

  @override
  Widget build(BuildContext context) {
    final List<SourceCard> sources = ref.watch(activeSourcesProvider);
    final List<OutflowLedgerType> allowed = _allowed(ref);
    // ★ **والسجلُّ الأول المسموح افتراضاً** — ⛔ **ولا يُفتَح على سجلٍّ
    //   لا يملكه المستخدم** (`GR-43`).
    final OutflowLedgerType? ledgerType =
        _ledgerType ?? (allowed.isEmpty ? null : allowed.first);

    return Scaffold(
      appBar: const QtmsTopBar(screenTitle: 'السحبيات والخرجيات'),
      body: ledgerType == null
          ? const QtmsEmptyState(
              spec: EmptyStateSpec(
                icon: Icons.lock_outline,
                title: 'لا صلاحية',
                message: 'ليست لديك صلاحية إضافة سحبية ولا خرجية — راجع '
                    'مالك النظام.',
              ),
            )
          : Column(
              children: <Widget>[
                _OutflowHeader(
                  allowed: allowed,
                  ledgerType: ledgerType,
                  sources: sources,
                  sourceId: _sourceId,
                  onLedger: (OutflowLedgerType value) =>
                      setState(() => _ledgerType = value),
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
                            message: 'المصدر إلزامي في كل سحبية وخرجية — '
                                'حتى سحبيات المالك الشخصية.',
                          ),
                        )
                      : _OutflowForm(
                          // ★ **مفتاحٌ مركّب** — ⟵ **فتبديلُ السجل أو المصدر
                          //   يُعيد بناء النموذج بحالةٍ نظيفة**،
                          //   ⛔ **ولا تبقى فئةُ سجلٍّ في سجلٍّ آخر.**
                          key: ValueKey<String>(
                            '${ledgerType.name}_$_sourceId',
                          ),
                          ledgerType: ledgerType,
                          sourceId: _sourceId!,
                        ),
                ),
              ],
            ),
    );
  }
}

/// رأس الشاشة — **السجل والمصدر** (`FR-M22-01` · `FR-M22-02`).
class _OutflowHeader extends StatelessWidget {
  const _OutflowHeader({
    required this.allowed,
    required this.ledgerType,
    required this.sources,
    required this.sourceId,
    required this.onLedger,
    required this.onSource,
  });

  final List<OutflowLedgerType> allowed;
  final OutflowLedgerType ledgerType;
  final List<SourceCard> sources;
  final String? sourceId;
  final ValueChanged<OutflowLedgerType> onLedger;
  final ValueChanged<String?> onSource;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: Spacing.screenPadding,
          vertical: Spacing.space8,
        ),
        child: Column(
          children: <Widget>[
            // ⛔⛔★★★ **ولا يُعرَض سجلٌّ لا يملك المستخدم مفتاحَه** — `GR-43`:
            //    ⟵ **فمن يملك الخرجيات وحدها لا يرى كلمة «سحبية» أصلاً.**
            DropdownButtonFormField<OutflowLedgerType>(
              key: const Key('outflow-ledger-type'),
              initialValue: ledgerType,
              decoration: const InputDecoration(labelText: 'السجل'),
              items: <DropdownMenuItem<OutflowLedgerType>>[
                for (final OutflowLedgerType type in allowed)
                  DropdownMenuItem<OutflowLedgerType>(
                    value: type,
                    child: Text(
                      type == OutflowLedgerType.withdrawal
                          ? 'سحبية'
                          : 'خرجية',
                    ),
                  ),
              ],
              onChanged: (OutflowLedgerType? value) {
                if (value != null) onLedger(value);
              },
            ),
            const SizedBox(height: Spacing.space8),
            // ⛔⛔★★★ **ولا «كل المصادر» هنا** (`GR-42` · `E-28`) — ★ **المصدر
            //    مفردٌ إلزامي**: ⟵ **والسندُ يُقيَّد على حساب مصدرٍ واحد.**
            DropdownButtonFormField<String>(
              key: const Key('outflow-source'),
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
          ],
        ),
      );
}

/// نموذج السند — ★ **حالةٌ محلية حتى الحفظ**.
class _OutflowForm extends ConsumerStatefulWidget {
  const _OutflowForm({
    required this.ledgerType,
    required this.sourceId,
    super.key,
  });

  final OutflowLedgerType ledgerType;
  final String sourceId;

  @override
  ConsumerState<_OutflowForm> createState() => _OutflowFormState();
}

class _OutflowFormState extends ConsumerState<_OutflowForm> {
  final List<_QatDraft> _qat = <_QatDraft>[];
  final List<_CashDraft> _cash = <_CashDraft>[];
  final TextEditingController _notes = TextEditingController();

  OutflowCategory? _category;
  CalendarDay? _date;
  bool _saving = false;
  String? _status;

  @override
  void dispose() {
    for (final _QatDraft draft in _qat) {
      draft.dispose();
    }
    for (final _CashDraft draft in _cash) {
      draft.dispose();
    }
    _notes.dispose();
    super.dispose();
  }

  OutflowCategory get _selectedCategory =>
      _category ?? OutflowCategory.of(widget.ledgerType).first;

  /// ★★ **مفتاحُ تسعير القات الآن** — يتبع السجل (`FR-M22-08` · `GR-43`).
  bool get _canPriceNow => ref.watch(
        hasPermissionProvider(
          widget.ledgerType == OutflowLedgerType.withdrawal
              ? Permission.withdrawalQatPriceNow
              : Permission.expenseQatPriceNow,
        ),
      );

  Money _qatTotal() {
    Money total = Money.zero;
    for (final _QatDraft draft in _qat) {
      if (draft.lineValue(_itemsById()) case final Money value) {
        total = total + value;
      }
    }
    return total;
  }

  Money _cashTotal() {
    Money total = Money.zero;
    for (final _CashDraft draft in _cash) {
      total = total + draft.amount;
    }
    return total;
  }

  int _unpricedCount() {
    int count = 0;
    for (final _QatDraft draft in _qat) {
      if (draft.itemId != null && draft.unitPrice == null) count++;
    }
    return count;
  }

  Map<String, ItemCard> _itemsById() => <String, ItemCard>{
        for (final ItemCard item
            in ref.read(outflowItemsProvider(widget.sourceId)))
          item.itemId: item,
      };

  Future<void> _save(CalendarDay today) async {
    final Map<String, ItemCard> items = _itemsById();
    final List<OutflowQatLineInput> qatLines = <OutflowQatLineInput>[
      for (final _QatDraft draft in _qat)
        if (draft.toInput(items) case final OutflowQatLineInput line) line,
    ];
    final List<OutflowCashLineInput> cashLines = <OutflowCashLineInput>[
      for (final _CashDraft draft in _cash)
        if (!draft.amount.isZero) draft.toInput(),
    ];

    if (qatLines.isEmpty && cashLines.isEmpty) {
      setState(() => _status = '❌ أضف بنداً واحداً على الأقل — قاتاً أو مبلغاً.');
      return;
    }

    setState(() {
      _saving = true;
      _status = null;
    });

    final Outcome<String> result =
        await ref.read(outflowAdminProvider).createOutflow(
              ledgerType: widget.ledgerType,
              sourceId: widget.sourceId,
              category: _selectedCategory,
              date: _date ?? today,
              qatLines: qatLines,
              cashLines: cashLines,
              notes: _notes.text,
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
        for (final _QatDraft draft in _qat) {
          draft.dispose();
        }
        for (final _CashDraft draft in _cash) {
          draft.dispose();
        }
        _qat.clear();
        _cash.clear();
        _notes.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final CalendarDay today = ref.watch(todayProvider);
    final List<ItemCard> items =
        ref.watch(outflowItemsProvider(widget.sourceId));
    final Map<String, ItemCard> itemsById = <String, ItemCard>{
      for (final ItemCard item in items) item.itemId: item,
    };
    // ⛔⛔★★★ **والمتبقّي جزءٌ من نصّ الخيار** — `AM-009` ⑥: ⟵ **فمن يسحب
    //    قاتاً يرى كم بقي منه *في لحظة الاختيار*** ⛔ **لا بعد أن يكتب كميةً
    //    تُرفَض بـ`ERR_STOCK_001`.** ★ **ورُصد غيابُه على المحاكي**
    //    (`WU-014` · 2026-09-01) ⛔ **لا في مراجعةٍ نصّية.**
    final Map<String, StockQuantity> remaining = ref.watch(
      remainingStockProvider(
        StockQuery(sourceId: widget.sourceId, stockDate: today),
      ),
    );
    final Money qatTotal = _qatTotal();
    final Money cashTotal = _cashTotal();
    final Money grandTotal =
        outflowGrandTotal(totalQatValue: qatTotal, totalCashValue: cashTotal);
    final int unpriced = _unpricedCount();

    final List<QtmsItemOption> options = <QtmsItemOption>[
      for (final ItemCard item in items)
        QtmsItemOption(
          id: item.itemId,
          label: itemOptionLabel(item.name, remaining[item.itemId]),
        ),
    ];

    return Column(
      children: <Widget>[
        Expanded(
          child: ListView(
            padding: const EdgeInsetsDirectional.all(Spacing.screenPadding),
            children: <Widget>[
              _CategoryField(
                ledgerType: widget.ledgerType,
                value: _selectedCategory,
                onChanged: (OutflowCategory value) =>
                    setState(() => _category = value),
              ),
              const SizedBox(height: Spacing.space12),
              _DateRow(
                date: _date ?? today,
                today: today,
                onChanged: (CalendarDay day) => setState(() => _date = day),
              ),
              const SizedBox(height: Spacing.space16),
              Text('بنود القات', style: TypeScale.titleSm),
              const SizedBox(height: Spacing.space8),
              if (_qat.isEmpty)
                Text(
                  'لا بند قاتٍ بعد — أضف بنداً إن كان الخارج بضاعة.',
                  style: TypeScale.caption,
                )
              else
                for (final _QatDraft draft in _qat)
                  QtmsItemLineRow(
                    key: ValueKey<_QatDraft>(draft),
                    options: optionsForRow(
                      all: options,
                      takenIds: <String?>[
                        for (final _QatDraft other in _qat) other.itemId,
                      ],
                      ownId: draft.itemId,
                    ),
                    selectedId: draft.itemId,
                    onSelected: (String id) =>
                        setState(() => draft.itemId = id),
                    onRemove: () => setState(() {
                      _qat.remove(draft);
                      draft.dispose();
                    }),
                    fields: <Widget>[
                      TextField(
                        key: Key('outflow-qty-${_qat.indexOf(draft)}'),
                        controller: draft.quantity,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'الكمية',
                          suffixText: draft.itemId == null
                              ? null
                              : unitNameOrNull(itemsById[draft.itemId]?.unit),
                        ),
                        onChanged: (String _) => setState(() {}),
                      ),
                      TextField(
                        key: Key('outflow-price-${_qat.indexOf(draft)}'),
                        controller: draft.price,
                        // ⛔⛔★★★ **والحقلُ يُعطَّل بلا مفتاحه** — `FR-M22-08`:
                        //    ★ **ولا يمنع الحفظ** (`FR-M22-07`)،
                        //    ⟵ **والبندُ يدخل مركزَ الإدخالات المعلّقة.**
                        enabled: _canPriceNow,
                        keyboardType: TextInputType.number,
                        inputFormatters: <TextInputFormatter>[
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: InputDecoration(
                          labelText: 'سعر الوحدة',
                          helperText: _canPriceNow
                              ? 'اختياري — يُسعَّر لاحقاً إن تُرك'
                              : 'ليست لديك صلاحية التسعير الآن — سيُسعَّر لاحقاً',
                        ),
                        onChanged: (String _) => setState(() {}),
                      ),
                    ],
                  ),
              QtmsAddLineButton(
                key: const Key('outflow-add-qat'),
                onPressed: () => setState(() => _qat.add(_QatDraft())),
              ),
              const SizedBox(height: Spacing.space16),
              Text('بنود المبالغ', style: TypeScale.titleSm),
              const SizedBox(height: Spacing.space8),
              for (final _CashDraft draft in _cash)
                _CashRow(
                  key: ValueKey<_CashDraft>(draft),
                  draft: draft,
                  index: _cash.indexOf(draft),
                  onChanged: () => setState(() {}),
                  onRemove: () => setState(() {
                    _cash.remove(draft);
                    draft.dispose();
                  }),
                ),
              QtmsAddLineButton(
                key: const Key('outflow-add-cash'),
                // ★ **«إضافة بند» لا «إضافة نوع»** — ⟵ **فالبندُ النقدي ليس
                //   نوعاً من المخزن** (`ui-guidelines.md` §6: **بلا مصطلحٍ
                //   يُخالف ما يفعله المستخدم**): ⛔ **ورُصد على المحاكي.**
                label: 'إضافة بند',
                onPressed: () => setState(() => _cash.add(_CashDraft())),
              ),
              const SizedBox(height: Spacing.space16),
              TextField(
                key: const Key('outflow-notes'),
                controller: _notes,
                decoration: const InputDecoration(labelText: 'البيان'),
              ),
              // ⏳★★ **وتنبيهٌ صريح عند بندٍ بلا سعر** — `FR-M22-07` · `E-27`.
              if (unpriced > 0) ...<Widget>[
                const SizedBox(height: Spacing.space12),
                Text(
                  '⏳ $unpriced من بنود القات بلا سعر — تُحفَظ ويخرج القات، '
                  'وتدخل مركز الإدخالات المعلّقة حتى تُسعَّر.',
                  style: TypeScale.bodyMd,
                ),
              ],
            ],
          ),
        ),
        QtmsStickyActionBar(
          summary: QtmsLiveSummary(
            // ★★★ **الإجمالي النهائي** — `GR-42` · `AT-38`.
            headline: 'الإجمالي النهائي: ${grandTotal.riyals} ريال',
            details: <String>[
              'قيمة القات: ${qatTotal.riyals}',
              'المبالغ: ${cashTotal.riyals}',
              // ⛔⛔★★★ **وتذكيرٌ صريح أنه لا يمسّ ذمّةَ أحد** — `GR-44`.
              'لا يمسّ حسابات المقاوته',
            ],
            emphasis: unpriced > 0 ? 'بنود بلا سعر: $unpriced' : null,
          ),
          status: _status == null
              ? null
              : Text(_status!, style: TypeScale.bodyMd),
          primary: FilledButton(
            key: const Key('outflow-save'),
            onPressed: _saving ? null : () => _save(today),
            child: Text(
              _saving
                  ? 'جارٍ الحفظ…'
                  : widget.ledgerType == OutflowLedgerType.withdrawal
                      ? 'حفظ السحبية'
                      : 'حفظ الخرجية',
            ),
          ),
        ),
      ],
    );
  }
}

/// ★ حقلُ الفئة — **من فئات سجلِّها وحدها** (`FR-M22-19`).
class _CategoryField extends StatelessWidget {
  const _CategoryField({
    required this.ledgerType,
    required this.value,
    required this.onChanged,
  });

  final OutflowLedgerType ledgerType;
  final OutflowCategory value;
  final ValueChanged<OutflowCategory> onChanged;

  @override
  Widget build(BuildContext context) =>
      DropdownButtonFormField<OutflowCategory>(
        key: const Key('outflow-category'),
        initialValue: value,
        decoration: const InputDecoration(labelText: 'الفئة'),
        items: <DropdownMenuItem<OutflowCategory>>[
          // ★★ **والقائمةُ من طبقة النطاق** ([OutflowCategory.of]) —
          //   ⛔ **ولا تصفيةٌ مكتوبةٌ في شاشة** (`ADR-0009`).
          for (final OutflowCategory category in OutflowCategory.of(ledgerType))
            DropdownMenuItem<OutflowCategory>(
              value: category,
              child: Text(category.label),
            ),
        ],
        onChanged: (OutflowCategory? selected) {
          if (selected != null) onChanged(selected);
        },
      );
}

/// ★★ صفّ التاريخ — `FR-M22-09`: ⛔ **ولا يقبل مستقبلياً أبداً**.
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
            key: const Key('outflow-date'),
            onPressed: () async {
              final DateTime? picked = await showDatePicker(
                context: context,
                initialDate: date.asUtcMidnight(),
                firstDate: DateTime.utc(today.year - 1),
                // ⛔⛔★★★ **والحدُّ الأعلى اليوم** — `FR-M22-09`:
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

/// صفّ بندِ مبلغ — **مبلغ** أو **أخرى** (`FR-M22-05`).
class _CashRow extends StatelessWidget {
  const _CashRow({
    required this.draft,
    required this.index,
    required this.onChanged,
    required this.onRemove,
    super.key,
  });

  final _CashDraft draft;
  final int index;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.only(bottom: Spacing.space12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: DropdownButtonFormField<OutflowLineKind>(
                key: Key('outflow-cash-kind-$index'),
                initialValue: draft.kind,
                decoration: const InputDecoration(labelText: 'النوع'),
                items: const <DropdownMenuItem<OutflowLineKind>>[
                  DropdownMenuItem<OutflowLineKind>(
                    value: OutflowLineKind.amount,
                    child: Text('مبلغ'),
                  ),
                  DropdownMenuItem<OutflowLineKind>(
                    value: OutflowLineKind.other,
                    child: Text('أخرى'),
                  ),
                ],
                onChanged: (OutflowLineKind? value) {
                  if (value != null) {
                    draft.kind = value;
                    onChanged();
                  }
                },
              ),
            ),
            const SizedBox(width: Spacing.space8),
            Expanded(
              child: TextField(
                key: Key('outflow-cash-amount-$index'),
                controller: draft.amountText,
                keyboardType: TextInputType.number,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: const InputDecoration(labelText: 'المبلغ'),
                onChanged: (String _) => onChanged(),
              ),
            ),
            const SizedBox(width: Spacing.space8),
            Expanded(
              child: TextField(
                key: Key('outflow-cash-desc-$index'),
                controller: draft.description,
                decoration: InputDecoration(
                  labelText: 'الوصف',
                  // ★ **وإلزاميٌّ لـ«أخرى» وحدها** — `FR-M22-05` ③.
                  errorText: draft.kind == OutflowLineKind.other &&
                          draft.description.text.trim().isEmpty
                      ? 'مطلوب لبند «أخرى»'
                      : null,
                ),
                onChanged: (String _) => onChanged(),
              ),
            ),
            IconButton(
              onPressed: onRemove,
              icon: const Icon(Icons.remove_circle_outline),
              tooltip: 'حذف البند',
              color: SemanticTriads.danger.ink,
              constraints: const BoxConstraints(
                minWidth: Sizes.minTouch,
                minHeight: Sizes.minTouch,
              ),
            ),
          ],
        ),
      );
}

// ═════════════════════════════════════════════════════════════════════════
// مسوّدات السطور — ★ **حالةٌ محلية حتى الحفظ** (`ADR-0003`: ⛔ لا مسوّدة
// محفوظة محلياً)
// ═════════════════════════════════════════════════════════════════════════

final class _QatDraft {
  final TextEditingController quantity = TextEditingController();
  final TextEditingController price = TextEditingController();
  String? itemId;

  Money? get unitPrice => Money.tryParseInput(price.text);

  Money? lineValue(Map<String, ItemCard> items) {
    final OutflowQatLineInput? line = toInput(items);
    if (line == null) return null;
    // ★★ **والمعادلة من طبقة النطاق** — ⛔ **ولا نسخة ثانية** (`ADR-0009`).
    return outflowQatLineValue(
      quantity: line.quantity,
      unitPrice: line.unitPrice,
    );
  }

  OutflowQatLineInput? toInput(Map<String, ItemCard> items) {
    final String? id = itemId;
    if (id == null) return null;
    final ItemCard? item = items[id];
    if (item == null) return null;
    final num? raw = num.tryParse(quantity.text.trim());
    if (raw == null || raw <= 0) return null;
    final StockQuantity value = switch (item.unit) {
      ItemUnit.piece => PieceQuantity(PieceCount(raw.toInt())),
      ItemUnit.kilogram => WeightQuantity(WeightKg(raw.toDouble())),
    };
    return OutflowQatLineInput(
      itemId: id,
      itemName: item.name,
      unit: item.unit,
      quantity: value,
      unitPrice: unitPrice,
    );
  }

  void dispose() {
    quantity.dispose();
    price.dispose();
  }
}

final class _CashDraft {
  final TextEditingController amountText = TextEditingController();
  final TextEditingController description = TextEditingController();
  OutflowLineKind kind = OutflowLineKind.amount;

  Money get amount => Money.tryParseInput(amountText.text) ?? Money.zero;

  OutflowCashLineInput toInput() => OutflowCashLineInput(
        kind: kind,
        amount: amount,
        description: description.text,
      );

  void dispose() {
    amountText.dispose();
    description.dispose();
  }
}

/// ★ اسمُ الوحدة أو `null` — ⛔ **ولا نسخةَ ثانية من التسمية**
/// ([unitName] في `inventory_widgets.dart`).
String? unitNameOrNull(ItemUnit? unit) => unit == null ? null : unitName(unit);

/// شاشة **الوارد عدداً** (`M6`) — **نمطا 2 و4** (`ui-guidelines.md` §3).
///
/// ⛔★★ **ولا حقل تاريخ في النموذج إطلاقاً** — `FR-M6-02` · `E-40`: «**تاريخ
/// التوريد هو تاريخ اليوم ولا يمكن تغييره**». ⟵ ★ **وما لا يُعرَض لا يُحاوَل
/// تغييره**، **والشريط المقفل يُخبر المستخدم لماذا.**
///
/// ⛔★★ **ولا وزن ولا ضريبة ولا سعر** — `FR-M6-10`: **عملية كمية بحتة**.
///
/// ★★ **والرعوي يظهر ويصير إلزامياً فقط إن اشترطه المصدر** (`FR-M6-03`) —
/// ⛔ **وإلا لا يُعرَض ولا يُخزَّن أصلاً**.
///
/// ★★★ **و`AM-009` غيّر ثلاثة أشياء هنا** (2026-08-31):
/// ③ ★★ **مرشِّحُ المصدر يحمل «كل المصادر»** — ⟵ **فالقائمةُ تعرض يومَ
///    المستخدم كلَّه**، ⛔ **ولا يُجبَر على اختيار مصدرٍ ليرى شيئاً.**
/// ⑤ ★★ **والمصدرُ صار حقلاً في النموذج** — ⟵ **فالإضافةُ لا تعتمد على
///    مرشِّح الشاشة**، ⛔ **ولا يُكتَب مستندٌ على مصدرٍ اختاره مرشِّحُ عرض.**
/// ④ ⛔⛔★★★ **والأنواعُ صفٌّ واحدٌ يُنشأ بالطلب** — ★ **كانت *كلُّ* أنواع
///    المصدر تُعرَض صفوفَ إدخالٍ دفعةً واحدة**: ⟵ **فبأربعين نوعاً يمرّ
///    المستخدم أربعين صفّاً ليملأ ثلاثة** ([QtmsItemLineRow]).
///
/// ⚠️⚠️ **وكل بوابة صلاحية هنا إخفاءٌ لا حماية** — ★ **والرفض في السحابة**
/// (`ADR-0013` القاعدة 3 · `RISK-02`).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qtms_domain/qtms_domain.dart';

import '../../../app/top_bar.dart';

import '../../../core/design/design_tokens.dart';
import '../../../core/messages/error_messages.dart';
import '../../../core/ui/async_state_view.dart';
import '../../../core/ui/context_header.dart';
import '../../../core/ui/destructive_sheet.dart';
import '../../../core/ui/inline_banner.dart';
import '../../../core/ui/item_line_editor.dart';
import '../../identity_access/presentation/permission_gate.dart';
import '../../master_data/application/master_data_providers.dart';
import '../../oversight/presentation/audit_trail_view.dart';
import '../application/inventory_providers.dart';
import 'inventory_widgets.dart';
import '../../../core/ui/optional_reason.dart';

/// قائمة الوارد عدداً لليوم.
class CountedIntakeScreen extends ConsumerWidget {
  /// ينشئ الشاشة.
  const CountedIntakeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CalendarDay today = ref.watch(todayProvider);
    // ★★ **مرشِّحُ عرضٍ لا سياقُ عملية** — `AM-009` ③ (راجع
    //    [sourceListFilterProvider]): ⟵ **و`null` تعني «كل المصادر».**
    final String? filterId = ref.watch(sourceListFilterProvider);
    final List<SourceCard> sources = ref.watch(activeSourcesProvider);

    return Scaffold(
      appBar: QtmsTopBar(screenTitle: 'الوارد عدداً'),
      // ⛔⛔★★ **والزرُّ لا يشترط مرشِّحاً بعد اليوم** — `AM-009` ⑤: ★ **المصدرُ
      //    حقلٌ في النموذج**، ⟵ **فزرُّ الإضافة يعمل و«كل المصادر» معروضة.**
      //    ⛔ **ويبقى محجوباً عمّن لا مصدرَ في نطاقه أصلاً** — ★ **فنموذجٌ
      //    بحقلِ مصدرٍ خاوٍ لا يُنتج شيئاً** (`E-35`).
      floatingActionButton: sources.isEmpty
          ? null
          : PermissionGate(
              permission: Permission.incomingCountWrite,
              child: _NewIntakeButton(sourceId: filterId ?? sources.first.sourceId),
            ),
      body: Column(
        children: <Widget>[
          // ★★★ **رأس السياق الموحّد** — `MASTER.md` §5b نمط `P3` (`ADR-0021`).
          //
          // ⛔⛔ **ويستبدل `SourcePicker` + `LockedDayBanner` معاً** — ★ **صفٌّ
          //    واحد بدل صفّين وفراغٍ بينهما.**
          //
          // ⚠️ **و`LockedDayBanner` باقٍ داخل نموذج الإدخال** — ★ **موضعٌ
          //    آخر بوظيفةٍ أخرى:** ⟵ **إفصاحٌ عن قفل التاريخ لحظة الكتابة**
          //    (`FR-M6-02` · `E-40`)، ⛔ **لا رأسُ سياقٍ للشاشة.**
          QtmsContextHeader(
            sources: sources,
            selectedSourceId: filterId,
            // ★★★ **وخيارُ «كل المصادر» هنا** — `AM-009` ③.
            allowAllSources: true,
            onSourceSelected: (String? id) =>
                ref.read(sourceListFilterProvider.notifier).select(id),
            day: today,
          ),
          Expanded(
            // ⛔⛔★★★ **ولا `SizedBox.shrink` حالةً لغياب المصدر** — §5b نمط
            //    `P3` قاعدةُ الفراغ الصامت (`design-system.md` §هـ).
            //
            // ⚠️★★ **و«اختر مصدراً» سقطت حالةً** — ★ **فالافتراض «الكل»**:
            //    ⟵ **ولم يبقَ إلا نطاقٌ فارغ** (`E-35`).
            child: sources.isEmpty
                ? const QtmsEmptyState(spec: noSourceInScopeEmpty)
                : _IntakeList(
                    sourceId: filterId,
                    day: today,
                    showSource: filterId == null,
                  ),
          ),
        ],
      ),
    );
  }
}

class _NewIntakeButton extends StatelessWidget {
  const _NewIntakeButton({required this.sourceId});

  final String sourceId;

  @override
  Widget build(BuildContext context) => FloatingActionButton.extended(
        onPressed: () => showCountedIntakeForm(context, sourceId: sourceId),
        icon: const Icon(Icons.add_box_outlined),
        label: const Text('وارد جديد'),
      );
}

class _IntakeList extends ConsumerWidget {
  const _IntakeList({
    required this.sourceId,
    required this.day,
    required this.showSource,
  });

  /// المصدر — و`null` تعني **كل المصادر** (`AM-009` ③).
  final String? sourceId;
  final CalendarDay day;

  /// ★ هل يُسمّى المصدر في كل بطاقة؟ — ⛔⛔ **وإلزاميٌّ في وضع «الكل»**:
  /// ⟵ **فصفٌّ بلا مصدرٍ في قائمةٍ تجمع مصادرَ لا يُقرأ** (`A-01`).
  final bool showSource;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<CountedIntakeCard>> intakes = ref.watch(
      countedIntakeListProvider(
        SourceListQuery(sourceId: sourceId, stockDate: day),
      ),
    );

    return InventoryAsyncView<CountedIntakeCard>(
      value: intakes,
      emptyIcon: Icons.add_box_outlined,
      emptyTitle: 'لا وارد اليوم',
      emptyLabel: 'سجّل أول وارد عدداً ليدخل المخزن فوراً باسم مورّده.',
      builder: (List<CountedIntakeCard> list) => ListView.separated(
        padding: const EdgeInsets.all(Spacing.space16),
        itemCount: list.length,
        separatorBuilder: (BuildContext _, int _) =>
            const SizedBox(height: Spacing.space8),
        itemBuilder: (BuildContext context, int index) =>
            _IntakeTile(intake: list[index], showSource: showSource),
      ),
    );
  }
}

class _IntakeTile extends ConsumerWidget {
  const _IntakeTile({required this.intake, this.showSource = false});

  final CountedIntakeCard intake;

  /// ★ يُسمّي المصدر في وضع «كل المصادر» — `AM-009` ③.
  final bool showSource;

  bool get _isCancelled => intake.status == CountedIntakeStatus.cancelled;

  @override
  Widget build(BuildContext context, WidgetRef ref) => InventoryTile(
        title: intake.documentNumber,
        // ★★ **أيقونة 🕘 في أول الصفّ** — `FR-M18-10` · `FR-M18-11`
        //   («**الوارد عدداً**» ضمن الشاشات المشمولة).
        leading: auditTrailLeading(
          ref,
          entityType: countedIntakeEntityType,
          entityId: intake.documentNumber,
          title: intake.documentNumber,
          sourceId: intake.sourceId,
        ),
        // ★★ **واسمُ المصدر في السطر الثاني في وضع «الكل»** — `AM-009` ③:
        //    ⛔⛔ **وصفٌّ بلا مصدرٍ في قائمةٍ تجمع مصادرَ لا يُقرأ** (`A-01`).
        //    ★ **وموضعُه السطرُ الثاني لا العنوان** — ⟵ **فالعنوانُ رقمُ
        //    المستند وهو ما يبحث عنه المستخدم.**
        subtitle: <String>[
          if (showSource) ref.watch(sourceDisplayNameProvider(intake.sourceId)),
          '${intake.lines.length} نوع',
          quantityLabel(PieceQuantity(intake.totalQuantity)),
        ].join(' · '),
        badges: <Widget>[
          if (_isCancelled) const CancelledBadge(),
          if (intake.amendCount > 0) const AmendedBadge(),
        ],
        actions: <Widget>[
          // ⛔★★ **ولا زر حذف إطلاقاً** — `FR-M6-14` · `GR-07`:
          //    «**الحذف مرفوض نهائياً لكل المستخدمين بمن فيهم المالك**».
          if (!_isCancelled)
            PermissionGate(
              permission: Permission.incomingCountAmend,
              child: IconButton(
                onPressed: () => showCountedIntakeForm(
                  context,
                  sourceId: intake.sourceId,
                  existing: intake,
                ),
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'تعديل الوارد',
              ),
            ),
          if (!_isCancelled)
            PermissionGate(
              permission: Permission.incomingCountCancel,
              child: IconButton(
                onPressed: () => showCancelIntakeSheet(context, intake: intake),
                icon: const Icon(Icons.block_outlined),
                tooltip: 'إلغاء الوارد',
              ),
            ),
        ],
      );
}

/// يفتح نموذج الوارد — و[existing] `null` تعني **إنشاءً**.
Future<void> showCountedIntakeForm(
  BuildContext context, {
  required String sourceId,
  CountedIntakeCard? existing,
}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: SemanticColors.surface,
      builder: (BuildContext context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: CountedIntakeFormSheet(sourceId: sourceId, existing: existing),
      ),
    );

/// ورقة نموذج الوارد عدداً.
class CountedIntakeFormSheet extends ConsumerStatefulWidget {
  /// ينشئ الورقة.
  const CountedIntakeFormSheet({
    required this.sourceId,
    this.existing,
    super.key,
  });

  /// المصدر.
  final String sourceId;

  /// المستند المُعدَّل.
  final CountedIntakeCard? existing;

  @override
  ConsumerState<CountedIntakeFormSheet> createState() =>
      _CountedIntakeFormSheetState();
}

class _CountedIntakeFormSheetState
    extends ConsumerState<CountedIntakeFormSheet> {
  final TextEditingController _notes = TextEditingController();
  final TextEditingController _amendReason = TextEditingController();

  /// ★★★ **السطورُ قائمةٌ مرتَّبة لا خريطةُ كتالوج** — `AM-009` ④.
  ///
  /// ⛔⛔★★★ **وكانت `Map<String,int>` مبنيّةً على *كل* أنواع المصدر:**
  /// ⟵ **فالنموذجُ يطول بطول الكتالوج لا بحجم العملية.** ★ **وصارت سطوراً
  /// يُنشئها المستخدم** — ⟵ **وترتيبُها ترتيبُ إدخاله** ⛔ **لا ترتيبُ
  /// الكتالوج.**
  ///
  /// ⛔⛔★★ **و«لا سطران لنفس النوع» بنيويٌّ في [optionsForRow]** —
  /// `FR-M6-07`: ⟵ **فالنوعُ المختار يسقط من خيارات إخوته**، ★ **والفحصُ
  /// في طبقة النطاق باقٍ حارساً ثانياً** (`BR-M6-05`).
  late final List<_IntakeLine> _lines = <_IntakeLine>[
    for (final ValidatedCountedIntakeLine line
        in widget.existing?.lines ?? const <ValidatedCountedIntakeLine>[])
      _IntakeLine(itemId: line.itemId, quantity: '${line.quantity.pieces}'),
  ];

  /// ★★ **المصدرُ حالةٌ في النموذج لا مُدخَلٌ ثابت** — `AM-009` ⑤.
  ///
  /// ⛔ **ولا يُغيَّر في التعديل** — ★ **`sourceUnchanged()` في القاعدة**:
  /// ⟵ **ونقلُ مستندٍ بين مصدرين نقلٌ خارجَ النطاق** (`ADR-0005`).
  late String _sourceId = widget.existing?.sourceId ?? widget.sourceId;

  late String? _supplierId = widget.existing?.supplierId;
  CatalogMessage? _rejection;
  bool _submitting = false;

  bool get _isEdit => widget.existing != null;

  @override
  void dispose() {
    _notes.dispose();
    _amendReason.dispose();
    for (final _IntakeLine line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final CalendarDay today = ref.watch(todayProvider);
    final List<SourceCard> sources = ref.watch(activeSourcesProvider);
    final List<ItemCard> items = ref.watch(intakeItemsProvider(_sourceId));
    final List<SupplierCard> suppliers =
        ref.watch(intakeSuppliersProvider(_sourceId));
    final bool requiresSupplier = _requiresSupplier(ref, _sourceId);
    // ★★ **والمتبقّي يظهر في نصّ الخيار** — `FR-M10-06` · `AM-009` ⑥.
    final Map<String, StockQuantity> remaining = ref.watch(
      remainingStockProvider(
        StockQuery(sourceId: _sourceId, stockDate: today),
      ),
    );
    final List<QtmsItemOption> options = <QtmsItemOption>[
      for (final ItemCard item in items)
        QtmsItemOption(
          id: item.itemId,
          label: itemOptionLabel(item.name, remaining[item.itemId]),
        ),
    ];

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Spacing.space16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              _isEdit ? 'تعديل وارد عدداً' : 'وارد عدداً جديد',
              style: TypeScale.titleLg,
            ),
            const SizedBox(height: Spacing.space12),
            // ⛔★★ **ولا منتقي تاريخ** — راجع ترويسة الملف.
            LockedDayBanner(day: widget.existing?.stockDate ?? today),
            const SizedBox(height: Spacing.space16),
            // ⑤ ★★★ **حقلُ المصدر داخل النموذج** — `AM-009` ⑤.
            //
            // ⛔ **ومقفلٌ في التعديل** — راجع [_sourceId].
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
                    child: Text(source.name, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: _isEdit ? null : _onSourceChanged,
            ),
            const SizedBox(height: Spacing.space16),
            // ★★ **الرعوي مشروطٌ بالمصدر** — `FR-M6-03`.
            if (requiresSupplier) ...<Widget>[
              Text(
                'الرعوي',
                style: TypeScale.label
                    .copyWith(color: SemanticColors.textSecondary),
              ),
              const SizedBox(height: Spacing.space8),
              Wrap(
                spacing: Spacing.space8,
                runSpacing: Spacing.space8,
                children: <Widget>[
                  for (final SupplierCard supplier in suppliers)
                    ChoiceChip(
                      label: Text(supplier.name),
                      selected: supplier.supplierId == _supplierId,
                      onSelected: (bool on) => setState(
                        () => _supplierId = on ? supplier.supplierId : null,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: Spacing.space16),
            ],
            Text(
              'الأنواع',
              style:
                  TypeScale.label.copyWith(color: SemanticColors.textSecondary),
            ),
            const SizedBox(height: Spacing.space8),
            // ④ ★★★ **صفٌّ لكل نوعٍ أدخله المستخدم** — `AM-009` ④.
            for (final (int index, _IntakeLine line) in _lines.indexed)
              QtmsItemLineRow(
                key: ValueKey<int>(line.seed),
                options: optionsForRow(
                  all: options,
                  takenIds: <String?>[
                    for (final _IntakeLine other in _lines) other.itemId,
                  ],
                  ownId: line.itemId,
                ),
                selectedId: line.itemId,
                onSelected: (String id) => setState(() => line.itemId = id),
                onRemove: () => setState(() {
                  _lines.removeAt(index).dispose();
                }),
                fields: <Widget>[
                  TextField(
                    controller: line.quantity,
                    // ★★ **لوحة أرقام بلا كسور** — `BR-M6-06`: ⛔ **والكسر
                    //    مرفوض في النوع نفسه** (`PieceCount.tryParseInput`).
                    keyboardType: const TextInputType.numberWithOptions(),
                    decoration: const InputDecoration(labelText: 'العدد'),
                  ),
                ],
              ),
            if (items.isEmpty)
              Text(
                // `FR-M6-05` — قائمة الأنواع مفلترة بالمصدر حصراً.
                'لا توجد أنواع مرتبطة بهذا المصدر.',
                style: TypeScale.bodyMd
                    .copyWith(color: SemanticColors.textSecondary),
              ),
            if (items.isNotEmpty)
              QtmsAddLineButton(
                onPressed: _lines.length >= items.length
                    ? null
                    : () => setState(() => _lines.add(_IntakeLine())),
              ),
            const SizedBox(height: Spacing.space16),
            TextField(
              controller: _notes,
              decoration: const InputDecoration(labelText: 'ملاحظات (اختياري)'),
            ),
            if (_isEdit) ...<Widget>[
              const SizedBox(height: Spacing.space12),
              TextField(
                controller: _amendReason,
                decoration:
                    const InputDecoration(labelText: 'سبب التعديل (اختياري)'),
              ),
            ],
            if (_rejection case final CatalogMessage message) ...<Widget>[
              const SizedBox(height: Spacing.space12),
              _Rejection(message: message),
            ],
            const SizedBox(height: Spacing.space16),
            FilledButton(
              onPressed: _submitting ? null : () => _submit(requiresSupplier),
              child: Text(_isEdit ? 'حفظ التعديل' : 'اعتماد'),
            ),
          ],
        ),
      ),
    );
  }

  /// ★★★ **وتبديلُ المصدر يُفرِغ السطور والرعوي** — ⛔ **ولا يبقى مُدخَلٌ
  /// يخصّ مصدراً آخر:** ★ **الأنواع والرعية مفلترون بالمصدر** (`FR-M6-05`)،
  /// ⟵ **وسطرٌ لنوعٍ لا ينتمي للمصدر الجديد يُرفَض في السحابة** ⛔ **بعد أن
  /// يكون المستخدم كتبه.**
  void _onSourceChanged(String? id) {
    if (id == null || id == _sourceId) return;
    setState(() {
      _sourceId = id;
      _supplierId = null;
      for (final _IntakeLine line in _lines) {
        line.dispose();
      }
      _lines.clear();
      _rejection = null;
    });
  }

  /// ★ **إلزامية الرعوي من سجل المصدر** — ⛔ **ولا تُخمَّن في الشاشة**.
  static bool _requiresSupplier(WidgetRef ref, String sourceId) {
    for (final SourceCard source in ref.watch(activeSourcesProvider)) {
      if (source.sourceId == sourceId) return source.requiresSupplierOnIntake;
    }
    return false;
  }

  Future<void> _submit(bool requiresSupplier) async {
    final Outcome<ValidatedCountedIntake> validated = validateCountedIntake(
      CountedIntakeInput(
        sourceId: _sourceId,
        sourceRequiresSupplier: requiresSupplier,
        supplierId: requiresSupplier ? _supplierId : null,
        notes: _notes.text,
        lines: <CountedIntakeLineInput>[
          // ⛔ **والصفُّ بلا نوعٍ أو بلا عددٍ ليس سطراً** — ★ **صفٌّ فارغٌ
          //   حالةُ إدخالٍ لا قيمة**: ⟵ **ولا يُرسَل صفر.**
          for (final _IntakeLine line in _lines)
            if (line.toInput() case final CountedIntakeLineInput input) input,
        ],
      ),
    );
    if (validated is Failure<ValidatedCountedIntake>) {
      setState(() => _rejection = _messageOf(validated.error, requiresSupplier));
      return;
    }

    setState(() {
      _submitting = true;
      _rejection = null;
    });

    final InventoryAdminRepository admin = ref.read(inventoryAdminProvider);
    final ValidatedCountedIntake intake =
        (validated as Success<ValidatedCountedIntake>).value;
    final Outcome<void> result = _isEdit
        ? await admin.amendCountedIntake(
            documentNumber: widget.existing!.documentNumber,
            intake: intake,
            amendReason: blankToNull(_amendReason.text),
          )
        : switch (await admin.createCountedIntake(intake)) {
            Failure<String>(:final AppError error) => Failure<void>(error),
            Success<String>() => const Success<void>(null),
          };

    if (!mounted) return;
    switch (result) {
      case Failure<void>(:final AppError error):
        setState(() {
          _submitting = false;
          _rejection = appErrorMessage(error);
        });
      case Success<void>():
        Navigator.of(context).pop();
    }
  }

  /// ★ يترجم رفض طبقة النطاق إلى رسالته — ⛔ **ولا تُصاغ في الشاشة**.
  static CatalogMessage _messageOf(AppError error, bool requiresSupplier) {
    if (error case ValidationError(:final String ruleCode)) {
      return switch (ruleCode) {
        'FR-M6-03' => CatalogMessage.supplierRequiredForSource,
        'BR-M6-05' => CatalogMessage.itemAlreadyInDocument,
        'BR-M6-06' => CatalogMessage.fractionalCount,
        _ => CatalogMessage.operationFailed,
      };
    }
    return appErrorMessage(error);
  }
}

/// ★★ سطرُ إدخالٍ واحد — **نوعٌ مختارٌ وعددٌ مكتوب.**
///
/// ⚠️ **و[seed] مفتاحُ الويدجت الثابت** — ⛔ **ولا يُستعمَل الموضعُ مفتاحاً**:
/// ⟵ **فحذفُ صفٍّ في الوسط كان يُزحزح مفاتيحَ من بعده** ⛔ **فيقفز النصُّ
/// المكتوب من صفٍّ إلى صفّ.**
class _IntakeLine {
  _IntakeLine({this.itemId, String quantity = ''})
      : quantity = TextEditingController(text: quantity),
        seed = _nextSeed++;

  static int _nextSeed = 0;

  /// النوع — و`null` تعني **صفّاً لم يُختَر نوعُه بعد**.
  String? itemId;

  /// العدد المكتوب.
  final TextEditingController quantity;

  /// مفتاحٌ ثابت للصفّ.
  final int seed;

  /// ★ يُحوِّل الصفَّ مُدخَلاً — و`null` **لصفٍّ ناقص**.
  CountedIntakeLineInput? toInput() {
    final String? id = itemId;
    final int? pieces = PieceCount.tryParseInput(quantity.text)?.pieces;
    if (id == null || pieces == null || pieces <= 0) return null;
    return CountedIntakeLineInput(
      itemId: id,
      // ⚠️ **الاسم للعرض وحده** — ★ **والسحابة تكتب الاسم المخزَّن**
      //    من سجل النوع (`functions_inventory_repository.dart`).
      itemName: id,
      unit: ItemUnit.piece,
      quantity: pieces,
    );
  }

  void dispose() => quantity.dispose();
}

/// يفتح ورقة إلغاء الوارد — ★ **والسببُ اختياريٌّ** (`ADR-0020`).
///
/// ★★ **والورقةُ اليومَ `QtmsDestructiveSheet`** (`MASTER.md` §5b `P6` ·
/// `ADR-0021`) — ⟵ ★★ **فلها زرُّ تراجعٍ صريح**: ⛔ **وكان مخرجُها الوحيد
/// سحباً لأسفل** — **إيماءةٌ غير معلَنة على فعلٍ لا رجعة فيه.**
Future<void> showCancelIntakeSheet(
  BuildContext context, {
  required CountedIntakeCard intake,
}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: SemanticColors.surface,
      builder: (BuildContext context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: CancelIntakeSheet(intake: intake),
      ),
    );

/// ورقة إلغاء الوارد.
///
/// ⚠️⚠️ **وهي مالكةُ المستودع لا الورقةُ الموحّدة** — ★ **تمرّر تنفيذَها في
/// `onConfirm`**، ⟵ **فيُعرَض الرفضُ في موضعه ⑥ والورقةُ مفتوحة.**
class CancelIntakeSheet extends ConsumerStatefulWidget {
  /// ينشئ الورقة.
  const CancelIntakeSheet({required this.intake, super.key});

  /// المستند المُلغى.
  final CountedIntakeCard intake;

  @override
  ConsumerState<CancelIntakeSheet> createState() => _CancelIntakeSheetState();
}

class _CancelIntakeSheetState extends ConsumerState<CancelIntakeSheet> {
  @override
  Widget build(BuildContext context) => QtmsDestructiveSheet(
        title: 'إلغاء ${widget.intake.documentNumber}',
        // ★ **الإلغاء وسمٌ لا حذف** — `GR-06` · `GR-07`.
        impact: 'الإلغاء يَسِم المستند وحركاته ولا يحذف شيئاً، ويُشترط توفّر '
            'الكمية غير المصروفة.',
        confirmLabel: 'تأكيد الإلغاء',
        reasonLabel: 'سبب الإلغاء (اختياري)',
        onConfirm: _submit,
      );

  /// ★ يُرجِع نصَّ الرفض — و`null` نجاحاً.
  Future<String?> _submit(DestructiveConfirmation confirmation) async {
    // ⛔⛔★★★ **ولا حارسَ على السبب** — `ADR-0020` (2026-08-27): ★ **اختياريٌّ
    //    في كل عملية**، ⟵ **وما تركه المستخدم فارغاً يُرسَل غياباً**
    //    ⛔ **لا نصّاً مُعبَّأً عنه.**
    final Outcome<void> result =
        await ref.read(inventoryAdminProvider).cancelCountedIntake(
              documentNumber: widget.intake.documentNumber,
              sourceId: widget.intake.sourceId,
              cancelReason: blankToNull(confirmation.reason),
            );

    return switch (result) {
      Failure<void>(:final AppError error) => catalogText(
          appErrorMessage(error),
        ),
      Success<void>() => null,
    };
  }
}

/// شريط الرفض — ★ **نصّه من الكتالوج حرفياً** ⛔ **ولا صياغة هنا.**
class _Rejection extends StatelessWidget {
  const _Rejection({required this.message});

  final CatalogMessage message;

  @override
  Widget build(BuildContext context) => QtmsInlineBanner(
        text: catalogText(message),
        triad: SemanticTriads.danger,
      );
}

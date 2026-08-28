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
/// ⚠️⚠️ **وكل بوابة صلاحية هنا إخفاءٌ لا حماية** — ★ **والرفض في السحابة**
/// (`ADR-0013` القاعدة 3 · `RISK-02`).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qtms_domain/qtms_domain.dart';

import '../../../core/design/design_tokens.dart';
import '../../../core/messages/error_messages.dart';
import '../../../core/ui/async_state_view.dart';
import '../../../core/ui/context_header.dart';
import '../../../core/ui/destructive_sheet.dart';
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
    final String? sourceId = ref.watch(selectedSourceProvider);
    final List<SourceCard> sources = ref.watch(activeSourcesProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: SemanticColors.surface,
        title: const Text('الوارد عدداً', style: TypeScale.titleSm),
      ),
      floatingActionButton: sourceId == null
          ? null
          : PermissionGate(
              permission: Permission.incomingCountWrite,
              child: _NewIntakeButton(sourceId: sourceId),
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
            selectedSourceId: sourceId,
            onSourceSelected: (String id) =>
                ref.read(selectedSourceProvider.notifier).select(id),
            day: today,
          ),
          Expanded(
            // ⛔⛔★★★ **ولا `SizedBox.shrink` حالةً لغياب المصدر** — §5b نمط
            //    `P3` قاعدةُ الفراغ الصامت (`design-system.md` §هـ).
            child: sourceId == null
                ? QtmsEmptyState(
                    spec: sources.isEmpty
                        ? noSourceInScopeEmpty
                        : chooseSourceEmpty(),
                  )
                : _IntakeList(sourceId: sourceId, day: today),
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
  const _IntakeList({required this.sourceId, required this.day});

  final String sourceId;
  final CalendarDay day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<CountedIntakeCard>> intakes = ref.watch(
      countedIntakesProvider(StockQuery(sourceId: sourceId, stockDate: day)),
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
            _IntakeTile(intake: list[index]),
      ),
    );
  }
}

class _IntakeTile extends ConsumerWidget {
  const _IntakeTile({required this.intake});

  final CountedIntakeCard intake;

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
        subtitle: '${intake.lines.length} نوع · '
            '${quantityLabel(PieceQuantity(intake.totalQuantity))}',
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

  /// السطور بمعرّف النوع — ★ **ومفتاح الخريطة يفرض «لا سطران لنفس النوع»**
  /// بنيوياً (`FR-M6-07`).
  late final Map<String, int> _lines = <String, int>{
    for (final ValidatedCountedIntakeLine line
        in widget.existing?.lines ?? const <ValidatedCountedIntakeLine>[])
      line.itemId: line.quantity.pieces,
  };

  late String? _supplierId = widget.existing?.supplierId;
  CatalogMessage? _rejection;
  bool _submitting = false;

  bool get _isEdit => widget.existing != null;

  @override
  void dispose() {
    _notes.dispose();
    _amendReason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final CalendarDay today = ref.watch(todayProvider);
    final List<ItemCard> items = ref.watch(intakeItemsProvider(widget.sourceId));
    final List<SupplierCard> suppliers =
        ref.watch(intakeSuppliersProvider(widget.sourceId));
    final bool requiresSupplier = _requiresSupplier(ref, widget.sourceId);

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
            for (final ItemCard item in items)
              _LineRow(
                item: item,
                quantity: _lines[item.itemId],
                onChanged: (int? value) => setState(() {
                  if (value == null || value <= 0) {
                    _lines.remove(item.itemId);
                  } else {
                    _lines[item.itemId] = value;
                  }
                }),
              ),
            if (items.isEmpty)
              Text(
                // `FR-M6-05` — قائمة الأنواع مفلترة بالمصدر حصراً.
                'لا توجد أنواع مرتبطة بهذا المصدر.',
                style: TypeScale.bodyMd
                    .copyWith(color: SemanticColors.textSecondary),
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
                decoration: const InputDecoration(labelText: 'سبب التعديل (اختياري)'),
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
        sourceId: widget.sourceId,
        sourceRequiresSupplier: requiresSupplier,
        supplierId: requiresSupplier ? _supplierId : null,
        notes: _notes.text,
        lines: <CountedIntakeLineInput>[
          for (final MapEntry<String, int> line in _lines.entries)
            CountedIntakeLineInput(
              itemId: line.key,
              // ⚠️ **الاسم للعرض وحده** — ★ **والسحابة تكتب الاسم المخزَّن**
              //    من سجل النوع (`functions_inventory_repository.dart`).
              itemName: line.key,
              unit: ItemUnit.piece,
              quantity: line.value,
            ),
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

class _LineRow extends StatelessWidget {
  const _LineRow({
    required this.item,
    required this.quantity,
    required this.onChanged,
  });

  final ItemCard item;
  final int? quantity;
  final void Function(int?) onChanged;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: Spacing.space8),
        child: Row(
          children: <Widget>[
            Expanded(child: Text(item.name, style: TypeScale.bodyMd)),
            const SizedBox(width: Spacing.space8),
            SizedBox(
              width: 120,
              child: TextFormField(
                initialValue: quantity?.toString() ?? '',
                // ★★ **لوحة أرقام بلا كسور** — `BR-M6-06`: ⛔ **والكسر
                //    مرفوض في النوع نفسه** (`PieceCount.tryParseInput`).
                keyboardType: const TextInputType.numberWithOptions(),
                decoration: InputDecoration(labelText: unitName(item.unit)),
                onChanged: (String value) =>
                    onChanged(PieceCount.tryParseInput(value)?.pieces),
              ),
            ),
          ],
        ),
      );
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
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(Spacing.space12),
        decoration: BoxDecoration(
          color: Primitives.dangerSoft,
          border: Border.all(color: Primitives.dangerBorder),
          borderRadius: BorderRadius.circular(Radii.card),
        ),
        child: Text(
          catalogText(message),
          style: TypeScale.bodyMd.copyWith(color: Primitives.dangerInk),
        ),
      );
}

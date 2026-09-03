/// شاشة الأنواع — **نمط 2** `ui-guidelines.md` §3.
///
/// ★★ **والنوع كيان واحد مستقل بتسمية واحدة** (`FR-M5` §1) — ⛔ **لا شجرة
/// من مستويين**، وهو الوحدة التي يُمسك لها **رصيد مخزني** و**سعران**.
///
/// ⛔★★ **ولا حقل سعر في هذه الشاشة إطلاقاً** — `FR-M5-09`: «الأسعار في
/// `M9` أو داخل سطر الجونية أو سطر التوزيع»، ★ **والدالة الكاتبة تُبطل
/// الطلب كله بأي حقل سعر.**
///
/// ★★ **و«السكرب» يظهر بعلامة 🔒 ولا تُتاح أزراره** (`FR-M5-05`) — ⚠️⚠️
/// **وهذا إخفاء لا حماية**: الدالة ترفضه بـ`ERR_SETUP_008` ولو تجاوز أحدٌ
/// الشاشة.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qtms_domain/qtms_domain.dart';

import '../../../app/top_bar.dart';

import '../../../core/device/device_preference_providers.dart';
import '../../../core/design/design_tokens.dart';
import '../../../core/ui/item_labels.dart';
import '../../../core/ui/entity_tile.dart';
import '../../../core/messages/error_messages.dart';
import '../../identity_access/presentation/permission_gate.dart';
import '../../oversight/presentation/audit_trail_view.dart';
import '../application/master_data_providers.dart';
import 'master_data_widgets.dart';
import '../../../core/ui/optional_reason.dart';

/// قائمة الأنواع.
class ItemsScreen extends ConsumerWidget {
  /// ينشئ الشاشة.
  const ItemsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<ItemCard>> items = ref.watch(itemsProvider);

    return Scaffold(
      appBar: QtmsTopBar(screenTitle: 'الأنواع'),
      floatingActionButton: const PermissionGate(
        permission: Permission.itemWrite,
        child: _NewItemButton(),
      ),
      body: MasterDataAsyncView<ItemCard>(
        value: items,
        emptyIcon: Icons.category_outlined,
        emptyTitle: 'لا توجد أنواع بعد',
        emptyLabel: 'النوع يحدّد وحدة القياس وطريقة الوزن — أضف أول نوع قبل تسجيل الوارد.',
        builder: (List<ItemCard> list) => EntityList(
          itemCount: list.length,
          itemBuilder: (BuildContext context, int index) =>
              _ItemTile(item: list[index]),
        ),
      ),
    );
  }
}

class _NewItemButton extends StatelessWidget {
  const _NewItemButton();

  @override
  Widget build(BuildContext context) => FloatingActionButton.extended(
        onPressed: () => showItemForm(context),
        icon: const Icon(Icons.category_outlined),
        label: const Text('نوع جديد'),
      );
}

class _ItemTile extends ConsumerWidget {
  const _ItemTile({required this.item});

  final ItemCard item;

  @override
  Widget build(BuildContext context, WidgetRef ref) => MasterDataTile(
        // ★★★ **واسمُ النوع بوزن حبته عند تفعيل الخيار** — `AM-012` §4.4:
        //    ⛔ **عرضٌ محضٌ** ⟵ **والطبيعةُ والوحدةُ في السطر الثاني كما هما.**
        title: itemCardDisplayName(
          item,
          showPieceWeight: ref.watch(showPieceWeightProvider),
        ),
        // ★★ **أيقونة 🕘 في أول الصفّ** — `FR-M18-10` · `FR-M18-11`.
        // ⛔⛔ **وعنوانُ السجل الاسمُ الخام** — ★ **ولا لاحقةَ عرضٍ فيه:**
        //    ⟵ **فالسجلُّ يُقرأ بعد سنةٍ وقد تغيّر التفضيل**، ⛔ **وعنوانٌ
        //    يتبدّل بتفضيلِ جهازٍ يجعل قيدين لكيانٍ واحد يبدوان لكيانين.**
        leading: auditTrailLeading(
          ref,
          entityType: itemEntityType,
          entityId: item.itemId,
          title: item.name,
        ),
        subtitle: '${natureLabel(item.nature)} · ${unitLabel(item.unit)}',
        badges: <Widget>[
          if (item.isSystemDefault) const SystemDefaultBadge(),
          if (!item.isActive) const DisabledBadge(),
        ],
        actions: <Widget>[
          // ⛔★★ **ولا زر تعديل للنوع الافتراضي** — `FR-M5-05`: «لا يُنشئه
          //    المستخدم ولا يحذفه ولا يُعطِّله من أي واجهة».
          if (!item.isSystemDefault)
            PermissionGate(
              permission: Permission.itemWrite,
              // ★★ **وإجراءٌ بأيقونةٍ ونصّ لا برمزٍ صامت** — `design-system.md` §6.ج:
              //    ⟵ **وقلمٌ عارٍ في صفٍّ خاصٍّ به يترك القارئ يخمّن ما يُعدَّل.**
              child: TextButton.icon(
                onPressed: () => showItemForm(context, existing: item),
                icon: const Icon(Icons.edit_outlined, size: Sizes.iconMd),
                label: const Text('تعديل'),
              ),
            ),
        ],
      );
}

/// ★ وصف الطبيعة بالعربية — ⛔ **ولا مصطلح تقني في الواجهة**
/// (`ui-guidelines.md` §6).
String natureLabel(ItemNature nature) => switch (nature) {
      ItemNature.countBased => 'عددي',
      ItemNature.weightBased => 'وزني',
    };

/// ★ وصف الوحدة بالعربية.
String unitLabel(ItemUnit unit) => switch (unit) {
      ItemUnit.piece => 'حبة',
      ItemUnit.kilogram => 'كيلوجرام',
    };

/// يفتح نموذج النوع — و[existing] `null` تعني **إنشاءً**.
Future<void> showItemForm(
  BuildContext context, {
  ItemCard? existing,
}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: SemanticColors.surface,
      builder: (BuildContext context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: ItemFormSheet(existing: existing),
      ),
    );

/// ورقة نموذج النوع.
class ItemFormSheet extends ConsumerStatefulWidget {
  /// ينشئ الورقة.
  const ItemFormSheet({this.existing, super.key});

  /// النوع المُعدَّل.
  final ItemCard? existing;

  @override
  ConsumerState<ItemFormSheet> createState() => _ItemFormSheetState();
}

class _ItemFormSheetState extends ConsumerState<ItemFormSheet> {
  late final TextEditingController _name =
      TextEditingController(text: widget.existing?.name ?? '');
  late final TextEditingController _pieceWeight = TextEditingController(
    text: widget.existing?.pieceWeightGrams?.toString() ?? '',
  );
  final TextEditingController _amendReason = TextEditingController();
  final TextEditingController _disableReason = TextEditingController();

  late Set<String> _sources = <String>{...?widget.existing?.sourceIds};
  late ItemNature _nature = widget.existing?.nature ?? ItemNature.countBased;
  late bool _isActive = widget.existing?.isActive ?? true;

  CatalogMessage? _rejection;
  bool _submitting = false;

  bool get _isEdit => widget.existing != null;

  @override
  void dispose() {
    _name.dispose();
    _pieceWeight.dispose();
    _amendReason.dispose();
    _disableReason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Spacing.space16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                _isEdit ? 'تعديل نوع' : 'نوع جديد',
                style: TypeScale.titleLg,
              ),
              const SizedBox(height: Spacing.space16),
              MasterDataField(
                controller: _name,
                label: 'اسم النوع',
                autofocus: true,
              ),
              const SizedBox(height: Spacing.space16),
              SourcesSelector(
                available: ref.watch(activeSourcesProvider),
                selected: _sources,
                onChanged: (Set<String> next) =>
                    setState(() => _sources = next),
              ),
              const SizedBox(height: Spacing.space16),
              Text(
                'الطبيعة',
                style: TypeScale.label
                    .copyWith(color: SemanticColors.textSecondary),
              ),
              const SizedBox(height: Spacing.space8),
              SegmentedButton<ItemNature>(
                segments: <ButtonSegment<ItemNature>>[
                  for (final ItemNature nature in ItemNature.values)
                    ButtonSegment<ItemNature>(
                      value: nature,
                      label: Text(natureLabel(nature)),
                    ),
                ],
                selected: <ItemNature>{_nature},
                onSelectionChanged: (Set<ItemNature> next) =>
                    setState(() => _nature = next.first),
              ),
              // ★★ **وزن الحبة للوزني وحده** — `FR-M5-02` · `E-09`:
              //   ⛔ **ويختفي تماماً للعددي** لا يُعطَّل فحسب.
              if (_nature == ItemNature.weightBased) ...<Widget>[
                const SizedBox(height: Spacing.space12),
                MasterDataField(
                  controller: _pieceWeight,
                  label: 'وزن الحبة بالجرام (اختياري)',
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: Spacing.space4),
                Text(
                  // `FR-M5-08` — أثرٌ يجب أن يعرفه المستخدم.
                  'قيمة افتراضية للعرض — تعديلها لاحقاً لا يؤثر على أي جونية '
                  'سابقة.',
                  style: TypeScale.bodyMd
                      .copyWith(color: SemanticColors.textSecondary),
                ),
              ],
              // ⛔★★ **ولا حقل وحدة ولا حقل سعر** — الوحدة **مشتقّة**
              //    (`FR-M5-03`: حبة لكل ما يُنشئه المستخدم)، ★ **والسعر
              //    مرفوض على السجل** (`FR-M5-09`).
              if (_isEdit) ...<Widget>[
                const SizedBox(height: Spacing.space12),
                SwitchListTile(
                  value: _isActive,
                  onChanged: (bool on) => setState(() => _isActive = on),
                  title: const Text('النوع نشط'),
                  subtitle: const Text('التعطيل بديل الحذف — ولا حذف للأنواع.'),
                  contentPadding: EdgeInsets.zero,
                ),
                if (!_isActive) ...<Widget>[
                  const SizedBox(height: Spacing.space12),
                  MasterDataField(
                    controller: _disableReason,
                    label: 'سبب التعطيل',
                  ),
                ],
                const SizedBox(height: Spacing.space12),
                MasterDataField(controller: _amendReason, label: 'سبب التعديل (اختياري)'),
              ],
              if (_rejection != null) ...<Widget>[
                const SizedBox(height: Spacing.space12),
                RejectionBanner(message: _rejection!),
              ],
              const SizedBox(height: Spacing.space16),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                child: Text(_isEdit ? 'حفظ التعديل' : 'إنشاء'),
              ),
            ],
          ),
        ),
      );

  Future<void> _submit() async {
    final Outcome<ValidatedItem> validated = validateItem(
      ItemInput(
        sourceIds: _sources.toList(),
        name: _name.text,
        nature: _nature,
        // ★ **يُرسَل للوزني وحده** — ⛔ **وللعددي يُرفَض** (`E-09`)، ★ **فلا
        //   نُرسل قيمةً بقيت في المتحكّم بعد تبديل الطبيعة.**
        pieceWeightGrams: _nature == ItemNature.weightBased
            ? double.tryParse(_pieceWeight.text.trim())
            : null,
        isActive: !_isEdit || _isActive,
        disableReason: _disableReason.text,
      ),
    );
    if (validated is Failure<ValidatedItem>) {
      setState(() => _rejection = CatalogMessage.operationFailed);
      return;
    }
    final ValidatedItem item = (validated as Success<ValidatedItem>).value;

    setState(() {
      _submitting = true;
      _rejection = null;
    });

    final MasterDataAdminRepository admin = ref.read(masterDataAdminProvider);
    final Outcome<void> result = _isEdit
        ? await admin.updateItem(
            itemId: widget.existing!.itemId,
            item: item,
            amendReason: blankToNull(_amendReason.text),
          )
        : switch (await admin.createItem(item)) {
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
}

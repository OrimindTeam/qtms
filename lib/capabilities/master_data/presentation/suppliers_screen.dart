/// شاشة الرعية (الموردين) — **نمط 2** `ui-guidelines.md` §3.
///
/// ★ **والرعوي يحمل مصادره** (`FR-M3-01`) — ⟵ **ولا يظهر في قائمة رعية
/// مصدرٍ ليس ضمنها** (`FR-M3-09`). ⚠️ **وإزالة مصدر لا تمسّ جوانيه السابقة
/// ولا حسابه فيه** — تمنع التوريد الجديد منه فقط (`FR-M3-08`).
///
/// ⛔ **ولا رقم مالي هنا:** «عرض مالية الرعوي» صلاحية مستقلة وبياناتها
/// تُبنى في `WU-015` — ★ **ولا تُدَّعى موجودة.**
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qtms_domain/qtms_domain.dart';

import '../../../core/design/design_tokens.dart';
import '../../../core/ui/entity_tile.dart';
import '../../../core/messages/error_messages.dart';
import '../../identity_access/presentation/permission_gate.dart';
import '../../oversight/presentation/audit_trail_view.dart';
import '../application/master_data_providers.dart';
import '../infrastructure/contact_picker.dart';
import 'master_data_widgets.dart';
import '../../../core/ui/optional_reason.dart';

/// قائمة الرعية.
class SuppliersScreen extends ConsumerWidget {
  /// ينشئ الشاشة.
  const SuppliersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<SupplierCard>> suppliers =
        ref.watch(suppliersProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: SemanticColors.surface,
        title: const Text('الرعية', style: TypeScale.titleSm),
      ),
      floatingActionButton: const PermissionGate(
        permission: Permission.supplierWrite,
        child: _NewSupplierButton(),
      ),
      body: MasterDataAsyncView<SupplierCard>(
        value: suppliers,
        emptyIcon: Icons.agriculture_outlined,
        emptyTitle: 'لا يوجد رعية بعد',
        emptyLabel: 'أضف أول رعوي لتنسب إليه الجواني الواردة وتتابع صافيه.',
        builder: (List<SupplierCard> items) => EntityList(
          itemCount: items.length,
          itemBuilder: (BuildContext context, int index) =>
              _SupplierTile(supplier: items[index]),
        ),
      ),
    );
  }
}

class _NewSupplierButton extends StatelessWidget {
  const _NewSupplierButton();

  @override
  Widget build(BuildContext context) => FloatingActionButton.extended(
        onPressed: () => showSupplierForm(context),
        icon: const Icon(Icons.person_add_alt_1_outlined),
        label: const Text('رعوي جديد'),
      );
}

class _SupplierTile extends ConsumerWidget {
  const _SupplierTile({required this.supplier});

  final SupplierCard supplier;

  @override
  Widget build(BuildContext context, WidgetRef ref) => MasterDataTile(
        title: supplier.name,
        // ★★ **أيقونة 🕘 في أول الصفّ** — `FR-M18-10` · `FR-M18-11`.
        leading: auditTrailLeading(
          ref,
          entityType: supplierEntityType,
          entityId: supplier.supplierId,
          title: supplier.name,
        ),
        subtitle: '${supplier.phone} · ${supplier.sourceIds.length} مصدر',
        badges: <Widget>[
          if (!supplier.isActive) const DisabledBadge(),
        ],
        actions: <Widget>[
          PermissionGate(
            permission: Permission.supplierWrite,
            // ★★ **وإجراءٌ بأيقونةٍ ونصّ لا برمزٍ صامت** — `design-system.md` §6.ج.
            child: TextButton.icon(
              onPressed: () => showSupplierForm(context, existing: supplier),
              icon: const Icon(Icons.edit_outlined, size: Sizes.iconMd),
              label: const Text('تعديل'),
            ),
          ),
        ],
      );
}

/// يفتح نموذج الرعوي — و[existing] `null` تعني **إنشاءً**.
Future<void> showSupplierForm(
  BuildContext context, {
  SupplierCard? existing,
}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: SemanticColors.surface,
      builder: (BuildContext context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SupplierFormSheet(existing: existing),
      ),
    );

/// ورقة نموذج الرعوي.
class SupplierFormSheet extends ConsumerStatefulWidget {
  /// ينشئ الورقة.
  const SupplierFormSheet({this.existing, super.key});

  /// الرعوي المُعدَّل.
  final SupplierCard? existing;

  @override
  ConsumerState<SupplierFormSheet> createState() => _SupplierFormSheetState();
}

class _SupplierFormSheetState extends ConsumerState<SupplierFormSheet> {
  late final TextEditingController _name =
      TextEditingController(text: widget.existing?.name ?? '');
  late final TextEditingController _phone =
      TextEditingController(text: widget.existing?.phone ?? '');
  late final TextEditingController _notes =
      TextEditingController(text: widget.existing?.notes ?? '');
  final TextEditingController _amendReason = TextEditingController();
  final TextEditingController _disableReason = TextEditingController();

  late Set<String> _sources = <String>{...?widget.existing?.sourceIds};
  late bool _isActive = widget.existing?.isActive ?? true;

  CatalogMessage? _rejection;
  bool _submitting = false;

  bool get _isEdit => widget.existing != null;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _notes.dispose();
    _amendReason.dispose();
    _disableReason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ContactPicker? picker = ref.watch(contactPickerProvider);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Spacing.space16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              _isEdit ? 'تعديل رعوي' : 'رعوي جديد',
              style: TypeScale.titleLg,
            ),
            const SizedBox(height: Spacing.space16),
            // ★★ **زرٌّ واحد يملأ الاسم والرقم معاً** — `FR-M3-03`.
            //   ⛔ **ولا يظهر بلا مُنتقٍ** (بيئة اختبار أو جهاز بلا تطبيق
            //   جهات اتصال) — ★ **والإدخال اليدوي باقٍ في الحالتين.**
            if (picker != null) ...<Widget>[
              OutlinedButton.icon(
                onPressed: () => _fillFromContacts(picker),
                icon: const Icon(Icons.contacts_outlined),
                label: const Text('جلب من جهات الاتصال'),
              ),
              const SizedBox(height: Spacing.space12),
            ],
            MasterDataField(
              controller: _name,
              label: 'اسم الرعوي',
              autofocus: true,
            ),
            const SizedBox(height: Spacing.space12),
            MasterDataField(
              controller: _phone,
              label: 'رقم الهاتف',
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: Spacing.space16),
            SourcesSelector(
              available: ref.watch(activeSourcesProvider),
              selected: _sources,
              onChanged: (Set<String> next) => setState(() => _sources = next),
            ),
            const SizedBox(height: Spacing.space12),
            MasterDataField(controller: _notes, label: 'ملاحظات (اختياري)'),
            if (_isEdit) ...<Widget>[
              const SizedBox(height: Spacing.space12),
              SwitchListTile(
                value: _isActive,
                onChanged: (bool on) => setState(() => _isActive = on),
                title: const Text('الرعوي نشط'),
                subtitle: const Text('التعطيل بديل الحذف — ولا حذف للرعية.'),
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
  }

  Future<void> _fillFromContacts(ContactPicker picker) async {
    final PickedContact? contact = await picker.pickOne();
    if (contact == null || !mounted) return;
    // ★ **يملأ ولا يقفل** — `FR-M3-03`: «مع إمكانية التعديل اليدوي بعده».
    setState(() {
      if (contact.name.isNotEmpty) _name.text = contact.name;
      _phone.text = contact.phone;
    });
  }

  Future<void> _submit() async {
    final Outcome<ValidatedSupplier> validated = validateSupplier(
      SupplierInput(
        sourceIds: _sources.toList(),
        name: _name.text,
        phone: _phone.text,
        notes: _notes.text,
        isActive: !_isEdit || _isActive,
        disableReason: _disableReason.text,
      ),
    );
    if (validated is Failure<ValidatedSupplier>) {
      setState(() => _rejection = CatalogMessage.operationFailed);
      return;
    }
    final ValidatedSupplier supplier =
        (validated as Success<ValidatedSupplier>).value;

    setState(() {
      _submitting = true;
      _rejection = null;
    });

    final MasterDataAdminRepository admin = ref.read(masterDataAdminProvider);
    final Outcome<void> result = _isEdit
        ? await admin.updateSupplier(
            supplierId: widget.existing!.supplierId,
            supplier: supplier,
            amendReason: blankToNull(_amendReason.text),
          )
        : switch (await admin.createSupplier(supplier)) {
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

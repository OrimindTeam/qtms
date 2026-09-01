/// شاشة المصادر — **نمط 2 (قائمة الكيانات)** `ui-guidelines.md` §3.
///
/// ★★ **والمصدر وحدة الفصل الكبرى في النظام** (`FR-M2` §1): مخزون مستقل ·
/// حسابات مستقلة · ضمار مستقل · **ونطاق صلاحية مستقل**. ⟵ **فإضافته
/// تُطلِق تهيئة الحسابات لكل مقوت ورعوي** (`FR-M2-04` · `AT-37`).
///
/// ⚠️⚠️ **وإخفاء الأزرار بـ`sourceWrite` إخفاءٌ لا حماية** — ★ **والكتابة
/// مغلقة في القواعد أصلاً**، والتفويض يُفحَص في الدالة (`ADR-0013` القاعدة 3).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qtms_domain/qtms_domain.dart';

import '../../../app/top_bar.dart';

import '../../../core/design/design_tokens.dart';
import '../../../core/ui/entity_tile.dart';
import '../../../core/messages/error_messages.dart';
import '../../identity_access/presentation/permission_gate.dart';
import '../../oversight/presentation/audit_trail_view.dart';
import '../application/master_data_providers.dart';
import 'master_data_widgets.dart';
import '../../../core/ui/optional_reason.dart';

/// قائمة المصادر.
class SourcesScreen extends ConsumerWidget {
  /// ينشئ الشاشة.
  const SourcesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<SourceCard>> sources = ref.watch(sourcesProvider);

    return Scaffold(
      appBar: QtmsTopBar(screenTitle: 'المصادر'),
      floatingActionButton: const PermissionGate(
        permission: Permission.sourceWrite,
        child: _NewSourceButton(),
      ),
      body: MasterDataAsyncView<SourceCard>(
        value: sources,
        emptyIcon: Icons.warehouse_outlined,
        emptyTitle: 'لا توجد مصادر بعد',
        emptyLabel: 'المصدر وحدة الفصل العليا في النظام — أنشئ أول مصدر لتبدأ تسجيل حركاته.',
        builder: (List<SourceCard> items) => EntityList(
          itemCount: items.length,
          itemBuilder: (BuildContext context, int index) =>
              _SourceTile(source: items[index]),
        ),
      ),
    );
  }
}

class _NewSourceButton extends StatelessWidget {
  const _NewSourceButton();

  @override
  Widget build(BuildContext context) => FloatingActionButton.extended(
        onPressed: () => showSourceForm(context),
        icon: const Icon(Icons.add_business_outlined),
        label: const Text('مصدر جديد'),
      );
}

class _SourceTile extends ConsumerWidget {
  const _SourceTile({required this.source});

  final SourceCard source;

  @override
  Widget build(BuildContext context, WidgetRef ref) => MasterDataTile(
        // ⛔⛔★★★ **الإجراء في صفّ الاسم نفسِه** — `AM-008` ⑥.
        actionsPlacement: EntityActionsPlacement.inline,
        title: source.name,
        // ★★ **أيقونة 🕘 في أول الصفّ** — `FR-M18-10` · `FR-M18-11`
        //   («**المصادر**» أولُ الشاشات المشمولة).
        leading: auditTrailLeading(
          ref,
          entityType: sourceEntityType,
          entityId: source.sourceId,
          title: source.name,
          // ★ **والمصدر يحمل نفسه في قيده** — `master_data.dart`:
          //   `auditSourceId: request.entityId` ⟵ **فيُفلتَر بالنطاق.**
          sourceId: source.sourceId,
        ),
        // ★ **الخيار الأهم تشغيلياً في السطر الثاني** — فهو ما يُغيّر شكل
        //   شاشتَي التوريد (`FR-M2-02`).
        subtitle: source.requiresSupplierOnIntake
            ? 'الرعوي إلزامي عند التوريد'
            : 'الرعوي غير مطلوب عند التوريد',
        badges: <Widget>[
          if (!source.isActive) const DisabledBadge(),
        ],
        actions: <Widget>[
          PermissionGate(
            permission: Permission.sourceWrite,
            // ⛔⛔★★★ **وزرٌّ أيقونيٌّ في صفّ الاسم نفسِه** — `AM-008` ⑥:
            //    ★ **بدل صفٍّ مستقلٍّ بفاصلٍ شعريٍّ لزرٍّ واحد**، ⟵ **وكان
            //    يُطيل البطاقة نصفَ ارتفاعها بلا معلومة.**
            //
            // ⚠️★★ **والنصّ سقط من الزرّ لا من الواجهة:** ★ **يبقى في
            //    `tooltip` لقارئ الشاشة وللضغط المطوّل** — ⛔ **وإبقاؤه
            //    مرسوماً كان يعصر اسمَ الكيان عند تكبير الخط**، ★ **وهو
            //    عطلُ `DEBT-48` بعينه** (`context_header.dart`).
            //    ⛔ **وقاعدةُ «لا أيقونة صامتة» في §6.ج على الزرّ العائم**،
            //    ★ **وبطاقاتُ المستخدمين على هذا النهج منذ `WU-001`.**
            child: IconButton(
              onPressed: () => showSourceForm(context, existing: source),
              icon: const Icon(Icons.edit_outlined, size: Sizes.iconMd),
              tooltip: 'تعديل',
              constraints: const BoxConstraints(
                minWidth: Sizes.minTouch,
                minHeight: Sizes.minTouch,
              ),
            ),
          ),
        ],
      );
}

/// يفتح نموذج المصدر — و[existing] `null` تعني **إنشاءً**.
Future<void> showSourceForm(
  BuildContext context, {
  SourceCard? existing,
}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: SemanticColors.surface,
      builder: (BuildContext context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SourceFormSheet(existing: existing),
      ),
    );

/// ورقة نموذج المصدر — **نمط 4**.
class SourceFormSheet extends ConsumerStatefulWidget {
  /// ينشئ الورقة.
  const SourceFormSheet({this.existing, super.key});

  /// المصدر المُعدَّل — و`null` تعني إنشاءً.
  final SourceCard? existing;

  @override
  ConsumerState<SourceFormSheet> createState() => _SourceFormSheetState();
}

class _SourceFormSheetState extends ConsumerState<SourceFormSheet> {
  late final TextEditingController _name =
      TextEditingController(text: widget.existing?.name ?? '');
  late final TextEditingController _notes =
      TextEditingController(text: widget.existing?.notes ?? '');
  final TextEditingController _amendReason = TextEditingController();
  final TextEditingController _disableReason = TextEditingController();

  late bool _requiresSupplier = widget.existing?.requiresSupplierOnIntake ?? false;
  late bool _isActive = widget.existing?.isActive ?? true;

  CatalogMessage? _rejection;
  bool _submitting = false;

  bool get _isEdit => widget.existing != null;

  @override
  void dispose() {
    _name.dispose();
    _notes.dispose();
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
                _isEdit ? 'تعديل مصدر' : 'مصدر جديد',
                style: TypeScale.titleLg,
              ),
              const SizedBox(height: Spacing.space16),
              MasterDataField(
                controller: _name,
                label: 'اسم المصدر',
                autofocus: true,
              ),
              const SizedBox(height: Spacing.space12),
              // ★★ **الخيار ذو الأثر التشغيلي** — `FR-M2-02` · `FR-M2-03`:
              //   تغييرُه **لا يمسّ المستندات السابقة إطلاقاً** (`E-38`).
              SwitchListTile(
                value: _requiresSupplier,
                onChanged: (bool on) => setState(() => _requiresSupplier = on),
                title: const Text('يجب اختيار الرعوي عند التوريد'),
                subtitle: const Text(
                  'لا يؤثر على المستندات السابقة — يُطبَّق على الجديدة فقط.',
                ),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: Spacing.space12),
              MasterDataField(controller: _notes, label: 'ملاحظات (اختياري)'),
              if (_isEdit) ...<Widget>[
                const SizedBox(height: Spacing.space12),
                // ★★ **التعطيل بديل الحذف** — `FR-M2-05`: «لا يُحذف مصدر له
                //   أي حركة إطلاقاً»، ⛔ **والحذف مرفوض في القاعدة دائماً.**
                SwitchListTile(
                  value: _isActive,
                  onChanged: (bool on) => setState(() => _isActive = on),
                  title: const Text('المصدر نشط'),
                  subtitle: const Text('التعطيل بديل الحذف — ولا حذف للمصادر.'),
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
                // ★★ **حقل السبب في التعديل وحده** — `ADR-0004` · `DEBT-21` ①.
                MasterDataField(
                  controller: _amendReason,
                  label: 'سبب التعديل (اختياري)',
                ),
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
              if (!_isEdit) ...<Widget>[
                const SizedBox(height: Spacing.space12),
                Text(
                  // ⚙️ `FR-M2-04` — أثرٌ يجب أن يعرفه المستخدم قبل الحفظ.
                  'يُنشأ للمصدر تلقائياً حسابٌ لكل مقوت ولكل رعوي، ويُوصَل به '
                  'نوع «السكرب».',
                  style: TypeScale.bodyMd
                      .copyWith(color: SemanticColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      );

  Future<void> _submit() async {
    // ★ **القواعد من طبقة النطاق المشتركة** — ⛔ ولا تُعاد كتابتها هنا،
    //   ⟵ **فما ترفضه السحابة يُرفَض هنا بلا رحلة شبكة.**
    final Outcome<ValidatedSource> validated = validateSource(
      SourceInput(
        name: _name.text,
        requiresSupplierOnIntake: _requiresSupplier,
        notes: _notes.text,
        isActive: !_isEdit || _isActive,
        disableReason: _disableReason.text,
      ),
    );
    if (validated is Failure<ValidatedSource>) {
      setState(() => _rejection = CatalogMessage.operationFailed);
      return;
    }
    final ValidatedSource source = (validated as Success<ValidatedSource>).value;

    setState(() {
      _submitting = true;
      _rejection = null;
    });

    final MasterDataAdminRepository admin = ref.read(masterDataAdminProvider);
    final Outcome<void> result = _isEdit
        ? await admin.updateSource(
            sourceId: widget.existing!.sourceId,
            source: source,
            amendReason: blankToNull(_amendReason.text),
          )
        : switch (await admin.createSource(source)) {
            Failure<String>(:final AppError error) => Failure<void>(error),
            Success<String>() => const Success<void>(null),
          };

    if (!mounted) return;
    switch (result) {
      case Failure<void>(:final AppError error):
        // ★ **الرفض يُعرَض** — ⛔ ولا يُبتلَع، **والورقة تبقى بمدخلاته.**
        setState(() {
          _submitting = false;
          _rejection = appErrorMessage(error);
        });
      case Success<void>():
        Navigator.of(context).pop();
    }
  }
}

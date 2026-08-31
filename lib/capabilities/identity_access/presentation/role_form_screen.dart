/// نموذج الدور وتأكيد حذفه — **نمط 4 (النموذج)** `ui-guidelines.md` §3.
///
/// ★ **ورقةٌ سفلية لا شاشة كاملة:** الحقول ثلاثة على الأكثر ⟵ **≤ 8**.
///
/// ★★ **وقاعدتا نمط 4 مُنفَّذتان هنا:** ① الزر الأساسي فوق لوحة المفاتيح ·
/// ② ★ **حقل السبب يظهر في التعديل وحده** — ⛔ **ولا «قبل» قبل الإنشاء أصلاً.**
///
/// ⛔⛔★★★ **والسببُ اختياريٌّ تعديلاً وحذفاً معاً** (`ADR-0020` · 2026-08-27) —
/// ★ **ولا يُعطَّل زرٌّ لغيابه**: ⚠️ **وكان إلزامياً بـ`ADR-0004` الشرط 2
/// و`IQ-018`** ⟵ **وسقط الشرطان بذلك القرار.**
/// ★★ **والحارس الباقي وحده: لا يُعبَّأ سببٌ نيابةً عن المستخدم** — ⟵ **فما
/// تركه فارغاً يُرسَل غياباً** بـ`blankToNull`.
///
/// ⚠️★★ **وجملةُ الأثر في ورقة الحذف هي التعويض الوحيد** — ★ **إذ لم يعد
/// ثمّة سببٌ يُقرأ لاحقاً «لماذا اختفى الدور».**
///
/// ⚠️⚠️ **وكل تحقّق هنا راحةٌ لا حماية:** القواعد نفسها في `validateRole`
/// **تُفحَص في السحابة** (`ADR-0012` — الحزمة مشتركة)، ⟵ **فلا يمرّ ما
/// ترفضه السحابة ولو تجاوز أحدٌ هذه الورقة.**
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qtms_domain/qtms_domain.dart';

import '../../../core/design/design_tokens.dart';
import '../../../core/ui/destructive_sheet.dart';
import '../../../core/ui/inline_banner.dart';
import '../../../core/messages/error_messages.dart';
import '../application/admin_providers.dart';
import 'permission_tree.dart';
import '../../../core/ui/optional_reason.dart';

/// يفتح نموذج الدور — و[existing] `null` تعني **إنشاءً**.
Future<void> showRoleForm(BuildContext context, {RoleCard? existing}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: SemanticColors.surface,
      builder: (BuildContext context) => Padding(
        // ★ **الزر الأساسي فوق لوحة المفاتيح** — نمط 4 البند ④.
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: RoleFormSheet(existing: existing),
      ),
    );

/// ★★ يطلب **تأكيد الحذف** ويقبل سبباً **اختيارياً** (`ADR-0020`).
///
/// ⛔⛔★★★ **وقيمتا العودة متمايزتان عمداً:** `null` = **تراجَع المستخدم** ·
/// نصٌّ (**وقد يكون فارغاً**) = **أكّد الحذف**. ⟵ ★ **فلولا هذا التمييز لصار
/// «أكّد بلا سبب» يُقرأ «تراجَع»**، ⛔ **وحذفٌ طلبه المستخدم لا يقع.**
///
/// ⚠️ **ولا يحذف بنفسه** — ★ **فصلُ «طلب التأكيد» عن «تنفيذ الحذف» مقصود**:
/// ⟵ **الشاشة التي تملك المستودع هي التي تنفّذ وتعرض الرفض**، فلا تُغلَق
/// الورقة على رفضٍ لا يراه أحد.
Future<String?> showRoleDeleteConfirmation(
  BuildContext context, {
  required RoleCard role,
}) async {
  final DestructiveConfirmation? confirmation =
      await showQtmsDestructiveSheet(
    context,
    title: 'حذف الدور',
    // ★ **يُسمّى الدور صراحةً** — ⟵ **فلا يُحذف غيرُ المقصود** بضغطةٍ على
    //   البطاقة الخطأ.
    impact: 'سيُحذف الدور «${role.name}» نهائياً ولا يمكن استرجاعه.',
    confirmLabel: 'حذف الدور',
    reasonLabel: 'سبب الحذف (اختياري)',
  );
  return confirmation?.reason;
}

/// ورقة نموذج الدور.
class RoleFormSheet extends ConsumerStatefulWidget {
  /// ينشئ الورقة.
  const RoleFormSheet({this.existing, super.key});
  /// الدور المُعدَّل — و`null` تعني إنشاءً.
  final RoleCard? existing;
  @override
  ConsumerState<RoleFormSheet> createState() => _RoleFormSheetState();
}


class _RoleFormSheetState extends ConsumerState<RoleFormSheet> {
  late final TextEditingController _name =
      TextEditingController(text: widget.existing?.name ?? '');
  late final TextEditingController _description =
      TextEditingController(text: widget.existing?.description ?? '');
  final TextEditingController _amendReason = TextEditingController();
  /// ★★ قالب الصلاحيات — `FR-M1-03`: «إنشاء دور **بقالب صلاحيات كامل**».
  late Set<Permission> _template = <Permission>{
    ...?widget.existing?.permissionTemplate,
  };
  CatalogMessage? _rejection;
  bool _submitting = false;
  bool get _isEdit => widget.existing != null;
  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _amendReason.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) => SafeArea(
        child: ConstrainedBox(
          // ★ **الورقة لا تبتلع الشاشة** — وشجرة الصلاحيات تمرّر داخلها،
          //   ⟵ **فيبقى ما تحتها ظاهراً** ولا يُحجَب سياق الشاشة الأم.
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: Padding(
            padding: const EdgeInsets.all(Spacing.space16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  _isEdit ? 'تعديل دور' : 'دور جديد',
                  style: TypeScale.titleLg,
                ),
                const SizedBox(height: Spacing.space16),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: <Widget>[
                      RoleField(
                        controller: _name,
                        label: 'اسم الدور',
                        autofocus: true,
                      ),
                      const SizedBox(height: Spacing.space12),
                      RoleField(
                        controller: _description,
                        label: 'الوصف (اختياري)',
                      ),
                      if (_isEdit) ...<Widget>[
                        const SizedBox(height: Spacing.space12),
                        // ★★ **حقل السبب في التعديل وحده** — ⛔ ولا «قبل»
                        //    قبل الإنشاء أصلاً.
                        //
                        // ⛔⛔★★★ **واختياريٌّ لا إلزامي** — `ADR-0020`:
                        //    ★ **ولا يُعطَّل زرُّ الحفظ لغيابه**، ⟵ **وما
                        //    تركه فارغاً يُرسَل غياباً** بـ`blankToNull`
                        //    ⛔ **لا نصّاً مُعبَّأً عنه.**
                        RoleField(
                          controller: _amendReason,
                          label: 'سبب التعديل (اختياري)',
                        ),
                      ],
                      const SizedBox(height: Spacing.space16),
                      // ★★ **قالب الصلاحيات كامل** — `FR-M1-03`.
                      //
                      // ⚠️⚠️ **ولا تُقيَّد الشجرة بصلاحيات المُنفِّذ هنا
                      //    عمداً — والفرق مقصود:** القالب **لا يمنح أحداً
                      //    شيئاً**، ★ **والمنح مسارُه `grantPermissions`**
                      //    وهو الذي يفرض `BR-M1-03` **على المانح لحظة
                      //    المنح**. ⟵ **فأخطرُ قالبٍ يبقى بلا أثر حتى
                      //    يطبّقه من يملك كل ما فيه أصلاً.**
                      PermissionTree(
                        selected: _template,
                        onChanged: (Set<Permission> next) =>
                            setState(() => _template = next),
                      ),
                    ],
                  ),
                ),
                if (_rejection case final CatalogMessage message) ...<Widget>[
                  const SizedBox(height: Spacing.space12),
                  RoleRejectionBanner(message: message),
                ],
                const SizedBox(height: Spacing.space16),
                FilledButton(
                  onPressed: _submitting ? null : _submit,
                  child: Text(_isEdit ? 'حفظ التعديل' : 'إنشاء'),
                ),
              ],
            ),
          ),
        ),
      );
  Future<void> _submit() async {
    // ★ **القواعد من طبقة النطاق المشتركة** — ⛔ ولا تُعاد كتابتها هنا.
    final Outcome<ValidatedRole> validated = validateRole(
      name: _name.text,
      description: _description.text,
      permissions: _template,
    );
    if (validated is Failure<ValidatedRole>) {
      // ⚠️ **رفضٌ محلي ⟵ ولا رحلة شبكة أصلاً.**
      setState(() => _rejection = CatalogMessage.operationFailed);
      return;
    }
    final ValidatedRole role = (validated as Success<ValidatedRole>).value;


    setState(() {
      _submitting = true;
      _rejection = null;
    });
    final RoleAdminRepository admin = ref.read(roleAdminProvider);
    final Outcome<void> result = _isEdit
        ? await admin.update(
            roleId: widget.existing!.roleId,
            role: role,
            amendReason: blankToNull(_amendReason.text),
          )
        : await admin.create(role);


    if (!mounted) return;
    switch (result) {
      case Failure<void>(:final AppError error):
        // ★ **الرفض يُعرَض ⛔ ولا يُبتلَع** — والورقة تبقى بمدخلاته.
        setState(() {
          _submitting = false;
          _rejection = appErrorMessage(error);
        });
      case Success<void>():
        Navigator.of(context).pop();
    }
  }
}

/// شريط الرفض — ★ **نصّه من الكتالوج حرفياً** ⛔ **ولا صياغة هنا.**
class RoleRejectionBanner extends StatelessWidget {
  /// ينشئ الشريط.
  const RoleRejectionBanner({required this.message, super.key});

  /// الرسالة المعروضة.
  final CatalogMessage message;

  @override
  Widget build(BuildContext context) => QtmsInlineBanner(
        text: catalogText(message),
        triad: SemanticTriads.danger,
      );
}

/// حقل نصّي بسيط — ★ **تركيز تلقائي على أول حقل** (نمط 4).
class RoleField extends StatelessWidget {
  /// ينشئ الحقل.
  const RoleField({
    required this.controller,
    required this.label,
    this.autofocus = false,
    super.key,
  });

  /// متحكّم النصّ.
  final TextEditingController controller;

  /// عنوان الحقل.
  final String label;

  /// هل يأخذ التركيز عند الفتح؟
  final bool autofocus;

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        autofocus: autofocus,
        decoration: InputDecoration(labelText: label),
      );
}

/// ★★★ **ورقة التأكيد المدمّرة الموحّدة** — `MASTER.md` §5b نمط `P6`
/// (`ADR-0021`).
///
/// ⛔⛔★★★ **وتستبدل أربع نسخٍ متباينة** (جرد 2026-08-27): `UserDisableSheet` ·
/// `RoleDeleteSheet` · `CancelIntakeSheet` · `CancelSackSheet` — ★ **ولا تتفق
/// اثنتان منها**: ⟵ **ورقتان بلا زرِّ تراجع البتّة**، ⛔ **والمخرجُ الوحيد
/// سحبٌ لأسفل** — ★ **إيماءةٌ غير معلَنة على فعلٍ لا رجعة فيه**، ⟵ **ومستخدمٌ
/// مستعجل في الميدان لا يخمّنها.**
///
/// ⛔⛔★★★ **وزرُّ التراجع يرسمه المكوّن بنفسه ولا يقبل إطفاءه** — ★ **قيدُ
/// `ADR-0021` ④ يُنفَّذ بالبنية لا بالمراجعة**: ⟵ **فلا يسقط سهواً كما سقط
/// مرتين.**
///
/// ⛔⛔★★★ **ولا يُعطَّل الزرُّ المدمّر لغياب السبب** (`ADR-0020`) — ★ **السببُ
/// اختياريٌّ في كل عملية**، ⟵ **وتعطيلُ الزرّ كان يمنع عمليةً صارت مشروعة.**
/// ★ **ويُعطَّل لغياب الحقل الإلزامي وحده** — **وهو ليس «سبب تعديل».**
///
/// ⛔⛔★★ **والحقل الإلزامي** ([QtmsDestructiveSheet.requiredFieldLabel])
/// **موضعُه ④** — ★ **وله اليومَ نظيران اثنان لا ثالثَ لهما**، **وهما
/// المستثنيان صراحةً من `ADR-0020`:** `balanceAcknowledgement` (`FR-M4-09`)
/// و`disableReason` (`FR-M1-12`). ⛔ **ولا يُقاس عليهما ثالثٌ بلا نصٍّ صريح.**
///
/// ⚠️★★ **وحقلُ السبب ⑤ يسقط حين لا تحمل العمليةُ سبباً أصلاً** — ★ **مقيسٌ
/// في التعطيل:** `disable({userId, reason})` **لا تقبل سبباً ثانياً**، ⟵ ⛔ **و
/// عرضُ حقلٍ تُهمَل قيمتُه أسوأ من غيابه**: **يكتب المستخدم تفسيراً يُرمى.**
///
/// ⛔⛔★★ **وعقدُ العودة متمايزٌ عمداً:** `null` = **تراجَع** · **كائنٌ ولو
/// بسببٍ فارغ** = **أكّد** — ⟵ **فلولا التمييز لصار «أكّد بلا سبب» يُقرأ
/// «تراجَع»**، ⛔ **وفعلٌ طلبه المستخدم لا يقع.**
///
/// ⚠️⚠️★★ **والورقة لا تنفّذ بنفسها** — ★ **ولا تملك مستودعاً ولا تعرف عمليةً**:
/// ⟵ **الشاشةُ المالكة للمستودع تنفّذ**، **وتمرّر تنفيذَها في
/// [QtmsDestructiveSheet.onConfirm]** حين تريد أن **يُعرَض الرفضُ داخل الورقة**
/// (الموضع ⑥) ⛔ **بدل أن تُغلَق على رفضٍ لا يراه أحد.** ★ **وحين تكون `null`
/// تكتفي الورقة بالعقد أعلاه** — **وهو حالُ ورقتَي التعطيل وحذف الدور.**
library;

import 'package:flutter/material.dart';

import '../design/design_tokens.dart';
import 'sticky_action_bar.dart';

/// ★★ نتيجةُ ورقة التأكيد.
@immutable
class DestructiveConfirmation {
  /// ينشئ النتيجة.
  const DestructiveConfirmation({this.reason, this.requiredValue});

  /// ★ السبب **(اختياري)** — ⛔ **وقد يكون فارغاً أو `null`** (`ADR-0020`).
  ///
  /// ★★ **و`null` هنا تعني «لا حقلَ سببٍ في هذه العملية»** — ⛔ **لا «تركه
  /// المستخدم فارغاً»**: ★ **والثاني نصٌّ فارغ**، ⟵ **والمُرسِل يُسقِط
  /// كليهما بـ`blankToNull`.**
  final String? reason;

  /// ★ قيمةُ الحقل الإلزامي إن طلبته الورقة — و`null` حين لا تطلبه.
  ///
  /// ⛔ **ولا تكون فارغةً حين تُطلَب** — ★ **الزرّ نفسُه لا يُفعَّل قبلها.**
  final String? requiredValue;
}

/// ★★ منفّذُ الفعل — **يُرجِع نصَّ الرفض، و`null` نجاحاً**.
///
/// ⛔⛔ **ونصُّ الرفض من كتالوج الرسائل عند المُنادي** — ★ **لا صياغةَ في
/// `core/ui`**: ⟵ **فالطبقةُ هنا بلا نطاقٍ ولا كتالوج.**
typedef DestructiveExecutor = Future<String?> Function(
  DestructiveConfirmation confirmation,
);

/// ★★★ يفتح ورقة التأكيد — و`null` تعني **تراجُعاً**.
Future<DestructiveConfirmation?> showQtmsDestructiveSheet(
  BuildContext context, {
  required String title,
  required String impact,
  required String confirmLabel,
  String? reasonLabel = 'السبب (اختياري)',
  String? requiredFieldLabel,
  DestructiveExecutor? onConfirm,
}) =>
    showModalBottomSheet<DestructiveConfirmation>(
      context: context,
      isScrollControlled: true,
      backgroundColor: SemanticColors.surface,
      builder: (BuildContext sheetContext) => Padding(
        // ★ **الأزرار فوق لوحة المفاتيح** — §5b `P6` ①.
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: QtmsDestructiveSheet(
          title: title,
          impact: impact,
          confirmLabel: confirmLabel,
          reasonLabel: reasonLabel,
          requiredFieldLabel: requiredFieldLabel,
          onConfirm: onConfirm,
        ),
      ),
    );

/// ورقة التأكيد المدمّرة.
class QtmsDestructiveSheet extends StatefulWidget {
  /// ينشئ الورقة.
  const QtmsDestructiveSheet({
    required this.title,
    required this.impact,
    required this.confirmLabel,
    this.reasonLabel = 'السبب (اختياري)',
    this.requiredFieldLabel,
    this.onConfirm,
    super.key,
  });

  /// ★ عنوان الفعل بلفظه — «تعطيل المستخدم» · «إلغاء الجونية».
  final String title;

  /// ★★ **جملةُ الأثر تسمّي الهدف صراحةً** — ⛔ **لا ضمير ولا «هذا العنصر»**:
  /// ⟵ **فلا يُعطَّل غيرُ المقصود بضغطةٍ على البطاقة الخطأ.**
  final String impact;

  /// نصّ الزرّ المدمّر — ★ **لفظُ الفعل صريحاً** ⛔ **لا «تأكيد» مجرّدة.**
  final String confirmLabel;

  /// تسمية حقل السبب — ★ **وتحمل «(اختياري)»** (`ADR-0020`).
  ///
  /// ★★ **و`null` تُسقِط الحقلَ كلَّه** — ⛔ **لعمليةٍ لا تحمل سبباً أصلاً.**
  final String? reasonLabel;

  /// ★ تسميةُ الحقل الإلزامي — و`null` حين لا تطلبه العملية.
  ///
  /// ⛔⛔ **وهو ليس «سبب تعديل»** — ★ **`ADR-0020` §«ما لا يشمله»**، **وهو
  /// وحده ما يُعطِّل الزرّ حين يغيب.**
  final String? requiredFieldLabel;

  /// ★★ منفّذُ المُنادي — و`null` تعني **الاكتفاء بعقد العودة**.
  final DestructiveExecutor? onConfirm;

  @override
  State<QtmsDestructiveSheet> createState() => _QtmsDestructiveSheetState();
}

class _QtmsDestructiveSheetState extends State<QtmsDestructiveSheet> {
  final TextEditingController _reason = TextEditingController();
  final TextEditingController _required = TextEditingController();

  /// ★ الحقلُ الإلزامي حاضر؟ — ⛔ **والفراغات ليست قيمة.**
  bool _hasRequired = false;

  /// ★ نصُّ الرفض القادم من المنفّذ — الموضع ⑥.
  String? _rejection;

  /// ★ الفعلُ جارٍ — ⛔ **فلا نقرةٌ ثانية تُنفّذه مرتين.**
  bool _busy = false;

  bool get _needsRequired => widget.requiredFieldLabel != null;

  @override
  void initState() {
    super.initState();
    _required.addListener(
      () => setState(() => _hasRequired = _required.text.trim().isNotEmpty),
    );
  }

  @override
  void dispose() {
    _reason.dispose();
    _required.dispose();
    super.dispose();
  }

  DestructiveConfirmation get _confirmation => DestructiveConfirmation(
        reason: widget.reasonLabel == null ? null : _reason.text,
        requiredValue: _needsRequired ? _required.text.trim() : null,
      );

  Future<void> _confirm() async {
    final DestructiveExecutor? execute = widget.onConfirm;
    if (execute == null) {
      Navigator.of(context).pop(_confirmation);
      return;
    }

    final DestructiveConfirmation confirmation = _confirmation;
    setState(() {
      _busy = true;
      _rejection = null;
    });
    final String? rejection = await execute(confirmation);
    if (!mounted) return;
    if (rejection == null) {
      Navigator.of(context).pop(confirmation);
      return;
    }
    // ★★ **والرفضُ يُعرَض والورقةُ مفتوحة** — ⛔ **فلا يُبتلَع.**
    setState(() {
      _busy = false;
      _rejection = rejection;
    });
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: const EdgeInsetsDirectional.all(Spacing.screenPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // ② عنوان الفعل.
              Text(widget.title, style: TypeScale.titleLg),
              const SizedBox(height: Spacing.space12),
              // ③ ★★ جملةُ الأثر تسمّي الهدف.
              Text(
                widget.impact,
                style: TypeScale.bodyMd
                    .copyWith(color: SemanticColors.textSecondary),
              ),
              // ④ ★ الحقل الإلزامي — **قبل السبب ومفصولٌ عنه بصرياً.**
              //
              // ⟵ ⛔ **فلا يختلط إقرارُ المخاطرة بتفسير التغيير** — ★ **وهما
              //    حقلان بمعنيين قانونيين مختلفين تماماً.**
              if (widget.requiredFieldLabel case final String label) ...<Widget>[
                const SizedBox(height: Spacing.space16),
                const Divider(height: Sizes.borderWidth),
                const SizedBox(height: Spacing.space16),
                TextField(
                  controller: _required,
                  autofocus: true,
                  decoration: InputDecoration(labelText: label),
                ),
              ],
              // ⑤ حقل السبب **(اختياري)** — ⛔ **ويسقط حين لا تحمله العملية.**
              if (widget.reasonLabel case final String label) ...<Widget>[
                const SizedBox(height: Spacing.space16),
                TextField(
                  controller: _reason,
                  autofocus: !_needsRequired,
                  decoration: InputDecoration(labelText: label),
                ),
              ],
              // ⑥ لافتة الرفض.
              if (_rejection case final String message) ...<Widget>[
                const SizedBox(height: Spacing.space12),
                QtmsActionStatus.rejection(message),
              ],
              const SizedBox(height: Spacing.space16),
              // ⑦ ★★ الزرّ المدمّر — **بثلاثية `danger` وأيقونةٍ ولفظٍ صريح.**
              FilledButton.icon(
                // ⛔⛔★★★ **ولا يُعطَّل لغياب السبب** (`ADR-0020`) — ★ **ويُعطَّل
                //    لغياب الحقل الإلزامي وحده، وأثناء التنفيذ.**
                onPressed: _busy || (_needsRequired && !_hasRequired)
                    ? null
                    : _confirm,
                style: FilledButton.styleFrom(
                  backgroundColor: SemanticTriads.danger.ink,
                ),
                icon: const Icon(Icons.warning_amber_outlined),
                label: Text(widget.confirmLabel),
              ),
              const SizedBox(height: Spacing.space8),
              // ⑧ ⛔⛔★★★ **زرّ التراجع — إلزاميٌّ بلا استثناء.**
              //
              // ★ **يرسمه المكوّن ولا يقبل إطفاءه** — ⟵ **فلا يكون السحبُ
              //   لأسفل هو المخرجَ الوحيد** على فعلٍ لا رجعة فيه.
              TextButton(
                onPressed: _busy ? null : () => Navigator.of(context).pop(),
                child: const Text('تراجع'),
              ),
            ],
          ),
        ),
      );
}

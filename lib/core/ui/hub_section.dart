/// ★★★ **قسمُ الصدَفة ومدخلُه** — `MASTER.md` §5b نمط `P1` (`ADR-0021`).
///
/// ⛔⛔★★★ **والمشكلة التي يحلّها مقيسةٌ في جرد 2026-08-27:** ★ **ثلاثةَ عشرَ
/// مدخلاً في `HomeShell` بوزنٍ بصريٍّ واحد** (`OutlinedButton` لكلّها)
/// **مفصولةٍ بـ`SizedBox` أشقّاءَ بلا عناوين أقسام** — ⟵ **فلا هرمَ ولا
/// حدودَ مجموعات**: ★ **«سجل التدقيق» بنفس بروز «التوزيع».**
///
/// ⛔⛔★★★ **وعطلُ الفجوات المكدَّسة:** ★ **`PermissionGate` تُرجِع
/// `SizedBox.shrink`** ⟵ **والفاصلُ الشقيقُ لمدخلٍ مخفيّ يبقى ظاهراً**:
/// ⛔ **فمن لا يملك مفاتيح مجموعةٍ كاملة كان يرى فجواتٍ متتالية بلا سبب.**
/// ★ **والعلاج بنيوي: الفواصل داخل المكوّن لا أشقّاءَ له**، ⟵ **والقسمُ كلُّه
/// يختفي حين تختفي كلُّ مداخله.**
///
/// ⚠️⚠️ **وكل ما هنا عرضٌ لا حماية** — ★ **البوابةُ تلفّ كلَّ مدخلٍ من الشاشة**
/// (`PermissionGate`)، **والقراءةُ والكتابةُ محكومتان في القواعد والدالة**
/// (`RISK-02`). ⛔ **فلا يُكتفى بإخفاء مدخل.**
library;

import 'package:flutter/material.dart';

import '../design/design_tokens.dart';

/// ★★ مدخلٌ واحد في الصدَفة.
///
/// ★ **و[isPrimary] لمدخلٍ واحد في الشاشة كلها** — §7: ⛔ **زر إجراء رئيسي
/// واحد لكل شاشة**، ⟵ **وهو أكثرُ المداخل تكراراً في اليوم.**
@immutable
class QtmsHubEntry {
  /// ينشئ المدخل.
  const QtmsHubEntry({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.isPrimary = false,
  });

  /// النصّ — ⛔ **إلزاميٌّ**: §8 المحظور الثاني عشر (لا معنى بأيقونةٍ وحدها).
  final String label;

  /// الأيقونة.
  final IconData icon;

  /// عند النقر.
  final VoidCallback onPressed;

  /// ★ هل هو المدخل الأساسي؟ — ⛔ **واحدٌ لا أكثر.**
  final bool isPrimary;
}

/// ★★★ قسمٌ في الصدَفة — **عنوانٌ ثم مداخله**.
///
/// ⛔⛔★★★ **ويختفي كلُّه حين تختفي كلُّ مداخله** — ★ **فلا عنوانُ قسمٍ فارغ**
/// ⛔ **ولا فجوةٌ مكدَّسة** لمن لا يملك مفاتيحه.
class QtmsHubSection extends StatelessWidget {
  /// ينشئ القسم.
  const QtmsHubSection({
    required this.title,
    required this.children,
    super.key,
  });

  /// ★ عنوان القسم — ⟵ **فحدودُ المجموعة مقروءة** ⛔ **لا مستنتَجة من فراغ.**
  final String title;

  /// ★★ مداخلُ القسم **بعد البوابات** — ⟵ **فالقائمة هنا هي المرئيّ فعلاً.**
  ///
  /// ⛔ **وفارغةٌ تعني اختفاءَ القسم كلِّه.**
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return Padding(
      // ★ **والفاصلُ داخل المكوّن** — ⛔ **لا `SizedBox` شقيقاً له.**
      padding: const EdgeInsetsDirectional.only(bottom: Spacing.space24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: Spacing.space8),
            child: Text(
              title,
              style: TypeScale.label
                  .copyWith(color: SemanticColors.textSecondary),
            ),
          ),
          for (int i = 0; i < children.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(height: Spacing.space8),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// ★ زرُّ مدخلٍ مرسوم — **أساسيٌّ أو ثانوي**.
///
/// ★★ **والفرق هرمٌ لا زينة** — §7: ⟵ **فأكثرُ المداخل تكراراً يُرى أولاً.**
class QtmsHubButton extends StatelessWidget {
  /// ينشئ الزرّ.
  const QtmsHubButton({required this.entry, super.key});

  /// وصفُ المدخل.
  final QtmsHubEntry entry;

  @override
  Widget build(BuildContext context) => entry.isPrimary
      ? FilledButton.icon(
          onPressed: entry.onPressed,
          icon: Icon(entry.icon),
          label: Text(entry.label),
        )
      : OutlinedButton.icon(
          onPressed: entry.onPressed,
          icon: Icon(entry.icon),
          label: Text(entry.label),
        );
}

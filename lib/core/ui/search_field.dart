/// ★★★ **حقلُ البحث اللاصق** — `MASTER.md` §5 أرشيتايب «سرد» (`ADR-0021`).
///
/// ⛔⛔★★★ **وبندُ §5 كان بلا تطبيقٍ واحد** — ★ **«حقل بحث لاصق ← مرشِّحات
/// شرائح» موصوفٌ منذ اعتماد §5** ⟵ **وشاشةٌ واحدة بحثت فعلاً**
/// (`PermissionTree`) **بحقلٍ محليٍّ مكتوبٍ في موضعه**: ⛔ **فالنمطُ يُنصّ
/// ولا يُطبَّق** — ★ **وهذا المكوّن يجعله قابلاً للتطبيق.**
///
/// ⛔⛔★★★ **والقاعدة الأولى — لاصقٌ لا يمرّ مع النتائج** (§5): ★ **والمُنادي
/// هو من يضعه خارج الممرّ** — ⟵ **وحقلُ بحثٍ يمرّ مع القائمة يخرج من الشاشة
/// عند النتيجة العاشرة**، ⛔ **فيصفّي المستخدمُ ثم يفقد ما كتبه من عينه.**
///
/// ⛔⛔★★★ **والقاعدة الثانية — التطبيع من مصدره الواحد وحده** (`IQ-013`):
/// ★ **والمكوّن يُسلّم النصَّ خاماً كما كُتب** ⛔ **ولا يُطبِّع ولا يُقصّ** —
/// ⟵ **فالتطبيع قاعدةُ نطاقٍ لا شأنَ عرضٍ** (`ADR-0010` القاعدة 5)، ★ **وكلُّ
/// مُنادٍ يمرّره بـ`normalizeName`** ⛔ **لا بتطبيعٍ محليٍّ** يجعل «الإدخال»
/// لا يطابق «الادخال».
///
/// ★★ **والقاعدة الثالثة — زرُّ المسح يظهر بالنصّ ويغيب بغيابه**: ⟵ **ومسحُ
/// بحثٍ بالتراجع حرفاً حرفاً ثمنٌ يدفعه المستخدم في كل مرة**، ⛔ **وزرٌّ
/// حاضرٌ على حقلٍ فارغ زينةٌ لا تفعل شيئاً.**
library;

import 'package:flutter/material.dart';

import '../design/design_tokens.dart';

/// ★★★ حقلُ البحث اللاصق.
class QtmsSearchField extends StatelessWidget {
  /// ينشئ الحقل.
  const QtmsSearchField({
    required this.controller,
    required this.label,
    super.key,
  });

  /// ★ متحكّمُ النصّ — **والمُنادي يملكه ويتخلّص منه.**
  ///
  /// ⚠️ **ويستمع إليه المُنادي بنفسه** — ★ **فالتصفية قرارُه لا قرارُ الحقل.**
  final TextEditingController controller;

  /// ★ نصُّ الحقل — **«بحث في الصلاحيات»** ⛔ **بلا مصطلح تقني** (§6).
  final String label;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (BuildContext context, TextEditingValue value, Widget? _) =>
            TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: const Icon(Icons.search),
            // ★★ **زرُّ المسح بالنصّ وحده** — ⛔ **ولا زرَّ على حقلٍ فارغ.**
            suffixIcon: switch (value.text.isEmpty) {
              true => null,
              false => IconButton(
                  onPressed: controller.clear,
                  icon: const Icon(Icons.close),
                  // ★ **وصفٌ دلالي** — §5 البند 3.
                  tooltip: 'مسح البحث',
                ),
            },
          ),
        ),
      );
}

/// ★★★ حالةُ «لا نتيجة للبحث» — §5: ⛔ **ولا قائمةٌ فارغة صامتة.**
///
/// ⛔⛔★★ **والنصُّ يُسمّي ما بُحث عنه** — ★ **«لا صلاحية بهذا الاسم»** —
/// ⟵ **و«لا نتائج» عاريةً تترك المستخدم لا يدري أبحثُه ضيّقٌ أم القائمةُ
/// خاوية.**
class QtmsNoMatch extends StatelessWidget {
  /// ينشئ الحالة.
  const QtmsNoMatch({required this.message, super.key});

  /// ★ النصُّ المُسمّي — ⛔ **لا «لا نتائج» عارية.**
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.all(Spacing.space16),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TypeScale.bodyMd.copyWith(color: SemanticColors.textSecondary),
        ),
      );
}

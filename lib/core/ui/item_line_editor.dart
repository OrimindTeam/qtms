/// ★★★ **محرِّر سطور الأنواع** — `AM-009` ④ · `design-system.md` §7.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **العطلُ الذي يعالجه — «القائمةُ الكاملة صفوفَ إدخال»:**
///
/// ★ **كانت ثلاثُ شاشاتٍ تعرض *كلَّ* أنواع المصدر صفوفَ إدخالٍ دفعةً واحدة**
/// (`counted_intake_screen` · `sack_intake_screen` · `distribution_screen`)
/// ⟵ **فبأربعين نوعاً يمرّ المستخدم أربعين صفّاً ليملأ ثلاثة**، ⛔ **والصفُّ
/// الفارغ لا يُميَّز عن صفرٍ مقصود**، ★ **وطولُ النموذج يتبع طولَ الكتالوج
/// لا حجمَ العملية.**
///
/// ✅ **والعلاج: صفٌّ واحدٌ يُنشأ بالطلب** — **حقلٌ منسدلٌ يُكتَب فيه فيُصفّي
/// القائمة**، ★ **ثم `+` لسطرٍ ثانٍ**: ⟵ **فطولُ النموذج = عددُ ما أدخله
/// المستخدم فعلاً.**
/// ═══════════════════════════════════════════════════════════════════════
///
/// ⛔⛔★★★ **و«لا سطران لنفس النوع» بنيويٌّ هنا لا فحصٌ عند الحفظ**
/// (`FR-M6-07` · `FR-M7-23` · `FR-M10-19`): ★ **الخياراتُ المعروضة لصفٍّ
/// تُسقِط ما اختاره إخوتُه**، ⟵ **فالتكرارُ غيرُ قابلٍ للتعبير أصلاً.**
///
/// ⛔ **ولا يقرأ هذا المكوّن مزوّداً واحداً ولا يحسب شيئاً** — ★ **يستقبل
/// خياراتٍ جاهزةً بنصوصها** (`ADR-0010` القاعدة 5 · `ADR-0009`): ⟵ **فنصُّ
/// «(المتبقّي)» يُبنى في طبقة الشاشة** ⛔ **لا هنا.**
library;

import 'package:flutter/material.dart';

import '../design/design_tokens.dart';

/// ★★ خيارُ نوعٍ واحد في القائمة المنسدلة.
///
/// ★★ **و[label] نصٌّ جاهز** — ⟵ **«عوارض (80 حبة)»** (`FR-M10-06`):
/// ⛔ **والمكوّن لا يبني هذا النصّ ولا يقرأ رصيداً.**
@immutable
class QtmsItemOption {
  /// ينشئ الخيار.
  const QtmsItemOption({required this.id, required this.label});

  /// معرّف النوع — ★ **وهو ما يُعاد في `onSelected`.**
  final String id;

  /// ★ النصُّ المعروض — ⛔ **بلا مصطلح تقني** (`ui-guidelines.md` §6).
  final String label;

  @override
  bool operator ==(Object other) =>
      other is QtmsItemOption && other.id == id && other.label == label;

  @override
  int get hashCode => Object.hash(id, label);
}

/// ★★★ صفُّ سطرٍ واحد — **منسدلٌ يُكتَب فيه، ثم حقولُ الصفّ، ثم زرُّ الحذف.**
///
/// ⛔⛔★★ **والمنسدلُ [DropdownMenu] لا [DropdownButtonFormField]:** ★ **وهو
/// وحده يقبل الكتابة فيُصفّي القائمة** (`enableFilter`) — ⟵ **وهو نصُّ الطلب
/// حرفياً**، ⛔ **و`DropdownButtonFormField` لا يقبل حرفاً واحداً.**
class QtmsItemLineRow extends StatelessWidget {
  /// ينشئ الصفّ.
  const QtmsItemLineRow({
    required this.options,
    required this.selectedId,
    required this.onSelected,
    required this.onRemove,
    this.label = 'النوع',
    this.fields = const <Widget>[],
    super.key,
  });

  /// ★★ الخيارات المتاحة **لهذا الصفّ وحده** — ⛔ **بلا ما اختاره إخوتُه.**
  ///
  /// ⚠️ **ويُبقي المُنادي خيارَ الصفّ نفسِه فيها** — ⟵ **وإلا عُرض الحقلُ
  /// فارغاً بعد أن اختار المستخدم**، ⛔ **فيُقرأ فقداناً للمُدخَل.**
  final List<QtmsItemOption> options;

  /// النوع المختار — و`null` تعني **صفّاً لم يُختَر نوعُه بعد**.
  final String? selectedId;

  /// يُستدعى عند اختيار نوع.
  final ValueChanged<String> onSelected;

  /// ★ يُستدعى عند حذف الصفّ — ⛔ **حذفُ سطرٍ لم يُحفَظ لا حذفُ بيانات**
  /// (`GR-07` يخصّ المخزَّن لا المسوّدة).
  final VoidCallback onRemove;

  /// نصُّ الحقل المنسدل.
  final String label;

  /// ★ حقولُ الصفّ بعد المنسدل — **الكمية والسعر وما إليهما.**
  final List<Widget> fields;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.only(bottom: Spacing.space12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: _ItemDropdown(
                    options: options,
                    selectedId: selectedId,
                    onSelected: onSelected,
                    label: label,
                  ),
                ),
                const SizedBox(width: Spacing.space8),
                // ⛔ **وزرُّ الحذف بهدف لمسٍ كامل** — §8.
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(Icons.remove_circle_outline),
                  tooltip: 'حذف السطر',
                  color: SemanticTriads.danger.ink,
                  constraints: const BoxConstraints(
                    minWidth: Sizes.minTouch,
                    minHeight: Sizes.minTouch,
                  ),
                ),
              ],
            ),
            if (fields.isNotEmpty) ...<Widget>[
              const SizedBox(height: Spacing.space8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  for (final (int index, Widget field) in fields.indexed) ...[
                    if (index > 0) const SizedBox(width: Spacing.space8),
                    Expanded(child: field),
                  ],
                ],
              ),
            ],
          ],
        ),
      );
}

/// ★★★ المنسدلُ القابل للكتابة — **يُصفّي القائمة بما يُكتَب.**
class _ItemDropdown extends StatelessWidget {
  const _ItemDropdown({
    required this.options,
    required this.selectedId,
    required this.onSelected,
    required this.label,
  });

  final List<QtmsItemOption> options;
  final String? selectedId;
  final ValueChanged<String> onSelected;
  final String label;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) =>
            DropdownMenu<String>(
          // ⛔⛔★★★ **وعرضٌ محدودٌ صريح** — `DEBT-63`: ★ **[DropdownMenu]
          //    بلا `width` يطلب عرضَه من محتواه**، ⟵ **وابنٌ غيرُ مرنٍ
          //    في `Row` بعرضٍ غير محدود قيدٌ مستحيل** ⛔ **لا يُخطَّط.**
          width: constraints.maxWidth,
          initialSelection: selectedId,
          label: Text(label),
          // ★★★ **الكتابةُ تُصفّي** — ⟵ **وهو جوهرُ `AM-009` ④.**
          enableFilter: true,
          enableSearch: true,
          requestFocusOnTap: true,
          menuHeight: Sizes.listRowHeight * 4,
          onSelected: (String? value) {
            if (value != null) onSelected(value);
          },
          dropdownMenuEntries: <DropdownMenuEntry<String>>[
            for (final QtmsItemOption option in options)
              DropdownMenuEntry<String>(value: option.id, label: option.label),
          ],
        ),
      );
}

/// ★★★ زرُّ إضافة سطر — **`+` صريحٌ باسمه** ⛔ **لا أيقونةٌ عارية.**
///
/// ⛔⛔★★ **ويُعطَّل بلا خياراتٍ باقية** — ★ **ولا يُخفى**: ⟵ **زرٌّ يختفي
/// يُقرأ عطلاً في الشاشة**، ★ **وزرٌّ معطَّلٌ بنصٍّ يقول إن الكتالوج استُنفد.**
class QtmsAddLineButton extends StatelessWidget {
  /// ينشئ الزرّ.
  const QtmsAddLineButton({
    required this.onPressed,
    this.label = 'إضافة نوع',
    super.key,
  });

  /// ★ يُستدعى لإضافة صفٍّ فارغ — و`null` تعني **لا نوعَ متبقٍّ**.
  final VoidCallback? onPressed;

  /// نصُّ الزرّ.
  final String label;

  @override
  Widget build(BuildContext context) => Align(
        alignment: AlignmentDirectional.centerStart,
        child: OutlinedButton.icon(
          onPressed: onPressed,
          icon: const Icon(Icons.add),
          label: Text(label),
        ),
      );
}

/// ★★ يبني خيارات صفٍّ بعينه — **بإسقاط ما اختاره إخوتُه.**
///
/// ⛔⛔★★★ **وهو الحارسُ البنيوي لـ«لا سطران لنفس النوع»** — ⟵ **فالتكرارُ
/// لا يُفحَص عند الحفظ**، ★ **بل لا يمكن التعبير عنه أصلاً.**
List<QtmsItemOption> optionsForRow({
  required List<QtmsItemOption> all,
  required Iterable<String?> takenIds,
  required String? ownId,
}) {
  final Set<String> taken = <String>{
    for (final String? id in takenIds)
      if (id != null && id != ownId) id,
  };
  return <QtmsItemOption>[
    for (final QtmsItemOption option in all)
      if (!taken.contains(option.id)) option,
  ];
}

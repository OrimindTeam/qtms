/// ★★★ **شريطُ المرشِّحات وشريطُ الإجراء الجماعي** — `MASTER.md` §5b
/// نمطا `P4` و`P7` (`ADR-0021`).
///
/// ⛔⛔★★★ **والقاعدة الأولى — الإجراء الجماعي فوق الصفوف لا تحتها** (§5b `P4`
/// البند ③): ★ **«نسخ أسعار أمس» و«نسخ صلاحيات مستخدم» يملآن الحقول** —
/// ⟵ **وزرٌّ يملأ الحقول موضوعٌ بعدها يكتشفه المستخدم بعد أن عبّأ يدوياً**،
/// ⛔ **فيصير النسخُ إتلافاً لعملٍ تمّ لا اختصاراً له.**
///
/// ⛔⛔★★★ **والقاعدة الثانية — الحشوُ من المُنادي لا من المكوّن** (`padded`):
/// ★ **[QtmsFilterBar] يسكن تارةً داخل `QtmsContextHeader` وتارةً وحده** —
/// ⟵ **وحشوٌ مزدوج كان يُبعده عن حافّة الرأس** (`DailyPricingScreen`).
///
/// ⛔⛔★★★ **والقاعدة الثالثة — حارسُ `if (on)` هنا مرةً واحدة**: ★ **ثلاثةُ
/// مواضع كانت تكرّره حرفاً بحرف**، ⟵ **و`ChoiceChip` تنادي بـ`false` عند
/// إلغاء التحديد**: ⛔ **وموضعٌ يسقط فيه الحارسُ يمسح المرشِّح بلمسةٍ ثانية.**
///
/// ⚠️⚠️ **والمكوّنان بلا نطاقٍ ولا استعلام** — ★ **يستقبلان خياراتٍ محسوبة
/// ونصّاً جاهزاً**: ⛔ **ولا معادلة ولا عدٌّ هنا** (`ADR-0010` القاعدة 5 ·
/// `coding-standards.md` §2.2).
library;

import 'package:flutter/material.dart';

import '../design/design_tokens.dart';

/// ★★ خيارُ مرشِّحٍ واحد — **نصٌّ وحالةُ تحديدٍ وفعلُ اختيار.**
@immutable
class QtmsFilterOption {
  /// ينشئ الخيار.
  const QtmsFilterOption({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  /// ★ نصُّ الخيار — ⛔ **بلا مصطلح تقني** (`ui-guidelines.md` §6).
  final String label;

  /// هل هو المحدَّد حالياً.
  final bool selected;

  /// ★★ **يُنادى عند التحديد وحده** — ⛔ **ولا يُنادى عند إلغائه.**
  ///
  /// ⟵ **فالحارسُ في المكوّن** ⛔ **لا في كل مُنادٍ على حدة.**
  final VoidCallback onSelected;
}

/// ★★★ شريطُ المرشِّحات — **مجموعةٌ أو أكثر من الشرائح.**
///
/// ★ **ويصلح لصورتيه معاً:** **مجموعةٌ واحدة** (`DailyPricingScreen`)
/// **ومجموعتان** (`AuditLogScreen`: المصدر ثم البُعد الثانوي) —
/// ⟵ **و[groups] هي الفارق وحدها.**
class QtmsFilterBar extends StatelessWidget {
  /// ينشئ الشريط.
  const QtmsFilterBar({
    required this.groups,
    this.padded = true,
    super.key,
  }) : _notice = null;

  /// ★★ صورةُ «لا مرشِّح يُعرَض» — **نصٌّ يشرح السبب** ⛔ **لا فراغ.**
  ///
  /// ⚠️ **ونطاقٌ فارغ حالةٌ حقيقية لا عطل** (`E-35`) — ★ **مستخدمٌ بلا مصدر.**
  const QtmsFilterBar.notice({
    required String message,
    this.padded = true,
    super.key,
  })  : _notice = message,
        groups = const <List<QtmsFilterOption>>[];

  /// ★★ المجموعات — **كل مجموعةٍ صفُّ شرائحَ مستقل.**
  ///
  /// ⛔ **وبُعدٌ ثانويٌّ واحد فوق الأساسي لا اثنان** (§7).
  final List<List<QtmsFilterOption>> groups;

  /// ★★ هل يضع المكوّن حشوَ الشاشة بنفسه.
  ///
  /// ⛔ **و`false` حين يسكن داخل رأس السياق** — ⟵ **فالرأس يحشو.**
  final bool padded;

  final String? _notice;

  @override
  Widget build(BuildContext context) {
    final Widget content = switch (_notice) {
      final String message => Text(
          message,
          style: TypeScale.bodyMd.copyWith(color: SemanticColors.textSecondary),
        ),
      null => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final (int index, List<QtmsFilterOption> group)
                in groups.indexed) ...<Widget>[
              if (index > 0) const SizedBox(height: Spacing.space8),
              Wrap(
                spacing: Spacing.space8,
                runSpacing: Spacing.space8,
                children: <Widget>[
                  for (final QtmsFilterOption option in group)
                    ChoiceChip(
                      label: Text(option.label),
                      selected: option.selected,
                      // ★★★ **الحارسُ هنا مرةً واحدة** — ⛔ **لا في كل مُنادٍ.**
                      onSelected: (bool on) {
                        if (on) option.onSelected();
                      },
                    ),
                ],
              ),
            ],
          ],
        ),
    };

    if (!padded) return content;
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: Spacing.screenPadding,
        vertical: Spacing.space8,
      ),
      child: content,
    );
  }
}

/// ★★★ شريطُ الإجراء الجماعي — §5b `P4` البند ③.
///
/// ⛔⛔★★★ **وموضعُه فوق الصفوف** — ★ **والمُنادي هو من يضعه**، ⟵ **والمكوّن
/// يحمل الحدَّ السفلي الفاصل** ⛔ **فلا يلتبس بأوّل صفّ.**
///
/// ★★ **و[headline] هو «الملخّصُ الحيُّ للأثر»** الذي يفرضه §5 على نمط
/// الإدخال — ⟵ **«سُعِّر 3 من 12»**: ⛔ **وغيابُه يترك المستخدم يعدّ بعينه.**
class QtmsBulkActionBar extends StatelessWidget {
  /// ينشئ الشريط.
  const QtmsBulkActionBar({
    required this.headline,
    this.action,
    super.key,
  });

  /// ★★ العدّادُ الحيّ — **أرقامٌ لاتينية** (`AM-003`) ⛔ **بلا مصطلح تقني.**
  final String headline;

  /// ★ الإجراءُ الجماعي — و`null` تعني **عدّاداً بلا إجراء.**
  ///
  /// ⚠️ **ويُخفيه المُنادي إن كان لا يفعل شيئاً** — ⟵ **فزرٌّ عاطل أسوأ من
  /// غيابه**، ⛔ **ولا يُعرَض مُعطَّلاً بلا تفسير.**
  final Widget? action;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: const BoxDecoration(
          color: SemanticColors.surfaceSunken,
          border: BorderDirectional(
            bottom: BorderSide(
              color: SemanticColors.border,
              width: Sizes.borderWidth,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: Spacing.screenPadding,
            vertical: Spacing.space8,
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  headline,
                  style: TypeScale.bodyMd
                      .copyWith(color: SemanticColors.textSecondary),
                ),
              ),
              if (action case final Widget widget) widget,
            ],
          ),
        ),
      );
}

/// ★★★ **بطاقةُ «يحتاج إجراء»** — `design-system.md` §7 · `ui-guidelines.md`
/// §3 نمط 1 البند ⑤ (`AM-017` ③).
///
/// ⛔⛔★★★ **والمشكلة التي تحلّها مقيسةٌ في مراجعة 2026-09-06:** ★ **صفّان
/// متجاوران بترويستين وعدّادين منفصلين** — ⟵ **فلا جوابَ لسؤالٍ واحد: «هل
/// عليّ عملٌ اليوم أصلاً؟»**: ⛔ **يقرأ المستخدم عدّادين ويجمعهما ذهنياً.**
///
/// ★★ **والترويسةُ الموحّدة تحمل الجواب** — ⟵ **عدّادٌ إجماليٌّ واحد**،
/// ★ **وبنودُه تحته تفصيلٌ لا تكرار.**
///
/// ⛔⛔★★★ **ولا تُخفى عند الصفر أبداً** (`ui-guidelines.md` §3 نمط 1):
/// ★ **تُعرَض مطويّةً بأيقونةٍ هادئةٍ ونصٍّ صريح** — ⟵ **فاختفاؤها يجعل
/// المستخدم يشكّ: أهو صفرٌ أم عطل؟**
///
/// ★★★ **وهي مثبَّتةٌ أعلى اللوحة لا تُمرَّر معها** (`ui-guidelines.md` §3
/// نمط 1 القرار 9) — ⛔ **والتثبيتُ بنيويٌّ خارج مساحة التمرير**، ⛔ **لا
/// بعنوانٍ لاصقٍ يعيد رسم نفسه.**
///
/// ⚠️ **وكلُّ ما هنا عرضٌ** (§5.1): ★ **العدّاداتُ تصل محسوبةً من مزوّداتها**
/// ⛔ **ولا يستعلم المكوّن ولا يجمع بياناتٍ من مصدر.**
library;

import 'package:flutter/material.dart';

import '../design/design_tokens.dart';
import 'status_pill.dart';

/// بطاقةُ «يحتاج إجراء» — ترويسةٌ موحّدة وبنودٌ مُدمَجة.
class QtmsNeedsActionCard extends StatefulWidget {
  /// ينشئ البطاقة.
  const QtmsNeedsActionCard({
    required this.total,
    required this.rows,
    this.isTotalKnown = true,
    super.key,
  });

  /// ★ **مجموعُ بنودها** — ⛔ **ولا يُحسَب هنا**: ★ **يصل جاهزاً** (§5.1).
  final int total;

  /// ★★ **هل اكتمل قياسُ الإجمالي؟** — ⛔ **وصفرٌ مؤقّتٌ أثناء التحميل يُقرأ
  /// عطلاً**: ⟵ **فيُعرَض «—» حتى يكتمل** (نمطُ `pendingEntriesCountProvider`).
  final bool isTotalKnown;

  /// ★ **بنودُها بعد بواباتها** — ⛔ **وبندٌ بلا صلاحيةٍ لا يصل أصلاً.**
  final List<Widget> rows;

  @override
  State<QtmsNeedsActionCard> createState() => _QtmsNeedsActionCardState();
}

class _QtmsNeedsActionCardState extends State<QtmsNeedsActionCard> {
  bool? _override;

  /// ★★ **مبسوطةٌ حين يوجد عملٌ ومطويّةٌ حين لا يوجد** — ★ **ما لم يقرّر
  /// المستخدمُ خلافَه بالنقر**: ⟵ **فقرارُه يعلو الافتراض.**
  bool get _isExpanded =>
      _override ?? (!widget.isTotalKnown || widget.total > 0);

  @override
  Widget build(BuildContext context) {
    // ⛔⛔★★★ **والهدوءُ يُقال بعد القياس لا قبله** — ★ **الحالةُ ثلاثيةٌ لا
    //    ثنائية:** ⟵ **«لم يكتمل القياس» ليست «لا شيء».**
    // ⚠️ **ورُصد على المحاكي في `AM-017`:** ★ **الترويسةُ قالت «لا شيء يحتاج
    //    إجراءً اليوم» وعدّادُها «—» وصفُّ التعديلات يعرض 19** — ⛔ **دعوى
    //    هدوءٍ فوق بندٍ يحمل عملاً**، ★ **وهي نفسُ قاعدةِ «لا صفرٌ مؤقّت».**
    final bool isQuiet = widget.isTotalKnown && widget.total == 0;
    final ColorTriad triad = switch ((widget.isTotalKnown, widget.total)) {
      (false, _) => SemanticTriads.neutral,
      (true, 0) => SemanticTriads.success,
      _ => SemanticTriads.warning,
    };

    return Material(
      color: SemanticColors.surface,
      borderRadius: BorderRadius.circular(Radii.card),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: SemanticColors.border,
            width: Sizes.borderWidth,
          ),
          borderRadius: BorderRadius.circular(Radii.card),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            InkWell(
              onTap: () => setState(() => _override = !_isExpanded),
              borderRadius: BorderRadius.circular(Radii.card),
              child: Semantics(
                button: true,
                label: switch ((widget.isTotalKnown, widget.total)) {
                  (false, _) => 'يحتاج إجراء — لم يكتمل القياس',
                  (true, 0) => 'لا شيء يحتاج إجراءً اليوم',
                  (true, final int n) => 'يحتاج إجراء — $n بنود',
                },
                child: Padding(
                  padding: const EdgeInsets.all(Spacing.cardPadding),
                  child: Row(
                    children: <Widget>[
                      IconBadgeBox(
                        icon: isQuiet
                            ? Icons.task_alt_outlined
                            : Icons.assignment_late_outlined,
                        triad: triad,
                        size: Sizes.avatarSm,
                      ),
                      const SizedBox(width: Spacing.space12),
                      Expanded(
                        child: Text(
                          isQuiet
                              ? 'لا شيء يحتاج إجراءً اليوم'
                              : 'يحتاج إجراء',
                          style: TypeScale.titleSm,
                        ),
                      ),
                      StatusPill(
                        label: switch ((widget.isTotalKnown, widget.total)) {
                          (false, _) => '—',
                          (true, 0) => 'لا شيء',
                          (true, final int n) => '$n بنود',
                        },
                        triad: triad,
                      ),
                      const SizedBox(width: Spacing.space8),
                      Icon(
                        _isExpanded
                            ? Icons.expand_less
                            : Icons.expand_more,
                        size: Sizes.iconMd,
                        color: SemanticColors.textTertiary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_isExpanded)
              for (final Widget row in widget.rows) ...<Widget>[
                const Divider(
                  height: Sizes.borderWidth,
                  thickness: Sizes.borderWidth,
                  color: SemanticColors.divider,
                ),
                row,
              ],
          ],
        ),
      ),
    );
  }
}

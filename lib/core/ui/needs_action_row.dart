/// ★★★ **صفُّ «يحتاج إجراء»** — `design-system.md` §7 (مكوّنات المجال).
///
/// ★ **عقدُه هناك حرفياً:** «**يُبنى فوق صف التنقّل** — ★ **حاويةُ أيقونةٍ
/// بعائلةِ حدّةِ الحالة + عنوان + وصفُ الوجهة + عدّادٌ جدولي بلون العائلة
/// نفسها**».
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **وصفر منطقٍ فيه** — §5.1: «**مكوّنات العرض لا تحسب ولا تجلب ولا
/// تقرّر**»: ⟵ **العدّاد يصل رقماً، والحدّةُ تصل ثلاثيةً جاهزة**، ⛔ **ولا
/// يقارن هذا الملف رقماً بحدٍّ ولا يشتقّ لوناً من قيمة.**
///
/// ★★ **والحالة الهادئة ليست إخفاءً** (`ui-guidelines.md` §3 نمط 1): ★ **«لا
/// يحتاج شيءٌ إجراءً» يُعرَض بأيقونةٍ هادئة** ⛔ **ولا تُخفى البطاقة** —
/// ⟵ **فاختفاءُ الصفّ يجعل المستخدم يشكّ: أهو صفرٌ أم عطل؟**
///
/// ⛔ **ولا لونَ وحده ينقل المعنى** (§8 المحظور الثاني عشر) — ★ **العنوان
/// والوصف والعدّاد نصوصٌ صريحة.**
/// ═══════════════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';

import '../design/design_tokens.dart';
import 'status_pill.dart';

/// صفُّ بندٍ يحتاج إجراءً — **عنوانٌ ووجهةٌ وعدّاد**.
class QtmsNeedsActionRow extends StatelessWidget {
  /// ينشئ الصف.
  const QtmsNeedsActionRow({
    required this.icon,
    required this.title,
    required this.destination,
    required this.count,
    required this.triad,
    required this.onTap,
    this.countLabel,
    super.key,
  });

  /// الأيقونة داخل حاويتها.
  final IconData icon;

  /// العنوان — ★ **ما الذي يحتاج إجراءً.**
  final String title;

  /// ★ **وصفُ الوجهة** — ⟵ **فالسهمُ وعدٌ، وهذا نصُّه.**
  final String destination;

  /// ★★ العدّاد — 🧮 **رقمٌ يصل جاهزاً** ⛔ **لا يُحسَب هنا.**
  final int count;

  /// ★ نصٌّ يحلّ محلّ الرقم حين لا يكون الرقم هو الرسالة (صفرٌ مثلاً).
  final String? countLabel;

  /// ★ ثلاثيةُ حدّة الحالة — **تصل جاهزةً** (§5.1).
  final ColorTriad triad;

  /// عند النقر.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // ★★ **`Material` يحمل اللون والشكل و`InkWell` بداخله** — ⛔ **ولا حاوية
    //    معتِمة فوق الحبر** (درسُ `EntityTile`: التموّج غير مرئي).
    return Material(
      color: SemanticColors.surface,
      borderRadius: BorderRadius.circular(Radii.card),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.card),
        child: Semantics(
          button: true,
          label: '$title — ${countLabel ?? '$count'} · $destination',
          child: Container(
            constraints: const BoxConstraints(minHeight: Sizes.tileMinHeight),
            padding: const EdgeInsets.all(Spacing.cardPadding),
            decoration: BoxDecoration(
              border: Border.all(
                color: SemanticColors.border,
                width: Sizes.borderWidth,
              ),
              borderRadius: BorderRadius.circular(Radii.card),
            ),
            child: Row(
              children: <Widget>[
                IconBadgeBox(icon: icon, triad: triad),
                const SizedBox(width: Spacing.space12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(title, style: TypeScale.titleSm),
                      const SizedBox(height: Spacing.space4),
                      Text(
                        destination,
                        style: TypeScale.bodyMd
                            .copyWith(color: SemanticColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: Spacing.space8),
                // ★★ **عدّادٌ جدولي بلون العائلة نفسها** — §7 نصّاً:
                //    ⟵ **فعمودُ الأرقام لا يهتزّ بين صفٍّ وآخر.**
                Text(
                  countLabel ?? '$count',
                  style: TypeScale.numeric.copyWith(color: triad.ink),
                ),
                const SizedBox(width: Spacing.space8),
                // ★ **والسهمُ هو الوعدُ بوجهة** — §6.و (صف التنقّل).
                //   ⛔ **ولا قيمةَ موضعية بيمين/يسار** — بوابة الاتجاه.
                const Icon(
                  Icons.chevron_left,
                  size: Sizes.iconMd,
                  color: SemanticColors.textTertiary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

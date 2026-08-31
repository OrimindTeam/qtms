/// ★★ الشريط التنبيهي داخل الشاشة — **مكوّنٌ واحد لكل غرضه**
/// (`design-system.md` §6.ز · §3 المبدأ الثالث).
///
/// ⚠️⚠️★★★ **ولماذا وُجد أصلاً** (`AM-007`): ★ **كان هذا الشريطُ منسوخاً
/// حرفياً في سبع شاشات** — ⟵ **وكلُّ نسخةٍ منها تستدعي الطبقةَ الأولية
/// مباشرةً** (`Primitives.dangerSoft` وأخواتها)، ⛔ **وهو ما تمنعه §1 من
/// `design-tokens.md` نصّاً**: «**الطبقة الأولية لا تُستدعى خارج ملف التوكنز
/// إطلاقاً**». ★ **والنسخُ نفسه محظورٌ في §8 المحظور الحادي عشر.**
///
/// ⛔⛔★★★ **والعقدُ يمرّر ثلاثيةً واحدة لا ثلاثةَ ألوان:** ★ **قاعدة §3.3
/// تمنع «مزج تعبئة من عائلة مع نص من عائلة أخرى»** — ⟵ **وتمريرُ ثلاث قيمٍ
/// منفصلة يجعل المخالفة سطراً عادياً لا يلفت المراجعة**، ★ **بينما تمريرُ
/// [ColorTriad] يجعلها مستحيلةً بلا تركيبٍ متعمَّد.**
library;

import 'package:flutter/material.dart';

import '../design/design_tokens.dart';

/// شريطٌ تنبيهيٌّ لحالةٍ قائمة داخل الشاشة.
///
/// ★ **لحالةٍ قائمة لا لحدثٍ عابر** (§6.ز) — ⟵ **والحدثُ العابر حبّةٌ عائمة
/// تُستدعى كحدث** ⛔ **لا عنصرٌ في الشجرة.**
class QtmsInlineBanner extends StatelessWidget {
  /// ينشئ الشريط.
  const QtmsInlineBanner({
    required this.text,
    required this.triad,
    super.key,
  });

  /// نصٌّ بشريٌّ جاهز — ⛔ **لا رمزُ خطأٍ تقني**
  /// (`ui-guidelines.md` §6: «لا مصطلح تقني في واجهة المستخدم»).
  final String text;

  /// ★ الثلاثيةُ اللونية للحالة — **تعبئةً وحدّاً ومقدّمةً من العائلة نفسها.**
  final ColorTriad triad;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(Spacing.space12),
        decoration: BoxDecoration(
          color: triad.soft,
          // ⛔ **حدٌّ بلا ظل** — §3.2: ⛔ **ممنوع ظلٌّ وحدٌّ معاً.**
          border: Border.all(
            color: triad.border,
            width: Sizes.borderWidth,
          ),
          borderRadius: BorderRadius.circular(Radii.card),
        ),
        child: Text(
          text,
          style: TypeScale.bodyMd.copyWith(color: triad.ink),
        ),
      );
}

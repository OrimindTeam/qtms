/// ★★★ **حبّة الحالة وحاوية الأيقونة** — `design-system.md` §6.أ و§6.د.
///
/// ⛔⛔★★★ **ومكوّنٌ واحد لا ستّ نسخ:** ★ **`design-system.md` §8 المحظور
/// الحادي عشر ينصّ «نسخُ مكوّن بدل إعادة استخدامه»**، ★ **و§5 البند 6 يفرض
/// «التنويع بـ`variant` داخل المكوّن ⛔ لا بنسخة محلية»**. ⟵ ⚠️⚠️ **وكانت
/// ستّ حبّاتٍ متطابقة البنية** (`CancelledBadge` · `AmendedBadge` ·
/// `DisabledBadge` · `SystemDefaultBadge` · شارة حالة الوزن · شارة السعر)
/// **تفترق عن بعضها عند أول تعديل** — ★ **وقد افترقت فعلاً في نصف القطر:**
/// كلُّها تستعمل `Radii.field` **وهي حبّة تستحق `Radii.pill`** (§7).
///
/// ⛔⛔★★★ **ولا لونَ وحده ينقل معنى** — §8 المحظور الثاني عشر: ★ **فالنصّ
/// إلزاميٌّ في العقد نفسه** (`label` مطلوب لا اختياري)، ⟵ **وحبّةٌ بلا نصّ
/// لا تُبنى أصلاً.**
library;

import 'package:flutter/material.dart';

import '../design/design_tokens.dart';

/// ★ حبّة حالة — **ثلاثيةٌ لونية واحدة + نصّ صريح**.
class StatusPill extends StatelessWidget {
  /// ينشئ الحبّة.
  const StatusPill({
    required this.label,
    required this.triad,
    this.icon,
    super.key,
  });

  /// ★ **النصّ الصريح** — ⛔ **إلزاميٌّ لا اختياري** (§6.د).
  final String label;

  /// ★ **الثلاثية اللونية** — تعبئة وحدّ ومقدّمة **من العائلة نفسها** (§3.3).
  final ColorTriad triad;

  /// ★ أيقونة اختيارية — **تعزيزٌ للمعنى** ⛔ **لا بديلٌ عن النصّ.**
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: Spacing.space8,
          vertical: Spacing.space4,
        ),
        decoration: BoxDecoration(
          color: triad.soft,
          border: Border.all(
            color: triad.border,
            width: Sizes.borderWidth,
          ),
          // ★ **حبّة** — §7: `radiusPill` ⛔ **لا نصف قطر الحقل.**
          borderRadius: BorderRadius.circular(Radii.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (icon case final IconData glyph) ...<Widget>[
              Icon(glyph, size: Sizes.iconSm, color: triad.ink),
              const SizedBox(width: Spacing.space4),
            ],
            // ⚠️ **والنصّ مرن** — ★ **فتكبيرُ الخط حتى `1.3×` لا يكسر الحبّة**
            //    (`ui-guidelines.md` §5) ⛔ **ولا يُقصّ النصّ.**
            Flexible(
              child: Text(
                label,
                style: TypeScale.label.copyWith(color: triad.ink),
              ),
            ),
          ],
        ),
      );
}

/// ★★ **حاوية الأيقونة** — `design-system.md` §6.أ.
///
/// ★ **تجسيد الثلاثية اللونية**: خلفية `soft` + أيقونة `ink` + `radiusMd`.
/// ⛔ **ولا أيقونة عارية في المستويات الرئيسية** — ★ **فالحاوية هي ما يجعل
/// الأيقونة تنتمي لمجموعةٍ بدل أن تطفو رمادية.**
class IconBadgeBox extends StatelessWidget {
  /// ينشئ الحاوية.
  const IconBadgeBox({
    required this.icon,
    required this.triad,
    this.size = Sizes.iconBox,
    super.key,
  });

  /// الأيقونة.
  final IconData icon;

  /// الثلاثية اللونية — ★ **تصنيفية للهوية أو دلالية للحكم** (§3.5).
  final ColorTriad triad;

  /// ★ المقاس — **36 / 48 / 56** (§6.أ).
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: triad.soft,
            borderRadius: BorderRadius.circular(Radii.field),
          ),
          child: Center(
            child: Icon(
              icon,
              // ★ الأيقونة نصف الحاوية تقريباً — ★ **نسبةٌ واحدة لكل المقاسات**
              //   ⟵ **فالبصريّات متسقة بين 36 و56 بلا جدول ثانٍ.**
              size: size <= Sizes.avatarSm ? Sizes.iconMd : Sizes.iconLg,
              color: triad.ink,
            ),
          ),
        ),
      );
}

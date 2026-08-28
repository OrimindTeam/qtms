/// ★★★ **بطاقة الكيان** — `design-system.md` §6.د: **«الأكثر استخداماً»**.
///
/// ⛔⛔★★★ **ومكوّنٌ واحد لا اثنان:** ★ **كانت `InventoryTile` و
/// `MasterDataTile` نسختين متطابقتين البنية** — ⟵ **وهو حرفياً ما يمنعه §8
/// المحظور الحادي عشر**، ★ **وقد افترقتا فعلاً:** ⟵ **إحداهما عولجت في
/// `DEBT-36` بالتفاف الشارات والأخرى بقيت بالعطل نفسه.**
///
/// ⛔⛔★★★ **وعطلٌ ثانٍ كان فيهما معاً — التموّج غير مرئي:**
/// `InkWell(child: Container(color: …))` ⟵ ★ **حبرُ `InkWell` يُرسَم على
/// `Material` الذي تحته**، ⛔ **والحاوية المعتِمة فوقه تحجبه تماماً** —
/// ⟵ **فالنقر على البطاقة كان بلا ردّ فعل بصري واحد.** ★ **والترتيب الصحيح:
/// `Material` يحمل اللون والشكل، و`InkWell` بداخله** ⟵ **فيُرسَم الحبر فوق
/// السطح ويُقصّ على الشكل نفسه.**
///
/// ★ **والبطاقات المتراصّة عمودياً `outlined`** — §6.أ: **الظل على كل بطاقة
/// في قائمة ضجيجٌ لا هرم.**
library;

import 'package:flutter/material.dart';

import '../design/design_tokens.dart';

/// بطاقة كيانٍ في قائمة.
class EntityTile extends StatelessWidget {
  /// ينشئ البطاقة.
  const EntityTile({
    required this.title,
    required this.subtitle,
    this.leading,
    this.trailing,
    this.badges = const <Widget>[],
    this.actions = const <Widget>[],
    this.onTap,
    this.semanticLabel,
    super.key,
  });

  /// العنوان.
  final String title;

  /// السطر الثانوي — ★ **واحدٌ لا أكثر** (§6.د).
  final String subtitle;

  /// المقدّمة — ★ **حاوية أيقونة أو صورة رمزية.**
  final Widget? leading;

  /// ★ **القيمة الطرفية الواحدة** — §6.د: ⛔ **ولا اثنتان.**
  final String? trailing;

  /// حبّات الحالة.
  final List<Widget> badges;

  /// ★ صفّ الإجراءات — **يُفصَل بخطٍّ شعري إن وُجد** (§6.د).
  final List<Widget> actions;

  /// عند النقر.
  final VoidCallback? onTap;

  /// ★★ **الوصف الدلالي** — §5 البند 3: **«وصف دلالي + هدف لمس ≥ 48»**.
  ///
  /// ⚠️ **وغيابُه يجعل قارئ الشاشة يقرأ العنوان والسطر الثانوي مفكَّكين**
  /// ⛔ **بلا أن يعرف أنهما بطاقةٌ واحدة قابلة للنقر.**
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final Widget info = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        if (leading case final Widget lead) ...<Widget>[
          lead,
          const SizedBox(width: Spacing.space12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(title, style: TypeScale.titleSm),
              const SizedBox(height: Spacing.space4),
              Text(
                subtitle,
                style: TypeScale.bodyMd
                    .copyWith(color: SemanticColors.textSecondary),
              ),
            ],
          ),
        ),
        if (trailing case final String value) ...<Widget>[
          const SizedBox(width: Spacing.space8),
          // ★★ **أرقامٌ جدولية** — §6.د: ⟵ **فعمودُ القيم لا يهتزّ بين
          //    بطاقةٍ وأخرى**، ★ **وهي المقارنة البصرية التي يعتمدها المالك.**
          Text(value, style: TypeScale.numeric),
        ],
      ],
    );

    final Widget content = Padding(
      padding: const EdgeInsets.all(Spacing.cardPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          info,
          // ⛔⛔★★★ **والشارات في سطرها لا في صفّ النصّ — `DEBT-36` واستكمالُه:**
          //    ★ **وضعُها في الصفّ يجعلها تنافس عمودَ النصّ على العرض نفسه**
          //    ⟵ **فإمّا انعصر النصّ حرفاً في كل سطر** (العطل الأصلي)
          //    **وإمّا انعصرت الشارةُ فانقسم رقمُها على سطرين** («ضائع 22.300
          //    / كجم») — ★ **وكلاهما رُصد على المحاكي.** ⟵ **والسطرُ المستقل
          //    يُنهي المنافسة أصلاً:** ⛔ **لا قسمةَ عرضٍ بين نصٍّ وحالة.**
          if (badges.isNotEmpty) ...<Widget>[
            const SizedBox(height: Spacing.space12),
            Wrap(
              spacing: Spacing.space8,
              runSpacing: Spacing.space8,
              children: badges,
            ),
          ],
          if (actions.isNotEmpty) ...<Widget>[
            const Padding(
              // ★ **إيقاعٌ غير متماثل عمداً** — ⟵ **الفاصلُ أقربُ لصفّ
              //   الإجراءات منه للنصّ**، ★ **فينتمي بصرياً لما يفصله عنه.**
              padding: EdgeInsetsDirectional.only(
                top: Spacing.space12,
                bottom: Spacing.space4,
              ),
              // ★ **فاصلٌ شعري قبل صفّ الإجراءات** — §6.د حرفياً.
              child: Divider(height: Sizes.borderWidth),
            ),
            // ★★ **وارتفاعُ الصفّ `minTouch` بالضبط** — ⟵ **فلا يتمدّد بحشو
            //   الأزرار الافتراضي**، ⛔ **ولا يهبط دون هدف اللمس.**
            SizedBox(
              height: Sizes.minTouch,
              child: Row(
                // ★ **الإجراءات عند نهاية الصفّ** — ⛔ **لا يمين/يسار.**
                mainAxisAlignment: MainAxisAlignment.end,
                children: actions,
              ),
            ),
          ],
        ],
      ),
    );

    return Semantics(
      // ★ **البطاقةُ عنصرٌ واحد لقارئ الشاشة** — ⟵ **يقرأ وصفها ثم يتيح نقرها.**
      label: semanticLabel ?? '$title. $subtitle',
      button: onTap != null,
      container: true,
      child: Material(
        // ★★ **السطح على `Material` نفسه** — ⟵ **فيُرسَم الحبر فوقه لا تحته.**
        color: SemanticColors.surface,
        // ⛔ **حدٌّ بلا ظل** — §6.أ: `outlined` للبطاقات المتراصّة.
        shape: RoundedRectangleBorder(
          side: const BorderSide(
            color: SemanticColors.border,
            width: Sizes.borderWidth,
          ),
          borderRadius: BorderRadius.circular(Radii.card),
        ),
        // ★ **القصّ على الشكل** — ⟵ **فالتموّج لا يتجاوز الزوايا المنحنية.**
        clipBehavior: Clip.antiAlias,
        child: onTap == null
            ? content
            : InkWell(
                onTap: onTap,
                // ★ **هدف اللمس من التوكنز** — §5 البند 3.
                child: ConstrainedBox(
                  constraints:
                      const BoxConstraints(minHeight: Sizes.tileMinHeight),
                  child: content,
                ),
              ),
      ),
    );
  }
}

/// ★ عنوان قسم — `design-system.md` §6.أ: **`titleMd` + `sectionGap` تلقائية**.
///
/// ⚠️ **ولماذا مكوّن لا سطر `Text`:** ★ **المسافة جزءٌ من العقد لا من الشاشة**
/// — ⟵ **وتركُها للشاشة يجعل كل قسمٍ يختار مسافته**، ⛔ **فتضيع إيقاعية
/// الشاشة التي تسأل عنها المراجعة البصرية (§7 السؤال الثالث).**
class SectionHeader extends StatelessWidget {
  /// ينشئ العنوان.
  const SectionHeader(this.title, {this.trailing, super.key});

  /// النصّ.
  final String title;

  /// عنصرٌ طرفي اختياري — **عدّاد أو زر «عرض الكل»**.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(
          top: Spacing.sectionGap,
          bottom: Spacing.space12,
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                title,
                style: TypeScale.titleMd
                    .copyWith(color: SemanticColors.textPrimary),
              ),
            ),
            if (trailing case final Widget widget) widget,
          ],
        ),
      );
}

/// ★★★ **قائمة بطاقات الكيان** — `ui-guidelines.md` نمط 2.
///
/// ⚠️⚠️ **ولماذا مكوّن لا `ListView` في كل شاشة:** ★ **ستُّ شاشات قوائم
/// كانت تكتب السقالة نفسها بيدها** — ⟵ **فافترقت فعلاً:** بعضُها يفصل
/// بـ`space8` وبعضُها بـ`space12`، ⛔ **والمعتمَد `cardGap` وحده** (§6).
/// ★ **وسؤالُ المراجعة الثالث يسأل حرفياً «هل المسافات متساوية بين العناصر
/// المتشابهة؟»** — ⟵ **وإجابتُه لا تُضمَن بستّ نسخ.**
///
/// ⛔⛔★★★ **ومسافةُ أمان الزر العائم تُضاف هنا** — `design-tokens.md` §6
/// (`fabSafeBottom`) و§6.أ («**يضيف `fabSafeBottom` تلقائياً**»): ⟵ **وكانت
/// غائبةً عن كل قائمة**، ★ **فآخرُ بطاقةٍ تختفي خلف الزر متى طالت القائمة.**
///
/// ★ **وسحبُ التحديث من عقد النمط 2** — ⟵ **يُمرَّر [onRefresh] متى ملكت
/// الشاشة وسيلةَ إعادة الجلب**، ⛔ **ولا يُخترَع سلوكٌ بلا مصدر بيانات.**
class EntityList extends StatelessWidget {
  /// ينشئ القائمة.
  const EntityList({
    required this.itemCount,
    required this.itemBuilder,
    this.onRefresh,
    this.hasFloatingAction = true,
    super.key,
  });

  /// عدد العناصر.
  final int itemCount;

  /// باني العنصر.
  final Widget Function(BuildContext context, int index) itemBuilder;

  /// ★ سحبٌ للتحديث — `null` تعني أن الشاشة لا تملك إعادة جلبٍ صريحة.
  final Future<void> Function()? onRefresh;

  /// ★ هل في الشاشة زرٌّ عائم؟ ⟵ **فتُحجَز مسافةُ أمانه.**
  final bool hasFloatingAction;

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.sizeOf(context).width;
    final Widget list = ListView.separated(
      // ★★ **هامشٌ متجاوب** — `ui-guidelines.md` §5: **12 دون 360 · 24 فوق 600.**
      padding: EdgeInsetsDirectional.fromSTEB(
        Breakpoints.gutter(width),
        Spacing.screenPadding,
        Breakpoints.gutter(width),
        // ⛔ **ولا تختفي آخرُ بطاقةٍ خلف الزر العائم.**
        hasFloatingAction ? Spacing.fabSafeBottom : Spacing.screenPadding,
      ),
      itemCount: itemCount,
      separatorBuilder: (BuildContext _, int _) =>
          const SizedBox(height: Spacing.cardGap),
      itemBuilder: itemBuilder,
    );

    if (onRefresh case final Future<void> Function() refresh) {
      return RefreshIndicator(
        onRefresh: refresh,
        color: Primitives.primary500,
        backgroundColor: SemanticColors.surface,
        child: list,
      );
    }
    return list;
  }
}

/// ★★★ **بطاقة ضمار المالك** — العنصر المميِّز في التطبيق.
///
/// **العقد الكامل:** `docs/18-ux-ui/design-system.md` §7.1 ·
/// **المعادلات ومصادر البنود:** `docs/04-design/module-design/owner-ledger-summary-design.md`
/// §2 و§3 و§4 · **الشكل:** `docs/18-ux-ui/prototypes/home-dashboard-owner-ledger-v1.html`
/// (`DS-002` · `AM-007`).
///
/// ⚠️⚠️★★★ **وحدُّها معلَنٌ صريحاً: شكلٌ بلا بيانات.** ★ **الملخصاتُ تُبنى في
/// السحابة داخل `WU-016`** (**مخطَّطة**) — ⟵ **فهذا المكوّن مبنيٌّ كاملاً
/// بعقدِ بياناتٍ حقيقي**، ⛔ **ولا يُغذَّى بأرقامٍ وهمية في أي شاشة:**
/// ★ **عرضُ رقمٍ مالي مخترَع أخطرُ من غياب الشاشة كلِّها.**
///
/// ⛔⛔★★★ **وصفر حسابٍ هنا** (`design-system.md` §5.1): ★ **معادلاتُ البنود
/// العشرة تعيش في طبقة النطاق وتُبنى في السحابة** (`ADR-0008` · `ADR-0012`) —
/// ⟵ **ولو جمعت البطاقةُ بندين لتُخرِج ثالثاً، لعاشت المعادلةُ في موضعين**
/// ⛔ **واختلف حكمُها عن حكم الملخص في أول حالةٍ حدّية** (تقريبٌ · بندٌ مخفيٌّ
/// بصلاحية · يومٌ بلا حركة). ★ **ولذلك كلُّ حقلٍ في [OwnerLedgerSummaryView]
/// نصٌّ منسَّقٌ مسبقاً** ⛔ **لا عددٌ خام.**
library;

import 'package:flutter/material.dart';

import '../../../core/design/design_tokens.dart';
import '../../../core/design/theme_extensions.dart';

/// ★★ رمزُ العملية على يمين صف البند — **Σ للجمع، − للطرح، = للحصيلة.**
enum LedgerOp {
  /// إجمالي — مجموعُ ما قبله.
  sum,

  /// مطروح.
  minus,

  /// حصيلةٌ وسطية.
  equals,
}

/// ★★★ **عقد بطاقة ضمار المالك** — **كلُّ حقلٍ نصٌّ منسَّقٌ مسبقاً.**
///
/// ⛔⛔ **ولا `int` ولا `double` في هذا النوع إطلاقاً:** ★ **تنسيقُ المبالغ
/// قاعدةُ مجالٍ** (`ADR-0015`: **عددٌ صحيح بالريال بلا كسور**) ⟵ **ولو نسّقت
/// البطاقةُ بنفسها لصار للتنسيق موضعان.**
///
/// ★★ **والحقول المحكومةُ بصلاحيةٍ نوعُها `String?`** — ★ **و`null` تعني
/// «لا يُرسَم البند إطلاقاً»** ⛔ **لا صفراً**: ⟵ **الصفرُ معلومةٌ في هذا
/// النظام** (`owner-ledger-summary-design.md` §9: «**أصفارٌ صريحة لا شرطات،
/// لأن الصفر هنا معلومة**»)، ★ **و«يختفي كلياً» في §5 يعني غيابَ القيمة.**
@immutable
class OwnerLedgerSummaryView {
  /// ينشئ العقد.
  const OwnerLedgerSummaryView({
    required this.scopeLabel,
    required this.totalDebt,
    required this.credit,
    required this.cash,
    required this.settledOfDay,
    required this.discounts,
    required this.remainingBeforeDiscount,
    required this.remainingAfterDiscount,
    required this.tax,
    required this.remainingAfterTax,
    required this.netFinal,
    required this.currencyLabel,
    this.withdrawals,
    this.expenses,
    this.deltaLabel,
    this.deltaIsPositive = true,
    this.retroUpdatedAtLabel,
    this.isLive = true,
  });

  /// وصفُ نطاق المصدر — «كل المصادر» أو اسمُ مصدرٍ بعينه.
  final String scopeLabel;

  /// ① إجمالي الضمار = الآجل + النقدي.
  final String totalDebt;

  /// ①-أ منه آجل.
  final String credit;

  /// ①-ب منه نقدي.
  final String cash;

  /// ② الواصل — **المسدَّد من ضمارات هذا اليوم**.
  final String settledOfDay;

  /// ③ الخصومات — ★ **بندٌ مستقلٌّ عن الواصل ويُطرح من الضمار.**
  final String discounts;

  /// ④ باقي الضمار **قبل** الخصم — **حجمُ الذمة الأصلية.**
  final String remainingBeforeDiscount;

  /// ⑤ باقي الضمار **بعد** الخصم — ★ **الذمم المفتوحة الفعلية.**
  ///
  /// ⛔⛔★★★ **والصفّان (④) و(⑤) يُعرَضان معاً إلزاماً** — **قرار `OQ-001`
  /// (الخيار ج)**: ⟵ **المعادلةُ الحرفية تُنتج رقماً، والذمم المفتوحة فعلياً
  /// رقماً آخر، والفارقُ هو الخصمُ بالضبط.** ★ **وعرضُهما يُظهر المعنيين ولا
  /// يخلط أحدهما بالآخر.** ⚠️ **والنموذجُ المرجعي يعرض واحداً، وغلبَ المستند.**
  final String remainingAfterDiscount;

  /// ⑥ إجمالي الضريبة — ضرائبُ جواني هذا اليوم.
  final String tax;

  /// ⑦ الباقي بعد الخصم والضريبة.
  final String remainingAfterTax;

  /// ⑧ السحبيات — ★ **`null` لمن لا يملك «عرض سحبيات المالك».**
  final String? withdrawals;

  /// ⑨ الخرجيات — ★ **`null` لمن لا يملك «عرض الخرجيات».**
  final String? expenses;

  /// ⑩ الصافي النهائي — ★ **مبنيٌّ على «بعد الخصم»** (§4).
  final String netFinal;

  /// وحدةُ العملة — تظهر **مرةً واحدة** مع الرقم البطل ومع الرِباط.
  final String currencyLabel;

  /// تسميةُ الفرق عن أمس — ★ **جاهزةً نصّاً** ⛔ **لا محسوبةً هنا.**
  final String? deltaLabel;

  /// اتجاهُ الفرق — ★ **حكمٌ جاهز** ⛔ **لا مقارنةُ رقمين في العرض** (§5.1).
  final bool deltaIsPositive;

  /// تاريخُ إعادة البناء بأثر رجعي — ★ **منسَّقاً جاهزاً** (§7).
  final String? retroUpdatedAtLabel;

  /// هل الاتصالُ قائمٌ والبطاقةُ لحظية؟
  final bool isLive;
}

/// ★★★ بطاقة ضمار المالك — **البطاقةُ الرئيسية الوحيدة في شاشتها.**
class OwnerLedgerCard extends StatelessWidget {
  /// ينشئ البطاقة.
  const OwnerLedgerCard({
    required this.summary,
    this.onRowTap,
    this.onShare,
    super.key,
  });

  /// العقد.
  final OwnerLedgerSummaryView summary;

  /// ★ تفكيكُ بندٍ إلى حركاته — ★ **والسهمُ هو الوعدُ به** (§7.1 القاعدة 5).
  final void Function(String rowLabel)? onRowTap;

  /// مشاركةُ ملخص اليوم.
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    final QtmsHeroColors hero = context.hero;

    return Container(
      decoration: BoxDecoration(
        gradient: hero.surfaceGradient,
        // ⛔ **حدٌّ بلا ظلٍّ على العنصر نفسه؟ لا** — §3.2 يمنع الظلَّ والحدَّ
        //    معاً، ★ **والبطاقةُ الرئيسية `e2`** (§6.د) ⟵ **فالظلُّ وحده.**
        boxShadow: Elevation.e2,
        borderRadius: BorderRadius.circular(Radii.hero),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _Header(summary: summary, onShare: onShare),
          _HeroNumber(summary: summary),
          _Ledger(summary: summary, onRowTap: onRowTap),
          _Tie(summary: summary),
        ],
      ),
    );
  }
}

// ════════════════════════════ ① الترويسة ════════════════════════════

class _Header extends StatelessWidget {
  const _Header({required this.summary, required this.onShare});

  final OwnerLedgerSummaryView summary;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.only(
          start: Spacing.cardPadding,
          end: Spacing.cardPadding,
          top: Spacing.space16,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  // ★★ **العنوانُ وحده بخط العرض الثاني** — §5-أ.
                  //    ⛔ **ولا رقمَ به**: أرقامُه متغيّرةُ العرض وبلا `tnum`.
                  Text(
                    'ضمار المالك — اليوم',
                    style: TypeScale.displayTitleSm.copyWith(
                      color: SemanticColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: Spacing.space2),
                  Text(
                    summary.scopeLabel,
                    style: TypeScale.caption.copyWith(
                      color: SemanticColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            if (summary.retroUpdatedAtLabel case final String label)
              // ★ **وسمُ الأثر الرجعي بعائلة `info`** — §7.1 القاعدة 6.
              //   ⛔ **ولا لونٌ وحده**: ★ **الرمزُ والنصُّ معه** (§8 المحظور 12).
              _Tag(
                text: '⟳ $label',
                triad: SemanticTriads.info,
              )
            else if (summary.isLive)
              _Tag(text: 'لحظي', triad: SemanticTriads.success),
            if (onShare != null)
              IconButton(
                onPressed: onShare,
                icon: const Icon(Icons.ios_share_outlined,
                    size: Sizes.iconMd),
                tooltip: 'مشاركة ملخص اليوم',
              ),
          ],
        ),
      );
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.triad});

  final String text;
  final ColorTriad triad;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.space8,
          vertical: Spacing.space4,
        ),
        decoration: BoxDecoration(
          color: triad.soft,
          border: Border.all(color: triad.border, width: Sizes.borderWidth),
          // ⚠️ ★ **وهذه ليست حبّةَ حالة** — ★ **وسمُ سياقٍ داخل بطاقةٍ واحدة**
          //    ⟵ **فنصفُ قطرها `field` لا `pill`**، ⛔ **ولا تُلتبس بالمكوّن
          //    المشترك الذي تحرسه بوابةُ الحِرفية البصرية.**
          borderRadius: BorderRadius.circular(Radii.field),
        ),
        child: Text(
          text,
          style: TypeScale.caption.copyWith(color: triad.ink),
        ),
      );
}

// ═══════════════════════ ② الرقم البطل والدلتا ═══════════════════════

class _HeroNumber extends StatelessWidget {
  const _HeroNumber({required this.summary});

  final OwnerLedgerSummaryView summary;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.only(
          start: Spacing.cardPadding,
          end: Spacing.cardPadding,
          top: Spacing.space12,
          bottom: Spacing.space16,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    'الصافي النهائي',
                    style: TypeScale.caption.copyWith(
                      color: SemanticColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: Spacing.space4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      // ⛔⛔★★★ **الرقمُ البطل بخط الجسم لا بخط العرض** —
                      //    ★ **`Tajawal` بلا `tnum` وأرقامُه متغيّرةُ العرض**
                      //    ⟵ **فعمودُ الرقم يرتجّ عند كل تحديثٍ لحظي**
                      //    (`design-tokens.md` §5-أ). ⚠️ **ويخالف هذا
                      //    النموذجَ المرجعي، وغلبَ القيدُ التقني.**
                      Flexible(
                        child: Text(
                          summary.netFinal,
                          style: TypeScale.numericDisplay.copyWith(
                            color: SemanticColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: Spacing.space4),
                      Padding(
                        padding: const EdgeInsetsDirectional.only(
                          bottom: Spacing.space4,
                        ),
                        child: Text(
                          summary.currencyLabel,
                          style: TypeScale.label.copyWith(
                            color: SemanticColors.textTertiary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (summary.deltaLabel case final String label)
              _Tag(
                text: label,
                triad: summary.deltaIsPositive
                    ? SemanticTriads.success
                    : SemanticTriads.danger,
              ),
          ],
        ),
      );
}

// ═══════════════════════ ③ سلسلة الاشتقاق ═══════════════════════

class _Ledger extends StatelessWidget {
  const _Ledger({required this.summary, required this.onRowTap});

  final OwnerLedgerSummaryView summary;
  final void Function(String rowLabel)? onRowTap;

  @override
  Widget build(BuildContext context) {
    final OwnerLedgerSummaryView s = summary;

    return Padding(
      padding: const EdgeInsetsDirectional.only(
        start: Spacing.cardPadding,
        end: Spacing.cardPadding,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _Row(
            op: LedgerOp.sum,
            label: 'إجمالي الضمار',
            why: 'الآجل + النقدي',
            amount: s.totalDebt,
            onTap: onRowTap,
          ),
          _Split(credit: s.credit, cash: s.cash),
          _Row(
            op: LedgerOp.minus,
            label: 'الواصل',
            why: 'المسدَّد من ضمارات هذا اليوم',
            amount: s.settledOfDay,
            onTap: onRowTap,
          ),
          _Row(
            op: LedgerOp.minus,
            label: 'الخصومات',
            why: 'بند مستقل عن الواصل — يُطرح من الضمار',
            amount: s.discounts,
            onTap: onRowTap,
          ),
          // ⛔⛔★★★ **الصفّان معاً — `OQ-001` الخيار ج.**
          _Row(
            op: LedgerOp.equals,
            label: 'باقي الضمار قبل الخصم',
            why: 'حجم الذمة الأصلية',
            amount: s.remainingBeforeDiscount,
            isTotal: true,
          ),
          _Row(
            op: LedgerOp.equals,
            label: 'باقي الضمار بعد الخصم',
            why: 'الذمم المفتوحة الفعلية — وعليها يُبنى الصافي',
            amount: s.remainingAfterDiscount,
            isTotal: true,
          ),
          _Row(
            op: LedgerOp.minus,
            label: 'إجمالي الضريبة',
            why: 'ضرائب جواني اليوم',
            amount: s.tax,
            onTap: onRowTap,
          ),
          _Row(
            op: LedgerOp.equals,
            label: 'الباقي بعد الخصم والضريبة',
            amount: s.remainingAfterTax,
            isTotal: true,
          ),
          // ★★ **والبندان المحكومان بصلاحيةٍ لا يُرسَمان لمن لا يملكها** —
          //    §7.1 القاعدة 4: ⛔ **ولا يُترك مكانُهما فارغاً ولا معطّلاً.**
          if (s.withdrawals case final String amount)
            _Row(
              op: LedgerOp.minus,
              label: 'السحبيات',
              why: 'سحب المالك من هذا المصدر',
              amount: amount,
              isRestricted: true,
              onTap: onRowTap,
            ),
          if (s.expenses case final String amount)
            _Row(
              op: LedgerOp.minus,
              label: 'الخرجيات',
              why: 'مصروف تشغيلي وشُقى الشُقّات',
              amount: amount,
              onTap: onRowTap,
            ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.op,
    required this.label,
    required this.amount,
    this.why,
    this.isTotal = false,
    this.isRestricted = false,
    this.onTap,
  });

  final LedgerOp op;
  final String label;
  final String amount;
  final String? why;
  final bool isTotal;
  final bool isRestricted;
  final void Function(String rowLabel)? onTap;

  @override
  Widget build(BuildContext context) {
    final Widget content = Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.space8),
      child: Row(
        children: <Widget>[
          _OpBadge(op: op),
          const SizedBox(width: Spacing.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        label,
                        style: isTotal
                            ? TypeScale.titleSm.copyWith(
                                color: SemanticTriads.primary.ink,
                              )
                            : TypeScale.label.copyWith(
                                color: SemanticColors.textSecondary,
                              ),
                      ),
                    ),
                    if (isRestricted) ...<Widget>[
                      const SizedBox(width: Spacing.space4),
                      // ★ **وسمُ «بصلاحية» على البند المحكوم** — §7.1.
                      Icon(
                        Icons.lock_outline,
                        size: Sizes.iconSm,
                        color: SemanticColors.textTertiary,
                        semanticLabel: 'بند محكوم بصلاحية',
                      ),
                    ],
                  ],
                ),
                if (why case final String text) ...<Widget>[
                  const SizedBox(height: Spacing.space2),
                  Text(
                    text,
                    style: TypeScale.caption.copyWith(
                      color: SemanticColors.textTertiary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: Spacing.space8),
          Text(
            amount,
            style: isTotal
                ? TypeScale.numeric.copyWith(
                    color: SemanticTriads.primary.ink,
                    fontWeight: FontWeight.w700,
                  )
                : TypeScale.numeric.copyWith(
                    color: SemanticColors.textPrimary,
                  ),
          ),
          if (onTap != null) ...<Widget>[
            const SizedBox(width: Spacing.space4),
            Icon(
              Icons.chevron_left,
              size: Sizes.iconMd,
              color: SemanticColors.border,
            ),
          ],
        ],
      ),
    );

    return DecoratedBox(
      decoration: const BoxDecoration(
        border: BorderDirectional(
          bottom: BorderSide(
            color: SemanticColors.divider,
            width: Sizes.borderWidth,
          ),
        ),
      ),
      child: onTap == null
          ? content
          : InkWell(
              onTap: () => onTap!(label),
              // ★ **هدفُ لمسٍ كامل** — §5 البند 3.
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: Sizes.minTouch,
                ),
                child: content,
              ),
            ),
    );
  }
}

class _OpBadge extends StatelessWidget {
  const _OpBadge({required this.op});

  final LedgerOp op;

  @override
  Widget build(BuildContext context) {
    final (String glyph, ColorTriad triad) = switch (op) {
      LedgerOp.sum => ('\u03A3', SemanticTriads.neutral),
      LedgerOp.minus => ('\u2212', SemanticTriads.danger),
      LedgerOp.equals => ('=', SemanticTriads.primary),
    };

    return Container(
      width: Sizes.iconLg,
      height: Sizes.iconLg,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: triad.soft,
        border: Border.all(color: triad.border, width: Sizes.borderWidth),
        shape: BoxShape.circle,
      ),
      child: Text(
        glyph,
        // ⚠️ ★ **رمزٌ لا رقم** — ⟵ **فلا يخالف قاعدةَ الأرقام الجدولية**،
        //    ★ **ومخفيٌّ عن قارئ الشاشة لأن تسميةَ البند تحمل المعنى.**
        style: TypeScale.caption.copyWith(color: triad.ink),
      ),
    );
  }
}

class _Split extends StatelessWidget {
  const _Split({required this.credit, required this.cash});

  final String credit;
  final String cash;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(
          top: Spacing.space8,
          bottom: Spacing.space8,
        ),
        child: Row(
          children: <Widget>[
            _Pill(label: 'منه آجل', value: credit),
            const SizedBox(width: Spacing.space8),
            _Pill(label: 'منه نقدي', value: cash),
          ],
        ),
      );
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.space12,
          vertical: Spacing.space4,
        ),
        decoration: BoxDecoration(
          color: SemanticColors.surfaceSunken,
          border: Border.all(
            color: SemanticColors.border,
            width: Sizes.borderWidth,
          ),
          borderRadius: BorderRadius.circular(Radii.field),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              label,
              style: TypeScale.caption.copyWith(
                color: SemanticColors.textSecondary,
              ),
            ),
            const SizedBox(width: Spacing.space4),
            Text(
              value,
              style: TypeScale.numericSm.copyWith(
                color: SemanticTriads.primary.ink,
              ),
            ),
          ],
        ),
      );
}

// ═══════════════════════════ ④ الرِباط ═══════════════════════════

/// ★★★ الرِباط — **الموضعُ الداكن الوحيد في الشاشة** (`design-tokens.md` §4).
///
/// ★ **شكلُه من الشعار:** ★ **سطورُ البطاقة تنتهي إلى شريطٍ واحد كما تنتهي
/// سيقانُ الحزمة إلى رباطها** — ⟵ **فهو التوقيعُ البصري للتطبيق.**
class _Tie extends StatelessWidget {
  const _Tie({required this.summary});

  final OwnerLedgerSummaryView summary;

  @override
  Widget build(BuildContext context) {
    final QtmsHeroColors hero = context.hero;

    return Padding(
      padding: const EdgeInsets.all(Spacing.space12),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.space16,
          vertical: Spacing.space12,
        ),
        decoration: BoxDecoration(
          gradient: hero.tieGradient,
          borderRadius: BorderRadius.circular(Radii.card),
        ),
        child: Row(
          children: <Widget>[
            Icon(
              Icons.account_balance_wallet_outlined,
              size: Sizes.iconLg,
              color: hero.onTieLabel,
            ),
            const SizedBox(width: Spacing.space12),
            Expanded(
              child: Text(
                'الصافي النهائي لليوم',
                style: TypeScale.label.copyWith(color: hero.onTieLabel),
              ),
            ),
            Text(
              summary.netFinal,
              style: TypeScale.numeric.copyWith(
                color: hero.onTie,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: Spacing.space4),
            Text(
              summary.currencyLabel,
              style: TypeScale.caption.copyWith(color: hero.onTieLabel),
            ),
          ],
        ),
      ),
    );
  }
}

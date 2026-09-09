/// ★★ **شريطُ النسبة** — `design-system.md` §6.د (`AM-017` ④).
///
/// ⛔⛔★★★ **والعطلُ الذي أنشأه مقيسٌ لا احتياط** (مراجعةُ تجربة الاستخدام ·
/// 2026-09-06): ★ **«أُودع 300,000» و«لم يُودع بعد 120,000» سطران نصّيان
/// متجاوران** — ⟵ **فالمستخدم يقرأ رقمين ويقارنهما ذهنياً في كل مرة**،
/// ⛔ **والسؤالُ الحقيقيّ نسبةٌ لا رقمان**: ★ **«أزال معظمُ المقبوض أم بقي؟».**
///
/// ⛔⛔★★★ **ولا يحمل اللونُ المعنى وحده** — §8 المحظور الثاني عشر: ★ **التسميتان
/// تحته تذكران الجزأين نصّاً وعدداً**، ⟵ **فلو أُزيل اللونُ كلُّه بقيت المعلومة.**
///
/// ⚠️ **وهذا عرضٌ محض** (`design-system.md` §5.1): ★ **الرقمان يصلان محسوبَين
/// من طبقة النطاق ومنسَّقَين بالمنسّق المركزي** (§6.ح) — ⛔ **ولا يبني هذا
/// المكوّن نصَّ مبلغٍ ولا يجمع ولا يطرح**: ★ **كلُّ ما يشتقّه كسرٌ هندسيٌّ
/// للرسم.**
library;

import 'package:flutter/material.dart';

import '../design/design_tokens.dart';

/// شريطٌ بجزأين وتسميتين.
class QtmsProportionBar extends StatelessWidget {
  /// ينشئ الشريط.
  const QtmsProportionBar({
    required this.startLabel,
    required this.endLabel,
    required this.part,
    required this.total,
    this.startTriad = SemanticTriads.primary,
    this.endTriad = SemanticTriads.neutral,
    super.key,
  });

  /// ★ تسميةُ الجزء الأول — **عند بداية السطر** (يمينه في RTL).
  final String startLabel;

  /// ★ تسميةُ الجزء الثاني — **عند نهاية السطر**.
  final String endLabel;

  /// ★ مقدارُ الجزء الأول — ⛔ **للرسم وحده لا للعرض.**
  final double part;

  /// ★ المجموع — ⛔ **وصفرُه يُرسَم شريطاً محايداً كاملاً لا يُخفى** (§هـ).
  final double total;

  /// ثلاثيةُ الجزء الأول.
  final ColorTriad startTriad;

  /// ثلاثيةُ الجزء الثاني.
  final ColorTriad endTriad;

  /// ★★ **الكسرُ مقصورٌ إلى \[0,1\]** — ⛔ **ولا يرمي عند تجاوزٍ ولا عند صفر.**
  double get fraction {
    if (!total.isFinite || total <= 0) return 0;
    final double raw = part / total;
    if (!raw.isFinite) return 0;
    return raw.clamp(0, 1).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final int startFlex = (fraction * 1000).round();
    final int endFlex = 1000 - startFlex;

    return Semantics(
      label: '$startLabel · $endLabel',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ClipRRect(
            // ⛔ **ونصفُ القطر `xs` لا `pill`** — ★ **بوابةُ §8 المحظور الحادي
            //    عشر تحجز `radiusPill` لحبّة الحالة وحدها**، ⟵ **والارتفاعُ 8
            //    يجعل `xs` طرفاً دائرياً تاماً بعد قصّ الرسّام.**
            borderRadius: BorderRadius.circular(Radii.xs),
            child: SizedBox(
              height: Sizes.proportionBarHeight,
              child: Row(
                children: <Widget>[
                  if (startFlex > 0)
                    Expanded(
                      flex: startFlex,
                      child: ColoredBox(color: startTriad.ink),
                    ),
                  if (endFlex > 0)
                    Expanded(
                      flex: endFlex,
                      child: ColoredBox(color: endTriad.border),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Spacing.space4),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  startLabel,
                  style: TypeScale.caption.copyWith(color: startTriad.ink),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: Spacing.space8),
              Expanded(
                child: Text(
                  endLabel,
                  style: TypeScale.caption
                      .copyWith(color: SemanticColors.textTertiary),
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

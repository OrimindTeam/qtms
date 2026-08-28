/// ★★★ **الميزان الحيّ الثابت** — `MASTER.md` §5b نمط `P5` (`ADR-0021`).
///
/// ⛔⛔★★★ **والقاعدة الأولى: لا يمرّ مع المحتوى أبداً** — ★ **عند السطر
/// الخامس يخرج `_WeightProgress` من الشاشة**: ⟵ **فيوازن المستخدم وزناً وهو
/// لا يرى المتبقّي** ⛔ **وهو جوهر `FR-M7-29` نفسِه.** ★ **ولهذا يُوضَع خارج
/// الممرّ لا داخله** — **والمكوّن هنا لا يمرّر نفسه.**
///
/// ⛔⛔★★★ **والقاعدة الثانية: لا يختفي عند الرفض إطلاقاً** — ★ **يعرض سببَ
/// الرفض مكانَ القيمة** (`DEBT-47`): ⟵ **واختفاؤه يترك المستخدم أمام فراغٍ
/// بلا رقمٍ ولا سبب**، ⛔ **فيقرأ الاختفاء عطلاً في الشاشة لا رفضاً لمُدخَله.**
///
/// ⛔⛔★★★ **والقاعدة الثالثة: الإجراء المشروط بالحالة داخل الميزان** — ★ **لا
/// تحت الزر الأساسي**: ⟵ **«تأكيد الوزن الضائع» يظهر ويختفي بحسب الحالة**،
/// ⛔ **فالزرُّ الأساسي يقفز تحت الإصبع**، **وإجراءٌ لا رجعة فيه يصير آخرَ ما
/// تلمسه اليد بعد الحفظ.** ★ **وموضعُه مُلحَقاً بالحالة التي أنتجته** —
/// ⟵ **فيُقرأ جواباً لا خياراً مجاوراً.**
///
/// ⚠️⚠️ **والمكوّن بلا نطاقٍ ولا حساب** — ★ **يستقبل نصوصاً ونسبةً محسوبة**:
/// ⛔ **ولا معادلة هنا** (`ADR-0010` القاعدة 5 · `coding-standards.md` §2.2).
library;

import 'package:flutter/material.dart';

import '../design/design_tokens.dart';
import 'status_pill.dart';

/// ★★ حالةُ الميزان — **نصٌّ وثلاثيةٌ لونية**.
///
/// ⛔ **والنصّ إلزاميٌّ** — §6.د: ★ **ولا معنى بلونٍ وحده.**
@immutable
class QtmsSummaryStatus {
  /// ينشئ الحالة.
  const QtmsSummaryStatus({
    required this.label,
    required this.triad,
    this.icon,
  });

  /// نصّ الحالة الصريح.
  final String label;

  /// الثلاثية اللونية.
  final ColorTriad triad;

  /// أيقونة اختيارية — ⛔ **تعزيزٌ لا بديل.**
  final IconData? icon;
}

/// ★★★ الميزان الحيّ.
///
/// ★ **ويصلح لصورتيه معاً:** **ميزانٌ بنسبةٍ وشريط تقدّم** (`SackLinesFormSheet`)
/// **وقيمةٌ محسوبةٌ بلا نسبة** (`SackHeaderFormSheet` · `DistributionScreen`) —
/// ⟵ **و[progress] هي الفارق وحدها.**
class QtmsLiveSummary extends StatelessWidget {
  /// ينشئ الميزان.
  const QtmsLiveSummary({
    required this.headline,
    this.details = const <String>[],
    this.emphasis,
    this.progress,
    this.status,
    this.rejection,
    this.conditionalAction,
    super.key,
  });

  /// ★★ السطر الأول — «فُسِّر س من ص» · «الوزن المطالب به: س كجم».
  ///
  /// ⛔ **ولا يختفي** — ★ **وحين يُرفَض المُدخَل يبقى ويظهر [rejection] معه.**
  final String headline;

  /// ★★ أسطرٌ إضافية بوزن [headline] نفسِه — ⛔ **ولا يُجمَع بعضُها ببعض.**
  ///
  /// ★ **يفرضها `P8` البند ⑦**: **إجماليّا الحبات والأوزان سطران مستقلّان**
  /// (`GR-19` · `FR-M10-15`) — ⛔ **ولا سطرَ ثالثٌ يجمعهما**، ⟵ **والمكوّن
  /// يرسمها كما تصله** ⛔ **ولا يحسب ولا يدمج** (`ADR-0010` القاعدة 5).
  final List<String> details;

  /// ★★ السطرُ المُبرَز — **قيمةُ الضمار في `P8`** بوزن `titleSm`.
  ///
  /// ⛔ **و`null` تعني غيابَه لا فراغَه** — ★ **فمن لا يملك `distributionPriceView`
  /// لا يُعرَض له سطرٌ خاوٍ** (`ت-12`).
  final String? emphasis;

  /// نسبةُ التقدّم `0..1` — و`null` تعني **ميزاناً بلا شريط**.
  final double? progress;

  /// حالةُ الميزان — و`null` تعني **بلا شارة**.
  final QtmsSummaryStatus? status;

  /// ★★★ سببُ الرفض الحيّ — ⛔ **يُعرَض ولا يُخفي الميزان** (`DEBT-47`).
  ///
  /// ⚠️ **وهو رفضُ الكتابة اللحظي لا رفضُ الحفظ** — ★ **ورفضُ الحفظ لافتةٌ
  /// في `QtmsStickyActionBar`**، ⟵ **وموضعان لأنهما حدثان مختلفان.**
  final String? rejection;

  /// ★★ الإجراءُ المشروط بالحالة — ⛔ **داخل الميزان لا تحت الزر الأساسي.**
  final Widget? conditionalAction;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsetsDirectional.all(Spacing.space12),
        decoration: BoxDecoration(
          color: SemanticColors.surfaceSunken,
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
            // ② السطر الأول — ⛔ **حاضرٌ في كل حال.**
            Text(headline, style: TypeScale.bodyMd),
            // ②ب ★★ **الأسطر المستقلّة** — ⛔ **بلا جمعٍ ولا سطرٍ ثالث** (`GR-19`).
            for (final String line in details)
              Text(line, style: TypeScale.bodyMd),
            // ②ج ★★ **السطر المُبرَز** — قيمةُ الضمار في `P8`.
            if (emphasis case final String value) ...<Widget>[
              const SizedBox(height: Spacing.space4),
              Text(value, style: TypeScale.titleSm),
            ],
            if (progress case final double value) ...<Widget>[
              const SizedBox(height: Spacing.space8),
              ClipRRect(
                borderRadius: BorderRadius.circular(Radii.field),
                child: LinearProgressIndicator(
                  // ⛔ **والقيمة مقيَّدة عند المُنادي** — ★ **والمكوّن لا يحسب.**
                  value: value,
                  minHeight: Spacing.space8,
                ),
              ),
            ],
            if (status case final QtmsSummaryStatus current) ...<Widget>[
              const SizedBox(height: Spacing.space8),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: StatusPill(
                  label: current.label,
                  triad: current.triad,
                  icon: current.icon,
                ),
              ),
            ],
            // ⑦ ★★★ سببُ الرفض — **مكانَ القيمة لا بدلاً من الميزان.**
            if (rejection case final String message) ...<Widget>[
              const SizedBox(height: Spacing.space8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(
                    Icons.error_outline,
                    size: Sizes.iconSm,
                    color: SemanticTriads.danger.ink,
                  ),
                  const SizedBox(width: Spacing.space4),
                  Expanded(
                    child: Text(
                      message,
                      style: TypeScale.label
                          .copyWith(color: SemanticTriads.danger.ink),
                    ),
                  ),
                ],
              ),
            ],
            // ③ ★★ الإجراء المشروط — **مُلحَقٌ بالحالة التي أنتجته.**
            if (conditionalAction case final Widget action) ...<Widget>[
              const SizedBox(height: Spacing.space8),
              action,
            ],
          ],
        ),
      );
}

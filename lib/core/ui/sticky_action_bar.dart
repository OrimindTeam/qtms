/// ★★★ **شريط الإجراء الثابت** — `MASTER.md` §5b: **`P2` · `P4` · `P5` · `P8`**
/// (`ADR-0021`).
///
/// ⛔⛔★★★ **والمشكلة التي يحلّها مقيسةٌ في أربع شاشات:** ★ **زرُّ الحفظ في
/// ذيل قائمةٍ طويلة** — ⟵ **شجرةُ 74 مفتاحاً في `PermissionsScreen`،
/// وعشراتُ الأنواع في `DailyPricingScreen`، وسطورُ التوزيع** — ★ **فبعد كل
/// تبديلٍ يمرّر المستخدم مسافةً كاملة ليحفظ**، ⛔ **وقد لا يجد الزرَّ أصلاً.**
///
/// ★★ **وثلاثة أشياء يجمعها الشريط في موضعٍ واحد ثابت** — §5b:
/// ① **الملخّص الحيّ** (اختياري — `P5` و`P8`) ·
/// ② **لافتة الحالة** (رفضٌ أو تحذيرٌ أو نجاح) ·
/// ③ **الزرّ الأساسي الواحد** (§7: ⛔ **زر إجراء رئيسي واحد لكل شاشة**).
///
/// ⛔⛔★★★ **ولافتةُ الحالة داخل الشريط لا فوقه في المحتوى الممرَّر** — ★ **وهو
/// عطلٌ قائمٌ اليوم في `DistributionScreen`:** ⟵ **اللافتةُ تظهر وتختفي
/// فيقفز الزرُّ تحت الإصبع** — ⛔ **على شاشةٍ تكتب ذمّةً على مقوت.**
/// ★ **وهنا الشريطُ كلُّه يعلو معاً** ⟵ **والزرُّ يبقى في موضعه من الأسفل.**
///
/// ⛔⛔★★ **والإجراء المدمّر لا يُوضَع فيه أبداً** — §5b `P8` ⑨: ★ **موضعُه
/// ذيلُ المحتوى الممرَّر** ⟵ **فلا يُلامَس سهواً بإصبعٍ تقصد الحفظ.**
///
/// ⚠️⚠️ **وكل ما هنا عرضٌ لا حماية** — ★ **والبوابةُ تُلفّ الزرَّ الأساسي من
/// الشاشة** (`PermissionGate`)، **والرفضُ الحقيقي في السحابة** (`RISK-02`).
library;

import 'package:flutter/material.dart';

import '../design/design_tokens.dart';

/// ★★★ شريط الإجراء الثابت أسفل الشاشة.
///
/// ★ **يُوضَع في `Scaffold.bottomNavigationBar`** ⟵ **فيبقى ثابتاً بلا أن
/// يحجب آخر عنصرٍ في القائمة**، ⛔ **بخلاف `Stack` الذي يغطّي المحتوى.**
class QtmsStickyActionBar extends StatelessWidget {
  /// ينشئ الشريط.
  const QtmsStickyActionBar({
    required this.primary,
    this.summary,
    this.status,
    super.key,
  });

  /// ★★ **الزرّ الأساسي الواحد** — §7: ⛔ **ولا زرّان أساسيان في شاشة.**
  final Widget primary;

  /// ★ الملخّص الحيّ — `P5` و`P8`: **يُعرَض فوق الزرّ مباشرةً**.
  ///
  /// ⟵ ★ **فالأثرُ مرئيٌّ لحظةَ الضغط** ⛔ **لا بعد تمريرٍ إلى أعلى.**
  final Widget? summary;

  /// ★ لافتة الحالة — **رفضٌ أو تحذيرٌ أو نجاح** ⛔ **و`null` تعني لا حالة.**
  final Widget? status;

  @override
  Widget build(BuildContext context) => Material(
        // ★ **سطحٌ يرفع الشريط عن المحتوى** — §6.أ: ⛔ **ولا ظلَّ مركّب** (§9).
        color: SemanticColors.surface,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(
                color: SemanticColors.border,
                width: Sizes.borderWidth,
              ),
            ),
          ),
          // ★★ **و`SafeArea` للأسفل وحده** — ⟵ **فلا يقع الزرُّ تحت شريط
          //    التنقّل** (§8)، ⛔ **ولا تُضاف حاشيةٌ علوية لا معنى لها هنا.**
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsetsDirectional.all(Spacing.screenPadding),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  // ① الملخّص الحيّ — `P5` · `P8`.
                  if (summary case final Widget live) ...<Widget>[
                    live,
                    const SizedBox(height: Spacing.space12),
                  ],
                  // ② ★★ **لافتة الحالة داخل الشريط** — ⛔ **لا فوقه في
                  //    المحتوى**: ⟵ **فلا يقفز الزرُّ عند ظهورها.**
                  if (status case final Widget state) ...<Widget>[
                    state,
                    const SizedBox(height: Spacing.space12),
                  ],
                  // ③ الزرّ الأساسي الواحد.
                  primary,
                ],
              ),
            ),
          ),
        ),
      );
}

/// ★★ **لافتة حالةٍ موحّدة للشريط** — **نجاحٌ أو تحذيرٌ أو رفض** (`AM-022`).
///
/// ⛔⛔★★ **ولا لونَ وحده ينقل المعنى** (§8 المحظور الثاني عشر) — ★ **الأيقونة
/// والنصّ معاً**، ⟵ **فمن لا يميّز الأخضر من الأحمر يقرأ الحالة.**
///
/// ⛔ **ولا صياغةَ نصٍّ هنا** — ★ **النصّ من كتالوج الرسائل** (§3 القاعدة 1).
class QtmsActionStatus extends StatelessWidget {
  /// ينشئ اللافتة.
  const QtmsActionStatus({
    required this.message,
    required this.triad,
    required this.icon,
    super.key,
  });

  /// ★ لافتة رفض — **بثلاثية `danger` وأيقونتها**.
  factory QtmsActionStatus.rejection(String message) => QtmsActionStatus(
        message: message,
        triad: SemanticTriads.danger,
        icon: Icons.error_outline,
      );

  /// ★★ لافتة تحذير — **بثلاثية `warning` وأيقونتها** (`AM-022`).
  ///
  /// ⛔⛔★★★ **ودرجةٌ ثالثةٌ لأن الحالةَ ثالثة فعلاً** — `design-system.md`
  /// §6-ز: ★ **«نجح الفعلُ ونتيجتُه ناقصة»** ⟵ **والتوزيعُ التلقائي في
  /// الخصومات هو الحالةُ المقيسة** (**مبلغٌ «لم يُوزَّع» لأنه يتجاوز ما على
  /// المقوت**): ⛔ **فليس فشلاً يُصبَغ `danger`**، ⛔ **ولا نجاحاً تامّاً
  /// يُصبَغ `success`.** ⟹ **وإجبارُ الشاشة على درجتين يُسقِط التمييز.**
  factory QtmsActionStatus.warning(String message) => QtmsActionStatus(
        message: message,
        triad: SemanticTriads.warning,
        icon: Icons.report_problem_outlined,
      );

  /// ★ لافتة نجاح — **بثلاثية `success` وأيقونتها**.
  ///
  /// ⛔⛔ **ولا «✅» إيموجي** (§9) — ★ **أيقونةٌ متجهية ترث اللون والمقاس**،
  /// ⟵ **بينما الإيموجي يتبع خطَّ الجهاز ولا يُلوَّن.**
  factory QtmsActionStatus.success(String message) => QtmsActionStatus(
        message: message,
        triad: SemanticTriads.success,
        icon: Icons.check_circle_outline,
      );

  /// النصّ — ★ **من الكتالوج** ⛔ **ولا صياغةَ هنا.**
  final String message;

  /// الثلاثية اللونية.
  final ColorTriad triad;

  /// الأيقونة — ⛔ **تعزيزٌ للنصّ لا بديلٌ عنه.**
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsetsDirectional.all(Spacing.space12),
        decoration: BoxDecoration(
          color: triad.soft,
          border: Border.all(color: triad.border, width: Sizes.borderWidth),
          borderRadius: BorderRadius.circular(Radii.card),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, size: Sizes.iconMd, color: triad.ink),
            const SizedBox(width: Spacing.space8),
            Expanded(
              child: Text(
                message,
                style: TypeScale.bodyMd.copyWith(color: triad.ink),
              ),
            ),
          ],
        ),
      );
}

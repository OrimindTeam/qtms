/// ★★★ **الهيكل العظمي** — `design-system.md` §هـ.
///
/// ⛔⛔★★★ **وهو «حالة التحميل الوحيدة المقبولة»** نصّاً — ★ **والعقد نفسه
/// يمنع صراحةً «مؤشّراً دوّاراً وسط الشاشة»**، ⟵ ⚠️⚠️ **وكان ذلك بالضبط ما
/// تفعله كلُّ شاشةٍ في التطبيق:** `Center(child: CircularProgressIndicator())`.
///
/// ★★ **ولماذا يهمّ فعلاً لا شكلاً:** ★ **المؤشّر الدوّار لا يحجز مساحة**،
/// ⟵ **فوصولُ البيانات يُقفِز التخطيط كلَّه دفعةً واحدة** — ★ **والهيكل
/// يحاكي شكل المحتوى القادم فيصل المحتوى إلى مكانه المحجوز بلا قفزة.**
/// ⛔ **ولا يُستعار هيكلُ شكلٍ لشكلٍ آخر** (§هـ نصّاً).
///
/// ★ **والوميض يحترم «تقليل الحركة»** — `design-tokens.md` §9: ⟵ **يُلغى
/// لا يُبطَّأ**، ★ **فيبقى الهيكل ساكناً مقروءاً بلا حركةٍ واحدة.**
library;

import 'package:flutter/material.dart';

import '../design/design_tokens.dart';

/// ★ مستطيلٌ هيكلي واحد — **لبنة كل هيكل**.
class SkeletonBox extends StatefulWidget {
  /// ينشئ اللبنة.
  const SkeletonBox({
    required this.height,
    this.width,
    this.radius = Radii.xs,
    super.key,
  });

  /// الارتفاع — ★ **يُشتقّ من ارتفاع النصّ الذي سيحلّ محلّه.**
  final double height;

  /// العرض — `null` تعني ملء المتاح.
  final double? width;

  /// نصف القطر.
  final double radius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Motion.shimmer,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ★★ **يُقرَّر عند كل تغيّر تبعيات** — ⟵ **فتبديلُ الإعداد أثناء التشغيل
    //    يوقف الوميض فوراً** ⛔ **لا عند إعادة تشغيل التطبيق.**
    if (Motion.reduced(context)) {
      _controller.stop();
      _controller.value = 0;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Widget box = SizedBox(
      width: widget.width,
      height: widget.height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: SemanticColors.skeleton,
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );

    // ⛔ **تقليلُ الحركة يُلغيه** — ★ **والهيكل يبقى ظاهراً بلونه القاعدي.**
    if (Motion.reduced(context)) {
      return box;
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) => ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (Rect bounds) => LinearGradient(
          begin: AlignmentDirectional.centerStart,
          end: AlignmentDirectional.centerEnd,
          colors: <Color>[
            SemanticColors.skeleton,
            SemanticColors.skeletonHighlight,
            SemanticColors.skeleton,
          ],
          // ★ **موجةٌ تعبر من البداية للنهاية** — ⛔ **بلا توهّج ولا نيون**
          //   (§8 المحظور الثامن): ★ **فرقُ الدرجتين بين `skeleton` و
          //   `skeletonHighlight` لطيفٌ بالتصميم.**
          stops: <double>[
            (_controller.value - 0.3).clamp(0.0, 1.0),
            _controller.value.clamp(0.0, 1.0),
            (_controller.value + 0.3).clamp(0.0, 1.0),
          ],
        // ★★ **والاتجاه يُمرَّر صراحةً** — ⟵ **`AlignmentDirectional` لا
        //    تُحلّ داخل مُظلِّلٍ بلا اتجاه**: ★ **فالمُظلِّل يرسم خارج شجرة
        //    التخطيط ولا يرث `Directionality` تلقائياً.**
        ).createShader(bounds, textDirection: Directionality.of(context)),
        child: child,
      ),
      child: box,
    );
  }
}

/// ★★ هيكل بطاقة كيان — ★ **يحاكي بطاقة الكيان شكلاً وارتفاعاً**.
///
/// ⛔ **ولا يُستعار لشكلٍ آخر** — §هـ: ★ **هيكلٌ لا يشبه ما يحلّ محلّه
/// يُنتج القفزة نفسها التي جاء ليمنعها.**
class SkeletonTile extends StatelessWidget {
  /// ينشئ الهيكل.
  const SkeletonTile({super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(Spacing.cardPadding),
        constraints: const BoxConstraints(minHeight: Sizes.tileMinHeight),
        decoration: BoxDecoration(
          color: SemanticColors.surface,
          border: Border.all(
            color: SemanticColors.border,
            width: Sizes.borderWidth,
          ),
          borderRadius: BorderRadius.circular(Radii.card),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // ★ سطر العنوان — **بعرضٍ نسبي كالعناوين الحقيقية**،
            //   ⛔ **ولا رقمَ عرضٍ محفور**: ★ **النسبة تصحّ على كل جهاز.**
            FractionallySizedBox(
              alignment: AlignmentDirectional.centerStart,
              widthFactor: 0.45,
              child: SkeletonBox(height: Sizes.iconMd),
            ),
            SizedBox(height: Spacing.space8),
            // ★ السطر الثانوي — أطولُ من العنوان كما في البطاقة الحقيقية.
            FractionallySizedBox(
              alignment: AlignmentDirectional.centerStart,
              widthFactor: 0.75,
              child: SkeletonBox(height: Sizes.iconSm),
            ),
          ],
        ),
      );
}

/// ★ قائمة هياكل — **حالة تحميل قائمةٍ كاملة**.
class SkeletonList extends StatelessWidget {
  /// ينشئ القائمة.
  const SkeletonList({this.count = 4, super.key});

  /// عدد الهياكل — ★ **ملءُ الطيّة تقريباً** ⛔ **لا صفحةٌ كاملة.**
  final int count;

  @override
  Widget build(BuildContext context) => ListView.separated(
        // ⛔ **ولا تمرير أثناء التحميل** — ★ **فلا شيء بعدُ يُمرَّر إليه.**
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(Spacing.screenPadding),
        itemCount: count,
        separatorBuilder: (BuildContext _, int _) =>
            const SizedBox(height: Spacing.cardGap),
        itemBuilder: (BuildContext _, int _) => const SkeletonTile(),
      );
}

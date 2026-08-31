/// امتدادات السمة — ★ **العائلات التصنيفية الخمس وطقم البطاقة الرئيسية**.
///
/// ⚠️⚠️ **ولماذا امتدادُ سمةٍ لا ثوابتُ ساكنة:** ★ **`design-tokens.md` §1
/// يفرض «القراءة عبر آلية الثيم لا عبر ثوابت ساكنة»** — ★ **فموضعُ التغيير
/// يبقى واحداً**، ⛔ **والثابت المحفور في شاشة يهرب من كل مراجعة.**
/// ★ **و`ColorScheme` لا تحمل هذين الطقمين** (خمس عائلات تصنيفية + تدرّج)،
/// ⟵ **فامتدادُ السمة هو المسار الرسمي لحملهما بلا اختراع قناة ثانية.**
///
/// ⛔⛔ **ولا وضعَ ثانٍ يُدعَم** (`AM-003`): ★ **`lerp` مُنفَّذة لأن العقد
/// يفرضها** ⛔ **ولا لأن هناك سمتين تُمزَجان.**
library;

import 'package:flutter/material.dart';

import 'design_tokens.dart';

/// ★★ **العائلات التصنيفية الخمس** — `design-system.md` §4.
///
/// ★ **الربط بالمجموعات الوظيفية ثابتٌ عبر التطبيق كله** — ⛔ **ولا يتغيّر
/// بين شاشة وأخرى**، ⟵ **ولذلك تُقرأ بأسمائها الوظيفية لا بأرقامها.**
@immutable
class QtmsCategoryColors extends ThemeExtension<QtmsCategoryColors> {
  /// ينشئ الطقم.
  const QtmsCategoryColors({
    required this.identity,
    required this.masterData,
    required this.inventory,
    required this.receivables,
    required this.cash,
  });

  /// ★ الطقم المعتمَد — §4 حرفياً.
  const QtmsCategoryColors.standard()
      : identity = const ColorTriad(
          soft: Primitives.cat1Soft,
          border: Primitives.cat1Base,
          ink: Primitives.cat1Ink,
        ),
        masterData = const ColorTriad(
          soft: Primitives.cat2Soft,
          border: Primitives.cat2Base,
          ink: Primitives.cat2Ink,
        ),
        inventory = const ColorTriad(
          soft: Primitives.cat3Soft,
          border: Primitives.cat3Base,
          ink: Primitives.cat3Ink,
        ),
        receivables = const ColorTriad(
          soft: Primitives.cat4Soft,
          border: Primitives.cat4Base,
          ink: Primitives.cat4Ink,
        ),
        cash = const ColorTriad(
          soft: Primitives.cat5Soft,
          border: Primitives.cat5Base,
          ink: Primitives.cat5Ink,
        );

  /// `cat1` — ★ **الهوية والصلاحيات**: المستخدمون والأدوار.
  final ColorTriad identity;

  /// `cat2` — ★ **بيانات التهيئة**: المصادر · الرعية · المقاوته · الأنواع.
  final ColorTriad masterData;

  /// `cat3` — ★ **المخزون**: الوارد · الجواني · التسعير · الجرد · الإتلاف.
  final ColorTriad inventory;

  /// `cat4` — ★ **التوزيع والذمم**: التوزيعات · الضمارات · القبض · الخصم.
  final ColorTriad receivables;

  /// `cat5` — ★ **النقد والمصروفات**: البيع النقدي · السحبيات · الخرجيات.
  final ColorTriad cash;

  @override
  QtmsCategoryColors copyWith({
    ColorTriad? identity,
    ColorTriad? masterData,
    ColorTriad? inventory,
    ColorTriad? receivables,
    ColorTriad? cash,
  }) =>
      QtmsCategoryColors(
        identity: identity ?? this.identity,
        masterData: masterData ?? this.masterData,
        inventory: inventory ?? this.inventory,
        receivables: receivables ?? this.receivables,
        cash: cash ?? this.cash,
      );

  // ⛔★ **ولا مزجَ فعلياً** — ★ **مجموعةُ قيمٍ واحدة** (`AM-003`): ⟵ **فالمزج
  //    بين طقمٍ ونفسه هو الطقم نفسه**، ⛔ **ولا نصفَ لونٍ تصنيفيٍّ يظهر لحظةً.**
  @override
  QtmsCategoryColors lerp(ThemeExtension<QtmsCategoryColors>? other, double t) =>
      this;
}

/// ★★★ **طقم البطاقة الرئيسية** — `design-tokens.md` §4.
///
/// ⚠️⚠️★★★ **مقلوبٌ بـ`AM-007` (`DS-002`): البطاقةُ سطحٌ فاتحٌ الآن لا داكن.**
/// ★ **جسمُها ورقيٌّ فاتح تُقرأ عليه بنودُ الاشتقاق**، ★ **والداكنُ انحصر في
/// شريطٍ واحد أسفلها — «الرِباط» — يحمل الحصيلة.**
///
/// ★ **والمبرّر وظيفيٌّ لا جمالي:** ★ **تسعةُ أرقامٍ على سطحٍ داكن تُقرأ
/// أثقلَ وتفقد الهرمية لأن كلَّ سطرٍ يصير بارزاً** — ★ **والحصيلةُ وحدها هي
/// ما يستحق البروز.** ★ **وشكلُه من الشعار: سطورُ البطاقة تنتهي إلى شريطٍ
/// واحد كما تنتهي سيقانُ الحزمة إلى رباطها.**
///
/// ⛔⛔ **وتدرّجاه الاثنان داخل البطاقة الرئيسية لا خارجها** — §8 المحظور
/// السابع قائمٌ كما هو، ★ **وحملُهما في امتداد السمة يجعل كلَّ مستعملٍ لهما
/// ظاهراً في مراجعةٍ واحدة.**
@immutable
class QtmsHeroColors extends ThemeExtension<QtmsHeroColors> {
  /// ينشئ الطقم.
  const QtmsHeroColors({
    required this.surfaceGradient,
    required this.tieGradient,
    required this.onTie,
    required this.successOnTie,
    required this.dangerOnTie,
    required this.labelOpacity,
  });

  /// ★ الطقم المعتمَد — §4 حرفياً.
  const QtmsHeroColors.standard()
      : surfaceGradient = const LinearGradient(
          // ★ **رأسيٌّ فاتح** — §4: جسمُ البطاقة من السطح النقي إلى ورقيٍّ خفيف.
          begin: AlignmentDirectional.topCenter,
          end: AlignmentDirectional.bottomCenter,
          colors: <Color>[SemanticColors.surface, Color(0xFFF7F6E9)],
        ),
        tieGradient = const LinearGradient(
          // ★ **قطريٌّ من أعلى-النهاية إلى أسفل-البداية** — §4 نصّاً.
          //   ⛔ **ولا `topRight`/`bottomLeft`**: بوابة الاتجاه ترفضهما،
          //   ★ **و`AlignmentDirectional` تنقل النيّة نفسها باتجاه RTL.**
          begin: AlignmentDirectional.topEnd,
          end: AlignmentDirectional.bottomStart,
          // ⛔⛔★★ **وطرفُه الفاتح `primary500` لا `primary400`** — ★ **شدٌّ
          //    مقصودٌ عن النموذج المرجعي للتباين لا للذوق:** ⟵ **النموذج
          //    ينتهي بالقوس الزيتوني والنصُّ الفاتح عليه 3.90:1** ⛔ **دون الحدّ.**
          colors: <Color>[Primitives.primary600, Primitives.primary500],
        ),
        onTie = const Color(0xFFF4F2DF),
        // ★ **ومؤشّرا الموجب والسالب أُفتحا** حتى بلغا 4.86 و4.75 على أسوأ
        //   طرفٍ من التدرّج — ✅ **مقيسان في بوابة التباين.**
        successOnTie = const Color(0xFFDCE9B0),
        dangerOnTie = const Color(0xFFF9DAD0),
        labelOpacity = 0.88;

  /// ★ تدرّجُ جسم البطاقة — **فاتح.**
  final Gradient surfaceGradient;

  /// ★★ تدرّجُ الرِباط — **الموضعُ الداكن الوحيد في الشاشة.**
  final Gradient tieGradient;

  /// ★ نصّ فاتح على الرِباط — ⛔ **قائمٌ بذاته لا مشتقٌّ من `textOnInverse`**:
  /// ★ **الأول يصف نصاً على تدرّج الرِباط، والثاني نصاً على `surfaceInverse`**
  /// — ★ **وخلطهما يجعل تغيير أحدهما يغيّر الآخر بلا قصد.**
  final Color onTie;

  /// مؤشّر موجب فوق الرِباط.
  final Color successOnTie;

  /// مؤشّر سالب فوق الرِباط.
  final Color dangerOnTie;

  /// ★★ **88٪ كحدّ أدنى — لا أقل** (§4).
  ///
  /// ⛔⛔ **ولا 78٪ بعد اليوم:** ★ **78٪ فوق طرف التدرّج الفاتح تُعطي 4.08:1**
  /// ⛔ **دون الحدّ** — ★ **و«لا أقل» في القاعدة يسمح بالشدّ لا بالتخفيف.**
  final double labelOpacity;

  /// ★ لون التسمية الثانوية فوق الرِباط — **بالشفافية المفروضة.**
  Color get onTieLabel => onTie.withValues(alpha: labelOpacity);

  @override
  QtmsHeroColors copyWith({
    Gradient? surfaceGradient,
    Gradient? tieGradient,
    Color? onTie,
    Color? successOnTie,
    Color? dangerOnTie,
    double? labelOpacity,
  }) =>
      QtmsHeroColors(
        surfaceGradient: surfaceGradient ?? this.surfaceGradient,
        tieGradient: tieGradient ?? this.tieGradient,
        onTie: onTie ?? this.onTie,
        successOnTie: successOnTie ?? this.successOnTie,
        dangerOnTie: dangerOnTie ?? this.dangerOnTie,
        labelOpacity: labelOpacity ?? this.labelOpacity,
      );

  @override
  QtmsHeroColors lerp(ThemeExtension<QtmsHeroColors>? other, double t) => this;
}

/// ★ قراءةُ الطقمين من السياق — ⛔ **ولا `Theme.of(context).extension<…>()!`
/// مكرَّرةً في كل شاشة.**
extension QtmsThemeAccess on BuildContext {
  /// العائلات التصنيفية الخمس.
  QtmsCategoryColors get categories =>
      Theme.of(this).extension<QtmsCategoryColors>() ??
      const QtmsCategoryColors.standard();

  /// طقم البطاقة الرئيسية.
  QtmsHeroColors get hero =>
      Theme.of(this).extension<QtmsHeroColors>() ??
      const QtmsHeroColors.standard();
}

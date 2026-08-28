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
/// ★ **سطحٌ داكن فوق خلفية فاتحة** — ★ **فيحتاج طقم نصّ خاصاً به** ⛔ **لا
/// يُستعار من توكنز السطح العادي.**
///
/// ⛔⛔ **وهو التدرّج الوحيد المسموح في التطبيق كله** — §8 المحظور السابع:
/// «**تدرّج لوني خارج البطاقة الرئيسية**»، ★ **وحملُه في امتداد السمة يجعل
/// كلَّ مستعملٍ له ظاهراً في مراجعةٍ واحدة.**
@immutable
class QtmsHeroColors extends ThemeExtension<QtmsHeroColors> {
  /// ينشئ الطقم.
  const QtmsHeroColors({
    required this.gradient,
    required this.onHero,
    required this.successOnHero,
    required this.dangerOnHero,
    required this.labelOpacity,
  });

  /// ★ الطقم المعتمَد — §4 حرفياً.
  const QtmsHeroColors.standard()
      : gradient = const LinearGradient(
          // ★ **قطريٌّ من أعلى-النهاية إلى أسفل-البداية** — §4 نصّاً.
          //   ⛔ **ولا `topRight`/`bottomLeft`**: بوابة الاتجاه ترفضهما،
          //   ★ **و`AlignmentDirectional` تنقل النيّة نفسها باتجاه RTL.**
          begin: AlignmentDirectional.topEnd,
          end: AlignmentDirectional.bottomStart,
          colors: <Color>[Primitives.primary600, Primitives.primary900],
        ),
        onHero = const Color(0xFFF7F9FC),
        successOnHero = const Color(0xFF7BD3A0),
        dangerOnHero = const Color(0xFFF49A9A),
        labelOpacity = 0.78;

  /// التدرّج — ★ **الوحيد في التطبيق.**
  final Gradient gradient;

  /// ★ نصّ فاتح على التدرّج — ⛔ **قائمٌ بذاته لا مشتقٌّ من `textOnInverse`**:
  /// ★ **الأول يصف نصاً على تدرّج البطاقة، والثاني نصاً على `surfaceInverse`**
  /// — ★ **وخلطهما يجعل تغيير أحدهما يغيّر الآخر بلا قصد.**
  final Color onHero;

  /// مؤشّر موجب فوق التدرّج.
  final Color successOnHero;

  /// مؤشّر سالب فوق التدرّج.
  final Color dangerOnHero;

  /// ★ **78٪ كحدّ أدنى — لا أقل** (§4).
  final double labelOpacity;

  /// ★ لون التسمية الثانوية فوق التدرّج — **بالشفافية المفروضة.**
  Color get onHeroLabel => onHero.withValues(alpha: labelOpacity);

  @override
  QtmsHeroColors copyWith({
    Gradient? gradient,
    Color? onHero,
    Color? successOnHero,
    Color? dangerOnHero,
    double? labelOpacity,
  }) =>
      QtmsHeroColors(
        gradient: gradient ?? this.gradient,
        onHero: onHero ?? this.onHero,
        successOnHero: successOnHero ?? this.successOnHero,
        dangerOnHero: dangerOnHero ?? this.dangerOnHero,
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

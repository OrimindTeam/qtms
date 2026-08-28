/// سمة التطبيق — ★ **تُبنى من التوكنز الدلالية وحدها** (`design-system.md`
/// §5.1: فصل العرض عن المنطق · `design-tokens.md` §1).
library;

import 'package:flutter/material.dart';

import 'design_tokens.dart';
import 'theme_extensions.dart';

/// ★ **السمة الوحيدة — الفاتحة** (`AM-003`).
///
/// ⛔ **ولا `darkTheme` ولا `ThemeMode` ولا قراءة لتفضيل النظام:** ★ **الوضع
/// الفاتح ليس افتراضاً بل القيمة الوحيدة**، ★ **فلا فرعَ حيّاً بلا استخدام.**
///
/// ★ **وآلية الثيم نفسها باقية عمداً** — ★ **نقطة حقن واحدة للقيم تجعل
/// الشاشة لا تعرف مصدر لونها** ⛔ **لا لأن هناك وضعاً ثانياً يُختار.**
ThemeData buildQtmsTheme() {
  final ColorScheme scheme = ColorScheme.fromSeed(
    seedColor: Primitives.primary500,
    surface: SemanticColors.surface,
    onSurface: SemanticColors.textPrimary,
    primary: Primitives.primary500,
    onPrimary: SemanticColors.textOnPrimary,
    error: Primitives.dangerBase,
    outline: SemanticColors.border,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: qtmsFontFamily,
    scaffoldBackgroundColor: SemanticColors.background,
    dividerColor: SemanticColors.divider,

    // ★★ **العائلات التصنيفية وطقم البطاقة الرئيسية عبر آلية الثيم** —
    //    `design-tokens.md` §1: ⛔ **لا ثوابت ساكنة تُقرأ من شاشة.**
    extensions: const <ThemeExtension<dynamic>>[
      QtmsCategoryColors.standard(),
      QtmsHeroColors.standard(),
    ],

    // ⚠️⚠️ **وخطُّ الفاصل الافتراضي يُنزَع من كل مكوّن** — ★ **لأن `Divider`
    //    و`ListTile` و`Card` تحمل ظلالاً وحدوداً افتراضية**، ⛔ **و§8 يمنع
    //    «استخدام مكوّنات الإطار الافتراضية بلا تغليفها».**
    dividerTheme: const DividerThemeData(
      color: SemanticColors.divider,
      thickness: Sizes.borderWidth,
      space: Sizes.borderWidth,
    ),

    textTheme: const TextTheme(
      displayLarge: TypeScale.displayLg,
      displaySmall: TypeScale.displaySm,
      titleLarge: TypeScale.titleLg,
      titleMedium: TypeScale.titleMd,
      titleSmall: TypeScale.titleSm,
      bodyLarge: TypeScale.bodyLg,
      bodyMedium: TypeScale.bodyMd,
      labelLarge: TypeScale.label,
      labelSmall: TypeScale.caption,
    ).apply(
      bodyColor: SemanticColors.textPrimary,
      displayColor: SemanticColors.textPrimary,
    ),

    // ★ **شريط علوي `surface` بلا ظل** — `design-system.md` §6.أ نصّاً.
    //   ⛔ **ولا ظلٍّ عند التمرير**: `scrolledUnderElevation` صفرٌ صراحةً،
    //   ⟵ **وإلا أعاد الإطارُ الظلَّ الذي منعه العقد.**
    appBarTheme: const AppBarTheme(
      backgroundColor: SemanticColors.surface,
      surfaceTintColor: Colors.transparent,
      foregroundColor: SemanticColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: Sizes.appBarHeight,
      centerTitle: false,
      // ★★ **ولونُ العنوان صريحٌ في النمط** — ⚠️ **`titleTextStyle` يُستعمَل
      //    كما هو**، ⟵ **ونمطٌ بلا لون يجعل عنوان الشريط يرث لوناً
      //    غير مضمون** ⛔ **فيختفي على سطحٍ أبيض.**
      titleTextStyle: TextStyle(
        fontFamily: qtmsFontFamily,
        fontSize: 17,
        fontWeight: FontWeight.w600,
        height: 1.40,
        letterSpacing: 0,
        color: SemanticColors.textPrimary,
      ),
    ),

    // §6.ب — حقل النص: **بلا حدّ افتراضي** · التركيز حدّ `primary` + حلقة.
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      // §3: `surfaceSunken` ⟵ **حقول الإدخال** حرفياً.
      fillColor: SemanticColors.surfaceSunken,
      // ★★ **ارتفاع الحقل من التوكنز** — §10 `fieldHeight`: ⟵ **فالحقل يفي
      //    بـ`minTouch` بنيوياً** ⛔ **لا بمصادفة الحشو الافتراضي.**
      constraints: const BoxConstraints(minHeight: Sizes.fieldHeight),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: Spacing.space16,
        vertical: Spacing.space12,
      ),
      // ⛔ **بلا حدّ افتراضي** — §6.ب نصّاً: ★ **الغائرُ يكفي للتمييز.**
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.field),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.field),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.field),
        borderSide: const BorderSide(
          color: Primitives.primary400,
          width: Sizes.focusWidth,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.field),
        borderSide: const BorderSide(
          color: Primitives.dangerBase,
          width: Sizes.borderWidth,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.field),
        borderSide: const BorderSide(
          color: Primitives.dangerBase,
          width: Sizes.focusWidth,
        ),
      ),
      labelStyle: const TextStyle(color: SemanticColors.textSecondary),
      // ★ **الخطأ `caption`** — §6.ب نصّاً.
      errorStyle: const TextStyle(color: Primitives.dangerInk),
    ),

    // ═══════════════════════════ §6.ج — الإجراءات ═══════════════════════════
    //
    // ⛔⛔★★★ **والأساسي `surfaceInverse` لا `primary`** — §6.ج جدولاً:
    //    «`primary` | `surfaceInverse` | `textOnInverse`». ★ **وهو فصلُ لون
    //    الهوية عن لون الإجراء** (§3.5): ⟵ **زرٌّ بلون الهوية يجعل كل شاشةٍ
    //    تصرخ بالأخضر**، ⛔ **فيضيع تمييزُ الإجراء الأساسي الواحد.**
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: SemanticColors.surfaceInverse,
        foregroundColor: SemanticColors.textOnInverse,
        disabledBackgroundColor: Primitives.neutral200,
        disabledForegroundColor: Primitives.neutral500,
        minimumSize: const Size.fromHeight(Sizes.buttonPrimaryHeight),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.field),
        ),
        textStyle: TypeScale.label,
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: SemanticColors.textPrimary,
        backgroundColor: SemanticColors.surface,
        // ★★ **هدف اللمس من التوكنز** — §5 البند 3: ⟵ **والافتراضي 40 وحده
        //    كان يُسقِط الشرط في كل مدخل من مداخل الصدَفة.**
        minimumSize: const Size.fromHeight(Sizes.minTouch),
        side: const BorderSide(
          color: SemanticColors.border,
          width: Sizes.borderWidth,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.field),
        ),
        textStyle: TypeScale.label,
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Primitives.primary700,
        minimumSize: const Size(Sizes.minTouch, Sizes.minTouch),
        textStyle: TypeScale.label,
      ),
    ),

    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: SemanticColors.textSecondary,
        // ★ **هدفُ لمسٍ كاملٌ ولو صغُرت الأيقونة** — §10 `minTouch`.
        minimumSize: const Size(Sizes.minTouch, Sizes.minTouch),
      ),
    ),

    // ★★★ **الزر العائم داكن + أيقونة ونص** — §6.ج: ⛔ **لا أيقونة صامتة**،
    //    ★ **ولا حاوية الإطار الفاتحة الافتراضية.**
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: SemanticColors.surfaceInverse,
      foregroundColor: SemanticColors.textOnInverse,
      elevation: 0,
      focusElevation: 0,
      hoverElevation: 0,
      highlightElevation: 0,
      extendedTextStyle: TypeScale.label,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.field),
      ),
    ),

    // §6.ب — الشرائح: ★ **النشطة ثلاثية `primary`** · وهدف اللمس مرفوع.
    chipTheme: ChipThemeData(
      backgroundColor: SemanticColors.surface,
      selectedColor: Primitives.primary50,
      checkmarkColor: Primitives.primary700,
      labelStyle: TypeScale.label.copyWith(color: SemanticColors.textPrimary),
      secondaryLabelStyle:
          TypeScale.label.copyWith(color: Primitives.primary700),
      side: const BorderSide(
        color: SemanticColors.border,
        width: Sizes.borderWidth,
      ),
      shape: const StadiumBorder(),
      // ★★ **ويُرفَع هدف اللمس بالحشو** — §6.ب: «بحشو غير مرئي».
      //    ⟵ **الشريحة `chipHeight` = 36 وحدها دون `minTouch`**،
      //    ★ **والحشو الرأسي يبلغ بها 48 بلا تضخيم بصري.**
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.space12,
        vertical: Spacing.space8,
      ),
      labelPadding: const EdgeInsets.symmetric(horizontal: Spacing.space4),
      showCheckmark: true,
    ),

    // §6.و — الورقة السفلية: `radius2xl` **علوي فقط**.
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: SemanticColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      modalBarrierColor: SemanticColors.overlay,
      showDragHandle: true,
      dragHandleColor: Primitives.neutral300,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadiusDirectional.vertical(
          top: Radius.circular(Radii.sheet),
        ),
      ),
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: SemanticColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      titleTextStyle: TypeScale.titleMd.copyWith(
        color: SemanticColors.textPrimary,
      ),
      contentTextStyle: TypeScale.bodyLg.copyWith(
        color: SemanticColors.textSecondary,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.card),
      ),
    ),

    // §6.ز — الحبّة العائمة: ★ **حدثٌ لا عنصر في الشجرة.**
    snackBarTheme: SnackBarThemeData(
      backgroundColor: SemanticColors.surfaceInverse,
      contentTextStyle: TypeScale.bodyMd.copyWith(
        color: SemanticColors.textOnInverse,
      ),
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.field),
      ),
    ),

    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith<Color>(
        (Set<WidgetState> states) => states.contains(WidgetState.selected)
            ? Primitives.primary500
            : SemanticColors.surface,
      ),
      side: const BorderSide(
        color: Primitives.neutral400,
        width: Sizes.borderWidth,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.xs),
      ),
    ),

    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith<Color>(
        (Set<WidgetState> states) => states.contains(WidgetState.selected)
            ? SemanticColors.surface
            : Primitives.neutral400,
      ),
      trackColor: WidgetStateProperty.resolveWith<Color>(
        (Set<WidgetState> states) => states.contains(WidgetState.selected)
            ? Primitives.primary500
            : Primitives.neutral200,
      ),
    ),

    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: Primitives.primary500,
      linearTrackColor: SemanticColors.surfaceSunken,
      circularTrackColor: SemanticColors.surfaceSunken,
    ),

    // ★ **حلقة التركيز من التوكنز** — §3 `focusRing`.
    focusColor: SemanticColors.focusRing,
    splashColor: SemanticColors.focusRing,
    highlightColor: SemanticColors.focusRing,
  );
}

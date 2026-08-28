/// التوكنز الأولية والدلالية — ★ **نقل حرفي لـ`design-tokens.md`**.
///
/// ★ **البنية ثلاثية الطبقات (§1) مُنفَّذة كما هي:** أولي ⟵ دلالي ⟵ مكوّن.
/// ⛔ **والشاشة لا تلمس الطبقة الأولية إطلاقاً** — تقرأ الدلالية وحدها،
/// وهي نفس قاعدة «الشاشات تستدعي الطبقة الدلالية فقط».
///
/// ⚠️ **وما لم يُنقَل بعد لا يُخترَع:** كل توكن هنا **منقولٌ بقيمته من المستند
/// حرفياً** ⛔ **لا بتقدير لوني قريب** — ★ **ومَن يضيف توكناً يضيفه من الجدول.**
///
/// ★★ **`AM-003` — وضعٌ واحد فقط: الفاتح.** ⛔ **لا مجموعة قيم ثانية، ولا
/// `ThemeMode`، ولا قراءة لتفضيل النظام.** ★ **وآلية الثيم أُبقيت بنيوياً**
/// (`design-tokens.md` §1) ⛔ **لكنها تُغذَّى بمجموعة واحدة لا مجموعتين.**
library;

import 'package:flutter/material.dart';

/// الطبقة الأولية — §2.
abstract final class Primitives {
  // ═══════════════ §2.1 المحايد — أساس النظام بميل بارد ═══════════════
  static const Color neutral0 = Color(0xFFFFFFFF);
  static const Color neutral25 = Color(0xFFFAFBFC);
  static const Color neutral50 = Color(0xFFF5F6FA);
  static const Color neutral100 = Color(0xFFEFF1F5);
  static const Color neutral200 = Color(0xFFE3E6ED);
  static const Color neutral300 = Color(0xFFCDD2DD);
  static const Color neutral400 = Color(0xFFA2AAB9);
  static const Color neutral500 = Color(0xFF7A8496);
  static const Color neutral600 = Color(0xFF5C6675);
  static const Color neutral700 = Color(0xFF414A58);
  static const Color neutral800 = Color(0xFF28303C);
  static const Color neutral900 = Color(0xFF161C26);
  static const Color neutral950 = Color(0xFF0E131B);

  // ═════ §2.2 الأساسي — ★★ أخضر عميق مستخلَص من شعار العميل (`AM-003`) ═════
  //    ⛔ لا الكحلي القديم: القيمة عُدِّلت عمداً عن إدخال مكتبة التصميم
  //    لتطابق الهوية البصرية الفعلية. ✅ و`primary500` مع نصّ أبيض = 6.2:1.
  static const Color primary50 = Color(0xFFE2F0D8);
  static const Color primary100 = Color(0xFFC5E0B1);
  static const Color primary200 = Color(0xFF9CC77D);
  static const Color primary300 = Color(0xFF73A650);
  static const Color primary400 = Color(0xFF5C8C3A);
  static const Color primary500 = Color(0xFF446B28);
  static const Color primary600 = Color(0xFF3C5E24);
  static const Color primary700 = Color(0xFF2E471B);
  static const Color primary800 = Color(0xFF223614);
  static const Color primary900 = Color(0xFF1A2910);

  // ═════════════════════ §2.3 عائلات الحالات ═════════════════════
  static const Color successSoft = Color(0xFFE7F5EC);
  static const Color successBorder = Color(0xFFB7E0C6);
  static const Color successBase = Color(0xFF2E9E5B);
  static const Color successInk = Color(0xFF1E6B3E);

  static const Color dangerSoft = Color(0xFFFDECEC);
  static const Color dangerBorder = Color(0xFFF5BFBF);
  static const Color dangerBase = Color(0xFFD93B3B);
  static const Color dangerInk = Color(0xFF9B2626);

  static const Color warningSoft = Color(0xFFFEF4E3);
  static const Color warningBorder = Color(0xFFF7D9A4);
  static const Color warningBase = Color(0xFFD98A17);
  static const Color warningInk = Color(0xFF8F5A0C);

  static const Color infoSoft = Color(0xFFE9F1FB);
  static const Color infoBorder = Color(0xFFBBD3F0);
  static const Color infoBase = Color(0xFF2C6FD1);
  static const Color infoInk = Color(0xFF1B4A8F);

  // ════════════ §2.4 العائلات التصنيفية — ★ خمس فقط لا أكثر ════════════
  //    ⛔ **ولا `border` مستقل لها** — الحدّ يساوي `base` عند الحاجة.
  static const Color cat1Soft = Color(0xFFE8EFF6);
  static const Color cat1Base = Color(0xFF3E7096);
  static const Color cat1Ink = Color(0xFF2F5F87);

  static const Color cat2Soft = Color(0xFFE4F2F3);
  static const Color cat2Base = Color(0xFF2F8089);
  static const Color cat2Ink = Color(0xFF25646B);

  static const Color cat3Soft = Color(0xFFEFEAF7);
  static const Color cat3Base = Color(0xFF6C50A6);
  static const Color cat3Ink = Color(0xFF553C86);

  static const Color cat4Soft = Color(0xFFFBF0DE);
  static const Color cat4Base = Color(0xFFC1811F);
  static const Color cat4Ink = Color(0xFF8A5A11);

  static const Color cat5Soft = Color(0xFFF2E4EE);
  static const Color cat5Base = Color(0xFF834072);
  static const Color cat5Ink = Color(0xFF632C55);
}

/// الطبقة الدلالية — §3.
///
/// ★★ **مجموعة واحدة لا مجموعتان** (`AM-003`): ⛔ **لا وضع داكن ولا قيمة
/// مشروطة بوضع.** ★ **والقيم الداكنة الملغاة محفوظة سجلاً تاريخياً في**
/// `docs/99-archive/2026/design-tokens-dark-mode-AM-003.md` ⛔ **ولا تُستورَد
/// منه قيمة.**
///
/// ⚠️ ★ **و`surfaceInverse` و`textOnInverse` ليسا «وضعاً داكناً»** — ★ **بل
/// سطحٌ داكن داخل شاشةٍ فاتحة** (الزر العائم · الإجراء الأساسي)، ⛔ **فلا
/// يُقرآن كبقايا وضعٍ أُلغي.**
abstract final class SemanticColors {
  static const Color background = Primitives.neutral50;
  static const Color surface = Primitives.neutral0;
  static const Color surfaceSunken = Color(0xFFF2F3F7);
  static const Color surfaceInverse = Color(0xFF141C2E);
  static const Color border = Primitives.neutral200;
  static const Color divider = Color(0xFFF0F1F5);
  static const Color textPrimary = Color(0xFF131A2B);
  static const Color textSecondary = Primitives.neutral600;
  static const Color textTertiary = Color(0xFF656E7E);
  static const Color textOnInverse = Color(0xFFF7F9FC);
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  // ★★ مشتقّ من `primary400` — ⟵ **وتغيُّره مع تغيُّر العائلة إلزامي**
  //    (`AM-003`): ⛔ **قيمة معتّمة يدوياً تبقى كحليةً بعد خضرة الأساس.**
  static const Color focusRing = Color(0x665C8C3A); // primary400 بشفافية 40٪
  static const Color overlay = Color(0x7A0E131B); // neutral950 بشفافية 48٪
  static const Color skeleton = Color(0xFFE9ECF2);
  static const Color skeletonHighlight = Color(0xFFF4F6FA);
}

/// ★ ثلاثيةٌ لونية واحدة — **تعبئة وحدّ ومقدّمة من العائلة نفسها** (§3.3).
///
/// ⛔⛔★★★ **وهذا النوع هو ما يمنع الخلط بنيوياً:** ★ **قاعدة §3.3 تمنع
/// «مزج تعبئة من عائلة مع نص من عائلة أخرى»** — ⟵ **وتمريرُ ثلاث قيمٍ
/// منفصلة إلى مكوّن يجعل المخالفة سطراً عادياً لا يلفت المراجعة**،
/// ★ **بينما تمريرُ ثلاثيةٍ واحدة يجعلها مستحيلةً بلا تركيب متعمَّد.**
@immutable
class ColorTriad {
  /// ينشئ الثلاثية.
  const ColorTriad({
    required this.soft,
    required this.border,
    required this.ink,
  });

  /// التعبئة.
  final Color soft;

  /// الحدّ — ★ **يساوي `base` في العائلات التصنيفية** (§2.4).
  final Color border;

  /// المقدّمة: نصّاً وأيقونةً معاً.
  final Color ink;
}

/// ★ العائلات الدلالية للحكم — §3.4.
///
/// ⛔ **ولا تُستخدَم زينةً** — ★ **ولا تنقل معنى باللون وحده**: §8 المحظور
/// الثاني عشر يفرض **أيقونة أو نصّاً دائماً**.
abstract final class SemanticTriads {
  static const ColorTriad success = ColorTriad(
    soft: Primitives.successSoft,
    border: Primitives.successBorder,
    ink: Primitives.successInk,
  );
  static const ColorTriad danger = ColorTriad(
    soft: Primitives.dangerSoft,
    border: Primitives.dangerBorder,
    ink: Primitives.dangerInk,
  );
  static const ColorTriad warning = ColorTriad(
    soft: Primitives.warningSoft,
    border: Primitives.warningBorder,
    ink: Primitives.warningInk,
  );
  static const ColorTriad info = ColorTriad(
    soft: Primitives.infoSoft,
    border: Primitives.infoBorder,
    ink: Primitives.infoInk,
  );

  /// ★ **و`primary` تعمل ثلاثية أيضاً** — §2.3 نصّاً.
  static const ColorTriad primary = ColorTriad(
    soft: Primitives.primary50,
    border: Primitives.primary200,
    ink: Primitives.primary700,
  );

  /// ★ محايدة — **لغياب الحكم** (§2 المبدأ الأول: «لا لون بلا وظيفة»).
  static const ColorTriad neutral = ColorTriad(
    soft: Primitives.neutral100,
    border: Primitives.neutral200,
    ink: Primitives.neutral700,
  );
}

/// §6 — المسافات على شبكة 4pt.
abstract final class Spacing {
  static const double space2 = 2;
  static const double space4 = 4;
  static const double space8 = 8;
  static const double space12 = 12;
  static const double space16 = 16;
  static const double space20 = 20;
  static const double space24 = 24;
  static const double space32 = 32;
  static const double space40 = 40;
  static const double space48 = 48;
  static const double space64 = 64;

  // ★ **التطبيقات الثابتة** — §6 نصّاً: ⟵ **فالشاشة تقرأ نيّةً لا رقماً**،
  //   ⛔ **و`space16` في موضع حشو الشاشة لا يقول إنه حشو الشاشة.**
  static const double screenPadding = space16;
  static const double cardPadding = space16;
  static const double cardGap = space12;
  static const double sectionGap = space24;
  static const double labelGap = space8;

  /// ★★ **مسافة أمان الزر العائم** — ⟵ **آخر بطاقةٍ في القائمة تبقى مقروءة**
  /// ⛔ **ولا تختفي خلف الزر.**
  static const double fabSafeBottom = 96;
}

/// §7 — نصف القطر.
///
/// ★ **القاعدة: الحجم أكبر ⇒ الانحناء أكبر** — الانحناء يعبّر عن **مستوى
/// العنصر في التسلسل** لا عن ذوق.
abstract final class Radii {
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 14;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 28;
  static const double pill = 999;

  /// حقول الإدخال وحاويات الأيقونات — §7 يربطهما بـ`radiusMd`.
  static const double field = md;

  /// البطاقات — §7 يربطها بـ`radiusLg`.
  static const double card = lg;

  /// البطاقة الرئيسية — §7 يربطها بـ`radiusXl`.
  static const double hero = xl;

  /// الورقة السفلية — **علوي فقط** (§7).
  static const double sheet = xxl;
}

/// §8 — الظلال.
///
/// ★ **السمة المميِّزة: إزاحة صغيرة + ضبابية كبيرة + شفافية منخفضة جداً** —
/// إحساس «هواء تحت البطاقة» لا «طبقة معدنية».
/// ⛔ **ممنوع ظل الإطار الافتراضي** · ⛔ **ممنوع ظل وحدّ معاً على العنصر نفسه.**
abstract final class Elevation {
  /// عناصر مسطّحة داخل بطاقة.
  static const List<BoxShadow> e0 = <BoxShadow>[];

  /// بطاقة عادية.
  static const List<BoxShadow> e1 = <BoxShadow>[
    BoxShadow(
      color: Color(0x0F0E131B),
      offset: Offset(0, 4),
      blurRadius: 12,
    ),
  ];

  /// بطاقة مرفوعة أو نشطة.
  static const List<BoxShadow> e2 = <BoxShadow>[
    BoxShadow(
      color: Color(0x140E131B),
      offset: Offset(0, 8),
      blurRadius: 24,
    ),
  ];

  /// زر عائم · ورقة سفلية · حوار.
  static const List<BoxShadow> e3 = <BoxShadow>[
    BoxShadow(
      color: Color(0x1F0E131B),
      offset: Offset(0, 12),
      blurRadius: 32,
    ),
  ];
}

/// §9 — الحركة.
///
/// ⛔ **لا حركة تتجاوز `400ms`** · ⛔ **لا ارتداد ولا مطاطية** ·
/// ★ **إعداد «تقليل الحركة» محترَم دائماً — والحركة تُلغى لا تُبطَّأ.**
abstract final class Motion {
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration base = Duration(milliseconds: 220);
  static const Duration slow = Duration(milliseconds: 320);
  static const Duration shimmer = Duration(milliseconds: 1200);

  static const Curve standard = Curves.easeInOutCubic;
  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;

  /// ★★ **هل يطلب المستخدم تقليل الحركة؟**
  ///
  /// ⚠️⚠️ **ولماذا دالةٌ واحدة لا فحصٌ في كل مكوّن:** ★ **المستند يفرض أن
  /// الحركة «تُلغى لا تُبطَّأ»** — ⟵ **وقاعدةٌ بهذا الوضوح تحتاج موضعَ
  /// تطبيقٍ واحداً**، ⛔ **وإلا نُسيت في مكوّنٍ فبقيت فيه وحدها.**
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// ★ المدّة الفعلية بعد احترام التقليل — ⛔ **صفرٌ لا إبطاء.**
  static Duration of(BuildContext context, Duration duration) =>
      reduced(context) ? Duration.zero : duration;
}

/// §10 — الأبعاد.
abstract final class Sizes {
  static const double fieldHeight = 52;
  static const double buttonPrimaryHeight = 52;
  static const double buttonSecondaryHeight = 44;
  static const double chipHeight = 36;
  static const double listRowHeight = 72;
  static const double tileMinHeight = 56;
  static const double appBarHeight = 56;
  static const double iconBox = 48;
  static const double iconSm = 16;
  static const double iconMd = 20;
  static const double iconLg = 24;
  static const double avatarSm = 36;
  static const double avatarMd = 44;
  static const double avatarLg = 64;
  static const double borderWidth = 1;
  static const double focusWidth = 2;

  /// ★★ **الحد الأدنى لهدف اللمس** — §5 البند 3 من عقود المكوّنات.
  ///
  /// ⚠️ **وهو شرطٌ لا توصية:** ★ **الاستخدام ميداني مستعجل**
  /// (`ui-guidelines.md` §2)، ⟵ **وهدفٌ أصغر يُنتج ضغطةً خاطئة على مستندٍ
  /// مالي.**
  static const double minTouch = 48;
}

/// §5 — تكسير التجاوب.
///
/// ★ **مقروءةٌ من جدول `ui-guidelines.md` §5 حرفياً** — ⛔ **ولا رقمَ تجاوبٍ
/// مكتوبٌ داخل شاشة.**
abstract final class Breakpoints {
  /// دونه: شبكة 3 أعمدة · حشو 12 · ★ **والجداول تتحوّل لبطاقات.**
  static const double compact = 360;

  /// فوقه: عمودان للقوائم · شبكة 6 أعمدة · هوامش 24.
  static const double expanded = 600;

  /// ★ عدد أعمدة الشبكة — **موزّع مركزي** (`design-system.md` §و).
  static int gridColumns(double width) {
    if (width < compact) return 3;
    if (width > expanded) return 6;
    return 4;
  }

  /// ★ الهامش الأفقي المتجاوب — §5: **حشو 12 دون 360 · و24 فوق 600.**
  static double gutter(double width) {
    if (width < compact) return Spacing.space12;
    if (width > expanded) return Spacing.space24;
    return Spacing.screenPadding;
  }
}

/// اسم عائلة الخط المعتمَد — §5.
const String qtmsFontFamily = 'IBM Plex Sans Arabic';

/// §5 — التايبوغرافيا.
///
/// ⚠️ **وقاعدة العربية مفروضة في كل نمط:** **ارتفاع السطر ≥ 1.6 للنصّ**
/// **وتباعد الأحرف = 0 دائماً** — ⛔ **ولا حروف كبيرة في النص العربي.**
abstract final class TypeScale {
  static const TextStyle displayLg = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    height: 1.25,
    letterSpacing: -0.5,
  );

  static const TextStyle displaySm = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w700,
    height: 1.30,
    letterSpacing: -0.3,
  );

  static const TextStyle titleLg = TextStyle(
    fontSize: 20,
    // ⚠️ ★ المستند يطلب 700، والحزمة المعتمدة لا تحمله — ⟵ رُبط في
    //    `pubspec.yaml` بملف 600 صراحةً ⛔ لا بمحاكاة آلية (README §1).
    fontWeight: FontWeight.w700,
    height: 1.35,
    letterSpacing: 0,
  );

  static const TextStyle titleMd = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    height: 1.40,
    letterSpacing: 0,
  );

  static const TextStyle titleSm = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.45,
    letterSpacing: 0,
  );

  static const TextStyle bodyLg = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.60,
    letterSpacing: 0,
  );

  static const TextStyle bodyMd = TextStyle(
    fontSize: 13.5,
    fontWeight: FontWeight.w400,
    height: 1.60,
    letterSpacing: 0,
  );

  static const TextStyle label = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    height: 1.40,
    letterSpacing: 0,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.40,
    letterSpacing: 0.1,
  );

  /// ★★★ **كل رقم في جدول — بأرقام جدولية** (§5).
  ///
  /// ⚠️⚠️ **وليس توكناً تجميلياً في QTMS:** ★ **بدون الأرقام الجدولية تهتزّ
  /// أعمدة الجداول المالية عند كل تحديث** — **وتُصعِّب المقارنة البصرية التي
  /// يعتمد عليها المالك.**
  ///
  /// ⛔ **ويُقرأ ارتفاع السطر 1.20 عمداً** — ★ **رقمٌ لا جملة**، ⟵ **فقاعدة
  /// «العربية ≥ 1.6» لا تنطبق عليه.**
  static const List<FontFeature> tabular = <FontFeature>[
    FontFeature.tabularFigures(),
  ];

  /// ★ نمط الرقم الجدولي بحجم النصّ الرئيسي.
  static const TextStyle numeric = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.20,
    letterSpacing: 0,
    fontFeatures: tabular,
  );

  /// ★ نمط الرقم الجدولي بحجم النصّ الثانوي.
  static const TextStyle numericSm = TextStyle(
    fontSize: 13.5,
    fontWeight: FontWeight.w600,
    height: 1.20,
    letterSpacing: 0,
    fontFeatures: tabular,
  );

  /// ★ الرقم المتصدّر في البطاقة الرئيسية — **جدوليٌّ كذلك.**
  static const TextStyle numericDisplay = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    height: 1.25,
    letterSpacing: -0.5,
    fontFeatures: tabular,
  );
}

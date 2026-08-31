/// توكنز المستند المُصدَّر — ★★ **مشتقّةٌ من الطبقة الدلالية نفسِها**.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **ولماذا تعيش هنا لا في راسم الـPDF:** ★ **بوابة التوكنز ترفض
/// «حجم خط مكتوب مباشرة» و«لون خام» في كل `lib/` خارج هذه الطبقة**
/// (`design-system.md` §8 المحظوران 1 و3) — ⟵ **وراسمٌ يحمل مقاساتِه
/// وألوانَه بنفسه يخرق البوابة**، ★ **أو يُجبِر على استثنائه منها.**
///
/// ★★ **والحلّ الصحيح ليس الاستثناء بل الاشتقاق:** ⟵ **فالمستند المُصدَّر
/// يقرؤه العميلُ نفسُه الذي يرى الشاشة**، ★ **وسلّمٌ ثانٍ للأحجام كان
/// يُنتج ملفاً يبدو من تطبيقٍ آخر** (`ui-guidelines.md` §7 السؤال 1).
/// ═══════════════════════════════════════════════════════════════════════
///
/// ⚠️ **ووحدةُ القياس تتغيّر ولا تتغيّر القيمة:** ★ **`pt` في الـPDF مقابل
/// `dp` على الشاشة** — ★ **والسلّم الطباعي واحد**، ⟵ **فالنسب محفوظة**
/// ⛔ **ولا رقمَ جديد يُخترَع.**
///
/// ⛔⛔★★ **ولا بصمةَ لجهة التطوير في أي قيمةٍ هنا ولا في أي مخرَج يستعملها**
/// — ★ **المستند المُصدَّر يخرج لعملاء العميل** (`developer-identity-placement.md`
/// §5 · `messaging-design.md` §8).
library;

import 'dart:ui' show Color;

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'design_tokens.dart';

/// ★ يحوّل لون الواجهة إلى لون المستند — **موضعٌ واحد** ⛔ **لا تحويلٌ مكرَّر.**
PdfColor pdfColorOf(Color color) => PdfColor.fromInt(color.toARGB32());

/// ألوان المستند المُصدَّر — ★ **من الطبقة الدلالية حصراً**.
abstract final class PdfPalette {
  /// نصّ العناوين والقيم.
  static PdfColor get textPrimary => pdfColorOf(SemanticColors.textPrimary);

  /// النصّ الثانوي — التسميات ورؤوس الأعمدة.
  static PdfColor get textSecondary => pdfColorOf(SemanticColors.textSecondary);

  /// خلفية رأس الجدول — ★ **السطح الغائر نفسه** (`design-system.md` §3.1).
  static PdfColor get headerFill => pdfColorOf(SemanticColors.surfaceSunken);

  /// خطوط الفصل.
  static PdfColor get divider => pdfColorOf(SemanticColors.border);
}

/// ★ السلّم الطباعي للمستند — **مشتقٌّ من [TypeScale]** ⛔ **لا موازٍ له**.
final class PdfTypeScale {
  /// ينشئ السلّم بخطٍّ مُحمَّل — ★ **والخط يُمرَّر ولا يُحمَّل هنا**:
  /// ⟵ **فالطبقةُ بلا وصولٍ إلى الأصول** (`design-system.md` §5.1).
  const PdfTypeScale({required pw.Font regular, required pw.Font bold})
      : _regular = regular,
        _bold = bold;

  final pw.Font _regular;
  final pw.Font _bold;

  /// عنوان المستند.
  pw.TextStyle get title => pw.TextStyle(
        font: _bold,
        fontSize: TypeScale.titleLg.fontSize,
        color: PdfPalette.textPrimary,
      );

  /// اسم المحل في الترويسة.
  pw.TextStyle get businessName => pw.TextStyle(
        font: _bold,
        fontSize: TypeScale.titleSm.fontSize,
        color: PdfPalette.textPrimary,
      );

  /// نصّ الجسم والقيم.
  pw.TextStyle get body => pw.TextStyle(
        font: _regular,
        fontSize: TypeScale.bodyMd.fontSize,
        color: PdfPalette.textPrimary,
      );

  /// التسميات ورؤوس الأعمدة.
  pw.TextStyle get label => pw.TextStyle(
        font: _regular,
        fontSize: TypeScale.bodyMd.fontSize,
        color: PdfPalette.textSecondary,
      );

  /// ★ عرضُ الفراغ بين كلمتين بحجم نصّ الجسم — **يُستعمَل بين تسميةٍ وقيمة**.
  double get wordGap => wordGapFor(body);

  /// الإجماليات — ★ **بوزنٍ أثقل** لأنها حصيلة الشاشة.
  pw.TextStyle get total => pw.TextStyle(
        font: _bold,
        fontSize: TypeScale.bodyMd.fontSize,
        color: PdfPalette.textPrimary,
      );
}

/// ★★ عرضُ الفراغ بين كلمتين **نسبةً إلى حجم الخط** — ⛔ **لا نقطةً ثابتة.**
///
/// ⚠️ **ولماذا نسبة:** ★ **الترويسة والعنوان والإجماليات بأحجامٍ مختلفة** —
/// ⟵ **وفراغٌ ثابت يبدو ضائعاً في العنوان وفجّاً في الجسم.**
///
/// ⛔⛔ **ولماذا نرسمه أصلاً:** راجع `spacedPdfValue` — ★ **الحزمة تُوزّع
/// فراغَ الكلمات على الفجوة الخطأ عند عكس الاتجاه** (مقيسٌ 2026-08-30).
///
/// ★ **والقيمة 0.35 مقيسةٌ بالعين على الجهاز** — ⟵ **0.2 اختُبرت فبدت
/// كلمتان ملتصقتين** (`الاختبارالأول`)، ⛔ **فلا تُخفَّض بلا إعادة قياس.**
const double pdfWordGapRatio = 0.35;

/// ★ يحسب عرضَ الفراغ لنمطٍ بعينه — ⛔ **ولا حجمَ خطٍّ مفقودٍ يُسقِط الرسم.**
double wordGapFor(pw.TextStyle style) =>
    (style.fontSize ?? TypeScale.bodyMd.fontSize ?? 0) * pdfWordGapRatio;

/// راسم المستند المُصدَّر — ★ **يحوّل [ExportableDocument] إلى ملف PDF**.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **ولا يحسب ولا ينسّق رقماً واحداً** (`design-system.md` §5.1):
/// ★ **كل خلية تصله نصّاً جاهزاً بناه النطاق** (`export_documents.dart`) —
/// ⟵ **وهو ما يجعل معيار قبول `WU-010` قابلاً للتحقق أصلاً**: «**المستند
/// المُصدَّر يطابق ما تعرضه الشاشة رقماً برقم**».
/// ═══════════════════════════════════════════════════════════════════════
///
/// ★★ **والاتجاه RTL مُصرَّحٌ به على مستوى المستند** — ⟵ **وهو ما يُفعِّل
/// تشكيلَ العربية في حزمة `pdf`** (`arabic.convert` داخلها)، ⛔ **وبدونه
/// تُطبَع الحروف منفصلةً ومقلوبة.**
///
/// ⛔⛔★★ **ولا بصمةَ لجهة التطوير في أي موضع من هذا الملف** —
/// `messaging-design.md` §8 · `developer-identity-placement.md` §5:
/// ★ **مخرَجٌ يُصدَّر لعملاء العميل من الممنوعات الثمانية نصّاً.**
library;

import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:qtms_domain/qtms_domain.dart';

import '../../../core/design/design_tokens.dart';
import '../../../core/design/pdf_tokens.dart';

/// مسار الخط العادي — ★ **الخط المعتمد نفسه** (`design-tokens.md` §5).
///
/// ⛔ **ولا خطَّ ثانٍ ولا بديلَ نظامي:** ★ **الخطوط النظامية على أندرويد لا
/// تُضمَّن في الـPDF**، ⟵ **فملفٌ يعتمدها يُقرأ صحيحاً على الجهاز الذي أنشأه
/// وحده** ⛔ **ويظهر فارغاً عند المستلِم.**
const String _regularFontAsset = 'assets/fonts/IBMPlexSansArabic-Regular.ttf';

/// مسار الخط الثقيل — ★ **وزن 600** (`pubspec.yaml`: **وهو بديل 700 الموثَّق**).
const String _boldFontAsset = 'assets/fonts/IBMPlexSansArabic-SemiBold.ttf';

/// ★ عقدُ راسم المستندات — **يعرّفه هذا الملف وتحقنه الشاشة**.
///
/// ⛔★★ **ولماذا واجهةٌ لا صنفٌ مباشر:** ★ **اختبارُ الشاشة لا يجوز أن يقرأ
/// قرصاً ولا يبني ملفاً حقيقياً** — ⟵ **فيُحقَن بديلٌ خفيف**، ★ **وصحّةُ
/// الملف نفسِها تُقاس في اختبار الراسم وحده.**
abstract interface class DocumentRenderer {
  /// يبني بايتات الملف للمستند.
  Future<Uint8List> render(ExportableDocument document);
}

/// ⛔⛔★★★ يقسّم قيمةً قصيرة كلماتٍ بفراغٍ نرسمه نحن — **علاجُ عطلٍ مقيس**.
///
/// ⚠️⚠️ **العطل — رصده الجهازُ وحده** (2026-08-30 · §د.2): ★ **قيمةٌ من ثلاث
/// كلمات تفقد أحد فراغاتها** ⟵ **«مصدر الاختبار الأول» طُبعت «مصدر
/// الاختبارالأول»** — ⟹ **اسمُ مصدرٍ يُقرأ كلمةً واحدة في مستندٍ يصل يدَ
/// العميل.** ⛔ **والسبب في تخطيط الحزمة نفسِها:** ★ **تُقطّع النصّ كلماتٍ
/// وتعكس ترتيبها للاتجاه**، **وعرضُ الفراغ يُنسَب للفجوة الخطأ.**
///
/// ⛔⛔ **وفراغٌ غير فاصل (`U+00A0`) لا يُصلحه — مقيسٌ لا مفترَض:** ★ **جُرّب
/// أولاً فخرج الملفُّ بمواضع الكلمات نفسِها حرفاً بحرف** (**26 مقطعاً في
/// المواضع نفسِها**) ⟵ **فالحزمة تُسوّيه فراغاً عادياً قبل التشكيل.**
///
/// ✅ **والعلاج: صفٌّ من كلماتٍ وفراغاتٍ نرسمها** — ⟵ **فالتخطيط لنا**،
/// ⛔ **ولا يُترَك للحزمة أن تُوزّع فراغاً بيننا وبين قارئ المستند.**
///
/// ⛔⛔ **ولا يُطبَّق إلا على القيم القصيرة** (الترويسة والإجماليات) —
/// ★ **إذ لا يلتفّ الصفّ**: ⟵ **وخلايا الجدول تبقى نصّاً عادياً** فقد تطول
/// أسماءُ الأنواع، ⛔ **وقيمةٌ لا تلتفّ تخرج من الصفحة.**
///
/// ⛔ **ولا يمسّ هذا نصَّ الرسالة ولا طبقة النطاق** — ★ **تخطيطٌ عند الرسم
/// وحده**: ⟵ **فمطابقةُ «المستند يطابق الرسالة رقماً برقم» قائمة.**
pw.Widget spacedPdfValue(String value, pw.TextStyle style) {
  final List<String> words = value.split(' ');
  if (words.length < 2) return pw.Text(value, style: style);
  // ★ **الفراغ نسبةً إلى حجم الخط** — `pdf_tokens.dart` ⛔ **لا نقطةَ حرّة.**
  final double gap = wordGapFor(style);
  return pw.Row(
    mainAxisSize: pw.MainAxisSize.min,
    children: <pw.Widget>[
      for (int i = 0; i < words.length; i++) ...<pw.Widget>[
        if (i > 0) pw.SizedBox(width: gap),
        pw.Text(words[i], style: style),
      ],
    ],
  );
}

/// راسم المستندات.
///
/// ★ **يُحمَّل الخطّان مرةً واحدة لكل نسخة** — ⛔ **لا عند كل تصدير**:
/// ⟵ **فقراءةُ ملفَّي خطٍّ من الحزمة في كل ضغطةٍ تأخيرٌ محسوس.**
final class PdfDocumentRenderer implements DocumentRenderer {
  /// ينشئ الراسم — ★ **وقارئُ الأصول يُحقَن، فيُختبَر بلا حزمة**.
  PdfDocumentRenderer({Future<ByteData> Function(String)? loadAsset})
      : _loadAsset = loadAsset ?? rootBundle.load;

  final Future<ByteData> Function(String) _loadAsset;

  PdfTypeScale? _scale;

  /// يبني بايتات ملف PDF للمستند.
  @override
  Future<Uint8List> render(ExportableDocument document) async {
    final PdfTypeScale scale = _scale ??= PdfTypeScale(
      regular: pw.Font.ttf(await _loadAsset(_regularFontAsset)),
      bold: pw.Font.ttf(await _loadAsset(_boldFontAsset)),
    );

    final pw.Document pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(Spacing.space24),
        // ★★ **الاتجاه على مستوى الصفحة** — ⟵ **فكلُّ نصٍّ فيها يُشكَّل عربياً.**
        textDirection: pw.TextDirection.rtl,
        build: (pw.Context context) => <pw.Widget>[
          _header(document, scale),
          pw.SizedBox(height: Spacing.space16),
          _table(document, scale),
          pw.SizedBox(height: Spacing.space16),
          _totals(document, scale),
        ],
      ),
    );
    return pdf.save();
  }

  pw.Widget _header(ExportableDocument document, PdfTypeScale scale) =>
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          pw.Text(document.businessName, style: scale.businessName),
          pw.SizedBox(height: Spacing.space4),
          pw.Text(document.title, style: scale.title),
          pw.SizedBox(height: Spacing.space12),
          for (final ExportField field in document.header)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: Spacing.space4),
              child: pw.Row(
                children: <pw.Widget>[
                  spacedPdfValue('${field.label}:', scale.label),
                  pw.SizedBox(width: scale.wordGap),
                  spacedPdfValue(field.value, scale.body),
                ],
              ),
            ),
          pw.Divider(color: PdfPalette.divider),
        ],
      );

  /// ★★ الجدول **مبنيٌّ يدوياً** — ⛔ **ولا `TableHelper.fromTextArray`**.
  ///
  /// ⚠️⚠️ **ولماذا — وهو قيدُ بوابةٍ لا ذوق:** ★ **مساعدُ الحزمة يقبل
  /// `Alignment` وحدها** ⛔ **لا `AlignmentGeometry`** — ⟵ **فمحاذاةُ خلاياه
  /// تُكتب `centerRight`**، ★ **وهي «قيمةٌ موضعية بيمين/يسار» ترفضها بوابةُ
  /// الاتجاه** (`ui-guidelines.md` §8 · `design-system.md` §2 المبدأ 5).
  ///
  /// ✅ **والحلُّ محاذاةٌ اتجاهية حقيقية** (`AlignmentDirectional.centerStart`)
  /// **تُحَلّ من اتجاه الصفحة** — ⟵ **فهي أصحُّ لا أشكلُ فقط:** ⛔ **ولا
  /// تنكسر لو تغيّر الاتجاه يوماً.**
  pw.Widget _table(ExportableDocument document, PdfTypeScale scale) => pw.Table(
        border: pw.TableBorder.all(color: PdfPalette.divider),
        children: <pw.TableRow>[
          pw.TableRow(
            decoration: pw.BoxDecoration(color: PdfPalette.headerFill),
            children: <pw.Widget>[
              for (final String column in document.columns)
                _cell(column, scale.label),
            ],
          ),
          for (final ExportRow row in document.rows)
            pw.TableRow(
              children: <pw.Widget>[
                for (final String cell in row.cells) _cell(cell, scale.body),
              ],
            ),
        ],
      );


  /// خليةُ جدولٍ **بمحاذاةٍ اتجاهية** — ⛔ **لا يمين ولا يسار**.
  pw.Widget _cell(String text, pw.TextStyle style) => pw.Container(
        alignment: pw.AlignmentDirectional.centerStart,
        padding: const pw.EdgeInsets.all(Spacing.space8),
        child: pw.Text(text, style: style),
      );

  pw.Widget _totals(ExportableDocument document, PdfTypeScale scale) =>
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          for (final ExportField field in document.totals)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: Spacing.space4),
              child: pw.Row(
                children: <pw.Widget>[
                  spacedPdfValue('${field.label}:', scale.label),
                  pw.SizedBox(width: scale.wordGap),
                  spacedPdfValue(field.value, scale.total),
                ],
              ),
            ),
        ],
      );
}

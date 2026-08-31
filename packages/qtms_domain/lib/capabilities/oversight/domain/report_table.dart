/// جدولُ تقريرٍ جاهزٌ للعرض والتصدير — ★★ **بنيةٌ خالصة يبنيها النطاق**.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **وخلاياه نصوصٌ منسَّقةٌ مسبقاً — ⛔ لا أرقامٌ خام** — ★ **بنفس
/// عقد [ExportableDocument] حرفياً وللسبب نفسِه** (`WU-010`): ⟵ **لو نسَّقت
/// الشاشةُ رقمَها ونسَّقه الراسمُ من جديد لصارت للقيمة الواحدة صيغتان**،
/// ⛔ **وافترقتا عند أول حالةٍ حدّية** (فاصلُ آلاف · وزنٌ بثلاث خانات ·
/// سطرٌ غير مسعَّر). ★ **وهنا تُبنى مرةً واحدة، والشاشةُ والملف يعرضان
/// النصَّ نفسَه** — ⟵ **فيتحقق `FR-M19-03` بلا موضعِ انزلاق.**
///
/// ⛔⛔★★★ **ولا جمعَ بين حبّةٍ وكيلوجرام في أي إجمالي** (`GR-19` ·
/// `FR-M19-05` · `E-31`) — ★ **والإجمالياتُ تُبنى بـ[formatTotals] وحدها**،
/// ⟵ **وهي تفصل السطرين بنيوياً** ⛔ **فلا موضعَ لجمعٍ خاطئ أصلاً.**
/// ═══════════════════════════════════════════════════════════════════════
///
/// ⚠️ **ووسمُ «⟳ مُحدَّث بأثر رجعي» (`FR-M19-06`) ليس هنا — ولا يُختلَق:**
/// ★ **مصدرُه `retroUpdatedAt` في `daily_summaries`** (`reporting-design.md`
/// §2 القاعدة 5)، ⛔ **ولا كاتبَ له في النظام اليوم** — ⟵ **وتقاريرُ
/// `WU-011` الأحدَ عشرَ تقرأ الدفاتر والمستندات لا الملخصات**،
/// ★ **فيُبنى الوسمُ مع كاتبه في `WU-016` و`WU-021`** ⛔ **لا قبلَه بقيمةٍ
/// فارغةٍ دائماً تُري المستخدم وسماً لا يظهر أبداً.**
library;

import 'audit_entity_types.dart';
import 'export_documents.dart';
import 'message_templates.dart';
import 'report_catalog.dart';

/// عمودٌ في جدول التقرير.
final class ReportColumn {
  /// ينشئ العمود.
  const ReportColumn(this.label, {this.numeric = false});

  /// العنوان المعروض — **بالعربية من معجم المصطلحات**.
  final String label;

  /// ★ **هل قيمتُه رقمٌ يُعرَض بالأرقام الجدولية؟** — `design-system.md` §6.د.
  ///
  /// ⚠️ **وقرارٌ يصل الشاشةَ جاهزاً** ⛔ **لا تستنبطه بفحص النصّ** (§5.1).
  final bool numeric;
}

/// صفٌّ في جدول التقرير — **خلاياه بترتيب [ReportTable.columns]**.
final class ReportRow {
  /// ينشئ الصف.
  const ReportRow(this.cells, {this.isCancelled = false});

  /// الخلايا **نصّاً منسَّقاً مسبقاً**.
  final List<String> cells;

  /// ★★ **هل الحركةُ ملغاة؟** — ⛔ **تُعرَض ولا تُحذَف** (`GR-06` ·
  /// `ADR-0004`)، ★ **ولا تدخل أي إجمالي** (`A-14`).
  ///
  /// ⚠️ **والقرار يصل الشاشةَ حكماً جاهزاً** — ⛔ **ولا تقرأه من نصّ خلية.**
  final bool isCancelled;
}

/// ★★★ جدولُ تقريرٍ كامل — **ترويسةٌ وأعمدةٌ وصفوفٌ وإجماليات**.
final class ReportTable {
  /// ينشئ الجدول.
  const ReportTable({
    required this.report,
    required this.header,
    required this.columns,
    required this.rows,
    required this.totals,
    this.incompleteCount = 0,
  });

  /// التقرير الذي بُني منه.
  final ReportId report;

  /// ★ صفوفُ الترويسة — **الفترة وأي فلترٍ فعّال** ⛔ **بلا المصدر**.
  ///
  /// ⚠️⚠️ **والمصدر يُضاف أولَ صفٍّ في [buildReportExport] وحدَه** — ★ **كما
  /// تفعل `buildDistributionExport` و`buildReceiptExport` حرفياً**: ⟵ **وفي
  /// الشاشة يحمله شريطُ السياق الثابت** (`ui-guidelines.md` §2)،
  /// ⛔ **فكتابتُه هنا كانت ستُكرِّره في الملف مرتين.**
  ///
  /// ★★ **وفي الحالين هو معروضٌ دائماً** — `FR-M19-02` (`ui-guidelines.md`
  /// نمط 6: «**كل تقرير يُصرِّح بنطاق المصادر المشمول**»)، ⟵ **ورقمٌ بلا
  /// مصدره غيرُ مقروء** (`ADR-0005`).
  final List<ExportField> header;

  /// عناوين الأعمدة.
  final List<ReportColumn> columns;

  /// الصفوف.
  final List<ReportRow> rows;

  /// الإجماليات أسفل الجدول — ⛔ **والحبّاتُ والأوزانُ سطران لا سطر**.
  final List<ExportField> totals;

  /// ★★ عددُ المستندات ذات القيم الناقصة في الفترة — `FR-M19-08`.
  ///
  /// ⛔ **ولا يُحتسَب إلا حيث له مصدرٌ فعلي** — ★ **`unpricedLineCount`
  /// في التوزيعات** (`WU-006`)، ⟵ **وصفرٌ في غيرها** ⛔ **لا تقديرٌ.**
  final int incompleteCount;

  /// ★★ **تحذيرُ النواقص بنصّه المعتمد** — `FR-M19-08` · `§11.9` حرفياً.
  ///
  /// ⛔ **و`null` تعني «لا نواقص»** — ★ **فلا يُعرَض شريطٌ فارغ.**
  String? get incompleteWarning => incompleteCount == 0
      ? null
      : '⚠️ يوجد $incompleteCount مستند بقيم ناقصة ضمن هذه الفترة — '
          'الأرقام قد تكون غير نهائية';

  /// ★ عددُ الصفوف غير الملغاة — **وهي وحدها ما دخل الإجماليات** (`A-14`).
  int get countedRows => rows.where((ReportRow row) => !row.isCancelled).length;
}

/// ★★★ يبني المستندَ المُصدَّر من الجدول نفسِه — ⛔ **بلا إعادة حساب**.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★ **والخلايا تُنقَل كما هي حرفاً بحرف** — ★ **وهو ما يجعل الملفَّ
/// يطابق الشاشةَ رقماً برقم** (معيارُ قبول `WU-010` نفسُه): ⟵ **فلا دالةَ
/// تنسيقٍ ثانية بين الشاشة والملف** ⛔ **ولا موضعَ لافتراقهما.**
///
/// ★★ **واسمُ المصدر أوّلُ صفٍّ في الترويسة** — ⛔ **ولا يسقط**:
/// **حدُّ `CR-004` المُعتمَد محصورٌ في ترويسة الرسالة وحدها** (`WU-010`)،
/// ⟵ **والمستندُ المُصدَّر دليلٌ يُحفَظ ويُراجَع** ⛔ **ولا يُقرأ بلا مصدره.**
/// ═══════════════════════════════════════════════════════════════════════
///
/// ★ **و[entityId] رمزُ التقرير مع فترته** — ⟵ **فقيدُ «تصدير» يقول أيَّ
/// تقريرٍ خرج وعن أي مدى** (`FR-M19-04`)، ⛔ **لا «تقرير» مجرَّدةً.**
ExportableDocument buildReportExport({
  required MessageBusiness business,
  required ReportTable table,
  required String sourceId,
  required String sourceName,
  required String entityId,
}) =>
    ExportableDocument(
      businessName: business.businessName,
      title: table.report.title,
      header: <ExportField>[
        ExportField('المصدر', sourceName),
        ...table.header,
      ],
      columns: <String>[
        for (final ReportColumn column in table.columns) column.label,
      ],
      rows: <ExportRow>[
        for (final ReportRow row in table.rows) ExportRow(row.cells),
      ],
      totals: table.totals,
      entityType: reportEntityType,
      entityId: entityId,
      sourceId: sourceId,
    );

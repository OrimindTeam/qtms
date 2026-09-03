/// المستند المُصدَّر — ★★ **بنيةٌ خالصة يبنيها النطاق ويرسمها التطبيق**.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **ولماذا في النطاق لا في طبقة العرض — وهو معيارُ قبول `WU-010`
/// حرفياً:** «**المستند المُصدَّر يطابق ما تعرضه الشاشة رقماً برقم**».
///
/// ⟵ ★ **فلو بنى راسمُ الـPDF أرقامَه بنفسه لصارت للقيمة الواحدة صيغتان**
/// — **واحدةٌ في الرسالة وأخرى في الملف** — ⛔ **وافترقتا عند أول حالةٍ
/// حدّية** (فاصلُ آلافٍ · وزنٌ بثلاث خانات · سطرٌ غير مسعَّر).
/// ★ **وهنا تُبنى النصوص مرةً واحدة** بالدوال نفسِها التي تبني الرسالة
/// (`message_templates.dart`)، ⟵ **والراسم يضع نصّاً جاهزاً لا يحسبه.**
/// ═══════════════════════════════════════════════════════════════════════
///
/// ⛔⛔★★ **ولا بصمةَ جهة التطوير في أي حقلٍ هنا** — ★ **هذه مخرجات العميل
/// لعملائه** (`messaging-design.md` §8 · `FR-SYS-30` ·
/// `developer-identity-placement.md` §5): ⟵ **والمخرَجُ المُصدَّر لعملاء
/// العميل من الممنوعات الثمانية نصّاً.**
library;

import '../../../core/money.dart';
import '../../inventory/domain/inventory.dart';
import 'audit_entity_types.dart';
import 'message_templates.dart';

/// صفٌّ مفتاح-قيمة في ترويسة المستند أو في إجمالياته.
final class ExportField {
  /// ينشئ الصف.
  const ExportField(this.label, this.value);

  /// التسمية — ★ **بالعربية من معجم المصطلحات** (`ui-guidelines.md` §6).
  final String label;

  /// القيمة **نصّاً منسَّقاً مسبقاً** — ⛔ **ولا رقمَ خام يُنسِّقه الراسم.**
  final String value;
}

/// صفٌّ في جدول المستند — **خلاياه نصوصٌ جاهزة**.
final class ExportRow {
  /// ينشئ الصف بخلاياه.
  const ExportRow(this.cells);

  /// الخلايا **بترتيب [ExportableDocument.columns]**.
  final List<String> cells;
}

/// مستندٌ جاهزٌ للتصدير — ★ **بلا أي معرفةٍ بصيغة الملف**.
final class ExportableDocument {
  /// ينشئ المستند.
  const ExportableDocument({
    required this.businessName,
    required this.title,
    required this.header,
    required this.columns,
    required this.rows,
    required this.totals,
    required this.entityType,
    required this.entityId,
    required this.sourceId,
    this.documentNumber,
  });

  /// اسم المحل — **من الإعداد التأسيسي** (`FR-M21-01`).
  final String businessName;

  /// عنوان المستند — «سند توزيع» · «سند قبض» · «سند خصم».
  final String title;

  /// صفوف الترويسة (التاريخ · المقوت · رقم السند).
  final List<ExportField> header;

  /// عناوين أعمدة الجدول.
  final List<String> columns;

  /// صفوف الجدول.
  final List<ExportRow> rows;

  /// الإجماليات أسفل الجدول.
  final List<ExportField> totals;

  /// ★ نوع الكيان — **يُرسَل إلى `logExport`** (`FR-M19-04`).
  final String entityType;

  /// ★ معرّف الكيان — **يُرسَل إلى `logExport`**.
  final String entityId;

  /// ★ المصدر — **ويُقاس عليه النطاق في العملية السحابية** (`GR-23`).
  final String sourceId;

  /// رقم المستند إن كان مرقَّماً.
  final String? documentNumber;
}

/// ★★ يبني مستند التوزيع القابل للتصدير — **من بيانات الرسالة نفسِها**.
///
/// ★ **و[withPricing] هو نفسُ تمييز القالبين ① و②** — ⟵ **فمن لا يرى
/// الأسعار في الشاشة لا تظهر في ملفه** (`ت-12` · `FR-M10-07`).
ExportableDocument buildDistributionExport({
  required MessageBusiness business,
  required DistributionMessageData data,
  required String sourceId,
  required String sourceName,
  required String entityId,
  required bool withPricing,
}) {
  final String separator = business.thousandsSeparator;
  return ExportableDocument(
    businessName: business.businessName,
    title: 'سند توزيع',
    header: <ExportField>[
      // ★★★ **والمصدر يبقى هنا صراحةً** — **نطاق `CR-004` المُعتمَد
      //    محصورٌ في ترويسة الرسالة وحدها** (2026-08-30 · المالك نصّاً)،
      //    ⛔ **ولا يمتدّ إلى المستند المُصدَّر** — ★ **فهو دليلٌ يُحفَظ ويُراجَع**،
      //    ⟵ **والحسابات مفصولةٌ بالمصدر** (`ADR-0005`) ⛔ **فلا يُقرأ بلا مصدره.**
      //    ★ **ومطابقةُ الرسالة مطابقةُ أرقام لا تطابقُ ترويسة** — ⛔ **ولا رقمَ
      //    هنا يُحسَب مرتين** (`WU-010` · معيار القبول حرفياً).
      ExportField('المصدر', sourceName),
      ExportField('تاريخ المخزون', data.stockDate.formatReadable()),
      ExportField('المقوت', data.dealerName),
    ],
    columns: withPricing
        ? const <String>['النوع', 'الكمية', 'سعر الوحدة', 'القيمة']
        : const <String>['النوع', 'الكمية'],
    rows: <ExportRow>[
      for (final MessageLine line in data.lines)
        ExportRow(<String>[
          line.itemName,
          formatQuantity(line.quantity),
          if (withPricing) ...<String>[
            // ★ **«غير مسعَّر» نصّاً** ⛔ **لا صفراً** (`FR-M10-08`).
            if (line.unitPrice case final Money price)
              formatRiyals(price, thousandsSeparator: separator)
            else
              'غير مسعَّر',
            if (line.lineTotal case final Money total)
              formatRiyals(total, thousandsSeparator: separator)
            else
              'غير مسعَّر',
          ],
        ]),
    ],
    totals: <ExportField>[
      // ★★★ **والإجماليُّ يتبع الرسالة حرفياً** — `AM-012` §4.3 · [`CR-011`]:
      //
      // ⛔⛔★★★ **ومعيارُ قبول `WU-010` هو السبب لا الذوق:** «**المستندُ
      //    المُصدَّر يطابق الرسالة رقماً برقم**» — ⟵ **وبقاؤه على
      //    `formatTotals` كان يجعل المستندَ يقول «60 حبة + 0.500 كجم»
      //    والرسالةَ تقول سطرين مسمَّيين** ⛔ **فيفترق ما يقرؤه العميل**
      //    (⚠️ **رصده اختبارُ المطابقة فعلاً لحظةَ التنفيذ**).
      //
      // ★ **والمحصّلةُ واحدة يقرؤها الاثنان** ⛔ **لا حلقةُ جمعٍ ثانية.**
      ExportField('الإجمالي', _lineTotals(data).countLabel),
      // ⛔ **وسطرُ السكرب عند وجوده وحده** — ★ **كما في الرسالة تماماً.**
      if (_lineTotals(data).hasScrap)
        ExportField(scrapTotalLabel, _lineTotals(data).scrapLabel),
      if (withPricing) ...<ExportField>[
        ExportField(
          'ضمار اليوم',
          formatRiyals(data.debtValue, thousandsSeparator: separator),
        ),
        ExportField(
          'الرصيد السابق',
          formatRiyals(data.previousBalance, thousandsSeparator: separator),
        ),
        ExportField(
          'الرصيد الحالي',
          formatRiyals(data.currentBalance, thousandsSeparator: separator),
        ),
      ],
    ],
    entityType: distributionEntityType,
    entityId: entityId,
    sourceId: sourceId,
  );
}

/// ★ محصّلةُ كميات سطور التوزيعة — ⛔ **ولا حلقةَ جمعٍ في بناء المستند**.
QuantityTotals _lineTotals(DistributionMessageData data) =>
    accumulateTotals(<StockQuantity>[
      for (final MessageLine line in data.lines) line.quantity,
    ]);

/// ★ يبني سند القبض القابل للتصدير.
ExportableDocument buildReceiptExport({
  required MessageBusiness business,
  required ReceiptMessageData data,
  required String sourceId,
  required String sourceName,
}) {
  final String separator = business.thousandsSeparator;
  return ExportableDocument(
    businessName: business.businessName,
    title: 'سند قبض',
    header: <ExportField>[
      // ★★ **والمصدر في السند كذلك** — نطاق `CR-004` المُعتمَد أعلاه.
      //    ★ **وسندُ ما لا يخصّ مصدراً بعينه يُنسَب «كل المصادر»**
      //    — **كما ينسُبه كاتبُ القيد نفسُه** (`auditAllSourcesId`).
      ExportField('المصدر', sourceName),
      ExportField('رقم السند', data.documentNumber),
      ExportField('التاريخ', data.paidOn.formatReadable()),
      ExportField('المقوت', data.dealerName),
    ],
    columns: const <String>['الضمار', 'المسدَّد', 'المتبقي'],
    rows: <ExportRow>[
      for (final SettledDebtLine line in data.settledLines)
        ExportRow(<String>[
          line.stockDate.formatReadable(),
          formatRiyals(line.amount, thousandsSeparator: separator),
          formatRiyals(line.remainingAfter, thousandsSeparator: separator),
        ]),
    ],
    totals: <ExportField>[
      ExportField(
        'إجمالي المقبوض',
        formatRiyals(data.totalPaid, thousandsSeparator: separator),
      ),
      ExportField(
        'الرصيد بعد السداد',
        formatRiyals(data.balanceAfter, thousandsSeparator: separator),
      ),
    ],
    entityType: receiptEntityType,
    entityId: data.documentNumber,
    sourceId: sourceId,
    documentNumber: data.documentNumber,
  );
}

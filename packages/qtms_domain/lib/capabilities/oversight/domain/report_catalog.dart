/// كتالوج التقارير — ★ **نقل حرفي لـ`FR-M19` §2 و`reporting-design.md` §3**.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **ولا يحمل هذا الملف إلا ما له تقريرٌ مبنيٌّ فعلاً** — ★ **بنفس
/// قاعدة `auditEntityTypes` و`PendingDocumentKind` حرفياً:** «⛔ **لا تُضاف
/// قيمة بلا كاتبٍ لها فعلاً**». ⟵ **فقائمةٌ تعرض تقريراً لا بيانات له
/// تُري المستخدم فراغاً يظنّه عطلاً**، ★ **والأحد عشر هنا هي نطاق `WU-011`
/// نصّاً** (`implementation-plan.md`) ⛔ **والبقيةُ تُضاف في زياداتها.**
///
/// ★★ **والعائلاتُ الستُّ هي تصنيف `FR-M19` §2 نفسُه** — ⛔ **لا تصنيفٌ
/// مُخترَع: `IQ-034` الخيار ب (2026-08-30) جعل لكلِّ عائلةٍ مفتاحَ صلاحية**،
/// ⟵ **فالعائلةُ عقدُ تفويضٍ لا ترويسةُ عرض.**
/// ═══════════════════════════════════════════════════════════════════════
///
/// ⚠️ **ورمزُ التقرير (`R-01`) معرّفٌ داخلي لا نصُّ واجهة** — ★ **يُكتب في
/// `entityId` عند التصدير** (`FR-M19-04`)، ⛔ **ولا يُعرَض في شاشة**
/// (`ui-guidelines.md` §6: **لا كلمة إنجليزية في أي شاشة**).
library;

import '../../identity_access/domain/permission.dart';

/// عائلةُ تقارير — ★ **ولكلٍّ مفتاحُ صلاحيةٍ مستقل** (`IQ-034` الخيار ب).
///
/// ⚠️⚠️ **و«لكلِّ تقريرٍ على حدة» في `FR-M19` §4 تُقرأ قراءةً موسَّعة** —
/// ★ **أثرٌ معلَنٌ في `reporting-design.md` §6** ⛔ **لا مسكوتٌ عنه:**
/// ⟵ **فمن يرى «المخزنية» يرى `R-01`…`R-07` كلَّها.**
enum ReportFamily {
  /// مخزنية — `R-01`…`R-07`.
  inventory(Permission.reportInventoryView, 'التقارير المخزنية'),

  /// بيعية — `R-08`…`R-13`.
  sales(Permission.reportSalesView, 'التقارير البيعية'),

  /// مالية — `R-14`…`R-20`.
  financial(Permission.reportFinancialView, 'التقارير المالية'),

  /// السحبيات والخرجيات — `R-21`…`R-24`.
  outflow(Permission.reportOutflowView, 'تقارير السحبيات والخرجيات'),

  /// الرعية — `R-25`…`R-27`.
  supplier(Permission.reportSupplierView, 'تقارير الرعية'),

  /// رقابية — `R-28`…`R-31`.
  oversight(Permission.reportOversightView, 'التقارير الرقابية');

  const ReportFamily(this.requiredPermission, this.label);

  /// ★ المفتاح الذي لا تُفتَح تقاريرُ العائلة بدونه.
  ///
  /// ⚠️⚠️ **وهو بوابةُ وصولٍ إلى الشاشة** — ★ **وسريّةُ الأرقام نفسِها
  /// يحرسها شرطُ قراءةِ كلِّ مجموعةٍ ونطاقُ المصادر** (`GR-23`)،
  /// ⛔ **فلا يُقرأ هذا المفتاح ضماناً لما لا تضمنه القاعدة**
  /// (`permissions-catalog.md` §2.11 · `RISK-02`).
  final Permission requiredPermission;

  /// ★ الاسم المعروض — **من `FR-M19` §2 حرفياً**.
  final String label;
}

/// ★★ التقارير المبنيّة فعلاً — **أحدَ عشرَ تقريراً من `WU-011`**.
///
/// ⛔ **ولا يُضاف عضوٌ هنا قبل بناء بانيه ومصدرِ بياناته** — راجع ترويسة
/// الملف.
enum ReportId {
  /// `R-01` — حركة نوع تفصيلية · **النوع والفترة** (`FR-M19` §2).
  itemMovements('R-01', 'حركة نوع تفصيلية', ReportFamily.inventory),

  /// `R-02` — رصيد المخزون الحالي · **النوع والحالة**.
  currentStock('R-02', 'رصيد المخزون الحالي', ReportFamily.inventory),

  /// `R-03` — الوارد عدداً · **الفترة والنوع والرعوي**.
  countedIntakes('R-03', 'الوارد عدداً', ReportFamily.inventory),

  /// `R-04` — الوارد جواني · **الفترة والرعوي والجونية**.
  sackIntakes('R-04', 'الوارد جواني', ReportFamily.inventory),

  /// `R-05` — متبقي اليوم لكل نوع · **التاريخ والنوع**.
  todayRemainder('R-05', 'متبقي اليوم لكل نوع', ReportFamily.inventory),

  /// `R-08` — التوزيعات التفصيلية · **الفترة والمقوت والنوع**.
  distributions('R-08', 'التوزيعات التفصيلية', ReportFamily.sales),

  /// `R-10` — الضمارات · **الفترة والمقوت والحالة**.
  settlements('R-10', 'الضمارات', ReportFamily.sales),

  /// `R-14` — المقبوضات · **الفترة والمستخدم وحالة الإيداع**.
  receipts('R-14', 'المقبوضات', ReportFamily.financial),

  /// `R-17` — أرصدة المقاوته · **الحالة والحد الأدنى للرصيد**.
  dealerBalances('R-17', 'أرصدة المقاوته', ReportFamily.financial),

  /// `R-19` — كشف حساب مقوت · **المقوت والفترة**.
  dealerStatement('R-19', 'كشف حساب مقوت', ReportFamily.financial),

  /// `R-28` — الإدخالات المعلّقة · **النوع والفترة**.
  pendingEntries('R-28', 'الإدخالات المعلّقة', ReportFamily.oversight);

  const ReportId(this.code, this.title, this.family);

  /// ★ الرمز المعتمد في `FR-M19` §2 — ⛔ **معرّفٌ لا نصُّ واجهة**.
  final String code;

  /// ★ العنوان المعروض — **من `FR-M19` §2 حرفياً**.
  final String title;

  /// العائلة — ★ **ومنها مفتاحُ الصلاحية**.
  final ReportFamily family;

  /// ★ يقرأ التقرير من رمزه — و`null` **لرمزٍ لا يعرفه هذا الإصدار**.
  ///
  /// ⛔ **ولا يُقرأ بافتراضٍ آمن:** ★ **رمزٌ مجهول يُعرَض غياباً صريحاً**
  /// ⛔ **ولا يُفتَح على تقريرٍ آخر** (نفس منطق `PendingDocumentKind.tryParse`).
  static ReportId? tryParse(String? raw) {
    for (final ReportId report in ReportId.values) {
      if (report.code == raw) return report;
    }
    return null;
  }
}

/// ★★ تقاريرُ عائلةٍ واحدة — **بترتيب `FR-M19` §2**.
List<ReportId> reportsOfFamily(ReportFamily family) => <ReportId>[
      for (final ReportId report in ReportId.values)
        if (report.family == family) report,
    ];

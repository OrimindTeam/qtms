/// أنواع الكيانات في سجل التدقيق — ★ **مصدر حقيقة واحد يشاركه التطبيق
/// والسحابة** (`ADR-0012`).
///
/// ★★ **والأسماء من معجم `naming-conventions.md` §2 حرفياً** — `source` ·
/// `supplier` · `dealer` · `item` · `sack` · `user` — ⛔ **ولا مرادف
/// مُخترَع** (`vendor` بدل `supplier`، `batch` بدل `sack`).
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⚠️⚠️ **ولماذا انتقلت إلى هنا في `WU-008` — وهي كانت في `functions/`:**
///
/// القيمة تُكتب في السحابة **وتُقرأ في التطبيق**: `FR-M18-10` يجعل السجل
/// السياقي يستعلم بـ`entityType` + `entityId`، ⟵ **فلو بقيت الثوابت في
/// `functions/` وحدها لَلَزِمَت نسخةٌ ثانية منها في التطبيق** — ⛔ **وهو
/// حرفياً ما يمنعه `coding-standards.md` §2.2** (مصدر حقيقة واحد).
///
/// ★★ **وأثرُ الانزلاق صامتٌ تماماً:** حرفٌ مختلف بين الكاتب والقارئ
/// **لا يُنتج خطأً** — ⟵ **بل سجلاً سياقياً فارغاً أبداً** يبدو «لا تاريخ
/// لهذا المستند»، ★ **وهو أسوأ عطلٍ ممكن في الحافظ الوحيد للتاريخ**
/// (`RISK-05`).
/// ═══════════════════════════════════════════════════════════════════════
library;

/// المصدر — `M2`.
const String sourceEntityType = 'source';

/// الرعوي — `M3`.
const String supplierEntityType = 'supplier';

/// المقوت — `M4`.
const String dealerEntityType = 'dealer';

/// النوع — `M5`.
const String itemEntityType = 'item';

/// الإعداد التأسيسي — `M21`.
const String appSettingsEntityType = 'appSettings';

/// الوارد عدداً — `M6`.
const String countedIntakeEntityType = 'countedIntake';

/// الجونية — `M7`.
const String sackEntityType = 'sack';

/// سعر اليوم — `M9`.
///
/// ★ **ومعرّفه `{sourceId}_{date}` لا رقم مستند** — `daily_prices` **بلا
/// `documentNumber`** (`schema/daily-prices.md`).
const String dailyPriceEntityType = 'dailyPrice';

/// ★ التوزيعة (الضمار) — `M10`.
///
/// ⚠️ **ومعرّفها المركّب `{dealerId}_{sourceId}_{stockDate}` لا رقم المستند**
/// — ★ **والسجل السياقي 🕘 يستعلم به** (`FR-M18-10`)، ⟵ **فهو ما يُكتب في
/// `entityId`** ⛔ **لا `documentNumber`.**
const String distributionEntityType = 'distribution';

/// ★ سند القبض — `M12` (`WU-007`).
///
/// ⚠️ **ومعرّفه رقم المستند `RCP-YYYYMMDD-####`** — ★ **بخلاف
/// [distributionEntityType] الذي معرّفه مركّب**: ⟵ **لأن `receipts` مفتاحُها
/// `documentNumber` نفسُه** (`schema/receipts.md`)، ★ **والسجل السياقي 🕘
/// يستعلم بما يُفتَح به المستند فعلاً** (`FR-M18-10`).
const String receiptEntityType = 'receipt';

/// ★★ التقرير — `M19` (`WU-011`).
///
/// ⛔⛔★★ **ونوعٌ لا مستندَ له في القاعدة — وهو مقصود:** ★ **التقريرُ مشتقٌّ
/// يُبنى عند الطلب** (`ADR-0008`) ⛔ **ولا يُخزَّن**، ⟵ **والقيدُ الوحيد الذي
/// يخصّه قيدُ «تصدير»** (`FR-M19-04`) — ★ **وهو أصلاً أولُ قيدٍ بلا مستندٍ
/// مصاحب في النظام** (`export_log.dart`).
///
/// ★ **و`entityId` رمزُ التقرير مع فترته** (`R-08:20260801-20260831`) —
/// ⟵ **فالسجلُّ السياقي 🕘 يجمع تصديراتِ تقريرٍ بعينه** ⛔ **لا كلَّ تصدير.**
const String reportEntityType = 'report';

/// ★ سند البيع النقدي — `M11` (`WU-012`).
///
/// ⚠️ **ومعرّفه رقم المستند `CSH-YYYYMMDD-####`** — ★ **بخلاف
/// [distributionEntityType] الذي معرّفه مركّب**: ⟵ **لأن `cash_sales`
/// مفتاحُها `documentNumber` نفسُه** (`schema/cash-sales.md`)، ★ **والسجل
/// السياقي 🕘 يستعلم بما يُفتَح به المستند فعلاً** (`FR-M18-10`).
const String cashSaleEntityType = 'cashSale';

/// المستخدم — `M1`.
const String userEntityType = 'user';

/// قالب الدور — `M1`.
const String roleEntityType = 'role';

/// ★ كل الأنواع المكتوبة اليوم — ⛔ **ولا تُضاف قيمة بلا كاتبٍ لها فعلاً**.
///
/// ⚠️ **والقائمة تُستكمَل في زيادة كل مستند** (نفس قاعدة `SourceDocumentType`
/// في `inventory.dart`) — ⛔ **ولا تُملأ استباقاً بأنواعٍ لا قيدَ لها**،
/// ★ **فقائمةُ فلترةٍ تعرض نوعاً بلا سجل تُري المستخدم فراغاً يظنّه عطلاً.**
const List<String> auditEntityTypes = <String>[
  sourceEntityType,
  supplierEntityType,
  dealerEntityType,
  itemEntityType,
  appSettingsEntityType,
  countedIntakeEntityType,
  sackEntityType,
  dailyPriceEntityType,
  distributionEntityType,
  // ⚠️★★ **أُضيف في `WU-010` (2026-08-30) — ⛔ ولم يكن ناقصاً استباقاً بل سهواً:**
  //    ★ **`receipt.dart:958` يكتب `entityType: receiptEntityType` منذ `WU-007`**
  //    ⟵ **فللقيمة كاتبٌ فعلي**، ⛔ **وغيابُها عن القائمة يخالف قاعدة الملف
  //    نفسِها** («لا تُضاف قيمة بلا كاتبٍ لها فعلاً» — ★ **والعكس لازمٌ منها**).
  //    ★ **ورصده أولُ مستهلكٍ للقائمة**: حارسُ `planExportLog` كان يرفض تصدير
  //    كل سند قبض (`IQ-032`) — ⟵ **وهو مثالٌ آخر على أن قائمةً بلا قارئ
  //    لا يحرسها شيء.**
  receiptEntityType,
  // ⚠️★★ **أُضيف في `WU-011` (2026-08-31) — ★ وله كاتبٌ فعلي في نفس الزيادة:**
  //    ★ **`buildReportExport` يكتبه في `entityType`**، ⟵ **والعمليةُ
  //    `logExport` تحرس القائمةَ نفسَها** (`planExportLog` البند ⑤):
  //    ⛔ **فبلا هذا السطر يُرفَض تصديرُ كل تقرير** — ★ **وهو حرفياً ما
  //    وقع لسند القبض في `WU-010`.**
  reportEntityType,
  // ⚠️★★ **أُضيف في `WU-012` (2026-09-01) — ★ وله كاتبٌ فعلي في نفس الزيادة:**
  //    ★ **`cash_sale.dart` يكتبه في `entityType` لكل إنشاءٍ وتعديلٍ وإلغاء**،
  //    ⟵ **وحارسُ `planExportLog` يقرأ هذه القائمةَ نفسَها** (`IQ-032`):
  //    ⛔ **فبلا هذا السطر يُرفَض تصديرُ كل سند بيعٍ نقدي** — ★ **وهو حرفياً
  //    ما وقع لسند القبض في `WU-010` وللتقرير في `WU-011`.**
  cashSaleEntityType,
  userEntityType,
  roleEntityType,
];

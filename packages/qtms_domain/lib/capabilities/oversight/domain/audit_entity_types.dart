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
  userEntityType,
  roleEntityType,
];

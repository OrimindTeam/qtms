/// كتالوج مفاتيح الصلاحيات — **نقل حرفي لـ`permissions-catalog.md` §2**.
///
/// ★ **المستند هو المصدر الوحيد للمفاتيح** (§0): «أي مفتاح يظهر في قواعد
/// الحماية أو في مزامن الصلاحيات أو في التطبيق **ولا سطر له هنا ⟵ يُرفَض في
/// المراجعة**» (`BR-M1-07`).
///
/// ★ **واسم القيمة هو المفتاح حرفياً** — فـ`Permission.sackView.name` يُنتج
/// `'sackView'` تماماً كما تقرأه قاعدة الحماية في
/// `request.auth.token.permissions.sackView`. ⛔ **فلا جدول تحويل بين
/// الاسم والمفتاح**، ولا موضع ينزلق فيه أحدهما عن الآخر.
///
/// ⚠️ **ويحرس التطابقَ مع المستند اختبارٌ آلي في الاتجاهين**
/// (`permission_test.dart`) — فلا مفتاح هنا بلا سطر هناك، ولا العكس.
library;

/// مفاتيح الصلاحيات الأربعة والسبعون المعتمدة.
///
/// ★ **والتسعة الأخيرة إدارية بحتة** — أُضيفت بجواب `IQ-007` (الخيار أ،
/// 2026-08-22). ⚠️ **وهي لا تنقض `BR-M1-08`** («منح صلاحية أو سحبها: من
/// العملية السحابية حصراً — ولا مفتاح يُتيحه من التطبيق»): الكتابة المباشرة
/// على `users` و`roles` تبقى `allow write: if false` في قواعد الحماية.
/// ★ **ما تُصرِّح به هذه المفاتيح هو استدعاء العملية السحابية نفسها** —
/// وتفحصها الدالة في الكود صراحةً (`ADR-0013` القاعدة 3).
///
/// ⚠️ **ولذلك هي المفاتيح الوحيدة بلا شرط في `firestore.rules`** — مستثناة
/// بمبرر موثَّق في `permissions-catalog.md` §5، **لأن مسارها سحابي لا قاعدي**.
enum Permission {
  // ── البيانات الأساسية (6) ──
  sourceWrite,
  supplierWrite,
  dealerWrite,
  // ★★ **صلاحية مستقلة لا بديلٌ عن `dealerWrite`** — `FR-M4-09` · `IQ-020`
  //    الخيار أ (2026-08-25). ⛔ **ولا تُغني عنها**: تعطيلُ مقوتٍ رصيدُه ≠ 0
  //    يشترط **الثلاثة معاً** — `dealerWrite` + هذه + إقرارٌ نصّي غير فارغ،
  //    ★ **والرصيد يُقاس داخل المعاملة** لا من الجهاز.
  dealerDisableWithBalance,
  itemWrite,
  appSettingsWrite,
  // ── التوريد (9) ──
  incomingCountWrite,
  // ★★ **مفتاح إنشاء رأس الجونية** — `FR-M7` §5 · `UC-001` · `IQ-021`
  //    الخيار أ (2026-08-26). ⛔ **ولا يُغني عنه مفتاحٌ حقلي**: مفاتيح
  //    `sack*Enter` **مساراتٌ تقتصر على حقلٍ واحد** (`§9.6`)، ⟵ **وإنشاءُ
  //    المستند كاملاً امتيازٌ آخر.** ⛔ **ولا `sackView`** — **صلاحيةُ قراءة**.
  //    ★ **وينطبق كذلك على «إضافة جونية من إدارة الجواني»** (`FR-M14-11`).
  sackCreate,
  sackView,
  sackTaxEnterNow,
  sackTaxEnterLater,
  sackRenameDisplay,
  sackLinesEnter,
  sackScrapWeightEnter,
  sackLostWeightConfirm,
  // ── التسعير والصرف (9) ──
  dailyPriceWrite,
  distributionCreate,
  distributionPriceNow,
  distributionPriceAmend,
  distributionPriceClear,
  distributionPriceView,
  cashSaleCreate,
  cashSaleBelowMinimum,
  agedRemainderClear,
  // ── الإتلاف والجرد (2) ──
  disposalCreate,
  stocktakeWrite,
  // ── التحصيل والذمم (6) ──
  receiptCreate,
  receiptBackdate,
  receiptDepositView,
  receiptDepositConfirm,
  discountCreate,
  dealerBalanceView,
  // ── السحبيات والخرجيات (5) ──
  withdrawalCreate,
  expenseCreate,
  withdrawalQatPriceNow,
  withdrawalView,
  expenseView,
  // ── المالية والرقابة (7) ──
  sackFinanceView,
  supplierFinanceView,
  ownerLedgerView,
  allSourcesCardView,
  sourceNetImpactView,
  auditLogViewCentral,
  auditLogViewContextual,
  // ── الإرسال (1) ──
  messagingSend,
  // ── التعديل والإلغاء (20) ──
  incomingCountAmend,
  incomingCountCancel,
  sackAmend,
  sackCancel,
  distributionAmend,
  distributionCancel,
  cashSaleAmend,
  cashSaleCancel,
  receiptAmend,
  receiptCancel,
  discountAmend,
  discountCancel,
  withdrawalAmend,
  withdrawalCancel,
  expenseAmend,
  expenseCancel,
  stocktakeAmend,
  stocktakeCancel,
  disposalAmend,
  disposalCancel,
  // ── إدارة الهوية والوصول (9) — ★ `IQ-007` الخيار أ ──
  // ⛔ مسارها **العملية السحابية وحدها** — ولا شرط لها في قواعد الحماية.
  userView,
  userCreate,
  userAmend,
  userDisable,
  roleAssign,
  permissionGrant,
  sourceScopeSet,
  roleWrite,
  roleDelete,
}

/// المفاتيح الإدارية التسعة — ★ **يُفحَص امتلاكها في الدالة السحابية لا في
/// قواعد الحماية** (`ADR-0013` القاعدة 3 · `IQ-007`).
///
/// ★ **ولماذا مجموعة مسمّاة لا قائمة تُكرَّر في كل مُستدعٍ:** لأن نسخة ثانية
/// منها تفترق عند أول إضافة — وهو ما يمنعه `BR-M1-07` نفسه.
const Set<Permission> identityAccessAdminPermissions = <Permission>{
  Permission.userView,
  Permission.userCreate,
  Permission.userAmend,
  Permission.userDisable,
  Permission.roleAssign,
  Permission.permissionGrant,
  Permission.sourceScopeSet,
  Permission.roleWrite,
  Permission.roleDelete,
};

/// ★★★ **ما يمنحه إقلاعُ المالك — كلُّ مفاتيح الكتالوج** (`IQ-023` الخيار أ).
///
/// ⚠️⚠️ **ولماذا الكلُّ لا التسعةُ الإدارية وحدها — عطلٌ رُصد حيّاً (2026-08-26):**
/// `BR-M1-03` **تسقُف المنح بصلاحيات المُنفِّذ**، ★ **و`FR-M1-08` تمنعه من منح
/// نفسه.** ⟵ **فمالكٌ بالتسعة الإدارية وحدها لا يستطيع أن يمنح أحداً أيَّ
/// صلاحيةٍ تشغيلية أبداً**، ⛔ **ولا أحدَ غيرَه يملكها ليمنحها** — ★ **والأدوارُ
/// قوالبُ لا تمنح.** ⟹ ⛔ **فلا بيعَ ولا مخزونَ ولا تسعيرَ لأحدٍ في أي بيئة.**
///
/// ★★ **والمالك جذرُ شجرة الصلاحيات** — ⟵ **و`BR-M1-03` تبقى ساريةً كما هي
/// حرفياً على كلِّ من دونه**، ⛔ **ولم تُستثنَ ولم تُخفَّف.**
const Set<Permission> ownerBootstrapPermissions = <Permission>{
  ...Permission.values,
};

/// كل المفاتيح كنصوص — كما تُكتب في مطالبات رمز الدخول وفي قواعد الحماية.
Set<String> get allPermissionKeys =>
    Permission.values.map((Permission p) => p.name).toSet();

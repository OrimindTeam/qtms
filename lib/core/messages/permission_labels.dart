/// أسماء الصلاحيات المعروضة — ★ **نقلٌ حرفي لـ`permissions-catalog.md` §2**.
///
/// ★★ **المصدر والمُلزِم:** §0 من الكتالوج: «**هذا المستند هو المصدر الوحيد
/// للمفاتيح**»، ★ **ووصفُ كل مفتاح فيه هو نصّه المعروض هنا حرفاً بحرف** —
/// ⛔ **ولا صياغة جديدة ولا اختصار ولا مرادف** (`ui-guidelines.md` §6:
/// «لا مصطلح تقني في واجهة المستخدم» — ⟵ **فلا يُعرَض `sackView` خاماً**).
///
/// ⚠️ **ومفاتيح §2.9 (التعديل والإلغاء) وصفُها مركّب من عمودَي جدولها**:
/// «نوع المستند» + الفعل — ★ **كما يقرؤها الجدول نفسه**، ⛔ لا كما نصوغها.
///
/// ★★ **ويحرس التطابقَ اختبارٌ آلي في الاتجاهين** (`permission_labels_test.dart`):
/// ⛔ **لا مفتاح في [Permission] بلا اسم هنا، ولا اسم هنا بلا مفتاح** — ⟵
/// **فصلاحيةٌ تُضاف غداً تُسقِط الاختبار** بدل أن تظهر للمدير بمفتاحها الخام.
library;

import 'package:qtms_domain/qtms_domain.dart';

/// مجموعة صلاحيات كما يعرضها الكتالوج — ★ **بترتيبه هو**.
final class PermissionGroup {
  /// ينشئ المجموعة.
  const PermissionGroup({required this.title, required this.permissions});

  /// عنوان المجموعة كما في `permissions-catalog.md` §2.
  final String title;

  /// مفاتيحها **بترتيب الكتالوج** — ⛔ لا بترتيب أبجدي يفرّق المتشابهات.
  final List<Permission> permissions;
}

/// ★ الاسم المعروض لكل مفتاح — **من الكتالوج حرفياً**.
///
/// ⛔ **والدالة شاملة بلا نمط `_`** — ★ **فالتصريف هو الحارس**: مفتاحٌ يُضاف
/// إلى [Permission] بلا سطر هنا **يُسقِط البناء** ⛔ ولا يظهر خاماً للمدير.
String permissionLabel(Permission permission) => switch (permission) {
      // ── البيانات الأساسية (5) ──
      Permission.sourceWrite => 'المصادر',
      Permission.supplierWrite => 'الرعية',
      Permission.dealerWrite => 'المقاوته',
      Permission.dealerDisableWithBalance => 'تعطيل مقوت له رصيد',
      Permission.itemWrite => 'الأنواع',
      Permission.appSettingsWrite => 'كتابة الإعداد التأسيسي',
      // ── التوريد (9) ──
      Permission.incomingCountWrite => 'الوارد عدداً',
      Permission.sackCreate => 'إضافة جونية',
      Permission.sackView => 'عرض الجواني',
      Permission.sackTaxEnterNow => 'إدخال الضريبة الآن',
      Permission.sackTaxEnterLater => 'إدخال الضريبة لاحقاً',
      Permission.sackRenameDisplay => 'تعديل اسم الجونية',
      Permission.sackLinesEnter => 'إدخال أنواع الجونية',
      Permission.sackScrapWeightEnter => 'إدخال وزن السكرب',
      Permission.sackLostWeightConfirm => 'تأكيد الوزن الضائع',
      // ── التسعير والصرف (9) ──
      Permission.dailyPriceWrite => 'التسعير اليومي',
      Permission.distributionCreate => 'إضافة توزيعة',
      Permission.distributionPriceNow => 'تسعير التوزيع الآن',
      Permission.distributionPriceAmend => 'تعديل سعر التوزيع',
      Permission.distributionPriceClear => 'تفريغ سعر التوزيع',
      Permission.distributionPriceView => 'عرض أسعار التوزيع وإجمالياته',
      Permission.cashSaleCreate => 'إضافة بيع نقدي',
      Permission.cashSaleBelowMinimum => 'البيع دون الحد الأدنى',
      Permission.agedRemainderClear => 'تصريف المتبقي المتأخر',
      // ── الإتلاف والجرد (5) ── ★ **وثلاثةُ `WU-022` يُسمّيها `FR-M16` §3**
      Permission.disposalCreate => 'الإتلاف',
      Permission.stocktakeWrite => 'تنفيذ الجرد',
      Permission.stocktakeView => 'عرض الجرد',
      Permission.stocktakeApprove => 'اعتماد الجرد',
      Permission.stocktakePriorDay => 'جرد يوم سابق',
      // ── التحصيل والذمم (9) ── ★ **ومفتاحا `IQ-040` آخرُها**
      Permission.receiptCreate => 'إضافة سند قبض',
      Permission.receiptBackdate => 'قبض بتاريخ سابق',
      Permission.receiptDepositView => 'عرض حالة الإيداع البنكي',
      Permission.receiptDepositConfirm => 'تأكيد الإيداع البنكي',
      Permission.discountCreate => 'الخصومات',
      Permission.discountBackdate => 'خصم بتاريخ سابق',
      Permission.dealerBalanceView => 'عرض أرصدة المقاوته',
      Permission.dealerStatementView => 'عرض كشف حساب المقوت',
      Permission.dealerStatementAllSources =>
        'عرض الكشف الموحّد لكل المصادر',
      // ── السحبيات والخرجيات (8) ──
      Permission.withdrawalCreate => 'إضافة سحبية',
      Permission.expenseCreate => 'إضافة خرجية',
      Permission.withdrawalQatPriceNow => 'تسعير القات المسحوب الآن',
      Permission.expenseQatPriceNow => 'تسعير القات المصروف الآن',
      Permission.withdrawalBackdate => 'سحبية بتاريخ سابق',
      Permission.expenseBackdate => 'خرجية بتاريخ سابق',
      Permission.withdrawalView => 'عرض سحبيات المالك',
      Permission.expenseView => 'عرض الخرجيات',
      // ── المالية والرقابة (7) ──
      Permission.sackFinanceView => 'عرض مالية الجونية',
      Permission.supplierFinanceView => 'عرض مالية الرعوي',
      Permission.ownerLedgerView => 'ضمار المالك وحركة النقد',
      Permission.allSourcesCardView => 'عرض بطاقة كل المصادر',
      Permission.sourceNetImpactView => 'عرض الأثر النهائي على حساب المصدر',
      Permission.auditLogViewCentral => 'عرض سجل التدقيق المركزي',
      Permission.auditLogViewContextual => 'السجل السياقي',
      // ── الإرسال والتصدير (2) ──
      Permission.messagingSend => 'الإرسال',
      Permission.documentExport => 'تصدير السندات والتقارير',
      // ── التعديل والإلغاء (20) ──
      Permission.incomingCountAmend => 'تعديل الوارد عدداً',
      Permission.incomingCountCancel => 'إلغاء الوارد عدداً',
      Permission.sackAmend => 'تعديل الجونية',
      Permission.sackCancel => 'إلغاء الجونية',
      Permission.distributionAmend => 'تعديل التوزيعة',
      Permission.distributionCancel => 'إلغاء التوزيعة',
      Permission.cashSaleAmend => 'تعديل البيع النقدي',
      Permission.cashSaleCancel => 'إلغاء البيع النقدي',
      Permission.receiptAmend => 'تعديل سند القبض',
      Permission.receiptCancel => 'إلغاء سند القبض',
      Permission.discountAmend => 'تعديل سند الخصم',
      Permission.discountCancel => 'إلغاء سند الخصم',
      Permission.withdrawalAmend => 'تعديل السحبية',
      Permission.withdrawalCancel => 'إلغاء السحبية',
      Permission.expenseAmend => 'تعديل الخرجية',
      Permission.expenseCancel => 'إلغاء الخرجية',
      Permission.stocktakeAmend => 'تعديل الجرد',
      Permission.stocktakeCancel => 'إلغاء الجرد',
      Permission.disposalAmend => 'تعديل الإتلاف',
      Permission.disposalCancel => 'إلغاء الإتلاف',
      // ── إدارة الهوية والوصول (9) ──
      Permission.userView => 'عرض المستخدمين',
      Permission.userCreate => 'إضافة مستخدم',
      Permission.userAmend => 'تعديل مستخدم',
      Permission.userDisable => 'تعطيل مستخدم',
      Permission.roleAssign => 'إسناد دور',
      Permission.permissionGrant => 'تخصيص صلاحيات فردية',
      Permission.sourceScopeSet => 'تحديد نطاق المصادر',
      Permission.roleWrite => 'إضافة دور أو تعديله',
      Permission.roleDelete => 'حذف دور',
      // ── التقارير (6) — ★★ `IQ-034` الخيار ب ──
      Permission.reportInventoryView => 'عرض التقارير المخزنية',
      Permission.reportSalesView => 'عرض التقارير البيعية',
      Permission.reportFinancialView => 'عرض التقارير المالية',
      Permission.reportOutflowView => 'عرض تقارير السحبيات والخرجيات',
      Permission.reportSupplierView => 'عرض تقارير الرعية',
      Permission.reportOversightView => 'عرض التقارير الرقابية',
    };

/// ★ مجموعات الكتالوج **بترتيبها فيه** — ⟵ **فالشاشة تعرضها كما يقرؤها
/// من كتب الكتالوج**، ⛔ ولا ترتيب مخترَع يجعل المدير يبحث عن مفتاح يعرفه.
const List<PermissionGroup> permissionGroups = <PermissionGroup>[
  PermissionGroup(
    title: 'البيانات الأساسية',
    permissions: <Permission>[
      Permission.sourceWrite,
      Permission.supplierWrite,
      Permission.dealerWrite,
      Permission.dealerDisableWithBalance,
      Permission.itemWrite,
      Permission.appSettingsWrite,
    ],
  ),
  PermissionGroup(
    title: 'التوريد',
    permissions: <Permission>[
      Permission.incomingCountWrite,
      Permission.sackCreate,
      Permission.sackView,
      Permission.sackTaxEnterNow,
      Permission.sackTaxEnterLater,
      Permission.sackRenameDisplay,
      Permission.sackLinesEnter,
      Permission.sackScrapWeightEnter,
      Permission.sackLostWeightConfirm,
    ],
  ),
  PermissionGroup(
    title: 'التسعير والصرف',
    permissions: <Permission>[
      Permission.dailyPriceWrite,
      Permission.distributionCreate,
      Permission.distributionPriceNow,
      Permission.distributionPriceAmend,
      Permission.distributionPriceClear,
      Permission.distributionPriceView,
      Permission.cashSaleCreate,
      Permission.cashSaleBelowMinimum,
      Permission.agedRemainderClear,
    ],
  ),
  PermissionGroup(
    title: 'الإتلاف والجرد',
    permissions: <Permission>[
      Permission.disposalCreate,
      Permission.stocktakeWrite,
      Permission.stocktakeView,
      Permission.stocktakeApprove,
      Permission.stocktakePriorDay,
    ],
  ),
  PermissionGroup(
    title: 'التحصيل والذمم',
    permissions: <Permission>[
      Permission.receiptCreate,
      Permission.receiptBackdate,
      Permission.receiptDepositView,
      Permission.receiptDepositConfirm,
      Permission.discountCreate,
      Permission.discountBackdate,
      Permission.dealerBalanceView,
      Permission.dealerStatementView,
      Permission.dealerStatementAllSources,
    ],
  ),
  PermissionGroup(
    title: 'السحبيات والخرجيات',
    permissions: <Permission>[
      Permission.withdrawalCreate,
      Permission.expenseCreate,
      Permission.withdrawalQatPriceNow,
      Permission.expenseQatPriceNow,
      Permission.withdrawalBackdate,
      Permission.expenseBackdate,
      Permission.withdrawalView,
      Permission.expenseView,
    ],
  ),
  PermissionGroup(
    title: 'المالية والرقابة',
    permissions: <Permission>[
      Permission.sackFinanceView,
      Permission.supplierFinanceView,
      Permission.ownerLedgerView,
      Permission.allSourcesCardView,
      Permission.sourceNetImpactView,
      Permission.auditLogViewCentral,
      Permission.auditLogViewContextual,
    ],
  ),
  PermissionGroup(
    title: 'الإرسال والتصدير',
    permissions: <Permission>[
      Permission.messagingSend,
      Permission.documentExport,
    ],
  ),
  PermissionGroup(
    title: 'التعديل والإلغاء',
    permissions: <Permission>[
      Permission.incomingCountAmend,
      Permission.incomingCountCancel,
      Permission.sackAmend,
      Permission.sackCancel,
      Permission.distributionAmend,
      Permission.distributionCancel,
      Permission.cashSaleAmend,
      Permission.cashSaleCancel,
      Permission.receiptAmend,
      Permission.receiptCancel,
      Permission.discountAmend,
      Permission.discountCancel,
      Permission.withdrawalAmend,
      Permission.withdrawalCancel,
      Permission.expenseAmend,
      Permission.expenseCancel,
      Permission.stocktakeAmend,
      Permission.stocktakeCancel,
      Permission.disposalAmend,
      Permission.disposalCancel,
    ],
  ),
  PermissionGroup(
    title: 'إدارة الهوية والوصول',
    permissions: <Permission>[
      Permission.userView,
      Permission.userCreate,
      Permission.userAmend,
      Permission.userDisable,
      Permission.roleAssign,
      Permission.permissionGrant,
      Permission.sourceScopeSet,
      Permission.roleWrite,
      Permission.roleDelete,
    ],
  ),
  // ★★ **التقارير — `IQ-034` الخيار ب (2026-08-30):** ⟵ **مفتاحٌ لكلِّ
  //    عائلةٍ كما يُصنِّفها `FR-M19` §2 نفسُه**، ⛔ **لا 31 مفتاحاً ولا واحد.**
  PermissionGroup(
    title: 'التقارير',
    permissions: <Permission>[
      Permission.reportInventoryView,
      Permission.reportSalesView,
      Permission.reportFinancialView,
      Permission.reportOutflowView,
      Permission.reportSupplierView,
      Permission.reportOversightView,
    ],
  ),
];

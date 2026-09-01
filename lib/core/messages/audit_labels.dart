/// أسماء سجل التدقيق المعروضة — ★ **الأفعال وأسماء الحقول بالعربية**.
///
/// ★★ **المصدر والمُلزِم:** `audit-log-design.md` §3 (حقل `action`) لأسماء
/// الأفعال، **ومعجم `naming-conventions.md` §2 و`data-dictionary.md`**
/// لأسماء الحقول — ⛔ **ولا صياغة جديدة ولا مرادف** (`ui-guidelines.md` §6:
/// «**لا مصطلح تقني في واجهة المستخدم**»).
///
/// ★★ **ويحرس تطابقَ الأفعال اختبارٌ آلي يقرأ المستند نفسه**
/// (`audit_labels_test.dart`) — ⛔ **فلا فعلٌ في [AuditAction] بلا اسمٍ هنا،
/// ولا اسمٌ هنا بلا سطرٍ في §3.**
library;

import 'package:qtms_domain/qtms_domain.dart';

/// ★ اسم الفعل المعروض — **من `audit-log-design.md` §3 حرفياً**.
///
/// ⛔ **والدالة شاملة بلا نمط `_`** — ★ **فالتصريف هو الحارس**: فعلٌ يُضاف
/// إلى [AuditAction] بلا سطر هنا **يُسقِط البناء** ⛔ **ولا يظهر خاماً.**
String auditActionLabel(AuditAction action) => switch (action) {
      AuditAction.create => 'إنشاء',
      AuditAction.amend => 'تعديل',
      AuditAction.cancel => 'إلغاء',
      AuditAction.disable => 'تعطيل',
      AuditAction.signIn => 'دخول',
      AuditAction.export => 'تصدير',
      AuditAction.depositConfirm => 'تأكيد إيداع بنكي',
      AuditAction.lostWeightConfirm => 'تأكيد وزن ضائع',
      AuditAction.disposal => 'إتلاف',
      AuditAction.agedRemainderClear => 'تصريف متأخر',
      AuditAction.permissionChange => 'تغيير صلاحية',
      AuditAction.delete => 'حذف قالب دور غير مُسنَد',
    };

/// ★★ اسم الفعل لقيدٍ مقروء — ⛔ **والمجهول لا يُخفى ولا يُسقِط الشاشة**.
///
/// ⚠️⚠️ **ولماذا نصٌّ صريح لا فراغ:** السجل **للإضافة فقط ولا يُهاجَر**
/// (`schema/audit-log.md`)، ⟵ **فقيدٌ كتبه إصدارٌ أحدث بفعلٍ لا يعرفه هذا
/// الإصدار يبقى مقروءاً بوقته ومُنفِّذه وقيمه**. ★ **وإخفاؤه من شاشة تدقيق
/// أسوأ من عرضه بفعلٍ غير مترجَم** — ⛔ **والفراغ يُقرأ «لم يحدث شيء».**
String auditActionLabelOrUnknown(AuditAction? action) =>
    action == null ? 'إجراء غير معروف' : auditActionLabel(action);

/// ★ اسم الحقل المعروض — **من معجم §2 وقاموس البيانات** · راجع [_fieldLabels].
///
/// ⛔ **ولا أيقونةَ هنا:** ★ **هذه الطبقة بلا `flutter`** كما هي
/// `permission_labels.dart` — ⟵ **وأيقونةُ الفعل تعيش في طبقة العرض**
/// (`audit_trail_view.dart`).
String auditFieldLabel(String field) => _fieldLabels[field] ?? field;

/// ★★ اسم **قيمةٍ رمزية** بالعربية — ⛔ **ولا يُعرَض رمزُ تعدادٍ خاماً**.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⚠️⚠️ **وعطلٌ رُصد على المحاكي (2026-08-27):** القيد يُخزِّن قيم التعدادات
/// **بأسمائها الإنجليزية** (`ItemNature.weightBased.name` · `ItemUnit
/// .piece.name` …) — ⟵ **فكانت الشاشة تعرض `weightBased` و`piece` حرفياً**
/// ⛔ **وهو مصطلحٌ تقني في واجهة المستخدم** (`ui-guidelines.md` §6).
///
/// ★ **والترجمة هي نفسها المعتمدة في شاشاتها** (`items_screen.dart` →
/// `natureLabel` و`unitLabel`) — ⛔ **ولا صياغة ثانية**: ⟵ **فالقيمة
/// نفسها تُقرأ بالنصّ نفسه أينما ظهرت.**
///
/// ⛔ **والمجهول يُعرَض كما هو** — بنفس علّة [_fieldLabels] حرفياً: ★ **إخفاءُ
/// قيمةٍ تغيّرت أسوأ من عرضها بنصٍّ تقني.**
/// ═══════════════════════════════════════════════════════════════════════
String auditValueLabel(String value) => _valueLabels[value] ?? value;

/// ★ رموز التعدادات المكتوبة في القيود اليوم — ⛔ **ولا رمزٌ بلا كاتبٍ له**.
const Map<String, String> _valueLabels = <String, String>{
  // ── طبيعة النوع ووحدته — `items_screen.dart` حرفياً ──
  'countBased': 'عددي',
  'weightBased': 'وزني',
  'piece': 'حبة',
  'kilogram': 'كيلوجرام',
  // ── الدفتر — `inventory.dart` ──
  'incoming': 'دخول',
  'outgoing': 'خروج',
  'normal': 'عادية',
  'adjustment': 'تسوية جرد',
  'disposal': 'إتلاف',
  'countedIntake': 'وارد عدداً',
  'sack': 'جونية',
  // ── حالات المستندات ──
  'approved': 'معتمد',
  'cancelled': 'ملغى',
  'priced': 'مسعَّر',
  'partiallyPriced': 'مسعَّر جزئياً',
  // ── مصدر وزن الحبة — `sack_intake.dart` ──
  'manual': 'يدوي',
  'derived': 'مشتقّ',
};

/// ★★ أسماء الحقول بالعربية — **من المعجم وقاموس البيانات**.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⚠️⚠️ **ولماذا الغائبُ يُعرَض بمفتاحه لا يُخفى — وهو قرارٌ تنفيذي مُعلَن:**
///
/// `FR-M18-03` يجعل القيد **«بالقيمة قبل وبعد»** شرطاً بنيوياً، ⟵ **وحقلٌ
/// تغيّر ولا اسمَ عربياً له هنا** يواجه خيارين: ① **يُخفى** فيصير السجل
/// يشهد بتغييرٍ ناقص، أو ② **يُعرَض بمفتاحه** فيقرؤه المدقّق تقنياً.
///
/// ★ **والثاني هو المختار:** ⛔ **إخفاءُ تغييرٍ وقع فعلاً يُسقِط مبرر
/// `ADR-0004` كلَّه** (`RISK-05`: «فإن ضعف شرط واحد من شروطه سقط المبرر
/// كله») — ★ **بينما مصطلحٌ تقني ظاهر عيبُ عرضٍ يُصلَح بسطرٍ هنا.**
/// ⟵ **فالمقايضة بين «ناقصٌ صامت» و«كاملٌ خشن»، والسجل يختار الثاني.**
/// ═══════════════════════════════════════════════════════════════════════
const Map<String, String> _fieldLabels = <String, String>{
  // ── المستند وهويته ──
  'documentNumber': 'رقم المستند',
  'status': 'الحالة',
  'notes': 'ملاحظات',
  'note': 'ملاحظة',
  'lines': 'السطور',
  'stockDate': 'تاريخ المخزون',
  'entryDate': 'تاريخ الإدخال',
  'date': 'التاريخ',
  // ── التعديل والإلغاء ──
  'amendCount': 'عدد التعديلات',
  'amendReason': 'سبب التعديل',
  'amendedBy': 'المُعدِّل',
  'cancelReason': 'سبب الإلغاء',
  'cancelledBy': 'المُلغي',
  'createdBy': 'المُنشئ',
  'modifiedBy': 'آخر من عدّل',
  'isCancelled': 'ملغى',
  'deleted': 'محذوف',
  // ── البيانات المرجعية ──
  'name': 'الاسم',
  'displayName': 'الاسم المعروض',
  'normalizedName': 'الاسم المُطبَّع',
  'code': 'الكود',
  'phone': 'الهاتف',
  'normalizedPhone': 'الهاتف المُطبَّع',
  'email': 'البريد',
  'description': 'الوصف',
  'isActive': 'نشط',
  'isSystemDefault': 'افتراضي للنظام',
  'requiresSupplierOnIntake': 'يشترط رعوياً عند التوريد',
  // ── المصادر والأنواع ──
  'sourceId': 'المصدر',
  'sourceName': 'اسم المصدر',
  'sourceIds': 'المصادر',
  'itemId': 'النوع',
  'itemKey': 'مفتاح النوع',
  'itemName': 'اسم النوع',
  'unit': 'الوحدة',
  'nature': 'طبيعة النوع',
  'scrapItemId': 'نوع السكرب',
  'scrapItemKey': 'مفتاح السكرب',
  // ── الرعية والمقاوته ──
  'supplierId': 'الرعوي',
  'supplierName': 'اسم الرعوي',
  'dealerId': 'المقوت',
  'dealerName': 'اسم المقوت',
  // ── الكميات والدفتر ──
  'quantity': 'الكمية',
  'totalQuantity': 'إجمالي الكمية',
  'direction': 'الاتجاه',
  'balance': 'الرصيد',
  'balanceAfter': 'الرصيد بعد الحركة',
  'incoming': 'الوارد',
  'outgoing': 'الصادر',
  'movementTag': 'وسم الحركة',
  'sourceDocType': 'نوع المستند المصدر',
  'sourceDocId': 'معرّف المستند المصدر',
  'sourceDocNumber': 'رقم المستند المصدر',
  // ── الجونية ──
  'sackId': 'الجونية',
  'dailySequence': 'التسلسل اليومي',
  'iceWeight': 'وزن الثلج',
  'scrapWeight': 'وزن السكرب',
  'claimableWeight': 'الوزن المطالب به',
  'remainingWeight': 'الوزن المتبقي',
  'lostWeight': 'الوزن الضائع',
  'lostWeightConfirmed': 'تأكيد الوزن الضائع',
  'lostWeightNote': 'ملاحظة الوزن الضائع',
  'lineTotalWeight': 'وزن السطر الكلي',
  'isScrapLine': 'سطر سكرب',
  'pieceWeightGrams': 'وزن الحبة بالجرام',
  'pieceWeightOrigin': 'مصدر وزن الحبة',
  'taxPerKilo': 'ضريبة الكيلو',
  'sackTax': 'ضريبة الجونية',
  'totalWeight': 'إجمالي الوزن',
  'totalRevenue': 'إجمالي سعر الجواني',
  'totalTax': 'إجمالي الضريبة',
  'net': 'الصافي',
  // ── البيع النقدي المباشر (`WU-012`) ──
  //
  // ⛔⛔★★ **عطلٌ رصده المحاكي وحده (2026-09-01):** ★ **قيدُ إنشاء سند البيع
  //    النقدي كان يعرض `netCashReceived` و`totalPieces` بمفتاحيهما الإنجليزيين**
  //    بين حقولٍ معرَّبة — ⟵ **ولا اختبارَ آليٌّ يكشفه**: ★ **الخريطة تُرجِع
  //    المفتاح نفسَه عند غيابه** ⛔ **فلا ترمي ولا تُفشِل شيئاً.**
  'netCashReceived': 'صافي المقبوض',
  'totalPieces': 'إجمالي الحبات',
  'unitPrice': 'سعر الوحدة',
  'lineTotal': 'قيمة السطر',
  'belowMinReason': 'سبب البيع دون الحد الأدنى',
  // ── التسعير ──
  'distributionPrice': 'سعر التوزيع',
  'minCashPrice': 'الحد الأدنى للبيع النقدي',
  'isPricingComplete': 'اكتمل التسعير',
  // ── الهوية والصلاحيات ──
  'userId': 'المستخدم',
  'userName': 'اسم المستخدم',
  'roleId': 'الدور',
  'permissions': 'الصلاحيات',
  'permissionsGranted': 'الصلاحيات الممنوحة',
  'sourceScope': 'نطاق المصادر',
  'disableReason': 'سبب التعطيل',
};

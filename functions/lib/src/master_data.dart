/// البيانات المرجعية — **التخطيط الخالص** لعمليات `WU-002`.
///
/// ★ **مفصول عن الشبكة بنفس منطق `user_admin.dart`:** `ADR-0013` القاعدة 3
/// تجعل **فحص التفويض في الكود** هو الحارس الوحيد لهذا المسار، فالدالة
/// تعمل بامتياز إداري يتجاوز قواعد الحماية. ★ **وحارسٌ لا يُختبَر بلا
/// سحابة حارسٌ غير مُختبَر** — فكل قرار هنا **دالة خالصة**.
///
/// ★ **وقواعد العمل نفسها من طبقة النطاق لا من هنا**
/// (`master_data.dart` في `qtms_domain`) — ⛔ **ولا تُعاد كتابتها**.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⚠️⚠️ **لماذا تمرّ البيانات المرجعية بدالة مستدعاة أصلاً — قرار تنفيذي
/// موثَّق لا نقلٌ عن مستند:**
///
/// `IQ-009` أغلق الكتابة المباشرة على **عشر مجموعات تمسّ المال أو المخزون**
/// ⛔ **ولم تكن البيانات المرجعية منها**. ★ **لكن ثلاثة نصوص مجتمعةً لا
/// تُحقَّق إلا بهذا المسار:**
///
///   ① `FR-M2-03` · `FR-M3-13` · `FR-M4-13`: تعديل الاسم أو الرقم أو
///      إلزامية الرعوي **«يُسجَّل بالقيمة قبل وبعد»**.
///   ② `FR-M18-04`: **«كتابة السجل تتم عبر السحابة حصراً، والكتابة عليه
///      من التطبيق ممنوعة نهائياً»** — والقاعدة `allow create: if false`.
///   ③ `audit-log-design.md` §2 الشرط 3 و`ADR-0013` القاعدة 1:
///      **المستند وقيده معاً أو لا شيء** — ⛔ **ولا مشغّل يكتب القيد بعد
///      الالتزام**، فهو يصل بعد أن التزمت الكتابة فلا شيء بقي ليُبطَل.
///
/// ⟵ ★ **فالكتابةُ المباشرة من التطبيق كانت ستُنتج تعديلاً بلا قيد** —
/// وهو ما تمنعه الثلاثة معاً. ✅ **والمسار هنا أقوى لا أضعف**: يضيف
/// حارساً في الكود إلى حارس القاعدة، **ويجعل حارس التفرّد وقيدَ التدقيق
/// في المعاملة نفسها**.
///
/// ⚠️ **وأثره على القواعد معلَن:** `sources` · `suppliers` · `dealers` ·
/// `items` · `app_settings` **وسجلات الحراسة الأربعة** صارت
/// `allow create, update: if false` — ⛔ **والقراءة لم تُمَسّ** (`ADR-0013`
/// القاعدة 4).
/// ═══════════════════════════════════════════════════════════════════════
library;

import 'package:qtms_domain/qtms_domain.dart';

import 'callable.dart';
import 'firestore_value.dart';
import 'identity_gateway.dart';

/// حقل معرّف الكيان داخل سجل حراسة التفرد.
///
/// ★ **ولماذا يحمل السجل معرّفاً أصلاً وهو «سجل فارغ» في القاموس:** بدونه
/// **لا سبيل للتمييز بين تكرارٍ حقيقي وإعادة إرسالٍ لنفس الطلب** — ⟵
/// **فتُرفَض إعادةُ المحاولة بعد انقطاعٍ وكأنها اسمٌ مكرر.**
const String guardEntityIdField = 'entityId';

/// حقل القيمة المُطبَّعة داخل سجل الحراسة — **للتشخيص لا للفحص**.
const String guardNormalizedField = 'normalized';

/// كتابة مستند واحدة ضمن الخطة — **بلا أي تبعية شبكة**.
final class MasterDataWrite {
  /// ينشئ الكتابة.
  const MasterDataWrite({
    required this.collectionId,
    required this.documentId,
    required this.fields,
    required this.updateMask,
    this.serverTimestampFields = const <String>[],
  });

  /// المجموعة المكتوب فيها.
  final String collectionId;

  /// معرّف المستند.
  final String documentId;

  /// الحقول بقيم Dart عادية.
  final Map<String, Object?> fields;

  /// ★ **قناع الكتابة** — ⛔ وبدونه تُمحى بقية حقول المستند.
  final List<String> updateMask;

  /// ★ حقول **وقت الخادم** — تُكتب بتحويل المنصة لا بساعة الحاوية.
  ///
  /// ⛔ **ولا تدخل [fields] ولا [updateMask]** — تحويلاتُ الحقل مسارٌ مستقل
  /// في بروتوكول الكتابة (`coding-standards.md` §2.3 · `GR-54`).
  final List<String> serverTimestampFields;
}

/// نوع عملية البيانات المرجعية — ويحدد الصلاحية التي لا تُنفَّذ بدونها.
enum MasterDataOperation {
  /// `createSource` — يشترط `sourceWrite` (`FR-M2-01`).
  createSource(Permission.sourceWrite, sourceEntityType, isCreate: true),

  /// `updateSource` — يشترط `sourceWrite` ★ **وسبباً نصياً** (`FR-M2-03`).
  updateSource(Permission.sourceWrite, sourceEntityType, isCreate: false),

  /// `createSupplier` — يشترط `supplierWrite` (`FR-M3-01`).
  createSupplier(Permission.supplierWrite, supplierEntityType, isCreate: true),

  /// `updateSupplier` — يشترط `supplierWrite` ★ **وسبباً** (`FR-M3-13`).
  updateSupplier(Permission.supplierWrite, supplierEntityType, isCreate: false),

  /// `createDealer` — يشترط `dealerWrite` (`FR-M4-01`).
  createDealer(Permission.dealerWrite, dealerEntityType, isCreate: true),

  /// `updateDealer` — يشترط `dealerWrite` ★ **وسبباً** (`FR-M4-13`).
  updateDealer(Permission.dealerWrite, dealerEntityType, isCreate: false),

  /// `createItem` — يشترط `itemWrite` (`FR-M5-01`).
  createItem(Permission.itemWrite, itemEntityType, isCreate: true),

  /// `updateItem` — يشترط `itemWrite` ★ **وسبباً** (`FR-M5-01`).
  updateItem(Permission.itemWrite, itemEntityType, isCreate: false),

  /// ★★ `writeAppSettings` — يشترط `appSettingsWrite` **ومرة واحدة**
  /// (`FR-M21-03`)، ⚙️ **وينشئ «السكرب»** في المعاملة نفسها (`IQ-012`).
  writeAppSettings(
    Permission.appSettingsWrite,
    appSettingsEntityType,
    isCreate: true,
  );

  const MasterDataOperation(
    this.requiredPermission,
    this.entityType, {
    required this.isCreate,
  });

  /// الصلاحية التي لا تُنفَّذ العملية بدونها.
  final Permission requiredPermission;

  /// نوع الكيان في قيد التدقيق.
  final String entityType;

  /// ★ هل هي إنشاء؟ — ⛔ **والسبب النصي يلزم التعديل وحده**: القيد يوثّق
  /// «ماذا كان وماذا صار»، **ولا «كان» قبل الإنشاء**.
  final bool isCreate;
}

/// سجل حراسة تفرّد كما قُرئ — و`null` تعني **غياب السجل**.
final class UniquenessGuardRead {
  /// ينشئ القراءة.
  const UniquenessGuardRead({
    required this.collectionId,
    required this.key,
    required this.stored,
  });

  /// مجموعة الحراسة.
  final String collectionId;

  /// المفتاح — ★ **هو القيمة المُطبَّعة نفسها** (`master-data-design.md` §3).
  final String key;

  /// المستند المقروء، أو `null` إن لم يوجد.
  final Map<String, Object?>? stored;

  /// معرّف الكيان الذي يملك هذا المفتاح، أو `null`.
  String? get ownerEntityId {
    final Object? owner = stored?[guardEntityIdField];
    return owner is String && owner.isNotEmpty ? owner : null;
  }

  /// ★ هل المفتاح محجوز لكيانٍ **آخر**؟
  ///
  /// ⚠️ **والتمييز عملي لا شكلي:** المحجوز لنفس الكيان **إعادة إرسال**
  /// (أو تعديلٌ لم يمسّ المفتاح)، ⟵ **ورفضُه كان سيُظهر «الاسم مكرر» عن
  /// اسمِ صاحبه هو.**
  bool isTakenByOther(String entityId) {
    final String? owner = ownerEntityId;
    // ⛔ **سجلٌ موجود بلا مالك محجوزٌ لا حرّ** — ★ **الرفض الافتراضي**:
    //    قد يكون سجلاً قديماً كُتب قبل هذا الحقل، **وقراءتُه «حرّاً» تفتح
    //    الباب لاسمين متطابقين.**
    if (stored == null) return false;
    return owner != entityId;
  }
}

/// نتيجة التخطيط — إما خطة كتابة وإما رفض مصنَّف.
sealed class MasterDataPlan {
  /// ينشئ النتيجة.
  const MasterDataPlan();
}

/// رُفض الطلب قبل أي كتابة.
final class MasterDataRejected extends MasterDataPlan {
  /// ينشئ رفضاً.
  const MasterDataRejected(this.error);

  /// رمز الرفض من كتالوج الأخطاء.
  final CallableError error;
}

/// قُبل الطلب — وهذه كتاباته وقيده.
final class MasterDataAccepted extends MasterDataPlan {
  /// ينشئ خطة مقبولة.
  const MasterDataAccepted({
    required this.entityId,
    required this.writes,
    required this.entry,
  });

  /// معرّف الكيان — الكود المخصَّص أو المعرّف القائم.
  final String entityId;

  /// المستندات المكتوبة — ⛔ **ولا تكون فارغة**.
  final List<MasterDataWrite> writes;

  /// قيد التدقيق — **يُكتب في المعاملة نفسها** (`ADR-0013` القاعدة 1).
  final AuditEntry entry;
}

/// طلب بيانات مرجعية مُتحقَّق من هوية مُنفِّذه.
final class MasterDataRequest {
  /// ينشئ الطلب.
  const MasterDataRequest({
    required this.actor,
    required this.entityId,
    required this.requestId,
    this.source,
    this.supplier,
    this.dealer,
    this.item,
    this.settings,
    this.amendReason,
    this.balanceAcknowledgement,
    this.guard,
    this.stored,
    this.dealerBalances,
    this.businessSettingsExist = false,
    this.formattingSettingsExist = false,
    this.scrapItemId,
    this.deviceInfo,
  });

  /// المُنفِّذ **بحالته الآن من خدمة المصادقة** لا من الرمز الذي أرسله.
  final AccountRecord actor;

  /// معرّف الكيان — **الكود المخصَّص عند الإنشاء، والقائم عند التعديل**.
  final String entityId;

  /// ★ **معرّف مُولَّد على الجهاز** — وهو **معرّف قيد التدقيق نفسه**،
  /// فإعادة الإرسال تكتب فوق القيد ولا تُنشئ ثانياً (`api-overview.md` §4).
  final String requestId;

  /// المصدر المُتحقَّق منه.
  final ValidatedSource? source;

  /// الرعوي المُتحقَّق منه.
  final ValidatedSupplier? supplier;

  /// المقوت المُتحقَّق منه.
  final ValidatedDealer? dealer;

  /// النوع المُتحقَّق منه.
  final ValidatedItem? item;

  /// الإعداد التأسيسي المُتحقَّق منه.
  final ValidatedAppSettings? settings;

  /// ★★ **سبب التعديل — إلزامي لكل عملية تعديل** (`ADR-0004` · `DEBT-21` ①).
  final String? amendReason;

  /// ★ **إقرار تعطيل مقوت له رصيد** — `FR-M4-09` · `E-39`.
  final String? balanceAcknowledgement;

  /// سجل حراسة التفرد للمفتاح **الوارد** — كما قُرئ داخل المعاملة.
  final UniquenessGuardRead? guard;

  /// ★ المستند القائم كما قُرئ داخل المعاملة — و`null` تعني **غيابه**.
  final Map<String, Object?>? stored;

  /// ★★ **أرصدة المقوت المقيسة** — ⛔ **و`null` تعني «لم تُقَس» ⟵ رفض**.
  final DealerBalanceCensus? dealerBalances;

  /// هل مستند بيانات المنشأة موجود؟
  final bool businessSettingsExist;

  /// هل مستند العملة والأرقام موجود؟
  final bool formattingSettingsExist;

  /// ★ معرّف النوع الافتراضي المخصَّص — لعملية الإعداد التأسيسي وحدها.
  final String? scrapItemId;

  /// وصف الجهاز للسجل — ⛔ بلا بيانات حساسة.
  final String? deviceInfo;
}

/// ★★ فحوص الحالة والصلاحية وحدها — **تُستدعى قبل فتح المعاملة**.
///
/// ⚠️ **ولماذا مُصدَّرة:** كل عملية هنا تحتاج **قراءةً داخل معاملة** قبل أن
/// يكتمل تخطيطها، ⟵ **وفتحُ معاملةٍ لطلبٍ يرفضه نقصُ الصلاحية هدرٌ وقفلٌ
/// بلا داعٍ**. ★ **والفحص نفسه لا يتكرر منطقاً** — [planMasterData] تعيده
/// كاملاً على الطلب المكتمل، ⛔ **فلا مسار يتخطّاه.**
MasterDataRejected? masterDataGate(
  MasterDataRequest request,
  MasterDataOperation operation,
) {
  // ① «التعطيل فوري ونافذ» — `authentication-policy.md` §2 القاعدة 3.
  if (request.actor.disabled) {
    return const MasterDataRejected(CallableError.accountDisabled);
  }
  // ② الصلاحية — ⛔ ولا قاعدة حماية تحرس هذا المسار؛ **هذا السطر هو
  //    الحارس** (`ADR-0013` القاعدة 3).
  if (!request.actor.claims.has(operation.requiredPermission)) {
    return const MasterDataRejected(CallableError.permissionMissing);
  }
  // ③ معرّف الطلب إلزامي — وبدونه لا تتحقق اللاتكرارية عند إعادة الإرسال.
  if (request.requestId.trim().isEmpty) {
    return const MasterDataRejected(CallableError.invalidArgument);
  }
  return null;
}

/// يخطّط عملية بيانات مرجعية — **دالة خالصة، وهي حارس التفويض الفعلي**.
MasterDataPlan planMasterData(
  MasterDataRequest request,
  MasterDataOperation operation,
) {
  final MasterDataRejected? gate = masterDataGate(request, operation);
  if (gate != null) return gate;

  if (request.entityId.trim().isEmpty) {
    return const MasterDataRejected(CallableError.invalidArgument);
  }

  // ⛔⛔★★★ **حارسُ السبب حُذف بـ`ADR-0020` (2026-08-27)** — ★ **السبب
  //    اختياريٌّ في كل عملية**، ⟵ **ولا رفضَ لغيابه.** ⛔ **ولا يُعبَّأ
  //    آلياً:** ★ **ما لم يكتبه إنسانٌ لا يُخزَّن.**
  final String? amendReason = _amendReason(request, operation);
  return switch (operation) {
    MasterDataOperation.createSource ||
    MasterDataOperation.updateSource =>
      _planSource(request, operation, amendReason),
    MasterDataOperation.createSupplier ||
    MasterDataOperation.updateSupplier =>
      _planSupplier(request, operation, amendReason),
    MasterDataOperation.createDealer ||
    MasterDataOperation.updateDealer =>
      _planDealer(request, operation, amendReason),
    MasterDataOperation.createItem ||
    MasterDataOperation.updateItem =>
      _planItem(request, operation, amendReason),
    MasterDataOperation.writeAppSettings => _planAppSettings(request),
  };
}

// ═════════════════════════════════════════════════════════════════════════
// المصدر
// ═════════════════════════════════════════════════════════════════════════

MasterDataPlan _planSource(
  MasterDataRequest request,
  MasterDataOperation operation,
  String? amendReason,
) {
  final ValidatedSource? source = request.source;
  if (source == null) {
    return const MasterDataRejected(CallableError.invalidArgument);
  }

  final MasterDataRejected? existence = _existenceGate(request, operation);
  if (existence != null) return existence;

  final MasterDataRejected? duplicate = _guardGate(
    request: request,
    expectedCollection: uniqueSourceNamesCollection,
    expectedKey: source.normalizedName,
    duplicateError: CallableError.duplicateSourceName,
  );
  if (duplicate != null) return duplicate;

  final Map<String, Object?> after = <String, Object?>{
    'name': source.name,
    'normalizedName': source.normalizedName,
    'requiresSupplierOnIntake': source.requiresSupplierOnIntake,
    'notes': source.notes,
    'isActive': source.isActive,
    'disableReason': source.disableReason,
  };

  return _accept(
    request: request,
    operation: operation,
    amendReason: amendReason,
    collectionId: sourcesCollection,
    idField: 'sourceId',
    after: after,
    guardCollection: uniqueSourceNamesCollection,
    guardKey: source.normalizedName,
    // ★ **المصدر يحمل نفسه في القيد** — فيُفلتَر بالنطاق (`FR-M18-14`).
    auditSourceId: request.entityId,
  );
}

// ═════════════════════════════════════════════════════════════════════════
// الرعوي
// ═════════════════════════════════════════════════════════════════════════

MasterDataPlan _planSupplier(
  MasterDataRequest request,
  MasterDataOperation operation,
  String? amendReason,
) {
  final ValidatedSupplier? supplier = request.supplier;
  if (supplier == null) {
    return const MasterDataRejected(CallableError.invalidArgument);
  }

  final MasterDataRejected? existence = _existenceGate(request, operation);
  if (existence != null) return existence;

  final MasterDataRejected? duplicate = _guardGate(
    request: request,
    expectedCollection: uniqueSupplierPhonesCollection,
    expectedKey: supplier.normalizedPhone,
    duplicateError: CallableError.duplicateSupplierPhone,
  );
  if (duplicate != null) return duplicate;

  final Map<String, Object?> after = <String, Object?>{
    // ⛔⛔★★★ **ولا `sourceIds` هنا إطلاقاً** — `CR-006` (2026-08-31):
    //    ★ **الرعوي يتبع كل المصادر الحالية والمستقبلية تلقائياً**، ⟵ **وحقلٌ
    //    فارغٌ يُكتب كان يوهم بانتماءٍ محدود.** ⛔ **ولا يُحذَف من المستندات
    //    القائمة**: ★ **قناعُ الكتابة يقتصر على المفاتيح أعلاه** — ⟵ **فما
    //    كُتب سابقاً يبقى مهجوراً لا مقروءاً** (**لا حذف بيانات**).
    'name': supplier.name,
    'normalizedName': supplier.normalizedName,
    'phone': supplier.phone,
    'normalizedPhone': supplier.normalizedPhone,
    'notes': supplier.notes,
    'isActive': supplier.isActive,
    'disableReason': supplier.disableReason,
  };

  return _accept(
    request: request,
    operation: operation,
    amendReason: amendReason,
    collectionId: suppliersCollection,
    idField: 'supplierId',
    after: after,
    guardCollection: uniqueSupplierPhonesCollection,
    guardKey: supplier.normalizedPhone,
  );
}

// ═════════════════════════════════════════════════════════════════════════
// المقوت
// ═════════════════════════════════════════════════════════════════════════

MasterDataPlan _planDealer(
  MasterDataRequest request,
  MasterDataOperation operation,
  String? amendReason,
) {
  final ValidatedDealer? dealer = request.dealer;
  if (dealer == null) {
    return const MasterDataRejected(CallableError.invalidArgument);
  }

  final MasterDataRejected? existence = _existenceGate(request, operation);
  if (existence != null) return existence;

  final MasterDataRejected? duplicate = _guardGate(
    request: request,
    expectedCollection: uniqueDealerPhonesCollection,
    expectedKey: dealer.normalizedPhone,
    duplicateError: CallableError.duplicateDealerPhone,
  );
  if (duplicate != null) return duplicate;

  // ★★ **تعطيل مقوت له رصيد** — `FR-M4-09` · `E-39` · `IQ-020` الخيار أ.
  //   ⛔ **ولا يُفحَص إلا عند تعطيلٍ فعلي** — فالمقوت النشط لا يعنيه الشرط،
  //   ★ **والإنشاء لا يُنشئ معطَّلاً برصيد** (لا رصيد له أصلاً).
  if (!dealer.isActive && _wasActive(request)) {
    final DealerBalanceCensus? census = request.dealerBalances;
    if (census == null) {
      // ⛔★★ **لم يُقَس الرصيد ⟵ رفض** — الرفض الافتراضي (`security-requirements.md`
      //    §2 القاعدة 6). ★ **فمسارٌ نسي القياس يُرفَض صراحةً**، ⛔ **ولا
      //    يُقرأ صمتُه «رصيده صفر».**
      return const MasterDataRejected(CallableError.internal);
    }
    // ★★★ **الشرط الثالث: المفتاح المستقل** — ⛔ **ولا قاعدة حماية تحرسه**،
    //    فهذا السطر هو الحارس (`ADR-0013` القاعدة 3). ★ **ويُقرأ من بطاقة
    //    المستخدم** (`ADR-0016`) لا من حمولة الطلب.
    final Outcome<void> allowed = validateDealerDeactivation(
      census: census,
      acknowledgement: request.balanceAcknowledgement,
      canDisableWithBalance:
          request.actor.claims.has(Permission.dealerDisableWithBalance),
    );
    if (allowed is Failure<void>) {
      // ★ **ويفترق الرمزان**: نقصُ الصلاحية `ERR_AUTH_001` · ونقصُ الإقرار
      //   `ERR_SETUP_006` — ⛔ **ولا رمز جامع يُخفي أيّهما وقع.**
      return MasterDataRejected(
        allowed.error is PermissionError
            ? CallableError.permissionMissing
            : CallableError.dealerBalanceBlocksDisable,
      );
    }
  }

  final Map<String, Object?> after = <String, Object?>{
    'name': dealer.name,
    'normalizedName': dealer.normalizedName,
    'phone': dealer.phone,
    'normalizedPhone': dealer.normalizedPhone,
    'notes': dealer.notes,
    'isActive': dealer.isActive,
    'disableReason': dealer.disableReason,
    // ⛔★★ **ولا حقل مصدر إطلاقاً** — `FR-M4-04` · `master-data-design.md` §7.
  };

  return _accept(
    request: request,
    operation: operation,
    amendReason: amendReason,
    collectionId: dealersCollection,
    idField: 'dealerId',
    after: after,
    guardCollection: uniqueDealerPhonesCollection,
    guardKey: dealer.normalizedPhone,
    // ★ **التعطيل فعلٌ مستقل في المعجم لا «تعديل»** — فيُقرأ من السجل بذاته
    //   ⛔ ولا يختفي بين تعديلات الأسماء.
    overrideAction: (!dealer.isActive && _wasActive(request))
        ? AuditAction.disable
        : null,
  );
}

// ═════════════════════════════════════════════════════════════════════════
// النوع
// ═════════════════════════════════════════════════════════════════════════

MasterDataPlan _planItem(
  MasterDataRequest request,
  MasterDataOperation operation,
  String? amendReason,
) {
  final ValidatedItem? item = request.item;
  if (item == null) {
    return const MasterDataRejected(CallableError.invalidArgument);
  }

  final MasterDataRejected? existence = _existenceGate(request, operation);
  if (existence != null) return existence;

  // ★★ **«السكرب» لا يُنشئه المستخدم ولا يُعدِّله ولا يُعطِّله** — `FR-M5-05`.
  //   ⛔ **قيدٌ يعلو على الصلاحية**: من يملك `itemWrite` يعدّل كل نوع إلا هذا.
  if (item.isSystemDefault) {
    return const MasterDataRejected(CallableError.systemDefaultItem);
  }
  final Map<String, Object?>? stored = request.stored;
  if (stored != null) {
    final Outcome<void> guard = validateSystemDefaultGuard(
      storedIsSystemDefault: stored['isSystemDefault'] == true,
    );
    if (guard is Failure<void>) {
      return const MasterDataRejected(CallableError.systemDefaultItem);
    }
    // ★★ **الوحدة لا تتغيّر** — `FR-M5-04` · `BR-M5-11` · `GR-19`.
    final ItemUnit? storedUnit = _unitOf(stored['unit']);
    if (storedUnit != null) {
      final Outcome<void> unchanged = validateItemUnitUnchanged(
        stored: storedUnit,
        incoming: item.unit,
      );
      if (unchanged is Failure<void>) {
        return const MasterDataRejected(CallableError.itemUnitLocked);
      }
    }
  }

  final MasterDataRejected? duplicate = _guardGate(
    request: request,
    expectedCollection: uniqueItemNamesCollection,
    expectedKey: item.normalizedName,
    duplicateError: CallableError.duplicateItemName,
  );
  if (duplicate != null) return duplicate;

  return _accept(
    request: request,
    operation: operation,
    amendReason: amendReason,
    collectionId: itemsCollection,
    idField: 'itemId',
    after: _itemFields(item),
    guardCollection: uniqueItemNamesCollection,
    guardKey: item.normalizedName,
  );
}

Map<String, Object?> _itemFields(ValidatedItem item) => <String, Object?>{
      'sourceIds': item.sourceIds,
      'name': item.name,
      'normalizedName': item.normalizedName,
      'nature': item.nature.name,
      // ⛔⛔★★ **ويُصرَّح به عشرياً — `DEBT-33`:** المُرمِّز **يرفض `double`
      //    المجرَّد عمداً** (`firestore_value.dart`: «لأن المُرمِّز لا يعرف
      //    أمبلغٌ هذا أم وزن، يرفض الاثنين ويُلزم المُستدعي بالتصريح»)،
      //    ⟵ **وتمريرُه خاماً كان يُسقِط إنشاء كل نوعٍ وزنيٍّ بوزن حبة
      //    بـ`500` خام** — ★ **رُصد بالتشغيل الحقيقي لا بالاختبارات.**
      //    ★ **و`sack_intake.dart` كان يُصرِّح به صحيحاً أصلاً** (سطر
      //    `'pieceWeightGrams': DecimalValue(pieceWeightGrams)`) — ⟵ ⛔ **فكان
      //    الحقلُ نفسه يُكتب بطريقتين مختلفتين من كاتبَين.**
      'pieceWeightGrams': item.pieceWeightGrams == null
          ? null
          : DecimalValue(item.pieceWeightGrams!),
      'unit': item.unit.name,
      'isSystemDefault': item.isSystemDefault,
      'isActive': item.isActive,
      'disableReason': item.disableReason,
      // ⛔★★ **ولا حقل سعر واحد** — `FR-M5-09`: «قاعدة الحماية ترفض أي حقل
      //    سعر على سجل الأنواع»، ★ **والدالة الكاتبة ورثت الشرط بعد الإغلاق.**
    };

ItemUnit? _unitOf(Object? raw) {
  for (final ItemUnit unit in ItemUnit.values) {
    if (unit.name == raw) return unit;
  }
  return null;
}

// ═════════════════════════════════════════════════════════════════════════
// الإعداد التأسيسي — ★★ ومعه النوع الافتراضي «السكرب» (`IQ-012`)
// ═════════════════════════════════════════════════════════════════════════

MasterDataPlan _planAppSettings(MasterDataRequest request) {
  final ValidatedAppSettings? settings = request.settings;
  if (settings == null) {
    return const MasterDataRejected(CallableError.invalidArgument);
  }

  // ★★ **مرة واحدة ولا تُعدَّل** — `FR-M21-03` · `AT-65`.
  final Outcome<void> unwritten = validateAppSettingsUnwritten(
    businessExists: request.businessSettingsExist,
    formattingExists: request.formattingSettingsExist,
  );
  if (unwritten is Failure<void>) {
    return const MasterDataRejected(CallableError.appSettingsAlreadyWritten);
  }

  final String? scrapItemId = request.scrapItemId;
  if (scrapItemId == null || scrapItemId.trim().isEmpty) {
    return const MasterDataRejected(CallableError.invalidArgument);
  }

  // ★★ **النوع الافتراضي يُنشأ هنا** — `IQ-012` (الخيار أ): «إنشاء النوع
  //   مسؤولية `M21` لا التهيئة». ⛔ **ولا من أي واجهة** (`master-data-design.md` §5).
  final Outcome<ValidatedItem> scrap = validateItem(
    ItemInput(
      // ⚠️ **بلا مصادر عند التأسيس** — لا مصدر موجود بعد أصلاً، ★ **والوصل
      //   يقع لاحقاً في `provisionAccountsOnSourceAdd`** مع كل مصدر يُضاف
      //   (`FR-M21-09` ④). ⟵ **فالقائمة تبدأ فارغة عمداً.**
      sourceIds: const <String>[_scrapBootstrapSource],
      name: scrapItemName,
      nature: ItemNature.weightBased,
      isSystemDefault: true,
    ),
  );
  if (scrap is Failure<ValidatedItem>) {
    return const MasterDataRejected(CallableError.internal);
  }
  final ValidatedItem scrapItem = (scrap as Success<ValidatedItem>).value;

  final UniquenessGuardRead? guard = request.guard;
  if (guard == null ||
      guard.collectionId != uniqueItemNamesCollection ||
      guard.key != scrapItem.normalizedName) {
    return const MasterDataRejected(CallableError.internal);
  }
  if (guard.isTakenByOther(scrapItemId)) {
    return const MasterDataRejected(CallableError.duplicateItemName);
  }

  final Map<String, Object?> businessFields = settings.businessFields;
  final Map<String, Object?> formattingFields = settings.formattingFields;
  final Map<String, Object?> scrapFields = <String, Object?>{
    ..._itemFields(scrapItem),
    // ⚠️ **وتُفرَّغ قائمة المصادر فعلياً في المستند** — `sourceIds` أعلاه
    //   حملت قيمة نائبة لتجتاز فحص «غير فارغة» في طبقة النطاق، ★ **والوصل
    //   الحقيقي مهمّة تهيئة الحسابات.**
    'sourceIds': const <String>[],
    'itemId': scrapItemId,
    'createdBy': request.actor.userId,
  };

  final List<MasterDataWrite> writes = <MasterDataWrite>[
    MasterDataWrite(
      collectionId: appSettingsCollection,
      documentId: appSettingsBusinessDocId,
      fields: businessFields,
      updateMask: businessFields.keys.toList(),
      serverTimestampFields: const <String>['createdAt'],
    ),
    MasterDataWrite(
      collectionId: appSettingsCollection,
      documentId: appSettingsFormattingDocId,
      fields: formattingFields,
      updateMask: formattingFields.keys.toList(),
      serverTimestampFields: const <String>['createdAt'],
    ),
    MasterDataWrite(
      collectionId: itemsCollection,
      documentId: scrapItemId,
      fields: scrapFields,
      updateMask: scrapFields.keys.toList(),
      serverTimestampFields: const <String>['createdAt'],
    ),
    _guardWrite(
      collectionId: uniqueItemNamesCollection,
      key: scrapItem.normalizedName,
      entityId: scrapItemId,
    ),
  ];

  return MasterDataAccepted(
    entityId: appSettingsBusinessDocId,
    writes: writes,
    entry: _entry(
      request: request,
      action: AuditAction.create,
      entityType: appSettingsEntityType,
      entityId: appSettingsBusinessDocId,
      reason: null,
      valuesBefore: const <String, Object?>{},
      valuesAfter: <String, Object?>{
        ...businessFields,
        ...formattingFields,
        'scrapItemId': scrapItemId,
      },
    ),
  );
}

/// ★ قيمة نائبة تجتاز شرط «المصادر غير فارغة» عند تأسيس السكرب.
///
/// ⚠️ **ولا تُكتب في المستند إطلاقاً** — راجع تعليق `sourceIds` أعلاه.
const String _scrapBootstrapSource = 'bootstrap';

// ═════════════════════════════════════════════════════════════════════════
// مشتركات التخطيط
// ═════════════════════════════════════════════════════════════════════════

/// ★ يفحص أن المستند موجود عند التعديل وغائب عند الإنشاء.
///
/// ⚠️ **ولماذا الاتجاهان معاً:** تعديلُ ما لا يوجد **يُنشئ مستنداً بلا
/// «قبل»** ⟵ فيشهد السجل على تعديلٍ لا يُعرَف ماذا كان؛ **وإنشاءٌ فوق
/// قائم يمحو مستنداً حياً** — ★ **وهو أخطر ما يفعله كودٌ محاسبي.**
MasterDataRejected? _existenceGate(
  MasterDataRequest request,
  MasterDataOperation operation,
) {
  final bool exists = request.stored != null;
  if (operation.isCreate && exists) {
    return const MasterDataRejected(CallableError.invalidArgument);
  }
  if (!operation.isCreate && !exists) {
    return const MasterDataRejected(CallableError.invalidArgument);
  }
  return null;
}

/// ★ يفحص سجل حراسة التفرد — ⛔ **ونقصُ القراءة رفضٌ لا تجاوز**.
MasterDataRejected? _guardGate({
  required MasterDataRequest request,
  required String expectedCollection,
  required String expectedKey,
  required CallableError duplicateError,
}) {
  final UniquenessGuardRead? guard = request.guard;
  // ⛔★★ **حارسٌ لم يُقرأ ⟵ رفض** — ★ **الرفض الافتراضي**: مسارٌ نسي قراءة
  //    الحارس كان سيكتب اسماً مكرراً **بلا أي إشارة**.
  if (guard == null ||
      guard.collectionId != expectedCollection ||
      guard.key != expectedKey) {
    return const MasterDataRejected(CallableError.internal);
  }
  if (guard.isTakenByOther(request.entityId)) {
    return MasterDataRejected(duplicateError);
  }
  return null;
}

/// هل كان السجل نشطاً قبل هذا الطلب؟ — ★ **والغياب يُقرأ «نشطاً»** لأن
/// الإنشاء يبدأ نشطاً.
bool _wasActive(MasterDataRequest request) =>
    request.stored?['isActive'] != false;

MasterDataPlan _accept({
  required MasterDataRequest request,
  required MasterDataOperation operation,
  required String? amendReason,
  required String collectionId,
  required String idField,
  required Map<String, Object?> after,
  required String guardCollection,
  required String guardKey,
  String? auditSourceId,
  AuditAction? overrideAction,
}) {
  final Map<String, Object?> fields = <String, Object?>{
    ...after,
    // ★ **المعرّف داخل المستند أيضاً** — `data-dictionary.md` §1 (PK ⚙️)،
    //   ⟵ **فالاستعلام الجماعي يحمله بلا قراءة معرّف المستند.**
    idField: request.entityId,
    if (operation.isCreate) 'createdBy': request.actor.userId,
  };

  final List<MasterDataWrite> writes = <MasterDataWrite>[
    MasterDataWrite(
      collectionId: collectionId,
      documentId: request.entityId,
      fields: fields,
      updateMask: fields.keys.toList(),
      // ⛅ **وقت الخادم عند الإنشاء وحده** — `data-dictionary.md`:
      //   `createdAt` ⚙️ **بتوقيت الخادم**. ⛔ **والتعديل لا يمسّه.**
      serverTimestampFields:
          operation.isCreate ? const <String>['createdAt'] : const <String>[],
    ),
    // ★ **حارس التفرد داخل المعاملة نفسها** — `master-data-design.md` §3:
    //   «وبلا ذلك يستطيع مستخدمان إنشاء نفس الرقم في نفس اللحظة».
    // ⚠️ **ويُكتب عند التعديل أيضاً إن تغيّر المفتاح** — ⛔ **والقديم يبقى
    //   محجوزاً**: «التفرد لا يُنقض» (`firestore.rules` §10)، ★ **وهو أثر
    //   معلَن**: الاسم القديم لا يُعاد استعماله.
    _guardWrite(
      collectionId: guardCollection,
      key: guardKey,
      entityId: request.entityId,
    ),
  ];

  final Map<String, Object?> before = request.stored ?? const <String, Object?>{};
  final Map<String, Object?> changedBefore = <String, Object?>{};
  final Map<String, Object?> changedAfter = <String, Object?>{};
  if (!operation.isCreate) {
    // ★ **الحقول المتغيرة فقط** — `audit-log-design.md` §8: «⛔ لا تُسجَّل
    //   قيم حساسة زائدة … بلا نسخ المستند كاملاً».
    for (final MapEntry<String, Object?> entry in after.entries) {
      if (!_sameValue(before[entry.key], entry.value)) {
        changedBefore[entry.key] = before[entry.key];
        changedAfter[entry.key] = entry.value;
      }
    }
  }

  return MasterDataAccepted(
    entityId: request.entityId,
    writes: writes,
    entry: _entry(
      request: request,
      action: overrideAction ??
          (operation.isCreate ? AuditAction.create : AuditAction.amend),
      reason: operation.isCreate ? null : amendReason,
      entityType: operation.entityType,
      entityId: request.entityId,
      sourceId: auditSourceId,
      valuesBefore: operation.isCreate ? const <String, Object?>{} : changedBefore,
      valuesAfter: operation.isCreate ? after : changedAfter,
    ),
  );
}

MasterDataWrite _guardWrite({
  required String collectionId,
  required String key,
  required String entityId,
}) =>
    MasterDataWrite(
      collectionId: collectionId,
      documentId: key,
      fields: <String, Object?>{
        guardEntityIdField: entityId,
        guardNormalizedField: key,
      },
      updateMask: <String>[guardEntityIdField, guardNormalizedField],
      serverTimestampFields: const <String>['createdAt'],
    );

/// ★ مقارنة قيمتين — **والقوائم تُقارَن عنصراً بعنصر**.
///
/// ⚠️ **ولماذا ليست `==`:** `sourceIds` قائمة، و`==` عليها **مقارنة مرجع**
/// ⟵ **فكل تعديلٍ كان سيبدو تغييراً في المصادر** ولو لم تتغيّر.
bool _sameValue(Object? a, Object? b) {
  if (a is List<Object?> && b is List<Object?>) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (!_sameValue(a[i], b[i])) return false;
    }
    return true;
  }
  // ★ **والعدد الصحيح يساوي نظيره العشري** — القاعدة تُرجِع `1` أحياناً
  //   و`1.0` أحياناً لنفس القيمة، ⛔ **وقراءة ذلك «تغييراً» ضجيجٌ في السجل.**
  if (a is num && b is num) return a == b;
  return a == b;
}

/// ★ سبب التعديل مقصوصاً، أو `null` إن غاب أو كان فراغات — `ADR-0004`.
String? _amendReason(
  MasterDataRequest request,
  MasterDataOperation operation,
) {
  if (operation.isCreate) return null;
  final String? raw = request.amendReason?.trim();
  return (raw == null || raw.isEmpty) ? null : raw;
}

AuditEntry _entry({
  required MasterDataRequest request,
  required AuditAction action,
  required String entityType,
  required String entityId,
  required String? reason,
  required Map<String, Object?> valuesBefore,
  required Map<String, Object?> valuesAfter,
  String? sourceId,
}) =>
    AuditEntry(
      id: request.requestId.trim(),
      // ⚠️ قيمة مبدئية لا تُكتب — الكاتب يستبدلها بوقت المنصة.
      occurredAt: DateTime.utc(1970),
      actor: AuditActor(
        userId: request.actor.userId,
        userName: request.actor.userName,
        // ★★★ **والبريد منسوخٌ وقت الحدث** — `AM-012` §3.
        userEmail: request.actor.userEmail,
      ),
      action: action,
      reason: reason,
      target: sourceId == null
          ? AuditTarget(entityType: entityType, entityId: entityId)
          : AuditTarget(
              entityType: entityType,
              entityId: entityId,
              sourceId: sourceId,
            ),
      valuesBefore: valuesBefore,
      valuesAfter: valuesAfter,
      deviceInfo: request.deviceInfo,
    );

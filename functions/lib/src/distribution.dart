/// التوزيع والضمار — **التخطيط الخالص** لعمليات `WU-006` (`M10`).
///
/// ★ **مفصول عن الشبكة بنفس منطق `inventory.dart`:** `ADR-0013` القاعدة 3
/// تجعل **فحص التفويض في الكود** هو الحارس الوحيد لهذا المسار، فالدالة تعمل
/// بامتياز إداري يتجاوز قواعد الحماية. ★ **وحارسٌ لا يُختبَر بلا سحابة
/// حارسٌ غير مُختبَر** — فكل قرار هنا **دالة خالصة**.
///
/// ★ **وكل معادلة من طبقة النطاق لا من هنا** (`qtms_domain`) —
/// ⛔ **ولا تُعاد كتابتها** (`coding-standards.md` §2.2 · `ADR-0009`).
/// ★★ **ومنها تحديداً [distributionLineTotal]** — **الموضع الثالث للتقريب**
/// (`ADR-0019`)، ⛔ **ولا نسخة ثانية منه هنا.**
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔★★ **عشرة قيود بندُ قبولٍ مُلزِم لهذه الدالة** (`DEBT-21` · `CR-002`):
///
///   ① **الصلاحية** (`distributionCreate` / `Amend` / `Cancel`).
///   ② ★★ **نطاق المصادر** — ⛔ **قيدٌ يعلو على كل صلاحية** (`GR-23`).
///   ③ **تاريخ المخزون = يوم المنصّة** (`FR-M10-03` · `A-10` · `GR-14`)
///      — ⚠️ **إلا في التصريف المتأخر بمفتاحه** (`agedRemainderClear`).
///   ④ **وقت الخادم في `entryDate` و`createdAt`** (`GR-54` · `E-41`).
///   ⑤ **السبب النصي غير الفارغ لكل تعديل وإلغاء** (`ADR-0004` الشرط 2).
///   ⑥ ★★ **منع الرصيد السالب** (`FR-M8-01` · `GR-11`) — ★ **مقيساً من
///      الدفتر داخل المعاملة** ⛔ **لا من الملخص ولا من الجهاز.**
///   ⑦ ★★★ **`GR-18` المعرّف المركّب بترتيبه** — [distributionId]:
///      ⟵ **وإنشاءٌ فوق قائم يُرفَض بـ`ERR_DIST_001`** ⛔ **ولا يمحو ضماراً.**
///   ⑧ ★★★ **السعر لا يُكتب إلا من مالك مفتاحه** (`FR-M10-10` · `ت-12`) —
///      ⟵ **«إخفاء الحقل تسهيل واجهة لا حماية»**، ⛔ **والحارس هنا.**
///   ⑨ ★★ **الحقول المالية لا تعيش في المستند الأب** (`ADR-0011`) —
///      ⟵ **`unitPrices[]` و`lineTotals[]` و`debtValue` في `pricing/current`.**
///   ⑩ **الحذف مرفوض نهائياً** — ⟵ **ولا مسار حذف في هذا الملف أصلاً.**
/// ═══════════════════════════════════════════════════════════════════════
library;

import 'package:qtms_domain/qtms_domain.dart';

import 'aged_remainder.dart';
import 'callable.dart';
import 'firestore_value.dart' show DecimalValue;
import 'identity_gateway.dart';
import 'inventory.dart';

/// نوع عملية توزيع — ويحدد الصلاحية التي لا تُنفَّذ بدونها.
enum DistributionOperation {
  /// `createDistribution` — يشترط `distributionCreate` (`FR-M10` §4).
  createDistribution(Permission.distributionCreate, isCreate: true),

  /// `amendDistribution` — يشترط `distributionAmend` ★ **وسبباً نصياً**
  /// (`FR-M10-16` · `ADR-0004`).
  amendDistribution(Permission.distributionAmend, isCreate: false),

  /// `cancelDistribution` — يشترط `distributionCancel` ★ **وسبباً نصياً**.
  ///
  /// ⛔★★ **وليس حذفاً:** الإلغاء **وسمٌ يُستبعَد من الجمع** (`GR-06` ·
  /// `A-14`)، ★ **والحركات والقيد يبقيان مقروءَين مشطوبَين.**
  cancelDistribution(
    Permission.distributionCancel,
    isCreate: false,
    isCancel: true,
  );

  const DistributionOperation(
    this.requiredPermission, {
    required this.isCreate,
    this.isCancel = false,
  });

  /// الصلاحية التي لا تُنفَّذ العملية بدونها.
  final Permission requiredPermission;

  /// هل هي إنشاء؟
  final bool isCreate;

  /// هل هي إلغاء؟
  final bool isCancel;
}

/// قيدٌ قائم في دفتر المقاوته كما قُرئ — **بمعرّفه** ليُميَّز صاحبه.
final class DealerLedgerRead {
  /// ينشئ القراءة.
  const DealerLedgerRead({required this.entryId, required this.entry});

  /// معرّف مستند القيد.
  final String entryId;

  /// القيد كما يدخل الجمع.
  final DealerLedgerEntry entry;
}

/// نتيجة التخطيط — إما خطة كتابة وإما رفض مصنَّف.
sealed class DistributionPlan {
  /// ينشئ النتيجة.
  const DistributionPlan();
}

/// رُفض الطلب قبل أي كتابة.
final class DistributionRejected extends DistributionPlan {
  /// ينشئ رفضاً.
  const DistributionRejected(this.error);

  /// رمز الرفض من كتالوج الأخطاء.
  final CallableError error;
}

/// قُبل الطلب — وهذه كتاباته وقيده.
final class DistributionAccepted extends DistributionPlan {
  /// ينشئ خطة مقبولة.
  const DistributionAccepted({
    required this.documentNumber,
    required this.distributionId,
    required this.writes,
    required this.entry,
  });

  /// رقم المستند — `DST-YYYYMMDD-####`.
  final String documentNumber;

  /// ★ المعرّف المركّب — **وهو معرّف المستند فعلياً** (`GR-18`).
  final String distributionId;

  /// المستندات المكتوبة — ⛔ **ولا تكون فارغة**.
  final List<InventoryWrite> writes;

  /// قيد التدقيق — **يُكتب في المعاملة نفسها** (`ADR-0013` القاعدة 1).
  final AuditEntry entry;
}

/// طلب توزيع مُتحقَّق من هوية مُنفِّذه.
final class DistributionRequest {
  /// ينشئ الطلب.
  const DistributionRequest({
    required this.actor,
    required this.requestId,
    required this.sourceId,
    required this.dealerId,
    required this.documentNumber,
    required this.stockDate,
    this.serverDay,
    this.distribution,
    this.storedSource,
    this.storedDealer,
    this.storedDocument,
    this.storedUnitPrices = const <String, Money?>{},
    this.storedSettlement,
    this.items = const <String, ItemRead>{},
    this.ledger = const <String, List<LedgerRead>>{},
    this.dealerLedger = const <DealerLedgerRead>[],
    this.surplusPools = const <SurplusPoolRead>[],
    this.hasStoredPricing = false,
    this.reason,
    this.deviceInfo,
  });

  /// المُنفِّذ **بحالته الآن من خدمة المصادقة**.
  final AccountRecord actor;

  /// ★ معرّف الطلب — **وهو معرّف قيد التدقيق نفسه** (`api-overview.md` §4).
  final String requestId;

  /// المصدر المستهدف.
  final String sourceId;

  /// المقوت المستهدف.
  final String dealerId;

  /// رقم المستند — **المخصَّص عند الإنشاء والقائم عند التعديل**.
  final String documentNumber;

  /// ★★ **تاريخ المخزون** — ⛔ **من زمن المنصّة داخل المعاملة**.
  ///
  /// ⚠️★★ **ويقبل يوماً أقدم في مسار التصريف المتأخر وحده** (`WU-019`) —
  /// ★ **بشرط [serverDay] و`agedRemainderClear` معاً** (`FR-M8-11`).
  final CalendarDay stockDate;

  /// ★★★ **يوم المنصّة كما قُرئ داخل المعاملة** — و`null` **«غيرُ معلوم»**.
  ///
  /// ⛔⛔★★★ **وهو الحدُّ الذي يفصل «اليوم» عن «المتأخر»** — ★ **يُمرَّر في
  /// مسار الإنشاء وحده**: ⟵ **والتعديلُ والإلغاءُ يومُهما محفورٌ في رقم
  /// المستند ولا يُعاد تقريرُه** (`documentNumberDay`)، ⛔ **فلا يُخمَّن حكمٌ
  /// من غياب** ([isAgedClearanceOn]).
  final CalendarDay? serverDay;

  /// ★ هل هذه العملية **تصريفُ متبقٍّ متأخر**؟ — `FR-M8-11`.
  bool get isAgedClearance =>
      isAgedClearanceOn(stockDate: stockDate, serverDay: serverDay);

  /// المستند المُتحقَّق منه — `null` للإلغاء.
  final ValidatedDistribution? distribution;

  /// سجل المصدر كما قُرئ — ⛔ **و`null` رفضٌ لا تجاوز**.
  final Map<String, Object?>? storedSource;

  /// سجل المقوت كما قُرئ — ⛔ **و`null` رفضٌ لا تجاوز**.
  final Map<String, Object?>? storedDealer;

  /// المستند الأب القائم — `null` تعني **غيابه**.
  final Map<String, Object?>? storedDocument;

  /// 🔒 **الأسعار المخزَّنة بمفتاح نوعها** — من `pricing/current`.
  ///
  /// ⚠️⚠️ **وهي مرجع فحص الصلاحية لا الحمولة** (`FR-M10-10`): ⟵ **الفرق
  /// بين المُرسَل والمخزَّن هو ما يُقابَل بالمفاتيح الثلاثة**، ⛔ **فمن
  /// أعاد إرسال السعر نفسه لم «يُعدِّل» شيئاً.**
  final Map<String, Money?> storedUnitPrices;

  /// ★ هل يوجد مستند أسعار مخزَّن أصلاً؟
  ///
  /// ⚠️ **ويلزم مستقلاً عن [storedUnitPrices]:** مستندٌ موجود بأسعارٍ كلها
  /// `null` **يُنتج خريطةً فارغة**، ⟵ **وغيابُه يُنتج الفارغةَ نفسها**،
  /// ⛔ **والفرق بينهما يقرر: أيُعاد بناؤه للمحاذاة أم لا يُكتب أصلاً؟**
  final bool hasStoredPricing;

  /// ★★ **تسوية الضمار المخزَّنة** — ⛔ **وحارس الإلغاء وحدها** (`E-15`).
  ///
  /// ⚠️ **و`null` تعني «لم تُكتب بعد» ⟵ لم يُمَسّ الضمار** (`ADR-0008`
  /// القاعدة 5: **لا يُنشأ سجل بصفر بلا داعٍ**).
  final DebtSettlement? storedSettlement;

  /// سجلات الأنواع المطلوبة بمعرّفاتها.
  final Map<String, ItemRead> items;

  /// ★★ **حركات دفتر المخزون لكل نوع** — **مقروءةً داخل المعاملة**.
  final Map<String, List<LedgerRead>> ledger;

  /// ★★ **قيود دفتر المقوت في هذا المصدر** — **مقروءةً داخل المعاملة**.
  ///
  /// ⛔ **ولا قيود مصدرٍ آخر معها** (`GR-20`) — ★ **والفلترة في الاستعلام
  /// لا بعد الجمع.**
  final List<DealerLedgerRead> dealerLedger;

  /// ★★★ **سجلات الفائض المتاح للمقوت** — **مقروءةً داخل المعاملة**.
  ///
  /// ⛔⛔★★★ **وهي مدخل `FR-M12-11`** («**عند إنشاء ضمار جديد للمقوت يسدد
  /// النظام تلقائياً من فائضه المتاح**») — ★ **والتطبيق هنا لا في مسار
  /// القبض**: ⟵ **لأن مُطلِقَه إنشاءُ الضمار لا وصولُ المال**
  /// (`settlement-design.md` §11).
  final List<SurplusPoolRead> surplusPools;

  /// ★ سبب التعديل أو الإلغاء — **إلزامي لكليهما** (`ADR-0004` الشرط 2).
  final String? reason;

  /// وصف الجهاز للسجل — ⛔ بلا بيانات حساسة.
  final String? deviceInfo;

  /// ★ المعرّف المركّب لهذا الطلب — [distributionId] (`GR-18`).
  String get compositeId => distributionId(
        dealerId: dealerId,
        sourceId: sourceId,
        stockDate: stockDate,
      );
}

/// ★★ فحوص الحالة والصلاحية والنطاق — **تُستدعى قبل فتح المعاملة**.
///
/// ⚠️ **ولماذا مُصدَّرة:** كل عملية هنا تحتاج **قراءةً داخل معاملة** قبل أن
/// يكتمل تخطيطها، ⟵ **وفتحُ معاملةٍ لطلبٍ يرفضه نقصُ الصلاحية هدرٌ وقفلٌ
/// بلا داعٍ**. ★ **والفحص يُعاد كاملاً** في [planDistribution] ⛔ **فلا مسار
/// يتخطّاه.**
DistributionRejected? distributionGate(
  DistributionRequest request,
  DistributionOperation operation,
) {
  // ① «التعطيل فوري ونافذ» — `authentication-policy.md` §2 القاعدة 3.
  if (request.actor.disabled) {
    return const DistributionRejected(CallableError.accountDisabled);
  }
  // ② الصلاحية — ⛔ ولا قاعدة حماية تحرس هذا المسار.
  if (!request.actor.claims.has(operation.requiredPermission)) {
    return const DistributionRejected(CallableError.permissionMissing);
  }
  // ③ ★★ **النطاق — قيدٌ يعلو على الصلاحية** (`GR-23`).
  //    ⛔ **والغياب منعٌ لا سماح.**
  if (!request.actor.claims.canAccessSource(request.sourceId)) {
    return const DistributionRejected(CallableError.sourceOutOfScope);
  }
  // ④ معرّف الطلب إلزامي — وبدونه لا تتحقق اللاتكرارية عند إعادة الإرسال.
  if (request.requestId.trim().isEmpty) {
    return const DistributionRejected(CallableError.invalidArgument);
  }
  // ⑤ المقوت إلزامي — ⛔ ولا ذمة بلا مَدين.
  if (request.dealerId.trim().isEmpty) {
    return const DistributionRejected(CallableError.invalidArgument);
  }
  return null;
}

/// يخطّط عملية توزيع — **دالة خالصة، وهي حارس التفويض الفعلي**.
DistributionPlan planDistribution(
  DistributionRequest request,
  DistributionOperation operation,
) {
  final DistributionRejected? gate = distributionGate(request, operation);
  if (gate != null) return gate;

  if (request.documentNumber.trim().isEmpty) {
    return const DistributionRejected(CallableError.invalidArgument);
  }

  // ⛔⛔★★★ **حارسُ السبب حُذف بـ`ADR-0020` (2026-08-27)** — ★ **السبب
  //    اختياريٌّ في كل عملية**، ⟵ **ولا رفضَ لغيابه.** ⛔ **ولا يُعبَّأ
  //    آلياً:** ★ **ما لم يكتبه إنسانٌ لا يُخزَّن.**
  final String? reason = _trimmed(request.reason);
  final DistributionRejected? existence = _existenceGate(request, operation);
  if (existence != null) return existence;

  final DistributionRejected? parties = _partiesGate(request, operation);
  if (parties != null) return parties;

  // ③ ★★★ **تاريخ المخزون = يوم المنصّة — إلا بمفتاح التصريف المتأخر**
  //    (`FR-M10-03` · `FR-M8-11` · `agedRemainderClear`): ⟵ **والحُكمُ هنا
  //    في الدالة الخالصة** ⛔ **لا في المنفِّذ**: ★ **فقواعدُ الحماية لا
  //    تحرس هذا المسار أصلاً** (`ADR-0013` القاعدة 3).
  if (request.serverDay case final CalendarDay serverDay) {
    final CallableError? denied = agedClearanceRejection(
      actor: request.actor,
      stockDate: request.stockDate,
      serverDay: serverDay,
    );
    if (denied != null) return DistributionRejected(denied);
  }

  return operation.isCancel
      ? _planCancellation(request, reason)
      : _planDistribution(request, operation, reason);
}

// ═════════════════════════════════════════════════════════════════════════
// الإنشاء والتعديل
// ═════════════════════════════════════════════════════════════════════════

DistributionPlan _planDistribution(
  DistributionRequest request,
  DistributionOperation operation,
  String? reason,
) {
  final ValidatedDistribution? distribution = request.distribution;
  if (distribution == null ||
      distribution.sourceId != request.sourceId ||
      distribution.dealerId != request.dealerId) {
    return const DistributionRejected(CallableError.invalidArgument);
  }

  // ★ الأنواع: **موجودة · نشطة · مرتبطة بالمصدر · بوحدتها المخزَّنة**.
  for (final ValidatedDistributionLine line in distribution.lines) {
    final ItemRead? item = request.items[line.itemKey];
    if (item == null || !item.isActive) {
      return const DistributionRejected(CallableError.invalidArgument);
    }
    // ★★ `FR-M5-10`: **النوع لا يظهر إلا في مصادره** — ⛔ **والواجهة تُخفي،
    //    وهذا السطر يمنع.**
    if (!item.sourceIds.contains(request.sourceId)) {
      return const DistributionRejected(CallableError.invalidArgument);
    }
    // ⛔ **ووحدة السطر = وحدة النوع المخزَّنة** — `FR-M5-03` · `GR-19`.
    if (line.quantity.unit != item.unit) {
      return const DistributionRejected(CallableError.itemUnitLocked);
    }
  }

  // ⑧ ★★★ **حارس السعر** — `FR-M10-10` · `ت-12` (راجع [_priceGate]).
  final DistributionRejected? price = _priceGate(request, operation, distribution);
  if (price != null) return price;

  // ★★ **كل نوعٍ يلمسه هذا المستند** — الجديد **والمحذوف من التعديل معاً**.
  final Map<String, StockQuantity> desired = <String, StockQuantity>{
    for (final ValidatedDistributionLine line in distribution.lines)
      line.itemKey: line.quantity,
  };
  final Map<String, String?> sackIds = <String, String?>{
    for (final ValidatedDistributionLine line in distribution.lines)
      line.itemKey: line.sackId,
  };
  final Set<String> touched = <String>{...desired.keys, ...request.ledger.keys};

  final List<InventoryWrite> writes = <InventoryWrite>[];
  for (final String itemKey in touched.toList()..sort()) {
    final Outcome<List<InventoryWrite>> planned = _planItem(
      request: request,
      itemKey: itemKey,
      desired: desired[itemKey],
      sackId: sackIds[itemKey],
      isCreate: operation.isCreate,
      reason: reason,
    );
    if (planned case Failure<List<InventoryWrite>>(:final AppError error)) {
      return DistributionRejected(_mapStockError(error, operation));
    }
    writes.addAll((planned as Success<List<InventoryWrite>>).value);
  }

  // ★★★ **تطبيق الفائض تلقائياً** — `FR-M12-11` · `AT-31` · `E-11`.
  //
  // ⛔⛔★★★ **وعلى الإنشاء وحده** — نصّ المتطلب: «**عند إنشاء ضمار جديد**»
  //    ⟵ **والتعديل يُعيد بناء القيمة لا يُنشئ ضماراً**، ⛔ **وتطبيقُه هناك
  //    كان يسحب فائضاً ثانياً لضمارٍ سُحِب له أصلاً.**
  final List<SurplusApplication> applications = operation.isCreate
      ? planSurplusApplication(
          debtValue: distribution.debtValue,
          sourceId: request.sourceId,
          pools: request.surplusPools,
        )
      : const <SurplusApplication>[];

  // ★★★ **القيد المدين وأثره على الرصيد** — `design-overview.md` §2.4.
  writes.addAll(
    _dealerWrites(
      request: request,
      debtValue: distribution.debtValue,
      isCancelled: false,
      isCreate: operation.isCreate,
      reason: reason,
      applications: applications,
    ),
  );

  writes.addAll(_surplusApplicationWrites(request, applications));

  // ⑩ ★★★ **وتسويةُ الضمار تُكتَب دائماً** — `DEBT-85` (راجع
  //    [_settlementWrites]): ⛔ **لا عند تطبيق الفائض وحده.**
  writes.addAll(
    _settlementWrites(request: request, applications: applications),
  );

  final Map<String, Object?> after = _documentFields(request, distribution);
  writes.insert(0, _documentWrite(request, operation, after, reason));

  // ⑨ ★★ **الأسعار في مستندها الفرعي وحدها** — `ADR-0011`.
  final InventoryWrite? pricing = _pricingWrite(request, distribution, reason);
  if (pricing != null) writes.insert(1, pricing);

  return DistributionAccepted(
    documentNumber: request.documentNumber,
    distributionId: request.compositeId,
    writes: writes,
    entry: _entry(
      request: request,
      // ★★★ **وفعلُ التصريف المتأخر باسمه** — `FR-M18-08` (**إجراءٌ واجبُ
      //    التسجيل**): ⛔ **ولا يُسجَّل «إنشاءً» عادياً**، ⟵ **فالسجلُّ
      //    يُقرأ للتمييز بين ما وقع اليوم وما وقع على يومٍ مضى.**
      action: request.isAgedClearance
          ? AuditAction.agedRemainderClear
          : (operation.isCreate ? AuditAction.create : AuditAction.amend),
      reason: reason,
      valuesBefore: operation.isCreate
          ? const <String, Object?>{}
          : _changedBefore(request.storedDocument, after),
      valuesAfter: operation.isCreate
          ? after
          : _changedAfter(request.storedDocument, after),
    ),
  );
}

// ═════════════════════════════════════════════════════════════════════════
// الإلغاء — ★ **بالوسم** ⛔ **بلا حركة عكسية ولا حذف** (`GR-06` · `GR-07`)
// ═════════════════════════════════════════════════════════════════════════

/// ⛔★★ **و[reason] صار `String?` بـ`ADR-0020`** — ★ **وكانت `!` عليه
/// آمنةً بحارسٍ حُذف**، ⟵ **فلولا تليينُ التوقيع لأسقط المسارَ كلَّه.**
DistributionPlan _planCancellation(
  DistributionRequest request,
  String? reason,
) {
  // ⛔⛔★★★ **حارس `E-15` — ولا يُقاس بحالة التسوية** (راجع طبقة النطاق).
  final DebtSettlement settlement = request.storedSettlement ??
      computeDebtSettlement(
        debtValue: Money.zero,
        settledAmount: Money.zero,
        discountedAmount: Money.zero,
      );
  final Outcome<void> cancellable =
      validateDistributionCancellable(settlement);
  if (cancellable is Failure<void>) {
    return const DistributionRejected(CallableError.settledDebtBlocksCancel);
  }

  final List<InventoryWrite> writes = <InventoryWrite>[];
  for (final String itemKey in request.ledger.keys.toList()..sort()) {
    final Outcome<List<InventoryWrite>> planned = _planItem(
      request: request,
      itemKey: itemKey,
      // ⛔ **لا كمية باقية** — كل حركات المستند تُوسَم ملغاة.
      desired: null,
      sackId: null,
      isCreate: false,
      reason: reason,
      cancelOwn: true,
    );
    if (planned case Failure<List<InventoryWrite>>(:final AppError error)) {
      return DistributionRejected(
        _mapStockError(error, DistributionOperation.cancelDistribution),
      );
    }
    writes.addAll((planned as Success<List<InventoryWrite>>).value);
  }

  // ★★ **والقيد المدين يُوسَم ملغى فيسقط من الرصيد** — ⛔ **بلا قيدٍ مضاد.**
  writes.addAll(
    _dealerWrites(
      request: request,
      debtValue: Money.zero,
      isCancelled: true,
      isCreate: false,
      reason: reason,
    ),
  );

  final Map<String, Object?> fields = <String, Object?>{
    documentStatusField: DistributionStatus.cancelled.name,
    'cancelReason': reason,
    'cancelledBy': request.actor.userId,
  };
  writes.insert(
    0,
    InventoryWrite(
      collectionId: distributionsCollection,
      documentId: request.compositeId,
      fields: fields,
      // ★ **قناعٌ ضيّق** — ⛔ **فلا يمحو الإلغاءُ سطوراً ولا تاريخ مخزون.**
      updateMask: fields.keys.toList(),
      serverTimestampFields: const <String>['cancelledAt'],
    ),
  );

  return DistributionAccepted(
    documentNumber: request.documentNumber,
    distributionId: request.compositeId,
    writes: writes,
    entry: _entry(
      request: request,
      // ★ **الإلغاء فعلٌ مستقل في المعجم لا «تعديل»** — فيُقرأ من السجل بذاته.
      action: AuditAction.cancel,
      reason: reason,
      valuesBefore: <String, Object?>{
        documentStatusField: request.storedDocument?[documentStatusField] ??
            DistributionStatus.approved.name,
      },
      valuesAfter: <String, Object?>{
        documentStatusField: DistributionStatus.cancelled.name,
      },
    ),
  );
}

// ═════════════════════════════════════════════════════════════════════════
// ⑧ ★★★ حارس السعر — `FR-M10-07` · `FR-M10-09` · `FR-M10-10` · `ت-12`
// ═════════════════════════════════════════════════════════════════════════

/// ★★★ **يقابل فرق الأسعار بمفاتيحه الثلاثة** — ⛔ **لا وجودَها بمفتاحٍ واحد**.
///
/// ═══════════════════════════════════════════════════════════════════════
/// | ما جرى للسعر | المفتاح المطلوب | المصدر |
/// |---|---|---|
/// | **سعرٌ يُدخَل حيث لا سعر** | `distributionPriceNow` | «تسعير التوزيع الآن» |
/// | **سعرٌ قائم يتغيّر** | `distributionPriceAmend` | «تعديل سعر التوزيع» |
/// | **سعرٌ قائم يُفرَّغ** | `distributionPriceClear` | «تفريغ سعر التوزيع» |
/// ═══════════════════════════════════════════════════════════════════════
///
/// ★★ **والتفريق من نصّ الكتالوج §2.3 حرفياً** (`permissions-catalog.md`) —
/// ⛔ **ولا مفتاح مُخترَع:** `FR-M10` §4 يذكر «تسعير التوزيع لاحقاً» بالاسم
/// المعروض، ⟵ **ولا سطر له في §2 من الكتالوج** (**74 مفتاحاً**)، ★ **وإدخالُ
/// سعرٍ حيث لا سعر هو «تسعير الآن» بنصّ المفتاح لا «تعديل سعر»** — **فلا
/// حاجة لمفتاحٍ رابع**، ⛔ **وإضافةُ مفتاح تُرفَض في المراجعة بلا سطرٍ في
/// المستند** (`BR-M1-07`).
///
/// ⚠️⚠️ **والمقارنة بالمخزَّن لا بالحمولة:** ⟵ **من أعاد إرسال السعر نفسه
/// لم يُعدِّل شيئاً**، ⛔ **ومطالبتُه بمفتاح التعديل كانت ستمنع إعادة إرسالٍ
/// بريئة** (نفس منطق `changesStoredPrice` في التسعير اليومي).
///
/// ⛔⛔★★ **ولا يُفحَص «هل يحمل سعراً» وحده:** `FR-M10-07` — **من لا يملك
/// رؤية السعر تُحتسب توزيعتُه مسعَّرةً كاملةً** ⟵ **والتطبيق يُرسل السعر
/// عنه من التسعير اليومي**؛ ★ **فالحارس على مَن يُغيّر السعر لا على مَن
/// يُمرّره كما هو.**
DistributionRejected? _priceGate(
  DistributionRequest request,
  DistributionOperation operation,
  ValidatedDistribution distribution,
) {
  bool entersNewPrice = false;
  bool changesStoredPrice = false;
  bool clearsStoredPrice = false;

  for (final ValidatedDistributionLine line in distribution.lines) {
    final Money? stored =
        operation.isCreate ? null : request.storedUnitPrices[line.itemKey];
    final Money? next = line.unitPrice;
    if (stored == null && next != null) entersNewPrice = true;
    if (stored != null && next == null) clearsStoredPrice = true;
    if (stored != null && next != null && stored.riyals != next.riyals) {
      changesStoredPrice = true;
    }
  }
  // ★ **وسطرٌ حُذف من التعديل وكان مسعَّراً تفريغٌ كذلك** — ⟵ **فالسعر
  //   يختفي من المستند فعلاً**، ⛔ **والحذف ليس بابَ التفافٍ على المفتاح.**
  if (!operation.isCreate) {
    final Set<String> remaining = <String>{
      for (final ValidatedDistributionLine line in distribution.lines)
        line.itemKey,
    };
    for (final MapEntry<String, Money?> entry
        in request.storedUnitPrices.entries) {
      if (entry.value != null && !remaining.contains(entry.key)) {
        clearsStoredPrice = true;
      }
    }
  }

  if (entersNewPrice &&
      !request.actor.claims.has(Permission.distributionPriceNow)) {
    return const DistributionRejected(CallableError.distributionPricingDenied);
  }
  if (changesStoredPrice &&
      !request.actor.claims.has(Permission.distributionPriceAmend)) {
    return const DistributionRejected(CallableError.distributionPricingDenied);
  }
  if (clearsStoredPrice &&
      !request.actor.claims.has(Permission.distributionPriceClear)) {
    return const DistributionRejected(CallableError.distributionPricingDenied);
  }
  return null;
}

// ═════════════════════════════════════════════════════════════════════════
// نوعٌ واحد: حركته الخارجة ورصيده
// ═════════════════════════════════════════════════════════════════════════

/// ★★★ **جوهر الزيادة مخزنياً:** يبني حركة **الخروج** ويُعيد بناء الرصيد.
///
/// ⚠️⚠️ **والرصيد يُجمَع ⛔ لا يُراكَم على قيمةٍ سابقة** —
/// `coding-standards.md` §2.7: ⟵ ★ **فإعادة إرسال الطلب نفسه تُنتج الرقم
/// نفسه.**
///
/// ⛔⛔★★ **والخصم المخزني فوري سُعِّر السطر أم لا** (`FR-M10-05`) — ⟵ **ولا
/// شرط سعرٍ في هذه الدالة إطلاقاً**: ★ **الخلط بين الخصم والمديونية يُنتج
/// مخزوناً وهمياً** (`distribution-design.md` §7).
Outcome<List<InventoryWrite>> _planItem({
  required DistributionRequest request,
  required String itemKey,
  required StockQuantity? desired,
  required String? sackId,
  required bool isCreate,
  required String? reason,
  bool cancelOwn = false,
}) {
  final String movementId = stockMovementId(
    documentNumber: request.documentNumber,
    itemKey: itemKey,
  );
  final List<LedgerRead> reads = request.ledger[itemKey] ?? const <LedgerRead>[];
  final ItemRead? item = request.items[itemKey];
  final ItemUnit unit = item?.unit ?? desired?.unit ?? ItemUnit.piece;

  // ★ **حركات غيري** — ⟵ **فالتعديل يستبدل حركتي لا يُراكم عليها.**
  final List<StockMovement> others = <StockMovement>[
    for (final LedgerRead read in reads)
      if (read.movementId != movementId) read.movement,
  ];

  final bool isCancelled = cancelOwn || desired == null;
  final StockQuantity quantity =
      desired ?? _existingQuantity(reads, movementId, unit);

  final List<StockMovement> projected = <StockMovement>[
    ...others,
    StockMovement(
      itemKey: itemKey,
      // ⛔★★ **خروجٌ دائماً** — ★ **والتوزيع لا يُدخِل شيئاً للمخزن.**
      direction: MovementDirection.outgoing,
      quantity: quantity,
      isCancelled: isCancelled,
    ),
  ];

  final Outcome<ItemDailyFlow> flow =
      computeItemDailyFlow(movements: projected, unit: unit);
  if (flow case Failure<ItemDailyFlow>(:final AppError error)) {
    return Failure<List<InventoryWrite>>(error);
  }
  final ItemDailyFlow computed = (flow as Success<ItemDailyFlow>).value;

  // ⑥ ★★ **منع الرصيد السالب** — `FR-M8-01` · `GR-11` · `E-01`.
  final Outcome<void> allowed =
      validateNonNegativeBalance(computed.balance);
  if (allowed case Failure<void>(:final AppError error)) {
    return Failure<List<InventoryWrite>>(error);
  }

  return Success<List<InventoryWrite>>(<InventoryWrite>[
    _movementWrite(
      request: request,
      movementId: movementId,
      itemKey: itemKey,
      itemName: item?.name ?? itemKey,
      unit: unit,
      quantity: quantity,
      balanceAfter: computed.balance,
      sackId: sackId,
      isCancelled: isCancelled,
      isCreate: isCreate,
      reason: reason,
    ),
    _balanceWrite(
      request: request,
      itemKey: itemKey,
      itemName: item?.name ?? itemKey,
      unit: unit,
      flow: computed,
    ),
  ]);
}

StockQuantity _existingQuantity(
  List<LedgerRead> reads,
  String movementId,
  ItemUnit unit,
) {
  for (final LedgerRead read in reads) {
    if (read.movementId == movementId) return read.movement.quantity;
  }
  return StockQuantity.zeroOf(unit);
}

InventoryWrite _movementWrite({
  required DistributionRequest request,
  required String movementId,
  required String itemKey,
  required String itemName,
  required ItemUnit unit,
  required StockQuantity quantity,
  required StockQuantity balanceAfter,
  required String? sackId,
  required bool isCancelled,
  required bool isCreate,
  required String? reason,
}) {
  final Map<String, Object?> fields = <String, Object?>{
    'sourceId': request.sourceId,
    'stockDate': request.stockDate.asUtcMidnight(),
    'itemKey': itemKey,
    'itemName': itemName,
    'unit': unit.name,
    'direction': MovementDirection.outgoing.name,
    'quantity': _quantityValue(quantity),
    // ★ **الرصيد التراكمي بعد الحركة** — `FR-M8-06`.
    'balanceAfter': _quantityValue(balanceAfter),
    // ⚠️⚠️ **ويُمرَّر صراحةً ⛔ لا يُحفَر في دالة الكتابة** — ★ **درسُ
    //    `sourceDocType` المحفور** (2026-08-26): **ثابتٌ لأن كاتبه اليوم
    //    واحد يُوسَم خطأً حين يصير له كاتبٌ ثانٍ.**
    'sourceDocType': SourceDocumentType.distribution.name,
    'sourceDocId': request.compositeId,
    'sourceDocNumber': request.documentNumber,
    'movementTag': MovementTag.normal.name,
    'isCancelled': isCancelled,
    // ★★ **و`sackId` متى كان النوع من جونية** — `FR-M10-14` · `A-13`:
    //    ⟵ **وهو ما يُطلق إعادة احتساب سعرها**، ⛔ **وغيابُه يُسقِطها بصمت.**
    'sackId': ?sackId,
    if (!isCreate) 'amendedBy': request.actor.userId,
    if (!isCreate) 'amendReason': reason,
  };
  return InventoryWrite(
    collectionId: inventoryLedgerCollection,
    documentId: movementId,
    fields: fields,
    updateMask: fields.keys.toList(),
    serverTimestampFields:
        isCreate ? const <String>['entryDate'] : const <String>['lastAmendedAt'],
  );
}

InventoryWrite _balanceWrite({
  required DistributionRequest request,
  required String itemKey,
  required String itemName,
  required ItemUnit unit,
  required ItemDailyFlow flow,
}) {
  final Map<String, Object?> fields = <String, Object?>{
    'sourceId': request.sourceId,
    'itemKey': itemKey,
    'itemName': itemName,
    'stockDate': request.stockDate.asUtcMidnight(),
    'unit': unit.name,
    'incoming': _quantityValue(flow.incoming),
    'outgoing': _quantityValue(flow.outgoing),
    'balance': _quantityValue(flow.balance),
  };
  return InventoryWrite(
    collectionId: itemDailyBalancesCollection,
    documentId: itemDailyBalanceId(
      sourceId: request.sourceId,
      itemKey: itemKey,
      stockDate: request.stockDate,
    ),
    fields: fields,
    updateMask: fields.keys.toList(),
    serverTimestampFields: const <String>['updatedAt'],
  );
}

/// ★ قيمة الكمية كما تُكتب — **صحيحٌ للحبّة، وعشريٌّ مُصرَّحٌ به للوزن**.
///
/// ★★ **والوزن يمرّ بـ[DecimalValue] وحدها** (`ADR-0015` القاعدة 9:
/// «**الأوزان ليست مبالغ**») — ⛔ **و`double` المجرَّد يبقى مرفوضاً في
/// المُرمِّز**، ★ **فالتصريح شرطُ المرور لا صيغةٌ اختيارية.**
Object _quantityValue(StockQuantity quantity) => switch (quantity) {
      PieceQuantity(:final PieceCount count) => count.pieces,
      WeightQuantity(:final WeightKg weight) => DecimalValue(weight.kilograms),
    };

// ═════════════════════════════════════════════════════════════════════════
// دفتر المقوت ورصيده — `design-overview.md` §2.4
// ═════════════════════════════════════════════════════════════════════════

/// ★★★ **كتابات تطبيق الفائض** — `FR-M12-11` · `AT-31`.
///
/// ```text
/// لكل سجلِّ فائضٍ طُبِّق منه:
///   ① حركةٌ دائنة في دفتر المقوت ببيانٍ آلي يذكر تاريخ الدفع
///   ② خصمُ المبلغ من «المتاح» في سجل الفائض
/// ثم للضمار كلِّه:
///   ③ التسوية في `pricing/current` والحالة في الأب (`IQ-027`)
/// ```
///
/// ⛔⛔★★★ **والبيان الآلي ليس نقضاً لـ[`ADR-0020`]** — ★ **القاعدة الباقية
/// تخصّ «**سبب**» يكتبه إنسان** (`amendReason`)، ⟵ **وهذا `memo` نصّ عليه
/// `FR-M12-11` صراحةً أن **النظام** يكتبه: ⛔ **وحذفُه كان يُسقِط متطلباً
/// منصوصاً**، ★ **وإبقاؤه لا يُعبِّئ سبباً نيابةً عن أحد.**
List<InventoryWrite> _surplusApplicationWrites(
  DistributionRequest request,
  List<SurplusApplication> applications,
) {
  if (applications.isEmpty) return const <InventoryWrite>[];

  final List<InventoryWrite> writes = <InventoryWrite>[];
  Money applied = Money.zero;
  final Map<String, SurplusPoolRead> poolsById = <String, SurplusPoolRead>{
    for (final SurplusPoolRead pool in request.surplusPools)
      pool.surplusId: pool,
  };

  for (final SurplusApplication application in applications) {
    applied = applied + application.amount;

    final Map<String, Object?> entryFields = <String, Object?>{
      'dealerId': request.dealerId,
      'dealerName': _nameOf(request.storedDealer) ?? request.dealerId,
      'sourceId': request.sourceId,
      'debtLotId': request.compositeId,
      'direction': DealerLedgerDirection.credit.name,
      'amount': application.amount.riyals,
      'entryType': DealerLedgerEntryType.surplusApplication.name,
      'sourceDocType': distributionEntityType,
      'sourceDocId': request.compositeId,
      'sourceDocNumber': request.documentNumber,
      // ★★ **البيان الآلي بنصّه** — `FR-M12-11`.
      'memo': application.memo,
      'isCancelled': false,
    };
    writes.add(
      InventoryWrite(
        collectionId: dealerLedgerCollection,
        documentId: surplusLedgerEntryId(
          debtLotId: request.compositeId,
          surplusId: application.surplusId,
        ),
        fields: entryFields,
        updateMask: entryFields.keys.toList(),
        serverTimestampFields: const <String>['entryDate'],
      ),
    );

    // ② ★ **خصمُ المُطبَّق من المتاح** — ⛔ **ولا يهبط تحت الصفر**
    //    ([availableSurplus] — **المعادلة في طبقة النطاق وحدها**).
    final SurplusPoolRead? pool = poolsById[application.surplusId];
    final Map<String, Object?> surplusFields = <String, Object?>{
      'availableAmount': availableSurplus(
        paid: pool?.available ?? application.amount,
        applied: application.amount,
      ).riyals,
    };
    writes.add(
      InventoryWrite(
        collectionId: dealerSurplusCollection,
        documentId: application.surplusId,
        fields: surplusFields,
        // ⛔★★ **قناعٌ ضيّق** — ⟵ **فلا يُمحى نطاقُ السجل ولا تاريخُ دفعه.**
        updateMask: surplusFields.keys.toList(),
        serverTimestampFields: const <String>['updatedAt'],
      ),
    );
  }

  return writes;
}

/// ★ مجموعُ ما طُبِّق من الفائض الآن — ⛔ **بلا ما طُبِّق سابقاً.**
Money _appliedNow(List<SurplusApplication> applications) =>
    applications.fold<Money>(
      Money.zero,
      (Money total, SurplusApplication a) => total + a.amount,
    );

/// ★★★ **تسويةُ الضمار — المبالغ في `pricing/current` والحالة في الأب**
/// ([`ADR-0011`] · `IQ-027`).
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **وتُكتَب في كل إنشاءٍ وتعديل — لا عند تطبيق الفائض وحده**
/// (`DEBT-85` — **مقيسٌ على التجريبية 2026-09-02**):
///
/// ★ **العطل الذي كشفه اختبار المرحلة:** **كانت هذه الكتابةُ داخل
/// [_surplusApplicationWrites]** ⟵ **وهي تعود فارغةً متى لا فائض**:
/// ⟹ ⛔⛔ **فضمارٌ يُنشأ عادةً لا يحمل `settlementStatus` إطلاقاً.**
///
/// ⛔⛔★★★ **وأثرُه أن الضمار الجديد لا يُقبَض منه ولا يُخصَم عليه أبداً:**
/// ★ **استعلامُ الضمارات المفتوحة يُقيّد `settlementStatus whereIn
/// [open, partiallyOpen]`** (`firestore_receipt_directory.dart`)،
/// ⟵ **والحقلُ الغائب لا يطابق شرطاً** ⟹ **فالضمار غيرُ مرئيٍّ في شاشتَي
/// المقبوضات والخصومات.**
///
/// ★★ **مقيسٌ رقماً برقم:** `dealer_balances/MQT-0001_SRC-001` **= 62,600
/// ريال**، ⛔ **بينما شاشةُ المقبوضات تقول «إجمالي الديون على المقوت: 350
/// ريال (1 ضمار مفتوح)»** — ★ **والوحيدُ الظاهر هو الضمارُ الذي وسَمَه خصمٌ
/// سابق**: ⟵ **وخمسةٌ من ستةٍ بلا حقلٍ إطلاقاً** (`runQuery` على
/// `distributions`). ⛔⛔ **وهذا يُخالف `FR-M12-03` نصّاً** («**إجمالي الديون
/// فور اختيار المقوت**»).
/// ═══════════════════════════════════════════════════════════════════════
///
/// ⛔⛔★★★ **والمُطبَّقُ سابقاً يُصان ولا يُصفَّر:** ★ **`settledAmount`
/// و`discountedAmount` من [DistributionRequest.storedSettlement]** —
/// ⟵ **وتعديلُ الضمار يُعيد بناء `remaining` على القيمة الجديدة**
/// ⛔ **ولا يمحو قبضاً وصل ولا خصماً مُنح.**
List<InventoryWrite> _settlementWrites({
  required DistributionRequest request,
  required List<SurplusApplication> applications,
}) {
  final DebtSettlement? stored = request.storedSettlement;
  final Money debtValue = _debtValueOf(request);
  // ⛔⛔★★ **وضمارٌ بقيمة صفرٍ بلا سابقةٍ ولا فائضٍ لا يُكتب له سجل** —
  //    [`ADR-0008`] القاعدة 5 («**لا يُنشأ سجل بصفر بلا داعٍ**»)
  //    و[`ADR-0011`]: ⟵ **ومستندٌ كلُّ سطوره غير مسعَّرة ينمو عند التسعير**
  //    (`E-05` · `FR-M10-08`)، ★ **فيُكتب سجلُّه حينها لا اليوم.**
  if (debtValue.isZero && stored == null && applications.isEmpty) {
    return const <InventoryWrite>[];
  }
  final DebtSettlement settlement = computeDebtSettlement(
    // ★ **القيمةُ من المستند المُتحقَّق منه** — [_debtValueOf].
    debtValue: debtValue,
    settledAmount:
        (stored?.settledAmount ?? Money.zero) + _appliedNow(applications),
    discountedAmount: stored?.discountedAmount ?? Money.zero,
  );
  final Map<String, Object?> pricingFields = <String, Object?>{
    'settledAmount': settlement.settledAmount.riyals,
    'discountedAmount': settlement.discountedAmount.riyals,
    'remaining': settlement.remaining.riyals,
  };
  final Map<String, Object?> parentFields = <String, Object?>{
    'settlementStatus': settlement.status.name,
  };
  return <InventoryWrite>[
    InventoryWrite(
      collectionId: '$distributionsCollection/${request.compositeId}'
          '/$distributionPricingSubcollection',
      documentId: distributionPricingDocumentId,
      fields: pricingFields,
      updateMask: pricingFields.keys.toList(),
    ),
    InventoryWrite(
      collectionId: distributionsCollection,
      documentId: request.compositeId,
      fields: parentFields,
      updateMask: parentFields.keys.toList(),
    ),
  ];
}

/// ★ قيمة الضمار المخطَّطة — **من المستند المُتحقَّق منه**.
Money _debtValueOf(DistributionRequest request) =>
    request.distribution?.debtValue ?? Money.zero;

/// ★★★ **القيد المدين وأثره على الرصيد** — ⛔ **والرصيد يُجمَع من الدفتر**.
///
/// ⚠️⚠️ **والقيد يُكتب ولو كانت القيمة صفراً** — ⟵ **فمستندٌ كل سطوره غير
/// مسعَّرة يُنشئ ضماراً بقيمة صفر ينمو عند التسعير** (`E-05` · `FR-M10-08`)،
/// ★ **ومعرّفُه مشتقٌّ فيُكتب فوقه لا بجانبه** ([debtLedgerEntryId]).
/// ⛔ **وقيدٌ لا يُكتب اليوم كان سيلزمه إنشاءٌ لاحق بمسارٍ ثانٍ** — **ونسختان
/// من الكتابة تفترقان.**
List<InventoryWrite> _dealerWrites({
  required DistributionRequest request,
  required Money debtValue,
  required bool isCancelled,
  required bool isCreate,
  required String? reason,
  List<SurplusApplication> applications = const <SurplusApplication>[],
}) {
  final String entryId = debtLedgerEntryId(
    documentNumber: request.documentNumber,
  );
  // ★ **قيود غيري** — ⟵ **فالتعديل يستبدل قيدي لا يُراكم عليه.**
  final List<DealerLedgerEntry> others = <DealerLedgerEntry>[
    for (final DealerLedgerRead read in request.dealerLedger)
      if (read.entryId != entryId) read.entry,
  ];
  final DealerLedgerEntry mine = DealerLedgerEntry(
    direction: DealerLedgerDirection.debit,
    amount: debtValue,
    isCancelled: isCancelled,
  );
  // ★★ **وقيود الفائض المُطبَّق تدخل الرصيد في المعاملة نفسها** — ⟵ **وإلّا
  //    لَقرأ المستخدم ديناً كاملاً على مقوتٍ سُدِّد نصفُه في اللحظة ذاتها.**
  final DealerAccountBalance projected = computeDealerBalance(
    <DealerLedgerEntry>[
      ...others,
      mine,
      for (final SurplusApplication application in applications)
        DealerLedgerEntry(
          direction: DealerLedgerDirection.credit,
          amount: application.amount,
          isCancelled: false,
        ),
    ],
  );

  final Map<String, Object?> entryFields = <String, Object?>{
    'dealerId': request.dealerId,
    'dealerName': _nameOf(request.storedDealer) ?? request.dealerId,
    'sourceId': request.sourceId,
    // ★ **الضمار المتأثر هو المستند نفسه** (`distribution-design.md` §2).
    'debtLotId': request.compositeId,
    'direction': DealerLedgerDirection.debit.name,
    'amount': debtValue.riyals,
    'entryType': DealerLedgerEntryType.debt.name,
    'sourceDocType': SourceDocumentType.distribution.name,
    'sourceDocId': request.compositeId,
    'sourceDocNumber': request.documentNumber,
    'balanceAfter': projected.balance.riyals,
    'isCancelled': isCancelled,
    if (!isCreate) 'amendedBy': request.actor.userId,
    if (!isCreate) 'amendReason': reason,
  };

  final Map<String, Object?> balanceFields = <String, Object?>{
    'dealerId': request.dealerId,
    'sourceId': request.sourceId,
    'totalDebit': projected.totalDebit.riyals,
    'totalCredit': projected.totalCredit.riyals,
    // ⚠️⚠️ **وهذا الحقل بعينه يقرؤه حارس تعطيل المقوت** (`FR-M4-09` ·
    //    `IQ-020`) **داخل معاملته** — ⟵ **فاسمُه عقدٌ بين وحدتين**،
    //    ⛔ **وتغييرُه هنا يُسقِط الحارس هناك بصمت.**
    'balance': projected.balance.riyals,
  };

  return <InventoryWrite>[
    InventoryWrite(
      collectionId: dealerLedgerCollection,
      documentId: entryId,
      fields: entryFields,
      updateMask: entryFields.keys.toList(),
      serverTimestampFields: isCreate
          ? const <String>['entryDate']
          : const <String>['lastAmendedAt'],
    ),
    InventoryWrite(
      collectionId: dealerBalancesCollection,
      documentId: dealerBalanceId(
        dealerId: request.dealerId,
        sourceId: request.sourceId,
      ),
      fields: balanceFields,
      // ⛔★★ **قناعٌ ضيّق لا يذكر `openDebtCount` ولا `oldestOpenDebtDate`** —
      //    ★ **ولا يكتبهما `WU-006` أصلاً**: **حسابُهما يحتاج حالةَ تسويةٍ
      //    لا كاتب لها قبل المقبوضات** (`WU-007`) وأعمار الديون (`WU-023`)،
      //    ⟵ **وكتابتُهما اليوم رقمٌ يبدو محسوباً وليس كذلك** (`ADR-0008`
      //    القاعدة 5: ⛔ **لا يُنشأ سجل بقيمة بلا داعٍ**).
      updateMask: balanceFields.keys.toList(),
      serverTimestampFields: const <String>['updatedAt'],
    ),
  ];
}

// ═════════════════════════════════════════════════════════════════════════
// المستند وحقوله
// ═════════════════════════════════════════════════════════════════════════

Map<String, Object?> _documentFields(
  DistributionRequest request,
  ValidatedDistribution distribution,
) =>
    <String, Object?>{
      'documentNumber': request.documentNumber,
      'sourceId': distribution.sourceId,
      if (_nameOf(request.storedSource) case final String sourceName)
        'sourceName': sourceName,
      'dealerId': distribution.dealerId,
      // ★ **الأسماء المكرَّرة عمداً** — `naming-conventions.md` §4:
      //   **المستند يشهد بما كان وقت إنشائه.**
      'dealerName': _nameOf(request.storedDealer) ?? distribution.dealerId,
      // ③ ★★ **تاريخ المخزون من الخادم** — `FR-M10-03`.
      'stockDate': request.stockDate.asUtcMidnight(),
      if (distribution.notes case final String notes) 'notes': notes,
      'lines': <Object?>[
        for (final ValidatedDistributionLine line in distribution.lines)
          // ⛔⛔★★ **بلا أي سعر** — `ADR-0011` · `data-dictionary.md`:
          //    ⟵ **`unitPrice` و`lineTotal` في `pricing/current` وحدها.**
          <String, Object?>{
            'itemId': line.itemId,
            'itemName': line.itemName,
            'unit': line.quantity.unit.name,
            'quantity': _quantityValue(line.quantity),
            if (line.sackId case final String sackId) 'sackId': sackId,
            if (line.note case final String note) 'note': note,
          },
      ],
      // ★ **عددٌ لا مبلغ** — ⟵ **فيعيش في الأب** (`firestore.rules` §16).
      'unpricedLineCount': distribution.unpricedLineCount,
      // ⛔ **إجماليان منفصلان دائماً** — `GR-19` · `FR-M10-15`.
      'totalPieces': distribution.totalPieces.pieces,
      'totalWeight': DecimalValue(distribution.totalWeight.kilograms),
      documentStatusField: distribution.pricingStatus.name,
      // ⛔⛔★★ **ولا حقل تسويةٍ واحد هنا** — `distribution-design.md` §2:
      //    «**حقول التسوية لا يكتبها التطبيق — تكتبها السحابة بعد كل قبض
      //    أو خصم**»، ⟵ **وكاتبُها المقبوضات (`WU-007`) والخصومات
      //    (`WU-013`)**؛ ★ **وغيابُها اليوم يعني «لم يُمَسّ»** (`ADR-0008`
      //    القاعدة 5) ⛔ **لا صفراً مكتوباً يبدو محسوباً.**
    };

InventoryWrite _documentWrite(
  DistributionRequest request,
  DistributionOperation operation,
  Map<String, Object?> after,
  String? reason,
) {
  final Map<String, Object?> fields = <String, Object?>{
    ...after,
    if (operation.isCreate) 'createdBy': request.actor.userId,
    if (!operation.isCreate) ...<String, Object?>{
      'amendedBy': request.actor.userId,
      'amendReason': reason,
      'amendCount': _amendCount(request.storedDocument) + 1,
    },
  };
  return InventoryWrite(
    collectionId: distributionsCollection,
    // ⑦ ★★★ **المعرّف المركّب هو معرّف المستند** — `GR-18` بنيوياً.
    documentId: request.compositeId,
    fields: fields,
    updateMask: fields.keys.toList(),
    serverTimestampFields: operation.isCreate
        ? const <String>['createdAt', 'entryDate']
        : const <String>['lastAmendedAt'],
  );
}

/// 🔒 ⑨ **مستند الأسعار** — `distributions/{key}/pricing/current` (`ADR-0011`).
///
/// ⚠️⚠️ **ويُكتب متى حمل المستند سعراً أو كان له مستند أسعار قائم** —
/// ★ **والثانية محاذاةٌ لا تسعير**: `unitPrices[]` و`lineTotals[]`
/// **موازيتان لترتيب `lines[]`** (`data-dictionary.md`)، ⟵ **فتعديلٌ يُغيّر
/// السطور ويترك المصفوفتين كما هما يُنتج سعراً منسوباً لنوعٍ آخر** —
/// ⛔ **وهو أسوأ من غيابه.**
///
/// ★ **ومستندٌ بلا سعرٍ ولا سابقةٍ لا يُكتب أصلاً** — ⟵ **فلا يُنشأ سجل
/// بلا داعٍ** (`ADR-0008` القاعدة 5)، ⛔ **ولا تُطلَب صلاحية سعرٍ لمن لم
/// يُسعِّر.**
InventoryWrite? _pricingWrite(
  DistributionRequest request,
  ValidatedDistribution distribution,
  String? reason,
) {
  if (!distribution.carriesAnyPrice && !request.hasStoredPricing) return null;

  final Map<String, Object?> fields = <String, Object?>{
    // ★ **نسخة المصدر** — **لفحص القراءة بالنطاق بلا قراءة الأب**
    //   (`data-dictionary.md` §`pricing/current`).
    'sourceId': distribution.sourceId,
    'unitPrices': <Object?>[
      for (final ValidatedDistributionLine line in distribution.lines)
        line.unitPrice?.riyals,
    ],
    'lineTotals': <Object?>[
      for (final ValidatedDistributionLine line in distribution.lines)
        line.lineTotal?.riyals,
    ],
    // ★★ **قيمة الضمار** — `Σ(قيم السطور المسعَّرة فقط)` من طبقة النطاق.
    'debtValue': distribution.debtValue.riyals,
  };
  return InventoryWrite(
    collectionId:
        '$distributionsCollection/${request.compositeId}/$distributionPricingSubcollection',
    documentId: distributionPricingDocumentId,
    fields: <String, Object?>{
      ...fields,
      'amendedBy': request.actor.userId,
      'amendReason': ?reason,
    },
    updateMask: <String>[...fields.keys, 'amendedBy', 'amendReason'],
    serverTimestampFields: const <String>['lastAmendedAt'],
  );
}

// ═════════════════════════════════════════════════════════════════════════
// بوابات مشتركة
// ═════════════════════════════════════════════════════════════════════════

/// ★ يفحص أن المستند موجود عند التعديل وغائب عند الإنشاء.
DistributionRejected? _existenceGate(
  DistributionRequest request,
  DistributionOperation operation,
) {
  final Map<String, Object?>? stored = request.storedDocument;
  if (operation.isCreate) {
    // ⑦ ⛔⛔★★★ **`GR-18` — ولا مستند ثانٍ ولا محوٌ لمستندٍ حيّ.**
    //    ★ **والرمز `ERR_DIST_001` يقول للواجهة «افتح الموجود للتعديل»**
    //    (`FR-M10-01` · `E-04`) ⛔ **لا «خطأ في الطلب».**
    return stored == null
        ? null
        : const DistributionRejected(CallableError.distributionExists);
  }
  if (stored == null) {
    return const DistributionRejected(CallableError.invalidArgument);
  }
  // ★★★ **والمخزَّن هو الحَكَم لا المُرسَل** — ⟵ **وإلا أمكن فحصُ النطاق
  //   على مصدرٍ ثم العملُ على مستند مصدرٍ آخر**، ⛔ **وهو تصعيدُ امتيازٍ
  //   صامت** (`GR-23`).
  if (stored['sourceId'] != request.sourceId) {
    return const DistributionRejected(CallableError.sourceOutOfScope);
  }
  if (stored['dealerId'] != request.dealerId) {
    return const DistributionRejected(CallableError.invalidArgument);
  }
  if (stored['stockDate'] != request.stockDate.asUtcMidnight()) {
    return const DistributionRejected(CallableError.invalidArgument);
  }
  // ★★ **والملغى لا يُعدَّل ولا يُلغى ثانيةً** — `ERR_AMEND_006`.
  final Outcome<void> live = validateDistributionNotCancelled(
    stored[documentStatusField] == DistributionStatus.cancelled.name
        ? DistributionStatus.cancelled
        : DistributionStatus.approved,
  );
  return live is Failure<void>
      ? const DistributionRejected(CallableError.documentCancelled)
      : null;
}

/// ★ يفحص طرفَي العملية — **المصدر والمقوت: موجودان ونشطان**.
///
/// ⚠️ **والإلغاء مسموح على مصدرٍ أو مقوتٍ عُطِّل** — ⟵ **فالتعطيل لا يحبس
/// مستنداً خاطئاً داخل النظام**؛ ⛔ **والمنع على التوزيع الجديد وتعديله**
/// (`FR-M10-12` · `schema/dealers.md` القاعدة 4: «**المقوت المعطَّل لا يظهر
/// في توزيع جديد، ويظهر في المقبوضات والخصومات**»).
DistributionRejected? _partiesGate(
  DistributionRequest request,
  DistributionOperation operation,
) {
  final Map<String, Object?>? source = request.storedSource;
  final Map<String, Object?>? dealer = request.storedDealer;
  // ⛔ **سجلٌّ لم يُقرأ ⟵ رفض** — الرفض الافتراضي: لا يُبنى قرارٌ بالتخمين.
  if (source == null || dealer == null) {
    return const DistributionRejected(CallableError.internal);
  }
  if (operation.isCancel) return null;
  if (source['isActive'] == false) {
    return const DistributionRejected(CallableError.sourceInactive);
  }
  if (dealer['isActive'] == false) {
    return const DistributionRejected(CallableError.dealerInactive);
  }
  return null;
}

/// ★ يُترجم خطأ النطاق إلى رمز الكتالوج **بحسب الفعل المطلوب**.
CallableError _mapStockError(
  AppError error,
  DistributionOperation operation,
) =>
    switch (error) {
      InsufficientStockError()
          when operation == DistributionOperation.amendDistribution =>
        CallableError.amendReducesBelowIssued,
      InsufficientStockError() => CallableError.insufficientStock,
      ValidationError(ruleCode: 'GR-19') => CallableError.itemUnitLocked,
      _ => CallableError.invalidArgument,
    };

// ═════════════════════════════════════════════════════════════════════════
// قيد التدقيق
// ═════════════════════════════════════════════════════════════════════════

Map<String, Object?> _changedBefore(
  Map<String, Object?>? stored,
  Map<String, Object?> after,
) =>
    <String, Object?>{
      for (final String key in after.keys)
        if (!_sameValue(stored?[key], after[key])) key: stored?[key],
    };

Map<String, Object?> _changedAfter(
  Map<String, Object?>? stored,
  Map<String, Object?> after,
) =>
    <String, Object?>{
      for (final MapEntry<String, Object?> entry in after.entries)
        if (!_sameValue(stored?[entry.key], entry.value))
          entry.key: entry.value,
    };

/// ★ مقارنة قيمتين — **والقوائم والخرائط تُقارَن عنصراً بعنصر**.
bool _sameValue(Object? a, Object? b) {
  if (a is DecimalValue && b is DecimalValue) return a.value == b.value;
  // ★ **والمخزَّن يعود `double` لا [DecimalValue]** — ⟵ **فالمقارنة على
  //   القيمة**، ⛔ **وإلا قُرئ كلُّ وزنٍ «تغييراً» في كل تعديل.**
  if (a is num && b is DecimalValue) return a.toDouble() == b.value;
  if (a is DecimalValue && b is num) return a.value == b.toDouble();
  if (a is List<Object?> && b is List<Object?>) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (!_sameValue(a[i], b[i])) return false;
    }
    return true;
  }
  if (a is Map<Object?, Object?> && b is Map<Object?, Object?>) {
    if (a.length != b.length) return false;
    for (final Object? key in a.keys) {
      if (!b.containsKey(key) || !_sameValue(a[key], b[key])) return false;
    }
    return true;
  }
  if (a is num && b is num) return a == b;
  return a == b;
}

AuditEntry _entry({
  required DistributionRequest request,
  required AuditAction action,
  required String? reason,
  required Map<String, Object?> valuesBefore,
  required Map<String, Object?> valuesAfter,
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
      target: AuditTarget(
        entityType: distributionEntityType,
        // ★★ **والمعرّف المركّب لا رقم المستند** — ⟵ **فالسجل السياقي 🕘
        //   يستعلم بما يُفتَح به المستند فعلاً** (`FR-M18-10`).
        entityId: request.compositeId,
        sourceId: request.sourceId,
        // ★★★ **والتاريخان معاً في القيد** — `AT-52` · `FR-SYS-18`:
        //    ⟵ **`occurredAt` تاريخُ الإدخال (وقتُ المنصّة)**، **وهذا
        //    تاريخُ المخزون** — ⛔ **ويفترقان في التصريف المتأخر وحده**،
        //    ★ **وهو بالضبط ما يجعل تسجيلَهما معاً شرطاً لا زينة.**
        stockDate: request.stockDate,
      ),
      // ⛔⛔★★★ **وتُمرَّر كما هي** — ★ **والوزن يبقى [DecimalValue] مغلَّفاً:**
      // ⚠️⚠️ **عطلٌ رُصد حيّاً على المحاكي (2026-08-27):** فكُّ الغلاف إلى
      // `double` مجرَّد **يُفشِل الالتزام كلَّه** لأن المُرمِّز يرفض الفاصلة
      // العائمة المجرَّدة رفضاً مقصوداً (`ADR-0015` القاعدة 1) — ⟵ **وقيدُ
      // التدقيق يمرّ بالمُرمِّز نفسه الذي تمرّ به المستندات.**
      // ★★ **وهو درسُ `DEBT-37` نفسه:** ⛔ **اختبارُ الطبقة لا يُغني عن
      // اختبار ما يعبر بينها** — ★ **فالخطة كانت صحيحة والترميز يسقط.**
      valuesBefore: valuesBefore,
      valuesAfter: valuesAfter,
      deviceInfo: request.deviceInfo,
    );

int _amendCount(Map<String, Object?>? stored) {
  final Object? raw = stored?['amendCount'];
  if (raw is int) return raw;
  if (raw is double && raw == raw.roundToDouble()) return raw.toInt();
  return 0;
}

/// ★ اسم السجل المقروء أو `null` — ⛔ **والفارغ غيابٌ لا نصٌّ فارغ**.
String? _nameOf(Map<String, Object?>? stored) {
  final Object? name = stored?['name'];
  return (name is String && name.trim().isNotEmpty) ? name.trim() : null;
}

String? _trimmed(String? value) {
  final String? text = value?.trim();
  return (text == null || text.isEmpty) ? null : text;
}

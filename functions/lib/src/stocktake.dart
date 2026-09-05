/// الجرد والتسويات — **التخطيط الخالص** لعمليات `WU-022` (`M16` · `FR-M16`).
///
/// ★ **مفصول عن الشبكة بنفس منطق `disposal.dart`:** `ADR-0013` القاعدة 3
/// تجعل **فحص التفويض في الكود** هو الحارس الوحيد لهذا المسار، فالدالة تعمل
/// بامتياز إداري يتجاوز قواعد الحماية. ★ **وحارسٌ لا يُختبَر بلا سحابة
/// حارسٌ غير مُختبَر** — فكل قرار هنا **دالة خالصة**.
///
/// ★ **وكل معادلة من طبقة النطاق لا من هنا** (`qtms_domain`) —
/// ⛔ **ولا تُعاد كتابتها** (`coding-standards.md` §2.2 · `ADR-0009`):
/// ★ **والفرقُ يُحسَب بـ[stocktakeDifference] واتجاهُه بـ[stocktakeAdjustment]**
/// ⛔ **ولا طرحَ يدويٌّ في هذا الملف.**
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔★★ **ستةُ قيودٍ بندُ قبولٍ مُلزِم لهذه الدالة:**
///
///   ① ⛔⛔★★★ **ولا حقلَ ماليٍّ واحدٌ يُكتب** — `BR-M16-03` · `AT-66`:
///      ⟵ **لا `unitPrice` ولا `lineTotal` ولا `amount` ولا `grandTotal`**،
///      ★ **والضمانةُ بنيويةٌ: [ValidatedStocktakeCounts] لا يحمل مبلغاً
///      أصلاً** ⛔ **فلا مسارَ يُسرِّبه.**
///   ② ⛔⛔★★★ **ولا قيدَ واحدٌ في دفتر المقاوته ولا في دفتر الرعوي** —
///      `BR-M16-03`: ★ **«حركات التسوية … تُستثنى من … استحقاق الرعوي»**
///      ⟵ **والغيابُ هنا تنفيذُ المتطلب لا نقصٌ فيه.**
///   ③ ⛔⛔★★★ **ولا تدخل سعرَ الجونية** (`AT-66` · `design-overview.md` §2.2)
///      — ★ **بنيوياً:** ⟵ **`readSackMovementDocuments` لا تقرأ `stocktakes`
///      إطلاقاً**، ⛔ **فلا شرطَ استثناءٍ يُنسى في دالة جمع.**
///      ★★ **والحركةُ تُوسَم [MovementTag.adjustment] فوق ذلك** — ⟵ **حزامٌ
///      وحمّالة**، ★ **فأيُّ قارئٍ للدفتر لاحقاً يراها مستثناةً بالوسم.**
///   ④ ★★ **نطاق المصادر** — ⛔ **قيدٌ يعلو على كل صلاحية** (`GR-23`).
///   ⑤ ★★★ **وتاريخُ المخزون:** **اليوم ⟵ قبول** · **أقدم ⟵ يشترط
///      `stocktakePriorDay`** (`FR-M16-08`) · **أحدث ⟵ مرفوضٌ للجميع**.
///      ⛔ **والحُكمُ من [stocktakePriorDayRejection] وحدها** — ★ **ولا
///      يُستدعى `agedClearanceRejection`**: ⟵ **مفتاحُه غيرُ مفتاحِنا**
///      (راجع [StocktakeOperation.startStocktake]).
///   ⑥ ⛔⛔★★★ **ولا جردان مفتوحان على نفس المصدر ونفس اليوم** —
///      `FR-M16-06` · `BR-M16-05`: ★ **يُقاس باستعلامٍ داخل المعاملة**
///      ([StocktakeRequest.sameDayDocuments]) ⛔ **لا بحقلٍ مخزَّنٍ ولا كاش.**
/// ═══════════════════════════════════════════════════════════════════════
///
/// ★★★ **والمرحلتان هما جوهرُ هذه الوحدة** — `FR-M16-03` و`FR-M16-09`:
/// ⟵ **[StocktakeOperation.startStocktake] تُجمِّد الرصيد الدفتري ولا تمسّ
/// حركةً واحدة**، ★ **و[StocktakeOperation.approveStocktake] وحدها تكتب
/// التسويات** ⛔ **بمفتاحٍ آخر.**
library;

import 'package:qtms_domain/qtms_domain.dart';

import 'callable.dart';
import 'firestore_value.dart' show DecimalValue;
import 'identity_gateway.dart';
import 'inventory.dart';

/// عمليات الجرد — ★★★ **أربعٌ لا ثلاث** (راجع ترويسة الملف).
enum StocktakeOperation {
  /// `startStocktake` — ★★★ **يبدأ جرداً ويُجمِّد الرصيد الدفتري**
  /// (`FR-M16-03`) ⛔ **بلا حركةٍ دفترية واحدة.**
  startStocktake(Permission.stocktakeWrite),

  /// `approveStocktake` — ★★★ **يعتمد الجرد فيكتب التسويات** (`FR-M16-11`).
  approveStocktake(Permission.stocktakeApprove, isCounting: true),

  /// `amendStocktake` — يعدّل جرداً معتمداً **بسببٍ نصّي اختياري**
  /// ([`ADR-0020`]) ⟵ **ويُعيد بناء الرصيد من الدفتر** (`A-14`).
  amendStocktake(Permission.stocktakeAmend, isCounting: true, isAmend: true),

  /// `cancelStocktake` — ★ **يَسِم المستند وحركاته «ملغى»** ⛔ **وليس حذفاً**
  /// (`GR-06` · `GR-07` · `A-14`).
  cancelStocktake(Permission.stocktakeCancel, isCancel: true);

  const StocktakeOperation(
    this.requiredPermission, {
    this.isCounting = false,
    this.isAmend = false,
    this.isCancel = false,
  });

  /// ★★ **المفتاح المطلوب** — ⛔ **أربعةٌ مستقلة لا مفتاحٌ واحد**:
  /// `permissions-catalog.md` §2.4 و§2.9 — ⟵ **فمن يبدأ جرداً لا يعتمده،
  /// ومن يعتمده لا يُلغيه** (`FR-M16-09`).
  final Permission requiredPermission;

  /// هل تحمل أعداداً فعلية؟ — **الاعتماد والتعديل**.
  final bool isCounting;

  /// هل هي تعديلٌ لمستندٍ معتمد؟
  final bool isAmend;

  /// هل هي إلغاء؟
  final bool isCancel;

  /// ★ هل هي **بدءُ** جردٍ جديد؟ — ⟵ **وهي وحدها تُخصِّص رقماً وتُجمِّد.**
  bool get isStart => this == StocktakeOperation.startStocktake;
}

/// نتيجة التخطيط — إما خطة كتابة وإما رفض مصنَّف.
sealed class StocktakePlan {
  /// ينشئ النتيجة.
  const StocktakePlan();
}

/// رُفض الطلب قبل أي كتابة.
final class StocktakeRejected extends StocktakePlan {
  /// ينشئ رفضاً.
  const StocktakeRejected(this.error);

  /// رمز الرفض من كتالوج الأخطاء.
  final CallableError error;
}

/// قُبل الطلب — وهذه كتاباته وقيده.
final class StocktakeAccepted extends StocktakePlan {
  /// ينشئ خطة مقبولة.
  const StocktakeAccepted({
    required this.documentNumber,
    required this.writes,
    required this.entry,
    required this.status,
  });

  /// رقم المستند — `STK-…` ★ **وهو معرّفه في المجموعة**.
  final String documentNumber;

  /// المستندات المكتوبة — ⛔ **ولا تكون فارغة**.
  final List<InventoryWrite> writes;

  /// قيد التدقيق — **يُكتب في المعاملة نفسها** (`ADR-0013` القاعدة 1).
  final AuditEntry entry;

  /// ★ حالة المستند بعد هذه العملية.
  final StocktakeStatus status;

  /// ★★ هل كتبت هذه الخطةُ حركاتِ تسويةٍ فعلاً؟ — ⟵ **ومنه يعرف المُنفِّذ
  /// أن يُشغّل راصدَ المتبقي وبنودَ المركز المعلّق** ⛔ **ولا يُشغّلهما على
  /// مسوّدةٍ لا تمسّ رصيداً.**
  bool get touchesLedger => writes.any(
        (InventoryWrite write) =>
            write.collectionId == itemDailyBalancesCollection,
      );
}

/// طلبُ جردٍ مُتحقَّق من هوية مُنفِّذه.
final class StocktakeRequest {
  /// ينشئ الطلب.
  const StocktakeRequest({
    required this.actor,
    required this.requestId,
    required this.sourceId,
    required this.documentNumber,
    required this.stockDate,
    this.serverDay,
    this.start,
    this.counts,
    this.storedSource,
    this.storedDocument,
    this.items = const <String, ItemRead>{},
    this.ledger = const <String, List<LedgerRead>>{},
    this.sameDayDocuments = const <String, Map<String, Object?>>{},
    this.reason,
    this.deviceInfo,
  });

  /// المُستدعي **بحالته الآن من خدمة المصادقة** لا من الرمز الذي أرسله.
  final AccountRecord actor;

  /// معرّف الطلب — ★ **وهو معرّف قيد التدقيق** فتتحقق اللاتكرارية.
  final String requestId;

  /// المصدر المستهدف.
  final String sourceId;

  /// رقم المستند — **المخصَّص عند البدء والقائم في ما عداه**.
  final String documentNumber;

  /// ★★★ **تاريخ المخزون المجرود** — ⛔ **وهو التاريخ الوحيد في هذه العملية**:
  /// ⟵ **لا أثرَ ماليَّ لها يقع في يومٍ آخر** (`BR-M16-04`).
  final CalendarDay stockDate;

  /// ★★ **يومُ المنصّة** — ⛔ **من `readTime` داخل المعاملة** لا من الجهاز.
  ///
  /// ⚠️⚠️ **و`null` تعني «غيرُ معلوم فلا حُكم»** — ★ **بنفس
  /// `DisposalRequest.serverDay` حرفياً**: ⟵ **وهو حالُ الاعتماد والتعديل
  /// والإلغاء** حيث اليومُ محفورٌ في رقم المستند ولا يُعاد تقريرُه،
  /// ⛔ **ولو فُحص هناك لَاستحال اعتمادُ جردِ أمسٍ على من لا يملك
  /// `stocktakePriorDay`** — ★ **وهو ليس بدءَ جردٍ جديد بل إتمامُ قائم.**
  final CalendarDay? serverDay;

  /// ★ هل هذه العملية **جردُ يومٍ سابق**؟ — `FR-M16-08`.
  bool get isPriorDay =>
      serverDay != null && stockDate.compareTo(serverDay!) < 0;

  /// طلبُ البدء المُتحقَّق منه — `null` في ما عدا البدء.
  final ValidatedStocktakeStart? start;

  /// الأعداد المُتحقَّق منها — `null` في البدء والإلغاء.
  final ValidatedStocktakeCounts? counts;

  /// سجل المصدر كما قُرئ — ⛔ **و`null` رفضٌ لا تجاوز**.
  final Map<String, Object?>? storedSource;

  /// المستند القائم — `null` تعني **غيابه**.
  final Map<String, Object?>? storedDocument;

  /// سجلات الأنواع المطلوبة بمعرّفاتها.
  final Map<String, ItemRead> items;

  /// ★★ **حركات دفتر المخزون لكل نوع** — **مقروءةً داخل المعاملة**.
  final Map<String, List<LedgerRead>> ledger;

  /// ★★★ **مستندات الجرد على نفس (المصدر × اليوم)** بمعرّفاتها — `FR-M16-06`.
  ///
  /// ⛔⛔ **وتُقرأ باستعلامٍ داخل المعاملة** — ★ **فحكمُ «لا جردان معاً»
  /// يُقاس لحظةَ الالتزام**، ⛔ **لا من قائمةٍ حمّلها الجهاز قبل دقيقة.**
  final Map<String, Map<String, Object?>> sameDayDocuments;

  /// ★ سببُ الجرد أو التعديل أو الإلغاء — ⛔ **اختياريٌّ** ([`ADR-0020`]).
  final String? reason;

  /// وصف الجهاز للسجل — ⛔ بلا بيانات حساسة.
  final String? deviceInfo;
}

/// ★★★ **حارسُ تاريخ المخزون في الجرد** — `FR-M16-08` · `BR-M16-07`.
///
/// | [stockDate] مقابل [serverDay] | الحكم |
/// |---|---|
/// | **مساوٍ** | ✅ **قبولٌ بلا مفتاحٍ إضافي** — ★ **جردُ اليوم المعتاد** |
/// | **أقدم** | ★ **يشترط `stocktakePriorDay`** — ⛔ **وبدونه رفض** |
/// | **أحدث (مستقبلي)** | ⛔⛔ **مرفوضٌ مطلقاً للجميع** — ★ **ولا مفتاحَ يفتحه** |
///
/// ★★ **والمستقبليُّ يُرفَض قبل فحص المفتاح عمداً** — ⟵ **فلا يُوهِم رمزُ
/// «نقص صلاحية» أن مفتاحاً ما يفتح باباً مغلقاً على الجميع** (`GR-13`).
///
/// ⛔⛔★★★ **ودالةٌ مستقلةٌ عن `agedClearanceRejection` عمداً** — ★ **رغم
/// تطابق شكلهما**: ⟵ **المفتاحان مختلفان بقرارِ متطلبٍ صريح**
/// (`FR-M16-08` مقابل `FR-M8-11`)، ⛔ **ودالةٌ واحدةٌ بمعامل مفتاحٍ كانت
/// تُغري بتمرير المفتاح الخطأ من مُستدعٍ واحد** — ★ **وهو تصعيدُ امتيازٍ
/// صامتٌ لا يكشفه أيُّ نوع.**
CallableError? stocktakePriorDayRejection({
  required AccountRecord actor,
  required CalendarDay stockDate,
  required CalendarDay serverDay,
}) {
  final int comparison = stockDate.compareTo(serverDay);
  if (comparison == 0) return null;
  if (comparison > 0) return CallableError.invalidArgument;
  return actor.claims.has(Permission.stocktakePriorDay)
      ? null
      : CallableError.permissionMissing;
}

/// ★★ فحوص الحالة والصلاحية والنطاق — **تُستدعى قبل فتح المعاملة**.
///
/// ⚠️ **ولماذا مُصدَّرة:** ⟵ **فتحُ معاملةٍ لطلبٍ يرفضه نقصُ الصلاحية هدرٌ
/// وقفلٌ بلا داعٍ**. ★ **والفحص يُعاد كاملاً** في [planStocktake] ⛔ **فلا
/// مسار يتخطّاه.**
StocktakeRejected? stocktakeGate(
  StocktakeRequest request,
  StocktakeOperation operation,
) {
  // ① «التعطيل فوري ونافذ» — `authentication-policy.md` §2 القاعدة 3.
  if (request.actor.disabled) {
    return const StocktakeRejected(CallableError.accountDisabled);
  }
  // ② ★★ **المفتاح يتبع العملية** — ⛔ **أربعةٌ لا واحد** (`FR-M16-09`).
  if (!request.actor.claims.has(operation.requiredPermission)) {
    return const StocktakeRejected(CallableError.permissionMissing);
  }
  // ③ ★★ **النطاق — قيدٌ يعلو على الصلاحية** (`GR-23`) — ⛔ **والغياب منعٌ.**
  if (!request.actor.claims.canAccessSource(request.sourceId)) {
    return const StocktakeRejected(CallableError.sourceOutOfScope);
  }
  // ④ معرّف الطلب إلزامي — وبدونه لا تتحقق اللاتكرارية عند إعادة الإرسال.
  if (request.requestId.trim().isEmpty) {
    return const StocktakeRejected(CallableError.invalidArgument);
  }
  return null;
}

/// يخطّط عملية جرد — **دالة خالصة، وهي حارس التفويض الفعلي**.
StocktakePlan planStocktake(
  StocktakeRequest request,
  StocktakeOperation operation,
) {
  final StocktakeRejected? gate = stocktakeGate(request, operation);
  if (gate != null) return gate;

  if (request.documentNumber.trim().isEmpty ||
      request.sourceId.trim().isEmpty) {
    return const StocktakeRejected(CallableError.invalidArgument);
  }

  // ⛔⛔★★★ **ولا حارسَ للسبب** — [`ADR-0020`].
  final String? reason = _trimmed(request.reason);

  final StocktakeRejected? existence = _existenceGate(request, operation);
  if (existence != null) return existence;

  final StocktakeRejected? source = _sourceGate(request, operation);
  if (source != null) return source;

  final StocktakeRejected? date = _dateGate(request, operation);
  if (date != null) return date;

  return switch (operation) {
    StocktakeOperation.startStocktake => _planStart(request, reason),
    StocktakeOperation.approveStocktake ||
    StocktakeOperation.amendStocktake =>
      _planCounts(request, operation, reason),
    StocktakeOperation.cancelStocktake => _planCancellation(request, reason),
  };
}

// ═════════════════════════════════════════════════════════════════════════
// ① البدء — ★★★ **تجميدُ الرصيد الدفتري** ⛔ **بلا حركةٍ واحدة**
// ═════════════════════════════════════════════════════════════════════════

StocktakePlan _planStart(StocktakeRequest request, String? reason) {
  final ValidatedStocktakeStart? start = request.start;
  if (start == null || start.sourceId != request.sourceId) {
    return const StocktakeRejected(CallableError.invalidArgument);
  }

  // ⑥ ⛔⛔★★★ **ولا جردان مفتوحان على نفس المصدر ونفس اليوم** — `FR-M16-06`.
  //
  //    ⚠️ **والمقياس «مسوّدةٌ قائمة» لا «مستندٌ قائم»** — ⟵ **فجردٌ اعتُمد
  //    أو أُلغي لا يمنع جرداً ثانياً في اليوم نفسه**: ★ **العدُّ قد يُعاد**،
  //    ⛔ **والمنعُ المطلق كان يحبس اليومَ بعد أول خطأ.**
  for (final Map<String, Object?> stored in request.sameDayDocuments.values) {
    if (stored[documentStatusField] == StocktakeStatus.draft.name) {
      return const StocktakeRejected(CallableError.stocktakeInProgress);
    }
  }

  // ★ الأنواع: **موجودة · نشطة · مرتبطة بالمصدر**.
  final List<FrozenStocktakeLine> lines = <FrozenStocktakeLine>[];
  for (final String itemKey in start.itemKeys) {
    final ItemRead? item = request.items[itemKey];
    if (item == null || !item.isActive) {
      return const StocktakeRejected(CallableError.invalidArgument);
    }
    // ★★ `FR-M5-10`: **النوع لا يظهر إلا في مصادره**.
    if (!item.sourceIds.contains(request.sourceId)) {
      return const StocktakeRejected(CallableError.invalidArgument);
    }

    // ★★★ **والرصيدُ الدفتري يُقاس من الدفتر داخل المعاملة** (`ADR-0008`) —
    //    ⛔ **لا من `item_daily_balances`** ولا من الحمولة: ⟵ **وهو الرقمُ
    //    الذي يُجمَّد** (`FR-M16-03`)، ★ **فمصدرُه يجب أن يكون مصدرَ الحقيقة.**
    final Outcome<ItemDailyFlow> flow = computeItemDailyFlow(
      movements: <StockMovement>[
        for (final LedgerRead read in request.ledger[itemKey] ??
            const <LedgerRead>[])
          read.movement,
      ],
      unit: item.unit,
    );
    if (flow case Failure<ItemDailyFlow>(:final AppError error)) {
      return StocktakeRejected(_mapStockError(error, request, false));
    }

    lines.add(
      FrozenStocktakeLine(
        itemKey: itemKey,
        itemName: item.name,
        bookBalance: (flow as Success<ItemDailyFlow>).value.balance,
      ),
    );
  }

  final Map<String, Object?> after = _documentFields(
    request: request,
    lines: lines,
    counts: const <String, ValidatedStocktakeCount>{},
    status: StocktakeStatus.draft,
    reason: reason,
  );

  return StocktakeAccepted(
    documentNumber: request.documentNumber,
    // ⛔⛔★★★ **كتابةٌ واحدة لا أكثر** — ★ **المسوّدةُ لا تمسّ دفتراً ولا
    //    رصيداً**: ⟵ **فجردٌ بُدئ ولم يُعتمَد لا يُغيِّر رقماً في المخزن.**
    writes: <InventoryWrite>[
      _documentWrite(request, StocktakeOperation.startStocktake, after, reason),
    ],
    status: StocktakeStatus.draft,
    entry: _entry(
      request: request,
      action: AuditAction.create,
      reason: reason,
      valuesBefore: const <String, Object?>{},
      valuesAfter: after,
    ),
  );
}

// ═════════════════════════════════════════════════════════════════════════
// ② الاعتماد والتعديل — ★★★ **حركاتُ التسوية وإعادةُ بناء الرصيد**
// ═════════════════════════════════════════════════════════════════════════

StocktakePlan _planCounts(
  StocktakeRequest request,
  StocktakeOperation operation,
  String? reason,
) {
  final ValidatedStocktakeCounts? counts = request.counts;
  if (counts == null || counts.sourceId != request.sourceId) {
    return const StocktakeRejected(CallableError.invalidArgument);
  }

  // ★★★ **والسطورُ المُجمَّدة من المستند المخزَّن** — `FR-M16-03`:
  //    ⛔ **ولا يُعاد قياسُ الرصيد الدفتري هنا أبداً** (القاعدة ③ في ترويسة
  //    `stocktake.dart`)، ⟵ **وإلا ابتلعت التسويةُ كلَّ حركةٍ وقعت أثناء العدّ.**
  final List<FrozenStocktakeLine>? frozen =
      readFrozenLines(request.storedDocument);
  if (frozen == null || frozen.isEmpty) {
    return const StocktakeRejected(CallableError.invalidArgument);
  }
  final Map<String, FrozenStocktakeLine> frozenByKey =
      <String, FrozenStocktakeLine>{
    for (final FrozenStocktakeLine line in frozen) line.itemKey: line,
  };

  // ⛔⛔★★★ **ولا عدٌّ لنوعٍ خارج المُجمَّد** — ★ **الجردُ يقع على ما جُمِّد
  //    عند بدئه**: ⟵ **ونوعٌ يُضاف عند الاعتماد لا رصيدَ دفترياً مجمَّداً
  //    له**، ⛔ **فتسويتُه تُقاس على صفرٍ مفترَض** — ★ **وهو رقمٌ مخترَع.**
  final Map<String, ValidatedStocktakeCount> countsByKey =
      <String, ValidatedStocktakeCount>{};
  for (final ValidatedStocktakeCount count in counts.counts) {
    final FrozenStocktakeLine? line = frozenByKey[count.itemKey];
    if (line == null) {
      return const StocktakeRejected(CallableError.invalidArgument);
    }
    // ⛔ **ووحدة العدّ = وحدة الرصيد المُجمَّد** — `GR-19` · `E-31`.
    if (count.actualCount.unit != line.bookBalance.unit) {
      return const StocktakeRejected(CallableError.itemUnitLocked);
    }
    countsByKey[count.itemKey] = count;
  }

  final List<InventoryWrite> writes = <InventoryWrite>[];
  // ★★ **كل نوعٍ يلمسه هذا المستند** — المُجمَّدُ **وما في دفتره معاً**:
  //    ⟵ **فنوعٌ عُدّ في اعتمادٍ سابق ثم حُذف من التعديل تُلغى حركتُه.**
  final Set<String> touched = <String>{
    ...frozenByKey.keys,
    ...request.ledger.keys,
  };
  for (final String itemKey in touched.toList()..sort()) {
    final Outcome<List<InventoryWrite>> planned = _planItem(
      request: request,
      itemKey: itemKey,
      frozen: frozenByKey[itemKey],
      count: countsByKey[itemKey],
      operation: operation,
      reason: reason,
    );
    if (planned case Failure<List<InventoryWrite>>(:final AppError error)) {
      return StocktakeRejected(_mapStockError(error, request, operation.isAmend));
    }
    writes.addAll((planned as Success<List<InventoryWrite>>).value);
  }

  // ② ⛔⛔★★★ **ولا كتابةَ واحدة في `dealer_ledger` ولا `supplier_ledger`**
  //    — `BR-M16-03`: ★ **والغياب هنا هو تنفيذُ المتطلب نفسِه**، ⛔ **لا
  //    سهوٌ يُستدرَك.**

  final Map<String, Object?> after = _documentFields(
    request: request,
    lines: frozen,
    counts: countsByKey,
    status: StocktakeStatus.approved,
    reason: counts.reason,
  );
  writes.insert(0, _documentWrite(request, operation, after, reason));

  return StocktakeAccepted(
    documentNumber: request.documentNumber,
    writes: writes,
    status: StocktakeStatus.approved,
    entry: _entry(
      request: request,
      // ★★ **والاعتمادُ «تعديل» في معجم الأفعال** — `audit-log-design.md` §3:
      //    ⛔ **ولا يُخترَع فعلٌ «جرد» بلا سطرٍ هناك** (قاعدة `audit_action.dart`
      //    الصريحة). ⟵ **والقيدُ كاملٌ بحقوله كما يطلب `FR-M16-11`**:
      //    ★ **`valuesBefore` تحمل المسوّدة و`valuesAfter` الأعدادَ والفروق.**
      action: AuditAction.amend,
      reason: reason,
      valuesBefore: _changedBefore(request.storedDocument, after),
      valuesAfter: _changedAfter(request.storedDocument, after),
    ),
  );
}

// ═════════════════════════════════════════════════════════════════════════
// ③ الإلغاء — ★ **بالوسم** ⛔ **بلا حركة عكسية ولا حذف** (`GR-06` · `GR-07`)
// ═════════════════════════════════════════════════════════════════════════

StocktakePlan _planCancellation(StocktakeRequest request, String? reason) {
  final List<InventoryWrite> writes = <InventoryWrite>[];
  // ★★ **وحركاتُ المستند وحدَها تُوسَم ملغاة** — ⟵ **ومسوّدةٌ بلا حركاتٍ
  //    تُلغى بكتابةٍ واحدة**: ★ **فلا شيء في الدفتر يخصّها أصلاً.**
  for (final String itemKey in request.ledger.keys.toList()..sort()) {
    final Outcome<List<InventoryWrite>> planned = _planItem(
      request: request,
      itemKey: itemKey,
      frozen: null,
      count: null,
      operation: StocktakeOperation.cancelStocktake,
      reason: reason,
    );
    if (planned case Failure<List<InventoryWrite>>(:final AppError error)) {
      return StocktakeRejected(_mapStockError(error, request, false));
    }
    writes.addAll((planned as Success<List<InventoryWrite>>).value);
  }

  final Map<String, Object?> fields = <String, Object?>{
    documentStatusField: StocktakeStatus.cancelled.name,
    'cancelReason': reason,
    'cancelledBy': request.actor.userId,
  };
  writes.insert(
    0,
    InventoryWrite(
      collectionId: stocktakesCollection,
      documentId: request.documentNumber,
      fields: fields,
      // ★ **قناعٌ ضيّق** — ⛔ **فلا يمحو الإلغاءُ سطوراً ولا رصيداً مجمَّداً.**
      updateMask: fields.keys.toList(),
      serverTimestampFields: const <String>['cancelledAt'],
    ),
  );

  return StocktakeAccepted(
    documentNumber: request.documentNumber,
    writes: writes,
    status: StocktakeStatus.cancelled,
    entry: _entry(
      request: request,
      // ★ **الإلغاء فعلٌ مستقل في المعجم لا «تعديل»**.
      action: AuditAction.cancel,
      reason: reason,
      valuesBefore: <String, Object?>{
        documentStatusField: request.storedDocument?[documentStatusField] ??
            StocktakeStatus.draft.name,
      },
      valuesAfter: <String, Object?>{
        documentStatusField: StocktakeStatus.cancelled.name,
      },
    ),
  );
}

// ═════════════════════════════════════════════════════════════════════════
// نوعٌ واحد: حركةُ تسويته ورصيده
// ═════════════════════════════════════════════════════════════════════════

/// ★★★ **جوهر الزيادة مخزنياً:** يبني **حركة التسوية** ويُعيد بناء الرصيد.
///
/// ⚠️⚠️ **والرصيد يُجمَع ⛔ لا يُراكَم على قيمةٍ سابقة** —
/// `coding-standards.md` §2.7: ⟵ ★ **فإعادة إرسال الطلب نفسه تُنتج الرقم
/// نفسه.**
///
/// ★★★ **واتجاهُ الحركة من إشارة الفرق** ([stocktakeAdjustment]) —
/// ⛔ **ولا يُرسَل من الجهاز**: ⟵ **وهو النوعُ الوحيد في الدفتر الذي يكون
/// دخولاً أو خروجاً** (`SourceDocumentType.stocktake`).
Outcome<List<InventoryWrite>> _planItem({
  required StocktakeRequest request,
  required String itemKey,
  required FrozenStocktakeLine? frozen,
  required ValidatedStocktakeCount? count,
  required StocktakeOperation operation,
  required String? reason,
}) {
  final String movementId = stockMovementId(
    documentNumber: request.documentNumber,
    itemKey: itemKey,
  );
  final List<LedgerRead> reads = request.ledger[itemKey] ?? const <LedgerRead>[];
  final ItemRead? item = request.items[itemKey];
  final ItemUnit unit =
      item?.unit ?? frozen?.bookBalance.unit ?? _unitOfExisting(reads, movementId);

  // ★ **حركات غيري** — ⟵ **فالتعديل يستبدل حركتي لا يُراكم عليها.**
  final List<StockMovement> others = <StockMovement>[
    for (final LedgerRead read in reads)
      if (read.movementId != movementId) read.movement,
  ];

  StocktakeAdjustment? adjustment;
  StockQuantity difference = StockQuantity.zeroOf(unit);
  if (!operation.isCancel && frozen != null && count != null) {
    final Outcome<StockQuantity> computed = stocktakeDifference(
      bookBalance: frozen.bookBalance,
      actualCount: count.actualCount,
    );
    if (computed case Failure<StockQuantity>(:final AppError error)) {
      return Failure<List<InventoryWrite>>(error);
    }
    difference = (computed as Success<StockQuantity>).value;
    adjustment = stocktakeAdjustment(difference);
  }

  // ★★ **وحركةٌ ملغاة حين لا تسوية** — ⟵ **فرقٌ صفريٌّ أو نوعٌ حُذف من
  //    التعديل أو إلغاءُ المستند كلِّه**: ★ **والوسمُ يُخرِجها من كل رصيد**
  //    ⛔ **بلا حركةٍ عكسية** (`A-14`).
  final bool isCancelled = adjustment == null;
  final StockQuantity quantity =
      adjustment?.quantity ?? _existingQuantity(reads, movementId, unit);
  final MovementDirection direction = adjustment?.direction ??
      _existingDirection(reads, movementId) ??
      MovementDirection.outgoing;

  final List<StockMovement> projected = <StockMovement>[
    ...others,
    StockMovement(
      itemKey: itemKey,
      direction: direction,
      quantity: quantity,
      isCancelled: isCancelled,
      // ③ ★★★ **والوسمُ هو ما يُخرِج هذه الحركة من كل احتساب** — `BR-M16-03`.
      movementTag: MovementTag.adjustment,
    ),
  ];

  final Outcome<ItemDailyFlow> flow =
      computeItemDailyFlow(movements: projected, unit: unit);
  if (flow case Failure<ItemDailyFlow>(:final AppError error)) {
    return Failure<List<InventoryWrite>>(error);
  }
  final ItemDailyFlow computed = (flow as Success<ItemDailyFlow>).value;

  // ⛔⛔★★ **ومنعُ الرصيد السالب قائمٌ هنا كذلك** — `FR-M8-01` · `GR-11`:
  //    ⟵ **وعدٌّ فعليٌّ غيرُ سالبٍ لا يُنتج رصيداً سالباً بذاته**، ★ **لكنَّ
  //    حركةً وقعت بعد التجميد قد تجعله كذلك** — ⛔ **فالحارسُ لا يُسقَط
  //    لأن المسار «يبدو آمناً».**
  final Outcome<void> allowed = validateNonNegativeBalance(computed.balance);
  if (allowed case Failure<void>(:final AppError error)) {
    return Failure<List<InventoryWrite>>(error);
  }

  return Success<List<InventoryWrite>>(<InventoryWrite>[
    _movementWrite(
      request: request,
      movementId: movementId,
      itemKey: itemKey,
      itemName: item?.name ?? frozen?.itemName ?? itemKey,
      unit: unit,
      direction: direction,
      quantity: quantity,
      balanceAfter: computed.balance,
      isCancelled: isCancelled,
      isCreate: operation == StocktakeOperation.approveStocktake,
      reason: count?.differenceReason ?? reason,
    ),
    _balanceWrite(
      request: request,
      itemKey: itemKey,
      itemName: item?.name ?? frozen?.itemName ?? itemKey,
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

MovementDirection? _existingDirection(
  List<LedgerRead> reads,
  String movementId,
) {
  for (final LedgerRead read in reads) {
    if (read.movementId == movementId) return read.movement.direction;
  }
  return null;
}

ItemUnit _unitOfExisting(List<LedgerRead> reads, String movementId) {
  for (final LedgerRead read in reads) {
    if (read.movementId == movementId) return read.movement.quantity.unit;
  }
  return reads.isEmpty ? ItemUnit.piece : reads.first.movement.quantity.unit;
}

InventoryWrite _movementWrite({
  required StocktakeRequest request,
  required String movementId,
  required String itemKey,
  required String itemName,
  required ItemUnit unit,
  required MovementDirection direction,
  required StockQuantity quantity,
  required StockQuantity balanceAfter,
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
    'direction': direction.name,
    'quantity': stocktakeQuantityValue(quantity),
    'balanceAfter': stocktakeQuantityValue(balanceAfter),
    // ⚠️⚠️ **ويُمرَّر صراحةً ⛔ لا يُحفَر** — ★ **درسُ `sourceDocType` المحفور**
    //    (2026-08-26).
    'sourceDocType': SourceDocumentType.stocktake.name,
    'sourceDocId': request.documentNumber,
    'sourceDocNumber': request.documentNumber,
    // ③ ★★★ **والوسمُ يُخرِجها من المبيعات ومن سعر الجونية ومن الرعوي** —
    //    `BR-M16-03` · `AT-66`.
    'movementTag': MovementTag.adjustment.name,
    'isCancelled': isCancelled,
    // ⛔⛔★★★ **ولا `sackId` في حركة التسوية** — ★ **قصداً**: ⟵ **الفرقُ غيرُ
    //    مفسَّرٍ بمستند** (`FR-M16` §1) **فلا جونيةَ يُنسَب إليها**،
    //    ⛔ **ونسبتُه إلى جونيةٍ كانت تُوهِم أن لها أثراً في سعرها.**
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
  required StocktakeRequest request,
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
    'incoming': stocktakeQuantityValue(flow.incoming),
    'outgoing': stocktakeQuantityValue(flow.outgoing),
    'balance': stocktakeQuantityValue(flow.balance),
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
/// ★★ **والوزن يمرّ بـ[DecimalValue] وحدها** (`ADR-0015` القاعدة 9) —
/// ⛔ **و`double` المجرَّد يبقى مرفوضاً في المُرمِّز** (`DEBT-41`).
Object stocktakeQuantityValue(StockQuantity quantity) => switch (quantity) {
      PieceQuantity(:final PieceCount count) => count.pieces,
      WeightQuantity(:final WeightKg weight) => DecimalValue(weight.kilograms),
    };

// ═════════════════════════════════════════════════════════════════════════
// المستند وحقوله
// ═════════════════════════════════════════════════════════════════════════

/// ★★★ **يقرأ السطور المُجمَّدة من المستند المخزَّن** — و`null` **لمشوَّه**.
///
/// ⚠️⚠️ **ولماذا مُصدَّرة:** ⟵ **المُنفِّذ يحتاجها قبل فتح المعاملة ليعرف
/// أنواعَ المستند فيقرأ حركاتِها**، ★ **والمُخطِّط يحتاجها داخلها ليحكم**
/// — ⛔ **ونسختان منها تفترقان عند أول تغيّرٍ في شكل الحقول.**
List<FrozenStocktakeLine>? readFrozenLines(Map<String, Object?>? document) {
  final Object? raw = document?['lines'];
  if (raw is! List<Object?>) return null;
  final List<FrozenStocktakeLine> lines = <FrozenStocktakeLine>[];
  for (final Object? entry in raw) {
    if (entry is! Map<String, Object?>) continue;
    final Object? itemKey = entry['itemKey'] ?? entry['itemId'];
    if (itemKey is! String || itemKey.isEmpty) continue;
    final ItemUnit unit = entry['unit'] == ItemUnit.kilogram.name
        ? ItemUnit.kilogram
        : ItemUnit.piece;
    final Object? itemName = entry['itemName'];
    lines.add(
      FrozenStocktakeLine(
        itemKey: itemKey,
        itemName:
            itemName is String && itemName.isNotEmpty ? itemName : itemKey,
        bookBalance: _quantityOf(entry['bookBalance'], unit),
      ),
    );
  }
  return lines;
}

StockQuantity _quantityOf(Object? raw, ItemUnit unit) {
  final num value = switch (raw) {
    final num number => number,
    final DecimalValue decimal => decimal.value,
    _ => 0,
  };
  return switch (unit) {
    // ⛔ **والحبّةُ عددٌ صحيح** — `BR-M6-06`.
    ItemUnit.piece => PieceQuantity(PieceCount(value.round())),
    ItemUnit.kilogram => WeightQuantity(WeightKg(value.toDouble())),
  };
}

Map<String, Object?> _documentFields({
  required StocktakeRequest request,
  required List<FrozenStocktakeLine> lines,
  required Map<String, ValidatedStocktakeCount> counts,
  required StocktakeStatus status,
  required String? reason,
}) =>
    <String, Object?>{
      'documentNumber': request.documentNumber,
      'sourceId': request.sourceId,
      if (_nameOf(request.storedSource) case final String sourceName)
        'sourceName': sourceName,
      // ★★★ **تاريخٌ واحد** — ⛔ **ولا `documentDate` هنا** (بخلاف `outflows`):
      //    ⟵ **لا أثرَ ماليَّ يقع في يومٍ آخر** (`BR-M16-04`).
      'stockDate': request.stockDate.asUtcMidnight(),
      if (reason case final String value) 'reason': value,
      'lines': <Object?>[
        for (final FrozenStocktakeLine line in lines)
          <String, Object?>{
            'itemKey': line.itemKey,
            'itemName': line.itemName,
            'unit': line.bookBalance.unit.name,
            // 🔒 ★★★ **الرصيد الدفتري المُجمَّد** — `FR-M16-03`:
            //    ⛔ **يُكتب عند البدء ولا يُمَسّ بعده أبداً.**
            'bookBalance': stocktakeQuantityValue(line.bookBalance),
            if (counts[line.itemKey] case final ValidatedStocktakeCount count)
              ...<String, Object?>{
                'actualCount': stocktakeQuantityValue(count.actualCount),
                'difference': stocktakeQuantityValue(
                  _differenceOrZero(line.bookBalance, count.actualCount),
                ),
                // ★★ **وسببُ الفرق اختياريٌّ** — `FR-M16-04` · [`ADR-0020`].
                'differenceReason': ?count.differenceReason,
              },
            // ⛔⛔★★★ **ولا حقلَ ماليٍّ في السطر** — `BR-M16-03`.
          },
      ],
      'lineCount': lines.length,
      documentStatusField: status.name,
      // ⛔⛔★★★ **ولا `grandTotal` ولا `totalValue` ولا حقلَ مقوتٍ ولا رعوي.**
    };

StockQuantity _differenceOrZero(StockQuantity book, StockQuantity actual) {
  final Outcome<StockQuantity> computed =
      stocktakeDifference(bookBalance: book, actualCount: actual);
  return switch (computed) {
    Success<StockQuantity>(:final StockQuantity value) => value,
    // ⛔ **غيرُ بالغٍ** — الوحدةُ فُحصت في [_planCounts] قبل الوصول هنا.
    Failure<StockQuantity>() => StockQuantity.zeroOf(book.unit),
  };
}

InventoryWrite _documentWrite(
  StocktakeRequest request,
  StocktakeOperation operation,
  Map<String, Object?> after,
  String? reason,
) {
  final Map<String, Object?> fields = <String, Object?>{
    ...after,
    if (operation.isStart) 'createdBy': request.actor.userId,
    if (operation == StocktakeOperation.approveStocktake)
      'approvedBy': request.actor.userId,
    if (!operation.isStart) ...<String, Object?>{
      'amendedBy': request.actor.userId,
      'amendReason': reason,
      'amendCount': _amendCount(request.storedDocument) + 1,
    },
  };
  return InventoryWrite(
    collectionId: stocktakesCollection,
    // ★ **ورقم المستند هو معرّفه**.
    documentId: request.documentNumber,
    fields: fields,
    updateMask: fields.keys.toList(),
    serverTimestampFields: switch (operation) {
      StocktakeOperation.startStocktake => const <String>[
          'createdAt',
          'entryDate',
        ],
      StocktakeOperation.approveStocktake => const <String>[
          'approvedAt',
          'lastAmendedAt',
        ],
      _ => const <String>['lastAmendedAt'],
    },
  );
}

// ═════════════════════════════════════════════════════════════════════════
// بوابات مشتركة
// ═════════════════════════════════════════════════════════════════════════

/// ★ يفحص أن المستند غائبٌ عند البدء وموجودٌ **بحالته الصحيحة** في ما عداه.
StocktakeRejected? _existenceGate(
  StocktakeRequest request,
  StocktakeOperation operation,
) {
  final Map<String, Object?>? stored = request.storedDocument;
  if (operation.isStart) {
    // ★ **ورقمٌ مخصَّصٌ للتوّ لا يقابله مستند** — ⟵ **ووجودُه تصادمُ عدّاد.**
    return stored == null
        ? null
        : const StocktakeRejected(CallableError.concurrency);
  }
  if (stored == null) {
    return const StocktakeRejected(CallableError.invalidArgument);
  }
  // ★★★ **والمخزَّن هو الحَكَم لا المُرسَل** — `GR-23`.
  if (stored['sourceId'] != request.sourceId) {
    return const StocktakeRejected(CallableError.sourceOutOfScope);
  }
  final Object? status = stored[documentStatusField];
  // ★★ **والملغى لا يُعتمَد ولا يُعدَّل ولا يُلغى ثانيةً** — `ERR_AMEND_006`.
  if (status == StocktakeStatus.cancelled.name) {
    return const StocktakeRejected(CallableError.documentCancelled);
  }
  // ⛔⛔★★★ **والحالةُ تحكم أيَّ عمليةٍ تُقبَل** — `FR-M16-09`:
  //
  //    | العملية | الحالة المطلوبة | لماذا |
  //    |---|---|---|
  //    | **اعتماد** | **مسوّدة** | ⛔ **ومعتمدٌ يُعتمَد ثانيةً كان يُنتج قيدَين لتسويةٍ واحدة** |
  //    | **تعديل** | **معتمد** | ⛔ **ومسوّدةٌ تُعدَّل بالاعتماد لا بالتعديل** — ★ **وإلا التفّ التعديلُ على مفتاح الاعتماد** |
  //    | **إلغاء** | **أيٌّ منهما** | ★ **فمسوّدةٌ خاطئة تُلغى كما يُلغى معتمَد** |
  if (operation == StocktakeOperation.approveStocktake &&
      status != StocktakeStatus.draft.name) {
    return const StocktakeRejected(CallableError.stocktakeNotDraft);
  }
  if (operation.isAmend && status != StocktakeStatus.approved.name) {
    return const StocktakeRejected(CallableError.stocktakeNotApproved);
  }
  return null;
}

/// ★ يفحص المصدر — **موجودٌ ونشط**.
///
/// ⚠️ **والإلغاء مسموح على مصدرٍ عُطِّل** — ⟵ **فالتعطيل لا يحبس مستنداً
/// خاطئاً داخل النظام**؛ ⛔ **والمنع على الجديد وتعديله** (`FR-M2-05`).
StocktakeRejected? _sourceGate(
  StocktakeRequest request,
  StocktakeOperation operation,
) {
  final Map<String, Object?>? source = request.storedSource;
  // ⛔ **سجلٌّ لم يُقرأ ⟵ رفض** — الرفض الافتراضي.
  if (source == null) {
    return const StocktakeRejected(CallableError.internal);
  }
  if (operation.isCancel) return null;
  if (source['isActive'] == false) {
    return const StocktakeRejected(CallableError.sourceInactive);
  }
  return null;
}

/// ★★★ **حارسُ تاريخ المخزون** — [stocktakePriorDayRejection].
///
/// ⚠️ **ولا يُفحَص إلا في البدء** — ★ **فاليومُ يُقرَّر هناك مرةً واحدة**:
/// ⟵ **والاعتمادُ والتعديلُ والإلغاءُ تقع على مستندٍ قائمٍ يومُه محفورٌ في
/// رقمه**، ⛔ **ولو فُحصت لَاستحال إتمامُ جردٍ بُدئ أمسِ بشكلٍ مشروع.**
StocktakeRejected? _dateGate(
  StocktakeRequest request,
  StocktakeOperation operation,
) {
  if (!operation.isStart) return null;
  // ⛔ **و«غيرُ معلوم» لا حُكمَ له** — راجع [StocktakeRequest.serverDay].
  if (request.serverDay case final CalendarDay serverDay) {
    final CallableError? rejection = stocktakePriorDayRejection(
      actor: request.actor,
      stockDate: request.stockDate,
      serverDay: serverDay,
    );
    if (rejection != null) return StocktakeRejected(rejection);
  }
  return null;
}

/// ★ يُترجم خطأ النطاق إلى رمز الكتالوج **بحسب الفعل المطلوب**.
CallableError _mapStockError(
  AppError error,
  StocktakeRequest request,
  bool isAmend,
) =>
    switch (error) {
      InsufficientStockError() when isAmend =>
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
///
/// ⚠️ **والمخزَّن يعود `double` لا [DecimalValue]** — ⟵ **فالمقارنة على
/// القيمة**، ⛔ **وإلا قُرئ كلُّ وزنٍ «تغييراً» في كل تعديل.**
bool _sameValue(Object? a, Object? b) {
  if (a is DecimalValue && b is DecimalValue) return a.value == b.value;
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
  required StocktakeRequest request,
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
        entityType: stocktakeEntityType,
        entityId: request.documentNumber,
        sourceId: request.sourceId,
      ),
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

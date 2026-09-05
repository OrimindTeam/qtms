/// الإتلاف — **التخطيط الخالص** لعمليات `WU-020` (`M8` · `FR-M8-16`).
///
/// ★ **مفصول عن الشبكة بنفس منطق `outflow.dart`:** `ADR-0013` القاعدة 3
/// تجعل **فحص التفويض في الكود** هو الحارس الوحيد لهذا المسار، فالدالة تعمل
/// بامتياز إداري يتجاوز قواعد الحماية. ★ **وحارسٌ لا يُختبَر بلا سحابة
/// حارسٌ غير مُختبَر** — فكل قرار هنا **دالة خالصة**.
///
/// ★ **وكل معادلة من طبقة النطاق لا من هنا** (`qtms_domain`) —
/// ⛔ **ولا تُعاد كتابتها** (`coding-standards.md` §2.2 · `ADR-0009`).
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔★★ **سبعةُ قيودٍ بندُ قبولٍ مُلزِم لهذه الدالة:**
///
///   ① ⛔⛔★★★ **ولا حقلَ ماليٍّ واحدٌ يُكتب** — `FR-M8-16` ·
///      `data-dictionary.md` §`disposals`: ⟵ **لا `unitPrice` ولا
///      `lineTotal` ولا `amount` ولا `grandTotal`**، ★ **والضمانةُ بنيويةٌ:
///      [ValidatedDisposal] لا يحمل مبلغاً أصلاً** ⛔ **فلا مسارَ يُسرِّبه.**
///   ② ⛔⛔★★★ **ولا قيدَ واحدٌ في دفتر المقاوته ولا في دفتر الرعوي** —
///      `A-15` · `GR-29`: ★ **«كل قات يخرج يستحق الرعوي ثمنه — والاستثناء
///      الوحيد: الإتلاف والوزن الضائع»** (`schema/supplier-ledger.md`).
///      ⟵ **والغياب هنا تنفيذُ المتطلب لا نقصٌ فيه.**
///   ③ ⛔⛔★★★ **ولا يدخل سعرَ الجونية** (`design-overview.md` §2.2) —
///      ★ **بنيوياً:** ⟵ **`readSackMovementDocuments` لا تقرأ `disposals`
///      إطلاقاً**، ⛔ **فلا شرطَ استثناءٍ يُنسى في دالة جمع.**
///      ★★ **والحركةُ تُوسَم [MovementTag.disposal] فوق ذلك** — ⟵ **حزامٌ
///      وحمّالة**، ★ **فأيُّ قارئٍ للدفتر لاحقاً يراها مستثناةً بالوسم.**
///   ④ ★★ **نطاق المصادر** — ⛔ **قيدٌ يعلو على كل صلاحية** (`GR-23`).
///   ⑤ ★★★ **وتاريخُ المخزون:** **اليوم ⟵ قبول** · **أقدم ⟵ يشترط
///      `agedRemainderClear`** (`FR-M8-11` — **الإتلافُ ثالثُ إجراءات
///      التصريف**) · **أحدث ⟵ مرفوضٌ للجميع**. ⛔ **والحُكمُ من
///      `agedClearanceRejection` وحدها** (`aged_remainder.dart`) — ★ **لا
///      حارسٌ ثانٍ يُخترَع** (`coding-standards.md` §2.2).
///   ⑥ ★★ **منع الرصيد السالب** (`FR-M8-01` · `GR-11`) — ★ **مقيساً من
///      الدفتر داخل المعاملة** ⛔ **لا من الملخص ولا من الجهاز.**
///   ⑦ **الحذف مرفوض نهائياً** — ⟵ **ولا مسار حذف في هذا الملف أصلاً**،
///      ★ **والإلغاءُ بالوسم** (`GR-06` · `GR-07` · `A-14`).
/// ═══════════════════════════════════════════════════════════════════════
///
/// ⛔⛔★★ **والسببُ اختياريٌّ في الأفعال الثلاثة** — `ADR-0020`: ★ **وكان
/// إلزامياً في الإتلاف حتى 2026-08-27** (`FR-M18-07` **مُلغى**)، ⟵ **فلا
/// حارسَ غيابٍ هنا** ⛔ **ولا يُعبَّأ نيابةً عن المستخدم.**
library;

import 'package:qtms_domain/qtms_domain.dart';

import 'aged_remainder.dart' show agedClearanceRejection, isAgedClearanceOn;
import 'callable.dart';
import 'firestore_value.dart' show DecimalValue;
import 'identity_gateway.dart';
import 'inventory.dart';

/// نوع عملية إتلاف.
enum DisposalOperation {
  /// `createDisposal` — ينشئ مستنداً (`FR-M8-16`).
  createDisposal(Permission.disposalCreate, isCreate: true),

  /// `amendDisposal` — يعدّل مستنداً معتمداً **بسببٍ نصّي اختياري**
  /// (`ADR-0020`).
  amendDisposal(Permission.disposalAmend, isCreate: false),

  /// `cancelDisposal` — ★ **يَسِم المستند وحركاته «ملغى»** ⛔ **وليس حذفاً**
  /// (`GR-06` · `GR-07` · `A-14`).
  cancelDisposal(Permission.disposalCancel, isCreate: false, isCancel: true);

  const DisposalOperation(
    this.requiredPermission, {
    required this.isCreate,
    this.isCancel = false,
  });

  /// ★★ **المفتاح المطلوب** — ⛔ **ثلاثةٌ مستقلة لا مفتاحٌ واحد**:
  /// `permissions-catalog.md` §2.4 و§`disposalAmend`/`disposalCancel`
  /// (**جدول التعديل والإلغاء**) — ⟵ **فمن يسجّل إتلافاً لا يُلغيه.**
  final Permission requiredPermission;

  /// هل هي إنشاء؟
  final bool isCreate;

  /// هل هي إلغاء؟
  final bool isCancel;
}

/// نتيجة التخطيط — إما خطة كتابة وإما رفض مصنَّف.
sealed class DisposalPlan {
  /// ينشئ النتيجة.
  const DisposalPlan();
}

/// رُفض الطلب قبل أي كتابة.
final class DisposalRejected extends DisposalPlan {
  /// ينشئ رفضاً.
  const DisposalRejected(this.error);

  /// رمز الرفض من كتالوج الأخطاء.
  final CallableError error;
}

/// قُبل الطلب — وهذه كتاباته وقيده.
final class DisposalAccepted extends DisposalPlan {
  /// ينشئ خطة مقبولة.
  const DisposalAccepted({
    required this.documentNumber,
    required this.writes,
    required this.entry,
    required this.isCancelled,
  });

  /// رقم المستند — `DSP-…` ★ **وهو معرّفه في المجموعة**.
  final String documentNumber;

  /// المستندات المكتوبة — ⛔ **ولا تكون فارغة**.
  final List<InventoryWrite> writes;

  /// قيد التدقيق — **يُكتب في المعاملة نفسها** (`ADR-0013` القاعدة 1).
  final AuditEntry entry;

  /// ★ هل المستند ملغى بعد هذه العملية؟
  final bool isCancelled;
}

/// طلبُ إتلافٍ مُتحقَّق من هوية مُنفِّذه.
final class DisposalRequest {
  /// ينشئ الطلب.
  const DisposalRequest({
    required this.actor,
    required this.requestId,
    required this.sourceId,
    required this.documentNumber,
    required this.stockDate,
    this.serverDay,
    this.disposal,
    this.storedSource,
    this.storedDocument,
    this.items = const <String, ItemRead>{},
    this.ledger = const <String, List<LedgerRead>>{},
    this.reason,
    this.deviceInfo,
  });

  /// المُنفِّذ **بحالته الآن من خدمة المصادقة**.
  final AccountRecord actor;

  /// ★ معرّف الطلب — **وهو معرّف قيد التدقيق نفسه** (`api-overview.md` §4).
  final String requestId;

  /// المصدر المستهدف.
  final String sourceId;

  /// رقم المستند — **المخصَّص عند الإنشاء والقائم عند التعديل**.
  final String documentNumber;

  /// ★★★ **تاريخ المخزون** — ⛔ **وهو التاريخ الوحيد في هذه العملية**:
  /// ⟵ **لا أثرَ ماليَّ لها يقع في يومٍ آخر** (`data-dictionary.md`
  /// §`disposals`).
  final CalendarDay stockDate;

  /// ★★ **يومُ المنصّة** — ⛔ **من `readTime` داخل المعاملة** لا من الجهاز.
  ///
  /// ⚠️⚠️ **و`null` تعني «غيرُ معلوم فلا حُكم»** — ★ **بنفس
  /// `CashSaleRequest.serverDay` حرفياً**: ⟵ **وهو حالُ التعديل والإلغاء**
  /// حيث اليومُ محفورٌ في رقم المستند ولا يُعاد تقريرُه، ⛔ **ولو فُحص هناك
  /// لَاستحال تعديلُ إتلافِ أمسٍ على من لا يملك `agedRemainderClear`**
  /// — ★ **وهو ليس تصريفاً جديداً بل تصحيحُ مستندٍ قائم.**
  final CalendarDay? serverDay;

  /// ★ هل هذه العملية **تصريفُ متبقٍّ متأخر**؟ — `FR-M8-11`.
  bool get isAgedClearance =>
      isAgedClearanceOn(stockDate: stockDate, serverDay: serverDay);

  /// المستند المُتحقَّق منه — `null` للإلغاء.
  final ValidatedDisposal? disposal;

  /// سجل المصدر كما قُرئ — ⛔ **و`null` رفضٌ لا تجاوز**.
  final Map<String, Object?>? storedSource;

  /// المستند القائم — `null` تعني **غيابه**.
  final Map<String, Object?>? storedDocument;

  /// سجلات الأنواع المطلوبة بمعرّفاتها.
  final Map<String, ItemRead> items;

  /// ★★ **حركات دفتر المخزون لكل نوع** — **مقروءةً داخل المعاملة**.
  final Map<String, List<LedgerRead>> ledger;

  /// ★ سبب الإتلاف أو التعديل أو الإلغاء — ⛔ **اختياريٌّ** (`ADR-0020`).
  final String? reason;

  /// وصف الجهاز للسجل — ⛔ بلا بيانات حساسة.
  final String? deviceInfo;
}

/// ★★ فحوص الحالة والصلاحية والنطاق — **تُستدعى قبل فتح المعاملة**.
///
/// ⚠️ **ولماذا مُصدَّرة:** ⟵ **فتحُ معاملةٍ لطلبٍ يرفضه نقصُ الصلاحية هدرٌ
/// وقفلٌ بلا داعٍ**. ★ **والفحص يُعاد كاملاً** في [planDisposal] ⛔ **فلا مسار
/// يتخطّاه.**
DisposalRejected? disposalGate(
  DisposalRequest request,
  DisposalOperation operation,
) {
  // ① «التعطيل فوري ونافذ» — `authentication-policy.md` §2 القاعدة 3.
  if (request.actor.disabled) {
    return const DisposalRejected(CallableError.accountDisabled);
  }
  // ② ★★ **المفتاح يتبع العملية** — ⛔ **ثلاثةٌ لا واحد.**
  if (!request.actor.claims.has(operation.requiredPermission)) {
    return const DisposalRejected(CallableError.permissionMissing);
  }
  // ③ ★★ **النطاق — قيدٌ يعلو على الصلاحية** (`GR-23`) — ⛔ **والغياب منعٌ.**
  if (!request.actor.claims.canAccessSource(request.sourceId)) {
    return const DisposalRejected(CallableError.sourceOutOfScope);
  }
  // ④ معرّف الطلب إلزامي — وبدونه لا تتحقق اللاتكرارية عند إعادة الإرسال.
  if (request.requestId.trim().isEmpty) {
    return const DisposalRejected(CallableError.invalidArgument);
  }
  return null;
}

/// يخطّط عملية إتلاف — **دالة خالصة، وهي حارس التفويض الفعلي**.
DisposalPlan planDisposal(
  DisposalRequest request,
  DisposalOperation operation,
) {
  final DisposalRejected? gate = disposalGate(request, operation);
  if (gate != null) return gate;

  if (request.documentNumber.trim().isEmpty ||
      request.sourceId.trim().isEmpty) {
    return const DisposalRejected(CallableError.invalidArgument);
  }

  // ⛔⛔★★★ **ولا حارسَ للسبب** — `ADR-0020`.
  final String? reason = _trimmed(request.reason);

  final DisposalRejected? existence = _existenceGate(request, operation);
  if (existence != null) return existence;

  final DisposalRejected? source = _sourceGate(request, operation);
  if (source != null) return source;

  final DisposalRejected? date = _dateGate(request, operation);
  if (date != null) return date;

  return operation.isCancel
      ? _planCancellation(request, reason)
      : _planDisposal(request, operation, reason);
}

// ═════════════════════════════════════════════════════════════════════════
// الإنشاء والتعديل
// ═════════════════════════════════════════════════════════════════════════

DisposalPlan _planDisposal(
  DisposalRequest request,
  DisposalOperation operation,
  String? reason,
) {
  final ValidatedDisposal? disposal = request.disposal;
  if (disposal == null || disposal.sourceId != request.sourceId) {
    return const DisposalRejected(CallableError.invalidArgument);
  }

  // ★ الأنواع: **موجودة · نشطة · مرتبطة بالمصدر · بوحدتها المخزَّنة**.
  for (final ValidatedDisposalLine line in disposal.lines) {
    final ItemRead? item = request.items[line.itemKey];
    if (item == null || !item.isActive) {
      return const DisposalRejected(CallableError.invalidArgument);
    }
    // ★★ `FR-M5-10`: **النوع لا يظهر إلا في مصادره**.
    if (!item.sourceIds.contains(request.sourceId)) {
      return const DisposalRejected(CallableError.invalidArgument);
    }
    // ⛔ **ووحدة السطر = وحدة النوع المخزَّنة** — `FR-M5-03` · `GR-19`.
    if (line.quantity.unit != item.unit) {
      return const DisposalRejected(CallableError.itemUnitLocked);
    }
  }

  // ★★ **كل نوعٍ يلمسه هذا المستند** — الجديد **والمحذوف من التعديل معاً**.
  final Map<String, StockQuantity> desired = <String, StockQuantity>{
    for (final ValidatedDisposalLine line in disposal.lines)
      line.itemKey: line.quantity,
  };
  final Map<String, String?> sackIds = <String, String?>{
    for (final ValidatedDisposalLine line in disposal.lines)
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
      return DisposalRejected(_mapStockError(error, operation));
    }
    writes.addAll((planned as Success<List<InventoryWrite>>).value);
  }

  // ② ⛔⛔★★★ **ولا كتابةَ واحدة في `dealer_ledger` ولا `supplier_ledger`**
  //    — `A-15` · `GR-29`: ★ **والغياب هنا هو تنفيذُ المتطلب نفسِه**،
  //    ⛔ **لا سهوٌ يُستدرَك.**

  final Map<String, Object?> after = _documentFields(request, disposal);
  writes.insert(0, _documentWrite(request, operation, after, reason));

  return DisposalAccepted(
    documentNumber: request.documentNumber,
    writes: writes,
    isCancelled: false,
    entry: _entry(
      request: request,
      // ★★★ **وفعلٌ مستقلٌّ في المعجم** — `FR-M18-08` · `audit_action.dart`:
      //    ⟵ **«إتلاف» فعلٌ واجبُ التسجيل باسمه** ⛔ **لا «إنشاءً» عادياً**،
      //    ★ **ومرشِّحُ سجل التدقيق يفصله.**
      action: operation.isCreate ? AuditAction.disposal : AuditAction.amend,
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

DisposalPlan _planCancellation(DisposalRequest request, String? reason) {
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
      return DisposalRejected(
        _mapStockError(error, DisposalOperation.cancelDisposal),
      );
    }
    writes.addAll((planned as Success<List<InventoryWrite>>).value);
  }

  final Map<String, Object?> fields = <String, Object?>{
    documentStatusField: DisposalStatus.cancelled.name,
    'cancelReason': reason,
    'cancelledBy': request.actor.userId,
  };
  writes.insert(
    0,
    InventoryWrite(
      collectionId: disposalsCollection,
      documentId: request.documentNumber,
      fields: fields,
      // ★ **قناعٌ ضيّق** — ⛔ **فلا يمحو الإلغاءُ سطوراً ولا تاريخاً.**
      updateMask: fields.keys.toList(),
      serverTimestampFields: const <String>['cancelledAt'],
    ),
  );

  return DisposalAccepted(
    documentNumber: request.documentNumber,
    writes: writes,
    isCancelled: true,
    entry: _entry(
      request: request,
      // ★ **الإلغاء فعلٌ مستقل في المعجم لا «تعديل»**.
      action: AuditAction.cancel,
      reason: reason,
      valuesBefore: <String, Object?>{
        documentStatusField: request.storedDocument?[documentStatusField] ??
            DisposalStatus.approved.name,
      },
      valuesAfter: <String, Object?>{
        documentStatusField: DisposalStatus.cancelled.name,
      },
    ),
  );
}

// ═════════════════════════════════════════════════════════════════════════
// نوعٌ واحد: حركته الخارجة ورصيده
// ═════════════════════════════════════════════════════════════════════════

/// ★★★ **جوهر الزيادة مخزنياً:** يبني حركة **الخروج** ويُعيد بناء الرصيد.
///
/// ⚠️⚠️ **والرصيد يُجمَع ⛔ لا يُراكَم على قيمةٍ سابقة** —
/// `coding-standards.md` §2.7: ⟵ ★ **فإعادة إرسال الطلب نفسه تُنتج الرقم
/// نفسه.**
Outcome<List<InventoryWrite>> _planItem({
  required DisposalRequest request,
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
      // ⛔★★ **خروجٌ دائماً** — `FR-M8-16`.
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
  final Outcome<void> allowed = validateNonNegativeBalance(computed.balance);
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
  required DisposalRequest request,
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
    'quantity': disposalQuantityValue(quantity),
    'balanceAfter': disposalQuantityValue(balanceAfter),
    // ⚠️⚠️ **ويُمرَّر صراحةً ⛔ لا يُحفَر** — ★ **درسُ `sourceDocType` المحفور**
    //    (2026-08-26): ⟵ **والقيمةُ تخصّ هذه العملية وحدها اليوم**،
    //    ⛔ **لكنها تُكتب من التعداد لا من نصٍّ حرفيّ.**
    'sourceDocType': SourceDocumentType.disposal.name,
    'sourceDocId': request.documentNumber,
    'sourceDocNumber': request.documentNumber,
    // ③ ★★★ **والوسمُ هو ما يُخرِج هذه الحركة من كل احتساب** — `FR-M8-16` ·
    //    `AT-66` · `inventory-design.md` §2: ⟵ **لا سعرَ جونيةٍ ولا مبيعات
    //    ولا استحقاقَ رعوي**، ⛔ **و[MovementTag.normal] هنا كان يُدخِلها
    //    في احتساباتٍ لا تخصّها بصمت.**
    'movementTag': MovementTag.disposal.name,
    'isCancelled': isCancelled,
    // ★ **ومرجعُ الجونية يبقى** — ⟵ **لتقرير `R-07`** ⛔ **بلا أثرٍ في سعرها**
    //   (القاعدة ③ في ترويسة الملف).
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
  required DisposalRequest request,
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
    'incoming': disposalQuantityValue(flow.incoming),
    'outgoing': disposalQuantityValue(flow.outgoing),
    'balance': disposalQuantityValue(flow.balance),
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
Object disposalQuantityValue(StockQuantity quantity) => switch (quantity) {
      PieceQuantity(:final PieceCount count) => count.pieces,
      WeightQuantity(:final WeightKg weight) => DecimalValue(weight.kilograms),
    };

// ═════════════════════════════════════════════════════════════════════════
// المستند وحقوله
// ═════════════════════════════════════════════════════════════════════════

Map<String, Object?> _documentFields(
  DisposalRequest request,
  ValidatedDisposal disposal,
) =>
    <String, Object?>{
      'documentNumber': request.documentNumber,
      'sourceId': disposal.sourceId,
      if (_nameOf(request.storedSource) case final String sourceName)
        'sourceName': sourceName,
      // ★★★ **تاريخٌ واحد** — ⛔ **ولا `documentDate` هنا** (بخلاف `outflows`):
      //    ⟵ **لا أثرَ ماليَّ يقع في يومٍ آخر** (`data-dictionary.md`).
      'stockDate': request.stockDate.asUtcMidnight(),
      // ★★ **والسببُ حقلُ المستند نفسِه** — `data-dictionary.md` §`disposals`.
      if (disposal.reason case final String reason) 'reason': reason,
      'lines': <Object?>[
        for (final ValidatedDisposalLine line in disposal.lines)
          <String, Object?>{
            'itemId': line.itemId,
            'itemName': line.itemName,
            'unit': line.quantity.unit.name,
            'quantity': disposalQuantityValue(line.quantity),
            if (line.sackId case final String sackId) 'sackId': sackId,
            // ⛔⛔★★★ **ولا حقلَ ماليٍّ في السطر** — `FR-M8-16`.
          },
      ],
      // ⛔ **إجماليان منفصلان دائماً للكميات** — `GR-19` · `E-31`.
      'totalPieces': disposal.totalPieces.pieces,
      'totalWeight': DecimalValue(disposal.totalWeight.kilograms),
      // ★ **عددُ الحركات المخزنية** — ⟵ **وبه يُعرَف ما يجب وسمُه عند
      //   الإلغاء بلا استعلامٍ داخل معاملة.**
      'lineCount': disposal.lines.length,
      documentStatusField: DisposalStatus.approved.name,
      // ⛔⛔★★★ **ولا `grandTotal` ولا `totalValue` ولا حقلَ مقوت.**
    };

InventoryWrite _documentWrite(
  DisposalRequest request,
  DisposalOperation operation,
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
    collectionId: disposalsCollection,
    // ★ **ورقم المستند هو معرّفه**.
    documentId: request.documentNumber,
    fields: fields,
    updateMask: fields.keys.toList(),
    serverTimestampFields: operation.isCreate
        ? const <String>['createdAt', 'entryDate']
        : const <String>['lastAmendedAt'],
  );
}

// ═════════════════════════════════════════════════════════════════════════
// بوابات مشتركة
// ═════════════════════════════════════════════════════════════════════════

/// ★ يفحص أن المستند موجود عند التعديل وغائب عند الإنشاء.
DisposalRejected? _existenceGate(
  DisposalRequest request,
  DisposalOperation operation,
) {
  final Map<String, Object?>? stored = request.storedDocument;
  if (operation.isCreate) {
    // ★ **ورقمٌ مخصَّصٌ للتوّ لا يقابله مستند** — ⟵ **ووجودُه تصادمُ عدّاد.**
    return stored == null
        ? null
        : const DisposalRejected(CallableError.concurrency);
  }
  if (stored == null) {
    return const DisposalRejected(CallableError.invalidArgument);
  }
  // ★★★ **والمخزَّن هو الحَكَم لا المُرسَل** — `GR-23`.
  if (stored['sourceId'] != request.sourceId) {
    return const DisposalRejected(CallableError.sourceOutOfScope);
  }
  // ★★ **والملغى لا يُعدَّل ولا يُلغى ثانيةً** — `ERR_AMEND_006` · `A-14`.
  if (stored[documentStatusField] == DisposalStatus.cancelled.name) {
    return const DisposalRejected(CallableError.documentCancelled);
  }
  return null;
}

/// ★ يفحص المصدر — **موجودٌ ونشط**.
///
/// ⚠️ **والإلغاء مسموح على مصدرٍ عُطِّل** — ⟵ **فالتعطيل لا يحبس مستنداً
/// خاطئاً داخل النظام**؛ ⛔ **والمنع على الجديد وتعديله** (`FR-M2-05`).
DisposalRejected? _sourceGate(
  DisposalRequest request,
  DisposalOperation operation,
) {
  final Map<String, Object?>? source = request.storedSource;
  // ⛔ **سجلٌّ لم يُقرأ ⟵ رفض** — الرفض الافتراضي.
  if (source == null) {
    return const DisposalRejected(CallableError.internal);
  }
  if (operation.isCancel) return null;
  if (source['isActive'] == false) {
    return const DisposalRejected(CallableError.sourceInactive);
  }
  return null;
}

/// ★★★ **حارسُ تاريخ المخزون** — ⛔ **ولا حارسَ ثانٍ يُخترَع هنا:**
/// ⟵ **[agedClearanceRejection] نفسُها التي تحرس التوزيعَ والبيعَ النقدي**
/// (`FR-M8-11`: **الإتلافُ ثالثُ الإجراءات الثلاثة**).
///
/// ⚠️ **ولا يُفحَص في الإلغاء** — ★ **فالإلغاءُ لا يُغيِّر تاريخاً**:
/// ⟵ **ومستندٌ بتاريخٍ سابقٍ صحيحٍ كان سيستحيل إلغاؤه بعد اليوم**، ⛔ **فيبقى
/// خصمُه حيّاً في رصيد ذلك اليوم أبداً.**
DisposalRejected? _dateGate(
  DisposalRequest request,
  DisposalOperation operation,
) {
  if (operation.isCancel) return null;
  // ⛔ **و«غيرُ معلوم» لا حُكمَ له** — راجع [DisposalRequest.serverDay].
  if (request.serverDay case final CalendarDay serverDay) {
    final CallableError? rejection = agedClearanceRejection(
      actor: request.actor,
      stockDate: request.stockDate,
      serverDay: serverDay,
    );
    if (rejection != null) return DisposalRejected(rejection);
  }
  return null;
}

/// ★ يُترجم خطأ النطاق إلى رمز الكتالوج **بحسب الفعل المطلوب**.
CallableError _mapStockError(AppError error, DisposalOperation operation) =>
    switch (error) {
      InsufficientStockError()
          when operation == DisposalOperation.amendDisposal =>
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
  required DisposalRequest request,
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
        entityType: disposalEntityType,
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

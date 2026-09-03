/// المخزون — **التخطيط الخالص** لعمليات `WU-003` (`M6` · `M8`).
///
/// ★ **مفصول عن الشبكة بنفس منطق `master_data.dart`:** `ADR-0013` القاعدة 3
/// تجعل **فحص التفويض في الكود** هو الحارس الوحيد لهذا المسار، فالدالة تعمل
/// بامتياز إداري يتجاوز قواعد الحماية. ★ **وحارسٌ لا يُختبَر بلا سحابة
/// حارسٌ غير مُختبَر** — فكل قرار هنا **دالة خالصة**.
///
/// ★ **وكل معادلة من طبقة النطاق لا من هنا** (`qtms_domain`) —
/// ⛔ **ولا تُعاد كتابتها** (`coding-standards.md` §2.2).
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔★★ **سبعة قيود كانت قواعدَ حماية قبل `WU-026`، وصارت بند قبولٍ هنا**
/// (`DEBT-21` ① · التحذير المكتوب في `firestore.rules` §12):
///
///   ① **الصلاحية** (`incomingCountWrite` / `Amend` / `Cancel`).
///   ② ★★ **نطاق المصادر** — `inScope(sourceId)`: ⛔ **قيدٌ يعلو على كل
///      صلاحية** (`GR-23`)، ★ **وإسقاطه يفتح مخزن مصدرٍ لمن لا يراه أصلاً.**
///   ③ **تاريخ المخزون = تاريخ اليوم من الخادم** (`todayStockDate()` سابقاً)
///      — `FR-M6-02` · `BR-M6-02` · `A-10` · `GR-14`.
///   ④ **وقت الخادم في `createdAt` و`entryDate`** (`serverTime()` سابقاً).
///   ⑤ **السبب النصي غير الفارغ لكل تعديل وإلغاء** (`nonEmpty()` سابقاً).
///   ⑥ ★★ **منع الرصيد السالب** (`FR-M8-01` · `GR-11`) — ★ **مقيساً من
///      الدفتر داخل المعاملة** ⛔ **لا من الملخص ولا من الجهاز.**
///   ⑦ **الحذف مرفوض نهائياً** — ⟵ **ولا مسار حذف في هذا الملف أصلاً.**
/// ═══════════════════════════════════════════════════════════════════════
library;

import 'package:qtms_domain/qtms_domain.dart';

import 'callable.dart';
import 'identity_gateway.dart';

/// حقل حالة المستند.
const String documentStatusField = 'status';

/// نوع عملية مخزنية — ويحدد الصلاحية التي لا تُنفَّذ بدونها.
enum InventoryOperation {
  /// `createCountedIntake` — يشترط `incomingCountWrite` (`FR-M6-01`).
  createCountedIntake(Permission.incomingCountWrite, isCreate: true),

  /// `amendCountedIntake` — يشترط `incomingCountAmend` ★ **وسبباً نصياً**
  /// (`FR-M6-11` · `ADR-0004`).
  amendCountedIntake(Permission.incomingCountAmend, isCreate: false),

  /// `cancelCountedIntake` — يشترط `incomingCountCancel` ★ **وسبباً نصياً**
  /// (`FR-M6-13`).
  ///
  /// ⛔★★ **وليس حذفاً:** الإلغاء **وسمٌ يُستبعَد من الجمع** (`GR-06` ·
  /// `A-14`)، ★ **والحركات تبقى في الدفتر مقروءةً مشطوبة.**
  cancelCountedIntake(
    Permission.incomingCountCancel,
    isCreate: false,
    isCancel: true,
  );

  const InventoryOperation(
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

/// كتابة مستند واحدة ضمن الخطة — **بلا أي تبعية شبكة**.
final class InventoryWrite {
  /// ينشئ الكتابة.
  const InventoryWrite({
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

  /// ★ حقول **وقت الخادم** — ⛔ ولا تدخل [fields] ولا [updateMask].
  final List<String> serverTimestampFields;
}

/// حركة دفترية قائمة كما قُرئت — **بمعرّفها** ليُميَّز صاحبها.
final class LedgerRead {
  /// ينشئ القراءة.
  const LedgerRead({required this.movementId, required this.movement});

  /// معرّف مستند الحركة.
  final String movementId;

  /// الحركة كما تدخل الجمع.
  final StockMovement movement;
}

/// ★ سجل نوعٍ كما قُرئ — **لفحص انتمائه للمصدر ووحدته وحالته**.
final class ItemRead {
  /// ينشئ القراءة.
  const ItemRead({
    required this.itemId,
    required this.name,
    required this.unit,
    required this.isActive,
    required this.sourceIds,
  });

  /// معرّفه.
  final String itemId;

  /// اسمه **كما هو مخزَّن الآن** — ★ **ويُنسَخ في الحركة وقت الكتابة**.
  final String name;

  /// وحدته — 🔒 **جزءٌ من هويته** (`FR-M5-03`).
  final ItemUnit unit;

  /// حالته.
  final bool isActive;

  /// مصادره — `FR-M5-10`.
  final List<String> sourceIds;
}

/// نتيجة التخطيط — إما خطة كتابة وإما رفض مصنَّف.
sealed class InventoryPlan {
  /// ينشئ النتيجة.
  const InventoryPlan();
}

/// رُفض الطلب قبل أي كتابة.
final class InventoryRejected extends InventoryPlan {
  /// ينشئ رفضاً.
  const InventoryRejected(this.error);

  /// رمز الرفض من كتالوج الأخطاء.
  final CallableError error;
}

/// قُبل الطلب — وهذه كتاباته وقيده.
final class InventoryAccepted extends InventoryPlan {
  /// ينشئ خطة مقبولة.
  const InventoryAccepted({
    required this.documentNumber,
    required this.writes,
    required this.entry,
  });

  /// رقم المستند.
  final String documentNumber;

  /// المستندات المكتوبة — ⛔ **ولا تكون فارغة**.
  final List<InventoryWrite> writes;

  /// قيد التدقيق — **يُكتب في المعاملة نفسها** (`ADR-0013` القاعدة 1).
  final AuditEntry entry;
}

/// طلب مخزني مُتحقَّق من هوية مُنفِّذه.
final class InventoryRequest {
  /// ينشئ الطلب.
  const InventoryRequest({
    required this.actor,
    required this.requestId,
    required this.sourceId,
    required this.documentNumber,
    required this.stockDate,
    this.intake,
    this.storedSource,
    this.storedDocument,
    this.items = const <String, ItemRead>{},
    this.ledger = const <String, List<LedgerRead>>{},
    this.storedSupplierSourceIds,
    this.storedSupplierName,
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

  /// ★★ **تاريخ المخزون** — ⛔ **من زمن المنصّة داخل المعاملة** لا من الجهاز
  /// ولا من ساعة الحاوية (`FR-M6-02` · `GR-54` · `E-41`).
  final CalendarDay stockDate;

  /// المستند المُتحقَّق منه — `null` للإلغاء.
  final ValidatedCountedIntake? intake;

  /// سجل المصدر كما قُرئ — ⛔ **و`null` رفضٌ لا تجاوز**.
  final Map<String, Object?>? storedSource;

  /// المستند القائم — `null` تعني **غيابه**.
  final Map<String, Object?>? storedDocument;

  /// سجلات الأنواع المطلوبة بمعرّفاتها.
  final Map<String, ItemRead> items;

  /// ★★ **حركات الدفتر لكل نوع** — **مقروءةً داخل المعاملة** (`ADR-0008`).
  final Map<String, List<LedgerRead>> ledger;

  /// مصادر الرعوي المُرسَل — `null` تعني **لا رعوي في الطلب**.
  final List<String>? storedSupplierSourceIds;

  /// ★ اسم الرعوي كما هو مخزَّن — **للنسخة في المستند**
  /// (`naming-conventions.md` §4: الأسماء المكرَّرة عمداً).
  final String? storedSupplierName;

  /// ★ سبب التعديل أو الإلغاء — **إلزامي لكليهما** (`ADR-0004` · `FR-M6-13`).
  final String? reason;

  /// وصف الجهاز للسجل — ⛔ بلا بيانات حساسة.
  final String? deviceInfo;
}

/// ★★ فحوص الحالة والصلاحية والنطاق — **تُستدعى قبل فتح المعاملة**.
///
/// ⚠️ **ولماذا مُصدَّرة:** كل عملية هنا تحتاج **قراءةً داخل معاملة** قبل أن
/// يكتمل تخطيطها، ⟵ **وفتحُ معاملةٍ لطلبٍ يرفضه نقصُ الصلاحية هدرٌ وقفلٌ
/// بلا داعٍ**. ★ **والفحص يُعاد كاملاً** في [planInventory] ⛔ **فلا مسار
/// يتخطّاه.**
InventoryRejected? inventoryGate(
  InventoryRequest request,
  InventoryOperation operation,
) {
  // ① «التعطيل فوري ونافذ» — `authentication-policy.md` §2 القاعدة 3.
  if (request.actor.disabled) {
    return const InventoryRejected(CallableError.accountDisabled);
  }
  // ② الصلاحية — ⛔ ولا قاعدة حماية تحرس هذا المسار.
  if (!request.actor.claims.has(operation.requiredPermission)) {
    return const InventoryRejected(CallableError.permissionMissing);
  }
  // ③ ★★ **النطاق — قيدٌ يعلو على الصلاحية** (`GR-23` · `FR-M6` §3).
  //    ⛔ **والغياب منعٌ لا سماح** (`canAccessSource` يُرجِع `false`).
  if (!request.actor.claims.canAccessSource(request.sourceId)) {
    return const InventoryRejected(CallableError.sourceOutOfScope);
  }
  // ④ معرّف الطلب إلزامي — وبدونه لا تتحقق اللاتكرارية عند إعادة الإرسال.
  if (request.requestId.trim().isEmpty) {
    return const InventoryRejected(CallableError.invalidArgument);
  }
  return null;
}

/// يخطّط عملية مخزنية — **دالة خالصة، وهي حارس التفويض الفعلي**.
InventoryPlan planInventory(
  InventoryRequest request,
  InventoryOperation operation,
) {
  final InventoryRejected? gate = inventoryGate(request, operation);
  if (gate != null) return gate;

  if (request.documentNumber.trim().isEmpty) {
    return const InventoryRejected(CallableError.invalidArgument);
  }

  // ⛔⛔★★★ **حارسُ السبب حُذف بـ`ADR-0020` (2026-08-27)** — ★ **السبب
  //    اختياريٌّ في كل عملية**، ⟵ **ولا رفضَ لغيابه.** ⛔ **ولا يُعبَّأ
  //    آلياً:** ★ **ما لم يكتبه إنسانٌ لا يُخزَّن.**
  final String? reason = _trimmed(request.reason);
  final InventoryRejected? existence = _existenceGate(request, operation);
  if (existence != null) return existence;

  final InventoryRejected? source = _sourceGate(request, operation);
  if (source != null) return source;

  return operation.isCancel
      ? _planCancellation(request, reason)
      : _planIntake(request, operation, reason);
}

// ═════════════════════════════════════════════════════════════════════════
// إنشاء وتعديل
// ═════════════════════════════════════════════════════════════════════════

InventoryPlan _planIntake(
  InventoryRequest request,
  InventoryOperation operation,
  String? reason,
) {
  final ValidatedCountedIntake? intake = request.intake;
  if (intake == null || intake.sourceId != request.sourceId) {
    return const InventoryRejected(CallableError.invalidArgument);
  }

  final InventoryRejected? supplier = _supplierGate(request, intake);
  if (supplier != null) return supplier;

  // ★ الأنواع: **موجودة · نشطة · مرتبطة بالمصدر · بوحدتها المخزَّنة**.
  for (final ValidatedCountedIntakeLine line in intake.lines) {
    final ItemRead? item = request.items[line.itemKey];
    if (item == null || !item.isActive) {
      return const InventoryRejected(CallableError.invalidArgument);
    }
    // ★★ `FR-M6-05` · `BR-M6-04`: «**قائمة الأنواع تُفلتَر بالمصدر المحدد
    //    حصراً**» — ⛔ **والواجهة تُخفي، وهذا السطر يمنع.**
    if (!item.sourceIds.contains(request.sourceId)) {
      return const InventoryRejected(CallableError.invalidArgument);
    }
    // ⛔ **ولا وحدة غير الحبّة** — راجع `validateCountedIntake` ⑤.
    if (item.unit != ItemUnit.piece) {
      return const InventoryRejected(CallableError.itemUnitLocked);
    }
  }

  // ★★ **كل نوعٍ يلمسه هذا المستند** — الجديد **والمحذوف من التعديل معاً**.
  final Map<String, StockQuantity> desired = <String, StockQuantity>{
    for (final ValidatedCountedIntakeLine line in intake.lines)
      line.itemKey: line.stockQuantity,
  };
  final Set<String> touched = <String>{
    ...desired.keys,
    ...request.ledger.keys,
  };

  final List<InventoryWrite> writes = <InventoryWrite>[];
  for (final String itemKey in touched.toList()..sort()) {
    final Outcome<_ItemPlan> planned = _planItem(
      request: request,
      itemKey: itemKey,
      desired: desired[itemKey],
      isCreate: operation.isCreate,
      reason: reason,
    );
    if (planned case Failure<_ItemPlan>(:final AppError error)) {
      return InventoryRejected(_mapStockError(error, operation));
    }
    writes.addAll((planned as Success<_ItemPlan>).value.writes);
  }

  final Map<String, Object?> after = _documentFields(request, intake);
  writes.insert(0, _documentWrite(request, operation, after, reason));

  return InventoryAccepted(
    documentNumber: request.documentNumber,
    writes: writes,
    entry: _entry(
      request: request,
      action: operation.isCreate ? AuditAction.create : AuditAction.amend,
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
InventoryPlan _planCancellation(InventoryRequest request, String? reason) {
  final List<InventoryWrite> writes = <InventoryWrite>[];
  for (final String itemKey in request.ledger.keys.toList()..sort()) {
    final Outcome<_ItemPlan> planned = _planItem(
      request: request,
      itemKey: itemKey,
      // ⛔ **لا كمية باقية** — كل حركات المستند تُوسَم ملغاة.
      desired: null,
      isCreate: false,
      reason: reason,
      cancelOwn: true,
    );
    if (planned case Failure<_ItemPlan>(:final AppError error)) {
      return InventoryRejected(
        _mapStockError(error, InventoryOperation.cancelCountedIntake),
      );
    }
    writes.addAll((planned as Success<_ItemPlan>).value.writes);
  }

  final Map<String, Object?> fields = <String, Object?>{
    documentStatusField: CountedIntakeStatus.cancelled.name,
    'cancelReason': reason,
    'cancelledBy': request.actor.userId,
  };
  writes.insert(
    0,
    InventoryWrite(
      collectionId: incomingCountCollection,
      documentId: request.documentNumber,
      fields: fields,
      // ★ **قناعٌ ضيّق** — ⛔ **فلا يمحو الإلغاءُ سطوراً ولا تاريخ مخزون.**
      updateMask: fields.keys.toList(),
      serverTimestampFields: const <String>['cancelledAt'],
    ),
  );

  return InventoryAccepted(
    documentNumber: request.documentNumber,
    writes: writes,
    entry: _entry(
      request: request,
      // ★ **الإلغاء فعلٌ مستقل في المعجم لا «تعديل»** — فيُقرأ من السجل بذاته.
      action: AuditAction.cancel,
      reason: reason,
      valuesBefore: <String, Object?>{
        documentStatusField:
            request.storedDocument?[documentStatusField] ??
                CountedIntakeStatus.approved.name,
      },
      valuesAfter: <String, Object?>{
        documentStatusField: CountedIntakeStatus.cancelled.name,
      },
    ),
  );
}

// ═════════════════════════════════════════════════════════════════════════
// نوعٌ واحد: حركته ورصيده
// ═════════════════════════════════════════════════════════════════════════

/// خطة نوعٍ واحد — حركته وسجل رصيده.
final class _ItemPlan {
  const _ItemPlan(this.writes);

  final List<InventoryWrite> writes;
}

/// ★★★ **جوهر الزيادة:** يبني حركة النوع **ويُعيد بناء رصيده من الدفتر**.
///
/// ⚠️⚠️ **والرصيد يُجمَع ⛔ لا يُراكَم على قيمةٍ سابقة** —
/// `coding-standards.md` §2.7: «**تُعيد البناء من الدفتر بالكامل ولا تُراكِم
/// على قيمة سابقة** … التشغيل المكرر مع التراكم يُنتج رقماً مضاعفاً بلا
/// إنذار». ⟵ ★ **فإعادة إرسال الطلب نفسه تُنتج الرقم نفسه.**
Outcome<_ItemPlan> _planItem({
  required InventoryRequest request,
  required String itemKey,
  required StockQuantity? desired,
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
  // ⛔ **نوعٌ لم يُقرأ ⟵ رفض** — الرفض الافتراضي: لا تُبنى وحدةٌ بالتخمين.
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
      direction: MovementDirection.incoming,
      quantity: quantity,
      isCancelled: isCancelled,
    ),
  ];

  final Outcome<ItemDailyFlow> flow =
      computeItemDailyFlow(movements: projected, unit: unit);
  if (flow case Failure<ItemDailyFlow>(:final AppError error)) {
    return Failure<_ItemPlan>(error);
  }
  final ItemDailyFlow computed = (flow as Success<ItemDailyFlow>).value;

  // ⑥ ★★ **منع الرصيد السالب** — `FR-M8-01` · `FR-M6-12` · `FR-M6-13`.
  final Outcome<void> allowed =
      validateStockChangeKeepsBalance(computed.balance);
  if (allowed case Failure<void>(:final AppError error)) {
    return Failure<_ItemPlan>(error);
  }

  return Success<_ItemPlan>(
    _ItemPlan(<InventoryWrite>[
      _movementWrite(
        request: request,
        movementId: movementId,
        itemKey: itemKey,
        itemName: item?.name ?? itemKey,
        unit: unit,
        quantity: quantity,
        balanceAfter: computed.balance,
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
    ]),
  );
}

/// كمية الحركة القائمة — ★ **تُستعمل عند الإلغاء وحده** (لا كمية جديدة).
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
  required InventoryRequest request,
  required String movementId,
  required String itemKey,
  required String itemName,
  required ItemUnit unit,
  required StockQuantity quantity,
  required StockQuantity balanceAfter,
  required bool isCancelled,
  required bool isCreate,
  required String? reason,
}) {
  final Map<String, Object?> fields = <String, Object?>{
    'sourceId': request.sourceId,
    // ★ **تاريخ المخزون** — ⛔ **وعليه وحده تُبنى الاستعلامات** (`RISK-07`).
    'stockDate': request.stockDate.asUtcMidnight(),
    'itemKey': itemKey,
    'itemName': itemName,
    'unit': unit.name,
    'direction': MovementDirection.incoming.name,
    'quantity': _quantityValue(quantity),
    'balanceAfter': _quantityValue(balanceAfter),
    'sourceDocType': SourceDocumentType.countedIntake.name,
    'sourceDocId': request.documentNumber,
    'sourceDocNumber': request.documentNumber,
    'movementTag': MovementTag.normal.name,
    'isCancelled': isCancelled,
    // ⛔★★ **ولا `sackId` إطلاقاً** — `FR-M6-09` · `BR-M6-10`: ⟵ **فلا تدخل
    //    هذه الحركة احتساب سعر أي جونية.**
    if (!isCreate) 'amendedBy': request.actor.userId,
    if (!isCreate) 'amendReason': reason,
  };
  return InventoryWrite(
    collectionId: inventoryLedgerCollection,
    documentId: movementId,
    fields: fields,
    updateMask: fields.keys.toList(),
    // ④ ⛅ **وقت المنصّة** — `entryDate` عند الإنشاء، و`lastAmendedAt` بعده.
    serverTimestampFields:
        isCreate ? const <String>['entryDate'] : const <String>['lastAmendedAt'],
  );
}

InventoryWrite _balanceWrite({
  required InventoryRequest request,
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

/// ★ قيمة الكمية كما تُكتب — **عدد صحيح للحبّة**.
///
/// ⛔★★ **والوزن يرمي عمداً ولا يُكتب:** مُرمِّز القاعدة **يرفض الفاصلة
/// العائمة** حتى يُحسَم تمثيلُها بقرار موثَّق (`firestore_value.dart`
/// · `ADR-0015` القاعدة 9)، ★ **وأول دفترٍ يكتب وزناً هو الجونية في `WU-004`**.
/// ⟵ **ومسارُ `WU-003` لا يبلغه أصلاً**: `validateCountedIntake` ⑤ يرفض
/// الكيلوجرام، ★ **والرمي هنا حارسٌ لو انفتح المسار غداً بلا قرار.**
Object _quantityValue(StockQuantity quantity) => switch (quantity) {
      PieceQuantity(:final PieceCount count) => count.pieces,
      WeightQuantity() => throw ArgumentError.value(
          quantity,
          'quantity',
          'تمثيل الوزن في القاعدة يحتاج قراراً موثَّقاً — ADR-0015 القاعدة 9',
        ),
    };

// ═════════════════════════════════════════════════════════════════════════
// المستند وحقوله
// ═════════════════════════════════════════════════════════════════════════

Map<String, Object?> _documentFields(
  InventoryRequest request,
  ValidatedCountedIntake intake,
) =>
    <String, Object?>{
      'documentNumber': request.documentNumber,
      'sourceId': intake.sourceId,
      // ★ **الأسماء المكرَّرة عمداً** — `naming-conventions.md` §4 (لاحقة
      //   `Name`) · `data-dictionary.md` §2. ⟵ **فالمستند يُقرأ ويُطبَع بلا
      //   قراءةٍ ثانية**، ★ **والنسخة لحظةَ الكتابة لا تتغيّر بتغيّر الاسم
      //   لاحقاً** — وهو المقصود: **المستند يشهد بما كان وقت إنشائه.**
      if (_nameOf(request.storedSource) case final String sourceName)
        'sourceName': sourceName,
      // ③ ★★ **تاريخ المخزون من الخادم** — `FR-M6-02` · `BR-M6-02`.
      'stockDate': request.stockDate.asUtcMidnight(),
      // ★ **الرعوي يُخزَّن فقط إن اشترطه المصدر** (`FR-M6-03`) — ⟵ **والغائب
      //   لا يُكتب مفتاحاً بقيمة فارغة**: المفتاح الفارغ نيّةٌ لا غياب.
      if (intake.supplierId case final String supplierId)
        'supplierId': supplierId,
      if (intake.supplierId != null)
        if (request.storedSupplierName case final String supplierName)
          'supplierName': supplierName,
      if (intake.notes case final String notes) 'notes': notes,
      'lines': <Object?>[
        for (final ValidatedCountedIntakeLine line in intake.lines)
          // ★ **بحقول `data-dictionary.md` §`incoming_count` حرفياً** —
          //   ⛔ **ولا حقل زائد**: `itemKey` في الدفتر **هو `itemId` نفسه**
          //   في هذه الوحدة (`FR-M6-09`)، ⟵ **وتكرارُه هنا مصدرُ حقيقةٍ ثانٍ.**
          <String, Object?>{
            'itemId': line.itemId,
            'itemName': line.itemName,
            'unit': ItemUnit.piece.name,
            'quantity': line.quantity.pieces,
            if (line.note case final String note) 'note': note,
          },
      ],
      'totalQuantity': intake.totalQuantity.pieces,
      documentStatusField: CountedIntakeStatus.approved.name,
      // ⛔★★ **ولا حقل وزنٍ ولا ضريبةٍ ولا سعر** — `FR-M6-10`.
    };

InventoryWrite _documentWrite(
  InventoryRequest request,
  InventoryOperation operation,
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
    collectionId: incomingCountCollection,
    documentId: request.documentNumber,
    fields: fields,
    updateMask: fields.keys.toList(),
    serverTimestampFields: operation.isCreate
        ? const <String>['createdAt', 'entryDate']
        : const <String>['lastAmendedAt'],
  );
}

int _amendCount(Map<String, Object?>? stored) {
  final Object? raw = stored?['amendCount'];
  if (raw is int) return raw;
  if (raw is double && raw == raw.roundToDouble()) return raw.toInt();
  return 0;
}

// ═════════════════════════════════════════════════════════════════════════
// بوابات مشتركة
// ═════════════════════════════════════════════════════════════════════════

/// ★ يفحص أن المستند موجود عند التعديل وغائب عند الإنشاء.
InventoryRejected? _existenceGate(
  InventoryRequest request,
  InventoryOperation operation,
) {
  final Map<String, Object?>? stored = request.storedDocument;
  if (operation.isCreate) {
    // ⛔ **إنشاءٌ فوق قائم يمحو مستنداً حياً** — وهو أخطر ما يفعله كودٌ محاسبي.
    return stored == null
        ? null
        : const InventoryRejected(CallableError.invalidArgument);
  }
  if (stored == null) {
    return const InventoryRejected(CallableError.invalidArgument);
  }
  // ★★★ **والمصدر المخزَّن هو الحَكَم لا المُرسَل** — ⟵ **وإلا أمكن فحصُ
  //   النطاق على مصدرٍ ثم العملُ على مستند مصدرٍ آخر**، ⛔ **وهو تصعيدُ
  //   امتيازٍ صامت** (`GR-23`).
  if (stored['sourceId'] != request.sourceId) {
    return const InventoryRejected(CallableError.sourceOutOfScope);
  }
  // ★★★ **وتاريخ المخزون المخزَّن هو الحَكَم** — ⟵ **فيومٌ مقروءٌ من رقم
  //   المستند يُقابَل بما في المستند نفسه**، ⛔ **ورصيدٌ جُمع ليومٍ آخر
  //   يُنتج ملخصاً كاذباً بصمت** (`RISK-07`).
  if (stored['stockDate'] != request.stockDate.asUtcMidnight()) {
    return const InventoryRejected(CallableError.invalidArgument);
  }
  // ★★ **والملغى لا يُعدَّل ولا يُلغى ثانيةً** — `ERR_AMEND_006`.
  final Outcome<void> live = validateNotCancelled(
    stored[documentStatusField] == CountedIntakeStatus.cancelled.name
        ? CountedIntakeStatus.cancelled
        : CountedIntakeStatus.approved,
  );
  return live is Failure<void>
      ? const InventoryRejected(CallableError.documentCancelled)
      : null;
}

/// ★ يفحص سجل المصدر — **موجودٌ ونشط** (`ERR_DIST_003`).
InventoryRejected? _sourceGate(
  InventoryRequest request,
  InventoryOperation operation,
) {
  final Map<String, Object?>? source = request.storedSource;
  // ⛔ **مصدرٌ لم يُقرأ ⟵ رفض** — الرفض الافتراضي.
  if (source == null) {
    return const InventoryRejected(CallableError.internal);
  }
  // ★ **والإلغاء مسموح على مصدرٍ عُطِّل** — ⟵ **فتعطيلُ مصدرٍ لا يحبس
  //   مستنداته الخاطئة داخله**؛ ⛔ **والمنع على التوريد الجديد وحده.**
  if (!operation.isCancel && source['isActive'] == false) {
    return const InventoryRejected(CallableError.sourceInactive);
  }
  return null;
}

/// ★ يفحص الرعوي — **مرتبطٌ بالمصدر** (`FR-M3-09`).
InventoryRejected? _supplierGate(
  InventoryRequest request,
  ValidatedCountedIntake intake,
) {
  if (intake.supplierId == null) return null;
  final List<String>? sources = request.storedSupplierSourceIds;
  // ⛔ **رعويٌّ لم يُقرأ أو لا ينتمي للمصدر ⟵ رفض** — `FR-M3-09`:
  //    «**لا يظهر في مصدر ليس ضمن مصادره**».
  if (sources == null || !sources.contains(request.sourceId)) {
    return const InventoryRejected(CallableError.supplierRequired);
  }
  return null;
}

/// ★ يُترجم خطأ النطاق إلى رمز الكتالوج **بحسب الفعل المطلوب**.
///
/// ⚠️ **والتمييز عملي لا شكلي:** التخفيض يُبلَّغ بـ`ERR_AMEND_003` («لا يمكن
/// تخفيض الكمية — الفرق غير متاح») والإلغاء بـ`ERR_STOCK_001` («الكمية غير
/// كافية») — ⟵ **فيقرأ المستخدم سبب منعه لا رمزاً جامعاً.**
CallableError _mapStockError(AppError error, InventoryOperation operation) =>
    switch (error) {
      InsufficientStockError() when operation == InventoryOperation.amendCountedIntake =>
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
  // ★ **والعدد الصحيح يساوي نظيره العشري** — القاعدة تُرجِع `1` و`1.0` لنفس
  //   القيمة، ⛔ **وقراءة ذلك «تغييراً» ضجيجٌ في السجل.**
  if (a is num && b is num) return a == b;
  return a == b;
}

AuditEntry _entry({
  required InventoryRequest request,
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
        entityType: countedIntakeEntityType,
        entityId: request.documentNumber,
        // ★ **المصدر في القيد** — ⟵ **فيُفلتَر السجل بالنطاق** (`FR-M18-14`).
        sourceId: request.sourceId,
      ),
      valuesBefore: valuesBefore,
      valuesAfter: valuesAfter,
      deviceInfo: request.deviceInfo,
    );

/// ★ اسم المستند المقروء أو `null` — ⛔ **والفارغ غيابٌ لا نصٌّ فارغ**.
String? _nameOf(Map<String, Object?>? stored) {
  final Object? name = stored?['name'];
  return (name is String && name.trim().isNotEmpty) ? name.trim() : null;
}

String? _trimmed(String? value) {
  final String? text = value?.trim();
  return (text == null || text.isEmpty) ? null : text;
}

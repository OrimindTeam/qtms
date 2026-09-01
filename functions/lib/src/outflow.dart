/// السحبيات والخرجيات — **التخطيط الخالص** لعمليات `WU-014` (`M22`).
///
/// ★ **مفصول عن الشبكة بنفس منطق `cash_sale.dart`:** `ADR-0013` القاعدة 3
/// تجعل **فحص التفويض في الكود** هو الحارس الوحيد لهذا المسار، فالدالة تعمل
/// بامتياز إداري يتجاوز قواعد الحماية. ★ **وحارسٌ لا يُختبَر بلا سحابة
/// حارسٌ غير مُختبَر** — فكل قرار هنا **دالة خالصة**.
///
/// ★ **وكل معادلة من طبقة النطاق لا من هنا** (`qtms_domain`) —
/// ⛔ **ولا تُعاد كتابتها** (`coding-standards.md` §2.2 · `ADR-0009`).
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔★★ **عشرةُ قيودٍ بندُ قبولٍ مُلزِم لهذه الدالة:**
///
///   ① ⛔⛔★★★ **الصلاحيةُ تتبع السجل ⛔ لا العملية وحدها** (`GR-43`) —
///      ★ **وهذا فارقُها البنيوي عن كل عملية أخرى في النظام**: ⟵ **مسارٌ
///      واحد ومفتاحان**، ★ **يختارهما [outflowPermission] من
///      [OutflowLedgerType]** ⛔ **لا من اسم العملية.**
///   ② ⛔⛔★★★ **والسجلُّ يُقرأ من المخزَّن في التعديل والإلغاء** — ⛔ **لا
///      من الحمولة**: ⟵ **وإلا لأمكن حاملَ `expenseAmend` أن يُرسل
///      `ledgerType: expense` فيُعدِّل **سحبيةً** لا يملك حتى رؤيتها**،
///      ★ **وهو تصعيدُ امتيازٍ صامت يُبطِل `GR-43` كلَّه.**
///   ③ ★★ **نطاق المصادر** — ⛔ **قيدٌ يعلو على كل صلاحية** (`GR-23`).
///   ④ ⛔⛔★★★ **والمصدر إلزاميٌّ دائماً** (`FR-M22-02` · `GR-42` · `E-28`)
///      — ★ **حتى لسحبيات المالك الشخصية**، ⟵ **ورمزُه `ERR_OUT_001`.**
///   ⑤ ★★ **تاريخُ السند يقبل السابق بمفتاحه ويرفض المستقبلي مطلقاً**
///      (`FR-M22-09` · `AT-56`) — ★ **والمفتاحُ يتبع السجل كذلك.**
///   ⑥ ⛔⛔★★★ **وتمييزٌ تاريخيٌّ لا يُخلَط** (`FR-M22-10` · `GR-49`):
///      **`documentDate` تاريخُ السند** · **`stockDate` تاريخُ المخزون** —
///      ⟵ **وحقلان مستقلان في كل حركةٍ وكل سطرِ دفتر.**
///   ⑦ ★★ **منع الرصيد السالب** (`FR-M22-12` · `GR-11`) — ★ **مقيساً من
///      الدفتر داخل المعاملة** ⛔ **لا من الملخص ولا من الجهاز.**
///   ⑧ ⛔⛔★★★ **ولا قيدَ واحدٌ في دفتر المقاوته** (`FR-M22-04` · `GR-44`) —
///      ★ **وهو أخطرُ ما يمكن أن يُكتَب هنا خطأً** (`outflow-design.md`
///      §10): ⟵ **لا `_dealerWrites` ولا `dealer_balances` ولا ضمار**،
///      ⛔ **ولا حقلَ مقوتٍ يعبر هذا الملف أصلاً.**
///   ⑨ ★★★ **والسعر اختياريٌّ** (`FR-M22-07`) — ⛔ **بخلاف البيع النقدي**:
///      ★ **والقاتُ يخرج مسعَّراً كان أو غيرَ مسعَّر** (`E-27`)، ⟵ **وبندُ
///      المركز المعلّق يُعلن النقص** (`FR-SYS-08`). ⛔⛔ **وإدخالُ السعر
///      *الآن* يشترط مفتاحَه** (`FR-M22-08` · `ERR_OUT_002`) — ★ **وغيابُه
///      لا يمنع الحفظ** ⛔ **بل يمنع الحقلَ وحده.**
///   ⑩ **الحذف مرفوض نهائياً** — ⟵ **ولا مسار حذف في هذا الملف أصلاً.**
/// ═══════════════════════════════════════════════════════════════════════
///
/// ⛔⛔★★ **ولا `pricing/current` هنا بخلاف التوزيعة** (`ADR-0011`) —
/// ★ **`ت-12` قاعدةُ التوزيع وحده**، ⟵ **والسعرُ في السند نفسِه**
/// (`schema/outflow-ledger.md`): ⛔ **وعزلُه كان سيُنشئ حارساً لا صلاحيةَ له.**
library;

import 'package:qtms_domain/qtms_domain.dart';

import 'callable.dart';
import 'firestore_value.dart' show DecimalValue;
import 'identity_gateway.dart';
import 'inventory.dart';

/// نوع عملية سحبيةٍ أو خرجية.
///
/// ⛔⛔★★★ **ولا مفتاحَ في هذا التعداد بخلاف `CashSaleOperation`** —
/// ★ **لأن المفتاح يتبع السجل لا العملية** (`GR-43`): ⟵ **راجع
/// [outflowPermission]**، ⛔ **وحقلُ `requiredPermission` هنا كان سيُجبِر
/// على قيمةٍ واحدة للسجلَّين** ★ **فيُسقِط الفصل الذي وُجدا لأجله.**
enum OutflowOperation {
  /// `createOutflow` — ينشئ سنداً (`FR-M22-01`).
  createOutflow(isCreate: true),

  /// `amendOutflow` — يعدّل سنداً معتمداً **بسببٍ نصّي اختياري**
  /// (`FR-M22-18` · `ADR-0020`).
  amendOutflow(isCreate: false),

  /// `cancelOutflow` — ★ **يَسِم السند وحركاته «ملغى»** ⛔ **وليس حذفاً**
  /// (`GR-06` · `GR-07` · `A-14`).
  cancelOutflow(isCreate: false, isCancel: true);

  const OutflowOperation({required this.isCreate, this.isCancel = false});

  /// هل هي إنشاء؟
  final bool isCreate;

  /// هل هي إلغاء؟
  final bool isCancel;
}

/// ★★★ **المفتاح المطلوب** — **من السجل والعملية معاً** (`GR-43`).
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **وهذه الدالةُ هي تنفيذُ `GR-43` نفسِه** — `FR-M22-03` ·
/// `outflow-design.md` §7: ★ **ثمانيةُ مفاتيح لمسارٍ واحد**، ⟵ **فمن يملك
/// «إضافة خرجية» لا يُنشئ سحبيةً ولا يُعدِّلها ولا يُلغيها.**
///
/// ★★ **وموضعٌ واحد لهذا الاختيار** ⛔ **لا شرطٌ في كل معالج** —
/// `coding-standards.md` §2.2: ⟵ **وشرطان متطابقان في موضعين يفترقان عند
/// أول مفتاحٍ جديد**، ★ **وهنا الافتراقُ يعني تسريبَ بياناتٍ حسّاسة.**
/// ═══════════════════════════════════════════════════════════════════════
Permission outflowPermission({
  required OutflowLedgerType ledgerType,
  required OutflowOperation operation,
}) =>
    switch ((ledgerType, operation)) {
      (OutflowLedgerType.withdrawal, OutflowOperation.createOutflow) =>
        Permission.withdrawalCreate,
      (OutflowLedgerType.withdrawal, OutflowOperation.amendOutflow) =>
        Permission.withdrawalAmend,
      (OutflowLedgerType.withdrawal, OutflowOperation.cancelOutflow) =>
        Permission.withdrawalCancel,
      (OutflowLedgerType.expense, OutflowOperation.createOutflow) =>
        Permission.expenseCreate,
      (OutflowLedgerType.expense, OutflowOperation.amendOutflow) =>
        Permission.expenseAmend,
      (OutflowLedgerType.expense, OutflowOperation.cancelOutflow) =>
        Permission.expenseCancel,
    };

/// ★★ **مفتاحُ تسعير القات الآن** — `FR-M22-08` · `ERR_OUT_002`.
Permission outflowPricingPermission(OutflowLedgerType ledgerType) =>
    switch (ledgerType) {
      OutflowLedgerType.withdrawal => Permission.withdrawalQatPriceNow,
      OutflowLedgerType.expense => Permission.expenseQatPriceNow,
    };

/// ★★ **مفتاحُ التاريخ السابق** — `FR-M22-09` · `AT-56`.
Permission outflowBackdatePermission(OutflowLedgerType ledgerType) =>
    switch (ledgerType) {
      OutflowLedgerType.withdrawal => Permission.withdrawalBackdate,
      OutflowLedgerType.expense => Permission.expenseBackdate,
    };

/// ★★ **نوعُ مستندِ الحركة المخزنية** — ⛔ **يُمرَّر ولا يُحفَر**.
///
/// ⚠️⚠️ **ودرسُ `sourceDocType` المحفور يبلغ ذروته هنا** (2026-08-26):
/// ⟵ **مسارُ الكود واحدٌ للسجلَّين**، ⛔ **فقيمةٌ محفورةٌ كانت ستَسِم كلَّ
/// خرجيةٍ «سحبيةً»** — ★ **وهو بالضبط العطلُ الذي وَسَمَ حركاتِ الجواني
/// «وارداً عدداً» حين صار للدفتر كاتبٌ ثانٍ.**
SourceDocumentType outflowSourceDocType(OutflowLedgerType ledgerType) =>
    switch (ledgerType) {
      OutflowLedgerType.withdrawal => SourceDocumentType.withdrawal,
      OutflowLedgerType.expense => SourceDocumentType.expense,
    };

/// ★★ **نوعُ الكيان في سجل التدقيق** — ⛔ **مستقلٌّ لكل سجل** (`GR-43`).
String outflowEntityType(OutflowLedgerType ledgerType) => switch (ledgerType) {
      OutflowLedgerType.withdrawal => withdrawalEntityType,
      OutflowLedgerType.expense => expenseEntityType,
    };

/// نتيجة التخطيط — إما خطة كتابة وإما رفض مصنَّف.
sealed class OutflowPlan {
  /// ينشئ النتيجة.
  const OutflowPlan();
}

/// رُفض الطلب قبل أي كتابة.
final class OutflowRejected extends OutflowPlan {
  /// ينشئ رفضاً.
  const OutflowRejected(this.error);

  /// رمز الرفض من كتالوج الأخطاء.
  final CallableError error;
}

/// قُبل الطلب — وهذه كتاباته وقيده.
final class OutflowAccepted extends OutflowPlan {
  /// ينشئ خطة مقبولة.
  const OutflowAccepted({
    required this.documentNumber,
    required this.ledgerType,
    required this.writes,
    required this.entry,
    required this.unpricedItemCount,
    required this.categoryLabel,
    required this.isCancelled,
  });

  /// رقم المستند — `WDR-…` أو `EXP-…` ★ **وهو معرّفه في المجموعة**.
  final String documentNumber;

  /// السجل — ★ **المُثبَت من المخزَّن في التعديل والإلغاء.**
  final OutflowLedgerType ledgerType;

  /// المستندات المكتوبة — ⛔ **ولا تكون فارغة**.
  final List<InventoryWrite> writes;

  /// قيد التدقيق — **يُكتب في المعاملة نفسها** (`ADR-0013` القاعدة 1).
  final AuditEntry entry;

  /// ★ عددُ بنود القات بلا سعر — ⟵ **مُدخَلُ بند المركز المعلّق.**
  final int unpricedItemCount;

  /// ★ اسمُ الفئة — ⟵ **عنوانُ بند المركز المعلّق** (`ui-guidelines.md` §6).
  final String categoryLabel;

  /// ★ هل السند ملغى بعد هذه العملية؟ — ⟵ **فيُخلى بندُه.**
  final bool isCancelled;
}

/// طلبُ سحبيةٍ أو خرجية مُتحقَّق من هوية مُنفِّذه.
final class OutflowRequest {
  /// ينشئ الطلب.
  const OutflowRequest({
    required this.actor,
    required this.requestId,
    required this.ledgerType,
    required this.sourceId,
    required this.documentNumber,
    required this.documentDate,
    required this.stockDate,
    required this.today,
    this.outflow,
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

  /// ★★★ **السجل كما ادّعته الحمولة** — ⛔ **والمخزَّن يعلوه في التعديل
  /// والإلغاء** (راجع القيد ② في ترويسة الملف).
  final OutflowLedgerType ledgerType;

  /// المصدر المستهدف.
  final String sourceId;

  /// رقم المستند — **المخصَّص عند الإنشاء والقائم عند التعديل**.
  final String documentNumber;

  /// ★★ **تاريخ السند** — **الأثر المالي** (`FR-M22-10` · `GR-49`).
  final CalendarDay documentDate;

  /// ★★ **تاريخ المخزون** — **الأثر المخزني لبنود القات** (`GR-49`).
  final CalendarDay stockDate;

  /// ★★ **يومُ المنصّة** — ⛔ **من `readTime` داخل المعاملة** لا من الجهاز.
  final CalendarDay today;

  /// المستند المُتحقَّق منه — `null` للإلغاء.
  final ValidatedOutflow? outflow;

  /// سجل المصدر كما قُرئ — ⛔ **و`null` رفضٌ لا تجاوز**.
  final Map<String, Object?>? storedSource;

  /// المستند القائم — `null` تعني **غيابه**.
  final Map<String, Object?>? storedDocument;

  /// سجلات الأنواع المطلوبة بمعرّفاتها.
  final Map<String, ItemRead> items;

  /// ★★ **حركات دفتر المخزون لكل نوع** — **مقروءةً داخل المعاملة**.
  final Map<String, List<LedgerRead>> ledger;

  /// ★ سبب التعديل أو الإلغاء — ⛔ **اختياريٌّ** (`ADR-0020`).
  final String? reason;

  /// وصف الجهاز للسجل — ⛔ بلا بيانات حساسة.
  final String? deviceInfo;
}

/// ★★ فحوص الحالة والصلاحية والنطاق — **تُستدعى قبل فتح المعاملة**.
///
/// ⚠️ **ولماذا مُصدَّرة:** ⟵ **فتحُ معاملةٍ لطلبٍ يرفضه نقصُ الصلاحية هدرٌ
/// وقفلٌ بلا داعٍ**. ★ **والفحص يُعاد كاملاً** في [planOutflow] ⛔ **فلا مسار
/// يتخطّاه.**
///
/// ⚠️⚠️★★★ **وهذا الفحصُ المسبق يعمل على السجل المُدَّعى في الحمولة** —
/// ⛔ **وهو *لا يكفي* للتعديل والإلغاء:** ★ **[planOutflow] يُعيده على السجل
/// **المخزَّن**** (`_existenceGate`)، ⟵ **فطلبٌ يدّعي «خرجية» على مستندِ
/// سحبيةٍ يمرّ من هنا ثم يُرفَض هناك** ⛔ **قبل أي كتابة.**
OutflowRejected? outflowGate(
  OutflowRequest request,
  OutflowOperation operation,
) {
  // ① «التعطيل فوري ونافذ» — `authentication-policy.md` §2 القاعدة 3.
  if (request.actor.disabled) {
    return const OutflowRejected(CallableError.accountDisabled);
  }
  // ② ★★★ **الصلاحية — من السجل والعملية معاً** (`GR-43`).
  if (!request.actor.claims.has(
    outflowPermission(
      ledgerType: request.ledgerType,
      operation: operation,
    ),
  )) {
    return const OutflowRejected(CallableError.permissionMissing);
  }
  // ③ ★★ **النطاق — قيدٌ يعلو على الصلاحية** (`GR-23`) — ⛔ **والغياب منعٌ.**
  if (!request.actor.claims.canAccessSource(request.sourceId)) {
    return const OutflowRejected(CallableError.sourceOutOfScope);
  }
  // ④ معرّف الطلب إلزامي — وبدونه لا تتحقق اللاتكرارية عند إعادة الإرسال.
  if (request.requestId.trim().isEmpty) {
    return const OutflowRejected(CallableError.invalidArgument);
  }
  return null;
}

/// يخطّط عملية سحبيةٍ أو خرجية — **دالة خالصة، وهي حارس التفويض الفعلي**.
OutflowPlan planOutflow(
  OutflowRequest request,
  OutflowOperation operation,
) {
  final OutflowRejected? gate = outflowGate(request, operation);
  if (gate != null) return gate;

  if (request.documentNumber.trim().isEmpty) {
    return const OutflowRejected(CallableError.invalidArgument);
  }
  // ④ ⛔⛔★★★ **المصدر إلزاميٌّ دائماً** — `GR-42` · `ERR_OUT_001`.
  if (request.sourceId.trim().isEmpty) {
    return const OutflowRejected(CallableError.outflowSourceMissing);
  }

  // ⛔⛔★★★ **ولا حارسَ للسبب** — `ADR-0020`.
  final String? reason = _trimmed(request.reason);

  final OutflowRejected? existence = _existenceGate(request, operation);
  if (existence != null) return existence;

  final OutflowRejected? source = _sourceGate(request, operation);
  if (source != null) return source;

  final OutflowRejected? date = _dateGate(request, operation);
  if (date != null) return date;

  return operation.isCancel
      ? _planCancellation(request, reason)
      : _planOutflow(request, operation, reason);
}

// ═════════════════════════════════════════════════════════════════════════
// الإنشاء والتعديل
// ═════════════════════════════════════════════════════════════════════════

OutflowPlan _planOutflow(
  OutflowRequest request,
  OutflowOperation operation,
  String? reason,
) {
  final ValidatedOutflow? outflow = request.outflow;
  if (outflow == null ||
      outflow.sourceId != request.sourceId ||
      outflow.ledgerType != request.ledgerType) {
    return const OutflowRejected(CallableError.invalidArgument);
  }

  // ⑨ ⛔⛔★★★ **إدخالُ السعر *الآن* يشترط مفتاحَه** — `FR-M22-08` ·
  //    `ERR_OUT_002`: ★ **والغيابُ لا يمنع الحفظ** ⛔ **بل الحقلَ وحده.**
  //    ⟵ **ويُفحَص على الإنشاء والتعديل معاً**: ⛔ **وإلا لأمكن حفظُ سندٍ
  //    بلا سعرٍ ثم تسعيرُه بتعديلٍ من غير مالك المفتاح** — ★ **وهو بابٌ
  //    خلفيٌّ للقاعدة كلِّها.**
  if (outflow.qatLines
          .any((ValidatedOutflowQatLine line) => line.unitPrice != null) &&
      !request.actor.claims
          .has(outflowPricingPermission(request.ledgerType))) {
    return const OutflowRejected(CallableError.outflowPricingNotAllowed);
  }

  // ★ الأنواع: **موجودة · نشطة · مرتبطة بالمصدر · بوحدتها المخزَّنة**.
  for (final ValidatedOutflowQatLine line in outflow.qatLines) {
    final ItemRead? item = request.items[line.itemKey];
    if (item == null || !item.isActive) {
      return const OutflowRejected(CallableError.invalidArgument);
    }
    // ★★ `FR-M5-10`: **النوع لا يظهر إلا في مصادره**.
    if (!item.sourceIds.contains(request.sourceId)) {
      return const OutflowRejected(CallableError.invalidArgument);
    }
    // ⛔ **ووحدة السطر = وحدة النوع المخزَّنة** — `FR-M5-03` · `GR-19`.
    if (line.quantity.unit != item.unit) {
      return const OutflowRejected(CallableError.itemUnitLocked);
    }
  }

  // ★★ **كل نوعٍ يلمسه هذا المستند** — الجديد **والمحذوف من التعديل معاً**.
  final Map<String, StockQuantity> desired = <String, StockQuantity>{
    for (final ValidatedOutflowQatLine line in outflow.qatLines)
      line.itemKey: line.quantity,
  };
  final Map<String, String?> sackIds = <String, String?>{
    for (final ValidatedOutflowQatLine line in outflow.qatLines)
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
      return OutflowRejected(_mapStockError(error, operation));
    }
    writes.addAll((planned as Success<List<InventoryWrite>>).value);
  }

  // ⑧ ⛔⛔★★★ **ولا كتابةَ واحدة في `dealer_ledger` ولا `dealer_balances`**
  //    — `FR-M22-04` · `GR-44`: ★ **والغياب هنا هو تنفيذُ المتطلب نفسِه**،
  //    ⛔ **لا سهوٌ يُستدرَك** (`outflow-design.md` §10).

  // ★★★ **سطرُ الدفتر الرابع** — `GR-04`: ⟵ **ولا يخرج قاتٌ ولا مالٌ خارج
  //    دورة البيع إلا بسطرٍ فيه.**
  writes.addAll(_ledgerWrites(request, outflow, operation, reason));

  final Map<String, Object?> after = _documentFields(request, outflow);
  writes.insert(0, _documentWrite(request, operation, after, reason));

  return OutflowAccepted(
    documentNumber: request.documentNumber,
    ledgerType: request.ledgerType,
    writes: writes,
    unpricedItemCount: outflow.unpricedItemCount,
    categoryLabel: outflow.category.label,
    isCancelled: false,
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

OutflowPlan _planCancellation(OutflowRequest request, String? reason) {
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
      return OutflowRejected(
        _mapStockError(error, OutflowOperation.cancelOutflow),
      );
    }
    writes.addAll((planned as Success<List<InventoryWrite>>).value);
  }

  // ★★ **وسطورُ الدفتر الرابع تُوسَم ملغاة كذلك** — ⛔ **ولا تُحذَف:**
  //    ⟵ **فتقريرُ المصدر يستبعدها بالوسم** (`FR-M22-16`)، ★ **وتبقى
  //    مقروءةً مشطوبة** (`A-14`).
  for (final String entryId in _storedLedgerEntryIds(request.storedDocument)) {
    final Map<String, Object?> fields = <String, Object?>{
      'isCancelled': true,
      'amendedBy': request.actor.userId,
      'amendReason': reason,
    };
    writes.add(
      InventoryWrite(
        collectionId: outflowLedgerCollection,
        documentId: entryId,
        fields: fields,
        updateMask: fields.keys.toList(),
        serverTimestampFields: const <String>['lastAmendedAt'],
      ),
    );
  }

  final Map<String, Object?> fields = <String, Object?>{
    documentStatusField: OutflowStatus.cancelled.name,
    'cancelReason': reason,
    'cancelledBy': request.actor.userId,
  };
  writes.insert(
    0,
    InventoryWrite(
      collectionId: outflowsCollection,
      documentId: request.documentNumber,
      fields: fields,
      // ★ **قناعٌ ضيّق** — ⛔ **فلا يمحو الإلغاءُ سطوراً ولا تاريخاً.**
      updateMask: fields.keys.toList(),
      serverTimestampFields: const <String>['cancelledAt'],
    ),
  );

  return OutflowAccepted(
    documentNumber: request.documentNumber,
    ledgerType: request.ledgerType,
    writes: writes,
    unpricedItemCount: 0,
    categoryLabel: _storedCategoryLabel(request.storedDocument),
    isCancelled: true,
    entry: _entry(
      request: request,
      // ★ **الإلغاء فعلٌ مستقل في المعجم لا «تعديل»**.
      action: AuditAction.cancel,
      reason: reason,
      valuesBefore: <String, Object?>{
        documentStatusField: request.storedDocument?[documentStatusField] ??
            OutflowStatus.approved.name,
      },
      valuesAfter: <String, Object?>{
        documentStatusField: OutflowStatus.cancelled.name,
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
///
/// ⚠️⚠️★★★ **ويقع كلُّه على [OutflowRequest.stockDate] ⛔ لا على تاريخ
/// السند** — `GR-49`: ⟵ **فالبضاعةُ تخرج من مخزون يومها.**
Outcome<List<InventoryWrite>> _planItem({
  required OutflowRequest request,
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
      // ⛔★★ **خروجٌ دائماً** — `FR-M22-06`.
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

  // ⑦ ★★ **منع الرصيد السالب** — `FR-M22-12` · `GR-11` · `E-01`.
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
  required OutflowRequest request,
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
    // ⑥ ★★★ **تاريخُ المخزون هنا** — ⛔ **لا تاريخُ السند** (`GR-49`).
    'stockDate': request.stockDate.asUtcMidnight(),
    'itemKey': itemKey,
    'itemName': itemName,
    'unit': unit.name,
    'direction': MovementDirection.outgoing.name,
    'quantity': _quantityValue(quantity),
    'balanceAfter': _quantityValue(balanceAfter),
    // ⚠️⚠️ **ويُمرَّر صراحةً ⛔ لا يُحفَر** — راجع [outflowSourceDocType].
    'sourceDocType': outflowSourceDocType(request.ledgerType).name,
    'sourceDocId': request.documentNumber,
    'sourceDocNumber': request.documentNumber,
    'movementTag': MovementTag.normal.name,
    'isCancelled': isCancelled,
    // ★★ **و`sackId` متى كان النوع من جونية** — `FR-M22-06` · `E-26`:
    //    ⟵ **وهو ما يُطلق إعادة احتساب سعرها فيستحق الرعوي ثمنها**،
    //    ⛔ **وغيابُه يُسقِطها بصمت.**
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
  required OutflowRequest request,
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

// ═════════════════════════════════════════════════════════════════════════
// ★★★ الدفتر الرابع — `GR-04` · `schema/outflow-ledger.md`
// ═════════════════════════════════════════════════════════════════════════

/// ★ معرّفُ سطرِ الدفتر — **حتميٌّ من رقم المستند وترتيب السطر**.
///
/// ⚠️⚠️ **والحتميةُ شرطُ التعديل بلا يتامى:** ⟵ **فالتعديل يكتب فوق سطورٍ
/// بنفس المعرّفات**، ★ **والزائدُ منها يُوسَم ملغى** ⛔ **لا يُترَك حيّاً.**
String outflowLedgerEntryId({
  required String documentNumber,
  required int index,
}) =>
    '${documentNumber}_${index.toString().padLeft(3, '0')}';

List<InventoryWrite> _ledgerWrites(
  OutflowRequest request,
  ValidatedOutflow outflow,
  OutflowOperation operation,
  String? reason,
) {
  final List<InventoryWrite> writes = <InventoryWrite>[];
  int index = 0;

  Map<String, Object?> common(OutflowLineKind kind) => <String, Object?>{
        // ★★★ **المصدر إلزاميٌّ في كل سطر** — `GR-42`.
        'sourceId': request.sourceId,
        // ★★★ **وأساسُ فصل الإجماليات والتقارير والصلاحيات** — `GR-43`.
        'ledgerType': outflow.ledgerType.name,
        'category': outflow.category.name,
        'itemType': kind.name,
        // ⑥ ★★★ **الأثر المالي في تاريخ السند** — `GR-49`.
        'documentDate': request.documentDate.asUtcMidnight(),
        'sourceDocType': outflowSourceDocType(outflow.ledgerType).name,
        'sourceDocId': request.documentNumber,
        'sourceDocNumber': request.documentNumber,
        'isCancelled': false,
        if (!operation.isCreate) 'amendedBy': request.actor.userId,
        if (!operation.isCreate) 'amendReason': reason,
      };

  for (final ValidatedOutflowQatLine line in outflow.qatLines) {
    final Map<String, Object?> fields = <String, Object?>{
      ...common(OutflowLineKind.qat),
      'itemKey': line.itemKey,
      'itemName': line.itemName,
      'unit': line.quantity.unit.name,
      'quantity': _quantityValue(line.quantity),
      // ⑥ ★★★ **والأثر المخزني في تاريخ المخزون** — `GR-49`.
      'stockDate': request.stockDate.asUtcMidnight(),
      'sackId': ?line.sackId,
      if (line.unitPrice case final Money price) 'unitPrice': price.riyals,
      // ⛔⛔ **والقيمةُ غائبةٌ لغير المسعَّر** — ★ **ولا تُكتب صفراً**:
      //    ⟵ **وصفرٌ كان سيدخل مجموعَ التقرير فيُظهره نهائياً وهو ناقص.**
      if (line.lineValue case final Money value) 'lineValue': value.riyals,
    };
    writes.add(
      InventoryWrite(
        collectionId: outflowLedgerCollection,
        documentId: outflowLedgerEntryId(
          documentNumber: request.documentNumber,
          index: index++,
        ),
        fields: fields,
        updateMask: fields.keys.toList(),
        serverTimestampFields: operation.isCreate
            ? const <String>['entryDate']
            : const <String>['lastAmendedAt'],
      ),
    );
  }

  for (final ValidatedOutflowCashLine line in outflow.cashLines) {
    final Map<String, Object?> fields = <String, Object?>{
      ...common(line.kind),
      'amount': line.amount.riyals,
      // ⛔ **ولا `stockDate` هنا** — ★ **لا أثرَ مخزني لسطرٍ نقدي.**
      if (line.description case final String text) 'description': text,
    };
    writes.add(
      InventoryWrite(
        collectionId: outflowLedgerCollection,
        documentId: outflowLedgerEntryId(
          documentNumber: request.documentNumber,
          index: index++,
        ),
        fields: fields,
        updateMask: fields.keys.toList(),
        serverTimestampFields: operation.isCreate
            ? const <String>['entryDate']
            : const <String>['lastAmendedAt'],
      ),
    );
  }

  // ★★★ **وسطورُ التعديل الزائدة تُوسَم ملغاة** — ⛔ **ولا تُترَك حيّة:**
  //    ⟵ **فسندٌ نقص سطراً كان سيُبقي قيمتَه في تقرير المصدر إلى الأبد**،
  //    ★ **وهو عطبٌ ماليٌّ صامت.** ⛔ **ولا تُحذَف** (`GR-07`).
  for (final String stale in _staleLedgerEntryIds(
    request.storedDocument,
    request.documentNumber,
    index,
  )) {
    final Map<String, Object?> fields = <String, Object?>{
      'isCancelled': true,
      'amendedBy': request.actor.userId,
      'amendReason': reason,
    };
    writes.add(
      InventoryWrite(
        collectionId: outflowLedgerCollection,
        documentId: stale,
        fields: fields,
        updateMask: fields.keys.toList(),
        serverTimestampFields: const <String>['lastAmendedAt'],
      ),
    );
  }

  return writes;
}

/// ★ معرّفاتُ سطور الدفتر التي كتبها هذا المستند سابقاً.
List<String> _storedLedgerEntryIds(Map<String, Object?>? stored) {
  final Object? count = stored?['ledgerEntryCount'];
  final Object? number = stored?['documentNumber'];
  if (count is! int || number is! String) return const <String>[];
  return <String>[
    for (int i = 0; i < count; i++)
      outflowLedgerEntryId(documentNumber: number, index: i),
  ];
}

/// ★ سطورٌ كتبها المستند سابقاً ولم يعد لها مقابلٌ بعد التعديل.
List<String> _staleLedgerEntryIds(
  Map<String, Object?>? stored,
  String documentNumber,
  int writtenCount,
) {
  final Object? previous = stored?['ledgerEntryCount'];
  if (previous is! int || previous <= writtenCount) return const <String>[];
  return <String>[
    for (int i = writtenCount; i < previous; i++)
      outflowLedgerEntryId(documentNumber: documentNumber, index: i),
  ];
}

/// ★ قيمة الكمية كما تُكتب — **صحيحٌ للحبّة، وعشريٌّ مُصرَّحٌ به للوزن**.
///
/// ★★ **والوزن يمرّ بـ[DecimalValue] وحدها** (`ADR-0015` القاعدة 9) —
/// ⛔ **و`double` المجرَّد يبقى مرفوضاً في المُرمِّز** (`DEBT-41`).
Object _quantityValue(StockQuantity quantity) => switch (quantity) {
      PieceQuantity(:final PieceCount count) => count.pieces,
      WeightQuantity(:final WeightKg weight) => DecimalValue(weight.kilograms),
    };

// ═════════════════════════════════════════════════════════════════════════
// المستند وحقوله
// ═════════════════════════════════════════════════════════════════════════

Map<String, Object?> _documentFields(
  OutflowRequest request,
  ValidatedOutflow outflow,
) =>
    <String, Object?>{
      'documentNumber': request.documentNumber,
      // ★★★ **وهو ما تقرؤه قاعدةُ الحماية لتختار مفتاح العرض** (`GR-43`).
      'ledgerType': outflow.ledgerType.name,
      'category': outflow.category.name,
      'sourceId': outflow.sourceId,
      if (_nameOf(request.storedSource) case final String sourceName)
        'sourceName': sourceName,
      // ⑥ ★★★ **حقلان مستقلان لا حقلٌ واحد** — `FR-M22-10` · `GR-49`.
      'documentDate': request.documentDate.asUtcMidnight(),
      'stockDate': request.stockDate.asUtcMidnight(),
      if (outflow.notes case final String notes) 'notes': notes,
      // ⛔⛔★★★ **ومصفوفةٌ واحدة `lines[]` بحقل `itemType`** — ⛔ **لا
      //    مصفوفتان**: ★ **وهو نصُّ `data-dictionary.md` §`outflows`
      //    حرفياً** (`lines[] ⟵ itemType (قات/مبلغ/أخرى)`)، ⟵ **وشكلٌ
      //    ثانٍ في المخزَّن كان يُجبر كلَّ قارئٍ لاحق** (تقاريرُ `WU-018` ·
      //    `R-21`…`R-24`) **على معرفة أيِّهما يقرأ.**
      //    ★ **والفصلُ يبقى في *النوع* داخل الذاكرة** ([ValidatedOutflow])
      //    ⛔ **لا في المخزَّن** — ⟵ **فالمخطَّط عقدٌ، والنوعُ أداةُ تحقّق.**
      'lines': <Object?>[
        for (final ValidatedOutflowQatLine line in outflow.qatLines)
          <String, Object?>{
            'itemType': OutflowLineKind.qat.name,
            'itemId': line.itemId,
            'itemName': line.itemName,
            'unit': line.quantity.unit.name,
            'quantity': _quantityValue(line.quantity),
            // ★★ **وتاريخُ المخزون في السطر نفسِه** — `GR-49` ·
            //   `data-dictionary.md`: ⟵ **فالبندُ يُقرأ مخزنياً بلا رجوعٍ
            //   إلى رأس المستند.**
            'stockDate': request.stockDate.asUtcMidnight(),
            if (line.unitPrice case final Money price)
              'unitPrice': price.riyals,
            if (line.lineValue case final Money value) 'lineValue': value.riyals,
            if (line.sackId case final String sackId) 'sackId': sackId,
          },
        for (final ValidatedOutflowCashLine line in outflow.cashLines)
          <String, Object?>{
            'itemType': line.kind.name,
            'amount': line.amount.riyals,
            if (line.description case final String text) 'description': text,
          },
      ],
      // ⛔ **إجماليان منفصلان دائماً للكميات** — `GR-19` · `FR-M22-11`.
      'totalPieces': outflow.totalPieces.pieces,
      'totalWeight': DecimalValue(outflow.totalWeight.kilograms),
      // ★★★ **والإجماليات المالية الثلاثة** — `GR-42` · `AT-38`.
      'totalQatValue': outflow.totalQatValue.riyals,
      'totalCashValue': outflow.totalCashValue.riyals,
      'grandTotal': outflow.grandTotal.riyals,
      // ★★ **وعددُ ما لم يُسعَّر مُعلَنٌ في المستند** — `FR-M22-07`:
      //    ⟵ **فالتقريرُ يعرف أن رقمَه ناقص** ⛔ **بلا استعلامٍ ثانٍ.**
      'unpricedItemCount': outflow.unpricedItemCount,
      // ★ **عددُ سطور الدفتر** — ⟵ **وبه يُعرَف ما يجب وسمُه عند التعديل**
      //   ⛔ **بلا استعلامٍ داخل معاملة** (راجع [_staleLedgerEntryIds]).
      'ledgerEntryCount': outflow.qatLines.length + outflow.cashLines.length,
      documentStatusField: OutflowStatus.approved.name,
      // ⛔⛔★★★ **ولا حقلَ مقوتٍ ولا ذمّة** — `FR-M22-04` · `GR-44`:
      //    ★ **والكتابةُ هنا لا تُنشئهما أصلاً.**
    };

InventoryWrite _documentWrite(
  OutflowRequest request,
  OutflowOperation operation,
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
    collectionId: outflowsCollection,
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
///
/// ⛔⛔★★★ **وهنا يقع القيد ② — أهمُّ حارسٍ في هذا الملف:** ★ **السجلُّ
/// المخزَّن هو الحَكَم** ⛔ **لا المُرسَل**: ⟵ **وقد فُحصت الصلاحيةُ في
/// [outflowGate] على السجل المُدَّعى**، ★ **فلو خالف المخزَّنُ ادّعاءَه
/// لكان المُنفِّذ قد اجتاز بوابةَ سجلٍّ ثم عمل على سجلٍّ آخر** — ⟵ **وهو
/// تصعيدُ امتيازٍ صامت يُبطِل `GR-43` كلَّه.**
OutflowRejected? _existenceGate(
  OutflowRequest request,
  OutflowOperation operation,
) {
  final Map<String, Object?>? stored = request.storedDocument;
  if (operation.isCreate) {
    // ★ **ورقمٌ مخصَّصٌ للتوّ لا يقابله مستند** — ⟵ **ووجودُه تصادمُ عدّاد.**
    return stored == null
        ? null
        : const OutflowRejected(CallableError.concurrency);
  }
  if (stored == null) {
    return const OutflowRejected(CallableError.invalidArgument);
  }
  // ★★★ **والمخزَّن هو الحَكَم لا المُرسَل** — `GR-23`.
  if (stored['sourceId'] != request.sourceId) {
    return const OutflowRejected(CallableError.sourceOutOfScope);
  }
  // ⛔⛔★★★ **والسجلُّ المخزَّن يعلو المُرسَل** — راجع ترويسة الدالة.
  if (stored['ledgerType'] != request.ledgerType.name) {
    return const OutflowRejected(CallableError.permissionMissing);
  }
  // ★★ **والملغى لا يُعدَّل ولا يُلغى ثانيةً** — `ERR_AMEND_006`.
  final Outcome<void> live = validateOutflowNotCancelled(
    stored[documentStatusField] == OutflowStatus.cancelled.name
        ? OutflowStatus.cancelled
        : OutflowStatus.approved,
  );
  return live is Failure<void>
      ? const OutflowRejected(CallableError.documentCancelled)
      : null;
}

/// ★ يفحص المصدر — **موجودٌ ونشط**.
///
/// ⚠️ **والإلغاء مسموح على مصدرٍ عُطِّل** — ⟵ **فالتعطيل لا يحبس مستنداً
/// خاطئاً داخل النظام**؛ ⛔ **والمنع على الجديد وتعديله** (`FR-M2-05`).
///
/// ⛔⛔★★ **ولا بوابةَ مقوتٍ هنا** (بخلاف `distribution.dart`) — ★ **لا طرفَ
/// ثانيَ في هذه العملية أصلاً** (`FR-M22-04`).
OutflowRejected? _sourceGate(
  OutflowRequest request,
  OutflowOperation operation,
) {
  final Map<String, Object?>? source = request.storedSource;
  // ⛔ **سجلٌّ لم يُقرأ ⟵ رفض** — الرفض الافتراضي.
  if (source == null) {
    return const OutflowRejected(CallableError.internal);
  }
  if (operation.isCancel) return null;
  if (source['isActive'] == false) {
    return const OutflowRejected(CallableError.sourceInactive);
  }
  return null;
}

/// ★★★ **حارسُ التاريخ** — `FR-M22-09` · `BR-M22-06` · `AT-56`.
///
/// ⛔⛔★★ **والمستقبليُّ مرفوضٌ للمالك نفسِه** — ★ **ولا مفتاح يفتحه**،
/// ⟵ **والمفتاحُ يخصّ السابقَ وحده** ([outflowBackdatePermission]).
///
/// ⚠️ **ولا يُفحَص في الإلغاء** — ★ **فالإلغاءُ لا يُغيِّر تاريخاً**:
/// ⟵ **وسندٌ بتاريخٍ سابقٍ صحيحٍ كان سيستحيل إلغاؤه بعد انقضاء صلاحية
/// مُلغيه**، ⛔ **فيبقى حيّاً في كل تقرير.**
OutflowRejected? _dateGate(
  OutflowRequest request,
  OutflowOperation operation,
) {
  if (operation.isCancel) return null;
  final Outcome<void> result = validateOutflowDate(
    date: request.documentDate,
    today: request.today,
    canBackdate: request.actor.claims
        .has(outflowBackdatePermission(request.ledgerType)),
  );
  return switch (result) {
    Failure<void>(error: PermissionError()) =>
      const OutflowRejected(CallableError.permissionMissing),
    Failure<void>() => const OutflowRejected(CallableError.invalidArgument),
    Success<void>() => null,
  };
}

/// ★ يُترجم خطأ النطاق إلى رمز الكتالوج **بحسب الفعل المطلوب**.
CallableError _mapStockError(AppError error, OutflowOperation operation) =>
    switch (error) {
      InsufficientStockError()
          when operation == OutflowOperation.amendOutflow =>
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
  required OutflowRequest request,
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
      ),
      action: action,
      reason: reason,
      target: AuditTarget(
        // ★★★ **ونوعٌ مستقلٌّ لكل سجل** — `GR-43`: ⟵ **فمرشِّحُ السجل يفصلهما**.
        entityType: outflowEntityType(request.ledgerType),
        entityId: request.documentNumber,
        sourceId: request.sourceId,
      ),
      // ⛔⛔★★★ **وتُمرَّر كما هي** — ★ **والوزن يبقى [DecimalValue] مغلَّفاً**
      //    (`DEBT-41`).
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

/// ★ اسمُ الفئة المخزَّنة أو نصٌّ محايد — **لعنوان بند المركز المعلّق**.
String _storedCategoryLabel(Map<String, Object?>? stored) {
  final Object? raw = stored?['category'];
  for (final OutflowCategory category in OutflowCategory.values) {
    if (category.name == raw) return category.label;
  }
  return 'سحبية أو خرجية';
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

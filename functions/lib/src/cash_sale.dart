/// البيع النقدي المباشر — **التخطيط الخالص** لعمليات `WU-012` (`M11`).
///
/// ★ **مفصول عن الشبكة بنفس منطق `distribution.dart`:** `ADR-0013` القاعدة 3
/// تجعل **فحص التفويض في الكود** هو الحارس الوحيد لهذا المسار، فالدالة تعمل
/// بامتياز إداري يتجاوز قواعد الحماية. ★ **وحارسٌ لا يُختبَر بلا سحابة
/// حارسٌ غير مُختبَر** — فكل قرار هنا **دالة خالصة**.
///
/// ★ **وكل معادلة من طبقة النطاق لا من هنا** (`qtms_domain`) —
/// ⛔ **ولا تُعاد كتابتها** (`coding-standards.md` §2.2 · `ADR-0009`).
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔★★ **تسعة قيود بندُ قبولٍ مُلزِم لهذه الدالة:**
///
///   ① **الصلاحية** (`cashSaleCreate` / `cashSaleAmend` / `cashSaleCancel`).
///   ② ★★ **نطاق المصادر** — ⛔ **قيدٌ يعلو على كل صلاحية** (`GR-23`).
///   ③ **تاريخ المخزون = يوم المنصّة** (`A-10` · `GR-14`) — ⚠️ **إلا في
///      التصريف المتأخر بمفتاحه** (`agedRemainderClear` — `WU-019`).
///   ④ **وقت الخادم في `entryDate` و`createdAt`** (`GR-54` · `E-41`).
///   ⑤ ★★ **منع الرصيد السالب** (`FR-M8-01` · `GR-11`) — ★ **مقيساً من
///      الدفتر داخل المعاملة** ⛔ **لا من الملخص ولا من الجهاز.**
///   ⑥ ⛔⛔★★★ **ولا قيدَ واحدٌ في دفتر المقاوته** (`FR-M11-03` · `GR-33`) —
///      ★ **وهو الفارق الجوهري عن `distribution.dart`**: ⟵ **لا
///      `_dealerWrites` ولا `dealer_balances` ولا فائضَ يُطبَّق**،
///      ⛔ **ولا حقلَ مقوتٍ يعبر هذا الملف أصلاً.**
///   ⑦ ★★★ **السعر إلزاميٌّ في كل سطر** (`FR-M11-04`) — ★ **تفرضه طبقةُ
///      النطاق بنوعها** (`ValidatedCashSaleLine.unitPrice` غيرُ قابلٍ للعدم)،
///      ⟵ **فلا يصل هنا سطرٌ بلا سعر أصلاً.**
///   ⑧ ⛔⛔★★★ **والسعر دون الحد الأدنى مرفوضٌ دائماً** ([`CR-007`] —
///      `GR-34` · `ERR_PRICE_002`) ⛔ **بلا استثناء ولا مفتاح تجاوز** —
///      ★ **والحدُّ يُقرأ من `daily_prices` داخل المعاملة** ⛔ **لا من
///      الحمولة**: ⟵ **وإلا كفى تعديلُ الطلب من خارج التطبيق لتجاوزه.**
///   ⑨ **الحذف مرفوض نهائياً** — ⟵ **ولا مسار حذف في هذا الملف أصلاً.**
/// ═══════════════════════════════════════════════════════════════════════
///
/// ⛔⛔★★ **ولا `pricing/current` هنا بخلاف التوزيعة** (`ADR-0011`) —
/// ★ **`ت-12` قاعدةُ التوزيع وحده**: ⟵ **ولا مفتاح «عرض أسعار البيع
/// النقدي» في الكتالوج §2.3 أصلاً**، ★ **والسعرُ في السند نفسِه**
/// (`schema/cash-sales.md`) — ⛔ **وعزلُه كان سيُنشئ حارساً لا صلاحيةَ له.**
library;

import 'package:qtms_domain/qtms_domain.dart';

import 'callable.dart';
import 'firestore_value.dart' show DecimalValue;
import 'identity_gateway.dart';
import 'inventory.dart';

/// نوع عملية بيعٍ نقدي — ويحدد الصلاحية التي لا تُنفَّذ بدونها.
enum CashSaleOperation {
  /// `createCashSale` — يشترط `cashSaleCreate` (`FR-M11` §4).
  createCashSale(Permission.cashSaleCreate, isCreate: true),

  /// `amendCashSale` — يشترط `cashSaleAmend` ★ **وسبباً نصياً اختيارياً**
  /// (`FR-M11-13` · `ADR-0020`).
  amendCashSale(Permission.cashSaleAmend, isCreate: false),

  /// `cancelCashSale` — يشترط `cashSaleCancel`.
  ///
  /// ⛔★★ **وليس حذفاً:** الإلغاء **وسمٌ يُستبعَد من الجمع** (`GR-06` ·
  /// `A-14`)، ★ **والحركات تبقى مقروءةً مشطوبة.**
  cancelCashSale(Permission.cashSaleCancel, isCreate: false, isCancel: true);

  const CashSaleOperation(
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

/// نتيجة التخطيط — إما خطة كتابة وإما رفض مصنَّف.
sealed class CashSalePlan {
  /// ينشئ النتيجة.
  const CashSalePlan();
}

/// رُفض الطلب قبل أي كتابة.
final class CashSaleRejected extends CashSalePlan {
  /// ينشئ رفضاً.
  const CashSaleRejected(this.error);

  /// رمز الرفض من كتالوج الأخطاء.
  final CallableError error;
}

/// قُبل الطلب — وهذه كتاباته وقيده.
final class CashSaleAccepted extends CashSalePlan {
  /// ينشئ خطة مقبولة.
  const CashSaleAccepted({
    required this.documentNumber,
    required this.writes,
    required this.entry,
  });

  /// رقم المستند — `CSH-YYYYMMDD-####` ★ **وهو معرّفه في المجموعة**.
  final String documentNumber;

  /// المستندات المكتوبة — ⛔ **ولا تكون فارغة**.
  final List<InventoryWrite> writes;

  /// قيد التدقيق — **يُكتب في المعاملة نفسها** (`ADR-0013` القاعدة 1).
  final AuditEntry entry;
}

/// طلب بيعٍ نقدي مُتحقَّق من هوية مُنفِّذه.
final class CashSaleRequest {
  /// ينشئ الطلب.
  const CashSaleRequest({
    required this.actor,
    required this.requestId,
    required this.sourceId,
    required this.documentNumber,
    required this.stockDate,
    this.sale,
    this.storedSource,
    this.storedDocument,
    this.items = const <String, ItemRead>{},
    this.ledger = const <String, List<LedgerRead>>{},
    this.minCashPrices = const <String, Money?>{},
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

  /// ★★ **تاريخ المخزون** — ⛔ **من زمن المنصّة داخل المعاملة**.
  final CalendarDay stockDate;

  /// المستند المُتحقَّق منه — `null` للإلغاء.
  final ValidatedCashSale? sale;

  /// سجل المصدر كما قُرئ — ⛔ **و`null` رفضٌ لا تجاوز**.
  final Map<String, Object?>? storedSource;

  /// المستند القائم — `null` تعني **غيابه**.
  final Map<String, Object?>? storedDocument;

  /// سجلات الأنواع المطلوبة بمعرّفاتها.
  final Map<String, ItemRead> items;

  /// ★★ **حركات دفتر المخزون لكل نوع** — **مقروءةً داخل المعاملة**.
  final Map<String, List<LedgerRead>> ledger;

  /// ★★★ **الحد الأدنى للبيع النقدي لكل نوع** — **من `daily_prices` داخل
  /// المعاملة** (`FR-M11-05` · `GR-34`).
  ///
  /// ⚠️⚠️ **و`null` أو الغياب يعني «لا حدَّ مسجَّلاً بعد»** (`FR-M11-06`) —
  /// ★ **فيُسمح بالبيع مع تنبيه** ⛔ **ولا يُعامَل صفراً**: ⟵ **وصفرٌ كان
  /// سيجعل كل سعرٍ «فوق الحد» فيسقط الحارس بصمت، أو يجعل كل نوعٍ غيرِ مسعَّر
  /// يستلزم مفتاحَ تجاوزٍ لا معنى له.**
  final Map<String, Money?> minCashPrices;

  /// ★ سبب التعديل أو الإلغاء — ⛔ **اختياريٌّ** (`ADR-0020`).
  final String? reason;

  /// وصف الجهاز للسجل — ⛔ بلا بيانات حساسة.
  final String? deviceInfo;
}

/// ★★ فحوص الحالة والصلاحية والنطاق — **تُستدعى قبل فتح المعاملة**.
///
/// ⚠️ **ولماذا مُصدَّرة:** كل عملية هنا تحتاج **قراءةً داخل معاملة** قبل أن
/// يكتمل تخطيطها، ⟵ **وفتحُ معاملةٍ لطلبٍ يرفضه نقصُ الصلاحية هدرٌ وقفلٌ
/// بلا داعٍ**. ★ **والفحص يُعاد كاملاً** في [planCashSale] ⛔ **فلا مسار
/// يتخطّاه.**
CashSaleRejected? cashSaleGate(
  CashSaleRequest request,
  CashSaleOperation operation,
) {
  // ① «التعطيل فوري ونافذ» — `authentication-policy.md` §2 القاعدة 3.
  if (request.actor.disabled) {
    return const CashSaleRejected(CallableError.accountDisabled);
  }
  // ② الصلاحية — ⛔ ولا قاعدة حماية تحرس هذا المسار.
  if (!request.actor.claims.has(operation.requiredPermission)) {
    return const CashSaleRejected(CallableError.permissionMissing);
  }
  // ③ ★★ **النطاق — قيدٌ يعلو على الصلاحية** (`GR-23`) — ⛔ **والغياب منعٌ.**
  if (!request.actor.claims.canAccessSource(request.sourceId)) {
    return const CashSaleRejected(CallableError.sourceOutOfScope);
  }
  // ④ معرّف الطلب إلزامي — وبدونه لا تتحقق اللاتكرارية عند إعادة الإرسال.
  if (request.requestId.trim().isEmpty) {
    return const CashSaleRejected(CallableError.invalidArgument);
  }
  return null;
}

/// يخطّط عملية بيعٍ نقدي — **دالة خالصة، وهي حارس التفويض الفعلي**.
CashSalePlan planCashSale(
  CashSaleRequest request,
  CashSaleOperation operation,
) {
  final CashSaleRejected? gate = cashSaleGate(request, operation);
  if (gate != null) return gate;

  if (request.documentNumber.trim().isEmpty) {
    return const CashSaleRejected(CallableError.invalidArgument);
  }

  // ⛔⛔★★★ **ولا حارسَ للسبب** — `ADR-0020`: ★ **اختياريٌّ إنشاءً وتعديلاً
  //    وإلغاءً**، ⟵ **ولا رفضَ لغيابه** ⛔ **ولا يُعبَّأ نيابةً عن المستخدم.**
  final String? reason = _trimmed(request.reason);

  final CashSaleRejected? existence = _existenceGate(request, operation);
  if (existence != null) return existence;

  final CashSaleRejected? source = _sourceGate(request, operation);
  if (source != null) return source;

  return operation.isCancel
      ? _planCancellation(request, reason)
      : _planSale(request, operation, reason);
}

// ═════════════════════════════════════════════════════════════════════════
// الإنشاء والتعديل
// ═════════════════════════════════════════════════════════════════════════

CashSalePlan _planSale(
  CashSaleRequest request,
  CashSaleOperation operation,
  String? reason,
) {
  final ValidatedCashSale? sale = request.sale;
  if (sale == null || sale.sourceId != request.sourceId) {
    return const CashSaleRejected(CallableError.invalidArgument);
  }

  // ★ الأنواع: **موجودة · نشطة · مرتبطة بالمصدر · بوحدتها المخزَّنة**.
  for (final ValidatedCashSaleLine line in sale.lines) {
    final ItemRead? item = request.items[line.itemKey];
    if (item == null || !item.isActive) {
      return const CashSaleRejected(CallableError.invalidArgument);
    }
    // ★★ `FR-M5-10`: **النوع لا يظهر إلا في مصادره** — ⛔ **والواجهة تُخفي،
    //    وهذا السطر يمنع.**
    if (!item.sourceIds.contains(request.sourceId)) {
      return const CashSaleRejected(CallableError.invalidArgument);
    }
    // ⛔ **ووحدة السطر = وحدة النوع المخزَّنة** — `FR-M5-03` · `GR-19`.
    if (line.quantity.unit != item.unit) {
      return const CashSaleRejected(CallableError.itemUnitLocked);
    }
  }

  // ⑧ ★★★ **حارس الحد الأدنى** — `FR-M11-05` (راجع [_minimumPriceGate]).
  final CashSaleRejected? minimum = _minimumPriceGate(request, sale);
  if (minimum != null) return minimum;

  // ★★ **كل نوعٍ يلمسه هذا المستند** — الجديد **والمحذوف من التعديل معاً**.
  final Map<String, StockQuantity> desired = <String, StockQuantity>{
    for (final ValidatedCashSaleLine line in sale.lines)
      line.itemKey: line.quantity,
  };
  final Map<String, String?> sackIds = <String, String?>{
    for (final ValidatedCashSaleLine line in sale.lines)
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
      return CashSaleRejected(_mapStockError(error, operation));
    }
    writes.addAll((planned as Success<List<InventoryWrite>>).value);
  }

  // ⑥ ⛔⛔★★★ **ولا كتابةَ واحدة في `dealer_ledger` ولا `dealer_balances`**
  //    — `FR-M11-03`: ★ **والغياب هنا هو تنفيذُ المتطلب نفسِه**، ⛔ **لا سهوٌ
  //    يُستدرَك.**

  final Map<String, Object?> after = _documentFields(request, sale);
  writes.insert(0, _documentWrite(request, operation, after, reason));

  return CashSaleAccepted(
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

CashSalePlan _planCancellation(CashSaleRequest request, String? reason) {
  // ⛔⛔★★ **ولا حارسَ تسويةٍ هنا بخلاف التوزيعة** (`E-15`) — ★ **البيع
  //    النقدي لا يُنشئ ذمّةً تُسدَّد** (`FR-M11-03`): ⟵ **فلا سدادَ يمنع
  //    إلغاءه**، ⛔ **والمانع الوحيد أن يكون ملغى سلفاً** (`_existenceGate`).
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
      return CashSaleRejected(
        _mapStockError(error, CashSaleOperation.cancelCashSale),
      );
    }
    writes.addAll((planned as Success<List<InventoryWrite>>).value);
  }

  final Map<String, Object?> fields = <String, Object?>{
    documentStatusField: CashSaleStatus.cancelled.name,
    'cancelReason': reason,
    'cancelledBy': request.actor.userId,
  };
  writes.insert(
    0,
    InventoryWrite(
      collectionId: cashSalesCollection,
      documentId: request.documentNumber,
      fields: fields,
      // ★ **قناعٌ ضيّق** — ⛔ **فلا يمحو الإلغاءُ سطوراً ولا تاريخ مخزون.**
      updateMask: fields.keys.toList(),
      serverTimestampFields: const <String>['cancelledAt'],
    ),
  );

  return CashSaleAccepted(
    documentNumber: request.documentNumber,
    writes: writes,
    entry: _entry(
      request: request,
      // ★ **الإلغاء فعلٌ مستقل في المعجم لا «تعديل»** — فيُقرأ من السجل بذاته.
      action: AuditAction.cancel,
      reason: reason,
      valuesBefore: <String, Object?>{
        documentStatusField: request.storedDocument?[documentStatusField] ??
            CashSaleStatus.approved.name,
      },
      valuesAfter: <String, Object?>{
        documentStatusField: CashSaleStatus.cancelled.name,
      },
    ),
  );
}

// ═════════════════════════════════════════════════════════════════════════
// ⑧ ★★★ حارس الحد الأدنى — `FR-M11-05` · `FR-M11-06` · `GR-34`
// ═════════════════════════════════════════════════════════════════════════

/// ⛔⛔★★★ **يرفض كلَّ سعرٍ دون الحد الأدنى — بلا استثناء ولا مفتاح تجاوز**.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ★★★ **وهذا تنفيذُ [`CR-007`] المعتمد (2026-09-01)** — ⛔ **لا انحرافٌ عن
/// `FR-M11-05`:** ★ **نصُّه الأصلي كان «إلا بصلاحية البيع دون الحد الأدنى»**،
/// ⟵ **وقرارُ المالك الصريح ألغى الاستثناء كلَّه**: **«يُمنع الحفظ للجميع
/// بلا استثناء»** — ★ **فصار الحدُّ الأدنى حدّاً فعلياً لا اقتراحاً بصلاحية.**
///
/// | الحالة | القرار |
/// |---|---|
/// | **لا حدَّ مسجَّلاً للنوع** | ✅ **يُقبَل** — `FR-M11-06` («يُسمح بالبيع مع تنبيه») |
/// | **السعر ≥ الحد** | ✅ **يُقبَل** — ★ **والمساواةُ مقبولة**: «**لا يقل عن**» |
/// | ⛔⛔ **السعر < الحد** | ⛔ **يُرفَض دائماً** — `ERR_PRICE_002` · ★ **ولو ملك المُرسِل `cashSaleBelowMinimum`** |
/// ═══════════════════════════════════════════════════════════════════════
///
/// ⛔⛔★★ **و`cashSaleBelowMinimum` لم يعد يمنح شيئاً بعد `CR-007`** —
/// ★ **ولذلك لا تقرؤه هذه الدالة إطلاقاً**: ⟵ **وقراءتُه هنا كانت ستُبقي
/// باباً يظنّه القارئ مغلقاً.** ⚠️ **ومصيرُ المفتاح في الكتالوج بندٌ معلَّق
/// في `CR-007` §5** — ⛔ **ولا يُحذَف مفتاحٌ من الكتالوج بلا قرارٍ صريح.**
///
/// ⛔⛔★★ **والمقارنة بدالة النطاق وحدها** ([isBelowMinimumCashPrice]) —
/// ★ **فالشاشةُ تُنبِّه بها وهذا يحرس بها**: ⟵ **وشرطان متطابقان في موضعين
/// يفترقان عند المساواة بالحد تحديداً** (`coding-standards.md` §2.2).
///
/// ⚠️⚠️ **ويُفحَص على الإنشاء والتعديل معاً** — ⛔ **ولا يُستثنى التعديل**:
/// ⟵ **وإلا لأمكن حفظُ سعرٍ نظامي ثم تخفيضُه بتعديل**، ★ **وهو بابٌ خلفيٌّ
/// للقاعدة كلِّها.**
CashSaleRejected? _minimumPriceGate(
  CashSaleRequest request,
  ValidatedCashSale sale,
) {
  for (final ValidatedCashSaleLine line in sale.lines) {
    if (isBelowMinimumCashPrice(
      unitPrice: line.unitPrice,
      minCashPrice: request.minCashPrices[line.itemKey],
    )) {
      return const CashSaleRejected(CallableError.belowMinimumCashPrice);
    }
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
Outcome<List<InventoryWrite>> _planItem({
  required CashSaleRequest request,
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
      // ⛔★★ **خروجٌ دائماً** — ★ **والبيع النقدي لا يُدخِل شيئاً للمخزن.**
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

  // ⑤ ★★ **منع الرصيد السالب** — `FR-M8-01` · `GR-11` · `E-01`.
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
  required CashSaleRequest request,
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
    'sourceDocType': SourceDocumentType.cashSale.name,
    'sourceDocId': request.documentNumber,
    'sourceDocNumber': request.documentNumber,
    'movementTag': MovementTag.normal.name,
    'isCancelled': isCancelled,
    // ★★ **و`sackId` متى كان النوع من جونية** — `FR-M11-09` · `A-13`:
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
  required CashSaleRequest request,
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
/// المُرمِّز** (`DEBT-41`)، ★ **فالتصريح شرطُ المرور لا صيغةٌ اختيارية.**
Object _quantityValue(StockQuantity quantity) => switch (quantity) {
      PieceQuantity(:final PieceCount count) => count.pieces,
      WeightQuantity(:final WeightKg weight) => DecimalValue(weight.kilograms),
    };

// ═════════════════════════════════════════════════════════════════════════
// المستند وحقوله
// ═════════════════════════════════════════════════════════════════════════

Map<String, Object?> _documentFields(
  CashSaleRequest request,
  ValidatedCashSale sale,
) =>
    <String, Object?>{
      'documentNumber': request.documentNumber,
      'sourceId': sale.sourceId,
      if (_nameOf(request.storedSource) case final String sourceName)
        'sourceName': sourceName,
      // ③ ★★ **تاريخ المخزون من الخادم** — `A-10` · `GR-14`.
      'stockDate': request.stockDate.asUtcMidnight(),
      if (sale.notes case final String notes) 'notes': notes,
      'lines': <Object?>[
        for (final ValidatedCashSaleLine line in sale.lines)
          // ★★ **والسعر في السطر نفسِه** — ⛔ **ولا مستندَ أسعارٍ فرعي**:
          //    راجع ترويسة الملف (`ت-12` قاعدةُ التوزيع وحده).
          <String, Object?>{
            'itemId': line.itemId,
            'itemName': line.itemName,
            'unit': line.quantity.unit.name,
            'quantity': _quantityValue(line.quantity),
            'unitPrice': line.unitPrice.riyals,
            'lineTotal': line.lineTotal.riyals,
            if (line.sackId case final String sackId) 'sackId': sackId,
            if (line.belowMinReason case final String reason)
              'belowMinReason': reason,
          },
      ],
      // ⛔ **إجماليان منفصلان دائماً** — `GR-19` · `FR-M11-14`.
      'totalPieces': sale.totalPieces.pieces,
      'totalWeight': DecimalValue(sale.totalWeight.kilograms),
      // ★★ **صافي المقبوض** — من طبقة النطاق (`design-overview.md` §2.6).
      'netCashReceived': sale.netCashReceived.riyals,
      documentStatusField: CashSaleStatus.approved.name,
      // ⛔⛔★★★ **ولا حقلَ مقوتٍ ولا اسمِ مشترٍ ولا خصم** — `FR-M11-03` ·
      //    `FR-M11-12` · `ت-06`: ★ **وقاعدةُ الحماية ترفضهما لو أُرسلا من
      //    خارج التطبيق** — ⟵ **والكتابةُ هنا لا تُنشئهما أصلاً.**
    };

InventoryWrite _documentWrite(
  CashSaleRequest request,
  CashSaleOperation operation,
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
    collectionId: cashSalesCollection,
    // ★ **ورقم المستند هو معرّفه** — ⛔ **ولا معرّفَ مركّب** (`GR-18` قيدُ
    //   ضمارٍ لمقوت، ★ **والبيعُ النقدي بلا مقوت**).
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
CashSaleRejected? _existenceGate(
  CashSaleRequest request,
  CashSaleOperation operation,
) {
  final Map<String, Object?>? stored = request.storedDocument;
  if (operation.isCreate) {
    // ★ **ورقمٌ مخصَّصٌ للتوّ لا يقابله مستند** — ⟵ **ووجودُه يعني تصادمَ
    //   عدّاد**: ⛔ **فلا يُكتَب فوق سندٍ حيّ.**
    return stored == null
        ? null
        : const CashSaleRejected(CallableError.concurrency);
  }
  if (stored == null) {
    return const CashSaleRejected(CallableError.invalidArgument);
  }
  // ★★★ **والمخزَّن هو الحَكَم لا المُرسَل** — ⟵ **وإلا أمكن فحصُ النطاق
  //   على مصدرٍ ثم العملُ على مستند مصدرٍ آخر**، ⛔ **وهو تصعيدُ امتيازٍ
  //   صامت** (`GR-23`).
  if (stored['sourceId'] != request.sourceId) {
    return const CashSaleRejected(CallableError.sourceOutOfScope);
  }
  if (stored['stockDate'] != request.stockDate.asUtcMidnight()) {
    return const CashSaleRejected(CallableError.invalidArgument);
  }
  // ★★ **والملغى لا يُعدَّل ولا يُلغى ثانيةً** — `ERR_AMEND_006`.
  final Outcome<void> live = validateCashSaleNotCancelled(
    stored[documentStatusField] == CashSaleStatus.cancelled.name
        ? CashSaleStatus.cancelled
        : CashSaleStatus.approved,
  );
  return live is Failure<void>
      ? const CashSaleRejected(CallableError.documentCancelled)
      : null;
}

/// ★ يفحص المصدر — **موجودٌ ونشط**.
///
/// ⚠️ **والإلغاء مسموح على مصدرٍ عُطِّل** — ⟵ **فالتعطيل لا يحبس مستنداً
/// خاطئاً داخل النظام**؛ ⛔ **والمنع على البيع الجديد وتعديله**
/// (`FR-M2-05` · `FR-M2-06`).
///
/// ⛔⛔★★ **ولا بوابةَ مقوتٍ هنا** (بخلاف `distribution.dart`) — ★ **لا طرفَ
/// ثانيَ في هذه العملية أصلاً** (`FR-M11-01`): ⟵ **المشتري عابرٌ بلا حساب.**
CashSaleRejected? _sourceGate(
  CashSaleRequest request,
  CashSaleOperation operation,
) {
  final Map<String, Object?>? source = request.storedSource;
  // ⛔ **سجلٌّ لم يُقرأ ⟵ رفض** — الرفض الافتراضي: لا يُبنى قرارٌ بالتخمين.
  if (source == null) {
    return const CashSaleRejected(CallableError.internal);
  }
  if (operation.isCancel) return null;
  if (source['isActive'] == false) {
    return const CashSaleRejected(CallableError.sourceInactive);
  }
  return null;
}

/// ★ يُترجم خطأ النطاق إلى رمز الكتالوج **بحسب الفعل المطلوب**.
CallableError _mapStockError(AppError error, CashSaleOperation operation) =>
    switch (error) {
      InsufficientStockError()
          when operation == CashSaleOperation.amendCashSale =>
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
  required CashSaleRequest request,
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
        entityType: cashSaleEntityType,
        // ★ **ورقم المستند هو معرّفه** — ⟵ **فالسجل السياقي 🕘 يستعلم بما
        //   يُفتَح به المستند فعلاً** (`FR-M18-10`).
        entityId: request.documentNumber,
        sourceId: request.sourceId,
      ),
      // ⛔⛔★★★ **وتُمرَّر كما هي** — ★ **والوزن يبقى [DecimalValue] مغلَّفاً:**
      //    ⟵ **وفكُّ الغلاف يُفشِل الالتزام كلَّه** (`DEBT-41`).
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

/// الخصومات — **التخطيط الخالص** لعمليات `WU-013` (`M13`).
///
/// ★ **مفصول عن الشبكة بنفس منطق `receipt.dart`:** `ADR-0013` القاعدة 3
/// تجعل **فحص التفويض في الكود** هو الحارس الوحيد لهذا المسار، فالدالة تعمل
/// بامتياز إداري يتجاوز قواعد الحماية. ★ **وحارسٌ لا يُختبَر بلا سحابة
/// حارسٌ غير مُختبَر** — فكل قرار هنا **دالة خالصة**.
///
/// ★ **وكل معادلة من طبقة النطاق لا من هنا** (`qtms_domain`) —
/// ⛔ **ولا تُعاد كتابتها** (`coding-standards.md` §2.2 · `ADR-0009`).
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔★★ **ثمانية قيود بندُ قبولٍ مُلزِم لهذه الدالة** (`FR-M13`):
///
///   ① **الصلاحية** (`discountCreate` / `discountAmend` / `discountCancel`)
///      — ⛔⛔★★ **ولا تُمنَح افتراضياً** (`FR-M13-09`): ★ **لأنها إسقاطُ
///      دَينٍ حقيقي**، ⟵ **ومنحُها ضمناً مع القبض كان يجعل كلَّ قابضٍ
///      يُسقِط ديوناً.**
///   ② ★★★ **نطاق المصادر — لكل مصدرٍ مسّه السند على حدة** (`GR-23` ·
///      `E-35`) — ⛔ **ولا يكفي فحصُ مصدرٍ واحد**: ★ **سندُ «الكل» يمسّ
///      مصادر عدة**، ⟵ **وفحصُ الأول وحده كان يُسقِط ديناً في مصدرٍ خارج
///      نطاق المُنفِّذ.**
///   ③ ⛔⛔ **التاريخ المستقبلي مرفوض مطلقاً للجميع** (`FR-M13-06`) —
///      ★ **والفحص يسبق فحص الصلاحية عمداً.**
///   ④ **تاريخٌ سابق يشترط `discountBackdate`** (`AT-56`).
///   ⑤ ★★★ **حركة دائنة لكل سطر لا واحدةٌ مجمّعة** (`FR-M13-03`) —
///      ⛔ **بلا أي أثرٍ نقدي.**
///   ⑥ ★★ **مبلغ الخصم > 0 ولا يتجاوز متبقّي ذلك الضمار** (`FR-M13-04`)
///      — ★ **مقيساً من `pricing/current` داخل المعاملة** (`IQ-027`)
///      ⛔ **لا من الجهاز.**
///   ⑦ ★★★ **مبالغ التسوية تُكتب في `pricing/current` وحده** (`IQ-027`
///      الخيار أ · `ADR-0011`) — ★ **و`settlementStatus` في الأب**،
///      ⛔⛔ **والمبلغ يدخل `discountedAmount` لا `settledAmount`**
///      (`ت-04` · `GR-40`).
///   ⑧ ⛔⛔★★★ **ولا فائضَ إطلاقاً — ويُرفَض صراحةً لو أُرسل** (`FR-M13-05`
///      · `AT-35` · `ERR_DIST_009`): ★ **لأن الحقل غير موجودٍ في الشاشة**،
///      ⟵ **فوصولُه يعني طلباً من خارج التطبيق** ⛔ **ولا يُتجاهَل صامتاً.**
///   ⑨ **الحذف مرفوض نهائياً** — ⟵ **ولا مسار حذف في هذا الملف أصلاً.**
///
/// ⛔⛔★★★ **ولا مسارَ إيداعٍ بنكي هنا** (`FR-M13` §2) — ★ **غيابٌ بنيويٌّ
/// لا شرطٌ يُفحَص**: ⟵ **لا نقدَ دخل فلا شيءَ يُودَع.**
/// ═══════════════════════════════════════════════════════════════════════
library;

import 'package:qtms_domain/qtms_domain.dart';

import 'callable.dart';
import 'identity_gateway.dart';
import 'inventory.dart';
import 'receipt.dart' show DebtLotRead, ReceiptLedgerRead;

/// نوع عملية خصم — ويحدد الصلاحية التي لا تُنفَّذ بدونها.
enum DiscountOperation {
  /// `createDiscount` — يشترط `discountCreate` (`FR-M13` §4).
  createDiscount(Permission.discountCreate, isCreate: true),

  /// `amendDiscount` — يشترط `discountAmend` ★ **وسببٌ نصيٌّ اختياري**
  /// ([`ADR-0020`]).
  amendDiscount(Permission.discountAmend, isCreate: false),

  /// `cancelDiscount` — يشترط `discountCancel`.
  ///
  /// ⛔★★ **وليس حذفاً:** الإلغاء **وسمٌ يُستبعَد من الجمع** (`GR-06` ·
  /// `A-14`)، ★ **والحركات والقيد يبقيان مقروءَين مشطوبَين.**
  cancelDiscount(Permission.discountCancel, isCreate: false, isCancel: true);

  const DiscountOperation(
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
sealed class DiscountPlan {
  /// ينشئ النتيجة.
  const DiscountPlan();
}

/// رُفض الطلب قبل أي كتابة.
final class DiscountRejected extends DiscountPlan {
  /// ينشئ رفضاً.
  const DiscountRejected(this.error);

  /// رمز الرفض من كتالوج الأخطاء.
  final CallableError error;
}

/// قُبل الطلب — وهذه كتاباته وقيده.
final class DiscountAccepted extends DiscountPlan {
  /// ينشئ خطة مقبولة.
  const DiscountAccepted({
    required this.documentNumber,
    required this.writes,
    required this.entry,
  });

  /// رقم المستند — `DSC-YYYYMMDD-####` **وهو معرّفه**.
  final String documentNumber;

  /// المستندات المكتوبة — ⛔ **ولا تكون فارغة**.
  final List<InventoryWrite> writes;

  /// قيد التدقيق — **يُكتب في المعاملة نفسها** (`ADR-0013` القاعدة 1).
  final AuditEntry entry;
}

/// طلب خصم مُتحقَّق من هوية مُنفِّذه.
final class DiscountRequest {
  /// ينشئ الطلب.
  const DiscountRequest({
    required this.actor,
    required this.requestId,
    required this.dealerId,
    required this.documentNumber,
    required this.date,
    required this.today,
    this.sourceFilter,
    this.lines = const <DiscountLineInput>[],
    this.usedAutoAllocation = false,
    this.lots = const <String, DebtLotRead>{},
    this.storedDealer,
    this.storedDocument,
    this.dealerLedger = const <ReceiptLedgerRead>[],
    this.reason,
    this.deviceInfo,
    this.surplusFieldPresent = false,
  });

  /// المُنفِّذ **بحالته الآن من خدمة المصادقة**.
  final AccountRecord actor;

  /// ★ معرّف الطلب — **وهو معرّف قيد التدقيق نفسه** (`api-overview.md` §4).
  final String requestId;

  /// المقوت المستهدف.
  final String dealerId;

  /// رقم المستند — **المخصَّص عند الإنشاء والقائم عند التعديل**.
  final String documentNumber;

  /// ★★ **تاريخ السند** — `FR-M13-06`.
  final CalendarDay date;

  /// ★ **يوم المنصّة** — ⛔ **من زمن الخادم داخل المعاملة** لا من الجهاز.
  final CalendarDay today;

  /// ★ **المصدر المحدد أو `null` لـ«الكل»** — `FR-M13-01`.
  final String? sourceFilter;

  /// سطور السند كما أقرّها المستخدم — ⛔ **لا مخرَج التوزيع التلقائي مباشرةً**.
  final List<DiscountLineInput> lines;

  /// ★ هل استُخدم التوزيع التلقائي؟ — **للتدقيق وحده**.
  final bool usedAutoAllocation;

  /// ★★ **الضمارات المقروءة داخل المعاملة** بمعرّفاتها.
  final Map<String, DebtLotRead> lots;

  /// سجل المقوت كما قُرئ — ⛔ **و`null` رفضٌ لا تجاوز**.
  final Map<String, Object?>? storedDealer;

  /// المستند القائم — `null` تعني **غيابه**.
  final Map<String, Object?>? storedDocument;

  /// ★★ **قيود دفتر المقوت** — **مقروءةً داخل المعاملة بمصادرها**.
  final List<ReceiptLedgerRead> dealerLedger;

  /// ★ سبب التعديل أو الإلغاء — **اختياريٌّ** ([`ADR-0020`]).
  final String? reason;

  /// وصف الجهاز للسجل — ⛔ بلا بيانات حساسة.
  final String? deviceInfo;

  /// ⛔⛔★★★ **هل حملت الحمولةُ حقلَ فائض؟** — `FR-M13-05` · `AT-35`.
  ///
  /// ★★ **وعَلَمٌ صريحٌ لا مبلغ** — ⟵ **لأن الرفض يقع على *وجود* الحقل
  /// لا على قيمته**: ⛔ **وفائضٌ بصفرٍ حقلٌ موجود كذلك**، ★ **وقبولُه كان
  /// يترك بابَ الحقل مفتوحاً في المخطَّط ثم يُملأ لاحقاً بلا حارس.**
  final bool surplusFieldPresent;

  /// ★★★ **المصادر التي مسّها السند فعلاً** — `schema/discounts.md`.
  ///
  /// ⛔⛔★★ **وهي مقروءةٌ من الضمارات لا من الحمولة** — ★ **وهي كذلك مدخل
  /// فحص النطاق** (القيد ②): ⟵ **فسندُ «الكل» يُفحَص على كل مصدرٍ مسّه**،
  /// ⛔ **لا على مصدرٍ واحد يُختار منها.**
  Set<String> get affectedSourceIds => <String>{
        for (final DiscountLineInput line in lines)
          if (lots[line.debtLotId] case final DebtLotRead lot) lot.sourceId,
      };
}

// ═════════════════════════════════════════════════════════════════════════
// البوابة — ★ **تُستدعى قبل فتح المعاملة وتُعاد كاملةً داخل التخطيط**
// ═════════════════════════════════════════════════════════════════════════

/// ★★ فحوص الحالة والصلاحية — **تُستدعى قبل فتح المعاملة**.
///
/// ⚠️ **ولا تفحص النطاق هنا** — ★ **لأن المصادر المتأثرة لا تُعرَف قبل قراءة
/// الضمارات داخل المعاملة**، ⟵ **وفحصُها يقع في [planDiscount] على المقروء
/// فعلاً** ⛔ **لا على ما ادّعته الحمولة.**
DiscountRejected? discountGate(
  DiscountRequest request,
  DiscountOperation operation,
) {
  // ① «التعطيل فوري ونافذ» — `authentication-policy.md` §2 القاعدة 3.
  if (request.actor.disabled) {
    return const DiscountRejected(CallableError.accountDisabled);
  }
  // ② الصلاحية — ⛔ ولا قاعدة حماية تحرس هذا المسار.
  if (!request.actor.claims.has(operation.requiredPermission)) {
    return const DiscountRejected(CallableError.permissionMissing);
  }
  // ③ معرّف الطلب إلزامي — وبدونه لا تتحقق اللاتكرارية عند إعادة الإرسال.
  if (request.requestId.trim().isEmpty) {
    return const DiscountRejected(CallableError.invalidArgument);
  }
  // ④ المقوت إلزامي — ⛔ ولا خصمَ بلا مدين.
  if (request.dealerId.trim().isEmpty) {
    return const DiscountRejected(CallableError.invalidArgument);
  }
  return null;
}

/// يخطّط عملية خصم — **دالة خالصة، وهي حارس التفويض الفعلي**.
DiscountPlan planDiscount(
  DiscountRequest request,
  DiscountOperation operation,
) {
  final DiscountRejected? gate = discountGate(request, operation);
  if (gate != null) return gate;

  if (request.documentNumber.trim().isEmpty) {
    return const DiscountRejected(CallableError.invalidArgument);
  }

  // ⑧ ⛔⛔★★★ **الفائض مرفوضٌ صراحةً** — `FR-M13-05` · `AT-35`.
  //    ★ **والفحص هنا قبل أي شيء آخر عدا البوابة**: ⟵ **فالسند الذي يحمل
  //    فائضاً ليس سندَ خصمٍ أصلاً**، ⛔ **ولا يُصحَّح بتصفير الحقل.**
  if (request.surplusFieldPresent) {
    return const DiscountRejected(CallableError.discountSurplusRejected);
  }

  // ⛔⛔★★★ **ولا حارسَ سببٍ نصّي** ([`ADR-0020`]) — ★ **اختياريٌّ إنشاءً
  //    وتعديلاً وإلغاءً**، ⛔ **ولا يُعبَّأ آلياً:** ★ **ما لم يكتبه إنسانٌ
  //    لا يُرسَل ولا يُخزَّن.**
  final String? reason = _trimmed(request.reason);

  // ★ المقوت: **موجود** — ⛔ **و`null` رفضٌ لا تجاوز**.
  if (request.storedDealer == null) {
    return const DiscountRejected(CallableError.internal);
  }

  // ⛔⛔★★ **والمقوتُ المعطَّل يُخصَم له** — ★ **بنفس علّة القبض منه**
  //    (`ERR_DIST_002`: «**يمكنك القبض منه فقط**») ⟵ **فالتعطيل يمنع
  //    *تحميلَه* ديناً جديداً**، ⛔ **لا إسقاطَ دَينٍ قائمٍ عنه**:
  //    ★ **وحارسُ نشاطٍ هنا كان يحبس ديناً لا سبيل لتصفيته.**

  final DiscountRejected? cancelled = _cancelledGate(request, operation);
  if (cancelled != null) return cancelled;

  return operation.isCancel
      ? _planCancellation(request, reason)
      : _planDiscount(request, operation, reason);
}

// ═════════════════════════════════════════════════════════════════════════
// الإنشاء والتعديل
// ═════════════════════════════════════════════════════════════════════════

DiscountPlan _planDiscount(
  DiscountRequest request,
  DiscountOperation operation,
  String? reason,
) {
  // ③ و④ ★★★ **التاريخ — والمستقبلي يسبق الصلاحية**.
  switch (validateDiscountDate(
    date: request.date,
    today: request.today,
    canBackdate: request.actor.claims.has(Permission.discountBackdate),
  )) {
    case Failure<void>(:final AppError error):
      return DiscountRejected(
        error is PermissionError
            ? CallableError.backdateDenied
            : CallableError.futureDateRejected,
      );
    case Success<void>():
      break;
  }

  // ⑥ ★★ **السطور مقابل المتبقي المقروء داخل المعاملة**.
  final Map<String, OpenDebtLot> lotsById = <String, OpenDebtLot>{
    for (final MapEntry<String, DebtLotRead> entry in request.lots.entries)
      // ⛔★★ **وضمارٌ ملغى ليس محلاً للخصم** — ★ **يُستبعَد من الخريطة**،
      //    ⟵ **فسطرٌ عليه يُرفَض بـ«ضمارٌ لم يُقرأ»** ⛔ **لا يُقبَل صامتاً.**
      if (!entry.value.isCancelled) entry.key: entry.value.asOpenLot,
  };
  final Outcome<List<ValidatedDiscountLine>> validated = validateDiscountLines(
    lines: request.lines,
    lotsById: lotsById,
  );
  if (validated
      case Failure<List<ValidatedDiscountLine>>(:final AppError error)) {
    return DiscountRejected(_mapDiscountError(error));
  }
  final List<ValidatedDiscountLine> lines =
      (validated as Success<List<ValidatedDiscountLine>>).value;

  // ② ★★★ **النطاق — على كل مصدرٍ مسّه السند فعلاً**.
  final DiscountRejected? scope = _scopeGate(request);
  if (scope != null) return scope;

  final List<InventoryWrite> writes = <InventoryWrite>[];
  final Map<String, Object?> after = _documentFields(request, lines);
  writes.add(_documentWrite(request, operation, after, reason));

  // ⑦ ★★★ **التسوية في `pricing/current` و`settlementStatus` في الأب**.
  for (final ValidatedDiscountLine line in lines) {
    writes.addAll(_settlementWrites(request: request, line: line));
  }

  // ⑤ ★★★ **حركة دائنة لكل سطر** — ⛔ **لا واحدةٌ مجمّعة**.
  writes.addAll(
    _dealerWrites(
      request: request,
      lines: lines,
      isCancelled: false,
      isCreate: operation.isCreate,
      reason: reason,
    ),
  );

  // ⛔⛔★★★ **ولا سجلَّ فائضٍ يُكتب هنا إطلاقاً** — ★ **بخلاف مسار القبض**:
  //    ⟵ **غيابٌ بنيويٌّ لا شرطٌ يُفحَص** (`FR-M13-05`).

  return DiscountAccepted(
    documentNumber: request.documentNumber,
    writes: writes,
    entry: _entry(
      request: request,
      action: operation.isCreate ? AuditAction.create : AuditAction.amend,
      reason: reason,
      valuesBefore: operation.isCreate
          ? const <String, Object?>{}
          : _changed(request.storedDocument, after, before: true),
      valuesAfter: operation.isCreate
          ? after
          : _changed(request.storedDocument, after, before: false),
    ),
  );
}

// ═════════════════════════════════════════════════════════════════════════
// الإلغاء — ★ **بالوسم** ⛔ **بلا حركة عكسية ولا حذف** (`GR-06` · `GR-07`)
// ═════════════════════════════════════════════════════════════════════════

DiscountPlan _planCancellation(DiscountRequest request, String? reason) {
  final Map<String, Object?>? stored = request.storedDocument;
  if (stored == null) {
    return const DiscountRejected(CallableError.internal);
  }

  final List<ValidatedDiscountLine> lines = _storedLines(stored, request.lots);
  final DiscountRejected? scope = _scopeGate(request, sources: <String>{
    for (final ValidatedDiscountLine line in lines) line.sourceId,
  });
  if (scope != null) return scope;

  final List<InventoryWrite> writes = <InventoryWrite>[];
  final Map<String, Object?> after = <String, Object?>{
    'status': 'cancelled',
    'cancelReason': reason,
  };
  writes.add(
    InventoryWrite(
      collectionId: discountsCollection,
      documentId: request.documentNumber,
      fields: after,
      updateMask: after.keys.toList(),
      serverTimestampFields: const <String>['lastAmendedAt'],
    ),
  );

  // ★★★ **وإلغاءُ السند يردّ المخصوم إلى الضمارات** — ⟵ **فالدين يعود
  //    مفتوحاً**، ⛔ **ولا حركةَ عكسية**: ★ **الحركة نفسُها تُوسَم ملغاة
  //    والتسوية تُعاد احتساباً** (`FR-M13-10`).
  for (final ValidatedDiscountLine line in lines) {
    writes.addAll(
      _settlementWrites(request: request, line: line, isReversal: true),
    );
  }

  writes.addAll(
    _dealerWrites(
      request: request,
      lines: lines,
      isCancelled: true,
      isCreate: false,
      reason: reason,
    ),
  );

  return DiscountAccepted(
    documentNumber: request.documentNumber,
    writes: writes,
    entry: _entry(
      request: request,
      action: AuditAction.cancel,
      reason: reason,
      valuesBefore: <String, Object?>{'status': stored['status'] ?? 'approved'},
      valuesAfter: <String, Object?>{'status': 'cancelled'},
    ),
  );
}

// ═════════════════════════════════════════════════════════════════════════
// الكتابات
// ═════════════════════════════════════════════════════════════════════════

/// ★★★ **التسوية — المبالغ في `pricing/current` والحالة في الأب** (`IQ-027`).
///
/// ⛔⛔★★★ **والمبلغ يدخل `discountedAmount` وحدَه** — ★ **عبر
/// [settlementAfterDiscount]**: ⟵ **فـ`settledAmount` لا يُمَسّ بريال**،
/// ★ **وهو ما يجعل بطاقةَ ضمار المالك تقرأ الرقمين منفصلين** (`ت-04` ·
/// `GR-40` · `FR-M15-03`).
List<InventoryWrite> _settlementWrites({
  required DiscountRequest request,
  required ValidatedDiscountLine line,
  bool isReversal = false,
}) {
  final DebtLotRead? lot = request.lots[line.debtLotId];
  if (lot == null) return const <InventoryWrite>[];

  final DebtSettlement after = settlementAfterDiscount(
    current: lot.settlement,
    // ★ **والإلغاء يطرح ما خُصِم** — ⛔ **بلا معادلةٍ ثانية**: ★ **نفس
    //   الدالة بمبلغٍ سالب** (`ADR-0009`).
    discounted: isReversal ? (Money.zero - line.amount) : line.amount,
  );

  final Map<String, Object?> pricingFields = <String, Object?>{
    'settledAmount': after.settledAmount.riyals,
    'discountedAmount': after.discountedAmount.riyals,
    'remaining': after.remaining.riyals,
  };
  final Map<String, Object?> parentFields = <String, Object?>{
    // ★★ **الحالة وحدها في الأب** — **حالةٌ لا رقم** (`IQ-027`).
    'settlementStatus': after.status.name,
  };

  return <InventoryWrite>[
    InventoryWrite(
      collectionId: '$distributionsCollection/${line.debtLotId}'
          '/$distributionPricingSubcollection',
      documentId: distributionPricingDocumentId,
      fields: pricingFields,
      // ⛔★★ **قناعٌ ضيّق** — ⟵ **فلا يُمحى `unitPrices[]` ولا `debtValue`
      //    ولا `lineTotals[]`** عند كتابة التسوية فوقها.
      updateMask: pricingFields.keys.toList(),
    ),
    InventoryWrite(
      collectionId: distributionsCollection,
      documentId: line.debtLotId,
      fields: parentFields,
      updateMask: parentFields.keys.toList(),
    ),
  ];
}

/// ★★★ **حركة دائنة لكل سطر** — `FR-M13-03` · `BR-M13-01`.
///
/// ⛔⛔★★★ **ونوعُها [DealerLedgerEntryType.discount] لا `receipt`** —
/// ★ **وهو التمييز الذي يقوم عليه `FR-M15-06-أ` كلُّه**: ⟵ **فشاشةُ حركة
/// النقد تعرض الخصم للعلم ولا تطرحه** (`schema/discounts.md` القاعدة 4)،
/// ⛔ **ونوعٌ خاطئ هنا كان يطرح من الصندوق مالاً لم يدخله أحد.**
List<InventoryWrite> _dealerWrites({
  required DiscountRequest request,
  required List<ValidatedDiscountLine> lines,
  required bool isCancelled,
  required bool isCreate,
  required String? reason,
}) {
  final String dealerName = _nameOf(request.storedDealer) ?? request.dealerId;
  final List<InventoryWrite> writes = <InventoryWrite>[];

  // ★ **قيود غيري في كل مصدر** — ⟵ **فالتعديل يستبدل قيودي لا يُراكم عليها.**
  final Set<String> mine = <String>{
    for (final ValidatedDiscountLine line in lines)
      discountLedgerEntryId(
        documentNumber: request.documentNumber,
        debtLotId: line.debtLotId,
      ),
  };

  final Map<String, List<DealerLedgerEntry>> othersBySource =
      <String, List<DealerLedgerEntry>>{};
  for (final ReceiptLedgerRead read in request.dealerLedger) {
    if (mine.contains(read.entryId)) continue;
    othersBySource
        .putIfAbsent(read.sourceId, () => <DealerLedgerEntry>[])
        .add(read.entry);
  }

  final Map<String, List<DealerLedgerEntry>> projected =
      <String, List<DealerLedgerEntry>>{
    for (final MapEntry<String, List<DealerLedgerEntry>> e
        in othersBySource.entries)
      e.key: <DealerLedgerEntry>[...e.value],
  };

  for (final ValidatedDiscountLine line in lines) {
    final String entryId = discountLedgerEntryId(
      documentNumber: request.documentNumber,
      debtLotId: line.debtLotId,
    );
    projected.putIfAbsent(line.sourceId, () => <DealerLedgerEntry>[]).add(
          DealerLedgerEntry(
            direction: DealerLedgerDirection.credit,
            amount: line.amount,
            isCancelled: isCancelled,
          ),
        );

    final Map<String, Object?> fields = <String, Object?>{
      'dealerId': request.dealerId,
      'dealerName': dealerName,
      'sourceId': line.sourceId,
      'debtLotId': line.debtLotId,
      'direction': DealerLedgerDirection.credit.name,
      'amount': line.amount.riyals,
      // ⛔⛔★★★ **«خصم» لا «قبض»** — `ت-04` · `GR-40` · `FR-M15-06-أ`.
      'entryType': DealerLedgerEntryType.discount.name,
      // ⛔⛔★★ **والنوع يُمرَّر صراحةً** — ★ **درسُ `sourceDocType` المحفور**
      //    (2026-08-26): ⛔ **لا يُفترَض ثابتٌ لأن كاتبه اليوم واحد.**
      'sourceDocType': discountEntityType,
      'sourceDocId': request.documentNumber,
      'sourceDocNumber': request.documentNumber,
      'isCancelled': isCancelled,
      'memo': line.note,
      if (!isCreate) 'amendedBy': request.actor.userId,
      if (!isCreate) 'amendReason': reason,
    };
    writes.add(
      InventoryWrite(
        collectionId: dealerLedgerCollection,
        documentId: entryId,
        fields: fields,
        updateMask: fields.keys.toList(),
        serverTimestampFields: isCreate
            ? const <String>['entryDate']
            : const <String>['lastAmendedAt'],
      ),
    );
  }

  // ★★ **سجل رصيدٍ لكل مصدرٍ مسّه السند** — ⛔ **ولا سجل جامع**.
  for (final String sourceId in projected.keys.toList()..sort()) {
    final DealerAccountBalance balance =
        computeDealerBalance(projected[sourceId]!);
    final Map<String, Object?> balanceFields = <String, Object?>{
      'dealerId': request.dealerId,
      'sourceId': sourceId,
      'totalDebit': balance.totalDebit.riyals,
      'totalCredit': balance.totalCredit.riyals,
      // ⚠️⚠️ **وهذا الحقل بعينه يقرؤه حارس تعطيل المقوت** (`FR-M4-09` ·
      //    `IQ-020`) **داخل معاملته** — ⟵ **فاسمُه عقدٌ بين وحدتين.**
      'balance': balance.balance.riyals,
    };
    writes.add(
      InventoryWrite(
        collectionId: dealerBalancesCollection,
        documentId: dealerBalanceId(
          dealerId: request.dealerId,
          sourceId: sourceId,
        ),
        fields: balanceFields,
        updateMask: balanceFields.keys.toList(),
        serverTimestampFields: const <String>['updatedAt'],
      ),
    );
  }

  return writes;
}

Map<String, Object?> _documentFields(
  DiscountRequest request,
  List<ValidatedDiscountLine> lines,
) =>
    <String, Object?>{
      'documentNumber': request.documentNumber,
      'date': request.date.asUtcMidnight(),
      'dealerId': request.dealerId,
      'dealerName': _nameOf(request.storedDealer) ?? request.dealerId,
      // ★ **«الكل» غيابُ مصدرٍ لا نصُّ «all»** — ⟵ **فالحقل يُقرأ منطقياً.**
      'sourceFilter': request.sourceFilter,
      // ★★★ **المصادر التي مسّها فعلاً** — ⟵ **وعليها فهرسٌ قائم.**
      'affectedSourceIds': <String>{
        for (final ValidatedDiscountLine line in lines) line.sourceId,
      }.toList()
        ..sort(),
      'totalDebtAtEntry': totalOpenDebt(<OpenDebtLot>[
        for (final DebtLotRead lot in request.lots.values)
          if (!lot.isCancelled) lot.asOpenLot,
      ]).riyals,
      'lines': <Object?>[
        for (final ValidatedDiscountLine line in lines)
          <String, Object?>{
            'debtLotId': line.debtLotId,
            'sourceId': line.sourceId,
            'remainingBefore': line.remainingBefore.riyals,
            // ★ **«مبلغ الخصم»** — `schema/discounts.md`: **«المبلغ الواصل»
            //   يصير «مبلغ الخصم»** ⛔ **والاسم في السلك يبقى `amount`**:
            //   ★ **فالتسميةُ فرقُ عرضٍ لا فرقُ مخطَّط.**
            'amount': line.amount.riyals,
            'remainingAfter': line.remainingAfter.riyals,
            'note': line.note,
          },
      ],
      // ⛔⛔★★★ **ولا حقلَ `surplusAmount` ولا `surplusScope` إطلاقاً** —
      //    ★ **غيابٌ بنيويٌّ من المخطَّط نفسِه** (`schema/discounts.md`).
      'usedAutoAllocation': request.usedAutoAllocation,
      'status': 'approved',
    };

InventoryWrite _documentWrite(
  DiscountRequest request,
  DiscountOperation operation,
  Map<String, Object?> fields,
  String? reason,
) {
  final Map<String, Object?> all = <String, Object?>{
    ...fields,
    if (!operation.isCreate)
      'amendCount': _amendCount(request.storedDocument) + 1,
    if (!operation.isCreate) 'amendReason': reason,
    if (!operation.isCreate) 'amendedBy': request.actor.userId,
    if (operation.isCreate) 'createdBy': request.actor.userId,
  };
  return InventoryWrite(
    collectionId: discountsCollection,
    documentId: request.documentNumber,
    fields: all,
    updateMask: all.keys.toList(),
    serverTimestampFields: operation.isCreate
        ? const <String>['createdAt']
        : const <String>['lastAmendedAt'],
  );
}

// ═════════════════════════════════════════════════════════════════════════
// الحرّاس المساعدة
// ═════════════════════════════════════════════════════════════════════════

/// ② ★★★ **النطاق على كل مصدرٍ مسّه السند** — `GR-23` · `E-35`.
DiscountRejected? _scopeGate(DiscountRequest request, {Set<String>? sources}) {
  final Set<String> affected = sources ?? request.affectedSourceIds;
  for (final String sourceId in affected) {
    if (!request.actor.claims.canAccessSource(sourceId)) {
      return const DiscountRejected(CallableError.sourceOutOfScope);
    }
  }
  // ★ **وفلترُ مصدرٍ محدد يُفحَص كذلك** — ⟵ **فسندٌ بمصدرٍ خارج النطاق
  //   لا يُفتَح أصلاً.**
  final String? filter = request.sourceFilter;
  if (filter != null && !request.actor.claims.canAccessSource(filter)) {
    return const DiscountRejected(CallableError.sourceOutOfScope);
  }
  return null;
}

/// ★ **مستندٌ ملغى لا يُعدَّل ولا يُلغى ثانيةً** — `ERR_AMEND_006`.
DiscountRejected? _cancelledGate(
  DiscountRequest request,
  DiscountOperation operation,
) {
  if (operation.isCreate) return null;
  final Object? status = request.storedDocument?['status'];
  if (status == 'cancelled') {
    return const DiscountRejected(CallableError.documentCancelled);
  }
  return null;
}

/// ★ سطور السند المخزَّنة — **لإعادة احتسابها عند الإلغاء**.
List<ValidatedDiscountLine> _storedLines(
  Map<String, Object?> stored,
  Map<String, DebtLotRead> lots,
) {
  final Object? raw = stored['lines'];
  if (raw is! List<Object?>) return const <ValidatedDiscountLine>[];
  final List<ValidatedDiscountLine> lines = <ValidatedDiscountLine>[];
  for (final Object? entry in raw) {
    if (entry is! Map<String, Object?>) continue;
    final Object? lotId = entry['debtLotId'];
    if (lotId is! String || lotId.isEmpty) continue;
    final int? amount = _asInt(entry['amount']);
    if (amount == null) continue;
    // ★ **والمصدر من الضمار المقروء إن وُجد** — ⛔ **وإلا فمن المخزَّن**:
    //   ⟵ **فضمارٌ لم يُقرأ لا يُسقِط ردَّ المبلغ في الدفتر.**
    final Object? storedSource = entry['sourceId'];
    final String? sourceId = lots[lotId]?.sourceId ??
        (storedSource is String && storedSource.isNotEmpty
            ? storedSource
            : null);
    if (sourceId == null) continue;
    lines.add(
      ValidatedDiscountLine(
        debtLotId: lotId,
        sourceId: sourceId,
        remainingBefore: Money(_asInt(entry['remainingBefore']) ?? 0),
        amount: Money(amount),
        remainingAfter: Money(_asInt(entry['remainingAfter']) ?? 0),
        note: entry['note'] is String ? entry['note']! as String : null,
      ),
    );
  }
  return lines;
}

CallableError _mapDiscountError(AppError error) => switch (error) {
      // ★ **ورمزٌ مستقلٌّ عن نظيره في القبض** — ⟵ **فرسالتُه تقول «مبلغ
      //   الخصم» لا «المبلغ الواصل»** (`error-codes-catalog.md`).
      ValidationError(ruleCode: 'BR-M13-02') =>
        CallableError.discountExceedsDebt,
      _ => CallableError.invalidArgument,
    };

AuditEntry _entry({
  required DiscountRequest request,
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
        // ⛔⛔★★ **نوعٌ مستقلٌّ عن سند القبض** — ⟵ **فسجل التدقيق نفسُه
        //    يُفرِّق بين ما دُفع وما أُسقِط** (`FR-M15-06-أ`).
        entityType: discountEntityType,
        entityId: request.documentNumber,
        documentNumber: request.documentNumber,
        // ★★ **ومصدرُ القيد فلترُ السند — و«الكل» [auditAllSourcesId]**:
        //   ⛔ **فسندٌ عابرٌ للمصادر لا يُنسَب لأحدها دون البقية.**
        sourceId: request.sourceFilter ?? auditAllSourcesId,
      ),
      valuesBefore: valuesBefore,
      valuesAfter: valuesAfter,
      deviceInfo: request.deviceInfo,
    );

Map<String, Object?> _changed(
  Map<String, Object?>? stored,
  Map<String, Object?> after, {
  required bool before,
}) {
  final Map<String, Object?> changed = <String, Object?>{};
  for (final MapEntry<String, Object?> entry in after.entries) {
    final Object? old = stored?[entry.key];
    if (_sameValue(old, entry.value)) continue;
    changed[entry.key] = before ? old : entry.value;
  }
  return changed;
}

bool _sameValue(Object? a, Object? b) {
  if (a is List<Object?> && b is List<Object?>) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (!_sameValue(a[i], b[i])) return false;
    }
    return true;
  }
  if (a is Map<String, Object?> && b is Map<String, Object?>) {
    if (a.length != b.length) return false;
    for (final MapEntry<String, Object?> e in a.entries) {
      if (!b.containsKey(e.key) || !_sameValue(e.value, b[e.key])) return false;
    }
    return true;
  }
  return a == b;
}

int _amendCount(Map<String, Object?>? stored) {
  final Object? raw = stored?['amendCount'];
  if (raw is int) return raw;
  if (raw is double && raw == raw.roundToDouble()) return raw.toInt();
  return 0;
}

int? _asInt(Object? raw) {
  if (raw is int) return raw;
  if (raw is double && raw == raw.roundToDouble()) return raw.toInt();
  if (raw is String) return int.tryParse(raw.trim());
  return null;
}

/// ★ اسم السجل المقروء أو `null` — ⛔ **والفارغ غيابٌ لا نصٌّ فارغ**.
String? _nameOf(Map<String, Object?>? stored) {
  final Object? name = stored?['name'];
  if (name is! String) return null;
  final String trimmed = name.trim();
  return trimmed.isEmpty ? null : trimmed;
}

/// ★ **الفراغات تُقرأ غياباً لا نصّاً فارغاً** — نفس قاعدة `blankToNull`.
String? _trimmed(String? value) {
  if (value == null) return null;
  final String trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

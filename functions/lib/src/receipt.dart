/// المقبوضات وحساب المقوت — **التخطيط الخالص** لعمليات `WU-007` (`M12`).
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
/// ⛔★★ **تسعة قيود بندُ قبولٍ مُلزِم لهذه الدالة** (`FR-M12`):
///
///   ① **الصلاحية** (`receiptCreate` / `receiptAmend` / `receiptCancel` /
///      `receiptDepositConfirm`).
///   ② ★★★ **نطاق المصادر — لكل مصدرٍ مسّه السند على حدة** (`GR-23` ·
///      `E-35`) — ⛔ **ولا يكفي فحصُ مصدرٍ واحد**: ★ **سندُ «الكل» يمسّ
///      مصادر عدة**، ⟵ **وفحصُ الأول وحده كان يُسدِّد ديناً في مصدرٍ خارج
///      نطاق المُنفِّذ.**
///   ③ ⛔⛔ **التاريخ المستقبلي مرفوض مطلقاً للجميع** (`FR-M12-02`) —
///      ★ **والفحص يسبق فحص الصلاحية عمداً.**
///   ④ **تاريخٌ سابق يشترط `receiptBackdate`** (`E-14`).
///   ⑤ ★★★ **حركة دائنة لكل سطر لا واحدةٌ مجمّعة** (`FR-M12-07`).
///   ⑥ ★★ **المبلغ الواصل > 0 ولا يتجاوز متبقّي ذلك الضمار** (`FR-M12-06`)
///      — ★ **مقيساً من `pricing/current` داخل المعاملة** (`IQ-027`)
///      ⛔ **لا من الجهاز.**
///   ⑦ ★★★ **مبالغ التسوية تُكتب في `pricing/current` وحده** (`IQ-027`
///      الخيار أ · `ADR-0011`) — ★ **و`settlementStatus` في الأب** (**حالةٌ
///      لا رقم**).
///   ⑧ ★★ **تأكيد الإيداع مسارٌ منفصل يقتصر على حقول الإيداع** ويشترط
///      **ملاحظة غير فارغة** (`FR-M12-18` · [`ADR-0017`]).
///   ⑨ **الحذف مرفوض نهائياً** — ⟵ **ولا مسار حذف في هذا الملف أصلاً.**
/// ═══════════════════════════════════════════════════════════════════════
library;

import 'package:qtms_domain/qtms_domain.dart';

import 'callable.dart';
import 'identity_gateway.dart';
import 'inventory.dart';

/// نوع عملية قبض — ويحدد الصلاحية التي لا تُنفَّذ بدونها.
enum ReceiptOperation {
  /// `createReceipt` — يشترط `receiptCreate` (`FR-M12` §6).
  createReceipt(Permission.receiptCreate, isCreate: true),

  /// `amendReceipt` — يشترط `receiptAmend` ★ **وسببٌ نصيٌّ اختياري**
  /// ([`ADR-0020`]).
  amendReceipt(Permission.receiptAmend, isCreate: false),

  /// `cancelReceipt` — يشترط `receiptCancel`.
  ///
  /// ⛔★★ **وليس حذفاً:** الإلغاء **وسمٌ يُستبعَد من الجمع** (`GR-06` ·
  /// `A-14`)، ★ **والحركات والقيد يبقيان مقروءَين مشطوبَين.**
  cancelReceipt(Permission.receiptCancel, isCreate: false, isCancel: true),

  /// ★★ `confirmReceiptDeposit` — يشترط `receiptDepositConfirm`
  /// **+ `receiptDepositView` + ملاحظة** (`FR-M12-15` · `FR-M12-17`).
  ///
  /// ⛔⛔★★ **ومسارٌ مستقلٌّ عن [amendReceipt] عمداً** — `FR-M12-18`:
  /// «**حقول الإيداع بمسار كتابة منفصل**» ⟵ **فمن يملك تأكيد الإيداع
  /// لا يُعدِّل مبلغاً**، ★ **ومن يُعدِّل السند لا يُقرّ إيداعاً.**
  confirmReceiptDeposit(
    Permission.receiptDepositConfirm,
    isCreate: false,
    isDeposit: true,
  );

  const ReceiptOperation(
    this.requiredPermission, {
    required this.isCreate,
    this.isCancel = false,
    this.isDeposit = false,
  });

  /// الصلاحية التي لا تُنفَّذ العملية بدونها.
  final Permission requiredPermission;

  /// هل هي إنشاء؟
  final bool isCreate;

  /// هل هي إلغاء؟
  final bool isCancel;

  /// هل هي تأكيد/تراجع إيداع؟
  final bool isDeposit;
}

/// قيدٌ قائم في دفتر المقاوته كما قُرئ — **بمعرّفه** ليُميَّز صاحبه.
final class ReceiptLedgerRead {
  /// ينشئ القراءة.
  const ReceiptLedgerRead({
    required this.entryId,
    required this.sourceId,
    required this.entry,
  });

  /// معرّف مستند القيد.
  final String entryId;

  /// ★ مصدر القيد — ⟵ **والجمع يقع داخل مصدره وحده** (`GR-20`).
  final String sourceId;

  /// القيد كما يدخل الجمع.
  final DealerLedgerEntry entry;
}

/// ★★ **ضمارٌ كما قُرئ داخل المعاملة** — **بأبيه وتسعيره معاً**.
///
/// ⛔⛔★★ **والتسوية من `pricing/current` لا من الأب** (`IQ-027`) — ★ **وهو
/// عين ما يقرؤه `readStoredSettlement` في مسار التوزيع**، ⟵ **ومصدرٌ واحد
/// للقراءة في المسارين** ⛔ **لا نسختان تفترقان.**
final class DebtLotRead {
  /// ينشئ القراءة.
  const DebtLotRead({
    required this.debtLotId,
    required this.sourceId,
    required this.stockDate,
    required this.settlement,
    required this.isCancelled,
  });

  /// معرّف الضمار — **وهو معرّف التوزيعة المركّب**.
  final String debtLotId;

  /// مصدر الضمار — ⛔ **مقروءٌ من مستنده لا من الحمولة** (`E-35`).
  final String sourceId;

  /// يوم الضمار — **مفتاح «الأقدم أولاً»**.
  final CalendarDay stockDate;

  /// ★ التسوية الحالية — **القيمة والمسدَّد والمخصوم والمتبقي**.
  final DebtSettlement settlement;

  /// ★★ **هل التوزيعة ملغاة؟** — ⟵ **ولا يُسدَّد ضمارٌ ملغى** (`A-14`).
  final bool isCancelled;

  /// الضمار المفتوح كما تراه طبقة النطاق.
  OpenDebtLot get asOpenLot => OpenDebtLot(
        debtLotId: debtLotId,
        sourceId: sourceId,
        stockDate: stockDate,
        remaining: settlement.remaining,
      );
}

/// نتيجة التخطيط — إما خطة كتابة وإما رفض مصنَّف.
sealed class ReceiptPlan {
  /// ينشئ النتيجة.
  const ReceiptPlan();
}

/// رُفض الطلب قبل أي كتابة.
final class ReceiptRejected extends ReceiptPlan {
  /// ينشئ رفضاً.
  const ReceiptRejected(this.error);

  /// رمز الرفض من كتالوج الأخطاء.
  final CallableError error;
}

/// قُبل الطلب — وهذه كتاباته وقيده.
final class ReceiptAccepted extends ReceiptPlan {
  /// ينشئ خطة مقبولة.
  const ReceiptAccepted({
    required this.documentNumber,
    required this.writes,
    required this.entry,
  });

  /// رقم المستند — `RCP-YYYYMMDD-####` **وهو معرّفه**.
  final String documentNumber;

  /// المستندات المكتوبة — ⛔ **ولا تكون فارغة**.
  final List<InventoryWrite> writes;

  /// قيد التدقيق — **يُكتب في المعاملة نفسها** (`ADR-0013` القاعدة 1).
  final AuditEntry entry;
}

/// طلب قبض مُتحقَّق من هوية مُنفِّذه.
final class ReceiptRequest {
  /// ينشئ الطلب.
  const ReceiptRequest({
    required this.actor,
    required this.requestId,
    required this.dealerId,
    required this.documentNumber,
    required this.date,
    required this.today,
    this.sourceFilter,
    this.lines = const <ReceiptLineInput>[],
    this.surplusAmount = Money.zero,
    this.surplusScope = SurplusScope.general,
    this.usedAutoAllocation = false,
    this.lots = const <String, DebtLotRead>{},
    this.storedDealer,
    this.storedDocument,
    this.storedSurplus,
    this.dealerLedger = const <ReceiptLedgerRead>[],
    this.depositNote,
    this.depositState,
    this.storedDeposit,
    this.reason,
    this.deviceInfo,
  });

  /// المُنفِّذ **بحالته الآن من خدمة المصادقة**.
  final AccountRecord actor;

  /// ★ معرّف الطلب — **وهو معرّف قيد التدقيق نفسه** (`api-overview.md` §4).
  final String requestId;

  /// المقوت المستهدف.
  final String dealerId;

  /// رقم المستند — **المخصَّص عند الإنشاء والقائم عند التعديل**.
  final String documentNumber;

  /// ★★ **تاريخ السند** — `FR-M12-01` · `FR-M12-02`.
  ///
  /// ⚠️⚠️ **وهو تاريخ «المقبوض في تاريخ»** ⛔ **لا تاريخ الضمار المسدَّد**
  /// (`GR-41` · `FR-M12-20`) — ★ **والرقمان لا يُخلطان.**
  final CalendarDay date;

  /// ★ **يوم المنصّة** — ⛔ **من زمن الخادم داخل المعاملة** لا من الجهاز.
  final CalendarDay today;

  /// ★ **المصدر المحدد أو `null` لـ«الكل»** — `FR-M12-04`.
  final String? sourceFilter;

  /// سطور السند كما أقرّها المستخدم — ⛔ **لا مخرَج التوزيع التلقائي مباشرةً**.
  final List<ReceiptLineInput> lines;

  /// ★ **مبلغ إضافي (فائض)** — `FR-M12-09`.
  final Money surplusAmount;

  /// نطاق الفائض — `FR-M12-12`.
  final SurplusScope surplusScope;

  /// ★ هل استُخدم التوزيع التلقائي؟ — **للتدقيق وحده** (`schema/receipts.md`).
  final bool usedAutoAllocation;

  /// ★★ **الضمارات المقروءة داخل المعاملة** بمعرّفاتها.
  final Map<String, DebtLotRead> lots;

  /// سجل المقوت كما قُرئ — ⛔ **و`null` رفضٌ لا تجاوز**.
  final Map<String, Object?>? storedDealer;

  /// المستند القائم — `null` تعني **غيابه**.
  final Map<String, Object?>? storedDocument;

  /// ★★ **سجل الفائض القائم** — ⛅ **وهو مشتقٌّ يحمل «المتاح» مباشرةً**
  /// (`data-dictionary.md` §4: «**الفائض المتاح · تاريخ آخر إدخال**»)،
  /// ⛔ **لا مدفوعاً ومُطبَّقاً منفصلَين.**
  final Map<String, Object?>? storedSurplus;

  /// ★★ **قيود دفتر المقوت** — **مقروءةً داخل المعاملة بمصادرها**.
  final List<ReceiptLedgerRead> dealerLedger;

  /// ★ **ملاحظة الإيداع** — **إلزامية عند التأكيد** (`FR-M12-15`).
  final String? depositNote;

  /// الحالة المطلوبة للإيداع — **تأكيدٌ أم تراجع** (`FR-M12-17`).
  final DepositState? depositState;

  /// مستند الإيداع القائم — **لقراءة القيمة «قبل»** (`FR-M12-17`).
  final Map<String, Object?>? storedDeposit;

  /// ★ سبب التعديل أو الإلغاء — **اختياريٌّ** ([`ADR-0020`]).
  final String? reason;

  /// وصف الجهاز للسجل — ⛔ بلا بيانات حساسة.
  final String? deviceInfo;

  /// ★★★ **المصادر التي مسّها السند فعلاً** — `schema/receipts.md`
  /// (`affectedSourceIds`).
  ///
  /// ⛔⛔★★ **وهي مقروءةٌ من الضمارات لا من الحمولة** — ★ **وهي كذلك مدخل
  /// فحص النطاق** (القيد ②): ⟵ **فسندُ «الكل» يُفحَص على كل مصدرٍ مسّه**،
  /// ⛔ **لا على مصدرٍ واحد يُختار منها.**
  Set<String> get affectedSourceIds => <String>{
        for (final ReceiptLineInput line in lines)
          if (lots[line.debtLotId] case final DebtLotRead lot) lot.sourceId,
        if (surplusScope == SurplusScope.source && sourceFilter != null)
          sourceFilter!,
      };
}

// ═════════════════════════════════════════════════════════════════════════
// البوابة — ★ **تُستدعى قبل فتح المعاملة وتُعاد كاملةً داخل التخطيط**
// ═════════════════════════════════════════════════════════════════════════

/// ★★ فحوص الحالة والصلاحية — **تُستدعى قبل فتح المعاملة**.
///
/// ⚠️ **ولا تفحص النطاق هنا** — ★ **لأن المصادر المتأثرة لا تُعرَف قبل قراءة
/// الضمارات داخل المعاملة**، ⟵ **وفحصُها يقع في [planReceipt] على المقروء
/// فعلاً** ⛔ **لا على ما ادّعته الحمولة.**
ReceiptRejected? receiptGate(
  ReceiptRequest request,
  ReceiptOperation operation,
) {
  // ① «التعطيل فوري ونافذ» — `authentication-policy.md` §2 القاعدة 3.
  if (request.actor.disabled) {
    return const ReceiptRejected(CallableError.accountDisabled);
  }
  // ② الصلاحية — ⛔ ولا قاعدة حماية تحرس هذا المسار.
  if (!request.actor.claims.has(operation.requiredPermission)) {
    return const ReceiptRejected(CallableError.permissionMissing);
  }
  // ③ ★★ **وتأكيد الإيداع يشترط رؤيتَه كذلك** — `FR-M12` §6: «**تأكيد
  //    الإيداع يتطلب «عرض حالة الإيداع» + «تأكيد الإيداع» + ملاحظة**».
  //    ⟵ **صلاحيتان لا تُغني إحداهما عن الأخرى.**
  if (operation.isDeposit &&
      !request.actor.claims.has(Permission.receiptDepositView)) {
    return const ReceiptRejected(CallableError.permissionMissing);
  }
  // ④ معرّف الطلب إلزامي — وبدونه لا تتحقق اللاتكرارية عند إعادة الإرسال.
  if (request.requestId.trim().isEmpty) {
    return const ReceiptRejected(CallableError.invalidArgument);
  }
  // ⑤ المقوت إلزامي — ⛔ ولا قبض بلا دافع.
  if (request.dealerId.trim().isEmpty) {
    return const ReceiptRejected(CallableError.invalidArgument);
  }
  return null;
}

/// يخطّط عملية قبض — **دالة خالصة، وهي حارس التفويض الفعلي**.
ReceiptPlan planReceipt(
  ReceiptRequest request,
  ReceiptOperation operation,
) {
  final ReceiptRejected? gate = receiptGate(request, operation);
  if (gate != null) return gate;

  if (request.documentNumber.trim().isEmpty) {
    return const ReceiptRejected(CallableError.invalidArgument);
  }

  // ⛔⛔★★★ **ولا حارسَ سببٍ نصّي** ([`ADR-0020`]) — ★ **اختياريٌّ إنشاءً
  //    وتعديلاً وإلغاءً**، ⛔ **ولا يُعبَّأ آلياً:** ★ **ما لم يكتبه إنسانٌ
  //    لا يُرسَل ولا يُخزَّن.**
  final String? reason = _trimmed(request.reason);

  if (operation.isDeposit) return _planDeposit(request, reason);

  // ★ المقوت: **موجودٌ ونشط** — ⛔ **و`null` رفضٌ لا تجاوز**.
  if (request.storedDealer == null) {
    return const ReceiptRejected(CallableError.internal);
  }

  // ⛔⛔★★ **والمقوتُ المعطَّل يُقبَض منه** — ★ **بنصّ `ERR_DIST_002`:
  //    «لا يمكن التوزيع … يمكنك القبض منه فقط»** ⟵ **فلا حارسَ نشاطٍ هنا**،
  //    ⛔ **وإضافتُه كانت ستحبس ديناً قائماً بلا سبيلٍ لتحصيله.**

  final ReceiptRejected? cancelled = _cancelledGate(request, operation);
  if (cancelled != null) return cancelled;

  return operation.isCancel
      ? _planCancellation(request, reason)
      : _planReceipt(request, operation, reason);
}

// ═════════════════════════════════════════════════════════════════════════
// الإنشاء والتعديل
// ═════════════════════════════════════════════════════════════════════════

ReceiptPlan _planReceipt(
  ReceiptRequest request,
  ReceiptOperation operation,
  String? reason,
) {
  // ③ و④ ★★★ **التاريخ — والمستقبلي يسبق الصلاحية**.
  switch (validateReceiptDate(
    date: request.date,
    today: request.today,
    canBackdate: request.actor.claims.has(Permission.receiptBackdate),
  )) {
    case Failure<void>(:final AppError error):
      return ReceiptRejected(
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
      // ⛔★★ **وضمارٌ ملغى ليس محلاً للسداد** — ★ **يُستبعَد من الخريطة**،
      //    ⟵ **فسطرٌ عليه يُرفَض بـ«ضمارٌ لم يُقرأ»** ⛔ **لا يُقبَل صامتاً.**
      if (!entry.value.isCancelled) entry.key: entry.value.asOpenLot,
  };
  final Outcome<List<ValidatedReceiptLine>> validated = validateReceiptLines(
    lines: request.lines,
    lotsById: lotsById,
    surplusAmount: request.surplusAmount,
  );
  if (validated case Failure<List<ValidatedReceiptLine>>(:final AppError error)) {
    return ReceiptRejected(_mapReceiptError(error));
  }
  final List<ValidatedReceiptLine> lines =
      (validated as Success<List<ValidatedReceiptLine>>).value;

  // ⛔★★ **وفائضٌ سالب رفضٌ لا صفرٌ مُصحَّح** — ★ **فمبلغٌ سالب في سندِ
  //    قبضٍ إمّا خللُ عميل وإمّا محاولةُ عكسٍ ملتوية**، ⟵ **وكلاهما يُرفَض.**
  if (request.surplusAmount.isNegative) {
    return const ReceiptRejected(CallableError.invalidArgument);
  }

  // ② ★★★ **النطاق — على كل مصدرٍ مسّه السند فعلاً**.
  final ReceiptRejected? scope = _scopeGate(request);
  if (scope != null) return scope;

  final List<InventoryWrite> writes = <InventoryWrite>[];
  final Map<String, Object?> after = _documentFields(request, lines);
  writes.add(_documentWrite(request, operation, after, reason));

  // ⑦ ★★★ **التسوية في `pricing/current` و`settlementStatus` في الأب**.
  for (final ValidatedReceiptLine line in lines) {
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

  // ★ **سجل الفائض** — ⛔ **ولا يُكتب سجلٌ بصفر بلا داعٍ** (`ADR-0008` ⑤).
  final InventoryWrite? surplus = _surplusWrite(request);
  if (surplus != null) writes.add(surplus);

  return ReceiptAccepted(
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

ReceiptPlan _planCancellation(ReceiptRequest request, String? reason) {
  final Map<String, Object?>? stored = request.storedDocument;
  if (stored == null) {
    return const ReceiptRejected(CallableError.internal);
  }

  final List<ValidatedReceiptLine> lines = _storedLines(stored, request.lots);
  final ReceiptRejected? scope = _scopeGate(request, sources: <String>{
    for (final ValidatedReceiptLine line in lines) line.sourceId,
  });
  if (scope != null) return scope;

  final List<InventoryWrite> writes = <InventoryWrite>[];
  final Map<String, Object?> after = <String, Object?>{
    'status': 'cancelled',
    'cancelReason': reason,
  };
  writes.add(
    InventoryWrite(
      collectionId: receiptsCollection,
      documentId: request.documentNumber,
      fields: after,
      updateMask: after.keys.toList(),
      serverTimestampFields: const <String>['lastAmendedAt'],
    ),
  );

  // ★★★ **وإلغاءُ السند يردّ المسدَّد إلى الضمارات** — ⟵ **فالدين يعود
  //    مفتوحاً**، ⛔ **ولا حركةَ عكسية**: ★ **الحركة نفسُها تُوسَم ملغاة
  //    والتسوية تُعاد احتساباً** (`FR-M12-21`: «**وتُعاد حالة الضمارات
  //    احتساباً**»).
  for (final ValidatedReceiptLine line in lines) {
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

  // ★★★ **والفائض يُسحَب كذلك** — ⟵ **فسندٌ ملغى لا يُبقي رصيداً يُسدَّد منه.**
  final InventoryWrite? surplus = _surplusWrite(request, isCancel: true);
  if (surplus != null) writes.add(surplus);

  return ReceiptAccepted(
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
// ⑧ ★★ الإيداع البنكي — [`ADR-0017`] · `FR-M12-15` … `FR-M12-18`
// ═════════════════════════════════════════════════════════════════════════

ReceiptPlan _planDeposit(ReceiptRequest request, String? reason) {
  final DepositState? target = request.depositState;
  if (target == null) {
    return const ReceiptRejected(CallableError.invalidArgument);
  }
  if (request.storedDocument == null) {
    return const ReceiptRejected(CallableError.internal);
  }

  // ⛔⛔★★ **والملاحظة إلزامية في الاتجاهين** — `FR-M12-17`: «**التراجع
  //    يتطلب نفس الصلاحية ويُسجَّل قيداً مستقلاً بالقيمة قبل وبعد**»،
  //    ★ **ونصّ `GR-38` يشترط الملاحظة للتغيير نفسِه** ⟵ **فتراجعٌ بلا
  //    ملاحظة كان يمحو إقراراً موثَّقاً بلا أثرٍ يشرح لماذا.**
  if (validateDepositConfirmation(note: request.depositNote)
      is Failure<void>) {
    return const ReceiptRejected(CallableError.depositNoteMissing);
  }

  final bool isDeposited = target == DepositState.deposited;
  final Map<String, Object?> fields = <String, Object?>{
    'isDeposited': isDeposited,
    'depositNote': request.depositNote!.trim(),
    'depositedBy': request.actor.userId,
  };

  return ReceiptAccepted(
    documentNumber: request.documentNumber,
    writes: <InventoryWrite>[
      InventoryWrite(
        // ⛅★★ **المسار المقيَّد وحده** — ⛔ **ولا حقلَ من الأب يُمَسّ هنا**
        //    (`FR-M12-18`): ★ **فمن يملك تأكيد الإيداع لا يُعدِّل مبلغاً.**
        collectionId: '$receiptsCollection/${request.documentNumber}'
            '/$receiptDepositSubcollection',
        documentId: receiptDepositDocumentId,
        fields: fields,
        updateMask: fields.keys.toList(),
        serverTimestampFields: const <String>['depositedAt'],
      ),
    ],
    entry: _entry(
      request: request,
      action: AuditAction.amend,
      reason: reason,
      // ★★ **القيمة قبل وبعد صراحةً** — `FR-M12-17`.
      valuesBefore: <String, Object?>{
        'isDeposited': _storedDepositFlag(request.storedDeposit),
      },
      valuesAfter: <String, Object?>{'isDeposited': isDeposited},
    ),
  );
}

bool _storedDepositFlag(Map<String, Object?>? stored) {
  final Object? raw = stored?['isDeposited'];
  return raw is bool && raw;
}

// ═════════════════════════════════════════════════════════════════════════
// الكتابات
// ═════════════════════════════════════════════════════════════════════════

/// ★★★ **التسوية — المبالغ في `pricing/current` والحالة في الأب** (`IQ-027`).
List<InventoryWrite> _settlementWrites({
  required ReceiptRequest request,
  required ValidatedReceiptLine line,
  bool isReversal = false,
}) {
  final DebtLotRead? lot = request.lots[line.debtLotId];
  if (lot == null) return const <InventoryWrite>[];

  final DebtSettlement after = settlementAfterReceipt(
    current: lot.settlement,
    // ★ **والإلغاء يطرح ما سُدِّد** — ⛔ **بلا معادلةٍ ثانية**: ★ **نفس
    //   الدالة بمبلغٍ سالب** (`ADR-0009`).
    received: isReversal ? (Money.zero - line.amount) : line.amount,
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

/// ★★★ **حركة دائنة لكل سطر** — `FR-M12-07` · `BR-M12-01`.
///
/// ⛔⛔★★★ **والرصيد يُجمَع لكل مصدرٍ على حدة** (`GR-20`) — ★ **فسندُ «الكل»
/// يُنتج سجلَّ رصيدٍ لكل مصدرٍ مسّه**، ⛔ **لا سجلاً واحداً جامعاً**:
/// ⟵ **والجامعُ كان يخلط ذمم مصدرين في رقمٍ لا يقابله دفتر.**
List<InventoryWrite> _dealerWrites({
  required ReceiptRequest request,
  required List<ValidatedReceiptLine> lines,
  required bool isCancelled,
  required bool isCreate,
  required String? reason,
}) {
  final String dealerName = _nameOf(request.storedDealer) ?? request.dealerId;
  final List<InventoryWrite> writes = <InventoryWrite>[];

  // ★ **قيود غيري في كل مصدر** — ⟵ **فالتعديل يستبدل قيودي لا يُراكم عليها.**
  final Set<String> mine = <String>{
    for (final ValidatedReceiptLine line in lines)
      receiptLedgerEntryId(
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

  for (final ValidatedReceiptLine line in lines) {
    final String entryId = receiptLedgerEntryId(
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
      'entryType': DealerLedgerEntryType.receipt.name,
      // ⛔⛔★★ **والنوع يُمرَّر صراحةً** — ★ **درسُ `sourceDocType` المحفور**
      //    (2026-08-26): ⛔ **لا يُفترَض ثابتٌ لأن كاتبه اليوم واحد.**
      'sourceDocType': receiptEntityType,
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

/// ★★★ **سجل الفائض** — ⛅ **مشتقٌّ يحمل «المتاح» كما يوثّقه
/// `data-dictionary.md` §4** (نفس نمط `dealer_balances`).
///
/// ⛔⛔★★★ **والتعديل يطرح مساهمة هذا السند القديمة قبل أن يُضيف الجديدة** —
/// ★ **حرفياً كما يفعل الرصيد بـ«قيود غيري + قيدي»**: ⟵ **وإلّا لَراكَم
/// تعديلُ سندٍ فائضَه مرتين** ⛔ **فصار للمقوت رصيدٌ لم يدفعه.**
///
/// ⛔★★ **ولا يُكتب سجلٌ بصفر بلا داعٍ عند الإنشاء** (`ADR-0008` القاعدة 5)
/// — ★ **ويُكتب عند التعديل والإلغاء ولو صار صفراً**، ⟵ **لأن سجلاً قائماً
/// يحمل فائضاً مُلغىً يجب أن يُصفَّر** ⛔ **لا أن يُترَك يُسدِّد ضمارات.**
InventoryWrite? _surplusWrite(ReceiptRequest request, {bool isCancel = false}) {
  final Money previous = Money(_asInt(request.storedDocument?['surplusAmount']) ?? 0);
  final Money next = isCancel ? Money.zero : request.surplusAmount;
  if (next.isZero && previous.isZero) return null;

  // ★ **ونطاق السجل من المخزَّن عند الإلغاء** — ⛔ **فالإلغاء لا يحمل حمولة.**
  final SurplusScope scope = isCancel
      ? (request.storedDocument?['surplusScope'] == SurplusScope.source.name
          ? SurplusScope.source
          : SurplusScope.general)
      : request.surplusScope;
  final String? scopeSource = isCancel
      ? (request.storedDocument?['sourceFilter'] as String?)
      : request.sourceFilter;
  if (scope == SurplusScope.source && (scopeSource == null || scopeSource.isEmpty)) {
    return null;
  }

  final Money stored = Money(_asInt(request.storedSurplus?['availableAmount']) ?? 0);
  final Map<String, Object?> fields = <String, Object?>{
    'dealerId': request.dealerId,
    'scope': scope.name,
    'sourceId': scope == SurplusScope.source ? scopeSource : null,
    // ★★★ **المتاح = (المخزَّن + الجديد) − القديم** — ⛔ **ولا يهبط تحت الصفر**
    //    ([availableSurplus] — **المعادلة في طبقة النطاق وحدها**).
    'availableAmount':
        availableSurplus(paid: stored + next, applied: previous).riyals,
    'lastPaidOn': request.date.asUtcMidnight(),
    'lastReceiptNumber': request.documentNumber,
  };
  return InventoryWrite(
    collectionId: dealerSurplusCollection,
    documentId: dealerSurplusId(
      dealerId: request.dealerId,
      scope: scope,
      sourceId: scopeSource,
    ),
    fields: fields,
    updateMask: fields.keys.toList(),
    serverTimestampFields: const <String>['updatedAt'],
  );
}

Map<String, Object?> _documentFields(
  ReceiptRequest request,
  List<ValidatedReceiptLine> lines,
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
        for (final ValidatedReceiptLine line in lines) line.sourceId,
      }.toList()
        ..sort(),
      'totalDebtAtEntry': totalOpenDebt(<OpenDebtLot>[
        for (final DebtLotRead lot in request.lots.values)
          if (!lot.isCancelled) lot.asOpenLot,
      ]).riyals,
      'lines': <Object?>[
        for (final ValidatedReceiptLine line in lines)
          <String, Object?>{
            'debtLotId': line.debtLotId,
            'sourceId': line.sourceId,
            'remainingBefore': line.remainingBefore.riyals,
            'amount': line.amount.riyals,
            'remainingAfter': line.remainingAfter.riyals,
            'note': line.note,
          },
      ],
      'surplusAmount': request.surplusAmount.riyals,
      'surplusScope': request.surplusScope.name,
      'usedAutoAllocation': request.usedAutoAllocation,
      'status': 'approved',
    };

InventoryWrite _documentWrite(
  ReceiptRequest request,
  ReceiptOperation operation,
  Map<String, Object?> fields,
  String? reason,
) {
  final Map<String, Object?> all = <String, Object?>{
    ...fields,
    if (!operation.isCreate) 'amendCount': _amendCount(request.storedDocument) + 1,
    if (!operation.isCreate) 'amendReason': reason,
    if (!operation.isCreate) 'amendedBy': request.actor.userId,
    if (operation.isCreate) 'createdBy': request.actor.userId,
  };
  return InventoryWrite(
    collectionId: receiptsCollection,
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
ReceiptRejected? _scopeGate(ReceiptRequest request, {Set<String>? sources}) {
  final Set<String> affected = sources ?? request.affectedSourceIds;
  for (final String sourceId in affected) {
    if (!request.actor.claims.canAccessSource(sourceId)) {
      return const ReceiptRejected(CallableError.sourceOutOfScope);
    }
  }
  // ★ **وفلترُ مصدرٍ محدد يُفحَص كذلك** — ⟵ **فسندٌ بمصدرٍ خارج النطاق
  //   وبلا سطور (فائضٌ وحده) كان يمرّ بلا فحص.**
  final String? filter = request.sourceFilter;
  if (filter != null && !request.actor.claims.canAccessSource(filter)) {
    return const ReceiptRejected(CallableError.sourceOutOfScope);
  }
  return null;
}

/// ★ **مستندٌ ملغى لا يُعدَّل ولا يُلغى ثانيةً** — `ERR_AMEND_006`.
ReceiptRejected? _cancelledGate(
  ReceiptRequest request,
  ReceiptOperation operation,
) {
  if (operation.isCreate) return null;
  final Object? status = request.storedDocument?['status'];
  if (status == 'cancelled') {
    return const ReceiptRejected(CallableError.documentCancelled);
  }
  return null;
}

/// ★ سطور السند المخزَّنة — **لإعادة احتسابها عند الإلغاء**.
List<ValidatedReceiptLine> _storedLines(
  Map<String, Object?> stored,
  Map<String, DebtLotRead> lots,
) {
  final Object? raw = stored['lines'];
  if (raw is! List<Object?>) return const <ValidatedReceiptLine>[];
  final List<ValidatedReceiptLine> lines = <ValidatedReceiptLine>[];
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
      ValidatedReceiptLine(
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

CallableError _mapReceiptError(AppError error) => switch (error) {
      ValidationError(ruleCode: 'BR-M12-02') => CallableError.receiptExceedsDebt,
      _ => CallableError.invalidArgument,
    };

AuditEntry _entry({
  required ReceiptRequest request,
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
        entityType: receiptEntityType,
        // ★★ **ورقم المستند هو معرّفه** — ⛔ **بخلاف التوزيعة** (`receipts`
        //    مفتاحُها `documentNumber`)، ⟵ **والسجل السياقي 🕘 يستعلم به.**
        entityId: request.documentNumber,
        documentNumber: request.documentNumber,
        // ★★ **ومصدرُ القيد فلترُ السند — و«الكل» [auditAllSourcesId]**:
        //   ⛔ **فسندٌ عابرٌ للمصادر لا يُنسَب لأحدها دون البقية**،
        //   ★ **وأثرُها في الاتجاه الآمن**: `inScope('all')` **لا تصدُق إلا
        //   لمن نطاقه `all`** ⟵ **فالقيد يضيق ولا يتّسع.**
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

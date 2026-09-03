/// تنفيذ عمليات الخصم — **الطرف الذي يلمس الشبكة** (`WU-013`).
///
/// ★ **مفصول عن `discount.dart` عمداً**، بنفس منطق `receipt_handler.dart`:
/// كل قرار تفويض وقاعدة عمل هناك في **دوال خالصة تُختبَر بلا سحابة**؛
/// وهنا **الترتيب والقراءة والالتزام** وحدها.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ★★★ **وتاريخ السند هنا ليس يوم المنصّة — كسند القبض تماماً**
///
/// `FR-M13-06`: «**التاريخ الافتراضي اليوم، ويقبل سابقاً بصلاحية «خصم
/// بتاريخ سابق»، ولا يقبل مستقبلياً**» ⟵ ★ **فالتاريخ يصل من الجهاز**،
/// **ويُقابَل بيوم المنصّة داخل المعاملة** ([validateDiscountDate]).
///
/// ★★ **ورقمُ المستند يُخصَّص بيوم المنصّة لا بتاريخ السند** — ⟵ **فالعدّاد
/// اليومي عدّادُ إدخالٍ لا عدّادُ ذمة**، ⛔ **وخلطُهما كان يُنتج رقمين
/// متطابقين لسندين أُدخِلا اليوم بتاريخين سابقين مختلفين.**
///
/// ⛔⛔★★★ **ولا مسارَ إيداعٍ بنكي ولا سجلَّ فائضٍ في هذا الملف إطلاقاً** —
/// ★ **غيابٌ بنيويٌّ لا فرعٌ يُتخطّى** (`FR-M13` §2 · `FR-M13-05`):
/// ⟵ **لا نقدَ دخل فلا شيءَ يُودَع، ولا فائضَ فلا سجلَّ يُقرأ ولا يُكتب.**
/// ═══════════════════════════════════════════════════════════════════════
library;

import 'package:qtms_domain/qtms_domain.dart';
import 'package:shelf/shelf.dart';

import 'audited_transaction.dart';
import 'callable.dart';
import 'counter_allocator.dart' show counterValueField;
import 'discount.dart';
import 'distribution_handler.dart' show readStoredSettlement;
import 'identity_gateway.dart';
import 'inventory.dart';
import 'inventory_handler.dart' show platformDayOf, readInt;
import 'permission_sync_handler.dart' show requestIdField;
import 'owner_ledger_summary_handler.dart';
import 'receipt.dart' show DebtLotRead, ReceiptLedgerRead;

/// اسم حقل سبب التعديل أو الإلغاء في الحمولة.
const String discountReasonField = 'reason';

/// مفتاح استعلام قيود دفتر المقوت داخل المعاملة.
const String discountDealerLedgerQueryKey = 'discountDealerLedger';

/// ★ حدّ قراءة قيود المقوت — ⛔ **وتجاوزُه رفضٌ لا جمعٌ ناقص**.
///
/// ⚠️ **وهو نظيرُ `receiptDealerLedgerLimit` بعينه** — ★ **لأن سند «الكل»
/// يمسّ كل مصادر المقوت** (`FR-M13-01`)، ⟵ **فالقراءة نفسُها والحدُّ نفسُه.**
/// ⚠️ **وهو حدٌّ معلَن لا مطويّ** — ★ **ويُسجَّل مع `DEBT-42` نفسِه.**
const int discountDealerLedgerLimit = 1500;

/// منفّذ عمليات الخصم.
final class DiscountHandler {
  /// ينشئ المنفّذ بتبعياته — ★ **تُحقَن، فيُختبَر بلا سحابة**.
  const DiscountHandler({
    required IdentityGateway identity,
    required AuditedTransaction transaction,
    DateTime Function()? clock,
    OwnerLedgerSummaryHandler? summaries,
  })  : _identity = identity,
        _transaction = transaction,
        _summaries = summaries,
        _clock = clock;

  final IdentityGateway _identity;
  final AuditedTransaction _transaction;

  /// ⛅★★★ **باني ملخصات ضمار المالك** (`WU-016`) — ★ **يُطلَق بعد الالتزام**.
  ///
  /// ⛔⛔★★ **وعلى يوم الضمار المخصوم لا يوم السند** — `FR-M15-06`:
  /// ★ **«الخصومات» بندٌ ثالثٌ مستقلٌّ عن «الواصل»**، ⟵ **ويخصّ ضماراتِ
  /// ذلك اليوم**: ⛔ **وخصمُ اليومِ لضمار أمس يُعيد بناءَ بطاقةِ أمس.**
  final OwnerLedgerSummaryHandler? _summaries;

  /// ★ ساعةُ **الاقتراح** وحدها — ⛔ **ولا تُكتب قيمتها في أي حقل** بلا
  /// موافقة المنصّة. تُحقَن في الاختبار.
  final DateTime Function()? _clock;

  DateTime _now() => (_clock ?? DateTime.now)().toUtc();

  /// ينفّذ [operation] على طلب HTTP خام.
  Future<Response> handle(
    Request httpRequest,
    DiscountOperation operation,
  ) async {
    final CallableParse parsed = await parseCallableRequest(httpRequest);
    if (parsed is RejectedCallable) return callableFailure(parsed.error);
    final CallableRequest call = (parsed as ParsedCallable).request;

    try {
      return await _execute(call, operation);
    } on IdentityGatewayException catch (error) {
      return callableFailure(
        CallableError.sessionExpired,
        detail: error.diagnostic,
      );
    } on AbortTransaction catch (aborted) {
      return callableFailure(aborted.reason as CallableError);
    } on TransactionContentionException catch (error) {
      return callableFailure(CallableError.concurrency, detail: '$error');
    }
  }

  Future<Response> _execute(
    CallableRequest call,
    DiscountOperation operation,
  ) async {
    final AccountRecord actor = await _identity.verifyIdToken(call.idToken);
    final String? requestId = call.readString(requestIdField);
    final String? dealerId = call.readString('dealerId');
    if (requestId == null || dealerId == null) {
      return callableFailure(CallableError.invalidArgument);
    }

    // ① البوابة — ⛔ قبل أي معاملة: الحالة والصلاحية.
    //   ⚠️ **والنطاق ليس هنا** — ★ **لأن المصادر المتأثرة تُقرأ من الضمارات
    //   داخل المعاملة** ([planDiscount] يفحصها على المقروء فعلاً).
    final DiscountRejected? gate = discountGate(
      DiscountRequest(
        actor: actor,
        requestId: requestId,
        dealerId: dealerId,
        documentNumber: _pendingDocumentNumber,
        date: CalendarDay.fromUtc(_now()),
        today: CalendarDay.fromUtc(_now()),
      ),
      operation,
    );
    if (gate != null) return callableFailure(gate.error);

    return operation.isCreate
        ? _create(call, actor, requestId, dealerId)
        : _amendOrCancel(call, actor, requestId, dealerId, operation);
  }

  // ═════════════════════════════════════════════════════════════════════
  // الإنشاء
  // ═════════════════════════════════════════════════════════════════════

  Future<Response> _create(
    CallableRequest call,
    AccountRecord actor,
    String requestId,
    String dealerId,
  ) async {
    // ⛔⛔★★★ **والفائضُ يُرفَض قبل أي قراءة** — `FR-M13-05` · `AT-35`:
    //    ★ **فلا تُفتَح معاملةٌ لسندٍ ليس سندَ خصمٍ أصلاً.**
    if (_carriesSurplus(call)) {
      return callableFailure(CallableError.discountSurplusRejected);
    }
    final _DiscountPayload? payload = _readPayload(call);
    if (payload == null) return callableFailure(CallableError.invalidArgument);

    CalendarDay day = CalendarDay.fromUtc(_now());
    String? number;
    final Set<OwnerLedgerDay> touched = <OwnerLedgerDay>{};
    CalendarDay? platformToday;
    for (int attempt = 0; attempt < 2; attempt++) {
      touched.clear();
      final _DayMismatch? drift = await _runCreate(
        actor: actor,
        requestId: requestId,
        dealerId: dealerId,
        payload: payload,
        day: day,
        onAllocated: (String allocated) => number = allocated,
        onLots: (Set<OwnerLedgerDay> lots, CalendarDay observed) {
          touched
            ..clear()
            ..addAll(lots);
          platformToday = observed;
        },
      );
      if (drift == null) {
        // ⛅★★★ **وتُعاد بناءُ بطاقةِ كل ضمارٍ خُصم منه** — `FR-M15-06`.
        await buildDailySummariesAfterCommit(
          _summaries,
          days: touched,
          today: platformToday ?? day,
        );
        return callableSuccess(<String, Object?>{
          'documentNumber': number,
          'date': payload.date.format(),
        });
      }
      day = drift.observed;
    }
    return callableFailure(
      CallableError.internal,
      detail: 'تعذّر تثبيت يوم الخادم — راجع ساعة الحاوية',
    );
  }

  Future<_DayMismatch?> _runCreate({
    required AccountRecord actor,
    required String requestId,
    required String dealerId,
    required _DiscountPayload payload,
    required CalendarDay day,
    required void Function(String) onAllocated,
    required void Function(Set<OwnerLedgerDay>, CalendarDay) onLots,
  }) async {
    final String dealerPath =
        _transaction.documentPath(dealersCollection, dealerId);
    final String counterPath = _transaction.documentPath(
      documentCountersCollection,
      documentCounterId(kind: DocumentKind.discount, day: day),
    );
    final Map<String, _LotPaths> lotPaths = _lotPathsFor(payload.lotIds);

    _DayMismatch? drift;
    await _transaction.run<void>(
      readPaths: <String>[
        dealerPath,
        counterPath,
        for (final _LotPaths paths in lotPaths.values) ...<String>[
          paths.document,
          paths.pricing,
        ],
      ],
      queries: <DocumentQuery>[_dealerLedgerQuery(dealerId: dealerId)],
      plan: (TransactionReads reads) {
        final CalendarDay? observed = platformDayOf(reads);
        if (observed == null) {
          throw const AbortTransaction(CallableError.internal);
        }
        if (observed != day) {
          drift = _DayMismatch(observed);
          throw const AbortTransaction(CallableError.concurrency);
        }

        final int sequence = nextSequence(
          readInt(reads.document(counterPath)?[counterValueField]),
        );
        final String number = formatDocumentNumber(
          kind: DocumentKind.discount,
          day: day,
          sequence: sequence,
        );
        onAllocated(number);

        final DiscountPlan plan = planDiscount(
          DiscountRequest(
            actor: actor,
            requestId: requestId,
            dealerId: dealerId,
            documentNumber: number,
            date: payload.date,
            // ★★★ **يوم المنصّة هو الحَكَم على «مستقبلي/سابق»** — ⛔ **لا
            //    ساعةُ الجهاز ولا ساعةُ الحاوية** (`A-10`).
            today: observed,
            sourceFilter: payload.sourceFilter,
            lines: payload.lines,
            usedAutoAllocation: payload.usedAutoAllocation,
            lots: _reportLots(_lotsOf(reads, lotPaths), observed, onLots),
            storedDealer: reads.document(dealerPath),
            dealerLedger: _dealerLedgerOf(reads),
            deviceInfo: payload.deviceInfo,
          ),
          DiscountOperation.createDiscount,
        );
        if (plan case DiscountRejected(:final CallableError error)) {
          throw AbortTransaction(error);
        }

        final DiscountAccepted accepted = plan as DiscountAccepted;
        return AuditedWrite<void>(
          documents: <PendingDocument>[
            for (final InventoryWrite write in accepted.writes)
              _toPending(write),
            // ⛅ **العدّاد يُستهلَك في الالتزام نفسه** — ⟵ **فلا رقمٌ
            //    يُخصَّص ثم تفشل الكتابة فتبقى فجوة.**
            PendingDocument(
              collectionId: documentCountersCollection,
              documentId:
                  documentCounterId(kind: DocumentKind.discount, day: day),
              fields: <String, Object?>{counterValueField: sequence},
              updateMask: const <String>[counterValueField],
            ),
          ],
          entry: accepted.entry,
          result: null,
        );
      },
    ).onError<AbortTransaction>((AbortTransaction error, StackTrace _) {
      if (drift == null) throw error;
    });

    return drift;
  }

  // ═════════════════════════════════════════════════════════════════════
  // التعديل والإلغاء
  // ═════════════════════════════════════════════════════════════════════

  Future<Response> _amendOrCancel(
    CallableRequest call,
    AccountRecord actor,
    String requestId,
    String dealerId,
    DiscountOperation operation,
  ) async {
    final String? number = call.readString('documentNumber');
    if (number == null) return callableFailure(CallableError.invalidArgument);

    // ⛔⛔★★★ **والفائضُ مرفوضٌ في التعديل كذلك** — ★ **وإلا لَمرّ من الباب
    //    الخلفي**: ⟵ **إنشاءٌ نظيفٌ ثم تعديلٌ يحقن الحقل.**
    if (!operation.isCancel && _carriesSurplus(call)) {
      return callableFailure(CallableError.discountSurplusRejected);
    }

    final _DiscountPayload? payload =
        operation.isCancel ? null : _readPayload(call);
    if (!operation.isCancel && payload == null) {
      return callableFailure(CallableError.invalidArgument);
    }
    final String? reason = call.readString(discountReasonField);

    // ★ **قراءةٌ تمهيدية للمستند** — ⟵ **لمعرفة ضماراته القائمة** التي يجب
    //   أن تُقرأ ولو حُذفت من التعديل. ⛔ **وليست مصدرَ قرار**: المعاملة
    //   تُعيد قراءة المستند وتحكم به.
    final Map<String, Object?>? preview = await _transaction.readDocument(
      collectionId: discountsCollection,
      documentId: number,
    );
    if (preview == null) return callableFailure(CallableError.invalidArgument);

    final Set<String> lotIds = <String>{
      ...?payload?.lotIds,
      ..._storedLotIds(preview),
    };
    final Map<String, _LotPaths> lotPaths = _lotPathsFor(lotIds);
    final String documentPath =
        _transaction.documentPath(discountsCollection, number);
    final String dealerPath =
        _transaction.documentPath(dealersCollection, dealerId);

    final Set<OwnerLedgerDay> touched = <OwnerLedgerDay>{};
    CalendarDay? platformToday;

    await _transaction.run<void>(
      readPaths: <String>[
        documentPath,
        dealerPath,
        for (final _LotPaths paths in lotPaths.values) ...<String>[
          paths.document,
          paths.pricing,
        ],
      ],
      queries: <DocumentQuery>[_dealerLedgerQuery(dealerId: dealerId)],
      plan: (TransactionReads reads) {
        final CalendarDay? observed = platformDayOf(reads);
        if (observed == null) {
          throw const AbortTransaction(CallableError.internal);
        }
        final Map<String, Object?>? stored = reads.document(documentPath);
        if (stored == null) {
          throw const AbortTransaction(CallableError.invalidArgument);
        }

        final DiscountPlan plan = planDiscount(
          DiscountRequest(
            actor: actor,
            requestId: requestId,
            dealerId: dealerId,
            documentNumber: number,
            // ★ **تاريخ السند من الحمولة عند التعديل والمخزَّن عند الإلغاء**
            //   — ⛔ **ولا يُخترَع تاريخ للإلغاء.**
            date: payload?.date ?? _storedDate(stored) ?? observed,
            today: observed,
            sourceFilter: payload?.sourceFilter ?? _storedFilter(stored),
            lines: payload?.lines ?? const <DiscountLineInput>[],
            usedAutoAllocation: payload?.usedAutoAllocation ?? false,
            lots: _reportLots(
              _lotsOf(reads, lotPaths),
              observed,
              (Set<OwnerLedgerDay> lots, CalendarDay today) {
                touched
                  ..clear()
                  ..addAll(lots);
                platformToday = today;
              },
            ),
            storedDealer: reads.document(dealerPath),
            storedDocument: stored,
            dealerLedger: _dealerLedgerOf(reads),
            reason: reason,
            deviceInfo: payload?.deviceInfo,
          ),
          operation,
        );
        if (plan case DiscountRejected(:final CallableError error)) {
          throw AbortTransaction(error);
        }

        final DiscountAccepted accepted = plan as DiscountAccepted;
        return AuditedWrite<void>(
          documents: <PendingDocument>[
            for (final InventoryWrite write in accepted.writes)
              _toPending(write),
          ],
          entry: accepted.entry,
          result: null,
        );
      },
    );

    // ⛅★★★ **وتُعاد بناءُ بطاقةِ كل ضمارٍ مسَّه السند** — ★ **قديمِه
    //    وجديدِه معاً** (نفسُ علّة مسار القبض حرفياً).
    await buildDailySummariesAfterCommit(
      _summaries,
      days: touched,
      today: platformToday ?? CalendarDay.fromUtc(_now()),
    );

    return callableSuccess(<String, Object?>{'documentNumber': number});
  }

  // ═════════════════════════════════════════════════════════════════════
  // القراءة
  // ═════════════════════════════════════════════════════════════════════

  /// ⛔⛔★★★ **هل تحمل الحمولةُ حقلَ فائضٍ بأي صورة؟** — `FR-M13-05` ·
  /// `AT-35` · `ERR_DIST_009`.
  ///
  /// ★★ **والفحصُ على *وجود المفتاح* لا على قيمته** — ⟵ **فـ`surplusAmount: 0`
  /// حقلٌ موجودٌ كذلك**: ⛔ **وقبولُه كان يُثبِّت الحقلَ في عقد السلك**،
  /// ★ **ثم يُملأ لاحقاً بلا حارس.**
  ///
  /// ★ **والمفتاحان معاً** — ⟵ **فمُرسِلٌ يبعث `surplusScope` وحده يدّعي
  /// نطاقاً لفائضٍ**، ⛔ **وسندُ الخصم لا يعرف النطاقَ إلا فلترَ مصدر.**
  static bool _carriesSurplus(CallableRequest call) =>
      call.data.containsKey('surplusAmount') ||
      call.data.containsKey('surplusScope');

  Map<String, _LotPaths> _lotPathsFor(Iterable<String> lotIds) =>
      <String, _LotPaths>{
        for (final String lotId in lotIds)
          lotId: _LotPaths(
            document:
                _transaction.documentPath(distributionsCollection, lotId),
            pricing: _transaction.documentPath(
              '$distributionsCollection/$lotId'
              '/$distributionPricingSubcollection',
              distributionPricingDocumentId,
            ),
          ),
      };

  /// ★★★ **الضمارات كما قُرئت** — **بأبيها وتسعيرها معاً** (`IQ-027`).
  ///
  /// ⛔⛔★★ **والمتبقي من `pricing/current` وحده** — ★ **عبر
  /// [readStoredSettlement] نفسِها التي يستعملها مسارا التوزيع والقبض**:
  /// ⟵ **مصدرُ قراءةٍ واحد للمسارات الثلاثة** ⛔ **لا ثلاثُ نسخٍ تفترق.**
  ///
  /// ⚠️⚠️ **وضمارٌ بلا تسعير متبقّيه صفر** — ★ **فسطرٌ عليه يُرفَض
  /// بـ`BR-M13-02`** ⟵ **وهو الصواب**: ⛔ **لا يُخصَم مما لم يُسعَّر بعد**
  /// (`FR-M10-08`).
  /// ★★ يُبلِّغ المُستدعيَ بالضمارات المتأثرة **ويُمرِّرها كما هي**.
  ///
  /// ⛔⛔ **ومصدرُ الضمار ويومُه من المستند المخزَّن** — ⛔ **لا من الحمولة**
  /// (نفسُ درس [`DEBT-86`] ②).
  static Map<String, DebtLotRead> _reportLots(
    Map<String, DebtLotRead> lots,
    CalendarDay observed,
    void Function(Set<OwnerLedgerDay>, CalendarDay) onLots,
  ) {
    onLots(
      <OwnerLedgerDay>{
        for (final DebtLotRead lot in lots.values)
          OwnerLedgerDay(sourceId: lot.sourceId, date: lot.stockDate),
      },
      observed,
    );
    return lots;
  }

  static Map<String, DebtLotRead> _lotsOf(
    TransactionReads reads,
    Map<String, _LotPaths> lotPaths,
  ) {
    final Map<String, DebtLotRead> lots = <String, DebtLotRead>{};
    for (final MapEntry<String, _LotPaths> entry in lotPaths.entries) {
      final Map<String, Object?>? parent = reads.document(entry.value.document);
      if (parent == null) continue;
      final Map<String, Object?>? pricing =
          reads.document(entry.value.pricing);
      final Object? sourceId = parent['sourceId'];
      if (sourceId is! String || sourceId.isEmpty) continue;
      final CalendarDay? stockDate = _dayOf(parent['stockDate']);
      if (stockDate == null) continue;

      final DebtSettlement settlement = readStoredSettlement(parent, pricing) ??
          computeDebtSettlement(
            debtValue: Money(readInt(pricing?['debtValue']) ?? 0),
            settledAmount: Money.zero,
            discountedAmount: Money.zero,
          );
      lots[entry.key] = DebtLotRead(
        debtLotId: entry.key,
        sourceId: sourceId,
        stockDate: stockDate,
        settlement: settlement,
        isCancelled: parent['status'] == 'cancelled',
      );
    }
    return lots;
  }

  /// ★★ **قيود المقوت في كل مصادره** — ⛔ **والمجموعة المبتورة رفضٌ**.
  ///
  /// ⚠️⚠️ **ولا يُقيَّد `sourceId` هنا** — ★ **لأن سند «الكل» يمسّ مصادر
  /// عدة**، ⟵ **والفهرس القائم `dealerId ↑ · sourceId ↑ · entryDate ↓`
  /// يغطّي المساواة الأولى وحدها كبادئة** ⛔ **فلا فهرسَ جديداً.**
  static List<ReceiptLedgerRead> _dealerLedgerOf(TransactionReads reads) {
    final List<String> ids = reads.matches(discountDealerLedgerQueryKey);
    final List<Map<String, Object?>> documents =
        reads.matchedDocuments(discountDealerLedgerQueryKey);
    if (ids.length >= discountDealerLedgerLimit) {
      // ⛔★★ **بترٌ ⟵ رصيدٌ كاذب** — ★ **ويُرفَض صراحةً**.
      throw const AbortTransaction(CallableError.internal);
    }
    final List<ReceiptLedgerRead> entries = <ReceiptLedgerRead>[];
    for (int i = 0; i < ids.length; i++) {
      final Object? sourceId = documents[i]['sourceId'];
      // ⛔ **وقيدٌ بلا مصدر لا يدخل جمعاً** — ★ **فالرصيد رصيدُ مصدر.**
      if (sourceId is! String || sourceId.isEmpty) continue;
      entries.add(
        ReceiptLedgerRead(
          entryId: ids[i],
          sourceId: sourceId,
          entry: DealerLedgerEntry(
            direction:
                documents[i]['direction'] == DealerLedgerDirection.credit.name
                    ? DealerLedgerDirection.credit
                    : DealerLedgerDirection.debit,
            amount: Money(readInt(documents[i]['amount']) ?? 0),
            // ⛔ **الملغاة صراحةً وحدها ملغاة** — ★ **والافتراض الآمن هنا
            //    «قيدٌ حيّ»**: ⟵ **قراءةُ قيدٍ حيّ ملغىً تُخفي ديناً قائماً.**
            isCancelled: documents[i]['isCancelled'] == true,
          ),
        ),
      );
    }
    return entries;
  }

  static DocumentQuery _dealerLedgerQuery({required String dealerId}) =>
      DocumentQuery(
        key: discountDealerLedgerQueryKey,
        collectionId: dealerLedgerCollection,
        fieldPath: 'dealerId',
        equalTo: dealerId,
        limit: discountDealerLedgerLimit,
      );

  _DiscountPayload? _readPayload(CallableRequest call) {
    final CalendarDay? date = _readDay(call.data['date']);
    if (date == null) return null;

    final Object? rawLines = call.data['lines'];
    if (rawLines is! List<Object?>) return null;
    final List<DiscountLineInput> lines = <DiscountLineInput>[];
    for (final Object? entry in rawLines) {
      if (entry is! Map<String, Object?>) return null;
      final Object? lotId = entry['debtLotId'];
      if (lotId is! String || lotId.trim().isEmpty) return null;
      final int? amount = readInt(entry['amount']);
      // ⛔★★ **ومبلغٌ لا يُقرأ عدداً صحيحاً رفضٌ لا تجاهل** — `ADR-0015`
      //    القاعدة 1: ⟵ **وتجاهلُه كان يحفظ سنداً بمبلغٍ أقل مما أقرّه
      //    المستخدم** ★ **ويبدو ناجحاً.**
      if (amount == null) return null;
      final Object? note = entry['note'];
      lines.add(
        DiscountLineInput(
          debtLotId: lotId.trim(),
          amount: Money(amount),
          note: note is String ? note : null,
        ),
      );
    }

    return _DiscountPayload(
      date: date,
      sourceFilter: call.readString('sourceFilter'),
      lines: lines,
      usedAutoAllocation: call.data['usedAutoAllocation'] == true,
      deviceInfo: call.readString('deviceInfo'),
    );
  }

  static Set<String> _storedLotIds(Map<String, Object?> stored) {
    final Object? lines = stored['lines'];
    if (lines is! List<Object?>) return <String>{};
    return <String>{
      for (final Object? line in lines)
        if (line is Map<String, Object?>)
          if (line['debtLotId'] case final String id) id,
    };
  }

  /// ★★ **تاريخ السند على السلك — `YYYYMMDD` المُدمَج** — ★ **نفس صيغة
  /// سند القبض** (`receipt_handler.dart`)، ⛔ **ولا صيغةَ ثانيةً تُخترَع.**
  static CalendarDay? _readDay(Object? raw) {
    if (raw is String) return CalendarDay.tryParseCompact(raw.trim());
    return null;
  }

  /// ★ يومٌ **مقروءٌ من القاعدة** — ⛅ **وهو `Timestamp` هناك لا نصّ**.
  static CalendarDay? _dayOf(Object? raw) {
    if (raw is DateTime) return CalendarDay.fromUtc(raw.toUtc());
    if (raw is String) return CalendarDay.tryParseCompact(raw.trim());
    return null;
  }

  static CalendarDay? _storedDate(Map<String, Object?> stored) =>
      _dayOf(stored['date']);

  static String? _storedFilter(Map<String, Object?> stored) {
    final Object? raw = stored['sourceFilter'];
    return raw is String && raw.isNotEmpty ? raw : null;
  }

  static PendingDocument _toPending(InventoryWrite write) => PendingDocument(
        collectionId: write.collectionId,
        documentId: write.documentId,
        fields: write.fields,
        updateMask: write.updateMask,
        serverTimestampFields: write.serverTimestampFields,
      );

  /// ★ رقمٌ نائب **لفحص البوابة قبل تخصيص الرقم** — ⛔ ولا يُكتب أبداً.
  static const String _pendingDocumentNumber = 'pending';
}

/// مسارا الضمار — **الأب وتسعيرُه** (`IQ-027`).
final class _LotPaths {
  const _LotPaths({required this.document, required this.pricing});

  final String document;
  final String pricing;
}

/// حمولة السند كما وصلت — ⛔ **بعد قراءتها لا قبلها**.
///
/// ⛔⛔★★★ **ولا حقلَ فائضٍ فيها** — ★ **بخلاف `_ReceiptPayload`**:
/// ⟵ **غيابٌ بنيويٌّ من النوع نفسِه** (`FR-M13-05`)، ⛔ **لا حقلٌ يُصفَّر.**
final class _DiscountPayload {
  const _DiscountPayload({
    required this.date,
    required this.sourceFilter,
    required this.lines,
    required this.usedAutoAllocation,
    required this.deviceInfo,
  });

  final CalendarDay date;
  final String? sourceFilter;
  final List<DiscountLineInput> lines;
  final bool usedAutoAllocation;
  final String? deviceInfo;

  Set<String> get lotIds => <String>{
        for (final DiscountLineInput line in lines) line.debtLotId,
      };
}

/// اختلاف يوم المنصّة عن اليوم المقترَح.
final class _DayMismatch {
  const _DayMismatch(this.observed);

  final CalendarDay observed;
}

/// تنفيذ عمليات الجرد — **الطرف الذي يلمس الشبكة** (`WU-022`).
///
/// ★ **مفصول عن `stocktake.dart` عمداً**، بنفس منطق `disposal_handler.dart`:
/// كل قرار تفويض وقاعدة عمل هناك في **دوال خالصة تُختبَر بلا سحابة**؛
/// وهنا **الترتيب والقراءة والالتزام** وحدها.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **وثلاثةُ غياباتٍ مقصودةٍ في هذا الملف — كلُّها تنفيذُ متطلبٍ لا نقص:**
///
/// | ما لا يُستدعى هنا | لماذا |
/// |---|---|
/// | **`revalueSacksAfterCommit`** | ⛔ **تسويةُ الجرد لا تدخل سعرَ الجونية** (`BR-M16-03` · `AT-66`) — ★ **واستدعاؤه كان عملاً بلا أثرٍ يُوهِم القارئ أن للتسوية مدخلاً في السعر** |
/// | **`buildDailySummariesAfterCommit`** | ⛔ **ولا مبلغَ في هذه العملية أصلاً** — ★ **وبطاقةُ ضمار المالك تقرأ `distributions` و`cash_sales` و`sacks` و`outflows` وحدها** |
/// | **دفترا المقاوته والرعوي** | `BR-M16-03` — ★ **«تُستثنى من … استحقاق الرعوي»** |
///
/// ★★★ **وما يُستدعى منها ضروريٌّ لا تجميلي — وعند الاعتماد وحده:**
///   · **راصدُ المتبقي المتأخر** (`aged_remainder.dart`) — ⟵ **التسويةُ
///     تُغيِّر الرصيد صعوداً أو هبوطاً**: ★ **فيُكتب بندُه أو يُمحى في
///     المعاملة نفسِها**، ⛔ **وإلا طالبت الشاشةُ بتصريف عدمٍ سُوِّي فعلاً**
///     أو **أخفت متبقياً كشفه الجرد** (`GR-16`).
///   · **بنودُ `M9` المعلّقة** (`pendingFromBalanceWrites`) — `AT-16`:
///     ⟵ **وبندُ «نوعٌ بلا سعر» يظهر متى أدخلت تسويةُ الزيادة رصيداً جديداً.**
///
/// ⛔⛔★★★ **والمسوّدةُ لا تُشغِّل أياً منهما** — ★ **لأنها لا تكتب رصيداً**
/// ([StocktakeAccepted.touchesLedger] **تقرأ ذلك من الخطة نفسِها**):
/// ⟵ **فلا يُقاس الأثرُ من نوع العملية بل من كتاباتها**، ⛔ **وشرطٌ على
/// اسم العملية كان ينزلق عند أول عمليةٍ خامسة.**
///
/// ★★ **وتاريخُ المخزون من الحمولة لا من المنصّة عند البدء** — ⛔ **بخلاف
/// `outflow_handler.dart`**: ⟵ **لأن جردَ يومٍ سابقٍ مسارٌ منصوصٌ عليه**
/// (`FR-M16-08`)، ★ **وغيابُه هو الحالُ الأصلي (جردُ اليوم)** ⛔ **ونصٌّ
/// مشوَّه رفضٌ صريحٌ لا سقوطٌ صامتٌ إلى «اليوم»** (`RISK-07`).
/// ═══════════════════════════════════════════════════════════════════════
library;

import 'package:qtms_domain/qtms_domain.dart';
import 'package:shelf/shelf.dart';

import 'aged_remainder.dart';
import 'audited_transaction.dart';
import 'callable.dart';
import 'counter_allocator.dart' show counterValueField;
import 'identity_gateway.dart';
import 'inventory.dart';
import 'inventory_handler.dart'
    show
        inventoryLedgerQuery,
        platformDayOf,
        readInt,
        readItemRecords,
        readLedgerMovements,
        withLedgerItems;
import 'pending_entries.dart';
import 'permission_sync_handler.dart' show requestIdField;
import 'stocktake.dart';

/// اسم حقل السبب في الحمولة — ★ **اختياريٌّ** ([`ADR-0020`]).
const String stocktakeReasonField = 'reason';

/// اسم حقل تاريخ المخزون المطلوب في الحمولة — ★ **مسارُ جرد يومٍ سابق**.
const String stocktakeStockDateField = 'stockDate';

/// ★★ **مفتاحُ استعلام جردِ اليوم نفسِه** — `FR-M16-06`.
///
/// ⛔ **ولا يتصادم مع مفاتيح استعلامات الدفتر** — ★ **تلك مفاتيحُها أنواعٌ
/// (`itemKey`)**، ⟵ **وهذا مفتاحٌ محجوزٌ بصيغةٍ لا تصلح مفتاحَ نوع.**
const String stocktakeSameDayQueryKey = '__stocktakes_same_day__';

/// ★ الحدُّ الأعلى لمستندات الجرد المقروءة لليوم الواحد — **حارسٌ لا سياسة**.
///
/// ⚠️ **ولماذا حدٌّ أصلاً:** ⟵ **الاستعلامُ داخل معاملة**، ★ **وقراءةٌ بلا
/// حدٍّ تنمو مع عمر البيانات** (`ADR-0008`). ★ **والعشرون تكفي بفارقٍ كبير:**
/// ⟵ **جردٌ واحدٌ مفتوحٌ لا أكثر** (`FR-M16-06`)، ⛔ **والباقي معتمدٌ أو ملغى.**
const int stocktakeSameDayLimit = 20;

/// ★ استعلامُ مستندات الجرد على (مصدر × يوم) — **داخل المعاملة**.
///
/// ⛔⛔★★ **ويُقيَّد `sourceId` و`stockDate` معاً** — ★ **والفهرسُ المقابل
/// `stocktakes: sourceId ↑ · stockDate ↓`** (`indexing-strategy.md`).
DocumentQuery stocktakeSameDayQuery({
  required String sourceId,
  required CalendarDay day,
}) =>
    DocumentQuery(
      key: stocktakeSameDayQueryKey,
      collectionId: stocktakesCollection,
      fieldPath: 'sourceId',
      equalTo: sourceId,
      andEquals: <String, Object?>{'stockDate': day.asUtcMidnight()},
      limit: stocktakeSameDayLimit,
    );

/// منفّذ عمليات الجرد.
final class StocktakeHandler {
  /// ينشئ المنفّذ بتبعياته — ★ **تُحقَن، فيُختبَر بلا سحابة**.
  const StocktakeHandler({
    required IdentityGateway identity,
    required AuditedTransaction transaction,
    DateTime Function()? clock,
  })  : _identity = identity,
        _transaction = transaction,
        _clock = clock;

  final IdentityGateway _identity;
  final AuditedTransaction _transaction;

  /// ★ ساعةُ **الاقتراح** وحدها — ⛔ **ولا تُكتب قيمتها في أي حقل** بلا
  /// موافقة المنصّة (`GR-54`). تُحقَن في الاختبار.
  final DateTime Function()? _clock;

  DateTime _now() => (_clock ?? DateTime.now)().toUtc();

  /// ينفّذ [operation] على طلب HTTP خام.
  Future<Response> handle(
    Request httpRequest,
    StocktakeOperation operation,
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
    StocktakeOperation operation,
  ) async {
    final AccountRecord actor = await _identity.verifyIdToken(call.idToken);
    final String? requestId = call.readString(requestIdField);
    final String? sourceId = call.readString('sourceId');
    if (requestId == null || sourceId == null || sourceId.trim().isEmpty) {
      return callableFailure(CallableError.invalidArgument);
    }

    // ① البوابة — ⛔ قبل أي معاملة: الصلاحية **والنطاق** معاً.
    final StocktakeRejected? gate = stocktakeGate(
      StocktakeRequest(
        actor: actor,
        requestId: requestId,
        sourceId: sourceId,
        documentNumber: _pendingDocumentNumber,
        stockDate: CalendarDay.fromUtc(_now()),
      ),
      operation,
    );
    if (gate != null) return callableFailure(gate.error);

    return operation.isStart
        ? _start(call, actor, requestId, sourceId)
        : _followUp(call, actor, requestId, sourceId, operation);
  }

  // ═════════════════════════════════════════════════════════════════════
  // ① البدء — ★ **تخصيصُ الرقم وتجميدُ الرصيد الدفتري**
  // ═════════════════════════════════════════════════════════════════════

  Future<Response> _start(
    CallableRequest call,
    AccountRecord actor,
    String requestId,
    String sourceId,
  ) async {
    final List<String>? itemIds = _readItemIds(call);
    if (itemIds == null || itemIds.isEmpty) {
      return callableFailure(CallableError.invalidArgument);
    }

    // ★★★ **تاريخُ المخزون المطلوب — مسارُ جرد يومٍ سابق** (`FR-M16-08`):
    //    ⛔⛔ **وغيابُه هو الحالُ الأصلي**، ★ **ووجودُه يُثبِّت اليوم ويُخضِع
    //    الطلبَ لـ`stocktakePriorDay`** داخل [planStocktake].
    final String? requestedDay = call.readString(stocktakeStockDateField);
    final CalendarDay? pinnedDay =
        requestedDay == null ? null : CalendarDay.tryParseCompact(requestedDay);
    // ⛔ **ونصٌّ مشوَّه رفضٌ صريح** — ⛔ **لا سقوطٌ صامتٌ إلى «اليوم»** (`RISK-07`).
    if (requestedDay != null && pinnedDay == null) {
      return callableFailure(CallableError.invalidArgument);
    }

    CalendarDay day = pinnedDay ?? CalendarDay.fromUtc(_now());
    String? number;
    // ★ **محاولتان لا أكثر** — ⟵ **فانقلابُ منتصف الليل يُصحَّح مرة واحدة.**
    for (int attempt = 0; attempt < 2; attempt++) {
      final _DayMismatch? drift = await _runStart(
        call: call,
        actor: actor,
        requestId: requestId,
        sourceId: sourceId,
        itemIds: itemIds,
        day: day,
        isPinned: pinnedDay != null,
        onAllocated: (String allocated) => number = allocated,
      );
      if (drift == null) {
        return callableSuccess(<String, Object?>{
          'documentNumber': number,
          'stockDate': day.format(),
        });
      }
      day = drift.observed;
    }
    return callableFailure(
      CallableError.internal,
      detail: 'تعذّر تثبيت يوم الخادم — راجع ساعة الحاوية',
    );
  }

  Future<_DayMismatch?> _runStart({
    required CallableRequest call,
    required AccountRecord actor,
    required String requestId,
    required String sourceId,
    required List<String> itemIds,
    required CalendarDay day,
    required bool isPinned,
    required void Function(String) onAllocated,
  }) async {
    final String sourcePath =
        _transaction.documentPath(sourcesCollection, sourceId);
    final String counterPath = _transaction.documentPath(
      documentCountersCollection,
      documentCounterId(kind: DocumentKind.stocktake, day: day),
    );
    final Map<String, String> itemPaths = <String, String>{
      for (final String itemId in itemIds)
        itemId: _transaction.documentPath(itemsCollection, itemId),
    };

    _DayMismatch? drift;
    await _transaction.run<void>(
      readPaths: <String>[sourcePath, counterPath, ...itemPaths.values],
      queries: <DocumentQuery>[
        for (final String itemId in itemIds)
          inventoryLedgerQuery(sourceId: sourceId, itemKey: itemId, day: day),
        // ⑥ ★★★ **حارسُ «لا جردان معاً»** — `FR-M16-06`.
        stocktakeSameDayQuery(sourceId: sourceId, day: day),
      ],
      plan: (TransactionReads reads) {
        // ★★★ **يوم المنصّة هو الحَكَم** — `GR-54`.
        final CalendarDay? observed = platformDayOf(reads);
        if (observed == null) {
          throw const AbortTransaction(CallableError.internal);
        }
        // ⛔⛔★★★ **والانقلابُ يُصحَّح في المسار غير المثبَّت وحده** —
        //    ★ **واليومُ المثبَّت مقصودٌ لا انزلاق** (`FR-M16-08`).
        if (!isPinned && observed != day) {
          drift = _DayMismatch(observed);
          throw const AbortTransaction(CallableError.concurrency);
        }

        final int sequence = nextSequence(
          readInt(reads.document(counterPath)?[counterValueField]),
        );
        final String number = formatDocumentNumber(
          kind: DocumentKind.stocktake,
          day: day,
          sequence: sequence,
        );
        onAllocated(number);

        // ★★★ **والمفتاح المركّب نوعٌ لا سجل له** — [`DEBT-86`]:
        //    ⛔ **بلا هذا لا يُجرَد سطرُ جونيةٍ إطلاقاً.**
        final Map<String, ItemRead> items = withLedgerItems(
          readItemRecords(reads, itemPaths),
          reads: reads,
          itemKeys: itemPaths.keys,
          sourceId: sourceId,
        );

        final Outcome<ValidatedStocktakeStart> validated = validateStocktakeStart(
          StocktakeStartInput(sourceId: sourceId, itemIds: itemIds),
        );
        if (validated is Failure<ValidatedStocktakeStart>) {
          throw AbortTransaction(_mapValidation(validated.error));
        }

        final StocktakePlan plan = planStocktake(
          StocktakeRequest(
            actor: actor,
            requestId: requestId,
            sourceId: sourceId,
            documentNumber: number,
            stockDate: day,
            // ★★★ **ويومُ المنصّة يبلغ المُخطِّط الخالص** — ⟵ **فبوابةُ
            //    جرد اليوم السابق تُقرَّر هناك** (`ADR-0013` القاعدة 3).
            serverDay: observed,
            start: (validated as Success<ValidatedStocktakeStart>).value,
            storedSource: reads.document(sourcePath),
            // ⛔★★ **ومستندٌ غائبٌ يقيناً** — ★ **الرقم خُصِّص للتوّ.**
            storedDocument: null,
            items: items,
            ledger: _ledgerOf(reads, itemPaths.keys, items),
            sameDayDocuments: _sameDayDocumentsOf(reads),
            reason: call.readString(stocktakeReasonField),
            deviceInfo: call.readString('deviceInfo'),
          ),
          StocktakeOperation.startStocktake,
        );
        if (plan case StocktakeRejected(:final CallableError error)) {
          throw AbortTransaction(error);
        }

        final StocktakeAccepted accepted = plan as StocktakeAccepted;
        return AuditedWrite<void>(
          documents: <PendingDocument>[
            for (final InventoryWrite write in accepted.writes)
              _toPending(write),
            // ⛅ **العدّاد يُستهلَك في الالتزام نفسه** — ⟵ **فلا رقمٌ
            //    يُخصَّص ثم تفشل الكتابة فتبقى فجوة.**
            PendingDocument(
              collectionId: documentCountersCollection,
              documentId:
                  documentCounterId(kind: DocumentKind.stocktake, day: day),
              fields: <String, Object?>{counterValueField: sequence},
              updateMask: const <String>[counterValueField],
            ),
          ],
          entry: accepted.entry,
          result: null,
        );
      },
    ).onError<AbortTransaction>((AbortTransaction error, StackTrace _) {
      // ★ **انقلاب اليوم ليس فشلاً** — ⟵ **يُعاد بناء الطلب باليوم الصحيح**،
      //   ⛔ **وكل رفضٍ آخر يصعد كما هو.**
      if (drift == null) throw error;
    });

    return drift;
  }

  // ═════════════════════════════════════════════════════════════════════
  // ② الاعتماد والتعديل والإلغاء — ★ **ويومُ المخزون محفورٌ في رقم المستند**
  // ═════════════════════════════════════════════════════════════════════

  Future<Response> _followUp(
    CallableRequest call,
    AccountRecord actor,
    String requestId,
    String sourceId,
    StocktakeOperation operation,
  ) async {
    final String? number = call.readString('documentNumber');
    if (number == null) return callableFailure(CallableError.invalidArgument);
    // ★★ **يومُ المخزون من الرقم لا من الجهاز ولا من الساعة**.
    final CalendarDay? day = parseDocumentNumberDay(number);
    if (day == null) return callableFailure(CallableError.invalidArgument);
    // ⛔ **والرقمُ يجب أن يحمل بادئةَ الجرد** — ★ **حارسٌ مبكّر**:
    //   ⟵ **والحَكَمُ النهائي المستندُ المخزَّن نفسُه** (`_existenceGate`).
    if (!number.startsWith('${DocumentKind.stocktake.prefix}-')) {
      return callableFailure(CallableError.invalidArgument);
    }

    // ⛔⛔★★★ **ولا فحصَ لغياب السبب** — [`ADR-0020`].
    final String? reason = call.readString(stocktakeReasonField);

    final List<_CountRequest> counts = operation.isCounting
        ? (_readCounts(call) ?? const <_CountRequest>[])
        : const <_CountRequest>[];
    if (operation.isCounting && counts.isEmpty) {
      return callableFailure(CallableError.invalidArgument);
    }

    final String documentPath =
        _transaction.documentPath(stocktakesCollection, number);
    final String sourcePath =
        _transaction.documentPath(sourcesCollection, sourceId);

    // ★ **قراءةٌ تمهيدية للمستند** — ⟵ **لمعرفة أنواعه المُجمَّدة** التي يجب
    //   أن تُقرأ حركاتُها وسجلاتُها. ⛔ **وليست مصدرَ قرار**: المعاملة تُعيد
    //   قراءة المستند وتحكم به (`_existenceGate`).
    final Map<String, Object?>? preview = await _transaction.readDocument(
      collectionId: stocktakesCollection,
      documentId: number,
    );
    if (preview == null) return callableFailure(CallableError.invalidArgument);

    final Set<String> itemIds = <String>{
      for (final _CountRequest count in counts) count.itemId,
      for (final FrozenStocktakeLine line
          in readFrozenLines(preview) ?? const <FrozenStocktakeLine>[])
        line.itemKey,
    };
    if (itemIds.isEmpty) return callableFailure(CallableError.invalidArgument);

    final Map<String, String> itemPaths = <String, String>{
      for (final String itemId in itemIds)
        itemId: _transaction.documentPath(itemsCollection, itemId),
    };
    // ★★ **وسجلُّ سعر اليوم لكل نوع** — ⛔ **لا لسعرٍ يُقرأ** (لا سعر هنا):
    //    ⟵ **بل لبنود المركز المعلّق وحدها** (`pendingFromBalanceWrites`).
    final Map<String, String> pricePaths = <String, String>{
      for (final String itemId in itemIds)
        itemId: _transaction.documentPath(
          dailyPricesCollection,
          dailyPriceId(sourceId: sourceId, itemKey: itemId, date: day),
        ),
    };

    await _transaction.run<void>(
      readPaths: <String>[
        documentPath,
        sourcePath,
        ...itemPaths.values,
        ...pricePaths.values,
      ],
      queries: <DocumentQuery>[
        for (final String itemId in itemIds)
          inventoryLedgerQuery(sourceId: sourceId, itemKey: itemId, day: day),
      ],
      plan: (TransactionReads reads) {
        final Map<String, ItemRead> items = withLedgerItems(
          readItemRecords(reads, itemPaths),
          reads: reads,
          itemKeys: itemPaths.keys,
          sourceId: sourceId,
        );

        ValidatedStocktakeCounts? validatedCounts;
        if (operation.isCounting) {
          final Outcome<ValidatedStocktakeCounts> validated = _validateCounts(
            sourceId: sourceId,
            counts: counts,
            items: items,
            stored: reads.document(documentPath),
            reason: call.readString(stocktakeReasonField),
          );
          if (validated is Failure<ValidatedStocktakeCounts>) {
            throw AbortTransaction(_mapValidation(validated.error));
          }
          validatedCounts =
              (validated as Success<ValidatedStocktakeCounts>).value;
        }

        final StocktakePlan plan = planStocktake(
          StocktakeRequest(
            actor: actor,
            requestId: requestId,
            sourceId: sourceId,
            documentNumber: number,
            stockDate: day,
            // ⛔⛔★★ **ولا `serverDay` هنا** — راجع [StocktakeRequest.serverDay]:
            //    ★ **إتمامُ جردٍ قائمٍ ليس بدءَ جردٍ جديد.**
            counts: validatedCounts,
            storedSource: reads.document(sourcePath),
            storedDocument: reads.document(documentPath),
            items: items,
            ledger: _ledgerOf(reads, itemIds, items),
            reason: reason,
            deviceInfo: call.readString('deviceInfo'),
          ),
          operation,
        );
        if (plan case StocktakeRejected(:final CallableError error)) {
          throw AbortTransaction(error);
        }

        final StocktakeAccepted accepted = plan as StocktakeAccepted;
        // ⛔⛔★★★ **والمشتقّاتُ تتبع الكتاباتِ لا اسمَ العملية** — راجع
        //    ترويسة الملف: ⟵ **فمسوّدةٌ لا تكتب رصيداً لا تُحرِّك راصداً.**
        final bool touchesLedger = accepted.touchesLedger;
        return AuditedWrite<void>(
          documents: <PendingDocument>[
            for (final InventoryWrite write in accepted.writes)
              _toPending(write),
            if (touchesLedger) ...<PendingDocument>[
              ..._pendingDocumentsOf(accepted, sourceId, day, reads, pricePaths),
              ...agedRemaindersFromBalanceWrites(accepted.writes).documents,
            ],
          ],
          deletions: <PendingDeletion>[
            if (touchesLedger) ...<PendingDeletion>[
              ..._pendingDeletionsOf(accepted, sourceId, day, reads, pricePaths),
              ...agedRemaindersFromBalanceWrites(accepted.writes).deletions,
            ],
          ],
          entry: accepted.entry,
          result: null,
        );
      },
    );

    return callableSuccess(<String, Object?>{
      'documentNumber': number,
      'stockDate': day.format(),
    });
  }

  // ═════════════════════════════════════════════════════════════════════
  // ★★ المركز المعلّق — **بنودُ `M9` وحدها** ⛔ **ولا بندَ للمستند نفسِه**
  // ═════════════════════════════════════════════════════════════════════

  PendingEntrySet _pendingSetOf(
    StocktakeAccepted accepted,
    String sourceId,
    CalendarDay day,
    TransactionReads reads,
    Map<String, String> pricePaths,
  ) =>
      pendingFromBalanceWrites(
        writes: accepted.writes,
        sourceId: sourceId,
        date: day,
        storedPrices: <String, Map<String, Object?>?>{
          for (final MapEntry<String, String> entry in pricePaths.entries)
            entry.key: reads.document(entry.value),
        },
      );

  List<PendingDocument> _pendingDocumentsOf(
    StocktakeAccepted accepted,
    String sourceId,
    CalendarDay day,
    TransactionReads reads,
    Map<String, String> pricePaths,
  ) =>
      pendingEntryDocuments(
        _pendingSetOf(accepted, sourceId, day, reads, pricePaths),
      );

  List<PendingDeletion> _pendingDeletionsOf(
    StocktakeAccepted accepted,
    String sourceId,
    CalendarDay day,
    TransactionReads reads,
    Map<String, String> pricePaths,
  ) =>
      pendingEntryDeletions(
        _pendingSetOf(accepted, sourceId, day, reads, pricePaths),
      );

  // ═════════════════════════════════════════════════════════════════════
  // قراءة الحمولة والمخزَّن
  // ═════════════════════════════════════════════════════════════════════

  /// ★ **يبني الأعداد من وحدة المستند المُجمَّد لا من الحمولة** — `GR-19`:
  /// ⟵ **فالوحدةُ من الرصيد الذي جُمِّد عند البدء**، ⛔ **ولا يُرسل العميل
  /// وحدةً فيُنشئ حركةً بوحدةٍ ليست وحدة النوع** (`FR-M5-03`).
  ///
  /// ⚠️ **وسجلُّ النوع احتياطٌ لا أصل** — ★ **يُستعمل حين لا سطرَ مُجمَّداً
  /// للنوع**: ⟵ **والمُخطِّطُ يرفض تلك الحالة صراحةً** (`_planCounts`)،
  /// ⛔ **فلا مسار يكتب تسويةً لنوعٍ لم يُجمَّد.**
  static Outcome<ValidatedStocktakeCounts> _validateCounts({
    required String sourceId,
    required List<_CountRequest> counts,
    required Map<String, ItemRead> items,
    required Map<String, Object?>? stored,
    required String? reason,
  }) {
    final Map<String, ItemUnit> units = <String, ItemUnit>{
      for (final FrozenStocktakeLine line
          in readFrozenLines(stored) ?? const <FrozenStocktakeLine>[])
        line.itemKey: line.bookBalance.unit,
    };

    final List<StocktakeCountInput> inputs = <StocktakeCountInput>[];
    for (final _CountRequest count in counts) {
      final ItemUnit? unit = units[count.itemId] ?? items[count.itemId]?.unit;
      if (unit == null) {
        return const Failure<ValidatedStocktakeCounts>(
          ValidationError('FR-M16-01'),
        );
      }
      final StockQuantity? quantity = _quantityOf(count.actualCount, unit);
      if (quantity == null) {
        return const Failure<ValidatedStocktakeCounts>(
          ValidationError('FR-M16-07'),
        );
      }
      inputs.add(
        StocktakeCountInput(
          itemId: count.itemId,
          unit: unit,
          actualCount: quantity,
          differenceReason: count.differenceReason,
        ),
      );
    }

    return validateStocktakeCounts(
      sourceId: sourceId,
      counts: inputs,
      reason: reason,
    );
  }

  /// ★ يترجم رفضَ طبقة النطاق إلى رمز الكتالوج.
  static CallableError _mapValidation(AppError error) => switch (error) {
        ValidationError(ruleCode: 'GR-19') => CallableError.itemUnitLocked,
        _ => CallableError.invalidArgument,
      };

  /// ★ الكمية بوحدة النوع — و`null` لمُدخَلٍ لا يصلح لتلك الوحدة.
  ///
  /// ⛔★★ **والكسر يُرفَض للنوع المعدود** — `BR-M6-06` · `ERR_STOCK_002`.
  static StockQuantity? _quantityOf(num raw, ItemUnit unit) => switch (unit) {
        ItemUnit.piece => raw == raw.roundToDouble()
            ? PieceQuantity(PieceCount(raw.toInt()))
            : null,
        ItemUnit.kilogram => WeightQuantity(WeightKg(raw.toDouble())),
      };

  static Map<String, List<LedgerRead>> _ledgerOf(
    TransactionReads reads,
    Iterable<String> itemKeys,
    Map<String, ItemRead> items,
  ) =>
      readLedgerMovements(
        reads,
        itemKeys,
        units: <String, ItemUnit>{
          for (final MapEntry<String, ItemRead> entry in items.entries)
            entry.key: entry.value.unit,
        },
      );

  /// ★ مستندات الجرد على نفس (المصدر × اليوم) بمعرّفاتها — `FR-M16-06`.
  static Map<String, Map<String, Object?>> _sameDayDocumentsOf(
    TransactionReads reads,
  ) {
    final List<String> ids = reads.matches(stocktakeSameDayQueryKey);
    final List<Map<String, Object?>> documents =
        reads.matchedDocuments(stocktakeSameDayQueryKey);
    final Map<String, Map<String, Object?>> result =
        <String, Map<String, Object?>>{};
    for (int i = 0; i < ids.length && i < documents.length; i++) {
      result[ids[i]] = documents[i];
    }
    return result;
  }

  List<String>? _readItemIds(CallableRequest call) {
    final Object? raw = call.data['itemIds'];
    if (raw is! List<Object?>) return null;
    final List<String> ids = <String>[];
    for (final Object? entry in raw) {
      if (entry is! String || entry.trim().isEmpty) return null;
      ids.add(entry.trim());
    }
    return ids;
  }

  List<_CountRequest>? _readCounts(CallableRequest call) {
    final Object? raw = call.data['counts'];
    if (raw is! List<Object?>) return null;
    final List<_CountRequest> counts = <_CountRequest>[];
    for (final Object? entry in raw) {
      if (entry is! Map<String, Object?>) return null;
      final Object? itemId = entry['itemId'];
      if (itemId is! String || itemId.trim().isEmpty) return null;
      final Object? rawCount = entry['actualCount'];
      final num? actual = rawCount is num
          ? rawCount
          : (rawCount is String ? num.tryParse(rawCount) : null);
      if (actual == null) return null;
      // ⛔⛔★★★ **ولا حقلَ سعرٍ ولا رصيدٍ دفتريٍّ يُقرأ من الحمولة إطلاقاً** —
      //    `FR-M16-01` (`bookBalance` 🧮 🔒): ★ **وما لا يُقرأ لا يُكتب**،
      //    ⟵ **فحمولةٌ تحمل `bookBalance` تُتجاهَل بنيوياً** ⛔ **لا بشرطٍ
      //    يُنسى** — ★ **وإلا كفى تعديلُ الحمولة لاختلاق فرقٍ لم يقع.**
      final Object? lineReason = entry['differenceReason'];
      counts.add(
        _CountRequest(
          itemId: itemId.trim(),
          actualCount: actual,
          differenceReason: lineReason is String && lineReason.trim().isNotEmpty
              ? lineReason.trim()
              : null,
        ),
      );
    }
    return counts;
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

/// عدٌّ كما وصل في الحمولة — ⛔ **بلا وحدةٍ ولا رصيدٍ دفتري**: كلاهما مخزَّن.
final class _CountRequest {
  const _CountRequest({
    required this.itemId,
    required this.actualCount,
    required this.differenceReason,
  });

  final String itemId;
  final num actualCount;
  final String? differenceReason;
}

/// ★ انقلاب اليوم بين اقتراح الحاوية وحكم المنصّة.
final class _DayMismatch {
  const _DayMismatch(this.observed);

  /// اليوم كما أعلنته المنصّة.
  final CalendarDay observed;
}

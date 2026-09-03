/// تنفيذ عمليات السحبيات والخرجيات — **الطرف الذي يلمس الشبكة** (`WU-014`).
///
/// ★ **مفصول عن `outflow.dart` عمداً**، بنفس منطق `cash_sale_handler.dart`:
/// كل قرار تفويض وقاعدة عمل هناك في **دوال خالصة تُختبَر بلا سحابة**؛
/// وهنا **الترتيب والقراءة والالتزام** وحدها.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **تاريخان لا تاريخٌ واحد — وهذا جوهرُ `GR-49` في هذا الملف:**
///
/// | الحقل | مصدرُه في هذه الزيادة | لماذا |
/// |---|---|---|
/// | **`documentDate`** | ★ **من الحمولة** — ويقبل السابق بمفتاحه | **الأثر المالي وقع يوم وقوعه** (`FR-M22-09` · `FR-M22-10`) |
/// | **`stockDate`** | ⛔ **من المنصّة حصراً** — `readTime` داخل المعاملة | `A-10` · `GR-14`: **النظام يحدد تاريخ المخزون لا المستخدم** |
///
/// ⚠️⚠️★★★ **وأثرٌ معلَنٌ لا مُخفى — تصريفُ المتبقي المتأخر خارج هذه الزيادة:**
/// ★ **`FR-M22-10` يصف حالةَ `stockDate` < `documentDate`** (قاتٌ من متبقٍّ
/// متأخر) — ⛔ **ولا مسار لها هنا اليوم**: ⟵ **تلك `WU-019` بمفتاحها
/// `agedRemainderClear`**، ★ **وفتحُها هنا كان يُتيح خصمَ مخزونِ يومٍ سابقٍ
/// بلا مفتاحه** (`GR-14`). ✅ **والحقلان مستقلان في المستند والدفتر من
/// اليوم** — ⟵ **فتُفتَح تلك الحالة في زيادتها بلا هجرةِ بيانات.**
///
/// ⛔⛔★★★ **ولا قراءةَ واحدة لدفتر المقاوته ولا لسجل مقوت** — `FR-M22-04`:
/// ★ **والغياب هنا تنفيذُ المتطلب لا نقصٌ فيه**: ⟵ **قراءةُ ما لا يُكتَب
/// تُغري بأن يُبنى عليه قرار.**
///
/// ★★★ **وقراءةُ `daily_prices` لبنودِ القات وحدها** — ⟵ **ومنها بنودُ
/// المركز المعلّق لـ`M9`** (`pendingFromBalanceWrites`): ⛔ **ولا حدَّ أدنى
/// يُقرأ منها هنا بخلاف البيع النقدي** — ★ **`FR-M11-05` قاعدةُ `M11` وحده**،
/// ⟵ **والسحبيةُ ليست بيعاً فلا سعرَ سوقٍ يُقاس عليه.**
/// ═══════════════════════════════════════════════════════════════════════
library;

import 'package:qtms_domain/qtms_domain.dart';
import 'package:shelf/shelf.dart';

import 'audited_transaction.dart';
import 'callable.dart';
import 'sack_valuation_handler.dart';
import 'counter_allocator.dart' show counterValueField;
import 'identity_gateway.dart';
import 'inventory.dart';
import 'inventory_handler.dart'
    show
        inventoryLedgerQuery,
        ledgerSackIds,
        platformDayOf,
        readInt,
        readItemRecords,
        readLedgerMovements,
        withLedgerItems;
import 'outflow.dart';
import 'owner_ledger_summary_handler.dart';
import 'pending_entries.dart';
import 'permission_sync_handler.dart' show requestIdField;

/// اسم حقل سبب التعديل أو الإلغاء في الحمولة.
const String outflowReasonField = 'reason';

/// منفّذ عمليات السحبيات والخرجيات.
final class OutflowHandler {
  /// ينشئ المنفّذ بتبعياته — ★ **تُحقَن، فيُختبَر بلا سحابة**.
  const OutflowHandler({
    required IdentityGateway identity,
    required AuditedTransaction transaction,
    DateTime Function()? clock,
    SackValuationHandler? valuation,
    OwnerLedgerSummaryHandler? summaries,
  })  : _identity = identity,
        _transaction = transaction,
        _valuation = valuation,
        _summaries = summaries,
        _clock = clock;

  final IdentityGateway _identity;
  final AuditedTransaction _transaction;

  /// ⛅★★ **مُحتسِبُ مالية الجواني** (`WU-015`) — ★ **يُطلَق بعد الالتزام**.
  ///
  /// ⛔⛔ **و`null` في الاختبار تعني «لا احتساب»** — ★ **فالمُحتسِب عمليةٌ
  /// مشغَّلةٌ مستقلة لها اختبارُها**، ⟵ **وفشلُه لا يُبطل هذه العملية أصلاً**
  /// (`api-overview.md` §3.3).
  final SackValuationHandler? _valuation;

  /// ⛅★★★ **باني ملخصات ضمار المالك** (`WU-016`) — ★ **يُطلَق بعد الالتزام**.
  ///
  /// ⛔⛔★★ **وعلى `documentDate` لا `stockDate`** — `GR-49`: ⟵ **فالسحبيةُ
  /// أثرُها ماليٌّ في تاريخ سندها**، ⛔ **وبناؤها على يوم المخزون كان
  /// يُدخِلها في بطاقةِ يومٍ آخر.**
  final OwnerLedgerSummaryHandler? _summaries;

  /// ★ ساعةُ **الاقتراح** وحدها — ⛔ **ولا تُكتب قيمتها في أي حقل** بلا
  /// موافقة المنصّة (راجع ترويسة الملف). تُحقَن في الاختبار.
  final DateTime Function()? _clock;

  DateTime _now() => (_clock ?? DateTime.now)().toUtc();

  /// ينفّذ [operation] على طلب HTTP خام.
  Future<Response> handle(
    Request httpRequest,
    OutflowOperation operation,
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
    OutflowOperation operation,
  ) async {
    final AccountRecord actor = await _identity.verifyIdToken(call.idToken);
    final String? requestId = call.readString(requestIdField);
    final String? sourceId = call.readString('sourceId');
    if (requestId == null) {
      return callableFailure(CallableError.invalidArgument);
    }
    // ④ ⛔⛔★★★ **المصدر إلزاميٌّ دائماً — ورمزُه مستقل** (`GR-42` · `E-28`):
    //    ★ **ويُفحَص قبل أي قراءة** ⟵ **فلا تُفتَح معاملةٌ لسندٍ لا مصدرَ له.**
    if (sourceId == null || sourceId.trim().isEmpty) {
      return callableFailure(CallableError.outflowSourceMissing);
    }

    final OutflowLedgerType? ledgerType = _readLedgerType(call.data['ledgerType']);
    if (ledgerType == null) {
      return callableFailure(CallableError.invalidArgument);
    }

    // ① البوابة — ⛔ قبل أي معاملة: **مفتاحُ السجل** والنطاق معاً.
    //
    // ⚠️⚠️★★ **وهذا الفحصُ على السجل المُدَّعى وحده** — ★ **ولا يكفي للتعديل
    //    والإلغاء**: ⟵ **`planOutflow` يُعيده على السجل المخزَّن** ⛔ **قبل
    //    أي كتابة** (`outflow.dart` القيد ②).
    final CalendarDay probe = CalendarDay.fromUtc(_now());
    final OutflowRejected? gate = outflowGate(
      OutflowRequest(
        actor: actor,
        requestId: requestId,
        ledgerType: ledgerType,
        sourceId: sourceId,
        documentNumber: _pendingDocumentNumber,
        documentDate: probe,
        stockDate: probe,
        today: probe,
      ),
      operation,
    );
    if (gate != null) return callableFailure(gate.error);

    return operation.isCreate
        ? _create(call, actor, requestId, sourceId, ledgerType)
        : _amendOrCancel(call, actor, requestId, sourceId, ledgerType, operation);
  }

  // ═════════════════════════════════════════════════════════════════════
  // الإنشاء — ★ **ويومُ المخزون من المنصّة** (راجع ترويسة الملف)
  // ═════════════════════════════════════════════════════════════════════

  Future<Response> _create(
    CallableRequest call,
    AccountRecord actor,
    String requestId,
    String sourceId,
    OutflowLedgerType ledgerType,
  ) async {
    final _OutflowPayload? payload = _readPayload(call);
    if (payload == null) return callableFailure(CallableError.invalidArgument);

    CalendarDay day = CalendarDay.fromUtc(_now());
    String? number;
    // ★ **محاولتان لا أكثر** — ⟵ **فانقلابُ منتصف الليل يُصحَّح مرة واحدة.**
    for (int attempt = 0; attempt < 2; attempt++) {
      final _DayMismatch? drift = await _runCreate(
        actor: actor,
        requestId: requestId,
        sourceId: sourceId,
        ledgerType: ledgerType,
        payload: payload,
        day: day,
        onAllocated: (String allocated) => number = allocated,
      );
      if (drift == null) {
        // ⛅★★★ **ويُعاد احتساب مالية جواني هذا اليوم** — `FR-M14-05`:
        //    ★ **بعد الالتزام لا داخله** (`api-overview.md` §3.2 و§3.3)،
        //    ⛔ **وفشلُه لا يُبطل هذه العملية.**
        await revalueSacksAfterCommit(
          _valuation,
          sourceId: sourceId,
          stockDate: day,
        );
        // ⛅★★★ **وتُعاد بناءُ بطاقة ضمار المالك ليوم السند** — `FR-M15-13`:
        //    ⛔ **على `documentDate` لا `stockDate`** (`GR-49`).
        await buildDailySummariesAfterCommit(
          _summaries,
          days: <OwnerLedgerDay>{
            OwnerLedgerDay(sourceId: sourceId, date: payload.date),
          },
          today: day,
        );
        return callableSuccess(<String, Object?>{
          'documentNumber': number,
          'documentDate': payload.date.format(),
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

  Future<_DayMismatch?> _runCreate({
    required AccountRecord actor,
    required String requestId,
    required String sourceId,
    required OutflowLedgerType ledgerType,
    required _OutflowPayload payload,
    required CalendarDay day,
    required void Function(String) onAllocated,
  }) async {
    final String sourcePath =
        _transaction.documentPath(sourcesCollection, sourceId);
    // ★★ **وعدّادٌ مستقلٌّ لكل سجل** — `FR-M22-01` (**ترقيمٌ منفصل**):
    //    ⟵ **`DocumentKind` يفصلهما**، ⛔ **فلا تتشارك السحبيةُ والخرجيةُ
    //    تسلسلاً واحداً.**
    final DocumentKind kind = ledgerType.documentKind;
    final String counterPath = _transaction.documentPath(
      documentCountersCollection,
      documentCounterId(kind: kind, day: day),
    );
    final Map<String, String> itemPaths = <String, String>{
      for (final _QatLineRequest line in payload.qatLines)
        line.itemId: _transaction.documentPath(itemsCollection, line.itemId),
    };
    final Map<String, String> pricePaths = <String, String>{
      for (final _QatLineRequest line in payload.qatLines)
        line.itemId: _transaction.documentPath(
          dailyPricesCollection,
          dailyPriceId(sourceId: sourceId, itemKey: line.itemId, date: day),
        ),
    };

    _DayMismatch? drift;
    await _transaction.run<void>(
      readPaths: <String>[
        sourcePath,
        counterPath,
        ...itemPaths.values,
        ...pricePaths.values,
      ],
      queries: <DocumentQuery>[
        for (final _QatLineRequest line in payload.qatLines)
          inventoryLedgerQuery(
            sourceId: sourceId,
            itemKey: line.itemId,
            day: day,
          ),
      ],
      plan: (TransactionReads reads) {
        // ★★★ **يوم المنصّة هو الحَكَم** — راجع ترويسة الملف.
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
          kind: kind,
          day: day,
          sequence: sequence,
        );
        onAllocated(number);

        // ★★★ **والمفتاح المركّب نوعٌ لا سجل له** — راجع [withLedgerItems]:
        //    ⛔ **بلا هذا لا تُسحَب أنواعُ جونيةٍ إطلاقاً** — ★ **وهي مقايسةُ
        //    `DEBT-55` نفسُها في هذا المسار.**
        final Map<String, ItemRead> items = withLedgerItems(
          readItemRecords(reads, itemPaths),
          reads: reads,
          itemKeys: itemPaths.keys,
          sourceId: sourceId,
        );
        final Outcome<ValidatedOutflow> validated = _validate(
          sourceId: sourceId,
          ledgerType: ledgerType,
          payload: payload,
          items: items,
          // ★★★ **ومرجعُ الجونية يُقاس من الدفتر** — [`DEBT-86`].
          sackIds: ledgerSackIds(reads: reads, itemKeys: itemPaths.keys),
        );
        if (validated is Failure<ValidatedOutflow>) {
          throw AbortTransaction(_mapValidation(validated.error));
        }

        final OutflowPlan plan = planOutflow(
          OutflowRequest(
            actor: actor,
            requestId: requestId,
            ledgerType: ledgerType,
            sourceId: sourceId,
            documentNumber: number,
            documentDate: payload.date,
            // ⛔⛔★★★ **ويومُ المخزون من المنصّة** — راجع ترويسة الملف.
            stockDate: day,
            // ★★★ **ويوم المنصّة هو الحَكَم على «مستقبلي/سابق»** — `A-10`.
            today: observed,
            outflow: (validated as Success<ValidatedOutflow>).value,
            storedSource: reads.document(sourcePath),
            // ⛔★★ **ومستندٌ غائبٌ يقيناً** — ★ **الرقم خُصِّص للتوّ.**
            storedDocument: null,
            items: items,
            ledger: _ledgerOf(
              reads,
              payload.qatLines.map((_QatLineRequest line) => line.itemId),
              items,
            ),
            deviceInfo: payload.deviceInfo,
          ),
          OutflowOperation.createOutflow,
        );
        if (plan case OutflowRejected(:final CallableError error)) {
          throw AbortTransaction(error);
        }

        final OutflowAccepted accepted = plan as OutflowAccepted;

        return AuditedWrite<void>(
          documents: <PendingDocument>[
            for (final InventoryWrite write in accepted.writes)
              _toPending(write),
            // ⛅ **العدّاد يُستهلَك في الالتزام نفسه** — ⟵ **فلا رقمٌ
            //    يُخصَّص ثم تفشل الكتابة فتبقى فجوة.**
            PendingDocument(
              collectionId: documentCountersCollection,
              documentId: documentCounterId(kind: kind, day: day),
              fields: <String, Object?>{counterValueField: sequence},
              updateMask: const <String>[counterValueField],
            ),
            ..._pendingDocumentsOf(
              accepted: accepted,
              sourceId: sourceId,
              day: day,
              reads: reads,
              pricePaths: pricePaths,
            ),
          ],
          deletions: _pendingDeletionsOf(
            accepted: accepted,
            sourceId: sourceId,
            day: day,
            reads: reads,
            pricePaths: pricePaths,
          ),
          entry: accepted.entry,
          result: null,
        );
      },
    ).onError<AbortTransaction>((AbortTransaction error, StackTrace _) {
      // ★ **انقلاب اليوم ليس فشلاً** — ⟵ **يُعاد بناء الطلب باليوم الصحيح.**
      if (drift == null) throw error;
    });

    return drift;
  }

  // ═════════════════════════════════════════════════════════════════════
  // التعديل والإلغاء — ★ **ويومُ المخزون محفورٌ في رقم المستند**
  // ═════════════════════════════════════════════════════════════════════

  Future<Response> _amendOrCancel(
    CallableRequest call,
    AccountRecord actor,
    String requestId,
    String sourceId,
    OutflowLedgerType ledgerType,
    OutflowOperation operation,
  ) async {
    final String? number = call.readString('documentNumber');
    if (number == null) return callableFailure(CallableError.invalidArgument);
    // ★★ **يومُ المخزون من الرقم لا من الجهاز ولا من الساعة** — ★ **ويُقابَل
    //   بـ`stockDate` المخزَّن داخل المعاملة** (`_existenceGate`).
    final CalendarDay? day = parseDocumentNumberDay(number);
    if (day == null) return callableFailure(CallableError.invalidArgument);
    // ⛔⛔★★ **والرقمُ يجب أن يحمل بادئةَ السجل المُدَّعى** — ★ **حارسٌ مبكّر**:
    //   ⟵ **والحَكَمُ النهائي `ledgerType` المخزَّن** (`_existenceGate`).
    if (!number.startsWith('${ledgerType.documentKind.prefix}-')) {
      return callableFailure(CallableError.invalidArgument);
    }

    // ⛔⛔★★★ **ولا فحصَ لغياب السبب** — `ADR-0020`.
    final String? reason = call.readString(outflowReasonField);

    final _OutflowPayload? payload =
        operation.isCancel ? null : _readPayload(call);
    if (!operation.isCancel && payload == null) {
      return callableFailure(CallableError.invalidArgument);
    }

    final String documentPath =
        _transaction.documentPath(outflowsCollection, number);
    final String sourcePath =
        _transaction.documentPath(sourcesCollection, sourceId);

    // ★ **قراءةٌ تمهيدية للمستند** — ⟵ **لمعرفة أنواعه القائمة** التي يجب
    //   أن تُقرأ حركاتُها ولو حُذفت من التعديل. ⛔ **وليست مصدرَ قرار.**
    final Map<String, Object?>? preview = await _transaction.readDocument(
      collectionId: outflowsCollection,
      documentId: number,
    );
    if (preview == null) return callableFailure(CallableError.invalidArgument);

    final Set<String> itemIds = <String>{
      if (payload != null)
        for (final _QatLineRequest line in payload.qatLines) line.itemId,
      ..._storedItemKeys(preview),
    };

    final Map<String, String> itemPaths = <String, String>{
      for (final String itemId in itemIds)
        itemId: _transaction.documentPath(itemsCollection, itemId),
    };
    final Map<String, String> pricePaths = <String, String>{
      for (final String itemId in itemIds)
        itemId: _transaction.documentPath(
          dailyPricesCollection,
          dailyPriceId(sourceId: sourceId, itemKey: itemId, date: day),
        ),
    };

    // ★★ **ويومُ المنصّة يُلتقَط من المعاملة نفسِها** — ⛔ **لا من ساعة
    //    الحاوية** (`GR-54`): ⟵ **وبه وحدَه يُقرَّر أنّ اليومَ المبنيَّ ماضٍ
    //    فيُوسَم «⟳ مُحدَّث بأثر رجعي»** (`FR-M15-12`).
    CalendarDay? platformToday;
    // ★ **وتاريخُ السند قبل التعديل** — ⟵ **فتعديلُ التاريخ يمسّ بطاقتين.**
    final CalendarDay storedDate = _storedDocumentDate(preview, day);

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
        final CalendarDay? observed = platformDayOf(reads);
        if (observed == null) {
          throw const AbortTransaction(CallableError.internal);
        }
        platformToday = observed;
        final Map<String, ItemRead> items = withLedgerItems(
          readItemRecords(reads, itemPaths),
          reads: reads,
          itemKeys: itemPaths.keys,
          sourceId: sourceId,
        );

        ValidatedOutflow? outflow;
        if (payload != null) {
          final Outcome<ValidatedOutflow> validated = _validate(
            sourceId: sourceId,
            ledgerType: ledgerType,
            payload: payload,
            items: items,
            // ★★★ **ومرجعُ الجونية يُقاس من الدفتر** — [`DEBT-86`].
            sackIds: ledgerSackIds(reads: reads, itemKeys: itemPaths.keys),
          );
          if (validated is Failure<ValidatedOutflow>) {
            throw AbortTransaction(_mapValidation(validated.error));
          }
          outflow = (validated as Success<ValidatedOutflow>).value;
        }

        final OutflowPlan plan = planOutflow(
          OutflowRequest(
            actor: actor,
            requestId: requestId,
            ledgerType: ledgerType,
            sourceId: sourceId,
            documentNumber: number,
            // ★ **تاريخُ السند من الحمولة عند التعديل** — ⟵ **ومن المخزَّن
            //   عند الإلغاء**: ⛔ **فالإلغاءُ لا يُغيِّر تاريخاً.**
            documentDate: payload?.date ?? storedDate,
            stockDate: day,
            today: observed,
            outflow: outflow,
            storedSource: reads.document(sourcePath),
            storedDocument: reads.document(documentPath),
            items: items,
            ledger: _ledgerOf(reads, itemIds, items),
            reason: reason,
            deviceInfo: call.readString('deviceInfo'),
          ),
          operation,
        );
        if (plan case OutflowRejected(:final CallableError error)) {
          throw AbortTransaction(error);
        }

        final OutflowAccepted accepted = plan as OutflowAccepted;

        return AuditedWrite<void>(
          documents: <PendingDocument>[
            for (final InventoryWrite write in accepted.writes)
              _toPending(write),
            ..._pendingDocumentsOf(
              accepted: accepted,
              sourceId: sourceId,
              day: day,
              reads: reads,
              pricePaths: pricePaths,
            ),
          ],
          deletions: _pendingDeletionsOf(
            accepted: accepted,
            sourceId: sourceId,
            day: day,
            reads: reads,
            pricePaths: pricePaths,
          ),
          entry: accepted.entry,
          result: null,
        );
      },
    );

    // ⛅★★★ **ويُعاد احتساب مالية جواني هذا اليوم** — `FR-M14-05`:
    //    ★ **بعد الالتزام لا داخله** (`api-overview.md` §3.2 و§3.3)،
    //    ⛔ **وفشلُه لا يُبطل هذه العملية** (راجع `revalueSacksAfterCommit`).
    await revalueSacksAfterCommit(
      _valuation,
      sourceId: sourceId,
      stockDate: day,
    );
    // ⛅★★★ **وبطاقتان لا واحدة متى غيّر التعديلُ تاريخَ السند** —
    //    ⟵ **فاليومُ القديم يفقد المبلغ واليومُ الجديد يكسبه**: ⛔ **وبناءُ
    //    الجديد وحدَه كان يترك رقماً ميتاً في بطاقةِ أمس إلى الأبد.**
    await buildDailySummariesAfterCommit(
      _summaries,
      days: <OwnerLedgerDay>{
        OwnerLedgerDay(sourceId: sourceId, date: storedDate),
        if (payload?.date case final CalendarDay amended)
          OwnerLedgerDay(sourceId: sourceId, date: amended),
      },
      today: platformToday ?? day,
    );

    return callableSuccess(<String, Object?>{
      'documentNumber': number,
      'stockDate': day.format(),
    });
  }

  // ═════════════════════════════════════════════════════════════════════
  // ★★ المركز المعلّق — **بندُ السند وبنودُ `M9` معاً في حصيلةٍ واحدة**
  // ═════════════════════════════════════════════════════════════════════

  /// ★★★ **حصيلةٌ واحدة تُدمَج** — ⛔ **لا حصيلتان تُكتبان بالتتابع:**
  /// ⟵ **فلو مسّ السندُ نوعاً وأخلى بندَ `M9` عنه بينما أبقى بندَ نفسِه**،
  /// ★ **[mergePendingSets] يجعل الكتابةَ تغلب المحوَ عند تعارض المعرّف**
  /// (`GR-50`) ⛔ **بينما كتابتان متتابعتان كانتا تُلغيان إحداهما الأخرى.**
  PendingEntrySet _pendingSetOf({
    required OutflowAccepted accepted,
    required String sourceId,
    required CalendarDay day,
    required TransactionReads reads,
    required Map<String, String> pricePaths,
  }) {
    final Map<String, Map<String, Object?>?> storedPrices =
        <String, Map<String, Object?>?>{
      for (final MapEntry<String, String> entry in pricePaths.entries)
        entry.key: reads.document(entry.value),
    };
    return mergePendingSets(<PendingEntrySet>[
      // ⏳ **بندُ `M9` يُزال متى استنفد السحبُ رصيدَ النوع** — `AT-16`.
      pendingFromBalanceWrites(
        writes: accepted.writes,
        sourceId: sourceId,
        date: day,
        storedPrices: storedPrices,
      ),
      // ⏳★★★ **وبندُ السند نفسِه** — `FR-M22-07` · `E-27` · `AT-41`:
      //    ⟵ **وهو ما كان `M22` بلا كاتبٍ له حتى هذه الزيادة**
      //    (`pending-entries-design.md` §11 البند 1).
      describeOutflowPending(
        outflowId: accepted.documentNumber,
        sourceId: sourceId,
        stockDate: day,
        categoryLabel: accepted.categoryLabel,
        unpricedLineCount: accepted.unpricedItemCount,
        documentNumber: accepted.documentNumber,
        isCancelled: accepted.isCancelled,
      ),
    ]);
  }

  List<PendingDocument> _pendingDocumentsOf({
    required OutflowAccepted accepted,
    required String sourceId,
    required CalendarDay day,
    required TransactionReads reads,
    required Map<String, String> pricePaths,
  }) =>
      pendingEntryDocuments(
        _pendingSetOf(
          accepted: accepted,
          sourceId: sourceId,
          day: day,
          reads: reads,
          pricePaths: pricePaths,
        ),
      );

  List<PendingDeletion> _pendingDeletionsOf({
    required OutflowAccepted accepted,
    required String sourceId,
    required CalendarDay day,
    required TransactionReads reads,
    required Map<String, String> pricePaths,
  }) =>
      pendingEntryDeletions(
        _pendingSetOf(
          accepted: accepted,
          sourceId: sourceId,
          day: day,
          reads: reads,
          pricePaths: pricePaths,
        ),
      );

  // ═════════════════════════════════════════════════════════════════════
  // قراءة الحمولة والمخزَّن
  // ═════════════════════════════════════════════════════════════════════

  /// ★ **يبني السند من سجلات الأنواع لا من الحمولة** — ⟵ **فاسمُ النوع
  /// ووحدتُه من القاعدة**، ⛔ **ولا يُرسل العميل وحدةً فيُنشئ حركةً بوحدةٍ
  /// ليست وحدة النوع** (`FR-M5-03` · `GR-19`).
  static Outcome<ValidatedOutflow> _validate({
    required String sourceId,
    required OutflowLedgerType ledgerType,
    required _OutflowPayload payload,
    required Map<String, ItemRead> items,
    required Map<String, String> sackIds,
  }) {
    final List<OutflowQatLineInput> qatLines = <OutflowQatLineInput>[];
    for (final _QatLineRequest line in payload.qatLines) {
      final ItemRead? item = items[line.itemId];
      if (item == null) {
        return const Failure<ValidatedOutflow>(ValidationError('FR-M22-05'));
      }
      final StockQuantity? quantity = _quantityOf(line.quantity, item.unit);
      if (quantity == null) {
        return const Failure<ValidatedOutflow>(ValidationError('BR-M22-09'));
      }
      qatLines.add(
        OutflowQatLineInput(
          itemId: line.itemId,
          itemName: item.name,
          unit: item.unit,
          quantity: quantity,
          // ★★★ **والسعر اختياريٌّ** — `FR-M22-07`: ⛔ **بخلاف البيع النقدي**.
          unitPrice: line.unitPrice,
          // ★★★ **والمقيسُ يسبق المُرسَل** — [`DEBT-86`] · `ADR-0007` ⑤:
          //    ⟵ **فحركةُ الخروج تحمل مرجعَ جونيتها ولو لم تُرسِله الشاشة.**
          sackId: sackIds[line.itemId] ?? line.sackId,
        ),
      );
    }

    return validateOutflow(
      OutflowInput(
        ledgerType: ledgerType,
        sourceId: sourceId,
        category: payload.category,
        qatLines: qatLines,
        cashLines: payload.cashLines,
        notes: payload.notes,
      ),
    );
  }

  /// ★ يترجم رفضَ طبقة النطاق إلى رمز الكتالوج.
  static CallableError _mapValidation(AppError error) => switch (error) {
        ValidationError(ruleCode: 'FR-M22-02') =>
          CallableError.outflowSourceMissing,
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

  /// ★ أنواعُ القات في المستند المخزَّن — **من `lines[]` بحقل `itemType`**.
  ///
  /// ⛔★★ **ويُصفّي على `itemType` صراحةً** — ⟵ **فسطرُ المبلغ لا `itemId`
  /// له**: ★ **وقراءتُه ككلٍّ كانت تُدخِل مفتاحاً فارغاً في قائمة الأنواع.**
  static Set<String> _storedItemKeys(Map<String, Object?> document) {
    final Object? lines = document['lines'];
    if (lines is! List<Object?>) return <String>{};
    return <String>{
      for (final Object? line in lines)
        if (line is Map<String, Object?>)
          if (line['itemType'] == OutflowLineKind.qat.name)
            if ((line['itemId'] ?? line['itemKey']) case final String key) key,
    };
  }

  /// ★ تاريخُ السند المخزَّن — **للإلغاء وحده** ⛔ **ولا يُغيَّر فيه.**
  static CalendarDay _storedDocumentDate(
    Map<String, Object?> stored,
    CalendarDay fallback,
  ) {
    final Object? raw = stored['documentDate'];
    if (raw is DateTime) return CalendarDay.fromUtc(raw.toUtc());
    if (raw is String) {
      return CalendarDay.tryParseCompact(raw.trim()) ?? fallback;
    }
    return fallback;
  }

  /// ★★ **السجل على السلك** — ⛔ **وقيمةٌ مجهولةٌ رفضٌ لا افتراض:**
  /// ⟵ **وافتراضُ «سحبية» عند الغموض كان يفتح السجلَّ الحسّاس بالخطأ.**
  static OutflowLedgerType? _readLedgerType(Object? raw) {
    for (final OutflowLedgerType type in OutflowLedgerType.values) {
      if (type.name == raw) return type;
    }
    return null;
  }

  static OutflowCategory? _readCategory(Object? raw) {
    for (final OutflowCategory category in OutflowCategory.values) {
      if (category.name == raw) return category;
    }
    return null;
  }

  /// ★★ **تاريخ السند على السلك — `YYYYMMDD` المُدمَج** — ★ **نفس صيغة سند
  /// القبض والخصم**، ⛔ **ولا صيغةَ ثانيةً تُخترَع.**
  static CalendarDay? _readDay(Object? raw) {
    if (raw is String) return CalendarDay.tryParseCompact(raw.trim());
    return null;
  }

  _OutflowPayload? _readPayload(CallableRequest call) {
    final CalendarDay? date = _readDay(call.data['date']);
    if (date == null) return null;

    final OutflowCategory? category = _readCategory(call.data['category']);
    if (category == null) return null;

    final List<_QatLineRequest> qatLines = <_QatLineRequest>[];
    final Object? rawQat = call.data['qatLines'];
    if (rawQat != null) {
      if (rawQat is! List<Object?>) return null;
      for (final Object? entry in rawQat) {
        if (entry is! Map<String, Object?>) return null;
        final Object? itemId = entry['itemId'];
        if (itemId is! String || itemId.trim().isEmpty) return null;
        final Object? rawQuantity = entry['quantity'];
        final num? quantity = rawQuantity is num
            ? rawQuantity
            : (rawQuantity is String ? num.tryParse(rawQuantity) : null);
        if (quantity == null) return null;
        // ★★★ **والسعرُ غائبٌ مقبول** — `FR-M22-07`: ⟵ **والحقلُ الموجودُ
        //    بقيمةٍ لا تُقرأ عدداً صحيحاً رفضٌ لا تجاهل** (`ADR-0015`).
        final Object? rawPrice = entry['unitPrice'];
        Money? unitPrice;
        if (rawPrice != null) {
          final int? price = readInt(rawPrice);
          if (price == null) return null;
          unitPrice = Money(price);
        }
        final Object? sackId = entry['sackId'];
        qatLines.add(
          _QatLineRequest(
            itemId: itemId.trim(),
            quantity: quantity,
            unitPrice: unitPrice,
            sackId: sackId is String && sackId.trim().isNotEmpty
                ? sackId.trim()
                : null,
          ),
        );
      }
    }

    final List<OutflowCashLineInput> cashLines = <OutflowCashLineInput>[];
    final Object? rawCash = call.data['cashLines'];
    if (rawCash != null) {
      if (rawCash is! List<Object?>) return null;
      for (final Object? entry in rawCash) {
        if (entry is! Map<String, Object?>) return null;
        final OutflowLineKind? kind = _readLineKind(entry['kind']);
        if (kind == null) return null;
        final int? amount = readInt(entry['amount']);
        // ⛔★★ **ومبلغٌ لا يُقرأ عدداً صحيحاً رفضٌ لا تجاهل** — `ADR-0015`.
        if (amount == null) return null;
        final Object? description = entry['description'];
        cashLines.add(
          OutflowCashLineInput(
            kind: kind,
            amount: Money(amount),
            description: description is String ? description : null,
          ),
        );
      }
    }

    return _OutflowPayload(
      date: date,
      category: category,
      qatLines: qatLines,
      cashLines: cashLines,
      notes: call.readString('notes'),
      deviceInfo: call.readString('deviceInfo'),
    );
  }

  static OutflowLineKind? _readLineKind(Object? raw) {
    for (final OutflowLineKind kind in OutflowLineKind.values) {
      // ⛔ **و«قات» مرفوضٌ في قائمة المبالغ** — ★ **له قائمتُه.**
      if (kind == OutflowLineKind.qat) continue;
      if (kind.name == raw) return kind;
    }
    return null;
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

/// حمولةُ السند كما وصلت — ⛔ **بلا اسمٍ ولا وحدة**: كلاهما من القاعدة.
final class _OutflowPayload {
  const _OutflowPayload({
    required this.date,
    required this.category,
    required this.qatLines,
    required this.cashLines,
    required this.notes,
    required this.deviceInfo,
  });

  final CalendarDay date;
  final OutflowCategory category;
  final List<_QatLineRequest> qatLines;
  final List<OutflowCashLineInput> cashLines;
  final String? notes;
  final String? deviceInfo;
}

/// سطرُ قاتٍ كما وصل في الحمولة.
final class _QatLineRequest {
  const _QatLineRequest({
    required this.itemId,
    required this.quantity,
    required this.unitPrice,
    required this.sackId,
  });

  final String itemId;
  final num quantity;
  final Money? unitPrice;
  final String? sackId;
}

/// ★ انقلاب اليوم بين اقتراح الحاوية وحكم المنصّة — راجع ترويسة الملف.
final class _DayMismatch {
  const _DayMismatch(this.observed);

  /// اليوم كما أعلنته المنصّة.
  final CalendarDay observed;
}

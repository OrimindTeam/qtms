/// تنفيذ عمليات الإتلاف — **الطرف الذي يلمس الشبكة** (`WU-020`).
///
/// ★ **مفصول عن `disposal.dart` عمداً**، بنفس منطق `cash_sale_handler.dart`:
/// كل قرار تفويض وقاعدة عمل هناك في **دوال خالصة تُختبَر بلا سحابة**؛
/// وهنا **الترتيب والقراءة والالتزام** وحدها.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **وثلاثةُ غياباتٍ مقصودةٍ في هذا الملف — كلُّها تنفيذُ متطلبٍ لا نقص:**
///
/// | ما لا يُستدعى هنا | لماذا |
/// |---|---|
/// | **`revalueSacksAfterCommit`** | ⛔ **الإتلافُ لا يدخل سعرَ الجونية** (`design-overview.md` §2.2 · `A-15`) — ★ **واستدعاؤه كان عملاً بلا أثرٍ يُوهِم القارئ أن للإتلاف مدخلاً في السعر** |
/// | **`buildDailySummariesAfterCommit`** | ⛔ **ولا مبلغَ في هذه العملية أصلاً** — ★ **وبطاقةُ ضمار المالك تقرأ `distributions` و`cash_sales` و`sacks` و`outflows` وحدها** (`owner_ledger_summary_handler.dart`) |
/// | **دفترا المقاوته والرعوي** | `GR-29` · `A-15` — ★ **«كل قات يخرج يستحق الرعوي ثمنه — والاستثناء الوحيد: الإتلاف والوزن الضائع»** |
///
/// ★★★ **وما يُستدعى منها ضروريٌّ لا تجميلي:**
///   · **راصدُ المتبقي المتأخر** (`aged_remainder.dart`) — ⟵ **الإتلافُ
///     يُنقِص الرصيد فقد يُصفّره**: ★ **فيُمحى بندُه في المعاملة نفسِها**،
///     ⛔ **وإلا بقيت الشاشة تُطالب بتصريف عدمٍ أُتلِف فعلاً** (`GR-16`).
///   · **بنودُ `M9` المعلّقة** (`pendingFromBalanceWrites`) — `AT-16`:
///     ⟵ **وبندُ «نوعٌ بلا سعر» يزول متى استنفد الإتلافُ رصيدَه.**
///     ⛔⛔ **ولا بندَ تسعيرٍ للمستند نفسِه** — ★ **لا سعرَ فيه يُنتظَر.**
///
/// ★★ **وتاريخُ المخزون من الحمولة لا من المنصّة** — ⛔ **بخلاف
/// `outflow_handler.dart`**: ⟵ **لأن الإتلافَ ثالثُ إجراءات تصريف المتبقي
/// المتأخر** (`FR-M8-11`)، ★ **وغيابُه هو الحالُ الأصلي (مخزون اليوم)**
/// ⛔ **ونصٌّ مشوَّه رفضٌ صريحٌ لا سقوطٌ صامتٌ إلى «اليوم»** (`RISK-07`).
/// ═══════════════════════════════════════════════════════════════════════
library;

import 'package:qtms_domain/qtms_domain.dart';
import 'package:shelf/shelf.dart';

import 'aged_remainder.dart';
import 'audited_transaction.dart';
import 'callable.dart';
import 'counter_allocator.dart' show counterValueField;
import 'disposal.dart';
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
import 'pending_entries.dart';
import 'permission_sync_handler.dart' show requestIdField;

/// اسم حقل السبب في الحمولة — ★ **اختياريٌّ** (`ADR-0020`).
const String disposalReasonField = 'reason';

/// اسم حقل تاريخ المخزون المطلوب في الحمولة — ★ **مسارُ التصريف المتأخر**.
const String disposalStockDateField = 'stockDate';

/// منفّذ عمليات الإتلاف.
final class DisposalHandler {
  /// ينشئ المنفّذ بتبعياته — ★ **تُحقَن، فيُختبَر بلا سحابة**.
  const DisposalHandler({
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
    DisposalOperation operation,
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
    DisposalOperation operation,
  ) async {
    final AccountRecord actor = await _identity.verifyIdToken(call.idToken);
    final String? requestId = call.readString(requestIdField);
    final String? sourceId = call.readString('sourceId');
    if (requestId == null || sourceId == null || sourceId.trim().isEmpty) {
      return callableFailure(CallableError.invalidArgument);
    }

    // ① البوابة — ⛔ قبل أي معاملة: الصلاحية **والنطاق** معاً.
    final DisposalRejected? gate = disposalGate(
      DisposalRequest(
        actor: actor,
        requestId: requestId,
        sourceId: sourceId,
        documentNumber: _pendingDocumentNumber,
        stockDate: CalendarDay.fromUtc(_now()),
      ),
      operation,
    );
    if (gate != null) return callableFailure(gate.error);

    return operation.isCreate
        ? _create(call, actor, requestId, sourceId)
        : _amendOrCancel(call, actor, requestId, sourceId, operation);
  }

  // ═════════════════════════════════════════════════════════════════════
  // الإنشاء
  // ═════════════════════════════════════════════════════════════════════

  Future<Response> _create(
    CallableRequest call,
    AccountRecord actor,
    String requestId,
    String sourceId,
  ) async {
    final List<_LineRequest>? lines = _readLines(call);
    if (lines == null || lines.isEmpty) {
      return callableFailure(CallableError.invalidArgument);
    }

    // ★★★ **تاريخُ المخزون المطلوب — مسارُ التصريف المتأخر** (`FR-M8-11`):
    //    ⛔⛔ **وغيابُه هو الحالُ الأصلي**، ★ **ووجودُه يُثبِّت اليوم ويُخضِع
    //    الطلبَ لـ`agedRemainderClear`** داخل [planDisposal].
    final String? requestedDay = call.readString(disposalStockDateField);
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
      final _DayMismatch? drift = await _runCreate(
        call: call,
        actor: actor,
        requestId: requestId,
        sourceId: sourceId,
        lines: lines,
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

  Future<_DayMismatch?> _runCreate({
    required CallableRequest call,
    required AccountRecord actor,
    required String requestId,
    required String sourceId,
    required List<_LineRequest> lines,
    required CalendarDay day,
    required bool isPinned,
    required void Function(String) onAllocated,
  }) async {
    final String sourcePath =
        _transaction.documentPath(sourcesCollection, sourceId);
    final String counterPath = _transaction.documentPath(
      documentCountersCollection,
      documentCounterId(kind: DocumentKind.disposal, day: day),
    );
    final Map<String, String> itemPaths = <String, String>{
      for (final _LineRequest line in lines)
        line.itemId: _transaction.documentPath(itemsCollection, line.itemId),
    };
    // ★★ **وسجلُّ سعر اليوم لكل نوع** — ⛔ **لا لسعرٍ يُقرأ** (لا سعر هنا):
    //    ⟵ **بل لبنود المركز المعلّق وحدها** (`pendingFromBalanceWrites`).
    final Map<String, String> pricePaths = <String, String>{
      for (final _LineRequest line in lines)
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
        for (final _LineRequest line in lines)
          inventoryLedgerQuery(
            sourceId: sourceId,
            itemKey: line.itemId,
            day: day,
          ),
      ],
      plan: (TransactionReads reads) {
        // ★★★ **يوم المنصّة هو الحَكَم** — `GR-54`.
        final CalendarDay? observed = platformDayOf(reads);
        if (observed == null) {
          throw const AbortTransaction(CallableError.internal);
        }
        // ⛔⛔★★★ **والانقلابُ يُصحَّح في المسار غير المثبَّت وحده** —
        //    ★ **واليومُ المثبَّت مقصودٌ لا انزلاق** (`WU-019`).
        if (!isPinned && observed != day) {
          drift = _DayMismatch(observed);
          throw const AbortTransaction(CallableError.concurrency);
        }

        final int sequence = nextSequence(
          readInt(reads.document(counterPath)?[counterValueField]),
        );
        final String number = formatDocumentNumber(
          kind: DocumentKind.disposal,
          day: day,
          sequence: sequence,
        );
        onAllocated(number);

        // ★★★ **والمفتاح المركّب نوعٌ لا سجل له** — راجع [withLedgerItems]:
        //    ⛔ **بلا هذا لا يُتلَف سطرُ جونيةٍ إطلاقاً** — ★ **وهي مقايسةُ
        //    `DEBT-55` و[`DEBT-86`] نفسُها في هذا المسار.**
        final Map<String, ItemRead> items = withLedgerItems(
          readItemRecords(reads, itemPaths),
          reads: reads,
          itemKeys: itemPaths.keys,
          sourceId: sourceId,
        );
        final Outcome<ValidatedDisposal> validated = _validate(
          sourceId: sourceId,
          lines: lines,
          items: items,
          // ★★★ **ومرجعُ الجونية يُقاس من الدفتر** — [`DEBT-86`].
          sackIds: ledgerSackIds(reads: reads, itemKeys: itemPaths.keys),
          reason: call.readString(disposalReasonField),
        );
        if (validated is Failure<ValidatedDisposal>) {
          throw AbortTransaction(_mapValidation(validated.error));
        }

        final DisposalPlan plan = planDisposal(
          DisposalRequest(
            actor: actor,
            requestId: requestId,
            sourceId: sourceId,
            documentNumber: number,
            stockDate: day,
            // ★★★ **ويومُ المنصّة يبلغ المُخطِّط الخالص** — ⟵ **فبوابةُ
            //    التصريف المتأخر تُقرَّر هناك** (`ADR-0013` القاعدة 3).
            serverDay: observed,
            disposal: (validated as Success<ValidatedDisposal>).value,
            storedSource: reads.document(sourcePath),
            // ⛔★★ **ومستندٌ غائبٌ يقيناً** — ★ **الرقم خُصِّص للتوّ.**
            storedDocument: null,
            items: items,
            ledger: _ledgerOf(
              reads,
              lines.map((_LineRequest line) => line.itemId),
              items,
            ),
            deviceInfo: call.readString('deviceInfo'),
          ),
          DisposalOperation.createDisposal,
        );
        if (plan case DisposalRejected(:final CallableError error)) {
          throw AbortTransaction(error);
        }

        final DisposalAccepted accepted = plan as DisposalAccepted;
        return AuditedWrite<void>(
          documents: <PendingDocument>[
            for (final InventoryWrite write in accepted.writes)
              _toPending(write),
            // ⛅ **العدّاد يُستهلَك في الالتزام نفسه** — ⟵ **فلا رقمٌ
            //    يُخصَّص ثم تفشل الكتابة فتبقى فجوة.**
            PendingDocument(
              collectionId: documentCountersCollection,
              documentId:
                  documentCounterId(kind: DocumentKind.disposal, day: day),
              fields: <String, Object?>{counterValueField: sequence},
              updateMask: const <String>[counterValueField],
            ),
            ..._pendingDocumentsOf(accepted, sourceId, day, reads, pricePaths),
            ...agedRemaindersFromBalanceWrites(accepted.writes).documents,
          ],
          deletions: <PendingDeletion>[
            ..._pendingDeletionsOf(accepted, sourceId, day, reads, pricePaths),
            ...agedRemaindersFromBalanceWrites(accepted.writes).deletions,
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
  // التعديل والإلغاء — ★ **ويومُ المخزون محفورٌ في رقم المستند**
  // ═════════════════════════════════════════════════════════════════════

  Future<Response> _amendOrCancel(
    CallableRequest call,
    AccountRecord actor,
    String requestId,
    String sourceId,
    DisposalOperation operation,
  ) async {
    final String? number = call.readString('documentNumber');
    if (number == null) return callableFailure(CallableError.invalidArgument);
    // ★★ **يومُ المخزون من الرقم لا من الجهاز ولا من الساعة**.
    final CalendarDay? day = parseDocumentNumberDay(number);
    if (day == null) return callableFailure(CallableError.invalidArgument);
    // ⛔ **والرقمُ يجب أن يحمل بادئةَ الإتلاف** — ★ **حارسٌ مبكّر**:
    //   ⟵ **والحَكَمُ النهائي المستندُ المخزَّن نفسُه** (`_existenceGate`).
    if (!number.startsWith('${DocumentKind.disposal.prefix}-')) {
      return callableFailure(CallableError.invalidArgument);
    }

    // ⛔⛔★★★ **ولا فحصَ لغياب السبب** — `ADR-0020`.
    final String? reason = call.readString(disposalReasonField);

    final List<_LineRequest> lines = operation.isCancel
        ? const <_LineRequest>[]
        : (_readLines(call) ?? const <_LineRequest>[]);
    if (!operation.isCancel && lines.isEmpty) {
      return callableFailure(CallableError.invalidArgument);
    }

    final String documentPath =
        _transaction.documentPath(disposalsCollection, number);
    final String sourcePath =
        _transaction.documentPath(sourcesCollection, sourceId);

    // ★ **قراءةٌ تمهيدية للمستند** — ⟵ **لمعرفة أنواعه القائمة** التي يجب
    //   أن تُقرأ حركاتُها ولو حُذفت من التعديل. ⛔ **وليست مصدرَ قرار**:
    //   المعاملة تُعيد قراءة المستند وتحكم به (`_existenceGate`).
    final Map<String, Object?>? preview = await _transaction.readDocument(
      collectionId: disposalsCollection,
      documentId: number,
    );
    if (preview == null) return callableFailure(CallableError.invalidArgument);

    final Set<String> itemIds = <String>{
      for (final _LineRequest line in lines) line.itemId,
      ..._storedItemKeys(preview),
    };
    if (itemIds.isEmpty) return callableFailure(CallableError.invalidArgument);

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

        ValidatedDisposal? disposal;
        if (!operation.isCancel) {
          final Outcome<ValidatedDisposal> validated = _validate(
            sourceId: sourceId,
            lines: lines,
            items: items,
            sackIds: ledgerSackIds(reads: reads, itemKeys: itemPaths.keys),
            reason: call.readString(disposalReasonField),
          );
          if (validated is Failure<ValidatedDisposal>) {
            throw AbortTransaction(_mapValidation(validated.error));
          }
          disposal = (validated as Success<ValidatedDisposal>).value;
        }

        final DisposalPlan plan = planDisposal(
          DisposalRequest(
            actor: actor,
            requestId: requestId,
            sourceId: sourceId,
            documentNumber: number,
            stockDate: day,
            // ⛔⛔★★ **ولا `serverDay` هنا** — راجع [DisposalRequest.serverDay]:
            //    ★ **تصحيحُ مستندٍ قائمٍ ليس تصريفاً جديداً.**
            disposal: disposal,
            storedSource: reads.document(sourcePath),
            storedDocument: reads.document(documentPath),
            items: items,
            ledger: _ledgerOf(reads, itemIds, items),
            reason: reason,
            deviceInfo: call.readString('deviceInfo'),
          ),
          operation,
        );
        if (plan case DisposalRejected(:final CallableError error)) {
          throw AbortTransaction(error);
        }

        final DisposalAccepted accepted = plan as DisposalAccepted;
        return AuditedWrite<void>(
          documents: <PendingDocument>[
            for (final InventoryWrite write in accepted.writes)
              _toPending(write),
            ..._pendingDocumentsOf(accepted, sourceId, day, reads, pricePaths),
            ...agedRemaindersFromBalanceWrites(accepted.writes).documents,
          ],
          deletions: <PendingDeletion>[
            ..._pendingDeletionsOf(accepted, sourceId, day, reads, pricePaths),
            ...agedRemaindersFromBalanceWrites(accepted.writes).deletions,
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
    DisposalAccepted accepted,
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
    DisposalAccepted accepted,
    String sourceId,
    CalendarDay day,
    TransactionReads reads,
    Map<String, String> pricePaths,
  ) =>
      pendingEntryDocuments(
        _pendingSetOf(accepted, sourceId, day, reads, pricePaths),
      );

  List<PendingDeletion> _pendingDeletionsOf(
    DisposalAccepted accepted,
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

  /// ★ **يبني المستند من سجلات الأنواع لا من الحمولة** — ⟵ **فاسمُ النوع
  /// ووحدتُه من القاعدة**، ⛔ **ولا يُرسل العميل وحدةً فيُنشئ حركةً بوحدةٍ
  /// ليست وحدة النوع** (`FR-M5-03` · `GR-19`).
  static Outcome<ValidatedDisposal> _validate({
    required String sourceId,
    required List<_LineRequest> lines,
    required Map<String, ItemRead> items,
    required Map<String, String> sackIds,
    required String? reason,
  }) {
    final List<DisposalLineInput> inputs = <DisposalLineInput>[];
    for (final _LineRequest line in lines) {
      final ItemRead? item = items[line.itemId];
      if (item == null) {
        return const Failure<ValidatedDisposal>(ValidationError('FR-M8-16'));
      }
      final StockQuantity? quantity = _quantityOf(line.quantity, item.unit);
      if (quantity == null) {
        return const Failure<ValidatedDisposal>(ValidationError('BR-M8-11'));
      }
      inputs.add(
        DisposalLineInput(
          itemId: line.itemId,
          itemName: item.name,
          unit: item.unit,
          quantity: quantity,
          // ★★★ **والمقيسُ يسبق المُرسَل** — [`DEBT-86`] · `ADR-0007` ⑤.
          sackId: sackIds[line.itemId] ?? line.sackId,
        ),
      );
    }

    return validateDisposal(
      DisposalInput(sourceId: sourceId, lines: inputs, reason: reason),
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

  /// ★ أنواعُ المستند المخزَّن — **من `lines[]`**.
  static Set<String> _storedItemKeys(Map<String, Object?> document) {
    final Object? lines = document['lines'];
    if (lines is! List<Object?>) return <String>{};
    return <String>{
      for (final Object? line in lines)
        if (line is Map<String, Object?>)
          if ((line['itemId'] ?? line['itemKey']) case final String key) key,
    };
  }

  List<_LineRequest>? _readLines(CallableRequest call) {
    final Object? raw = call.data['lines'];
    if (raw is! List<Object?>) return null;
    final List<_LineRequest> lines = <_LineRequest>[];
    for (final Object? entry in raw) {
      if (entry is! Map<String, Object?>) return null;
      final Object? itemId = entry['itemId'];
      if (itemId is! String || itemId.trim().isEmpty) return null;
      final Object? rawQuantity = entry['quantity'];
      final num? quantity = rawQuantity is num
          ? rawQuantity
          : (rawQuantity is String ? num.tryParse(rawQuantity) : null);
      if (quantity == null) return null;
      // ⛔⛔★★★ **ولا حقلَ سعرٍ يُقرأ من الحمولة إطلاقاً** — `FR-M8-16`:
      //    ★ **وما لا يُقرأ لا يُكتب**، ⟵ **فحمولةٌ تحمل `unitPrice`
      //    تُتجاهَل بنيوياً** ⛔ **لا بشرطٍ يُنسى.**
      final Object? sackId = entry['sackId'];
      lines.add(
        _LineRequest(
          itemId: itemId.trim(),
          quantity: quantity,
          sackId:
              sackId is String && sackId.trim().isNotEmpty ? sackId.trim() : null,
        ),
      );
    }
    return lines;
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

/// سطرُ إتلافٍ كما وصل في الحمولة — ⛔ **بلا اسمٍ ولا وحدة**: كلاهما من القاعدة.
final class _LineRequest {
  const _LineRequest({
    required this.itemId,
    required this.quantity,
    required this.sackId,
  });

  final String itemId;
  final num quantity;
  final String? sackId;
}

/// ★ انقلاب اليوم بين اقتراح الحاوية وحكم المنصّة.
final class _DayMismatch {
  const _DayMismatch(this.observed);

  /// اليوم كما أعلنته المنصّة.
  final CalendarDay observed;
}

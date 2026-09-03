/// تنفيذ عمليات البيع النقدي — **الطرف الذي يلمس الشبكة** (`WU-012`).
///
/// ★ **مفصول عن `cash_sale.dart` عمداً**، بنفس منطق `distribution_handler.dart`:
/// كل قرار تفويض وقاعدة عمل هناك في **دوال خالصة تُختبَر بلا سحابة**؛
/// وهنا **الترتيب والقراءة والالتزام** وحدها.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ★★★ **يوم المخزون هنا يوم المنصّة — بنفس آلية `inventory_handler.dart`**
///
/// `A-10` و`GR-14`: **النظام هو من يحدد تاريخ المخزون لا المستخدم**.
/// ⟵ ★ **والحاوية تقترح والمنصّة تحكم**: يُقترَح اليوم، وتُبنى القراءات به،
/// **ويصل زمن المنصّة مع نتيجة الاستعلام** (`readTime`)، ⛔ **وإن اختلف
/// أُعيدت المحاولة مرة واحدة باليوم الذي أعلنته المنصّة.**
///
/// ⚠️ **والتصريف المتأخر خارج نطاق هذه الزيادة** — `FR-M11-10` يذكر البيع من
/// مخزون يومٍ سابق، ★ **وتلك `WU-019`** بمفتاحها `agedRemainderClear` —
/// ⛔ **ولا مسار له هنا اليوم**، ⟵ **فلا تاريخ يُقبَل من الجهاز إطلاقاً.**
/// ═══════════════════════════════════════════════════════════════════════
///
/// ⛔⛔★★★ **ولا قراءةَ واحدة لدفتر المقاوته ولا لسجل مقوت** — `FR-M11-03`:
/// ★ **والغياب هنا تنفيذُ المتطلب لا نقصٌ فيه**: ⟵ **قراءةُ ما لا يُكتَب
/// تُغري بأن يُبنى عليه قرار.**
///
/// ★★★ **وقراءةُ `daily_prices` إلزامية في المسارين معاً** (`FR-M11-05`) —
/// ★ **فمنها الحدُّ الأدنى الذي يحرسه [planCashSale]**، ⟵ **ومنها كذلك
/// بنودُ المركز المعلّق** (`pendingFromBalanceWrites`): ⛔ **وقراءةٌ واحدة
/// تخدم الغرضين** لا قراءتان تفترقان.
library;

import 'package:qtms_domain/qtms_domain.dart';
import 'package:shelf/shelf.dart';

import 'audited_transaction.dart';
import 'callable.dart';
import 'sack_valuation_handler.dart';
import 'cash_sale.dart';
import 'owner_ledger_summary_handler.dart';
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
import 'pending_entries.dart';
import 'permission_sync_handler.dart' show requestIdField;

/// اسم حقل سبب التعديل أو الإلغاء في الحمولة.
const String cashSaleReasonField = 'reason';

/// منفّذ عمليات البيع النقدي.
final class CashSaleHandler {
  /// ينشئ المنفّذ بتبعياته — ★ **تُحقَن، فيُختبَر بلا سحابة**.
  const CashSaleHandler({
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
  /// ★★ **وعلى `stockDate`** — `schema/cash-sales.md` القاعدة 8: **«إن كان
  /// من مخزون يوم سابق فيُحتسب في «نقدي» ذلك اليوم» لا اليوم الحالي.**
  final OwnerLedgerSummaryHandler? _summaries;

  /// ★ ساعةُ **الاقتراح** وحدها — ⛔ **ولا تُكتب قيمتها في أي حقل** بلا
  /// موافقة المنصّة (راجع ترويسة الملف). تُحقَن في الاختبار.
  final DateTime Function()? _clock;

  DateTime _now() => (_clock ?? DateTime.now)().toUtc();

  /// ينفّذ [operation] على طلب HTTP خام.
  Future<Response> handle(
    Request httpRequest,
    CashSaleOperation operation,
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
    CashSaleOperation operation,
  ) async {
    final AccountRecord actor = await _identity.verifyIdToken(call.idToken);
    final String? requestId = call.readString(requestIdField);
    final String? sourceId = call.readString('sourceId');
    if (requestId == null || sourceId == null) {
      return callableFailure(CallableError.invalidArgument);
    }

    // ① البوابة — ⛔ قبل أي معاملة: الصلاحية **والنطاق** معاً.
    final CashSaleRejected? gate = cashSaleGate(
      CashSaleRequest(
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
  // الإنشاء — ★ **واليوم من المنصّة** (راجع ترويسة الملف)
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

    CalendarDay day = CalendarDay.fromUtc(_now());
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
        // ⛅★★★ **وتُعاد بناءُ بطاقة ضمار المالك** — `FR-M15-13` · `FR-M15-01`:
        //    ★ **والبيعُ النقدي بندُ «منه نقدي» فيها.**
        await buildDailySummariesAfterCommit(
          _summaries,
          days: <OwnerLedgerDay>{
            OwnerLedgerDay(sourceId: sourceId, date: day),
          },
          today: day,
        );
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
    required void Function(String) onAllocated,
  }) async {
    final String sourcePath =
        _transaction.documentPath(sourcesCollection, sourceId);
    final String counterPath = _transaction.documentPath(
      documentCountersCollection,
      documentCounterId(kind: DocumentKind.cashSale, day: day),
    );
    final Map<String, String> itemPaths = <String, String>{
      for (final _LineRequest line in lines)
        line.itemId: _transaction.documentPath(itemsCollection, line.itemId),
    };
    // ★★★ **وسجل سعر اليوم لكل نوع** — **مصدرُ الحدّ الأدنى** (`FR-M11-05`)
    //    ⟵ **ومصدرُ بنود المركز المعلّق معاً** (راجع ترويسة الملف).
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
          kind: DocumentKind.cashSale,
          day: day,
          sequence: sequence,
        );
        onAllocated(number);

        // ★★★ **والمفتاح المركّب نوعٌ لا سجل له** — راجع [withLedgerItems]:
        //    ⛔ **بلا هذا لا يُباع سطرُ جونيةٍ إطلاقاً** — ★ **وهي مقايسةُ
        //    `DEBT-55` نفسُها في هذا المسار.**
        final Map<String, ItemRead> items = withLedgerItems(
          readItemRecords(reads, itemPaths),
          reads: reads,
          itemKeys: itemPaths.keys,
          sourceId: sourceId,
        );
        final Outcome<ValidatedCashSale> validated = _validate(
          sourceId: sourceId,
          lines: lines,
          items: items,
          // ★★★ **ومرجعُ الجونية يُقاس من الدفتر** — [`DEBT-86`].
          sackIds: ledgerSackIds(reads: reads, itemKeys: itemPaths.keys),
          notes: call.readString('notes'),
        );
        if (validated is Failure<ValidatedCashSale>) {
          throw AbortTransaction(_mapValidation(validated.error));
        }

        final Map<String, Map<String, Object?>?> storedPrices =
            <String, Map<String, Object?>?>{
          for (final MapEntry<String, String> entry in pricePaths.entries)
            entry.key: reads.document(entry.value),
        };

        final CashSalePlan plan = planCashSale(
          CashSaleRequest(
            actor: actor,
            requestId: requestId,
            sourceId: sourceId,
            documentNumber: number,
            stockDate: day,
            sale: (validated as Success<ValidatedCashSale>).value,
            storedSource: reads.document(sourcePath),
            // ⛔★★ **ومستندٌ غائبٌ يقيناً** — ★ **الرقم خُصِّص للتوّ من عدّاد
            //    اليوم**، ⟵ **فلا سندَ يحمله**: ⛔ **ولا يُقرأ ما لا يوجد.**
            storedDocument: null,
            items: items,
            ledger: _ledgerOf(
              reads,
              lines.map((_LineRequest line) => line.itemId),
              items,
            ),
            minCashPrices: _minimumsOf(storedPrices),
          ),
          CashSaleOperation.createCashSale,
        );
        if (plan case CashSaleRejected(:final CallableError error)) {
          throw AbortTransaction(error);
        }

        final CashSaleAccepted accepted = plan as CashSaleAccepted;

        // ⏳★★★ **وبندُ `M9` يُزال متى استنفد البيعُ رصيدَ النوع** —
        //    `pending-entries-design.md` §9، ★ **ويبقى بدقّة حين يبقى رصيد.**
        //    ⛔⛔ **ولا بندَ تسعيرٍ للسند نفسه** — `FR-M11-04`: ★ **لا سطرَ
        //    بلا سعر في بيعٍ نقدي أصلاً.**
        final PendingEntrySet pending = pendingFromBalanceWrites(
          writes: accepted.writes,
          sourceId: sourceId,
          date: day,
          storedPrices: storedPrices,
        );

        return AuditedWrite<void>(
          documents: <PendingDocument>[
            for (final InventoryWrite write in accepted.writes)
              _toPending(write),
            // ⛅ **العدّاد يُستهلَك في الالتزام نفسه** — ⟵ **فلا رقمٌ
            //    يُخصَّص ثم تفشل الكتابة فتبقى فجوة.**
            PendingDocument(
              collectionId: documentCountersCollection,
              documentId:
                  documentCounterId(kind: DocumentKind.cashSale, day: day),
              fields: <String, Object?>{counterValueField: sequence},
              updateMask: const <String>[counterValueField],
            ),
            ...pendingEntryDocuments(pending),
          ],
          deletions: pendingEntryDeletions(pending),
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
  // التعديل والإلغاء — ★ **واليوم محفورٌ في رقم المستند**
  // ═════════════════════════════════════════════════════════════════════

  Future<Response> _amendOrCancel(
    CallableRequest call,
    AccountRecord actor,
    String requestId,
    String sourceId,
    CashSaleOperation operation,
  ) async {
    final String? number = call.readString('documentNumber');
    if (number == null) return callableFailure(CallableError.invalidArgument);
    // ★★ **اليوم من الرقم لا من الجهاز ولا من الساعة** — ★ **ويُقابَل
    //   بـ`stockDate` المخزَّن داخل المعاملة** (`_existenceGate`).
    final CalendarDay? day = parseDocumentNumberDay(number);
    if (day == null) return callableFailure(CallableError.invalidArgument);

    // ⛔⛔★★★ **ولا فحصَ لغياب السبب** — `ADR-0020`.
    final String? reason = call.readString(cashSaleReasonField);

    final List<_LineRequest> lines = operation.isCancel
        ? const <_LineRequest>[]
        : (_readLines(call) ?? const <_LineRequest>[]);
    if (!operation.isCancel && lines.isEmpty) {
      return callableFailure(CallableError.invalidArgument);
    }

    final String documentPath =
        _transaction.documentPath(cashSalesCollection, number);
    final String sourcePath =
        _transaction.documentPath(sourcesCollection, sourceId);

    // ★ **قراءةٌ تمهيدية للمستند** — ⟵ **لمعرفة أنواعه القائمة** التي يجب
    //   أن تُقرأ حركاتُها ولو حُذفت من التعديل. ⛔ **وليست مصدرَ قرار**:
    //   المعاملة تُعيد قراءة المستند وتحكم به (`_existenceGate`).
    final Map<String, Object?>? preview = await _transaction.readDocument(
      collectionId: cashSalesCollection,
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

    // ★★ **ويومُ المنصّة يُلتقَط من المعاملة نفسِها** — ⛔ **لا من ساعة
    //    الحاوية** (`GR-54`): ⟵ **وبه وحدَه يُعرَف أن اليومَ المبنيَّ ماضٍ
    //    فيُوسَم «⟳ مُحدَّث بأثر رجعي»** (`FR-M15-12`).
    CalendarDay? platformToday;

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
        platformToday = platformDayOf(reads);
        final Map<String, ItemRead> items = withLedgerItems(
          readItemRecords(reads, itemPaths),
          reads: reads,
          itemKeys: itemPaths.keys,
          sourceId: sourceId,
        );

        ValidatedCashSale? sale;
        if (!operation.isCancel) {
          final Outcome<ValidatedCashSale> validated = _validate(
            sourceId: sourceId,
            lines: lines,
            items: items,
            // ★★★ **ومرجعُ الجونية يُقاس من الدفتر** — [`DEBT-86`].
            sackIds: ledgerSackIds(reads: reads, itemKeys: itemPaths.keys),
            notes: call.readString('notes'),
          );
          if (validated is Failure<ValidatedCashSale>) {
            throw AbortTransaction(_mapValidation(validated.error));
          }
          sale = (validated as Success<ValidatedCashSale>).value;
        }

        final Map<String, Map<String, Object?>?> storedPrices =
            <String, Map<String, Object?>?>{
          for (final MapEntry<String, String> entry in pricePaths.entries)
            entry.key: reads.document(entry.value),
        };

        final CashSalePlan plan = planCashSale(
          CashSaleRequest(
            actor: actor,
            requestId: requestId,
            sourceId: sourceId,
            documentNumber: number,
            stockDate: day,
            sale: sale,
            storedSource: reads.document(sourcePath),
            storedDocument: reads.document(documentPath),
            items: items,
            ledger: _ledgerOf(reads, itemIds, items),
            minCashPrices: _minimumsOf(storedPrices),
            reason: reason,
          ),
          operation,
        );
        if (plan case CashSaleRejected(:final CallableError error)) {
          throw AbortTransaction(error);
        }

        final CashSaleAccepted accepted = plan as CashSaleAccepted;

        final PendingEntrySet pending = pendingFromBalanceWrites(
          writes: accepted.writes,
          sourceId: sourceId,
          date: day,
          storedPrices: storedPrices,
        );

        return AuditedWrite<void>(
          documents: <PendingDocument>[
            for (final InventoryWrite write in accepted.writes)
              _toPending(write),
            ...pendingEntryDocuments(pending),
          ],
          deletions: pendingEntryDeletions(pending),
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
    await buildDailySummariesAfterCommit(
      _summaries,
      days: <OwnerLedgerDay>{OwnerLedgerDay(sourceId: sourceId, date: day)},
      today: platformToday ?? day,
    );

    return callableSuccess(<String, Object?>{
      'documentNumber': number,
      'stockDate': day.format(),
    });
  }

  // ═════════════════════════════════════════════════════════════════════
  // قراءة الحمولة والمخزَّن
  // ═════════════════════════════════════════════════════════════════════

  /// ★ **يبني السند من سجلات الأنواع لا من الحمولة** — ⟵ **فاسمُ النوع
  /// ووحدتُه من القاعدة**، ⛔ **ولا يُرسل العميل وحدةً فيُنشئ حركةً بوحدةٍ
  /// ليست وحدة النوع** (`FR-M5-03` · `GR-19`).
  static Outcome<ValidatedCashSale> _validate({
    required String sourceId,
    required List<_LineRequest> lines,
    required Map<String, ItemRead> items,
    required Map<String, String> sackIds,
    required String? notes,
  }) {
    final List<CashSaleLineInput> inputs = <CashSaleLineInput>[];
    for (final _LineRequest line in lines) {
      final ItemRead? item = items[line.itemId];
      if (item == null) {
        return const Failure<ValidatedCashSale>(ValidationError('FR-M11-01'));
      }
      final StockQuantity? quantity = _quantityOf(line.quantity, item.unit);
      if (quantity == null) {
        return const Failure<ValidatedCashSale>(ValidationError('BR-M11-06'));
      }
      // ⑦ ★★★ **والسعر إلزاميٌّ** — `FR-M11-04` · `ERR_PRICE_004`:
      //    ⟵ **فالحمولة بلا سعرٍ تُرفَض هنا** ⛔ **ولا تُحفَظ «غير مسعَّرة».**
      final Money? unitPrice = line.unitPrice;
      if (unitPrice == null) {
        return const Failure<ValidatedCashSale>(ValidationError('FR-M11-04'));
      }
      inputs.add(
        CashSaleLineInput(
          itemId: line.itemId,
          itemName: item.name,
          unit: item.unit,
          quantity: quantity,
          unitPrice: unitPrice,
          // ★★★ **والمقيسُ يسبق المُرسَل** — [`DEBT-86`] · `ADR-0007` ⑤:
          //    ⟵ **فحركةُ الخروج تحمل مرجعَ جونيتها ولو لم تُرسِله الشاشة.**
          sackId: sackIds[line.itemId] ?? line.sackId,
          belowMinReason: line.belowMinReason,
        ),
      );
    }
    return validateCashSale(
      CashSaleInput(sourceId: sourceId, lines: inputs, notes: notes),
    );
  }

  /// ★ يترجم رفضَ طبقة النطاق إلى رمز الكتالوج.
  ///
  /// ★★ **و«السعر مفقود» له رمزُه المستقل** (`ERR_PRICE_004`) — ⛔ **ولا
  /// يُبتلَع في `invalidArgument` العام**: ⟵ **فالمستخدم يقرأ الحقل الذي
  /// عليه ملؤه** («البيع النقدي يتطلب إدخال سعر لكل نوع»).
  static CallableError _mapValidation(AppError error) => switch (error) {
        ValidationError(ruleCode: 'FR-M11-04') =>
          CallableError.cashPriceMissing,
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

  /// ★★★ **الحدود الدنيا المقروءة** — ⛔ **والغياب `null` لا صفر**.
  ///
  /// ⚠️⚠️ **والفرق قاطع** (`FR-M11-06`): ★ **`null` تعني «لا حدَّ مسجَّلاً»
  /// فيُسمح بالبيع بتنبيه** — ⛔ **وصفرٌ كان سيعني «حدٌّ قدره صفر»** ⟵ **فلا
  /// سعرَ يقع دونه أبداً**: ★ **والحارس يسقط بصمت.**
  static Map<String, Money?> _minimumsOf(
    Map<String, Map<String, Object?>?> storedPrices,
  ) =>
      <String, Money?>{
        for (final MapEntry<String, Map<String, Object?>?> entry
            in storedPrices.entries)
          if (readInt(entry.value?['minCashPrice']) case final int minimum)
            entry.key: Money(minimum),
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

  static Set<String> _storedItemKeys(Map<String, Object?> document) {
    final Object? lines = document['lines'];
    if (lines is! List<Object?>) return <String>{};
    return <String>{
      for (final Object? line in lines)
        if (line is Map<String, Object?>)
          if ((line['itemId'] ?? line['itemKey']) case final String key) key,
    };
  }

  static List<_LineRequest>? _readLines(CallableRequest call) {
    final Object? raw = call.data['lines'];
    if (raw is! List<Object?>) return null;
    final List<_LineRequest> lines = <_LineRequest>[];
    for (final Object? entry in raw) {
      if (entry is! Map<String, Object?>) return null;
      final Object? itemId = entry['itemId'];
      if (itemId is! String || itemId.trim().isEmpty) return null;
      final Object? rawQuantity = entry['quantity'];
      // ★ **الكمية تُقرأ عدداً عاماً** — ⟵ **ووحدةُ النوع المخزَّنة هي التي
      //   تقرر أتُبنى حبّاتٍ أم كيلوجرامات** ([_quantityOf]).
      final num? quantity = rawQuantity is num
          ? rawQuantity
          : (rawQuantity is String ? num.tryParse(rawQuantity) : null);
      if (quantity == null) return null;
      final int? unitPrice = readInt(entry['unitPrice']);
      final Object? sackId = entry['sackId'];
      final Object? reason = entry['belowMinReason'];
      lines.add(
        _LineRequest(
          itemId: itemId.trim(),
          quantity: quantity,
          // ⛔★★ **وسعرٌ لم يُقرأ عدداً صحيحاً يبقى غائباً فيُرفَض بـ
          //    `ERR_PRICE_004`** — ★ **ولا يُقرَّب ولا يُبتلَع** (`ADR-0015`).
          unitPrice: unitPrice == null ? null : Money(unitPrice),
          sackId: sackId is String && sackId.trim().isNotEmpty
              ? sackId.trim()
              : null,
          belowMinReason: reason is String ? reason : null,
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

/// سطرٌ كما وصل في الحمولة — ⛔ **بلا اسمٍ ولا وحدة**: كلاهما من القاعدة.
final class _LineRequest {
  const _LineRequest({
    required this.itemId,
    required this.quantity,
    required this.unitPrice,
    required this.sackId,
    required this.belowMinReason,
  });

  final String itemId;
  final num quantity;
  final Money? unitPrice;
  final String? sackId;
  final String? belowMinReason;
}

/// ★ انقلاب اليوم بين اقتراح الحاوية وحكم المنصّة — راجع ترويسة الملف.
final class _DayMismatch {
  const _DayMismatch(this.observed);

  /// اليوم كما أعلنته المنصّة.
  final CalendarDay observed;
}

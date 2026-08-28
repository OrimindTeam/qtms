/// تنفيذ عمليات التوزيع — **الطرف الذي يلمس الشبكة** (`WU-006`).
///
/// ★ **مفصول عن `distribution.dart` عمداً**، بنفس منطق `inventory_handler.dart`:
/// كل قرار تفويض وقاعدة عمل هناك في **دوال خالصة تُختبَر بلا سحابة**؛
/// وهنا **الترتيب والقراءة والالتزام** وحدها.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ★★★ **يوم المخزون هنا يوم المنصّة — بنفس آلية `inventory_handler.dart`**
///
/// `FR-M10-03`: «**تاريخ المخزون غير قابل للتغيير يدوياً إطلاقاً … والنظام
/// هو من يحدده لا المستخدم**» (`A-10` · `GR-14`). ⟵ ★ **والحاوية تقترح
/// والمنصّة تحكم**: يُقترَح اليوم، وتُبنى القراءات به، **ويصل زمن المنصّة مع
/// نتيجة الاستعلام** (`readTime`)، ⛔ **وإن اختلف أُعيدت المحاولة مرة واحدة
/// باليوم الذي أعلنته المنصّة.**
///
/// ⚠️⚠️ **وهنا يزيد الأمر خطورةً عن `WU-003`:** ★ **اليوم يدخل المعرّف
/// المركّب نفسه** `{dealerId}_{sourceId}_{stockDate}` — ⟵ **فيومٌ خاطئ لا
/// يُنتج تاريخاً خاطئاً فحسب، بل ضماراً ثانياً لنفس المقوت في اليوم نفسه**،
/// ⛔ **وهو بالضبط ما وُجد `GR-18` ليمنعه.**
///
/// ⚠️ **والتصريف المتأخر خارج نطاق هذه الزيادة** — `FR-M10-03` يذكر «تاريخ
/// اليوم الأصلي **عند الدخول من شاشة المتبقي المتأخر**»، ★ **وتلك `WU-019`**
/// بمفتاحها `agedRemainderClear` — ⛔ **ولا مسار له هنا اليوم**، ⟵ **فلا
/// تاريخ يُقبَل من الجهاز إطلاقاً في هذه الزيادة.**
/// ═══════════════════════════════════════════════════════════════════════
library;

import 'package:qtms_domain/qtms_domain.dart';
import 'package:shelf/shelf.dart';

import 'audited_transaction.dart';
import 'callable.dart';
import 'counter_allocator.dart' show counterValueField;
import 'distribution.dart';
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
import 'permission_sync_handler.dart' show requestIdField;

/// اسم حقل سبب التعديل أو الإلغاء في الحمولة.
const String distributionReasonField = 'reason';

/// مفتاح استعلام قيود دفتر المقوت داخل المعاملة.
const String dealerLedgerQueryKey = 'dealerLedger';

/// ★ حدّ قراءة قيود المقوت في مصدرٍ واحد.
///
/// ⚠️ **ولماذا حدٌّ أصلاً:** رصيد المقوت يُجمَع من الدفتر داخل المعاملة
/// (`ADR-0008`)، ⟵ **والقيود تنمو مع عمر الحساب لا مع نشاط اليوم** —
/// ★ **بخلاف دفتر المخزون.** ⛔ **وتجاوزُه لا يُبتلَع:** رصيدٌ مجموعٌ من
/// مجموعةٍ مبتورة **رقمٌ كاذب يُطالَب به مقوت**، ★ **فيُرفَض الطلب صراحةً.**
///
/// ⚠️⚠️ **وهذا حدٌّ معلَن لا مطويّ** (`DEBT`): ★ **حسابٌ يتجاوز 500 قيدٍ في
/// مصدرٍ واحد سيتوقف عن قبول التوزيع** — ⟵ **والعلاج رصيدٌ متدرّج مُرحَّل
/// لا رفعُ الحد**، ⛔ **ولا يُخمَّن حلُّه في هذه الزيادة.**
const int dealerLedgerLimit = 500;

/// منفّذ عمليات التوزيع.
final class DistributionHandler {
  /// ينشئ المنفّذ بتبعياته — ★ **تُحقَن، فيُختبَر بلا سحابة**.
  const DistributionHandler({
    required IdentityGateway identity,
    required AuditedTransaction transaction,
    DateTime Function()? clock,
  })  : _identity = identity,
        _transaction = transaction,
        _clock = clock;

  final IdentityGateway _identity;
  final AuditedTransaction _transaction;

  /// ★ ساعةُ **الاقتراح** وحدها — ⛔ **ولا تُكتب قيمتها في أي حقل** بلا
  /// موافقة المنصّة (راجع ترويسة الملف). تُحقَن في الاختبار.
  final DateTime Function()? _clock;

  DateTime _now() => (_clock ?? DateTime.now)().toUtc();

  /// ينفّذ [operation] على طلب HTTP خام.
  Future<Response> handle(
    Request httpRequest,
    DistributionOperation operation,
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
    DistributionOperation operation,
  ) async {
    final AccountRecord actor = await _identity.verifyIdToken(call.idToken);
    final String? requestId = call.readString(requestIdField);
    final String? sourceId = call.readString('sourceId');
    final String? dealerId = call.readString('dealerId');
    if (requestId == null || sourceId == null || dealerId == null) {
      return callableFailure(CallableError.invalidArgument);
    }

    // ① البوابة — ⛔ قبل أي معاملة: الصلاحية **والنطاق** معاً.
    final DistributionRejected? gate = distributionGate(
      DistributionRequest(
        actor: actor,
        requestId: requestId,
        sourceId: sourceId,
        dealerId: dealerId,
        documentNumber: _pendingDocumentNumber,
        stockDate: CalendarDay.fromUtc(_now()),
      ),
      operation,
    );
    if (gate != null) return callableFailure(gate.error);

    return operation.isCreate
        ? _create(call, actor, requestId, sourceId, dealerId)
        : _amendOrCancel(call, actor, requestId, sourceId, dealerId, operation);
  }

  // ═════════════════════════════════════════════════════════════════════
  // الإنشاء — ★ **واليوم من المنصّة** (راجع ترويسة الملف)
  // ═════════════════════════════════════════════════════════════════════

  Future<Response> _create(
    CallableRequest call,
    AccountRecord actor,
    String requestId,
    String sourceId,
    String dealerId,
  ) async {
    final List<_LineRequest>? lines = _readLines(call);
    if (lines == null || lines.isEmpty) {
      return callableFailure(CallableError.invalidArgument);
    }

    CalendarDay day = CalendarDay.fromUtc(_now());
    String? number;
    String? id;
    // ★ **محاولتان لا أكثر** — ⟵ **فانقلابُ منتصف الليل يُصحَّح مرة واحدة.**
    for (int attempt = 0; attempt < 2; attempt++) {
      final _DayMismatch? drift = await _runCreate(
        call: call,
        actor: actor,
        requestId: requestId,
        sourceId: sourceId,
        dealerId: dealerId,
        lines: lines,
        day: day,
        onAllocated: (String allocated, String compositeId) {
          number = allocated;
          id = compositeId;
        },
      );
      if (drift == null) {
        return callableSuccess(<String, Object?>{
          'documentNumber': number,
          'distributionId': id,
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
    required String dealerId,
    required List<_LineRequest> lines,
    required CalendarDay day,
    required void Function(String, String) onAllocated,
  }) async {
    final String compositeId = distributionId(
      dealerId: dealerId,
      sourceId: sourceId,
      stockDate: day,
    );
    final String sourcePath =
        _transaction.documentPath(sourcesCollection, sourceId);
    final String dealerPath =
        _transaction.documentPath(dealersCollection, dealerId);
    final String documentPath =
        _transaction.documentPath(distributionsCollection, compositeId);
    final String counterPath = _transaction.documentPath(
      documentCountersCollection,
      documentCounterId(kind: DocumentKind.distribution, day: day),
    );
    final Map<String, String> itemPaths = <String, String>{
      for (final _LineRequest line in lines)
        line.itemId: _transaction.documentPath(itemsCollection, line.itemId),
    };
    // ★★★ **سجلّا الفائض** — `FR-M12-11`: **العامُّ وفائضُ هذا المصدر**.
    //    ⛔ **ولا سجلَّ مصدرٍ آخر يُقرأ** (`E-13`) — ★ **والمفتاح يمنعه أصلاً.**
    final Map<String, SurplusScope> surplusPaths = <String, SurplusScope>{
      _transaction.documentPath(
        dealerSurplusCollection,
        dealerSurplusId(dealerId: dealerId, scope: SurplusScope.general),
      ): SurplusScope.general,
      _transaction.documentPath(
        dealerSurplusCollection,
        dealerSurplusId(
          dealerId: dealerId,
          scope: SurplusScope.source,
          sourceId: sourceId,
        ),
      ): SurplusScope.source,
    };

    _DayMismatch? drift;
    await _transaction.run<void>(
      readPaths: <String>[
        sourcePath,
        dealerPath,
        documentPath,
        counterPath,
        ...itemPaths.values,
        ...surplusPaths.keys,
      ],
      queries: <DocumentQuery>[
        for (final _LineRequest line in lines)
          inventoryLedgerQuery(
            sourceId: sourceId,
            itemKey: line.itemId,
            day: day,
          ),
        _dealerLedgerQuery(dealerId: dealerId, sourceId: sourceId),
      ],
      plan: (TransactionReads reads) {
        // ③ ★★★ **يوم المنصّة هو الحَكَم** — راجع ترويسة الملف.
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
          kind: DocumentKind.distribution,
          day: day,
          sequence: sequence,
        );
        onAllocated(number, compositeId);

        // ★★★ **والمفتاح المركّب نوعٌ لا سجل له** — راجع [withLedgerItems]:
        //    ⛔ **بلا هذا لا يُوزَّع سطرُ جونيةٍ إطلاقاً** — ★ **وهي مقايسةُ
        //    `DEBT-55` نفسُها في هذا المسار** (`FR-M10-13`).
        final Map<String, ItemRead> items = withLedgerItems(
          readItemRecords(reads, itemPaths),
          reads: reads,
          itemKeys: itemPaths.keys,
          sourceId: sourceId,
        );
        final Outcome<ValidatedDistribution> validated = _validate(
          sourceId: sourceId,
          dealerId: dealerId,
          lines: lines,
          items: items,
          notes: call.readString('notes'),
        );
        if (validated is Failure<ValidatedDistribution>) {
          throw const AbortTransaction(CallableError.invalidArgument);
        }

        final DistributionPlan plan = planDistribution(
          DistributionRequest(
            actor: actor,
            requestId: requestId,
            sourceId: sourceId,
            dealerId: dealerId,
            documentNumber: number,
            stockDate: day,
            distribution: (validated as Success<ValidatedDistribution>).value,
            storedSource: reads.document(sourcePath),
            storedDealer: reads.document(dealerPath),
            storedDocument: reads.document(documentPath),
            items: items,
            ledger: _ledgerOf(
              reads,
              lines.map((_LineRequest l) => l.itemId),
              items,
            ),
            dealerLedger: _dealerLedgerOf(reads),
            surplusPools: _surplusPoolsOf(reads, surplusPaths),
          ),
          DistributionOperation.createDistribution,
        );
        if (plan case DistributionRejected(:final CallableError error)) {
          throw AbortTransaction(error);
        }

        final DistributionAccepted accepted = plan as DistributionAccepted;
        return AuditedWrite<void>(
          documents: <PendingDocument>[
            for (final InventoryWrite write in accepted.writes)
              _toPending(write),
            // ⛅ **العدّاد يُستهلَك في الالتزام نفسه** — ⟵ **فلا رقمٌ
            //    يُخصَّص ثم تفشل الكتابة فتبقى فجوة.**
            PendingDocument(
              collectionId: documentCountersCollection,
              documentId:
                  documentCounterId(kind: DocumentKind.distribution, day: day),
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
  // التعديل والإلغاء — ★ **واليوم محفورٌ في رقم المستند**
  // ═════════════════════════════════════════════════════════════════════

  Future<Response> _amendOrCancel(
    CallableRequest call,
    AccountRecord actor,
    String requestId,
    String sourceId,
    String dealerId,
    DistributionOperation operation,
  ) async {
    final String? number = call.readString('documentNumber');
    if (number == null) return callableFailure(CallableError.invalidArgument);
    // ★★ **اليوم من الرقم لا من الجهاز ولا من الساعة** — ★ **ويُقابَل
    //   بـ`stockDate` المخزَّن داخل المعاملة** (`_existenceGate`).
    final CalendarDay? day = parseDocumentNumberDay(number);
    if (day == null) return callableFailure(CallableError.invalidArgument);

    // ⛔⛔★★★ **ولا فحصَ لغياب السبب** — `ADR-0020` (2026-08-27):
    //    ★ **اختياريٌّ في كل عملية**، ⟵ **ويُمرَّر كما ورد أو غائباً.**
    final String? reason = call.readString(distributionReasonField);

    final List<_LineRequest> lines = operation.isCancel
        ? const <_LineRequest>[]
        : (_readLines(call) ?? const <_LineRequest>[]);
    if (!operation.isCancel && lines.isEmpty) {
      return callableFailure(CallableError.invalidArgument);
    }

    final String compositeId = distributionId(
      dealerId: dealerId,
      sourceId: sourceId,
      stockDate: day,
    );
    final String documentPath =
        _transaction.documentPath(distributionsCollection, compositeId);
    final String pricingPath = _transaction.documentPath(
      _pricingCollection(compositeId),
      distributionPricingDocumentId,
    );
    final String sourcePath =
        _transaction.documentPath(sourcesCollection, sourceId);
    final String dealerPath =
        _transaction.documentPath(dealersCollection, dealerId);

    // ★ **قراءةٌ تمهيدية للمستند** — ⟵ **لمعرفة أنواعه القائمة** التي يجب
    //   أن تُقرأ حركاتُها ولو حُذفت من التعديل. ⛔ **وليست مصدرَ قرار**:
    //   المعاملة تُعيد قراءة المستند وتحكم به (`_existenceGate`).
    final Map<String, Object?>? preview = await _transaction.readDocument(
      collectionId: distributionsCollection,
      documentId: compositeId,
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

    await _transaction.run<void>(
      readPaths: <String>[
        documentPath,
        pricingPath,
        sourcePath,
        dealerPath,
        ...itemPaths.values,
      ],
      queries: <DocumentQuery>[
        for (final String itemId in itemIds)
          inventoryLedgerQuery(sourceId: sourceId, itemKey: itemId, day: day),
        _dealerLedgerQuery(dealerId: dealerId, sourceId: sourceId),
      ],
      plan: (TransactionReads reads) {
        // ★★★ **والمفتاح المركّب نوعٌ لا سجل له** — راجع [withLedgerItems]:
        //    ⛔ **بلا هذا لا يُوزَّع سطرُ جونيةٍ إطلاقاً** — ★ **وهي مقايسةُ
        //    `DEBT-55` نفسُها في هذا المسار** (`FR-M10-13`).
        final Map<String, ItemRead> items = withLedgerItems(
          readItemRecords(reads, itemPaths),
          reads: reads,
          itemKeys: itemPaths.keys,
          sourceId: sourceId,
        );
        final Map<String, Object?>? stored = reads.document(documentPath);
        final Map<String, Object?>? pricing = reads.document(pricingPath);

        ValidatedDistribution? distribution;
        if (!operation.isCancel) {
          final Outcome<ValidatedDistribution> validated = _validate(
            sourceId: sourceId,
            dealerId: dealerId,
            lines: lines,
            items: items,
            notes: call.readString('notes'),
          );
          if (validated is Failure<ValidatedDistribution>) {
            throw const AbortTransaction(CallableError.invalidArgument);
          }
          distribution = (validated as Success<ValidatedDistribution>).value;
        }

        final DistributionPlan plan = planDistribution(
          DistributionRequest(
            actor: actor,
            requestId: requestId,
            sourceId: sourceId,
            dealerId: dealerId,
            documentNumber: number,
            stockDate: day,
            distribution: distribution,
            storedSource: reads.document(sourcePath),
            storedDealer: reads.document(dealerPath),
            storedDocument: stored,
            storedUnitPrices: _storedPricesOf(stored, pricing),
            hasStoredPricing: pricing != null,
            storedSettlement: readStoredSettlement(stored, pricing),
            items: items,
            ledger: _ledgerOf(reads, itemIds, items),
            dealerLedger: _dealerLedgerOf(reads),
            reason: reason,
          ),
          operation,
        );
        if (plan case DistributionRejected(:final CallableError error)) {
          throw AbortTransaction(error);
        }

        final DistributionAccepted accepted = plan as DistributionAccepted;
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

    return callableSuccess(<String, Object?>{
      'documentNumber': number,
      'distributionId': compositeId,
      'stockDate': day.format(),
    });
  }

  // ═════════════════════════════════════════════════════════════════════
  // قراءة الحمولة والمخزَّن
  // ═════════════════════════════════════════════════════════════════════

  /// ★ **يبني المستند من سجلات الأنواع لا من الحمولة** — ⟵ **فاسمُ النوع
  /// ووحدتُه من القاعدة**، ⛔ **ولا يُرسل العميل وحدةً فيُنشئ حركةً بوحدةٍ
  /// ليست وحدة النوع** (`FR-M5-03` · `GR-19`).
  ///
  /// ⚠️⚠️ **والكمية تُبنى بوحدة النوع المخزَّنة:** ⟵ **فسطرٌ لنوعٍ وزنيٍّ
  /// يُبنى [WeightQuantity] ولو أرسله العميل عدداً صحيحاً**، ★ **والعكس
  /// يُرفَض في طبقة النطاق** لأن الكسر ليس كميةً معدودة (`BR-M6-06`).
  static Outcome<ValidatedDistribution> _validate({
    required String sourceId,
    required String dealerId,
    required List<_LineRequest> lines,
    required Map<String, ItemRead> items,
    required String? notes,
  }) {
    final List<DistributionLineInput> inputs = <DistributionLineInput>[];
    for (final _LineRequest line in lines) {
      final ItemRead? item = items[line.itemId];
      if (item == null) {
        return const Failure<ValidatedDistribution>(
          ValidationError('FR-M10-13'),
        );
      }
      final StockQuantity? quantity = _quantityOf(line.quantity, item.unit);
      if (quantity == null) {
        return const Failure<ValidatedDistribution>(
          ValidationError('BR-M10-10'),
        );
      }
      inputs.add(
        DistributionLineInput(
          itemId: line.itemId,
          itemName: item.name,
          unit: item.unit,
          quantity: quantity,
          sackId: line.sackId,
          unitPrice: line.unitPrice,
          note: line.note,
        ),
      );
    }
    return validateDistribution(
      DistributionInput(
        sourceId: sourceId,
        dealerId: dealerId,
        notes: notes,
        lines: inputs,
      ),
    );
  }

  /// ★ الكمية بوحدة النوع — و`null` لمُدخَلٍ لا يصلح لتلك الوحدة.
  ///
  /// ⛔★★ **والكسر يُرفَض للنوع المعدود** — `BR-M6-06` · `ERR_STOCK_002`:
  /// «**الكسور مسموحة في الأنواع الوزنية فقط**».
  static StockQuantity? _quantityOf(num raw, ItemUnit unit) => switch (unit) {
        ItemUnit.piece => raw == raw.roundToDouble()
            ? PieceQuantity(PieceCount(raw.toInt()))
            : null,
        ItemUnit.kilogram => WeightQuantity(WeightKg(raw.toDouble())),
      };

  /// ★★★ **سجلات الفائض المقروءة** — `FR-M12-11` · `settlement-design.md` §4.
  ///
  /// ⛔★★ **والسجلُّ الغائب ليس صفراً مكتوباً** — ★ **بل لا سجلَّ أصلاً**:
  /// ⟵ **فيُتخطّى** (`ADR-0008` القاعدة 5)، ⛔ **ولا يُبنى عليه تطبيق.**
  ///
  /// ⚠️ **و`availableAmount` هو الحقل الموثَّق** (`data-dictionary.md` §4:
  /// «**الفائض المتاح · تاريخ آخر إدخال**») — ⛔ **ولا يُجمَع من مدفوعٍ
  /// ومُطبَّقٍ هنا**: ★ **السجل مشتقٌّ كـ`dealer_balances` تماماً.**
  static List<SurplusPoolRead> _surplusPoolsOf(
    TransactionReads reads,
    Map<String, SurplusScope> paths,
  ) {
    final List<SurplusPoolRead> pools = <SurplusPoolRead>[];
    for (final MapEntry<String, SurplusScope> entry in paths.entries) {
      final Map<String, Object?>? stored = reads.document(entry.key);
      if (stored == null) continue;
      final int available = readInt(stored['availableAmount']) ?? 0;
      if (available <= 0) continue;
      final Object? paidOn = stored['lastPaidOn'];
      pools.add(
        SurplusPoolRead(
          // ★ **ومعرّفُ السجل آخرُ مقطعٍ في مساره** — ⟵ **وهو ما يُكتب به.**
          surplusId: entry.key.split('/').last,
          scope: entry.value,
          paidOn: paidOn is DateTime
              ? CalendarDay.fromUtc(paidOn.toUtc())
              // ⛔★★ **وتاريخٌ غائب لا يُسقِط السجل** — ★ **يدخل البيان
              //    الآلي بيومٍ محايد**: ⟵ **وحجبُ فائضٍ مستحقٍّ لأن حقلَ
              //    عرضٍ غاب أسوأ من بيانٍ ناقص.**
              : CalendarDay(1970, 1, 1),
          available: Money(available),
        ),
      );
    }
    return pools;
  }

  static DocumentQuery _dealerLedgerQuery({
    required String dealerId,
    required String sourceId,
  }) =>
      DocumentQuery(
        key: dealerLedgerQueryKey,
        collectionId: dealerLedgerCollection,
        fieldPath: 'dealerId',
        equalTo: dealerId,
        // ⛔★★ **ومصدرٌ واحد لا أكثر** (`GR-20`) — ★ **والفهرس القائم
        //    `dealerId ↑ · sourceId ↑ · entryDate ↓`** يغطّي المساواتين.
        andEquals: <String, Object?>{'sourceId': sourceId},
        limit: dealerLedgerLimit,
      );

  /// ★★ قيود المقوت المقروءة — ⛔ **والمجموعة المبتورة رفضٌ لا جمعٌ ناقص**.
  static List<DealerLedgerRead> _dealerLedgerOf(TransactionReads reads) {
    final List<String> ids = reads.matches(dealerLedgerQueryKey);
    final List<Map<String, Object?>> documents =
        reads.matchedDocuments(dealerLedgerQueryKey);
    if (ids.length >= dealerLedgerLimit) {
      // ⛔★★ **بترٌ ⟵ رصيدٌ كاذب** — ★ **ويُرفَض صراحةً** (راجع
      //    [dealerLedgerLimit]).
      throw const AbortTransaction(CallableError.internal);
    }
    return <DealerLedgerRead>[
      for (int i = 0; i < ids.length; i++)
        DealerLedgerRead(
          entryId: ids[i],
          entry: DealerLedgerEntry(
            direction: documents[i]['direction'] ==
                    DealerLedgerDirection.credit.name
                ? DealerLedgerDirection.credit
                : DealerLedgerDirection.debit,
            amount: Money(readInt(documents[i]['amount']) ?? 0),
            // ⛔ **الملغاة صراحةً وحدها ملغاة** — ★ **والافتراض الآمن هنا
            //    «قيدٌ حيّ»**: ⟵ **قراءةُ قيدٍ حيّ ملغىً تُخفي ديناً قائماً.**
            isCancelled: documents[i]['isCancelled'] == true,
          ),
        ),
    ];
  }

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

  /// 🔒 **الأسعار المخزَّنة بمفتاح نوعها** — ⛔ **مقروءةً بمحاذاة السطور**.
  ///
  /// ⚠️⚠️ **والمحاذاة بالفهرس هي العقد نفسه** (`data-dictionary.md`:
  /// «**موازية لترتيب `lines[]` في الأب**») — ⟵ **فطولٌ مختلف يعني مستنداً
  /// غير متسق**، ★ **وتُقرأ الأزواج المتقابلة وحدها** ⛔ **ولا يُنسَب سعرٌ
  /// لنوعٍ بالتخمين.**
  static Map<String, Money?> _storedPricesOf(
    Map<String, Object?>? stored,
    Map<String, Object?>? pricing,
  ) {
    if (stored == null || pricing == null) return const <String, Money?>{};
    final Object? lines = stored['lines'];
    final Object? prices = pricing['unitPrices'];
    if (lines is! List<Object?> || prices is! List<Object?>) {
      return const <String, Money?>{};
    }
    final Map<String, Money?> byItem = <String, Money?>{};
    for (int i = 0; i < lines.length && i < prices.length; i++) {
      final Object? line = lines[i];
      if (line is! Map<String, Object?>) continue;
      final Object? key = line['itemId'] ?? line['itemKey'];
      if (key is! String || key.isEmpty) continue;
      final int? price = readInt(prices[i]);
      byItem[key] = price == null ? null : Money(price);
    }
    return byItem;
  }

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
      final Object? price = entry['unitPrice'];
      final int? unitPrice = readInt(price);
      // ⛔★★ **وسعرٌ أُرسل ولم يُقرأ عدداً صحيحاً رفضٌ لا تجاهل** —
      //    `ADR-0015` القاعدة 1: **كل مبلغ `int`**، ⟵ **وتجاهلُه كان
      //    سيحفظ السطر «غير مسعَّر» بينما المستخدم يظنّه مسعَّراً.**
      if (price != null && unitPrice == null) return null;
      final Object? sackId = entry['sackId'];
      final Object? note = entry['note'];
      lines.add(
        _LineRequest(
          itemId: itemId.trim(),
          quantity: quantity,
          unitPrice: unitPrice == null ? null : Money(unitPrice),
          sackId: sackId is String && sackId.trim().isNotEmpty
              ? sackId.trim()
              : null,
          note: note is String ? note : null,
        ),
      );
    }
    return lines;
  }

  static String _pricingCollection(String compositeId) =>
      '$distributionsCollection/$compositeId/$distributionPricingSubcollection';

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
/// ═══════════════════════════════════════════════════════════════════════
/// ★★ **تسوية الضمار المخزَّنة** — ⛔ **والغياب «لم يُمَسّ» لا صفراً محسوباً**.
///
/// ⛔⛔★★★ **والمبالغُ الثلاثة تُقرأ من `pricing/current` لا من الأب**
/// (`IQ-027` · **الخيار أ** · 2026-08-28): **المتبقي + المسدَّد + المخصوم
/// = `debtValue`** — ⟵ **فبقاؤها في الأب كان يكشف قيمة الضمار لمن لا يملك
/// `distributionPriceView`**، ★ **وهو عينُ ما نُقل `debtValue` من أجله**
/// ([`ADR-0011`]). ★ **و`settlementStatus` وحده يبقى في الأب** — **حالةٌ لا
/// رقم**، ⟵ **والفهرس القائم عليه صالحٌ بلا تغيير.**
///
/// ⛔⛔★★ **ودالةٌ عليا لا خاصّةٌ داخل الصنف — عمداً:** ★ **هذه طبقةُ
/// المعالِج**، ⟵ **ودرسُ [`DEBT-37`] و[`DEBT-55`] أنها لم تكن مُختبَرةً قطّ**
/// بينما اختباراتُ التخطيط تُمرِّر [DebtSettlement] جاهزةً فلا ترى المصدر.
/// ═══════════════════════════════════════════════════════════════════════
DebtSettlement? readStoredSettlement(
  Map<String, Object?>? stored,
  Map<String, Object?>? pricing,
) {
  if (stored == null || pricing == null) return null;
  final int? settled = readInt(pricing['settledAmount']);
  final int? discounted = readInt(pricing['discountedAmount']);
  if (settled == null && discounted == null) return null;
  return computeDebtSettlement(
    debtValue: Money(readInt(pricing['debtValue']) ?? 0),
    settledAmount: Money(settled ?? 0),
    discountedAmount: Money(discounted ?? 0),
  );
}

final class _LineRequest {
  const _LineRequest({
    required this.itemId,
    required this.quantity,
    required this.unitPrice,
    required this.sackId,
    required this.note,
  });

  final String itemId;
  final num quantity;
  final Money? unitPrice;
  final String? sackId;
  final String? note;
}

/// ★ انقلاب اليوم بين اقتراح الحاوية وحكم المنصّة — راجع ترويسة الملف.
final class _DayMismatch {
  const _DayMismatch(this.observed);

  /// اليوم كما أعلنته المنصّة.
  final CalendarDay observed;
}

/// تنفيذ عمليات القبض — **الطرف الذي يلمس الشبكة** (`WU-007`).
///
/// ★ **مفصول عن `receipt.dart` عمداً**، بنفس منطق `distribution_handler.dart`:
/// كل قرار تفويض وقاعدة عمل هناك في **دوال خالصة تُختبَر بلا سحابة**؛
/// وهنا **الترتيب والقراءة والالتزام** وحدها.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ★★★ **وتاريخ السند هنا ليس يوم المنصّة — بخلاف التوزيع تماماً**
///
/// `FR-M10-03` يجعل **تاريخ المخزون** غير قابل للتغيير يدوياً إطلاقاً؛
/// ⛔ **و`FR-M12-02` يقول عكسه للقبض حرفياً**: «**التاريخ الافتراضي اليوم،
/// ويقبل تاريخاً سابقاً بصلاحية «قبض بتاريخ سابق»، ولا يقبل تاريخاً
/// مستقبلياً أبداً**» (`E-14`). ⟵ ★ **فالتاريخ يصل من الجهاز هنا**،
/// **ويُقابَل بيوم المنصّة داخل المعاملة** ([validateReceiptDate]):
/// ⛔ **والمستقبلي يُرفَض قطعاً**، ★ **والسابق بمفتاحه.**
///
/// ⚠️⚠️ **ولا يُقاس هذا على `WU-006`:** ★ **الفرق أن ذاك «تاريخ مخزون» يدخل
/// معرّفاً مركّباً ويحكم رصيد يوم**، ⛔ **وهذا «تاريخ صندوق»**: ⟵ **ما دخل
/// الصندوق فعلاً في ذلك التاريخ** (`GR-41` · `FR-M12-20`).
///
/// ★★ **ورقمُ المستند يُخصَّص بيوم المنصّة لا بتاريخ السند** — ⟵ **فالعدّاد
/// اليومي عدّادُ إدخالٍ لا عدّادُ ذمة**، ⛔ **وخلطُهما كان يُنتج رقمين
/// متطابقين لسندين أُدخِلا اليوم بتاريخين سابقين مختلفين.**
/// ═══════════════════════════════════════════════════════════════════════
library;

import 'package:qtms_domain/qtms_domain.dart';
import 'package:shelf/shelf.dart';

import 'audited_transaction.dart';
import 'callable.dart';
import 'counter_allocator.dart' show counterValueField;
import 'distribution_handler.dart' show readStoredSettlement;
import 'identity_gateway.dart';
import 'inventory.dart';
import 'inventory_handler.dart' show platformDayOf, readInt;
import 'permission_sync_handler.dart' show requestIdField;
import 'receipt.dart';

/// اسم حقل سبب التعديل أو الإلغاء في الحمولة.
const String receiptReasonField = 'reason';

/// مفتاح استعلام قيود دفتر المقوت داخل المعاملة.
const String receiptDealerLedgerQueryKey = 'receiptDealerLedger';

/// ★ حدّ قراءة قيود المقوت — ⛔ **وتجاوزُه رفضٌ لا جمعٌ ناقص**.
///
/// ⚠️⚠️ **وهو أوسع من نظيره في التوزيع عمداً** (`dealerLedgerLimit` = 500):
/// ★ **ذاك يقرأ مصدراً واحداً**، ⛔ **وهذا يقرأ كل مصادر المقوت** لأن سند
/// «الكل» يمسّها معاً (`FR-M12-04`) — ⟵ **فالحدّ نفسُه كان سيبتر حساباً
/// موزَّعاً على ثلاثة مصادر عند ثُلث عمره.**
///
/// ⚠️ **وهو حدٌّ معلَن لا مطويّ** — ★ **والعلاج رصيدٌ متدرّج مُرحَّل**
/// ⛔ **لا رفعُ الرقم**، ★ **ويُسجَّل ديناً تقنياً مع `DEBT-42` نفسِه.**
const int receiptDealerLedgerLimit = 1500;

/// منفّذ عمليات القبض.
final class ReceiptHandler {
  /// ينشئ المنفّذ بتبعياته — ★ **تُحقَن، فيُختبَر بلا سحابة**.
  const ReceiptHandler({
    required IdentityGateway identity,
    required AuditedTransaction transaction,
    DateTime Function()? clock,
  })  : _identity = identity,
        _transaction = transaction,
        _clock = clock;

  final IdentityGateway _identity;
  final AuditedTransaction _transaction;

  /// ★ ساعةُ **الاقتراح** وحدها — ⛔ **ولا تُكتب قيمتها في أي حقل** بلا
  /// موافقة المنصّة. تُحقَن في الاختبار.
  final DateTime Function()? _clock;

  DateTime _now() => (_clock ?? DateTime.now)().toUtc();

  /// ينفّذ [operation] على طلب HTTP خام.
  Future<Response> handle(
    Request httpRequest,
    ReceiptOperation operation,
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
    ReceiptOperation operation,
  ) async {
    final AccountRecord actor = await _identity.verifyIdToken(call.idToken);
    final String? requestId = call.readString(requestIdField);
    final String? dealerId = call.readString('dealerId');
    if (requestId == null || dealerId == null) {
      return callableFailure(CallableError.invalidArgument);
    }

    // ① البوابة — ⛔ قبل أي معاملة: الحالة والصلاحية.
    //   ⚠️ **والنطاق ليس هنا** — ★ **لأن المصادر المتأثرة تُقرأ من الضمارات
    //   داخل المعاملة** ([planReceipt] يفحصها على المقروء فعلاً).
    final ReceiptRejected? gate = receiptGate(
      ReceiptRequest(
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

    if (operation.isDeposit) {
      return _confirmDeposit(call, actor, requestId, dealerId);
    }
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
    final _ReceiptPayload? payload = _readPayload(call);
    if (payload == null) return callableFailure(CallableError.invalidArgument);

    CalendarDay day = CalendarDay.fromUtc(_now());
    String? number;
    for (int attempt = 0; attempt < 2; attempt++) {
      final _DayMismatch? drift = await _runCreate(
        actor: actor,
        requestId: requestId,
        dealerId: dealerId,
        payload: payload,
        day: day,
        onAllocated: (String allocated) => number = allocated,
      );
      if (drift == null) {
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
    required _ReceiptPayload payload,
    required CalendarDay day,
    required void Function(String) onAllocated,
  }) async {
    final String dealerPath =
        _transaction.documentPath(dealersCollection, dealerId);
    final String counterPath = _transaction.documentPath(
      documentCountersCollection,
      documentCounterId(kind: DocumentKind.receipt, day: day),
    );
    final Map<String, _LotPaths> lotPaths = _lotPathsFor(payload.lotIds);
    final List<String> surplusPaths =
        _surplusPathsFor(dealerId, payload.sourceFilter);

    _DayMismatch? drift;
    await _transaction.run<void>(
      readPaths: <String>[
        dealerPath,
        counterPath,
        ...surplusPaths,
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
          kind: DocumentKind.receipt,
          day: day,
          sequence: sequence,
        );
        onAllocated(number);

        final ReceiptPlan plan = planReceipt(
          ReceiptRequest(
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
            surplusAmount: payload.surplusAmount,
            surplusScope: payload.surplusScope,
            usedAutoAllocation: payload.usedAutoAllocation,
            lots: _lotsOf(reads, lotPaths),
            storedDealer: reads.document(dealerPath),
            storedSurplus:
                _surplusOf(reads, surplusPaths, payload.surplusScope),
            dealerLedger: _dealerLedgerOf(reads),
            deviceInfo: payload.deviceInfo,
          ),
          ReceiptOperation.createReceipt,
        );
        if (plan case ReceiptRejected(:final CallableError error)) {
          throw AbortTransaction(error);
        }

        final ReceiptAccepted accepted = plan as ReceiptAccepted;
        return AuditedWrite<void>(
          documents: <PendingDocument>[
            for (final InventoryWrite write in accepted.writes)
              _toPending(write),
            // ⛅ **العدّاد يُستهلَك في الالتزام نفسه** — ⟵ **فلا رقمٌ
            //    يُخصَّص ثم تفشل الكتابة فتبقى فجوة.**
            PendingDocument(
              collectionId: documentCountersCollection,
              documentId:
                  documentCounterId(kind: DocumentKind.receipt, day: day),
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
    ReceiptOperation operation,
  ) async {
    final String? number = call.readString('documentNumber');
    if (number == null) return callableFailure(CallableError.invalidArgument);

    final _ReceiptPayload? payload =
        operation.isCancel ? null : _readPayload(call);
    if (!operation.isCancel && payload == null) {
      return callableFailure(CallableError.invalidArgument);
    }
    final String? reason = call.readString(receiptReasonField);

    // ★ **قراءةٌ تمهيدية للمستند** — ⟵ **لمعرفة ضماراته القائمة** التي يجب
    //   أن تُقرأ ولو حُذفت من التعديل. ⛔ **وليست مصدرَ قرار**: المعاملة
    //   تُعيد قراءة المستند وتحكم به.
    final Map<String, Object?>? preview = await _transaction.readDocument(
      collectionId: receiptsCollection,
      documentId: number,
    );
    if (preview == null) return callableFailure(CallableError.invalidArgument);

    final Set<String> lotIds = <String>{
      ...?payload?.lotIds,
      ..._storedLotIds(preview),
    };
    final Map<String, _LotPaths> lotPaths = _lotPathsFor(lotIds);
    final String documentPath =
        _transaction.documentPath(receiptsCollection, number);
    final String dealerPath =
        _transaction.documentPath(dealersCollection, dealerId);
    // ★ **وفلترُ المخزَّن يدخل مسارات الفائض** — ⟵ **فالإلغاء يسحب فائضاً
    //   قُيِّد بمصدرٍ محدد وقتَ الإنشاء** ⛔ **ولا حمولةَ له اليوم.**
    final List<String> surplusPaths = _surplusPathsFor(
      dealerId,
      payload?.sourceFilter ?? _storedFilter(preview),
    );

    await _transaction.run<void>(
      readPaths: <String>[
        documentPath,
        dealerPath,
        ...surplusPaths,
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

        final ReceiptPlan plan = planReceipt(
          ReceiptRequest(
            actor: actor,
            requestId: requestId,
            dealerId: dealerId,
            documentNumber: number,
            // ★ **تاريخ السند من الحمولة عند التعديل والمخزَّن عند الإلغاء**
            //   — ⛔ **ولا يُخترَع تاريخ للإلغاء.**
            date: payload?.date ?? _storedDate(stored) ?? observed,
            today: observed,
            sourceFilter: payload?.sourceFilter ?? _storedFilter(stored),
            lines: payload?.lines ?? const <ReceiptLineInput>[],
            surplusAmount: payload?.surplusAmount ?? Money.zero,
            surplusScope: payload?.surplusScope ?? SurplusScope.general,
            usedAutoAllocation: payload?.usedAutoAllocation ?? false,
            lots: _lotsOf(reads, lotPaths),
            storedDealer: reads.document(dealerPath),
            storedDocument: stored,
            storedSurplus: _surplusOf(
              reads,
              surplusPaths,
              payload?.surplusScope ??
                  (stored['surplusScope'] == SurplusScope.source.name
                      ? SurplusScope.source
                      : SurplusScope.general),
            ),
            dealerLedger: _dealerLedgerOf(reads),
            reason: reason,
            deviceInfo: payload?.deviceInfo,
          ),
          operation,
        );
        if (plan case ReceiptRejected(:final CallableError error)) {
          throw AbortTransaction(error);
        }

        final ReceiptAccepted accepted = plan as ReceiptAccepted;
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

    return callableSuccess(<String, Object?>{'documentNumber': number});
  }

  // ═════════════════════════════════════════════════════════════════════
  // ⑧ ★★ الإيداع البنكي — مسارٌ مقيَّد بحقوله وحدها (`FR-M12-18`)
  // ═════════════════════════════════════════════════════════════════════

  Future<Response> _confirmDeposit(
    CallableRequest call,
    AccountRecord actor,
    String requestId,
    String dealerId,
  ) async {
    final String? number = call.readString('documentNumber');
    if (number == null) return callableFailure(CallableError.invalidArgument);
    final String? note = call.readString('depositNote');
    final Object? rawDeposited = call.data['isDeposited'];
    if (rawDeposited is! bool) {
      return callableFailure(CallableError.invalidArgument);
    }

    final String documentPath =
        _transaction.documentPath(receiptsCollection, number);
    final String depositPath = _transaction.documentPath(
      '$receiptsCollection/$number/$receiptDepositSubcollection',
      receiptDepositDocumentId,
    );

    await _transaction.run<void>(
      readPaths: <String>[documentPath, depositPath],
      plan: (TransactionReads reads) {
        final CalendarDay? observed = platformDayOf(reads);
        if (observed == null) {
          throw const AbortTransaction(CallableError.internal);
        }
        final Map<String, Object?>? stored = reads.document(documentPath);
        if (stored == null) {
          throw const AbortTransaction(CallableError.invalidArgument);
        }

        final ReceiptPlan plan = planReceipt(
          ReceiptRequest(
            actor: actor,
            requestId: requestId,
            dealerId: dealerId,
            documentNumber: number,
            date: _storedDate(stored) ?? observed,
            today: observed,
            sourceFilter: _storedFilter(stored),
            storedDocument: stored,
            storedDeposit: reads.document(depositPath),
            depositNote: note,
            depositState: rawDeposited
                ? DepositState.deposited
                : DepositState.notDeposited,
            reason: call.readString(receiptReasonField),
          ),
          ReceiptOperation.confirmReceiptDeposit,
        );
        if (plan case ReceiptRejected(:final CallableError error)) {
          throw AbortTransaction(error);
        }

        final ReceiptAccepted accepted = plan as ReceiptAccepted;
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
      'isDeposited': rawDeposited,
    });
  }

  // ═════════════════════════════════════════════════════════════════════
  // القراءة
  // ═════════════════════════════════════════════════════════════════════

  /// ★★ **مسارا سجلَّي الفائض المحتملَين للمقوت** — **مصدرُه والعام**.
  ///
  /// ⛔⛔★★ **ومسارٌ معروفٌ مسبقاً لا استعلام** — ★ **لأن المفتاح مشتقٌّ**
  /// ([dealerSurplusId])، ⟵ **والقراءة داخل المعاملة تحتاج مساراً لا نتيجةَ
  /// بحث** ⛔ **واستعلامٌ هنا كان يفتح باب البتر** كما في دفتر المقوت.
  List<String> _surplusPathsFor(String dealerId, String? sourceFilter) =>
      <String>[
        _transaction.documentPath(
          dealerSurplusCollection,
          dealerSurplusId(dealerId: dealerId, scope: SurplusScope.general),
        ),
        if (sourceFilter != null && sourceFilter.isNotEmpty)
          _transaction.documentPath(
            dealerSurplusCollection,
            dealerSurplusId(
              dealerId: dealerId,
              scope: SurplusScope.source,
              sourceId: sourceFilter,
            ),
          ),
      ];

  /// ★ سجل الفائض المطابق لنطاق هذا السند — ⛔ **و`null` يعني «لا رصيد بعد».**
  static Map<String, Object?>? _surplusOf(
    TransactionReads reads,
    List<String> paths,
    SurplusScope scope,
  ) {
    // ★ **العامُّ أولُ المسارين دائماً** ([_surplusPathsFor]) — ⟵ **وسجلُّ
    //   المصدر ثانيها إن وُجد فلترٌ محدد.**
    if (scope == SurplusScope.general) return reads.document(paths.first);
    return paths.length > 1 ? reads.document(paths[1]) : null;
  }

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
  /// [readStoredSettlement] نفسِها التي يستعملها مسار التوزيع**:
  /// ⟵ **مصدرُ قراءةٍ واحد للمسارين** ⛔ **لا نسختان تفترقان عند أول تغيير.**
  ///
  /// ⚠️⚠️ **وضمارٌ بلا تسعير متبقّيه صفر لا «قيمتُه المجهولة»** — ★ **فسطرٌ
  /// عليه يُرفَض بـ`BR-M12-02`** ⟵ **وهو الصواب**: ⛔ **لا يُسدَّد ما لم
  /// يُسعَّر بعد** (`FR-M10-08`: **السطور غير المسعَّرة لا تدخل الرصيد**).
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
  /// ⚠️⚠️ **ولا يُقيَّد `sourceId` هنا بخلاف مسار التوزيع** — ★ **لأن سند
  /// «الكل» يمسّ مصادر عدة** (`FR-M12-04`)، ⟵ **والفهرس القائم
  /// `dealerId ↑ · sourceId ↑ · entryDate ↓` يغطّي المساواة الأولى وحدها
  /// كبادئة** ⛔ **فلا فهرسَ جديداً.** ★ **والتجميع بالمصدر بعد القراءة**
  /// ⛔ **لا يُجمَع رصيدٌ عابرٌ للمصادر** (`GR-20`).
  static List<ReceiptLedgerRead> _dealerLedgerOf(TransactionReads reads) {
    final List<String> ids = reads.matches(receiptDealerLedgerQueryKey);
    final List<Map<String, Object?>> documents =
        reads.matchedDocuments(receiptDealerLedgerQueryKey);
    if (ids.length >= receiptDealerLedgerLimit) {
      // ⛔★★ **بترٌ ⟵ رصيدٌ كاذب** — ★ **ويُرفَض صراحةً**.
      throw const AbortTransaction(CallableError.internal);
    }
    final List<ReceiptLedgerRead> entries = <ReceiptLedgerRead>[];
    for (int i = 0; i < ids.length; i++) {
      final Object? sourceId = documents[i]['sourceId'];
      // ⛔ **وقيدٌ بلا مصدر لا يدخل جمعاً** — ★ **فالرصيد رصيدُ مصدر**،
      //    ⟵ **وإسنادُه لمصدرٍ مُخمَّن كان يخلط دفترين.**
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
        key: receiptDealerLedgerQueryKey,
        collectionId: dealerLedgerCollection,
        fieldPath: 'dealerId',
        equalTo: dealerId,
        limit: receiptDealerLedgerLimit,
      );

  _ReceiptPayload? _readPayload(CallableRequest call) {
    final CalendarDay? date = _readDay(call.data['date']);
    if (date == null) return null;

    final Object? rawLines = call.data['lines'];
    if (rawLines is! List<Object?>) return null;
    final List<ReceiptLineInput> lines = <ReceiptLineInput>[];
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
        ReceiptLineInput(
          debtLotId: lotId.trim(),
          amount: Money(amount),
          note: note is String ? note : null,
        ),
      );
    }

    final Object? rawSurplus = call.data['surplusAmount'];
    final int surplus = rawSurplus == null ? 0 : (readInt(rawSurplus) ?? -1);
    if (surplus < 0) return null;

    final Object? rawScope = call.data['surplusScope'];
    final SurplusScope scope = rawScope == SurplusScope.source.name
        ? SurplusScope.source
        : SurplusScope.general;
    final String? sourceFilter = call.readString('sourceFilter');
    // ⛔⛔★★ **وفائضُ مصدرٍ بلا مصدرٍ محدد رفضٌ** — ⟵ **وإلا سقط إلى «عام»
    //    فسُدِّد لضمارات مصادرَ أخرى** (`E-13`)، ★ **والمفتاح نفسُه يرفضه.**
    if (scope == SurplusScope.source && surplus > 0 && sourceFilter == null) {
      return null;
    }

    return _ReceiptPayload(
      date: date,
      sourceFilter: sourceFilter,
      lines: lines,
      surplusAmount: Money(surplus),
      surplusScope: scope,
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

  /// ★★ **تاريخ السند على السلك — `YYYYMMDD` المُدمَج** (`CalendarDay.format`).
  ///
  /// ⛔⛔★★ **وهذا أولُ تاريخٍ يرسله الجهاز في هذا النظام** — ★ **وكل ما
  /// سبقه كان يوم منصّة** (`FR-M10-03`): ⟵ **فالصيغة قرارٌ تنفيذي روتيني
  /// اتُّخذ ذاتياً** (بروتوكول التشغيل §ب الفئة 3)، ★ **واختير المُدمَج لأنه
  /// **الصيغة القائمة فعلاً** في أرقام المستندات والمفاتيح المركّبة
  /// (`naming-conventions.md` §4 و§5)، **ولها قارئٌ مكتوبٌ ومُختبَر**
  /// ([CalendarDay.tryParseCompact]) — ⛔ **فلا صيغةَ ثانيةً تُخترَع للسلك.**
  ///
  /// ⛔★★ **ولا يُقبَل `DateTime` من الجهاز** — ★ **لأن اللحظة تحمل منطقةً
  /// وساعةً**، ⟵ **ويومُ الصندوق يومٌ تقويمي لا لحظة** (`ADR-0006`).
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
final class _ReceiptPayload {
  const _ReceiptPayload({
    required this.date,
    required this.sourceFilter,
    required this.lines,
    required this.surplusAmount,
    required this.surplusScope,
    required this.usedAutoAllocation,
    required this.deviceInfo,
  });

  final CalendarDay date;
  final String? sourceFilter;
  final List<ReceiptLineInput> lines;
  final Money surplusAmount;
  final SurplusScope surplusScope;
  final bool usedAutoAllocation;
  final String? deviceInfo;

  Set<String> get lotIds => <String>{
        for (final ReceiptLineInput line in lines) line.debtLotId,
      };
}

/// اختلاف يوم المنصّة عن اليوم المقترَح.
final class _DayMismatch {
  const _DayMismatch(this.observed);

  final CalendarDay observed;
}

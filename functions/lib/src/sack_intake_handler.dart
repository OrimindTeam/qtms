/// تنفيذ عمليات الجواني — **الطرف الذي يلمس الشبكة** (`WU-004`).
///
/// ★ **مفصول عن `sack_intake.dart` عمداً**، بنفس منطق `inventory_handler.dart`:
/// كل قرار تفويض وقاعدة عمل هناك في **دوال خالصة تُختبَر بلا سحابة**؛
/// وهنا **الترتيب والقراءة والالتزام** وحدها.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ★★★ **عدّادان لا واحد في الإنشاء — وهو ما يميّز هذه الوحدة:**
///   ① **عدّاد المستندات** `document_counters/sack_{YYYYMMDD}` ⟵ يُنتج
///      رقم المستند `SCK-YYYYMMDD-####` (`naming-conventions.md` §5).
///   ② ★★ **العدّاد اليومي للجواني** `daily_sack_counters/{sourceId}_{YYYYMMDD}`
///      ⟵ يُنتج **الرقم المتسلسل اليومي المستقل لكل مصدر** (`FR-M7-04`).
///
/// ⛔★★ **وهما مستقلان فعلاً لا نسختان:** `AT-14` يفرض تسلسلاً **١ ثم ٢ ثم ٣
/// عبر كل رعية رداع**، و`AT-15` يفرض أن **جونية ماوية في اليوم نفسه رقمها ١
/// مستقلاً** (`E-44`). ⟵ **فعدّادٌ واحد كان يُنتج «٢» لأول جونية في المصدر
/// الثاني**، ★ **بينما رقم المستند يتسلسل عبر المصادر كلها بحكم صيغته.**
///
/// ★★ **وكلاهما يُستهلَك في الالتزام نفسه** — ⟵ **فلا رقمٌ يُخصَّص ثم تفشل
/// الكتابة فتبقى فجوة** (`counter_allocator.dart`).
/// ═══════════════════════════════════════════════════════════════════════
///
/// ★ **ومصدر «تاريخ اليوم من الخادم» هو نفسه المشروح في
/// `inventory_handler.dart`** — ⛔ **ولا يُعاد شرحه هنا**: الحاوية تقترح
/// **والمنصّة تحكم** عبر `platformDayOf(reads)` (`GR-54` · `E-41`).
library;

import 'package:qtms_domain/qtms_domain.dart';
import 'package:shelf/shelf.dart';

import 'audited_transaction.dart';
import 'callable.dart';
import 'counter_allocator.dart' show counterValueField;
import 'firestore_value.dart' show DecimalValue;
import 'identity_gateway.dart';
import 'inventory.dart';
import 'inventory_handler.dart'
    show
        inventoryLedgerLimit,
        inventoryLedgerQuery,
        platformDayOf,
        readInt,
        readSourceIds,
        readStockMovement,
        readStoredName,
        readWeight;
import 'permission_sync_handler.dart' show requestIdField;
import 'sack_intake.dart';

/// اسم حقل سبب التعديل أو الإلغاء في الحمولة.
const String sackReasonField = 'reason';

/// ★ مفتاح استعلام النوع الافتراضي «السكرب».
const String scrapItemQueryKey = '__scrapItem';

/// ★ حدّ قراءة النوع الافتراضي — **اثنان لا واحد عمداً**.
///
/// ⚠️⚠️ **والثاني ليس ترفاً:** الحدّ `1` كان يُخفي وجود نوعين افتراضيين،
/// ⟵ **فيختار أحدهما بلا إنذار** — ★ **ومفتاحُ رصيد السكرب يُبنى عليه**،
/// ⛔ **فاختيارٌ صامت بين اثنين يُنتج رصيدين لسكربٍ واحد.**
const int scrapItemQueryLimit = 2;

/// منفّذ عمليات الجواني.
final class SackIntakeHandler {
  /// ينشئ المنفّذ بتبعياته — ★ **تُحقَن، فيُختبَر بلا سحابة**.
  const SackIntakeHandler({
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
  Future<Response> handle(Request httpRequest, SackOperation operation) async {
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
    SackOperation operation,
  ) async {
    final AccountRecord actor = await _identity.verifyIdToken(call.idToken);
    final String? requestId = call.readString(requestIdField);
    final String? sourceId = call.readString('sourceId');
    if (requestId == null || sourceId == null) {
      return callableFailure(CallableError.invalidArgument);
    }

    // ① البوابة — ⛔ قبل أي معاملة: الصلاحية **والنطاق** معاً.
    final SackRejected? gate = sackGate(
      SackRequest(
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
        : _mutate(call, actor, requestId, sourceId, operation);
  }

  // ═════════════════════════════════════════════════════════════════════
  // الإنشاء — ★ **الرأس والسكرب معاً، واليوم من المنصّة**
  // ═════════════════════════════════════════════════════════════════════

  Future<Response> _create(
    CallableRequest call,
    AccountRecord actor,
    String requestId,
    String sourceId,
  ) async {
    CalendarDay day = CalendarDay.fromUtc(_now());
    String? number;
    int? sequence;

    // ★ **محاولتان لا أكثر** — ⟵ **فانقلابُ منتصف الليل يُصحَّح مرة واحدة**
    //   ⛔ **ولا حلقة لا تنتهي** (نفس منطق `inventory_handler.dart`).
    for (int attempt = 0; attempt < 2; attempt++) {
      final CalendarDay? drift = await _runCreate(
        call: call,
        actor: actor,
        requestId: requestId,
        sourceId: sourceId,
        day: day,
        onAllocated: (String allocated, int allocatedSequence) {
          number = allocated;
          sequence = allocatedSequence;
        },
      );
      if (drift == null) {
        return callableSuccess(<String, Object?>{
          'documentNumber': number,
          'dailySequence': sequence,
          'stockDate': day.format(),
        });
      }
      day = drift;
    }

    // ⛔ **يومان متتاليان مختلفان ⟵ شذوذُ ساعةٍ لا انقلابُ منتصف ليل**.
    return callableFailure(
      CallableError.internal,
      detail: 'تعذّر تثبيت يوم الخادم — راجع ساعة الحاوية',
    );
  }

  Future<CalendarDay?> _runCreate({
    required CallableRequest call,
    required AccountRecord actor,
    required String requestId,
    required String sourceId,
    required CalendarDay day,
    required void Function(String, int) onAllocated,
  }) async {
    final String? supplierId = call.readString('supplierId');
    final String sourcePath = _transaction.documentPath(
      sourcesCollection,
      sourceId,
    );
    final String documentCounterPath = _transaction.documentPath(
      documentCountersCollection,
      documentCounterId(kind: DocumentKind.sack, day: day),
    );
    final String dailyCounterPath = _transaction.documentPath(
      dailySackCountersCollection,
      dailySackCounterId(sourceId: sourceId, day: day),
    );
    final String? supplierPath = supplierId == null
        ? null
        : _transaction.documentPath(suppliersCollection, supplierId);

    CalendarDay? drift;
    await _transaction.run<void>(
      readPaths: <String>[
        sourcePath,
        documentCounterPath,
        dailyCounterPath,
        ?supplierPath,
      ],
      queries: <DocumentQuery>[_scrapItemQuery()],
      plan: (TransactionReads reads) {
        // ③ ★★★ **يوم المنصّة هو الحَكَم**.
        final CalendarDay? observed = platformDayOf(reads);
        if (observed == null) {
          throw const AbortTransaction(CallableError.internal);
        }
        if (observed != day) {
          drift = observed;
          throw const AbortTransaction(CallableError.concurrency);
        }

        final int documentSequence = nextSequence(
          readInt(reads.document(documentCounterPath)?[counterValueField]),
        );
        final String number = formatDocumentNumber(
          kind: DocumentKind.sack,
          day: day,
          sequence: documentSequence,
        );
        // ⛅★★ **والتسلسل اليومي من عدّاده هو** — `FR-M7-04` · `E-44`.
        final int dailySequence = nextSequence(
          readInt(reads.document(dailyCounterPath)?[counterValueField]),
        );
        onAllocated(number, dailySequence);

        final Outcome<ValidatedSackIntake> validated = _validateIntake(
          call: call,
          sourceId: sourceId,
          source: reads.document(sourcePath),
          supplierId: supplierId,
          lines: const <ValidatedSackLine>[],
        );
        if (validated case Failure<ValidatedSackIntake>(:final AppError error)) {
          throw AbortTransaction(sackValidationError(error));
        }

        final SackPlan plan = planSack(
          SackRequest(
            actor: actor,
            requestId: requestId,
            sourceId: sourceId,
            documentNumber: number,
            stockDate: day,
            dailySequence: dailySequence,
            intake: (validated as Success<ValidatedSackIntake>).value,
            storedSource: reads.document(sourcePath),
            storedSupplierSourceIds: supplierPath == null
                ? null
                : readSourceIds(reads.document(supplierPath)),
            storedSupplierName: supplierPath == null
                ? null
                : readStoredName(reads.document(supplierPath)),
            scrapItemId: _scrapItemIdOf(reads),
            // ⛔★★ **ولا حركات تُقرأ للإنشاء** — ★ **مفاتيح هذه الجونية
            //    تحمل تسلسلها الذي خُصِّص للتوّ**، **والتسلسل لا يُعاد
            //    استخدامه أبداً** (`ADR-0007` القاعدة 3)، ⟵ **فلا حركة
            //    سابقة يمكن أن تحمل المفتاح نفسه.**
            deviceInfo: call.readString('deviceInfo'),
          ),
          SackOperation.createSack,
        );
        if (plan case SackRejected(:final CallableError error)) {
          throw AbortTransaction(error);
        }

        final SackAccepted accepted = plan as SackAccepted;
        return AuditedWrite<void>(
          documents: <PendingDocument>[
            for (final InventoryWrite write in accepted.writes)
              _toPending(write),
            // ⛅ **العدّادان يُستهلكان في الالتزام نفسه**.
            PendingDocument(
              collectionId: documentCountersCollection,
              documentId: documentCounterId(kind: DocumentKind.sack, day: day),
              fields: <String, Object?>{counterValueField: documentSequence},
              updateMask: const <String>[counterValueField],
            ),
            PendingDocument(
              collectionId: dailySackCountersCollection,
              documentId: dailySackCounterId(sourceId: sourceId, day: day),
              fields: <String, Object?>{counterValueField: dailySequence},
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
  // بقية المسارات — ★ **واليوم محفورٌ في رقم المستند**
  // ═════════════════════════════════════════════════════════════════════

  Future<Response> _mutate(
    CallableRequest call,
    AccountRecord actor,
    String requestId,
    String sourceId,
    SackOperation operation,
  ) async {
    final String? number = call.readString('documentNumber');
    if (number == null) return callableFailure(CallableError.invalidArgument);
    // ★★ **اليوم من الرقم لا من الجهاز ولا من الساعة** — ★ **ويُقابَل
    //   بـ`stockDate` المخزَّن داخل المعاملة** (`_existenceGate`).
    final CalendarDay? day = parseDocumentNumberDay(number);
    if (day == null) return callableFailure(CallableError.invalidArgument);

    // ⛔⛔★★★ **ولا فحصَ لغياب السبب** — `ADR-0020` (2026-08-27):
    //    ★ **اختياريٌّ في كل عملية**، ⟵ **ويُمرَّر كما ورد أو غائباً.**
    final String? reason = call.readString(sackReasonField);

    // ★ **قراءةٌ تمهيدية للمستند** — ⟵ **لمعرفة تسلسله واسم رعويه المُجمَّد**
    //   اللذين تُبنى بهما **مفاتيح الرصيد المركّبة**، ⛔ **وليست مصدرَ قرار**:
    //   المعاملة تُعيد قراءة المستند وتحكم به (`_existenceGate`).
    final Map<String, Object?>? preview = await _transaction.readDocument(
      collectionId: sacksCollection,
      documentId: number,
    );
    if (preview == null) return callableFailure(CallableError.invalidArgument);
    final StoredSack? previewSack = readStoredSack(preview);
    if (previewSack == null) {
      return callableFailure(CallableError.invalidArgument);
    }

    final List<ValidatedSackLine>? incoming = operation.touchesLines
        ? _readLines(call, previewSack)
        : null;
    if (operation == SackOperation.enterSackLines && incoming == null) {
      return callableFailure(CallableError.invalidArgument);
    }

    // ★★ **كل مفتاحٍ يلمسه هذا الطلب** — القائم **والوارد معاً**.
    final Set<String> keys = <String>{
      for (final ValidatedSackLine line in previewSack.lines)
        line.itemKeyIn(
          dailySequence: previewSack.dailySequence,
          supplierName: previewSack.supplierName,
        ),
      for (final ValidatedSackLine line in incoming ?? const <ValidatedSackLine>[])
        line.itemKeyIn(
          dailySequence: previewSack.dailySequence,
          supplierName: previewSack.supplierName,
        ),
      // ★ **ومفتاح السكرب القائم والجديد معاً** — ⟵ **فتخفيضُه إلى صفرٍ
      //   يجب أن يَسِم حركته ملغاة** (`GR-07`: ⛔ لا حذف).
      ?previewSack.scrapItemKey,
      if (operation.touchesScrap)
        sackScrapCompositeName(
          dailySequence: previewSack.dailySequence,
          supplierName: previewSack.supplierName,
        ),
    };

    final String documentPath =
        _transaction.documentPath(sacksCollection, number);
    final String sourcePath =
        _transaction.documentPath(sourcesCollection, sourceId);

    await _transaction.run<void>(
      readPaths: <String>[documentPath, sourcePath],
      queries: <DocumentQuery>[
        if (operation.touchesScrap || operation.touchesLines) _scrapItemQuery(),
        for (final String key in keys)
          inventoryLedgerQuery(sourceId: sourceId, itemKey: key, day: day),
      ],
      plan: (TransactionReads reads) {
        final StoredSack? stored = readStoredSack(reads.document(documentPath));
        if (stored == null) {
          throw const AbortTransaction(CallableError.invalidArgument);
        }

        ValidatedSackIntake? intake;
        if (operation.isFullAmend) {
          final Outcome<ValidatedSackIntake> validated = _validateIntake(
            call: call,
            sourceId: sourceId,
            source: reads.document(sourcePath),
            supplierId: stored.supplierId,
            lines: incoming ?? const <ValidatedSackLine>[],
          );
          if (validated
              case Failure<ValidatedSackIntake>(:final AppError error)) {
            throw AbortTransaction(sackValidationError(error));
          }
          intake = (validated as Success<ValidatedSackIntake>).value;
        }

        final SackPlan plan = planSack(
          SackRequest(
            actor: actor,
            requestId: requestId,
            sourceId: sourceId,
            documentNumber: number,
            stockDate: day,
            dailySequence: stored.dailySequence,
            intake: intake,
            lines: incoming,
            storedSource: reads.document(sourcePath),
            stored: stored,
            ledger: _ledgerOf(reads, keys),
            scrapItemId: (operation.touchesScrap || operation.touchesLines)
                ? _scrapItemIdOf(reads)
                : null,
            taxPerKilo: _moneyOf(call.data['taxPerKilo']),
            displayName: call.readString('displayName'),
            scrapWeight: _weightOf(call.data['scrapWeight']),
            lostWeightNote: call.readString('lostWeightNote'),
            reason: reason,
            deviceInfo: call.readString('deviceInfo'),
          ),
          operation,
        );
        if (plan case SackRejected(:final CallableError error)) {
          throw AbortTransaction(error);
        }

        final SackAccepted accepted = plan as SackAccepted;
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
      'stockDate': day.format(),
    });
  }

  // ═════════════════════════════════════════════════════════════════════
  // قراءة الحمولة والنتائج
  // ═════════════════════════════════════════════════════════════════════

  /// ★ **يبني المستند من سجل المصدر لا من الحمولة** — ⟵ **فإلزاميةُ الرعوي
  /// من المصدر**، ⛔ **ولا يُعلن العميلُ أن المصدر لا يشترطه فيتخطّى الشرط.**
  static Outcome<ValidatedSackIntake> _validateIntake({
    required CallableRequest call,
    required String sourceId,
    required Map<String, Object?>? source,
    required String? supplierId,
    required List<ValidatedSackLine> lines,
  }) =>
      validateSackIntake(
        SackIntakeInput(
          sourceId: sourceId,
          // ★★ **من سجل المصدر لا من الحمولة** — `FR-M7-03`.
          sourceRequiresSupplier: source?['requiresSupplierOnIntake'] == true,
          supplierId: supplierId,
          weights: SackWeightsInput(
            totalWeight: _weightOf(call.data['totalWeight']) ?? WeightKg.zero,
            iceWeight: _weightOf(call.data['iceWeight']) ?? WeightKg.zero,
            scrapWeight: _weightOf(call.data['scrapWeight']) ?? WeightKg.zero,
          ),
          lines: <SackLineInput>[
            // ⚠️ **السطور تُمرَّر مُتحقَّقاً منها سلفاً** — ★ **وتُعاد صياغتها
            //   مُدخَلاتٍ ليمرّ المستند كاملاً بالدالة الواحدة**، ⛔ **فلا
            //   قيدٌ من قيوده الستة يتخطّى سطراً** (`coding-standards.md` §2.2).
            for (final ValidatedSackLine line in lines)
              SackLineInput(
                itemId: line.itemId,
                itemName: line.itemName,
                nature: line.nature,
                unit: line.unit,
                quantity: line.quantity.pieces,
                pieceWeightGrams: line.nature == ItemNature.countBased
                    ? null
                    : line.pieceWeightGrams,
                lineTotalWeight: line.nature == ItemNature.countBased
                    ? line.lineTotalWeight.kilograms
                    : null,
                distributionPrice: line.distributionPrice,
                minCashPrice: line.minCashPrice,
                note: line.note,
              ),
          ],
          lostWeightConfirmed: call.data['lostWeightConfirmed'] == true,
          lostWeightNote: call.readString('lostWeightNote'),
          notes: call.readString('notes'),
        ),
      );

  /// ★★ يقرأ السطور من الحمولة — **بطبيعة النوع ووحدته من سجله**.
  ///
  /// ⛔★★★ **والطبيعة من القاعدة لا من الجهاز** — ★ **وهي ما يختار حالةَ
  /// وزن الحبة من الثلاث** (`FR-M7-13`): ⟵ **فعميلٌ يُعلن نوعاً وزنياً
  /// «عددياً» كان يستنتج له وزن حبة من الوزن الكلي**، ⛔ **وهو بالضبط ما
  /// يمنعه `FR-M7-14` نصّاً.**
  ///
  /// ⚠️ **ويُرجِع `null` لحمولةٍ غير صالحة** — ⛔ **ولا قائمةً فارغة**:
  /// الفارغة **تعني حذف كل السطور** وهي نيّةٌ مشروعة، ⟵ **وطيّ الخطأ فيها
  /// كان سيمحو سطور مستندٍ بسبب حمولةٍ مشوَّهة.**
  static List<ValidatedSackLine>? _readLines(
    CallableRequest call,
    StoredSack stored,
  ) {
    final Object? raw = call.data['lines'];
    if (raw is! List<Object?>) return null;

    final List<SackLineInput> inputs = <SackLineInput>[];
    for (final Object? entry in raw) {
      if (entry is! Map<String, Object?>) return null;
      final Object? itemId = entry['itemId'];
      final Object? itemName = entry['itemName'];
      final int? quantity = readInt(entry['quantity']);
      final ItemNature? nature = _natureOf(entry['nature']);
      if (itemId is! String ||
          itemId.trim().isEmpty ||
          itemName is! String ||
          itemName.trim().isEmpty ||
          quantity == null ||
          nature == null) {
        return null;
      }
      inputs.add(
        SackLineInput(
          itemId: itemId.trim(),
          itemName: itemName.trim(),
          nature: nature,
          unit: ItemUnit.piece,
          quantity: quantity,
          configuredPieceWeightGrams: _doubleOf(
            entry['configuredPieceWeightGrams'],
          ),
          pieceWeightGrams: _doubleOf(entry['pieceWeightGrams']),
          lineTotalWeight: _doubleOf(entry['lineTotalWeight']),
          distributionPrice: _moneyOf(entry['distributionPrice']),
          minCashPrice: _moneyOf(entry['minCashPrice']),
          note: entry['note'] is String ? entry['note']! as String : null,
        ),
      );
    }

    // ★ **ويمرّ كلٌّ منها بالجدول الثلاثي** — ⛔ **ولا سطرٌ يُبنى بالتخمين.**
    final List<ValidatedSackLine> validated = <ValidatedSackLine>[];
    final Set<String> seen = <String>{};
    for (final SackLineInput input in inputs) {
      if (!seen.add(input.itemId)) return null;
      final Outcome<ValidatedSackLine> resolved = resolveSackLine(input);
      if (resolved case Failure<ValidatedSackLine>(:final AppError error)) {
        throw AbortTransaction(sackValidationError(error));
      }
      validated.add((resolved as Success<ValidatedSackLine>).value);
    }
    validated.sort(
      (ValidatedSackLine a, ValidatedSackLine b) =>
          a.itemId.compareTo(b.itemId),
    );
    // ⚠️ `stored` غير مستعمَل هنا عمداً — ★ **الأوزان تُقرأ من المستند داخل
    //   المعاملة لا من هذه اللقطة** (راجع `_mutate`).
    assert(stored.dailySequence >= 1, 'تسلسلٌ مخزَّن غير صالح');
    return validated;
  }

  /// ★★ استعلام النوع الافتراضي «السكرب» — ⛅ **يُنشئه `writeAppSettings`**.
  ///
  /// ⚠️⚠️ **ولماذا استعلامٌ لا معرّفٌ مخزَّن في `app_settings`:** `IQ-012`
  /// أنشأ النوع في `items` بعَلَم `isSystemDefault` ⛔ **ولم يضع مؤشّراً
  /// إليه في مستند الإعداد**. ⟵ ★ **فالعَلَم هو مصدر الحقيقة الوحيد**،
  /// ⛔ **واختراعُ حقلِ مؤشّرٍ الآن كان يُنشئ مصدرَ حقيقةٍ ثانياً** يفترق
  /// عن العَلَم عند أول تعديل.
  static DocumentQuery _scrapItemQuery() => const DocumentQuery(
        key: scrapItemQueryKey,
        collectionId: itemsCollection,
        fieldPath: 'isSystemDefault',
        equalTo: true,
        limit: scrapItemQueryLimit,
      );

  /// ★ معرّف النوع الافتراضي أو `null` — ⛔ **والتعدّد رفضٌ لا اختيار**.
  static String? _scrapItemIdOf(TransactionReads reads) {
    final List<String> matches = reads.matches(scrapItemQueryKey);
    if (matches.length != 1) {
      // ⛔★★ **صفرٌ ⟵ لم يُكتب الإعداد التأسيسي بعد** (`FR-M21-03`)،
      //    **واثنان ⟵ فسادُ بيانات**. ★ **وكلاهما يُرفَض صراحةً**،
      //    ⛔ **ولا يُختار أحدهما ولا يُكتب سكربٌ بلا نوع.**
      return null;
    }
    return matches.single;
  }

  /// ★★ حركات الدفتر لكل مفتاح مركّب — **بوحدتها المقروءة من الحركة نفسها**.
  ///
  /// ⚠️⚠️ **والوحدة من الحركة لا من سجل نوع** — ★ **لأن المفتاح هنا اسمٌ
  /// مركّب لا معرّف نوع**، ⟵ **فلا سجل يحمله**. ⛔ **والمجهول يُقرأ حبّةً**،
  /// **والسكرب يُقرأ وزناً** بحكم مفتاحه المعروف.
  Map<String, List<LedgerRead>> _ledgerOf(
    TransactionReads reads,
    Set<String> keys,
  ) {
    final Map<String, List<LedgerRead>> ledger = <String, List<LedgerRead>>{};
    for (final String key in keys) {
      final List<String> ids = reads.matches(key);
      final List<Map<String, Object?>> documents = reads.matchedDocuments(key);
      // ⛔★★ **بترٌ ⟵ رصيدٌ كاذب** — ★ **ويُرفَض صراحةً** (`ADR-0008`).
      if (ids.length >= inventoryLedgerLimit) {
        throw const AbortTransaction(CallableError.internal);
      }
      ledger[key] = <LedgerRead>[
        for (int i = 0; i < ids.length; i++)
          LedgerRead(
            movementId: ids[i],
            movement: readStockMovement(
              key,
              documents[i],
              unit: _unitOf(documents[i]),
            ),
          ),
      ];
    }
    return ledger;
  }

  /// ★ وحدة الحركة المقروءة — ⛔ **والمجهول حبّة**.
  static ItemUnit _unitOf(Map<String, Object?> data) {
    for (final ItemUnit unit in ItemUnit.values) {
      if (unit.name == data['unit']) return unit;
    }
    return ItemUnit.piece;
  }

  static ItemNature? _natureOf(Object? raw) {
    for (final ItemNature nature in ItemNature.values) {
      if (nature.name == raw) return nature;
    }
    return null;
  }

  /// ★ مبلغٌ مقروء أو `null` — ⛔ **والكسر ليس مبلغاً** (`ADR-0015` القاعدة 3).
  static Money? _moneyOf(Object? raw) {
    final int? value = readInt(raw);
    return value == null ? null : Money(value);
  }

  /// ★ وزنٌ مقروء أو `null` — ⚠️ **والكسر مقبول** (`ADR-0015` القاعدة 9).
  static WeightKg? _weightOf(Object? raw) {
    if (raw == null) return null;
    if (raw is! num && raw is! String) return null;
    return WeightKg(readWeight(raw));
  }

  static double? _doubleOf(Object? raw) => switch (raw) {
        final num value => value.toDouble(),
        final String value => double.tryParse(value),
        _ => null,
      };

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

// ═════════════════════════════════════════════════════════════════════════
// قراءة مستند الجونية — ★ **مصدرٌ واحد لفكّ الترميز**
// ═════════════════════════════════════════════════════════════════════════

/// ★★ يفكّ مستند جونية مقروءاً إلى [StoredSack] — أو `null` **لمشوَّه**.
///
/// ⚠️⚠️ **ومُصدَّرة عمداً:** يستعملها المعالج **مرتين** (اللقطة التمهيدية
/// وداخل المعاملة)، ★ **وتستعملها الاختبارات**. ⟵ **ونسخةٌ ثانية من فكّ
/// الترميز كانت تفترق عند أول تغيير في اسم حقل** (`coding-standards.md` §2.2).
///
/// ⛔★★ **والمشوَّه يُرفَض ولا يُقرأ بقيمٍ افتراضية:** جونيةٌ بلا تسلسلٍ أو
/// بلا أوزان **تُنتج مفاتيح رصيدٍ خاطئة**، ⟵ **وقراءتُها بصفرٍ كانت تكتب
/// حركاتٍ على مفتاح «جونية رقم 0»** ⛔ **بلا أي أثر ظاهر.**
StoredSack? readStoredSack(Map<String, Object?>? data) {
  if (data == null) return null;
  final Object? sourceId = data['sourceId'];
  final int? dailySequence = readInt(data['dailySequence']);
  final Object? stockDate = data['stockDate'];
  if (sourceId is! String ||
      sourceId.isEmpty ||
      dailySequence == null ||
      dailySequence < 1 ||
      stockDate is! DateTime) {
    return null;
  }

  final ValidatedSackWeights weights = ValidatedSackWeights(
    totalWeight: WeightKg(readWeight(data['totalWeight'])),
    iceWeight: WeightKg(readWeight(data['iceWeight'])),
    scrapWeight: WeightKg(readWeight(data['scrapWeight'])),
  );

  return StoredSack(
    sourceId: sourceId,
    stockDate: CalendarDay.fromUtc(stockDate),
    dailySequence: dailySequence,
    displayName: data['displayName'] is String
        ? data['displayName']! as String
        : sackDisplayName(dailySequence: dailySequence),
    weights: weights,
    lines: _storedLines(data['lines']),
    status: data['status'] == SackStatus.cancelled.name
        ? SackStatus.cancelled
        : SackStatus.approved,
    lostWeightConfirmed: data['lostWeightConfirmed'] == true,
    supplierId: data['supplierId'] is String
        ? data['supplierId']! as String
        : null,
    supplierName: readStoredName(<String, Object?>{
      'name': data['supplierName'],
    }),
    scrapItemKey: data['scrapItemKey'] is String
        ? data['scrapItemKey']! as String
        : null,
    lostWeightNote: data['lostWeightNote'] is String
        ? data['lostWeightNote']! as String
        : null,
    notes: data['notes'] is String ? data['notes']! as String : null,
    amendCount: readInt(data['amendCount']) ?? 0,
  );
}

/// ★ سطور مستندٍ مخزَّن — ⛔ **والمشوَّه يُسقَط لا يُقرأ بالتخمين**.
///
/// ⚠️ **وتُقرأ بقيمها المخزَّنة لا بإعادة اشتقاقها:** `pieceWeightGrams`
/// و`lineTotalWeight` **مُجمَّدان لحظة الحفظ** (`FR-M7-15` · `ADR-0007`
/// القاعدة 4)، ⟵ **وإعادةُ اشتقاقهما كانت تُغيّر أرقاماً تاريخية.**
List<ValidatedSackLine> _storedLines(Object? raw) {
  if (raw is! List<Object?>) return const <ValidatedSackLine>[];
  final List<ValidatedSackLine> lines = <ValidatedSackLine>[];
  for (final Object? entry in raw) {
    if (entry is! Map<String, Object?>) continue;
    final Object? itemId = entry['itemId'];
    final int? quantity = readInt(entry['quantity']);
    if (itemId is! String || itemId.isEmpty || quantity == null) continue;
    lines.add(
      ValidatedSackLine(
        itemId: itemId,
        itemName: entry['itemName'] is String
            ? entry['itemName']! as String
            : itemId,
        nature: entry['nature'] == ItemNature.countBased.name
            ? ItemNature.countBased
            : ItemNature.weightBased,
        unit: entry['unit'] == ItemUnit.kilogram.name
            ? ItemUnit.kilogram
            : ItemUnit.piece,
        quantity: PieceCount(quantity),
        pieceWeightGrams: readWeight(entry['pieceWeightGrams']),
        pieceWeightOrigin: _originOf(entry['pieceWeightOrigin']),
        lineTotalWeight: WeightKg(readWeight(entry['lineTotalWeight'])),
        distributionPrice: _storedMoney(entry['distributionPrice']),
        minCashPrice: _storedMoney(entry['minCashPrice']),
        note: entry['note'] is String ? entry['note']! as String : null,
      ),
    );
  }
  return lines;
}

/// ★ مبلغٌ مخزَّن أو `null` — ⛔ **و`null` تعني «معلّق» لا صفراً** (`FR-M7-21`).
///
/// ⚠️⚠️ **والتمييز ليس شكلياً:** سعرُ توزيعٍ **صفراً** قرارٌ صريح، ★ **وغيابُه
/// بندٌ في المركز المعلّق** — ⟵ **وطيُّ الغياب في صفرٍ كان يُسقِط البند
/// ويجعل الجونية تبدو مكتملة التسعير** (`isPricingComplete`).
Money? _storedMoney(Object? raw) {
  final int? value = readInt(raw);
  return value == null ? null : Money(value);
}

PieceWeightOrigin _originOf(Object? raw) {
  for (final PieceWeightOrigin origin in PieceWeightOrigin.values) {
    if (origin.name == raw) return origin;
  }
  // ⛔ **والمجهول «يدوي»** — ★ **وهو الافتراض الآمن**: ⟵ **وسمُه «تهيئةً»
  //   كان يدّعي مصدراً لم يُقرأ**، **و«مستنتَجاً» يدّعي اشتقاقاً لم يقع.**
  return PieceWeightOrigin.manual;
}

/// ★ قيمةٌ عشرية للكتابة — ⛔ **ولا تمرّ `double` مجرَّدة** (`ADR-0015`).
///
/// ⚠️ **مُصدَّرة للاختبارات وحدها** — ★ **فالمخطِّط يبنيها بنفسه.**
DecimalValue decimalOf(double value) => DecimalValue(value);

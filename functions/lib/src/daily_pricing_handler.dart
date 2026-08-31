/// تنفيذ عملية التسعير اليومي — **الطرف الذي يلمس الشبكة** (`WU-005`).
///
/// ★ **مفصول عن `daily_pricing.dart` عمداً**، بنفس منطق `inventory_handler.dart`:
/// كل قرار تفويض وقاعدة عمل هناك في **دوال خالصة تُختبَر بلا سحابة**؛
/// وهنا **الترتيب والقراءة والالتزام** وحدها.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ★★★ **يوم السعر — من المنصّة لا من ساعة الحاوية**
///
/// `FR-M9-03` يجعل السعر يخصّ **(النوع × المصدر × اليوم)**، و`FR-M9-01`
/// يجعل **كل يوم يبدأ بلا أسعار** — ⟵ ★ **فاليوم يدخل مفتاح المستند نفسه**
/// (`{sourceId}_{itemKey}_{date}`)، ⛔ **ولا يمكن بناء مفتاحٍ من قيمةٍ لا
/// نعرفها**. **و`coding-standards.md` §2.3 (`GR-54` · `E-41`) يمنع وقت
/// الجهاز في أي حقل يُخزَّن، و«الحاوية جهازٌ أيضاً».**
///
/// ✅ **فالآلية هي آلية `inventory_handler.dart` نفسها حرفياً:** الحاوية
/// **تقترح** والمنصّة **تحكم** — ★ **ومحاولتان لا أكثر**، ⛔ **وغيابُ زمن
/// المنصّة رفضٌ** لا رجوعَ إلى ساعة الحاوية.
///
/// ⚠️⚠️ **وحدٌّ معلَن لا يُطوى:** اليوم **يوم UTC** — **وهو نفس `DEBT-29`
/// حرفياً** ⛔ **لا حدٌّ جديد**: ما بين 00:00 و03:00 بتوقيت اليمن يُنسَب
/// إلى اليوم السابق. ★ **وموضعُ تغييره واحدٌ لكل المشروع** لا هذا الملف
/// وحده — ⟵ **فحسمُه يسري على التوريد والتسعير معاً.**
/// ═══════════════════════════════════════════════════════════════════════
library;

import 'package:qtms_domain/qtms_domain.dart';
import 'package:shelf/shelf.dart';

import 'audited_transaction.dart';
import 'callable.dart';
import 'daily_pricing.dart';
import 'identity_gateway.dart';
import 'inventory.dart' show InventoryWrite, ItemRead;
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

/// اسم حقل سبب التعديل في الحمولة.
const String dailyPricingReasonField = 'reason';

/// منفّذ عملية التسعير اليومي.
final class DailyPricingHandler {
  /// ينشئ المنفّذ بتبعياته — ★ **تُحقَن، فيُختبَر بلا سحابة**.
  const DailyPricingHandler({
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
    DailyPricingOperation operation,
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
    DailyPricingOperation operation,
  ) async {
    final AccountRecord actor = await _identity.verifyIdToken(call.idToken);
    final String? requestId = call.readString(requestIdField);
    final String? sourceId = call.readString('sourceId');
    if (requestId == null || sourceId == null) {
      return callableFailure(CallableError.invalidArgument);
    }

    // ① البوابة — ⛔ قبل أي معاملة: الصلاحية **والنطاق** معاً.
    final DailyPricingRejected? gate = dailyPricingGate(
      DailyPricingRequest(
        actor: actor,
        requestId: requestId,
        sourceId: sourceId,
        date: CalendarDay.fromUtc(_now()),
      ),
      operation,
    );
    if (gate != null) return callableFailure(gate.error);

    final List<_PriceLineRequest>? lines = _readLines(call);
    if (lines == null || lines.isEmpty) {
      return callableFailure(CallableError.invalidArgument);
    }

    CalendarDay day = CalendarDay.fromUtc(_now());
    // ★ **محاولتان لا أكثر** — راجع ترويسة الملف.
    for (int attempt = 0; attempt < 2; attempt++) {
      final _DayMismatch? drift = await _runWrite(
        call: call,
        actor: actor,
        requestId: requestId,
        sourceId: sourceId,
        lines: lines,
        day: day,
        operation: operation,
      );
      if (drift == null) {
        return callableSuccess(<String, Object?>{
          'date': day.format(),
          'count': lines.length,
        });
      }
      day = drift.observed;
    }
    // ⛔ **يومان متتاليان مختلفان ⟵ شذوذُ ساعةٍ لا انقلابُ منتصف ليل.**
    return callableFailure(
      CallableError.internal,
      detail: 'تعذّر تثبيت يوم الخادم — راجع ساعة الحاوية',
    );
  }

  Future<_DayMismatch?> _runWrite({
    required CallableRequest call,
    required AccountRecord actor,
    required String requestId,
    required String sourceId,
    required List<_PriceLineRequest> lines,
    required CalendarDay day,
    required DailyPricingOperation operation,
  }) async {
    final String sourcePath =
        _transaction.documentPath(sourcesCollection, sourceId);
    final Map<String, String> itemPaths = <String, String>{
      for (final _PriceLineRequest line in lines)
        line.itemId: _transaction.documentPath(itemsCollection, line.itemId),
    };
    // ★ **سجل السعر القائم لكل نوع** — ⟵ **وهو ما يُميّز الإنشاء من التعديل**
    //   (`changesStoredPrice`)، ⛔ **ولا يُؤخَذ ذلك التمييز من الجهاز.**
    final Map<String, String> pricePaths = <String, String>{
      for (final _PriceLineRequest line in lines)
        line.itemId: _transaction.documentPath(
          dailyPricesCollection,
          dailyPriceId(
            sourceId: sourceId,
            itemKey: line.itemId,
            date: day,
          ),
        ),
    };

    _DayMismatch? drift;
    await _transaction.run<void>(
      readPaths: <String>[
        sourcePath,
        ...itemPaths.values,
        ...pricePaths.values,
      ],
      queries: <DocumentQuery>[
        for (final _PriceLineRequest line in lines)
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

        // ★★★ **والمفتاح المركّب نوعٌ لا سجل له** — راجع [withLedgerItems]:
        //    ⛔ **بلا هذا السطر يسقط كلُّ سطرِ جونيةٍ على «النوع غير موجود»**
        //    (`DEBT-55`)، ⟵ **و`FR-M9-02` يُسعِّر ما ورد جواني وسكرباً نصّاً.**
        final Map<String, ItemRead> items = withLedgerItems(
          readItemRecords(reads, itemPaths),
          reads: reads,
          itemKeys: itemPaths.keys,
          sourceId: sourceId,
        );
        final Outcome<ValidatedDailyPriceBatch> validated = _validate(
          sourceId: sourceId,
          lines: lines,
          items: items,
        );
        if (validated is Failure<ValidatedDailyPriceBatch>) {
          throw const AbortTransaction(CallableError.invalidArgument);
        }
        // ★ **الدفعة المُتحقَّق منها تُقرأ مرةً واحدة** — ⟵ **فالمُخطِّط
        //   وباني المركز المعلّق يعملان على الكائن نفسه** ⛔ **لا على نسختين.**
        final ValidatedDailyPriceBatch batch =
            (validated as Success<ValidatedDailyPriceBatch>).value;

        final DailyPricingPlan plan = planDailyPricing(
          DailyPricingRequest(
            actor: actor,
            requestId: requestId,
            sourceId: sourceId,
            date: day,
            batch: batch,
            storedSource: reads.document(sourcePath),
            items: items,
            ledger: readLedgerMovements(
              reads,
              itemPaths.keys,
              units: <String, ItemUnit>{
                for (final MapEntry<String, ItemRead> entry in items.entries)
                  entry.key: entry.value.unit,
              },
            ),
            storedPrices: <String, Map<String, Object?>?>{
              for (final MapEntry<String, String> entry in pricePaths.entries)
                entry.key: reads.document(entry.value),
            },
            reason: call.readString(dailyPricingReasonField),
          ),
          operation,
        );
        if (plan case DailyPricingRejected(:final CallableError error)) {
          throw AbortTransaction(error);
        }

        final DailyPricingAccepted accepted = plan as DailyPricingAccepted;

        // ⏳★★★ **بنود المركز المعلّق — في المعاملة نفسها** (`WU-009` ·
        //    `FR-SYS-09` · `FR-M9-10`): ⟵ **فالبند يزول في اللحظة التي
        //    اكتمل فيها التسعير** ⛔ **لا بعدها بمشغّل** (`AT-16`).
        //    ⚠️⚠️ **ولا يُوقِف شيئاً** — `FR-SYS-06`: **المركز لا يمنع.**
        final PendingEntrySet pending = pendingFromPricedLines(
          batch: batch,
          date: day,
        );

        return AuditedWrite<void>(
          documents: <PendingDocument>[
            for (final InventoryWrite write in accepted.writes)
              PendingDocument(
                collectionId: write.collectionId,
                documentId: write.documentId,
                fields: write.fields,
                updateMask: write.updateMask,
                serverTimestampFields: write.serverTimestampFields,
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

  /// ★ **يبني الدفعة من سجلات الأنواع لا من الحمولة** — ⟵ **فاسمُ النوع
  /// ووحدتُه من القاعدة**، ⛔ **ولا يُرسل العميل وحدةً فيُسعِّر بوحدةٍ ليست
  /// وحدة النوع** (`FR-M5-03` · `FR-M9-06`).
  static Outcome<ValidatedDailyPriceBatch> _validate({
    required String sourceId,
    required List<_PriceLineRequest> lines,
    required Map<String, ItemRead> items,
  }) {
    final List<DailyPriceLineInput> inputs = <DailyPriceLineInput>[];
    for (final _PriceLineRequest line in lines) {
      final ItemRead? item = items[line.itemId];
      if (item == null) {
        return const Failure<ValidatedDailyPriceBatch>(
          ValidationError('FR-M9-01'),
        );
      }
      inputs.add(
        DailyPriceLineInput(
          itemId: line.itemId,
          itemName: item.name,
          unit: item.unit,
          distributionPrice: line.distributionPrice,
          minCashPrice: line.minCashPrice,
        ),
      );
    }
    return validateDailyPrices(
      DailyPriceBatchInput(sourceId: sourceId, lines: inputs),
    );
  }

  /// ★ يقرأ سطور الحمولة — و`null` تعني **حمولةً غير صالحة**.
  ///
  /// ⛔★★ **والكسر في مبلغ يُرفَض ولا يُقرَّب** — `ADR-0015` القاعدة 3:
  /// **قيمةٌ ليست عدداً صحيحاً تُسقِط السطر كله** ⟵ **فيصل المستخدمَ
  /// رفضٌ صريح** ⛔ **لا سعرٌ غير الذي كتبه.**
  static List<_PriceLineRequest>? _readLines(CallableRequest call) {
    final Object? raw = call.data['lines'];
    if (raw is! List<Object?>) return null;
    final List<_PriceLineRequest> lines = <_PriceLineRequest>[];
    for (final Object? entry in raw) {
      if (entry is! Map<String, Object?>) return null;
      final Object? itemId = entry['itemId'];
      if (itemId is! String || itemId.trim().isEmpty) return null;

      final _MoneyField distribution = _money(entry, 'distributionPrice');
      if (distribution.invalid) return null;
      final _MoneyField minimum = _money(entry, 'minCashPrice');
      if (minimum.invalid) return null;

      lines.add(
        _PriceLineRequest(
          itemId: itemId.trim(),
          distributionPrice: distribution.value,
          minCashPrice: minimum.value,
        ),
      );
    }
    return lines;
  }

  /// ★★ يقرأ مبلغاً اختيارياً — ⛔ **ويُميّز الغياب من الفساد**.
  ///
  /// ⚠️⚠️ **والتمييز جوهري لا شكلي:** **الغياب «تفريغ» مقصود** يكتب `null`
  /// (`FR-M9-07`)، ★ **والفساد (كسرٌ أو نصٌّ ليس رقماً) خللٌ يُرفَض** —
  /// ⟵ ⛔ **وقراءتُهما سواءً كانت تُفرِّغ سعراً كتبه المستخدم بكسرٍ**
  /// **بصمت**، وهو ما يمنعه `ADR-0015` القاعدة 3.
  static _MoneyField _money(Map<String, Object?> entry, String key) {
    if (!entry.containsKey(key)) return const _MoneyField.absent();
    final Object? raw = entry[key];
    if (raw == null) return const _MoneyField.absent();
    final int? value = readInt(raw);
    return value == null ? const _MoneyField.invalid() : _MoneyField(Money(value));
  }
}

/// سطرٌ كما وصل في الحمولة — ⛔ **بلا اسمٍ ولا وحدة**: كلاهما من القاعدة.
final class _PriceLineRequest {
  const _PriceLineRequest({
    required this.itemId,
    required this.distributionPrice,
    required this.minCashPrice,
  });

  final String itemId;
  final Money? distributionPrice;
  final Money? minCashPrice;
}

/// ★ مبلغٌ مقروء من الحمولة — **غائبٌ أو صالحٌ أو فاسد**.
final class _MoneyField {
  const _MoneyField(this.value) : invalid = false;
  const _MoneyField.absent()
      : value = null,
        invalid = false;
  const _MoneyField.invalid()
      : value = null,
        invalid = true;

  final Money? value;
  final bool invalid;
}

/// ★ انقلاب اليوم بين اقتراح الحاوية وحكم المنصّة — راجع ترويسة الملف.
final class _DayMismatch {
  const _DayMismatch(this.observed);

  /// اليوم كما أعلنته المنصّة.
  final CalendarDay observed;
}

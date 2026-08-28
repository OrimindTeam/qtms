/// تنفيذ عمليات المخزون — **الطرف الذي يلمس الشبكة** (`WU-003`).
///
/// ★ **مفصول عن `inventory.dart` عمداً**، بنفس منطق `master_data_handler.dart`:
/// كل قرار تفويض وقاعدة عمل هناك في **دوال خالصة تُختبَر بلا سحابة**؛
/// وهنا **الترتيب والقراءة والالتزام** وحدها.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ★★★ **من أين يأتي «تاريخ اليوم من الخادم»؟ — أخطر سؤال في هذا الملف**
///
/// `FR-M6-02` يجعل تاريخ التوريد **«تاريخ اليوم من الخادم، مقفلاً وغير قابل
/// للتغيير إطلاقاً»**، و`coding-standards.md` §2.3 (`GR-54` · `E-41`) يمنع
/// **وقت الجهاز في أي حقل يُخزَّن** — ★ **و`audited_transaction.dart` يُعلن
/// صراحةً أن «الحاوية جهازٌ أيضاً»**. ⟵ ⛔ **فساعة الحاوية لا تصلح مصدراً.**
///
/// ★ **ولا يكفي تحويل `REQUEST_TIME`** كما يكفي لـ`createdAt`: ⚠️ **تاريخ
/// المخزون قيمةٌ نقرؤها نحن** — تدخل **رقم المستند** (`INC-YYYYMMDD-####`)
/// و**المفتاح المركّب** `{sourceId}_{itemKey}_{stockDate}` و**كل استعلام
/// رصيد**. ⛔ **ولا يمكن بناء مفتاحٍ من قيمةٍ لا نعرفها.**
///
/// ✅ **والحلّ: الحاوية تقترح والمنصّة تحكم.**
///   ① يُقترَح اليوم من ساعة الحاوية — ★ **تخميناً لا مصدرَ حقيقة.**
///   ② تُبنى القراءات به، **ويصل زمن المنصّة مع نتيجة الاستعلام**
///      (`TransactionReads.readTime` — `readTime` في `RunQueryResponse`).
///   ③ ⛔ **إن اختلف اليوم، تُبطَل المعاملة وتُعاد مرة واحدة باليوم الذي
///      أعلنته المنصّة** — ⟵ **فالقيمة الملتزَمة يومُ المنصّة دائماً.**
///   ④ ⛔ **وغياب زمن المنصّة رفضٌ** — ولا رجوع إلى ساعة الحاوية.
///
/// ⚠️⚠️ **وحدٌّ معلَن لا يُطوى:** اليوم **يوم UTC** — لأن `firestore.rules`
/// تُعرّفه كذلك (`request.time.date()`) و[CalendarDay.fromUtc] هي المشتقّة
/// الوحيدة. ★ **وبتوقيت اليمن (UTC+3) ينزلق ما بين 00:00 و03:00 محلياً إلى
/// اليوم السابق** — ⟵ **وخارج ساعات العمل الموثَّقة** (`persona-storekeeper.md`:
/// «قرابة السادسة صباحاً»). ⛔ **وتغييرُه قرارُ صاحب المشروع** ومَوضِعُه
/// هذا الملف وحده (`DEBT-29`).
/// ═══════════════════════════════════════════════════════════════════════
library;

import 'package:qtms_domain/qtms_domain.dart';
import 'package:shelf/shelf.dart';

import 'audited_transaction.dart';
import 'callable.dart';
import 'counter_allocator.dart' show counterValueField;
import 'identity_gateway.dart';
import 'inventory.dart';
import 'permission_sync_handler.dart' show requestIdField;

/// اسم حقل سبب التعديل أو الإلغاء في الحمولة.
const String inventoryReasonField = 'reason';

/// ★ حدّ قراءة حركات الدفتر لنوعٍ في يوم.
///
/// ⚠️ **ولماذا حدٌّ أصلاً:** الاستعلام محدود بحركات **يومٍ واحد لنوعٍ واحد
/// في مصدرٍ واحد** — ⟵ **فهو محدود بنشاط اليوم لا بعمر البيانات**
/// (`ADR-0008`). ⛔ **وتجاوزُه لا يُبتلَع:** الرصيد المجموع من مجموعةٍ
/// مبتورة **رقمٌ كاذب**، ★ **فيُرفَض الطلب صراحةً** (راجع `_ledgerOf`).
const int inventoryLedgerLimit = 500;

// ═════════════════════════════════════════════════════════════════════════
// ★★ قراءاتٌ مشتركة — **يستعملها كل مسارٍ يلمس الدفتر** (`WU-003` · `WU-005`)
//
// ⚠️⚠️ **ولماذا مُصدَّرة لا خاصة:** `coding-standards.md` §2.2 يمنع تكرار
// القاعدة الواحدة، ★ **وأخطرُ ما يُكرَّر هنا شرطُ `stockDate`** — `RISK-07`:
// «التاريخان متساويان في 99٪ من الحالات، **فلا يظهر الخطأ إلا عند التصريف
// المتأخر** ويكون قد أنتج تقارير خاطئة **بصمت**». ⟵ **ونسخةٌ ثانية من
// الاستعلام كانت ستفترق عند أول تعديل** ⛔ **بلا اختبارٍ يكشفها.**
// ═════════════════════════════════════════════════════════════════════════

/// ★★ استعلام حركات نوعٍ في **(مصدر × نوع × تاريخ مخزون)**.
///
/// ★ **الفهرس القائم منذ `WU-000`:** `sourceId ↑ · itemKey ↑ · stockDate ↓`.
///
/// ⚠️⚠️ **وعلى `stockDate` لا `entryDate`** — `RISK-07` ·
/// `coding-standards.md` §5 البند 6.
DocumentQuery inventoryLedgerQuery({
  required String sourceId,
  required String itemKey,
  required CalendarDay day,
}) =>
    DocumentQuery(
      key: itemKey,
      collectionId: inventoryLedgerCollection,
      fieldPath: 'sourceId',
      equalTo: sourceId,
      andEquals: <String, Object?>{
        'itemKey': itemKey,
        'stockDate': day.asUtcMidnight(),
      },
      limit: inventoryLedgerLimit,
    );

/// ★★ **زمن المنصّة ⟵ يوماً تقويمياً** — و`null` تعني **أنه لم يصل**.
///
/// ⛔ **وغيابُه رفضٌ** — ★ **ولا رجوع إلى ساعة الحاوية** (راجع ترويسة الملف).
CalendarDay? platformDayOf(TransactionReads reads) {
  final DateTime? readTime = reads.readTime;
  return readTime == null ? null : CalendarDay.fromUtc(readTime);
}

/// ★ سجلات الأنواع المقروءة بمعرّفاتها — **الاسم والوحدة والحالة ومصادره**.
Map<String, ItemRead> readItemRecords(
  TransactionReads reads,
  Map<String, String> itemPaths,
) {
  final Map<String, ItemRead> items = <String, ItemRead>{};
  for (final MapEntry<String, String> entry in itemPaths.entries) {
    final Map<String, Object?>? data = reads.document(entry.value);
    if (data == null) continue;
    final Object? name = data['name'];
    items[entry.key] = ItemRead(
      itemId: entry.key,
      name: name is String && name.isNotEmpty ? name : entry.key,
      unit: readItemUnit(data['unit']),
      isActive: data['isActive'] != false,
      sourceIds: readSourceIds(data) ?? const <String>[],
    );
  }
  return items;
}

/// ★★★ **سجلات الأنواع مُتمَّمةً من الدفتر لكل مفتاحٍ مركّب** (`DEBT-55`).
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **ولماذا لا يكفي [readItemRecords] وحده:** `itemKey` في الدفتر
/// **«النوع أو الاسم المركّب»** (`inventory-ledger.md` · `ADR-0007`) —
/// ★ **وسطرُ الجونية يدخل المخزن بمفتاحٍ مركّب** (`سلة - جونية رقم 1`)
/// ⛔ **لا بمعرّف سجل نوع**، ⟵ **فقراءةُ `items/{itemKey}` تردّ غياباً.**
///
/// ⚠️⚠️★★★ **وهذا بالضبط ما أخفق حيّاً:** `POST /writeDailyPrices` ⟵ **`400`**
/// (2026-08-28) — ★ **ومخزونُ ذلك اليوم كلُّه من جونية**، ⟵ **فسقط كلُّ
/// سطرٍ على «النوع غير موجود»** ⛔ **بينما `FR-M9-02` ينصّ صراحةً على
/// تسعير ما ورد «عدداً أو جواني أو كان سكرباً».**
///
/// ★★ **ومن أين تُؤخذ الوحدة والاسم إذن:** **من حركة الدفتر نفسها** —
/// ⛔ **لا من الحمولة**: ★ **الحركةُ كتبتها السحابة في معاملةٍ سابقة**،
/// ⟵ **فهي بيانٌ مخزَّن كسجل النوع تماماً** (`ADR-0008`: «الرصيد مشتقّ من
/// الدفتر دائماً») — **وشرطُ `FR-M9-06` «الوحدة المخزَّنة لا المُرسَلة»
/// مصونٌ حرفياً.**
///
/// ★ **و[ItemRead.sourceIds] هو المصدر المطلوب وحده** — ⟵ **لأن الاستعلام
/// قيّد `sourceId` أصلاً**، **فوجودُ حركةٍ مطابقة إثباتُ انتماءٍ لا افتراض.**
/// ★ **و[ItemRead.isActive] صحيحٌ دائماً** — ⛔ **إذ لا سجلَ يُعطَّل لمفتاحٍ
/// مركّب**، ⟵ **والحارسُ الفعلي رصيدُ اليوم المقيس من الدفتر بعده.**
///
/// ⛔★★ **ولا يُشتقّ شيءٌ من حركةٍ ملغاة** — ★ **الملغاة ليست مصدرَ هوية
/// كما أنها ليست مصدرَ رصيد** (`A-14`).
/// ═══════════════════════════════════════════════════════════════════════
Map<String, ItemRead> withLedgerItems(
  Map<String, ItemRead> items, {
  required TransactionReads reads,
  required Iterable<String> itemKeys,
  required String sourceId,
}) {
  final Map<String, ItemRead> completed = <String, ItemRead>{...items};
  for (final String itemKey in itemKeys) {
    if (completed.containsKey(itemKey)) continue;
    for (final Map<String, Object?> document in reads.matchedDocuments(itemKey)) {
      if (document['isCancelled'] == true) continue;
      final Object? name = document['itemName'];
      completed[itemKey] = ItemRead(
        itemId: itemKey,
        name: name is String && name.isNotEmpty ? name : itemKey,
        unit: readItemUnit(document['unit']),
        isActive: true,
        sourceIds: <String>[sourceId],
      );
      break;
    }
  }
  return completed;
}

/// ★★ حركات الدفتر لكل نوع — ⛔ **والمجموعة المبتورة رفضٌ لا جمعٌ ناقص**.
///
/// [units] وحدةُ كل نوع **كما هي مخزَّنة في سجله** — ★ **وبها تُبنى الكمية**
/// ⛔ **لا بوحدةٍ مفترضة** (`FR-M5-03` · `GR-19`).
Map<String, List<LedgerRead>> readLedgerMovements(
  TransactionReads reads,
  Iterable<String> itemKeys, {
  required Map<String, ItemUnit> units,
}) {
  final Map<String, List<LedgerRead>> ledger = <String, List<LedgerRead>>{};
  for (final String itemKey in itemKeys) {
    final List<String> ids = reads.matches(itemKey);
    final List<Map<String, Object?>> documents = reads.matchedDocuments(itemKey);
    if (ids.length >= inventoryLedgerLimit) {
      // ⛔★★ **بترٌ ⟵ رصيدٌ كاذب** — ★ **ويُرفَض صراحةً** (`ADR-0008`:
      //    «أي تعارض يُحسَم لصالح الدفتر»؛ ⟵ **ودفترٌ لم يُقرأ كاملاً
      //    لا يُحسَم به**).
      throw const AbortTransaction(CallableError.internal);
    }
    final ItemUnit unit = units[itemKey] ?? ItemUnit.piece;
    ledger[itemKey] = <LedgerRead>[
      for (int i = 0; i < ids.length; i++)
        LedgerRead(
          movementId: ids[i],
          movement: readStockMovement(itemKey, documents[i], unit: unit),
        ),
    ];
  }
  return ledger;
}

/// ★ يبني حركةً من مستند مقروء — ⛔ **والمجهول يُقرأ بالافتراض الآمن**.
///
/// ⚠️ **والافتراض الآمن هنا «حركةٌ حيّة بكميتها»** ⛔ **لا «ملغاة»**:
/// ★ **قراءةُ حركةٍ حيّة ملغاةً تُنقِص الرصيد فتسمح بسحبٍ لا يغطيه المخزون**
/// — ⟵ **وهو بالضبط ما يمنعه `FR-M8-01`.**
///
/// ⚠️⚠️ **و[unit] وحدةُ النوع المخزَّنة لا وحدةٌ تُستنتَج من الحركة** —
/// ★ **والوزن يُقرأ وزناً** (`WeightQuantity`): **السكرب وحدةُ رصيده
/// كيلوجرام** (`FR-M5-03`)، ⟵ **وقراءتُه حبّاتٍ كانت تُفشِل جمعَ رصيده
/// بـ`GR-19`** ⛔ **بلا سببٍ ظاهر.**
StockMovement readStockMovement(
  String itemKey,
  Map<String, Object?> data, {
  required ItemUnit unit,
}) =>
    StockMovement(
      itemKey: itemKey,
      direction: data['direction'] == MovementDirection.outgoing.name
          ? MovementDirection.outgoing
          : MovementDirection.incoming,
      quantity: switch (unit) {
        ItemUnit.piece => PieceQuantity(PieceCount(readInt(data['quantity']) ?? 0)),
        ItemUnit.kilogram =>
          WeightQuantity(WeightKg(readWeight(data['quantity']))),
      },
      // ⛔ **الملغاة صراحةً وحدها ملغاة** — راجع أعلاه.
      isCancelled: data['isCancelled'] == true,
      movementTag: readMovementTag(data['movementTag']),
    );

/// وسم الحركة المقروء — **والمجهول عادية**.
MovementTag readMovementTag(Object? raw) {
  for (final MovementTag tag in MovementTag.values) {
    if (tag.name == raw) return tag;
  }
  return MovementTag.normal;
}

/// وحدة النوع المقروءة.
///
/// ⛔ **ووحدةٌ مجهولة تُقرأ حبّةً** — ★ **وكل مسارٍ كاتب يرفض ما ليس وحدةَ
/// النوع المخزَّنة أصلاً**، ⟵ **فلا مسار يكتب بوحدةٍ لم تُقرأ.**
ItemUnit readItemUnit(Object? raw) {
  for (final ItemUnit unit in ItemUnit.values) {
    if (unit.name == raw) return unit;
  }
  return ItemUnit.piece;
}

/// مصادر السجل المقروء أو `null` — ⛔ **والغياب ليس قائمة فارغة**.
List<String>? readSourceIds(Map<String, Object?>? data) {
  final Object? raw = data?['sourceIds'];
  if (raw is! List<Object?>) return null;
  return <String>[
    for (final Object? id in raw)
      if (id is String && id.isNotEmpty) id,
  ];
}

/// اسم السجل المقروء أو `null` — ⛔ **والفارغ غيابٌ لا نصٌّ فارغ**.
String? readStoredName(Map<String, Object?>? data) {
  final Object? name = data?['name'];
  return (name is String && name.trim().isNotEmpty) ? name.trim() : null;
}

/// عددٌ صحيح مقروء أو `null`.
///
/// ★ القاعدة قد تُعيد العدد الصحيح عشرياً — ⛔ **والكسر ليس كمية معدودة**
/// (`BR-M6-06`)، ⟵ فيعود `null` فيُرفَض السطر.
int? readInt(Object? raw) => switch (raw) {
      final int value => value,
      final double value when value == value.roundToDouble() => value.toInt(),
      final String value => int.tryParse(value),
      _ => null,
    };

/// ★ وزنٌ مقروء بالكيلوجرام — **والمجهول صفر**.
///
/// ⚠️ **والكسر مقبولٌ هنا بخلاف [readInt]** — `ADR-0015` القاعدة 9:
/// **«الأوزان ليست مبالغ … تبقى عشرية كما هي»** (`design-overview.md` §2.11).
double readWeight(Object? raw) => switch (raw) {
      final num value => value.toDouble(),
      final String value => double.tryParse(value) ?? 0,
      _ => 0,
    };

/// منفّذ عمليات المخزون.
final class InventoryHandler {
  /// ينشئ المنفّذ بتبعياته — ★ **تُحقَن، فيُختبَر بلا سحابة**.
  const InventoryHandler({
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
    InventoryOperation operation,
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
    InventoryOperation operation,
  ) async {
    final AccountRecord actor = await _identity.verifyIdToken(call.idToken);
    final String? requestId = call.readString(requestIdField);
    final String? sourceId = call.readString('sourceId');
    if (requestId == null || sourceId == null) {
      return callableFailure(CallableError.invalidArgument);
    }

    // ① البوابة — ⛔ قبل أي معاملة: الصلاحية **والنطاق** معاً.
    final InventoryRejected? gate = inventoryGate(
      InventoryRequest(
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
    // ★ **محاولتان لا أكثر:** الثانية **باليوم الذي أعلنته المنصّة** —
    //   ⟵ **فانقلابُ منتصف الليل يُصحَّح مرة واحدة** ⛔ **ولا حلقة لا تنتهي.**
    for (int attempt = 0; attempt < 2; attempt++) {
      final _DayMismatch? drift = await _runCreate(
        call: call,
        actor: actor,
        requestId: requestId,
        sourceId: sourceId,
        lines: lines,
        day: day,
        onNumber: (String allocated) => number = allocated,
      );
      if (drift == null) {
        return callableSuccess(<String, Object?>{
          'documentNumber': number,
          'stockDate': day.format(),
        });
      }
      day = drift.observed;
    }
    // ⛔ **يومان متتاليان مختلفان ⟵ شذوذُ ساعةٍ لا انقلابُ منتصف ليل** —
    //    ★ **ويُرفَض صراحةً** ولا يُكتب بتاريخٍ مشكوك فيه.
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
    required void Function(String) onNumber,
  }) async {
    final String? supplierId = call.readString('supplierId');
    final String sourcePath = _transaction.documentPath(
      sourcesCollection,
      sourceId,
    );
    final String counterPath = _transaction.documentPath(
      documentCountersCollection,
      documentCounterId(kind: DocumentKind.countedIntake, day: day),
    );
    final Map<String, String> itemPaths = <String, String>{
      for (final _LineRequest line in lines)
        line.itemId: _transaction.documentPath(itemsCollection, line.itemId),
    };
    final String? supplierPath = supplierId == null
        ? null
        : _transaction.documentPath(suppliersCollection, supplierId);

    _DayMismatch? drift;
    await _transaction.run<void>(
      readPaths: <String>[sourcePath, counterPath, ...itemPaths.values, ?supplierPath],
      queries: <DocumentQuery>[
        for (final _LineRequest line in lines)
          _ledgerQuery(sourceId: sourceId, itemKey: line.itemId, day: day),
      ],
      plan: (TransactionReads reads) {
        // ③ ★★★ **يوم المنصّة هو الحَكَم** — راجع ترويسة الملف.
        final CalendarDay? observed = _platformDay(reads);
        if (observed == null) {
          throw const AbortTransaction(CallableError.internal);
        }
        if (observed != day) {
          drift = _DayMismatch(observed);
          throw const AbortTransaction(CallableError.concurrency);
        }

        final int sequence = nextSequence(
          _intOf(reads.document(counterPath)?[counterValueField]),
        );
        final String number = formatDocumentNumber(
          kind: DocumentKind.countedIntake,
          day: day,
          sequence: sequence,
        );
        onNumber(number);

        final Map<String, ItemRead> items = _itemsOf(reads, itemPaths);
        final Outcome<ValidatedCountedIntake> validated = _validate(
          sourceId: sourceId,
          source: reads.document(sourcePath),
          supplierId: supplierId,
          lines: lines,
          items: items,
          notes: call.readString('notes'),
        );
        if (validated is Failure<ValidatedCountedIntake>) {
          throw const AbortTransaction(CallableError.invalidArgument);
        }

        final InventoryPlan plan = planInventory(
          InventoryRequest(
            actor: actor,
            requestId: requestId,
            sourceId: sourceId,
            documentNumber: number,
            stockDate: day,
            intake: (validated as Success<ValidatedCountedIntake>).value,
            storedSource: reads.document(sourcePath),
            items: items,
            ledger: _ledgerOf(reads, lines.map((_LineRequest l) => l.itemId), items),
            storedSupplierSourceIds: supplierPath == null
                ? null
                : _sourceIdsOf(reads.document(supplierPath)),
            storedSupplierName: supplierPath == null
                ? null
                : _nameOf(reads.document(supplierPath)),
          ),
          InventoryOperation.createCountedIntake,
        );
        if (plan case InventoryRejected(:final CallableError error)) {
          throw AbortTransaction(error);
        }

        final InventoryAccepted accepted = plan as InventoryAccepted;
        return AuditedWrite<void>(
          documents: <PendingDocument>[
            for (final InventoryWrite write in accepted.writes)
              _toPending(write),
            // ⛅ **العدّاد يُستهلَك في الالتزام نفسه** — ⟵ **فلا رقمٌ
            //    يُخصَّص ثم تفشل الكتابة فتبقى فجوة.**
            PendingDocument(
              collectionId: documentCountersCollection,
              documentId:
                  documentCounterId(kind: DocumentKind.countedIntake, day: day),
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
    InventoryOperation operation,
  ) async {
    final String? number = call.readString('documentNumber');
    if (number == null) return callableFailure(CallableError.invalidArgument);
    // ★★ **اليوم من الرقم لا من الجهاز ولا من الساعة** — ★ **ويُقابَل
    //   بـ`stockDate` المخزَّن داخل المعاملة** (`_existenceGate`).
    final CalendarDay? day = parseDocumentNumberDay(number);
    if (day == null) return callableFailure(CallableError.invalidArgument);

    // ⛔⛔★★★ **ولا فحصَ لغياب السبب** — `ADR-0020` (2026-08-27):
    //    ★ **اختياريٌّ في كل عملية**، ⟵ **ويُمرَّر كما ورد أو غائباً.**
    final String? reason = call.readString(inventoryReasonField);

    final List<_LineRequest> lines =
        operation.isCancel ? const <_LineRequest>[] : (_readLines(call) ?? const <_LineRequest>[]);
    if (!operation.isCancel && lines.isEmpty) {
      return callableFailure(CallableError.invalidArgument);
    }

    final String? supplierId =
        operation.isCancel ? null : call.readString('supplierId');
    final String documentPath =
        _transaction.documentPath(incomingCountCollection, number);
    final String sourcePath =
        _transaction.documentPath(sourcesCollection, sourceId);

    // ★ **قراءةٌ تمهيدية للمستند** — ⟵ **لمعرفة أنواعه القائمة** التي يجب
    //   أن تُقرأ حركاتُها ولو حُذفت من التعديل. ⛔ **وليست مصدرَ قرار**:
    //   المعاملة تُعيد قراءة المستند وتحكم به (`_existenceGate`).
    final Map<String, Object?>? preview = await _transaction.readDocument(
      collectionId: incomingCountCollection,
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
    final String? supplierPath = supplierId == null
        ? null
        : _transaction.documentPath(suppliersCollection, supplierId);

    await _transaction.run<void>(
      readPaths: <String>[
        documentPath,
        sourcePath,
        ...itemPaths.values,
        ?supplierPath,
      ],
      queries: <DocumentQuery>[
        for (final String itemId in itemIds)
          _ledgerQuery(sourceId: sourceId, itemKey: itemId, day: day),
      ],
      plan: (TransactionReads reads) {
        final Map<String, ItemRead> items = _itemsOf(reads, itemPaths);
        ValidatedCountedIntake? intake;
        if (!operation.isCancel) {
          final Outcome<ValidatedCountedIntake> validated = _validate(
            sourceId: sourceId,
            source: reads.document(sourcePath),
            supplierId: supplierId,
            lines: lines,
            items: items,
            notes: call.readString('notes'),
          );
          if (validated is Failure<ValidatedCountedIntake>) {
            throw const AbortTransaction(CallableError.invalidArgument);
          }
          intake = (validated as Success<ValidatedCountedIntake>).value;
        }

        final InventoryPlan plan = planInventory(
          InventoryRequest(
            actor: actor,
            requestId: requestId,
            sourceId: sourceId,
            documentNumber: number,
            stockDate: day,
            intake: intake,
            storedSource: reads.document(sourcePath),
            storedDocument: reads.document(documentPath),
            items: items,
            ledger: _ledgerOf(reads, itemIds, items),
            storedSupplierSourceIds: supplierPath == null
                ? null
                : _sourceIdsOf(reads.document(supplierPath)),
            storedSupplierName: supplierPath == null
                ? null
                : _nameOf(reads.document(supplierPath)),
            reason: reason,
          ),
          operation,
        );
        if (plan case InventoryRejected(:final CallableError error)) {
          throw AbortTransaction(error);
        }

        final InventoryAccepted accepted = plan as InventoryAccepted;
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

  /// ★ **يبني المستند من سجلات الأنواع لا من الحمولة** — ⟵ **فاسمُ النوع
  /// ووحدتُه من القاعدة**، ⛔ **ولا يُرسل العميل وحدةً فيُنشئ حركةً بوحدةٍ
  /// ليست وحدة النوع** (`FR-M5-03` · `GR-19`).
  static Outcome<ValidatedCountedIntake> _validate({
    required String sourceId,
    required Map<String, Object?>? source,
    required String? supplierId,
    required List<_LineRequest> lines,
    required Map<String, ItemRead> items,
    required String? notes,
  }) {
    final List<CountedIntakeLineInput> inputs = <CountedIntakeLineInput>[];
    for (final _LineRequest line in lines) {
      final ItemRead? item = items[line.itemId];
      if (item == null) {
        return const Failure<ValidatedCountedIntake>(
          ValidationError('FR-M6-04'),
        );
      }
      inputs.add(
        CountedIntakeLineInput(
          itemId: line.itemId,
          itemName: item.name,
          unit: item.unit,
          quantity: line.quantity,
          note: line.note,
        ),
      );
    }
    return validateCountedIntake(
      CountedIntakeInput(
        sourceId: sourceId,
        // ★★ **من سجل المصدر لا من الحمولة** — `FR-M2-02`: ⟵ **وإلا أعلن
        //   العميلُ أن المصدر لا يشترط رعوياً فتخطّى الشرط.**
        sourceRequiresSupplier: source?['requiresSupplierOnIntake'] == true,
        supplierId: supplierId,
        notes: notes,
        lines: inputs,
      ),
    );
  }

  // ★ **الأربعة أدناه تُفوِّض إلى الدوال المشتركة أعلى الملف** — ⟵ **فقاعدةٌ
  //   واحدة لا نسختان**، ⛔ **ولا يبقى شرطُ `stockDate` مكتوباً مرتين.**

  static DocumentQuery _ledgerQuery({
    required String sourceId,
    required String itemKey,
    required CalendarDay day,
  }) =>
      inventoryLedgerQuery(sourceId: sourceId, itemKey: itemKey, day: day);

  static CalendarDay? _platformDay(TransactionReads reads) =>
      platformDayOf(reads);

  /// ★★ حركات الدفتر لكل نوع — **بوحدة كل نوع المخزَّنة**.
  ///
  /// ⚠️ **وأنواعُ هذه الوحدة كلها بالحبّة** (`FR-M6-10`)، ★ **والوحدة
  /// تُمرَّر مع ذلك من سجل النوع** ⛔ **لا تُفترَض**: `_planIntake` يرفض
  /// ما ليس حبّة صراحةً، ⟵ **فالافتراض هنا كان سيُخفي ذلك الرفض.**
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

  static Map<String, ItemRead> _itemsOf(
    TransactionReads reads,
    Map<String, String> itemPaths,
  ) =>
      readItemRecords(reads, itemPaths);

  static String? _nameOf(Map<String, Object?>? data) => readStoredName(data);

  static List<String>? _sourceIdsOf(Map<String, Object?>? data) =>
      readSourceIds(data);

  static Set<String> _storedItemKeys(Map<String, Object?> document) {
    final Object? lines = document['lines'];
    if (lines is! List<Object?>) return <String>{};
    return <String>{
      for (final Object? line in lines)
        if (line is Map<String, Object?>)
          // ★ **والسطر يحمل `itemId`** — وهو `itemKey` نفسه في هذه الوحدة
          //   (`FR-M6-09`). ⚠️ **و`itemKey` يُقرأ احتياطاً** لأي مستندٍ
          //   كُتب بصيغةٍ أقدم، ⛔ **ولا يُسقَط السطر بصمت.**
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
      final int? quantity = _intOf(entry['quantity']);
      if (itemId is! String || itemId.trim().isEmpty || quantity == null) {
        return null;
      }
      final Object? note = entry['note'];
      lines.add(
        _LineRequest(
          itemId: itemId.trim(),
          quantity: quantity,
          note: note is String ? note : null,
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

  static int? _intOf(Object? raw) => readInt(raw);


  /// ★ رقمٌ نائب **لفحص البوابة قبل تخصيص الرقم** — ⛔ ولا يُكتب أبداً.
  static const String _pendingDocumentNumber = 'pending';
}

/// سطرٌ كما وصل في الحمولة — ⛔ **بلا اسمٍ ولا وحدة**: كلاهما من القاعدة.
final class _LineRequest {
  const _LineRequest({
    required this.itemId,
    required this.quantity,
    required this.note,
  });

  final String itemId;
  final int quantity;
  final String? note;
}

/// ★ انقلاب اليوم بين اقتراح الحاوية وحكم المنصّة — راجع ترويسة الملف.
final class _DayMismatch {
  const _DayMismatch(this.observed);

  /// اليوم كما أعلنته المنصّة.
  final CalendarDay observed;
}

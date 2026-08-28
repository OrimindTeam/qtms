/// بدائل اختبارية للمخزون — ★ **فلا اختبار يمسّ سحابة ولا شبكة**
/// (`ADR-0010`: حقن اعتمادية صريح · `test-strategy.md`).
library;

import 'dart:async';

import 'package:qtms_domain/qtms_domain.dart';

/// دليل مخزون يُتحكَّم به — ★ **والخطأ يُبثّ كخطأ لا كقائمة فارغة**،
/// ⟵ **فيُختبَر تمييز الشاشة بين «ممنوع» و«لا يوجد».**
final class FakeInventoryDirectory implements InventoryDirectory {
  final StreamController<List<ItemDailyBalanceCard>> _stock =
      StreamController<List<ItemDailyBalanceCard>>.broadcast();
  final StreamController<List<StockMovementCard>> _movements =
      StreamController<List<StockMovementCard>>.broadcast();
  final StreamController<List<CountedIntakeCard>> _intakes =
      StreamController<List<CountedIntakeCard>>.broadcast();

  List<ItemDailyBalanceCard>? _currentStock;
  List<StockMovementCard>? _currentMovements;
  List<CountedIntakeCard>? _currentIntakes;
  Object? _stockError;

  /// ★ آخر تاريخ مخزون طُلب — ⛔ **يُثبت أن الشاشة تستعلم على `stockDate`**.
  CalendarDay? lastStockDate;

  /// آخر مصدر طُلب.
  String? lastSourceId;

  /// يبثّ الأرصدة.
  void emitStock(List<ItemDailyBalanceCard> value) {
    _currentStock = value;
    _stock.add(value);
  }

  /// ★ يبثّ رفضاً — ⛔ **لا قائمة فارغة**.
  void emitStockError(Object error) {
    _stockError = error;
    _stock.addError(error);
  }

  /// يبثّ حركات نوع.
  void emitMovements(List<StockMovementCard> value) {
    _currentMovements = value;
    _movements.add(value);
  }

  /// يبثّ مستندات الوارد.
  void emitIntakes(List<CountedIntakeCard> value) {
    _currentIntakes = value;
    _intakes.add(value);
  }

  /// ⚠️ **يُغلِق بلا انتظار عمداً** — بنفس سبب `FakeMasterDataDirectory.dispose`.
  void dispose() {
    unawaited(_stock.close());
    unawaited(_movements.close());
    unawaited(_intakes.close());
  }

  @override
  Stream<List<ItemDailyBalanceCard>> watchTodayStock({
    required String sourceId,
    required CalendarDay stockDate,
  }) async* {
    lastSourceId = sourceId;
    lastStockDate = stockDate;
    if (_stockError case final Object error) {
      yield* Stream<List<ItemDailyBalanceCard>>.error(error);
    }
    if (_currentStock case final List<ItemDailyBalanceCard> value) yield value;
    yield* _stock.stream;
  }

  @override
  Stream<List<StockMovementCard>> watchItemMovements({
    required String sourceId,
    required String itemKey,
    required CalendarDay stockDate,
  }) async* {
    lastStockDate = stockDate;
    if (_currentMovements case final List<StockMovementCard> value) yield value;
    yield* _movements.stream;
  }

  @override
  Stream<List<CountedIntakeCard>> watchCountedIntakes({
    required String sourceId,
    required CalendarDay stockDate,
  }) async* {
    lastSourceId = sourceId;
    lastStockDate = stockDate;
    if (_currentIntakes case final List<CountedIntakeCard> value) yield value;
    yield* _intakes.stream;
  }
}

/// مستودع كتابة مخزون يُتحكَّم به — ★ **يسجّل ما أُرسل حرفياً**.
final class FakeInventoryAdmin implements InventoryAdminRepository {
  /// آخر مستند أُرسل.
  ValidatedCountedIntake? lastIntake;

  /// آخر سبب تعديل أُرسل.
  String? lastAmendReason;

  /// آخر سبب إلغاء أُرسل.
  String? lastCancelReason;

  /// آخر رقم مستند أُرسل.
  String? lastDocumentNumber;

  /// آخر مصدر أُرسل مع الإلغاء.
  String? lastCancelSourceId;

  /// عدد الاستدعاءات — يُثبت أن الزر يفعل شيئاً.
  int calls = 0;

  /// النتيجة المُعادة — ★ **يُضبَط لاختبار عرض الرفض**.
  AppError? failure;

  Outcome<void> get _void =>
      failure == null ? const Success<void>(null) : Failure<void>(failure!);

  @override
  Future<Outcome<String>> createCountedIntake(
    ValidatedCountedIntake intake,
  ) async {
    calls++;
    lastIntake = intake;
    return failure == null
        ? const Success<String>('INC-20260825-0001')
        : Failure<String>(failure!);
  }

  @override
  Future<Outcome<void>> amendCountedIntake({
    required String documentNumber,
    required ValidatedCountedIntake intake,
    String? amendReason,
  }) async {
    calls++;
    lastIntake = intake;
    lastAmendReason = amendReason;
    lastDocumentNumber = documentNumber;
    return _void;
  }

  @override
  Future<Outcome<void>> cancelCountedIntake({
    required String documentNumber,
    required String sourceId,
    String? cancelReason,
  }) async {
    calls++;
    lastDocumentNumber = documentNumber;
    lastCancelSourceId = sourceId;
    lastCancelReason = cancelReason;
    return _void;
  }
}

/// رصيد نوعٍ جاهز للاختبارات.
ItemDailyBalanceCard testBalance({
  String itemKey = 'ITM-0002',
  String itemName = 'عود',
  int incoming = 120,
  int outgoing = 20,
  CalendarDay? stockDate,
}) =>
    ItemDailyBalanceCard(
      sourceId: 'SRC-001',
      itemKey: itemKey,
      itemName: itemName,
      stockDate: stockDate ?? CalendarDay(2026, 8, 25),
      incoming: PieceQuantity(PieceCount(incoming)),
      outgoing: PieceQuantity(PieceCount(outgoing)),
      balance: PieceQuantity(PieceCount(incoming - outgoing)),
    );

/// رصيد وزني جاهز — ★ **لاختبار الإجمالين المنفصلين** (`FR-M8-07`).
ItemDailyBalanceCard testWeightBalance({
  String itemKey = 'ITM-SCRAP',
  String itemName = 'السكرب',
  double kilograms = 2.5,
}) =>
    ItemDailyBalanceCard(
      sourceId: 'SRC-001',
      itemKey: itemKey,
      itemName: itemName,
      stockDate: CalendarDay(2026, 8, 25),
      incoming: WeightQuantity(WeightKg(kilograms)),
      outgoing: const WeightQuantity(WeightKg.zero),
      balance: WeightQuantity(WeightKg(kilograms)),
    );

/// مستند وارد جاهز للاختبارات.
CountedIntakeCard testIntake({
  String documentNumber = 'INC-20260825-0001',
  CountedIntakeStatus status = CountedIntakeStatus.approved,
  int quantity = 120,
  int amendCount = 0,
}) =>
    CountedIntakeCard(
      documentNumber: documentNumber,
      sourceId: 'SRC-001',
      stockDate: CalendarDay(2026, 8, 25),
      entryDate: DateTime.utc(2026, 8, 25, 6),
      status: status,
      totalQuantity: PieceCount(quantity),
      amendCount: amendCount,
      lines: <ValidatedCountedIntakeLine>[
        ValidatedCountedIntakeLine(
          itemId: 'ITM-0002',
          itemName: 'عود',
          quantity: PieceCount(quantity),
          note: null,
        ),
      ],
    );

/// حركة جاهزة للاختبارات.
StockMovementCard testMovement({
  bool isCancelled = false,
  bool isAmended = false,
  int quantity = 120,
  MovementDirection direction = MovementDirection.incoming,
}) =>
    StockMovementCard(
      movementId: 'INC-20260825-0001_ITM-0002',
      itemKey: 'ITM-0002',
      itemName: 'عود',
      direction: direction,
      quantity: PieceQuantity(PieceCount(quantity)),
      balanceAfter: PieceQuantity(PieceCount(quantity)),
      sourceDocumentType: SourceDocumentType.countedIntake,
      sourceDocumentNumber: 'INC-20260825-0001',
      entryDate: DateTime.utc(2026, 8, 25, 6),
      isCancelled: isCancelled,
      isAmended: isAmended,
    );

// ═════════════════════════════════════════════════════════════════════════
// التسعير اليومي (`WU-005`)
// ═════════════════════════════════════════════════════════════════════════

/// دليل تسعير يُتحكَّم به — ★ **ويسجّل اليوم الذي طُلب**، ⛔ **فيُثبت أن
/// الشاشة تستعلم على يوم واحد** (`FR-M9-01` · `GR-31`).
final class FakeDailyPricingDirectory implements DailyPricingDirectory {
  final Map<String, StreamController<List<DailyPriceCard>>> _byDay =
      <String, StreamController<List<DailyPriceCard>>>{};
  final Map<String, List<DailyPriceCard>> _current =
      <String, List<DailyPriceCard>>{};
  Object? _error;

  /// ★ كل الأيام التي استُعلم عنها — ⛔ **يُثبت أنها اليوم وأمسِه لا سواهما**.
  final List<CalendarDay> requestedDays = <CalendarDay>[];

  /// آخر مصدر طُلب.
  String? lastSourceId;

  /// يبثّ أسعار يوم.
  void emitPrices(CalendarDay day, List<DailyPriceCard> value) {
    _current[day.format()] = value;
    _controllerFor(day).add(value);
  }

  /// ★ يبثّ رفضاً — ⛔ **لا قائمة فارغة**.
  void emitError(Object error) => _error = error;

  /// ⚠️ **يُغلِق بلا انتظار عمداً** — بنفس سبب [FakeInventoryDirectory.dispose].
  void dispose() {
    for (final StreamController<List<DailyPriceCard>> c in _byDay.values) {
      unawaited(c.close());
    }
  }

  StreamController<List<DailyPriceCard>> _controllerFor(CalendarDay day) =>
      _byDay.putIfAbsent(
        day.format(),
        StreamController<List<DailyPriceCard>>.broadcast,
      );

  @override
  Stream<List<DailyPriceCard>> watchDailyPrices({
    required String sourceId,
    required CalendarDay date,
  }) async* {
    lastSourceId = sourceId;
    requestedDays.add(date);
    if (_error case final Object error) {
      yield* Stream<List<DailyPriceCard>>.error(error);
    }
    if (_current[date.format()] case final List<DailyPriceCard> value) {
      yield value;
    } else {
      // ⚠️ **يومٌ بلا سجلات قائمةٌ فارغة لا انتظارٌ أبدي** — ★ **وهو الحال
      //    الطبيعي كل صباح** (`FR-M9-01`: كل يوم يبدأ بلا أسعار).
      yield const <DailyPriceCard>[];
    }
    yield* _controllerFor(date).stream;
  }
}

/// مستودع كتابة أسعار يُتحكَّم به — ★ **يسجّل ما أُرسل حرفياً**.
final class FakeDailyPricingRepository implements DailyPricingRepository {
  /// آخر دفعة أُرسلت.
  ValidatedDailyPriceBatch? lastBatch;

  /// ★ آخر سبب أُرسل — ⛔ **و`null` تعني أنه لم يُرسَل أصلاً**.
  String? lastReason;

  /// عدد الاستدعاءات — يُثبت أن الزر يفعل شيئاً.
  int calls = 0;

  /// النتيجة المُعادة — ★ **يُضبَط لاختبار عرض الرفض**.
  AppError? failure;

  @override
  Future<Outcome<void>> writeDailyPrices({
    required ValidatedDailyPriceBatch batch,
    String? amendReason,
  }) async {
    calls++;
    lastBatch = batch;
    lastReason = amendReason;
    return failure == null
        ? const Success<void>(null)
        : Failure<void>(failure!);
  }
}

/// بطاقة سعر جاهزة للاختبارات.
DailyPriceCard testPrice({
  String itemKey = 'ITM-0002',
  String itemName = 'عود',
  ItemUnit unit = ItemUnit.piece,
  int? distribution = 1200,
  int? minimum = 1000,
  CalendarDay? date,
}) =>
    DailyPriceCard(
      sourceId: 'SRC-001',
      itemKey: itemKey,
      itemName: itemName,
      unit: unit,
      date: date ?? CalendarDay(2026, 8, 25),
      distributionPrice: distribution == null ? null : Money(distribution),
      minCashPrice: minimum == null ? null : Money(minimum),
    );

/// بدائل اختبارية للجواني — ★ **فلا اختبار يمسّ سحابة ولا شبكة**
/// (`ADR-0010`: حقن اعتمادية صريح · `test-strategy.md`).
library;

import 'dart:async';

import 'package:qtms_domain/qtms_domain.dart';

/// دليل جواني يُتحكَّم به.
final class FakeSackDirectory implements SackDirectory {
  final StreamController<List<SackCard>> _sacks =
      StreamController<List<SackCard>>.broadcast();
  final StreamController<SackFinanceCard?> _finance =
      StreamController<SackFinanceCard?>.broadcast();

  List<SackCard>? _current;
  SackFinanceCard? _currentFinance;
  Object? _error;

  /// ★ آخر تاريخ مخزون طُلب — ⛔ **يُثبت أن الشاشة تستعلم على `stockDate`**.
  CalendarDay? lastStockDate;

  /// آخر مصدر طُلب.
  String? lastSourceId;

  /// يبثّ الجواني.
  void emitSacks(List<SackCard> value) {
    _current = value;
    _sacks.add(value);
  }

  /// ★ يبثّ رفضاً — ⛔ **لا قائمة فارغة**.
  void emitError(Object error) {
    _error = error;
    _sacks.addError(error);
  }

  /// يبثّ مالية جونية.
  void emitFinance(SackFinanceCard? value) {
    _currentFinance = value;
    _finance.add(value);
  }

  /// ★★ يبثّ ماليةَ **جونيةٍ بعينها** — ⟵ **فشاشةٌ تعرض عدّة جوانٍ تُقاس
  /// بأرقامٍ مختلفة لكلٍّ منها** (`WU-015`)، ⛔ **لا برقمٍ واحدٍ للجميع.**
  void emitFinanceFor(String sackId, SackFinanceCard? value) {
    _financeBySack[sackId] = value;
  }

  final Map<String, SackFinanceCard?> _financeBySack =
      <String, SackFinanceCard?>{};

  /// ⚠️ **يُغلِق بلا انتظار عمداً** — بنفس سبب بقية البدائل.
  void dispose() {
    unawaited(_sacks.close());
    unawaited(_finance.close());
  }

  @override
  Stream<List<SackCard>> watchSacks({
    required String sourceId,
    required CalendarDay stockDate,
  }) async* {
    lastSourceId = sourceId;
    lastStockDate = stockDate;
    if (_error case final Object error) {
      yield* Stream<List<SackCard>>.error(error);
    }
    if (_current case final List<SackCard> value) yield value;
    yield* _sacks.stream;
  }

  @override
  Stream<SackFinanceCard?> watchSackFinance({required String sackId}) async* {
    // ★ **وماليةُ جونيةٍ بعينها تسبق العامة** — راجع [emitFinanceFor].
    if (_financeBySack.containsKey(sackId)) {
      yield _financeBySack[sackId];
      return;
    }
    yield _currentFinance;
    yield* _finance.stream;
  }
}

/// مستودع كتابة جواني يُسجّل ما وصله — ★ **فيُقاس ما تُمرِّره الشاشة**.
final class FakeSackAdmin implements SackAdminRepository {
  /// آخر جونية طُلب إنشاؤها.
  ValidatedSackIntake? createdSack;

  /// آخر سطور طُلب إدخالها.
  List<ValidatedSackLine>? enteredLines;

  /// آخر سبب مُرسَل مع السطور.
  String? linesReason;

  /// آخر ضريبة كيلو مُرسَلة.
  Money? enteredTax;

  /// آخر اسم ظاهر مُرسَل.
  String? renamedTo;

  /// آخر وزن سكرب مُرسَل.
  WeightKg? enteredScrapWeight;

  /// ★ عدد مرات تأكيد الوزن الضائع — ⛔ **ويجب ألّا يقع ضمناً** (`BR-M7-12`).
  int lostWeightConfirmations = 0;

  /// آخر سبب إلغاء.
  String? cancelReason;

  /// ★★ **عدد نداءات الإلغاء** — ⟵ **لتمييز «لم يُنادَ» من «نُودي بلا سبب»**
  /// بعد `ADR-0020`، ★ **إذ صار `cancelReason == null` حالةً مشروعة.**
  int cancelCalls = 0;

  /// ★ الرفض الذي تُرجِعه كل عملية — `null` تعني نجاحاً.
  AppError? rejection;

  Outcome<void> get _result => rejection == null
      ? const Success<void>(null)
      : Failure<void>(rejection!);

  @override
  Future<Outcome<String>> createSack(ValidatedSackIntake intake) async {
    createdSack = intake;
    return rejection == null
        ? const Success<String>('SCK-20260826-0001')
        : Failure<String>(rejection!);
  }

  @override
  Future<Outcome<void>> enterSackLines({
    required String documentNumber,
    required String sourceId,
    required List<ValidatedSackLine> lines,
    String? amendReason,
  }) async {
    enteredLines = lines;
    linesReason = amendReason;
    return _result;
  }

  @override
  Future<Outcome<void>> enterSackTax({
    required String documentNumber,
    required String sourceId,
    required Money taxPerKilo,
    String? amendReason,
  }) async {
    enteredTax = taxPerKilo;
    return _result;
  }

  @override
  Future<Outcome<void>> renameSack({
    required String documentNumber,
    required String sourceId,
    required String displayName,
    String? amendReason,
  }) async {
    renamedTo = displayName;
    return _result;
  }

  @override
  Future<Outcome<void>> enterSackScrapWeight({
    required String documentNumber,
    required String sourceId,
    required WeightKg scrapWeight,
    String? amendReason,
  }) async {
    enteredScrapWeight = scrapWeight;
    return _result;
  }

  @override
  Future<Outcome<void>> confirmSackLostWeight({
    required String documentNumber,
    required String sourceId,
    String? lostWeightNote,
  }) async {
    lostWeightConfirmations++;
    return _result;
  }

  @override
  Future<Outcome<void>> amendSack({
    required String documentNumber,
    required ValidatedSackIntake intake,
    String? amendReason,
  }) async {
    createdSack = intake;
    return _result;
  }

  @override
  Future<Outcome<void>> cancelSack({
    required String documentNumber,
    required String sourceId,
    String? cancelReason,
  }) async {
    cancelCalls++;
    this.cancelReason = cancelReason;
    return _result;
  }
}

/// ★ جونية جاهزة للاختبارات — **بأوزان `AT-06`**.
SackCard testSack({
  String documentNumber = 'SCK-20260826-0001',
  String sourceId = 'SRC-001',
  int dailySequence = 1,
  double total = 45,
  double ice = 6.5,
  double scrap = 1.2,
  List<ValidatedSackLine> lines = const <ValidatedSackLine>[],
  SackStatus status = SackStatus.approved,
  bool lostWeightConfirmed = false,
  String? supplierName = 'عبدالفتاح',
  required CalendarDay stockDate,
}) {
  final ValidatedSackWeights weights = ValidatedSackWeights(
    totalWeight: WeightKg(total),
    iceWeight: WeightKg(ice),
    scrapWeight: WeightKg(scrap),
  );
  return SackCard(
    documentNumber: documentNumber,
    sourceId: sourceId,
    stockDate: stockDate,
    entryDate: DateTime.utc(2026, 8, 26),
    dailySequence: dailySequence,
    displayName: sackDisplayName(
      dailySequence: dailySequence,
      supplierName: supplierName,
    ),
    status: status,
    weights: weights,
    // ★★ **والحاسبة من طبقة النطاق** — ⛔ **ولا قيمةٌ محفورة في البديل**:
    //    ⟵ **وإلا اختُبرت الشاشة على رقمٍ لا تُنتجه المعادلة.**
    explanation: explainSackWeight(
      weights: weights,
      lines: lines,
      lostWeightConfirmed: lostWeightConfirmed,
    ),
    lostWeightConfirmed: lostWeightConfirmed,
    lines: lines,
    supplierId: supplierName == null ? null : 'SUP-0001',
    supplierName: supplierName,
  );
}

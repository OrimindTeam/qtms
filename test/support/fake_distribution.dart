/// بدائل التوزيع للاختبار — ★ **بلا سحابة ولا شبكة** (`ADR-0010`).
///
/// ⚠️⚠️ **وتدفّقان منفصلان عمداً** (`ADR-0011`): **الأب** و**الأسعار** —
/// ⟵ **فيُختبَر `ت-12` كما يقع فعلاً**: ★ **الأسعار تغيب عمّن لا يملكها
/// بينما يبقى المستند ظاهراً**، ⛔ **لا حقلٌ `null` في نوعٍ واحد.**
library;

import 'dart:async';

import 'package:qtms_domain/qtms_domain.dart';

/// دليل توزيع بديل.
final class FakeDistributionDirectory implements DistributionDirectory {
  final StreamController<List<DistributionCard>> _list =
      StreamController<List<DistributionCard>>.broadcast();
  final StreamController<DistributionPricingCard?> _pricing =
      StreamController<DistributionPricingCard?>.broadcast();
  final StreamController<DealerBalanceCard?> _balance =
      StreamController<DealerBalanceCard?>.broadcast();

  List<DistributionCard> _lastList = const <DistributionCard>[];
  DistributionPricingCard? _lastPricing;
  DealerBalanceCard? _lastBalance;

  /// المعرّفات التي طُلبت لأسعارها — ★ **لإثبات أن الشاشة تستعلم بالمعرّف
  /// المركّب على مستند الأسعار وحده** (`ADR-0011`).
  final List<String> requestedIds = <String>[];

  /// يبثّ قائمة اليوم.
  void emitList(List<DistributionCard> value) {
    _lastList = value;
    _list.add(value);
  }

  /// ★★ يبثّ توزيعةَ المقوت — ⛔ **عبر قائمة اليوم لا بمعرّفها**.
  ///
  /// ⚠️⚠️ **وهذا هو مسار الإنتاج نفسه بعد عطل المحاكي (2026-08-27):**
  /// **القراءة بالمعرّف تُرفَض على المستند الغائب** — ⟵ **فالبديل يُحاكي ما
  /// يقع فعلاً**، ⛔ **ولا يُثبِّت مساراً لا وجود له.**
  void emitOne(DistributionCard? value) {
    emitList(value == null
        ? const <DistributionCard>[]
        : <DistributionCard>[value]);
  }

  /// يبثّ الأسعار — و`null` تعني **«لا أرى» أو «لا يوجد»** معاً (`ت-12`).
  void emitPricing(DistributionPricingCard? value) {
    _lastPricing = value;
    _pricing.add(value);
  }

  @override
  Stream<List<DistributionCard>> watchDistributions({
    required String sourceId,
    required CalendarDay stockDate,
  }) async* {
    yield _lastList;
    yield* _list.stream;
  }

  @override
  Stream<DistributionPricingCard?> watchDistributionPricing({
    required String distributionId,
  }) async* {
    requestedIds.add(distributionId);
    yield _lastPricing;
    yield* _pricing.stream;
  }

  /// ★ يبثّ رصيد المقوت — و`null` تعني **«لا أرى» أو «لا يوجد»** معاً
  /// (نفس عقد الأسعار — `WU-010`).
  void emitBalance(DealerBalanceCard? value) {
    _lastBalance = value;
    _balance.add(value);
  }

  @override
  Stream<DealerBalanceCard?> watchDealerBalance({
    required String dealerId,
    required String sourceId,
  }) async* {
    yield _lastBalance;
    yield* _balance.stream;
  }

  /// يغلق التدفّقات.
  void dispose() {
    _list.close();
    _pricing.close();
    _balance.close();
  }
}

/// مستودع كتابة بديل — ★ **يحفظ آخر حمولة لتُفحَص**.
final class FakeDistributionAdmin implements DistributionAdminRepository {
  /// آخر توزيعة أُرسلت للإنشاء أو التعديل.
  ValidatedDistribution? lastDistribution;

  /// آخر سبب تعديل أُرسل — ⛔ **ولا يُعبَّأ آلياً** (`ADR-0004`).
  String? lastAmendReason;

  /// آخر سبب إلغاء أُرسل.
  String? lastCancelReason;

  /// عدد استدعاءات الإنشاء.
  int createCalls = 0;

  /// عدد استدعاءات التعديل.
  int amendCalls = 0;

  /// عدد استدعاءات الإلغاء.
  int cancelCalls = 0;

  /// رفضٌ مُبرمَج — ★ **لاختبار عرض رسالة الكتالوج**.
  AppError? rejection;

  /// ★★ تاريخُ المخزون المُرسَل في آخر إنشاء — و`null` **لم يُرسَل** (`WU-019`).
  CalendarDay? lastCreateStockDate;

  @override
  Future<Outcome<String>> createDistribution(
    ValidatedDistribution distribution, {
    CalendarDay? stockDate,
  }) async {
    createCalls++;
    lastDistribution = distribution;
    lastCreateStockDate = stockDate;
    final AppError? error = rejection;
    return error == null
        ? const Success<String>('MQT-0001_SRC-001_20260827')
        : Failure<String>(error);
  }

  @override
  Future<Outcome<void>> amendDistribution({
    required String documentNumber,
    required ValidatedDistribution distribution,
    String? amendReason,
  }) async {
    amendCalls++;
    lastDistribution = distribution;
    lastAmendReason = amendReason;
    final AppError? error = rejection;
    return error == null ? const Success<void>(null) : Failure<void>(error);
  }

  @override
  Future<Outcome<void>> cancelDistribution({
    required String documentNumber,
    required String sourceId,
    required String dealerId,
    String? cancelReason,
  }) async {
    cancelCalls++;
    lastCancelReason = cancelReason;
    final AppError? error = rejection;
    return error == null ? const Success<void>(null) : Failure<void>(error);
  }
}

/// بطاقة توزيعة جاهزة للاختبار.
DistributionCard testDistributionCard({
  String dealerId = 'MQT-0001',
  String sourceId = 'SRC-001',
  String dealerName = 'مقوت مثال',
  String documentNumber = 'DST-20260827-0001',
  DistributionStatus status = DistributionStatus.priced,
  int unpricedLineCount = 0,
  int amendCount = 0,
  int quantity = 80,
  String itemId = 'ITM-0002',
  CalendarDay? stockDate,
}) {
  final CalendarDay day = stockDate ?? CalendarDay(2026, 8, 27);
  return DistributionCard(
    distributionId:
        distributionId(dealerId: dealerId, sourceId: sourceId, stockDate: day),
    documentNumber: documentNumber,
    sourceId: sourceId,
    dealerId: dealerId,
    dealerName: dealerName,
    stockDate: day,
    entryDate: DateTime.utc(2026, 8, 27, 6),
    status: status,
    unpricedLineCount: unpricedLineCount,
    totalPieces: PieceCount(quantity),
    totalWeight: WeightKg.zero,
    amendCount: amendCount,
    lines: <ValidatedDistributionLine>[
      ValidatedDistributionLine(
        itemId: itemId,
        itemName: 'عود',
        quantity: PieceQuantity(PieceCount(quantity)),
        sackId: null,
        // ⛔★★ **ولا سعرٌ في المستند الأب** — `ADR-0011`:
        //   ★ **ويصل الشاشةَ من `pricing/current` وحدَه** (`DEBT-87`).
        unitPrice: null,
        note: null,
      ),
    ],
  );
}

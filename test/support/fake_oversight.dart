/// بدائل اختبارية لسجل التدقيق — ★ **فلا اختبار يمسّ سحابة ولا شبكة**
/// (`ADR-0010`: حقن اعتمادية صريح · `test-strategy.md`).
///
/// ⛔⛔★★ **ولا نظيرَ كاتبٍ هنا ولا في الأصل:** `AuditLogDirectory` **عقدُ
/// قراءةٍ محض** (`FR-M18-01` · `FR-M18-04`) — ★ **والبديل يطابقه حرفياً**،
/// ⟵ **فلا يُغري اختبارٌ بكتابة قيدٍ لا مسارَ لها في الإنتاج.**
library;

import 'dart:async';

import 'package:qtms_domain/qtms_domain.dart';

/// دليل سجل تدقيق يُتحكَّم به — ★ **والخطأ يُبثّ كخطأ لا كقائمة فارغة**،
/// ⟵ **فيُختبَر تمييز الشاشة بين «ممنوع» و«لا نشاط»** (`FR-M18-12`).
final class FakeAuditLogDirectory implements AuditLogDirectory {
  final StreamController<List<AuditLogEntryCard>> _central =
      StreamController<List<AuditLogEntryCard>>.broadcast();
  final Map<AuditEntityRef, StreamController<List<AuditLogEntryCard>>> _entity =
      <AuditEntityRef, StreamController<List<AuditLogEntryCard>>>{};

  List<AuditLogEntryCard>? _currentCentral;
  Object? _centralError;
  final Map<AuditEntityRef, List<AuditLogEntryCard>> _currentEntity =
      <AuditEntityRef, List<AuditLogEntryCard>>{};

  /// ★ آخر فلترٍ طُلب — ⛔ **يُثبت أن الشاشة تستعلم بما اختاره المستخدم**
  /// لا بفلترٍ ثابت.
  AuditLogFilter? lastFilter;

  /// ★ آخر كيانٍ فُتح سجلُّه — ⛔ **يُثبت أن الورقة تسأل عن الكيان الصحيح.**
  AuditEntityRef? lastEntity;

  /// ★ آخر حدٍّ طُلب — ⛔ **يُثبت أن السجل لا يُقرأ كاملاً** (`§8`).
  int? lastLimit;

  /// يبثّ قيود الشاشة المركزية.
  void emitCentral(List<AuditLogEntryCard> value) {
    _currentCentral = value;
    _central.add(value);
  }

  /// ★ يبثّ رفضاً — ⛔ **لا قائمة فارغة**.
  void emitCentralError(Object error) {
    _centralError = error;
    _central.addError(error);
  }

  /// يبثّ قيود كيانٍ بعينه.
  void emitEntity(AuditEntityRef entity, List<AuditLogEntryCard> value) {
    _currentEntity[entity] = value;
    _controllerFor(entity).add(value);
  }

  StreamController<List<AuditLogEntryCard>> _controllerFor(
    AuditEntityRef entity,
  ) =>
      _entity.putIfAbsent(
        entity,
        StreamController<List<AuditLogEntryCard>>.broadcast,
      );

  @override
  Stream<List<AuditLogEntryCard>> watchCentralLog({
    required AuditLogFilter filter,
    int limit = auditLogPageSize,
  }) async* {
    lastFilter = filter;
    lastLimit = limit;
    if (_centralError case final Object error) {
      yield* Stream<List<AuditLogEntryCard>>.error(error);
    }
    if (_currentCentral case final List<AuditLogEntryCard> value) yield value;
    yield* _central.stream;
  }

  @override
  Stream<List<AuditLogEntryCard>> watchEntityLog({
    required AuditEntityRef entity,
    int limit = auditLogPageSize,
  }) async* {
    lastEntity = entity;
    lastLimit = limit;
    if (_currentEntity[entity] case final List<AuditLogEntryCard> value) {
      yield value;
    }
    yield* _controllerFor(entity).stream;
  }
}

/// قيدٌ اختباري بأقل ما يلزم — ★ **يُعدَّل في كل اختبار حسب حاجته.**
AuditLogEntryCard testAuditEntry({
  String id = 'REQ-1',
  DateTime? occurredAt,
  String userName = 'عبدالفتاح',
  String? userEmail = 'abdulfattah@example.com',
  AuditAction? action = AuditAction.amend,
  String entityType = 'countedIntake',
  String entityId = 'INC-20260827-0001',
  String sourceId = 'SRC-001',
  String? documentNumber,
  CalendarDay? stockDate,
  Map<String, Object?> before = const <String, Object?>{},
  Map<String, Object?> after = const <String, Object?>{},
  String? reason = 'تصحيح كمية',
}) =>
    AuditLogEntryCard(
      id: id,
      occurredAt: occurredAt ?? DateTime.utc(2026, 8, 27, 9, 15),
      userId: 'U-001',
      userName: userName,
      userEmail: userEmail,
      action: action,
      entityType: entityType,
      entityId: entityId,
      sourceId: sourceId,
      documentNumber: documentNumber,
      stockDate: stockDate,
      valuesBefore: before,
      valuesAfter: after,
      reason: reason,
    );

/// ★★ دليل تقارير يُتحكَّم به — `WU-011`.
///
/// ⛔⛔★★ **ويُسجِّل ما طُلب منه** — ★ **فيُثبت الاختبار أن الشاشة تستعلم
/// بالمصدر والفترة اللذين اختارهما المستخدم** ⛔ **لا بثابتٍ في الكود**،
/// ⟵ **وأن «كل المصادر» تُعدَّد مصادرَ لا تصل غياباً** (`IQ-024` · `DEBT-40`).
final class FakeReportDirectory implements ReportDirectory {
  /// المصادر التي استُعلم بها بالترتيب.
  final List<String> requestedSources = <String>[];

  /// آخر فترةٍ طُلبت.
  ReportPeriod? lastPeriod;

  /// آخر حالةِ تسويةٍ طُلبت.
  SettlementStatus? lastSettlementStatus;

  /// ★ هل طُلبت الأسعار؟ — ⛔ **ولا تُطلَب بلا `distributionPriceView`.**
  bool pricingRequested = false;

  /// ★ هل طُلبت حالاتُ الإيداع؟ — ⛔ **ولا تُطلَب بلا `receiptDepositView`.**
  bool depositsRequested = false;

  /// ما يردّه الدليل لكل دالة.
  List<StockMovementCard> movements = const <StockMovementCard>[];

  /// أرصدةُ اليوم.
  List<ItemDailyBalanceCard> balances = const <ItemDailyBalanceCard>[];

  /// مستنداتُ الوارد عدداً.
  List<CountedIntakeCard> intakes = const <CountedIntakeCard>[];

  /// الجواني.
  List<SackCard> sackCards = const <SackCard>[];

  /// التوزيعات.
  List<DistributionCard> distributionCards = const <DistributionCard>[];

  /// أسعارُ التوزيعات.
  Map<String, DistributionPricingCard> pricing =
      const <String, DistributionPricingCard>{};

  /// السندات.
  List<ReceiptCard> receiptCards = const <ReceiptCard>[];

  /// حالاتُ الإيداع.
  Map<String, DepositState> deposits = const <String, DepositState>{};

  /// أرصدةُ المقاوته.
  List<DealerBalanceCard> dealerBalanceCards = const <DealerBalanceCard>[];

  /// قيودُ كشف الحساب.
  List<DealerLedgerRowCard> statement = const <DealerLedgerRowCard>[];

  /// بنودُ المركز المعلّق.
  List<PendingEntryCard> pending = const <PendingEntryCard>[];

  /// ★ خطأٌ يُرمى بدل النتيجة — **لاختبار حالة الرفض**.
  ///
  /// ⚠️ **ونوعُه `Exception` لا `Object`** — `only_throw_errors`
  /// (`analysis_options.yaml`): ★ **والرفضُ في الإنتاج استثناءُ منصّة
  /// (`FirebaseException`)** ⟵ **فهو النوع نفسُه صنفاً.**
  Exception? failure;

  /// ★★ تأخيرٌ اختياريٌّ قبل الردّ — **لإبقاء إعادة الحساب معلّقةً في اختبار**.
  ///
  /// ⛔⛔ **وبه وحده يُقاس `DEBT-74`:** ★ **أن الشاشة لا تعرض جدولَ التقرير
  /// السابق بينما يُبنى الجديد** — ⟵ **وبلا تأخيرٍ يكتمل المستقبل في نفس
  /// النبضة** ⛔ **فلا تقع النافذة التي فيها العطل أصلاً.**
  Duration? delay;

  /// ★ ينتظر [delay] إن وُجد — **قبل كل ردّ**.
  Future<void> _settle() async {
    if (delay case final Duration wait) await Future<void>.delayed(wait);
  }

  void _record(String sourceId, ReportPeriod period) {
    requestedSources.add(sourceId);
    lastPeriod = period;
    if (failure case final Exception error) throw error;
  }

  @override
  Future<List<StockMovementCard>> itemMovements({
    required String sourceId,
    required String itemKey,
    required ReportPeriod period,
    int limit = reportPageSize,
  }) async {
    _record(sourceId, period);
    await _settle();
    return movements;
  }

  @override
  Future<List<ItemDailyBalanceCard>> dailyBalances({
    required String sourceId,
    required CalendarDay stockDate,
  }) async {
    _record(sourceId, ReportPeriod.singleDay(stockDate));
    await _settle();
    return balances;
  }

  @override
  Future<List<CountedIntakeCard>> countedIntakes({
    required String sourceId,
    required ReportPeriod period,
    int limit = reportPageSize,
  }) async {
    _record(sourceId, period);
    await _settle();
    return intakes;
  }

  @override
  Future<List<SackCard>> sacks({
    required String sourceId,
    required ReportPeriod period,
    int limit = reportPageSize,
  }) async {
    _record(sourceId, period);
    await _settle();
    return sackCards;
  }

  @override
  Future<List<DistributionCard>> distributions({
    required String sourceId,
    required ReportPeriod period,
    SettlementStatus? settlementStatus,
    int limit = reportPageSize,
  }) async {
    _record(sourceId, period);
    await _settle();
    lastSettlementStatus = settlementStatus;
    return distributionCards;
  }

  @override
  Future<Map<String, DistributionPricingCard>> distributionPricing({
    required List<String> distributionIds,
  }) async {
    pricingRequested = true;
    return pricing;
  }

  @override
  Future<List<ReceiptCard>> receipts({
    required String sourceId,
    required ReportPeriod period,
    int limit = reportPageSize,
  }) async {
    _record(sourceId, period);
    await _settle();
    return receiptCards;
  }

  @override
  Future<Map<String, DepositState>> receiptDeposits({
    required List<String> documentNumbers,
  }) async {
    depositsRequested = true;
    return deposits;
  }

  @override
  Future<List<DealerBalanceCard>> dealerBalances({
    required String sourceId,
    int limit = reportPageSize,
  }) async {
    requestedSources.add(sourceId);
    if (failure case final Exception error) throw error;
    return dealerBalanceCards;
  }

  @override
  Future<List<DealerLedgerRowCard>> dealerStatement({
    required String dealerId,
    required String sourceId,
    required ReportPeriod period,
    int limit = reportPageSize,
  }) async {
    _record(sourceId, period);
    await _settle();
    return statement;
  }

  @override
  Future<List<PendingEntryCard>> pendingEntries({
    required String sourceId,
    required ReportPeriod period,
    int limit = reportPageSize,
  }) async {
    _record(sourceId, period);
    await _settle();
    return pending;
  }
}

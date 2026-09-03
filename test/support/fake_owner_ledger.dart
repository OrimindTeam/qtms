/// بدائل ضمار المالك وحركة النقد للاختبار — `WU-016`.
///
/// ⛔ **بلا سحابة ولا شبكة** (`ADR-0010`) — ★ **والمستودعات تُحقَن في الجذر**.
library;

import 'dart:async';

import 'package:qtms_domain/qtms_domain.dart';

/// دليلُ ملخصات مزيَّف — **يبثّ ما يُوضَع فيه**.
final class FakeOwnerLedgerDirectory implements OwnerLedgerDirectory {
  final Map<String, StreamController<OwnerLedgerSummary?>> _summaries =
      <String, StreamController<OwnerLedgerSummary?>>{};
  final Map<String, StreamController<List<OwnerLedgerTrendPoint>>> _trends =
      <String, StreamController<List<OwnerLedgerTrendPoint>>>{};
  final Map<String, List<OwnerLedgerSummary>> _ranges =
      <String, List<OwnerLedgerSummary>>{};

  /// ★ يضع ملخّصَ مصدرٍ — و`null` تعني **يومٌ بلا ملخّصٍ مكتوب**.
  void emitSummary(String sourceId, OwnerLedgerSummary? summary) =>
      _controllerFor(sourceId).add(summary);

  /// ★ يضع سلسلةَ مصدر.
  void emitTrend(String sourceId, List<OwnerLedgerTrendPoint> points) =>
      _trendFor(sourceId).add(points);

  /// ★ يضع سجلَّ مدىً لمصدر.
  void emitRange(String sourceId, List<OwnerLedgerSummary> summaries) =>
      _ranges[sourceId] = summaries;

  StreamController<OwnerLedgerSummary?> _controllerFor(String sourceId) =>
      _summaries.putIfAbsent(
        sourceId,
        StreamController<OwnerLedgerSummary?>.broadcast,
      );

  StreamController<List<OwnerLedgerTrendPoint>> _trendFor(String sourceId) =>
      _trends.putIfAbsent(
        sourceId,
        StreamController<List<OwnerLedgerTrendPoint>>.broadcast,
      );

  @override
  Stream<OwnerLedgerSummary?> watchSummary({
    required String sourceId,
    required CalendarDay date,
  }) =>
      _controllerFor(sourceId).stream;

  @override
  Stream<List<OwnerLedgerTrendPoint>> watchTrend({required String sourceId}) =>
      _trendFor(sourceId).stream;

  @override
  Stream<List<OwnerLedgerSummary>> watchSummaryRange({
    required String sourceId,
    required CalendarDay from,
    required CalendarDay to,
  }) =>
      Stream<List<OwnerLedgerSummary>>.value(
        _ranges[sourceId] ?? const <OwnerLedgerSummary>[],
      );
}

/// قارئُ حركة نقدٍ مزيَّف — ★ **ويُسجِّل ما طُلب منه**.
final class FakeCashMovementReader implements CashMovementReader {
  /// ينشئ القارئ.
  FakeCashMovementReader({CashMovementSummary? result}) : _result = result;

  CashMovementSummary? _result;

  /// المصادرُ في آخر نداء — ★ **لإثبات أن النطاق يُمرَّر كما هو.**
  List<String>? lastSourceIds;

  /// هل طُلب الفائضُ العام في آخر نداء؟
  bool? lastIncludesUnscopedSurplus;

  /// هل طُلبت حالةُ الإيداع في آخر نداء؟
  bool? lastReadsDeposit;

  /// يضع النتيجة.
  set result(CashMovementSummary value) => _result = value;

  @override
  Future<CashMovementSummary> readCashMovement({
    required List<String> sourceIds,
    required bool includesUnscopedSurplus,
    required CalendarDay date,
    required bool readsDeposit,
  }) async {
    lastSourceIds = sourceIds;
    lastIncludesUnscopedSurplus = includesUnscopedSurplus;
    lastReadsDeposit = readsDeposit;
    return _result ??
        computeCashMovement(
          date: date,
          contributions: const CashMovementContributions(),
        );
  }
}

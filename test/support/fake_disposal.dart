/// بدائل الإتلاف للاختبار — ★ **بلا سحابة ولا شبكة** (`ADR-0010`).
///
/// ⛔⛔★★★ **ولا حقلَ ماليٍّ في أيٍّ من هذه الأنواع** (`FR-M8-16`) — ★ **وهو
/// ما يجعل اختبارَ «لا قيمةَ للمُتلَف» ممكناً بفحص العقد نفسِه** ⛔ **لا
/// بفحص ما إذا كانت الشاشة أخفت حقلاً.**
library;

import 'dart:async';

import 'package:qtms_domain/qtms_domain.dart';

/// دليل إتلافٍ بديل.
final class FakeDisposalDirectory implements DisposalDirectory {
  final StreamController<List<DisposalCard>> _cards =
      StreamController<List<DisposalCard>>.broadcast();

  List<DisposalCard> _last = const <DisposalCard>[];

  /// ★★★ **المصادر التي وصلت الدليل** — ★ **لإثبات أن الاستعلام يُقيّد
  /// `sourceId`** ⛔ **واستعلامٌ لا يُقيّده يُرفَض كاملاً** (`IQ-024`).
  final List<String> requested = <String>[];

  /// يبثّ المستندات.
  void emit(List<DisposalCard> value) {
    _last = value;
    _cards.add(value);
  }

  @override
  Stream<List<DisposalCard>> watchDisposals({
    required String sourceId,
    int limit = 100,
  }) async* {
    requested.add(sourceId);
    yield _last;
    yield* _cards.stream;
  }

  /// يغلق التدفّقات.
  void dispose() => _cards.close();
}

/// مستودع كتابة بديل — ★ **يسجّل ما طُلب منه** ⛔ **ولا يكتب.**
final class FakeDisposalAdminRepository implements DisposalAdminRepository {
  /// المستندات المطلوب إنشاؤها.
  final List<CreatedDisposal> created = <CreatedDisposal>[];

  /// النتيجة التالية — ★ **لاختبار مسار الرفض كما يصل من السحابة.**
  Outcome<String> nextResult = const Success<String>('DSP-20260904-0001');

  @override
  Future<Outcome<String>> createDisposal({
    required String sourceId,
    List<DisposalLineInput> lines = const <DisposalLineInput>[],
    CalendarDay? stockDate,
    String? reason,
  }) async {
    created.add(
      CreatedDisposal(
        sourceId: sourceId,
        lines: lines,
        stockDate: stockDate,
        reason: reason,
      ),
    );
    return nextResult;
  }

  @override
  Future<Outcome<void>> amendDisposal({
    required String documentNumber,
    required String sourceId,
    List<DisposalLineInput> lines = const <DisposalLineInput>[],
    String? amendReason,
  }) async =>
      const Success<void>(null);

  @override
  Future<Outcome<void>> cancelDisposal({
    required String documentNumber,
    required String sourceId,
    String? cancelReason,
  }) async =>
      const Success<void>(null);
}

/// ★ طلبُ إنشاءٍ كما وصل المستودع — ⛔ **بلا مبلغٍ ولا سعر**.
final class CreatedDisposal {
  /// ينشئ الطلب.
  const CreatedDisposal({
    required this.sourceId,
    required this.lines,
    required this.stockDate,
    required this.reason,
  });

  /// المصدر.
  final String sourceId;

  /// السطور.
  final List<DisposalLineInput> lines;

  /// ★★ تاريخُ المخزون المُرسَل — و`null` **تعني «مخزون اليوم»**.
  final CalendarDay? stockDate;

  /// السبب — **اختياريٌّ** (`ADR-0020`).
  final String? reason;
}

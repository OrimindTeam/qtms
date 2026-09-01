/// بدائل السحبيات والخرجيات للاختبار — ★ **بلا سحابة ولا شبكة**
/// (`ADR-0010`).
///
/// ⛔⛔★★★ **وبديلٌ واحد للسجلَّين ⛔ لا بديلان** — ★ **بنفس علّة وحدة
/// المستودع نفسِها** (`outflow-design.md` §2): ⟵ **والسجلُّ حقلٌ في الطلب
/// المسجَّل**، ★ **وهو ما يجعل اختبارَ «الخرجيةُ لم تُرسَل سحبيةً» ممكناً
/// بفحص الحقل** ⛔ **لا بفحص أيِّ قائمةٍ استُدعيت.**
library;

import 'dart:async';

import 'package:qtms_domain/qtms_domain.dart';

/// دليل سحبيات وخرجيات بديل.
final class FakeOutflowDirectory implements OutflowDirectory {
  final StreamController<List<OutflowCard>> _cards =
      StreamController<List<OutflowCard>>.broadcast();

  List<OutflowCard> _last = const <OutflowCard>[];

  /// ★★★ **الأسئلة التي وصلت الدليل** — ★ **لإثبات أن الاستعلام يُقيّد
  /// `sourceId` و`ledgerType` معاً** ⛔ **لا واحداً منهما**:
  /// ⟵ **واستعلامٌ لا يُقيّدهما يُرفَض كاملاً** (`IQ-024` · `DEBT-40`).
  final List<({String sourceId, OutflowLedgerType ledgerType})> requested =
      <({String sourceId, OutflowLedgerType ledgerType})>[];

  /// يبثّ السندات.
  void emit(List<OutflowCard> value) {
    _last = value;
    _cards.add(value);
  }

  @override
  Stream<List<OutflowCard>> watchOutflows({
    required String sourceId,
    required OutflowLedgerType ledgerType,
    int limit = 50,
  }) async* {
    requested.add((sourceId: sourceId, ledgerType: ledgerType));
    yield _last;
    yield* _cards.stream;
  }

  /// يغلق التدفّقات.
  void dispose() => _cards.close();
}

/// مستودع كتابة بديل — ★ **يسجّل ما طُلب منه** ⛔ **ولا يكتب.**
final class FakeOutflowAdminRepository implements OutflowAdminRepository {
  /// السندات المطلوب إنشاؤها.
  final List<CreatedOutflow> created = <CreatedOutflow>[];

  /// النتيجة التالية — ★ **لاختبار مسار الرفض كما يصل من السحابة.**
  Outcome<String> nextResult = const Success<String>('WDR-20260901-0001');

  @override
  Future<Outcome<String>> createOutflow({
    required OutflowLedgerType ledgerType,
    required String sourceId,
    required OutflowCategory category,
    required CalendarDay date,
    List<OutflowQatLineInput> qatLines = const <OutflowQatLineInput>[],
    List<OutflowCashLineInput> cashLines = const <OutflowCashLineInput>[],
    String? notes,
  }) async {
    created.add(
      CreatedOutflow(
        ledgerType: ledgerType,
        sourceId: sourceId,
        category: category,
        date: date,
        qatLines: qatLines,
        cashLines: cashLines,
        notes: notes,
      ),
    );
    return nextResult;
  }

  @override
  Future<Outcome<void>> amendOutflow({
    required String documentNumber,
    required String sourceId,
    required OutflowCategory category,
    List<OutflowQatLineInput> qatLines = const <OutflowQatLineInput>[],
    List<OutflowCashLineInput> cashLines = const <OutflowCashLineInput>[],
    String? notes,
    String? amendReason,
  }) async =>
      const Success<void>(null);

  @override
  Future<Outcome<void>> cancelOutflow({
    required String documentNumber,
    required String sourceId,
    String? cancelReason,
  }) async =>
      const Success<void>(null);
}

/// طلب إنشاء سندٍ كما وصل المستودع.
///
/// ⛔⛔★★★ **ولا حقلَ مقوتٍ فيه إطلاقاً** (`FR-M22-04` · `GR-44`) —
/// ★ **غيابٌ بنيويٌّ يجعل اختبارَ «لا مساس بالمقاوته» ممكناً بالنوع نفسِه**،
/// ⛔ **لا بفحصِ قيمةٍ فارغة.**
final class CreatedOutflow {
  /// ينشئ الطلب.
  const CreatedOutflow({
    required this.ledgerType,
    required this.sourceId,
    required this.category,
    required this.date,
    required this.qatLines,
    required this.cashLines,
    required this.notes,
  });

  /// السجل — ★ **وهو ما يفصل السحبية عن الخرجية** (`GR-43`).
  final OutflowLedgerType ledgerType;

  /// المصدر — ⛔ **إلزاميٌّ دائماً** (`GR-42`).
  final String sourceId;

  /// الفئة.
  final OutflowCategory category;

  /// تاريخ السند.
  final CalendarDay date;

  /// بنود القات.
  final List<OutflowQatLineInput> qatLines;

  /// بنود المبالغ.
  final List<OutflowCashLineInput> cashLines;

  /// البيان.
  final String? notes;
}

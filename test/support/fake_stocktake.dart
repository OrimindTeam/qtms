/// بدائل الجرد للاختبار — ★ **بلا سحابة ولا شبكة** (`ADR-0010`).
///
/// ⛔⛔★★★ **ولا حقلَ ماليٍّ في أيٍّ من هذه الأنواع** (`BR-M16-03`) — ★ **وهو
/// ما يجعل اختبارَ «لا قيمةَ لتسوية الجرد» ممكناً بفحص العقد نفسِه** ⛔ **لا
/// بفحص ما إذا كانت الشاشة أخفت حقلاً.**
library;

import 'dart:async';

import 'package:qtms_domain/qtms_domain.dart';

/// دليل جردٍ بديل.
final class FakeStocktakeDirectory implements StocktakeDirectory {
  final StreamController<List<StocktakeCard>> _cards =
      StreamController<List<StocktakeCard>>.broadcast();

  List<StocktakeCard> _last = const <StocktakeCard>[];

  /// ★★★ **المصادر التي وصلت الدليل** — ★ **لإثبات أن الاستعلام يُقيّد
  /// `sourceId`** ⛔ **واستعلامٌ لا يُقيّده يُرفَض كاملاً** (`IQ-024`).
  final List<String> requested = <String>[];

  /// يبثّ المستندات.
  void emit(List<StocktakeCard> value) {
    _last = value;
    _cards.add(value);
  }

  @override
  Stream<List<StocktakeCard>> watchStocktakes({
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
final class FakeStocktakeAdminRepository implements StocktakeAdminRepository {
  /// طلبات البدء.
  final List<StartedStocktake> started = <StartedStocktake>[];

  /// طلبات الاعتماد.
  final List<ApprovedStocktake> approved = <ApprovedStocktake>[];

  /// أرقام ما طُلب إلغاؤه.
  final List<String> cancelled = <String>[];

  /// نتيجة البدء التالية — ★ **لاختبار مسار الرفض كما يصل من السحابة.**
  Outcome<String> nextStart = const Success<String>('STK-20260905-001');

  /// نتيجة الاعتماد التالية.
  Outcome<void> nextApprove = const Success<void>(null);

  /// ★ نتيجة الإلغاء التالية — **مؤجَّلةً** ⟵ **فتُقاس حالةُ «جارٍ الإلغاء».**
  Future<Outcome<void>>? nextCancel;

  @override
  Future<Outcome<String>> startStocktake({
    required String sourceId,
    List<String> itemIds = const <String>[],
    CalendarDay? stockDate,
    String? reason,
  }) async {
    started.add(
      StartedStocktake(
        sourceId: sourceId,
        itemIds: itemIds,
        stockDate: stockDate,
        reason: reason,
      ),
    );
    return nextStart;
  }

  @override
  Future<Outcome<void>> approveStocktake({
    required String documentNumber,
    required String sourceId,
    List<StocktakeCountInput> counts = const <StocktakeCountInput>[],
    String? reason,
  }) async {
    approved.add(
      ApprovedStocktake(
        documentNumber: documentNumber,
        sourceId: sourceId,
        counts: counts,
        reason: reason,
      ),
    );
    return nextApprove;
  }

  @override
  Future<Outcome<void>> amendStocktake({
    required String documentNumber,
    required String sourceId,
    List<StocktakeCountInput> counts = const <StocktakeCountInput>[],
    String? amendReason,
  }) async =>
      const Success<void>(null);

  @override
  Future<Outcome<void>> cancelStocktake({
    required String documentNumber,
    required String sourceId,
    String? cancelReason,
  }) async {
    cancelled.add(documentNumber);
    return nextCancel == null ? const Success<void>(null) : await nextCancel!;
  }
}

/// ★ طلبُ بدءٍ كما وصل المستودع — ⛔ **بلا رصيدٍ دفتريٍّ ولا مبلغ**.
final class StartedStocktake {
  /// ينشئ الطلب.
  const StartedStocktake({
    required this.sourceId,
    required this.itemIds,
    required this.stockDate,
    required this.reason,
  });

  /// المصدر.
  final String sourceId;

  /// الأنواع المطلوب جردها.
  final List<String> itemIds;

  /// ★★ تاريخُ المخزون المُرسَل — و`null` **تعني «مخزون اليوم»**.
  final CalendarDay? stockDate;

  /// السبب — **اختياريٌّ** (`ADR-0020`).
  final String? reason;
}

/// ★ طلبُ اعتمادٍ كما وصل المستودع.
final class ApprovedStocktake {
  /// ينشئ الطلب.
  const ApprovedStocktake({
    required this.documentNumber,
    required this.sourceId,
    required this.counts,
    required this.reason,
  });

  /// رقم المستند.
  final String documentNumber;

  /// المصدر.
  final String sourceId;

  /// ★★ الأعداد الفعلية — ⛔ **ولا رصيدَ دفتريٍّ فيها** (`FR-M16-01`).
  final List<StocktakeCountInput> counts;

  /// السبب — **اختياريٌّ**.
  final String? reason;
}

/// ★ بطاقةُ جردٍ للاختبار — **مسوّدةٌ افتراضاً**.
StocktakeCard testStocktake({
  String documentNumber = 'STK-20260905-001',
  String sourceId = 'SRC-001',
  StocktakeStatus status = StocktakeStatus.draft,
  CalendarDay? stockDate,
  List<StocktakeCardLine>? lines,
}) =>
    StocktakeCard(
      documentNumber: documentNumber,
      sourceId: sourceId,
      status: status,
      stockDate: stockDate ?? CalendarDay(2026, 9, 5),
      lines: lines ??
          <StocktakeCardLine>[
            const StocktakeCardLine(
              itemKey: 'ITM-0001',
              itemName: 'عوارض',
              bookBalance: PieceQuantity(PieceCount(80)),
            ),
          ],
    );

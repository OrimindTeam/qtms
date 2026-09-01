/// بدائل البيع النقدي للاختبار — ★ **بلا سحابة ولا شبكة** (`ADR-0010`).
///
/// ⛔⛔★★★ **وتدفّقٌ واحد لا تدفّقان** (بخلاف `fake_distribution.dart`) —
/// ★ **لأن `ADR-0011` عزل أسعارَ التوزيعة لأجل `ت-12`** ⛔ **ولا نظير له
/// هنا**: ⟵ **السعرُ جزءٌ من سند البيع النقدي نفسِه** (`schema/cash-sales.md`).
library;

import 'dart:async';

import 'package:qtms_domain/qtms_domain.dart';

/// دليل بيعٍ نقدي بديل.
final class FakeCashSaleDirectory implements CashSaleDirectory {
  final StreamController<List<CashSaleCard>> _list =
      StreamController<List<CashSaleCard>>.broadcast();

  List<CashSaleCard> _lastList = const <CashSaleCard>[];

  /// ★ المصادر التي استُعلم عنها — ⛔ **لإثبات أن الاستعلام مقيَّدٌ بالمصدر**
  /// (`IQ-024`): ⟵ **فاستعلامٌ غيرُ مقيَّد يُرفَض كاملاً في القاعدة.**
  final List<String> requestedSources = <String>[];

  /// يبثّ قائمة اليوم.
  void emitList(List<CashSaleCard> value) {
    _lastList = value;
    _list.add(value);
  }

  /// يبثّ سنداً واحداً — ⛔ **عبر قائمة اليوم لا بمعرّفه** (`DEBT-40`).
  void emitOne(CashSaleCard? value) {
    emitList(
      value == null ? const <CashSaleCard>[] : <CashSaleCard>[value],
    );
  }

  @override
  Stream<List<CashSaleCard>> watchCashSales({
    required String sourceId,
    required CalendarDay stockDate,
  }) async* {
    requestedSources.add(sourceId);
    yield _lastList;
    yield* _list.stream;
  }

  /// يغلق التدفّقات.
  void dispose() {
    _list.close();
  }
}

/// مستودع كتابة بديل — ★ **يحفظ آخر حمولة لتُفحَص**.
final class FakeCashSaleAdmin implements CashSaleAdminRepository {
  /// آخر سندٍ أُرسل للإنشاء أو التعديل.
  ValidatedCashSale? lastSale;

  /// آخر سبب تعديل أُرسل — ⛔ **ولا يُعبَّأ آلياً** (`ADR-0020`).
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

  @override
  Future<Outcome<String>> createCashSale(ValidatedCashSale sale) async {
    createCalls++;
    lastSale = sale;
    final AppError? error = rejection;
    return error == null
        ? const Success<String>('CSH-20260827-0001')
        : Failure<String>(error);
  }

  @override
  Future<Outcome<void>> amendCashSale({
    required String documentNumber,
    required ValidatedCashSale sale,
    String? amendReason,
  }) async {
    amendCalls++;
    lastSale = sale;
    lastAmendReason = amendReason;
    final AppError? error = rejection;
    return error == null ? const Success<void>(null) : Failure<void>(error);
  }

  @override
  Future<Outcome<void>> cancelCashSale({
    required String documentNumber,
    required String sourceId,
    String? cancelReason,
  }) async {
    cancelCalls++;
    lastCancelReason = cancelReason;
    final AppError? error = rejection;
    return error == null ? const Success<void>(null) : Failure<void>(error);
  }
}

/// بطاقة سندٍ جاهزة للاختبار.
CashSaleCard testCashSaleCard({
  String sourceId = 'SRC-001',
  String documentNumber = 'CSH-20260827-0001',
  CashSaleStatus status = CashSaleStatus.approved,
  int amendCount = 0,
  int quantity = 80,
  int unitPrice = 700,
  String itemId = 'ITM-0002',
  CalendarDay? stockDate,
}) {
  final CalendarDay day = stockDate ?? CalendarDay(2026, 8, 27);
  final ValidatedCashSaleLine line = ValidatedCashSaleLine(
    itemId: itemId,
    itemName: 'عود',
    quantity: PieceQuantity(PieceCount(quantity)),
    unitPrice: Money(unitPrice),
    sackId: null,
    belowMinReason: null,
  );
  return CashSaleCard(
    documentNumber: documentNumber,
    sourceId: sourceId,
    stockDate: day,
    entryDate: DateTime.utc(2026, 8, 27, 6),
    status: status,
    totalPieces: PieceCount(quantity),
    totalWeight: WeightKg.zero,
    // ★ **من طبقة النطاق** — ⛔ **ولا ضربَ في ملفِّ اختبار.**
    netCashReceived: computeNetCashReceived(<Money>[line.lineTotal]),
    amendCount: amendCount,
    lines: <ValidatedCashSaleLine>[line],
  );
}

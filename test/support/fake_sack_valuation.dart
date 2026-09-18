/// بديلٌ اختباري لدليل مالية الجواني (`M14` · `WU-015`) — ★ **بلا سحابة**
/// (`ADR-0010` · `test-strategy.md`).
library;

import 'dart:async';

import 'package:qtms_domain/qtms_domain.dart';

/// دليل مالية جواني يُتحكَّم به.
final class FakeSackValuationDirectory implements SackValuationDirectory {
  final StreamController<SupplierBalanceCard?> _balance =
      StreamController<SupplierBalanceCard?>.broadcast();
  final StreamController<List<SupplierLedgerRow>> _ledger =
      StreamController<List<SupplierLedgerRow>>.broadcast();

  SupplierBalanceCard? _currentBalance;
  List<SupplierLedgerRow> _currentLedger = const <SupplierLedgerRow>[];
  Outcome<List<SackRevenueContribution>> _breakdown =
      const Success<List<SackRevenueContribution>>(
    <SackRevenueContribution>[],
  );

  /// ★ آخر جونيةٍ طُلب تفكيكها — ⛔ **يُثبت أن الورقة تسأل عن الصحيحة**.
  String? lastBreakdownSackId;

  /// ★ آخر تاريخ مخزون طُلب — ⛔ **يُثبت أن السؤال على `stockDate`**.
  CalendarDay? lastBreakdownStockDate;

  /// ⛔⛔★★★ **عددُ مرات القراءة الفعلية** ([`DEBT-90`]) — ★ **يُثبت أن
  /// الورقة تقرأ من جديد في كل فتحة**، ⛔ **ولا تُعيد لقطةً مخزَّنة.**
  int breakdownCallCount = 0;

  /// ★★★ **يُبقي رصيدَ الرعوي في حالة تحميلٍ أبديّة** — `AM-021` ③.
  ///
  /// ⛔⛔ **و`AsyncData(null)` ليست `AsyncLoading`** — ★ **الأولى «لا حساب
  /// أو لا صلاحية» والثانية «انتظر»**: ⟵ **والبطاقةُ تُخفى في الأولى
  /// وتُرسَم هيكلاً في الثانية.**
  void holdBalance() => _balancePending = true;

  bool _balancePending = false;

  /// يبثّ رصيد الرعوي.
  void emitBalance(SupplierBalanceCard? value) {
    _currentBalance = value;
    _balance.add(value);
  }

  /// يبثّ سطور دفتر الرعية.
  void emitLedger(List<SupplierLedgerRow> rows) {
    _currentLedger = rows;
    _ledger.add(rows);
  }

  /// ★ يضبط نتيجة التفكيك — **نجاحاً أو رفضاً**.
  void setBreakdown(Outcome<List<SackRevenueContribution>> outcome) =>
      _breakdown = outcome;

  /// ⚠️ **يُغلِق بلا انتظار عمداً** — بنفس سبب بقية البدائل.
  void dispose() {
    unawaited(_balance.close());
    unawaited(_ledger.close());
  }

  @override
  Stream<SupplierBalanceCard?> watchSupplierBalance({
    required String supplierId,
    required String sourceId,
  }) async* {
    // ★★★ **والتعليقُ يسبق البثّ** — راجع [holdBalance].
    if (_balancePending) {
      await Completer<void>().future;
      return;
    }
    yield _currentBalance;
    yield* _balance.stream;
  }

  @override
  Stream<List<SupplierLedgerRow>> watchSupplierLedger({
    required String supplierId,
    required String sourceId,
  }) async* {
    yield _currentLedger;
    yield* _ledger.stream;
  }

  @override
  Future<Outcome<List<SackRevenueContribution>>> loadSackContributions({
    required String sackId,
    required String sourceId,
    required CalendarDay stockDate,
  }) async {
    breakdownCallCount++;
    lastBreakdownSackId = sackId;
    lastBreakdownStockDate = stockDate;
    return _breakdown;
  }
}

/// ★ مساهمةٌ جاهزة للاختبارات.
SackRevenueContribution testContribution({
  String itemName = 'بطوة',
  SackRevenueSource origin = SackRevenueSource.distribution,
  String documentNumber = 'DST-20260826-0001',
  String? counterpartyName = 'المقوت الأول',
  int quantity = 10,
  int? unitPrice = 500,
  int? lineValue = 5000,
  bool isCancelled = false,
}) =>
    SackRevenueContribution(
      itemKey: '$itemName - عبدالفتاح - جونية رقم 1',
      itemName: itemName,
      origin: origin,
      documentNumber: documentNumber,
      quantity: PieceQuantity(PieceCount(quantity)),
      unitPrice: unitPrice == null ? null : Money(unitPrice),
      lineValue: lineValue == null ? null : Money(lineValue),
      counterpartyName: counterpartyName,
      isCancelled: isCancelled,
    );

/// ★ بطاقةُ رصيدٍ جاهزة.
SupplierBalanceCard testSupplierBalance({
  String supplierId = 'SUP-0001',
  String sourceId = 'SRC-001',
  int revenue = 57300,
  int tax = 1625,
  int sackCount = 2,
  int pendingTaxCount = 0,
  int unfinalRevenueCount = 0,
}) =>
    SupplierBalanceCard(
      supplierId: supplierId,
      sourceId: sourceId,
      totals: SupplierSourceTotals(
        totalRevenue: Money(revenue),
        totalTax: Money(tax),
        sackCount: sackCount,
        pendingTaxCount: pendingTaxCount,
        unfinalRevenueCount: unfinalRevenueCount,
      ),
    );

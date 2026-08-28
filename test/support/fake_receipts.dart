/// بدائل المقبوضات للاختبار — ★ **بلا سحابة ولا شبكة** (`ADR-0010`).
///
/// ⚠️⚠️ **وتدفّقان منفصلان عمداً** ([`ADR-0017`]): **الأب** و**حالة الإيداع** —
/// ⟵ **فيُختبَر `FR-M12-16` كما يقع فعلاً**: ★ **الحالة تغيب عمّن لا يملكها
/// بينما يبقى السند ظاهراً**، ⛔ **لا حقلٌ `null` في نوعٍ واحد.**
library;

import 'dart:async';

import 'package:qtms_domain/qtms_domain.dart';

/// دليل مقبوضات بديل.
final class FakeReceiptDirectory implements ReceiptDirectory {
  final StreamController<List<OpenDebtLot>> _lots =
      StreamController<List<OpenDebtLot>>.broadcast();
  final StreamController<List<ReceiptCard>> _receipts =
      StreamController<List<ReceiptCard>>.broadcast();
  final StreamController<ReceiptDepositCard?> _deposit =
      StreamController<ReceiptDepositCard?>.broadcast();
  final StreamController<Money?> _surplus =
      StreamController<Money?>.broadcast();

  List<OpenDebtLot> _lastLots = const <OpenDebtLot>[];
  List<ReceiptCard> _lastReceipts = const <ReceiptCard>[];
  ReceiptDepositCard? _lastDeposit;
  Money? _lastSurplus;

  /// ★★★ **المصادر التي طُلبت بها الضمارات** — ★ **لإثبات أن «الكل» تصل
  /// **مُعدَّدة** ⛔ **لا غياباً**: ⟵ **واستعلامٌ بلا `sourceId` يُرفَض كاملاً**
  /// (`IQ-024` · `DEBT-40`).
  final List<List<String>> requestedSources = <List<String>>[];

  /// يبثّ الضمارات المفتوحة.
  void emitLots(List<OpenDebtLot> value) {
    _lastLots = value;
    _lots.add(value);
  }

  /// يبثّ السندات.
  void emitReceipts(List<ReceiptCard> value) {
    _lastReceipts = value;
    _receipts.add(value);
  }

  /// يبثّ حالة الإيداع — و`null` تعني **«لا أرى» أو «لا يوجد»** معاً.
  void emitDeposit(ReceiptDepositCard? value) {
    _lastDeposit = value;
    _deposit.add(value);
  }

  /// يبثّ الفائض المتاح.
  void emitSurplus(Money? value) {
    _lastSurplus = value;
    _surplus.add(value);
  }

  @override
  Stream<List<OpenDebtLot>> watchOpenDebtLots({
    required String dealerId,
    required List<String> sourceIds,
  }) async* {
    requestedSources.add(sourceIds);
    yield _lastLots;
    yield* _lots.stream;
  }

  @override
  Stream<List<ReceiptCard>> watchReceipts({
    required String dealerId,
    int limit = 50,
  }) async* {
    yield _lastReceipts;
    yield* _receipts.stream;
  }

  @override
  Stream<ReceiptDepositCard?> watchReceiptDeposit({
    required String documentNumber,
  }) async* {
    yield _lastDeposit;
    yield* _deposit.stream;
  }

  @override
  Stream<Money?> watchAvailableSurplus({
    required String dealerId,
    required SurplusScope scope,
    String? sourceId,
  }) async* {
    yield _lastSurplus;
    yield* _surplus.stream;
  }

  /// يغلق التدفّقات.
  void dispose() {
    _lots.close();
    _receipts.close();
    _deposit.close();
    _surplus.close();
  }
}

/// مستودع كتابة مقبوضات بديل — ★ **يسجّل ما طُلب منه** ⛔ **ولا يكتب.**
final class FakeReceiptAdminRepository implements ReceiptAdminRepository {
  /// السندات المطلوب إنشاؤها.
  final List<CreatedReceipt> created = <CreatedReceipt>[];

  /// طلبات الإيداع.
  final List<DepositRequest> deposits = <DepositRequest>[];

  /// النتيجة التالية — ★ **لاختبار مسار الرفض كما يصل من السحابة.**
  Outcome<String> nextResult = const Success<String>('RCP-20260828-0001');

  @override
  Future<Outcome<String>> createReceipt({
    required String dealerId,
    required CalendarDay date,
    required List<ReceiptLineInput> lines,
    String? sourceFilter,
    Money surplusAmount = Money.zero,
    SurplusScope surplusScope = SurplusScope.general,
    bool usedAutoAllocation = false,
  }) async {
    created.add(
      CreatedReceipt(
        dealerId: dealerId,
        date: date,
        lines: lines,
        sourceFilter: sourceFilter,
        surplusAmount: surplusAmount,
        surplusScope: surplusScope,
        usedAutoAllocation: usedAutoAllocation,
      ),
    );
    return nextResult;
  }

  @override
  Future<Outcome<void>> amendReceipt({
    required String documentNumber,
    required String dealerId,
    required CalendarDay date,
    required List<ReceiptLineInput> lines,
    String? sourceFilter,
    Money surplusAmount = Money.zero,
    SurplusScope surplusScope = SurplusScope.general,
    String? amendReason,
  }) async =>
      const Success<void>(null);

  @override
  Future<Outcome<void>> cancelReceipt({
    required String documentNumber,
    required String dealerId,
    String? cancelReason,
  }) async =>
      const Success<void>(null);

  @override
  Future<Outcome<void>> setReceiptDeposit({
    required String documentNumber,
    required String dealerId,
    required bool isDeposited,
    required String note,
  }) async {
    deposits.add(
      DepositRequest(
        documentNumber: documentNumber,
        isDeposited: isDeposited,
        note: note,
      ),
    );
    return const Success<void>(null);
  }
}

/// طلب إنشاء سند كما وصل المستودع.
final class CreatedReceipt {
  /// ينشئ الطلب.
  const CreatedReceipt({
    required this.dealerId,
    required this.date,
    required this.lines,
    required this.sourceFilter,
    required this.surplusAmount,
    required this.surplusScope,
    required this.usedAutoAllocation,
  });

  /// المقوت.
  final String dealerId;

  /// التاريخ.
  final CalendarDay date;

  /// السطور.
  final List<ReceiptLineInput> lines;

  /// فلتر المصدر.
  final String? sourceFilter;

  /// الفائض.
  final Money surplusAmount;

  /// نطاقه.
  final SurplusScope surplusScope;

  /// هل استُخدم التوزيع التلقائي؟
  final bool usedAutoAllocation;
}

/// طلب تغيير حالة إيداع.
final class DepositRequest {
  /// ينشئ الطلب.
  const DepositRequest({
    required this.documentNumber,
    required this.isDeposited,
    required this.note,
  });

  /// رقم السند.
  final String documentNumber;

  /// الحالة المطلوبة.
  final bool isDeposited;

  /// الملاحظة.
  final String note;
}

/// بدائل الخصومات للاختبار — ★ **بلا سحابة ولا شبكة** (`ADR-0010`).
///
/// ⛔⛔★★★ **وبديلٌ منفصلٌ عن `fake_receipts.dart` قطعاً** — ★ **بنفس علّة
/// انفصال المستودعين نفسِها** (`FR-M15-06-أ`): ⟵ **فبديلٌ واحد يخدم
/// الاثنين كان سيجعل اختبارَ «الخصم لا يُكتب كقبض» يمرّ بلا معنى** —
/// ⛔ **إذ يُسجَّل الطلبان في القائمة نفسِها.**
library;

import 'dart:async';

import 'package:qtms_domain/qtms_domain.dart';

/// دليل خصومات بديل.
final class FakeDiscountDirectory implements DiscountDirectory {
  final StreamController<List<OpenDebtLot>> _lots =
      StreamController<List<OpenDebtLot>>.broadcast();
  final StreamController<List<DiscountCard>> _discounts =
      StreamController<List<DiscountCard>>.broadcast();

  List<OpenDebtLot> _lastLots = const <OpenDebtLot>[];
  List<DiscountCard> _lastDiscounts = const <DiscountCard>[];

  /// ★★★ **المصادر التي طُلبت بها الضمارات** — ★ **لإثبات أن «الكل» تصل
  /// مُعدَّدة** ⛔ **لا غياباً**: ⟵ **واستعلامٌ بلا `sourceId` يُرفَض كاملاً**
  /// (`IQ-024` · `DEBT-40`).
  final List<List<String>> requestedSources = <List<String>>[];

  /// يبثّ الضمارات المفتوحة.
  void emitLots(List<OpenDebtLot> value) {
    _lastLots = value;
    _lots.add(value);
  }

  /// يبثّ سندات الخصم.
  void emitDiscounts(List<DiscountCard> value) {
    _lastDiscounts = value;
    _discounts.add(value);
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
  Stream<List<DiscountCard>> watchDiscounts({
    required String dealerId,
    int limit = 50,
  }) async* {
    yield _lastDiscounts;
    yield* _discounts.stream;
  }

  /// يغلق التدفّقات.
  void dispose() {
    _lots.close();
    _discounts.close();
  }
}

/// مستودع كتابة خصومات بديل — ★ **يسجّل ما طُلب منه** ⛔ **ولا يكتب.**
final class FakeDiscountAdminRepository implements DiscountAdminRepository {
  /// السندات المطلوب إنشاؤها.
  final List<CreatedDiscount> created = <CreatedDiscount>[];

  /// النتيجة التالية — ★ **لاختبار مسار الرفض كما يصل من السحابة.**
  Outcome<String> nextResult = const Success<String>('DSC-20260901-0001');

  @override
  Future<Outcome<String>> createDiscount({
    required String dealerId,
    required CalendarDay date,
    required List<DiscountLineInput> lines,
    String? sourceFilter,
    bool usedAutoAllocation = false,
  }) async {
    created.add(
      CreatedDiscount(
        dealerId: dealerId,
        date: date,
        lines: lines,
        sourceFilter: sourceFilter,
        usedAutoAllocation: usedAutoAllocation,
      ),
    );
    return nextResult;
  }

  @override
  Future<Outcome<void>> amendDiscount({
    required String documentNumber,
    required String dealerId,
    required CalendarDay date,
    required List<DiscountLineInput> lines,
    String? sourceFilter,
    String? amendReason,
  }) async =>
      const Success<void>(null);

  @override
  Future<Outcome<void>> cancelDiscount({
    required String documentNumber,
    required String dealerId,
    String? cancelReason,
  }) async =>
      const Success<void>(null);
}

/// طلب إنشاء سند خصمٍ كما وصل المستودع.
///
/// ⛔⛔★★★ **ولا حقلَ فائضٍ فيه** — ★ **بخلاف `CreatedReceipt`**:
/// ⟵ **غيابٌ بنيويٌّ يجعل اختبارَ «لا فائض» ممكناً بالنوع نفسِه**
/// (`FR-M13-05`)، ⛔ **لا بفحصِ قيمةٍ صفرية.**
final class CreatedDiscount {
  /// ينشئ الطلب.
  const CreatedDiscount({
    required this.dealerId,
    required this.date,
    required this.lines,
    required this.sourceFilter,
    required this.usedAutoAllocation,
  });

  /// المقوت.
  final String dealerId;

  /// التاريخ.
  final CalendarDay date;

  /// السطور.
  final List<DiscountLineInput> lines;

  /// فلتر المصدر.
  final String? sourceFilter;

  /// هل استُخدم التوزيع التلقائي؟
  final bool usedAutoAllocation;
}

/// كتابة البيع النقدي عبر **العمليات السحابية المستدعاة الثلاث** (`WU-012`).
///
/// ⛔★★ **ولا كتابة مباشرة:** `cash_sales` و`inventory_ledger` و
/// `item_daily_balances` **كلها مغلقة في القواعد** — ⟵ **فكل عملية هنا طلبٌ
/// لا كتابة**، **والسندُ وحركاتُه وأرصدتُه وقيدُ تدقيقه في معاملة واحدة**
/// (`ADR-0013` القاعدة 1 · `GR-51`).
///
/// ⛔★★ **ولا يُرسَل تاريخٌ إطلاقاً** — **النظام هو من يحدده لا المستخدم**
/// (`A-10` · `GR-14`)، ★ **واليوم من المنصّة داخل المعاملة** ⟵ ★ **وما لا
/// يُرسَل لا يُزوَّر.**
///
/// ⛔★★ **ولا يُرسَل اسمُ نوعٍ ولا وحدتُه** — ★ **كلاهما من سجل النوع**
/// (`FR-M5-03`)، ⟵ **فلا يُباع بوحدةٍ ليست وحدة النوع** (`GR-19`).
///
/// ⛔⛔★★★ **ولا حقلَ مقوتٍ ولا اسمِ مشترٍ ولا خصم في أي حمولة هنا** —
/// `FR-M11-03` · `FR-M11-12` (`ت-06`): ★ **والغياب البنيوي هو الحارس.**
library;

import 'package:qtms_domain/qtms_domain.dart';

import '../../../core/callable/callable_client.dart';
import '../../identity_access/infrastructure/functions_user_admin_repository.dart'
    show RequestIdFactory;

/// مستودع كتابة البيع النقدي الحقيقي.
final class FunctionsCashSaleRepository implements CashSaleAdminRepository {
  /// ينشئ المستودع.
  const FunctionsCashSaleRepository({
    required CallableClient client,
    required RequestIdFactory newRequestId,
  })  : _client = client,
        _newRequestId = newRequestId;

  final CallableClient _client;
  final RequestIdFactory _newRequestId;

  @override
  Future<Outcome<String>> createCashSale(ValidatedCashSale sale) async {
    final Outcome<Map<String, Object?>> result = await _client.call(
      'createCashSale',
      <String, Object?>{
        'requestId': _newRequestId(),
        'sourceId': sale.sourceId,
        'notes': ?sale.notes,
        'lines': _linesOf(sale),
      },
    );
    return switch (result) {
      Failure<Map<String, Object?>>(:final AppError error) =>
        Failure<String>(error),
      Success<Map<String, Object?>>(:final Map<String, Object?> value) =>
        Success<String>(value['documentNumber'] as String? ?? ''),
    };
  }

  @override
  Future<Outcome<void>> amendCashSale({
    required String documentNumber,
    required ValidatedCashSale sale,
    String? amendReason,
  }) async {
    final Outcome<Map<String, Object?>> result = await _client.call(
      'amendCashSale',
      <String, Object?>{
        'requestId': _newRequestId(),
        'documentNumber': documentNumber,
        'sourceId': sale.sourceId,
        // ⛔⛔★★ **ولا يُعبَّأ نيابةً عن المستخدم أبداً** (`CLAUDE.md`):
        //    **ما لم يكتبه إنسانٌ لا يُرسَل** (`ADR-0020`).
        'reason': ?amendReason,
        'notes': ?sale.notes,
        'lines': _linesOf(sale),
      },
    );
    return switch (result) {
      Failure<Map<String, Object?>>(:final AppError error) =>
        Failure<void>(error),
      Success<Map<String, Object?>>() => const Success<void>(null),
    };
  }

  @override
  Future<Outcome<void>> cancelCashSale({
    required String documentNumber,
    required String sourceId,
    String? cancelReason,
  }) async {
    final Outcome<Map<String, Object?>> result = await _client.call(
      'cancelCashSale',
      <String, Object?>{
        'requestId': _newRequestId(),
        'documentNumber': documentNumber,
        'sourceId': sourceId,
        'reason': ?cancelReason,
      },
    );
    return switch (result) {
      Failure<Map<String, Object?>>(:final AppError error) =>
        Failure<void>(error),
      Success<Map<String, Object?>>() => const Success<void>(null),
    };
  }

  /// ★ السطور كما تعبر الشبكة — ⛔ **بلا اسمٍ ولا وحدة**: كلاهما من القاعدة.
  ///
  /// ★★ **والسعر حاضرٌ دائماً** — `FR-M11-04`: ⟵ **ولا مفتاحَ `null` هنا
  /// بخلاف التوزيع**، ⛔ **فـ«التسعير لاحقاً» لا وجود له في بيعٍ نقدي.**
  static List<Object?> _linesOf(ValidatedCashSale sale) => <Object?>[
        for (final ValidatedCashSaleLine line in sale.lines)
          <String, Object?>{
            'itemId': line.itemId,
            'quantity': switch (line.quantity) {
              PieceQuantity(:final PieceCount count) => count.pieces,
              WeightQuantity(:final WeightKg weight) => weight.kilograms,
            },
            'unitPrice': line.unitPrice.riyals,
            'sackId': ?line.sackId,
            'belowMinReason': ?line.belowMinReason,
          },
      ];
}

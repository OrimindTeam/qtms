/// كتابة الإتلاف عبر **العمليات السحابية المستدعاة الثلاث** (`WU-020`).
///
/// ⛔★★ **ولا كتابة مباشرة:** `disposals` و`inventory_ledger` و
/// `item_daily_balances` **كلها مغلقة في القواعد** — ⟵ **فكل عملية هنا
/// طلبٌ لا كتابة**، **والمستندُ وحركاتُه وأرصدتُه وقيدُ تدقيقه في معاملة
/// واحدة** (`ADR-0013` القاعدة 1).
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **ولا حقلَ ماليٍّ في أي حمولة هنا** (`FR-M8-16`) — ★ **غيابٌ
/// بنيويٌّ من الحمولة نفسِها**: ⟵ **فما لا يُرسَل لا يُكتَب**، ★ **والسحابة
/// لا تقرأ `unitPrice` من حمولة الإتلاف أصلاً.**
///
/// ⛔★★ **ولا يُرسَل اسمُ نوعٍ ولا وحدةٌ** — ★ **كلاهما من سجل النوع المقروء
/// داخل المعاملة**، ⟵ **فما لا يُرسَل لا يُزوَّر.**
///
/// ★★ **وتاريخُ المخزون يُرسَل عند التصريف المتأخر وحده** — `FR-M8-11`:
/// ⟵ **وغيابُه يعني «مخزون اليوم» من المنصّة**، ⛔ **ولا يُملأ بيوم الجهاز**
/// (`GR-54` · `E-41`).
///
/// ⛔⛔★★★ **ولا يُعبَّأ سببٌ نيابةً عن المستخدم** ([`ADR-0020`]) — ★ **ما لم
/// يكتبه إنسانٌ لا يُرسَل**، **والفراغات تُقرأ غياباً لا نصّاً فارغاً.**
/// ═══════════════════════════════════════════════════════════════════════
library;

import 'package:qtms_domain/qtms_domain.dart';

import '../../../core/callable/callable_client.dart';
import '../../identity_access/infrastructure/functions_user_admin_repository.dart'
    show RequestIdFactory;

/// مستودع كتابة الإتلاف الحقيقي.
final class FunctionsDisposalRepository implements DisposalAdminRepository {
  /// ينشئ المستودع.
  const FunctionsDisposalRepository({
    required CallableClient client,
    required RequestIdFactory newRequestId,
  })  : _client = client,
        _newRequestId = newRequestId;

  final CallableClient _client;
  final RequestIdFactory _newRequestId;

  @override
  Future<Outcome<String>> createDisposal({
    required String sourceId,
    List<DisposalLineInput> lines = const <DisposalLineInput>[],
    CalendarDay? stockDate,
    String? reason,
  }) async {
    final Outcome<Map<String, Object?>> result = await _client.call(
      'createDisposal',
      <String, Object?>{
        'requestId': _newRequestId(),
        'sourceId': sourceId,
        'lines': _linesOf(lines),
        // ★★ **الصيغة المُدمَجة `YYYYMMDD`** — ★ **وهي صيغة المشروع القائمة**
        //   (`naming-conventions.md` §4 و§5)، ⛔ **ولا تُرسَل إلا عند التثبيت.**
        'stockDate': ?stockDate?.format(),
        'reason': ?_blankToNull(reason),
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
  Future<Outcome<void>> amendDisposal({
    required String documentNumber,
    required String sourceId,
    List<DisposalLineInput> lines = const <DisposalLineInput>[],
    String? amendReason,
  }) async {
    final Outcome<Map<String, Object?>> result = await _client.call(
      'amendDisposal',
      <String, Object?>{
        'requestId': _newRequestId(),
        'documentNumber': documentNumber,
        'sourceId': sourceId,
        'lines': _linesOf(lines),
        // ⛔★★ **ويُرسَل غائباً إن لم يكتبه إنسان** ([`ADR-0020`]).
        'reason': ?_blankToNull(amendReason),
      },
    );
    return _voidOf(result);
  }

  @override
  Future<Outcome<void>> cancelDisposal({
    required String documentNumber,
    required String sourceId,
    String? cancelReason,
  }) async {
    final Outcome<Map<String, Object?>> result = await _client.call(
      'cancelDisposal',
      <String, Object?>{
        'requestId': _newRequestId(),
        'documentNumber': documentNumber,
        'sourceId': sourceId,
        'reason': ?_blankToNull(cancelReason),
      },
    );
    return _voidOf(result);
  }

  static Outcome<void> _voidOf(Outcome<Map<String, Object?>> result) =>
      switch (result) {
        Failure<Map<String, Object?>>(:final AppError error) =>
          Failure<void>(error),
        Success<Map<String, Object?>>() => const Success<void>(null),
      };

  static List<Map<String, Object?>> _linesOf(List<DisposalLineInput> lines) =>
      <Map<String, Object?>>[
        for (final DisposalLineInput line in lines)
          <String, Object?>{
            'itemId': line.itemId,
            'quantity': switch (line.quantity) {
              PieceQuantity(:final PieceCount count) => count.pieces,
              WeightQuantity(:final WeightKg weight) => weight.kilograms,
            },
            'sackId': ?line.sackId,
            // ⛔⛔★★★ **ولا `unitPrice` ولا `lineValue`** — `FR-M8-16`.
          },
      ];

  /// ★ **الفراغات تُقرأ غياباً لا نصّاً فارغاً** — ([`ADR-0020`] · الطرفان).
  static String? _blankToNull(String? value) {
    if (value == null) return null;
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

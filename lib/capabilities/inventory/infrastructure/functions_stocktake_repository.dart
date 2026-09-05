/// كتابة الجرد عبر **العمليات السحابية المستدعاة الأربع** (`WU-022`).
///
/// ⛔★★ **ولا كتابة مباشرة:** `stocktakes` و`inventory_ledger` و
/// `item_daily_balances` **كلها مغلقة في القواعد** — ⟵ **فكل عملية هنا
/// طلبٌ لا كتابة**، **والمستندُ وحركاتُ تسويته وأرصدتُه وقيدُ تدقيقه في
/// معاملة واحدة** (`ADR-0013` القاعدة 1).
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **ولا حقلَ ماليٍّ في أي حمولة هنا** (`BR-M16-03`) — ★ **غيابٌ
/// بنيويٌّ من الحمولة نفسِها**: ⟵ **فما لا يُرسَل لا يُكتَب.**
///
/// ⛔⛔★★★ **ولا يُرسَل رصيدٌ دفتريٌّ إطلاقاً** — `FR-M16-01` (`bookBalance`
/// 🧮 🔒): ★ **تقيسه السحابةُ من الدفتر وتُجمِّده عند البدء** (`FR-M16-03`)،
/// ⟵ **وإرسالُه من الجهاز كان يكفي لاختلاق فرقٍ لم يقع.**
///
/// ⛔★★ **ولا يُرسَل اسمُ نوعٍ ولا وحدةٌ** — ★ **كلاهما من سجل النوع المقروء
/// داخل المعاملة**، ⟵ **فما لا يُرسَل لا يُزوَّر.**
///
/// ★★ **وتاريخُ المخزون يُرسَل عند جرد يومٍ سابق وحده** — `FR-M16-08`:
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

/// مستودع كتابة الجرد الحقيقي.
final class FunctionsStocktakeRepository implements StocktakeAdminRepository {
  /// ينشئ المستودع.
  const FunctionsStocktakeRepository({
    required CallableClient client,
    required RequestIdFactory newRequestId,
  })  : _client = client,
        _newRequestId = newRequestId;

  final CallableClient _client;
  final RequestIdFactory _newRequestId;

  @override
  Future<Outcome<String>> startStocktake({
    required String sourceId,
    List<String> itemIds = const <String>[],
    CalendarDay? stockDate,
    String? reason,
  }) async {
    final Outcome<Map<String, Object?>> result = await _client.call(
      'startStocktake',
      <String, Object?>{
        'requestId': _newRequestId(),
        'sourceId': sourceId,
        'itemIds': itemIds,
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
  Future<Outcome<void>> approveStocktake({
    required String documentNumber,
    required String sourceId,
    List<StocktakeCountInput> counts = const <StocktakeCountInput>[],
    String? reason,
  }) async =>
      _voidOf(
        await _client.call('approveStocktake', <String, Object?>{
          'requestId': _newRequestId(),
          'documentNumber': documentNumber,
          'sourceId': sourceId,
          'counts': _countsOf(counts),
          'reason': ?_blankToNull(reason),
        }),
      );

  @override
  Future<Outcome<void>> amendStocktake({
    required String documentNumber,
    required String sourceId,
    List<StocktakeCountInput> counts = const <StocktakeCountInput>[],
    String? amendReason,
  }) async =>
      _voidOf(
        await _client.call('amendStocktake', <String, Object?>{
          'requestId': _newRequestId(),
          'documentNumber': documentNumber,
          'sourceId': sourceId,
          'counts': _countsOf(counts),
          // ⛔★★ **ويُرسَل غائباً إن لم يكتبه إنسان** ([`ADR-0020`]).
          'reason': ?_blankToNull(amendReason),
        }),
      );

  @override
  Future<Outcome<void>> cancelStocktake({
    required String documentNumber,
    required String sourceId,
    String? cancelReason,
  }) async =>
      _voidOf(
        await _client.call('cancelStocktake', <String, Object?>{
          'requestId': _newRequestId(),
          'documentNumber': documentNumber,
          'sourceId': sourceId,
          'reason': ?_blankToNull(cancelReason),
        }),
      );

  static Outcome<void> _voidOf(Outcome<Map<String, Object?>> result) =>
      switch (result) {
        Failure<Map<String, Object?>>(:final AppError error) =>
          Failure<void>(error),
        Success<Map<String, Object?>>() => const Success<void>(null),
      };

  static List<Map<String, Object?>> _countsOf(
    List<StocktakeCountInput> counts,
  ) =>
      <Map<String, Object?>>[
        for (final StocktakeCountInput entry in counts)
          <String, Object?>{
            'itemId': entry.itemId,
            'actualCount': switch (entry.actualCount) {
              PieceQuantity(:final PieceCount count) => count.pieces,
              WeightQuantity(:final WeightKg weight) => weight.kilograms,
            },
            // ★★ **وسببُ الفرق اختياريٌّ** — `FR-M16-04` · [`ADR-0020`].
            'differenceReason': ?_blankToNull(entry.differenceReason),
            // ⛔⛔★★★ **ولا `bookBalance` ولا `difference`** — ★ **كلاهما
            //    تحسبه السحابة**: ⟵ **والمُرسَلُ هو ما عُدَّ فعلاً وحده.**
          },
      ];

  /// ★ **الفراغات تُقرأ غياباً لا نصّاً فارغاً** — ([`ADR-0020`] · الطرفان).
  static String? _blankToNull(String? value) {
    if (value == null) return null;
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

/// كتابة التوزيع عبر **العمليات السحابية المستدعاة الثلاث** (`WU-006`).
///
/// ⛔★★ **ولا كتابة مباشرة:** `distributions` و`pricing/current` و
/// `dealer_ledger` و`dealer_balances` و`inventory_ledger` **كلها مغلقة في
/// القواعد** — ⟵ **فكل عملية هنا طلبٌ لا كتابة**، **والمستندُ وأسعارُه
/// وحركاتُه وقيدُه المدين وأرصدتُه وقيدُ تدقيقه في معاملة واحدة**
/// (`ADR-0013` القاعدة 1 · `FR-M10-13` · `GR-51`).
///
/// ⛔★★ **ولا يُرسَل تاريخٌ إطلاقاً** — `FR-M10-03`: **النظام هو من يحدده لا
/// المستخدم** (`A-10` · `GR-14`)، ★ **واليوم من المنصّة داخل المعاملة**.
/// ⟵ ★ **وما لا يُرسَل لا يُزوَّر.**
///
/// ⛔★★ **ولا يُرسَل اسمُ نوعٍ ولا وحدتُه** — ★ **كلاهما من سجل النوع**
/// (`FR-M5-03`)، ⟵ **فلا يُوزّع عميلٌ بوحدةٍ ليست وحدة النوع** (`GR-19`).
///
/// ⚠️⚠️ **والسعر يُرسَل بمفتاحٍ حاضرٍ بقيمة `null` صريحة عند التفريغ** —
/// ⟵ **فالسحابة تُميّز «فرِّغ» من «لا تمسّ»**، ★ **ومفتاحٌ محذوف كان يُبقي
/// السعر القديم قائماً بصمت** (نفس قاعدة التسعير اليومي).
library;

import 'package:qtms_domain/qtms_domain.dart';

import '../../../core/callable/callable_client.dart';
import '../../identity_access/infrastructure/functions_user_admin_repository.dart'
    show RequestIdFactory;

/// مستودع كتابة التوزيع الحقيقي.
final class FunctionsDistributionRepository
    implements DistributionAdminRepository {
  /// ينشئ المستودع.
  const FunctionsDistributionRepository({
    required CallableClient client,
    required RequestIdFactory newRequestId,
  })  : _client = client,
        _newRequestId = newRequestId;

  final CallableClient _client;
  final RequestIdFactory _newRequestId;

  @override
  Future<Outcome<String>> createDistribution(
    ValidatedDistribution distribution,
  ) async {
    final Outcome<Map<String, Object?>> result = await _client.call(
      'createDistribution',
      <String, Object?>{
        'requestId': _newRequestId(),
        'sourceId': distribution.sourceId,
        'dealerId': distribution.dealerId,
        'notes': ?distribution.notes,
        'lines': _linesOf(distribution),
      },
    );
    return switch (result) {
      Failure<Map<String, Object?>>(:final AppError error) =>
        Failure<String>(error),
      // ★ **ويُرجَع المعرّف المركّب لا رقم المستند** — ⟵ **لأنه ما تُفتَح به
      //   التوزيعة وما يُستعلَم به السجل السياقي** (`FR-M18-10`).
      Success<Map<String, Object?>>(:final Map<String, Object?> value) =>
        Success<String>(
          value['distributionId'] as String? ??
              value['documentNumber'] as String? ??
              '',
        ),
    };
  }

  @override
  Future<Outcome<void>> amendDistribution({
    required String documentNumber,
    required ValidatedDistribution distribution,
    String? amendReason,
  }) async {
    final Outcome<Map<String, Object?>> result = await _client.call(
      'amendDistribution',
      <String, Object?>{
        'requestId': _newRequestId(),
        'documentNumber': documentNumber,
        'sourceId': distribution.sourceId,
        'dealerId': distribution.dealerId,
        // ⛔⛔★★ **ولا يُعبَّأ نيابةً عن المستخدم أبداً** (`CLAUDE.md`):
        //    **ما لم يكتبه إنسانٌ لا يُرسَل** — ★ **والسحابة ترفض الفارغ.**
        'reason': ?amendReason,
        'notes': ?distribution.notes,
        'lines': _linesOf(distribution),
      },
    );
    return switch (result) {
      Failure<Map<String, Object?>>(:final AppError error) =>
        Failure<void>(error),
      Success<Map<String, Object?>>() => const Success<void>(null),
    };
  }

  @override
  Future<Outcome<void>> cancelDistribution({
    required String documentNumber,
    required String sourceId,
    required String dealerId,
    String? cancelReason,
  }) async {
    final Outcome<Map<String, Object?>> result = await _client.call(
      'cancelDistribution',
      <String, Object?>{
        'requestId': _newRequestId(),
        'documentNumber': documentNumber,
        'sourceId': sourceId,
        'dealerId': dealerId,
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
  static List<Object?> _linesOf(ValidatedDistribution distribution) =>
      <Object?>[
        for (final ValidatedDistributionLine line in distribution.lines)
          <String, Object?>{
            'itemId': line.itemId,
            'quantity': switch (line.quantity) {
              PieceQuantity(:final PieceCount count) => count.pieces,
              WeightQuantity(:final WeightKg weight) => weight.kilograms,
            },
            // ⛔★★ **حاضرٌ دائماً ولو `null`** — راجع ترويسة الملف.
            'unitPrice': line.unitPrice?.riyals,
            'sackId': ?line.sackId,
            'note': ?line.note,
          },
      ];
}

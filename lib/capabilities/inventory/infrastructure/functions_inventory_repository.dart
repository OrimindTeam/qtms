/// كتابة المخزون عبر **العمليات السحابية المستدعاة** (`WU-003`).
///
/// ⛔★★ **ولا كتابة مباشرة واحدة:** `incoming_count` و`inventory_ledger` و
/// `item_daily_balances` مغلقة في القواعد — ⟵ **فكل عملية هنا طلبٌ لا
/// كتابة**، والحركةُ والرصيدُ وقيدُ التدقيق **في السحابة معاً في معاملة
/// واحدة** (`ADR-0013` القاعدة 1).
///
/// ⛔★★ **ولا يُرسَل تاريخ مخزونٍ إطلاقاً** — `FR-M6-02`: **من الخادم، مقفلاً
/// وغير قابل للتغيير**. ⟵ ★ **وما لا يُرسَل لا يُزوَّر.**
///
/// ★★ **و`requestId` مُولَّد على الجهاز لكل عملية** — وهو **معرّف قيد
/// التدقيق نفسه** (`api-overview.md` §4)، ⟵ **فإعادة الإرسال بعد انقطاع
/// تكتب فوق القيد ولا تُنشئ ثانياً.**
library;

import 'package:qtms_domain/qtms_domain.dart';

import '../../../core/callable/callable_client.dart';
import '../../identity_access/infrastructure/functions_user_admin_repository.dart'
    show RequestIdFactory;

/// مستودع كتابة المخزون الحقيقي.
final class FunctionsInventoryRepository implements InventoryAdminRepository {
  /// ينشئ المستودع.
  const FunctionsInventoryRepository({
    required CallableClient client,
    required RequestIdFactory newRequestId,
  })  : _client = client,
        _newRequestId = newRequestId;

  final CallableClient _client;
  final RequestIdFactory _newRequestId;

  @override
  Future<Outcome<String>> createCountedIntake(
    ValidatedCountedIntake intake,
  ) async {
    final Outcome<Map<String, Object?>> result = await _client.call(
      'createCountedIntake',
      _intakeFields(intake),
    );
    return switch (result) {
      Failure<Map<String, Object?>>(:final AppError error) =>
        Failure<String>(error),
      Success<Map<String, Object?>>(:final Map<String, Object?> value) =>
        _readNumber(value, 'createCountedIntake'),
    };
  }

  @override
  Future<Outcome<void>> amendCountedIntake({
    required String documentNumber,
    required ValidatedCountedIntake intake,
    String? amendReason,
  }) =>
      _voidCall('amendCountedIntake', <String, Object?>{
        ..._intakeFields(intake),
        'documentNumber': documentNumber,
        // ★★ **السبب النصي إلزامي** — `ADR-0004` · `FR-M6-11`.
        'reason': ?amendReason,
      });

  @override
  Future<Outcome<void>> cancelCountedIntake({
    required String documentNumber,
    required String sourceId,
    String? cancelReason,
  }) =>
      _voidCall('cancelCountedIntake', <String, Object?>{
        'requestId': _newRequestId(),
        // ⚠️ **المصدر يُرسَل لفحص النطاق قبل المعاملة** — ★ **والمخزَّن هو
        //   الحَكَم داخلها** (`_existenceGate`)، ⛔ **فلا يُصدَّق المُرسَل.**
        'sourceId': sourceId,
        'documentNumber': documentNumber,
        'reason': ?cancelReason,
      });

  Map<String, Object?> _intakeFields(ValidatedCountedIntake intake) =>
      <String, Object?>{
        'requestId': _newRequestId(),
        'sourceId': intake.sourceId,
        if (intake.supplierId case final String supplierId)
          'supplierId': supplierId,
        if (intake.notes case final String notes) 'notes': notes,
        'lines': <Object?>[
          for (final ValidatedCountedIntakeLine line in intake.lines)
            <String, Object?>{
              'itemId': line.itemId,
              'quantity': line.quantity.pieces,
              if (line.note case final String note) 'note': note,
            },
        ],
        // ⛔★★ **ولا `stockDate` ولا `itemName` ولا `unit` ولا `totalQuantity`:**
        //    ★ **التاريخ من المنصّة**، **والاسم والوحدة من سجل النوع**،
        //    **والإجمالي محسوب** — ⟵ **فلا يُرسل عميلٌ وحدةً تُنشئ حركةً
        //    بوحدةٍ ليست وحدة النوع** (`FR-M5-03` · `GR-19`).
      };

  Future<Outcome<void>> _voidCall(
    String operation,
    Map<String, Object?> data,
  ) async {
    final Outcome<Map<String, Object?>> result =
        await _client.call(operation, data);
    return switch (result) {
      Failure<Map<String, Object?>>(:final AppError error) =>
        Failure<void>(error),
      Success<Map<String, Object?>>() => const Success<void>(null),
    };
  }

  /// ⚠️ **نجاحٌ بلا رقم عطلٌ لا نجاح** — الشاشة تحتاجه لتعرض ما أُنشئ،
  /// ⛔ **وابتلاعُه يُظهر «تمّ» ثم لا يجد المستخدمُ مستنده.**
  static Outcome<String> _readNumber(
    Map<String, Object?> result,
    String operation,
  ) {
    final Object? number = result['documentNumber'];
    if (number is String && number.isNotEmpty) return Success<String>(number);
    return Failure<String>(
      InfrastructureError('استجابة $operation بلا documentNumber'),
    );
  }
}

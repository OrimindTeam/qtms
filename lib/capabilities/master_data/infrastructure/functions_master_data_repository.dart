/// كتابة البيانات المرجعية عبر **العمليات السحابية المستدعاة** (`WU-002`).
///
/// ⛔★★ **ولا كتابة مباشرة واحدة:** المجموعات الخمس وسجلات الحراسة الأربعة
/// مغلقة في القواعد بـ`allow create, update: if false` — ⟵ **فكل عملية هنا
/// طلبٌ لا كتابة**، والقرارُ وحارسُ التفرّد وقيدُ التدقيق **في السحابة معاً
/// في معاملة واحدة** (`ADR-0013` القاعدة 1).
///
/// ★★ **و`requestId` مُولَّد على الجهاز لكل عملية** — وهو **معرّف قيد
/// التدقيق نفسه** (`api-overview.md` §4)، ⟵ **فإعادة الإرسال بعد انقطاع
/// تكتب فوق القيد ولا تُنشئ ثانياً.**
library;

import 'package:qtms_domain/qtms_domain.dart';

import '../../../core/callable/callable_client.dart';
import '../../identity_access/infrastructure/functions_user_admin_repository.dart'
    show RequestIdFactory;

/// مستودع كتابة البيانات المرجعية الحقيقي.
final class FunctionsMasterDataRepository implements MasterDataAdminRepository {
  /// ينشئ المستودع.
  const FunctionsMasterDataRepository({
    required CallableClient client,
    required RequestIdFactory newRequestId,
  })  : _client = client,
        _newRequestId = newRequestId;

  final CallableClient _client;
  final RequestIdFactory _newRequestId;

  // ═════════════════════════════════════════════════════════════════════
  // المصادر
  // ═════════════════════════════════════════════════════════════════════

  @override
  Future<Outcome<String>> createSource(ValidatedSource source) =>
      _createCall('createSource', 'sourceId', _sourceFields(source));

  @override
  Future<Outcome<void>> updateSource({
    required String sourceId,
    required ValidatedSource source,
    String? amendReason,
  }) =>
      _voidCall('updateSource', <String, Object?>{
        ..._sourceFields(source),
        'sourceId': sourceId,
        // ★★ **سبب التعديل إلزامي** — `ADR-0004` · `FR-M2-03`.
        'amendReason': ?amendReason,
      });

  Map<String, Object?> _sourceFields(ValidatedSource source) =>
      <String, Object?>{
        'requestId': _newRequestId(),
        'name': source.name,
        'requiresSupplierOnIntake': source.requiresSupplierOnIntake,
        // ⛔ **الغائب لا يُرسَل مفتاحاً بقيمة فارغة** — والمفتاح الفارغ نيّةٌ
        //    لا غياب.
        if (source.notes != null) 'notes': source.notes,
        'isActive': source.isActive,
        if (source.disableReason != null) 'disableReason': source.disableReason,
        // ⛔★★ **ولا `normalizedName` يُرسَل:** التطبيع **يُعاد في السحابة**
        //    من الدالة نفسها (`ADR-0012`)، ⟵ **فلا يستطيع عميلٌ أن يُرسل
        //    مفتاح تفرّدٍ لا يطابق اسمه** فيتجاوز الحارس.
      };

  // ═════════════════════════════════════════════════════════════════════
  // الرعية
  // ═════════════════════════════════════════════════════════════════════

  @override
  Future<Outcome<String>> createSupplier(ValidatedSupplier supplier) =>
      _createCall('createSupplier', 'supplierId', _supplierFields(supplier));

  @override
  Future<Outcome<void>> updateSupplier({
    required String supplierId,
    required ValidatedSupplier supplier,
    String? amendReason,
  }) =>
      _voidCall('updateSupplier', <String, Object?>{
        ..._supplierFields(supplier),
        'supplierId': supplierId,
        'amendReason': ?amendReason,
      });

  Map<String, Object?> _supplierFields(ValidatedSupplier supplier) =>
      <String, Object?>{
        'requestId': _newRequestId(),
        'sourceIds': supplier.sourceIds,
        'name': supplier.name,
        'phone': supplier.phone,
        if (supplier.notes != null) 'notes': supplier.notes,
        'isActive': supplier.isActive,
        if (supplier.disableReason != null)
          'disableReason': supplier.disableReason,
      };

  // ═════════════════════════════════════════════════════════════════════
  // المقاوته
  // ═════════════════════════════════════════════════════════════════════

  @override
  Future<Outcome<String>> createDealer(ValidatedDealer dealer) =>
      _createCall('createDealer', 'dealerId', _dealerFields(dealer));

  @override
  Future<Outcome<void>> updateDealer({
    required String dealerId,
    required ValidatedDealer dealer,
    String? amendReason,
    String? balanceAcknowledgement,
  }) =>
      _voidCall('updateDealer', <String, Object?>{
        ..._dealerFields(dealer),
        'dealerId': dealerId,
        'amendReason': ?amendReason,
        // ★ **الإقرار يُرسَل ولا يُفحَص هنا** — الرصيد **يُقاس في السحابة**
        //   داخل المعاملة (`FR-M4-09`)، ⛔ **ولا كاشَ في الجهاز يُقرِّر.**
        'balanceAcknowledgement': ?balanceAcknowledgement,
      });

  Map<String, Object?> _dealerFields(ValidatedDealer dealer) =>
      <String, Object?>{
        'requestId': _newRequestId(),
        'name': dealer.name,
        'phone': dealer.phone,
        if (dealer.notes != null) 'notes': dealer.notes,
        'isActive': dealer.isActive,
        if (dealer.disableReason != null) 'disableReason': dealer.disableReason,
        // ⛔★★ **ولا حقل مصدر إطلاقاً** — `FR-M4-04` · `ADR-0005`.
      };

  // ═════════════════════════════════════════════════════════════════════
  // الأنواع
  // ═════════════════════════════════════════════════════════════════════

  @override
  Future<Outcome<String>> createItem(ValidatedItem item) =>
      _createCall('createItem', 'itemId', _itemFields(item));

  @override
  Future<Outcome<void>> updateItem({
    required String itemId,
    required ValidatedItem item,
    String? amendReason,
  }) =>
      _voidCall('updateItem', <String, Object?>{
        ..._itemFields(item),
        'itemId': itemId,
        'amendReason': ?amendReason,
      });

  Map<String, Object?> _itemFields(ValidatedItem item) => <String, Object?>{
        'requestId': _newRequestId(),
        'sourceIds': item.sourceIds,
        'name': item.name,
        'nature': item.nature.name,
        if (item.pieceWeightGrams != null)
          'pieceWeightGrams': item.pieceWeightGrams,
        'isActive': item.isActive,
        if (item.disableReason != null) 'disableReason': item.disableReason,
        // ⛔★★ **ولا `unit` ولا `isSystemDefault` ولا أي حقل سعر:**
        //    الوحدة **مشتقّة في طبقة النطاق** (`FR-M5-03`)، والنوع الافتراضي
        //    **من السحابة فقط** (`FR-M5-05`)، ★ **والسعر مرفوض على السجل**
        //    (`FR-M5-09`) — ⟵ **والدالة تُبطل الطلب كله بأيٍّ منها.**
      };

  // ═════════════════════════════════════════════════════════════════════
  // ★★ الإعداد التأسيسي — مرة واحدة، ومعه «السكرب» (`IQ-012`)
  // ═════════════════════════════════════════════════════════════════════

  @override
  Future<Outcome<void>> writeAppSettings(ValidatedAppSettings settings) =>
      _voidCall('writeAppSettings', <String, Object?>{
        'requestId': _newRequestId(),
        'businessName': settings.businessName,
        if (settings.logo != null) 'logo': settings.logo,
        if (settings.phone != null) 'phone': settings.phone,
        if (settings.address != null) 'address': settings.address,
        'currencySymbol': settings.currencySymbol,
        'thousandsSeparator': settings.thousandsSeparator,
        // ⛔★★ **ولا `decimalPlaces` يُرسَل** — **صفرٌ حتماً** (`ADR-0015`)،
        //    ⟵ **وإرسالُه كان سيَعِد بعرضٍ لا يقابله تخزين.**
      });

  Future<Outcome<String>> _createCall(
    String operation,
    String idField,
    Map<String, Object?> data,
  ) async {
    final Outcome<Map<String, Object?>> result =
        await _client.call(operation, data);
    return switch (result) {
      Failure<Map<String, Object?>>(:final AppError error) =>
        Failure<String>(error),
      Success<Map<String, Object?>>(:final Map<String, Object?> value) =>
        _readId(value, idField, operation),
    };
  }

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

  /// ⚠️ **نجاحٌ بلا معرّف عطلٌ لا نجاح** — الشاشة تحتاجه لتفتح بطاقة ما
  /// أُنشئ، ⛔ **وابتلاعُه يُظهر «تمّ» ثم لا يجد المستخدمَ أحدٌ.**
  static Outcome<String> _readId(
    Map<String, Object?> result,
    String idField,
    String operation,
  ) {
    final Object? id = result[idField];
    if (id is String && id.isNotEmpty) return Success<String>(id);
    return Failure<String>(
      InfrastructureError('استجابة $operation بلا $idField'),
    );
  }
}

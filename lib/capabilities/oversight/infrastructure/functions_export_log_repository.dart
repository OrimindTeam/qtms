/// تسجيل التصدير عبر العملية السحابية `logExport` (`WU-010`).
///
/// ⛔★★ **ولا كتابة مباشرة:** `audit_log` **مغلقة للإنشاء والتعديل والحذف
/// لكل مستخدم بلا استثناء** — ⟵ **فهذا نداءٌ لا كتابة** (`ADR-0013` ·
/// `IQ-032` الخيار أ).
///
/// ⚠️⚠️ **وفشلُ التسجيل لا يُبتلَع ولا يُخفي الملف:** ★ **الملف يُبنى ويُشارَك
/// أولاً، ثم يُسجَّل** — ⟵ **فرفضُ السحابة يصل المستخدمَ رسالةً صريحة**،
/// ⛔ **ولا يُلغى مخرَجٌ صار بيده أصلاً.** ★ **والترتيب مقصود ومُعلَن في
/// `messaging-design.md` §9.**
library;

import 'package:qtms_domain/qtms_domain.dart';

import '../../../core/callable/callable_client.dart';
import '../../identity_access/infrastructure/functions_user_admin_repository.dart'
    show RequestIdFactory;

/// مستودع تسجيل التصدير الحقيقي.
final class FunctionsExportLogRepository implements ExportLogRepository {
  /// ينشئ المستودع.
  const FunctionsExportLogRepository({
    required CallableClient client,
    required RequestIdFactory newRequestId,
  })  : _client = client,
        _newRequestId = newRequestId;

  final CallableClient _client;
  final RequestIdFactory _newRequestId;

  @override
  Future<Outcome<void>> logExport({
    required String sourceId,
    required String entityType,
    required String entityId,
    required ExportedFormat format,
    String? documentNumber,
  }) async {
    final Outcome<Map<String, Object?>> result = await _client.call(
      'logExport',
      <String, Object?>{
        'requestId': _newRequestId(),
        'sourceId': sourceId,
        'entityType': entityType,
        'entityId': entityId,
        'exportFormat': format.wireName,
        'documentNumber': ?documentNumber,
      },
    );
    return switch (result) {
      Failure<Map<String, Object?>>(:final AppError error) =>
        Failure<void>(error),
      Success<Map<String, Object?>>() => const Success<void>(null),
    };
  }
}

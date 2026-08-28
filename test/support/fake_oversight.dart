/// بدائل اختبارية لسجل التدقيق — ★ **فلا اختبار يمسّ سحابة ولا شبكة**
/// (`ADR-0010`: حقن اعتمادية صريح · `test-strategy.md`).
///
/// ⛔⛔★★ **ولا نظيرَ كاتبٍ هنا ولا في الأصل:** `AuditLogDirectory` **عقدُ
/// قراءةٍ محض** (`FR-M18-01` · `FR-M18-04`) — ★ **والبديل يطابقه حرفياً**،
/// ⟵ **فلا يُغري اختبارٌ بكتابة قيدٍ لا مسارَ لها في الإنتاج.**
library;

import 'dart:async';

import 'package:qtms_domain/qtms_domain.dart';

/// دليل سجل تدقيق يُتحكَّم به — ★ **والخطأ يُبثّ كخطأ لا كقائمة فارغة**،
/// ⟵ **فيُختبَر تمييز الشاشة بين «ممنوع» و«لا نشاط»** (`FR-M18-12`).
final class FakeAuditLogDirectory implements AuditLogDirectory {
  final StreamController<List<AuditLogEntryCard>> _central =
      StreamController<List<AuditLogEntryCard>>.broadcast();
  final Map<AuditEntityRef, StreamController<List<AuditLogEntryCard>>> _entity =
      <AuditEntityRef, StreamController<List<AuditLogEntryCard>>>{};

  List<AuditLogEntryCard>? _currentCentral;
  Object? _centralError;
  final Map<AuditEntityRef, List<AuditLogEntryCard>> _currentEntity =
      <AuditEntityRef, List<AuditLogEntryCard>>{};

  /// ★ آخر فلترٍ طُلب — ⛔ **يُثبت أن الشاشة تستعلم بما اختاره المستخدم**
  /// لا بفلترٍ ثابت.
  AuditLogFilter? lastFilter;

  /// ★ آخر كيانٍ فُتح سجلُّه — ⛔ **يُثبت أن الورقة تسأل عن الكيان الصحيح.**
  AuditEntityRef? lastEntity;

  /// ★ آخر حدٍّ طُلب — ⛔ **يُثبت أن السجل لا يُقرأ كاملاً** (`§8`).
  int? lastLimit;

  /// يبثّ قيود الشاشة المركزية.
  void emitCentral(List<AuditLogEntryCard> value) {
    _currentCentral = value;
    _central.add(value);
  }

  /// ★ يبثّ رفضاً — ⛔ **لا قائمة فارغة**.
  void emitCentralError(Object error) {
    _centralError = error;
    _central.addError(error);
  }

  /// يبثّ قيود كيانٍ بعينه.
  void emitEntity(AuditEntityRef entity, List<AuditLogEntryCard> value) {
    _currentEntity[entity] = value;
    _controllerFor(entity).add(value);
  }

  StreamController<List<AuditLogEntryCard>> _controllerFor(
    AuditEntityRef entity,
  ) =>
      _entity.putIfAbsent(
        entity,
        StreamController<List<AuditLogEntryCard>>.broadcast,
      );

  @override
  Stream<List<AuditLogEntryCard>> watchCentralLog({
    required AuditLogFilter filter,
    int limit = auditLogPageSize,
  }) async* {
    lastFilter = filter;
    lastLimit = limit;
    if (_centralError case final Object error) {
      yield* Stream<List<AuditLogEntryCard>>.error(error);
    }
    if (_currentCentral case final List<AuditLogEntryCard> value) yield value;
    yield* _central.stream;
  }

  @override
  Stream<List<AuditLogEntryCard>> watchEntityLog({
    required AuditEntityRef entity,
    int limit = auditLogPageSize,
  }) async* {
    lastEntity = entity;
    lastLimit = limit;
    if (_currentEntity[entity] case final List<AuditLogEntryCard> value) {
      yield value;
    }
    yield* _controllerFor(entity).stream;
  }
}

/// قيدٌ اختباري بأقل ما يلزم — ★ **يُعدَّل في كل اختبار حسب حاجته.**
AuditLogEntryCard testAuditEntry({
  String id = 'REQ-1',
  DateTime? occurredAt,
  String userName = 'عبدالفتاح',
  AuditAction? action = AuditAction.amend,
  String entityType = 'countedIntake',
  String entityId = 'INC-20260827-0001',
  String sourceId = 'SRC-001',
  String? documentNumber,
  CalendarDay? stockDate,
  Map<String, Object?> before = const <String, Object?>{},
  Map<String, Object?> after = const <String, Object?>{},
  String? reason = 'تصحيح كمية',
}) =>
    AuditLogEntryCard(
      id: id,
      occurredAt: occurredAt ?? DateTime.utc(2026, 8, 27, 9, 15),
      userId: 'U-001',
      userName: userName,
      action: action,
      entityType: entityType,
      entityId: entityId,
      sourceId: sourceId,
      documentNumber: documentNumber,
      stockDate: stockDate,
      valuesBefore: before,
      valuesAfter: after,
      reason: reason,
    );

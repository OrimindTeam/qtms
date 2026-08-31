/// بديلٌ اختباري لدليل المركز المعلّق — ★ **فلا اختبار يمسّ سحابة ولا شبكة**
/// (`ADR-0010` · `test-strategy.md`).
///
/// ⛔⛔★★ **ولا نظيرَ كاتبٍ هنا ولا في الأصل:** `PendingEntryDirectory`
/// **عقدُ قراءةٍ محض** (`FR-SYS-09`) — ★ **والبديل يطابقه حرفياً**،
/// ⟵ **فلا يُغري اختبارٌ بكتابة بندٍ لا مسارَ لها في الإنتاج.**
library;

import 'dart:async';

import 'package:qtms_domain/qtms_domain.dart';

/// دليل مركزٍ يُتحكَّم به — ★ **والخطأ يُبثّ كخطأ لا كقائمة فارغة**،
/// ⟵ **فيُختبَر تمييز الشاشة بين «ممنوع» و«لا قيمة معلّقة».**
final class FakePendingEntryDirectory implements PendingEntryDirectory {
  final Map<String, StreamController<List<PendingEntryCard>>> _controllers =
      <String, StreamController<List<PendingEntryCard>>>{};
  final Map<String, List<PendingEntryCard>> _current =
      <String, List<PendingEntryCard>>{};
  final Map<String, Object> _errors = <String, Object>{};

  /// ★ آخر فلترٍ طُلب — ⛔ **يُثبت أن الشاشة تستعلم بما اختاره المستخدم.**
  PendingEntryFilter? lastFilter;

  /// ★ آخر حدٍّ طُلب — ⛔ **يُثبت أن المركز لا يُقرأ بلا حدّ.**
  int? lastLimit;

  /// يبثّ بنود مصدرٍ بعينه.
  void emit(String sourceId, List<PendingEntryCard> value) {
    _current[sourceId] = value;
    _controllerFor(sourceId).add(value);
  }

  /// ★ يبثّ رفضاً — ⛔ **لا قائمة فارغة**.
  void emitError(String sourceId, Object error) {
    _errors[sourceId] = error;
    _controllerFor(sourceId).addError(error);
  }

  StreamController<List<PendingEntryCard>> _controllerFor(String sourceId) =>
      _controllers.putIfAbsent(
        sourceId,
        StreamController<List<PendingEntryCard>>.broadcast,
      );

  @override
  Stream<List<PendingEntryCard>> watchPending({
    required PendingEntryFilter filter,
    int limit = pendingEntriesPageSize,
  }) async* {
    lastFilter = filter;
    lastLimit = limit;
    if (_errors[filter.sourceId] case final Object error) {
      yield* Stream<List<PendingEntryCard>>.error(error);
    }
    if (_current[filter.sourceId] case final List<PendingEntryCard> value) {
      // ★★ **والفلترُ بالنوع يُطبَّق هنا كما يُطبَّق في الدليل الحقيقي** —
      //    ⟵ **فلا يمرّ اختبارٌ على بديلٍ أرحم من الأصل** (`DEBT-37`).
      yield <PendingEntryCard>[
        for (final PendingEntryCard card in value)
          if (filter.accepts(card)) card,
      ];
    }
    yield* _controllerFor(filter.sourceId).stream.map(
          (List<PendingEntryCard> value) => <PendingEntryCard>[
            for (final PendingEntryCard card in value)
              if (filter.accepts(card)) card,
          ],
        );
  }
}

/// بندٌ اختباري بأقل ما يلزم — ★ **يُعدَّل في كل اختبار حسب حاجته.**
PendingEntryCard testPendingEntry({
  String id = 'sack_SCK-20260830-0001_sackTax',
  PendingDocumentKind? kind = PendingDocumentKind.sack,
  String documentId = 'SCK-20260830-0001',
  String readableTitle = 'عبد الفتاح - جونية رقم ١',
  String sourceId = 'SRC-001',
  CalendarDay? date,
  String missingField = 'ضريبة الكيلو',
  PendingMissingField? field = PendingMissingField.sackTax,
  String? documentNumber = 'SCK-20260830-0001',
}) =>
    PendingEntryCard(
      id: id,
      kind: kind,
      documentId: documentId,
      readableTitle: readableTitle,
      sourceId: sourceId,
      date: date ?? CalendarDay(2026, 8, 30),
      missingField: missingField,
      field: field,
      documentNumber: documentNumber,
    );

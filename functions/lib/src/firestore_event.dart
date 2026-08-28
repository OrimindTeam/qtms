/// نموذج حدث كتابة على قاعدة البيانات كما يصل عبر Eventarc.
///
/// ★ **حقيقة رصدها `DEBT-09` بالتشغيل (2026-08-22):** Eventarc **لا يقبل
/// لأحداث قاعدة البيانات إلا `application/protobuf`** — وصيغة JSON مرفوضة
/// **عند إنشاء المشغّل** برسالة صريحة، لا عند التشغيل. وفكّ protobuf بلغة
/// Dart يحتاج توليد أنواع `DocumentEventData` — **وهو `DEBT-16` ولم يُنجَز**.
///
/// ★ **ولذلك يفكّ هذا الملف على مستويين:**
///   ① **الحمولة كاملةً** حين تصل JSON — وهو حال الاستدعاء المباشر والاختبار.
///   ② ★ **سمات الحدث وحدها** حين تصل ثنائية — فمسار المستند ونوع التغيير
///      يصلان في `subject` و`type` **خارج الحمولة**، فيُعرَف **أي مستند
///      تغيّر وكيف** بلا أي فكّ. ⛔ **ولا تُعرَف قيم الحقول** —
///      و`FirestoreDocumentEvent.payloadDecoded` يقول ذلك صراحةً بدل أن
///      يُوهم بخريطة فارغة أنها مستند بلا حقول.
library;

import 'firestore_value.dart';

/// نوع التغيير الذي وقع على المستند.
enum DocumentChangeKind {
  /// أُنشئ المستند.
  created,

  /// عُدِّل المستند.
  updated,

  /// حُذف المستند — ⛔ **لا يقع في هذا النظام** (`ADR-0004`)، ووجوده مؤشر خلل.
  deleted;

  /// يشتقّ النوع من `type` في CloudEvent — مثل
  /// `google.cloud.firestore.document.v1.created`.
  static DocumentChangeKind? fromEventType(String eventType) {
    if (eventType.endsWith('.created')) return DocumentChangeKind.created;
    if (eventType.endsWith('.updated')) return DocumentChangeKind.updated;
    if (eventType.endsWith('.deleted')) return DocumentChangeKind.deleted;
    return null;
  }
}

/// حدث كتابة مفكوك — القيمتان قبل وبعد، ومسار المستند ومجموعته.
final class FirestoreDocumentEvent {
  const FirestoreDocumentEvent({
    required this.kind,
    required this.documentPath,
    required this.valuesBefore,
    required this.valuesAfter,
    required this.changedFieldPaths,
    required this.payloadDecoded,
  });

  /// يفكّ الحدث من حمولة `DocumentEventData` بصيغة JSON.
  ///
  /// [eventType] من حقل `type` في CloudEvent، و[subject] من حقل `subject`
  /// وصيغته `documents/<المسار>`.
  static FirestoreDocumentEvent? tryParse({
    required String eventType,
    required String? subject,
    required Object? data,
  }) {
    final DocumentChangeKind? kind =
        DocumentChangeKind.fromEventType(eventType);
    if (kind == null) return null;
    if (data is! Map<String, Object?>) return null;

    final String? path = _documentPathFrom(subject, data);
    if (path == null) return null;

    final Object? before = data['oldValue'];
    final Object? after = data['value'];

    return FirestoreDocumentEvent(
      kind: kind,
      payloadDecoded: true,
      documentPath: path,
      valuesBefore: before is Map<String, Object?>
          ? decodeFirestoreFields(before['fields'])
          : const <String, Object?>{},
      valuesAfter: after is Map<String, Object?>
          ? decodeFirestoreFields(after['fields'])
          : const <String, Object?>{},
      changedFieldPaths: _changedPathsFrom(data['updateMask']),
    );
  }

  /// يفكّ سمات الحدث وحدها — للحمولة الثنائية (protobuf).
  ///
  /// يُرجِع `null` إن تعذّر حتى معرفة **أي مستند تغيّر** — فلا معنى لأثر بلا
  /// مسار. و[payloadDecoded] في الناتج **`false` دائماً**.
  static FirestoreDocumentEvent? tryParseAttributesOnly({
    required String eventType,
    required String? subject,
  }) {
    final DocumentChangeKind? kind =
        DocumentChangeKind.fromEventType(eventType);
    if (kind == null) return null;

    final String? path = _documentPathFrom(subject, const <String, Object?>{});
    if (path == null) return null;

    return FirestoreDocumentEvent(
      kind: kind,
      payloadDecoded: false,
      documentPath: path,
      valuesBefore: const <String, Object?>{},
      valuesAfter: const <String, Object?>{},
      changedFieldPaths: const <String>[],
    );
  }

  final DocumentChangeKind kind;

  /// هل فُكَّت حمولة الحدث فعلاً؟
  ///
  /// ⚠️ **`false` يعني أن الحقول غير معلومة، لا أنها فارغة** — والفرق جوهري
  /// في سجل تدقيق (`DEBT-16`).
  final bool payloadDecoded;

  /// المسار النسبي للمستند — مثل `sources/SRC-001`.
  final String documentPath;

  final Map<String, Object?> valuesBefore;
  final Map<String, Object?> valuesAfter;

  /// الحقول التي مسّها التعديل — أساس قاعدة «الحقول المتغيرة فقط»
  /// (`audit-log-design.md` §3 و§8).
  final List<String> changedFieldPaths;

  /// اسم المجموعة — أول جزء من المسار.
  String get collectionId => documentPath.split('/').first;

  /// معرّف المستند — آخر جزء من المسار.
  String get documentId => documentPath.split('/').last;

  static String? _documentPathFrom(String? subject, Map<String, Object?> data) {
    // المسار المفضَّل: `subject` وصيغته `documents/sources/SRC-001`.
    const String marker = 'documents/';
    if (subject != null) {
      final int at = subject.indexOf(marker);
      if (at >= 0) {
        final String path = subject.substring(at + marker.length);
        if (path.isNotEmpty) return path;
      }
    }
    // بديل: `name` داخل الحمولة نفسها — يغطي حالة غياب `subject`.
    for (final String key in const <String>['value', 'oldValue']) {
      final Object? node = data[key];
      if (node is! Map<String, Object?>) continue;
      final Object? name = node['name'];
      if (name is! String) continue;
      final int at = name.indexOf(marker);
      if (at >= 0 && at + marker.length < name.length) {
        return name.substring(at + marker.length);
      }
    }
    return null;
  }

  static List<String> _changedPathsFrom(Object? updateMask) {
    if (updateMask is! Map<String, Object?>) return const <String>[];
    final Object? paths = updateMask['fieldPaths'];
    if (paths is! List<Object?>) return const <String>[];
    return paths.whereType<String>().toList();
  }
}

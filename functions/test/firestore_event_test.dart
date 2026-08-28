import 'package:qtms_functions/src/firestore_event.dart';
import 'package:test/test.dart';

/// حمولة مطابقة لشكل `DocumentEventData` كما يسلّمها Eventarc بصيغة JSON.
Map<String, Object?> _payload({
  Map<String, Object?>? oldFields,
  Map<String, Object?>? newFields,
  List<String>? updatedPaths,
  String name =
      'projects/qtms-orimind-master/databases/(default)/documents/sources/SRC-001',
}) {
  Map<String, Object?> wrap(Map<String, Object?> fields) =>
      <String, Object?>{
        'name': name,
        'fields': fields.map(
          (String key, Object? value) => MapEntry<String, Object?>(
            key,
            <String, Object?>{'stringValue': value.toString()},
          ),
        ),
      };

  return <String, Object?>{
    if (oldFields != null) 'oldValue': wrap(oldFields),
    if (newFields != null) 'value': wrap(newFields),
    if (updatedPaths != null)
      'updateMask': <String, Object?>{'fieldPaths': updatedPaths},
  };
}

void main() {
  const String createdType = 'google.cloud.firestore.document.v1.created';
  const String updatedType = 'google.cloud.firestore.document.v1.updated';
  const String subject = 'documents/sources/SRC-001';

  group('DocumentChangeKind', () {
    test('يشتقّ النوع من لاحقة نوع الحدث', () {
      expect(DocumentChangeKind.fromEventType(createdType),
          DocumentChangeKind.created);
      expect(DocumentChangeKind.fromEventType(updatedType),
          DocumentChangeKind.updated);
      expect(
        DocumentChangeKind.fromEventType(
            'google.cloud.firestore.document.v1.deleted'),
        DocumentChangeKind.deleted,
      );
    });

    test('نوع غير معروف يُرجِع null ولا يُخمَّن', () {
      expect(DocumentChangeKind.fromEventType('com.example.other'), isNull);
    });
  });

  group('FirestoreDocumentEvent.tryParse', () {
    test('يفكّ حدث إنشاء ويستخرج المسار والمجموعة والمعرّف', () {
      final FirestoreDocumentEvent? event = FirestoreDocumentEvent.tryParse(
        eventType: createdType,
        subject: subject,
        data: _payload(newFields: <String, Object?>{'name': 'المصدر الأول'}),
      );

      expect(event, isNotNull);
      expect(event!.kind, DocumentChangeKind.created);
      expect(event.documentPath, 'sources/SRC-001');
      expect(event.collectionId, 'sources');
      expect(event.documentId, 'SRC-001');
      expect(event.valuesBefore, isEmpty);
      expect(event.valuesAfter, <String, Object?>{'name': 'المصدر الأول'});
    });

    test('يفكّ حدث تعديل ويحمل الحقول المتغيرة وحدها', () {
      final FirestoreDocumentEvent? event = FirestoreDocumentEvent.tryParse(
        eventType: updatedType,
        subject: subject,
        data: _payload(
          oldFields: <String, Object?>{'name': 'قبل'},
          newFields: <String, Object?>{'name': 'بعد'},
          updatedPaths: <String>['name'],
        ),
      );

      expect(event!.changedFieldPaths, <String>['name']);
      expect(event.valuesBefore['name'], 'قبل');
      expect(event.valuesAfter['name'], 'بعد');
    });

    test('يستخرج المسار من الحمولة عند غياب subject', () {
      final FirestoreDocumentEvent? event = FirestoreDocumentEvent.tryParse(
        eventType: createdType,
        subject: null,
        data: _payload(newFields: <String, Object?>{'name': 'س'}),
      );

      expect(event!.documentPath, 'sources/SRC-001');
    });

    test('يفكّ مساراً متداخلاً (مجموعة فرعية) كاملاً', () {
      final FirestoreDocumentEvent? event = FirestoreDocumentEvent.tryParse(
        eventType: createdType,
        subject: 'documents/sacks/SCK-1/pricing/current',
        data: _payload(newFields: <String, Object?>{'x': '1'}),
      );

      expect(event!.documentPath, 'sacks/SCK-1/pricing/current');
      expect(event.collectionId, 'sacks');
      expect(event.documentId, 'current');
    });

    test('يُرجِع null لحدث غير مفهوم بدل تخمين محتواه', () {
      expect(
        FirestoreDocumentEvent.tryParse(
            eventType: 'com.example.other', subject: subject, data: _payload()),
        isNull,
      );
      expect(
        FirestoreDocumentEvent.tryParse(
            eventType: createdType, subject: subject, data: 'not-a-map'),
        isNull,
      );
      // لا subject ولا name — فلا مسار يُشتقّ.
      expect(
        FirestoreDocumentEvent.tryParse(
            eventType: createdType,
            subject: null,
            data: <String, Object?>{'value': <String, Object?>{}}),
        isNull,
      );
    });
  });
}

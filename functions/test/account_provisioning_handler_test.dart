import 'package:qtms_functions/src/account_provisioning_handler.dart';
import 'package:qtms_functions/src/firestore_writer.dart';
import 'package:test/test.dart';

/// كتابة مسجَّلة — لفحص **ماذا كُتب وبأي قناع**.
final class RecordedWrite {
  const RecordedWrite(this.collectionId, this.documentId, this.data, this.mask);

  final String collectionId;
  final String documentId;
  final Map<String, Object?> data;
  final List<String>? mask;

  String get path => '$collectionId/$documentId';
}

/// قاعدة مزيّفة — ★ **تسجّل كل قراءة وكتابة**، ⛔ بلا أي شبكة.
final class FakeStore implements ProvisioningStore {
  FakeStore({
    this.collections = const <String, List<String>>{},
    this.scrap,
  });

  final Map<String, List<String>> collections;
  final StoredDocument? scrap;

  final List<String> listed = <String>[];
  final List<RecordedWrite> writes = <RecordedWrite>[];
  int scrapLookups = 0;

  @override
  Future<List<String>> listDocumentIds(String collectionId) async {
    listed.add(collectionId);
    return collections[collectionId] ?? const <String>[];
  }

  @override
  Future<StoredDocument?> findFirstWhereTrue({
    required String collectionId,
    required String field,
  }) async {
    scrapLookups++;
    return scrap;
  }

  @override
  Future<void> writeDocument({
    required String collectionId,
    required String documentId,
    required Map<String, Object?> data,
    List<String>? updateMask,
  }) async {
    writes.add(RecordedWrite(collectionId, documentId, data, updateMask));
  }
}

const String createdType = 'google.cloud.firestore.document.v1.created';
const String updatedType = 'google.cloud.firestore.document.v1.updated';

void main() {
  group('إضافة مصدر — حساب لكل طرف + نسخة السكرب', () {
    test('يُكتب حساب لكل مقوت ولكل رعوي، ويُوصَل السكرب', () async {
      final FakeStore store = FakeStore(
        collections: <String, List<String>>{
          'dealers': <String>['DLR-001', 'DLR-002'],
          'suppliers': <String>['SUP-001'],
        },
        scrap: const StoredDocument(
          id: 'ITM-0001',
          fields: <String, Object?>{
            'sourceIds': <String>['SRC-001'],
          },
        ),
      );

      final ProvisioningOutcome outcome =
          await AccountProvisioningHandler(store).handleEvent(
        eventType: createdType,
        subject: 'documents/sources/SRC-002',
      );

      expect(outcome.kind, ProvisioningOutcomeKind.applied);
      expect(
        store.writes.map((RecordedWrite w) => w.path),
        containsAll(<String>[
          'dealer_balances/DLR-001_SRC-002',
          'dealer_balances/DLR-002_SRC-002',
          'supplier_balances/SUP-001_SRC-002',
          'items/ITM-0001',
        ]),
      );
      expect(outcome.documentsWritten, 4);
    });

    test('★★ وقناع الكتابة يُمرَّر للسكرب — وبدونه تُمحى بقية حقول النوع',
        () async {
      final FakeStore store = FakeStore(
        scrap: const StoredDocument(
          id: 'ITM-0001',
          fields: <String, Object?>{
            'sourceIds': <String>['SRC-001'],
          },
        ),
      );

      await AccountProvisioningHandler(store).handleEvent(
        eventType: createdType,
        subject: 'documents/sources/SRC-002',
      );

      final RecordedWrite w =
          store.writes.firstWhere((RecordedWrite w) => w.collectionId == 'items');
      expect(w.mask, <String>['sourceIds']);
      // ★ اتحاد لا استبدال — المصدر السابق باقٍ.
      expect(w.data['sourceIds'], <String>['SRC-001', 'SRC-002']);
    });

    test('★ والسكرب الغائب يُبلَّغ عنه ⛔ ولا يُخترَع', () async {
      final FakeStore store = FakeStore(
        collections: <String, List<String>>{
          'dealers': <String>['DLR-001'],
        },
      );

      final ProvisioningOutcome outcome =
          await AccountProvisioningHandler(store).handleEvent(
        eventType: createdType,
        subject: 'documents/sources/SRC-002',
      );

      expect(outcome.scrapMissing, isTrue);
      expect(
        store.writes.where((RecordedWrite w) => w.collectionId == 'items'),
        isEmpty,
      );
    });
  });

  group('إضافة طرف — حساب له في كل المصادر', () {
    test('المقوت الجديد يُهيَّأ له حساب في كل مصدر', () async {
      final FakeStore store = FakeStore(
        collections: <String, List<String>>{
          'sources': <String>['SRC-001', 'SRC-002'],
        },
      );

      final ProvisioningOutcome outcome =
          await AccountProvisioningHandler(store).handleEvent(
        eventType: createdType,
        subject: 'documents/dealers/DLR-007',
      );

      expect(outcome.kind, ProvisioningOutcomeKind.applied);
      expect(
        store.writes.map((RecordedWrite w) => w.path),
        <String>[
          'dealer_balances/DLR-007_SRC-001',
          'dealer_balances/DLR-007_SRC-002',
        ],
      );
    });

    test('★ ولا تُقرأ مجموعة لا تلزم — ولا يُبحَث عن السكرب أصلاً', () async {
      final FakeStore store = FakeStore(
        collections: <String, List<String>>{
          'sources': <String>['SRC-001'],
        },
      );

      await AccountProvisioningHandler(store).handleEvent(
        eventType: createdType,
        subject: 'documents/dealers/DLR-007',
      );

      // ⛔ لا الرعوية ولا أرصدتهم — فإضافة مقوت لا تمسّهم.
      expect(store.listed, isNot(contains('suppliers')));
      expect(store.listed, isNot(contains('supplier_balances')));
      expect(store.scrapLookups, 0);
    });
  });

  group('★★★ لا يلمس القائم — وإعادة التشغيل بلا أثر جانبي', () {
    test('★★ الحساب القائم لا يُكتب فوقه', () async {
      final FakeStore store = FakeStore(
        collections: <String, List<String>>{
          'sources': <String>['SRC-001', 'SRC-002'],
          'dealer_balances': <String>['DLR-007_SRC-001'],
        },
      );

      await AccountProvisioningHandler(store).handleEvent(
        eventType: createdType,
        subject: 'documents/dealers/DLR-007',
      );

      expect(
        store.writes.map((RecordedWrite w) => w.path),
        <String>['dealer_balances/DLR-007_SRC-002'],
        reason: '⛔ كُتب فوق حساب قائم — وهذا محوُ رصيد',
      );
    });

    test('★ والتشغيل الثاني على حالة مكتملة لا يكتب شيئاً', () async {
      final FakeStore store = FakeStore(
        collections: <String, List<String>>{
          'sources': <String>['SRC-001'],
          'dealer_balances': <String>['DLR-007_SRC-001'],
        },
      );

      final ProvisioningOutcome outcome =
          await AccountProvisioningHandler(store).handleEvent(
        eventType: createdType,
        subject: 'documents/dealers/DLR-007',
      );

      expect(outcome.kind, ProvisioningOutcomeKind.nothingToDo);
      expect(store.writes, isEmpty);
    });
  });

  group('الأحداث التي لا تخصّ التهيئة', () {
    test('التعديل يُجوهَل — والإنشاء وحده يُهيِّئ', () async {
      final FakeStore store = FakeStore();
      final ProvisioningOutcome outcome =
          await AccountProvisioningHandler(store).handleEvent(
        eventType: updatedType,
        subject: 'documents/sources/SRC-002',
      );

      expect(outcome.kind, ProvisioningOutcomeKind.ignored);
      expect(store.listed, isEmpty);
    });

    test('مجموعة أخرى تُجوهَل ⛔ ولا تُقرأ القاعدة أصلاً', () async {
      final FakeStore store = FakeStore();
      final ProvisioningOutcome outcome =
          await AccountProvisioningHandler(store).handleEvent(
        eventType: createdType,
        subject: 'documents/receipts/RCP-001',
      );

      expect(outcome.kind, ProvisioningOutcomeKind.ignored);
      expect(store.listed, isEmpty);
    });

    test('★ ومستند فرعي يُجوهَل — التهيئة لجذر المجموعة وحده', () async {
      final FakeStore store = FakeStore();
      final ProvisioningOutcome outcome =
          await AccountProvisioningHandler(store).handleEvent(
        eventType: createdType,
        subject: 'documents/sources/SRC-002/audit/current',
      );

      expect(outcome.kind, ProvisioningOutcomeKind.ignored);
    });

    test('حدث بلا مسار يُرفَض ⛔ ولا يُبتلَع صامتاً', () async {
      final FakeStore store = FakeStore();
      final ProvisioningOutcome outcome =
          await AccountProvisioningHandler(store).handleEvent(
        eventType: createdType,
        subject: null,
      );

      expect(outcome.kind, ProvisioningOutcomeKind.rejected);
    });
  });

  group('صلابة القراءة', () {
    test('★ نوعٌ افتراضي بلا حقل مصادر يُوصَل بلا انهيار', () async {
      final FakeStore store = FakeStore(
        scrap: const StoredDocument(id: 'ITM-0001', fields: <String, Object?>{}),
      );

      final ProvisioningOutcome outcome =
          await AccountProvisioningHandler(store).handleEvent(
        eventType: createdType,
        subject: 'documents/sources/SRC-002',
      );

      expect(outcome.kind, ProvisioningOutcomeKind.applied);
      final RecordedWrite w = store.writes.single;
      expect(w.data['sourceIds'], <String>['SRC-002']);
    });
  });
}

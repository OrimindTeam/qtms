/// كتابة المستندات عبر واجهة REST الرسمية لقاعدة البيانات.
///
/// ★ **الاعتماد على بيانات الاعتماد الافتراضية للتطبيق (ADC)** — لا مفتاح
/// ولا سرّ في أي ملف (`coding-standards.md` §2.4 · `secrets-management-policy.md`).
/// على Cloud Run تأتي الهوية من **حساب الخدمة المرفق بالخدمة**، ومحلياً من
/// `gcloud auth application-default login`.
///
/// ⚠️ **وهذا المسار يتجاوز قواعد الحماية** لأنه يعمل بامتياز إداري — وهو
/// **بالضبط** ما تتطلبه العمليات المذكورة في `api-overview.md` §2 الشرط 4
/// («تحتاج امتيازاً يتجاوز قواعد الحماية»). ولذلك **كل تفويض يُفحَص في الكود
/// هنا صراحةً** ولا يُتَّكل على القواعد — راجع `ADR-0002`.
library;

import 'package:googleapis/firestore/v1.dart' as firestore;
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:http/http.dart' as http;

import 'firestore_decode.dart';
import 'firestore_value.dart';

/// مستند مقروء ومعه معرّفه — فالمعرّف جزء من المعنى لا زينة.
final class StoredDocument {
  /// ينشئ المستند.
  const StoredDocument({required this.id, required this.fields});

  /// معرّف المستند وحده (لا مساره الكامل).
  final String id;

  /// حقوله بقيم Dart عادية.
  final Map<String, Object?> fields;
}

/// ★ كتابةٌ واحدة في دفعةِ التزام — **بحقولها وقناعها وتحويلاتها الزمنية**.
///
/// ★★ **ونوعٌ مستقلٌّ عن `InventoryWrite` عمداً:** ⟵ **فهذا الملف بنيةٌ
/// تحتية عامة**، ⛔ **وربطُه بنوعٍ يخصّ عمليةً بعينها يقلب اتجاه الاعتماد**
/// (نفسُ منطق `FirestoreProvisioningStore`: «**الكاتب لا يعرف التهيئة**»).
final class CommittedWrite {
  /// ينشئ الكتابة.
  const CommittedWrite({
    required this.collectionId,
    required this.documentId,
    required this.fields,
    required this.updateMask,
    this.serverTimestampFields = const <String>[],
  });

  /// المجموعة — ★ **وقد تكون مساراً فرعياً** (`sacks/{id}/finance`).
  final String collectionId;

  /// معرّف المستند.
  final String documentId;

  /// الحقول بقيم Dart عادية.
  final Map<String, Object?> fields;

  /// ★ **قناع الكتابة** — ⛔ **وبدونه تُمحى بقية الحقول**.
  final List<String> updateMask;

  /// ★ حقول **وقت الخادم** — ⛔ **ولا تدخل [fields] ولا [updateMask]**.
  final List<String> serverTimestampFields;
}

/// عميل كتابة رفيع على قاعدة بيانات مشروع واحد.
final class FirestoreWriter {
  FirestoreWriter({
    required this.projectId,
    required firestore.FirestoreApi api,
    this.databaseId = '(default)',
  }) : _api = api;

  /// يبني عميلاً ببيانات الاعتماد الافتراضية للبيئة الحالية.
  static Future<FirestoreWriter> connect({
    required String projectId,
    String databaseId = '(default)',
  }) async {
    final http.Client client = await auth.clientViaApplicationDefaultCredentials(
      scopes: <String>[firestore.FirestoreApi.datastoreScope],
    );
    return FirestoreWriter(
      projectId: projectId,
      databaseId: databaseId,
      api: firestore.FirestoreApi(client),
    );
  }

  final String projectId;
  final String databaseId;
  final firestore.FirestoreApi _api;

  /// العميل المُهيَّأ — يشاركه `CounterAllocator` فلا تُفتَح جلسة اعتماد ثانية.
  firestore.FirestoreApi get api => _api;

  String get _documentsRoot =>
      'projects/$projectId/databases/$databaseId/documents';

  /// يكتب مستنداً بمعرّف محدّد، فيُنشئه أو يستبدله بالكامل.
  ///
  /// ★ **قابل للتكرار بلا أثر جانبي (Idempotent)** — نفس المعرّف يُنتج نفس
  /// المستند مهما تكرّر التشغيل. وهذا **شرط صحة لا تحسين**
  /// (`coding-standards.md` §2.7): المشغّل **قد يُنفَّذ مرتين أو خارج
  /// الترتيب**، والكتابة التراكمية كانت ستُنتج رقماً مضاعفاً بلا أي إنذار.
  /// ★ **و`updateMask` ليس تحسيناً بل شرط صحة:** بدونه تُستبدَل الحقول غير
  /// المذكورة فتُمحى — تماماً كما ينصّ `PendingDocument.updateMask`.
  Future<void> writeDocument({
    required String collectionId,
    required String documentId,
    required Map<String, Object?> data,
    List<String>? updateMask,
  }) async {
    final firestore.Document document = firestore.Document()
      ..fields = encodeFirestoreFields(data).map(
        (String key, Object? value) => MapEntry<String, firestore.Value>(
          key,
          firestore.Value.fromJson(value! as Map<String, Object?>),
        ),
      );

    await _api.projects.databases.documents.patch(
      document,
      '$_documentsRoot/$collectionId/$documentId',
      updateMask_fieldPaths: updateMask,
    );
  }

  /// يعدّد معرّفات مستندات مجموعة كاملةً — **بترقيم صفحات لا بصفحة واحدة**.
  ///
  /// ⚠️ **ولا يُطلَب أي حقل** (`mask_fieldPaths: ['__name__']`): تهيئة
  /// الحسابات تحتاج **المعرّفات وحدها**، ⛔ **وجرّ كل حقول كل الأطراف
  /// تكلفةُ قراءةٍ بلا مقابل** — وقد تكون الأطراف بالمئات.
  Future<List<String>> listDocumentIds(String collectionId) async {
    final List<String> ids = <String>[];
    String? pageToken;
    do {
      final firestore.ListDocumentsResponse page =
          await _api.projects.databases.documents.list(
        _documentsRoot,
        collectionId,
        pageSize: 300,
        pageToken: pageToken,
        mask_fieldPaths: const <String>['__name__'],
      );
      for (final firestore.Document doc in page.documents ?? const <firestore.Document>[]) {
        final String? name = doc.name;
        if (name != null) ids.add(name.split('/').last);
      }
      pageToken = page.nextPageToken;
    } while (pageToken != null && pageToken.isNotEmpty);
    return ids;
  }

  /// يعيد أول مستند في [collectionId] يحمل [field] بقيمة `true`، أو `null`.
  ///
  /// ★ **استعلامٌ لا مسحٌ كامل:** النوع الافتراضي واحد في النظام كله
  /// (`data-dictionary.md` §`items`)، ⛔ **فجرّ كل الأنواع لإيجاده هدرٌ**.
  Future<StoredDocument?> findFirstWhereTrue({
    required String collectionId,
    required String field,
  }) async {
    // ★ `RunQueryResponse` **هو نفسه قائمة** من العناصر في هذه الحزمة.
    final firestore.RunQueryResponse rows =
        await _api.projects.databases.documents.runQuery(
      firestore.RunQueryRequest()
        ..structuredQuery = (firestore.StructuredQuery()
          ..from = <firestore.CollectionSelector>[
            firestore.CollectionSelector()..collectionId = collectionId,
          ]
          ..where = (firestore.Filter()
            ..fieldFilter = (firestore.FieldFilter()
              ..field = (firestore.FieldReference()..fieldPath = field)
              ..op = 'EQUAL'
              ..value = (firestore.Value()..booleanValue = true)))
          ..limit = 1),
      _documentsRoot,
    );
    for (final firestore.RunQueryResponseElement row in rows) {
      final firestore.Document? doc = row.document;
      if (doc?.name == null) continue;
      return StoredDocument(
        id: doc!.name!.split('/').last,
        fields: decodeFirestoreFields(
          doc.fields?.map((String k, firestore.Value v) =>
              MapEntry<String, Object?>(k, v.toJson())),
        ),
      );
    }
    return null;
  }

  /// ★ المسار الكامل لمستند — ★ **يُبنى هنا وحده** (⛔ لا نصٌّ محفور).
  String documentPath(String collectionId, String documentId) =>
      '$_documentsRoot/$collectionId/$documentId';

  /// ★★ يقرأ عدّة مستندات **في نداءٍ واحد** — و`null` تعني **غياب المستند**.
  ///
  /// ⚠️ **ولماذا نداءٌ واحد لا نداءٌ لكل مستند:** المُحتسِب يقرأ ماليةَ كل
  /// جونيةٍ وسطرَ دفترها معاً (`WU-015`) — ⟵ **ونداءٌ لكل واحدٍ منها يجعل
  /// زمنَ العملية يتضاعف بعدد الجواني**، ⛔ **وهو ما يمنعه قيدُ الأداء في
  /// `sack-valuation-design.md` §6.**
  Future<Map<String, Map<String, Object?>?>> readDocuments(
    Iterable<String> paths,
  ) async {
    final List<String> unique = paths.toSet().toList(growable: false);
    if (unique.isEmpty) return <String, Map<String, Object?>?>{};
    final firestore.BatchGetDocumentsResponse response =
        await _api.projects.databases.documents.batchGet(
      firestore.BatchGetDocumentsRequest()..documents = unique,
      'projects/$projectId/databases/$databaseId',
    );
    final Map<String, Map<String, Object?>?> reads =
        <String, Map<String, Object?>?>{};
    for (final firestore.BatchGetDocumentsResponseElement element in response) {
      if (element.found?.name case final String name) {
        // ★★★ **فكٌّ مُصنَّف** — ⛔ **لا `toJson()`** (`DEBT-24`).
        reads[name] = decodeDocumentFields(element.found?.fields);
      } else if (element.missing case final String name) {
        reads[name] = null;
      }
    }
    for (final String path in unique) {
      reads.putIfAbsent(path, () => null);
    }
    return reads;
  }

  /// ★★ يلتزم بدفعةٍ من الكتابات **معاً** — ⛔ **بلا معاملة**.
  ///
  /// ⚠️⚠️ **ولماذا بلا معاملة:** هذه **كتاباتُ ملخّصٍ مشتقّ** (`ADR-0008`) لا
  /// كتابةُ مستخدم — ★ **ومعرّفاتُها حتمية**، ⟵ **فالتشغيل الجزئي ثم إعادة
  /// التشغيل يُكملان الناقص بلا ازدواج** (نفسُ تعليل `account_provisioning_handler.dart`
  /// حرفياً). ⛔ **و`ADR-0013` القاعدة 1 تحكم كتابة المستخدم وقيدها** لا هذه.
  ///
  /// ★ **والدفعةُ تُقسَّم على [_commitBatchLimit]** — ⟵ **فحدُّ المنصّة 500
  /// كتابةٍ لكل التزام**، ⛔ **وتجاوزُه يُسقِط الدفعة كلَّها.**
  Future<void> commitWrites(List<CommittedWrite> writes) async {
    for (int start = 0; start < writes.length; start += _commitBatchLimit) {
      final int end = (start + _commitBatchLimit).clamp(0, writes.length);
      await _api.projects.databases.documents.commit(
        firestore.CommitRequest()
          ..writes = <firestore.Write>[
            for (final CommittedWrite write in writes.sublist(start, end))
              _toWrite(write),
          ],
        'projects/$projectId/databases/$databaseId',
      );
    }
  }

  /// حدّ المنصّة لعدد الكتابات في التزامٍ واحد.
  static const int _commitBatchLimit = 500;

  firestore.Write _toWrite(CommittedWrite write) {
    final firestore.Write encoded = firestore.Write()
      ..update = (firestore.Document()
        ..fields = encodeFirestoreFields(write.fields).map(
          (String key, Object? value) => MapEntry<String, firestore.Value>(
            key,
            firestore.Value.fromJson(value! as Map<String, Object?>),
          ),
        )
        ..name = documentPath(write.collectionId, write.documentId))
      ..updateMask = (firestore.DocumentMask()..fieldPaths = write.updateMask);
    if (write.serverTimestampFields.isNotEmpty) {
      // ⛔ لا ساعة حاوية — `coding-standards.md` §2.3 · `GR-54`.
      encoded.updateTransforms = <firestore.FieldTransform>[
        for (final String field in write.serverTimestampFields)
          firestore.FieldTransform()
            ..fieldPath = field
            ..setToServerValue = 'REQUEST_TIME',
      ];
    }
    return encoded;
  }

  /// ★★ يقرأ مستندات مجموعة **بمرشّح مساواةٍ واحدٍ أو أكثر** — ⛔ **لا مسحاً**.
  ///
  /// ⚠️⚠️ **ولماذا خارج المعاملة:** المُحتسِب **بناءُ ملخّصٍ مشتقّ**
  /// (`ADR-0008`) لا كتابةُ مستخدم — ★ **ومستنداتُه تُكتشَف بالاستعلام ثم
  /// تُقرأ حقولُها في النداء نفسِه**: ⟵ **وهو ما لا تسمح به `AuditedTransaction`
  /// التي تقرأ مسارات معروفةً مقدَّماً.** ★ **والذرّية غير مطلوبة هنا
  /// أصلاً** — راجع ترويسة `sack_valuation_handler.dart`.
  ///
  /// ⛔★★ **ولا شرط مدى ولا ترتيب** — ★ **مساواةٌ فقط**، ⟵ **فكلُّ استعلامٍ
  /// هنا يقابله فهرسٌ قائم في `firestore.indexes.json`** ⛔ **ولا فهرسَ
  /// يُكتشَف نقصُه في التشغيل.**
  Future<List<StoredDocument>> queryDocuments({
    required String collectionId,
    required Map<String, Object?> equals,
    int? limit,
  }) async {
    final firestore.RunQueryResponse rows =
        await _api.projects.databases.documents.runQuery(
      firestore.RunQueryRequest()
        ..structuredQuery = (firestore.StructuredQuery()
          ..from = <firestore.CollectionSelector>[
            firestore.CollectionSelector()..collectionId = collectionId,
          ]
          ..where = _equalityFilter(equals)
          ..limit = limit),
      _documentsRoot,
    );
    final List<StoredDocument> found = <StoredDocument>[];
    for (final firestore.RunQueryResponseElement row in rows) {
      final firestore.Document? doc = row.document;
      final String? name = doc?.name;
      if (doc == null || name == null) continue;
      found.add(
        StoredDocument(
          id: name.split('/').last,
          // ★★★ **فكٌّ مُصنَّف** — ⛔ **لا `toJson()`** (`DEBT-24`).
          fields: decodeDocumentFields(doc.fields),
        ),
      );
    }
    return found;
  }

  static firestore.Filter _equalityFilter(Map<String, Object?> equals) {
    if (equals.isEmpty) {
      throw ArgumentError.value(equals, 'equals', 'استعلامٌ بلا مرشّح مسحٌ كامل');
    }
    firestore.Filter single(String fieldPath, Object? value) =>
        firestore.Filter()
          ..fieldFilter = (firestore.FieldFilter()
            ..field = (firestore.FieldReference()..fieldPath = fieldPath)
            ..op = 'EQUAL'
            ..value = firestore.Value.fromJson(encodeFirestoreValue(value)));

    if (equals.length == 1) {
      final MapEntry<String, Object?> only = equals.entries.first;
      return single(only.key, only.value);
    }
    return firestore.Filter()
      ..compositeFilter = (firestore.CompositeFilter()
        ..op = 'AND'
        ..filters = <firestore.Filter>[
          for (final MapEntry<String, Object?> entry in equals.entries)
            single(entry.key, entry.value),
        ]);
  }

  /// يقرأ مستنداً، أو `null` إن لم يكن موجوداً.
  ///
  /// ★ **أُضيف لـ`ADR-0016`:** الصلاحيات خرجت من الرمز إلى بطاقة المستخدم،
  /// فصار على الدالة المستدعاة أن **تقرأ البطاقة** لتعرف صلاحيات المُنفِّذ —
  /// تماماً كما صارت القاعدة تقرأها.
  ///
  /// ⛔ **والغياب ليس خطأً بل حالة**: حسابٌ بلا بطاقة = **بلا صلاحية**
  /// إطلاقاً، وهو الرفض الافتراضي نفسه الذي تطبّقه القاعدة.
  Future<Map<String, Object?>?> readDocument({
    required String collectionId,
    required String documentId,
  }) async {
    try {
      final firestore.Document doc = await _api.projects.databases.documents
          .get('$_documentsRoot/$collectionId/$documentId');
      // ★★★ **فكٌّ مُصنَّف** — ⛔ **لا `toJson()`**: راجع `firestore_decode.dart`.
      //    ⚠️ **والمرور بـ`toJson()` هو العطل الذي أعمى كل فحص صلاحية.**
      return decodeDocumentFields(doc.fields);
    } on firestore.DetailedApiRequestError catch (error) {
      if (error.status == 404) return null;
      rethrow;
    }
  }
}

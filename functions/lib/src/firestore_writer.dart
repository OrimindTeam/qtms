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

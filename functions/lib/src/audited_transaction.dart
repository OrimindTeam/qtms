/// معاملة ذرّية تكتب **المستند وقيد تدقيقه معاً** — تنفيذ `ADR-0013`.
///
/// ★ **القاعدة 1 من الـADR حرفياً:** «**المستند وقيده يُكتبان معاً أو لا
/// يُكتب أيٌّ منهما** — لا حالة وسطى». وهذا هو الوفاء بـ`BR-M18-03`
/// («**لا ينجح تعديل بلا قيد مقابل**»)، ⛔ **لا مشغّل يكتب القيد بعد الالتزام**
/// — فالمشغّل يصل **بعد أن التزمت الكتابة فعلاً**، فلا شيء بقي ليُبطَل.
///
/// ⚠️ **والترتيب ملزم** (`coding-standards.md` §2.6): **كل القراءات قبل كل
/// الكتابات**، و**لا استدعاء خارجي داخل المعاملة** — لأنها تُعاد تلقائياً
/// فيتكرر الأثر. ولذلك تأخذ [AuditedTransaction.run] **قائمة مسارات تُقرأ**
/// ثم **دالة تخطيط خالصة** لا تلمس الشبكة.
///
/// ★ **ووقت القيد من المنصة لا من ساعة الحاوية** — `REQUEST_TIME` داخل
/// المعاملة نفسها، وكل الحقول في المعاملة الواحدة **تأخذ الطابع نفسه**.
library;

import 'dart:math' as math;

import 'package:googleapis/firestore/v1.dart' as firestore;
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:http/http.dart' as http;
import 'package:qtms_domain/qtms_domain.dart';

import 'firestore_decode.dart';
import 'firestore_value.dart';

/// اسم حقل وقت الحدث — **يُكتب بتحويل المنصة لا بقيمة منّا**.
const String auditOccurredAtField = 'occurredAt';

/// مستند مُعدّ للكتابة داخل المعاملة.
final class PendingDocument {
  /// ينشئ مستنداً معلَّقاً.
  const PendingDocument({
    required this.collectionId,
    required this.documentId,
    required this.fields,
    this.updateMask,
    this.serverTimestampFields = const <String>[],
  });

  /// المجموعة التي يُكتب فيها.
  final String collectionId;

  /// معرّف المستند — ★ **مُولَّد مسبقاً** فيمنع الازدواج عند إعادة الإرسال
  /// (`api-overview.md` §4).
  final String documentId;

  /// حقوله بقيم Dart عادية — والترميز مسؤولية هذا الملف.
  final Map<String, Object?> fields;

  /// الحقول التي تُكتب وحدها، أو `null` لاستبدال المستند بالكامل.
  ///
  /// ⛔ **بلا قناع، تُمحى الحقول غير المذكورة** — فالقناع ليس تحسيناً.
  final List<String>? updateMask;

  /// ★ حقول **وقت الخادم** — تُكتب بتحويل المنصة داخل الالتزام نفسه.
  ///
  /// ⚠️⚠️ **ولماذا لزم هذا المسار أصلاً:** `data-dictionary.md` §1 يجعل
  /// `createdAt` **⚙️ بتوقيت الخادم**، **وكانت قاعدة الحماية تفرضه**
  /// بـ`serverTime('createdAt')`. ⛔ **ثم أُغلقت الكتابة المباشرة فلم يعد
  /// أحدٌ يفرضه** — ★ **فانتقل إثباتُه إلى الدالة الكاتبة** (`DEBT-21` ①).
  /// ⟵ **وساعةُ الحاوية ليست بديلاً**: `coding-standards.md` §2.3 · `GR-54`
  /// («لا يُستخدَم وقت الجهاز في أي حقل يُخزَّن»)، **والحاوية جهازٌ أيضاً.**
  ///
  /// ⛔ **ولا تُذكَر هذه الحقول في [fields] ولا في [updateMask]** —
  /// تحويلاتُ الحقل مسارٌ مستقل في بروتوكول الكتابة، **وذكرُها في القناع
  /// يجعل الكتابة تمحوها ثم يُعيدها التحويل** بلا فائدة.
  final List<String> serverTimestampFields;
}

/// ★★ مستند **يُحذف** داخل المعاملة — `IQ-018` (2026-08-24).
///
/// ⛔★★ **ولا يُقاس على هذا أي حذفٍ آخر:** `security-requirements.md` §2
/// البند 1 يمنع الحذف في **السجلات والحركات**، ★ **والاستثناء الوحيد
/// المعتمد هو قالب الدور غير المُسنَد** — قالبٌ لا سجلَّ حركة، ولا مستخدمَ
/// يشير إليه، ⟵ **فلا مرجع ينكسر ولا تاريخ يضيع**. ✅ **والقيد يبقى**:
/// الحذف نفسه يُوثَّق في سجل التدقيق كأي تغيير.
final class PendingDeletion {
  /// ينشئ حذفاً معلَّقاً.
  const PendingDeletion({required this.collectionId, required this.documentId});

  /// المجموعة المحذوف منها.
  final String collectionId;

  /// معرّف المستند المحذوف.
  final String documentId;
}

/// ★ استعلام يُنفَّذ **داخل المعاملة** — ⟵ **قراءةٌ متسقة لا لقطةٌ سابقة**.
///
/// ★★ **وهو ما يجعل «الدور غير مُسنَد» حقيقةً مقيسة لا قيمةً مخزَّنة**
/// (`IQ-018`): ⛔ **لا حقل `isAssigned` في مستند الدور ولا كاش في التطبيق**،
/// بل **سؤالٌ لمجموعة `users` نفسها لحظةَ الحذف**.
final class DocumentQuery {
  /// ينشئ استعلاماً بمفتاح تُقرأ به نتيجته.
  const DocumentQuery({
    required this.key,
    required this.collectionId,
    required this.fieldPath,
    required this.equalTo,
    this.andEquals = const <String, Object?>{},
    this.limit = 1,
  });

  /// مفتاح النتيجة في [TransactionReads].
  final String key;

  /// المجموعة المستعلَم عنها.
  final String collectionId;

  /// الحقل المقارَن.
  final String fieldPath;

  /// القيمة المطلوبة.
  final Object? equalTo;

  /// ★★ شروط مساواة **إضافية تُجمَع بـ`AND`** — ⛔ **ولا شرط مدى ولا ترتيب**.
  ///
  /// ⚠️⚠️ **ولماذا لزمت (`WU-003`):** رصيد المخزون يُجمَع من الدفتر **لكل
  /// (مصدر × نوع × تاريخ مخزون)** (`design-overview.md` §2.1)، ⟵ **وشرطٌ
  /// واحد كان سيقرأ حركاتِ النوع في **كل** الأيام** ثم يُصفّيها في الذاكرة —
  /// ⛔ **قراءةٌ تنمو مع عمر البيانات**، وهو بالضبط ما رفضه `ADR-0008`.
  ///
  /// ★ **والفهرس المطلوب قائمٌ منذ `WU-000`:**
  /// `inventory_ledger: sourceId ↑ · itemKey ↑ · stockDate ↓` —
  /// ⛔ **فلا فهرس جديد ولا حقلٌ مشتقٌّ يُضاف إلى الدفتر.**
  final Map<String, Object?> andEquals;

  /// حدّ النتائج — ★ **الافتراضي 1**: السؤال «هل يوجد» لا «كم عددهم».
  final int limit;
}

/// ما قُرئ داخل المعاملة — مستنداتٍ ونتائجَ استعلام.
final class TransactionReads {
  /// ينشئ نتائج القراءة.
  const TransactionReads({
    required this.documents,
    required this.queries,
    this.queryDocuments = const <String, List<Map<String, Object?>>>{},
    this.readTime,
  });

  /// ★ حالة القراءة الفارغة — لعمليةٍ لا تقرأ شيئاً.
  static const TransactionReads none = TransactionReads(
    documents: <String, Map<String, Object?>?>{},
    queries: <String, List<String>>{},
  );

  /// ★★★ **زمن القراءة كما أعلنته المنصّة** — و`null` تعني **أنه لم يصل**.
  ///
  /// ⚠️⚠️ **ولماذا يلزم أصلاً (`WU-003`):** `stockDate` **قيمةٌ تُخزَّن
  /// وتدخل مفتاحاً مركّباً ورقمَ مستند**، ⛔ **فلا يكفيها تحويل `REQUEST_TIME`**
  /// الذي يكتب زمناً لا نعرفه. ★ **و`coding-standards.md` §2.3 (`GR-54`)
  /// يمنع ساعة الجهاز** — ⟵ **وهذا الحقل هو ساعة المنصّة نفسها**، تصل مع
  /// نتيجة الاستعلام داخل المعاملة (`readTime` في `RunQueryResponse`).
  ///
  /// ⛔★★ **والغياب رفضٌ لا رجوعٌ إلى ساعة الحاوية** — راجع مُستدعيه:
  /// **الحاوية جهازٌ أيضاً** (ترويسة هذا الملف).
  final DateTime? readTime;

  /// المستندات المقروءة بمساراتها — و`null` تعني **غياب المستند**.
  final Map<String, Map<String, Object?>?> documents;

  /// معرّفات المستندات المطابقة لكل استعلام بمفتاحه.
  final Map<String, List<String>> queries;

  /// ★ **حقول المستندات المطابقة** لكل استعلام بمفتاحه — بنفس ترتيب
  /// [queries].
  ///
  /// ⚠️ **ولماذا مسارٌ ثانٍ لا استبدالٌ للأول:** أسئلةٌ كثيرة تكتفي
  /// بـ«**هل يوجد**» (`IQ-018`)، ⟵ **وحملُ الحقول لها كلفةٌ بلا فائدة**.
  /// ★ **وأسئلةٌ أخرى تحتاج القيمة نفسها** — «هل رصيدُه ≠ 0؟» (`FR-M4-09`)
  /// ⛔ **ولا يُجاب عنها بمعرّفٍ وحده.**
  final Map<String, List<Map<String, Object?>>> queryDocuments;

  /// حقول نتيجة استعلام بمفتاحه — ⛔ **والغياب ليس فراغاً**.
  ///
  /// ⚠️ **يرمي عند طلب مفتاح لم يُستعلَم عنه** — بنفس منطق [matches]
  /// وللسبب نفسه: **استعلامٌ منسيّ يُقرَأ «لا رصيد» فيُعطَّل مقوتٌ عليه دين.**
  List<Map<String, Object?>> matchedDocuments(String key) {
    final List<Map<String, Object?>>? found = queryDocuments[key];
    if (found == null) {
      throw StateError('لا مستندات استعلام بالمفتاح «$key» — ولا تُطوى في فراغ');
    }
    return found;
  }

  /// مستند بمساره.
  Map<String, Object?>? document(String path) => documents[path];

  /// معرّفات نتيجة استعلام بمفتاحه — ⛔ **والغياب ليس فراغاً**.
  ///
  /// ⚠️ **يرمي عند طلب مفتاح لم يُستعلَم عنه** — ★ **ولا يُرجِع قائمة فارغة**:
  /// الفارغة تعني «لا مطابق» ⟵ **فطيّ الخطأ فيها كان سيُحوِّل استعلاماً
  /// منسياً إلى «الدور غير مُسنَد» فيُحذَف دورٌ مُسنَد.**
  List<String> matches(String key) {
    final List<String>? found = queries[key];
    if (found == null) {
      throw StateError('لا نتيجة استعلام بالمفتاح «$key» — ولا تُطوى في فراغ');
    }
    return found;
  }
}

/// ★ إبطال المعاملة من داخل التخطيط — **رفضٌ بعد قراءةٍ لا فشلٌ تقني**.
///
/// ⚠️ **ولماذا استثناء لا قيمةٌ عائدة:** قرار الرفض يظهر **بعد** أن قرأت
/// المعاملة، ⟵ **والتخطيط لا يملك مساراً يُرجِع به «لا تكتب شيئاً»** ما دام
/// [AuditedWrite] يشترط مستنداً وقيداً. ★ **والمعاملة تُلغى فعلاً** (Rollback)
/// ⛔ لا تُترك مفتوحةً حتى تنتهي مهلتها.
final class AbortTransaction implements Exception {
  /// ينشئ إبطالاً بسببه — ★ **وسببه رمز الكتالوج** كما يصل المستخدم.
  const AbortTransaction(this.reason);

  /// سبب الإبطال — يُترجِمه المُستدعي إلى استجابة.
  final Object reason;

  @override
  String toString() => 'AbortTransaction: $reason';
}

/// خطة كتابة ذرّية: مستنداتها وقيدها ونتيجتها.
final class AuditedWrite<T> {
  /// ينشئ خطة.
  const AuditedWrite({
    required this.documents,
    required this.entry,
    required this.result,
    this.deletions = const <PendingDeletion>[],
  });

  /// المستندات المكتوبة — ⛔ **ولا تكون فارغة**: قيد بلا تعديل لا معنى له.
  ///
  /// ⚠️ **إلا إذا كانت [deletions] غير فارغة** — فالحذف تغييرٌ يُوثَّق أيضاً.
  final List<PendingDocument> documents;

  /// ★★ المستندات المحذوفة — `IQ-018`. راجع [PendingDeletion].
  final List<PendingDeletion> deletions;

  /// قيد التدقيق المقابل — **إلزامي، ولا كتابة بلا قيد**.
  final AuditEntry entry;

  /// ما تُرجِعه العملية للمُستدعي عند النجاح.
  final T result;
}

/// فشل المعاملة بعد استنفاد إعادة المحاولة — تعارض تزامن مستمر.
final class TransactionContentionException implements Exception {
  /// ينشئ الاستثناء بعدد محاولاته.
  const TransactionContentionException(this.attempts);

  /// عدد المحاولات التي جُرّبت.
  final int attempts;

  @override
  String toString() =>
      'TransactionContentionException: تعذّر الالتزام بعد $attempts محاولات';
}

/// مُنفِّذ المعاملات المُدقَّقة.
final class AuditedTransaction {
  /// ينشئ مُنفِّذاً على قاعدة مشروع واحد.
  AuditedTransaction({
    required this.projectId,
    required firestore.FirestoreApi api,
    this.databaseId = '(default)',
    this.maxAttempts = 5,
    math.Random? random,
  })  : _api = api,
        _random = random ?? math.Random();

  /// يبني مُنفِّذاً ببيانات الاعتماد الافتراضية للبيئة الحالية.
  ///
  /// ★ **بنفس نمط `FirestoreWriter.connect`** — ⛔ ولا مفتاح ولا سرّ في أي
  /// ملف (`secrets-management-policy.md` · `coding-standards.md` §2.4).
  static Future<AuditedTransaction> connect({
    required String projectId,
    String databaseId = '(default)',
  }) async {
    final http.Client client = await auth.clientViaApplicationDefaultCredentials(
      scopes: <String>[firestore.FirestoreApi.datastoreScope],
    );
    return AuditedTransaction(
      projectId: projectId,
      databaseId: databaseId,
      api: firestore.FirestoreApi(client),
    );
  }

  /// معرّف المشروع.
  final String projectId;

  /// معرّف القاعدة.
  final String databaseId;

  /// حدّ إعادة المحاولة عند تعارض التزامن.
  ///
  /// ★ **إعادة المحاولة سلوك متوقَّع لا استثناء** (`coding-standards.md` §2.6).
  final int maxAttempts;

  final firestore.FirestoreApi _api;
  final math.Random _random;

  static const Duration _backoffBase = Duration(milliseconds: 40);

  String get _root => 'projects/$projectId/databases/$databaseId';

  /// المسار الكامل لمستند.
  String documentPath(String collectionId, String documentId) =>
      '$_root/documents/$collectionId/$documentId';

  /// ★ يقرأ مستنداً **خارج أي معاملة** — و`null` تعني **غيابه**.
  ///
  /// ⚠️⚠️ **ولا يُبنى عليه قرار إطلاقاً:** لقطةٌ قد تتغيّر قبل الالتزام،
  /// ⟵ **واستعمالها الوحيد المشروع هو تحديد *ما* يُقرأ داخل المعاملة**
  /// (مثال `WU-003`: أنواعُ مستندٍ قائم لتُقرأ حركاتُها). ★ **والمعاملة
  /// تُعيد قراءة المستند نفسه وتحكم به** — ⛔ **فلا تُغني هذه عن تلك.**
  Future<Map<String, Object?>?> readDocument({
    required String collectionId,
    required String documentId,
  }) async {
    try {
      final firestore.Document doc =
          await _api.projects.databases.documents.get(
        documentPath(collectionId, documentId),
      );
      // ★★★ **فكٌّ مُصنَّف** — ⛔ **لا `toJson()`** (`DEBT-24`).
      return decodeDocumentFields(doc.fields);
    } on firestore.DetailedApiRequestError catch (error) {
      // ★ غياب المستند ليس خطأً — والمُستدعي يترجمه إلى رفضٍ صريح.
      if (error.status == 404) return null;
      rethrow;
    }
  }

  /// ينفّذ معاملة: يقرأ [readPaths]، ثم يخطّط، ثم يلتزم بالمستندات وقيدها.
  ///
  /// [plan] **دالة خالصة** — ⛔ لا شبكة ولا ملفات فيها، لأنها تُستدعى مجدداً
  /// عند كل إعادة محاولة.
  Future<T> run<T>({
    required List<String> readPaths,
    required AuditedWrite<T> Function(TransactionReads reads) plan,
    List<DocumentQuery> queries = const <DocumentQuery>[],
  }) async {
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      final String transactionId = await _begin();
      // ① كل القراءات أولاً — §2.6. ★ **والاستعلامات منها**: تُنفَّذ داخل
      //   المعاملة نفسها فتشترك في اتّساقها (`IQ-018`).
      final _QueryResults results = await _runQueries(queries, transactionId);
      final Map<String, List<_QueryHit>> hits = results.hits;
      final TransactionReads reads = TransactionReads(
        documents: await _readAll(readPaths, transactionId),
        queries: <String, List<String>>{
          for (final MapEntry<String, List<_QueryHit>> entry in hits.entries)
            entry.key: <String>[
              for (final _QueryHit hit in entry.value) hit.documentId,
            ],
        },
        queryDocuments: <String, List<Map<String, Object?>>>{
          for (final MapEntry<String, List<_QueryHit>> entry in hits.entries)
            entry.key: <Map<String, Object?>>[
              for (final _QueryHit hit in entry.value) hit.fields,
            ],
        },
        // ★★★ **ساعة المنصّة** — ⛔ لا ساعة الحاوية (راجع [TransactionReads.readTime]).
        readTime: results.readTime,
      );
      // ② ثم تخطيط خالص، ③ ثم الكتابات في التزام واحد.
      final AuditedWrite<T> write;
      try {
        write = plan(reads);
      } on AbortTransaction {
        // ★ **رفضٌ بعد قراءة** — ⛔ **ولا تُترك المعاملة مفتوحة**، فالمهلة
        //   تحجز أقفالها حتى تنتهي فتُعطِّل غيرَها بلا داعٍ.
        await _rollback(transactionId);
        rethrow;
      }
      try {
        await _commit(transactionId, write);
        return write.result;
      } on firestore.DetailedApiRequestError catch (error) {
        final bool retryable = error.status == 409 || error.status == 400;
        if (!retryable || attempt == maxAttempts) rethrow;
        await Future<void>.delayed(_backoffFor(attempt));
      }
    }
    throw TransactionContentionException(maxAttempts);
  }

  /// ينفّذ الاستعلامات داخل المعاملة ويُرجِع المطابق لكل مفتاح **وزمن القراءة**.
  Future<_QueryResults> _runQueries(
    List<DocumentQuery> queries,
    String transactionId,
  ) async {
    final Map<String, List<_QueryHit>> results = <String, List<_QueryHit>>{};
    DateTime? readTime;
    for (final DocumentQuery query in queries) {
      final _QueryOutcome outcome = await _runQuery(query, transactionId);
      results[query.key] = outcome.hits;
      // ★ **أول زمنٍ أعلنته المنصّة يكفي** — كلها داخل المعاملة نفسها،
      //   ⟵ **والفارق بينها أجزاءُ ثانية لا يُغيّر يوماً تقويمياً**؛
      //   ⛔ **والحالة الحدّية (منتصف الليل) يحرسها المُستدعي** بمقارنة
      //   اليوم المطلوب بالمقروء (`inventory_handler.dart`).
      readTime ??= outcome.readTime;
    }
    return _QueryResults(hits: results, readTime: readTime);
  }

  Future<_QueryOutcome> _runQuery(
    DocumentQuery query,
    String transactionId,
  ) async {
    final List<firestore.RunQueryResponseElement> response =
        await _api.projects.databases.documents.runQuery(
      firestore.RunQueryRequest()
        ..transaction = transactionId
        ..structuredQuery = (firestore.StructuredQuery()
          ..from = <firestore.CollectionSelector>[
            firestore.CollectionSelector()..collectionId = query.collectionId,
          ]
          ..where = _filterOf(query)
          ..limit = query.limit),
      '$_root/documents',
    );
    DateTime? readTime;
    final List<_QueryHit> hits = <_QueryHit>[];
    for (final firestore.RunQueryResponseElement element in response) {
      // ★ **يصل مع كل عنصر، وحتى مع عنصرٍ بلا مستند** حين لا نتيجة —
      //   ⟵ **فاستعلامٌ فارغ يُعطي زمناً صالحاً** (توثيق `readTime`).
      if (element.readTime case final String stamp) {
        readTime ??= DateTime.parse(stamp).toUtc();
      }
      if (element.document?.name case final String name) {
        hits.add(
          _QueryHit(
            documentId: name.split('/').last,
            // ★★★ **فكٌّ مُصنَّف** — ⛔ **لا `toJson()`** (`DEBT-24`).
            fields: decodeDocumentFields(element.document?.fields),
          ),
        );
      }
    }
    return _QueryOutcome(hits: hits, readTime: readTime);
  }

  /// ★ يبني مُرشِّح الاستعلام — **حقلٌ واحد أو تركيبةُ `AND`**.
  static firestore.Filter _filterOf(DocumentQuery query) {
    firestore.Filter single(String fieldPath, Object? value) =>
        firestore.Filter()
          ..fieldFilter = (firestore.FieldFilter()
            ..field = (firestore.FieldReference()..fieldPath = fieldPath)
            ..op = 'EQUAL'
            ..value = firestore.Value.fromJson(encodeFirestoreValue(value)));

    if (query.andEquals.isEmpty) {
      return single(query.fieldPath, query.equalTo);
    }
    return firestore.Filter()
      ..compositeFilter = (firestore.CompositeFilter()
        ..op = 'AND'
        ..filters = <firestore.Filter>[
          single(query.fieldPath, query.equalTo),
          for (final MapEntry<String, Object?> extra in query.andEquals.entries)
            single(extra.key, extra.value),
        ]);
  }

  Future<void> _rollback(String transactionId) async {
    try {
      await _api.projects.databases.documents.rollback(
        firestore.RollbackRequest()..transaction = transactionId,
        _root,
      );
    } on firestore.DetailedApiRequestError {
      // ⛔ **ليس ابتلاعاً لخطأ مؤثِّر:** الإبطال تنظيفٌ لا قرار، والمعاملة
      //    **لم تلتزم أصلاً** — ⟵ **وفشل التنظيف يتركها تنتهي بمهلتها**،
      //    ⛔ **ولا يُخفي رفضاً** لأن [AbortTransaction] يصعد فوقه.
    }
  }

  Future<String> _begin() async {
    final firestore.BeginTransactionResponse begun =
        await _api.projects.databases.documents.beginTransaction(
      firestore.BeginTransactionRequest(),
      _root,
    );
    final String? id = begun.transaction;
    if (id == null) {
      throw StateError('تعذّر بدء المعاملة — لا معرّف في الاستجابة');
    }
    return id;
  }

  Future<Map<String, Map<String, Object?>?>> _readAll(
    List<String> paths,
    String transactionId,
  ) async {
    final Map<String, Map<String, Object?>?> reads =
        <String, Map<String, Object?>?>{};
    for (final String path in paths) {
      reads[path] = await _readOne(path, transactionId);
    }
    return reads;
  }

  Future<Map<String, Object?>?> _readOne(
    String path,
    String transactionId,
  ) async {
    try {
      final firestore.Document doc =
          await _api.projects.databases.documents.get(
        path,
        transaction: transactionId,
      );
      // ★★★ **فكٌّ مُصنَّف** — ⛔ **لا `toJson()`** (راجع `firestore_decode.dart`).
      return decodeDocumentFields(doc.fields);
    } on firestore.DetailedApiRequestError catch (error) {
      // ★ غياب المستند ليس خطأً — أول منح لمستخدم لا سجلّ له بعد.
      if (error.status == 404) return null;
      rethrow;
    }
  }

  Future<void> _commit(String transactionId, AuditedWrite<Object?> write) async {
    if (write.documents.isEmpty && write.deletions.isEmpty) {
      throw ArgumentError.value(
        write.documents,
        'documents',
        'قيد بلا مستند مكتوب ولا محذوف — والقيد يوثّق تغييراً لا فراغاً',
      );
    }
    final List<firestore.Write> writes = <firestore.Write>[
      for (final PendingDocument doc in write.documents) _toWrite(doc),
      // ★★ **الحذف والقيد في الالتزام نفسه** (`ADR-0013` القاعدة 1) — ⟵
      //   **فلا دورٌ يُحذف بلا قيد، ولا قيدُ حذفٍ بلا حذف** (`BR-M18-03`).
      for (final PendingDeletion gone in write.deletions)
        firestore.Write()
          ..delete = documentPath(gone.collectionId, gone.documentId),
      _auditWrite(write.entry),
    ];
    await _api.projects.databases.documents.commit(
      firestore.CommitRequest()
        ..transaction = transactionId
        ..writes = writes,
      _root,
    );
  }

  firestore.Write _toWrite(PendingDocument doc) {
    final firestore.Write write = firestore.Write()
      ..update = (_encodeDocument(doc.fields)
        ..name = documentPath(doc.collectionId, doc.documentId));
    final List<String>? mask = doc.updateMask;
    if (mask != null) {
      write.updateMask = firestore.DocumentMask()..fieldPaths = mask;
    }
    if (doc.serverTimestampFields.isNotEmpty) {
      // ⛔ لا ساعة حاوية — `coding-standards.md` §2.3 · `GR-54`.
      write.updateTransforms = <firestore.FieldTransform>[
        for (final String field in doc.serverTimestampFields)
          firestore.FieldTransform()
            ..fieldPath = field
            ..setToServerValue = 'REQUEST_TIME',
      ];
    }
    return write;
  }

  /// كتابة القيد — ★ **بلا `occurredAt` في الحقول، وبتحويل زمن المنصة بدلاً عنه**.
  firestore.Write _auditWrite(AuditEntry entry) {
    final Map<String, Object?> fields = Map<String, Object?>.from(
      entry.toFields(),
    )..remove(auditOccurredAtField);
    return firestore.Write()
      ..update = (_encodeDocument(fields)
        ..name = documentPath(auditLogCollection, entry.id))
      ..updateTransforms = <firestore.FieldTransform>[
        firestore.FieldTransform()
          ..fieldPath = auditOccurredAtField
          // ⛔ لا ساعة حاوية — `coding-standards.md` §2.3 · `GR-54`.
          ..setToServerValue = 'REQUEST_TIME',
      ];
  }

  static firestore.Document _encodeDocument(Map<String, Object?> fields) {
    return firestore.Document()
      ..fields = encodeFirestoreFields(fields).map(
        (String key, Object? value) => MapEntry<String, firestore.Value>(
          key,
          firestore.Value.fromJson(value! as Map<String, Object?>),
        ),
      );
  }

  /// تباعد أسّي **بتشويش عشوائي** — والتشويش هو الجوهر لا التزيين.
  ///
  /// ⚠️ **رُصد بالتشغيل الحقيقي** في `CounterAllocator`: بلا تشويش يعيد كل
  /// الخاسرين المحاولة في اللحظة نفسها **فيتصادمون مجدداً**.
  Duration _backoffFor(int attempt) {
    final int ceiling = _backoffBase.inMilliseconds * (1 << (attempt - 1));
    return Duration(milliseconds: _random.nextInt(ceiling) + 1);
  }
}

/// نتيجة استعلامٍ واحدة — معرّفها وحقولها معاً.
final class _QueryHit {
  const _QueryHit({required this.documentId, required this.fields});

  final String documentId;
  final Map<String, Object?> fields;
}

/// مخرَج استعلامٍ واحد — مطابقاته **وزمن قراءته من المنصّة**.
final class _QueryOutcome {
  const _QueryOutcome({required this.hits, required this.readTime});

  final List<_QueryHit> hits;
  final DateTime? readTime;
}

/// مخرَج كل الاستعلامات — بمفاتيحها **وزمن قراءةٍ واحد**.
final class _QueryResults {
  const _QueryResults({required this.hits, required this.readTime});

  final Map<String, List<_QueryHit>> hits;
  final DateTime? readTime;
}

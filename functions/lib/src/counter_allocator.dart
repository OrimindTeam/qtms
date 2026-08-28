/// تخصيص أرقام التسلسل **داخل معاملة ذرّية**.
///
/// ★ **لماذا معاملة لا زيادة ذرّية بسيطة:** `ADR-0013` يفرض أن يُكتب المستند
/// **وقيد تدقيقه** معاً في **معاملة واحدة**. والرقم جزء من المستند، فتخصيصه
/// يجب أن يقع **داخل المعاملة نفسها** — وإلا أمكن أن يُخصَّص رقم ثم تفشل
/// كتابة المستند، **فتبقى فجوة بلا مستند**.
///
/// ★ **وهذا هو الفحص ⑥ من «الخطوة صفر»** (`product-roadmap.md` §0):
/// «**توليد رقمين متزامنين لجونيتين ينجح بلا تكرار**» (`E-43`).
///
/// ⚠️ **الترتيب ملزم** (`coding-standards.md` §2.6): **كل القراءات قبل كل
/// الكتابات**، و**لا استدعاء خارجي داخل المعاملة** — لأنها تُعاد تلقائياً
/// فيتكرر الأثر.
library;

import 'dart:math' as math;

import 'package:googleapis/firestore/v1.dart' as firestore;
import 'package:qtms_domain/qtms_domain.dart';

import 'firestore_value.dart';

/// حقل قيمة العدّاد داخل مستنده.
const String counterValueField = 'value';

/// نتيجة تخصيص رقم.
final class AllocatedSequence {
  const AllocatedSequence({required this.sequence, required this.counterId});

  /// الرقم المخصَّص — **يبدأ من ١** ولا يُعاد استخدامه.
  final int sequence;

  /// معرّف مستند العدّاد الذي استُهلك.
  final String counterId;
}

/// يخصّص أرقام التسلسل من عدّادات السحابة.
///
/// ⛔ **لا يُستدعى من التطبيق إطلاقاً** — العدّادات «السحابة فقط · والقراءة
/// مرفوضة للجميع» (`data-dictionary.md` §1)، وقاعدة الحماية تفرضه
/// (`allow read, write: if false`).
final class CounterAllocator {
  CounterAllocator({
    required this.projectId,
    required firestore.FirestoreApi api,
    this.databaseId = '(default)',
    this.maxAttempts = 8,
    math.Random? random,
  })  : _api = api,
        _random = random ?? _sharedRandom;

  static final math.Random _sharedRandom = math.Random();

  final String projectId;
  final String databaseId;
  final firestore.FirestoreApi _api;

  /// حدّ إعادة المحاولة عند تعارض التزامن.
  ///
  /// ★ **إعادة المحاولة سلوك متوقَّع لا استثناء** (`coding-standards.md`
  /// §2.6) — فمستخدمان يُنشئان جونيتين في اللحظة نفسها **يتنافسان على
  /// العدّاد نفسه**، ويفوز أحدهما فيُعيد الآخر القراءة ويأخذ الرقم التالي.
  final int maxAttempts;

  final math.Random _random;

  /// أساس التباعد الأسّي بين المحاولات.
  ///
  /// ★ **رُصد بالتشغيل الحقيقي (2026-08-22):** بلا تباعد، تفشل **اثنتا عشرة**
  /// محاولة متزامنة على العدّاد نفسه بـ`Aborted due to cross-transaction
  /// contention` — لأن كل الخاسرين **يعيدون المحاولة في اللحظة نفسها
  /// فيتصادمون مجدداً**. ⟵ والتباعد **العشوائي** هو ما يفضّهم.
  static const Duration _backoffBase = Duration(milliseconds: 40);

  String get _documentsRoot =>
      'projects/$projectId/databases/$databaseId/documents';

  /// يخصّص الرقم التالي من عدّاد المستندات لنوعٍ في يوم.
  Future<AllocatedSequence> allocateDocumentSequence({
    required DocumentKind kind,
    required CalendarDay day,
  }) {
    final String counterId = documentCounterId(kind: kind, day: day);
    return _allocate(
      collectionId: documentCountersCollection,
      documentId: counterId,
    );
  }

  /// يخصّص الرقم اليومي التالي لجونية في مصدر.
  ///
  /// ★ **مستقل لكل مصدر ويبدأ من ١ كل يوم** (`naming-conventions.md` §5).
  Future<AllocatedSequence> allocateDailySackSequence({
    required String sourceId,
    required CalendarDay day,
  }) {
    final String counterId = dailySackCounterId(sourceId: sourceId, day: day);
    return _allocate(
      collectionId: dailySackCountersCollection,
      documentId: counterId,
    );
  }

  /// المعاملة: قراءة العدّاد ثم كتابته بشرط ألّا يكون تغيّر بينهما.
  ///
  /// ★ **الشرط هو ما يمنع التكرار**: المعاملة تحمل معرّفها، وأي كتابة
  /// متزامنة على المستند نفسه **تُفشل الالتزام** بدل أن تدهسه — فيُعاد
  /// التخصيص برقم جديد. ⛔ **ولا يُسلَّم رقمان متطابقان أبداً.**
  Future<AllocatedSequence> _allocate({
    required String collectionId,
    required String documentId,
  }) async {
    final String name = '$_documentsRoot/$collectionId/$documentId';

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      final firestore.BeginTransactionResponse begun =
          await _api.projects.databases.documents.beginTransaction(
        firestore.BeginTransactionRequest(),
        'projects/$projectId/databases/$databaseId',
      );
      final String? transactionId = begun.transaction;
      if (transactionId == null) {
        throw StateError('تعذّر بدء المعاملة — لا معرّف في الاستجابة');
      }

      // ① كل القراءات أولاً (§2.6).
      final int? current = await _readCounter(name, transactionId);
      final int next = nextSequence(current);

      // ② ثم الكتابة، داخل المعاملة نفسها.
      final firestore.Document updated = firestore.Document()
        ..fields = <String, firestore.Value>{
          counterValueField: firestore.Value.fromJson(
            encodeFirestoreValue(next),
          ),
        };

      try {
        await _api.projects.databases.documents.commit(
          firestore.CommitRequest()
            ..transaction = transactionId
            ..writes = <firestore.Write>[
              firestore.Write()
                ..update = (updated..name = name)
                // ⛔ الحقول المذكورة وحدها تُكتب — فلا يُمحى حقل آخر سهواً.
                ..updateMask =
                    (firestore.DocumentMask()..fieldPaths = <String>[
                      counterValueField,
                    ]),
            ],
          'projects/$projectId/databases/$databaseId',
        );
        return AllocatedSequence(sequence: next, counterId: documentId);
      } on firestore.DetailedApiRequestError catch (error) {
        // 409 = تعارض تزامن · 400 = المعاملة بطلت. وكلاهما يُعاد.
        final bool retryable = error.status == 409 || error.status == 400;
        if (!retryable || attempt == maxAttempts) rethrow;
        // ⛔ لا ابتلاع صامت: الفشل النهائي يُرمى، والمحاولة الوسطى تُعاد فقط.
        await Future<void>.delayed(_backoffFor(attempt));
      }
    }

    throw StateError(
      'تعذّر تخصيص رقم بعد $maxAttempts محاولات — تعارض تزامن مستمر',
    );
  }

  /// تباعد أسّي **بتشويش عشوائي** — والتشويش هو الجوهر لا التزيين.
  ///
  /// ⚠️ **التباعد الثابت لا يحلّ شيئاً هنا:** المتنافسون يفشلون في اللحظة
  /// نفسها، فينتظرون المدة نفسها، **فيتصادمون مرة أخرى بالضبط**. والعشوائية
  /// وحدها تكسر هذا التزامن.
  Duration _backoffFor(int attempt) {
    final int ceiling = _backoffBase.inMilliseconds * (1 << (attempt - 1));
    return Duration(milliseconds: _random.nextInt(ceiling) + 1);
  }

  Future<int?> _readCounter(String name, String transactionId) async {
    try {
      final firestore.Document doc =
          await _api.projects.databases.documents.get(
        name,
        transaction: transactionId,
      );
      final Object? value = decodeFirestoreFields(
        doc.fields?.map(
          (String k, firestore.Value v) =>
              MapEntry<String, Object?>(k, v.toJson()),
        ),
      )[counterValueField];
      return value is int ? value : null;
    } on firestore.DetailedApiRequestError catch (error) {
      // ★ غياب العدّاد ليس خطأً — أول جونية في اليوم تبدأ من ١.
      if (error.status == 404) return null;
      rethrow;
    }
  }
}

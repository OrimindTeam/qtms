/// تنفيذ تهيئة الحسابات — **الطرف الذي يلمس الشبكة**.
///
/// ★ **مفصول عن `account_provisioning.dart` عمداً**، بنفس منطق
/// `owner_bootstrap_handler.dart` و`permission_sync_handler.dart`: كل قرار
/// في دوال خالصة تُختبَر بلا سحابة؛ **وهنا اللقطة والأثر** وحدهما.
///
/// ★ **وترتيب الأثر مقصود:** ① تُقرأ اللقطة كاملةً ② ثم يُخطَّط خالصاً
/// ③ ثم تُنفَّذ الكتابات. ⛔ **ولا قراءة بين كتابتين** — فلو تغيّرت القاعدة
/// أثناء التنفيذ لَخطَّطنا على نصف حالة.
///
/// ⚠️ **ولماذا ليست معاملة ذرّية واحدة:** المستندات المكتوبة قد تكون
/// **بعدد الأطراف** (مئات)، وحدّ المعاملة أضيق من ذلك. ✅ **والذرّية ليست
/// مطلوبة هنا أصلاً:** كل كتابة **مستقلة ومُشتقّة المعرّف**، ⟵ **فالتشغيل
/// الجزئي ثم إعادة التشغيل يُكملان الناقص بلا ازدواج ولا تراكم** — وهو
/// معنى «قابلة للتكرار بلا أثر جانبي» (`coding-standards.md` §2.7).
/// ⛔ **بخلاف `ADR-0013` القاعدة 1** التي تحكم **كتابة المستخدم وقيدها**،
/// وهذه ليست كتابة مستخدم بل **بناء ملخّص مشتقّ** (`ADR-0008`).
library;

import 'package:qtms_domain/qtms_domain.dart';

import 'account_provisioning.dart';
import 'firestore_event.dart';
import 'firestore_writer.dart';

/// ما تحتاجه التهيئة من القاعدة — ⛔ **ولا شيء أكثر**.
///
/// ★ **واجهة ضيّقة عمداً:** تُحقَن فيُختبَر المنفّذ بلا سحابة، وتمنع أن
/// يتسرّب إلى هذا الملف وصولٌ لا تحتاجه العملية.
abstract interface class ProvisioningStore {
  /// يعدّد معرّفات مستندات مجموعة كاملةً.
  Future<List<String>> listDocumentIds(String collectionId);

  /// يعيد أول مستند يحمل [field] بقيمة `true`، أو `null`.
  Future<StoredDocument?> findFirstWhereTrue({
    required String collectionId,
    required String field,
  });

  /// يكتب مستنداً بقناع كتابة — ⛔ وبدون القناع تُمحى بقية الحقول.
  Future<void> writeDocument({
    required String collectionId,
    required String documentId,
    required Map<String, Object?> data,
    List<String>? updateMask,
  });
}

/// وصلةٌ رقيقة تجعل [FirestoreWriter] يفي بعقد [ProvisioningStore].
///
/// ★ **اتجاه الاعتماد مقصود:** الكاتب لا يعرف التهيئة، والوصلة هنا —
/// فلا يرتهن ملفٌ عام بحاجة عمليةٍ بعينها.
final class FirestoreProvisioningStore implements ProvisioningStore {
  /// ينشئ الوصلة على كاتب قائم.
  const FirestoreProvisioningStore(this._writer);

  final FirestoreWriter _writer;

  @override
  Future<List<String>> listDocumentIds(String collectionId) =>
      _writer.listDocumentIds(collectionId);

  @override
  Future<StoredDocument?> findFirstWhereTrue({
    required String collectionId,
    required String field,
  }) =>
      _writer.findFirstWhereTrue(collectionId: collectionId, field: field);

  @override
  Future<void> writeDocument({
    required String collectionId,
    required String documentId,
    required Map<String, Object?> data,
    List<String>? updateMask,
  }) =>
      _writer.writeDocument(
        collectionId: collectionId,
        documentId: documentId,
        data: data,
        updateMask: updateMask,
      );
}

/// ماذا حدث فعلاً في هذا الاستدعاء.
enum ProvisioningOutcomeKind {
  /// ★ حدثٌ لا يخصّ التهيئة (مجموعة أخرى أو تغيير غير إنشاء) — **تُجوهَل**.
  ///
  /// ⛔ **وليست فشلاً:** المشغّل قد يُوسَّع لاحقاً، والتجاهل الصريح
  /// أوضح من رفضٍ يُقلق من يقرأ السجل.
  ignored,

  /// رُفض الحدث — حمولته لا تكفي لتحديد ما يُهيَّأ.
  rejected,

  /// لا شيء ناقص — كل الحسابات قائمة.
  nothingToDo,

  /// نُفِّذت الكتابات.
  applied,
}

/// نتيجة استدعاء واحد.
final class ProvisioningOutcome {
  /// ينشئ النتيجة.
  const ProvisioningOutcome({
    required this.kind,
    this.documentsWritten = 0,
    this.scrapMissing = false,
  });

  /// ماذا حدث.
  final ProvisioningOutcomeKind kind;

  /// عدد المستندات المكتوبة فعلاً.
  final int documentsWritten;

  /// ★ **النوع الافتراضي «السكرب» غير موجود** — راجع
  /// [AccountProvisioningAccepted.scrapMissing].
  final bool scrapMissing;

  @override
  String toString() => 'ProvisioningOutcome(${kind.name}, '
      'documentsWritten: $documentsWritten, scrapMissing: $scrapMissing)';
}

/// منفّذ تهيئة الحسابات على حدث كتابة.
final class AccountProvisioningHandler {
  /// ينشئ المنفّذ بتبعيته — ★ **تُحقَن، فيُختبَر بلا سحابة**.
  const AccountProvisioningHandler(this._store);

  final ProvisioningStore _store;

  /// ينفّذ التهيئة على سمات حدث كتابة.
  ///
  /// ★ **سمات الحدث تكفي** — ⛔ **ولا حاجة لفكّ حمولته** (`DEBT-16`):
  /// المسار ونوع التغيير يصلان في [subject] و[eventType] خارجها.
  Future<ProvisioningOutcome> handleEvent({
    required String eventType,
    required String? subject,
  }) async {
    final FirestoreDocumentEvent? event =
        FirestoreDocumentEvent.tryParseAttributesOnly(
      eventType: eventType,
      subject: subject,
    );
    if (event == null) {
      return const ProvisioningOutcome(kind: ProvisioningOutcomeKind.rejected);
    }
    // ★ الإنشاء وحده يُهيِّئ — والتعديل لا يُضيف طرفاً ولا مصدراً.
    if (event.kind != DocumentChangeKind.created) {
      return const ProvisioningOutcome(kind: ProvisioningOutcomeKind.ignored);
    }

    final List<String> segments = event.documentPath.split('/');
    // ⛔ مستند فرعي لا مستند جذر — لا يخصّ التهيئة.
    if (segments.length != 2) {
      return const ProvisioningOutcome(kind: ProvisioningOutcomeKind.ignored);
    }
    final ProvisioningTrigger? trigger =
        ProvisioningTrigger.fromCollection(segments.first);
    if (trigger == null) {
      return const ProvisioningOutcome(kind: ProvisioningOutcomeKind.ignored);
    }

    return _provision(trigger, segments.last);
  }

  Future<ProvisioningOutcome> _provision(
    ProvisioningTrigger trigger,
    String entityId,
  ) async {
    final AccountProvisioningPlan plan = planAccountProvisioning(
      await _snapshot(trigger, entityId),
    );

    return switch (plan) {
      AccountProvisioningRejected() =>
        const ProvisioningOutcome(kind: ProvisioningOutcomeKind.rejected),
      AccountProvisioningNothingToDo() =>
        const ProvisioningOutcome(kind: ProvisioningOutcomeKind.nothingToDo),
      AccountProvisioningAccepted() => await _apply(plan),
    };
  }

  /// ★ **كل القراءات أولاً** — `coding-standards.md` §2.6.
  Future<AccountProvisioningRequest> _snapshot(
    ProvisioningTrigger trigger,
    String entityId,
  ) async {
    final bool bySource = trigger == ProvisioningTrigger.sourceAdded;
    final bool touchesDealers =
        bySource || trigger == ProvisioningTrigger.dealerAdded;
    final bool touchesSuppliers =
        bySource || trigger == ProvisioningTrigger.supplierAdded;

    return AccountProvisioningRequest(
      trigger: trigger,
      entityId: entityId,
      dealerIds: bySource ? await _ids(dealersCollection) : const <String>[],
      supplierIds:
          bySource ? await _ids(suppliersCollection) : const <String>[],
      sourceIds: bySource ? const <String>[] : await _ids(sourcesCollection),
      existingDealerBalanceKeys: touchesDealers
          ? (await _ids(dealerBalancesCollection)).toSet()
          : const <String>{},
      existingSupplierBalanceKeys: touchesSuppliers
          ? (await _ids(supplierBalancesCollection)).toSet()
          : const <String>{},
      scrapItem: bySource ? await _scrapItem() : null,
    );
  }

  Future<List<String>> _ids(String collectionId) =>
      _store.listDocumentIds(collectionId);

  /// يقرأ النوع الافتراضي «السكرب» ولقطة مصادره.
  Future<ScrapItemSnapshot?> _scrapItem() async {
    final StoredDocument? doc = await _store.findFirstWhereTrue(
      collectionId: itemsCollection,
      field: systemDefaultItemField,
    );
    if (doc == null) return null;
    final Object? sources = doc.fields['sourceIds'];
    return ScrapItemSnapshot(
      itemId: doc.id,
      // ⛔ حقل غائب أو من نوع آخر يُعامَل قائمةً فارغة لا خطأً — والوصل
      //   حينها يُضيف المصدر بلا أن يمحو شيئاً.
      sourceIds: sources is List
          ? sources.whereType<String>().toList(growable: false)
          : const <String>[],
    );
  }

  Future<ProvisioningOutcome> _apply(AccountProvisioningAccepted plan) async {
    for (final ProvisioningWrite write in plan.writes) {
      await _store.writeDocument(
        collectionId: write.collectionId,
        documentId: write.documentId,
        data: write.fields,
        updateMask: write.updateMask,
      );
    }
    return ProvisioningOutcome(
      kind: plan.writes.isEmpty
          ? ProvisioningOutcomeKind.nothingToDo
          : ProvisioningOutcomeKind.applied,
      documentsWritten: plan.writes.length,
      scrapMissing: plan.scrapMissing,
    );
  }
}

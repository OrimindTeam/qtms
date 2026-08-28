/// تهيئة الحسابات عند إضافة مصدر أو طرف — **التخطيط الخالص**.
///
/// يخدم العمليتين المشغَّلتين بالكتابة في `api-overview.md` §3.2:
///
/// | العملية | المُشغِّل | ما تفعله |
/// |---|---|---|
/// | `provisionAccountsOnSourceAdd` | إضافة مصدر | حساب لكل مقوت ولكل رعوي **+ نسخة السكرب** |
/// | `provisionAccountsOnPartyAdd` | إضافة مقوت أو رعوي | حساب له في **كل** المصادر القائمة |
///
/// ★ **وهما وجهان لعملية واحدة** — نفس الحاصل الديكارتي (طرف × مصدر) من
/// طرفيه. ⟵ **فمنطقهما واحد هنا، والفرق في الضلع الثابت وحده.**
///
/// ═══════════════════════════════════════════════════════════════════════
/// ★★ **الحقيقة التي فتحت الطريق أمام هذه العملية (2026-08-24):**
/// كان يُظنّ أن `DEBT-16` (فكّ حمولة protobuf) يحجب كل عملية مشغَّلة.
/// ⛔ **وهو لا يحجب هذه**: كل ما تحتاجه هو **أي مستند أُنشئ** — والمسار
/// ونوع التغيير يصلان في `subject` و`type` **خارج الحمولة**، فتكفيهما
/// `FirestoreDocumentEvent.tryParseAttributesOnly` ⛔ **بلا فكّ حقل واحد.**
///
/// ═══════════════════════════════════════════════════════════════════════
/// ★★★ **أخطر قاعدة في هذا الملف — التهيئة تُنشئ الناقص ولا تلمس القائم:**
///
/// المُشغِّل قد يُنفَّذ مرتين أو خارج الترتيب (`api-overview.md` §3.3 ·
/// `PAT-08`). ⛔ **فلو كتبت التهيئة أصفاراً فوق حسابٍ قائم لَمَحَت رصيداً
/// حقيقياً بلا أي إنذار** — ★ **وهو أسوأ ما يمكن أن يفعله كودٌ محاسبي.**
///
/// ⟵ ★ **ولذلك يستقبل المخطِّط مفاتيحَ الحسابات القائمة ويستبعدها**، فلا
/// يُنتج إلا كتابةَ إنشاءٍ لما لا وجود له. ✅ **وبهذا تصير العملية قابلة
/// للتكرار بلا أثر جانبي حقيقةً لا ادّعاءً.**
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔ **وما لا يكتبه هذا الملف عمداً — ولماذا:**
///
///   ① **«عدد الضمارات المفتوحة» و«تاريخ أقدمها»** (`data-dictionary.md`
///      §`dealer_balances`): ⛔ **لا اسم حقلٍ موثَّقٌ لهما في أي مستند**،
///      ★ **ولا يُخترَع اسم**. ✅ **ولا حاجة أصلاً:** الرصيد **مشتقّ من
///      الدفتر دائماً** (`ADR-0008`)، ويعيد `recalculateDealerAndDebtLot`
///      بناءه بالكامل — ⟵ **فحقل التهيئة لهما لا معنى له.**
///
///   ② ★ **قيد تدقيق**: ⛔ **لا يُكتب.** سجل التدقيق سجلُّ **أفعال
///      المستخدمين** (`M18`)، ⟵ **وهذه مستندات ملخّص تشتقّها السحابة**
///      (`ADR-0008`). ⚠️ **ولو كُتب لَأنتجت إضافةُ مصدرٍ واحدٍ قيداً لكل
///      مقوت ولكل رعوي** — ★ **فأغرقت السجل بضجيج يُخفي التغييرات
///      الحقيقية**، وهو نقيض الغرض منه.
library;

import 'package:qtms_domain/qtms_domain.dart';

import 'callable.dart';

/// حقل النوع الافتراضي في [itemsCollection] (`data-dictionary.md` §`items`).
const String systemDefaultItemField = 'isSystemDefault';

// ★★ **وأسماء المجموعات من طبقة النطاق** (`master_data.dart` في
// `qtms_domain`) — ⛔ **ولا نسخة ثانية منها هنا**: `coding-standards.md`
// §2.2 («مصدر حقيقة واحد» · `P-10`)، ⟵ **ونسختان تفترقان عند أول تعديل
// فتكتب السحابة في مجموعة ويقرأ التطبيق من أخرى.**

/// الطرف الذي أُضيف، أو المصدر — حسب المُشغِّل.
enum ProvisioningTrigger {
  /// أُضيف مصدر ⟵ يُهيَّأ له حساب لكل طرف قائم، **وتُوصَل به نسخة السكرب**.
  sourceAdded,

  /// أُضيف مقوت ⟵ يُهيَّأ له حساب في كل مصدر قائم.
  dealerAdded,

  /// أُضيف رعوي ⟵ يُهيَّأ له حساب في كل مصدر قائم.
  supplierAdded;

  /// يشتقّ المُشغِّل من مجموعة المستند الذي أُنشئ.
  ///
  /// ⟵ ★ **وهذا كل ما تحتاجه العملية من الحدث** — راجع ترويسة الملف.
  static ProvisioningTrigger? fromCollection(String collection) =>
      switch (collection) {
        sourcesCollection => ProvisioningTrigger.sourceAdded,
        dealersCollection => ProvisioningTrigger.dealerAdded,
        suppliersCollection => ProvisioningTrigger.supplierAdded,
        _ => null,
      };
}

/// لقطة النوع الافتراضي «السكرب» كما هو الآن.
///
/// ★ **واحدٌ في النظام كله لا واحدٌ لكل مصدر** — لأن `normalizedName`
/// **فريد على مستوى النظام** (`data-dictionary.md` §`items`)، ⟵ **فالربط
/// بالمصادر عبر `sourceIds` لا بنسخ متعددة.**
final class ScrapItemSnapshot {
  /// ينشئ اللقطة.
  const ScrapItemSnapshot({required this.itemId, required this.sourceIds});

  /// معرّف النوع — مثل `ITM-0001`.
  final String itemId;

  /// المصادر المرتبط بها الآن.
  final List<String> sourceIds;
}

/// طلب تهيئة — **لقطةٌ مقروءة قبل التخطيط**، فالمخطِّط خالص لا يقرأ شيئاً.
final class AccountProvisioningRequest {
  /// ينشئ الطلب.
  const AccountProvisioningRequest({
    required this.trigger,
    required this.entityId,
    required this.dealerIds,
    required this.supplierIds,
    required this.sourceIds,
    required this.existingDealerBalanceKeys,
    required this.existingSupplierBalanceKeys,
    this.scrapItem,
  });

  /// ما الذي أُضيف.
  final ProvisioningTrigger trigger;

  /// معرّف الكيان المُضاف — `SRC-001` أو `DLR-001` أو `SUP-001`.
  final String entityId;

  /// كل المقاوته القائمين — **يُستعمل مع [ProvisioningTrigger.sourceAdded]**.
  final List<String> dealerIds;

  /// كل الرعوية القائمين — **يُستعمل مع [ProvisioningTrigger.sourceAdded]**.
  final List<String> supplierIds;

  /// كل المصادر القائمة — **تُستعمل مع مُشغِّلَي الطرف**.
  final List<String> sourceIds;

  /// ★ مفاتيح حسابات المقاوته **القائمة فعلاً** — ⛔ ولا تُمَسّ.
  final Set<String> existingDealerBalanceKeys;

  /// ★ مفاتيح حسابات الرعوية **القائمة فعلاً** — ⛔ ولا تُمَسّ.
  final Set<String> existingSupplierBalanceKeys;

  /// النوع الافتراضي «السكرب» إن وُجد — و`null` إن لم يُنشأ بعد.
  final ScrapItemSnapshot? scrapItem;
}

/// كتابة مستند واحدة ضمن الخطة.
final class ProvisioningWrite {
  /// ينشئ الكتابة.
  const ProvisioningWrite({
    required this.collectionId,
    required this.documentId,
    required this.fields,
    required this.updateMask,
  });

  /// المجموعة المكتوب فيها.
  final String collectionId;

  /// معرّف المستند — ★ **مُشتقّ لا مُولَّد**، فإعادة التشغيل تُصيب نفسه.
  final String documentId;

  /// الحقول التي تُكتب.
  final Map<String, Object?> fields;

  /// ★ **قناع الكتابة** — ⛔ وبدونه تُمحى بقية حقول المستند.
  final List<String> updateMask;

  /// المسار النسبي — للتشخيص والسجل.
  String get path => '$collectionId/$documentId';
}

/// نتيجة التخطيط.
sealed class AccountProvisioningPlan {
  /// ينشئ النتيجة.
  const AccountProvisioningPlan();
}

/// رُفض الطلب قبل أي كتابة.
final class AccountProvisioningRejected extends AccountProvisioningPlan {
  /// ينشئ رفضاً.
  const AccountProvisioningRejected(this.error);

  /// رمز الرفض من كتالوج الأخطاء.
  final CallableError error;
}

/// ★ **لا شيء ناقص** — كل الحسابات قائمة، ⛔ فلا كتابة ولا أثر.
///
/// ★ **ونجاحٌ لا رفض:** الاستدعاء الثاني لم يفشل، بل وجد الحالة المطلوبة
/// قائمة — وهو معنى «قابلية التكرار بلا أثر جانبي» (`coding-standards.md`
/// §2.7).
final class AccountProvisioningNothingToDo extends AccountProvisioningPlan {
  /// ينشئ نتيجة «لا شيء ناقص».
  const AccountProvisioningNothingToDo();
}

/// قُبل الطلب — وهذه كتاباته.
final class AccountProvisioningAccepted extends AccountProvisioningPlan {
  /// ينشئ خطة مقبولة.
  const AccountProvisioningAccepted({
    required this.writes,
    required this.scrapLinked,
    required this.scrapMissing,
  });

  /// الكتابات المطلوبة — **إنشاءُ الناقص وحده**.
  final List<ProvisioningWrite> writes;

  /// هل تضمّنت الخطة وصلَ المصدر الجديد بنسخة السكرب؟
  final bool scrapLinked;

  /// ★ **السكرب غير موجود بعد** — ⛔ **ولا يُنشأ هنا.**
  ///
  /// إنشاء النوع الافتراضي من اختصاص وحدة الأنواع (`M5`) التي تملك ترقيمه
  /// وحقوله. ⟵ ★ **والتهيئة تصل ولا تخترع**، وتُبلِّغ بهذه الراية فيُرصَد
  /// النقص بدل أن يُبتلَع صامتاً.
  final bool scrapMissing;
}

/// ★ مفتاح حساب مركّب — `{partyId}_{sourceId}` (`data-dictionary.md`).
String balanceKey(String partyId, String sourceId) => '${partyId}_$sourceId';

/// نتيجة خطوة السكرب — الكتابة إن لزمت، وراية الغياب.
final class _ScrapStep {
  const _ScrapStep({this.write, this.missing = false});

  final ProvisioningWrite? write;
  final bool missing;
}

/// يخطّط تهيئة الحسابات — **دالة خالصة**.
///
/// ★ **ترتيب الفحوص مقصود:** صحّة الطلب، ثم حصر الأزواج، ثم استبعاد القائم.
AccountProvisioningPlan planAccountProvisioning(
  AccountProvisioningRequest request,
) {
  // ① معرّف الكيان إلزامي — ولا معنى لتهيئة حساب لطرفٍ بلا هوية.
  final String entityId = request.entityId.trim();
  if (entityId.isEmpty) {
    return const AccountProvisioningRejected(CallableError.invalidArgument);
  }

  final List<ProvisioningWrite> writes = <ProvisioningWrite>[];
  _ScrapStep scrap = const _ScrapStep();

  switch (request.trigger) {
    case ProvisioningTrigger.sourceAdded:
      _addBalancesForNewSource(writes, request, entityId);
      scrap = _linkScrapToSource(request.scrapItem, entityId);
      final ProvisioningWrite? scrapWrite = scrap.write;
      if (scrapWrite != null) writes.add(scrapWrite);

    case ProvisioningTrigger.dealerAdded:
      for (final String sourceId in _clean(request.sourceIds)) {
        _addDealerBalance(writes, request, entityId, sourceId);
      }

    case ProvisioningTrigger.supplierAdded:
      for (final String sourceId in _clean(request.sourceIds)) {
        _addSupplierBalance(writes, request, entityId, sourceId);
      }
  }

  if (writes.isEmpty && !scrap.missing) {
    return const AccountProvisioningNothingToDo();
  }
  return AccountProvisioningAccepted(
    writes: List<ProvisioningWrite>.unmodifiable(writes),
    scrapLinked: scrap.write != null,
    scrapMissing: scrap.missing,
  );
}

/// حساب لكل مقوت ولكل رعوي في المصدر الجديد.
void _addBalancesForNewSource(
  List<ProvisioningWrite> writes,
  AccountProvisioningRequest request,
  String sourceId,
) {
  for (final String dealerId in _clean(request.dealerIds)) {
    _addDealerBalance(writes, request, dealerId, sourceId);
  }
  for (final String supplierId in _clean(request.supplierIds)) {
    _addSupplierBalance(writes, request, supplierId, sourceId);
  }
}

/// ★ «+ نسخة السكرب» — وصلُ المصدر الجديد بالنوع الافتراضي.
_ScrapStep _linkScrapToSource(ScrapItemSnapshot? scrap, String sourceId) {
  if (scrap == null) return const _ScrapStep(missing: true);
  if (scrap.sourceIds.contains(sourceId)) return const _ScrapStep();
  return _ScrapStep(
    write: ProvisioningWrite(
      collectionId: itemsCollection,
      documentId: scrap.itemId,
      // ★ **اتحاد لا استبدال** — ⛔ وكتابة المصدر الجديد وحده تفصل النوعَ
      //   عن كل المصادر السابقة.
      fields: <String, Object?>{
        'sourceIds': <String>[...scrap.sourceIds, sourceId],
      },
      updateMask: const <String>['sourceIds'],
    ),
  );
}

/// يُسقِط الفارغ والمكرّر ويحفظ الترتيب — فلا كتابة مزدوجة لمعرّف واحد.
Iterable<String> _clean(List<String> ids) {
  final Set<String> seen = <String>{};
  return ids.map((String id) => id.trim()).where(
        (String id) => id.isNotEmpty && seen.add(id),
      );
}

void _addDealerBalance(
  List<ProvisioningWrite> writes,
  AccountProvisioningRequest request,
  String dealerId,
  String sourceId,
) {
  final String key = balanceKey(dealerId, sourceId);
  if (request.existingDealerBalanceKeys.contains(key)) return;
  writes.add(ProvisioningWrite(
    collectionId: dealerBalancesCollection,
    documentId: key,
    // ★ **كل مبلغ عدد صحيح بالريال** (`ADR-0015`) — ⛔ ولا `0.0` ولا نصّ.
    fields: <String, Object?>{
      'dealerId': dealerId,
      'sourceId': sourceId,
      'totalDebit': 0,
      'totalCredit': 0,
      'balance': 0,
    },
    updateMask: const <String>[
      'dealerId',
      'sourceId',
      'totalDebit',
      'totalCredit',
      'balance',
    ],
  ));
}

void _addSupplierBalance(
  List<ProvisioningWrite> writes,
  AccountProvisioningRequest request,
  String supplierId,
  String sourceId,
) {
  final String key = balanceKey(supplierId, sourceId);
  if (request.existingSupplierBalanceKeys.contains(key)) return;
  writes.add(ProvisioningWrite(
    collectionId: supplierBalancesCollection,
    documentId: key,
    // ★ **`sourceId` حقلٌ صريح لا زينة:** قاعدة قراءة `supplier_balances`
    //   تستدعي `storedInScope()`، وهي تشترط `'sourceId' in resource.data`.
    //   ⛔ **فالمستند بلا هذا الحقل لا يقرؤه أحد إطلاقاً.**
    fields: <String, Object?>{
      'supplierId': supplierId,
      'sourceId': sourceId,
      'totalRevenue': 0,
      'totalTax': 0,
      'net': 0,
    },
    updateMask: const <String>[
      'supplierId',
      'sourceId',
      'totalRevenue',
      'totalTax',
      'net',
    ],
  ));
}

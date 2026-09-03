/// مالية الجواني وحساب الرعوي — **التخطيط الخالص** لـ`WU-015` (`M14`).
///
/// ★ **مفصول عن الشبكة بنفس منطق `distribution.dart`:** كل قرارٍ هنا **دالة
/// خالصة تُختبَر بلا سحابة**، ⛔ **والقراءة والالتزام في
/// `sack_valuation_handler.dart` وحده.**
///
/// ★ **وكل معادلة من طبقة النطاق لا من هنا** (`computeSackRevenue` ·
/// `computeSupplierNet` · `computeSupplierSourceTotals`) —
/// ⛔ **ولا تُعاد كتابتها** (`coding-standards.md` §2.2).
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **ثلاث قواعد يفرضها هذا الملف — وكلُّها من `api-overview.md` §3.3:**
///
///   ① ★★★ **قابلٌ للتكرار بلا أثر جانبي** — **يُعيد البناء من المستندات
///      بالكامل** ⛔ **ولا يُراكِم على قيمة سابقة**: ⟵ **والمعرّفات حتمية**
///      (`supplier_ledger/{sackId}` · `supplier_balances/{supplierId}_{sourceId}`)،
///      ★ **فتشغيلُه مرتين يُنتج الرقم نفسَه** (`PAT-08`).
///   ② ⛔⛔ **ولا يُكتب شيءٌ إن لم يتغيّر شيء** — ★ **و`recalcVersion` لا
///      يتضخّم بلا سبب**: ⟵ **فرقمُ إعادة الاحتساب يبقى دالاً على تغيّرٍ
///      وقع فعلاً** ⛔ **لا على عدد مرات التشغيل.**
///   ③ ★★ **والضريبةُ المعلّقة تُكتب `null` لا صفراً** (`FR-M7-10` ·
///      `ADR-0008` القاعدة 5) — ⟵ **وصفرٌ هنا كان يجعل الصافي يساوي السعر
///      فيبدو الحسابُ مستقراً وهو لم يُحتسب بعد.**
/// ═══════════════════════════════════════════════════════════════════════
library;

import 'package:qtms_domain/qtms_domain.dart';

import 'inventory.dart' show InventoryWrite;

/// اسم حقل رقم إعادة الاحتساب — ★ **يُقرأ ويُكتب من موضعٍ واحد**.
const String recalcVersionField = 'recalcVersion';

/// ★ حالةُ جونيةٍ كما قُرئت قبل الاحتساب — **المخزَّن مع ما يلزم لبنائه**.
final class SackValuationState {
  /// ينشئ الحالة.
  const SackValuationState({
    required this.sackId,
    required this.sourceId,
    required this.displayName,
    this.supplierId,
    this.supplierName,
    this.isCancelled = false,
    this.sackTax,
    this.storedRevenue,
    this.storedNet,
    this.storedRevenueFinal,
    this.storedRecalcVersion = 0,
  });

  /// رقم الجونية — ★ **وهو معرّف سطر دفتر الرعية نفسُه**.
  final String sackId;

  /// المصدر — ⛔ **إلزامي: لكل رعوي حساب في كل مصدر** (`A-11`).
  final String sourceId;

  /// الاسم الظاهر.
  final String displayName;

  /// ★ الرعوي أو `null` **إن كان المصدر لا يشترطه** (`FR-M7-03`).
  final String? supplierId;

  /// اسم الرعوي كما كان لحظة الإنشاء.
  final String? supplierName;

  /// هل الجونية ملغاة؟ (`GR-06`).
  final bool isCancelled;

  /// 🔵 ضريبتها المخزَّنة في `finance/current` أو `null` **إن كانت معلّقة**.
  final Money? sackTax;

  /// الإيراد المخزَّن — **للمقارنة وحدها** (القاعدة ②).
  final Money? storedRevenue;

  /// الصافي المخزَّن — **للمقارنة وحدها**.
  final Money? storedNet;

  /// وسمُ النهائية المخزَّن — **للمقارنة وحدها**.
  final bool? storedRevenueFinal;

  /// رقم إعادة الاحتساب المخزَّن في دفتر الرعية — ★ **و`0` تعني «لا سطر بعد»**.
  final int storedRecalcVersion;
}

/// ★ نتيجةُ احتسابِ جونيةٍ واحدة — **الرقم وما إن كان قد تغيّر**.
final class SackValuationResult {
  /// ينشئ النتيجة.
  const SackValuationResult({
    required this.sackId,
    required this.revenue,
    required this.changed,
    this.supplierNet,
  });

  /// رقم الجونية.
  final String sackId;

  /// سعرها وحالةُ نهائيته.
  final SackRevenue revenue;

  /// ★ صافي الرعوي أو `null` **إن كانت الضريبة معلّقة** (القاعدة ③).
  final Money? supplierNet;

  /// ★ هل اختلف المحتسَب عن المخزَّن؟ — ⛔ **وبلا اختلافٍ لا كتابة**.
  final bool changed;
}

/// ★★ خطةُ احتساب دفعةٍ من الجواني — **كتاباتُها ونتائجُها والرعية المتأثرون**.
final class SackValuationPlan {
  /// ينشئ الخطة.
  const SackValuationPlan({
    required this.writes,
    required this.results,
    required this.touchedSupplierIds,
  });

  /// ★ خطةٌ فارغة — **لا جونية تغيّرت**.
  static const SackValuationPlan empty = SackValuationPlan(
    writes: <InventoryWrite>[],
    results: <SackValuationResult>[],
    touchedSupplierIds: <String>{},
  );

  /// الكتابات — **مالية الجونية وسطرُ دفتر الرعية**.
  final List<InventoryWrite> writes;

  /// نتيجةُ كل جونية — ★ **حتى غيرِ المتغيّرة**، ⟵ **فالمُستدعي يُبلِّغ بها.**
  final List<SackValuationResult> results;

  /// ★ الرعيةُ الذين تغيّرت جوانيهم — ⟵ **وأرصدتُهم وحدهم تُعاد بناءً**.
  final Set<String> touchedSupplierIds;

  /// هل في الخطة كتابةٌ واحدة؟
  bool get isEmpty => writes.isEmpty;
}

/// ★★★ **يخطّط احتساب دفعةٍ من جواني (مصدر × تاريخ مخزون)** — `FR-M14-05`.
///
/// ⚠️⚠️ **وبتجميعٍ لا بعد كل حركة منفردة** (`sack-valuation-design.md` §6
/// القاعدة 1 · `NFR-PERF-05`): ★ **المستنداتُ تُقرأ مرةً واحدة للدفعة كلها**،
/// ⟵ **وكلُّ جونيةٍ تُصفّيها بمرجعها هي** ⛔ **لا استعلامٌ لكل جونية.**
SackValuationPlan planSackValuation({
  required List<SackValuationState> sacks,
  required List<SackMovementDocument> documents,
}) {
  final List<InventoryWrite> writes = <InventoryWrite>[];
  final List<SackValuationResult> results = <SackValuationResult>[];
  final Set<String> suppliers = <String>{};

  for (final SackValuationState sack in sacks) {
    final SackRevenue revenue = computeSackRevenue(
      contributionsForSack(sackId: sack.sackId, documents: documents),
    );
    final Money? tax = sack.sackTax;
    final Money? net = tax == null
        ? null
        : computeSupplierNet(sackRevenue: revenue.total, sackTax: tax);
    final bool changed = _hasChanged(sack, revenue: revenue, net: net);

    results.add(
      SackValuationResult(
        sackId: sack.sackId,
        revenue: revenue,
        supplierNet: net,
        changed: changed,
      ),
    );
    if (!changed) continue;

    writes.add(_financeWrite(sack, revenue: revenue, net: net));
    final String? supplierId = sack.supplierId;
    // ⛔★★ **ولا سطرَ دفترٍ لجونيةٍ بلا رعوي** — `FR-M7-03`: **مصدرٌ لا
    //    يشترط الرعوي لا حسابَ رعويٍّ فيه أصلاً**، ⟵ **وسطرٌ بمعرّفٍ فارغ
    //    كان يُنشئ حساباً لا صاحب له.** ★ **وماليةُ الجونية تُكتب كما هي.**
    if (supplierId == null) continue;
    suppliers.add(supplierId);
    writes.add(
      _ledgerWrite(sack, supplierId: supplierId, revenue: revenue, net: net),
    );
  }

  return SackValuationPlan(
    writes: writes,
    results: results,
    touchedSupplierIds: suppliers,
  );
}

/// ★ هل اختلف المحتسَب عن المخزَّن؟ — راجع القاعدة ② في ترويسة الملف.
///
/// ⚠️ **وغيابُ المخزَّن اختلافٌ** — ⟵ **فأولُ احتسابٍ يُكتب دائماً**،
/// ⛔ **ولا تُقرأ جونيةٌ بلا مالية «مطابقةً» فتبقى بلا سطرٍ أبداً.**
bool _hasChanged(
  SackValuationState sack, {
  required SackRevenue revenue,
  required Money? net,
}) =>
    sack.storedRevenue != revenue.total ||
    sack.storedNet != net ||
    sack.storedRevenueFinal != revenue.isFinal ||
    sack.storedRecalcVersion == 0;

/// 🔒 **ماليةُ الجونية** — `sacks/{id}/finance/current` (`ADR-0011`).
///
/// ⛔★★ **وقناعٌ ضيّق لا يذكر `taxPerKilo` ولا `sackTax`** — ★ **يكتبهما
/// `enterSackTax` وحده** (`FR-M7-10`)، ⟵ **وذكرُهما هنا كان يمحو ضريبةً
/// أُدخلت** لأن هذا المسار لا يعرفها إلا مقروءةً.
InventoryWrite _financeWrite(
  SackValuationState sack, {
  required SackRevenue revenue,
  required Money? net,
}) {
  final Map<String, Object?> fields = <String, Object?>{
    // ★ **نسخة المصدر** — **لفحص القراءة بالنطاق بلا قراءة الأب** (القواعد).
    'sourceId': sack.sourceId,
    'sackId': sack.sackId,
    'sackRevenue': revenue.total.riyals,
    // ③ ⛔ **والصافي `null` عند ضريبةٍ معلّقة** — راجع ترويسة الملف.
    'supplierNet': net?.riyals,
    // ★★ **مصدر وسم «⏳ سعر غير نهائي»** — `FR-M14-06`.
    'isRevenueFinal': revenue.isFinal,
  };
  return InventoryWrite(
    collectionId:
        '$sacksCollection/${sack.sackId}/$sackFinanceSubcollection',
    documentId: sackFinanceDocumentId,
    fields: fields,
    updateMask: fields.keys.toList(),
    serverTimestampFields: const <String>['lastRevaluedAt'],
  );
}

/// 🔒 **سطرُ دفتر حسابات الرعية** — `supplier_ledger/{sackId}`.
///
/// ★ **سطرٌ واحدٌ لكل جونية يُعاد كتابته** — راجع [supplierLedgerEntryId]:
/// ⛔ **ولا سطرَ لكل احتساب.**
InventoryWrite _ledgerWrite(
  SackValuationState sack, {
  required String supplierId,
  required SackRevenue revenue,
  required Money? net,
}) {
  final bool isFirst = sack.storedRecalcVersion == 0;
  final Map<String, Object?> fields = <String, Object?>{
    'supplierId': supplierId,
    'supplierName': sack.supplierName,
    // ★★★ **المصدر إلزاميٌّ في كل سطر** — `A-11` · **وشرطُ القراءة يقرؤه**.
    'sourceId': sack.sourceId,
    'sackId': sack.sackId,
    'sackDisplayName': sack.displayName,
    'sackRevenue': revenue.total.riyals,
    'sackTax': sack.sackTax?.riyals,
    'supplierNet': net?.riyals,
    'isRevenueFinal': revenue.isFinal,
    // ★ **والملغاة تبقى سطراً موسوماً** — ⛔ **ولا تُحذَف** (`GR-07`).
    'isCancelled': sack.isCancelled,
    // ★★ **رقمٌ متزايد** — ⛔ **ولا يتضخّم بلا تغيّر** (القاعدة ②).
    recalcVersionField: sack.storedRecalcVersion + 1,
  };
  return InventoryWrite(
    collectionId: supplierLedgerCollection,
    documentId: supplierLedgerEntryId(sackId: sack.sackId),
    fields: fields,
    updateMask: fields.keys.toList(),
    // ★ **وتاريخُ القيد يُكتب مرةً واحدة** — ⟵ **فهو «متى سُجِّل»**،
    //   ⛔ **وإعادةُ كتابته في كل احتساب تمحو تاريخَ نشأة السطر.**
    serverTimestampFields:
        isFirst ? const <String>['entryDate'] : const <String>['lastAmendedAt'],
  );
}

/// ★★★ **يخطّط رصيد الرعوي في مصدر** — `design-overview.md` §2.5 · `FR-M14-12`.
///
/// ⚠️⚠️ **ويُبنى من كل سطور الدفتر لا من فرقٍ يُضاف** — ★ **وهو معنى «يُعيد
/// البناء من الدفتر بالكامل ولا يُراكِم»** (`api-overview.md` §3.3):
/// ⟵ **فتشغيلٌ مكرَّر أو خارج الترتيب يُنتج الرقم نفسَه.**
///
/// ⛔★★ **والملغاة لا تدخل الجمع** — ★ **يُسقِطها المُستدعي قبل الاستدعاء**،
/// ⟵ **فالمعادلة في طبقة النطاق لا تعرف الإلغاء** (`A-14`).
InventoryWrite planSupplierBalance({
  required String supplierId,
  required String sourceId,
  required Iterable<SupplierSackRow> rows,
}) {
  final SupplierSourceTotals totals = computeSupplierSourceTotals(rows);
  final Map<String, Object?> fields = <String, Object?>{
    'supplierId': supplierId,
    // ★★ **ويُقرأ في شرط النطاق** — `storedInScope()` (`IQ-024` · `DEBT-40`).
    'sourceId': sourceId,
    'totalSackRevenue': totals.totalRevenue.riyals,
    'totalSackTax': totals.totalTax.riyals,
    'supplierNet': totals.net.riyals,
    'sackCount': totals.sackCount,
    // ★ **عدّادان يقولان لماذا الرقم غير نهائي** — ⛔ **لا وسمٌ مبهم**.
    'pendingTaxCount': totals.pendingTaxCount,
    'unfinalRevenueCount': totals.unfinalRevenueCount,
  };
  return InventoryWrite(
    collectionId: supplierBalancesCollection,
    documentId: supplierBalanceId(supplierId: supplierId, sourceId: sourceId),
    fields: fields,
    updateMask: fields.keys.toList(),
    serverTimestampFields: const <String>['updatedAt'],
  );
}

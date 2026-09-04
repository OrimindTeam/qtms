/// مالية الجونية وحساب الرعوي (`M14`) — ★★★ **الإيراد الفعلي لا الافتراضي**.
///
/// ★ **المصدر:** `FR-M14-01` … `FR-M14-15` · `sack-valuation-design.md` ·
/// `design-overview.md` §2.2 و§2.5 و§2.11 · `schema/supplier-ledger.md` ·
/// `ADR-0008` (المشتقّ يُبنى ولا يُقرأ مصدرَ حقيقة) · `ADR-0015`.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔★★ **أربع قواعد بنيوية يفرضها هذا الملف بنوعه لا بشرطٍ يُنسى:**
///
///   ① ★★★ **سعر الجونية = الإيراد الفعلي المتحقق منها** (`A-13` ·
///      `BR-M14-01`) — ⛔ **ولا يدخله سعرُ التوزيع الافتراضي ولا الحد
///      الأدنى إطلاقاً**: ⟵ **فالقيمة تُقرأ من مستند الحركة نفسِه**،
///      ★ **وهو ما يُلزم به النوع [SackRevenueContribution] بحمله
///      [SackRevenueContribution.lineValue] وحدَه قيمةً معتمَدة.**
///   ② ⛔⛔ **وما لم يُصرَف لا يُحتسب** (`FR-M14-07` · `E-21`) — ★ **والنوع
///      لا يعرف «كمية الجونية» أصلاً**: ⟵ **فلا مدخلَ لحسابٍ على ما بقي
///      في المخزن.**
///   ③ ⛔⛔★★ **والإتلافُ والوزنُ الضائع وتسويةُ الجرد لا تُضيف شيئاً**
///      (`FR-M14-08` · `FR-M14-10` · `A-15`) — ★ **والاستبعادُ حقلٌ صريح
///      في المساهمة** ([SackRevenueContribution.isExcluded])، ⛔ **لا شرطٌ
///      في دالة الجمع يُنسى عند أول كاتبٍ جديد** (**درسُ `sourceDocType`
///      المحفور — 2026-08-26**).
///   ④ ★ **ولا تقريبَ في هذا الملف إلا في موضعٍ واحدٍ معلوم:** **متوسط سعر
///      الكيلو المتحقق** ([computeAverageKiloPrice]) — **الموضع ②**
///      (`design-overview.md` §2.11)، ⛔ **وهو للعرض ولا يُخزَّن.**
///      ⟵ **وقيمُ السطور تصل مقرَّبةً أصلاً من الموضع ③** (`ADR-0019`)،
///      ★ **فجمعُها جمعُ أعدادٍ صحيحة** ⛔ **بلا تقريبٍ ثانٍ.**
/// ═══════════════════════════════════════════════════════════════════════
library;

import '../../../core/money.dart';
import '../../../core/quantity.dart';
import 'inventory.dart' show StockQuantity;

// ═════════════════════════════════════════════════════════════════════════
// أسماء المجموعات — `data-dictionary.md` §3 و§4 · `naming-conventions.md` §4
// ═════════════════════════════════════════════════════════════════════════

/// دفتر حسابات الرعية — ★ **لا يُحذف منه شيء** (`schema/supplier-ledger.md`).
const String supplierLedgerCollection = 'supplier_ledger';

// ⛅ **ورصيدُ الرعوي `supplierBalancesCollection`** مُعرَّفٌ في
//    `master_data.dart` مع بقية سجلات الأرصدة — ⛔ **ولا نسخةَ ثانيةً له
//    هنا**: ★ **اسمٌ واحدٌ للمفهوم الواحد** (`naming-conventions.md` §1).

/// معرّف رصيد الرعوي — `{supplierId}_{sourceId}` (`naming-conventions.md` §4).
///
/// ⚠️ **وترتيب الأجزاء ثابت لا يُبدَّل** — «لأنه يحدد الفهارس وكفاءة
/// الاستعلام».
String supplierBalanceId({
  required String supplierId,
  required String sourceId,
}) {
  if (supplierId.isEmpty) {
    throw ArgumentError.value(supplierId, 'supplierId', 'الرعوي إلزامي');
  }
  if (sourceId.isEmpty) {
    throw ArgumentError.value(sourceId, 'sourceId', 'المصدر إلزامي في كل سطر');
  }
  return '${supplierId}_$sourceId';
}

/// ★★★ **معرّف سطر دفتر الرعية — رقمُ الجونية نفسُه** (`sackId`).
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **ولماذا سطرٌ واحدٌ لكل جونية يُعاد كتابته، لا سطرٌ لكل احتساب:**
/// ★ **`schema/supplier-ledger.md` يُعلِّل `recalcVersion` حرفياً بأنه**
/// «**يمنع تطبيق حساب قديم *فوق* حساب أحدث عند تنفيذ المشغّلات خارج
/// الترتيب**» — ⟵ **و«فوق» لا معنى لها إلا في *استبدالِ* مستندٍ واحد**:
/// ★ **فلو أُلحِق سطرٌ جديد بكل احتساب لَما كُتب شيءٌ فوق شيء أصلاً.**
///
/// ⛔⛔ **وسطرٌ لكل احتساب كان يكسر §5 من التصميم كذلك:** «**إجمالي سعر
/// الجواني في المصدر = Σ(سعر كل جونية)**» — ★ **جونيةً لا سطراً**،
/// ⟵ **فجمعُ السطور كان يُضاعف إيرادَ كل جونيةٍ عُدِّلت مرة.**
///
/// ★ **والمعرّف الحتمي هو ما يجعل العملية «قابلة للتكرار بلا أثر جانبي»**
/// (`coding-standards.md` §2.7 · `PAT-08`) — ⟵ **فإعادةُ التشغيل تكتب
/// الرقم نفسَه** ⛔ **لا سطراً ثانياً.**
/// ═══════════════════════════════════════════════════════════════════════
String supplierLedgerEntryId({required String sackId}) {
  if (sackId.isEmpty) {
    throw ArgumentError.value(sackId, 'sackId', 'رقم الجونية إلزامي');
  }
  return sackId;
}

// ═════════════════════════════════════════════════════════════════════════
// المساهمة — سطرُ حركةٍ خارجةٍ من جونية بقيمته المسجَّلة في مستنده
// ═════════════════════════════════════════════════════════════════════════

/// ★ **المستند الذي كوَّن جزءاً من سعر الجونية** — `sack-valuation-design.md` §3.
///
/// ⚠️ **ولا قيمة هنا بلا مستندٍ يكتبها فعلاً** — ★ **بنفس قاعدة
/// `SourceDocumentType`**: ⛔ **ولا تُملأ استباقاً بقيمٍ لا كاتب لها.**
enum SackRevenueSource {
  /// توزيع على مقوت — `M10` (`FR-M14-02`).
  distribution('توزيع'),

  /// بيع نقدي مباشر — `M11` (`FR-M14-02`).
  cashSale('بيع نقدي'),

  /// ★ سحبية مالك — `M22` · `E-26`: **يستحق الرعوي ثمنها** (`A-15`).
  withdrawal('سحبية'),

  /// ★ خرجية تشغيلية — `M22` · `GR-45`.
  expense('خرجية');

  const SackRevenueSource(this.label);

  /// ★ الاسم المعروض — **بالعربية من معجم المصطلحات** (`ui-guidelines.md` §6).
  ///
  /// ⚠️⚠️ **وموضعُه النطاق لا الشاشة** — ★ **بنفس `OutflowCategory.label`
  /// و`ReportFamily.label` حرفياً**: ⟵ **يقرؤه تفكيكُ `R-27` وورقةُ التفكيك
  /// معاً** (`WU-015` · `WU-018`)، ⛔ **ونسخةٌ ثانية في إحداهما تفترق عن
  /// الأخرى عند أول تسميةٍ تتغيّر** (`coding-standards.md` §2.2).
  final String label;
}

/// ★★★ **مساهمةٌ واحدة في سعر الجونية** — سطرُ حركةٍ خارجةٍ بقيمته المسجَّلة.
///
/// ⛔⛔★★ **و[lineValue] وحدُه القيمةُ المعتمدة** — ★ **يُقرأ من مستند الحركة
/// كما سُجِّل فيه** (`sack-valuation-design.md` §2 الخطوة ③)، ⛔ **ولا
/// يُعاد اشتقاقُه هنا من الكمية والسعر:** ⟵ **فالسطرُ الوزنيُّ مرَّ بالتقريب
/// (الموضع ③ · `ADR-0019`) لحظةَ حفظِ مستنده**، ★ **وإعادةُ ضربِه هنا
/// كانت تُنتج رقماً يخالف ما في المستند بريالٍ أو ريالين** ⛔ **بلا إنذار.**
///
/// ★ **و[unitPrice] و[quantity] للعرض والتفكيك وحدهما** (`FR-M14-15`) —
/// ⛔ **ولا يدخلان أي جمع.**
final class SackRevenueContribution {
  /// ينشئ المساهمة.
  const SackRevenueContribution({
    required this.itemKey,
    required this.itemName,
    required this.origin,
    required this.documentNumber,
    required this.quantity,
    this.unitPrice,
    this.lineValue,
    this.counterpartyName,
    this.isCancelled = false,
    this.isExcluded = false,
  });

  /// مفتاح النوع — **الاسم المركّب** (`ADR-0007`).
  final String itemKey;

  /// اسم النوع كما يُعرَض.
  final String itemName;

  /// المستند الذي كوَّنها.
  final SackRevenueSource origin;

  /// رقم ذلك المستند — `DST-…` · `CSH-…` · `WDR-…` · `EXP-…`.
  final String documentNumber;

  /// الكمية بوحدتها — ⛔ **للعرض لا للجمع** (`GR-19`).
  final StockQuantity quantity;

  /// 🔵 سعر الوحدة المسجَّل أو `null` — **للعرض** (`FR-M14-15`).
  final Money? unitPrice;

  /// ★ **قيمة السطر كما سُجِّلت في مستندها** — ⛔ **و`null` تعني «غير مسعَّر»**.
  ///
  /// ⚠️ **والغياب ليس صفراً** (`FR-M22-07` · `ADR-0008` القاعدة 5) —
  /// ⟵ **وصفرٌ كان يدخل المجموع فيُظهره نهائياً وهو ناقص.**
  final Money? lineValue;

  /// الجهة المقابلة — **المقوت أو سبب الخرجية** (`FR-M14-15`).
  final String? counterpartyName;

  /// ★ **الملغاة لا تدخل أي جمع** — ⛔ **وهي بديل الحركة العكسية** (`A-14`).
  final bool isCancelled;

  /// ⛔★★ **مستبعَدةٌ بطبيعتها:** **إتلاف** · **وزنٌ ضائع** · **تسوية جرد**.
  ///
  /// ★ **حقلٌ صريح لا شرطٌ في دالة الجمع** — راجع القاعدة ③ في ترويسة الملف.
  final bool isExcluded;

  /// ★ هل تدخل الاحتساب أصلاً؟ — ⛔ **قبل السؤال عن تسعيرها**.
  bool get isCountable => !isCancelled && !isExcluded;

  /// ★ هل هي داخلةٌ ومسعَّرة؟
  bool get isPriced => isCountable && lineValue != null;
}

// ═════════════════════════════════════════════════════════════════════════
// المعادلة — `design-overview.md` §2.2 · `BR-M14-01`
// ═════════════════════════════════════════════════════════════════════════

/// ★★ نتيجة احتساب سعر الجونية — **الرقم وحالةُ نهائيته معاً**.
///
/// ⚠️⚠️ **ولماذا نوعٌ لا [Money] عارياً:** `FR-M14-06` يجعل الجونية ذات
/// الحركات غير المسعَّرة **«⏳ سعر غير نهائي»** — ⟵ **ورقمٌ مجرَّد كان
/// يُقرأ نهائياً في كل شاشة وتقرير**، ⛔ **وهو أخطر من غيابه.**
final class SackRevenue {
  /// ينشئ النتيجة.
  const SackRevenue({
    required this.total,
    required this.unpricedCount,
    required this.countedCount,
  });

  /// ★ **جونيةٌ لم يخرج منها شيء بعد** — ⛔ **صفرٌ نهائيٌّ لا «غير نهائي»**.
  static const SackRevenue none =
      SackRevenue(total: Money.zero, unpricedCount: 0, countedCount: 0);

  /// سعر الجونية — `Σ(قيم السطور المسعَّرة الداخلة)`.
  final Money total;

  /// عدد السطور الداخلة بلا قيمة مسجَّلة (`E-27`).
  final int unpricedCount;

  /// عدد السطور الداخلة كلِّها — مسعَّرةً كانت أو لا.
  final int countedCount;

  /// ★★ **هل السعر نهائي؟** — مصدر وسم «⏳ سعر غير نهائي» (`FR-M14-06`).
  bool get isFinal => unpricedCount == 0;
}

/// ★★★ **سعر الجونية = الإيراد الفعلي المتحقق** — `BR-M14-01` · `FR-M14-02`.
///
/// ```text
/// سعر الجونية = Σ(قيمة كل توزيع فعلي) + Σ(بيع نقدي) + Σ(سحبية أو خرجية)
///               [للمسعَّرة غير الملغاة فقط]
///               [ولا يدخل: الإتلاف · الوزن الضائع · تسوية الجرد
///                · ولا الكمية التي لم تُصرَف بعد]
/// ```
///
/// ★ **وجمعُ أعدادٍ صحيحة** — ⛔ **بلا تقريب**: القيم وصلت مقرَّبةً من
/// الموضع ③ (`ADR-0019` القاعدة 2 · `design-overview.md` §2.11).
///
/// ⚠️ **والدالة خالصةٌ وقابلةٌ للتكرار بلا أثر** — ★ **تبني من المساهمات
/// بالكامل** ⛔ **ولا تُراكِم على قيمة سابقة** (`coding-standards.md` §2.7 ·
/// `PAT-08`): ⟵ **فتشغيلُها مرتين يُنتج الرقم نفسَه.**
SackRevenue computeSackRevenue(
  Iterable<SackRevenueContribution> contributions,
) {
  Money total = Money.zero;
  int unpriced = 0;
  int counted = 0;

  for (final SackRevenueContribution contribution in contributions) {
    // ① و③ ⛔ **الملغاة والمستبعَدة لا تدخل عدّاً ولا جمعاً** — `A-14` · `A-15`.
    if (!contribution.isCountable) continue;
    counted++;
    final Money? value = contribution.lineValue;
    if (value == null) {
      // ⑨ ★ **حركةٌ غير مسعَّرة تُبقي السعر «غير نهائي»** — `FR-M14-06`.
      unpriced++;
      continue;
    }
    total = total + value;
  }

  return SackRevenue(
    total: total,
    unpricedCount: unpriced,
    countedCount: counted,
  );
}

/// ★★★ **صافي الرعوي عن الجونية = سعرها − ضريبتها** — `FR-M14-04` · `A-11`.
///
/// ★ **طرحُ عددين صحيحين** — ⛔ **ولا تقريب ثانٍ**: الضريبة مقرَّبةٌ أصلاً
/// في الموضع ① (`design-overview.md` §2.11).
///
/// ⚠️ **والسالب حالةٌ واقعية لا خطأ** — ★ **جونيةٌ ضريبتُها أكبر مما تحقق
/// منها بعدُ**: ⟵ **فالرقم حيٌّ يرتفع مع كل صرف** (`FR-M14-05`)،
/// ⛔ **وطيُّه في صفرٍ كان يُخفي أن الجونية لم تُصرَف بعد.**
Money computeSupplierNet({required Money sackRevenue, required Money sackTax}) =>
    sackRevenue - sackTax;

/// ★ **متوسط سعر الكيلو المتحقق** — **الموضع ② للتقريب** (`FR-M14-15`).
///
/// ```text
/// متوسط سعر الكيلو = round(سعر الجونية ÷ الوزن المطالب به)
/// ```
///
/// ⛔⛔★★ **للعرض وحده ولا يُخزَّن ولا يدخل أي معادلة أخرى** —
/// `design-overview.md` §2.11 نصّاً · `ADR-0015`.
///
/// ★ **و`null` لوزنٍ مطالبٍ به غير موجب** — ⟵ **القسمة على صفرٍ ليست رقماً**،
/// ⛔ **وصفرٌ مكتوبٌ هنا كان يُقرأ «متوسطاً» وهو غياب قاسم.**
Money? computeAverageKiloPrice({
  required Money sackRevenue,
  required WeightKg claimableWeight,
}) {
  if (claimableWeight.kilograms <= 0) return null;
  // ⛔ **والسالب لا يمرّ بالتقريب** — `ADR-0015` القاعدة 8 · [Money.rounded].
  if (sackRevenue.isNegative) return null;
  return Money.rounded(sackRevenue.riyals / claimableWeight.kilograms);
}

// ═════════════════════════════════════════════════════════════════════════
// حساب الرعوي في مصدر — `design-overview.md` §2.5 · `FR-M14-12`
// ═════════════════════════════════════════════════════════════════════════

/// ★ سطرُ جونيةٍ في حساب الرعوي — **كما يُقرأ من دفتر الرعية**.
///
/// ⛔ **و[sackTax] قد تكون `null`** — ★ **ضريبةٌ لم تُدخَل بعد** (`FR-M7-10`)،
/// ⟵ **وطيُّها في صفرٍ يجعل الصافي يبدو مستقراً وهو لم يُحتسب.**
final class SupplierSackRow {
  /// ينشئ السطر.
  const SupplierSackRow({
    required this.sackId,
    required this.sackRevenue,
    this.sackTax,
    this.isRevenueFinal = true,
  });

  /// رقم الجونية.
  final String sackId;

  /// سعرها المحتسَب.
  final Money sackRevenue;

  /// 🔵 ضريبتها أو `null` **إن كانت معلّقة**.
  final Money? sackTax;

  /// ★ هل سعرها نهائي؟ (`FR-M14-06`).
  final bool isRevenueFinal;
}

/// ★★ إجماليات الرعوي في مصدرٍ واحد — `design-overview.md` §2.5.
final class SupplierSourceTotals {
  /// ينشئ الإجماليات.
  const SupplierSourceTotals({
    required this.totalRevenue,
    required this.totalTax,
    required this.sackCount,
    required this.pendingTaxCount,
    required this.unfinalRevenueCount,
  });

  /// إجمالي سعر الجواني في المصدر.
  final Money totalRevenue;

  /// إجمالي الضريبة في المصدر — ⛔ **للمُدخَلة وحدها**.
  final Money totalTax;

  /// عدد الجواني.
  final int sackCount;

  /// عدد الجواني بضريبةٍ معلّقة (`FR-M7-10`).
  final int pendingTaxCount;

  /// عدد الجواني بسعرٍ غير نهائي (`FR-M14-06`).
  final int unfinalRevenueCount;

  /// ★★★ **صافي الرعوي في المصدر = إجمالي السعر − إجمالي الضريبة**.
  Money get net => totalRevenue - totalTax;

  /// ★ هل الحساب نهائيٌّ بكل بنوده؟ — ⛔ **ضريبةٌ معلّقة تُبقيه غير نهائي**.
  bool get isFinal => pendingTaxCount == 0 && unfinalRevenueCount == 0;
}

/// ★★★ **إجماليات الرعوي في مصدر** — `FR-M14-12` · `design-overview.md` §2.5.
///
/// ```text
/// إجمالي سعر الجواني في المصدر = Σ(سعر كل جونية له في هذا المصدر)
/// إجمالي الضريبة في المصدر     = Σ(ضريبة كل جونية له فيه)
/// صافي الرعوي في المصدر        = الأول − الثاني
/// ```
///
/// ⛔⛔★★★ **ولا تُجمع حسابات الرعوي بين المصادر في أي عملية** (`FR-M14-04` ·
/// `GR-21` · `ADR-0005`) — ★ **والدالة تأخذ سطورَ مصدرٍ واحد**:
/// ⟵ **والجمعُ عبر المصادر عرضٌ يبنيه المُستدعي** ⛔ **ولا حسابٌ موحّد.**
SupplierSourceTotals computeSupplierSourceTotals(
  Iterable<SupplierSackRow> rows,
) {
  Money revenue = Money.zero;
  Money tax = Money.zero;
  int count = 0;
  int pendingTax = 0;
  int unfinalRevenue = 0;

  for (final SupplierSackRow row in rows) {
    count++;
    revenue = revenue + row.sackRevenue;
    final Money? rowTax = row.sackTax;
    if (rowTax == null) {
      // ⛔ **ولا تُجمَع صفراً** — ★ **الغياب غيابٌ**، ⟵ **والعدّاد يقول ذلك.**
      pendingTax++;
    } else {
      tax = tax + rowTax;
    }
    if (!row.isRevenueFinal) unfinalRevenue++;
  }

  return SupplierSourceTotals(
    totalRevenue: revenue,
    totalTax: tax,
    sackCount: count,
    pendingTaxCount: pendingTax,
    unfinalRevenueCount: unfinalRevenue,
  );
}

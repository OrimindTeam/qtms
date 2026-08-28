/// التوزيع والضمار (`M10`) — ★ **أكثر العمليات تكراراً في اليوم**.
///
/// ★ **المصدر:** `FR-M10-01` … `FR-M10-21` · `distribution-design.md` ·
/// `design-overview.md` §2.3 و§2.4 · `data-dictionary.md` §`distributions` ·
/// `schema/distributions.md` · `schema/dealer-ledger.md` ·
/// `ADR-0005` (المصدر مفتاح تقسيم) · `ADR-0011` (عزل الأسعار) ·
/// ★ `ADR-0019` (**موضع التقريب الثالث**).
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔★★ **خمس قواعد بنيوية يفرضها هذا الملف بنوعه لا بشرطٍ يُنسى:**
///
///   ① ★★ **الضمار ليس كياناً مستقلاً — هو مستند التوزيعة نفسه** مضافاً
///      إليه حقول التسوية (`distribution-design.md` §2)، ⟵ **ولا مجموعة
///      ثانية ولا معرّف ثانٍ.**
///   ② ★★ **المعرّف المركّب `{dealerId}_{sourceId}_{stockDate}` يفرض
///      `GR-18` بنيوياً** — ⛔ **لا بفحصٍ تطبيقي قد يُنسى** ([distributionId]).
///   ③ ⛔ **لا تُجمع حبّةٌ مع كيلوجرام** (`GR-19` · `FR-M10-15`) — ★ **إجماليان
///      منفصلان دائماً** ([ValidatedDistribution.totalPieces] و[ValidatedDistribution.totalWeight]).
///   ④ ★★★ **الخصم المخزني فوري في كل الأحوال، والمديونية بقيمة السطور
///      المسعَّرة وحدها** (`FR-M10-05` · `BR-M10-04`) — ⟵ **والخلط بينهما
///      يُنتج ذمةً وهمية أو مخزوناً وهمياً** (`distribution-design.md` §7).
///   ⑤ ★★ **إخفاء عمود السعر لا يعني توزيعةً بلا سعر** (`ت-12` · `FR-M10-07`)
///      — ⟵ **فالقيمة تُحتسب كاملةً هنا**، ⛔ **والإخفاء شأن الشاشة والقاعدة
///      لا شأن هذه المعادلة.**
/// ═══════════════════════════════════════════════════════════════════════
///
/// ⚠️⚠️ **وقيمة السطر الوزني تمرّ بالتقريب — والموضع الثالث المعتمد**
/// ([distributionLineTotal]): `ADR-0019` (قرار المالك في `IQ-026` — الخيار أ).
/// ⛔ **ولم يُعدَّل `ADR-0015`** — **الإحصاء وحده توسَّع من موضعين إلى ثلاثة**.
library;

import '../../../core/calendar_day.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/money.dart';
import '../../../core/outcome.dart';
import '../../../core/quantity.dart';
import '../../inventory/domain/inventory.dart';
import '../../master_data/domain/master_data.dart'
    show ItemUnit, freeTextMaxLength;

// ═════════════════════════════════════════════════════════════════════════
// أسماء المجموعات — `data-dictionary.md` · `naming-conventions.md` §4
// (`snake_case` جمعاً). ★ **مصدر حقيقة واحد يشاركه التطبيق والسحابة.**
// ═════════════════════════════════════════════════════════════════════════

/// مستندات التوزيع — ★ **وهي الضمارات نفسها** (القاعدة ① في ترويسة الملف).
const String distributionsCollection = 'distributions';

/// 🔒 المجموعة الفرعية للأسعار — `distributions/{key}/pricing/current`.
///
/// ⛔★★ **ووجودها ليس ترتيباً جمالياً:** `ADR-0011` — **القاعدة تمنح المستند
/// كاملاً ولا تُخفي حقلاً داخله**، ⟵ **فبقاء السعر في الأب يجعل `ت-12`
/// إخفاءَ واجهة لا حماية.**
const String distributionPricingSubcollection = 'pricing';

/// معرّف مستند الأسعار الوحيد داخل [distributionPricingSubcollection].
const String distributionPricingDocumentId = 'current';

/// دفتر حسابات المقاوته — ★ **مصدر الحقيقة الوحيد لكل رصيد مقوت** (`GR-02`).
const String dealerLedgerCollection = 'dealer_ledger';

// ⛅ **ورصيد المقوت `dealer_balances` مُعرَّفٌ في `master_data.dart`** —
//    ★ **ولا نسخة ثانية منه هنا** (`coding-standards.md` §2.2): ⟵ **ثابتٌ
//    مكرَّر يفترق عند أول إعادة تسمية**، ⛔ **والافتراق في اسم مجموعةٍ يكتب
//    الرصيد في مكانٍ لا يقرؤه أحد.**
//    ⚠️ **ولا يُقرأ كمصدر حقيقة في أي معاملة** — `ADR-0008`: **الرصيد
//    يُجمَع من الدفتر داخلها** ([computeDealerBalance]).

// ═════════════════════════════════════════════════════════════════════════
// المفاتيح المركّبة — `naming-conventions.md` §4 (**ترتيبها ملزم**)
// ═════════════════════════════════════════════════════════════════════════

/// ★★★ معرّف التوزيعة — `{dealerId}_{sourceId}_{stockDate}`.
///
/// ⛔★★★ **وهذا المعرّف هو `GR-18` نفسه** (`FR-M10-01` · `BR-M10-01`):
/// «**لا يمكن إنشاء أكثر من توزيعة واحدة لكل (مقوت × مصدر × تاريخ مخزون)**».
/// ⟵ ★ **فمحاولة إنشاء ثانٍ تفشل على المستند نفسه** ⛔ **لا على فحصٍ تطبيقي
/// قد يُنسى أو يسبقه تزامن** — **ويُفتَح الموجود للتعديل** (`E-04`).
///
/// ⚠️⚠️ **والمفتاح `stockDate` لا `entryDate`** — نصّ `FR-M10-01`:
/// «**والمفتاح تاريخ المخزون لا تاريخ الإدخال**». ⟵ **وتصريفُ متبقّي أمس
/// اليوم يقع في ضمار أمس** (`E-23`)، ⛔ **ولو كان المفتاح تاريخ الإدخال
/// لَأنشأ ضماراً ثانياً لليوم نفسه بصمت.**
String distributionId({
  required String dealerId,
  required String sourceId,
  required CalendarDay stockDate,
}) {
  if (dealerId.isEmpty) {
    throw ArgumentError.value(dealerId, 'dealerId', 'المقوت إلزامي');
  }
  if (sourceId.isEmpty) {
    throw ArgumentError.value(sourceId, 'sourceId', 'المصدر إلزامي');
  }
  return '${dealerId}_${sourceId}_${stockDate.format()}';
}

/// معرّف سجل رصيد المقوت — `{dealerId}_{sourceId}`.
///
/// ⚠️ **ولا رصيد جامعٌ بين المصادر في أي عملية مالية** (`FR-M10-04` ·
/// `BR-M10-05` · `GR-20`) — ★ **والجمع للعرض وحده** (`schema/dealer-ledger.md`
/// القاعدة 1).
String dealerBalanceId({
  required String dealerId,
  required String sourceId,
}) {
  if (dealerId.isEmpty) {
    throw ArgumentError.value(dealerId, 'dealerId', 'المقوت إلزامي');
  }
  if (sourceId.isEmpty) {
    throw ArgumentError.value(sourceId, 'sourceId', 'المصدر إلزامي');
  }
  return '${dealerId}_$sourceId';
}

/// ★ معرّف الحركة المدينة التي يُنشئها التوزيع — `{documentNumber}_debt`.
///
/// ★★ **ولماذا معرّفٌ مشتقٌّ لا عشوائي** — نفس علّة [stockMovementId]:
/// **التعديل يقع على الحركة نفسها** (`FR-M10-16` · `A-14`) ⛔ **ولا يُنشئ
/// حركة تصحيحية**، ⟵ **فلا بدّ من مسارٍ يُصيبها مباشرةً بلا استعلام**.
/// ★ **وهو كذلك ما يجعل إعادة الإرسال تكتب فوق الحركة نفسها** ⛔ **لا حركةً
/// ثانيةً بنفس المبلغ** — وهو في دفتر ذمم **مضاعفةُ دَينٍ صامتة**.
String debtLedgerEntryId({required String documentNumber}) {
  if (documentNumber.isEmpty) {
    throw ArgumentError.value(documentNumber, 'documentNumber', 'الرقم إلزامي');
  }
  return '${documentNumber}_debt';
}

// ═════════════════════════════════════════════════════════════════════════
// حالات المستند والتسوية — `FR-M10` §3 · `design-overview.md` §2.3
// ═════════════════════════════════════════════════════════════════════════

/// حالة مستند التوزيع — `data-dictionary.md` §`distributions` (`status`).
///
/// ⚠️ **والتعديل لا يغيّر الحالة** (`FR-M10` §3) — ★ **يُعدِّل القيم في مكانها
/// ويُعيد احتساب الأرصدة**، ⛔ **بلا حركة عكسية.**
enum DistributionStatus {
  /// معتمد — ★ **ولا سطر مسعَّر بعد** (`E-05` · `FR-M10-08`).
  approved,

  /// ★ مسعَّر جزئياً — **سطور مسعَّرة وأخرى لا** (`E-05` · `AT-23`).
  ///
  /// ⚠️ **والمديونية بالمسعَّر وحده** — `FR-M10-05`، ★ **والباقي يدخل مركز
  /// الإدخالات المعلّقة** (`FR-M10-08`).
  partiallyPriced,

  /// مسعَّر — **كل السطور تحمل سعراً**.
  priced,

  /// ★ ملغى — **بالوسم لا بحركة عكسية** (`FR-M10-18` · `GR-06`).
  cancelled,
}

/// حالة تسوية الضمار — `design-overview.md` §2.3.
enum SettlementStatus {
  /// مفتوح — **لم يُسدَّد منه شيء**.
  open,

  /// مفتوح جزئياً — `0 < المتبقي < القيمة`.
  partiallyOpen,

  /// مغلق — **المتبقي صفر**.
  closed,
}

/// اتجاه الحركة في دفتر المقاوته — `schema/dealer-ledger.md`.
enum DealerLedgerDirection {
  /// مدين — **عليه للمحل**.
  debit,

  /// دائن — **له عند المحل**.
  credit,
}

/// نوع القيد في دفتر المقاوته — `data-dictionary.md` §`dealer_ledger`.
///
/// ⚠️ **ولا تُضاف قيمة هنا بلا مستندٍ يكتبها فعلاً** — ★ **والقائمة تُستكمَل
/// في زيادة كل مستند** (نفس قاعدة [SourceDocumentType])، ⛔ **ولا تُملأ
/// استباقاً بقيمٍ لا كاتب لها.**
enum DealerLedgerEntryType {
  /// ★ ضمار — **يكتبه التوزيع** (`M10` · `WU-006`).
  debt,
}

// ═════════════════════════════════════════════════════════════════════════
// ★★★ المعادلة — `design-overview.md` §2.3 · `ADR-0019`
// ═════════════════════════════════════════════════════════════════════════

/// ★★★ **قيمة السطر** — `الكمية × سعر الوحدة (المُجمَّد)`.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ★★ **وهذه هي الدالة الوحيدة في النظام التي تحمل الموضع الثالث للتقريب**
/// ([`ADR-0019`] — قرار المالك في `IQ-026`، الخيار أ · 2026-08-27):
///
/// | نوع السطر | المعادلة | التقريب |
/// |---|---|---|
/// | **معدود (حبّة)** | `صحيح × صحيح` | ⛔ **لا تقريب إطلاقاً** |
/// | ★ **وزني (كجم)** | `الكمية بثلاث خانات × سعر صحيح` | ★ **لأقرب ريال** |
/// ═══════════════════════════════════════════════════════════════════════
///
/// ⛔⛔★★ **والحالة تُقرَّر من وحدة الكمية لا من كون الناتج كسرياً** —
/// ⟵ **فلا فرعٌ ضمنيٌّ في الكود يعتمد على شكل الرقم**، ★ **و`1.000 كجم ×
/// 500` يمرّ بنفس المسار الذي يمرّ به `1.234 كجم × 1,501`** ⛔ **ولا يتبدّل
/// السلوك بتبدّل المُدخَل.**
///
/// ★ **والسعر الغائب يعني «غير مسعَّر»** ⛔ **لا صفراً** (`FR-M10-08`) —
/// ⟵ **فيُرجَع `null`**، **والسطر يدخل المركز المعلّق ولا يدخل المديونية**
/// (`FR-M10-05`).
///
/// ⚠️ **ولا ينتج سالباً إطلاقاً:** الكمية موجبة بالتحقق (`FR-M10-11`)
/// والسعر موجب — ★ **فحارس السالب في [Money.rounded] يبقى كما هو**
/// (`ADR-0015` القاعدة 8).
Money? distributionLineTotal({
  required StockQuantity quantity,
  required Money? unitPrice,
}) {
  if (unitPrice == null) return null;
  return switch (quantity) {
    // ⛔ **لا تقريب** — `صحيح × صحيح = صحيح` (`ADR-0019` القاعدة 3).
    PieceQuantity(:final PieceCount count) => unitPrice * count.pieces,
    // ★ **الموضع ③** — `ADR-0019` القاعدتان 1 و5 (`ADR-0015` القاعدة 5 نفسها).
    WeightQuantity(:final WeightKg weight) =>
      Money.rounded(weight.kilograms * unitPrice.riyals),
  };
}

/// ★★ **قيمة الضمار** — `Σ(قيم السطور المسعَّرة فقط)` (`design-overview.md` §2.3).
///
/// ⛔⛔★★ **والسطور غير المسعَّرة لا تدخل بصفر — بل لا تدخل** (`FR-M10-05` ·
/// `BR-M10-04`): ⟵ **والفرق ليس شكلياً**: **سطرٌ بصفر يقول «قيمته صفر»**،
/// ★ **وسطرٌ غائبٌ عن الجمع يقول «قيمته لم تُحدَّد بعد»** — ⛔ **والأول
/// يُغلق المديونية على رقمٍ ناقص، والثاني يُبقي المستند «مسعَّراً جزئياً»
/// حتى يكتمل** (`E-05` · `AT-23`).
///
/// ★ **ولا تقريب هنا** — `ADR-0019` القاعدة 2: **مجموعُ قيمٍ مقرَّبةٍ أصلاً**
/// ⛔ **فلا تقريب ثانٍ** (نفس منطق `ADR-0015` القاعدة 6 في ضريبة الجونية).
Money computeDebtValue(Iterable<Money?> lineTotals) {
  Money total = Money.zero;
  for (final Money? lineTotal in lineTotals) {
    if (lineTotal == null) continue;
    total = total + lineTotal;
  }
  return total;
}

/// تسوية الضمار — **القيمة والمسدَّد والمخصوم والمتبقي وحالته**.
final class DebtSettlement {
  /// ينشئ التسوية.
  const DebtSettlement({
    required this.debtValue,
    required this.settledAmount,
    required this.discountedAmount,
    required this.remaining,
    required this.status,
  });

  /// قيمة الضمار.
  final Money debtValue;

  /// ★ المسدَّد — ⛅ **تكتبه السحابة بعد كل قبض** (`distribution-design.md` §2).
  final Money settledAmount;

  /// ★ المخصوم — ⛅ **تكتبه السحابة بعد كل خصم**.
  final Money discountedAmount;

  /// المتبقي — `القيمة − المسدَّد − المخصوم`.
  final Money remaining;

  /// حالة التسوية.
  final SettlementStatus status;

  /// ★★ **هل مُسّ هذا الضمار بسدادٍ أو خصم؟** — `FR-M10-18` · `E-15`.
  ///
  /// ⛔⛔★★ **وهذا هو حارس الإلغاء ⛔ لا [status]:** نصّ `E-15` «**سُدِّد
  /// ضمارها كلياً أو جزئياً**» ⟵ **يسأل عمّا وصل فعلاً**، ★ **بينما
  /// [status] يسأل عن المتبقي** — ⛔ **وضمارٌ قيمتُه صفر (كل سطوره غير
  /// مسعَّرة) متبقّيه صفر فيبدو «مغلقاً» وهو لم يُمَسّ**، ⟵ **فحارسٌ
  /// مبنيٌّ على الحالة كان سيمنع إلغاء توزيعةٍ لم يدفع عنها أحد ريالاً.**
  bool get isTouchedBySettlement =>
      !settledAmount.isZero || !discountedAmount.isZero;
}

/// ★★ يحسب تسوية الضمار — `design-overview.md` §2.3.
///
/// ```text
/// المتبقي على الضمار = قيمة الضمار − المسدَّد − المخصوم
///
///    المتبقي = قيمة الضمار      → مفتوح
///    0 < المتبقي < القيمة       → مفتوح جزئياً
///    المتبقي = 0                → مغلق
/// ```
///
/// ⚠️⚠️ **وحالة القيمة صفر محسومة هنا صراحةً: «مغلق»** — ★ **والحالتان
/// الأولى والثالثة تصدُقان معاً عليها** (المتبقي = القيمة = 0)، ⟵ **فرُجِّحت
/// الثالثة**: **`dealer_balances` يعدّ «الضمارات المفتوحة» لأعمار الديون**
/// (`data-dictionary.md` §4)، ⛔ **وضمارٌ لا يُطالَب بريال واحد ليس ديناً
/// مفتوحاً** — ★ **وعدُّه مفتوحاً يُضخِّم أقدمَ دَينٍ برقمٍ لا يقابله مبلغ.**
/// ★ **وأثرُ الترجيح محصور في وسمٍ يُعاد احتسابه عند أول تسعير**
/// ⛔ **ولا يُغيّر ريالاً واحداً في أي دفتر** — **قرار تنفيذي روتيني موثَّق**
/// (بروتوكول التشغيل §ب الفئة 3)، ⛔ **وليس حارسَ الإلغاء** (راجع
/// [DebtSettlement.isTouchedBySettlement]).
DebtSettlement computeDebtSettlement({
  required Money debtValue,
  required Money settledAmount,
  required Money discountedAmount,
}) {
  final Money remaining = debtValue - settledAmount - discountedAmount;
  final SettlementStatus status;
  if (remaining.isZero || remaining.isNegative) {
    status = SettlementStatus.closed;
  } else if (remaining >= debtValue) {
    status = SettlementStatus.open;
  } else {
    status = SettlementStatus.partiallyOpen;
  }
  return DebtSettlement(
    debtValue: debtValue,
    settledAmount: settledAmount,
    discountedAmount: discountedAmount,
    remaining: remaining,
    status: status,
  );
}

// ═════════════════════════════════════════════════════════════════════════
// رصيد المقوت — `design-overview.md` §2.4 · `schema/dealer-ledger.md`
// ═════════════════════════════════════════════════════════════════════════

/// قيد دفتري في حساب المقوت — **بما يلزم لجمع الرصيد وحده**.
///
/// ⛔ **ولا يحمل الحقول المرجعية كاملة عمداً** — نفس علّة [StockMovement]:
/// ★ **الجمع لا يحتاجها**، ⟵ **وحملُها هنا يُغري بأن يُبنى عليها قرارٌ في
/// دالة الجمع.**
final class DealerLedgerEntry {
  /// ينشئ القيد.
  const DealerLedgerEntry({
    required this.direction,
    required this.amount,
    required this.isCancelled,
  });

  /// مدين أم دائن.
  final DealerLedgerDirection direction;

  /// المبلغ — ★ **عدد صحيح بالريال** (`ADR-0015`).
  final Money amount;

  /// ★ **الملغاة لا تدخل أي جمع** — `schema/dealer-ledger.md` القاعدة 5.
  final bool isCancelled;
}

/// رصيد المقوت في مصدر — **المدين والدائن والرصيد معاً**.
final class DealerAccountBalance {
  /// ينشئ الرصيد.
  const DealerAccountBalance({
    required this.totalDebit,
    required this.totalCredit,
    required this.balance,
  });

  /// إجمالي المدين — `Σ(قيم الضمارات)`.
  final Money totalDebit;

  /// إجمالي الدائن — `Σ(المقبوضات) + Σ(الخصومات) + Σ(الفائض المُطبَّق)`.
  final Money totalCredit;

  /// الرصيد — `المدين − الدائن`.
  ///
  /// ```text
  /// > 0 ⟸ عليه للمحل   ·   = 0 ⟸ مسدَّد   ·   < 0 ⟸ له فائض
  /// ```
  final Money balance;

  /// ★ **له فائض عند المحل** — `design-overview.md` §2.4.
  bool get hasSurplus => balance.isNegative;
}

/// ★★ **رصيد المقوت في مصدرٍ واحد** — `design-overview.md` §2.4.
///
/// ⛔⛔★★ **ولا تُجمع أرصدة المقوت بين المصادر في أي عملية مالية**
/// (`FR-M10-04` · `GR-20` · `schema/dealer-ledger.md` القاعدة 1) —
/// ★ **والجمع للعرض وحده.** ⟵ **ولذلك تستقبل هذه الدالة قيود مصدرٍ واحد**
/// ⛔ **ولا تعرف المصدر أصلاً**: **الفلترة مسؤولية المُستدعي**، ★ **وهي في
/// المعاملة قراءةٌ مقيَّدة بـ`sourceId`** لا فلترةٌ بعد الجمع.
///
/// ⚠️ **والرصيد يُجمَع من الدفتر ⛔ لا يُقرأ من `dealer_balances`** —
/// `ADR-0008`: **الملخص مشتقٌّ يُكتب بعد الجمع** ⛔ **ولا يُقرأ ليُبنى عليه**.
DealerAccountBalance computeDealerBalance(
  Iterable<DealerLedgerEntry> entries,
) {
  Money debit = Money.zero;
  Money credit = Money.zero;
  for (final DealerLedgerEntry entry in entries) {
    // ⛔ **الملغاة لا تدخل أي جمع** — `A-14`.
    if (entry.isCancelled) continue;
    switch (entry.direction) {
      case DealerLedgerDirection.debit:
        debit = debit + entry.amount;
      case DealerLedgerDirection.credit:
        credit = credit + entry.amount;
    }
  }
  return DealerAccountBalance(
    totalDebit: debit,
    totalCredit: credit,
    balance: debit - credit,
  );
}

// ═════════════════════════════════════════════════════════════════════════
// السطور والمستند
// ═════════════════════════════════════════════════════════════════════════

/// سطر توزيع كما يصل من الواجهة — **قبل أي تحقق**.
final class DistributionLineInput {
  /// ينشئ المدخلات.
  const DistributionLineInput({
    required this.itemId,
    required this.itemName,
    required this.unit,
    required this.quantity,
    this.sackId,
    this.unitPrice,
    this.note,
  });

  /// معرّف النوع — ★ **وهو `itemKey` في الدفتر** (نفس قاعدة `FR-M6-09`).
  final String itemId;

  /// اسم النوع المعروض — ★ **نسخةٌ مقصودة** (`naming-conventions.md` §4).
  final String itemName;

  /// وحدة النوع — ★ **مقروءةٌ من سجل النوع** ⛔ **لا مُدخَلة** (`FR-M5-03`).
  final ItemUnit unit;

  /// ★ الكمية **بوحدتها في النوع** — `GR-19`.
  ///
  /// ⚠️ **وتُقابَل بـ[unit] في التحقق** — ⟵ **فكميةٌ بوحدةٍ غير وحدة النوع
  /// تُرفَض صراحةً** ⛔ **ولا تُحوَّل صامتاً** (`E-31`).
  final StockQuantity quantity;

  /// ★ **الجونية التي ينتمي إليها النوع** أو `null`.
  ///
  /// ⚠️⚠️ **وهو الحقل الذي يُبنى عليه إعادةُ احتساب سعر الجونية**
  /// (`FR-M10-14` · `A-13` · `schema/inventory-ledger.md`) — ⟵ **فغيابُه
  /// عن سطرٍ من جونية يُسقِط الجونيةَ من الاحتساب بصمت.**
  final String? sackId;

  /// ★ سعر الوحدة **المُجمَّد** أو `null` — `FR-M10-09` · `FR-M10-08`.
  ///
  /// ⛔★★ **والغياب «غير مسعَّر» لا «صفر»** — راجع [distributionLineTotal].
  final Money? unitPrice;

  /// ملاحظة السطر — اختيارية.
  final String? note;
}

/// سطر توزيع مُتحقَّق منه.
final class ValidatedDistributionLine {
  /// ينشئ السطر.
  const ValidatedDistributionLine({
    required this.itemId,
    required this.itemName,
    required this.quantity,
    required this.sackId,
    required this.unitPrice,
    required this.note,
  });

  /// معرّف النوع.
  final String itemId;

  /// ★ **مفتاح النوع في الدفتر** — **المعرّف لا الاسم**.
  ///
  /// ★★ **ولماذا المعرّف:** الاسم **يتغيّر بالتعديل** (`FR-M5-01`) بينما
  /// مفتاح الرصيد `{sourceId}_{itemKey}_{stockDate}` **يجب أن يثبت**،
  /// ⟵ **فاسمٌ متغيّر مفتاحاً كان يُنشئ رصيداً ثانياً لنفس النوع بصمت.**
  String get itemKey => itemId;

  /// الاسم المعروض لحظة الإدخال.
  final String itemName;

  /// الكمية بوحدتها.
  final StockQuantity quantity;

  /// الجونية أو `null`.
  final String? sackId;

  /// السعر المُجمَّد أو `null`.
  final Money? unitPrice;

  /// الملاحظة أو `null` — ⛔ **والفارغ غيابٌ لا نصٌّ فارغ**.
  final String? note;

  /// هل يحمل سعراً؟ — ★ **وهو ما يُدخِله في المديونية** (`FR-M10-05`).
  bool get isPriced => unitPrice != null;

  /// ★★ قيمة السطر أو `null` — **الدالة الوحيدة** ([distributionLineTotal]).
  Money? get lineTotal =>
      distributionLineTotal(quantity: quantity, unitPrice: unitPrice);
}

/// مدخلات مستند توزيع.
final class DistributionInput {
  /// ينشئ المدخلات.
  const DistributionInput({
    required this.sourceId,
    required this.dealerId,
    required this.lines,
    this.notes,
  });

  /// المصدر — ★ **إلزامي، والمديونية تُقيَّد عليه وحده** (`FR-M10-04`).
  final String sourceId;

  /// المقوت — ★ **إلزامي**.
  final String dealerId;

  /// سطور المستند — ⛔ **ولا فارغة**.
  final List<DistributionLineInput> lines;

  /// ملاحظات المستند.
  final String? notes;
}

/// مستند توزيع مُتحقَّق منه — **جاهز للكتابة كما هو**.
final class ValidatedDistribution {
  /// ينشئ المستند.
  ValidatedDistribution({
    required this.sourceId,
    required this.dealerId,
    required this.notes,
    required List<ValidatedDistributionLine> lines,
  }) : lines = List<ValidatedDistributionLine>.unmodifiable(lines);

  /// المصدر.
  final String sourceId;

  /// المقوت.
  final String dealerId;

  /// ملاحظات المستند أو `null`.
  final String? notes;

  /// السطور **مرتَّبةً بمفتاح النوع** — ★ **فنفس الإدخال يُنتج نفس المستند**
  /// في كل تشغيل (`coding-standards.md` §2.7 · إعادة المحاولة بلا أثر).
  final List<ValidatedDistributionLine> lines;

  /// ★ إجمالي الحبّات — ⛔ **ولا يُجمع مع [totalWeight] أبداً** (`GR-19`).
  PieceCount get totalPieces {
    PieceCount total = PieceCount.zero;
    for (final ValidatedDistributionLine line in lines) {
      if (line.quantity case PieceQuantity(:final PieceCount count)) {
        total = total + count;
      }
    }
    return total;
  }

  /// ★ إجمالي الأوزان — ⛔ **ولا يُجمع مع [totalPieces] أبداً** (`GR-19`).
  WeightKg get totalWeight {
    WeightKg total = WeightKg.zero;
    for (final ValidatedDistributionLine line in lines) {
      if (line.quantity case WeightQuantity(:final WeightKg weight)) {
        total = total + weight;
      }
    }
    return total;
  }

  /// ★★ **قيمة الضمار** — [computeDebtValue] (`design-overview.md` §2.3).
  Money get debtValue => computeDebtValue(
        <Money?>[
          for (final ValidatedDistributionLine line in lines) line.lineTotal,
        ],
      );

  /// ★ عدد السطور غير المسعَّرة — 🧮 **عدد لا مبلغ**.
  ///
  /// ⛔★★ **ولهذا يعيش في المستند الأب** (`ADR-0011` · `firestore.rules` §16):
  /// ★ **يكشف عدداً وحالةً لا مبلغاً**، ⟵ **وهو مصدر وسم «⏳ سعر غير نهائي»
  /// الذي يراه الجميع** ⛔ **بينما `debtValue` يعيش مع الأسعار.**
  int get unpricedLineCount =>
      lines.where((ValidatedDistributionLine line) => !line.isPriced).length;

  /// ★★ حالة التسعير المشتقّة — `FR-M10` §3 · `E-05`.
  ///
  /// ⚠️ **وتُشتقّ من السطور ⛔ لا تُرسَل من الجهاز** — ★ **فحالةٌ مُرسَلة
  /// كانت ستُخالف سطورها بصمت.**
  DistributionStatus get pricingStatus {
    if (unpricedLineCount == 0) return DistributionStatus.priced;
    if (unpricedLineCount == lines.length) return DistributionStatus.approved;
    return DistributionStatus.partiallyPriced;
  }

  /// ★ هل يحمل المستند سعراً واحداً على الأقل؟
  ///
  /// ⚠️⚠️ **وهو ما يُقابَل بصلاحية التسعير** (`FR-M10-07` · `FR-M10-10` ·
  /// `ERR_PRICE_001`): ⟵ **«قواعد الحماية ترفض أي مستند يحمل سعراً من
  /// مُرسِل لا يملك الصلاحية»** — ★ **وبعد `WU-026` صار الحارس على الدالة
  /// الكاتبة** (`ADR-0013` القاعدة 2 · `DEBT-21`).
  bool get carriesAnyPrice => unpricedLineCount < lines.length;
}

/// ★ الحدّ الأدنى لعدد السطور — **مستندٌ بلا سطر لا يُنشئ حركة فلا معنى له**.
const int distributionMinLines = 1;

/// يفحص مستند توزيع — `FR-M10-04` … `FR-M10-19`.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ★★ **ستة قيود تُفحَص هنا:**
///
///   ① **المصدر والمقوت إلزاميان** (`FR-M10-04`) — ⛔ ولا ذمة بلا طرفين.
///   ② **سطرٌ واحد على الأقل**.
///   ③ ⛔ **لا سطران لنفس النوع** (`FR-M10-19` · `BR-M10-15`) — ★ **والواجهة
///      تدمجهما مع تنبيه قبل أن تصل هنا**، ⛔ **وهذا يمنع ما أفلت منها.**
///   ④ ★★ **الكمية موجبة تماماً** (`FR-M10-11` · `BR-M10-10`) — ⛔ **والصفر
///      ليس توزيعاً، والسالب إرجاعٌ لا توزيع.**
///   ⑤ ⛔ **ووحدة الكمية = وحدة النوع** (`GR-19` · `E-31`) — ★ **فلا تُحوَّل
///      حبّةٌ إلى كيلوجرام صامتاً.**
///   ⑥ ★ **السعر — إن وُجد — موجب تماماً** ⛔ **والصفر ليس سعراً**: ⟵ **سعرٌ
///      بصفر يُقيّد ديناً بصفر ويُغلق السطر عن المركز المعلّق**، ★ **بينما
///      غيابُ السعر يُبقيه معلّقاً حتى يُسعَّر** (`FR-M10-08`).
/// ═══════════════════════════════════════════════════════════════════════
Outcome<ValidatedDistribution> validateDistribution(DistributionInput input) {
  final String sourceId = input.sourceId.trim();
  if (sourceId.isEmpty) {
    return const Failure<ValidatedDistribution>(ValidationError('FR-M10-04'));
  }
  final String dealerId = input.dealerId.trim();
  if (dealerId.isEmpty) {
    return const Failure<ValidatedDistribution>(ValidationError('FR-M10-04'));
  }
  if (input.lines.length < distributionMinLines) {
    return const Failure<ValidatedDistribution>(ValidationError('FR-M10-13'));
  }

  final Outcome<List<ValidatedDistributionLine>> lines =
      _validateLines(input.lines);
  if (lines
      case Failure<List<ValidatedDistributionLine>>(:final AppError error)) {
    return Failure<ValidatedDistribution>(error);
  }

  final Outcome<String?> notes = _optionalNote(input.notes);
  if (notes case Failure<String?>(:final AppError error)) {
    return Failure<ValidatedDistribution>(error);
  }

  return Success<ValidatedDistribution>(
    ValidatedDistribution(
      sourceId: sourceId,
      dealerId: dealerId,
      notes: (notes as Success<String?>).value,
      lines: (lines as Success<List<ValidatedDistributionLine>>).value,
    ),
  );
}

Outcome<List<ValidatedDistributionLine>> _validateLines(
  List<DistributionLineInput> raw,
) {
  final Set<String> seen = <String>{};
  final List<ValidatedDistributionLine> validated =
      <ValidatedDistributionLine>[];

  for (final DistributionLineInput line in raw) {
    final String itemId = line.itemId.trim();
    if (itemId.isEmpty) {
      return const Failure<List<ValidatedDistributionLine>>(
        ValidationError('FR-M10-13'),
      );
    }
    // ③ ⛔ **لا سطران لنفس النوع** — `FR-M10-19` · `BR-M10-15`.
    if (!seen.add(itemId)) {
      return const Failure<List<ValidatedDistributionLine>>(
        ValidationError('BR-M10-15'),
      );
    }
    // ⑤ ⛔ **ووحدة الكمية = وحدة النوع** — `GR-19`.
    if (line.quantity.unit != line.unit) {
      return const Failure<List<ValidatedDistributionLine>>(
        ValidationError('GR-19'),
      );
    }
    // ④ ⛔ **موجبٌ تماماً** — `FR-M10-11` · `BR-M10-10`.
    if (!line.quantity.isPositive) {
      return const Failure<List<ValidatedDistributionLine>>(
        ValidationError('BR-M10-10'),
      );
    }

    final String name = line.itemName.trim();
    if (name.isEmpty) {
      return const Failure<List<ValidatedDistributionLine>>(
        ValidationError('FR-M10-13'),
      );
    }

    // ⑥ ★ **السعر موجبٌ تماماً إن وُجد** — راجع ترويسة [validateDistribution].
    final Money? unitPrice = line.unitPrice;
    if (unitPrice != null && unitPrice.riyals <= 0) {
      return const Failure<List<ValidatedDistributionLine>>(
        ValidationError('BR-M10-08'),
      );
    }

    final Outcome<String?> note = _optionalNote(line.note);
    if (note case Failure<String?>(:final AppError error)) {
      return Failure<List<ValidatedDistributionLine>>(error);
    }

    final String? sackId = line.sackId?.trim();

    validated.add(
      ValidatedDistributionLine(
        itemId: itemId,
        itemName: name,
        quantity: line.quantity,
        sackId: sackId == null || sackId.isEmpty ? null : sackId,
        unitPrice: unitPrice,
        note: (note as Success<String?>).value,
      ),
    );
  }

  // ★ **ترتيبٌ ثابت** — راجع [ValidatedDistribution.lines].
  validated.sort(
    (ValidatedDistributionLine a, ValidatedDistributionLine b) =>
        a.itemKey.compareTo(b.itemKey),
  );
  return Success<List<ValidatedDistributionLine>>(validated);
}

Outcome<String?> _optionalNote(String? value) {
  final String? text = value?.trim();
  if (text == null || text.isEmpty) return const Success<String?>(null);
  if (text.length > freeTextMaxLength) {
    return const Failure<String?>(ValidationError('FR-M10-13'));
  }
  return Success<String?>(text);
}

// ═════════════════════════════════════════════════════════════════════════
// التعديل والإلغاء — ★ **على المستند نفسه** ⛔ **بلا حركة عكسية** (`A-14`)
// ═════════════════════════════════════════════════════════════════════════

/// ★ يفحص أن المستند ليس ملغى قبل تعديله — `ERR_AMEND_006`.
///
/// ⛔★★ **والملغى لا يُعدَّل ولا يُلغى ثانيةً:** الإلغاء **نهائي بالوسم**
/// (`FR-M10-18`)، ⟵ **وتعديلُ ملغىً يُعيد كميةً إلى الرصيد ويُقيِّد ديناً
/// من مستندٍ خرج من الحساب** — ★ **وهو فسادُ رصيدٍ وذمةٍ صامت معاً.**
Outcome<void> validateDistributionNotCancelled(DistributionStatus status) =>
    status == DistributionStatus.cancelled
        ? const Failure<void>(ValidationError('ERR_AMEND_006'))
        : const Success<void>(null);

/// ★★★ **يفحص أن الضمار لم يُسدَّد قبل إلغاء توزيعته** — `FR-M10-18` · `E-15`.
///
/// ⛔⛔★★ **ورمزُه `ERR_AMEND_005` وحده** («لا يمكن إلغاء توزيعة سُدِّد
/// ضمارها كلياً أو جزئياً. عالج السداد أولاً») — ★ **ونصّه يقول للمستخدم
/// الفعلَ المطلوب**، ⛔ **لا «ممنوع» بلا مخرج.**
///
/// ⚠️⚠️ **ويُقاس بـ[DebtSettlement.isTouchedBySettlement] ⛔ لا بحالة
/// التسوية** — راجع تعليل ذلك هناك: ★ **ضمارٌ قيمتُه صفر يبدو «مغلقاً» وهو
/// لم يُمَسّ**، ⟵ **وحارسٌ مبنيٌّ على الحالة كان سيحبس توزيعةً خاطئة داخل
/// النظام بلا مخرج.**
Outcome<void> validateDistributionCancellable(DebtSettlement settlement) =>
    settlement.isTouchedBySettlement
        ? const Failure<void>(ValidationError('ERR_AMEND_005'))
        : const Success<void>(null);

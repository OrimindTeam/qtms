/// ═══════════════════════════════════════════════════════════════════════
/// **المقبوضات وحساب المقوت** — `M12` · `FR-M12` · `settlement-design.md`.
///
/// ★★★ **وثلاث قواعد تحكم هذا الملف كلَّه**، وكلُّ ما تحته تفريعٌ عليها:
///
/// ① ⛔⛔ **حركة دائنة لكل سطر لا حركة واحدة مجمّعة** (`FR-M12-07` ·
///   `BR-M12-01` · `schema/dealer-ledger.md` القاعدة 3) — ★ **لأن كل سطر
///   يخصّ ضماراً ومصدراً مختلفاً**، ⟵ **وحركةٌ مجمّعة تُفقد الرصيدَ مصدرَه
///   فيستحيل بناء كشف حساب مفصولٍ بالمصدر** (`GR-20`).
///
/// ② ⛔⛔ **التوزيع التلقائي يُحسَب محلياً ويُعرَض للمراجعة ولا يكتب**
///   (`FR-M12-14` · `BR-M12-07`) — ★ **فهو اقتراحٌ لا قرار**، ⟵ **ودالّتُه
///   هنا نقيّةٌ تُرجِع اقتراحاً** ⛔ **ولا تعرف الكتابة أصلاً.**
///
/// ③ ⛔⛔ **تطبيق الفائض عمليةٌ سحابية لا تطبيقية** (`settlement-design.md`
///   §11) — ★ **لأنها تُطلَق عند إنشاء ضمارٍ جديد لا عند القبض**، ⟵ **فمنطقُه
///   هنا** ([planSurplusApplication]) **وتنفيذُه في العملية السحابية وحدها.**
///
/// ⚠️⚠️ **والفرق بين «الواصل» و«المقبوض في تاريخ» مصونٌ بنيوياً** (`GR-41` ·
/// `FR-M12-20`): ★ **هذا الملف يكتب سنداً بتاريخه** ⛔ **ولا يُسنِد مبلغاً
/// ليوم الضمار**، ⟵ **والرقمان يُبنيان من موضعين مختلفين** (`daily-summaries.md`).
/// ═══════════════════════════════════════════════════════════════════════
library;

import '../../../core/calendar_day.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/money.dart';
import '../../../core/outcome.dart';
import 'distribution.dart';

// ═════════════════════════════════════════════════════════════════════════
// أسماء المجموعات — `data-dictionary.md` · `naming-conventions.md` §4
// ═════════════════════════════════════════════════════════════════════════

/// سندات القبض — `schema/receipts.md`.
const String receiptsCollection = 'receipts';

/// 🔒 المجموعة الفرعية لحالة الإيداع البنكي — `receipts/{id}/deposit/current`.
///
/// ⛔★★ **ووجودها ليس ترتيباً جمالياً** — [`ADR-0017`] بنمط [`ADR-0011`]
/// نفسِه: **القاعدة تمنح المستند كاملاً ولا تُخفي حقلاً داخله**، ⟵ **فبقاء
/// حالة الإيداع في الأب يجعل `FR-M12-16` إخفاءَ واجهة لا حماية** (`RISK-02`).
const String receiptDepositSubcollection = 'deposit';

/// معرّف مستند الإيداع الوحيد داخل [receiptDepositSubcollection].
const String receiptDepositDocumentId = 'current';

/// ★ أرصدة الفائض المتاح لكل مقوت — `settlement-design.md` §4.
const String dealerSurplusCollection = 'dealer_surplus';

// ═════════════════════════════════════════════════════════════════════════
// المفاتيح المركّبة — `naming-conventions.md` §4 (**ترتيبها ملزم**)
// ═════════════════════════════════════════════════════════════════════════

/// ★★ **مفتاح نطاق الفائض العام** — `settlement-design.md` §4.
///
/// ⛔⛔ **ولا يجوز أن يساوي أي `sourceId` حقيقي** — ★ **وسجلات المصادر
/// `SRC-###`** (`document_number.dart` · `EntityKind`) ⟵ **فلا تصادم.**
const String generalSurplusScopeKey = 'general';

/// ★★★ معرّف سجل الفائض — `{dealerId}_{sourceId | 'general'}`.
///
/// ⛔⛔★★ **وهذا المفتاح هو `E-13` نفسه بنيوياً** (`FR-M12-12` · `BR-M12-06` ·
/// `GR-37`): **فائضُ رداع وضمارٌ جديد في ماوية ⟵ لا يُسدَّد منه شيء** —
/// ★ **لأن السجلين مستندان مختلفان أصلاً**، ⛔ **لا لأن فحصاً تطبيقياً منعه**
/// ⟵ **وفحصٌ كهذا يُنسى، والمفتاحُ لا يُنسى.**
String dealerSurplusId({
  required String dealerId,
  required SurplusScope scope,
  String? sourceId,
}) {
  if (dealerId.isEmpty) {
    throw ArgumentError.value(dealerId, 'dealerId', 'المقوت إلزامي');
  }
  switch (scope) {
    case SurplusScope.general:
      return '${dealerId}_$generalSurplusScopeKey';
    case SurplusScope.source:
      if (sourceId == null || sourceId.isEmpty) {
        // ⛔★★ **فائضُ مصدرٍ بلا مصدر تناقضٌ لا قيمةٌ افتراضية** — ⟵ **وسقوطُه
        //    إلى «عام» صامتاً كان سيُسدِّد لضمارات مصادرَ أخرى** (`E-13`).
        throw ArgumentError.value(sourceId, 'sourceId', 'مصدر الفائض إلزامي');
      }
      return '${dealerId}_$sourceId';
  }
}

/// ★ معرّف الحركة الدائنة لسطر قبض — `{documentNumber}_{debtLotId}`.
///
/// ★★ **ومعرّفٌ مشتقٌّ لا عشوائي** — نفس علّة [debtLedgerEntryId] حرفياً:
/// **التعديل يقع على الحركة نفسها** ⛔ **ولا يُنشئ حركة عكسية** (`A-14` ·
/// `FR-M12-21`)، ⟵ **وإعادةُ الإرسال تكتب فوقها** ⛔ **لا حركةً ثانيةً
/// بنفس المبلغ** — وهي في دفتر ذمم **إسقاطُ دَينٍ صامت مرتين.**
String receiptLedgerEntryId({
  required String documentNumber,
  required String debtLotId,
}) {
  if (documentNumber.isEmpty) {
    throw ArgumentError.value(documentNumber, 'documentNumber', 'الرقم إلزامي');
  }
  if (debtLotId.isEmpty) {
    throw ArgumentError.value(debtLotId, 'debtLotId', 'الضمار إلزامي');
  }
  return '${documentNumber}_$debtLotId';
}

/// ★ معرّف حركة تطبيق الفائض — `{debtLotId}_surplus_{surplusId}`.
///
/// ⛔★★ **ومعرّفُه بالضمار لا بالسند** — ★ **لأن كاتبَه إنشاءُ الضمار**
/// (`FR-M12-11`) ⛔ **لا سندُ القبض الذي وُلِد منه الفائض قبل أيام.**
///
/// ⛔⛔★★ **وسجلُّ الفائض جزءٌ من المعرّف** — ★ **لأن ضماراً واحداً قد
/// يُسدَّد من سجلَّين معاً** (**فائضُ مصدره ثم العام** — `FR-M12-12`):
/// ⟵ **ومعرّفٌ بالضمار وحده كان يكتب الحركةَ الثانية فوق الأولى** ⛔ **فيضيع
/// أحدُ التسديدين من الدفتر بينما رصيدُ الفائض نقص بهما معاً.**
String surplusLedgerEntryId({
  required String debtLotId,
  required String surplusId,
}) {
  if (debtLotId.isEmpty) {
    throw ArgumentError.value(debtLotId, 'debtLotId', 'الضمار إلزامي');
  }
  if (surplusId.isEmpty) {
    throw ArgumentError.value(surplusId, 'surplusId', 'سجل الفائض إلزامي');
  }
  return '${debtLotId}_surplus_$surplusId';
}

// ═════════════════════════════════════════════════════════════════════════
// الأنواع — `FR-M12` §2 و§3
// ═════════════════════════════════════════════════════════════════════════

/// نطاق الفائض — `FR-M12-12` · `settlement-design.md` §4.
enum SurplusScope {
  /// ★ **مصدر محدد** — يُسدَّد **لضمارات ذلك المصدر حصراً** (`E-13`).
  source,

  /// ★ **عام** — يُسدَّد **لأي ضمار قادم بأي مصدر بالأقدم أولاً**.
  general,
}

/// حالة الإيداع البنكي — `FR-M12-15` · [`ADR-0017`].
enum DepositState {
  /// ★ **تبدأ «لم يُودع»** دائماً — `schema/receipts.md`.
  notDeposited,

  /// أُودع — **بملاحظة إلزامية** (`FR-M12-15`).
  deposited,
}

/// ★★ **ضمارٌ مفتوح متاحٌ للسداد** — `FR-M12-05`.
///
/// ⚠️⚠️ **و[remaining] يُقرأ من `pricing/current` لا من الأب** (`IQ-027`
/// الخيار أ) — ★ **والقراءة مسؤولية المُستدعي**، ⛔ **وهذا النوع لا يعرف
/// مستنداً أصلاً.**
final class OpenDebtLot {
  /// ينشئ الضمار المفتوح.
  const OpenDebtLot({
    required this.debtLotId,
    required this.sourceId,
    required this.stockDate,
    required this.remaining,
  });

  /// معرّف الضمار — **وهو معرّف التوزيعة المركّب** ([distributionId]).
  final String debtLotId;

  /// ★ المصدر — **إلزامي** (`schema/dealer-ledger.md`).
  final String sourceId;

  /// ★ **يوم الضمار** — ⛔ **لا يوم الإدخال** (`ADR-0006`).
  ///
  /// ⚠️ **وهو مفتاح الترتيب «بالأقدم أولاً»** (`FR-M12-13` · `FR-M12-12`).
  final CalendarDay stockDate;

  /// المتبقي عليه — `القيمة − المسدَّد − المخصوم`.
  final Money remaining;
}

/// سطر قبض كما يصل من الواجهة — **قبل أي تحقق**.
final class ReceiptLineInput {
  /// ينشئ المدخلات.
  const ReceiptLineInput({
    required this.debtLotId,
    required this.amount,
    this.note,
  });

  /// الضمار المستهدَف.
  final String debtLotId;

  /// ★ **المبلغ الواصل** — `FR-M12-06`.
  final Money amount;

  /// بيان السطر — اختياري.
  final String? note;
}

/// سطر قبض مُتحقَّق منه — **بالمتبقي قبله وبعده محسوبَين**.
final class ValidatedReceiptLine {
  /// ينشئ السطر.
  const ValidatedReceiptLine({
    required this.debtLotId,
    required this.sourceId,
    required this.remainingBefore,
    required this.amount,
    required this.remainingAfter,
    required this.note,
  });

  /// الضمار المسدَّد.
  final String debtLotId;

  /// ★ **مصدر ذلك الضمار** — ⛔ **مقروءٌ منه لا مُدخَل** (`E-35`).
  ///
  /// ⚠️⚠️ **وهو ما يجعل الحركة الدائنة تقع في مصدرها الصحيح** (`FR-M12-07`)
  /// — ⟵ **ومصدرٌ مُدخَلٌ من الواجهة كان يسمح بقيد دائنٍ في مصدرٍ لا ضمار
  /// له فيه**، ⛔ **فيُسدَّد دَينٌ في دفترٍ آخر.**
  final String sourceId;

  /// المتبقي على الضمار **قبل** هذا السطر.
  final Money remainingBefore;

  /// المبلغ الواصل.
  final Money amount;

  /// المتبقي **بعده** — `remainingBefore − amount`.
  final Money remainingAfter;

  /// بيان السطر.
  final String? note;
}

/// ★★ **اقتراح التوزيع التلقائي** — ⛔ **اقتراحٌ لا قرار** (`FR-M12-14`).
final class AutoAllocationProposal {
  /// ينشئ الاقتراح.
  const AutoAllocationProposal({required this.lines, required this.surplus});

  /// السطور المقترَحة **بترتيب الأقدم أولاً**.
  final List<ReceiptLineInput> lines;

  /// ★ **ما فاض بعد استيفاء كل الضمارات** — `FR-M12-13`.
  final Money surplus;
}

/// ★★ **حركةُ تطبيق فائضٍ على ضمارٍ جديد** — `FR-M12-11`.
final class SurplusApplication {
  /// ينشئ الحركة.
  const SurplusApplication({
    required this.surplusId,
    required this.amount,
    required this.memo,
  });

  /// سجل الفائض المسحوب منه ([dealerSurplusId]).
  final String surplusId;

  /// المبلغ المُطبَّق.
  final Money amount;

  /// ★★ **البيان الآلي** — `FR-M12-11` **بنصّه الحرفي**.
  final String memo;
}

/// ★ **سجل فائضٍ متاح** كما يُقرأ من `dealer_surplus`.
final class SurplusPoolRead {
  /// ينشئ السجل.
  const SurplusPoolRead({
    required this.surplusId,
    required this.scope,
    required this.paidOn,
    required this.available,
  });

  /// معرّف السجل.
  final String surplusId;

  /// نطاقه — **مصدرٌ أو عام**.
  final SurplusScope scope;

  /// ★ **تاريخ الدفع** — ⟵ **يدخل البيان الآلي حرفياً** (`FR-M12-11`).
  final CalendarDay paidOn;

  /// ★ المتاح — `ما دُفع زائداً − ما طُبِّق منه` (`design-overview.md` §2.4).
  final Money available;
}

// ═════════════════════════════════════════════════════════════════════════
// ★★★ المعادلات — `design-overview.md` §2.4 · `settlement-design.md` §4 و§5
// ═════════════════════════════════════════════════════════════════════════

/// ★★★ **الفائض المتاح** — `design-overview.md` §2.4.
///
/// ```text
/// الفائض المتاح = ما دُفع زائداً − ما طُبِّق منه على ضمارات لاحقة
/// ```
///
/// ⛔★★ **ولا يهبط تحت الصفر** — ★ **فتطبيقٌ يتجاوز المدفوع تناقضٌ لا رصيدٌ
/// سالب**، ⟵ **والسالب هنا كان سيُقرأ «ديناً على المحل» في `hasSurplus`**
/// ([DealerAccountBalance]) **وهو معنى آخر تماماً.**
Money availableSurplus({required Money paid, required Money applied}) {
  final Money remainder = paid - applied;
  return remainder.isNegative ? Money.zero : remainder;
}

/// ★★★ **التوزيع التلقائي — بالأقدم أولاً** (`FR-M12-13` · `BR-M12-07`).
///
/// ```text
/// يُرتَّب المفتوح بالأقدم أولاً (stockDate) ثم يُسدَّد كلٌّ بالكامل
/// حتى ينفد المبلغ — والأخير قد يُسدَّد جزئياً — وما يفيض فائضٌ.
/// ```
///
/// ⛔⛔★★★ **ولا تكتب هذه الدالة شيئاً ولا تُستدعى من السحابة** — نصّ
/// `FR-M12-14` **حرفياً**: «**تُعرض نتيجة التوزيع التلقائي للمراجعة والتعديل
/// قبل الحفظ ولا تُحفظ تلقائياً — والحساب يجري محلياً في التطبيق بلا كتابة**».
/// ⟵ **فهي تُرجِع [AutoAllocationProposal]** ⛔ **لا سطوراً مُثبَتة**، ★ **وما
/// يُحفَظ هو ما أقرَّه المستخدم بعد تعديله** لا مخرجُ هذه الدالة مباشرةً.
///
/// ⚠️ **والتصفية بالمصدر مسؤولية المُستدعي** — ⟵ **فحقل «المصدر» في الرأس
/// يحدد أي الضمارات تظهر أصلاً** (`FR-M12-04`)، ★ **وهذه تستقبل ما ظهر.**
///
/// ⚠️⚠️ **والترتيب مستقرٌّ عند تساوي التاريخ** — ★ **بمعرّف الضمار**:
/// ⟵ **فاقتراحان لنفس المدخلات متطابقان حرفياً** (`coding-standards.md` §2.7)،
/// ⛔ **ولا يتبدّل ما يراه المستخدم بين عرضين.**
AutoAllocationProposal allocateReceiptAutomatically({
  required Money amount,
  required Iterable<OpenDebtLot> openLots,
}) {
  final List<OpenDebtLot> ordered = <OpenDebtLot>[...openLots]
    ..sort((OpenDebtLot a, OpenDebtLot b) {
      final int byDate = a.stockDate.compareTo(b.stockDate);
      return byDate != 0 ? byDate : a.debtLotId.compareTo(b.debtLotId);
    });

  final List<ReceiptLineInput> lines = <ReceiptLineInput>[];
  Money left = amount;
  for (final OpenDebtLot lot in ordered) {
    if (left.isZero || left.isNegative) break;
    // ⛔ **وضمارٌ متبقّيه صفر أو سالب لا يُقترَح له سطر** — ★ **فسطرٌ بمبلغ
    //    صفر يُرفَض في التحقق أصلاً** ([validateReceiptLine])، ⟵ **واقتراحُه
    //    كان يُنتج سنداً لا يُحفَظ.**
    if (lot.remaining.isZero || lot.remaining.isNegative) continue;
    final Money take = left >= lot.remaining ? lot.remaining : left;
    lines.add(ReceiptLineInput(debtLotId: lot.debtLotId, amount: take));
    left = left - take;
  }
  return AutoAllocationProposal(lines: lines, surplus: left);
}

/// ★★★ **تخطيط تطبيق الفائض على ضمارٍ جديد** (`FR-M12-11` · `FR-M12-12`).
///
/// ```text
/// عند إنشاء ضمار جديد للمقوت:
///    ⚙️ تسدد السحابة تلقائياً من فائضه المتاح
///    ⚙️ وتكتب البيان الآلي: «تسديد تلقائي من المبلغ المدفوع بتاريخ {…}»
///    ↓ وإن بقي فائض يُسدَّد للضمار الذي يليه وهكذا
/// ```
///
/// ⛔⛔★★★ **والنطاق يُفرَض هنا صراحةً كذلك** — ★ **رغم أن المفتاح يفرضه**
/// ([dealerSurplusId]): ⟵ **لأن المُستدعي قد يقرأ سجلات المقوت كلَّها بمرّة**،
/// ★ **فسجلُّ مصدرٍ آخر يُستبعَد هنا قطعاً** (`E-13` · `AT-32`).
///
/// ⚠️ **والأقدم أولاً بين سجلات الفائض نفسِها** — `FR-M12-12`: «**يُسدَّد لأي
/// ضمار قادم بأي مصدر بالأقدم أولاً**» ⟵ **فالمدفوع أولاً يُستهلَك أولاً.**
List<SurplusApplication> planSurplusApplication({
  required Money debtValue,
  required String sourceId,
  required Iterable<SurplusPoolRead> pools,
}) {
  if (debtValue.isZero || debtValue.isNegative) {
    return const <SurplusApplication>[];
  }
  final List<SurplusPoolRead> usable = <SurplusPoolRead>[
    for (final SurplusPoolRead pool in pools)
      if (!pool.available.isZero && !pool.available.isNegative)
        if (pool.scope == SurplusScope.general ||
            pool.surplusId.endsWith('_$sourceId'))
          pool,
  ]..sort((SurplusPoolRead a, SurplusPoolRead b) {
      final int byDate = a.paidOn.compareTo(b.paidOn);
      return byDate != 0 ? byDate : a.surplusId.compareTo(b.surplusId);
    });

  final List<SurplusApplication> applications = <SurplusApplication>[];
  Money left = debtValue;
  for (final SurplusPoolRead pool in usable) {
    if (left.isZero || left.isNegative) break;
    final Money take = left >= pool.available ? pool.available : left;
    applications.add(
      SurplusApplication(
        surplusId: pool.surplusId,
        amount: take,
        memo: surplusApplicationMemo(paidOn: pool.paidOn),
      ),
    );
    left = left - take;
  }
  return applications;
}

/// ★★ **البيان الآلي لتطبيق الفائض** — `FR-M12-11` **بنصّه الحرفي**.
///
/// ⛔⛔★★ **وهذا النص لا يُعبِّئ سبباً نيابةً عن المستخدم** — ★ **والقاعدة
/// الباقية بعد [`ADR-0020`] تخصّ «**سبب التعديل**» وحده**: ⟵ **وهذا **بيان
/// حركة** (`memo`) نصّ عليه المتطلب صراحةً أن **النظام** يكتبه، ⛔ **لا حقل
/// `amendReason`** — **والخلطُ بينهما كان سيُسقِط متطلباً منصوصاً.**
String surplusApplicationMemo({required CalendarDay paidOn}) =>
    'تسديد تلقائي من المبلغ المدفوع بتاريخ ${paidOn.formatReadable()}';

// ═════════════════════════════════════════════════════════════════════════
// التحقق — `error-handling-strategy.md` §3 (**تُرجَع نتيجةً لا تُرمى**)
// ═════════════════════════════════════════════════════════════════════════

/// ★★★ **تاريخ السند** — `FR-M12-02` · `BR-M12-03` · `A-10`.
///
/// ```text
/// مستقبلي            ⟵ مرفوض دائماً بلا استثناء ولأي مستخدم
/// سابق بلا صلاحية    ⟵ مرفوض
/// سابق بصلاحية       ⟵ مقبول
/// اليوم              ⟵ مقبول
/// ```
///
/// ⛔⛔★★ **والمستقبلي مرفوضٌ للمالك نفسِه** — نصّ `permissions-catalog.md`
/// (`receiptBackdate`): «**⛔ والمستقبلي مرفوض مطلقاً للجميع**» ⟵ **فلا مفتاح
/// يفتحه**، ★ **والفحص يسبق فحص الصلاحية عمداً** ⛔ **فلا يُعطي مالكٌ لنفسه
/// تاريخاً مستقبلياً بحُجّة أنه يملك كل المفاتيح.**
Outcome<void> validateReceiptDate({
  required CalendarDay date,
  required CalendarDay today,
  required bool canBackdate,
}) {
  if (date.compareTo(today) > 0) {
    return const Failure<void>(ValidationError('BR-M12-03'));
  }
  if (date.compareTo(today) < 0 && !canBackdate) {
    return const Failure<void>(PermissionError());
  }
  return const Success<void>(null);
}

/// ★★★ **سطر القبض** — `FR-M12-06` · `BR-M12-02`.
///
/// ```text
/// المبلغ الواصل > 0   ولا يتجاوز المتبقي على ذلك الضمار
/// ```
///
/// ⛔★★ **والصفر مرفوضٌ لا مُتجاهَل** — ★ **فسطرٌ بصفر يكتب حركةً دائنة بلا
/// أثر** ⟵ **ويُلوِّث كشف الحساب بسطورٍ لا معنى لها** (`FR-M17`).
Outcome<ValidatedReceiptLine> validateReceiptLine({
  required ReceiptLineInput line,
  required OpenDebtLot lot,
}) {
  if (line.amount.isZero || line.amount.isNegative) {
    return const Failure<ValidatedReceiptLine>(ValidationError('BR-M12-02'));
  }
  if (line.amount > lot.remaining) {
    return const Failure<ValidatedReceiptLine>(ValidationError('BR-M12-02'));
  }
  return Success<ValidatedReceiptLine>(
    ValidatedReceiptLine(
      debtLotId: lot.debtLotId,
      // ★ **المصدر من الضمار المقروء** ⛔ **لا من الحمولة** (`E-35`).
      sourceId: lot.sourceId,
      remainingBefore: lot.remaining,
      amount: line.amount,
      remainingAfter: lot.remaining - line.amount,
      note: line.note,
    ),
  );
}

/// ★★★ **سند القبض كاملاً** — `FR-M12-05` … `FR-M12-10`.
///
/// ⛔⛔★★ **وضمارٌ مكرَّر في سطرين يُرفَض** — ★ **وإلا لتحقّق كلُّ سطرٍ على
/// حدة مقابل **نفس** المتبقي فمرّا معاً**، ⟵ **والمجموع يتجاوز الضمار
/// فيُسدَّد أكثر من قيمته** ⛔ **وهو بالضبط ما يمنعه `BR-M12-02`.**
///
/// ⛔★★ **وسندٌ بلا سطرٍ ولا فائض يُرفَض** — ★ **و`FR-M12-10` يُجيز «الفائض
/// وحده»** ⟵ **فالمرفوض هو الفارغ تماماً** ⛔ **لا الفائضُ المنفرد.**
Outcome<List<ValidatedReceiptLine>> validateReceiptLines({
  required Iterable<ReceiptLineInput> lines,
  required Map<String, OpenDebtLot> lotsById,
  required Money surplusAmount,
}) {
  final List<ValidatedReceiptLine> validated = <ValidatedReceiptLine>[];
  final Set<String> seen = <String>{};
  for (final ReceiptLineInput line in lines) {
    if (!seen.add(line.debtLotId)) {
      return const Failure<List<ValidatedReceiptLine>>(
        ValidationError('BR-M12-02'),
      );
    }
    final OpenDebtLot? lot = lotsById[line.debtLotId];
    if (lot == null) {
      // ⛔ **ضمارٌ لم يُقرأ رفضٌ لا تخطٍّ** — ★ **فتخطّيه يحفظ سنداً بمبلغٍ
      //    أقل مما أقرّه المستخدم** ⟵ **ويبدو ناجحاً.**
      return const Failure<List<ValidatedReceiptLine>>(
        ValidationError('BR-M12-02'),
      );
    }
    switch (validateReceiptLine(line: line, lot: lot)) {
      case Failure<ValidatedReceiptLine>(:final AppError error):
        return Failure<List<ValidatedReceiptLine>>(error);
      case Success<ValidatedReceiptLine>(:final ValidatedReceiptLine value):
        validated.add(value);
    }
  }
  if (validated.isEmpty && (surplusAmount.isZero || surplusAmount.isNegative)) {
    return const Failure<List<ValidatedReceiptLine>>(
      ValidationError('BR-M12-04'),
    );
  }
  return Success<List<ValidatedReceiptLine>>(validated);
}

/// ★★ **تأكيد الإيداع البنكي** — `FR-M12-15` · `BR-M12-08` · `GR-38`.
///
/// ⛔⛔★★ **والملاحظة إلزاميةٌ هنا وحدها خارج [`ADR-0020`]** — ★ **نصّ القرار
/// صراحةً**: **حقلا `balanceAcknowledgement` و`disableReason` خارجه**،
/// ⟵ **وهذا ثالثُهما بنفس العلّة**: **ليس «سبب تعديل» بل إقرارٌ تشغيلي
/// يوثّق أين أُودع المال** ⛔ **وبلا ما يوثّقه لا معنى للتأكيد أصلاً.**
///
/// ★ **والفراغات تُقرأ غياباً لا نصّاً فارغاً** — نفس قاعدة `blankToNull`.
Outcome<void> validateDepositConfirmation({required String? note}) {
  if (note == null || note.trim().isEmpty) {
    return const Failure<void>(ValidationError('BR-M12-08'));
  }
  return const Success<void>(null);
}

/// ★★ **إجمالي الديون على المقوت** — `FR-M12-03` · `BR-M12-11`.
///
/// ⚠️ **عبر كل المصادر** — ★ **للعرض وحده** (`schema/dealer-ledger.md`
/// القاعدة 1: «**الجمع للعرض فقط**») ⛔ **ولا يُبنى عليه قيدٌ واحد.**
Money totalOpenDebt(Iterable<OpenDebtLot> openLots) {
  Money total = Money.zero;
  for (final OpenDebtLot lot in openLots) {
    if (lot.remaining.isNegative) continue;
    total = total + lot.remaining;
  }
  return total;
}

/// ★★ **تسويةٌ جديدة بعد وصول مبلغ** — `settlement-design.md` §3.
///
/// ⛔⛔★★ **ولا نسخة ثانية من المعادلة هنا** — ★ **تُستدعى
/// [computeDebtSettlement] نفسُها** (`ADR-0009`: **لا تكرار لأي معادلة خارج
/// طبقة النطاق** — ★ **ولا داخلها مرتين**).
DebtSettlement settlementAfterReceipt({
  required DebtSettlement current,
  required Money received,
}) =>
    computeDebtSettlement(
      debtValue: current.debtValue,
      settledAmount: current.settledAmount + received,
      discountedAmount: current.discountedAmount,
    );

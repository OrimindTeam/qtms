/// ضمار المالك وحركة النقد (`M15`) — ★ **أخطر معادلات النظام حسابياً**.
///
/// ★ **المصدر:** `FR-M15-01` … `FR-M15-23` ·
/// `module-design/owner-ledger-summary-design.md` §2 و§2.1 و§3 و§4 و§5 ·
/// `design-overview.md` §2.8 و§2.9 · `schema/daily-summaries.md` ·
/// `ADR-0008` (**الملخّص مشتقٌّ لا مصدرَ حقيقة**) · `ADR-0011` القاعدة 4 ·
/// `ADR-0015` (**كلُّ مبلغٍ `int` بالريال**).
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔★★ **أربع قواعد بنيوية يفرضها هذا الملف بنوعه لا بشرطٍ يُنسى:**
///
///   ① ★★★ **الصفّان «قبل الخصم» و«بعد الخصم» حقلان مستقلان إلزاميان**
///      (`OQ-001` الخيار ج · `FR-M15-04`) — ⟵ **والصافي النهائي مبنيٌّ على
///      الثاني وحده**، ⛔ **ولا يُقرأ أحدهما مكان الآخر.**
///   ② ⛔⛔ **والبندُ المحكومُ بصلاحيةٍ يخرج من الصافي كما يخرج من البطاقة**
///      ([projectOwnerLedgerSummary]) — §5 · §10.1 القاعدة 2:
///      ⟵ **فالبطاقةُ تُبنى حسب صلاحيات قارئها** ⛔ **لا تُبنى مرةً وتُفلتَر
///      عرضاً**، ★ **ورقمُ الصافي يختلف بين قارئين — سلوكٌ مقصود لا خلل.**
///   ③ ★★ **وبطاقةُ «كل المصادر» مجموعُ بطاقات المصادر عرضاً فقط**
///      ([aggregateOwnerLedgerSummaries]) — `FR-M15-02` · `A-01`:
///      ⛔ **ولا حسابَ موحّدٌ يُنشأ**، ★ **ومن نطاقه مصدرٌ واحد تُجمَع له من
///      مصادره وحدها** (`E-36`).
///   ④ ⛔⛔ **و«الواصل» ≠ «المقبوض في تاريخ»** (`GR-41` · `FR-M15-15`) —
///      ★ **الأول ذمّةُ يوم** ([OwnerLedgerSummary.settledOfDay]) **والثاني
///      صندوقُ يوم** ([CashMovementSummary.receivedFromDealers])،
///      ⟵ **ولكلٍّ نوعُه هنا** ⛔ **فلا يقبل أحدهما مكان الآخر.**
/// ═══════════════════════════════════════════════════════════════════════
///
/// ⛔⛔★★★ **ولا يُقرأ هذا الملخّص مصدرَ حقيقةٍ في أي معاملة** — `ADR-0008`:
/// ★ **الدفترُ هو الحَكَم دائماً**، ⟵ **والملخّصُ قابلٌ لإعادة البناء منه
/// بالكامل** (§8)، ★ **وكلُّ بناءٍ يُعيد الحساب من الصفر** ⛔ **ولا يُراكِم
/// على قيمةٍ سابقة** (`api-overview.md` §3.3 — `PAT-08`).
library;

import '../../../core/calendar_day.dart';
import '../../../core/money.dart';

// ═════════════════════════════════════════════════════════════════════════
// أسماء المجموعات والمفاتيح — `data-dictionary.md` §4 ·
// `naming-conventions.md` §4. ★ **مصدر حقيقة واحد يشاركه التطبيق والسحابة.**
// ═════════════════════════════════════════════════════════════════════════

/// ملخصات اليوم — ★ **بطاقةُ ضمار المالك جاهزةً** (`schema/daily-summaries.md`).
const String dailySummariesCollection = 'daily_summaries';

/// ✅★★ سجلُّ السلسلة — **مستندٌ واحدٌ لكل مصدر بآخر سبعِ قيم** (`IQ-030`).
///
/// ⛔ **ولا مستندَ لكل يوم** — ★ **وغرضُه قراءةٌ واحدةٌ للرسم كلِّه**
/// (§2.1 القاعدة 3): ⟵ **وسبعُ قراءاتٍ في كل فتحةٍ للبطاقة تخالف §8.**
const String ownerLedgerTrendsCollection = 'owner_ledger_trends';

/// ★★ معرّفُ نطاق «كل المصادر» — **قيمةُ `sourceId` في البطاقة التجميعية**.
///
/// ⛔⛔ **وهي القيمةُ التي تقرؤها قاعدةُ الحماية لتشترط `allSourcesCardView`**
/// (`firestore.rules` — `match /daily_summaries/{summaryId}`): ⟵ **فتغييرُها
/// هنا يفتح البطاقةَ التجميعية لمن لا يملك مفتاحَها**، ⛔ **ولا نسخةَ ثانية
/// منها في أي طبقة.**
const String allSourcesScopeId = 'all';

/// ★ طولُ السلسلة — **سبعُ نقاطٍ كحدٍّ أقصى** (`FR-M15-23` · §2.1).
const int ownerLedgerTrendLength = 7;

/// معرّفُ ملخّص مصدرٍ في يوم — `{sourceId}_{date}`.
///
/// ⚠️⚠️ **والمفتاح المركّب لا يُفهرَس** (`IQ-002` ④) — ⟵ **ولذلك `sourceId`
/// و`date` حقلان صريحان في المستند**: ★ **شرطُ القراءة `storedInScope()`
/// يقرأ الحقل لا المفتاح** (`indexing-strategy.md` §2).
String dailySummaryId({
  required String sourceId,
  required CalendarDay date,
}) {
  if (sourceId.isEmpty) {
    throw ArgumentError.value(sourceId, 'sourceId', 'المصدر إلزامي');
  }
  return '${sourceId}_${date.format()}';
}

/// معرّفُ البطاقة التجميعية — `all_{date}`.
String allSourcesSummaryId(CalendarDay date) =>
    dailySummaryId(sourceId: allSourcesScopeId, date: date);

/// معرّفُ سجلِّ السلسلة — `{sourceId}` · و`all` للتجميعي (§2.1).
String ownerLedgerTrendId(String sourceId) {
  if (sourceId.isEmpty) {
    throw ArgumentError.value(sourceId, 'sourceId', 'المصدر إلزامي');
  }
  return sourceId;
}

// ═════════════════════════════════════════════════════════════════════════
// ★★★ المُدخَلات الخام — **ما يُجمَع من الدفاتر قبل أي معادلة**
// ═════════════════════════════════════════════════════════════════════════

/// مساهماتُ يومٍ في مصدر — ★ **سبعةُ مجاميعَ خام** ⛔ **بلا معادلةٍ واحدة**.
///
/// ★★ **ولماذا نوعٌ مستقلٌّ عن [OwnerLedgerSummary]:** ⟵ **فالجمعُ من
/// الدفاتر مسؤوليةُ السحابة، والمعادلاتُ العشرُ مسؤوليةُ هذا الملف**:
/// ★ **وفصلُهما يجعل كلَّ معادلةٍ قابلةً للاختبار بأرقام §15 المرجعية**
/// ⛔ **بلا قاعدةِ بياناتٍ ولا شبكة.**
final class OwnerLedgerContributions {
  /// ينشئ المساهمات.
  const OwnerLedgerContributions({
    this.credit = Money.zero,
    this.cash = Money.zero,
    this.settledOfDay = Money.zero,
    this.discounts = Money.zero,
    this.tax = Money.zero,
    this.withdrawals = Money.zero,
    this.expenses = Money.zero,
  });

  /// ①-أ **الآجل** — Σ قيم ضمارات اليوم (`debtValue` لكل توزيعةٍ غير ملغاة).
  final Money credit;

  /// ①-ب **النقدي** — Σ صافي البيع النقدي في اليوم (`netCashReceived`).
  final Money cash;

  /// ② **الواصل** — ★ **المسدَّد من ضمارات هذا اليوم** (`settledAmount`).
  ///
  /// ⛔⛔ **ولا علاقةَ له بتاريخ سند القبض** — `FR-M15-05` · `AT-49`:
  /// ⟵ **قبضُ اليومِ لضمار أمس يدخل «واصلَ أمس»** ⛔ **لا واصلَ اليوم.**
  final Money settledOfDay;

  /// ③ **الخصومات** — `discountedAmount` (**بندٌ مستقلٌّ عن الواصل** · `ت-04`).
  final Money discounts;

  /// ⑥ **إجمالي الضريبة** — Σ ضرائب جواني هذا اليوم في هذا المصدر.
  final Money tax;

  /// ⑧ **السحبيات** — Σ سنداتِ `WDR` بتاريخ السند (`GR-49`).
  final Money withdrawals;

  /// ⑨ **الخرجيات** — Σ سنداتِ `EXP` بتاريخ السند (`GR-49`).
  final Money expenses;

  /// يجمع مساهمتين — ★ **لبناء بطاقة «كل المصادر»** (`FR-M15-02`).
  OwnerLedgerContributions operator +(OwnerLedgerContributions other) =>
      OwnerLedgerContributions(
        credit: credit + other.credit,
        cash: cash + other.cash,
        settledOfDay: settledOfDay + other.settledOfDay,
        discounts: discounts + other.discounts,
        tax: tax + other.tax,
        withdrawals: withdrawals + other.withdrawals,
        expenses: expenses + other.expenses,
      );

  /// ★ هل اليومُ بلا حركةٍ إطلاقاً؟ — ⟵ **فلا يُكتب له ملخّصٌ من العدم.**
  bool get isEmpty =>
      credit.isZero &&
      cash.isZero &&
      settledOfDay.isZero &&
      discounts.isZero &&
      tax.isZero &&
      withdrawals.isZero &&
      expenses.isZero;
}

// ═════════════════════════════════════════════════════════════════════════
// ★★★ الملخّص — **البنود العشرة بمعادلاتها** (§3 · `design-overview` §2.8)
// ═════════════════════════════════════════════════════════════════════════

/// بطاقةُ ضمار المالك ليومٍ في مصدر — ★ **بالبنود العشرة كاملةً**.
final class OwnerLedgerSummary {
  /// ينشئ الملخّص — ⛔ **ولا يُستدعى مباشرةً لبناء بطاقة**:
  /// ★ **[computeOwnerLedgerSummary] هي الموضعُ الوحيد للمعادلات.**
  const OwnerLedgerSummary({
    required this.sourceId,
    required this.date,
    required this.credit,
    required this.cash,
    required this.totalDebt,
    required this.settledOfDay,
    required this.discounts,
    required this.remainingBeforeDiscount,
    required this.remainingAfterDiscount,
    required this.tax,
    required this.remainingAfterTax,
    required this.withdrawals,
    required this.expenses,
    required this.netFinal,
    this.retroUpdatedAt,
  });

  /// المصدر — ★ **أو [allSourcesScopeId] للبطاقة التجميعية**.
  final String sourceId;

  /// اليوم — ★ **تاريخُ المخزون** ⛔ **لا تاريخ الإدخال** (`RISK-07`).
  final CalendarDay date;

  /// ①-أ منه آجل.
  final Money credit;

  /// ①-ب منه نقدي.
  final Money cash;

  /// ① إجمالي الضمار = الآجل + النقدي.
  final Money totalDebt;

  /// ② الواصل.
  final Money settledOfDay;

  /// ③ الخصومات.
  final Money discounts;

  /// ④ باقي الضمار **قبل** الخصم = ① − النقدي − ②.
  final Money remainingBeforeDiscount;

  /// ⑤ باقي الضمار **بعد** الخصم = ④ − ③ — ★ **الذمم المفتوحة الفعلية**.
  final Money remainingAfterDiscount;

  /// ⑥ إجمالي الضريبة.
  final Money tax;

  /// ⑦ الباقي بعد الخصم والضريبة = ⑤ − ⑥.
  final Money remainingAfterTax;

  /// ⑧ السحبيات.
  final Money withdrawals;

  /// ⑨ الخرجيات.
  final Money expenses;

  /// ⑩ الصافي النهائي = ⑦ − ⑧ − ⑨ — ★ **مبنيٌّ على «بعد الخصم»** (`OQ-001`).
  final Money netFinal;

  /// ★ وسمُ «⟳ مُحدَّث بأثر رجعي» وتاريخه — `FR-M15-12` · §7.
  final DateTime? retroUpdatedAt;

  /// ★ المساهماتُ الخام المستخرَجة من هذا الملخّص — **لإعادة التجميع**.
  OwnerLedgerContributions get contributions => OwnerLedgerContributions(
        credit: credit,
        cash: cash,
        settledOfDay: settledOfDay,
        discounts: discounts,
        tax: tax,
        withdrawals: withdrawals,
        expenses: expenses,
      );
}

/// ★★★ **يبني البنود العشرة من المساهمات** — **الموضعُ الوحيد للمعادلات**.
///
/// ```text
/// ①  إجمالي الضمار             = الآجل + النقدي
/// ②  الواصل                    = Σ المسدَّد من ضمارات هذا اليوم
/// ③  الخصومات                  = Σ المخصوم من ضمارات هذا اليوم
/// ④  باقي الضمار قبل الخصم     = ① − النقدي − ②
/// ⑤  باقي الضمار بعد الخصم     = ④ − ③
/// ⑥  إجمالي الضريبة            = Σ ضرائب جواني هذا اليوم
/// ⑦  الباقي بعد الخصم والضريبة = ⑤ − ⑥
/// ⑧  السحبيات · ⑨ الخرجيات
/// ⑩  الصافي النهائي            = ⑦ − ⑧ − ⑨
/// ```
///
/// > **لماذا يُطرح «النقدي» في ④؟** لأن ① يشمله، **والنقدي محصَّل فوراً**
/// > فلا يبقى ذمةً على أحد (`design-overview.md` §2.8).
OwnerLedgerSummary computeOwnerLedgerSummary({
  required String sourceId,
  required CalendarDay date,
  required OwnerLedgerContributions contributions,
  DateTime? retroUpdatedAt,
}) {
  final Money totalDebt = contributions.credit + contributions.cash;
  final Money remainingBeforeDiscount =
      totalDebt - contributions.cash - contributions.settledOfDay;
  final Money remainingAfterDiscount =
      remainingBeforeDiscount - contributions.discounts;
  final Money remainingAfterTax = remainingAfterDiscount - contributions.tax;
  final Money netFinal =
      remainingAfterTax - contributions.withdrawals - contributions.expenses;

  return OwnerLedgerSummary(
    sourceId: sourceId,
    date: date,
    credit: contributions.credit,
    cash: contributions.cash,
    totalDebt: totalDebt,
    settledOfDay: contributions.settledOfDay,
    discounts: contributions.discounts,
    remainingBeforeDiscount: remainingBeforeDiscount,
    remainingAfterDiscount: remainingAfterDiscount,
    tax: contributions.tax,
    remainingAfterTax: remainingAfterTax,
    withdrawals: contributions.withdrawals,
    expenses: contributions.expenses,
    netFinal: netFinal,
    retroUpdatedAt: retroUpdatedAt,
  );
}

/// ★★ **بطاقةُ «كل المصادر» = مجموعُ بطاقات المصادر** — `FR-M15-02` · `A-01`.
///
/// ⛔⛔ **وعرضٌ فقط بلا حسابٍ موحّد:** ★ **المعادلاتُ خطّيةٌ كلُّها**، ⟵ **فجمعُ
/// المساهمات ثم بناؤها يُطابق جمعَ البطاقات بنداً ببند** — ★ **واختبارُ
/// التوازن يُثبته** (§11).
///
/// ⛔ **ومن نطاقه مصدرٌ واحد تُجمَع له من مصادره وحدها** (`E-36` · `FR-M15-09`)
/// — ★ **والمُستدعي هو من يُقرِّر ما يدخل القائمة**، ⛔ **لا هذه الدالة.**
OwnerLedgerSummary aggregateOwnerLedgerSummaries({
  required CalendarDay date,
  required Iterable<OwnerLedgerSummary> summaries,
}) {
  OwnerLedgerContributions total = const OwnerLedgerContributions();
  DateTime? retro;
  for (final OwnerLedgerSummary summary in summaries) {
    total = total + summary.contributions;
    final DateTime? stamp = summary.retroUpdatedAt;
    // ★ **وأحدثُ وسمٍ رجعيٍّ بين المصادر يَسِمُ البطاقةَ التجميعية** —
    //   ⟵ **فالتجميعيةُ لا تُخفي أن أحدَ مكوّناتها أُعيد بناؤه** (§7).
    if (stamp != null && (retro == null || stamp.isAfter(retro))) {
      retro = stamp;
    }
  }
  return computeOwnerLedgerSummary(
    sourceId: allSourcesScopeId,
    date: date,
    contributions: total,
    retroUpdatedAt: retro,
  );
}

// ═════════════════════════════════════════════════════════════════════════
// ⛔⛔★★★ البناء حسب صلاحيات القارئ — §5 · `FR-M15-10` · `E-29`
// ═════════════════════════════════════════════════════════════════════════

/// ما يراه القارئ من البندين المحكومين — `withdrawalView` · `expenseView`.
final class OwnerLedgerVisibility {
  /// ينشئ الرؤية.
  const OwnerLedgerVisibility({
    required this.showsWithdrawals,
    required this.showsExpenses,
  });

  /// ★ رؤيةٌ كاملة — **لمن يملك المفتاحين معاً**.
  static const OwnerLedgerVisibility full = OwnerLedgerVisibility(
    showsWithdrawals: true,
    showsExpenses: true,
  );

  /// هل يملك «عرض سحبيات المالك»؟
  final bool showsWithdrawals;

  /// هل يملك «عرض الخرجيات»؟
  final bool showsExpenses;
}

/// ★★★ **البطاقةُ كما يراها قارئٌ بعينه** — ⛔ **لا ملخّصٌ مُفلتَر عرضاً**.
///
/// ⛔⛔ **والبندُ المحكومُ `null` لمن لا يملكه** ⛔ **لا صفراً**:
/// ⟵ **الصفرُ معلومةٌ في هذا النظام** (§9)، ★ **و«يختفي كلياً» يعني غيابَ
/// القيمة** (§10.1 القاعدة 2).
final class OwnerLedgerProjection {
  /// ينشئ الإسقاط — ★ **عبر [projectOwnerLedgerSummary] وحدها.**
  const OwnerLedgerProjection({
    required this.summary,
    required this.withdrawals,
    required this.expenses,
    required this.netFinal,
  });

  /// الملخّصُ المخزَّن كما هو — ★ **بنودُه غيرُ المحكومة تُقرأ منه مباشرة.**
  final OwnerLedgerSummary summary;

  /// ⑧ السحبيات — ★ **`null` لمن لا يملك `withdrawalView`.**
  final Money? withdrawals;

  /// ⑨ الخرجيات — ★ **`null` لمن لا يملك `expenseView`.**
  final Money? expenses;

  /// ⑩ الصافي النهائي **كما يراه هذا القارئ** — ★ **بلا البند المخفي.**
  final Money netFinal;
}

/// ★★★ يُسقِط الملخّصَ على صلاحيات قارئه — §5 · §2.1 القاعدة 5.
///
/// > ⚠️ **الأثر التنفيذي المُعلَن:** «الصافي النهائي» الذي يراه مستخدمان
/// > مختلفا الصلاحيات **قد يختلف رقمه** — **وهذا سلوك مقصود لا خلل** (§5).
OwnerLedgerProjection projectOwnerLedgerSummary(
  OwnerLedgerSummary summary,
  OwnerLedgerVisibility visibility,
) {
  // ★ **والصافيُ يُعاد بناؤه من ⑦** ⛔ **لا يُعدَّل الصافي المخزَّن بالجمع**:
  //   ⟵ **فالمعادلةُ واحدةٌ في الحالتين** ⛔ **ولا فرعٌ ثانٍ يفترق عنها.**
  final Money withdrawals =
      visibility.showsWithdrawals ? summary.withdrawals : Money.zero;
  final Money expenses =
      visibility.showsExpenses ? summary.expenses : Money.zero;
  return OwnerLedgerProjection(
    summary: summary,
    withdrawals: visibility.showsWithdrawals ? summary.withdrawals : null,
    expenses: visibility.showsExpenses ? summary.expenses : null,
    netFinal: summary.remainingAfterTax - withdrawals - expenses,
  );
}

// ═════════════════════════════════════════════════════════════════════════
// ✅★★ سجلُّ السلسلة — `IQ-030` الخيار أ · §2.1
// ═════════════════════════════════════════════════════════════════════════

/// نقطةٌ في سلسلة الصافي — ★ **يومٌ واحد**.
///
/// ⚠️⚠️★★ **وتحمل [withdrawals] و[expenses] معها** — ⛔ **ولا [netFinal]
/// وحده**: ⟵ **لأن §2.1 القاعدة 5 تشترط أن يخرج البندُ المحكوم من صافي
/// الرسم كما يخرج من البطاقة**، ★ **وذلك يستحيل من رقمٍ واحدٍ مجموع.**
/// ⛔⛔ **ولا كشفَ جديداً في هذا:** ★ **البندان مقروءان أصلاً في
/// `daily_summaries` بنفس الشرط** (`ADR-0011` القاعدة 4 — **الملخّصُ محكومٌ
/// على مستوى المستند**)، ⟵ **والقاعدة 4 من §2.1 تشترط الشرطَ نفسَه** —
/// ★ **فلا شرطَ جديدٌ يُخترَع ولا بيانٌ جديدٌ يُكشَف.**
final class OwnerLedgerTrendPoint {
  /// ينشئ النقطة.
  const OwnerLedgerTrendPoint({
    required this.date,
    required this.netFinal,
    required this.withdrawals,
    required this.expenses,
    this.retroUpdated = false,
  });

  /// يومُ النقطة.
  final CalendarDay date;

  /// الصافي النهائي **كاملاً** — ★ **قبل أي إسقاطٍ بصلاحية.**
  final Money netFinal;

  /// ⑧ السحبيات في ذلك اليوم — ★ **لإعادة بناء الصافي للقارئ المحجوب.**
  final Money withdrawals;

  /// ⑨ الخرجيات في ذلك اليوم.
  final Money expenses;

  /// هل أُعيد بناءُ ذلك اليوم بأثرٍ رجعي؟ — §7.
  final bool retroUpdated;

  /// ★ الصافي **كما يراه قارئٌ بعينه** — نفسُ منطق [projectOwnerLedgerSummary].
  Money netFinalFor(OwnerLedgerVisibility visibility) =>
      netFinal +
      (visibility.showsWithdrawals ? Money.zero : withdrawals) +
      (visibility.showsExpenses ? Money.zero : expenses);
}

/// ★★★ يُدرِج نقطةً في السلسلة — **مرتَّبةً تصاعدياً بسبعِ نقاطٍ كحدٍّ أقصى**.
///
/// ⛔⛔★★ **ويستبدل نقطةَ اليوم نفسِه ولا يُضيف ثانية** — ⟵ **فالبناءُ يتكرّر
/// عشراتِ المرات في اليوم الواحد**: ★ **وهو معنى «قابلة للتكرار بلا أثر
/// جانبي»** (`api-overview.md` §3.3 · `PAT-08`)، ⛔ **وإضافةٌ في كل مرة كانت
/// تُخرِج أيامَ الأمس من السلسلة قبل أن ينتهي اليوم.**
///
/// ★ **ويقبل الأثرَ الرجعي على يومٍ قديم** — ⟵ **فيُصلَح موضعُه في مكانه**
/// ⛔ **ولا يُدفَع إلى آخر السلسلة** (§2.1 القاعدة 1).
List<OwnerLedgerTrendPoint> appendOwnerLedgerTrendPoint(
  Iterable<OwnerLedgerTrendPoint> points,
  OwnerLedgerTrendPoint point,
) {
  final List<OwnerLedgerTrendPoint> merged = <OwnerLedgerTrendPoint>[
    for (final OwnerLedgerTrendPoint existing in points)
      if (existing.date != point.date) existing,
    point,
  ]..sort(
      (OwnerLedgerTrendPoint a, OwnerLedgerTrendPoint b) =>
          a.date.compareTo(b.date),
    );
  if (merged.length <= ownerLedgerTrendLength) return merged;
  return merged.sublist(merged.length - ownerLedgerTrendLength);
}

// ═════════════════════════════════════════════════════════════════════════
// ★★★ حركة النقد في تاريخ — `design-overview.md` §2.9 · `FR-M15-15`…`23`
// ═════════════════════════════════════════════════════════════════════════

/// مساهماتُ حركة النقد في تاريخ — ★ **بتاريخ السند لا بتاريخ الضمار**.
final class CashMovementContributions {
  /// ينشئ المساهمات.
  const CashMovementContributions({
    this.receivedForSameDayDebt = Money.zero,
    this.receivedForPreviousDays = Money.zero,
    this.receivedAsSurplus = Money.zero,
    this.cashSales = Money.zero,
    this.withdrawals = Money.zero,
    this.expenses = Money.zero,
    this.discounts = Money.zero,
    this.deposited = Money.zero,
  });

  /// من المقبوض: **ما سدّد ضماراتِ نفس اليوم**.
  final Money receivedForSameDayDebt;

  /// من المقبوض: **ما سدّد ضماراتِ أيامٍ سابقة**.
  final Money receivedForPreviousDays;

  /// من المقبوض: **فائضٌ لم يُسدَّد بعد** (`FR-M12-12`).
  final Money receivedAsSurplus;

  /// المبيعاتُ النقدية المُدخلة في التاريخ — ★ **بتاريخ إدخالها**.
  final Money cashSales;

  /// السحبياتُ في التاريخ.
  final Money withdrawals;

  /// الخرجياتُ في التاريخ.
  final Money expenses;

  /// الخصوماتُ في التاريخ — ⛔ **تُعرَض للعلم ولا تُطرح** (`FR-M15-20`).
  final Money discounts;

  /// من المقبوض: **ما أُودع في الحساب البنكي** (`ADR-0017` · `R-24`).
  final Money deposited;
}

/// حركةُ النقد في تاريخ — ★ **«كم في يدي؟»** (`FR-M15-16` … `FR-M15-21`).
final class CashMovementSummary {
  /// ينشئ الحركة — ★ **عبر [computeCashMovement] وحدها.**
  const CashMovementSummary({
    required this.date,
    required this.receivedFromDealers,
    required this.receivedForSameDayDebt,
    required this.receivedForPreviousDays,
    required this.receivedAsSurplus,
    required this.cashSales,
    required this.totalIn,
    required this.withdrawals,
    required this.expenses,
    required this.totalOut,
    required this.netInHand,
    required this.discounts,
    required this.deposited,
    required this.notDeposited,
    required this.coveragePercent,
    required this.hasCashGap,
  });

  /// تاريخُ الحركة.
  final CalendarDay date;

  /// ★★★ **المقبوضُ من المقاوته في التاريخ** — ⛔ **وليس «الواصل»** (`GR-41`).
  final Money receivedFromDealers;

  /// منه: لضمارات هذا اليوم.
  final Money receivedForSameDayDebt;

  /// منه: لأيامٍ سابقة.
  final Money receivedForPreviousDays;

  /// منه: فائضٌ لم يُسدَّد.
  final Money receivedAsSurplus;

  /// المبيعاتُ النقدية في التاريخ.
  final Money cashSales;

  /// إجمالي النقد الداخل = المقبوض + المبيعات النقدية.
  final Money totalIn;

  /// السحبيات.
  final Money withdrawals;

  /// الخرجيات.
  final Money expenses;

  /// إجمالي الخارج = السحبيات + الخرجيات.
  final Money totalOut;

  /// ★ **صافي النقد المتبقي في اليد** = الداخل − الخارج (`FR-M15-18`).
  final Money netInHand;

  /// الخصومات — ⛔ **للعلم فقط ولا تُطرح** (`FR-M15-20`).
  final Money discounts;

  /// من المقبوض: أُودع.
  final Money deposited;

  /// من المقبوض: لم يُودع بعد.
  final Money notDeposited;

  /// ★ نسبةُ تغطية السحبيات من المقبوض — ⛔ **`null` إن كان المقبوض صفراً**.
  ///
  /// ⛔⛔ **ولا تُكتب صفراً عند غياب المقبوض** — ⟵ **فصفرُ التغطية معلومةٌ
  /// مختلفةٌ تماماً عن «لا مقبوضَ يُقاس عليه»** (§9).
  final int? coveragePercent;

  /// ★ تنبيهُ فجوة النقد — **الصافي في اليد أقلُّ مما لم يُودع** (§9).
  final bool hasCashGap;
}

/// ★★★ يبني حركةَ النقد في تاريخ — `design-overview.md` §2.9.
///
/// ```text
/// الداخل   = المقبوض في التاريخ + المبيعات النقدية في التاريخ
/// الخارج   = السحبيات + الخرجيات
/// الصافي   = الداخل − الخارج
/// التغطية% = (الخارج ÷ المقبوض في التاريخ) × 100
/// ```
///
/// ⛔⛔★★ **وتُطرح السحبياتُ والخرجيات من «المقبوض في التاريخ» لا من
/// «الواصل»** (`GR-47` · `FR-M15-19`) — ★ **لأنها تُصرف من النقد الموجود
/// فعلاً لا من ذمّة اليوم.**
CashMovementSummary computeCashMovement({
  required CalendarDay date,
  required CashMovementContributions contributions,
}) {
  final Money received = contributions.receivedForSameDayDebt +
      contributions.receivedForPreviousDays +
      contributions.receivedAsSurplus;
  final Money totalIn = received + contributions.cashSales;
  final Money totalOut = contributions.withdrawals + contributions.expenses;
  final Money netInHand = totalIn - totalOut;
  final Money notDeposited = received - contributions.deposited;

  return CashMovementSummary(
    date: date,
    receivedFromDealers: received,
    receivedForSameDayDebt: contributions.receivedForSameDayDebt,
    receivedForPreviousDays: contributions.receivedForPreviousDays,
    receivedAsSurplus: contributions.receivedAsSurplus,
    cashSales: contributions.cashSales,
    totalIn: totalIn,
    withdrawals: contributions.withdrawals,
    expenses: contributions.expenses,
    totalOut: totalOut,
    netInHand: netInHand,
    discounts: contributions.discounts,
    deposited: contributions.deposited,
    notDeposited: notDeposited,
    coveragePercent: received.isZero
        ? null
        : (totalOut.riyals * 100 / received.riyals).round(),
    // ⛔ **ولا تنبيهَ حين لا شيءَ لم يُودَع** — ⟵ **فصفرٌ ≥ صفر ليس فجوة.**
    hasCashGap: notDeposited.riyals > 0 && netInHand < notDeposited,
  );
}

/// ★★★ **حركةُ النقد كما يراها قارئٌ بعينه** — ⛔ **لا ملخّصٌ مُفلتَر عرضاً**.
///
/// ⛔⛔★★★ **ونصُّ `E-29` يذكر النقدَ صراحةً:** «**البند يختفي كلياً من
/// البطاقة *والنقد* وكل التقارير**» (§9) — ⟵ **فإخفاءُ الصفِّ وحدَه لا يكفي:**
/// ★ **«إجمالي الخارج» يكشف المخفيَّ بالطرح**، ⛔ **و«صافي النقد في اليد»
/// كذلك.**
final class CashMovementProjection {
  /// ينشئ الإسقاط — ★ **عبر [projectCashMovement] وحدها.**
  const CashMovementProjection({
    required this.summary,
    required this.withdrawals,
    required this.expenses,
    required this.totalOut,
    required this.netInHand,
    required this.coveragePercent,
    required this.hasCashGap,
  });

  /// الحركةُ كاملةً — ★ **بنودُها غيرُ المحكومة تُقرأ منها مباشرة.**
  final CashMovementSummary summary;

  /// السحبيات — ★ **`null` لمن لا يملك `withdrawalView`.**
  final Money? withdrawals;

  /// الخرجيات — ★ **`null` لمن لا يملك `expenseView`.**
  final Money? expenses;

  /// إجمالي الخارج **مما يراه هذا القارئ**.
  final Money totalOut;

  /// صافي النقد في اليد **كما يراه هذا القارئ**.
  final Money netInHand;

  /// نسبةُ التغطية **على ما يراه** — ⛔ **و`null` بلا مقبوضٍ يُقاس عليه.**
  final int? coveragePercent;

  /// تنبيهُ فجوة النقد **على ما يراه**.
  final bool hasCashGap;
}

/// ★★★ يُسقِط حركةَ النقد على صلاحيات قارئها — `E-29` · `FR-M15-10`.
///
/// ★ **والمعادلاتُ هي [computeCashMovement] نفسُها** — ⛔ **ولا فرعٌ ثانٍ
/// يفترق عنها** (`coding-standards.md` §2.2).
CashMovementProjection projectCashMovement(
  CashMovementSummary summary,
  OwnerLedgerVisibility visibility,
) {
  final CashMovementSummary visible = computeCashMovement(
    date: summary.date,
    contributions: CashMovementContributions(
      receivedForSameDayDebt: summary.receivedForSameDayDebt,
      receivedForPreviousDays: summary.receivedForPreviousDays,
      receivedAsSurplus: summary.receivedAsSurplus,
      cashSales: summary.cashSales,
      withdrawals:
          visibility.showsWithdrawals ? summary.withdrawals : Money.zero,
      expenses: visibility.showsExpenses ? summary.expenses : Money.zero,
      discounts: summary.discounts,
      deposited: summary.deposited,
    ),
  );
  return CashMovementProjection(
    summary: summary,
    withdrawals: visibility.showsWithdrawals ? summary.withdrawals : null,
    expenses: visibility.showsExpenses ? summary.expenses : null,
    totalOut: visible.totalOut,
    netInHand: visible.netInHand,
    coveragePercent: visible.coveragePercent,
    hasCashGap: visible.hasCashGap,
  );
}

/// ★★★ **كشف حساب المقوت** (`M17`) — **يُبنى من الدفتر حصراً**.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **القاعدةُ الحاكمة — `FR-M17-03` و`BR-M17-01` و`ADR-0008`:**
/// **الكشفُ يُبنى من `dealer_ledger` وحدَه** ⛔ **لا من أرقامٍ مخزَّنة.**
/// ⟵ **ولذلك لا يقبل هذا الملفُّ `dealer_balances` ولا `OpenDebtLot.remaining`
///    ولا أيَّ حقلٍ مبنيٍّ مسبقاً**: ★ **كلُّ رقمٍ هنا مشتقٌّ من القيود.**
///
/// ⚠️⚠️ **وهذا ليس تشدّداً نظرياً — `DEBT-75` قِيس حيّاً:** ★ **`balanceAfter`
///    يكتبه كاتبُ التوزيع ولا يكتبه كاتبُ القبض**، ⟵ **فقراءتُه حقلاً مخزَّناً
///    كانت تُظهِر «الرصيد الختامي» صفراً بينما الدفترُ يقول 49,800.**
/// ═══════════════════════════════════════════════════════════════════════
///
/// ★ **والفصلُ بالمصدر إلزامي** (`FR-M17-04` · `BR-M17-02` · `GR-20`):
/// ⟵ **و«الكل» تجميعٌ بصريٌّ ببيان كل مصدر** ⛔ **لا رصيدٌ موحّدٌ في الدفاتر.**
///
/// **المصدر:** `FR-M17-01` … `FR-M17-09` · `settlement-design.md` §9 ·
/// `schema/dealer-ledger.md` · `design-overview.md` §2.4.
library;

import '../../../core/arabic_numerals.dart';
import '../../../core/calendar_day.dart';
import '../../../core/money.dart';
import '../../oversight/domain/export_documents.dart';
import '../../oversight/domain/message_templates.dart';
import '../../oversight/domain/report_catalog.dart';
import '../../oversight/domain/report_repository.dart';
import '../../oversight/domain/report_table.dart';
import 'distribution.dart';

// ═════════════════════════════════════════════════════════════════════════
// ① حالةُ الضمار — `settlement-design.md` §3
// ═════════════════════════════════════════════════════════════════════════

/// ★ تخطيطُ الكشف — **نمطان لا ثالثَ لهما** (`FR-M17-02`).
///
/// ⛔ **وفي النطاق لا في الشاشة** — ★ **لأن [buildDealerStatementTable] هي
/// التي تُفرِّع عليه**: ⟵ **والشاشةُ تختار ولا تعرف كيف يُبنى الجدول.**
enum DealerStatementLayout {
  /// ★ **بالضمارات — الافتراضي** (`FR-M17-02`).
  lots,

  /// بالحركات — التفصيلي.
  entries,
}

/// حالةُ الضمار — **ثلاثٌ لا رابعَ لها** (`FR-M17-02`).
enum DebtLotStatus {
  /// لم يُسدَّد منه شيء.
  open,

  /// سُدِّد بعضُه — **قبضاً أو خصماً أو تطبيقَ فائض**.
  partiallyOpen,

  /// ★ **صُفِّي بالكامل** — ⛔ **ولا حدَّ زمنيَّ للإقفال** (ت-11).
  closed,
}

/// ★ اسمُ الحالة كما يُعرَض — ⛔ **ولا يُبنى في شاشة** (`design-system.md` §5.1).
String debtLotStatusLabel(DebtLotStatus status) => switch (status) {
      DebtLotStatus.open => 'مفتوح',
      DebtLotStatus.partiallyOpen => 'مفتوح جزئياً',
      DebtLotStatus.closed => 'مغلق',
    };

// ═════════════════════════════════════════════════════════════════════════
// ② أعمارُ الدين — `FR-M17-07`
// ═════════════════════════════════════════════════════════════════════════

/// ★★ شريحةُ عمرِ دين — **بالضمارات** (`FR-M17-07`).
///
/// ⛔ **والشرائحُ أربعٌ بحدودها المنصوصة** — `FR-M17-07` حرفياً:
/// **0–7 · 8–15 · 16–30 · أكثر من 30** ⛔ **ولا شريحةَ خامسة تُخترَع.**
enum DebtAgeBucket {
  /// 0 … 7 يوماً.
  upToSeven,

  /// 8 … 15 يوماً.
  upToFifteen,

  /// 16 … 30 يوماً.
  upToThirty,

  /// أكثر من 30 يوماً.
  overThirty,
}

/// ★ اسمُ الشريحة كما يُعرَض.
String debtAgeBucketLabel(DebtAgeBucket bucket) => switch (bucket) {
      DebtAgeBucket.upToSeven => '0 – 7 أيام',
      DebtAgeBucket.upToFifteen => '8 – 15 يوماً',
      DebtAgeBucket.upToThirty => '16 – 30 يوماً',
      DebtAgeBucket.overThirty => 'أكثر من 30 يوماً',
    };

/// ★ الشريحةُ التي يقع فيها عمرٌ بالأيام — ⛔ **والسالبُ يقع في الأولى**:
/// ⟵ **ضمارٌ بيومٍ لاحق للمرجع عمرُه صفر** ⛔ **لا شريحةٌ خامسة.**
DebtAgeBucket debtAgeBucketOf(int ageInDays) {
  if (ageInDays <= 7) return DebtAgeBucket.upToSeven;
  if (ageInDays <= 15) return DebtAgeBucket.upToFifteen;
  if (ageInDays <= 30) return DebtAgeBucket.upToThirty;
  return DebtAgeBucket.overThirty;
}

// ═════════════════════════════════════════════════════════════════════════
// ③ يومُ الضمار — مشتقٌّ من معرّفه لا من قراءةٍ ثانية
// ═════════════════════════════════════════════════════════════════════════

/// ★★★ **يومُ الضمار مشتقٌّ من معرّفه** — `{dealerId}_{sourceId}_{stockDate}`.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **ولماذا اشتقاقاً لا قراءةً من `distributions`:**
/// ★ **`FR-M17-03` يمنع بناء الكشف من أي مصدرٍ غير الدفتر** — ⟵ **وقراءةُ
///    مستند التوزيعة لأخذ `stockDate` تُدخِل مصدرَ حقيقةٍ ثانياً** ⛔ **قد
///    يفترق عن الدفتر عند أول تعديل.**
/// ★ **والمعرّفُ نفسُه يحمل اليوم عقداً معتمداً** ([distributionId] ·
///    `naming-conventions.md` §4) — ⟵ **فالاشتقاق قراءةٌ للعقد لا تخمين.**
///
/// ⚠️⚠️ **وهو `stockDate` لا `entryDate` — وهذا هو الصواب هنا تحديداً:**
/// ★ **عمرُ الدين يُحسَب من يوم الضمار** ⛔ **لا من يوم إدخاله**:
/// ⟵ **وتصريفُ متبقّي أمسِ اليومَ يقع في ضمار أمس** (`E-23`)،
/// ★ **فحسابُ عمره من تاريخ الإدخال كان يُظهِر ديناً عمرُه يومان جديداً.**
///
/// ⛔⛔ **ومعرّفٌ لا يطابق العقد يُرجِع `null` ولا يُخمَّن يومُه** — ★ **ويُستبعَد
///    الضمارُ حينها من الأعمار وحدها بتنبيهٍ صريح** ([DealerStatement.lotsWithoutAge])
///    ⛔ **ولا يسقط من الكشف ولا من الرصيد**: ⟵ **فإسقاطُه يُنقِص مبلغاً،
///    وتخمينُ يومه يُنشئ عمراً كاذباً** — ★ **وكلاهما أسوأ من إعلان الجهل.**
/// ═══════════════════════════════════════════════════════════════════════
CalendarDay? debtLotStockDate(String debtLotId) {
  final int separator = debtLotId.lastIndexOf('_');
  if (separator < 0 || separator == debtLotId.length - 1) return null;
  return CalendarDay.tryParseCompact(debtLotId.substring(separator + 1));
}

/// ★ عمرُ يومٍ بالأيام حتى [reference] — ⛔ **بلا `DateTime` يُبنى في مُستدعٍ.**
int debtAgeInDays({required CalendarDay lotDay, required CalendarDay reference}) =>
    reference.asUtcMidnight().difference(lotDay.asUtcMidnight()).inDays;

// ═════════════════════════════════════════════════════════════════════════
// ④ صفوفُ الكشف
// ═════════════════════════════════════════════════════════════════════════

/// ★★ سطرُ ضمارٍ في نمط العرض الافتراضي — `FR-M17-02`.
///
/// ★ **وكلُّ حقلٍ هنا مشتقٌّ من قيود الدفتر** ⛔ **لا مقروءٌ مخزَّناً.**
final class DealerStatementLot {
  /// ينشئ السطر.
  const DealerStatementLot({
    required this.debtLotId,
    required this.sourceId,
    required this.value,
    required this.settled,
    required this.discounted,
    required this.status,
    this.stockDate,
    this.documentNumber,
  });

  /// معرّف الضمار.
  final String debtLotId;

  /// ★ المصدر — **إلزامي في كل سطر** (`FR-M17-04`).
  final String sourceId;

  /// قيمةُ الضمار — **مجموعُ قيوده المدينة غير الملغاة**.
  final Money value;

  /// المسدَّد — **قبضاً وتطبيقَ فائض**.
  final Money settled;

  /// المخصوم — **خصماً وحدَه** (`M13` · `GR-41`).
  final Money discounted;

  /// حالةُ الضمار.
  final DebtLotStatus status;

  /// ★ يومُ الضمار — و`null` **لمعرّفٍ لا يطابق العقد** ([debtLotStockDate]).
  final CalendarDay? stockDate;

  /// رقمُ مستند التوزيعة — للعرض.
  final String? documentNumber;

  /// ★ المتبقي — `القيمة − المسدَّد − المخصوم` (`settlement-design.md` §3).
  Money get remaining => value - settled - discounted;
}

/// ★★ سطرُ حركةٍ في النمط التفصيلي — `FR-M17-02`.
final class DealerStatementEntry {
  /// ينشئ السطر.
  const DealerStatementEntry({
    required this.entryId,
    required this.sourceId,
    required this.direction,
    required this.amount,
    required this.runningBalance,
    required this.isCancelled,
    this.lastAmendedAt,
    this.amendedBy,
    this.debtLotId,
    this.entryType,
    this.entryDate,
    this.documentNumber,
    this.memo,
  });

  /// معرّف القيد.
  final String entryId;

  /// ★ المصدر — **يُسمّى في كل سطر** (`FR-M17-04`).
  final String sourceId;

  /// الاتجاه.
  final DealerLedgerDirection direction;

  /// المبلغ.
  final Money amount;

  /// ★★ **الرصيدُ التراكمي بعد هذه الحركة** — ⛔ **مشتقٌّ لا مقروء** (`DEBT-75`).
  ///
  /// ⚠️ **والملغاةُ لا تُحرِّكه** — `FR-M17-06`: ⟵ **فرصيدُها هو رصيدُ ما قبلها.**
  final Money runningBalance;

  /// ★ ملغاة؟ — **تُستبعَد من الأرصدة ويجوز إظهارها مشطوبة** (`FR-M17-06`).
  final bool isCancelled;

  /// ★★ **وقتُ آخر تعديل** — و`null` **لحركةٍ لم تُعدَّل** (`FR-M17-05`).
  final DateTime? lastAmendedAt;

  /// ★ من عدّل — `FR-M17-05`.
  final String? amendedBy;

  /// ★★ **مُعدَّلة؟** — ⟵ **شارةُ «مُعدَّل» أمامها** (`FR-M17-05`).
  ///
  /// ⛔⛔ **والحركةُ تُعدَّل في مكانها فلا يظهر لها سطرٌ مضاد** (`A-14`) —
  /// ★ **فبلا هذه الشارة يقرأ المقوتُ رقماً مُعدَّلاً كأنه الأصل.**
  ///
  /// ⛔ **ومقيسٌ من الدفتر لا وسمٌ يُمرَّر** — [DealerLedgerRowCard.lastAmendedAt].
  bool get isAmended => lastAmendedAt != null;

  /// ★ الضمارُ المتأثر — و`null` **لقيدٍ لا يخصّ ضماراً بعينه**.
  final String? debtLotId;

  /// نوع القيد — و`null` **لنوعٍ لا يعرفه هذا الإصدار**.
  final DealerLedgerEntryType? entryType;

  /// تاريخ الإدخال.
  final DateTime? entryDate;

  /// رقم المستند.
  final String? documentNumber;

  /// البيان — **آليٌّ عند تطبيق الفائض** (`FR-M12-11`).
  final String? memo;
}

/// ★ اسمُ نوع القيد كما يُعرَض — ⛔ **و«غير معروف» لنوعٍ لا يعرفه الإصدار.**
String dealerLedgerEntryTypeLabel(DealerLedgerEntryType? type) =>
    switch (type) {
      DealerLedgerEntryType.debt => 'ضمار',
      DealerLedgerEntryType.receipt => 'قبض',
      DealerLedgerEntryType.discount => 'خصم',
      DealerLedgerEntryType.surplusApplication => 'تطبيق فائض',
      null => 'نوع غير معروف',
    };

// ═════════════════════════════════════════════════════════════════════════
// ⑤ الكشف الكامل
// ═════════════════════════════════════════════════════════════════════════

/// ★★★ **الكشفُ المبنيّ** — **رأسٌ ونمطا عرضٍ وتذييل** (`FR-M17-01`…`07`).
final class DealerStatement {
  /// ينشئ الكشف.
  const DealerStatement({
    required this.dealerName,
    required this.sourceIds,
    required this.lots,
    required this.entries,
    required this.totalDebit,
    required this.totalCredit,
    required this.availableSurplus,
    required this.aging,
    required this.lotsWithoutAge,
    required this.issuedOn,
    this.dealerCode,
    this.dealerPhone,
    this.unpricedNotice,
  });

  /// اسمُ المقوت — `FR-M17-01`.
  final String dealerName;

  /// ★★ **المصادرُ المشمولة** — ⛔ **مُعدَّدةٌ دائماً ولو كانت واحداً**:
  /// ⟵ **فرأسُ الكشف يقول أيَّ مصدرٍ يعرض** (`FR-M17-01` · `FR-M17-04`).
  final List<String> sourceIds;

  /// سطورُ الضمارات — **النمطُ الافتراضي**.
  final List<DealerStatementLot> lots;

  /// سطورُ الحركات — **النمطُ التفصيلي**.
  final List<DealerStatementEntry> entries;

  /// إجمالي المدين — **غيرُ الملغاة وحدها**.
  final Money totalDebit;

  /// إجمالي الدائن — **غيرُ الملغاة وحدها**.
  final Money totalCredit;

  /// ★★ **الفائضُ المتاح** — `FR-M17-07`: ⟵ **يُطرح من الرصيد بياناً**
  /// ⛔ **ولا يُخصَم منه**: ★ **فهو نقدٌ لدى المحل لم يُنسَب لضمارٍ بعد.**
  final Money availableSurplus;

  /// ★ أعمارُ الدين — **بالمتبقي على الضمارات المفتوحة** (`FR-M17-07`).
  final Map<DebtAgeBucket, Money> aging;

  /// ⚠️ **ضماراتٌ تعذّر اشتقاق يومها** — ★ **تُعلَن ولا تُخمَّن**
  /// ([debtLotStockDate]).
  final List<DealerStatementLot> lotsWithoutAge;

  /// تاريخ الإصدار — `FR-M17-01`.
  final CalendarDay issuedOn;

  /// كودُ المقوت — `FR-M17-01`.
  final String? dealerCode;

  /// هاتفُ المقوت — `FR-M17-01`.
  final String? dealerPhone;

  /// ⚠️ **تنبيهُ السطور غير المسعَّرة** — `FR-M17-07`: ⛔ **ولا تدخل الرصيد.**
  final String? unpricedNotice;

  /// ★★★ **الرصيدُ المستحق** — `المدين − الدائن` (`schema/dealer-ledger.md`).
  Money get balance => totalDebit - totalCredit;

  /// ★ الرصيدُ بالكتابة العربية — `FR-M17-07`.
  String get balanceInWords => riyalsInArabicWords(balance);

  /// ★ مجموعُ ما زال مفتوحاً على الضمارات.
  Money get openRemaining {
    Money total = Money.zero;
    for (final DealerStatementLot lot in lots) {
      if (lot.remaining.riyals > 0) total = total + lot.remaining;
    }
    return total;
  }
}

// ═════════════════════════════════════════════════════════════════════════
// ⑥ الباني
// ═════════════════════════════════════════════════════════════════════════

/// ★ يرتّب القيود بتاريخ الإدخال — **والقديمُ أولاً**.
///
/// ⛔ **وقيدٌ بلا طابعٍ يُؤخَّر** — ★ **ولا يُقحَم في وسط السلسلة بتخمين.**
int _byEntryDate(DealerStatementEntry a, DealerStatementEntry b) {
  final DateTime? left = a.entryDate;
  final DateTime? right = b.entryDate;
  if (left == null && right == null) return a.entryId.compareTo(b.entryId);
  if (left == null) return 1;
  if (right == null) return -1;
  final int byDate = left.compareTo(right);
  return byDate != 0 ? byDate : a.entryId.compareTo(b.entryId);
}

/// ★★★ **يبني كشف الحساب من قيود الدفتر وحدها** — `FR-M17-03`.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ★ **[ledger] قيودُ المقوت في المصادر المطلوبة** — ⟵ **والاستعلامُ يبقى
///    مقيَّداً بالمصدر دائماً** (`IQ-024`): ★ **و«الكل» استعلامٌ لكل مصدرٍ
///    ثم دمجٌ في الذاكرة** ⛔ **لا استعلامٌ واحدٌ غيرُ مقيَّد.**
///
/// ⛔⛔★★ **والملغاةُ تُعرَض ولا تدخل رقماً واحداً** (`FR-M17-06` · `A-14`):
/// ⟵ **لا في المدين ولا في الدائن ولا في قيمة الضمار ولا في عمره.**
/// ═══════════════════════════════════════════════════════════════════════
DealerStatement buildDealerStatement({
  required String dealerName,
  required List<String> sourceIds,
  required List<DealerLedgerRowCard> ledger,
  required CalendarDay issuedOn,
  Money availableSurplus = Money.zero,
  Map<String, String> lotDocumentNumbers = const <String, String>{},
  String? dealerCode,
  String? dealerPhone,
  String? unpricedNotice,
}) {
  // ── ① الحركات مرتَّبةً، والرصيدُ الجاري مشتقٌّ منها ──
  final List<DealerStatementEntry> ordered = <DealerStatementEntry>[
    for (final DealerLedgerRowCard row in ledger)
      DealerStatementEntry(
        entryId: row.entryId,
        sourceId: row.sourceId,
        direction: row.direction,
        amount: row.amount,
        // ★ يُعاد بناؤه أدناه بعد الترتيب — ⛔ **ولا يُقرأ مخزَّناً.**
        runningBalance: Money.zero,
        isCancelled: row.isCancelled,
        lastAmendedAt: row.lastAmendedAt,
        amendedBy: row.amendedBy,
        debtLotId: row.debtLotId,
        entryType: row.entryType,
        entryDate: row.entryDate,
        documentNumber: row.sourceDocNumber,
        memo: row.memo,
      ),
  ]..sort(_byEntryDate);

  Money debit = Money.zero;
  Money credit = Money.zero;
  Money running = Money.zero;
  final List<DealerStatementEntry> entries = <DealerStatementEntry>[];
  for (final DealerStatementEntry entry in ordered) {
    if (!entry.isCancelled) {
      if (entry.direction == DealerLedgerDirection.debit) {
        debit = debit + entry.amount;
        running = running + entry.amount;
      } else {
        credit = credit + entry.amount;
        running = running - entry.amount;
      }
    }
    entries.add(
      DealerStatementEntry(
        entryId: entry.entryId,
        sourceId: entry.sourceId,
        direction: entry.direction,
        amount: entry.amount,
        runningBalance: running,
        isCancelled: entry.isCancelled,
        lastAmendedAt: entry.lastAmendedAt,
        amendedBy: entry.amendedBy,
        debtLotId: entry.debtLotId,
        entryType: entry.entryType,
        entryDate: entry.entryDate,
        documentNumber: entry.documentNumber,
        memo: entry.memo,
      ),
    );
  }

  // ── ② الضمارات مجمَّعةً من القيود نفسِها ──
  //
  // ⛔⛔★★ **والتجميعُ بـ`debtLotId` لا بالمستند** — ★ **فحركةٌ دائنةٌ لكل
  //    سطرِ قبضٍ** (`BR-M12-01`): ⟵ **وسندٌ واحد يمسّ ثلاثة ضمارات.**
  final Map<String, Money> lotValue = <String, Money>{};
  final Map<String, Money> lotSettled = <String, Money>{};
  final Map<String, Money> lotDiscounted = <String, Money>{};
  final Map<String, String> lotSource = <String, String>{};
  // ★★★ **رقمُ مستند الضمار — من قيده المدين نفسِه** (`WU-017`).
  //
  // ⛔⛔ **ولا يُقرأ من `distributions`** — ★ **`FR-M17-03`: الكشفُ من الدفتر
  //    حصراً**: ⟵ **وقيدُ الضمار يحمل `sourceDocNumber` أصلاً**
  //    (`schema/dealer-ledger.md`)، ⛔ **فقراءةُ المستند الأب تُدخِل مصدرَ
  //    حقيقةٍ ثانياً بلا حاجة.**
  //
  // ⚠️ **ورُصد على المحاكي (2026-09-04):** ★ **كان كلُّ سطرٍ يعرض «بلا مستند»
  //    بينما رقمُ التوزيعة في الدفتر** — ⟵ **وسطرُ ضمارٍ بلا رقم مستنده لا
  //    يُراجَع**: ★ **والمقوتُ يحتجّ على مبلغٍ لا يجد سنده.**
  final Map<String, String> lotDocument = <String, String>{};
  final List<String> lotOrder = <String>[];

  for (final DealerStatementEntry entry in entries) {
    if (entry.isCancelled) continue;
    final String? lotId = entry.debtLotId;
    if (lotId == null) continue;
    if (!lotValue.containsKey(lotId)) {
      lotValue[lotId] = Money.zero;
      lotSettled[lotId] = Money.zero;
      lotDiscounted[lotId] = Money.zero;
      lotSource[lotId] = entry.sourceId;
      lotOrder.add(lotId);
    }
    switch (entry.entryType) {
      case DealerLedgerEntryType.debt:
        lotValue[lotId] = lotValue[lotId]! + entry.amount;
        // ★ **ورقمُه من قيده المدين** — ⛔ **ولا من قيدِ قبضٍ أو خصم**:
        //   ⟵ **تلك مستنداتٌ أخرى لها سطورُها في النمط التفصيلي.**
        if (entry.documentNumber case final String number) {
          lotDocument[lotId] = number;
        }
      case DealerLedgerEntryType.discount:
        lotDiscounted[lotId] = lotDiscounted[lotId]! + entry.amount;
      case DealerLedgerEntryType.receipt:
      case DealerLedgerEntryType.surplusApplication:
        lotSettled[lotId] = lotSettled[lotId]! + entry.amount;
      // ⛔⛔ **ونوعٌ لا يعرفه هذا الإصدار لا يُنسَب لخانةٍ بالتخمين** —
      //    ★ **نفسُ حكم [dealerLedgerEntryTypeLabel]**: ⟵ **قيدُ قبضٍ
      //    يُحسَب خصماً يكذب على المقوت وعلى المدقّق معاً.**
      case null:
        break;
    }
  }

  final List<DealerStatementLot> lots = <DealerStatementLot>[
    for (final String lotId in lotOrder)
      DealerStatementLot(
        debtLotId: lotId,
        sourceId: lotSource[lotId]!,
        value: lotValue[lotId]!,
        settled: lotSettled[lotId]!,
        discounted: lotDiscounted[lotId]!,
        status: _statusOf(
          value: lotValue[lotId]!,
          settled: lotSettled[lotId]!,
          discounted: lotDiscounted[lotId]!,
        ),
        stockDate: debtLotStockDate(lotId),
        documentNumber: lotDocumentNumbers[lotId] ?? lotDocument[lotId],
      ),
  ];

  // ── ③ الأعمار — **بالمتبقي على الضمارات المفتوحة وحدها** ──
  final Map<DebtAgeBucket, Money> aging = <DebtAgeBucket, Money>{
    for (final DebtAgeBucket bucket in DebtAgeBucket.values) bucket: Money.zero,
  };
  final List<DealerStatementLot> withoutAge = <DealerStatementLot>[];
  for (final DealerStatementLot lot in lots) {
    if (lot.remaining.riyals <= 0) continue;
    final CalendarDay? day = lot.stockDate;
    if (day == null) {
      withoutAge.add(lot);
      continue;
    }
    final DebtAgeBucket bucket = debtAgeBucketOf(
      debtAgeInDays(lotDay: day, reference: issuedOn),
    );
    aging[bucket] = aging[bucket]! + lot.remaining;
  }

  return DealerStatement(
    dealerName: dealerName,
    sourceIds: List<String>.unmodifiable(sourceIds),
    lots: List<DealerStatementLot>.unmodifiable(lots),
    entries: List<DealerStatementEntry>.unmodifiable(entries),
    totalDebit: debit,
    totalCredit: credit,
    availableSurplus: availableSurplus,
    aging: Map<DebtAgeBucket, Money>.unmodifiable(aging),
    lotsWithoutAge: List<DealerStatementLot>.unmodifiable(withoutAge),
    issuedOn: issuedOn,
    dealerCode: dealerCode,
    dealerPhone: dealerPhone,
    unpricedNotice: unpricedNotice,
  );
}

/// ★ حالةُ الضمار من أرقامه — `settlement-design.md` §3.
///
/// ⛔ **وضمارٌ قيمتُه صفرٌ يُقرأ مغلقاً** — ★ **لا مفتوحاً بلا متبقٍّ.**
DebtLotStatus _statusOf({
  required Money value,
  required Money settled,
  required Money discounted,
}) {
  final Money covered = settled + discounted;
  if (covered.riyals >= value.riyals) return DebtLotStatus.closed;
  if (covered.isZero) return DebtLotStatus.open;
  return DebtLotStatus.partiallyOpen;
}

// ═════════════════════════════════════════════════════════════════════════
// ⑦ إسقاطُ الكشف جدولاً — **مصدرٌ واحد للشاشة وللملف المُصدَّر**
// ═════════════════════════════════════════════════════════════════════════

/// ★★★ **يُسقِط الكشفَ في [ReportTable] بنمط العرض المطلوب** — `FR-M17-02`.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **ولماذا جدولٌ واحد للشاشة وللتصدير معاً:** ★ **هو معيارُ قبول
///    `WU-010` حرفياً** — «**الملفُّ يطابق الشاشةَ رقماً برقم**»:
///    ⟵ **والخلايا تُنسَّق هنا مرةً واحدة**، ⛔ **فلا دالةَ تنسيقٍ ثانية بين
///    الشاشة والملف ولا موضعَ لافتراقهما** (`report_table.dart` نصّاً).
/// ⟹ **وهذا ما يجعل «التصدير» في `FR-M17-08` إعادةَ استعمالٍ للمسار القائم**
///    ([buildReportExport] · `documentExport`) ⛔ **لا مساراً ثانياً يُبنى.**
///
/// ⚠️ **و[showCancelled] يُظهر الملغاةَ ولا يُدخِلها رقماً** (`FR-M17-06`):
/// ★ **الإجمالياتُ محسوبةٌ في [DealerStatement] قبل هذا الإسقاط أصلاً**،
/// ⛔ **فلا يستطيع هذا الخيارُ أن يُغيِّر مبلغاً ولو أراد.**
/// ═══════════════════════════════════════════════════════════════════════
ReportTable buildDealerStatementTable({
  required DealerStatement statement,
  required ReportPeriod period,
  required DealerStatementLayout layout,
  bool showCancelled = false,
  String Function(String sourceId)? sourceName,
  String thousandsSeparator = ',',
}) {
  String money(Money amount) =>
      formatRiyals(amount, thousandsSeparator: thousandsSeparator);
  String source(String id) => sourceName?.call(id) ?? id;

  final List<ExportField> header = <ExportField>[
    ExportField('المقوت', statement.dealerName),
    if (statement.dealerCode case final String code)
      ExportField('الكود', code),
    if (statement.dealerPhone case final String phone)
      ExportField('الهاتف', phone),
    // ★★ **والمصادرُ مُسمّاةٌ في الرأس** — `FR-M17-01` · `FR-M17-04`:
    //    ⟵ **و«الكل» تُكتب بأسماء مصادرها** ⛔ **لا بكلمةٍ مبهمة.**
    ExportField(
      'المصدر',
      statement.sourceIds.isEmpty
          ? 'لا مصدر في نطاقك'
          : statement.sourceIds.map(source).join(' · '),
    ),
    ExportField('الفترة (تاريخ الإدخال)', period.label),
    ExportField('تاريخ الإصدار', statement.issuedOn.formatReadable()),
  ];

  final List<ExportField> totals = <ExportField>[
    ExportField('إجمالي المدين', money(statement.totalDebit)),
    ExportField('إجمالي الدائن', money(statement.totalCredit)),
    ExportField('الرصيد المستحق', money(statement.balance)),
    // ★ **وبالكتابة العربية** — `FR-M17-07`: ⟵ **حارسُ الرقم من التحريف.**
    ExportField('الرصيد كتابةً', statement.balanceInWords),
    // ⛔⛔ **والفائضُ بيانٌ يُطرح قراءةً ولا يُخصَم من الرصيد** (`FR-M17-07`).
    ExportField('المبلغ الفائض المتاح', money(statement.availableSurplus)),
    for (final DebtAgeBucket bucket in DebtAgeBucket.values)
      ExportField(
        'أعمار الدين — ${debtAgeBucketLabel(bucket)}',
        money(statement.aging[bucket] ?? Money.zero),
      ),
    if (statement.lotsWithoutAge.isNotEmpty)
      ExportField(
        '⚠️ ضمارات خارج الأعمار',
        '${statement.lotsWithoutAge.length} ضمار بلا تاريخ مقروء',
      ),
    if (statement.unpricedNotice case final String notice)
      ExportField('⚠️ تنبيه', notice),
  ];

  return switch (layout) {
    DealerStatementLayout.lots => ReportTable(
        report: ReportId.dealerStatement,
        header: header,
        columns: const <ReportColumn>[
          ReportColumn('تاريخ الضمار'),
          ReportColumn('المصدر'),
          ReportColumn('المستند'),
          ReportColumn('قيمة الضمار', numeric: true),
          ReportColumn('مسدَّد', numeric: true),
          ReportColumn('مخصوم', numeric: true),
          ReportColumn('المتبقي', numeric: true),
          ReportColumn('الحالة'),
        ],
        rows: <ReportRow>[
          for (final DealerStatementLot lot in statement.lots)
            ReportRow(
              <String>[
                lot.stockDate?.formatReadable() ?? 'بلا تاريخ',
                source(lot.sourceId),
                lot.documentNumber ?? 'بلا مستند',
                money(lot.value),
                money(lot.settled),
                money(lot.discounted),
                money(lot.remaining),
                debtLotStatusLabel(lot.status),
              ],
            ),
        ],
        totals: totals,
      ),
    DealerStatementLayout.entries => ReportTable(
        report: ReportId.dealerStatement,
        header: header,
        columns: const <ReportColumn>[
          ReportColumn('تاريخ الإدخال'),
          ReportColumn('المصدر'),
          ReportColumn('البيان'),
          ReportColumn('المستند'),
          ReportColumn('مدين', numeric: true),
          ReportColumn('دائن', numeric: true),
          ReportColumn('الرصيد التراكمي', numeric: true),
        ],
        rows: <ReportRow>[
          for (final DealerStatementEntry entry in statement.entries)
            if (showCancelled || !entry.isCancelled)
              ReportRow(
                <String>[
                  entry.entryDate == null
                      ? 'بلا تاريخ'
                      : CalendarDay.fromUtc(entry.entryDate!.toUtc())
                          .formatReadable(),
                  source(entry.sourceId),
                  // ★★ **وشارةُ «مُعدَّل» نصٌّ في الخلية** — `FR-M17-05`:
                  //    ⛔ **ولا لونٌ وحدَه** (`design-system.md` §8 ⑫)،
                  //    ⟵ **فتظهر في الملف المُصدَّر كما تظهر على الشاشة.**
                  entry.isAmended
                      ? '${dealerLedgerEntryTypeLabel(entry.entryType)} (مُعدَّل)'
                      : dealerLedgerEntryTypeLabel(entry.entryType),
                  entry.documentNumber ?? 'بلا مستند',
                  entry.direction == DealerLedgerDirection.debit
                      ? money(entry.amount)
                      : '',
                  entry.direction == DealerLedgerDirection.credit
                      ? money(entry.amount)
                      : '',
                  money(entry.runningBalance),
                ],
                isCancelled: entry.isCancelled,
              ),
        ],
        totals: totals,
      ),
  };
}

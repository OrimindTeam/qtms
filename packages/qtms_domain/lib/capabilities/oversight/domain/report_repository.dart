/// عقودُ قراءة التقارير — ★ **يعرّفها النطاق وتُنفِّذها البنية التحتية**
/// (`ADR-0009` · `ADR-0010` القاعدة 2).
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **وكلُّ استعلامٍ هنا يُقيّد `sourceId` صراحةً — قياسٌ ثلاثيٌّ لا
/// اجتهاد** (`IQ-024` · `WU-008` · `DEBT-40`): ★ **شرطُ قراءة هذه المجموعات
/// `storedInScope()` وهو يقرأ `resource.data.sourceId`**، ⟵ **واستعلامُ
/// سردٍ لا يُقيّده يُرفَض كاملاً ولو كان نطاقُ المستخدم شاملاً.**
/// ⛔ **والعلاج تقييدُ الحقل وفهرسٌ ببادئته** ⛔ **لا تخفيفُ القاعدة.**
///
/// ⟵ ★★ **ولذلك «كل المصادر» في `FR-M19` §1 مصادرُ مُعدَّدة يدمجها المزوّد**
/// ⛔ **ولا تصل الدليلَ غياباً** — **بنفس ما فُعل في `watchOpenDebtLots`
/// حرفياً** (`WU-007`).
/// ═══════════════════════════════════════════════════════════════════════
///
/// ⚠️⚠️ **والقراءةُ لقطةٌ لا تدفّق** — `reporting-design.md` §4: «**لا
/// مستمعين لحظيين على التقارير — قراءة عند الطلب فقط**»، ⟵ **فمستمعٌ حيٌّ
/// على فترةٍ شهرية يُعيد قراءتها عند كل كتابةٍ في المصدر** ⛔ **بكلفةٍ بلا
/// مقابل** (`NFR-COST-03`).
library;

import '../../../core/calendar_day.dart';
import '../../../core/money.dart';
import '../../financial_outflow/domain/outflow.dart';
import '../../financial_outflow/domain/outflow_repository.dart';
import '../../financial_outflow/domain/owner_ledger_summary.dart';
import '../../inventory/domain/disposal_repository.dart';
import '../../inventory/domain/inventory_repository.dart';
import '../../inventory/domain/sack_intake_repository.dart';
import '../../inventory/domain/sack_valuation_repository.dart';
import '../../sales_receivables/domain/cash_sale_repository.dart';
import '../../sales_receivables/domain/discount_repository.dart';
import '../../sales_receivables/domain/distribution.dart';
import '../../sales_receivables/domain/distribution_repository.dart';
import '../../sales_receivables/domain/receipt.dart';
import '../../sales_receivables/domain/receipt_repository.dart';
import 'pending_entry.dart';

/// ★★ حدُّ الصفحة الواحدة في أي تقرير تفصيلي.
///
/// ⚠️ **وليس رقماً تجميلياً** — `reporting-design.md` §4: «**التقارير
/// التفصيلية تقرأ الدفتر بترقيم صفحات — لا تُحمَّل فترة كاملة دفعةً واحدة**»،
/// ★ **ومئتان تسع الشهرَ في مصدرٍ نشط بلا أن تُثقِل جهازاً ميدانياً.**
const int reportPageSize = 200;

/// ★★ فترةُ التقرير — **يومان شاملان طرفيهما**.
///
/// ⛔ **ولا مدىً مقلوب** — ★ **والنوعُ يمنعه ببانيه** ⟵ **فلا شاشةَ تُرسِل
/// «من» بعد «إلى»** فتعرض فراغاً يبدو «لا بيانات».
final class ReportPeriod {
  const ReportPeriod._(this.from, this.to);

  /// ★ فترةُ يومٍ واحد — **`R-02` و`R-05`** (`FR-M19` §2: «التاريخ»).
  factory ReportPeriod.singleDay(CalendarDay day) => ReportPeriod._(day, day);

  /// ★ يبني الفترة — و`null` **للمدى المقلوب**.
  ///
  /// ═════════════════════════════════════════════════════════════════════
  /// ⛔⛔ **ولا يُقلَب المدى ضمناً ولا يُصحَّح** — ★ **بنفس ما فعله
  /// `AuditLogFilterState.withRange` حرفياً** (`WU-008`): ⟵ **المدى المقلوب
  /// يُهمَل فتبقى الفترةُ السابقة قائمة**، ⛔ **ولا يُبنى تقريرٌ على مدىً لم
  /// يقصده المستخدم.**
  ///
  /// ⛔ **ولا `AppError` هنا** — ★ **كتالوجُ الأخطاء تسعُ فئاتٍ مغلقة**
  /// (`error-handling-strategy.md` §2) ⛔ **ولا يُخترَع رمزُ قاعدةٍ لها**،
  /// ⟵ **والحارسُ في منتقي التاريخ نفسِه** (`design-system.md` §6.ب).
  /// ═════════════════════════════════════════════════════════════════════
  static ReportPeriod? of({
    required CalendarDay from,
    required CalendarDay to,
  }) =>
      from.compareTo(to) > 0 ? null : ReportPeriod._(from, to);

  /// أول يوم — **شاملٌ**.
  final CalendarDay from;

  /// آخر يوم — **شاملٌ**.
  final CalendarDay to;

  /// ★ نصُّ الفترة للترويسة — ⛔ **ولا يُبنى في شاشة** (`design-system.md` §5.1).
  String get label => from == to
      ? from.formatReadable()
      : 'من ${from.formatReadable()} إلى ${to.formatReadable()}';

  /// ★ معرّفُ المدى في `entityId` عند التصدير — **`YYYYMMDD-YYYYMMDD`**.
  String get compactRange => '${from.format()}-${to.format()}';
}

/// ★★ صفٌّ في دفتر المقاوته كما يُقرأ للتقارير — `R-19`.
///
/// ⚠️ **ومستقلٌّ عن [DealerLedgerEntry]** — ★ **ذاك مُدخَلُ معادلةِ الرصيد
/// (اتجاهٌ ومبلغٌ وإلغاء) وحده**، ⟵ **وهذا بطاقةُ عرضٍ تحمل ما يُقرأ في
/// كشف الحساب** (التاريخ · النوع · المستند · الرصيد بعد الحركة).
/// ⛔ **ولا يُوسَّع ذاك ليحمل عرضاً** — ⟵ **فتدخل حقولُ العرض في كل معادلة.**
final class DealerLedgerRowCard {
  /// ينشئ الصف.
  const DealerLedgerRowCard({
    required this.entryId,
    required this.dealerId,
    required this.sourceId,
    required this.direction,
    required this.entryType,
    required this.amount,
    required this.isCancelled,
    this.entryDate,
    this.debtLotId,
    this.sourceDocNumber,
    this.memo,
    this.lastAmendedAt,
    this.amendedBy,
  });

  /// معرّف القيد.
  final String entryId;

  /// المقوت.
  final String dealerId;

  /// المصدر.
  final String sourceId;

  /// الاتجاه — **مدين أو دائن**.
  final DealerLedgerDirection direction;

  /// ★ نوع القيد — و`null` **لنوعٍ لا يعرفه هذا الإصدار**.
  ///
  /// ⛔ **ولا يُقرأ «ضماراً» احتياطاً** — ★ **قيدُ قبضٍ يُعرَض ضماراً يكذب
  /// على المدقّق** (نفس منطق `AuditAction` في `WU-008`).
  final DealerLedgerEntryType? entryType;

  /// المبلغ.
  final Money amount;

  /// ★ ملغى؟ — ⛔ **يُعرَض ولا يدخل الإجماليات** (`A-14`).
  final bool isCancelled;

  /// تاريخ الإدخال — و`null` **لقيدٍ بلا طابع**.
  final DateTime? entryDate;

  /// الضمار المتأثر.
  final String? debtLotId;

  /// رقم المستند المصدر.
  final String? sourceDocNumber;

  /// البيان الآلي — **لقيود تطبيق الفائض** (`FR-M12-11`).
  final String? memo;

  /// ★★ **وقتُ آخر تعديل** — و`null` **لحركةٍ لم تُعدَّل** (`FR-M17-05`).
  ///
  /// ⛔⛔★★ **ولماذا حقلٌ في الصف لا وسمٌ يُمرَّر من الشاشة:** ★ **الحركةُ
  /// تُعدَّل في مكانها فلا يظهر لها سطرٌ مضاد** (`A-14` · `BR-M17-03`) —
  /// ⟹ **فبلا هذا الحقل يقرأ المقوتُ رقماً مُعدَّلاً كأنه الأصل**، ⛔ **ولا
  /// أثرَ في الكشف يدلّه.** ★ **والدفترُ يكتبه أصلاً** (`schema/dealer-ledger.md`).
  final DateTime? lastAmendedAt;

  /// ★ من عدّل — `FR-M17-05` («**مع اسم من عدّل ووقت التعديل**»).
  final String? amendedBy;
}

/// ★★★ دليلُ قراءة التقارير — ⛔ **قراءةً فقط ولا كتابةَ واحدة**.
///
/// ★ **وكلُّ دالةٍ لقطةٌ واحدة** (`Future`) ⛔ **لا تدفّق** — راجع ترويسة الملف.
abstract interface class ReportDirectory {
  /// `R-01` — **حركاتُ نوعٍ في مصدرٍ خلال فترة**.
  ///
  /// ★ **الفهرس:** `sourceId ↑ · itemKey ↑ · stockDate ↓`.
  Future<List<StockMovementCard>> itemMovements({
    required String sourceId,
    required String itemKey,
    required ReportPeriod period,
    int limit,
  });

  /// `R-02` · `R-05` — **أرصدةُ الأنواع في يومٍ واحد**.
  ///
  /// ★ **الفهرس:** `sourceId ↑ · stockDate ↑ · itemKey ↑`.
  ///
  /// ⛔⛔ **وعلى `stockDate` لا `entryDate`** (`RISK-07` · `ADR-0006`) —
  /// ★ **وخلطُهما يُنتج أرقاماً خاطئة بصمت** لا تظهر إلا مع تصريفٍ متأخر.
  Future<List<ItemDailyBalanceCard>> dailyBalances({
    required String sourceId,
    required CalendarDay stockDate,
  });

  /// `R-03` — **مستنداتُ الوارد عدداً في فترة**.
  ///
  /// ★ **الفهرس:** `sourceId ↑ · stockDate ↓` (**أُضيف في `WU-011`**).
  Future<List<CountedIntakeCard>> countedIntakes({
    required String sourceId,
    required ReportPeriod period,
    int limit,
  });

  /// `R-04` — **جواني الفترة**.
  ///
  /// ★ **الفهرس:** `sourceId ↑ · stockDate ↓`.
  Future<List<SackCard>> sacks({
    required String sourceId,
    required ReportPeriod period,
    int limit,
  });

  /// ★★ `R-07` — **مستنداتُ الإتلاف في فترة** (`WU-020`).
  ///
  /// ★ **الفهرس:** `sourceId ↑ · stockDate ↓` — ★ **نفسُ شكل [sacks]**،
  /// ⛔ **ولا فهرسَ ثانٍ يُخترَع.**
  ///
  /// ⛔⛔★★ **ولا مفتاحَ عرضٍ زائدٌ لها** — ★ **شرطُ قراءة `disposals`
  /// النطاقُ وحده** (`firestore.rules` §22): ⟵ **ولا حقلَ ماليَّ فيها
  /// يُحجَب** (`FR-M8-16`).
  Future<List<DisposalCard>> disposals({
    required String sourceId,
    required ReportPeriod period,
    int limit,
  });

  /// `R-08` · `R-10` — **توزيعاتُ الفترة**.
  ///
  /// ★ **الفهرس:** `sourceId ↑ · stockDate ↓` · ★ **وبحالةِ تسويةٍ:**
  /// `sourceId ↑ · settlementStatus ↑ · stockDate ↓` (**أُضيف في `WU-011`**).
  Future<List<DistributionCard>> distributions({
    required String sourceId,
    required ReportPeriod period,
    SettlementStatus? settlementStatus,
    int limit,
  });

  /// 🔒 `R-10` — **أسعارُ توزيعاتٍ بعينها وقيمُ ضماراتها**.
  ///
  /// ⛔⛔★★ **ولا تصل إلا لمن يملك `distributionPriceView`** (`ADR-0011` ·
  /// `ت-12`) — ★ **والمفقودُ يعني «لا أملك رؤيته» أو «لا سعرَ بعد» معاً**،
  /// ⟵ **والتمييز لا يلزم التقرير: كلاهما «لا يُعرَض عمود القيمة»**
  /// (`FR-M10-07`).
  ///
  /// ⚠️ **وقراءةٌ لكل توزيعة** — ★ **ولذلك تُطلَب لصفحةٍ واحدة لا لفترةٍ
  /// كاملة**: ⟵ **الأسعارُ في مستندٍ فرعي بشرطِ قراءةٍ مستقل** ⛔ **ولا
  /// تُقرأ باستعلامِ مجموعةٍ واحد** (`ADR-0011`).
  Future<Map<String, DistributionPricingCard>> distributionPricing({
    required List<String> distributionIds,
  });

  /// `R-14` — **سنداتُ القبض التي مسّت هذا المصدر في الفترة**.
  ///
  /// ★ **الفهرس:** `affectedSourceIds ⊃ · date ↓` — ⚠️ **وهو فهرسُ احتواءِ
  /// مصفوفة**: ★ **لأن سندَ «كل المصادر» يمسّ عدةَ مصادر** ⟵ **ولن يظهر في
  /// أيٍّ منها بفهرسٍ على `sourceFilter`** (`IQ-002` ③).
  Future<List<ReceiptCard>> receipts({
    required String sourceId,
    required ReportPeriod period,
    int limit,
  });

  /// 🔒 `R-14` — **حالاتُ الإيداع لسنداتٍ بعينها**.
  ///
  /// ⛔⛔★★ **ولا تصل إلا لمن يملك `receiptDepositView`** (`ADR-0017`) —
  /// ★ **والمفقودُ يعني «لا أملك رؤيته» أو «لا حالةَ بعد» معاً**، ⟵ **والتمييز
  /// لا يلزم التقرير: كلاهما «لا يُعرَض عمود الإيداع»** (`FR-M12-16`).
  ///
  /// ⚠️ **وقراءةٌ لكل سند** — ★ **ولذلك تُطلَب لصفحةٍ واحدة لا لفترةٍ كاملة**:
  /// ⟵ **حالةُ الإيداع في مستندٍ فرعي بشرطِ قراءةٍ مستقل** ⛔ **ولا تُقرأ
  /// باستعلامِ مجموعةٍ واحد** (`ADR-0017`).
  Future<Map<String, DepositState>> receiptDeposits({
    required List<String> documentNumbers,
  });

  /// `R-17` — **أرصدةُ المقاوته في مصدر**.
  ///
  /// 🔒 **ولا تصل إلا لمن يملك `dealerBalanceView`** — شرطُ القاعدة نفسُه.
  Future<List<DealerBalanceCard>> dealerBalances({
    required String sourceId,
    int limit,
  });

  /// `R-19` — **كشفُ حساب مقوتٍ في مصدرٍ خلال فترة**.
  ///
  /// ★ **الفهرس:** `dealerId ↑ · sourceId ↑ · entryDate ↓`.
  ///
  /// ⚠️⚠️ **والمدى على `entryDate` هنا لا `stockDate`** — ★ **وهو الصواب
  /// وليس مخالفةً للقاعدة 2 من `indexing-strategy.md` §3:** ⟵ **دفترُ
  /// المقاوته دفترٌ مالي لا مخزني**، ★ **وحركتُه تقع يوم إدخالها** ⛔ **ولا
  /// `stockDate` في قيده أصلاً** (`schema/dealer-ledger.md`).
  Future<List<DealerLedgerRowCard>> dealerStatement({
    required String dealerId,
    required String sourceId,
    required ReportPeriod period,
    int limit,
  });

  /// `R-28` — **بنودُ المركز المعلّق في فترة**.
  ///
  /// ★ **الفهرس:** `sourceId ↑ · date ↓`.
  Future<List<PendingEntryCard>> pendingEntries({
    required String sourceId,
    required ReportPeriod period,
    int limit,
  });

  // ═══════════════════════════════════════════════════════════════════
  // ★★ زيادةُ `WU-018` — تقاريرُ المرحلة الثانية
  // ═══════════════════════════════════════════════════════════════════

  /// `R-11` · `R-12` — **سنداتُ البيع النقدي في فترة**.
  ///
  /// ★ **الفهرس:** `sourceId ↑ · stockDate ↓`.
  ///
  /// ⛔⛔ **وعلى `stockDate` لا `entryDate`** — ★ **تقريرٌ بيعيٌّ مخزنيُّ
  /// الأثر** (`RISK-07` · `schema/cash-sales.md` القاعدة 8)، ⚠️ **بخلاف
  /// حركة النقد وحدَها** (`R-16`): ⟵ **تلك صندوقُ يومٍ فتقرأ تاريخ الإدخال**
  /// (`FR-M15-16`) ⛔ **وخلطُهما يُنتج رقمين مختلفين لليوم نفسِه.**
  Future<List<CashSaleCard>> cashSales({
    required String sourceId,
    required ReportPeriod period,
    int limit,
  });

  /// `R-15` — **سنداتُ الخصم التي مسّت هذا المصدر في فترة**.
  ///
  /// ★ **الفهرس:** `affectedSourceIds ⊃ · date ↓` — ⚠️ **فهرسُ احتواءِ
  /// مصفوفة كنظيره في `R-14` حرفياً**: ★ **وسندُ «كل المصادر» يمسّ عدةَ
  /// مصادر** ⟵ **ولن يظهر في أيٍّ منها بفهرسٍ على `sourceFilter`.**
  Future<List<DiscountCard>> discounts({
    required String sourceId,
    required ReportPeriod period,
    int limit,
  });

  /// 🔒 `R-21` · `R-22` — **سنداتُ سجلٍّ بعينه في فترة**.
  ///
  /// ★ **الفهرس:** `sourceId ↑ · ledgerType ↑ · documentDate ↓`.
  ///
  /// ⛔⛔★★★ **و[ledgerType] مُقيَّدٌ صراحةً — استعلامان لا واحد** ([`DEBT-89`]):
  /// ★ **شرطُ قراءة `outflows` يتفرّع على `resource.data.ledgerType`**،
  /// ⟵ **واستعلامٌ لا يُقيّده يُرفَض كاملاً ولو ملك القارئُ المفتاحين معاً.**
  ///
  /// ⚠️ **وتقريرا السحبيات والخرجيات منفصلان تماماً** — `FR-M19-07` · `GR-43`:
  /// ⛔ **ولا تقريرَ واحدٌ يجمعهما بفلترٍ.**
  Future<List<OutflowCard>> outflows({
    required String sourceId,
    required OutflowLedgerType ledgerType,
    required ReportPeriod period,
    int limit,
  });

  /// 🔒 `R-20` · `R-23` — **ملخصاتُ أيام مصدرٍ في فترة**.
  ///
  /// ★ **الفهرس:** `sourceId ↑ · date ↓` · 🔒 **وشرطُها `ownerLedgerView`**.
  ///
  /// ⛔⛔★★ **ولقطةٌ لا بثّ** — ★ **بخلاف `watchSummaryRange`** (`FR-M15-14`):
  /// ⟵ **تلك بطاقةٌ حيّةٌ تُفتَح عشرات المرات يومياً**، ★ **وهذا تقريرٌ
  /// يُقرأ عند الطلب** (`reporting-design.md` §4) ⛔ **فلا مستمعَ عليه.**
  ///
  /// ⛔⛔★★★ **ولا يُقرأ مستندُ «كل المصادر» هنا إطلاقاً** — ★ **«الكل» في
  /// التقارير مصادرُ مُعدَّدة يجمعها المزوّد** ([aggregateOwnerLedgerSummaries]
  /// · `E-36`): ⟵ **فمن نطاقه مصدرٌ واحد لا تدخل أرقامُ غيره تقريرَه**،
  /// ⛔ **ولا يُشترَط له `allSourcesCardView` أصلاً.**
  Future<List<OwnerLedgerSummary>> dailySummaries({
    required String sourceId,
    required ReportPeriod period,
    int limit,
  });

  /// 🔒 `R-25` · `R-26` — **سطورُ دفتر الرعية في مصدرٍ خلال فترة**.
  ///
  /// ★ **الفهرس:** `sourceId ↑ · entryDate ↓` · 🔒 **وشرطُها
  /// `supplierFinanceView`**.
  ///
  /// ⚠️⚠️ **والمدى على `entryDate` لا `stockDate`** — ★ **وهو الصواب لا
  /// مخالفةً للقاعدة 2 من `indexing-strategy.md` §3:** ⟵ **دفترُ الرعية
  /// دفترٌ مالي لا مخزني** ⛔ **ولا `stockDate` في سطره أصلاً**
  /// (`schema/supplier-ledger.md`) — ★ **وهو نفسُ ما فُعل في `R-19` حرفياً.**
  ///
  /// ⛔ **والرعويُّ يُرشَّح محلياً لا في الاستعلام** — ★ **السطرُ يحمل
  /// `supplierId`**، ⟵ **فترشيحُه مجانيٌّ بلا فهرسٍ ثالث** (`DEBT-72`).
  Future<List<SupplierLedgerRow>> supplierLedger({
    required String sourceId,
    required ReportPeriod period,
    int limit,
  });
}

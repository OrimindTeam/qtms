/// مزوّدات التقارير (`WU-011` · `M19`).
///
/// ★ **بنفس نمط `audit_log_providers.dart`:** الدليل **يُحقَن في الجذر ولا
/// يُبنى هنا** (`ADR-0010`) — ⟵ **فتُختبَر الشاشات بلا سحابة ولا شبكة.**
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⚠️⚠️ **وكلُّ ما هنا عرضٌ لا تفويض:** ★ **إخفاءُ تقريرٍ بمفتاح عائلته
/// إخفاءٌ لا حماية** — ⟵ **والحارسُ الفعلي شرطُ قراءة كلِّ مجموعةٍ يقرؤها
/// التقرير ونطاقُ المصادر** (`RISK-02` · `permissions-catalog.md` §2.11):
/// ⛔ **ولا يُدَّعى غيرُ ذلك** — ★ **والمخاطرةُ المتبقية معلَنةٌ في `DEBT-71`.**
///
/// ⛔⛔★★★ **و«كل المصادر» لصاحب النطاق الشامل وحدَه** — ★ **بنفس ما فعله
/// `auditSourceOptionsProvider` حرفياً:** ⟵ **والعمليةُ `logExport` تفحص
/// `canAccessSource('all')` وهي لا تصدُق إلا له** (`export_log.dart`)،
/// ⛔ **فبطاقةُ الخيار عند صاحب نطاقٍ محدود كانت ستُنتج تصديراً مرفوضاً
/// دائماً** يقرؤه المستخدم عطلاً.
/// ═══════════════════════════════════════════════════════════════════════
library;

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qtms_domain/qtms_domain.dart';

import '../../financial_outflow/application/owner_ledger_providers.dart';
import '../../identity_access/application/session_providers.dart';
import '../../inventory/application/inventory_providers.dart';
import '../../inventory/application/sack_valuation_providers.dart';
import '../../master_data/application/master_data_providers.dart';

/// دليلُ قراءة التقارير — ⛔ **يُحقَن في الجذر**.
final Provider<ReportDirectory> reportDirectoryProvider =
    Provider<ReportDirectory>((Ref ref) {
  throw UnimplementedError('reportDirectoryProvider يجب تجاوزه عند الجذر');
});

/// ★★★ **تقاريرُ يومٍ واحد** — ⛔ **ولا مدى «من–إلى» لها** (`WU-018`).
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★ **وقرارُ نطاقٍ معلَنٌ لا سهو** ([`DEBT-94`]): ★ **`R-16` و`R-24`
/// يُجمَعان من الدفاتر عند القراءة لا من ملخّصٍ مبنيٍّ مسبقاً** — ★ **خمسةُ
/// استعلاماتٍ لكل يومٍ لكل مصدر** (`FirestoreCashMovementDirectory`):
/// ⟵ **ومدىً شهريٌّ يُنتج مئةً وخمسين قراءةً لمصدرٍ واحد** ⛔ **بلا سقفٍ
/// موثَّق** — ★ **والعتبةُ الرقمية غيرُ موثَّقة فتكون بند `IQ`**
/// (`implementation-playbook.md` §5). ⟹ **فبُنيا يوماً واحداً كنظيرَيهما
/// `R-02` و`R-05`** — ★ **و«من–إلى» مؤجَّلٌ معلَناً** ⛔ **لا مسكوتاً عنه.**
/// ═══════════════════════════════════════════════════════════════════════
bool isSingleDayReport(ReportId report) =>
    report == ReportId.currentStock ||
    report == ReportId.todayRemainder ||
    report == ReportId.cashMovement ||
    report == ReportId.withdrawalCoverage;

/// ★★ التقاريرُ التي يملك المستخدم مفتاحَ عائلتها — ⛔ **وما عداها لا يُرسَم**.
///
/// ⚠️ **ولا يُعرَض معطَّلاً** — `ui-guidelines.md` نمط 6: «**وبند يُخفى لعدم
/// الصلاحية لا يُترك فراغاً بل يختفي كله**».
/// ⛔⛔★★ **ومفاتيحُ التقرير الزائدة تُفحَص معه** ([ReportId.requiredPermissions])
/// — ★ **وكلُّها شرطُ قراءةٍ يُرَدُّ استعلامُ التقرير بدونه كاملاً**
/// (`IQ-024` · [`DEBT-89`]): ⟵ **فتقريرٌ يُرَدُّ دائماً يُري المستخدم عطلاً
/// لا منعاً**، ⛔ **وهو أسوأ من إخفائه.**
final Provider<List<ReportId>> visibleReportsProvider =
    Provider<List<ReportId>>((Ref ref) {
  bool grants(ReportId report) {
    for (final Permission permission in report.requiredPermissions) {
      if (!ref.watch(hasPermissionProvider(permission))) return false;
    }
    return true;
  }

  return <ReportId>[
    for (final ReportId report in ReportId.values)
      if (grants(report)) report,
  ];
});

/// ★ عائلاتٌ فيها تقريرٌ واحد مرئيٌّ على الأقل — **بترتيب `FR-M19` §2**.
final Provider<List<ReportFamily>> visibleReportFamiliesProvider =
    Provider<List<ReportFamily>>((Ref ref) {
  final List<ReportId> reports = ref.watch(visibleReportsProvider);
  return <ReportFamily>[
    for (final ReportFamily family in ReportFamily.values)
      if (reports.any((ReportId report) => report.family == family)) family,
  ];
});

/// خيارُ مصدرٍ في فلتر التقارير — **معرّفه ونصُّه المعروض**.
///
/// ⛔ **و`sourceId == null` تعني «كل المصادر»** — ★ **ولا تُمرَّر استعلاماً**:
/// ⟵ **تُعدَّد مصادرُ النطاق ويُدمَج ناتجُها محلياً** (`ReportDirectory`).
final class ReportSourceOption {
  /// ينشئ الخيار.
  const ReportSourceOption({required this.sourceId, required this.label});

  /// المعرّف — و`null` **لكل المصادر**.
  final String? sourceId;

  /// النصّ المعروض.
  final String label;
}

/// ★★ خيارات المصدر — **مصادرُ النطاق، و«كل المصادر» لصاحب الشامل وحدَه**.
final Provider<List<ReportSourceOption>> reportSourceOptionsProvider =
    Provider<List<ReportSourceOption>>((Ref ref) {
  final bool allScope =
      ref.watch(currentSessionProvider)?.sourceScope is AllSources;
  return <ReportSourceOption>[
    for (final SourceCard source in ref.watch(activeSourcesProvider))
      ReportSourceOption(sourceId: source.sourceId, label: source.name),
    if (allScope) const ReportSourceOption(sourceId: null, label: 'كل المصادر'),
  ];
});

/// ★★★ طلبُ تقريرٍ واحد — **ما تعرضه الشاشة الآن**.
///
/// ⛔ **وحقولُه الثانوية لكلِّ تقريرٍ ما يخصُّه** — ★ **موصوفةٌ في `FR-M19` §2**:
/// ⟵ **وحقلٌ لا يخصّ التقرير الجاري يُهمَل** ⛔ **ولا يُغيِّر نتيجته.**
@immutable
final class ReportRequest {
  /// ينشئ الطلب.
  const ReportRequest({
    required this.report,
    required this.period,
    this.sourceId,
    this.allSources = false,
    this.itemKey,
    this.dealerId,
    this.settlementStatus,
    this.depositState,
    this.pendingKind,
    this.availability,
    this.balanceState,
    this.outflowCategory,
    this.outflowLineKind,
    this.supplierId,
    this.sackId,
  });

  /// التقرير المطلوب.
  final ReportId report;

  /// الفترة — **يومان شاملان طرفيهما**.
  final ReportPeriod period;

  /// ★ المصدرُ المختار صراحةً — و`null` **يعني «لم يُختَر بعد»**.
  ///
  /// ⛔⛔★★ **ولا تعني «كل المصادر»** — ★ **تلك [allSources] عَلَمٌ صريح**:
  /// ⟵ **وخلطُهما كان يجعل شاشةً فُتحت قبل وصول قائمة المصادر تستعلم كلَّ
  /// مصادر النطاق بلا أن يطلب المستخدم ذلك** ⛔ **بكلفةِ قراءةٍ مضاعفة
  /// وأرقامٍ لا تخصّ ما ظنّه مختاراً** (**عطلٌ رُصد في اختبار `WU-011`**).
  final String? sourceId;

  /// ★★ «كل المصادر» — ⛔ **ولصاحب النطاق الشامل وحدَه** (`export_log.dart`).
  final bool allSources;

  /// `R-01` — النوع المطلوب حركتُه.
  final String? itemKey;

  /// `R-19` — المقوت المطلوب كشفُه.
  final String? dealerId;

  /// `R-10` — حالةُ التسوية.
  final SettlementStatus? settlementStatus;

  /// `R-14` — حالةُ الإيداع البنكي.
  final DepositState? depositState;

  /// `R-28` — نوعُ المستند المعلَّق.
  final PendingDocumentKind? pendingKind;

  /// `R-02` — متوفر أو نفد.
  final StockAvailability? availability;

  /// `R-17` — حالةُ رصيد المقوت.
  final DealerBalanceState? balanceState;

  /// `R-21` · `R-22` — فئةُ السند (`FR-M22-19`).
  final OutflowCategory? outflowCategory;

  /// `R-21` · `R-22` — نوعُ البند (`FR-M22-05`).
  final OutflowLineKind? outflowLineKind;

  /// `R-25` · `R-26` — الرعوي المطلوب حسابُه.
  ///
  /// ⛔ **وترشيحٌ محليٌّ لا قيدُ استعلام** — ★ **السطرُ يحمل `supplierId`**:
  /// ⟵ **فلا فهرسَ ثالثٌ يُنشأ لفلترٍ مجاني** (`DEBT-72`).
  final String? supplierId;

  /// `R-27` — الجونية المطلوب تفكيكُ سعرها.
  final String? sackId;

  /// ★ نسخةٌ بتعديلٍ واحد — ⛔ **والقيمة `null` تعني «امسح هذا الفلتر»**.
  ///
  /// ⚠️⚠️ **ولذلك عَلَمٌ صريحٌ لكل حقلٍ يُمسَح** — ★ **ولا يُستنتَج المسح من
  /// `null`**: ⟵ **وإلا استحال التمييز بين «لم يتغيّر» و«امسحه»**،
  /// ⛔ **وهو الخطأ الذي يجعل فلتراً يعود من تلقائه بعد مسحه.**
  ReportRequest copyWith({
    ReportPeriod? period,
    String? sourceId,
    bool clearSource = false,
    bool? allSources,
    String? itemKey,
    bool clearItem = false,
    String? dealerId,
    bool clearDealer = false,
    SettlementStatus? settlementStatus,
    bool clearSettlement = false,
    DepositState? depositState,
    bool clearDeposit = false,
    PendingDocumentKind? pendingKind,
    bool clearPendingKind = false,
    StockAvailability? availability,
    bool clearAvailability = false,
    DealerBalanceState? balanceState,
    bool clearBalanceState = false,
    OutflowCategory? outflowCategory,
    bool clearOutflowCategory = false,
    OutflowLineKind? outflowLineKind,
    bool clearOutflowLineKind = false,
    String? supplierId,
    bool clearSupplier = false,
    String? sackId,
    bool clearSack = false,
  }) =>
      ReportRequest(
        report: report,
        period: period ?? this.period,
        sourceId: clearSource ? null : (sourceId ?? this.sourceId),
        allSources: allSources ?? this.allSources,
        itemKey: clearItem ? null : (itemKey ?? this.itemKey),
        dealerId: clearDealer ? null : (dealerId ?? this.dealerId),
        settlementStatus: clearSettlement
            ? null
            : (settlementStatus ?? this.settlementStatus),
        depositState:
            clearDeposit ? null : (depositState ?? this.depositState),
        pendingKind:
            clearPendingKind ? null : (pendingKind ?? this.pendingKind),
        availability:
            clearAvailability ? null : (availability ?? this.availability),
        balanceState:
            clearBalanceState ? null : (balanceState ?? this.balanceState),
        outflowCategory: clearOutflowCategory
            ? null
            : (outflowCategory ?? this.outflowCategory),
        outflowLineKind: clearOutflowLineKind
            ? null
            : (outflowLineKind ?? this.outflowLineKind),
        supplierId: clearSupplier ? null : (supplierId ?? this.supplierId),
        sackId: clearSack ? null : (sackId ?? this.sackId),
      );
}

/// ★★ الطلبُ الجاري — و`null` **قبل فتح أي تقرير**.
///
/// ⛔ **وشاشةٌ واحدةٌ مفتوحةٌ في كل لحظة** — ★ **فحالةٌ واحدة تكفي**،
/// ⟵ **وعائلةٌ من الحالات كانت ستُبقي فلاتر تقريرٍ أُغلق حيّةً في الذاكرة.**
final NotifierProvider<ReportRequestState, ReportRequest?>
    reportRequestProvider =
    NotifierProvider<ReportRequestState, ReportRequest?>(
  ReportRequestState.new,
);

/// حالةُ الطلب الجاري.
class ReportRequestState extends Notifier<ReportRequest?> {
  @override
  ReportRequest? build() => null;

  /// ★★ يفتح تقريراً بفلاترِه الافتراضية.
  ///
  /// ⚠️⚠️ **ويُستدعى بعد أول إطار لا داخل `initState`** — `DEBT-68`:
  /// ★ **الكتابةُ في مزوّدٍ أثناء بناء الشجرة تُسقِط الشاشة كاملةً**
  /// (`Tried to modify a provider while the widget tree was building`).
  /// ⛔⛔★★ **ولا يُثبَّت مصدرٌ هنا** — ★ **يُحلّ في [effectiveReportSources]**:
  /// ⟵ **فشاشةٌ تُفتَح قبل وصول قائمة المصادر كانت تُثبِّت «لا مصدر»**،
  /// ⛔ **ثم لا تتصحّح حين تصل القائمة** (**عطلٌ رُصد في اختبار `WU-011`**).
  void open(ReportId report) {
    state = ReportRequest(
      report: report,
      // ★★ **والافتراضُ يومٌ واحد للتقارير اللحظية وأسبوعٌ لما يمتدّ** —
      //    `FR-M19` §2: **`R-02` و`R-05` فلترُهما «التاريخ» لا «الفترة»**.
      period: _defaultPeriod(report, ref.read(todayProvider)),
    );
  }

  /// ★ يُغلق التقرير — ⛔ **فلا تبقى فلاترُه حيّةً بعد مغادرة شاشته**.
  void close() => state = null;

  /// يبدّل المصدر — و`null` **تعني «كل المصادر»**.
  void selectSource(String? sourceId) {
    final ReportRequest? current = state;
    if (current == null) return;
    state = sourceId == null
        ? current.copyWith(clearSource: true, allSources: true)
        : current.copyWith(sourceId: sourceId, allSources: false);
  }

  /// ★ يضبط الفترة — ⛔ **والمدى المقلوب يُهمَل ولا يُقلَب**.
  ///
  /// ★ **بنفس ما فعله `AuditLogFilterState.withRange` حرفياً** (`WU-008`).
  void withPeriod({required CalendarDay from, required CalendarDay to}) {
    final ReportRequest? current = state;
    if (current == null) return;
    final ReportPeriod? period = ReportPeriod.of(from: from, to: to);
    if (period == null) return;
    state = current.copyWith(period: period);
  }

  /// `R-01` — يختار النوع.
  void selectItem(String? itemKey) => _apply(
        (ReportRequest current) => itemKey == null
            ? current.copyWith(clearItem: true)
            : current.copyWith(itemKey: itemKey),
      );

  /// `R-19` — يختار المقوت.
  void selectDealer(String? dealerId) => _apply(
        (ReportRequest current) => dealerId == null
            ? current.copyWith(clearDealer: true)
            : current.copyWith(dealerId: dealerId),
      );

  /// `R-10` — يختار حالة التسوية.
  void selectSettlementStatus(SettlementStatus? status) => _apply(
        (ReportRequest current) => status == null
            ? current.copyWith(clearSettlement: true)
            : current.copyWith(settlementStatus: status),
      );

  /// `R-14` — يختار حالة الإيداع.
  void selectDepositState(DepositState? deposit) => _apply(
        (ReportRequest current) => deposit == null
            ? current.copyWith(clearDeposit: true)
            : current.copyWith(depositState: deposit),
      );

  /// `R-28` — يختار نوع المستند المعلَّق.
  void selectPendingKind(PendingDocumentKind? kind) => _apply(
        (ReportRequest current) => kind == null
            ? current.copyWith(clearPendingKind: true)
            : current.copyWith(pendingKind: kind),
      );

  /// `R-02` — يختار حالة التوفر.
  void selectAvailability(StockAvailability? availability) => _apply(
        (ReportRequest current) => availability == null
            ? current.copyWith(clearAvailability: true)
            : current.copyWith(availability: availability),
      );

  /// `R-17` — يختار حالة الرصيد.
  void selectBalanceState(DealerBalanceState? balanceState) => _apply(
        (ReportRequest current) => balanceState == null
            ? current.copyWith(clearBalanceState: true)
            : current.copyWith(balanceState: balanceState),
      );

  /// `R-21` · `R-22` — يختار فئة السند.
  void selectOutflowCategory(OutflowCategory? category) => _apply(
        (ReportRequest current) => category == null
            ? current.copyWith(clearOutflowCategory: true)
            : current.copyWith(outflowCategory: category),
      );

  /// `R-21` · `R-22` — يختار نوع البند.
  void selectOutflowLineKind(OutflowLineKind? kind) => _apply(
        (ReportRequest current) => kind == null
            ? current.copyWith(clearOutflowLineKind: true)
            : current.copyWith(outflowLineKind: kind),
      );

  /// `R-25` · `R-26` — يختار الرعوي.
  void selectSupplier(String? supplierId) => _apply(
        (ReportRequest current) => supplierId == null
            ? current.copyWith(clearSupplier: true)
            : current.copyWith(supplierId: supplierId),
      );

  /// `R-27` — يختار الجونية.
  void selectSack(String? sackId) => _apply(
        (ReportRequest current) => sackId == null
            ? current.copyWith(clearSack: true)
            : current.copyWith(sackId: sackId),
      );

  void _apply(ReportRequest Function(ReportRequest current) change) {
    final ReportRequest? current = state;
    if (current == null) return;
    state = change(current);
  }

  /// ★★ الفترةُ الافتراضية — **يومٌ لما يخصّ يوماً، وأسبوعٌ لما يمتدّ**.
  ///
  /// ⛔ **ولا شهرٌ افتراضاً** — ★ **صفحةٌ واحدة حدُّها [reportPageSize]**،
  /// ⟵ **وفترةٌ تتجاوزها تُظهر جزءاً بلا أن تقول إنه جزء.**
  static ReportPeriod _defaultPeriod(ReportId report, CalendarDay today) {
    if (isSingleDayReport(report)) return ReportPeriod.singleDay(today);
    CalendarDay from = today;
    for (int i = 0; i < 6; i++) {
      from = from.previousDay();
    }
    return ReportPeriod.of(from: from, to: today) ??
        ReportPeriod.singleDay(today);
  }
}

/// ★★★ المصادرُ التي يقع عليها الاستعلام فعلاً — ⛔ **وفارغةٌ تعني «لا مصدر بعد»**.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ★★ **وهي موضعُ حلِّ المصدر الافتراضي** — ⛔ **لا [ReportRequestState.open]**:
/// ⟵ **فشاشةٌ تُفتَح قبل وصول قائمة المصادر تتصحّح من تلقائها حين تصل**،
/// ⛔ **بدل أن تُثبِّت اختياراً خاطئاً لا يتبدّل** (**عطلٌ رُصد في اختبار
/// `WU-011` قبل النشر** — ★ **وكان يستعلم كلَّ المصادر بلا طلب المستخدم**).
///
/// ⛔⛔★★ **و«كل المصادر» تُعدَّد هنا مصادرَ صريحة** — ★ **ولا تصل الدليلَ
/// غياباً** (`IQ-024` · `DEBT-40`).
/// ═══════════════════════════════════════════════════════════════════════
final Provider<List<String>> effectiveReportSources =
    Provider<List<String>>((Ref ref) {
  final ReportRequest? request = ref.watch(reportRequestProvider);
  if (request == null) return const <String>[];
  final List<SourceCard> active = ref.watch(activeSourcesProvider);
  if (request.allSources) {
    return <String>[for (final SourceCard source in active) source.sourceId];
  }
  if (request.sourceId case final String sourceId) return <String>[sourceId];
  // ★ **وأولُ مصدرٍ في النطاق افتراضاً** — ⛔ **ولا استعلامَ قبل وصوله.**
  return active.isEmpty ? const <String>[] : <String>[active.first.sourceId];
});

/// ★★ جوانيُّ الفترة — **قائمةُ اختيارِ `R-27` وحدَها**.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★ **و`autoDispose` إلزاميّة** ([`DEBT-90`]) — ★ **قراءةٌ عند الطلب
/// بلا `autoDispose` تُخزِّن نتيجتَها**: ⟵ **فتعرض جوانيَّ فترةٍ سابقة بعد
/// تبديل المدى** ⛔ **مخالفةٌ لـ`ADR-0008`.**
///
/// ⛔ **ولا تُقرأ إلا لهذا التقرير** — ★ **فقائمةُ الجواني قراءةٌ إضافية**:
/// ⟵ **وتحميلُها في كل تقريرٍ كان يُضاعف الكلفة بلا مقابل** (`NFR-COST-03`).
/// ═══════════════════════════════════════════════════════════════════════
final reportSacksProvider =
    FutureProvider.autoDispose<List<SackCard>>((Ref ref) async {
  final ReportRequest? request = ref.watch(reportRequestProvider);
  // ★ **وتخدم `R-04` كذلك** — **فلترُ الجونية فيه** ([`DEBT-72`] ②):
  //   ⛔ **ولا تُقرأ لتقريرٍ لا يعرضها** (`NFR-COST-03`).
  if (request == null ||
      (request.report != ReportId.sackPriceBreakdown &&
          request.report != ReportId.sackIntakes)) {
    return const <SackCard>[];
  }
  final ReportDirectory directory = ref.watch(reportDirectoryProvider);
  return <SackCard>[
    for (final String sourceId in ref.watch(effectiveReportSources))
      ...await directory.sacks(sourceId: sourceId, period: request.period),
  ];
});

/// ★ المصدرُ المختار فعلاً — و`null` **لـ«كل المصادر» أو قبل وصول القائمة**.
final Provider<String?> selectedReportSource = Provider<String?>((Ref ref) {
  final ReportRequest? request = ref.watch(reportRequestProvider);
  if (request == null || request.allSources) return null;
  final List<String> sources = ref.watch(effectiveReportSources);
  return sources.isEmpty ? null : sources.first;
});

/// ★★★ جدولُ التقرير الجاري — و`null` **قبل فتح أي تقرير**.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★ **ولقطةٌ لا تدفّق** — `reporting-design.md` §4: «**لا مستمعين
/// لحظيين على التقارير**»، ⟵ **والتحديث بسحبٍ صريح** (`ref.invalidate`).
///
/// ★★ **و«كل المصادر» استعلامٌ لكل مصدرٍ ثم دمجٌ محلي** — ⛔ **ولا استعلامَ
/// واحدٌ عابرٌ للمصادر**: ★ **القاعدة ترفضه** (`IQ-024` · `DEBT-40`).
/// ═══════════════════════════════════════════════════════════════════════
final FutureProvider<Outcome<ReportTable?>> reportTableProvider =
    FutureProvider<Outcome<ReportTable?>>((Ref ref) async {
  try {
    return Success<ReportTable?>(await _buildTable(ref));
  } on Object catch (error) {
    // ⛔⛔★★★ **والرفضُ يُرجَع نتيجةً ولا يُرمى** — `error-handling-strategy.md`
    //    §3 القاعدة 3، ⟵ **ولها هنا سببٌ ثانٍ مقيسٌ لا نظري** (`DEBT-73`):
    //    ★★ **Riverpod 3 يُعيد المحاولة تلقائياً على أي مزوّدٍ يرمي** —
    //    ⟵ **فالحالةُ تبقى `AsyncLoading` بلا نهاية والمستخدم أمام هيكلٍ
    //    شبحيٍّ أبداً**، ⛔ **ولا تظهر حالةُ الخطأ إطلاقاً.**
    //    ★ **وقيسَ في اختبار `WU-011`**: `AsyncError` لم تصل الشاشة قطّ.
    return Failure<ReportTable?>(_asAppError(error));
  }
});

/// ★ يترجم رفضَ المنصّة إلى خطأ نطاق — ⛔ **ولا يُعرَض رمزٌ تقني للمستخدم**.
///
/// ★★ **و«ممنوع» أشيعُ سببٍ هنا بفارق** — ★ **شرطُ قراءةٍ أو نطاقُ مصادر**
/// (`GR-23`): ⟵ **ورسالتُه من الكتالوج قابلةٌ للتصرف**، ⛔ **بخلاف رسالةٍ
/// عامة تترك المستخدم بلا خطوةٍ تالية.**
AppError _asAppError(Object error) => switch (error) {
      // ★ **وما وصل نتيجةً يُفكّ نتيجةً** — ⛔ **بلا فحص نصٍّ هشّ.**
      final _ReportFailure failure => failure.error,
      _ when error.toString().contains('permission-denied') =>
        const PermissionError(),
      _ => InfrastructureError(error.toString()),
    };

/// ★ يبني الجدول — ⛔ **ويرمي عند الرفض ليُترجَم في مُستدعيه وحده**.
Future<ReportTable?> _buildTable(Ref ref) async {
  final ReportRequest? request = ref.watch(reportRequestProvider);
  if (request == null) return null;

  final ReportDirectory directory = ref.watch(reportDirectoryProvider);
  final String separator =
      ref.watch(appSettingsProvider).value?.thousandsSeparator ?? '';
  // ⛔⛔★★ **ولا استعلامَ بلا مصدرٍ صريح** — ★ **القاعدة ترفضه** (`IQ-024`):
  //    ⟵ **وفراغُ القائمة يعني «لم تصل مصادرُ النطاق بعد»**، ★ **فتُعرَض
  //    الشاشةُ طالبةً الاختيار** ⛔ **لا مستعلِمةً بلا قيد.**
  final List<String> sources = ref.watch(effectiveReportSources);
  if (sources.isEmpty) return null;

  final Map<String, String> dealerNames = <String, String>{
    for (final DealerCard dealer
        in ref.watch(dealersProvider).value ?? const <DealerCard>[])
      dealer.dealerId: dealer.name,
  };
  final Map<String, String> supplierNames = <String, String>{
    for (final SupplierCard supplier
        in ref.watch(suppliersProvider).value ?? const <SupplierCard>[])
      supplier.supplierId: supplier.name,
  };

  switch (request.report) {
    case ReportId.itemMovements:
      final String? itemKey = request.itemKey;
      if (itemKey == null) return null;
      final List<StockMovementCard> movements = <StockMovementCard>[
        for (final String sourceId in sources)
          ...await directory.itemMovements(
            sourceId: sourceId,
            itemKey: itemKey,
            period: request.period,
          ),
      ];
      return buildItemMovementsReport(
        period: request.period,
        itemName: _itemName(ref, itemKey),
        movements: movements,
      );

    case ReportId.currentStock:
      return buildCurrentStockReport(
        stockDate: request.period.to,
        balances: await _balances(directory, sources, request.period.to),
        availability: request.availability,
        itemKey: request.itemKey,
        itemName: _itemNameOrNull(ref, request.itemKey),
      );

    case ReportId.todayRemainder:
      return buildTodayRemainderReport(
        stockDate: request.period.to,
        balances: await _balances(directory, sources, request.period.to),
        itemKey: request.itemKey,
        itemName: _itemNameOrNull(ref, request.itemKey),
      );

    case ReportId.countedIntakes:
      final List<CountedIntakeCard> intakes = <CountedIntakeCard>[
        for (final String sourceId in sources)
          ...await directory.countedIntakes(
            sourceId: sourceId,
            period: request.period,
          ),
      ];
      return buildCountedIntakesReport(
        period: request.period,
        intakes: intakes,
        supplierNames: supplierNames,
        supplierId: request.supplierId,
        itemKey: request.itemKey,
        itemName: _itemNameOrNull(ref, request.itemKey),
      );

    case ReportId.sackIntakes:
      final List<SackCard> sacks = <SackCard>[
        for (final String sourceId in sources)
          ...await directory.sacks(
            sourceId: sourceId,
            period: request.period,
          ),
      ];
      return buildSackIntakesReport(
        period: request.period,
        sacks: sacks,
        supplierNames: supplierNames,
        supplierId: request.supplierId,
        sackId: request.sackId,
      );

    case ReportId.distributions:
      return buildDistributionsReport(
        period: request.period,
        distributions: await _distributions(directory, sources, request),
        dealerNames: dealerNames,
        dealerId: request.dealerId,
      );

    case ReportId.settlements:
      final List<DistributionCard> cards =
          await _distributions(directory, sources, request);
      // 🔒 **والأسعارُ لمن يملك `distributionPriceView` وحدَه** (`ت-12`) —
      //    ⛔ **ولا تُطلَب أصلاً لغيره**: ⟵ **فلا قراءةٌ تُرفَض بلا داعٍ.**
      final Map<String, DistributionPricingCard> pricing =
          ref.watch(hasPermissionProvider(Permission.distributionPriceView))
              ? await directory.distributionPricing(
                  distributionIds: <String>[
                    for (final DistributionCard card in cards)
                      card.distributionId,
                  ],
                )
              : const <String, DistributionPricingCard>{};
      return buildSettlementsReport(
        period: request.period,
        distributions: cards,
        pricing: pricing,
        dealerNames: dealerNames,
        settlementStatus: request.settlementStatus,
        dealerId: request.dealerId,
        thousandsSeparator: separator,
      );

    case ReportId.receipts:
      final List<ReceiptCard> receipts = <ReceiptCard>[
        for (final String sourceId in sources)
          ...await directory.receipts(
            sourceId: sourceId,
            period: request.period,
          ),
      ];
      // 🔒 **وحالةُ الإيداع لمن يملك `receiptDepositView` وحدَه** (`ADR-0017`).
      final Map<String, DepositState> deposits =
          ref.watch(hasPermissionProvider(Permission.receiptDepositView))
              ? await directory.receiptDeposits(
                  documentNumbers: <String>[
                    for (final ReceiptCard receipt in receipts)
                      receipt.documentNumber,
                  ],
                )
              : const <String, DepositState>{};
      return buildReceiptsReport(
        period: request.period,
        receipts: receipts,
        sourceId: ref.watch(selectedReportSource),
        deposits: deposits,
        depositFilter: request.depositState,
        thousandsSeparator: separator,
      );

    case ReportId.dealerBalances:
      final List<DealerBalanceCard> balances = <DealerBalanceCard>[
        for (final String sourceId in sources)
          ...await directory.dealerBalances(sourceId: sourceId),
      ];
      return buildDealerBalancesReport(
        balances: balances,
        dealerNames: dealerNames,
        state: request.balanceState,
        thousandsSeparator: separator,
      );

    case ReportId.dealerStatement:
      final String? dealerId = request.dealerId;
      if (dealerId == null) return null;
      final List<DealerLedgerRowCard> entries = <DealerLedgerRowCard>[
        for (final String sourceId in sources)
          ...await directory.dealerStatement(
            dealerId: dealerId,
            sourceId: sourceId,
            period: request.period,
          ),
      ];
      return buildDealerStatementReport(
        period: request.period,
        dealerName: dealerNames[dealerId] ?? dealerId,
        entries: entries,
        thousandsSeparator: separator,
      );

    case ReportId.pendingEntries:
      final List<PendingEntryCard> entries = <PendingEntryCard>[
        for (final String sourceId in sources)
          ...await directory.pendingEntries(
            sourceId: sourceId,
            period: request.period,
          ),
      ];
      return buildPendingEntriesReport(
        period: request.period,
        entries: entries,
        kind: request.pendingKind,
      );

    // ═══════════════════ زيادةُ `WU-018` — المرحلة الثانية ═══════════════════

    case ReportId.dealerDistributionSummary:
      final List<DistributionCard> cards =
          await _distributions(directory, sources, request);
      // 🔒 **والأسعارُ لمن يملك `distributionPriceView` وحدَه** (`ت-12`).
      final Map<String, DistributionPricingCard> pricing =
          ref.watch(hasPermissionProvider(Permission.distributionPriceView))
              ? await directory.distributionPricing(
                  distributionIds: <String>[
                    for (final DistributionCard card in cards)
                      card.distributionId,
                  ],
                )
              : const <String, DistributionPricingCard>{};
      return buildDealerDistributionSummaryReport(
        period: request.period,
        distributions: cards,
        pricing: pricing,
        dealerNames: dealerNames,
        thousandsSeparator: separator,
      );

    case ReportId.cashSales:
      return buildCashSalesReport(
        period: request.period,
        sales: await _cashSales(directory, sources, request),
        thousandsSeparator: separator,
      );

    case ReportId.salesByItem:
      final List<DistributionCard> cards =
          await _distributions(directory, sources, request);
      final bool readsPricing =
          ref.watch(hasPermissionProvider(Permission.distributionPriceView));
      final Map<String, DistributionPricingCard> pricing = readsPricing
          ? await directory.distributionPricing(
              distributionIds: <String>[
                for (final DistributionCard card in cards) card.distributionId,
              ],
            )
          : const <String, DistributionPricingCard>{};
      return buildSalesByItemReport(
        period: request.period,
        distributions: cards,
        cashSales: await _cashSales(directory, sources, request),
        pricing: pricing,
        // ⛔⛔ **وعمودُ القيمة يظهر بالصلاحية لا بامتلاء الخريطة** — ★ **فترةٌ
        //    بلا توزيعاتٍ خريطتُها فارغة**، ⟵ **وإخفاءُ العمود حينها كان
        //    يُسقِط قيمةَ البيع النقدي وهي مقروءةٌ للجميع.**
        withValue: readsPricing,
        thousandsSeparator: separator,
      );

    case ReportId.unpricedLines:
      return buildUnpricedLinesReport(
        period: request.period,
        distributions: await _distributions(directory, sources, request),
        dealerNames: dealerNames,
        dealerId: request.dealerId,
      );

    case ReportId.discounts:
      final List<DiscountCard> cards = <DiscountCard>[
        for (final String sourceId in sources)
          ...await directory.discounts(
            sourceId: sourceId,
            period: request.period,
          ),
      ];
      return buildDiscountsReport(
        period: request.period,
        discounts: cards,
        sourceId: ref.watch(selectedReportSource),
        thousandsSeparator: separator,
      );

    case ReportId.cashMovement:
      return buildCashMovementReport(
        date: request.period.to,
        movement: await _cashMovement(ref, sources, request),
        readsDeposit:
            ref.watch(hasPermissionProvider(Permission.receiptDepositView)),
        thousandsSeparator: separator,
      );

    case ReportId.withdrawalCoverage:
      return buildWithdrawalCoverageReport(
        date: request.period.to,
        movement: await _cashMovement(ref, sources, request),
        thousandsSeparator: separator,
      );

    case ReportId.ownerLedgerDaily:
      return buildOwnerLedgerDailyReport(
        period: request.period,
        days: await _summaryDays(ref, directory, sources, request),
        visibility: ref.watch(ownerLedgerVisibilityProvider),
        thousandsSeparator: separator,
      );

    case ReportId.sourceNetImpact:
      return buildSourceNetImpactReport(
        period: request.period,
        days: await _summaryDays(ref, directory, sources, request),
        visibility: ref.watch(ownerLedgerVisibilityProvider),
        thousandsSeparator: separator,
      );

    case ReportId.withdrawals:
    case ReportId.expenses:
      final OutflowLedgerType ledgerType =
          request.report == ReportId.withdrawals
              ? OutflowLedgerType.withdrawal
              : OutflowLedgerType.expense;
      final List<OutflowCard> cards = <OutflowCard>[
        for (final String sourceId in sources)
          ...await directory.outflows(
            sourceId: sourceId,
            ledgerType: ledgerType,
            period: request.period,
          ),
      ];
      return buildOutflowLedgerReport(
        period: request.period,
        ledgerType: ledgerType,
        outflows: cards,
        category: request.outflowCategory,
        lineKind: request.outflowLineKind,
        thousandsSeparator: separator,
      );

    case ReportId.supplierAccount:
      return buildSupplierAccountReport(
        period: request.period,
        rows: await _supplierLedger(directory, sources, request),
        supplierId: request.supplierId,
        supplierNames: supplierNames,
        thousandsSeparator: separator,
      );

    case ReportId.supplierTax:
      return buildSupplierTaxReport(
        period: request.period,
        rows: await _supplierLedger(directory, sources, request),
        supplierId: request.supplierId,
        supplierNames: supplierNames,
        thousandsSeparator: separator,
      );

    case ReportId.sackPriceBreakdown:
      final String? sackId = request.sackId;
      if (sackId == null) return null;
      // ★★ **والجونيةُ تُقرأ من جوانيِّ الفترة نفسِها** — ⟵ **فمنها تاريخُ
      //    مخزونها ومصدرُها**: ⛔ **ولا يُبنى المسار من معرّفٍ مجرَّد**،
      //    ★ **و`loadSackContributions` تشترط الثلاثة معاً** (`GR-49`).
      final List<SackCard> sacks = <SackCard>[
        for (final String sourceId in sources)
          ...await directory.sacks(sourceId: sourceId, period: request.period),
      ];
      SackCard? selected;
      for (final SackCard sack in sacks) {
        if (sack.documentNumber == sackId) selected = sack;
      }
      if (selected == null) return null;
      final Outcome<List<SackRevenueContribution>> outcome = await ref
          .watch(sackValuationDirectoryProvider)
          .loadSackContributions(
            sackId: selected.documentNumber,
            sourceId: selected.sourceId,
            stockDate: selected.stockDate,
          );
      return switch (outcome) {
        Success<List<SackRevenueContribution>>(
          :final List<SackRevenueContribution> value
        ) =>
          buildSackPriceBreakdownReport(
            sackDisplayName: selected.displayName,
            contributions: value,
            thousandsSeparator: separator,
          ),
        // ⛔ **ورفضُ القراءة يصعد خطأً صريحاً** — ★ **فيُميِّز المستخدمُ بين
        //    «لا بيانات» و«ممنوعٌ من الرؤية»** (`FR-M18-12`).
        Failure<List<SackRevenueContribution>>(:final AppError error) =>
          throw _ReportFailure(error),
      };
  }
}

/// ★ سنداتُ البيع النقدي عبر مصادرَ مُعدَّدة.
Future<List<CashSaleCard>> _cashSales(
  ReportDirectory directory,
  List<String> sources,
  ReportRequest request,
) async =>
    <CashSaleCard>[
      for (final String sourceId in sources)
        ...await directory.cashSales(
          sourceId: sourceId,
          period: request.period,
        ),
    ];

/// ★ سطورُ دفتر الرعية عبر مصادرَ مُعدَّدة.
Future<List<SupplierLedgerRow>> _supplierLedger(
  ReportDirectory directory,
  List<String> sources,
  ReportRequest request,
) async =>
    <SupplierLedgerRow>[
      for (final String sourceId in sources)
        ...await directory.supplierLedger(
          sourceId: sourceId,
          period: request.period,
        ),
    ];

/// ★★★ حركةُ النقد في تاريخ التقرير — **بالقارئ نفسِه الذي تستعمله البطاقة**.
///
/// ⛔ **ولا نسخةَ ثانية من التجميع** (`coding-standards.md` §2.2) — ★ **وهو
/// خمسةُ استعلاماتٍ لكل مصدر** ⟵ **ولذلك التقريرُ يومٌ واحد** ([`DEBT-94`]).
Future<CashMovementProjection> _cashMovement(
  Ref ref,
  List<String> sources,
  ReportRequest request,
) async {
  final CashMovementSummary summary =
      await ref.watch(cashMovementReaderProvider).readCashMovement(
            sourceIds: sources,
            // ⛔⛔ **والفائضُ العام في «كل المصادر» وحدها** — `FR-M12-12`.
            includesUnscopedSurplus: request.allSources,
            date: request.period.to,
            readsDeposit:
                ref.watch(hasPermissionProvider(Permission.receiptDepositView)),
          );
  return projectCashMovement(summary, ref.watch(ownerLedgerVisibilityProvider));
}

/// ★★★ أيامُ الفترة مبنيّةً على صلاحيات قارئها — `R-20` · `R-23`.
///
/// ⛔⛔★★ **و«كل المصادر» تُجمَع من بطاقات مصادر القارئ يوماً بيوم** — ⛔ **لا
/// من مستند `all_{date}`** (`E-36` · `FR-M15-09`): ⟵ **فمن نطاقه مصدرٌ واحد
/// لا تدخل أرقامُ غيره تقريرَه**، ★ **والجمعُ خطّيٌّ يطابق جمعَ البطاقات بنداً
/// ببند** ([aggregateOwnerLedgerSummaries]).
Future<List<OwnerLedgerProjection>> _summaryDays(
  Ref ref,
  ReportDirectory directory,
  List<String> sources,
  ReportRequest request,
) async {
  final Map<CalendarDay, List<OwnerLedgerSummary>> byDay =
      <CalendarDay, List<OwnerLedgerSummary>>{};
  for (final String sourceId in sources) {
    for (final OwnerLedgerSummary summary in await directory.dailySummaries(
      sourceId: sourceId,
      period: request.period,
    )) {
      byDay.putIfAbsent(summary.date, () => <OwnerLedgerSummary>[]).add(summary);
    }
  }
  final OwnerLedgerVisibility visibility =
      ref.watch(ownerLedgerVisibilityProvider);
  return <OwnerLedgerProjection>[
    for (final MapEntry<CalendarDay, List<OwnerLedgerSummary>> day
        in byDay.entries)
      projectOwnerLedgerSummary(
        day.value.length == 1
            ? day.value.single
            : aggregateOwnerLedgerSummaries(
                date: day.key,
                summaries: day.value,
              ),
        visibility,
      ),
  ];
}

/// ★ رفضٌ صعد من طبقةٍ تُرجِع [Outcome] — ⛔ **ولا يُبتلَع في «لا بيانات»**.
///
/// ⚠️ **وموجودٌ لأن [_buildTable] يرمي ويُترجَم في مُستدعيه وحده** — ★ **فما
/// وصل نتيجةً يُعاد رمياً ثم يُفكّ في [_asAppError]**: ⛔ **بلا فحص نصٍّ
/// هشّ لرسالةٍ تقنية.**
final class _ReportFailure implements Exception {
  const _ReportFailure(this.error);

  final AppError error;
}

/// ★ أرصدةُ يومٍ عبر مصادرَ مُعدَّدة.
Future<List<ItemDailyBalanceCard>> _balances(
  ReportDirectory directory,
  List<String> sources,
  CalendarDay stockDate,
) async =>
    <ItemDailyBalanceCard>[
      for (final String sourceId in sources)
        ...await directory.dailyBalances(
          sourceId: sourceId,
          stockDate: stockDate,
        ),
    ];

/// ★ توزيعاتُ الفترة عبر مصادرَ مُعدَّدة — **بحالة التسوية إن طُلبت**.
Future<List<DistributionCard>> _distributions(
  ReportDirectory directory,
  List<String> sources,
  ReportRequest request,
) async =>
    <DistributionCard>[
      for (final String sourceId in sources)
        ...await directory.distributions(
          sourceId: sourceId,
          period: request.period,
          settlementStatus: request.settlementStatus,
        ),
    ];

/// ★ اسمُ النوع للترويسة — و`null` **حين لا فلترَ أصلاً**.
///
/// ⛔ **ولا يُعرَض مفتاحٌ تقني في شاشة** (`ui-guidelines.md` §6) — ★ **والاسمُ
/// يُبنى هنا مرةً** ⟵ **فيُصرِّح الفلترُ بنفسه ولو خلا الجدول من صفوفه.**
String? _itemNameOrNull(Ref ref, String? itemKey) =>
    itemKey == null ? null : _itemName(ref, itemKey);

/// ★ اسمُ النوع للعرض — ⛔ **والغائب يقع على مفتاحه لا على فراغ**.
String _itemName(Ref ref, String itemKey) {
  for (final ItemCard item
      in ref.read(itemsProvider).value ?? const <ItemCard>[]) {
    if (item.itemId == itemKey) return item.name;
  }
  return itemKey;
}

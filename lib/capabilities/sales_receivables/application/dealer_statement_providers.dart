/// مزوّدات **كشف حساب المقوت** (`M17` · `WU-017`).
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **ثلاثُ قواعدَ تحكم كلَّ رقمٍ يخرج من هنا:**
///
///   ① ★★★ **الكشفُ يُبنى من الدفتر حصراً** (`FR-M17-03` · `ADR-0008`) —
///      ⟵ **والمعادلاتُ كلُّها في [buildDealerStatement] بطبقة النطاق**:
///      ⛔ **وصفرُ حسابٍ هنا وصفرُ حسابٍ في الشاشة** (`design-system.md` §5.1).
///   ② ⛔⛔★★★ **والاستعلامُ مقيَّدٌ بالمصدر دائماً** (`IQ-024` · `DEBT-40`) —
///      ★ **شرطُ قراءة `dealer_ledger` يعتمد `resource.data.sourceId`**:
///      ⟵ **واستعلامٌ لا يُقيّده يُرفَض كاملاً ولو ملك القارئ كل المفاتيح.**
///      ⟹ **فـ«كل المصادر» استعلامٌ لكل مصدرٍ ثم دمجٌ في الذاكرة** ⛔ **لا
///      استعلامٌ واحدٌ غيرُ مقيَّد** (نفسُ ما فعله `WU-008` حرفياً).
///   ③ ⚠️⚠️ **وكلُّ بوابةٍ هنا إخفاءٌ لا حماية** (`RISK-02`) — ★ **والحارسُ
///      الحقيقي `perm('dealerBalanceView')` + النطاق في `firestore.rules`**،
///      ⛔ **ومفتاحا `IQ-040` بوابتا شاشةٍ لا حارسا سريّة.**
/// ═══════════════════════════════════════════════════════════════════════
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qtms_domain/qtms_domain.dart';

import '../../identity_access/application/session_providers.dart';
import '../../inventory/application/inventory_providers.dart';
import '../../master_data/application/master_data_providers.dart';
import '../../oversight/application/report_providers.dart';
import 'receipt_providers.dart';

/// ★ المقوت المختار — و`null` **قبل الاختيار**.
final NotifierProvider<DealerStatementDealer, String?> statementDealerProvider =
    NotifierProvider<DealerStatementDealer, String?>(DealerStatementDealer.new);

/// حالةُ اختيار المقوت.
class DealerStatementDealer extends Notifier<String?> {
  @override
  String? build() => null;

  /// يختار المقوت.
  void select(String? dealerId) => state = dealerId;
}

/// ★★ المصدرُ المختار — و`null` تعني **«كل المصادر»** (`FR-M17-01`).
///
/// ⛔⛔ **و«الكل» هنا عرضٌ مجمَّعٌ ببيان كل مصدر** (`FR-M17-04`) — ★ **ولا
/// يُنشئ رصيداً موحّداً في الدفاتر**: ⟵ **فـ`A-01` لم تُمَسّ** (**تمنع الجمع
/// في *عملية* لا في *سرد***).
final NotifierProvider<DealerStatementSource, String?> statementSourceProvider =
    NotifierProvider<DealerStatementSource, String?>(DealerStatementSource.new);

/// حالةُ اختيار المصدر.
class DealerStatementSource extends Notifier<String?> {
  @override
  String? build() => null;

  /// يختار المصدر — و`null` **«كل المصادر»**.
  void select(String? sourceId) => state = sourceId;
}

/// ★ نمطُ العرض — **والافتراضي بالضمارات** (`FR-M17-02`).
final NotifierProvider<DealerStatementLayoutMode, DealerStatementLayout>
    statementViewProvider =
    NotifierProvider<DealerStatementLayoutMode, DealerStatementLayout>(
        DealerStatementLayoutMode.new);

/// حالةُ نمط العرض.
class DealerStatementLayoutMode extends Notifier<DealerStatementLayout> {
  @override
  DealerStatementLayout build() => DealerStatementLayout.lots;

  /// يبدّل النمط.
  void select(DealerStatementLayout view) => state = view;
}

/// ★ خيارُ «عرض الملغى» — **مطفأٌ افتراضياً** (`FR-M17-06`).
///
/// ⛔⛔ **والملغاةُ خارجَ الأرصدة في الحالتين** — ★ **والخيارُ يُظهرها مشطوبةً
/// وحسب**: ⟵ **فلا يُغيِّر رقماً واحداً** (`A-14`).
final NotifierProvider<DealerStatementCancelled, bool>
    statementShowCancelledProvider =
    NotifierProvider<DealerStatementCancelled, bool>(
        DealerStatementCancelled.new);

/// حالةُ إظهار الملغى.
class DealerStatementCancelled extends Notifier<bool> {
  @override
  bool build() => false;

  /// يبدّل الإظهار.
  void toggle() => state = !state;
}

/// ★ الفترةُ المعروضة — **والافتراضيُّ آخرُ ثلاثين يوماً حتى اليوم**.
///
/// ⚠️⚠️ **وهي على `entryDate` لا `stockDate`** — ★ **دفترُ المقاوته دفترٌ
/// ماليٌّ لا مخزني** (`ReportDirectory.dealerStatement` · `schema/dealer-ledger.md`):
/// ⛔ **ولا `stockDate` في قيده أصلاً.**
final NotifierProvider<DealerStatementPeriod, ReportPeriod?>
    statementPeriodProvider =
    NotifierProvider<DealerStatementPeriod, ReportPeriod?>(
        DealerStatementPeriod.new);

/// حالةُ الفترة.
class DealerStatementPeriod extends Notifier<ReportPeriod?> {
  @override
  ReportPeriod? build() => null;

  /// ★ يضبط الفترة — ⛔ **والمدى المقلوب يُهمَل ولا يُقلَب ضمناً**
  /// ([ReportPeriod.of] **تُرجِع `null`**).
  void select({required CalendarDay from, required CalendarDay to}) {
    final ReportPeriod? period = ReportPeriod.of(from: from, to: to);
    if (period != null) state = period;
  }
}

/// ★ الفترةُ الفعّالة — **المختارةُ أو آخرُ ثلاثين يوماً**.
final Provider<ReportPeriod> effectiveStatementPeriodProvider =
    Provider<ReportPeriod>((Ref ref) {
  final ReportPeriod? chosen = ref.watch(statementPeriodProvider);
  if (chosen != null) return chosen;
  final CalendarDay today = ref.watch(todayProvider);
  CalendarDay from = today;
  for (int i = 0; i < 30; i++) {
    from = from.previousDay();
  }
  return ReportPeriod.of(from: from, to: today) ??
      ReportPeriod.singleDay(today);
});

/// ★★ المصادرُ المشمولة في الاستعلام — **مُعدَّدةٌ دائماً** (القاعدة ② أعلاه).
///
/// ⛔ **ومصادرُ نطاق المستخدم وحدها** — `FR-M17-09` · `GR-23` · `E-35`:
/// ⟵ **فلا يظهر في الكشف رقمٌ من مصدرٍ خارج نطاقه.**
final Provider<List<String>> statementSourceIdsProvider =
    Provider<List<String>>((Ref ref) {
  final String? selected = ref.watch(statementSourceProvider);
  final List<SourceCard> sources = ref.watch(activeSourcesProvider);
  final AuthSession? session = ref.watch(currentSessionProvider);
  final List<String> inScope = <String>[
    for (final SourceCard source in sources)
      if (session?.canAccessSource(source.sourceId) ?? false) source.sourceId,
  ];
  if (selected == null) return List<String>.unmodifiable(inScope);
  // ⛔ **ومصدرٌ خارج النطاق لا يُستعلَم عنه** — ★ **لا لأن القاعدة سترفضه
  //    فحسب، بل لأن استعلاماً مرفوضاً يُسقِط الشاشةَ كلَّها بخطأ.**
  return List<String>.unmodifiable(
    inScope.contains(selected) ? <String>[selected] : const <String>[],
  );
});

/// ★★ **هل يرى المستخدمُ خيار «كل المصادر»؟** — `IQ-040` الخيار أ.
///
/// ⛔ **ومفتاحٌ مستقلٌّ فوق النطاق** — ★ **نظيرُ `allSourcesCardView` حرفياً**
/// (الكتالوج §2.7): ⟵ **فمن نطاقُه شاملٌ ولا يملك المفتاح لا يرى الخيار.**
final Provider<bool> canViewAllSourcesStatementProvider =
    Provider<bool>((Ref ref) =>
        ref.watch(hasPermissionProvider(Permission.dealerStatementAllSources)));

/// وسيطُ بناء الكشف — **المقوت والمصادر والفترة معاً**.
final class DealerStatementQuery {
  /// ينشئ الوسيط.
  DealerStatementQuery({
    required this.dealerId,
    required List<String> sourceIds,
    required this.period,
  }) : sourceIds = List<String>.unmodifiable(sourceIds);

  /// المقوت.
  final String dealerId;

  /// ★ المصادر — **مُعدَّدةٌ دائماً** ⛔ **ولا `null` تعني «الكل»**.
  final List<String> sourceIds;

  /// الفترة — **على تاريخ الإدخال**.
  final ReportPeriod period;

  @override
  bool operator ==(Object other) {
    if (other is! DealerStatementQuery) return false;
    if (other.dealerId != dealerId) return false;
    if (other.period.from != period.from || other.period.to != period.to) {
      return false;
    }
    if (other.sourceIds.length != sourceIds.length) return false;
    for (int i = 0; i < sourceIds.length; i++) {
      if (other.sourceIds[i] != sourceIds[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
        dealerId,
        period.from,
        period.to,
        Object.hashAll(sourceIds),
      );
}

/// ⛅ **قيودُ الدفتر للمقوت في المصادر المطلوبة** — **استعلامٌ لكل مصدر**.
final dealerLedgerEntriesProvider = FutureProvider.family<
    List<DealerLedgerRowCard>, DealerStatementQuery>((
  Ref ref,
  DealerStatementQuery query,
) async {
  final ReportDirectory directory = ref.watch(reportDirectoryProvider);
  return <DealerLedgerRowCard>[
    for (final String sourceId in query.sourceIds)
      ...await directory.dealerStatement(
        dealerId: query.dealerId,
        sourceId: sourceId,
        period: query.period,
      ),
  ];
});

/// ★★★ **الكشفُ المبنيّ** — ⛔ **و`null` قبل اختيار المقوت** (لا كشفٌ فارغ).
///
/// ★ **والفائضُ يُقرأ بنطاقه الصحيح:** ⟵ **فائضُ مصدرٍ لمصدرٍ مختار، وفائضٌ
/// عامٌّ لـ«الكل»** (`FR-M12-12` · `E-13`) — ⛔ **ولا يُجمَع النوعان.**
final dealerStatementProvider =
    FutureProvider.autoDispose<DealerStatement?>((Ref ref) async {
  final String? dealerId = ref.watch(statementDealerProvider);
  if (dealerId == null) return null;

  final List<String> sourceIds = ref.watch(statementSourceIdsProvider);
  final ReportPeriod period = ref.watch(effectiveStatementPeriodProvider);
  final String? selectedSource = ref.watch(statementSourceProvider);

  final List<DealerLedgerRowCard> ledger = await ref.watch(
    dealerLedgerEntriesProvider(
      DealerStatementQuery(
        dealerId: dealerId,
        sourceIds: sourceIds,
        period: period,
      ),
    ).future,
  );

  final Money surplus = ref.watch(
        availableSurplusProvider(
          SurplusQuery(
            dealerId: dealerId,
            scope: selectedSource == null
                ? SurplusScope.general
                : SurplusScope.source,
            sourceId: selectedSource,
          ),
        ),
      ).value ??
      Money.zero;

  final DealerCard? dealer = ref
      .watch(dealersProvider)
      .value
      ?.where((DealerCard card) => card.dealerId == dealerId)
      .firstOrNull;

  // ★★ **والبناءُ كلُّه في طبقة النطاق** — ⛔ **ولا معادلةَ هنا** (`ADR-0009`).
  return buildDealerStatement(
    dealerName: dealer?.name ?? dealerId,
    dealerCode: dealer?.dealerId,
    dealerPhone: dealer?.phone,
    sourceIds: sourceIds,
    ledger: ledger,
    issuedOn: ref.watch(todayProvider),
    availableSurplus: surplus,
  );
});

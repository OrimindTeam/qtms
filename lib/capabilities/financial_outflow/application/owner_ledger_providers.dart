/// مزوّدات ضمار المالك وحركة النقد (`WU-016`).
///
/// ★ **بنفس نمط `outflow_providers.dart`:** المستودعات **تُحقَن في الجذر
/// ولا تُبنى هنا** (`ADR-0010`) — ⟵ **فتُختبَر الشاشات بلا سحابة ولا شبكة**.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **والبطاقةُ تُبنى حسب صلاحيات قارئها هنا** — ★ **في هذه الطبقة
/// وحدها** (`owner-ledger-summary-design.md` §5): ⟵ **فالشاشةُ تستقبل
/// نصوصاً منسَّقةً جاهزة** ⛔ **ولا تعرف صلاحيةً ولا تحسب رقماً**
/// (`design-system.md` §5.1).
///
/// ⚠️⚠️ **وكلُّ ما هنا عرضٌ لا تفويض:** ★ **الحمايةُ الحقيقية شرطُ القراءة
/// في `firestore.rules`** — `RISK-02`: ⛔ **ولا يُكتفى بإخفاء بندٍ أبداً.**
///
/// ⛔⛔★★★ **وبطاقةُ «كل المصادر» تُبنى من بطاقات مصادر القارئ لا من المستند
/// التجميعي** إلا لصاحب النطاق الشامل — ★ **وهو ما تفرضه القاعدة نفسُها بعد
/// `WU-016`**: ⟵ **فمن نطاقه «رداع» لا تدخل أرقامُ «ماوية» في «الكل» عنده**
/// (`FR-M15-09` · `E-36`).
/// ═══════════════════════════════════════════════════════════════════════
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qtms_domain/qtms_domain.dart';

import '../../../core/state/combine_async.dart';
import '../../identity_access/application/session_providers.dart';
import '../../master_data/application/master_data_providers.dart';

/// دليل ضمار المالك — ⛔ **يُحقَن في الجذر**.
final Provider<OwnerLedgerDirectory> ownerLedgerDirectoryProvider =
    Provider<OwnerLedgerDirectory>((Ref ref) {
  throw UnimplementedError('ownerLedgerDirectoryProvider يجب تجاوزه عند الجذر');
});

/// قارئ حركة النقد — ⛔ **يُحقَن في الجذر**.
final Provider<CashMovementReader> cashMovementReaderProvider =
    Provider<CashMovementReader>((Ref ref) {
  throw UnimplementedError('cashMovementReaderProvider يجب تجاوزه عند الجذر');
});

/// ★ **اليومُ المعروض** — **اليومَ افتراضاً** (`FR-M15-22`).
///
/// ⛔⛔ **وهو يومُ عرضٍ لا يومٌ يُكتب** — ★ **فكلُّ ما يُخزَّن يومُه من المنصّة**
/// (`GR-54` · `E-41`): ⟵ **وهذه شاشةُ قراءةٍ لا تكتب حرفاً.**
final NotifierProvider<OwnerLedgerDay, CalendarDay> ownerLedgerDayProvider =
    NotifierProvider<OwnerLedgerDay, CalendarDay>(OwnerLedgerDay.new);

/// حالةُ اليوم المعروض.
class OwnerLedgerDay extends Notifier<CalendarDay> {
  @override
  CalendarDay build() => CalendarDay.fromUtc(DateTime.now().toUtc());

  /// يختار يوماً للعرض.
  void select(CalendarDay date) => state = date;
}

/// ★ **المصدرُ المعروض** — و`null` تعني «كل المصادر» (`FR-M15-02`).
final NotifierProvider<OwnerLedgerSource, String?> ownerLedgerSourceProvider =
    NotifierProvider<OwnerLedgerSource, String?>(OwnerLedgerSource.new);

/// حالةُ المصدر المعروض.
///
/// ⛔ **و«كل المصادر» افتراضاً بخلاف شاشة المخزون** — ★ **فبطاقةُ الضمار
/// تُعرَض للكل ثم تُفصَّل** (`ui-guidelines.md` نمط 1 ③ ثم ④)، ⟵ **وهو عكسُ
/// `selectedSourceProvider`**: ★ **تلك عمليةٌ تكتب في مصدرٍ بعينه** (`A-01`)
/// ⛔ **وهذه قراءةٌ لا تكتب حرفاً.**
class OwnerLedgerSource extends Notifier<String?> {
  @override
  String? build() => null;

  /// يختار مصدراً — و`null` تعني «كل المصادر».
  void select(String? sourceId) => state = sourceId;
}

/// ★★ **ما يراه هذا القارئ من البندين المحكومين** — `FR-M15-10` · `E-29`.
final Provider<OwnerLedgerVisibility> ownerLedgerVisibilityProvider =
    Provider<OwnerLedgerVisibility>(
  (Ref ref) => OwnerLedgerVisibility(
    showsWithdrawals: ref.watch(hasPermissionProvider(Permission.withdrawalView)),
    showsExpenses: ref.watch(hasPermissionProvider(Permission.expenseView)),
  ),
);

/// ★ **مصادرُ القارئ التي تدخل بطاقة «الكل» عنده** — `E-36`.
///
/// ⛔ **وتُقرأ من `sources` لا من الرمز** — ★ **فالقاعدة تُرشِّحها بالنطاق
/// أصلاً** (`master_data_providers.dart`): ⟵ **ولا ترشيحَ في الجهاز.**
final Provider<List<String>> ownerLedgerScopeProvider = Provider<List<String>>(
  (Ref ref) => <String>[
    for (final SourceCard source in ref.watch(sourcesProvider).value ??
        const <SourceCard>[])
      source.sourceId,
  ],
);

/// ★ هل نطاقُ القارئ شاملٌ لكل المصادر؟ — ⟵ **وهو وحده يقرأ `all_{date}`**.
final Provider<bool> hasAllSourcesScopeProvider = Provider<bool>(
  (Ref ref) => ref.watch(currentSessionProvider)?.sourceScope is AllSources,
);

/// ⛅ ملخّصُ مصدرٍ في اليوم المعروض.
final ownerLedgerSummaryProvider =
    StreamProvider.family<OwnerLedgerSummary?, String>(
  (Ref ref, String sourceId) =>
      ref.watch(ownerLedgerDirectoryProvider).watchSummary(
            sourceId: sourceId,
            date: ref.watch(ownerLedgerDayProvider),
          ),
);

/// ⛅★★★ **البطاقةُ المعروضة** — **مصدرٌ بعينه أو مجموعُ بطاقات مصادر القارئ**.
///
/// ⛔⛔ **ولا تُقرأ `all_{date}` إلا لصاحب النطاق الشامل** — راجع ترويسة الملف.
final Provider<AsyncValue<OwnerLedgerProjection?>> ownerLedgerCardProvider =
    Provider<AsyncValue<OwnerLedgerProjection?>>((Ref ref) {
  final CalendarDay date = ref.watch(ownerLedgerDayProvider);
  final OwnerLedgerVisibility visibility =
      ref.watch(ownerLedgerVisibilityProvider);
  final String? sourceId = ref.watch(ownerLedgerSourceProvider);

  if (sourceId != null) {
    return ref.watch(ownerLedgerSummaryProvider(sourceId)).whenData(
          (OwnerLedgerSummary? summary) => summary == null
              ? null
              : projectOwnerLedgerSummary(summary, visibility),
        );
  }

  if (ref.watch(hasAllSourcesScopeProvider)) {
    return ref.watch(ownerLedgerSummaryProvider(allSourcesScopeId)).whenData(
          (OwnerLedgerSummary? summary) => summary == null
              ? null
              : projectOwnerLedgerSummary(summary, visibility),
        );
  }

  // ★★ **ومن نطاقه مصادرُ بعينها يجمعها هنا** — `aggregateOwnerLedgerSummaries`
  //    هي المعادلةُ نفسُها التي بنت المستندَ التجميعي في السحابة (`ADR-0012`).
  final List<String> sources = ref.watch(ownerLedgerScopeProvider);
  if (sources.isEmpty) return const AsyncValue<OwnerLedgerProjection?>.data(null);

  return combineAsync<OwnerLedgerSummary?>(
    <AsyncValue<OwnerLedgerSummary?>>[
      for (final String source in sources)
        ref.watch(ownerLedgerSummaryProvider(source)),
    ],
  ).whenData(
    (List<OwnerLedgerSummary?> summaries) => projectOwnerLedgerSummary(
      aggregateOwnerLedgerSummaries(
        date: date,
        summaries: <OwnerLedgerSummary>[
          for (final OwnerLedgerSummary? summary in summaries) ?summary,
        ],
      ),
      visibility,
    ),
  );
});

/// ⛅ سلسلةُ آخر سبعةِ أيام للنطاق المعروض — `IQ-030`.
///
/// ⛔ **ولمن لا يملك النطاق الشامل: سلسلةُ مصدرِه وحدَه** — ★ **ولا رسمَ
/// «كل» يُجمَع من سبع سلاسل**: ⟵ **فذلك سبعُ قراءاتٍ في كل فتحة** ⛔ **وهو
/// ما وُجد هذا السجل لتفاديه** (§8).
final Provider<AsyncValue<List<OwnerLedgerTrendPoint>>> ownerLedgerTrendProvider =
    Provider<AsyncValue<List<OwnerLedgerTrendPoint>>>((Ref ref) {
  final String? sourceId = ref.watch(ownerLedgerSourceProvider);
  final String scope = sourceId ??
      (ref.watch(hasAllSourcesScopeProvider) ? allSourcesScopeId : '');
  if (scope.isEmpty) {
    final List<String> sources = ref.watch(ownerLedgerScopeProvider);
    if (sources.length != 1) {
      return const AsyncValue<List<OwnerLedgerTrendPoint>>.data(
        <OwnerLedgerTrendPoint>[],
      );
    }
    return ref.watch(ownerLedgerTrendFamilyProvider(sources.single));
  }
  return ref.watch(ownerLedgerTrendFamilyProvider(scope));
});

/// ⛅ سلسلةُ مصدرٍ بعينه.
final ownerLedgerTrendFamilyProvider =
    StreamProvider.family<List<OwnerLedgerTrendPoint>, String>(
  (Ref ref, String sourceId) =>
      ref.watch(ownerLedgerDirectoryProvider).watchTrend(sourceId: sourceId),
);

/// ★ مدى سجل الأيام السابقة — `FR-M15-14`.
final class OwnerLedgerRange {
  /// ينشئ المدى.
  const OwnerLedgerRange({
    required this.sourceId,
    required this.from,
    required this.to,
  });

  /// المصدر — ⛔ **إلزاميٌّ** (شرطُ القراءة يعتمده).
  final String sourceId;

  /// أولُ يومٍ في المدى.
  final CalendarDay from;

  /// آخرُ يومٍ في المدى.
  final CalendarDay to;

  @override
  bool operator ==(Object other) =>
      other is OwnerLedgerRange &&
      other.sourceId == sourceId &&
      other.from == from &&
      other.to == to;

  @override
  int get hashCode => Object.hash(sourceId, from, to);
}

/// ⛅ سجلُّ الأيام السابقة لمصدرٍ في مدى — `FR-M15-14`.
final ownerLedgerHistoryProvider =
    StreamProvider.family<List<OwnerLedgerSummary>, OwnerLedgerRange>(
  (Ref ref, OwnerLedgerRange range) =>
      ref.watch(ownerLedgerDirectoryProvider).watchSummaryRange(
            sourceId: range.sourceId,
            from: range.from,
            to: range.to,
          ),
);

/// ⛅★★ حركةُ النقد في اليوم المعروض — `FR-M15-15` … `FR-M15-21`.
///
/// ⛔⛔★★★ **و`autoDispose` إلزاميّة** — [`DEBT-90`] (2026-09-03):
/// ★ **قراءةٌ عند الطلب بلا `autoDispose` تُخزِّن نتيجتَها بمفتاح العائلة**،
/// ⟹ **فتعرض رقمَ صندوقٍ قديماً بعد حركةٍ حقيقية** — ⛔ **مخالفةٌ لـ`ADR-0008`.**
final cashMovementProvider =
    FutureProvider.autoDispose.family<CashMovementSummary, CalendarDay>(
  (Ref ref, CalendarDay date) {
    final String? sourceId = ref.watch(ownerLedgerSourceProvider);
    final List<String> sources = sourceId != null
        ? <String>[sourceId]
        : ref.watch(ownerLedgerScopeProvider);
    return ref.watch(cashMovementReaderProvider).readCashMovement(
          sourceIds: sources,
          // ★ **والفائضُ العام في «كل المصادر» وحدها** — `FR-M12-12`.
          includesUnscopedSurplus: sourceId == null,
          date: date,
          readsDeposit:
              ref.watch(hasPermissionProvider(Permission.receiptDepositView)),
        );
  },
);

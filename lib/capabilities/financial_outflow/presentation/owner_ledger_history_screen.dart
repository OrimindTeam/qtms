/// شاشة **سجل ضمار المالك للأيام السابقة** (`FR-M15-14`) — **نمط 2**.
///
/// ★ **ولماذا شاشةٌ مستقلة لا قسمٌ في الرئيسية:** `ui-guidelines.md` نمط 1
/// يستثني «**سجلَّ ضمار المالك للأيام السابقة**» من الرئيسية نصّاً —
/// ★ **استقصائيٌّ لا يوميّ**، ⟵ **ومكانُه «المزيد».**
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **والسجلُّ لمصدرٍ بعينه دائماً** — ★ **شرطُ قراءة `daily_summaries`
/// يعتمد `resource.data.sourceId`** (`storedInScope()`): ⟵ **والشرط يُقيَّم
/// على قيود الاستعلام لا على كل مستند** (`IQ-024` · `WU-008` · `DEBT-40`)،
/// ⛔ **فسردٌ بلا مصدرٍ مُقيَّد يُرفَض كاملاً ولو ملك القارئُ كلَّ المفاتيح.**
///
/// ⛔⛔ **والبندُ المحكومُ بصلاحيةٍ يخرج من كل صفٍّ هنا كما يخرج من البطاقة**
/// (§5 · `E-29`) — ★ **بالإسقاط نفسِه** [projectOwnerLedgerSummary].
/// ═══════════════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qtms_domain/qtms_domain.dart';

import '../../../app/top_bar.dart';
import '../../../core/design/design_tokens.dart';
import '../../../core/ui/async_state_view.dart';
import '../../../core/ui/date_labels.dart';
import '../../../core/ui/filter_bar.dart';
import '../../../core/ui/key_value_row.dart';
import '../application/owner_ledger_providers.dart';
import 'owner_ledger_format.dart';

/// عنوان الشاشة — ★ **مصدرٌ واحد يقرؤه الشريطُ والمدخلُ والاختبار**.
const String ownerLedgerHistoryScreenTitle = 'سجل الأيام السابقة';

/// مدى السجل المعروض — `FR-M15-14` (**الكل / من–إلى**).
enum OwnerLedgerHistorySpan {
  /// آخر سبعة أيام.
  week(7, 'آخر ٧ أيام'),

  /// آخر ثلاثين يوماً.
  month(30, 'آخر ٣٠ يوماً'),

  /// آخر تسعين يوماً — ★ **وهو «الكل» العملي**.
  ///
  /// ⛔⛔ **ولا «كل الأيام» بلا حدّ** — ★ **فالسردُ غيرُ المحدود يُنتج قراءةً
  /// تنمو بلا سقف** (`NFR-PERF-04`)، ⟵ **والحدُّ معلَنٌ في الواجهة**
  /// ⛔ **لا مخفيٌّ يُوهم بأن ما ظهر هو الكل.**
  quarter(90, 'آخر ٩٠ يوماً');

  const OwnerLedgerHistorySpan(this.days, this.label);

  /// عددُ الأيام.
  final int days;

  /// التسمية المعروضة.
  final String label;
}

/// حالةُ المدى المختار.
final NotifierProvider<OwnerLedgerHistoryFilter, OwnerLedgerHistorySpan>
    ownerLedgerHistorySpanProvider =
    NotifierProvider<OwnerLedgerHistoryFilter, OwnerLedgerHistorySpan>(
  OwnerLedgerHistoryFilter.new,
);

/// مرشِّحُ المدى.
class OwnerLedgerHistoryFilter extends Notifier<OwnerLedgerHistorySpan> {
  @override
  OwnerLedgerHistorySpan build() => OwnerLedgerHistorySpan.week;

  /// يختار مدىً.
  void select(OwnerLedgerHistorySpan span) => state = span;
}

/// شاشة سجل الأيام السابقة.
class OwnerLedgerHistoryScreen extends ConsumerWidget {
  /// ينشئ الشاشة.
  const OwnerLedgerHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? sourceId = ref.watch(ownerLedgerSourceProvider);
    final OwnerLedgerHistorySpan span =
        ref.watch(ownerLedgerHistorySpanProvider);

    return Scaffold(
      appBar: const QtmsTopBar(screenTitle: ownerLedgerHistoryScreenTitle),
      body: sourceId == null
          ? const QtmsEmptyState(spec: _noSourceSpec)
          : Column(
              children: <Widget>[
                QtmsFilterBar(
                  groups: <List<QtmsFilterOption>>[
                    <QtmsFilterOption>[
                      for (final OwnerLedgerHistorySpan option
                          in OwnerLedgerHistorySpan.values)
                        QtmsFilterOption(
                          label: option.label,
                          selected: option == span,
                          onSelected: () => ref
                              .read(ownerLedgerHistorySpanProvider.notifier)
                              .select(option),
                        ),
                    ],
                  ],
                ),
                Expanded(
                  child: _HistoryList(sourceId: sourceId, span: span),
                ),
              ],
            ),
    );
  }
}

const EmptyStateSpec _noSourceSpec = EmptyStateSpec(
  icon: Icons.filter_alt_outlined,
  title: 'اختر مصدراً أولاً',
  message: 'سجل الأيام يُعرَض لمصدرٍ واحد — والمصدر يُختار من شاشة ضمار المالك.',
);

class _HistoryList extends ConsumerWidget {
  const _HistoryList({required this.sourceId, required this.span});

  final String sourceId;
  final OwnerLedgerHistorySpan span;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CalendarDay today = ref.watch(ownerLedgerDayProvider);
    CalendarDay from = today;
    for (int i = 0; i < span.days; i++) {
      from = from.previousDay();
    }
    final OwnerLedgerVisibility visibility =
        ref.watch(ownerLedgerVisibilityProvider);

    return AsyncStateView<OwnerLedgerSummary>(
      value: ref.watch(
        ownerLedgerHistoryProvider(
          OwnerLedgerRange(sourceId: sourceId, from: from, to: today),
        ),
      ),
      empty: const EmptyStateSpec(
        icon: Icons.event_busy_outlined,
        title: 'لا أيام في هذا المدى',
        message: 'لم تُسجَّل حركةٌ لهذا المصدر في المدى المختار.',
      ),
      // ★ **الخطأ يُعرَض ولا يُطوى في «فارغ»** — ⟵ **فيُميِّز المستخدم بين
      //   «لا أيام» و«ممنوعٌ من الرؤية»** (نفسُ صياغة بقية الشاشات).
      errorMessage: (Object _) =>
          'تحقق من صلاحيتك ونطاق مصادرك، ثم أعد المحاولة.',
      builder: (List<OwnerLedgerSummary> items) => ListView.builder(
        padding: const EdgeInsets.all(Spacing.cardPadding),
        itemCount: items.length,
        itemBuilder: (BuildContext context, int index) => _DayTile(
          projection: projectOwnerLedgerSummary(items[index], visibility),
        ),
      ),
    );
  }
}

class _DayTile extends StatelessWidget {
  const _DayTile({required this.projection});

  final OwnerLedgerProjection projection;

  @override
  Widget build(BuildContext context) {
    final OwnerLedgerSummary s = projection.summary;
    return Container(
      margin: const EdgeInsets.only(bottom: Spacing.space8),
      padding: const EdgeInsets.all(Spacing.space12),
      decoration: BoxDecoration(
        color: SemanticColors.surface,
        border: Border.all(
          color: SemanticColors.border,
          width: Sizes.borderWidth,
        ),
        borderRadius: BorderRadius.circular(Radii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  dayLabel(s.date),
                  style: TypeScale.titleSm
                      .copyWith(color: SemanticColors.textPrimary),
                ),
              ),
              // ★ **ووسمُ الأثر الرجعي يظهر في كل تقريرٍ يخصّ ذلك اليوم** —
              //   `FR-M15-12` · §7.
              if (s.retroUpdatedAt != null)
                Text(
                  '⟳ مُحدَّث بأثر رجعي',
                  style: TypeScale.caption
                      .copyWith(color: SemanticTriads.info.ink),
                ),
            ],
          ),
          const SizedBox(height: Spacing.space8),
          QtmsKeyValueRow(
            label: 'إجمالي الضمار',
            value: formatRiyals(s.totalDebt),
            numeric: true,
          ),
          QtmsKeyValueRow(
            label: 'باقي الضمار قبل الخصم',
            value: formatRiyals(s.remainingBeforeDiscount),
            numeric: true,
          ),
          QtmsKeyValueRow(
            label: 'باقي الضمار بعد الخصم',
            value: formatRiyals(s.remainingAfterDiscount),
            numeric: true,
          ),
          if (projection.withdrawals case final Money amount)
            QtmsKeyValueRow(
              label: 'السحبيات',
              value: formatRiyals(amount),
              numeric: true,
            ),
          if (projection.expenses case final Money amount)
            QtmsKeyValueRow(
              label: 'الخرجيات',
              value: formatRiyals(amount),
              numeric: true,
            ),
          QtmsKeyValueRow(
            label: 'الصافي النهائي',
            value: '${formatRiyals(projection.netFinal)} $riyalLabel',
            numeric: true,
          ),
        ],
      ),
    );
  }
}

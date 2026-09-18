/// شاشة **ضمار المالك وحركة النقد** (`M15`) — **نمط 1** (`ui-guidelines.md`
/// §3): ★ **بطاقةٌ رئيسيةٌ واحدة، ثم رسمُ السلسلة، ثم حركةُ النقد بطاقةً
/// مستقلة تحتها.**
///
/// ★ **المصدر:** `FR-M15-01` … `FR-M15-23` · `owner-ledger-summary-design.md` ·
/// `design-overview.md` §2.8 و§2.9 · `design-system.md` §7.1 ·
/// `design-tokens.md` · `ui-guidelines.md` **نمط 1** (بروتوكول التشغيل §ح).
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **أربع قواعدَ تحكم كل رقمٍ في هذه الشاشة:**
///
///   ① ★★★ **صفرُ حسابٍ هنا** (`design-system.md` §5.1) — ⟵ **المعادلاتُ
///      العشرُ في طبقة النطاق وتُبنى في السحابة** (`ADR-0008` · `ADR-0012`):
///      ★ **والشاشةُ تستقبل نصوصاً منسَّقةً جاهزة** ⛔ **لا أعداداً خام.**
///   ② ⛔⛔ **والبندُ المحكومُ بصلاحيةٍ لا يُرسَم إطلاقاً** — `E-29` · §5:
///      ★ **والإسقاطُ في `owner_ledger_providers.dart`** ⛔ **لا هنا.**
///   ③ ⛔⛔★★★ **و«حركة النقد» بطاقةٌ مستقلة لا تُدمَج في بطاقة الضمار**
///      (`ui-guidelines.md` نمط 1 · القرار 1) — ★ **ومعها سطرٌ يشرح الفرق
///      بين «الواصل» و«المقبوض»**: ⟵ **ودمجُهما هو بالضبط الخطأُ الذي بُنيت
///      `M15` لمنعه** (`AT-49` · `GR-41`).
///   ④ ★ **ويومٌ بلا حركةٍ يُعرَض بأصفارٍ صريحة لا شرطات** — ⟵ **لأن الصفرَ
///      هنا معلومة** (`ui-guidelines.md` نمط 1 · §9).
/// ═══════════════════════════════════════════════════════════════════════
///
/// ⚠️⚠️ **وكلُّ بوابةٍ هنا إخفاءٌ لا حماية** — ★ **ويقابلها شرطُ قراءةٍ في
/// `firestore.rules`** (`ownerLedgerView` · `allSourcesCardView` مع النطاق)
/// — `RISK-02`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qtms_domain/qtms_domain.dart';

import '../../../app/router.dart';
import '../../../app/top_bar.dart';
import '../../../core/design/design_tokens.dart';
import '../../../core/messages/error_messages.dart';
import '../../../core/ui/async_state_view.dart';
import '../../../core/ui/context_header.dart';
import '../../../core/ui/date_labels.dart';
import '../../../core/ui/inline_banner.dart';
import '../../master_data/application/master_data_providers.dart';
import '../application/owner_ledger_providers.dart';
import 'cash_movement_card.dart';
import 'owner_ledger_actions.dart';
import 'owner_ledger_card.dart';
import 'owner_ledger_format.dart';
import 'owner_ledger_trend_chart.dart';

/// عنوان الشاشة — ★ **مصدرٌ واحد يقرؤه الشريطُ والمدخلُ والاختبار**.
const String ownerLedgerScreenTitle = 'ضمار المالك';

/// شاشة ضمار المالك وحركة النقد.
class OwnerLedgerScreen extends ConsumerWidget {
  /// ينشئ الشاشة.
  const OwnerLedgerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CalendarDay day = ref.watch(ownerLedgerDayProvider);
    final String? sourceId = ref.watch(ownerLedgerSourceProvider);
    final List<SourceCard> sources = ref.watch(activeSourcesProvider);

    return Scaffold(
      appBar: const QtmsTopBar(screenTitle: ownerLedgerScreenTitle),
      body: ListView(
        padding: const EdgeInsets.only(bottom: Spacing.space24),
        children: <Widget>[
          QtmsContextHeader(
            sources: sources,
            selectedSourceId: sourceId,
            // ★★ **و«كل المصادر» خيارٌ مشروع هنا** — `FR-M15-02`:
            //    ⟵ **بخلاف شاشات العمليات** (`A-01`)، ★ **فهذه قراءةٌ
            //    وتجميعٌ للعرض** ⛔ **لا حسابٌ موحّدٌ يُنشأ.**
            onSourceSelected: (String? id) =>
                ref.read(ownerLedgerSourceProvider.notifier).select(id),
            day: day,
            allowAllSources: true,
          ),
          const Padding(
            padding: EdgeInsets.all(Spacing.cardPadding),
            child: _OwnerLedgerCardSlot(),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: Spacing.cardPadding),
            child: OwnerLedgerTrendChart(),
          ),
          const SizedBox(height: Spacing.space16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: Spacing.cardPadding),
            child: CashMovementCard(),
          ),
          const SizedBox(height: Spacing.space16),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.cardPadding,
            ),
            child: _HistoryLink(sourceId: sourceId),
          ),
        ],
      ),
    );
  }
}

/// ★ موضعُ البطاقة — **بحالاتها الأربع** (`ui-guidelines.md` نمط 1).
class _OwnerLedgerCardSlot extends ConsumerWidget {
  const _OwnerLedgerCardSlot();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<OwnerLedgerProjection?> card =
        ref.watch(ownerLedgerCardProvider);
    final CalendarDay day = ref.watch(ownerLedgerDayProvider);
    final String? sourceId = ref.watch(ownerLedgerSourceProvider);
    final String scopeLabel = sourceId == null
        ? 'كل المصادر'
        : ref.watch(sourceNameProvider(sourceId));

    return switch (card) {
      // ⛔⛔★★★ **ولا نصَّ استثناءٍ خامّ في `message` أبداً** — `AM-023`
      //    (`design-system.md` §هـ · `owner-ledger-summary-design.md` §10.5 ①):
      //    ★ **النصُّ البشريُّ الموحَّد في `message`**، ★ **والخامُّ مطويٌّ في
      //    `detail` خلف «تفاصيل تقنية»** ⛔ **ولا يُبتلَع كذلك.**
      AsyncError<OwnerLedgerProjection?>(:final Object error) => QtmsErrorState(
          message: readRejectionMessage,
          detail: '$error',
          onRetry: () => ref.invalidate(ownerLedgerSummaryProvider),
        ),
      AsyncLoading<OwnerLedgerProjection?>() => const _CardSkeleton(),
      AsyncValue<OwnerLedgerProjection?>(:final OwnerLedgerProjection? value) =>
        _card(context, ref, value, day: day, scopeLabel: scopeLabel),
    };
  }

  /// ★ البطاقةُ موصولةً بإجرائيها — §7.1 القاعدتان 5 و10 (`AM-023`).
  Widget _card(
    BuildContext context,
    WidgetRef ref,
    OwnerLedgerProjection? value, {
    required CalendarDay day,
    required String scopeLabel,
  }) {
    final String? sourceId = ref.watch(ownerLedgerSourceProvider);
    // ⛔⛔★★ **واليومُ بلا ملخّصٍ يُعرَض بأصفارٍ صريحة** — ⟵ **لا شاشةٌ
    //    فارغة**: ★ **«لم يُوزَّع اليوم شيء» معلومةٌ يريدها المالك.**
    final OwnerLedgerSummaryView view = ownerLedgerViewOf(
      value ??
          projectOwnerLedgerSummary(
            computeOwnerLedgerSummary(
              sourceId: sourceId ?? allSourcesScopeId,
              date: day,
              contributions: const OwnerLedgerContributions(),
            ),
            ref.watch(ownerLedgerVisibilityProvider),
          ),
      scopeLabel: scopeLabel,
      isLive: true,
    );
    return OwnerLedgerCard(
      summary: view,
      onRowTap: (String label) => openOwnerLedgerRow(context, ref, label),
      onShare: () =>
          shareOwnerLedgerSummary(context, ref, view: view, day: day),
    );
  }
}

/// ★ هيكلٌ شبحيٌّ بمقاس البطاقة — ⛔ **لا دوّامةً تحجب الشاشة** (نمط 1).
class _CardSkeleton extends StatelessWidget {
  const _CardSkeleton();

  @override
  Widget build(BuildContext context) => Container(
        // ★ **ارتفاعٌ مشتقٌّ من التوكنز** — ⛔ **لا رقمَ حرٌّ في شاشة.**
        height: Sizes.listRowHeight * 5,
        decoration: BoxDecoration(
          color: SemanticColors.surfaceSunken,
          borderRadius: BorderRadius.circular(Radii.hero),
        ),
      );
}

/// ★ مدخلُ سجل الأيام السابقة — `FR-M15-14`.
class _HistoryLink extends StatelessWidget {
  const _HistoryLink({required this.sourceId});

  final String? sourceId;

  @override
  Widget build(BuildContext context) {
    // ⛔⛔ **والسجلُّ لمصدرٍ بعينه** — ★ **شرطُ القراءة يعتمد `sourceId`**:
    //    ⟵ **واستعلامٌ لا يُقيّده يُرفَض كاملاً** (`IQ-024` · `DEBT-40`).
    if (sourceId == null) {
      return const QtmsInlineBanner(
        text: 'اختر مصدراً لعرض سجل أيامه السابقة.',
        triad: SemanticTriads.info,
      );
    }
    return OutlinedButton.icon(
      onPressed: () => context.go(ownerLedgerHistoryRoute),
      icon: const Icon(Icons.history, size: Sizes.iconMd),
      label: const Text('سجل الأيام السابقة'),
    );
  }
}

/// ★ اسمُ مصدرٍ للعرض — ⛔ **ومعرّفُه إن غاب اسمُه** (لا فراغٌ صامت).
final sourceNameProvider = Provider.family<String, String>((Ref ref, String id) {
  for (final SourceCard source in ref.watch(activeSourcesProvider)) {
    if (source.sourceId == id) return source.name;
  }
  return id;
});

/// ★★ يومٌ مقروءٌ للعرض — ★ **يُفوَّض إلى [dayLabel]** ⛔ **ولا صيغةَ ثانية.**
String ownerLedgerDayLabel(CalendarDay day) => dayLabel(day);

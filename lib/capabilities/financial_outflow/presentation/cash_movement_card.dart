/// ★★★ **بطاقة حركة النقد في تاريخ** — `FR-M15-15` … `FR-M15-21`.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **بطاقةٌ مستقلة تحت بطاقة الضمار ⛔ ولا تُدمَج فيها** —
/// `ui-guidelines.md` نمط 1 · القرار 1: ★ **سؤالان مختلفان — «كم لي؟»
/// و«كم في يدي؟»**، ⟵ **ودمجُهما هو بالضبط الخطأُ الذي بُنيت `M15` لمنعه.**
///
/// ★★ **ومعها سطرٌ يشرح الفرق نصّاً في الشاشة** — ⛔ **لا في مستندٍ يقرؤه
/// المطوّر وحده**: `AT-49` (**الواصل 179,700 · المقبوض 200,000**).
///
/// ⛔⛔ **والخصوماتُ تُعرَض للعلم ولا تُطرح** (`FR-M15-20`) — ★ **إسقاطُ دينٍ
/// لا خروجُ نقد.**
/// ═══════════════════════════════════════════════════════════════════════
///
/// ⛔ **وصفر حسابٍ هنا** (`design-system.md` §5.1) — ★ **المعادلاتُ في
/// [computeCashMovement]** بطبقة النطاق (`ADR-0012`).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qtms_domain/qtms_domain.dart';

import '../../../core/design/design_tokens.dart';
import '../../../core/ui/async_state_view.dart';
import '../../../core/ui/inline_banner.dart';
import '../../../core/ui/key_value_row.dart';
import '../../identity_access/application/session_providers.dart';
import '../application/owner_ledger_providers.dart';
import 'owner_ledger_format.dart';

/// بطاقة حركة النقد.
class CashMovementCard extends ConsumerWidget {
  /// ينشئ البطاقة.
  const CashMovementCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CalendarDay date = ref.watch(ownerLedgerDayProvider);
    final AsyncValue<CashMovementSummary> cash =
        ref.watch(cashMovementProvider(date));
    final bool showsDeposit =
        ref.watch(hasPermissionProvider(Permission.receiptDepositView));
    // ⛔⛔★★★ **والبندُ المحكوم يختفي من النقد كما يختفي من البطاقة** —
    //    `E-29` نصّاً: «**يختفي كلياً من البطاقة *والنقد* وكل التقارير**».
    final OwnerLedgerVisibility visibility =
        ref.watch(ownerLedgerVisibilityProvider);

    return switch (cash) {
      AsyncError<CashMovementSummary>(:final Object error) =>
        QtmsErrorState(message: '$error'),
      AsyncLoading<CashMovementSummary>() => const _Skeleton(),
      AsyncValue<CashMovementSummary>(:final CashMovementSummary? value)
          when value != null =>
        _Body(
          projection: projectCashMovement(value, visibility),
          showsDeposit: showsDeposit,
        ),
      _ => const _Skeleton(),
    };
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) => Container(
        height: Sizes.listRowHeight * 3,
        decoration: BoxDecoration(
          color: SemanticColors.surfaceSunken,
          borderRadius: BorderRadius.circular(Radii.card),
        ),
      );
}

class _Body extends StatelessWidget {
  const _Body({required this.projection, required this.showsDeposit});

  final CashMovementProjection projection;
  final bool showsDeposit;

  CashMovementSummary get summary => projection.summary;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(Spacing.cardPadding),
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
            Text(
              'حركة النقد في التاريخ',
              style: TypeScale.titleSm
                  .copyWith(color: SemanticColors.textPrimary),
            ),
            const SizedBox(height: Spacing.space2),
            // ★★★ **سطرُ الفرق — `AT-49` · `GR-41`.**
            Text(
              'المقبوض ≠ الواصل: الواصل يخصّ ضمارات هذا اليوم، '
              'والمقبوض كلُّ ما دخل الصندوق في هذا التاريخ.',
              style: TypeScale.caption
                  .copyWith(color: SemanticColors.textTertiary),
            ),
            const SizedBox(height: Spacing.space12),
            _Section(label: '▸ الداخل'),
            QtmsKeyValueRow(
              label: 'المقبوض من المقاوته',
              value: '${formatRiyals(summary.receivedFromDealers)} $riyalLabel',
            ),
            QtmsKeyValueRow(
              label: '— منه: لضمارات هذا اليوم',
              value: formatRiyals(summary.receivedForSameDayDebt),
            ),
            QtmsKeyValueRow(
              label: '— منه: لأيام سابقة',
              value: formatRiyals(summary.receivedForPreviousDays),
            ),
            QtmsKeyValueRow(
              label: '— منه: فائض لم يُسدَّد',
              value: formatRiyals(summary.receivedAsSurplus),
            ),
            QtmsKeyValueRow(
              label: 'المبيعات النقدية المُدخلة',
              value: formatRiyals(summary.cashSales),
            ),
            QtmsKeyValueRow(
              label: 'إجمالي النقد الداخل',
              value: '${formatRiyals(summary.totalIn)} $riyalLabel',
            ),
            const SizedBox(height: Spacing.space12),
            _Section(label: '▸ الخارج'),
            // ⛔⛔ **ولا يُرسَم البندُ المحكوم لمن لا يملكه** — ★ **ولا صفراً**:
            //    ⟵ **والإجماليُّ يُبنى على ما يراه** ⛔ **وإلا كشفه بالطرح.**
            if (projection.withdrawals case final Money amount)
              QtmsKeyValueRow(
                label: 'السحبيات',
                value: formatRiyals(amount),
              ),
            if (projection.expenses case final Money amount)
              QtmsKeyValueRow(
                label: 'الخرجيات',
                value: formatRiyals(amount),
              ),
            QtmsKeyValueRow(
              label: 'إجمالي الخارج',
              value: '${formatRiyals(projection.totalOut)} $riyalLabel',
            ),
            const SizedBox(height: Spacing.space12),
            QtmsKeyValueRow(
              label: '💰 صافي النقد المتبقي في اليد',
              value: '${formatRiyals(projection.netInHand)} $riyalLabel',
            ),
            if (projection.coveragePercent case final int percent)
              QtmsKeyValueRow(
                label: '📈 تغطية الخارج من المقبوض',
                value: '$percent٪',
              ),
            // ★★ **والإيداعُ لمن يملك `receiptDepositView` وحده** (`ADR-0017`)
            //    — ⛔ **ولا يُعرَض صفراً لمن لا يملكه:** ⟵ **فصفرُ الإيداع
            //    معلومةٌ مختلفةٌ عن «لا تُقرأ حالةُ الإيداع أصلاً».**
            if (showsDeposit) ...<Widget>[
              QtmsKeyValueRow(
                label: '🏦 من المقبوض: أُودع',
                value: formatRiyals(summary.deposited),
              ),
              QtmsKeyValueRow(
                label: '🏦 من المقبوض: لم يُودع بعد',
                value: formatRiyals(summary.notDeposited),
              ),
            ],
            // ⛔⛔ **وتُعرَض ولا تُطرح** — `FR-M15-20`.
            QtmsKeyValueRow(
              label: '✂️ الخصومات (للعلم — لا تُطرح)',
              value: formatRiyals(summary.discounts),
            ),
            if (showsDeposit && projection.hasCashGap) ...<Widget>[
              const SizedBox(height: Spacing.space12),
              QtmsInlineBanner(
                text: 'تنبيه فجوة النقد: الصافي في اليد أقلّ مما لم يُودع '
                    'بعد — راجع السحبيات.',
                triad: SemanticTriads.warning,
              ),
            ],
          ],
        ),
      );
}

class _Section extends StatelessWidget {
  const _Section({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: Spacing.space4),
        child: Text(
          label,
          style: TypeScale.label.copyWith(color: SemanticTriads.primary.ink),
        ),
      );
}

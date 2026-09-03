/// ★★ **رسمُ الصافي — آخر سبعة أيام** (`FR-M15-23` · `IQ-030` الخيار أ).
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **ولا رقمَ وهميٌّ في هذا الرسم إطلاقاً** — ★ **مصدرُه سجلُّ
/// `owner_ledger_trends` وحدَه** (`owner-ledger-summary-design.md` §2.1):
/// ⟵ **وقبل `WU-016` لم يكن له مصدر**، ⛔ **ورسمٌ بلا سلسلةٍ حقيقية أرقامٌ
/// وهميةٌ في شاشةٍ حقيقية** (§10 — **اختلاقٌ محرَّم**).
///
/// ⛔⛔ **ولا يكشف الرسمُ ما تُخفيه البطاقة** — §2.1 القاعدة 5:
/// ★ **والصافيُ يُسقَط على صلاحيات قارئه بـ[OwnerLedgerTrendPoint.netFinalFor]**
/// ⛔ **لا يُقرأ `netFinal` المخزَّن مباشرةً.**
///
/// ⛔⛔★★ **وصفرُ قيمةِ لونٍ أو حجمِ خطٍّ أو نصفِ قطرٍ خارج التوكنز**
/// (`design-system.md` §3.3 · بروتوكول التشغيل §ح) — ★ **تحرسها بوابةُ
/// `design_gates_test.dart`.**
/// ═══════════════════════════════════════════════════════════════════════
///
/// ★ **وأعمدةٌ لا خطٌّ منحنٍ:** ⟵ **سبعُ نقاطٍ لا تصنع منحنى يُقرأ**،
/// ★ **والعمودُ يُقارَن بالعين بلا محورٍ رقمي** (`ui-guidelines.md` §6).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qtms_domain/qtms_domain.dart';

import '../../../core/design/design_tokens.dart';
import '../application/owner_ledger_providers.dart';

/// رسمُ آخر سبعة أيام.
class OwnerLedgerTrendChart extends ConsumerWidget {
  /// ينشئ الرسم.
  const OwnerLedgerTrendChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<OwnerLedgerTrendPoint> points =
        ref.watch(ownerLedgerTrendProvider).value ??
            const <OwnerLedgerTrendPoint>[];
    // ⛔ **ولا رسمَ لنقطةٍ واحدة** — ★ **الرسمُ مقارنة**، ⟵ **وعمودٌ وحيد
    //   لا يُقارَن بشيء فيُوهم بمعنىً ليس فيه.**
    if (points.length < 2) return const SizedBox.shrink();

    final OwnerLedgerVisibility visibility =
        ref.watch(ownerLedgerVisibilityProvider);
    final List<int> values = <int>[
      for (final OwnerLedgerTrendPoint point in points)
        point.netFinalFor(visibility).riyals,
    ];
    final int peak = values.fold<int>(0, (int a, int b) => b > a ? b : a);

    return Container(
      padding: const EdgeInsets.all(Spacing.space16),
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
            'الصافي — آخر ${points.length} أيام',
            style: TypeScale.label
                .copyWith(color: SemanticColors.textSecondary),
          ),
          const SizedBox(height: Spacing.space12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              for (int i = 0; i < points.length; i++)
                Expanded(
                  child: _Bar(
                    point: points[i],
                    value: values[i],
                    peak: peak,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.point, required this.value, required this.peak});

  final OwnerLedgerTrendPoint point;
  final int value;
  final int peak;

  @override
  Widget build(BuildContext context) {
    // ★ **والارتفاعُ نسبةٌ من هدف اللمس ×3** — ⛔ **لا رقمَ حرٌّ في الشاشة.**
    const double maxHeight = Sizes.minTouch * 3;
    // ⛔ **والسالبُ يُرسَم بأدنى ارتفاع** — ★ **ولونُ الخطر يحمل المعنى**:
    //    ⟵ **فعمودٌ بلا ارتفاعٍ كان يختفي وهو أهمُّ ما في الرسم.**
    final double ratio = peak <= 0 ? 0 : (value <= 0 ? 0 : value / peak);
    final ColorTriad triad = value < 0
        ? SemanticTriads.danger
        : (point.retroUpdated
            ? SemanticTriads.info
            : SemanticTriads.primary);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.space2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(
            height: maxHeight,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                height: (maxHeight * ratio).clamp(Sizes.borderWidth * 2, maxHeight),
                decoration: BoxDecoration(
                  color: triad.soft,
                  border: Border.all(
                    color: triad.border,
                    width: Sizes.borderWidth,
                  ),
                  borderRadius: BorderRadius.circular(Radii.field),
                ),
              ),
            ),
          ),
          const SizedBox(height: Spacing.space4),
          Text(
            // ★ **يومُ الشهر وحده** — ⟵ **فسبعةُ تواريخَ كاملة لا تُقرأ في
            //   عرضِ عمود**، ★ **والتاريخُ الكامل في سجل الأيام** (`FR-M15-14`).
            '${point.date.day}',
            style: TypeScale.numericSm
                .copyWith(color: SemanticColors.textTertiary),
          ),
        ],
      ),
    );
  }
}

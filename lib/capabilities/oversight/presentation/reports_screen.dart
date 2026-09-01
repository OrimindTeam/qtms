/// شاشةُ التقارير — **نمط 6** (`ui-guidelines.md` §3: «شاشة المؤشّرات
/// والتقارير» — ⑤ **قسم «تقارير تفصيلية»**).
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **وما لا يملك المستخدم مفتاحَ عائلته لا يُرسَم إطلاقاً** —
/// `ui-guidelines.md` نمط 6: «**وبند يُخفى لعدم الصلاحية لا يُترك فراغاً بل
/// يختفي كله**»، ⟵ **والعائلةُ كلُّها تختفي بعنوانها** ⛔ **لا يبقى عنوانٌ
/// فوق فراغ** (نفس علاج `QtmsHubSection` في `home_shell.dart`).
///
/// ⚠️⚠️ **وكلُّ إخفاءٍ هنا عرضٌ لا حماية** (`RISK-02`) — ★ **والحارسُ الفعلي
/// شرطُ قراءة كلِّ مجموعةٍ يقرؤها التقرير ونطاقُ المصادر**، ⟵ **والمخاطرةُ
/// المتبقية معلَنةٌ صراحةً في `DEBT-71`** ⛔ **لا مكتومة.**
/// ═══════════════════════════════════════════════════════════════════════
///
/// ⛔ **ولا مؤشّرَ ولا رسمَ هنا بعد** — ★ **البندان ② و④ من النمط 6 مصدرُهما
/// ملخصاتُ `M15`** (`daily_summaries`) ⟵ **وتُبنى في `WU-016`**،
/// ⛔ **ولا تُخترَع بيانات لعرضها** (نفس ما فُعل بالنمط 1 حرفياً).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qtms_domain/qtms_domain.dart';

import '../../../app/top_bar.dart';

import '../../../app/router.dart';
import '../../../core/design/design_tokens.dart';
import '../../../core/ui/async_state_view.dart';
import '../../../core/ui/entity_tile.dart';
import '../../../core/ui/status_pill.dart';
import '../application/report_providers.dart';

/// شاشة قائمة التقارير.
class ReportsScreen extends ConsumerWidget {
  /// ينشئ الشاشة.
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<ReportFamily> families =
        ref.watch(visibleReportFamiliesProvider);
    final List<ReportId> reports = ref.watch(visibleReportsProvider);

    return Scaffold(
      appBar: QtmsTopBar(screenTitle: 'التقارير'),
      body: families.isEmpty
          ? const QtmsEmptyState(
              spec: EmptyStateSpec(
                icon: Icons.assessment_outlined,
                title: 'لا تقرير ضمن صلاحياتك',
                // ★ **سببُ الفراغ والخطوةُ التالية** — `ui-guidelines.md` §6.
                message: 'تقاريرُ كل مجموعة تحتاج مفتاحَ عرضها. '
                    'راجع المدير لمنحك ما يخصّ عملك.',
              ),
            )
          : ListView(
              padding: const EdgeInsetsDirectional.all(Spacing.screenPadding),
              children: <Widget>[
                for (final ReportFamily family in families) ...<Widget>[
                  SectionHeader(family.label),
                  for (final ReportId report in reportsOfFamily(family))
                    if (reports.contains(report))
                      Padding(
                        padding: const EdgeInsetsDirectional.only(
                          bottom: Spacing.cardGap,
                        ),
                        child: EntityTile(
                          leading: const IconBadgeBox(
                            icon: Icons.description_outlined,
                            triad: SemanticTriads.neutral,
                          ),
                          title: report.title,
                          // ★ **الفلاترُ المتاحةُ فعلاً** — ⛔ **لا ما يَعِد
                          //   به المتطلب ولم يُبنَ بعد** (`DEBT-72`).
                          subtitle: _filtersLabel(report),
                          onTap: () => _open(context, ref, report),
                          semanticLabel: report.title,
                        ),
                      ),
                  const SizedBox(height: Spacing.space8),
                ],
              ],
            ),
    );
  }

  /// ★★ يفتح التقرير — **ويُهيّئ طلبَه قبل الملاحة**.
  ///
  /// ⚠️ **والتهيئةُ هنا استجابةً للمس لا أثناء بناء الشجرة** — ★ **فلا
  /// تقع في `DEBT-68`**: ⟵ **الكتابةُ في مزوّدٍ أثناء البناء تُسقِط الشاشة.**
  static void _open(BuildContext context, WidgetRef ref, ReportId report) {
    ref.read(reportRequestProvider.notifier).open(report);
    context.go(reportRoute(report));
  }

  /// ★ الفلاترُ المتاحة لكل تقرير — **بالمصدر دائماً وما يخصُّه بعده**.
  static String _filtersLabel(ReportId report) => switch (report) {
        ReportId.itemMovements => 'المصدر · النوع · الفترة',
        ReportId.currentStock => 'المصدر · التاريخ · الحالة',
        ReportId.countedIntakes => 'المصدر · الفترة',
        ReportId.sackIntakes => 'المصدر · الفترة',
        ReportId.todayRemainder => 'المصدر · التاريخ',
        ReportId.distributions => 'المصدر · الفترة',
        ReportId.settlements => 'المصدر · الفترة · حالة التسوية',
        ReportId.receipts => 'المصدر · الفترة · حالة الإيداع',
        ReportId.dealerBalances => 'المصدر · حالة الرصيد',
        ReportId.dealerStatement => 'المصدر · المقوت · الفترة',
        ReportId.pendingEntries => 'المصدر · الفترة · نوع المستند',
      };
}

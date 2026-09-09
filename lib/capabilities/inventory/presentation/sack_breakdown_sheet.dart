/// ★★★ **تفكيك سعر الجونية** — `FR-M14-15` · **نمط 3** (`ui-guidelines.md` §3).
///
/// ```text
/// كل الحركات المكوِّنة له: النوع · الجهة · الكمية · السعر · القيمة · نوع الحركة
/// ```
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **والمجموعُ هنا ليس مصدرَ الحقيقة — وهذا أهم ما في الملف:**
/// ★ **الرقمُ المعتمد في `finance/current` يكتبه المُحتسِب السحابي**
/// (`ADR-0008`) — ⟵ **وهذا تفكيكٌ يشرح كيف تكوَّن**، ★ **يُبنى بنفس دالة
/// النطاق** (`computeSackRevenue`) ⛔ **لا بمعادلةٍ ثانية.**
///
/// ⛔⛔ **وقد يختلف المجموعُ هنا عن المخزَّن اختلافاً مشروعاً واحداً:**
/// ★ **قارئٌ لا يملك `distributionPriceView` لا يرى قيمَ سطور التوزيع**
/// (`ADR-0011` · `ت-12`) — ⟵ **فتظهر عنده «—»**، ★ **والصفحةُ تقول ذلك
/// صراحةً** ⛔ **ولا تعرض مجموعاً ناقصاً كأنه السعر.**
/// ═══════════════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qtms_domain/qtms_domain.dart';

import '../../../core/design/design_tokens.dart';
import '../../../core/ui/async_state_view.dart';
import '../../../core/ui/data_table.dart';
import '../../../core/ui/inline_banner.dart';
import '../../../core/ui/skeleton.dart';
import '../application/sack_valuation_providers.dart';
import 'inventory_widgets.dart';

/// يفتح **ورقة تفكيك سعر الجونية**.
Future<void> showSackBreakdown(
  BuildContext context, {
  required String sackId,
  required String sackName,
  required String sourceId,
  required CalendarDay day,
}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: SemanticColors.surface,
      builder: (BuildContext context) => SackBreakdownSheet(
        sackId: sackId,
        sackName: sackName,
        sourceId: sourceId,
        day: day,
      ),
    );

/// ورقةُ تفكيك سعر الجونية.
class SackBreakdownSheet extends ConsumerWidget {
  /// ينشئ الورقة.
  const SackBreakdownSheet({
    required this.sackId,
    required this.sackName,
    required this.sourceId,
    required this.day,
    super.key,
  });

  /// رقم الجونية.
  final String sackId;

  /// اسمها الظاهر.
  final String sackName;

  /// المصدر.
  final String sourceId;

  /// ★ تاريخ المخزون — ⛔ **لا تاريخ الإدخال** (`RISK-07`).
  final CalendarDay day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Outcome<List<SackRevenueContribution>>> loaded =
        ref.watch(
      sackBreakdownProvider(
        SackBreakdownQuery(sackId: sackId, sourceId: sourceId, stockDate: day),
      ),
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.space16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('تفكيك سعر: $sackName', style: TypeScale.titleMd),
            const SizedBox(height: Spacing.space12),
            Flexible(child: _Body(state: loaded)),
          ],
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.state});

  final AsyncValue<Outcome<List<SackRevenueContribution>>> state;

  @override
  Widget build(BuildContext context) => switch (state) {
        AsyncValue<Outcome<List<SackRevenueContribution>>>(
          hasError: true,
        ) =>
          QtmsErrorState(message: _readFailure),
        AsyncValue<Outcome<List<SackRevenueContribution>>>(
          value: final Outcome<List<SackRevenueContribution>> outcome?,
        ) =>
          switch (outcome) {
            Failure<List<SackRevenueContribution>>() =>
              QtmsErrorState(message: _readFailure),
            Success<List<SackRevenueContribution>>(
              value: final List<SackRevenueContribution> rows,
            ) =>
              rows.isEmpty
                  ? const QtmsEmptyState(spec: _noMovementsEmpty)
                  : _Breakdown(rows: rows),
          },
        _ => const SkeletonList(count: 3),
      };
}

/// ★ **رسالةُ الرفض البشرية** — ⛔ **ولا رمزَ تقنيّ في واجهة المستخدم**
/// (`ui-guidelines.md` §6) — ★ **بنفس نصّ [InventoryAsyncView] حرفياً**:
/// ⟵ **فلا صياغتان لرفضٍ واحد.**
const String _readFailure =
    'تحقق من صلاحيتك ونطاق مصادرك، ثم أعد المحاولة.';

/// ★ **«لم يخرج منها شيء بعد» لا «لا توجد بيانات»** — `E-21`.
const EmptyStateSpec _noMovementsEmpty = EmptyStateSpec(
  icon: Icons.inbox_outlined,
  title: 'لم يخرج من هذه الجونية شيء بعد',
  message: 'الجونية تُقيَّم بما تحقق منها — والكمية الباقية في المخزن '
      'لا تُحتسب في سعرها.',
);

class _Breakdown extends StatelessWidget {
  const _Breakdown({required this.rows});

  final List<SackRevenueContribution> rows;

  @override
  Widget build(BuildContext context) {
    final SackRevenue revenue = computeSackRevenue(rows);
    return ListView(
      shrinkWrap: true,
      children: <Widget>[
        QtmsDataTable(
          columns: const <QtmsTableColumn>[
            QtmsTableColumn('النوع'),
            QtmsTableColumn('نوع الحركة'),
            QtmsTableColumn('الجهة'),
            QtmsTableColumn('الكمية', numeric: true),
            QtmsTableColumn('السعر', numeric: true),
            QtmsTableColumn('القيمة', numeric: true),
          ],
          rows: <QtmsTableRow>[
            for (final SackRevenueContribution row in rows)
              QtmsTableRow(
                <String>[
                  row.itemName,
                  row.origin.label,
                  row.counterpartyName ?? row.documentNumber,
                  quantityLabel(row.quantity),
                  row.unitPrice == null ? '—' : formatRiyals(row.unitPrice!),
                  row.lineValue == null ? '—' : formatRiyals(row.lineValue!),
                ],
                // ★ **والملغى مشطوبٌ لا محذوف** — `A-14`.
                isStruck: !row.isCountable,
              ),
          ],
        ),
        const SizedBox(height: Spacing.space12),
        QtmsInlineBanner(
          triad: revenue.isFinal
              ? SemanticTriads.success
              : SemanticTriads.warning,
          text: revenue.isFinal
              ? 'مجموع الحركات المسعَّرة: ${formatRiyals(revenue.total)} ريال'
              : 'مجموع المسعَّر: ${formatRiyals(revenue.total)} ريال — '
                  'و${revenue.unpricedCount} حركة بلا قيمة ظاهرة، '
                  'فالسعر غير نهائي.',
        ),
      ],
    );
  }
}


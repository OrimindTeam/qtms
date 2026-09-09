/// بطاقاتُ شاشة **مالية الجواني** (`M14` · `WU-015`) — **عرضٌ محض**.
///
/// ★ **مفصولةٌ عن `sack_finance_screen.dart` عمداً** — ⟵ **بلاها يتجاوز ملفُّ
/// الشاشة حدَّ 400 سطر** (`coding-standards.md` §4)، ★ **والفصلُ بالمسؤولية:**
/// **الشاشةُ تُركِّب والسياقُ يُرشِّح، وهذه تعرض أرقاماً مخزَّنة.**
///
/// ⛔⛔★★★ **ولا معادلةَ تُحسَب هنا** — ★ **الأرقامُ من `finance/current` و
/// `supplier_balances`**، ⟵ **والإجمالياتُ من `computeSupplierSourceTotals`
/// في طبقة النطاق** ⛔ **لا بجمعٍ في الودجت** (`coding-standards.md` §2.2).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qtms_domain/qtms_domain.dart';

import '../../../core/design/design_tokens.dart';
import '../../../core/ui/key_value_row.dart';
import '../../../core/ui/status_pill.dart';
import '../../identity_access/presentation/permission_gate.dart';
import '../application/inventory_providers.dart';
import '../application/sack_valuation_providers.dart';
import 'inventory_widgets.dart';
import 'sack_breakdown_sheet.dart';
import 'sack_tax_sheet.dart';

/// 🔒 **بطاقة حساب الرعوي في المصدر** — `design-overview.md` §2.5.
///
/// ⛔⛔ **وعبر كل الأيام لا يومَ الشاشة** — ★ **فهو حسابٌ لا ملخّصُ يوم**،
/// ⟵ **وقصرُه على اليوم كان يجعل «حساب الرعوي» رقماً يتغيّر بتغيّر مرشِّح.**
class SupplierAccountCard extends ConsumerWidget {
  /// ينشئ البطاقة.
  const SupplierAccountCard({
    required this.supplierId,
    required this.sourceId,
    super.key,
  });

  /// الرعوي.
  final String supplierId;

  /// المصدر.
  final String sourceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<SupplierBalanceCard?> balance = ref.watch(
      supplierBalanceProvider(
        SupplierAccountQuery(supplierId: supplierId, sourceId: sourceId),
      ),
    );
    final SupplierBalanceCard? card = balance.value;
    // ⛔★★ **وغيابُها إخفاءٌ لا رسالةُ فشل** — ★ **من لا يملك
    //   `supplierFinanceView` لا يُفترَض به أن يرى شيئاً** (`ADR-0011`).
    if (card == null) return const SizedBox.shrink();

    final SupplierSourceTotals totals = card.totals;
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.space16),
      child: SackFinancePanel(
        title: 'حساب الرعوي في هذا المصدر',
        children: <Widget>[
          QtmsKeyValueRow(
            label: 'إجمالي سعر الجواني',
            value: '${formatRiyals(totals.totalRevenue)} ريال',
            numeric: true,
          ),
          QtmsKeyValueRow(
            label: 'إجمالي الضريبة',
            value: '${formatRiyals(totals.totalTax)} ريال',
            numeric: true,
          ),
          QtmsKeyValueRow(
            label: 'صافي الرعوي',
            value: '${formatRiyals(totals.net)} ريال',
            numeric: true,
          ),
          QtmsKeyValueRow(
            label: 'عدد الجواني',
            value: '${totals.sackCount}',
            numeric: true,
          ),
          if (!totals.isFinal)
            Padding(
              padding: const EdgeInsets.only(top: Spacing.space8),
              child: StatusPill(
                label: _pendingLabel(totals),
                triad: SemanticTriads.warning,
                icon: Icons.hourglass_bottom_outlined,
              ),
            ),
        ],
      ),
    );
  }

  /// ★ **يقول لماذا الرقم غير نهائي** — ⛔ **لا وسمٌ مبهم**.
  static String _pendingLabel(SupplierSourceTotals totals) {
    if (totals.pendingTaxCount > 0 && totals.unfinalRevenueCount > 0) {
      return 'غير نهائي — ${totals.pendingTaxCount} بضريبةٍ معلّقة '
          'و${totals.unfinalRevenueCount} بسعرٍ غير نهائي';
    }
    if (totals.pendingTaxCount > 0) {
      return 'غير نهائي — ${totals.pendingTaxCount} جونية بضريبةٍ معلّقة';
    }
    return 'غير نهائي — ${totals.unfinalRevenueCount} جونية بسعرٍ غير نهائي';
  }
}

/// ★★ **إجماليات اليوم والمصدر** — `FR-M14-12`.
///
/// ★ **والمعادلة من طبقة النطاق** (`computeSupplierSourceTotals`) —
/// ⛔ **ولا نسخةَ ثانية منها هنا** (`coding-standards.md` §2.2).
class SackDayTotals extends ConsumerWidget {
  /// ينشئ الإجماليات.
  const SackDayTotals({required this.sacks, super.key});

  /// جواني اليوم المعروضة.
  final List<SackCard> sacks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<SupplierSackRow> rows = <SupplierSackRow>[
      for (final SackCard sack in sacks)
        if (!sack.isCancelled)
          if (ref.watch(sackFinanceProvider(sack.documentNumber)).value
              case final SackFinanceCard finance)
            SupplierSackRow(
              sackId: sack.documentNumber,
              sackRevenue: finance.sackRevenue ?? Money.zero,
              sackTax: finance.sackTax,
              isRevenueFinal: finance.sackRevenue != null,
            ),
    ];
    // ⛔★★ **وبلا ماليةٍ مقروءة لا إجمالي** — ★ **من لا يملك `sackFinanceView`
    //   لا يرى المبالغ أصلاً** (`ADR-0011`)، ⟵ **وصفرٌ هنا كان يُقرأ رقماً.**
    if (rows.isEmpty) return const SizedBox.shrink();

    final SupplierSourceTotals totals = computeSupplierSourceTotals(rows);
    return SackFinancePanel(
      title: 'إجماليات اليوم في هذا المصدر',
      children: <Widget>[
        QtmsKeyValueRow(
          label: 'عدد الجواني',
          value: '${totals.sackCount}',
          numeric: true,
        ),
        QtmsKeyValueRow(
          label: 'إجمالي سعر الجواني',
          value: '${formatRiyals(totals.totalRevenue)} ريال',
          numeric: true,
        ),
        QtmsKeyValueRow(
          label: 'إجمالي الضريبة',
          value: '${formatRiyals(totals.totalTax)} ريال',
          numeric: true,
        ),
        QtmsKeyValueRow(
          label: 'الصافي لكل الجواني',
          value: '${formatRiyals(totals.net)} ريال',
          numeric: true,
        ),
      ],
    );
  }
}

/// ★ بطاقةُ جونيةٍ بماليتها — **والنقر يفتح تفكيك سعرها** (`FR-M14-15`).
class SackFinanceTile extends ConsumerWidget {
  /// ينشئ البطاقة.
  const SackFinanceTile({
    required this.sack,
    required this.sourceId,
    required this.day,
    super.key,
  });

  /// الجونية.
  final SackCard sack;

  /// المصدر.
  final String sourceId;

  /// تاريخ المخزون.
  final CalendarDay day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SackFinanceCard? finance =
        ref.watch(sackFinanceProvider(sack.documentNumber)).value;
    final Money? revenue = finance?.sackRevenue;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        InventoryTile(
          title: sack.displayName,
          subtitle: _subtitleOf(finance),
          trailing: revenue == null ? '—' : '${formatRiyals(revenue)} ريال',
          onTap: () => showSackBreakdown(
            context,
            sackId: sack.documentNumber,
            sackName: sack.displayName,
            sourceId: sourceId,
            day: day,
          ),
        ),
        // ★★★ **مدخلُ ضريبة الكيلو** — `FR-M7-10` · **ونطاقُ `WU-015`
        //   يشمل «وضريبة الجونية»** نصّاً.
        //
        // ⛔⛔ **وببوابةِ «أيُّهما»** — الكتالوج §2.2: **`sackTaxEnterNow`
        //   أو `sackTaxEnterLater`** — ★ **والثانيةُ تشترط `sackView` معها**،
        //   ⟵ **وهي شرطُ الوصول إلى هذه الشاشة أصلاً** (`home_shell`).
        // ⚠️⚠️ **وإخفاءٌ لا حماية** — ★ **والفحصُ في `planSack`** (`RISK-02`).
        //
        // ⛔ **ولا يظهر لجونيةٍ ملغاة** — `ERR_AMEND_006`: ★ **الملغاة لا
        //   تُعدَّل**، ⟵ **وزرٌّ يفتح ورقةً ترفضها السحابةُ حتماً تضليل.**
        if (!sack.isCancelled)
          AnyPermissionGate(
            permissions: const <Permission>[
              Permission.sackTaxEnterNow,
              Permission.sackTaxEnterLater,
            ],
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () => showSackTaxSheet(
                  context,
                  sack: sack,
                  currentTaxPerKilo: finance?.taxPerKilo,
                ),
                icon: const Icon(Icons.receipt_long_outlined),
                label: Text(
                  finance?.taxPerKilo == null
                      ? 'إدخال ضريبة الكيلو'
                      : 'تعديل ضريبة الكيلو',
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// ★ سطرٌ يقول حالةَ الرقم — ⛔ **ولا يُخفي أن الضريبة معلّقة**.
  static String _subtitleOf(SackFinanceCard? finance) {
    if (finance == null) return 'المالية غير متاحة';
    final StringBuffer text = StringBuffer();
    text.write(
      finance.sackTax == null
          ? 'الضريبة معلّقة'
          : 'الضريبة ${formatRiyals(finance.sackTax!)} ريال',
    );
    text.write(' · ');
    text.write(
      finance.supplierNet == null
          ? 'الصافي غير محتسَب'
          : 'الصافي ${formatRiyals(finance.supplierNet!)} ريال',
    );
    return text.toString();
  }
}

/// ★ لوحةٌ بسيطة — **بالطبقة الدلالية وحدها** (`design-system.md` §3.3).
class SackFinancePanel extends StatelessWidget {
  /// ينشئ اللوحة.
  const SackFinancePanel({
    required this.title,
    required this.children,
    super.key,
  });

  /// العنوان.
  final String title;

  /// المحتوى.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(Spacing.space16),
        decoration: BoxDecoration(
          color: SemanticColors.surfaceSunken,
          border: Border.all(color: SemanticColors.border),
          borderRadius: BorderRadius.circular(Radii.card),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: TypeScale.titleSm),
            const SizedBox(height: Spacing.space8),
            ...children,
          ],
        ),
      );
}

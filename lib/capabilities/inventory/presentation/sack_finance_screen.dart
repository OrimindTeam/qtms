/// شاشة **مالية الجواني وحساب الرعوي** (`M14`) — **نمط 2** (`ui-guidelines.md`
/// §3) بورقةِ تفصيلٍ من **نمط 3**.
///
/// ★ **المصدر:** `FR-M14-01` … `FR-M14-15` · `sack-valuation-design.md` ·
/// `design-overview.md` §2.2 و§2.5 · `design-system.md` · `design-tokens.md`
/// (بروتوكول التشغيل §ح — **الوحدة تعرض شاشة**).
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **ثلاث قواعدَ تحكم كل رقمٍ في هذه الشاشة:**
///
///   ① ★★★ **الرقمُ المعروض هو المخزَّن من المُحتسِب السحابي** — ⟵ **يُقرأ
///      من `finance/current`** ⛔ **ولا يُعاد حسابُه في الشاشة**:
///      ★ **ورقمان لمعادلةٍ واحدة يفترقان عند أول تعديل**
///      (`coding-standards.md` §2.2 · `ADR-0008`).
///   ② ⛔⛔ **ولا تُجمع حسابات الرعوي بين المصادر** (`FR-M14-04` · `GR-21`
///      · `ADR-0005`) — ★ **والشاشة على مصدرٍ واحد دائماً**.
///   ③ ⛔⛔★★★ **ولا عمليةَ تسديدٍ للرعوي في هذا الإصدار** (`FR-M14-13`) —
///      ★ **والتنبيهُ النطاقي ظاهرٌ في الشاشة نصّاً** ⛔ **لا في مستندٍ
///      يقرؤه المطوّر وحده**: ⟵ **«ويجب إبلاغ الرعية بذلك تفادياً لسوء
///      الفهم»** (`sack-valuation-design.md` §7).
/// ═══════════════════════════════════════════════════════════════════════
///
/// ⚠️⚠️ **وكلُّ بوابةٍ هنا إخفاءٌ لا حماية** — ★ **ويقابلها شرطُ قراءةٍ في
/// `firestore.rules`** (`sackFinanceView` على `finance/current` ·
/// `supplierFinanceView` على `supplier_balances`) — `RISK-02`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qtms_domain/qtms_domain.dart';

import '../../../app/top_bar.dart';
import '../../../core/design/design_tokens.dart';
import '../../../core/ui/async_state_view.dart';
import '../../../core/ui/context_header.dart';
import '../../../core/ui/filter_bar.dart';
import '../../../core/ui/inline_banner.dart';
import '../../master_data/application/master_data_providers.dart';
import '../application/inventory_providers.dart';
import '../application/sack_valuation_providers.dart';
import 'inventory_widgets.dart';
import 'sack_finance_cards.dart';

/// عنوان الشاشة — ★ **مصدرٌ واحد يقرؤه الشريطُ والمدخلُ والاختبار**.
const String sackFinanceScreenTitle = 'مالية الجواني';

/// شاشة مالية الجواني وحساب الرعوي.
class SackFinanceScreen extends ConsumerWidget {
  /// ينشئ الشاشة.
  const SackFinanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CalendarDay today = ref.watch(todayProvider);
    final String? sourceId = ref.watch(selectedSourceProvider);
    final List<SourceCard> sources = ref.watch(activeSourcesProvider);
    final String? supplierId = ref.watch(selectedSupplierProvider);

    return Scaffold(
      appBar: const QtmsTopBar(screenTitle: sackFinanceScreenTitle),
      body: Column(
        children: <Widget>[
          QtmsContextHeader(
            sources: sources,
            selectedSourceId: sourceId,
            // ⛔⛔ **ولا خيارَ «كل المصادر»** — راجع القاعدة ② في الترويسة.
            onSourceSelected: (String? id) {
              if (id != null) {
                ref.read(selectedSourceProvider.notifier).select(id);
              }
            },
            day: today,
            activeFilterCount: supplierId == null ? 0 : 1,
            filters: _SupplierFilter(selectedSupplierId: supplierId),
          ),
          Expanded(
            child: sourceId == null
                ? QtmsEmptyState(
                    spec: sources.isEmpty
                        ? noSourceInScopeEmpty
                        : chooseSourceEmpty(),
                  )
                : _SackFinanceBody(
                    sourceId: sourceId,
                    day: today,
                    supplierId: supplierId,
                  ),
          ),
        ],
      ),
    );
  }
}

/// ★ مرشِّح الرعوي — **«كل الرعية» خيارٌ مشروع** (`FR-M14-01`).
class _SupplierFilter extends ConsumerWidget {
  const _SupplierFilter({required this.selectedSupplierId});

  final String? selectedSupplierId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ★ **والمعطَّل لا يُعرَض مرشِّحاً** — ⛔ **فلا يُختار من لا جواني له
    //   تُضاف بعد اليوم** (`FR-M3-11`).
    final List<SupplierCard> suppliers = <SupplierCard>[
      for (final SupplierCard supplier
          in ref.watch(suppliersProvider).value ?? const <SupplierCard>[])
        if (supplier.isActive) supplier,
    ];
    return QtmsFilterBar(
      padded: false,
      groups: <List<QtmsFilterOption>>[
        <QtmsFilterOption>[
          QtmsFilterOption(
            label: 'كل الرعية',
            selected: selectedSupplierId == null,
            onSelected: () =>
                ref.read(selectedSupplierProvider.notifier).select(null),
          ),
          for (final SupplierCard supplier in suppliers)
            QtmsFilterOption(
              label: supplier.name,
              selected: selectedSupplierId == supplier.supplierId,
              onSelected: () => ref
                  .read(selectedSupplierProvider.notifier)
                  .select(supplier.supplierId),
            ),
        ],
      ],
    );
  }
}

class _SackFinanceBody extends ConsumerWidget {
  const _SackFinanceBody({
    required this.sourceId,
    required this.day,
    required this.supplierId,
  });

  final String sourceId;
  final CalendarDay day;
  final String? supplierId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<SackCard>> sacks = ref.watch(
      sacksProvider(StockQuery(sourceId: sourceId, stockDate: day)),
    );

    return InventoryAsyncView<SackCard>(
      value: sacks.whenData(
        (List<SackCard> all) => <SackCard>[
          for (final SackCard sack in all)
            if (supplierId == null || sack.supplierId == supplierId) sack,
        ],
      ),
      emptyIcon: Icons.inventory_outlined,
      emptyTitle: 'لا جواني في هذا اليوم',
      emptyLabel: 'لم يُورَّد لهذا المصدر جونيةٌ اليوم — سجّل جونية من التوريد.',
      builder: (List<SackCard> list) => ListView(
        padding: const EdgeInsets.all(Spacing.space16),
        children: <Widget>[
          if (supplierId case final String supplier)
            SupplierAccountCard(supplierId: supplier, sourceId: sourceId),
          SackDayTotals(sacks: list),
          const SizedBox(height: Spacing.space16),
          for (final SackCard sack in list) ...<Widget>[
            SackFinanceTile(sack: sack, sourceId: sourceId, day: day),
            const SizedBox(height: Spacing.space8),
          ],
          const SizedBox(height: Spacing.space16),
          // ③ ⛔⛔★★★ **التنبيه النطاقي** — `FR-M14-13`.
          const QtmsInlineBanner(
            triad: SemanticTriads.info,
            text: 'الصافي يُعرَض ويُقيَّد فقط — ولا توجد عملية تسديد للرعوي '
                'في هذا الإصدار.',
          ),
        ],
      ),
    );
  }
}


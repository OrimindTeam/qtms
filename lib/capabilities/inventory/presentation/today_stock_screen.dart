/// شاشة **مخزون اليوم** (`M8` الشاشة الأولى) — **نمط 2** (`ui-guidelines.md` §3).
///
/// ⛔★★ **اليوم الجاري فقط 🔒 ولا متصفّح تاريخ** — `FR-M8-05` · `BR-M8-06`
/// (`GR-55`): «**والاطلاع التاريخي وظيفة تقارير `M19`**».
///
/// ⛔★★ **ولا واجهة تُعدِّل الرصيد مباشرة** — `FR-M8-03` · `GR-01`: التغيير
/// **عبر تعديل الحركة نفسها أو تسوية جرد**، ⟵ **فالشاشة عرضٌ محض.**
///
/// ★★ **وإجماليان منفصلان لا إجمالي واحد** — `FR-M8-07` (`E-31` · `GR-19`):
/// «**الأنواع بالحبة والأنواع بالكيلوجرام تُعرض معاً مع عمود الوحدة، ولا
/// تُجمع إجمالياتها معاً إطلاقاً**».
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qtms_domain/qtms_domain.dart';

import '../../../app/top_bar.dart';

import '../../../core/design/design_tokens.dart';
import '../../../core/ui/async_state_view.dart';
import '../../../core/ui/context_header.dart';
import '../../../core/ui/date_labels.dart';
import '../../master_data/application/master_data_providers.dart';
import '../../oversight/presentation/audit_trail_view.dart';
import '../application/inventory_providers.dart';
import 'inventory_widgets.dart';

/// شاشة مخزون اليوم.
class TodayStockScreen extends ConsumerWidget {
  /// ينشئ الشاشة.
  const TodayStockScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CalendarDay today = ref.watch(todayProvider);
    final String? sourceId = ref.watch(selectedSourceProvider);
    final List<SourceCard> sources = ref.watch(activeSourcesProvider);

    return Scaffold(
      appBar: QtmsTopBar(screenTitle: 'مخزون اليوم'),
      body: Column(
        children: <Widget>[
          // ★★★ **رأس السياق الموحّد** — `MASTER.md` §5b نمط `P3` (`ADR-0021`).
          //
          // ⛔⛔ **ويستبدل `SourcePicker` + `LockedDayBanner` معاً** — ★ **صفٌّ
          //    واحد بدل صفّين وفراغٍ بينهما**، ⟵ **والمنتقي قائمةٌ منسدلة
          //    بارتفاعٍ ثابت** ⛔ **لا شرائح تلتفّ بلا حدّ.**
          QtmsContextHeader(
            sources: sources,
            selectedSourceId: sourceId,
            // ⛔ **وشاشةُ عمليةٍ على مصدرٍ واحد** — ★ **بلا خيار «الكل»**
            //   (`AM-009` ③ · `A-01`): ⟵ **و`null` لا تصل هنا أبداً.**
            onSourceSelected: (String? id) {
              if (id != null) ref.read(selectedSourceProvider.notifier).select(id);
            },
            day: today,
          ),
          Expanded(
            // ⛔⛔★★★ **ولا `SizedBox.shrink` حالةً لغياب المصدر** — §5b نمط
            //    `P3` قاعدةُ الفراغ الصامت: ★ **شاشةٌ بيضاء تُقرأ عطلاً لا
            //    انتظاراً** (`design-system.md` §هـ).
            //
            // ⚠️ **وحالتان لا واحدة:** ★ **نطاقٌ فارغ** (`E-35` — ⛔ بلا إجراء،
            //    فالمستخدم لا يملك ما يفعله) **ومصادرُ قائمةٌ بلا اختيار.**
            child: sourceId == null
                ? QtmsEmptyState(
                    spec: sources.isEmpty
                        ? noSourceInScopeEmpty
                        : chooseSourceEmpty(),
                  )
                : _StockList(sourceId: sourceId, day: today),
          ),
        ],
      ),
    );
  }
}

class _StockList extends ConsumerWidget {
  const _StockList({required this.sourceId, required this.day});

  final String sourceId;
  final CalendarDay day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<ItemDailyBalanceCard>> balances = ref.watch(
      todayStockProvider(StockQuery(sourceId: sourceId, stockDate: day)),
    );

    return InventoryAsyncView<ItemDailyBalanceCard>(
      value: balances,
      // ★ **«لا يوجد بعد» لا «ممنوع»** — والمنع له نصّه في `InventoryAsyncView`.
      emptyIcon: Icons.inventory_2_outlined,
      emptyTitle: 'المخزن فارغ اليوم',
      emptyLabel: 'لم يدخل هذا المصدر وارد اليوم — سجّل وارداً أو جونية.',
      builder: (List<ItemDailyBalanceCard> list) => ListView(
        padding: const EdgeInsets.all(Spacing.space16),
        children: <Widget>[
          _Totals(balances: list),
          const SizedBox(height: Spacing.space16),
          for (final ItemDailyBalanceCard card in list) ...<Widget>[
            InventoryTile(
              title: card.itemName,
              subtitle: 'وارد ${quantityLabel(card.incoming)} · '
                  'صادر ${quantityLabel(card.outgoing)}',
              trailing: quantityLabel(card.balance),
              // ★ **النقر يفتح سجل حركة النوع لذلك اليوم** — `FR-M8-06`.
              onTap: () => showItemMovements(
                context,
                sourceId: sourceId,
                itemKey: card.itemKey,
                itemName: card.itemName,
                day: day,
              ),
            ),
            const SizedBox(height: Spacing.space8),
          ],
        ],
      ),
    );
  }
}

/// ★★ **إجماليان منفصلان** — `FR-M8-07`.
///
/// ⛔★★ **ولا سطرَ ثالثٌ يجمعهما:** ★ **الجمع بين الحبات والأوزان ممنوع**،
/// ⟵ **وسطرٌ «الإجمالي» كان سيكون رقماً بلا معنى.**
class _Totals extends StatelessWidget {
  const _Totals({required this.balances});

  final List<ItemDailyBalanceCard> balances;

  @override
  Widget build(BuildContext context) {
    int pieces = 0;
    double kilograms = 0;
    for (final ItemDailyBalanceCard card in balances) {
      switch (card.balance) {
        case PieceQuantity(:final PieceCount count):
          pieces += count.pieces;
        case WeightQuantity(:final WeightKg weight):
          kilograms += weight.kilograms;
      }
    }

    return Container(
      padding: const EdgeInsets.all(Spacing.space16),
      decoration: BoxDecoration(
        color: SemanticColors.surfaceSunken,
        border: Border.all(color: SemanticColors.border),
        borderRadius: BorderRadius.circular(Radii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'إجمالي المعدود: ${quantityLabel(PieceQuantity(PieceCount(pieces)))}',
            style: TypeScale.bodyLg,
          ),
          const SizedBox(height: Spacing.space4),
          Text(
            'إجمالي الوزني: ${quantityLabel(WeightQuantity(WeightKg(kilograms)))}',
            style: TypeScale.bodyLg,
          ),
        ],
      ),
    );
  }
}

/// يفتح **سجل حركة النوع** — `FR-M8-06`.
Future<void> showItemMovements(
  BuildContext context, {
  required String sourceId,
  required String itemKey,
  required String itemName,
  required CalendarDay day,
}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: SemanticColors.surface,
      builder: (BuildContext context) => ItemMovementsSheet(
        sourceId: sourceId,
        itemKey: itemKey,
        itemName: itemName,
        day: day,
      ),
    );

/// ورقة سجل حركة النوع.
class ItemMovementsSheet extends ConsumerWidget {
  /// ينشئ الورقة.
  const ItemMovementsSheet({
    required this.sourceId,
    required this.itemKey,
    required this.itemName,
    required this.day,
    super.key,
  });

  /// المصدر.
  final String sourceId;

  /// مفتاح النوع.
  final String itemKey;

  /// اسم النوع.
  final String itemName;

  /// تاريخ المخزون.
  final CalendarDay day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<StockMovementCard>> movements = ref.watch(
      itemMovementsProvider(
        MovementQuery(sourceId: sourceId, itemKey: itemKey, stockDate: day),
      ),
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.space16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text('حركة $itemName — ${dayLabel(day)}',
                style: TypeScale.titleLg),
            const SizedBox(height: Spacing.space16),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: InventoryAsyncView<StockMovementCard>(
                value: movements,
                emptyIcon: Icons.receipt_long_outlined,
                emptyTitle: 'لا حركات اليوم',
                emptyLabel: 'لم تُسجَّل حركةٌ على هذا النوع في تاريخ اليوم.',
                builder: (List<StockMovementCard> list) => ListView.separated(
                  shrinkWrap: true,
                  itemCount: list.length,
                  separatorBuilder: (BuildContext _, int _) =>
                      const SizedBox(height: Spacing.space8),
                  itemBuilder: (BuildContext context, int index) =>
                      _MovementTile(
                        movement: list[index],
                        sourceId: sourceId,
                      ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MovementTile extends ConsumerWidget {
  const _MovementTile({required this.movement, required this.sourceId});

  final StockMovementCard movement;

  /// ★★ مصدر الحركة — ⛔ **إلزاميٌّ لقراءة السجل السياقي.**
  ///
  /// ⚠️ **ولا يحمله [StockMovementCard]** — ★ **الشاشة تستعلم به أصلاً**
  /// ([MovementQuery])، ⟵ **فهو معلومٌ هنا يقيناً** ⛔ **ولا يُخمَّن.**
  final String sourceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => InventoryTile(
        title: movement.sourceDocumentNumber,
        // ★★ **أيقونة 🕘 في أول الصفّ** — `FR-M18-10` · `FR-M18-11`
        //   («**سجل حركة النوع**» ضمن الشاشات المشمولة نصّاً).
        //
        // ⚠️⚠️ **والسجل سجلُّ المستند المصدر لا الحركة:** ★ **الحركة ليست
        //   كياناً في قيد التدقيق** — ⛔ **ولا قيدَ يُكتب باسمها**، ⟵ **بل
        //   يُكتب باسم المستند الذي أنشأها** (`inventory.dart` →
        //   `entityId: request.documentNumber`). ★ **فالأيقونة تفتح تاريخ
        //   ذلك المستند**، وهو ما يفسّر الحركة فعلاً.
        leading: auditTrailLeading(
          ref,
          entityType: _entityTypeOf(movement.sourceDocumentType),
          entityId: movement.sourceDocumentNumber,
          title: movement.sourceDocumentNumber,
          sourceId: sourceId,
        ),
        subtitle: movement.direction == MovementDirection.incoming
            ? 'دخول ${quantityLabel(movement.quantity)}'
            : 'خروج ${quantityLabel(movement.quantity)}',
        // ★ **الرصيد التراكمي بعد كل حركة** — `FR-M8-06`.
        trailing: quantityLabel(movement.balanceAfter),
        badges: <Widget>[
          // ★ **الملغاة تُعرَض ولا تختفي** (`A-14`) — ⟵ **فالسجل يشهد بما جرى.**
          if (movement.isCancelled) const CancelledBadge(),
          if (movement.isAmended) const AmendedBadge(),
        ],
      );
}

/// ★★ نوعُ كيان المستند المصدر في سجل التدقيق — ⛔ **ولا نصٌّ محفور**.
///
/// ⚠️⚠️ **ولماذا دالةُ تحويلٍ لا ثابتٌ واحد:** الدفتر صار له **كاتبان**
/// (`WU-003` و`WU-004`) — ★ **وهو بالضبط الدرس المُلحَق بـ`DEBT-24`:**
/// «⛔ **ولا يُفترَض ثابتٌ لأن كاتبه اليوم واحد**». ⟵ **وحرفٌ مختلف هنا
/// يفتح سجلاً فارغاً أبداً** ⛔ **لا خطأً ظاهراً.**
String _entityTypeOf(SourceDocumentType type) => switch (type) {
      SourceDocumentType.countedIntake => countedIntakeEntityType,
      SourceDocumentType.sack => sackEntityType,
      // ★ **وكاتبٌ ثالث منذ `WU-006`** — ⟵ **والسجل السياقي للحركة يفتح
      //   التوزيعة بمعرّفها المركّب** (`FR-M18-10`).
      SourceDocumentType.distribution => distributionEntityType,
      // ★ **وكاتبٌ رابع منذ `WU-012`** — ⟵ **والسجل السياقي للحركة يفتح
      //   سندَ البيع النقدي برقمه** (`FR-M18-10`): ★ **ومعرّفُه رقمُه**
      //   ⛔ **لا معرّفٌ مركّب** (`schema/cash-sales.md`).
      SourceDocumentType.cashSale => cashSaleEntityType,
    };

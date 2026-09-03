/// شاشة **التوزيع والضمار** (`M10`) — **أكثر العمليات تكراراً في اليوم**.
///
/// ★ **هدف الأداء: توزيعة معتادة في أقل من 30 ثانية** (`FR-M10`).
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **وأخطر ما يُساء فهمه في هذه الشاشة — `ت-12` (`FR-M10-07`):**
///
/// **إخفاء عمود السعر لا يعني أن التوزيعة بلا سعر.** ⟵ **السعر يُطبَّق من
/// التسعير اليومي تلقائياً، وقيمة الضمار تُحتسب كاملة، والمديونية تُقيَّد
/// بها** — ★ **والمستخدم لا يراها فقط.**
///
/// ⟵ **ولهذا يُرسَل السعر المقترَح دائماً** حتى ممن لا يملك رؤيته:
/// [suggestedDistributionPricesProvider]، ⛔ **وإسقاطُه كان سيُنشئ ضماراً
/// بصفر لمقوتٍ استلم بضاعة.**
/// ═══════════════════════════════════════════════════════════════════════
///
/// ★★★ **و`AM-009` أعاد بناء الشاشة كلَّها** (2026-08-31) — **من «نموذجٍ
/// دائم» إلى «سجلاتٍ وزرٍّ عائم»:**
///
/// ⛔⛔★★★ **العطلُ الذي عالجه — الشاشةُ كانت نموذجاً لا قائمة:** ★ **تفتح
/// على منتقي مقوتٍ ثم *نموذجِ إدخالٍ مفتوح*** ⟵ **فلا يرى المستخدم توزيعات
/// يومه أبداً**: ⛔ **ولا كم مقوتاً وُزِّع له، ولا أيُّهم بقي**، ★ **ولا
/// مدخلَ لإرسالِ توزيعةٍ إلا بأن يختار صاحبَها فيدخل نموذجَ تعديلها.**
///
/// ✅ **والبنيةُ اليوم:** ① **مرشِّحُ مصدرٍ بـ«الكل»** ② **بحثٌ بالمقوت**
/// ③ **سجلاتٌ باسم المقوت لكلٍّ أربعةُ إجراءات** ④ **وزرٌّ عائمٌ للإضافة.**
///
/// ⛔⛔★★★ **و«الحذف» في الطلب نُفِّذ إلغاءً — وهو حدُّ حَوْكمةٍ لا اختيارَ
/// أسلوب:** ★ **`GR-07` و`ADR-0004` و`CLAUDE.md`: «لا حذف بيانات … لأي
/// مستخدم بمن فيهم المالك»** — ⟵ **والإلغاءُ هو المكافئُ المعتمَد**
/// (`FR-M10-18`): **يَسِم المستند وحركاته فتُستبعَد من كل الأرصدة والتقارير
/// بلا حركاتٍ عكسية**، ★ **وأثرُه على المستخدم هو أثرُ الحذف نفسُه**،
/// ⛔ **والفارقُ أن الأثر يبقى مقروءاً في سجل التدقيق.**
///
/// ⚠️⚠️ **وكل ما هنا عرضٌ لا حماية** — ★ **والرفض الحقيقي في السحابة**
/// (`ADR-0013` القاعدة 3 · `RISK-02`): `distributions` **مغلقة للكتابة**،
/// **والصلاحية والنطاق والرصيد و`GR-18` وحارس السعر كلها في
/// `planDistribution`.**
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show FilteringTextInputFormatter, TextInputFormatter;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qtms_domain/qtms_domain.dart';

import '../../../app/top_bar.dart';

import '../../../core/device/device_preference_providers.dart';
import '../../../core/design/design_tokens.dart';
import '../../../core/messages/error_messages.dart';
import '../../../core/ui/async_state_view.dart';
import '../../../core/ui/context_header.dart';
import '../../../core/ui/destructive_sheet.dart';
import '../../../core/ui/item_line_editor.dart';
import '../../../core/ui/optional_reason.dart';
import '../../../core/ui/key_value_row.dart';
import '../../../core/ui/live_summary.dart';
import '../../../core/ui/search_field.dart';
import '../../../core/ui/status_pill.dart';
import '../../../core/ui/sticky_action_bar.dart';
import '../../master_data/application/master_data_providers.dart';
import '../../identity_access/application/session_providers.dart';
import '../../identity_access/presentation/permission_gate.dart';
import '../../inventory/application/inventory_providers.dart';
import '../../inventory/presentation/inventory_widgets.dart';
import '../../oversight/application/pending_entries_providers.dart';
import '../../oversight/application/messaging_providers.dart';
import '../../oversight/presentation/audit_trail_view.dart';
import '../../oversight/presentation/send_document_sheet.dart';
import '../application/distribution_providers.dart';

/// شاشة التوزيع — ★ **سجلاتٌ ومرشِّحان وزرٌّ عائم** (`AM-009` ⑦).
class DistributionScreen extends ConsumerStatefulWidget {
  /// ينشئ الشاشة.
  const DistributionScreen({super.key});

  @override
  ConsumerState<DistributionScreen> createState() => _DistributionScreenState();
}

class _DistributionScreenState extends ConsumerState<DistributionScreen> {
  /// ★★ **بحثُ المقوت** — `AM-009` ⑦: ⛔ **ولا قائمةٌ منسدلة بمئة مقوت.**
  final TextEditingController _dealerSearch = TextEditingController();

  @override
  void initState() {
    super.initState();
    // ⏳★★★ **وجهةُ زر [ إدخال ] من المركز المعلّق** — `FR-SYS-04`.
    //
    // ⛔⛔★★★ **والاستهلاك بعد أول إطار لا داخل [initState] — عطلٌ مقيسٌ لا
    //    احتياط** (`DEBT-68` · 2026-08-30): ★ **[PendingFocusState.take]
    //    *تكتب* حالةً، وRiverpod يمنع الكتابة في دورة حياة الويدجت.**
    //
    // ★★ **وأثرُه اليوم بحثٌ مضبوطٌ باسم المقوت** — ⛔ **لا نموذجٌ يُفتَح**
    //    (`pending-entries-design.md` §6): ⟵ **فالسجلُّ يظهر مفلتراً
    //    والمستخدم يقرّر.**
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      if (!mounted) return;
      final PendingFocus? focus = ref.read(pendingFocusProvider);
      if (focus == null || focus.kind != PendingDocumentKind.distribution) {
        return;
      }
      ref.read(pendingFocusProvider.notifier).take();
      final String? dealerId = focus.dealerId;
      if (dealerId == null) return;
      final String name = ref
          .read(distributionDealersProvider)
          .where((DealerCard dealer) => dealer.dealerId == dealerId)
          .map((DealerCard dealer) => dealer.name)
          .firstOrNull ??
          '';
      // ⛔ **ومقوتٌ لا يقابله سجلٌّ في القائمة يُهمَل** — ★ **فالشاشة تُفتَح
      //   بلا مرشِّح** ⛔ **ولا تُفتَح على بحثٍ لا يطابق شيئاً.**
      if (name.isEmpty) return;
      setState(() {
        _dealerSearch.text = name;
        ref.read(sourceListFilterProvider.notifier).select(focus.sourceId);
      });
    });
  }

  @override
  void dispose() {
    _dealerSearch.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final CalendarDay today = ref.watch(todayProvider);
    final String? filterId = ref.watch(sourceListFilterProvider);
    final List<SourceCard> sources = ref.watch(activeSourcesProvider);

    return Scaffold(
      appBar: const QtmsTopBar(screenTitle: 'التوزيع'),
      // ④ ★★★ **زرٌّ عائمٌ للإضافة** — `AM-009` ⑦: ⛔ **ولا نموذجٌ مفتوحٌ
      //    يشغل الشاشة قبل أن يطلبه المستخدم.**
      floatingActionButton: sources.isEmpty
          ? null
          : PermissionGate(
              permission: Permission.distributionCreate,
              child: FloatingActionButton.extended(
                onPressed: () => showDistributionForm(
                  context,
                  sourceId: filterId ?? sources.first.sourceId,
                ),
                icon: const Icon(Icons.local_shipping_outlined),
                label: const Text('توزيعة جديدة'),
              ),
            ),
      body: Column(
        children: <Widget>[
          // ① ★★★ **رأس السياق بمرشِّح «كل المصادر»** — `AM-009` ⑦.
          QtmsContextHeader(
            sources: sources,
            selectedSourceId: filterId,
            allowAllSources: true,
            onSourceSelected: (String? id) =>
                ref.read(sourceListFilterProvider.notifier).select(id),
            day: today,
          ),
          // ② ★★★ **بحثُ المقوت لاصقٌ فوق القائمة** — `MASTER.md` §5:
          //    ⛔ **ولا يمرّ مع النتائج** ⟵ **فلا يخرج من الشاشة عند
          //    النتيجة العاشرة.**
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: Spacing.screenPadding,
              vertical: Spacing.space8,
            ),
            child: QtmsSearchField(
              controller: _dealerSearch,
              label: 'بحث بالمقوت',
            ),
          ),
          Expanded(
            child: sources.isEmpty
                ? const QtmsEmptyState(spec: noSourceInScopeEmpty)
                : _DistributionRecords(
                    sourceId: filterId,
                    day: today,
                    search: _dealerSearch,
                    showSource: filterId == null,
                  ),
          ),
        ],
      ),
    );
  }
}

/// ★★★ سجلاتُ اليوم — **باسم المقوت** (`AM-009` ⑦).
class _DistributionRecords extends ConsumerWidget {
  const _DistributionRecords({
    required this.sourceId,
    required this.day,
    required this.search,
    required this.showSource,
  });

  final String? sourceId;
  final CalendarDay day;
  final TextEditingController search;
  final bool showSource;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<DistributionCard>> records = ref.watch(
      distributionListProvider(
        SourceListQuery(sourceId: sourceId, stockDate: day),
      ),
    );

    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: search,
      builder: (BuildContext context, TextEditingValue value, Widget? _) {
        // ⛔⛔★★ **والتطبيع من مصدره الواحد** (`IQ-013`) — ★ **`normalizeName`**:
        //    ⟵ **فـ«الإدخال» تطابق «الادخال»**، ⛔ **ولا تطبيعٌ محليّ.**
        final String needle = normalizeName(value.text);
        return InventoryAsyncView<DistributionCard>(
          value: records,
          emptyIcon: Icons.local_shipping_outlined,
          emptyTitle: 'لا توزيعات اليوم',
          emptyLabel: 'ابدأ بتوزيعةٍ جديدة لتُقيَّد على المقوت فوراً.',
          builder: (List<DistributionCard> list) {
            final List<DistributionCard> shown = needle.isEmpty
                ? list
                : <DistributionCard>[
                    for (final DistributionCard card in list)
                      if (normalizeName(card.dealerName).contains(needle)) card,
                  ];
            if (shown.isEmpty) {
              return QtmsNoMatch(message: 'لا مقوت بهذا الاسم في نتائج اليوم.');
            }
            return ListView.separated(
              padding: const EdgeInsetsDirectional.all(Spacing.screenPadding),
              itemCount: shown.length,
              separatorBuilder: (BuildContext _, int _) =>
                  const SizedBox(height: Spacing.space8),
              itemBuilder: (BuildContext context, int index) =>
                  _DistributionTile(card: shown[index], showSource: showSource),
            );
          },
        );
      },
    );
  }
}

/// ★★★ سجلُّ توزيعةٍ واحدة — **الاسمُ ثم الإجراءات الأربعة.**
class _DistributionTile extends ConsumerWidget {
  const _DistributionTile({required this.card, required this.showSource});

  final DistributionCard card;
  final bool showSource;

  bool get _isCancelled => card.status == DistributionStatus.cancelled;

  @override
  Widget build(BuildContext context, WidgetRef ref) => InventoryTile(
        // ★★★ **العنوانُ اسمُ المقوت** — `AM-009` ⑦: ⛔ **لا رقمُ المستند**:
        //    ⟵ **فالمستخدم يبحث عن «أحمد» لا عن `DST-20260831-0007`.**
        title: card.dealerName,
        leading: auditTrailLeading(
          ref,
          entityType: distributionEntityType,
          entityId: card.distributionId,
          title: card.documentNumber,
          sourceId: card.sourceId,
        ),
        subtitle: <String>[
          card.documentNumber,
          if (showSource) ref.watch(sourceDisplayNameProvider(card.sourceId)),
          '${card.lines.length} نوع',
        ].join(' · '),
        badges: <Widget>[
          if (_isCancelled) const CancelledBadge(),
          if (card.amendCount > 0) const AmendedBadge(),
          // ⏳ **وسمُ السعر غير النهائي يراه الجميع** — ★ **عددٌ لا مبلغ**
          //    (`ADR-0011`).
          if (card.unpricedLineCount > 0)
            const StatusPill(
              label: 'سعر غير نهائي',
              triad: SemanticTriads.warning,
              icon: Icons.hourglass_bottom_outlined,
            ),
        ],
        actions: <Widget>[
          // ★ **عرض** — ⛔ **بلا صلاحية**: ★ **القراءة يحكمها النطاق وحده**
          //   في `firestore.rules` (`isSignedIn() && storedInScope()`).
          IconButton(
            onPressed: () => showDistributionDetails(context, card: card),
            icon: const Icon(Icons.visibility_outlined),
            tooltip: 'عرض التوزيعة',
          ),
          // ★ **إرسال أو تصدير** — `FR-M20-04`.
          _SendAction(card: card),
          if (!_isCancelled)
            PermissionGate(
              permission: Permission.distributionAmend,
              child: IconButton(
                onPressed: () => showDistributionForm(
                  context,
                  sourceId: card.sourceId,
                  dealerId: card.dealerId,
                ),
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'تعديل التوزيعة',
              ),
            ),
          // ⛔⛔★★★ **ولا زرَّ حذفٍ إطلاقاً** — راجع ترويسة الملف: ★ **الإلغاء
          //    هو المكافئُ المعتمَد** (`GR-07` · `FR-M10-18`).
          if (!_isCancelled)
            PermissionGate(
              permission: Permission.distributionCancel,
              child: IconButton(
                onPressed: () => showCancelDistributionSheet(context, card: card),
                icon: const Icon(Icons.block_outlined),
                tooltip: 'إلغاء التوزيعة',
                color: SemanticTriads.danger.ink,
              ),
            ),
        ],
      );
}

// ═════════════════════════════════════════════════════════════════════════
// ورقة العرض
// ═════════════════════════════════════════════════════════════════════════

/// ★★ يفتح ورقة عرض التوزيعة — **قراءةٌ محضة**.
Future<void> showDistributionDetails(
  BuildContext context, {
  required DistributionCard card,
}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: SemanticColors.surface,
      builder: (BuildContext context) => DistributionDetailsSheet(card: card),
    );

/// ورقة عرض التوزيعة.
///
/// ⛔⛔★★ **وقيمةُ الضمار لمن يملك رؤيتها وحده** (`ت-12`) — ★ **ومصدرُها
/// `pricing/current`** ⛔ **لا حسابٌ محليّ.**
class DistributionDetailsSheet extends ConsumerWidget {
  /// ينشئ الورقة.
  const DistributionDetailsSheet({required this.card, super.key});

  /// التوزيعة المعروضة.
  final DistributionCard card;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool canSeePrices =
        ref.watch(hasPermissionProvider(Permission.distributionPriceView));
    final DistributionPricingCard? pricing =
        ref.watch(distributionPricingProvider(card.distributionId)).value;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.all(Spacing.space16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(card.dealerName, style: TypeScale.titleLg),
            const SizedBox(height: Spacing.space12),
            QtmsKeyValueRow(label: 'المستند', value: card.documentNumber),
            QtmsKeyValueRow(
              label: 'المصدر',
              value: ref.watch(sourceDisplayNameProvider(card.sourceId)),
            ),
            const SizedBox(height: Spacing.space16),
            for (final ValidatedDistributionLine line in card.lines)
              QtmsKeyValueRow(
                label: line.itemName,
                value: quantityLabel(line.quantity),
              ),
            const SizedBox(height: Spacing.space16),
            // ⛔⛔★★ **والإجماليان منفصلان دائماً** (`GR-19` · `FR-M10-15`).
            QtmsKeyValueRow(
              label: 'إجمالي الحبات',
              value: '${card.totalPieces.pieces} حبة',
            ),
            QtmsKeyValueRow(
              label: 'إجمالي الأوزان',
              value: '${card.totalWeight.formatted()} كجم',
            ),
            if (canSeePrices && pricing != null)
              QtmsKeyValueRow(
                label: 'قيمة الضمار',
                value: '${pricing.debtValue.riyals} ريال',
              ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════
// ورقة الإلغاء
// ═════════════════════════════════════════════════════════════════════════

/// يفتح ورقة إلغاء التوزيعة — ★ **والسببُ اختياريٌّ** (`ADR-0020`).
Future<void> showCancelDistributionSheet(
  BuildContext context, {
  required DistributionCard card,
}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: SemanticColors.surface,
      builder: (BuildContext context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: CancelDistributionSheet(card: card),
      ),
    );

/// ورقة إلغاء التوزيعة.
class CancelDistributionSheet extends ConsumerWidget {
  /// ينشئ الورقة.
  const CancelDistributionSheet({required this.card, super.key});

  /// التوزيعة الملغاة.
  final DistributionCard card;

  @override
  Widget build(BuildContext context, WidgetRef ref) => QtmsDestructiveSheet(
        title: 'إلغاء توزيعة ${card.dealerName}',
        // ★ **الإلغاء وسمٌ لا حذف** — `GR-06` · `GR-07` · `FR-M10-18`.
        impact: 'الإلغاء يَسِم التوزيعة وحركاتها ولا يحذف شيئاً، فتُستبعَد من '
            'كل الأرصدة والتقارير. ويُرفَض إن كان الضمار قد سُدِّد كلياً أو '
            'جزئياً.',
        confirmLabel: 'تأكيد الإلغاء',
        reasonLabel: 'سبب الإلغاء (اختياري)',
        onConfirm: (DestructiveConfirmation confirmation) async {
          // ⛔⛔★★★ **ولا حارسَ على السبب** — `ADR-0020`.
          final Outcome<void> result =
              await ref.read(distributionAdminProvider).cancelDistribution(
                    documentNumber: card.documentNumber,
                    sourceId: card.sourceId,
                    dealerId: card.dealerId,
                    cancelReason: blankToNull(confirmation.reason),
                  );
          return switch (result) {
            Failure<void>(:final AppError error) =>
              catalogText(appErrorMessage(error)),
            Success<void>() => null,
          };
        },
      );
}

// ═════════════════════════════════════════════════════════════════════════
// نموذج التوزيعة
// ═════════════════════════════════════════════════════════════════════════

/// ★★★ يفتح نموذج التوزيعة — **إنشاءً أو تعديلاً** (`AM-009` ⑦).
Future<void> showDistributionForm(
  BuildContext context, {
  required String sourceId,
  String? dealerId,
}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: SemanticColors.surface,
      builder: (BuildContext context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: DistributionFormSheet(sourceId: sourceId, dealerId: dealerId),
      ),
    );

/// ورقة نموذج التوزيعة.
///
/// ⚠️⚠️ **وتفتح الموجود للتعديل تلقائياً** — `FR-M10-01` (`E-04`): «**عند
/// المحاولة يُفتح المستند الموجود للتعديل ولا يُنشأ مستند ثانٍ**».
/// ⟵ ★ **والورقة تعرف ذلك قبل الحفظ** بمراقبة توزيعة (المقوت × المصدر ×
/// اليوم)، ⛔ **فلا تُرسل إنشاءً يُرفَض.**
class DistributionFormSheet extends ConsumerStatefulWidget {
  /// ينشئ الورقة.
  const DistributionFormSheet({
    required this.sourceId,
    this.dealerId,
    super.key,
  });

  /// المصدر الابتدائي.
  final String sourceId;

  /// المقوت الابتدائي — و`null` تعني **إنشاءً بلا اختيارٍ بعد**.
  final String? dealerId;

  @override
  ConsumerState<DistributionFormSheet> createState() =>
      _DistributionFormSheetState();
}

class _DistributionFormSheetState
    extends ConsumerState<DistributionFormSheet> {
  final TextEditingController _reason = TextEditingController();
  late String _sourceId = widget.sourceId;
  late String? _dealerId = widget.dealerId;

  /// ★★★ **سطورٌ يُنشئها المستخدم** — `AM-009` ④ (راجع [QtmsItemLineRow]).
  final List<_DistLine> _lines = <_DistLine>[];

  /// ★ معرّفُ ما بُذر منه — ⛔ **ولا يُعاد الملء عند كل بناء**: ⟵ **وإلا مسح
  /// ما يكتبه المستخدم كلما وصل تحديثٌ من جهازٍ آخر.**
  String? _seededId;

  bool _submitting = false;
  bool _saved = false;
  CatalogMessage? _rejection;

  @override
  void dispose() {
    _reason.dispose();
    for (final _DistLine line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final CalendarDay today = ref.watch(todayProvider);
    final List<SourceCard> sources = ref.watch(activeSourcesProvider);
    // ⛔★★ **ولا يظهر مقوتٌ معطَّل** — `FR-M10-12`.
    final List<DealerCard> dealers = ref.watch(distributionDealersProvider);
    // ⛔⛔★★★ **والخياراتُ من أرصدة الدفتر لا من كتالوج الأنواع** —
    //    [`DEBT-86`] · `ADR-0007`: راجع [stockOptionsProvider].
    final List<StockOption> items = ref.watch(
      stockOptionsProvider(StockQuery(sourceId: _sourceId, stockDate: today)),
    );
    final DistributionQuery query =
        DistributionQuery(sourceId: _sourceId, stockDate: today);
    // ⛔⛔★★★ **ويُراقَب لا يُقرأ لحظة الحفظ** — ⟵ **فالقراءة المتأخرة كانت
    //   تجد التدفّق لم يُشترَك بعد فتعود فارغة**، ★ **فيُرسَل السطر بلا سعر
    //   وينشأ ضمارٌ بصفر لمقوتٍ استلم بضاعة** (`FR-M10-07`).
    final Map<String, Money> suggested =
        ref.watch(suggestedDistributionPricesProvider(query));

    final bool canSeePrices =
        ref.watch(hasPermissionProvider(Permission.distributionPriceView));
    final bool canAmendPrice =
        ref.watch(hasPermissionProvider(Permission.distributionPriceAmend));
    final bool canClearPrice =
        ref.watch(hasPermissionProvider(Permission.distributionPriceClear));

    // ⛔⛔★★★ **ومن قائمة اليوم لا بقراءةٍ بالمعرّف** — `DEBT-40`: **القراءة
    //    بالمعرّف تُرفَض على المستند الغائب** لأن `storedInScope()` يقرأ
    //    `resource.data.sourceId`، ⟵ **وهو أشيعُ حالات `E-04`.**
    final DistributionCard? existing = switch (_dealerId) {
      final String dealerId => ref
          .watch(
            dealerDistributionProvider(
              DealerDistributionQuery(
                sourceId: _sourceId,
                dealerId: dealerId,
                stockDate: today,
              ),
            ),
          )
          .value,
      null => null,
    };
    // ★★★ **والأسعارُ من مستندها الفرعي وحدَه** — [`ADR-0011`] · `ت-12`:
    //    ⟵ **`DistributionCard.lines[].unitPrice` فارغٌ دائماً بالتصميم**،
    //    ⛔ **فبذرُ السعر منه كان لا يقع أبداً** (`DEBT-87`).
    final AsyncValue<DistributionPricingCard?> existingPricing =
        existing == null
            ? const AsyncValue<DistributionPricingCard?>.data(null)
            : ref.watch(distributionPricingProvider(existing.distributionId));
    _seedFrom(existing, existingPricing);

    final bool isAmend = existing != null;
    final bool isCancelled = existing?.status == DistributionStatus.cancelled;

    // ★★ **تفضيلُ إظهار وزن الحبة** — `AM-012` §4.4: ⛔ **عرضٌ محضٌ**
    //    ⟵ **ولا يمسّ وحدةَ الكمية ولا أي حساب.**
    final bool showPieceWeight = ref.watch(showPieceWeightProvider);
    final List<QtmsItemOption> options = <QtmsItemOption>[
      for (final StockOption item in items)
        QtmsItemOption(
          id: item.itemKey,
          // ⑥ ★★★ **«اسم النوع (المتبقّي منه)»** — `FR-M10-06` حرفياً.
          // ★★ **ووزنُ الحبة عند تفعيل الخيار** — `AM-012` §4.4.
          label: itemOptionLabel(
            item.itemName,
            item.balance,
            showPieceWeight: showPieceWeight,
            pieceWeightGrams: item.pieceWeightGrams,
          ),
        ),
    ];
    final Map<String, StockOption> itemsById = <String, StockOption>{
      for (final StockOption item in items) item.itemKey: item,
    };

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * _sheetHeightRatio,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsetsDirectional.all(Spacing.space16),
              child: Text(
                isAmend ? 'تعديل التوزيعة' : 'توزيعة جديدة',
                style: TypeScale.titleLg,
              ),
            ),
            Flexible(
              child: ListView(
                padding: const EdgeInsetsDirectional.only(
                  start: Spacing.screenPadding,
                  end: Spacing.screenPadding,
                  bottom: Spacing.screenPadding,
                ),
                children: <Widget>[
                  // ★★ **المقوت والمصدر حقلان في النموذج** — `AM-009` ⑦.
                  //
                  // ⛔ **والمقوتُ مقفلٌ متى فُتح مستندٌ قائم** — `GR-18`:
                  //    ⟵ **فتبديلُه يعني توزيعةً أخرى لا تعديلَ هذه.**
                  _DealerField(
                    dealers: dealers,
                    selected: _dealerId,
                    onSelected: _onDealerChanged,
                  ),
                  const SizedBox(height: Spacing.space12),
                  DropdownButtonFormField<String>(
                    initialValue:
                        sources.any((SourceCard s) => s.sourceId == _sourceId)
                            ? _sourceId
                            : null,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'المصدر'),
                    items: <DropdownMenuItem<String>>[
                      for (final SourceCard source in sources)
                        DropdownMenuItem<String>(
                          value: source.sourceId,
                          child:
                              Text(source.name, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: isAmend ? null : _onSourceChanged,
                  ),
                  const SizedBox(height: Spacing.space16),
                  if (isAmend) _ExistingBanner(card: existing),
                  if (isCancelled)
                    Text(
                      'هذه التوزيعة ملغاة — لا يمكن تعديلها.',
                      style: TypeScale.bodyMd
                          .copyWith(color: SemanticTriads.danger.ink),
                    )
                  else ...<Widget>[
                    Text(
                      'الأنواع',
                      style: TypeScale.label
                          .copyWith(color: SemanticColors.textSecondary),
                    ),
                    const SizedBox(height: Spacing.space8),
                    for (final (int index, _DistLine line) in _lines.indexed)
                      QtmsItemLineRow(
                        key: ValueKey<int>(line.seed),
                        options: optionsForRow(
                          all: options,
                          takenIds: <String?>[
                            for (final _DistLine other in _lines) other.itemId,
                          ],
                          ownId: line.itemId,
                        ),
                        selectedId: line.itemId,
                        onSelected: (String id) => setState(() {
                          line.itemId = id;
                          // ★★ **والسعرُ المقترَح يُملأ عند الاختيار** —
                          //    `FR-M10-09`: ⟵ **فالمعتادُ لا يُكتَب**،
                          //    ⛔ **وما يُملأ هنا هو ما يراه المستخدم فعلاً.**
                          if (canSeePrices && line.price.text.isEmpty) {
                            line.price.text =
                                suggested[id]?.riyals.toString() ?? '';
                          }
                        }),
                        onRemove: () =>
                            setState(() => _lines.removeAt(index).dispose()),
                        fields: <Widget>[
                          _quantityField(line, itemsById[line.itemId]),
                          if (canSeePrices)
                            _priceField(
                              line,
                              canEdit: canAmendPrice || canClearPrice,
                              canClear: canClearPrice,
                            ),
                        ],
                      ),
                    if (items.isEmpty)
                      Text(
                        // ★ **والعلّةُ رصيدٌ لا ربطٌ** — [`DEBT-86`]:
                        //   ⟵ **فالخياراتُ من دفتر اليوم.**
                        'لا مخزون في هذا المصدر اليوم.',
                        style: TypeScale.bodyMd
                            .copyWith(color: SemanticColors.textSecondary),
                      ),
                    if (items.isNotEmpty)
                      QtmsAddLineButton(
                        onPressed: _dealerId == null ||
                                _lines.length >= items.length
                            ? null
                            : () => setState(() => _lines.add(_DistLine())),
                      ),
                    if (canSeePrices && canClearPrice) ...<Widget>[
                      const SizedBox(height: Spacing.space8),
                      Text(
                        // ★★ **«تسعير لاحق» فعلٌ صريحٌ مُسمّى** — `FR-M10-08`:
                        //    ⟵ **والسطرُ يدخل مركز الإدخالات المعلّقة.**
                        'اترك السعر فارغاً للتسعير لاحقاً — يدخل السطر مركز '
                        'الإدخالات المعلّقة.',
                        style: TypeScale.caption
                            .copyWith(color: SemanticColors.textSecondary),
                      ),
                    ],
                    if (isAmend) ...<Widget>[
                      const SizedBox(height: Spacing.space16),
                      // ⛔⛔★★★ **ولا يُعبَّأ آلياً أبداً** — `ADR-0020` القيد ①.
                      TextField(
                        controller: _reason,
                        decoration: const InputDecoration(
                          labelText: 'سبب التعديل (اختياري)',
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
            // ⑦⑧ ★★★ **الملخّصُ المالي ثابتٌ فوق الزرّ** — §5b `P8`.
            if (!isCancelled)
              QtmsStickyActionBar(
                summary:
                    _totals(_linesFor(itemsById, suggested, canSeePrices)),
                status: switch ((_rejection, _saved)) {
                  (final CatalogMessage message, _) =>
                    QtmsActionStatus.rejection(catalogText(message)),
                  (null, true) => QtmsActionStatus.success('تم الحفظ.'),
                  _ => null,
                },
                primary: PermissionGate(
                  permission: isAmend
                      ? Permission.distributionAmend
                      : Permission.distributionCreate,
                  child: FilledButton.icon(
                    onPressed: _submitting || _dealerId == null
                        ? null
                        : () => _submit(existing, itemsById, suggested,
                            canSeePrices),
                    icon: const Icon(Icons.save_outlined),
                    label: Text(isAmend ? 'حفظ التعديل' : 'حفظ التوزيعة'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// ★ نسبةُ ارتفاع الورقة — ⛔ **ولا رقمَ عارٍ في التخطيط**.
  static const double _sheetHeightRatio = 0.9;

  Widget _quantityField(_DistLine line, StockOption? item) => TextField(
        controller: line.quantity,
        keyboardType: TextInputType.numberWithOptions(
          decimal: item?.unit == ItemUnit.kilogram,
        ),
        // ⛔★★ **والكسر مرفوض في المعدود من المُدخِل نفسه**
        //    (`BR-M6-06` · `ERR_STOCK_002`).
        inputFormatters: <TextInputFormatter>[
          if (item?.unit == ItemUnit.kilogram)
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
          else
            FilteringTextInputFormatter.digitsOnly,
        ],
        decoration: InputDecoration(
          labelText: 'الكمية',
          suffixText: item == null ? null : unitName(item.unit),
        ),
        onChanged: (String _) => setState(() {}),
      );

  /// ★★ حقلُ السعر — **يظهر لمن يراه، ويُحرَّر لمن يملك تغييره.**
  ///
  /// ⛔⛔★★★ **وإخفاؤه تسهيلُ واجهةٍ لا حماية** — `FR-M10-10`: ★ **القاعدة
  /// والدالة ترفضان سعراً من مُرسِلٍ لا يملك المفتاح** ⛔ **حتى من خارج
  /// التطبيق**، ⟵ **فما هنا عرضٌ محض.**
  Widget _priceField(
    _DistLine line, {
    required bool canEdit,
    required bool canClear,
  }) =>
      TextField(
        controller: line.price,
        readOnly: !canEdit,
        keyboardType: const TextInputType.numberWithOptions(),
        // ⛔★★ **ولا كسرَ في مبلغ** — `ADR-0015`.
        inputFormatters: <TextInputFormatter>[
          FilteringTextInputFormatter.digitsOnly,
        ],
        decoration: InputDecoration(
          labelText: canClear ? 'السعر (أو اتركه لاحقاً)' : 'السعر',
          suffixText: 'ريال',
        ),
        onChanged: (String _) => setState(() {}),
      );

  /// ★★ يملأ الحقول من التوزيعة القائمة **مرةً واحدة لكل مستند** — `E-04`.
  /// ★★ يملأ النموذج من المستند القائم — **للتعديل**.
  ///
  /// ⛔⛔★★★ **والسعرُ يُبذَر معها — `DEBT-87` (مقيسٌ على المحاكي 2026-09-02):**
  /// ★ **كان النوعُ والكميةُ وحدَهما يُبذَران** ⟵ **فيُفتَح النموذجُ بحقلِ
  /// سعرٍ فارغ**، ⛔⛔ **وحفظُه يُرسِل `unitPrice: null`** ⟹ **فيُقرأ
  /// «تفريغَ سعرٍ قائم»** (`distributionPriceClear`) ★ **فتنهار قيمةُ الضمار
  /// إلى صفر بلا أن يقصد المستخدم شيئاً** — ⛔ **ومن عدّل الكمية وحدَها
  /// خسِر السعر.**
  ///
  /// ★ **و`unitPrice` غائبٌ أصلاً لمن لا يملك `distributionPriceView`**
  /// (`ت-12`) — ⟵ **فيبقى الحقلُ فارغاً له كما كان**، ⛔ **ولا يُكشَف سعرٌ
  /// لمن لا يراه.**
  void _seedFrom(
    DistributionCard? card,
    AsyncValue<DistributionPricingCard?> pricing,
  ) {
    if (card == null || _seededId == card.distributionId) return;
    // ⛔⛔★★ **ولا يُبذَر ومستندُ الأسعار ما يزال يُحمَّل** — ⟵ **وإلا بُذر
    //    الحقلُ فارغاً ثم قُفل البذرُ بـ`_seededId`** ⟹ **فيضيع السعر
    //    كما لو لم يُصلَح شيء** (`DEBT-87`).
    //
    // ⛔ **و«لا يوجد» ليست «لم تصل بعد»** — ★ **ومستندٌ غائبٌ يصل `data(null)`
    //    فيُبذَر فارغاً وهو الصواب** (`FR-M10-08`: **مستندٌ بلا سعرٍ بعد**)،
    //    ⟵ **ومن لا يملك `distributionPriceView` يصله `null` كذلك** (`ت-12`).
    if (pricing.isLoading) return;
    _seededId = card.distributionId;
    for (final _DistLine line in _lines) {
      line.dispose();
    }
    _lines
      ..clear()
      ..addAll(<_DistLine>[
        for (final ValidatedDistributionLine line in card.lines)
          _DistLine(
            itemId: line.itemKey,
            quantity: switch (line.quantity) {
              PieceQuantity(:final PieceCount count) => '${count.pieces}',
              WeightQuantity(:final WeightKg weight) => weight.formatted(),
            },
            price: _priceTextAt(pricing.value, card.lines.indexOf(line)),
          ),
      ]);
  }

  /// ★ نصُّ سعرِ السطر من مستند الأسعار — ⛔ **والفارغ «تسعيرٌ لاحق»**.
  static String _priceTextAt(DistributionPricingCard? pricing, int index) {
    if (pricing == null || index < 0 || index >= pricing.unitPrices.length) {
      return '';
    }
    final Money? price = pricing.unitPrices[index];
    return price == null ? '' : '${price.riyals}';
  }

  void _onDealerChanged(String id) {
    if (id == _dealerId) return;
    setState(() {
      _dealerId = id;
      _resetLines();
    });
  }

  void _onSourceChanged(String? id) {
    if (id == null || id == _sourceId) return;
    setState(() {
      _sourceId = id;
      _resetLines();
    });
  }

  /// ⛔ **وتبديلُ المقوت أو المصدر يُفرِغ السطور** — ★ **فالأنواع والأسعار
  /// والمتبقّي كلُّها مشتقّةٌ من المصدر** (`A-01`)، ⟵ **والمستندُ المفتوح
  /// يتبع (المقوت × المصدر × اليوم)** (`GR-18`).
  void _resetLines() {
    for (final _DistLine line in _lines) {
      line.dispose();
    }
    _lines.clear();
    _seededId = null;
    _rejection = null;
    _saved = false;
  }

  /// ★ السطور المكتوبة فعلاً — ⛔ **والفارغ ليس سطراً**.
  List<DistributionLineInput> _linesFor(
    Map<String, StockOption> itemsById,
    Map<String, Money> suggested,
    bool canSeePrices,
  ) {
    final List<DistributionLineInput> lines = <DistributionLineInput>[];
    for (final _DistLine line in _lines) {
      final StockOption? item = itemsById[line.itemId];
      if (item == null) continue;
      final StockQuantity? quantity =
          _quantityOf(item.unit, line.quantity.text.trim());
      if (quantity == null) continue;
      lines.add(
        DistributionLineInput(
          // ★★ **ومفتاحُ الدفتر هو المُرسَل** — `ADR-0007`: ⟵ **مركّباً كان
          //    أو مجرَّداً**، ⛔ **ولا معرّفَ سجلِ نوعٍ يُشتقّ منه.**
          itemId: item.itemKey,
          itemName: item.itemName,
          unit: item.unit,
          quantity: quantity,
          // ★★★ **ويُرسَل حتى لمن لا يراه** — راجع ترويسة الملف (`ت-12`):
          //    ⟵ **فمن لا يملك `distributionPriceView` يُرسَل عنه المقترَح
          //    كاملاً**، ⛔ **ولا يُرسَل غياباً فيُنشأ ضمارٌ بصفر.**
          unitPrice: canSeePrices
              ? Money.tryParseInput(line.price.text.trim())
              : suggested[item.itemKey],
        ),
      );
    }
    return lines;
  }

  /// ★ الكمية بوحدة النوع — و`null` لمُدخَلٍ لا يصلح لتلك الوحدة.
  static StockQuantity? _quantityOf(ItemUnit unit, String text) {
    if (text.isEmpty) return null;
    switch (unit) {
      case ItemUnit.piece:
        final PieceCount? count = PieceCount.tryParseInput(text);
        return count == null ? null : PieceQuantity(count);
      case ItemUnit.kilogram:
        final WeightKg? weight = WeightKg.tryParseInput(text);
        return weight == null ? null : WeightQuantity(weight);
    }
  }

  Future<void> _submit(
    DistributionCard? card,
    Map<String, StockOption> itemsById,
    Map<String, Money> suggested,
    bool canSeePrices,
  ) async {
    final String? dealerId = _dealerId;
    if (dealerId == null) return;

    final Outcome<ValidatedDistribution> validated = validateDistribution(
      DistributionInput(
        sourceId: _sourceId,
        dealerId: dealerId,
        lines: _linesFor(itemsById, suggested, canSeePrices),
      ),
    );
    if (validated is Failure<ValidatedDistribution>) {
      setState(() => _rejection = CatalogMessage.operationFailed);
      return;
    }
    final ValidatedDistribution distribution =
        (validated as Success<ValidatedDistribution>).value;

    setState(() {
      _submitting = true;
      _rejection = null;
      _saved = false;
    });

    final DistributionAdminRepository repository =
        ref.read(distributionAdminProvider);
    final Outcome<void> outcome = card == null
        ? await repository.createDistribution(distribution)
        : await repository.amendDistribution(
            documentNumber: card.documentNumber,
            distribution: distribution,
            amendReason: blankToNull(_reason.text),
          );
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _saved = outcome is Success<void>;
      _rejection =
          outcome is Failure<void> ? appErrorMessage(outcome.error) : null;
    });
    // ★ **وورقةٌ نجحت تُغلَق** — ⛔ **ولا تبقى مفتوحةً على مستندٍ حُفظ**:
    //   ⟵ **فالسجلُّ في القائمة خلفها هو الدليل.**
    if (outcome is Success<void> && mounted) Navigator.of(context).pop();
  }
}

/// ★★★ حقلُ المقوت — **منسدلٌ يُكتَب فيه فيُصفّي** (`AM-009` ⑦).
class _DealerField extends StatelessWidget {
  const _DealerField({
    required this.dealers,
    required this.selected,
    required this.onSelected,
  });

  final List<DealerCard> dealers;
  final String? selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) =>
            DropdownMenu<String>(
          // ⛔⛔★★★ **وعرضٌ محدودٌ صريح** — `DEBT-63`.
          width: constraints.maxWidth,
          initialSelection: selected,
          label: const Text('المقوت'),
          enableFilter: true,
          enableSearch: true,
          requestFocusOnTap: true,
          menuHeight: Sizes.listRowHeight * 4,
          onSelected: (String? value) {
            if (value != null) onSelected(value);
          },
          dropdownMenuEntries: <DropdownMenuEntry<String>>[
            for (final DealerCard dealer in dealers)
              DropdownMenuEntry<String>(
                value: dealer.dealerId,
                label: dealer.name,
              ),
          ],
        ),
      );
}

/// ★★★ **الملخّصُ المالي الثابت** — §5b نمط `P8` البند ⑦ (`ADR-0021`).
///
/// ⛔⛔★★ **والإجماليان منفصلان دائماً** (`GR-19` · `FR-M10-15`) — ★ **سطران
/// مستقلّان** ⛔ **ولا سطرَ ثالثٌ يجمعهما.**
///
/// ⚠️ **والجمعُ هنا عرضٌ لا معادلة** — ★ **مجموعُ ما كتبه المستخدمُ لحظتَه**،
/// ⛔ **ولا قاعدةَ عملٍ فيه** (`ADR-0010` القاعدة 1).
Widget _totals(List<DistributionLineInput> lines) {
  int pieces = 0;
  double kilograms = 0;
  bool unpriced = false;
  for (final DistributionLineInput line in lines) {
    switch (line.quantity) {
      case PieceQuantity(:final PieceCount count):
        pieces += count.pieces;
      case WeightQuantity(:final WeightKg weight):
        kilograms += weight.kilograms;
    }
    if (line.unitPrice == null) unpriced = true;
  }
  return QtmsLiveSummary(
    headline: 'إجمالي الحبات: $pieces حبة',
    details: <String>[
      'إجمالي الأوزان: ${kilograms.toStringAsFixed(WeightKg.decimals)} كجم',
      if (unpriced) 'سطورٌ بلا سعر — تُسعَّر لاحقاً',
    ],
    // ⛔⛔★★★ **ولا قيمةَ ضمارٍ محسوبةٌ هنا** — `ADR-0010` القاعدة 1 ·
    //    `design-system.md` §5.1: ★ **ضربُ السعر في الكمية معادلةُ عملٍ**،
    //    ⟵ **وتكرارُها في شاشة يخالف «لا تكرار لأي معادلة خارج طبقة
    //    النطاق»** (`CLAUDE.md`). ★ **والضمارُ المقيَّد يُقرأ من
    //    `pricing/current` في ورقة العرض بعد الحفظ** ⛔ **لا يُقدَّر قبله.**
    emphasis: null,
  );
}

/// ★★ شارة «يوجد توزيع — فُتح للتعديل» — `E-04` · `ERR_DIST_001`.
class _ExistingBanner extends StatelessWidget {
  const _ExistingBanner({required this.card});

  final DistributionCard card;

  @override
  Widget build(BuildContext context) => Card(
        color: SemanticColors.surfaceSunken,
        child: ListTile(
          title: Text(card.documentNumber, style: TypeScale.bodyMd),
          subtitle: Text(
            'يوجد توزيع لهذا المقوت اليوم — فُتح للتعديل'
            '${card.amendCount > 0 ? ' · مُعدَّل ×${card.amendCount}' : ''}'
            '${card.hasUnpricedLines ? ' · سعر غير نهائي' : ''}',
          ),
        ),
      );
}

/// تحرير سطرٍ محلي — **نوعٌ وكميةٌ وسعر.**
class _DistLine {
  _DistLine({this.itemId, String quantity = '', String price = ''})
      : quantity = TextEditingController(text: quantity),
        price = TextEditingController(text: price),
        seed = _nextSeed++;

  static int _nextSeed = 0;

  /// النوع — و`null` تعني **صفّاً لم يُختَر نوعُه بعد**.
  String? itemId;

  /// الكمية المكتوبة.
  final TextEditingController quantity;

  /// ★ السعر المكتوب — **وفراغُه «تسعيرٌ لاحق»** (`FR-M10-08`).
  final TextEditingController price;

  /// مفتاحٌ ثابت للصفّ — ⛔ **ولا الموضعُ مفتاحاً.**
  final int seed;

  void dispose() {
    quantity.dispose();
    price.dispose();
  }
}

/// ★★★ زرُّ الإرسال والتصدير — `M20` (`WU-010`).
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★ **ولا يحسب شيئاً** (`design-system.md` §5.1): ★ **الأسعار وقيم
/// السطور من `pricing/current`** (`ADR-0011`) · **والرصيد من
/// `dealer_balances`** · **والنصوص من طبقة النطاق** — ⟵ **فالرسالةُ
/// والملفُّ يخرجان من مصدرٍ واحد** ⛔ **ولا يفترقان رقماً واحداً.**
///
/// ⚠️⚠️ **والقالب ② مشروطٌ بشرطين معاً لا واحد:** ★ **كل السطور مسعَّرة**
/// (`FR-M20-03` · `AT-63`) · ★ **والرصيد مقروءٌ فعلاً** — ⟵ **فمن لا يملك
/// `dealerBalanceView` لا يستطيع أن يضع رصيداً في رسالة**، ⛔ **ولا يُخترَع
/// له صفر.**
/// ═══════════════════════════════════════════════════════════════════════
class _SendAction extends ConsumerWidget {
  const _SendAction({required this.card});

  final DistributionCard card;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool canSend =
        ref.watch(hasPermissionProvider(Permission.messagingSend));
    final bool canExport =
        ref.watch(hasPermissionProvider(Permission.documentExport));
    // ★ **ولا يظهر الزرّ لمن لا يملك أياً منهما** — ⛔ **ولا يظهر معطَّلاً**:
    //   ⟵ **«الصلاحيات تُخفي لا تُعطِّل»** (`ui-guidelines.md` §2).
    if (!canSend && !canExport) return const SizedBox.shrink();

    final MessageBusiness business = ref.watch(messageBusinessProvider);
    final String sourceName =
        ref.watch(sourceDisplayNameProvider(card.sourceId));
    final DistributionPricingCard? pricing =
        ref.watch(distributionPricingProvider(card.distributionId)).value;
    final DealerBalanceCard? balance = ref
        .watch(
          dealerBalanceProvider(
            DealerBalanceQuery(
              dealerId: card.dealerId,
              sourceId: card.sourceId,
            ),
          ),
        )
        .value;
    final String phone = ref
        .watch(distributionDealersProvider)
        .where((DealerCard dealer) => dealer.dealerId == card.dealerId)
        .map((DealerCard dealer) => dealer.phone)
        .firstOrNull ??
        '';

    final DistributionMessageData data = _messageData(pricing, balance);
    // ★ **الشرطان معاً** — راجع ترويسة الصنف.
    final bool priced =
        pricing != null && card.unpricedLineCount == 0 && balance != null;

    return IconButton(
      onPressed: () => showQtmsSendSheet(
        context,
        document: SendableDocument(
          title: 'إرسال التوزيعة',
          offersTemplateChoice: true,
          pricedTemplateAvailable: priced,
          phone: phone,
          renderMessage: (MessageTemplate template) =>
              renderDistributionMessage(
            business: business,
            data: data,
            template: template,
          ),
          renderShortMessage: () => renderShortDistributionMessage(
            business: business,
            data: data,
          ),
          buildExport: (MessageTemplate template) => buildDistributionExport(
            business: business,
            data: data,
            sourceId: card.sourceId,
            sourceName: sourceName,
            entityId: card.distributionId,
            withPricing: template == MessageTemplate.distributionWithPricing,
          ),
        ),
      ),
      icon: const Icon(Icons.send_outlined),
      tooltip: 'إرسال أو تصدير',
    );
  }

  /// ★ يجمع بيانات الرسالة — ⛔ **بلا حسابٍ إلا ما تُجريه طبقة النطاق**.
  DistributionMessageData _messageData(
    DistributionPricingCard? pricing,
    DealerBalanceCard? balance,
  ) {
    final Money current = balance?.balance.balance ?? Money.zero;
    final Money debt = pricing?.debtValue ?? Money.zero;
    return DistributionMessageData(
      dealerName: card.dealerName,
      stockDate: card.stockDate,
      lines: <MessageLine>[
        for (int i = 0; i < card.lines.length; i++)
          MessageLine(
            itemName: card.lines[i].itemName,
            quantity: card.lines[i].quantity,
            // ★ **والأسعار موازيةٌ لترتيب السطور** (`DistributionPricingCard`).
            unitPrice: _at(pricing?.unitPrices, i),
            lineTotal: _at(pricing?.lineTotals, i),
          ),
      ],
      debtValue: debt,
      // ★★ **والمعادلة في طبقة النطاق** — ⛔ **لا طرحٌ في شاشة.**
      previousBalance:
          balanceBeforeTodayDebt(currentBalance: current, todayDebt: debt),
      currentBalance: current,
    );
  }

  /// ★ عنصرٌ بموضعه — و`null` لقائمةٍ أقصر (⛔ **ولا رميٌ على طول مختلف**).
  static Money? _at(List<Money?>? values, int index) =>
      values != null && index < values.length ? values[index] : null;
}

/// شاشة **الوارد جواني** (`M7`) — **نمطا 2 و4** (`ui-guidelines.md` §3).
///
/// ⛔★★ **ولا حقل تاريخ في النموذج إطلاقاً** — `FR-M7-02`: «**تاريخ التوريد
/// تاريخ اليوم من الخادم، مقفلاً وغير قابل للتغيير إطلاقاً**». ⟵ ★ **وما
/// لا يُعرَض لا يُحاوَل تغييره**، **والشريط المقفل يُخبر المستخدم لماذا.**
///
/// ⛔★★ **ولا حقل للرقم المتسلسل** — `FR-M7-04`: **تُولِّده السحابة**،
/// ⟵ **وعرضُه للتحرير كان يُغري بتغيير ما لا يتغيّر** (`ADR-0007` القاعدة 3).
///
/// ★★★ **والحاسبة الحيّة تستدعي [explainSackWeight] ولا تحسب شيئاً بنفسها**
/// — `ADR-0010` القاعدة 5: ⟵ **فرقمُ الشاشة هو رقمُ السحابة حرفياً**،
/// ⛔ **ونسخةٌ ثانية من المعادلة تفترق عند أول تعديل** (`coding-standards.md`
/// §2.2).
///
/// ⚠️⚠️ **وكل بوابة صلاحية هنا إخفاءٌ لا حماية** — ★ **والرفض في السحابة**
/// (`ADR-0013` القاعدة 3 · `RISK-02`).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qtms_domain/qtms_domain.dart';

import '../../../core/design/design_tokens.dart';
import '../../../core/messages/error_messages.dart';
import '../../../core/ui/async_state_view.dart';
import '../../../core/ui/context_header.dart';
import '../../../core/ui/destructive_sheet.dart';
import '../../../core/ui/inline_banner.dart';
import '../../../core/ui/live_summary.dart';
import '../../../core/ui/status_pill.dart';
import '../../../core/ui/sticky_action_bar.dart';
import '../../identity_access/presentation/permission_gate.dart';
import '../../master_data/application/master_data_providers.dart';
import '../../oversight/presentation/audit_trail_view.dart';
import '../application/inventory_providers.dart';
import '../../../core/ui/entity_tile.dart';
import 'inventory_widgets.dart';
import '../../../core/ui/optional_reason.dart';

/// قائمة جواني اليوم.
class SackIntakeScreen extends ConsumerWidget {
  /// ينشئ الشاشة.
  const SackIntakeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CalendarDay today = ref.watch(todayProvider);
    final String? sourceId = ref.watch(selectedSourceProvider);
    final List<SourceCard> sources = ref.watch(activeSourcesProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: SemanticColors.surface,
        title: const Text('الوارد جواني', style: TypeScale.titleSm),
      ),
      floatingActionButton: sourceId == null
          ? null
          : PermissionGate(
              // ★★★ `IQ-021` الخيار أ — ⛔ **ولا مفتاح حقلي بديلاً عنه**.
              permission: Permission.sackCreate,
              child: _NewSackButton(sourceId: sourceId),
            ),
      body: Column(
        children: <Widget>[
          // ★★★ **رأس السياق الموحّد** — `MASTER.md` §5b نمط `P3` (`ADR-0021`).
          //
          // ⛔⛔ **ويستبدل `SourcePicker` + `LockedDayBanner` معاً** — ★ **صفٌّ
          //    واحد بدل صفّين وفراغٍ بينهما.**
          //
          // ⚠️ **و`LockedDayBanner` باقٍ داخل نموذج رأس الجونية** — ★ **موضعٌ
          //    آخر بوظيفةٍ أخرى:** ⟵ **إفصاحٌ عن قفل التاريخ لحظة الكتابة**
          //    (`FR-M7-02`)، ⛔ **لا رأسُ سياقٍ للشاشة.**
          QtmsContextHeader(
            sources: sources,
            selectedSourceId: sourceId,
            onSourceSelected: (String id) =>
                ref.read(selectedSourceProvider.notifier).select(id),
            day: today,
          ),
          Expanded(
            // ⛔⛔★★★ **ولا `SizedBox.shrink` حالةً لغياب المصدر** — §5b نمط
            //    `P3` قاعدةُ الفراغ الصامت (`design-system.md` §هـ).
            child: sourceId == null
                ? QtmsEmptyState(
                    spec: sources.isEmpty
                        ? noSourceInScopeEmpty
                        : chooseSourceEmpty(),
                  )
                : _SackList(sourceId: sourceId, day: today),
          ),
        ],
      ),
    );
  }
}

class _NewSackButton extends StatelessWidget {
  const _NewSackButton({required this.sourceId});

  final String sourceId;

  @override
  Widget build(BuildContext context) => FloatingActionButton.extended(
        onPressed: () => showSackHeaderForm(context, sourceId: sourceId),
        icon: const Icon(Icons.inventory_2_outlined),
        label: const Text('جونية جديدة'),
      );
}

class _SackList extends ConsumerWidget {
  const _SackList({required this.sourceId, required this.day});

  final String sourceId;
  final CalendarDay day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<SackCard>> sacks = ref.watch(
      sacksProvider(StockQuery(sourceId: sourceId, stockDate: day)),
    );

    return InventoryAsyncView<SackCard>(
      value: sacks,
      emptyIcon: Icons.inventory_outlined,
      emptyTitle: 'لا توجد جواني اليوم',
      emptyLabel: 'ابدأ بجونية جديدة لتسجيل أوزانها وأنواعها.',
      builder: (List<SackCard> list) => EntityList(
        itemCount: list.length,
        itemBuilder: (BuildContext context, int index) =>
            _SackTile(sack: list[index]),
      ),
    );
  }
}

class _SackTile extends ConsumerWidget {
  const _SackTile({required this.sack});

  final SackCard sack;

  @override
  Widget build(BuildContext context, WidgetRef ref) => InventoryTile(
        title: sack.displayName,
        // ★★ **أيقونة 🕘 في أول الصفّ** — `FR-M18-10` · `FR-M18-11`
        //   («**الجواني**» ضمن الشاشات المشمولة).
        //
        // ⚠️⚠️ **والمعرّف `documentNumber` لا الاسم المعروض** — ★ **لأنه
        //   ما يكتبه القيد حرفياً** (`sack_intake.dart` →
        //   `AuditTarget.entityId: request.documentNumber`)، ⟵ **وأيُّ
        //   قيمةٍ أخرى تُنتج سجلاً سياقياً فارغاً أبداً** ⛔ **يبدو «لا
        //   تاريخ لهذه الجونية» وهو أسوأ عطلٍ في الحافظ الوحيد للتاريخ.**
        //   ★ **والاسم المعروض قابلٌ للتغيير أصلاً** (`sackRenameDisplay`).
        leading: auditTrailLeading(
          ref,
          entityType: sackEntityType,
          entityId: sack.documentNumber,
          title: sack.displayName,
          sourceId: sack.sourceId,
        ),
        subtitle: '${sack.documentNumber} · '
            'المطالب به ${sack.weights.claimableWeight.formatted()} كجم · '
            '${sack.lines.length} نوع',
        badges: <Widget>[
          if (sack.isCancelled) const CancelledBadge(),
          if (sack.amendCount > 0) const AmendedBadge(),
          // ★★ **شارة حالة الوزن** — `sack-intake-design.md` §2.
          _WeightStateBadge(explanation: sack.explanation),
          // ★ «⏳ سعر غير نهائي» — `FR-M7-24`.
          if (!sack.isPricingComplete && sack.lines.isNotEmpty)
            const _PendingPriceBadge(),
        ],
        actions: <Widget>[
          // ⛔★★ **ولا زر حذف إطلاقاً** — `GR-07`: «**الحذف مرفوض نهائياً
          //    لكل المستخدمين بمن فيهم المالك**».
          // ★★★ **وإجراءاتٌ بأيقونةٍ ونصّ لا برمزٍ صامت** — `design-system.md`
          //    §6.ج: **«الأول أساسي · والبقية `textSecondary` · والمدمّر
          //    آخراً `danger/ink`»**. ⟵ ⚠️⚠️ **ورمزان عاريان (⊘ و▤) كانا
          //    يتركان القارئ يخمّن أيُّهما يُدخِل وأيُّهما يُلغي** — ★ **على
          //    مستندٍ مالي لا يُحذَف ولا يُتراجَع عن إلغائه.**
          if (!sack.isCancelled)
            PermissionGate(
              permission: Permission.sackLinesEnter,
              child: TextButton.icon(
                onPressed: () => showSackLinesForm(context, sack: sack),
                icon: const Icon(Icons.list_alt_outlined, size: Sizes.iconMd),
                label: const Text('الأنواع'),
              ),
            ),
          // ★ **والمدمّر آخراً بلون `danger`** — ⟵ **فترتيبُ الصفّ نفسه
          //   يُبعِد الإصبعَ عن الإلغاء**، ★ **واللونُ يُنبِّه واللفظُ يُصرِّح.**
          if (!sack.isCancelled)
            PermissionGate(
              permission: Permission.sackCancel,
              child: TextButton.icon(
                onPressed: () => showCancelSackSheet(context, sack: sack),
                icon: const Icon(Icons.block_outlined, size: Sizes.iconMd),
                label: const Text('إلغاء'),
                style: TextButton.styleFrom(
                  foregroundColor: SemanticTriads.danger.ink,
                ),
              ),
            ),
        ],
      );
}

/// ★★★ حالةُ تفسير الوزن — **الحالات الثلاث** (`sack-intake-design.md` §2).
///
/// ★ **موزّعٌ واحد للحالة** — ⟵ **تقرؤه الشارةُ في البطاقة والميزانُ في
/// النموذج معاً**، ⛔ **فلا نسختان تنحرفان.**
QtmsSummaryStatus _sackWeightStatus(SackWeightExplanation explanation) =>
    switch (explanation.state) {
      SackWeightState.fullyExplained => const QtmsSummaryStatus(
          label: 'مفسَّر بالكامل',
          triad: SemanticTriads.primary,
          icon: Icons.check_circle_outline,
        ),
      // ⚠️ **«غير مفسَّر» تحذيرٌ لا خطأ** — ★ **حالةٌ مشروعة يُلاحقها المركز
      //    المعلّق** (`E-10`)، ⛔ **ولا تمنع الحفظ.**
      SackWeightState.unexplained => QtmsSummaryStatus(
          label: 'متبقٍ ${explanation.remainingWeight.formatted()} كجم',
          triad: SemanticTriads.warning,
          icon: Icons.pending_outlined,
        ),
      SackWeightState.lostConfirmed => QtmsSummaryStatus(
          label: 'ضائع ${explanation.lostWeight.formatted()} كجم',
          triad: SemanticTriads.danger,
          icon: Icons.report_problem_outlined,
        ),
    };

/// ★★ شارة حالة تفسير الوزن — ⛔ **ولا رسمَ محلّياً** (§5b `P5`).
class _WeightStateBadge extends StatelessWidget {
  const _WeightStateBadge({required this.explanation});

  final SackWeightExplanation explanation;

  @override
  Widget build(BuildContext context) {
    final QtmsSummaryStatus status = _sackWeightStatus(explanation);
    return StatusPill(
      label: status.label,
      triad: status.triad,
      icon: status.icon,
    );
  }
}

class _PendingPriceBadge extends StatelessWidget {
  const _PendingPriceBadge();

  @override
  Widget build(BuildContext context) => const StatusPill(
        // ⛔⛔ **ولا «⏳» إيموجي** (§9) — ★ **أيقونةٌ متجهية ترث اللون
        //    والمقاس**، ⟵ **بينما الإيموجي يتبع خطَّ الجهاز ولا يُلوَّن.**
        label: 'سعر غير نهائي',
        triad: SemanticTriads.warning,
        icon: Icons.schedule_outlined,
      );
}

// ═════════════════════════════════════════════════════════════════════════
// ★★★ نموذج رأس الجونية — **الأوزان والسكرب** (`FR-M7-06` … `FR-M7-09`)
// ═════════════════════════════════════════════════════════════════════════

/// يفتح نموذج رأس الجونية.
Future<void> showSackHeaderForm(
  BuildContext context, {
  required String sourceId,
}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: SemanticColors.surface,
      builder: (BuildContext context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SackHeaderFormSheet(sourceId: sourceId),
      ),
    );

/// ورقة رأس الجونية.
class SackHeaderFormSheet extends ConsumerStatefulWidget {
  /// ينشئ الورقة.
  const SackHeaderFormSheet({required this.sourceId, super.key});

  /// المصدر.
  final String sourceId;

  @override
  ConsumerState<SackHeaderFormSheet> createState() =>
      _SackHeaderFormSheetState();
}

class _SackHeaderFormSheetState extends ConsumerState<SackHeaderFormSheet> {
  final TextEditingController _total = TextEditingController();
  final TextEditingController _ice = TextEditingController(text: '0');
  final TextEditingController _scrap = TextEditingController(text: '0');
  final TextEditingController _notes = TextEditingController();

  String? _supplierId;
  CatalogMessage? _rejection;
  bool _submitting = false;

  @override
  void dispose() {
    _total.dispose();
    _ice.dispose();
    _scrap.dispose();
    _notes.dispose();
    super.dispose();
  }

  /// ★★ **الأوزان كما هي الآن** — ⛔ **بلا تحقق**: للحاسبة الحيّة وحدها.
  SackWeightsInput get _weights => SackWeightsInput(
        totalWeight: WeightKg.tryParseInput(_total.text) ?? WeightKg.zero,
        iceWeight: WeightKg.tryParseInput(_ice.text) ?? WeightKg.zero,
        scrapWeight: WeightKg.tryParseInput(_scrap.text) ?? WeightKg.zero,
      );

  @override
  Widget build(BuildContext context) {
    final CalendarDay today = ref.watch(todayProvider);
    final List<SupplierCard> suppliers =
        ref.watch(intakeSuppliersProvider(widget.sourceId));
    final bool requiresSupplier = _requiresSupplier(ref, widget.sourceId);

    // ★★★ **الحاسبة الحيّة** — ⟵ **تُعاد مع كل ضغطة مفتاح** (`FR-M7-29`).
    final Outcome<ValidatedSackWeights> checked =
        validateSackWeights(_weights);

    return SafeArea(
      child: ConstrainedBox(
        // ★ **الورقة لا تبتلع الشاشة** — ⟵ **فيبقى ما تحتها ظاهراً.**
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                Spacing.space16,
                Spacing.space16,
                Spacing.space16,
                Spacing.space12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  // ① العنوان.
                  const Text('جونية جديدة', style: TypeScale.titleLg),
                  const SizedBox(height: Spacing.space12),
                  // ⛔★★ **ولا منتقي تاريخ** — راجع ترويسة الملف.
                  LockedDayBanner(day: today),
                  const SizedBox(height: Spacing.space12),
                  // ② ★★★ **الميزان الحيّ — ثابتٌ لا يمرّ** (§5b `P5`).
                  //
                  // ⛔⛔ **وكان يمرّ مع الحقول** — ⟵ **فيغيب عن العين لحظةَ
                  //    الحاجة إليه** (`FR-M7-29`).
                  _claimableSummary(checked),
                ],
              ),
            ),
            // ④ الحقول — **تمرّ وحدها.**
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsetsDirectional.only(
                  // ⛔ **ولا صفرٌ عارٍ في السلّم** — ★ **والأعلى يُحذَف لا يُصفَّر**:
                  //    ⟵ **الميزانُ فوقَه يحمل حشوَه.**
                  start: Spacing.screenPadding,
                  end: Spacing.screenPadding,
                  bottom: Spacing.screenPadding,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    // ★★ **الرعوي مشروطٌ بالمصدر** — `FR-M7-03`.
                    if (requiresSupplier) ...<Widget>[
                      _FieldLabel('الرعوي'),
                      const SizedBox(height: Spacing.space8),
                      Wrap(
                        spacing: Spacing.space8,
                        runSpacing: Spacing.space8,
                        children: <Widget>[
                          for (final SupplierCard supplier in suppliers)
                            ChoiceChip(
                              label: Text(supplier.name),
                              selected: supplier.supplierId == _supplierId,
                              onSelected: (bool on) => setState(
                                () => _supplierId =
                                    on ? supplier.supplierId : null,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: Spacing.space16),
                    ],

                    _FieldLabel('الأوزان (كجم)'),
                    const SizedBox(height: Spacing.space8),
                    _WeightField(
                      controller: _total,
                      label: 'الوزن الكلي',
                      onChanged: () => setState(() {}),
                    ),
                    _WeightField(
                      controller: _ice,
                      label: 'وزن الثلج',
                      onChanged: () => setState(() {}),
                    ),
                    // ★★ **والسكرب يدخل المخزن فور الحفظ** — `FR-M7-09` · `AT-07`.
                    PermissionGate(
                      permission: Permission.sackScrapWeightEnter,
                      child: _WeightField(
                        controller: _scrap,
                        label: 'وزن السكرب',
                        onChanged: () => setState(() {}),
                      ),
                    ),
                    const SizedBox(height: Spacing.space16),

                    TextField(
                      controller: _notes,
                      decoration:
                          const InputDecoration(labelText: 'ملاحظات (اختياري)'),
                    ),
                    const SizedBox(height: Spacing.space16),
                    Text(
                      // ★ **إفصاحٌ صريح عن تسلسل الخطوات** — `sack-intake-design.md` §2.
                      'يُحفَظ الرأس أولاً ويدخل السكرب المخزن فوراً، ثم '
                      'تُدخَل الأنواع.',
                      style: TypeScale.bodyMd
                          .copyWith(color: SemanticColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
            // ⑥ ★★ **شريط الإجراء الثابت** — لافتةُ الرفض ثم الزرُّ الأساسي.
            QtmsStickyActionBar(
              status: _rejection == null
                  ? null
                  : QtmsActionStatus.rejection(catalogText(_rejection!)),
              primary: FilledButton(
                onPressed: _submitting ? null : () => _submit(requiresSupplier),
                child: const Text('حفظ الرأس'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ★★★ الميزان الحيّ — **المطالب به، أو سببُ رفض الأوزان مكانَ القيمة**.
  ///
  /// ⛔⛔★★★ **ولا يختفي عند الرفض** (`DEBT-47`) — ★ **وكان `SizedBox.shrink`**:
  /// ⟵ **فمن أدخل ثلجاً أكبر من الكلي رأى الملخّصَ يتبخّر** ⛔ **بلا رقمٍ ولا
  /// سبب**، ★ **فقرأ الاختفاء عطلاً في الشاشة لا رفضاً لمُدخَله.**
  Widget _claimableSummary(Outcome<ValidatedSackWeights> checked) =>
      switch (checked) {
        Success<ValidatedSackWeights>(:final ValidatedSackWeights value) =>
          QtmsLiveSummary(
            headline: 'الوزن المطالب به: '
                '${value.claimableWeight.formatted()} كجم',
          ),
        // ⚠️ **والرفض يُعرَض حيّاً لا عند الحفظ وحده** — ⟵ **فيُصحِّح
        //    المستخدم الرقم وهو ينظر إليه** (`FR-M7-29`).
        Failure<ValidatedSackWeights>(:final AppError error) =>
          QtmsLiveSummary(
            headline: 'الوزن المطالب به: —',
            rejection: catalogText(sackRejectionMessage(error)),
          ),
      };

  static bool _requiresSupplier(WidgetRef ref, String sourceId) {
    for (final SourceCard source in ref.watch(activeSourcesProvider)) {
      if (source.sourceId == sourceId) return source.requiresSupplierOnIntake;
    }
    return false;
  }

  Future<void> _submit(bool requiresSupplier) async {
    final Outcome<ValidatedSackIntake> validated = validateSackIntake(
      SackIntakeInput(
        sourceId: widget.sourceId,
        sourceRequiresSupplier: requiresSupplier,
        supplierId: requiresSupplier ? _supplierId : null,
        weights: _weights,
        notes: _notes.text,
      ),
    );
    if (validated is Failure<ValidatedSackIntake>) {
      setState(() => _rejection = sackRejectionMessage(validated.error));
      return;
    }

    setState(() {
      _submitting = true;
      _rejection = null;
    });

    final Outcome<String> result = await ref
        .read(sackAdminProvider)
        .createSack((validated as Success<ValidatedSackIntake>).value);

    if (!mounted) return;
    switch (result) {
      case Failure<String>(:final AppError error):
        setState(() {
          _submitting = false;
          _rejection = appErrorMessage(error);
        });
      case Success<String>():
        Navigator.of(context).pop();
    }
  }
}

// ═════════════════════════════════════════════════════════════════════════
// ★★★ نموذج السطور — **جدول وزن الحبة الثلاثي والحاسبة الحيّة**
// ═════════════════════════════════════════════════════════════════════════

/// يفتح نموذج أنواع الجونية.
Future<void> showSackLinesForm(
  BuildContext context, {
  required SackCard sack,
}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: SemanticColors.surface,
      builder: (BuildContext context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SackLinesFormSheet(sack: sack),
      ),
    );

/// ورقة أنواع الجونية.
class SackLinesFormSheet extends ConsumerStatefulWidget {
  /// ينشئ الورقة.
  const SackLinesFormSheet({required this.sack, super.key});

  /// الجونية.
  final SackCard sack;

  @override
  ConsumerState<SackLinesFormSheet> createState() => _SackLinesFormSheetState();
}

class _SackLinesFormSheetState extends ConsumerState<SackLinesFormSheet> {
  /// ★ مُدخَلات كل نوع بمعرّفه — ★ **والمفتاح يفرض «لا سطران لنفس النوع»**
  /// بنيوياً (`FR-M7-23`).
  late final Map<String, _LineDraft> _drafts = <String, _LineDraft>{
    for (final ValidatedSackLine line in widget.sack.lines)
      line.itemId: _LineDraft.fromLine(line),
  };

  final TextEditingController _reason = TextEditingController();
  CatalogMessage? _rejection;
  bool _submitting = false;

  @override
  void dispose() {
    for (final _LineDraft draft in _drafts.values) {
      draft.dispose();
    }
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<ItemCard> items =
        ref.watch(sackLineItemsProvider(widget.sack.sourceId));

    // ★★★ **الحاسبة الحيّة** — ⟵ **تستدعي دوال النطاق ولا تحسب بنفسها**
    //    (`ADR-0010` القاعدة 5).
    final List<ValidatedSackLine> resolved = _resolvedLines(items);
    final SackWeightExplanation explanation = explainSackWeight(
      weights: widget.sack.weights,
      lines: resolved,
      lostWeightConfirmed: widget.sack.lostWeightConfirmed,
    );

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                Spacing.space16,
                Spacing.space16,
                Spacing.space16,
                Spacing.space12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  // ① العنوان.
                  Text(
                    'أنواع ${widget.sack.displayName}',
                    style: TypeScale.titleLg,
                  ),
                  const SizedBox(height: Spacing.space12),
                  // ② ★★★ **الميزان ثابتٌ لا يمرّ** — ⛔ **وكان يخرج من الشاشة
                  //    عند السطر الخامس** ⟵ **فيوازن المستخدم وهو لا يرى
                  //    المتبقّي** (`FR-M7-29`).
                  _weightSummary(explanation),
                ],
              ),
            ),
            // ④ الصفوف — **تمرّ وحدها.**
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsetsDirectional.only(
                  // ⛔ **ولا صفرٌ عارٍ في السلّم** — ★ **والأعلى يُحذَف لا يُصفَّر**:
                  //    ⟵ **الميزانُ فوقَه يحمل حشوَه.**
                  start: Spacing.screenPadding,
                  end: Spacing.screenPadding,
                  bottom: Spacing.screenPadding,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    for (final ItemCard item in items)
                      _SackLineRow(
                        item: item,
                        draft: _drafts[item.itemId],
                        onToggle: (bool on) => setState(() {
                          if (on) {
                            _drafts[item.itemId] = _LineDraft.forItem(item);
                          } else {
                            _drafts.remove(item.itemId)?.dispose();
                          }
                        }),
                        onChanged: () => setState(() {}),
                      ),
                    if (items.isEmpty)
                      Text(
                        // `FR-M7-22` — قائمة الأنواع مفلترة بالمصدر حصراً.
                        'لا توجد أنواع مرتبطة بهذا المصدر.',
                        style: TypeScale.bodyMd
                            .copyWith(color: SemanticColors.textSecondary),
                      ),
                    const SizedBox(height: Spacing.space16),
                    // ⑤ حقل السبب **(اختياري)**.
                    TextField(
                      controller: _reason,
                      decoration: const InputDecoration(
                        labelText: 'سبب التعديل (اختياري)',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // ⑥ ★★ **شريط الإجراء الثابت** — ⛔ **والزرُّ الأساسي وحده فيه.**
            QtmsStickyActionBar(
              status: _rejection == null
                  ? null
                  : QtmsActionStatus.rejection(catalogText(_rejection!)),
              primary: FilledButton(
                onPressed: _submitting ? null : () => _submit(items),
                child: const Text('حفظ الأنواع'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ★★ الميزان الحيّ — **نصُّه وشريطُه وحالتُه وإجراؤها المشروط**.
  ///
  /// ⛔⛔★★★ **وزرُّ «تأكيد الوزن الضائع» داخله لا تحت الزر الأساسي** —
  /// ★ **يظهر ويختفي بحسب الحالة**: ⟵ **فكان يُزحزح الزرَّ الأساسي تحت
  /// الإصبع**، ⛔ **وإجراءٌ لا رجعة فيه يصير آخرَ ما تلمسه اليد بعد الحفظ.**
  /// ★ **وموضعُه الآن مُلحَقٌ بالحالة التي أنتجته** ⟵ **فيُقرأ جواباً لا
  /// خياراً مجاوراً.**
  Widget _weightSummary(SackWeightExplanation explanation) {
    final double claimable = explanation.claimableWeight.kilograms;
    // ⛔ **والقسمة هنا نسبةُ عرضٍ لا معادلةَ عمل** — ★ **والأوزان كلُّها من
    //    `explainSackWeight`** (`ADR-0010` القاعدة 5).
    final double ratio = claimable <= 0
        ? 0
        : (explanation.explainedWeight.kilograms / claimable).clamp(0.0, 1.0);

    return QtmsLiveSummary(
      headline: 'فُسِّر ${explanation.explainedWeight.formatted()} '
          'من ${explanation.claimableWeight.formatted()} كجم',
      progress: ratio,
      status: _sackWeightStatus(explanation),
      // ★★ **تأكيد الوزن الضائع — زرٌّ صريح مستقل** (`FR-M7-19`).
      // ⛔ **ولا يُسجَّل ضمناً مع الحفظ أبداً** (`BR-M7-12`).
      conditionalAction: explanation.state == SackWeightState.unexplained
          ? PermissionGate(
              permission: Permission.sackLostWeightConfirm,
              child: OutlinedButton.icon(
                onPressed: _submitting ? null : _confirmLostWeight,
                icon: const Icon(Icons.report_problem_outlined),
                label: Text(
                  'تأكيد الوزن الضائع '
                  '(${explanation.remainingWeight.formatted()} كجم)',
                ),
              ),
            )
          : null,
    );
  }

  /// ★★ السطور المُتحقَّق منها — ⛔ **والمرفوض يُسقَط من الحاسبة وحدها**.
  ///
  /// ⚠️ **ولا يُرفَع الرفض هنا:** المستخدم **يكتب رقماً ناقصاً أثناء الكتابة**
  /// — ⟵ **وإظهار خطأٍ مع كل حرف ضجيج**، ★ **والرفض يظهر عند الحفظ.**
  List<ValidatedSackLine> _resolvedLines(List<ItemCard> items) {
    final Map<String, ItemCard> byId = <String, ItemCard>{
      for (final ItemCard item in items) item.itemId: item,
    };
    final List<ValidatedSackLine> lines = <ValidatedSackLine>[];
    for (final MapEntry<String, _LineDraft> entry in _drafts.entries) {
      final ItemCard? item = byId[entry.key];
      if (item == null) continue;
      final Outcome<ValidatedSackLine> resolved =
          resolveSackLine(entry.value.toInput(item));
      if (resolved is Success<ValidatedSackLine>) {
        lines.add(resolved.value);
      }
    }
    return lines;
  }

  Future<void> _submit(List<ItemCard> items) async {
    final Map<String, ItemCard> byId = <String, ItemCard>{
      for (final ItemCard item in items) item.itemId: item,
    };

    // ★★ **وكل سطرٍ يمرّ بالجدول الثلاثي** — ⛔ **والرفض يُعرَض برسالته.**
    final List<ValidatedSackLine> lines = <ValidatedSackLine>[];
    for (final MapEntry<String, _LineDraft> entry in _drafts.entries) {
      final ItemCard? item = byId[entry.key];
      if (item == null) continue;
      final Outcome<ValidatedSackLine> resolved =
          resolveSackLine(entry.value.toInput(item));
      if (resolved case Failure<ValidatedSackLine>(:final AppError error)) {
        setState(() => _rejection = sackRejectionMessage(error));
        return;
      }
      lines.add((resolved as Success<ValidatedSackLine>).value);
    }

    // ⑥ ★★ **ولا تجاوز للمطالب به** — `FR-M7-18` · `E-07`.
    final SackWeightExplanation explanation = explainSackWeight(
      weights: widget.sack.weights,
      lines: lines,
    );
    if (explanation.remainingWeight.kilograms < -weightEpsilonKg) {
      setState(() => _rejection = CatalogMessage.sackWeightExceeded);
      return;
    }

    setState(() {
      _submitting = true;
      _rejection = null;
    });

    final Outcome<void> result =
        await ref.read(sackAdminProvider).enterSackLines(
              documentNumber: widget.sack.documentNumber,
              sourceId: widget.sack.sourceId,
              lines: lines,
              amendReason: blankToNull(_reason.text),
            );

    if (!mounted) return;
    switch (result) {
      case Failure<void>(:final AppError error):
        setState(() {
          _submitting = false;
          _rejection = appErrorMessage(error);
        });
      case Success<void>():
        Navigator.of(context).pop();
    }
  }

  Future<void> _confirmLostWeight() async {
    setState(() {
      _submitting = true;
      _rejection = null;
    });

    final Outcome<void> result =
        await ref.read(sackAdminProvider).confirmSackLostWeight(
              documentNumber: widget.sack.documentNumber,
              sourceId: widget.sack.sourceId,
            );

    if (!mounted) return;
    switch (result) {
      case Failure<void>(:final AppError error):
        setState(() {
          _submitting = false;
          _rejection = appErrorMessage(error);
        });
      case Success<void>():
        Navigator.of(context).pop();
    }
  }
}

/// ★★★ صفّ سطر — **ويُظهر الحقول بحسب حالة النوع من الثلاث**.
class _SackLineRow extends StatelessWidget {
  const _SackLineRow({
    required this.item,
    required this.draft,
    required this.onToggle,
    required this.onChanged,
  });

  final ItemCard item;
  final _LineDraft? draft;
  final void Function(bool) onToggle;
  final VoidCallback onChanged;

  /// ★★ **الحالة الثالثة: عددي** — الحقل **مقفل وفارغ** والوزن الكلي يدوي.
  bool get _isCounted => item.nature == ItemNature.countBased;

  @override
  Widget build(BuildContext context) {
    final _LineDraft? current = draft;
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.space12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Checkbox(
                value: current != null,
                onChanged: (bool? on) => onToggle(on ?? false),
              ),
              Expanded(child: Text(item.name, style: TypeScale.bodyMd)),
              Text(
                _isCounted ? 'عددي' : 'وزني',
                style: TypeScale.label
                    .copyWith(color: SemanticColors.textSecondary),
              ),
            ],
          ),
          if (current != null) ...<Widget>[
            const SizedBox(height: Spacing.space8),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: current.quantity,
                    keyboardType: const TextInputType.numberWithOptions(),
                    decoration: const InputDecoration(labelText: 'العدد'),
                    onChanged: (String _) => onChanged(),
                  ),
                ),
                const SizedBox(width: Spacing.space8),
                Expanded(
                  child: _isCounted
                      // ★ **الحالة ③** — الوزن الكلي **يُدخَل يدوياً**.
                      ? TextField(
                          controller: current.lineTotalWeight,
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'الوزن الكلي (كجم)',
                          ),
                          onChanged: (String _) => onChanged(),
                        )
                      // ★ **الحالتان ① و②** — وزن الحبة، والوزن الكلي محسوب.
                      : PermissionGate(
                          permission: Permission.sackLinesEnter,
                          child: TextField(
                            controller: current.pieceWeight,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'وزن الحبة (جم)',
                            ),
                            onChanged: (String _) => onChanged(),
                          ),
                        ),
                ),
              ],
            ),
            // ⛔★★★ **ولا حقل وزن حبة للعددي إطلاقاً** — `E-09`: «**الحقل
            //    مقفل**»، ★ **والقفل هنا غيابُ الحقل لا تعطيلُه**: ⟵ **حقلٌ
            //    معطَّل يُغري بالبحث عن طريقة لتعبئته.**
            if (_isCounted)
              Padding(
                padding: const EdgeInsets.only(top: Spacing.space4),
                child: Text(
                  'وزن الحبة يُستنتَج من الوزن الكلي والعدد.',
                  style: TypeScale.bodyMd
                      .copyWith(color: SemanticColors.textSecondary),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// مسوّدة سطرٍ قيد التحرير.
final class _LineDraft {
  _LineDraft({
    required this.quantity,
    required this.pieceWeight,
    required this.lineTotalWeight,
    required this.configuredPieceWeightGrams,
  });

  /// ★ من نوعٍ يُختار للتوّ — **ووزن الحبة من التهيئة إن وُجد** (الحالة ①).
  factory _LineDraft.forItem(ItemCard item) => _LineDraft(
        quantity: TextEditingController(),
        pieceWeight: TextEditingController(
          text: item.pieceWeightGrams?.toString() ?? '',
        ),
        lineTotalWeight: TextEditingController(),
        configuredPieceWeightGrams: item.pieceWeightGrams,
      );

  /// ★ من سطرٍ مخزَّن — **بقيمه المُجمَّدة** (`FR-M7-15`).
  ///
  /// ⛔⛔★★★ **ومصدرُ الرقم مُجمَّدٌ معه** (`DEBT-37`): **سطرٌ جاء وزنُه من
  /// التهيئة يعود بصلته بها**، ⟵ **فتعديلٌ لسببٍ آخر لا يَسِمه «يدوياً»**
  /// ⛔ **ولم يكتب المستخدم رقمه.** ★ **وطيُّها في `null` كان يُعيد وسمَ كلِّ
  /// سطرٍ لم يُمَسّ عند أول تعديل** ⟵ **وهو غسلُ مصدرٍ لا حفظُه.**
  factory _LineDraft.fromLine(ValidatedSackLine line) => _LineDraft(
        quantity: TextEditingController(text: line.quantity.pieces.toString()),
        pieceWeight: TextEditingController(
          text: line.nature == ItemNature.countBased
              ? ''
              : line.pieceWeightGrams.toString(),
        ),
        lineTotalWeight: TextEditingController(
          text: line.nature == ItemNature.countBased
              ? line.lineTotalWeight.kilograms.toString()
              : '',
        ),
        configuredPieceWeightGrams:
            line.pieceWeightOrigin == PieceWeightOrigin.configured
                ? line.pieceWeightGrams
                : null,
      );

  final TextEditingController quantity;
  final TextEditingController pieceWeight;
  final TextEditingController lineTotalWeight;

  /// ★ قيمة التهيئة — ⛔ **ولا تُعدَّل من هنا أبداً** (`FR-M7-15`).
  final double? configuredPieceWeightGrams;

  /// ★★ يبني المُدخَل — **والطبيعة من سجل النوع لا من الشاشة**.
  ///
  /// ⛔★★★ **ولا يُمرَّر وزن حبةٍ لنوعٍ عددي ولا وزنٌ كلي لوزني** — ⟵ **فجدولُ
  /// الحالات الثلاث يُطبَّق حرفياً** (`FR-M7-13` · `E-08` · `E-09`).
  SackLineInput toInput(ItemCard item) {
    final bool isCounted = item.nature == ItemNature.countBased;
    final double? manual = double.tryParse(pieceWeight.text.trim());
    return SackLineInput(
      itemId: item.itemId,
      itemName: item.name,
      nature: item.nature,
      unit: item.unit,
      quantity: PieceCount.tryParseInput(quantity.text)?.pieces ?? 0,
      configuredPieceWeightGrams: isCounted ? null : configuredPieceWeightGrams,
      // ★ **والمُدخَل يعلو على التهيئة** — ⛔ **ويبقى محلياً** (`FR-M7-15`).
      pieceWeightGrams: isCounted
          ? null
          : (manual != null && manual != configuredPieceWeightGrams
              ? manual
              : null),
      lineTotalWeight:
          isCounted ? double.tryParse(lineTotalWeight.text.trim()) : null,
    );
  }

  void dispose() {
    quantity.dispose();
    pieceWeight.dispose();
    lineTotalWeight.dispose();
  }
}

// ═════════════════════════════════════════════════════════════════════════
// الإلغاء
// ═════════════════════════════════════════════════════════════════════════

/// يفتح ورقة إلغاء الجونية — ★ **والسببُ اختياريٌّ** (`ADR-0020`).
///
/// ★★ **والورقةُ اليومَ `QtmsDestructiveSheet`** (`MASTER.md` §5b `P6` ·
/// `ADR-0021`) — ⟵ ★★ **فلها زرُّ تراجعٍ صريح**: ⛔ **وكان مخرجُها الوحيد
/// سحباً لأسفل** — **إيماءةٌ غير معلَنة على فعلٍ لا رجعة فيه.**
Future<void> showCancelSackSheet(
  BuildContext context, {
  required SackCard sack,
}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: SemanticColors.surface,
      builder: (BuildContext context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: CancelSackSheet(sack: sack),
      ),
    );

/// ورقة إلغاء الجونية.
///
/// ⚠️⚠️ **وهي مالكةُ المستودع لا الورقةُ الموحّدة** — ★ **تمرّر تنفيذَها في
/// `onConfirm`**، ⟵ **فيُعرَض الرفضُ في موضعه ⑥ والورقةُ مفتوحة.**
class CancelSackSheet extends ConsumerStatefulWidget {
  /// ينشئ الورقة.
  const CancelSackSheet({required this.sack, super.key});

  /// الجونية.
  final SackCard sack;

  @override
  ConsumerState<CancelSackSheet> createState() => _CancelSackSheetState();
}

class _CancelSackSheetState extends ConsumerState<CancelSackSheet> {
  @override
  Widget build(BuildContext context) => QtmsDestructiveSheet(
        title: 'إلغاء ${widget.sack.displayName}',
        // ★ **الإلغاء وسمٌ لا حذف** — `GR-06` · `GR-07`.
        impact: 'الإلغاء يَسِم الجونية وحركاتها ولا يحذف شيئاً، ويُشترط توفّر '
            'الكمية غير المصروفة.',
        confirmLabel: 'تأكيد الإلغاء',
        reasonLabel: 'سبب الإلغاء (اختياري)',
        onConfirm: _submit,
      );

  /// ★ يُرجِع نصَّ الرفض — و`null` نجاحاً.
  Future<String?> _submit(DestructiveConfirmation confirmation) async {
    // ⛔⛔★★★ **ولا حارسَ على السبب** — `ADR-0020` (2026-08-27): ★ **اختياريٌّ
    //    في كل عملية**، ⟵ **وما تركه المستخدم فارغاً يُرسَل غياباً**
    //    ⛔ **لا نصّاً مُعبَّأً عنه.**
    final Outcome<void> result = await ref.read(sackAdminProvider).cancelSack(
          documentNumber: widget.sack.documentNumber,
          sourceId: widget.sack.sourceId,
          cancelReason: blankToNull(confirmation.reason),
        );

    return switch (result) {
      Failure<void>(:final AppError error) => catalogText(
          appErrorMessage(error),
        ),
      Success<void>() => null,
    };
  }
}

// ═════════════════════════════════════════════════════════════════════════
// مشترَكات
// ═════════════════════════════════════════════════════════════════════════

/// ★ يترجم رفض طبقة النطاق إلى رسالته — ⛔ **ولا تُصاغ في الشاشة**.
///
/// ⚠️ **ومُصدَّرة ليُختبَر التحويل نفسه** — ★ **فهو قرارٌ يُقاس** لا تفصيل عرض.
CatalogMessage sackRejectionMessage(AppError error) {
  if (error case ValidationError(:final String ruleCode)) {
    return switch (ruleCode) {
      'BR-M7-03' => CatalogMessage.supplierRequiredForSource,
      'BR-M7-07' || 'FR-M7-06' => CatalogMessage.sackWeightsIllogical,
      'BR-M7-08' => CatalogMessage.sackWeightExceeded,
      'E-08' => CatalogMessage.pieceWeightMissing,
      'E-09' || 'FR-M7-13' => CatalogMessage.countedLineNeedsTotalWeight,
      'BR-M7-17' => CatalogMessage.itemAlreadyInDocument,
      'BR-M6-06' => CatalogMessage.fractionalCount,
      _ => CatalogMessage.operationFailed,
    };
  }
  return appErrorMessage(error);
}

/// شريط الرفض — ★ **نصّه من الكتالوج حرفياً** ⛔ **ولا صياغة هنا.**
class SackRejectionBanner extends StatelessWidget {
  /// ينشئ الشريط.
  const SackRejectionBanner({required this.message, super.key});

  /// الرسالة.
  final CatalogMessage message;

  @override
  Widget build(BuildContext context) => QtmsInlineBanner(
        text: catalogText(message),
        triad: SemanticTriads.danger,
      );
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TypeScale.label.copyWith(color: SemanticColors.textSecondary),
      );
}

/// ★ حقل وزن — **يقبل الكسر** (`ADR-0015` القاعدة 9).
class _WeightField extends StatelessWidget {
  const _WeightField({
    required this.controller,
    required this.label,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: Spacing.space8),
        child: TextField(
          controller: controller,
          // ★★ **والكسر مسموح هنا بخلاف المبالغ** — `ADR-0015` القاعدة 9.
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: label),
          onChanged: (String _) => onChanged(),
        ),
      );
}

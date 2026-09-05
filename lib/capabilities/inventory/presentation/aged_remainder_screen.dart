/// شاشة **متبقي الأيام السابقة** (`M8` الشاشة الثانية) — **نمط 2**
/// (`ui-guidelines.md` §3): قائمةُ كياناتٍ بمرشِّحاتٍ وبحثٍ فوري.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ★★★ **وهي شاشةُ عملٍ لا شاشةُ اطّلاع** — `FR-M8` §1: «**شاشةُ عملٍ لتصريف
/// ما لم يُصرَّف من الأيام الماضية، على يومه الأصلي**»: ⟵ **فلكل بندٍ
/// إجراؤه**، ⛔ **ولا تُعرَض أرقامٌ بلا وجهة.**
///
/// ⛔⛔★★★ **وكلُّ ما يُصرَّف يُحتسب في يومه الأصلي** — `FR-M8-09` (`A-08` ·
/// `ق-4`): ⟵ **والشاشةُ تُثبِّت (مصدر × نوع × تاريخ مخزون) على شاشة التصريف**
/// (`FR-M8-12`)، ⛔ **ولا تكتب حرفاً بنفسها**: ★ **مسارُ الكتابة يبقى `M10`
/// و`M11` وحدهما** (`UC-004` ③).
///
/// ✅★★★ **والإجراءاتُ ثلاثةٌ منذ `WU-020`** — `FR-M8-11`: **توزيعٌ · بيعٌ
/// نقدي · إتلاف** ⟵ **ولكلٍّ مفتاحُه فوق `agedRemainderClear`**، ★ **والإتلافُ
/// يفتح شاشتَه مثبَّتةً بنفس الآلية** (`agedClearanceFocusProvider`)
/// ⛔ **لا بمسارِ كتابةٍ ثانٍ.**
/// ═══════════════════════════════════════════════════════════════════════
///
/// ⚠️⚠️ **وكل بوابةٍ هنا إخفاءٌ لا حماية** — ★ **والحارسُ الحقيقي
/// `agedClearanceRejection` في الدالة الكاتبة** (`ADR-0013` القاعدة 3 ·
/// `RISK-02`).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qtms_domain/qtms_domain.dart';

import '../../../app/router.dart';
import '../../../app/top_bar.dart';
import '../../../core/design/design_tokens.dart';
import '../../../core/ui/async_state_view.dart';
import '../../../core/ui/date_labels.dart';
import '../../../core/ui/filter_bar.dart';
import '../../../core/ui/search_field.dart';
import '../../../core/ui/status_pill.dart';
import '../../identity_access/application/session_providers.dart';
import '../../master_data/application/master_data_providers.dart';
import '../application/aged_remainder_providers.dart';
import '../application/inventory_providers.dart';
import 'inventory_widgets.dart';

/// ★★★ **الثلاثيةُ اللونية لدرجة الحدّة** — `FR-M8-10` (**تدرّجٌ حسب العمر**).
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⚠️⚠️★★★ **وقرارٌ تنفيذيٌّ مُعلَنٌ لا انحرافٌ صامت** (`WU-019` · 2026-09-04):
/// ★ **المتطلب يذكر ثلاثَ درجات (🟡 · 🟠 · 🔴)**، ⛔ **ولوحةُ التوكنز بلا
/// عائلةٍ برتقالية بين الذهبي والطيني** (`design-tokens.md` §2.3: **أربع
/// عائلاتٍ دلالية**) — ★ **وإدخالُ لونٍ خارج الشعار يحتاج قرارَ مالكٍ مسجَّلاً
/// كما في** [`DS-003`](../../../../docs/00-governance/upds-workflow/design-source-selection.md)
/// ⛔ **لا اجتهاداً في شاشة.**
///
/// ✅ **فالدرجاتُ ثلاثٌ فعلاً بعائلتين وأيقونتين:** ⟵ **`warning` للحديث،
/// و`danger` لما تجاوز اليومين — بأيقونتين مختلفتين** ⟵ **فالثلاثُ متمايزةٌ
/// بصرياً بلا لونٍ مخترَع.**
///
/// ⛔⛔★★ **ولا معنى يُنقَل باللون وحده على كل حال** — `design-system.md` §8
/// المحظور الثاني عشر: ★ **وعمرُ البند مكتوبٌ رقماً في كل صفٍّ**
/// (`FR-M8-18`)، ⟵ **فالحدّةُ تُسرِّع القراءة** ⛔ **ولا تحملها.**
///
/// ★ **والربطُ الدلالي من `design-system.md` §3.4 و`design-tokens.md` §2.3:**
/// **الذهبي «قيمةٌ مؤجَّلة لا خطأ»** · **والطيني «ما يتقادم ويضرّ»** —
/// ⟵ **وهو بالضبط ما يفعله الزمن ببضاعةٍ لم تُصرَّف.**
/// ═══════════════════════════════════════════════════════════════════════
ColorTriad agedSeverityTriad(AgedRemainderSeverity severity) =>
    switch (severity) {
      AgedRemainderSeverity.recent => SemanticTriads.warning,
      AgedRemainderSeverity.ageing => SemanticTriads.danger,
      AgedRemainderSeverity.overdue => SemanticTriads.danger,
    };

/// ★ أيقونةُ الدرجة — ★ **وهي الفارقُ الثالث بين الدرجتين الأشدّ.**
IconData agedSeverityIcon(AgedRemainderSeverity severity) =>
    switch (severity) {
      AgedRemainderSeverity.recent => Icons.schedule_outlined,
      AgedRemainderSeverity.ageing => Icons.warning_amber_outlined,
      AgedRemainderSeverity.overdue => Icons.error_outline,
    };

/// ★★ وصفُ العمر نصّاً — ⛔ **ولا يُترك للون وحده** (§8 المحظور الثاني عشر).
String agedAgeLabel(int ageInDays) => switch (ageInDays) {
      1 => 'منذ يوم',
      2 => 'منذ يومين',
      _ => 'منذ $ageInDays أيام',
    };

/// شاشة متبقي الأيام السابقة.
class AgedRemainderScreen extends ConsumerStatefulWidget {
  /// ينشئ الشاشة.
  const AgedRemainderScreen({super.key});

  @override
  ConsumerState<AgedRemainderScreen> createState() =>
      _AgedRemainderScreenState();
}

class _AgedRemainderScreenState extends ConsumerState<AgedRemainderScreen> {
  final TextEditingController _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    // ★ **والتصفيةُ قرارُ الشاشة لا قرارُ الحقل** — `QtmsSearchField` نصّاً:
    //   «**ويستمع إليه المُنادي بنفسه**».
    _search.addListener(_onSearchChanged);
  }

  void _onSearchChanged() => setState(() {});

  @override
  void dispose() {
    _search.removeListener(_onSearchChanged);
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final CalendarDay today = ref.watch(todayProvider);
    final List<SourceCard> sources = ref.watch(activeSourcesProvider);
    final String? filter = ref.watch(sourceListFilterProvider);
    final AsyncValue<List<AgedRemainderDay>> days =
        ref.watch(agedRemainderDaysProvider(filter));

    return Scaffold(
      appBar: const QtmsTopBar(screenTitle: 'متبقي الأيام السابقة'),
      body: Column(
        children: <Widget>[
          // ⛔⛔★★ **ومرشِّحُ عرضٍ لا سياقُ عملية** — ⟵ **و`null` تعني «كل
          //    المصادر»** (`AM-009` ③): ★ **فالشاشةُ تُلاحق ما لم يُصرَّف في
          //    نطاق المستخدم كلِّه**، ⛔ **والكتابةُ تقع على مصدرٍ واحدٍ
          //    مثبَّتٍ من البند** (`A-01` · `FR-M8-12`).
          if (sources.isEmpty)
            const QtmsFilterBar.notice(
              // ⚠️ **نطاقٌ فارغ حالةٌ حقيقية لا عطل** — `E-35`.
              message: 'لا يوجد مصدر ضمن نطاقك. راجع المدير.',
            )
          else
            QtmsFilterBar(
              groups: <List<QtmsFilterOption>>[
                <QtmsFilterOption>[
                  QtmsFilterOption(
                    label: 'كل المصادر',
                    selected: filter == null,
                    onSelected: () =>
                        ref.read(sourceListFilterProvider.notifier).select(null),
                  ),
                  for (final SourceCard source in sources)
                    QtmsFilterOption(
                      label: source.name,
                      selected: filter == source.sourceId,
                      onSelected: () => ref
                          .read(sourceListFilterProvider.notifier)
                          .select(source.sourceId),
                    ),
                ],
              ],
            ),
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: Spacing.screenPadding,
            ),
            // ★ **بحثٌ فوري داخل الأسماء المركّبة** — `FR-M8-18`: ⟵ **باسم
            //   الرعوي أو رقم الجونية** (**كلاهما جزءٌ من المفتاح المركّب**
            //   — `ADR-0007`).
            child: QtmsSearchField(
              controller: _search,
              label: 'بحث في الأنواع',
            ),
          ),
          const SizedBox(height: Spacing.space12),
          Expanded(
            child: AsyncStateView<AgedRemainderDay>(
              value: days,
              empty: const EmptyStateSpec(
                icon: Icons.event_available_outlined,
                title: 'لا متبقي من أيام سابقة',
                // ★ **الحالةُ الفارغة تقول السبب** — `ui-guidelines.md` §6:
                //   ⛔ **لا «لا توجد بيانات».**
                message: 'كل مخزون الأيام الماضية صُرِّف بالكامل.',
                triad: SemanticTriads.success,
              ),
              errorMessage: (Object _) =>
                  'تحقق من صلاحيتك ونطاق مصادرك، ثم أعد المحاولة.',
              builder: (List<AgedRemainderDay> list) {
                final List<AgedRemainderDay> visible = _filtered(list);
                if (visible.isEmpty) {
                  return const QtmsNoMatch(
                    message: 'لا نوع يطابق البحث في المتبقي المتأخر.',
                  );
                }
                return ListView(
                  // ⛔ **وحشوٌ اتجاهيٌّ لا موضعي** — بوابة الاتجاه.
                  padding: const EdgeInsetsDirectional.only(
                    start: Spacing.screenPadding,
                    end: Spacing.screenPadding,
                    bottom: Spacing.fabSafeBottom,
                  ),
                  children: <Widget>[
                    for (final AgedRemainderDay day in visible) ...<Widget>[
                      _DaySection(day: day, today: today, sources: sources),
                      const SizedBox(height: Spacing.space16),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// ★ تصفيةُ البحث — ⛔ **ويُسقَط اليومُ الذي لم يبقَ فيه بندٌ مطابق**:
  /// ⟵ **فعنوانُ يومٍ بلا بنودٍ تحته يُقرأ عطلاً.**
  List<AgedRemainderDay> _filtered(List<AgedRemainderDay> days) {
    final String query = _search.text.trim();
    if (query.isEmpty) return days;
    return <AgedRemainderDay>[
      for (final AgedRemainderDay day in days)
        if (day.items
            .where((AgedRemainderCard card) => card.displayName.contains(query))
            .toList()
        case final List<AgedRemainderCard> matched when matched.isNotEmpty)
          AgedRemainderDay(
            stockDate: day.stockDate,
            ageInDays: day.ageInDays,
            items: matched,
          ),
    ];
  }
}

/// ★★ قسمُ يومٍ واحد — **عنوانُه تاريخُ المخزون وعمرُه**، وتحته بنودُه.
class _DaySection extends StatelessWidget {
  const _DaySection({
    required this.day,
    required this.today,
    required this.sources,
  });

  final AgedRemainderDay day;
  final CalendarDay today;
  final List<SourceCard> sources;

  @override
  Widget build(BuildContext context) {
    final ColorTriad triad = agedSeverityTriad(day.severity);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            IconBadgeBox(icon: agedSeverityIcon(day.severity), triad: triad),
            const SizedBox(width: Spacing.space12),
            Expanded(
              child: Text(
                // ★★ **والتاريخ مُصرَّحٌ بنوعه** — `ui-guidelines.md` §2:
                //   ⛔ **لا كلمة «التاريخ» وحدها.**
                'مخزون يوم ${dayLabel(day.stockDate)}',
                style: TypeScale.titleSm,
              ),
            ),
            StatusPill(label: agedAgeLabel(day.ageInDays), triad: triad),
          ],
        ),
        const SizedBox(height: Spacing.space8),
        for (final AgedRemainderCard card in day.items) ...<Widget>[
          _RemainderTile(card: card, today: today, sources: sources),
          const SizedBox(height: Spacing.space8),
        ],
      ],
    );
  }
}

/// ★ بطاقةُ بندٍ متأخر — **الاسمُ والمصدرُ والمتبقّي وإجراءا التصريف**.
class _RemainderTile extends ConsumerWidget {
  const _RemainderTile({
    required this.card,
    required this.today,
    required this.sources,
  });

  final AgedRemainderCard card;
  final CalendarDay today;
  final List<SourceCard> sources;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ⛔⛔★★★ **والصلاحيتان لا تُغني إحداهما عن الأخرى** —
    //    `authentication-and-authorization.md` §5 (`E4` من `UC-004`):
    //    ★ **«تصريف المتبقي المتأخر» + «إضافة توزيعة»** للتوزيع،
    //    ★ **و«تصريف المتبقي المتأخر» + «إضافة بيع نقدي»** للبيع.
    //    ⚠️⚠️ **وإخفاءٌ لا حماية** — ★ **والرفضُ في السحابة.**
    final bool canClear =
        ref.watch(hasPermissionProvider(Permission.agedRemainderClear));
    final bool canDistribute =
        canClear && ref.watch(hasPermissionProvider(Permission.distributionCreate));
    final bool canSell =
        canClear && ref.watch(hasPermissionProvider(Permission.cashSaleCreate));
    final bool canDispose =
        canClear && ref.watch(hasPermissionProvider(Permission.disposalCreate));

    // ★★ **واسمُ المصدر إلزاميٌّ في وضع «الكل»** — `AM-009` ③: ⟵ **فصفٌّ بلا
    //   مصدرٍ في قائمةٍ تجمع مصادرَ لا يُقرأ** (`A-01`).
    final String sourceName = sources
            .where((SourceCard source) => source.sourceId == card.sourceId)
            .map((SourceCard source) => source.name)
            .firstOrNull ??
        card.sourceId;

    return InventoryTile(
      title: card.displayName,
      subtitle: 'المصدر: $sourceName',
      trailing: quantityLabel(card.remaining),
      actions: <Widget>[
        if (canDistribute)
          TextButton(
            onPressed: () => _open(context, ref, distributionRoute),
            child: const Text('توزيع'),
          ),
        if (canSell)
          TextButton(
            onPressed: () => _open(context, ref, cashSaleRoute),
            child: const Text('بيع نقدي'),
          ),
        // ★★★ **والإتلافُ ثالثُ الإجراءات** (`FR-M8-11` · `WU-020`) —
        //    ⛔⛔ **ومفتاحان لا مفتاحٌ واحد:** ★ **«تصريف المتبقي المتأخر»
        //    + «الإتلاف»** — ⟵ **بنفس قاعدة التوزيع والبيع حرفياً**
        //    (`FR-M8` §5: «**صلاحيات لا تُغني عن بعضها**»).
        if (canDispose)
          TextButton(
            onPressed: () => _open(context, ref, disposalRoute),
            child: const Text('إتلاف'),
          ),
      ],
    );
  }

  /// ★★★ يفتح شاشةَ التصريف **مثبَّتةً على البند** — `FR-M8-12` · `UC-004` ③.
  void _open(BuildContext context, WidgetRef ref, String route) {
    ref.read(agedClearanceFocusProvider.notifier).request(
          AgedClearanceFocus(
            sourceId: card.sourceId,
            itemKey: card.itemKey,
            stockDate: card.stockDate,
          ),
        );
    context.go(route);
  }
}

/// ★★★ **شريطُ التنبيه البارز في شاشة التصريف المثبَّتة** — `FR-M8-12` نصّاً.
///
/// ⛔⛔★★★ **ونصُّه من المتطلب حرفياً** — ⟵ **فما يقرؤه المستخدم هو ما اعتُمد**:
/// «⚠️ **أنت تصرّف مخزون يوم {التاريخ} — سيُحتسب في ضمار ذلك اليوم لا في
/// اليوم الحالي**».
///
/// ★ **وشريطٌ تنبيهيٌّ لحالةٍ قائمة لا حبّةٌ عائمة** (`design-system.md` §6.ز):
/// ⟵ **فالتثبيتُ حالةٌ تدوم ما دامت الورقة مفتوحة** ⛔ **لا حدثٌ عابر.**
class AgedClearanceBanner extends StatelessWidget {
  /// ينشئ الشريط.
  const AgedClearanceBanner({required this.stockDate, super.key});

  /// تاريخ المخزون المثبَّت.
  final CalendarDay stockDate;

  @override
  Widget build(BuildContext context) => Container(
        // ⛔ **ولا هامشَ من عنده** — ★ **الحاويةُ تحشو** (`design-system.md`
        //   §5 القاعدة 1): ⟵ **فحشوان متجاوران يكسران سلّم المسافات.**
        padding: const EdgeInsets.all(Spacing.space12),
        decoration: BoxDecoration(
          color: SemanticTriads.warning.soft,
          border: Border.all(
            color: SemanticTriads.warning.border,
            width: Sizes.borderWidth,
          ),
          borderRadius: BorderRadius.circular(Radii.card),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(
              Icons.warning_amber_outlined,
              size: Sizes.iconMd,
              color: SemanticTriads.warning.ink,
            ),
            const SizedBox(width: Spacing.space8),
            Expanded(
              child: Text(
                'أنت تصرّف مخزون يوم ${dayLabel(stockDate)} — '
                'سيُحتسب في ضمار ذلك اليوم لا في اليوم الحالي.',
                style: TypeScale.bodyMd
                    .copyWith(color: SemanticTriads.warning.ink),
              ),
            ),
          ],
        ),
      );
}

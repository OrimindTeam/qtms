/// شاشة **مركز الإدخالات المعلّقة** — **نمط 2** (`ui-guidelines.md` §3).
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **يلاحق ويذكّر ولا يمنع** — `GR-50` · `FR-SYS-06` (**حرجة**):
/// ⟵ **فلا زرَّ يحفظ هنا، ولا عمليةَ تُعطَّل من هذه الشاشة، ولا حقلَ
/// يُدخَل فيها.** ★ **وكلُّ ما تفعله: تُظهر ما ينقص وتفتح شاشتَه.**
///
/// ⛔⛔★★★ **ولا شاشة إدخالٍ بديلة** — `FR-SYS-04` · §6 من مستند الوحدة:
/// «**بناء شاشة إدخال موحّدة داخل المركز مخالفة تصميمية — تُنتج مساراً
/// ثانياً للكتابة بقواعد تحقّق منفصلة تفترق عن الأصلية**». ⟵ **وزرُّ
/// [ إدخال ] يفتح الشاشة الأصلية على سياق البند** ⛔ **ولا نموذجَ هنا.**
///
/// ⚠️⚠️ **وبلا بوابة صلاحية** — ⛔ **لا مفتاح لها في الكتالوج §2**:
/// ★ **والقاعدة تكتفي بالنطاق** (`isSignedIn() && storedInScope()`)،
/// ⟵ **وبوابةٌ هنا كانت ستُخفي شاشةً تسمح بها القاعدة** (نفس ما فُعِل
/// بمخزون اليوم والتسعير في `home_shell.dart`).
/// ═══════════════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qtms_domain/qtms_domain.dart';

import '../../../app/top_bar.dart';

import '../../../app/router.dart';
import '../../../core/design/design_tokens.dart';
import '../../../core/messages/error_messages.dart';
import '../../../core/ui/async_state_view.dart';
import '../../../core/ui/date_labels.dart';
import '../../../core/ui/entity_tile.dart';
import '../../../core/ui/filter_bar.dart';
import '../../../core/ui/inline_banner.dart';
import '../../../core/ui/status_pill.dart';
import '../../inventory/application/inventory_providers.dart';
import '../../inventory/presentation/supply_intake_screen.dart';
import '../application/pending_entries_providers.dart';

/// شاشة مركز الإدخالات المعلّقة.
class PendingEntriesScreen extends ConsumerWidget {
  /// ينشئ الشاشة.
  const PendingEntriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<PendingEntryCard>> entries =
        ref.watch(pendingEntriesProvider);

    return Scaffold(
      appBar: QtmsTopBar(screenTitle: 'الإدخالات المعلّقة'),
      body: Column(
        children: <Widget>[
          const _PendingFilterBar(),
          const _RemindsNotEnforcesNotice(),
          const SizedBox(height: Spacing.space8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.screenPadding,
              ),
              child: AsyncStateView<PendingEntryCard>(
                value: entries,
                errorMessage: (Object _) =>
                    readRejectionMessage,
                onRetry: () => ref.invalidate(pendingEntriesProvider),
                empty: const EmptyStateSpec(
                  icon: Icons.task_alt_outlined,
                  triad: SemanticTriads.success,
                  title: 'لا قيمة معلّقة في هذا المصدر',
                  // ★ **سببُ الفراغ والخطوةُ التالية** — `ui-guidelines.md` §6.
                  message: 'كل ما حُفظ هنا مكتملُ القيم. '
                      'وأي قيمة تُترك لاحقاً ستظهر في هذه الشاشة فوراً.',
                ),
                builder: (List<PendingEntryCard> items) {
                  // ★★★ **بطاقةٌ لكلِّ مستند لا لكلِّ قيمةٍ ناقصة** — `AM-025` ①
                  //    (`pending-entries-design.md` §13) — ⛔ **والتجميعُ عرضٌ**
                  //    ★ **والسجلُّ نفسُه سطرٌ لكلِّ قيمةٍ كما هو** (`FR-SYS-09`).
                  final List<_PendingGroup> groups = _groupByDocument(items);
                  return ListView.separated(
                    padding: const EdgeInsets.only(
                      bottom: Spacing.fabSafeBottom,
                    ),
                    itemCount: groups.length,
                    separatorBuilder: (BuildContext context, int index) =>
                        const SizedBox(height: Spacing.cardGap),
                    itemBuilder: (BuildContext context, int index) =>
                        _PendingTile(group: groups[index]),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ★★ شريطٌ يُعلن أن المركز يذكّر ولا يمنع — ⛔ **ولا يُخفى**.
///
/// ⚠️⚠️ **ولماذا يُعرَض دائماً:** `FR-SYS-06` **متطلبٌ حرج**، ⟵ **ومستخدمٌ
/// يظنّ أن بنداً معلّقاً يمنعه من الإقفال يتوقّف عن العمل بلا سبب** —
/// ★ **وإعلانُ القاعدة جزءٌ من أثرها** (بنفس منطق شريط سجل التدقيق).
class _RemindsNotEnforcesNotice extends StatelessWidget {
  const _RemindsNotEnforcesNotice();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: Spacing.screenPadding),
        child: QtmsInlineBanner(
          text: 'هذه الشاشة تذكّر ولا تمنع — لا شيء هنا يوقف حفظاً '
              'ولا توزيعاً ولا تصديراً.',
          triad: SemanticTriads.info,
        ),
      );
}

/// ★★ شريط الفلاتر — `FR-SYS-10`: **المصدر · نوع المستند**.
///
/// ⛔⛔★★★ **والمصدر أولاً وفي كل حال** — ★ **استعلامٌ بلا قيدٍ عليه يُرفَض
/// من القاعدة كاملاً** (راجع `FirestorePendingEntryDirectory`)، ⟵ **فلا
/// بطاقةَ «كل المصادر» هنا** ⛔ **ولو ملك المستخدم النطاق الشامل.**
///
/// ⚠️ **وفلترُ التاريخ ليس شريحة** — `FR-SYS-10` يذكره، ★ **والقائمة مرتَّبةٌ
/// بالتاريخ تنازلياً أصلاً والتاريخ ظاهرٌ في كل بطاقة**: ⟵ **ومدىً زمنيٌّ
/// على مجموعةٍ لا تتجاوز صفحةً واحدة زينةٌ لا أداة.** ★ **وأثرٌ معلَن.**
class _PendingFilterBar extends ConsumerWidget {
  const _PendingFilterBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PendingEntryFilter? filter = ref.watch(pendingFilterProvider);
    final PendingFilterState controller =
        ref.read(pendingFilterProvider.notifier);
    final List<SourceCard> sources = ref.watch(pendingSourceOptionsProvider);

    if (sources.isEmpty) {
      // ⚠️ **نطاقٌ فارغ حالةٌ حقيقية** — `E-35`: مستخدمٌ بلا مصدر.
      return const QtmsFilterBar.notice(
        message: 'لا يوجد مصدر ضمن نطاقك. راجع المدير.',
      );
    }

    return QtmsFilterBar(
      groups: <List<QtmsFilterOption>>[
        <QtmsFilterOption>[
          for (final SourceCard source in sources)
            QtmsFilterOption(
              label: source.name,
              selected: filter?.sourceId == source.sourceId,
              onSelected: () => controller.selectSource(source.sourceId),
            ),
        ],
        <QtmsFilterOption>[
          QtmsFilterOption(
            label: 'الكل',
            selected: filter?.kind == null,
            onSelected: () => controller.selectKind(null),
          ),
          for (final PendingDocumentKind kind in PendingDocumentKind.values)
            QtmsFilterOption(
              label: kind.label,
              selected: filter?.kind == kind,
              onSelected: () => controller.selectKind(kind),
            ),
        ],
      ],
    );
  }
}

/// ★★★ مجموعةُ بنودٍ لمستندٍ واحد — `AM-025` ① (`pending-entries-design.md` §13).
///
/// ⛔⛔★★★ **ولماذا مفتاحُ التجميع النوعُ والمعرّفُ معاً** — ⛔ **لا المعرّفُ
/// وحدَه:** ★ **معرّفان متطابقان من نوعين مختلفين مستندان مختلفان** —
/// ⟵ **وجمعُهما كان يُنتج بطاقةً تخلط شاراتِ مستندين**، ★ **وهو أسوأ من
/// التكرار الذي جاء هذا القسمُ يعالجه أصلاً.**
final class _PendingGroup {
  const _PendingGroup({required this.head, required this.entries});

  /// أوّلُ بندٍ في المجموعة — ★ **ومنه العنوانُ والرقمُ والتاريخ.**
  final PendingEntryCard head;

  /// كلُّ بنود المستند — ★ **شارةٌ لكلٍّ منها** (§13).
  final List<PendingEntryCard> entries;

  /// ★★ أوّلُ بندٍ يملك وجهةً صالحة — و`null` **إن لم يملكها أيٌّ منها**.
  ///
  /// ⛔ **ومجموعةٌ بلا وجهةٍ تُعرَض ولا تُفتَح** — ★ **فاختفاؤها يُخفي نقصاً
  /// قائماً** (`GR-50`)، ⟵ **وفتحُها على شاشةٍ مُخمَّنة أسوأ.**
  PendingEntryCard? get destination {
    for (final PendingEntryCard entry in entries) {
      if (entry.hasDestination) return entry;
    }
    return null;
  }
}

/// ★★★ يجمع بنودَ المستند الواحد في مجموعةٍ واحدة — **بحفظ ترتيب الدليل**.
///
/// ⚠️ **والترتيبُ محفوظٌ بحكم ترتيب الإدراج في `Map`** — ★ **وهو الافتراض في
/// Dart**: ⟵ **فالمجموعةُ تقع في موضع أوّلِ بندٍ منها**، ⛔ **ولا يُعاد الفرزُ
/// فيقفز مستندٌ فوق أحدثَ منه** (**الدليل يُرجِعها بالتاريخ تنازلياً**).
List<_PendingGroup> _groupByDocument(List<PendingEntryCard> items) {
  final Map<String, List<PendingEntryCard>> byDocument =
      <String, List<PendingEntryCard>>{};
  for (final PendingEntryCard item in items) {
    final String key = '${item.kind?.name ?? 'غير معروف'}/${item.documentId}';
    byDocument.putIfAbsent(key, () => <PendingEntryCard>[]).add(item);
  }
  return <_PendingGroup>[
    for (final List<PendingEntryCard> group in byDocument.values)
      _PendingGroup(head: group.first, entries: group),
  ];
}

/// ★★★ بطاقةُ مستندٍ معلَّق — **عنوانٌ مقروء + شارةٌ لكلِّ قيمةٍ ناقصة + زر [ إدخال ]**.
///
/// ⛔⛔★★★ **وبطاقةٌ واحدةٌ للمستند لا لكلِّ قيمة** — `AM-025` ① (§13):
/// ⚠️ **والعطلُ مقيسٌ بلقطةٍ فعلية لا مفترَض:** ★ **«جونية رقم 2» ظهرت
/// ببطاقتين عنوانُهما وسطرُهما الثانوي متطابقان حرفياً**، ⟵ **فتُقرآن عند
/// المسح السريع مستندين مختلفين** ⛔ **لا مستنداً واحداً ينقصه شيئان.**
///
/// ⛔⛔ **وسجلُّ البنود لم يُمَسّ** — ★ **السحابةُ تكتبه وتمحوه بندَ بند**
/// (`FR-SYS-09`): ⟵ **والتجميعُ عرضٌ في الشاشة وحدَها**، ★ **والعدّادُ يبقى
/// عددَ القيم لا عددَ المستندات.**
class _PendingTile extends ConsumerWidget {
  const _PendingTile({required this.group});

  final _PendingGroup group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PendingEntryCard head = group.head;
    final PendingEntryCard? destination = group.destination;
    return EntityTile(
      leading: IconBadgeBox(
        icon: Icons.hourglass_bottom_outlined,
        // ★★ **⏳ برتقالية موحّدة في كل النظام** — §4 من مستند الوحدة:
        //    ⛔ **ولا شكلَ بديل في أي شاشة**، ★ **وعائلةُ «تنبيه · تأخّر»
        //    هي `warning`** (`design-system.md` §3.4).
        triad: SemanticTriads.warning,
      ),
      title: head.readableTitle,
      subtitle: _subtitle(head),
      // ★★ **شارةٌ لكلِّ قيمةٍ ناقصة** — ★ **و[EntityTile] تضعها في `Wrap`
      //    في سطرها المستقل أصلاً** (`DEBT-36`): ⛔ **فلا تُزاحم النصّ.**
      badges: <Widget>[
        for (final PendingEntryCard entry in group.entries)
          StatusPill(
            label: entry.missingField,
            triad: SemanticTriads.warning,
            icon: Icons.hourglass_empty,
          ),
      ],
      actions: <Widget>[
        if (destination case final PendingEntryCard target)
          // ★★ **زرٌّ واحدٌ للمستند** — §13: ⟵ **كلُّ حقولِه تُفتَح من شاشته
          //    هي** (§6)، ⛔ **فزرٌّ لكلِّ شارةٍ تكرارٌ بلا وجهةٍ ثانية.**
          TextButton(
            onPressed: () => _open(context, ref, target),
            child: const Text('إدخال'),
          )
        else
          // ⛔ **بندٌ من إصدارٍ أحدث يُعرَض ولا يُفتَح** — ★ **فاختفاؤه
          //   يُخفي نقصاً قائماً**، ⛔ **وفتحُه على شاشةٍ مُخمَّنة أسوأ.**
          Text(
            'حدِّث التطبيق لفتح هذا البند',
            style: TypeScale.caption
                .copyWith(color: SemanticColors.textTertiary),
          ),
      ],
      // ★ **وقارئُ الشاشة يسمع المجموعة مجموعةً** — §13.
      semanticLabel: '${head.readableTitle} — ${_missingFields(group)}',
    );
  }

  /// ★ كلُّ القيم الناقصة في نصٍّ واحد — **للوصف الدلالي وحدَه**.
  static String _missingFields(_PendingGroup group) => group.entries
      .map((PendingEntryCard entry) => entry.missingField)
      .join(' · ');

  /// ★ سطرٌ ثانويٌّ واحد — **الرقم والتاريخ** (§6.د: سطرٌ واحد لا أكثر).
  static String _subtitle(PendingEntryCard entry) {
    final String date = entry.date == null
        ? 'بلا تاريخ'
        : 'تاريخ المخزون ${dayLabel(entry.date!)}';
    final String? number = entry.documentNumber;
    return number == null ? date : '$number · $date';
  }

  /// ★★★ **يفتح الشاشة الأصلية على سياق البند** — `FR-SYS-04`.
  ///
  /// ═════════════════════════════════════════════════════════════════════
  /// ⛔⛔ **ولا نموذجَ إدخالٍ هنا** (§6 من مستند الوحدة) — ★ **والسياق
  /// يُهيَّأ في مزوّداته قبل الملاحة**، ⟵ **فالشاشة الأصلية تُفتَح جاهزةً
  /// بلا أن تعرف بالمركز شيئاً** ⛔ **ولا يتسرّب المركز إلى ثلاث شاشات.**
  ///
  /// ★ **والمصدر أولاً وفي كل حال** — ★ **كل شاشةٍ تشغيلية مقيَّدةٌ بمصدرها**
  /// (`A-01`)، ⟵ **وشاشةٌ تُفتَح على مصدرٍ آخر تعرض «لا بيانات» فيبدو البند
  /// كذباً.**
  ///
  /// ★★ **ثم ما يخصّ كل نوع:**
  ///   · **التسعير** ⟵ **مرشِّح «لم يُسعَّر»** فيصير الحقلُ الناقص أول
  ///     ما يُرى (`FR-M9-05`) — ⛔ **بلا قائمةٍ كاملة يبحث فيها.**
  ///   · **التوزيع** ⟵ **المقوت المقصود** ([PendingFocus.dealerId]) —
  ///     ★ **وهو حالةٌ محلية في تلك الشاشة**، ⟵ **فيُمرَّر عبر
  ///     [pendingFocusProvider].**
  ///   · **الجونية** ⟵ **المصدر وحده يكفي**: ★ **القائمة تعرض جواني اليوم
  ///     بشاراتها ⏳**، ⛔ **ولا حالةَ اختيارٍ ثانية فيها تُضبَط.**
  ///
  /// ⚠️⚠️ **وحدٌّ معلَن لا يُطوى** (`DEBT-64`): ★ **الوجهةُ تفتح الشاشة على
  /// سياق البند** ⛔ **ولا تفتح الورقة السفلية للحقل نفسه** — ⟵ **فبندُ
  /// «ضريبة الكيلو» يصل قائمةَ الجواني لا نموذجَ الضريبة.**
  /// ═════════════════════════════════════════════════════════════════════
  static void _open(BuildContext context, WidgetRef ref, PendingEntryCard e) {
    final PendingDocumentKind kind = e.kind!;
    ref.read(selectedSourceProvider.notifier).select(e.sourceId);

    switch (kind) {
      case PendingDocumentKind.dailyPrice:
        ref
            .read(pricingFilterProvider.notifier)
            .select(PricingStatusFilter.unpriced);
      case PendingDocumentKind.distribution:
        ref.read(pendingFocusProvider.notifier).request(
              PendingFocus(
                kind: kind,
                sourceId: e.sourceId,
                documentId: e.documentId,
                field: e.field!,
              ),
            );
      // ★★★ **والجونيةُ تبويبٌ في «التوريد مخزني» منذ `AM-012` §2** —
      //    ⟵ **فتُفتَح الشاشةُ على تبويبها** ⛔ **لا على «الوارد عدداً»**:
      //    ★ **وبندٌ يصل تبويباً لا يخصّه يُقرأ عطلاً في الوجهة.**
      case PendingDocumentKind.sack:
        break;
      // ★★ **وبندُ `M22` يفتح شاشةَ السحبيات على مصدره** (`WU-014`) —
      //   ⚠️ **ولا تركيزَ على بندٍ بعينه فيها بعد**: ⟵ **فالشاشةُ اليومَ
      //   نموذجُ إنشاءٍ لا قائمةَ سنداتٍ تُفتَح على سند** (`FR-M22-13`
      //   موضعُه `WU-018`) — ★ **وهو حدٌّ مُعلَنٌ لا سهو**، ⛔ **وادّعاءُ
      //   تركيزٍ لا يقع كان أسوأ من غيابه** (`DEBT-64` نفسُه).
      case PendingDocumentKind.outflow:
        break;
    }

    // ★★ **والتبويبُ يُمرَّر حالةَ ملاحةٍ لا معاملاً في الرابط** — `router.dart`:
    //    ⟵ **فلا رابطٌ يُشارَك يفتح نصفَ الشاشة** (نفسُ علّة `auditLogRoute`).
    context.go(
      pendingScreenRoute(kind.screen),
      extra: kind == PendingDocumentKind.sack ? supplyIntakeSackTab : null,
    );
  }
}

/// عناصر مشتركة لشاشات المخزون — **نمطا 2 و4** (`ui-guidelines.md` §3).
///
/// ⚠️⚠️ **وكل ما هنا عرضٌ لا حماية** — ★ **والرفض الحقيقي في السحابة**
/// (`ADR-0013` القاعدة 3 · `RISK-02`).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qtms_domain/qtms_domain.dart';

import '../../../core/design/design_tokens.dart';
import '../../../core/ui/item_labels.dart';
import '../../../core/design/theme_extensions.dart';
import '../../../core/ui/async_state_view.dart';
import '../../../core/ui/date_labels.dart';
import '../../../core/ui/entity_tile.dart';
import '../../../core/ui/status_pill.dart';
import '../../master_data/application/master_data_providers.dart';
import '../application/inventory_providers.dart';

/// ★★ **وصف الكمية بوحدتها** — `FR-M8-07` · `GR-19`.
///
/// ⛔★★ **ولا دالة تعرض رقماً بلا وحدته:** «الأنواع بالحبة والأنواع
/// بالكيلوجرام تُعرض معاً **مع عمود الوحدة**، **ولا تُجمع إجمالياتها معاً
/// إطلاقاً**» — ⟵ **ورقمٌ عارٍ يُغري بجمعٍ ممنوع.**
String quantityLabel(StockQuantity quantity) => switch (quantity) {
      PieceQuantity(:final PieceCount count) => '${count.pieces} حبة',
      WeightQuantity(:final WeightKg weight) => '${weight.formatted()} كجم',
    };

/// وصف الوحدة بالعربية — ⛔ **ولا مصطلح تقني في الواجهة** (§6).
String unitName(ItemUnit unit) => switch (unit) {
      ItemUnit.piece => 'حبة',
      ItemUnit.kilogram => 'كيلوجرام',
    };

/// ★★★ **نصُّ خيار النوع في القائمة المنسدلة** — `FR-M10-06` حرفياً:
/// «**عوارض (80 حبة)**» · «**سكرب - ع.الفتاح - ج١ (1.200 كجم)**».
///
/// ⛔⛔★★★ **والمتبقّي جزءٌ من النصّ لا عمودٌ مجاور** — `AM-009` ⑥: ⟵ **فمن
/// يختار نوعاً يرى كم بقي منه *في لحظة الاختيار*** ⛔ **لا بعد أن يكتب رقماً
/// يُرفَض.** ★ **وهو بندٌ موثَّقٌ منذ اعتماد `FR-M10`** — ⟵ **كان بلا تطبيق.**
///
/// ⚠️ **و[remaining] الغائبة تعني رصيداً صفراً** — `ADR-0008` القاعدة 5،
/// ⛔ **لا «رصيداً مجهولاً»**: ★ **والصفرُ يُعرَض صريحاً** ⟵ **فلا يُخفى
/// عن المستخدم أن النوع نفد.**
///
/// ★★★ **وتقبل وزنَ الحبة والتفضيل منذ `AM-012` §4.4** — ⛔ **ولا تقرأ
/// مزوّداً بنفسها:** ⟵ **فتبقى دالةً خالصةً تُختبَر بلا شجرة**، ★ **والقراءةُ
/// في الشاشة المُستدعية** (`ADR-0010` القاعدة 5).
///
/// ⛔⛔ **وترتيبُ اللاحقتين مقصود:** **الاسمُ ⟵ وزنُ الحبة ⟵ المتبقّي** —
/// ★ **فالوزنُ جزءٌ من هوية النوع** (لاحقةُ اسم)، ⛔ **والمتبقّي حالةٌ لحظية**:
/// ⟵ **«بطّوه وزن (200 جرام) (80 حبة)»** ★ **يُقرأ من اليمين هويةً ثم حالة.**
String itemOptionLabel(
  String name,
  StockQuantity? remaining, {
  bool showPieceWeight = false,
  double? pieceWeightGrams,
}) {
  final String label = itemDisplayName(
    name,
    showPieceWeight: showPieceWeight,
    pieceWeightGrams: pieceWeightGrams,
  );
  return remaining == null ? label : '$label (${quantityLabel(remaining)})';
}


/// ★ عارض تدفّق شاشات المخزون — ★ **يفوّض لمبدّل الحالات المشترك.**
///
/// ⛔⛔ **ولا نسخةَ ثانية من المبدّل** (§8 المحظور الحادي عشر) — ★ **وما يبقى
/// هنا نصوصُ المجال وحدها:** ⟵ **فالسلوك واحدٌ في التطبيق كله، والكلامُ محلّي.**
class InventoryAsyncView<T> extends StatelessWidget {
  /// ينشئ العارض.
  const InventoryAsyncView({
    required this.value,
    required this.emptyLabel,
    required this.builder,
    this.emptyIcon = Icons.inventory_2_outlined,
    this.emptyTitle = 'لا توجد سجلات بعد',
    this.onRetry,
    super.key,
  });

  /// التدفّق المعروض.
  final AsyncValue<List<T>> value;

  /// ★ نصّ الحالة الفارغة — **الخطوة التالية لا وصفُ الفراغ** (§6).
  final String emptyLabel;

  /// أيقونة الحالة الفارغة.
  final IconData emptyIcon;

  /// عنوان الحالة الفارغة.
  final String emptyTitle;

  /// باني القائمة.
  final Widget Function(List<T> items) builder;

  /// إعادة المحاولة عند الخطأ.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => AsyncStateView<T>(
        value: value,
        builder: builder,
        onRetry: onRetry,
        empty: EmptyStateSpec(
          icon: emptyIcon,
          title: emptyTitle,
          message: emptyLabel,
          // ★★ **وحاويةُ أيقونة الفراغ بعائلة المجموعة** — §4 و§3.5:
          //    ⟵ **فالشاشةُ الفارغة تبقى منتميةً لمجموعتها بصرياً**،
          //    ⛔ **ولا يُستعمَل اللون التصنيفي حكماً ولا خلفيةً كبيرة.**
          triad: context.categories.inventory,
        ),
        // ★ **الخطأ يُعرَض ولا يُطوى في «فارغ»** — ⟵ **فيُميِّز المستخدم بين
        //   «لا مخزون» و«ممنوعٌ من الرؤية».**
        errorMessage: (Object _) =>
            'تحقق من صلاحيتك ونطاق مصادرك، ثم أعد المحاولة.',
      );
}

/// ★★ منتقي المصدر — `FR-M8-04` (`A-01`): **رصيد كل نوع مستقل في كل مصدر**.
///
/// ⛔ **ولا خيار «كل المصادر» هنا إطلاقاً** — ★ **الجمع بين مصدرين ممنوع في
/// أي عملية**، ⟵ **وخيارٌ كهذا كان يُوحي بأنه ممكن.**
class SourcePicker extends ConsumerWidget {
  /// ينشئ المنتقي.
  const SourcePicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<SourceCard> sources = ref.watch(activeSourcesProvider);
    final String? selected = ref.watch(selectedSourceProvider);
    if (sources.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(Spacing.space16),
        child: Text(
          // ⚠️ **نطاقٌ فارغ حالةٌ حقيقية** — `E-35`: مستخدمٌ بلا مصدر.
          'لا يوجد مصدر ضمن نطاقك. راجع المدير.',
          style: TypeScale.bodyMd.copyWith(color: SemanticColors.textSecondary),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.space16,
        vertical: Spacing.space8,
      ),
      child: Wrap(
        spacing: Spacing.space8,
        runSpacing: Spacing.space8,
        children: <Widget>[
          for (final SourceCard source in sources)
            ChoiceChip(
              label: Text(source.name),
              selected: source.sourceId == selected,
              onSelected: (bool on) {
                if (on) {
                  ref
                      .read(selectedSourceProvider.notifier)
                      .select(source.sourceId);
                }
              },
            ),
        ],
      ),
    );
  }
}

/// شريط «تاريخ اليوم 🔒» — `FR-M8-05` · `FR-M6-02`.
///
/// ★★ **ويُعرَض دائماً ولا يُخفى:** التاريخ **مقفل من الخادم**، ⟵ **وإظهاره
/// يمنع أن يظنّ المستخدم أنه يعمل على يومٍ آخر** (`E-40`).
class LockedDayBanner extends StatelessWidget {
  /// ينشئ الشريط.
  const LockedDayBanner({required this.day, super.key});

  /// اليوم المعروض.
  final CalendarDay day;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(horizontal: Spacing.space16),
        padding: const EdgeInsets.all(Spacing.space12),
        decoration: BoxDecoration(
          color: SemanticColors.surfaceSunken,
          border: Border.all(color: SemanticColors.border),
          borderRadius: BorderRadius.circular(Radii.card),
        ),
        child: Row(
          children: <Widget>[
            // ★ **مقاسُ الأيقونة من §10 لا من سلّم المسافات** — ⟵ **فتوكنُ
            //   مسافةٍ في موضع مقاسٍ يمرّ الفحص ويكذب على القارئ.**
            const Icon(
              Icons.lock_outline,
              size: Sizes.iconMd,
              color: SemanticColors.textSecondary,
            ),
            const SizedBox(width: Spacing.space8),
            Expanded(
              child: Text(
                'تاريخ اليوم ${dayLabel(day)} — من الخادم ولا يُغيَّر.',
                style: TypeScale.bodyMd
                    .copyWith(color: SemanticColors.textSecondary),
              ),
            ),
          ],
        ),
      );
}

/// حبّة «ملغى» — ★ **فالملغى يُرى ولا يختفي** (`A-14`).
///
/// ⛔ **ولا رسمَ محلّياً** — ★ **تفويضٌ لـ[StatusPill]** (§5 البند 6).
class CancelledBadge extends StatelessWidget {
  /// ينشئ الحبّة.
  const CancelledBadge({super.key});

  @override
  Widget build(BuildContext context) => const StatusPill(
        label: 'ملغى',
        triad: SemanticTriads.danger,
        // ★ **أيقونةٌ مع النصّ** — §8 المحظور الثاني عشر: ⛔ لا لونَ وحده.
        //
        // ⛔⛔★★ **وليست `block_outlined`** — ★ **تلك أيقونةُ زرِّ الإلغاء**:
        //    ⟵ **فلو تشاركتا الرمز لصار الشكلُ الواحد يعني «هذا ملغى» و
        //    «ألغِ هذا» معاً**، ★ **وهو التباسٌ يقع على مستندٍ مالي.**
        //    ★ **ورصده اختبارٌ قائم فعلاً** (`inventory_screens_test.dart`).
        icon: Icons.cancel_outlined,
      );
}

/// ★ حبّة «مُعدَّل» — `FR-M8-06`.
class AmendedBadge extends StatelessWidget {
  /// ينشئ الحبّة.
  const AmendedBadge({super.key});

  @override
  Widget build(BuildContext context) => const StatusPill(
        label: 'مُعدَّل',
        triad: SemanticTriads.warning,
        icon: Icons.history_edu_outlined,
      );
}

/// بطاقة صفٍّ في قائمة مخزنية — ★ **تفويضٌ لـ[EntityTile]**.
///
/// ⛔⛔ **ولا نسخةَ ثانية من البطاقة** — §8 المحظور الحادي عشر: ⟵ **وكانت
/// هذه و`MasterDataTile` متطابقتين ثم افترقتا** (`DEBT-36` عولج في إحداهما
/// وحدها) — ★ **وهو بالضبط ما تتنبّأ به القاعدة.**
class InventoryTile extends StatelessWidget {
  /// ينشئ البطاقة.
  const InventoryTile({
    required this.title,
    required this.subtitle,
    this.leading,
    this.trailing,
    this.badges = const <Widget>[],
    this.actions = const <Widget>[],
    this.onTap,
    super.key,
  });

  /// ★★ المقدّمة — **أيقونة 🕘 للسجل السياقي** (`FR-M18-10`).
  ///
  /// ⛔ **و`null` تعني غيابها فعلاً بلا فراغٍ يزيح النصّ** — راجع
  /// `auditTrailLeading` في `audit_trail_view.dart`.
  final Widget? leading;

  /// العنوان.
  final String title;

  /// السطر الثاني.
  final String subtitle;

  /// النصّ الطرفي — ★ **الكمية بوحدتها**.
  final String? trailing;

  /// حبّات الحالة.
  final List<Widget> badges;

  /// أزرار الإجراءات.
  final List<Widget> actions;

  /// عند النقر.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => EntityTile(
        title: title,
        subtitle: subtitle,
        leading: leading,
        trailing: trailing,
        badges: badges,
        actions: actions,
        onTap: onTap,
      );
}

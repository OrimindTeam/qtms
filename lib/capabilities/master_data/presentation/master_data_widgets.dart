/// عناصر مشتركة لشاشات البيانات المرجعية — **نمطا 2 و4** (`ui-guidelines.md` §3).
///
/// ★ **ولماذا ملفٌ مشترك:** أربع شاشات قوائم وأربعة نماذج **تتبع النمط
/// نفسه حرفياً** (`design-system.md` §هـ: الحالات الأربع إلزامية)، ⟵
/// **ونسخُ العنصر أربع مرات يجعله يفترق عند أول تعديل** — وهو نفس ما
/// يمنعه `coding-standards.md` §2.2 في المعادلات.
///
/// ⚠️⚠️ **وكل ما هنا عرضٌ لا حماية** — ★ **والرفض الحقيقي في السحابة**
/// (`ADR-0013` القاعدة 3 · `RISK-02`).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qtms_domain/qtms_domain.dart';

import '../../../core/design/design_tokens.dart';
import '../../../core/design/theme_extensions.dart';
import '../../../core/messages/error_messages.dart';
import '../../../core/ui/async_state_view.dart';
import '../../../core/ui/entity_tile.dart';
import '../../../core/ui/status_pill.dart';

/// ★ عارض تدفّق شاشات البيانات المرجعية — ★ **يفوّض للمبدّل المشترك.**
///
/// ⛔⛔ **ولا نسخةَ ثانية منه** (§8 المحظور الحادي عشر) — ★ **وما يبقى هنا
/// ترجمةُ الخطأ إلى رسالة الكتالوج وحدها.**
class MasterDataAsyncView<T> extends StatelessWidget {
  /// ينشئ العارض.
  const MasterDataAsyncView({
    required this.value,
    required this.emptyLabel,
    required this.builder,
    this.emptyIcon = Icons.folder_open_outlined,
    this.emptyTitle = 'لا توجد سجلات بعد',
    this.onRetry,
    super.key,
  });

  /// التدفّق المعروض.
  final AsyncValue<List<T>> value;

  /// نصّ الحالة الفارغة — ★ **«لا يوجد بعد» لا «ممنوع»**.
  final String emptyLabel;

  /// أيقونة الحالة الفارغة.
  final IconData emptyIcon;

  /// عنوان الحالة الفارغة.
  final String emptyTitle;

  /// باني القائمة عند وجود بيانات.
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
          triad: context.categories.masterData,
        ),
        // ★★ **وأشيع سبب الخطأ نقصُ النطاق أو الصلاحية لا عطل** — ⛔ **ولا
        //    يُعرَض كقائمة فارغة أبداً:** «لا مصادر» تجعل المستخدم يبحث عن
        //    عطلٍ لا وجود له، ★ **بينما الحقيقة أنه ممنوعٌ من الرؤية.**
        errorMessage: (Object failure) => catalogText(
          failure.toString().contains('permission-denied')
              ? CatalogMessage.permissionMissing
              : CatalogMessage.operationFailed,
        ),
      );
}

/// بطاقة صفٍّ في قائمة — ★ **تفويضٌ لـ[EntityTile]**.
///
/// ⛔⛔ **ولا نسخةَ ثانية من البطاقة** — §8 المحظور الحادي عشر: ⟵ **وكانت
/// هذه و`InventoryTile` متطابقتين ثم افترقتا**، ★ **فعولج التفافُ الشارات
/// (`DEBT-36`) في إحداهما وبقي العطلُ في الأخرى.**
class MasterDataTile extends StatelessWidget {
  /// ينشئ البطاقة.
  const MasterDataTile({
    required this.title,
    required this.subtitle,
    this.leading,
    this.badges = const <Widget>[],
    this.actions = const <Widget>[],
    this.actionsPlacement = EntityActionsPlacement.stacked,
    super.key,
  });

  /// العنوان.
  final String title;

  /// السطر الثاني.
  final String subtitle;

  /// ★★ المقدّمة — **أيقونة 🕘 للسجل السياقي** (`FR-M18-10`).
  ///
  /// ⛔ **و`null` تعني غيابها فعلاً بلا فراغٍ يزيح النصّ** — راجع
  /// `auditTrailLeading` في `audit_trail_view.dart`.
  final Widget? leading;

  /// حبّات الحالة.
  final List<Widget> badges;

  /// أزرار الإجراءات.
  final List<Widget> actions;

  /// ★ موضع الإجراءات — `AM-008` ⑥. راجع [EntityActionsPlacement].
  final EntityActionsPlacement actionsPlacement;

  @override
  Widget build(BuildContext context) => EntityTile(
        title: title,
        subtitle: subtitle,
        leading: leading,
        badges: badges,
        actions: actions,
        actionsPlacement: actionsPlacement,
      );
}

/// حبّة «معطَّل» — ★ **فالمعطَّل يُرى في القائمة ولا يختفي**.
///
/// ⛔ **والإخفاء يجعله كالمحذوف في عين المستخدم** فيظنّه ذهب وهو باقٍ
/// بحركاته وقيوده (`FR-M2-05` · `FR-M3-06` · `FR-M4-07` · `FR-M5-12`).
class DisabledBadge extends StatelessWidget {
  /// ينشئ الحبّة.
  const DisabledBadge({super.key});

  @override
  Widget build(BuildContext context) => const StatusPill(
        label: 'معطَّل',
        triad: SemanticTriads.danger,
        icon: Icons.do_not_disturb_on_outlined,
      );
}

/// ★★ حبّة «افتراضي» — النوع الذي **لا يُعدَّل ولا يُحذف** (`FR-M5-05`).
///
/// ★ **والقفلُ أيقونةٌ متجهية لا رمزاً نصياً** — ⟵ **فيرث لونَ الثلاثية
/// ومقاسَ التوكنز**، ⛔ **بينما الرمزُ النصّي يتبع خطَّ الجهاز ولا يُلوَّن.**
class SystemDefaultBadge extends StatelessWidget {
  /// ينشئ الحبّة.
  const SystemDefaultBadge({super.key});

  @override
  Widget build(BuildContext context) => const StatusPill(
        label: 'افتراضي',
        triad: SemanticTriads.warning,
        icon: Icons.lock_outline,
      );
}

/// شريط الرفض — ★ **نصّه من الكتالوج حرفياً** ⛔ **ولا صياغة هنا.**
class RejectionBanner extends StatelessWidget {
  /// ينشئ الشريط.
  const RejectionBanner({required this.message, super.key});

  /// الرسالة المعروضة.
  final CatalogMessage message;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(Spacing.space12),
        decoration: BoxDecoration(
          color: SemanticTriads.danger.soft,
          border: Border.all(
            color: SemanticTriads.danger.border,
            width: Sizes.borderWidth,
          ),
          borderRadius: BorderRadius.circular(Radii.card),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // ★★ **أيقونة `danger`** — §هـ يفرضها في حالة الخطأ، ★ **و§8
            //    المحظور الثاني عشر يمنع نقلَ المعنى باللون وحده.**
            Icon(
              Icons.error_outline,
              size: Sizes.iconMd,
              color: SemanticTriads.danger.ink,
            ),
            const SizedBox(width: Spacing.space8),
            Expanded(
              child: Text(
                catalogText(message),
                style: TypeScale.bodyMd
                    .copyWith(color: SemanticTriads.danger.ink),
              ),
            ),
          ],
        ),
      );
}

/// حقل نصّي — **تركيز تلقائي على الأول** (نمط 4).
class MasterDataField extends StatelessWidget {
  /// ينشئ الحقل.
  const MasterDataField({
    required this.controller,
    required this.label,
    this.autofocus = false,
    this.keyboardType,
    super.key,
  });

  /// المتحكّم.
  final TextEditingController controller;

  /// التسمية.
  final String label;

  /// تركيز تلقائي.
  final bool autofocus;

  /// نوع لوحة المفاتيح.
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        autofocus: autofocus,
        keyboardType: keyboardType,
        decoration: InputDecoration(labelText: label),
      );
}

/// ★ منتقي المصادر (اختيار متعدد) — `FR-M3-01` · `FR-M5-01`.
///
/// ⛔ **ولا يعرض إلا المصادر النشطة** (`FR-M2-06`)، ★ **مع إبقاء المختار
/// سابقاً ولو عُطِّل مصدرُه** — ⟵ **فإزالةُ مصدرٍ من القائمة لا تُزيله من
/// السجل بصمت** (`FR-M3-08` · `FR-M5-14`: «لا تؤثر على الحركات السابقة»).
class SourcesSelector extends StatelessWidget {
  /// ينشئ المنتقي.
  const SourcesSelector({
    required this.available,
    required this.selected,
    required this.onChanged,
    super.key,
  });

  /// المصادر المتاحة للاختيار.
  final List<SourceCard> available;

  /// المختارة الآن.
  final Set<String> selected;

  /// يُستدعى عند كل تبديل.
  final void Function(Set<String> next) onChanged;

  @override
  Widget build(BuildContext context) {
    final Set<String> known = <String>{
      for (final SourceCard source in available) source.sourceId,
    };
    // ★ **المختارُ الذي لم يعد في المتاح يظهر بمعرّفه** — ⛔ ولا يختفي بصمت.
    final List<String> orphans = <String>[
      for (final String id in selected)
        if (!known.contains(id)) id,
    ]..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'المصادر',
          style: TypeScale.label.copyWith(color: SemanticColors.textSecondary),
        ),
        const SizedBox(height: Spacing.space8),
        Wrap(
          spacing: Spacing.space8,
          runSpacing: Spacing.space8,
          children: <Widget>[
            for (final SourceCard source in available)
              FilterChip(
                label: Text(source.name),
                selected: selected.contains(source.sourceId),
                onSelected: (bool on) => onChanged(<String>{
                  ...selected,
                  if (on) source.sourceId,
                }..removeWhere((String id) => !on && id == source.sourceId)),
              ),
            for (final String id in orphans)
              FilterChip(
                label: Text(id),
                selected: true,
                onSelected: (bool on) => onChanged(<String>{
                  ...selected,
                }..removeWhere((String other) => !on && other == id)),
              ),
          ],
        ),
      ],
    );
  }
}

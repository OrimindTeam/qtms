/// ★★★ **تفصيلُ الضمار حسب المصدر** — `ui-guidelines.md` §3 نمط 1 البند ④ ·
/// `design-system.md` §7 «بطاقة المصدر المصغّرة» (`AM-017` ②).
///
/// ★ **صفٌّ أفقيٌّ من بطاقاتٍ مصغَّرة، كلُّ بطاقةٍ مصدرٌ واحد** — ⟵ **فتُقارَن
/// المصادرُ بلمحةٍ واحدة** ⛔ **بدل تبديل المرشِّح وانتظار إعادة التحميل في كل
/// مرة.**
///
/// ⛔⛔★★★ **ولا يظهر إلا حين يكون النطاقُ «كل المصادر»** — ⟵ **ومصدرٌ واحدٌ
/// مختارٌ يجعل بطاقتَه نسخةً حرفيةً من البطاقة الرئيسية فوقه**: ★ **فتكرارٌ
/// بلا معلومة.**
///
/// ⚠️⚠️ **وكلُّ رقمٍ هنا يمرّ بالمنسّق المركزي** (`design-system.md` §6.ح) —
/// ⛔ **ولا يُبنى نصُّ مبلغٍ من `Money.riyals`**، ★ **والبنودُ محسوبةٌ في
/// طبقة النطاق** (`ADR-0008`) ⛔ **ولا تجمع البطاقةُ ولا تطرح.**
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qtms_domain/qtms_domain.dart';

import '../../../core/design/design_tokens.dart';
import '../../../core/ui/key_value_row.dart';
import '../../master_data/application/master_data_providers.dart';
import '../application/owner_ledger_providers.dart';
import 'owner_ledger_format.dart';

/// صفُّ بطاقات المصادر المصغّرة.
class SourceLedgerStrip extends ConsumerWidget {
  /// ينشئ الصفّ.
  const SourceLedgerStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ⛔ **مصدرٌ مختارٌ ⟵ لا صفّ** — ★ **الشرطُ الأول في العقد.**
    if (ref.watch(ownerLedgerSourceProvider) != null) {
      return const SizedBox.shrink();
    }
    final List<SourceCard> sources = ref.watch(activeSourcesProvider);
    // ★ **ومصدرٌ واحدٌ في النطاق ⟵ لا مقارنة** ⛔ **فلا صفّ.**
    if (sources.length < 2) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Padding(
          padding: const EdgeInsetsDirectional.only(bottom: Spacing.space8),
          child: Text(
            'تفصيل حسب المصدر',
            style:
                TypeScale.label.copyWith(color: SemanticColors.textSecondary),
          ),
        ),
        SizedBox(
          height: Sizes.listRowHeight * 2,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: sources.length,
            separatorBuilder: (BuildContext context, int index) =>
                const SizedBox(width: Spacing.space12),
            itemBuilder: (BuildContext context, int index) =>
                _SourceLedgerCard(source: sources[index]),
          ),
        ),
      ],
    );
  }
}

class _SourceLedgerCard extends ConsumerWidget {
  const _SourceLedgerCard({required this.source});

  final SourceCard source;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<OwnerLedgerProjection?> card =
        ref.watch(ownerLedgerCardForSourceProvider(source.sourceId));

    return SizedBox(
      width: Sizes.sourceCardWidth,
      child: Container(
        padding: const EdgeInsets.all(Spacing.space12),
        decoration: BoxDecoration(
          color: SemanticColors.surface,
          border: Border.all(
            color: SemanticColors.border,
            width: Sizes.borderWidth,
          ),
          borderRadius: BorderRadius.circular(Radii.card),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              source.name,
              style: TypeScale.titleSm,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: Spacing.space4),
            Expanded(child: _Body(card: card)),
          ],
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.card});

  final AsyncValue<OwnerLedgerProjection?> card;

  @override
  Widget build(BuildContext context) => switch (card) {
        // ⛔ **والخطأُ يُقال ولا يُخفى** — §هـ: ★ **بطاقةٌ صامتةٌ تُقرأ صفراً.**
        AsyncError<OwnerLedgerProjection?>() => Text(
            'تعذّر عرض ملخص هذا المصدر',
            style: TypeScale.caption.copyWith(color: SemanticTriads.danger.ink),
          ),
        AsyncLoading<OwnerLedgerProjection?>() => const _Skeleton(),
        AsyncValue<OwnerLedgerProjection?>(
          :final OwnerLedgerProjection? value
        ) =>
          _Numbers(projection: value),
      };
}

class _Numbers extends StatelessWidget {
  const _Numbers({required this.projection});

  final OwnerLedgerProjection? projection;

  @override
  Widget build(BuildContext context) {
    // ★★ **ويومٌ بلا حركةٍ يُعرَض بأصفارٍ صريحة** (`ui-guidelines.md` نمط 1)
    //    — ⛔ **لا شرطاتٍ ولا إخفاء**: ⟵ **الصفرُ هنا معلومة.**
    if (projection == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            'لا حركة اليوم',
            style:
                TypeScale.caption.copyWith(color: SemanticColors.textTertiary),
          ),
        ],
      );
    }
    final OwnerLedgerProjection p = projection!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        QtmsKeyValueRow(
          label: 'إجمالي الضمار',
          value: formatRiyals(p.summary.totalDebt),
          numeric: true,
        ),
        const Divider(
          height: Sizes.borderWidth,
          thickness: Sizes.borderWidth,
          color: SemanticColors.divider,
        ),
        QtmsKeyValueRow(
          label: 'الصافي النهائي',
          value: '${formatRiyals(p.netFinal)} $riyalLabel',
          numeric: true,
        ),
      ],
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: SemanticColors.skeleton,
          borderRadius: BorderRadius.circular(Radii.field),
        ),
        child: const SizedBox.expand(),
      );
}

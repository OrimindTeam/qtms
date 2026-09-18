/// ★★★ **قسمُ الصدَفة ومدخلُه** — `MASTER.md` §5b نمط `P1` (`ADR-0021`).
///
/// ⛔⛔★★★ **والمشكلة التي يحلّها مقيسةٌ في جرد 2026-08-27:** ★ **ثلاثةَ عشرَ
/// مدخلاً في `HomeShell` بوزنٍ بصريٍّ واحد** (`OutlinedButton` لكلّها)
/// **مفصولةٍ بـ`SizedBox` أشقّاءَ بلا عناوين أقسام** — ⟵ **فلا هرمَ ولا
/// حدودَ مجموعات**: ★ **«سجل التدقيق» بنفس بروز «التوزيع».**
///
/// ⛔⛔★★★ **وعطلُ الفجوات المكدَّسة:** ★ **`PermissionGate` تُرجِع
/// `SizedBox.shrink`** ⟵ **والفاصلُ الشقيقُ لمدخلٍ مخفيّ يبقى ظاهراً**:
/// ⛔ **فمن لا يملك مفاتيح مجموعةٍ كاملة كان يرى فجواتٍ متتالية بلا سبب.**
/// ★ **والعلاج بنيوي: الفواصل داخل المكوّن لا أشقّاءَ له**، ⟵ **والقسمُ كلُّه
/// يختفي حين تختفي كلُّ مداخله.**
///
/// ⛔⛔★★★ **وبـ`AM-017` صار القسمُ شبكةً لا عموداً** — `design-system.md`
/// §6.و «بلاطة مدخل الصدَفة» و§7 «شبكة عمليات اليوم»: ★★★ **وثلاثةُ أعمدةٍ
/// في كل العروض منذ `AM-027`** (⛔ **بعد أن كانت عمودين دون `expanded`**)،
/// ★ **والمدخلُ الأساسي يمتدّ بعرض عمودين.**
/// ⟵ **والسببُ مقيس:** ★ **إحدى وعشرون وجهةً في عمودٍ واحدٍ من أزرارٍ
/// بعرضٍ كامل تفرض تمريراً يعادل أضعافَ ارتفاع الشاشة** ⛔ **بلا سياقٍ نصّيٍّ
/// يبرّر العمود**: ⟵ **والوجهةُ التصنيفيةُ بلاطةٌ لا سطر.**
///
/// ⛔⛔★★★ **والبوابةُ تسبق القائمة ولا تلفّ عناصرها** (`AM-017`): ★ **الشاشةُ
/// تبني [QtmsHubEntry] للمداخل المسموح بها وحدها** — ⟵ **فالمكوّنُ يعرف
/// عددَ بلاطاته الحقيقي قبل التخطيط**، ⛔ **ولا يحسب خانةً لمدخلٍ مخفيّ.**
///
/// ⚠️⚠️ **وكل ما هنا عرضٌ لا حماية** — ★ **والقراءةُ والكتابةُ محكومتان في
/// القواعد والدالة** (`RISK-02`). ⛔ **فلا يُكتفى بإخفاء مدخل.**
library;

import 'package:flutter/material.dart';

import '../design/design_tokens.dart';

/// ★★ مدخلٌ واحد في الصدَفة.
///
/// ★ **و[isPrimary] لمدخلٍ واحد في الشاشة كلها** — §7: ⛔ **زر إجراء رئيسي
/// واحد لكل شاشة**، ⟵ **وهو أكثرُ المداخل تكراراً في اليوم.**
@immutable
class QtmsHubEntry {
  /// ينشئ المدخل.
  const QtmsHubEntry({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.isPrimary = false,
    this.isFrequent = false,
  });

  /// النصّ — ⛔ **إلزاميٌّ**: §8 المحظور الثاني عشر (لا معنى بأيقونةٍ وحدها).
  final String label;

  /// الأيقونة.
  final IconData icon;

  /// عند النقر.
  final VoidCallback onPressed;

  /// ★ هل هو المدخل الأساسي؟ — ⛔ **واحدٌ لا أكثر** · ★ **ويمتدّ بعرض عمودين.**
  final bool isPrimary;

  /// ★★ **توكيدٌ ثانويٌّ للأكثر استخداماً يومياً** — `AM-017` (المكسب السريع).
  ///
  /// ★ **أيقونةٌ وحدٌّ من عائلة الهوية ووزنُ تسميةٍ أثقل** — ⛔⛔ **لا لونَ
  /// خلفيةٍ ممتلئ**: ★ **الممتلئُ محجوزٌ لـ[isPrimary] وحده.**
  /// ⛔ **وثلاثةٌ على الأكثر في القسم الواحد** — ⟵ **فالتوكيدُ على النصف
  /// ليس توكيداً.**
  final bool isFrequent;
}

/// ★★★ قسمٌ في الصدَفة — **عنوانٌ ثم شبكةُ مداخله**.
///
/// ⛔⛔★★★ **ويختفي كلُّه حين تختفي كلُّ مداخله** — ★ **فلا عنوانُ قسمٍ فارغ**
/// ⛔ **ولا فجوةٌ مكدَّسة** لمن لا يملك مفاتيحه.
class QtmsHubSection extends StatelessWidget {
  /// ينشئ القسم.
  const QtmsHubSection({
    required this.title,
    required this.entries,
    super.key,
  });

  /// ★ عنوان القسم — ⟵ **فحدودُ المجموعة مقروءة** ⛔ **لا مستنتَجة من فراغ.**
  final String title;

  /// ★★ مداخلُ القسم **بعد البوابات** — ⟵ **فالقائمة هنا هي المرئيّ فعلاً.**
  ///
  /// ⛔ **وفارغةٌ تعني اختفاءَ القسم كلِّه.**
  final List<QtmsHubEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();
    return Padding(
      // ★ **والفاصلُ داخل المكوّن** — ⛔ **لا `SizedBox` شقيقاً له.**
      padding: const EdgeInsetsDirectional.only(bottom: Spacing.space24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: Spacing.space8),
            child: Text(
              title,
              style:
                  TypeScale.label.copyWith(color: SemanticColors.textSecondary),
            ),
          ),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final int columns = Breakpoints.hubColumns(constraints.maxWidth);
              final List<List<QtmsHubEntry>> rows =
                  packHubRows(entries, columns);
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  for (int r = 0; r < rows.length; r++) ...<Widget>[
                    // ★★ **وفاصلٌ واحدٌ أفقياً ورأسياً** — `AM-027`: ⟵ **فالشبكةُ
                    //    تُقرأ شبكةً** ⛔ **لا صفوفاً متباعدةً بأعمدةٍ ملتصقة.**
                    if (r > 0) const SizedBox(height: Spacing.space8),
                    _HubRow(entries: rows[r], columns: columns),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// ★★ **عرضُ المدخل بالخانات** — ⛔ **ولا يتجاوز عددَ الأعمدة**: ⟵ **فمدخلٌ
/// أساسيٌّ في شبكةٍ بعمودٍ واحد يبقى بعمودٍ واحد** ⛔ **ولا يفيض.**
int hubEntrySpan(QtmsHubEntry entry, int columns) =>
    entry.isPrimary && columns > 1 ? 2 : 1;

/// ★★★ **توزيعُ المداخل على صفوفٍ بسعةٍ ثابتة** — ★ **دالّةٌ نقيّةٌ تُختبَر
/// وحدَها**: ⟵ **فالتخطيطُ مقيسٌ لا مُشاهَد.**
List<List<QtmsHubEntry>> packHubRows(List<QtmsHubEntry> entries, int columns) {
  final List<List<QtmsHubEntry>> rows = <List<QtmsHubEntry>>[];
  List<QtmsHubEntry> current = <QtmsHubEntry>[];
  int used = 0;
  for (final QtmsHubEntry entry in entries) {
    final int span = hubEntrySpan(entry, columns);
    if (used + span > columns && current.isNotEmpty) {
      rows.add(current);
      current = <QtmsHubEntry>[];
      used = 0;
    }
    current.add(entry);
    used += span;
  }
  if (current.isNotEmpty) rows.add(current);
  return rows;
}

class _HubRow extends StatelessWidget {
  const _HubRow({required this.entries, required this.columns});

  final List<QtmsHubEntry> entries;
  final int columns;

  @override
  Widget build(BuildContext context) {
    int used = 0;
    final List<Widget> cells = <Widget>[];
    for (final QtmsHubEntry entry in entries) {
      if (cells.isNotEmpty) {
        // ★★ **فاصلٌ `space8` لا `space12` منذ `AM-027`** — ⟵ **فالعمودُ
        //    الثالثُ يكسب من الفاصل ما يحتاجه للتسمية.**
        cells.add(const SizedBox(width: Spacing.space8));
      }
      final int span = hubEntrySpan(entry, columns);
      used += span;
      cells.add(Expanded(flex: span, child: QtmsHubTile(entry: entry)));
    }
    // ★★ **والصفُّ الناقص يُملأ بخانةٍ فارغة** — ⟵ **فعرضُ البلاطة الأخيرة
    //    يساوي عرضَ نظيراتها في الصفوف الكاملة** ⛔ **ولا تتمدّد وحدها.**
    if (used < columns) {
      cells
        ..add(const SizedBox(width: Spacing.space8))
        ..add(Expanded(flex: columns - used, child: const SizedBox.shrink()));
    }
    return SizedBox(
      height: Sizes.hubTileHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: cells,
      ),
    );
  }
}

/// ★ بلاطةُ مدخلٍ مرسومة — **أساسيةٌ أو مؤكَّدةٌ أو عادية**.
///
/// ★★ **والفرق هرمٌ لا زينة** — §7: ⟵ **فأكثرُ المداخل تكراراً يُرى أولاً.**
class QtmsHubTile extends StatelessWidget {
  /// ينشئ البلاطة.
  const QtmsHubTile({required this.entry, super.key});

  /// وصفُ المدخل.
  final QtmsHubEntry entry;

  @override
  Widget build(BuildContext context) {
    final bool primary = entry.isPrimary;
    final Color background =
        primary ? SemanticColors.surfaceInverse : SemanticColors.surface;
    final Color foreground =
        primary ? SemanticColors.textOnInverse : SemanticColors.textPrimary;
    final Color iconColor = switch ((primary, entry.isFrequent)) {
      (true, _) => SemanticColors.textOnInverse,
      (false, true) => SemanticTriads.primary.ink,
      (false, false) => SemanticColors.textSecondary,
    };
    final Color borderColor = entry.isFrequent
        ? SemanticTriads.primary.border
        : SemanticColors.border;
    // ★★ **والتوكيدُ وزنٌ لا حجم** — ⟵ **فمقاسُ البلاطة واحدٌ في الشبكة
    //    كلِّها**: ⛔ **ودرجةٌ أكبر تكسر ارتفاع [Sizes.hubTileHeight] على
    //    سطرين.** ★ **و700 يقع على ملفّ 600 المضمَّن** (نظيرُ `titleLg`).
    final TextStyle labelStyle = primary || entry.isFrequent
        ? TypeScale.label
            .copyWith(color: foreground, fontWeight: FontWeight.w700)
        : TypeScale.label.copyWith(color: foreground);

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(Radii.card),
      child: InkWell(
        onTap: entry.onPressed,
        borderRadius: BorderRadius.circular(Radii.card),
        child: Semantics(
          button: true,
          label: entry.label,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: primary
                  ? null
                  : Border.all(color: borderColor, width: Sizes.borderWidth),
              borderRadius: BorderRadius.circular(Radii.card),
            ),
            child: Padding(
              padding: const EdgeInsets.all(Spacing.space12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(entry.icon, size: Sizes.iconXl, color: iconColor),
                  const SizedBox(height: Spacing.space8),
                  Text(
                    entry.label,
                    style: labelStyle,
                    textAlign: TextAlign.center,
                    // ★★★ **ثلاثةُ أسطرٍ منذ `AM-027`** — ⛔ **لا سطران**:
                    //    ⟵ **فالعمودُ الثالثُ يُضيّق البلاطةَ إلى ≈104 على 360**
                    //    ⟹ ⛔ **و«كشف حساب المقوت» تُقصّ في سطرين.**
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// ★★★ **رأس السياق الثابت** — `MASTER.md` §5b نمط `P3` (`ADR-0021`).
///
/// ⛔⛔★★★ **ومكوّنٌ واحد لخمس شاشات:** ★ **كان `SourcePicker` و
/// `LockedDayBanner` عنصرين منفصلين تُركِّبهما كلُّ شاشةٍ بنفسها** — ⟵ **خمسُ
/// نسخٍ من التركيب نفسِه**، ⛔ **وهو ما يمنعه §8 المحظور الحادي عشر.**
///
/// ★★ **ويحلّ عطلين مرصودين في جرد 2026-08-27:**
///
/// ① ⛔⛔ **الرأس الثقيل:** ★ **كان منتقي المصدر شرائح `Wrap` تلتفّ بلا حدّ**
///    ⟵ **فبعشرة مصادر يُبتلَع نصفُ الشاشة قبل أول بيان**، ★ **ومعه لافتةُ
///    يومٍ مستقلة وصفُّ مرشِّحاتٍ مفتوح**: ⟵ **ثلاثةُ صفوفٍ في التسعير
///    وأربعةٌ في التوزيع.** ★ **والعلاج بنيوي: صفٌّ واحد بقائمةٍ منسدلة**
///    ⛔ **لا شرائح**، **واليومُ نصٌّ داخل الصفّ نفسه** ⛔ **لا لافتةٌ ثانية.**
///
/// ② ⛔⛔★★★ **الفراغ الصامت:** ★ **أربعُ شاشاتٍ كانت تعرض `SizedBox.shrink`
///    حين لا مصدرَ مختار** — ⟵ **شاشةٌ بيضاء تُقرأ عطلاً لا انتظاراً**
///    (`design-system.md` §هـ: الحالات الأربع إلزامية). ★ **والعلاج
///    [chooseSourceEmpty] و[noSourceInScopeEmpty]** ⟵ **فلكل حالةٍ نصُّها
///    وإجراؤها**، ⛔ **ولا شاشةَ صامتة بعد اليوم.**
///
/// ⚠️⚠️ **وهذا عرضٌ محض لا حماية** — ★ **والنطاق يُفرَض في `firestore.rules`
/// وفي الدالة الكاتبة** (`ADR-0013` القاعدة 3 · `RISK-02`): ⟵ **فقائمةٌ
/// تعرض مصدراً لا تسمح به القاعدة تُرفَض قراءتُها هناك** ⛔ **لا هنا.**
///
/// ⛔ **ولا يقرأ هذا المكوّن مزوّداً واحداً** — ★ **تُمرَّر إليه الحالة**:
/// ⟵ **فطبقةُ `core` لا تعتمد على قدرةٍ بعينها** (`ADR-0009`).
library;

import 'package:flutter/material.dart';
import 'package:qtms_domain/qtms_domain.dart';

import '../design/design_tokens.dart';
import 'async_state_view.dart';
import 'date_labels.dart';

/// ★★ **السقف البنيوي لارتفاع الرأس الثابت** — §5b نمط `P3`: **96dp**.
///
/// ⚠️⚠️★★ **وهو سقفٌ بنيوي لا قصٌّ قسري — والفرق مقصود:** ★ **الرأس مبنيٌّ
/// صفّاً واحداً وزرَّ طيٍّ واحداً**، ⟵ **فلا يبلغه أصلاً عند مقياس النصّ
/// الطبيعي.** ⛔ **ولا يُحاصَر بـ`maxHeight` يقصّه:** ★ **§8 يفرض احترام
/// `textScaler` عند 200٪ بلا فيضان** — ⟵ **وقصُّه كان يُخفي اسمَ المصدر
/// نفسِه عمّن كبّر الخط**، ⛔ **وهو أسوأ من رأسٍ يزيد بضعة بكسلات.**
const double kContextHeaderMaxHeight = Sizes.minTouch * 2;

/// ★★★ رأس السياق — **المصدر واليوم المقفل في صفٍّ واحد**.
class QtmsContextHeader extends StatefulWidget {
  /// ينشئ الرأس.
  const QtmsContextHeader({
    required this.sources,
    required this.selectedSourceId,
    required this.onSourceSelected,
    required this.day,
    this.filters,
    this.activeFilterCount = 0,
    super.key,
  });

  /// ★ المصادر المتاحة — **مصادرُ نطاق المستخدم وحدها** (`FR-M1-07` · `E-35`).
  final List<SourceCard> sources;

  /// المصدر المختار — و`null` تعني **لم يُختَر بعد**.
  final String? selectedSourceId;

  /// يُستدعى عند اختيار مصدر.
  final ValueChanged<String> onSourceSelected;

  /// ★ اليوم المقفل — **من الخادم** (`FR-M8-05` · `FR-M6-02`).
  final CalendarDay day;

  /// ★ صفّ المرشِّحات — **مطويٌّ افتراضياً** ⛔ **ولا يُفتَح من تلقائه.**
  ///
  /// ⟵ ★ **و`null` تعني أن الشاشة بلا مرشِّحات** — ⛔ **فلا يظهر زرُّ الطيّ.**
  final Widget? filters;

  /// عدد المرشِّحات النشطة — ★ **يظهر في زرّ الطيّ** ⟵ **فلا يخفى أثرُها.**
  final int activeFilterCount;

  @override
  State<QtmsContextHeader> createState() => _QtmsContextHeaderState();
}

class _QtmsContextHeaderState extends State<QtmsContextHeader> {
  /// ⛔★★ **مطويٌّ ابتداءً دائماً** — §5b: ⟵ **فالرأس يبدأ بأخفّ صورةٍ له.**
  bool _filtersOpen = false;

  /// ★★ هل كبّر المستخدم النصّ بما يُضيّق الصفّ الواحد؟
  ///
  /// ★ **والعتبة 1.3×** — وهي عتبةُ `definition-of-done.md` §1 ⑤ نفسُها:
  /// ⟵ **فما يمرّ عندها يبقى صفّاً واحداً**، ★ **وما فوقها ينقسم صفّين.**
  ///
  /// ⛔⛔★★★ **والقياس على مقاس النصّ الفعلي لا على رقمٍ مرجعي كبير — عطلٌ
  /// رصده المحاكي (2026-08-27) بعد أن ظنّ الإصلاحُ الأولُ نفسَه ناجحاً:**
  /// ★ **أندرويد 14+ يُكبّر الخطوط تكبيراً غير خطّي** (`non-linear font
  /// scaling`) ⟵ **فالمقاسات الكبيرة تكاد لا تُكبَّر**: ★ **قياسٌ على 100
  /// أعاد نسبةً ≈ 1.0 عند `font_scale = 2.0`** ⛔ **فلم ينقسم الصفُّ أبداً**،
  /// **بينما 13.5 تُعيد النسبة الحقيقية.** ⟵ ⛔ **ولا يُفترَض أن التكبير
  /// خطّي** — ★ **يُقاس على المقاس الذي سيُعرَض به النصّ فعلاً.**
  static bool _isScaledUp(BuildContext context) {
    // ★ **مقاسُ النصّ الثانوي من التوكنز** — ⛔ **ولا رقمَ محفور هنا.**
    final double base = TypeScale.bodyMd.fontSize ?? Sizes.iconSm;
    return MediaQuery.textScalerOf(context).scale(base) / base > 1.3;
  }

  Widget _sourceField() => _SourceField(
        sources: widget.sources,
        selectedSourceId: widget.selectedSourceId,
        onSourceSelected: widget.onSourceSelected,
      );

  List<Widget> _filterToggle() => <Widget>[
        if (widget.filters != null) ...<Widget>[
          const SizedBox(width: Spacing.space8),
          _FilterToggle(
            open: _filtersOpen,
            activeCount: widget.activeFilterCount,
            onPressed: () => setState(() => _filtersOpen = !_filtersOpen),
          ),
        ],
      ];

  @override
  Widget build(BuildContext context) {
    // ⚠️ **نطاقٌ فارغ حالةٌ حقيقية لا عطل** — `E-35`: مستخدمٌ بلا مصدر.
    //    ★ **وتُعرَض هنا لأن لا قائمةَ تُبنى أصلاً** ⛔ **ولا رأسَ بلا محتوى.**
    if (widget.sources.isEmpty) return const _NoScopeNotice();

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: SemanticColors.surface,
        border: Border(
          bottom: BorderSide(
            color: SemanticColors.border,
            width: Sizes.borderWidth,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: Spacing.screenPadding,
              vertical: Spacing.space8,
            ),
            // ⛔⛔★★★ **والصفُّ الواحد يصير صفّين عند تكبير النصّ — عطلٌ رُصد
            //    على المحاكي (2026-08-27) ⛔ لم يكشفه اختبارُ الويدجت:**
            //    ★ **عند `textScaler` 2.0 كان اسمُ المصدر يُقتطَع إلى
            //    «مصدر الا…»** ⟵ **فلا يعرف المستخدم على أي مصدرٍ يعمل**،
            //    ⛔ **وهو أسوأ من رأسٍ يزيد سطراً** على شاشةٍ كلُّ رقمٍ فيها
            //    يخصّ مصدراً بعينه (`A-01`). ★ **والسقف 96dp قيدُ الحالة
            //    الطبيعية** ⛔ **لا قيدٌ يُقدَّم على قابلية القراءة** (§8).
            child: _isScaledUp(context)
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      _sourceField(),
                      const SizedBox(height: Spacing.space8),
                      Row(children: <Widget>[
                        _LockedDay(day: widget.day),
                        const Spacer(),
                        ..._filterToggle(),
                      ]),
                    ],
                  )
                : Row(
                    children: <Widget>[
                      // ① ★★ **المصدر قائمةٌ منسدلة** — ⛔ **لا شرائح تلتفّ**:
                      //    ⟵ **فارتفاعُ الصفّ ثابتٌ مهما بلغ عدد المصادر.**
                      Expanded(child: _sourceField()),
                      const SizedBox(width: Spacing.space12),
                      // ② ★★ **اليوم المقفل داخل الصفّ نفسه** — ⛔ **لا لافتةٌ ثانية.**
                      _LockedDay(day: widget.day),
                      // ③ ★ **زرّ المرشِّحات — مطويٌّ** ⛔ **ولا صفٌّ مفتوح.**
                      ..._filterToggle(),
                    ],
                  ),
          ),
          if (widget.filters case final Widget filters when _filtersOpen)
            Padding(
              padding: const EdgeInsetsDirectional.only(
                start: Spacing.screenPadding,
                end: Spacing.screenPadding,
                bottom: Spacing.space8,
              ),
              child: filters,
            ),
        ],
      ),
    );
  }
}

/// ★ منتقي المصدر — **قائمةٌ منسدلة بارتفاعٍ ثابت**.
///
/// ⛔★★ **ولا خيار «كل المصادر» إطلاقاً** — `A-01`: **لا جمع بين مصدرين في
/// أي عملية**، ⟵ **وخيارٌ كهذا كان يُوحي بأنه ممكن.**
class _SourceField extends StatelessWidget {
  const _SourceField({
    required this.sources,
    required this.selectedSourceId,
    required this.onSourceSelected,
  });

  final List<SourceCard> sources;
  final String? selectedSourceId;
  final ValueChanged<String> onSourceSelected;

  @override
  Widget build(BuildContext context) {
    // ⛔ **ومعرّفٌ لا يقابله مصدرٌ في القائمة يُعامَل «لم يُختَر»** — ⟵ **فلا
    //   ترمي القائمة المنسدلة على قيمةٍ لا خيارَ لها** (`DropdownButton`
    //   يشترط تفرّد القيمة ووجودَها)، ★ **والحالة واقعية:** **مصدرٌ عُطِّل
    //   بينما الشاشة مفتوحة.**
    final bool known = sources
        .any((SourceCard source) => source.sourceId == selectedSourceId);

    return DropdownButtonFormField<String>(
      initialValue: known ? selectedSourceId : null,
      isDense: true,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'المصدر',
        isDense: true,
      ),
      // ★ **وصفٌ دلالي لقارئ الشاشة** — `design-system.md` §5 البند 3.
      hint: const Text('اختر المصدر'),
      items: <DropdownMenuItem<String>>[
        for (final SourceCard source in sources)
          DropdownMenuItem<String>(
            value: source.sourceId,
            child: Text(source.name, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (String? value) {
        if (value != null) onSourceSelected(value);
      },
    );
  }
}

/// ★★ اليوم المقفل — **نصٌّ وأيقونة قفل داخل صفّ السياق**.
///
/// ★★ **ويُعرَض دائماً ولا يُخفى:** التاريخ **مقفل من الخادم**، ⟵ **وإظهاره
/// يمنع أن يظنّ المستخدم أنه يعمل على يومٍ آخر** (`E-40`).
///
/// ⛔ **ولا معنى باللون وحده** (§8) — ★ **فالأيقونة والنصّ والوصفُ الدلالي معاً.**
class _LockedDay extends StatelessWidget {
  const _LockedDay({required this.day});

  final CalendarDay day;

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'تاريخ اليوم ${dayLabel(day)} — من الخادم ولا يُغيَّر',
        child: ExcludeSemantics(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.lock_outline,
                size: Sizes.iconMd,
                color: SemanticColors.textSecondary,
              ),
              const SizedBox(width: Spacing.space4),
              Text(
                dayLabel(day),
                // ★★ **أرقامٌ جدولية** — §6.د: ⟵ **فالتاريخ لا يهتزّ عرضُه
                //    بين يومٍ وآخر** فيُزيح ما بجانبه.
                style: TypeScale.numeric
                    .copyWith(color: SemanticColors.textSecondary),
              ),
            ],
          ),
        ),
      );
}

/// ★ زرّ طيّ المرشِّحات — **يحمل عددَ النشط منها**.
///
/// ⛔ **ولا يُخفي أثرَ المرشِّح وهو مطويّ** — ★ **العدد ظاهرٌ على الزر**:
/// ⟵ **فلا يقرأ المستخدم قائمةً مفلترة ظانّاً أنها كاملة.**
class _FilterToggle extends StatelessWidget {
  const _FilterToggle({
    required this.open,
    required this.activeCount,
    required this.onPressed,
  });

  final bool open;
  final int activeCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    // ⛔⛔★★★ **وزرٌّ أيقونيٌّ لا نصّي — عطلٌ رصده المحاكي (`DEBT-48`):**
    // ★ **`TextButton.icon` بنصّ «مرشِّحات» كان ثالثَ عنصرٍ في الصفّ**،
    // ⟵ **فعصر اسمَ المصدر إلى «مصدر الاخت…» عند المقياس الطبيعي** —
    // ⛔ **فلا يعرف المستخدم على أي مصدرٍ يعمل**، ★ **وكلُّ رقمٍ في الشاشة
    // يخصّ مصدراً بعينه** (`A-01`).
    //
    // ★★ **والعددُ لم يسقط بل انتقل إلى شارةٍ** — §5b: **«وعددُ النشط يظهر
    // في زرّ الطيّ»** ⟵ **فالشرطُ محفوظٌ بحرفه**، ⛔ **والنصُّ وحده هو ما
    // استُغني عنه** — ★ **ويبقى في `tooltip` لقارئ الشاشة.**
    final String label =
        activeCount > 0 ? 'مرشِّحات ($activeCount)' : 'مرشِّحات';
    final Widget glyph = Icon(
      open ? Icons.expand_less : Icons.tune_outlined,
      size: Sizes.iconMd,
    );
    return IconButton(
      onPressed: onPressed,
      tooltip: label,
      // ★ **هدف لمسٍ كامل** — `design-system.md` §5 البند 3.
      constraints: const BoxConstraints(
        minWidth: Sizes.minTouch,
        minHeight: Sizes.minTouch,
      ),
      icon: activeCount > 0
          ? Badge.count(count: activeCount, child: glyph)
          : glyph,
    );
  }
}

/// ⚠️ **نطاقٌ فارغ** — `E-35`: مستخدمٌ لا مصدرَ ضمن نطاقه.
///
/// ⛔ **ولا يُعرَض فراغاً ولا خطأً** — ★ **حالةٌ مشروعة لها نصُّها وخطوتُها.**
class _NoScopeNotice extends StatelessWidget {
  const _NoScopeNotice();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.all(Spacing.screenPadding),
        child: Row(
          children: <Widget>[
            const Icon(
              Icons.info_outline,
              size: Sizes.iconMd,
              color: SemanticColors.textSecondary,
            ),
            const SizedBox(width: Spacing.space8),
            Expanded(
              child: Text(
                'لا يوجد مصدر ضمن نطاقك. راجع المدير.',
                style: TypeScale.bodyMd
                    .copyWith(color: SemanticColors.textSecondary),
              ),
            ),
          ],
        ),
      );
}

/// ★★★ **الحالة الفارغة حين لا مصدرَ مختار** — §5b نمط `P3`.
///
/// ⛔⛔★★★ **وهي بديلُ `SizedBox.shrink` الذي كان في أربع شاشات** — ⟵ **شاشةٌ
/// بيضاء صامتة تُقرأ عطلاً**، ★ **و§هـ يفرض «أيقونة + عنوان + رسالة + إجراء».**
EmptyStateSpec chooseSourceEmpty({VoidCallback? onChoose}) => EmptyStateSpec(
      icon: Icons.warehouse_outlined,
      title: 'اختر مصدراً لعرض بياناته',
      message: 'رصيد كل نوع وحساباته مستقلة في كل مصدر — '
          'فاختر المصدر أولاً من أعلى الشاشة.',
      actionLabel: onChoose == null ? null : 'اختيار المصدر',
      onAction: onChoose,
    );

/// ★★ الحالة الفارغة حين لا مصدرَ في نطاق المستخدم أصلاً — `E-35`.
///
/// ⛔ **ولا إجراءَ لها** — ★ **فالمستخدم لا يملك ما يفعله**: ⟵ **والخطوة
/// التالية مراجعةُ المدير**، ⛔ **لا زرٌّ لا يقود إلى شيء.**
const EmptyStateSpec noSourceInScopeEmpty = EmptyStateSpec(
  icon: Icons.lock_outline,
  title: 'لا يوجد مصدر ضمن نطاقك',
  message: 'نطاق مصادرك لا يشمل أي مصدر — راجع المدير لمنحك نطاقاً.',
);

/// ★★★ جدولُ العرض — **عقدُ `design-system.md` §6.د حرفياً**.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ★ **العقد المُلزِم:** **رأسٌ ثابت `surfaceSunken`** · **صفوف 48** ·
/// **أرقامٌ جدولية** · ★ **تمريرٌ أفقيٌّ واحدٌ يتشاركه الرأس والجسم** ·
/// ⛔ **لا تمرير رأسي داخلي** · ★ **وتحوّلٌ تلقائي إلى بطاقات تحت عرض 360**.
///
/// ⛔⛔★★ **والتمريرُ الأفقي واحدٌ بنيوياً لا بمزامنة متحكّمَين:** ★ **الرأسُ
/// والجسمُ داخل ممرٍّ واحد** — ⟵ **فيستحيل أن ينزلق أحدهما عن الآخر**،
/// ⛔ **ومزامنةُ متحكّمَين تنزلق عند أول قفزةٍ برمجية.**
///
/// ⛔⛔★★ **ولا تمريرَ رأسيٌّ هنا** — ★ **الجدولُ يُبنى كاملاً داخل ممرِّ
/// الشاشة**: ⟵ **وممرٌّ داخل ممرٍّ يسرق لفتةَ الإصبع** ⛔ **فيتعذّر تمريرُ
/// الشاشة من فوق الجدول.**
/// ═══════════════════════════════════════════════════════════════════════
///
/// ⚠️⚠️ **والصفُّ الملغى يُعرَض مشطوباً ولا يختفي** (`A-14` · `GR-06`) —
/// ★ **ولا يُنقَل المعنى باللون وحده** (`design-system.md` §8 المحظور
/// الثاني عشر): ⟵ **والشطبُ شكلٌ لا لون**، ★ **ونصُّ الحالة في عموده.**
library;

import 'package:flutter/material.dart';

import '../design/design_tokens.dart';

/// عمودٌ في الجدول.
@immutable
class QtmsTableColumn {
  /// ينشئ العمود.
  const QtmsTableColumn(this.label, {this.numeric = false});

  /// العنوان المعروض.
  final String label;

  /// ★ **رقمٌ يُعرَض بالأرقام الجدولية** — ⛔ **والقرار يصل جاهزاً**
  /// (`design-system.md` §5.1) ⛔ **لا يُستنبَط بفحص النصّ.**
  final bool numeric;
}

/// صفٌّ في الجدول — **خلاياه بترتيب الأعمدة**.
@immutable
class QtmsTableRow {
  /// ينشئ الصف.
  const QtmsTableRow(this.cells, {this.isStruck = false});

  /// الخلايا **نصّاً جاهزاً** — ⛔ **ولا حسابَ في المكوّن** (§5.1).
  final List<String> cells;

  /// ★ مشطوب — **للحركة الملغاة** (`A-14`).
  final bool isStruck;
}

/// ★★★ الجدول.
class QtmsDataTable extends StatelessWidget {
  /// ينشئ الجدول.
  const QtmsDataTable({
    required this.columns,
    required this.rows,
    this.minimumColumnWidth = _defaultColumnWidth,
    super.key,
  });

  /// الأعمدة.
  final List<QtmsTableColumn> columns;

  /// الصفوف.
  final List<QtmsTableRow> rows;

  /// ★ أدنى عرضٍ لعمود — ⛔ **ولا يُكتَب رقمٌ في شاشة** (يُمرَّر من التوكنز).
  final double minimumColumnWidth;

  static const double _defaultColumnWidth = 120;

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.sizeOf(context).width;
    // ★★ **تحت 360 تتحوّل الجداول إلى بطاقات** — `ui-guidelines.md` §5.
    if (width < Breakpoints.compact) return _CardList(columns: columns, rows: rows);

    return Directionality(
      textDirection: Directionality.of(context),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _HeaderRow(columns: columns, columnWidth: minimumColumnWidth),
            for (final QtmsTableRow row in rows)
              _BodyRow(
                columns: columns,
                row: row,
                columnWidth: minimumColumnWidth,
              ),
          ],
        ),
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.columns, required this.columnWidth});

  final List<QtmsTableColumn> columns;
  final double columnWidth;

  @override
  Widget build(BuildContext context) => Container(
        height: Sizes.minTouch,
        color: SemanticColors.surfaceSunken,
        child: Row(
          children: <Widget>[
            for (final QtmsTableColumn column in columns)
              SizedBox(
                width: columnWidth,
                child: Padding(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: Spacing.space8,
                  ),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      column.label,
                      style: TypeScale.label
                          .copyWith(color: SemanticColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
}

class _BodyRow extends StatelessWidget {
  const _BodyRow({
    required this.columns,
    required this.row,
    required this.columnWidth,
  });

  final List<QtmsTableColumn> columns;
  final QtmsTableRow row;
  final double columnWidth;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: SemanticColors.divider,
              width: Sizes.borderWidth,
            ),
          ),
        ),
        child: SizedBox(
          height: Sizes.minTouch,
          child: Row(
            children: <Widget>[
              for (int i = 0; i < columns.length; i++)
                SizedBox(
                  width: columnWidth,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.symmetric(
                      horizontal: Spacing.space8,
                    ),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        i < row.cells.length ? row.cells[i] : '',
                        style: _cellStyle(columns[i].numeric, row.isStruck),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
}

/// ★★ بطاقاتٌ بدل الجدول تحت 360 — **صفٌّ مفتاح-قيمة لكل خلية**.
///
/// ⚠️ **ولا تُقتَطع الأعمدة** — ★ **جدولٌ بستة أعمدة على 320 بكسل يُقرأ
/// حرفاً حرفاً**، ⟵ **والبطاقةُ تُبقي كل قيمةٍ باسمها.**
class _CardList extends StatelessWidget {
  const _CardList({required this.columns, required this.rows});

  final List<QtmsTableColumn> columns;
  final List<QtmsTableRow> rows;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final QtmsTableRow row in rows)
            Container(
              margin: const EdgeInsetsDirectional.only(
                bottom: Spacing.cardGap,
              ),
              padding: const EdgeInsetsDirectional.all(Spacing.cardPadding),
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
                children: <Widget>[
                  for (int i = 0; i < columns.length; i++)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(
                        bottom: Spacing.space4,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              columns[i].label,
                              style: TypeScale.caption.copyWith(
                                color: SemanticColors.textSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(width: Spacing.space8),
                          Expanded(
                            child: Text(
                              i < row.cells.length ? row.cells[i] : '',
                              style: _cellStyle(
                                columns[i].numeric,
                                row.isStruck,
                              ),
                              textAlign: TextAlign.end,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      );
}

/// ★ نمطُ الخلية — **جدوليٌّ للأرقام، ومشطوبٌ للملغى**.
TextStyle _cellStyle(bool numeric, bool struck) {
  final TextStyle base = numeric
      ? TypeScale.numericSm.copyWith(color: SemanticColors.textPrimary)
      : TypeScale.bodyMd.copyWith(color: SemanticColors.textPrimary);
  return struck
      ? base.copyWith(
          decoration: TextDecoration.lineThrough,
          color: SemanticColors.textTertiary,
        )
      : base;
}

/// ★★★ **باني المركز المعلّق** — الدوال الخالصة التي تُنتج بنودَه.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **ولماذا هنا لا في السحابة وحدها** (`ADR-0012` ·
/// `coding-standards.md` §2.2): ★ **الشاشة تعرض الدلالات الخمس نفسها**
/// (`FR-SYS-03`: الحقل · سطر السجل · رأس الشاشة · لوحة التحكم · التصدير)،
/// ⟵ **ولو حكمت الشاشةُ بنفسها «هذا الحقل ناقص» لعاش الشرطُ في موضعين**
/// ⛔ **واختلف حكمُه عن حكم الكاتب في أول حالةٍ حدّية** (وزنٌ متبقٍّ بمقدار
/// `1e-15` · سعرٌ صفري · جونيةٌ ملغاة). ★ **وهذا الملف يجعلهما دالةً واحدة.**
///
/// ★★★ **وكل دالة هنا تُرجِع [PendingEntrySet] لا قائمةَ بنود** — ⟵ **لأن
/// «ما يجب أن يُحذَف» جزءٌ من الجواب لا أثرٌ جانبي:** §7 من
/// `pending-entries-design.md` تجعل البند **«يختفي فور الإدخال الفعلي»**،
/// ⛔ **وكاتبٌ يعرف ما يكتب ولا يعرف ما يمحو يترك يتامى** — ★ **فيُطالَب
/// المستخدم بقيمةٍ أدخلها فعلاً**، وهو أسوأ عطلٍ ممكنٍ في شاشةٍ غرضها
/// التذكير (`GR-50`).
///
/// ⛔⛔ **ولا دالةَ هنا تمنع شيئاً** — `FR-SYS-06` (**حرجة**): **المركز
/// يلاحق ويذكّر ولا يُعطِّل أي عملية.**
/// ═══════════════════════════════════════════════════════════════════════
library;

import '../../../core/calendar_day.dart';
import '../../../core/money.dart';
import '../../inventory/domain/daily_price.dart'
    show dailyPriceId, isPricingComplete;
import '../../inventory/domain/sack_intake.dart' show SackWeightState;
import 'pending_entry.dart';

// ═════════════════════════════════════════════════════════════════════════
// الحصيلة — ★ **ما يُكتَب وما يُمحى معاً**
// ═════════════════════════════════════════════════════════════════════════

/// ★★ حصيلة البناء لمستندٍ واحد — **البنود القائمة ومعرّفات ما زال**.
///
/// ⚠️ **والمجموعتان متكاملتان لا متداخلتان:** ★ **كل حقلٍ من حقول هذا
/// المستند يقع في إحداهما بالضبط** — ⟵ **فإعادةُ تشغيل الباني على الحالة
/// نفسها تُنتج القائمتين نفسَيهما** (`PAT-07`).
final class PendingEntrySet {
  /// ينشئ الحصيلة.
  const PendingEntrySet({
    this.drafts = const <PendingEntryDraft>[],
    this.clearedIds = const <String>[],
  });

  /// ★ البنود التي **يجب أن تكون قائمة** الآن.
  final List<PendingEntryDraft> drafts;

  /// ★★ معرّفات البنود التي **يجب أن تزول** الآن — ⛔ **والحذف عديمُ الأثر
  /// على غائب**، ⟵ **فلا قراءةَ سابقة له.**
  final List<String> clearedIds;

  /// ★ هل هذه الحصيلة بلا أثرٍ إطلاقاً؟ — ⟵ **فيتخطّاها الكاتب.**
  bool get isEmpty => drafts.isEmpty && clearedIds.isEmpty;
}

// ═════════════════════════════════════════════════════════════════════════
// `M7` — الجونية
// ═════════════════════════════════════════════════════════════════════════

/// ★ حقول الجونية المُلاحَقة — **ثلاثةٌ بالضبط** (راجع [PendingMissingField]).
const List<PendingMissingField> sackPendingFields = <PendingMissingField>[
  PendingMissingField.sackTax,
  PendingMissingField.sackLines,
  PendingMissingField.sackLostWeight,
];

/// ★★★ بنود جونيةٍ واحدة — `FR-M7-10` · `E-06` · `E-10`.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ★★ **والحالة مخزَّنةٌ في المستند أصلاً** — `sack-intake-design.md` §5:
/// «**`remainingWeight` · `lostWeightConfirmed` · `taxPerKilo`**»، ⟵ **فلا
/// شيء يُستنتَج هنا ولا يُحسَب**: ★ **الدالة تقرأ حالةً كُتبت وتصفها.**
///
/// ⛔⛔★★ **والجونية الملغاة تُخلي بنودها كلَّها** (`GR-06` · `FR-M7-26`):
/// ★ **الملغى يخرج من كل الأرصدة والتقارير**، ⟵ **ومطالبةُ المستخدم بضريبة
/// جونيةٍ ألغاها مطالبةٌ بلا معنى** ⛔ **وتُبقي عدّاداً لا يُصفَّر أبداً.**
///
/// ⚠️ **و«الوزن الضائع» بندٌ للحالة [SackWeightState.unexplained] وحدها** —
/// ⛔ **لا للمفسَّر بالكامل ولا للمؤكَّد ضائعاً**: ★ **الأول لا نقص فيه،
/// والثاني أُدخِلت قيمتُه بالزرّ الصريح** (`BR-M7-12`).
/// ═══════════════════════════════════════════════════════════════════════
PendingEntrySet describeSackPending({
  required String sackId,
  required String sourceId,
  required CalendarDay stockDate,
  required String displayName,
  required bool hasTax,
  required bool hasLines,
  required SackWeightState weightState,
  String? documentNumber,
  bool isCancelled = false,
}) {
  final List<PendingEntryDraft> drafts = <PendingEntryDraft>[];

  if (!isCancelled) {
    if (!hasTax) {
      drafts.add(
        _sackDraft(
          sackId: sackId,
          sourceId: sourceId,
          stockDate: stockDate,
          displayName: displayName,
          documentNumber: documentNumber,
          field: PendingMissingField.sackTax,
        ),
      );
    }
    if (!hasLines) {
      drafts.add(
        _sackDraft(
          sackId: sackId,
          sourceId: sourceId,
          stockDate: stockDate,
          displayName: displayName,
          documentNumber: documentNumber,
          field: PendingMissingField.sackLines,
        ),
      );
    }
    if (weightState == SackWeightState.unexplained) {
      drafts.add(
        _sackDraft(
          sackId: sackId,
          sourceId: sourceId,
          stockDate: stockDate,
          displayName: displayName,
          documentNumber: documentNumber,
          field: PendingMissingField.sackLostWeight,
        ),
      );
    }
  }

  return _completeSet(
    kind: PendingDocumentKind.sack,
    documentId: sackId,
    allFields: sackPendingFields,
    drafts: drafts,
  );
}

PendingEntryDraft _sackDraft({
  required String sackId,
  required String sourceId,
  required CalendarDay stockDate,
  required String displayName,
  required String? documentNumber,
  required PendingMissingField field,
}) =>
    PendingEntryDraft(
      kind: PendingDocumentKind.sack,
      documentId: sackId,
      field: field,
      // ★★ **الاسم الظاهر هو العنوان المقروء حرفياً** — §3 من مستند الوحدة
      //    يضرب مثالَه نفسه: «عبد الفتاح - جونية رقم ١»، ⟵ **وهو ما يبنيه
      //    [sackDisplayName]** ⛔ **فلا صيغةَ ثانية للاسم نفسه** (`ADR-0007`).
      readableTitle: displayName,
      sourceId: sourceId,
      date: stockDate,
      documentNumber: documentNumber,
    );

// ═════════════════════════════════════════════════════════════════════════
// `M9` — تسعير نوعٍ له كمية اليوم
// ═════════════════════════════════════════════════════════════════════════

/// ★ حقول التسعير المُلاحَقة — **واحدٌ بالضبط** (راجع [PendingMissingField]).
const List<PendingMissingField> itemPricingPendingFields =
    <PendingMissingField>[PendingMissingField.itemPricing];

/// ★★★ بندُ تسعيرِ نوعٍ في يومٍ ومصدر — `FR-M9-10` · `AT-16` · `FR-SYS-08`.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ★★★ **وشرطاه معاً لا أحدهما** (`FR-M9-10` نصّاً):
///   ① **له كمية في مخزون اليوم** — [hasStock]. ⛔ **والصفر ليس كمية**:
///      `pending-entries-design.md` §9 — «**نوع نفد رصيده اليوم ⟵ يختفي
///      بند تسعيره: لا يُطالَب بتسعير ما لا كمية له**».
///   ② **ولم يكتمل تسعيره** — [isPricingComplete] وحدها حَكَماً
///      (`FR-M9-05`)، ⛔ **ولا شرطٌ يُعاد كتابته هنا.**
///
/// ★★ **والسكرب كأي نوع** — `FR-SYS-08` نصّاً: «**بما فيه السكرب**»،
/// ⟵ **فلا استثناءَ في هذه الدالة إطلاقاً**، ★ **ومفتاحُه المركّب يدخل
/// [itemKey] كما يدخله الدفتر** (`ADR-0007` · `withLedgerItems`).
///
/// ★★ **والبند واحدٌ لِما ينقصه سعرٌ أو حدٌّ أو كلاهما** — ⛔ **ولا بندان**:
/// ⟵ **والنصُّ المعروض وحده يفرّق بينها** (راجع [_pricingLabel])، ★ **فلا
/// يبقى نصفُ بندٍ بعد إدخال نصف القيمة.**
/// ═══════════════════════════════════════════════════════════════════════
PendingEntrySet describeItemPricingPending({
  required String sourceId,
  required String itemKey,
  required String itemName,
  required CalendarDay date,
  required bool hasStock,
  Money? distributionPrice,
  Money? minCashPrice,
}) {
  final String documentId =
      dailyPriceId(sourceId: sourceId, itemKey: itemKey, date: date);
  final bool complete = isPricingComplete(
    distributionPrice: distributionPrice,
    minCashPrice: minCashPrice,
  );

  return _completeSet(
    kind: PendingDocumentKind.dailyPrice,
    documentId: documentId,
    allFields: itemPricingPendingFields,
    drafts: hasStock && !complete
        ? <PendingEntryDraft>[
            PendingEntryDraft(
              kind: PendingDocumentKind.dailyPrice,
              documentId: documentId,
              field: PendingMissingField.itemPricing,
              // ★ **اسم النوع وحده عنواناً** — ⟵ **فالمستخدم يعرف ما ينقصه
              //   بلا فتح شاشة**، ★ **والمصدر واليوم في الفلتر أصلاً.**
              readableTitle: itemName,
              sourceId: sourceId,
              date: date,
              missingField: _pricingLabel(
                distributionPrice: distributionPrice,
                minCashPrice: minCashPrice,
              ),
            ),
          ]
        : const <PendingEntryDraft>[],
  );
}

/// ★★ نصُّ ما ينقص بالضبط — ⛔ **لا «لم يُسعَّر» مبهمة**.
///
/// ⚠️ **و`ui-guidelines.md` §6 يفرض هذا:** «**ما الشرط المخالَف وكيف يُصلَح**»
/// — ⟵ **ومن أدخل سعر التوزيع وحده يجب أن يقرأ «الحد الأدنى»** ⛔ **لا
/// «تسعير النوع»** فيظنّ أن ما أدخله ضاع.
String _pricingLabel({
  required Money? distributionPrice,
  required Money? minCashPrice,
}) {
  if (distributionPrice == null && minCashPrice == null) {
    return 'سعر التوزيع والحد الأدنى';
  }
  return distributionPrice == null ? 'سعر التوزيع' : 'الحد الأدنى';
}

// ═════════════════════════════════════════════════════════════════════════
// `M10` — سطرُ توزيعٍ بلا سعر
// ═════════════════════════════════════════════════════════════════════════

/// ★ حقول التوزيعة المُلاحَقة — **واحدٌ بالضبط** (راجع [PendingMissingField]).
const List<PendingMissingField> distributionPendingFields =
    <PendingMissingField>[PendingMissingField.distributionLinePricing];

/// ★★★ بندُ توزيعةٍ بسطورٍ غير مسعَّرة — `FR-M10-08` · `AT-23` · `AT-24`.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ★★ **بندٌ واحد للتوزيعة مهما بلغ عدد سطورها غير المسعَّرة** —
/// `pending-entries-design.md` §9 (`AT-23`): «**بند واحد · والحالة مسعَّر
/// جزئياً**»، ⟵ **والعدد يظهر في نصّ البند** ⛔ **لا في عدد البنود:**
/// ★ **فالمستخدم يفتح شاشةً واحدة ويُسعِّر ما فيها دفعةً.**
///
/// ⛔⛔ **والتوزيعة الملغاة تُخلي بندها** (`GR-06` · `FR-M10-18`) — ★ **بنفس
/// علّة الجونية الملغاة حرفياً.**
/// ═══════════════════════════════════════════════════════════════════════
PendingEntrySet describeDistributionPending({
  required String distributionId,
  required String sourceId,
  required CalendarDay stockDate,
  required String dealerName,
  required int unpricedLineCount,
  String? documentNumber,
  bool isCancelled = false,
}) =>
    _completeSet(
      kind: PendingDocumentKind.distribution,
      documentId: distributionId,
      allFields: distributionPendingFields,
      drafts: !isCancelled && unpricedLineCount > 0
          ? <PendingEntryDraft>[
              PendingEntryDraft(
                kind: PendingDocumentKind.distribution,
                documentId: distributionId,
                field: PendingMissingField.distributionLinePricing,
                // ★ **اسم المقوت هو ما يعرفه المستخدم** — ⛔ **لا المعرّف
                //   المركّب** (`ui-guidelines.md` §6: بلا مصطلح تقني).
                readableTitle: 'توزيعة $dealerName',
                sourceId: sourceId,
                date: stockDate,
                documentNumber: documentNumber,
                missingField: unpricedLineCount == 1
                    ? 'سعر الوحدة لسطرٍ واحد'
                    : 'سعر الوحدة لـ$unpricedLineCount سطور',
              ),
            ]
          : const <PendingEntryDraft>[],
    );

// ═════════════════════════════════════════════════════════════════════════
// المُكمِّل — ★ **ما لم يُكتَب يُمحى**
// ═════════════════════════════════════════════════════════════════════════

/// ★★★ يُكمل الحصيلة: **كل حقلٍ لا بندَ له الآن يدخل قائمة المحو**.
///
/// ⚠️⚠️ **وهذه هي الضمانة التي تجعل §7 صحيحة بلا استعلام:** ⟵ **الكاتب
/// يمحو ما لم يعد ناقصاً في اللحظة نفسها التي كتب فيها ما بقي ناقصاً**،
/// ⛔ **ولا يحتاج أن يقرأ ما هو قائم.**
PendingEntrySet _completeSet({
  required PendingDocumentKind kind,
  required String documentId,
  required List<PendingMissingField> allFields,
  required List<PendingEntryDraft> drafts,
}) {
  final Set<PendingMissingField> present = <PendingMissingField>{
    for (final PendingEntryDraft draft in drafts) draft.field,
  };
  return PendingEntrySet(
    drafts: List<PendingEntryDraft>.unmodifiable(drafts),
    clearedIds: List<String>.unmodifiable(<String>[
      for (final PendingMissingField field in allFields)
        if (!present.contains(field))
          pendingEntryId(kind: kind, documentId: documentId, field: field),
    ]),
  );
}

/// ★ يدمج حصائلَ عدّة مستندات في واحدة — **للمعاملة الواحدة**.
///
/// ⚠️ **والتكرار يُزال بالمعرّف** — ⟵ **فمستندان يمسّان نوعاً واحداً في
/// معاملةٍ واحدة** (سطرا جونيةٍ بنفس النوع) **لا يُنتجان كتابتين لبندٍ
/// واحد**، ⛔ **ولا كتابةً ومحواً للمعرّف نفسه.**
///
/// ★★ **والكتابة تغلب المحو عند التعارض** — ⟵ **فنوعٌ بقي ناقصاً في سطرٍ
/// ومكتملاً في آخر يبقى بنده قائماً**: ⛔ **ومحوُه كان سيُخفي نقصاً حقيقياً**،
/// ★ **وهو ما يمنعه `GR-50`** (المركز **لا ينسى**).
PendingEntrySet mergePendingSets(Iterable<PendingEntrySet> sets) {
  final Map<String, PendingEntryDraft> drafts = <String, PendingEntryDraft>{};
  final Set<String> cleared = <String>{};
  for (final PendingEntrySet set in sets) {
    for (final PendingEntryDraft draft in set.drafts) {
      drafts[draft.entryId] = draft;
    }
    cleared.addAll(set.clearedIds);
  }
  cleared.removeAll(drafts.keys);
  return PendingEntrySet(
    drafts: List<PendingEntryDraft>.unmodifiable(drafts.values),
    clearedIds: List<String>.unmodifiable(cleared),
  );
}

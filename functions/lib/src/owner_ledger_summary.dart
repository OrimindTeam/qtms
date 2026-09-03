/// ★★★ **باني الملخصات — الطرف الخالص** (`api-overview.md` §3.2
/// `buildDailySummaries`).
///
/// ★ **مفصولٌ عن `owner_ledger_summary_handler.dart` عمداً**، بنفس منطق
/// `sack_valuation.dart` مقابل `sack_valuation_handler.dart`: **كلُّ قرارٍ
/// هنا في دوالَّ خالصةٍ تُختبَر بلا سحابة**؛ **وهناك القراءةُ والالتزام**.
///
/// ⛔⛔★★★ **ولا معادلةَ واحدةً في هذا الملف** — ★ **العشرُ كلُّها في
/// `packages/qtms_domain/.../owner_ledger_summary.dart`** (`ADR-0012`):
/// ⟵ **وهذا الملف يُحوِّل نتيجتَها إلى حقولٍ مخزَّنة لا أكثر**، ⛔ **ونسخةٌ
/// ثانية من معادلةٍ هنا تفترق عن أصلها عند أول تعديل** (`coding-standards.md`
/// §2.2).
library;

import 'package:qtms_domain/qtms_domain.dart';

import 'inventory.dart' show InventoryWrite;

/// ★ حقلُ وسم الأثر الرجعي — `FR-M15-12` · `owner-ledger-summary-design.md` §7.
///
/// ⚠️⚠️★★ **ويُكتب طابعَ خادمٍ لا وقتَ حاوية** (`GR-54` · `E-41`) — ★ **والقرارُ
/// وحدَه يُتَّخذ في الحاوية** (**هل اليومُ المبنيُّ ماضٍ؟**)، ⛔ **والقيمةُ من
/// المنصّة.**
const String retroUpdatedAtField = 'retroUpdatedAt';

/// حقلُ وقت آخر بناء.
const String summaryUpdatedAtField = 'updatedAt';

/// حقلُ مصفوفة نقاط السلسلة — `owner_ledger_trends` (§2.1).
const String trendPointsField = 'points';

// ═════════════════════════════════════════════════════════════════════════
// ★★ الملخّص اليومي — `schema/daily-summaries.md`
// ═════════════════════════════════════════════════════════════════════════

/// ★★★ يبني كتابةَ ملخّصِ يومٍ في مصدر.
///
/// ⛔⛔★★ **ويُعيد البناء كاملاً في كل مرة** — ★ **ولا يُراكِم على قيمةٍ
/// سابقة** (`api-overview.md` §3.3 · `PAT-08`): ⟵ **فالمُشغِّل قد يُنفَّذ
/// مرتين أو خارج الترتيب**، ⛔ **والتراكمُ يُنتج رقماً مضاعفاً بلا أي إنذار.**
///
/// ★ **و[markRetro] تُوسَم لليوم الماضي وحده** — ⟵ **فبناءُ اليوم الجاري
/// ليس أثراً رجعياً**، ⛔ **ووسمُه يجعل كلَّ بطاقةٍ موسومةً فيفقد الوسمُ معناه.**
InventoryWrite planDailySummaryWrite(
  OwnerLedgerSummary summary, {
  required bool markRetro,
}) {
  final Map<String, Object?> fields = <String, Object?>{
    // ⚠️⚠️ **حقلان صريحان لا مفتاحٌ مركّبٌ وحده** (`IQ-002` ④) — ★ **شرطُ
    //    القراءة `storedInScope()` يقرأ الحقل**، ⛔ **والمفتاحُ لا يُفهرَس.**
    'sourceId': summary.sourceId,
    'date': summary.date.asUtcMidnight(),
    'credit': summary.credit.riyals,
    'cash': summary.cash.riyals,
    'totalDebt': summary.totalDebt.riyals,
    'settledOfDay': summary.settledOfDay.riyals,
    'discounts': summary.discounts.riyals,
    'remainingBeforeDiscount': summary.remainingBeforeDiscount.riyals,
    'remainingAfterDiscount': summary.remainingAfterDiscount.riyals,
    'tax': summary.tax.riyals,
    'remainingAfterTax': summary.remainingAfterTax.riyals,
    'withdrawals': summary.withdrawals.riyals,
    'expenses': summary.expenses.riyals,
    'netFinal': summary.netFinal.riyals,
  };
  return InventoryWrite(
    collectionId: dailySummariesCollection,
    documentId: dailySummaryId(
      sourceId: summary.sourceId,
      date: summary.date,
    ),
    fields: fields,
    updateMask: fields.keys.toList(),
    serverTimestampFields: <String>[
      summaryUpdatedAtField,
      // ⛔ **ولا يُمحى وسمٌ قديم عند بناء اليوم الجاري** — ★ **القناعُ لا
      //   يشمل الحقل أصلاً حين لا يُوسَم**: ⟵ **فيبقى ما كُتب سابقاً.**
      if (markRetro) retroUpdatedAtField,
    ],
  );
}

/// ★ يقرأ ملخّصاً مخزَّناً — ⛔ **و`null` لمستندٍ غائبٍ أو بلا تاريخ صالح.**
///
/// ⚠️ **والغيابُ حالةٌ طبيعية لا خطأ** — ★ **يومٌ بلا حركةٍ لا مستندَ له.**
OwnerLedgerSummary? readDailySummary(Map<String, Object?>? fields) {
  if (fields == null) return null;
  final Object? sourceId = fields['sourceId'];
  if (sourceId is! String || sourceId.isEmpty) return null;
  final CalendarDay? date = readSummaryDay(fields['date']);
  if (date == null) return null;
  return computeOwnerLedgerSummary(
    sourceId: sourceId,
    date: date,
    contributions: OwnerLedgerContributions(
      credit: _money(fields['credit']),
      cash: _money(fields['cash']),
      settledOfDay: _money(fields['settledOfDay']),
      discounts: _money(fields['discounts']),
      tax: _money(fields['tax']),
      withdrawals: _money(fields['withdrawals']),
      expenses: _money(fields['expenses']),
    ),
    retroUpdatedAt: switch (fields[retroUpdatedAtField]) {
      final DateTime stamp => stamp,
      _ => null,
    },
  );
}

/// ★ يقرأ يوماً مخزَّناً طابعاً زمنياً — ⛔ **و`null` لغير الصالح.**
CalendarDay? readSummaryDay(Object? raw) => switch (raw) {
      final DateTime value => CalendarDay.fromUtc(value),
      final String value => CalendarDay.tryParseCompact(value),
      _ => null,
    };

// ═════════════════════════════════════════════════════════════════════════
// ✅★★ سجلُّ السلسلة — `IQ-030` الخيار أ · §2.1
// ═════════════════════════════════════════════════════════════════════════

/// ★★ يبني كتابةَ سجلِّ السلسلة.
///
/// ⛔⛔★★ **و`sourceId` حقلٌ مطلوبٌ لا اختياري** — ★ **شرطُ القراءة يعتمده**
/// (`storedInScope()`): ⟵ **وأيُّ سردٍ لا يُقيّده يُرفَض كاملاً** (`IQ-024` ·
/// `WU-008` · `DEBT-40`)، ★ **وغيابُه يجعل المستندَ غيرَ مقروءٍ لأحد.**
InventoryWrite planOwnerLedgerTrendWrite({
  required String sourceId,
  required List<OwnerLedgerTrendPoint> points,
}) {
  final Map<String, Object?> fields = <String, Object?>{
    'sourceId': sourceId,
    trendPointsField: <Object?>[
      for (final OwnerLedgerTrendPoint point in points)
        <String, Object?>{
          // ★ **نصّاً مضغوطاً `YYYYMMDD`** — ⟵ **داخل مصفوفةٍ لا تُفهرَس
          //   ولا يُستعلَم عليها**، ★ **ونظيرُه `stockDate` في سجل التدقيق.**
          'date': point.date.format(),
          'netFinal': point.netFinal.riyals,
          'withdrawals': point.withdrawals.riyals,
          'expenses': point.expenses.riyals,
          'retroUpdated': point.retroUpdated,
        },
    ],
  };
  return InventoryWrite(
    collectionId: ownerLedgerTrendsCollection,
    documentId: ownerLedgerTrendId(sourceId),
    fields: fields,
    updateMask: fields.keys.toList(),
    serverTimestampFields: const <String>[summaryUpdatedAtField],
  );
}

/// ★ يقرأ نقاطَ سلسلةٍ مخزَّنة — ⛔ **والمشوَّهُ يُسقَط ولا يُسقِط البناء.**
///
/// ⚠️ **ولماذا يُسقَط لا يُرمى:** ★ **السلسلةُ عرضٌ مشتقّ** (`ADR-0008`)،
/// ⟵ **ونقطةٌ تالفةٌ لا يجوز أن تمنع بناءَ ملخّصِ اليوم** — ⛔ **والملخّصُ
/// هو الرقمُ الذي يُبنى عليه قرار.**
List<OwnerLedgerTrendPoint> readOwnerLedgerTrendPoints(
  Map<String, Object?>? fields,
) {
  final Object? raw = fields?[trendPointsField];
  if (raw is! List<Object?>) return const <OwnerLedgerTrendPoint>[];
  final List<OwnerLedgerTrendPoint> points = <OwnerLedgerTrendPoint>[];
  for (final Object? entry in raw) {
    if (entry is! Map<String, Object?>) continue;
    final CalendarDay? date = readSummaryDay(entry['date']);
    if (date == null) continue;
    points.add(
      OwnerLedgerTrendPoint(
        date: date,
        netFinal: _money(entry['netFinal']),
        withdrawals: _money(entry['withdrawals']),
        expenses: _money(entry['expenses']),
        retroUpdated: entry['retroUpdated'] == true,
      ),
    );
  }
  return points;
}

/// ★ نقطةُ السلسلة المقابلةُ لملخّص — **ووسمُها من وسم الملخّص نفسِه**.
OwnerLedgerTrendPoint trendPointOf(
  OwnerLedgerSummary summary, {
  required bool markRetro,
}) =>
    OwnerLedgerTrendPoint(
      date: summary.date,
      netFinal: summary.netFinal,
      withdrawals: summary.withdrawals,
      expenses: summary.expenses,
      retroUpdated: markRetro || summary.retroUpdatedAt != null,
    );

/// ★ مبلغٌ مقروء — ⛔ **والكسر ليس مبلغاً** (`ADR-0015`)، **والغائبُ صفر**.
///
/// ⚠️ **والصفرُ هنا صوابٌ لا افتراضٌ مخترَع:** ★ **حقلٌ غائبٌ في ملخّصٍ
/// مشتقٍّ يعني «لا مساهمةَ في هذا البند»** — ⟵ **وهو صفرٌ بالتعريف.**
Money _money(Object? raw) => switch (raw) {
      final int value => Money(value),
      final double value when value == value.roundToDouble() =>
        Money(value.toInt()),
      _ => Money.zero,
    };

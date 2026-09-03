/// دليل ضمار المالك — **قراءةً فقط** (`ADR-0013` القاعدة 4).
///
/// ⛔★★ **ولا كتابة واحدة هنا:** `daily_summaries` و`owner_ledger_trends`
/// **`allow write: if false` للجميع بمن فيهم المالك** — ⛅ **والملخصاتُ
/// تبنيها العمليةُ السحابية `buildDailySummaries` وحدَها**
/// (`api-overview.md` §3.2 و§4).
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **وكلُّ استعلامٍ يُقيّد `sourceId` صراحةً** — **مقيسٌ أربع مرات في
/// هذا المشروع** (`IQ-024` · `WU-008` · `DEBT-40` · [`DEBT-89`]):
/// ⟵ **الشرط يُقيَّم على قيود الاستعلام لا على كل مستند**، ⛔ **فاستعلامٌ لا
/// يُقيّده يُرفَض كاملاً ولو ملك القارئُ كلَّ المفاتيح.**
///
/// ⛔⛔★★★ **وقراءةُ الملخّص باستعلامٍ مقيَّد ⛔ لا بمعرّفه — وهو `DEBT-40`
/// بعينه، ثانيَ مرة** (كشفه اختبارُ المحاكي وحده · 2026-09-03):
/// ★ **قراءةُ مستندٍ *غائبٍ* بمعرّفه تُرفَض بـ`PERMISSION_DENIED`** — ⟵ **إذ
/// يقرأ الشرطُ `resource.data.sourceId`**، **والمستندُ الغائب بلا `resource`
/// أصلاً فيُقيَّم الشرط `false`.** ⛔⛔ **والغيابُ هنا هو الحالة الطبيعية
/// تماماً:** ★ **يومٌ لم تقع فيه عمليةٌ بعدُ لا ملخّصَ له** — ⟵ **فكانت
/// الشاشةُ تبقى على الهيكل العظمي أبداً في أول يومٍ من كل يوم.**
/// ★ **والعلاجُ تقييدُ الاستعلام** (`sourceId` **و**`date` **صراحةً بفهرسٍ
/// قائم**) ⛔ **لا تخفيفُ القاعدة** — ★ **والقاعدة سليمة ولم تُمَسّ بحرف**،
/// ⟵ **واستعلامٌ لا يُطابق شيئاً يُرجِع صفراً** ⛔ **لا رفضاً.**
/// ═══════════════════════════════════════════════════════════════════════
///
/// ⚠️⚠️★★ **والغيابُ حالةٌ لا خطأ:** ★ **يومٌ بلا حركةٍ لا مستندَ له** —
/// ⟵ **ويُعرَض بأصفارٍ صريحة لا شرطات** (`ui-guidelines.md` نمط 1:
/// **«لأن الصفرَ هنا معلومة»**)، ⛔ **ولا تُسقِط الشاشةُ نفسَها على غيابه.**
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qtms_domain/qtms_domain.dart';

/// الدليل الحقيقي.
final class FirestoreOwnerLedgerDirectory implements OwnerLedgerDirectory {
  /// ينشئ الدليل.
  const FirestoreOwnerLedgerDirectory(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Stream<OwnerLedgerSummary?> watchSummary({
    required String sourceId,
    required CalendarDay date,
  }) =>
      _firestore
          .collection(dailySummariesCollection)
          // ⛔⛔★★★ **الحقلان صراحةً** — راجع ترويسة الملف (`DEBT-40`).
          .where('sourceId', isEqualTo: sourceId)
          .where('date', isEqualTo: Timestamp.fromDate(date.asUtcMidnight()))
          .limit(1)
          .snapshots()
          .map(
            (QuerySnapshot<Map<String, dynamic>> snapshot) =>
                snapshot.docs.isEmpty
                    ? null
                    : summaryOf(snapshot.docs.first.data()),
          );

  @override
  Stream<List<OwnerLedgerTrendPoint>> watchTrend({required String sourceId}) =>
      _firestore
          .collection(ownerLedgerTrendsCollection)
          // ⛔⛔★★ **والمصدرُ مُقيَّدٌ صراحةً كذلك** — ★ **فالسجلُّ يُنشأ مع
          //    أول بناءِ ملخّص**، ⟵ **وقبله غائبٌ تماماً** (`DEBT-40`).
          .where('sourceId', isEqualTo: ownerLedgerTrendId(sourceId))
          .limit(1)
          .snapshots()
          .map(
            (QuerySnapshot<Map<String, dynamic>> snapshot) =>
                snapshot.docs.isEmpty
                    ? const <OwnerLedgerTrendPoint>[]
                    : trendOf(snapshot.docs.first.data()),
          );

  @override
  Stream<List<OwnerLedgerSummary>> watchSummaryRange({
    required String sourceId,
    required CalendarDay from,
    required CalendarDay to,
  }) =>
      _firestore
          .collection(dailySummariesCollection)
          // ★★★ **المصدر مُقيَّدٌ صراحةً** — راجع ترويسة الملف.
          .where('sourceId', isEqualTo: sourceId)
          .where(
            'date',
            isGreaterThanOrEqualTo: Timestamp.fromDate(from.asUtcMidnight()),
            isLessThanOrEqualTo: Timestamp.fromDate(to.asUtcMidnight()),
          )
          .orderBy('date', descending: true)
          .snapshots()
          .map(
            (QuerySnapshot<Map<String, dynamic>> snapshot) =>
                <OwnerLedgerSummary>[
              for (final QueryDocumentSnapshot<Map<String, dynamic>> row
                  in snapshot.docs)
                if (summaryOf(row.data()) case final OwnerLedgerSummary s) s,
            ],
          );

  // ═════════════════════════════════════════════════════════════════════
  // التحويل — ⛔ **والمجهول يُقرأ بالافتراض الآمن لا يُسقِط الشاشة**
  // ═════════════════════════════════════════════════════════════════════

  /// ★ يحوّل مستند ملخّصٍ خاماً — ⛔ **و`null` لمستندٍ غائبٍ أو بلا تاريخ**.
  ///
  /// ★★ **ومكشوفٌ لأن تقارير المرحلة الثانية تقرأ المجموعةَ نفسَها**
  /// (`WU-018` · `R-20`) — ⛔ **ونسخةٌ ثانية تفترق عند أول حقل.**
  static OwnerLedgerSummary? summaryOf(Map<String, dynamic>? data) {
    if (data == null) return null;
    final Object? sourceId = data['sourceId'];
    if (sourceId is! String || sourceId.isEmpty) return null;
    final CalendarDay? date = _dayOf(data['date']);
    if (date == null) return null;
    // ⛔⛔★★ **والبنودُ تُعاد بناؤها بالمعادلة لا تُقرأ مخزَّنةً** —
    //    `ADR-0008`: ⟵ **فلو انحرف مخزَّنٌ قديمٌ عن معادلته اليوم، عُرض
    //    الرقمُ الصحيح**، ⛔ **ولا يُصدَّق `netFinal` مكتوبٌ بمعادلةٍ أقدم.**
    return computeOwnerLedgerSummary(
      sourceId: sourceId,
      date: date,
      contributions: OwnerLedgerContributions(
        credit: _money(data['credit']),
        cash: _money(data['cash']),
        settledOfDay: _money(data['settledOfDay']),
        discounts: _money(data['discounts']),
        tax: _money(data['tax']),
        withdrawals: _money(data['withdrawals']),
        expenses: _money(data['expenses']),
      ),
      retroUpdatedAt: switch (data['retroUpdatedAt']) {
        final Timestamp stamp => stamp.toDate().toUtc(),
        _ => null,
      },
    );
  }

  /// ★ يحوّل مستند السلسلة — ⛔ **والنقطةُ التالفة تُسقَط ولا تُسقِط الرسم**.
  static List<OwnerLedgerTrendPoint> trendOf(Map<String, dynamic>? data) {
    final Object? raw = data?['points'];
    if (raw is! List<dynamic>) return const <OwnerLedgerTrendPoint>[];
    final List<OwnerLedgerTrendPoint> points = <OwnerLedgerTrendPoint>[];
    for (final Object? entry in raw) {
      if (entry is! Map<String, dynamic>) continue;
      final Object? date = entry['date'];
      if (date is! String) continue;
      final CalendarDay? day = CalendarDay.tryParseCompact(date);
      if (day == null) continue;
      points.add(
        OwnerLedgerTrendPoint(
          date: day,
          netFinal: _money(entry['netFinal']),
          withdrawals: _money(entry['withdrawals']),
          expenses: _money(entry['expenses']),
          retroUpdated: entry['retroUpdated'] == true,
        ),
      );
    }
    points.sort(
      (OwnerLedgerTrendPoint a, OwnerLedgerTrendPoint b) =>
          a.date.compareTo(b.date),
    );
    return points;
  }

  static CalendarDay? _dayOf(Object? raw) => switch (raw) {
        final Timestamp stamp => CalendarDay.fromUtc(stamp.toDate().toUtc()),
        final String text => CalendarDay.tryParseCompact(text),
        _ => null,
      };

  /// ⛔ **والكسر ليس مبلغاً** (`ADR-0015`) — **والغائبُ صفرٌ بالتعريف.**
  static Money _money(Object? raw) => switch (raw) {
        final int value => Money(value),
        final double value when value == value.roundToDouble() =>
          Money(value.toInt()),
        _ => Money.zero,
      };
}

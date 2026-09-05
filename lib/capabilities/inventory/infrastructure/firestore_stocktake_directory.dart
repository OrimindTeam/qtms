/// دليلُ الجرد — **قراءةً فقط** (`ADR-0013` القاعدة 4 · `WU-022`).
///
/// ⛔★★ **ولا كتابة واحدة هنا:** `stocktakes` **`allow create, update: if false`**
/// — ★ **والكاتبُ الوحيد العملياتُ المستدعاة** (`functions/lib/src/stocktake.dart`).
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **والاستعلامُ مقيَّدٌ بالمصدر إلزاماً** — ★ **شرطُ القراءة يعتمد
/// `resource.data.sourceId`** (`storedInScope()`)، ⟵ **والسردُ يُقيَّم على
/// قيود الاستعلام لا على كل مستند**: ⟹ ⛔ **فاستعلامٌ لا يُقيّده يُرفَض
/// كاملاً ولو ملك القارئُ نطاقاً شاملاً** (`IQ-024` · `DEBT-40` · `WU-016`).
///
/// ⚠️ **والرفضُ يصل خطأً في التدفّق لا قائمةً فارغة** — ⟵ ★ **فتُميِّز
/// الشاشة بين «لا جرد» و«ممنوعٌ من الرؤية»** (`RISK-02`).
/// ═══════════════════════════════════════════════════════════════════════
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qtms_domain/qtms_domain.dart';

/// الدليل الحقيقي.
final class FirestoreStocktakeDirectory implements StocktakeDirectory {
  /// ينشئ الدليل.
  const FirestoreStocktakeDirectory(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Stream<List<StocktakeCard>> watchStocktakes({
    required String sourceId,
    int limit = 100,
  }) =>
      _firestore
          .collection(stocktakesCollection)
          .where('sourceId', isEqualTo: sourceId)
          // ★ **الفهرس: `sourceId ↑ · stockDate ↓`** — `indexing-strategy.md`
          //   §3 القاعدة 1 (**يبدأ بالمصدر وينتهي بتاريخ المخزون**).
          .orderBy('stockDate', descending: true)
          .limit(limit)
          .snapshots()
          .map(
            (QuerySnapshot<Map<String, dynamic>> snapshot) => <StocktakeCard>[
              for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
                  in snapshot.docs)
                if (stocktakeCardOf(doc.id, doc.data())
                    case final StocktakeCard card)
                  card,
            ],
          );
}

/// ★★ يقرأ بطاقةَ الجرد من حقولها — و`null` **لمستندٍ مشوَّه**.
///
/// ⚠️ **والمشوَّهُ يُتخطّى ولا يُسقِط الشاشة** — ⛔ **ولا يُسدّ نقصُه بقيمةٍ
/// مُولَّدة**: ★ **فرقٌ مخترَعٌ يُري المستخدم تسويةً لم تقع.**
StocktakeCard? stocktakeCardOf(String id, Map<String, dynamic> data) {
  final Object? sourceId = data['sourceId'];
  final Object? stockDate = data['stockDate'];
  if (sourceId is! String || sourceId.isEmpty) return null;
  if (stockDate is! Timestamp) return null;

  final Object? sourceName = data['sourceName'];
  final Object? reason = data['reason'];
  final Object? cancelReason = data['cancelReason'];
  final Object? amendCount = data['amendCount'];
  final Object? documentNumber = data['documentNumber'];

  return StocktakeCard(
    documentNumber: documentNumber is String && documentNumber.isNotEmpty
        ? documentNumber
        : id,
    stockDate: CalendarDay.fromUtc(stockDate.toDate().toUtc()),
    sourceId: sourceId,
    sourceName:
        sourceName is String && sourceName.isNotEmpty ? sourceName : null,
    // ★ **الحالةُ من الحقل المخزَّن** — ⛔ **ولا تُستنتَج من امتلاء الأعداد.**
    status: _statusOf(data['status']),
    reason: reason is String && reason.isNotEmpty ? reason : null,
    cancelReason:
        cancelReason is String && cancelReason.isNotEmpty ? cancelReason : null,
    amendCount: amendCount is int ? amendCount : 0,
    lines: _linesOf(data['lines']),
  );
}

/// ★ الحالةُ من نصّها — ⛔ **والمجهولُ مسوّدةٌ لا معتمَد**: ★ **الافتراضُ
/// الآمن ألّا يُعرَض مستندٌ مجهولُ الحالة معتمَداً وقد لا يكون.**
StocktakeStatus _statusOf(Object? raw) => switch (raw) {
      final String value when value == StocktakeStatus.approved.name =>
        StocktakeStatus.approved,
      final String value when value == StocktakeStatus.cancelled.name =>
        StocktakeStatus.cancelled,
      _ => StocktakeStatus.draft,
    };

List<StocktakeCardLine> _linesOf(Object? raw) {
  if (raw is! List<Object?>) return const <StocktakeCardLine>[];
  final List<StocktakeCardLine> lines = <StocktakeCardLine>[];
  for (final Object? entry in raw) {
    if (entry is! Map<String, Object?>) continue;
    final Object? itemKey = entry['itemKey'] ?? entry['itemId'];
    if (itemKey is! String || itemKey.isEmpty) continue;
    final Object? itemName = entry['itemName'];
    // ★ **الوحدةُ من المستند** — ⛔ **ولا تُستنتَج من شكل الرقم**: ⟵ **حبّةٌ
    //   عددُها 3 ووزنٌ قدرُه 3.000 كجم يُكتبان `3` كلاهما** (`GR-19`).
    final ItemUnit unit = entry['unit'] == ItemUnit.kilogram.name
        ? ItemUnit.kilogram
        : ItemUnit.piece;
    final Object? differenceReason = entry['differenceReason'];
    lines.add(
      StocktakeCardLine(
        itemKey: itemKey,
        itemName: itemName is String && itemName.isNotEmpty ? itemName : itemKey,
        bookBalance: _quantityOf(entry['bookBalance'], unit) ??
            StockQuantity.zeroOf(unit),
        // ★★ **وغيابُ العدّ حالةٌ مشروعة** — ⟵ **المسوّدةُ قبل الاعتماد**:
        //   ⛔ **ولا يُسَدّ بصفرٍ يُقرأ «عُدَّ فلم يوجد شيء».**
        actualCount: _quantityOf(entry['actualCount'], unit),
        difference: _quantityOf(entry['difference'], unit),
        differenceReason:
            differenceReason is String && differenceReason.isNotEmpty
                ? differenceReason
                : null,
      ),
    );
  }
  return lines;
}

/// ★ كميةٌ مقروءة — و`null` **للحقل الغائب** ⛔ **لا صفرٌ يُختلَق**.
StockQuantity? _quantityOf(Object? raw, ItemUnit unit) {
  if (raw is! num) return null;
  return switch (unit) {
    // ⛔ **والحبّةُ عددٌ صحيح** — `BR-M6-06`.
    ItemUnit.piece => PieceQuantity(PieceCount(raw.round())),
    ItemUnit.kilogram => WeightQuantity(WeightKg(raw.toDouble())),
  };
}

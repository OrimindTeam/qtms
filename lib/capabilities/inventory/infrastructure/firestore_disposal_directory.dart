/// دليلُ الإتلاف — **قراءةً فقط** (`ADR-0013` القاعدة 4 · `WU-020`).
///
/// ⛔★★ **ولا كتابة واحدة هنا:** `disposals` **`allow create, update: if false`**
/// — ★ **والكاتبُ الوحيد العمليةُ المستدعاة** (`functions/lib/src/disposal.dart`).
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **والاستعلامُ مقيَّدٌ بالمصدر إلزاماً** — ★ **شرطُ القراءة يعتمد
/// `resource.data.sourceId`** (`storedInScope()`)، ⟵ **والسردُ يُقيَّم على
/// قيود الاستعلام لا على كل مستند**: ⟹ ⛔ **فاستعلامٌ لا يُقيّده يُرفَض
/// كاملاً ولو ملك القارئُ نطاقاً شاملاً** (`IQ-024` · `DEBT-40` · `WU-016`).
///
/// ⚠️ **والرفضُ يصل خطأً في التدفّق لا قائمةً فارغة** — ⟵ ★ **فتُميِّز
/// الشاشة بين «لا إتلاف» و«ممنوعٌ من الرؤية»** (`RISK-02`).
/// ═══════════════════════════════════════════════════════════════════════
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qtms_domain/qtms_domain.dart';

/// الدليل الحقيقي.
final class FirestoreDisposalDirectory implements DisposalDirectory {
  /// ينشئ الدليل.
  const FirestoreDisposalDirectory(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Stream<List<DisposalCard>> watchDisposals({
    required String sourceId,
    int limit = 100,
  }) =>
      _firestore
          .collection(disposalsCollection)
          .where('sourceId', isEqualTo: sourceId)
          // ★ **الفهرس: `sourceId ↑ · stockDate ↓`** — `indexing-strategy.md`
          //   §3 القاعدة 1 (**يبدأ بالمصدر وينتهي بتاريخ المخزون**).
          .orderBy('stockDate', descending: true)
          .limit(limit)
          .snapshots()
          .map(
            (QuerySnapshot<Map<String, dynamic>> snapshot) => <DisposalCard>[
              for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
                  in snapshot.docs)
                if (disposalCardOf(doc.id, doc.data()) case final DisposalCard card)
                  card,
            ],
          );
}

/// ★★ يقرأ بطاقةَ الإتلاف من حقولها — و`null` **لمستندٍ مشوَّه**.
///
/// ⚠️ **والمشوَّهُ يُتخطّى ولا يُسقِط الشاشة** — ⛔ **ولا يُسدّ نقصُه بقيمةٍ
/// مُولَّدة**: ★ **كميةٌ مخترَعةٌ تُري المستخدم إتلافاً لم يقع.**
DisposalCard? disposalCardOf(String id, Map<String, dynamic> data) {
  final Object? sourceId = data['sourceId'];
  final Object? stockDate = data['stockDate'];
  if (sourceId is! String || sourceId.isEmpty) return null;
  if (stockDate is! Timestamp) return null;

  final Object? sourceName = data['sourceName'];
  final Object? reason = data['reason'];
  final Object? cancelReason = data['cancelReason'];
  final Object? amendCount = data['amendCount'];
  final Object? documentNumber = data['documentNumber'];

  return DisposalCard(
    documentNumber:
        documentNumber is String && documentNumber.isNotEmpty ? documentNumber : id,
    stockDate: CalendarDay.fromUtc(stockDate.toDate().toUtc()),
    sourceId: sourceId,
    sourceName:
        sourceName is String && sourceName.isNotEmpty ? sourceName : null,
    // ★ **الحالةُ من الحقل المخزَّن** — ⛔ **ولا تُستنتَج من وجود سببِ إلغاء.**
    isCancelled: data['status'] == DisposalStatus.cancelled.name,
    reason: reason is String && reason.isNotEmpty ? reason : null,
    cancelReason:
        cancelReason is String && cancelReason.isNotEmpty ? cancelReason : null,
    amendCount: amendCount is int ? amendCount : 0,
    lines: _linesOf(data['lines']),
  );
}

List<DisposalCardLine> _linesOf(Object? raw) {
  if (raw is! List<Object?>) return const <DisposalCardLine>[];
  final List<DisposalCardLine> lines = <DisposalCardLine>[];
  for (final Object? entry in raw) {
    if (entry is! Map<String, Object?>) continue;
    final Object? itemId = entry['itemId'] ?? entry['itemKey'];
    if (itemId is! String || itemId.isEmpty) continue;
    final Object? itemName = entry['itemName'];
    // ★ **الوحدةُ من المستند** — ⛔ **ولا تُستنتَج من شكل الرقم**: ⟵ **حبّةٌ
    //   عددُها 3 ووزنٌ قدرُه 3.000 كجم يُكتبان `3` كلاهما** (`GR-19`).
    final ItemUnit unit = entry['unit'] == ItemUnit.kilogram.name
        ? ItemUnit.kilogram
        : ItemUnit.piece;
    final Object? quantity = entry['quantity'];
    final num value = quantity is num ? quantity : 0;
    final Object? sackId = entry['sackId'];
    lines.add(
      DisposalCardLine(
        itemKey: itemId,
        itemName: itemName is String && itemName.isNotEmpty ? itemName : itemId,
        quantity: switch (unit) {
          // ⛔ **والحبّةُ عددٌ صحيح** — `BR-M6-06`.
          ItemUnit.piece => PieceQuantity(PieceCount(value.toInt())),
          ItemUnit.kilogram => WeightQuantity(WeightKg(value.toDouble())),
        },
        sackId: sackId is String && sackId.isNotEmpty ? sackId : null,
      ),
    );
  }
  return lines;
}

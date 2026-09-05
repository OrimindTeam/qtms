/// دليلُ المتبقي المتأخر — **قراءةً فقط** (`ADR-0013` القاعدة 4 · `WU-019`).
///
/// ⛔★★ **ولا كتابة واحدة هنا:** `aged_remainders` **`allow write: if false`**
/// للجميع — ★ **والبندُ مشتقٌّ يكتبه راصدُ السحابة داخل معاملة الحركة**
/// (`functions/lib/src/aged_remainder.dart`).
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **والاستعلامُ مقيَّدٌ بالمصدر إلزاماً** — ★ **شرطُ القراءة يعتمد
/// `resource.data.sourceId`** (`storedInScope()`)، ⟵ **والسردُ يُقيَّم على
/// قيود الاستعلام لا على كل مستند**: ⟹ ⛔ **فاستعلامٌ لا يُقيّده يُرفَض
/// كاملاً ولو ملك القارئُ نطاقاً شاملاً** (`IQ-024` · `DEBT-40` · `WU-016`).
///
/// ★★ **والحدُّ الزمني `stockDate < اليوم` جزءٌ من الاستعلام لا مرشِّحُ عرض**
/// — ⟵ **فرصيدُ اليوم لا يُقرأ هنا أصلاً** (`FR-M8-05`: **شاشةُ مخزون اليوم
/// تعرضه**)، ⛔ **ولا يُجلَب ثم يُطرَح في الذاكرة**: ★ **القائمةُ تنمو مع
/// عمر الحساب، والحدُّ في الاستعلام هو ما يجعلها محدودةً فعلاً**
/// (`indexing-strategy.md` §4).
/// ═══════════════════════════════════════════════════════════════════════
///
/// ⚠️ **والرفضُ يصل خطأً في التدفّق لا قائمةً فارغة** — ⟵ ★ **فتُميِّز
/// الشاشة بين «لا متبقٍّ» و«ممنوعٌ من الرؤية»** (`RISK-02`).
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qtms_domain/qtms_domain.dart';

/// الدليل الحقيقي.
final class FirestoreAgedRemainderDirectory implements AgedRemainderDirectory {
  /// ينشئ الدليل.
  const FirestoreAgedRemainderDirectory(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Stream<List<AgedRemainderCard>> watchAgedRemainders({
    required String sourceId,
    required CalendarDay today,
  }) =>
      _firestore
          .collection(agedRemaindersCollection)
          .where('sourceId', isEqualTo: sourceId)
          // ★★ **تاريخ المخزون** — ⛔ **لا تاريخ الإدخال** (`RISK-07`).
          //   ★ **و«أقلّ من اليوم» تعريفُ «متأخر» حرفياً** (`FR-M8-09`).
          .where(
            'stockDate',
            isLessThan: Timestamp.fromDate(today.asUtcMidnight()),
          )
          // ★ **الفهرس: `sourceId ↑ · stockDate ↑`** — `indexing-strategy.md`
          //   §3 القاعدة 1 (**يبدأ بالمصدر وينتهي بتاريخ المخزون**).
          //   ⛔ **والترتيب في الفهرس هو ترتيب الاستعلام** (القاعدة 4).
          .orderBy('stockDate')
          .snapshots()
          .map(
            (QuerySnapshot<Map<String, dynamic>> snapshot) =>
                <AgedRemainderCard>[
              for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
                  in snapshot.docs)
                if (agedRemainderCardOf(doc.data()) case final AgedRemainderCard card)
                  card,
            ],
          );
}

/// ★★ يقرأ بطاقةَ البند من حقولها — و`null` **لمستندٍ مشوَّه**.
///
/// ⚠️ **والمشوَّهُ يُتخطّى ولا يُسقِط الشاشة** — ★ **البندُ *تنبيهٌ* لا حساب**
/// (`GR-16`): ⟵ **ومستندٌ واحدٌ ناقصُ حقلٍ لا يُخفي بقيةَ ما يحتاج إجراءً.**
/// ⛔ **ولا يُسدّ نقصُه بقيمةٍ مُولَّدة:** ★ **رصيدٌ مخترَعٌ يُطالِب بتصريف
/// ما لا وجود له.**
AgedRemainderCard? agedRemainderCardOf(Map<String, dynamic> data) {
  final Object? sourceId = data['sourceId'];
  final Object? itemKey = data['itemKey'];
  final Object? stockDate = data['stockDate'];
  if (sourceId is! String || sourceId.isEmpty) return null;
  if (itemKey is! String || itemKey.isEmpty) return null;
  if (stockDate is! Timestamp) return null;

  final Object? itemName = data['itemName'];
  // ★ **الوحدةُ من المستند** — ⛔ **ولا تُستنتَج من شكل الرقم**: ⟵ **حبّةٌ
  //   عددُها 3 ووزنٌ قدرُه 3.000 كجم يُكتبان `3` كلاهما** (`GR-19`).
  final ItemUnit unit =
      data['unit'] == ItemUnit.kilogram.name ? ItemUnit.kilogram : ItemUnit.piece;
  final Object? remaining = data['remaining'];
  final num value = remaining is num ? remaining : 0;

  return AgedRemainderCard(
    sourceId: sourceId,
    itemKey: itemKey,
    itemName: itemName is String && itemName.isNotEmpty ? itemName : itemKey,
    stockDate: CalendarDay.fromUtc(stockDate.toDate().toUtc()),
    remaining: switch (unit) {
      // ⛔ **والحبّةُ عددٌ صحيح** — `BR-M6-06`: ⟵ **والكسرُ يُقتطَع لا يُقرَّب**،
      //   ★ **فلا يُعرَض متبقٍّ أكبرُ من الرصيد الفعلي.**
      ItemUnit.piece => PieceQuantity(PieceCount(value.toInt())),
      ItemUnit.kilogram => WeightQuantity(WeightKg(value.toDouble())),
    },
  );
}

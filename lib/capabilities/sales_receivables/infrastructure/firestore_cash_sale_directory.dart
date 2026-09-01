/// دليل البيع النقدي — **قراءةً فقط** (`ADR-0013` القاعدة 4).
///
/// ⛔★★ **ولا كتابة واحدة هنا:** `cash_sales` **`allow create, update: if
/// false`** — **والكتابة عبر العمليات المستدعاة**
/// (`functions_cash_sale_repository.dart`).
///
/// ⛔⛔★★★ **واستعلامٌ مقيَّدٌ بالمصدر واليوم دائماً** — ★ **شرطُ القراءة
/// `isSignedIn() && storedInScope()` يقرأ `resource.data.sourceId`**، ⟵ **والشرط
/// يُقيَّم على قيود الاستعلام لا على كل مستند** (`IQ-024` · `WU-008`):
/// ⛔ **فاستعلامٌ لا يُقيّد `sourceId` يُرفَض كاملاً ولو بنطاقٍ شامل.**
///
/// ⛔⛔★★ **ولا قارئَ بالمعرّف هنا** — ★ **بنفس علّة `DEBT-40`**: قراءةُ
/// `cash_sales/{رقم}` **تُرفَض ما دام المستند غائباً** لأن شرطها يعتمد
/// `resource.data`، ⟵ **والوجودُ يُستنتَج من قائمة اليوم المقيَّدة.**
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qtms_domain/qtms_domain.dart';

/// الدليل الحقيقي.
final class FirestoreCashSaleDirectory implements CashSaleDirectory {
  /// ينشئ الدليل.
  const FirestoreCashSaleDirectory(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Stream<List<CashSaleCard>> watchCashSales({
    required String sourceId,
    required CalendarDay stockDate,
  }) =>
      _firestore
          .collection(cashSalesCollection)
          .where('sourceId', isEqualTo: sourceId)
          // ★★ **يومٌ واحد** — ⛔ **ولا يُجمع يومان** (`RISK-07`).
          //    ★ **والفهرس المعتمد `sourceId ↑ · stockDate ↓`.**
          .where(
            'stockDate',
            isEqualTo: Timestamp.fromDate(stockDate.asUtcMidnight()),
          )
          .snapshots()
          .map((QuerySnapshot<Map<String, dynamic>> snapshot) {
            final List<CashSaleCard> cards = <CashSaleCard>[
              for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
                  in snapshot.docs)
                cardOf(doc.id, doc.data(), stockDate),
            ];
            // ★ **مرتَّبةً برقم المستند** — ⟵ **فترتيب الشاشة ثابت**،
            //   ⛔ **ولا يقفز صفٌّ بتعديل كميته.**
            cards.sort(
              (CashSaleCard a, CashSaleCard b) =>
                  a.documentNumber.compareTo(b.documentNumber),
            );
            return cards;
          });

  // ═════════════════════════════════════════════════════════════════════
  // التحويل — ⛔ **والمجهول يُقرأ بالافتراض الآمن لا يُسقِط الشاشة**
  // ═════════════════════════════════════════════════════════════════════

  /// ★ يحوّل مستند سندٍ خاماً إلى بطاقته.
  ///
  /// ⛔★★ **ولا `as int` عارية** — ★ **درسُ `DEBT-24`**: **لا يُفترَض شكلُ
  /// مخرجات مكتبة، يُقاس** — ⟵ **والحقل الغائب يُقرأ صفراً لا يُسقِط الشاشة.**
  static CashSaleCard cardOf(
    String id,
    Map<String, dynamic> data,
    CalendarDay fallbackDate,
  ) {
    final Object? rawLines = data['lines'];
    final List<ValidatedCashSaleLine> lines = <ValidatedCashSaleLine>[
      if (rawLines is List<dynamic>)
        for (final dynamic raw in rawLines)
          if (raw is Map<String, dynamic>) _lineOf(raw),
    ];
    return CashSaleCard(
      documentNumber: data['documentNumber'] as String? ?? id,
      sourceId: data['sourceId'] as String? ?? '',
      sourceName: data['sourceName'] as String?,
      stockDate: _dayOf(data['stockDate']) ?? fallbackDate,
      entryDate: _dateOf(data['entryDate']) ?? DateTime.now().toUtc(),
      // ★ **والملغى صراحةً وحده ملغى** — ⛔ **والافتراض الآمن «سندٌ حيّ»**.
      status: data['status'] == CashSaleStatus.cancelled.name
          ? CashSaleStatus.cancelled
          : CashSaleStatus.approved,
      totalPieces: PieceCount(_int(data['totalPieces']) ?? 0),
      totalWeight: WeightKg(_double(data['totalWeight']) ?? 0),
      netCashReceived: Money(_int(data['netCashReceived']) ?? 0),
      lines: lines,
      notes: data['notes'] as String?,
      cancelReason: data['cancelReason'] as String?,
      amendCount: _int(data['amendCount']) ?? 0,
    );
  }

  static ValidatedCashSaleLine _lineOf(Map<String, dynamic> raw) {
    final ItemUnit unit = raw['unit'] == ItemUnit.kilogram.name
        ? ItemUnit.kilogram
        : ItemUnit.piece;
    final Object? quantity = raw['quantity'];
    return ValidatedCashSaleLine(
      itemId: raw['itemId'] as String? ?? '',
      itemName: raw['itemName'] as String? ?? '',
      quantity: switch (unit) {
        ItemUnit.piece => PieceQuantity(PieceCount(_int(quantity) ?? 0)),
        ItemUnit.kilogram => WeightQuantity(WeightKg(_double(quantity) ?? 0)),
      },
      unitPrice: Money(_int(raw['unitPrice']) ?? 0),
      sackId: raw['sackId'] as String?,
      belowMinReason: raw['belowMinReason'] as String?,
    );
  }

  static int? _int(Object? value) => switch (value) {
        final int value => value,
        final double value when value == value.roundToDouble() => value.toInt(),
        final num value => value.round(),
        _ => null,
      };

  static double? _double(Object? value) =>
      value is num ? value.toDouble() : null;

  static DateTime? _dateOf(Object? value) => switch (value) {
        final Timestamp value => value.toDate().toUtc(),
        final DateTime value => value.toUtc(),
        _ => null,
      };

  static CalendarDay? _dayOf(Object? value) {
    final DateTime? date = _dateOf(value);
    return date == null ? null : CalendarDay.fromUtc(date);
  }
}

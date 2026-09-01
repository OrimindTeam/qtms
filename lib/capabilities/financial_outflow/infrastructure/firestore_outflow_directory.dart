/// دليل السحبيات والخرجيات — **قراءةً فقط** (`ADR-0013` القاعدة 4).
///
/// ⛔★★ **ولا كتابة واحدة هنا:** `outflows` **`allow create, update: if
/// false`** — **والكتابة عبر العمليات المستدعاة**
/// (`functions_outflow_repository.dart`).
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **وكلُّ استعلامٍ يُقيّد الحقلَ الذي يعتمده شرطُ قراءته** —
/// **مقيسٌ ثلاث مرات في هذا المشروع** (`IQ-024` · `WU-008` · `DEBT-40`):
/// ⟵ **الشرط يُقيَّم على قيود الاستعلام لا على كل مستند**، ⛔ **فاستعلامٌ لا
/// يُقيّده يُرفَض كاملاً ولو بنطاقٍ شامل.**
///
/// ★★★ **وهنا حقلان لا حقلٌ واحد** — ⟵ **وهو ما يجعل هذه الوحدة أشدَّ من
/// سابقاتها**: شرطُ `outflows` يقرأ **`resource.data.sourceId`** (عبر
/// `storedInScope()`) **و`resource.data.ledgerType`** معاً:
///
/// ```javascript
/// allow read: if isSignedIn() && storedInScope()
///             && (isWithdrawal() ? perm('withdrawalView')
///                                : perm('expenseView'));
/// ```
///
/// ⟵ **فالاستعلام يُقيّدهما كليهما** ⛔ **ولا واحدٌ منهما**، ★ **والفهرس
/// `sourceId ↑ · ledgerType ↑ · documentDate ↓` قائمٌ لهذا بالضبط**
/// (`schema/outflow-ledger.md` · `firestore.indexes.json`).
/// ═══════════════════════════════════════════════════════════════════════
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qtms_domain/qtms_domain.dart';

/// الدليل الحقيقي.
final class FirestoreOutflowDirectory implements OutflowDirectory {
  /// ينشئ الدليل.
  const FirestoreOutflowDirectory(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Stream<List<OutflowCard>> watchOutflows({
    required String sourceId,
    required OutflowLedgerType ledgerType,
    int limit = 50,
  }) =>
      _firestore
          .collection(outflowsCollection)
          // ★★★ **الحقلان معاً** — راجع ترويسة الملف.
          .where('sourceId', isEqualTo: sourceId)
          .where('ledgerType', isEqualTo: ledgerType.name)
          .orderBy('documentDate', descending: true)
          .limit(limit)
          .snapshots()
          .map(
            (QuerySnapshot<Map<String, dynamic>> snapshot) => <OutflowCard>[
              for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
                  in snapshot.docs)
                cardOf(doc.id, doc.data()),
            ],
          );

  // ═════════════════════════════════════════════════════════════════════
  // التحويل — ⛔ **والمجهول يُقرأ بالافتراض الآمن لا يُسقِط الشاشة**
  // ═════════════════════════════════════════════════════════════════════

  /// ★ يحوّل مستند سحبيةٍ أو خرجيةٍ خاماً إلى بطاقته.
  ///
  /// ★★ **ومكشوفٌ لأن تقارير المرحلة الثانية تقرأ المجموعةَ نفسَها**
  /// (`WU-018` · `R-21`…`R-24`) — ⛔ **ونسخةٌ ثانية تفترق عند أول حقل.**
  static OutflowCard cardOf(String id, Map<String, dynamic> data) {
    final OutflowLedgerType ledgerType = _ledgerTypeOf(data['ledgerType']);
    // ⛔⛔★★★ **ومصفوفةٌ واحدة `lines[]` بحقل `itemType`** — ★ **وهو نصُّ
    //    `data-dictionary.md` §`outflows`**: ⟵ **والفصلُ يقع هنا عند
    //    القراءة** ⛔ **لا في المخزَّن.**
    final Object? rawLines = data['lines'];
    final List<Map<String, dynamic>> lines = <Map<String, dynamic>>[
      if (rawLines is List<dynamic>)
        for (final Object? entry in rawLines)
          if (entry is Map<String, dynamic>) entry,
    ];

    return OutflowCard(
      documentNumber: data['documentNumber'] as String? ?? id,
      ledgerType: ledgerType,
      category: _categoryOf(data['category'], ledgerType),
      // ★★ **تاريخان مستقلان** — `GR-49`: ⛔ **ولا يُشتقّ أحدهما من الآخر.**
      date: _dayOf(data['documentDate']) ?? CalendarDay(1970, 1, 1),
      stockDate: _dayOf(data['stockDate']) ?? CalendarDay(1970, 1, 1),
      sourceId: data['sourceId'] as String? ?? '',
      sourceName: data['sourceName'] as String?,
      qatLines: <OutflowCardQatLine>[
        for (final Map<String, dynamic> entry in lines)
          if (entry['itemType'] == OutflowLineKind.qat.name)
            if (entry['itemId'] case final String itemId)
              OutflowCardQatLine(
                itemKey: itemId,
                itemName: entry['itemName'] as String? ?? itemId,
                quantity: _quantityOf(entry['quantity'], entry['unit']),
                // ⛔⛔ **والغائبُ `null` لا صفر** — `FR-M22-07`:
                //    ⟵ **فالشاشة تعرض «⏳ لم يُسعَّر» لا «0».**
                unitPrice: _moneyOf(entry['unitPrice']),
                lineValue: _moneyOf(entry['lineValue']),
                sackId: entry['sackId'] as String?,
              ),
      ],
      cashLines: <OutflowCardCashLine>[
        for (final Map<String, dynamic> entry in lines)
          if (entry['itemType'] != OutflowLineKind.qat.name)
            OutflowCardCashLine(
              kind: _lineKindOf(entry['itemType']),
              amount: Money(_intOf(entry['amount']) ?? 0),
              description: entry['description'] as String?,
            ),
      ],
      totalQatValue: Money(_intOf(data['totalQatValue']) ?? 0),
      totalCashValue: Money(_intOf(data['totalCashValue']) ?? 0),
      grandTotal: Money(_intOf(data['grandTotal']) ?? 0),
      unpricedItemCount: _intOf(data['unpricedItemCount']) ?? 0,
      notes: data['notes'] as String?,
      // ⛔ **والملغى صراحةً وحده ملغى** — ★ **والافتراض الآمن «سندٌ حيّ».**
      isCancelled: data['status'] == 'cancelled',
      cancelReason: data['cancelReason'] as String?,
      amendCount: _intOf(data['amendCount']) ?? 0,
    );
  }

  /// ⛔⛔★★ **والمجهول يُقرأ «خرجية» عمداً** — ⛔ **لا «سحبية»:**
  /// ⟵ **فالسحبيات هي السجلُّ الحسّاس** (`GR-43`)، ★ **ومستندٌ بحقلٍ مشوَّه
  /// لا يُعرَض في قائمة السحبيات بالخطأ.** ⚠️ **وهذا عرضٌ لا حماية** —
  /// ★ **والحمايةُ في القاعدة نفسِها** (`resource.data.ledgerType`).
  static OutflowLedgerType _ledgerTypeOf(Object? raw) =>
      raw == OutflowLedgerType.withdrawal.name
          ? OutflowLedgerType.withdrawal
          : OutflowLedgerType.expense;

  static OutflowCategory _categoryOf(Object? raw, OutflowLedgerType ledger) {
    for (final OutflowCategory category in OutflowCategory.values) {
      if (category.name == raw) return category;
    }
    // ★ **وفئةٌ مجهولةٌ تسقط إلى «أخرى» في سجلِّها** — ⛔ **ولا تعبر السجلَّين.**
    return ledger == OutflowLedgerType.withdrawal
        ? OutflowCategory.withdrawalOther
        : OutflowCategory.expenseOperating;
  }

  static OutflowLineKind _lineKindOf(Object? raw) =>
      raw == OutflowLineKind.other.name
          ? OutflowLineKind.other
          : OutflowLineKind.amount;

  /// ★ الكمية بوحدتها المخزَّنة — `GR-19`.
  static StockQuantity _quantityOf(Object? raw, Object? unit) {
    if (unit == ItemUnit.kilogram.name) {
      return WeightQuantity(WeightKg((raw as num?)?.toDouble() ?? 0));
    }
    return PieceQuantity(PieceCount(_intOf(raw) ?? 0));
  }

  static Money? _moneyOf(Object? raw) {
    final int? value = _intOf(raw);
    return value == null ? null : Money(value);
  }

  static CalendarDay? _dayOf(Object? raw) {
    if (raw is Timestamp) return CalendarDay.fromUtc(raw.toDate().toUtc());
    if (raw is DateTime) return CalendarDay.fromUtc(raw.toUtc());
    return null;
  }

  static int? _intOf(Object? raw) {
    if (raw is int) return raw;
    if (raw is num && raw == raw.roundToDouble()) return raw.toInt();
    return null;
  }
}

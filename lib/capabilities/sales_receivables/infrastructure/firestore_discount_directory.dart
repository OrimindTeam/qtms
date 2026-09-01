/// دليل الخصومات والضمارات المفتوحة — **قراءةً فقط** (`ADR-0013` القاعدة 4).
///
/// ⛔★★ **ولا كتابة واحدة هنا:** `discounts` **`allow create, update: if
/// false`** — **والكتابة عبر العمليات المستدعاة**
/// (`functions_discount_repository.dart`).
///
/// ⛔⛔★★★ **وتدفّقٌ واحد للسند لا اثنان — وهذا فارقُه عن سند القبض:**
/// ★ **لا `deposit/current` هنا ولا شرطَ قراءةٍ ثانٍ** (`FR-M13` §2)،
/// ⟵ **لا نقدَ دخل فلا شيءَ يُودَع.**
///
/// ⛔⛔★★★ **وكلُّ استعلامٍ يُقيّد الحقلَ الذي يعتمده شرطُ قراءته** —
/// **مقيسٌ ثلاث مرات في هذا المشروع** (`IQ-024` · `WU-008` · `DEBT-40`):
/// ⟵ **الشرط يُقيَّم على قيود الاستعلام لا على كل مستند**، ⛔ **فاستعلامٌ
/// لا يُقيّده يُرفَض كاملاً ولو بنطاقٍ شامل.**
///
/// ⚠️⚠️ **وقراءةُ الضمارات المفتوحة هنا هي قراءةُ `FirestoreReceiptDirectory`
/// نفسُها** — ★ **وتُفوَّض إليها صراحةً** (`coding-standards.md` §2.2):
/// ⟵ **فاستعلامٌ ثانٍ بنفس القيود كان سيفترق عنها عند أول تغيير في الفهرس
/// أو في شرط الحالة**، ⛔ **وهو استعلامٌ حرسُه `storedInScope()`.**
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qtms_domain/qtms_domain.dart';

import 'firestore_receipt_directory.dart';

/// الدليل الحقيقي.
final class FirestoreDiscountDirectory implements DiscountDirectory {
  /// ينشئ الدليل.
  FirestoreDiscountDirectory(this._firestore)
      : _lots = FirestoreReceiptDirectory(_firestore);

  final FirebaseFirestore _firestore;

  /// ★★ **دليلُ القبض نفسُه لقراءة الضمارات المفتوحة** — ⛔ **لا نسخةٌ ثانية**.
  ///
  /// ⚠️ **ولا يعني هذا أن الخصم «قبضٌ»** — ★ **الضمارُ المفتوح مفهومٌ واحد
  /// يخصّ التوزيع لا التسوية**: ⟵ **والمسارُ الذي يقرؤه واحدٌ لكليهما**،
  /// ⛔ **والذي يفترق هو ما يُكتَب بعده** (`FR-M15-06-أ`).
  final FirestoreReceiptDirectory _lots;

  @override
  Stream<List<OpenDebtLot>> watchOpenDebtLots({
    required String dealerId,
    required List<String> sourceIds,
  }) =>
      _lots.watchOpenDebtLots(dealerId: dealerId, sourceIds: sourceIds);

  @override
  Stream<List<DiscountCard>> watchDiscounts({
    required String dealerId,
    int limit = 50,
  }) =>
      _firestore
          .collection(discountsCollection)
          // ★ **الفهرس المعتمد `dealerId ↑ · date ↓`** (`schema/discounts.md`).
          .where('dealerId', isEqualTo: dealerId)
          .orderBy('date', descending: true)
          .limit(limit)
          .snapshots()
          .map(
            (QuerySnapshot<Map<String, dynamic>> snapshot) => <DiscountCard>[
              for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
                  in snapshot.docs)
                cardOf(doc.id, doc.data()),
            ],
          );

  // ═════════════════════════════════════════════════════════════════════
  // التحويل — ⛔ **والمجهول يُقرأ بالافتراض الآمن لا يُسقِط الشاشة**
  // ═════════════════════════════════════════════════════════════════════

  /// ★ يحوّل مستند سندِ خصمٍ خاماً إلى بطاقته.
  ///
  /// ★★ **ومكشوفٌ لأن تقارير المرحلة الثانية تقرأ المجموعةَ نفسَها**
  /// (`WU-018`) — ⛔ **ونسخةٌ ثانية تفترق عند أول حقل.**
  ///
  /// ⛔⛔★★★ **ولا يقرأ `surplusAmount` ولا `surplusScope` إطلاقاً** —
  /// ★ **فلا وجودَ لهما في المخطَّط** (`schema/discounts.md`): ⟵ **وقراءةُ
  /// حقلٍ غائبٍ «احتياطاً» كانت تُثبِّت في الكود توقّعَ وجوده.**
  static DiscountCard cardOf(String id, Map<String, dynamic> data) {
    final Object? rawLines = data['lines'];
    final List<DiscountCardLine> lines = <DiscountCardLine>[
      if (rawLines is List<dynamic>)
        for (final Object? entry in rawLines)
          if (entry is Map<String, dynamic>)
            if (entry['debtLotId'] case final String lotId)
              DiscountCardLine(
                debtLotId: lotId,
                sourceId: entry['sourceId'] as String? ?? '',
                remainingBefore: Money(_intOf(entry['remainingBefore']) ?? 0),
                amount: Money(_intOf(entry['amount']) ?? 0),
                remainingAfter: Money(_intOf(entry['remainingAfter']) ?? 0),
                note: entry['note'] as String?,
              ),
    ];
    final Object? rawSources = data['affectedSourceIds'];
    return DiscountCard(
      documentNumber: data['documentNumber'] as String? ?? id,
      date: _dayOf(data['date']) ?? CalendarDay(1970, 1, 1),
      dealerId: data['dealerId'] as String? ?? '',
      dealerName: data['dealerName'] as String? ?? '',
      sourceFilter: data['sourceFilter'] as String?,
      affectedSourceIds: <String>[
        if (rawSources is List<dynamic>)
          for (final Object? source in rawSources)
            if (source is String) source,
      ],
      lines: lines,
      totalDebtAtEntry: Money(_intOf(data['totalDebtAtEntry']) ?? 0),
      usedAutoAllocation: data['usedAutoAllocation'] == true,
      // ⛔ **والملغى صراحةً وحده ملغى** — ★ **والافتراض الآمن «سندٌ حيّ»**:
      //   ⟵ **قراءةُ سندٍ حيٍّ ملغىً كانت تُخفي ديناً أُسقِط فعلاً.**
      isCancelled: data['status'] == 'cancelled',
      cancelReason: data['cancelReason'] as String?,
      amendCount: _intOf(data['amendCount']) ?? 0,
    );
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

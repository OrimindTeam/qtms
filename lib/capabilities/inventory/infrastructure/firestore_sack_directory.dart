/// دليل الجواني — **قراءةً فقط** (`ADR-0013` القاعدة 4).
///
/// ⛔★★ **ولا كتابة واحدة هنا:** `sacks` و`sacks/{id}/finance` **مغلقتان في
/// القواعد** — **والكتابة عبر العمليات المستدعاة**
/// (`functions_sack_repository.dart`).
///
/// ★★★ **وتدفّقان لا واحد — وهو نصّ `ADR-0011`:** شرطُ قراءة المستند
/// (`sackView`) **مستقلٌّ عن شرط قراءة ماليته** (`sackFinanceView`).
/// ⟵ ★ **فدمجُهما في تدفّقٍ واحد كان يُسقِط الشاشة كلها لمن يملك الأول
/// وحده**، ⛔ **بينما المقصود أن يرى الجونية بلا ماليتها.**
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qtms_domain/qtms_domain.dart';

/// الدليل الحقيقي.
final class FirestoreSackDirectory implements SackDirectory {
  /// ينشئ الدليل.
  const FirestoreSackDirectory(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Stream<List<SackCard>> watchSacks({
    required String sourceId,
    required CalendarDay stockDate,
  }) =>
      _firestore
          .collection(sacksCollection)
          .where('sourceId', isEqualTo: sourceId)
          // ★★ **تاريخ المخزون لا تاريخ الإدخال** — `RISK-07`.
          .where(
            'stockDate',
            isEqualTo: Timestamp.fromDate(stockDate.asUtcMidnight()),
          )
          .snapshots()
          .map((QuerySnapshot<Map<String, dynamic>> snapshot) {
            final List<SackCard> cards = <SackCard>[
              for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
                  in snapshot.docs)
                _sackOf(doc.id, doc.data(), stockDate),
            ];
            // ★ **بالرقم المتسلسل اليومي** — ⟵ **فهو ترتيب الإنشاء داخل
            //   المصدر بلا فهرس**، ⛔ **ولا يتغيّر بتغيّر الاسم الظاهر.**
            cards.sort(
              (SackCard a, SackCard b) =>
                  a.dailySequence.compareTo(b.dailySequence),
            );
            return cards;
          });

  @override
  Stream<SackFinanceCard?> watchSackFinance({required String sackId}) =>
      _firestore
          .collection(sacksCollection)
          .doc(sackId)
          .collection(sackFinanceSubcollection)
          .doc(sackFinanceDocumentId)
          .snapshots()
          .map(
            (DocumentSnapshot<Map<String, dynamic>> doc) =>
                doc.exists ? _financeOf(sackId, doc.data()) : null,
          )
          // ⚠️⚠️ **ورفضُ القراءة يُطوى في `null` هنا وحده** — ★ **وهو
          //    الموضع الوحيد المشروع لذلك في هذه الزيادة:** من لا يملك
          //    `sackFinanceView` **لا يُفترَض به أن يرى شيئاً**، ⟵ **ورسالةُ
          //    فشلٍ كانت ستُخبره بوجود بياناتٍ مُنع منها** ⛔ **وهي نفسها
          //    تسريبُ وجودٍ يمنعه `ADR-0011`.**
          //    ★ **وبقيةُ التدفقات تُمرِّر الخطأ كما هو** (`RISK-02`).
          .handleError(
            (Object _) {},
            test: (dynamic error) => error is FirebaseException,
          );

  // ═════════════════════════════════════════════════════════════════════
  // التحويل — ⛔ **والمجهول يُقرأ بالافتراض الآمن لا يُسقِط الشاشة**
  // ═════════════════════════════════════════════════════════════════════

  static SackCard _sackOf(
    String id,
    Map<String, dynamic> data,
    CalendarDay fallbackDay,
  ) {
    final int dailySequence = _int(data['dailySequence']) ?? 1;
    final ValidatedSackWeights weights = ValidatedSackWeights(
      totalWeight: WeightKg(_double(data['totalWeight']) ?? 0),
      iceWeight: WeightKg(_double(data['iceWeight']) ?? 0),
      scrapWeight: WeightKg(_double(data['scrapWeight']) ?? 0),
    );
    final List<ValidatedSackLine> lines = _linesOf(data['lines']);

    return SackCard(
      documentNumber: _text(data['documentNumber']) ?? id,
      sourceId: _text(data['sourceId']) ?? '',
      stockDate: _dayOf(data['stockDate']) ?? fallbackDay,
      entryDate: _instant(data['entryDate']) ?? DateTime.utc(1970),
      dailySequence: dailySequence,
      displayName: _text(data['displayName']) ??
          sackDisplayName(dailySequence: dailySequence),
      status: data['status'] == SackStatus.cancelled.name
          ? SackStatus.cancelled
          : SackStatus.approved,
      weights: weights,
      // ★★ **والحاسبة من طبقة النطاق لا من القيم المخزَّنة** —
      //    `coding-standards.md` §2.2: ⟵ **فرقمُ الشاشة هو رقمُ السحابة
      //    حرفياً**، ⛔ **ولا نسخةٌ ثانية من المعادلة تفترق عند أول تعديل.**
      explanation: explainSackWeight(
        weights: weights,
        lines: lines,
        lostWeightConfirmed: data['lostWeightConfirmed'] == true,
      ),
      lostWeightConfirmed: data['lostWeightConfirmed'] == true,
      lines: lines,
      supplierId: _text(data['supplierId']),
      supplierName: _text(data['supplierName']),
      scrapItemKey: _text(data['scrapItemKey']),
      notes: _text(data['notes']),
      lostWeightNote: _text(data['lostWeightNote']),
      cancelReason: _text(data['cancelReason']),
      isPricingComplete: data['isPricingComplete'] == true,
      amendCount: _int(data['amendCount']) ?? 0,
    );
  }

  static SackFinanceCard _financeOf(String sackId, Map<String, dynamic>? data) =>
      SackFinanceCard(
        sackId: sackId,
        sourceId: _text(data?['sourceId']) ?? '',
        // ⛔★ **و`null` تعني «معلّقة» لا صفراً** (`FR-M7-10`) — ★ **وهي
        //    مصدر بند المركز المعلّق**، ⟵ **وطيُّها في صفرٍ يُسقِط البند.**
        taxPerKilo: _money(data?['taxPerKilo']),
        sackTax: _money(data?['sackTax']),
        sackRevenue: _money(data?['sackRevenue']),
        supplierNet: _money(data?['supplierNet']),
      );

  /// ★ سطور المستند — ⛔ **بقيمها المخزَّنة لا بإعادة اشتقاقها**.
  ///
  /// ⚠️ **`pieceWeightGrams` و`lineTotalWeight` مُجمَّدان لحظة الحفظ**
  /// (`FR-M7-15` · `ADR-0007` القاعدة 4) — ⟵ **وإعادةُ اشتقاقهما في
  /// الشاشة كانت تُظهِر أرقاماً غير التي كُتبت.**
  static List<ValidatedSackLine> _linesOf(Object? raw) {
    if (raw is! List<dynamic>) return const <ValidatedSackLine>[];
    final List<ValidatedSackLine> lines = <ValidatedSackLine>[];
    for (final Object? entry in raw) {
      if (entry is! Map<dynamic, dynamic>) continue;
      final String? itemId = _text(entry['itemId']);
      if (itemId == null) continue;
      lines.add(
        ValidatedSackLine(
          itemId: itemId,
          itemName: _text(entry['itemName']) ?? itemId,
          nature: entry['nature'] == ItemNature.countBased.name
              ? ItemNature.countBased
              : ItemNature.weightBased,
          unit: entry['unit'] == ItemUnit.kilogram.name
              ? ItemUnit.kilogram
              : ItemUnit.piece,
          quantity: PieceCount(_int(entry['quantity']) ?? 0),
          pieceWeightGrams: _double(entry['pieceWeightGrams']) ?? 0,
          pieceWeightOrigin: _originOf(entry['pieceWeightOrigin']),
          lineTotalWeight: WeightKg(_double(entry['lineTotalWeight']) ?? 0),
          distributionPrice: _money(entry['distributionPrice']),
          minCashPrice: _money(entry['minCashPrice']),
          note: _text(entry['note']),
        ),
      );
    }
    return lines;
  }

  static PieceWeightOrigin _originOf(Object? raw) {
    for (final PieceWeightOrigin origin in PieceWeightOrigin.values) {
      if (origin.name == raw) return origin;
    }
    // ⛔ **والمجهول «يدوي»** — ★ **الافتراض الآمن**: ⟵ **وسمُه «تهيئةً»
    //   يدّعي مصدراً لم يُقرأ، و«مستنتَجاً» يدّعي اشتقاقاً لم يقع.**
    return PieceWeightOrigin.manual;
  }

  static CalendarDay? _dayOf(Object? raw) {
    final DateTime? instant = _instant(raw);
    return instant == null ? null : CalendarDay.fromUtc(instant);
  }

  static DateTime? _instant(Object? raw) => switch (raw) {
        final Timestamp value => value.toDate().toUtc(),
        final DateTime value => value.toUtc(),
        _ => null,
      };

  static String? _text(Object? raw) {
    if (raw is! String) return null;
    final String trimmed = raw.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  /// ★ مبلغٌ مقروء أو `null` — ⛔ **والكسر ليس مبلغاً** (`ADR-0015`).
  static Money? _money(Object? raw) {
    final int? value = _int(raw);
    return value == null ? null : Money(value);
  }

  static int? _int(Object? raw) => switch (raw) {
        final int value => value,
        final double value when value == value.roundToDouble() => value.toInt(),
        _ => null,
      };

  static double? _double(Object? raw) => switch (raw) {
        final int value => value.toDouble(),
        final double value => value,
        _ => null,
      };
}

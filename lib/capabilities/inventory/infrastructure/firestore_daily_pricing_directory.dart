/// دليل التسعير اليومي — **قراءةً فقط** (`ADR-0013` القاعدة 4).
///
/// ⛔★★ **ولا كتابة واحدة هنا:** `daily_prices` **`allow create, update:
/// if false`** — **والكتابة عبر العملية المستدعاة**
/// (`functions_daily_pricing_repository.dart`).
///
/// ⚠️ **والرفض يصل كخطأ في التدفّق لا كقائمة فارغة** — ⟵ ★ **فتُميِّز
/// الشاشة بين «لا أسعار اليوم» و«ممنوعٌ من الرؤية»**.
///
/// ⚠️⚠️ **وغيابُ السجل «غير مسعَّر» لا «صفر»** — ⟵ **والشاشة تدمج هذه
/// القائمة بأرصدة اليوم** (`FR-M9-02`)، ⛔ **فلا يُبنى على غياب السجل أنّ
/// النوع غير موجود.**
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qtms_domain/qtms_domain.dart';

/// الدليل الحقيقي.
final class FirestoreDailyPricingDirectory implements DailyPricingDirectory {
  /// ينشئ الدليل.
  const FirestoreDailyPricingDirectory(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Stream<List<DailyPriceCard>> watchDailyPrices({
    required String sourceId,
    required CalendarDay date,
  }) =>
      _firestore
          .collection(dailyPricesCollection)
          .where('sourceId', isEqualTo: sourceId)
          // ★★ **يومٌ واحد** — `FR-M9-01` (`GR-31`): ⛔ **ولا يُرحَّل سعرُ
          //    أمس**، ★ **والتصفير أثرُ المفتاح لا شرطٌ يُكتب.**
          .where('date', isEqualTo: Timestamp.fromDate(date.asUtcMidnight()))
          // ★ الفهرس المعتمد: `sourceId ↑ · date ↑ · isPricingComplete ↑`.
          .snapshots()
          .map((QuerySnapshot<Map<String, dynamic>> snapshot) {
            final List<DailyPriceCard> cards = <DailyPriceCard>[
              for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
                  in snapshot.docs)
                _priceOf(doc.data(), date),
            ];
            // ★ **مرتَّبةً بمفتاح النوع** — ⟵ **فترتيب الشاشة ثابت**،
            //   ⛔ **ولا يقفز صفٌّ بتغيّر سعره.**
            cards.sort(
              (DailyPriceCard a, DailyPriceCard b) =>
                  a.itemKey.compareTo(b.itemKey),
            );
            return cards;
          });

  // ═════════════════════════════════════════════════════════════════════
  // التحويل — ⛔ **والمجهول يُقرأ بالافتراض الآمن لا يُسقِط الشاشة**
  // ═════════════════════════════════════════════════════════════════════

  static DailyPriceCard _priceOf(
    Map<String, dynamic> data,
    CalendarDay fallbackDay,
  ) =>
      DailyPriceCard(
        sourceId: _text(data['sourceId']) ?? '',
        itemKey: _text(data['itemKey']) ?? '',
        itemName: _text(data['itemName']) ?? _text(data['itemKey']) ?? '',
        unit: _unitOf(data['unit']),
        date: _dayOf(data['date']) ?? fallbackDay,
        // ⛔★★ **والغياب `null` لا صفر** — ★ **والفرق ظاهرٌ للمستخدم:**
        //    `null` يبقى «غير مسعَّر» في المركز المعلّق (`FR-M9-10`)،
        //    **بينما الصفر كان سيبدو سعراً** ⛔ **ويُسقِط حارس الحد الأدنى.**
        distributionPrice: _money(data['distributionPrice']),
        minCashPrice: _money(data['minCashPrice']),
        lastModifiedAt: _instant(data['lastModifiedAt']),
        modifiedBy: _text(data['modifiedBy']),
      );

  /// ★ مبلغٌ مقروء — ⛔ **والكسر يُقرأ غياباً لا يُقرَّب** (`ADR-0015`).
  ///
  /// ⚠️ **ولماذا الغياب لا التقريب:** `ADR-0015` القاعدة 3 تمنع التقريب
  /// الصامت، ★ **وقيمةٌ كسرية في هذا الحقل فسادُ بيانات لا سعرٌ صحيح** —
  /// ⟵ **وعرضُها «غير مسعَّر» يدفع المستخدم لإعادة إدخالها**، ⛔ **بينما
  /// تقريبُها كان يُثبِّت رقماً لم يكتبه أحد.**
  static Money? _money(Object? raw) => switch (raw) {
        final int value => Money(value),
        final double value when value == value.roundToDouble() =>
          Money(value.toInt()),
        _ => null,
      };

  static ItemUnit _unitOf(Object? raw) {
    for (final ItemUnit unit in ItemUnit.values) {
      if (unit.name == raw) return unit;
    }
    return ItemUnit.piece;
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
}

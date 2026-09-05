/// اختبارات **المتبقي المتأخر** — `FR-M8-09` … `FR-M8-18` · `WU-019`.
///
/// ⛔★★ **وكلُّ حدٍّ هنا منقولٌ عن المتطلب حرفياً** — ⛔ **لا عتبةٌ مخترَعة:**
/// **يوم–يومان 🟡** · **3–4 أيام 🟠** · **5 فأكثر 🔴** (`FR-M8-10`).
library;

import 'package:qtms_domain/qtms_domain.dart';
import 'package:test/test.dart';

void main() {
  // ★ **يومٌ ثابتٌ لا ساعةَ جهاز** — ⛔ **فلا اختبارَ ينكسر بمرور منتصف الليل.**
  final CalendarDay day = CalendarDay(2026, 9, 4);

  AgedRemainderCard cardOn(
    CalendarDay stockDate, {
    String sourceId = 'SRC-001',
    String itemKey = 'ITM-0001',
    String itemName = 'عوارض',
    int pieces = 10,
  }) =>
      AgedRemainderCard(
        sourceId: sourceId,
        itemKey: itemKey,
        itemName: itemName,
        stockDate: stockDate,
        remaining: PieceQuantity(PieceCount(pieces)),
      );

  group('★★ العمر — `inventory-design.md` §5', () {
    test('عمر البند = تاريخ اليوم − تاريخ المخزون', () {
      expect(
        agedRemainderAgeInDays(today: day, stockDate: CalendarDay(2026, 9, 1)),
        3,
      );
    });

    test('★ ويعبر حدَّ الشهر بلا خطأ', () {
      expect(
        agedRemainderAgeInDays(today: day, stockDate: CalendarDay(2026, 8, 30)),
        5,
      );
    });

    test('⛔ ورصيدُ اليوم نفسِه ليس متأخراً — `FR-M8-05`', () {
      expect(isAgedRemainder(today: day, stockDate: day), isFalse);
      expect(
        isAgedRemainder(today: day, stockDate: CalendarDay(2026, 9, 3)),
        isTrue,
      );
    });
  });

  group('★★ درجةُ الحدّة — `FR-M8-10` حرفياً', () {
    test('يوم–يومان ⟵ الأحدث', () {
      expect(agedRemainderSeverityOf(1), AgedRemainderSeverity.recent);
      expect(agedRemainderSeverityOf(2), AgedRemainderSeverity.recent);
    });

    test('3–4 أيام ⟵ الوسطى', () {
      expect(agedRemainderSeverityOf(3), AgedRemainderSeverity.ageing);
      expect(agedRemainderSeverityOf(4), AgedRemainderSeverity.ageing);
    });

    test('5 فأكثر ⟵ الأشدّ', () {
      expect(agedRemainderSeverityOf(5), AgedRemainderSeverity.overdue);
      expect(agedRemainderSeverityOf(40), AgedRemainderSeverity.overdue);
    });

    test('★ والأشدُّ يغلب في الجمع', () {
      expect(
        AgedRemainderSeverity.recent.max(AgedRemainderSeverity.overdue),
        AgedRemainderSeverity.overdue,
      );
      expect(
        AgedRemainderSeverity.overdue.max(AgedRemainderSeverity.ageing),
        AgedRemainderSeverity.overdue,
      );
    });
  });

  group('★★★ التجميع — `UC-004` ②', () {
    test('★ يجمع بالأيام والأقدمُ أولاً', () {
      final List<AgedRemainderDay> days = groupAgedRemainders(
        cards: <AgedRemainderCard>[
          cardOn(CalendarDay(2026, 9, 3)),
          cardOn(CalendarDay(2026, 8, 30)),
          cardOn(CalendarDay(2026, 9, 3), itemKey: 'ITM-0002'),
        ],
        today: day,
      );

      expect(days.length, 2);
      expect(days.first.stockDate, CalendarDay(2026, 8, 30));
      expect(days.first.ageInDays, 5);
      expect(days.first.severity, AgedRemainderSeverity.overdue);
      expect(days.last.items.length, 2);
    });

    test('⛔ ويُسقِط رصيدَ اليوم — فمخزون اليوم شاشتُه', () {
      expect(
        groupAgedRemainders(
          cards: <AgedRemainderCard>[cardOn(day)],
          today: day,
        ),
        isEmpty,
      );
    });

    test('⛔ ويُسقِط الرصيدَ غيرَ الموجب — ولا يُطالِب بتصريف عدم', () {
      expect(
        groupAgedRemainders(
          cards: <AgedRemainderCard>[
            cardOn(CalendarDay(2026, 9, 2), pieces: 0),
          ],
          today: day,
        ),
        isEmpty,
      );
    });

    test('★ ويرتّب بنودَ اليوم بالمصدر ثم بمفتاح النوع', () {
      final List<AgedRemainderDay> days = groupAgedRemainders(
        cards: <AgedRemainderCard>[
          cardOn(CalendarDay(2026, 9, 2), sourceId: 'SRC-002'),
          cardOn(CalendarDay(2026, 9, 2), itemKey: 'ITM-0009'),
          cardOn(CalendarDay(2026, 9, 2), itemKey: 'ITM-0001'),
        ],
        today: day,
      );

      expect(days.single.items.map((AgedRemainderCard c) => c.itemKey).toList(),
          <String>['ITM-0001', 'ITM-0009', 'ITM-0001']);
      expect(days.single.items.last.sourceId, 'SRC-002');
    });
  });

  group('★★ خلاصةُ التنبيه — `FR-M8-10` · `UC-004` ①', () {
    test('★ العدّادُ عددُ الأيام لا عددُ البنود', () {
      final AgedRemainderAlert alert = summarizeAgedRemainders(
        groupAgedRemainders(
          cards: <AgedRemainderCard>[
            cardOn(CalendarDay(2026, 9, 3)),
            cardOn(CalendarDay(2026, 9, 3), itemKey: 'ITM-0002'),
            cardOn(CalendarDay(2026, 8, 30)),
          ],
          today: day,
        ),
      );

      expect(alert.dayCount, 2);
      expect(alert.itemCount, 3);
      expect(alert.severity, AgedRemainderSeverity.overdue);
      expect(alert.oldestAgeInDays, 5);
      expect(alert.hasWork, isTrue);
    });

    test('★ ولا شيء يحتاج إجراءً ⟵ خلاصةٌ هادئة لا غياب', () {
      final AgedRemainderAlert alert =
          summarizeAgedRemainders(const <AgedRemainderDay>[]);
      expect(alert.hasWork, isFalse);
      expect(alert.dayCount, 0);
    });
  });

  group('★★ المعرّف والاسم المعروض', () {
    test('★ المعرّفُ هو معرّفُ سجل الرصيد نفسُه بترتيبه', () {
      expect(
        agedRemainderId(
          sourceId: 'SRC-001',
          itemKey: 'عتود - جونية رقم 1',
          stockDate: CalendarDay(2026, 9, 2),
        ),
        itemDailyBalanceId(
          sourceId: 'SRC-001',
          itemKey: 'عتود - جونية رقم 1',
          stockDate: CalendarDay(2026, 9, 2),
        ),
      );
    });

    test('★★ والاسمُ المركّب هو المعروض — [`DEBT-86`]', () {
      final AgedRemainderCard card = cardOn(
        CalendarDay(2026, 9, 2),
        itemKey: 'عتود - جونية رقم 1',
        itemName: 'عتود',
      );
      expect(card.displayName, 'عتود - جونية رقم 1');
      expect(card.ageInDaysOn(day), 2);
      expect(card.severityOn(day), AgedRemainderSeverity.recent);
      expect(card.unit, ItemUnit.piece);
    });
  });
}

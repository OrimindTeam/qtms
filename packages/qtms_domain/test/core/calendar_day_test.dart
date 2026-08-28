import 'package:qtms_domain/qtms_domain.dart';
import 'package:test/test.dart';

void main() {
  group('CalendarDay — اليوم التقويمي', () {
    test('يبني الصيغة YYYYMMDD بحشو أصفار كامل', () {
      expect(CalendarDay(2026, 8, 22).format(), '20260822');
      expect(CalendarDay(2026, 1, 5).format(), '20260105');
      expect(CalendarDay(2026, 12, 31).format(), '20261231');
    });

    test('يرفض شهراً خارج المدى 1–12', () {
      expect(() => CalendarDay(2026, 0, 1), throwsArgumentError);
      expect(() => CalendarDay(2026, 13, 1), throwsArgumentError);
    });

    test('يرفض يوماً غير موجود في شهره — لا يلتفّ صامتاً', () {
      // ⚠️ `DateTime(2026, 2, 31)` في Dart **ينزلق إلى 3 مارس بلا إنذار**.
      //    هذا الاختبار يُثبت أن النوع يرفضه بدل أن يقبل يوماً آخر بصمت.
      expect(() => CalendarDay(2026, 2, 31), throwsArgumentError);
      expect(() => CalendarDay(2026, 4, 31), throwsArgumentError);
    });

    test('يقبل 29 فبراير في سنة كبيسة ويرفضه في غيرها', () {
      expect(CalendarDay(2028, 2, 29).format(), '20280229');
      expect(() => CalendarDay(2026, 2, 29), throwsArgumentError);
    });

    test('GR-54: يشتقّ اليوم من لحظة الخادم بـUTC لا بمنطقة الجهاز', () {
      // نفس اللحظة تماماً بصيغتين مختلفتي الإزاحة — ويجب أن تُنتج اليوم نفسه.
      final DateTime utcInstant = DateTime.utc(2026, 8, 22, 21, 30);
      final DateTime shiftedSameInstant =
          DateTime.parse('2026-08-23T00:30:00+03:00');

      expect(CalendarDay.fromUtc(utcInstant).format(), '20260822');
      expect(CalendarDay.fromUtc(shiftedSameInstant).format(), '20260822');
    });

    test('المساواة والترتيب بالقيمة لا بالمرجع', () {
      expect(CalendarDay(2026, 8, 22), equals(CalendarDay(2026, 8, 22)));
      expect(CalendarDay(2026, 8, 22).hashCode,
          CalendarDay(2026, 8, 22).hashCode);
      expect(CalendarDay(2026, 8, 21).compareTo(CalendarDay(2026, 8, 22)),
          lessThan(0));
      expect(CalendarDay(2026, 9, 1).compareTo(CalendarDay(2026, 8, 22)),
          greaterThan(0));
    });
  });

  group('previousDay — اليوم السابق (FR-M9-13)', () {
    test('★ داخل الشهر يُنقِص يوماً', () {
      expect(CalendarDay(2026, 8, 25).previousDay(), CalendarDay(2026, 8, 24));
    });

    test('★★ ويعبر أول الشهر إلى آخر ما قبله', () {
      expect(CalendarDay(2026, 8, 1).previousDay(), CalendarDay(2026, 7, 31));
    });

    test('★★ ويعبر أول السنة', () {
      expect(CalendarDay(2026, 1, 1).previousDay(), CalendarDay(2025, 12, 31));
    });

    test('★★★ والسنة الكبيسة تُحسَب صحيحةً — 1 مارس 2024 ⟵ 29 فبراير', () {
      expect(CalendarDay(2024, 3, 1).previousDay(), CalendarDay(2024, 2, 29));
    });

    test('⛔ وغير الكبيسة تعود إلى 28 — 1 مارس 2026 ⟵ 28 فبراير', () {
      expect(CalendarDay(2026, 3, 1).previousDay(), CalendarDay(2026, 2, 28));
    });
  });

  group('★★ tryParseCompact — نظير format للقراءة (WU-008)', () {
    test('★ يفكّ ما تكتبه format حرفياً — رحلةُ ذهابٍ وإياب', () {
      final CalendarDay day = CalendarDay(2026, 8, 27);
      expect(CalendarDay.tryParseCompact(day.format()), day);
    });

    test('★ ويقبل المسافات الطرفية — فالقيمة المخزَّنة قد تُقرأ مشذَّبة', () {
      expect(CalendarDay.tryParseCompact(' 20260827 '), CalendarDay(2026, 8, 27));
    });

    test('⛔ والطول غير الثمانية غيابٌ لا انهيار', () {
      expect(CalendarDay.tryParseCompact('2026827'), isNull);
      expect(CalendarDay.tryParseCompact('202608271'), isNull);
      expect(CalendarDay.tryParseCompact(''), isNull);
    });

    test('⛔ وغير الرقمي غيابٌ كذلك', () {
      expect(CalendarDay.tryParseCompact('2026-8-27'), isNull);
      expect(CalendarDay.tryParseCompact('٢٠٢٦٠٨٢٧'), isNull);
    });

    test('★★★ ويومٌ لا وجود له يُرفَض بنفس حارس المُنشئ — 31 فبراير', () {
      expect(CalendarDay.tryParseCompact('20260231'), isNull);
      expect(CalendarDay.tryParseCompact('20260229'), isNull);
      expect(CalendarDay.tryParseCompact('20240229'), CalendarDay(2024, 2, 29));
    });

    test('⛔ وشهرٌ خارج المدى يُرفَض ولا يُلتَفّ إلى السنة التالية', () {
      expect(CalendarDay.tryParseCompact('20261327'), isNull);
      expect(CalendarDay.tryParseCompact('20260027'), isNull);
    });
  });
}

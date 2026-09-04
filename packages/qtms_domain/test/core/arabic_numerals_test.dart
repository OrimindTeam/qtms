import 'package:qtms_domain/qtms_domain.dart';
import 'package:test/test.dart';

void main() {
  group('riyalsInArabicWords — FR-M17-07', () {
    test('★ الصفرُ يُفقَّط ولا يُترك فارغاً — الصفرُ في كشفٍ معلومة', () {
      expect(riyalsInArabicWords(Money.zero), 'صفر ريال');
    });

    test('الآحاد', () {
      expect(riyalsInArabicWords(const Money(1)), 'واحد ريال');
      expect(riyalsInArabicWords(const Money(9)), 'تسعة ريال');
    });

    test('★ العشراتُ المركّبة — والآحادُ تسبق العشرات', () {
      expect(riyalsInArabicWords(const Money(10)), 'عشرة ريال');
      expect(riyalsInArabicWords(const Money(11)), 'أحد عشر ريال');
      expect(riyalsInArabicWords(const Money(19)), 'تسعة عشر ريال');
      expect(riyalsInArabicWords(const Money(20)), 'عشرون ريال');
      expect(riyalsInArabicWords(const Money(25)), 'خمسة وعشرون ريال');
      expect(riyalsInArabicWords(const Money(99)), 'تسعة وتسعون ريال');
    });

    test('المئات بصيغها المعتمدة', () {
      expect(riyalsInArabicWords(const Money(100)), 'مئة ريال');
      expect(riyalsInArabicWords(const Money(200)), 'مئتان ريال');
      expect(riyalsInArabicWords(const Money(300)), 'ثلاثمئة ريال');
      expect(riyalsInArabicWords(const Money(999)),
          'تسعمئة وتسعة وتسعون ريال');
    });

    test('★★ الألوفُ بصيغها الثلاث — مفرد ومثنّى وجمع', () {
      expect(riyalsInArabicWords(const Money(1000)), 'ألف ريال');
      expect(riyalsInArabicWords(const Money(2000)), 'ألفان ريال');
      expect(riyalsInArabicWords(const Money(3000)), 'ثلاثة آلاف ريال');
      // ★ **وتمييزُ ما فوق العشرة مفردٌ منصوب** — «أحد عشر ألفاً».
      expect(riyalsInArabicWords(const Money(11000)), 'أحد عشر ألفاً ريال');
    });

    test('مبلغٌ مركَّب من مرتبتين', () {
      expect(
        riyalsInArabicWords(const Money(49800)),
        'تسعة وأربعون ألفاً وثمانمئة ريال',
      );
    });

    test('★ والمجموعةُ الصفرية تُتخطّى ولا تُنطَق', () {
      expect(riyalsInArabicWords(const Money(1000000)), 'مليون ريال');
      expect(riyalsInArabicWords(const Money(1000005)), 'مليون وخمسة ريال');
    });

    test('الملايين والمليارات', () {
      expect(riyalsInArabicWords(const Money(2000000)), 'مليونان ريال');
      expect(riyalsInArabicWords(const Money(5000000)), 'خمسة ملايين ريال');
      expect(riyalsInArabicWords(const Money(1000000000)), 'مليار ريال');
    });

    // ⛔⛔★★★ **الإشارةُ تُنطَق كلمةً** — ★ **ورصيدُ المقوت يكون سالباً فعلاً
    //    حين يكون له فائض** (`schema/dealer-ledger.md`).
    test('⛔ السالبُ يُصدَّر بكلمة «سالب» صريحة لا بإشارة', () {
      expect(riyalsInArabicWords(const Money(-500)), 'سالب خمسمئة ريال');
    });

    test('★ ومبلغٌ فوق المراتب المعروفة يُردّ رقماً ولا يُخترَع اسمُ مرتبته', () {
      const Money huge = Money(1000000000000);
      expect(riyalsInArabicWords(huge), '1000000000000 ريال');
    });

    test('★ والحدُّ الأدنى لا يُفيض — بلا abs()', () {
      // ⚠️ **`(-2^63).abs()` تفيض في Dart** — ★ **والدالةُ تعمل على النصّ.**
      const Money floor = Money(-9223372036854775808);
      expect(() => riyalsInArabicWords(floor), returnsNormally);
      expect(riyalsInArabicWords(floor), startsWith('سالب '));
    });
  });
}

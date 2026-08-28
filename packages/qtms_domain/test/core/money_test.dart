import 'package:qtms_domain/qtms_domain.dart';
import 'package:test/test.dart';

void main() {
  group('المال — ADR-0015: عدد صحيح بالريال', () {
    test('الجمع والطرح والضرب في عدد صحيح', () {
      expect((const Money(1200) + const Money(800)).riyals, 2000);
      expect((const Money(1200) - const Money(800)).riyals, 400);
      expect((const Money(1200) * 3).riyals, 3600);
      expect(Money.zero.isZero, isTrue);
    });

    test('★ المقارنة والسالب', () {
      expect(const Money(500) < const Money(600), isTrue);
      expect(const Money(600) >= const Money(600), isTrue);
      expect((const Money(100) - const Money(300)).isNegative, isTrue);
    });

    test('★★ التقريب الحسابي لأقرب ريال — القاعدة 5 بمثاليها المنصوصين', () {
      expect(Money.rounded(617.25).riyals, 617);
      expect(Money.rounded(617.50).riyals, 618);
      expect(Money.rounded(1215.067).riyals, 1215);
    });

    test('⛔ والتقريب على سالب يُرمى — القاعدة 8، فلا يُخمَّن اتجاهه', () {
      expect(() => Money.rounded(-0.5), throwsArgumentError);
      expect(() => Money.rounded(double.nan), throwsArgumentError);
      expect(() => Money.rounded(double.infinity), throwsArgumentError);
    });

    test('★★ وإدخال المستخدم يرفض الكسر ولا يُقرِّبه — القاعدة 3', () {
      expect(Money.tryParseInput('1200')?.riyals, 1200);
      expect(Money.tryParseInput(' 1200 ')?.riyals, 1200);
      // ⛔ الكسر يُرفَض رفضاً صريحاً — ولا يعود 1200 ولا 1201.
      expect(Money.tryParseInput('1200.5'), isNull);
      expect(Money.tryParseInput('1200,5'), isNull);
      expect(Money.tryParseInput(''), isNull);
      expect(Money.tryParseInput('كثير'), isNull);
    });

    test('★ والمبلغ المخزون هو المعروض حرفياً — القاعدة 2 (لا فِلس)', () {
      const Money amount = Money(1215);
      expect(amount.riyals, 1215);
    });
  });
}

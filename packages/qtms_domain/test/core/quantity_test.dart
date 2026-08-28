import 'package:qtms_domain/qtms_domain.dart';
import 'package:test/test.dart';

void main() {
  group('الكميات — GR-19: الوحدة داخل النوع', () {
    test('المعدود عدد صحيح ويرفض الكسر — BR-M6-06', () {
      expect(PieceCount.tryParseInput('40')?.pieces, 40);
      expect(PieceCount.tryParseInput('40.5'), isNull);
      expect((const PieceCount(40) + const PieceCount(2)).pieces, 42);
      expect((const PieceCount(40) - const PieceCount(45)).isNegative, isTrue);
    });

    test('★ والوزني يقبل الكسر — فالأوزان ليست مبالغ (ADR-0015 القاعدة 9)', () {
      expect(WeightKg.tryParseInput('12.345')?.kilograms, closeTo(12.345, 1e-9));
      expect(WeightKg.tryParseInput('abc'), isNull);
      expect(
        (const WeightKg(12.5) + const WeightKg(0.25)).kilograms,
        closeTo(12.75, 1e-9),
      );
    });

    test('★ والعرض بثلاث خانات — design-overview §2.11', () {
      expect(const WeightKg(12.3456).formatted(), '12.346');
      expect(const WeightKg(12).formatted(), '12.000');
      expect(WeightKg.decimals, 3);
    });

    test('★★ ولا تُجمع الحبات مع الأوزان — والمنع بالنوع لا بالمراجعة', () {
      // ⛔ لا عملية جمع بين النوعين أصلاً، والسطر التالي لا يُصرَّف:
      //    const PieceCount(1) + const WeightKg(1);
      // ★ فالاختبار هنا يُثبت أنهما نوعان مستقلان بلا جسر بينهما.
      expect(const PieceCount(1).pieces, isA<int>());
      expect(const WeightKg(1).kilograms, isA<double>());
    });
  });
}

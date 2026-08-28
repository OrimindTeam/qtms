import 'package:qtms_domain/qtms_domain.dart';
import 'package:test/test.dart';

void main() {
  final CalendarDay day = CalendarDay(2026, 8, 22);

  group('مفاتيح العدّادات — data-dictionary §1', () {
    test('عدّاد المستند بالنوع واليوم', () {
      expect(
        documentCounterId(kind: DocumentKind.receipt, day: day),
        'receipt_20260822',
      );
      expect(
        documentCounterId(kind: DocumentKind.stocktake, day: day),
        'stocktake_20260822',
      );
    });

    test('★ وعدّاد الجونية بالمصدر واليوم — وهو الاستثناء المنصوص', () {
      expect(
        dailySackCounterId(sourceId: 'SRC-001', day: day),
        'SRC-001_20260822',
      );
      // مصدران في اليوم نفسه ⟵ عدّادان مستقلان تماماً.
      expect(
        dailySackCounterId(sourceId: 'SRC-002', day: day),
        isNot(dailySackCounterId(sourceId: 'SRC-001', day: day)),
      );
    });

    test('واليوم نفسه لمصدرين مختلفين لا يتصادم مع يوم آخر', () {
      expect(
        dailySackCounterId(sourceId: 'SRC-001', day: CalendarDay(2026, 8, 23)),
        'SRC-001_20260823',
      );
    });

    test('يرفض مصدراً فارغاً', () {
      expect(
        () => dailySackCounterId(sourceId: '', day: day),
        throwsArgumentError,
      );
    });

    test('أسماء المجموعات كما في القاموس حرفياً', () {
      expect(documentCountersCollection, 'document_counters');
      expect(dailySackCountersCollection, 'daily_sack_counters');
    });
  });

  group('nextSequence — naming-conventions §5', () {
    test('الغياب يعني صفراً فيبدأ من ١', () {
      expect(nextSequence(null), 1);
    });

    test('يتقدّم دائماً ولا يعيد استخدام رقم', () {
      expect(nextSequence(1), 2);
      expect(nextSequence(9999), 10000);
    });

    test('يرفض عدّاداً سالباً — خلل لا حالة عمل', () {
      expect(() => nextSequence(-1), throwsArgumentError);
    });

    test('★ تسلسل متتابع لا يُنتج رقمين متطابقين إطلاقاً', () {
      // محاكاة تخصيص متتابع — كل خطوة تقرأ ناتج سابقتها.
      int? current;
      final List<int> issued = <int>[];
      for (int i = 0; i < 50; i++) {
        current = nextSequence(current);
        issued.add(current);
      }
      expect(issued.toSet().length, 50, reason: 'تكرار في التسلسل');
      expect(issued.first, 1);
      expect(issued.last, 50);
    });
  });
}

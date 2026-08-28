/// ★★★ **مبالغُ التسوية تعيش في `pricing/current`** — اختبارُ ارتداد `IQ-027`.
///
/// ⛔⛔★★★ **ولماذا ملفٌّ مستقل لطبقة المعالِج:** `distribution_test.dart`
/// يختبر **التخطيط الخالص** ويُمرِّر [DebtSettlement] **مبنيّةً في الاختبار
/// نفسه** — ⟵ **فلم يرَ قطُّ من أي مستندٍ يقرؤها المعالِج**، ⛔ **فلو بقيت
/// القراءة على الأب بعد نقل الحقول لَمَرَّ كلُّ اختبارٍ أخضرَ بينما حارسُ
/// `E-15` معطَّلٌ حيّاً** (إلغاءُ ضمارٍ سُدِّد يمرّ).
/// ★★ **وهو درسُ [`DEBT-37`] و[`DEBT-55`] حرفياً: اختبارُ الطبقة لا يُغني عن
/// اختبار ما يعبر بينها.**
library;

import 'package:qtms_domain/qtms_domain.dart';
import 'package:qtms_functions/src/distribution_handler.dart'
    show readStoredSettlement;
import 'package:test/test.dart';

/// مستندُ الأب — ⛔ **بلا أي مبلغ** (`ADR-0011` · `IQ-027`).
Map<String, Object?> parent({String settlementStatus = 'open'}) =>
    <String, Object?>{
      'documentNumber': 'DST-20260828-0001',
      'sourceId': 'SRC-001',
      'dealerId': 'MQT-0001',
      'status': 'priced',
      'settlementStatus': settlementStatus,
    };

/// مستند `pricing/current` — ★ **موضعُ كل مبلغ**.
Map<String, Object?> pricing({
  int debtValue = 120000,
  int? settledAmount,
  int? discountedAmount,
}) =>
    <String, Object?>{
      'sourceId': 'SRC-001',
      'debtValue': debtValue,
      'settledAmount': ?settledAmount,
      'discountedAmount': ?discountedAmount,
    };

void main() {
  group('★★★ IQ-027 — المبالغُ تُقرأ من `pricing/current` لا من الأب', () {
    test('⛔ غيابُ مستند التسعير ⟵ «لم يُمَسّ» لا صفرٌ محسوب', () {
      expect(readStoredSettlement(parent(), null), isNull);
    });

    test('⛔ وغيابُ الأب كذلك ⟵ null', () {
      expect(readStoredSettlement(null, pricing(settledAmount: 5000)), isNull);
    });

    test('⛔ مستندُ تسعيرٍ بلا حقلَي تسوية ⟵ «لم يُمَسّ»', () {
      expect(readStoredSettlement(parent(), pricing()), isNull);
    });

    test('★★★ المسدَّد يُقرأ من `pricing` ⟵ والضمارُ ممسوس', () {
      final DebtSettlement? settlement = readStoredSettlement(
        parent(),
        pricing(settledAmount: 20000),
      );
      expect(settlement, isNotNull);
      expect(settlement!.settledAmount, const Money(20000));
      expect(settlement.debtValue, const Money(120000));
      expect(settlement.remaining, const Money(100000));
      expect(settlement.status, SettlementStatus.partiallyOpen);
      expect(settlement.isTouchedBySettlement, isTrue);
    });

    test('★★ والمخصوم كذلك ⟵ يُمنع الإلغاء بـ`E-15`', () {
      final DebtSettlement? settlement = readStoredSettlement(
        parent(),
        pricing(discountedAmount: 500),
      );
      expect(settlement!.isTouchedBySettlement, isTrue);
      expect(
        validateDistributionCancellable(settlement),
        isA<Failure<void>>(),
      );
    });

    test('★★★ سدادٌ كامل ⟵ مغلق والمتبقي صفر', () {
      final DebtSettlement? settlement = readStoredSettlement(
        parent(settlementStatus: 'closed'),
        pricing(settledAmount: 100000, discountedAmount: 20000),
      );
      expect(settlement!.remaining, Money.zero);
      expect(settlement.status, SettlementStatus.closed);
    });

    // ⛔⛔★★★ **الحارسُ الفعلي لهذا الارتداد:** ★ **مبلغٌ مكتوبٌ في الأب
    //    خطأً لا يُقرأ إطلاقاً** — ⟵ **فلو عادت القراءةُ إلى الأب يوماً
    //    سقط هذا الاختبار وحدَه**، ⛔ **ولا يسقط شيءٌ سواه.**
    test('⛔⛔ ومبلغٌ في الأب يُتجاهَل تماماً — الحارسُ الحقيقي', () {
      final Map<String, Object?> contaminated = parent()
        ..['settledAmount'] = 99999
        ..['discountedAmount'] = 88888;
      expect(readStoredSettlement(contaminated, pricing()), isNull);
    });
  });
}

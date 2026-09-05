/// الجرد — **طبقة النطاق** (`WU-022` · `M16`).
///
/// ═══════════════════════════════════════════════════════════════════════
/// ★★★ **وثلاثةٌ تحرسها هذه الاختبارات:**
///
///   ① **`FR-M16-01`:** ★ **الفرق = العدُّ الفعلي − الرصيدُ الدفتري** —
///      ⟵ **بإشارته**، ⛔ **ولا قيمةَ مطلقة تُخفي اتجاهه.**
///   ② **`inventory-design.md` §3:** ★★ **الزيادةُ دخولٌ والنقصُ خروج** —
///      ⟵ **والصفرُ لا حركةَ له إطلاقاً.**
///   ③ **`GR-19` · `E-31`:** ⛔ **ولا تُطرَح حبّةٌ من كيلوجرام.**
/// ═══════════════════════════════════════════════════════════════════════
library;

import 'package:qtms_domain/qtms_domain.dart';
import 'package:test/test.dart';

StockQuantity pieces(int value) => PieceQuantity(PieceCount(value));

StockQuantity kilos(double value) => WeightQuantity(WeightKg(value));

StockQuantity difference({
  required StockQuantity book,
  required StockQuantity actual,
}) =>
    (stocktakeDifference(bookBalance: book, actualCount: actual)
            as Success<StockQuantity>)
        .value;

void main() {
  group('★★★ FR-M16-01 — الفرق بإشارته', () {
    test('★ العدُّ أكثر من الدفتر ⟵ فرقٌ موجب', () {
      expect(difference(book: pieces(80), actual: pieces(83)), pieces(3));
    });

    test('★★ والعدُّ أقلّ ⟵ فرقٌ سالب — ⛔ ولا قيمةَ مطلقة تُخفي اتجاهه', () {
      expect(difference(book: pieces(80), actual: pieces(78)), pieces(-2));
    });

    test('★ والمطابقُ صفر', () {
      expect(difference(book: pieces(80), actual: pieces(80)), pieces(0));
    });

    test('★★ والأوزان بثلاث خانات — `FR-M16-07`', () {
      final StockQuantity value =
          difference(book: kilos(1.200), actual: kilos(1.180));
      expect((value as WeightQuantity).weight.formatted(), '-0.020');
    });

    test('⛔⛔ ولا تُطرَح حبّةٌ من كيلوجرام — `GR-19` · `E-31`', () {
      final Outcome<StockQuantity> result = stocktakeDifference(
        bookBalance: pieces(80),
        actualCount: kilos(80),
      );
      expect(result, isA<Failure<StockQuantity>>());
      expect(
        ((result as Failure<StockQuantity>).error as ValidationError).ruleCode,
        'GR-19',
      );
    });
  });

  group('★★★ حركةُ التسوية — الاتجاهُ من الإشارة', () {
    test('★ الفرقُ الموجب دخولٌ بكميةٍ مطلقة — «تسوية جرد بالزيادة»', () {
      final StocktakeAdjustment adjustment = stocktakeAdjustment(pieces(3))!;
      expect(adjustment.direction, MovementDirection.incoming);
      expect(adjustment.quantity, pieces(3));
    });

    test('★★ والسالبُ خروجٌ بكميةٍ مطلقة — «تسوية جرد بالنقص»', () {
      final StocktakeAdjustment adjustment = stocktakeAdjustment(pieces(-2))!;
      expect(adjustment.direction, MovementDirection.outgoing);
      // ⛔⛔ **ولا كميةَ سالبة في الدفتر إطلاقاً**.
      expect(adjustment.quantity, pieces(2));
      expect(adjustment.quantity.isNegative, isFalse);
    });

    test('⛔⛔★★ والصفرُ بلا حركةٍ أصلاً — ⛔ لا حركةٌ صفرية', () {
      expect(stocktakeAdjustment(pieces(0)), isNull);
      expect(stocktakeAdjustment(kilos(0)), isNull);
    });

    test('★★ والوزنُ السالب يُقلَب مطلقاً كذلك', () {
      final StocktakeAdjustment adjustment = stocktakeAdjustment(kilos(-0.02))!;
      expect(adjustment.direction, MovementDirection.outgoing);
      expect(
        (adjustment.quantity as WeightQuantity).weight.formatted(),
        '0.020',
      );
    });
  });

  group('★★ بدءُ الجرد — التحقق', () {
    test('★ يقبل أنواعاً ويرتّبها — `coding-standards.md` §2.7', () {
      final Outcome<ValidatedStocktakeStart> result = validateStocktakeStart(
        const StocktakeStartInput(
          sourceId: 'SRC-001',
          itemIds: <String>['ITM-9', 'ITM-1'],
        ),
      );
      expect(
        (result as Success<ValidatedStocktakeStart>).value.itemKeys,
        <String>['ITM-1', 'ITM-9'],
      );
    });

    test('⛔ ويرفض بلا مصدر — `BR-M16-04`', () {
      expect(
        validateStocktakeStart(
          const StocktakeStartInput(sourceId: '  ', itemIds: <String>['ITM-1']),
        ),
        isA<Failure<ValidatedStocktakeStart>>(),
      );
    });

    test('⛔ ويرفض بلا نوعٍ واحد — `FR-M16-01`', () {
      expect(
        validateStocktakeStart(
          const StocktakeStartInput(sourceId: 'SRC-001'),
        ),
        isA<Failure<ValidatedStocktakeStart>>(),
      );
    });

    test('⛔ ويرفض نوعاً مكرَّراً', () {
      expect(
        validateStocktakeStart(
          const StocktakeStartInput(
            sourceId: 'SRC-001',
            itemIds: <String>['ITM-1', 'ITM-1'],
          ),
        ),
        isA<Failure<ValidatedStocktakeStart>>(),
      );
    });
  });

  group('★★ الأعداد الفعلية — التحقق', () {
    StocktakeCountInput count({
      String itemId = 'ITM-1',
      int actual = 78,
      ItemUnit unit = ItemUnit.piece,
      String? reason,
    }) =>
        StocktakeCountInput(
          itemId: itemId,
          unit: unit,
          actualCount: PieceQuantity(PieceCount(actual)),
          differenceReason: reason,
        );

    test('★★ والصفرُ عدٌّ مشروع — «لم يبقَ شيء» معلومةٌ لا غياب', () {
      final Outcome<ValidatedStocktakeCounts> result = validateStocktakeCounts(
        sourceId: 'SRC-001',
        counts: <StocktakeCountInput>[count(actual: 0)],
      );
      expect(result, isA<Success<ValidatedStocktakeCounts>>());
    });

    test('⛔ والسالبُ مرفوض — `FR-M16-07`', () {
      final Outcome<ValidatedStocktakeCounts> result = validateStocktakeCounts(
        sourceId: 'SRC-001',
        counts: <StocktakeCountInput>[count(actual: -1)],
      );
      expect(result, isA<Failure<ValidatedStocktakeCounts>>());
    });

    test('⛔ ووحدةُ العدّ = وحدة النوع — `GR-19`', () {
      final Outcome<ValidatedStocktakeCounts> result = validateStocktakeCounts(
        sourceId: 'SRC-001',
        counts: <StocktakeCountInput>[
          count(unit: ItemUnit.kilogram),
        ],
      );
      expect(
        ((result as Failure<ValidatedStocktakeCounts>).error as ValidationError)
            .ruleCode,
        'GR-19',
      );
    });

    test('⛔ ولا عدّان لنفس النوع', () {
      final Outcome<ValidatedStocktakeCounts> result = validateStocktakeCounts(
        sourceId: 'SRC-001',
        counts: <StocktakeCountInput>[count(), count()],
      );
      expect(result, isA<Failure<ValidatedStocktakeCounts>>());
    });

    test('★★★ وسببُ الفرق اختياريٌّ — `FR-M16-04` · `ADR-0020`', () {
      // ⛔⛔ **ولا يُرفَض اعتمادٌ لغيابه** — ★ **وكان إلزامياً قبل `ADR-0020`.**
      final Outcome<ValidatedStocktakeCounts> result = validateStocktakeCounts(
        sourceId: 'SRC-001',
        counts: <StocktakeCountInput>[count()],
      );
      expect(
        (result as Success<ValidatedStocktakeCounts>)
            .value
            .counts
            .single
            .differenceReason,
        isNull,
      );
    });

    test('★★ والفراغُ غيابٌ لا نصٌّ فارغ — `ADR-0020` القاعدة الباقية', () {
      final Outcome<ValidatedStocktakeCounts> result = validateStocktakeCounts(
        sourceId: 'SRC-001',
        counts: <StocktakeCountInput>[count(reason: '   ')],
        reason: '  ',
      );
      final ValidatedStocktakeCounts value =
          (result as Success<ValidatedStocktakeCounts>).value;
      expect(value.counts.single.differenceReason, isNull);
      expect(value.reason, isNull);
    });

    test('⛔ والسببُ الطويل مرفوض — `GR-49`', () {
      final Outcome<ValidatedStocktakeCounts> result = validateStocktakeCounts(
        sourceId: 'SRC-001',
        counts: <StocktakeCountInput>[count(reason: 'ا' * 5000)],
      );
      expect(result, isA<Failure<ValidatedStocktakeCounts>>());
    });

    test('★ والأعدادُ تُرتَّب بمفتاح النوع', () {
      final Outcome<ValidatedStocktakeCounts> result = validateStocktakeCounts(
        sourceId: 'SRC-001',
        counts: <StocktakeCountInput>[
          count(itemId: 'ITM-9'),
          count(itemId: 'ITM-1'),
        ],
      );
      expect(
        (result as Success<ValidatedStocktakeCounts>)
            .value
            .counts
            .map((ValidatedStocktakeCount c) => c.itemKey)
            .toList(),
        <String>['ITM-1', 'ITM-9'],
      );
    });
  });
}

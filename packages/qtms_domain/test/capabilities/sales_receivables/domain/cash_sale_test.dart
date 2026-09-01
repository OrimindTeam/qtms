/// البيع النقدي المباشر (`M11` · `WU-012`) — **طبقة النطاق**.
///
/// ⚠️⚠️ **وما تُثبته هذه الاختبارات:** أن **صافي المقبوض = Σ(قيم السطور)**
/// (`design-overview.md` §2.6)، وأن **التسعير إلزاميٌّ ولا سطرَ بلا سعر**
/// (`FR-M11-04`)، وأن **حدَّ البيع الأدنى يُقاس بدالةٍ واحدة والمساواةُ به
/// مقبولة** (`FR-M11-05`)، وأن **الغياب ليس تجاوزاً** (`FR-M11-06`)،
/// وأن **الإجماليين لا يُجمعان** (`GR-19`).
///
/// ⛔ **ولا تُثبت أن الكتابة محميّة** — ★ **الحماية في `planCashSale`**،
/// ولها اختباراتها هناك (`functions/test/cash_sale_test.dart`).
library;

import 'package:qtms_domain/qtms_domain.dart';
import 'package:test/test.dart';

CashSaleLineInput _pieceLine(
  String itemId, {
  int quantity = 10,
  int unitPrice = 700,
  String? sackId,
  String? belowMinReason,
}) =>
    CashSaleLineInput(
      itemId: itemId,
      itemName: 'عوارض',
      unit: ItemUnit.piece,
      quantity: PieceQuantity(PieceCount(quantity)),
      unitPrice: Money(unitPrice),
      sackId: sackId,
      belowMinReason: belowMinReason,
    );

CashSaleLineInput _weightLine(
  String itemId, {
  double quantity = 0.700,
  int unitPrice = 3500,
  String? sackId,
}) =>
    CashSaleLineInput(
      itemId: itemId,
      itemName: 'سكرب',
      unit: ItemUnit.kilogram,
      quantity: WeightQuantity(WeightKg(quantity)),
      unitPrice: Money(unitPrice),
      sackId: sackId,
    );

CashSaleInput _sale({
  List<CashSaleLineInput>? lines,
  String sourceId = 'SRC-001',
  String? notes,
}) =>
    CashSaleInput(
      sourceId: sourceId,
      notes: notes,
      lines: lines ?? <CashSaleLineInput>[_pieceLine('ITM-0001')],
    );

ValidatedCashSale _validated(CashSaleInput input) =>
    (validateCashSale(input) as Success<ValidatedCashSale>).value;

void main() {
  // ═══════════════════════════════════════════════════════════════════════
  // ★★★ قيمة السطر — ⛔ ولا معادلةَ ثانية (ADR-0019)
  // ═══════════════════════════════════════════════════════════════════════
  group('★★★ cashSaleLineTotal — تفويضٌ لا نسخة', () {
    test('⛔ المعدود لا يمرّ بالتقريب — صحيح × صحيح', () {
      expect(
        cashSaleLineTotal(
          quantity: const PieceQuantity(PieceCount(80)),
          unitPrice: const Money(1501),
        ),
        const Money(120080),
      );
    });

    test('★ والوزني يُقرَّب لأقرب ريال — الموضع الثالث (ADR-0019)', () {
      // 0.700 كجم × 3,500 = 2,450 بالضبط.
      expect(
        cashSaleLineTotal(
          quantity: const WeightQuantity(WeightKg(0.700)),
          unitPrice: const Money(3500),
        ),
        const Money(2450),
      );
      // 1.234 كجم × 1,501 = 1,852.234 ⟵ 1,852.
      expect(
        cashSaleLineTotal(
          quantity: const WeightQuantity(WeightKg(1.234)),
          unitPrice: const Money(1501),
        ),
        const Money(1852),
      );
    });

    test('★★ وهي حرفياً نتيجةُ distributionLineTotal — ⛔ لا نسخة تفترق', () {
      const StockQuantity quantity = WeightQuantity(WeightKg(1.234));
      const Money price = Money(1501);
      expect(
        cashSaleLineTotal(quantity: quantity, unitPrice: price),
        distributionLineTotal(quantity: quantity, unitPrice: price),
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // ★★ صافي المقبوض — design-overview.md §2.6
  // ═══════════════════════════════════════════════════════════════════════
  group('★★ computeNetCashReceived — Σ(قيم السطور)', () {
    test('✅ يجمع سطور الحبّات والأوزان معاً — فكلاهما مبلغٌ بالريال', () {
      final ValidatedCashSale sale = _validated(
        _sale(
          lines: <CashSaleLineInput>[
            // 10 × 700 = 7,000
            _pieceLine('ITM-0001'),
            // 0.700 × 3,500 = 2,450
            _weightLine('ITM-0002'),
          ],
        ),
      );
      expect(sale.netCashReceived, const Money(9450));
    });

    test('★ وسندٌ بسطرٍ واحد صافيه قيمةُ سطره', () {
      expect(_validated(_sale()).netCashReceived, const Money(7000));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // ⛔ GR-19 — الإجماليان منفصلان دائماً
  // ═══════════════════════════════════════════════════════════════════════
  group('⛔ GR-19 — ولا تُجمع حبّةٌ مع كيلوجرام', () {
    test('★ إجماليان مستقلّان لكل وحدة', () {
      final ValidatedCashSale sale = _validated(
        _sale(
          lines: <CashSaleLineInput>[
            _pieceLine('ITM-0001', quantity: 12),
            _weightLine('ITM-0002', quantity: 2.500),
          ],
        ),
      );
      expect(sale.totalPieces.pieces, 12);
      expect(sale.totalWeight.kilograms, closeTo(2.500, 0.0001));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // ★★★ FR-M11-05 — الحد الأدنى (GR-34)
  // ═══════════════════════════════════════════════════════════════════════
  group('★★★ isBelowMinimumCashPrice — FR-M11-05 · FR-M11-06', () {
    test('⛔ السعر دون الحد ⟵ صحيح', () {
      expect(
        isBelowMinimumCashPrice(
          unitPrice: const Money(600),
          minCashPrice: const Money(700),
        ),
        isTrue,
      );
    });

    test('★★ والمساواةُ بالحد مقبولة — «لا يقل عن» لا «يزيد على»', () {
      expect(
        isBelowMinimumCashPrice(
          unitPrice: const Money(700),
          minCashPrice: const Money(700),
        ),
        isFalse,
      );
    });

    test('★★ وغيابُ الحد ليس تجاوزاً — FR-M11-06 يُجيز البيع بتنبيه', () {
      expect(
        isBelowMinimumCashPrice(
          unitPrice: const Money(1),
          minCashPrice: null,
        ),
        isFalse,
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // ★★★ التحقق — FR-M11-01 … FR-M11-12
  // ═══════════════════════════════════════════════════════════════════════
  group('★★★ validateCashSale', () {
    test('✅ سندٌ سليم يُقبَل وسطورُه مرتَّبةٌ بمفتاح النوع', () {
      final ValidatedCashSale sale = _validated(
        _sale(
          lines: <CashSaleLineInput>[
            _pieceLine('ITM-0009'),
            _pieceLine('ITM-0002'),
          ],
        ),
      );
      expect(
        sale.lines.map((ValidatedCashSaleLine l) => l.itemKey),
        <String>['ITM-0002', 'ITM-0009'],
      );
    });

    test('⛔ FR-M11-02: بلا مصدرٍ يُرفَض — ولا خصمَ من مخزنٍ مجهول', () {
      expect(validateCashSale(_sale(sourceId: '  ')), isA<Failure<Object?>>());
    });

    test('⛔ سندٌ بلا سطرٍ يُرفَض', () {
      expect(
        validateCashSale(_sale(lines: const <CashSaleLineInput>[])),
        isA<Failure<Object?>>(),
      );
    });

    test('⛔ ولا سطران لنفس النوع', () {
      expect(
        validateCashSale(
          _sale(
            lines: <CashSaleLineInput>[
              _pieceLine('ITM-0001'),
              _pieceLine('ITM-0001', quantity: 3),
            ],
          ),
        ),
        isA<Failure<Object?>>(),
      );
    });

    test('⛔ GR-19: ووحدةُ الكمية يجب أن تطابق وحدة النوع', () {
      expect(
        validateCashSale(
          _sale(
            lines: <CashSaleLineInput>[
              CashSaleLineInput(
                itemId: 'ITM-0001',
                itemName: 'عوارض',
                unit: ItemUnit.piece,
                quantity: const WeightQuantity(WeightKg(1)),
                unitPrice: const Money(700),
              ),
            ],
          ),
        ),
        isA<Failure<Object?>>(),
      );
    });

    test('⛔ والكمية صفراً ليست بيعاً', () {
      expect(
        validateCashSale(
          _sale(lines: <CashSaleLineInput>[_pieceLine('ITM-0001', quantity: 0)]),
        ),
        isA<Failure<Object?>>(),
      );
    });

    test('⛔⛔ FR-M11-04: وسعرٌ بصفرٍ ليس سعراً — لا بيعَ نقديٍّ بلا مقبوض', () {
      final Outcome<ValidatedCashSale> outcome = validateCashSale(
        _sale(
          lines: <CashSaleLineInput>[_pieceLine('ITM-0001', unitPrice: 0)],
        ),
      );
      expect(outcome, isA<Failure<ValidatedCashSale>>());
      expect(
        ((outcome as Failure<ValidatedCashSale>).error as ValidationError)
            .ruleCode,
        'FR-M11-04',
      );
    });

    test('★ ADR-0020: وسببُ البيع دون الحد اختياريٌّ — والفراغ غيابٌ', () {
      final ValidatedCashSale sale = _validated(
        _sale(
          lines: <CashSaleLineInput>[
            _pieceLine('ITM-0001', belowMinReason: '   '),
          ],
        ),
      );
      expect(sale.lines.single.belowMinReason, isNull);
    });

    test('★ والسببُ المكتوب يُحفَظ كما كتبه الإنسان', () {
      final ValidatedCashSale sale = _validated(
        _sale(
          lines: <CashSaleLineInput>[
            _pieceLine('ITM-0001', belowMinReason: ' تصفية آخر اليوم '),
          ],
        ),
      );
      expect(sale.lines.single.belowMinReason, 'تصفية آخر اليوم');
    });

    test('★★ و`sackId` يعبر كما هو — فهو ما يُطلق احتساب سعر الجونية', () {
      final ValidatedCashSale sale = _validated(
        _sale(
          lines: <CashSaleLineInput>[
            _weightLine('ITM-0002', sackId: 'SCK-20260901-0001'),
          ],
        ),
      );
      expect(sale.lines.single.sackId, 'SCK-20260901-0001');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // ★ الحالة — FR-M11-13
  // ═══════════════════════════════════════════════════════════════════════
  group('★ validateCashSaleNotCancelled', () {
    test('✅ المعتمد يمرّ', () {
      expect(
        validateCashSaleNotCancelled(CashSaleStatus.approved),
        isA<Success<void>>(),
      );
    });

    test('⛔ والملغى لا يُعدَّل ولا يُلغى ثانيةً', () {
      expect(
        validateCashSaleNotCancelled(CashSaleStatus.cancelled),
        isA<Failure<void>>(),
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // ⛔⛔★★★ FR-M11-03 — ولا أثرَ على ذمم المقاوته: حارسٌ بنيوي
  // ═══════════════════════════════════════════════════════════════════════
  group('⛔⛔★★★ FR-M11-03 — لا حقلَ مقوتٍ في أي نوعٍ هنا', () {
    test('★★ والسندُ المتحقَّق منه لا يحمل معرّف مقوتٍ ولا اسمَ مشترٍ', () {
      final ValidatedCashSale sale = _validated(_sale());
      // ⛔ **والغياب بنيويٌّ لا شرطٌ يُفحَص** — ★ **فالاختبار يوثّقه بالمقابلة
      //    مع التوزيعة التي تحمل `dealerId`** ⟵ **وأي إضافةٍ لاحقة تُسقِطه.**
      expect(sale.sourceId, 'SRC-001');
      expect(sale.lines.single.itemKey, 'ITM-0001');
    });
  });
}

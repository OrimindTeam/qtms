import 'package:qtms_domain/qtms_domain.dart';
import 'package:test/test.dart';

DailyPriceLineInput _line(
  String itemId, {
  String name = 'عوارض',
  ItemUnit unit = ItemUnit.piece,
  int? distribution,
  int? minimum,
}) =>
    DailyPriceLineInput(
      itemId: itemId,
      itemName: name,
      unit: unit,
      distributionPrice: distribution == null ? null : Money(distribution),
      minCashPrice: minimum == null ? null : Money(minimum),
    );

DailyPriceBatchInput _batch({
  String sourceId = 'SRC-001',
  List<DailyPriceLineInput>? lines,
}) =>
    DailyPriceBatchInput(
      sourceId: sourceId,
      lines: lines ??
          <DailyPriceLineInput>[
            _line('ITM-0001', distribution: 1200, minimum: 1000),
          ],
    );

ValidatedDailyPriceBatch _ok(Outcome<ValidatedDailyPriceBatch> outcome) =>
    (outcome as Success<ValidatedDailyPriceBatch>).value;

String _ruleOf(Outcome<ValidatedDailyPriceBatch> outcome) =>
    ((outcome as Failure<ValidatedDailyPriceBatch>).error as ValidationError)
        .ruleCode;

void main() {
  group('dailyPriceId — المفتاح المركّب (naming-conventions §4)', () {
    test('★ FR-M9-01 · FR-M9-03: المصدر والنوع واليوم في المفتاح بترتيبه', () {
      expect(
        dailyPriceId(
          sourceId: 'SRC-001',
          itemKey: 'ITM-0007',
          date: CalendarDay(2026, 8, 25),
        ),
        'SRC-001_ITM-0007_20260825',
      );
    });

    test('★★ GR-31: يومٌ آخر ⟵ مفتاحٌ آخر — فالتصفير اليومي بنيوي', () {
      final String today = dailyPriceId(
        sourceId: 'SRC-001',
        itemKey: 'ITM-0007',
        date: CalendarDay(2026, 8, 25),
      );
      final String tomorrow = dailyPriceId(
        sourceId: 'SRC-001',
        itemKey: 'ITM-0007',
        date: CalendarDay(2026, 8, 26),
      );
      expect(today, isNot(tomorrow));
    });

    test('★★ A-01: مصدرٌ آخر ⟵ مفتاحٌ آخر — فتسعير رداع لا يُسعِّر ماوية', () {
      expect(
        dailyPriceId(
          sourceId: 'SRC-002',
          itemKey: 'ITM-0007',
          date: CalendarDay(2026, 8, 25),
        ),
        isNot(
          dailyPriceId(
            sourceId: 'SRC-001',
            itemKey: 'ITM-0007',
            date: CalendarDay(2026, 8, 25),
          ),
        ),
      );
    });

    test('⛔ ويرفض المصدر أو النوع الفارغ — لا يبني مفتاحاً ناقصاً', () {
      expect(
        () => dailyPriceId(
          sourceId: '',
          itemKey: 'ITM-0001',
          date: CalendarDay(2026, 8, 25),
        ),
        throwsArgumentError,
      );
      expect(
        () => dailyPriceId(
          sourceId: 'SRC-001',
          itemKey: '',
          date: CalendarDay(2026, 8, 25),
        ),
        throwsArgumentError,
      );
    });
  });

  group('isPricingComplete — FR-M9-05', () {
    test('★ السعران معاً ⟵ تم التسعير', () {
      expect(
        isPricingComplete(
          distributionPrice: const Money(1200),
          minCashPrice: const Money(1000),
        ),
        isTrue,
      );
    });

    test('⛔ ونصفُ التسعير ليس تسعيراً — في الاتجاهين معاً (FR-M9-10)', () {
      expect(
        isPricingComplete(
          distributionPrice: const Money(1200),
          minCashPrice: null,
        ),
        isFalse,
      );
      expect(
        isPricingComplete(
          distributionPrice: null,
          minCashPrice: const Money(1000),
        ),
        isFalse,
      );
      expect(
        isPricingComplete(distributionPrice: null, minCashPrice: null),
        isFalse,
      );
    });
  });

  group('PricingStatusFilter — FR-M9-05', () {
    test('★ الكل يقبل الحالتين، وكلٌّ من الآخرين يقبل حالته وحدها', () {
      expect(PricingStatusFilter.all.accepts(complete: true), isTrue);
      expect(PricingStatusFilter.all.accepts(complete: false), isTrue);
      expect(PricingStatusFilter.priced.accepts(complete: true), isTrue);
      expect(PricingStatusFilter.priced.accepts(complete: false), isFalse);
      expect(PricingStatusFilter.unpriced.accepts(complete: false), isTrue);
      expect(PricingStatusFilter.unpriced.accepts(complete: true), isFalse);
    });
  });

  group('validateDailyPrices — FR-M9', () {
    test('يقبل دفعةً صحيحة ويُرتّب سطورها بمفتاح النوع', () {
      final ValidatedDailyPriceBatch batch = _ok(
        validateDailyPrices(
          _batch(
            lines: <DailyPriceLineInput>[
              _line('ITM-0009', distribution: 900, minimum: 800),
              _line('ITM-0001', distribution: 1200, minimum: 1000),
            ],
          ),
        ),
      );
      expect(
        batch.lines.map((ValidatedDailyPriceLine l) => l.itemKey).toList(),
        <String>['ITM-0001', 'ITM-0009'],
      );
      expect(batch.sourceId, 'SRC-001');
      expect(batch.lines.every((ValidatedDailyPriceLine l) => l.complete),
          isTrue);
    });

    test('★ FR-M9-03: المصدر إلزامي — ولا سعرَ بلا مصدرٍ يخصّه', () {
      expect(_ruleOf(validateDailyPrices(_batch(sourceId: '   '))), 'FR-M9-03');
    });

    test('⛔ ودفعةٌ بلا سطور تُرفَض — لا تكتب شيئاً فلا معنى لها', () {
      expect(
        _ruleOf(
          validateDailyPrices(_batch(lines: const <DailyPriceLineInput>[])),
        ),
        'FR-M9-01',
      );
    });

    test('★★ BR-M9-04: لا سطران لنفس النوع — وإلا غلب آخرُهما أولَه بصمت', () {
      expect(
        _ruleOf(
          validateDailyPrices(
            _batch(
              lines: <DailyPriceLineInput>[
                _line('ITM-0001', distribution: 1200, minimum: 1000),
                _line('ITM-0001', distribution: 1300, minimum: 1100),
              ],
            ),
          ),
        ),
        'BR-M9-04',
      );
    });

    test('⛔ واسم النوع الفارغ يُرفَض — النسخة المعروضة مقصودة', () {
      expect(
        _ruleOf(
          validateDailyPrices(
            _batch(
              lines: <DailyPriceLineInput>[
                _line('ITM-0001', name: '  ', distribution: 1200),
              ],
            ),
          ),
        ),
        'FR-M9-01',
      );
    });

    test('★★ BR-M9-06: السعر السالب مرفوض — في الحقلين معاً', () {
      expect(
        _ruleOf(
          validateDailyPrices(
            _batch(
              lines: <DailyPriceLineInput>[_line('ITM-0001', distribution: -1)],
            ),
          ),
        ),
        'BR-M9-06',
      );
      expect(
        _ruleOf(
          validateDailyPrices(
            _batch(
              lines: <DailyPriceLineInput>[_line('ITM-0001', minimum: -5)],
            ),
          ),
        ),
        'BR-M9-06',
      );
    });

    test('⛔⛔ FR-M9-08 · GR-34: والصفر مرفوض — وإلا أسقط الحدَّ الأدنى بصمت',
        () {
      expect(
        _ruleOf(
          validateDailyPrices(
            _batch(
              lines: <DailyPriceLineInput>[
                _line('ITM-0001', distribution: 1200, minimum: 0),
              ],
            ),
          ),
        ),
        'BR-M9-06',
      );
    });

    test('★ والغياب (null) مقبول — وهو التعبير الصحيح عن «بلا سعر»', () {
      final ValidatedDailyPriceBatch batch = _ok(
        validateDailyPrices(
          _batch(lines: <DailyPriceLineInput>[_line('ITM-0001')]),
        ),
      );
      final ValidatedDailyPriceLine line = batch.lines.single;
      expect(line.distributionPrice, isNull);
      expect(line.minCashPrice, isNull);
      expect(line.isCleared, isTrue);
      expect(line.complete, isFalse);
    });

    test('★ ونصفُ تسعيرٍ يُقبَل كتابةً ويبقى «غير مسعَّر» (FR-M9-10)', () {
      final ValidatedDailyPriceLine line = _ok(
        validateDailyPrices(
          _batch(
            lines: <DailyPriceLineInput>[_line('ITM-0001', distribution: 1200)],
          ),
        ),
      ).lines.single;
      expect(line.distributionPrice, const Money(1200));
      expect(line.complete, isFalse);
      expect(line.isCleared, isFalse);
    });

    test('★ FR-M9-06: وحدة النوع تُنقَل كما هي — سعر كيلو للسكرب', () {
      final ValidatedDailyPriceLine line = _ok(
        validateDailyPrices(
          _batch(
            lines: <DailyPriceLineInput>[
              _line(
                'ITM-0002',
                name: 'السكرب',
                unit: ItemUnit.kilogram,
                distribution: 700,
                minimum: 600,
              ),
            ],
          ),
        ),
      ).lines.single;
      expect(line.unit, ItemUnit.kilogram);
    });

    test('★ coding-standards §2.7: نفس المُدخَل يُنتج نفس الدفعة حرفياً', () {
      List<String> keysOf(ValidatedDailyPriceBatch b) =>
          b.lines.map((ValidatedDailyPriceLine l) => l.itemKey).toList();
      final DailyPriceBatchInput input = _batch(
        lines: <DailyPriceLineInput>[
          _line('ITM-0009', distribution: 900, minimum: 800),
          _line('ITM-0001', distribution: 1200, minimum: 1000),
        ],
      );
      expect(
        keysOf(_ok(validateDailyPrices(input))),
        keysOf(_ok(validateDailyPrices(input))),
      );
    });
  });

  group('changesStoredPrice — ADR-0004 · CR-002 · FR-M9-11', () {
    ValidatedDailyPriceLine lineOf({int? distribution, int? minimum}) => _ok(
          validateDailyPrices(
            _batch(
              lines: <DailyPriceLineInput>[
                _line(
                  'ITM-0001',
                  distribution: distribution,
                  minimum: minimum,
                ),
              ],
            ),
          ),
        ).lines.single;

    test('★★ سجلٌّ غائب ⟵ إنشاءٌ خالص، فلا يُطالَب بعلّة (FR-M9-01)', () {
      expect(
        changesStoredPrice(
          line: lineOf(distribution: 1200, minimum: 1000),
          stored: null,
        ),
        isFalse,
      );
    });

    test('★★ وسعرٌ قائم تغيّر ⟵ تعديلٌ يشترط السبب', () {
      expect(
        changesStoredPrice(
          line: lineOf(distribution: 1300, minimum: 1000),
          stored: <String, Object?>{
            'distributionPrice': 1200,
            'minCashPrice': 1000,
          },
        ),
        isTrue,
      );
    });

    test('★★★ وإعادةُ إرسال نفس الأسعار ليست تعديلاً — §2.7 حرفياً', () {
      expect(
        changesStoredPrice(
          line: lineOf(distribution: 1200, minimum: 1000),
          stored: <String, Object?>{
            'distributionPrice': 1200,
            'minCashPrice': 1000,
          },
        ),
        isFalse,
      );
    });

    test('★ والقاعدة قد تُعيد الصحيح عشرياً — فـ1200.0 يساوي 1200', () {
      expect(
        changesStoredPrice(
          line: lineOf(distribution: 1200, minimum: 1000),
          stored: <String, Object?>{
            'distributionPrice': 1200.0,
            'minCashPrice': 1000.0,
          },
        ),
        isFalse,
      );
    });

    test('★★ والتفريغ تعديلٌ أيضاً — إسقاط سعرٍ قائم يُسجَّل بقيمته قبل', () {
      expect(
        changesStoredPrice(
          line: lineOf(),
          stored: <String, Object?>{
            'distributionPrice': 1200,
            'minCashPrice': 1000,
          },
        ),
        isTrue,
      );
    });

    test('★ وإضافةُ الحد الأدنى إلى سجلٍ نصفِ مسعَّر تعديل', () {
      expect(
        changesStoredPrice(
          line: lineOf(distribution: 1200, minimum: 1000),
          stored: <String, Object?>{'distributionPrice': 1200},
        ),
        isTrue,
      );
    });
  });

  group('DailyPriceCard — البطاقة المقروءة', () {
    // ★ يومٌ ثابت — ⛔ **فلا اختبارَ ينكسر بمرور منتصف الليل**.
    final CalendarDay day = CalendarDay(2026, 8, 25);

    test('★ complete تُشتقّ من السعرين ⛔ لا من الحقل المخزَّن', () {
      final DailyPriceCard card = DailyPriceCard(
        sourceId: 'SRC-001',
        itemKey: 'ITM-0001',
        itemName: 'عوارض',
        unit: ItemUnit.piece,
        date: day,
        distributionPrice: const Money(1200),
        minCashPrice: const Money(1000),
      );
      expect(card.complete, isTrue);
    });

    test('★ وبطاقةٌ بلا حدٍّ أدنى غير مسعَّرة', () {
      final DailyPriceCard card = DailyPriceCard(
        sourceId: 'SRC-001',
        itemKey: 'ITM-0001',
        itemName: 'عوارض',
        unit: ItemUnit.piece,
        date: day,
        distributionPrice: const Money(1200),
      );
      expect(card.complete, isFalse);
    });
  });
}

/// الإتلاف — **طبقة النطاق** (`WU-020` · `FR-M8-16` · `BR-M8-11`).
///
/// ⛔⛔★★★ **وأولُ ما يُحرَس هنا بنيويٌّ لا شرطيّ:** ★ **لا نوعَ في هذا
/// الملفِّ يحمل مبلغاً** — ⟵ **فاختبارُ «لا حقلَ ماليّ» في السحابة يُقاس
/// على الكتابات**، ★ **وهنا يُقاس على العقد نفسِه** (`FR-M8-16`).
library;

import 'package:qtms_domain/qtms_domain.dart';
import 'package:test/test.dart';

const String sourceA = 'SRC-001';
const String itemA = 'ITM-0001';
const String itemB = 'ITM-0002';

DisposalLineInput line({
  String itemId = itemA,
  int quantity = 5,
  ItemUnit unit = ItemUnit.piece,
  StockQuantity? amount,
  String name = 'عوارض',
  String? sackId,
}) =>
    DisposalLineInput(
      itemId: itemId,
      itemName: name,
      unit: unit,
      quantity: amount ?? PieceQuantity(PieceCount(quantity)),
      sackId: sackId,
    );

ValidatedDisposal ok(Outcome<ValidatedDisposal> outcome) {
  expect(outcome, isA<Success<ValidatedDisposal>>(), reason: 'رُفض ما يُقبَل');
  return (outcome as Success<ValidatedDisposal>).value;
}

String ruleOf(Outcome<ValidatedDisposal> outcome) {
  expect(outcome, isA<Failure<ValidatedDisposal>>(), reason: 'قُبل ما يُرفَض');
  final AppError error = (outcome as Failure<ValidatedDisposal>).error;
  return (error as ValidationError).ruleCode;
}

void main() {
  group('★★★ FR-M8-16 — مستندُ إتلافٍ صحيح', () {
    test('✅ مستندٌ بسطرٍ واحد يُقبَل — والسطورُ مرتَّبةٌ بمفتاح النوع', () {
      final ValidatedDisposal disposal = ok(
        validateDisposal(
          DisposalInput(
            sourceId: sourceA,
            lines: <DisposalLineInput>[
              line(itemId: itemB),
              line(itemId: itemA),
            ],
          ),
        ),
      );
      expect(
        disposal.lines.map((ValidatedDisposalLine l) => l.itemKey).toList(),
        <String>[itemA, itemB],
      );
    });

    test('★★ والإجماليان منفصلان — ⛔ ولا تُجمع حبّةٌ مع كيلوجرام (GR-19)', () {
      final ValidatedDisposal disposal = ok(
        validateDisposal(
          DisposalInput(
            sourceId: sourceA,
            lines: <DisposalLineInput>[
              line(quantity: 12),
              line(
                itemId: itemB,
                unit: ItemUnit.kilogram,
                amount: const WeightQuantity(WeightKg(1.250)),
              ),
            ],
          ),
        ),
      );
      expect(disposal.totalPieces.pieces, 12);
      expect(disposal.totalWeight.kilograms, 1.250);
    });

    test('★ ومفتاحُ النوع هو معرّفه لا اسمه — FR-M5-01', () {
      final ValidatedDisposal disposal =
          ok(validateDisposal(DisposalInput(sourceId: sourceA,
              lines: <DisposalLineInput>[line(name: 'عوارض حمراء')])));
      expect(disposal.lines.single.itemKey, itemA);
      expect(disposal.lines.single.itemName, 'عوارض حمراء');
    });

    test('★★ ومرجعُ الجونية يُحفَظ — لتقرير R-07 بلا أثرٍ في سعرها', () {
      final ValidatedDisposal disposal = ok(
        validateDisposal(
          DisposalInput(
            sourceId: sourceA,
            lines: <DisposalLineInput>[line(sackId: 'SCK-20260904-0001')],
          ),
        ),
      );
      expect(disposal.lines.single.sackId, 'SCK-20260904-0001');
    });
  });

  group('★★★ الرفض — ستةُ قيود', () {
    test('⛔ مصدرٌ فارغ يُرفَض — ولا «مصدر افتراضي» يُملأ', () {
      expect(
        ruleOf(
          validateDisposal(
            DisposalInput(
              sourceId: '   ',
              lines: <DisposalLineInput>[line()],
            ),
          ),
        ),
        'BR-M8-11',
      );
    });

    test('⛔ ومستندٌ بلا سطرٍ يُرفَض — لا يُتلِف شيئاً', () {
      expect(
        ruleOf(validateDisposal(const DisposalInput(sourceId: sourceA))),
        'FR-M8-16',
      );
    });

    test('⛔ وسطران لنفس النوع يُرفَضان', () {
      expect(
        ruleOf(
          validateDisposal(
            DisposalInput(
              sourceId: sourceA,
              lines: <DisposalLineInput>[line(), line()],
            ),
          ),
        ),
        'BR-M10-15',
      );
    });

    test('⛔ وكميةُ صفرٍ ليست إتلافاً', () {
      expect(
        ruleOf(
          validateDisposal(
            DisposalInput(
              sourceId: sourceA,
              lines: <DisposalLineInput>[line(quantity: 0)],
            ),
          ),
        ),
        'BR-M8-11',
      );
    });

    test('⛔ والسالبُ إدخالٌ لا إتلاف', () {
      expect(
        ruleOf(
          validateDisposal(
            DisposalInput(
              sourceId: sourceA,
              lines: <DisposalLineInput>[line(quantity: -3)],
            ),
          ),
        ),
        'BR-M8-11',
      );
    });

    test('⛔ ووحدةُ الكمية تخالف وحدةَ النوع — GR-19', () {
      expect(
        ruleOf(
          validateDisposal(
            DisposalInput(
              sourceId: sourceA,
              lines: <DisposalLineInput>[
                line(
                  unit: ItemUnit.kilogram,
                  amount: const PieceQuantity(PieceCount(4)),
                ),
              ],
            ),
          ),
        ),
        'GR-19',
      );
    });

    test('⛔ واسمُ نوعٍ فارغ يُرفَض', () {
      expect(
        ruleOf(
          validateDisposal(
            DisposalInput(
              sourceId: sourceA,
              lines: <DisposalLineInput>[line(name: '  ')],
            ),
          ),
        ),
        'FR-M8-16',
      );
    });
  });

  group('★★★ ADR-0020 — السببُ اختياريٌّ والفراغُ غياب', () {
    test('✅ بلا سببٍ يمرّ — ولا نصَّ يُعبَّأ نيابةً عن المستخدم', () {
      expect(
        ok(
          validateDisposal(
            DisposalInput(
              sourceId: sourceA,
              lines: <DisposalLineInput>[line()],
            ),
          ),
        ).reason,
        isNull,
      );
    });

    test('✅ والفراغاتُ تُقرأ غياباً لا نصّاً فارغاً', () {
      expect(
        ok(
          validateDisposal(
            DisposalInput(
              sourceId: sourceA,
              lines: <DisposalLineInput>[line()],
              reason: '    ',
            ),
          ),
        ).reason,
        isNull,
      );
    });

    test('✅ وسببٌ مكتوبٌ يُحفَظ مُشذَّباً', () {
      expect(
        ok(
          validateDisposal(
            DisposalInput(
              sourceId: sourceA,
              lines: <DisposalLineInput>[line()],
              reason: '  تلف بالحرارة  ',
            ),
          ),
        ).reason,
        'تلف بالحرارة',
      );
    });

    test('⛔ وسببٌ يتجاوز الحد يُرفَض', () {
      expect(
        ruleOf(
          validateDisposal(
            DisposalInput(
              sourceId: sourceA,
              lines: <DisposalLineInput>[line()],
              reason: 'ت' * (freeTextMaxLength + 1),
            ),
          ),
        ),
        'GR-49',
      );
    });
  });

  group('★★★ design-overview §2.10 — نسبة الإتلاف ٪', () {
    test('★★ (المُتلَف ÷ الوارد) × 100 — بالحبّة', () {
      expect(
        disposalRatePercent(
          disposed: const PieceQuantity(PieceCount(5)),
          incoming: const PieceQuantity(PieceCount(200)),
        ),
        2.5,
      );
    });

    test('★★ وبالكيلوجرام كذلك', () {
      expect(
        disposalRatePercent(
          disposed: const WeightQuantity(WeightKg(1.5)),
          incoming: const WeightQuantity(WeightKg(30)),
        ),
        5,
      );
    });

    test('⛔⛔★★ ووارِدُ صفرٍ يُرجِع `null` — ⛔ لا صفراً يُقرأ «لا إتلاف»', () {
      expect(
        disposalRatePercent(
          disposed: const PieceQuantity(PieceCount(5)),
          incoming: const PieceQuantity(PieceCount.zero),
        ),
        isNull,
      );
    });

    test('⛔⛔★★ ووحدتان مختلفتان تُرجِعان `null` — ولا تُجمعان (GR-19)', () {
      expect(
        disposalRatePercent(
          disposed: const PieceQuantity(PieceCount(5)),
          incoming: const WeightQuantity(WeightKg(30)),
        ),
        isNull,
      );
    });
  });

  group('★ ثوابتُ العقد', () {
    test('★ اسمُ المجموعة `disposals` — naming-conventions §4', () {
      expect(disposalsCollection, 'disposals');
    });

    test('★★ وبادئةُ الرقم `DSP` بأربع خانات', () {
      expect(DocumentKind.disposal.prefix, 'DSP');
      expect(DocumentKind.disposal.sequenceWidth, 4);
    });

    test('★★ ويقبل تاريخاً سابقاً — فهو ثالثُ إجراءات التصريف (FR-M8-11)', () {
      expect(allowsBackdating(DocumentKind.disposal), isTrue);
    });

    test('★★ وحالتان لا أكثر — والإلغاءُ بالوسم', () {
      expect(DisposalStatus.values, hasLength(2));
    });
  });
}

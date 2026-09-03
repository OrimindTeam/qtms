@TestOn('vm')
library;

import 'package:qtms_domain/qtms_domain.dart';
import 'package:test/test.dart';

/// ★ سطرٌ وزنيٌّ بوزن حبة في التهيئة — **الحالة ① من الجدول الثلاثي**.
SackLineInput _configured({
  String itemId = 'ITM-0001',
  String itemName = 'بطوة معالم أحمر',
  int quantity = 100,
  double configured = 200,
  double? manual,
}) =>
    SackLineInput(
      itemId: itemId,
      itemName: itemName,
      nature: ItemNature.weightBased,
      unit: ItemUnit.piece,
      quantity: quantity,
      configuredPieceWeightGrams: configured,
      pieceWeightGrams: manual,
    );

/// ★ سطرٌ عدديّ — **الحالة ③**: الوزن الكلي يدوي ووزن الحبة مُستنتَج.
SackLineInput _counted({
  String itemId = 'ITM-0002',
  String itemName = 'عادي',
  int quantity = 250,
  double? total = 15,
}) =>
    SackLineInput(
      itemId: itemId,
      itemName: itemName,
      nature: ItemNature.countBased,
      unit: ItemUnit.piece,
      quantity: quantity,
      lineTotalWeight: total,
    );

SackIntakeInput _intake({
  double total = 45,
  double ice = 6.5,
  double scrap = 1.2,
  List<SackLineInput> lines = const <SackLineInput>[],
  bool requiresSupplier = true,
  String? supplierId = 'SUP-0001',
  bool lostConfirmed = false,
}) =>
    SackIntakeInput(
      sourceId: 'SRC-001',
      sourceRequiresSupplier: requiresSupplier,
      supplierId: supplierId,
      weights: SackWeightsInput(
        totalWeight: WeightKg(total),
        iceWeight: WeightKg(ice),
        scrapWeight: WeightKg(scrap),
      ),
      lines: lines,
      lostWeightConfirmed: lostConfirmed,
    );

T _ok<T>(Outcome<T> outcome) {
  expect(outcome, isA<Success<T>>(),
      reason: 'توقّعنا نجاحاً — والفشل هنا يعني قاعدةً فُرضت خطأً');
  return (outcome as Success<T>).value;
}

String _ruleOf(Outcome<Object?> outcome) {
  expect(outcome, isA<Failure<Object?>>(), reason: 'توقّعنا رفضاً');
  final AppError error = (outcome as Failure<Object?>).error;
  expect(error, isA<ValidationError>());
  return (error as ValidationError).ruleCode;
}

void main() {
  // ═══════════════════════════════════════════════════════════════════════
  group('FR-M7-06 … FR-M7-08 — أوزان الرأس', () {
    test('★ AT-06: 45.000 − 6.500 − 1.200 = 37.300 مطالباً به', () {
      final ValidatedSackWeights weights = _ok(
        validateSackWeights(
          const SackWeightsInput(
            totalWeight: WeightKg(45),
            iceWeight: WeightKg(6.5),
            scrapWeight: WeightKg(1.2),
          ),
        ),
      );
      expect(weights.claimableWeight.formatted(), '37.300');
    });

    test('⛔★★ BR-M7-07: الكلي ≤ الثلج + السكرب ⟵ يُرفَض الحفظ', () {
      expect(
        _ruleOf(
          validateSackWeights(
            const SackWeightsInput(
              totalWeight: WeightKg(10),
              iceWeight: WeightKg(6),
              scrapWeight: WeightKg(4),
            ),
          ),
        ),
        'BR-M7-07',
      );
    });

    test('⛔★★ والقيد صارمٌ لا «≥» — فالمساواة تماماً تُرفَض كذلك', () {
      // ★ حارسٌ على القيد نفسه: نصّ `FR-M7-07` «**أكبر من**» — ⟵ ومساواةٌ
      //   تعني مطالباً به صفراً، ⛔ وهو مستندٌ بلا معنى محاسبي.
      expect(
        _ruleOf(
          validateSackWeights(
            const SackWeightsInput(
              totalWeight: WeightKg(10),
              iceWeight: WeightKg(6),
              scrapWeight: WeightKg(4.0),
            ),
          ),
        ),
        'BR-M7-07',
      );
    });

    test('⛔ والوزن السالب يُرفَض قبل أي قيد آخر', () {
      expect(
        _ruleOf(
          validateSackWeights(
            const SackWeightsInput(
              totalWeight: WeightKg(45),
              iceWeight: WeightKg(-1),
              scrapWeight: WeightKg(0),
            ),
          ),
        ),
        'FR-M7-06',
      );
    });

    test('★ والسكرب صفراً حالةٌ صحيحة — فهو افتراضه', () {
      final ValidatedSackWeights weights = _ok(
        validateSackWeights(
          const SackWeightsInput(
            totalWeight: WeightKg(20),
            iceWeight: WeightKg(2),
            scrapWeight: WeightKg.zero,
          ),
        ),
      );
      expect(weights.claimableWeight.formatted(), '18.000');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('★★★ FR-M7-13 — جدول وزن الحبة بحالاته الثلاث', () {
    test('① وزني + تهيئة: AT-08 — 100 × 200جم = 20.000 كجم محسوباً', () {
      final ValidatedSackLine line = _ok(resolveSackLine(_configured()));
      expect(line.lineTotalWeight.formatted(), '20.000');
      expect(line.pieceWeightGrams, 200);
      expect(line.pieceWeightOrigin, PieceWeightOrigin.configured);
    });

    test('① والتعديل المحلي يعلو على التهيئة ويُوسَم `manual`', () {
      final ValidatedSackLine line =
          _ok(resolveSackLine(_configured(manual: 250)));
      expect(line.pieceWeightGrams, 250);
      expect(line.pieceWeightOrigin, PieceWeightOrigin.manual);
      expect(line.lineTotalWeight.formatted(), '25.000');
    });

    test('★ ويُوسَم `manual` ولو طابق التهيئة — فالتدقيق يقرأ المصدر', () {
      // ⛔ الرقم نفسه، **والمصدر مختلف** — ⟵ وحقل `pieceWeightOrigin` وُجد
      //   ليكشف هذا بالضبط (`sack-intake-design.md` §4).
      final ValidatedSackLine line =
          _ok(resolveSackLine(_configured(manual: 200)));
      expect(line.pieceWeightOrigin, PieceWeightOrigin.manual);
    });

    test('⛔★★★ ② E-08 · FR-M7-14: وزنيٌّ بلا وزن حبة ⟵ يُرفَض ولا يُستنتَج',
        () {
      expect(
        _ruleOf(
          resolveSackLine(
            const SackLineInput(
              itemId: 'ITM-0001',
              itemName: 'بطوة',
              nature: ItemNature.weightBased,
              unit: ItemUnit.piece,
              quantity: 100,
              // ⛔ ولا وزن حبة — لا في التهيئة ولا يدوياً.
              lineTotalWeight: 20,
            ),
          ),
        ),
        'E-08',
      );
    });

    test('③ AT-09: 250 حبة و15.000 كجم ⟵ 60 جم مستنتَجاً', () {
      final ValidatedSackLine line = _ok(resolveSackLine(_counted()));
      expect(line.pieceWeightGrams, closeTo(60, 1e-9));
      expect(line.pieceWeightOrigin, PieceWeightOrigin.inferred);
      expect(line.lineTotalWeight.formatted(), '15.000');
    });

    test('⛔ ③ E-09: عدديٌّ أُدخل له وزن حبة ⟵ يُرفَض — الحقل مقفل', () {
      expect(
        _ruleOf(
          resolveSackLine(
            const SackLineInput(
              itemId: 'ITM-0002',
              itemName: 'عادي',
              nature: ItemNature.countBased,
              unit: ItemUnit.piece,
              quantity: 250,
              pieceWeightGrams: 60,
              lineTotalWeight: 15,
            ),
          ),
        ),
        'E-09',
      );
    });

    test('⛔ ③ وعدديٌّ بلا وزن كلي ⟵ يُرفَض (ERR_INTAKE_006)', () {
      expect(_ruleOf(resolveSackLine(_counted(total: null))), 'FR-M7-13');
    });

    test('⛔ والعدد غير الموجب يُرفَض في الحالتين', () {
      expect(_ruleOf(resolveSackLine(_configured(quantity: 0))), 'BR-M6-06');
      expect(_ruleOf(resolveSackLine(_counted(quantity: -5))), 'BR-M6-06');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('★★★ FR-M7-17 — الحاسبة الحيّة وحالة تفسير الوزن', () {
    test('★ AT-10: 37.300 − 35.000 = 2.300 متبقياً · والحالة «غير مفسَّر»', () {
      final ValidatedSackWeights weights = _ok(
        validateSackWeights(
          const SackWeightsInput(
            totalWeight: WeightKg(45),
            iceWeight: WeightKg(6.5),
            scrapWeight: WeightKg(1.2),
          ),
        ),
      );
      // 100 × 350جم = 35.000 كجم.
      final ValidatedSackLine line =
          _ok(resolveSackLine(_configured(configured: 350)));

      final SackWeightExplanation explanation = explainSackWeight(
        weights: weights,
        lines: <ValidatedSackLine>[line],
      );
      expect(explanation.explainedWeight.formatted(), '35.000');
      expect(explanation.remainingWeight.formatted(), '2.300');
      expect(explanation.state, SackWeightState.unexplained);
      // ⛔★★ BR-M7-12 — ولا وزنَ ضائعاً بلا تأكيد.
      expect(explanation.lostWeight.kilograms, 0);
    });

    test('★★ AT-11 · E-10: التأكيد الصريح وحده يُحوّله إلى «ضائع مؤكَّد»', () {
      final ValidatedSackWeights weights = _ok(
        validateSackWeights(
          const SackWeightsInput(
            totalWeight: WeightKg(45),
            iceWeight: WeightKg(6.5),
            scrapWeight: WeightKg(1.2),
          ),
        ),
      );
      final ValidatedSackLine line =
          _ok(resolveSackLine(_configured(configured: 350)));

      final SackWeightExplanation confirmed = explainSackWeight(
        weights: weights,
        lines: <ValidatedSackLine>[line],
        lostWeightConfirmed: true,
      );
      expect(confirmed.state, SackWeightState.lostConfirmed);
      expect(confirmed.lostWeight.formatted(), '2.300');
      // ★ النسبة للعرض وحدها ⛔ ولا تُخزَّن.
      expect(confirmed.lostWeightPercentage, closeTo(6.166, 0.001));
    });

    test('★★ والمتبقي الصفري يُقرأ «مفسَّراً بالكامل» رغم بقايا العشري', () {
      // ⚠️ 37.300 − (3 × 12.4333…) تُنتج بقيةً من رتبة 1e-15 — ★ والهامش
      //   وحده يمنع بقاء جونيةٍ مفسَّرةٍ في حالة «غير مفسَّر» أبداً.
      final ValidatedSackWeights weights = _ok(
        validateSackWeights(
          const SackWeightsInput(
            // 3 سطور × (10000/3 جم لحبةٍ واحدة) = 10.000 كجم بالضبط.
            totalWeight: WeightKg(10),
            iceWeight: WeightKg(0),
            scrapWeight: WeightKg(0),
          ),
        ),
      );
      final List<ValidatedSackLine> lines = <ValidatedSackLine>[
        for (int i = 0; i < 3; i++)
          _ok(
            resolveSackLine(
              _configured(
                itemId: 'ITM-000$i',
                quantity: 1,
                configured: 10000 / 3,
              ),
            ),
          ),
      ];
      final SackWeightExplanation explanation =
          explainSackWeight(weights: weights, lines: lines);
      expect(explanation.state, SackWeightState.fullyExplained);
      expect(explanation.remainingWeight.kilograms, 0);
    });

    test('⛔★ وتأكيدٌ بلا متبقٍّ ليس تأكيداً — فلا وسمَ كاذب', () {
      final ValidatedSackIntake intake = _ok(
        validateSackIntake(
          _intake(
            total: 20.2,
            ice: 0,
            scrap: 0.2,
            // 100 × 200جم = 20.000 — والمطالب به 20.000 بالضبط.
            lines: <SackLineInput>[_configured()],
            lostConfirmed: true,
          ),
        ),
      );
      expect(intake.explanation.state, SackWeightState.fullyExplained);
      expect(intake.lostWeightConfirmed, isFalse);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('validateSackIntake — قيود المستند', () {
    test('★★ E-06: جونية بأوزانها بلا أنواع تُقبَل — وهي حالةٌ صحيحة', () {
      final ValidatedSackIntake intake = _ok(validateSackIntake(_intake()));
      expect(intake.lines, isEmpty);
      expect(intake.weights.claimableWeight.formatted(), '37.300');
      // ⛔ ولا وسمَ اكتمال تسعيرٍ لمستندٍ بلا سطور.
      expect(intake.isPricingComplete, isFalse);
    });

    test('⛔★★ BR-M7-03: مصدرٌ يشترط الرعوي ووصل بلا رعوي ⟵ يُرفَض', () {
      expect(
        _ruleOf(validateSackIntake(_intake(supplierId: null))),
        'BR-M7-03',
      );
    });

    test('⛔★★ وفي الاتجاه الآخر: رعويٌّ لمصدرٍ لا يشترطه ⟵ يُرفَض لا يُطرَح',
        () {
      // ★ طرحُه الصامت يجعل الواجهة تظنّ أنها خزّنت إسناداً لم يُخزَّن.
      expect(
        _ruleOf(
          validateSackIntake(
            _intake(requiresSupplier: false, supplierId: 'SUP-0001'),
          ),
        ),
        'BR-M7-03',
      );
    });

    test('⛔★ BR-M7-17 · ERR_INTAKE_008: لا سطران لنفس النوع', () {
      expect(
        _ruleOf(
          validateSackIntake(
            _intake(
              lines: <SackLineInput>[_configured(), _configured()],
            ),
          ),
        ),
        'BR-M7-17',
      );
    });

    test('⛔★★ E-07 · BR-M7-08: مجموع الأوزان يتجاوز المطالب به ⟵ يُرفَض', () {
      expect(
        _ruleOf(
          validateSackIntake(
            // 37.300 مطالبٌ بها · و200 × 500جم = 100.000 كجم.
            _intake(
              lines: <SackLineInput>[_configured(quantity: 200, configured: 500)],
            ),
          ),
        ),
        'BR-M7-08',
      );
    });

    test('★ والمساواة التامة مع المطالب به تُقبَل — فهي تفسيرٌ كامل', () {
      final ValidatedSackIntake intake = _ok(
        validateSackIntake(
          // المطالب به 20.000 · و100 × 200جم = 20.000.
          _intake(total: 20.2, ice: 0, scrap: 0.2,
              lines: <SackLineInput>[_configured()]),
        ),
      );
      expect(intake.explanation.state, SackWeightState.fullyExplained);
    });

    test('★ والسطور تُرتَّب بمعرّف النوع — فنفس الإدخال يُنتج نفس المستند', () {
      final ValidatedSackIntake first = _ok(
        validateSackIntake(
          _intake(
            lines: <SackLineInput>[
              _configured(itemId: 'ITM-0009', quantity: 10),
              _configured(itemId: 'ITM-0001', quantity: 10),
            ],
          ),
        ),
      );
      expect(
        first.lines.map((ValidatedSackLine l) => l.itemId).toList(),
        <String>['ITM-0001', 'ITM-0009'],
      );
    });

    test('★ GR-19: إجمالي الحبّات لا يجمع وزناً', () {
      final ValidatedSackIntake intake = _ok(
        validateSackIntake(
          _intake(
            lines: <SackLineInput>[
              _configured(itemId: 'ITM-0001', quantity: 10),
              _counted(itemId: 'ITM-0002', quantity: 20, total: 1),
            ],
          ),
        ),
      );
      expect(intake.totalPieces.pieces, 30);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('★★★ ADR-0007 — الأسماء المركّبة', () {
    test('★ FR-M7-05: الاسم الظاهر بالرعوي وبدونه', () {
      expect(
        sackDisplayName(dailySequence: 1, supplierName: 'عبدالفتاح'),
        'عبدالفتاح - جونية رقم 1',
      );
      expect(sackDisplayName(dailySequence: 3), 'جونية رقم 3');
    });

    test('★★ FR-M7-16 · AT-12: الاسم المركّب أساس ربط الحبة بجونيتها', () {
      expect(
        sackCompositeItemName(
          itemName: 'بطوة معالم أحمر',
          dailySequence: 1,
          supplierName: 'عبدالفتاح',
        ),
        'بطوة معالم أحمر - عبدالفتاح - جونية رقم 1',
      );
    });

    test('★★ E-43 · E-44: جونيتان بنفس الرقم في مصدرين تُنتجان مفتاحين مختلفين'
        ' باختلاف رعويهما', () {
      // ⚠️ والتمييز الفعلي بين المصدرين في **مفتاح سجل الرصيد** الذي يحمل
      //   `sourceId`، ★ وهذا الاختبار يحرس شطر الاسم منه.
      final String first = sackCompositeItemName(
        itemName: 'بطوة',
        dailySequence: 1,
        supplierName: 'مازن',
      );
      final String second = sackCompositeItemName(
        itemName: 'بطوة',
        dailySequence: 1,
        supplierName: 'عبدالفتاح',
      );
      expect(first, isNot(second));
    });

    // ═══════════════════════════════════════════════════════════════════
    // ⛔⛔★★★ [`DEBT-86`] — والاسمُ المركّب هو **المعروض** لا المخزَّن فحسب
    // ═══════════════════════════════════════════════════════════════════
    test('✅★★★ DEBT-86: سطرُ جونيةٍ يُعرَض باسمه المركّب لا بالمجرَّد', () {
      // ★★ **وحركةُ الجونية تُخزِّن المجرَّد في `itemName`** — ⟵ **فعرضُه
      //    وحدَه كان يجعل جونيتين من نوعٍ واحد سطرين متطابقين**، ⛔ **وهو
      //    عينُ ما رفضه `ADR-0007` في خياره الثاني.**
      expect(
        ledgerItemDisplayName(
          itemKey: 'عتود - جونية رقم 1',
          itemName: 'عتود',
        ),
        'عتود - جونية رقم 1',
      );
    });

    test('★★ ومفتاحُ الوارد عدداً يُعرَض باسمه المخزَّن — BR-M6-10', () {
      // ⛔ **والمفتاحُ هنا معرّفُ سجلٍّ لا اسم** — ⟵ **وعرضُه كان يُظهر
      //    «ITM-0002» للمستخدم.**
      expect(
        ledgerItemDisplayName(itemKey: 'ITM-0002', itemName: 'عود'),
        'عود',
      );
    });

    test('⛔★ واسمٌ مخزَّنٌ فارغٌ يقع على المفتاح — ⛔ لا على فراغ', () {
      expect(ledgerItemDisplayName(itemKey: 'ITM-0002', itemName: '  '),
          'ITM-0002');
    });

    test('★★★ والقاعدةُ تُقرأ ما يكتبه [sackCompositeItemName] حرفياً', () {
      // ⛔⛔★★ **وهو الحارسُ الفعلي** — ★ **بانٍ وقارئٌ في ملفٍ واحد**:
      //    ⟵ **فتغييرُ الصيغة يُسقِط هذا الاختبار قبل أن يُسقِط شاشة.**
      const String bare = 'بطوة معالم أحمر';
      final String composite = sackCompositeItemName(
        itemName: bare,
        dailySequence: 1,
        supplierName: 'عبدالفتاح',
      );
      expect(
        ledgerItemDisplayName(itemKey: composite, itemName: bare),
        composite,
      );
    });

    test('★ وسطر السكرب يُبنى من اسم النوع المخزَّن لا من نصّ محفور', () {
      expect(
        sackScrapCompositeName(dailySequence: 2, supplierName: 'مازن'),
        '$scrapItemName - مازن - جونية رقم 2',
      );
    });

    test('⛔ وتسلسلٌ دون ١ خللٌ في العدّاد ⟵ يُرمى لا يُرجَع نتيجةً', () {
      expect(() => sackDisplayName(dailySequence: 0), throwsArgumentError);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('★★ FR-M7-09 — سطر السكرب المولَّد', () {
    test('★ AT-07: وزنٌ موجب ⟵ سطرٌ بالكيلوجرام باسمٍ مركّب', () {
      final SackScrapLine? scrap = buildSackScrapLine(
        scrapItemId: 'ITM-0001',
        scrapWeight: const WeightKg(1.2),
        dailySequence: 1,
        supplierName: 'مازن',
      );
      expect(scrap, isNotNull);
      expect(scrap!.itemKey, '$scrapItemName - مازن - جونية رقم 1');
      expect(scrap.stockQuantity, const WeightQuantity(WeightKg(1.2)));
      expect(scrap.stockQuantity.unit, ItemUnit.kilogram);
    });

    test('⛔★★ ADR-0008 القاعدة 5: صفرُ السكرب لا يُنتج سطراً ولا سجل رصيد',
        () {
      expect(
        buildSackScrapLine(
          scrapItemId: 'ITM-0001',
          scrapWeight: WeightKg.zero,
          dailySequence: 1,
        ),
        isNull,
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('★★★ FR-M7-11 — ضريبة الجونية (الموضع ① للتقريب)', () {
    test('★ AT-13: 25 × 45.000 = 1,125 بلا كسر', () {
      expect(
        sackTax(taxPerKilo: const Money(25), totalWeight: const WeightKg(45))
            .riyals,
        1125,
      );
    });

    test('★★ وحالتا التقريب: 617.25 ⟵ 617 · و617.50 ⟵ 618', () {
      // 617.25 = 24.69 × 25  ⟵ ونستعمل وزناً يُنتجها بالضبط.
      expect(
        sackTax(taxPerKilo: const Money(25), totalWeight: const WeightKg(24.69))
            .riyals,
        617,
      );
      expect(
        sackTax(taxPerKilo: const Money(25), totalWeight: const WeightKg(24.7))
            .riyals,
        618,
      );
    });

    test('⛔★★ وعلى الوزن الكلي لا المطالب به — والفرق ليس تفصيلاً', () {
      final ValidatedSackWeights weights = _ok(
        validateSackWeights(
          const SackWeightsInput(
            totalWeight: WeightKg(45),
            iceWeight: WeightKg(6.5),
            scrapWeight: WeightKg(1.2),
          ),
        ),
      );
      final Money onTotal =
          sackTax(taxPerKilo: const Money(25), totalWeight: weights.totalWeight);
      final Money onClaimable = sackTax(
        taxPerKilo: const Money(25),
        totalWeight: weights.claimableWeight,
      );
      // ★ حارسٌ يُثبت أن الاثنين يفترقان فعلاً — ⟵ فلو استُعمل المطالب به
      //   لَنقصت ضريبةُ كل جونيةٍ فيها ثلج بصمت.
      expect(onTotal.riyals, 1125);
      // ⚠️⚠️ **و932 لا 933 — والفرق مقيسٌ لا سهو:** `45 − 6.5 − 1.2` يُنتج
      //    في الثنائي `37.299999999999997` لا `37.300`، ⟵ **فالضرب يُعطي
      //    `932.4999…` فتُقرَّب لأسفل.** ★ **ولا أثر لهذا على المسار
      //    الإنتاجي:** الضريبة **على الوزن الكلي وهو مُدخَلٌ من المستخدم**
      //    (`FR-M7-11`) ⛔ **لا على فرقٍ محسوب** — ★ **وهذا السطر يوثّق
      //    الحدّ صراحةً بدل أن يُكتشَف لاحقاً في رقمٍ حقيقي.**
      expect(onClaimable.riyals, 932);
      expect(onTotal.riyals, greaterThan(onClaimable.riyals));
    });

    test('★ وصفرُ ضريبة الكيلو مقبول · والسالب مرفوض', () {
      expect(_ok(validateSackTaxPerKilo(Money.zero)).riyals, 0);
      expect(_ruleOf(validateSackTaxPerKilo(const Money(-1))), 'BR-M7-14');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('التعديل والإلغاء', () {
    test('⛔ ERR_AMEND_006: الملغاة لا تُعدَّل ولا تُلغى ثانيةً', () {
      expect(
        _ruleOf(validateSackNotCancelled(SackStatus.cancelled)),
        'ERR_AMEND_006',
      );
      expect(
        validateSackNotCancelled(SackStatus.approved),
        isA<Success<void>>(),
      );
    });

    test('⛔★★★ BR-M7-05: الرقم المتسلسل لا يتغيّر أبداً', () {
      expect(
        validateSackSequenceUnchanged(storedSequence: 3, incomingSequence: 3),
        isA<Success<void>>(),
      );
      expect(
        _ruleOf(
          validateSackSequenceUnchanged(
            storedSequence: 3,
            incomingSequence: 4,
          ),
        ),
        'BR-M7-05',
      );
    });
  });
}

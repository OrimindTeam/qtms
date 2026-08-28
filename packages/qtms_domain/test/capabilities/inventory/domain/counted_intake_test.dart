import 'package:qtms_domain/qtms_domain.dart';
import 'package:test/test.dart';

CountedIntakeLineInput _line(
  String itemId,
  int quantity, {
  ItemUnit unit = ItemUnit.piece,
  String? note,
}) =>
    CountedIntakeLineInput(
      itemId: itemId,
      itemName: 'عوارض',
      unit: unit,
      quantity: quantity,
      note: note,
    );

CountedIntakeInput _intake({
  bool requiresSupplier = false,
  String? supplierId,
  List<CountedIntakeLineInput>? lines,
  String? notes,
}) =>
    CountedIntakeInput(
      sourceId: 'SRC-001',
      sourceRequiresSupplier: requiresSupplier,
      supplierId: supplierId,
      notes: notes,
      lines: lines ?? <CountedIntakeLineInput>[_line('ITM-0001', 120)],
    );

void main() {
  group('validateCountedIntake — FR-M6', () {
    test('يقبل مستنداً بسطرٍ صحيح ويحسب الإجمالي', () {
      final Outcome<ValidatedCountedIntake> outcome = validateCountedIntake(
        _intake(
          lines: <CountedIntakeLineInput>[
            _line('ITM-0002', 30),
            _line('ITM-0001', 120),
          ],
        ),
      );
      final ValidatedCountedIntake intake =
          (outcome as Success<ValidatedCountedIntake>).value;
      expect(intake.totalQuantity.pieces, 150);
      // ★ ترتيبٌ ثابت بمفتاح النوع — فنفس الإدخال يُنتج نفس المستند.
      expect(
        intake.lines.map((ValidatedCountedIntakeLine l) => l.itemKey).toList(),
        <String>['ITM-0001', 'ITM-0002'],
      );
      expect(intake.supplierId, isNull);
    });

    test('★ FR-M6-09: مفتاح النوع هو المعرّف لا الاسم — ولا اسم مركّب', () {
      final Outcome<ValidatedCountedIntake> outcome =
          validateCountedIntake(_intake());
      final ValidatedCountedIntakeLine line =
          (outcome as Success<ValidatedCountedIntake>).value.lines.single;
      expect(line.itemKey, 'ITM-0001');
      expect(line.itemName, 'عوارض');
    });

    test('★ BR-M6-06: يرفض كمية صفراً', () {
      expect(
        validateCountedIntake(
          _intake(lines: <CountedIntakeLineInput>[_line('ITM-0001', 0)]),
        ),
        isA<Failure<ValidatedCountedIntake>>(),
      );
    });

    test('★ BR-M6-06: يرفض كمية سالبة — والسالب سحبٌ لا وارد', () {
      final Outcome<ValidatedCountedIntake> outcome = validateCountedIntake(
        _intake(lines: <CountedIntakeLineInput>[_line('ITM-0001', -5)]),
      );
      expect(
        ((outcome as Failure<ValidatedCountedIntake>).error as ValidationError)
            .ruleCode,
        'BR-M6-06',
      );
    });

    test('★★ FR-M6-07 · ERR_INTAKE_008: يرفض سطرين لنفس النوع', () {
      final Outcome<ValidatedCountedIntake> outcome = validateCountedIntake(
        _intake(
          lines: <CountedIntakeLineInput>[
            _line('ITM-0001', 10),
            _line('ITM-0001', 5),
          ],
        ),
      );
      expect(
        ((outcome as Failure<ValidatedCountedIntake>).error as ValidationError)
            .ruleCode,
        'BR-M6-05',
      );
    });

    test('★★ FR-M6-10: يرفض وحدة الكيلوجرام — لا وزن في هذه الوحدة إطلاقاً', () {
      final Outcome<ValidatedCountedIntake> outcome = validateCountedIntake(
        _intake(
          lines: <CountedIntakeLineInput>[
            _line('ITM-SCRAP', 3, unit: ItemUnit.kilogram),
          ],
        ),
      );
      expect(
        ((outcome as Failure<ValidatedCountedIntake>).error as ValidationError)
            .ruleCode,
        'FR-M6-10',
      );
    });

    test('يرفض مستنداً بلا سطور', () {
      expect(
        validateCountedIntake(
          _intake(lines: const <CountedIntakeLineInput>[]),
        ),
        isA<Failure<ValidatedCountedIntake>>(),
      );
    });

    test('يرفض مصدراً فارغاً', () {
      expect(
        validateCountedIntake(
          const CountedIntakeInput(
            sourceId: '   ',
            sourceRequiresSupplier: false,
            lines: <CountedIntakeLineInput>[
              CountedIntakeLineInput(
                itemId: 'ITM-0001',
                itemName: 'عوارض',
                unit: ItemUnit.piece,
                quantity: 5,
              ),
            ],
          ),
        ),
        isA<Failure<ValidatedCountedIntake>>(),
      );
    });
  });

  group('★★ FR-M6-03 — الرعوي مشروطٌ بالمصدر في الاتجاهين', () {
    test('يرفض غياب الرعوي إن اشترطه المصدر', () {
      final Outcome<ValidatedCountedIntake> outcome =
          validateCountedIntake(_intake(requiresSupplier: true));
      expect(
        ((outcome as Failure<ValidatedCountedIntake>).error as ValidationError)
            .ruleCode,
        'FR-M6-03',
      );
    });

    test('يقبله ويُخزّنه إن اشترطه المصدر', () {
      final Outcome<ValidatedCountedIntake> outcome = validateCountedIntake(
        _intake(requiresSupplier: true, supplierId: 'SUP-0003'),
      );
      expect(
        (outcome as Success<ValidatedCountedIntake>).value.supplierId,
        'SUP-0003',
      );
    });

    test('★★ ويرفض رعوياً وصل لمصدرٍ لا يشترطه — ⛔ ولا يطرحه صامتاً', () {
      // «وإلا لا يُعرض ولا يُخزَّن أصلاً» — والطرحُ الصامت يجعل الواجهة
      // تظنّ أنها خزّنت إسناداً لم يُخزَّن.
      final Outcome<ValidatedCountedIntake> outcome = validateCountedIntake(
        _intake(supplierId: 'SUP-0003'),
      );
      expect(
        ((outcome as Failure<ValidatedCountedIntake>).error as ValidationError)
            .ruleCode,
        'FR-M6-03',
      );
    });

    test('والفراغات ليست رعوياً', () {
      expect(
        validateCountedIntake(_intake(supplierId: '   ')),
        isA<Success<ValidatedCountedIntake>>(),
      );
    });
  });

  group('التعديل والإلغاء — FR-M6-11 … FR-M6-13', () {
    test('★★ FR-M6-12: يرفض تخفيضاً يُنتج رصيداً سالباً', () {
      expect(
        validateStockChangeKeepsBalance(const PieceQuantity(PieceCount(-20))),
        isA<Failure<void>>(),
      );
    });

    test('يقبل تخفيضاً يُبقي الرصيد صفراً', () {
      expect(
        validateStockChangeKeepsBalance(const PieceQuantity(PieceCount.zero)),
        isA<Success<void>>(),
      );
    });

    test('★★ ERR_AMEND_006: لا يُعدَّل مستندٌ ملغى', () {
      expect(
        validateNotCancelled(CountedIntakeStatus.cancelled),
        isA<Failure<void>>(),
      );
      expect(
        validateNotCancelled(CountedIntakeStatus.approved),
        isA<Success<void>>(),
      );
    });
  });

  group('الملاحظات — نصٌّ اختياري', () {
    test('الفارغ غيابٌ لا نصٌّ فارغ', () {
      final Outcome<ValidatedCountedIntake> outcome = validateCountedIntake(
        _intake(notes: '   ', lines: <CountedIntakeLineInput>[
          _line('ITM-0001', 5, note: ''),
        ]),
      );
      final ValidatedCountedIntake intake =
          (outcome as Success<ValidatedCountedIntake>).value;
      expect(intake.notes, isNull);
      expect(intake.lines.single.note, isNull);
    });

    test('يرفض نصّاً يتجاوز الحدّ', () {
      expect(
        validateCountedIntake(_intake(notes: 'ن' * (freeTextMaxLength + 1))),
        isA<Failure<ValidatedCountedIntake>>(),
      );
    });
  });
}

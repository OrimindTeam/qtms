import 'package:qtms_domain/qtms_domain.dart';
import 'package:test/test.dart';

DistributionLineInput _pieceLine(
  String itemId, {
  int quantity = 10,
  int? unitPrice,
  String? sackId,
  String? note,
}) =>
    DistributionLineInput(
      itemId: itemId,
      itemName: 'عوارض',
      unit: ItemUnit.piece,
      quantity: PieceQuantity(PieceCount(quantity)),
      sackId: sackId,
      unitPrice: unitPrice == null ? null : Money(unitPrice),
      note: note,
    );

DistributionLineInput _weightLine(
  String itemId, {
  double quantity = 1.234,
  int? unitPrice,
  String? sackId,
}) =>
    DistributionLineInput(
      itemId: itemId,
      itemName: 'سكرب',
      unit: ItemUnit.kilogram,
      quantity: WeightQuantity(WeightKg(quantity)),
      sackId: sackId,
      unitPrice: unitPrice == null ? null : Money(unitPrice),
    );

DistributionInput _distribution({
  List<DistributionLineInput>? lines,
  String dealerId = 'MQT-0001',
  String sourceId = 'SRC-001',
  String? notes,
}) =>
    DistributionInput(
      sourceId: sourceId,
      dealerId: dealerId,
      notes: notes,
      lines: lines ?? <DistributionLineInput>[_pieceLine('ITM-0001')],
    );

ValidatedDistribution _validated(DistributionInput input) =>
    (validateDistribution(input) as Success<ValidatedDistribution>).value;

void main() {
  // ═══════════════════════════════════════════════════════════════════════
  // ★★★ ADR-0019 — الموضع الثالث للتقريب (قرار المالك في IQ-026، الخيار أ)
  // ═══════════════════════════════════════════════════════════════════════
  group('★★★ distributionLineTotal — ADR-0019 الموضع الثالث', () {
    test('⛔ السطر المعدود لا يمرّ بالتقريب — صحيح × صحيح', () {
      final Money? total = distributionLineTotal(
        quantity: const PieceQuantity(PieceCount(80)),
        unitPrice: const Money(1501),
      );
      expect(total, const Money(120080));
    });

    test('★ السطر الوزني يُقرَّب لأقرب ريال — المثال المرجعي في IQ-026', () {
      // 1.234 كجم × 1,501 = 1,852.234 ⟵ 1,852
      final Money? total = distributionLineTotal(
        quantity: const WeightQuantity(WeightKg(1.234)),
        unitPrice: const Money(1501),
      );
      expect(total, const Money(1852));
    });

    test('★ ADR-0015 القاعدة 5: الكسر ≥ 0.5 لأعلى', () {
      // 0.5 كجم × 1,235 = 617.5 ⟵ 618
      expect(
        distributionLineTotal(
          quantity: const WeightQuantity(WeightKg(0.5)),
          unitPrice: const Money(1235),
        ),
        const Money(618),
      );
    });

    test('★ ADR-0015 القاعدة 5: الكسر < 0.5 لأسفل', () {
      // 0.25 كجم × 2,469 = 617.25 ⟵ 617
      expect(
        distributionLineTotal(
          quantity: const WeightQuantity(WeightKg(0.25)),
          unitPrice: const Money(2469),
        ),
        const Money(617),
      );
    });

    test('★ AT-21 يبقى كما هو: 0.500 كجم سكرب × 4,000 = 2,000', () {
      expect(
        distributionLineTotal(
          quantity: const WeightQuantity(WeightKg(0.5)),
          unitPrice: const Money(4000),
        ),
        const Money(2000),
      );
    });

    test('⛔ السعر الغائب يُنتج null — «غير مسعَّر» لا «صفر»', () {
      expect(
        distributionLineTotal(
          quantity: const WeightQuantity(WeightKg(1.234)),
          unitPrice: null,
        ),
        isNull,
      );
    });

    test(
      '★ ADR-0019 القاعدة 3: المسار يُقرَّر من الوحدة لا من شكل الناتج',
      () {
        // ناتجٌ صحيحٌ تماماً — ومع ذلك يمرّ بمسار الوزن نفسه بلا تبدّل سلوك.
        expect(
          distributionLineTotal(
            quantity: const WeightQuantity(WeightKg(2)),
            unitPrice: const Money(500),
          ),
          const Money(1000),
        );
      },
    );
  });

  group('★★ computeDebtValue — ADR-0019 القاعدة 2', () {
    test('⛔ لا تقريب ثانٍ — مجموع قيمٍ مقرَّبة أصلاً', () {
      // 617.5 ⟵ 618  ·  617.25 ⟵ 617  ⟹  1,235
      final Money debtValue = computeDebtValue(<Money?>[
        distributionLineTotal(
          quantity: const WeightQuantity(WeightKg(0.5)),
          unitPrice: const Money(1235),
        ),
        distributionLineTotal(
          quantity: const WeightQuantity(WeightKg(0.25)),
          unitPrice: const Money(2469),
        ),
      ]);
      expect(debtValue, const Money(1235));
    });

    test('⛔ السطر غير المسعَّر لا يدخل الجمع — ولا يدخل بصفر', () {
      expect(
        computeDebtValue(<Money?>[const Money(500), null, const Money(300)]),
        const Money(800),
      );
    });

    test('مستندٌ كل سطوره غير مسعَّرة ⟵ قيمة الضمار صفر', () {
      expect(computeDebtValue(<Money?>[null, null]), Money.zero);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // GR-18 — المعرّف المركّب
  // ═══════════════════════════════════════════════════════════════════════
  group('★★★ distributionId — GR-18 بنيوياً', () {
    test('الترتيب ملزم: {dealerId}_{sourceId}_{stockDate}', () {
      expect(
        distributionId(
          dealerId: 'MQT-0001',
          sourceId: 'SRC-001',
          stockDate: CalendarDay(2026, 8, 27),
        ),
        'MQT-0001_SRC-001_20260827',
      );
    });

    test('★ نفس (المقوت × المصدر × اليوم) ⟵ نفس المعرّف حرفياً', () {
      final String first = distributionId(
        dealerId: 'MQT-0001',
        sourceId: 'SRC-001',
        stockDate: CalendarDay(2026, 8, 27),
      );
      final String second = distributionId(
        dealerId: 'MQT-0001',
        sourceId: 'SRC-001',
        stockDate: CalendarDay(2026, 8, 27),
      );
      expect(first, second);
    });

    test('⛔ يومان مختلفان ⟵ ضماران مختلفان (E-23)', () {
      expect(
        distributionId(
          dealerId: 'MQT-0001',
          sourceId: 'SRC-001',
          stockDate: CalendarDay(2026, 8, 26),
        ),
        isNot(
          distributionId(
            dealerId: 'MQT-0001',
            sourceId: 'SRC-001',
            stockDate: CalendarDay(2026, 8, 27),
          ),
        ),
      );
    });

    test('⛔ AT-20: مصدران في يومٍ واحد ⟵ ضماران منفصلان', () {
      expect(
        distributionId(
          dealerId: 'MQT-0001',
          sourceId: 'SRC-001',
          stockDate: CalendarDay(2026, 8, 27),
        ),
        isNot(
          distributionId(
            dealerId: 'MQT-0001',
            sourceId: 'SRC-002',
            stockDate: CalendarDay(2026, 8, 27),
          ),
        ),
      );
    });

    test('⛔ يرفض المقوت أو المصدر الفارغ', () {
      expect(
        () => distributionId(
          dealerId: '',
          sourceId: 'SRC-001',
          stockDate: CalendarDay(2026, 8, 27),
        ),
        throwsArgumentError,
      );
      expect(
        () => distributionId(
          dealerId: 'MQT-0001',
          sourceId: '',
          stockDate: CalendarDay(2026, 8, 27),
        ),
        throwsArgumentError,
      );
    });
  });

  group('dealerBalanceId · debtLedgerEntryId', () {
    test('رصيد المقوت — {dealerId}_{sourceId}', () {
      expect(
        dealerBalanceId(dealerId: 'MQT-0001', sourceId: 'SRC-002'),
        'MQT-0001_SRC-002',
      );
    });

    test('★ القيد المدين معرّفه مشتقٌّ — فإعادة الإرسال تكتب فوقه', () {
      expect(
        debtLedgerEntryId(documentNumber: 'DST-20260827-0001'),
        'DST-20260827-0001_debt',
      );
    });

    test('⛔ يرفض الرقم الفارغ', () {
      expect(
        () => debtLedgerEntryId(documentNumber: ''),
        throwsArgumentError,
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // validateDistribution — FR-M10
  // ═══════════════════════════════════════════════════════════════════════
  group('validateDistribution — FR-M10', () {
    test('يقبل مستنداً صحيحاً ويرتّب سطوره بمفتاح النوع', () {
      final ValidatedDistribution distribution = _validated(
        _distribution(
          lines: <DistributionLineInput>[
            _pieceLine('ITM-0002', quantity: 30),
            _pieceLine('ITM-0001', quantity: 120),
          ],
        ),
      );
      expect(
        distribution.lines
            .map((ValidatedDistributionLine l) => l.itemKey)
            .toList(),
        <String>['ITM-0001', 'ITM-0002'],
      );
    });

    test('⛔ FR-M10-19: سطران لنفس النوع يُرفضان', () {
      final Outcome<ValidatedDistribution> outcome = validateDistribution(
        _distribution(
          lines: <DistributionLineInput>[
            _pieceLine('ITM-0001'),
            _pieceLine('ITM-0001'),
          ],
        ),
      );
      expect(outcome, isA<Failure<ValidatedDistribution>>());
    });

    test('⛔ FR-M10-11: الكمية صفراً تُرفض — والصفر ليس توزيعاً', () {
      final Outcome<ValidatedDistribution> outcome = validateDistribution(
        _distribution(
          lines: <DistributionLineInput>[_pieceLine('ITM-0001', quantity: 0)],
        ),
      );
      expect(outcome, isA<Failure<ValidatedDistribution>>());
    });

    test('⛔ FR-M10-11: الكمية السالبة تُرفض', () {
      final Outcome<ValidatedDistribution> outcome = validateDistribution(
        _distribution(
          lines: <DistributionLineInput>[_pieceLine('ITM-0001', quantity: -5)],
        ),
      );
      expect(outcome, isA<Failure<ValidatedDistribution>>());
    });

    test('⛔ GR-19: كميةٌ بوحدةٍ غير وحدة النوع تُرفض ولا تُحوَّل صامتاً', () {
      final Outcome<ValidatedDistribution> outcome = validateDistribution(
        _distribution(
          lines: <DistributionLineInput>[
            DistributionLineInput(
              itemId: 'ITM-0001',
              itemName: 'عوارض',
              unit: ItemUnit.piece,
              quantity: const WeightQuantity(WeightKg(1.5)),
            ),
          ],
        ),
      );
      expect(outcome, isA<Failure<ValidatedDistribution>>());
    });

    test('⛔ السعر بصفر يُرفض — والغياب وحده يعني «غير مسعَّر»', () {
      final Outcome<ValidatedDistribution> outcome = validateDistribution(
        _distribution(
          lines: <DistributionLineInput>[
            _pieceLine('ITM-0001', unitPrice: 0),
          ],
        ),
      );
      expect(outcome, isA<Failure<ValidatedDistribution>>());
    });

    test('⛔⛔★★★ IQ-043 — مستندٌ بلا سطور يُرفض بـERR_DIST_010 — ⛔ لا بالجامع', () {
      final Outcome<ValidatedDistribution> outcome = validateDistribution(
        _distribution(lines: <DistributionLineInput>[]),
      );
      expect(outcome, isA<Failure<ValidatedDistribution>>());
      // ★★ **والرمزُ مقيسٌ لا مفترَض** — ⟵ **فالشاشةُ تُطابقُه نصّاً**
      //   (`_messageOf`)، ⛔ **وتغييرُه هنا يُسقِط الرسالة بصمت.**
      expect(
        ((outcome as Failure<ValidatedDistribution>).error as ValidationError)
            .ruleCode,
        distributionNeedsLineCode,
      );
      expect(distributionNeedsLineCode, 'ERR_DIST_010');
    });

    test('⛔ المقوت أو المصدر الفارغ يُرفض', () {
      expect(
        validateDistribution(_distribution(dealerId: '  ')),
        isA<Failure<ValidatedDistribution>>(),
      );
      expect(
        validateDistribution(_distribution(sourceId: '')),
        isA<Failure<ValidatedDistribution>>(),
      );
    });

    test('★ الملاحظة الفارغة غيابٌ لا نصٌّ فارغ', () {
      final ValidatedDistribution distribution = _validated(
        _distribution(
          lines: <DistributionLineInput>[_pieceLine('ITM-0001', note: '   ')],
          notes: '  ',
        ),
      );
      expect(distribution.lines.single.note, isNull);
      expect(distribution.notes, isNull);
    });

    test('★ FR-M10-14: sackId يُحفَظ فيُطلق إعادة احتساب سعر الجونية', () {
      final ValidatedDistribution distribution = _validated(
        _distribution(
          lines: <DistributionLineInput>[
            _pieceLine('ITM-0001', sackId: 'SCK-20260827-0001'),
          ],
        ),
      );
      expect(distribution.lines.single.sackId, 'SCK-20260827-0001');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // GR-19 — إجماليان منفصلان دائماً
  // ═══════════════════════════════════════════════════════════════════════
  group('★★ الإجماليات — GR-19 · FR-M10-15', () {
    test('⛔ الحبات والأوزان لا تُجمع في إجمالٍ واحد', () {
      final ValidatedDistribution distribution = _validated(
        _distribution(
          lines: <DistributionLineInput>[
            _pieceLine('ITM-0001', quantity: 80),
            _pieceLine('ITM-0002', quantity: 20),
            _weightLine('ITM-0003', quantity: 1.2),
            _weightLine('ITM-0004', quantity: 0.3),
          ],
        ),
      );
      expect(distribution.totalPieces.pieces, 100);
      expect(distribution.totalWeight.kilograms, closeTo(1.5, 1e-9));
    });

    test('مستندٌ بلا سطرٍ وزني ⟵ إجمالي الوزن صفر', () {
      final ValidatedDistribution distribution = _validated(_distribution());
      expect(distribution.totalWeight.kilograms, 0);
      expect(distribution.totalPieces.pieces, 10);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // E-05 · AT-23 — حالة التسعير والمديونية بالمسعَّر وحده
  // ═══════════════════════════════════════════════════════════════════════
  group('★★★ حالة التسعير — E-05 · AT-23 · FR-M10-05', () {
    test('AT-23: سطران مسعَّران وسطرٌ بلا سعر ⟵ «مسعَّر جزئياً»', () {
      final ValidatedDistribution distribution = _validated(
        _distribution(
          lines: <DistributionLineInput>[
            _pieceLine('ITM-0001', quantity: 10, unitPrice: 100),
            _pieceLine('ITM-0002', quantity: 5, unitPrice: 200),
            _pieceLine('ITM-0003', quantity: 7),
          ],
        ),
      );
      expect(distribution.pricingStatus, DistributionStatus.partiallyPriced);
      expect(distribution.unpricedLineCount, 1);
      // ⛔ المديونية بالمسعَّر وحده: (10×100) + (5×200) = 2,000.
      expect(distribution.debtValue, const Money(2000));
    });

    test('كل السطور مسعَّرة ⟵ «مسعَّر»', () {
      final ValidatedDistribution distribution = _validated(
        _distribution(
          lines: <DistributionLineInput>[
            _pieceLine('ITM-0001', quantity: 10, unitPrice: 100),
          ],
        ),
      );
      expect(distribution.pricingStatus, DistributionStatus.priced);
      expect(distribution.unpricedLineCount, 0);
      expect(distribution.carriesAnyPrice, isTrue);
    });

    test('FR-M10-08: لا سطر مسعَّر ⟵ «معتمد» وقيمة الضمار صفر', () {
      final ValidatedDistribution distribution = _validated(
        _distribution(
          lines: <DistributionLineInput>[
            _pieceLine('ITM-0001'),
            _pieceLine('ITM-0002'),
          ],
        ),
      );
      expect(distribution.pricingStatus, DistributionStatus.approved);
      expect(distribution.unpricedLineCount, 2);
      expect(distribution.debtValue, Money.zero);
      // ⟵ **وهذا ما يُقابَل بصلاحية التسعير في الدالة الكاتبة.**
      expect(distribution.carriesAnyPrice, isFalse);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // design-overview §2.3 — تسوية الضمار
  // ═══════════════════════════════════════════════════════════════════════
  group('computeDebtSettlement — design-overview §2.3', () {
    test('المتبقي = القيمة ⟵ مفتوح', () {
      final DebtSettlement settlement = computeDebtSettlement(
        debtValue: const Money(10000),
        settledAmount: Money.zero,
        discountedAmount: Money.zero,
      );
      expect(settlement.status, SettlementStatus.open);
      expect(settlement.remaining, const Money(10000));
      expect(settlement.isTouchedBySettlement, isFalse);
    });

    test('0 < المتبقي < القيمة ⟵ مفتوح جزئياً', () {
      final DebtSettlement settlement = computeDebtSettlement(
        debtValue: const Money(10000),
        settledAmount: const Money(4000),
        discountedAmount: const Money(1000),
      );
      expect(settlement.status, SettlementStatus.partiallyOpen);
      expect(settlement.remaining, const Money(5000));
      expect(settlement.isTouchedBySettlement, isTrue);
    });

    test('المتبقي = 0 ⟵ مغلق', () {
      final DebtSettlement settlement = computeDebtSettlement(
        debtValue: const Money(10000),
        settledAmount: const Money(7000),
        discountedAmount: const Money(3000),
      );
      expect(settlement.status, SettlementStatus.closed);
      expect(settlement.remaining, Money.zero);
    });

    test('★ القيمة صفر ⟵ مغلق — ولا يُعدّ ديناً مفتوحاً في أعمار الديون', () {
      final DebtSettlement settlement = computeDebtSettlement(
        debtValue: Money.zero,
        settledAmount: Money.zero,
        discountedAmount: Money.zero,
      );
      expect(settlement.status, SettlementStatus.closed);
    });

    test('⛔⛔ والقيمة صفر لا تعني «مُسّ بسداد» — وهو حارس الإلغاء', () {
      final DebtSettlement settlement = computeDebtSettlement(
        debtValue: Money.zero,
        settledAmount: Money.zero,
        discountedAmount: Money.zero,
      );
      // ★ الحارس يقيس ما وصل فعلاً لا حالة المتبقي.
      expect(settlement.isTouchedBySettlement, isFalse);
      expect(
        validateDistributionCancellable(settlement),
        isA<Success<void>>(),
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // FR-M10-18 · E-15 — حارس الإلغاء
  // ═══════════════════════════════════════════════════════════════════════
  group('★★★ validateDistributionCancellable — E-15', () {
    test('⛔ سُدِّد جزئياً ⟵ الإلغاء مرفوض (ERR_AMEND_005)', () {
      final Outcome<void> outcome = validateDistributionCancellable(
        computeDebtSettlement(
          debtValue: const Money(10000),
          settledAmount: const Money(1),
          discountedAmount: Money.zero,
        ),
      );
      expect(outcome, isA<Failure<void>>());
      expect(
        ((outcome as Failure<void>).error as ValidationError).ruleCode,
        'ERR_AMEND_005',
      );
    });

    test('⛔ خُصم منه ⟵ الإلغاء مرفوض كذلك', () {
      expect(
        validateDistributionCancellable(
          computeDebtSettlement(
            debtValue: const Money(10000),
            settledAmount: Money.zero,
            discountedAmount: const Money(500),
          ),
        ),
        isA<Failure<void>>(),
      );
    });

    test('✅ لم يُمَسّ ⟵ الإلغاء مسموح', () {
      expect(
        validateDistributionCancellable(
          computeDebtSettlement(
            debtValue: const Money(10000),
            settledAmount: Money.zero,
            discountedAmount: Money.zero,
          ),
        ),
        isA<Success<void>>(),
      );
    });
  });

  group('validateDistributionNotCancelled — ERR_AMEND_006', () {
    test('⛔ الملغى لا يُعدَّل ولا يُلغى ثانيةً', () {
      expect(
        validateDistributionNotCancelled(DistributionStatus.cancelled),
        isA<Failure<void>>(),
      );
    });

    test('✅ المعتمد والمسعَّر يُعدَّلان', () {
      expect(
        validateDistributionNotCancelled(DistributionStatus.approved),
        isA<Success<void>>(),
      );
      expect(
        validateDistributionNotCancelled(DistributionStatus.priced),
        isA<Success<void>>(),
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // design-overview §2.4 — رصيد المقوت
  // ═══════════════════════════════════════════════════════════════════════
  group('computeDealerBalance — design-overview §2.4', () {
    DealerLedgerEntry debit(int amount, {bool cancelled = false}) =>
        DealerLedgerEntry(
          direction: DealerLedgerDirection.debit,
          amount: Money(amount),
          isCancelled: cancelled,
        );
    DealerLedgerEntry credit(int amount, {bool cancelled = false}) =>
        DealerLedgerEntry(
          direction: DealerLedgerDirection.credit,
          amount: Money(amount),
          isCancelled: cancelled,
        );

    test('الرصيد = المدين − الدائن', () {
      final DealerAccountBalance balance = computeDealerBalance(
        <DealerLedgerEntry>[debit(10000), debit(5000), credit(4000)],
      );
      expect(balance.totalDebit, const Money(15000));
      expect(balance.totalCredit, const Money(4000));
      expect(balance.balance, const Money(11000));
      expect(balance.hasSurplus, isFalse);
    });

    test('⛔ الملغاة لا تدخل أي جمع', () {
      final DealerAccountBalance balance = computeDealerBalance(
        <DealerLedgerEntry>[
          debit(10000),
          debit(9999, cancelled: true),
          credit(1000, cancelled: true),
        ],
      );
      expect(balance.balance, const Money(10000));
    });

    test('★ الرصيد السالب فائضٌ له عند المحل', () {
      final DealerAccountBalance balance = computeDealerBalance(
        <DealerLedgerEntry>[debit(1000), credit(1500)],
      );
      expect(balance.balance, const Money(-500));
      expect(balance.hasSurplus, isTrue);
    });

    test('دفترٌ فارغ ⟵ رصيد صفر ⛔ لا خطأ', () {
      final DealerAccountBalance balance =
          computeDealerBalance(const <DealerLedgerEntry>[]);
      expect(balance.balance, Money.zero);
    });
  });
}

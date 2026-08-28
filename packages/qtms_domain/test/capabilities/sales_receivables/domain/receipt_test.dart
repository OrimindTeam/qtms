/// ★★★ **المقبوضات وحساب المقوت** — `M12` · `FR-M12` · `WU-007`.
library;

import 'package:qtms_domain/qtms_domain.dart';
import 'package:test/test.dart';

const String dealerA = 'MQT-0001';
const String sourceA = 'SRC-001';
const String sourceB = 'SRC-002';

CalendarDay day(int d) => CalendarDay(2026, 8, d);

OpenDebtLot lot(
  int stockDay, {
  int remaining = 30000,
  String sourceId = sourceA,
}) =>
    OpenDebtLot(
      debtLotId: distributionId(
        dealerId: dealerA,
        sourceId: sourceId,
        stockDate: day(stockDay),
      ),
      sourceId: sourceId,
      stockDate: day(stockDay),
      remaining: Money(remaining),
    );

Map<String, OpenDebtLot> byId(List<OpenDebtLot> lots) => <String, OpenDebtLot>{
      for (final OpenDebtLot l in lots) l.debtLotId: l,
    };

void main() {
  // ═══════════════════════════════════════════════════════════════════════
  // المفاتيح المركّبة — ★ `E-13` بنيوياً
  // ═══════════════════════════════════════════════════════════════════════
  group('★★★ مفتاح الفائض — `E-13` مفروضٌ بالمفتاح لا بفحص', () {
    test('★ فائضُ مصدرٍ يحمل معرّف المصدر', () {
      expect(
        dealerSurplusId(
          dealerId: dealerA,
          scope: SurplusScope.source,
          sourceId: sourceA,
        ),
        'MQT-0001_SRC-001',
      );
    });

    test('★ والعامُّ يحمل `general`', () {
      expect(
        dealerSurplusId(dealerId: dealerA, scope: SurplusScope.general),
        'MQT-0001_general',
      );
    });

    test('⛔⛔ فائضُ مصدرٍ بلا مصدر ⟵ رفضٌ لا سقوطٌ إلى «عام»', () {
      expect(
        () => dealerSurplusId(dealerId: dealerA, scope: SurplusScope.source),
        throwsArgumentError,
      );
    });

    test('⛔ ومقوتٌ فارغ يُرفَض', () {
      expect(
        () => dealerSurplusId(dealerId: '', scope: SurplusScope.general),
        throwsArgumentError,
      );
    });

    test('★ ومعرّفُ الحركة الدائنة مشتقٌّ بالسند والضمار معاً', () {
      expect(
        receiptLedgerEntryId(
          documentNumber: 'RCP-20260828-0001',
          debtLotId: 'MQT-0001_SRC-001_2026-08-20',
        ),
        'RCP-20260828-0001_MQT-0001_SRC-001_2026-08-20',
      );
    });

    test('★★ ومعرّفُ تطبيق الفائض بالضمار وسجلِّ الفائض معاً', () {
      expect(
        surplusLedgerEntryId(
          debtLotId: 'MQT-0001_SRC-001_2026-08-20',
          surplusId: 'MQT-0001_general',
        ),
        'MQT-0001_SRC-001_2026-08-20_surplus_MQT-0001_general',
      );
    });

    test('⛔⛔★★ وسجلّان يُسدِّدان ضماراً واحداً ⟵ معرّفان مختلفان', () {
      // ★★ **الحارس:** ⟵ **ولولا دخولُ السجل في المعرّف لكُتبت الثانيةُ
      //    فوق الأولى** ⛔ **فضاع تسديدٌ من الدفتر ورصيدُ الفائض نقص بهما.**
      expect(
        surplusLedgerEntryId(debtLotId: 'L', surplusId: 'MQT-0001_SRC-001'),
        isNot(
          surplusLedgerEntryId(debtLotId: 'L', surplusId: 'MQT-0001_general'),
        ),
      );
    });

    test('⛔ ومعرّفاتٌ فارغة تُرفَض', () {
      expect(
        () => receiptLedgerEntryId(documentNumber: '', debtLotId: 'x'),
        throwsArgumentError,
      );
      expect(
        () => receiptLedgerEntryId(documentNumber: 'x', debtLotId: ''),
        throwsArgumentError,
      );
      expect(
        () => surplusLedgerEntryId(debtLotId: '', surplusId: 'x'),
        throwsArgumentError,
      );
      expect(
        () => surplusLedgerEntryId(debtLotId: 'x', surplusId: ''),
        throwsArgumentError,
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // ★★★ AT-29 — التوزيع التلقائي بالأقدم أولاً
  // ═══════════════════════════════════════════════════════════════════════
  group('★★★ التوزيع التلقائي — بالأقدم أولاً (`FR-M12-13`)', () {
    test('★★★ يسدد الأقدم كاملاً ثم الذي يليه جزئياً', () {
      final AutoAllocationProposal proposal = allocateReceiptAutomatically(
        amount: const Money(45000),
        openLots: <OpenDebtLot>[
          lot(20, remaining: 30000),
          lot(18, remaining: 20000),
        ],
      );
      expect(proposal.lines.length, 2);
      // ⟵ **الأقدم (18) أولاً** ⛔ **لا بترتيب المدخلات.**
      expect(proposal.lines.first.debtLotId, lot(18).debtLotId);
      expect(proposal.lines.first.amount, const Money(20000));
      expect(proposal.lines.last.amount, const Money(25000));
      expect(proposal.surplus, Money.zero);
    });

    test('★★★ AT-30 — دفع 50,000 والمستحق 30,000 ⟵ 20,000 فائضاً', () {
      final AutoAllocationProposal proposal = allocateReceiptAutomatically(
        amount: const Money(50000),
        openLots: <OpenDebtLot>[lot(20, remaining: 30000)],
      );
      expect(proposal.lines.single.amount, const Money(30000));
      expect(proposal.surplus, const Money(20000));
    });

    test('★ ومبلغٌ أقل من أقدم ضمار ⟵ سطرٌ جزئي واحد بلا فائض', () {
      final AutoAllocationProposal proposal = allocateReceiptAutomatically(
        amount: const Money(5000),
        openLots: <OpenDebtLot>[lot(18), lot(20)],
      );
      expect(proposal.lines.single.debtLotId, lot(18).debtLotId);
      expect(proposal.lines.single.amount, const Money(5000));
      expect(proposal.surplus, Money.zero);
    });

    test('⛔ ولا ضمار مفتوح ⟵ المبلغ كلُّه فائض', () {
      final AutoAllocationProposal proposal = allocateReceiptAutomatically(
        amount: const Money(9000),
        openLots: const <OpenDebtLot>[],
      );
      expect(proposal.lines, isEmpty);
      expect(proposal.surplus, const Money(9000));
    });

    test('⛔ وضمارٌ متبقّيه صفر لا يُقترَح له سطر', () {
      final AutoAllocationProposal proposal = allocateReceiptAutomatically(
        amount: const Money(9000),
        openLots: <OpenDebtLot>[lot(18, remaining: 0), lot(20)],
      );
      expect(proposal.lines.single.debtLotId, lot(20).debtLotId);
    });

    test('★★ والترتيب مستقرٌّ عند تساوي التاريخ — نفس المدخلات نفسُ الاقتراح',
        () {
      List<String> run() => allocateReceiptAutomatically(
            amount: const Money(100000),
            openLots: <OpenDebtLot>[
              lot(18, sourceId: sourceB, remaining: 10000),
              lot(18, remaining: 10000),
            ],
          ).lines.map((ReceiptLineInput l) => l.debtLotId).toList();
      expect(run(), run());
      // ⟵ **`SRC-001` قبل `SRC-002` بالمعرّف** — ⛔ **لا بترتيب المدخلات.**
      expect(run().first, contains(sourceA));
    });

    test('⛔ ومبلغٌ صفر ⟵ لا سطر ولا فائض', () {
      final AutoAllocationProposal proposal = allocateReceiptAutomatically(
        amount: Money.zero,
        openLots: <OpenDebtLot>[lot(18)],
      );
      expect(proposal.lines, isEmpty);
      expect(proposal.surplus, Money.zero);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // ★★★ FR-M12-06 — سطر القبض
  // ═══════════════════════════════════════════════════════════════════════
  group('★★★ سطر القبض — `BR-M12-02`', () {
    test('★ مبلغٌ ضمن المتبقي ⟵ يُقبَل والمتبقي بعده محسوب', () {
      final Outcome<ValidatedReceiptLine> outcome = validateReceiptLine(
        line: const ReceiptLineInput(
          debtLotId: 'x',
          amount: Money(10000),
        ),
        lot: lot(18, remaining: 30000),
      );
      final ValidatedReceiptLine line =
          (outcome as Success<ValidatedReceiptLine>).value;
      expect(line.remainingBefore, const Money(30000));
      expect(line.remainingAfter, const Money(20000));
      // ★★ **والمصدر من الضمار المقروء** ⛔ **لا من الحمولة** (`E-35`).
      expect(line.sourceId, sourceA);
      expect(line.debtLotId, lot(18).debtLotId);
    });

    test('⛔⛔ ومبلغٌ يتجاوز المتبقي ⟵ رفضٌ بـ`BR-M12-02`', () {
      final Outcome<ValidatedReceiptLine> outcome = validateReceiptLine(
        line: const ReceiptLineInput(debtLotId: 'x', amount: Money(30001)),
        lot: lot(18, remaining: 30000),
      );
      expect(
        ((outcome as Failure<ValidatedReceiptLine>).error as ValidationError)
            .ruleCode,
        'BR-M12-02',
      );
    });

    test('★ والمساوي للمتبقي يُقبَل ⟵ والمتبقي بعده صفر', () {
      final Outcome<ValidatedReceiptLine> outcome = validateReceiptLine(
        line: const ReceiptLineInput(debtLotId: 'x', amount: Money(30000)),
        lot: lot(18, remaining: 30000),
      );
      expect(
        (outcome as Success<ValidatedReceiptLine>).value.remainingAfter,
        Money.zero,
      );
    });

    test('⛔ وصفرٌ يُرفَض لا يُتجاهَل', () {
      expect(
        validateReceiptLine(
          line: const ReceiptLineInput(debtLotId: 'x', amount: Money.zero),
          lot: lot(18),
        ),
        isA<Failure<ValidatedReceiptLine>>(),
      );
    });

    test('⛔ وسالبٌ يُرفَض', () {
      expect(
        validateReceiptLine(
          line: const ReceiptLineInput(debtLotId: 'x', amount: Money(-1)),
          lot: lot(18),
        ),
        isA<Failure<ValidatedReceiptLine>>(),
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // ★★★ السند كاملاً
  // ═══════════════════════════════════════════════════════════════════════
  group('★★★ السند كاملاً — `FR-M12-05` … `FR-M12-10`', () {
    test('★★ سطران على ضمارين ⟵ يُقبلان بمصدرَيهما', () {
      final List<OpenDebtLot> lots = <OpenDebtLot>[
        lot(18, remaining: 20000),
        lot(20, remaining: 30000, sourceId: sourceB),
      ];
      final Outcome<List<ValidatedReceiptLine>> outcome = validateReceiptLines(
        lines: <ReceiptLineInput>[
          ReceiptLineInput(debtLotId: lots[0].debtLotId, amount: Money(20000)),
          ReceiptLineInput(debtLotId: lots[1].debtLotId, amount: Money(5000)),
        ],
        lotsById: byId(lots),
        surplusAmount: Money.zero,
      );
      final List<ValidatedReceiptLine> lines =
          (outcome as Success<List<ValidatedReceiptLine>>).value;
      expect(lines.map((ValidatedReceiptLine l) => l.sourceId),
          <String>[sourceA, sourceB]);
    });

    test('⛔⛔★★ ضمارٌ مكرَّر في سطرين ⟵ رفض — وإلا سُدِّد أكثر من قيمته', () {
      final List<OpenDebtLot> lots = <OpenDebtLot>[lot(18, remaining: 20000)];
      final Outcome<List<ValidatedReceiptLine>> outcome = validateReceiptLines(
        lines: <ReceiptLineInput>[
          ReceiptLineInput(debtLotId: lots[0].debtLotId, amount: Money(20000)),
          ReceiptLineInput(debtLotId: lots[0].debtLotId, amount: Money(20000)),
        ],
        lotsById: byId(lots),
        surplusAmount: Money.zero,
      );
      expect(outcome, isA<Failure<List<ValidatedReceiptLine>>>());
    });

    test('⛔ وضمارٌ لم يُقرأ ⟵ رفضٌ لا تخطٍّ صامت', () {
      final Outcome<List<ValidatedReceiptLine>> outcome = validateReceiptLines(
        lines: const <ReceiptLineInput>[
          ReceiptLineInput(debtLotId: 'مجهول', amount: Money(100)),
        ],
        lotsById: const <String, OpenDebtLot>{},
        surplusAmount: Money.zero,
      );
      expect(outcome, isA<Failure<List<ValidatedReceiptLine>>>());
    });

    test('★★★ FR-M12-10 — فائضٌ وحده بلا سطر ⟵ يُقبَل', () {
      final Outcome<List<ValidatedReceiptLine>> outcome = validateReceiptLines(
        lines: const <ReceiptLineInput>[],
        lotsById: const <String, OpenDebtLot>{},
        surplusAmount: const Money(20000),
      );
      expect((outcome as Success<List<ValidatedReceiptLine>>).value, isEmpty);
    });

    test('⛔ وسندٌ فارغٌ تماماً ⟵ رفض', () {
      final Outcome<List<ValidatedReceiptLine>> outcome = validateReceiptLines(
        lines: const <ReceiptLineInput>[],
        lotsById: const <String, OpenDebtLot>{},
        surplusAmount: Money.zero,
      );
      expect(
        ((outcome as Failure<List<ValidatedReceiptLine>>).error
                as ValidationError)
            .ruleCode,
        'BR-M12-04',
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // ★★★ FR-M12-02 — التاريخ
  // ═══════════════════════════════════════════════════════════════════════
  group('★★★ تاريخ السند — `FR-M12-02` · `A-10`', () {
    test('★ اليوم يُقبَل بلا صلاحية', () {
      expect(
        validateReceiptDate(
          date: day(28),
          today: day(28),
          canBackdate: false,
        ),
        isA<Success<void>>(),
      );
    });

    test('⛔⛔★★ والمستقبلي مرفوضٌ ولو ملك كل الصلاحيات', () {
      final Outcome<void> outcome = validateReceiptDate(
        date: day(29),
        today: day(28),
        canBackdate: true,
      );
      expect(
        ((outcome as Failure<void>).error as ValidationError).ruleCode,
        'BR-M12-03',
      );
    });

    test('⛔ وسابقٌ بلا صلاحية ⟵ خطأ صلاحية لا تحقّق', () {
      final Outcome<void> outcome = validateReceiptDate(
        date: day(27),
        today: day(28),
        canBackdate: false,
      );
      expect((outcome as Failure<void>).error, isA<PermissionError>());
    });

    test('★ وسابقٌ بصلاحية يُقبَل — `E-14`', () {
      expect(
        validateReceiptDate(date: day(20), today: day(28), canBackdate: true),
        isA<Success<void>>(),
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // ★★★ الفائض — AT-31 · AT-32 · E-13
  // ═══════════════════════════════════════════════════════════════════════
  group('★★★ الفائض المتاح وتطبيقه', () {
    SurplusPoolRead pool({
      required SurplusScope scope,
      String? sourceId,
      int available = 20000,
      int paidDay = 20,
    }) =>
        SurplusPoolRead(
          surplusId: dealerSurplusId(
            dealerId: dealerA,
            scope: scope,
            sourceId: sourceId,
          ),
          scope: scope,
          paidOn: day(paidDay),
          available: Money(available),
        );

    test('★ المتاح = المدفوع − المُطبَّق', () {
      expect(
        availableSurplus(paid: const Money(50000), applied: const Money(30000)),
        const Money(20000),
      );
    });

    test('⛔★★ ولا يهبط تحت الصفر', () {
      expect(
        availableSurplus(paid: const Money(10000), applied: const Money(30000)),
        Money.zero,
      );
    });

    test('★★★ AT-31 — ضمارٌ جديد يُسدَّد من الفائض ببيانٍ آلي', () {
      final List<SurplusApplication> applications = planSurplusApplication(
        debtValue: const Money(30000),
        sourceId: sourceA,
        pools: <SurplusPoolRead>[
          pool(scope: SurplusScope.source, sourceId: sourceA),
        ],
      );
      expect(applications.single.amount, const Money(20000));
      expect(
        applications.single.memo,
        'تسديد تلقائي من المبلغ المدفوع بتاريخ 2026/08/20',
      );
    });

    test('⛔⛔★★★ E-13 · AT-32 — فائضُ رداع وضمارُ ماوية ⟵ لا يُسدَّد شيء', () {
      final List<SurplusApplication> applications = planSurplusApplication(
        debtValue: const Money(30000),
        sourceId: sourceB,
        pools: <SurplusPoolRead>[
          pool(scope: SurplusScope.source, sourceId: sourceA),
        ],
      );
      expect(applications, isEmpty);
    });

    test('★★ والعامُّ يُسدَّد لأي مصدر', () {
      final List<SurplusApplication> applications = planSurplusApplication(
        debtValue: const Money(30000),
        sourceId: sourceB,
        pools: <SurplusPoolRead>[pool(scope: SurplusScope.general)],
      );
      expect(applications.single.amount, const Money(20000));
    });

    test('★★★ وبالأقدم أولاً بين السجلات — والمدفوعُ أولاً يُستهلَك أولاً', () {
      final List<SurplusApplication> applications = planSurplusApplication(
        debtValue: const Money(25000),
        sourceId: sourceA,
        pools: <SurplusPoolRead>[
          pool(scope: SurplusScope.general, available: 20000, paidDay: 25),
          pool(
            scope: SurplusScope.source,
            sourceId: sourceA,
            available: 20000,
            paidDay: 20,
          ),
        ],
      );
      expect(applications.length, 2);
      expect(applications.first.memo, contains('2026/08/20'));
      expect(applications.first.amount, const Money(20000));
      expect(applications.last.amount, const Money(5000));
    });

    test('⛔ وضمارٌ بقيمة صفر لا يسحب فائضاً', () {
      expect(
        planSurplusApplication(
          debtValue: Money.zero,
          sourceId: sourceA,
          pools: <SurplusPoolRead>[pool(scope: SurplusScope.general)],
        ),
        isEmpty,
      );
    });

    test('⛔ وسجلٌّ متاحُه صفر يُتخطّى', () {
      expect(
        planSurplusApplication(
          debtValue: const Money(5000),
          sourceId: sourceA,
          pools: <SurplusPoolRead>[
            pool(scope: SurplusScope.general, available: 0),
          ],
        ),
        isEmpty,
      );
    });

    test('★ ولا يُطبَّق أكثر من قيمة الضمار', () {
      final List<SurplusApplication> applications = planSurplusApplication(
        debtValue: const Money(5000),
        sourceId: sourceA,
        pools: <SurplusPoolRead>[
          pool(scope: SurplusScope.general, available: 90000),
        ],
      );
      expect(applications.single.amount, const Money(5000));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // ★★ الإيداع البنكي — AT-36
  // ═══════════════════════════════════════════════════════════════════════
  group('★★ تأكيد الإيداع البنكي — `FR-M12-15` · `AT-36`', () {
    test('⛔ بلا ملاحظة ⟵ يُرفَض', () {
      final Outcome<void> outcome = validateDepositConfirmation(note: null);
      expect(
        ((outcome as Failure<void>).error as ValidationError).ruleCode,
        'BR-M12-08',
      );
    });

    test('⛔★★ وفراغاتٌ تُقرأ غياباً لا نصّاً', () {
      expect(
        validateDepositConfirmation(note: '   '),
        isA<Failure<void>>(),
      );
    });

    test('★ وبملاحظة ⟵ يُقبَل', () {
      expect(
        validateDepositConfirmation(note: 'أُودع في حساب البنك الأهلي'),
        isA<Success<void>>(),
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // ★★ الرصيد والتسوية
  // ═══════════════════════════════════════════════════════════════════════
  group('★★ إجمالي الديون والتسوية بعد القبض', () {
    test('★★ FR-M12-03 — إجمالي الديون عبر كل المصادر', () {
      expect(
        totalOpenDebt(<OpenDebtLot>[
          lot(18, remaining: 20000),
          lot(20, remaining: 30000, sourceId: sourceB),
        ]),
        const Money(50000),
      );
    });

    test('⛔ وضمارٌ متبقّيه سالب لا يُنقِص الإجمالي', () {
      expect(
        totalOpenDebt(<OpenDebtLot>[
          lot(18, remaining: 20000),
          lot(20, remaining: -5000),
        ]),
        const Money(20000),
      );
    });

    test('★★★ التسوية بعد قبضٍ جزئي ⟵ «مفتوح جزئياً»', () {
      final DebtSettlement after = settlementAfterReceipt(
        current: computeDebtSettlement(
          debtValue: const Money(30000),
          settledAmount: Money.zero,
          discountedAmount: Money.zero,
        ),
        received: const Money(10000),
      );
      expect(after.settledAmount, const Money(10000));
      expect(after.remaining, const Money(20000));
      expect(after.status, SettlementStatus.partiallyOpen);
    });

    test('★★★ وبقبضٍ كامل ⟵ «مغلق»', () {
      final DebtSettlement after = settlementAfterReceipt(
        current: computeDebtSettlement(
          debtValue: const Money(30000),
          settledAmount: const Money(10000),
          discountedAmount: Money.zero,
        ),
        received: const Money(20000),
      );
      expect(after.remaining, Money.zero);
      expect(after.status, SettlementStatus.closed);
    });

    test('★★ والدائنُ يُنقِص الرصيد — `design-overview.md` §2.4', () {
      final DealerAccountBalance balance =
          computeDealerBalance(<DealerLedgerEntry>[
        const DealerLedgerEntry(
          direction: DealerLedgerDirection.debit,
          amount: Money(30000),
          isCancelled: false,
        ),
        const DealerLedgerEntry(
          direction: DealerLedgerDirection.credit,
          amount: Money(30000),
          isCancelled: false,
        ),
      ]);
      expect(balance.balance, Money.zero);
      expect(balance.hasSurplus, isFalse);
    });

    test('★★★ ودائنٌ يتجاوز المدين ⟵ «له فائض»', () {
      final DealerAccountBalance balance =
          computeDealerBalance(<DealerLedgerEntry>[
        const DealerLedgerEntry(
          direction: DealerLedgerDirection.debit,
          amount: Money(30000),
          isCancelled: false,
        ),
        const DealerLedgerEntry(
          direction: DealerLedgerDirection.credit,
          amount: Money(50000),
          isCancelled: false,
        ),
      ]);
      expect(balance.hasSurplus, isTrue);
      expect(balance.balance, const Money(-20000));
    });
  });
}

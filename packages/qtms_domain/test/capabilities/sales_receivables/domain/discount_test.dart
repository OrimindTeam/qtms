/// ★★★ **الخصومات** — `M13` · `FR-M13` · `WU-013`.
library;

import 'package:qtms_domain/qtms_domain.dart';
import 'package:test/test.dart';

const String dealerA = 'MQT-0001';
const String sourceA = 'SRC-001';
const String sourceB = 'SRC-002';

CalendarDay day(int d) => CalendarDay(2026, 9, d);

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

DebtSettlement settlement({
  int debtValue = 10000,
  int settled = 0,
  int discounted = 0,
}) =>
    computeDebtSettlement(
      debtValue: Money(debtValue),
      settledAmount: Money(settled),
      discountedAmount: Money(discounted),
    );

void main() {
  // ═══════════════════════════════════════════════════════════════════════
  // ⛔⛔★★★ الفصل عن القبض — `FR-M15-06-أ` · `schema/discounts.md`
  // ═══════════════════════════════════════════════════════════════════════
  group('⛔⛔★★★ الخصمُ مسارٌ منفصلٌ عن القبض — لا يُدخَل كمبلغٍ واصل', () {
    test('★★ المجموعةُ منفصلة — ⛔ ولا تساوي مجموعةَ المقبوضات', () {
      expect(discountsCollection, 'discounts');
      expect(discountsCollection, isNot(receiptsCollection));
    });

    test('★★★ ونوعُ القيد «خصم» مستقلٌّ عن «قبض» — `ت-04` · `GR-40`', () {
      expect(DealerLedgerEntryType.discount.name, 'discount');
      expect(
        DealerLedgerEntryType.discount,
        isNot(DealerLedgerEntryType.receipt),
      );
    });

    test('★★ ونوعُ قيد التدقيق مستقلٌّ كذلك — ومسجَّلٌ في القائمة', () {
      expect(discountEntityType, 'discount');
      expect(discountEntityType, isNot(receiptEntityType));
      // ⛔⛔ **وبلا التسجيل يُرفَض تصديرُ كل سند خصم** (`IQ-032` · `FR-M13-12`)
      //    — ★ **وهو العطل الذي تكرّر في `WU-010` و`WU-011` و`WU-012`.**
      expect(auditEntityTypes, contains(discountEntityType));
    });

    test('⛔⛔★★★ ومعرّفا الحركتين لا يلتقيان — البادئةُ تفصلهما', () {
      final String debtLot = lot(1).debtLotId;
      final String asDiscount = discountLedgerEntryId(
        documentNumber: 'DSC-20260901-0001',
        debtLotId: debtLot,
      );
      final String asReceipt = receiptLedgerEntryId(
        documentNumber: 'RCP-20260901-0001',
        debtLotId: debtLot,
      );
      expect(asDiscount, isNot(asReceipt));
      expect(asDiscount, startsWith('DSC-'));
    });

    test('★ والمعرّفُ مشتقٌّ ثابت — فإعادةُ الإرسال تكتب فوقه لا حركةً ثانية', () {
      final String debtLot = lot(1).debtLotId;
      expect(
        discountLedgerEntryId(
          documentNumber: 'DSC-20260901-0001',
          debtLotId: debtLot,
        ),
        discountLedgerEntryId(
          documentNumber: 'DSC-20260901-0001',
          debtLotId: debtLot,
        ),
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // ★★★ التسوية — `AT-33` · `FR-M13-03` · `FR-M13-08`
  // ═══════════════════════════════════════════════════════════════════════
  group('★★★ الخصمُ يخفض الضمار فعلاً — `AT-33`', () {
    test('★★★ `AT-33`: خصم 3,000 على ضمارٍ متبقيه 8,000 ⟵ المتبقي 5,000', () {
      final DebtSettlement current = settlement(debtValue: 8000);
      final DebtSettlement after = settlementAfterDiscount(
        current: current,
        discounted: const Money(3000),
      );
      expect(after.remaining, const Money(5000));
      expect(after.status, SettlementStatus.partiallyOpen);
    });

    test('⛔⛔★★★ ويُقيَّد في «المخصوم» وحدَه — ⛔ ولا يمسّ «المسدَّد»', () {
      final DebtSettlement after = settlementAfterDiscount(
        current: settlement(debtValue: 8000),
        discounted: const Money(3000),
      );
      expect(after.discountedAmount, const Money(3000));
      // ⛔⛔ **وهذا هو `ت-04` بنيوياً** — ★ **فالواصلُ لا يبتلع الخصم.**
      expect(after.settledAmount, Money.zero);
    });

    test('★★ والخصمُ يتراكم على خصمٍ سابق — ⛔ ولا يستبدله', () {
      final DebtSettlement after = settlementAfterDiscount(
        current: settlement(debtValue: 10000, discounted: 2000),
        discounted: const Money(3000),
      );
      expect(after.discountedAmount, const Money(5000));
      expect(after.remaining, const Money(5000));
    });

    test('★★ ويُغلِق الضمارَ متى استوفى المتبقي', () {
      final DebtSettlement after = settlementAfterDiscount(
        current: settlement(debtValue: 8000, settled: 5000),
        discounted: const Money(3000),
      );
      expect(after.remaining, Money.zero);
      expect(after.status, SettlementStatus.closed);
    });

    test('★★★ والقبضُ والخصمُ يتعايشان على ضمارٍ واحد بلا خلط', () {
      final DebtSettlement afterReceipt = settlementAfterReceipt(
        current: settlement(debtValue: 10000),
        received: const Money(4000),
      );
      final DebtSettlement afterBoth = settlementAfterDiscount(
        current: afterReceipt,
        discounted: const Money(3000),
      );
      expect(afterBoth.settledAmount, const Money(4000));
      expect(afterBoth.discountedAmount, const Money(3000));
      expect(afterBoth.remaining, const Money(3000));
    });

    test('★★ والإلغاءُ يردّ المخصوم — بمبلغٍ سالبٍ بلا معادلةٍ ثانية', () {
      final DebtSettlement after = settlementAfterDiscount(
        current: settlement(debtValue: 8000, discounted: 3000),
        discounted: Money.zero - const Money(3000),
      );
      expect(after.discountedAmount, Money.zero);
      expect(after.remaining, const Money(8000));
      expect(after.status, SettlementStatus.open);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // ★★★ سطر الخصم — `FR-M13-04` · `BR-M13-02`
  // ═══════════════════════════════════════════════════════════════════════
  group('★★★ سطرُ الخصم — > 0 ولا يتجاوز المتبقي', () {
    test('★ سطرٌ سليم يمرّ بمتبقٍّ محسوبٍ قبله وبعده', () {
      final OpenDebtLot l = lot(1, remaining: 8000);
      final Outcome<ValidatedDiscountLine> result = validateDiscountLine(
        line: DiscountLineInput(debtLotId: l.debtLotId, amount: const Money(3000)),
        lot: l,
      );
      expect(result, isA<Success<ValidatedDiscountLine>>());
      final ValidatedDiscountLine line =
          (result as Success<ValidatedDiscountLine>).value;
      expect(line.remainingBefore, const Money(8000));
      expect(line.amount, const Money(3000));
      expect(line.remainingAfter, const Money(5000));
    });

    test('⛔ ومبلغٌ يتجاوز المتبقي يُرفَض بـ`BR-M13-02`', () {
      final OpenDebtLot l = lot(1, remaining: 8000);
      final Outcome<ValidatedDiscountLine> result = validateDiscountLine(
        line: DiscountLineInput(debtLotId: l.debtLotId, amount: const Money(8001)),
        lot: l,
      );
      expect(result, isA<Failure<ValidatedDiscountLine>>());
      expect(
        ((result as Failure<ValidatedDiscountLine>).error as ValidationError)
            .ruleCode,
        'BR-M13-02',
      );
    });

    test('⛔ والصفرُ مرفوضٌ لا مُتجاهَل — فحركةٌ بلا أثرٍ تُلوِّث الكشف', () {
      final OpenDebtLot l = lot(1);
      expect(
        validateDiscountLine(
          line: DiscountLineInput(debtLotId: l.debtLotId, amount: Money.zero),
          lot: l,
        ),
        isA<Failure<ValidatedDiscountLine>>(),
      );
    });

    test('⛔ والسالبُ مرفوضٌ كذلك', () {
      final OpenDebtLot l = lot(1);
      expect(
        validateDiscountLine(
          line: DiscountLineInput(
            debtLotId: l.debtLotId,
            amount: Money.zero - const Money(100),
          ),
          lot: l,
        ),
        isA<Failure<ValidatedDiscountLine>>(),
      );
    });

    test('⛔⛔★★ والمصدرُ من الضمار المقروء لا من الحمولة — `E-35`', () {
      final OpenDebtLot l = lot(1, sourceId: sourceB);
      final ValidatedDiscountLine line = (validateDiscountLine(
        line: DiscountLineInput(debtLotId: l.debtLotId, amount: const Money(100)),
        lot: l,
      ) as Success<ValidatedDiscountLine>)
          .value;
      expect(line.sourceId, sourceB);
    });

    test('★★ وخصمان متتاليان لا يتجاوزان معاً قيمة الضمار', () {
      // ★ **المتبقي يُقاس بعد الخصم الأول** — ⟵ **فالثاني يُرفَض.**
      final OpenDebtLot afterFirst = lot(1, remaining: 5000);
      expect(
        validateDiscountLine(
          line: DiscountLineInput(
            debtLotId: afterFirst.debtLotId,
            amount: const Money(5001),
          ),
          lot: afterFirst,
        ),
        isA<Failure<ValidatedDiscountLine>>(),
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // ★★★ السند كاملاً — ⛔ **ولا فائضَ يُنقِذ سنداً فارغاً**
  // ═══════════════════════════════════════════════════════════════════════
  group('★★★ سندُ الخصم كاملاً — `FR-M13-02`', () {
    test('★ سندٌ بسطرين على ضمارين يمرّ', () {
      final List<OpenDebtLot> lots = <OpenDebtLot>[
        lot(1, remaining: 8000),
        lot(2, remaining: 5000),
      ];
      final Outcome<List<ValidatedDiscountLine>> result = validateDiscountLines(
        lines: <DiscountLineInput>[
          DiscountLineInput(debtLotId: lots[0].debtLotId, amount: const Money(3000)),
          DiscountLineInput(debtLotId: lots[1].debtLotId, amount: const Money(1000)),
        ],
        lotsById: byId(lots),
      );
      expect(result, isA<Success<List<ValidatedDiscountLine>>>());
      expect((result as Success<List<ValidatedDiscountLine>>).value, hasLength(2));
    });

    test('⛔⛔★★ وضمارٌ مكرَّرٌ في سطرين يُرفَض — وإلا أُسقِط أكثر من قيمته', () {
      final OpenDebtLot l = lot(1, remaining: 8000);
      final Outcome<List<ValidatedDiscountLine>> result = validateDiscountLines(
        lines: <DiscountLineInput>[
          DiscountLineInput(debtLotId: l.debtLotId, amount: const Money(5000)),
          DiscountLineInput(debtLotId: l.debtLotId, amount: const Money(5000)),
        ],
        lotsById: byId(<OpenDebtLot>[l]),
      );
      expect(result, isA<Failure<List<ValidatedDiscountLine>>>());
    });

    test('⛔ وضمارٌ لم يُقرأ رفضٌ لا تخطٍّ', () {
      expect(
        validateDiscountLines(
          lines: <DiscountLineInput>[
            const DiscountLineInput(debtLotId: 'لا-وجود-له', amount: Money(100)),
          ],
          lotsById: const <String, OpenDebtLot>{},
        ),
        isA<Failure<List<ValidatedDiscountLine>>>(),
      );
    });

    test('⛔⛔★★★ وسندٌ بلا سطرٍ يُرفَض قطعاً — ⛔ ولا فائضَ يُنقِذه', () {
      // ★ **وهنا يفترق عن سند القبض** — ⟵ **الذي يُجيز «الفائضَ وحده»**
      //    (`FR-M12-10`)، ⛔ **والخصمُ لا فائضَ فيه إطلاقاً** (`FR-M13-05`).
      expect(
        validateDiscountLines(
          lines: const <DiscountLineInput>[],
          lotsById: const <String, OpenDebtLot>{},
        ),
        isA<Failure<List<ValidatedDiscountLine>>>(),
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // ★★★ التاريخ — `FR-M13-06` · `AT-56`
  // ═══════════════════════════════════════════════════════════════════════
  group('★★★ تاريخُ السند — والمستقبلي يسبق الصلاحية', () {
    test('★ اليومُ مقبولٌ بلا صلاحية', () {
      expect(
        validateDiscountDate(
          date: day(10),
          today: day(10),
          canBackdate: false,
        ),
        isA<Success<void>>(),
      );
    });

    test('⛔⛔★★ والمستقبليُّ مرفوضٌ ولو ملك كلَّ المفاتيح — `AT-56`', () {
      final Outcome<void> result = validateDiscountDate(
        date: day(11),
        today: day(10),
        canBackdate: true,
      );
      expect(result, isA<Failure<void>>());
      // ★ **ورمزُ القاعدة قاعدةُ `M13` لا `M12`.**
      expect(
        ((result as Failure<void>).error as ValidationError).ruleCode,
        'BR-M13-04',
      );
    });

    test('⛔ والسابقُ بلا صلاحية يُرفَض بخطأ صلاحية لا تحقّق', () {
      final Outcome<void> result = validateDiscountDate(
        date: day(9),
        today: day(10),
        canBackdate: false,
      );
      expect(result, isA<Failure<void>>());
      expect((result as Failure<void>).error, isA<PermissionError>());
    });

    test('★ والسابقُ بصلاحيةٍ مقبول', () {
      expect(
        validateDiscountDate(date: day(9), today: day(10), canBackdate: true),
        isA<Success<void>>(),
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // ★★ التوزيع التلقائي — `FR-M13-07`
  // ═══════════════════════════════════════════════════════════════════════
  group('★★ التوزيعُ التلقائي للخصم — بالأقدم أولاً واقتراحٌ لا قرار', () {
    test('★★ يُسدَّد الأقدمُ بالكامل ثم يليه جزئياً', () {
      final DiscountAllocationProposal proposal = allocateDiscountAutomatically(
        amount: const Money(10000),
        openLots: <OpenDebtLot>[
          lot(2, remaining: 5000),
          lot(1, remaining: 8000),
        ],
      );
      expect(proposal.lines, hasLength(2));
      // ★ **الأقدم (يوم 1) أولاً وبالكامل.**
      expect(proposal.lines[0].debtLotId, lot(1).debtLotId);
      expect(proposal.lines[0].amount, const Money(8000));
      expect(proposal.lines[1].amount, const Money(2000));
      expect(proposal.unallocated, Money.zero);
    });

    test('⛔⛔★★ وما يزيد «غيرُ موزَّع» ⛔ لا فائضٌ يُحفَظ', () {
      final DiscountAllocationProposal proposal = allocateDiscountAutomatically(
        amount: const Money(20000),
        openLots: <OpenDebtLot>[lot(1, remaining: 8000)],
      );
      expect(proposal.lines, hasLength(1));
      expect(proposal.unallocated, const Money(12000));
    });

    test('★ ولا يقترح سطراً لضمارٍ متبقّيه صفر', () {
      final DiscountAllocationProposal proposal = allocateDiscountAutomatically(
        amount: const Money(1000),
        openLots: <OpenDebtLot>[
          lot(1, remaining: 0),
          lot(2, remaining: 5000),
        ],
      );
      expect(proposal.lines, hasLength(1));
      expect(proposal.lines.single.debtLotId, lot(2).debtLotId);
    });

    test('★★ والاقتراحُ ثابتٌ بين عرضين — ترتيبٌ مستقر', () {
      final List<OpenDebtLot> lots = <OpenDebtLot>[
        lot(1, remaining: 5000),
        lot(1, remaining: 5000, sourceId: sourceB),
      ];
      final DiscountAllocationProposal a =
          allocateDiscountAutomatically(amount: const Money(7000), openLots: lots);
      final DiscountAllocationProposal b =
          allocateDiscountAutomatically(amount: const Money(7000), openLots: lots);
      expect(
        a.lines.map((DiscountLineInput l) => l.debtLotId).toList(),
        b.lines.map((DiscountLineInput l) => l.debtLotId).toList(),
      );
    });

    test('⛔ ومخرَجُ الاقتراح لا يُحفَظ إلا بعد التحقق — فالفائضُ يُرفَض سطراً', () {
      // ★ **اقتراحٌ بمبلغٍ يتجاوز الديون يُنتج سطوراً صالحة وباقياً غير موزَّع**
      //    — ⟵ **والباقي لا يُرسَل أصلاً**، ★ **والسطورُ تمرّ التحقق.**
      final OpenDebtLot l = lot(1, remaining: 8000);
      final DiscountAllocationProposal proposal = allocateDiscountAutomatically(
        amount: const Money(20000),
        openLots: <OpenDebtLot>[l],
      );
      expect(
        validateDiscountLines(
          lines: proposal.lines,
          lotsById: byId(<OpenDebtLot>[l]),
        ),
        isA<Success<List<ValidatedDiscountLine>>>(),
      );
    });
  });
}

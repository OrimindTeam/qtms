/// ★★★ **ضمار المالك وحركة النقد** — `M15` · `FR-M15` · `WU-016`.
///
/// ⛔⛔★★★ **وأرقامُ §15 المرجعية هنا ليست عيّنةً اختُرِعت** — ★ **هي نصُّ
/// [`TC-FIN-001`](../../../../../../docs/08-testing-and-qa/test-cases/TC-FIN-001-reference-day-scenario.md)
/// §5 حرفياً**: ⟵ **«كل رقم يُشتقّ من §15 حرفياً ⛔ ولا يُنسَخ من مخرج
/// الكود»**، ★ **فأيُّ انحرافٍ عنها خللٌ في الكود لا في التوقّع.**
library;

import 'package:qtms_domain/qtms_domain.dart';
import 'package:test/test.dart';

const String radaa = 'SRC-RADAA';
const String mawiyah = 'SRC-MAWIYAH';

CalendarDay day(int d) => CalendarDay(2026, 8, d);

// ═══════════════════════════════════════════════════════════════════════
// ★ سيناريو §15 — رداع · 20/08 (`TC-FIN-001` §5)
//
//   إجمالي الضمار 545,550 · النقدي 27,450 · الواصل 149,500 · الخصم 5,000
//   ⟹ قبل الخصم 368,600 · بعد الخصم 363,600 · الصافي النهائي 330,475
//
// ⚠️⚠️ **والمستند يُثبت مجموعَ (الضريبة + السحبيات + الخرجيات) لا تفصيلَه**
//   — 363,600 − 330,475 = **33,125**: ⟵ **فالتفصيلُ أدناه أحدُ التقسيمات**،
//   ★ **واختبارُ «أيُّ تقسيمٍ يُنتج الصافيَ نفسَه» يُثبت أن المعادلة لا
//   التقسيم هو المقيس** ⛔ **فلا رقمَ مخترَعٌ يُقاس عليه.**
// ═══════════════════════════════════════════════════════════════════════

const int radaaCredit = 518100; // 545,550 − 27,450
const int radaaCash = 27450;
const int radaaSettled = 149500;
const int radaaDiscounts = 5000;
const int radaaDeductions = 33125; // الضريبة + السحبيات + الخرجيات

OwnerLedgerContributions radaaContributions({
  int tax = 8125,
  int withdrawals = 20000,
  int expenses = 5000,
}) =>
    OwnerLedgerContributions(
      credit: const Money(radaaCredit),
      cash: const Money(radaaCash),
      settledOfDay: const Money(radaaSettled),
      discounts: const Money(radaaDiscounts),
      tax: Money(tax),
      withdrawals: Money(withdrawals),
      expenses: Money(expenses),
    );

OwnerLedgerSummary radaaSummary({
  int tax = 8125,
  int withdrawals = 20000,
  int expenses = 5000,
}) =>
    computeOwnerLedgerSummary(
      sourceId: radaa,
      date: day(20),
      contributions: radaaContributions(
        tax: tax,
        withdrawals: withdrawals,
        expenses: expenses,
      ),
    );

void main() {
  group('المفاتيح', () {
    test('مفتاح ملخّص المصدر مركّب من المصدر واليوم', () {
      expect(
        dailySummaryId(sourceId: radaa, date: day(20)),
        'SRC-RADAA_20260820',
      );
    });

    test('مفتاح البطاقة التجميعية يبدأ بـall', () {
      expect(allSourcesSummaryId(day(20)), 'all_20260820');
      expect(allSourcesScopeId, 'all');
    });

    test('مفتاح السلسلة هو المصدر نفسه — مستندٌ واحدٌ لا مستندٌ لكل يوم', () {
      expect(ownerLedgerTrendId(radaa), radaa);
      expect(ownerLedgerTrendId(allSourcesScopeId), 'all');
    });

    test('المصدر الفارغ يُرفض رفضاً صريحاً', () {
      expect(
        () => dailySummaryId(sourceId: '', date: day(20)),
        throwsArgumentError,
      );
      expect(() => ownerLedgerTrendId(''), throwsArgumentError);
    });
  });

  group('★★★ البنود العشرة — أرقام §15 المرجعية', () {
    final OwnerLedgerSummary summary = radaaSummary();

    test('① إجمالي الضمار = الآجل + النقدي = 545,550', () {
      expect(summary.totalDebt, const Money(545550));
      expect(summary.credit, const Money(radaaCredit));
      expect(summary.cash, const Money(radaaCash));
    });

    test('④ باقي الضمار قبل الخصم = 368,600 — نصّ المصدر حرفياً', () {
      expect(summary.remainingBeforeDiscount, const Money(368600));
    });

    test('⑤ باقي الضمار بعد الخصم = 363,600 — الذمم المفتوحة الفعلية', () {
      expect(summary.remainingAfterDiscount, const Money(363600));
    });

    test('★ والفارق بين الصفّين هو الخصم بالضبط — 5,000', () {
      expect(
        summary.remainingBeforeDiscount.riyals -
            summary.remainingAfterDiscount.riyals,
        radaaDiscounts,
      );
    });

    test('⑩ الصافي النهائي = 330,475 — مبنيٌّ على «بعد الخصم»', () {
      expect(summary.netFinal, const Money(330475));
    });

    test('⛔ ولا يُبنى الصافي على «قبل الخصم» — وإلا لصار 335,475', () {
      expect(summary.netFinal, isNot(const Money(335475)));
    });

    test('★ وأيُّ تقسيمٍ للـ33,125 يُنتج الصافيَ نفسَه — المعادلةُ هي المقيس',
        () {
      for (final (int, int, int) split in <(int, int, int)>[
        (8125, 20000, 5000),
        (0, 33125, 0),
        (33125, 0, 0),
        (1, 1, 33123),
      ]) {
        final OwnerLedgerSummary variant = radaaSummary(
          tax: split.$1,
          withdrawals: split.$2,
          expenses: split.$3,
        );
        expect(variant.netFinal, const Money(330475));
        expect(
          split.$1 + split.$2 + split.$3,
          radaaDeductions,
          reason: 'التقسيم يجب أن يبقى على المجموع المُثبَت',
        );
      }
    });

    test('يومٌ بلا حركة يُنتج أصفاراً صريحة لا شرطات', () {
      final OwnerLedgerSummary empty = computeOwnerLedgerSummary(
        sourceId: radaa,
        date: day(21),
        contributions: const OwnerLedgerContributions(),
      );
      expect(empty.totalDebt, Money.zero);
      expect(empty.netFinal, Money.zero);
      expect(const OwnerLedgerContributions().isEmpty, isTrue);
    });

    test('★ والنقدي المحصَّل فوراً لا يبقى ذمّةً — يُطرح في ④', () {
      final OwnerLedgerSummary cashOnly = computeOwnerLedgerSummary(
        sourceId: radaa,
        date: day(20),
        contributions: const OwnerLedgerContributions(cash: Money(50000)),
      );
      expect(cashOnly.totalDebt, const Money(50000));
      expect(cashOnly.remainingBeforeDiscount, Money.zero);
    });
  });

  group('★★ بطاقة «كل المصادر» — مجموعُ بطاقات المصادر عرضاً فقط', () {
    test('اختبارُ التوازن: المجموع بنداً ببند', () {
      final OwnerLedgerSummary a = radaaSummary();
      final OwnerLedgerSummary b = computeOwnerLedgerSummary(
        sourceId: mawiyah,
        date: day(20),
        contributions: const OwnerLedgerContributions(
          credit: Money(100000),
          cash: Money(10000),
          settledOfDay: Money(30000),
          tax: Money(2200),
          withdrawals: Money(3000),
        ),
      );
      final OwnerLedgerSummary all = aggregateOwnerLedgerSummaries(
        date: day(20),
        summaries: <OwnerLedgerSummary>[a, b],
      );

      expect(all.sourceId, allSourcesScopeId);
      expect(all.totalDebt, a.totalDebt + b.totalDebt);
      expect(
        all.remainingAfterDiscount,
        a.remainingAfterDiscount + b.remainingAfterDiscount,
      );
      expect(all.netFinal, a.netFinal + b.netFinal);
    });

    test('★ والصافي التجميعي 405,275 — بأرقام §15', () {
      // ★ **74,800 هو صافي بقية المصادر** — 405,275 − 330,475 (`TC-FIN-001`).
      final OwnerLedgerSummary others = computeOwnerLedgerSummary(
        sourceId: mawiyah,
        date: day(20),
        contributions: const OwnerLedgerContributions(credit: Money(74800)),
      );
      final OwnerLedgerSummary all = aggregateOwnerLedgerSummaries(
        date: day(20),
        summaries: <OwnerLedgerSummary>[radaaSummary(), others],
      );
      expect(all.netFinal, const Money(405275));
    });

    test('⛔ ومن نطاقه مصدرٌ واحد تُجمَع له من مصادره وحدها — E-36', () {
      final OwnerLedgerSummary scoped = aggregateOwnerLedgerSummaries(
        date: day(20),
        summaries: <OwnerLedgerSummary>[radaaSummary()],
      );
      expect(scoped.netFinal, const Money(330475));
    });

    test('★ وأحدثُ وسمٍ رجعيٍّ بين المصادر يَسِمُ التجميعية', () {
      final DateTime older = DateTime.utc(2026, 8, 21, 6);
      final DateTime newer = DateTime.utc(2026, 8, 22, 9);
      final OwnerLedgerSummary all = aggregateOwnerLedgerSummaries(
        date: day(20),
        summaries: <OwnerLedgerSummary>[
          computeOwnerLedgerSummary(
            sourceId: radaa,
            date: day(20),
            contributions: const OwnerLedgerContributions(credit: Money(10)),
            retroUpdatedAt: older,
          ),
          computeOwnerLedgerSummary(
            sourceId: mawiyah,
            date: day(20),
            contributions: const OwnerLedgerContributions(credit: Money(10)),
            retroUpdatedAt: newer,
          ),
        ],
      );
      expect(all.retroUpdatedAt, newer);
    });

    test('ولا وسمَ حين لا مصدرَ أُعيد بناؤه', () {
      final OwnerLedgerSummary all = aggregateOwnerLedgerSummaries(
        date: day(20),
        summaries: <OwnerLedgerSummary>[radaaSummary()],
      );
      expect(all.retroUpdatedAt, isNull);
    });
  });

  group('⛔⛔★★★ البناء حسب صلاحيات القارئ — §5 · FR-M15-10 · E-29', () {
    final OwnerLedgerSummary summary = radaaSummary();

    test('من يملك المفتاحين يرى البندين والصافي الكامل', () {
      final OwnerLedgerProjection full =
          projectOwnerLedgerSummary(summary, OwnerLedgerVisibility.full);
      expect(full.withdrawals, const Money(20000));
      expect(full.expenses, const Money(5000));
      expect(full.netFinal, const Money(330475));
    });

    test('⛔ ومن لا يملك «عرض سحبيات المالك» يصله null لا صفراً', () {
      final OwnerLedgerProjection view = projectOwnerLedgerSummary(
        summary,
        const OwnerLedgerVisibility(
          showsWithdrawals: false,
          showsExpenses: true,
        ),
      );
      expect(view.withdrawals, isNull);
      expect(view.expenses, const Money(5000));
      // ★ **والبندُ يخرج من الصافي كما يخرج من البطاقة** — §5.
      expect(view.netFinal, const Money(330475 + 20000));
    });

    test('⛔ ومن لا يملك «عرض الخرجيات» كذلك', () {
      final OwnerLedgerProjection view = projectOwnerLedgerSummary(
        summary,
        const OwnerLedgerVisibility(
          showsWithdrawals: true,
          showsExpenses: false,
        ),
      );
      expect(view.expenses, isNull);
      expect(view.netFinal, const Money(330475 + 5000));
    });

    test('★ ومَن لا يملك المفتاحين يرى ⑦ نفسَه صافياً', () {
      final OwnerLedgerProjection view = projectOwnerLedgerSummary(
        summary,
        const OwnerLedgerVisibility(
          showsWithdrawals: false,
          showsExpenses: false,
        ),
      );
      expect(view.netFinal, summary.remainingAfterTax);
      expect(view.summary.remainingAfterTax, const Money(355475));
    });

    test('⛔ وصفرٌ حقيقيٌّ يبقى صفراً معروضاً لا محذوفاً', () {
      final OwnerLedgerProjection view = projectOwnerLedgerSummary(
        radaaSummary(tax: 33125, withdrawals: 0, expenses: 0),
        OwnerLedgerVisibility.full,
      );
      expect(view.withdrawals, Money.zero);
      expect(view.expenses, Money.zero);
    });
  });

  group('✅★★ سجلُّ السلسلة — IQ-030', () {
    OwnerLedgerTrendPoint point(int d, int net) => OwnerLedgerTrendPoint(
          date: day(d),
          netFinal: Money(net),
          withdrawals: const Money(1000),
          expenses: const Money(500),
        );

    test('يُدرِج النقطة مرتَّبةً تصاعدياً', () {
      final List<OwnerLedgerTrendPoint> series = appendOwnerLedgerTrendPoint(
        <OwnerLedgerTrendPoint>[point(19, 200), point(17, 100)],
        point(18, 150),
      );
      expect(
        series.map((OwnerLedgerTrendPoint p) => p.date.day),
        <int>[17, 18, 19],
      );
    });

    test('⛔⛔ ويستبدل نقطة اليوم نفسِه ولا يُضيف ثانية — idempotent', () {
      List<OwnerLedgerTrendPoint> series = <OwnerLedgerTrendPoint>[];
      for (int i = 0; i < 5; i++) {
        series = appendOwnerLedgerTrendPoint(series, point(20, 300 + i));
      }
      expect(series, hasLength(1));
      expect(series.single.netFinal, const Money(304));
    });

    test('★ ولا تتجاوز السلسلة سبعَ نقاط — والأقدم يسقط', () {
      List<OwnerLedgerTrendPoint> series = <OwnerLedgerTrendPoint>[];
      for (int d = 10; d <= 20; d++) {
        series = appendOwnerLedgerTrendPoint(series, point(d, d));
      }
      expect(series, hasLength(ownerLedgerTrendLength));
      expect(series.first.date, day(14));
      expect(series.last.date, day(20));
    });

    test('★ والأثرُ الرجعي يُصلح موضعَ اليوم في مكانه لا في آخر السلسلة', () {
      List<OwnerLedgerTrendPoint> series = <OwnerLedgerTrendPoint>[];
      for (int d = 18; d <= 20; d++) {
        series = appendOwnerLedgerTrendPoint(series, point(d, d));
      }
      series = appendOwnerLedgerTrendPoint(
        series,
        OwnerLedgerTrendPoint(
          date: day(18),
          netFinal: const Money(999),
          withdrawals: Money.zero,
          expenses: Money.zero,
          retroUpdated: true,
        ),
      );
      expect(series.first.date, day(18));
      expect(series.first.netFinal, const Money(999));
      expect(series.first.retroUpdated, isTrue);
      expect(series, hasLength(3));
    });

    test('⛔⛔ ولا يكشف الرسمُ ما تُخفيه البطاقة — §2.1 القاعدة 5', () {
      final OwnerLedgerTrendPoint p = point(20, 330475);
      expect(p.netFinalFor(OwnerLedgerVisibility.full), const Money(330475));
      expect(
        p.netFinalFor(
          const OwnerLedgerVisibility(
            showsWithdrawals: false,
            showsExpenses: true,
          ),
        ),
        const Money(331475),
      );
      expect(
        p.netFinalFor(
          const OwnerLedgerVisibility(
            showsWithdrawals: false,
            showsExpenses: false,
          ),
        ),
        const Money(331975),
      );
    });
  });

  group('★★★ حركة النقد في تاريخ — §2.9 · FR-M15-15…21', () {
    // ★ **أرقام السيناريو:** المقبوض 200,000 (`AT-49`) · النقدي 27,450 ·
    //   الداخل 227,450 · الخارج 46,250 · الصافي 181,200 (`FR-M15-18`).
    CashMovementSummary reference({int deposited = 0}) => computeCashMovement(
          date: day(20),
          contributions: CashMovementContributions(
            receivedForSameDayDebt: const Money(149500),
            receivedForPreviousDays: const Money(40500),
            receivedAsSurplus: const Money(10000),
            cashSales: const Money(27450),
            withdrawals: const Money(36250),
            expenses: const Money(10000),
            discounts: const Money(5000),
            deposited: Money(deposited),
          ),
        );

    test('المقبوض في التاريخ = 200,000 — بثلاثة أوجهٍ مفصَّلة', () {
      final CashMovementSummary cash = reference();
      expect(cash.receivedFromDealers, const Money(200000));
      expect(cash.receivedForSameDayDebt, const Money(149500));
      expect(cash.receivedForPreviousDays, const Money(40500));
      expect(cash.receivedAsSurplus, const Money(10000));
    });

    test('★ الداخل 227,450 والخارج 46,250 والصافي 181,200', () {
      final CashMovementSummary cash = reference();
      expect(cash.totalIn, const Money(227450));
      expect(cash.totalOut, const Money(46250));
      expect(cash.netInHand, const Money(181200));
    });

    test('⛔⛔ و«الواصل» ≠ «المقبوض» — GR-41 · AT-49', () {
      final CashMovementSummary cash = reference();
      final OwnerLedgerSummary card = radaaSummary();
      expect(card.settledOfDay, const Money(149500));
      expect(cash.receivedFromDealers, const Money(200000));
      expect(cash.receivedFromDealers, isNot(card.settledOfDay));
    });

    test('⛔ والخصومات تُعرض للعلم ولا تُطرح — FR-M15-20', () {
      final CashMovementSummary cash = reference();
      expect(cash.discounts, const Money(5000));
      expect(cash.netInHand, const Money(181200));
    });

    test('نسبةُ التغطية تُقاس على المقبوض لا على الواصل — GR-47', () {
      expect(reference().coveragePercent, 23); // 46,250 ÷ 200,000
    });

    test('⛔ ولا نسبةَ حين لا مقبوضَ يُقاس عليه — null لا صفر', () {
      final CashMovementSummary empty = computeCashMovement(
        date: day(21),
        contributions: const CashMovementContributions(
          cashSales: Money(1000),
        ),
      );
      expect(empty.coveragePercent, isNull);
      expect(empty.netInHand, const Money(1000));
    });

    test('الإيداع: أُودع / لم يُودع بعد — R-24', () {
      final CashMovementSummary cash = reference(deposited: 120000);
      expect(cash.deposited, const Money(120000));
      expect(cash.notDeposited, const Money(80000));
    });

    test('★ تنبيهُ فجوة النقد حين يقلّ الصافي عمّا لم يُودع', () {
      expect(reference(deposited: 120000).hasCashGap, isFalse);
      expect(reference().hasCashGap, isTrue); // 181,200 < 200,000
    });

    test('⛔ ولا تنبيهَ حين لا شيءَ لم يُودَع', () {
      expect(reference(deposited: 200000).hasCashGap, isFalse);
    });

    // ═══════════════════════════════════════════════════════════════════
    // ⛔⛔★★★ E-29 يذكر النقدَ صراحةً — «يختفي من البطاقة *والنقد*»
    // ═══════════════════════════════════════════════════════════════════

    test('★ من يملك المفتاحين يرى البندين والإجماليَّ الكامل', () {
      final CashMovementProjection view =
          projectCashMovement(reference(), OwnerLedgerVisibility.full);
      expect(view.withdrawals, const Money(36250));
      expect(view.expenses, const Money(10000));
      expect(view.totalOut, const Money(46250));
      expect(view.netInHand, const Money(181200));
    });

    test('⛔⛔ ومن لا يملك «عرض السحبيات» يصله null والإجماليُّ بلا مبلغه', () {
      final CashMovementProjection view = projectCashMovement(
        reference(),
        const OwnerLedgerVisibility(
          showsWithdrawals: false,
          showsExpenses: true,
        ),
      );
      expect(view.withdrawals, isNull);
      expect(view.expenses, const Money(10000));
      // ⛔⛔ **وإلا كُشف المخفيُّ بالطرح** — 46,250 − 10,000.
      expect(view.totalOut, const Money(10000));
      expect(view.netInHand, const Money(217450));
      expect(view.coveragePercent, 5);
    });

    test('★ ومَن لا يملك المفتاحين يرى الداخلَ صافياً', () {
      final CashMovementProjection view = projectCashMovement(
        reference(),
        const OwnerLedgerVisibility(
          showsWithdrawals: false,
          showsExpenses: false,
        ),
      );
      expect(view.totalOut, Money.zero);
      expect(view.netInHand, const Money(227450));
    });
  });
}

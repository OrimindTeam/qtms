/// ★★★ **تحويلُ الملخّص إلى عقد العرض** — `WU-016` · `FR-M15-10` · §10.1.
///
/// ⚠️⚠️ **وما تُثبته هذه الاختبارات عقدٌ لا شكل:**
/// ① ⛔⛔ **البندُ المحكومُ يصل `null` لمن لا يملكه** — ⛔ **لا صفراً نصّياً.**
/// ② ★★ **والصافيُ من الإسقاط لا من المخزَّن** — ⟵ **فرقمُه يختلف بين قارئين.**
/// ③ ★ **وكلُّ حقلٍ نصٌّ منسَّقٌ مسبقاً** — ⛔ **ولا عددَ خام يعبر إلى الشاشة.**
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:qtms/capabilities/financial_outflow/presentation/owner_ledger_card.dart';
import 'package:qtms/capabilities/financial_outflow/presentation/owner_ledger_format.dart';
import 'package:qtms_domain/qtms_domain.dart';

final CalendarDay day = CalendarDay(2026, 8, 20);

/// ★ ملخّصُ §15 المرجعي — `TC-FIN-001` §5.
OwnerLedgerSummary reference({DateTime? retro}) => computeOwnerLedgerSummary(
      sourceId: 'SRC-RADAA',
      date: day,
      contributions: const OwnerLedgerContributions(
        credit: Money(518100),
        cash: Money(27450),
        settledOfDay: Money(149500),
        discounts: Money(5000),
        tax: Money(8125),
        withdrawals: Money(20000),
        expenses: Money(5000),
      ),
      retroUpdatedAt: retro,
    );

void main() {
  group('★★★ الأرقام تصل نصّاً منسَّقاً — ADR-0015', () {
    test('البنودُ العشرة بفواصل الآلاف', () {
      final OwnerLedgerSummaryView v = ownerLedgerViewOf(
        projectOwnerLedgerSummary(reference(), OwnerLedgerVisibility.full),
        scopeLabel: 'رداع',
        isLive: true,
      );
      expect(v.totalDebt, '545,550');
      expect(v.remainingBeforeDiscount, '368,600');
      expect(v.remainingAfterDiscount, '363,600');
      expect(v.netFinal, '330,475');
      expect(v.currencyLabel, riyalLabel);
      expect(v.scopeLabel, 'رداع');
    });
  });

  group('⛔⛔★★★ البندُ المحكوم — E-29 · §10.1 القاعدة 2', () {
    test('من لا يملك «عرض سحبيات المالك» يصله null لا «0»', () {
      final OwnerLedgerSummaryView v = ownerLedgerViewOf(
        projectOwnerLedgerSummary(
          reference(),
          const OwnerLedgerVisibility(
            showsWithdrawals: false,
            showsExpenses: true,
          ),
        ),
        scopeLabel: 'رداع',
        isLive: true,
      );
      expect(v.withdrawals, isNull);
      expect(v.expenses, '5,000');
      // ★★ **والصافي يختلف — سلوكٌ مقصود لا خلل** (§5).
      expect(v.netFinal, '350,475');
    });

    test('★ وصفرٌ حقيقيٌّ يبقى «0» معروضاً لا محذوفاً', () {
      final OwnerLedgerSummary zeroWithdrawals = computeOwnerLedgerSummary(
        sourceId: 'SRC-RADAA',
        date: day,
        contributions: const OwnerLedgerContributions(credit: Money(1000)),
      );
      final OwnerLedgerSummaryView v = ownerLedgerViewOf(
        projectOwnerLedgerSummary(
          zeroWithdrawals,
          OwnerLedgerVisibility.full,
        ),
        scopeLabel: 'رداع',
        isLive: true,
      );
      expect(v.withdrawals, '0');
      expect(v.expenses, '0');
    });
  });

  group('★ وسمُ الأثر الرجعي — FR-M15-12', () {
    test('يصل تاريخاً جاهزاً منسَّقاً', () {
      final OwnerLedgerSummaryView v = ownerLedgerViewOf(
        projectOwnerLedgerSummary(
          reference(retro: DateTime.utc(2026, 8, 22, 9, 30)),
          OwnerLedgerVisibility.full,
        ),
        scopeLabel: 'رداع',
        isLive: true,
      );
      expect(v.retroUpdatedAtLabel, isNotNull);
      expect(v.retroUpdatedAtLabel, contains('2026'));
    });

    test('⛔ ولا وسمَ بلا تاريخ', () {
      final OwnerLedgerSummaryView v = ownerLedgerViewOf(
        projectOwnerLedgerSummary(reference(), OwnerLedgerVisibility.full),
        scopeLabel: 'رداع',
        isLive: true,
      );
      expect(v.retroUpdatedAtLabel, isNull);
    });
  });

  group('★ فرقُ اليوم عن أمس — FR-M15-23', () {
    OwnerLedgerSummaryView withPrevious(int? previous) => ownerLedgerViewOf(
          projectOwnerLedgerSummary(reference(), OwnerLedgerVisibility.full),
          scopeLabel: 'رداع',
          isLive: true,
          previousNetFinal: previous == null ? null : Money(previous),
        );

    test('⛔ ولا مقارنةَ بلا يومِ أمس — null لا «0٪»', () {
      expect(withPrevious(null).deltaLabel, isNull);
    });

    test('★ وارتفاعٌ بسهمٍ ونسبة', () {
      final OwnerLedgerSummaryView v = withPrevious(300000);
      expect(v.deltaLabel, contains('▲'));
      expect(v.deltaIsPositive, isTrue);
    });

    test('★ وانخفاضٌ بسهمٍ معاكس', () {
      final OwnerLedgerSummaryView v = withPrevious(400000);
      expect(v.deltaLabel, contains('▼'));
      expect(v.deltaIsPositive, isFalse);
    });

    test('★ وتساوٍ يُقال نصّاً لا بنسبةٍ صفرية', () {
      expect(withPrevious(330475).deltaLabel, 'كما أمس');
    });

    test('⛔ ولا قسمةَ على صفر — أمسٌ بصفرٍ يُعرَض بالمبلغ وحده', () {
      final OwnerLedgerSummaryView v = withPrevious(0);
      expect(v.deltaLabel, isNot(contains('٪')));
      expect(v.deltaLabel, contains('330,475'));
    });
  });

  // ★★★ `AM-023` — نصُّ مشاركةِ ملخّص اليوم.
  group('★★★ AM-023 — نصُّ المشاركة يطابق البطاقة حرفاً بحرف', () {
    OwnerLedgerSummaryView viewOf(OwnerLedgerVisibility visibility) =>
        ownerLedgerViewOf(
          projectOwnerLedgerSummary(reference(), visibility),
          scopeLabel: 'رداع',
          isLive: true,
        );

    test('★ كلُّ بندٍ بنصِّه المنسَّق — ⛔ ولا رقمَ يُبنى في النصّ', () {
      final String text = ownerLedgerShareText(
        viewOf(OwnerLedgerVisibility.full),
        dayLabel: '2026/08/20',
      );
      expect(text, contains('ضمار المالك — 2026/08/20'));
      expect(text, contains('رداع'));
      expect(text, contains('إجمالي الضمار: 545,550'));
      expect(text, contains('باقي الضمار قبل الخصم: 368,600'));
      expect(text, contains('باقي الضمار بعد الخصم: 363,600'));
      expect(text, contains('السحبيات: 20,000'));
      expect(text, contains('الخرجيات: 5,000'));
      expect(text, contains('الصافي النهائي: 330,475 ريال'));
    });

    test('⛔⛔★★★ والبندُ المحكومُ يغيب عن النصّ كما يغيب عن البطاقة — E-29', () {
      final String text = ownerLedgerShareText(
        viewOf(
          const OwnerLedgerVisibility(
            showsWithdrawals: false,
            showsExpenses: true,
          ),
        ),
        dayLabel: '2026/08/20',
      );
      // ⛔ **ولا صفراً** — ★ **الصفرُ معلومةٌ مختلفةٌ عن الغياب** (§9).
      expect(text, isNot(contains('السحبيات')));
      expect(text, contains('الخرجيات: 5,000'));
    });
  });
}

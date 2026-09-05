/// `R-07` — **الوزن الضائع والسكرب والإتلاف** (`WU-020` · `FR-M19` §2).
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **وما تُثبته هذه الاختبارات:** ★ **أن الوزن الضائع لا يظهر بلا
/// تأكيدٍ صريح** (`BR-M7-12`) · **وأن الملغى يُعرَض ولا يُحتسَب** (`A-14`) ·
/// **وأن إجمالياتِ الحبّة والوزن لا تُجمَع** (`GR-19`) · **وأن فلتر الرعوي
/// يستبعد الإتلاف كلَّه** ⟵ **إذ لا رعويَّ لمستنده** (`data-dictionary.md`).
/// ═══════════════════════════════════════════════════════════════════════
library;

import 'package:qtms_domain/qtms_domain.dart';
import 'package:test/test.dart';

final CalendarDay dayA = CalendarDay(2026, 9, 3);
final CalendarDay dayB = CalendarDay(2026, 9, 4);
final ReportPeriod span = ReportPeriod.of(from: dayA, to: dayB)!;

SackCard sackOf({
  required int sequence,
  double total = 45,
  double ice = 6.5,
  double scrap = 1.2,
  bool lostConfirmed = false,
  String? supplierId,
  String? supplierName,
  SackStatus status = SackStatus.approved,
  String? lostWeightNote,
}) {
  final ValidatedSackWeights weights = ValidatedSackWeights(
    totalWeight: WeightKg(total),
    iceWeight: WeightKg(ice),
    scrapWeight: WeightKg(scrap),
  );
  return SackCard(
    documentNumber: 'SCK-20260903-000$sequence',
    sourceId: 'SRC-001',
    stockDate: dayA,
    entryDate: DateTime.utc(2026, 9, 3, 6),
    dailySequence: sequence,
    displayName: sackDisplayName(dailySequence: sequence),
    status: status,
    weights: weights,
    explanation: explainSackWeight(
      weights: weights,
      lines: const <ValidatedSackLine>[],
      lostWeightConfirmed: lostConfirmed,
    ),
    lostWeightConfirmed: lostConfirmed,
    lines: const <ValidatedSackLine>[],
    supplierId: supplierId,
    supplierName: supplierName,
    lostWeightNote: lostWeightNote,
  );
}

DisposalCard disposalOf({
  String number = 'DSP-20260904-0001',
  List<DisposalCardLine>? lines,
  bool isCancelled = false,
  String? reason,
}) =>
    DisposalCard(
      documentNumber: number,
      stockDate: dayB,
      sourceId: 'SRC-001',
      isCancelled: isCancelled,
      reason: reason,
      lines: lines ??
          <DisposalCardLine>[
            const DisposalCardLine(
              itemKey: 'ITM-0001',
              itemName: 'عوارض',
              quantity: PieceQuantity(PieceCount(8)),
            ),
          ],
    );

String? totalOf(ReportTable table, String label) {
  for (final ExportField field in table.totals) {
    if (field.label == label) return field.value;
  }
  return null;
}

void main() {
  group('★★★ R-07 — البنودُ الثلاثة في جدولٍ واحد', () {
    test('★★ سطرُ سكربٍ وسطرُ إتلافٍ — ولا سطرَ ضائعٍ بلا تأكيد', () {
      final ReportTable table = buildWasteAndDisposalReport(
        period: span,
        sacks: <SackCard>[sackOf(sequence: 1)],
        disposals: <DisposalCard>[disposalOf()],
      );
      expect(table.report, ReportId.wasteAndDisposal);
      expect(table.rows, hasLength(2));
      expect(table.rows.first.cells[1], 'سكرب');
      expect(table.rows.last.cells[1], 'إتلاف');
      // ⛔⛔ **والوزنُ الضائع صفرٌ ما لم يُؤكَّد** — `BR-M7-12` · `FR-M7-19`.
      expect(totalOf(table, 'إجمالي الوزن الضائع'), contains('0.000 كجم'));
    });

    test('★★ وبالتأكيد يظهر سطرُه بقيمته وملاحظته', () {
      final ReportTable table = buildWasteAndDisposalReport(
        period: span,
        sacks: <SackCard>[
          sackOf(sequence: 1, lostConfirmed: true, lostWeightNote: 'تبخّر'),
        ],
        disposals: const <DisposalCard>[],
      );
      expect(table.rows.first.cells[1], 'وزن ضائع');
      // ★ المطالب به = 45 − 6.5 − 1.2 = 37.300، وبلا سطورٍ فالمتبقي كلُّه.
      expect(table.rows.first.cells[4], '37.300 كجم');
      expect(table.rows.first.cells[5], 'تبخّر');
      expect(totalOf(table, 'إجمالي الوزن الضائع'), contains('37.300 كجم'));
    });

    test('★★ وسببُ الإتلاف يظهر في عمود البيان — والغيابُ شَرْطة', () {
      final ReportTable table = buildWasteAndDisposalReport(
        period: span,
        sacks: const <SackCard>[],
        disposals: <DisposalCard>[
          disposalOf(reason: 'تلف بالحرارة'),
          disposalOf(number: 'DSP-20260904-0002'),
        ],
      );
      expect(table.rows[0].cells[5], 'تلف بالحرارة');
      expect(table.rows[1].cells[5], '—');
    });
  });

  group('★★★ A-14 — الملغى يُعرَض ولا يدخل إجمالياً', () {
    test('⛔ جونيةٌ ملغاةٌ تُعرَض مشطوبةً ولا يُحتسَب سكربُها', () {
      final ReportTable table = buildWasteAndDisposalReport(
        period: span,
        sacks: <SackCard>[
          sackOf(sequence: 1, status: SackStatus.cancelled),
        ],
        disposals: const <DisposalCard>[],
      );
      expect(table.rows.single.isCancelled, isTrue);
      expect(totalOf(table, 'إجمالي السكرب'), contains('0.000 كجم'));
    });

    test('⛔ ومستندُ إتلافٍ ملغى يُعرَض ولا يُحتسَب', () {
      final ReportTable table = buildWasteAndDisposalReport(
        period: span,
        sacks: const <SackCard>[],
        disposals: <DisposalCard>[disposalOf(isCancelled: true)],
      );
      expect(table.rows.single.isCancelled, isTrue);
      expect(totalOf(table, 'عدد بنود الإتلاف'), '0');
      expect(totalOf(table, 'إجمالي المُتلَف'), contains('0 حبة'));
    });
  });

  group('★★★ GR-19 — ولا تُجمع حبّةٌ مع كيلوجرام', () {
    test('★★ إجمالي المُتلَف سطران منفصلان', () {
      final ReportTable table = buildWasteAndDisposalReport(
        period: span,
        sacks: const <SackCard>[],
        disposals: <DisposalCard>[
          disposalOf(
            lines: <DisposalCardLine>[
              const DisposalCardLine(
                itemKey: 'ITM-0001',
                itemName: 'عوارض',
                quantity: PieceQuantity(PieceCount(8)),
              ),
              const DisposalCardLine(
                itemKey: 'SCRAP',
                itemName: 'السكرب',
                quantity: WeightQuantity(WeightKg(0.75)),
              ),
            ],
          ),
        ],
      );
      final String total = totalOf(table, 'إجمالي المُتلَف')!;
      expect(total, contains('8 حبة'));
      expect(total, contains('0.750 كجم'));
      expect(totalOf(table, 'عدد بنود الإتلاف'), '2');
    });
  });

  group('★★★ فلترُ الرعوي — والإتلافُ لا رعويَّ له', () {
    test('★ يُبقي جونيةَ الرعوي وحدها', () {
      final ReportTable table = buildWasteAndDisposalReport(
        period: span,
        sacks: <SackCard>[
          sackOf(sequence: 1, supplierId: 'SUP-0001', supplierName: 'أحمد'),
          sackOf(sequence: 2, supplierId: 'SUP-0002', supplierName: 'سالم'),
        ],
        disposals: <DisposalCard>[disposalOf()],
        supplierId: 'SUP-0001',
      );
      expect(table.rows, hasLength(1));
      expect(table.rows.single.cells[3], 'أحمد');
    });

    test('⛔⛔ ويستبعد الإتلافَ كلَّه — ⛔ ولا يُنسَب لرعويٍّ بالتخمين', () {
      final ReportTable table = buildWasteAndDisposalReport(
        period: span,
        sacks: const <SackCard>[],
        disposals: <DisposalCard>[disposalOf()],
        supplierId: 'SUP-0001',
      );
      expect(table.rows, isEmpty);
      expect(totalOf(table, 'عدد بنود الإتلاف'), '0');
    });

    test('★ واسمُ الرعوي في الترويسة من الخريطة لا من المعرّف', () {
      final ReportTable table = buildWasteAndDisposalReport(
        period: span,
        sacks: const <SackCard>[],
        disposals: const <DisposalCard>[],
        supplierId: 'SUP-0001',
        supplierNames: const <String, String>{'SUP-0001': 'أحمد'},
      );
      expect(
        table.header
            .firstWhere((ExportField field) => field.label == 'الرعوي')
            .value,
        'أحمد',
      );
    });
  });
}

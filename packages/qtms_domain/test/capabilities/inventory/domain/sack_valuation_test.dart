@TestOn('vm')
library;

import 'package:qtms_domain/qtms_domain.dart';
import 'package:test/test.dart';

/// ★ مساهمةٌ معدودة مسعَّرة — **الحالة الغالبة** (توزيعٌ بحبّات).
SackRevenueContribution _counted({
  String itemKey = 'بطوة - رعوي - جونية رقم 1',
  SackRevenueSource origin = SackRevenueSource.distribution,
  String documentNumber = 'DST-20260903-0001',
  int quantity = 10,
  int? unitPrice = 500,
  int? lineValue = 5000,
  bool isCancelled = false,
  bool isExcluded = false,
}) =>
    SackRevenueContribution(
      itemKey: itemKey,
      itemName: itemKey,
      origin: origin,
      documentNumber: documentNumber,
      quantity: PieceQuantity(PieceCount(quantity)),
      unitPrice: unitPrice == null ? null : Money(unitPrice),
      lineValue: lineValue == null ? null : Money(lineValue),
      isCancelled: isCancelled,
      isExcluded: isExcluded,
    );

/// ★ مساهمةٌ وزنية — **السكرب** (`ت-09`): قيمتُها وصلت مقرَّبةً من الموضع ③.
SackRevenueContribution _weighted({
  double kilograms = 0.5,
  int? lineValue = 125,
  SackRevenueSource origin = SackRevenueSource.cashSale,
  String documentNumber = 'CSH-20260903-0001',
}) =>
    SackRevenueContribution(
      itemKey: 'السكرب - رعوي - جونية رقم 1',
      itemName: 'السكرب',
      origin: origin,
      documentNumber: documentNumber,
      quantity: WeightQuantity(WeightKg(kilograms)),
      unitPrice: const Money(250),
      lineValue: lineValue == null ? null : Money(lineValue),
    );

void main() {
  group('BR-M14-01: سعر الجونية = الإيراد الفعلي لا الافتراضي', () {
    test('يجمع التوزيع والبيع النقدي والسحبية والخرجية معاً', () {
      final SackRevenue revenue = computeSackRevenue(<SackRevenueContribution>[
        _counted(lineValue: 5000),
        _counted(
          origin: SackRevenueSource.cashSale,
          documentNumber: 'CSH-20260903-0001',
          lineValue: 2450,
        ),
        _counted(
          origin: SackRevenueSource.withdrawal,
          documentNumber: 'WDR-20260903-0001',
          lineValue: 700,
        ),
        _counted(
          origin: SackRevenueSource.expense,
          documentNumber: 'EXP-20260903-0001',
          lineValue: 300,
        ),
      ]);

      expect(revenue.total, const Money(8450));
      expect(revenue.countedCount, 4);
      expect(revenue.isFinal, isTrue);
    });

    test('ت-09: إيراد السكرب يدخل السعر كأي نوع آخر', () {
      final SackRevenue revenue = computeSackRevenue(<SackRevenueContribution>[
        _weighted(lineValue: 2000, origin: SackRevenueSource.distribution),
        _weighted(lineValue: 2450),
      ]);

      expect(revenue.total, const Money(4450));
      expect(revenue.isFinal, isTrue);
    });

    test('جونيةٌ لم يخرج منها شيء = صفرٌ نهائي لا «غير نهائي»', () {
      final SackRevenue revenue =
          computeSackRevenue(const <SackRevenueContribution>[]);

      expect(revenue.total, Money.zero);
      expect(revenue.countedCount, 0);
      expect(revenue.isFinal, isTrue);
      expect(revenue.total, SackRevenue.none.total);
    });

    test('A-14: الحركة الملغاة لا تدخل الجمع ولا العدّ', () {
      final SackRevenue revenue = computeSackRevenue(<SackRevenueContribution>[
        _counted(lineValue: 5000),
        _counted(documentNumber: 'DST-20260903-0002', lineValue: 9999,
            isCancelled: true),
      ]);

      expect(revenue.total, const Money(5000));
      expect(revenue.countedCount, 1);
    });

    test('FR-M14-08 · A-15: الإتلاف والوزن الضائع لا يُضيفان شيئاً', () {
      final SackRevenue revenue = computeSackRevenue(<SackRevenueContribution>[
        _counted(lineValue: 5000),
        _counted(documentNumber: 'DSP-1', lineValue: 4000, isExcluded: true),
      ]);

      expect(revenue.total, const Money(5000));
      expect(revenue.countedCount, 1);
    });

    test('FR-M14-10 · AT-66: تسوية الجرد مستبعَدة كذلك', () {
      final SackRevenue revenue = computeSackRevenue(<SackRevenueContribution>[
        _counted(documentNumber: 'STK-1', lineValue: 1200, isExcluded: true),
      ]);

      expect(revenue.total, Money.zero);
      expect(revenue.countedCount, 0);
    });

    test('الملغاة والمستبعَدة معاً لا تُعدّ مرتين', () {
      final SackRevenueContribution both =
          _counted(lineValue: 1000, isCancelled: true, isExcluded: true);

      expect(both.isCountable, isFalse);
      expect(computeSackRevenue(<SackRevenueContribution>[both]).countedCount, 0);
    });
  });

  group('FR-M14-06 · E-27: «⏳ سعر غير نهائي»', () {
    test('حركةٌ بلا قيمة مسجَّلة تُبقي السعر غير نهائي ولا تُجمَع صفراً', () {
      final SackRevenue revenue = computeSackRevenue(<SackRevenueContribution>[
        _counted(lineValue: 5000),
        _counted(
          documentNumber: 'WDR-20260903-0001',
          origin: SackRevenueSource.withdrawal,
          unitPrice: null,
          lineValue: null,
        ),
      ]);

      expect(revenue.total, const Money(5000));
      expect(revenue.unpricedCount, 1);
      expect(revenue.countedCount, 2);
      expect(revenue.isFinal, isFalse);
    });

    test('حركةٌ ملغاةٌ بلا سعر لا تجعل السعر غير نهائي', () {
      final SackRevenue revenue = computeSackRevenue(<SackRevenueContribution>[
        _counted(lineValue: 5000),
        _counted(lineValue: null, isCancelled: true),
      ]);

      expect(revenue.unpricedCount, 0);
      expect(revenue.isFinal, isTrue);
    });

    test('isPriced يفرّق بين «داخلة ومسعَّرة» و«داخلة بلا سعر»', () {
      expect(_counted().isPriced, isTrue);
      expect(_counted(lineValue: null).isPriced, isFalse);
      expect(_counted(isCancelled: true).isPriced, isFalse);
    });
  });

  group('FR-M14-04 · A-11: الصافي = السعر − الضريبة', () {
    test('طرحُ عددين صحيحين بلا تقريب ثانٍ', () {
      expect(
        computeSupplierNet(
          sackRevenue: const Money(37300),
          sackTax: const Money(1125),
        ),
        const Money(36175),
      );
    });

    test('AT-13: 25 × 45.000 = 1,125 — والصافي يُبنى عليها كما هي', () {
      final Money tax = sackTax(
        taxPerKilo: const Money(25),
        totalWeight: const WeightKg(45),
      );

      expect(tax, const Money(1125));
      expect(
        computeSupplierNet(sackRevenue: const Money(1125), sackTax: tax),
        Money.zero,
      );
    });

    test('السالب حالةٌ واقعية لا خطأ — جونيةٌ لم تُصرَف بعد', () {
      expect(
        computeSupplierNet(
          sackRevenue: Money.zero,
          sackTax: const Money(1125),
        ),
        const Money(-1125),
      );
    });
  });

  group('الموضع ② للتقريب: متوسط سعر الكيلو المتحقق', () {
    test('يُقرَّب لأقرب ريال — 1,215.067 ⟵ 1,215', () {
      expect(
        computeAverageKiloPrice(
          sackRevenue: const Money(45565),
          claimableWeight: const WeightKg(37.5),
        ),
        const Money(1215),
      );
    });

    test('النصف لأعلى — ADR-0015 القاعدة 5', () {
      expect(
        computeAverageKiloPrice(
          sackRevenue: const Money(1235),
          claimableWeight: const WeightKg(2),
        ),
        const Money(618),
      );
      expect(
        computeAverageKiloPrice(
          sackRevenue: const Money(1234),
          claimableWeight: const WeightKg(2),
        ),
        const Money(617),
      );
    });

    test('وزنٌ مطالبٌ به غير موجب ⟵ null لا صفر', () {
      expect(
        computeAverageKiloPrice(
          sackRevenue: const Money(5000),
          claimableWeight: WeightKg.zero,
        ),
        isNull,
      );
    });

    test('سعرٌ سالبٌ لا يمرّ بالتقريب — ADR-0015 القاعدة 8', () {
      expect(
        computeAverageKiloPrice(
          sackRevenue: const Money(-10),
          claimableWeight: const WeightKg(1),
        ),
        isNull,
      );
    });
  });

  group('design-overview §2.5: حساب الرعوي في مصدر', () {
    test('الإجماليات الثلاثة تُبنى من سطور المصدر الواحد', () {
      final SupplierSourceTotals totals =
          computeSupplierSourceTotals(const <SupplierSackRow>[
        SupplierSackRow(
          sackId: 'SCK-20260903-0001',
          sackRevenue: Money(37300),
          sackTax: Money(1125),
        ),
        SupplierSackRow(
          sackId: 'SCK-20260903-0002',
          sackRevenue: Money(20000),
          sackTax: Money(500),
        ),
      ]);

      expect(totals.totalRevenue, const Money(57300));
      expect(totals.totalTax, const Money(1625));
      expect(totals.net, const Money(55675));
      expect(totals.sackCount, 2);
      expect(totals.isFinal, isTrue);
    });

    test('FR-M7-10: ضريبةٌ معلّقة لا تُجمَع صفراً وتُبقي الحساب غير نهائي', () {
      final SupplierSourceTotals totals =
          computeSupplierSourceTotals(const <SupplierSackRow>[
        SupplierSackRow(
          sackId: 'SCK-20260903-0001',
          sackRevenue: Money(37300),
          sackTax: Money(1125),
        ),
        SupplierSackRow(sackId: 'SCK-20260903-0002', sackRevenue: Money(20000)),
      ]);

      expect(totals.totalTax, const Money(1125));
      expect(totals.pendingTaxCount, 1);
      expect(totals.isFinal, isFalse);
    });

    test('سعرٌ غير نهائي يُبقي الحساب غير نهائي ولو اكتملت الضرائب', () {
      final SupplierSourceTotals totals =
          computeSupplierSourceTotals(const <SupplierSackRow>[
        SupplierSackRow(
          sackId: 'SCK-20260903-0001',
          sackRevenue: Money(37300),
          sackTax: Money(1125),
          isRevenueFinal: false,
        ),
      ]);

      expect(totals.pendingTaxCount, 0);
      expect(totals.unfinalRevenueCount, 1);
      expect(totals.isFinal, isFalse);
    });

    test('حسابٌ بلا جواني = أصفارٌ نهائية', () {
      final SupplierSourceTotals totals =
          computeSupplierSourceTotals(const <SupplierSackRow>[]);

      expect(totals.totalRevenue, Money.zero);
      expect(totals.net, Money.zero);
      expect(totals.sackCount, 0);
      expect(totals.isFinal, isTrue);
    });
  });

  group('المعرّفات — naming-conventions §4', () {
    test('رصيد الرعوي {supplierId}_{sourceId} بترتيبٍ ثابت', () {
      expect(
        supplierBalanceId(supplierId: 'SUP-0001', sourceId: 'SRC-001'),
        'SUP-0001_SRC-001',
      );
    });

    test('ويرفض الفراغ في أيٍّ من جزأيه', () {
      expect(
        () => supplierBalanceId(supplierId: '', sourceId: 'SRC-001'),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => supplierBalanceId(supplierId: 'SUP-0001', sourceId: ''),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('سطرُ دفتر الرعية معرّفُه رقمُ الجونية نفسُه — سطرٌ واحدٌ لكل جونية',
        () {
      expect(
        supplierLedgerEntryId(sackId: 'SCK-20260903-0001'),
        'SCK-20260903-0001',
      );
      expect(
        () => supplierLedgerEntryId(sackId: ''),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('أسماء المجموعتين كما في data-dictionary §3 و§4', () {
      expect(supplierLedgerCollection, 'supplier_ledger');
      expect(supplierBalancesCollection, 'supplier_balances');
    });
  });

  group('AT-47: رعويٌّ في مصدرين ⟵ حسابان منفصلان تماماً', () {
    test('لا دالة تجمع سطور مصدرين — والإجماليات تُبنى لكل مصدر وحده', () {
      final SupplierSourceTotals first =
          computeSupplierSourceTotals(const <SupplierSackRow>[
        SupplierSackRow(
          sackId: 'SCK-A',
          sackRevenue: Money(10000),
          sackTax: Money(300),
        ),
      ]);
      final SupplierSourceTotals second =
          computeSupplierSourceTotals(const <SupplierSackRow>[
        SupplierSackRow(
          sackId: 'SCK-B',
          sackRevenue: Money(4000),
          sackTax: Money(100),
        ),
      ]);

      expect(first.net, const Money(9700));
      expect(second.net, const Money(3900));
      // ★ **والجمع عرضٌ يبنيه المُستدعي** — ⛔ **ولا حساب موحّد** (`GR-21`).
      expect(first.net + second.net, const Money(13600));
    });
  });

  group('SupplierLedgerRow — العقد المقروء', () {
    test('يتحوّل إلى سطر معادلة §2.5 بلا فقد حقل', () {
      const SupplierLedgerRow row = SupplierLedgerRow(
        sackId: 'SCK-20260903-0001',
        supplierId: 'SUP-0001',
        sourceId: 'SRC-001',
        sackRevenue: Money(37300),
        recalcVersion: 4,
        sackTax: Money(1125),
        supplierNet: Money(36175),
        isRevenueFinal: false,
      );

      final SupplierSackRow totalsRow = row.asTotalsRow;
      expect(totalsRow.sackId, 'SCK-20260903-0001');
      expect(totalsRow.sackRevenue, const Money(37300));
      expect(totalsRow.sackTax, const Money(1125));
      expect(totalsRow.isRevenueFinal, isFalse);
    });
  });

  group('sack-valuation-design §2 ①: مساهماتُ جونيةٍ بعينها', () {
    SackMovementDocument doc({
      String number = 'DST-20260903-0001',
      SackRevenueSource origin = SackRevenueSource.distribution,
      bool cancelled = false,
      bool excluded = false,
      List<SackMovementLine> lines = const <SackMovementLine>[],
    }) =>
        SackMovementDocument(
          documentNumber: number,
          origin: origin,
          isCancelled: cancelled,
          isExcluded: excluded,
          counterpartyName: 'المقوت الأول',
          lines: lines,
        );

    SackMovementLine line({String? sackId, int? value = 5000}) =>
        SackMovementLine(
          itemKey: 'بطوة - رعوي - جونية رقم 1',
          itemName: 'بطوة',
          quantity: const PieceQuantity(PieceCount(10)),
          sackId: sackId,
          unitPrice: const Money(500),
          lineValue: value == null ? null : Money(value),
        );

    test('الانتماء بـsackId وحده — وسطرٌ بلا مرجعٍ لا يدخل', () {
      final List<SackRevenueContribution> found = contributionsForSack(
        sackId: 'SCK-20260903-0001',
        documents: <SackMovementDocument>[
          doc(lines: <SackMovementLine>[
            line(sackId: 'SCK-20260903-0001'),
            line(sackId: 'SCK-20260903-0002'),
            line(),
          ]),
        ],
      );

      expect(found, hasLength(1));
      expect(found.single.documentNumber, 'DST-20260903-0001');
      expect(found.single.counterpartyName, 'المقوت الأول');
    });

    test('الملغى يمرّ موسوماً لا مطروحاً — والتفكيك يعرضه', () {
      final List<SackRevenueContribution> found = contributionsForSack(
        sackId: 'SCK-20260903-0001',
        documents: <SackMovementDocument>[
          doc(cancelled: true, lines: <SackMovementLine>[
            line(sackId: 'SCK-20260903-0001'),
          ]),
        ],
      );

      expect(found, hasLength(1));
      expect(found.single.isCancelled, isTrue);
      expect(computeSackRevenue(found).total, Money.zero);
    });

    test('AT-54 · AT-66: المستبعَد يمرّ موسوماً ولا يدخل الجمع', () {
      final List<SackRevenueContribution> found = contributionsForSack(
        sackId: 'SCK-20260903-0001',
        documents: <SackMovementDocument>[
          doc(number: 'STK-20260903-001', excluded: true,
              lines: <SackMovementLine>[line(sackId: 'SCK-20260903-0001')]),
        ],
      );

      expect(found.single.isExcluded, isTrue);
      expect(computeSackRevenue(found).countedCount, 0);
    });

    test('يجمع من المستندات الأربعة بترتيب ورودها', () {
      final List<SackRevenueContribution> found = contributionsForSack(
        sackId: 'SCK-20260903-0001',
        documents: <SackMovementDocument>[
          doc(lines: <SackMovementLine>[line(sackId: 'SCK-20260903-0001')]),
          doc(
            number: 'CSH-20260903-0001',
            origin: SackRevenueSource.cashSale,
            lines: <SackMovementLine>[
              line(sackId: 'SCK-20260903-0001', value: 2450),
            ],
          ),
          doc(
            number: 'WDR-20260903-0001',
            origin: SackRevenueSource.withdrawal,
            lines: <SackMovementLine>[
              line(sackId: 'SCK-20260903-0001', value: null),
            ],
          ),
          doc(
            number: 'EXP-20260903-0001',
            origin: SackRevenueSource.expense,
            lines: <SackMovementLine>[
              line(sackId: 'SCK-20260903-0001', value: 300),
            ],
          ),
        ],
      );

      expect(found, hasLength(4));
      expect(
        found.map((SackRevenueContribution c) => c.origin),
        <SackRevenueSource>[
          SackRevenueSource.distribution,
          SackRevenueSource.cashSale,
          SackRevenueSource.withdrawal,
          SackRevenueSource.expense,
        ],
      );

      final SackRevenue revenue = computeSackRevenue(found);
      expect(revenue.total, const Money(7750));
      expect(revenue.isFinal, isFalse);
    });

    test('جونيةٌ بلا مستندات = صفرٌ نهائي', () {
      expect(
        contributionsForSack(
          sackId: 'SCK-20260903-0009',
          documents: const <SackMovementDocument>[],
        ),
        isEmpty,
      );
    });
  });
}

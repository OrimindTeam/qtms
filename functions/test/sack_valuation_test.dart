/// اختبار **التخطيط الخالص** لمُحتسِب مالية الجواني (`WU-015` · `M14`).
///
/// ★ **بلا شبكة ولا سحابة** — ⟵ **فكل قرارٍ هنا دالةٌ خالصة**، ★ **وطبقةُ
/// الشبكة لها اختبارُها المستقل** (`sack_valuation_handler_test.dart`).
library;

import 'package:qtms_domain/qtms_domain.dart';
import 'package:qtms_functions/src/inventory.dart' show InventoryWrite;
import 'package:qtms_functions/src/sack_valuation.dart';
import 'package:test/test.dart';

const String sourceA = 'SRC-001';
const String supplierA = 'SUP-0001';
const String sackA = 'SCK-20260903-0001';

SackValuationState _sack({
  String sackId = sackA,
  String? supplierId = supplierA,
  int? tax = 1125,
  int? storedRevenue,
  int? storedNet,
  bool? storedFinal,
  int storedVersion = 0,
  bool isCancelled = false,
}) =>
    SackValuationState(
      sackId: sackId,
      sourceId: sourceA,
      displayName: 'الرعوي الأول - جونية رقم 1',
      supplierId: supplierId,
      supplierName: 'الرعوي الأول',
      isCancelled: isCancelled,
      sackTax: tax == null ? null : Money(tax),
      storedRevenue: storedRevenue == null ? null : Money(storedRevenue),
      storedNet: storedNet == null ? null : Money(storedNet),
      storedRevenueFinal: storedFinal,
      storedRecalcVersion: storedVersion,
    );

SackMovementDocument _distribution({
  String number = 'DST-20260903-0001',
  String? sackId = sackA,
  int? lineValue = 37300,
  bool isCancelled = false,
}) =>
    SackMovementDocument(
      documentNumber: number,
      origin: SackRevenueSource.distribution,
      isCancelled: isCancelled,
      counterpartyName: 'المقوت الأول',
      lines: <SackMovementLine>[
        SackMovementLine(
          itemKey: 'بطوة - الرعوي الأول - جونية رقم 1',
          itemName: 'بطوة',
          quantity: const PieceQuantity(PieceCount(100)),
          sackId: sackId,
          unitPrice: const Money(373),
          lineValue: lineValue == null ? null : Money(lineValue),
        ),
      ],
    );

InventoryWrite _writeIn(SackValuationPlan plan, String collectionId) =>
    plan.writes.firstWhere(
      (InventoryWrite write) => write.collectionId.contains(collectionId),
    );

void main() {
  group('FR-M14-05: إعادة الاحتساب تكتب المالية وسطر دفتر الرعية معاً', () {
    test('كتابتان لجونيةٍ واحدة — ماليتُها وسطرُها', () {
      final SackValuationPlan plan = planSackValuation(
        sacks: <SackValuationState>[_sack()],
        documents: <SackMovementDocument>[_distribution()],
      );

      expect(plan.writes, hasLength(2));
      expect(plan.touchedSupplierIds, <String>{supplierA});

      final InventoryWrite finance = _writeIn(plan, sackFinanceSubcollection);
      expect(finance.documentId, sackFinanceDocumentId);
      expect(finance.fields['sackRevenue'], 37300);
      expect(finance.fields['supplierNet'], 36175);
      expect(finance.fields['isRevenueFinal'], isTrue);
      expect(finance.serverTimestampFields, <String>['lastRevaluedAt']);
    });

    test('ADR-0011: المالية في finance/current — ⛔ ولا حقل مالي في الأب', () {
      final SackValuationPlan plan = planSackValuation(
        sacks: <SackValuationState>[_sack()],
        documents: <SackMovementDocument>[_distribution()],
      );

      for (final InventoryWrite write in plan.writes) {
        expect(write.collectionId, isNot(sacksCollection));
      }
      expect(
        _writeIn(plan, sackFinanceSubcollection).collectionId,
        '$sacksCollection/$sackA/$sackFinanceSubcollection',
      );
    });

    test('قناعُ المالية لا يذكر الضريبة — ⛔ فلا يمحو ما أدخله enterSackTax',
        () {
      final InventoryWrite finance = _writeIn(
        planSackValuation(
          sacks: <SackValuationState>[_sack()],
          documents: <SackMovementDocument>[_distribution()],
        ),
        sackFinanceSubcollection,
      );

      expect(finance.updateMask, isNot(contains('sackTax')));
      expect(finance.updateMask, isNot(contains('taxPerKilo')));
      expect(finance.updateMask, contains('sackRevenue'));
      expect(finance.updateMask, contains('supplierNet'));
    });

    test('سطرُ الدفتر يحمل المصدر والرعوي والصافي ورقم الاحتساب', () {
      final InventoryWrite ledger = _writeIn(
        planSackValuation(
          sacks: <SackValuationState>[_sack()],
          documents: <SackMovementDocument>[_distribution()],
        ),
        supplierLedgerCollection,
      );

      expect(ledger.documentId, sackA);
      expect(ledger.fields['sourceId'], sourceA);
      expect(ledger.fields['supplierId'], supplierA);
      expect(ledger.fields['sackRevenue'], 37300);
      expect(ledger.fields['sackTax'], 1125);
      expect(ledger.fields['supplierNet'], 36175);
      expect(ledger.fields[recalcVersionField], 1);
      expect(ledger.serverTimestampFields, <String>['entryDate']);
    });

    test('وتاريخُ القيد لا يُعاد كتابته — lastAmendedAt بعد أول احتساب', () {
      final InventoryWrite ledger = _writeIn(
        planSackValuation(
          sacks: <SackValuationState>[
            _sack(storedRevenue: 1000, storedNet: -125, storedFinal: true,
                storedVersion: 3),
          ],
          documents: <SackMovementDocument>[_distribution()],
        ),
        supplierLedgerCollection,
      );

      expect(ledger.fields[recalcVersionField], 4);
      expect(ledger.serverTimestampFields, <String>['lastAmendedAt']);
    });
  });

  group('api-overview §3.3: قابلٌ للتكرار بلا أثر جانبي', () {
    test('⛔ لا كتابة إن لم يتغيّر شيء — ولا يتضخّم recalcVersion', () {
      final SackValuationPlan plan = planSackValuation(
        sacks: <SackValuationState>[
          _sack(
            storedRevenue: 37300,
            storedNet: 36175,
            storedFinal: true,
            storedVersion: 7,
          ),
        ],
        documents: <SackMovementDocument>[_distribution()],
      );

      expect(plan.isEmpty, isTrue);
      expect(plan.writes, isEmpty);
      expect(plan.touchedSupplierIds, isEmpty);
      expect(plan.results.single.changed, isFalse);
      expect(plan.results.single.revenue.total, const Money(37300));
    });

    test('وأولُ احتسابٍ يُكتب دائماً ولو طابق المخزَّن صفراً', () {
      final SackValuationPlan plan = planSackValuation(
        sacks: <SackValuationState>[_sack(tax: null)],
        documents: const <SackMovementDocument>[],
      );

      expect(plan.writes, hasLength(2));
      expect(plan.results.single.revenue.total, Money.zero);
    });

    test('ونفسُ المُدخَل يُنتج نفس الخطة حرفياً', () {
      Map<String, Object?> fieldsOf(SackValuationPlan plan) =>
          <String, Object?>{
            for (final InventoryWrite write in plan.writes)
              '${write.collectionId}/${write.documentId}': write.fields,
          };

      final SackValuationPlan first = planSackValuation(
        sacks: <SackValuationState>[_sack()],
        documents: <SackMovementDocument>[_distribution()],
      );
      final SackValuationPlan second = planSackValuation(
        sacks: <SackValuationState>[_sack()],
        documents: <SackMovementDocument>[_distribution()],
      );

      expect(fieldsOf(first).toString(), fieldsOf(second).toString());
    });
  });

  group('FR-M7-10: الضريبة المعلّقة', () {
    test('⛔ الصافي null لا صفراً — والحقل مذكورٌ في القناع', () {
      final SackValuationPlan plan = planSackValuation(
        sacks: <SackValuationState>[_sack(tax: null)],
        documents: <SackMovementDocument>[_distribution()],
      );

      final InventoryWrite finance = _writeIn(plan, sackFinanceSubcollection);
      expect(finance.fields['sackRevenue'], 37300);
      expect(finance.fields['supplierNet'], isNull);
      expect(finance.updateMask, contains('supplierNet'));

      final InventoryWrite ledger = _writeIn(plan, supplierLedgerCollection);
      expect(ledger.fields['sackTax'], isNull);
      expect(ledger.fields['supplierNet'], isNull);
      expect(plan.results.single.supplierNet, isNull);
    });
  });

  group('FR-M14-06: وسم «⏳ سعر غير نهائي»', () {
    test('حركةٌ بلا قيمةٍ تُسقِط الوسم في المالية وفي الدفتر معاً', () {
      final SackValuationPlan plan = planSackValuation(
        sacks: <SackValuationState>[_sack()],
        documents: <SackMovementDocument>[
          _distribution(),
          _distribution(number: 'DST-20260903-0002', lineValue: null),
        ],
      );

      expect(_writeIn(plan, sackFinanceSubcollection)
          .fields['isRevenueFinal'], isFalse);
      expect(
        _writeIn(plan, supplierLedgerCollection).fields['isRevenueFinal'],
        isFalse,
      );
      expect(plan.results.single.revenue.unpricedCount, 1);
    });
  });

  group('FR-M7-03: جونيةٌ في مصدرٍ لا يشترط الرعوي', () {
    test('⛔ لا سطرَ دفترٍ لها — وماليتُها تُكتب كما هي', () {
      final SackValuationPlan plan = planSackValuation(
        sacks: <SackValuationState>[_sack(supplierId: null)],
        documents: <SackMovementDocument>[_distribution()],
      );

      expect(plan.writes, hasLength(1));
      expect(plan.writes.single.collectionId, contains(sackFinanceSubcollection));
      expect(plan.touchedSupplierIds, isEmpty);
    });
  });

  group('GR-06 · GR-07: الجونية الملغاة', () {
    test('تبقى سطراً موسوماً — ⛔ ولا تُحذَف', () {
      final InventoryWrite ledger = _writeIn(
        planSackValuation(
          sacks: <SackValuationState>[_sack(isCancelled: true)],
          documents: <SackMovementDocument>[_distribution(isCancelled: true)],
        ),
        supplierLedgerCollection,
      );

      expect(ledger.fields['isCancelled'], isTrue);
      expect(ledger.fields['sackRevenue'], 0);
    });
  });

  group('التجميع — sack-valuation-design §6 القاعدة 1', () {
    test('دفعةٌ من ثلاث جوانٍ تُحتسب من قراءةِ مستنداتٍ واحدة', () {
      const String sackB = 'SCK-20260903-0002';
      const String sackC = 'SCK-20260903-0003';
      final SackValuationPlan plan = planSackValuation(
        sacks: <SackValuationState>[
          _sack(),
          _sack(sackId: sackB, tax: 500),
          _sack(sackId: sackC, tax: null),
        ],
        documents: <SackMovementDocument>[
          _distribution(),
          _distribution(number: 'DST-20260903-0002', sackId: sackB,
              lineValue: 20000),
        ],
      );

      expect(plan.results, hasLength(3));
      expect(plan.results[0].revenue.total, const Money(37300));
      expect(plan.results[1].revenue.total, const Money(20000));
      // ★ **جونيةٌ لم يخرج منها شيء = صفرٌ نهائي** — ⛔ **لا غياب**.
      expect(plan.results[2].revenue.total, Money.zero);
      expect(plan.results[2].revenue.isFinal, isTrue);
      expect(plan.writes, hasLength(6));
    });
  });

  group('design-overview §2.5: رصيد الرعوي في مصدر', () {
    test('يُبنى من كل سطور الدفتر — ⛔ ولا يُراكِم', () {
      final InventoryWrite balance = planSupplierBalance(
        supplierId: supplierA,
        sourceId: sourceA,
        rows: const <SupplierSackRow>[
          SupplierSackRow(
            sackId: sackA,
            sackRevenue: Money(37300),
            sackTax: Money(1125),
          ),
          SupplierSackRow(
            sackId: 'SCK-20260902-0001',
            sackRevenue: Money(20000),
            sackTax: Money(500),
          ),
        ],
      );

      expect(
        balance.documentId,
        supplierBalanceId(supplierId: supplierA, sourceId: sourceA),
      );
      expect(balance.fields['totalSackRevenue'], 57300);
      expect(balance.fields['totalSackTax'], 1625);
      expect(balance.fields['supplierNet'], 55675);
      expect(balance.fields['sackCount'], 2);
      expect(balance.fields['pendingTaxCount'], 0);
      expect(balance.serverTimestampFields, <String>['updatedAt']);
    });

    test('IQ-024 · DEBT-40: sourceId حقلٌ صريحٌ في المستند', () {
      final InventoryWrite balance = planSupplierBalance(
        supplierId: supplierA,
        sourceId: sourceA,
        rows: const <SupplierSackRow>[],
      );

      expect(balance.fields['sourceId'], sourceA);
      expect(balance.updateMask, contains('sourceId'));
      expect(balance.fields['totalSackRevenue'], 0);
      expect(balance.fields['supplierNet'], 0);
    });

    test('وعدّادان يقولان لماذا الرقم غير نهائي', () {
      final InventoryWrite balance = planSupplierBalance(
        supplierId: supplierA,
        sourceId: sourceA,
        rows: const <SupplierSackRow>[
          SupplierSackRow(sackId: sackA, sackRevenue: Money(37300)),
          SupplierSackRow(
            sackId: 'SCK-B',
            sackRevenue: Money(1000),
            sackTax: Money(10),
            isRevenueFinal: false,
          ),
        ],
      );

      expect(balance.fields['pendingTaxCount'], 1);
      expect(balance.fields['unfinalRevenueCount'], 1);
      expect(balance.fields['totalSackTax'], 10);
    });
  });
}

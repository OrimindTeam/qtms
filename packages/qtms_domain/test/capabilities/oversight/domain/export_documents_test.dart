/// المستند المُصدَّر — ★★ **يطابق الرسالة رقماً برقم** (معيار قبول `WU-010`).
///
/// ⚠️⚠️ **وهذا بالضبط ما يقيسه هذا الملف:** ★ **كل رقمٍ في المستند يُقابَل
/// بنظيره في نصّ الرسالة** — ⟵ **فلو بنى أحدُهما أرقامَه بنفسه لسقط
/// الاختبار**، ⛔ **لا لظهور فرقٍ في مراجعةٍ بصرية.**
library;

import 'package:qtms_domain/qtms_domain.dart';
import 'package:test/test.dart';

const MessageBusiness _business = MessageBusiness(
  businessName: 'وكالة محمد المحامي',
  thousandsSeparator: ',',
);

DistributionMessageData _distribution({bool priced = true}) =>
    DistributionMessageData(
      dealerName: 'أحمد صالح',
      stockDate: CalendarDay(2026, 8, 30),
      lines: <MessageLine>[
        MessageLine(
          itemName: 'شامي',
          quantity: const PieceQuantity(PieceCount(60)),
          unitPrice: priced ? const Money(1500) : null,
          lineTotal: priced ? const Money(90000) : null,
        ),
        MessageLine(
          itemName: 'سكرب',
          quantity: const WeightQuantity(WeightKg(0.5)),
          unitPrice: priced ? const Money(4000) : null,
          lineTotal: priced ? const Money(2000) : null,
        ),
      ],
      debtValue: const Money(92000),
      previousBalance: const Money(8000),
      currentBalance: const Money(100000),
    );

void main() {
  group('★★★ المستند يطابق الرسالة رقماً برقم — معيار قبول `WU-010`', () {
    test('★ القالب ② — كل قيمةٍ في الجدول موجودةٌ في النصّ', () {
      final ExportableDocument document = buildDistributionExport(
        business: _business,
        data: _distribution(),
        sourceId: 'SRC-001',
        sourceName: 'مصدر صنعاء',
        entityId: 'MQT-0001_SRC-001_20260830',
        withPricing: true,
      );
      final String message = renderDistributionMessage(
        business: _business,
        data: _distribution(),
        template: MessageTemplate.distributionWithPricing,
      );

      for (final ExportRow row in document.rows) {
        for (final String cell in row.cells) {
          expect(message, contains(cell), reason: cell);
        }
      }
      for (final ExportField total in document.totals) {
        expect(message, contains(total.value), reason: total.label);
      }
    });

    test('★ والقالب ① كذلك — بعمودين لا أربعة', () {
      final ExportableDocument document = buildDistributionExport(
        business: _business,
        data: _distribution(),
        sourceId: 'SRC-001',
        sourceName: 'مصدر صنعاء',
        entityId: 'MQT-0001_SRC-001_20260830',
        withPricing: false,
      );
      final String message = renderDistributionMessage(
        business: _business,
        data: _distribution(),
        template: MessageTemplate.distributionOnly,
      );

      expect(document.columns, <String>['النوع', 'الكمية']);
      for (final ExportRow row in document.rows) {
        for (final String cell in row.cells) {
          expect(message, contains(cell));
        }
      }
      // ⛔⛔ **ولا سعرَ يتسرّب إلى ملف القالب ①** (`ت-12`).
      expect(document.totals.map((ExportField f) => f.label), <String>['الإجمالي']);
    });

    test('⛔⛔ والسطر غير المسعَّر «غير مسعَّر» في الملف كما في الرسالة', () {
      final ExportableDocument document = buildDistributionExport(
        business: _business,
        data: _distribution(priced: false),
        sourceId: 'SRC-001',
        sourceName: 'مصدر صنعاء',
        entityId: 'X',
        withPricing: true,
      );
      expect(document.rows.first.cells, contains('غير مسعَّر'));
      expect(document.rows.first.cells, isNot(contains('0')));
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  // ★★★ **نطاق `CR-004` المُعتمَد — والحدُّ نفسُه هو محلُّ الاختبار:**
  // ★ **يُحذَف اسمُ المصدر من ترويسة الرسالة وحدها** (يحرسه
  //   `message_templates_test.dart`)، ⛔ **ولا يُحذَف من المستند المُصدَّر**
  //   — ⟵ **فالتصدير دليلٌ يُحفَظ ويُراجَع، والحسابات مفصولةٌ بالمصدر**
  //   (`ADR-0005`). ★ **وهذان الاختباران طرفا الحدّ معاً** ⛔ **فلا يُقرأ
  //   القرارُ توسيعاً ولا تضييقاً.**
  // ═════════════════════════════════════════════════════════════════════
  group('★★★ `CR-004` — والمصدر باقٍ في ترويسة المستند المُصدَّر', () {
    test('★ في القالبين ① و② معاً', () {
      for (final bool priced in <bool>[false, true]) {
        final ExportableDocument document = buildDistributionExport(
          business: _business,
          data: _distribution(),
          sourceId: 'SRC-001',
          sourceName: 'مصدر صنعاء',
          entityId: 'X',
          withPricing: priced,
        );
        expect(
          document.header.map((ExportField f) => f.label),
          containsAll(<String>['المصدر', 'تاريخ المخزون']),
        );
        expect(
          document.header
              .firstWhere((ExportField f) => f.label == 'المصدر')
              .value,
          'مصدر صنعاء',
        );
      }
    });

    test('⛔ والرسالةُ نفسُها بلا اسم المصدر — الطرف الآخر للحدّ', () {
      final String message = renderDistributionMessage(
        business: _business,
        data: _distribution(),
        template: MessageTemplate.distributionWithPricing,
      );
      expect(message, isNot(contains('مصدر صنعاء')));
      expect(message, isNot(contains('المصدر:')));
    });

    test('★ وسندُ القبض يحمله كذلك', () {
      final ExportableDocument document = buildReceiptExport(
        business: _business,
        data: buildReceiptMessageData(
          dealerName: 'أحمد صالح',
          documentNumber: 'RCP-20260830-0007',
          paidOn: CalendarDay(2026, 8, 30),
          settled: <ReceiptSettlementInput>[],
          openRemainingBefore: Money.zero,
        ),
        sourceId: 'SRC-001',
        sourceName: 'كل المصادر',
      );
      expect(
        document.header.first.label,
        'المصدر',
      );
      expect(document.header.first.value, 'كل المصادر');
    });
  });

  group('★ حقول التسجيل — `FR-M19-04`', () {
    test('★★ نوعُ الكيان ومعرّفه ومصدره تصل `logExport`', () {
      final ExportableDocument document = buildDistributionExport(
        business: _business,
        data: _distribution(),
        sourceId: 'SRC-001',
        sourceName: 'مصدر صنعاء',
        entityId: 'MQT-0001_SRC-001_20260830',
        withPricing: true,
      );
      expect(document.entityType, distributionEntityType);
      expect(document.entityId, 'MQT-0001_SRC-001_20260830');
      expect(document.sourceId, 'SRC-001');
      // ⛔ **والتوزيعة بلا رقم مستندٍ في القيد** — ★ **معرّفها مركّب.**
      expect(document.documentNumber, isNull);
    });

    test('★ وسندُ القبض يحمل رقمَه في الحقلين معاً', () {
      final ExportableDocument document = buildReceiptExport(
        business: _business,
        data: buildReceiptMessageData(
          dealerName: 'أحمد صالح',
          documentNumber: 'RCP-20260830-0007',
          paidOn: CalendarDay(2026, 8, 30),
          settled: <ReceiptSettlementInput>[],
          openRemainingBefore: Money.zero,
        ),
        sourceId: 'SRC-001',
        sourceName: 'مصدر صنعاء',
      );
      expect(document.entityType, receiptEntityType);
      expect(document.entityId, 'RCP-20260830-0007');
      expect(document.documentNumber, 'RCP-20260830-0007');
    });
  });

  group('★★★ بناء سند القبض — الحساب في النطاق لا في الشاشة', () {
    ReceiptMessageData build({Money surplus = Money.zero}) =>
        buildReceiptMessageData(
          dealerName: 'أحمد صالح',
          documentNumber: 'RCP-20260830-0007',
          paidOn: CalendarDay(2026, 8, 30),
          settled: <ReceiptSettlementInput>[
            ReceiptSettlementInput(
              stockDate: CalendarDay(2026, 8, 28),
              remainingBefore: const Money(50000),
              amount: const Money(50000),
            ),
            ReceiptSettlementInput(
              stockDate: CalendarDay(2026, 8, 29),
              remainingBefore: const Money(32000),
              amount: const Money(20000),
            ),
          ],
          openRemainingBefore: const Money(82000),
          surplusAmount: surplus,
        );

    test('★ المتبقي على كل ضمارٍ بعد سداده', () {
      final ReceiptMessageData data = build();
      expect(data.settledLines.first.remainingAfter, const Money(0));
      expect(data.settledLines.last.remainingAfter, const Money(12000));
    });

    test('★ وإجمالي المقبوض مجموعُ السطور', () {
      expect(build().totalPaid, const Money(70000));
    });

    test('★★ والرصيد بعد السداد = المفتوحُ قبلها − المسدَّد', () {
      expect(build().balanceAfter, const Money(12000));
    });

    test('⛔⛔ والفائض يدخل المقبوض ولا يُنقِص الرصيد — `FR-M12-11`', () {
      // ★ **نقدٌ دخل ولم يُنسَب لضمارٍ بعد** — ⟵ **يُطبَّق على ضمارٍ قادم.**
      final ReceiptMessageData data = build(surplus: const Money(5000));
      expect(data.totalPaid, const Money(75000));
      expect(data.balanceAfter, const Money(12000));
    });

    test('★ ومجموع المتبقي دالةُ نطاقٍ لا جمعٌ في شاشة', () {
      expect(
        totalOpenRemaining(const <Money>[Money(50000), Money(32000)]),
        const Money(82000),
      );
      expect(totalOpenRemaining(const <Money>[]), Money.zero);
    });
  });

  group('★★ الرصيد قبل ضمار اليوم — افتراضٌ موثَّق', () {
    test('★ الحالي ناقص ضمار اليوم', () {
      expect(
        balanceBeforeTodayDebt(
          currentBalance: const Money(100000),
          todayDebt: const Money(92000),
        ),
        const Money(8000),
      );
    });

    test('★ ويصلح سالباً — ⛔ ولا يُطوى إلى صفر', () {
      // ⚠️ **رصيدٌ سالب يعني «للمقوت عندنا»** — ★ **وطيُّه يقلب المعنى.**
      expect(
        balanceBeforeTodayDebt(
          currentBalance: const Money(1000),
          todayDebt: const Money(5000),
        ),
        const Money(-4000),
      );
    });
  });
}

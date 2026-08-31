/// اختبارات قوالب رسائل `M20` — ★ **القيمة والنصّ معاً**.
///
/// ★★ **ولماذا يُختبَر نصُّ القالب حرفاً بحرف:** `FR-M20-06` يجعله **ثابتاً
/// لا يُغيَّر إلا بإصدار**، ⟵ **فتغيّرُه انحرافٌ تعاقدي لا تحسينُ صياغة**،
/// ★ **والاختبار هو ما يجعله كذلك فعلاً** ⛔ **لا التعليق فوقه.**
library;

import 'package:qtms_domain/qtms_domain.dart';
import 'package:test/test.dart';

const MessageBusiness _business = MessageBusiness(
  businessName: 'وكالة محمد المحامي',
  thousandsSeparator: ',',
);

DistributionMessageData _distribution({
  bool priced = true,
  bool mixedUnits = true,
}) =>
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
        if (mixedUnits)
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
  group('FR-M20-08 — فواصل الآلاف وبلا كسور للمبالغ', () {
    test('يجمّع بثلاث خانات', () {
      expect(formatRiyals(const Money(1234567)), '1,234,567');
      expect(formatRiyals(const Money(1000)), '1,000');
      expect(formatRiyals(const Money(999)), '999');
      expect(formatRiyals(const Money(0)), '0');
    });

    test('★ والسالب يحتفظ بإشارته — ⛔ ولا يُطوى إلى صفر', () {
      // ★ رصيدٌ سالب يعني «للمقوت عندنا» — وإخفاؤه يقلب معنى الرسالة.
      expect(formatRiyals(const Money(-2500)), '-2,500');
      expect(formatRiyals(const Money(-999)), '-999');
    });

    test('★ وفاصلٌ فارغ في الإعداد يعني بلا فاصل — ⛔ ولا يُبدَّل افتراضاً', () {
      expect(
        formatRiyals(const Money(1234567), thousandsSeparator: ''),
        '1234567',
      );
      expect(
        formatRiyals(const Money(-1234567), thousandsSeparator: ''),
        '-1234567',
      );
    });

    test('⛔ ولا كسر عشري في أي مبلغ — النوع نفسه يمنعه', () {
      // ★ حارسٌ على النوع لا على النصّ: `Money` عدد صحيح بالتعريف
      //   (`ADR-0015`) — فلا مسار يُنتج كسراً أصلاً.
      expect(formatRiyals(const Money(2000)), isNot(contains('.')));
    });
  });

  group('FR-M20-10 · GR-19 — الإجماليات تفصل الحبات عن الأوزان', () {
    test('★ إجماليان في سطرٍ واحد ⛔ ولا جمعَ بينهما', () {
      expect(
        formatTotals(const <StockQuantity>[
          PieceQuantity(PieceCount(60)),
          WeightQuantity(WeightKg(0.5)),
        ]),
        '60 حبة + 0.500 كجم',
      );
    });

    test('★ والطرف الغائب يُعرَض صفراً — فالسطر موجودٌ دائماً', () {
      expect(
        formatTotals(const <StockQuantity>[PieceQuantity(PieceCount(60))]),
        '60 حبة + 0.000 كجم',
      );
      expect(
        formatTotals(const <StockQuantity>[WeightQuantity(WeightKg(1.25))]),
        '0 حبة + 1.250 كجم',
      );
    });

    test('★ ورسالةٌ بلا سطور تُنتج إجمالياً صفرياً ⛔ لا فراغاً', () {
      expect(formatTotals(const <StockQuantity>[]), '0 حبة + 0.000 كجم');
    });

    test('★ والوزن بثلاث خانات دائماً — `FR-M20-08`', () {
      expect(
        formatQuantity(const WeightQuantity(WeightKg(2))),
        '2.000 كجم',
      );
      expect(
        formatQuantity(const PieceQuantity(PieceCount(7))),
        '7 حبة',
      );
    });
  });

  group('القالب ① — التوزيع فقط (`IQ-031` الخيار ب)', () {
    test('★ الترويسة والسطور والإجمالي — بلا سعرٍ واحد', () {
      final String text = renderDistributionMessage(
        business: _business,
        data: _distribution(priced: false),
        template: MessageTemplate.distributionOnly,
      );
      expect(
        text,
        'وكالة محمد المحامي\n'
        'تاريخ المخزون: 2026/08/30\n'
        'الأخ/ أحمد صالح — تفاصيل ما استلمته اليوم:\n'
        '\n'
        'شامي — 60 حبة\n'
        'سكرب — 0.500 كجم\n'
        'الإجمالي: 60 حبة + 0.500 كجم',
      );
    });

    test('⛔⛔ ولا سعرَ ولا ضمارَ ولا رصيدَ يتسرّب إلى القالب ①', () {
      final String text = renderDistributionMessage(
        business: _business,
        data: _distribution(),
        template: MessageTemplate.distributionOnly,
      );
      // ★ البيانات المُمرَّرة **مسعَّرة كاملةً** — والقالب ① يتجاهلها عمداً:
      //   ⟵ **فمن لا يملك `distributionPriceView` لا يُسرَّب له سعرٌ عبر
      //   رسالة** (`ت-12`)، ⛔ ولو حُمِّلت البيانات كاملةً في الشاشة.
      expect(text, isNot(contains('1,500')));
      expect(text, isNot(contains('ضمار اليوم')));
      expect(text, isNot(contains('الرصيد')));
    });
  });

  group('القالب ② — التوزيع مع التسعير', () {
    test('★ السعر وقيمة السطر بصيغة `FR-M20-08` حرفياً', () {
      final String text = renderDistributionMessage(
        business: _business,
        data: _distribution(),
        template: MessageTemplate.distributionWithPricing,
      );
      // ★ مثال المتطلب نفسه: «سكرب … 0.500 كجم × 4,000 = 2,000».
      expect(text, contains('سكرب — 0.500 كجم × 4,000 = 2,000'));
      expect(text, contains('شامي — 60 حبة × 1,500 = 90,000'));
    });

    test('★ ويضيف ضمار اليوم والرصيدين — `FR-M20-07`', () {
      final String text = renderDistributionMessage(
        business: _business,
        data: _distribution(),
        template: MessageTemplate.distributionWithPricing,
      );
      expect(text, contains('ضمار اليوم: 92,000'));
      expect(text, contains('الرصيد السابق: 8,000'));
      expect(text, contains('الرصيد الحالي: 100,000'));
    });

    test('⛔⛔ والسطر غير المسعَّر يُكتب «غير مسعَّر» ⛔ لا صفراً', () {
      // `FR-M10-08` · `BR-M10-04`: **الغياب ليس صفراً** — ★ **وصفرٌ هنا
      //   كان يقول للمقوت إن السطر مجّاني.**
      final String text = renderDistributionMessage(
        business: _business,
        data: DistributionMessageData(
          dealerName: 'أحمد صالح',
          stockDate: CalendarDay(2026, 8, 30),
          lines: const <MessageLine>[
            MessageLine(
              itemName: 'شامي',
              quantity: PieceQuantity(PieceCount(60)),
            ),
          ],
          debtValue: const Money(0),
          previousBalance: const Money(0),
          currentBalance: const Money(0),
        ),
        template: MessageTemplate.distributionWithPricing,
      );
      expect(text, contains('شامي — 60 حبة — غير مسعَّر'));
      expect(text, isNot(contains('× 0 =')));
    });
  });

  group('★★ `CR-004` — الترويسة بلا اسم المصدر (نصّ المالك في `IQ-031`)', () {
    test('⛔ ولا سطرَ «المصدر:» في أي قالبٍ من قوالب التوزيع', () {
      for (final MessageTemplate template in <MessageTemplate>[
        MessageTemplate.distributionOnly,
        MessageTemplate.distributionWithPricing,
      ]) {
        final String text = renderDistributionMessage(
          business: _business,
          data: _distribution(),
          template: template,
        );
        expect(text, isNot(contains('المصدر')), reason: '$template');
      }
    });

    test('★ وتاريخ المخزون يبقى — فأحد البُعدين مرئي', () {
      // ⚠️ **الخطر المعلَن في `CR-004` §4:** حذفُ المصدر يُبقي التاريخ
      //   وحده مميِّزاً — ★ **وهذا الاختبار يحرس ما بقي.**
      final String text = renderDistributionMessage(
        business: _business,
        data: _distribution(),
        template: MessageTemplate.distributionOnly,
      );
      expect(text, contains('تاريخ المخزون: 2026/08/30'));
    });
  });

  group('القالب ③ — سند القبض', () {
    test('★ الضمارات المسدَّدة والرصيد بعدها', () {
      final String text = renderReceiptMessage(
        business: _business,
        data: ReceiptMessageData(
          dealerName: 'أحمد صالح',
          documentNumber: 'RCP-20260830-0007',
          paidOn: CalendarDay(2026, 8, 30),
          settledLines: <SettledDebtLine>[
            SettledDebtLine(
              stockDate: CalendarDay(2026, 8, 28),
              amount: const Money(50000),
              remainingAfter: const Money(0),
            ),
            SettledDebtLine(
              stockDate: CalendarDay(2026, 8, 29),
              amount: const Money(20000),
              remainingAfter: const Money(12000),
            ),
          ],
          totalPaid: const Money(70000),
          balanceAfter: const Money(12000),
        ),
      );
      expect(text, contains('سند قبض رقم: RCP-20260830-0007'));
      expect(
        text,
        contains('ضمار 2026/08/28 — سُدِّد 50,000 — المتبقي 0'),
      );
      expect(
        text,
        contains('ضمار 2026/08/29 — سُدِّد 20,000 — المتبقي 12,000'),
      );
      expect(text, contains('إجمالي المقبوض: 70,000'));
      expect(text, contains('الرصيد بعد السداد: 12,000'));
    });
  });

  group('القالب ④ — سند الخصم (⏳ بلا شاشة حتى `WU-013`)', () {
    test('★ يسمّيه «خصماً» صراحةً — ⛔ لا «مقبوضاً»', () {
      final String text = renderDiscountMessage(
        business: _business,
        data: DiscountMessageData(
          dealerName: 'أحمد صالح',
          documentNumber: 'DSC-20260830-0002',
          discountedOn: CalendarDay(2026, 8, 30),
          discountedLines: <SettledDebtLine>[
            SettledDebtLine(
              stockDate: CalendarDay(2026, 8, 28),
              amount: const Money(5000),
              remainingAfter: const Money(0),
            ),
          ],
          totalDiscount: const Money(5000),
          balanceAfter: const Money(7000),
        ),
      );
      expect(text, contains('سند خصم رقم: DSC-20260830-0002'));
      expect(text, contains('خُصم 5,000'));
      expect(text, contains('إجمالي الخصم: 5,000'));
      expect(text, contains('الرصيد بعد الخصم: 7,000'));
      expect(text, isNot(contains('مقبوض')));
    });
  });

  group('FR-M20-13 — النسخة المختصرة: الإجمالي والرصيد فقط', () {
    test('★ بلا سطرٍ صنفي واحد', () {
      final String text = renderShortDistributionMessage(
        business: _business,
        data: _distribution(),
      );
      expect(text, isNot(contains('شامي')));
      expect(text, isNot(contains('سكرب')));
      expect(text, contains('الإجمالي: 60 حبة + 0.500 كجم'));
      expect(text, contains('ضمار اليوم: 92,000'));
      expect(text, contains('الرصيد الحالي: 100,000'));
    });

    test('★ وأقصرُ فعلاً من الكاملة — وإلا فلا معنى للخيار', () {
      final DistributionMessageData data = _distribution();
      expect(
        renderShortDistributionMessage(business: _business, data: data).length,
        lessThan(
          renderDistributionMessage(
            business: _business,
            data: data,
            template: MessageTemplate.distributionWithPricing,
          ).length,
        ),
      );
    });
  });

  group('FR-M20-11 — الترميز والأسطر', () {
    test('⛔ ولا محرف تحكّم خفيّ في أي مخرَج', () {
      // ★ الرسالة تعبر تطبيقاً آخر لا نتحكم في عرضه — ⟵ **ومحارف الاتجاه
      //   المضمَّنة تظهر مربّعاتٍ في بعض العملاء.**
      final String text = renderDistributionMessage(
        business: _business,
        data: _distribution(),
        template: MessageTemplate.distributionWithPricing,
      );
      for (final int rune in text.runes) {
        final bool isControl = rune < 0x20 && rune != 0x0A;
        final bool isBidi = rune >= 0x200E && rune <= 0x200F ||
            rune >= 0x202A && rune <= 0x202E;
        expect(isControl || isBidi, isFalse,
            reason: 'محرف تحكّم غير مسموح: ${rune.toRadixString(16)}');
      }
    });

    test('★ ولا سطرَ فارغ في الذيل — `trimRight`', () {
      final String text = renderDistributionMessage(
        business: _business,
        data: _distribution(),
        template: MessageTemplate.distributionOnly,
      );
      expect(text.endsWith('\n'), isFalse);
    });
  });

  group('⛔⛔ الخصوصية — بصمة جهة التطوير خارج كل مخرَج (`FR-SYS-30`)', () {
    test('لا ذكرَ لجهة تطويرٍ في أي قالب', () {
      final List<String> outputs = <String>[
        renderDistributionMessage(
          business: _business,
          data: _distribution(),
          template: MessageTemplate.distributionWithPricing,
        ),
        renderShortDistributionMessage(
          business: _business,
          data: _distribution(),
        ),
      ];
      for (final String text in outputs) {
        expect(text.toLowerCase(), isNot(contains('orimind')));
        expect(text.toLowerCase(), isNot(contains('qtms')));
      }
    });
  });
}

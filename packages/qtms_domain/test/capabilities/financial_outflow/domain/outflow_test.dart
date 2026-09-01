/// ★★★ **السحبيات والخرجيات** — `M22` · `FR-M22` · `WU-014`.
library;

import 'package:qtms_domain/qtms_domain.dart';
import 'package:test/test.dart';

const String sourceA = 'SRC-001';
const String itemA = 'ITM-0001';
const String itemB = 'ITM-0002';

CalendarDay day(int d) => CalendarDay(2026, 9, d);

OutflowQatLineInput qat({
  String itemId = itemA,
  String itemName = 'عتود',
  ItemUnit unit = ItemUnit.piece,
  num quantity = 5,
  int? unitPrice = 1500,
  String? sackId,
}) =>
    OutflowQatLineInput(
      itemId: itemId,
      itemName: itemName,
      unit: unit,
      quantity: unit == ItemUnit.piece
          ? PieceQuantity(PieceCount(quantity.toInt()))
          : WeightQuantity(WeightKg(quantity.toDouble())),
      unitPrice: unitPrice == null ? null : Money(unitPrice),
      sackId: sackId,
    );

OutflowCashLineInput cash({
  OutflowLineKind kind = OutflowLineKind.amount,
  int amount = 20000,
  String? description,
}) =>
    OutflowCashLineInput(
      kind: kind,
      amount: Money(amount),
      description: description,
    );

OutflowInput input({
  OutflowLedgerType ledgerType = OutflowLedgerType.withdrawal,
  String sourceId = sourceA,
  OutflowCategory? category,
  List<OutflowQatLineInput> qatLines = const <OutflowQatLineInput>[],
  List<OutflowCashLineInput> cashLines = const <OutflowCashLineInput>[],
  String? notes,
}) =>
    OutflowInput(
      ledgerType: ledgerType,
      sourceId: sourceId,
      category: category ??
          (ledgerType == OutflowLedgerType.withdrawal
              ? OutflowCategory.withdrawalQat
              : OutflowCategory.expenseShareCuts),
      qatLines: qatLines,
      cashLines: cashLines,
      notes: notes,
    );

ValidatedOutflow accepted(OutflowInput raw) {
  final Outcome<ValidatedOutflow> result = validateOutflow(raw);
  expect(result, isA<Success<ValidatedOutflow>>(), reason: 'كان يجب أن يُقبَل');
  return (result as Success<ValidatedOutflow>).value;
}

String? ruleOf(Outcome<ValidatedOutflow> result) =>
    result is Failure<ValidatedOutflow> && result.error is ValidationError
        ? (result.error as ValidationError).ruleCode
        : null;

void main() {
  // ═══════════════════════════════════════════════════════════════════════
  // ⛔⛔★★★ `GR-42` — المصدر إلزاميٌّ دائماً، حتى لسحبيات المالك
  // ═══════════════════════════════════════════════════════════════════════
  group('GR-42 · FR-M22-02 · E-28 — المصدر إلزامي', () {
    test('⛔ سحبيةٌ بلا مصدر تُرفَض — ★ ولو كانت شخصية للمالك', () {
      final Outcome<ValidatedOutflow> result = validateOutflow(
        input(sourceId: '', cashLines: <OutflowCashLineInput>[cash()]),
      );
      expect(result, isA<Failure<ValidatedOutflow>>());
      expect(ruleOf(result), 'FR-M22-02');
    });

    test('⛔ والفراغُ ليس مصدراً — ★ فالمسافات تُقصّ ثم يُفحَص', () {
      final Outcome<ValidatedOutflow> result = validateOutflow(
        input(sourceId: '   ', cashLines: <OutflowCashLineInput>[cash()]),
      );
      expect(ruleOf(result), 'FR-M22-02');
    });

    test('⛔ والخرجيةُ بلا مصدر تُرفَض كذلك — ★ فالقاعدة للسجلَّين', () {
      final Outcome<ValidatedOutflow> result = validateOutflow(
        input(
          ledgerType: OutflowLedgerType.expense,
          sourceId: '',
          cashLines: <OutflowCashLineInput>[cash()],
        ),
      );
      expect(ruleOf(result), 'FR-M22-02');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // ★★★ `GR-42` · `AT-38` — الإجمالي النهائي = قيمة القات + المبالغ
  // ═══════════════════════════════════════════════════════════════════════
  group('GR-42 · AT-38 — الإجمالي النهائي', () {
    test('★★★ سيناريو AT-38 حرفياً: 5 حبات × 1,500 + 20,000 ⟹ 27,500', () {
      final ValidatedOutflow doc = accepted(
        input(
          qatLines: <OutflowQatLineInput>[qat(quantity: 5, unitPrice: 1500)],
          cashLines: <OutflowCashLineInput>[cash(amount: 20000)],
        ),
      );
      expect(doc.totalQatValue, const Money(7500));
      expect(doc.totalCashValue, const Money(20000));
      expect(doc.grandTotal, const Money(27500));
    });

    test('★ سندُ مبالغَ خالصٌ — ⛔ ولا يمسّ المخزون', () {
      final ValidatedOutflow doc = accepted(
        input(
          category: OutflowCategory.withdrawalCash,
          cashLines: <OutflowCashLineInput>[cash(amount: 5000)],
        ),
      );
      expect(doc.totalQatValue, Money.zero);
      expect(doc.grandTotal, const Money(5000));
      expect(doc.touchesInventory, isFalse);
    });

    test('★ وسندُ قاتٍ خالصٌ يمسّ المخزون', () {
      final ValidatedOutflow doc = accepted(
        input(qatLines: <OutflowQatLineInput>[qat()]),
      );
      expect(doc.touchesInventory, isTrue);
    });

    test('★★ والدالةُ المستقلة تُطابق ما تحسبه البطاقة', () {
      expect(
        outflowGrandTotal(
          totalQatValue: const Money(7500),
          totalCashValue: const Money(20000),
        ),
        const Money(27500),
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // ★★★ `FR-M22-07` · `E-27` · `AT-41` — السعر اختياري
  // ═══════════════════════════════════════════════════════════════════════
  group('FR-M22-07 · E-27 — بندُ قاتٍ بلا سعر', () {
    test('★★★ يُقبَل ويُعَدّ غيرَ مسعَّر — ⛔ بخلاف البيع النقدي', () {
      final ValidatedOutflow doc = accepted(
        input(qatLines: <OutflowQatLineInput>[qat(unitPrice: null)]),
      );
      expect(doc.unpricedItemCount, 1);
      expect(doc.qatLines.single.isUnpriced, isTrue);
      expect(doc.qatLines.single.lineValue, isNull);
    });

    test('⛔⛔ وقيمتُه لا تدخل الإجمالي — ★ ولا تُعامَل صفراً', () {
      final ValidatedOutflow doc = accepted(
        input(
          qatLines: <OutflowQatLineInput>[
            qat(quantity: 5, unitPrice: 1500),
            qat(itemId: itemB, itemName: 'مطري', quantity: 3, unitPrice: null),
          ],
        ),
      );
      // ★ **7,500 وحدها** — ⛔ **والسطر الثاني معلَنٌ لا مُبتلَع.**
      expect(doc.totalQatValue, const Money(7500));
      expect(doc.unpricedItemCount, 1);
    });

    test('★ وسندٌ مسعَّرٌ بالكامل عدّادُه صفر', () {
      final ValidatedOutflow doc = accepted(
        input(qatLines: <OutflowQatLineInput>[qat()]),
      );
      expect(doc.unpricedItemCount, 0);
    });

    test('⛔ والسعرُ الصفري مرفوضٌ — ★ فالصفر ليس سعراً وغيابُه معلَن', () {
      final Outcome<ValidatedOutflow> result = validateOutflow(
        input(qatLines: <OutflowQatLineInput>[qat(unitPrice: 0)]),
      );
      expect(ruleOf(result), 'FR-M22-07');
    });

    test('⛔ والسالبُ مرفوضٌ كذلك', () {
      final Outcome<ValidatedOutflow> result = validateOutflow(
        input(qatLines: <OutflowQatLineInput>[qat(unitPrice: -1)]),
      );
      expect(ruleOf(result), 'FR-M22-07');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // ⛔ `GR-19` · `FR-M22-11` · `E-31` — الوحدات لا تُجمع
  // ═══════════════════════════════════════════════════════════════════════
  group('GR-19 · FR-M22-11 — الحبّة والكيلوجرام لا يُجمعان', () {
    test('★ إجماليان منفصلان دائماً', () {
      final ValidatedOutflow doc = accepted(
        input(
          qatLines: <OutflowQatLineInput>[
            qat(quantity: 5),
            qat(
              itemId: itemB,
              itemName: 'مطري',
              unit: ItemUnit.kilogram,
              quantity: 2.5,
              unitPrice: 4000,
            ),
          ],
        ),
      );
      expect(doc.totalPieces, const PieceCount(5));
      expect(doc.totalWeight.kilograms, closeTo(2.5, 1e-9));
    });

    test('⛔ ووحدةُ الكمية يجب أن تطابق وحدة النوع', () {
      final Outcome<ValidatedOutflow> result = validateOutflow(
        input(
          qatLines: <OutflowQatLineInput>[
            OutflowQatLineInput(
              itemId: itemA,
              itemName: 'عتود',
              unit: ItemUnit.kilogram,
              quantity: const PieceQuantity(PieceCount(5)),
              unitPrice: const Money(1500),
            ),
          ],
        ),
      );
      expect(ruleOf(result), 'GR-19');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // ⛔ `FR-M22-19` — الفئة من فئات سجلِّها وحدها
  // ═══════════════════════════════════════════════════════════════════════
  group('FR-M22-19 — الفئات مقيَّدةٌ بسجلِّها', () {
    test('⛔ فئةُ خرجيةٍ في سحبيةٍ تُرفَض', () {
      final Outcome<ValidatedOutflow> result = validateOutflow(
        input(
          category: OutflowCategory.expenseShareCuts,
          cashLines: <OutflowCashLineInput>[cash()],
        ),
      );
      expect(ruleOf(result), 'FR-M22-19');
    });

    test('⛔ وفئةُ سحبيةٍ في خرجيةٍ تُرفَض', () {
      final Outcome<ValidatedOutflow> result = validateOutflow(
        input(
          ledgerType: OutflowLedgerType.expense,
          category: OutflowCategory.withdrawalQat,
          cashLines: <OutflowCashLineInput>[cash()],
        ),
      );
      expect(ruleOf(result), 'FR-M22-19');
    });

    test('★ وثلاثٌ للسحبية وأربعٌ للخرجية — ⛔ لا قائمةٌ واحدة', () {
      expect(OutflowCategory.of(OutflowLedgerType.withdrawal), hasLength(3));
      expect(OutflowCategory.of(OutflowLedgerType.expense), hasLength(4));
      expect(OutflowCategory.values, hasLength(7));
    });

    test('★ وكلُّ تسميةٍ عربيةٌ من نصّ المتطلب', () {
      expect(OutflowCategory.expenseShareCuts.label, 'شُقى الشُقّات');
      expect(OutflowCategory.expenseQatForShares.label, 'قات للشُقّات');
      expect(OutflowCategory.withdrawalCash.label, 'مبلغ مالي');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // ★ `FR-M22-05` — سطور المبالغ
  // ═══════════════════════════════════════════════════════════════════════
  group('FR-M22-05 — سطور المبالغ', () {
    test('⛔ المبلغُ الصفري مرفوض', () {
      final Outcome<ValidatedOutflow> result = validateOutflow(
        input(cashLines: <OutflowCashLineInput>[cash(amount: 0)]),
      );
      expect(ruleOf(result), 'FR-M22-05');
    });

    test('⛔ والسالبُ مرفوض — ★ فالسحبيةُ خروجٌ لا إدخال', () {
      final Outcome<ValidatedOutflow> result = validateOutflow(
        input(cashLines: <OutflowCashLineInput>[cash(amount: -100)]),
      );
      expect(ruleOf(result), 'FR-M22-05');
    });

    test('⛔ و«أخرى» بلا وصفٍ تُرفَض — ★ والمتطلب ينصّ «وصف + مبلغ»', () {
      final Outcome<ValidatedOutflow> result = validateOutflow(
        input(
          cashLines: <OutflowCashLineInput>[
            cash(kind: OutflowLineKind.other, description: '   '),
          ],
        ),
      );
      expect(ruleOf(result), 'FR-M22-05');
    });

    test('★ و«مبلغ» بلا وصفٍ مقبولة — ⛔ ولا يُفرَض ما لا ينصّه المتطلب', () {
      final ValidatedOutflow doc = accepted(
        input(cashLines: <OutflowCashLineInput>[cash()]),
      );
      expect(doc.cashLines.single.description, isNull);
    });

    test('⛔ وسطرُ قاتٍ في قائمة المبالغ خللٌ يُرفَض', () {
      final Outcome<ValidatedOutflow> result = validateOutflow(
        input(
          cashLines: <OutflowCashLineInput>[cash(kind: OutflowLineKind.qat)],
        ),
      );
      expect(ruleOf(result), 'FR-M22-05');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // ★ بنيةُ السند
  // ═══════════════════════════════════════════════════════════════════════
  group('بنية السند', () {
    test('⛔ سندٌ بلا سطرٍ واحد يُرفَض', () {
      expect(ruleOf(validateOutflow(input())), 'FR-M22-01');
    });

    test('⛔ ولا سطران لنفس النوع — ★ والواجهة تدمجهما قبل الوصول', () {
      final Outcome<ValidatedOutflow> result = validateOutflow(
        input(
          qatLines: <OutflowQatLineInput>[qat(), qat()],
        ),
      );
      expect(ruleOf(result), 'BR-M10-15');
    });

    test('⛔ والكميةُ الصفرية مرفوضة', () {
      final Outcome<ValidatedOutflow> result = validateOutflow(
        input(qatLines: <OutflowQatLineInput>[qat(quantity: 0)]),
      );
      expect(ruleOf(result), 'BR-M22-09');
    });

    test('★★ والسطورُ تُرتَّب بمفتاح النوع — فنفسُ الإدخال يُنتج نفسَ المستند',
        () {
      final ValidatedOutflow doc = accepted(
        input(
          qatLines: <OutflowQatLineInput>[
            qat(itemId: itemB, itemName: 'مطري'),
            qat(itemId: itemA),
          ],
        ),
      );
      expect(
        doc.qatLines.map((ValidatedOutflowQatLine l) => l.itemKey),
        <String>[itemA, itemB],
      );
    });

    test('★ والبيانُ الفارغ غيابٌ لا نصٌّ فارغ — ADR-0020', () {
      final ValidatedOutflow doc = accepted(
        input(cashLines: <OutflowCashLineInput>[cash()], notes: '   '),
      );
      expect(doc.notes, isNull);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // ⛔⛔★★★ `FR-M22-04` · `GR-44` — لا حقلَ مقوتٍ في هذه الطبقة إطلاقاً
  // ═══════════════════════════════════════════════════════════════════════
  group('GR-44 — لا مساس بدفتر المقاوته', () {
    test('⛔⛔ ولا حقلَ مقوتٍ في أي مُدخَلٍ ولا مخرَجٍ هنا — غيابٌ بنيوي', () {
      // ★★ **حارسٌ على الغياب لا على القيمة** — ⟵ **فالتنفيذ يفرض المتطلب
      //    بنوعه**: ⛔ **ولا مسارٌ يُمرِّر مقوتاً سهواً فيُكتَب له قيد.**
      final ValidatedOutflow doc = accepted(
        input(qatLines: <OutflowQatLineInput>[qat()]),
      );
      expect(doc.toString(), isNotEmpty);
      expect(
        <String>[
          ...doc.qatLines.map((ValidatedOutflowQatLine l) => l.itemKey),
        ],
        isNot(contains('MQT-0001')),
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // ★★★ `FR-M22-09` · `AT-56` — التاريخ
  // ═══════════════════════════════════════════════════════════════════════
  group('FR-M22-09 · BR-M22-06 · AT-56 — تاريخ السند', () {
    test('⛔⛔ المستقبليُّ مرفوضٌ دائماً — ★ ولو ملك المفتاح', () {
      final Outcome<void> result = validateOutflowDate(
        date: day(2),
        today: day(1),
        canBackdate: true,
      );
      expect(result, isA<Failure<void>>());
      expect(
        ((result as Failure<void>).error as ValidationError).ruleCode,
        'BR-M22-06',
      );
    });

    test('⛔ والسابقُ بلا مفتاحٍ يُرفَض بخطأ صلاحية', () {
      final Outcome<void> result = validateOutflowDate(
        date: day(1),
        today: day(3),
        canBackdate: false,
      );
      expect((result as Failure<void>).error, isA<PermissionError>());
    });

    test('★ والسابقُ بمفتاحه يُقبَل', () {
      expect(
        validateOutflowDate(
          date: day(1),
          today: day(3),
          canBackdate: true,
        ),
        isA<Success<void>>(),
      );
    });

    test('★ واليومُ يُقبَل بلا مفتاح', () {
      expect(
        validateOutflowDate(
          date: day(3),
          today: day(3),
          canBackdate: false,
        ),
        isA<Success<void>>(),
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // ★ `FR-M22-18` · `A-14` — الإلغاء بالوسم
  // ═══════════════════════════════════════════════════════════════════════
  group('FR-M22-18 — الملغى لا يُمَسّ', () {
    test('⛔ الملغى يُرفَض تعديلاً وإلغاءً ثانياً', () {
      final Outcome<void> result =
          validateOutflowNotCancelled(OutflowStatus.cancelled);
      expect(
        ((result as Failure<void>).error as ValidationError).ruleCode,
        'FR-M22-18',
      );
    });

    test('★ والمعتمَدُ يمرّ', () {
      expect(
        validateOutflowNotCancelled(OutflowStatus.approved),
        isA<Success<void>>(),
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // ★★ التفويض — ⛔ ولا معادلةَ ثانية
  // ═══════════════════════════════════════════════════════════════════════
  group('ADR-0019 · coding-standards §2.2 — التفويض لا النسخ', () {
    test('★★★ قيمةُ السطر تُطابق [distributionLineTotal] حرفياً', () {
      const StockQuantity q = WeightQuantity(WeightKg(2.5));
      expect(
        outflowQatLineValue(quantity: q, unitPrice: const Money(4000)),
        distributionLineTotal(quantity: q, unitPrice: const Money(4000)),
      );
    });

    test('★ وموضعُ التقريب الثالث محفوظ — 2.5 كجم × 4,000 ⟹ 10,000', () {
      expect(
        outflowQatLineValue(
          quantity: const WeightQuantity(WeightKg(2.5)),
          unitPrice: const Money(4000),
        ),
        const Money(10000),
      );
    });

    test('★ وتاريخُ السند يُطابق [validateReceiptDate] في المستقبلي', () {
      expect(
        validateOutflowDate(date: day(5), today: day(1), canBackdate: true),
        isA<Failure<void>>(),
      );
      expect(
        validateReceiptDate(date: day(5), today: day(1), canBackdate: true),
        isA<Failure<void>>(),
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // ★★ `GR-43` — السجلّان وترقيمُهما
  // ═══════════════════════════════════════════════════════════════════════
  group('GR-43 · FR-M22-01 — ترقيمٌ منفصل لكل سجل', () {
    test('★ السحبيةُ `WDR` والخرجيةُ `EXP` — ⛔ ولا بادئةَ مكتوبةٌ هنا', () {
      expect(OutflowLedgerType.withdrawal.documentKind, DocumentKind.withdrawal);
      expect(OutflowLedgerType.expense.documentKind, DocumentKind.expense);
      expect(OutflowLedgerType.withdrawal.documentKind.prefix, 'WDR');
      expect(OutflowLedgerType.expense.documentKind.prefix, 'EXP');
    });

    test('★ وكلاهما يقبل تاريخاً سابقاً — allowsBackdating', () {
      expect(allowsBackdating(DocumentKind.withdrawal), isTrue);
      expect(allowsBackdating(DocumentKind.expense), isTrue);
    });

    test('★ ومفاتيحُ السجلَّين مستقلةٌ في الكتالوج — GR-43', () {
      expect(
        <Permission>{
          Permission.withdrawalCreate,
          Permission.expenseCreate,
          Permission.withdrawalView,
          Permission.expenseView,
          Permission.withdrawalQatPriceNow,
          Permission.expenseQatPriceNow,
          Permission.withdrawalBackdate,
          Permission.expenseBackdate,
        },
        hasLength(8),
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // ★★ `FR-SYS-08` — بندُ المركز المعلّق
  // ═══════════════════════════════════════════════════════════════════════
  group('FR-SYS-08 · AT-41 — بندُ المركز المعلّق', () {
    test('★★ بندٌ واحد للسند مهما بلغ عددُ بنوده غير المسعَّرة', () {
      final PendingEntrySet set = describeOutflowPending(
        outflowId: 'WDR-20260901-0001',
        sourceId: sourceA,
        stockDate: day(1),
        categoryLabel: 'سحبية قات',
        unpricedLineCount: 3,
      );
      expect(set.drafts, hasLength(1));
      expect(set.drafts.single.missingField, 'سعر الوحدة لـ3 بنود');
      expect(set.clearedIds, isEmpty);
    });

    test('★ والمفردُ بصيغته — «لبندٍ واحد»', () {
      final PendingEntrySet set = describeOutflowPending(
        outflowId: 'EXP-20260901-0001',
        sourceId: sourceA,
        stockDate: day(1),
        categoryLabel: 'خرجية قات للشُقّات',
        unpricedLineCount: 1,
      );
      expect(set.drafts.single.missingField, 'سعر الوحدة لبندٍ واحد');
    });

    test('★ والسندُ المسعَّر بالكامل يُخلي بندَه', () {
      final PendingEntrySet set = describeOutflowPending(
        outflowId: 'WDR-20260901-0001',
        sourceId: sourceA,
        stockDate: day(1),
        categoryLabel: 'سحبية قات',
        unpricedLineCount: 0,
      );
      expect(set.drafts, isEmpty);
      expect(set.clearedIds, hasLength(1));
    });

    test('⛔⛔ والملغى يُخلي بندَه ولو بقي غيرَ مسعَّر — GR-06', () {
      final PendingEntrySet set = describeOutflowPending(
        outflowId: 'WDR-20260901-0001',
        sourceId: sourceA,
        stockDate: day(1),
        categoryLabel: 'سحبية قات',
        unpricedLineCount: 2,
        isCancelled: true,
      );
      expect(set.drafts, isEmpty);
      expect(set.clearedIds, hasLength(1));
    });

    test('⛔⛔★★ وتاريخُه تاريخُ المخزون لا تاريخُ السند — GR-49', () {
      final PendingEntrySet set = describeOutflowPending(
        outflowId: 'WDR-20260901-0001',
        sourceId: sourceA,
        // ★ **يوم المخزون** — ⟵ **وشاشةُ التسعير تُفتَح عليه.**
        stockDate: day(28),
        categoryLabel: 'سحبية قات',
        unpricedLineCount: 1,
      );
      expect(set.drafts.single.date, day(28));
    });
  });
}

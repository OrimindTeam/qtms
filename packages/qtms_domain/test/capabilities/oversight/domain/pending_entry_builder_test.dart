import 'package:qtms_domain/qtms_domain.dart';
import 'package:test/test.dart';

final CalendarDay day = CalendarDay(2026, 8, 30);

PendingEntrySet sackSet({
  bool hasTax = true,
  bool hasLines = true,
  SackWeightState weightState = SackWeightState.fullyExplained,
  bool isCancelled = false,
}) =>
    describeSackPending(
      sackId: 'SCK-1',
      sourceId: 'SRC-001',
      stockDate: day,
      displayName: 'عبد الفتاح - جونية رقم ١',
      documentNumber: 'SCK-20260830-0001',
      hasTax: hasTax,
      hasLines: hasLines,
      weightState: weightState,
      isCancelled: isCancelled,
    );

Set<PendingMissingField> fieldsOf(PendingEntrySet set) =>
    set.drafts.map((PendingEntryDraft d) => d.field).toSet();

void main() {
  group('describeSackPending — M7 (FR-M7-10 · E-06 · E-10)', () {
    test('★★ E-06: جونية بلا أنواع ولا ضريبة ⟵ بندان قائمان', () {
      final PendingEntrySet set = sackSet(hasTax: false, hasLines: false);
      expect(
        fieldsOf(set),
        <PendingMissingField>{
          PendingMissingField.sackTax,
          PendingMissingField.sackLines,
        },
      );
    });

    test('★★ E-10: وزنٌ غير مفسَّر ⟵ بند «الوزن الضائع لم يُؤكَّد»', () {
      final PendingEntrySet set =
          sackSet(weightState: SackWeightState.unexplained);
      expect(fieldsOf(set), contains(PendingMissingField.sackLostWeight));
    });

    test('⛔ والمؤكَّد ضائعاً ليس ناقصاً — BR-M7-12: الزرُّ الصريح إدخال', () {
      final PendingEntrySet set =
          sackSet(weightState: SackWeightState.lostConfirmed);
      expect(fieldsOf(set), isNot(contains(PendingMissingField.sackLostWeight)));
      expect(
        set.clearedIds,
        contains('sack_SCK-1_${PendingMissingField.sackLostWeight.name}'),
      );
    });

    test('⛔ والمفسَّر بالكامل ليس ناقصاً', () {
      expect(
        fieldsOf(sackSet(weightState: SackWeightState.fullyExplained)),
        isNot(contains(PendingMissingField.sackLostWeight)),
      );
    });

    test('★★★ جونيةٌ مكتملة ⟵ لا بند، وثلاثةُ معرّفاتٍ تُمحى', () {
      final PendingEntrySet set = sackSet();
      expect(set.drafts, isEmpty);
      expect(set.clearedIds, hasLength(3));
    });

    test('⛔⛔ والملغاة تُخلي بنودها كلَّها — GR-06', () {
      final PendingEntrySet set = sackSet(
        hasTax: false,
        hasLines: false,
        weightState: SackWeightState.unexplained,
        isCancelled: true,
      );
      expect(set.drafts, isEmpty);
      expect(set.clearedIds, hasLength(3));
    });

    test('★ والعنوان المقروء هو الاسم الظاهر حرفياً — §3', () {
      final PendingEntrySet set = sackSet(hasTax: false);
      expect(set.drafts.single.readableTitle, 'عبد الفتاح - جونية رقم ١');
      expect(set.drafts.single.documentNumber, 'SCK-20260830-0001');
    });

    test('★★ والمجموعتان متكاملتان — كل حقلٍ في إحداهما بالضبط', () {
      final PendingEntrySet set = sackSet(hasTax: false);
      expect(set.drafts.length + set.clearedIds.length, sackPendingFields.length);
      expect(
        set.drafts.map((PendingEntryDraft d) => d.entryId).toSet().intersection(
              set.clearedIds.toSet(),
            ),
        isEmpty,
      );
    });
  });

  group('describeItemPricingPending — M9 (FR-M9-10 · AT-16)', () {
    PendingEntrySet build({
      required bool hasStock,
      Money? distributionPrice,
      Money? minCashPrice,
    }) =>
        describeItemPricingPending(
          sourceId: 'SRC-001',
          itemKey: 'ITM-0001',
          itemName: 'قات بلدي',
          date: day,
          hasStock: hasStock,
          distributionPrice: distributionPrice,
          minCashPrice: minCashPrice,
        );

    test('★★★ كميةٌ اليوم بلا سعرين ⟵ بندٌ واحد لا اثنان', () {
      final PendingEntrySet set = build(hasStock: true);
      expect(set.drafts, hasLength(1));
      expect(set.drafts.single.field, PendingMissingField.itemPricing);
      expect(set.drafts.single.missingField, 'سعر التوزيع والحد الأدنى');
    });

    test('★★ ونصفُ التسعير ليس تسعيراً — ينقصه الحد الأدنى', () {
      final PendingEntrySet set =
          build(hasStock: true, distributionPrice: const Money(400));
      expect(set.drafts, hasLength(1));
      expect(set.drafts.single.missingField, 'الحد الأدنى');
    });

    test('★★ وينقصه سعر التوزيع وحده', () {
      final PendingEntrySet set =
          build(hasStock: true, minCashPrice: const Money(380));
      expect(set.drafts.single.missingField, 'سعر التوزيع');
    });

    test('★★★ AT-16: يختفي فور اكتمال التسعير', () {
      final PendingEntrySet set = build(
        hasStock: true,
        distributionPrice: const Money(400),
        minCashPrice: const Money(380),
      );
      expect(set.drafts, isEmpty);
      expect(set.clearedIds, hasLength(1));
    });

    test('⛔⛔ ونوعٌ نفد رصيدُه لا يُطالَب بتسعير — §9', () {
      final PendingEntrySet set = build(hasStock: false);
      expect(set.drafts, isEmpty);
      expect(
        set.clearedIds.single,
        'dailyPrice_SRC-001_ITM-0001_20260830_itemPricing',
      );
    });

    test('★★ ومعرّف البند مبنيٌّ على مفتاح السعر نفسه — لا مفتاحَ ثانٍ', () {
      final PendingEntrySet set = build(hasStock: true);
      expect(
        set.drafts.single.documentId,
        dailyPriceId(sourceId: 'SRC-001', itemKey: 'ITM-0001', date: day),
      );
    });

    test('★ والسكرب كأي نوع — FR-SYS-08 نصّاً', () {
      final PendingEntrySet set = describeItemPricingPending(
        sourceId: 'SRC-001',
        itemKey: 'سكرب - عبد الفتاح - جونية رقم ١',
        itemName: 'سكرب - عبد الفتاح - جونية رقم ١',
        date: day,
        hasStock: true,
      );
      expect(set.drafts, hasLength(1));
    });
  });

  group('describeDistributionPending — M10 (FR-M10-08 · AT-23 · AT-24)', () {
    PendingEntrySet build({
      required int unpriced,
      bool isCancelled = false,
    }) =>
        describeDistributionPending(
          distributionId: 'MQT-0001_SRC-001_20260830',
          sourceId: 'SRC-001',
          stockDate: day,
          dealerName: 'أبو أحمد',
          documentNumber: 'DST-20260830-0001',
          unpricedLineCount: unpriced,
          isCancelled: isCancelled,
        );

    test('★★★ AT-23: سطرٌ غير مسعَّر ⟵ بندٌ واحد للتوزيعة كلها', () {
      final PendingEntrySet set = build(unpriced: 1);
      expect(set.drafts, hasLength(1));
      expect(set.drafts.single.missingField, 'سعر الوحدة لسطرٍ واحد');
    });

    test('★★ وثلاثةُ سطورٍ غير مسعَّرة تبقى بنداً واحداً بعددها في نصّه', () {
      final PendingEntrySet set = build(unpriced: 3);
      expect(set.drafts, hasLength(1));
      expect(set.drafts.single.missingField, 'سعر الوحدة لـ3 سطور');
    });

    test('★★★ AT-24: تسعيرُ الباقي ⟵ يختفي البند', () {
      final PendingEntrySet set = build(unpriced: 0);
      expect(set.drafts, isEmpty);
      expect(set.clearedIds, hasLength(1));
    });

    test('⛔⛔ والملغاة تُخلي بندها — GR-06 · FR-M10-18', () {
      final PendingEntrySet set = build(unpriced: 2, isCancelled: true);
      expect(set.drafts, isEmpty);
      expect(set.clearedIds, hasLength(1));
    });

    test('★ والعنوان باسم المقوت لا بالمعرّف المركّب', () {
      expect(build(unpriced: 1).drafts.single.readableTitle, 'توزيعة أبو أحمد');
    });
  });

  group('mergePendingSets — دمج حصائل المعاملة الواحدة', () {
    PendingEntrySet pricing({
      required String itemKey,
      required bool hasStock,
      Money? distributionPrice,
      Money? minCashPrice,
    }) =>
        describeItemPricingPending(
          sourceId: 'SRC-001',
          itemKey: itemKey,
          itemName: itemKey,
          date: day,
          hasStock: hasStock,
          distributionPrice: distributionPrice,
          minCashPrice: minCashPrice,
        );

    test('★ يجمع بنودَ مستندين بلا تكرار', () {
      final PendingEntrySet merged = mergePendingSets(<PendingEntrySet>[
        pricing(itemKey: 'A', hasStock: true),
        pricing(itemKey: 'B', hasStock: true),
      ]);
      expect(merged.drafts, hasLength(2));
      expect(merged.clearedIds, isEmpty);
    });

    test('★★ والمكرَّر مرةً واحدة — سطران بنفس النوع في معاملةٍ واحدة', () {
      final PendingEntrySet merged = mergePendingSets(<PendingEntrySet>[
        pricing(itemKey: 'A', hasStock: true),
        pricing(itemKey: 'A', hasStock: true),
      ]);
      expect(merged.drafts, hasLength(1));
    });

    test('★★★ والكتابة تغلب المحو — نقصٌ حقيقي لا يُمحى بحصيلةٍ أخرى', () {
      final PendingEntrySet merged = mergePendingSets(<PendingEntrySet>[
        pricing(
          itemKey: 'A',
          hasStock: true,
          distributionPrice: const Money(1),
          minCashPrice: const Money(1),
        ),
        pricing(itemKey: 'A', hasStock: true),
      ]);
      expect(merged.drafts, hasLength(1));
      expect(merged.clearedIds, isEmpty);
    });

    test('★ وحصيلةٌ فارغة تماماً تُعرَف بنفسها', () {
      const PendingEntrySet empty = PendingEntrySet();
      expect(empty.isEmpty, isTrue);
      expect(mergePendingSets(const <PendingEntrySet>[]).isEmpty, isTrue);
    });
  });
}

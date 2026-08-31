/// باني المركز المعلّق — ★★ **الطرف السحابي** (`WU-009` · `FR-SYS-09`).
///
/// ⚠️⚠️ **ولماذا يُختبَر مستقلاً عن المعالِجات:** ★ **درسُ `DEBT-37` نصّاً**
/// — «⛔ **اختبارُ الطبقة لا يُغني عن اختبار ما يعبر بينها**»: ⟵ **وهذا
/// الملف هو ما يعبر بين خطةِ الكتابة وبين مستندات المركز**، ★ **فحراستُه
/// تحتاج اختباراً على مخرَجه هو** ⛔ **لا تغطيةً نصّية.**
library;

import 'package:qtms_domain/qtms_domain.dart';
import 'package:qtms_functions/src/audited_transaction.dart';
import 'package:qtms_functions/src/firestore_value.dart';
import 'package:qtms_functions/src/inventory.dart' show InventoryWrite;
import 'package:qtms_functions/src/pending_entries.dart';
import 'package:test/test.dart';

final CalendarDay day = CalendarDay(2026, 8, 30);
final CalendarDay yesterday = CalendarDay(2026, 8, 29);

InventoryWrite balanceWrite({
  required String itemKey,
  required Object? balance,
  String itemName = 'قات بلدي',
  CalendarDay? stockDate,
}) =>
    InventoryWrite(
      collectionId: itemDailyBalancesCollection,
      documentId: itemDailyBalanceId(
        sourceId: 'SRC-001',
        itemKey: itemKey,
        stockDate: stockDate ?? day,
      ),
      fields: <String, Object?>{
        'sourceId': 'SRC-001',
        'itemKey': itemKey,
        'itemName': itemName,
        'stockDate': (stockDate ?? day).asUtcMidnight(),
        'balance': balance,
      },
      updateMask: const <String>[],
    );

void main() {
  group('pendingEntryDocuments — شكل الكتابة', () {
    final PendingEntrySet set = describeItemPricingPending(
      sourceId: 'SRC-001',
      itemKey: 'ITM-1',
      itemName: 'قات بلدي',
      date: day,
      hasStock: true,
    );

    test('★ المجموعة والمعرّف من طبقة النطاق — ⛔ ولا نصٌّ محفور هنا', () {
      final PendingDocument doc = pendingEntryDocuments(set).single;
      expect(doc.collectionId, pendingEntriesCollection);
      expect(doc.documentId, set.drafts.single.entryId);
    });

    test('★★ والقناع كاملُ الحقول — فالنصّ القديم لا يبقى', () {
      final PendingDocument doc = pendingEntryDocuments(set).single;
      expect(doc.updateMask, doc.fields.keys.toList());
    });

    test('★★ ووقت الرصد من المنصّة — GR-54: ⛔ ولا ساعةَ حاوية', () {
      final PendingDocument doc = pendingEntryDocuments(set).single;
      expect(doc.serverTimestampFields, <String>['detectedAt']);
      expect(doc.fields.containsKey('detectedAt'), isFalse);
    });

    test('★ والمحو مستندٌ بالمعرّف نفسه في المجموعة نفسها', () {
      final PendingEntrySet cleared = describeItemPricingPending(
        sourceId: 'SRC-001',
        itemKey: 'ITM-1',
        itemName: 'قات بلدي',
        date: day,
        hasStock: false,
      );
      final PendingDeletion gone = pendingEntryDeletions(cleared).single;
      expect(gone.collectionId, pendingEntriesCollection);
      expect(gone.documentId, 'dailyPrice_SRC-001_ITM-1_20260830_itemPricing');
    });
  });

  group('pendingFromBalanceWrites — M9 من الرصيد الناتج', () {
    test('★★★ رصيدٌ موجب بلا سعر ⟵ بندٌ قائم', () {
      final PendingEntrySet set = pendingFromBalanceWrites(
        writes: <InventoryWrite>[balanceWrite(itemKey: 'ITM-1', balance: 100)],
        sourceId: 'SRC-001',
        date: day,
      );
      expect(set.drafts, hasLength(1));
      expect(set.drafts.single.readableTitle, 'قات بلدي');
    });

    test('★★★ ورصيدٌ صفر ⟵ محوٌ لا بند — §9', () {
      final PendingEntrySet set = pendingFromBalanceWrites(
        writes: <InventoryWrite>[balanceWrite(itemKey: 'ITM-1', balance: 0)],
        sourceId: 'SRC-001',
        date: day,
      );
      expect(set.drafts, isEmpty);
      expect(set.clearedIds, hasLength(1));
    });

    test('★★★ ورصيدٌ موجب بسعرٍ مكتمل ⟵ محوٌ — AT-16', () {
      final PendingEntrySet set = pendingFromBalanceWrites(
        writes: <InventoryWrite>[balanceWrite(itemKey: 'ITM-1', balance: 100)],
        sourceId: 'SRC-001',
        date: day,
        storedPrices: <String, Map<String, Object?>?>{
          'ITM-1': <String, Object?>{
            'distributionPrice': 400,
            'minCashPrice': 380,
          },
        },
      );
      expect(set.drafts, isEmpty);
      expect(set.clearedIds, hasLength(1));
    });

    test('★★ ونصفُ التسعير يُبقي البند — FR-M9-10 «أو»', () {
      final PendingEntrySet set = pendingFromBalanceWrites(
        writes: <InventoryWrite>[balanceWrite(itemKey: 'ITM-1', balance: 100)],
        sourceId: 'SRC-001',
        date: day,
        storedPrices: <String, Map<String, Object?>?>{
          'ITM-1': <String, Object?>{'distributionPrice': 400},
        },
      );
      expect(set.drafts.single.missingField, 'الحد الأدنى');
    });

    test('⛔⛔★★ ورصيدٌ وزنيٌّ كسري يُقرأ كميةً — لا صفراً', () {
      final PendingEntrySet set = pendingFromBalanceWrites(
        writes: <InventoryWrite>[
          balanceWrite(itemKey: 'SCRAP', balance: DecimalValue(0.5)),
        ],
        sourceId: 'SRC-001',
        date: day,
      );
      expect(
        set.drafts,
        hasLength(1),
        reason: 'قراءةُ الوزن بالأعداد الصحيحة وحدها تُخفي بنداً قائماً',
      );
    });

    test('⛔★★ ورصيدٌ ليومٍ آخر يُتخطّى كلياً — GR-31', () {
      final PendingEntrySet set = pendingFromBalanceWrites(
        writes: <InventoryWrite>[
          balanceWrite(itemKey: 'ITM-1', balance: 100, stockDate: yesterday),
        ],
        sourceId: 'SRC-001',
        date: day,
      );
      expect(set.isEmpty, isTrue);
    });

    test('★ وكتاباتٌ من مجموعاتٍ أخرى تُتخطّى', () {
      final PendingEntrySet set = pendingFromBalanceWrites(
        writes: <InventoryWrite>[
          InventoryWrite(
            collectionId: inventoryLedgerCollection,
            documentId: 'MV-1',
            fields: const <String, Object?>{'itemKey': 'ITM-1'},
            updateMask: const <String>[],
          ),
        ],
        sourceId: 'SRC-001',
        date: day,
      );
      expect(set.isEmpty, isTrue);
    });

    group('PendingPricingMode.clearOnEmptyOnly — سعرٌ مجهول', () {
      test('★★ رصيدٌ موجب ⟵ لا شيء إطلاقاً: ⛔ ولا بندٌ بسعرٍ مجهول', () {
        final PendingEntrySet set = pendingFromBalanceWrites(
          writes: <InventoryWrite>[
            balanceWrite(itemKey: 'ITM-1', balance: 100),
          ],
          sourceId: 'SRC-001',
          date: day,
          mode: PendingPricingMode.clearOnEmptyOnly,
        );
        expect(set.isEmpty, isTrue);
      });

      test('★★ ورصيدٌ صفر ⟵ محوٌ كما في الوضع الدقيق', () {
        final PendingEntrySet set = pendingFromBalanceWrites(
          writes: <InventoryWrite>[balanceWrite(itemKey: 'ITM-1', balance: 0)],
          sourceId: 'SRC-001',
          date: day,
          mode: PendingPricingMode.clearOnEmptyOnly,
        );
        expect(set.clearedIds, hasLength(1));
      });
    });
  });

  group('pendingFromPricedLines — AT-16: يختفي فور التسعير', () {
    ValidatedDailyPriceBatch batch({
      Money? distributionPrice,
      Money? minCashPrice,
    }) =>
        ValidatedDailyPriceBatch(
          sourceId: 'SRC-001',
          lines: <ValidatedDailyPriceLine>[
            ValidatedDailyPriceLine(
              itemId: 'ITM-1',
              itemName: 'قات بلدي',
              unit: ItemUnit.piece,
              distributionPrice: distributionPrice,
              minCashPrice: minCashPrice,
            ),
          ],
        );

    test('★★★ تسعيرٌ مكتمل ⟵ محوٌ', () {
      final PendingEntrySet set = pendingFromPricedLines(
        batch: batch(
          distributionPrice: const Money(400),
          minCashPrice: const Money(380),
        ),
        date: day,
      );
      expect(set.drafts, isEmpty);
      expect(set.clearedIds, hasLength(1));
    });

    test('★★ وتفريغُ السعرين ⟵ يعود البند', () {
      final PendingEntrySet set = pendingFromPricedLines(
        batch: batch(),
        date: day,
      );
      expect(set.drafts, hasLength(1));
      expect(set.drafts.single.missingField, 'سعر التوزيع والحد الأدنى');
    });

    test('★ والاسم من السطر المُتحقَّق منه لا من المفتاح', () {
      final PendingEntrySet set =
          pendingFromPricedLines(batch: batch(), date: day);
      expect(set.drafts.single.readableTitle, 'قات بلدي');
    });
  });

  group('pendingFromSackState — M7 من حالة الجونية', () {
    InventoryWrite sackWrite(Map<String, Object?> fields) => InventoryWrite(
          collectionId: sacksCollection,
          documentId: 'SCK-20260830-0001',
          fields: fields,
          updateMask: const <String>[],
        );

    PendingEntrySet build({
      List<InventoryWrite> writes = const <InventoryWrite>[],
      bool storedHasLines = false,
      double storedRemaining = 0,
      bool storedConfirmed = false,
      bool hasTax = false,
      bool isCancelled = false,
    }) =>
        pendingFromSackState(
          writes: writes,
          sackId: 'SCK-20260830-0001',
          sourceId: 'SRC-001',
          stockDate: day,
          storedDisplayName: 'عبد الفتاح - جونية رقم ١',
          storedHasLines: storedHasLines,
          storedRemainingKilograms: storedRemaining,
          storedLostWeightConfirmed: storedConfirmed,
          hasTax: hasTax,
          isCancelled: isCancelled,
        );

    test('★★★ E-06: بلا ضريبة ولا أنواع ⟵ بندان', () {
      expect(build().drafts, hasLength(2));
    });

    test('★★ والكتابةُ تُغطّي المخزَّن — سطورٌ كُتبت الآن تُزيل بندها', () {
      final PendingEntrySet set = build(
        writes: <InventoryWrite>[
          sackWrite(<String, Object?>{
            'lines': <Object?>[<String, Object?>{'itemId': 'ITM-1'}],
          }),
        ],
      );
      expect(
        set.drafts.map((PendingEntryDraft d) => d.field),
        <PendingMissingField>[PendingMissingField.sackTax],
      );
    });

    test('★★★ E-10: متبقٍّ غير مؤكَّد ⟵ بندُ الوزن الضائع', () {
      final PendingEntrySet set = build(
        storedHasLines: true,
        hasTax: true,
        writes: <InventoryWrite>[
          sackWrite(<String, Object?>{
            'remainingWeight': DecimalValue(3.5),
            'lostWeightConfirmed': false,
          }),
        ],
      );
      expect(
        set.drafts.single.field,
        PendingMissingField.sackLostWeight,
      );
    });

    test('★★★ وتأكيدُه الصريح يُزيل البند — BR-M7-12', () {
      final PendingEntrySet set = build(
        storedHasLines: true,
        hasTax: true,
        writes: <InventoryWrite>[
          sackWrite(<String, Object?>{
            'remainingWeight': DecimalValue(3.5),
            'lostWeightConfirmed': true,
          }),
        ],
      );
      expect(set.drafts, isEmpty);
      expect(set.clearedIds, hasLength(3));
    });

    test('★★ والهامش من طبقة النطاق — متبقٍّ 1e-15 مفسَّرٌ بالكامل', () {
      final PendingEntrySet set = build(
        storedHasLines: true,
        hasTax: true,
        writes: <InventoryWrite>[
          sackWrite(<String, Object?>{
            'remainingWeight': DecimalValue(1e-15),
            'lostWeightConfirmed': false,
          }),
        ],
      );
      expect(set.drafts, isEmpty);
    });

    test('⛔⛔★★ والإلغاء المكتوب الآن يُخلي البنود — GR-06', () {
      final PendingEntrySet set = build(
        writes: <InventoryWrite>[
          sackWrite(<String, Object?>{'status': SackStatus.cancelled.name}),
        ],
      );
      expect(set.drafts, isEmpty);
      expect(set.clearedIds, hasLength(3));
    });

    test('★ والاسم الظاهر المُعدَّل يصل العنوان المقروء', () {
      final PendingEntrySet set = build(
        writes: <InventoryWrite>[
          sackWrite(<String, Object?>{'displayName': 'اسمٌ جديد'}),
        ],
      );
      expect(set.drafts.first.readableTitle, 'اسمٌ جديد');
    });

    test('★ وبلا كتابةٍ للمستند تُقرأ الحالة المخزَّنة وحدها', () {
      final PendingEntrySet set = build(
        storedHasLines: true,
        hasTax: true,
        storedRemaining: 2,
        storedConfirmed: false,
      );
      expect(set.drafts.single.field, PendingMissingField.sackLostWeight);
    });
  });
}

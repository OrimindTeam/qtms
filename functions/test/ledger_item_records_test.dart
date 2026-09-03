/// ★★★ **المفتاح المركّب نوعٌ لا سجل له** — اختبارُ ارتداد `DEBT-55`.
///
/// ⛔⛔★★★ **ولماذا ملفٌّ مستقل لطبقة المعالِج:** `daily_pricing_test.dart`
/// يختبر **التخطيط الخالص** بخريطة أنواعٍ **مبنيّةٍ في الاختبار نفسه** —
/// ⟵ **فلم يرَ قطُّ أن المعالِج يبنيها من `items/{itemKey}` وحدها**،
/// ⛔ **وسقط كلُّ سطرِ جونيةٍ حيّاً بينما 1271 اختباراً أخضر.**
/// ★★ **وهو درسُ `DEBT-37` حرفياً: اختبارُ الطبقة لا يُغني عن اختبار ما
/// يعبر بينها.**
library;

import 'package:qtms_domain/qtms_domain.dart';
import 'package:qtms_functions/src/audited_transaction.dart';
import 'package:qtms_functions/src/inventory.dart' show ItemRead;
import 'package:qtms_functions/src/inventory_handler.dart'
    show ledgerSackIds, withLedgerItems;
import 'package:test/test.dart';

const String sourceA = 'SRC-001';
const String compositeKey = 'سلة - جونية رقم 1';
const String scrapKey = 'السكرب - جونية رقم 1';

/// حركةُ دفترٍ كما تُقرأ فعلاً — ★ **بحقول الإنتاج نفسها** (`inventory-ledger.md`).
Map<String, Object?> ledgerDocument({
  String itemKey = compositeKey,
  String itemName = 'سلة',
  String unit = 'piece',
  bool cancelled = false,
  // ★★ **ومرجعُ الجونية حقلٌ حقيقيٌّ في الحركة** — `ADR-0007` ⑤ · `sackId`.
  String? sackId,
}) =>
    <String, Object?>{
      'sourceId': sourceA,
      'itemKey': itemKey,
      'itemName': itemName,
      'unit': unit,
      'direction': 'incoming',
      'quantity': 250,
      'isCancelled': cancelled,
      'sourceDocType': 'sack',
      'sackId': ?sackId,
    };

TransactionReads readsOf(Map<String, List<Map<String, Object?>>> matched) =>
    TransactionReads(
      documents: const <String, Map<String, Object?>?>{},
      queries: <String, List<String>>{
        for (final MapEntry<String, List<Map<String, Object?>>> entry
            in matched.entries)
          entry.key: <String>[
            for (int i = 0; i < entry.value.length; i++) 'mv-${entry.key}-$i',
          ],
      },
      queryDocuments: matched,
    );

void main() {
  group('★★★ `DEBT-55` — الاسم المركّب يُسعَّر ويُوزَّع', () {
    test('✅★★ مفتاحٌ مركّبٌ بلا سجل نوع يُستكمَل من الدفتر', () {
      final Map<String, ItemRead> completed = withLedgerItems(
        const <String, ItemRead>{},
        reads: readsOf(<String, List<Map<String, Object?>>>{
          compositeKey: <Map<String, Object?>>[ledgerDocument()],
        }),
        itemKeys: const <String>[compositeKey],
        sourceId: sourceA,
      );

      final ItemRead? item = completed[compositeKey];
      expect(item, isNotNull, reason: '⛔ غيابُه هو عينُ الرفض `400` حيّاً');
      expect(item!.itemId, compositeKey);
      // ★ الاسم من الدفتر ⛔ لا من الحمولة.
      expect(item.name, 'سلة');
      // ★ **الوحدة المخزَّنة لا المُرسَلة** — `FR-M9-06`.
      expect(item.unit, ItemUnit.piece);
      expect(item.isActive, isTrue);
      // ★ الاستعلام قيّد المصدر ⟵ فالانتماء مُثبَت لا مفترَض.
      expect(item.sourceIds, <String>[sourceA]);
    });

    test('✅★ والسكرب بالكيلوجرام — ⛔ لا يُقرأ حبّاتٍ', () {
      final Map<String, ItemRead> completed = withLedgerItems(
        const <String, ItemRead>{},
        reads: readsOf(<String, List<Map<String, Object?>>>{
          scrapKey: <Map<String, Object?>>[
            ledgerDocument(
              itemKey: scrapKey,
              itemName: scrapKey,
              unit: 'kilogram',
            ),
          ],
        }),
        itemKeys: const <String>[scrapKey],
        sourceId: sourceA,
      );

      expect(completed[scrapKey]!.unit, ItemUnit.kilogram);
    });

    test('⛔★★ ولا هويةَ من حركةٍ ملغاة — `A-14`', () {
      final Map<String, ItemRead> completed = withLedgerItems(
        const <String, ItemRead>{},
        reads: readsOf(<String, List<Map<String, Object?>>>{
          compositeKey: <Map<String, Object?>>[
            ledgerDocument(cancelled: true),
          ],
        }),
        itemKeys: const <String>[compositeKey],
        sourceId: sourceA,
      );

      expect(completed, isEmpty);
    });

    test('⛔★★★ وسجلُّ النوع القائم لا يُستبدَل بالدفتر', () {
      const ItemRead stored = ItemRead(
        itemId: 'ITM-0002',
        name: 'سلة',
        unit: ItemUnit.piece,
        isActive: false,
        sourceIds: <String>[sourceA, 'SRC-002'],
      );

      final Map<String, ItemRead> completed = withLedgerItems(
        const <String, ItemRead>{'ITM-0002': stored},
        reads: readsOf(<String, List<Map<String, Object?>>>{
          'ITM-0002': <Map<String, Object?>>[
            ledgerDocument(itemKey: 'ITM-0002'),
          ],
        }),
        itemKeys: const <String>['ITM-0002'],
        sourceId: sourceA,
      );

      // ⛔ **ولو استُبدل لعاد نوعٌ معطَّلٌ نشطاً** — ★ وهو تصعيدُ حالة.
      expect(completed['ITM-0002']!.isActive, isFalse);
      expect(completed['ITM-0002']!.sourceIds, stored.sourceIds);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // ⛔⛔★★★ [`DEBT-86`] — مرجعُ الجونية يُقاس من الدفتر لا يُصدَّق من الحمولة
  // ═══════════════════════════════════════════════════════════════════════
  //
  // ⚠️⚠️★★★ **ولماذا لزم هذا:** ★ **التطبيق لم يُرسِل `sackId` في أي سطرٍ
  //   قطّ** — ⛔ **ولا حقلَ له في أي شاشة**، ⟹ **فما إن صار المفتاحُ المركّب
  //   قابلاً للاختيار ([`DEBT-86`]) حتى صارت كلُّ حركةِ خروجٍ منه بلا مرجعِ
  //   جونية** ⟵ **فتسقط الجونيةُ من احتساب إيرادها بصمت** (`FR-M10-14` ·
  //   `A-13`): ⛔ **بلا خطأٍ يُرفَع ولا رقمٍ يبدو شاذاً.**
  group('⛔⛔★★★ `DEBT-86` — `sackId` من الدفتر', () {
    test('✅★★★ مفتاحٌ مركّبٌ ⟵ مرجعُ جونيته من حركة الدخول', () {
      final Map<String, String> sackIds = ledgerSackIds(
        reads: readsOf(<String, List<Map<String, Object?>>>{
          compositeKey: <Map<String, Object?>>[
            ledgerDocument(sackId: 'SCK-20260902-0001'),
          ],
        }),
        itemKeys: const <String>[compositeKey],
      );

      expect(sackIds[compositeKey], 'SCK-20260902-0001');
    });

    test('★★ ومفتاحٌ مجرَّدٌ (وارد عدداً) يبقى بلا مرجع — BR-M6-10', () {
      // ⛔★★ **وغيابُه هنا هو الصواب** — ★ **الوارد عدداً لا يدخل احتساب
      //    سعر أي جونية** (`ADR-0007` القاعدة 1)، ⟵ **ومرجعٌ مخترَعٌ له
      //    كان يُضيف إيراداً لجونيةٍ لم تُخرِجه.**
      final Map<String, String> sackIds = ledgerSackIds(
        reads: readsOf(<String, List<Map<String, Object?>>>{
          'ITM-0002': <Map<String, Object?>>[
            ledgerDocument(itemKey: 'ITM-0002'),
          ],
        }),
        itemKeys: const <String>['ITM-0002'],
      );

      expect(sackIds.containsKey('ITM-0002'), isFalse);
    });

    test('⛔★★ ولا يُشتقّ من حركةٍ ملغاة — A-14', () {
      // ★ **بنفس حارس [withLedgerItems]** — ⟵ **الملغاةُ ليست مصدرَ هوية
      //   كما أنها ليست مصدرَ رصيد.**
      final Map<String, String> sackIds = ledgerSackIds(
        reads: readsOf(<String, List<Map<String, Object?>>>{
          compositeKey: <Map<String, Object?>>[
            ledgerDocument(sackId: 'SCK-20260902-0009', cancelled: true),
            ledgerDocument(sackId: 'SCK-20260902-0001'),
          ],
        }),
        itemKeys: const <String>[compositeKey],
      );

      // ★ **والحيّةُ وحدَها تُقرأ** — ⛔ **ولو سبقتها ملغاةٌ في الترتيب.**
      expect(sackIds[compositeKey], 'SCK-20260902-0001');
    });

    test('★ ومفتاحٌ بلا حركةٍ حاملةٍ للمرجع يبقى غائباً — ⛔ لا نصّاً فارغاً',
        () {
      final Map<String, String> sackIds = ledgerSackIds(
        reads: readsOf(<String, List<Map<String, Object?>>>{
          compositeKey: <Map<String, Object?>>[ledgerDocument()],
        }),
        itemKeys: const <String>[compositeKey],
      );

      expect(sackIds, isEmpty);
    });
  });
}

/// ★★ اختبارُ ارتدادٍ لسجل حركة النوع — تقرير `2026-08-26-run2` · بند التدقيق ①.
///
/// ⛔⛔★★ **العطلُ الذي يحرسه هذا الملف عطلٌ وقع فعلاً** (تقرير 2026-08-26 §6 ⓵):
/// `firestore_inventory_directory.dart` **كان يحفر `SourceDocumentType.countedIntake`**
/// في كل حركة يقرؤها. ★ **وكان صحيحاً يوم كُتب** — لم يكن للدفتر كاتبٌ غيره.
/// ⟵ **ثم جعلت `WU-004` الجونيةَ تكتب في الدفتر نفسه**، ⛔ **فصار يَسِم حركات
/// الجواني «وارداً عدداً»**: ★ **خطأ عرضٍ صامت لا يُسقِط شيئاً ولا يُنتج رسالة.**
///
/// ⚠️⚠️ **ولماذا اختبارٌ سلوكي لا تغطيةٌ نصية:** `CLAUDE.md` يقطع بأن «التغطية
/// تُثبت أن الشرط **مذكور** لا أنه **صحيح**» — ⟵ ★ **فالحراسةُ هنا على
/// المخرَج نفسه**، ⛔ **لا على وجود كلمةٍ في المصدر.**
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:qtms/capabilities/inventory/infrastructure/firestore_inventory_directory.dart';
import 'package:qtms_domain/qtms_domain.dart';

/// مستندُ حركةٍ خام — ★ **الحدُّ الأدنى الذي يكتبه الدفتر فعلاً.**
Map<String, dynamic> _doc({Object? sourceDocType}) => <String, dynamic>{
      'itemKey': 'item-1',
      'itemName': 'عتود',
      'direction': MovementDirection.incoming.name,
      'unit': ItemUnit.piece.name,
      'quantity': 10,
      'balanceAfter': 10,
      // ★ **والغيابُ يُحاكي حركاتِ `WU-003`** المكتوبةَ قبل وجود الحقل.
      'sourceDocType': ?sourceDocType,
      'sourceDocNumber': 'SCK-000001',
    };

void main() {
  group('★★ سجل حركة النوع — نوعُ المستند يُقرأ من الحركة لا يُفترَض', () {
    test(
      '⛔⛔ الارتداد الأصلي: حركةُ جونيةٍ تُقرأ `sack` — ⛔ لا «وارداً عدداً»',
      () {
        final StockMovementCard card = FirestoreInventoryDirectory.movementOf(
          'mv-1',
          _doc(sourceDocType: SourceDocumentType.sack.name),
        );

        expect(
          card.sourceDocumentType,
          SourceDocumentType.sack,
          reason: '★ هذا حرفياً العطل المرصود في `WU-004` — ⛔ وحفرُ الثابت '
              'يُعيده صامتاً',
        );
      },
    );

    test('★ وكلُّ قيمة في المعجم تُقرأ قيمتَها هي — ⛔ ولا واحدة تنزلق', () {
      for (final SourceDocumentType type in SourceDocumentType.values) {
        final StockMovementCard card = FirestoreInventoryDirectory.movementOf(
          'mv-${type.name}',
          _doc(sourceDocType: type.name),
        );
        expect(card.sourceDocumentType, type, reason: '★ النوع ${type.name}');
      }
    });

    test(
      '★★ والغائبُ يعود «وارداً عدداً» — ★ الافتراضُ الآمن لأقدم كاتبٍ للدفتر',
      () {
        // ⚠️ **حركاتُ `WU-003` كُتبت قبل وجود الحقل أصلاً** — ⟵ **وقراءتُها
        //   بالأحدث كانت ستَسِمها خطأً بدل أن تُبقيها على حقيقتها.**
        final StockMovementCard card =
            FirestoreInventoryDirectory.movementOf('mv-legacy', _doc());

        expect(card.sourceDocumentType, SourceDocumentType.countedIntake);
      },
    );

    test('★ وقيمةٌ مجهولة لا تُسقِط السطر — تعود للافتراض الآمن', () {
      final StockMovementCard card = FirestoreInventoryDirectory.movementOf(
        'mv-junk',
        _doc(sourceDocType: 'zzNotAType'),
      );

      expect(card.sourceDocumentType, SourceDocumentType.countedIntake);
    });

    test('★ ورقمُ المستند يُقرأ من الحركة نفسها كذلك', () {
      final StockMovementCard card = FirestoreInventoryDirectory.movementOf(
        'mv-2',
        _doc(sourceDocType: SourceDocumentType.sack.name),
      );

      expect(card.sourceDocumentNumber, 'SCK-000001');
      expect(card.movementId, 'mv-2');
    });
  });
}

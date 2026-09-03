/// ★★★ **اسمُ النوع مع وزن الحبة** — `AM-012` §4.4.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:qtms/core/ui/item_labels.dart';

void main() {
  group('★★★ `AM-012` §4.4 — إظهار وزن الحبة بجانب اسم النوع', () {
    test('★ الحالةُ المعتمدة من الطلب حرفياً — «بطّوه وزن (200 جرام)»', () {
      expect(
        itemDisplayName(
          'بطّوه',
          showPieceWeight: true,
          pieceWeightGrams: 200,
        ),
        'بطّوه وزن (200 جرام)',
      );
    });

    test('⛔ ومعطَّلاً يظهر الاسمُ وحدَه — «بطّوه»', () {
      expect(
        itemDisplayName(
          'بطّوه',
          showPieceWeight: false,
          pieceWeightGrams: 200,
        ),
        'بطّوه',
      );
    });

    test('⛔⛔★★★ ولا يُستنتَج وزنٌ غائب — الغائبُ يُسقِط اللاحقة وحدها', () {
      // ★★★ **`FR-M7-14` · `E-08`:** ⛔ **ولا يُستنتَج وزنُ حبةٍ من شيء
      //    إطلاقاً** — ⟵ **والنوعُ العددي لا وزنَ حبةٍ له أصلاً** (`E-09`).
      expect(
        itemDisplayName('عود', showPieceWeight: true),
        'عود',
      );
      expect(
        itemDisplayName('عود', showPieceWeight: true, pieceWeightGrams: null),
        'عود',
      );
    });

    test('⛔★★ وصفرٌ أو سالبٌ ليس وزناً — ⛔ ولا «وزن (0 جرام)»', () {
      // ★ **نفسُ حارس `validateItem`** (`FR-M5-02`): ⟵ **والصفرُ يُنتج وزناً
      //    كلياً صفرياً لكل جونية** ⛔ **فسادُ حسابٍ صامت.**
      expect(
        itemDisplayName('س', showPieceWeight: true, pieceWeightGrams: 0),
        'س',
      );
      expect(
        itemDisplayName('س', showPieceWeight: true, pieceWeightGrams: -5),
        'س',
      );
      expect(
        itemDisplayName(
          'س',
          showPieceWeight: true,
          pieceWeightGrams: double.nan,
        ),
        'س',
      );
    });

    test('★ والصحيحُ بلا كسرٍ صفريّ — «200» لا «200.0»', () {
      expect(
        itemDisplayName('ب', showPieceWeight: true, pieceWeightGrams: 200.0),
        'ب وزن (200 جرام)',
      );
    });

    test('★ والكسرُ الحقيقي يبقى — «12.5»', () {
      expect(
        itemDisplayName('ب', showPieceWeight: true, pieceWeightGrams: 12.5),
        'ب وزن (12.5 جرام)',
      );
    });
  });
}

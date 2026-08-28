/// فكّ قيم Firestore **كما تُنتجها `googleapis` فعلاً** — ⛔ لا كما نتخيّلها.
///
/// ⚠️⚠️ **اختبارٌ وُلد من عطلٍ حقيقي في الإنتاج التجريبي (2026-08-25):**
/// كل عملية سحابية كانت تقرأ **صفر صلاحيات** من بطاقة تحمل تسعاً — ⟵
/// **فرُفض كل استدعاء إداري بـ`ERR_AUTH_001`** بينما البطاقة سليمة تماماً.
///
/// ★★ **والسبب فحصُ نوعٍ أضيق مما تُنتجه المكتبة:** `Value.toJson()` يُعيد
/// الخرائط المتداخلة بأنواع مثل `Map<String, Map<String, dynamic>>`، ⟵
/// **و`is Map<String, Object?>` كان يمرّ، بينما الفحص على الطبقة الداخلية
/// يسقط** فيعود `null` صامتاً. ⛔ **والصمت هو الكارثة**: لا استثناء ولا سجل،
/// **وصلاحيةٌ ممنوحة تُقرأ غير ممنوحة.**
///
/// ★ **ولذلك يبني هذا الاختبار القيمة بـ`googleapis` نفسها** ⛔ **لا بخريطة
/// يدوية** — فخريطةٌ نكتبها بأيدينا تُثبت ما نظنّه لا ما يقع.
library;

import 'package:googleapis/firestore/v1.dart' as firestore;
import 'package:qtms_functions/src/firestore_decode.dart';
import 'package:test/test.dart';

/// يبني قيمة **كما تصل من الشبكة فعلاً** ثم يفكّها بالمسار المعتمد.
Object? decodeAsRead(Map<String, Object?> wireJson) =>
    decodeTypedValue(firestore.Value.fromJson(wireJson));

void main() {
  group('★★★ خريطة الصلاحيات — العطل الذي رُصد بالنشر لا بالاختبار', () {
    test('⛔★★★ خريطة `permissions` تُفكّ إلى قيمها ⛔ لا إلى null', () {
      final Map<String, Object?> wire = <String, Object?>{
        'mapValue': <String, Object?>{
          'fields': <String, Object?>{
            'roleWrite': <String, Object?>{'booleanValue': true},
            'roleDelete': <String, Object?>{'booleanValue': true},
            'userView': <String, Object?>{'booleanValue': false},
          },
        },
      };

      final Object? decoded = decodeAsRead(wire);

      // ⛔★★★ **هذا السطر هو العطل نفسه** — كان `decoded` يساوي `null`.
      expect(decoded, isNotNull, reason: 'خريطة الصلاحيات فُكّت إلى null');
      expect(decoded, isA<Map<String, Object?>>());
      final Map<String, Object?> map = decoded! as Map<String, Object?>;
      expect(map['roleWrite'], isTrue);
      expect(map['roleDelete'], isTrue);
      expect(map['userView'], isFalse);
    });

    test('★★ ومستندٌ كامل بحقل خريطة يُفكّ بكل حقوله', () {
      final Map<String, firestore.Value> fields = <String, firestore.Value>{
        'isActive': firestore.Value.fromJson(
          <String, Object?>{'booleanValue': true},
        ),
        'permissions': firestore.Value.fromJson(<String, Object?>{
          'mapValue': <String, Object?>{
            'fields': <String, Object?>{
              'sackView': <String, Object?>{'booleanValue': true},
            },
          },
        }),
      };

      final Map<String, Object?> card = decodeDocumentFields(fields);

      expect(card['isActive'], isTrue);
      // ★ **الحقل موجود بمفتاحه** — ⚠️ **وكان موجوداً بقيمة `null`**، ⟵
      //   **فبدا المستند سليماً في السجل والصلاحيةُ مفقودة.**
      expect(card.keys, containsAll(<String>['isActive', 'permissions']));
      expect(card['permissions'], isNotNull);
      expect((card['permissions']! as Map<String, Object?>)['sackView'], isTrue);
    });

    test('★ ومصفوفةٌ متداخلة تُفكّ كذلك — نفس صنف العطل', () {
      final Map<String, Object?> wire = <String, Object?>{
        'arrayValue': <String, Object?>{
          'values': <Object?>[
            <String, Object?>{'stringValue': 'SRC-001'},
            <String, Object?>{'stringValue': 'SRC-002'},
          ],
        },
      };
      expect(
        decodeAsRead(wire),
        <String>['SRC-001', 'SRC-002'],
      );
    });

    test('★ وخريطةٌ داخل مصفوفة داخل خريطة — أعمق مستوى يُتوقَّع', () {
      final Map<String, Object?> wire = <String, Object?>{
        'mapValue': <String, Object?>{
          'fields': <String, Object?>{
            'scope': <String, Object?>{
              'arrayValue': <String, Object?>{
                'values': <Object?>[
                  <String, Object?>{'stringValue': 'SRC-9'},
                ],
              },
            },
          },
        },
      };
      final Object? decoded = decodeAsRead(wire);
      expect((decoded! as Map<String, Object?>)['scope'], <String>['SRC-9']);
    });
  });
}

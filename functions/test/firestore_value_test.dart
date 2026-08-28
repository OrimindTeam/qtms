import 'package:qtms_functions/src/firestore_value.dart';
import 'package:test/test.dart';

void main() {
  group('فكّ ترميز قيم قاعدة البيانات', () {
    test('العدد الصحيح يصل نصّاً ويُفكّ عدداً — لا null صامتاً', () {
      // ⚠️ هذا هو المزلق الحقيقي: الواجهة تحمل int64 نصّاً.
      expect(decodeFirestoreValue(<String, Object?>{'integerValue': '42'}), 42);
      expect(
        decodeFirestoreValue(<String, Object?>{'integerValue': '-7'}),
        -7,
      );
      // عدد أكبر مما يتّسع له رقم JSON بدقة — يجب أن يبقى دقيقاً.
      expect(
        decodeFirestoreValue(<String, Object?>{
          'integerValue': '9007199254740993',
        }),
        9007199254740993,
      );
    });

    test('الأنواع البسيطة', () {
      expect(
        decodeFirestoreValue(<String, Object?>{'stringValue': 'SRC-001'}),
        'SRC-001',
      );
      expect(
        decodeFirestoreValue(<String, Object?>{'booleanValue': true}),
        true,
      );
      expect(decodeFirestoreValue(<String, Object?>{'nullValue': null}), isNull);
      expect(
        decodeFirestoreValue(<String, Object?>{
          'timestampValue': '2026-08-22T10:15:30Z',
        }),
        DateTime.utc(2026, 8, 22, 10, 15, 30),
      );
    });

    test('المصفوفة والخريطة المتداخلتان', () {
      final Object? decoded = decodeFirestoreValue(<String, Object?>{
        'mapValue': <String, Object?>{
          'fields': <String, Object?>{
            'itemName': <String, Object?>{'stringValue': 'قات'},
            'quantity': <String, Object?>{'integerValue': '3'},
            'tags': <String, Object?>{
              'arrayValue': <String, Object?>{
                'values': <Object?>[
                  <String, Object?>{'stringValue': 'أ'},
                  <String, Object?>{'stringValue': 'ب'},
                ],
              },
            },
          },
        },
      });

      expect(decoded, <String, Object?>{
        'itemName': 'قات',
        'quantity': 3,
        'tags': <Object?>['أ', 'ب'],
      });
    });

    test('مصفوفة فارغة أو غائبة لا تُسقط الفكّ', () {
      expect(
        decodeFirestoreValue(<String, Object?>{
          'arrayValue': <String, Object?>{},
        }),
        <Object?>[],
      );
      expect(decodeFirestoreFields(null), <String, Object?>{});
    });
  });

  group('ترميز القيم للكتابة', () {
    test('العدد الصحيح يُرسَل نصّاً — وإلا صار doubleValue عند الخادم', () {
      expect(
        encodeFirestoreValue(42),
        <String, Object?>{'integerValue': '42'},
      );
    });

    test('ADR-0015 · coding-standards §2.1 · §5 البند 1: الفاصلة العائمة مرفوضة', () {
      // ★ اختبار «لا فاصلة عائمة» الصريح — test-strategy §3 القاعدة 4.
      //   والمبلغ عدد صحيح بالريال — لا نوع عشري ولا «أصغر وحدة» (ADR-0015).
      expect(() => encodeFirestoreValue(1.5), throwsArgumentError);
      expect(() => encodeFirestoreValue(0.0), throwsArgumentError);
    });

    test('ADR-0015: رسالة الرفض تسمّي القرار الحاكم لا سياسة ملغاة', () {
      // ★ حارس ضد عودة صياغة «أصغر وحدة» — وهي البديل الذي رفضه ADR-0015.
      expect(
        () => encodeFirestoreValue(617.5),
        throwsA(
          isA<ArgumentError>().having(
            (ArgumentError e) => e.message.toString(),
            'message',
            allOf(contains('ADR-0015'), isNot(contains('أصغر وحدة'))),
          ),
        ),
      );
    });

    test('نوع غير مدعوم يُرمى ولا يُحوَّل صامتاً', () {
      expect(() => encodeFirestoreValue(Object()), throwsArgumentError);
      expect(() => encodeFirestoreValue(Duration.zero), throwsArgumentError);
    });

    test('الترميز والفكّ رحلة ذهاب وعودة بلا فقدان', () {
      final Map<String, Object?> original = <String, Object?>{
        'sourceId': 'SRC-001',
        'sequence': 7,
        'isActive': true,
        'occurredAt': DateTime.utc(2026, 8, 22, 10, 15, 30),
        'changedFieldPaths': <Object?>['name', 'phone'],
        'nested': <String, Object?>{'count': 3},
        'missing': null,
      };

      expect(
        decodeFirestoreFields(encodeFirestoreFields(original)),
        original,
      );
    });
  });
}

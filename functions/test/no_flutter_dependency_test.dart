@TestOn('vm')
library;

import 'dart:io';

import 'package:test/test.dart';

/// حارس آلي على **القاعدة 1 من `ADR-0012`** ونصّ `ADR-0009` ②.
///
/// ★ **لماذا اختبار وليس مراجعة:** لأن الاعتمادية على `flutter` قد تتسرّب
/// **غير مباشرة** — حزمة نطاق تستورد حزمة صغيرة تعتمد `flutter` بدورها. عندها
/// يبدو `pubspec.yaml` نظيفاً تماماً بينما **تفشل الحاوية عند النشر**، وهو
/// أسوأ وقت لاكتشاف ذلك. هذا الاختبار يقرأ **الرسم المحلول كاملاً**
/// (`pubspec.lock`) فيرى غير المباشر كما يرى المباشر.
void main() {
  group('ADR-0012 القاعدة 1: لا `flutter` في مسار العمليات السحابية', () {
    test('الرسم المحلول لـ`functions/` خالٍ من أي حزمة Flutter', () {
      final File lock = File('pubspec.lock');
      expect(lock.existsSync(), isTrue,
          reason: 'شغّل `dart pub get` في `functions/` أولاً');

      final Set<String> locked = _lockedPackageNames(lock);

      // ★ حارس على الحارس: لو انكسر تحليل `pubspec.lock` لعاد بمجموعة فارغة
      //   **فنجح الفحص أدناه دائماً بلا أن يفحص شيئاً**. هذا السطر يمنع ذلك.
      expect(locked, contains('functions_framework'));
      expect(locked, contains('qtms_domain'));
      expect(locked.length, greaterThan(10));

      final List<String> offenders = locked
          .where((String name) =>
              name == 'flutter' ||
              name == 'flutter_test' ||
              name == 'flutter_localizations' ||
              name.startsWith('flutter_'))
          .toList();

      expect(
        offenders,
        isEmpty,
        reason: '⛔ تسرّبت اعتمادية Flutter إلى مسار السحابة: $offenders — '
            'وستفشل الحاوية عند البناء بـDart SDK وحده.',
      );
    });

    test('حزمة النطاق نفسها لا تعلن `flutter` اعتماديةً', () {
      final File pubspec = File('../packages/qtms_domain/pubspec.yaml');
      expect(pubspec.existsSync(), isTrue);

      final String text = pubspec.readAsStringSync();
      expect(text, isNot(contains('sdk: flutter')));
      expect(text, isNot(contains('flutter_lints')));
    });

    test('الحاوية تُبنى من صورة Dart لا صورة Flutter', () {
      final String dockerfile = File('Dockerfile').readAsStringSync();
      expect(dockerfile, contains('FROM dart:'));
      expect(dockerfile.toLowerCase(), isNot(contains('from flutter')));
    });
  });
}

/// يستخرج أسماء الحزم من `pubspec.lock` بلا محلّل YAML كامل — الملف مولَّد
/// بصيغة ثابتة، وأسماء الحزم وحدها هي المفاتيح ذات المسافة البادئة المزدوجة.
Set<String> _lockedPackageNames(File lock) {
  final Set<String> names = <String>{};
  bool insidePackages = false;
  for (final String line in lock.readAsLinesSync()) {
    if (line.startsWith('packages:')) {
      insidePackages = true;
      continue;
    }
    if (insidePackages && line.isNotEmpty && !line.startsWith(' ')) break;
    if (!insidePackages) continue;
    final RegExpMatch? match =
        RegExp(r'^  ([a-z0-9_]+):\s*$').firstMatch(line);
    if (match != null) names.add(match.group(1)!);
  }
  return names;
}

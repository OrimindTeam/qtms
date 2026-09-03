/// ★★ **حارسُ رقم الإصدار** — ⛔ **ولا مصدرَي حقيقةٍ للإصدار.**
///
/// ★ **يقرأ `pubspec.yaml` نفسَه ويقارن** — ⟵ **فتعديلُ الإصدار هناك بلا
/// تعديلٍ في [appVersion] يُسقِط الاختبار**، ★ **والعكسُ كذلك.** ⛔ **وهذا
/// ما يُغني عن حزمةِ قراءةِ بياناتِ الحزمة وقتَ التشغيل** — ★ **نفسُ أسلوب
/// حارسِ توكنز `primary` وحارسِ أوزان الخط في هذا المشروع.**
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qtms/core/app_version.dart';

void main() {
  test('★★ appVersion مطابقٌ لـ`pubspec.yaml` حرفياً ⛔ بلا رقم البناء', () {
    final String pubspec = File('pubspec.yaml').readAsStringSync();
    final RegExpMatch? match =
        RegExp(r'^version:\s*([0-9]+\.[0-9]+\.[0-9]+)\+?\d*\s*$', multiLine: true)
            .firstMatch(pubspec);

    expect(match, isNotNull, reason: '⛔ لا سطرَ إصدارٍ في `pubspec.yaml`.');
    expect(
      appVersion,
      match!.group(1),
      reason: '⛔ الإصدارُ المعروض يخالف `pubspec.yaml` — مصدرُ حقيقةٍ ثانٍ.',
    );
  });

  test('★ وسطرُ العرض يحمل الرقمَ نفسَه', () {
    expect(appVersionLabel, contains(appVersion));
  });
}

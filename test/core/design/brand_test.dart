/// هوية المنتج — ★ **حارس المصدر الواحد للاسم الظاهر ولشعار العميل**
/// (`AM-002`).
///
/// ⚠️★★ **ولماذا حارس ملفّي لا اختبار ويدجت وحده:** الاسم يعيش في مكانين
/// **لا ثالث لهما**: `appDisplayName` في Dart (مبدّل المهام · عنوان النافذة)
/// و`app_name` في مورد أندرويد (شاشة الجهاز). ★ **ولا اختبار سلوكي واحد
/// يفشل إن افترقا** — يبقى التطبيق باسمين، ويُكتشَف الأمر على جهاز المالك.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qtms/core/design/brand.dart';

/// يقرأ قيمة `<string name="app_name">` من مورد أندرويد.
///
/// ⛔ **بلا `package:path`** — غير مُعلَنة في `pubspec.yaml`
/// (`depend_on_referenced_packages: error`)، ★ **و`Uri.resolve` محايد
/// للمنصّة أصلاً** (`implementation-playbook` §4 البند 6).
String readAndroidAppName(String relativePath) {
  final File file = File.fromUri(Directory.current.uri.resolve(relativePath));
  expect(file.existsSync(), isTrue, reason: 'المورد غائب: $relativePath');
  final RegExpMatch? match = RegExp(
    r'<string\s+name="app_name">(.*?)</string>',
    dotAll: true,
  ).firstMatch(file.readAsStringSync());
  expect(match, isNotNull, reason: 'لا مفتاح app_name في $relativePath');
  return match!.group(1)!.trim();
}

void main() {
  const String mainStrings = 'android/app/src/main/res/values/strings.xml';
  const String stagingStrings =
      'android/app/src/staging/res/values/strings.xml';

  test('★★ AM-002: اسمُ التطبيق واحد في Dart وفي مورد أندرويد حرفياً', () {
    expect(readAndroidAppName(mainStrings), appDisplayName);
  });

  test('⛔★★ AM-002: ولا أثر للاسم المؤقت «QTMS» في الاسم الظاهر', () {
    // ★ الاسم الظاهر هوية العميل حصراً — ⛔ ولا بادئة تقنية
    //   (`developer-identity.md` §1).
    expect(appDisplayName, 'وكالة محمد المحامي');
    expect(appDisplayName.toUpperCase().contains('QTMS'), isFalse);
  });

  test('🔶★ والنكهة التجريبية تُميَّز بالاسم على الجهاز نفسه', () {
    final String staging = readAndroidAppName(stagingStrings);
    // ⛔ لا يساوي الإنتاجي — وإلا فالتطبيقان لا يُفرَّقان بعد التثبيت معاً.
    expect(staging, isNot(appDisplayName));
    // ★ ويبقى هوية العميل نفسها لا اسماً آخر.
    expect(staging.startsWith(appDisplayName), isTrue);
  });

  test('★ ومسار الشعار يشير إلى أصل مُعلَن فعلاً في الحزمة', () {
    final File asset =
        File.fromUri(Directory.current.uri.resolve(brandLogoAsset));
    expect(asset.existsSync(), isTrue, reason: 'أصل الشعار غائب');

    // ★ ⟵ ومطابقٌ بايتاً ببايت لأصله المعتمد في `RF-001`
    //   ⛔ فلا تفترق النسخة التنفيذية عن الأصل بتحرير يدوي.
    final File source = File.fromUri(
      Directory.current.uri.resolve('docs/19-assets/icons/app-icon-foreground.png'),
    );
    expect(asset.readAsBytesSync(), source.readAsBytesSync());
  });

  testWidgets('★ والشعار يُرسَم من هذا الأصل بتسمية دلالية باسم العميل', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: BrandLogo())));

    final Image image = tester.widget<Image>(
      find.descendant(of: find.byType(BrandLogo), matching: find.byType(Image)),
    );
    expect((image.image as AssetImage).assetName, brandLogoAsset);
    expect(image.semanticLabel, appDisplayName);
    // ⛔ ولا `cover` — تقتطع أطراف نصّ الشعار.
    expect(image.fit, BoxFit.contain);
  });
}

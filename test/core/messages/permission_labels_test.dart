/// حارس أسماء الصلاحيات — ★★ **تغطية في الاتجاهين، وقراءةٌ فعلية للكتالوج**.
///
/// ⚠️⚠️ **ولماذا يقرأ المستند نفسه لا قائمةً منسوخة:** قائمةٌ منسوخة **تفترق
/// عن مصدرها عند أول تعديل**، ⟵ **فيصير الحارسُ يحرس نسختَه هو**. ★ **وقراءة
/// `permissions-catalog.md` مباشرةً تجعل تعديلَ المستند يُسقِط الاختبار**
/// حين لا يُتبَع بتعديل الكود — وهو بالضبط ما يفرضه §0 («**هذا المستند هو
/// المصدر الوحيد للمفاتيح**») و`BR-M1-07`.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qtms/core/messages/permission_labels.dart';
import 'package:qtms_domain/qtms_domain.dart';

/// أوصاف الكتالوج بمفاتيحها — **مقروءةً من المستند حرفياً**.
Map<String, String> catalogDescriptions() {
  final File file = File('docs/09-security/permissions-catalog.md');
  final String section = file
      .readAsStringSync()
      .split('## 2. الكتالوج المعتمد')[1]
      .split('\n## 3.')[0];

  final RegExp singleKeyRow = RegExp(r'^\|\s*`([A-Za-z]+)`\s*\|\s*(.+?)\s*\|');
  // §2.9 — جدولٌ بثلاثة أعمدة: نوع المستند · مفتاح التعديل · مفتاح الإلغاء.
  final RegExp amendCancelRow =
      RegExp(r'^\|\s*([^|`]+?)\s*\|\s*`([A-Za-z]+)`\s*\|\s*`([A-Za-z]+)`\s*\|');

  final Map<String, String> found = <String, String>{};
  for (final String line in section.split('\n')) {
    final RegExpMatch? single = singleKeyRow.firstMatch(line);
    if (single != null) {
      found[single.group(1)!] = _clean(single.group(2)!);
      continue;
    }
    final RegExpMatch? pair = amendCancelRow.firstMatch(line);
    if (pair != null) {
      final String documentType = pair.group(1)!.trim();
      found[pair.group(2)!] = 'تعديل $documentType';
      found[pair.group(3)!] = 'إلغاء $documentType';
    }
  }
  return found;
}

/// يُزيل التوكيد والمراجع بين قوسين — ★ **زينةُ المستند لا نصُّ العرض**.
String _clean(String description) => description
    .replaceAll('**', '')
    .replaceAll(RegExp(r'\s*\(`[^`]+`\)'), '')
    .trim();

void main() {
  group('★★ BR-M1-07 — كل مفتاح باسمه العربي من الكتالوج حرفياً', () {
    late Map<String, String> catalog;

    setUp(() => catalog = catalogDescriptions());

    test('★ المستند يحمل الأحد والثمانين مفتاحاً — وإلا فالقراءة مكسورة', () {
      // ⚠️ **حارسٌ على الحارس:** لو انكسر تحليل الجدول لَعادت خريطةٌ ناقصة
      //    **فنجحت بقية الاختبارات على فراغ** — ⟵ **وهو نجاحٌ لسببٍ خاطئ**.
      expect(catalog.length, Permission.values.length);
      // ★ **و`documentExport` آخرُها** — `IQ-032` الخيار أ (2026-08-30).
      expect(catalog.length, 81);
    });

    test('⛔★★ لا مفتاح في الكتالوج بلا اسم عربي مطابق في التطبيق', () {
      for (final Permission permission in Permission.values) {
        expect(
          catalog[permission.name],
          isNotNull,
          reason: 'المفتاح ${permission.name} بلا سطر في الكتالوج',
        );
        expect(
          permissionLabel(permission),
          catalog[permission.name],
          reason: 'اسم ${permission.name} في التطبيق يخالف وصفه في الكتالوج',
        );
      }
    });

    test('⛔★★ ولا مفتاح في الكتالوج خارج [Permission]', () {
      final Set<String> known =
          Permission.values.map((Permission p) => p.name).toSet();
      expect(catalog.keys.toSet().difference(known), isEmpty);
    });

    test('⛔★★ ولا مفتاح خارج المجموعات — فلا صلاحية تختفي من الشاشة', () {
      // ⚠️ **حالةٌ خفية:** مفتاحٌ له اسمٌ في [permissionLabel] وليس في أي
      //    مجموعة **لا يظهر في الشجرة إطلاقاً** ⟵ **فلا يُمنَح ولا يُسحَب**،
      //    ★ **ويبدو للمدير كأنه غير موجود في النظام.**
      final List<Permission> grouped = <Permission>[
        for (final PermissionGroup group in permissionGroups)
          ...group.permissions,
      ];
      expect(grouped.toSet(), Permission.values.toSet());
      // ⛔ **ولا تكرار** — مفتاحٌ في مجموعتين يُعرَض مرتين فيُربك ويُناقض نفسه.
      expect(grouped.length, Permission.values.length);
    });

    test('★ وترتيب المجموعات هو ترتيب الكتالوج — ⛔ لا أبجدي مخترَع', () {
      final List<Permission> grouped = <Permission>[
        for (final PermissionGroup group in permissionGroups)
          ...group.permissions,
      ];
      expect(grouped, Permission.values);
    });

    test('⛔★ ولا اسم فارغ ولا مفتاح تقني معروض', () {
      for (final Permission permission in Permission.values) {
        final String label = permissionLabel(permission);
        expect(label.trim(), isNotEmpty);
        // ★ `ui-guidelines.md` §6: «لا مصطلح تقني في واجهة المستخدم».
        expect(label, isNot(permission.name));
      }
    });
  });
}

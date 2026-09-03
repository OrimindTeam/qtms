/// ★★★ **بصمةُ جهة التطوير — طبقةُ الوصول وقاعدةُ المصدر الواحد**
/// (`FR-SYS-28` … `FR-SYS-30` · `WU-028`).
///
/// ⛔⛔★★★ **ولا قيمةَ تواصلٍ مكتوبةٌ في هذا الملف ولا في أي اختبار** —
/// ★ **الاختباراتُ تقرأ الأصلَ نفسَه وتقارن**: ⟵ **فلو كُتبت القيمةُ هنا
/// لصار الاختبارُ نسخةً ثانيةً تفترق عن الأولى**، ⛔ **وهو عينُ ما تمنعه
/// القاعدة** (`developer-identity.md` §6).
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qtms/core/identity/developer_attribution.dart';
import 'package:qtms/core/identity/developer_identity.dart';

/// ★ مصدرُ الحقيقة كما هو على القرص.
Map<String, dynamic> _identityJson() => jsonDecode(
      File(developerIdentityAssetPath).readAsStringSync(),
    ) as Map<String, dynamic>;

void main() {
  group('★★★ مصدرُ الحقيقة الوحيد — FR-SYS-29', () {
    test('★ الملفُّ موجودٌ في مساره المعلَن', () {
      expect(
        File(developerIdentityAssetPath).existsSync(),
        isTrue,
        reason: 'مصدرُ حقيقة البصمة غائب: $developerIdentityAssetPath',
      );
    });

    test('★★ والحقولُ الإلزامية الأربعة مملوءةٌ فعلاً ⛔ لا قالبيةً', () {
      final DeveloperIdentity identity =
          DeveloperIdentity.fromJson(_identityJson());
      expect(identity.developerName, isNotEmpty);
      expect(identity.website, isNotEmpty);
      expect(identity.email, isNotEmpty);
      expect(identity.attributionAr, isNotEmpty);
    });

    test('★★★ وقيمةٌ قالبيةٌ `<...>` تُعامَل غائبةً ⛔ لا مملوءة', () {
      // ⛔⛔ **وهذا حارسُ الاختلاق نفسُه**: ⟵ **بدونه يمرّ ملفٌ مُنشأ بـ`--init`
      //    كأنه صالح فيُبنى منتَجٌ يعرض «`<اسم المطور>`» حرفياً للعميل.**
      expect(
        () => DeveloperIdentity.fromJson(<String, dynamic>{
          'developer_name': '<اسم المطور>',
          'website': 'x',
          'email': 'y',
          'logo_files': <String, dynamic>{'mark_png': 'assets/logo-mark.png'},
        }),
        throwsA(isA<DeveloperIdentityException>()),
      );
    });

    test('★ والحقلُ الإلزامي الغائب يُرفَض بخطأٍ مُسمّى ⛔ لا بقيمةٍ افتراضية',
        () {
      expect(
        () => DeveloperIdentity.fromJson(<String, dynamic>{
          'website': 'x',
          'email': 'y',
          'logo_files': <String, dynamic>{'mark_png': 'assets/logo-mark.png'},
        }),
        throwsA(isA<DeveloperIdentityException>()),
      );
    });

    test('★★ ومسارُ الشعار يُعاد بناؤه على جذر المشروع ⛔ لا على جذر المخزن',
        () {
      final DeveloperIdentity identity =
          DeveloperIdentity.fromJson(_identityJson());
      expect(identity.markLogoAssetPath, startsWith('assets/branding/'));
      expect(
        File(identity.markLogoAssetPath).existsSync(),
        isTrue,
        reason: '⛔ مفتاحُ الشعار في JSON ادّعاء — ووجودُ الملف هو الإثبات.',
      );
    });

    test('★ وسطرُ الحقوق يُبنى من السنة والاسم — ⛔ ولا يقرأ ساعةَ الجهاز', () {
      final DeveloperIdentity identity =
          DeveloperIdentity.fromJson(_identityJson());
      final int start = identity.copyrightStartYear;
      expect(identity.copyrightLine(start), '© $start ${identity.developerName}');
      expect(
        identity.copyrightLine(start + 3),
        '© $start–${start + 3} ${identity.developerName}',
      );
    });
  });

  group('★★★ قاعدةُ التبعية البصرية — developer-identity.md §4', () {
    test('⛔⛔★★★ شعارُ المطوّر ≤ 40٪ من شعار العميل', () {
      expect(
        developerMarkRatio,
        lessThanOrEqualTo(0.40),
        reason: '⛔ نسبةُ شعار المطوّر تجاوزت الحدَّ المعتمد في §4.',
      );
    });
  });

  // ══════════════════════════════════════════════════════════════════
  // ⛔⛔★★★ **الفحصُ الآلي القاطع** — `implementation-playbook.md` §7 بند 2-ب
  //    الفحص 4: «**ابحث نصياً عن قيم البريد والهاتف والموقع في شجرة الكود؛
  //    أي ظهورٍ خارج ملف مصدر الحقيقة وطبقة الوصول = مخالفة**».
  //
  // ★★ **وهو الحارسُ الوحيدُ الذي يمنع عودةَ القيمة محفورةً** — ⟵ **ولا
  //    اختبارَ وظيفيٌّ يفشل لأن بريداً كُتب في شاشة.**
  // ══════════════════════════════════════════════════════════════════
  group('⛔⛔★★★ لا قيمةَ تواصلٍ محفورةٌ خارج مصدر الحقيقة — FR-SYS-29', () {
    test('★★★ البريدُ والهاتفُ والموقعُ لا يظهر أيٌّ منها في شجرة المشروع', () {
      final Map<String, dynamic> json = _identityJson();
      final List<String> secrets = <String>[
        json['email'] as String,
        json['website'] as String,
        if (json['phone'] != null) json['phone'] as String,
      ].map((String s) => s.trim()).where((String s) => s.isNotEmpty).toList();

      // ★ المسموحُ له وحده: مصدرُ الحقيقة — ⛔ ولا ملفَّ كودٍ واحد.
      const Set<String> allowed = <String>{developerIdentityAssetPath};

      final List<String> hits = <String>[];
      // ★★ **وملفّاتُ الجذر الوثائقية داخل النطاق كذلك** — ⟵ **فالموضعان 4
      //    و5 (`README` و`LICENSE`) يحملان الاسمَ وحدَه**، ⛔ **ولا قيمةَ
      //    تواصلٍ فيهما**: ★ **وإلا صارا نسختين تفترقان عن مصدر الحقيقة.**
      final List<FileSystemEntity> targets = <FileSystemEntity>[
        for (final Directory dir in <Directory>[
          Directory('lib'),
          Directory('test'),
          Directory('assets'),
          Directory('packages'),
          Directory('functions/lib'),
        ])
          if (dir.existsSync()) ...dir.listSync(recursive: true),
        for (final String root in <String>['README.md', 'LICENSE', 'CLAUDE.md'])
          if (File(root).existsSync()) File(root),
      ];

      {
        for (final FileSystemEntity entity in targets) {
          if (entity is! File) continue;
          final String path = entity.path.replaceAll(r'\', '/');
          if (allowed.contains(path)) continue;
          final bool scannable =
              <String>['.dart', '.json', '.yaml', '.md', '.js']
                      .any(path.endsWith) ||
                  path.endsWith('/LICENSE') ||
                  path == 'LICENSE';
          if (!scannable) continue;
          final String code = entity.readAsStringSync();
          for (final String secret in secrets) {
            if (code.contains(secret)) {
              hits.add('$path ⟵ يحمل قيمةَ تواصلٍ محفورة');
            }
          }
        }
      }
      expect(
        hits,
        isEmpty,
        reason: '\n⛔ قيمُ التواصل تُقرأ من مصدر الحقيقة وحده:\n'
            '${hits.join('\n')}\n',
      );
    });
  });
}

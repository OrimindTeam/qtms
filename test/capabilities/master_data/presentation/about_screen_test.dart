/// ★★★ **شاشة «حول التطبيق» وتذييل الإعدادات** — `FR-SYS-28` · `WU-028`.
///
/// ⛔⛔★★★ **وأخطرُ ما يُختبَر هنا ليس ظهورَ الإسناد بل حدُّه:** ★ **مرةً
/// واحدةً في الشاشة**، ★ **وهويةُ العميل أكبرُ منه بمقاسٍ مقيس**، ⛔ **ولا
/// أثرَ له في شريطٍ علوي ولا شاشةِ دخولٍ ولا بداية** (`developer-identity.md`
/// §4 و§5) — ⟵ **وهذه مخالفاتٌ تعاقديةٌ تمرّ من كل فحصٍ وظيفيٍّ بامتياز.**
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qtms/capabilities/master_data/presentation/about_screen.dart';
import 'package:qtms/core/app_version.dart';
import 'package:qtms/core/design/brand.dart';
import 'package:qtms/core/design/design_tokens.dart';
import 'package:qtms/core/identity/developer_attribution.dart';
import 'package:qtms/core/identity/developer_identity.dart';
import 'package:qtms/core/identity/developer_identity_providers.dart';

/// ★ بصمةٌ ثابتةٌ للاختبار — ⛔ **ولا قيمةَ تواصلٍ حقيقيةٍ في ملف اختبار.**
const DeveloperIdentity fakeIdentity = DeveloperIdentity(
  developerName: 'جهة الاختبار',
  website: 'example.invalid',
  email: 'qa@example.invalid',
  attributionAr: 'طُوِّر بواسطة جهة الاختبار',
  copyrightStartYear: 2026,
  markLogoAssetPath: 'assets/branding/logo-mark.png',
);

Future<void> settle(WidgetTester tester) async {
  for (int i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Widget host(Widget child) => ProviderScope(
      overrides: [
        developerIdentityProvider.overrideWith((Ref ref) async => fakeIdentity),
      ],
      child: MaterialApp(
        locale: const Locale('ar'),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: child,
        ),
      ),
    );

void main() {
  group('★★★ قسمُ الإسناد — الموضع 1', () {
    testWidgets('★ نصُّ الإسناد يُعرَض من مصدر الحقيقة ⛔ لا محفوراً',
        (WidgetTester tester) async {
      await tester.pumpWidget(host(
        const Scaffold(body: DeveloperAttribution(identity: fakeIdentity)),
      ));
      await settle(tester);

      expect(find.text(fakeIdentity.attributionAr), findsOneWidget);
      expect(find.text(fakeIdentity.website), findsOneWidget);
      expect(find.text(fakeIdentity.email), findsOneWidget);
    });

    testWidgets('⛔⛔★★★ ومرةً واحدةً في الشاشة — §4', (WidgetTester tester) async {
      await tester.pumpWidget(host(
        const Scaffold(body: DeveloperAttribution(identity: fakeIdentity)),
      ));
      await settle(tester);

      expect(find.text(fakeIdentity.attributionAr), findsOneWidget);
      expect(find.byType(DeveloperAttribution), findsOneWidget);
    });

    testWidgets('★★ واللونُ ثانويٌّ والدرجةُ أصغرُ المتاح — §4',
        (WidgetTester tester) async {
      await tester.pumpWidget(host(
        const Scaffold(body: DeveloperAttribution(identity: fakeIdentity)),
      ));
      await settle(tester);

      final Text attribution =
          tester.widget<Text>(find.text(fakeIdentity.attributionAr));
      expect(attribution.style?.color, SemanticColors.textSecondary);
      expect(attribution.style?.fontSize, TypeScale.caption.fontSize);
    });

    testWidgets('★★★ وشعارُ المطوّر أصغرُ من شعار العميل فعلاً — قياساً',
        (WidgetTester tester) async {
      expect(developerMarkSize, lessThan(BrandLogo.defaultSize));
      expect(
        developerMarkSize / BrandLogo.defaultSize,
        lessThanOrEqualTo(0.40),
      );
    });
  });

  group('★★ تذييلُ الإصدار — الموضع 2', () {
    testWidgets('★ يعرض الإصدارَ والإسنادَ معاً', (WidgetTester tester) async {
      await tester.pumpWidget(host(
        const Scaffold(
          body: DeveloperAttribution(
            identity: fakeIdentity,
            variant: DeveloperAttributionVariant.footer,
            versionLabel: appVersionLabel,
          ),
        ),
      ));
      await settle(tester);

      expect(find.text(appVersionLabel), findsOneWidget);
      expect(find.text(fakeIdentity.attributionAr), findsOneWidget);
    });

    testWidgets('⛔ ولا قيمةَ تواصلٍ في التذييل — مضغوطٌ بالاسم وحده',
        (WidgetTester tester) async {
      await tester.pumpWidget(host(
        const Scaffold(
          body: DeveloperAttribution(
            identity: fakeIdentity,
            variant: DeveloperAttributionVariant.footer,
            versionLabel: appVersionLabel,
          ),
        ),
      ));
      await settle(tester);

      expect(find.text(fakeIdentity.email), findsNothing);
      expect(find.text(fakeIdentity.website), findsNothing);
    });
  });

  group('★★★ الشاشةُ كاملةً', () {
    testWidgets('★ هويةُ العميل في صدرها والإسنادُ أسفلَها',
        (WidgetTester tester) async {
      await tester.pumpWidget(host(const AboutScreen()));
      await settle(tester);

      // ★★ **وشعارُ الجسم وحده** — ⛔ **لا شعارُ الشريط العلوي:** ★ **الشريطُ
      //    يحمل شعارَ العميل في كل شاشةٍ بعقده** (`ui-guidelines.md` §3-أ ①)،
      //    ⟵ **فوجودُ اثنين هو الصواب لا العطل.**
      final Finder bodyLogo = find.descendant(
        of: find.byType(ListView),
        matching: find.byType(BrandLogo),
      );
      expect(bodyLogo, findsOneWidget);
      expect(find.text(appDisplayName), findsWidgets);
      expect(find.byType(DeveloperAttribution), findsOneWidget);

      // ★★★ **والترتيبُ مقيسٌ لا مفترَض** — §4: «**أسفلَ المحتوى**».
      final double logoY = tester.getCenter(bodyLogo).dy;
      final double attributionY =
          tester.getCenter(find.byType(DeveloperAttribution)).dy;
      expect(attributionY, greaterThan(logoY));
    });

    testWidgets('★★ ورقمُ الإصدار معروضٌ — مرساةُ الموضع 2',
        (WidgetTester tester) async {
      await tester.pumpWidget(host(const AboutScreen()));
      await settle(tester);
      expect(find.text(appVersionLabel), findsOneWidget);
    });
  });
}

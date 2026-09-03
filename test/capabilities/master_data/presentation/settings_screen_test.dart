/// ★★★ **شاشة «الإعدادات»** — `AM-012` §4.4 (2026-09-02).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qtms/capabilities/identity_access/application/session_providers.dart';
import 'package:qtms/capabilities/master_data/presentation/about_screen.dart';
import 'package:qtms/capabilities/master_data/presentation/settings_screen.dart';
import 'package:qtms/core/app_version.dart';
import 'package:qtms/core/identity/developer_attribution.dart';
import 'package:qtms/core/identity/developer_identity.dart';
import 'package:qtms/core/identity/developer_identity_providers.dart';
import 'package:qtms/core/device/device_preference_providers.dart';
import 'package:qtms_domain/qtms_domain.dart';

import '../../../support/fake_identity.dart';

/// ★ بصمةٌ ثابتةٌ للاختبار — ⛔ **ولا قيمةَ تواصلٍ حقيقيةٍ في ملف اختبار.**
const DeveloperIdentity settingsFakeIdentity = DeveloperIdentity(
  developerName: 'جهة الاختبار',
  website: 'example.invalid',
  email: 'qa@example.invalid',
  attributionAr: 'طُوِّر بواسطة جهة الاختبار',
  copyrightStartYear: 2026,
  markLogoAssetPath: 'assets/branding/logo-mark.png',
);

void main() {
  late FakeAuthRepository auth;
  late FakeUserCardRepository cards;
  late FakeDevicePreferences preferences;

  Future<ProviderContainer> pump(WidgetTester tester) async {
    auth = FakeAuthRepository();
    cards = FakeUserCardRepository();
    preferences = FakeDevicePreferences();
    addTearDown(auth.dispose);
    addTearDown(cards.dispose);

    auth.emitIdentity(
      const AuthenticatedIdentity(userId: 'U-001', sourceScope: AllSources()),
    );
    cards.emitCard('U-001', testCard());

    final ProviderContainer container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        userCardRepositoryProvider.overrideWithValue(cards),
        devicePreferencesProvider.overrideWithValue(preferences),
        developerIdentityProvider
            .overrideWith((Ref ref) async => settingsFakeIdentity),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(locale: Locale('ar'), home: SettingsScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    return container;
  }

  group('★★★ `AM-012` §4.4 — زرُّ «إظهار وزن الحبة بجانب اسم النوع»', () {
    testWidgets('★ النصُّ كما طلبه المالك حرفياً', (WidgetTester t) async {
      await pump(t);
      expect(find.text(showPieceWeightToggleLabel), findsOneWidget);
      expect(showPieceWeightToggleLabel, 'إظهار وزن الحبة بجانب اسم النوع');
    });

    testWidgets('⛔ وافتراضُه معطَّل — فالحالةُ القائمة اليوم هي الافتراض', (
      WidgetTester t,
    ) async {
      final ProviderContainer container = await pump(t);
      expect(container.read(showPieceWeightProvider), false);
    });

    testWidgets('★★ والتبديلُ يُغيِّر الحالةَ ويكتبها على الجهاز معاً', (
      WidgetTester t,
    ) async {
      final ProviderContainer container = await pump(t);
      await t.tap(find.byType(SwitchListTile));
      await t.pumpAndSettle();

      expect(container.read(showPieceWeightProvider), true);
      // ⛔⛔ **ولا يكتفي بأحدهما** — ★ **وإلا عاد الخيارُ إلى وضعه عند
      //    أول إقلاعٍ تالٍ** ⛔ **بلا سببٍ ظاهر.**
      expect(preferences.writeCalls, 1);
      expect(await preferences.showPieceWeightWithItemName(), true);
    });

    testWidgets(
      '⛔⛔★★★ والنصُّ يُعلن أنه عرضٌ محضٌ لا يمسّ الوحدة ولا الحساب',
      (WidgetTester t) async {
        // ★★★ **بنصِّ الطلب: «تجميلي/عرضي فقط، ولا يؤثر إطلاقاً على الطبيعة
        //    العددية للنوع»** — ⟵ **ومبدِّلٌ بلا هذا النصّ يُوهم بأنه يغيّر
        //    وحدةَ الحساب** ⛔ **وهو أخطر التباسٍ ممكن هنا.**
        await pump(t);
        expect(find.textContaining('ولا يغيّر وحدة النوع'), findsOneWidget);
        expect(find.textContaining('يبقى العدّ بالحبة'), findsOneWidget);
      },
    );

    testWidgets('★ وإفصاحٌ عن محلّية التفضيل — ⛔ ولا يُترك يُكتشَف', (
      WidgetTester t,
    ) async {
      await pump(t);
      expect(
        find.textContaining('محفوظ على هذا الجهاز وحده'),
        findsOneWidget,
      );
    });
  });

  // ══════════════════════════════════════════════════════════════════
  // ★★★ **تذييلُ الإصدار والإسناد ومدخلُ «حول»** — `FR-SYS-28` · `WU-028`.
  // ══════════════════════════════════════════════════════════════════
  group('★★★ FR-SYS-28 — تذييلُ الإعدادات ومدخلُ «حول التطبيق»', () {
    testWidgets('★ صفُّ «حول التطبيق» موجودٌ في مجموعة «حول»', (
      WidgetTester t,
    ) async {
      await pump(t);
      expect(find.text(settingsAboutGroupTitle), findsOneWidget);
      expect(find.text(aboutScreenTitle), findsOneWidget);
    });

    testWidgets('★★ ورقمُ الإصدار والإسنادُ في التذييل معاً', (
      WidgetTester t,
    ) async {
      await pump(t);
      await t.pump(const Duration(milliseconds: 20));
      expect(find.text(appVersionLabel), findsOneWidget);
      expect(find.text(settingsFakeIdentity.attributionAr), findsOneWidget);
    });

    testWidgets('⛔⛔★★★ ومرةً واحدةً في الشاشة — developer-identity.md §4', (
      WidgetTester t,
    ) async {
      await pump(t);
      await t.pump(const Duration(milliseconds: 20));
      expect(find.byType(DeveloperAttribution), findsOneWidget);
      expect(find.text(settingsFakeIdentity.attributionAr), findsOneWidget);
    });

    testWidgets('⛔ ولا قيمةَ تواصلٍ في تذييل الإعدادات', (
      WidgetTester t,
    ) async {
      await pump(t);
      await t.pump(const Duration(milliseconds: 20));
      expect(find.text(settingsFakeIdentity.email), findsNothing);
      expect(find.text(settingsFakeIdentity.website), findsNothing);
    });
  });
}

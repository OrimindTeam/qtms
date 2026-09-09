/// صدَفة ما بعد الدخول — ★ **بلا موجّه**، فيُفحص المكوّن وحده.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qtms/capabilities/financial_outflow/application/owner_ledger_providers.dart';
import 'package:qtms/capabilities/financial_outflow/presentation/owner_ledger_card.dart';
import 'package:qtms/capabilities/identity_access/application/session_providers.dart';
import 'package:qtms/capabilities/inventory/presentation/supply_intake_screen.dart';
import 'package:qtms/capabilities/identity_access/presentation/home_shell.dart';
import 'package:qtms/capabilities/master_data/application/master_data_providers.dart';
import 'package:qtms/core/design/design_tokens.dart';
import 'package:qtms/core/ui/avatar.dart';
import 'package:qtms/core/ui/hub_section.dart';
import 'package:qtms/core/ui/needs_action_card.dart';
import 'package:qtms_domain/qtms_domain.dart';

import '../../../support/fake_identity.dart';
import '../../../support/fake_master_data.dart';
import '../../../support/fake_owner_ledger.dart';

void main() {
  testWidgets(
    '★ تعرض الهوية في الشريط — ⛔ ولا بطاقةَ دورٍ ونطاق (AM-009 ②)',
    (WidgetTester tester) async {
      final FakeAuthRepository auth = FakeAuthRepository();
      final FakeUserCardRepository cards = FakeUserCardRepository();
      auth.emitIdentity(
        const AuthenticatedIdentity(userId: 'U-001', sourceScope: AllSources()),
      );
      cards.emitCard('U-001', testCard());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(auth),
            userCardRepositoryProvider.overrideWithValue(cards),
          ],
          child: const MaterialApp(
            locale: Locale('ar'),
            home: HomeShell(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));

      // ⚠️★★★ **واسمُ المستخدم انتقل إلى الصورة الرمزية بـ`AM-008` ①** —
      //    ⟵ **فيُقاس بحرفه الأول لا بنصٍّ كامل**، ★ **ولا يسقط الفحص:
      //    الهويةُ ما زالت معروضة** ⛔ **بشكلٍ آخر.**
      expect(find.byType(QtmsAvatar), findsOneWidget);
      expect(
        tester.widget<QtmsAvatar>(find.byType(QtmsAvatar)).name,
        'عبدالفتاح',
      );
      // ★★ **واسمُ الشاشة في الشريط العلوي** — `AM-008` ①.
      expect(find.text('لوحة اليوم'), findsOneWidget);
      // ⛔⛔★★★ **ولا بطاقةَ هويةٍ في جسم الشاشة** — `AM-009` ②: ★ **كانت
      //    تعرض اسمَ الدور ونطاقَ المصادر في الطيّة الأولى**، ⟵ **وهما
      //    وصفُ حالةٍ لا مدخلُ عمل** ⛔ **فأُزيلا بطلب المالك.**
      //    ★ **والدورُ والنطاق يُقرآن في `PermissionsScreen`.**
      expect(find.text('المالك'), findsNothing);
      expect(find.text('كل المصادر'), findsNothing);
      // ⛔⛔★★★ **ولا أيقونةَ خروجٍ في الشريط** — `AM-009` ①: ★ **انتقلت
      //    إلى قائمة الجلسة على الصورة الرمزية.**
      expect(find.byIcon(Icons.logout), findsNothing);

      auth.dispose();
      cards.dispose();
    },
    timeout: const Timeout(Duration(seconds: 20)),
  );

  testWidgets(
    '⛔⛔★★★ كلُّ زيادةٍ منجَزة لها مدخلٌ في الصدَفة — ولا شاشةَ يتيمة',
    (WidgetTester tester) async {
      // ★★★ **اختبارُ ارتدادٍ لعطلٍ حقيقي رُصد على المحاكي (2026-08-26):**
      //    شاشةُ الجواني **مبنيّةٌ ومسارُها مسجَّل في `router.dart`**
      //    ⛔ **ولا زرَّ واحد يصل إليها** ⟵ **فكانت `WU-004` كلها غيرَ
      //    قابلةٍ للوصول من الواجهة.**
      //
      // ⚠️⚠️ **ولا اختبارَ آليٍّ واحدٍ كان يفشل بذلك:** اختبارات الشاشة
      //    **تبنيها مباشرةً** ⛔ **ولا تمرّ بالصدَفة** — ★ **فالفجوة كانت
      //    بين «الشاشة تعمل» و«المستخدم يصل إليها».**
      // ★ سطحٌ طويل — ⟵ **فتُبنى كلُّ المداخل** ⛔ **ولا يسقط واحدٌ لأنه
      //   خارج الشاشة وحدها**، وهو ما يُبطِل الغرض من الاختبار.
      tester.view.physicalSize = const Size(1200, 4200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final FakeAuthRepository auth = FakeAuthRepository();
      final FakeUserCardRepository cards = FakeUserCardRepository();
      auth.emitIdentity(
        const AuthenticatedIdentity(userId: 'U-001', sourceScope: AllSources()),
      );
      // ★ بطاقةٌ بكل الصلاحيات — فلا تُخفي بوابةٌ مدخلاً لسببٍ آخر.
      cards.emitCard(
        'U-001',
        testCard(permissions: Permission.values.toSet()),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(auth),
            userCardRepositoryProvider.overrideWithValue(cards),
          ],
          child: const MaterialApp(
            locale: Locale('ar'),
            home: HomeShell(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));

      // ★★★ **ومدخلٌ واحدٌ للتوريد منذ `AM-012` §2** — ⟵ **«الوارد عدداً»
      //    و«الوارد جواني» تبويبان داخله** ⛔ **لا مدخلان في الصدَفة.**
      for (final String label in <String>[
        supplyIntakeScreenTitle,
        'مخزون اليوم',
        'التسعير اليومي',
      ]) {
        expect(
          find.text(label),
          findsOneWidget,
          reason: '⛔ لا مدخل للزيادة «$label» في الصدَفة',
        );
      }

      auth.dispose();
      cards.dispose();
    },
    timeout: const Timeout(Duration(seconds: 20)),
  );

  group('★★★ لوحةُ اليوم بعد `AM-017` — الشبكةُ والتثبيتُ والطيّ', () {
    late FakeAuthRepository auth;
    late FakeUserCardRepository cards;
    late FakeOwnerLedgerDirectory ledger;
    late FakeCashMovementReader cash;
    late FakeMasterDataDirectory masterData;

    setUp(() {
      auth = FakeAuthRepository();
      cards = FakeUserCardRepository();
      ledger = FakeOwnerLedgerDirectory();
      cash = FakeCashMovementReader();
      masterData = FakeMasterDataDirectory()
        ..emitSources(<SourceCard>[
          const SourceCard(
            sourceId: 'SRC-001',
            name: 'رداع',
            requiresSupplierOnIntake: false,
            isActive: true,
          ),
        ]);
    });

    tearDown(() {
      auth.dispose();
      cards.dispose();
    });

    Future<void> pumpShell(
      WidgetTester tester, {
      // ★ **عرضُ Pixel 6 المنطقي — فالأعمدةُ عمودان كما على الجهاز**،
      //   ★ **وارتفاعٌ فسيحٌ عمداً**: ⟵ **`ListView` يبني ما يظهر وحدَه**،
      //   ⛔ **فقياسُ بلاطةٍ لم تُبنَ بعدُ يقيس غيابَ نافذةٍ لا غيابَ بلاطة.**
      Size size = const Size(411, 1600),
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      auth.emitIdentity(
        const AuthenticatedIdentity(userId: 'U-001', sourceScope: AllSources()),
      );
      cards.emitCard(
        'U-001',
        testCard(permissions: Permission.values.toSet()),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(auth),
            userCardRepositoryProvider.overrideWithValue(cards),
            masterDataDirectoryProvider.overrideWithValue(masterData),
            masterDataAdminProvider.overrideWithValue(FakeMasterDataAdmin()),
            contactPickerProvider.overrideWithValue(null),
            ownerLedgerDirectoryProvider.overrideWithValue(ledger),
            cashMovementReaderProvider.overrideWithValue(cash),
          ],
          child: const MaterialApp(locale: Locale('ar'), home: HomeShell()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      // ★ **البثُّ بعد الاشتراك** — ⛔ **ومذيعٌ بلا إعادةِ بثٍّ يُضيع ما سبقه.**
      ledger.emitSummary(
        allSourcesScopeId,
        computeOwnerLedgerSummary(
          sourceId: allSourcesScopeId,
          date: CalendarDay(2026, 9, 9),
          contributions: const OwnerLedgerContributions(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
    }

    testWidgets('★★★ المداخلُ بلاطاتُ شبكةٍ ⛔ لا أزرارَ بعرضٍ كامل',
        (WidgetTester tester) async {
      await pumpShell(tester);

      expect(find.byType(QtmsHubTile), findsWidgets);
      // ⛔ **ولا زرَّ مدخلٍ محاطٍ بعرضٍ كامل بقي في الصدَفة.**
      expect(
        tester.getSize(find.byType(QtmsHubTile).first).height,
        Sizes.hubTileHeight,
      );
    });

    testWidgets('★★★ والأساسيُّ «التوزيع» يمتدّ بعرض عمودين',
        (WidgetTester tester) async {
      await pumpShell(tester);

      final double primary = tester
          .getSize(
            find.ancestor(
              of: find.text('التوزيع'),
              matching: find.byType(QtmsHubTile),
            ),
          )
          .width;
      final double secondary = tester
          .getSize(
            find.ancestor(
              of: find.text('البيع النقدي'),
              matching: find.byType(QtmsHubTile),
            ),
          )
          .width;

      expect(
        primary,
        greaterThan(secondary * 1.8),
        reason: '⛔ الأساسيُّ لا يمتدّ بعرض عمودين',
      );
    });

    testWidgets('⛔⛔★★★ وبطاقةُ «يحتاج إجراء» مثبَّتةٌ لا تُمرَّر مع المحتوى',
        (WidgetTester tester) async {
      await pumpShell(tester);

      final double before =
          tester.getTopLeft(find.byType(QtmsNeedsActionCard)).dy;
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pump();

      expect(find.byType(QtmsNeedsActionCard), findsOneWidget);
      expect(
        tester.getTopLeft(find.byType(QtmsNeedsActionCard)).dy,
        before,
        reason: '⛔ البطاقةُ تحرّكت مع التمرير — فليست مثبَّتة',
      );
    });

    testWidgets('★★★ وبطاقةُ الضمار مطويّةٌ في اللوحة — §7.1 القاعدة 8',
        (WidgetTester tester) async {
      await pumpShell(tester);

      expect(find.byType(OwnerLedgerCard), findsOneWidget);
      expect(
        tester.widget<OwnerLedgerCard>(find.byType(OwnerLedgerCard))
            .initiallyExpanded,
        isFalse,
      );
      expect(find.text('عرض التفاصيل'), findsOneWidget);
      expect(find.text('إجمالي الضمار'), findsNothing);
    });
  });
}

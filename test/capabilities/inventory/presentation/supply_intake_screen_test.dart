/// ★★★ **شاشة «التوريد مخزني»** — `AM-012` §2 (2026-09-02).
///
/// ⚠️⚠️ **وما تُثبته هذه الاختبارات:** أن **الشاشتين صارتا تبويبين في شاشةٍ
/// واحدة**، وأن **مرشِّح المصدر مشتركٌ بينهما فعلاً** (⛔ **لا حالتان
/// مُتزامنتان**)، وأن **زرَّ الإضافة يتبع التبويب**، وأن **نموذج الجونية
/// صار يحمل حقل المصدر**.
///
/// ⛔ **ولا تُثبت أن الكتابة محميّة** — ★ **الحماية في الدوال الكاتبة وفي
/// `firestore.rules`**، ولها اختباراتها هناك (`RISK-02`).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qtms/capabilities/identity_access/application/session_providers.dart';
import 'package:qtms/capabilities/inventory/application/inventory_providers.dart';
import 'package:qtms/capabilities/inventory/presentation/supply_intake_screen.dart';
import 'package:qtms/capabilities/master_data/application/master_data_providers.dart';
import 'package:qtms/core/ui/context_header.dart';
import 'package:qtms_domain/qtms_domain.dart';

import '../../../support/fake_identity.dart';
import '../../../support/fake_inventory.dart';
import '../../../support/fake_master_data.dart';
import '../../../support/fake_sacks.dart';

/// ★★ **اليوم مثبَّت** — ⛔ **فلا اختبارَ ينكسر بمرور منتصف الليل.**
final CalendarDay fixedDay = CalendarDay(2026, 8, 26);

/// ★ كلُّ مفاتيح التوريد — فالاختبار يقيس **البنية لا نقصَ المفتاح**.
const Set<Permission> supplyKeys = <Permission>{
  Permission.incomingCountWrite,
  Permission.incomingCountAmend,
  Permission.sackCreate,
  Permission.sackView,
  Permission.sackLinesEnter,
  Permission.sackScrapWeightEnter,
};

Future<ProviderContainer> pumpSupply(
  WidgetTester tester, {
  required FakeInventoryDirectory inventory,
  required FakeSackDirectory sacks,
  required FakeMasterDataDirectory masterData,
  Set<Permission> actorPermissions = supplyKeys,
  int initialTab = supplyIntakeCountedTab,
}) async {
  final FakeAuthRepository auth = FakeAuthRepository();
  final FakeUserCardRepository cards = FakeUserCardRepository();
  auth.emitIdentity(
    const AuthenticatedIdentity(userId: 'U-001', sourceScope: AllSources()),
  );
  cards.emitCard('U-001', testCard(permissions: actorPermissions));
  addTearDown(auth.dispose);
  addTearDown(cards.dispose);

  final ProviderContainer container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(auth),
      userCardRepositoryProvider.overrideWithValue(cards),
      masterDataDirectoryProvider.overrideWithValue(masterData),
      masterDataAdminProvider.overrideWithValue(FakeMasterDataAdmin()),
      contactPickerProvider.overrideWithValue(null),
      inventoryDirectoryProvider.overrideWithValue(inventory),
      inventoryAdminProvider.overrideWithValue(FakeInventoryAdmin()),
      sackDirectoryProvider.overrideWithValue(sacks),
      sackAdminProvider.overrideWithValue(FakeSackAdmin()),
      todayProvider.overrideWithValue(fixedDay),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('ar'),
        home: SupplyIntakeScreen(initialTab: initialTab),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 20));
  return container;
}

void main() {
  late FakeInventoryDirectory inventory;
  late FakeSackDirectory sacks;
  late FakeMasterDataDirectory masterData;

  setUp(() {
    inventory = FakeInventoryDirectory();
    sacks = FakeSackDirectory();
    masterData = FakeMasterDataDirectory();
    masterData.emitSources(<SourceCard>[
      testSource(sourceId: 'SRC-001', name: 'رداع'),
      testSource(sourceId: 'SRC-002', name: 'ماوية'),
    ]);
    masterData.emitItems(<ItemCard>[testItem()]);
    masterData.emitSuppliers(const <SupplierCard>[]);
    inventory.emitIntakes(const <CountedIntakeCard>[]);
    inventory.emitStock(const <ItemDailyBalanceCard>[]);
    sacks.emitSacks(const <SackCard>[]);
  });

  tearDown(() {
    inventory.dispose();
    sacks.dispose();
    masterData.dispose();
  });

  group('★★★ الدمج — شاشةٌ واحدة بتبويبين (`AM-012` §2)', () {
    testWidgets('★ الاسمُ «التوريد مخزني» والتبويبان بعنوانيهما', (
      WidgetTester t,
    ) async {
      await pumpSupply(
        t,
        inventory: inventory,
        sacks: sacks,
        masterData: masterData,
      );

      expect(find.text(supplyIntakeScreenTitle), findsOneWidget);
      expect(find.byType(TabBar), findsOneWidget);
      expect(find.text(countedIntakeTabTitle), findsOneWidget);
      expect(find.text(sackIntakeTabTitle), findsOneWidget);
    });

    testWidgets('⛔⛔★★★ ورأسُ سياقٍ واحدٌ فوق التبويبات — ⛔ لا نسخةَ في كلٍّ', (
      WidgetTester t,
    ) async {
      // ★ **«لا تكرار للمعلومة بين التبويبات»** — `ui-guidelines.md` §3 نمط 3.
      await pumpSupply(
        t,
        inventory: inventory,
        sacks: sacks,
        masterData: masterData,
      );
      expect(find.byType(QtmsContextHeader), findsOneWidget);
    });

    testWidgets('★★ والانتقالُ إلى التبويب الثاني يعرض قائمة الجواني', (
      WidgetTester t,
    ) async {
      await pumpSupply(
        t,
        inventory: inventory,
        sacks: sacks,
        masterData: masterData,
      );

      await t.tap(find.text(sackIntakeTabTitle));
      await t.pumpAndSettle();
      expect(find.text('لا توجد جواني اليوم'), findsOneWidget);
    });

    testWidgets('★★ ويُفتَح على تبويب الجواني حين يُطلَب — مركزُ الإدخالات', (
      WidgetTester t,
    ) async {
      await pumpSupply(
        t,
        inventory: inventory,
        sacks: sacks,
        masterData: masterData,
        initialTab: supplyIntakeSackTab,
      );
      expect(find.text('لا توجد جواني اليوم'), findsOneWidget);
    });
  });

  group('⛔⛔★★★ مرشِّحُ المصدر مشتركٌ بين التبويبين — نصُّ الطلب', () {
    testWidgets(
      '★★★ تغييرُه من تبويبٍ ينعكس على الآخر — ⛔ ولا حالتان تُتزامنان',
      (WidgetTester t) async {
        final ProviderContainer container = await pumpSupply(
          t,
          inventory: inventory,
          sacks: sacks,
          masterData: masterData,
        );

        // ★ **والافتراض «كل المصادر»** — `AM-009` ③.
        expect(container.read(sourceListFilterProvider), isNull);

        // ★ يُختار مصدرٌ من التبويب الأول.
        await t.tap(find.byType(DropdownButtonFormField<String>).first);
        await t.pumpAndSettle();
        await t.tap(find.text('ماوية').last);
        await t.pumpAndSettle();
        expect(container.read(sourceListFilterProvider), 'SRC-002');

        // ⛔⛔★★★ **والتبويبُ الثاني يقرأ القيمةَ نفسَها** — ★ **مزوّدٌ واحد**:
        //    ⟵ **ولا مزامنةَ يدوية تفوت.**
        await t.tap(find.text(sackIntakeTabTitle));
        await t.pumpAndSettle();
        expect(container.read(sourceListFilterProvider), 'SRC-002');
        // ★ **والرأسُ نفسُه يعرض الاختيار** — ⛔ **ولا يعود إلى «الكل».**
        expect(find.text('ماوية'), findsWidgets);
      },
    );

    testWidgets(
      '★★★ و«كل المصادر» متاحةٌ في التبويبين — قرارُ المالك في §2 ②',
      (WidgetTester t) async {
        final ProviderContainer container = await pumpSupply(
          t,
          inventory: inventory,
          sacks: sacks,
          masterData: masterData,
          initialTab: supplyIntakeSackTab,
        );

        // ⛔⛔★★ **وكان تبويبُ الجواني يمنعها قبل `AM-012`** — ★ **ويعرض
        //    «اختر مصدراً»**: ⟵ **والآن يعرض قائمةَ كل المصادر.**
        expect(container.read(sourceListFilterProvider), isNull);
        expect(find.textContaining('اختر مصدر'), findsNothing);
        expect(find.text('لا توجد جواني اليوم'), findsOneWidget);
      },
    );
  });

  group('⛔⛔★★ زرُّ الإضافة يتبع التبويب — ⛔ لا زرَّ واحدٌ لعمليتين', () {
    testWidgets('★ «وارد عدداً جديد» في الأول و«جونية جديدة» في الثاني', (
      WidgetTester t,
    ) async {
      await pumpSupply(
        t,
        inventory: inventory,
        sacks: sacks,
        masterData: masterData,
      );

      expect(find.text('وارد جديد'), findsOneWidget);
      expect(find.text('جونية جديدة'), findsNothing);

      await t.tap(find.text(sackIntakeTabTitle));
      await t.pumpAndSettle();

      expect(find.text('جونية جديدة'), findsOneWidget);
      expect(find.text('وارد جديد'), findsNothing);
    });

    testWidgets(
      '⛔⛔★★★ وزرُّ الجونية يعمل و«كل المصادر» معروضة — `AM-012` §2',
      (WidgetTester t) async {
        // ★★★ **وهذا جوهرُ قرارِ المالك:** ⟵ **قبله كان الزرُّ يختفي على
        //    «الكل»** ⛔ **فتسقط قدرةُ الإضافة كلَّها.**
        final ProviderContainer container = await pumpSupply(
          t,
          inventory: inventory,
          sacks: sacks,
          masterData: masterData,
          initialTab: supplyIntakeSackTab,
        );
        expect(container.read(sourceListFilterProvider), isNull);
        expect(find.text('جونية جديدة'), findsOneWidget);
      },
    );

    testWidgets('⛔ ومن لا يملك مفتاحَ الجونية لا يرى زرَّها', (
      WidgetTester t,
    ) async {
      // ⚠️ **إخفاءٌ لا حماية** — ★ **والرفض في `planSack`** (`RISK-02`).
      await pumpSupply(
        t,
        inventory: inventory,
        sacks: sacks,
        masterData: masterData,
        actorPermissions: const <Permission>{Permission.incomingCountWrite},
        initialTab: supplyIntakeSackTab,
      );
      expect(find.text('جونية جديدة'), findsNothing);
    });
  });

  group('★★★ نموذجُ الجونية يحمل حقل المصدر — `AM-012` §2', () {
    testWidgets(
      '★★★ فتُنشَأ جونيةٌ ومرشِّحُ الشاشة على «كل المصادر»',
      (WidgetTester t) async {
        await pumpSupply(
          t,
          inventory: inventory,
          sacks: sacks,
          masterData: masterData,
          initialTab: supplyIntakeSackTab,
        );

        await t.tap(find.text('جونية جديدة'));
        await t.pumpAndSettle();

        // ★★ **وحقلُ المصدر داخل النموذج** — ⛔ **لا مُشتقٌّ من مرشِّح عرض.**
        expect(find.text('المصدر'), findsWidgets);
        expect(find.byType(DropdownButtonFormField<String>), findsWidgets);
        // ★ **والوزنُ الكلي حاضرٌ كما كان** — ⛔ **ولم يسقط من النموذج شيء.**
        expect(find.text('الوزن الكلي'), findsOneWidget);
      },
    );
  });
}

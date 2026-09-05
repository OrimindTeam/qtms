/// شاشةُ متبقي الأيام السابقة وصفُّ تنبيهها — `WU-019` (`M8` الشاشة الثانية).
///
/// ⚠️⚠️ **وما تُثبته هذه الاختبارات وما لا تُثبته:** تُثبت أن **الشاشة تعرض
/// ما هو متأخرٌ فعلاً بعمره ومصدره**، وأنها **تُثبِّت البند على شاشة التصريف**،
/// وأنها **تعرض الرفض بنصّه**. ⛔ **ولا تُثبت أن الكتابة محميّة** — ★ **الحماية
/// في `agedClearanceRejection`** ولها اختبارُها في `functions/test`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:qtms/capabilities/identity_access/application/session_providers.dart';
import 'package:qtms/capabilities/identity_access/presentation/home_shell.dart';
import 'package:qtms/capabilities/inventory/application/aged_remainder_providers.dart';
import 'package:qtms/capabilities/inventory/application/inventory_providers.dart';
import 'package:qtms/capabilities/inventory/presentation/aged_remainder_screen.dart';
import 'package:qtms/capabilities/master_data/application/master_data_providers.dart';
import 'package:qtms/core/design/design_tokens.dart';
import 'package:qtms/core/ui/async_state_view.dart';
import 'package:qtms/core/ui/needs_action_row.dart';
import 'package:qtms/core/ui/status_pill.dart';
import 'package:qtms_domain/qtms_domain.dart';

import '../../../support/fake_identity.dart';
import '../../../support/fake_inventory.dart';
import '../../../support/fake_master_data.dart';

/// ★★ **اليوم مثبَّت** — ⛔ **فلا اختبارَ ينكسر بمرور منتصف الليل.**
final CalendarDay fixedDay = CalendarDay(2026, 9, 4);

/// ★ مفاتيحُ التصريف الثلاثة — فالاختبار يقيس **الشاشة لا نقصَ المفتاح**.
const Set<Permission> clearKeys = <Permission>{
  Permission.agedRemainderClear,
  Permission.distributionCreate,
  Permission.cashSaleCreate,
};

Future<void> pumpScreen(
  WidgetTester tester, {
  required FakeAgedRemainderDirectory aged,
  required FakeMasterDataDirectory masterData,
  Set<Permission> actorPermissions = clearKeys,
}) async {
  final FakeAuthRepository auth = FakeAuthRepository();
  final FakeUserCardRepository cards = FakeUserCardRepository();
  auth.emitIdentity(
    const AuthenticatedIdentity(userId: 'U-001', sourceScope: AllSources()),
  );
  cards.emitCard('U-001', testCard(permissions: actorPermissions));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        userCardRepositoryProvider.overrideWithValue(cards),
        masterDataDirectoryProvider.overrideWithValue(masterData),
        masterDataAdminProvider.overrideWithValue(FakeMasterDataAdmin()),
        contactPickerProvider.overrideWithValue(null),
        agedRemainderDirectoryProvider.overrideWithValue(aged),
        todayProvider.overrideWithValue(fixedDay),
      ],
      // ★★ **ومُوجِّهٌ حقيقيٌّ مصغَّر** — ⟵ **فزرُّ التصريف يُبحِر فعلاً**،
      //   ⛔ **ولا يُختبَر تثبيتُ البند على شاشةٍ بلا ملاحة.**
      child: MaterialApp.router(
        locale: const Locale('ar'),
        routerConfig: GoRouter(
          routes: <RouteBase>[
            GoRoute(
              path: '/',
              builder: (BuildContext _, GoRouterState _) =>
                  const AgedRemainderScreen(),
            ),
            GoRoute(
              path: '/home/distribution',
              builder: (BuildContext _, GoRouterState _) =>
                  const Scaffold(body: Text('شاشة التوزيع')),
            ),
            GoRoute(
              path: '/home/cash-sales',
              builder: (BuildContext _, GoRouterState _) =>
                  const Scaffold(body: Text('شاشة البيع النقدي')),
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 20));
}

/// ★ صفُّ المتبقي في الصدَفة — ⛔ **بعقده لا بنصٍّ عائمٍ في الشاشة.**
QtmsNeedsActionRow agedRow(WidgetTester tester) =>
    tester.widget<QtmsNeedsActionRow>(
      find.ancestor(
        of: find.text('متبقي أيام سابقة'),
        matching: find.byType(QtmsNeedsActionRow),
      ),
    );

void main() {
  late FakeAgedRemainderDirectory aged;
  late FakeMasterDataDirectory masterData;

  setUp(() {
    aged = FakeAgedRemainderDirectory();
    masterData = FakeMasterDataDirectory();
    masterData.emitSources(<SourceCard>[testSource()]);
    masterData.emitItems(<ItemCard>[]);
    masterData.emitSuppliers(<SupplierCard>[]);
    masterData.emitDealers(<DealerCard>[]);
  });

  testWidgets('★★★ تعرض اليومَ وعمرَه ونوعَه ومتبقّيه', (WidgetTester tester) async {
    aged.emit(<AgedRemainderCard>[
      testAgedRemainder(stockDate: CalendarDay(2026, 9, 2)),
    ]);
    await pumpScreen(tester, aged: aged, masterData: masterData);

    expect(find.textContaining('مخزون يوم 2026/09/02'), findsOneWidget);
    expect(find.text('منذ يومين'), findsOneWidget);
    expect(find.text('عوارض'), findsOneWidget);
    expect(find.text('20 حبة'), findsOneWidget);
  });

  testWidgets('⛔⛔★★ والحدُّ الزمني في الاستعلام لا في العرض',
      (WidgetTester tester) async {
    aged.emit(const <AgedRemainderCard>[]);
    await pumpScreen(tester, aged: aged, masterData: masterData);

    // ★ **يُطلَب «اليوم» فيقتطع الاستعلامُ ما قبله وحده** — `FR-M8-09`.
    expect(aged.lastToday, fixedDay);
    // ⛔⛔ **واستعلامٌ مقيَّدٌ لكل مصدر** — `IQ-024` · `DEBT-40`.
    expect(aged.requestedSources, contains('SRC-001'));
  });

  testWidgets('★★ والحالةُ الفارغة تقول السبب لا «لا توجد بيانات»',
      (WidgetTester tester) async {
    aged.emit(const <AgedRemainderCard>[]);
    await pumpScreen(tester, aged: aged, masterData: masterData);

    expect(find.text('لا متبقي من أيام سابقة'), findsOneWidget);
    expect(find.textContaining('صُرِّف بالكامل'), findsOneWidget);
  });

  testWidgets('⛔⛔★★ والرفضُ يُعرَض خطأً — لا قائمةً فارغة (`RISK-02`)',
      (WidgetTester tester) async {
    aged.emitError(StateError('permission-denied'));
    await pumpScreen(tester, aged: aged, masterData: masterData);

    expect(find.byType(QtmsErrorState), findsOneWidget);
    expect(find.text('لا متبقي من أيام سابقة'), findsNothing);
  });

  testWidgets('★★★ ورصيدُ اليوم لا يظهر هنا — `FR-M8-05` · `E2`',
      (WidgetTester tester) async {
    // ⚠️ **حارسٌ ثانٍ فوق حدّ الاستعلام** — ⟵ **فبندٌ وصل بيوم اليوم يُسقَط.**
    aged.emit(<AgedRemainderCard>[testAgedRemainder(stockDate: fixedDay)]);
    await pumpScreen(tester, aged: aged, masterData: masterData);

    expect(find.text('لا متبقي من أيام سابقة'), findsOneWidget);
  });

  testWidgets('★★★ والأقدمُ أولاً — فالترتيبُ يحمل معنى',
      (WidgetTester tester) async {
    aged.emit(<AgedRemainderCard>[
      testAgedRemainder(stockDate: CalendarDay(2026, 9, 3)),
      testAgedRemainder(stockDate: CalendarDay(2026, 8, 28), itemKey: 'ITM-9'),
    ]);
    await pumpScreen(tester, aged: aged, masterData: masterData);

    final double older = tester
        .getTopLeft(find.textContaining('مخزون يوم 2026/08/28'))
        .dy;
    final double newer = tester
        .getTopLeft(find.textContaining('مخزون يوم 2026/09/03'))
        .dy;
    expect(older, lessThan(newer));
  });

  testWidgets('⛔⛔★★ ومن لا يملك المفاتيح لا يرى إجراءً',
      (WidgetTester tester) async {
    aged.emit(<AgedRemainderCard>[
      testAgedRemainder(stockDate: CalendarDay(2026, 9, 2)),
    ]);
    await pumpScreen(
      tester,
      aged: aged,
      masterData: masterData,
      actorPermissions: const <Permission>{},
    );

    expect(find.text('توزيع'), findsNothing);
    expect(find.text('بيع نقدي'), findsNothing);
  });

  testWidgets('⛔⛔★★★ و«تصريف المتبقي» وحدها لا تكفي — `E4` من `UC-004`',
      (WidgetTester tester) async {
    aged.emit(<AgedRemainderCard>[
      testAgedRemainder(stockDate: CalendarDay(2026, 9, 2)),
    ]);
    await pumpScreen(
      tester,
      aged: aged,
      masterData: masterData,
      actorPermissions: const <Permission>{Permission.agedRemainderClear},
    );

    expect(find.text('توزيع'), findsNothing);
    expect(find.text('بيع نقدي'), findsNothing);
  });

  testWidgets('★★★ والنقرُ يُثبِّت المصدرَ والنوعَ وتاريخَ المخزون',
      (WidgetTester tester) async {
    aged.emit(<AgedRemainderCard>[
      testAgedRemainder(stockDate: CalendarDay(2026, 9, 2)),
    ]);
    await pumpScreen(tester, aged: aged, masterData: masterData);

    final ProviderContainer container = ProviderScope.containerOf(
      tester.element(find.byType(AgedRemainderScreen)),
    );
    await tester.tap(find.text('توزيع'));
    await tester.pumpAndSettle();
    // ★ **وأبحرت فعلاً** — ⟵ **فالتثبيتُ وعدٌ بوجهة لا حالةٌ معلّقة.**
    expect(find.text('شاشة التوزيع'), findsOneWidget);

    final AgedClearanceFocus? focus =
        container.read(agedClearanceFocusProvider);
    expect(focus, isNotNull);
    expect(focus!.sourceId, 'SRC-001');
    expect(focus.itemKey, 'ITM-0001');
    expect(focus.stockDate, CalendarDay(2026, 9, 2));
  });

  group('★★ درجةُ الحدّة — ثلاثٌ بعائلتين وأيقونتين', () {
    test('★ والعائلةُ تتبع العمر', () {
      expect(
        agedSeverityTriad(AgedRemainderSeverity.recent),
        SemanticTriads.warning,
      );
      expect(
        agedSeverityTriad(AgedRemainderSeverity.ageing),
        SemanticTriads.danger,
      );
      expect(
        agedSeverityTriad(AgedRemainderSeverity.overdue),
        SemanticTriads.danger,
      );
    });

    test('⛔⛔★★ والأيقونةُ تفرّق بين الدرجتين الأشدّ — فلا لونَ وحده', () {
      expect(
        agedSeverityIcon(AgedRemainderSeverity.ageing),
        isNot(agedSeverityIcon(AgedRemainderSeverity.overdue)),
      );
      expect(
        agedSeverityIcon(AgedRemainderSeverity.recent),
        isNot(agedSeverityIcon(AgedRemainderSeverity.ageing)),
      );
    });

    test('★ والعمرُ نصٌّ صريح — `FR-M8-18`', () {
      expect(agedAgeLabel(1), 'منذ يوم');
      expect(agedAgeLabel(2), 'منذ يومين');
      expect(agedAgeLabel(7), 'منذ 7 أيام');
    });
  });

  group('★★★ التنبيهُ الدائم في الصدَفة — `FR-M8-10` (`GR-16`)', () {
    Future<void> pumpShell(
      WidgetTester tester, {
      required FakeAgedRemainderDirectory aged,
      required FakeMasterDataDirectory masterData,
    }) async {
      final FakeAuthRepository auth = FakeAuthRepository();
      final FakeUserCardRepository cards = FakeUserCardRepository();
      auth.emitIdentity(
        const AuthenticatedIdentity(userId: 'U-001', sourceScope: AllSources()),
      );
      cards.emitCard('U-001', testCard(permissions: clearKeys));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(auth),
            userCardRepositoryProvider.overrideWithValue(cards),
            masterDataDirectoryProvider.overrideWithValue(masterData),
            agedRemainderDirectoryProvider.overrideWithValue(aged),
            todayProvider.overrideWithValue(fixedDay),
          ],
          child: const MaterialApp(locale: Locale('ar'), home: HomeShell()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
    }

    testWidgets('★★★ العدّادُ عددُ الأيام — `UC-004` ①',
        (WidgetTester tester) async {
      aged.emit(<AgedRemainderCard>[
        testAgedRemainder(stockDate: CalendarDay(2026, 9, 2)),
        testAgedRemainder(stockDate: CalendarDay(2026, 9, 2), itemKey: 'ITM-9'),
        testAgedRemainder(stockDate: CalendarDay(2026, 8, 28)),
      ]);
      await pumpShell(tester, aged: aged, masterData: masterData);

      // ★ **يومان لا ثلاثةُ بنود** — ⛔ **والعدّادُ يجيب «كم يوماً لم يُقفَل؟».**
      expect(agedRow(tester).count, 2);
      expect(agedRow(tester).countLabel, isNull);
      expect(find.textContaining('منذ 7 أيام'), findsOneWidget);
    });

    testWidgets('⛔⛔★★ والحالةُ الهادئة تُعرَض ولا تُخفى — §7',
        (WidgetTester tester) async {
      aged.emit(const <AgedRemainderCard>[]);
      await pumpShell(tester, aged: aged, masterData: masterData);

      expect(agedRow(tester).count, 0);
      expect(agedRow(tester).countLabel, 'لا شيء');
      // ⛔ **والصفُّ باقٍ ظاهراً** — ★ **فاختفاؤه يجعل المستخدم يشكّ.**
      expect(find.text('متبقي أيام سابقة'), findsOneWidget);
    });

    testWidgets('★ والرفضُ يُقال «تعذّر» ⛔ لا صفراً كاذباً',
        (WidgetTester tester) async {
      aged.emitError(StateError('permission-denied'));
      await pumpShell(tester, aged: aged, masterData: masterData);

      // ⛔⛔ **ولا يُقاس بنصٍّ في الشاشة** — ★ **فصفُّ المركز المعلّق يقول
      //    «تعذّر» كذلك في هذه البيئة**: ⟵ **والقياسُ على عقد الصفّ نفسِه.**
      expect(agedRow(tester).countLabel, 'تعذّر');
    });
  });

  testWidgets('★ وحبّةُ الحدّة تحمل نصّها لا لونَها وحده',
      (WidgetTester tester) async {
    aged.emit(<AgedRemainderCard>[
      testAgedRemainder(stockDate: CalendarDay(2026, 8, 28)),
    ]);
    await pumpScreen(tester, aged: aged, masterData: masterData);

    final StatusPill pill = tester.widget<StatusPill>(find.byType(StatusPill));
    expect(pill.label, 'منذ 7 أيام');
    expect(pill.triad, SemanticTriads.danger);
  });
}

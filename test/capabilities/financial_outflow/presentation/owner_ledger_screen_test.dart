/// شاشة ضمار المالك وحركة النقد — `WU-016` · `M15`.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⚠️⚠️ **وما تُثبته هذه الاختبارات وما لا تُثبته:**
/// ★ **تُثبت أن البطاقة تُبنى حسب صلاحيات قارئها فعلاً** (`FR-M15-10` ·
/// `E-29`)، وأن **«كل المصادر» تُجمَع من بطاقات مصادر القارئ لا من المستند
/// التجميعي** لمن ليس نطاقُه شاملاً (`FR-M15-09` · `E-36`)، وأن **يوماً بلا
/// ملخّصٍ يُعرَض بأصفارٍ صريحة لا شاشةً فارغة** (§9)، وأن **حركة النقد بطاقةٌ
/// مستقلة تحمل سطرَ الفرق بين «الواصل» و«المقبوض»** (`AT-49` · `GR-41`).
///
/// ⛔ **ولا تُثبت أن القراءة محميّة** — ★ **الحمايةُ شرطُ القراءة في
/// `firestore.rules`**، ولها اختباراتها على المحاكي (`RISK-02`).
/// ═══════════════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qtms/app/router.dart';
import 'package:qtms/capabilities/financial_outflow/application/owner_ledger_providers.dart';
import 'package:qtms/capabilities/financial_outflow/presentation/owner_ledger_actions.dart';
import 'package:qtms/capabilities/financial_outflow/presentation/owner_ledger_screen.dart';
import 'package:qtms/capabilities/oversight/application/messaging_providers.dart';
import 'package:qtms/core/messages/error_messages.dart';
import 'package:qtms/capabilities/identity_access/application/session_providers.dart';
import 'package:qtms/capabilities/master_data/application/master_data_providers.dart';
import 'package:qtms_domain/qtms_domain.dart';

import '../../../support/fake_identity.dart';
import '../../../support/fake_master_data.dart';
import '../../../support/fake_messaging.dart';
import '../../../support/fake_owner_ledger.dart';

/// ★★ **اليوم مثبَّت** — ⛔ **فلا اختبارَ ينكسر بمرور منتصف الليل.**
final CalendarDay fixedDay = CalendarDay(2026, 8, 20);

const String radaa = 'SRC-001';
const String mawiyah = 'SRC-002';

late FakeOwnerLedgerDirectory ledger;
late FakeCashMovementReader cash;
late FakeMasterDataDirectory masterData;
late FakeShare sharer;

const Set<Permission> fullPermissions = <Permission>{
  Permission.ownerLedgerView,
  Permission.allSourcesCardView,
  Permission.withdrawalView,
  Permission.expenseView,
  Permission.receiptDepositView,
};

/// ⛔⛔★★★ **بلا «عرض سحبيات المالك»** — ★ **وهي جوهر `E-29`.**
const Set<Permission> withoutWithdrawals = <Permission>{
  Permission.ownerLedgerView,
  Permission.allSourcesCardView,
  Permission.expenseView,
};

OwnerLedgerSummary summaryOf({
  required String sourceId,
  int credit = 518100,
  int cash = 27450,
  int settled = 149500,
  int discounts = 5000,
  int tax = 8125,
  int withdrawals = 20000,
  int expenses = 5000,
}) =>
    computeOwnerLedgerSummary(
      sourceId: sourceId,
      date: fixedDay,
      contributions: OwnerLedgerContributions(
        credit: Money(credit),
        cash: Money(cash),
        settledOfDay: Money(settled),
        discounts: Money(discounts),
        tax: Money(tax),
        withdrawals: Money(withdrawals),
        expenses: Money(expenses),
      ),
    );

Future<void> pumpScreen(
  WidgetTester tester, {
  Set<Permission> actorPermissions = fullPermissions,
  SourceScope scope = const AllSources(),
}) async {
  final FakeAuthRepository auth = FakeAuthRepository();
  final FakeUserCardRepository cards = FakeUserCardRepository();
  auth.emitIdentity(
    AuthenticatedIdentity(userId: 'U-001', sourceScope: scope),
  );
  cards.emitCard('U-001', testCard(permissions: actorPermissions));

  tester.view.physicalSize = const Size(1200, 3600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

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
        documentShareProvider.overrideWithValue(sharer),
      ],
      child: const MaterialApp(
        locale: Locale('ar'),
        home: OwnerLedgerScreen(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 20));
}

Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  setUp(() {
    ledger = FakeOwnerLedgerDirectory();
    cash = FakeCashMovementReader();
    sharer = FakeShare();
    masterData = FakeMasterDataDirectory()
      ..emitSources(<SourceCard>[
        const SourceCard(
          sourceId: radaa,
          name: 'رداع',
          requiresSupplierOnIntake: false,
          isActive: true,
        ),
        const SourceCard(
          sourceId: mawiyah,
          name: 'ماوية',
          requiresSupplierOnIntake: false,
          isActive: true,
        ),
      ]);
  });

  group('★★★ البطاقة تُبنى حسب صلاحيات قارئها — FR-M15-10 · E-29', () {
    testWidgets('من يملك المفتاحين يرى البندين والصافي الكامل', (
      WidgetTester tester,
    ) async {
      await pumpScreen(tester);
      ledger.emitSummary(allSourcesScopeId, summaryOf(sourceId: 'all'));
      await settle(tester);

      // ★ **مرتان: بندٌ في البطاقة وبندٌ في حركة النقد** — ⟵ **وكلاهما
      //   محكومٌ بالمفتاح نفسِه** (`E-29`: «**من البطاقة والنقد**»).
      expect(find.text('السحبيات'), findsNWidgets(2));
      expect(find.text('الخرجيات'), findsNWidgets(2));
      expect(find.text('330,475'), findsWidgets);
    });

    testWidgets('⛔ ومن لا يملك «عرض سحبيات المالك» لا يُرسَم له البند', (
      WidgetTester tester,
    ) async {
      await pumpScreen(tester, actorPermissions: withoutWithdrawals);
      ledger.emitSummary(allSourcesScopeId, summaryOf(sourceId: 'all'));
      await settle(tester);

      // ⛔⛔ **ويختفي من الموضعين معاً** — `E-29` نصّاً.
      expect(find.text('السحبيات'), findsNothing);
      expect(find.text('الخرجيات'), findsNWidgets(2));
      // ★★ **والصافي يختلف — سلوكٌ مقصود لا خلل** (§5).
      expect(find.text('350,475'), findsWidgets);
      expect(find.text('330,475'), findsNothing);
    });
  });

  group('⛔⛔★★★ «كل المصادر» — E-36 · FR-M15-09', () {
    testWidgets('صاحبُ النطاق الشامل يقرأ المستند التجميعي', (
      WidgetTester tester,
    ) async {
      await pumpScreen(tester);
      ledger.emitSummary(
        allSourcesScopeId,
        summaryOf(sourceId: 'all', credit: 100000, settled: 0, discounts: 0,
            tax: 0, withdrawals: 0, expenses: 0, cash: 0),
      );
      await settle(tester);
      expect(find.text('100,000'), findsWidgets);
    });

    testWidgets('⛔ ومَن نطاقُه مصادرُ بعينها تُجمَع له من مصادره وحدها', (
      WidgetTester tester,
    ) async {
      await pumpScreen(
        tester,
        scope: ScopedSources(<String>{radaa, mawiyah}),
      );
      // ⛔⛔ **ولا يُقرأ المستند التجميعي إطلاقاً** — ★ **ولو وُضع فيه رقم.**
      ledger.emitSummary(
        allSourcesScopeId,
        summaryOf(sourceId: 'all', credit: 999999, settled: 0, discounts: 0,
            tax: 0, withdrawals: 0, expenses: 0, cash: 0),
      );
      ledger.emitSummary(
        radaa,
        summaryOf(sourceId: radaa, credit: 60000, settled: 0, discounts: 0,
            tax: 0, withdrawals: 0, expenses: 0, cash: 0),
      );
      ledger.emitSummary(
        mawiyah,
        summaryOf(sourceId: mawiyah, credit: 40000, settled: 0, discounts: 0,
            tax: 0, withdrawals: 0, expenses: 0, cash: 0),
      );
      await settle(tester);

      expect(find.text('100,000'), findsWidgets);
      expect(find.text('999,999'), findsNothing);
    });
  });

  group('★ يومٌ بلا ملخّص — §9 · ui-guidelines نمط 1', () {
    testWidgets('يُعرَض بأصفارٍ صريحة لا بشاشةٍ فارغة', (
      WidgetTester tester,
    ) async {
      await pumpScreen(tester);
      ledger.emitSummary(allSourcesScopeId, null);
      await settle(tester);

      expect(find.text('ضمار المالك — اليوم'), findsOneWidget);
      expect(find.text('0'), findsWidgets);
    });
  });

  group('⛔⛔★★★ حركة النقد بطاقةٌ مستقلة — AT-49 · GR-41', () {
    testWidgets('تحمل سطرَ الفرق بين «الواصل» و«المقبوض»', (
      WidgetTester tester,
    ) async {
      await pumpScreen(tester);
      ledger.emitSummary(allSourcesScopeId, summaryOf(sourceId: 'all'));
      await settle(tester);
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('حركة النقد في التاريخ'), findsOneWidget);
      expect(
        find.textContaining('المقبوض ≠ الواصل'),
        findsOneWidget,
      );
    });

    testWidgets('★ والنطاقُ يُمرَّر كما هو — والفائضُ العام لـ«الكل» وحدها', (
      WidgetTester tester,
    ) async {
      await pumpScreen(tester, scope: ScopedSources(<String>{radaa, mawiyah}));
      ledger.emitSummary(radaa, summaryOf(sourceId: radaa));
      ledger.emitSummary(mawiyah, summaryOf(sourceId: mawiyah));
      await settle(tester);
      await tester.pump(const Duration(milliseconds: 50));

      expect(cash.lastSourceIds, <String>[radaa, mawiyah]);
      expect(cash.lastIncludesUnscopedSurplus, isTrue);
      expect(cash.lastReadsDeposit, isTrue);
    });

    testWidgets('⛔ ولا تُقرأ حالةُ الإيداع بلا مفتاحها — ADR-0017', (
      WidgetTester tester,
    ) async {
      await pumpScreen(tester, actorPermissions: withoutWithdrawals);
      ledger.emitSummary(allSourcesScopeId, summaryOf(sourceId: 'all'));
      await settle(tester);
      await tester.pump(const Duration(milliseconds: 50));

      expect(cash.lastReadsDeposit, isFalse);
      expect(find.textContaining('أُودع'), findsNothing);
    });
  });

  // ══════════════ `AM-023` — مراجعةُ تجربة الاستخدام ══════════════

  group('⛔⛔★★★ AM-023 ① — لا نصَّ استثناءٍ خامّ للمستخدم', () {
    testWidgets('البطاقةُ الرئيسية تعرض رسالةً بشرية والخامُّ مطويٌّ', (
      WidgetTester tester,
    ) async {
      await pumpScreen(tester);
      ledger.emitSummaryError(
        allSourcesScopeId,
        StateError('PERMISSION_DENIED: Missing or insufficient permissions'),
      );
      await settle(tester);

      expect(find.text(readRejectionMessage), findsOneWidget);

      // ⛔⛔ **والخامُّ مطويٌّ حتى يُطلَب** — ★ **ولا يُبتلَع كذلك:**
      //    ⟵ **والطيُّ يُقاس بحالة [AnimatedCrossFade] نفسِها**، ⛔ **لا
      //    بغياب النصّ من الشجرة** (**كلا الطفلين فيها دائماً**).
      AnimatedCrossFade fold() =>
          tester.widget<AnimatedCrossFade>(find.byType(AnimatedCrossFade));
      expect(fold().crossFadeState, CrossFadeState.showFirst);
      expect(find.text('تفاصيل تقنية'), findsOneWidget);
      expect(find.textContaining('PERMISSION_DENIED'), findsOneWidget);

      await tester.tap(find.text('تفاصيل تقنية'));
      await tester.pumpAndSettle();
      expect(fold().crossFadeState, CrossFadeState.showSecond);
      expect(find.text('إخفاء التفاصيل التقنية'), findsOneWidget);
    });
  });

  group('★★★ AM-023 ② و③ — الإجراءان موصولان في الشاشة المستقلة', () {
    testWidgets('أيقونةُ المشاركة تُسلِّم ملخّصَ اليوم نصّاً', (
      WidgetTester tester,
    ) async {
      await pumpScreen(tester);
      ledger.emitSummary(allSourcesScopeId, summaryOf(sourceId: 'all'));
      await settle(tester);

      await tester.tap(find.byTooltip('مشاركة ملخص اليوم'));
      await tester.pumpAndSettle();

      expect(sharer.sharedTexts, hasLength(1));
      final String text = sharer.sharedTexts.single;
      // ★ **ما يُشارَك هو ما يُقرأ حرفياً** — ⛔ **ولا رقمَ يُبنى في النصّ.**
      expect(text, contains('الصافي النهائي: 330,475 ريال'));
      expect(text, contains('السحبيات: 20,000'));
    });

    testWidgets('⛔⛔ والبندُ المحكومُ يغيب عن النصّ كما يغيب عن البطاقة — E-29', (
      WidgetTester tester,
    ) async {
      await pumpScreen(tester, actorPermissions: withoutWithdrawals);
      ledger.emitSummary(allSourcesScopeId, summaryOf(sourceId: 'all'));
      await settle(tester);

      await tester.tap(find.byTooltip('مشاركة ملخص اليوم'));
      await tester.pumpAndSettle();

      final String text = sharer.sharedTexts.single;
      expect(text, isNot(contains('السحبيات')));
      expect(text, contains('الخرجيات: 5,000'));
    });

    testWidgets('★ وسهمُ التفكيك مرسومٌ على الصفوف — §7.1 القاعدة 5', (
      WidgetTester tester,
    ) async {
      await pumpScreen(tester);
      ledger.emitSummary(allSourcesScopeId, summaryOf(sourceId: 'all'));
      await settle(tester);

      // ★ **والسهمُ لا يُرسَم إلا حين `onRowTap != null`** — ⟵ **فوجودُه
      //   دليلُ التوصيل نفسِه.**
      expect(find.byIcon(Icons.chevron_left), findsWidgets);
    });
  });

  group('★★ AM-023 ③ — خريطةُ الوجهات واحدةٌ للموضعين', () {
    test('كلُّ صفٍّ يفتح وجهتَه حين يملك القارئُ مفتاحَها', () {
      const Set<Permission> all = <Permission>{
        Permission.dealerStatementView,
        Permission.receiptCreate,
        Permission.discountCreate,
        Permission.sackView,
        Permission.withdrawalCreate,
      };
      bool can(Permission p) => all.contains(p);
      expect(
        ownerLedgerRowRoute('إجمالي الضمار', can: can),
        dealerStatementRoute,
      );
      expect(ownerLedgerRowRoute('الواصل', can: can), receiptRoute);
      expect(ownerLedgerRowRoute('الخصومات', can: can), discountRoute);
      expect(
        ownerLedgerRowRoute('إجمالي الضريبة', can: can),
        sackFinanceRoute,
      );
      expect(ownerLedgerRowRoute('السحبيات', can: can), outflowRoute);
    });

    test('⛔⛔ ومن لا يملك المفتاح تُفتَح له شاشةُ الضمار — لا شاشةُ رفض', () {
      bool none(Permission _) => false;
      for (final String label in <String>[
        'إجمالي الضمار',
        'الواصل',
        'الخصومات',
        'إجمالي الضريبة',
        'السحبيات',
        'الخرجيات',
        'بندٌ لا مدخلَ له',
      ]) {
        expect(
          ownerLedgerRowRoute(label, can: none),
          ownerLedgerRoute,
          reason: label,
        );
      }
    });
  });
}

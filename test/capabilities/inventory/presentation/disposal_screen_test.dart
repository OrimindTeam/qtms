/// شاشة الإتلاف — `WU-020` (`FR-M8-16`).
///
/// ⚠️⚠️ **وما تُثبته هذه الاختبارات وما لا تُثبته:** تُثبت أن الشاشة
/// **بلا حقلٍ ماليٍّ واحد** (`FR-M8-16` — **أخطر ما في الوحدة**)، وأن
/// **التحذير معروضٌ قبل الحفظ** (`FR-M8-16` نصّاً)، وأن **المصدر إلزاميٌّ
/// قبل أي بند** (`ADR-0005`)، وأن **الخيارات من أرصدة الدفتر** ([`DEBT-86`])،
/// وأن **السبب اختياريٌّ ولا يُعبَّأ نيابةً عن المستخدم** (`ADR-0020`)، وأن
/// **من لا يملك `disposalCreate` لا يرى النموذج أصلاً**.
/// ⛔ **ولا تُثبت أن الكتابة محميّة** — ★ **الحماية في `planDisposal`**،
/// ولها اختباراتها هناك (`functions/test/disposal_test.dart`).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qtms/capabilities/identity_access/application/session_providers.dart';
import 'package:qtms/capabilities/inventory/application/disposal_providers.dart';
import 'package:qtms/capabilities/inventory/application/inventory_providers.dart';
import 'package:qtms/capabilities/inventory/presentation/disposal_screen.dart';
import 'package:qtms/capabilities/master_data/application/master_data_providers.dart';
import 'package:qtms/core/design/design_tokens.dart';
import 'package:qtms/core/messages/error_messages.dart';
import 'package:qtms/core/ui/sticky_action_bar.dart';
import 'package:qtms_domain/qtms_domain.dart';

import '../../../support/fake_disposal.dart';
import '../../../support/fake_identity.dart';
import '../../../support/fake_inventory.dart';
import '../../../support/fake_master_data.dart';

/// ★★ **اليوم مثبَّت** — ⛔ **فلا اختبارَ ينكسر بمرور منتصف الليل.**
final CalendarDay fixedDay = CalendarDay(2026, 9, 4);

late FakeDisposalDirectory directory;
late FakeDisposalAdminRepository admin;
late FakeMasterDataDirectory masterData;
late FakeInventoryDirectory inventory;

const Set<Permission> fullPermissions = <Permission>{
  Permission.disposalCreate,
  Permission.agedRemainderClear,
};

Future<void> pumpDisposal(
  WidgetTester tester, {
  Set<Permission> actorPermissions = fullPermissions,
}) async {
  final FakeAuthRepository auth = FakeAuthRepository();
  final FakeUserCardRepository cards = FakeUserCardRepository();
  auth.emitIdentity(
    const AuthenticatedIdentity(userId: 'U-001', sourceScope: AllSources()),
  );
  cards.emitCard('U-001', testCard(permissions: actorPermissions));

  // ★★ **نافذةٌ طويلة عمداً** — ⛔ **فالقائمة تُبنى كسولاً في المقاس
  //   الافتراضي**: ⟵ **فيقع زرُّ الإضافة خارجها فلا يوجد في الشجرة.**
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
        // ⛔⛔★★★ **ودليلُ المخزون إلزاميٌّ** — [`DEBT-86`]: ★ **خياراتُ النوع
        //    من أرصدة الدفتر**، ⟵ **وبلا بثٍّ لا خيارَ في المنسدل.**
        inventoryDirectoryProvider.overrideWithValue(inventory),
        inventoryAdminProvider.overrideWithValue(FakeInventoryAdmin()),
        disposalDirectoryProvider.overrideWithValue(directory),
        disposalAdminProvider.overrideWithValue(admin),
        todayProvider.overrideWithValue(fixedDay),
      ],
      child: const MaterialApp(
        locale: Locale('ar'),
        home: DisposalScreen(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 20));
}

Future<void> scrollTo(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 2000));
    await tester.pumpAndSettle();
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Future<void> tapAddLine(WidgetTester tester) async {
  final Finder wrapper = find.byKey(const Key('disposal-add-line'));
  await scrollTo(tester, wrapper);
  await tester.tap(
    find.descendant(of: wrapper, matching: find.byType(OutlinedButton)),
  );
  await tester.pumpAndSettle();
}

Future<void> chooseSource(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('disposal-source')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('مصدر رداع').last);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    directory = FakeDisposalDirectory();
    admin = FakeDisposalAdminRepository();
    masterData = FakeMasterDataDirectory();
    masterData.emitSources(<SourceCard>[testSource()]);
    masterData.emitItems(<ItemCard>[
      testItem(itemId: 'ITM-0001', name: 'عوارض'),
    ]);
    inventory = FakeInventoryDirectory();
    inventory.emitStock(<ItemDailyBalanceCard>[
      testBalance(itemKey: 'ITM-0001', itemName: 'عوارض'),
    ]);
  });

  tearDown(() {
    directory.dispose();
    inventory.dispose();
  });

  group('★★★ FR-M8-16 — التحذير الصريح ولا حقلَ ماليّ', () {
    testWidgets('★★ التحذيرُ معروضٌ قبل أي إدخال', (WidgetTester tester) async {
      await pumpDisposal(tester);
      await chooseSource(tester);

      expect(
        find.textContaining('بلا أي قيمة مالية ولا استحقاق'),
        findsWidgets,
      );
    });

    testWidgets('⛔⛔★★★ ولا حقلَ سعرٍ في الصفّ إطلاقاً',
        (WidgetTester tester) async {
      await pumpDisposal(tester);
      await chooseSource(tester);
      await tapAddLine(tester);

      expect(find.byKey(const Key('disposal-qty-0')), findsOneWidget);
      // ⛔⛔★★★ **ولا حقلَ سعرٍ ولا مبلغٍ في الصفّ** — ★ **حقلٌ واحدٌ لا
      //    حقلان** (بخلاف صفّ السحبية): ⟵ **والقياسُ على عدد حقول الصفّ**
      //    ⛔ **لا على نصٍّ قد يرد في تحذير الشاشة نفسِه.**
      expect(find.byKey(const Key('disposal-price-0')), findsNothing);
      expect(find.text('سعر الوحدة'), findsNothing);
      // ⛔ **ولا مبلغَ ولا عملةَ في أي مكان من الشاشة.**
      expect(find.textContaining('ريال'), findsNothing);
    });

    testWidgets('★★ والحصيلةُ كمياتٌ لا مبالغ — GR-19',
        (WidgetTester tester) async {
      await pumpDisposal(tester);
      await chooseSource(tester);

      expect(find.textContaining('إجمالي المُتلَف'), findsOneWidget);
      expect(find.textContaining('حبة'), findsWidgets);
    });
  });

  group('★★★ المصدر إلزاميٌّ قبل أي بند — ADR-0005', () {
    testWidgets('⛔ وبلا مصدرٍ لا نموذج', (WidgetTester tester) async {
      await pumpDisposal(tester);

      expect(find.text('اختر المصدر'), findsOneWidget);
      expect(find.byKey(const Key('disposal-add-line')), findsNothing);
    });

    testWidgets('✅ واختيارُه يفتح النموذج', (WidgetTester tester) async {
      await pumpDisposal(tester);
      await chooseSource(tester);

      expect(find.byKey(const Key('disposal-add-line')), findsOneWidget);
      expect(find.byKey(const Key('disposal-save')), findsOneWidget);
    });
  });

  group('★★★ الصلاحية تُخفي لا تُعطِّل — RISK-02', () {
    testWidgets('⛔ وبلا `disposalCreate` لا يُعرَض النموذج',
        (WidgetTester tester) async {
      await pumpDisposal(tester, actorPermissions: const <Permission>{});

      expect(find.text('لا صلاحية'), findsOneWidget);
      expect(find.byKey(const Key('disposal-source')), findsNothing);
    });
  });

  group('★★★ الحفظ — ما يصل المستودع', () {
    testWidgets('✅★★ سطرٌ بكميةٍ يُرسَل بلا سعرٍ ولا تاريخٍ مثبَّت',
        (WidgetTester tester) async {
      await pumpDisposal(tester);
      await chooseSource(tester);
      await tapAddLine(tester);

      await tester.tap(find.byKey(const Key('disposal-qty-0')));
      await tester.enterText(find.byKey(const Key('disposal-qty-0')), '4');
      await tester.pumpAndSettle();

      // ★ اختيارُ النوع من المنسدل.
      await tester.tap(find.text('النوع').last);
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('عوارض').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('disposal-save')));
      await tester.pumpAndSettle();

      expect(admin.created, hasLength(1));
      final CreatedDisposal request = admin.created.single;
      expect(request.sourceId, 'SRC-001');
      expect(request.lines.single.itemId, 'ITM-0001');
      expect(
        request.lines.single.quantity,
        const PieceQuantity(PieceCount(4)),
      );
      // ⛔⛔★★★ **ولا تاريخَ يُرسَل في المسار العادي** — ★ **يومُ المخزون
      //    من المنصّة** (`GR-54` · `E-41`).
      expect(request.stockDate, isNull);
      // ✅★★ **ولا سببَ يُعبَّأ نيابةً عن المستخدم** — `ADR-0020`.
      expect(request.reason, anyOf(isNull, isEmpty));
    });

    testWidgets('⛔ وبلا سطرٍ صالح لا يُرسَل شيء ورسالةٌ تقول ما ينقص',
        (WidgetTester tester) async {
      await pumpDisposal(tester);
      await chooseSource(tester);

      await tester.tap(find.byKey(const Key('disposal-save')));
      await tester.pumpAndSettle();

      expect(admin.created, isEmpty);
      expect(find.textContaining('أضف نوعاً واحداً'), findsOneWidget);
    });
  });

  group('⛔⛔★★★ AM-021 ④ — سطرُ الحالة بثلاثيةٍ لونية لا نصٌّ عارٍ', () {
    /// ★ يقرأ لافتةَ الحالة من شريط الإجراء الثابت — و`null` حين لا حالة.
    QtmsActionStatus? statusOf(WidgetTester tester) {
      final Finder banner = find.byType(QtmsActionStatus);
      if (banner.evaluate().isEmpty) return null;
      return tester.widget<QtmsActionStatus>(banner);
    }

    testWidgets('★★★ والفشلُ بثلاثية `danger` وأيقونةٍ متجهية',
        (WidgetTester tester) async {
      // ⛔⛔ **وكان `Text` عارياً يحمل «❌»** — ★ **والإيموجي يتبع خطَّ الجهاز
      //   ولا يُلوَّن ولا يرث المقاس** (`design-system.md` §8 المحظور 12).
      await pumpDisposal(tester);
      await chooseSource(tester);

      await tester.tap(find.byKey(const Key('disposal-save')));
      await tester.pumpAndSettle();

      final QtmsActionStatus? status = statusOf(tester);
      expect(status, isNotNull);
      expect(status!.triad, SemanticTriads.danger);
      expect(status.icon, Icons.error_outline);
      expect(status.message, 'أضف نوعاً واحداً على الأقل بكميةٍ أكبر من صفر.');
      // ⛔ **ولا رمزَ إيموجي في النصّ بعد اليوم.**
      expect(status.message.contains('❌'), isFalse);
      expect(find.textContaining('❌'), findsNothing);
    });

    testWidgets('★★★ والنجاحُ بثلاثية `success` ⛔ بلا «✅» إيموجي',
        (WidgetTester tester) async {
      await pumpDisposal(tester);
      await chooseSource(tester);
      await tapAddLine(tester);

      await tester.tap(find.byKey(const Key('disposal-qty-0')));
      await tester.enterText(find.byKey(const Key('disposal-qty-0')), '4');
      await tester.pumpAndSettle();
      await tester.tap(find.text('النوع').last);
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('عوارض').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('disposal-save')));
      await tester.pumpAndSettle();

      final QtmsActionStatus? status = statusOf(tester);
      expect(status, isNotNull);
      expect(status!.triad, SemanticTriads.success);
      expect(status.icon, Icons.check_circle_outline);
      expect(status.message, 'سُجِّل الإتلاف DSP-20260904-0001');
      expect(find.textContaining('✅'), findsNothing);
    });

    testWidgets('★★ ورفضُ السحابة يُعرَض بنصّ الكتالوج بثلاثية `danger`',
        (WidgetTester tester) async {
      admin.nextResult = const Failure<String>(ValidationError('BR-M8-XX'));
      await pumpDisposal(tester);
      await chooseSource(tester);
      await tapAddLine(tester);

      await tester.tap(find.byKey(const Key('disposal-qty-0')));
      await tester.enterText(find.byKey(const Key('disposal-qty-0')), '4');
      await tester.pumpAndSettle();
      await tester.tap(find.text('النوع').last);
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('عوارض').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('disposal-save')));
      await tester.pumpAndSettle();

      final QtmsActionStatus? status = statusOf(tester);
      expect(status, isNotNull);
      expect(status!.triad, SemanticTriads.danger);
      expect(status.message, catalogText(CatalogMessage.operationFailed));
    });
  });

  group('★★ ADR-0020 — حقلُ السبب مَوْسومٌ «اختياري»', () {
    testWidgets('★ ويُعرَض صراحةً لا ضمناً', (WidgetTester tester) async {
      await pumpDisposal(tester);
      await chooseSource(tester);
      await scrollTo(tester, find.byKey(const Key('disposal-reason')));

      expect(find.text('سبب الإتلاف'), findsOneWidget);
      expect(find.textContaining('اختياري'), findsOneWidget);
    });
  });
}

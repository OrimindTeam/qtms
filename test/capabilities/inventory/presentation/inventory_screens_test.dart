/// شاشات المخزون — `WU-003`.
///
/// ⚠️⚠️ **وما تُثبته هذه الاختبارات وما لا تُثبته:** تُثبت أن **الواجهة
/// تُمرِّر ما كتبه المستخدم كما هو**، وأنها **لا تعرض ما يمنعه المتطلب**
/// (لا تاريخ · لا وزن · لا حذف)، وأنها **تعرض رفض السحابة بنصّه**.
/// ⛔ **ولا تُثبت أن الكتابة محميّة** — ★ **الحماية في `planInventory`
/// و`firestore.rules`**، ولها اختباراتها هناك (`inventory_test.dart`).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qtms/capabilities/identity_access/application/session_providers.dart';
import 'package:qtms/capabilities/inventory/application/inventory_providers.dart';
import 'package:qtms/capabilities/inventory/presentation/counted_intake_screen.dart';
import 'package:qtms/capabilities/inventory/presentation/today_stock_screen.dart';
import 'package:qtms/capabilities/master_data/application/master_data_providers.dart';
import 'package:qtms/core/messages/error_messages.dart';
import 'package:qtms/core/ui/async_state_view.dart';
import 'package:qtms/core/ui/context_header.dart';
import 'package:qtms_domain/qtms_domain.dart';

import '../../../support/fake_identity.dart';
import '../../../support/fake_inventory.dart';
import '../../../support/fake_master_data.dart';

/// ★ مفاتيح المخزون الثلاثة — فالاختبار يقيس **القاعدة لا نقصَ المفتاح**.
const Set<Permission> inventoryKeys = <Permission>{
  Permission.incomingCountWrite,
  Permission.incomingCountAmend,
  Permission.incomingCountCancel,
};

/// ★★ **اليوم مثبَّت** — ⛔ **فلا اختبارَ ينكسر بمرور منتصف الليل.**
final CalendarDay fixedDay = CalendarDay(2026, 8, 25);

Future<void> pumpScreen(
  WidgetTester tester, {
  required Widget screen,
  required FakeInventoryDirectory inventory,
  required FakeInventoryAdmin admin,
  required FakeMasterDataDirectory masterData,
  Set<Permission> actorPermissions = inventoryKeys,
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
        inventoryDirectoryProvider.overrideWithValue(inventory),
        inventoryAdminProvider.overrideWithValue(admin),
        todayProvider.overrideWithValue(fixedDay),
      ],
      child: MaterialApp(locale: const Locale('ar'), home: screen),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 20));
}

void main() {
  late FakeInventoryDirectory inventory;
  late FakeInventoryAdmin admin;
  late FakeMasterDataDirectory masterData;

  setUp(() {
    inventory = FakeInventoryDirectory();
    admin = FakeInventoryAdmin();
    masterData = FakeMasterDataDirectory();
    masterData.emitSources(<SourceCard>[testSource()]);
    masterData.emitItems(<ItemCard>[testItem()]);
    masterData.emitSuppliers(<SupplierCard>[
      SupplierCard(
        supplierId: 'SUP-0001',
        name: 'رعوي مثال',
        phone: '777111222',
        isActive: true,
        sourceIds: const <String>['SRC-001'],
      ),
    ]);
  });

  tearDown(() {
    inventory.dispose();
    masterData.dispose();
  });

  // ═══════════════════════════════════════════════════════════════════
  // مخزون اليوم — FR-M8
  // ═══════════════════════════════════════════════════════════════════

  group('★ مخزون اليوم — FR-M8', () {
    testWidgets('✅ تعرض الرصيد بوحدته والوارد والصادر', (WidgetTester t) async {
      inventory.emitStock(<ItemDailyBalanceCard>[testBalance()]);
      await pumpScreen(
        t,
        screen: const TodayStockScreen(),
        inventory: inventory,
        admin: admin,
        masterData: masterData,
      );
      expect(find.text('عود'), findsOneWidget);
      // ★ **الرصيد بوحدته** — `FR-M8-07` · `GR-19`.
      expect(find.text('100 حبة'), findsOneWidget);
      expect(find.text('وارد 120 حبة · صادر 20 حبة'), findsOneWidget);
    });

    testWidgets('★★★ FR-M8-05: تستعلم على تاريخ اليوم لا سواه',
        (WidgetTester t) async {
      inventory.emitStock(<ItemDailyBalanceCard>[testBalance()]);
      await pumpScreen(
        t,
        screen: const TodayStockScreen(),
        inventory: inventory,
        admin: admin,
        masterData: masterData,
      );
      // ⛔★★ **وهذا حارسُ `RISK-07` في الواجهة:** الاستعلام على **تاريخ
      //    المخزون** لا تاريخ الإدخال، **ولليوم الجاري وحده**.
      expect(inventory.lastStockDate, fixedDay);
      expect(inventory.lastSourceId, 'SRC-001');
    });

    testWidgets('★★ FR-M8-05: ⛔ ولا متصفّح تاريخ في الشاشة',
        (WidgetTester t) async {
      inventory.emitStock(<ItemDailyBalanceCard>[testBalance()]);
      await pumpScreen(
        t,
        screen: const TodayStockScreen(),
        inventory: inventory,
        admin: admin,
        masterData: masterData,
      );
      // ★ **رأس السياق يُخبر لماذا** — ⛔ **ولا زرَّ تاريخ.**
      //
      // ⚠️★★ **وصيغةُ العرض تغيّرت بـ`P3`** (`ADR-0021` · `MASTER.md` §5b):
      //    ★ **كانت لافتةً مستقلة بجملةٍ كاملة، وصارت التاريخَ داخل صفّ
      //    السياق نفسِه** ⟵ **صفٌّ واحد بدل صفّين.** ⛔ **والضمانةُ لم
      //    تُخفَّف بحرف:** ★ **التاريخ ظاهرٌ، والقفلُ ظاهرٌ، وسببُ القفل
      //    يصل قارئَ الشاشة كاملاً** — ⟵ **فما يُثبته الاختبار هو ما كان
      //    يُثبته**، ⛔ **والتغيير في الموضع لا في القاعدة.**
      expect(find.text('2026/08/25'), findsOneWidget);
      // ★ **ولا معنى باللون وحده** (§8) — أيقونةُ القفل مع النصّ.
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      // ★★ **وسببُ القفل يبلغ TalkBack** — ⟵ **فلا يُفقَد بانتقاله من
      //    نصٍّ مرئي إلى وصفٍ دلالي.**
      expect(
        find.bySemanticsLabel(
          'تاريخ اليوم 2026/08/25 — من الخادم ولا يُغيَّر',
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.calendar_today), findsNothing);
      expect(find.byIcon(Icons.date_range), findsNothing);
    });

    testWidgets('★★★ FR-M8-07 · E-31: إجماليان منفصلان ⛔ ولا ثالثٌ يجمعهما',
        (WidgetTester t) async {
      inventory.emitStock(<ItemDailyBalanceCard>[
        testBalance(),
        testWeightBalance(),
      ]);
      await pumpScreen(
        t,
        screen: const TodayStockScreen(),
        inventory: inventory,
        admin: admin,
        masterData: masterData,
      );
      expect(find.text('إجمالي المعدود: 100 حبة'), findsOneWidget);
      expect(find.text('إجمالي الوزني: 2.500 كجم'), findsOneWidget);
      // ⛔ **ولا سطرَ «الإجمالي»** — ★ **الجمع بين الوحدتين ممنوع.**
      expect(find.textContaining('الإجمالي:'), findsNothing);
    });

    testWidgets('★★ ولا واجهة تُعدِّل الرصيد مباشرة — FR-M8-03 · GR-01',
        (WidgetTester t) async {
      inventory.emitStock(<ItemDailyBalanceCard>[testBalance()]);
      await pumpScreen(
        t,
        screen: const TodayStockScreen(),
        inventory: inventory,
        admin: admin,
        masterData: masterData,
      );
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(TextFormField), findsNothing);
      expect(find.byIcon(Icons.edit_outlined), findsNothing);
    });

    testWidgets('★★ والرفض يُعرَض ⛔ لا كقائمة فارغة', (WidgetTester t) async {
      inventory.emitStockError(Exception('permission-denied'));
      await pumpScreen(
        t,
        screen: const TodayStockScreen(),
        inventory: inventory,
        admin: admin,
        masterData: masterData,
      );
      expect(
        find.text('تحقق من صلاحيتك ونطاق مصادرك، ثم أعد المحاولة.'),
        findsOneWidget,
      );
      expect(find.text('لا يوجد مخزون لهذا المصدر اليوم.'), findsNothing);
    });

    testWidgets('★★ FR-M8-06: النقر يفتح سجل حركة النوع بالرصيد التراكمي',
        (WidgetTester t) async {
      inventory.emitStock(<ItemDailyBalanceCard>[testBalance()]);
      inventory.emitMovements(<StockMovementCard>[
        testMovement(),
        testMovement(isCancelled: true, quantity: 5),
      ]);
      await pumpScreen(
        t,
        screen: const TodayStockScreen(),
        inventory: inventory,
        admin: admin,
        masterData: masterData,
      );
      await t.tap(find.text('عود'));
      await t.pumpAndSettle();

      expect(find.text('حركة عود — 2026/08/25'), findsOneWidget);
      expect(find.text('دخول 120 حبة'), findsOneWidget);
      // ★ **الملغاة تُعرَض ولا تختفي** — `A-14`.
      expect(find.text('ملغى'), findsOneWidget);
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // الوارد عدداً — FR-M6
  // ═══════════════════════════════════════════════════════════════════

  group('★★★ P3 — رأس السياق الموحّد (ADR-0021 · MASTER.md §5b)', () {
    testWidgets('★ صفٌّ واحد: قائمةٌ منسدلة + يومٌ مقفل — ⛔ ولا شرائح تلتفّ',
        (WidgetTester t) async {
      await pumpScreen(
        t,
        screen: const CountedIntakeScreen(),
        inventory: inventory,
        admin: admin,
        masterData: masterData,
      );

      // ★★ **رأسٌ واحد للشاشة** — ⛔ **ولا `SourcePicker` ولا لافتةٌ ثانية.**
      expect(find.byType(QtmsContextHeader), findsOneWidget);
      expect(find.text('2026/08/25'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      // ⛔⛔ **ولا شريحةَ مصدرٍ واحدة في الرأس** — ★ **وهي ما كان يلتفّ.**
      expect(find.byType(ChoiceChip), findsNothing);
    });

    testWidgets('⛔⛔★★★ ولا فراغٌ صامت بلا مصدر — حالةٌ مصمَّمة',
        (WidgetTester t) async {
      // ★ **نطاقٌ بلا مصادر** — ⟵ **وهي الحالة التي كانت تُعرَض
      //   `SizedBox.shrink`**: ⛔ **شاشةٌ بيضاء تُقرأ عطلاً** (§هـ).
      masterData.emitSources(const <SourceCard>[]);
      await pumpScreen(
        t,
        screen: const CountedIntakeScreen(),
        inventory: inventory,
        admin: admin,
        masterData: masterData,
      );

      expect(find.byType(QtmsEmptyState), findsOneWidget);
      expect(find.textContaining('لا يوجد مصدر ضمن نطاقك'), findsWidgets);
      // ⛔★★ **ولا زرَّ إضافةٍ بلا مصدر** — ★ **فلا يُفتَح نموذجٌ بلا سياق.**
      expect(find.text('وارد جديد'), findsNothing);
    });
  });

  group('★ الوارد عدداً — FR-M6', () {
    testWidgets('✅ تعرض مستندات اليوم بأرقامها وإجمالياتها',
        (WidgetTester t) async {
      inventory.emitIntakes(<CountedIntakeCard>[testIntake()]);
      await pumpScreen(
        t,
        screen: const CountedIntakeScreen(),
        inventory: inventory,
        admin: admin,
        masterData: masterData,
      );
      expect(find.text('INC-20260825-0001'), findsOneWidget);
      expect(find.text('1 نوع · 120 حبة'), findsOneWidget);
    });

    testWidgets('★★★ FR-M6-14 · GR-07: ⛔ ولا زر حذف إطلاقاً',
        (WidgetTester t) async {
      inventory.emitIntakes(<CountedIntakeCard>[testIntake()]);
      await pumpScreen(
        t,
        screen: const CountedIntakeScreen(),
        inventory: inventory,
        admin: admin,
        masterData: masterData,
      );
      expect(find.byIcon(Icons.delete), findsNothing);
      expect(find.byIcon(Icons.delete_outline), findsNothing);
      expect(find.byIcon(Icons.delete_forever), findsNothing);
      // ★ **والإلغاء موجود بديلاً عنه.**
      expect(find.byIcon(Icons.block_outlined), findsOneWidget);
    });

    testWidgets('★★ والملغى يُرى مشطوباً ⛔ ولا تُتاح أزراره',
        (WidgetTester t) async {
      inventory.emitIntakes(<CountedIntakeCard>[
        testIntake(status: CountedIntakeStatus.cancelled),
      ]);
      await pumpScreen(
        t,
        screen: const CountedIntakeScreen(),
        inventory: inventory,
        admin: admin,
        masterData: masterData,
      );
      expect(find.text('ملغى'), findsOneWidget);
      expect(find.byIcon(Icons.edit_outlined), findsNothing);
      expect(find.byIcon(Icons.block_outlined), findsNothing);
    });

    testWidgets('★ وشارة «مُعدَّل» تظهر على المستند المعدَّل — FR-M8-06',
        (WidgetTester t) async {
      inventory.emitIntakes(<CountedIntakeCard>[testIntake(amendCount: 2)]);
      await pumpScreen(
        t,
        screen: const CountedIntakeScreen(),
        inventory: inventory,
        admin: admin,
        masterData: masterData,
      );
      expect(find.text('مُعدَّل'), findsOneWidget);
    });

    testWidgets('★★ ولا يظهر زر الإنشاء بلا incomingCountWrite',
        (WidgetTester t) async {
      inventory.emitIntakes(<CountedIntakeCard>[]);
      await pumpScreen(
        t,
        screen: const CountedIntakeScreen(),
        inventory: inventory,
        admin: admin,
        masterData: masterData,
        actorPermissions: const <Permission>{},
      );
      expect(find.text('وارد جديد'), findsNothing);
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // نموذج الوارد — ⛔ لا تاريخ ولا وزن ولا سعر
  // ═══════════════════════════════════════════════════════════════════

  group('★★ نموذج الوارد — FR-M6-02 · FR-M6-10', () {
    Future<void> openForm(WidgetTester t, {bool requiresSupplier = true}) async {
      // ★ **إلزامية الرعوي من سجل المصدر** — `FR-M6-03` · `FR-M2-02`.
      masterData.emitSources(<SourceCard>[
        testSource(requiresSupplierOnIntake: requiresSupplier),
      ]);
      inventory.emitIntakes(<CountedIntakeCard>[]);
      await pumpScreen(
        t,
        screen: const CountedIntakeScreen(),
        inventory: inventory,
        admin: admin,
        masterData: masterData,
      );
      await t.tap(find.text('وارد جديد'));
      await t.pumpAndSettle();
    }

    testWidgets('⛔★★★ FR-M6-02 · E-40: لا حقل تاريخ في النموذج إطلاقاً',
        (WidgetTester t) async {
      await openForm(t);
      expect(find.text('وارد عدداً جديد'), findsOneWidget);
      // ★ **الشريط المقفل يُخبر لماذا** — ⛔ **ولا منتقي تاريخ.**
      expect(
        find.text('تاريخ اليوم 2026/08/25 — من الخادم ولا يُغيَّر.'),
        findsWidgets,
      );
      expect(find.byIcon(Icons.calendar_today), findsNothing);
      expect(find.byType(CalendarDatePicker), findsNothing);
    });

    testWidgets('⛔★★★ FR-M6-10: لا حقل وزن ولا ضريبة ولا سعر',
        (WidgetTester t) async {
      await openForm(t);
      for (final String forbidden in <String>[
        'الوزن',
        'وزن',
        'الضريبة',
        'السعر',
        'سعر',
      ]) {
        expect(
          find.textContaining(forbidden),
          findsNothing,
          reason: 'ظهر «$forbidden» في نموذج الوارد عدداً',
        );
      }
    });

    testWidgets('★★★ يُرسل ما كتبه المستخدم كما هو', (WidgetTester t) async {
      // ★★ **ومصدرٌ لا يشترط الرعوي** — `FR-M6-03`: ⛔ **فلا حقل رعوي يُعرَض
      //    ولا يُخزَّن أصلاً**، ⟵ **وهذا هو الشطر الثاني من القاعدة.**
      await openForm(t, requiresSupplier: false);
      expect(find.text('الرعوي'), findsNothing);
      await t.enterText(find.byType(TextFormField).first, '120');
      await t.pump();
      await t.tap(find.text('اعتماد'));
      await t.pumpAndSettle();

      expect(admin.calls, 1);
      expect(admin.lastIntake?.sourceId, 'SRC-001');
      expect(admin.lastIntake?.lines.single.itemId, 'ITM-0002');
      expect(admin.lastIntake?.lines.single.quantity.pieces, 120);
      expect(admin.lastIntake?.totalQuantity.pieces, 120);
      // ⛔★★ **ولا رعويَّ يُرسَل لمصدرٍ لا يشترطه** — `FR-M6-03`.
      expect(admin.lastIntake?.supplierId, isNull);
    });

    testWidgets('★★★ FR-M6-03: يُرسل الرعوي حين يشترطه المصدر',
        (WidgetTester t) async {
      await openForm(t);
      await t.tap(find.text('رعوي مثال'));
      await t.pump();
      await t.enterText(find.byType(TextFormField).first, '50');
      await t.pump();
      await t.tap(find.text('اعتماد'));
      await t.pumpAndSettle();

      expect(admin.lastIntake?.supplierId, 'SUP-0001');
    });

    testWidgets('★★★ FR-M6-03: ويُرفض الاعتماد بلا رعوي حين يشترطه المصدر',
        (WidgetTester t) async {
      await openForm(t);
      await t.enterText(find.byType(TextFormField).first, '50');
      await t.pump();
      await t.tap(find.text('اعتماد'));
      await t.pumpAndSettle();

      expect(admin.calls, 0);
      expect(
        find.text(catalogText(CatalogMessage.supplierRequiredForSource)),
        findsOneWidget,
      );
    });

    testWidgets('★★ ورفض السحابة يُعرَض بنصّه من الكتالوج',
        (WidgetTester t) async {
      admin.failure = const InsufficientStockError();
      await openForm(t);
      await t.tap(find.text('رعوي مثال'));
      await t.pump();
      await t.enterText(find.byType(TextFormField).first, '50');
      await t.pump();
      await t.tap(find.text('اعتماد'));
      await t.pumpAndSettle();

      expect(
        find.text(catalogText(CatalogMessage.insufficientStock)),
        findsOneWidget,
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // الإلغاء — FR-M6-13
  // ═══════════════════════════════════════════════════════════════════

  group('★★ الإلغاء — FR-M6-13', () {
    Future<void> openCancel(WidgetTester t) async {
      inventory.emitIntakes(<CountedIntakeCard>[testIntake()]);
      await pumpScreen(
        t,
        screen: const CountedIntakeScreen(),
        inventory: inventory,
        admin: admin,
        masterData: masterData,
      );
      await t.tap(find.byIcon(Icons.block_outlined));
      await t.pumpAndSettle();
    }

    // ⛔⛔★★★ **ارتدادُ `ADR-0020`:** ★ **كانت الشاشة ترفض قبل الشبكة
    //    بـ`ERR_AMEND_004`** — ⟵ **وصار الإلغاء بلا سببٍ مشروعاً**،
    //    ★ **فيصل الشبكة والسببُ غائبٌ صريحاً** ⛔ **لا نصّاً مُعبَّأً عنه.**
    testWidgets('✅★★★ ADR-0020: يقبل التأكيد بلا سببٍ — ويصل السبب غياباً',
        (WidgetTester t) async {
      await openCancel(t);
      await t.tap(find.text('تأكيد الإلغاء'));
      await t.pumpAndSettle();

      expect(admin.calls, 1);
      expect(admin.lastCancelReason, isNull);
      expect(
        find.text(catalogText(CatalogMessage.cancelReasonMissing)),
        findsNothing,
      );
    });

    testWidgets('★★ ويُمرِّر السبب والمصدر كما هما', (WidgetTester t) async {
      await openCancel(t);
      await t.enterText(find.byType(TextField).first, 'دفعة مكررة');
      await t.pump();
      await t.tap(find.text('تأكيد الإلغاء'));
      await t.pumpAndSettle();

      expect(admin.calls, 1);
      expect(admin.lastCancelReason, 'دفعة مكررة');
      expect(admin.lastDocumentNumber, 'INC-20260825-0001');
      expect(admin.lastCancelSourceId, 'SRC-001');
    });
  });
}

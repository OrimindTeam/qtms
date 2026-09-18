/// شاشة التسعير اليومي — `WU-005`.
///
/// ⚠️⚠️ **وما تُثبته هذه الاختبارات وما لا تُثبته:** تُثبت أن **الشاشة تعرض
/// ما له كمية اليوم وحده**، وأنها **تُمرِّر ما كتبه المستخدم كما هو**، وأنها
/// **تعرض رفض السحابة بنصّه**، وأن **«نسخ أسعار أمس» لا يحفظ شيئاً**.
/// ⛔ **ولا تُثبت أن الكتابة محميّة** — ★ **الحماية في `planDailyPricing`**،
/// ولها اختباراتها هناك (`functions/test/daily_pricing_test.dart`).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qtms/capabilities/identity_access/application/session_providers.dart';
import 'package:qtms/capabilities/inventory/application/inventory_providers.dart';
import 'package:qtms/capabilities/inventory/presentation/daily_pricing_screen.dart';
import 'package:qtms/capabilities/master_data/application/master_data_providers.dart';
import 'package:qtms/core/messages/error_messages.dart';
import 'package:qtms/core/ui/context_header.dart';
import 'package:qtms/core/ui/sticky_action_bar.dart';
import 'package:qtms_domain/qtms_domain.dart';

import '../../../support/fake_identity.dart';
import '../../../support/fake_inventory.dart';
import '../../../support/fake_master_data.dart';

/// ★★ **اليوم مثبَّت** — ⛔ **فلا اختبارَ ينكسر بمرور منتصف الليل.**
final CalendarDay fixedDay = CalendarDay(2026, 8, 25);

late FakeInventoryDirectory inventory;
late FakeDailyPricingDirectory pricing;
late FakeDailyPricingRepository repository;
late FakeMasterDataDirectory masterData;

Future<void> pumpPricing(
  WidgetTester tester, {
  Set<Permission> actorPermissions = const <Permission>{
    Permission.dailyPriceWrite,
  },
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
        inventoryAdminProvider.overrideWithValue(FakeInventoryAdmin()),
        dailyPricingDirectoryProvider.overrideWithValue(pricing),
        dailyPricingRepositoryProvider.overrideWithValue(repository),
        todayProvider.overrideWithValue(fixedDay),
      ],
      child: MaterialApp(
        locale: const Locale('ar'),
        home: const DailyPricingScreen(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 20));
}

void main() {
  setUp(() {
    inventory = FakeInventoryDirectory();
    pricing = FakeDailyPricingDirectory();
    repository = FakeDailyPricingRepository();
    masterData = FakeMasterDataDirectory();
    masterData.emitSources(<SourceCard>[testSource()]);
    masterData.emitItems(<ItemCard>[testItem()]);
  });

  tearDown(() {
    inventory.dispose();
    pricing.dispose();
    masterData.dispose();
  });

  group('★★ FR-M9-02 · E-33 — لا تظهر إلا الأنواع التي لها كمية اليوم', () {
    testWidgets('★ نوعٌ له رصيدٌ موجب يظهر', (WidgetTester tester) async {
      inventory.emitStock(<ItemDailyBalanceCard>[testBalance()]);
      await pumpPricing(tester);
      expect(find.text('عود'), findsOneWidget);
    });

    testWidgets('⛔ ونوعٌ رصيدُه صفر لا يظهر — والصفر ليس كمية',
        (WidgetTester tester) async {
      inventory.emitStock(<ItemDailyBalanceCard>[
        testBalance(incoming: 120, outgoing: 120),
      ]);
      await pumpPricing(tester);
      expect(find.text('عود'), findsNothing);
      expect(
        find.text('التسعير يتبع المخزون — سجّل وارداً أولاً ثم عُد لتسعيره.'),
        findsOneWidget,
      );
    });

    testWidgets('★★ والسكرب يظهر بسعر الكيلو لا بسعر الحبة (FR-M9-06)',
        (WidgetTester tester) async {
      inventory.emitStock(<ItemDailyBalanceCard>[testWeightBalance()]);
      await pumpPricing(tester);
      expect(find.text('سعر التوزيع لكل كيلوجرام'), findsOneWidget);
      expect(find.text('الحد الأدنى لكل كيلوجرام'), findsOneWidget);
    });
  });

  group('★★ FR-M9-01 · GR-31 — يومٌ واحد ولا ترحيل صامت', () {
    testWidgets('★ تستعلم على اليوم المثبَّت — ⛔ ولا يومَ سواه إلا أمسِه',
        (WidgetTester tester) async {
      inventory.emitStock(<ItemDailyBalanceCard>[testBalance()]);
      await pumpPricing(tester);
      // ★ اليوم للعرض، وأمسِه لزرّ النسخ وحده (`FR-M9-13`).
      expect(
        pricing.requestedDays.map((CalendarDay d) => d.format()).toSet(),
        <String>{'20260825', '20260824'},
      );
    });

    testWidgets('★★ وحقول اليوم تبدأ فارغة حين لا سعر لليوم',
        (WidgetTester tester) async {
      inventory.emitStock(<ItemDailyBalanceCard>[testBalance()]);
      // ⚠️ **أمسِ مسعَّر واليوم لا** — ⟵ **والحقول تبقى فارغة**، ⛔ **فلا
      //    ترحيل تلقائي صامت.**
      pricing.emitPrices(
        fixedDay.previousDay(),
        <DailyPriceCard>[testPrice(date: fixedDay.previousDay())],
      );
      await pumpPricing(tester);
      final Iterable<TextField> fields =
          tester.widgetList<TextField>(find.byType(TextField));
      for (final TextField field in fields) {
        expect(field.controller?.text ?? '', isEmpty);
      }
    });

    testWidgets('★★★ و«نسخ أسعار أمس» يملأ الحقول ⛔ ولا يحفظ شيئاً',
        (WidgetTester tester) async {
      inventory.emitStock(<ItemDailyBalanceCard>[testBalance()]);
      pricing.emitPrices(
        fixedDay.previousDay(),
        <DailyPriceCard>[testPrice(date: fixedDay.previousDay())],
      );
      await pumpPricing(tester);
      // ⚠️ **تدفّق أمسِ يصل بعد تدفّق اليوم** — ★ **فيُنتظَر إطارٌ إضافي**،
      //    ⛔ **ولا يُبنى الاختبار على ترتيب وصولٍ غير مضمون.**
      await tester.pump(const Duration(milliseconds: 20));

      expect(find.text('نسخ أسعار أمس'), findsOneWidget);
      await tester.tap(find.text('نسخ أسعار أمس'));
      await tester.pump();

      expect(find.widgetWithText(TextField, '1200'), findsOneWidget);
      expect(find.widgetWithText(TextField, '1000'), findsOneWidget);
      // ⛔★★ **ولا كتابة واحدة** — `BR-M9-02`: **نسخٌ صريح لا ترحيل صامت**.
      expect(repository.calls, 0);
    });

    testWidgets('⛔ ويُخفى الزر إن لم يكن لأمس أسعار',
        (WidgetTester tester) async {
      inventory.emitStock(<ItemDailyBalanceCard>[testBalance()]);
      await pumpPricing(tester);
      await tester.pump(const Duration(milliseconds: 20));
      expect(find.text('نسخ أسعار أمس'), findsNothing);
    });
  });

  group('الحفظ — ما يُرسَل وما لا يُرسَل', () {
    testWidgets('★ يُرسل ما كتبه المستخدم كما هو بمفتاح النوع',
        (WidgetTester tester) async {
      inventory.emitStock(<ItemDailyBalanceCard>[testBalance()]);
      await pumpPricing(tester);

      await tester.enterText(find.byType(TextField).at(0), '1500');
      await tester.enterText(find.byType(TextField).at(1), '1300');
      await tester.tap(find.text('حفظ أسعار اليوم'));
      await tester.pump();

      final ValidatedDailyPriceLine line = repository.lastBatch!.lines.single;
      expect(repository.lastBatch!.sourceId, 'SRC-001');
      expect(line.itemKey, 'ITM-0002');
      expect(line.distributionPrice, const Money(1500));
      expect(line.minCashPrice, const Money(1300));
      expect(line.complete, isTrue);
    });

    testWidgets('★★ والحقل الفارغ يُرسَل تفريغاً (null) ⛔ لا صفراً',
        (WidgetTester tester) async {
      inventory.emitStock(<ItemDailyBalanceCard>[testBalance()]);
      pricing.emitPrices(fixedDay, <DailyPriceCard>[testPrice()]);
      await pumpPricing(tester);

      await tester.enterText(find.byType(TextField).at(0), '');
      await tester.enterText(find.byType(TextField).at(1), '');
      await tester.tap(find.text('حفظ أسعار اليوم'));
      await tester.pump();

      final ValidatedDailyPriceLine line = repository.lastBatch!.lines.single;
      expect(line.distributionPrice, isNull);
      expect(line.minCashPrice, isNull);
      expect(line.isCleared, isTrue);
    });

    testWidgets('★★ والسبب لا يُرسَل إن تُرك فارغاً — ⛔ ولا نصّاً فارغاً',
        (WidgetTester tester) async {
      inventory.emitStock(<ItemDailyBalanceCard>[testBalance()]);
      await pumpPricing(tester);

      await tester.enterText(find.byType(TextField).at(0), '1500');
      await tester.tap(find.text('حفظ أسعار اليوم'));
      await tester.pump();

      expect(repository.lastReason, isNull);
    });

    testWidgets('★ ويُرسَل السبب حين يكتبه المستخدم (ADR-0004)',
        (WidgetTester tester) async {
      inventory.emitStock(<ItemDailyBalanceCard>[testBalance()]);
      await pumpPricing(tester);

      await tester.enterText(find.byType(TextField).at(0), '1500');
      await tester.enterText(find.byType(TextField).at(2), 'تصحيح سعر السوق');
      await tester.tap(find.text('حفظ أسعار اليوم'));
      await tester.pump();

      expect(repository.lastReason, 'تصحيح سعر السوق');
    });

    testWidgets('⛔★★ RISK-02: وزرّ الحفظ يُخفى بلا dailyPriceWrite',
        (WidgetTester tester) async {
      inventory.emitStock(<ItemDailyBalanceCard>[testBalance()]);
      await pumpPricing(tester, actorPermissions: const <Permission>{});
      expect(find.text('حفظ أسعار اليوم'), findsNothing);
    });
  });

  group('الرفض — يُعرَض بنصّ الكتالوج ⛔ ولا يُبتلَع', () {
    testWidgets('★★ ERR_MONEY_001: والسعر غير الموجب يُرفَض قبل الإرسال',
        (WidgetTester tester) async {
      inventory.emitStock(<ItemDailyBalanceCard>[testBalance()]);
      await pumpPricing(tester);

      await tester.enterText(find.byType(TextField).at(0), '0');
      await tester.tap(find.text('حفظ أسعار اليوم'));
      await tester.pump();

      expect(
        find.text(catalogText(CatalogMessage.fractionalMoney)),
        findsOneWidget,
      );
      // ⛔ **ولا يبلغ السحابة أصلاً.**
      expect(repository.calls, 0);
    });

    testWidgets('★ ورفض السحابة يُعرَض بنصّه', (WidgetTester tester) async {
      inventory.emitStock(<ItemDailyBalanceCard>[testBalance()]);
      repository.failure =
          const InfrastructureError('ERR_AMEND_002');
      await pumpPricing(tester);

      await tester.enterText(find.byType(TextField).at(0), '1500');
      await tester.tap(find.text('حفظ أسعار اليوم'));
      await tester.pump();

      expect(
        find.text(catalogText(CatalogMessage.amendReasonMissing)),
        findsOneWidget,
      );
    });

    testWidgets('★★ ومنعُ الرؤية يُميَّز عن «لا يوجد» (RISK-02)',
        (WidgetTester tester) async {
      inventory.emitStockError(const PermissionError());
      await pumpPricing(tester);
      expect(
        find.text('تحقق من صلاحيتك ونطاق مصادرك، ثم أعد المحاولة.'),
        findsOneWidget,
      );
    });
  });

  group('فلتر حالة التسعير — FR-M9-05', () {
    /// ★★ **يفتح المرشِّحات المطويّة** — §5b نمط `P3` البند ③ (`ADR-0021`).
    ///
    /// ⚠️⚠️ **وطيُّها ابتداءً سلوكٌ مقصود لا ارتداد:** ★ **كان رأسُ هذه
    /// الشاشة ثلاثةَ صفوف** — ⟵ **وصفُّ المرشِّحات المفتوح دائماً يدفع أول
    /// صفِّ تسعيرٍ خارج الطيّة.** ⛔ **والضمانةُ لم تُخفَّف:** ★ **المرشِّح
    /// يعمل كما كان، وعددُ النشط ظاهرٌ على الزرّ وهو مطويّ** ⟵ **فلا يقرأ
    /// المستخدم قائمةً مفلترة ظانّاً أنها كاملة.**
    Future<void> openFilters(WidgetTester tester) async {
      await tester.tap(find.byTooltip('مرشِّحات'));
      await tester.pump();
    }

    testWidgets('★ «لم يتم» يُخفي المسعَّر بالكامل',
        (WidgetTester tester) async {
      inventory.emitStock(<ItemDailyBalanceCard>[testBalance()]);
      pricing.emitPrices(fixedDay, <DailyPriceCard>[testPrice()]);
      await pumpPricing(tester);

      expect(find.text('عود'), findsOneWidget);
      await openFilters(tester);
      await tester.tap(find.text('لم يتم'));
      await tester.pump();
      expect(find.text('عود'), findsNothing);
    });

    testWidgets('★★ ونصفُ التسعير يبقى في «لم يتم» — FR-M9-10',
        (WidgetTester tester) async {
      inventory.emitStock(<ItemDailyBalanceCard>[testBalance()]);
      pricing.emitPrices(
        fixedDay,
        <DailyPriceCard>[testPrice(minimum: null)],
      );
      await pumpPricing(tester);

      await openFilters(tester);
      await tester.tap(find.text('لم يتم'));
      await tester.pump();
      expect(find.text('عود'), findsOneWidget);
    });

    testWidgets('★ و«تم التسعير» يعرض المكتمل وحده',
        (WidgetTester tester) async {
      inventory.emitStock(<ItemDailyBalanceCard>[testBalance()]);
      pricing.emitPrices(fixedDay, <DailyPriceCard>[testPrice()]);
      await pumpPricing(tester);

      await openFilters(tester);
      await tester.tap(find.text('تم التسعير'));
      await tester.pump();
      expect(find.text('عود'), findsOneWidget);
    });

    testWidgets('★★★ وعددُ المرشِّح النشط ظاهرٌ على الزرّ وهو مطويّ',
        (WidgetTester tester) async {
      inventory.emitStock(<ItemDailyBalanceCard>[testBalance()]);
      pricing.emitPrices(fixedDay, <DailyPriceCard>[testPrice()]);
      await pumpPricing(tester);

      // ★ **«الكل» ليس مرشِّحاً نشطاً** — ⟵ **فلا يُعَدّ.**
      expect(find.byTooltip('مرشِّحات'), findsOneWidget);

      await openFilters(tester);
      await tester.tap(find.text('لم يتم'));
      await tester.pump();
      // ⛔⛔★★ **وبعد الاختيار يُعلن الزرُّ أن ثمّة مرشِّحاً نشطاً** —
      //    ⟵ **فلا تُقرأ قائمةٌ مفلترة على أنها كاملة.**
      expect(find.byTooltip('مرشِّحات (1)'), findsOneWidget);
    });
  });

  group('⛔⛔★★★ AM-021 — زرٌّ ثنائي الحالة وفراغُ مرشِّحٍ يُسمّى باسمه', () {
    Future<void> openFilters(WidgetTester tester) async {
      await tester.tap(find.byTooltip('مرشِّحات'));
      await tester.pump();
    }

    testWidgets('★★★ ② زرُّ الحفظ يقول «جارٍ الحفظ…» ويُعطَّل أثناء النداء',
        (WidgetTester tester) async {
      // ⛔⛔ **وكان التعطيلُ وحدَه** — `design-system.md` §6-ي البند ②:
      //   ★ **«وزرٌّ معطَّلٌ بلا بديلٍ يُقرأ ممنوعاً لا مشغولاً».**
      final Completer<Outcome<void>> pending = Completer<Outcome<void>>();
      repository.nextResult = pending.future;
      inventory.emitStock(<ItemDailyBalanceCard>[testBalance()]);
      await pumpPricing(tester);

      await tester.enterText(find.byType(TextField).at(0), '1500');
      await tester.enterText(find.byType(TextField).at(1), '1300');
      await tester.tap(find.text(dailyPricingSaveLabel));
      await tester.pump();

      expect(find.text(dailyPricingSavingLabel), findsOneWidget);
      expect(find.text(dailyPricingSaveLabel), findsNothing);
      final FilledButton button =
          tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);

      pending.complete(const Success<void>(null));
      await tester.pumpAndSettle();
      expect(find.text(dailyPricingSaveLabel), findsOneWidget);
    });

    testWidgets('★★★ ③ فراغُ «لم يتم» على يومٍ مكتمل يُسمّى باسمه',
        (WidgetTester tester) async {
      // ⛔⛔★★★ **ورسالةُ «لا شيء يُسعَّر بعد» فوق يومٍ سُعِّر بالكامل تقول
      //   عكسَ الحقيقة تماماً** — `design-system.md` §هـ.
      inventory.emitStock(<ItemDailyBalanceCard>[testBalance()]);
      pricing.emitPrices(fixedDay, <DailyPriceCard>[testPrice()]);
      await pumpPricing(tester);

      await openFilters(tester);
      await tester.tap(find.text('لم يتم'));
      await tester.pumpAndSettle();

      expect(find.text(pricingFilteredEmptyTitle), findsOneWidget);
      expect(find.text('لا شيء يُسعَّر بعد'), findsNothing);
      expect(find.text(pricingFilteredEmptyAction), findsOneWidget);
    });

    testWidgets('★★★ و«اعرض الكل» يرفع المرشِّح فعلاً فتعود الصفوف',
        (WidgetTester tester) async {
      inventory.emitStock(<ItemDailyBalanceCard>[testBalance()]);
      pricing.emitPrices(fixedDay, <DailyPriceCard>[testPrice()]);
      await pumpPricing(tester);

      await openFilters(tester);
      await tester.tap(find.text('لم يتم'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(pricingFilteredEmptyAction));
      await tester.pumpAndSettle();

      expect(find.text('عود'), findsOneWidget);
      expect(find.text(pricingFilteredEmptyTitle), findsNothing);
    });

    testWidgets(
        '⛔⛔★★★ ويومٌ بلا مخزونٍ أصلاً يبقى على رسالة الفراغ العامة',
        (WidgetTester tester) async {
      // ★★ **فالشرطُ مقيسٌ لا مُفترَض** — ⟵ **«المرشِّحُ ليس الكل» وحدَه لا
      //   يكفي**: ⛔ **ويومٌ بلا مخزونٍ فراغُه فراغُ بيانات لا فراغُ مرشِّح.**
      inventory.emitStock(const <ItemDailyBalanceCard>[]);
      await pumpPricing(tester);

      await openFilters(tester);
      await tester.tap(find.text('لم يتم'));
      await tester.pumpAndSettle();

      expect(find.text('لا شيء يُسعَّر بعد'), findsOneWidget);
      expect(find.text(pricingFilteredEmptyTitle), findsNothing);
    });
  });

  group('★★★ P3 — رأس السياق على شاشة التسعير (ADR-0021 · §5b)', () {
    testWidgets('★ صفٌّ واحد بدل ثلاثة — ⛔ ولا لافتةَ يومٍ مستقلة',
        (WidgetTester tester) async {
      inventory.emitStock(<ItemDailyBalanceCard>[testBalance()]);
      pricing.emitPrices(fixedDay, <DailyPriceCard>[testPrice()]);
      await pumpPricing(tester);

      expect(find.byType(QtmsContextHeader), findsOneWidget);
      expect(find.text('2026/08/25'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    });

    testWidgets('★★★ P4: وزرُّ الحفظ في شريطٍ ثابت — ⛔ لا في ذيل القائمة',
        (WidgetTester tester) async {
      inventory.emitStock(<ItemDailyBalanceCard>[testBalance()]);
      pricing.emitPrices(fixedDay, <DailyPriceCard>[testPrice()]);
      await pumpPricing(tester);

      // ⚠️ **ونبضةٌ إضافية قبل قياس الزرّ** — ★ **`PermissionGate` تقرأ
      //    بطاقةَ المستخدم من تدفّق**، ⟵ **فالمفتاح يصل بعد أول بناء.**
      await tester.pump(const Duration(milliseconds: 20));

      expect(find.byType(QtmsStickyActionBar), findsOneWidget);
      expect(find.text('حفظ أسعار اليوم'), findsOneWidget);
    });

    testWidgets('★★ P4: وعدّادُ المسعَّر ملخّصٌ حيٌّ فوق الصفوف',
        (WidgetTester tester) async {
      inventory.emitStock(<ItemDailyBalanceCard>[testBalance()]);
      pricing.emitPrices(fixedDay, <DailyPriceCard>[testPrice()]);
      await pumpPricing(tester);

      // ★ **والحالةُ من `PricingRow.complete`** ⟵ **وهي تفوّض لطبقة النطاق.**
      expect(find.text('سُعِّر 1 من 1'), findsOneWidget);

      final double bulkY = tester.getCenter(find.text('سُعِّر 1 من 1')).dy;
      final double rowY = tester.getCenter(find.text('عود')).dy;
      // ⛔⛔★★ **الإجراء الجماعي فوق الصفوف لا تحتها** — §5b `P4` ③.
      expect(bulkY, lessThan(rowY));
    });
  });

  // ═══════════ ⛔⛔★★★ حارسُ `DEBT-62` — ولماذا هو حارسُ شرطٍ لا حارسُ عَرَض ═══════════
  //
  // ★★★ **العطل كما وقع فعلاً على `Pixel_6_API_36` (2026-08-29):** ★ **جسمُ شاشة
  //    التسعير لا يُرسَم إطلاقاً عند الدخول إليها مرةً ثانية في نفس تشغيل
  //    التطبيق** — ⛔ **بلا استثناءٍ ولا خطأ**: ★ **`build` و`initState`
  //    والتخطيطُ والإطاراتُ كلُّها سليمة**، ⛔ **و`paint` لا يُستدعى** و
  //    **فحصُ اللمس لا يمرّ**، ★ **وأسلافُ الجسم عالقون على `debugNeedsPaint`.**
  //
  // ★★ **وعُزل المُسبِّبُ بالقطع على الجهاز:** ⛔ **`_CopyYesterdayButton`** —
  //    ⟵ **وهو الاشتراكُ الثاني على [dailyPricesProvider]** (**أسعارُ أمس**)،
  //    ★ **وشاشةُ التسعير وحدَها تشترك في هذه العائلة مرتين.**
  //    ✅ **والعلاجُ المُثبَتُ حيّاً: `isAutoDispose: true`** ⟵ **فيسقط اشتراكُ
  //    أمس عند مغادرة الشاشة ويُعاد نظيفاً عند العودة.**
  //
  // ⛔⛔★★★ **ولماذا يفحص هذا الاختبارُ الشرطَ لا العَرَض:** ★ **العَرَضُ
  //    (تعذُّرُ الرسم) لا يتكرّر في اختبار ودجاتٍ إطلاقاً** — ⟵ **جُرِّب مرتين
  //    بتبديلٍ مباشر وبملاحةِ `go_router` متداخلةٍ مطابقة، والشجرةُ حاضرةٌ في
  //    الحالتين**: ★ **لأن اختبار الودجات لا يُشغّل المُركِّبَ الحقيقي.**
  //    ⟹ ★★ **فالحارسُ الممكنُ هنا هو الشرطُ الذي أزال العطل** — ⛔ **ولو
  //    أُسقِط `isAutoDispose` عاد العطلُ صامتاً بلا اختبارٍ يسقط.**
  //    ⚠️ **ويُقال بصدق: هذا حارسُ انحدارٍ للشرط** ⛔ **لا برهانٌ على أن
  //    الرسمَ يعمل** — ★ **وبرهانُ الرسم بوابةُ §د.2 على المحاكي وحدها.**
  test('⛔⛔★★★ DEBT-62 — `dailyPricesProvider` يبقى `isAutoDispose`', () {
    expect(
      dailyPricesProvider.isAutoDispose,
      isTrue,
      reason: '★ إسقاطُه يُعيد عطلَ الشاشة الفارغة — DEBT-62',
    );
  });
}

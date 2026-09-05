/// شاشة التوزيع والضمار — `WU-006` · **مُعاد بناؤها في `AM-009` ⑦**.
///
/// ⚠️⚠️ **وما تُثبته هذه الاختبارات وما لا تُثبته:** تُثبت أن الشاشة
/// **تعرض سجلات اليوم باسم المقوت**، وأنها **تفتح التوزيعة القائمة للتعديل**
/// (`E-04`)، وأنها **تُخفي قيمة الضمار عمّن لا يملك رؤيتها وتُرسل السعر مع
/// ذلك** (`ت-12` — **أخطر ما في الوحدة**)، وأنها **تفصل الإجماليين**
/// (`GR-19`)، وأنها **لا تُعبِّئ سبب التعديل نيابةً عن المستخدم**،
/// و⛔⛔ **أنها لا تعرض زرَّ حذفٍ إطلاقاً** (`GR-07`).
/// ⛔ **ولا تُثبت أن الكتابة محميّة** — ★ **الحماية في `planDistribution`**،
/// ولها اختباراتها هناك (`functions/test/distribution_test.dart`).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qtms/capabilities/identity_access/application/session_providers.dart';
import 'package:qtms/capabilities/inventory/application/inventory_providers.dart';
import 'package:qtms/capabilities/master_data/application/master_data_providers.dart';
import 'package:qtms/capabilities/oversight/application/pending_entries_providers.dart';
import 'package:qtms/capabilities/sales_receivables/application/distribution_providers.dart';
import 'package:qtms/capabilities/sales_receivables/presentation/distribution_screen.dart';
import 'package:qtms/core/ui/context_header.dart';
import 'package:qtms/core/ui/search_field.dart';
import 'package:qtms/core/ui/sticky_action_bar.dart';
import 'package:qtms_domain/qtms_domain.dart';

import '../../../support/fake_distribution.dart';
import '../../../support/fake_identity.dart';
import '../../../support/fake_inventory.dart';
import '../../../support/fake_master_data.dart';

/// ★★ **اليوم مثبَّت** — ⛔ **فلا اختبارَ ينكسر بمرور منتصف الليل.**
final CalendarDay fixedDay = CalendarDay(2026, 8, 27);

late FakeDistributionDirectory distributions;
late FakeDistributionAdmin admin;
late FakeMasterDataDirectory masterData;
late FakeDailyPricingDirectory pricing;
late FakeInventoryDirectory inventory;

const Set<Permission> fullPermissions = <Permission>{
  Permission.distributionCreate,
  Permission.distributionAmend,
  Permission.distributionCancel,
  Permission.distributionPriceNow,
  Permission.distributionPriceView,
  Permission.distributionPriceAmend,
  Permission.distributionPriceClear,
};

Future<void> pumpDistribution(
  WidgetTester tester, {
  Set<Permission> actorPermissions = fullPermissions,
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
        distributionDirectoryProvider.overrideWithValue(distributions),
        distributionAdminProvider.overrideWithValue(admin),
        todayProvider.overrideWithValue(fixedDay),
      ],
      child: const MaterialApp(
        locale: Locale('ar'),
        home: DistributionScreen(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 20));
}

/// ⛔⛔★★★ **حارسُ `DEBT-68`** — ★ **يُشغِّل الشاشة ووجهةٌ من المركز المعلّق
/// مضبوطةٌ سلفاً**، ⟵ **وهو بالضبط ما أسقط الشاشة حيّاً على `Pixel_6_API_36`**
/// بـ«Tried to modify a provider while the widget tree was building».
///
/// ⚠️ **ويحتاج حاوية صريحة** — ★ **فالوجهةُ تُضبَط قبل أول بناء**،
/// ⛔ **ولا تُضبَط من داخل الشجرة.**
Future<ProviderContainer> pumpWithPendingFocus(
  WidgetTester tester, {
  required PendingFocus focus,
}) async {
  final FakeAuthRepository auth = FakeAuthRepository();
  final FakeUserCardRepository cards = FakeUserCardRepository();
  auth.emitIdentity(
    const AuthenticatedIdentity(userId: 'U-001', sourceScope: AllSources()),
  );
  cards.emitCard('U-001', testCard(permissions: fullPermissions));

  final ProviderContainer container = ProviderContainer(overrides: [
    authRepositoryProvider.overrideWithValue(auth),
    userCardRepositoryProvider.overrideWithValue(cards),
    masterDataDirectoryProvider.overrideWithValue(masterData),
    masterDataAdminProvider.overrideWithValue(FakeMasterDataAdmin()),
    contactPickerProvider.overrideWithValue(null),
    inventoryDirectoryProvider.overrideWithValue(inventory),
    inventoryAdminProvider.overrideWithValue(FakeInventoryAdmin()),
    dailyPricingDirectoryProvider.overrideWithValue(pricing),
    distributionDirectoryProvider.overrideWithValue(distributions),
    distributionAdminProvider.overrideWithValue(admin),
    todayProvider.overrideWithValue(fixedDay),
  ]);
  addTearDown(container.dispose);
  container.read(pendingFocusProvider.notifier).request(focus);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        locale: Locale('ar'),
        home: DistributionScreen(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 20));
  return container;
}

/// ★★★ **يفتح نموذج الإنشاء من الزرّ العائم** — `AM-009` ⑦.
Future<void> openNewForm(WidgetTester tester) async {
  await tester.tap(find.text('توزيعة جديدة'));
  await tester.pumpAndSettle();
}

/// ★★★ **يفتح نموذج التعديل من سجلّ المقوت** — `AM-009` ⑦.
Future<void> openAmendForm(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.edit_outlined));
  await tester.pumpAndSettle();
}

/// ★ يختار المقوت داخل النموذج — **المنسدلُ الأول في الورقة.**
Future<void> pickDealer(
  WidgetTester tester, [
  String name = 'مقوت مثال',
]) async {
  await tester.tap(find.byType(DropdownMenu<String>).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text(name).last);
  await tester.pumpAndSettle();
}

/// ★ يُمرِّر ورقة النموذج حتى يظهر العنصر — **فالورقةُ أطول من الشاشة.**
///
/// ⛔ **و`ensureVisible` لا تكفي** — ★ **`ListView` يبني بالطلب**:
/// ⟵ **فآخرُ عنصرٍ قد لا يكون مبنيّاً أصلاً** ⛔ **فلا يجده أي مُلتقِط.**
Future<void> scrollFormTo(WidgetTester tester, Finder target) async {
  await tester.dragUntilVisible(
    target,
    find.byType(ListView).last,
    const Offset(0, -80),
  );
  await tester.pumpAndSettle();
}

/// ★★★ **يضيف سطرَ نوعٍ بالنمط الجديد** — `AM-009` ④: **زرُّ `+` ثم منسدلٌ
/// يُصفّي ثم الكمية** ⛔ **لا صفوفَ كتالوجٍ جاهزة.**
Future<void> addLine(
  WidgetTester tester, {
  /// ★★ **والنصُّ يحمل المتبقّي** — `FR-M10-06` · [`DEBT-86`]: ⟵ **فالخيارُ
  ///    من رصيد الدفتر**، ⛔ **ولا اسمٌ مجرَّدٌ في القائمة.**
  String item = 'عود (100 حبة)',
  required String quantity,
}) async {
  await tester.tap(find.text('إضافة نوع'));
  await tester.pumpAndSettle();
  await tester.tap(find.byType(DropdownMenu<String>).last);
  await tester.pumpAndSettle();
  await tester.tap(find.text(item).last);
  await tester.pumpAndSettle();
  await tester.enterText(
    find.widgetWithText(TextField, 'الكمية').last,
    quantity,
  );
  await tester.pump();
}

void main() {
  setUp(() {
    distributions = FakeDistributionDirectory();
    admin = FakeDistributionAdmin();
    masterData = FakeMasterDataDirectory();
    pricing = FakeDailyPricingDirectory();
    inventory = FakeInventoryDirectory();
    masterData.emitSources(<SourceCard>[testSource()]);
    masterData.emitItems(<ItemCard>[testItem()]);
    masterData.emitDealers(<DealerCard>[testDealer()]);
    // ★★ **ورصيدُ اليوم هو مصدرُ الخيارات** — [`DEBT-86`].
    inventory.emitStock(<ItemDailyBalanceCard>[testBalance()]);
    distributions.emitList(const <DistributionCard>[]);
  });

  tearDown(() {
    distributions.dispose();
    masterData.dispose();
    pricing.dispose();
    inventory.dispose();
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('★★★ AM-009 ⑦ — سجلاتٌ ومرشِّحان وزرٌّ عائم', () {
    testWidgets('★★★ الشاشة تعرض سجلات اليوم باسم المقوت — ⛔ لا نموذجَ مفتوح',
        (WidgetTester tester) async {
      distributions.emitOne(testDistributionCard());
      await pumpDistribution(tester);

      // ★ **العنوانُ اسمُ المقوت** — ⛔ **لا رقمُ المستند.**
      expect(find.text('مقوت مثال'), findsOneWidget);
      // ⛔⛔ **ولا نموذجَ إدخالٍ قبل أن يطلبه المستخدم.**
      expect(find.text('إضافة نوع'), findsNothing);
      expect(find.text('توزيعة جديدة'), findsOneWidget);
    });

    testWidgets('★★ ومرشِّحُ المصدر يحمل «كل المصادر» — AM-009 ③',
        (WidgetTester tester) async {
      await pumpDistribution(tester);
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      expect(find.text('كل المصادر'), findsWidgets);
    });

    testWidgets('★★★ وبحثُ المقوت يُصفّي السجلات', (WidgetTester tester) async {
      distributions.emitList(<DistributionCard>[
        testDistributionCard(),
        testDistributionCard(
          dealerId: 'MQT-0002',
          dealerName: 'مقوت آخر',
        ),
      ]);
      await pumpDistribution(tester);
      expect(find.text('مقوت مثال'), findsOneWidget);
      expect(find.text('مقوت آخر'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'بحث بالمقوت'),
        'آخر',
      );
      await tester.pumpAndSettle();

      expect(find.byType(QtmsSearchField), findsOneWidget);
      // ★ **والاسمُ الباقي وحده** — ⛔ **ولا قائمةٌ فارغة صامتة.**
      expect(find.text('مقوت آخر'), findsWidgets);
    });

    testWidgets('★★ وأربعةُ إجراءاتٍ على كل سجلّ', (WidgetTester tester) async {
      distributions.emitOne(testDistributionCard());
      await pumpDistribution(tester);

      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
      expect(find.byIcon(Icons.block_outlined), findsOneWidget);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('★ اختيار المقوت في النموذج', () {
    testWidgets('⛔ ولا يظهر مقوتٌ معطَّل — FR-M10-12', (
      WidgetTester tester,
    ) async {
      masterData.emitDealers(<DealerCard>[
        testDealer(),
        testDealer(
          dealerId: 'MQT-0009',
          name: 'مقوت معطَّل',
          phone: '777999888',
          isActive: false,
        ),
      ]);
      await pumpDistribution(tester);
      await openNewForm(tester);
      await tester.tap(find.byType(DropdownMenu<String>).first);
      await tester.pumpAndSettle();
      expect(find.text('مقوت معطَّل'), findsNothing);
      expect(find.text('مقوت مثال'), findsWidgets);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('★★★ GR-18 · E-04 — يُفتَح الموجود للتعديل', () {
    testWidgets(
      '⛔⛔★★★ ارتداد: لا توزيعة بعد ⟵ نموذجُ إنشاءٍ فوراً — ⛔ لا هيكلٌ أبدي',
      (WidgetTester tester) async {
        // ⚠️⚠️ **عطلٌ رُصد حيّاً على المحاكي (2026-08-27):** القراءة بالمعرّف
        //    المركّب تُرفَض بـ`PERMISSION_DENIED` على المستند الغائب لأن
        //    `storedInScope()` يقرأ `resource.data` — ⟵ **فكانت الشاشة تبقى
        //    على الهيكل العظمي أبداً في أشيع حالات `E-04`.**
        // ★ **والوجود الآن يُشتقّ من قائمة اليوم المقيَّدة بـ`sourceId`.**
        distributions.emitList(const <DistributionCard>[]);
        await pumpDistribution(tester);
        await openNewForm(tester);
        await pickDealer(tester);
        expect(find.text('حفظ التوزيعة'), findsOneWidget);
      },
    );

    testWidgets('★★ وأسعارُ التوزيعة تُطلَب بالمعرّف المركّب — ADR-0011', (
      WidgetTester tester,
    ) async {
      distributions.emitOne(testDistributionCard());
      await pumpDistribution(tester);
      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pumpAndSettle();
      expect(
        distributions.requestedIds,
        contains('MQT-0001_SRC-001_20260827'),
      );
    });

    testWidgets('★★ وتوزيعةٌ قائمة تُفتَح بشارتها وسبب تعديلٍ اختياري', (
      WidgetTester tester,
    ) async {
      distributions.emitOne(testDistributionCard(amendCount: 2));
      await pumpDistribution(tester);
      await openAmendForm(tester);

      expect(find.textContaining('فُتح للتعديل'), findsOneWidget);
      expect(find.textContaining('مُعدَّل ×2'), findsWidgets);
      expect(find.text('حفظ التعديل'), findsOneWidget);
      await scrollFormTo(tester, find.text('سبب التعديل (اختياري)'));
      expect(find.text('سبب التعديل (اختياري)'), findsOneWidget);
      // ⛔ **ولا زرّ إنشاء على مستندٍ قائم.**
      expect(find.text('حفظ التوزيعة'), findsNothing);
    });

    testWidgets('★ وغيابُ التوزيعة إنشاءٌ لا خطأ', (
      WidgetTester tester,
    ) async {
      distributions.emitOne(null);
      await pumpDistribution(tester);
      await openNewForm(tester);
      await pickDealer(tester);
      expect(find.text('حفظ التوزيعة'), findsOneWidget);
      expect(find.text('سبب التعديل (اختياري)'), findsNothing);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('⛔⛔★★★ ت-12 — إخفاء السعر لا يعني توزيعةً بلا سعر', () {
    testWidgets('⛔ من لا يملك `distributionPriceView` لا يرى قيمة الضمار', (
      WidgetTester tester,
    ) async {
      distributions
        ..emitOne(testDistributionCard())
        // ★ **والقاعدة تمنعه أصلاً فلا تصل البطاقة** — `null` هنا تمثيلٌ لذلك.
        ..emitPricing(null);
      await pumpDistribution(
        tester,
        actorPermissions: const <Permission>{Permission.distributionCreate},
      );
      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pumpAndSettle();
      expect(find.textContaining('قيمة الضمار'), findsNothing);
    });

    testWidgets('✅ ومن يملكه يراها كما كُتبت — ⛔ لا محسوبةً محلياً', (
      WidgetTester tester,
    ) async {
      distributions
        ..emitOne(testDistributionCard())
        ..emitPricing(
          DistributionPricingCard(
            sourceId: 'SRC-001',
            debtValue: const Money(121852),
            unitPrices: <Money?>[const Money(1500)],
            lineTotals: <Money?>[const Money(121852)],
          ),
        );
      await pumpDistribution(tester);
      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pumpAndSettle();
      expect(find.textContaining('121852'), findsWidgets);
    });

    testWidgets(
      '⛔⛔★★★ والسعر المقترَح يُرسَل حتى ممن لا يراه — وإلا نشأ ضمارٌ بصفر',
      (WidgetTester tester) async {
        pricing.emitPrices(fixedDay, <DailyPriceCard>[
          DailyPriceCard(
            sourceId: 'SRC-001',
            itemKey: 'ITM-0002',
            itemName: 'عود',
            unit: ItemUnit.piece,
            date: fixedDay,
            distributionPrice: const Money(1500),
          ),
        ]);
        distributions.emitOne(null);
        await pumpDistribution(
          tester,
          // ⛔ **بلا `distributionPriceView`** — ★ **ومع ذلك يُرسَل السعر.**
          actorPermissions: const <Permission>{Permission.distributionCreate},
        );
        await openNewForm(tester);
        await pickDealer(tester);
        await addLine(tester, quantity: '80');
        // ⛔ **ولا حقلَ سعرٍ لمن لا يراه** — `FR-M10-07`.
        expect(find.widgetWithText(TextField, 'السعر'), findsNothing);

        await tester.tap(find.text('حفظ التوزيعة'));
        await tester.pump(const Duration(milliseconds: 20));

        expect(admin.createCalls, 1);
        final ValidatedDistribution sent = admin.lastDistribution!;
        expect(sent.lines.single.unitPrice, const Money(1500));
        // ★ **وقيمة الضمار تُحتسب كاملة** — `FR-M10-07`.
        expect(sent.debtValue, const Money(120000));
      },
    );

    testWidgets(
      '★★★ AM-009 ⑦: ومن يملك تعديل السعر يراه مملوءاً بالمقترَح ويُغيِّره',
      (WidgetTester tester) async {
        pricing.emitPrices(fixedDay, <DailyPriceCard>[
          DailyPriceCard(
            sourceId: 'SRC-001',
            itemKey: 'ITM-0002',
            itemName: 'عود',
            unit: ItemUnit.piece,
            date: fixedDay,
            distributionPrice: const Money(1500),
          ),
        ]);
        distributions.emitOne(null);
        await pumpDistribution(tester);
        await openNewForm(tester);
        await pickDealer(tester);
        await addLine(tester, quantity: '10');

        // ★★ **والسعرُ المقترَح يُملأ عند اختيار النوع** — `FR-M10-09`.
        final TextField price = tester.widget<TextField>(
          find.widgetWithText(TextField, 'السعر (أو اتركه لاحقاً)').last,
        );
        expect(price.controller!.text, '1500');

        await tester.enterText(
          find.widgetWithText(TextField, 'السعر (أو اتركه لاحقاً)').last,
          '1600',
        );
        await tester.pump();
        await tester.tap(find.text('حفظ التوزيعة'));
        await tester.pump(const Duration(milliseconds: 20));

        expect(admin.lastDistribution!.lines.single.unitPrice, const Money(1600));
      },
    );

    testWidgets(
      '★★★ AM-009 ⑦ · FR-M10-08: وتفريغُ السعر «تسعيرٌ لاحق» — يصل غياباً',
      (WidgetTester tester) async {
        pricing.emitPrices(fixedDay, <DailyPriceCard>[
          DailyPriceCard(
            sourceId: 'SRC-001',
            itemKey: 'ITM-0002',
            itemName: 'عود',
            unit: ItemUnit.piece,
            date: fixedDay,
            distributionPrice: const Money(1500),
          ),
        ]);
        distributions.emitOne(null);
        await pumpDistribution(tester);
        await openNewForm(tester);
        await pickDealer(tester);
        await addLine(tester, quantity: '10');

        // ★★★ **وتفريغُ الحقل هو «التسعير لاحقاً»** — `FR-M10-08`:
        //    ⟵ **فالسطرُ يُحفَظ بلا سعر ويدخل مركز الإدخالات المعلّقة**،
        //    ⛔ **ولا يُرسَل صفرٌ ولا يُعاد المقترَح خلسةً.**
        await tester.enterText(
          find.widgetWithText(TextField, 'السعر (أو اتركه لاحقاً)').last,
          '',
        );
        await tester.pump();
        expect(find.textContaining('سطورٌ بلا سعر'), findsOneWidget);

        await tester.tap(find.text('حفظ التوزيعة'));
        await tester.pump(const Duration(milliseconds: 20));

        expect(admin.createCalls, 1);
        expect(admin.lastDistribution!.lines.single.unitPrice, isNull);
      },
    );
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('⛔ GR-19 — إجماليان منفصلان دائماً', () {
    testWidgets('★ الحبات والأوزان سطران لا سطرٌ واحد', (
      WidgetTester tester,
    ) async {
      distributions.emitOne(null);
      await pumpDistribution(tester);
      await openNewForm(tester);
      await pickDealer(tester);
      await addLine(tester, quantity: '80');
      expect(find.textContaining('إجمالي الحبات: 80'), findsOneWidget);
      expect(find.textContaining('إجمالي الأوزان: 0.000'), findsOneWidget);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('⛔⛔★★★ DEBT-87 — التعديل يبذر السعر ⛔ ولا يُفرِّغه صامتاً', () {
    // ═════════════════════════════════════════════════════════════════════
    // ★ **العطل مقيسٌ على `Pixel_6_API_36` (2026-09-02):** ⟵ **فُتح نموذجُ
    // التعديل بحقلِ سعرٍ فارغ لتوزيعةٍ سعرُها 500** — ⛔⛔ **وحفظُه يُرسِل
    // `unitPrice: null`** ⟹ **«تفريغُ سعرٍ قائم»**: ★ **فتنهار قيمةُ
    // الضمار إلى صفر بلا أن يقصد المستخدم شيئاً.**
    // ═════════════════════════════════════════════════════════════════════
    testWidgets('★★★ السعرُ القائم يظهر في الحقل عند فتح التعديل', (
      WidgetTester tester,
    ) async {
      distributions.emitOne(testDistributionCard());
      // ★★ **والسعرُ في مستنده الفرعي وحدَه** — [`ADR-0011`].
      distributions.emitPricing(
        DistributionPricingCard(
          sourceId: 'SRC-001',
          debtValue: Money(40000),
          unitPrices: <Money?>[Money(500)],
          lineTotals: <Money?>[Money(40000)],
        ),
      );
      await pumpDistribution(tester);
      await openAmendForm(tester);

      final TextField price = tester.widget<TextField>(
        find.widgetWithText(TextField, 'السعر (أو اتركه لاحقاً)'),
      );
      expect(price.controller!.text, '500');
    });

    testWidgets('⛔⛔ وحفظُ تعديلٍ بلا مساسٍ بالسعر يُرسله كما هو', (
      WidgetTester tester,
    ) async {
      distributions.emitOne(testDistributionCard());
      distributions.emitPricing(
        DistributionPricingCard(
          sourceId: 'SRC-001',
          debtValue: Money(40000),
          unitPrices: <Money?>[Money(500)],
          lineTotals: <Money?>[Money(40000)],
        ),
      );
      await pumpDistribution(tester);
      await openAmendForm(tester);

      await tester.tap(find.text('حفظ التعديل'));
      await tester.pump(const Duration(milliseconds: 20));

      expect(admin.amendCalls, 1);
      expect(admin.lastDistribution!.lines.single.unitPrice, const Money(500));
    });

    testWidgets('⛔ وتوزيعةٌ بلا سعر تبقى بحقلٍ فارغ — FR-M10-08', (
      WidgetTester tester,
    ) async {
      distributions.emitOne(testDistributionCard());
      await pumpDistribution(tester);
      await openAmendForm(tester);

      final TextField price = tester.widget<TextField>(
        find.widgetWithText(TextField, 'السعر (أو اتركه لاحقاً)'),
      );
      expect(price.controller!.text, isEmpty);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('⛔⛔★★★ ولا يُعبَّئ سبب التعديل نيابةً عن المستخدم', () {
    // ⛔⛔★★★ **وبعد `ADR-0020` صار «الفارغ» يُرسَل غياباً لا نصّاً فارغاً**
    //    — ★ **والسحابة تقبله**، ⟵ **فالحارس الباقي أن التطبيق لا يخترع
    //    نصّاً**، ⛔ **وأن الفراغات لا تُخزَّن حقلاً يبدو مملوءاً.**
    testWidgets('★ ما لم يكتبه إنسانٌ يُرسَل غياباً — ⛔ لا نصّاً ولا فراغاً', (
      WidgetTester tester,
    ) async {
      distributions.emitOne(testDistributionCard());
      await pumpDistribution(tester);
      await openAmendForm(tester);

      await tester.tap(find.text('حفظ التعديل'));
      await tester.pump(const Duration(milliseconds: 20));

      expect(admin.amendCalls, 1);
      // ⛔ **ولا نصّ مخترَع يسدّ الفراغ** — `CLAUDE.md` · `ADR-0020` القيد 1.
      expect(admin.lastAmendReason, isNull);
    });

    testWidgets('✅ وما كتبه يصل كما هو', (WidgetTester tester) async {
      distributions.emitOne(testDistributionCard());
      await pumpDistribution(tester);
      await openAmendForm(tester);

      await scrollFormTo(tester, find.text('سبب التعديل (اختياري)'));
      await tester.enterText(
        find.widgetWithText(TextField, 'سبب التعديل (اختياري)'),
        'تصحيح كمية',
      );
      await tester.tap(find.text('حفظ التعديل'));
      await tester.pump(const Duration(milliseconds: 20));
      expect(admin.lastAmendReason, 'تصحيح كمية');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('★ الإلغاء — GR-07 · E-15', () {
    testWidgets('⛔⛔★★★ ولا زرّ حذف إطلاقاً — والإلغاء بديلُه المعتمَد', (
      WidgetTester tester,
    ) async {
      distributions.emitOne(testDistributionCard());
      await pumpDistribution(tester);

      // ⛔⛔★★★ **وطلبُ المالك في `AM-009` قال «حذف»** — ★ **ونُفِّذ إلغاءً**:
      //    `GR-07` · `ADR-0004` · `CLAUDE.md` («لا حذف بيانات … لأي مستخدم
      //    بمن فيهم المالك») ⟵ **والإلغاء هو المكافئ** (`FR-M10-18`).
      expect(find.byIcon(Icons.delete), findsNothing);
      expect(find.byIcon(Icons.delete_outline), findsNothing);
      expect(find.byIcon(Icons.delete_forever), findsNothing);
      expect(find.text('حذف'), findsNothing);
      expect(find.byIcon(Icons.block_outlined), findsOneWidget);
    });

    testWidgets('★ ورفضُ السحابة يُعرَض بنصّ الكتالوج', (
      WidgetTester tester,
    ) async {
      admin.rejection = const ValidationError('ERR_AMEND_005');
      distributions.emitOne(testDistributionCard());
      await pumpDistribution(tester);
      await tester.tap(find.byIcon(Icons.block_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.text('تأكيد الإلغاء'));
      await tester.pump(const Duration(milliseconds: 20));

      expect(admin.cancelCalls, 1);
      // ★ **ورسالةٌ ظاهرة لا صمت** — ⛔ **والصمت بعد فشلٍ أخطر من الفشل.**
      expect(find.textContaining('❌'), findsWidgets);
    });

    testWidgets('✅★★★ ADR-0020: ويُقبَل الإلغاء بلا سببٍ — ويصل غياباً', (
      WidgetTester tester,
    ) async {
      distributions.emitOne(testDistributionCard());
      await pumpDistribution(tester);
      await tester.tap(find.byIcon(Icons.block_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.text('تأكيد الإلغاء'));
      await tester.pump(const Duration(milliseconds: 20));

      expect(admin.cancelCalls, 1);
      expect(admin.lastCancelReason, isNull);
    });

    testWidgets('⛔ والملغاة لا تُعدَّل', (WidgetTester tester) async {
      distributions.emitOne(
        testDistributionCard(status: DistributionStatus.cancelled),
      );
      await pumpDistribution(tester);

      expect(find.text('ملغى'), findsOneWidget);
      // ⛔ **ولا زرَّ تعديلٍ ولا إلغاءٍ على مستندٍ ملغى.**
      expect(find.byIcon(Icons.edit_outlined), findsNothing);
      expect(find.byIcon(Icons.block_outlined), findsNothing);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('★★★ P3 · P8 — رأس السياق والشريط الثابت (ADR-0021 · §5b)', () {
    testWidgets('★ رأسُ سياقٍ بصفٍّ واحد بدل أربعة مستويات', (
      WidgetTester tester,
    ) async {
      distributions.emitOne(null);
      await pumpDistribution(tester);

      expect(find.byType(QtmsContextHeader), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    });

    testWidgets('★★★ والملخّصُ المالي والزرُّ في شريطٍ ثابت أسفل الورقة', (
      WidgetTester tester,
    ) async {
      distributions.emitOne(null);
      await pumpDistribution(tester);
      await openNewForm(tester);
      await pickDealer(tester);

      expect(find.byType(QtmsStickyActionBar), findsOneWidget);
      // ★★ **والإجماليان داخل الشريط** — ⟵ **فالأثرُ مرئيٌّ لحظةَ الإدخال**،
      //    ⛔ **لا بعد تمريرٍ إلى آخر الأنواع.**
      expect(find.textContaining('إجمالي الحبات'), findsOneWidget);
      expect(find.text('حفظ التوزيعة'), findsOneWidget);
    });

    testWidgets('⛔⛔★★★ ولا مدمّرَ داخل نموذج التعديل — موضعُه السجلّ', (
      WidgetTester tester,
    ) async {
      distributions.emitOne(testDistributionCard());
      await pumpDistribution(tester);
      await openAmendForm(tester);

      // ★★★ **والإلغاء انتقل إلى صفّ إجراءات السجلّ** — `AM-009` ⑦:
      //    ⟵ **فلا يقع تحت إصبعٍ تقصد الحفظ داخل النموذج أصلاً.**
      expect(find.text('إلغاء التوزيعة'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(QtmsStickyActionBar),
          matching: find.text('حفظ التعديل'),
        ),
        findsOneWidget,
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('★ الصلاحيات — إخفاءٌ لا حماية', () {
    testWidgets('⛔ بلا `distributionCreate` لا يظهر الزرُّ العائم', (
      WidgetTester tester,
    ) async {
      distributions.emitOne(null);
      await pumpDistribution(
        tester,
        actorPermissions: const <Permission>{Permission.dealerWrite},
      );
      expect(find.text('توزيعة جديدة'), findsNothing);
    });

    testWidgets('⛔ وبلا `distributionCancel` لا يظهر زر الإلغاء', (
      WidgetTester tester,
    ) async {
      distributions.emitOne(testDistributionCard());
      await pumpDistribution(
        tester,
        actorPermissions: const <Permission>{
          Permission.distributionCreate,
          Permission.distributionAmend,
        },
      );
      expect(find.byIcon(Icons.block_outlined), findsNothing);
      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    });

    testWidgets('⛔ وبلا `distributionAmend` لا يظهر زر التعديل', (
      WidgetTester tester,
    ) async {
      distributions.emitOne(testDistributionCard());
      await pumpDistribution(
        tester,
        actorPermissions: const <Permission>{Permission.distributionCreate},
      );
      expect(find.byIcon(Icons.edit_outlined), findsNothing);
      // ★ **والعرضُ بلا مفتاح** — ⟵ **القراءة يحكمها النطاق وحده.**
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('⛔⛔★★★ DEBT-68 — وجهةُ المركز المعلّق لا تُسقِط الشاشة', () {
    PendingFocus focusOn(String documentId) => PendingFocus(
          kind: PendingDocumentKind.distribution,
          sourceId: 'SRC-001',
          documentId: documentId,
          field: PendingMissingField.distributionLinePricing,
        );

    testWidgets('★★★ الشاشة تُبنى بلا استثناء — والكتابة بعد أول إطار', (
      WidgetTester tester,
    ) async {
      await pumpWithPendingFocus(
        tester,
        focus: focusOn('MQT-0001_SRC-001_20260827'),
      );
      // ⛔ **بلا الإصلاح يرمي Riverpod هنا** — ★ **والاختبار يقيس العطل
      //   لا يصفه** (`troubleshooting-guide.md` §5).
      expect(tester.takeException(), isNull);
      expect(find.byType(DistributionScreen), findsOneWidget);
    });

    testWidgets('★★ وتُستهلَك الوجهة مرةً واحدة — فلا تعلق', (
      WidgetTester tester,
    ) async {
      final ProviderContainer container = await pumpWithPendingFocus(
        tester,
        focus: focusOn('MQT-0001_SRC-001_20260827'),
      );
      expect(container.read(pendingFocusProvider), isNull);
    });

    testWidgets('★★ والمقوت المقصود يُضبَط في حقل البحث', (
      WidgetTester tester,
    ) async {
      distributions.emitOne(testDistributionCard());
      await pumpWithPendingFocus(
        tester,
        focus: focusOn('MQT-0001_SRC-001_20260827'),
      );
      await tester.pump(const Duration(milliseconds: 20));
      expect(find.text('مقوت مثال'), findsWidgets);
    });

    testWidgets('⛔ ومعرّفٌ لا يطابق الشكل يُهمَل ولا يُخمَّن مقوت', (
      WidgetTester tester,
    ) async {
      await pumpWithPendingFocus(tester, focus: focusOn('لا-يطابق-الشكل'));
      expect(tester.takeException(), isNull);
      // ★ **وحقلُ البحث يبقى فارغاً** — ⛔ **ولا يُملأ باسمٍ مُخمَّن.**
      final TextField search = tester.widget<TextField>(
        find.widgetWithText(TextField, 'بحث بالمقوت'),
      );
      expect(search.controller!.text, isEmpty);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // ⛔⛔★★★ [`DEBT-86`] — ما يدخل المخزنَ من جونية يُوزَّع
  // ═══════════════════════════════════════════════════════════════════════
  //
  // ★ **مقيسٌ على `Pixel_6_API_36` (2026-09-02):** **«عتود» ورد في جونية**
  //   ⟹ **دخل الدفترَ بمفتاحٍ مركّب** (`ADR-0007`)، ⛔ **والمنسدلُ كان يُبنى
  //   من `items` بمعرّفاتِ `itemId`** — ⟵ **فلم يظهر المفتاحُ قطّ.**
  group('⛔⛔★★★ DEBT-86 — سطرُ الجونية يُوزَّع من الشاشة', () {
    testWidgets(
      '✅★★★ المفتاحُ المركّب خيارٌ في المنسدل ويُرسَل كما هو في الدفتر',
      (WidgetTester tester) async {
        // ★★ **والكتالوجُ يحمل «عتود» بمعرّفه** — ⛔ **والدفترُ يحمل المركّب**:
        //    ⟵ **وهما مفتاحان مختلفان**، ★ **والدفترُ هو الحَكَم** (`ADR-0008`).
        masterData.emitItems(<ItemCard>[
          testItem(itemId: 'ITM-0003', name: 'عتود'),
        ]);
        inventory.emitStock(<ItemDailyBalanceCard>[
          // ⛔⛔★★ **والشكلُ المخزَّن الحقيقي: مفتاحٌ مركّبٌ واسمٌ مجرَّد**
          //    (مقيسٌ على التجريبية) — ★ **والعرضُ يُركِّبه** (`ADR-0007`).
          testBalance(
            itemKey: 'عتود - جونية رقم 1',
            itemName: 'عتود',
            incoming: 100,
            outgoing: 0,
          ),
        ]);
        distributions.emitOne(null);
        await pumpDistribution(tester);
        await openNewForm(tester);
        await pickDealer(tester);
        await addLine(
          tester,
          item: 'عتود - جونية رقم 1 (100 حبة)',
          quantity: '10',
        );

        await tester.tap(find.text('حفظ التوزيعة'));
        await tester.pump(const Duration(milliseconds: 20));

        expect(admin.createCalls, 1);
        final ValidatedDistributionLine line =
            admin.lastDistribution!.lines.single;
        // ⛔⛔★★★ **والمُرسَلُ مفتاحُ الدفتر** — ⛔ **لا `ITM-0003`**:
        //    ⟵ **وهو حرفياً ما كانت السحابة ترفضه بـ«الكمية غير كافية».**
        expect(line.itemId, 'عتود - جونية رقم 1');
        expect(line.itemName, 'عتود - جونية رقم 1');
        expect(line.quantity, PieceQuantity(const PieceCount(10)));
      },
    );

    testWidgets(
      '⛔⛔★★ ونوعٌ في الكتالوج بلا رصيدٍ اليوم لا يُعرَض خياراً',
      (WidgetTester tester) async {
        masterData.emitItems(<ItemCard>[
          testItem(itemId: 'ITM-0009', name: 'بطّوه'),
        ]);
        inventory.emitStock(const <ItemDailyBalanceCard>[]);
        distributions.emitOne(null);
        await pumpDistribution(tester);
        await openNewForm(tester);
        await pickDealer(tester);

        // ★ **ولا زرَّ إضافةِ سطرٍ أصلاً** — ⟵ **والنصُّ يقول العلّة.**
        expect(find.text('لا مخزون في هذا المصدر اليوم.'), findsOneWidget);
        expect(find.text('إضافة نوع'), findsNothing);
      },
    );
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('★★★ WU-019 — التصريفُ المتأخر مثبَّتاً على يومه', () {
    /// ★ **يومُ مخزونٍ أقدمُ من [fixedDay] بيومين.**
    final CalendarDay pinnedDay = CalendarDay(2026, 8, 25);

    Future<void> pumpPinnedForm(WidgetTester tester) async {
      final FakeAuthRepository auth = FakeAuthRepository();
      final FakeUserCardRepository cards = FakeUserCardRepository();
      auth.emitIdentity(
        const AuthenticatedIdentity(userId: 'U-001', sourceScope: AllSources()),
      );
      cards.emitCard(
        'U-001',
        testCard(
          permissions: <Permission>{
            ...fullPermissions,
            Permission.agedRemainderClear,
          },
        ),
      );

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
            distributionDirectoryProvider.overrideWithValue(distributions),
            distributionAdminProvider.overrideWithValue(admin),
            todayProvider.overrideWithValue(fixedDay),
          ],
          child: MaterialApp(
            locale: const Locale('ar'),
            home: Scaffold(
              body: DistributionFormSheet(
                sourceId: 'SRC-001',
                pinnedStockDate: pinnedDay,
                pinnedItemKey: 'ITM-0002',
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
    }

    testWidgets('⚠️★★★ شريطُ التنبيه بنصّ المتطلب — FR-M8-12',
        (WidgetTester tester) async {
      await pumpPinnedForm(tester);

      expect(
        find.textContaining('أنت تصرّف مخزون يوم 2026/08/25'),
        findsOneWidget,
      );
      expect(
        find.textContaining('سيُحتسب في ضمار ذلك اليوم لا في اليوم الحالي'),
        findsOneWidget,
      );
    });

    testWidgets('🔒★★★ والمصدرُ مقفلٌ — ⛔ فلا يُصرَّف بندٌ آخر',
        (WidgetTester tester) async {
      await pumpPinnedForm(tester);

      final DropdownButtonFormField<String> source =
          tester.widget<DropdownButtonFormField<String>>(
        find.byType(DropdownButtonFormField<String>),
      );
      expect(source.onChanged, isNull);
    });

    testWidgets('★★★ والنوعُ مبذورٌ سطراً أول — ⛔ لا نموذجَ فارغ',
        (WidgetTester tester) async {
      await pumpPinnedForm(tester);

      // ★ **صفُّ سطرٍ واحدٌ حاضرٌ قبل أن يضغط المستخدم «إضافة نوع».**
      expect(find.widgetWithText(TextField, 'الكمية'), findsOneWidget);
    });

    testWidgets(
      '⛔⛔★★★ وتاريخُ المخزون يُرسَل مع الإنشاء — لا يومُ المنصّة',
      (WidgetTester tester) async {
        await pumpPinnedForm(tester);
        await pickDealer(tester);
        await tester.enterText(
          find.widgetWithText(TextField, 'الكمية').last,
          '5',
        );
        await tester.pump();
        await scrollFormTo(tester, find.text('حفظ التوزيعة'));
        await tester.tap(find.text('حفظ التوزيعة'));
        await tester.pumpAndSettle();

        expect(admin.createCalls, 1);
        expect(admin.lastCreateStockDate, pinnedDay);
      },
    );
  });
}

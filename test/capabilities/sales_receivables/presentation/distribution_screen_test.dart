/// شاشة التوزيع والضمار — `WU-006`.
///
/// ⚠️⚠️ **وما تُثبته هذه الاختبارات وما لا تُثبته:** تُثبت أن الشاشة
/// **تفتح التوزيعة القائمة للتعديل** (`E-04`)، وأنها **تُخفي قيمة الضمار
/// عمّن لا يملك رؤيتها وتُرسل السعر مع ذلك** (`ت-12` — **أخطر ما في
/// الوحدة**)، وأنها **تفصل الإجماليين** (`GR-19`)، وأنها **لا تُعبِّئ سبب
/// التعديل نيابةً عن المستخدم**.
/// ⛔ **ولا تُثبت أن الكتابة محميّة** — ★ **الحماية في `planDistribution`**،
/// ولها اختباراتها هناك (`functions/test/distribution_test.dart`).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qtms/capabilities/identity_access/application/session_providers.dart';
import 'package:qtms/capabilities/inventory/application/inventory_providers.dart';
import 'package:qtms/capabilities/master_data/application/master_data_providers.dart';
import 'package:qtms/capabilities/sales_receivables/application/distribution_providers.dart';
import 'package:qtms/capabilities/sales_receivables/presentation/distribution_screen.dart';
import 'package:qtms/core/ui/context_header.dart';
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
      child: MaterialApp(
        locale: const Locale('ar'),
        home: const DistributionScreen(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 20));
}

Future<void> selectDealer(WidgetTester tester) async {
  await tester.tap(find.byType(DropdownButtonFormField<String>).last);
  await tester.pumpAndSettle();
  await tester.tap(find.text('مقوت مثال').last);
  await tester.pumpAndSettle();
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
  });

  tearDown(() {
    distributions.dispose();
    masterData.dispose();
    pricing.dispose();
    inventory.dispose();
  });

  group('★ الشاشة تفتح وتعرض المقاوته', () {
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
      await tester.tap(find.byType(DropdownButtonFormField<String>).last);
      await tester.pumpAndSettle();
      expect(find.text('مقوت معطَّل'), findsNothing);
      expect(find.text('مقوت مثال'), findsWidgets);
    });
  });

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
        await selectDealer(tester);
        await tester.pump(const Duration(milliseconds: 20));
        expect(find.text('حفظ التوزيعة'), findsOneWidget);
      },
    );

    testWidgets('★★ وأسعارُ التوزيعة تُطلَب بالمعرّف المركّب — ADR-0011', (
      WidgetTester tester,
    ) async {
      distributions.emitOne(testDistributionCard());
      await pumpDistribution(tester);
      await selectDealer(tester);
      await tester.pump(const Duration(milliseconds: 20));
      expect(
        distributions.requestedIds,
        contains('MQT-0001_SRC-001_20260827'),
      );
    });

    testWidgets('★★ وتوزيعةٌ قائمة تُفتَح بشارتها وسبب تعديلٍ مطلوب', (
      WidgetTester tester,
    ) async {
      distributions.emitOne(testDistributionCard(amendCount: 2));
      await pumpDistribution(tester);
      await selectDealer(tester);
      await tester.pump(const Duration(milliseconds: 20));

      expect(find.textContaining('فُتح للتعديل'), findsOneWidget);
      expect(find.textContaining('مُعدَّل ×2'), findsOneWidget);
      expect(find.text('سبب التعديل (اختياري)'), findsOneWidget);
      expect(find.text('حفظ التعديل'), findsOneWidget);
      // ⛔ **ولا زرّ إنشاء على مستندٍ قائم.**
      expect(find.text('حفظ التوزيعة'), findsNothing);
    });

    testWidgets('★ وغيابُ التوزيعة إنشاءٌ لا خطأ', (
      WidgetTester tester,
    ) async {
      distributions.emitOne(null);
      await pumpDistribution(tester);
      await selectDealer(tester);
      expect(find.text('حفظ التوزيعة'), findsOneWidget);
      expect(find.text('سبب التعديل (اختياري)'), findsNothing);
    });
  });

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
      await selectDealer(tester);
      await tester.pump(const Duration(milliseconds: 20));
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
      await selectDealer(tester);
      await tester.pump(const Duration(milliseconds: 20));
      expect(find.textContaining('قيمة الضمار: 121852'), findsOneWidget);
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
        await selectDealer(tester);
        await tester.pump(const Duration(milliseconds: 20));

        await tester.enterText(find.byType(TextField).first, '80');
        await tester.pump();
        await tester.tap(find.text('حفظ التوزيعة'));
        await tester.pump(const Duration(milliseconds: 20));

        expect(admin.createCalls, 1);
        final ValidatedDistribution sent = admin.lastDistribution!;
        expect(sent.lines.single.unitPrice, const Money(1500));
        // ★ **وقيمة الضمار تُحتسب كاملة** — `FR-M10-07`.
        expect(sent.debtValue, const Money(120000));
      },
    );
  });

  group('⛔ GR-19 — إجماليان منفصلان دائماً', () {
    testWidgets('★ الحبات والأوزان سطران لا سطرٌ واحد', (
      WidgetTester tester,
    ) async {
      distributions.emitOne(null);
      await pumpDistribution(tester);
      await selectDealer(tester);
      await tester.enterText(find.byType(TextField).first, '80');
      await tester.pump();
      expect(find.textContaining('إجمالي الحبات: 80'), findsOneWidget);
      expect(find.textContaining('إجمالي الأوزان: 0.000'), findsOneWidget);
    });
  });

  group('⛔⛔★★★ ولا يُعبَّئ سبب التعديل نيابةً عن المستخدم', () {
    // ⛔⛔★★★ **وبعد `ADR-0020` صار «الفارغ» يُرسَل غياباً لا نصّاً فارغاً**
    //    — ★ **والسحابة تقبله**، ⟵ **فالحارس الباقي أن التطبيق لا يخترع
    //    نصّاً**، ⛔ **وأن الفراغات لا تُخزَّن حقلاً يبدو مملوءاً.**
    testWidgets('★ ما لم يكتبه إنسانٌ يُرسَل غياباً — ⛔ لا نصّاً ولا فراغاً', (
      WidgetTester tester,
    ) async {
      distributions.emitOne(testDistributionCard());
      await pumpDistribution(tester);
      await selectDealer(tester);
      await tester.pump(const Duration(milliseconds: 20));

      await tester.tap(find.text('حفظ التعديل'));
      await tester.pump(const Duration(milliseconds: 20));

      expect(admin.amendCalls, 1);
      // ⛔ **ولا نصّ مخترَع يسدّ الفراغ** — `CLAUDE.md` · `ADR-0020` القيد 1.
      expect(admin.lastAmendReason, isNull);
    });

    testWidgets('✅ وما كتبه يصل كما هو', (WidgetTester tester) async {
      distributions.emitOne(testDistributionCard());
      await pumpDistribution(tester);
      await selectDealer(tester);
      await tester.pump(const Duration(milliseconds: 20));

      await tester.enterText(
        find.widgetWithText(TextField, 'سبب التعديل (اختياري)'),
        'تصحيح كمية',
      );
      await tester.tap(find.text('حفظ التعديل'));
      await tester.pump(const Duration(milliseconds: 20));
      expect(admin.lastAmendReason, 'تصحيح كمية');
    });
  });

  group('★ الإلغاء — GR-07 · E-15', () {
    testWidgets('⛔ ولا زرّ حذف إطلاقاً', (WidgetTester tester) async {
      distributions.emitOne(testDistributionCard());
      await pumpDistribution(tester);
      await selectDealer(tester);
      await tester.pump(const Duration(milliseconds: 20));
      await tester.dragUntilVisible(
        find.text('إلغاء التوزيعة'),
        find.byType(ListView),
        const Offset(0, -80),
      );
      expect(find.text('حذف'), findsNothing);
      expect(find.text('إلغاء التوزيعة'), findsOneWidget);
    });

    testWidgets('★ ورفضُ السحابة يُعرَض بنصّ الكتالوج', (
      WidgetTester tester,
    ) async {
      admin.rejection = const ValidationError('ERR_AMEND_005');
      distributions.emitOne(testDistributionCard());
      await pumpDistribution(tester);
      await selectDealer(tester);
      await tester.pump(const Duration(milliseconds: 20));
      await tester.dragUntilVisible(
        find.text('إلغاء التوزيعة'),
        find.byType(ListView),
        const Offset(0, -80),
      );
      // ⚠️★★ **ودفعةٌ إضافية بعد ظهوره** — §5b `P8`: ★ **الشريطُ الثابت
      //    يحتلّ أسفل الشاشة**، ⟵ **فأولُ ظهورٍ للزرّ قد يقع خلفه**
      //    ⛔ **فتُصيب النقرةُ الشريطَ لا الزرّ.**
      await tester.drag(find.byType(ListView), const Offset(0, -200));
      await tester.pump();
      await tester.tap(find.text('إلغاء التوزيعة'));
      await tester.pump(const Duration(milliseconds: 20));
      expect(admin.cancelCalls, 1);
      // ★ **ورسالةٌ ظاهرة لا صمت** — ⛔ **والصمت بعد فشلٍ أخطر من الفشل.**
      expect(find.textContaining('❌'), findsWidgets);
    });

    testWidgets('⛔ والملغاة لا تُعدَّل', (WidgetTester tester) async {
      distributions.emitOne(
        testDistributionCard(status: DistributionStatus.cancelled),
      );
      await pumpDistribution(tester);
      await selectDealer(tester);
      await tester.pump(const Duration(milliseconds: 20));
      expect(find.textContaining('ملغاة'), findsOneWidget);
      expect(find.text('حفظ التعديل'), findsNothing);
    });
  });

  group('★★★ P3 · P8 — رأس السياق والشريط الثابت (ADR-0021 · §5b)', () {
    testWidgets('★ رأسُ سياقٍ بصفٍّ واحد بدل أربعة مستويات', (
      WidgetTester tester,
    ) async {
      distributions.emitOne(null);
      await pumpDistribution(tester);

      expect(find.byType(QtmsContextHeader), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    });

    testWidgets('★★★ والملخّصُ المالي والزرُّ في شريطٍ ثابت أسفل الشاشة', (
      WidgetTester tester,
    ) async {
      distributions.emitOne(null);
      await pumpDistribution(tester);
      await selectDealer(tester);
      await tester.pump(const Duration(milliseconds: 20));

      expect(find.byType(QtmsStickyActionBar), findsOneWidget);
      // ★★ **والإجماليان داخل الشريط** — ⟵ **فالأثرُ مرئيٌّ لحظةَ الإدخال**،
      //    ⛔ **لا بعد تمريرٍ إلى آخر الأنواع.**
      expect(find.textContaining('إجمالي الحبات'), findsOneWidget);
      expect(find.text('حفظ التوزيعة'), findsOneWidget);
    });

    testWidgets('⛔⛔★★★ والمدمّرُ ليس داخل الشريط الثابت', (
      WidgetTester tester,
    ) async {
      distributions.emitOne(testDistributionCard());
      await pumpDistribution(tester);
      await selectDealer(tester);
      await tester.pump(const Duration(milliseconds: 20));

      // ★ **«إلغاء التوزيعة» في ذيل المحتوى الممرَّر** — §5b `P8` ⑨:
      //   ⟵ **فلا يُلامَس سهواً بإصبعٍ تقصد الحفظ.**
      expect(
        find.descendant(
          of: find.byType(QtmsStickyActionBar),
          matching: find.text('إلغاء التوزيعة'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(QtmsStickyActionBar),
          matching: find.text('حفظ التعديل'),
        ),
        findsOneWidget,
      );
    });
  });

  group('★ الصلاحيات — إخفاءٌ لا حماية', () {
    testWidgets('⛔ بلا `distributionCreate` لا يظهر زر الحفظ', (
      WidgetTester tester,
    ) async {
      distributions.emitOne(null);
      await pumpDistribution(
        tester,
        actorPermissions: const <Permission>{Permission.dealerWrite},
      );
      await selectDealer(tester);
      expect(find.text('حفظ التوزيعة'), findsNothing);
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
      await selectDealer(tester);
      await tester.pump(const Duration(milliseconds: 20));
      expect(find.text('إلغاء التوزيعة'), findsNothing);
      expect(find.text('حفظ التعديل'), findsOneWidget);
    });
  });
}

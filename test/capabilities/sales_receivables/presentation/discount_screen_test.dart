/// شاشة الخصومات — `WU-013`.
///
/// ⚠️⚠️ **وما تُثبته هذه الاختبارات وما لا تُثبته:** تُثبت أن الشاشة
/// **تعرض إجمالي الديون فور اختيار المقوت** (`FR-M13-01`)، وأن **التوزيع
/// التلقائي يملأ الحقول ولا يحفظ** (`FR-M13-07`)، وأن **لا حقلَ فائضٍ فيها
/// إطلاقاً** (`FR-M13-05` — **أخطر ما في الوحدة**)، وأن **ما يُرسَل يذهب
/// إلى مستودع الخصم لا مستودع القبض** (`FR-M15-06-أ`).
/// ⛔ **ولا تُثبت أن الكتابة محميّة** — ★ **الحماية في `planDiscount`**،
/// ولها اختباراتها هناك (`functions/test/discount_test.dart`).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qtms/capabilities/identity_access/application/session_providers.dart';
import 'package:qtms/capabilities/inventory/application/inventory_providers.dart';
import 'package:qtms/capabilities/master_data/application/master_data_providers.dart';
import 'package:qtms/capabilities/sales_receivables/application/discount_providers.dart';
import 'package:qtms/capabilities/sales_receivables/presentation/discount_screen.dart';
import 'package:qtms_domain/qtms_domain.dart';

import '../../../support/fake_discounts.dart';
import '../../../support/fake_identity.dart';
import '../../../support/fake_master_data.dart';

/// ★★ **اليوم مثبَّت** — ⛔ **فلا اختبارَ ينكسر بمرور منتصف الليل.**
final CalendarDay fixedDay = CalendarDay(2026, 9, 1);

late FakeDiscountDirectory discounts;
late FakeDiscountAdminRepository admin;
late FakeMasterDataDirectory masterData;

const Set<Permission> fullPermissions = <Permission>{
  Permission.discountCreate,
  Permission.discountAmend,
  Permission.discountCancel,
  Permission.discountBackdate,
};

OpenDebtLot lot({
  int stockDay = 20,
  int remaining = 30000,
  String sourceId = 'SRC-001',
}) =>
    OpenDebtLot(
      debtLotId: distributionId(
        dealerId: 'MQT-0001',
        sourceId: sourceId,
        stockDate: CalendarDay(2026, 8, stockDay),
      ),
      sourceId: sourceId,
      stockDate: CalendarDay(2026, 8, stockDay),
      remaining: Money(remaining),
    );

Future<void> pumpDiscounts(
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
        discountDirectoryProvider.overrideWithValue(discounts),
        discountAdminProvider.overrideWithValue(admin),
        todayProvider.overrideWithValue(fixedDay),
      ],
      child: const MaterialApp(
        locale: Locale('ar'),
        home: DiscountScreen(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 20));
}

/// ★ يُمرِّر حتى يظهر الودجت — ⛔ **فالقائمة تُبنى كسولاً في مقاس الاختبار**.
Future<void> scrollTo(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 2000));
    await tester.pumpAndSettle();
  }
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

/// ★ يُظهِر الودجت ثم يضغطه.
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await scrollTo(tester, finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// ★ حقل ضمارٍ بعينه — **بمفتاحه** ⛔ **لا بترتيبه بين الحقول المرئية.**
Finder lotField(int stockDay, {String sourceId = 'SRC-001'}) =>
    find.byKey(Key('discount-lot-${lot(
      stockDay: stockDay,
      sourceId: sourceId,
    ).debtLotId}'));

Future<void> enterLot(
  WidgetTester tester,
  int stockDay,
  String value,
) async {
  final Finder finder = lotField(stockDay);
  await scrollTo(tester, finder);
  await tester.enterText(finder, value);
  await tester.pumpAndSettle();
}

Future<String?> lotText(WidgetTester tester, int stockDay) async {
  final Finder finder = lotField(stockDay);
  await scrollTo(tester, finder);
  return tester.widget<TextField>(finder).controller?.text;
}

Finder get autoAmountField => find.descendant(
      of: find.byKey(const Key('discount-auto-amount')),
      matching: find.byType(TextField),
    );

Future<void> selectDealer(WidgetTester tester) async {
  await tester.tap(find.byType(DropdownButtonFormField<String>).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text('مقوت مثال').last);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    discounts = FakeDiscountDirectory();
    admin = FakeDiscountAdminRepository();
    masterData = FakeMasterDataDirectory();
    masterData.emitSources(<SourceCard>[testSource()]);
    masterData.emitDealers(<DealerCard>[testDealer()]);
    discounts.emitLots(<OpenDebtLot>[lot()]);
  });

  tearDown(() {
    discounts.dispose();
    masterData.dispose();
  });

  group('★ الشاشة تفتح وتطلب المقوت', () {
    testWidgets('★ بلا مقوتٍ مختار ⟵ إرشادٌ لا نموذج', (
      WidgetTester tester,
    ) async {
      await pumpDiscounts(tester);
      expect(find.text('اختر المقوت'), findsOneWidget);
      expect(find.text('حفظ سند الخصم'), findsNothing);
    });

    testWidgets('★★ `FR-M13-01` — إجمالي الديون يظهر فور اختيار المقوت', (
      WidgetTester tester,
    ) async {
      discounts.emitLots(<OpenDebtLot>[
        lot(remaining: 30000),
        lot(stockDay: 21, remaining: 20000),
      ]);
      await pumpDiscounts(tester);
      await selectDealer(tester);
      expect(
        find.textContaining('إجمالي الديون على المقوت: 50,000'),
        findsOneWidget,
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // ⛔⛔★★★ لا فائضَ في هذه الشاشة — `FR-M13-05` · `AT-35`
  // ═══════════════════════════════════════════════════════════════════════
  group('⛔⛔★★★ لا حقلَ فائضٍ إطلاقاً — `AT-35`', () {
    testWidgets('⛔⛔★★★ ولا حقلَ بمفتاح الفائض ولا بنصّه', (
      WidgetTester tester,
    ) async {
      await pumpDiscounts(tester);
      await selectDealer(tester);
      // ★ **مفتاحُ حقل الفائض في شاشة القبض** — ⛔ **ولا نظيرَ له هنا.**
      expect(find.byKey(const Key('receipt-surplus')), findsNothing);
      expect(find.textContaining('فائض'), findsNothing);
    });

    testWidgets('⛔⛔★★★ والنصُّ يقول «الخصم» لا «الواصل»', (
      WidgetTester tester,
    ) async {
      await pumpDiscounts(tester);
      await selectDealer(tester);
      await scrollTo(tester, lotField(20));
      expect(find.text('الخصم'), findsOneWidget);
      expect(find.text('الواصل'), findsNothing);
    });

    testWidgets('⛔⛔★★ ويُصرَّح أنه بلا أثرٍ نقدي', (
      WidgetTester tester,
    ) async {
      await pumpDiscounts(tester);
      await selectDealer(tester);
      expect(
        find.textContaining('بلا أثر نقدي'),
        findsOneWidget,
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // ★★★ الحفظ — `FR-M13-02` · `FR-M15-06-أ`
  // ═══════════════════════════════════════════════════════════════════════
  group('★★★ الحفظ يذهب إلى مستودع الخصم', () {
    testWidgets('★★★ سطرٌ واحد ⟵ طلبُ إنشاءٍ بسطرٍ واحد بمبلغه', (
      WidgetTester tester,
    ) async {
      await pumpDiscounts(tester);
      await selectDealer(tester);
      await enterLot(tester, 20, '3000');
      await tapVisible(tester, find.byKey(const Key('discount-save')));

      expect(admin.created, hasLength(1));
      final CreatedDiscount request = admin.created.single;
      expect(request.dealerId, 'MQT-0001');
      expect(request.lines, hasLength(1));
      expect(request.lines.single.amount, const Money(3000));
      expect(request.date, fixedDay);
    });

    testWidgets('⛔⛔★★ وسندٌ بلا سطرٍ يُرفَض قبل أي رحلةِ شبكة', (
      WidgetTester tester,
    ) async {
      await pumpDiscounts(tester);
      await selectDealer(tester);
      await tapVisible(tester, find.byKey(const Key('discount-save')));
      // ⛔ **ولا فائضَ يُنقِذه** — ★ **وهنا يفترق عن سند القبض.**
      expect(admin.created, isEmpty);
      expect(
        find.textContaining('أدخل مبلغ خصمٍ على ضمارٍ واحد على الأقل'),
        findsOneWidget,
      );
    });

    testWidgets('★★ ورقمُ السند يُعرَض بعد النجاح', (
      WidgetTester tester,
    ) async {
      await pumpDiscounts(tester);
      await selectDealer(tester);
      await enterLot(tester, 20, '3000');
      await tapVisible(tester, find.byKey(const Key('discount-save')));
      expect(
        find.textContaining('حُفِظ سند الخصم DSC-20260901-0001'),
        findsOneWidget,
      );
    });

    testWidgets('⛔★★ ورفضُ السحابة يُعرَض ولا يُبتلَع', (
      WidgetTester tester,
    ) async {
      admin.nextResult =
          const Failure<String>(ValidationError('BR-M13-02'));
      await pumpDiscounts(tester);
      await selectDealer(tester);
      await enterLot(tester, 20, '3000');
      await tapVisible(tester, find.byKey(const Key('discount-save')));
      // ★ **والحقولُ لا تُمسَح عند الفشل** — ⟵ **فلا يُعيد المستخدم إدخالها.**
      expect(await lotText(tester, 20), '3000');
    });

    testWidgets('⛔⛔★★★ والمصادر تصل مُعدَّدة لا غياباً — `DEBT-40`', (
      WidgetTester tester,
    ) async {
      await pumpDiscounts(tester);
      await selectDealer(tester);
      expect(discounts.requestedSources, isNotEmpty);
      expect(discounts.requestedSources.last, <String>['SRC-001']);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // ★★ التوزيع التلقائي — `FR-M13-07`
  // ═══════════════════════════════════════════════════════════════════════
  group('★★ التوزيعُ التلقائي يملأ الحقول ⛔ ولا يحفظ', () {
    testWidgets('★★★ يملأ الحقول بالأقدم أولاً ⛔ ولا يُرسِل شيئاً', (
      WidgetTester tester,
    ) async {
      discounts.emitLots(<OpenDebtLot>[
        lot(stockDay: 20, remaining: 8000),
        lot(stockDay: 21, remaining: 5000),
      ]);
      await pumpDiscounts(tester);
      await selectDealer(tester);
      await scrollTo(tester, autoAmountField);
      await tester.enterText(autoAmountField, '10000');
      await tester.pumpAndSettle();
      await tapVisible(
        tester,
        find.byKey(const Key('discount-auto-allocate')),
      );

      expect(await lotText(tester, 20), '8000');
      expect(await lotText(tester, 21), '2000');
      // ⛔⛔★★★ **ولم يُحفَظ شيء** — `FR-M13-07`: **اقتراحٌ لا قرار.**
      expect(admin.created, isEmpty);
    });

    testWidgets('⛔⛔★★ وما يزيد يُعرَض «لم تُوزَّع» ⛔ لا «فائضاً»', (
      WidgetTester tester,
    ) async {
      discounts.emitLots(<OpenDebtLot>[lot(stockDay: 20, remaining: 8000)]);
      await pumpDiscounts(tester);
      await selectDealer(tester);
      await scrollTo(tester, autoAmountField);
      await tester.enterText(autoAmountField, '20000');
      await tester.pumpAndSettle();
      await tapVisible(
        tester,
        find.byKey(const Key('discount-auto-allocate')),
      );
      expect(find.textContaining('12,000 ريال لم تُوزَّع'), findsOneWidget);
      expect(find.textContaining('فائض'), findsNothing);
    });

    testWidgets('★ والمستخدم يُعدِّل الاقتراح قبل الحفظ فيُرسَل المعدَّل', (
      WidgetTester tester,
    ) async {
      discounts.emitLots(<OpenDebtLot>[lot(stockDay: 20, remaining: 8000)]);
      await pumpDiscounts(tester);
      await selectDealer(tester);
      await scrollTo(tester, autoAmountField);
      await tester.enterText(autoAmountField, '8000');
      await tester.pumpAndSettle();
      await tapVisible(
        tester,
        find.byKey(const Key('discount-auto-allocate')),
      );
      // ★ **ثم يُخفِّضه المستخدم** — ⟵ **وما يُرسَل ما في الحقل.**
      await enterLot(tester, 20, '2500');
      await tapVisible(tester, find.byKey(const Key('discount-save')));
      expect(admin.created.single.lines.single.amount, const Money(2500));
      expect(admin.created.single.usedAutoAllocation, isTrue);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // ★★ العرض اللحظي — ⛔ **والرفض الحقيقي في السحابة**
  // ═══════════════════════════════════════════════════════════════════════
  group('★★ التجاوزُ يُعرَض لحظياً — ⛔ والحارس في السحابة', () {
    testWidgets('⛔ مبلغٌ يتجاوز المتبقي ⟵ «يتجاوز المتبقي»', (
      WidgetTester tester,
    ) async {
      discounts.emitLots(<OpenDebtLot>[lot(stockDay: 20, remaining: 8000)]);
      await pumpDiscounts(tester);
      await selectDealer(tester);
      await enterLot(tester, 20, '8001');
      expect(find.text('يتجاوز المتبقي'), findsOneWidget);
    });

    testWidgets('★ والمتبقي بعده يُحسَب لحظياً', (
      WidgetTester tester,
    ) async {
      discounts.emitLots(<OpenDebtLot>[lot(stockDay: 20, remaining: 8000)]);
      await pumpDiscounts(tester);
      await selectDealer(tester);
      await enterLot(tester, 20, '3000');
      expect(find.text('بعده: 5,000'), findsOneWidget);
    });

    testWidgets('★★ وإجمالي الخصم يُعرَض في الشريط الملتصق', (
      WidgetTester tester,
    ) async {
      discounts.emitLots(<OpenDebtLot>[
        lot(stockDay: 20, remaining: 8000),
        lot(stockDay: 21, remaining: 5000),
      ]);
      await pumpDiscounts(tester);
      await selectDealer(tester);
      await enterLot(tester, 20, '3000');
      await enterLot(tester, 21, '1000');
      expect(find.textContaining('إجمالي الخصم: 4,000'), findsOneWidget);
      // ⛔⛔★★★ **ولا يُسمّى «مقبوضاً»** — `FR-M15-06-أ`.
      expect(find.textContaining('إجمالي المقبوض'), findsNothing);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // ★★ الحالة الفارغة — ⛔ **ولا تُلمَّح إلى فائض**
  // ═══════════════════════════════════════════════════════════════════════
  group('★★ لا ضمارات مفتوحة', () {
    testWidgets('⛔⛔★★ ولا شيءَ يُخصَم — ⛔ ولا اقتراحَ فائضٍ كما في القبض', (
      WidgetTester tester,
    ) async {
      discounts.emitLots(const <OpenDebtLot>[]);
      await pumpDiscounts(tester);
      await selectDealer(tester);
      expect(find.text('لا ضمارات مفتوحة'), findsOneWidget);
      expect(find.textContaining('ولا شيء يُخصَم منه'), findsOneWidget);
      // ★ **وشاشةُ القبض تقترح هنا تسجيلَ فائض** — ⛔ **وهذه لا تفعل.**
      expect(find.textContaining('مقدَّم'), findsNothing);
    });
  });
}

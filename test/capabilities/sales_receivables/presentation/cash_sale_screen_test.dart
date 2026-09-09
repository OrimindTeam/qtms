/// شاشة البيع النقدي المباشر — `WU-012` (`M11`).
///
/// ⚠️⚠️ **وما تُثبته هذه الاختبارات وما لا تُثبته:** تُثبت أن الشاشة **تعرض
/// سجلات اليوم برقم السند**، وأنها ⛔⛔ **لا تعرض حقل مقوتٍ ولا رصيدَ ذمّة
/// إطلاقاً** (`FR-M11-03` — **أخطر ما في الوحدة**)، وأنها **تُنبِّه على السعر
/// دون الحد الأدنى** (`FR-M11-05`)، وأنها **لا تُرسل سطراً بلا سعر**
/// (`FR-M11-04`)، وأنها **تفصل الإجماليين** (`GR-19`)، وأنها **لا تُعبِّئ
/// سبب التعديل نيابةً عن المستخدم** (`ADR-0020`)، و⛔⛔ **أنها لا تعرض زرَّ
/// حذفٍ إطلاقاً** (`GR-07`).
///
/// ⛔ **ولا تُثبت أن الكتابة محميّة** — ★ **الحماية في `planCashSale`**،
/// ولها اختباراتها هناك (`functions/test/cash_sale_test.dart`).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qtms/capabilities/identity_access/application/session_providers.dart';
import 'package:qtms/capabilities/inventory/application/inventory_providers.dart';
import 'package:qtms/capabilities/master_data/application/master_data_providers.dart';
import 'package:qtms/capabilities/sales_receivables/application/cash_sale_providers.dart';
import 'package:qtms/capabilities/sales_receivables/presentation/cash_sale_screen.dart';
import 'package:qtms/core/ui/search_field.dart';
import 'package:qtms/core/ui/sticky_action_bar.dart';
import 'package:qtms_domain/qtms_domain.dart';

import '../../../support/fake_cash_sale.dart';
import '../../../support/fake_identity.dart';
import '../../../support/fake_inventory.dart';
import '../../../support/fake_master_data.dart';

/// ★★ **اليوم مثبَّت** — ⛔ **فلا اختبارَ ينكسر بمرور منتصف الليل.**
final CalendarDay fixedDay = CalendarDay(2026, 8, 27);

late FakeCashSaleDirectory sales;
late FakeCashSaleAdmin admin;
late FakeMasterDataDirectory masterData;
late FakeDailyPricingDirectory pricing;
late FakeInventoryDirectory inventory;

const Set<Permission> fullPermissions = <Permission>{
  Permission.cashSaleCreate,
  Permission.cashSaleAmend,
  Permission.cashSaleCancel,
  Permission.cashSaleBelowMinimum,
};

Future<void> pumpCashSale(
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
        cashSaleDirectoryProvider.overrideWithValue(sales),
        cashSaleAdminProvider.overrideWithValue(admin),
        todayProvider.overrideWithValue(fixedDay),
      ],
      child: const MaterialApp(
        locale: Locale('ar'),
        home: CashSaleScreen(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 20));
}

/// ★★★ **يفتح نموذج الإنشاء من الزرّ العائم**.
Future<void> openNewForm(WidgetTester tester) async {
  await tester.tap(find.text('بيع نقدي جديد'));
  await tester.pumpAndSettle();
}

/// ★★★ **يضيف سطرَ نوعٍ** — `AM-009` ④: **زرُّ `+` ثم منسدلٌ يُصفّي.**
Future<void> addLine(
  WidgetTester tester, {
  /// ★★ **والنصُّ يحمل المتبقّي** — `FR-M10-06` · [`DEBT-86`]: ⟵ **فالخيارُ
  ///    من رصيد الدفتر**، ⛔ **ولا اسمٌ مجرَّدٌ في القائمة.**
  String item = 'عود (100 حبة)',
  required String quantity,
  String? price,
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
  if (price != null) {
    await tester.enterText(
      find.widgetWithText(TextField, 'السعر').last,
      price,
    );
    await tester.pump();
  }
}

/// ★ يضغط زرَّ الحفظ.
Future<void> save(WidgetTester tester) async {
  await tester.tap(find.text('حفظ السند'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    sales = FakeCashSaleDirectory();
    admin = FakeCashSaleAdmin();
    masterData = FakeMasterDataDirectory();
    pricing = FakeDailyPricingDirectory();
    inventory = FakeInventoryDirectory();
    masterData.emitSources(<SourceCard>[testSource()]);
    masterData.emitItems(<ItemCard>[testItem()]);
    // ★★ **ورصيدُ اليوم هو مصدرُ الخيارات** — [`DEBT-86`].
    inventory.emitStock(<ItemDailyBalanceCard>[testBalance()]);
    sales.emitList(const <CashSaleCard>[]);
  });

  tearDown(() {
    sales.dispose();
    masterData.dispose();
    pricing.dispose();
    inventory.dispose();
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('★★★ البنية — سجلاتٌ ومرشِّحان وزرٌّ عائم (AM-009 ⑦)', () {
    testWidgets('★★★ تعرض سجلات اليوم برقم السند — ⛔ لا نموذجَ مفتوح',
        (WidgetTester tester) async {
      sales.emitOne(testCashSaleCard());
      await pumpCashSale(tester);

      expect(find.text('CSH-20260827-0001'), findsWidgets);
      // ⛔⛔ **ولا نموذجَ إدخالٍ قبل أن يطلبه المستخدم.**
      expect(find.text('إضافة نوع'), findsNothing);
      expect(find.text('بيع نقدي جديد'), findsOneWidget);
    });

    testWidgets('★★ ومرشِّحُ المصدر يحمل «كل المصادر»',
        (WidgetTester tester) async {
      await pumpCashSale(tester);
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      expect(find.text('كل المصادر'), findsWidgets);
    });

    testWidgets('★★ وبحثٌ برقم السند يُصفّي السجلات',
        (WidgetTester tester) async {
      sales.emitList(<CashSaleCard>[
        testCashSaleCard(),
        testCashSaleCard(documentNumber: 'CSH-20260827-0002'),
      ]);
      await pumpCashSale(tester);
      expect(find.byType(QtmsSearchField), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'بحث برقم السند'),
        '0002',
      );
      await tester.pumpAndSettle();

      expect(find.text('CSH-20260827-0002'), findsWidgets);
      expect(find.text('CSH-20260827-0001'), findsNothing);
    });

    testWidgets('⛔⛔★★★ ولا زرَّ حذفٍ إطلاقاً — GR-07',
        (WidgetTester tester) async {
      sales.emitOne(testCashSaleCard());
      await pumpCashSale(tester);

      expect(find.byIcon(Icons.delete_outline), findsNothing);
      expect(find.byIcon(Icons.delete), findsNothing);
      // ★ **والإلغاء هو المكافئ المعتمَد** — `FR-M11-13`.
      expect(find.byIcon(Icons.block_outlined), findsOneWidget);
    });

    testWidgets('★ وثلاثةُ إجراءاتٍ على كل سجلّ', (WidgetTester tester) async {
      sales.emitOne(testCashSaleCard());
      await pumpCashSale(tester);

      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
      expect(find.byIcon(Icons.block_outlined), findsOneWidget);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('⛔⛔★★★ FR-M11-03 — لا مقوتَ ولا ذمّةَ في هذه الشاشة', () {
    testWidgets('⛔⛔ ولا حقلَ مقوتٍ في النموذج — والغيابُ بنيويٌّ لا شرط',
        (WidgetTester tester) async {
      await pumpCashSale(tester);
      await openNewForm(tester);

      expect(find.widgetWithText(TextField, 'المقوت'), findsNothing);
      expect(find.text('المقوت'), findsNothing);
      // ⛔ **ولا حقلَ مشترٍ ولا خصم** — `FR-M11-12` (`ت-06`).
      expect(find.text('اسم المشتري'), findsNothing);
      expect(find.text('الخصم'), findsNothing);
    });

    testWidgets('⛔ ولا رصيدَ ذمّةٍ يُعرَض في سجلّ السند',
        (WidgetTester tester) async {
      sales.emitOne(testCashSaleCard());
      await pumpCashSale(tester);

      expect(find.textContaining('الضمار'), findsNothing);
      expect(find.textContaining('الرصيد'), findsNothing);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('★★★ FR-M11-04 — التسعير إلزاميٌّ داخل السند', () {
    testWidgets('⛔⛔ سطرٌ بلا سعرٍ لا يُرسَل — ⛔ ولا يُحفَظ «غير مسعَّر»',
        (WidgetTester tester) async {
      await pumpCashSale(tester);
      await openNewForm(tester);
      await addLine(tester, quantity: '10');
      await save(tester);

      // ★ **والتحقق يرفض السند لأن سطرَه الوحيد سقط** — ⟵ **فلا إنشاء.**
      expect(admin.createCalls, 0);
    });

    testWidgets('✅ وسطرٌ بسعرٍ يُرسَل بقيمته كما كتبها المستخدم',
        (WidgetTester tester) async {
      await pumpCashSale(tester);
      await openNewForm(tester);
      await addLine(tester, quantity: '10', price: '700');
      await save(tester);

      expect(admin.createCalls, 1);
      final ValidatedCashSale sale = admin.lastSale!;
      expect(sale.lines.single.unitPrice, const Money(700));
      // ★★ **وصافي المقبوض من طبقة النطاق** — 10 × 700.
      expect(sale.netCashReceived, const Money(7000));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('★★★ FR-M11-05 · FR-M11-06 — الحد الأدنى تنبيهاً', () {
    testWidgets('★★ الحدُّ المسجَّل يُملأ اقتراحاً عند اختيار النوع',
        (WidgetTester tester) async {
      pricing.emitPrices(fixedDay, <DailyPriceCard>[
        DailyPriceCard(
          sourceId: 'SRC-001',
          itemKey: 'ITM-0002',
          itemName: 'عود',
          unit: ItemUnit.piece,
          date: fixedDay,
          distributionPrice: const Money(800),
          minCashPrice: const Money(700),
        ),
      ]);
      await pumpCashSale(tester);
      await openNewForm(tester);
      await addLine(tester, quantity: '10');

      expect(find.text('الحد الأدنى 700'), findsOneWidget);
    });

    testWidgets('⛔⛔ وسعرٌ دون الحد يُنبَّه عليه قبل الحفظ',
        (WidgetTester tester) async {
      pricing.emitPrices(fixedDay, <DailyPriceCard>[
        DailyPriceCard(
          sourceId: 'SRC-001',
          itemKey: 'ITM-0002',
          itemName: 'عود',
          unit: ItemUnit.piece,
          date: fixedDay,
          minCashPrice: const Money(700),
        ),
      ]);
      await pumpCashSale(tester);
      await openNewForm(tester);
      await addLine(tester, quantity: '10', price: '600');

      expect(find.text('أقل من الحد الأدنى'), findsOneWidget);
    });

    testWidgets('★★ ونوعٌ بلا حدٍّ مسجَّل يُعرَض «غير مسعَّر» — FR-M11-06',
        (WidgetTester tester) async {
      await pumpCashSale(tester);
      await openNewForm(tester);
      await addLine(tester, quantity: '10', price: '600');

      expect(find.text('غير مسعَّر — لا حدَّ له'), findsOneWidget);
      // ⛔ **ولا يُوسَم «دون الحد»** — ★ **فالغياب ليس تجاوزاً.**
      expect(find.text('أقل من الحد الأدنى'), findsNothing);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('★★ الملخّص الحيّ — GR-19 و design-overview §2.6', () {
    testWidgets('★★ يعرض صافي المقبوض والإجماليين منفصلين',
        (WidgetTester tester) async {
      await pumpCashSale(tester);
      await openNewForm(tester);
      await addLine(tester, quantity: '10', price: '700');

      expect(find.byType(QtmsStickyActionBar), findsOneWidget);
      expect(find.textContaining('صافي المقبوض: 7,000'), findsOneWidget);
      expect(find.textContaining('إجمالي الحبات: 10'), findsOneWidget);
      // ⛔ **وسطرٌ ثالثٌ مستقل للأوزان** — ⛔ **ولا يُجمع مع الحبّات.**
      expect(find.textContaining('إجمالي الأوزان: 0.000'), findsOneWidget);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('★★ الصلاحيات — إخفاءٌ لا حماية', () {
    testWidgets('⛔ بلا `cashSaleCreate` لا يظهر الزرُّ العائم',
        (WidgetTester tester) async {
      await pumpCashSale(tester, actorPermissions: const <Permission>{});
      expect(find.text('بيع نقدي جديد'), findsNothing);
    });

    testWidgets('⛔ وبلا `cashSaleCancel` لا يظهر زرُّ الإلغاء',
        (WidgetTester tester) async {
      sales.emitOne(testCashSaleCard());
      await pumpCashSale(
        tester,
        actorPermissions: const <Permission>{Permission.cashSaleCreate},
      );
      expect(find.byIcon(Icons.block_outlined), findsNothing);
      // ★ **والعرضُ يبقى — القراءة يحكمها النطاق وحده.**
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('★★ الإلغاء والتعديل', () {
    testWidgets('★★ ADR-0020: ويُرسَل الإلغاء بلا سبب حين لا يكتبه المستخدم',
        (WidgetTester tester) async {
      sales.emitOne(testCashSaleCard());
      await pumpCashSale(tester);

      await tester.tap(find.byIcon(Icons.block_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.text('تأكيد الإلغاء'));
      await tester.pumpAndSettle();

      expect(admin.cancelCalls, 1);
      // ⛔⛔ **ولا يُعبَّأ نيابةً عنه** — ★ **والفراغ غيابٌ لا نصٌّ فارغ.**
      expect(admin.lastCancelReason, isNull);
    });

    testWidgets('★★ والسندُ الملغى لا يُعرَض له زرُّ تعديل',
        (WidgetTester tester) async {
      sales.emitOne(testCashSaleCard(status: CashSaleStatus.cancelled));
      await pumpCashSale(tester);

      expect(find.byIcon(Icons.edit_outlined), findsNothing);
      expect(find.byIcon(Icons.block_outlined), findsNothing);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('⛔⛔★★ IQ-024 — الاستعلام مقيَّدٌ بالمصدر', () {
    testWidgets('★★ ويُستعلَم لكل مصدرٍ على حدة — ⛔ لا استعلامٌ غيرُ مقيَّد',
        (WidgetTester tester) async {
      await pumpCashSale(tester);
      expect(sales.requestedSources, contains('SRC-001'));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  _belowMinimumGuardTests();

  // ═══════════════════════════════════════════════════════════════════════
  group('★ الرفض — رسالة الكتالوج لا صمت', () {
    testWidgets('⛔ ورفضُ السحابة يُعرَض ولا يُبتلَع',
        (WidgetTester tester) async {
      admin.rejection = const InfrastructureError('ERR_PRICE_002');
      await pumpCashSale(tester);
      await openNewForm(tester);
      await addLine(tester, quantity: '10', price: '600');
      await save(tester);

      expect(admin.createCalls, 1);
      expect(find.byType(QtmsActionStatus), findsOneWidget);
    });
  });
}

// ═══════════════════════════════════════════════════════════════════════════
// ⛔⛔★★★ حارسُ الحفظ دون الحد الأدنى — FR-M11-05 · GR-34
//
// ⚠️⚠️ **وأُضيف بعد ملاحظةِ المالك على التشغيل الحيّ (2026-09-01):** ★ **الشاشة
//    كانت تُمكِّن الحفظَ ثم تنتظر رفضَ السحابة** — ⛔ **ورحلةُ شبكةٍ لتُخبِر
//    المستخدم بما تعرفه الشاشةُ سلفاً.**
// ═══════════════════════════════════════════════════════════════════════════
void _belowMinimumGuardTests() {
  group('⛔⛔★★★ الحفظ دون الحد الأدنى', () {
    setUp(() {
      pricing.emitPrices(fixedDay, <DailyPriceCard>[
        DailyPriceCard(
          sourceId: 'SRC-001',
          itemKey: 'ITM-0002',
          itemName: 'عود',
          unit: ItemUnit.piece,
          date: fixedDay,
          minCashPrice: const Money(700),
        ),
      ]);
    });

    testWidgets('⛔⛔ بلا `cashSaleBelowMinimum`: الحفظ مُعطَّل ولا طلبَ يُرسَل',
        (WidgetTester tester) async {
      await pumpCashSale(
        tester,
        actorPermissions: const <Permission>{Permission.cashSaleCreate},
      );
      await openNewForm(tester);
      await addLine(tester, quantity: '10', price: '600');

      final FilledButton button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'حفظ السند'),
      );
      expect(button.onPressed, isNull);

      await tester.tap(find.text('حفظ السند'));
      await tester.pumpAndSettle();
      // ⛔ **ولا طلبَ يُرسَل** — ★ **فلا رحلةَ شبكةٍ لرفضٍ معروفٍ سلفاً.**
      expect(admin.createCalls, 0);
    });

    testWidgets('★★ ويُعرَض نصُّ الكتالوج نفسُه الذي تردّ به السحابة',
        (WidgetTester tester) async {
      await pumpCashSale(
        tester,
        actorPermissions: const <Permission>{Permission.cashSaleCreate},
      );
      await openNewForm(tester);
      await addLine(tester, quantity: '10', price: '600');

      expect(find.byType(QtmsActionStatus), findsOneWidget);
      expect(
        find.text('❌ السعر أقل من الحد الأدنى للبيع النقدي لهذا النوع.'),
        findsOneWidget,
      );
    });

    testWidgets(
      '⛔⛔★★★ CR-007: ويُعطَّل الحفظ ولو ملك المستخدم مفتاح التجاوز',
      (WidgetTester tester) async {
        // ★ **`fullPermissions` تحوي `cashSaleBelowMinimum`.**
        await pumpCashSale(tester);
        await openNewForm(tester);
        await addLine(tester, quantity: '10', price: '600');

        final FilledButton button = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'حفظ السند'),
        );
        expect(button.onPressed, isNull);
        await tester.tap(find.text('حفظ السند'));
        await tester.pumpAndSettle();
        expect(admin.createCalls, 0);
      },
    );

    testWidgets('✅ والسعرُ عند الحد أو فوقه يُمكِّن الحفظ — «لا يقل عن»',
        (WidgetTester tester) async {
      await pumpCashSale(
        tester,
        actorPermissions: const <Permission>{Permission.cashSaleCreate},
      );
      await openNewForm(tester);
      await addLine(tester, quantity: '10', price: '700');

      await save(tester);
      expect(admin.createCalls, 1);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('★★★ WU-019 — بيعُ متبقٍّ متأخر على يومه', () {
    /// ★ **يومُ مخزونٍ أقدمُ من [fixedDay].**
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
            cashSaleDirectoryProvider.overrideWithValue(sales),
            cashSaleAdminProvider.overrideWithValue(admin),
            todayProvider.overrideWithValue(fixedDay),
          ],
          child: MaterialApp(
            locale: const Locale('ar'),
            home: Scaffold(
              body: CashSaleFormSheet(
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
    });

    testWidgets('🔒★★★ والمصدرُ مقفل', (WidgetTester tester) async {
      await pumpPinnedForm(tester);

      final DropdownButtonFormField<String> source =
          tester.widget<DropdownButtonFormField<String>>(
        find.byType(DropdownButtonFormField<String>),
      );
      expect(source.onChanged, isNull);
    });

    testWidgets(
      '⛔⛔★★★ وتاريخُ المخزون يُرسَل مع الإنشاء — E-24: «نقدي» ذلك اليوم',
      (WidgetTester tester) async {
        await pumpPinnedForm(tester);
        await tester.enterText(
          find.widgetWithText(TextField, 'الكمية').last,
          '5',
        );
        await tester.pump();
        await tester.enterText(
          find.widgetWithText(TextField, 'السعر').last,
          '700',
        );
        await tester.pump();
        await save(tester);

        expect(admin.createCalls, 1);
        expect(admin.lastCreateStockDate, pinnedDay);
      },
    );
  });
}

/// شاشة السحبيات والخرجيات — `WU-014`.
///
/// ⚠️⚠️ **وما تُثبته هذه الاختبارات وما لا تُثبته:** تُثبت أن الشاشة
/// **لا تعرض سجلاً لا يملك المستخدم مفتاحَه** (`GR-43` — **أخطر ما في
/// الوحدة**)، وأن **المصدر إلزاميٌّ قبل أي بند** (`GR-42` · `E-28`)، وأن
/// **الإجمالي النهائي = قيمة القات + المبالغ** (`AT-38`)، وأن **بند القات
/// بلا سعرٍ يُحفَظ ويُعلَن** (`FR-M22-07` · `E-27`)، وأن **حقل السعر يُعطَّل
/// بلا مفتاحه** (`FR-M22-08`)، وأن **لا حقلَ مقوتٍ في الشاشة إطلاقاً**
/// (`FR-M22-04` · `GR-44`).
/// ⛔ **ولا تُثبت أن الكتابة محميّة** — ★ **الحماية في `planOutflow`**،
/// ولها اختباراتها هناك (`functions/test/outflow_test.dart`).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qtms/capabilities/financial_outflow/application/outflow_providers.dart';
import 'package:qtms/capabilities/financial_outflow/presentation/outflow_screen.dart';
import 'package:qtms/capabilities/identity_access/application/session_providers.dart';
import 'package:qtms/capabilities/inventory/application/inventory_providers.dart';
import 'package:qtms/capabilities/master_data/application/master_data_providers.dart';
import 'package:qtms_domain/qtms_domain.dart';

import '../../../support/fake_identity.dart';
import '../../../support/fake_master_data.dart';
import '../../../support/fake_outflow.dart';

/// ★★ **اليوم مثبَّت** — ⛔ **فلا اختبارَ ينكسر بمرور منتصف الليل.**
final CalendarDay fixedDay = CalendarDay(2026, 9, 1);

late FakeOutflowDirectory directory;
late FakeOutflowAdminRepository admin;
late FakeMasterDataDirectory masterData;

const Set<Permission> fullPermissions = <Permission>{
  Permission.withdrawalCreate,
  Permission.expenseCreate,
  Permission.withdrawalQatPriceNow,
  Permission.expenseQatPriceNow,
  Permission.withdrawalBackdate,
  Permission.expenseBackdate,
};

/// ⛔⛔★★★ **مفاتيح الخرجيات وحدها** — ★ **وهي جوهر `GR-43`.**
const Set<Permission> expenseOnly = <Permission>{
  Permission.expenseCreate,
  Permission.expenseQatPriceNow,
};

Future<void> pumpOutflow(
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
  //   الافتراضي (800×600)**: ⟵ **وزرُّ إضافة البند يقع خارجها فلا يوجد
  //   في الشجرة أصلاً**، ★ **والمقاسُ الطويل يجعل الاختبار يقيس الشاشة
  //   لا كسلَ القائمة.**
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
        outflowDirectoryProvider.overrideWithValue(directory),
        outflowAdminProvider.overrideWithValue(admin),
        todayProvider.overrideWithValue(fixedDay),
      ],
      child: const MaterialApp(
        locale: Locale('ar'),
        home: OutflowScreen(),
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

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await scrollTo(tester, finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// ★★ يضغط **زرَّ الإضافة الداخلي** لا غلافَه.
///
/// ⚠️⚠️ **ولماذا لا يكفي `tap` على المفتاح:** `QtmsAddLineButton` **يلفّ
/// الزرَّ في `Align(centerStart)`** — ⟵ **فالغلافُ يملأ عرضَ القائمة
/// و«مركزُه» يقع خارج الزرِّ نفسِه**: ⛔ **فتسقط الضغطةُ في الفراغ بلا خطأ.**
Future<void> tapAddLine(WidgetTester tester, String key) async {
  final Finder wrapper = find.byKey(Key(key));
  await scrollTo(tester, wrapper);
  await tester.tap(
    find.descendant(of: wrapper, matching: find.byType(OutlinedButton)),
  );
  await tester.pumpAndSettle();
}

/// ★ يختار المصدر — ⛔ **بلا مصدرٍ لا نموذج أصلاً** (`GR-42`).
Future<void> chooseSource(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('outflow-source')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('مصدر رداع').last);
  await tester.pumpAndSettle();
}

/// ★ يختار سجلاً بعينه — **للسجلَّين معاً**.
Future<void> chooseLedger(WidgetTester tester, String label) async {
  await tester.tap(find.byKey(const Key('outflow-ledger-type')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    directory = FakeOutflowDirectory();
    admin = FakeOutflowAdminRepository();
    masterData = FakeMasterDataDirectory();
    masterData.emitSources(<SourceCard>[testSource()]);
    masterData.emitItems(<ItemCard>[
      testItem(itemId: 'ITM-0001', name: 'عوارض'),
    ]);
  });

  tearDown(() => directory.dispose());

  // ═══════════════════════════════════════════════════════════════════════
  // ⛔⛔★★★ `GR-43` — لا يرى المستخدمُ سجلاً لا يملك مفتاحَه
  // ═══════════════════════════════════════════════════════════════════════
  group('GR-43 · FR-M22-03 — الفصل بين السجلَّين', () {
    testWidgets('★★★ حاملُ مفاتيح الخرجيات وحدها لا يرى كلمة «سحبية»',
        (WidgetTester tester) async {
      await pumpOutflow(tester, actorPermissions: expenseOnly);
      expect(find.text('سحبية'), findsNothing);
      expect(find.text('خرجية'), findsWidgets);
    });

    testWidgets('★ وحاملُ المفتاحين يرى السجلَّين',
        (WidgetTester tester) async {
      await pumpOutflow(tester);
      await tester.tap(find.byKey(const Key('outflow-ledger-type')));
      await tester.pumpAndSettle();
      expect(find.text('سحبية'), findsWidgets);
      expect(find.text('خرجية'), findsWidgets);
    });

    testWidgets('⛔ ومن لا يملك أيّاً منهما لا يرى نموذجاً أصلاً',
        (WidgetTester tester) async {
      await pumpOutflow(
        tester,
        actorPermissions: const <Permission>{Permission.sackView},
      );
      expect(find.text('لا صلاحية'), findsOneWidget);
      expect(find.byKey(const Key('outflow-source')), findsNothing);
    });

    testWidgets('★★★ والسجلُّ المُرسَل يطابق المختار — ⛔ ولا يُخلط',
        (WidgetTester tester) async {
      await pumpOutflow(tester, actorPermissions: expenseOnly);
      await chooseSource(tester);
      await tapAddLine(tester, 'outflow-add-cash');
      await tester.enterText(
        find.byKey(const Key('outflow-cash-amount-0')),
        '5000',
      );
      await tester.pumpAndSettle();
      await tapVisible(tester, find.byKey(const Key('outflow-save')));

      expect(admin.created, hasLength(1));
      expect(admin.created.single.ledgerType, OutflowLedgerType.expense);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // ⛔⛔★★★ `GR-42` · `E-28` — المصدر إلزاميٌّ قبل أي بند
  // ═══════════════════════════════════════════════════════════════════════
  group('GR-42 · E-28 — المصدر إلزامي', () {
    testWidgets('⛔ لا نموذجَ قبل اختيار المصدر — ★ والنصُّ يقول العلّة',
        (WidgetTester tester) async {
      await pumpOutflow(tester);
      expect(find.text('اختر المصدر'), findsOneWidget);
      expect(
        find.textContaining('حتى سحبيات المالك الشخصية'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('outflow-save')), findsNothing);
    });

    testWidgets('★ وبعد اختياره يظهر النموذج', (WidgetTester tester) async {
      await pumpOutflow(tester);
      await chooseSource(tester);
      expect(find.byKey(const Key('outflow-save')), findsOneWidget);
    });

    testWidgets('⛔⛔ ولا خيار «كل المصادر» في القائمة',
        (WidgetTester tester) async {
      await pumpOutflow(tester);
      await tester.tap(find.byKey(const Key('outflow-source')));
      await tester.pumpAndSettle();
      expect(find.text('كل المصادر'), findsNothing);
    });

    testWidgets('★ والمصدرُ المُرسَل هو المختار', (WidgetTester tester) async {
      await pumpOutflow(tester);
      await chooseSource(tester);
      await tapAddLine(tester, 'outflow-add-cash');
      await tester.enterText(
        find.byKey(const Key('outflow-cash-amount-0')),
        '100',
      );
      await tester.pumpAndSettle();
      await tapVisible(tester, find.byKey(const Key('outflow-save')));
      expect(admin.created.single.sourceId, 'SRC-001');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // ★★★ `GR-42` · `AT-38` — الإجمالي النهائي
  // ═══════════════════════════════════════════════════════════════════════
  group('AT-38 — الإجمالي النهائي = قيمة القات + المبالغ', () {
    testWidgets('★★★ سيناريو AT-38 حرفياً في الشريط الملتصق',
        (WidgetTester tester) async {
      await pumpOutflow(tester);
      await chooseSource(tester);

      await tapAddLine(tester, 'outflow-add-qat');
      await tapVisible(tester, find.text('النوع').last);
      await tapVisible(tester, find.text('عوارض').last);
      await tester.enterText(find.byKey(const Key('outflow-qty-0')), '5');
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('outflow-price-0')), '1500');
      await tester.pumpAndSettle();

      await tapAddLine(tester, 'outflow-add-cash');
      await tester.enterText(
        find.byKey(const Key('outflow-cash-amount-0')),
        '20000',
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('الإجمالي النهائي: 27500'), findsOneWidget);
      expect(find.textContaining('قيمة القات: 7500'), findsOneWidget);
      expect(find.textContaining('المبالغ: 20000'), findsOneWidget);
    });

    testWidgets('⛔⛔★★★ وتذكيرٌ صريح أنه لا يمسّ حسابات المقاوته',
        (WidgetTester tester) async {
      await pumpOutflow(tester);
      await chooseSource(tester);
      expect(find.text('لا يمسّ حسابات المقاوته'), findsOneWidget);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // ★★★ `FR-M22-07` · `FR-M22-08` · `E-27` — السعر اختياريٌّ ومفتاحُه
  // ═══════════════════════════════════════════════════════════════════════
  group('FR-M22-07 · FR-M22-08 — السعر', () {
    testWidgets('★★★ بندُ قاتٍ بلا سعرٍ يُحفَظ ويُعلَن نقصُه',
        (WidgetTester tester) async {
      await pumpOutflow(tester);
      await chooseSource(tester);
      await tapAddLine(tester, 'outflow-add-qat');
      await tapVisible(tester, find.text('النوع').last);
      await tapVisible(tester, find.text('عوارض').last);
      await tester.enterText(find.byKey(const Key('outflow-qty-0')), '5');
      await tester.pumpAndSettle();

      expect(find.textContaining('بنود بلا سعر: 1'), findsOneWidget);
      expect(
        find.textContaining('تدخل مركز الإدخالات المعلّقة'),
        findsOneWidget,
      );

      await tapVisible(tester, find.byKey(const Key('outflow-save')));
      expect(admin.created.single.qatLines.single.unitPrice, isNull);
    });

    testWidgets('⛔⛔★★★ وحقلُ السعر مُعطَّلٌ بلا مفتاحه — ولا يمنع الحفظ',
        (WidgetTester tester) async {
      await pumpOutflow(
        tester,
        actorPermissions: const <Permission>{Permission.withdrawalCreate},
      );
      await chooseSource(tester);
      await tapAddLine(tester, 'outflow-add-qat');

      final TextField price = tester.widget<TextField>(
        find.byKey(const Key('outflow-price-0')),
      );
      expect(price.enabled, isFalse);
      expect(
        find.textContaining('ليست لديك صلاحية التسعير الآن'),
        findsOneWidget,
      );
      // ★ **والحفظُ باقٍ متاحاً** — `FR-M22-07`.
      expect(find.byKey(const Key('outflow-save')), findsOneWidget);
    });

    testWidgets('★ وبمفتاحه يُفعَّل الحقل', (WidgetTester tester) async {
      await pumpOutflow(tester);
      await chooseSource(tester);
      await tapAddLine(tester, 'outflow-add-qat');
      final TextField price = tester.widget<TextField>(
        find.byKey(const Key('outflow-price-0')),
      );
      expect(price.enabled, isTrue);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // ⛔ `FR-M22-19` — الفئات مقيَّدةٌ بسجلِّها
  // ═══════════════════════════════════════════════════════════════════════
  group('FR-M22-19 — الفئات', () {
    testWidgets('★ فئاتُ الخرجية وحدها في سجل الخرجيات',
        (WidgetTester tester) async {
      await pumpOutflow(tester, actorPermissions: expenseOnly);
      await chooseSource(tester);
      await tester.tap(find.byKey(const Key('outflow-category')));
      await tester.pumpAndSettle();
      expect(find.text('شُقى الشُقّات'), findsWidgets);
      expect(find.text('قات للشُقّات'), findsWidgets);
      // ⛔ **ولا فئةَ سحبيةٍ هنا.**
      expect(find.text('مبلغ مالي'), findsNothing);
    });

    testWidgets('★ والفئةُ المُرسَلة من سجلِّها', (WidgetTester tester) async {
      await pumpOutflow(tester, actorPermissions: expenseOnly);
      await chooseSource(tester);
      await tapAddLine(tester, 'outflow-add-cash');
      await tester.enterText(
        find.byKey(const Key('outflow-cash-amount-0')),
        '300',
      );
      await tester.pumpAndSettle();
      await tapVisible(tester, find.byKey(const Key('outflow-save')));
      expect(
        admin.created.single.category.ledgerType,
        OutflowLedgerType.expense,
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // ⛔⛔★★★ `GR-44` — لا حقلَ مقوتٍ في الشاشة إطلاقاً
  // ═══════════════════════════════════════════════════════════════════════
  group('GR-44 — لا مساس بالمقاوته', () {
    testWidgets('⛔⛔★★★ ولا كلمةَ «مقوت» في الشاشة كلِّها',
        (WidgetTester tester) async {
      await pumpOutflow(tester);
      await chooseSource(tester);
      expect(find.textContaining('مقوت'), findsNothing);
      expect(find.textContaining('ضمار'), findsNothing);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // ★★ الحفظ والرفض
  // ═══════════════════════════════════════════════════════════════════════
  group('الحفظ', () {
    testWidgets('⛔ سندٌ بلا بندٍ يُرفَض في الشاشة — ★ ولا يُرسَل',
        (WidgetTester tester) async {
      await pumpOutflow(tester);
      await chooseSource(tester);
      await tapVisible(tester, find.byKey(const Key('outflow-save')));
      expect(find.textContaining('أضف بنداً واحداً على الأقل'), findsOneWidget);
      expect(admin.created, isEmpty);
    });

    testWidgets('⛔⛔★★★ ورفضُ السحابة يُعرَض ولا يُبتلَع',
        (WidgetTester tester) async {
      admin.nextResult =
          const Failure<String>(InfrastructureError('ERR_OUT_001'));
      await pumpOutflow(tester);
      await chooseSource(tester);
      await tapAddLine(tester, 'outflow-add-cash');
      await tester.enterText(
        find.byKey(const Key('outflow-cash-amount-0')),
        '900',
      );
      await tester.pumpAndSettle();
      await tapVisible(tester, find.byKey(const Key('outflow-save')));

      // ★ **والمُدخَل باقٍ** — ⛔ **فلا يُقرأ الرفضُ نجاحاً.**
      expect(
        tester
            .widget<TextField>(
              find.byKey(const Key('outflow-cash-amount-0')),
            )
            .controller
            ?.text,
        '900',
      );
      expect(find.textContaining('✅'), findsNothing);
    });

    testWidgets('★ والنجاحُ يُعرَض برقم السند ويُفرِغ البنود',
        (WidgetTester tester) async {
      await pumpOutflow(tester);
      await chooseSource(tester);
      await tapAddLine(tester, 'outflow-add-cash');
      await tester.enterText(
        find.byKey(const Key('outflow-cash-amount-0')),
        '900',
      );
      await tester.pumpAndSettle();
      await tapVisible(tester, find.byKey(const Key('outflow-save')));

      expect(find.textContaining('WDR-20260901-0001'), findsOneWidget);
      expect(find.byKey(const Key('outflow-cash-amount-0')), findsNothing);
    });

    testWidgets('★ والبيانُ يُرسَل كما كتبه المستخدم',
        (WidgetTester tester) async {
      await pumpOutflow(tester);
      await chooseSource(tester);
      await tapAddLine(tester, 'outflow-add-cash');
      await tester.enterText(
        find.byKey(const Key('outflow-cash-amount-0')),
        '900',
      );
      await tester.pumpAndSettle();
      await scrollTo(tester, find.byKey(const Key('outflow-notes')));
      await tester.enterText(
        find.byKey(const Key('outflow-notes')),
        'مصروف يوم الخميس',
      );
      await tester.pumpAndSettle();
      await tapVisible(tester, find.byKey(const Key('outflow-save')));
      expect(admin.created.single.notes, 'مصروف يوم الخميس');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // ★ `FR-M22-09` — التاريخ
  // ═══════════════════════════════════════════════════════════════════════
  group('FR-M22-09 — التاريخ', () {
    testWidgets('★ تاريخُ السند اليومُ افتراضاً ويُرسَل كذلك',
        (WidgetTester tester) async {
      await pumpOutflow(tester);
      await chooseSource(tester);
      expect(find.textContaining('تاريخ السند'), findsOneWidget);
      await tapAddLine(tester, 'outflow-add-cash');
      await tester.enterText(
        find.byKey(const Key('outflow-cash-amount-0')),
        '100',
      );
      await tester.pumpAndSettle();
      await tapVisible(tester, find.byKey(const Key('outflow-save')));
      expect(admin.created.single.date, fixedDay);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // ★★ `AM-008` · `AM-009` — الشريط الموحّد
  // ═══════════════════════════════════════════════════════════════════════
  group('AM-008 · AM-009 — الشريط العلوي', () {
    testWidgets('★ اسمُ الشاشة في الشريط — ⛔ ولا زرَّ رجوعٍ ولا خروج',
        (WidgetTester tester) async {
      await pumpOutflow(tester);
      expect(find.text('السحبيات والخرجيات'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsNothing);
      expect(find.byIcon(Icons.logout), findsNothing);
    });
  });
}

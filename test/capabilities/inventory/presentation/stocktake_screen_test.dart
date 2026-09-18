/// شاشة الجرد — `WU-022` (`FR-M16`).
///
/// ⚠️⚠️ **وما تُثبته هذه الاختبارات وما لا تُثبته:** تُثبت أن الشاشة
/// **بلا حقلٍ ماليٍّ واحد** (`BR-M16-03`)، وأن **الرصيد الدفتري يُعرَض ولا
/// يُحرَّر** (`FR-M16-01` 🔒)، وأن **المرحلتين تتبعان حالة المستند**
/// (`FR-M16-03` · `FR-M16-09`)، وأن **مفتاح جرد يومٍ سابق يُخفي الحقل ولا
/// يُعطِّله** (`FR-M16-08`)، وأن **السبب اختياريٌّ ولا يُعبَّأ نيابةً عن
/// المستخدم** (`ADR-0020`)، وأن **من لا يملك `stocktakeWrite` لا يرى
/// النموذج**. ⛔ **ولا تُثبت أن الكتابة محميّة** — ★ **الحماية في
/// `planStocktake`**، ولها اختباراتها هناك (`functions/test/stocktake_test.dart`).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qtms/capabilities/identity_access/application/session_providers.dart';
import 'package:qtms/core/design/design_tokens.dart';
import 'package:qtms/core/ui/destructive_sheet.dart';
import 'package:qtms/core/ui/sticky_action_bar.dart';
import 'package:qtms/core/messages/error_messages.dart';
import 'package:qtms/capabilities/inventory/application/inventory_providers.dart';
import 'package:qtms/capabilities/inventory/application/stocktake_providers.dart';
import 'package:qtms/capabilities/inventory/presentation/stocktake_screen.dart';
import 'package:qtms/capabilities/master_data/application/master_data_providers.dart';
import 'package:qtms_domain/qtms_domain.dart';

import '../../../support/fake_identity.dart';
import '../../../support/fake_inventory.dart';
import '../../../support/fake_master_data.dart';
import '../../../support/fake_stocktake.dart';

/// ★★ **اليوم مثبَّت** — ⛔ **فلا اختبارَ ينكسر بمرور منتصف الليل.**
final CalendarDay fixedDay = CalendarDay(2026, 9, 5);

late FakeStocktakeDirectory directory;
late FakeStocktakeAdminRepository admin;
late FakeMasterDataDirectory masterData;
late FakeInventoryDirectory inventory;

const Set<Permission> fullPermissions = <Permission>{
  Permission.stocktakeWrite,
  Permission.stocktakeApprove,
  Permission.stocktakeCancel,
  Permission.stocktakePriorDay,
};

Future<void> pumpStocktake(
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
        stocktakeDirectoryProvider.overrideWithValue(directory),
        stocktakeAdminProvider.overrideWithValue(admin),
        todayProvider.overrideWithValue(fixedDay),
      ],
      child: const MaterialApp(
        locale: Locale('ar'),
        home: StocktakeScreen(),
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
  final Finder wrapper = find.byKey(const Key('stocktake-add-line'));
  await scrollTo(tester, wrapper);
  await tester.tap(
    find.descendant(of: wrapper, matching: find.byType(OutlinedButton)),
  );
  await tester.pumpAndSettle();
}

Future<void> chooseSource(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('stocktake-source')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('مصدر رداع').last);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    directory = FakeStocktakeDirectory();
    admin = FakeStocktakeAdminRepository();
    masterData = FakeMasterDataDirectory();
    masterData.emitSources(<SourceCard>[testSource()]);
    masterData.emitItems(<ItemCard>[
      testItem(itemId: 'ITM-0001', name: 'عوارض'),
    ]);
    inventory = FakeInventoryDirectory();
    inventory.emitStock(<ItemDailyBalanceCard>[
      testBalance(itemKey: 'ITM-0001', itemName: 'عوارض'),
    ]);
    directory.emit(const <StocktakeCard>[]);
  });

  tearDown(() {
    directory.dispose();
    inventory.dispose();
  });

  group('★★★ المصدر إلزاميٌّ قبل أي بند — BR-M16-04', () {
    testWidgets('⛔ وبلا مصدرٍ لا نموذج', (WidgetTester tester) async {
      await pumpStocktake(tester);

      expect(find.text('اختر المصدر'), findsOneWidget);
      expect(find.byKey(const Key('stocktake-add-line')), findsNothing);
    });

    testWidgets('✅ واختيارُه يفتح نموذج البدء', (WidgetTester tester) async {
      await pumpStocktake(tester);
      await chooseSource(tester);

      expect(find.byKey(const Key('stocktake-add-line')), findsOneWidget);
      expect(find.byKey(const Key('stocktake-start')), findsOneWidget);
      // ⛔⛔★★★ **والاستعلامُ يُقيّد المصدر** — `IQ-024`.
      expect(directory.requested, contains('SRC-001'));
    });
  });

  group('★★★ الصلاحية تُخفي لا تُعطِّل — RISK-02', () {
    testWidgets('⛔ وبلا `stocktakeWrite` لا يُعرَض النموذج',
        (WidgetTester tester) async {
      await pumpStocktake(tester, actorPermissions: const <Permission>{});

      expect(find.text('لا صلاحية'), findsOneWidget);
      expect(find.byKey(const Key('stocktake-source')), findsNothing);
    });

    testWidgets('⛔⛔★★★ وبلا `stocktakePriorDay` لا حقلَ تاريخٍ أصلاً',
        (WidgetTester tester) async {
      await pumpStocktake(
        tester,
        actorPermissions: const <Permission>{Permission.stocktakeWrite},
      );
      await chooseSource(tester);

      // ★ **الحقلُ غائبٌ لا معطَّل** — `ui-guidelines.md` §2.
      expect(find.byKey(const Key('stocktake-date')), findsNothing);
      // ★ **والتاريخُ معروضٌ نصّاً مع ذلك** — ⟵ **فكل شاشةٍ تُصرِّح بتاريخها.**
      expect(find.textContaining('تاريخ المخزون المجرود'), findsOneWidget);
    });

    testWidgets('✅★★ ومعه يظهر منتقي اليوم السابق',
        (WidgetTester tester) async {
      await pumpStocktake(tester);
      await chooseSource(tester);

      expect(find.byKey(const Key('stocktake-date')), findsOneWidget);
    });
  });

  group('★★★ FR-M16-03 — التجميد معلَنٌ قبل البدء', () {
    testWidgets('★★ وتنبيهُ التجميد معروض', (WidgetTester tester) async {
      await pumpStocktake(tester);
      await chooseSource(tester);

      expect(find.textContaining('يُجمِّد الرصيد الدفتري'), findsWidgets);
    });

    testWidgets('⛔⛔★★★ ولا حقلَ ماليٍّ في نموذج البدء',
        (WidgetTester tester) async {
      await pumpStocktake(tester);
      await chooseSource(tester);
      await tapAddLine(tester);

      expect(find.textContaining('ريال'), findsNothing);
      expect(find.text('سعر الوحدة'), findsNothing);
    });
  });

  group('★★★ البدء — ما يصل المستودع', () {
    testWidgets('✅★★ نوعٌ مختارٌ يُرسَل بلا تاريخٍ مثبَّت ولا رصيدٍ دفتري',
        (WidgetTester tester) async {
      await pumpStocktake(tester);
      await chooseSource(tester);
      await tapAddLine(tester);

      await tester.tap(find.byType(DropdownMenu<String>).last);
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('عوارض').last);
      await tester.pumpAndSettle();

      await scrollTo(tester, find.byKey(const Key('stocktake-start')));
      await tester.tap(find.byKey(const Key('stocktake-start')));
      await tester.pumpAndSettle();

      expect(admin.started, hasLength(1));
      final StartedStocktake sent = admin.started.single;
      expect(sent.sourceId, 'SRC-001');
      expect(sent.itemIds, <String>['ITM-0001']);
      // ⛔⛔★★★ **ولا تاريخَ يُرسَل ما لم يُثبَّت** — `GR-54` · `E-41`.
      expect(sent.stockDate, isNull);
      // ★★ **والسببُ غائبٌ لا نصٌّ فارغ** — `ADR-0020`.
      expect(sent.reason, anyOf(isNull, ''));
    });

    testWidgets('⛔ وبلا نوعٍ لا يُرسَل شيء', (WidgetTester tester) async {
      await pumpStocktake(tester);
      await chooseSource(tester);

      await scrollTo(tester, find.byKey(const Key('stocktake-start')));
      await tester.tap(find.byKey(const Key('stocktake-start')));
      await tester.pumpAndSettle();

      expect(admin.started, isEmpty);
      expect(find.textContaining('اختر نوعاً واحداً'), findsOneWidget);
    });
  });

  group('★★★ FR-M16-06 — المسوّدةُ القائمة تُقدَّم على بدءٍ جديد', () {
    testWidgets('★★ ومستندٌ مفتوحٌ يفتح نموذج العدّ لا نموذج البدء',
        (WidgetTester tester) async {
      directory.emit(<StocktakeCard>[testStocktake()]);
      await pumpStocktake(tester);
      await chooseSource(tester);

      expect(find.byKey(const Key('stocktake-start')), findsNothing);
      expect(find.byKey(const Key('stocktake-approve')), findsOneWidget);
      expect(find.textContaining('جردٌ مفتوح STK-20260905-001'), findsOneWidget);
    });

    testWidgets('★ ومستندٌ معتمدٌ لا يمنع بدءَ جردٍ جديد',
        (WidgetTester tester) async {
      directory.emit(<StocktakeCard>[
        testStocktake(status: StocktakeStatus.approved),
      ]);
      await pumpStocktake(tester);
      await chooseSource(tester);

      expect(find.byKey(const Key('stocktake-start')), findsOneWidget);
    });
  });

  group('★★★ FR-M16-01 — الرصيدُ الدفتري يُعرَض ولا يُحرَّر', () {
    testWidgets('🔒★★★ ولا حقلَ إدخالٍ للرصيد الدفتري إطلاقاً',
        (WidgetTester tester) async {
      directory.emit(<StocktakeCard>[testStocktake()]);
      await pumpStocktake(tester);
      await chooseSource(tester);

      expect(
        find.textContaining('الرصيد الدفتري المُجمَّد: 80'),
        findsOneWidget,
      );
      // ⛔⛔★★★ **والحقلُ الوحيد هو العدُّ الفعلي** — ⟵ **ولا حقلَ رصيدٍ
      //    ولا حقلَ فرقٍ يُدخَل**: ★ **كلاهما محسوب.**
      expect(find.byKey(const Key('stocktake-count-ITM-0001')), findsOneWidget);
      expect(find.byKey(const Key('stocktake-book-ITM-0001')), findsNothing);
      expect(find.byKey(const Key('stocktake-difference-ITM-0001')), findsNothing);
    });

    testWidgets(
        '⛔⛔★★★ [`DEBT-86`] — والاسمُ المعروض هو المفتاح المركّب لا المجرَّد',
        (WidgetTester tester) async {
      // ⚠️ **ارتدادٌ رُصد على المحاكي 2026-09-05** — ★ **كان يُعرَض «عتود»
      //   لسطرَي جونيتين مختلفتين بلا تمييز**: ⟵ **وهو الخيارُ 2 الذي رفضه
      //   `ADR-0007` نصّاً.**
      directory.emit(<StocktakeCard>[
        testStocktake(
          lines: <StocktakeCardLine>[
            const StocktakeCardLine(
              itemKey: 'عتود - جونية رقم 1',
              itemName: 'عتود',
              bookBalance: PieceQuantity(PieceCount(85)),
            ),
          ],
        ),
      ]);
      await pumpStocktake(tester);
      await chooseSource(tester);

      expect(find.text('عتود - جونية رقم 1'), findsOneWidget);
      expect(find.text('عتود'), findsNothing);
    });

    testWidgets('★★★ والفرقُ يُعرَض محسوباً باتجاهه',
        (WidgetTester tester) async {
      directory.emit(<StocktakeCard>[testStocktake()]);
      await pumpStocktake(tester);
      await chooseSource(tester);

      await tester.enterText(
        find.byKey(const Key('stocktake-count-ITM-0001')),
        '78',
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('الفرق: نقص'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('stocktake-count-ITM-0001')),
        '83',
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('الفرق: زيادة'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('stocktake-count-ITM-0001')),
        '80',
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('الفرق: مطابق'), findsOneWidget);
    });
  });

  group('★★★ الاعتماد — ما يصل المستودع', () {
    testWidgets('✅★★ العدُّ الفعلي وحدَه يُرسَل — ⛔ بلا رصيدٍ ولا فرق',
        (WidgetTester tester) async {
      directory.emit(<StocktakeCard>[testStocktake()]);
      await pumpStocktake(tester);
      await chooseSource(tester);

      await tester.enterText(
        find.byKey(const Key('stocktake-count-ITM-0001')),
        '78',
      );
      await tester.pumpAndSettle();
      await scrollTo(tester, find.byKey(const Key('stocktake-approve')));
      await tester.tap(find.byKey(const Key('stocktake-approve')));
      await tester.pumpAndSettle();

      expect(admin.approved, hasLength(1));
      final ApprovedStocktake sent = admin.approved.single;
      expect(sent.documentNumber, 'STK-20260905-001');
      expect(sent.counts.single.itemId, 'ITM-0001');
      expect(
        sent.counts.single.actualCount,
        const PieceQuantity(PieceCount(78)),
      );
      // ★★ **وسببُ الفرق غائبٌ لأن المستخدم لم يكتبه** — `ADR-0020`.
      expect(sent.counts.single.differenceReason, anyOf(isNull, ''));
    });

    testWidgets('⛔ وعدٌّ ناقصٌ لا يُرسَل', (WidgetTester tester) async {
      directory.emit(<StocktakeCard>[testStocktake()]);
      await pumpStocktake(tester);
      await chooseSource(tester);

      await scrollTo(tester, find.byKey(const Key('stocktake-approve')));
      await tester.tap(find.byKey(const Key('stocktake-approve')));
      await tester.pumpAndSettle();

      expect(admin.approved, isEmpty);
      // ★★★ **والرسالةُ تُسمّي السطرَ الناقص باسمه المعروض** — `AM-021` ⑥:
      //    ⛔ **لا «لكل نوع» مجرَّدة** (`ui-guidelines.md` §6).
      expect(find.text('أدخل العدّ الفعلي لـ«عوارض».'), findsOneWidget);
      // ★★ **وحدٌّ لونيٌّ على الحقل الناقص مع تلميحٍ نصّي** — ⛔ **ولا لونَ
      //    وحده ينقل المعنى** (§8 المحظور الثاني عشر).
      final TextField field = tester.widget<TextField>(
        find.byKey(const Key('stocktake-count-ITM-0001')),
      );
      expect(field.decoration!.helperText, stocktakeMissingCountHint);
      expect(
        field.decoration!.enabledBorder,
        isA<OutlineInputBorder>().having(
          (OutlineInputBorder border) => border.borderSide.color,
          'لونُ الحدّ',
          SemanticTriads.danger.border,
        ),
      );
    });

    testWidgets(
        '⛔⛔★★★ AM-021 ⑥: وتُسمّى السطورُ الناقصة الأولُ منها ويُعَدّ الباقي',
        (WidgetTester tester) async {
      directory.emit(<StocktakeCard>[
        testStocktake(
          lines: const <StocktakeCardLine>[
            StocktakeCardLine(
              itemKey: 'ITM-0001',
              itemName: 'عوارض',
              bookBalance: PieceQuantity(PieceCount(80)),
            ),
            StocktakeCardLine(
              itemKey: 'ITM-0002',
              itemName: 'عتود',
              bookBalance: PieceQuantity(PieceCount(40)),
            ),
            StocktakeCardLine(
              itemKey: 'ITM-0003',
              itemName: 'سلة',
              bookBalance: PieceQuantity(PieceCount(10)),
            ),
          ],
        ),
      ]);
      await pumpStocktake(tester);
      await chooseSource(tester);

      // ★ **سطرٌ واحدٌ يُعَدّ والاثنان الباقيان ناقصان.**
      await tester.enterText(
        find.byKey(const Key('stocktake-count-ITM-0001')),
        '80',
      );
      await tester.pumpAndSettle();
      await scrollTo(tester, find.byKey(const Key('stocktake-approve')));
      await tester.tap(find.byKey(const Key('stocktake-approve')));
      await tester.pumpAndSettle();

      expect(admin.approved, isEmpty);
      expect(
        find.text('أدخل العدّ الفعلي لـ«عتود» و1 سطرٍ آخر بلا عدّ.'),
        findsOneWidget,
      );
      // ⛔ **والسطرُ المكتملُ بلا حدٍّ أحمر** — ★ **فالحدُّ إشارةٌ لا زينة.**
      final TextField done = tester.widget<TextField>(
        find.byKey(const Key('stocktake-count-ITM-0001')),
      );
      expect(done.decoration!.enabledBorder, isNull);
      expect(done.decoration!.helperText, isNull);
    });

    testWidgets(
        '⛔⛔★★★ AM-021 ⑥: والحدُّ الأحمر يُطفأ بعد إصلاح السطر واعتمادٍ ناجح',
        (WidgetTester tester) async {
      directory.emit(<StocktakeCard>[testStocktake()]);
      await pumpStocktake(tester);
      await chooseSource(tester);

      await scrollTo(tester, find.byKey(const Key('stocktake-approve')));
      await tester.tap(find.byKey(const Key('stocktake-approve')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('stocktake-count-ITM-0001')))
            .decoration!
            .helperText,
        stocktakeMissingCountHint,
      );

      await tester.enterText(
        find.byKey(const Key('stocktake-count-ITM-0001')),
        '78',
      );
      await tester.pumpAndSettle();
      await scrollTo(tester, find.byKey(const Key('stocktake-approve')));
      await tester.tap(find.byKey(const Key('stocktake-approve')));
      await tester.pumpAndSettle();

      expect(admin.approved, isNotEmpty);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('stocktake-count-ITM-0001')))
            .decoration!
            .helperText,
        isNull,
      );
    });

    testWidgets('⛔⛔★★★ ومن لا يملك `stocktakeApprove` لا يعتمد',
        (WidgetTester tester) async {
      directory.emit(<StocktakeCard>[testStocktake()]);
      await pumpStocktake(
        tester,
        actorPermissions: const <Permission>{Permission.stocktakeWrite},
      );
      await chooseSource(tester);

      expect(find.text('الاعتماد يحتاج صلاحية'), findsOneWidget);
      final FilledButton button = tester.widget<FilledButton>(
        find.byKey(const Key('stocktake-approve')),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets(
        '⛔⛔★★ والإلغاءُ يُسمّى باسمه أثناء تنفيذه — ⛔ لا «جارٍ الاعتماد»',
        (WidgetTester tester) async {
      // ⚠️ **ارتدادٌ رُصد على المحاكي 2026-09-05** — ★ **عَلَمٌ واحدٌ للحفظ
      //   كان يعرض «جارٍ الاعتماد…» أثناء الإلغاء**: ⛔ **فيقرأ المستخدمُ أن
      //   مستنداً يُعتمَد وهو يُلغى** (`ui-guidelines.md` §6).
      final Completer<Outcome<void>> pending = Completer<Outcome<void>>();
      admin.nextCancel = pending.future;
      directory.emit(<StocktakeCard>[testStocktake()]);
      await pumpStocktake(tester);
      await chooseSource(tester);

      await scrollTo(tester, find.byKey(const Key('stocktake-cancel')));
      await tester.tap(find.byKey(const Key('stocktake-cancel')));
      await tester.pumpAndSettle();
      // ★★★ **والتنفيذُ خلف ورقة التأكيد** — `AM-021` ⑤.
      await tester.tap(find.text('تأكيد إلغاء الجرد'));
      await tester.pump();

      expect(find.text('جارٍ الإلغاء…'), findsOneWidget);
      expect(find.text('جارٍ الاعتماد…'), findsNothing);

      pending.complete(const Success<void>(null));
      await tester.pumpAndSettle();
    });

    testWidgets('★★ والإلغاءُ ظاهرٌ لمن يملك مفتاحه — ⛔ ولا زرَّ حذف',
        (WidgetTester tester) async {
      directory.emit(<StocktakeCard>[testStocktake()]);
      await pumpStocktake(tester);
      await chooseSource(tester);

      await scrollTo(tester, find.byKey(const Key('stocktake-cancel')));
      await tester.tap(find.byKey(const Key('stocktake-cancel')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('تأكيد إلغاء الجرد'));
      await tester.pumpAndSettle();

      expect(admin.cancelled, <String>['STK-20260905-001']);
    });
  });

  group('⛔⛔★★★ AM-021 ⑤ — إلغاءُ الجرد بالورقة المدمّرة الموحّدة', () {
    testWidgets('★★★ ولا تنفيذَ بضغطةٍ واحدة — الورقةُ تُفتَح ولا يُلغى شيء',
        (WidgetTester tester) async {
      // ⚠️⚠️ **وكان `TextButton` أحمرَ ينفّذ مباشرةً** — ⛔ **بلا تأكيدٍ ولا
      //   مخرَج**: ⟵ **بينما إلغاءُ الوارد والجونية والتوزيعة والبيع النقدي
      //   كلُّها بالورقة** (`ADR-0021` `P6`).
      directory.emit(<StocktakeCard>[testStocktake()]);
      await pumpStocktake(tester);
      await chooseSource(tester);

      await scrollTo(tester, find.byKey(const Key('stocktake-cancel')));
      await tester.tap(find.byKey(const Key('stocktake-cancel')));
      await tester.pumpAndSettle();

      expect(admin.cancelled, isEmpty);
      // ★ **عنوانٌ يسمّي المستند برقمه** — ⛔ **لا «هل أنت متأكد؟»** (§6).
      //   ★ **ويُقاس داخل الورقة وحدَها** — ⟵ **فالزرُّ تحتها يحمل النصَّ
      //   نفسَه عمداً**: ⛔ **ووعدُ الزرّ وعنوانُ الورقة لا يفترقان.**
      expect(
        find.descendant(
          of: find.byType(QtmsDestructiveSheet),
          matching: find.text('إلغاء الجرد STK-20260905-001'),
        ),
        findsOneWidget,
      );
      // ★ **وجملةُ أثرٍ صريحة.**
      expect(find.textContaining('الإلغاء يَسِم مسوّدة الجرد'), findsOneWidget);
      // ⛔⛔★★★ **وزرُّ تراجعٍ إلزامي** — `ADR-0021` القيد 4.
      expect(find.text('تراجع'), findsOneWidget);
      // ★★ **وسببُ الإلغاء اختياريٌّ ولا يُعطِّل الزرّ** (`ADR-0020`).
      expect(find.text('سبب الإلغاء (اختياري)'), findsOneWidget);
      final FilledButton confirm = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('تأكيد إلغاء الجرد'),
          matching: find.byType(FilledButton),
        ),
      );
      expect(confirm.onPressed, isNotNull);
    });

    testWidgets('★★★ و«تراجع» يُغلق الورقة بلا إلغاءٍ واحد',
        (WidgetTester tester) async {
      directory.emit(<StocktakeCard>[testStocktake()]);
      await pumpStocktake(tester);
      await chooseSource(tester);

      await scrollTo(tester, find.byKey(const Key('stocktake-cancel')));
      await tester.tap(find.byKey(const Key('stocktake-cancel')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('تراجع'));
      await tester.pumpAndSettle();

      expect(admin.cancelled, isEmpty);
      expect(find.text('تأكيد إلغاء الجرد'), findsNothing);
    });

    testWidgets(
        '⛔⛔★★★ وسببُ الإلغاء من الورقة لا من حقل ملاحظة الاعتماد',
        (WidgetTester tester) async {
      // ⛔⛔★★★ **وكان الحقلُ الواحدُ يُرسَل للعمليتين معاً** — ⟵ **فمن كتب
      //   ملاحظةً على العدّ ثم ألغى أُرسلت ملاحظتُه سبباً للإلغاء**:
      //   ★ **وهو ما تمنعه القاعدةُ الباقية من [`ADR-0020`].**
      directory.emit(<StocktakeCard>[testStocktake()]);
      await pumpStocktake(tester);
      await chooseSource(tester);

      await tester.enterText(
        find.byKey(const Key('stocktake-approve-reason')),
        'ملاحظةٌ على العدّ لا على الإلغاء',
      );
      await tester.pumpAndSettle();

      await scrollTo(tester, find.byKey(const Key('stocktake-cancel')));
      await tester.tap(find.byKey(const Key('stocktake-cancel')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('تأكيد إلغاء الجرد'));
      await tester.pumpAndSettle();

      expect(admin.cancelled, <String>['STK-20260905-001']);
      // ⛔ **والفراغُ يُقرأ غياباً لا نصّاً** (`blankToNull`).
      expect(admin.cancelReasons.single, isNull);
    });

    testWidgets('★★★ والرفضُ يُعرَض داخل الورقة وهي مفتوحة — ⛔ ولا يُبتلَع',
        (WidgetTester tester) async {
      admin.nextCancel = Future<Outcome<void>>.value(
        const Failure<void>(ValidationError('BR-M16-XX')),
      );
      directory.emit(<StocktakeCard>[testStocktake()]);
      await pumpStocktake(tester);
      await chooseSource(tester);

      await scrollTo(tester, find.byKey(const Key('stocktake-cancel')));
      await tester.tap(find.byKey(const Key('stocktake-cancel')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('تأكيد إلغاء الجرد'));
      await tester.pumpAndSettle();

      expect(find.text('تأكيد إلغاء الجرد'), findsOneWidget);
      expect(
        find.text(catalogText(CatalogMessage.operationFailed)),
        findsOneWidget,
      );
    });
  });

  group('⛔⛔★★★ لافتةُ النجاح تبقى عبر تبدّل المرحلة', () {
    testWidgets('★★★ واعتمادٌ ناجحٌ يُغلِق المسوّدة ويُبقي لافتةَ «اعتُمد الجرد»',
        (WidgetTester tester) async {
      // ⚠️ **ارتدادٌ رُصد على المحاكي 2026-09-05** — ★ **الاعتمادُ يُغلِق
      //   المسوّدة فيُستبدَل النموذج**: ⛔ **وكانت اللافتةُ تُتلَف معه**،
      //   ⟵ **فيبدو للمستخدم أن شيئاً لم يحدث.**
      directory.emit(<StocktakeCard>[testStocktake()]);
      await pumpStocktake(tester);
      await chooseSource(tester);

      await tester.enterText(
        find.byKey(const Key('stocktake-count-ITM-0001')),
        '78',
      );
      await tester.pumpAndSettle();
      await scrollTo(tester, find.byKey(const Key('stocktake-approve')));
      await tester.tap(find.byKey(const Key('stocktake-approve')));
      await tester.pumpAndSettle();

      // ★ **والمسوّدةُ تُغلَق فيعود نموذجُ البدء** — ⟵ **كما يفعل الدليلُ الحيّ.**
      directory.emit(<StocktakeCard>[
        testStocktake(status: StocktakeStatus.approved),
      ]);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('stocktake-start')), findsOneWidget);
      expect(
        find.textContaining('اعتُمد الجرد STK-20260905-001'),
        findsOneWidget,
      );
    });
  });

  group('⛔⛔★★★ AM-021 ④ — سطرُ حالة الجرد بثلاثيةٍ لونية لا نصٌّ عارٍ', () {
    /// ★ يقرأ لافتةَ الحالة من شريط الإجراء الثابت — و`null` حين لا حالة.
    ///
    /// ⛔⛔ **ونفسُ مُساعِد `disposal_screen_test.dart` حرفاً بحرف** — ★ **فالنمطُ
    /// المرجعيُّ واحدٌ ويُقاس بالطريقة نفسِها** (§8 المحظور 11).
    QtmsActionStatus? statusOf(WidgetTester tester) {
      final Finder banner = find.byType(QtmsActionStatus);
      if (banner.evaluate().isEmpty) return null;
      return tester.widget<QtmsActionStatus>(banner);
    }

    testWidgets('★★★ ورفضُ البدء بلا نوعٍ بثلاثية `danger` وأيقونةٍ متجهية',
        (WidgetTester tester) async {
      await pumpStocktake(tester);
      await chooseSource(tester);

      await scrollTo(tester, find.byKey(const Key('stocktake-start')));
      await tester.tap(find.byKey(const Key('stocktake-start')));
      await tester.pumpAndSettle();

      final QtmsActionStatus? status = statusOf(tester);
      expect(status, isNotNull);
      expect(status!.triad, SemanticTriads.danger);
      expect(status.icon, Icons.error_outline);
      expect(status.message, 'اختر نوعاً واحداً على الأقل لجرده.');
      // ⛔ **ولا رمزَ إيموجي في الشاشة كلِّها بعد اليوم.**
      expect(find.textContaining('❌'), findsNothing);
    });

    testWidgets('★★★ وبدءٌ ناجحٌ بثلاثية `success` ⛔ بلا «✅» إيموجي',
        (WidgetTester tester) async {
      await pumpStocktake(tester);
      await chooseSource(tester);
      await tapAddLine(tester);
      // ★ **وبنفس صيغة اختيار النوع القائمة في هذا الملف** — ⛔ **ولا ضغطةٌ
      //   على تسميةٍ غيرِ قابلةٍ للاختبار اللمسي.**
      await tester.tap(find.byType(DropdownMenu<String>).last);
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('عوارض').last);
      await tester.pumpAndSettle();

      await scrollTo(tester, find.byKey(const Key('stocktake-start')));
      await tester.tap(find.byKey(const Key('stocktake-start')));
      await tester.pumpAndSettle();

      final QtmsActionStatus? status = statusOf(tester);
      expect(status, isNotNull);
      expect(status!.triad, SemanticTriads.success);
      expect(status.icon, Icons.check_circle_outline);
      expect(status.message, 'بدأ الجرد STK-20260905-001');
      expect(find.textContaining('✅'), findsNothing);
    });

    testWidgets('★★★ وحرسُ العدّ الناقص بثلاثية `danger` بنصّه المُسمّى',
        (WidgetTester tester) async {
      directory.emit(<StocktakeCard>[testStocktake()]);
      await pumpStocktake(tester);
      await chooseSource(tester);

      await scrollTo(tester, find.byKey(const Key('stocktake-approve')));
      await tester.tap(find.byKey(const Key('stocktake-approve')));
      await tester.pumpAndSettle();

      final QtmsActionStatus? status = statusOf(tester);
      expect(status, isNotNull);
      expect(status!.triad, SemanticTriads.danger);
      expect(status.message, 'أدخل العدّ الفعلي لـ«عوارض».');
    });

    testWidgets('★★★ واعتمادٌ ناجحٌ بثلاثية `success`',
        (WidgetTester tester) async {
      directory.emit(<StocktakeCard>[testStocktake()]);
      await pumpStocktake(tester);
      await chooseSource(tester);

      await tester.enterText(
        find.byKey(const Key('stocktake-count-ITM-0001')),
        '78',
      );
      await tester.pumpAndSettle();
      await scrollTo(tester, find.byKey(const Key('stocktake-approve')));
      await tester.tap(find.byKey(const Key('stocktake-approve')));
      await tester.pumpAndSettle();

      final QtmsActionStatus? status = statusOf(tester);
      expect(status, isNotNull);
      expect(status!.triad, SemanticTriads.success);
      expect(status.message, 'اعتُمد الجرد STK-20260905-001');
    });

    testWidgets('★★★ وإلغاءٌ ناجحٌ بثلاثية `success` بعد إغلاق الورقة',
        (WidgetTester tester) async {
      directory.emit(<StocktakeCard>[testStocktake()]);
      await pumpStocktake(tester);
      await chooseSource(tester);

      await scrollTo(tester, find.byKey(const Key('stocktake-cancel')));
      await tester.tap(find.byKey(const Key('stocktake-cancel')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('تأكيد إلغاء الجرد'));
      await tester.pumpAndSettle();

      final QtmsActionStatus? status = statusOf(tester);
      expect(status, isNotNull);
      expect(status!.triad, SemanticTriads.success);
      expect(status.message, 'أُلغي الجرد STK-20260905-001');
    });

    testWidgets(
        '⛔⛔★★★ ورفضُ السحابة عند الاعتماد بثلاثية `danger` بنصّ الكتالوج',
        (WidgetTester tester) async {
      admin.nextApprove = const Failure<void>(ValidationError('BR-M16-XX'));
      directory.emit(<StocktakeCard>[testStocktake()]);
      await pumpStocktake(tester);
      await chooseSource(tester);

      await tester.enterText(
        find.byKey(const Key('stocktake-count-ITM-0001')),
        '78',
      );
      await tester.pumpAndSettle();
      await scrollTo(tester, find.byKey(const Key('stocktake-approve')));
      await tester.tap(find.byKey(const Key('stocktake-approve')));
      await tester.pumpAndSettle();

      final QtmsActionStatus? status = statusOf(tester);
      expect(status, isNotNull);
      expect(status!.triad, SemanticTriads.danger);
      expect(status.message, catalogText(CatalogMessage.operationFailed));
    });

    testWidgets(
        '⛔⛔★★★ ولافتةُ النجاح تعبر تبدّلَ المرحلة بثلاثيتها — لا بنصّها وحدَه',
        (WidgetTester tester) async {
      // ⚠️ **ارتدادُ 2026-09-05 نفسُه، مقيساً على النمط الجديد:** ★ **الاعتمادُ
      //   يُغلِق المسوّدة فيُستبدَل النموذج**، ⛔ **واللافتةُ يجب أن تبقى.**
      directory.emit(<StocktakeCard>[testStocktake()]);
      await pumpStocktake(tester);
      await chooseSource(tester);

      await tester.enterText(
        find.byKey(const Key('stocktake-count-ITM-0001')),
        '78',
      );
      await tester.pumpAndSettle();
      await scrollTo(tester, find.byKey(const Key('stocktake-approve')));
      await tester.tap(find.byKey(const Key('stocktake-approve')));
      await tester.pumpAndSettle();

      directory.emit(<StocktakeCard>[
        testStocktake(status: StocktakeStatus.approved),
      ]);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('stocktake-start')), findsOneWidget);
      final QtmsActionStatus? status = statusOf(tester);
      expect(status, isNotNull);
      expect(status!.triad, SemanticTriads.success);
      expect(status.message, 'اعتُمد الجرد STK-20260905-001');
    });
  });

  group('★★★ ADR-0020 — السببُ اختياريٌّ ويُوسَم صراحةً', () {
    testWidgets('★★ ونصُّ «اختياري» معروضٌ في حقل السبب',
        (WidgetTester tester) async {
      await pumpStocktake(tester);
      await chooseSource(tester);

      await scrollTo(tester, find.byKey(const Key('stocktake-reason')));
      expect(
        find.textContaining('اختياري — ولا يُكتب نيابةً عنك'),
        findsWidgets,
      );
    });
  });
}

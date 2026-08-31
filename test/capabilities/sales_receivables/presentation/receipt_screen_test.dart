/// شاشة المقبوضات وحساب المقوت — `WU-007`.
///
/// ⚠️⚠️ **وما تُثبته هذه الاختبارات وما لا تُثبته:** تُثبت أن الشاشة
/// **تعرض إجمالي الديون فور اختيار المقوت** (`FR-M12-03`)، وأن **التوزيع
/// التلقائي يملأ الحقول ولا يحفظ** (`FR-M12-14` — **أخطر ما في الوحدة**)،
/// وأن **الفائض وحده يُقبَل** (`FR-M12-10`)، وأن **نطاق الفائض يتبع فلتر
/// السند** (`E-13`).
/// ⛔ **ولا تُثبت أن الكتابة محميّة** — ★ **الحماية في `planReceipt`**،
/// ولها اختباراتها هناك (`functions/test/receipt_test.dart`).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qtms/capabilities/identity_access/application/session_providers.dart';
import 'package:qtms/capabilities/inventory/application/inventory_providers.dart';
import 'package:qtms/capabilities/master_data/application/master_data_providers.dart';
import 'package:qtms/capabilities/sales_receivables/application/receipt_providers.dart';
import 'package:qtms/capabilities/sales_receivables/presentation/receipt_screen.dart';
import 'package:qtms_domain/qtms_domain.dart';

import '../../../support/fake_identity.dart';
import '../../../support/fake_master_data.dart';
import '../../../support/fake_receipts.dart';

/// ★★ **اليوم مثبَّت** — ⛔ **فلا اختبارَ ينكسر بمرور منتصف الليل.**
final CalendarDay fixedDay = CalendarDay(2026, 8, 28);

late FakeReceiptDirectory receipts;
late FakeReceiptAdminRepository admin;
late FakeMasterDataDirectory masterData;

const Set<Permission> fullPermissions = <Permission>{
  Permission.receiptCreate,
  Permission.receiptAmend,
  Permission.receiptCancel,
  Permission.receiptBackdate,
  Permission.receiptDepositView,
  Permission.receiptDepositConfirm,
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

Future<void> pumpReceipts(
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
        receiptDirectoryProvider.overrideWithValue(receipts),
        receiptAdminProvider.overrideWithValue(admin),
        todayProvider.overrideWithValue(fixedDay),
      ],
      child: const MaterialApp(
        locale: Locale('ar'),
        home: ReceiptScreen(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 20));
}

/// ★ يُمرِّر حتى يظهر الودجت — ⛔ **فالقائمة تُبنى كسولاً في مقاس الاختبار**،
/// ⟵ **و`ensureVisible` تفترض عنصراً مبنيّاً أصلاً.**
Future<void> scrollTo(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    // ★★ **يُعاد للأعلى أولاً** — ⟵ **فالهدف قد يكون فوق الموضع الحالي**،
    //    ⛔ **و`scrollUntilVisible` تمضي في اتجاهٍ واحد فلا تبلغه أبداً.**
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
    find.byKey(Key('receipt-lot-${lot(
      stockDay: stockDay,
      sourceId: sourceId,
    ).debtLotId}'));

/// ★ يقرأ نصّ حقل ضمارٍ بعد التمرير إليه.
Future<String?> lotText(WidgetTester tester, int stockDay) async {
  final Finder finder = lotField(stockDay);
  await scrollTo(tester, finder);
  return tester.widget<TextField>(finder).controller?.text;
}

/// ★ حقل الفائض — **بمفتاحه** ⛔ **لا بترتيبه بين الحقول.**
Finder get surplusField => find.descendant(
      of: find.byKey(const Key('receipt-surplus')),
      matching: find.byType(TextField),
    );

Future<void> enterSurplus(WidgetTester tester, String value) async {
  await scrollTo(tester, surplusField);
  await tester.enterText(surplusField, value);
  await tester.pumpAndSettle();
}

Future<void> selectDealer(WidgetTester tester) async {
  await tester.tap(find.byType(DropdownButtonFormField<String>).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text('مقوت مثال').last);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    receipts = FakeReceiptDirectory();
    admin = FakeReceiptAdminRepository();
    masterData = FakeMasterDataDirectory();
    masterData.emitSources(<SourceCard>[testSource()]);
    masterData.emitDealers(<DealerCard>[testDealer()]);
    receipts.emitLots(<OpenDebtLot>[lot()]);
  });

  tearDown(() {
    receipts.dispose();
    masterData.dispose();
  });

  group('★ الشاشة تفتح وتطلب المقوت', () {
    testWidgets('★ بلا مقوتٍ مختار ⟵ إرشادٌ لا نموذج', (
      WidgetTester tester,
    ) async {
      await pumpReceipts(tester);
      expect(find.text('اختر المقوت'), findsOneWidget);
      expect(find.text('حفظ سند القبض'), findsNothing);
    });

    testWidgets('★★ FR-M12-03 — إجمالي الديون يظهر فور اختيار المقوت', (
      WidgetTester tester,
    ) async {
      receipts.emitLots(<OpenDebtLot>[
        lot(remaining: 30000),
        lot(stockDay: 21, remaining: 20000),
      ]);
      await pumpReceipts(tester);
      await selectDealer(tester);
      // ⟵ **قبل أي إدخال** (`BR-M12-11`).
      expect(
        find.textContaining('إجمالي الديون على المقوت: 50000'),
        findsOneWidget,
      );
    });

    testWidgets('★ ولا ضمار مفتوح ⟵ حالةٌ فارغة صريحة لا شاشةٌ خاوية', (
      WidgetTester tester,
    ) async {
      receipts.emitLots(const <OpenDebtLot>[]);
      await pumpReceipts(tester);
      await selectDealer(tester);
      expect(find.text('لا ضمارات مفتوحة'), findsOneWidget);
    });
  });

  group('★★★ التوزيع التلقائي — اقتراحٌ لا قرار (`FR-M12-14`)', () {
    testWidgets('★★★ يملأ الحقول ⛔ ولا يحفظ شيئاً — الحارسُ الحقيقي', (
      WidgetTester tester,
    ) async {
      receipts.emitLots(<OpenDebtLot>[
        lot(stockDay: 18, remaining: 20000),
        lot(stockDay: 20, remaining: 30000),
      ]);
      await pumpReceipts(tester);
      await selectDealer(tester);

      // ★ **يُدخِل المستخدم مبلغاً على الأقدم ثم يطلب التوزيع.**
      await tester.enterText(find.byType(TextField).first, '45000');
      await tester.pumpAndSettle();
      await tapVisible(tester, find.byKey(const Key('receipt-auto-allocate')));

      // ⛔⛔ **ولا سندَ حُفِظ** — ★ **الاقتراح عرضٌ محض.**
      expect(admin.created, isEmpty);
      // ★★ **والأقدم امتلأ كاملاً والذي يليه بالباقي.**
      expect(await lotText(tester, 18), '20000');
      expect(await lotText(tester, 20), '25000');
    });

    testWidgets('★★ AT-30 — ما يفيض يذهب لحقل الفائض', (
      WidgetTester tester,
    ) async {
      receipts.emitLots(<OpenDebtLot>[lot(remaining: 30000)]);
      await pumpReceipts(tester);
      await selectDealer(tester);
      await tester.enterText(find.byType(TextField).first, '50000');
      await tester.pumpAndSettle();
      await tapVisible(tester, find.byKey(const Key('receipt-auto-allocate')));

      expect(await lotText(tester, 20), '30000');
      expect(
        tester.widget<TextField>(surplusField).controller?.text,
        '20000',
      );
    });
  });

  group('★★ الحفظ — وما يُرسَل هو ما في الحقول', () {
    testWidgets('★★★ يُرسِل السطر الممتلئ وحده ⛔ لا الصفري', (
      WidgetTester tester,
    ) async {
      receipts.emitLots(<OpenDebtLot>[
        lot(stockDay: 18, remaining: 20000),
        lot(stockDay: 20, remaining: 30000),
      ]);
      await pumpReceipts(tester);
      await selectDealer(tester);
      await tester.enterText(find.byType(TextField).first, '5000');
      await tester.pumpAndSettle();
      await tapVisible(tester, find.byKey(const Key('receipt-save')));

      expect(admin.created.single.lines.length, 1);
      expect(admin.created.single.lines.single.amount, const Money(5000));
      // ★★ **والتاريخ الافتراضي اليوم** — `FR-M12-02`.
      expect(admin.created.single.date, fixedDay);
    });

    testWidgets('★★★ FR-M12-10 — فائضٌ وحده بلا سطر يُقبَل', (
      WidgetTester tester,
    ) async {
      await pumpReceipts(tester);
      await selectDealer(tester);
      await enterSurplus(tester, '20000');
      await tapVisible(tester, find.byKey(const Key('receipt-save')));

      expect(admin.created.single.lines, isEmpty);
      expect(admin.created.single.surplusAmount, const Money(20000));
    });

    testWidgets('⛔ وسندٌ فارغٌ تماماً لا يُرسَل أصلاً', (
      WidgetTester tester,
    ) async {
      await pumpReceipts(tester);
      await selectDealer(tester);
      await tapVisible(tester, find.byKey(const Key('receipt-save')));

      expect(admin.created, isEmpty);
      expect(
        find.textContaining('أدخل مبلغاً على ضمارٍ واحد'),
        findsOneWidget,
      );
    });

    testWidgets('★★★ E-13 — نطاق الفائض يتبع فلتر السند', (
      WidgetTester tester,
    ) async {
      await pumpReceipts(tester);
      await selectDealer(tester);
      await enterSurplus(tester, '20000');
      await tapVisible(tester, find.byKey(const Key('receipt-save')));

      // ⟵ **الفلتر «الكل» ابتداءً** ⟵ **فالفائض عامّ** (`FR-M12-12`).
      expect(admin.created.single.surplusScope, SurplusScope.general);
      expect(admin.created.single.sourceFilter, isNull);
    });

    testWidgets('★★ ورفضُ السحابة يُعرَض برسالة الكتالوج ⛔ لا برمزٍ خام', (
      WidgetTester tester,
    ) async {
      admin.nextResult = const Failure<String>(ValidationError('BR-M12-02'));
      await pumpReceipts(tester);
      await selectDealer(tester);
      await tester.enterText(find.byType(TextField).first, '5000');
      await tester.pumpAndSettle();
      await tapVisible(tester, find.byKey(const Key('receipt-save')));

      expect(find.textContaining('BR-M12-02'), findsNothing);
    });
  });

  group('★★ النطاق والتنبيهات', () {
    testWidgets('⛔⛔★★★ «الكل» تصل مُعدَّدةً ⛔ لا غياباً — حارسُ `IQ-024`', (
      WidgetTester tester,
    ) async {
      masterData.emitSources(<SourceCard>[
        testSource(),
        testSource(sourceId: 'SRC-002', name: 'ماوية'),
      ]);
      await pumpReceipts(tester);
      await selectDealer(tester);
      // ⛔⛔★★★ **الحارسُ الحقيقي:** ★ **شرطُ قراءة `distributions` يعتمد
      //    `resource.data.sourceId`** ⟵ **واستعلامٌ لا يُقيّده يُرفَض كاملاً
      //    ولو بنطاقٍ شامل** (`IQ-024` · `WU-008` · `DEBT-40`).
      expect(receipts.requestedSources.last, <String>['SRC-001', 'SRC-002']);
    });

    testWidgets('★★ ومصدرٌ محدد يُقيَّد وحده', (WidgetTester tester) async {
      masterData.emitSources(<SourceCard>[
        testSource(),
        testSource(sourceId: 'SRC-002', name: 'ماوية'),
      ]);
      await pumpReceipts(tester);
      await selectDealer(tester);
      await tester.tap(find.byType(DropdownButtonFormField<String?>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ماوية').last);
      await tester.pumpAndSettle();
      expect(receipts.requestedSources.last, <String>['SRC-002']);
    });

    testWidgets('★★★ E-12 — تنبيهٌ صريح عند فائضٍ مع ديونٍ مفتوحة', (
      WidgetTester tester,
    ) async {
      await pumpReceipts(tester);
      await selectDealer(tester);
      await enterSurplus(tester, '5000');

      // ⛔ **تنبيهٌ لا منع** — `FR-M12-10`.
      expect(
        find.textContaining('يوجد ضمارات مفتوحة بقيمة 30000'),
        findsOneWidget,
      );
      expect(find.text('حفظ سند القبض'), findsOneWidget);
    });

    testWidgets('★★ ومبلغٌ يتجاوز المتبقي يُوسَم لحظياً', (
      WidgetTester tester,
    ) async {
      await pumpReceipts(tester);
      await selectDealer(tester);
      await tester.enterText(find.byType(TextField).first, '30001');
      await tester.pumpAndSettle();

      expect(find.text('يتجاوز المتبقي'), findsOneWidget);
    });

    // ═══════════ ⛔⛔★★★ ارتدادُ `DEBT-61` — كشفه المحاكي وحده ═══════════
    //
    // ★★★ **العطل كما وقع فعلاً على `Pixel_6_API_36` (2026-08-29):** ★ **سندُ
    //    قبضٍ بـ3000 على ضمارٍ متبقيه 5000 نجح فعلاً في السحابة**
    //    (`remaining` **صار 2000 مقيساً في Firestore**) ⛔ **والشاشة بقيت
    //    تعرض «المتبقي: 5000» ولافتةَ «5000 ريال» — حتى بعد الخروج من
    //    الشاشة والرجوع إليها**، ★ **ولم تصحّ إلا بإقلاعٍ جديد للتطبيق.**
    //
    // ⛔⛔★★★ **ولماذا لم يكشفه أيٌّ من 1507 اختباراً آلياً:** ★ **السببُ يعيش
    //    في حدٍّ بين طبقتين لا داخل واحدة** — **`openDebtLotsProvider` يبثّ
    //    مستنداتِ `distributions` الأب، والمتبقي يُقرأ قراءةً مفردةً من
    //    `pricing/current`** ⟵ **وسندُ القبض لا يمسّ الأب إطلاقاً**
    //    (`IQ-027` · `ADR-0011`): ⛔ **فلا حدثَ بثٍّ يقع.** ★★ **وبديلُ
    //    الاختبار يبثّ ما يُملى عليه فيُخفي الحدَّ نفسَه** — ⟹ **وهذا ثالثُ
    //    وجوه درس `DEBT-37`: اختبارُ الطبقة لا يُغني عن اختبار ما يعبر بينها.**
    //
    // ★ **فالحارسُ هنا سلوكيٌّ لا حسابي:** ⛔ **لا يفحص رقماً** — ★ **يفحص أن
    //    الشاشة أعادت طلبَ المشتقّ بعد كتابةٍ ناجحة**، ⟵ **وهو بالضبط ما كان
    //    غائباً.**
    testWidgets(
        '⛔⛔★★★ DEBT-61 — بعد حفظٍ ناجح تُعاد قراءةُ الضمارات ⛔ لا تبقى قيمةً بائتة',
        (WidgetTester tester) async {
      receipts.emitLots(<OpenDebtLot>[lot(remaining: 5000)]);
      await pumpReceipts(tester);
      await selectDealer(tester);
      final int before = receipts.requestedSources.length;

      await tester.enterText(find.byType(TextField).first, '3000');
      await tester.pumpAndSettle();
      await tapVisible(tester, find.byKey(const Key('receipt-save')));

      // ★ **الكتابة نجحت فعلاً** — ⟵ **فالشرط منطبق.**
      expect(admin.created.single.lines.single.amount, const Money(3000));
      // ⛔⛔★★★ **والمشتقُّ أُعيد طلبُه** — ★ **قبل الإصلاح كان يبقى كما هو.**
      expect(
        receipts.requestedSources.length,
        greaterThan(before),
        reason: '★ سندٌ ناجح يجب أن يُبطِل قراءة الضمارات المفتوحة — DEBT-61',
      );
    });

    testWidgets('⛔★★ وسندٌ فاشل لا يُبطِل شيئاً — ⟵ فلا قراءةَ بلا سبب', (
      WidgetTester tester,
    ) async {
      admin.nextResult = const Failure<String>(ValidationError('BR-M12-02'));
      receipts.emitLots(<OpenDebtLot>[lot(remaining: 5000)]);
      await pumpReceipts(tester);
      await selectDealer(tester);
      final int before = receipts.requestedSources.length;

      await tester.enterText(find.byType(TextField).first, '3000');
      await tester.pumpAndSettle();
      await tapVisible(tester, find.byKey(const Key('receipt-save')));

      // ★ **الفشلُ لا يُغيِّر رصيداً** — ⟵ **فإبطالُه قراءةٌ بلا موجب.**
      expect(receipts.requestedSources.length, before);
    });
  });
}

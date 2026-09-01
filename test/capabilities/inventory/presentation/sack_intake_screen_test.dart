/// شاشة الوارد جواني — `WU-004`.
///
/// ⚠️⚠️ **وما تُثبته هذه الاختبارات وما لا تُثبته:** تُثبت أن **الواجهة
/// تُمرِّر ما كتبه المستخدم كما هو**، وأنها **لا تعرض ما يمنعه المتطلب**
/// (لا تاريخ · لا رقم متسلسل · لا حقل وزن حبة لنوعٍ عددي · لا حذف)،
/// وأن **الحاسبة الحيّة تستدعي دوال النطاق**، وأنها **تعرض رفض السحابة
/// بنصّه**. ⛔ **ولا تُثبت أن الكتابة محميّة** — ★ **الحماية في `planSack`**،
/// ولها اختباراتها هناك (`functions/test/sack_intake_test.dart`).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qtms/capabilities/identity_access/application/session_providers.dart';
import 'package:qtms/capabilities/inventory/application/inventory_providers.dart';
import 'package:qtms/capabilities/inventory/presentation/sack_intake_screen.dart';
import 'package:qtms/capabilities/master_data/application/master_data_providers.dart';
import 'package:qtms/core/messages/error_messages.dart';
import 'package:qtms/core/ui/async_state_view.dart';
import 'package:qtms/core/ui/context_header.dart';
import 'package:qtms_domain/qtms_domain.dart';

import '../../../support/fake_identity.dart';
import '../../../support/fake_master_data.dart';
import '../../../support/fake_sacks.dart';

/// ★ كل مفاتيح الجونية — فالاختبار يقيس **القاعدة لا نقصَ المفتاح**.
const Set<Permission> sackKeys = <Permission>{
  Permission.sackCreate,
  Permission.sackView,
  Permission.sackLinesEnter,
  Permission.sackScrapWeightEnter,
  Permission.sackLostWeightConfirm,
  Permission.sackCancel,
};

/// ★★ **اليوم مثبَّت** — ⛔ **فلا اختبارَ ينكسر بمرور منتصف الليل.**
final CalendarDay fixedDay = CalendarDay(2026, 8, 26);

/// ★ نوعٌ وزنيٌّ **بوزن حبة في التهيئة** — **الحالة ①**.
ItemCard weightedItem() => testItem(
      itemId: 'ITM-0002',
      name: 'بطوة',
      nature: ItemNature.weightBased,
      pieceWeightGrams: 200,
    );

/// ★ نوعٌ وزنيٌّ **بلا وزن حبة** — **الحالة ②** (`E-08`).
ItemCard weightedItemNoConfig() => testItem(
      itemId: 'ITM-0003',
      name: 'معالم',
      nature: ItemNature.weightBased,
    );

/// ★ نوعٌ عدديّ — **الحالة ③**.
ItemCard countedItem() => testItem(
      itemId: 'ITM-0004',
      name: 'عود',
      nature: ItemNature.countBased,
    );

/// ★★★ **يضيف سطرَ نوعٍ بالنمط الجديد** — `AM-009` ④.
///
/// ⛔⛔★★ **وحلّ محلَّ «مربّعِ اختيارٍ على صفٍّ من الكتالوج»:** ★ **كانت
/// الورقة تعرض *كلَّ* أنواع المصدر صفوفاً**، ⟵ **وصارت صفّاً يُنشأ بالطلب**
/// — **زرُّ `+` ثم منسدلٌ يُصفّي بالكتابة.**
Future<void> pickLine(WidgetTester tester, String item) async {
  await tester.tap(find.text('إضافة نوع'));
  await tester.pumpAndSettle();
  await tester.tap(find.byType(DropdownMenu<String>).last);
  await tester.pumpAndSettle();
  await tester.tap(find.text(item).last);
  await tester.pumpAndSettle();
}

Future<void> pumpScreen(
  WidgetTester tester, {
  required Widget screen,
  required FakeSackDirectory sacks,
  required FakeSackAdmin admin,
  required FakeMasterDataDirectory masterData,
  Set<Permission> actorPermissions = sackKeys,
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
        sackDirectoryProvider.overrideWithValue(sacks),
        sackAdminProvider.overrideWithValue(admin),
        todayProvider.overrideWithValue(fixedDay),
      ],
      // ⚠️ **والأوراق تحتاج سلفاً من `Material`** — ★ **تُقدّمه الصدَفة
      //   في التطبيق الحقيقي** (`showModalBottomSheet`)، ⟵ **ويُقدَّم هنا
      //   صراحةً** ⛔ **بدل فتحها بنقرةٍ تُقحِم شاشةً أخرى في كل اختبار.**
      child: MaterialApp(
        locale: const Locale('ar'),
        home: Scaffold(body: screen),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 20));
}

void main() {
  late FakeSackDirectory sacks;
  late FakeSackAdmin admin;
  late FakeMasterDataDirectory masterData;

  setUp(() {
    sacks = FakeSackDirectory();
    admin = FakeSackAdmin();
    masterData = FakeMasterDataDirectory();
    masterData.emitSources(<SourceCard>[testSource()]);
    masterData.emitItems(<ItemCard>[
      weightedItem(),
      weightedItemNoConfig(),
      countedItem(),
    ]);
    masterData.emitSuppliers(<SupplierCard>[
      SupplierCard(
        supplierId: 'SUP-0001',
        name: 'عبدالفتاح',
        phone: '777111222',
        isActive: true,
      ),
    ]);
    sacks.emitSacks(const <SackCard>[]);
  });

  tearDown(() {
    sacks.dispose();
    masterData.dispose();
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('★★ نموذج رأس الجونية — FR-M7-02 · FR-M7-04 · FR-M7-08', () {
    testWidgets('⛔★★ ولا حقل تاريخ ولا رقم متسلسل في النموذج', (
      WidgetTester tester,
    ) async {
      await pumpScreen(
        tester,
        screen: const SackHeaderFormSheet(sourceId: 'SRC-001'),
        sacks: sacks,
        admin: admin,
        masterData: masterData,
      );

      for (final String forbidden in <String>[
        'التاريخ',
        'تاريخ التوريد',
        'الرقم المتسلسل',
        'رقم الجونية',
      ]) {
        expect(find.widgetWithText(TextField, forbidden), findsNothing,
            reason: '⛔ «$forbidden» من الخادم — FR-M7-02 · FR-M7-04');
      }
    });

    testWidgets('★★★ AT-06: الحاسبة تُظهر المطالب به حيّاً مع كل ضغطة', (
      WidgetTester tester,
    ) async {
      await pumpScreen(
        tester,
        screen: const SackHeaderFormSheet(sourceId: 'SRC-001'),
        sacks: sacks,
        admin: admin,
        masterData: masterData,
      );

      await tester.enterText(
        find.widgetWithText(TextField, 'الوزن الكلي'),
        '45',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'وزن الثلج'),
        '6.5',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'وزن السكرب'),
        '1.2',
      );
      await tester.pump();

      // ★ **الرقم من [explainSackWeight] لا من حسابٍ في الشاشة.**
      expect(find.textContaining('37.300'), findsOneWidget);
    });

    testWidgets('⛔★★ BR-M7-07: الكلي ≤ الثلج + السكرب ⟵ رفضٌ بنصّه', (
      WidgetTester tester,
    ) async {
      await pumpScreen(
        tester,
        screen: const SackHeaderFormSheet(sourceId: 'SRC-001'),
        sacks: sacks,
        admin: admin,
        masterData: masterData,
      );

      await tester.enterText(
        find.widgetWithText(TextField, 'الوزن الكلي'),
        '10',
      );
      await tester.enterText(find.widgetWithText(TextField, 'وزن الثلج'), '6');
      await tester.enterText(
        find.widgetWithText(TextField, 'وزن السكرب'),
        '4',
      );
      // ★ **ويُختار الرعوي أولاً** — ⟵ **فالقيد ② يسبق ③ في
      //   `validateSackIntake`**، ⛔ **وبدونه كنّا نقيس رسالة الرعوي
      //   ونظنّها رسالة الأوزان** (وهو نجاحٌ لسببٍ خاطئ).
      // ★★ **ويُمرَّر إليه أولاً** — ⟵ **فالحقول تمرّ وحدها بعد `P5`**
      //    (`MASTER.md` §5b): ★ **والميزان ثابتٌ فوقها.**
      await tester.ensureVisible(find.text('عبدالفتاح'));
      await tester.pump();
      await tester.tap(find.text('عبدالفتاح'));
      await tester.pump();

      await tester.ensureVisible(
        find.widgetWithText(FilledButton, 'حفظ الرأس'),
      );
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'حفظ الرأس'));
      await tester.pump();

      expect(
        find.text(catalogText(CatalogMessage.sackWeightsIllogical)),
        findsOneWidget,
      );
      // ⛔ **ولا يُرسَل شيء للسحابة.**
      expect(admin.createdSack, isNull);
    });

    testWidgets('✅ والأوزان الصحيحة تُمرَّر كما كتبها المستخدم', (
      WidgetTester tester,
    ) async {
      await pumpScreen(
        tester,
        screen: const SackHeaderFormSheet(sourceId: 'SRC-001'),
        sacks: sacks,
        admin: admin,
        masterData: masterData,
      );

      await tester.enterText(
        find.widgetWithText(TextField, 'الوزن الكلي'),
        '45',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'وزن الثلج'),
        '6.5',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'وزن السكرب'),
        '1.2',
      );
      await tester.pump();
      // ★★ **ويُمرَّر إليه أولاً** — ⟵ **فالحقول تمرّ وحدها بعد `P5`**
      //    (`MASTER.md` §5b): ★ **والميزان ثابتٌ فوقها.**
      await tester.ensureVisible(find.text('عبدالفتاح'));
      await tester.pump();
      await tester.tap(find.text('عبدالفتاح'));
      await tester.pump();

      await tester.ensureVisible(
        find.widgetWithText(FilledButton, 'حفظ الرأس'),
      );
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'حفظ الرأس'));
      await tester.pump();

      expect(admin.createdSack, isNotNull);
      expect(admin.createdSack!.weights.totalWeight.kilograms, 45);
      expect(admin.createdSack!.weights.scrapWeight.kilograms, 1.2);
      expect(admin.createdSack!.supplierId, 'SUP-0001');
      // ⛔★★ **ولا سطر واحد في الإنشاء** — `FR-M7-27`.
      expect(admin.createdSack!.lines, isEmpty);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('★★★ FR-M7-13 — جدول وزن الحبة في الواجهة', () {
    testWidgets('⛔★★★ E-09: النوع العددي بلا حقل وزن حبة إطلاقاً', (
      WidgetTester tester,
    ) async {
      await pumpScreen(
        tester,
        screen: SackLinesFormSheet(sack: testSack(stockDate: fixedDay)),
        sacks: sacks,
        admin: admin,
        masterData: masterData,
      );

      // ★ يُختار النوع العددي.
      await pickLine(tester, 'عود');

      // ⛔★★ **والقفل غيابُ الحقل لا تعطيلُه** — راجع الشاشة.
      expect(find.widgetWithText(TextField, 'وزن الحبة (جم)'), findsNothing);
      expect(
        find.widgetWithText(TextField, 'الوزن الكلي (كجم)'),
        findsOneWidget,
      );
      // ★★ **والنصُّ صار إرشاداً على الحقل نفسِه** — `AM-009` ④:
      //    ⟵ **فيُقرأ مع الحقل لا في سطرٍ منفصلٍ تحته.**
      expect(find.text('وزن الحبة يُستنتَج'), findsOneWidget);
    });

    testWidgets('★ ① النوع الوزني يعرض وزن الحبة من التهيئة تلقائياً', (
      WidgetTester tester,
    ) async {
      await pumpScreen(
        tester,
        screen: SackLinesFormSheet(sack: testSack(stockDate: fixedDay)),
        sacks: sacks,
        admin: admin,
        masterData: masterData,
      );

      await pickLine(tester, 'بطوة');

      final TextField field = tester.widget<TextField>(
        find.widgetWithText(TextField, 'وزن الحبة (جم)'),
      );
      expect(field.controller!.text, '200.0');
    });

    testWidgets('★★★ AT-08: 100 × 200جم = 20.000 كجم في شريط التقدّم', (
      WidgetTester tester,
    ) async {
      await pumpScreen(
        tester,
        screen: SackLinesFormSheet(sack: testSack(stockDate: fixedDay)),
        sacks: sacks,
        admin: admin,
        masterData: masterData,
      );

      await pickLine(tester, 'بطوة');
      await tester.enterText(
        find.widgetWithText(TextField, 'العدد'),
        '100',
      );
      await tester.pump();

      // ★★ **فُسِّر 20.000 من 37.300 كجم** — `FR-M7-29`.
      expect(find.textContaining('فُسِّر 20.000 من 37.300'), findsOneWidget);
      // ⚠️ **والمتبقي 17.300 «غير مفسَّر»** — ★ **حالةٌ مشروعة** (`E-10`).
      expect(find.textContaining('متبقٍ 17.300'), findsOneWidget);
    });

    testWidgets('⛔★★★ E-08: وزنيٌّ بلا وزن حبة ⟵ رفضٌ بنصّه عند الحفظ', (
      WidgetTester tester,
    ) async {
      await pumpScreen(
        tester,
        screen: SackLinesFormSheet(sack: testSack(stockDate: fixedDay)),
        sacks: sacks,
        admin: admin,
        masterData: masterData,
      );

      await pickLine(tester, 'معالم');
      await tester.enterText(find.widgetWithText(TextField, 'العدد'), '50');
      await tester.pump();

      await tester.tap(find.widgetWithText(FilledButton, 'حفظ الأنواع'));
      await tester.pump();

      expect(
        find.text(catalogText(CatalogMessage.pieceWeightMissing)),
        findsOneWidget,
      );
      // ⛔ **ولا يُستنتَج له وزن حبة ولا يُرسَل السطر.**
      expect(admin.enteredLines, isNull);
    });

    // ═════════════════════════════════════════════════════════════════
    // ★★★ `DEBT-37` — **مصدرُ وزن الحبة يُكتَب صحيحاً ولا يُغسَل**
    //
    // ⚠️⚠️ **ولماذا اختبارٌ على `pieceWeightOrigin` لا على الرقم:** الرقم
    // نفسه في الحالتين (200جم) — ★ **والمصدر وحده يُفرِّق**، ⟵ **وهو ما
    // يقرأه المدقّق** (`sack-intake-design.md` §4). ⛔ **وعطلٌ فيه لا يظهر
    // في أي شاشة ولا يُغيِّر ريالاً واحداً** — **يُغيِّر معنى السجل فقط.**
    // ═════════════════════════════════════════════════════════════════
    testWidgets('★★★ ① رقمُ التهيئة بلا مساسٍ يُوسَم «تهيئة» ⛔ لا «يدوي»', (
      WidgetTester tester,
    ) async {
      await pumpScreen(
        tester,
        screen: SackLinesFormSheet(sack: testSack(stockDate: fixedDay)),
        sacks: sacks,
        admin: admin,
        masterData: masterData,
      );

      await pickLine(tester, 'بطوة');
      // ★ **والعدد وحده يُكتَب** — ⛔ **وحقل وزن الحبة لا يُمَسّ.**
      await tester.enterText(find.widgetWithText(TextField, 'العدد'), '100');
      await tester.pump();

      await tester.tap(find.widgetWithText(FilledButton, 'حفظ الأنواع'));
      await tester.pump();

      final ValidatedSackLine line = admin.enteredLines!.single;
      expect(line.pieceWeightGrams, 200);
      expect(line.pieceWeightOrigin, PieceWeightOrigin.configured);
    });

    testWidgets('⛔★★★ وتعديلٌ لسببٍ آخر لا يُعيد وسمَ سطرٍ لم يُمَسّ', (
      WidgetTester tester,
    ) async {
      // ★ سطرٌ مخزَّن **مصدره التهيئة** — ⟵ **والتعديل يُضيف نوعاً آخر.**
      final ValidatedSackLine stored = (resolveSackLine(
        const SackLineInput(
          itemId: 'ITM-0002',
          itemName: 'بطوة',
          nature: ItemNature.weightBased,
          unit: ItemUnit.piece,
          quantity: 100,
          configuredPieceWeightGrams: 200,
        ),
      ) as Success<ValidatedSackLine>)
          .value;
      expect(stored.pieceWeightOrigin, PieceWeightOrigin.configured);

      await pumpScreen(
        tester,
        screen: SackLinesFormSheet(
          sack: testSack(stockDate: fixedDay, lines: <ValidatedSackLine>[stored]),
        ),
        sacks: sacks,
        admin: admin,
        masterData: masterData,
      );

      await pickLine(tester, 'عود');
      await tester.enterText(
        find.widgetWithText(TextField, 'الوزن الكلي (كجم)'),
        '5',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'العدد').last,
        '50',
      );
      await tester.pump();

      await tester.tap(find.widgetWithText(FilledButton, 'حفظ الأنواع'));
      await tester.pump();

      final ValidatedSackLine resent = admin.enteredLines!
          .firstWhere((ValidatedSackLine l) => l.itemId == 'ITM-0002');
      expect(resent.pieceWeightGrams, 200);
      expect(resent.pieceWeightOrigin, PieceWeightOrigin.configured);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('★★★ FR-M7-19 · BR-M7-12 — تأكيد الوزن الضائع صريحٌ وحده', () {
    testWidgets('⛔★★★ الحفظ العادي لا يُسجِّل وزناً ضائعاً ضمناً', (
      WidgetTester tester,
    ) async {
      await pumpScreen(
        tester,
        screen: SackLinesFormSheet(sack: testSack(stockDate: fixedDay)),
        sacks: sacks,
        admin: admin,
        masterData: masterData,
      );

      await pickLine(tester, 'بطوة');
      await tester.enterText(find.widgetWithText(TextField, 'العدد'), '100');
      await tester.pump();

      await tester.tap(find.widgetWithText(FilledButton, 'حفظ الأنواع'));
      await tester.pump();

      expect(admin.enteredLines, hasLength(1));
      // ⛔★★★ **وهذا جوهر `BR-M7-12`** — ⟵ **الحفظ لا يُؤكِّد شيئاً.**
      expect(admin.lostWeightConfirmations, 0);
    });

    testWidgets('★★ والزر الصريح وحده يُؤكِّد — ويظهر بالمتبقي', (
      WidgetTester tester,
    ) async {
      await pumpScreen(
        tester,
        screen: SackLinesFormSheet(sack: testSack(stockDate: fixedDay)),
        sacks: sacks,
        admin: admin,
        masterData: masterData,
      );

      // ★ بلا سطور: المتبقي = المطالب به كاملاً (37.300).
      expect(
        find.textContaining('تأكيد الوزن الضائع (37.300 كجم)'),
        findsOneWidget,
      );

      // ⛔⛔★★ **ويُقصَد بنصّه لا بنوعه** — `AM-009` ④: ★ **صار في الورقة
      //    زرٌّ محاطٌ ثانٍ («إضافة نوع»)**، ⟵ **و«أولُ `OutlinedButton`»
      //    كان سيُصيب الخطأ** ⛔ **فيمرّ الاختبار على فعلٍ آخر.**
      await tester.tap(
        find.widgetWithText(OutlinedButton, 'تأكيد الوزن الضائع (37.300 كجم)'),
      );
      await tester.pump();

      expect(admin.lostWeightConfirmations, 1);
    });

    testWidgets('⛔ والزر يختفي حين لا متبقٍّ — فلا تأكيدَ بلا سبب', (
      WidgetTester tester,
    ) async {
      // ★ سطرٌ عدديّ يُفسِّر المطالب به بالكامل.
      final ValidatedSackLine full = (resolveSackLine(
        const SackLineInput(
          itemId: 'ITM-0004',
          itemName: 'عود',
          nature: ItemNature.countBased,
          unit: ItemUnit.piece,
          quantity: 100,
          lineTotalWeight: 37.3,
        ),
      ) as Success<ValidatedSackLine>)
          .value;

      await pumpScreen(
        tester,
        screen: SackLinesFormSheet(
          sack: testSack(
            stockDate: fixedDay,
            lines: <ValidatedSackLine>[full],
          ),
        ),
        sacks: sacks,
        admin: admin,
        masterData: masterData,
      );

      // ⛔⛔★★ **ويُقاس غيابُه بنصّه لا بنوعه** — `AM-009` ④: ★ **زرُّ
      //    «إضافة نوع» محاطٌ كذلك**، ⟵ **و«لا `OutlinedButton` البتة»
      //    كان سيقيس اختفاءَ زرِّ الإضافة** ⛔ **لا اختفاءَ التأكيد.**
      expect(find.textContaining('تأكيد الوزن الضائع'), findsNothing);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('★★★ P3 — رأس السياق الموحّد (ADR-0021 · MASTER.md §5b)', () {
    testWidgets('★ صفٌّ واحد: قائمةٌ منسدلة + يومٌ مقفل — ⛔ ولا شرائح تلتفّ', (
      WidgetTester tester,
    ) async {
      await pumpScreen(
        tester,
        screen: const SackIntakeScreen(),
        sacks: sacks,
        admin: admin,
        masterData: masterData,
      );

      // ★★ **رأسٌ واحد للشاشة** — ⛔ **ولا `SourcePicker` ولا لافتةٌ ثانية.**
      expect(find.byType(QtmsContextHeader), findsOneWidget);
      expect(find.text('2026/08/26'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      // ⛔⛔ **ولا شريحةَ مصدرٍ واحدة في الرأس** — ★ **وهي ما كان يلتفّ.**
      expect(find.byType(ChoiceChip), findsNothing);
    });

    testWidgets('⛔⛔★★★ ولا فراغٌ صامت بلا مصدر — حالةٌ مصمَّمة', (
      WidgetTester tester,
    ) async {
      // ★ **نطاقٌ بلا مصادر** — ⟵ **وهي الحالة التي كانت تُعرَض
      //   `SizedBox.shrink`**: ⛔ **شاشةٌ بيضاء تُقرأ عطلاً** (§هـ).
      masterData.emitSources(const <SourceCard>[]);
      await pumpScreen(
        tester,
        screen: const SackIntakeScreen(),
        sacks: sacks,
        admin: admin,
        masterData: masterData,
      );

      expect(find.byType(QtmsEmptyState), findsOneWidget);
      expect(find.textContaining('لا يوجد مصدر ضمن نطاقك'), findsWidgets);
    });
  });

  group('القائمة والإلغاء', () {
    testWidgets('★★ الشاشة تستعلم على تاريخ المخزون لا تاريخ الإدخال', (
      WidgetTester tester,
    ) async {
      await pumpScreen(
        tester,
        screen: const SackIntakeScreen(),
        sacks: sacks,
        admin: admin,
        masterData: masterData,
      );
      expect(sacks.lastStockDate, fixedDay);
      expect(sacks.lastSourceId, 'SRC-001');
    });

    testWidgets('★ والجونية تُعرَض باسمها الظاهر ومطالبها', (
      WidgetTester tester,
    ) async {
      sacks.emitSacks(<SackCard>[testSack(stockDate: fixedDay)]);
      await pumpScreen(
        tester,
        screen: const SackIntakeScreen(),
        sacks: sacks,
        admin: admin,
        masterData: masterData,
      );
      await tester.pump();

      expect(find.text('عبدالفتاح - جونية رقم 1'), findsOneWidget);
      expect(find.textContaining('المطالب به 37.300'), findsOneWidget);
    });

    testWidgets('⛔★★ ولا زر حذف إطلاقاً — GR-07', (
      WidgetTester tester,
    ) async {
      sacks.emitSacks(<SackCard>[testSack(stockDate: fixedDay)]);
      await pumpScreen(
        tester,
        screen: const SackIntakeScreen(),
        sacks: sacks,
        admin: admin,
        masterData: masterData,
      );
      await tester.pump();

      expect(find.byIcon(Icons.delete), findsNothing);
      expect(find.byIcon(Icons.delete_outline), findsNothing);
      expect(find.text('حذف'), findsNothing);
    });

    // ⛔⛔★★★ **ارتدادُ `ADR-0020`:** ★ **كانت الشاشة ترفض قبل الشبكة** —
    //    ⟵ **وصار الإلغاء بلا سببٍ مشروعاً فيصل السحابة**، ★ **والسببُ
    //    يصلها غياباً صريحاً** ⛔ **لا نصّاً مُعبَّأً عن المستخدم.**
    testWidgets('✅★★★ ADR-0020: والإلغاء بلا سبب يصل الشبكة بسببٍ غائب', (
      WidgetTester tester,
    ) async {
      await pumpScreen(
        tester,
        screen: CancelSackSheet(sack: testSack(stockDate: fixedDay)),
        sacks: sacks,
        admin: admin,
        masterData: masterData,
      );

      await tester.tap(find.widgetWithText(FilledButton, 'تأكيد الإلغاء'));
      await tester.pumpAndSettle();

      expect(admin.cancelCalls, 1);
      expect(admin.cancelReason, isNull);
      expect(
        find.text(catalogText(CatalogMessage.cancelReasonMissing)),
        findsNothing,
      );
    });

    testWidgets('★★ ورفض السحابة يُعرَض بنصّه من الكتالوج ⛔ لا يُبتلَع', (
      WidgetTester tester,
    ) async {
      admin.rejection = const PermissionError();
      await pumpScreen(
        tester,
        screen: CancelSackSheet(sack: testSack(stockDate: fixedDay)),
        sacks: sacks,
        admin: admin,
        masterData: masterData,
      );

      await tester.enterText(
        find.widgetWithText(TextField, 'سبب الإلغاء (اختياري)'),
        'إدخال خاطئ',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'تأكيد الإلغاء'));
      await tester.pump();

      expect(
        find.text(catalogText(CatalogMessage.permissionMissing)),
        findsOneWidget,
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('★★ RISK-02 — بوابات الصلاحية إخفاءٌ لا حماية', () {
    testWidgets('⛔ من لا يملك `sackCreate` لا يرى زر الإضافة', (
      WidgetTester tester,
    ) async {
      await pumpScreen(
        tester,
        screen: const SackIntakeScreen(),
        sacks: sacks,
        admin: admin,
        masterData: masterData,
        actorPermissions: const <Permission>{Permission.sackView},
      );

      expect(find.text('جونية جديدة'), findsNothing);
    });

    testWidgets('✅ ومن يملكه يراه', (WidgetTester tester) async {
      await pumpScreen(
        tester,
        screen: const SackIntakeScreen(),
        sacks: sacks,
        admin: admin,
        masterData: masterData,
      );

      expect(find.text('جونية جديدة'), findsOneWidget);
    });
  });
}

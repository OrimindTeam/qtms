/// شاشات البيانات المرجعية — `WU-002`.
///
/// ⚠️⚠️ **وما تُثبته هذه الاختبارات وما لا تُثبته:** تُثبت أن **الواجهة
/// تُمرِّر ما كتبه المستخدم كما هو**، وأنها **لا تعرض ما يمنعه المتطلب**،
/// وأنها **تعرض رفض السحابة بنصّه**. ⛔ **ولا تُثبت أن الكتابة محميّة** —
/// ★ **الحماية في `planMasterData` و`firestore.rules`**، ولها اختباراتها
/// هناك (`master_data_test.dart` · `rules.test.js`).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qtms/capabilities/identity_access/application/session_providers.dart';
import 'package:qtms/capabilities/master_data/application/master_data_providers.dart';
import 'package:qtms/capabilities/master_data/infrastructure/contact_picker.dart';
import 'package:qtms/capabilities/master_data/presentation/dealers_screen.dart';
import 'package:qtms/capabilities/master_data/presentation/items_screen.dart';
import 'package:qtms/capabilities/master_data/presentation/sources_screen.dart';
import 'package:qtms/capabilities/master_data/presentation/suppliers_screen.dart';
import 'package:qtms/core/messages/error_messages.dart';
import 'package:qtms/core/ui/entity_tile.dart';
import 'package:qtms_domain/qtms_domain.dart';

import '../../../support/fake_identity.dart';
import '../../../support/fake_master_data.dart';

/// ★ كل مفاتيح البيانات المرجعية — فالاختبار يقيس **القاعدة لا نقصَ المفتاح**.
const Set<Permission> masterDataKeys = <Permission>{
  Permission.sourceWrite,
  Permission.supplierWrite,
  Permission.dealerWrite,
  Permission.itemWrite,
};

Future<void> pumpScreen(
  WidgetTester tester, {
  required Widget screen,
  required FakeMasterDataDirectory directory,
  required FakeMasterDataAdmin admin,
  ContactPicker? picker,
  Set<Permission> actorPermissions = masterDataKeys,
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
        masterDataDirectoryProvider.overrideWithValue(directory),
        masterDataAdminProvider.overrideWithValue(admin),
        contactPickerProvider.overrideWithValue(picker),
      ],
      child: MaterialApp(locale: const Locale('ar'), home: screen),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 20));
}

void main() {
  late FakeMasterDataDirectory directory;
  late FakeMasterDataAdmin admin;

  setUp(() {
    directory = FakeMasterDataDirectory();
    admin = FakeMasterDataAdmin();
  });

  tearDown(() => directory.dispose());

  // ═══════════════════════════════════════════════════════════════════
  // المصادر — FR-M2
  // ═══════════════════════════════════════════════════════════════════

  group('★ المصادر — FR-M2', () {
    testWidgets('✅ تعرض المصادر وتُميّز إلزامية الرعوي', (WidgetTester t) async {
      directory.emitSources(<SourceCard>[
        testSource(name: 'رداع'),
        testSource(
          sourceId: 'SRC-002',
          name: 'ذمار',
          requiresSupplierOnIntake: false,
        ),
      ]);
      await pumpScreen(
        t,
        screen: const SourcesScreen(),
        directory: directory,
        admin: admin,
      );
      expect(find.text('رداع'), findsOneWidget);
      expect(find.text('ذمار'), findsOneWidget);
      expect(find.text('الرعوي إلزامي عند التوريد'), findsOneWidget);
      expect(find.text('الرعوي غير مطلوب عند التوريد'), findsOneWidget);
    });

    testWidgets('★★ والمعطَّل يُرى ولا يختفي — FR-M2-05', (WidgetTester t) async {
      directory.emitSources(<SourceCard>[testSource(isActive: false)]);
      await pumpScreen(
        t,
        screen: const SourcesScreen(),
        directory: directory,
        admin: admin,
      );
      expect(find.text('معطَّل'), findsOneWidget);
    });

    testWidgets('⛔★★ والرفض يُعرَض ⛔ لا كقائمة فارغة', (WidgetTester t) async {
      directory.emitSourcesError(
        Exception('[cloud_firestore/permission-denied] denied'),
      );
      await pumpScreen(
        t,
        screen: const SourcesScreen(),
        directory: directory,
        admin: admin,
      );
      expect(
        find.text(catalogText(CatalogMessage.permissionMissing)),
        findsOneWidget,
      );
      expect(find.text('لا توجد مصادر بعد.'), findsNothing);
    });

    testWidgets('⛔ ولا زر إنشاء بلا `sourceWrite`', (WidgetTester t) async {
      directory.emitSources(<SourceCard>[]);
      await pumpScreen(
        t,
        screen: const SourcesScreen(),
        directory: directory,
        admin: admin,
        actorPermissions: const <Permission>{},
      );
      expect(find.text('مصدر جديد'), findsNothing);
    });

    testWidgets('✅ وإنشاء مصدر يُمرِّر الخيار كما اختاره المستخدم',
        (WidgetTester t) async {
      directory.emitSources(<SourceCard>[]);
      await pumpScreen(
        t,
        screen: const SourcesScreen(),
        directory: directory,
        admin: admin,
      );
      await t.tap(find.text('مصدر جديد'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField).first, 'رداع');
      await t.tap(find.byType(SwitchListTile));
      await t.pump();
      await t.tap(find.text('إنشاء'));
      await t.pumpAndSettle();

      expect(admin.calls, 1);
      expect(admin.lastSource?.name, 'رداع');
      expect(admin.lastSource?.requiresSupplierOnIntake, isTrue);
      // ★ **والتطبيع من طبقة النطاق** — ⛔ ولا نسخة في الواجهة.
      expect(admin.lastSource?.normalizedName, normalizeName('رداع'));
    });

    testWidgets('⛔★★ ورفض السحابة يُعرَض بنصّه ⛔ ولا يُبتلَع',
        (WidgetTester t) async {
      directory.emitSources(<SourceCard>[]);
      admin.failure = const InfrastructureError('ERR_SETUP_004');
      await pumpScreen(
        t,
        screen: const SourcesScreen(),
        directory: directory,
        admin: admin,
      );
      await t.tap(find.text('مصدر جديد'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField).first, 'رداع');
      await t.tap(find.text('إنشاء'));
      await t.pumpAndSettle();

      expect(
        find.text(catalogText(CatalogMessage.sourceNameExists)),
        findsOneWidget,
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // الرعية — FR-M3
  // ═══════════════════════════════════════════════════════════════════

  group('★ الرعية — FR-M3', () {
    testWidgets('★★ FR-M3-03: جلب من جهات الاتصال يملأ الاسم والرقم معاً',
        (WidgetTester t) async {
      directory
        ..emitSuppliers(<SupplierCard>[])
        ..emitSources(<SourceCard>[testSource()]);
      final FakeContactPicker picker = FakeContactPicker(
        const PickedContact(name: 'صالح', phone: '0777123456'),
      );
      await pumpScreen(
        t,
        screen: const SuppliersScreen(),
        directory: directory,
        admin: admin,
        picker: picker,
      );
      await t.tap(find.text('رعوي جديد'));
      await t.pumpAndSettle();
      await t.tap(find.text('جلب من جهات الاتصال'));
      await t.pumpAndSettle();

      expect(picker.opens, 1);
      expect(find.text('صالح'), findsOneWidget);
      expect(find.text('0777123456'), findsOneWidget);
    });

    testWidgets('⛔ ولا يظهر الزر بلا مُنتقٍ — والإدخال اليدوي باقٍ',
        (WidgetTester t) async {
      directory
        ..emitSuppliers(<SupplierCard>[])
        ..emitSources(<SourceCard>[testSource()]);
      await pumpScreen(
        t,
        screen: const SuppliersScreen(),
        directory: directory,
        admin: admin,
      );
      await t.tap(find.text('رعوي جديد'));
      await t.pumpAndSettle();
      expect(find.text('جلب من جهات الاتصال'), findsNothing);
      expect(find.text('اسم الرعوي'), findsOneWidget);
    });

    // ⛔⛔★★★ **واستُبدل اختبار «المصدر المختار يُرسَل» بـ`CR-006`**
    //    (2026-08-31) — ★ **ونقيضُه هو المطلوب الآن:** ⟵ **لا مُنتقيَ
    //    مصادرَ في النموذج، ورعويٌّ بلا مصدرٍ يُقبَل** ⛔ **ولا يُرفَض.**
    testWidgets('⛔★★★ ولا مُنتقيَ مصادرَ — ورعويٌّ يُنشأ بلا مصدر (CR-006)',
        (WidgetTester t) async {
      directory
        ..emitSuppliers(<SupplierCard>[])
        ..emitSources(<SourceCard>[testSource(name: 'رداع')]);
      await pumpScreen(
        t,
        screen: const SuppliersScreen(),
        directory: directory,
        admin: admin,
      );
      await t.tap(find.text('رعوي جديد'));
      await t.pumpAndSettle();

      // ⛔⛔ **ولا شريحةَ مصدرٍ واحدة في الورقة** — ★ **والمصدر «رداع» مُعلَنٌ
      //    في الدليل**، ⟵ **فظهورُه هنا كان يعني بقاء المُنتقي.**
      expect(find.widgetWithText(FilterChip, 'رداع'), findsNothing);

      await t.enterText(find.widgetWithText(TextField, 'اسم الرعوي'), 'صالح');
      await t.enterText(
        find.widgetWithText(TextField, 'رقم الهاتف'),
        '0777123456',
      );
      await t.tap(find.text('إنشاء'));
      await t.pumpAndSettle();

      // ✅ **يُقبَل بلا مصدر** — `CR-006`.
      expect(admin.calls, 1);
      // ★ **الهاتف مُطبَّع من طبقة النطاق** — `IQ-014`.
      expect(admin.lastSupplier?.normalizedPhone, '777123456');
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // المقاوته — FR-M4
  // ═══════════════════════════════════════════════════════════════════

  group('★ المقاوته — FR-M4', () {
    testWidgets('⛔★★ FR-M4-04: لا حقل مصدر في نموذج المقوت إطلاقاً',
        (WidgetTester t) async {
      directory
        ..emitDealers(<DealerCard>[])
        ..emitSources(<SourceCard>[testSource(name: 'رداع')]);
      await pumpScreen(
        t,
        screen: const DealersScreen(),
        directory: directory,
        admin: admin,
      );
      await t.tap(find.text('مقوت جديد'));
      await t.pumpAndSettle();
      // ⛔ لا منتقي مصادر ولا حبّة مصدر.
      expect(find.text('المصادر'), findsNothing);
      expect(find.byType(FilterChip), findsNothing);
    });

    testWidgets('★★ FR-M4-09: الإقرار يُرسَل عند التعطيل', (WidgetTester t) async {
      directory
        ..emitDealers(<DealerCard>[testDealer()])
        ..emitSources(<SourceCard>[testSource()]);
      await pumpScreen(
        t,
        screen: const DealersScreen(),
        directory: directory,
        admin: admin,
      );
      await t.tap(find.byIcon(Icons.edit_outlined));
      await t.pumpAndSettle();
      // تعطيل ⟵ يظهر حقلا السبب والإقرار.
      await t.tap(find.byType(SwitchListTile));
      await t.pumpAndSettle();
      await t.enterText(
        find.widgetWithText(TextField, 'سبب التعطيل'),
        'ترك العمل',
      );
      await t.enterText(
        find.widgetWithText(
          TextField,
          'إقرار التعطيل رغم الرصيد (إن وُجد رصيد)',
        ),
        'أقرّ بالمتابعة',
      );
      await t.enterText(
        find.widgetWithText(TextField, 'سبب التعديل (اختياري)'),
        'طلب المالك',
      );
      await t.tap(find.text('حفظ التعديل'));
      await t.pumpAndSettle();

      expect(admin.lastBalanceAcknowledgement, 'أقرّ بالمتابعة');
      expect(admin.lastAmendReason, 'طلب المالك');
      expect(admin.lastDealer?.isActive, isFalse);
    });

    testWidgets('★ ولا يظهر حقل الإقرار على مقوتٍ يبقى نشطاً',
        (WidgetTester t) async {
      directory
        ..emitDealers(<DealerCard>[testDealer()])
        ..emitSources(<SourceCard>[testSource()]);
      await pumpScreen(
        t,
        screen: const DealersScreen(),
        directory: directory,
        admin: admin,
      );
      await t.tap(find.byIcon(Icons.edit_outlined));
      await t.pumpAndSettle();
      expect(
        find.widgetWithText(
          TextField,
          'إقرار التعطيل رغم الرصيد (إن وُجد رصيد)',
        ),
        findsNothing,
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // الأنواع — FR-M5
  // ═══════════════════════════════════════════════════════════════════

  group('★ الأنواع — FR-M5', () {
    testWidgets('★★ FR-M5-05: «السكرب» بعلامة 🔒 ⛔ ولا زر تعديل له',
        (WidgetTester t) async {
      directory.emitItems(<ItemCard>[
        testItem(
          itemId: 'ITM-0001',
          name: scrapItemName,
          nature: ItemNature.weightBased,
          unit: ItemUnit.kilogram,
          isSystemDefault: true,
        ),
        testItem(),
      ]);
      await pumpScreen(
        t,
        screen: const ItemsScreen(),
        directory: directory,
        admin: admin,
      );
      expect(find.text('افتراضي'), findsOneWidget);
      // ★ نوعٌ واحد قابل للتعديل — ⛔ والسكرب ليس منها.
      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
      expect(find.text('وزني · كيلوجرام'), findsOneWidget);
    });

    testWidgets('★★ FR-M5-02 · E-09: وزن الحبة يظهر للوزني ويختفي للعددي',
        (WidgetTester t) async {
      directory
        ..emitItems(<ItemCard>[])
        ..emitSources(<SourceCard>[testSource(name: 'رداع')]);
      await pumpScreen(
        t,
        screen: const ItemsScreen(),
        directory: directory,
        admin: admin,
      );
      await t.tap(find.text('نوع جديد'));
      await t.pumpAndSettle();
      // العددي هو الافتراضي ⟵ لا حقل وزن حبة.
      expect(
        find.widgetWithText(TextField, 'وزن الحبة بالجرام (اختياري)'),
        findsNothing,
      );
      await t.tap(find.text('وزني'));
      await t.pumpAndSettle();
      expect(
        find.widgetWithText(TextField, 'وزن الحبة بالجرام (اختياري)'),
        findsOneWidget,
      );
    });

    testWidgets('⛔★★ FR-M5-09: لا حقل سعر في نموذج النوع إطلاقاً',
        (WidgetTester t) async {
      directory
        ..emitItems(<ItemCard>[])
        ..emitSources(<SourceCard>[testSource()]);
      await pumpScreen(
        t,
        screen: const ItemsScreen(),
        directory: directory,
        admin: admin,
      );
      await t.tap(find.text('نوع جديد'));
      await t.pumpAndSettle();
      for (final String forbidden in <String>['سعر', 'السعر', 'الحد الأدنى']) {
        expect(
          find.textContaining(forbidden),
          findsNothing,
          reason: 'ظهر نصّ «$forbidden» في نموذج النوع',
        );
      }
    });

    testWidgets('★★ FR-M5-03: وحدة نوع المستخدم «حبة» دائماً — ⛔ ولا حقل لها',
        (WidgetTester t) async {
      directory
        ..emitItems(<ItemCard>[])
        ..emitSources(<SourceCard>[testSource(name: 'رداع')]);
      await pumpScreen(
        t,
        screen: const ItemsScreen(),
        directory: directory,
        admin: admin,
      );
      await t.tap(find.text('نوع جديد'));
      await t.pumpAndSettle();
      await t.enterText(find.widgetWithText(TextField, 'اسم النوع'), 'عود');
      await t.tap(find.widgetWithText(FilterChip, 'رداع'));
      await t.pump();
      // ★ ويختار الوزني — ⟵ **والوحدة تبقى «حبة»** لأنها مشتقّة لا مُدخَلة.
      await t.tap(find.text('وزني'));
      await t.pumpAndSettle();
      await t.tap(find.text('إنشاء'));
      await t.pumpAndSettle();

      expect(admin.lastItem?.unit, ItemUnit.piece);
      expect(admin.lastItem?.isSystemDefault, isFalse);
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // ⛔⛔★★★ AM-008 ⑥ — زرُّ التعديل في صفّ الاسم نفسِه
  // ═══════════════════════════════════════════════════════════════════

  group('⛔⛔★★★ AM-008 ⑥ — الإجراء في صفّ الاسم لا في صفٍّ لوحده', () {
    testWidgets('★ المصادر والمقاوته والرعية — ثلاثتُها بلا فاصلٍ ولا صفٍّ ثانٍ',
        (WidgetTester tester) async {
      final List<(Widget, void Function(FakeMasterDataDirectory))> screens =
          <(Widget, void Function(FakeMasterDataDirectory))>[
        (
          const SourcesScreen(),
          (FakeMasterDataDirectory d) => d.emitSources(<SourceCard>[testSource()]),
        ),
        (
          const DealersScreen(),
          (FakeMasterDataDirectory d) => d.emitDealers(<DealerCard>[testDealer()]),
        ),
        (
          const SuppliersScreen(),
          (FakeMasterDataDirectory d) => d.emitSuppliers(<SupplierCard>[
                const SupplierCard(
                  supplierId: 'SUP-0001',
                  name: 'رعوي مثال',
                  phone: '777111222',
                  isActive: true,
                ),
              ]),
        ),
      ];

      for (final (Widget screen, void Function(FakeMasterDataDirectory) seed)
          in screens) {
        final FakeMasterDataDirectory directory = FakeMasterDataDirectory();
        seed(directory);
        await pumpScreen(
          tester,
          screen: screen,
          directory: directory,
          admin: FakeMasterDataAdmin(),
        );

        // ★ **الزرُّ أيقونيٌّ بوصفٍ دلالي** — ⛔ **لا رمزٌ صامت.**
        expect(find.byTooltip('تعديل'), findsOneWidget,
            reason: screen.runtimeType.toString());
        // ⛔⛔ **ولا فاصلَ شعري في البطاقة** — ★ **وهو ما كان يفصل صفَّ
        //    الإجراء عن الاسم** (`AM-008` ⑥).
        expect(
          find.descendant(
            of: find.byType(EntityTile),
            matching: find.byType(Divider),
          ),
          findsNothing,
          reason: screen.runtimeType.toString(),
        );
        directory.dispose();
      }
    });

    testWidgets('⛔★★ ولا «عددُ مصادر» في بطاقة الرعوي بعد CR-006',
        (WidgetTester tester) async {
      final FakeMasterDataDirectory directory = FakeMasterDataDirectory()
        ..emitSuppliers(<SupplierCard>[
          const SupplierCard(
            supplierId: 'SUP-0001',
            name: 'رعوي مثال',
            phone: '777111222',
            isActive: true,
          ),
        ]);
      await pumpScreen(
        tester,
        screen: const SuppliersScreen(),
        directory: directory,
        admin: FakeMasterDataAdmin(),
      );

      // ★ **السطر الثانوي هاتفُه وحده** — ⛔ **ولا رقمٌ ثابتٌ في كل بطاقة.**
      expect(find.text('777111222'), findsOneWidget);
      expect(find.textContaining('مصدر'), findsNothing);
      directory.dispose();
    });
  });
}

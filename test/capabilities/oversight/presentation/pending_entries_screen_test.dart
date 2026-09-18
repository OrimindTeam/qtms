/// شاشة مركز الإدخالات المعلّقة — `WU-009` (`FR-SYS-01` … `FR-SYS-10`).
///
/// ⚠️⚠️ **وما تُثبته هذه الاختبارات وما لا تُثبته:** تُثبت أن **الشاشة تعرض
/// العنوان المقروء والقيمة الناقصة والتاريخ**، وأن **الفلتر يصل الدليل كما
/// اختاره المستخدم بمصدرٍ إلزامي**، وأن **الرفض يظهر خطأً لا فراغاً**، وأن
/// **زر [ إدخال ] يفتح الشاشة الأصلية بسياقها** ⛔ **ولا نموذجَ إدخالٍ فيها**،
/// وأن **العدّاد الحيّ في الصدَفة يُجمَع من كل مصادر النطاق**.
///
/// ⛔⛔ **ولا تُثبت أن البنود تُكتب وتُمحى صحيحاً** — ★ **ذاك في طبقة النطاق**
/// (`pending_entry_builder_test.dart`) **وفي السحابة** (`pending_entries_test
/// .dart`)، **وحمايتُه في `firestore.rules` مُختبَرةٌ على المحاكي.**
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:qtms/app/router.dart';
import 'package:qtms/capabilities/identity_access/application/session_providers.dart';
import 'package:qtms/capabilities/inventory/application/inventory_providers.dart';
import 'package:qtms/capabilities/master_data/application/master_data_providers.dart';
import 'package:qtms/capabilities/oversight/application/pending_entries_providers.dart';
import 'package:qtms/capabilities/oversight/presentation/pending_entries_screen.dart';
import 'package:qtms_domain/qtms_domain.dart';

import '../../../support/fake_identity.dart';
import '../../../support/fake_master_data.dart';
import '../../../support/fake_pending_entries.dart';

late FakePendingEntryDirectory pending;
late FakeMasterDataDirectory masterData;
late ProviderContainer container;

/// ★ موجّهٌ اختباري بمساراتِ الوجهات الثلاث — ⟵ **فتُقاس الملاحة فعلاً**،
/// ⛔ **ولا يُكتفى بأن الزرّ موجود.**
GoRouter buildRouter() => GoRouter(
      initialLocation: pendingEntriesRoute,
      routes: <RouteBase>[
        GoRoute(
          path: pendingEntriesRoute,
          builder: (BuildContext context, GoRouterState state) =>
              const PendingEntriesScreen(),
        ),
        for (final String route in <String>[
          supplyIntakeRoute,
          dailyPricingRoute,
          distributionRoute,
        ])
          GoRoute(
            path: route,
            builder: (BuildContext context, GoRouterState state) =>
                Scaffold(body: Text('وجهة: $route')),
          ),
      ],
    );

Future<void> pumpScreen(WidgetTester tester) async {
  final FakeAuthRepository auth = FakeAuthRepository();
  final FakeUserCardRepository cards = FakeUserCardRepository();
  auth.emitIdentity(
    const AuthenticatedIdentity(userId: 'U-001', sourceScope: AllSources()),
  );
  cards.emitCard('U-001', testCard(permissions: const <Permission>{}));

  container = ProviderContainer(overrides: [
    authRepositoryProvider.overrideWithValue(auth),
    userCardRepositoryProvider.overrideWithValue(cards),
    masterDataDirectoryProvider.overrideWithValue(masterData),
    masterDataAdminProvider.overrideWithValue(FakeMasterDataAdmin()),
    contactPickerProvider.overrideWithValue(null),
    pendingEntryDirectoryProvider.overrideWithValue(pending),
  ]);
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        locale: const Locale('ar'),
        routerConfig: buildRouter(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 20));
}

void main() {
  setUp(() {
    pending = FakePendingEntryDirectory();
    masterData = FakeMasterDataDirectory();
    masterData.emitSources(<SourceCard>[
      SourceCard(
        sourceId: 'SRC-001',
        name: 'رداع',
        isActive: true,
        requiresSupplierOnIntake: true,
      ),
      SourceCard(
        sourceId: 'SRC-002',
        name: 'ماوية',
        isActive: true,
        requiresSupplierOnIntake: true,
      ),
    ]);
  });

  group('العرض — FR-SYS-03: القيمة الناقصة مقروءة', () {
    testWidgets('★★ العنوان المقروء والقيمة الناقصة والتاريخ معاً', (
      WidgetTester tester,
    ) async {
      pending.emit('SRC-001', <PendingEntryCard>[testPendingEntry()]);
      await pumpScreen(tester);

      expect(find.text('عبد الفتاح - جونية رقم ١'), findsOneWidget);
      expect(find.text('ضريبة الكيلو'), findsOneWidget);
      expect(find.textContaining('SCK-20260830-0001'), findsWidgets);
    });

    testWidgets('⛔⛔★★★ FR-SYS-06: الشاشة تُعلن أنها تذكّر ولا تمنع', (
      WidgetTester tester,
    ) async {
      pending.emit('SRC-001', <PendingEntryCard>[testPendingEntry()]);
      await pumpScreen(tester);

      expect(find.textContaining('تذكّر ولا تمنع'), findsOneWidget);
    });

    testWidgets('★★ ولا قيمة معلّقة ⟵ حالةٌ مصمَّمة بسببٍ وخطوةٍ تالية', (
      WidgetTester tester,
    ) async {
      pending.emit('SRC-001', const <PendingEntryCard>[]);
      await pumpScreen(tester);

      expect(find.text('لا قيمة معلّقة في هذا المصدر'), findsOneWidget);
      expect(find.textContaining('ستظهر في هذه الشاشة'), findsOneWidget);
    });

    testWidgets('★★ والرفض يظهر خطأً لا فراغاً', (WidgetTester tester) async {
      pending.emitError('SRC-001', StateError('permission-denied'));
      await pumpScreen(tester);
      await tester.pump(const Duration(milliseconds: 20));

      expect(find.text('تعذّر عرض البيانات'), findsOneWidget);
    });

    testWidgets('★★ وبندٌ من إصدارٍ أحدث يُعرَض ولا يُفتَح', (
      WidgetTester tester,
    ) async {
      pending.emit('SRC-001', <PendingEntryCard>[
        testPendingEntry(kind: null, field: null, missingField: 'قيمة جديدة'),
      ]);
      await pumpScreen(tester);

      expect(find.text('قيمة جديدة'), findsOneWidget);
      expect(find.text('إدخال'), findsNothing);
      expect(find.textContaining('حدِّث التطبيق'), findsOneWidget);
    });
  });

  group('الفلتر — FR-SYS-10 · FR-SYS-07', () {
    testWidgets('⛔⛔★★★ المصدر إلزاميٌّ في أول استعلام — ولا «كل المصادر»', (
      WidgetTester tester,
    ) async {
      pending.emit('SRC-001', <PendingEntryCard>[testPendingEntry()]);
      await pumpScreen(tester);

      expect(pending.lastFilter?.sourceId, 'SRC-001');
      expect(find.text('كل المصادر'), findsNothing);
    });

    testWidgets('★★ وتبديل المصدر يصل الدليل كما اختاره المستخدم', (
      WidgetTester tester,
    ) async {
      pending.emit('SRC-001', <PendingEntryCard>[testPendingEntry()]);
      pending.emit('SRC-002', const <PendingEntryCard>[]);
      await pumpScreen(tester);

      await tester.tap(find.text('ماوية'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));

      expect(pending.lastFilter?.sourceId, 'SRC-002');
    });

    testWidgets('★★ وفلترُ النوع يُقصي ما سواه', (WidgetTester tester) async {
      pending.emit('SRC-001', <PendingEntryCard>[
        testPendingEntry(),
        testPendingEntry(
          id: 'distribution_X_distributionLinePricing',
          kind: PendingDocumentKind.distribution,
          documentId: 'MQT-1_SRC-001_20260830',
          readableTitle: 'توزيعة أبو أحمد',
          missingField: 'سعر الوحدة لسطرٍ واحد',
          field: PendingMissingField.distributionLinePricing,
          documentNumber: 'DST-20260830-0001',
        ),
      ]);
      await pumpScreen(tester);
      expect(find.text('توزيعة أبو أحمد'), findsOneWidget);

      await tester.tap(find.text('جونية'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));

      expect(pending.lastFilter?.kind, PendingDocumentKind.sack);
      expect(find.text('توزيعة أبو أحمد'), findsNothing);
      expect(find.text('عبد الفتاح - جونية رقم ١'), findsOneWidget);
    });

    testWidgets('★★ والحدّ يصل الدليل — ⛔ ولا قراءةَ بلا حدّ', (
      WidgetTester tester,
    ) async {
      pending.emit('SRC-001', <PendingEntryCard>[testPendingEntry()]);
      await pumpScreen(tester);

      expect(pending.lastLimit, pendingEntriesPageSize);
    });
  });

  group('زر [ إدخال ] — FR-SYS-04', () {
    testWidgets('★★★ بندُ جونيةٍ يفتح شاشة الجواني بمصدره', (
      WidgetTester tester,
    ) async {
      pending.emit('SRC-002', <PendingEntryCard>[
        testPendingEntry(sourceId: 'SRC-002'),
      ]);
      pending.emit('SRC-001', const <PendingEntryCard>[]);
      await pumpScreen(tester);

      await tester.tap(find.text('ماوية'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      await tester.tap(find.text('إدخال'));
      await tester.pumpAndSettle();

      // ★★★ **والجونيةُ تبويبٌ في «التوريد مخزني» منذ `AM-012` §2.**
      expect(find.text('وجهة: $supplyIntakeRoute'), findsOneWidget);
      expect(container.read(selectedSourceProvider), 'SRC-002');
    });

    testWidgets('★★★ وبندُ تسعيرٍ يفتح التسعير على «لم يُسعَّر»', (
      WidgetTester tester,
    ) async {
      pending.emit('SRC-001', <PendingEntryCard>[
        testPendingEntry(
          id: 'dailyPrice_SRC-001_ITM-1_20260830_itemPricing',
          kind: PendingDocumentKind.dailyPrice,
          documentId: 'SRC-001_ITM-1_20260830',
          readableTitle: 'قات بلدي',
          missingField: 'سعر التوزيع والحد الأدنى',
          field: PendingMissingField.itemPricing,
          documentNumber: null,
        ),
      ]);
      await pumpScreen(tester);

      await tester.tap(find.text('إدخال'));
      await tester.pumpAndSettle();

      expect(find.text('وجهة: $dailyPricingRoute'), findsOneWidget);
      expect(
        container.read(pricingFilterProvider),
        PricingStatusFilter.unpriced,
      );
    });

    testWidgets('★★★ وبندُ توزيعةٍ يحمل المقوت في وجهته', (
      WidgetTester tester,
    ) async {
      pending.emit('SRC-001', <PendingEntryCard>[
        testPendingEntry(
          id: 'distribution_MQT-0001_SRC-001_20260830_distributionLinePricing',
          kind: PendingDocumentKind.distribution,
          documentId: 'MQT-0001_SRC-001_20260830',
          readableTitle: 'توزيعة أبو أحمد',
          missingField: 'سعر الوحدة لسطرٍ واحد',
          field: PendingMissingField.distributionLinePricing,
          documentNumber: 'DST-20260830-0001',
        ),
      ]);
      await pumpScreen(tester);

      await tester.tap(find.text('إدخال'));
      await tester.pumpAndSettle();

      expect(find.text('وجهة: $distributionRoute'), findsOneWidget);
      expect(container.read(pendingFocusProvider)?.dealerId, 'MQT-0001');
    });
  });

  group('العدّاد الحيّ — FR-SYS-03 الموضع الرابع', () {
    testWidgets('★★★ يُجمَع من كل مصادر النطاق لا من مصدرٍ واحد', (
      WidgetTester tester,
    ) async {
      pending.emit('SRC-001', <PendingEntryCard>[testPendingEntry()]);
      pending.emit('SRC-002', <PendingEntryCard>[
        testPendingEntry(id: 'a', sourceId: 'SRC-002'),
        testPendingEntry(id: 'b', sourceId: 'SRC-002'),
      ]);
      await pumpScreen(tester);
      // ★ **الاشتراك يبدأ بالمراقبة لا بالقراءة** — ⟵ **فالتدفّقات تُفتَح
      //   ثم تُبثّ قيمُها**، ⛔ **وقراءةٌ لحظية تلتقط «قيد التحميل».**
      container.listen<AsyncValue<int>>(
        pendingEntriesCountProvider,
        (AsyncValue<int>? previous, AsyncValue<int> next) {},
      );
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pump(const Duration(milliseconds: 20));

      expect(container.read(pendingEntriesCountProvider).value, 3);
    });

    testWidgets('⛔★★ ورفضُ مصدرٍ واحد يجعل العدّاد خطأً لا رقماً ناقصاً', (
      WidgetTester tester,
    ) async {
      pending.emit('SRC-001', <PendingEntryCard>[testPendingEntry()]);
      pending.emitError('SRC-002', StateError('permission-denied'));
      await pumpScreen(tester);
      container.listen<AsyncValue<int>>(
        pendingEntriesCountProvider,
        (AsyncValue<int>? previous, AsyncValue<int> next) {},
      );
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pump(const Duration(milliseconds: 20));

      expect(container.read(pendingEntriesCountProvider).hasError, isTrue);
    });
  });

  group('★★★ AM-025 ① — بطاقةٌ واحدةٌ لكلِّ مستند (§13)', () {
    /// ★ بندان لِجونيةٍ واحدة — **وهو ما رصدته المراجعة بلقطةٍ فعلية.**
    List<PendingEntryCard> twoOnOneSack() => <PendingEntryCard>[
          testPendingEntry(),
          testPendingEntry(
            id: 'sack_SCK-20260830-0001_sackLostWeight',
            missingField: 'الوزن الضائع لم يُؤكَّد',
            field: PendingMissingField.sackLostWeight,
          ),
        ];

    testWidgets(
        '⛔⛔★★★ بندان لنفس المستند ⟵ بطاقةٌ واحدة بعنوانٍ واحد وشارتين', (
      WidgetTester tester,
    ) async {
      pending.emit('SRC-001', twoOnOneSack());
      await pumpScreen(tester);

      // ① ★ **العنوانُ ورقمُ المستند مرةً واحدة** — ⛔ لا بطاقتان متطابقتان.
      expect(
        find.text('عبد الفتاح - جونية رقم ١'),
        findsOneWidget,
        reason: '★ بطاقةٌ واحدةٌ للمستند لا بطاقةٌ لكلِّ قيمةٍ ناقصة',
      );
      // ② ★★ **وشارةٌ لكلِّ قيمةٍ ناقصة** — ⛔ ولا تسقط واحدةٌ منها.
      expect(find.text('ضريبة الكيلو'), findsOneWidget);
      expect(find.text('الوزن الضائع لم يُؤكَّد'), findsOneWidget);
      // ③ ★ **وزرُّ [ إدخال ] واحد** — ⛔ لا زرٌّ لكلِّ شارة.
      expect(find.text('إدخال'), findsOneWidget);
    });

    testWidgets('★★ ومستندان مختلفان يبقيان بطاقتين — ⛔ ولا يُجمَعان', (
      WidgetTester tester,
    ) async {
      pending.emit('SRC-001', <PendingEntryCard>[
        testPendingEntry(),
        testPendingEntry(
          id: 'sack_SCK-20260830-0002_sackTax',
          documentId: 'SCK-20260830-0002',
          documentNumber: 'SCK-20260830-0002',
          readableTitle: 'سالم - جونية رقم ٢',
        ),
      ]);
      await pumpScreen(tester);

      expect(find.text('عبد الفتاح - جونية رقم ١'), findsOneWidget);
      expect(find.text('سالم - جونية رقم ٢'), findsOneWidget);
      expect(find.text('إدخال'), findsNWidgets(2));
    });

    testWidgets(
        '⛔⛔★★ ومعرّفان متطابقان من نوعين مختلفين لا يُجمَعان — بطاقتان', (
      WidgetTester tester,
    ) async {
      pending.emit('SRC-001', <PendingEntryCard>[
        testPendingEntry(documentId: 'X-1', documentNumber: null),
        testPendingEntry(
          id: 'distribution_X-1_unitPrice',
          kind: PendingDocumentKind.distribution,
          documentId: 'X-1',
          documentNumber: null,
          readableTitle: 'توزيعة سالم',
          missingField: 'سعر وحدة السطر',
          field: PendingMissingField.distributionLinePricing,
        ),
      ]);
      await pumpScreen(tester);

      expect(find.text('عبد الفتاح - جونية رقم ١'), findsOneWidget);
      expect(find.text('توزيعة سالم'), findsOneWidget);
    });

    testWidgets('★★ وزرُّ المجموعة يفتح وجهةَ أوّلِ بندٍ يملك وجهةً صالحة', (
      WidgetTester tester,
    ) async {
      pending.emit('SRC-001', <PendingEntryCard>[
        // ⛔ **حقلٌ لا يعرفه هذا الإصدار أولاً** — ★ **من نوعٍ معروف**،
        //    ⟵ **فهو في المجموعة نفسِها** ⛔ **ولا وجهةَ له وحدَه.**
        testPendingEntry(
          id: 'sack_SCK-20260830-0001_unknown',
          field: null,
          missingField: 'قيمة جديدة',
        ),
        testPendingEntry(),
      ]);
      await pumpScreen(tester);

      // ★ **بطاقةٌ واحدة بشارتين ولا يختفي المجهول** (`GR-50`).
      expect(find.text('عبد الفتاح - جونية رقم ١'), findsOneWidget);
      expect(find.text('قيمة جديدة'), findsOneWidget);
      expect(find.text('ضريبة الكيلو'), findsOneWidget);
      expect(find.text('إدخال'), findsOneWidget);

      await tester.tap(find.text('إدخال'));
      await tester.pumpAndSettle();
      expect(find.text('وجهة: $supplyIntakeRoute'), findsOneWidget);
    });

    testWidgets('⛔★★ ومجموعةٌ بلا وجهةٍ إطلاقاً تُعرَض ولا تُفتَح', (
      WidgetTester tester,
    ) async {
      pending.emit('SRC-001', <PendingEntryCard>[
        testPendingEntry(
          id: 'sack_SCK-20260830-0001_a',
          kind: null,
          field: null,
          missingField: 'قيمة جديدة أ',
        ),
        testPendingEntry(
          id: 'sack_SCK-20260830-0001_b',
          kind: null,
          field: null,
          missingField: 'قيمة جديدة ب',
        ),
      ]);
      await pumpScreen(tester);

      expect(find.text('قيمة جديدة أ'), findsOneWidget);
      expect(find.text('قيمة جديدة ب'), findsOneWidget);
      expect(find.text('إدخال'), findsNothing);
      expect(find.textContaining('حدِّث التطبيق'), findsOneWidget);
    });

    testWidgets('⛔⛔★★★ والعدّادُ يبقى عددَ القيم لا عددَ المستندات', (
      WidgetTester tester,
    ) async {
      pending.emit('SRC-001', twoOnOneSack());
      pending.emit('SRC-002', const <PendingEntryCard>[]);
      await pumpScreen(tester);
      container.listen<AsyncValue<int>>(
        pendingEntriesCountProvider,
        (AsyncValue<int>? previous, AsyncValue<int> next) {},
      );
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pump(const Duration(milliseconds: 20));

      expect(
        container.read(pendingEntriesCountProvider).value,
        2,
        reason: '★ التجميعُ عرضٌ في الشاشة ⛔ لا تغييرٌ في السجلّ ولا العدّاد',
      );
    });
  });
}

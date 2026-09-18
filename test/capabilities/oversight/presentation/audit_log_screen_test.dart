/// شاشة سجل التدقيق والسجل السياقي — `WU-008` (`M18`).
///
/// ⚠️⚠️ **وما تُثبته هذه الاختبارات وما لا تُثبته:** تُثبت أن **الشاشة تعرض
/// الصيغة الموحّدة** (فعل · مستخدم · وقت · حقل · قبل/بعد · سبب)، وأن
/// **الفلتر يصل الدليل كما اختاره المستخدم**، وأن **الرفض يظهر خطأً لا
/// فراغاً**، وأن **أيقونة 🕘 تختفي بلا صلاحية وتفتح سجل الكيان الصحيح**.
///
/// ⛔⛔ **ولا تُثبت أن السجل محميّ من التعديل والحذف** — ★ **ذاك في
/// `firestore.rules` ومُختبَرٌ على المحاكي** (`test/security-rules/`)،
/// **والعقد نفسه بلا كاتب** (`audit_log_repository_test.dart`).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qtms/capabilities/identity_access/application/session_providers.dart';
import 'package:qtms/capabilities/master_data/application/master_data_providers.dart';
import 'package:qtms/capabilities/master_data/presentation/sources_screen.dart';
import 'package:qtms/capabilities/oversight/application/audit_log_providers.dart';
import 'package:qtms/capabilities/oversight/presentation/audit_log_screen.dart';
import 'package:qtms_domain/qtms_domain.dart';

import '../../../support/fake_identity.dart';
import '../../../support/fake_master_data.dart';
import '../../../support/fake_oversight.dart';

late FakeAuditLogDirectory auditLog;
late FakeMasterDataDirectory masterData;

/// ★ الصلاحيات الافتراضية — **صاحب الشاشة المركزية**.
const Set<Permission> centralViewer = <Permission>{
  Permission.auditLogViewCentral,
};

Future<void> pumpScreen(
  WidgetTester tester,
  Widget screen, {
  Set<Permission> actorPermissions = centralViewer,
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
        auditLogDirectoryProvider.overrideWithValue(auditLog),
      ],
      child: MaterialApp(locale: const Locale('ar'), home: screen),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 20));
}

void main() {
  setUp(() {
    auditLog = FakeAuditLogDirectory();
    masterData = FakeMasterDataDirectory();
    masterData.emitSources(<SourceCard>[
      SourceCard(
        sourceId: 'SRC-001',
        name: 'رداع',
        requiresSupplierOnIntake: false,
        isActive: true,
      ),
      SourceCard(
        sourceId: 'SRC-002',
        name: 'ماوية',
        requiresSupplierOnIntake: false,
        isActive: true,
      ),
    ]);
  });

  group('★★ الشاشة المركزية — FR-M18-09', () {
    testWidgets('★ تعرض الصيغة الموحّدة: فعل · مستخدم · وقت · حقل · سبب',
        (WidgetTester tester) async {
      auditLog.emitCentral(<AuditLogEntryCard>[
        testAuditEntry(
          before: <String, Object?>{'quantity': 100},
          after: <String, Object?>{'quantity': 95},
          reason: 'خطأ في العدّ',
        ),
      ]);
      await pumpScreen(tester, const AuditLogScreen());

      // ① الفعل بنصّه — ⛔ لا بلونٍ وحده.
      expect(find.text('تعديل'), findsWidgets);
      // ② المستخدم مُثبَّتاً وقت الحدث.
      expect(find.text('عبدالفتاح'), findsOneWidget);
      // ③ الوقت — **بتوقيت النظام (UTC)** كما كُتب.
      expect(find.text('2026/08/27 09:15'), findsOneWidget);
      // ④ الحقل بقيمتيه — ★ **باسمه العربي** لا بمفتاحه.
      expect(find.text('الكمية:'), findsOneWidget);
      expect(find.text('100'), findsOneWidget);
      expect(find.text('95'), findsOneWidget);
      // ⑤ السبب — `FR-M18-07`.
      expect(find.text('السبب: خطأ في العدّ'), findsOneWidget);
    });

    testWidgets('★★ وتُعلن أن السجل للإضافة فقط — FR-M18-01',
        (WidgetTester tester) async {
      auditLog.emitCentral(<AuditLogEntryCard>[testAuditEntry()]);
      await pumpScreen(tester, const AuditLogScreen());
      expect(
        find.textContaining('للإضافة فقط'),
        findsOneWidget,
        reason: '★ من يعلم أن أثره باقٍ لا يُمحى يتصرّف بحسبه',
      );
    });

    testWidgets('⛔⛔★★★ والمصدر مُقيَّدٌ في كل استعلام — ولو بلا اختيارٍ من المستخدم',
        (WidgetTester tester) async {
      // ★★ **مقيسٌ على المحاكي:** استعلامٌ بلا `sourceId` **يُرفَض كاملاً**
      //    ⟵ **فالشاشة تبدأ بأول مصدرٍ في النطاق** ⛔ **لا بلا فلتر.**
      auditLog.emitCentral(<AuditLogEntryCard>[testAuditEntry()]);
      await pumpScreen(tester, const AuditLogScreen());
      expect(auditLog.lastFilter?.sourceId, 'SRC-001');
    });

    testWidgets('★ والفلتر يصل الدليل بما اختاره المستخدم لا بثابت',
        (WidgetTester tester) async {
      auditLog.emitCentral(<AuditLogEntryCard>[testAuditEntry()]);
      await pumpScreen(tester, const AuditLogScreen());

      await tester.tap(find.widgetWithText(ChoiceChip, 'إلغاء'));
      await tester.pump();

      expect(auditLog.lastFilter?.dimension, AuditFilterDimension.action);
      expect(auditLog.lastFilter?.action, AuditAction.cancel);
      expect(
        auditLog.lastFilter?.sourceId,
        'SRC-001',
        reason: '★ والمصدر يبقى مُقيَّداً مع البُعد الثانوي',
      );
    });

    testWidgets('★★ وتبديل المصدر يُبقي البُعد الثانوي ويُغيّر المصدر وحده',
        (WidgetTester tester) async {
      auditLog.emitCentral(<AuditLogEntryCard>[testAuditEntry()]);
      await pumpScreen(tester, const AuditLogScreen());

      await tester.tap(find.widgetWithText(ChoiceChip, 'إلغاء'));
      await tester.pump();
      await tester.tap(find.widgetWithText(ChoiceChip, 'ماوية'));
      await tester.pump();

      expect(auditLog.lastFilter?.sourceId, 'SRC-002');
      expect(auditLog.lastFilter?.dimension, AuditFilterDimension.action);
    });

    testWidgets('★ و«كل الأفعال» تُلغي البُعد الثانوي وحده',
        (WidgetTester tester) async {
      auditLog.emitCentral(<AuditLogEntryCard>[testAuditEntry()]);
      await pumpScreen(tester, const AuditLogScreen());

      await tester.tap(find.widgetWithText(ChoiceChip, 'إلغاء'));
      await tester.pump();
      await tester.tap(find.widgetWithText(ChoiceChip, 'كل الأفعال'));
      await tester.pump();

      expect(auditLog.lastFilter?.dimension, AuditFilterDimension.none);
      expect(auditLog.lastFilter?.action, isNull);
      expect(auditLog.lastFilter?.sourceId, 'SRC-001');
    });

    testWidgets('★★ وخيار «ما لا يخصّ مصدراً» لصاحب النطاق الشامل وحده',
        (WidgetTester tester) async {
      // ⟵ **قيودُ تغيير الصلاحيات والمستخدمين تُكتب بـ`sourceId = all`**،
      //   ★ **و`inScope('all')` لا تصدُق إلا لمن نطاقه `all`.**
      auditLog.emitCentral(<AuditLogEntryCard>[testAuditEntry()]);
      await pumpScreen(tester, const AuditLogScreen());
      expect(find.widgetWithText(ChoiceChip, 'ما لا يخصّ مصدراً'), findsOneWidget);

      await tester.tap(find.widgetWithText(ChoiceChip, 'ما لا يخصّ مصدراً'));
      await tester.pump();
      expect(auditLog.lastFilter?.sourceId, auditAllSourcesId);
    });

    testWidgets('⛔ والرفض يظهر خطأً لا فراغاً — FR-M18-12',
        (WidgetTester tester) async {
      auditLog.emitCentralError(StateError('permission-denied'));
      await pumpScreen(tester, const AuditLogScreen());
      expect(find.text('تعذّر عرض البيانات'), findsOneWidget);
    });

    testWidgets('★ والسجل لا يُقرأ كاملاً — §8 يفرض حدّاً',
        (WidgetTester tester) async {
      auditLog.emitCentral(<AuditLogEntryCard>[testAuditEntry()]);
      await pumpScreen(tester, const AuditLogScreen());
      expect(auditLog.lastLimit, auditLogPageSize);
    });

    testWidgets('★★ والمصادر المعروضة في الفلتر مصادرُ نطاقه وحدها — GR-23',
        (WidgetTester tester) async {
      masterData.emitSources(<SourceCard>[
        SourceCard(
          sourceId: 'SRC-001',
          name: 'رداع',
          requiresSupplierOnIntake: false,
          isActive: true,
        ),
      ]);
      auditLog.emitCentral(<AuditLogEntryCard>[testAuditEntry()]);
      await pumpScreen(tester, const AuditLogScreen());

      expect(find.widgetWithText(ChoiceChip, 'رداع'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'ماوية'), findsNothing);
    });
  });

  group('★★ عرضُ القيد — حالاتٌ لا تُسقِط الشاشة', () {
    testWidgets('★★ فعلٌ غير معروف يُعرَض ولا يختفي', (WidgetTester tester) async {
      auditLog.emitCentral(<AuditLogEntryCard>[
        testAuditEntry(action: null, reason: null),
      ]);
      await pumpScreen(tester, const AuditLogScreen());
      expect(find.text('إجراء غير معروف'), findsOneWidget);
      expect(find.text('عبدالفتاح'), findsOneWidget);
    });

    testWidgets('★ وغيابُ القيمة نصٌّ صريح لا خانةٌ فارغة',
        (WidgetTester tester) async {
      // ⚠️★★ **والفعلُ «تعديل» لا «إنشاء» منذ `AM-012` §3.1** — ★ **والإنشاءُ
      //    صار بلا صفوفٍ إطلاقاً**، ⟵ **وحقلٌ أُضيف في تعديلٍ هو الحالُ
      //    الحقيقيُّ الذي يُنتج «قبل» غائبة** (`AuditFieldChange.before`).
      auditLog.emitCentral(<AuditLogEntryCard>[
        testAuditEntry(
          action: AuditAction.amend,
          after: <String, Object?>{'quantity': 40},
          reason: null,
        ),
      ]);
      await pumpScreen(tester, const AuditLogScreen());
      expect(find.text('لا قيمة'), findsOneWidget);
      expect(find.text('40'), findsOneWidget);
    });

    testWidgets(
        '⛔⛔★★★ وسهمُ التغيير يتّجه من «قبل» إلى «بعد» — عطلٌ رُصد على المحاكي',
        (WidgetTester tester) async {
      // ★★★ **اختبارُ ارتدادٍ لعطلٍ حقيقي (2026-08-27):** ★ **كلا
      //    `arrow_back` و`arrow_forward` في Material يحملان
      //    `matchTextDirection: true`** — ⟵ **فينقلبان مع RTL**، ⛔ **وكان
      //    `arrow_back` يُرسَم متجهاً يميناً** أي **من «بعد» إلى «قبل»**،
      //    ★ **فيقرأ المدقّق التغيير مقلوباً على مستندٍ مالي.**
      auditLog.emitCentral(<AuditLogEntryCard>[
        testAuditEntry(
          before: <String, Object?>{'quantity': 100},
          after: <String, Object?>{'quantity': 95},
        ),
      ]);
      await pumpScreen(tester, const AuditLogScreen());

      final Icon arrow = tester.widget<Icon>(
        find.byIcon(Icons.arrow_forward),
      );
      expect(
        arrow.icon,
        Icons.arrow_forward,
        reason: '★ «الأمام» في اتجاه القراءة — من «قبل» إلى «بعد»',
      );
      expect(
        find.byIcon(Icons.arrow_back),
        findsNothing,
        reason: '⛔ فالرجوع يُرسَم يميناً في RTL — أي عكس اتجاه التغيير',
      );
    });

    testWidgets('⛔ وشطبُ «قبل» على قيمةٍ كانت وحدها — ولا يُشطَب نفيُ القيمة',
        (WidgetTester tester) async {
      // ⟵ **شطبُ «لا قيمة» يشطب النفيَ لا القيمة** ⛔ **فيُقرأ عكسَ معناه.**
      // ⚠️ **والفعلُ «تعديل» بعد `AM-012` §3.1** — راجع الاختبار أعلاه.
      auditLog.emitCentral(<AuditLogEntryCard>[
        testAuditEntry(
          action: AuditAction.amend,
          after: <String, Object?>{'quantity': 40},
          reason: null,
        ),
      ]);
      await pumpScreen(tester, const AuditLogScreen());

      final Text absent = tester.widget<Text>(find.text('لا قيمة'));
      expect(absent.style?.decoration, TextDecoration.none);
    });

    testWidgets('★★ وتاريخ المخزون يُعرَض متى وُجد — AT-52 · RISK-07',
        (WidgetTester tester) async {
      auditLog.emitCentral(<AuditLogEntryCard>[
        testAuditEntry(stockDate: CalendarDay(2026, 8, 26)),
      ]);
      await pumpScreen(tester, const AuditLogScreen());
      expect(find.textContaining('مخزون 2026/08/26'), findsOneWidget);
    });

    testWidgets(
      '⛔⛔★★★ AM-012 §3.1: الإنشاءُ بلا صفِّ «قبل/بعد» واحد',
      (WidgetTester tester) async {
        auditLog.emitCentral(<AuditLogEntryCard>[
          testAuditEntry(
            action: AuditAction.create,
            after: <String, Object?>{'quantity': 40, 'itemName': 'شامي'},
            reason: null,
          ),
        ]);
        await pumpScreen(tester, const AuditLogScreen());

        // ★ **والقيدُ نفسُه معروضٌ كاملاً** — ⛔ **لم يختفِ.**
        // ⚠️ **و«إنشاء» تظهر مرتين: في حبّة الفعل وفي مرشِّح الأفعال** —
        //    ★ **والمقصودُ هنا وجودُها لا عددُها.**
        expect(find.text('إنشاء'), findsAtLeastNWidgets(1));
        expect(find.text('عبدالفتاح'), findsOneWidget);
        // ⛔⛔ **ولا صفَّ تغيّرٍ واحد.**
        expect(find.text('لا قيمة'), findsNothing);
        expect(find.text('40'), findsNothing);
        expect(find.byIcon(Icons.arrow_forward), findsNothing);
      },
    );

    testWidgets(
      '★★★ AM-012 §3.2: والتعديلُ يعرض ما تغيّر فعلاً وحدَه',
      (WidgetTester tester) async {
        auditLog.emitCentral(<AuditLogEntryCard>[
          testAuditEntry(
            action: AuditAction.amend,
            before: <String, Object?>{'quantity': 100, 'itemName': 'شامي'},
            after: <String, Object?>{'quantity': 95, 'itemName': 'شامي'},
          ),
        ]);
        await pumpScreen(tester, const AuditLogScreen());

        expect(find.text('100'), findsOneWidget);
        expect(find.text('95'), findsOneWidget);
        // ⛔ **والحقلُ الذي لم يتغيّر لا يُعرَض** — ★ **صفٌّ واحد لا صفّان.**
        expect(find.text('شامي'), findsNothing);
        expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
      },
    );

    testWidgets(
      '★★★ AM-012 §3: وبريدُ المُنفِّذ تحت اسمه',
      (WidgetTester tester) async {
        auditLog.emitCentral(<AuditLogEntryCard>[
          testAuditEntry(userEmail: 'owner@qtms.test'),
        ]);
        await pumpScreen(tester, const AuditLogScreen());
        expect(find.text('عبدالفتاح'), findsOneWidget);
        expect(find.text('owner@qtms.test'), findsOneWidget);
      },
    );

    testWidgets(
      '⛔⛔★★★ وغيابُ البريد يُسقِط السطر — ⛔ ولا «لا قيمة» في موضع هوية',
      (WidgetTester tester) async {
        // ★★ **وهي حالُ كل قيدٍ كُتب قبل 2026-09-02** — ⟵ **والسجلُّ للإضافة
        //    فقط ولا يُهاجَر**: ⛔ **فلا يُملأ بأثرٍ رجعي.**
        auditLog.emitCentral(<AuditLogEntryCard>[
          testAuditEntry(userEmail: null),
        ]);
        await pumpScreen(tester, const AuditLogScreen());
        expect(find.text('عبدالفتاح'), findsOneWidget);
        expect(find.text('لا قيمة'), findsNothing);
      },
    );

    testWidgets(
      '★★★ AM-012 §3.3: وسطرُ الهدف «اسم النوع: الرقم»',
      (WidgetTester tester) async {
        auditLog.emitCentral(<AuditLogEntryCard>[
          testAuditEntry(
            entityType: countedIntakeEntityType,
            entityId: 'INC-20260827-0001',
          ),
        ]);
        await pumpScreen(tester, const AuditLogScreen());
        expect(
          find.text('الوارد عدداً: INC-20260827-0001'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      '★★ ونوعٌ آخر باسمه هو — ⛔ لا اسمٌ واحدٌ لكل الكيانات',
      (WidgetTester tester) async {
        auditLog.emitCentral(<AuditLogEntryCard>[
          testAuditEntry(
            entityType: userEntityType,
            entityId: 'U-042',
            stockDate: null,
          ),
        ]);
        await pumpScreen(tester, const AuditLogScreen());
        expect(find.text('المستخدمون: U-042'), findsOneWidget);
      },
    );

    testWidgets(
      '⛔⛔ ونوعٌ لا يعرفه هذا الإصدار يُعرَض بمفتاحه ⛔ ولا يختفي',
      (WidgetTester tester) async {
        // ★ **بنفس علّة «إجراء غير معروف»** — ⟵ **السجلُّ للإضافة فقط.**
        auditLog.emitCentral(<AuditLogEntryCard>[
          testAuditEntry(entityType: 'somethingNew', entityId: 'X-1'),
        ]);
        await pumpScreen(tester, const AuditLogScreen());
        expect(find.textContaining('somethingNew: X-1'), findsOneWidget);
      },
    );

    testWidgets('⛔ والحالة الفارغة بسببٍ وإجراء — §هـ',
        (WidgetTester tester) async {
      auditLog.emitCentral(const <AuditLogEntryCard>[]);
      await pumpScreen(tester, const AuditLogScreen());
      expect(find.text('لا نشاط مُسجَّل'), findsOneWidget);
      expect(find.textContaining('وسّع المدى'), findsOneWidget);
    });
  });

  group('★★★ السجل السياقي — FR-M18-10 · FR-M18-11 · FR-M18-12', () {
    testWidgets('★ أيقونة 🕘 تظهر في صفوف المصادر لمن يملك الصلاحية',
        (WidgetTester tester) async {
      await pumpScreen(tester, const SourcesScreen());
      expect(find.byTooltip('سجل التغييرات'), findsNWidgets(2));
    });

    testWidgets('⛔ وتختفي تماماً بلا صلاحية — «الممنوع لا يظهر أصلاً»',
        (WidgetTester tester) async {
      await pumpScreen(
        tester,
        const SourcesScreen(),
        actorPermissions: const <Permission>{Permission.sourceWrite},
      );
      expect(find.byTooltip('سجل التغييرات'), findsNothing);
    });

    testWidgets('★★ وتظهر لصاحب السياقي وحده — الشرط «أو» لا «و»',
        (WidgetTester tester) async {
      await pumpScreen(
        tester,
        const SourcesScreen(),
        actorPermissions: const <Permission>{
          Permission.auditLogViewContextual,
        },
      );
      expect(find.byTooltip('سجل التغييرات'), findsNWidgets(2));
    });

    testWidgets('★★★ والنقر يفتح سجل الكيان الصحيح — ⛔ لا كياناً آخر',
        (WidgetTester tester) async {
      final AuditEntityRef entity = AuditEntityRef(
        entityType: sourceEntityType,
        entityId: 'SRC-002',
        // ★★ **والمصدر جزءٌ من المفتاح** — ⟵ **فاستعلامٌ بلا قيدٍ عليه
        //    يُرفَض كاملاً** (مقيسٌ على المحاكي).
        sourceId: 'SRC-002',
      );
      auditLog.emitEntity(entity, <AuditLogEntryCard>[
        testAuditEntry(
          entityType: sourceEntityType,
          entityId: 'SRC-002',
          action: AuditAction.create,
          after: <String, Object?>{'name': 'ماوية'},
          reason: null,
        ),
      ]);

      await pumpScreen(tester, const SourcesScreen());
      await tester.tap(find.byTooltip('سجل التغييرات').last);
      await tester.pumpAndSettle();

      expect(auditLog.lastEntity, entity);
      expect(find.textContaining('سجل التغييرات — ماوية'), findsOneWidget);
      expect(find.text('إنشاء'), findsOneWidget);
    });

    testWidgets('★ وسجلٌ فارغ يقول سببه — ⛔ لا «لا توجد بيانات»',
        (WidgetTester tester) async {
      auditLog.emitEntity(
        AuditEntityRef(
          entityType: sourceEntityType,
          entityId: 'SRC-001',
          sourceId: 'SRC-001',
        ),
        const <AuditLogEntryCard>[],
      );
      await pumpScreen(tester, const SourcesScreen());
      await tester.tap(find.byTooltip('سجل التغييرات').first);
      await tester.pumpAndSettle();
      expect(find.textContaining('لم يُسجَّل على هذا السجل'), findsOneWidget);
    });
  });

  group('★★★ AM-025 §2 — ثلاثُ تصحيحاتٍ في بطاقة القيد (§5-ب)', () {
    setUp(() {
      masterData.emitItems(<ItemCard>[
        ItemCard(
          itemId: 'ITM-0001',
          name: 'بطوة',
          nature: ItemNature.countBased,
          unit: ItemUnit.piece,
          isActive: true,
          isSystemDefault: false,
        ),
      ]);
      masterData.emitDealers(const <DealerCard>[
        DealerCard(
          dealerId: 'MQT-0002',
          name: 'سالم',
          phone: '770000000',
          isActive: true,
        ),
      ]);
    });

    testWidgets(
      '⛔⛔★★★ ① بريدٌ مطابقٌ لاسم الفاعل يُسقَط كلياً — ⛔ ولا سطرٌ مكرَّر',
      (WidgetTester tester) async {
        auditLog.emitCentral(<AuditLogEntryCard>[
          testAuditEntry(
            userName: 'orimind@qtms.test',
            userEmail: 'orimind@qtms.test',
          ),
        ]);
        await pumpScreen(tester, const AuditLogScreen());
      // ★★ **وإطارٌ ثانٍ للقوائم المرجعية** — ★ **مزوّداتُ الأسماء تُشترَك عند
      //    أوّلِ بناءِ بطاقة** ( §2): ⟵ **فقيمتُها تصل في الإطار التالي.**
      await tester.pump(const Duration(milliseconds: 20));

        expect(
          find.text('orimind@qtms.test'),
          findsOneWidget,
          reason: '★ سطرٌ واحد لا سطران — والتمييزُ غائبٌ أصلاً حين تتطابق',
        );
      },
    );

    testWidgets('★ وبريدٌ مختلفٌ يبقى سطراً ثانياً كما هو', (
      WidgetTester tester,
    ) async {
      auditLog.emitCentral(<AuditLogEntryCard>[
        testAuditEntry(userName: 'عبدالفتاح', userEmail: 'owner@qtms.test'),
      ]);
      await pumpScreen(tester, const AuditLogScreen());
      // ★★ **وإطارٌ ثانٍ للقوائم المرجعية** — ★ **مزوّداتُ الأسماء تُشترَك عند
      //    أوّلِ بناءِ بطاقة** ( §2): ⟵ **فقيمتُها تصل في الإطار التالي.**
      await tester.pump(const Duration(milliseconds: 20));

      expect(find.text('عبدالفتاح'), findsOneWidget);
      expect(find.text('owner@qtms.test'), findsOneWidget);
    });

    testWidgets('★★★ ② معرّفُ نوعٍ خام ⟵ اسمُ النوع في سطر الهدف', (
      WidgetTester tester,
    ) async {
      auditLog.emitCentral(<AuditLogEntryCard>[
        testAuditEntry(entityType: itemEntityType, entityId: 'ITM-0001'),
      ]);
      await pumpScreen(tester, const AuditLogScreen());
      // ★★ **وإطارٌ ثانٍ للقوائم المرجعية** — ★ **مزوّداتُ الأسماء تُشترَك عند
      //    أوّلِ بناءِ بطاقة** ( §2): ⟵ **فقيمتُها تصل في الإطار التالي.**
      await tester.pump(const Duration(milliseconds: 20));

      expect(find.textContaining('الأنواع: بطوة'), findsOneWidget);
      expect(find.textContaining('ITM-0001'), findsNothing);
    });

    testWidgets('★★★ ② ومعرّفُ دفعةِ تسعيرٍ ⟵ اسمُ المصدر والتاريخ مقروءَين', (
      WidgetTester tester,
    ) async {
      auditLog.emitCentral(<AuditLogEntryCard>[
        testAuditEntry(
          entityType: dailyPriceEntityType,
          entityId: 'SRC-001_20260905',
        ),
      ]);
      await pumpScreen(tester, const AuditLogScreen());
      // ★★ **وإطارٌ ثانٍ للقوائم المرجعية** — ★ **مزوّداتُ الأسماء تُشترَك عند
      //    أوّلِ بناءِ بطاقة** ( §2): ⟵ **فقيمتُها تصل في الإطار التالي.**
      await tester.pump(const Duration(milliseconds: 20));

      expect(
        find.textContaining('التسعير اليومي: رداع · 2026/09/05'),
        findsOneWidget,
      );
    });

    testWidgets('★★★ ② ومعرّفُ توزيعةٍ مركَّب ⟵ اسمُ المقوت والمصدر', (
      WidgetTester tester,
    ) async {
      auditLog.emitCentral(<AuditLogEntryCard>[
        testAuditEntry(
          entityType: distributionEntityType,
          entityId: 'MQT-0002_SRC-001_20260905',
        ),
      ]);
      await pumpScreen(tester, const AuditLogScreen());
      // ★★ **وإطارٌ ثانٍ للقوائم المرجعية** — ★ **مزوّداتُ الأسماء تُشترَك عند
      //    أوّلِ بناءِ بطاقة** ( §2): ⟵ **فقيمتُها تصل في الإطار التالي.**
      await tester.pump(const Duration(milliseconds: 20));

      expect(find.textContaining('التوزيع: سالم · رداع'), findsOneWidget);
      expect(find.textContaining('MQT-0002'), findsNothing);
    });

    testWidgets(
      '⛔⛔★★★ ② ورقمُ المستند يعلو كلَّ اشتقاق — AM-025 §2 ② في الكاتب',
      (WidgetTester tester) async {
        auditLog.emitCentral(<AuditLogEntryCard>[
          testAuditEntry(
            entityType: distributionEntityType,
            entityId: 'MQT-0002_SRC-001_20260905',
            documentNumber: 'DST-20260905-0002',
          ),
        ]);
        await pumpScreen(tester, const AuditLogScreen());
      // ★★ **وإطارٌ ثانٍ للقوائم المرجعية** — ★ **مزوّداتُ الأسماء تُشترَك عند
      //    أوّلِ بناءِ بطاقة** ( §2): ⟵ **فقيمتُها تصل في الإطار التالي.**
      await tester.pump(const Duration(milliseconds: 20));

        expect(
          find.textContaining('التوزيع: DST-20260905-0002'),
          findsOneWidget,
          reason: '★ الرقمُ الذي يكتبه القيد يُعرَض كما هو ⛔ ولا يُشتقّ بديلٌ',
        );
      },
    );

    testWidgets('⛔★ ومعرّفٌ لا يوافق الصيغة يقع على نفسه — ⛔ ولا يُفكَّك تخميناً',
        (WidgetTester tester) async {
      auditLog.emitCentral(<AuditLogEntryCard>[
        testAuditEntry(
          entityType: dailyPriceEntityType,
          entityId: 'SRC-001_ليس-تاريخاً',
        ),
      ]);
      await pumpScreen(tester, const AuditLogScreen());
      // ★★ **وإطارٌ ثانٍ للقوائم المرجعية** — ★ **مزوّداتُ الأسماء تُشترَك عند
      //    أوّلِ بناءِ بطاقة** ( §2): ⟵ **فقيمتُها تصل في الإطار التالي.**
      await tester.pump(const Duration(milliseconds: 20));

      expect(
        find.textContaining('التسعير اليومي: SRC-001_ليس-تاريخاً'),
        findsOneWidget,
      );
    });

    testWidgets(
      '⛔⛔★★★ ③ الخريطةُ تُفرَد صفّاً لكلِّ سعرٍ — ⛔ لا «حقول (2)»',
      (WidgetTester tester) async {
        auditLog.emitCentral(<AuditLogEntryCard>[
          testAuditEntry(
            entityType: dailyPriceEntityType,
            entityId: 'SRC-001_20260905',
            before: <String, Object?>{
              'ITM-0001': <String, Object?>{
                'distributionPrice': 50,
                'minCashPrice': 40,
              },
            },
            after: <String, Object?>{
              'ITM-0001': <String, Object?>{
                'distributionPrice': 60,
                'minCashPrice': 45,
              },
            },
          ),
        ]);
        await pumpScreen(tester, const AuditLogScreen());
      // ★★ **وإطارٌ ثانٍ للقوائم المرجعية** — ★ **مزوّداتُ الأسماء تُشترَك عند
      //    أوّلِ بناءِ بطاقة** ( §2): ⟵ **فقيمتُها تصل في الإطار التالي.**
      await tester.pump(const Duration(milliseconds: 20));

        // ⛔ **ولا أثرَ للاختصار القديم.**
        expect(find.textContaining('حقول ('), findsNothing);
        // ★ **صفّان باسم النوع واسمِ الحقل معاً.**
        expect(find.text('بطوة · سعر التوزيع:'), findsOneWidget);
        expect(find.text('بطوة · الحد الأدنى للبيع النقدي:'), findsOneWidget);
        expect(find.text('50'), findsOneWidget);
        expect(find.text('60'), findsOneWidget);
        expect(find.text('40'), findsOneWidget);
        expect(find.text('45'), findsOneWidget);
      },
    );

    testWidgets('⛔★★ ③ والمفتاحُ الفرعيُّ الذي لم يتغيّر لا يُنتج صفّاً', (
      WidgetTester tester,
    ) async {
      auditLog.emitCentral(<AuditLogEntryCard>[
        testAuditEntry(
          entityType: dailyPriceEntityType,
          entityId: 'SRC-001_20260905',
          before: <String, Object?>{
            'ITM-0001': <String, Object?>{
              'distributionPrice': 50,
              'minCashPrice': 40,
            },
          },
          after: <String, Object?>{
            'ITM-0001': <String, Object?>{
              'distributionPrice': 60,
              'minCashPrice': 40,
            },
          },
        ),
      ]);
      await pumpScreen(tester, const AuditLogScreen());
      // ★★ **وإطارٌ ثانٍ للقوائم المرجعية** — ★ **مزوّداتُ الأسماء تُشترَك عند
      //    أوّلِ بناءِ بطاقة** ( §2): ⟵ **فقيمتُها تصل في الإطار التالي.**
      await tester.pump(const Duration(milliseconds: 20));

      expect(find.text('بطوة · سعر التوزيع:'), findsOneWidget);
      expect(find.text('بطوة · الحد الأدنى للبيع النقدي:'), findsNothing);
    });

    testWidgets('★★ ③ وغيابُ المفتاح في أحد الطرفين يُقرأ «لا قيمة»', (
      WidgetTester tester,
    ) async {
      auditLog.emitCentral(<AuditLogEntryCard>[
        testAuditEntry(
          entityType: dailyPriceEntityType,
          entityId: 'SRC-001_20260905',
          before: <String, Object?>{
            'ITM-0001': <String, Object?>{'distributionPrice': null},
          },
          after: <String, Object?>{
            'ITM-0001': <String, Object?>{'distributionPrice': 60},
          },
        ),
      ]);
      await pumpScreen(tester, const AuditLogScreen());
      // ★★ **وإطارٌ ثانٍ للقوائم المرجعية** — ★ **مزوّداتُ الأسماء تُشترَك عند
      //    أوّلِ بناءِ بطاقة** ( §2): ⟵ **فقيمتُها تصل في الإطار التالي.**
      await tester.pump(const Duration(milliseconds: 20));

      expect(find.text('بطوة · سعر التوزيع:'), findsOneWidget);
      expect(find.text('لا قيمة'), findsOneWidget);
      expect(find.text('60'), findsOneWidget);
    });

    testWidgets('★ ③ والقائمةُ لا تُفكَّك — «قائمة (N)» باقيةٌ كما هي', (
      WidgetTester tester,
    ) async {
      auditLog.emitCentral(<AuditLogEntryCard>[
        testAuditEntry(
          before: <String, Object?>{
            'lines': <Object?>[1, 2],
          },
          after: <String, Object?>{
            'lines': <Object?>[1, 2, 3],
          },
        ),
      ]);
      await pumpScreen(tester, const AuditLogScreen());
      // ★★ **وإطارٌ ثانٍ للقوائم المرجعية** — ★ **مزوّداتُ الأسماء تُشترَك عند
      //    أوّلِ بناءِ بطاقة** ( §2): ⟵ **فقيمتُها تصل في الإطار التالي.**
      await tester.pump(const Duration(milliseconds: 20));

      expect(find.text('السطور:'), findsOneWidget);
      expect(find.text('قائمة (2)'), findsOneWidget);
      expect(find.text('قائمة (3)'), findsOneWidget);
    });
  });
}

/// شاشة الأدوار — ★★ **حسم `IQ-018` من طرف الواجهة**.
///
/// ⚠️⚠️ **وما تُثبته هذه الاختبارات وما لا تُثبته:** تُثبت أن **الواجهة لا
/// تعرض الحذف على دورٍ تعرف أنه مُسنَد**، وأنها **تُمرِّر الطلب والسبب كما
/// هما**، وأنها **تعرض رفض السحابة بنصّه**. ⛔ **ولا تُثبت أن الحذف محميّ**
/// — ★ **الحماية في `planRoleDeletion` و`firestore.rules`**، ولها اختباراتها
/// هناك (`user_admin_test.dart` · `rules.test.js`).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qtms/capabilities/identity_access/application/admin_providers.dart';
import 'package:qtms/capabilities/identity_access/application/session_providers.dart';
import 'package:qtms/capabilities/identity_access/presentation/roles_screen.dart';
import 'package:qtms/core/messages/error_messages.dart';
import 'package:qtms_domain/qtms_domain.dart';

import '../../../support/fake_identity.dart';

/// ★ كل صلاحيات إدارة الأدوار — فالاختبار يقيس **القاعدة لا نقصَ المفتاح**.
const Set<Permission> roleAdminKeys = <Permission>{
  Permission.userView,
  Permission.roleWrite,
  Permission.roleDelete,
};

Future<void> pumpRoles(
  WidgetTester tester, {
  required FakeRoleAdmin roles,
  required FakeUserDirectory directory,
  Set<Permission> actorPermissions = roleAdminKeys,
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
        userDirectoryProvider.overrideWithValue(directory),
        roleAdminProvider.overrideWithValue(roles),
      ],
      child: const MaterialApp(locale: Locale('ar'), home: RolesScreen()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 20));
}

void main() {
  testWidgets('✅ تعرض الأدوار بأسمائها وأوصافها', (WidgetTester tester) async {
    final FakeRoleAdmin roles = FakeRoleAdmin()
      ..emit(<RoleCard>[
        RoleCard(roleId: 'R-1', name: 'محاسب', description: 'يمسك الدفاتر'),
        testRole(roleId: 'R-2', name: 'أمين مخزن'),
      ]);
    final FakeUserDirectory directory = FakeUserDirectory()
      ..emit(<UserCard>[testCard()]);

    await pumpRoles(tester, roles: roles, directory: directory);

    expect(find.text('محاسب'), findsOneWidget);
    expect(find.text('يمسك الدفاتر'), findsOneWidget);
    expect(find.text('أمين مخزن'), findsOneWidget);
    roles.dispose();
    directory.dispose();
  });

  testWidgets(
    '⛔★★★ IQ-018: الدور المُسنَد لا يُعرَض له زر حذف — ولا يُرسَل طلب',
    (WidgetTester tester) async {
      // ★★ **والإسناد من بيانات المستخدمين الفعلية** — ⛔ لا من حقل في
      //    مستند الدور: `U-002` دورُه `R-1` ⟵ **فـ`R-1` مُسنَد**.
      final FakeRoleAdmin roles = FakeRoleAdmin()
        ..emit(<RoleCard>[testRole(roleId: 'R-1', name: 'محاسب')]);
      final FakeUserDirectory directory = FakeUserDirectory()
        ..emit(<UserCard>[
          testCard(),
          testCard(userId: 'U-002', name: 'أحمد', roleId: 'R-1'),
        ]);

      await pumpRoles(tester, roles: roles, directory: directory);

      expect(find.text('مُسنَد'), findsOneWidget);
      expect(find.byTooltip('حذف الدور'), findsNothing);
      // ★ **والتعديل يبقى متاحاً** — ⟵ **فالغياب حذفٌ لا شللٌ في البطاقة**،
      //   وهو ما يمنع «نجح الاختبار لحظرٍ عام غير مقصود».
      expect(find.byTooltip('تعديل الدور'), findsOneWidget);
      expect(roles.deletedRoleIds, isEmpty);
      roles.dispose();
      directory.dispose();
    },
  );

  testWidgets('⛔★★ ولا يُعرَض للمُسنَد لعدة مستخدمين كذلك',
      (WidgetTester tester) async {
    final FakeRoleAdmin roles = FakeRoleAdmin()
      ..emit(<RoleCard>[testRole(roleId: 'R-1')]);
    final FakeUserDirectory directory = FakeUserDirectory()
      ..emit(<UserCard>[
        testCard(userId: 'U-002', roleId: 'R-1'),
        testCard(userId: 'U-003', roleId: 'R-1'),
        testCard(userId: 'U-004', roleId: 'R-1'),
      ]);

    await pumpRoles(tester, roles: roles, directory: directory);

    expect(find.byTooltip('حذف الدور'), findsNothing);
    roles.dispose();
    directory.dispose();
  });

  testWidgets('✅★★ وغيرُ المُسنَد يُعرَض له الحذف — ويُرسَل بسببه',
      (WidgetTester tester) async {
    final FakeRoleAdmin roles = FakeRoleAdmin()
      ..emit(<RoleCard>[testRole(roleId: 'R-9', name: 'قالب قديم')]);
    // ★ **مستخدمٌ بدورٍ آخر** — ⟵ **فالقائمة ليست فارغة** والشاشة تعرف
    //   الإسناد فعلاً، **والدور `R-9` غير مُسنَد حقاً.**
    final FakeUserDirectory directory = FakeUserDirectory()
      ..emit(<UserCard>[testCard(userId: 'U-002', roleId: 'R-1')]);

    await pumpRoles(tester, roles: roles, directory: directory);

    expect(find.byTooltip('حذف الدور'), findsOneWidget);
    await tester.tap(find.byTooltip('حذف الدور'));
    await tester.pumpAndSettle();

    // ⛔⛔★★★ **ارتدادُ `ADR-0020`:** ★ **كان الزر معطَّلاً حتى يُكتب سبب** —
    //    ⟵ **وصار الحذفُ بلا سببٍ مشروعاً**، ⛔ **فتعطيلُ الزر كان يمنع
    //    عمليةً معتمدة.**
    final Finder confirm = find.widgetWithText(FilledButton, 'حذف الدور');
    expect(tester.widget<FilledButton>(confirm).onPressed, isNotNull);

    await tester.enterText(
      find.widgetWithText(TextField, 'سبب الحذف (اختياري)'),
      'الدور لم يعد مستخدَماً',
    );
    await tester.pumpAndSettle();
    await tester.tap(confirm);
    await tester.pumpAndSettle();

    expect(roles.deletedRoleIds, <String>['R-9']);
    expect(roles.lastDeleteReason, 'الدور لم يعد مستخدَماً');
    roles.dispose();
    directory.dispose();
  });

  testWidgets('⛔★★★ ورفض السحابة يُعرَض بنصّه — ERR_SETUP_012 لا رسالة عامة',
      (WidgetTester tester) async {
    // ⚠️⚠️ **وهذا هو المسار الذي يقع فعلاً حين تكذب الواجهة على نفسها:**
    //    الشاشة ظنّت الدور غير مُسنَد (لأنها لا ترى كل المستخدمين مثلاً)،
    //    ★ **والسحابة استعلمت فوجدته مُسنَداً فرفضت** — ⟵ **فيجب أن يرى
    //    المديرُ السببَ الحقيقي**، ⛔ لا «تعذّر إتمام العملية».
    final FakeRoleAdmin roles = FakeRoleAdmin()
      ..emit(<RoleCard>[testRole(roleId: 'R-9')])
      ..result = const Failure<void>(InfrastructureError('ERR_SETUP_012'));
    final FakeUserDirectory directory = FakeUserDirectory()
      ..emit(<UserCard>[testCard()]);

    await pumpRoles(tester, roles: roles, directory: directory);
    await tester.tap(find.byTooltip('حذف الدور'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'سبب الحذف (اختياري)'),
      'تنظيف',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'حذف الدور'));
    await tester.pumpAndSettle();

    expect(
      find.text(catalogText(CatalogMessage.roleAssigned)),
      findsOneWidget,
    );
    // ★ **ولا رسالة عامة** — فاختلاطهما يُخفي السبب الحقيقي.
    expect(
      find.text(catalogText(CatalogMessage.operationFailed)),
      findsNothing,
    );
    roles.dispose();
    directory.dispose();
  });

  testWidgets(
    '⛔★★ ومن لا يملك `roleDelete` لا يرى الحذف — ويرى التعديل',
    (WidgetTester tester) async {
      // ★★ **والتعديل ظاهرٌ في الحالة نفسها** — ⟵ **فالغياب سببُه المفتاح
      //    المقصود** لا إخفاءٌ عام للأزرار.
      final FakeRoleAdmin roles = FakeRoleAdmin()
        ..emit(<RoleCard>[testRole(roleId: 'R-9')]);
      final FakeUserDirectory directory = FakeUserDirectory()
        ..emit(<UserCard>[testCard()]);

      await pumpRoles(
        tester,
        roles: roles,
        directory: directory,
        actorPermissions: <Permission>{
          Permission.userView,
          Permission.roleWrite,
        },
      );

      expect(find.byTooltip('حذف الدور'), findsNothing);
      expect(find.byTooltip('تعديل الدور'), findsOneWidget);
      roles.dispose();
      directory.dispose();
    },
  );

  testWidgets(
    '★★ وإسنادٌ «غير معروف» يُتيح المحاولة ⛔ ولا يمنع صاحبَ الحق',
    (WidgetTester tester) async {
      // ⚠️ **حالةٌ حقيقية:** من يملك `roleDelete` ولا يملك `userView`
      //    **لا يستطيع قراءة المستخدمين** ⟵ **فلا يعرف الإسناد**.
      //    ★ **والصحيح إتاحة المحاولة والسحابة تحسم** — ⛔ لا منعٌ استباقي
      //    يمنع صاحب الحق من حقّه.
      final FakeRoleAdmin roles = FakeRoleAdmin()
        ..emit(<RoleCard>[testRole(roleId: 'R-1')]);
      final FakeUserDirectory directory = FakeUserDirectory()
        ..emitError(Exception('permission-denied'));

      await pumpRoles(tester, roles: roles, directory: directory);

      expect(find.byTooltip('حذف الدور'), findsOneWidget);
      // ⛔ **ولا يُوصَف الدور بـ«مُسنَد» وهو غير معروف** — ادّعاءٌ بما لا يُعلَم.
      expect(find.text('مُسنَد'), findsNothing);
      roles.dispose();
      directory.dispose();
    },
  );

  testWidgets('★ ورفض قراءة الأدوار يُعرَض منعاً ⛔ لا قائمةً فارغة',
      (WidgetTester tester) async {
    final FakeRoleAdmin roles = FakeRoleAdmin()
      ..emitError(Exception('permission-denied'));
    final FakeUserDirectory directory = FakeUserDirectory()
      ..emit(<UserCard>[testCard()]);

    await pumpRoles(tester, roles: roles, directory: directory);

    expect(
      find.text(catalogText(CatalogMessage.permissionMissing)),
      findsOneWidget,
    );
    expect(find.text('لا توجد أدوار بعد.'), findsNothing);
    roles.dispose();
    directory.dispose();
  });

  testWidgets('★★ وإنشاء دور يُرسل قالب صلاحياته — FR-M1-03',
      (WidgetTester tester) async {
    final FakeRoleAdmin roles = FakeRoleAdmin()..emit(<RoleCard>[]);
    final FakeUserDirectory directory = FakeUserDirectory()
      ..emit(<UserCard>[testCard()]);

    await pumpRoles(tester, roles: roles, directory: directory);
    await tester.tap(find.text('دور جديد'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'اسم الدور'),
      'أمين صندوق',
    );
    // ★ **البحث الفوري بالاسم العربي** — `FR-M1-16` ①.
    await tester.enterText(
      find.widgetWithText(TextField, 'بحث في الصلاحيات'),
      'إضافة سند قبض',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'إنشاء'));
    await tester.pumpAndSettle();

    expect(roles.createdRole?.name, 'أمين صندوق');
    expect(
      roles.createdRole?.permissions,
      <Permission>{Permission.receiptCreate},
    );
    roles.dispose();
    directory.dispose();
  });

  group('⛔⛔★★★ ADR-0020 — وسببُ التعديل اختياريٌّ في نموذج الدور', () {
    // ⚠️⚠️★★ **ومقصدُ هذه المجموعة مزدوج:** ★ **تُثبت القاعدة**، ⟵ **وتحرس
    //    مسارَ التعديل الذي لم يكن مقيساً قبلها** — ⛔ **فبقي بلا شاهد.**

    testWidgets('★ يُحفَظ بلا سببٍ البتّة — ⛔ ولا زرَّ يُعطَّل لغيابه', (
      WidgetTester tester,
    ) async {
      final FakeRoleAdmin roles = FakeRoleAdmin()
        ..emit(<RoleCard>[testRole(roleId: 'R-1', name: 'محاسب')]);
      final FakeUserDirectory directory = FakeUserDirectory()
        ..emit(<UserCard>[testCard()]);

      await pumpRoles(tester, roles: roles, directory: directory);
      await tester.tap(find.byTooltip('تعديل الدور'));
      await tester.pumpAndSettle();

      expect(find.text('سبب التعديل (اختياري)'), findsOneWidget);
      final Finder save = find.widgetWithText(FilledButton, 'حفظ التعديل');
      expect(tester.widget<FilledButton>(save).onPressed, isNotNull);

      await tester.tap(save);
      await tester.pumpAndSettle();

      // ⛔⛔ **وغيابٌ لا نصٌّ فارغ** — ★ `blankToNull` في الطرفين.
      expect(roles.lastAmendReason, isNull);
      roles.dispose();
      directory.dispose();
    });

    testWidgets('★★ وما كتبه الإنسان يصل كما هو', (WidgetTester tester) async {
      final FakeRoleAdmin roles = FakeRoleAdmin()
        ..emit(<RoleCard>[testRole(roleId: 'R-1', name: 'محاسب')]);
      final FakeUserDirectory directory = FakeUserDirectory()
        ..emit(<UserCard>[testCard()]);

      await pumpRoles(tester, roles: roles, directory: directory);
      await tester.tap(find.byTooltip('تعديل الدور'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'سبب التعديل (اختياري)'),
        'توسيع صلاحياته',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'حفظ التعديل'));
      await tester.pumpAndSettle();

      expect(roles.lastAmendReason, 'توسيع صلاحياته');
      roles.dispose();
      directory.dispose();
    });
  });
}

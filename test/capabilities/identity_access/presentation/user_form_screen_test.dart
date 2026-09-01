/// نموذج المستخدم — **نمط 4** · ★ **وسبب التعديل الإلزامي** (`DEBT-21` ①).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qtms/capabilities/identity_access/application/admin_providers.dart';
import 'package:qtms/capabilities/identity_access/presentation/user_form_screen.dart';
import 'package:qtms/core/messages/error_messages.dart';
import 'package:qtms_domain/qtms_domain.dart';

import '../../../support/fake_identity.dart';

/// ★★ **والأدوار تُحقَن كذلك بعد `AM-008` ③** — ⟵ **فالقائمة المنسدلة
/// تقرأ `rolesProvider`**، ⛔ **ولا تُترَك بلا مستودعٍ فتُقرأ خطأً.**
Future<void> pumpForm(
  WidgetTester tester,
  FakeUserAdmin admin, {
  UserCard? existing,
  List<RoleCard> roles = const <RoleCard>[],
}) async {
  final FakeRoleAdmin roleAdmin = FakeRoleAdmin()..emit(roles);
  addTearDown(roleAdmin.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        userAdminProvider.overrideWithValue(admin),
        roleAdminProvider.overrideWithValue(roleAdmin),
      ],
      child: MaterialApp(
        locale: const Locale('ar'),
        home: Scaffold(body: UserFormSheet(existing: existing)),
      ),
    ),
  );
  await tester.pump();
}

/// يملأ الحقول الإلزامية بقيم صحيحة.
///
/// ⚠️★★★ **وكلمة المرور الأولية صارت منها في الإنشاء** — `CR-005`
/// (2026-08-31): ⟵ **فبدونها يُرفَض الطلب محلياً ولا يصل المستودع.**
/// ⛔⛔ **والقيمة هنا قيمةُ اختبارٍ لا سرَّ حقيقي** — ★ **ولا نظير لها في أي
/// بيئة** (`secrets-management-policy.md`).
Future<void> fillValid(WidgetTester tester, {bool isCreate = true}) async {
  final Finder fields = find.byType(TextField);
  await tester.enterText(fields.at(0), 'أحمد المقوت');
  await tester.enterText(fields.at(1), 'ahmed@example.com');
  if (isCreate) {
    await tester.enterText(fields.at(3), 'ThisIsNotARealSecret');
    await tester.enterText(fields.at(4), 'ThisIsNotARealSecret');
  }
  await tester.pump();
}

void main() {
  group('★ الإنشاء', () {
    // ⚠️★★★ **واستُبدل اختبار «لا حقل كلمة مرور» بـ`CR-005`** (2026-08-31)
    //    — ★ **ونقيضُه هو المطلوب الآن.** ⛔⛔ **و`FR-M1-02` قائمٌ بلا مساس:**
    //    ★ **حارسُه في طبقة النطاق** (`forbiddenUserFields`) **وفي الدالة
    //    السحابية** ⟵ **لا في غياب الحقل من الشاشة.**
    testWidgets('⚠️★★★ CR-005: حقلا كلمة المرور الأولية في الإنشاء وحده',
        (WidgetTester tester) async {
      await pumpForm(tester, FakeUserAdmin());

      // ★ **خمسةُ حقول: الاسم · البريد · الهاتف · الكلمة · تأكيدها.**
      expect(find.byType(TextField), findsNWidgets(5));
      expect(find.text('كلمة المرور الأولية'), findsOneWidget);
      expect(find.text('تأكيد كلمة المرور'), findsOneWidget);
      // ⛔⛔ **والمُدخَل مخفيٌّ افتراضياً** — ★ **ولا يُعرَض نصّاً ظاهراً.**
      expect(
        tester
            .widgetList<TextField>(find.byType(TextField))
            .where((TextField field) => field.obscureText)
            .length,
        2,
      );
    });

    testWidgets('⛔★★★ CR-005: ولا حقلَ كلمةِ مرورٍ في التعديل إطلاقاً',
        (WidgetTester tester) async {
      // ★★ **«الإدارة لا تقرأ كلمةً قائمة»** — `authentication-policy.md` §5
      //    (**الشطر الباقي بحرفه**): ⟵ **وحقلٌ هنا كان يُوهم بمسارٍ لا وجود له.**
      await pumpForm(tester, FakeUserAdmin(), existing: testCard());
      expect(find.text('كلمة المرور الأولية'), findsNothing);
      expect(find.text('تأكيد كلمة المرور'), findsNothing);
    });

    testWidgets('⛔★★★ CR-005: وكلمةٌ لا تطابق تأكيدَها تُرفَض محلياً',
        (WidgetTester tester) async {
      final FakeUserAdmin admin = FakeUserAdmin();
      await pumpForm(tester, admin);
      final Finder fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'أحمد المقوت');
      await tester.enterText(fields.at(1), 'ahmed@example.com');
      await tester.enterText(fields.at(3), 'ThisIsNotARealSecret');
      await tester.enterText(fields.at(4), 'ThisIsNotARealSecretX');
      await tester.pump();

      await tester.tap(find.byType(FilledButton));
      await tester.pump();

      // ⛔ **ولا رحلةَ شبكةٍ أصلاً** — `ADR-0012`.
      expect(admin.createdProfile, isNull);
      expect(
        find.text(catalogText(CatalogMessage.operationFailed)),
        findsOneWidget,
      );
    });

    testWidgets('★★★ AM-008 ③: الدور يُختار من قائمة منسدلة ويصل المستودع',
        (WidgetTester tester) async {
      final FakeUserAdmin admin = FakeUserAdmin();
      await pumpForm(
        tester,
        admin,
        roles: <RoleCard>[testRole(roleId: 'ROLE-9', name: 'محاسب')],
      );
      // ⛔ **ولا حقلَ نصٍّ للدور** — ★ **قائمةٌ منسدلة** (`AM-008` ③).
      expect(find.byType(DropdownButtonFormField<String?>), findsOneWidget);

      await fillValid(tester);
      await tester.tap(find.byType(DropdownButtonFormField<String?>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('محاسب').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FilledButton));
      await tester.pump();

      expect(admin.createdProfile?.roleId, 'ROLE-9');
    });

    testWidgets('⛔ ولا حقل سبب تعديل في الإنشاء — لا «قبل» قبل الإنشاء',
        (WidgetTester tester) async {
      await pumpForm(tester, FakeUserAdmin());
      expect(find.text('سبب التعديل (اختياري)'), findsNothing);
    });

    testWidgets('✅ ويُمرِّر الملف مُطبَّعاً كما تفحصه طبقة النطاق',
        (WidgetTester tester) async {
      final FakeUserAdmin admin = FakeUserAdmin();
      await pumpForm(tester, admin);
      await fillValid(tester);

      await tester.tap(find.byType(FilledButton));
      await tester.pump();

      expect(admin.createdProfile?.name, 'أحمد المقوت');
      // ★ **البريد بحروف صغيرة** — من `validateUserProfile` لا من الشاشة.
      expect(admin.createdProfile?.email, 'ahmed@example.com');
    });

    testWidgets('⛔ ومُدخَل مرفوض لا يصل الشبكة أصلاً',
        (WidgetTester tester) async {
      // ⚠️ **نفس القاعدة التي سترفضه في السحابة ترفضه هنا** (`ADR-0012`)،
      //    ⟵ **فيرى المستخدم النتيجة فوراً بلا رحلة**.
      final FakeUserAdmin admin = FakeUserAdmin();
      await pumpForm(tester, admin);
      await tester.enterText(find.byType(TextField).at(0), 'أ');
      await tester.enterText(find.byType(TextField).at(1), 'بريد-خاطئ');
      await tester.pump();

      await tester.tap(find.byType(FilledButton));
      await tester.pump();

      expect(admin.createdProfile, isNull);
      expect(
        find.text(catalogText(CatalogMessage.operationFailed)),
        findsOneWidget,
      );
    });
  });

  group('★★★ ADR-0020 — سبب التعديل اختياريٌّ ويصل السحابة إن كُتب', () {
    testWidgets('✅ حقل السبب يظهر في التعديل وحده', (WidgetTester tester) async {
      await pumpForm(tester, FakeUserAdmin(), existing: testCard());
      expect(find.text('سبب التعديل (اختياري)'), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(4));
    });

    testWidgets('★★ وما يكتبه المستخدم يصل المستودع حرفياً',
        (WidgetTester tester) async {
      // ★★ **بلا هذا الاختبار قد يُبنى الحقل ولا يُرسَل** — ⟵ **فيضيع نصٌّ
      //    كتبه إنسانٌ بلا أثر**، ⛔ **وهو أسوأ من عدم طلبه أصلاً.**
      //    ⚠️★★ **ولم تعد السحابة ترفض غيابه** (`ADR-0020`) — ★ **فالحارس
      //    الآن على الوصول لا على الوجود.**
      final FakeUserAdmin admin = FakeUserAdmin();
      await pumpForm(tester, admin, existing: testCard());
      await fillValid(tester, isCreate: false);
      await tester.enterText(find.byType(TextField).at(3), 'تصحيح الاسم');
      await tester.pump();

      await tester.tap(find.byType(FilledButton));
      await tester.pump();

      expect(admin.lastAmendReason, 'تصحيح الاسم');
    });
  });

  group('★ الرفض يُعرَض ولا يُبتلَع', () {
    testWidgets('★★ رفضُ السحابة يظهر بنصّ الكتالوج ⛔ ولا تُغلَق الورقة صامتة',
        (WidgetTester tester) async {
      // ⚠️ **إغلاقٌ صامت بعد رفض = «تمّ» كاذبة** — وهي أخطر ما في شاشة
      //    إدارة صلاحيات: يظنّ المدير أنه أنشأ مستخدماً ولا مستخدم.
      final FakeUserAdmin admin = FakeUserAdmin()
        ..result = const Failure<void>(PermissionError());
      await pumpForm(tester, admin);
      await fillValid(tester);

      await tester.tap(find.byType(FilledButton));
      await tester.pump();

      expect(
        find.text(catalogText(CatalogMessage.permissionMissing)),
        findsOneWidget,
      );
      // ★ **والحقول تبقى بمدخلاته** ⛔ فلا يُعيد كتابتها من الصفر.
      expect(find.text('أحمد المقوت'), findsOneWidget);
    });

    testWidgets('⛔⛔★★★ ورمز السحابة المجهول يُعرَض برمزه هو — `DEBT-52`',
        (WidgetTester tester) async {
      // ⚠️★★ **وكان يُعرَض برسالة عامة حتى 2026-08-28** — ⟵ ⛔ **فابتلع
      //   تشخيص `DEBT-49` أربع جولات**: ★ **والرسالة العامة تضليلٌ إيجابي
      //   لا غموضٌ محايد** («أعد المحاولة» فعلٌ لا يمكن أن ينجح).
      final FakeUserAdmin admin = FakeUserAdmin()
        ..result = const Failure<void>(InfrastructureError('ERR_XYZ_999'));
      await pumpForm(tester, admin);
      await fillValid(tester);

      await tester.tap(find.byType(FilledButton));
      await tester.pump();

      expect(
        find.text(catalogText(CatalogMessage.operationFailed)),
        findsNothing,
      );
      expect(
        find.textContaining('ERR_XYZ_999'),
        findsOneWidget,
      );
    });

    testWidgets('★ و`ERR_SETUP_011` يصل برسالته هو — لا برسالة عامة',
        (WidgetTester tester) async {
      // ★ **البريد المكرر أشيع رفضٍ في الإنشاء** — ⟵ **ورسالته تُرشد
      //   المدير لتغييره**، ⛔ بينما العامة تتركه يُعيد المحاولة بلا جدوى.
      final FakeUserAdmin admin = FakeUserAdmin()
        ..result = const Failure<void>(InfrastructureError('ERR_SETUP_011'));
      await pumpForm(tester, admin);
      await fillValid(tester);

      await tester.tap(find.byType(FilledButton));
      await tester.pump();

      expect(
        find.text(catalogText(CatalogMessage.emailAlreadyExists)),
        findsOneWidget,
      );
    });
  });
}

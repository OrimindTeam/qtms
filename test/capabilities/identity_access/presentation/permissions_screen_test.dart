/// شاشة تخصيص الصلاحيات — `FR-M1-05` · `FR-M1-06` · `FR-M1-08` · `FR-M1-16`.
///
/// ⚠️⚠️ **وما تُثبته هذه الاختبارات وما لا تُثبته:** تُثبت أن **الشاشة لا
/// تعرض ما لا يجوز**، وأنها **تُرسل ما اختاره المدير حرفياً عبر العملية
/// السحابية وحدها**، وأنها **تعرض النجاح والرفض الحقيقيين**. ⛔ **ولا تُثبت
/// أن القيود محميّة** — ★ **الحماية في `validatePermissionGrant` و
/// `permission_sync.dart` و`firestore.rules`**، ولكلٍّ اختباراتُه.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qtms/capabilities/identity_access/application/admin_providers.dart';
import 'package:qtms/capabilities/identity_access/application/session_providers.dart';
import 'package:qtms/capabilities/identity_access/presentation/permissions_screen.dart';
import 'package:qtms/capabilities/master_data/application/master_data_providers.dart';
import 'package:qtms/core/messages/error_messages.dart';
import 'package:qtms/core/messages/permission_labels.dart';
import 'package:qtms_domain/qtms_domain.dart';

import '../../../support/fake_identity.dart';

const String actorId = 'U-001';
const String targetId = 'U-002';

Future<void> pumpPermissions(
  WidgetTester tester, {
  required FakeUserDirectory directory,
  required FakeUserAdmin admin,
  FakeRoleAdmin? roles,
  Set<Permission> actorPermissions = const <Permission>{
    Permission.userView,
    Permission.permissionGrant,
    Permission.receiptCreate,
  },
  SourceScope actorScope = const AllSources(),
  String openFor = targetId,
  /// ★ كتالوجُ المصادر المعروض — ⛔ **وفارغٌ افتراضاً** (`AM-018`):
  /// ⟵ **فالحالةُ الافتراضية هي «معرّفٌ لا مستندَ له»** ★ **وهي واقعةٌ فعلاً.**
  List<SourceCard> sources = const <SourceCard>[],
}) async {
  final FakeAuthRepository auth = FakeAuthRepository();
  final FakeUserCardRepository cards = FakeUserCardRepository();
  auth.emitIdentity(
    AuthenticatedIdentity(userId: actorId, sourceScope: actorScope),
  );
  cards.emitCard(
    actorId,
    testCard(userId: actorId, permissions: actorPermissions),
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        userCardRepositoryProvider.overrideWithValue(cards),
        userDirectoryProvider.overrideWithValue(directory),
        userAdminProvider.overrideWithValue(admin),
        roleAdminProvider.overrideWithValue(roles ?? (FakeRoleAdmin()..emit(<RoleCard>[]))),
        sourcesProvider.overrideWith(
          (Ref ref) => Stream<List<SourceCard>>.value(sources),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('ar'),
        home: PermissionsScreen(userId: openFor),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 20));
}

/// يجد مربّع اختيار الصلاحية بعنوانها العربي.
Finder checkboxFor(Permission permission) => find.ancestor(
      of: find.text(permissionLabel(permission)),
      matching: find.byType(Row),
    );

/// ★ يمرّر حتى زر الحفظ ثم يضغطه.
///
/// ⚠️ **والتمرير لازم لا تجميل:** الشجرة **اثنان وسبعون مفتاحاً**، والقائمة
/// كسولة ⟵ **فالزر لا يُبنى أصلاً قبل الوصول إليه**، ولا ينفع `ensureVisible`.
Future<void> tapSave(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.text('حفظ الصلاحيات'),
    600,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('حفظ الصلاحيات'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    '⛔★★★ لا يعدّل أحدٌ صلاحيات نفسه — ولو المالك',
    (WidgetTester tester) async {
      // ★ `authentication-policy.md` §3. ⚠️⚠️ **ومنعُ العرض هنا ليس
      //    الحماية**: `validatePermissionGrant` ① ترفض الطلب نفسه.
      final FakeUserDirectory directory = FakeUserDirectory()
        ..emit(<UserCard>[testCard(userId: actorId)]);
      final FakeUserAdmin admin = FakeUserAdmin();

      await pumpPermissions(
        tester,
        directory: directory,
        admin: admin,
        openFor: actorId,
      );

      expect(
        find.text('لا يمكن لأي مستخدم تعديل صلاحيات حسابه — ولو كان المالك.'),
        findsOneWidget,
      );
      // ⛔ **ولا شجرة صلاحيات أصلاً** — فلا مسار للضغط على «حفظ».
      expect(find.text('حفظ الصلاحيات'), findsNothing);
      directory.dispose();
    },
  );

  testWidgets(
    '⛔★★★ BR-M1-03: ما لا يملكه المُنفِّذ يُعرَض معطَّلاً بسببٍ مكتوب',
    (WidgetTester tester) async {
      final FakeUserDirectory directory = FakeUserDirectory()
        ..emit(<UserCard>[
          testCard(userId: actorId),
          testCard(userId: targetId, name: 'أحمد'),
        ]);
      final FakeUserAdmin admin = FakeUserAdmin();

      await pumpPermissions(tester, directory: directory, admin: admin);

      // ★ **صلاحية يملكها المُنفِّذ ⟵ قابلة للتبديل.**
      final Finder ownedRow = checkboxFor(Permission.receiptCreate).first;
      expect(
        tester
            .widget<Checkbox>(
              find.descendant(of: ownedRow, matching: find.byType(Checkbox)),
            )
            .onChanged,
        isNotNull,
      );

      // ⛔ **وصلاحية لا يملكها ⟵ معطَّلة** — ★ **وتُعرَض ولا تُخفى** فيفهم
      //   المدير أنها موجودة وأنه لا يملكها.
      final Finder foreignRow = checkboxFor(Permission.ownerLedgerView).first;
      expect(
        tester
            .widget<Checkbox>(
              find.descendant(of: foreignRow, matching: find.byType(Checkbox)),
            )
            .onChanged,
        isNull,
      );
      expect(find.text('لا تملكها'), findsWidgets);
      directory.dispose();
    },
  );

  testWidgets(
    '✅★★ والحفظ يمرّ بالعملية السحابية بما اختاره المدير حرفياً',
    (WidgetTester tester) async {
      final FakeUserDirectory directory = FakeUserDirectory()
        ..emit(<UserCard>[
          testCard(userId: actorId),
          testCard(
            userId: targetId,
            name: 'أحمد',
            permissions: const <Permission>{},
          ),
        ]);
      final FakeUserAdmin admin = FakeUserAdmin();

      await pumpPermissions(tester, directory: directory, admin: admin);

      await tester.enterText(
        find.widgetWithText(TextField, 'بحث في الصلاحيات'),
        permissionLabel(Permission.receiptCreate),
      );
      await tester.pumpAndSettle();
      // ⚠️ **مربّع الصلاحية لا `byType(Checkbox).first`** — ★ **فالأول
      //    مربّعُ «كل المصادر»**، وضغطُه كان يُفرغ النطاق فيُعطِّل الحفظ.
      await tester.tap(
        find.descendant(
          of: checkboxFor(Permission.receiptCreate).first,
          matching: find.byType(Checkbox),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('حفظ الصلاحيات'));
      await tester.pumpAndSettle();

      expect(admin.lastGrantTarget, targetId);
      expect(
        admin.lastGrantedPermissions,
        <Permission>{Permission.receiptCreate},
      );
      expect(admin.lastGrantedScope, const AllSources());
      // ★ **حالة نجاح ظاهرة** — ⛔ ولا صمت بعد عملية نجحت.
      expect(find.text('✅ حُفظت الصلاحيات.'), findsOneWidget);
      directory.dispose();
    },
  );

  testWidgets(
    '⛔★★ ورفض السحابة يُعرَض بنصّه — ERR_AUTH_007 لا رسالة عامة',
    (WidgetTester tester) async {
      final FakeUserDirectory directory = FakeUserDirectory()
        ..emit(<UserCard>[
          testCard(userId: actorId),
          testCard(userId: targetId, name: 'أحمد'),
        ]);
      final FakeUserAdmin admin = FakeUserAdmin()
        ..result = const Failure<void>(PermissionError());

      await pumpPermissions(tester, directory: directory, admin: admin);
      await tapSave(tester);

      expect(
        find.text(catalogText(CatalogMessage.permissionMissing)),
        findsOneWidget,
      );
      // ⛔ **ولا حالة نجاح كاذبة** — أخطر ما يمكن أن تعرضه هذه الشاشة.
      expect(find.text('✅ حُفظت الصلاحيات.'), findsNothing);
      directory.dispose();
    },
  );

  testWidgets(
    '⛔★★★ FR-M1-08: من نطاقه محدود لا يُعرَض له «كل المصادر»',
    (WidgetTester tester) async {
      // ★ `scopeIsWithin` ترفض `all` داخل قائمة محدودة مهما طالت، ⟵
      //   **فعرضُها كان سيَعِد بما يُرفَض**. ⚠️⚠️ **والحسم في السحابة.**
      final FakeUserDirectory directory = FakeUserDirectory()
        ..emit(<UserCard>[
          testCard(userId: actorId),
          testCard(userId: targetId, name: 'أحمد'),
        ]);
      final FakeUserAdmin admin = FakeUserAdmin();

      await pumpPermissions(
        tester,
        directory: directory,
        admin: admin,
        actorScope: ScopedSources(<String>{'SRC-A', 'SRC-B'}),
      );

      expect(find.text('كل المصادر'), findsNothing);
      // ★ **ومصادرُ نطاقه معروضة** — ⟵ **فالغياب تضييقٌ مقصود لا شللٌ عام.**
      //
      // ⛔⛔★★★ **وبلا كتالوجٍ تُعرَض بصيغة «غير معروف»** — `AM-018` ·
      //    `design-system.md` §8 المحظور 13: ⛔ **ولا معرّفٌ عارٍ يُقرأ اسماً**،
      //    ★ **والمعرّفُ يبقى مذكوراً ليُتتبَّع** ⛔ **ولا يُخفى.**
      expect(find.text('مصدر غير معروف (SRC-A)'), findsOneWidget);
      expect(find.text('مصدر غير معروف (SRC-B)'), findsOneWidget);
      expect(find.text('SRC-A'), findsNothing);
      directory.dispose();
    },
  );

  testWidgets(
    '⛔⛔★★★ AM-018: المصدرُ باسمه المقروء لا بمعرّفه الخام',
    (WidgetTester tester) async {
      final FakeUserDirectory directory = FakeUserDirectory()
        ..emit(<UserCard>[
          testCard(userId: actorId),
          testCard(userId: targetId, name: 'أحمد'),
        ]);

      await pumpPermissions(
        tester,
        directory: directory,
        admin: FakeUserAdmin(),
        actorScope: ScopedSources(<String>{'SRC-A', 'SRC-B'}),
        sources: const <SourceCard>[
          SourceCard(
            sourceId: 'SRC-A',
            name: 'مزرعة الحدا',
            requiresSupplierOnIntake: false,
            isActive: true,
          ),
        ],
      );

      // ★ **الموجودُ في الكتالوج باسمه.**
      expect(find.text('مزرعة الحدا'), findsOneWidget);
      expect(find.text('SRC-A'), findsNothing);
      // ⛔ **والغائبُ بصيغة «غير معروف» لا عارياً.**
      expect(find.text('مصدر غير معروف (SRC-B)'), findsOneWidget);
      directory.dispose();
    },
  );

  testWidgets('✅★ ومن نطاقه «كل المصادر» يراها', (WidgetTester tester) async {
    final FakeUserDirectory directory = FakeUserDirectory()
      ..emit(<UserCard>[
        testCard(userId: actorId),
        testCard(userId: targetId, name: 'أحمد'),
      ]);
    final FakeUserAdmin admin = FakeUserAdmin();

    await pumpPermissions(tester, directory: directory, admin: admin);

    expect(find.text('كل المصادر'), findsOneWidget);
    directory.dispose();
  });

  testWidgets(
    '★★ FR-M1-05: المنح فوق قالب الدور يُوسَم في المقارنة',
    (WidgetTester tester) async {
      final FakeRoleAdmin roles = FakeRoleAdmin()
        ..emit(<RoleCard>[
          testRole(
            roleId: 'R-1',
            template: const <Permission>{Permission.sackView},
          ),
        ]);
      final FakeUserDirectory directory = FakeUserDirectory()
        ..emit(<UserCard>[
          testCard(userId: actorId),
          testCard(
            userId: targetId,
            name: 'أحمد',
            roleId: 'R-1',
            // ★ **يملك `receiptCreate` وليست في قالبه ⟵ «فوق الدور»**،
            //   **ولا يملك `sackView` وهي في قالبه ⟵ «دون الدور»**.
            permissions: const <Permission>{Permission.receiptCreate},
          ),
        ]);
      final FakeUserAdmin admin = FakeUserAdmin();

      await pumpPermissions(
        tester,
        directory: directory,
        admin: admin,
        roles: roles,
      );

      expect(find.text('فوق الدور'), findsOneWidget);
      expect(find.text('دون الدور'), findsOneWidget);
      roles.dispose();
      directory.dispose();
    },
  );

  testWidgets(
    '★★ FR-M1-16 ②: نسخ صلاحيات مستخدم يملأ الشجرة ⛔ ولا يحفظ',
    (WidgetTester tester) async {
      // ⚠️ **والنسخ اقتراحٌ لا حفظ** — ★ **فيراجعه المدير قبل الإرسال**،
      //    ⛔ ولا ينسخ صلاحيةً وهو لا يدري.
      final FakeUserDirectory directory = FakeUserDirectory()
        ..emit(<UserCard>[
          testCard(userId: actorId),
          testCard(
            userId: targetId,
            name: 'أحمد',
            permissions: const <Permission>{},
          ),
          testCard(
            userId: 'U-003',
            name: 'سالم',
            permissions: const <Permission>{Permission.receiptCreate},
          ),
        ]);
      final FakeUserAdmin admin = FakeUserAdmin();

      await pumpPermissions(tester, directory: directory, admin: admin);

      await tester.tap(find.text('نسخ صلاحيات مستخدم'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('سالم').last);
      await tester.pumpAndSettle();

      // ⛔ **ولا شيء أُرسل بعد** — النسخ ملأ الشجرة وحدها.
      expect(admin.lastGrantedPermissions, isNull);

      await tapSave(tester);
      expect(
        admin.lastGrantedPermissions,
        <Permission>{Permission.receiptCreate},
      );
      directory.dispose();
    },
  );

  testWidgets('★ FR-M1-16 ①: البحث بالاسم العربي يُصفّي الشجرة فوراً',
      (WidgetTester tester) async {
    final FakeUserDirectory directory = FakeUserDirectory()
      ..emit(<UserCard>[
        testCard(userId: actorId),
        testCard(userId: targetId, name: 'أحمد'),
      ]);
    final FakeUserAdmin admin = FakeUserAdmin();

    await pumpPermissions(tester, directory: directory, admin: admin);

    // ⚠️ **نصّ بحثٍ لا يساوي أي عنوان** — ⟵ **فالعثور على العنوان يُثبت
    //    التصفية**، ⛔ ولا يخلط حقلَ البحث نفسه بالنتيجة.
    await tester.enterText(
      find.widgetWithText(TextField, 'بحث في الصلاحيات'),
      'سند قبض',
    );
    await tester.pumpAndSettle();

    expect(find.text(permissionLabel(Permission.receiptCreate)), findsOneWidget);
    expect(find.text(permissionLabel(Permission.sackView)), findsNothing);

    await tester.enterText(
      find.widgetWithText(TextField, 'بحث في الصلاحيات'),
      'لا صلاحية بهذا الاسم إطلاقاً',
    );
    await tester.pumpAndSettle();
    // ★ **حالة «لا نتيجة» صريحة** — ⛔ ولا شجرةٌ فارغة صامتة.
    expect(find.text('لا صلاحية بهذا الاسم.'), findsOneWidget);
    directory.dispose();
  });
}

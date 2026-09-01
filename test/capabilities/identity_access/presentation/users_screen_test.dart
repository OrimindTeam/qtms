/// شاشة إدارة المستخدمين — ★ **الشاشة التي فتحها `IQ-015`**.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qtms/capabilities/identity_access/application/admin_providers.dart';
import 'package:qtms/capabilities/identity_access/application/session_providers.dart';
import 'package:qtms/capabilities/identity_access/presentation/home_shell.dart';
import 'package:qtms/capabilities/identity_access/presentation/users_screen.dart';
import 'package:qtms/core/messages/error_messages.dart';
import 'package:qtms/core/ui/avatar.dart';
import 'package:qtms/core/ui/entity_tile.dart';
import 'package:qtms_domain/qtms_domain.dart';

import '../../../support/fake_identity.dart';

Future<void> pumpUsers(
  WidgetTester tester,
  FakeUserDirectory directory, {
  FakeAuthRepository? auth,
  FakeUserCardRepository? cards,
}) async {
  final FakeAuthRepository authRepo = auth ?? FakeAuthRepository();
  final FakeUserCardRepository cardRepo = cards ?? FakeUserCardRepository();
  authRepo.emitIdentity(
    const AuthenticatedIdentity(userId: 'U-001', sourceScope: AllSources()),
  );
  cardRepo.emitCard('U-001', testCard());

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(authRepo),
        userCardRepositoryProvider.overrideWithValue(cardRepo),
        userDirectoryProvider.overrideWithValue(directory),
      ],
      child: const MaterialApp(locale: Locale('ar'), home: UsersScreen()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 20));
}

void main() {
  testWidgets('✅ تعرض المستخدمين بأسمائهم وأدوارهم', (WidgetTester tester) async {
    final FakeUserDirectory directory = FakeUserDirectory()
      ..emit(<UserCard>[
        testCard(userId: 'U-001', name: 'عبدالفتاح'),
        testCard(userId: 'U-002', name: 'أحمد'),
      ]);

    await pumpUsers(tester, directory);

    // ★★ **والعنوان `الاسم : الدور` في سطرٍ واحد** — `AM-008` ④.
    expect(find.text('عبدالفتاح : المالك'), findsOneWidget);
    expect(find.text('أحمد : المالك'), findsOneWidget);
    // ★★★ **وصورةٌ رمزية لكلٍّ بالحرف الأول** — `AM-008` ④.
    //    ⚠️ **وتُقاس باسمها لا بعددها المجرَّد** — ★ **فالشريط العلوي يحمل
    //    صورةَ صاحب الجلسة أيضاً** (`AM-008` ①)، ⟵ **وعدٌّ أعمى يخلط بينها.**
    for (final String name in <String>['عبدالفتاح', 'أحمد']) {
      expect(
        find.descendant(
          of: find.byType(EntityList),
          matching: find.byWidgetPredicate(
            (Widget widget) => widget is QtmsAvatar && widget.name == name,
          ),
        ),
        findsOneWidget,
      );
    }
    directory.dispose();
  });

  testWidgets(
    '⛔★★ IQ-015: رفض القاعدة يظهر رسالةَ منعٍ ⛔ لا قائمةً فارغة',
    (WidgetTester tester) async {
      // ★★ **هذا التمييز هو جوهر الشاشة:** «لا يوجد مستخدمون» تجعل المديرَ
      //    يبحث عن عطلٍ لا وجود له، **بينما الحقيقة أنه ممنوعٌ من الرؤية**.
      final FakeUserDirectory directory = FakeUserDirectory()
        ..emitError(Exception('permission-denied'));

      await pumpUsers(tester, directory);

      expect(
        find.text(catalogText(CatalogMessage.permissionMissing)),
        findsOneWidget,
      );
      expect(find.text('لا يوجد مستخدمون بعد'), findsNothing);
      directory.dispose();
    },
  );

  testWidgets('★ وخطأ غير المنع يظهر برسالة عامة ⛔ لا باتهام الصلاحية',
      (WidgetTester tester) async {
    // ⚠️ **اتهامُ صلاحيةٍ سليمة يُرسِل المديرَ ليمنح صلاحيةً ممنوحة أصلاً.**
    final FakeUserDirectory directory = FakeUserDirectory()
      ..emitError(Exception('unavailable'));

    await pumpUsers(tester, directory);

    expect(
      find.text(catalogText(CatalogMessage.operationFailed)),
      findsOneWidget,
    );
    expect(
      find.text(catalogText(CatalogMessage.permissionMissing)),
      findsNothing,
    );
    directory.dispose();
  });

  testWidgets('★ والقائمة الفارغة فعلاً لها نصّها هي', (WidgetTester tester) async {
    final FakeUserDirectory directory = FakeUserDirectory()
      ..emit(const <UserCard>[]);

    await pumpUsers(tester, directory);

    expect(find.text('لا يوجد مستخدمون بعد'), findsOneWidget);
    directory.dispose();
  });

  testWidgets(
    '★★ FR-M1-12: المعطَّل يظهر في القائمة موسوماً ⛔ ولا يختفي',
    (WidgetTester tester) async {
      // ★ **الحذف ممنوع** — ⟵ **وإخفاؤه يجعله كالمحذوف في عين المدير**
      //   فيظنّه ذهب وهو باقٍ بقيوده في سجل التدقيق.
      final FakeUserDirectory directory = FakeUserDirectory()
        ..emit(<UserCard>[
          testCard(userId: 'U-002', name: 'أحمد', isActive: false),
        ]);

      await pumpUsers(tester, directory);

      expect(find.text('أحمد : المالك'), findsOneWidget);
      expect(find.text('معطَّل'), findsOneWidget);
      directory.dispose();
    },
  );

  // ═══════════════════════════════════════════════════════════════════
  // ★★ بوابة الصلاحية في الصدَفة — ⚠️ **إخفاء لا حماية** (`RISK-02`)
  // ═══════════════════════════════════════════════════════════════════
  group('★ مدخل الشاشة في الصدَفة محكوم بـuserView', () {
    Future<void> pumpShell(
      WidgetTester tester, {
      required Set<Permission> permissions,
      required FakeAuthRepository auth,
      required FakeUserCardRepository cards,
    }) async {
      auth.emitIdentity(
        const AuthenticatedIdentity(userId: 'U-001', sourceScope: AllSources()),
      );
      cards.emitCard('U-001', testCard(permissions: permissions));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(auth),
            userCardRepositoryProvider.overrideWithValue(cards),
          ],
          child: const MaterialApp(locale: Locale('ar'), home: HomeShell()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
    }

    testWidgets('✅ يظهر لمن يملكها', (WidgetTester tester) async {
      final FakeAuthRepository auth = FakeAuthRepository();
      final FakeUserCardRepository cards = FakeUserCardRepository();
      await pumpShell(
        tester,
        permissions: <Permission>{Permission.userView},
        auth: auth,
        cards: cards,
      );

      expect(find.text('إدارة المستخدمين'), findsOneWidget);
      auth.dispose();
      cards.dispose();
    });

    testWidgets('⛔ ولا يظهر لمن لا يملكها — «الممنوع لا يظهر أصلاً»',
        (WidgetTester tester) async {
      final FakeAuthRepository auth = FakeAuthRepository();
      final FakeUserCardRepository cards = FakeUserCardRepository();
      await pumpShell(
        tester,
        permissions: <Permission>{Permission.sackView},
        auth: auth,
        cards: cards,
      );

      expect(find.text('إدارة المستخدمين'), findsNothing);
      auth.dispose();
      cards.dispose();
    });
  });
}

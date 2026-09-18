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
  /// ★ صلاحياتُ صاحب الجلسة — ★ **تُمرَّر حيث تحكم بوابةٌ ما يُعرَض.**
  Set<Permission> permissions = const <Permission>{Permission.sackView},
}) async {
  final FakeAuthRepository authRepo = auth ?? FakeAuthRepository();
  final FakeUserCardRepository cardRepo = cards ?? FakeUserCardRepository();
  authRepo.emitIdentity(
    const AuthenticatedIdentity(userId: 'U-001', sourceScope: AllSources()),
  );
  cardRepo.emitCard('U-001', testCard(permissions: permissions));

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

      // ★★ **ويُمرَّر إليه قبل القياس** — ⛔ **ولا يُضعَّف الشرط:**
      //    ⟵ **جسمُ الصدَفة `ListView` يبني كسولاً**، ★ **وصفُّ «متبقي أيام
      //    سابقة» في `WU-019` أزاح الأقسام تحت الطيّة** — ⛔ **فغيابُ الودجت
      //    من شجرة البناء ليس غياباً من الشاشة.** ★ **والقياسُ يبقى قياسَ
      //    ظهورٍ فعليٍّ لمن يملك المفتاح** (ويقابله الاختبارُ السالب أدناه).
      await tester.scrollUntilVisible(
        find.text('إدارة المستخدمين'),
        200,
        scrollable: find.byType(Scrollable).first,
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

      // ⛔⛔★★ **ويُمرَّر إلى آخر الصدَفة قبل نفي الظهور** — ★ **وإلا صار
      //    النفيُ صادقاً لأن القائمة الكسولة لم تبنِ القسمَ بعد** ⛔ **لا
      //    لأن البوابة أخفته**: ⟵ **وهو نفيٌ فارغ يمرّ على شاشةٍ معطوبة.**
      await scrollShellToEnd(tester);
      expect(find.text('إدارة المستخدمين'), findsNothing);
      // ★ **وشاهدٌ حيٌّ على أن الشجرة بُنيت فعلاً** — ★ **«التسعير اليومي»
      //   مدخلٌ بلا بوابة** (`home_shell.dart`: **النطاقُ وحده يحكم**):
      //   ⟵ **فظهورُه يُثبت أن الأقسام بُنيت**، ⛔ **والنفيُ أعلاه ليس نفيَ
      //   قائمةٍ لم تُبنَ.**
      expect(find.text('التسعير اليومي'), findsOneWidget);
      auth.dispose();
      cards.dispose();
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // ⛔⛔★★★ AM-018 — السطرُ الثانوي والأيقونة الموحّدة
  // ══════════════════════════════════════════════════════════════════════

  group('⛔⛔★★★ AM-018 — ولا معرّفٌ داخليٌّ في نصٍّ يراه المستخدم', () {
    test('★★ الفراغُ يُعامَل غياباً لا نصّاً — §8 المحظور 13', () {
      expect(userSubtitle('a@b.test'), 'a@b.test');
      // ⛔⛔ **وهذه بعينُها ما تمرّ من `??`** — ⟵ **فتُعرَض سطراً خاوياً.**
      expect(userSubtitle(''), noEmailLabel);
      expect(userSubtitle('   '), noEmailLabel);
      expect(userSubtitle(null), noEmailLabel);
    });

    testWidgets('★★ وبطاقةٌ ببريدٍ فارغٍ تعرض «بلا بريد» ⛔ لا فراغاً',
        (WidgetTester tester) async {
      final FakeUserDirectory directory = FakeUserDirectory()
        ..emit(<UserCard>[
          testCard(userId: 'U-002', name: 'مستخدم مُسنَد', email: ''),
        ]);

      await pumpUsers(tester, directory);

      expect(find.text(noEmailLabel), findsOneWidget);
      // ⛔⛔★★★ **ولا معرّفَ المستخدم في موضع البريد.**
      expect(find.textContaining('U-002'), findsNothing);
      directory.dispose();
    });

    testWidgets('★ وأيقونةُ «إضافة» موحَّدةٌ مع الشاشات الشقيقة',
        (WidgetTester tester) async {
      final FakeUserDirectory directory = FakeUserDirectory()
        ..emit(<UserCard>[testCard(userId: 'U-001')]);
      // ★ **والزرُّ خلف `userCreate`** — ⟵ **فبلا المفتاح يغيب بحقّ**،
      //   ⛔ **ونفيُ الأيقونة عندئذٍ نفيٌ فارغ.**
      await pumpUsers(
        tester,
        directory,
        permissions: <Permission>{Permission.userCreate},
      );

      expect(find.byIcon(Icons.person_add_alt_outlined), findsOneWidget);
      expect(find.byIcon(Icons.person_add_alt), findsNothing);
      expect(find.byIcon(Icons.person_add_alt_1_outlined), findsNothing);
      directory.dispose();
    });
  });
}

/// ★★ يُمرِّر جسمَ الصدَفة إلى نهايته — ⛔ **ولا يكتفي بقفزةٍ واحدة:**
/// ⟵ **`ListView` الكسول لا يعرف مداه الأقصى إلا بقدر ما بنى**، ★ **فيُعاد
/// القفزُ حتى يثبت المدى.**
Future<void> scrollShellToEnd(WidgetTester tester) async {
  final ScrollableState state =
      tester.state<ScrollableState>(find.byType(Scrollable).first);
  double previous = -1;
  while (state.position.maxScrollExtent > previous) {
    previous = state.position.maxScrollExtent;
    state.position.jumpTo(previous);
    await tester.pumpAndSettle();
  }
}

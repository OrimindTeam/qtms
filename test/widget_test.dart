/// اختبار جذر التطبيق ومساره.
///
/// ★ يُثبت ثلاثة أشياء **لا تظهر في اختبار وحدة**: أن حالة الإقلاع تصل
/// الشاشة، وأن حالة الجلسة **تُقرِّر الوجهة**، وأن الاتجاه RTL فعلاً.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qtms/capabilities/identity_access/application/session_providers.dart';
import 'package:qtms/capabilities/identity_access/presentation/home_shell.dart';
import 'package:qtms/capabilities/identity_access/presentation/login_screen.dart';
import 'package:qtms/capabilities/identity_access/presentation/session_blocked_screen.dart';
import 'package:qtms/core/design/brand.dart';
import 'package:qtms/core/messages/error_messages.dart';
import 'package:qtms/core/startup/app_startup.dart';
import 'package:qtms/main.dart';
import 'package:qtms/core/ui/avatar.dart';
import 'package:qtms_domain/qtms_domain.dart';

import 'support/fake_identity.dart';

/// نبضات محدودة — ⛔ **ولا `pumpAndSettle`**: شاشة الانتظار تحمل مؤشّراً
/// دوّاراً **لا ينتهي**، ⟵ **فالانتظار حتى السكون لا يعود أبداً.**
Future<void> _settle(WidgetTester tester) async {
  // ★ نبضات تتجاوز زمن انتقال المسار (≈300ms) — فالوجهة الجديدة تُبنى فعلاً.
  for (int i = 0; i < 16; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  late FakeAuthRepository auth;
  late FakeUserCardRepository cards;

  setUp(() {
    auth = FakeAuthRepository();
    cards = FakeUserCardRepository();
  });

  tearDown(() {
    auth.dispose();
    cards.dispose();
  });

  Widget app(StartupOutcome outcome) => ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          userCardRepositoryProvider.overrideWithValue(cards),
        ],
        child: QtmsApp(outcome: outcome),
      );

  testWidgets('C-04: غياب خدمات المنصة يظهر برسالة الكتالوج لا يُبتلَع', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      app(const StartupFailed(PlatformUnavailableError('TestFailure'))),
    );
    await tester.pump();

    expect(
      find.text(catalogText(CatalogMessage.platformUnavailable)),
      findsOneWidget,
    );
  });

  testWidgets('★★ AM-002: عنوان التطبيق اسمُ العميل — في الحالتين معاً', (
    WidgetTester tester,
  ) async {
    // ★ العنوان يظهر في مبدّل مهام أندرويد، ⟵ فهو موضع اسم ظاهر فعلاً.
    await tester.pumpWidget(app(const StartupReady()));
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).title,
      appDisplayName,
    );

    // ⚠️ وحتى تطبيق تعذُّر الإقلاع يحمل الاسم نفسه — ⛔ فلا 'QTMS' يتسرّب
    //    من المسار البديل الذي يراه المستخدم عند غياب المنصّة.
    await tester.pumpWidget(
      app(const StartupFailed(PlatformUnavailableError('TestFailure'))),
    );
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).title,
      appDisplayName,
    );
  });

  testWidgets('★★ AM-002: شاشة البداية تعرض شعار العميل فوق المؤشّر', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(app(const StartupReady()));
    await tester.pump();

    // ★ حالة الجلسة لم تُعرَف بعد ⟵ فالوجهة هي شاشة البداية.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(BrandLogo), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);

    // ⛔ وبلا نصّ مضاف مع الشعار — القاعدة قائمة كما هي
    //    (`ui-guidelines.md` نمط 8-أ)، والاسم مرسومٌ داخل الشعار نفسه.
    expect(find.text(appDisplayName), findsNothing);
  });

  testWidgets('بلا جلسة ⟵ شاشة الدخول', (WidgetTester tester) async {
    await tester.pumpWidget(app(const StartupReady()));
    auth.emitIdentity(null);
    await _settle(tester);

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(HomeShell), findsNothing);
  });

  testWidgets('★ جلسة قائمة ⟵ الصدَفة', (WidgetTester tester) async {
    await tester.pumpWidget(app(const StartupReady()));
    auth.emitIdentity(
      const AuthenticatedIdentity(userId: 'U-001', sourceScope: AllSources()),
    );
    await tester.pump();
    cards.emitCard('U-001', testCard());
    await _settle(tester);

    expect(find.byType(HomeShell), findsOneWidget);
    // ⚠️★★ **والاسمُ في الصورة الرمزية بعد `AM-008` ①** — ⛔ **لا نصّاً في
    //    الشريط**: ★ **والهويةُ معروضةٌ بشكلٍ آخر لا ساقطة.**
    expect(
      tester.widget<QtmsAvatar>(find.byType(QtmsAvatar)).name,
      'عبدالفتاح',
    );
    // ⛔⛔★★★ **ولا بطاقةَ دورٍ ولا نطاقِ مصادر في الصدَفة** — `AM-009` ②:
    //    ★ **كانت تعرض «كل المصادر» في صدر الشاشة**، ⟵ **وأُزيلت بطلب
    //    المالك** ⛔ **ولا تعود بصمت.**
    expect(find.text('كل المصادر'), findsNothing);
  });

  testWidgets('★★ FR-M1-15: تعطيل الحساب يُخرج المستخدم من شاشات العمل فوراً', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(app(const StartupReady()));
    auth.emitIdentity(
      const AuthenticatedIdentity(userId: 'U-001', sourceScope: AllSources()),
    );
    await tester.pump();
    cards.emitCard('U-001', testCard());
    await _settle(tester);
    expect(find.byType(HomeShell), findsOneWidget);

    // ⟵ التعطيل يصل عبر المُصغي الحيّ بلا إعادة دخول.
    cards.emitCard('U-001', testCard(isActive: false));
    await _settle(tester);

    expect(find.byType(HomeShell), findsNothing);
    expect(find.byType(SessionBlockedScreen), findsOneWidget);
    expect(
      find.text(catalogText(CatalogMessage.accountDisabled)),
      findsOneWidget,
    );
  });

  testWidgets('★ ولا يُقرأ إلا بطاقة صاحب الجلسة', (WidgetTester tester) async {
    await tester.pumpWidget(app(const StartupReady()));
    auth.emitIdentity(
      const AuthenticatedIdentity(userId: 'U-001', sourceScope: AllSources()),
    );
    await _settle(tester);

    expect(cards.requestedUserIds, <String>['U-001']);
  });

  testWidgets('اتجاه الواجهة من اليمين لليسار', (WidgetTester tester) async {
    await tester.pumpWidget(app(const StartupReady()));
    auth.emitIdentity(null);
    await _settle(tester);

    // ★ يُقرأ الاتجاه **كما تراه الشاشة فعلاً** لا من أعلى الشجرة.
    final TextDirection direction = Directionality.of(
      tester.element(find.byType(LoginScreen)),
    );
    expect(direction, TextDirection.rtl);
  });
}

/// ★★★ **شاشة الحساب المعطَّل** — `FR-M1-15` · `AM-018`.
///
/// ⛔⛔★★★ **وما تحرسه هذه الاختبارات ليس ظهورَ الرسالة بل وجودَ مخرَج:**
/// ★ **لا شيءَ خلف زرّ الخروج في هذه الشاشة إطلاقاً** — ⟵ **فزرٌّ يُضغَط بلا
/// أثرٍ مرئيٍّ ولا رسالةِ فشلٍ يترك الحسابَ المعطَّل عالقاً بلا مخرج**،
/// ★ **ويظنّ المستخدمُ التطبيقَ معطوباً لا اتصالَه.**
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qtms/capabilities/identity_access/application/session_providers.dart';
import 'package:qtms/capabilities/identity_access/presentation/session_blocked_screen.dart';
import 'package:qtms/core/ui/inline_banner.dart';

import '../../../support/fake_identity.dart';

void main() {
  late FakeAuthRepository auth;

  setUp(() => auth = FakeAuthRepository());
  tearDown(() => auth.dispose());

  Future<void> pumpBlocked(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
        ],
        child: const MaterialApp(
          locale: Locale('ar'),
          home: SessionBlockedScreen(),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('★ الزرُّ في حالته الساكنة مفعَّلٌ بنصّه', (
    WidgetTester tester,
  ) async {
    await pumpBlocked(tester);

    expect(find.widgetWithText(FilledButton, signOutLabel), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
    expect(find.byType(QtmsInlineBanner), findsNothing);
  });

  testWidgets(
    '★★ AM-018: الضغطُ يُبدّل النصَّ ويُعطّل الزر — ⛔ ولا ضغطتان تُنتجان نداءين',
    (WidgetTester tester) async {
      final Completer<void> gate = Completer<void>();
      auth.signOutGate = gate;
      await pumpBlocked(tester);
      await tester.tap(find.byType(FilledButton));
      await tester.pump();

      expect(find.text(signOutBusyLabel), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );

      // ⛔ **وضغطةٌ ثانيةٌ على المعطَّل لا تُنتج نداءً.**
      await tester.tap(find.byType(FilledButton), warnIfMissed: false);
      await tester.pump();
      expect(auth.signOutCalls, 1);

      gate.complete();
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    '⛔⛔★★★ AM-018: وفشلُ الخروج يُعرَض ويُعاد تفعيلُ الزر — ⛔ ولا يُبتلَع',
    (WidgetTester tester) async {
      auth.signOutThrows = true;
      await pumpBlocked(tester);

      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      // ★ **الفشلُ بنصّه** — ⛔ **ولا نصُّ المنصّة الخام.**
      expect(find.text(signOutFailureMessage), findsOneWidget);
      expect(find.byType(QtmsInlineBanner), findsOneWidget);
      expect(find.textContaining('StateError'), findsNothing);

      // ⛔⛔ **والزرُّ عاد مفعَّلاً بنصّه** — ⟵ **وزرٌّ يبقى معطَّلاً بعد
      //    الفشل يُغلق الشاشةَ بلا مخرج.**
      expect(find.widgetWithText(FilledButton, signOutLabel), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );

      // ★ **وإعادةُ المحاولة ممكنةٌ فعلاً.**
      auth.signOutThrows = false;
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(auth.signOutCalls, 2);
    },
  );
}

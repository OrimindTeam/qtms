/// صدَفة ما بعد الدخول — ★ **بلا موجّه**، فيُفحص المكوّن وحده.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qtms/capabilities/identity_access/application/session_providers.dart';
import 'package:qtms/capabilities/identity_access/presentation/home_shell.dart';
import 'package:qtms_domain/qtms_domain.dart';

import '../../../support/fake_identity.dart';

void main() {
  testWidgets(
    '★ تعرض الاسم والدور ونطاق المصادر',
    (WidgetTester tester) async {
      final FakeAuthRepository auth = FakeAuthRepository();
      final FakeUserCardRepository cards = FakeUserCardRepository();
      auth.emitIdentity(
        const AuthenticatedIdentity(userId: 'U-001', sourceScope: AllSources()),
      );
      cards.emitCard('U-001', testCard());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(auth),
            userCardRepositoryProvider.overrideWithValue(cards),
          ],
          child: const MaterialApp(
            locale: Locale('ar'),
            home: HomeShell(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));

      expect(find.text('عبدالفتاح'), findsOneWidget);
      expect(find.text('المالك'), findsOneWidget);
      expect(find.text('كل المصادر'), findsOneWidget);

      auth.dispose();
      cards.dispose();
    },
    timeout: const Timeout(Duration(seconds: 20)),
  );

  testWidgets(
    '⛔⛔★★★ كلُّ زيادةٍ منجَزة لها مدخلٌ في الصدَفة — ولا شاشةَ يتيمة',
    (WidgetTester tester) async {
      // ★★★ **اختبارُ ارتدادٍ لعطلٍ حقيقي رُصد على المحاكي (2026-08-26):**
      //    شاشةُ الجواني **مبنيّةٌ ومسارُها مسجَّل في `router.dart`**
      //    ⛔ **ولا زرَّ واحد يصل إليها** ⟵ **فكانت `WU-004` كلها غيرَ
      //    قابلةٍ للوصول من الواجهة.**
      //
      // ⚠️⚠️ **ولا اختبارَ آليٍّ واحدٍ كان يفشل بذلك:** اختبارات الشاشة
      //    **تبنيها مباشرةً** ⛔ **ولا تمرّ بالصدَفة** — ★ **فالفجوة كانت
      //    بين «الشاشة تعمل» و«المستخدم يصل إليها».**
      // ★ سطحٌ طويل — ⟵ **فتُبنى كلُّ المداخل** ⛔ **ولا يسقط واحدٌ لأنه
      //   خارج الشاشة وحدها**، وهو ما يُبطِل الغرض من الاختبار.
      tester.view.physicalSize = const Size(1200, 4200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final FakeAuthRepository auth = FakeAuthRepository();
      final FakeUserCardRepository cards = FakeUserCardRepository();
      auth.emitIdentity(
        const AuthenticatedIdentity(userId: 'U-001', sourceScope: AllSources()),
      );
      // ★ بطاقةٌ بكل الصلاحيات — فلا تُخفي بوابةٌ مدخلاً لسببٍ آخر.
      cards.emitCard(
        'U-001',
        testCard(permissions: Permission.values.toSet()),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(auth),
            userCardRepositoryProvider.overrideWithValue(cards),
          ],
          child: const MaterialApp(
            locale: Locale('ar'),
            home: HomeShell(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));

      for (final String label in <String>[
        'الوارد عدداً',
        'الوارد جواني',
        'مخزون اليوم',
        'التسعير اليومي',
      ]) {
        expect(
          find.text(label),
          findsOneWidget,
          reason: '⛔ لا مدخل للزيادة «$label» في الصدَفة',
        );
      }

      auth.dispose();
      cards.dispose();
    },
    timeout: const Timeout(Duration(seconds: 20)),
  );
}

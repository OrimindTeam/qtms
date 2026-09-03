/// صدَفة ما بعد الدخول — ★ **بلا موجّه**، فيُفحص المكوّن وحده.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qtms/capabilities/identity_access/application/session_providers.dart';
import 'package:qtms/capabilities/inventory/presentation/supply_intake_screen.dart';
import 'package:qtms/capabilities/identity_access/presentation/home_shell.dart';
import 'package:qtms/core/ui/avatar.dart';
import 'package:qtms_domain/qtms_domain.dart';

import '../../../support/fake_identity.dart';

void main() {
  testWidgets(
    '★ تعرض الهوية في الشريط — ⛔ ولا بطاقةَ دورٍ ونطاق (AM-009 ②)',
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

      // ⚠️★★★ **واسمُ المستخدم انتقل إلى الصورة الرمزية بـ`AM-008` ①** —
      //    ⟵ **فيُقاس بحرفه الأول لا بنصٍّ كامل**، ★ **ولا يسقط الفحص:
      //    الهويةُ ما زالت معروضة** ⛔ **بشكلٍ آخر.**
      expect(find.byType(QtmsAvatar), findsOneWidget);
      expect(
        tester.widget<QtmsAvatar>(find.byType(QtmsAvatar)).name,
        'عبدالفتاح',
      );
      // ★★ **واسمُ الشاشة في الشريط العلوي** — `AM-008` ①.
      expect(find.text('لوحة اليوم'), findsOneWidget);
      // ⛔⛔★★★ **ولا بطاقةَ هويةٍ في جسم الشاشة** — `AM-009` ②: ★ **كانت
      //    تعرض اسمَ الدور ونطاقَ المصادر في الطيّة الأولى**، ⟵ **وهما
      //    وصفُ حالةٍ لا مدخلُ عمل** ⛔ **فأُزيلا بطلب المالك.**
      //    ★ **والدورُ والنطاق يُقرآن في `PermissionsScreen`.**
      expect(find.text('المالك'), findsNothing);
      expect(find.text('كل المصادر'), findsNothing);
      // ⛔⛔★★★ **ولا أيقونةَ خروجٍ في الشريط** — `AM-009` ①: ★ **انتقلت
      //    إلى قائمة الجلسة على الصورة الرمزية.**
      expect(find.byIcon(Icons.logout), findsNothing);

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

      // ★★★ **ومدخلٌ واحدٌ للتوريد منذ `AM-012` §2** — ⟵ **«الوارد عدداً»
      //    و«الوارد جواني» تبويبان داخله** ⛔ **لا مدخلان في الصدَفة.**
      for (final String label in <String>[
        supplyIntakeScreenTitle,
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

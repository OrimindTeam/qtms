/// ★★★ حقلُ البحث اللاصق وحالةُ «لا نتيجة» — `MASTER.md` §5 «سرد»
/// (`ADR-0021`).
///
/// ⚠️⚠️ **وما تُثبته هذه الاختبارات:** أن **زرّ المسح يتبع النصّ ظهوراً
/// وغياباً**، وأنه **يُفرِّغ الحقل فعلاً**، وأن **المكوّن يُسلّم النصّ خاماً
/// بلا تطبيع** — ★ **فالتطبيع قاعدةُ نطاقٍ لا شأنَ عرضٍ** (`IQ-013`).
/// ⛔ **ولا تُثبت أن التصفية صحيحة** — ★ **فالتصفيةُ قرارُ المُنادي.**
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qtms/core/ui/search_field.dart';

Future<void> pumpField(
  WidgetTester tester,
  TextEditingController controller,
) =>
    tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: QtmsSearchField(
              controller: controller,
              label: 'بحث في الصلاحيات',
            ),
          ),
        ),
      ),
    );

void main() {
  group('★★ حقل البحث — QtmsSearchField', () {
    testWidgets('★★ زرُّ المسح يغيب على حقلٍ فارغ — ⛔ ولا زينةَ لا تفعل شيئاً',
        (WidgetTester tester) async {
      final TextEditingController controller = TextEditingController();
      addTearDown(controller.dispose);

      await pumpField(tester, controller);

      expect(find.text('بحث في الصلاحيات'), findsOneWidget);
      expect(find.byIcon(Icons.search), findsOneWidget);
      expect(find.byIcon(Icons.close), findsNothing);
    });

    testWidgets('★★★ ويظهر بالنصّ ثم يُفرِّغ الحقل فعلاً', (
      WidgetTester tester,
    ) async {
      final TextEditingController controller = TextEditingController();
      addTearDown(controller.dispose);

      await pumpField(tester, controller);
      await tester.enterText(find.byType(TextField), 'توزيع');
      await tester.pump();

      expect(find.byIcon(Icons.close), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();

      // ⟵ **ومسحُ بحثٍ بالتراجع حرفاً حرفاً ثمنٌ كان يدفعه المستخدم.**
      expect(controller.text, isEmpty);
      expect(find.byIcon(Icons.close), findsNothing);
    });

    testWidgets(
      '⛔⛔★★★ والنصُّ يُسلَّم خاماً — ★ ولا تطبيعَ في العرض (IQ-013)',
      (WidgetTester tester) async {
        final TextEditingController controller = TextEditingController();
        addTearDown(controller.dispose);

        await pumpField(tester, controller);
        // ★ **همزةُ وصلٍ ومسافاتٌ طرفية** — ⟵ **يعبران كما كُتبا.**
        await tester.enterText(find.byType(TextField), '  الادخال  ');
        await tester.pump();

        // ⛔ **ولا يقصّ المكوّن ولا يُطبِّع** — ★ **فالتطبيع عند المُنادي.**
        expect(controller.text, '  الادخال  ');
      },
    );
  });

  group('★★ حالة «لا نتيجة» — QtmsNoMatch', () {
    testWidgets('⛔⛔ والنصُّ يُسمّي ما بُحث عنه — ⛔ لا «لا نتائج» عارية', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('ar'),
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: QtmsNoMatch(message: 'لا صلاحية بهذا الاسم.'),
            ),
          ),
        ),
      );

      expect(find.text('لا صلاحية بهذا الاسم.'), findsOneWidget);
    });
  });
}

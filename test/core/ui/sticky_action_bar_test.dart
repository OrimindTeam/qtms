/// ★★★ شريط الإجراء الثابت — `MASTER.md` §5b (`P2` · `P4` · `P5` · `P8`).
///
/// ⚠️⚠️ **وما تُثبته هذه الاختبارات:** أن **الترتيب ملخّصٌ ← حالةٌ ← زرّ**،
/// وأن **ظهور اللافتة لا يُزيح الزرّ**، وأن **الحالة لا تُنقَل باللون وحده**.
/// ⛔ **ولا تُثبت أن الكتابة محميّة** — ★ **البوابةُ تلفّ الزرّ من الشاشة**
/// والرفضُ في السحابة (`RISK-02`).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qtms/core/ui/sticky_action_bar.dart';

Future<void> pumpBar(
  WidgetTester tester, {
  Widget? summary,
  Widget? status,
}) =>
    tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: ListView(
              children: <Widget>[
                for (int i = 0; i < 40; i++) Text('سطر رقم $i'),
              ],
            ),
            bottomNavigationBar: QtmsStickyActionBar(
              summary: summary,
              status: status,
              primary: FilledButton(
                onPressed: () {},
                child: const Text('حفظ'),
              ),
            ),
          ),
        ),
      ),
    );

void main() {
  group('⛔⛔★★★ الزرّ ثابتٌ أسفل الشاشة — ⛔ لا في ذيل قائمة', () {
    testWidgets('★ يبقى ظاهراً مع قائمةٍ أطول من الشاشة', (
      WidgetTester tester,
    ) async {
      await pumpBar(tester);

      // ★ **قائمةٌ من أربعين سطراً** — ⟵ **والزرُّ ظاهرٌ بلا تمرير.**
      expect(find.text('حفظ'), findsOneWidget);

      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pump();
      // ★★ **وبعد التمرير كما قبله** — ⛔ **فلا يُطارَد الزرّ.**
      expect(find.text('حفظ'), findsOneWidget);
    });

    testWidgets('★ والزرّ أسفل الملخّص والحالة معاً — ترتيبٌ ملزِم', (
      WidgetTester tester,
    ) async {
      await pumpBar(
        tester,
        summary: const Text('قيمة الضمار: 1200 ريال'),
        status: QtmsActionStatus.rejection('تعذّر إتمام العملية.'),
      );

      final double summaryY = tester.getCenter(
        find.text('قيمة الضمار: 1200 ريال'),
      ).dy;
      final double statusY =
          tester.getCenter(find.text('تعذّر إتمام العملية.')).dy;
      final double buttonY = tester.getCenter(find.text('حفظ')).dy;

      // ★★ **ملخّصٌ ← حالةٌ ← زرّ** — §5b: ⟵ **فالأثرُ والسببُ قبل الفعل.**
      expect(summaryY, lessThan(statusY));
      expect(statusY, lessThan(buttonY));
    });
  });

  group('⛔⛔★★★ ظهور اللافتة لا يُزيح الزرّ — عطلُ DistributionScreen', () {
    testWidgets('★ موضعُ الزرّ من الأسفل ثابتٌ قبل اللافتة وبعدها', (
      WidgetTester tester,
    ) async {
      await pumpBar(tester);
      final double before =
          tester.getBottomLeft(find.widgetWithText(FilledButton, 'حفظ')).dy;

      await pumpBar(
        tester,
        status: QtmsActionStatus.rejection('تعذّر إتمام العملية.'),
      );
      final double after =
          tester.getBottomLeft(find.widgetWithText(FilledButton, 'حفظ')).dy;

      // ⛔⛔★★★ **والشريط كلُّه يعلو معاً** — ⟵ **فحافّةُ الزرّ السفلى
      //    لا تتحرّك**، ★ **بخلاف لافتةٍ فوق الزرّ في محتوىً ممرَّر**
      //    ⟵ **تدفعه لأسفل فيقفز تحت الإصبع.**
      expect(after, before);
    });
  });

  group('⛔ ولا معنى باللون وحده — §8 المحظور الثاني عشر', () {
    testWidgets('★ لافتةُ الرفض بأيقونةٍ ونصّ معاً', (
      WidgetTester tester,
    ) async {
      await pumpBar(
        tester,
        status: QtmsActionStatus.rejection('تعذّر إتمام العملية.'),
      );
      expect(find.text('تعذّر إتمام العملية.'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('★ ولافتةُ النجاح بأيقونةٍ متجهية — ⛔ لا «✅» إيموجي', (
      WidgetTester tester,
    ) async {
      await pumpBar(tester, status: QtmsActionStatus.success('حُفظ.'));
      expect(find.text('حُفظ.'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
      // ⛔ **ولا إيموجي في نصّ اللافتة** (§9).
      expect(find.textContaining('✅'), findsNothing);
    });
  });

  testWidgets('★ وبلا ملخّصٍ ولا حالة يبقى الزرّ وحده — ⛔ بلا فراغٍ زائد', (
    WidgetTester tester,
  ) async {
    await pumpBar(tester);
    expect(find.byType(QtmsActionStatus), findsNothing);
    expect(find.text('حفظ'), findsOneWidget);
  });
}

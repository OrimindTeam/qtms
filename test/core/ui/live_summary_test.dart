/// ★★★ الميزان الحيّ — `MASTER.md` §5b نمط `P5` (`ADR-0021`).
///
/// ⚠️⚠️ **وما تُثبته:** أن **الميزان لا يختفي عند الرفض بل يحمل سببه**
/// (`DEBT-47`)، وأن **الإجراء المشروط داخله لا تحت الزر**، وأن **الحالة نصٌّ
/// لا لونٌ وحده**. ⛔ **ولا تُثبت صحّة رقمٍ** — ★ **الحساب في طبقة النطاق**
/// ولها اختباراتها.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qtms/core/design/design_tokens.dart';
import 'package:qtms/core/ui/live_summary.dart';
import 'package:qtms/core/ui/status_pill.dart';

Future<void> pumpSummary(WidgetTester tester, QtmsLiveSummary summary) =>
    tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: summary),
        ),
      ),
    );

void main() {
  group('⛔⛔★★★ لا يختفي عند الرفض — DEBT-47', () {
    testWidgets('★★ السطرُ الأول باقٍ والسببُ معه', (
      WidgetTester tester,
    ) async {
      await pumpSummary(
        tester,
        const QtmsLiveSummary(
          headline: 'الوزن المطالب به: 0.000 كجم',
          rejection: 'وزن الثلج أكبر من الوزن الكلي',
        ),
      );

      // ⛔ **فلا فراغَ بلا رقمٍ ولا سبب** — ★ **والمستخدم يُصحِّح وهو ينظر.**
      expect(find.text('الوزن المطالب به: 0.000 كجم'), findsOneWidget);
      expect(find.text('وزن الثلج أكبر من الوزن الكلي'), findsOneWidget);
    });

    testWidgets('★ وبلا رفضٍ لا لافتةَ رفض', (WidgetTester tester) async {
      await pumpSummary(
        tester,
        const QtmsLiveSummary(headline: 'الوزن المطالب به: 30.000 كجم'),
      );
      expect(find.byIcon(Icons.error_outline), findsNothing);
    });
  });

  group('⛔⛔★★★ الإجراء المشروط داخل الميزان — لا تحت الزر الأساسي', () {
    testWidgets('★★ ويُرسَم ضمن الميزان نفسِه', (WidgetTester tester) async {
      await pumpSummary(
        tester,
        QtmsLiveSummary(
          headline: 'فُسِّر 35.000 من 37.300 كجم',
          progress: 0.93,
          conditionalAction: OutlinedButton(
            onPressed: () {},
            child: const Text('تأكيد الوزن الضائع (2.300 كجم)'),
          ),
        ),
      );

      // ⟵ **فلا يقفز الزرُّ الأساسي تحت الإصبع حين تتغيّر الحالة.**
      expect(
        find.descendant(
          of: find.byType(QtmsLiveSummary),
          matching: find.text('تأكيد الوزن الضائع (2.300 كجم)'),
        ),
        findsOneWidget,
      );
    });
  });

  group('★★ الحالةُ حبّةٌ موحّدة — ⛔ ولا رسمَ محلّياً', () {
    testWidgets('★ تُرسَم بـ`StatusPill` بنصّها', (WidgetTester tester) async {
      await pumpSummary(
        tester,
        const QtmsLiveSummary(
          headline: 'فُسِّر 35.000 من 37.300 كجم',
          progress: 0.93,
          status: QtmsSummaryStatus(
            label: 'متبقٍ 2.300 كجم',
            triad: SemanticTriads.warning,
          ),
        ),
      );

      expect(find.byType(StatusPill), findsOneWidget);
      // §6.د — ⛔ **ولا معنى بلونٍ وحده.**
      expect(find.text('متبقٍ 2.300 كجم'), findsOneWidget);
    });
  });

  testWidgets('★ وبلا نسبةٍ لا شريطَ تقدّم — صورتان لمكوّنٍ واحد', (
    WidgetTester tester,
  ) async {
    await pumpSummary(
      tester,
      const QtmsLiveSummary(headline: 'الوزن المطالب به: 30.000 كجم'),
    );
    expect(find.byType(LinearProgressIndicator), findsNothing);

    await pumpSummary(
      tester,
      const QtmsLiveSummary(headline: 'فُسِّر 1 من 2', progress: 0.5),
    );
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });
}

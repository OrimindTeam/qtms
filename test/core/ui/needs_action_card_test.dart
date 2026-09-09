/// ★★★ بوابةُ بطاقة «يحتاج إجراء» — `design-system.md` §7 (`AM-017` ③).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qtms/core/design/design_tokens.dart';
import 'package:qtms/core/ui/needs_action_card.dart';
import 'package:qtms/core/ui/needs_action_row.dart';
import 'package:qtms/core/ui/status_pill.dart';

Widget row(String title, int count) => QtmsNeedsActionRow(
      isFramed: false,
      icon: Icons.hourglass_bottom_outlined,
      title: title,
      destination: 'وجهةُ $title',
      count: count,
      triad: SemanticTriads.warning,
      onTap: () {},
      chips: <Widget>[
        StatusPill(label: 'جواني $count', triad: SemanticTriads.warning),
      ],
    );

Future<void> pumpCard(
  WidgetTester tester, {
  required int total,
  bool isTotalKnown = true,
}) =>
    tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: SingleChildScrollView(
              child: QtmsNeedsActionCard(
                total: total,
                isTotalKnown: isTotalKnown,
                rows: <Widget>[row('الإدخالات المعلّقة', 2), row('متبقي', 1)],
              ),
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets('★★★ ترويسةٌ موحّدةٌ بعدّادٍ إجمالي ⛔ لا عدّادان منفصلان',
      (WidgetTester tester) async {
    await pumpCard(tester, total: 3);

    expect(find.text('يحتاج إجراء'), findsOneWidget);
    expect(find.text('3 بنود'), findsOneWidget);
  });

  testWidgets('★★ ومبسوطةٌ حين يوجد عمل — البنودُ ورقائقُها مرسومة',
      (WidgetTester tester) async {
    await pumpCard(tester, total: 3);

    expect(find.text('الإدخالات المعلّقة'), findsOneWidget);
    expect(find.text('متبقي'), findsOneWidget);
    expect(find.text('جواني 2'), findsOneWidget);
  });

  testWidgets('⛔⛔★★★ ولا تُخفى عند الصفر — تُعرَض مطويّةً بنصٍّ صريح',
      (WidgetTester tester) async {
    await pumpCard(tester, total: 0);

    // ★ **البطاقةُ قائمة** — ⟵ **فاختفاؤها يجعل المستخدم يشكّ: أصفرٌ أم عطل؟**
    expect(find.byType(QtmsNeedsActionCard), findsOneWidget);
    expect(find.text('لا شيء يحتاج إجراءً اليوم'), findsOneWidget);
    expect(find.text('لا شيء'), findsOneWidget);
    // ⛔ **والتفاصيلُ مطويّة** — ★ **فاللوحةُ لا تُهدر ثلثَ الشاشة على فراغ.**
    expect(find.text('الإدخالات المعلّقة'), findsNothing);
  });

  testWidgets('★★ والنقرُ على الترويسة يكشف البنود — وقرارُ المستخدم يعلو',
      (WidgetTester tester) async {
    await pumpCard(tester, total: 0);
    expect(find.text('الإدخالات المعلّقة'), findsNothing);

    await tester.tap(find.text('لا شيء يحتاج إجراءً اليوم'));
    await tester.pumpAndSettle();

    expect(find.text('الإدخالات المعلّقة'), findsOneWidget);
  });

  testWidgets('⚠️★★ وأثناء التحميل «—» ⛔ لا صفرٌ مؤقّتٌ يُقرأ عطلاً',
      (WidgetTester tester) async {
    await pumpCard(tester, total: 0, isTotalKnown: false);

    expect(find.text('—'), findsOneWidget);
    expect(find.text('لا شيء'), findsNothing);
  });

  testWidgets(
      '⛔⛔★★★ ولا تُدَّعى الحالةُ الهادئة قبل اكتمال القياس — رُصد على المحاكي',
      (WidgetTester tester) async {
    await pumpCard(tester, total: 0, isTotalKnown: false);

    // ⛔ **«لم يكتمل القياس» ليست «لا شيء»** — ⟵ **والحالةُ ثلاثيةٌ لا ثنائية.**
    expect(find.text('لا شيء يحتاج إجراءً اليوم'), findsNothing);
    expect(find.text('يحتاج إجراء'), findsOneWidget);
    // ★ **والبنودُ مبسوطةٌ ما دام القياسُ ناقصاً** — ⛔ **ولا طيَّ على مجهول.**
    expect(find.text('الإدخالات المعلّقة'), findsOneWidget);
  });
}

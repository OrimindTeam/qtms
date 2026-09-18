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

  // ═══════════════ ★★★ تطابقُ العدد عربياً — `AM-017` (رُصد على المحاكي) ═══
  //
  // ⛔⛔ **الترويسةُ كانت تعرض «42 بنود» على `Pixel_6_API_36`** — ⟵ **خطأٌ
  //    نحويٌّ صريح**: ★ **و11 فأكثرُ يُميَّز بمفردٍ منصوب.**
  test('★★★ تطابقُ العدد — مفردٌ ومثنّى وجمعُ قلّةٍ ومفردٌ منصوب', () {
    expect(needsActionCountLabel(0), 'لا شيء');
    expect(needsActionCountLabel(1), 'بندٌ واحد');
    expect(needsActionCountLabel(2), 'بندان');
    // ★ **جمعُ القلّة 3…10.**
    expect(needsActionCountLabel(3), '3 بنود');
    expect(needsActionCountLabel(10), '10 بنود');
    // ⛔⛔ **ومن 11 فصاعداً مفردٌ منصوب** — ⛔ **لا «بنود».**
    expect(needsActionCountLabel(11), '11 بنداً');
    expect(needsActionCountLabel(42), '42 بنداً');
    expect(needsActionCountLabel(100), '100 بنداً');
  });

  testWidgets('★★ والترويسةُ تستعمل التسميةَ نفسَها ⛔ لا جمعاً محفوراً',
      (WidgetTester tester) async {
    await pumpCard(tester, total: 42);

    expect(find.text('42 بنداً'), findsOneWidget);
    expect(find.text('42 بنود'), findsNothing);
  });
}

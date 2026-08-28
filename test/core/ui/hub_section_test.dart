/// ★★★ قسمُ الصدَفة `QtmsHubSection` — `MASTER.md` §5b نمط `P1` (`ADR-0021`).
///
/// ⚠️⚠️ **وما تُثبته:** أن **القسمَ يختفي كلُّه بلا مداخل** ⛔ **فلا فجوةٌ
/// مكدَّسة ولا عنوانُ قسمٍ فارغ**، وأن **الفواصلَ داخل المكوّن لا أشقّاءَ له**،
/// وأن **المدخلَ الأساسي أبرزُ من الثانوي**.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qtms/core/ui/hub_section.dart';

Future<void> pumpSection(
  WidgetTester tester, {
  required List<Widget> children,
  String title = 'العمليات اليومية',
}) =>
    tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: QtmsHubSection(title: title, children: children),
          ),
        ),
      ),
    );

QtmsHubButton entry(String label, {bool primary = false}) => QtmsHubButton(
      entry: QtmsHubEntry(
        label: label,
        icon: Icons.circle_outlined,
        onPressed: () {},
        isPrimary: primary,
      ),
    );

void main() {
  group('⛔⛔★★★ القسمُ يختفي كلُّه بلا مداخل — لا فجوةٌ مكدَّسة', () {
    testWidgets('★ قسمٌ بلا مداخل لا يعرض عنوانه ولا يشغل ارتفاعاً', (
      WidgetTester tester,
    ) async {
      await pumpSection(tester, children: const <Widget>[]);

      // ⛔ **ولا عنوانُ قسمٍ فارغ** — ⟵ **فمن لا يملك مفاتيحه لا يرى أثره.**
      expect(find.text('العمليات اليومية'), findsNothing);
      expect(
        tester.getSize(find.byType(QtmsHubSection)).height,
        0,
        reason: '★ القسمُ الفارغ يشغل ارتفاعاً — وهي الفجوة المكدَّسة نفسُها',
      );
    });

    testWidgets('★ وقسمٌ بمدخلٍ واحد يعرض عنوانه ومدخله', (
      WidgetTester tester,
    ) async {
      await pumpSection(tester, children: <Widget>[entry('التوزيع')]);

      expect(find.text('العمليات اليومية'), findsOneWidget);
      expect(find.text('التوزيع'), findsOneWidget);
    });
  });

  group('★★ الهرمُ البصري — §7: زرُّ إجراءٍ رئيسي واحد', () {
    testWidgets('★ الأساسي `FilledButton` والثانوي `OutlinedButton`', (
      WidgetTester tester,
    ) async {
      await pumpSection(
        tester,
        children: <Widget>[
          entry('التوزيع', primary: true),
          entry('الوارد عدداً'),
          entry('مخزون اليوم'),
        ],
      );

      // ⟵ **فأكثرُ المداخل تكراراً يُرى أولاً** — ⛔ **ولا ثلاثةَ عشرَ بوزنٍ واحد.**
      expect(find.byType(FilledButton), findsOneWidget);
      expect(find.byType(OutlinedButton), findsNWidgets(2));
    });

    testWidgets('⛔ ولا معنى بأيقونةٍ وحدها — النصُّ إلزاميٌّ في العقد', (
      WidgetTester tester,
    ) async {
      await pumpSection(tester, children: <Widget>[entry('التوزيع')]);
      // §8 المحظور الثاني عشر — ★ **والنوعُ نفسُه يفرض `label`.**
      expect(find.text('التوزيع'), findsOneWidget);
    });
  });

  testWidgets('★★ والفواصلُ داخل المكوّن — ⛔ لا `SizedBox` أشقّاءَ له', (
    WidgetTester tester,
  ) async {
    await pumpSection(
      tester,
      children: <Widget>[entry('أ'), entry('ب'), entry('ج')],
    );

    final double a = tester.getBottomLeft(find.text('أ')).dy;
    final double b = tester.getTopLeft(find.text('ب')).dy;
    // ★ **فاصلٌ حقيقي بين المدخلين** — ⟵ **ويأتي من القسم لا من الشاشة.**
    expect(b, greaterThan(a));
  });
}

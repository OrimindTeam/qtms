/// ★★ بوابةُ شريط النسبة — `design-system.md` §6.د (`AM-017` ④).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qtms/core/design/design_tokens.dart';
import 'package:qtms/core/ui/proportion_bar.dart';

Future<void> pumpBar(
  WidgetTester tester, {
  required double part,
  required double total,
  String startLabel = 'أُودع 300,000',
  String endLabel = 'لم يُودع بعد 120,000',
}) =>
    tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: SizedBox(
              width: 320,
              child: QtmsProportionBar(
                part: part,
                total: total,
                startLabel: startLabel,
                endLabel: endLabel,
              ),
            ),
          ),
        ),
      ),
    );

QtmsProportionBar bar({required double part, required double total}) =>
    QtmsProportionBar(
      part: part,
      total: total,
      startLabel: 'أ',
      endLabel: 'ب',
    );

void main() {
  group('★★ الكسرُ مقصورٌ ولا يرمي — §6.د', () {
    test('★ نسبةٌ عادية', () {
      expect(bar(part: 300, total: 420).fraction, closeTo(0.714, 0.001));
    });

    test('⛔ ومجموعٌ صفرٌ لا يرمي — يُقرأ صفراً', () {
      expect(bar(part: 0, total: 0).fraction, 0);
      expect(bar(part: 5, total: 0).fraction, 0);
    });

    test('⛔ وتجاوزٌ يُقصَر إلى الواحد ⛔ لا يفيض', () {
      expect(bar(part: 900, total: 420).fraction, 1);
    });

    test('⛔ وسالبٌ يُقصَر إلى الصفر', () {
      expect(bar(part: -10, total: 420).fraction, 0);
    });
  });

  testWidgets('⛔⛔★★★ التسميتان تحملان المعنى — فلا لونَ وحده (§8 المحظور 12)',
      (WidgetTester tester) async {
    await pumpBar(tester, part: 300000, total: 420000);

    expect(find.text('أُودع 300,000'), findsOneWidget);
    expect(find.text('لم يُودع بعد 120,000'), findsOneWidget);
  });

  testWidgets('⛔★★ والمجموعُ صفراً يُرسَم شريطاً محايداً كاملاً ⛔ لا يُخفى',
      (WidgetTester tester) async {
    await pumpBar(tester, part: 0, total: 0);

    // ★ **الشريطُ قائمٌ بارتفاعه المقرَّر** — ⟵ **فالصفرُ معلومةٌ تُعرَض.**
    expect(find.byType(QtmsProportionBar), findsOneWidget);
    final Size size = tester.getSize(
      find.descendant(
        of: find.byType(QtmsProportionBar),
        matching: find.byType(ClipRRect),
      ),
    );
    expect(size.height, Sizes.proportionBarHeight);
  });
}

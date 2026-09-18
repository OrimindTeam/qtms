/// ★★★ بوابةُ الصفر الابتدائي — `AM-027` ① (`sack-intake-design.md` §13).
///
/// ⛔⛔★★★ **والعطلُ المقيس الذي تحرسه:** ★ **حقلٌ يبدأ بـ`0` كان يجعل `4`
/// تصير `40`** ⟵ **لأن المؤشّر يقع قبل الصفر**: ⟹ **فهذه البوابة تُثبت أن
/// الصفرَ يُفرَّغ عند التركيز ويعود عند الفراغ** ⛔ **وأن رقمَ المستخدم لا
/// يُمَسّ أبداً.**
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qtms/core/ui/zero_placeholder.dart';

void main() {
  group('★★ الدالّتان النقيّتان — حدودُهما مقيسة', () {
    test('★ التركيزُ يُفرِغ الصفرَ الابتدائي وحدَه', () {
      expect(zeroPlaceholderOnFocus('0'), '');
      // ⛔ **ورقمُ المستخدم لا يُمَسّ** — ★ **ولو بدأ بصفر.**
      expect(zeroPlaceholderOnFocus('0.5'), '0.5');
      expect(zeroPlaceholderOnFocus('04'), '04');
      expect(zeroPlaceholderOnFocus('4'), '4');
      expect(zeroPlaceholderOnFocus(''), '');
    });

    test('★ وفقدُ التركيز يُعيد الصفرَ للفارغ وحدَه', () {
      expect(zeroPlaceholderOnBlur(''), '0');
      expect(zeroPlaceholderOnBlur('   '), '0');
      expect(zeroPlaceholderOnBlur('4'), '4');
      expect(zeroPlaceholderOnBlur('0'), '0');
    });
  });

  group('★★★ الحقلُ — سلوكُه الفعليُّ على الشجرة', () {
    testWidgets('⛔⛔ إدخالُ 4 على حقلٍ يبدأ بصفرٍ يعطي 4 — ⛔ لا 40', (
      WidgetTester tester,
    ) async {
      final TextEditingController controller =
          TextEditingController(text: '0');
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ar'),
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: QtmsZeroPlaceholderField(
                controller: controller,
                label: 'وزن الثلج',
                onChanged: () {},
              ),
            ),
          ),
        ),
      );

      // ★ **قبل اللمس: القيمةُ الابتدائيةُ ظاهرةٌ كما كانت.**
      expect(controller.text, '0');

      await tester.tap(find.byType(TextField));
      await tester.pump();
      expect(controller.text, '', reason: '⛔ الصفرُ لم يُفرَّغ عند التركيز');

      await tester.enterText(find.byType(TextField), '4');
      await tester.pump();
      expect(controller.text, '4');
    });

    testWidgets('★★ وتركُ الحقل فارغاً يُعيد الصفر عند فقد التركيز', (
      WidgetTester tester,
    ) async {
      final TextEditingController controller =
          TextEditingController(text: '0');
      final FocusNode other = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(other.dispose);

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ar'),
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: Column(
                children: <Widget>[
                  QtmsZeroPlaceholderField(
                    controller: controller,
                    label: 'وزن السكرب',
                    onChanged: () {},
                  ),
                  TextField(focusNode: other),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(TextField).first);
      await tester.pump();
      expect(controller.text, '');

      // ★ **الانتقالُ إلى حقلٍ آخر** — ⟵ **فقدُ تركيزٍ حقيقيّ.**
      other.requestFocus();
      await tester.pump();
      expect(controller.text, '0', reason: '⛔ الفراغُ لم يعد صفراً');
    });

    testWidgets('⛔ ورقمُ المستخدم يبقى بعد فقد التركيز', (
      WidgetTester tester,
    ) async {
      final TextEditingController controller =
          TextEditingController(text: '0');
      final FocusNode other = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(other.dispose);

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ar'),
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: Column(
                children: <Widget>[
                  QtmsZeroPlaceholderField(
                    controller: controller,
                    label: 'وزن الثلج',
                    onChanged: () {},
                  ),
                  TextField(focusNode: other),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(TextField).first);
      await tester.pump();
      await tester.enterText(find.byType(TextField).first, '4.5');
      await tester.pump();

      other.requestFocus();
      await tester.pump();
      expect(controller.text, '4.5');
    });
  });
}

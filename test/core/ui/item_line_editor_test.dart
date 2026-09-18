/// ★★★ **صفُّ سطر النوع المشترك** — `AM-009` ④ · `ui-guidelines.md`.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **ولماذا وُجد هذا الملف — `DEBT-88` مقيسٌ على المحاكي (2026-09-02):**
/// ★ **[DropdownMenu] يقرأ `initialSelection` عند إنشائه وحدَه** —
/// ⟵ **وخياراتٌ تصل بعده لا تُحدِّث النصَّ المعروض**: ⟹ ⛔⛔ **فيُفتَح
/// نموذجُ تعديل التوزيعة بحقلِ نوعٍ يبدو فارغاً والنوعُ مختارٌ فعلاً**
/// (**الكميةُ والسعرُ مبذوران بجانبه**) — ★ **فيُقرأ فقداناً للمُدخَل.**
///
/// ⛔ **ولم يكشفه اختبارٌ قطّ** — ★ **هذه الطبقة لم تكن مُختبَرةً**:
/// ⟵ **رابعَ عشرَ أوجهِ `DEBT-37`.**
/// ═══════════════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qtms/core/ui/item_line_editor.dart';

/// ★ يبني الصفَّ بخياراتٍ تُبدَّل بين إطارين — **محاكاةُ بثٍّ يصل متأخراً.**
class _Harness extends StatefulWidget {
  const _Harness({required this.initialOptions, required this.lateOptions});

  final List<QtmsItemOption> initialOptions;
  final List<QtmsItemOption> lateOptions;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  late List<QtmsItemOption> _options = widget.initialOptions;

  void deliverLate() => setState(() => _options = widget.lateOptions);

  @override
  Widget build(BuildContext context) => MaterialApp(
        locale: const Locale('ar'),
        home: Scaffold(
          body: QtmsItemLineRow(
            options: _options,
            selectedId: 'ITM-0002',
            onSelected: (_) {},
            onRemove: () {},
          ),
        ),
      );
}

void main() {
  const QtmsItemOption sella =
      QtmsItemOption(id: 'ITM-0002', label: 'سلة (30 حبة)');
  const QtmsItemOption atoud =
      QtmsItemOption(id: 'ITM-0003', label: 'عتود (100 حبة)');

  testWidgets('✅ الخياراتُ حاضرةٌ من أول إطار ⟵ النصُّ يظهر', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const _Harness(
        initialOptions: <QtmsItemOption>[sella, atoud],
        lateOptions: <QtmsItemOption>[sella, atoud],
      ),
    );
    await tester.pumpAndSettle();

    expect(_fieldText(tester), 'سلة (30 حبة)');
  });

  testWidgets(
    '⛔⛔★★★ DEBT-88: خياراتٌ تصل بعد الإنشاء ⟵ النصُّ يظهر كذلك',
    (WidgetTester tester) async {
      // ★ **أولُ إطارٍ بلا خيارات** — ⟵ **وهو حال بثِّ الأنواع لحظةَ فتح
      //   الورقة**، ⛔ **وقبل العلاج كان الحقلُ يبقى فارغاً أبداً.**
      await tester.pumpWidget(
        const _Harness(
          initialOptions: <QtmsItemOption>[],
          lateOptions: <QtmsItemOption>[sella, atoud],
        ),
      );
      await tester.pumpAndSettle();
      expect(_fieldText(tester), isEmpty);

      final _HarnessState state = tester.state<_HarnessState>(
        find.byType(_Harness),
      );
      state.deliverLate();
      await tester.pumpAndSettle();

      expect(_fieldText(tester), 'سلة (30 حبة)');
    },
  );

  testWidgets('⛔ وتبدّلُ نصِّ الخيار وحدَه لا يُعيد بناءه بلا داعٍ', (
    WidgetTester tester,
  ) async {
    // ★ **المتبقّي يتغيّر بعد كل حفظ** — ⟵ **والعددُ ثابت**:
    //   ⛔ **فلا يُهدَم المنسدل** ★ **ويبقى النصُّ صحيحاً بعد التحديث.**
    await tester.pumpWidget(
      const _Harness(
        initialOptions: <QtmsItemOption>[sella, atoud],
        lateOptions: <QtmsItemOption>[
          QtmsItemOption(id: 'ITM-0002', label: 'سلة (20 حبة)'),
          atoud,
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(_fieldText(tester), 'سلة (30 حبة)');

    tester.state<_HarnessState>(find.byType(_Harness)).deliverLate();
    await tester.pumpAndSettle();

    // ⚠️ **والنصُّ المعروض يبقى الأولَ** — ★ **لأن المنسدل لم يُعَد بناؤه**:
    //   ⛔ **وهو المقصود** — ⟵ **فإعادةُ بنائه في كل تحديثِ رصيدٍ تُفقِد
    //   المستخدمَ ما يكتبه.**
    expect(_fieldText(tester), 'سلة (30 حبة)');
  });

  group('★★★ متحكّمُ البحث وزرُّ النوع الجديد — `AM-027` ②', () {
    testWidgets('★★ ما يُكتَب في المنسدل يصل المُنادي عبر [onSearchChanged]', (
      WidgetTester tester,
    ) async {
      String typed = '';

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ar'),
          home: Scaffold(
            body: QtmsItemLineRow(
              options: const <QtmsItemOption>[sella, atoud],
              selectedId: null,
              onSelected: (_) {},
              onRemove: () {},
              onSearchChanged: (String text) => typed = text,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'عوارض');
      await tester.pump();

      // ⟹ ★ **وهو ما يُهيَّأ به نموذجُ «إضافة نوع جديد»** — ⛔ **فلا يُعيد
      //    المستخدمُ كتابةَ الاسم مرتين.**
      expect(typed, 'عوارض');
    });

    testWidgets(
        '⛔⛔★★★ وتبدُّلُ الخيارات لا يُشعِر نسخةً مُبطَلة — العطلُ المقيس',
        (WidgetTester tester) async {
      // ★★ **هذا هو الانهيارُ الذي أسقط اختبارين فعلاً**: ⟵ **متحكّمٌ واحدٌ
      //    يعبر نسختين** ⟹ **`Cannot get renderObject of inactive element`.**
      await tester.pumpWidget(
        const _Harness(
          initialOptions: <QtmsItemOption>[sella],
          lateOptions: <QtmsItemOption>[sella, atoud],
        ),
      );
      await tester.pumpAndSettle();

      // ★ **تركيزٌ حقيقيٌّ على الحقل** — ⟵ **فمؤشّرُ الكتابة يعمل.**
      await tester.tap(find.byType(TextField).first);
      await tester.pumpAndSettle();

      tester.state<_HarnessState>(find.byType(_Harness)).deliverLate();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('⛔⛔ وزرُّ «إضافة نوع جديد» لا يُعطَّل أبداً', (
      WidgetTester tester,
    ) async {
      int taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ar'),
          home: Scaffold(
            body: QtmsCreateItemButton(onPressed: () => taps++),
          ),
        ),
      );

      expect(find.text('إضافة نوع جديد'), findsOneWidget);
      await tester.tap(find.byType(OutlinedButton));
      expect(taps, 1, reason: '⛔ الزرُّ لا يستجيب — والكتالوجُ لا يُستنفَد');
    });
  });
}

/// ★ نصُّ حقلِ المنسدل المعروض — ⛔ **لا نصُّ عناصر القائمة.**
String _fieldText(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField).first).controller!.text;

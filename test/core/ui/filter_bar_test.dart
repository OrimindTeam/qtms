/// ★★★ شريطُ المرشِّحات وشريطُ الإجراء الجماعي — `MASTER.md` §5b
/// (`P4` · `P7`) · `ADR-0021`.
///
/// ⚠️⚠️ **وما تُثبته هذه الاختبارات:** أن **حارس `if (on)` قائمٌ في المكوّن
/// وحده** فلا يُمسَح المرشِّح بلمسةٍ ثانية، وأن **المجموعات صفوفٌ مستقلة**،
/// وأن **الحشو من المُنادي**، وأن **العدّاد حاضرٌ ولو غاب الإجراء**.
/// ⛔ **ولا تُثبت أن القراءة محميّة** — ★ **الفلترُ عرضٌ**، **والقيدُ الحقيقي
/// في `firestore.rules`** (`IQ-024` · `GR-23` · `RISK-02`).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qtms/core/design/design_tokens.dart';
import 'package:qtms/core/ui/filter_bar.dart';

Future<void> pumpBar(WidgetTester tester, Widget bar) => tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: bar),
        ),
      ),
    );

void main() {
  group('★★ شريط المرشِّحات — QtmsFilterBar', () {
    testWidgets(
      '⛔⛔★★★ حارسُ `if (on)` في المكوّن — ★ إلغاءُ تحديد المحدَّد لا يُنادي',
      (WidgetTester tester) async {
        int calls = 0;
        await pumpBar(
          tester,
          QtmsFilterBar(
            groups: <List<QtmsFilterOption>>[
              <QtmsFilterOption>[
                QtmsFilterOption(
                  label: 'الكل',
                  selected: true,
                  onSelected: () => calls++,
                ),
              ],
            ],
          ),
        );

        // ★ **ضغطُ الشريحة المحدَّدة أصلاً** — ⟵ **`ChoiceChip` تنادي بـ`false`.**
        await tester.tap(find.text('الكل'));
        await tester.pump();

        // ⛔⛔ **ولا نداءَ واحد** — ★ **وسقوطُ الحارس كان يمسح المرشِّح.**
        expect(calls, 0);
      },
    );

    testWidgets('★ وضغطُ غير المحدَّد يُنادي مرةً واحدة', (
      WidgetTester tester,
    ) async {
      int calls = 0;
      await pumpBar(
        tester,
        QtmsFilterBar(
          groups: <List<QtmsFilterOption>>[
            <QtmsFilterOption>[
              QtmsFilterOption(
                label: 'تم التسعير',
                selected: false,
                onSelected: () => calls++,
              ),
            ],
          ],
        ),
      );

      await tester.tap(find.text('تم التسعير'));
      await tester.pump();

      expect(calls, 1);
    });

    testWidgets('★★ ومجموعتان صفّان مستقلّان — ⛔ لا صفٌّ واحد يجمعهما', (
      WidgetTester tester,
    ) async {
      await pumpBar(
        tester,
        QtmsFilterBar(
          groups: <List<QtmsFilterOption>>[
            <QtmsFilterOption>[
              QtmsFilterOption(
                label: 'مصدر أول',
                selected: true,
                onSelected: () {},
              ),
            ],
            <QtmsFilterOption>[
              QtmsFilterOption(
                label: 'كل الأفعال',
                selected: true,
                onSelected: () {},
              ),
            ],
          ],
        ),
      );

      // ★ **صفَّا `Wrap` اثنان لا واحد** — ⟵ **فالبُعد الثانوي فوق الأساسي.**
      expect(find.byType(Wrap), findsNWidgets(2));
      // ★★ **والثاني أسفلَ الأول** — ⛔ **لا بجانبه.**
      expect(
        tester.getTopLeft(find.text('كل الأفعال')).dy,
        greaterThan(tester.getTopLeft(find.text('مصدر أول')).dy),
      );
    });

    testWidgets('⛔★★ والحشوُ من المُنادي — `padded: false` بلا حشوِ شاشة', (
      WidgetTester tester,
    ) async {
      final List<QtmsFilterOption> group = <QtmsFilterOption>[
        QtmsFilterOption(label: 'الكل', selected: true, onSelected: () {}),
      ];

      await pumpBar(
        tester,
        QtmsFilterBar(
          padded: false,
          groups: <List<QtmsFilterOption>>[group],
        ),
      );
      final double bare = tester.getTopLeft(find.byType(Wrap)).dy;

      await pumpBar(
        tester,
        QtmsFilterBar(groups: <List<QtmsFilterOption>>[group]),
      );
      final double padded = tester.getTopLeft(find.byType(Wrap)).dy;

      // ⛔⛔ **وحشوٌ مزدوج كان يُبعده عن حافّة الرأس** (`DailyPricingScreen`).
      expect(padded - bare, Spacing.space8);
    });

    testWidgets('⚠️★★ ونطاقٌ فارغ نصٌّ يشرح السبب — ⛔ لا فراغ (E-35)', (
      WidgetTester tester,
    ) async {
      await pumpBar(
        tester,
        const QtmsFilterBar.notice(
          message: 'لا يوجد مصدر ضمن نطاقك. راجع المدير.',
        ),
      );

      expect(find.text('لا يوجد مصدر ضمن نطاقك. راجع المدير.'), findsOneWidget);
      // ⛔ **ولا شريحةَ واحدة** — ★ **فلا يُوهَم بمرشِّحٍ لا وجود له.**
      expect(find.byType(ChoiceChip), findsNothing);
    });
  });

  group('★★ شريط الإجراء الجماعي — QtmsBulkActionBar', () {
    testWidgets('★★★ العدّادُ والإجراء معاً — §5b P4 البند ③', (
      WidgetTester tester,
    ) async {
      await pumpBar(
        tester,
        QtmsBulkActionBar(
          headline: 'سُعِّر 3 من 12',
          action: OutlinedButton(
            onPressed: () {},
            child: const Text('نسخ أسعار أمس'),
          ),
        ),
      );

      // ★★ **أرقامٌ لاتينية** (`AM-003`) — ⛔ **ولا مصطلحَ تقني** (§6).
      expect(find.text('سُعِّر 3 من 12'), findsOneWidget);
      expect(find.text('نسخ أسعار أمس'), findsOneWidget);
    });

    testWidgets('★ وغيابُ الإجراء يُبقي العدّاد — ⛔ ولا زرَّ عاطلاً', (
      WidgetTester tester,
    ) async {
      await pumpBar(tester, const QtmsBulkActionBar(headline: 'سُعِّر 0 من 5'));

      expect(find.text('سُعِّر 0 من 5'), findsOneWidget);
      // ⚠️ **فزرٌّ لا يفعل شيئاً أسوأ من غيابه** — ⛔ **ولا يُعرَض مُعطَّلاً.**
      expect(find.byType(OutlinedButton), findsNothing);
    });
  });
}

/// ★★ بوابةُ قسم الصدَفة — `design-system.md` §6.و و§7 (`ADR-0021` · `AM-017`).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qtms/core/design/design_tokens.dart';
import 'package:qtms/core/ui/hub_section.dart';

Future<void> pumpSection(
  WidgetTester tester, {
  required List<QtmsHubEntry> entries,
  String title = 'العمليات اليومية',
  double width = 360,
}) =>
    tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: SizedBox(
              width: width,
              child: SingleChildScrollView(
                child: QtmsHubSection(title: title, entries: entries),
              ),
            ),
          ),
        ),
      ),
    );

QtmsHubEntry entry(
  String label, {
  bool primary = false,
  bool frequent = false,
}) =>
    QtmsHubEntry(
      label: label,
      icon: Icons.circle_outlined,
      onPressed: () {},
      isPrimary: primary,
      isFrequent: frequent,
    );

void main() {
  group('⛔⛔★★★ القسمُ يختفي كلُّه بلا مداخل — لا فجوةٌ مكدَّسة', () {
    testWidgets('★ قسمٌ بلا مداخل لا يعرض عنوانه ولا يشغل ارتفاعاً', (
      WidgetTester tester,
    ) async {
      await pumpSection(tester, entries: const <QtmsHubEntry>[]);

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
      await pumpSection(tester, entries: <QtmsHubEntry>[entry('التوزيع')]);

      expect(find.text('العمليات اليومية'), findsOneWidget);
      expect(find.text('التوزيع'), findsOneWidget);
    });
  });

  group('★★ الهرمُ البصري — §7: زرُّ إجراءٍ رئيسي واحد', () {
    testWidgets('★ الأساسيُّ ممتلئٌ بالسطح المعكوس والباقي محاطٌ بالسطح', (
      WidgetTester tester,
    ) async {
      await pumpSection(
        tester,
        entries: <QtmsHubEntry>[
          entry('التوزيع', primary: true),
          entry('الوارد عدداً'),
          entry('مخزون اليوم'),
        ],
      );

      Material materialOf(String label) => tester.widget<Material>(
            find
                .ancestor(
                  of: find.text(label),
                  matching: find.byType(Material),
                )
                .first,
          );

      expect(materialOf('التوزيع').color, SemanticColors.surfaceInverse);
      expect(materialOf('الوارد عدداً').color, SemanticColors.surface);
      expect(materialOf('مخزون اليوم').color, SemanticColors.surface);
    });

    testWidgets('★★ والمؤكَّدُ الثانوي بحدٍّ من عائلة الهوية — ⛔ لا تعبئة', (
      WidgetTester tester,
    ) async {
      await pumpSection(
        tester,
        entries: <QtmsHubEntry>[
          entry('البيع النقدي', frequent: true),
          entry('الجرد'),
        ],
      );

      BoxDecoration decorationOf(String label) =>
          tester.widget<DecoratedBox>(
            find
                .ancestor(
                  of: find.text(label),
                  matching: find.byType(DecoratedBox),
                )
                .first,
          ).decoration as BoxDecoration;

      final BoxDecoration frequent = decorationOf('البيع النقدي');
      final BoxDecoration plain = decorationOf('الجرد');
      expect(
        (frequent.border! as Border).top.color,
        SemanticTriads.primary.border,
        reason: '⛔ المؤكَّدُ بلا حدٍّ من عائلة الهوية',
      );
      expect((plain.border! as Border).top.color, SemanticColors.border);
      // ⛔ **ولا تعبئةَ ممتلئة للمؤكَّد** — الممتلئُ للأساسي وحده.
      expect(
        tester
            .widget<Material>(
              find
                  .ancestor(
                    of: find.text('البيع النقدي'),
                    matching: find.byType(Material),
                  )
                  .first,
            )
            .color,
        SemanticColors.surface,
      );
    });

    testWidgets('⛔ ولا معنى بأيقونةٍ وحدها — النصُّ إلزاميٌّ في العقد', (
      WidgetTester tester,
    ) async {
      await pumpSection(tester, entries: <QtmsHubEntry>[entry('التوزيع')]);
      expect(find.text('التوزيع'), findsOneWidget);
    });
  });

  group('★★★ الشبكةُ — عمودان دون `expanded` وثلاثةٌ فوقه (`AM-017`)', () {
    test('★ الموزّعُ المركزي يعطي 2 عند 360 و3 فوق 600', () {
      expect(Breakpoints.hubColumns(360), 2);
      expect(Breakpoints.hubColumns(599), 2);
      expect(Breakpoints.hubColumns(720), 3);
    });

    test('★★ والأساسيُّ يشغل خانتين فيبقى وحده في صفٍّ بعمودين', () {
      final List<QtmsHubEntry> entries = <QtmsHubEntry>[
        entry('التوزيع', primary: true),
        entry('أ'),
        entry('ب'),
        entry('ج'),
      ];

      final List<List<QtmsHubEntry>> two = packHubRows(entries, 2);
      expect(two.length, 3);
      expect(two.first.length, 1);
      expect(two[1].map((QtmsHubEntry e) => e.label), <String>['أ', 'ب']);

      final List<List<QtmsHubEntry>> three = packHubRows(entries, 3);
      expect(three.first.map((QtmsHubEntry e) => e.label),
          <String>['التوزيع', 'أ']);
    });

    test('⛔ ولا يفيض الأساسيُّ شبكةً بعمودٍ واحد', () {
      expect(hubEntrySpan(entry('التوزيع', primary: true), 1), 1);
      expect(hubEntrySpan(entry('التوزيع', primary: true), 2), 2);
      expect(hubEntrySpan(entry('أ'), 3), 1);
    });

    testWidgets('★★ واثنا عشرَ مدخلاً تُرسَم في سبعة صفوفٍ بارتفاع البلاطة', (
      WidgetTester tester,
    ) async {
      await pumpSection(
        tester,
        entries: <QtmsHubEntry>[
          entry('التوزيع', primary: true),
          for (int i = 1; i < 12; i++) entry('مدخل $i'),
        ],
      );

      // ★ **سبعةُ صفوفٍ: صفُّ الأساسي + خمسةُ صفوفٍ مزدوجة + صفُّ الأخير.**
      final double gridHeight = tester
          .getSize(find.byType(QtmsHubSection))
          .height;
      const double rows = 7;
      final double expected = rows * Sizes.hubTileHeight +
          (rows - 1) * Spacing.space12 +
          // ★ عنوانُ القسم وفاصلُه وفاصلُ القسم السفلي.
          Spacing.space8 +
          Spacing.space24;
      expect(gridHeight, greaterThan(expected - Sizes.hubTileHeight));
      expect(gridHeight, lessThan(expected + Sizes.hubTileHeight));
    });
  });
}

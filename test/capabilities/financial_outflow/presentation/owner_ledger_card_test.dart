/// ★★★ بطاقة ضمار المالك — `design-system.md` §7.1 ·
/// `owner-ledger-summary-design.md` §3 و§4 و§5 (`AM-007` · `DS-002`).
///
/// ⚠️⚠️ **وما تُثبته هذه الاختبارات ليس شكلاً بل عقداً:**
/// ① ⛔⛔★★★ **صفَّا «قبل الخصم» و«بعد الخصم» يظهران معاً** — **قرار `OQ-001`
///    (الخيار ج)**، ⟵ **وهو الموضعُ الذي خالف فيه النموذجُ المرجعي المستندَ
///    فغلبَ المستند.**
/// ② ⛔⛔★★★ **والبندُ المحكوم بصلاحيةٍ لا يُرسَم إطلاقاً حين يغيب** —
///    ⛔ **لا صفراً ولا مكاناً فارغاً**: ★ **الصفرُ معلومةٌ في هذا النظام.**
/// ③ ★★ **والرقمُ البطل بخط الجسم لا بخط العرض** — ⟵ **وهو قيدٌ تقنيٌّ مقيس.**
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qtms/capabilities/financial_outflow/presentation/owner_ledger_card.dart';
import 'package:qtms/core/design/app_theme.dart';
import 'package:qtms/core/design/design_tokens.dart';
import 'package:qtms/core/design/theme_extensions.dart';

/// ★ عقدٌ اختباريٌّ كامل — ⚠️ **أرقامٌ اختبارية لا بيانات إنتاج:**
/// ⛔ **والمكوّنُ لا يُغذَّى بها في أي شاشة** (`AM-007`).
OwnerLedgerSummaryView view({
  String? withdrawals = '27,500',
  String? expenses = '19,000',
  String? retro,
  String? delta = '77% عن أمس',
}) =>
    OwnerLedgerSummaryView(
      scopeLabel: 'كل المصادر · عرض تجميعي',
      totalDebt: '1,325,000',
      credit: '1,240,000',
      cash: '85,000',
      settledOfDay: '420,000',
      discounts: '3,000',
      remainingBeforeDiscount: '820,000',
      remainingAfterDiscount: '817,000',
      tax: '9,850',
      remainingAfterTax: '807,150',
      netFinal: '760,650',
      currencyLabel: 'ر.ي',
      withdrawals: withdrawals,
      expenses: expenses,
      retroUpdatedAtLabel: retro,
      deltaLabel: delta,
    );

Future<void> pumpCard(
  WidgetTester tester, {
  required OwnerLedgerSummaryView summary,
  void Function(String rowLabel)? onRowTap,
  VoidCallback? onShare,
}) =>
    tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        theme: buildQtmsTheme(),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: SingleChildScrollView(
              child: OwnerLedgerCard(
                summary: summary,
                onRowTap: onRowTap,
                onShare: onShare,
              ),
            ),
          ),
        ),
      ),
    );

void main() {
  group('⛔⛔★★★ صفَّا الخصم معاً — `OQ-001` الخيار ج', () {
    testWidgets('★ «قبل الخصم» و«بعد الخصم» كلاهما مرسوم', (
      WidgetTester tester,
    ) async {
      await pumpCard(tester, summary: view());

      // ⟵ **المعادلةُ الحرفية تُنتج رقماً، والذمم المفتوحة فعلياً رقماً آخر،
      //    والفارقُ هو الخصمُ بالضبط** — ★ **وعرضُهما يُظهر المعنيين.**
      expect(find.text('باقي الضمار قبل الخصم'), findsOneWidget);
      expect(find.text('باقي الضمار بعد الخصم'), findsOneWidget);
      expect(find.text('820,000'), findsOneWidget);
      expect(find.text('817,000'), findsOneWidget);
    });

    testWidgets('★★ والخصومات بندٌ مستقلٌّ عن الواصل', (
      WidgetTester tester,
    ) async {
      await pumpCard(tester, summary: view());

      // ⛔ **ولا يُدخَل الخصمُ كمبلغٍ واصل** — §4.1 من مستند الوحدة.
      expect(find.text('الواصل'), findsOneWidget);
      expect(find.text('الخصومات'), findsOneWidget);
      expect(
        find.text('بند مستقل عن الواصل — يُطرح من الضمار'),
        findsOneWidget,
      );
    });

    testWidgets('★ والبنودُ العشرةُ بترتيبها المُلزِم — §3', (
      WidgetTester tester,
    ) async {
      await pumpCard(tester, summary: view());

      double y(String label) => tester.getTopLeft(find.text(label)).dy;

      // ★ **سلسلةُ اشتقاقٍ تُقرأ من أعلى إلى أسفل** — ⛔ **لا أرقامٌ متجاورة.**
      expect(y('إجمالي الضمار'), lessThan(y('الواصل')));
      expect(y('الواصل'), lessThan(y('الخصومات')));
      expect(y('الخصومات'), lessThan(y('باقي الضمار قبل الخصم')));
      expect(
        y('باقي الضمار قبل الخصم'),
        lessThan(y('باقي الضمار بعد الخصم')),
      );
      expect(y('باقي الضمار بعد الخصم'), lessThan(y('إجمالي الضريبة')));
      expect(
        y('إجمالي الضريبة'),
        lessThan(y('الباقي بعد الخصم والضريبة')),
      );
      expect(y('الباقي بعد الخصم والضريبة'), lessThan(y('السحبيات')));
      expect(y('السحبيات'), lessThan(y('الخرجيات')));
    });
  });

  group('⛔⛔★★★ البناءُ حسب صلاحيات القارئ — §5', () {
    testWidgets('★ بندُ السحبيات يختفي كلياً لمن لا يملك عرضه', (
      WidgetTester tester,
    ) async {
      await pumpCard(tester, summary: view(withdrawals: null));

      // ⛔ **ولا صفرٌ ولا مكانٌ فارغ ولا بندٌ معطَّل** — ★ **يختفي كلياً.**
      expect(find.text('السحبيات'), findsNothing);
      expect(find.text('27,500'), findsNothing);
      // ★ **وبقيةُ البطاقة كاملةٌ كما هي.**
      expect(find.text('الخرجيات'), findsOneWidget);
      expect(find.text('الصافي النهائي لليوم'), findsOneWidget);
    });

    testWidgets('★ والخرجياتُ كذلك — والبطاقةُ تبقى قائمةً بلا كلا البندين', (
      WidgetTester tester,
    ) async {
      await pumpCard(
        tester,
        summary: view(withdrawals: null, expenses: null),
      );

      expect(find.text('السحبيات'), findsNothing);
      expect(find.text('الخرجيات'), findsNothing);
      expect(find.text('باقي الضمار بعد الخصم'), findsOneWidget);
      // ⚠️ ★ **والصافي الذي يراه هذا القارئ قد يختلف رقمُه — سلوكٌ مقصود.**
      expect(find.text('760,650'), findsNWidgets(2));
    });
  });

  group('★★ الرقمُ البطل والرِباط', () {
    testWidgets('⛔⛔★★★ الرقمُ البطل بخط الجسم لا بخط العرض', (
      WidgetTester tester,
    ) async {
      await pumpCard(tester, summary: view());

      final Iterable<Text> heroNumbers = tester
          .widgetList<Text>(find.text('760,650'));
      expect(heroNumbers, isNotEmpty);
      for (final Text text in heroNumbers) {
        // ⟵ **أرقامُ خط العرض متغيّرةُ العرض وبلا `tnum`** — ★ **فعمودُ الرقم
        //    يرتجّ عند كل تحديثٍ لحظي** (`design-tokens.md` §5-أ).
        expect(text.style?.fontFamily, isNot(qtmsDisplayFontFamily));
        expect(
          text.style?.fontFeatures,
          TypeScale.tabular,
          reason: '★ كلُّ رقمٍ جدوليٌّ إلزاماً',
        );
      }
    });

    testWidgets('★★ والعنوانُ الحرفيُّ وحده بخط العرض', (
      WidgetTester tester,
    ) async {
      await pumpCard(tester, summary: view());

      final Text title =
          tester.widget<Text>(find.text('ضمار المالك — اليوم'));
      expect(title.style?.fontFamily, qtmsDisplayFontFamily);
      expect(title.style?.fontFeatures ?? const <FontFeature>[], isEmpty);
    });

    testWidgets('★ والصافي يظهر مرتين — رقماً بطلاً وفي الرِباط', (
      WidgetTester tester,
    ) async {
      await pumpCard(tester, summary: view());
      expect(find.text('760,650'), findsNWidgets(2));
      expect(find.text('الصافي النهائي'), findsOneWidget);
      expect(find.text('الصافي النهائي لليوم'), findsOneWidget);
    });
  });

  group('★ وسمُ الأثر الرجعي ووسمُ اللحظية — §7', () {
    testWidgets('★★ وسمُ «⟳» يحلّ محلّ «لحظي» حين وُجد تاريخُ إعادة بناء', (
      WidgetTester tester,
    ) async {
      await pumpCard(tester, summary: view(retro: 'مُحدَّث 20/08'));

      // ⛔ **ولا لونٌ وحده ينقل المعنى** — ★ **الرمزُ والنصُّ معه.**
      expect(find.text('⟳ مُحدَّث 20/08'), findsOneWidget);
      expect(find.text('لحظي'), findsNothing);
    });

    testWidgets('★ وبلا أثرٍ رجعي يظهر وسمُ «لحظي»', (
      WidgetTester tester,
    ) async {
      await pumpCard(tester, summary: view());
      expect(find.text('لحظي'), findsOneWidget);
    });
  });

  group('★★ التفكيكُ وعدٌ يُقرأ من السهم — §7.1 القاعدة 5', () {
    testWidgets('★ النقرُ على بندٍ يُبلِّغ تسميتَه', (
      WidgetTester tester,
    ) async {
      final List<String> tapped = <String>[];
      await pumpCard(
        tester,
        summary: view(),
        onRowTap: tapped.add,
      );

      await tester.tap(find.text('إجمالي الضريبة'));
      await tester.pump();
      expect(tapped, <String>['إجمالي الضريبة']);
    });

    testWidgets('⛔ وصفوفُ الحصيلة لا تُنقَر — ليست بنداً له حركات', (
      WidgetTester tester,
    ) async {
      final List<String> tapped = <String>[];
      await pumpCard(tester, summary: view(), onRowTap: tapped.add);

      await tester.tap(
        find.text('باقي الضمار بعد الخصم'),
        warnIfMissed: false,
      );
      await tester.pump();
      // ★ **الحصيلةُ مشتقّةٌ من بنودٍ فوقها** — ⛔ **فلا حركاتٌ تُفكَّك إليها.**
      expect(tapped, isEmpty);
    });
  });

  testWidgets('⛔⛔★★★ ولا حسابَ داخل البطاقة — §5.1', (
    WidgetTester tester,
  ) async {
    // ★ **عقدٌ بقيمٍ متناقضةٍ رياضياً يُرسَم كما هو** — ⟵ **وهذا هو الدليل:**
    //   ★ **البطاقةُ لا تجمع ولا تطرح ولا تقارن**، ⛔ **ولو حسبت لعاشت
    //   المعادلةُ في موضعين واختلف حكمُها عن حكم الملخص.**
    await pumpCard(
      tester,
      summary: const OwnerLedgerSummaryView(
        scopeLabel: 'رداع',
        totalDebt: '1',
        credit: '1',
        cash: '1',
        settledOfDay: '1',
        discounts: '1',
        remainingBeforeDiscount: '999',
        remainingAfterDiscount: '999',
        tax: '1',
        remainingAfterTax: '999',
        netFinal: '999',
        currencyLabel: 'ر.ي',
      ),
    );

    // ★ **خمسةُ مواضع:** ثلاثُ حصائلَ وسطية + الرقمُ البطل + الرِباط.
    expect(find.text('999'), findsNWidgets(5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('★★ والرِباطُ يقرأ تدرّجَه من آلية الثيم لا من ثابتٍ محلي', (
    WidgetTester tester,
  ) async {
    await pumpCard(tester, summary: view());

    final BuildContext context = tester.element(find.text('الصافي النهائي'));
    final QtmsHeroColors hero = context.hero;
    // ⛔ **ولا تدرّجَ ثانٍ في التطبيق** — §8 المحظور السابع.
    expect(
      find.byWidgetPredicate(
        (Widget w) =>
            w is DecoratedBox &&
            (w.decoration as BoxDecoration).gradient == hero.tieGradient,
      ),
      findsOneWidget,
    );
  });
}

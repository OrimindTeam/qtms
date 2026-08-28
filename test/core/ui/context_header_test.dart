/// ★★★ رأس السياق `QtmsContextHeader` — `MASTER.md` §5b نمط `P3` (`ADR-0021`).
///
/// ⚠️⚠️ **وما تُثبته هذه الاختبارات وما لا تُثبته:** تُثبت أن **الرأس صفٌّ
/// واحد لا ثلاثة**، وأن **المرشِّحات مطويّة ابتداءً**، وأن **حالتَي الفراغ
/// لهما نصٌّ وإجراء** ⛔ **لا `SizedBox.shrink`.**
/// ⛔ **ولا تُثبت أن النطاق محميّ** — ★ **الحماية في `firestore.rules`
/// والدالة الكاتبة** (`RISK-02`)، ولها اختباراتها هناك.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qtms/core/ui/async_state_view.dart';
import 'package:qtms/core/ui/context_header.dart';
import 'package:qtms_domain/qtms_domain.dart';

/// ★★ **اليوم مثبَّت** — ⛔ **فلا اختبارَ ينكسر بمرور منتصف الليل.**
final CalendarDay fixedDay = CalendarDay(2026, 8, 25);

SourceCard source(String id, String name) => SourceCard(
      sourceId: id,
      name: name,
      requiresSupplierOnIntake: false,
      isActive: true,
    );

Future<void> pumpHeader(
  WidgetTester tester, {
  required List<SourceCard> sources,
  String? selected,
  Widget? filters,
  int activeFilterCount = 0,
  ValueChanged<String>? onSourceSelected,
  double textScale = 1,
}) =>
    tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        builder: (BuildContext context, Widget? child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: QtmsContextHeader(
              sources: sources,
              selectedSourceId: selected,
              onSourceSelected: onSourceSelected ?? (String _) {},
              day: fixedDay,
              filters: filters,
              activeFilterCount: activeFilterCount,
            ),
          ),
        ),
      ),
    );

void main() {
  group('⛔⛔★★★ قاعدة الرأس الثقيل — §5b نمط P3', () {
    testWidgets('★ الرأس المطويّ لا يتجاوز السقف البنيوي 96dp', (
      WidgetTester tester,
    ) async {
      // ★ **عشرةُ مصادر** — ⟵ **وهو العدد الذي كان يُبتلَع به نصفُ الشاشة**
      //   حين كان المنتقي شرائح `Wrap` تلتفّ بلا حدّ.
      await pumpHeader(
        tester,
        sources: <SourceCard>[
          for (int i = 1; i <= 10; i++) source('SRC-00$i', 'مصدر رقم $i'),
        ],
        selected: 'SRC-001',
      );

      final Size size = tester.getSize(find.byType(QtmsContextHeader));
      expect(
        size.height,
        lessThanOrEqualTo(kContextHeaderMaxHeight),
        reason: '★ الرأس الثابت يتجاوز 96dp — §5b نمط P3',
      );
    });

    testWidgets('⛔ ولا شرائح تلتفّ — المصدر قائمةٌ منسدلة', (
      WidgetTester tester,
    ) async {
      await pumpHeader(
        tester,
        sources: <SourceCard>[
          for (int i = 1; i <= 10; i++) source('SRC-00$i', 'مصدر رقم $i'),
        ],
        selected: 'SRC-001',
      );

      expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
      // ⛔⛔ **ولا `ChoiceChip` واحدة** — ★ **وهي ما كان يُنتج الالتفاف.**
      expect(find.byType(ChoiceChip), findsNothing);
      expect(find.byType(Wrap), findsNothing);
    });

    testWidgets(
        '⛔⛔★★★ ولا يُقتطَع اسمُ المصدر عند تكبير النصّ — الصفُّ ينقسم صفّين',
        (WidgetTester tester) async {
      // ⚠️⚠️★★★ **اختبارُ ارتدادٍ لعطلٍ رصده المحاكي وحده (2026-08-27):**
      //    ★ **عند `textScaler` 2.0 كان الاسمُ يُقتطَع «مصدر الا…»** ⟵ **فلا
      //    يعرف المستخدم على أي مصدرٍ يعمل** — ⛔ **و11 اختبارَ ويدجت لم
      //    تكشفه** لأنها كلها عند المقياس الطبيعي.
      //    ★★ **ودرسُه درسُ `DEBT-37`:** ⟵ **ما يمرّ بين الطبقات يُقاس حيّاً.**
      const String longName = 'مصدر الاختبار الأول';

      await pumpHeader(
        tester,
        sources: <SourceCard>[source('SRC-001', longName)],
        selected: 'SRC-001',
      );
      final double single = tester.getSize(find.byType(QtmsContextHeader)).height;

      await pumpHeader(
        tester,
        sources: <SourceCard>[source('SRC-001', longName)],
        selected: 'SRC-001',
        textScale: 2,
      );
      final double scaled = tester.getSize(find.byType(QtmsContextHeader)).height;

      // ★ **الرأس ينمو عمداً** — ⟵ **فالمصدرُ يأخذ عرضَ الشاشة كاملاً
      //   واليومُ ينزل تحته**، ⛔ **ولا يتنافسان على صفٍّ واحد.**
      expect(
        scaled,
        greaterThan(single),
        reason: '★ الرأس لم ينقسم صفّين عند التكبير — الاسمُ يُقتطَع',
      );
      // ⛔ **ولا فيضان** — §8: `textScaler` محترمٌ بلا كسر تخطيط.
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        '⛔⛔★★★ ولا يُعصَر اسمُ المصدر بزرّ المرشِّحات — DEBT-48',
        (WidgetTester tester) async {
      // ⚠️⚠️★★★ **اختبارُ ارتدادٍ لعطلٍ رصده المحاكي عند المقياس الطبيعي:**
      //    ★ **ثلاثةُ عناصرَ في صفٍّ واحد تعصر الاسم** ⟵ «مصدر الاخت…».
      const String longName = 'مصدر الاختبار الأول';

      await pumpHeader(
        tester,
        sources: <SourceCard>[source('SRC-001', longName)],
        selected: 'SRC-001',
      );
      final double plain =
          tester.getSize(find.byType(QtmsContextHeader)).height;

      await pumpHeader(
        tester,
        sources: <SourceCard>[source('SRC-001', longName)],
        selected: 'SRC-001',
        filters: const Text('صفّ المرشِّحات'),
      );
      final double withFilters =
          tester.getSize(find.byType(QtmsContextHeader)).height;

      // ★★ **والصفُّ يبقى واحداً** — ⟵ **فالزرُّ أيقونيٌّ لا نصّي**،
      //    ⛔ **ولا ثالثَ عنصرٍ نصّي يزاحم اسمَ المصدر.**
      expect(withFilters, plain);
      // ⛔⛔★★ **والسقفُ 96dp محفوظ** — §5b `P3`.
      expect(withFilters, lessThanOrEqualTo(kContextHeaderMaxHeight));
      expect(tester.takeException(), isNull);
    });

    testWidgets('★★ واليوم المقفل داخل الصفّ نفسه لا في لافتةٍ ثانية', (
      WidgetTester tester,
    ) async {
      await pumpHeader(
        tester,
        sources: <SourceCard>[source('SRC-001', 'مصدر رداع')],
        selected: 'SRC-001',
      );

      expect(find.text('2026/08/25'), findsOneWidget);
      // ★ **أيقونةُ القفل مع النصّ** — §8: ⛔ **لا معنى باللون وحده.**
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    });
  });

  group('★ المرشِّحات — مطويّةٌ ابتداءً', () {
    testWidgets('⛔ ولا زرَّ طيٍّ لشاشةٍ بلا مرشِّحات', (
      WidgetTester tester,
    ) async {
      await pumpHeader(
        tester,
        sources: <SourceCard>[source('SRC-001', 'مصدر رداع')],
        selected: 'SRC-001',
      );
      expect(find.byTooltip('مرشِّحات'), findsNothing);
    });

    testWidgets('★★ ولا تُعرَض حتى يفتحها المستخدم صراحةً', (
      WidgetTester tester,
    ) async {
      await pumpHeader(
        tester,
        sources: <SourceCard>[source('SRC-001', 'مصدر رداع')],
        selected: 'SRC-001',
        filters: const Text('صفّ المرشِّحات'),
      );

      // ⛔★★ **مطويّةٌ ابتداءً** — §5b: ⟵ **فالرأس يبدأ بأخفّ صورةٍ له.**
      expect(find.text('صفّ المرشِّحات'), findsNothing);
      expect(find.byTooltip('مرشِّحات'), findsOneWidget);

      await tester.tap(find.byTooltip('مرشِّحات'));
      await tester.pump();
      expect(find.text('صفّ المرشِّحات'), findsOneWidget);
    });

    testWidgets('★ وعددُ النشط ظاهرٌ على الزرّ وهي مطويّة', (
      WidgetTester tester,
    ) async {
      await pumpHeader(
        tester,
        sources: <SourceCard>[source('SRC-001', 'مصدر رداع')],
        selected: 'SRC-001',
        filters: const Text('صفّ المرشِّحات'),
        activeFilterCount: 2,
      );
      // ⟵ **فلا يقرأ المستخدم قائمةً مفلترة ظانّاً أنها كاملة.**
      // ★★ **والعددُ شارةٌ على الأيقونة** — ⛔ **ولم يسقط بإسقاط النصّ.**
      expect(find.byTooltip('مرشِّحات (2)'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
    });
  });

  group('⛔⛔★★★ قاعدة الفراغ الصامت — §5b نمط P3', () {
    testWidgets('★ نطاقٌ فارغ يُعرَض بنصّه — ⛔ لا فراغاً', (
      WidgetTester tester,
    ) async {
      await pumpHeader(tester, sources: const <SourceCard>[]);

      expect(find.textContaining('لا يوجد مصدر ضمن نطاقك'), findsOneWidget);
      expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    });

    test('★★ و«اختر مصدراً» حالةٌ مصمَّمة بعنوانٍ ورسالةٍ وإجراء', () {
      bool tapped = false;
      final EmptyStateSpec spec = chooseSourceEmpty(
        onChoose: () => tapped = true,
      );

      expect(spec.title, isNotEmpty);
      expect(spec.message, isNotEmpty);
      // ⛔⛔★★★ **وهي بديلُ `SizedBox.shrink`** — §هـ يفرض الإجراء الأساسي.
      expect(spec.actionLabel, isNotNull);
      spec.onAction!();
      expect(tapped, isTrue);
    });

    test('⛔ ولا إجراءَ لحالة «لا مصدر في نطاقك» — فالمستخدم لا يملك ما يفعله',
        () {
      expect(noSourceInScopeEmpty.title, isNotEmpty);
      expect(noSourceInScopeEmpty.message, isNotEmpty);
      // ★ **والخطوة التالية مراجعةُ المدير** ⛔ **لا زرٌّ لا يقود إلى شيء.**
      expect(noSourceInScopeEmpty.onAction, isNull);
    });
  });

  group('★ الاختيار', () {
    testWidgets('★ يُبلِّغ المعرّف المختار كما هو', (
      WidgetTester tester,
    ) async {
      String? picked;
      await pumpHeader(
        tester,
        sources: <SourceCard>[
          source('SRC-001', 'مصدر رداع'),
          source('SRC-002', 'مصدر ذمار'),
        ],
        selected: 'SRC-001',
        onSourceSelected: (String id) => picked = id,
      );

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('مصدر ذمار').last);
      await tester.pumpAndSettle();

      expect(picked, 'SRC-002');
    });

    testWidgets('⛔⛔ ومعرّفٌ لا يقابله مصدرٌ لا يُسقِط الشاشة', (
      WidgetTester tester,
    ) async {
      // ★★ **حالةٌ واقعية:** **مصدرٌ عُطِّل بينما الشاشة مفتوحة** — ⟵ **فيبقى
      //   معرّفُه في الحالة ولا خيارَ له في القائمة.**
      await pumpHeader(
        tester,
        sources: <SourceCard>[source('SRC-001', 'مصدر رداع')],
        selected: 'SRC-999',
      );

      expect(tester.takeException(), isNull);
      expect(find.text('اختر المصدر'), findsOneWidget);
    });
  });
}

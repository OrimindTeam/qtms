/// ⛔⛔★★★ **موضعُ إجراءات بطاقة الكيان** — `AM-008` ⑥ · `design-system.md` §6.د.
///
/// ★★ **وثلاثةُ أوضاعٍ لا واحد** — ⟵ **وكان الوضعُ واحداً: صفٌّ مستقلٌّ
/// بفاصلٍ شعري**، ★ **فبطاقةُ مصدرٍ بزرّ «تعديل» واحد كانت ثلاثةَ مستويات**
/// ⛔ **وارتفاعُها يقارب ضعفَ ما تحمله من معلومة.**
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qtms/core/ui/entity_tile.dart';

Future<void> pumpTile(
  WidgetTester tester, {
  required EntityActionsPlacement placement,
  List<Widget> actions = const <Widget>[],
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('ar'),
      home: Scaffold(
        body: EntityTile(
          title: 'مصدر رداع',
          subtitle: 'الرعوي إلزامي عند التوريد',
          actions: actions,
          actionsPlacement: placement,
        ),
      ),
    ),
  );
  await tester.pump();
}

Widget editButton() => IconButton(
      onPressed: () {},
      icon: const Icon(Icons.edit_outlined),
      tooltip: 'تعديل',
    );

void main() {
  testWidgets(
    '⛔⛔★★★ `inline` ⟵ الإجراء في صفّ الاسم نفسِه — ⛔ بلا فاصلٍ ولا صفٍّ ثانٍ',
    (WidgetTester tester) async {
      await pumpTile(
        tester,
        placement: EntityActionsPlacement.inline,
        actions: <Widget>[editButton()],
      );

      expect(find.byTooltip('تعديل'), findsOneWidget);
      // ⛔ **ولا فاصلَ شعري** — ★ **وهو ما كان يُنشئ الصفَّ الثالث.**
      expect(find.byType(Divider), findsNothing);

      // ★★★ **والقياسُ بنيويّ لا بصريّ:** ⟵ **الزرُّ والعنوان على المحور
      //    الرأسي نفسِه** ⛔ **لا أحدُهما تحت الآخر.**
      final Rect title = tester.getRect(find.text('مصدر رداع'));
      final Rect action = tester.getRect(find.byTooltip('تعديل'));
      expect(action.center.dy, closeTo(title.center.dy, title.height * 2));
    },
  );

  testWidgets(
    '★ `stacked` ⟵ صفٌّ مستقلٌّ بفاصلٍ شعري — وهو الافتراض',
    (WidgetTester tester) async {
      await pumpTile(
        tester,
        placement: EntityActionsPlacement.stacked,
        actions: <Widget>[editButton()],
      );

      expect(find.byType(Divider), findsOneWidget);
      final Rect title = tester.getRect(find.text('مصدر رداع'));
      final Rect action = tester.getRect(find.byTooltip('تعديل'));
      // ⛔ **والزرُّ تحت العنوان فعلاً** — ★ **فالوضعان مختلفان بنيوياً.**
      expect(action.top, greaterThan(title.bottom));
    },
  );

  testWidgets(
    '★★ `subtitleRow` ⟵ على سطر النصّ الثانوي — والعنوانُ بعرضٍ كامل',
    (WidgetTester tester) async {
      await pumpTile(
        tester,
        placement: EntityActionsPlacement.subtitleRow,
        actions: <Widget>[editButton()],
      );

      expect(find.byType(Divider), findsNothing);
      final Rect title = tester.getRect(find.text('مصدر رداع'));
      final Rect subtitle = tester.getRect(find.text('الرعوي إلزامي عند التوريد'));
      final Rect action = tester.getRect(find.byTooltip('تعديل'));

      // ★ **الزرُّ تحت العنوان وعلى ارتفاع النصّ الثانوي.**
      expect(action.center.dy, greaterThan(title.bottom));
      expect(action.center.dy, closeTo(subtitle.center.dy, subtitle.height * 2));
    },
  );

  testWidgets(
    '⛔ وقائمةٌ فارغة لا تُنتج فاصلاً ولا مسافةً في أيٍّ من الأوضاع',
    (WidgetTester tester) async {
      for (final EntityActionsPlacement placement
          in EntityActionsPlacement.values) {
        await pumpTile(tester, placement: placement);
        expect(find.byType(Divider), findsNothing, reason: placement.name);
      }
    },
  );
}

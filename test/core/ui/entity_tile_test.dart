/// ★★★ بطاقةُ الكيان — `design-system.md` §6.د · `ADR-0021`.
///
/// ⚠️⚠️ **وما تُثبته هذه الاختبارات:** أن **شقّ الرفض المُضاف يُعرَض داخل
/// البطاقة ولا يُخفي ما رُفض**، وأن **الحالات في سطرها لا في صفّ النصّ**
/// (`DEBT-36`)، وأن **الإجراءات خلف فاصلٍ شعري**.
/// ⛔ **ولا تُثبت أن الإجراء مسموح** — ★ **`PermissionGate` إخفاءٌ لا حماية**
/// **والرفضُ الحقيقي في السحابة** (`RISK-02`).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qtms/core/ui/entity_tile.dart';
import 'package:qtms/core/ui/status_pill.dart';
import 'package:qtms/core/design/design_tokens.dart';

Future<void> pumpTile(
  WidgetTester tester, {
  String? rejection,
  List<Widget> badges = const <Widget>[],
  List<Widget> actions = const <Widget>[],
}) =>
    tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: EntityTile(
              title: 'مدير المخزون',
              subtitle: 'دورٌ للتشغيل اليومي',
              badges: badges,
              actions: actions,
              rejection: rejection,
            ),
          ),
        ),
      ),
    );

void main() {
  group('★★★ شقّ الرفض — EntityTile.rejection', () {
    testWidgets('⛔ و`null` غيابٌ لا فراغ — بلا رسالةٍ ولا أيقونة', (
      WidgetTester tester,
    ) async {
      await pumpTile(tester);

      expect(find.byIcon(Icons.error_outline), findsNothing);
    });

    testWidgets(
      '⛔⛔★★★ والرفضُ يُعرَض ولا يُخفي ما رُفض — سابقةُ QtmsLiveSummary',
      (WidgetTester tester) async {
        await pumpTile(tester, rejection: 'لا يمكن حذف دورٍ مُسنَد.');

        // ★★ **الرسالةُ حاضرة** — ⛔ **ولا تُبتلَع.**
        expect(find.text('لا يمكن حذف دورٍ مُسنَد.'), findsOneWidget);
        // ⛔ **ولا معنى باللون وحده** — §8: ★ **أيقونةٌ ونصٌّ معاً.**
        expect(find.byIcon(Icons.error_outline), findsOneWidget);
        // ⛔⛔★★★ **والبطاقة باقيةٌ كاملة** — ★ **فيُعرَف أيُّ صفٍّ رُفض.**
        expect(find.text('مدير المخزون'), findsOneWidget);
        expect(find.text('دورٌ للتشغيل اليومي'), findsOneWidget);
      },
    );

    testWidgets('★★ والرفضُ بعد الحالات وقبل الإجراءات — يُقرأ جواباً', (
      WidgetTester tester,
    ) async {
      await pumpTile(
        tester,
        badges: <Widget>[
          const StatusPill(label: 'مُسنَد', triad: SemanticTriads.info),
        ],
        rejection: 'لا يمكن حذف دورٍ مُسنَد.',
        actions: <Widget>[
          IconButton(onPressed: () {}, icon: const Icon(Icons.edit_outlined)),
        ],
      );

      final double badge = tester.getTopLeft(find.text('مُسنَد')).dy;
      final double message =
          tester.getTopLeft(find.text('لا يمكن حذف دورٍ مُسنَد.')).dy;
      final double action =
          tester.getTopLeft(find.byIcon(Icons.edit_outlined)).dy;

      expect(message, greaterThan(badge));
      expect(action, greaterThan(message));
      // ★ **فاصلٌ شعري قبل صفّ الإجراءات** — §6.د حرفياً.
      expect(find.byType(Divider), findsOneWidget);
    });
  });

  group('★★ الحالات في سطرها — DEBT-36 واستكمالُه', () {
    testWidgets('⛔⛔ ولا قسمةَ عرضٍ بين نصٍّ وحالة — الشارةُ أسفل العنوان', (
      WidgetTester tester,
    ) async {
      await pumpTile(
        tester,
        badges: <Widget>[
          const StatusPill(label: 'معطَّل', triad: SemanticTriads.danger),
        ],
      );

      // ★ **الشارةُ أسفل النصّ لا بجانبه** — ⟵ **فلا تنافسه على العرض.**
      expect(
        tester.getTopLeft(find.text('معطَّل')).dy,
        greaterThan(tester.getTopLeft(find.text('دورٌ للتشغيل اليومي')).dy),
      );
    });
  });
}

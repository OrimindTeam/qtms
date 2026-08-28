/// ★★★ ورقة التأكيد المدمّرة — `MASTER.md` §5b نمط `P6` (`ADR-0021`).
///
/// ⚠️⚠️ **وما تُثبته:** أن **زرَّ التراجع موجودٌ دائماً**، وأن **الزرَّ المدمّر
/// لا يُعطَّل لغياب السبب** (`ADR-0020`) **ويُعطَّل لغياب الحقل الإلزامي وحده**، وأن
/// **عقدَ العودة يميّز التراجُعَ من التأكيد بلا سبب**.
/// ⛔ **ولا تُثبت أن العملية محميّة** — ★ **الحماية في الدالة الكاتبة**
/// (`RISK-02`).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qtms/core/ui/destructive_sheet.dart';

/// ★ يفتح الورقة — ⛔ **ولا يلتقط النتيجة**: ★ **الاختبارات التي تعنيها تلتقطها
/// بنفسها بعد النقر.**
Future<void> openSheet(
  WidgetTester tester, {
  String? requiredFieldLabel,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('ar'),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: Builder(
            builder: (BuildContext context) => TextButton(
              onPressed: () async {
                await showQtmsDestructiveSheet(
                  context,
                  title: 'تعطيل المستخدم',
                  impact: 'سيُمنع «عبدالفتاح» من الدخول فوراً.',
                  confirmLabel: 'تعطيل',
                  requiredFieldLabel: requiredFieldLabel,
                );
              },
              child: const Text('افتح'),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('افتح'));
  await tester.pumpAndSettle();
}

void main() {
  group('⛔⛔★★★ زرُّ التراجع إلزاميٌّ بلا استثناء', () {
    testWidgets('★ موجودٌ في كل ورقة — ⛔ ولا مخرجَ وحيدٌ بالسحب', (
      WidgetTester tester,
    ) async {
      await openSheet(tester);
      expect(find.text('تراجع'), findsOneWidget);
      expect(find.text('تعطيل'), findsOneWidget);
    });

    testWidgets('★★ والتراجُع يُرجِع `null` — ⛔ لا تأكيداً بسببٍ فارغ', (
      WidgetTester tester,
    ) async {
      DestructiveConfirmation? captured;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ar'),
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: Builder(
                builder: (BuildContext context) => TextButton(
                  onPressed: () async => captured =
                      await showQtmsDestructiveSheet(
                    context,
                    title: 'إلغاء الجونية',
                    impact: 'الإلغاء يَسِم الجونية ولا يحذف شيئاً.',
                    confirmLabel: 'تأكيد الإلغاء',
                  ),
                  child: const Text('افتح'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('افتح'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('تراجع'));
      await tester.pumpAndSettle();

      // ⛔⛔★★ **والتمييز مقصود** — ⟵ **فـ«أكّد بلا سبب» لا يُقرأ «تراجَع».**
      expect(captured, isNull);
    });
  });

  group('⛔⛔★★★ ولا يُعطَّل المدمّر لغياب السبب — ADR-0020', () {
    testWidgets('★ الزرُّ فعّالٌ والسببُ فارغ', (WidgetTester tester) async {
      await openSheet(tester);

      final FilledButton button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'تعطيل'),
      );
      // ★ **السحابةُ تقبل بلا سبب** — ⟵ **فتعطيلُ الزرّ كان يمنع عمليةً مشروعة.**
      expect(button.onPressed, isNotNull);
    });

    testWidgets('★★ ويُعطَّل لغياب الحقل الإلزامي وحده — FR-M4-09', (
      WidgetTester tester,
    ) async {
      await openSheet(
        tester,
        requiredFieldLabel: 'إقرار التعطيل رغم الرصيد',
      );

      FilledButton button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'تعطيل'),
      );
      // ⛔ **بلا الحقل الإلزامي لا يقع الفعل** — ★ **وهو ليس «سبب تعديل».**
      expect(button.onPressed, isNull);

      await tester.enterText(
        find.widgetWithText(TextField, 'إقرار التعطيل رغم الرصيد'),
        'أُقرّ بالمخاطرة',
      );
      await tester.pump();

      button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'تعطيل'),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('⛔ والفراغاتُ ليست إقراراً', (WidgetTester tester) async {
      await openSheet(
        tester,
        requiredFieldLabel: 'إقرار التعطيل رغم الرصيد',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'إقرار التعطيل رغم الرصيد'),
        '   ',
      );
      await tester.pump();

      final FilledButton button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'تعطيل'),
      );
      expect(button.onPressed, isNull);
    });
  });

  testWidgets('★★ وجملةُ الأثر تسمّي الهدف صراحةً — ⛔ لا ضمير', (
    WidgetTester tester,
  ) async {
    await openSheet(tester);
    // ⟵ **فلا يُعطَّل غيرُ المقصود بضغطةٍ على البطاقة الخطأ.**
    expect(find.textContaining('عبدالفتاح'), findsOneWidget);
  });

  group('⚠️★★ وحقلُ السبب يسقط حين لا تحمله العملية', () {
    testWidgets('★ `reasonLabel: null` ⟵ ولا حقلَ سببٍ البتّة', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ar'),
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: Builder(
                builder: (BuildContext context) => TextButton(
                  onPressed: () async => showQtmsDestructiveSheet(
                    context,
                    title: 'تعطيل المستخدم',
                    impact: 'سيُمنع «عبدالفتاح» من الدخول فوراً.',
                    confirmLabel: 'تعطيل',
                    reasonLabel: null,
                    requiredFieldLabel: 'سبب التعطيل',
                  ),
                  child: const Text('افتح'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('افتح'));
      await tester.pumpAndSettle();

      // ⛔ **فلا يكتب المستخدم تفسيراً يُرمى** — ★ `disable` لا تقبل ثانياً.
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('سبب التعطيل'), findsOneWidget);
    });
  });

  group('⚠️⚠️★★ والمنفّذُ للمُنادي — والرفضُ يُعرَض والورقةُ مفتوحة', () {
    testWidgets('⛔ الرفضُ لا يُغلِق الورقة ولا يُبتلَع', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ar'),
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: Builder(
                builder: (BuildContext context) => TextButton(
                  onPressed: () async => showQtmsDestructiveSheet(
                    context,
                    title: 'إلغاء الوارد',
                    impact: 'الإلغاء يَسِم المستند «و-1» ولا يحذف شيئاً.',
                    confirmLabel: 'تأكيد الإلغاء',
                    onConfirm: (DestructiveConfirmation _) async =>
                        'الكمية غير المصروفة لا تكفي',
                  ),
                  child: const Text('افتح'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('افتح'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('تأكيد الإلغاء'));
      await tester.pumpAndSettle();

      expect(find.text('الكمية غير المصروفة لا تكفي'), findsOneWidget);
      // ★ **والورقةُ باقية** — ⟵ **فالرفضُ يُقرأ حيث وقع.**
      expect(find.text('إلغاء الوارد'), findsOneWidget);
    });

    testWidgets('★ والنجاحُ يُغلِقها ويُرجِع التأكيد', (
      WidgetTester tester,
    ) async {
      DestructiveConfirmation? captured;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ar'),
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: Builder(
                builder: (BuildContext context) => TextButton(
                  onPressed: () async => captured =
                      await showQtmsDestructiveSheet(
                    context,
                    title: 'إلغاء الوارد',
                    impact: 'الإلغاء يَسِم المستند «و-1» ولا يحذف شيئاً.',
                    confirmLabel: 'تأكيد الإلغاء',
                    onConfirm: (DestructiveConfirmation _) async => null,
                  ),
                  child: const Text('افتح'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('افتح'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('تأكيد الإلغاء'));
      await tester.pumpAndSettle();

      expect(find.text('إلغاء الوارد'), findsNothing);
      expect(captured, isNotNull);
      // ★ **وسببٌ فارغٌ لا `null`** — ⟵ **فالعمليةُ تحمل سبباً تركه فارغاً.**
      expect(captured!.reason, '');
    });
  });
}

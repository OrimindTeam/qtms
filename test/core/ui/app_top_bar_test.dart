/// ⛔⛔★★★ **الشريط العلوي الموحّد** — `ui-guidelines.md` §3-أ (`AM-008` ①).
///
/// ★★ **وهذه اختباراتُ العرض المحض** — ⛔ **بلا مزوّدات ولا جلسة**: ⟵ **لأن
/// `QtmsTopBarView` تتلقّى حالتَها كاملةً** (`design-system.md` §5.1).
/// ★ **والبوابة الآلية التي تفرض استعماله في كل شاشة في**
/// `test/core/design/design_gates_test.dart` — ⛔ **ولا تُكرَّر هنا.**
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qtms/core/connectivity/connection_status.dart';
import 'package:qtms/core/design/brand.dart';
import 'package:qtms/core/ui/app_top_bar.dart';
import 'package:qtms/core/ui/avatar.dart';
import 'package:qtms_domain/qtms_domain.dart';

Future<void> pumpBar(
  WidgetTester tester, {
  String screenTitle = 'لوحة اليوم',
  String userName = 'محمد',
  CalendarDay? today,
  ConnectionStatus connection = ConnectionStatus.online,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('ar'),
      home: Scaffold(
        appBar: QtmsTopBarView(
          screenTitle: screenTitle,
          userName: userName,
          today: today ?? CalendarDay(2026, 8, 20),
          connection: connection,
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('★★★ الترتيب البصري — §3-أ', () {
    testWidgets('✅ الشعار واسمُ التطبيق واسمُ الشاشة والتاريخ والصورة الرمزية',
        (WidgetTester tester) async {
      await pumpBar(tester);

      // ① **شعار العميل** — ⛔ **ولا مسارَ أصلٍ محفورٌ في شاشة** (`AM-002`).
      expect(find.byType(BrandLogo), findsOneWidget);
      // ② **الاسم الظاهر من مصدر الحقيقة الواحد** ثم اسمُ الشاشة تحته.
      expect(find.text(appDisplayName), findsOneWidget);
      expect(find.text('لوحة اليوم'), findsOneWidget);
      // ③ **التاريخ `يوم / شهر`** — ★ **بصيغة الصورة المرجعية حرفياً.**
      expect(find.text('20 / 08'), findsOneWidget);
      // ④ **الصورة الرمزية بالحرف الأول.**
      expect(find.byType(QtmsAvatar), findsOneWidget);
      expect(find.text('م'), findsOneWidget);
    });

    testWidgets('★★ واسمُ الشاشة ديناميكيٌّ لا ثابتٌ في المكوّن',
        (WidgetTester tester) async {
      await pumpBar(tester, screenTitle: 'سجل التدقيق');
      expect(find.text('سجل التدقيق'), findsOneWidget);
      expect(find.text('لوحة اليوم'), findsNothing);
      // ⛔ **واسمُ التطبيق لا يتبدّل معه.**
      expect(find.text(appDisplayName), findsOneWidget);
    });

    testWidgets('★★ والحرفُ يتبدّل بتبدّل صاحب الجلسة',
        (WidgetTester tester) async {
      await pumpBar(tester, userName: 'عبدالفتاح');
      expect(find.text('ع'), findsOneWidget);
      await pumpBar(tester, userName: 'أحمد');
      expect(find.text('أ'), findsOneWidget);
    });

    testWidgets('⚠️ واسمٌ فارغٌ يُعطي «؟» ⛔ لا مربّعاً خاوياً',
        (WidgetTester tester) async {
      await pumpBar(tester, userName: '   ');
      expect(find.text('؟'), findsOneWidget);
    });
  });

  group('⛔⛔★★★ التاريخ — يوم / شهر بصفرٍ بادئ', () {
    test('★ صفرٌ بادئٌ في الطرفين — فعرضُ النصّ ثابتٌ طوال الشهر', () {
      expect(dayMonthLabel(CalendarDay(2026, 1, 5)), '05 / 01');
      expect(dayMonthLabel(CalendarDay(2026, 12, 31)), '31 / 12');
    });

    test('⛔★★ واليومُ أولاً لا الشهر — ⟵ فلا يُقرأ الشهرُ يوماً', () {
      // ★ **20 / 08 = اليوم العشرون من الشهر الثامن** — ⛔ **لا العكس.**
      expect(dayMonthLabel(CalendarDay(2026, 8, 20)), '20 / 08');
    });
  });

  group('⛔⛔★★★ حالة الاتصال — مقيسةٌ لا مُدَّعاة', () {
    testWidgets('✅ متصل ⟵ نصٌّ صريح لا لونٌ وحده', (WidgetTester tester) async {
      await pumpBar(tester);
      expect(find.text('متصل'), findsOneWidget);
    });

    testWidgets('⛔ وغيرُ متصلٍ يُعلَن ولا يُخفى', (WidgetTester tester) async {
      await pumpBar(tester, connection: ConnectionStatus.offline);
      expect(find.text('غير متصل'), findsOneWidget);
      expect(find.text('متصل'), findsNothing);
    });

    testWidgets(
      '⛔⛔★★★ وقبل أي قياسٍ لا يُقال «متصل» — ADR-0003',
      (WidgetTester tester) async {
        // ★★★ **وهو جوهرُ البند:** ⟵ **وسمُ «متصل» بلا قياسٍ ادّعاءٌ لا
        //    معلومة**، ⛔ **وهو ضدُّ ما وُجد المؤشّر لأجله.**
        await pumpBar(tester, connection: ConnectionStatus.unknown);
        expect(find.text('متصل'), findsNothing);
        expect(find.text('غير متصل'), findsNothing);
        expect(find.text('يتحقق'), findsOneWidget);
      },
    );
  });

  group('★★ التجاوب — §3-أ القاعدة 4', () {
    testWidgets(
      '⛔★★★ عند الضيق يُقصّ اسمُ الشاشة وحده — ⛔ ولا تختفي حالةُ الاتصال '
      'ولا الصورةُ الرمزية',
      (WidgetTester tester) async {
        // ★ **شاشةٌ ضيّقة دون نقطة التكسير** — `Breakpoints.compact`.
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await pumpBar(
          tester,
          screenTitle: 'اسمُ شاشةٍ طويلٌ جداً لا يتّسع له عرضُ الشريط إطلاقاً',
        );

        // ⛔ **ولا فيضان** — ★ **`tester` يرمي على أي تجاوزٍ في التخطيط.**
        expect(tester.takeException(), isNull);
        // ★ **العناصرُ الثلاثة الأخرى باقية.**
        expect(find.text('متصل'), findsOneWidget);
        expect(find.byType(QtmsAvatar), findsOneWidget);
        expect(find.text('20 / 08'), findsOneWidget);
      },
    );

    testWidgets('★★ ويحتمل تكبيرَ النصّ 200٪ بلا فيضان — §8',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ar'),
          builder: (BuildContext context, Widget? child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2.0)),
            child: child!,
          ),
          home: Scaffold(
            appBar: QtmsTopBarView(
              screenTitle: 'مخزون اليوم',
              userName: 'محمد',
              today: CalendarDay(2026, 8, 20),
              connection: ConnectionStatus.online,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}

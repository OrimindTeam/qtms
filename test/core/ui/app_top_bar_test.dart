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
import 'package:qtms/core/design/design_tokens.dart';
import 'package:qtms/core/ui/app_top_bar.dart';
import 'package:qtms/core/ui/avatar.dart';
import 'package:qtms_domain/qtms_domain.dart';

Future<void> pumpBar(
  WidgetTester tester, {
  String screenTitle = 'لوحة اليوم',
  String userName = 'محمد',
  CalendarDay? today,
  ConnectionStatus connection = ConnectionStatus.online,
  VoidCallback? onAvatarTap,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('ar'),
      home: Directionality(
        // ⛔⛔★★ **واتجاهٌ صريح لا مُستنتَجٌ من `locale`** — ★ **الاختبارُ بلا
        //    `localizationsDelegates` يقع على `ltr` الافتراضية**، ⟵ **فتُقاس
        //    الحوافُّ مقلوبةً** ⛔ **ويمرّ اختبارُ محاذاةٍ وهو يقيس الطرف الخطأ.**
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: QtmsTopBarView(
            screenTitle: screenTitle,
            userName: userName,
            today: today ?? CalendarDay(2026, 8, 20),
            connection: connection,
            onAvatarTap: onAvatarTap,
          ),
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
      expect(find.text('2026 / 08 / 20'), findsOneWidget);
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

  group('⛔⛔★★★ التاريخ — اليومُ أولاً في اتجاه القراءة العربية (AM-012 ①)', () {
    test('★ صفرٌ بادئٌ في اليوم والشهر — فعرضُ النصّ ثابتٌ طوال الشهر', () {
      expect(topBarDayLabel(CalendarDay(2026, 1, 5)), '2026 / 01 / 05');
      expect(topBarDayLabel(CalendarDay(2026, 12, 31)), '2026 / 12 / 31');
    });

    test(
      '⛔⛔★★★ واليومُ في آخر النصّ ⟵ فيقع أولَ ما تراه العينُ من اليمين',
      () {
        // ★★★ **تصحيحُ خطأٍ أبلغ عنه المالك (2026-09-02):** ★ **نُفِّذ أولاً
        //    `20 / 08 / 2026`** — ⟵ **فرأى على الجهاز أن *السنةَ* تظهر أولاً**،
        //    ⛔ **لأن قراءتَه تبدأ من اليمين حيث تقع `2026`.**
        //    ⟹ ★ **فالخطأ كان في افتراض أن «الأول» هو الطرفُ الأيسر.**
        final String label = topBarDayLabel(CalendarDay(2026, 8, 20));
        expect(label, '2026 / 08 / 20');
        // ⛔⛔ **واليومُ آخرَ النصّ قطعاً** — ★ **وهو ما يجعله أولَ المقروء.**
        expect(label.endsWith('20'), isTrue);
        expect(label.startsWith('2026'), isTrue);
      },
    );

    test(
      '⛔⛔★★★ والسنةُ حقلٌ ثالثٌ إلزامي — ⟵ فحقلان يحتملان قراءتين (AM-012 ①)',
      () {
        final String label = topBarDayLabel(CalendarDay(2026, 1, 5));
        expect(label.split(' / ').length, 3);
      },
    );

    test(
      '⛔⛔★★★ و`formatReadable()` لم تُمَسّ — قرارُ المالك في AM-012 §2 ①',
      () {
        // ★★ **لها قارئٌ ثانٍ خارج الشاشة** (`FR-M12-11`) — ⟵ **وتغييرُها
        //    كان يجعل نصّاً مخزَّناً يُقرأ بصيغتين.**
        expect(CalendarDay(2026, 1, 5).formatReadable(), '2026/01/05');
      },
    );
  });

  group('⛔⛔★★★ المحاذاةُ البصرية على الطرفين (AM-012 · بلاغُ المالك)', () {
    testWidgets(
      '★★★ الشعارُ والصورةُ الرمزية على بُعدٍ واحدٍ من حافتَي الشاشة',
      (WidgetTester tester) async {
        // ⚠️⚠️★★★ **عطلٌ رآه المالكُ على الجهاز (2026-09-02):** ★ **«مسافة
        //    فارغة بين يسار الشاشة والأفتار»** — ⟵ **لأن الصورة 36 داخل هدف
        //    لمسٍ 48**: ⛔ **فكان الفراغُ 22 مقابل 16 عند الشعار.**
        //
        // ⛔⛔ **والعلاجُ ليس تصغيرَ هدف اللمس** — ★ **§5 البند 3 يفرض 48**:
        //    ⟵ **بل طرحُ الفائض من حشو النهاية** ⟹ **فتتساوى المسافةُ المرئية.**
        await pumpBar(tester, onAvatarTap: () {});

        final Rect logo = tester.getRect(find.byType(BrandLogo));
        final Rect avatar = tester.getRect(find.byType(QtmsAvatar));
        final Size screen =
            tester.view.physicalSize / tester.view.devicePixelRatio;

        // ★ **الشعارُ عند البداية (اليمين في RTL) والصورةُ عند النهاية.**
        final double logoEdgeGap = screen.width - logo.right;
        final double avatarEdgeGap = avatar.left;

        expect(
          avatarEdgeGap,
          moreOrLessEquals(logoEdgeGap, epsilon: 0.5),
          reason: '⛔ الفراغُ المرئي يجب أن يتساوى على الطرفين',
        );
        // ⛔⛔★★★ **ولا فراغَ ميتاً بين الصورة والحافة** — ★ **وهو العطلُ
        //    الذي أبلغ عنه المالك:** ⟵ **123 بكسلاً من حصّةٍ حجزتها
        //    `Flexible` ولم تستعملها.**
        expect(
          avatarEdgeGap,
          lessThanOrEqualTo(Spacing.screenPadding + 0.5),
          reason: '⛔ فراغٌ ميتٌ عاد — راجع سقفَ عمود التاريخ',
        );
      },
    );

    testWidgets(
      '⛔⛔★★★ وهدفُ اللمس يبقى 48 كاملاً — §5 البند 3',
      (WidgetTester tester) async {
        // ★★★ **وهذا الشرطُ هو ما يمنع «العلاج» الخاطئ:** ⛔ **تصغيرُ الهدف
        //    كان سيُساوي المسافةَ ويكسر إمكانيةَ الوصول معاً.**
        await pumpBar(tester, onAvatarTap: () {});
        final Size hit = tester.getSize(find.byType(IconButton).first);
        expect(hit.width, greaterThanOrEqualTo(Sizes.minTouch));
        expect(hit.height, greaterThanOrEqualTo(Sizes.minTouch));
      },
    );
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
        expect(find.text('2026 / 08 / 20'), findsOneWidget);
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

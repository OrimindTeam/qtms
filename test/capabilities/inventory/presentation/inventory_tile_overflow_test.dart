/// ★★ اختبارُ ارتدادٍ لتجاوز تخطيط بطاقة المخزون — `DEBT-36`.
///
/// ⛔⛔★★★ **عطلٌ وقع فعلاً على المحاكي (2026-08-26):** بطاقةُ الجونية كانت
/// تُرسَم **حرفاً في كل سطر** مع شريط التجاوز الأصفر **فور إضافة أول سطور**
/// إليها — ★ **لأن شارةً ثانية تظهر عندئذٍ** («⏳ سعر غير نهائي») **فتعصر
/// عمودَ النص حتى الصفر** في صفٍّ بلا قيد.
///
/// ⚠️⚠️ **ولم يفشل به اختبارٌ واحد:** ★ **اختبارات الشاشة تبني البطاقة بشارةٍ
/// واحدة وبعرضٍ واسع** — ⟵ **فالحالة الحقيقية (شارتان على عرض هاتف) لم
/// تُختبَر قط.**
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qtms/capabilities/inventory/presentation/inventory_widgets.dart';

void main() {
  testWidgets(
    '⛔⛔★★★ DEBT-36: بطاقةٌ بشارتين على عرض هاتف — ⛔ ولا تجاوزَ تخطيط',
    (WidgetTester tester) async {
      // ★ **عرضُ هاتفٍ حقيقي** — ⛔ لا سطحُ اختبارٍ واسع يُخفي العطل.
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('ar'),
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: InventoryTile(
                title: 'جونية رقم 2',
                // ★ **النصّ الحقيقي الذي رُصد** — ⛔ لا نصٌّ قصير مُصطنع.
                subtitle: 'SCK-20260826-0002 · المطالب به 23.000 كجم · 1 نوع',
                badges: <Widget>[
                  Chip(label: Text('متبقٍ 3.000 كجم')),
                  Chip(label: Text('⏳ سعر غير نهائي')),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // ⛔ **أي تجاوزٍ يُسجَّل استثناءً في `FlutterError`** — ★ والاختبار
      //   يفشل به تلقائياً. ★ **والتأكيد الصريح أوضحُ في التقرير:**
      expect(tester.takeException(), isNull);
      expect(find.text('جونية رقم 2'), findsOneWidget);
    },
  );
}

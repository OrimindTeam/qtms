/// ورقة الإرسال والتصدير — `M20` (`WU-010`).
///
/// ⚠️⚠️ **وما تُثبته هذه الاختبارات:** أن **الصلاحية تُخفي الزرّ ولا تُعطِّله**،
/// وأن **غياب الرقم يمنع زرَّي الإرسال برسالة صريحة** (`FR-M20-02`)، وأن
/// **خيار «مع التسعير» يُعرَض معطَّلاً بسببٍ مكتوب حين تكون سطورٌ غير مسعَّرة**
/// (`FR-M20-03` · `AT-63`)، وأن **التصدير يُسجَّل مرةً واحدة بالحقول الصحيحة**
/// (`FR-M19-04`)، وأن **الرفض يُعرَض ولا يُغلق الورقة**.
///
/// ⛔⛔ **ولا تُثبت أن الرسالة وصلت** — ★ **ولا يوجد في النظام ما يعرف ذلك**
/// (`FR-M20-15` · `AT-64`): ⟵ **والورقة تقول «فُتحت» لا «أُرسلت».**
///
/// ⛔ **ولا تُثبت أن قيد «تصدير» كُتب فعلاً** — ★ **ذاك في السحابة**
/// (`functions/test/export_log_test.dart`) **وفي اختبار المحاكي.**
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qtms/capabilities/identity_access/application/session_providers.dart';
import 'package:qtms/capabilities/master_data/application/master_data_providers.dart';
import 'package:qtms/capabilities/oversight/application/messaging_providers.dart';
import 'package:qtms/capabilities/oversight/presentation/send_document_sheet.dart';
import 'package:qtms_domain/qtms_domain.dart';

import '../../../support/fake_identity.dart';
import '../../../support/fake_master_data.dart';
import '../../../support/fake_messaging.dart';

late FakeExportLog exportLog;
late FakeDocumentRenderer renderer;
late FakeShare share;
late FakeChannels channels;
late FakeMasterDataDirectory masterData;

const MessageBusiness _business = MessageBusiness(
  businessName: 'وكالة محمد المحامي',
);

DistributionMessageData _data({bool priced = true}) => DistributionMessageData(
      dealerName: 'أحمد صالح',
      stockDate: CalendarDay(2026, 8, 30),
      lines: <MessageLine>[
        MessageLine(
          itemName: 'شامي',
          quantity: const PieceQuantity(PieceCount(60)),
          unitPrice: priced ? const Money(1500) : null,
          lineTotal: priced ? const Money(90000) : null,
        ),
      ],
      debtValue: priced ? const Money(90000) : Money.zero,
      previousBalance: const Money(8000),
      currentBalance: const Money(98000),
    );

SendableDocument distributionDocument({
  bool priced = true,
  String phone = '771234567',
}) =>
    SendableDocument(
      title: 'إرسال التوزيعة',
      offersTemplateChoice: true,
      pricedTemplateAvailable: priced,
      phone: phone,
      renderMessage: (MessageTemplate template) => renderDistributionMessage(
        business: _business,
        data: _data(priced: priced),
        template: template,
      ),
      renderShortMessage: () => renderShortDistributionMessage(
        business: _business,
        data: _data(priced: priced),
      ),
      buildExport: (MessageTemplate template) => buildDistributionExport(
        business: _business,
        data: _data(priced: priced),
        sourceId: 'SRC-001',
        sourceName: 'مصدر صنعاء',
        entityId: 'MQT-0001_SRC-001_20260830',
        withPricing: template == MessageTemplate.distributionWithPricing,
      ),
    );

Future<void> pumpSheet(
  WidgetTester tester, {
  required SendableDocument document,
  Set<Permission> permissions = const <Permission>{
    Permission.messagingSend,
    Permission.documentExport,
  },
}) async {
  final FakeAuthRepository auth = FakeAuthRepository();
  final FakeUserCardRepository cards = FakeUserCardRepository();
  auth.emitIdentity(
    const AuthenticatedIdentity(userId: 'U-001', sourceScope: AllSources()),
  );
  cards.emitCard('U-001', testCard(permissions: permissions));

  final ProviderContainer container = ProviderContainer(overrides: [
    authRepositoryProvider.overrideWithValue(auth),
    userCardRepositoryProvider.overrideWithValue(cards),
    masterDataDirectoryProvider.overrideWithValue(masterData),
    exportLogRepositoryProvider.overrideWithValue(exportLog),
    pdfRendererProvider.overrideWithValue(renderer),
    documentShareProvider.overrideWithValue(share),
    messageChannelProvider.overrideWithValue(channels.launcher),
  ]);
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('ar'),
        home: Builder(
          builder: (BuildContext context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () =>
                    showQtmsSendSheet(context, document: document),
                child: const Text('افتح'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.tap(find.text('افتح'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    exportLog = FakeExportLog();
    renderer = FakeDocumentRenderer();
    share = FakeShare();
    channels = FakeChannels();
    masterData = FakeMasterDataDirectory();
  });

  group('⛔★★ الصلاحيات تُخفي لا تُعطِّل — `ui-guidelines.md` §2', () {
    testWidgets('★ بلا `messagingSend` لا يظهر زرّا الإرسال', (
      WidgetTester tester,
    ) async {
      await pumpSheet(
        tester,
        document: distributionDocument(),
        permissions: const <Permission>{Permission.documentExport},
      );

      expect(find.text('فتح واتساب'), findsNothing);
      expect(find.text('فتح الرسائل'), findsNothing);
      // ★ **والتصدير يبقى** — ⟵ **فهما صلاحيتان لا واحدة** (`IQ-032`).
      expect(find.text('تصدير ملف ومشاركته'), findsOneWidget);
    });

    testWidgets('★ وبلا `documentExport` لا يظهر زرّ التصدير', (
      WidgetTester tester,
    ) async {
      await pumpSheet(
        tester,
        document: distributionDocument(),
        permissions: const <Permission>{Permission.messagingSend},
      );

      expect(find.text('تصدير ملف ومشاركته'), findsNothing);
      expect(find.text('فتح واتساب'), findsOneWidget);
    });
  });

  group('FR-M20-02 — لا رقم ⟵ لا إرسال', () {
    testWidgets('⛔ الزرّان يختفيان ورسالةٌ صريحة تحلّ محلّهما', (
      WidgetTester tester,
    ) async {
      await pumpSheet(tester, document: distributionDocument(phone: '   '));

      expect(find.text('فتح واتساب'), findsNothing);
      expect(
        find.textContaining('لا يوجد رقم هاتف صحيح'),
        findsOneWidget,
      );
    });
  });

  group('FR-M20-03 · AT-63 — «مع التسعير» معطَّلٌ بسطورٍ غير مسعَّرة', () {
    testWidgets('⛔ معطَّلٌ ★ ومعروضٌ بسببه مكتوباً', (
      WidgetTester tester,
    ) async {
      await pumpSheet(tester, document: distributionDocument(priced: false));

      // ★ **معروضٌ لا مخفيّ** — ⟵ **فيعرف المستخدم أن الخيار موجود.**
      expect(find.text('التوزيع مع التسعير'), findsOneWidget);
      expect(find.text('يتطلب أن تكون كل السطور مسعَّرة.'), findsOneWidget);

      final RadioListTile<MessageTemplate> tile =
          tester.widget<RadioListTile<MessageTemplate>>(
        find.widgetWithText(
          RadioListTile<MessageTemplate>,
          'التوزيع مع التسعير',
        ),
      );
      expect(tile.enabled, isFalse);
    });

    testWidgets('✅ ومُفعَّلٌ حين تكون كل السطور مسعَّرة', (
      WidgetTester tester,
    ) async {
      await pumpSheet(tester, document: distributionDocument());

      final RadioListTile<MessageTemplate> tile =
          tester.widget<RadioListTile<MessageTemplate>>(
        find.widgetWithText(
          RadioListTile<MessageTemplate>,
          'التوزيع مع التسعير',
        ),
      );
      expect(tile.enabled, isTrue);
    });
  });

  group('★★ المعاينة — ما سيصل المستلِم حرفياً', () {
    testWidgets('★ القالب ① بلا سعر ⛔ ولا ضمار', (WidgetTester tester) async {
      await pumpSheet(tester, document: distributionDocument());

      expect(find.textContaining('شامي — 60 حبة'), findsOneWidget);
      expect(find.textContaining('ضمار اليوم'), findsNothing);
    });

    testWidgets('★★ واختيار ② يُبدِّل النصّ المعروض فوراً', (
      WidgetTester tester,
    ) async {
      await pumpSheet(tester, document: distributionDocument());

      await tester.tap(find.text('التوزيع مع التسعير'));
      await tester.pumpAndSettle();

      expect(find.textContaining('ضمار اليوم: 90,000'), findsOneWidget);
      expect(find.textContaining('الرصيد الحالي: 98,000'), findsOneWidget);
    });
  });

  group('★ الإرسال — يفتح المحادثة ولا يُرسِل', () {
    testWidgets('★★ واتساب يفتح الرابط ★ والرسالة تقول «فُتحت»', (
      WidgetTester tester,
    ) async {
      await pumpSheet(tester, document: distributionDocument());

      await tester.tap(find.text('فتح واتساب'));
      await tester.pumpAndSettle();

      // ⛔⛔★★ **مخطَّط `whatsapp:` لا `https`** — ★ **عطلٌ رُصد حيّاً**
      //    (2026-08-30): **المتصفّحُ يعالج كلَّ `https`** ⟵ **فيُفتَح بدل واتساب.**
      expect(channels.opened.single.scheme, 'whatsapp');
      // ⛔⛔ **ولا كلمة «أُرسلت»** — ★ **النظام لا يعرف إن وصلت.**
      expect(find.textContaining('فُتحت المحادثة'), findsOneWidget);
      // ⛔⛔★★ **ولا تسجيلَ للإرسال إطلاقاً** — `AT-64`.
      expect(exportLog.logged, isEmpty);
    });

    testWidgets('★ FR-M20-12: واتساب غير مثبَّت ⟵ يقترح الرسائل النصية', (
      WidgetTester tester,
    ) async {
      channels.available = false;
      await pumpSheet(tester, document: distributionDocument());

      await tester.tap(find.text('فتح واتساب'));
      await tester.pumpAndSettle();

      expect(find.textContaining('غير مثبَّت'), findsOneWidget);
      expect(find.textContaining('رسالة نصية'), findsOneWidget);
    });
  });

  group('★★★ التصدير — `FR-M20-14` · `FR-M19-04`', () {
    testWidgets('★★ يبني الملف ويشاركه ثم يُسجِّله مرةً واحدة', (
      WidgetTester tester,
    ) async {
      await pumpSheet(tester, document: distributionDocument());

      // ★★ **والزرُّ أسفلَ معاينةٍ نصّيةٍ غيرِ محدودة الطول** — ⟵ **فيقع
      //    خارج مَنفَذ العرض في اختبارٍ بشاشةٍ صغيرة**: ★ **والورقةُ
      //    تُمرَّر فعلاً** (`SingleChildScrollView`)، ⛔ **فالتمرير قبل
      //    النقر يحاكي المستخدم** ⛔ **ولا يُخفَّف الفحص.**
      await tester.ensureVisible(find.text('تصدير ملف ومشاركته'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('تصدير ملف ومشاركته'));
      await tester.pumpAndSettle();

      expect(renderer.rendered, hasLength(1));
      expect(share.shared, hasLength(1));
      expect(exportLog.logged, hasLength(1));

      final LoggedExport entry = exportLog.logged.single;
      expect(entry.entityType, distributionEntityType);
      expect(entry.entityId, 'MQT-0001_SRC-001_20260830');
      expect(entry.sourceId, 'SRC-001');
      expect(entry.format, ExportedFormat.pdf);
      expect(find.textContaining('تسجيل التصدير'), findsOneWidget);
    });

    testWidgets('★★ والملفُّ يتبع القالب المختار — ⛔ لا سعرَ في ①', (
      WidgetTester tester,
    ) async {
      await pumpSheet(tester, document: distributionDocument());

      // ★★ **والزرُّ أسفلَ معاينةٍ نصّيةٍ غيرِ محدودة الطول** — ⟵ **فيقع
      //    خارج مَنفَذ العرض في اختبارٍ بشاشةٍ صغيرة**: ★ **والورقةُ
      //    تُمرَّر فعلاً** (`SingleChildScrollView`)، ⛔ **فالتمرير قبل
      //    النقر يحاكي المستخدم** ⛔ **ولا يُخفَّف الفحص.**
      await tester.ensureVisible(find.text('تصدير ملف ومشاركته'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('تصدير ملف ومشاركته'));
      await tester.pumpAndSettle();

      // ★ **القالب ① افتراضاً** — ⟵ **فعمودان لا أربعة.**
      expect(renderer.rendered.single.columns, <String>['النوع', 'الكمية']);
    });

    testWidgets('⛔ ورفضُ التسجيل يُعرَض ولا يُغلق الورقة', (
      WidgetTester tester,
    ) async {
      exportLog.rejection = const PermissionError();
      await pumpSheet(tester, document: distributionDocument());

      // ★★ **والزرُّ أسفلَ معاينةٍ نصّيةٍ غيرِ محدودة الطول** — ⟵ **فيقع
      //    خارج مَنفَذ العرض في اختبارٍ بشاشةٍ صغيرة**: ★ **والورقةُ
      //    تُمرَّر فعلاً** (`SingleChildScrollView`)، ⛔ **فالتمرير قبل
      //    النقر يحاكي المستخدم** ⛔ **ولا يُخفَّف الفحص.**
      await tester.ensureVisible(find.text('تصدير ملف ومشاركته'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('تصدير ملف ومشاركته'));
      await tester.pumpAndSettle();

      // ★ **والملف وصل المستخدم قبل الرفض** — ⟵ **فلا يُلغى مخرَجٌ بيده.**
      expect(share.shared, hasLength(1));
      expect(find.text('إغلاق'), findsOneWidget);
      expect(find.text('تم إنشاء الملف وتسجيل التصدير.'), findsNothing);
    });

    testWidgets('⛔ وفشلُ إنشاء الملف يمنع التسجيل أصلاً', (
      WidgetTester tester,
    ) async {
      share.fails = true;
      await pumpSheet(tester, document: distributionDocument());

      // ★★ **والزرُّ أسفلَ معاينةٍ نصّيةٍ غيرِ محدودة الطول** — ⟵ **فيقع
      //    خارج مَنفَذ العرض في اختبارٍ بشاشةٍ صغيرة**: ★ **والورقةُ
      //    تُمرَّر فعلاً** (`SingleChildScrollView`)، ⛔ **فالتمرير قبل
      //    النقر يحاكي المستخدم** ⛔ **ولا يُخفَّف الفحص.**
      await tester.ensureVisible(find.text('تصدير ملف ومشاركته'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('تصدير ملف ومشاركته'));
      await tester.pumpAndSettle();

      expect(find.textContaining('تعذّر إنشاء الملف'), findsOneWidget);
      // ⛔⛔★★ **ولا قيدَ تصديرٍ لملفٍ لم يخرج** — ★ **وإلا كذب السجل.**
      expect(exportLog.logged, isEmpty);
    });
  });
}

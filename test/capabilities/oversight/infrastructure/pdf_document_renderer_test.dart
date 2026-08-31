/// راسم المستند المُصدَّر ومشاركتُه — `M20` (`WU-010`).
///
/// ⚠️⚠️ **وما تُثبته هذه الاختبارات:** أن **الملف يُبنى فعلاً بايتاتٍ صالحة**،
/// وأن **الخطّين يُحمَّلان مرةً واحدة لا عند كل تصدير**، وأن **اسم الملف بلا
/// اسم عميل**، وأن **الفشل نتيجةٌ مصنَّفة لا استثناءٌ عارٍ**.
///
/// ⛔⛔ **ولا تُثبت أن العربية تظهر متّصلةً في القارئ** — ★ **ذاك بندُ اختبار
/// المحاكي** (بروتوكول التشغيل §د.2): **ما لا تراه الاختبارات يُفحَص بعين.**
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:qtms/capabilities/oversight/infrastructure/document_share_service.dart';
import 'package:qtms/capabilities/oversight/infrastructure/pdf_document_renderer.dart';
import 'package:qtms_domain/qtms_domain.dart';

const ExportableDocument _document = ExportableDocument(
  businessName: 'وكالة محمد المحامي',
  title: 'سند توزيع',
  header: <ExportField>[
    ExportField('تاريخ المخزون', '2026/08/30'),
    ExportField('المقوت', 'أحمد صالح'),
  ],
  columns: <String>['النوع', 'الكمية'],
  rows: <ExportRow>[
    ExportRow(<String>['شامي', '60 حبة']),
    ExportRow(<String>['سكرب', '0.500 كجم']),
  ],
  totals: <ExportField>[ExportField('الإجمالي', '60 حبة + 0.500 كجم')],
  entityType: distributionEntityType,
  entityId: 'MQT-0001_SRC-001_20260830',
  sourceId: 'SRC-001',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<String> loaded;

  /// ★ يقرأ الخطّ الحقيقي من القرص — ⛔ **ولا خطَّ وهمي**: ⟵ **الحزمة ترفض
  /// ملفاً ليس `TTF`**، ★ **فالاختبار يقيس المسار الفعلي.**
  Future<ByteData> loadAsset(String key) async {
    loaded.add(key);
    final Uint8List bytes = await File(key).readAsBytes();
    return ByteData.view(bytes.buffer);
  }

  setUp(() => loaded = <String>[]);

  group('★ بناء الملف', () {
    test('★★ بايتاتٌ صالحة تبدأ ببصمة PDF', () async {
      final Uint8List bytes =
          await PdfDocumentRenderer(loadAsset: loadAsset).render(_document);

      expect(bytes.length, greaterThan(1000));
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });

    test('★ والخطّان يُحمَّلان مرةً واحدة لكل نسخة ⛔ لا عند كل تصدير', () async {
      final PdfDocumentRenderer renderer =
          PdfDocumentRenderer(loadAsset: loadAsset);
      await renderer.render(_document);
      await renderer.render(_document);

      // ⚠️ **قراءةُ ملفَّي خطٍّ في كل ضغطةٍ تأخيرٌ محسوس** — راجع ترويسة الراسم.
      expect(loaded.length, 2);
      expect(loaded.toSet().length, 2);
    });

    test('⛔⛔ ولا خطَّ من خارج الخطّين المعتمدَين', () async {
      await PdfDocumentRenderer(loadAsset: loadAsset).render(_document);
      for (final String key in loaded) {
        expect(key, startsWith('assets/fonts/IBMPlexSansArabic-'));
      }
    });
  });

  group('★ المشاركة — `FR-M20-14`', () {
    test('★★ اسم الملف من نوع المستند ومعرّفه ⛔ بلا اسم عميل', () async {
      String? sharedPath;
      final Directory temp =
          await Directory.systemTemp.createTemp('qtms-export-test');
      addTearDown(() => temp.deleteSync(recursive: true));

      final DocumentShareOutcome outcome = await DocumentShareService(
        temporaryDirectory: () async => temp,
        shareFile: (String path, String subject) async => sharedPath = path,
      ).sharePdf(
        document: _document,
        bytes: Uint8List.fromList(<int>[1, 2, 3]),
      );

      expect(outcome, DocumentShareOutcome.shared);
      expect(sharedPath, endsWith('distribution-MQT-0001_SRC-001_20260830.pdf'));
      // ⛔⛔ **ولا اسم مقوتٍ في اسم الملف** — ★ **يظهر في قوائم المشاركة
      //    وسجلّات النظام** (`messaging-design.md` §8).
      expect(sharedPath, isNot(contains('أحمد')));
      expect(File(sharedPath!).readAsBytesSync(), <int>[1, 2, 3]);
    });

    test('⛔ والفشل نتيجةٌ مصنَّفة لا استثناءٌ عارٍ — §3 القاعدة 3', () async {
      final DocumentShareOutcome outcome = await DocumentShareService(
        temporaryDirectory: () async => throw StateError('لا مجلد مؤقت'),
        shareFile: (String _, String _) async {},
      ).sharePdf(
        document: _document,
        bytes: Uint8List.fromList(<int>[1]),
      );

      expect(outcome, DocumentShareOutcome.failed);
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  // ⛔⛔★★★ **اختبارُ ارتدادٍ لعطلٍ كشفه الجهاز وحده** (2026-08-30 · §د.2):
  // ★ **«مصدر الاختبار الأول» طُبعت «مصدر الاختبارالأول»** — ⟵ **الحزمة
  //   تُقطّع النصّ كلماتٍ وتعكس ترتيبها، وعرضُ الفراغ يُنسَب للفجوة الخطأ.**
  // ⛔ **ولم يكشفه أيٌّ من 1687 اختباراً** — ★ **لأنه في تخطيط حزمةٍ لا في
  //   منطقنا**: ⟹ **والحارسُ هنا على أن التخطيط بقي لنا.**
  // ═════════════════════════════════════════════════════════════════════
  group('★★★ فراغُ الكلمات في المستند — `spacedPdfValue`', () {
    const pw.TextStyle style = pw.TextStyle(fontSize: 10);

    test('★★ قيمةٌ من ثلاث كلمات ⟵ صفٌّ بثلاثة نصوص وفراغين نرسمهما', () {
      final pw.Widget widget = spacedPdfValue('مصدر الاختبار الأول', style);

      expect(widget, isA<pw.Row>());
      final List<pw.Widget> children = (widget as pw.Row).children;
      expect(children.whereType<pw.Text>().length, 3);
      // ★ **والفراغان مرسومان بعرضٍ من التوكنز** ⛔ **لا متروكان للحزمة.**
      expect(children.whereType<pw.SizedBox>().length, 2);
    });

    test('⛔ وكلمةٌ واحدة تبقى نصّاً مفرداً — ⛔ ولا صفَّ بلا داعٍ', () {
      expect(spacedPdfValue('سلة', style), isA<pw.Text>());
      expect(spacedPdfValue('', style), isA<pw.Text>());
    });
  });
}

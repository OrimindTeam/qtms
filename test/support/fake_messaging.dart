/// بدائل الإرسال والتصدير للاختبار — ★ **بلا جهازٍ ولا نظام ملفاتٍ ولا شبكة**
/// (`ADR-0010`).
///
/// ⛔⛔★★ **ولا بديلَ لتسجيل الإرسال** — ★ **لأنه لا وجود له أصلاً**
/// (`FR-M20-15` · `AT-64`): ⟵ **والبديلُ الوحيد هنا للتصدير.**
library;

import 'dart:typed_data';

import 'package:qtms/capabilities/oversight/infrastructure/document_share_service.dart';
import 'package:qtms/capabilities/oversight/infrastructure/message_channel_launcher.dart';
import 'package:qtms/capabilities/oversight/infrastructure/pdf_document_renderer.dart';
import 'package:qtms_domain/qtms_domain.dart';

/// حمولةُ تسجيلِ تصديرٍ واحدة — ★ **لتُفحَص حقلاً حقلاً**.
final class LoggedExport {
  /// ينشئ الحمولة.
  const LoggedExport({
    required this.sourceId,
    required this.entityType,
    required this.entityId,
    required this.format,
    this.documentNumber,
  });

  /// المصدر — **ويُقاس عليه النطاق في السحابة** (`GR-23`).
  final String sourceId;

  /// نوع الكيان المُصدَّر.
  final String entityType;

  /// معرّف الكيان المُصدَّر.
  final String entityId;

  /// الصيغة.
  final ExportedFormat format;

  /// رقم المستند إن كان مرقَّماً.
  final String? documentNumber;
}

/// مستودع تسجيل تصديرٍ بديل — ★ **يحفظ ما أُرسل**.
final class FakeExportLog implements ExportLogRepository {
  /// كل ما سُجِّل — ★ **قائمةٌ لا آخرُ قيمة**: ⟵ **فيُقاس أن التصدير يُسجَّل
  /// مرةً واحدة** ⛔ **لا مرتين.**
  final List<LoggedExport> logged = <LoggedExport>[];

  /// رفضٌ مُبرمَج — ★ **لاختبار عرض رسالة الكتالوج داخل الورقة.**
  AppError? rejection;

  @override
  Future<Outcome<void>> logExport({
    required String sourceId,
    required String entityType,
    required String entityId,
    required ExportedFormat format,
    String? documentNumber,
  }) async {
    logged.add(
      LoggedExport(
        sourceId: sourceId,
        entityType: entityType,
        entityId: entityId,
        format: format,
        documentNumber: documentNumber,
      ),
    );
    final AppError? error = rejection;
    return error == null ? const Success<void>(null) : Failure<void>(error);
  }
}

/// ★ راسمٌ بديل — ⛔ **ولا يُقرأ قرصٌ في اختبار واجهة**.
///
/// ⚠️ **وصحّةُ الملف نفسِها تُقاس في `pdf_document_renderer_test.dart`** —
/// ⟵ **وهذا يقيس مسار الشاشة وحده.**
final class FakeDocumentRenderer implements DocumentRenderer {
  /// المستندات التي طُلب رسمُها.
  final List<ExportableDocument> rendered = <ExportableDocument>[];

  @override
  Future<Uint8List> render(ExportableDocument document) async {
    rendered.add(document);
    // ★ بصمة `%PDF` — ⟵ **فالبديل يشبه ما يُنتجه الراسم الحقيقي.**
    return Uint8List.fromList(<int>[37, 80, 68, 70]);
  }
}

/// ★ مُشارِكٌ بديل — **بلا نظام ملفاتٍ ولا ورقة نظام**.
///
/// ⛔⛔★★ **ولا يكتب قرصاً إطلاقاً** — ★ **وكتابةُ القرص لا يحصرها
/// `pumpAndSettle`**: ⟵ **فاختبارُ الشاشة كان يقرأ النتيجة قبل اكتمالها**
/// (رُصد فعلاً 2026-08-30). ★ **وصحّةُ الكتابة تُقاس في اختبار الخدمة وحده.**
final class FakeShare implements DocumentSharer {
  /// المستندات التي سُلِّمت للمشاركة.
  final List<ExportableDocument> shared = <ExportableDocument>[];

  /// هل تفشل الكتابة؟ — ★ **لاختبار الرسالة المصنَّفة.**
  bool fails = false;

  @override
  Future<DocumentShareOutcome> sharePdf({
    required ExportableDocument document,
    required Uint8List bytes,
  }) async {
    if (fails) return DocumentShareOutcome.failed;
    shared.add(document);
    return DocumentShareOutcome.shared;
  }
}

/// ★ فاتحُ قنواتٍ بديل — **يحفظ ما فُتح** ⛔ **ولا يلمس جهازاً**.
final class FakeChannels {
  /// الروابط التي طُلب فتحُها.
  final List<Uri> opened = <Uri>[];

  /// هل القناة متاحة؟ — `false` تُحاكي **غياب واتساب** (`FR-M20-12`).
  bool available = true;

  /// الفاتحُ الجاهز للحقن.
  MessageChannelLauncher get launcher => MessageChannelLauncher(
        canLaunch: (Uri _) async => available,
        launch: (Uri uri) async {
          opened.add(uri);
          return true;
        },
      );
}

/// ★★★ تصديرُ مستندٍ ومشاركتُه ثم تسجيلُه — **إجراءٌ واحدٌ يشاركه كل مُصدِّر**.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **والترتيب مقصودٌ ومُعلَن** (`messaging-design.md` §9): ★ **الملفُّ
/// يُبنى ويُشارَك أولاً، ثم يُسجَّل** — ⟵ **فرفضُ السحابة يصل المستخدمَ
/// رسالةً صريحة**، ⛔ **ولا يُلغى مخرَجٌ صار بيده أصلاً.**
///
/// ⛔⛔★★ **ولا يُبتلَع رفضُ التسجيل** — ★ **مقيسٌ حيّاً في `WU-010` بقطع
/// الشبكة** (§د.2 · السيناريو الثالث عشر): ⟵ **يُعرَض ولا يُكتَب قيدٌ وهمي.**
///
/// ★★ **ولماذا دالةٌ واحدة لا نسخةٌ في كل شاشة:** ⟵ **`WU-010` بنت هذا
/// التسلسل في ورقة الإرسال، و`WU-011` تحتاجه في شاشة التقارير** — ★ **ونسخةٌ
/// ثانية منه تفترق عند أول تعديل** (`coding-standards.md` §2.2 ·
/// `design-system.md` §8 المحظور الحادي عشر: **لا نسخُ مكوّنٍ بدل إعادة
/// استخدامه**).
/// ═══════════════════════════════════════════════════════════════════════
library;

import 'package:qtms_domain/qtms_domain.dart';

import '../../../core/messages/error_messages.dart';
import '../infrastructure/document_share_service.dart';
import '../infrastructure/pdf_document_renderer.dart';

/// نتيجةُ التصدير — **حكمٌ ونصٌّ جاهزان للعرض**.
///
/// ⛔ **ولا تُترجَم في شاشة** — ★ **رسائلُ الخطأ من الكتالوج المعتمد وحده**
/// (`error-handling-strategy.md` §3 القاعدة 2).
final class DocumentExportResult {
  /// ينشئ النتيجة.
  const DocumentExportResult({required this.isSuccess, required this.message});

  /// هل اكتمل التصدير **والتسجيل** معاً؟
  final bool isSuccess;

  /// النصّ المعروض — ⛔ **بشرياً لا رمزاً تقنياً**.
  final String message;
}

/// ★★★ يُصدِّر المستند ويشاركه **ثم يُسجِّله** — `FR-M19-04` · `FR-M20-14`.
Future<DocumentExportResult> runDocumentExport({
  required ExportableDocument document,
  required DocumentRenderer renderer,
  required DocumentSharer sharer,
  required ExportLogRepository exportLog,
}) async {
  final DocumentShareOutcome shared = await sharer.sharePdf(
    document: document,
    bytes: await renderer.render(document),
  );
  if (shared == DocumentShareOutcome.failed) {
    return const DocumentExportResult(
      isSuccess: false,
      message: 'تعذّر إنشاء الملف. أعد المحاولة.',
    );
  }

  final Outcome<void> logged = await exportLog.logExport(
    sourceId: document.sourceId,
    entityType: document.entityType,
    entityId: document.entityId,
    format: ExportedFormat.pdf,
    documentNumber: document.documentNumber,
  );
  return switch (logged) {
    Success<void>() => const DocumentExportResult(
        isSuccess: true,
        message: 'تم إنشاء الملف وتسجيل التصدير.',
      ),
    Failure<void>(:final AppError error) => DocumentExportResult(
        isSuccess: false,
        message: catalogText(appErrorMessage(error)),
      ),
  };
}

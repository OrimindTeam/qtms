/// تنفيذ عملية `logExport` — **الطرف الذي يلمس الشبكة** (`WU-010`).
///
/// ★ **مفصول عن `export_log.dart` عمداً**، بنفس منطق `daily_pricing_handler.dart`:
/// كل قرار تفويض هناك في **دوال خالصة تُختبَر بلا سحابة**؛ وهنا **القراءة
/// والالتزام** وحدهما.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **معاملةٌ بلا قراءةٍ واحدة — وهو مقصود لا سهو**
///
/// كل عملية كاتبة أخرى تقرأ حالةً تبني عليها قرارها (رصيداً · مستنداً ·
/// عدّاداً). ★ **والتصدير لا يبني على شيء:** **يُخرِج نسخةً من بياناتٍ
/// قرأها المستخدمُ أصلاً بصلاحيته ونطاقه**، ⟵ **فالقيد يوثّق «من صدّر ماذا
/// ومتى»** ⛔ **لا يتحقق من حالةٍ.**
///
/// ⚠️⚠️ **وأثرٌ يجب أن يُقال صراحةً:** ★ **هذه العملية لا تتحقق من وجود
/// المستند المُصدَّر أصلاً** — ⟵ **فمُستدعٍ يملك `documentExport` والنطاق
/// يستطيع كتابة قيدِ تصديرٍ لمعرّفٍ لا وجود له.** ⛔ **والأثر محدود بحدّه:**
/// **قيدٌ زائف في سجلٍ يُقرأ بالنطاق نفسه** — ★ **ولا يُغيِّر مالاً ولا
/// مخزوناً ولا صلاحية**، ⟵ **وقراءةُ المستند للتحقق كانت تُضاعف كلفة كل
/// تصدير بلا أن تمنع شيئاً ذا أثر.** ★ **خطرٌ مُعلَن مقبول بقرارٍ لا بسهو.**
/// ═══════════════════════════════════════════════════════════════════════
library;

import 'package:qtms_domain/qtms_domain.dart';
import 'package:shelf/shelf.dart';

import 'audited_transaction.dart';
import 'callable.dart';
import 'export_log.dart';
import 'identity_gateway.dart';
import 'permission_sync_handler.dart' show requestIdField;

/// اسم حقل المصدر في الحمولة.
const String exportSourceIdField = 'sourceId';

/// اسم حقل نوع الكيان المُصدَّر.
const String exportEntityTypeField = 'entityType';

/// اسم حقل معرّف الكيان المُصدَّر.
const String exportEntityIdField = 'entityId';

/// اسم حقل رقم المستند — **اختياري**.
const String exportDocumentNumberField = 'documentNumber';

/// اسم حقل تاريخ المخزون — **اختياري**.
const String exportStockDateField = 'stockDate';

/// اسم حقل صيغة الملف.
const String exportFormatField = 'exportFormat';

/// اسم حقل وصف الجهاز — **اختياري**.
const String exportDeviceInfoField = 'deviceInfo';

/// منفّذ عملية تسجيل التصدير.
final class ExportLogHandler {
  /// ينشئ المنفّذ بتبعياته — ★ **تُحقَن، فيُختبَر بلا سحابة**.
  const ExportLogHandler({
    required IdentityGateway identity,
    required AuditedTransaction transaction,
  })  : _identity = identity,
        _transaction = transaction;

  final IdentityGateway _identity;
  final AuditedTransaction _transaction;

  /// ينفّذ [operation] على طلب HTTP خام.
  Future<Response> handle(
    Request httpRequest,
    ExportLogOperation operation,
  ) async {
    final CallableParse parsed = await parseCallableRequest(httpRequest);
    if (parsed is RejectedCallable) return callableFailure(parsed.error);
    final CallableRequest call = (parsed as ParsedCallable).request;

    try {
      return await _execute(call, operation);
    } on IdentityGatewayException catch (error) {
      return callableFailure(
        CallableError.sessionExpired,
        detail: error.diagnostic,
      );
    } on AbortTransaction catch (aborted) {
      return callableFailure(aborted.reason as CallableError);
    } on TransactionContentionException catch (error) {
      return callableFailure(CallableError.concurrency, detail: '$error');
    }
  }

  Future<Response> _execute(
    CallableRequest call,
    ExportLogOperation operation,
  ) async {
    final AccountRecord actor = await _identity.verifyIdToken(call.idToken);

    final String? requestId = call.readString(requestIdField);
    final String? sourceId = call.readString(exportSourceIdField);
    final String? entityType = call.readString(exportEntityTypeField);
    final String? entityId = call.readString(exportEntityIdField);
    final ExportFormat? format = _readFormat(call);
    if (requestId == null ||
        sourceId == null ||
        entityType == null ||
        entityId == null ||
        format == null) {
      return callableFailure(CallableError.invalidArgument);
    }

    final String? rawStockDate = call.readString(exportStockDateField);
    // ★ **تاريخٌ مُرسَلٌ غيرُ قابلٍ للفكّ رفضٌ** — ⛔ **ولا يُطوى في `null`**:
    //   ⟵ **فقيدٌ بلا `stockDate` يقول «لا يخصّ يوماً»**، ★ **وهو غير ما
    //   قصده المُرسِل** — والالتباس في سجلٍ هو الحافظ الوحيد للتاريخ.
    CalendarDay? stockDate;
    if (rawStockDate != null) {
      stockDate = CalendarDay.tryParseCompact(rawStockDate);
      if (stockDate == null) {
        return callableFailure(CallableError.invalidArgument);
      }
    }

    // ① البوابة — ⛔ قبل أي معاملة: الصلاحية **والنطاق** معاً.
    //   ★ **ووقتُ التمثيل هنا لا يُكتب**: الكاتب يستبدله بزمن المنصّة
    //   (`REQUEST_TIME`) داخل الالتزام نفسه (`GR-54`).
    ExportLogRequest buildRequest(DateTime occurredAt) => ExportLogRequest(
          actor: actor,
          requestId: requestId,
          sourceId: sourceId,
          entityType: entityType,
          entityId: entityId,
          format: format,
          occurredAt: occurredAt,
          documentNumber: call.readString(exportDocumentNumberField),
          stockDate: stockDate,
          deviceInfo: call.readString(exportDeviceInfoField),
        );

    final ExportLogRejected? gate = exportLogGate(
      buildRequest(DateTime.now().toUtc()),
      operation,
    );
    if (gate != null) return callableFailure(gate.error);

    await _transaction.run<void>(
      // ⛔ **لا قراءات** — راجع ترويسة الملف.
      readPaths: const <String>[],
      plan: (TransactionReads reads) {
        // ★★ **ساعة المنصّة من زمن القراءة** — ⛔ ولا ساعة الحاوية.
        // ⛔ **وغيابُ زمن المنصّة لا يُردّ إلى ساعة الحاوية في حقلٍ يُخزَّن**
        //   — ★ **ولا يُخزَّن هذا الوقت أصلاً**: `_auditWrite` يستبدله
        //   بـ`REQUEST_TIME` داخل الالتزام. ⟵ **فهو تمثيلٌ محض**، ★ **وقيمةُ
        //   الحاوية عنده مقبولةٌ صراحةً** ⛔ **ولا تعبر إلى القاعدة.**
        final ExportLogPlan plan = planExportLog(
          buildRequest((reads.readTime ?? DateTime.now()).toUtc()),
          operation,
        );
        return switch (plan) {
          // ★ **الرفض بعد فتح المعاملة يُبطلها صراحةً** — ⛔ ولا تُترك مفتوحة.
          ExportLogRejected(:final CallableError error) =>
            throw AbortTransaction(error),
          ExportLogAccepted(:final AuditEntry entry) => AuditedWrite<void>(
              // ⛔⛔★★★ **ولا مستندَ واحد** — ★ **والعَلَم يُصرَّح به**،
              //   ⟵ **فالحارس في `_commit` يقرأ نيّةً لا يُخمّنها.**
              documents: const <PendingDocument>[],
              auditOnly: true,
              entry: entry,
              result: null,
            ),
        };
      },
    );

    return callableSuccess(<String, Object?>{
      'entryId': requestId,
      'entityType': entityType,
      'entityId': entityId,
    });
  }

  /// يقرأ الصيغة — ⛔ **وقيمةٌ مجهولة رفضٌ** لا تجاوزٌ إلى افتراضٍ.
  static ExportFormat? _readFormat(CallableRequest call) {
    final String? raw = call.readString(exportFormatField);
    if (raw == null) return null;
    for (final ExportFormat format in ExportFormat.values) {
      if (format.wireName == raw) return format;
    }
    return null;
  }
}

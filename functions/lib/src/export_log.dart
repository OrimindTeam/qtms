/// تسجيل التصدير — **التخطيط الخالص** لعملية `logExport` (`M19` · `M20`).
///
/// ★ **مفصول عن الشبكة بنفس منطق `daily_pricing.dart`:** `ADR-0013` القاعدة 3
/// تجعل **فحص التفويض في الكود** هو الحارس الوحيد لهذا المسار، فالدالة تعمل
/// بامتياز إداري يتجاوز قواعد الحماية. ★ **وحارسٌ لا يُختبَر بلا سحابة
/// حارسٌ غير مُختبَر** — فكل قرار هنا **دالة خالصة**.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ★★★ **لماذا وُجدت هذه العملية أصلاً — `IQ-032` الخيار أ (2026-08-30)**
///
/// `FR-M19-04` يقول: «**التصدير يُسجَّل في سجل التدقيق بالإجراء «تصدير»**»،
/// و`messaging-design.md` §9 يعيدها للسندات — ⟵ ⛔ **والتطبيق ممنوعٌ من
/// كتابة `audit_log` مطلقاً** (`allow create, update, delete: if false`).
/// ★ **فلزمت عمليةٌ سحابية**، وهذه هي.
///
/// ⛔⛔★★★ **وهي أولُ عمليةٍ في النظام تكتب قيداً بلا مستندٍ مصاحب** —
/// ★ **لأن التصدير لا يُغيِّر بياناً**: **يُخرِج نسخةً ويغادر.**
/// ⟵ **ولذلك `AuditedWrite.auditOnly` عَلَمٌ صريحٌ مُسمّى** في
/// `audited_transaction.dart` ⛔ **لا إسقاطٌ لحارس «لا كتابةَ فارغة» للجميع.**
///
/// ⚠️ **والفرق بين هذا و`FR-M20-15` ليس تناقضاً:** ★ **الإرسال** إجراء واجهة
/// **لا يُسجَّل إطلاقاً** (`AT-64`) — ⛔ **ولا مسار له هنا** · ★ **والتصدير**
/// إخراجُ ملفٍ يغادر النظام **ويُسجَّل**. ⟵ **فعلان مختلفان لا فعلٌ واحد.**
/// ═══════════════════════════════════════════════════════════════════════
library;

import 'package:qtms_domain/qtms_domain.dart';

import 'callable.dart';
import 'identity_gateway.dart';

/// صيغة الملف المُصدَّر — `FR-M19-01` («PDF / Excel»).
///
/// ⛔ **ولا تُضاف قيمة هنا بلا مُصدِّرٍ لها فعلاً في التطبيق** — نفس قاعدة
/// [auditEntityTypes]: ★ **قائمةُ فلترةٍ تعرض صيغةً بلا سجل تُري المستخدم
/// فراغاً يظنّه عطلاً.**
enum ExportFormat {
  /// ملف PDF — ★ **الصيغة الوحيدة المُنفَّذة في `WU-010`.**
  pdf;

  /// القيمة كما تُكتب في القيد.
  String get wireName => name;
}

/// نوع العملية — ★ **وواحدة لا أكثر**، ⛔ **ولا تُوسَّع بلا سطرٍ في العقد.**
enum ExportLogOperation {
  /// `logExport` — يشترط `documentExport` (`IQ-032` · `FR-M19-04`).
  logExport(Permission.documentExport);

  const ExportLogOperation(this.requiredPermission);

  /// الصلاحية التي لا تُنفَّذ العملية بدونها.
  final Permission requiredPermission;
}

/// نتيجة التخطيط — إما قيدٌ يُكتب وإما رفضٌ مصنَّف.
sealed class ExportLogPlan {
  /// ينشئ النتيجة.
  const ExportLogPlan();
}

/// رُفض الطلب قبل أي كتابة.
final class ExportLogRejected extends ExportLogPlan {
  /// ينشئ رفضاً.
  const ExportLogRejected(this.error);

  /// رمز الرفض من كتالوج الأخطاء.
  final CallableError error;
}

/// قُبل الطلب — وهذا قيده.
final class ExportLogAccepted extends ExportLogPlan {
  /// ينشئ خطة مقبولة.
  const ExportLogAccepted(this.entry);

  /// ★ **قيد التدقيق وحده** — ⛔ **ولا مستندَ معه** (راجع ترويسة الملف).
  final AuditEntry entry;
}

/// طلب تسجيل تصدير مُتحقَّق من هوية مُنفِّذه.
final class ExportLogRequest {
  /// ينشئ الطلب.
  const ExportLogRequest({
    required this.actor,
    required this.requestId,
    required this.sourceId,
    required this.entityType,
    required this.entityId,
    required this.format,
    required this.occurredAt,
    this.documentNumber,
    this.stockDate,
    this.deviceInfo,
  });

  /// المُنفِّذ **بحالته الآن من خدمة المصادقة**.
  final AccountRecord actor;

  /// ★ معرّف الطلب — **وهو معرّف قيد التدقيق نفسه** (`api-overview.md` §4).
  final String requestId;

  /// ★★ المصدر الذي يخصّه المستند المُصدَّر — **ويُقاس عليه النطاق** (`GR-23`).
  ///
  /// ⚠️ **والتقرير الذي يشمل كل المصادر يُمرَّر بـ[auditAllSourcesId]** —
  /// ★ **و`canAccessSource('all')` لا تصدُق إلا لصاحب النطاق الكامل**،
  /// ⟵ **فالقيد يضيق على من يملك الكل** ⛔ **ولا يتّسع لمن لا يملكه.**
  final String sourceId;

  /// نوع الكيان المُصدَّر — **من [auditEntityTypes] حصراً**.
  final String entityType;

  /// معرّف الكيان المُصدَّر.
  final String entityId;

  /// صيغة الملف.
  final ExportFormat format;

  /// ★★ **وقت الحدث من المنصّة** — ⛔ **لا من ساعة الحاوية** (`GR-54`).
  ///
  /// ⚠️ **وقيمتُه هنا للتمثيل والاختبار** — ★ **والكاتب يستبدله بزمن المنصّة
  /// داخل المعاملة** كما في بقية العمليات (`AuditEntry.occurredAt`).
  final DateTime occurredAt;

  /// رقم المستند إن كان مرقَّماً — و`null` للتقارير والمفاتيح المركّبة.
  final String? documentNumber;

  /// ★ تاريخ المخزون إن كان الكيان يخصّ يوماً — ⛔ **ولا يُخلَط بتاريخ
  /// الإدخال** (`RISK-07`).
  final CalendarDay? stockDate;

  /// وصف الجهاز للسجل — ⛔ بلا بيانات حساسة.
  final String? deviceInfo;
}

/// ★★ فحوص الحالة والصلاحية والنطاق — **تُستدعى قبل فتح المعاملة**.
///
/// ★ **والفحص يُعاد كاملاً** في [planExportLog] ⛔ **فلا مسار يتخطّاه.**
ExportLogRejected? exportLogGate(
  ExportLogRequest request,
  ExportLogOperation operation,
) {
  // ① «التعطيل فوري ونافذ» — `authentication-policy.md` §2 القاعدة 3.
  if (request.actor.disabled) {
    return const ExportLogRejected(CallableError.accountDisabled);
  }
  // ② الصلاحية — ⛔ ولا قاعدة حماية تحرس هذا المسار (الكتالوج §2.8).
  if (!request.actor.claims.has(operation.requiredPermission)) {
    return const ExportLogRejected(CallableError.permissionMissing);
  }
  // ③ ★★ **النطاق — قيدٌ يعلو على الصلاحية** (`GR-23` · `FR-M19-02`).
  //    ⛔ **والغياب منعٌ لا سماح.**
  if (!request.actor.claims.canAccessSource(request.sourceId)) {
    return const ExportLogRejected(CallableError.sourceOutOfScope);
  }
  // ④ معرّف الطلب إلزامي — وبدونه لا تتحقق اللاتكرارية عند إعادة الإرسال.
  if (request.requestId.trim().isEmpty) {
    return const ExportLogRejected(CallableError.invalidArgument);
  }
  return null;
}

/// يخطّط تسجيل تصدير — **دالة خالصة، وهي حارس التفويض الفعلي**.
ExportLogPlan planExportLog(
  ExportLogRequest request,
  ExportLogOperation operation,
) {
  final ExportLogRejected? gate = exportLogGate(request, operation);
  if (gate != null) return gate;

  // ⑤ ★★ **نوع الكيان من القائمة المعتمدة حصراً** — ⛔ **ولا نصٌّ حرّ.**
  //    ⚠️ **ولماذا حارسٌ لا تساهل:** `entityType` هو ما يستعلم به السجل
  //    السياقي 🕘 (`FR-M18-10`) — ⟵ **وقيمةٌ لا يعرفها القارئ تُنتج سجلاً
  //    فارغاً أبداً يبدو «لا تاريخ لهذا المستند»** (`audit_entity_types.dart`).
  if (!auditEntityTypes.contains(request.entityType)) {
    return const ExportLogRejected(CallableError.invalidArgument);
  }
  if (request.entityId.trim().isEmpty) {
    return const ExportLogRejected(CallableError.invalidArgument);
  }

  return ExportLogAccepted(
    AuditEntry(
      id: request.requestId,
      occurredAt: request.occurredAt,
      actor: AuditActor(
        userId: request.actor.userId,
        // ★ **منسوخ لا مرجع** — الشرط 4 في `audit-log-design.md` §2.
        userName: request.actor.userName,
        // ★★★ **والبريد منسوخٌ وقت الحدث كذلك** — `AM-012` §3.
        userEmail: request.actor.userEmail,
      ),
      action: AuditAction.export,
      target: AuditTarget(
        entityType: request.entityType,
        entityId: request.entityId.trim(),
        sourceId: request.sourceId,
        documentNumber: request.documentNumber,
        stockDate: request.stockDate,
      ),
      // ⛔⛔★★ **`valuesBefore` فارغة قطعاً — والتصدير لا يُغيِّر حقلاً.**
      //    ★ **و`valuesAfter` علامةٌ صريحة لا حقلٌ متغيّر** — **بنفس سابقة
      //    `delete` التي تكتب `{'deleted': true}`** (`audit-log-design.md` §3)،
      //    ⟵ **فخريطةٌ فارغةٌ تماماً كانت تُقرأ «لم يتغيّر شيء» بلا أن تقول
      //    ماذا خرج من النظام.**
      valuesAfter: <String, Object?>{'exportFormat': request.format.wireName},
      // ⛔⛔★★★ **ولا سبب** — ★ **ولا يُعبَّأ نيابةً عن المستخدم أبداً**
      //    (`ADR-0020` القيد الوحيد الباقي): ما لم يكتبه إنسان لا يُخزَّن.
      deviceInfo: request.deviceInfo,
    ),
  );
}

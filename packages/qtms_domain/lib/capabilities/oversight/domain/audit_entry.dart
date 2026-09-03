/// قيد سجل التدقيق — **نقل حرفي لحقول `data-dictionary.md` §5 و
/// `audit-log-design.md` §3**.
///
/// ⚠️ **بعد `ADR-0004` هذا السجل هو الحافظ الوحيد للتاريخ** — «فإن ضعف شرط
/// واحد من شروطه **سقط المبرر كله**» (`RISK-05`). ولذلك يعيش بناؤه في طبقة
/// النطاق: ★ **لا يكتبه التطبيق إطلاقاً** (`allow create: if false`)، **وتبنيه
/// العمليةُ السحابية من هنا** — فلا صيغتان للقيد نفسه.
///
/// ★ **ولا يحمل هذا الملف أي استدعاء منصة** (`ADR-0012`) — يُنتج خريطة حقول
/// خالصة، والترميز والكتابة مسؤولية `functions/`.
library;

import '../../../core/calendar_day.dart';
import 'audit_action.dart';

/// اسم مجموعة سجل التدقيق — `naming-conventions.md` §4 (`snake_case` جمعاً).
const String auditLogCollection = 'audit_log';

/// ★ قيمة `sourceId` لقيد لا يخصّ مصدراً بعينه (تغيير صلاحية · دخول).
///
/// ⚠️ **افتراض هندسي موثَّق لا نقل حرفي:** `data-dictionary.md` §5 يجعل
/// `sourceId` حقلاً حاكماً في كل قيد، وقاعدة قراءة `audit_log` تشترط
/// `storedInScope()` — **فقيد بلا `sourceId` لا يقرؤه أحد إطلاقاً**.
/// ★ **والقيمة `'all'` سابقتها موثَّقة في المشروع نفسه**: البطاقة التجميعية
/// `all_{date}` تحمل `sourceId = 'all'` (`data-dictionary.md` §4).
///
/// ★ **وأثرها الأمني في الاتجاه الآمن:** `inScope('all')` لا تصدُق إلا لمن
/// نطاقه `all` — فقيود تغيير الصلاحيات **تضيق على أصحاب النطاق الكامل**
/// ولا تتّسع. ⛔ **ولو كان الاختيار خاطئاً لكان التصحيح توسيعاً لا كشفاً.**
const String auditAllSourcesId = 'all';

/// قيد تدقيق واحد — **غير قابل للتغيير بعد إنشائه** (`audit-log-design.md` §2).
final class AuditEntry {
  /// ينشئ قيداً، ويرفض ما لا يجوز أن يُكتب أصلاً.
  ///
  /// يرمي [ArgumentError] لأن قيداً ناقص المُسنَد إليه **خلل برمجي في
  /// المُستدعي** لا قاعدة عمل مخالَفة (`error-handling-strategy.md` §3).
  factory AuditEntry({
    required String id,
    required DateTime occurredAt,
    required AuditActor actor,
    required AuditAction action,
    required AuditTarget target,
    Map<String, Object?> valuesBefore = const <String, Object?>{},
    Map<String, Object?> valuesAfter = const <String, Object?>{},
    String? reason,
    String? deviceInfo,
  }) {
    if (id.isEmpty) {
      throw ArgumentError.value(id, 'id', 'معرّف القيد إلزامي');
    }
    if (!occurredAt.isUtc) {
      // ★ `coding-standards.md` §2.3: «لا يُستخدَم وقت الجهاز في أي حقل
      //   يُخزَّن» — واشتراط UTC يمنع أن ينزلق وقت الخادم بمنطقة الحاوية.
      throw ArgumentError.value(
        occurredAt,
        'occurredAt',
        'الوقت يجب أن يكون UTC',
      );
    }
    return AuditEntry._(
      id: id,
      occurredAt: occurredAt,
      actor: actor,
      action: action,
      target: target,
      valuesBefore: Map<String, Object?>.unmodifiable(valuesBefore),
      valuesAfter: Map<String, Object?>.unmodifiable(valuesAfter),
      reason: _blankToNull(reason),
      deviceInfo: deviceInfo,
    );
  }

  const AuditEntry._({
    required this.id,
    required this.occurredAt,
    required this.actor,
    required this.action,
    required this.target,
    required this.valuesBefore,
    required this.valuesAfter,
    required this.reason,
    required this.deviceInfo,
  });

  /// ★★ **الفراغات وحدها ليست سبباً — فتُقرأ غياباً لا نصّاً فارغاً**
  /// (`ADR-0020` القيد 3).
  ///
  /// ⛔⛔★★★ **ولماذا حارسٌ قائمٌ بذاته بعد سقوط الإلزام:** ★ **كان الحارس
  /// القديم يرفض الفراغات قبل أن تصل التخزين**، ⟵ **فحين حُذف صار
  /// `'   '.trim()` يُخزَّن `''`** — ⛔ **وحقلٌ يبدو مملوءاً وهو خالٍ أسوأ من
  /// غيابٍ صريح**: ★ **يقرؤه المدقّق «كُتب سببٌ» ثم لا يجد فيه شيئاً.**
  /// ⟵ ★★ **ورصده اختبارُ الارتداد فعلاً** لا المراجعة (2026-08-27).
  static String? _blankToNull(String? reason) {
    final String? trimmed = reason?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  // ⛔⛔★★★ **`requiresReason` حُذفت بـ`ADR-0020` (2026-08-27) — ومعها
  //   حارسُها في المُنشئ وعَلَمُ `isDeferredEntry`.**
  //
  //   ★ **ما كانت تقوله:** «السبب إلزاميٌّ في `amend` و`cancel` و`disposal`
  //   و`delete`» (`audit-log-design.md` §3 · `IQ-018` للحذف)، ★ **وإعفاءٌ
  //   واحدٌ مُسمّى بعَلَمٍ صريح لمسارَي التعبئة المؤجَّلة** (`ADR-0018`).
  //
  //   ⟵ ★★ **و`ADR-0020` عمّم الإعفاء على كل فعل**، ⛔ **فلم يبقَ شرطٌ
  //   يُفحَص ولا إعفاءٌ يُطلَب** — ★ **وحذفُ الحارس أصدق من إبقائه يُرجِع
  //   `false` دائماً**، ⟵ **فلا يظنّ قارئٌ أن ثمّة حمايةً قائمة.**
  //
  //   ⛔⛔★★★ **والقاعدة الوحيدة الباقية — وهي الآن الحارس الوحيد:**
  //   **لا يُعبِّئ التطبيق ولا السحابة سبباً نيابةً عن المستخدم**، ⟵ **فحقل
  //   [reason] إمّا نصُّ إنسانٍ وإمّا `null`** ⛔ **ولا حالةَ ثالثة.**

  final String id;

  /// **بتوقيت الخادم** — `data-dictionary.md` §5.
  ///
  /// ⚠️ **وفي مسار العملية السحابية لا يُكتب هذا الحقل من هنا:** الكاتب
  /// يستبدله بوقت المنصة (`REQUEST_TIME`) داخل المعاملة نفسها، التزاماً
  /// بـ`coding-standards.md` §2.3 («**لا يُستخدَم وقت الجهاز في أي حقل
  /// يُخزَّن**» · `GR-54`) — ★ **وساعةُ الحاوية جهازٌ كغيره** في هذا المشروع،
  /// وهو ما استقرّ عليه مسار `DEBT-09` صراحةً.
  /// ★ **فقيمته هنا للتمثيل والاختبار**، وهي المرجع عند قراءة قيد مكتوب.
  final DateTime occurredAt;

  /// المستخدم **مُثبَّتاً وقت الحدث** — الشرط 4 في `audit-log-design.md` §2.
  final AuditActor actor;

  /// الإجراء المُسجَّل.
  final AuditAction action;

  /// الكيان الذي وقع عليه الإجراء.
  final AuditTarget target;

  /// **الحقول المتغيرة فقط** — ⛔ ولا نسخ للمستند كاملاً (§8).
  final Map<String, Object?> valuesBefore;

  /// القيم بعد التغيير — **المتغيرة منها فقط كذلك**.
  final Map<String, Object?> valuesAfter;

  /// السبب النصي — ★★ **اختياريٌّ في كل الأفعال** (`ADR-0020`).
  ///
  /// ⛔⛔ **و`null` تعني «لم يكتب المستخدم سبباً»** — ★ **لا «نُسي»**،
  /// ⟵ **ولا يجوز سدُّ الفراغ بنصٍّ مُولَّد.**
  final String? reason;

  /// وصف الجهاز **لتتبّع مصدر العملية** — ⛔ ولا معرّف جهاز في بطاقة المستخدم.
  final String? deviceInfo;

  /// خريطة حقول القيد كما تُكتب في المجموعة.
  ///
  /// ★ **أسماء الحقول من `data-dictionary.md` §5 حرفياً** — فأي انزلاق فيها
  /// يكسر الفهارس الأربعة في `audit-log-design.md` §7 بصمت.
  Map<String, Object?> toFields() => <String, Object?>{
        'id': id,
        // ⚠️ **بدقة الثانية** — والكسور تُقتطَع هنا لا عند القراءة، وإلا
        //    اختلف ترتيب قيدين في الثانية نفسها بين قارئ وآخر.
        'occurredAt': truncateToSecond(occurredAt),
        'userId': actor.userId,
        'userName': actor.userName,
        // ★★★ **بريدُ المُنفِّذ — `AM-012` §3.1 و§3.2** (2026-09-02).
        //
        // ⛔⛔★★★ **ومنسوخٌ وقت الحدث كالاسم تماماً** (§2 الشرط 4) — ⟵ **لا
        //    مرجعٌ يُقرأ من `users/{userId}` عند العرض**: ★ **فبريدٌ تغيّر
        //    بعد الحدث كان سيُعيد كتابة تاريخِ من نفّذه**، ⛔ **وحسابٌ
        //    عُطِّل وحُذفت بطاقتُه كان يترك قيدَه بلا هوية.**
        //
        // ⚠️★★ **و`null` مسموحةٌ وتعني «لم يُعرَف» لا «لا بريد له»** —
        //    ★ **وقيودُ ما قبل هذا التاريخ تحمل الحقلَ غائباً**: ⟵ **فالعرضُ
        //    يُسقِط السطر** ⛔ **ولا يكتب «لا قيمة» في موضع هوية.**
        'userEmail': actor.userEmail,
        'action': action.name,
        'entityType': target.entityType,
        'entityId': target.entityId,
        'documentNumber': target.documentNumber,
        'sourceId': target.sourceId,
        'stockDate': target.stockDate?.format(),
        'valuesBefore': valuesBefore,
        'valuesAfter': valuesAfter,
        'reason': reason,
        'deviceInfo': deviceInfo,
      };

  /// يقتطع الكسور دون الثانية — **بدقة الثانية** كما يفرض قاموس البيانات.
  static DateTime truncateToSecond(DateTime value) => DateTime.utc(
        value.year,
        value.month,
        value.day,
        value.hour,
        value.minute,
        value.second,
      );
}

/// منفِّذ العملية — **اسمه منسوخ فلا يتغيّر لو تغيّر لاحقاً** (§2 الشرط 4).
final class AuditActor {
  /// ينشئ مُنفِّذاً، ويرفض الهوية الناقصة.
  factory AuditActor({
    required String userId,
    required String userName,
    String? userEmail,
  }) {
    if (userId.isEmpty) {
      throw ArgumentError.value(
        userId,
        'userId',
        'المُنفِّذ إلزامي — لا قيد مجهول',
      );
    }
    return AuditActor._(userId, userName, _blankToNull(userEmail));
  }

  const AuditActor._(this.userId, this.userName, this.userEmail);

  /// معرّف المُنفِّذ في خدمة المصادقة.
  final String userId;

  /// ★ **منسوخ لا مرجع** — فتغيير اسم المستخدم لاحقاً لا يُعيد كتابة تاريخه.
  final String userName;

  /// ★★★ **بريدُ المُنفِّذ منسوخاً وقت الحدث** — `AM-012` §3 · اختياري.
  ///
  /// ⛔⛔★★ **والفراغُ يُقرأ غياباً لا نصّاً فارغاً** — ★ **نفسُ قاعدة
  /// [AuditEntry] في حقل السبب** (`ADR-0020` القيد 3): ⟵ **وسطرُ بريدٍ
  /// فارغٍ تحت الاسم يُقرأ «بريدٌ محذوف»** ⛔ **بينما معناه «لم يُعرَف».**
  ///
  /// ⚠️ **و`null` هي حالُ كل قيدٍ كُتب قبل 2026-09-02** — ⛔ **ولا يُملأ
  /// بأثرٍ رجعي:** ★ **السجلُّ للإضافة فقط ولا يُهاجَر** (`schema/audit-log.md`).
  final String? userEmail;

  static String? _blankToNull(String? value) {
    final String? trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }
}

/// الكيان الذي وقع عليه الإجراء.
final class AuditTarget {
  /// ينشئ هدفاً، ويرفض الكيان المجهول.
  factory AuditTarget({
    required String entityType,
    required String entityId,
    String sourceId = auditAllSourcesId,
    String? documentNumber,
    CalendarDay? stockDate,
  }) {
    if (entityType.isEmpty || entityId.isEmpty) {
      throw ArgumentError.value(
        '$entityType/$entityId',
        'target',
        'نوع الكيان ومعرّفه إلزامان — والقيد بلا هدف لا يُتتبَّع',
      );
    }
    return AuditTarget._(
      entityType: entityType,
      entityId: entityId,
      sourceId: sourceId,
      documentNumber: documentNumber,
      stockDate: stockDate,
    );
  }

  const AuditTarget._({
    required this.entityType,
    required this.entityId,
    required this.sourceId,
    required this.documentNumber,
    required this.stockDate,
  });

  /// نوع الكيان — `user` · `source` · `distribution` … من معجم §2.
  final String entityType;

  /// معرّف الكيان.
  final String entityId;

  /// **للفلترة ولاحترام النطاق** — `audit-log-design.md` §3.
  final String sourceId;

  /// رقم المستند إن كان الكيان مستنداً مرقَّماً.
  final String? documentNumber;

  /// ★ **لتمييز التصريف المتأخر** — ⛔ ولا يُخلَط بتاريخ الإدخال (`RISK-07`).
  final CalendarDay? stockDate;
}

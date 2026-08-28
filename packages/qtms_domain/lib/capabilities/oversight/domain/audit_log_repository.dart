/// عقد قراءة سجل التدقيق — ★ **قراءةٌ فقط، ولا كاتبَ هنا إطلاقاً**.
///
/// ★ **المصدر:** `FR-M18-01` … `FR-M18-16` · `audit-log-design.md` §3 و§5
/// و§7 · `schema/audit-log.md` · `data-dictionary.md` §5.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔★★ **أربع قواعد بنيوية يفرضها هذا الملف بغياب ما لا يجوز وجودُه:**
///
///   ① ⛔⛔ **لا دالة كتابة ولا تعديل ولا حذف — ولا لِلمالك** (`FR-M18-01` ·
///      `GR-08`) — ⟵ **وقاعدة الحماية `allow create, update, delete: if
///      false` للجميع**، ★ **وغيابُ الدالة هنا هو نظيرُها في الكود:**
///      **ما لا عقدَ له لا يُستدعى بالسهو.**
///   ② ★★ **السجل السياقي عرضٌ محض ولا يُنشئ مجموعة** (`FR-M18-13`) —
///      ⟵ **فهو استعلامٌ على المجموعة نفسها بمفتاح الكيان**، ⛔ **لا نسخةٌ
///      ثانية ولا مجموعةٌ مشتقّة.**
///   ③ ★★ **ولا قراءةَ للسجل كاملاً في أي شاشة** (`audit-log-design.md` §8:
///      «**حجم السجل ينمو بلا حد … يُدار بالترقيم والفهرسة الضيقة**») —
///      ⟵ **فكل استعلامٍ هنا محدودٌ بـ[auditLogPageSize]** ⛔ **ولا دالة
///      بلا حدّ.**
///   ④ ⛔⛔★★★ **ولا استعلامَ بلا مصدرٍ مُقيَّد** — راجع [AuditLogFilter].
/// ═══════════════════════════════════════════════════════════════════════
library;

import '../../../core/calendar_day.dart';
import 'audit_action.dart';
import 'audit_entry.dart';

/// ★ حدّ الصفحة الواحدة — `audit-log-design.md` §8.
///
/// ⚠️⚠️ **وهو قيدٌ بنيوي لا تحسينُ أداء:** المستند ينصّ أن السجل **«ينمو بلا
/// حد»** وأنه **«لا يُقرَأ كاملاً في أي شاشة»** — ⟵ **واستعلامٌ بلا حدٍّ على
/// مجموعةٍ للإضافة فقط يصير أبطأ كل يوم بلا أن يفشل مرةً واحدة**، ★ **فلا
/// يظهر في اختبارٍ ولا في مراجعة.**
///
/// ⚠️ **والقيمة قرارٌ تنفيذي روتيني مُعلَن** — ⛔ **لا نقلٌ عن مستند**:
/// المستند يفرض **وجود** حدٍّ ولا يذكر رقمه. ★ **و50 صفّاً تملأ شاشةً ونصفاً
/// على أصغر جهازٍ مدعوم** (`ui-guidelines.md` §5) ⟵ **فالمستخدم يرى نتيجةً
/// كاملة بلا انتظار.**
const int auditLogPageSize = 50;

/// ★★ البُعد الثانوي في الشاشة المركزية — `FR-M18-09`.
///
/// ⚠️ **وهو ثانويٌّ لأن المصدر أوّليٌّ دائماً** — راجع [AuditLogFilter].
enum AuditFilterDimension {
  /// ★ بلا بُعدٍ ثانٍ — **كل نشاط هذا المصدر** (مع المدى الزمني إن وُجد).
  none,

  /// نشاط مستخدم — `R-30`.
  user,

  /// سجل التعديلات — `R-29`.
  action,
}

/// فلتر الشاشة المركزية — `FR-M18-09`.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **والمصدر إلزاميٌّ في كل استعلام — وهذا قياسٌ حيٌّ لا اجتهاد:**
///
/// قاعدة `audit_log` تشترط `storedInScope()` وهي `'sourceId' in resource.data
/// && inScope(resource.data.sourceId)`. ★★ **وقُيس على المحاكي (2026-08-27):**
///
/// | الاستعلام | النتيجة |
/// |---|---|
/// | `getDoc` لمستندٍ واحد (نطاقٌ شامل) | ✅ **يمرّ** |
/// | `getDocs` **بلا قيدٍ على `sourceId`** — **ولو بنطاقٍ شامل** | ⛔ **يُرفَض** |
/// | `getDocs` مع `sourceId ==` داخل النطاق | ✅ **يمرّ** |
/// | `getDocs` مع `sourceId ==` + `userId` / `action` / `entityType`+`entityId` | ✅ **يمرّ** |
///
/// ⟵ ★★★ **فشرطُ `resource.data` لا يُقيَّم لكل مستند في السرد** — **يُقيَّم
/// على قيود الاستعلام نفسه**، ⛔ **واستعلامٌ لا يُقيّد الحقل لا يُثبِت الشرط
/// فيُرفَض كاملاً.** ★ **وهو حرفياً درس `IQ-024`** الذي ترك منتقيَ المصدر
/// فارغاً في كل شاشة حتى 2026-08-26.
///
/// ★★ **ولذلك المصدر حقلٌ مطلوب في النوع نفسه** — ⛔ **لا خيارٌ يُنسى**:
/// ⟵ **فاستعلامٌ يُرفَض حيّاً يستحيل بناؤه أصلاً.**
///
/// ★ **وهذا يوافق مبدأ النظام لا يخالفه:** `A-01` — **لا جمع بين مصدرين في
/// أي عملية**، و`GR-23` — **النطاق قيدٌ يعلو على كل صلاحية**.
/// ═══════════════════════════════════════════════════════════════════════
final class AuditLogFilter {
  /// ينشئ الفلتر، ويرفض بُعداً بلا قيمته.
  ///
  /// يرمي [ArgumentError] لأن بُعداً بلا قيمة **خلل برمجي في المُستدعي** لا
  /// قاعدة عمل مخالَفة (`error-handling-strategy.md` §3 القاعدة 3).
  factory AuditLogFilter({
    required String sourceId,
    AuditFilterDimension dimension = AuditFilterDimension.none,
    String? userId,
    AuditAction? action,
    CalendarDay? from,
    CalendarDay? to,
  }) {
    // ④ ⛔⛔ **ولا استعلامَ بلا مصدر** — راجع ترويسة الصنف.
    if (sourceId.trim().isEmpty) {
      throw ArgumentError.value(
        sourceId,
        'sourceId',
        'المصدر إلزامي في كل استعلام على السجل — وإلا رُفض الاستعلام كاملاً',
      );
    }
    switch (dimension) {
      case AuditFilterDimension.none:
        break;
      case AuditFilterDimension.user:
        if (userId == null || userId.trim().isEmpty) {
          throw ArgumentError.value(userId, 'userId', 'بُعد المستخدم بلا قيمة');
        }
      case AuditFilterDimension.action:
        if (action == null) {
          throw ArgumentError.value(action, 'action', 'بُعد الإجراء بلا قيمة');
        }
    }
    // ★ **ومدىً مقلوب خللٌ برمجي كذلك** — ⟵ **واستعلامُه يُرجِع فراغاً
    //   صامتاً** فيبدو «لا أحداث» بينما السؤال نفسه مستحيل.
    if (from != null && to != null && from.compareTo(to) > 0) {
      throw ArgumentError.value(from, 'from', 'بداية المدى بعد نهايته');
    }
    return AuditLogFilter._(
      sourceId: sourceId.trim(),
      dimension: dimension,
      userId: userId?.trim(),
      action: action,
      from: from,
      to: to,
    );
  }

  const AuditLogFilter._({
    required this.sourceId,
    required this.dimension,
    required this.userId,
    required this.action,
    required this.from,
    required this.to,
  });

  /// ★★ **المصدر — إلزاميٌّ دائماً** (راجع ترويسة الصنف).
  ///
  /// ★ **وقيمة [auditAllSourcesId] تعني قيود «ما لا يخصّ مصدراً»** — تغييرُ
  /// صلاحية · دخول · مستخدم · دور — ⟵ **ولا يقرؤها إلا صاحب النطاق الشامل**،
  /// ★ **وهو أثرٌ موثَّق سلفاً** في `audit_entry.dart` (`auditAllSourcesId`).
  final String sourceId;

  /// البُعد الثانوي المفعَّل — ⛔ **واحدٌ لا أكثر**.
  final AuditFilterDimension dimension;

  /// المستخدم حين يكون [dimension] هو [AuditFilterDimension.user].
  final String? userId;

  /// الإجراء حين يكون [dimension] هو [AuditFilterDimension.action].
  final AuditAction? action;

  /// ★ أول يوم في المدى — **شاملٌ له** · `null` = بلا حدٍّ سفلي.
  final CalendarDay? from;

  /// ★ آخر يوم في المدى — **شاملٌ له** · `null` = بلا حدٍّ علوي.
  final CalendarDay? to;

  /// هل هو «كل نشاط هذا المصدر»؟ — ★ **فتُظهر الشاشة أحدثَه** لا «نتائج بحث».
  bool get isSourceOnly =>
      dimension == AuditFilterDimension.none && from == null && to == null;

  @override
  bool operator ==(Object other) =>
      other is AuditLogFilter &&
      other.sourceId == sourceId &&
      other.dimension == dimension &&
      other.userId == userId &&
      other.action == action &&
      other.from == from &&
      other.to == to;

  @override
  int get hashCode => Object.hash(sourceId, dimension, userId, action, from, to);
}

/// ★ مفتاح السجل السياقي — **نوع الكيان ومعرّفه ومصدره معاً** (`FR-M18-10`).
///
/// ⚠️ **ولا يُفرَّق النوع عن المعرّف:** ★ **معرّفٌ بلا نوعه قد يتصادم بين
/// مجموعتين** (رقمُ مستندٍ ومعرّفُ مستخدم).
///
/// ⛔⛔★★ **والمصدر جزءٌ منه إلزاماً** — بنفس علّة [AuditLogFilter.sourceId]
/// حرفياً: ⟵ **استعلامٌ لا يُقيّده يُرفَض كاملاً من القاعدة** ⛔ **فيبدو
/// «لا تاريخ لهذا المستند»** وهو أسوأ عطلٍ في الحافظ الوحيد للتاريخ.
///
/// ★★ **وقيمتُه هي ما كتبه القيد لا ما تظنّه الشاشة:** كُتّابُ اليوم يكتبون
/// **مصدر المستند** للوارد والجونية والسعر، **ومعرّفَ المصدر نفسه** لسجل
/// المصدر، **و[auditAllSourcesId]** للرعوي والمقوت والنوع والمستخدم والدور
/// (`master_data.dart` · `user_admin.dart`) — ⛔ **ولا يُخمَّن.**
final class AuditEntityRef {
  /// ينشئ المفتاح، ويرفض الكيان المجهول.
  factory AuditEntityRef({
    required String entityType,
    required String entityId,
    String sourceId = auditAllSourcesId,
  }) {
    if (entityType.trim().isEmpty || entityId.trim().isEmpty) {
      throw ArgumentError.value(
        '$entityType/$entityId',
        'entity',
        'نوع الكيان ومعرّفه إلزامان — والسجل السياقي بلا هدف لا يُفتَح',
      );
    }
    if (sourceId.trim().isEmpty) {
      throw ArgumentError.value(
        sourceId,
        'sourceId',
        'المصدر إلزامي — واستعلامٌ بلا قيدٍ عليه يُرفَض كاملاً',
      );
    }
    return AuditEntityRef._(
      entityType.trim(),
      entityId.trim(),
      sourceId.trim(),
    );
  }

  const AuditEntityRef._(this.entityType, this.entityId, this.sourceId);

  /// نوع الكيان — من معجم `naming-conventions.md` §2.
  final String entityType;

  /// معرّف الكيان.
  final String entityId;

  /// ★★ مصدر قيوده — **كما كتبه القيد** ⛔ لا كما تفترضه الشاشة.
  final String sourceId;

  @override
  bool operator ==(Object other) =>
      other is AuditEntityRef &&
      other.entityType == entityType &&
      other.entityId == entityId &&
      other.sourceId == sourceId;

  @override
  int get hashCode => Object.hash(entityType, entityId, sourceId);
}

/// بطاقة قيدٍ كما تُقرأ — **بحقول `data-dictionary.md` §5 حرفياً**.
///
/// ⚠️ **وهي غير [AuditEntry] عمداً:** ذاك **يُبنى ليُكتَب** ويرفض ما لا يجوز
/// كتابته (سبب ناقص · وقتٌ غير UTC)، ★ **وهذا يُقرأ من قيدٍ كُتب فعلاً**.
/// ⟵ ⛔ **ودمجُهما كان سيجعل قيداً قديماً ناقصَ حقلٍ يرمي عند العرض**،
/// ★ **فيُسقِط شاشةَ التدقيق بالضبط حين يُحتاج إليها.**
final class AuditLogEntryCard {
  /// ينشئ البطاقة.
  AuditLogEntryCard({
    required this.id,
    required this.occurredAt,
    required this.userId,
    required this.userName,
    required this.action,
    required this.entityType,
    required this.entityId,
    required this.sourceId,
    Map<String, Object?> valuesBefore = const <String, Object?>{},
    Map<String, Object?> valuesAfter = const <String, Object?>{},
    this.documentNumber,
    this.stockDate,
    this.reason,
    this.deviceInfo,
  })  : valuesBefore = Map<String, Object?>.unmodifiable(valuesBefore),
        valuesAfter = Map<String, Object?>.unmodifiable(valuesAfter);

  /// معرّف القيد — ★ **وهو معرّف الطلب نفسه** (`api-overview.md` §4).
  final String id;

  /// وقت الحدث **بتوقيت الخادم بدقة الثانية** (`FR-M18-05`).
  final DateTime occurredAt;

  /// معرّف المُنفِّذ.
  final String userId;

  /// ★ اسمه **مُثبَّتاً وقت الحدث** — ⛔ **لا مرجعاً يُقرأ الآن** (§2 الشرط 4).
  final String userName;

  /// الإجراء — ★ **و`null` تعني فعلاً غير معروف لهذا الإصدار**.
  ///
  /// ⚠️ **ولماذا يُقبَل المجهول:** السجل **للإضافة فقط ولا يُهاجَر**، ⟵
  /// **فقيدٌ كتبه إصدارٌ أحدث بفعلٍ جديد يبقى مقروءاً** ⛔ **بدل أن يُسقِط
  /// الشاشة أو يختفي بصمت** — ★ **واختفاءُ قيدٍ من شاشة تدقيق أسوأ من
  /// عرضه بفعلٍ غير مترجَم.**
  final AuditAction? action;

  /// نوع الكيان.
  final String entityType;

  /// معرّف الكيان.
  final String entityId;

  /// ★ **المصدر — للفلترة ولاحترام النطاق** (`FR-M18-14`).
  final String sourceId;

  /// رقم المستند إن كان الكيان مستنداً مرقَّماً.
  final String? documentNumber;

  /// ★ **تاريخ المخزون** — ⛔ **لا يُخلَط بوقت الحدث** (`RISK-07`).
  ///
  /// ★★ **وهو ما يُميِّز التصريف المتأخر** (`FR-M18-08` · `AT-52`): ⟵ **قيدٌ
  /// وقتُه اليوم وتاريخُ مخزونه أمس.**
  final CalendarDay? stockDate;

  /// **الحقول المتغيرة فقط** قبل التغيير.
  final Map<String, Object?> valuesBefore;

  /// القيم بعد التغيير — **المتغيرة منها فقط كذلك**.
  final Map<String, Object?> valuesAfter;

  /// السبب النصي — ★★ **اختياريٌّ دائماً** (`ADR-0020`) · `null` = لم يُكتَب.
  final String? reason;

  /// وصف الجهاز.
  final String? deviceInfo;
}

/// ★ تغيّرُ حقلٍ واحد — **صفٌّ في الصيغة الموحّدة** (`FR-M18-10`).
final class AuditFieldChange {
  /// ينشئ الصف.
  const AuditFieldChange({
    required this.field,
    required this.before,
    required this.after,
  });

  /// اسم الحقل كما كُتب في القيد.
  final String field;

  /// القيمة قبل — `null` تعني **غياباً** (حقلٌ أُضيف).
  final Object? before;

  /// القيمة بعد — `null` تعني **غياباً** (حقلٌ أُزيل).
  final Object? after;

  @override
  bool operator ==(Object other) =>
      other is AuditFieldChange &&
      other.field == field &&
      other.before == before &&
      other.after == after;

  @override
  int get hashCode => Object.hash(field, before, after);
}

/// ★★★ **الصيغة الموحّدة لعرض «قبل/بعد»** — `audit-log-design.md` §5:
/// «**موحّدة في كل الوحدات** — أيقونة الإجراء · المستخدم · الوقت · الحقل ·
/// قبل/بعد · السبب».
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⚠️⚠️ **ولماذا دالةٌ في طبقة النطاق لا حلقةٌ في الشاشة:** «**موحّدة في كل
/// الوحدات**» **شرطٌ لا وصف** — ★ **والسجل السياقي يظهر في أربع عشرة شاشة**
/// (`FR-M18-11`)، ⟵ **وأربع عشرة حلقةً تفترق عند أول تعديل**
/// (`coding-standards.md` §2.2). ★ **والشاشة المركزية تعرض الصيغة نفسها**
/// (§5: «بصيغة موحّدة») ⟵ **فهي خمس عشرة.**
///
/// ★★ **والاتحاد لا التقاطع:** `data-dictionary.md` §5 يجعل الخريطتين
/// **«الحقول المتغيرة فقط»** — ⛔ **وليستا متطابقتي المفاتيح بالضرورة:**
/// **إنشاءٌ** يكتب `valuesAfter` وحدها، **وحذفُ قالب الدور** يكتب
/// `valuesBefore` كاملةً و`valuesAfter` علامةَ غياب (`IQ-018`). ⟵ **فقراءةُ
/// مفاتيح إحداهما وحدها كانت ستُخفي نصف التغيير في نصف الأفعال.**
///
/// ★ **والترتيب أبجديٌّ ثابت** — ⟵ **فقيدٌ واحد يُعرَض بالترتيب نفسه في كل
/// فتحة**، ⛔ **ولا يقفز صفٌّ بين مرّةٍ وأخرى** فيظنّه المدقّق تغيّراً.
///
/// ⛔★★ **والمتساويان يُستبعَدان:** قيمةٌ لم تتغيّر **ليست تغييراً**، ⟵
/// **وعرضُها يُغرِق الصفَّ الحقيقي في ضجيج.** ★ **والعدد الصحيح يساوي
/// نظيره العشري** لأن القاعدة تُرجِع `1` و`1.0` لنفس القيمة.
/// ═══════════════════════════════════════════════════════════════════════
List<AuditFieldChange> describeAuditChanges(AuditLogEntryCard entry) {
  final Set<String> fields = <String>{
    ...entry.valuesBefore.keys,
    ...entry.valuesAfter.keys,
  };
  final List<AuditFieldChange> rows = <AuditFieldChange>[
    for (final String field in fields.toList()..sort())
      AuditFieldChange(
        field: field,
        before: entry.valuesBefore[field],
        after: entry.valuesAfter[field],
      ),
  ];
  return List<AuditFieldChange>.unmodifiable(
    rows.where((AuditFieldChange row) => !sameAuditValue(row.before, row.after)),
  );
}

/// ★ مقارنة قيمتين في السجل — **والقوائم والخرائط عنصراً بعنصر**.
///
/// ⚠️ **ومُصدَّرة عمداً:** ★ **القارئ والعارض يحتاجانها معاً**، ⛔ **ونسخةٌ
/// خاصة في أحدهما تجعل صفّاً يُعَدّ تغييراً هنا ولا يُعَدّ هناك.**
bool sameAuditValue(Object? a, Object? b) {
  if (a is List<Object?> && b is List<Object?>) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (!sameAuditValue(a[i], b[i])) return false;
    }
    return true;
  }
  if (a is Map<Object?, Object?> && b is Map<Object?, Object?>) {
    if (a.length != b.length) return false;
    for (final Object? key in a.keys) {
      if (!b.containsKey(key) || !sameAuditValue(a[key], b[key])) return false;
    }
    return true;
  }
  // ★ **والعدد الصحيح يساوي نظيره العشري** — القاعدة تُرجِع `1` و`1.0` معاً.
  if (a is num && b is num) return a == b;
  return a == b;
}

/// دليل سجل التدقيق — ★★ **قراءةً فقط** (`FR-M18-13`).
///
/// ⛔⛔★★ **ولا نظيرَ كاتبٍ له في هذا الملف ولا في غيره** — `FR-M18-04`:
/// «**كتابة السجل تتم عبر السحابة حصراً … والكتابة عليه من التطبيق ممنوعة
/// نهائياً**». ★ **والقيد يُكتب داخل معاملة المستند نفسه** (`ADR-0013`
/// القاعدة 1 · `audited_transaction.dart`) ⟵ **فلا مسارَ ثانٍ يُنشئ قيداً.**
abstract interface class AuditLogDirectory {
  /// ★ **الشاشة المركزية** — `FR-M18-09`: ⛔ **وتشترط «عرض سجل التدقيق
  /// المركزي»** في قاعدة الحماية (`FR-M18-12`).
  ///
  /// ⚠️ **والرفض يصل خطأً في التدفّق لا قائمةً فارغة** — ⟵ ★ **فتُميِّز
  /// الشاشة بين «لا نشاط» و«ممنوعٌ من الرؤية».**
  Stream<List<AuditLogEntryCard>> watchCentralLog({
    required AuditLogFilter filter,
    int limit = auditLogPageSize,
  });

  /// ★★ **السجل السياقي** — `FR-M18-10`: **أحداث هذا السجل وحده مرتبةً
  /// زمنياً تنازلياً**.
  ///
  /// ⚠️⚠️ **وصلاحيتُه صلاحيةُ عرض الوحدة نفسها** (`FR-M18-12`: «من يرى
  /// المستند يرى تاريخه») — ★ **والقاعدة تقبل `auditLogViewContextual`
  /// أو المركزي**، ⟵ **والبوابة في الشاشة تُخفي الأيقونة لمن لا يملك
  /// أياً منهما** ⛔ **وهي إخفاءٌ لا حماية** (`RISK-02`).
  Stream<List<AuditLogEntryCard>> watchEntityLog({
    required AuditEntityRef entity,
    int limit = auditLogPageSize,
  });
}

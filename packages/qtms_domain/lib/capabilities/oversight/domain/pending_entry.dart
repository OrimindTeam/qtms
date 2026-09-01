/// ★★★ **مركز الإدخالات المعلّقة** — `WU-009` (`FR-SYS-01` … `FR-SYS-10`).
///
/// ⛔⛔★★★ **والمبدأ الحاكم الذي يحكم كل سطرٍ هنا** (`GR-50` ·
/// `pending-entries-design.md` §1 و§10): **المركز يلاحق ويذكّر ⛔ ولا يمنع.**
/// ⟵ **فلا دالة في هذا الملف تُرجِع رفضاً، ولا عقدَ كتابةٍ يشترط خلوّ
/// المركز**، ★ **وأي تنفيذٍ يمنع حفظاً أو تصديراً بسبب بندٍ معلّق يخالف
/// المتطلب نصّاً** (`FR-SYS-06` — **حرجة**).
///
/// ═══════════════════════════════════════════════════════════════════════
/// ★★★ **والبنود مشتقّةٌ لا مصدرَ حقيقة** (§10 · `PAT-07` · `ADR-0008`):
/// ⟵ **تُبنى بالكامل من المستندات نفسها**، ⛔ **ولا يُبنى عليها حساب ولا
/// رصيد ولا رقمٌ مالي.** ★ **ولذلك كل دالةِ وصفٍ هنا خالصةٌ تماماً:**
/// **تأخذ حالةَ المستند كما هي وتُرجِع البنودَ المتوقَّعة** — ⟵ **فيستحيل
/// أن يفترق ما تكتبه السحابة عمّا يعرضه التطبيق** (`ADR-0012`).
///
/// ⛔⛔★★★ **والبنود تُنشئها وتحذفها السحابة حصراً** (`FR-SYS-09` ·
/// `database-overview.md` §2) — ★ **ولذلك لا عقدَ كتابةٍ هنا للتطبيق:**
/// [PendingEntryDirectory] **قراءةٌ محضة**، ⟵ **وغيابُ الكاتب هو نظيرُ
/// `allow write: if false` في `firestore.rules` حرفياً**، بنفس منطق
/// `AuditLogDirectory`.
/// ═══════════════════════════════════════════════════════════════════════
library;

import '../../../core/calendar_day.dart';

/// ⛅ بنود المركز المعلّق — **مشتقّةٌ بالكامل** (`backup-and-recovery-policy.md`).
const String pendingEntriesCollection = 'pending_entries';

// ═════════════════════════════════════════════════════════════════════════
// وجهة زر [ إدخال ] — `FR-SYS-04`
// ═════════════════════════════════════════════════════════════════════════

/// ★★ الشاشة التي يفتحها زر [ إدخال ] — **الشاشة الأصلية للحقل**.
///
/// ⛔⛔★★★ **ولا شاشة إدخالٍ بديلة داخل المركز** (`FR-SYS-04` ·
/// `pending-entries-design.md` §6): ★ **«حفاظاً على وحدة مكان الإدخال»**،
/// ⟵ **وبناءُ نموذجٍ موحَّدٍ في المركز يُنتج مسارَ كتابةٍ ثانياً بقواعد
/// تحقّقٍ منفصلة تفترق عن الأصلية عند أول تعديل** — ★ **وهو ما يسمّيه
/// المستند «مخالفةً تصميمية» نصّاً.**
///
/// ⚠️ **واسمُ الشاشة هنا لا مسارُها** — ★ **طبقة النطاق لا تعرف الملاحة**
/// (`ADR-0009`)، ⟵ **والتطبيق وحده يترجم هذه القيمة إلى مسارٍ في
/// `router.dart`.**
enum PendingScreen {
  /// شاشة الوارد جواني (`M7`).
  sackIntake,

  /// شاشة التسعير اليومي (`M9`).
  dailyPricing,

  /// شاشة التوزيع (`M10`).
  distribution,

  /// ★★ شاشة السحبيات والخرجيات (`M22`) — `WU-014`.
  ///
  /// ⛔⛔★★ **وشاشةٌ واحدة للسجلَّين** — `FR-M22` §1 نصّاً («**سجلّان
  /// منفصلان في شاشة واحدة**»): ⟵ **فالوجهة واحدة**، ★ **والسجلُّ المقصود
  /// يُقرأ من رقم المستند نفسِه** (`WDR-` · `EXP-`) ⛔ **لا من قيمةٍ ثانية
  /// في هذا المعجم.**
  outflow,
}

// ═════════════════════════════════════════════════════════════════════════
// نوع المستند المُلاحَق — `FR-SYS-08`
// ═════════════════════════════════════════════════════════════════════════

/// نوع المستند الذي يحمل القيمة الناقصة — `FR-SYS-08`.
///
/// ⛔⛔★★ **ولا قيمةَ هنا بلا كاتبٍ لها اليوم** — ★ **بنفس قاعدة
/// `SourceDocumentType` في `inventory.dart` حرفياً**: ⟵ **قيمةٌ لا كاتب لها
/// تُنتج فلتراً يعرض فراغاً دائماً فيقرؤه المستخدم عطلاً.**
///
/// ✅★★ **و`M22` أُضيف في `WU-014` (2026-09-01) — ★ بالضبط كما نصّت الحاشية
/// السابقة:** **قيمةٌ واحدة هنا وسطرٌ واحد في [PendingMissingField]**
/// (`pending-entries-design.md` §11 البند 1). ⟵ **وله كاتبٌ فعليٌّ في نفس
/// الزيادة** (`outflow.dart` عبر `describeOutflowPending`)، ⛔ **فلم يُضَف
/// استباقاً.** ★ **وكان غائباً عمداً حتى ذلك التاريخ** — **والتاريخ يُقرأ
/// ولا يُبنى عليه.**
enum PendingDocumentKind {
  /// جونية (`M7`) — `FR-M7-10` · `E-06` · `E-10`.
  sack('جونية', PendingScreen.sackIntake),

  /// ★★ تسعير نوعٍ في يومٍ ومصدر (`M9`) — `FR-M9-10` · `AT-16`.
  dailyPrice('تسعير اليوم', PendingScreen.dailyPricing),

  /// توزيعة (`M10`) — `FR-M10-08` · `AT-23` · `AT-24`.
  distribution('توزيعة', PendingScreen.distribution),

  /// ★★ سحبية أو خرجية (`M22`) — `FR-M22-07` · `E-27` · `AT-41`.
  ///
  /// ⛔⛔★★ **واسمُ الفلتر يجمع السجلَّين عمداً** — ★ **فالبندُ يُعرَض بعنوانٍ
  /// يحمل رقمَ مستنده** (`WDR-…` أو `EXP-…`) ⟵ **فيُميِّزه القارئ بلا مصطلحٍ
  /// تقني**، ⛔ **وقيمتان في الفلتر كانتا ستُضاعفان قائمةً قصيرةً بلا فائدة.**
  ///
  /// ⚠️⚠️★★ **ولا يُسقِط هذا الجمعُ حارسَ `GR-43` إطلاقاً** — ★ **شرطُ قراءة
  /// `pending_entries` نطاقُ المصدر** (`firestore.rules`)، ⟵ **والبندُ نفسُه
  /// لا يحمل مبلغاً ولا كميةً** ⛔ **بل عنواناً ورقمَ مستندٍ وحقلاً ناقصاً**:
  /// ★ **والمستندُ نفسُه يبقى محروساً بمفتاح سجلِّه.**
  outflow('سحبية أو خرجية', PendingScreen.outflow);

  const PendingDocumentKind(this.label, this.screen);

  /// ★ الاسم المعروض في الفلتر — ⛔ **بلا مصطلح تقني**
  /// (`ui-guidelines.md` §6).
  final String label;

  /// ★ الشاشة الأصلية للحقل — راجع [PendingScreen].
  final PendingScreen screen;

  /// ★ يقرأ النوع من قيمةٍ مخزَّنة — و`null` تعني **نوعاً لا يعرفه هذا
  /// الإصدار**.
  ///
  /// ⚠️ **ولا يُقرأ بافتراضٍ آمن:** ★ **بندٌ من نوعٍ مجهول يُعرَض بلا وجهة**
  /// ⛔ **خيرٌ من أن يُفتَح على شاشةٍ خاطئة** — ⟵ **وزرُّ [إدخال] يُخفى له.**
  static PendingDocumentKind? tryParse(Object? raw) {
    for (final PendingDocumentKind kind in PendingDocumentKind.values) {
      if (kind.name == raw) return kind;
    }
    return null;
  }
}

// ═════════════════════════════════════════════════════════════════════════
// الحقل الناقص — ★ **ستةٌ لا عشرة، ولماذا**
// ═════════════════════════════════════════════════════════════════════════

/// ★★★ **الحقل المُلاحَق** — **مفتاحٌ ثابتٌ يدخل معرّف البند**.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⚠️⚠️★★★ **ولماذا ستةٌ بينما `FR-SYS-08` يعدّ عشرة أسماء — مقروءٌ من
/// مستندات الوحدات لا مُختصَرٌ باجتهاد:**
///
///   ① **«وزن الحبة» لا يكون ناقصاً بعد الحفظ إطلاقاً** — ★ **`validateSackLine`
///      يُنتج `pieceWeightGrams` في حالاته الثلاث كلها** (`FR-M7-13` ·
///      `FR-M7-14`)، ⟵ **فسطرٌ محفوظٌ بلا وزن حبةٍ حالةٌ يستحيل بناؤها**،
///      ⛔ **وبندٌ لا يظهر أبداً ضجيجٌ في الكتالوج لا حارس.**
///   ② ★★ **«سعر التوزيع» و«الحد الأدنى» في الجونية هما حقلا `M9` نفسهما**
///      — `FR-M7-21` («سعر التوزيع والحد الأدنى **من `M9`**») ·
///      `pending-entries-design.md` §9: «**نوع سُعِّر من شاشة الجونية ⟵
///      يختفي بنده فوراً — المصدران يكتبان نفس الحقل**». ⟵ **فبندان
///      منفصلان لحقلٍ واحد كان سيبقى أحدهما بعد إدخال الآخر** ⛔ **وهو
///      عطلٌ يُطالِب المستخدم بما أدخله.**
///   ③ ★★ **و`M9` بندٌ واحد لا اثنان:** `FR-M9-10` نصّاً — «**بلا سعر توزيع
///      **أو** بلا حد أدنى … حتى يُسعَّر**»، ⟵ **حالةٌ واحدة اسمُها «لم
///      يُسعَّر»**، ★ **و`isPricingComplete` حَكَمُها الوحيد.** ⛔ **وما
///      ينقص منهما نصٌّ في [PendingEntryDraft.missingField]** لا بندٌ ثانٍ.
///   ④ ★★ **و`M10` بندٌ واحد للتوزيعة** — `pending-entries-design.md` §9
///      (`AT-23`): «**توزيعة بسطر غير مسعَّر ⟵ بند واحد**»، ⛔ **لا بندٌ
///      لكل سطر.**
/// ═══════════════════════════════════════════════════════════════════════
enum PendingMissingField {
  /// ★ ضريبة الكيلو لم تُدخل — `FR-M7-10` · `E-06`.
  ///
  /// 🔒 **وحقلُها في `sacks/{id}/finance/current`** (`ADR-0011`) —
  /// ⟵ **والبند يشير إلى شاشة الجونية لا إلى المستند الفرعي.**
  sackTax('ضريبة الكيلو', 'taxPerKilo'),

  /// ★ أنواع الجونية لم تُدخل — `FR-M7-12` · `E-06`.
  sackLines('الأنواع لم تُدخل', 'lines'),

  /// ★★ وزنٌ غير مفسَّر لم يُؤكَّد ضائعاً — `FR-M7-19` · `BR-M7-12` · `E-10`.
  ///
  /// ⛔⛔ **ولا يُستنتَج التأكيد من المتبقي** — ★ **الزرُّ الصريح وحده**
  /// (`SackWeightState.lostConfirmed`).
  sackLostWeight('الوزن الضائع لم يُؤكَّد', 'lostWeight'),

  /// ★★ نوعٌ له كمية اليوم ولم يكتمل تسعيره — `FR-M9-10` · `AT-16`.
  itemPricing('تسعير النوع', 'distributionPrice'),

  /// ★★ سطرُ توزيعٍ بلا سعر وحدة — `FR-M10-08` · `AT-23` · `AT-24`.
  distributionLinePricing('سعر وحدة السطر', 'unitPrice'),

  /// ★★ بندُ قاتٍ في سحبيةٍ أو خرجية بلا سعر — `FR-M22-07` · `E-27` · `AT-41`.
  ///
  /// ⛔⛔★★ **وبندٌ واحدٌ للسند مهما بلغ عدد بنوده غير المسعَّرة** — ★ **بنفس
  /// قرار [distributionLinePricing] حرفياً** (`AT-23`): ⟵ **والعددُ يظهر في
  /// نصّ البند** ⛔ **لا في عدد البنود.**
  ///
  /// ⚠️⚠️ **ومفتاحُ الحقل `unitPrice` نفسُه** — ★ **وهو الحقل الفعلي في شاشة
  /// السحبيات كما هو في شاشة التوزيع**: ⟵ **والمعرّف لا يلتبس لأن
  /// [PendingDocumentKind] جزءٌ منه** (`pendingEntryId`).
  outflowLinePricing('سعر وحدة بند القات', 'unitPrice');

  const PendingMissingField(this.defaultLabel, this.fieldKey);

  /// ★ الاسم العربي الافتراضي للقيمة الناقصة — `pending-entries-design.md` §3.
  final String defaultLabel;

  /// ★★ **الحقل بالضبط داخل الشاشة** — `FR-SYS-04`: **وجهة زر [إدخال]**.
  final String fieldKey;

  /// ★ يقرأ الحقل من قيمةٍ مخزَّنة — و`null` **حقلٌ لا يعرفه هذا الإصدار**.
  static PendingMissingField? tryParse(Object? raw) {
    for (final PendingMissingField field in PendingMissingField.values) {
      if (field.name == raw) return field;
    }
    return null;
  }
}

// ═════════════════════════════════════════════════════════════════════════
// معرّف البند — ★ **حتميٌّ فيُكتَب ويُحذَف بلا استعلام**
// ═════════════════════════════════════════════════════════════════════════

/// ★★★ معرّف بندٍ معلّق — **`{النوع}_{معرّف المستند}_{الحقل}`**.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⚠️⚠️★★★ **ولماذا حتميٌّ لا مُولَّد — قرارٌ بنيويٌّ لا تسمية:** §7 من
/// مستند الوحدة يجعل البند **«يختفي فور الإدخال الفعلي»**، ⟵ **فالكاتب
/// يحتاج أن يحذفه دون أن يعرف أنه موجود.** ★ **ومعرّفٌ حتمي يجعل الحذف
/// عمليةً بلا قراءةٍ سابقة** (والحذف على مستندٍ غائب **عديمُ الأثر**) —
/// ⟵ **فلا استعلامَ داخل معاملةٍ ولا فهرسَ إضافي**، ⛔ **ولا نسخةٌ ثانية
/// من البند نفسه** مهما تكرّرت الكتابة.
///
/// ★★ **وهو ما يجعل البناء «قابلاً لإعادة البناء بالكامل»** (§10 · `PAT-07`):
/// ⟵ **إعادةُ تشغيل الكاتب على المستندات نفسها تُنتج المجموعة نفسها حرفاً
/// بحرف**، ⛔ **بلا تراكمٍ ولا يتامى.**
/// ═══════════════════════════════════════════════════════════════════════
String pendingEntryId({
  required PendingDocumentKind kind,
  required String documentId,
  required PendingMissingField field,
}) {
  final String id = documentId.trim();
  if (id.isEmpty) {
    throw ArgumentError.value(
      documentId,
      'documentId',
      'معرّف المستند إلزامي — وبندٌ بلا مستندٍ لا وجهةَ له',
    );
  }
  return '${kind.name}_${id}_${field.name}';
}

// ═════════════════════════════════════════════════════════════════════════
// البند كما يُكتَب — ★ **السحابة وحدها تبنيه**
// ═════════════════════════════════════════════════════════════════════════

/// ★★ بندٌ معلّق **مُعَدٌّ للكتابة** — `data-dictionary.md` §`pending_entries`.
///
/// ⚠️ **وهو غير [PendingEntryCard] عمداً** — ★ **بنفس فرق `AuditEntry` عن
/// `AuditLogEntryCard`:** ⟵ **هذا يُبنى ليُكتَب فيرفض ما لا يجوز كتابته،
/// وذاك يُقرأ من بندٍ كُتب فعلاً فلا يرمي على نقصٍ في إصدارٍ سابق.**
final class PendingEntryDraft {
  /// ينشئ البند، ويرفض ما لا وجهةَ له.
  factory PendingEntryDraft({
    required PendingDocumentKind kind,
    required String documentId,
    required PendingMissingField field,
    required String readableTitle,
    required String sourceId,
    required CalendarDay date,
    String? documentNumber,
    String? missingField,
  }) {
    if (sourceId.trim().isEmpty) {
      // ⛔⛔ **ومصدرٌ فارغ يجعل البند غيرَ مقروءٍ لأحد** — ★ **شرطُ القراءة
      //    `storedInScope()` يفحص `resource.data.sourceId`**، ⟵ **وبندٌ بلا
      //    مصدرٍ يُكتب ثم لا يراه أحدٌ أبداً** ⛔ **وهو أسوأ من ألّا يُكتب.**
      throw ArgumentError.value(
        sourceId,
        'sourceId',
        'المصدر إلزامي في كل بند — والنطاق يُقاس عليه',
      );
    }
    final String title = readableTitle.trim();
    if (title.isEmpty) {
      // ★ **«عنوانٌ يفهمه المستخدم بلا فتح المستند»** — §3 نصّاً.
      throw ArgumentError.value(
        readableTitle,
        'readableTitle',
        'العنوان المقروء إلزامي — وبندٌ بلا عنوانٍ لا يُفهَم',
      );
    }
    return PendingEntryDraft._(
      kind: kind,
      documentId: documentId.trim(),
      field: field,
      readableTitle: title,
      sourceId: sourceId.trim(),
      date: date,
      documentNumber: _trimmedOrNull(documentNumber),
      missingField: _trimmedOrNull(missingField) ?? field.defaultLabel,
    );
  }

  const PendingEntryDraft._({
    required this.kind,
    required this.documentId,
    required this.field,
    required this.readableTitle,
    required this.sourceId,
    required this.date,
    required this.documentNumber,
    required this.missingField,
  });

  /// نوع المستند.
  final PendingDocumentKind kind;

  /// معرّف المستند الحامل للنقص.
  final String documentId;

  /// الحقل الناقص.
  final PendingMissingField field;

  /// ★ **العنوان المقروء** — «عبد الفتاح - جونية رقم ١» (§3).
  final String readableTitle;

  /// ★★ **المصدر** — **لاحترام النطاق والفلترة** (`FR-SYS-07` · `AT-68`).
  final String sourceId;

  /// ★★ **تاريخ المخزون** — ⛔ **لا تاريخ الإدخال** (`FR-SYS-18` · `GR-13`).
  final CalendarDay date;

  /// رقم المستند إن كان مرقَّماً — و`null` لِما لا رقم له (`daily_prices`).
  final String? documentNumber;

  /// ★ **القيمة الناقصة بالاسم العربي** (§3) — ⛔ **بلا مصطلح تقني**.
  final String missingField;

  /// معرّف البند — [pendingEntryId].
  String get entryId =>
      pendingEntryId(kind: kind, documentId: documentId, field: field);

  /// حقول المستند كما تُكتب.
  ///
  /// ⛔★★ **ولا حقلَ مالي هنا ولا كمية** — ★ **المركز يذكّر بما ينقص**،
  /// ⟵ **وحملُه رقماً يجعله مصدرَ حقيقةٍ ثانياً لِما هو مشتقٌّ أصلاً** (§10).
  Map<String, Object?> toFields() => <String, Object?>{
        'documentType': kind.name,
        'documentId': documentId,
        if (documentNumber case final String number) 'documentNumber': number,
        'readableTitle': readableTitle,
        'sourceId': sourceId,
        'date': date.asUtcMidnight(),
        'missingField': missingField,
        // ★★ **وجهة زر [إدخال] — الشاشة والحقل معاً** (§3 · `FR-SYS-04`).
        'navigationScreen': kind.screen.name,
        'navigationField': field.fieldKey,
        // ★ **ومفتاح الحقل مخزَّنٌ صراحةً** — ⟵ **فالقارئ يعرف *أيّ* بندٍ
        //   هذا بلا أن يُفكّك معرّفه نصّاً** ⛔ **ولا تحليلَ لمعرّف.**
        'missingFieldKey': field.name,
      };

  @override
  bool operator ==(Object other) =>
      other is PendingEntryDraft &&
      other.kind == kind &&
      other.documentId == documentId &&
      other.field == field &&
      other.readableTitle == readableTitle &&
      other.sourceId == sourceId &&
      other.date == date &&
      other.documentNumber == documentNumber &&
      other.missingField == missingField;

  @override
  int get hashCode => Object.hash(
        kind,
        documentId,
        field,
        readableTitle,
        sourceId,
        date,
        documentNumber,
        missingField,
      );
}

// ═════════════════════════════════════════════════════════════════════════
// البند كما يُقرأ
// ═════════════════════════════════════════════════════════════════════════

/// بطاقة بندٍ معلّق كما تُقرأ في الشاشة.
final class PendingEntryCard {
  /// ينشئ البطاقة.
  const PendingEntryCard({
    required this.id,
    required this.kind,
    required this.documentId,
    required this.readableTitle,
    required this.sourceId,
    required this.date,
    required this.missingField,
    this.field,
    this.documentNumber,
  });

  /// معرّف البند.
  final String id;

  /// نوع المستند — ★ **و`null` نوعٌ لا يعرفه هذا الإصدار**.
  final PendingDocumentKind? kind;

  /// معرّف المستند.
  final String documentId;

  /// العنوان المقروء.
  final String readableTitle;

  /// المصدر.
  final String sourceId;

  /// تاريخ المخزون.
  final CalendarDay? date;

  /// القيمة الناقصة بالعربية.
  final String missingField;

  /// الحقل — ★ **و`null` حقلٌ لا يعرفه هذا الإصدار** فيُخفى زرّ [إدخال].
  final PendingMissingField? field;

  /// رقم المستند إن وُجد.
  final String? documentNumber;

  /// ★★ هل يملك هذا البند وجهةً صالحة لزر [ إدخال ]؟
  ///
  /// ⛔ **وبندٌ بلا وجهةٍ يُعرَض ولا يُفتَح** — ★ **فاختفاؤه يُخفي نقصاً
  /// قائماً**، ⟵ **وفتحُه على شاشةٍ مُخمَّنة أسوأ** (`GR-50`: يُذكّر).
  bool get hasDestination => kind != null && field != null;
}

// ═════════════════════════════════════════════════════════════════════════
// الفلتر والدليل — ⛔ **ولا استعلامَ بلا مصدرٍ مُقيَّد**
// ═════════════════════════════════════════════════════════════════════════

/// فلتر المركز — `FR-SYS-10`: **المصدر · التاريخ · نوع المستند**.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **والمصدر إلزاميٌّ في النوع نفسه — وهذا قياسٌ حيٌّ لا اجتهاد:**
/// قاعدة `pending_entries` تشترط `storedInScope()` وهي شرطٌ على
/// `resource.data`، ⟵ **والسردُ يُقيَّم على قيود الاستعلام لا على كل مستند**
/// ⟹ **`getDocs` بلا قيدٍ على `sourceId` يُرفَض كاملاً — ولو بنطاقٍ شامل.**
///
/// ★★ **وهو الدرس المقيس ثلاث مرات في هذا المشروع:** `IQ-024` (`sources`) ·
/// `WU-008` (`audit_log`) · `DEBT-40` (`distributions`) — ⟵ **فالعلاج
/// تقييدُ الحقل في الاستعلام** ⛔ **لا تخفيفُ القاعدة.**
///
/// ★ **ويوافق مبدأ النظام لا يخالفه:** `A-01` (**لا جمع بين مصدرين في أي
/// عملية**) · `GR-23` (**النطاق قيدٌ يعلو على كل صلاحية**) ·
/// `FR-SYS-07` (**المركز يحترم نطاق مصادر المستخدم** — `AT-68`).
/// ═══════════════════════════════════════════════════════════════════════
final class PendingEntryFilter {
  /// ينشئ الفلتر، ويرفض استعلاماً بلا مصدر.
  factory PendingEntryFilter({
    required String sourceId,
    PendingDocumentKind? kind,
  }) {
    if (sourceId.trim().isEmpty) {
      throw ArgumentError.value(
        sourceId,
        'sourceId',
        'المصدر إلزامي في كل استعلام على المركز — وإلا رُفض الاستعلام كاملاً',
      );
    }
    return PendingEntryFilter._(sourceId: sourceId.trim(), kind: kind);
  }

  const PendingEntryFilter._({required this.sourceId, required this.kind});

  /// ★★ المصدر — **إلزاميٌّ دائماً** (راجع ترويسة الصنف).
  final String sourceId;

  /// ★ نوع المستند — و`null` **كل الأنواع**.
  ///
  /// ⚠️ **ويُفلتَر في الذاكرة لا في الاستعلام** — راجع [PendingEntryDirectory].
  final PendingDocumentKind? kind;

  /// هل يقبل الفلتر بطاقةً بهذا النوع؟
  bool accepts(PendingEntryCard card) => kind == null || card.kind == kind;

  @override
  bool operator ==(Object other) =>
      other is PendingEntryFilter &&
      other.sourceId == sourceId &&
      other.kind == kind;

  @override
  int get hashCode => Object.hash(sourceId, kind);
}

/// ★ حدّ الصفحة الواحدة — بنفس علّة `auditLogPageSize` حرفياً.
///
/// ⚠️ **والمركز ينمو بلا حدٍّ كذلك** — ★ **بندٌ لكل قيمةٍ متروكة في كل يوم**،
/// ⟵ **واستعلامٌ بلا حدٍّ يصير أبطأ كل يوم بلا أن يفشل مرة**، ⛔ **فلا يظهر
/// في اختبارٍ ولا مراجعة.**
///
/// ⚠️ **والقيمة قرارٌ تنفيذي روتيني مُعلَن** — ⛔ **لا نقلٌ عن مستند**:
/// ★ **مئةٌ ضِعفُ ما تعرضه شاشةٌ واحدة** ⟵ **فالعدّاد صادقٌ عملياً**،
/// ★ **وهي نفس رتبة `dealerLedgerLimit`.**
const int pendingEntriesPageSize = 100;

/// دليل المركز — ★★ **قراءةً فقط** (`FR-SYS-09`).
///
/// ⛔⛔★★ **ولا نظيرَ كاتبٍ له في هذا الملف ولا في غيره** — `FR-SYS-09`:
/// «**بنود المركز تُنشئها وتحذفها السحابة حصراً — لا يكتبها التطبيق ولا
/// يحذفها المستخدم**»، ★ **والقاعدة `allow write: if false` للجميع.**
/// ⟵ **وغيابُ الدالة هنا هو نظيرُها في الكود: ما لا عقدَ له لا يُستدعى
/// بالسهو** (نفس منطق `AuditLogDirectory`).
abstract interface class PendingEntryDirectory {
  /// ⛅ بنود مصدرٍ واحد — ★ **مرتَّبةً بالتاريخ تنازلياً** (الفهرس
  /// `sourceId ↑ · date ↓` — `indexing-strategy.md`).
  ///
  /// ⚠️ **ونوعُ المستند يُفلتَر في الذاكرة** — ⛔ **لا في الاستعلام**:
  /// ★ **الفهرس المعتمَد حقلان اثنان** (`sourceId` · `date`)، ⟵ **وقيدٌ
  /// ثالث كان يفرض فهرساً رابعاً لِما تحسمه الصفحةُ الواحدة أصلاً.**
  Stream<List<PendingEntryCard>> watchPending({
    required PendingEntryFilter filter,
    int limit = pendingEntriesPageSize,
  });
}

String? _trimmedOrNull(String? value) {
  final String? text = value?.trim();
  return (text == null || text.isEmpty) ? null : text;
}

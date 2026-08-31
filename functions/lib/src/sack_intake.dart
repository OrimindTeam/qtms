/// الوارد جواني — **التخطيط الخالص** لعمليات `WU-004` (`M7`).
///
/// ★ **مفصول عن الشبكة بنفس منطق `inventory.dart`:** `ADR-0013` القاعدة 3
/// تجعل **فحص التفويض في الكود** هو الحارس الوحيد لهذا المسار، فالدالة تعمل
/// بامتياز إداري يتجاوز قواعد الحماية. ★ **وحارسٌ لا يُختبَر بلا سحابة
/// حارسٌ غير مُختبَر** — فكل قرار هنا **دالة خالصة**.
///
/// ★ **وكل معادلة من طبقة النطاق لا من هنا** (`qtms_domain`) —
/// ⛔ **ولا تُعاد كتابتها** (`coding-standards.md` §2.2).
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔★★★ **سبعة مسارات كتابةٍ منفصلة لا مسارٌ جامع — وهو نصّ `FR-M7-27`:**
/// «**مسارات كتابة منفصلة لكل مجموعة حقول** … **كل منها يشترط صلاحيته
/// المطابقة**». ⟵ ★ **فدالةٌ جامعة كانت تُلزم من يُدخل الضريبة بامتلاك
/// صلاحية إدخال الأنواع**، ⛔ **وهو توسيعُ امتيازٍ يخالف تفكيك `§9.6`.**
///
/// ★★ **ولكل مسارٍ قناعُ كتابةٍ ضيّق** — ⟵ **فمسارُ الاسم لا يمسّ وزناً،
/// ومسارُ الضريبة لا يمسّ سطراً**، ⛔ **ولا قناعٌ واسع يمحو ما لم يُقصَد.**
/// ═══════════════════════════════════════════════════════════════════════
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔★★ **وثمانية قيود كانت قواعدَ حماية قبل `WU-026`، وصارت بند قبولٍ هنا**
/// (`DEBT-21` ① · التحذير المكتوب في `firestore.rules` §12):
///
///   ① **الصلاحية** — ★ **و`sackCreate` مفتاحٌ مستقل** (`IQ-021` الخيار أ).
///   ② ★★ **نطاق المصادر** — ⛔ **قيدٌ يعلو على كل صلاحية** (`GR-23`).
///   ③ **تاريخ المخزون = تاريخ اليوم من الخادم** (`FR-M7-02` · `A-10`).
///   ④ **وقت الخادم في `createdAt` و`entryDate`**.
///   ⑤ **السبب النصي غير الفارغ لكل تعديل وإلغاء** (`ADR-0004` · `CR-002`).
///   ⑥ ★★ **منع الرصيد السالب** — ★ **مقيساً من الدفتر داخل المعاملة**.
///   ⑦ ⛔★★★ **ولا حقل مالي في مستند الجونية إطلاقاً** (`ADR-0011`) —
///      ★ **والمالية في `finance/current` وحدها**، ⟵ **لأن القاعدة تمنح
///      المستند كاملاً ولا تُخفي حقلاً داخله.**
///   ⑧ **الحذف مرفوض نهائياً** — ⟵ **ولا مسار حذف في هذا الملف أصلاً.**
/// ═══════════════════════════════════════════════════════════════════════
library;

import 'package:qtms_domain/qtms_domain.dart';

import 'callable.dart';
import 'firestore_value.dart' show DecimalValue;
import 'identity_gateway.dart';
import 'inventory.dart';

/// نوع عملية على جونية — ★ **ويحدد الصلاحية التي لا تُنفَّذ بدونها**.
enum SackOperation {
  /// ★★★ `createSack` — يشترط **`sackCreate`** (`FR-M7-01` · `IQ-021`).
  ///
  /// ⛔★★ **ولا يكتب سطراً واحداً من الأنواع** — ★ **يكتب الرأس والسكرب
  /// وحدهما**، وهو **نصّ آلة الحالة في `sack-intake-design.md` §2**:
  /// `أوزان_مُدخَلة ⟵ السكرب_في_المخزن (حفظ فوري) ⟵ وزن_غير_مفسَّر`.
  /// ⟵ **والأنواع تدخل بمسارها وصلاحيتها** (`FR-M7-27`)، ⛔ **وحشرُها هنا
  /// كان يُلزم كل مُنشئ جونيةٍ بامتلاك `sackLinesEnter` كذلك.**
  createSack(Permission.sackCreate, isCreate: true),

  /// `enterSackLines` — يشترط `sackLinesEnter` (`FR-M7-12`).
  ///
  /// ⛔ **مسارٌ يقتصر على مصفوفة السطور** — `§9.6` حرفياً.
  ///
  /// ★★ **ومسارُ تعبئةٍ مؤجَّلة** (`ADR-0018` · `IQ-025`): «إدخال أنواع
  /// الجونية **الآن**» و«**لاحقاً**» مفتاحان مستقلان عن `sackAmend`،
  /// ⟵ **فالسببُ اختياريٌّ هنا** ⛔ **ولا يُعبَّأ آلياً.**
  enterSackLines(Permission.sackLinesEnter, touchesLines: true),

  /// `enterSackTax` — يشترط `sackTaxEnterNow` **أو** `sackTaxEnterLater`.
  ///
  /// ★★ **مفتاحان لمسارٍ واحد** — وهو ما كانت تقوله القاعدة نصّاً قبل
  /// `WU-026`: `perm('sackTaxEnterNow') || perm2('sackView','sackTaxEnterLater')`.
  /// ⟵ **فـ«لاحقاً» يشترط `sackView` معه** (الكتالوج §2.2).
  /// ★★ **وهي تعبئةٌ مؤجَّلة كذلك** (`ADR-0018` · `IQ-025`) — `FR-M7-10`:
  /// **القيمة 🔵 حالي/لاحق** ويلاحقها المركز المعلّق حتى تُدخَل،
  /// ⟵ **فالسببُ اختياريٌّ فيها** ⛔ **ولا يُعبَّأ آلياً.**
  enterSackTax(
    Permission.sackTaxEnterNow,
    alternatePermission: Permission.sackTaxEnterLater,
    alternateCompanion: Permission.sackView,
    touchesFinance: true,
  ),

  /// `renameSack` — يشترط `sackRenameDisplay` (`FR-M7-05`).
  ///
  /// ⛔★★ **ويمنع مسّ الرقم المتسلسل** (`ADR-0007` القاعدة 3).
  renameSack(Permission.sackRenameDisplay),

  /// `enterSackScrapWeight` — يشترط `sackScrapWeightEnter` (`FR-M7-09`).
  ///
  /// ⚙️ **ويُعيد توليد سطر مخزون السكرب** — ⛔ **ويُعيد بناء رصيده.**
  enterSackScrapWeight(Permission.sackScrapWeightEnter, touchesScrap: true),

  /// `confirmSackLostWeight` — يشترط `sackLostWeightConfirm` (`FR-M7-19`).
  ///
  /// ⛔★★ **ولا يلمس الدفتر إطلاقاً** — `FR-M7-20`: **الوزن الضائع لا يدخل
  /// المخزون ولا يُقيَّد له أي قيمة**، ⟵ **وهو بيانٌ تفسيري للوزن فقط.**
  confirmSackLostWeight(Permission.sackLostWeightConfirm),

  /// `amendSack` — يشترط `sackAmend` ★ **وسبباً نصياً** (`FR-M7-26`).
  amendSack(
    Permission.sackAmend,
    touchesLines: true,
    touchesScrap: true,
    isFullAmend: true,
  ),

  /// `cancelSack` — يشترط `sackCancel` ★ **وسبباً نصياً**.
  ///
  /// ⛔★★ **وليس حذفاً:** الإلغاء **وسمٌ يُستبعَد من الجمع** (`GR-06`).
  cancelSack(
    Permission.sackCancel,
    isCancel: true,
    touchesLines: true,
    touchesScrap: true,
  );

  const SackOperation(
    this.requiredPermission, {
    this.alternatePermission,
    this.alternateCompanion,
    this.isCreate = false,
    this.isCancel = false,
    this.touchesLines = false,
    this.touchesScrap = false,
    this.touchesFinance = false,
    this.isFullAmend = false,
  });

  /// الصلاحية التي لا تُنفَّذ العملية بدونها.
  final Permission requiredPermission;

  /// ★ صلاحية بديلة مقبولة — ⛔ **للضريبة وحدها** (راجع [enterSackTax]).
  final Permission? alternatePermission;

  /// ★ صلاحية تُشترَط **مع** [alternatePermission] لا بدلاً عنها.
  final Permission? alternateCompanion;

  /// هل هي إنشاء؟
  final bool isCreate;

  /// هل هي إلغاء؟
  final bool isCancel;

  /// هل تلمس حركات السطور؟
  final bool touchesLines;

  /// هل تلمس حركة السكرب؟
  final bool touchesScrap;

  /// هل تكتب في `finance/current`؟
  final bool touchesFinance;

  /// ★ هل هي تعديلٌ شامل للرأس والسطور معاً؟ (`FR-M7-26`).
  final bool isFullAmend;

  // ⛔⛔★★★ **`isDeferredEntry` و`requiresReason` حُذفا بـ`ADR-0020`
  //   (2026-08-27).** ★ **كان الأول عَلَمَ الإعفاء المُسمَّى** (`ADR-0018` ·
  //   `IQ-025`) **والثاني حارسَ السبب** — ⟵ **وقد صار السبب اختيارياً في كل
  //   العمليات**، ⛔ **فلا حارسَ يُعفى منه ولا عَلَمَ يطلب إعفاءً.**
  //
  //   ✅★★ **وما بقي من `ADR-0018` نافذاً هنا: «التعبئة الأولى ليست تعديلاً»**
  //   — ⛔ **لا `amendCount` ولا `amendedBy` ولا شارة «مُعدَّل»** ⟵ **وهو
  //   محمولٌ على `isFirstEntry` في `_partialWrite`**، ★ **لا على هذا العَلَم**،
  //   ⛔ **فلم يسقط بسقوطه.**
}

/// نتيجة التخطيط — إما خطة كتابة وإما رفض مصنَّف.
sealed class SackPlan {
  /// ينشئ النتيجة.
  const SackPlan();
}

/// رُفض الطلب قبل أي كتابة.
final class SackRejected extends SackPlan {
  /// ينشئ رفضاً.
  const SackRejected(this.error);

  /// رمز الرفض من كتالوج الأخطاء.
  final CallableError error;
}

/// قُبل الطلب — وهذه كتاباته وقيده.
final class SackAccepted extends SackPlan {
  /// ينشئ خطة مقبولة.
  const SackAccepted({
    required this.documentNumber,
    required this.writes,
    required this.entry,
  });

  /// رقم المستند.
  final String documentNumber;

  /// المستندات المكتوبة — ⛔ **ولا تكون فارغة**.
  final List<InventoryWrite> writes;

  /// قيد التدقيق — **يُكتب في المعاملة نفسها** (`ADR-0013` القاعدة 1).
  final AuditEntry entry;
}

/// ★ حالة الجونية المخزَّنة كما قُرئت — **مفكوكةً بأنواعها**.
///
/// ⚠️⚠️ **ولماذا نوعٌ مفكوك لا خريطةٌ خام:** كل مسارٍ من السبعة **يبني
/// المستند كاملاً من قيمه المخزَّنة ثم يستبدل مجموعته وحدها** — ⟵ **فقراءةُ
/// الخريطة الخام في سبعة مواضع كانت تُكرِّر فكَّ الترميز سبع مرات**،
/// ⛔ **وكلُّ نسخةٍ منها تفترق عند أول تغيير في اسم حقل.**
final class StoredSack {
  /// ينشئ الحالة المقروءة.
  const StoredSack({
    required this.sourceId,
    required this.stockDate,
    required this.dailySequence,
    required this.displayName,
    required this.weights,
    required this.lines,
    required this.status,
    required this.lostWeightConfirmed,
    this.supplierId,
    this.supplierName,
    this.scrapItemKey,
    this.lostWeightNote,
    this.notes,
    this.amendCount = 0,
  });

  /// المصدر المخزَّن — ★★ **وهو الحَكَم لا المُرسَل** (`GR-23`).
  final String sourceId;

  /// تاريخ المخزون المخزَّن — ★★ **وهو الحَكَم كذلك** (`RISK-07`).
  final CalendarDay stockDate;

  /// ★★ الرقم المتسلسل اليومي — ⛔ **لا يتغيّر أبداً**.
  final int dailySequence;

  /// الاسم الظاهر.
  final String displayName;

  /// الأوزان الثلاثة.
  final ValidatedSackWeights weights;

  /// السطور المخزَّنة.
  final List<ValidatedSackLine> lines;

  /// الحالة.
  final SackStatus status;

  /// هل أُكِّد الوزن الضائع؟
  final bool lostWeightConfirmed;

  /// الرعوي.
  final String? supplierId;

  /// ★ اسم الرعوي **المُجمَّد لحظة الإنشاء** — ⛔ **ولا يُعاد قراءته**.
  ///
  /// ⚠️⚠️ **وهذا ما يجعل الاسم المركّب ثابتاً:** `ADR-0007` القاعدة 4 —
  /// ⟵ **فتغيّرُ اسم الرعوي لاحقاً لا يُعيد تسمية مفاتيح رصيدٍ قائمة**،
  /// ⛔ **وقراءتُه من سجل الرعوي في كل تعديل كانت تكسر كل مفاتيحها.**
  final String? supplierName;

  /// مفتاح سطر السكرب أو `null`.
  final String? scrapItemKey;

  /// ملاحظة الوزن الضائع.
  final String? lostWeightNote;

  /// ملاحظات المستند.
  final String? notes;

  /// عدد التعديلات.
  final int amendCount;
}

/// طلبٌ على جونية مُتحقَّق من هوية مُنفِّذه.
final class SackRequest {
  /// ينشئ الطلب.
  const SackRequest({
    required this.actor,
    required this.requestId,
    required this.sourceId,
    required this.documentNumber,
    required this.stockDate,
    this.dailySequence,
    this.intake,
    this.lines,
    this.storedSource,
    this.stored,
    this.items = const <String, ItemRead>{},
    this.ledger = const <String, List<LedgerRead>>{},
    this.storedSupplierSourceIds,
    this.storedSupplierName,
    this.scrapItemId,
    this.taxPerKilo,
    this.displayName,
    this.scrapWeight,
    this.lostWeightNote,
    this.reason,
    this.deviceInfo,
  });

  /// المُنفِّذ **بحالته الآن من خدمة المصادقة**.
  final AccountRecord actor;

  /// ★ معرّف الطلب — **وهو معرّف قيد التدقيق نفسه** (`api-overview.md` §4).
  final String requestId;

  /// المصدر المستهدف.
  final String sourceId;

  /// رقم المستند.
  final String documentNumber;

  /// ★★ تاريخ المخزون — ⛔ **من زمن المنصّة داخل المعاملة** (`GR-54`).
  final CalendarDay stockDate;

  /// ★★ الرقم المتسلسل اليومي المخصَّص — ⛅ **للإنشاء وحده**.
  final int? dailySequence;

  /// الجونية المُتحقَّق منها — **للإنشاء والتعديل الشامل**.
  final ValidatedSackIntake? intake;

  /// ★ السطور المُتحقَّق منها — **لمسار `enterSackLines` وحده**.
  final List<ValidatedSackLine>? lines;

  /// سجل المصدر كما قُرئ — ⛔ **و`null` رفضٌ لا تجاوز**.
  final Map<String, Object?>? storedSource;

  /// ★ الجونية القائمة — `null` تعني **غيابها**.
  final StoredSack? stored;

  /// سجلات الأنواع المطلوبة بمعرّفاتها.
  final Map<String, ItemRead> items;

  /// ★★ **حركات الدفتر لكل مفتاح مركّب** — **مقروءةً داخل المعاملة**.
  final Map<String, List<LedgerRead>> ledger;

  /// مصادر الرعوي المُرسَل.
  final List<String>? storedSupplierSourceIds;

  /// اسم الرعوي كما هو مخزَّن — ★ **للنسخة المُجمَّدة عند الإنشاء**.
  final String? storedSupplierName;

  /// ★ معرّف النوع الافتراضي «السكرب» — ⛅ **من `app_settings`** (`IQ-012`).
  final String? scrapItemId;

  /// قيمة ضريبة الكيلو — **لمسار الضريبة وحده**.
  final Money? taxPerKilo;

  /// الاسم الظاهر الجديد — **لمسار التسمية وحده**.
  final String? displayName;

  /// وزن السكرب الجديد — **لمساره وحده**.
  final WeightKg? scrapWeight;

  /// ملاحظة الوزن الضائع.
  final String? lostWeightNote;

  /// ★ سبب التعديل أو الإلغاء (`ADR-0004`).
  final String? reason;

  /// وصف الجهاز للسجل — ⛔ بلا بيانات حساسة.
  final String? deviceInfo;
}

/// ★★ فحوص الحالة والصلاحية والنطاق — **تُستدعى قبل فتح المعاملة**.
///
/// ⚠️ **ولماذا مُصدَّرة:** كل عملية هنا تحتاج **قراءةً داخل معاملة** قبل أن
/// يكتمل تخطيطها، ⟵ **وفتحُ معاملةٍ لطلبٍ يرفضه نقصُ الصلاحية هدرٌ وقفلٌ
/// بلا داعٍ**. ★ **والفحص يُعاد كاملاً** في [planSack] ⛔ **فلا مسار
/// يتخطّاه.**
SackRejected? sackGate(SackRequest request, SackOperation operation) {
  // ① «التعطيل فوري ونافذ» — `authentication-policy.md` §2 القاعدة 3.
  if (request.actor.disabled) {
    return const SackRejected(CallableError.accountDisabled);
  }
  // ② الصلاحية — ⛔ ولا قاعدة حماية تحرس هذا المسار (`ADR-0013` القاعدة 2).
  if (!_hasPermissionFor(request.actor, operation)) {
    return const SackRejected(CallableError.permissionMissing);
  }
  // ③ ★★ **النطاق — قيدٌ يعلو على الصلاحية** (`GR-23` · `FR-M7-28`).
  //    ⛔ **والغياب منعٌ لا سماح** (`canAccessSource` يُرجِع `false`).
  if (!request.actor.claims.canAccessSource(request.sourceId)) {
    return const SackRejected(CallableError.sourceOutOfScope);
  }
  // ④ معرّف الطلب إلزامي — وبدونه لا تتحقق اللاتكرارية عند إعادة الإرسال.
  if (request.requestId.trim().isEmpty) {
    return const SackRejected(CallableError.invalidArgument);
  }
  return null;
}

/// ★★ يفحص امتلاك الصلاحية — **بالمفتاح الأصلي أو بالبديل مع رفيقه**.
///
/// ⛔★★ **والرفيق شرطٌ لا زينة:** الكتالوج §2.2 ينصّ أن `sackTaxEnterLater`
/// **«يشترط `sackView` معاً»** — ⟵ **ومن يملك «لاحقاً» وحده بلا `sackView`
/// لا يرى الجونية أصلاً**، ⛔ **فإدخالُه ضريبةً على مستندٍ لا يقرؤه عبثٌ
/// يفتح مساراً بلا رقابة.**
bool _hasPermissionFor(AccountRecord actor, SackOperation operation) {
  if (actor.claims.has(operation.requiredPermission)) return true;
  final Permission? alternate = operation.alternatePermission;
  if (alternate == null || !actor.claims.has(alternate)) return false;
  final Permission? companion = operation.alternateCompanion;
  return companion == null || actor.claims.has(companion);
}

/// يخطّط عملية جونية — **دالة خالصة، وهي حارس التفويض الفعلي**.
SackPlan planSack(SackRequest request, SackOperation operation) {
  final SackRejected? gate = sackGate(request, operation);
  if (gate != null) return gate;

  if (request.documentNumber.trim().isEmpty) {
    return const SackRejected(CallableError.invalidArgument);
  }

  // ⛔⛔★★★ **حارسُ السبب حُذف بـ`ADR-0020` (2026-08-27)** — ★ **السبب
  //    اختياريٌّ في كل عملية**، ⟵ **ولا رفضَ لغيابه.** ⛔ **ولا يُعبَّأ
  //    آلياً:** ★ **ما لم يكتبه إنسانٌ لا يُخزَّن.**
  final String? reason = _trimmed(request.reason);
  final SackRejected? existence = _existenceGate(request, operation);
  if (existence != null) return existence;

  final SackRejected? source = _sourceGate(request, operation);
  if (source != null) return source;

  return switch (operation) {
    SackOperation.createSack => _planCreate(request),
    SackOperation.cancelSack => _planCancellation(request, reason),
    SackOperation.enterSackTax => _planTax(request, reason),
    SackOperation.renameSack => _planRename(request, reason),
    SackOperation.confirmSackLostWeight => _planLostWeight(request),
    SackOperation.enterSackLines => _planLines(request, reason),
    SackOperation.enterSackScrapWeight => _planScrapWeight(request, reason),
    SackOperation.amendSack => _planFullAmend(request, reason),
  };
}

// ═════════════════════════════════════════════════════════════════════════
// ★★★ الإنشاء — **الرأس والسكرب معاً، والسكرب قبل أي نوع آخر** (`FR-M7-09`)
// ═════════════════════════════════════════════════════════════════════════

SackPlan _planCreate(SackRequest request) {
  final ValidatedSackIntake? intake = request.intake;
  final int? sequence = request.dailySequence;
  if (intake == null ||
      intake.sourceId != request.sourceId ||
      sequence == null ||
      sequence < 1) {
    return const SackRejected(CallableError.invalidArgument);
  }

  final SackRejected? supplier = _supplierGate(request, intake.supplierId);
  if (supplier != null) return supplier;

  // ⛔★★ **ولا سطر واحد في الإنشاء** — راجع [SackOperation.createSack].
  if (intake.lines.isNotEmpty) {
    return const SackRejected(CallableError.invalidArgument);
  }

  // ★ **اسم الرعوي يُجمَّد الآن** — `ADR-0007` القاعدة 4.
  final String? supplierName =
      intake.supplierId == null ? null : _trimmed(request.storedSupplierName);
  if (intake.supplierId != null && supplierName == null) {
    // ⛔ **رعويٌّ بلا اسمٍ مقروء ⟵ رفض**: الاسم **جزءٌ من مفتاح الرصيد**،
    //    ⟵ **وجونيةٌ بمفتاحٍ ناقص تُفصَل حركاتُها عن رأسها بصمت.**
    return const SackRejected(CallableError.internal);
  }

  final List<InventoryWrite> writes = <InventoryWrite>[];

  // ⚙️★★★ **السكرب يدخل المخزن عند حفظ الرأس — قبل أي نوع آخر** (`AT-07`).
  final Outcome<List<InventoryWrite>> scrap = _scrapWrites(
    request: request,
    weights: intake.weights,
    dailySequence: sequence,
    supplierName: supplierName,
    isCreate: true,
    reason: null,
  );
  if (scrap case Failure<List<InventoryWrite>>(:final AppError error)) {
    return SackRejected(_mapStockError(error, SackOperation.createSack));
  }
  writes.addAll((scrap as Success<List<InventoryWrite>>).value);

  final String displayName = sackDisplayName(
    dailySequence: sequence,
    supplierName: supplierName,
  );
  final Map<String, Object?> after = _documentFields(
    request: request,
    intake: intake,
    dailySequence: sequence,
    displayName: displayName,
    supplierName: supplierName,
    scrapItemKey: _scrapKeyOf(intake.weights, sequence, supplierName),
  );

  writes.insert(
    0,
    InventoryWrite(
      collectionId: sacksCollection,
      documentId: request.documentNumber,
      fields: <String, Object?>{
        ...after,
        'createdBy': request.actor.userId,
      },
      updateMask: <String>[...after.keys, 'createdBy'],
      serverTimestampFields: const <String>['createdAt', 'entryDate'],
    ),
  );

  return SackAccepted(
    documentNumber: request.documentNumber,
    writes: writes,
    entry: _entry(
      request: request,
      action: AuditAction.create,
      reason: null,
      valuesBefore: const <String, Object?>{},
      valuesAfter: after,
    ),
  );
}

// ═════════════════════════════════════════════════════════════════════════
// السطور — ★ **مسارٌ يقتصر على `lines`** (`sackLinesEnter` · `§9.6`)
// ═════════════════════════════════════════════════════════════════════════

SackPlan _planLines(SackRequest request, String? reason) {
  final StoredSack stored = request.stored!;
  final List<ValidatedSackLine>? lines = request.lines;
  if (lines == null) return const SackRejected(CallableError.invalidArgument);

  // ★★★ **أوّلُ تعبئةٍ أم تغييرٌ على سطورٍ قائمة؟** — `IQ-025` · `ADR-0018`.
  //
  // ⛔⛔ **والفرق ليس تجميلاً:** جونيةٌ تُدخَل سطورُها لأول مرة **لم تُعدَّل**،
  //    ⟵ **فرفعُ `amendCount` كان يُظهر شارة «مُعدَّل ×1»** على مستندٍ
  //    **لم يمسّه أحدٌ بعد إنشائه** (`ADR-0004` القاعدة 3 · `E-06`).
  final bool isFirstEntry = !_hasStoredLines(stored);

  // ★★ **والقيود تُعاد على الحالة المخزَّنة لا على ما أرسله العميل** —
  //    ⟵ **فالأوزان من المستند**، ⛔ **ولا يُعلن الجهازُ مطالباً به أوسع.**
  final Outcome<List<InventoryWrite>> planned = _lineWrites(
    request: request,
    stored: stored,
    lines: lines,
    reason: reason,
    isCreate: isFirstEntry,
  );
  if (planned case Failure<List<InventoryWrite>>(:final AppError error)) {
    return SackRejected(_mapStockError(error, SackOperation.enterSackLines));
  }

  final SackWeightExplanation explanation = explainSackWeight(
    weights: stored.weights,
    lines: lines,
    lostWeightConfirmed: stored.lostWeightConfirmed,
  );
  // ⑥ ★★ **لا تجاوز للمطالب به** — `FR-M7-18` · `E-07`.
  if (explanation.remainingWeight.kilograms < -weightEpsilonKg) {
    return const SackRejected(CallableError.sackWeightExceeded);
  }

  final Map<String, Object?> after = <String, Object?>{
    'lines': _lineMaps(lines),
    'totalQuantity': _piecesOf(lines),
    ..._explanationFields(explanation),
    'isPricingComplete': lines.isNotEmpty &&
        lines.every((ValidatedSackLine l) => l.distributionPrice != null),
  };

  return _accepted(
    request: request,
    stored: stored,
    writes: <InventoryWrite>[
      _partialWrite(request, after, reason, isFirstEntry: isFirstEntry),
      ...(planned as Success<List<InventoryWrite>>).value,
    ],
    after: after,
    reason: reason,
    // ★★ **والقيد يقول الحقيقة:** أوّلُ تعبئةٍ **إنشاءُ سطور** لا تعديل —
    //    ⟵ **فيقرأ المدقّق `create` فيعلم أنه إكمالُ إدخالٍ مؤجَّل**
    //    (`FR-M7-12` · `E-06`)، ⛔ **لا مساساً بقيمةٍ سبق أن استقرّت.**
    action: isFirstEntry ? AuditAction.create : AuditAction.amend,
  );
}

// ═════════════════════════════════════════════════════════════════════════
// الضريبة — 🔒 **في `finance/current` وحدها** (`ADR-0011`)
// ═════════════════════════════════════════════════════════════════════════

SackPlan _planTax(SackRequest request, String? reason) {
  final StoredSack stored = request.stored!;
  final Money? taxPerKilo = request.taxPerKilo;
  if (taxPerKilo == null) {
    return const SackRejected(CallableError.invalidArgument);
  }
  final Outcome<Money> checked = validateSackTaxPerKilo(taxPerKilo);
  if (checked is Failure<Money>) {
    return const SackRejected(CallableError.invalidArgument);
  }

  // ★★★ **الموضع ① للتقريب** — `design-overview.md` §2.11 · `FR-M7-11`.
  //    ⛔ **وعلى الوزن الكلي لا المطالب به.**
  final Money tax = sackTax(
    taxPerKilo: taxPerKilo,
    totalWeight: stored.weights.totalWeight,
  );

  final Map<String, Object?> finance = <String, Object?>{
    // ★ **نسخة المصدر** — لتُفحَص القراءة بالنطاق بلا قراءة الأب (القواعد).
    'sourceId': stored.sourceId,
    'sackId': request.documentNumber,
    'taxPerKilo': taxPerKilo.riyals,
    // ★ **عددٌ صحيح بالريال بعد التقريب** — `ADR-0015`.
    'sackTax': tax.riyals,
  };

  return SackAccepted(
    documentNumber: request.documentNumber,
    writes: <InventoryWrite>[
      InventoryWrite(
        collectionId: sackFinancePathOf(request.documentNumber),
        documentId: sackFinanceDocumentId,
        fields: <String, Object?>{
          ...finance,
          'amendedBy': request.actor.userId,
          // ★★ **والسبب اختياريٌّ هنا** (`ADR-0018`) — ⛔ **ولا يُعبَّأ آلياً.**
          'amendReason': ?reason,
        },
        // ★ **قناعٌ ضيّق** — ⛔ **فلا يمحو إدخالُ الضريبة إيراداً ولا صافياً**
        //   يكتبهما `M14` لاحقاً في المستند نفسه.
        //
        // ⚠️★★ **و`amendReason` يبقى في القناع ولو غاب** — ⟵ **فإدخالٌ
        //   جديدٌ بلا سبب يمحو سببَ إدخالٍ سابق**، ⛔ **ولا يترك نصّاً قديماً
        //   ملتصقاً بقيمةٍ لم يُكتَب من أجلها.** ★ **والقيدُ يحفظ الأصل.**
        updateMask: <String>[
          ...finance.keys,
          'amendedBy',
          'amendReason',
        ],
        serverTimestampFields: const <String>['lastAmendedAt'],
      ),
    ],
    entry: _entry(
      request: request,
      action: AuditAction.amend,
      reason: reason,
      valuesBefore: const <String, Object?>{},
      valuesAfter: finance,
    ),
  );
}

// ═════════════════════════════════════════════════════════════════════════
// الاسم الظاهر — ⛔ **ولا يمسّ الرقم المتسلسل** (`ADR-0007` القاعدة 3)
// ═════════════════════════════════════════════════════════════════════════

/// ⛔★★ **و[reason] صار `String?` بـ`ADR-0020`** — ★ **وكانت `!` عليه
/// آمنةً بحارسٍ حُذف**، ⟵ **فلولا تليينُ التوقيع لأسقط المسارَ كلَّه.**
SackPlan _planRename(SackRequest request, String? reason) {
  final StoredSack stored = request.stored!;
  final String? displayName = _trimmed(request.displayName);
  if (displayName == null) {
    return const SackRejected(CallableError.invalidArgument);
  }

  // ⛔★★★ **حارسٌ صريح على الرقم المتسلسل** — ★ **ولا يكفي أن المسار لا
  //    يكتبه:** الحقل **يُبنى في القناع من قائمة أسماء**، ⟵ **وسطرٌ يُضاف
  //    سهواً كان يمرّ بلا اعتراض.** ★ **والفحص هنا يجعله خطأً معلَناً.**
  final Outcome<void> sequence = validateSackSequenceUnchanged(
    storedSequence: stored.dailySequence,
    incomingSequence: request.dailySequence ?? stored.dailySequence,
  );
  if (sequence is Failure<void>) {
    return const SackRejected(CallableError.invalidArgument);
  }

  final Map<String, Object?> after = <String, Object?>{
    'displayName': displayName,
  };
  return _accepted(
    request: request,
    stored: stored,
    writes: <InventoryWrite>[_partialWrite(request, after, reason)],
    after: after,
    reason: reason,
  );
}

// ═════════════════════════════════════════════════════════════════════════
// الوزن الضائع — ⛔ **ولا يلمس الدفتر** (`FR-M7-20`)
// ═════════════════════════════════════════════════════════════════════════

SackPlan _planLostWeight(SackRequest request) {
  final StoredSack stored = request.stored!;
  final SackWeightExplanation explanation = explainSackWeight(
    weights: stored.weights,
    lines: stored.lines,
    lostWeightConfirmed: true,
  );

  // ⛔★ **وتأكيدٌ بلا متبقٍّ ليس تأكيداً** — ⟵ **فجونيةٌ مفسَّرة بالكامل
  //    لا وزنَ ضائعَ فيها**، ⛔ **ولا يُكتب وسمٌ كاذب** (`BR-M7-12`).
  if (explanation.state != SackWeightState.lostConfirmed) {
    // ⛔★ **ولا رمزَ كتالوجٍ له عمداً:** الزرّ **لا يُعرَض أصلاً بلا
    //    متبقٍّ** (`FR-M7-19`)، ⟵ **فبلوغُ هذا السطر خللُ عميلٍ لا قاعدةُ
    //    عملٍ خالفها مستخدم** — ★ **واختراعُ رسالةٍ له يخالف §3 القاعدة 5.**
    return const SackRejected(CallableError.invalidArgument);
  }

  final Map<String, Object?> after = <String, Object?>{
    ..._explanationFields(explanation),
    'lostWeightNote': ?_trimmed(request.lostWeightNote),
  };

  return _accepted(
    request: request,
    stored: stored,
    writes: <InventoryWrite>[_partialWrite(request, after, null)],
    after: after,
    reason: null,
    // ★★★ **فعلٌ مستقل في المعجم لا «تعديل»** — `audit-log-design.md` §3
    //    يُفرد «**تأكيد وزن ضائع**» بسطره. ⚠️ **وكان يحسم تعارضاً سقط اليوم**
    //    (`AuditEntry.requiresReason` قبل `ADR-0020`) — ★ **ويبقى الفعل
    //    مستقلاً لأنه الصحيح وصفاً**، ⛔ **لا التفافاً على حارسٍ لم يعد.**
    action: AuditAction.lostWeightConfirm,
  );
}

// ═════════════════════════════════════════════════════════════════════════
// وزن السكرب — ⚙️ **ويُعيد توليد سطر المخزون**
// ═════════════════════════════════════════════════════════════════════════

/// ⛔★★ **و[reason] صار `String?` بـ`ADR-0020`** — ★ **وكانت `!` عليه
/// آمنةً بحارسٍ حُذف**، ⟵ **فلولا تليينُ التوقيع لأسقط المسارَ كلَّه.**
SackPlan _planScrapWeight(SackRequest request, String? reason) {
  final StoredSack stored = request.stored!;
  final WeightKg? scrapWeight = request.scrapWeight;
  if (scrapWeight == null) {
    return const SackRejected(CallableError.invalidArgument);
  }

  // ★★ **والأوزان تُعاد فحصاً كاملاً** — ⟵ **فسكربٌ يبتلع المطالب به
  //    يُرفَض هنا كما يُرفَض عند الإنشاء** (`FR-M7-07`).
  final Outcome<ValidatedSackWeights> weights = validateSackWeights(
    SackWeightsInput(
      totalWeight: stored.weights.totalWeight,
      iceWeight: stored.weights.iceWeight,
      scrapWeight: scrapWeight,
    ),
  );
  if (weights is Failure<ValidatedSackWeights>) {
    return const SackRejected(CallableError.sackWeightsIllogical);
  }
  final ValidatedSackWeights checked =
      (weights as Success<ValidatedSackWeights>).value;

  final Outcome<List<InventoryWrite>> scrap = _scrapWrites(
    request: request,
    weights: checked,
    dailySequence: stored.dailySequence,
    supplierName: stored.supplierName,
    isCreate: false,
    reason: reason,
  );
  if (scrap case Failure<List<InventoryWrite>>(:final AppError error)) {
    return SackRejected(
      _mapStockError(error, SackOperation.enterSackScrapWeight),
    );
  }

  final SackWeightExplanation explanation = explainSackWeight(
    weights: checked,
    lines: stored.lines,
    lostWeightConfirmed: stored.lostWeightConfirmed,
  );
  // ⑥ ★★ **وتقليصُ المطالب به قد يجعل السطور تتجاوزه** — ⟵ **فيُرفَض.**
  if (explanation.remainingWeight.kilograms < -weightEpsilonKg) {
    return const SackRejected(CallableError.sackWeightExceeded);
  }

  final Map<String, Object?> after = <String, Object?>{
    'scrapWeight': DecimalValue(checked.scrapWeight.kilograms),
    ..._explanationFields(explanation),
    'scrapItemKey': _scrapKeyOf(
      checked,
      stored.dailySequence,
      stored.supplierName,
    ),
  };

  return _accepted(
    request: request,
    stored: stored,
    writes: <InventoryWrite>[
      _partialWrite(request, after, reason),
      ...(scrap as Success<List<InventoryWrite>>).value,
    ],
    after: after,
    reason: reason,
  );
}

// ═════════════════════════════════════════════════════════════════════════
// التعديل الشامل — ★ **الرأس والسطور معاً** (`FR-M7-26`)
// ═════════════════════════════════════════════════════════════════════════

/// ⛔★★ **و[reason] صار `String?` بـ`ADR-0020`** — ★ **وكانت `!` عليه
/// آمنةً بحارسٍ حُذف**، ⟵ **فلولا تليينُ التوقيع لأسقط المسارَ كلَّه.**
SackPlan _planFullAmend(SackRequest request, String? reason) {
  final StoredSack stored = request.stored!;
  final ValidatedSackIntake? intake = request.intake;
  if (intake == null || intake.sourceId != request.sourceId) {
    return const SackRejected(CallableError.invalidArgument);
  }

  // ⛔★★★ **والرقم المتسلسل واسم الرعوي المُجمَّد لا يتغيّران** — ⟵ **فمفاتيح
  //    الرصيد تبقى مصيبةً سجلاتِها**، ★ **والتعديل يقع على الحركة نفسها.**
  final String? supplierName = stored.supplierName;

  final List<InventoryWrite> writes = <InventoryWrite>[];

  final Outcome<List<InventoryWrite>> scrap = _scrapWrites(
    request: request,
    weights: intake.weights,
    dailySequence: stored.dailySequence,
    supplierName: supplierName,
    isCreate: false,
    reason: reason,
  );
  if (scrap case Failure<List<InventoryWrite>>(:final AppError error)) {
    return SackRejected(_mapStockError(error, SackOperation.amendSack));
  }
  writes.addAll((scrap as Success<List<InventoryWrite>>).value);

  final Outcome<List<InventoryWrite>> lines = _lineWrites(
    request: request,
    stored: StoredSack(
      sourceId: stored.sourceId,
      stockDate: stored.stockDate,
      dailySequence: stored.dailySequence,
      displayName: stored.displayName,
      weights: intake.weights,
      lines: stored.lines,
      status: stored.status,
      lostWeightConfirmed: stored.lostWeightConfirmed,
      supplierId: stored.supplierId,
      supplierName: supplierName,
      scrapItemKey: stored.scrapItemKey,
    ),
    lines: intake.lines,
    reason: reason,
    isCreate: false,
  );
  if (lines case Failure<List<InventoryWrite>>(:final AppError error)) {
    return SackRejected(_mapStockError(error, SackOperation.amendSack));
  }
  writes.addAll((lines as Success<List<InventoryWrite>>).value);

  final SackWeightExplanation explanation = explainSackWeight(
    weights: intake.weights,
    lines: intake.lines,
    lostWeightConfirmed: intake.lostWeightConfirmed,
  );
  if (explanation.remainingWeight.kilograms < -weightEpsilonKg) {
    return const SackRejected(CallableError.sackWeightExceeded);
  }

  final Map<String, Object?> after = _documentFields(
    request: request,
    intake: intake,
    dailySequence: stored.dailySequence,
    displayName: stored.displayName,
    supplierName: supplierName,
    scrapItemKey:
        _scrapKeyOf(intake.weights, stored.dailySequence, supplierName),
  );

  writes.insert(0, _partialWrite(request, after, reason));

  return _accepted(
    request: request,
    stored: stored,
    writes: writes,
    after: after,
    reason: reason,
  );
}

// ═════════════════════════════════════════════════════════════════════════
// الإلغاء — ★ **بالوسم** ⛔ **بلا حركة عكسية ولا حذف** (`GR-06` · `GR-07`)
// ═════════════════════════════════════════════════════════════════════════

/// ⛔★★ **و[reason] صار `String?` بـ`ADR-0020`** — ★ **وكانت `!` عليه
/// آمنةً بحارسٍ حُذف**، ⟵ **فلولا تليينُ التوقيع لأسقط المسارَ كلَّه.**
SackPlan _planCancellation(SackRequest request, String? reason) {
  final StoredSack stored = request.stored!;
  final List<InventoryWrite> writes = <InventoryWrite>[];

  for (final String itemKey in request.ledger.keys.toList()..sort()) {
    final Outcome<List<InventoryWrite>> planned = _movementWrites(
      request: request,
      itemKey: itemKey,
      itemName: itemKey,
      unit: _unitOfLedger(request, itemKey),
      // ⛔ **لا كمية باقية** — كل حركات المستند تُوسَم ملغاة.
      desired: null,
      isCreate: false,
      reason: reason,
      cancelOwn: true,
    );
    if (planned case Failure<List<InventoryWrite>>(:final AppError error)) {
      return SackRejected(_mapStockError(error, SackOperation.cancelSack));
    }
    writes.addAll((planned as Success<List<InventoryWrite>>).value);
  }

  final Map<String, Object?> fields = <String, Object?>{
    'status': SackStatus.cancelled.name,
    'cancelReason': reason,
    'cancelledBy': request.actor.userId,
  };
  writes.insert(
    0,
    InventoryWrite(
      collectionId: sacksCollection,
      documentId: request.documentNumber,
      fields: fields,
      // ★ **قناعٌ ضيّق** — ⛔ **فلا يمحو الإلغاءُ سطوراً ولا أوزاناً.**
      updateMask: fields.keys.toList(),
      serverTimestampFields: const <String>['cancelledAt'],
    ),
  );

  return SackAccepted(
    documentNumber: request.documentNumber,
    writes: writes,
    entry: _entry(
      request: request,
      // ★ **الإلغاء فعلٌ مستقل في المعجم لا «تعديل»**.
      action: AuditAction.cancel,
      reason: reason,
      valuesBefore: <String, Object?>{'status': stored.status.name},
      valuesAfter: <String, Object?>{'status': SackStatus.cancelled.name},
    ),
  );
}

// ═════════════════════════════════════════════════════════════════════════
// حركات الدفتر — ★★ **وتُعيد بناء الرصيد من الدفتر** ⛔ **لا تُراكم**
// ═════════════════════════════════════════════════════════════════════════

/// ★★ كتابات السطور — **الجديدة والمحذوفة من التعديل معاً**.
///
/// ⚠️⚠️ **والمفتاح هو الاسم المركّب لا معرّف النوع** (`ADR-0007`) — ⟵ **وهو
/// ما يجعل كل حبة قابلة للردّ إلى جونيتها ورعويها**، ★ **وعليه يُبنى سعر
/// الجونية إيراداً فعلياً** (`A-13`).
Outcome<List<InventoryWrite>> _lineWrites({
  required SackRequest request,
  required StoredSack stored,
  required List<ValidatedSackLine> lines,
  required String? reason,
  required bool isCreate,
}) {
  final Map<String, ValidatedSackLine> desired = <String, ValidatedSackLine>{
    for (final ValidatedSackLine line in lines)
      line.itemKeyIn(
        dailySequence: stored.dailySequence,
        supplierName: stored.supplierName,
      ): line,
  };

  // ★★ **كل مفتاحٍ يلمسه هذا المستند** — ⟵ **والمحذوف من التعديل يُوسَم
  //    ملغى**، ⛔ **ولا يبقى رصيدُه معلّقاً بلا مستندٍ يفسّره.**
  final Set<String> touched = <String>{
    ...desired.keys,
    ...request.ledger.keys.where(
      (String key) => key != stored.scrapItemKey,
    ),
  };

  final List<InventoryWrite> writes = <InventoryWrite>[];
  for (final String itemKey in touched.toList()..sort()) {
    final ValidatedSackLine? line = desired[itemKey];
    final Outcome<List<InventoryWrite>> planned = _movementWrites(
      request: request,
      itemKey: itemKey,
      itemName: line?.itemName ?? itemKey,
      unit: line?.unit ?? _unitOfLedger(request, itemKey),
      desired: line?.stockQuantity,
      isCreate: isCreate,
      reason: reason,
      lineTotalWeight: line?.lineTotalWeight,
      pieceWeightGrams: line?.pieceWeightGrams,
    );
    if (planned case Failure<List<InventoryWrite>>(:final AppError error)) {
      return Failure<List<InventoryWrite>>(error);
    }
    writes.addAll((planned as Success<List<InventoryWrite>>).value);
  }
  return Success<List<InventoryWrite>>(writes);
}

/// ⚙️★★★ **كتابات السكرب** — `FR-M7-09` · `AT-07` · `E-06`.
///
/// ⛔★★ **وصفرُ السكرب يَسِم حركته ملغاةً ولا يحذفها** — ★ **فتخفيضُه إلى
/// صفرٍ بعد إدخاله يجب أن يُخرِج وزنه من الرصيد**، ⟵ **والحذف ممنوع**
/// (`GR-07`)، **فالوسم هو المخرج الوحيد.**
Outcome<List<InventoryWrite>> _scrapWrites({
  required SackRequest request,
  required ValidatedSackWeights weights,
  required int dailySequence,
  required String? supplierName,
  required bool isCreate,
  required String? reason,
}) {
  final String? scrapItemId = _trimmed(request.scrapItemId);
  final SackScrapLine? scrap = scrapItemId == null
      ? null
      : buildSackScrapLine(
          scrapItemId: scrapItemId,
          scrapWeight: weights.scrapWeight,
          dailySequence: dailySequence,
          supplierName: supplierName,
        );

  // ★ **مفتاحُ السكرب القائم** — ⟵ **ليُوسَم ملغىً إن صار وزنه صفراً.**
  final String? existingKey = request.stored?.scrapItemKey;
  final String? key = scrap?.itemKey ?? existingKey;
  if (key == null) {
    // ★ **لا سكربَ الآن ولا سابقاً** — ⟵ **فلا حركة ولا سجل رصيد**
    //   (`ADR-0008` القاعدة 5).
    return const Success<List<InventoryWrite>>(<InventoryWrite>[]);
  }

  return _movementWrites(
    request: request,
    itemKey: key,
    itemName: key,
    unit: ItemUnit.kilogram,
    desired: scrap?.stockQuantity,
    isCreate: isCreate,
    reason: reason,
    lineTotalWeight: scrap?.weight,
    isScrap: true,
  );
}

/// ★★★ **جوهر الزيادة:** يبني الحركة **ويُعيد بناء رصيدها من الدفتر**.
///
/// ⚠️⚠️ **والرصيد يُجمَع ⛔ لا يُراكَم على قيمةٍ سابقة** —
/// `coding-standards.md` §2.7: «**تُعيد البناء من الدفتر بالكامل**».
/// ⟵ ★ **فإعادة إرسال الطلب نفسه تُنتج الرقم نفسه.**
Outcome<List<InventoryWrite>> _movementWrites({
  required SackRequest request,
  required String itemKey,
  required String itemName,
  required ItemUnit unit,
  required StockQuantity? desired,
  required bool isCreate,
  required String? reason,
  WeightKg? lineTotalWeight,
  double? pieceWeightGrams,
  bool cancelOwn = false,
  bool isScrap = false,
}) {
  final String movementId = stockMovementId(
    documentNumber: request.documentNumber,
    itemKey: itemKey,
  );
  final List<LedgerRead> reads = request.ledger[itemKey] ?? const <LedgerRead>[];

  // ★ **حركات غيري** — ⟵ **فالتعديل يستبدل حركتي لا يُراكم عليها.**
  final List<StockMovement> others = <StockMovement>[
    for (final LedgerRead read in reads)
      if (read.movementId != movementId) read.movement,
  ];

  final bool isCancelled = cancelOwn || desired == null;
  final StockQuantity quantity =
      desired ?? _existingQuantity(reads, movementId, unit);

  final List<StockMovement> projected = <StockMovement>[
    ...others,
    StockMovement(
      itemKey: itemKey,
      direction: MovementDirection.incoming,
      quantity: quantity,
      isCancelled: isCancelled,
    ),
  ];

  final Outcome<ItemDailyFlow> flow =
      computeItemDailyFlow(movements: projected, unit: unit);
  if (flow case Failure<ItemDailyFlow>(:final AppError error)) {
    return Failure<List<InventoryWrite>>(error);
  }
  final ItemDailyFlow computed = (flow as Success<ItemDailyFlow>).value;

  // ⑥ ★★ **منع الرصيد السالب** — `FR-M8-01` · `GR-11`.
  final Outcome<void> allowed = validateNonNegativeBalance(computed.balance);
  if (allowed case Failure<void>(:final AppError error)) {
    return Failure<List<InventoryWrite>>(error);
  }

  final Map<String, Object?> movement = <String, Object?>{
    'sourceId': request.sourceId,
    // ★ **تاريخ المخزون** — ⛔ **وعليه وحده تُبنى الاستعلامات** (`RISK-07`).
    'stockDate': request.stockDate.asUtcMidnight(),
    'itemKey': itemKey,
    'itemName': itemName,
    'unit': unit.name,
    'direction': MovementDirection.incoming.name,
    'quantity': _quantityValue(quantity),
    'balanceAfter': _quantityValue(computed.balance),
    'sourceDocType': SourceDocumentType.sack.name,
    'sourceDocId': request.documentNumber,
    'sourceDocNumber': request.documentNumber,
    'movementTag': MovementTag.normal.name,
    'isCancelled': isCancelled,
    // ★★★ **و`sackId` حاضرٌ هنا بخلاف الوارد عدداً** — `ADR-0007` القاعدة 5:
    //    ⟵ **وهو أساس فهرس «تفكيك سعر الجونية»** (`BR-M6-10` بالمقابل).
    'sackId': request.documentNumber,
    // ★ **بيانٌ تفسيري للتدقيق** — ⛔ **ولا يدخل أي جمع رصيد** (`GR-19`).
    if (lineTotalWeight != null)
      'lineTotalWeight': DecimalValue(lineTotalWeight.kilograms),
    if (pieceWeightGrams != null)
      'pieceWeightGrams': DecimalValue(pieceWeightGrams),
    if (isScrap) 'isScrapLine': true,
    if (!isCreate) 'amendedBy': request.actor.userId,
    if (!isCreate && reason != null) 'amendReason': reason,
  };

  final Map<String, Object?> balance = <String, Object?>{
    'sourceId': request.sourceId,
    'itemKey': itemKey,
    'itemName': itemName,
    'stockDate': request.stockDate.asUtcMidnight(),
    'unit': unit.name,
    'incoming': _quantityValue(computed.incoming),
    'outgoing': _quantityValue(computed.outgoing),
    'balance': _quantityValue(computed.balance),
  };

  return Success<List<InventoryWrite>>(<InventoryWrite>[
    InventoryWrite(
      collectionId: inventoryLedgerCollection,
      documentId: movementId,
      fields: movement,
      updateMask: movement.keys.toList(),
      // ④ ⛅ **وقت المنصّة**.
      serverTimestampFields: isCreate
          ? const <String>['entryDate']
          : const <String>['lastAmendedAt'],
    ),
    InventoryWrite(
      collectionId: itemDailyBalancesCollection,
      documentId: itemDailyBalanceId(
        sourceId: request.sourceId,
        itemKey: itemKey,
        stockDate: request.stockDate,
      ),
      fields: balance,
      updateMask: balance.keys.toList(),
      serverTimestampFields: const <String>['updatedAt'],
    ),
  ]);
}

/// كمية الحركة القائمة — ★ **تُستعمل عند الإلغاء وحده**.
StockQuantity _existingQuantity(
  List<LedgerRead> reads,
  String movementId,
  ItemUnit unit,
) {
  for (final LedgerRead read in reads) {
    if (read.movementId == movementId) return read.movement.quantity;
  }
  return StockQuantity.zeroOf(unit);
}

/// ★ وحدة المفتاح كما قُرئت من الدفتر — ⛔ **والمجهول حبّة**.
///
/// ⚠️ **ولا تُستنتَج من سجل نوع:** المفتاح هنا **اسمٌ مركّب لا معرّف نوع**،
/// ⟵ **فلا سجل يحمله**، ★ **ووحدتُه في حركاته القائمة وحدها.**
ItemUnit _unitOfLedger(SackRequest request, String itemKey) {
  final List<LedgerRead>? reads = request.ledger[itemKey];
  if (reads == null || reads.isEmpty) return ItemUnit.piece;
  return reads.first.movement.quantity.unit;
}

/// ★ قيمة الكمية كما تُكتب — **صحيحٌ للحبّة، وعشريٌّ مُصرَّحٌ به للوزن**.
///
/// ★★ **وهذا هو موضع حسم ما تركه `WU-003` مفتوحاً:** المُرمِّز كان **يرمي
/// على الوزن** حتى يُحسَم تمثيلُه بقرار موثَّق، ⟵ **والقرار مكتوبٌ سلفاً**
/// في `data-dictionary.md` §الوحدات و`ADR-0015` **القاعدة 9**، ★ **فمرّ
/// الوزن عبر [DecimalValue] المُصرِّح** ⛔ **وبقي `double` المجرَّد مرفوضاً.**
Object _quantityValue(StockQuantity quantity) => switch (quantity) {
      PieceQuantity(:final PieceCount count) => count.pieces,
      WeightQuantity(:final WeightKg weight) => DecimalValue(weight.kilograms),
    };

// ═════════════════════════════════════════════════════════════════════════
// حقول المستند
// ═════════════════════════════════════════════════════════════════════════

Map<String, Object?> _documentFields({
  required SackRequest request,
  required ValidatedSackIntake intake,
  required int dailySequence,
  required String displayName,
  required String? supplierName,
  required String? scrapItemKey,
}) =>
    <String, Object?>{
      'documentNumber': request.documentNumber,
      'sourceId': intake.sourceId,
      if (_nameOf(request.storedSource) case final String sourceName)
        'sourceName': sourceName,
      // ③ ★★ **تاريخ المخزون من الخادم** — `FR-M7-02` · `BR-M7-02`.
      'stockDate': request.stockDate.asUtcMidnight(),
      // ⛅★★ **الرقم المتسلسل من السحابة** — ⛔ **ولا يتغيّر أبداً**.
      'dailySequence': dailySequence,
      'displayName': displayName,
      if (intake.supplierId case final String supplierId)
        'supplierId': supplierId,
      // ★ **نسخةٌ مُجمَّدة** — `ADR-0007` القاعدة 4.
      if (supplierName case final String name) 'supplierName': name,
      // ★★ **الأوزان عشرية مُصرَّحٌ بها** — `ADR-0015` القاعدة 9.
      'totalWeight': DecimalValue(intake.weights.totalWeight.kilograms),
      'iceWeight': DecimalValue(intake.weights.iceWeight.kilograms),
      'scrapWeight': DecimalValue(intake.weights.scrapWeight.kilograms),
      ..._explanationFields(intake.explanation),
      if (scrapItemKey case final String key) 'scrapItemKey': key,
      if (intake.lostWeightNote case final String note) 'lostWeightNote': note,
      if (intake.notes case final String notes) 'notes': notes,
      'lines': _lineMaps(intake.lines),
      'totalQuantity': intake.totalPieces.pieces,
      'isPricingComplete': intake.isPricingComplete,
      'status': SackStatus.approved.name,
      // ⛔★★★ **ولا حقل مالي واحد** — `ADR-0011`: **الضريبة والسعر والصافي
      //    في `finance/current` وحدها**، ⟵ **ووجودُها هنا تسريبٌ لكل من
      //    يقرأ المستند** لأن القاعدة تمنحه كاملاً.
    };

/// ★ حقول الحاسبة — **مصدرها [SackWeightExplanation] وحده**.
///
/// ⛔ **ولا يُعاد حسابُ أيٍّ منها هنا** (`coding-standards.md` §2.2).
Map<String, Object?> _explanationFields(SackWeightExplanation explanation) =>
    <String, Object?>{
      'claimableWeight': DecimalValue(explanation.claimableWeight.kilograms),
      'remainingWeight': DecimalValue(explanation.remainingWeight.kilograms),
      'lostWeight': DecimalValue(explanation.lostWeight.kilograms),
      'lostWeightConfirmed':
          explanation.state == SackWeightState.lostConfirmed,
    };

List<Object?> _lineMaps(List<ValidatedSackLine> lines) => <Object?>[
      for (final ValidatedSackLine line in lines)
        <String, Object?>{
          'itemId': line.itemId,
          'itemName': line.itemName,
          'nature': line.nature.name,
          'unit': line.unit.name,
          'quantity': line.quantity.pieces,
          'pieceWeightGrams': DecimalValue(line.pieceWeightGrams),
          // ★★ **مصدر الرقم للتدقيق** — `sack-intake-design.md` §4.
          'pieceWeightOrigin': line.pieceWeightOrigin.name,
          'lineTotalWeight': DecimalValue(line.lineTotalWeight.kilograms),
          if (line.distributionPrice case final Money price)
            'distributionPrice': price.riyals,
          if (line.minCashPrice case final Money price)
            'minCashPrice': price.riyals,
          if (line.note case final String note) 'note': note,
        },
    ];

int _piecesOf(List<ValidatedSackLine> lines) {
  int total = 0;
  for (final ValidatedSackLine line in lines) {
    if (line.unit == ItemUnit.piece) total += line.quantity.pieces;
  }
  return total;
}

String? _scrapKeyOf(
  ValidatedSackWeights weights,
  int dailySequence,
  String? supplierName,
) =>
    weights.scrapWeight.kilograms <= 0
        ? null
        : sackScrapCompositeName(
            dailySequence: dailySequence,
            supplierName: supplierName,
          );

bool _hasStoredLines(StoredSack stored) => stored.lines.isNotEmpty;

/// ★ كتابةٌ جزئية على مستند الجونية — **بقناعٍ ضيّق** (`FR-M7-27`).
///
/// ★★★ **و[isFirstEntry] يمنع وسمَ التعبئة الأولى تعديلاً** (`IQ-025` ·
/// `ADR-0018`): ⛔ **فلا `amendCount` ولا `amendedBy` ولا `lastAmendedAt`**
/// على مستندٍ **يُملأ حقلُه المؤجَّل أوّلَ مرة** — ★ **والقيدُ وحده يحمل
/// من فعلَ ومتى**، تماماً كما يفعل الإنشاء نفسه.
InventoryWrite _partialWrite(
  SackRequest request,
  Map<String, Object?> after,
  String? reason, {
  bool isFirstEntry = false,
}) {
  final Map<String, Object?> fields = isFirstEntry
      ? <String, Object?>{...after}
      : <String, Object?>{
          ...after,
          'amendedBy': request.actor.userId,
          // ★★ **والسبب اختياريٌّ في مسارَي التعبئة المؤجَّلة** (`ADR-0018`)
          //    ⛔ **وإلزاميٌّ فيما عداهما** — `planSack` ⑤ هو الحارس.
          'amendReason': ?reason,
          'amendCount': (request.stored?.amendCount ?? 0) + 1,
        };
  return InventoryWrite(
    collectionId: sacksCollection,
    documentId: request.documentNumber,
    fields: fields,
    // ⛔⛔★★★ **و`amendReason` يبقى في القناع ولو غاب** (`DEBT-39`) —
    //    ⟵ **فتعديلٌ لاحقٌ بلا سبب يمحو سببَ تعديلٍ سابق** بدل أن يتركه
    //    عالقاً على تعديلٍ ليس سببَه. ⚠️⚠️ **ورُصد حيّاً على المحاكي:**
    //    `SCK-20260826-0006` **حمل `amendCount: 3` و`amendedBy` جديدَين**
    //    ⛔ **و`amendReason` من التعديل الثاني** — ★ **وهو عينُ عطل
    //    `IQ-025`**: نصٌّ يقرؤه المدقّق سبباً لما ليس سببَه.
    //    ★ **والقيدُ يحفظ الأصل** — `audit_log` **لكل تعديلٍ قيدُه.**
    updateMask: <String>[
      ...fields.keys,
      if (!isFirstEntry && reason == null) 'amendReason',
    ],
    serverTimestampFields:
        isFirstEntry ? const <String>[] : const <String>['lastAmendedAt'],
  );
}

SackAccepted _accepted({
  required SackRequest request,
  required StoredSack stored,
  required List<InventoryWrite> writes,
  required Map<String, Object?> after,
  required String? reason,
  AuditAction action = AuditAction.amend,
}) =>
    SackAccepted(
      documentNumber: request.documentNumber,
      writes: writes,
      entry: _entry(
        request: request,
        action: action,
        reason: reason,
        valuesBefore: const <String, Object?>{},
        valuesAfter: after,
      ),
    );

// ═════════════════════════════════════════════════════════════════════════
// بوابات مشتركة
// ═════════════════════════════════════════════════════════════════════════

/// ★ يفحص أن المستند موجود عند التعديل وغائب عند الإنشاء.
SackRejected? _existenceGate(SackRequest request, SackOperation operation) {
  final StoredSack? stored = request.stored;
  if (operation.isCreate) {
    // ⛔ **إنشاءٌ فوق قائم يمحو مستنداً حياً** — وهو أخطر ما يفعله كودٌ محاسبي.
    return stored == null
        ? null
        : const SackRejected(CallableError.invalidArgument);
  }
  if (stored == null) {
    return const SackRejected(CallableError.invalidArgument);
  }
  // ★★★ **والمصدر المخزَّن هو الحَكَم لا المُرسَل** — ⟵ **وإلا أمكن فحصُ
  //   النطاق على مصدرٍ ثم العملُ على مستند مصدرٍ آخر**، ⛔ **وهو تصعيدُ
  //   امتيازٍ صامت** (`GR-23`).
  if (stored.sourceId != request.sourceId) {
    return const SackRejected(CallableError.sourceOutOfScope);
  }
  // ★★★ **وتاريخ المخزون المخزَّن هو الحَكَم** — ⛔ **ورصيدٌ جُمع ليومٍ آخر
  //   يُنتج ملخصاً كاذباً بصمت** (`RISK-07`).
  if (stored.stockDate != request.stockDate) {
    return const SackRejected(CallableError.invalidArgument);
  }
  // ★★ **والملغاة لا تُعدَّل ولا تُلغى ثانيةً** — `ERR_AMEND_006`.
  final Outcome<void> live = validateSackNotCancelled(stored.status);
  return live is Failure<void>
      ? const SackRejected(CallableError.documentCancelled)
      : null;
}

/// ★ يفحص سجل المصدر — **موجودٌ ونشط** (`ERR_DIST_003`).
SackRejected? _sourceGate(SackRequest request, SackOperation operation) {
  final Map<String, Object?>? source = request.storedSource;
  // ⛔ **مصدرٌ لم يُقرأ ⟵ رفض** — الرفض الافتراضي.
  if (source == null) {
    return const SackRejected(CallableError.internal);
  }
  // ★ **والإلغاء مسموح على مصدرٍ عُطِّل** — ⟵ **فتعطيلُ مصدرٍ لا يحبس
  //   مستنداته الخاطئة داخله**؛ ⛔ **والمنع على التوريد الجديد وحده.**
  if (!operation.isCancel && source['isActive'] == false) {
    return const SackRejected(CallableError.sourceInactive);
  }
  return null;
}

/// ★ يفحص الرعوي — **مرتبطٌ بالمصدر** (`FR-M3-09`).
SackRejected? _supplierGate(SackRequest request, String? supplierId) {
  if (supplierId == null) return null;
  final List<String>? sources = request.storedSupplierSourceIds;
  // ⛔ **رعويٌّ لم يُقرأ أو لا ينتمي للمصدر ⟵ رفض** — `FR-M3-09`.
  if (sources == null || !sources.contains(request.sourceId)) {
    return const SackRejected(CallableError.supplierRequired);
  }
  return null;
}

/// ★ يُترجم خطأ النطاق إلى رمز الكتالوج **بحسب الفعل المطلوب**.
CallableError _mapStockError(AppError error, SackOperation operation) =>
    switch (error) {
      InsufficientStockError() when operation == SackOperation.amendSack =>
        CallableError.amendReducesBelowIssued,
      InsufficientStockError() => CallableError.insufficientStock,
      ValidationError(ruleCode: 'GR-19') => CallableError.itemUnitLocked,
      ValidationError(ruleCode: 'BR-M7-07') =>
        CallableError.sackWeightsIllogical,
      ValidationError(ruleCode: 'BR-M7-08') => CallableError.sackWeightExceeded,
      ValidationError(ruleCode: 'E-08') => CallableError.pieceWeightMissing,
      ValidationError(ruleCode: 'FR-M7-06') =>
        CallableError.sackWeightsIllogical,
      ValidationError(ruleCode: 'E-09') ||
      ValidationError(ruleCode: 'FR-M7-13') =>
        CallableError.countedLineNeedsTotalWeight,
      ValidationError(ruleCode: 'BR-M7-17') =>
        CallableError.itemAlreadyInDocument,
      ValidationError(ruleCode: 'BR-M7-03') => CallableError.supplierRequired,
      _ => CallableError.invalidArgument,
    };

/// ★★ يُترجم رفض طبقة النطاق عند فحص المستند كاملاً — **للمعالج**.
///
/// ⚠️ **ومُصدَّرة لأن الفحص يقع في المعالج قبل التخطيط** — ⟵ **فالرمز
/// الصحيح يجب أن يصل المستخدمَ من هناك أيضاً**، ⛔ **لا رمزٌ جامع.**
CallableError sackValidationError(AppError error) =>
    _mapStockError(error, SackOperation.createSack);

// ═════════════════════════════════════════════════════════════════════════
// قيد التدقيق
// ═════════════════════════════════════════════════════════════════════════

AuditEntry _entry({
  required SackRequest request,
  required AuditAction action,
  required String? reason,
  required Map<String, Object?> valuesBefore,
  required Map<String, Object?> valuesAfter,
}) =>
    AuditEntry(
      id: request.requestId.trim(),
      // ⚠️ قيمة مبدئية لا تُكتب — الكاتب يستبدلها بوقت المنصة.
      occurredAt: DateTime.utc(1970),
      actor: AuditActor(
        userId: request.actor.userId,
        userName: request.actor.userName,
      ),
      action: action,
      reason: reason,
      target: AuditTarget(
        entityType: sackEntityType,
        entityId: request.documentNumber,
        // ★ **المصدر في القيد** — ⟵ **فيُفلتَر السجل بالنطاق** (`FR-M18-14`).
        sourceId: request.sourceId,
      ),
      // ⛔⛔★★★ **ولا تُسطَّح القيم هنا — `DEBT-35`:** كان القيد يُسطِّح
      //    [DecimalValue] إلى `double` خام، ⟵ **ثم يُرمِّزه `_auditWrite`
      //    فيرفضه المُرمِّز** (`ADR-0015`) ⟹ ⛔ **كلُّ إنشاء جونية كان يسقط
      //    بـ`500` خام.** ★ **والتسطيحُ لم يكن يُنجز شيئاً أصلاً:**
      //    [DecimalValue] **تُخزَّن `doubleValue` في القاعدة** — ⟵ **فالقيد
      //    يُقرأ رقماً عادياً في الحالتين**، ★ **والغايةُ المكتوبة («لا يحمل
      //    أنواعَ ترميزٍ داخلية») متحققةٌ في المخزَّن لا في نوع الوسيط.**
      valuesBefore: valuesBefore,
      valuesAfter: valuesAfter,
      deviceInfo: request.deviceInfo,
    );

/// ★ اسم المستند المقروء أو `null` — ⛔ **والفارغ غيابٌ لا نصٌّ فارغ**.
String? _nameOf(Map<String, Object?>? stored) {
  final Object? name = stored?['name'];
  return (name is String && name.trim().isNotEmpty) ? name.trim() : null;
}

/// 🔒 **مسار المجموعة الفرعية للمالية** — `sacks/{id}/finance` (`ADR-0011`).
///
/// ⚠️ **ويُبنى من ثابتَي النطاق لا من نصٍّ محفور** — ⟵ **فتغيّرُ أيٍّ منهما
/// يسري على الكاتب والقارئ معاً**، ⛔ **ولا مسارٌ ثانٍ يفترق عنه.**
String sackFinancePathOf(String documentNumber) =>
    '$sacksCollection/$documentNumber/$sackFinanceSubcollection';

String? _trimmed(String? value) {
  final String? text = value?.trim();
  return (text == null || text.isEmpty) ? null : text;
}

/// كتالوج الرسائل المعروضة — ★ **نقلٌ حرفي، ⛔ ولا صياغة جديدة.**
///
/// ★★ **المصدر المُلزِم بعد حسم `IQ-016` (2026-08-24):**
/// `05-api/error-codes-catalog.md` §2 — **وهو مرجع نصّ العرض المعتمد**،
/// و`error-handling-strategy.md` §4 (**STATIC**) مرجعٌ تاريخي لأسلوب
/// الصياغة. ⟵ ★ **فمرجعٌ واحد لا اثنان يتنازعان** (سُدِّد به `DEBT-13`).
///
/// ★ **والقاعدة التي يفرضها هذا الملف بوجوده:** §3 القاعدة 2 — «**لا يُعرَض
/// رمز تقني للمستخدم — الرسالة من الكتالوج حصراً**». ⟵ **فلا `String` عربي
/// معروض في أي شاشة خارج هذا الملف.**
library;

import 'package:qtms_domain/qtms_domain.dart';

/// الرسائل المعتمدة التي يستهلكها هذا الإصدار.
///
/// ⚠️ **ولا تُضاف رسالة هنا بلا سطر في الكتالوج** — والإضافة الصامتة هي
/// بالضبط ما يمنعه `DEBT-13`.
enum CatalogMessageId {
  /// `ERR_AUTH_003`.
  sessionExpired,

  /// `ERR_AUTH_004`.
  accountDisabled,

  /// `ERR_AUTH_005`.
  temporaryLock,

  /// `ERR_CONN_001`.
  noConnection,

  /// `ERR_CONN_002`.
  platformUnavailable,

  /// ★ `ERR_AUTH_008` — **بيانات دخول غير صحيحة** (`IQ-016`).
  invalidCredentials,

  /// ★ `ERR_AUTH_009` — **فشل دخول غير متوقَّع** (`IQ-016`).
  unexpectedSignInFailure,

  /// `ERR_AUTH_001` — صلاحية مفقودة.
  permissionMissing,

  /// `ERR_AUTH_007` — منح صلاحية لا يملكها المُنفِّذ (`BR-M1-03`).
  grantBeyondActor,

  /// `ERR_AMEND_002` — ★★ **سبب التعديل مفقود** (`ADR-0004` · `DEBT-21` ①).
  amendReasonMissing,

  /// `ERR_SETUP_011` — ★ بريد مستخدم مكرر (`FR-M1-01`).
  emailAlreadyExists,

  /// ★★ `ERR_SETUP_012` — **حذف دور مُسنَد** (`FR-M1-03` · `IQ-018`).
  roleAssigned,

  // ── البيانات المرجعية (`WU-002`) — الكتالوج §2.4 ──

  /// `ERR_SETUP_001` — رقم رعوي مكرر (`FR-M3-02`).
  supplierPhoneExists,

  /// `ERR_SETUP_002` — رقم مقوت مكرر (`FR-M4-02`).
  dealerPhoneExists,

  /// `ERR_SETUP_003` — اسم نوع مكرر (`FR-M5-01`).
  itemNameExists,

  /// `ERR_SETUP_004` — اسم مصدر مكرر (`FR-M2-01`).
  sourceNameExists,

  /// `ERR_SETUP_006` — ★ تعطيل مقوت له رصيد (`FR-M4-09` · `E-39`).
  dealerBalanceBlocksDisable,

  /// `ERR_SETUP_008` — ★★ تعديل النوع الافتراضي «السكرب» (`FR-M5-05`).
  systemDefaultItem,

  /// `ERR_SETUP_009` — ★★ تغيير وحدة نوع (`FR-M5-04` · `GR-19`).
  itemUnitLocked,

  /// `ERR_SETUP_010` — ★★ كتابة الإعداد التأسيسي مرتين (`FR-M21-03` · `AT-65`).
  appSettingsAlreadyWritten,

  /// `ERR_CONC_001` — تعارض تزامن.
  concurrencyConflict,

  // ── المخزون والتوريد (`WU-003`) — الكتالوج §2.6 و§2.7 و§2.11 ──
  //
  // ⛔★★ **ولا نصّ مُخترَع واحد:** كلها **رموزٌ ونصوصٌ قائمة في الكتالوج**
  //    قبل هذه الزيادة — ★ **والزيادة تستهلكه ولا تُوسّعه** (§3 القاعدة 5).

  /// `ERR_AUTH_002` — ★★ **مصدر خارج النطاق** (`GR-23`).
  sourceOutOfScope,

  /// `ERR_INTAKE_001` — الرعوي مشروطٌ بالمصدر (`FR-M6-03`).
  supplierRequiredForSource,

  /// `ERR_INTAKE_008` — ★ نوع مكرر في المستند (`FR-M6-07`).
  itemAlreadyInDocument,

  /// `ERR_STOCK_001` — ★★ **الكمية غير كافية** (`E-01`).
  insufficientStock,

  /// `ERR_STOCK_002` — كسورٌ في كمية معدودة (`BR-M6-06`).
  fractionalCount,

  /// `ERR_AMEND_003` — ★★ تخفيضٌ لكمية صُرفت (`FR-M6-12`).
  amendReducesBelowIssued,

  /// `ERR_AMEND_004` — سبب الإلغاء مفقود (`FR-M6-13`).
  cancelReasonMissing,

  /// `ERR_AMEND_006` — ★ المستند ملغى (`A-14`).
  documentCancelled,

  /// `ERR_DIST_003` — المصدر معطَّل (`FR-M2-06`).
  sourceInactive,

  // ── التسعير اليومي (`WU-005`) — الكتالوج §`MONEY` ──

  /// ★ `ERR_MONEY_001` — **كسرٌ في مبلغ** (`ADR-0015` القاعدة 3).
  ///
  /// ⚠️ **ويُعرَض كذلك للسعر غير الموجب** — ★ **بنفس سابقة `BR-M6-06`**
  /// التي تُعرَض بـ`ERR_STOCK_002` للكسر **وللكمية غير الموجبة معاً**:
  /// ⟵ **الرسالتان تُرشدان لفعلٍ واحد** («اكتب رقماً صحيحاً صالحاً»)،
  /// ⛔ **واختراعُ رمزٍ ثالث يخالف `error-codes-catalog.md` §3 القاعدة 5**
  /// (**نصّ أي رسالة جديدة يعتمده صاحب المشروع صراحةً**).
  fractionalMoney,

  // ── الوارد جواني (`WU-004`) — الكتالوج §2.6 ──
  //
  // ⛔★★ **ولا نصّ مُخترَع واحد:** كلها **رموزٌ ونصوصٌ قائمة في الكتالوج**
  //    قبل هذه الزيادة — ★ **والزيادة تستهلكه ولا تُوسّعه** (§3 القاعدة 5).

  /// `ERR_INTAKE_003` — ★★ **أوزان غير منطقية** (`FR-M7-07` · `BR-M7-07`).
  sackWeightsIllogical,

  /// `ERR_INTAKE_004` — ★★ **تجاوز الوزن المطالب به** (`FR-M7-18` · `E-07`).
  sackWeightExceeded,

  /// `ERR_INTAKE_005` — ⛔★★★ **وزن حبة مفقود لنوعٍ وزني** (`E-08`).
  pieceWeightMissing,

  /// `ERR_INTAKE_006` — ★ **سطرٌ عدديّ يحتاج وزنه الكلي** (`FR-M7-13` · `E-09`).
  countedLineNeedsTotalWeight,

  // ── التوزيع والضمار (`WU-006`) — الكتالوج §`DIST` و§`PRICE` و§`AMEND` ──

  /// ★★★ `ERR_DIST_001` — **توزيعةٌ قائمة لنفس المفتاح** (`GR-18` · `E-04`).
  ///
  /// ⚠️ **ونصّه إرشادٌ لا منع** — ★ **والشاشة تفتح الموجودة للتعديل**.
  distributionExists,

  /// `ERR_DIST_002` — **مقوت معطَّل** (`FR-M10-12`).
  dealerInactive,

  /// ⛔★★★ `ERR_PRICE_001` — **كتابة سعرٍ بلا مفتاحه** (`ت-12` · `AT-25`).
  distributionPricingDenied,

  /// ⛔★★ `ERR_AMEND_005` — **إلغاء توزيعةٍ سُدِّد ضمارها** (`E-15`).
  settledDebtBlocksCancel,

  // ── المقبوضات (`WU-007`) — الكتالوج §`DIST` ──
  //
  // ⛔★★ **ولا نصّ مُخترَع واحد:** الأربعة **رموزٌ ونصوصٌ قائمة في الكتالوج**
  //    قبل هذه الزيادة — ★ **والزيادة تستهلكه ولا تُوسّعه** (§3 القاعدة 5).

  /// ⛔★★ `ERR_DIST_004` — **المبلغ الواصل يتجاوز المتبقي** (`FR-M12-06`).
  receiptExceedsDebt,

  /// ⛔⛔★★ `ERR_DIST_006` — **تاريخ مستقبلي** (`FR-M12-02` · `AT-56`).
  futureDateRejected,

  /// `ERR_DIST_007` — **تسجيل بتاريخ سابق بلا صلاحية** (`E-14`).
  backdateDenied,

  /// ★★ `ERR_DIST_008` — **ملاحظة الإيداع مفقودة** (`FR-M12-15` · `AT-36`).
  depositNoteMissing,

  // ── البيع النقدي المباشر (`WU-012`) — الكتالوج §`PRICE` ──
  //
  // ⛔★★ **ولا نصّ مُخترَع واحد:** الثلاثة **رموزٌ ونصوصٌ قائمة في الكتالوج**
  //    قبل هذه الزيادة — ★ **والزيادة تستهلكه ولا تُوسّعه** (§3 القاعدة 5).

  /// ⛔⛔★★★ `ERR_PRICE_002` — **سعرٌ دون الحد الأدنى** (`FR-M11-05` · `GR-34`).
  ///
  /// ★★ **والصلاحيةُ وحدها هي الحارس** — ⛔ **و`ERR_PRICE_003` («سبب التجاوز
  /// مفقود») لم يعد يُصدَر** بـ`ADR-0020`.
  belowMinimumCashPrice,

  /// ★★★ `ERR_PRICE_004` — **سعرٌ مفقود في بيعٍ نقدي** (`FR-M11-04`).
  cashPriceMissing,

  /// ⚠️ `ERR_PRICE_005` — **نوعٌ غير مسعَّر** (`FR-M11-06`) — ★ **تنبيهٌ لا منع**.
  itemNotPricedYet,

  // ── الجرد (`WU-022`) — الكتالوج §`STOCK` ──
  //
  // ✅★★★ **ونصّاهما اعتمدهما صاحب المشروع صراحةً (2026-09-05 · `IQ-042`)**
  //    — ⛔ **لا بصياغة اجتهادية** (`error-codes-catalog.md` §3 القاعدة 5).

  /// ★★ `ERR_STOCK_006` — **جردٌ مفتوحٌ على المصدر واليوم نفسِهما** (`FR-M16-06`).
  stocktakeInProgress,

  /// ★★ `ERR_STOCK_007` — **حالةُ مستند الجرد لا تسمح بالعملية** (`FR-M16-09`).
  ///
  /// ⛔⛔ **ورمزٌ واحدٌ للحالتين معاً** — **اعتمادُ ما ليس مسوّدةً** و**تعديلُ
  /// ما ليس معتمداً**: ⟵ **والفعلُ المُرشَد إليه واحد**، ⛔ **والتمييزُ في
  /// السجلّ لا في الشاشة.**
  stocktakeStateBlocked,

  /// ★ `ERR_CALL_500` — **فشل عملية غير متوقَّع**، ⛔ **ومصير كل رمز مجهول**.
  operationFailed,
}

/// ★★ **الرسالة المعروضة — مدخلُ كتالوجٍ معتمد أو نصٌّ تشخيصي.**
///
/// ⛔⛔★★★ **وهذا انحرافٌ مُوثَّق عن §3 القاعدة 1** («لا يُعرَض رمز تقني
/// للمستخدم») **لسدّ `DEBT-52`** (2026-08-28): ★ **الرسالة العامة «تعذّر
/// إتمام العملية. أعد المحاولة.» كانت تبتلع تشخيصاً دقيقاً موجوداً فعلاً**
/// ⟵ **فكلّفت أربع جولات تشخيص**، ⛔ **وهي تضليلٌ إيجابي: «أعد المحاولة»
/// فعلٌ لا يمكن أن ينجح حين يكون العطل في البناء لا في اللحظة.**
/// ⟵ ★ **فالرمز غير الكتالوجي يصل الشاشة بنصّه**، ⛔ **والرسالة العامة
/// تبقى حدّاً أدنى للنصّ الفارغ وحده.**
sealed class CatalogMessage {
  /// ⛔ لا يُنشأ إلا بالشكلين أدناه.
  const CatalogMessage();

  static const CatalogMessage sessionExpired = CatalogEntry(
    CatalogMessageId.sessionExpired,
  );
  static const CatalogMessage accountDisabled = CatalogEntry(
    CatalogMessageId.accountDisabled,
  );
  static const CatalogMessage temporaryLock = CatalogEntry(
    CatalogMessageId.temporaryLock,
  );
  static const CatalogMessage noConnection = CatalogEntry(
    CatalogMessageId.noConnection,
  );
  static const CatalogMessage platformUnavailable = CatalogEntry(
    CatalogMessageId.platformUnavailable,
  );
  static const CatalogMessage invalidCredentials = CatalogEntry(
    CatalogMessageId.invalidCredentials,
  );
  static const CatalogMessage unexpectedSignInFailure = CatalogEntry(
    CatalogMessageId.unexpectedSignInFailure,
  );
  static const CatalogMessage permissionMissing = CatalogEntry(
    CatalogMessageId.permissionMissing,
  );
  static const CatalogMessage grantBeyondActor = CatalogEntry(
    CatalogMessageId.grantBeyondActor,
  );
  static const CatalogMessage amendReasonMissing = CatalogEntry(
    CatalogMessageId.amendReasonMissing,
  );
  static const CatalogMessage emailAlreadyExists = CatalogEntry(
    CatalogMessageId.emailAlreadyExists,
  );
  static const CatalogMessage roleAssigned = CatalogEntry(
    CatalogMessageId.roleAssigned,
  );
  static const CatalogMessage supplierPhoneExists = CatalogEntry(
    CatalogMessageId.supplierPhoneExists,
  );
  static const CatalogMessage dealerPhoneExists = CatalogEntry(
    CatalogMessageId.dealerPhoneExists,
  );
  static const CatalogMessage itemNameExists = CatalogEntry(
    CatalogMessageId.itemNameExists,
  );
  static const CatalogMessage sourceNameExists = CatalogEntry(
    CatalogMessageId.sourceNameExists,
  );
  static const CatalogMessage dealerBalanceBlocksDisable = CatalogEntry(
    CatalogMessageId.dealerBalanceBlocksDisable,
  );
  static const CatalogMessage systemDefaultItem = CatalogEntry(
    CatalogMessageId.systemDefaultItem,
  );
  static const CatalogMessage itemUnitLocked = CatalogEntry(
    CatalogMessageId.itemUnitLocked,
  );
  static const CatalogMessage appSettingsAlreadyWritten = CatalogEntry(
    CatalogMessageId.appSettingsAlreadyWritten,
  );
  static const CatalogMessage concurrencyConflict = CatalogEntry(
    CatalogMessageId.concurrencyConflict,
  );
  static const CatalogMessage sourceOutOfScope = CatalogEntry(
    CatalogMessageId.sourceOutOfScope,
  );
  static const CatalogMessage supplierRequiredForSource = CatalogEntry(
    CatalogMessageId.supplierRequiredForSource,
  );
  static const CatalogMessage itemAlreadyInDocument = CatalogEntry(
    CatalogMessageId.itemAlreadyInDocument,
  );
  static const CatalogMessage insufficientStock = CatalogEntry(
    CatalogMessageId.insufficientStock,
  );
  static const CatalogMessage fractionalCount = CatalogEntry(
    CatalogMessageId.fractionalCount,
  );
  static const CatalogMessage amendReducesBelowIssued = CatalogEntry(
    CatalogMessageId.amendReducesBelowIssued,
  );
  static const CatalogMessage cancelReasonMissing = CatalogEntry(
    CatalogMessageId.cancelReasonMissing,
  );
  static const CatalogMessage documentCancelled = CatalogEntry(
    CatalogMessageId.documentCancelled,
  );
  static const CatalogMessage stocktakeInProgress = CatalogEntry(
    CatalogMessageId.stocktakeInProgress,
  );
  static const CatalogMessage stocktakeStateBlocked = CatalogEntry(
    CatalogMessageId.stocktakeStateBlocked,
  );
  static const CatalogMessage sourceInactive = CatalogEntry(
    CatalogMessageId.sourceInactive,
  );
  static const CatalogMessage fractionalMoney = CatalogEntry(
    CatalogMessageId.fractionalMoney,
  );
  static const CatalogMessage sackWeightsIllogical = CatalogEntry(
    CatalogMessageId.sackWeightsIllogical,
  );
  static const CatalogMessage sackWeightExceeded = CatalogEntry(
    CatalogMessageId.sackWeightExceeded,
  );
  static const CatalogMessage pieceWeightMissing = CatalogEntry(
    CatalogMessageId.pieceWeightMissing,
  );
  static const CatalogMessage countedLineNeedsTotalWeight = CatalogEntry(
    CatalogMessageId.countedLineNeedsTotalWeight,
  );
  static const CatalogMessage distributionExists = CatalogEntry(
    CatalogMessageId.distributionExists,
  );
  static const CatalogMessage dealerInactive = CatalogEntry(
    CatalogMessageId.dealerInactive,
  );
  static const CatalogMessage distributionPricingDenied = CatalogEntry(
    CatalogMessageId.distributionPricingDenied,
  );
  static const CatalogMessage settledDebtBlocksCancel = CatalogEntry(
    CatalogMessageId.settledDebtBlocksCancel,
  );
  static const CatalogMessage belowMinimumCashPrice = CatalogEntry(
    CatalogMessageId.belowMinimumCashPrice,
  );
  static const CatalogMessage cashPriceMissing = CatalogEntry(
    CatalogMessageId.cashPriceMissing,
  );
  static const CatalogMessage itemNotPricedYet = CatalogEntry(
    CatalogMessageId.itemNotPricedYet,
  );
  static const CatalogMessage receiptExceedsDebt = CatalogEntry(
    CatalogMessageId.receiptExceedsDebt,
  );
  static const CatalogMessage futureDateRejected = CatalogEntry(
    CatalogMessageId.futureDateRejected,
  );
  static const CatalogMessage backdateDenied = CatalogEntry(
    CatalogMessageId.backdateDenied,
  );
  static const CatalogMessage depositNoteMissing = CatalogEntry(
    CatalogMessageId.depositNoteMissing,
  );
  static const CatalogMessage operationFailed = CatalogEntry(
    CatalogMessageId.operationFailed,
  );
}

/// مدخلُ كتالوجٍ معتمد — ★ **نصّه من الكتالوج حرفاً بحرف**.
final class CatalogEntry extends CatalogMessage {
  /// ينشئ المدخل بمعرّفه.
  const CatalogEntry(this.id);

  /// معرّف المدخل في الكتالوج.
  final CatalogMessageId id;

  @override
  bool operator ==(Object other) => other is CatalogEntry && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// ★★★ **نصٌّ تشخيصي لا مقابل له في الكتالوج** — `DEBT-52`.
///
/// ⚠️ **ويحمل رمزَ خطأٍ خادمياً غيرَ معروفٍ للتطبيق** (`ERR_CALL_400` …)
/// **أو نصَّ عطلٍ محلياً** — ⟵ ★ **وكلاهما يصل المستخدم**، ⛔ **ولا يُطوى.**
final class DiagnosticMessage extends CatalogMessage {
  /// ينشئ الرسالة بنصّها التشخيصي.
  const DiagnosticMessage(this.diagnostic);

  /// النصّ التشخيصي كما وصل — ⛔ **بلا تفسير ولا ترجمة.**
  final String diagnostic;

  @override
  bool operator ==(Object other) =>
      other is DiagnosticMessage && other.diagnostic == diagnostic;

  @override
  int get hashCode => diagnostic.hashCode;
}

/// حدُّ عرض النصّ التشخيصي — ★ **ما زاد يُقصّ بعلامة قطع** ⛔ لا يُحذف كلّه.
const int _diagnosticLimit = 140;

/// نصّ الرسالة المعروضة.
String catalogText(CatalogMessage message) => switch (message) {
      CatalogEntry(:final CatalogMessageId id) => _entryText(id),
      DiagnosticMessage(:final String diagnostic) => _diagnosticText(diagnostic),
    };

/// ★★ يصوغ النصّ التشخيصي للعرض.
///
/// ⛔ **ولا «أعد المحاولة» هنا:** ★ **العطل التشخيصي غالباً بنيوي**،
/// ⟵ **فدعوةُ الإعادة تُرسل المستخدم إلى طريقٍ مسدود بثقة** (`DEBT-52`).
/// ★ **والفراغ وحده يسقط إلى الرسالة العامة** — ⛔ فلا شاشة بلا نصّ.
String _diagnosticText(String diagnostic) {
  final String trimmed = diagnostic.trim();
  if (trimmed.isEmpty) return _entryText(CatalogMessageId.operationFailed);
  final String shown = trimmed.length <= _diagnosticLimit
      ? trimmed
      : '${trimmed.substring(0, _diagnosticLimit)}…';
  return '❌ تعذّر إتمام العملية — التفصيل التقني: $shown';
}

/// نصّ مدخل الكتالوج **حرفاً بحرف** — ⛔ **ولا صياغة جديدة.**
String _entryText(CatalogMessageId message) => switch (message) {
      CatalogMessageId.sessionExpired =>
        '⚠️ انتهت مدة الجلسة. يرجى تسجيل الدخول مرة أخرى.',
      CatalogMessageId.accountDisabled => '❌ الحساب معطَّل. راجع المدير.',
      CatalogMessageId.temporaryLock =>
        '⚠️ قُفل الحساب مؤقتاً بعد محاولات دخول فاشلة.',
      CatalogMessageId.noConnection =>
        '❌ لا يوجد اتصال بالإنترنت — لا يمكن حفظ العملية. تحقق من الاتصال '
            'ثم أعد المحاولة.',
      CatalogMessageId.platformUnavailable =>
        '❌ خدمات Google Play غير متوفرة على هذا الجهاز — النظام غير مدعوم '
            'عليه.',
      CatalogMessageId.invalidCredentials =>
        '❌ البريد الإلكتروني أو كلمة المرور غير صحيحة.',
      CatalogMessageId.unexpectedSignInFailure =>
        '❌ تعذّر تسجيل الدخول لخطأ غير متوقَّع. أعد المحاولة.',
      CatalogMessageId.permissionMissing => '❌ ليس لديك صلاحية تنفيذ هذه العملية.',
      CatalogMessageId.grantBeyondActor => '❌ لا يمكنك منح صلاحية لا تملكها.',
      CatalogMessageId.amendReasonMissing => '❌ يجب إدخال سبب التعديل قبل الحفظ.',
      CatalogMessageId.emailAlreadyExists =>
        '❌ البريد الإلكتروني مسجَّل مسبقاً لمستخدم آخر.',
      CatalogMessageId.roleAssigned => '❌ لا يمكن حذف دور مُسنَد إلى مستخدم.',
      // ⚠️ **ونصوص الكتالوج تحمل قوالب `{الاسم}` و`{الكود}` و`{الرصيد}`** —
      //    ⛔ **ولا تُملأ هنا**: هذا المعبر لا يملك السياق أصلاً، ★ **والشاشة
      //    هي التي تعرف ما حاول المستخدم فعله**. ⟵ **فيُعرَض النصّ بلا
      //    القالب**، ⛔ **ولا يُعرَض قوسٌ فارغ يُربك القارئ.**
      CatalogMessageId.supplierPhoneExists =>
        '❌ رقم الهاتف مسجَّل مسبقاً لرعوي آخر.',
      CatalogMessageId.dealerPhoneExists => '❌ رقم الهاتف مسجَّل مسبقاً لمقوت آخر.',
      CatalogMessageId.itemNameExists => '❌ اسم النوع مسجَّل مسبقاً.',
      CatalogMessageId.sourceNameExists => '❌ اسم المصدر مسجَّل مسبقاً.',
      CatalogMessageId.dealerBalanceBlocksDisable =>
        '⚠️ هذا المقوت له رصيد قائم. التعطيل يتطلب صلاحية وإقراراً مكتوباً.',
      CatalogMessageId.systemDefaultItem =>
        '❌ «السكرب» نوع افتراضي في النظام — لا يُعدَّل ولا يُحذف.',
      CatalogMessageId.itemUnitLocked =>
        '❌ لا يمكن تغيير وحدة القياس بعد أول حركة على النوع.',
      CatalogMessageId.appSettingsAlreadyWritten =>
        '❌ الإعداد التأسيسي يُكتب مرة واحدة ولا يُعدَّل.',
      CatalogMessageId.concurrencyConflict =>
        '⚠️ تم تعديل البيانات من مستخدم آخر. يرجى إعادة المحاولة.',
      // ⚠️ **وقوالب `{المصدر}` و`{النوع}` و`{المتاح}` لا تُملأ هنا** — راجع
      //    الملاحظة أعلاه: ★ **هذا المعبر لا يملك السياق**، ⟵ **فيُعرَض
      //    النصّ بلا القالب** ⛔ **لا بقوسٍ فارغ يُربك القارئ.**
      CatalogMessageId.sourceOutOfScope =>
        '❌ لا تملك صلاحية العمل على هذا المصدر. راجع المدير.',
      CatalogMessageId.supplierRequiredForSource =>
        '❌ هذا المصدر يشترط اختيار الرعوي عند التوريد.',
      CatalogMessageId.itemAlreadyInDocument =>
        '❌ هذا النوع مُدخَل مسبقاً في هذا المستند. عدّل السطر الموجود.',
      CatalogMessageId.insufficientStock =>
        '❌ الكمية غير كافية — المتوفر أقل من المطلوب.',
      CatalogMessageId.fractionalCount =>
        '❌ الكمية يجب أن تكون رقماً صحيحاً لهذا النوع — الكسور مسموحة في '
            'الأنواع الوزنية فقط.',
      CatalogMessageId.amendReducesBelowIssued =>
        '❌ لا يمكن تخفيض الكمية — الفرق غير متاح حالياً في مخزون هذا المصدر.',
      CatalogMessageId.cancelReasonMissing => '❌ يجب إدخال سبب الإلغاء.',
      CatalogMessageId.documentCancelled =>
        '❌ لا يمكن تنفيذ العملية — المستند ملغى.',
      CatalogMessageId.sourceInactive =>
        '❌ المصدر معطَّل — لا يمكن التوريد أو التوزيع منه.',
      // ✅★★★ **منقولان حرفاً بحرف من `error-codes-catalog.md` §`STOCK`**
      //    — ★ **باعتماد صاحب المشروع نصَّهما صراحةً** (`IQ-042` · 2026-09-05).
      CatalogMessageId.stocktakeInProgress =>
        '❌ يوجد جرد مفتوح لهذا المصدر في هذا اليوم — اعتمده أو ألغِه قبل بدء '
            'جرد جديد.',
      CatalogMessageId.stocktakeStateBlocked =>
        '❌ حالة مستند الجرد لا تسمح بهذه العملية — حدّث الشاشة وأعد المحاولة.',
      // ★ **منقولٌ حرفاً بحرف من `error-codes-catalog.md` §`MONEY`.**
      CatalogMessageId.fractionalMoney =>
        '❌ المبلغ يجب أن يكون رقماً صحيحاً بالريال — بلا كسور عشرية.',
      // ★ **منقولةٌ حرفاً بحرف من `error-codes-catalog.md` §2.6.**
      CatalogMessageId.sackWeightsIllogical =>
        '❌ الوزن الكلي يجب أن يكون أكبر من مجموع الثلج والسكرب.',
      // ⚠️ **وقوالب `{المجموع}` و`{المطالب}` لا تُملأ هنا** — راجع الملاحظة
      //    أعلاه: ★ **هذا المعبر لا يملك السياق**، ⟵ **فيُعرَض النصّ بلا
      //    القالب** ⛔ **لا بقوسٍ فارغ يُربك القارئ.**
      CatalogMessageId.sackWeightExceeded =>
        '❌ مجموع أوزان الأنواع يتجاوز الوزن المطالب به.',
      CatalogMessageId.pieceWeightMissing =>
        '❌ هذا النوع وزني ولا يوجد له وزن حبة — أدخله يدوياً '
            '(لا يُستنتج من الوزن الكلي).',
      CatalogMessageId.countedLineNeedsTotalWeight =>
        '❌ هذا النوع عددي — أدخل الوزن الكلي ليُستنتج وزن الحبة.',
      // ★ **منقولةٌ حرفاً بحرف من `error-codes-catalog.md` §`DIST` و
      //   §`PRICE` و§`AMEND`** — ⚠️ **وقوالبها لا تُملأ هنا** (راجع أعلاه).
      CatalogMessageId.distributionExists =>
        '⚠️ يوجد توزيع لهذا المقوت من هذا المصدر بمخزون اليوم. '
            'سيُفتح للتعديل بدل إنشاء توزيع ثانٍ.',
      CatalogMessageId.dealerInactive =>
        '❌ لا يمكن التوزيع — حساب المقوت معطَّل. يمكنك القبض منه فقط.',
      CatalogMessageId.distributionPricingDenied =>
        '❌ ليس لديك صلاحية إدخال السعر لحظة التوزيع. سيُسعَّر لاحقاً.',
      CatalogMessageId.settledDebtBlocksCancel =>
        '❌ لا يمكن إلغاء توزيعة سُدِّد ضمارها كلياً أو جزئياً. '
            'عالج السداد أولاً.',
      // ★ **منقولةٌ حرفاً بحرف من `error-codes-catalog.md` §`DIST`**
      //   — ⚠️ **وقوالب `{المبلغ}` و`{المتبقي}` لا تُملأ هنا** (راجع أعلاه):
      //   ★ **هذا المعبر لا يملك السياق**، ⟵ **فيُعرَض النصّ بلا القالب.**
      CatalogMessageId.receiptExceedsDebt =>
        '❌ المبلغ الواصل يتجاوز المتبقي على هذا الضمار.',
      CatalogMessageId.futureDateRejected =>
        '❌ لا يمكن تسجيل عملية بتاريخ مستقبلي.',
      CatalogMessageId.backdateDenied =>
        '❌ ليس لديك صلاحية التسجيل بتاريخ سابق.',
      CatalogMessageId.depositNoteMissing =>
        '❌ تأكيد الإيداع البنكي يتطلب إدخال ملاحظة.',
      // ★ **منقولةٌ حرفاً بحرف من `error-codes-catalog.md` §`PRICE`**
      //   — ⚠️ **وقوالب `{الحد}` و`{النوع}` لا تُملأ هنا** (راجع أعلاه).
      CatalogMessageId.belowMinimumCashPrice =>
        '❌ السعر أقل من الحد الأدنى للبيع النقدي لهذا النوع.',
      CatalogMessageId.cashPriceMissing =>
        '❌ البيع النقدي يتطلب إدخال سعر لكل نوع.',
      CatalogMessageId.itemNotPricedYet =>
        '⚠️ هذا النوع غير مسعَّر بعد — لا يوجد له حد أدنى للبيع النقدي.',
      CatalogMessageId.operationFailed => '❌ تعذّر إتمام العملية. أعد المحاولة.',
    };

/// ★★ يترجم **رمز الكتالوج القادم من عملية سحابية** إلى رسالته المعروضة.
///
/// ⛔★★ **والرمز المجهول يُعرَض بـ`ERR_CALL_500` ⛔ ولا يُبتلَع ولا يُعرَض
/// خاماً:** الابتلاع يترك الشاشة **صامتة بعد فشل حقيقي** ⟵ فيظنّ المحاسب
/// أن العملية نجحت، ★ **وعرضُ الرمز خام يخالف §3 القاعدة 1** («لا يُعرَض
/// رمز تقني للمستخدم»). ⟵ **فالمجهول يُعرَض برسالة عامة ويُسجَّل برمزه.**
CatalogMessage callableErrorMessage(String code) => switch (code) {
      'ERR_AUTH_001' => CatalogMessage.permissionMissing,
      'ERR_AUTH_003' => CatalogMessage.sessionExpired,
      'ERR_AUTH_004' => CatalogMessage.accountDisabled,
      'ERR_AUTH_007' => CatalogMessage.grantBeyondActor,
      'ERR_AMEND_002' => CatalogMessage.amendReasonMissing,
      'ERR_SETUP_011' => CatalogMessage.emailAlreadyExists,
      'ERR_SETUP_012' => CatalogMessage.roleAssigned,
      'ERR_SETUP_001' => CatalogMessage.supplierPhoneExists,
      'ERR_SETUP_002' => CatalogMessage.dealerPhoneExists,
      'ERR_SETUP_003' => CatalogMessage.itemNameExists,
      'ERR_SETUP_004' => CatalogMessage.sourceNameExists,
      'ERR_SETUP_006' => CatalogMessage.dealerBalanceBlocksDisable,
      'ERR_SETUP_008' => CatalogMessage.systemDefaultItem,
      'ERR_SETUP_009' => CatalogMessage.itemUnitLocked,
      'ERR_SETUP_010' => CatalogMessage.appSettingsAlreadyWritten,
      'ERR_CONC_001' => CatalogMessage.concurrencyConflict,
      // ── المخزون والتوريد (`WU-003`) ──
      'ERR_AUTH_002' => CatalogMessage.sourceOutOfScope,
      'ERR_INTAKE_001' => CatalogMessage.supplierRequiredForSource,
      'ERR_INTAKE_008' => CatalogMessage.itemAlreadyInDocument,
      'ERR_STOCK_001' => CatalogMessage.insufficientStock,
      'ERR_STOCK_002' => CatalogMessage.fractionalCount,
      'ERR_AMEND_003' => CatalogMessage.amendReducesBelowIssued,
      'ERR_AMEND_004' => CatalogMessage.cancelReasonMissing,
      'ERR_AMEND_006' => CatalogMessage.documentCancelled,
      'ERR_DIST_003' => CatalogMessage.sourceInactive,
      // ── الوارد جواني (`WU-004`) ──
      'ERR_INTAKE_003' => CatalogMessage.sackWeightsIllogical,
      'ERR_INTAKE_004' => CatalogMessage.sackWeightExceeded,
      'ERR_INTAKE_005' => CatalogMessage.pieceWeightMissing,
      'ERR_INTAKE_006' => CatalogMessage.countedLineNeedsTotalWeight,
      // ── التوزيع والضمار (`WU-006`) ──
      'ERR_DIST_001' => CatalogMessage.distributionExists,
      'ERR_DIST_002' => CatalogMessage.dealerInactive,
      'ERR_PRICE_001' => CatalogMessage.distributionPricingDenied,
      'ERR_AMEND_005' => CatalogMessage.settledDebtBlocksCancel,
      // ── المقبوضات (`WU-007`) ──
      'ERR_DIST_004' => CatalogMessage.receiptExceedsDebt,
      'ERR_DIST_006' => CatalogMessage.futureDateRejected,
      'ERR_DIST_007' => CatalogMessage.backdateDenied,
      'ERR_DIST_008' => CatalogMessage.depositNoteMissing,
      // ── البيع النقدي المباشر (`WU-012`) ──
      'ERR_PRICE_002' => CatalogMessage.belowMinimumCashPrice,
      'ERR_PRICE_004' => CatalogMessage.cashPriceMissing,
      'ERR_PRICE_005' => CatalogMessage.itemNotPricedYet,
      // ── التسعير اليومي (`WU-005`) ──
      'ERR_MONEY_001' => CatalogMessage.fractionalMoney,
      // ── الجرد (`WU-022`) ──
      'ERR_STOCK_006' => CatalogMessage.stocktakeInProgress,
      'ERR_STOCK_007' => CatalogMessage.stocktakeStateBlocked,
      // ⛔⛔★★★ **والمجهول يصل بنصّه لا برسالةٍ عامة** — `DEBT-52`:
      //   ★ **رمزٌ يُضيفه الخادم غداً يُقرأ فوراً** ⟵ **بلا جولة تشخيص**،
      //   ⛔ **والفارغ وحده يسقط إلى `ERR_CALL_500`** (في [_diagnosticText]).
      _ => DiagnosticMessage(code),
    };

/// رسالة رفض الدخول — ★★ **ولكل حالة نصّ الآن، ⛔ ولا `null`** (`IQ-016`).
///
/// ✅ **وحُسم البند باعتماد صاحب المشروع نصَّ `ERR_AUTH_008` و`ERR_AUTH_009`
/// صراحةً** — ⛔ **لا بصياغة اجتهادية**، ★ **والنوع العائد صار غير قابل
/// للعدم فصار «حالةٌ بلا نصّ» خطأَ تصريفٍ لا عطلاً صامتاً في الشاشة.**
CatalogMessage signInRejectionMessage(SignInRejection reason) =>
    switch (reason) {
      SignInRejection.accountDisabled => CatalogMessage.accountDisabled,
      SignInRejection.lockedOut => CatalogMessage.temporaryLock,
      SignInRejection.noConnection => CatalogMessage.noConnection,
      SignInRejection.platformUnavailable => CatalogMessage.platformUnavailable,
      SignInRejection.invalidCredentials => CatalogMessage.invalidCredentials,
      SignInRejection.unexpected => CatalogMessage.unexpectedSignInFailure,
    };

/// ★★ يترجم **خطأ طبقة النطاق** إلى رسالته المعروضة.
///
/// ★ **وهو المعبر الوحيد بين `AppError` والشاشة** — ⛔ **ولا شاشةَ تُترجم
/// خطأً بنفسها**، وإلا افترقت الترجمتان فعرضت شاشتان نصّين مختلفين لخطأ واحد.
///
/// ⚠️ **و[InfrastructureError] تحمل رمز الكتالوج في وصفها** حين يأتي من
/// عملية سحابية — ⟵ **فيُترجَم برمزه**، ⛔ **والمجهول برسالة عامة لا بصمت.**
CatalogMessage appErrorMessage(AppError error) => switch (error) {
      SessionError() => CatalogMessage.sessionExpired,
      PermissionError() => CatalogMessage.permissionMissing,
      ConnectivityError() => CatalogMessage.noConnection,
      ConcurrencyError() => CatalogMessage.concurrencyConflict,
      PlatformUnavailableError() => CatalogMessage.platformUnavailable,
      InfrastructureError(:final String diagnostic) => callableErrorMessage(
        diagnostic,
      ),
      // ⛔ **وما بقي رسالة عامة** — ⚠️ **ورسائل قواعد العمل تُعرَض من
      //    شاشاتها بسياقها** (`{النوع}` · `{المصدر}` …) لا من هنا مجرَّدةً.
      // ★★ **ونقصُ المخزون له نصّه** — ⛔ **ولا يُطوى في «تعذّر إتمام
      //    العملية»**: `E-01` رسالةٌ **قابلة للتصرف** (`P-13`)، ⟵ **فالبائع
      //    يفهم أن الكمية لا تكفي** لا أن النظام تعطّل.
      InsufficientStockError() => CatalogMessage.insufficientStock,
      ValidationError() || IntegrationError() => CatalogMessage.operationFailed,
    };

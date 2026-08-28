/// بروتوكول العمليات **المستدعاة مباشرةً** من التطبيق.
///
/// ★ **لماذا يُكتب يدوياً:** `ADR-0009` ② يضع العمليات على Cloud Run بلغة
/// Dart، ⛔ **ولا يوجد SDK إداري بـDart** يغلّف بروتوكول الاستدعاء. فالغلاف
/// هنا **نقل حرفي للبروتوكول المُعلَن** الذي يتكلمه عميل المنصة:
///
/// ```text
/// الطلب     : POST · {"data": {...}} · Authorization: Bearer <رمز الدخول>
/// النجاح    : 200 · {"result": {...}}
/// الفشل     : رمز HTTP مطابق · {"error": {"status", "message", "details"}}
/// ```
///
/// ⛔ **ولا نصّ عربي في أي استجابة هنا** — `error-handling-strategy.md` §3
/// القاعدة 2: «لا يُعرَض رمز تقني للمستخدم — الرسالة من كتالوج §11 حصراً»،
/// **وربط الرمز برسالته مسؤولية طبقة العرض** لا الشبكة. فما يعبر هنا
/// **رمز الكتالوج وحده** (`ERR_AUTH_001` …).
library;

import 'dart:convert';

import 'package:shelf/shelf.dart';

/// خطأ يعبر الشبكة — **رمزه من `error-codes-catalog.md` §2 حصراً**.
final class CallableError {
  /// ينشئ خطأً برمزه وحالته.
  const CallableError({
    required this.code,
    required this.status,
    required this.httpStatus,
  });

  /// رمز الكتالوج — مثال `ERR_AUTH_001`.
  final String code;

  /// الحالة القياسية التي يفهمها عميل المنصة.
  final String status;

  /// رمز HTTP المقابل.
  final int httpStatus;

  /// صلاحية مفقودة — `ERR_AUTH_001`.
  static const CallableError permissionMissing = CallableError(
    code: 'ERR_AUTH_001',
    status: 'PERMISSION_DENIED',
    httpStatus: 403,
  );

  /// مصدر خارج النطاق — `ERR_AUTH_002`.
  static const CallableError sourceOutOfScope = CallableError(
    code: 'ERR_AUTH_002',
    status: 'PERMISSION_DENIED',
    httpStatus: 403,
  );

  /// انتهت الجلسة أو الرمز غير صالح — `ERR_AUTH_003`.
  static const CallableError sessionExpired = CallableError(
    code: 'ERR_AUTH_003',
    status: 'UNAUTHENTICATED',
    httpStatus: 401,
  );

  /// حساب معطَّل — `ERR_AUTH_004`.
  ///
  /// ★ **يُفحَص في كل استدعاء لا عند الدخول فقط** —
  /// `authentication-policy.md` §2 القاعدة 3: «**التعطيل فوري ونافذ** — لا
  /// انتظار انتهاء الجلسة».
  static const CallableError accountDisabled = CallableError(
    code: 'ERR_AUTH_004',
    status: 'UNAUTHENTICATED',
    httpStatus: 401,
  );

  /// منح صلاحية لا يملكها المُنفِّذ — `ERR_AUTH_007` (`BR-M1-03`).
  static const CallableError grantBeyondActor = CallableError(
    code: 'ERR_AUTH_007',
    status: 'PERMISSION_DENIED',
    httpStatus: 403,
  );

  /// ★★ **سبب التعديل مفقود** — `ERR_AMEND_002` (`ADR-0004` · `DEBT-21` ①).
  ///
  /// ⚠️⚠️ **وهذا بندُ قبولٍ مُلزِم لكل دالة كاتبة، لا خيار:** كانت قواعد
  /// الحماية تفرض `nonEmpty('amendReason')` على كل تعديل، ⛔ **ثم أُغلقت
  /// الكتابة المباشرة بـ`WU-026` فلم يعد أحدٌ يفرضه**. ★ **و`CR-002` نقل
  /// إثباته إلى أول دالة كاتبة** — ⟵ **وهذه هي**، فإسقاطه هنا **ثغرة صامتة**
  /// لا نقصُ ميزة.
  static const CallableError amendReasonMissing = CallableError(
    code: 'ERR_AMEND_002',
    status: 'INVALID_ARGUMENT',
    httpStatus: 400,
  );

  /// ★ البريد مسجَّل لحسابٍ آخر — `ERR_SETUP_011` (`FR-M1-01`).
  ///
  /// ⚠️ **ورمزه 409 لا 400:** الطلب **صحيح البنية** وإنما يتعارض مع حالة
  /// قائمة في النظام — ⟵ **والتمييز عملي لا شكلي**: التطبيق يعرض رسالة
  /// الكتالوج للمستخدم بدل «خلل في الطلب» الذي لا يُرشده إلى شيء.
  static const CallableError emailAlreadyExists = CallableError(
    code: 'ERR_SETUP_011',
    status: 'ALREADY_EXISTS',
    httpStatus: 409,
  );

  /// ★★ **الدور مُسنَد لمستخدم ⟵ لا يُحذف** — `ERR_SETUP_012`
  /// (`FR-M1-03` · حسم `IQ-018`).
  ///
  /// ⚠️ **ورمزه مستقل عن `ERR_AUTH_001` عمداً:** المُنفِّذ **قد يملك
  /// `roleDelete` كاملاً** والرفض مع ذلك صحيح — ⟵ **فرمزُ «لا صلاحية»
  /// كان سيُرسِل المديرَ يطلب صلاحيةً يملكها أصلاً** بدل أن يفهم أن الدور
  /// مُسنَد. ★ **والتمييز عملي لا شكلي.**
  ///
  /// ⚠️ **ومستقل عن `ERR_SETUP_005` أيضاً**: نصّ تلك يقترح **التعطيل**
  /// بديلاً، ⛔ **ولا تعطيل للأدوار** (`IQ-018`: «لا يُنشأ حقل `isActive`
  /// للدور»).
  static const CallableError roleAssigned = CallableError(
    code: 'ERR_SETUP_012',
    // ★ الطلب سليم البنية، **وإنما يتعارض مع حالة قائمة** — وهو المعنى
    //   القياسي لـ`FAILED_PRECONDITION` (وتقابله 400 في المنصة).
    status: 'FAILED_PRECONDITION',
    httpStatus: 400,
  );

  /// اسم مصدر مكرر — `ERR_SETUP_004` (`FR-M2-01` · `BR-M2-05`).
  ///
  /// ★ **والفحص على القيمة المُطبَّعة حصراً** عبر سجل حراسة معرّفه هو
  /// القيمة نفسها (`master-data-design.md` §3). ⚠️ **وأثرُ التطبيع الكامل
  /// معلَن:** قد يقع الرفض على اسمٍ يبدو مختلفاً بحرف واحد — **سلوك مقصود**
  /// (`IQ-013` §3.4).
  static const CallableError duplicateSourceName = CallableError(
    code: 'ERR_SETUP_004',
    // ★ الطلب سليم البنية **وإنما يتعارض مع حالة قائمة** — كـ`ERR_SETUP_011`.
    status: 'ALREADY_EXISTS',
    httpStatus: 409,
  );

  /// رقم رعوي مكرر — `ERR_SETUP_001` (`FR-M3-02`).
  static const CallableError duplicateSupplierPhone = CallableError(
    code: 'ERR_SETUP_001',
    status: 'ALREADY_EXISTS',
    httpStatus: 409,
  );

  /// رقم مقوت مكرر — `ERR_SETUP_002` (`FR-M4-02`).
  static const CallableError duplicateDealerPhone = CallableError(
    code: 'ERR_SETUP_002',
    status: 'ALREADY_EXISTS',
    httpStatus: 409,
  );

  /// اسم نوع مكرر — `ERR_SETUP_003` (`FR-M5-01`).
  static const CallableError duplicateItemName = CallableError(
    code: 'ERR_SETUP_003',
    status: 'ALREADY_EXISTS',
    httpStatus: 409,
  );

  /// ★★ **تعطيل مقوت له رصيد بلا إقرار** — `ERR_SETUP_006` (`FR-M4-09` · `E-39`).
  ///
  /// ⚠️ **ورمزه مستقل عن `ERR_AUTH_001` عمداً:** المُنفِّذ **يملك
  /// `dealerWrite` كاملاً** والرفض مع ذلك صحيح — ⟵ **فرمزُ «لا صلاحية»
  /// كان سيُرسِل المديرَ يطلب صلاحيةً يملكها أصلاً** بدل أن يفهم أن عليه
  /// كتابة الإقرار.
  static const CallableError dealerBalanceBlocksDisable = CallableError(
    code: 'ERR_SETUP_006',
    status: 'FAILED_PRECONDITION',
    httpStatus: 400,
  );

  /// ★★ **تعديل النوع الافتراضي «السكرب»** — `ERR_SETUP_008` (`FR-M5-05`).
  ///
  /// ⛔ **قيدٌ يعلو على الصلاحية:** من يملك `itemWrite` يعدّل كل نوع **إلا
  /// هذا**، ⟵ **فرمزٌ مستقل يقول للمستخدم السبب الحقيقي.**
  static const CallableError systemDefaultItem = CallableError(
    code: 'ERR_SETUP_008',
    status: 'FAILED_PRECONDITION',
    httpStatus: 400,
  );

  /// ★★ **تغيير وحدة نوع** — `ERR_SETUP_009` (`FR-M5-04` · `GR-19`).
  static const CallableError itemUnitLocked = CallableError(
    code: 'ERR_SETUP_009',
    status: 'FAILED_PRECONDITION',
    httpStatus: 400,
  );

  /// ★★ **كتابة الإعداد التأسيسي مرتين** — `ERR_SETUP_010` (`FR-M21-03` · `AT-65`).
  ///
  /// ⛔ **ويُرفَض حتى من المالك** — نصّ المتطلب: «**التعديل والحذف مرفوضان
  /// نهائياً لكل المستخدمين بمن فيهم المالك**».
  static const CallableError appSettingsAlreadyWritten = CallableError(
    code: 'ERR_SETUP_010',
    status: 'FAILED_PRECONDITION',
    httpStatus: 400,
  );

  // ══════════════════════════════════════════════════════════════════════
  // المخزون والتوريد (`WU-003`) — ★★ **كلها رموزٌ قائمة في الكتالوج**
  //
  // ⛔★★ **ولا رمزَ واحدٌ مُخترَع هنا:** `error-codes-catalog.md` §3 القاعدة 4
  //    («إضافة كود جديد تستلزم إضافة سطر هنا») والقاعدة 5 (**نصّ أي رسالة
  //    جديدة يعتمده صاحب المشروع صراحةً**، حسم `IQ-016`) — ⟵ **فالزيادة
  //    تستهلك الكتالوج ولا تُوسّعه**، ⛔ **ولا تُصاغ رسالةٌ اجتهاداً.**
  // ══════════════════════════════════════════════════════════════════════

  /// ★★ **الكمية غير كافية** — `ERR_STOCK_001` (`FR-M8-01` · `E-01`).
  ///
  /// ★ **ورمزُه مستقل عن `ERR_AMEND_003` عمداً:** هذا **منعُ عمليةٍ جديدة**
  /// وذاك **منعُ تخفيضٍ لكميةٍ صُرفت** — ⟵ **والرسالتان تُرشدان لفعلين
  /// مختلفين** (`error-codes-catalog.md` §2).
  static const CallableError insufficientStock = CallableError(
    code: 'ERR_STOCK_001',
    status: 'FAILED_PRECONDITION',
    httpStatus: 400,
  );

  /// ★★ **تخفيضٌ لكمية صُرفت** — `ERR_AMEND_003` (`FR-M6-12` · `BR-M6-07`).
  static const CallableError amendReducesBelowIssued = CallableError(
    code: 'ERR_AMEND_003',
    status: 'FAILED_PRECONDITION',
    httpStatus: 400,
  );

  /// ★ **سبب الإلغاء مفقود** — `ERR_AMEND_004` (`FR-M6-13` · `GR-06`).
  ///
  /// ⚠️ **ورمزُه مستقل عن `ERR_AMEND_002` عمداً:** الكتالوج يُفرد للإلغاء
  /// نصّاً خاصاً («يجب إدخال سبب الإلغاء») — ⟵ **فيقرأ المستخدم الحقلَ
  /// الذي عليه ملؤه** ⛔ **لا «سبب التعديل» وهو يُلغي.**
  static const CallableError cancelReasonMissing = CallableError(
    code: 'ERR_AMEND_004',
    status: 'INVALID_ARGUMENT',
    httpStatus: 400,
  );

  /// ★ **المستند ملغى** — `ERR_AMEND_006` (`FR-M6-13` · `A-14`).
  ///
  /// ⛔ **والملغى لا يُعدَّل ولا يُلغى ثانيةً:** إعادةُ كميةٍ إلى الرصيد من
  /// مستندٍ خرج من الحساب **فسادُ رصيدٍ صامت.**
  static const CallableError documentCancelled = CallableError(
    code: 'ERR_AMEND_006',
    status: 'FAILED_PRECONDITION',
    httpStatus: 400,
  );

  /// ★ **المصدر معطَّل** — `ERR_DIST_003` (`FR-M2-05` · `FR-M2-06`).
  ///
  /// ⚠️ **ويمنع التوريد الجديد وحده** — ★ **والإلغاء يبقى ممكناً**، ⟵ **فلا
  /// يحبس تعطيلُ مصدرٍ مستنداته الخاطئة داخله.**
  static const CallableError sourceInactive = CallableError(
    code: 'ERR_DIST_003',
    status: 'FAILED_PRECONDITION',
    httpStatus: 400,
  );

  /// ★ **الرعوي غير صالح لهذا المصدر** — `ERR_INTAKE_001` (`FR-M6-03` · `FR-M3-09`).
  ///
  /// ⚠️⚠️ **ويُعاد استعماله للحالتين معاً — غيابِ الرعوي المشروط وانتمائِه
  /// لمصدرٍ آخر** — ⛔ **ولا يُخترَع له رمزٌ ثالث:** `error-codes-catalog.md`
  /// §3 القاعدة 5 يجعل **نصّ أي رسالة جديدة قراراً لصاحب المشروع**، ★ **ونصّ
  /// هذا الرمز يُرشد للفعل نفسه في الحالتين** («اختر رعوياً لهذا المصدر»).
  static const CallableError supplierRequired = CallableError(
    code: 'ERR_INTAKE_001',
    status: 'FAILED_PRECONDITION',
    httpStatus: 400,
  );

  // ══════════════════════════════════════════════════════════════════════
  // الوارد جواني (`WU-004`) — ★★ **كلها رموزٌ قائمة في الكتالوج §2.6**
  //
  // ⛔★★ **ولا رمزَ واحدٌ مُخترَع هنا:** `error-codes-catalog.md` §3
  //    القاعدة 4 والقاعدة 5 (**نصّ أي رسالة جديدة يعتمده صاحب المشروع
  //    صراحةً**، حسم `IQ-016`) — ⟵ **فالزيادة تستهلك الكتالوج ولا تُوسّعه.**
  // ══════════════════════════════════════════════════════════════════════

  /// ★★ **أوزان غير منطقية** — `ERR_INTAKE_003` (`FR-M7-07` · `BR-M7-07`).
  ///
  /// «❌ الوزن الكلي يجب أن يكون أكبر من مجموع الثلج والسكرب.»
  static const CallableError sackWeightsIllogical = CallableError(
    code: 'ERR_INTAKE_003',
    status: 'FAILED_PRECONDITION',
    httpStatus: 400,
  );

  /// ★★ **تجاوز الوزن المطالب به** — `ERR_INTAKE_004` (`FR-M7-18` · `E-07`).
  static const CallableError sackWeightExceeded = CallableError(
    code: 'ERR_INTAKE_004',
    status: 'FAILED_PRECONDITION',
    httpStatus: 400,
  );

  /// ⛔★★★ **وزن حبة مفقود لنوعٍ وزني** — `ERR_INTAKE_005` (`E-08` · `FR-M7-14`).
  ///
  /// ★ **ونصّه يقول للمستخدم السبب الحقيقي** — «أدخله يدوياً (**لا يُستنتَج
  /// من الوزن الكلي**)»: ⟵ **فيفهم أن الرفض قاعدةٌ مقصودة لا نقصُ ميزة.**
  static const CallableError pieceWeightMissing = CallableError(
    code: 'ERR_INTAKE_005',
    status: 'FAILED_PRECONDITION',
    httpStatus: 400,
  );

  /// ★ **سطرٌ عدديّ يحتاج وزنه الكلي** — `ERR_INTAKE_006` (`FR-M7-13`).
  ///
  /// ⚠️⚠️ **ويُعاد استعماله للحالتين معاً — غيابِ الوزن الكلي وإرسالِ وزن
  /// حبةٍ لنوعٍ عددي** (`E-09`) — ⛔ **ولا يُخترَع له رمزٌ ثالث:** الكتالوج
  /// §3 القاعدة 5 يجعل **نصّ أي رسالة جديدة قراراً لصاحب المشروع**، ★ **ونصّ
  /// هذا الرمز يُرشد للفعل نفسه في الحالتين**: «**النوع عددي — أدخل الوزن
  /// الكلي ليُستنتَج وزن الحبة**» ⟵ **وهو بالضبط ما على المستخدم فعله حين
  /// يجد حقل وزن الحبة مقفلاً.**
  static const CallableError countedLineNeedsTotalWeight = CallableError(
    code: 'ERR_INTAKE_006',
    status: 'FAILED_PRECONDITION',
    httpStatus: 400,
  );

  /// ★ **نوع مكرر في المستند** — `ERR_INTAKE_008` (`FR-M7-23` · `BR-M7-17`).
  static const CallableError itemAlreadyInDocument = CallableError(
    code: 'ERR_INTAKE_008',
    status: 'FAILED_PRECONDITION',
    httpStatus: 400,
  );

  // ══════════════════════════════════════════════════════════════════════
  // التوزيع والضمار (`WU-006`) — ★★ **كلها رموزٌ قائمة في الكتالوج §2**
  //
  // ⛔★★ **ولا رمزَ واحدٌ مُخترَع هنا:** `error-codes-catalog.md` §3
  //    القاعدة 4 والقاعدة 5 (**نصّ أي رسالة جديدة يعتمده صاحب المشروع
  //    صراحةً**، حسم `IQ-016`) — ⟵ **فالزيادة تستهلك الكتالوج ولا تُوسّعه.**
  // ══════════════════════════════════════════════════════════════════════

  /// ⛔⛔★★★ **توزيعةٌ قائمة لنفس (المقوت × المصدر × اليوم)** —
  /// `ERR_DIST_001` (`FR-M10-01` · `GR-18` · `E-04`).
  ///
  /// ★★ **ونصّه يقول للواجهة ما تفعله:** «⚠️ يوجد توزيع لـ«{المقوت}» من
  /// مصدر «{المصدر}» بمخزون {التاريخ}. **سيُفتح للتعديل بدل إنشاء توزيع
  /// ثانٍ**» — ⟵ **فهو إرشادٌ لا منعٌ مسدود.**
  ///
  /// ⚠️ **ورمزه مستقل عن `ERR_CALL_400` عمداً:** الطلب **صحيح البنية**
  /// وإنما يتعارض مع حالة قائمة — ★ **والتمييز عملي**: `ERR_CALL_400`
  /// كان سيُظهر «خلل في الطلب» لمستخدمٍ فعل الصواب.
  static const CallableError distributionExists = CallableError(
    code: 'ERR_DIST_001',
    status: 'ALREADY_EXISTS',
    httpStatus: 409,
  );

  /// ★ **مقوت معطَّل** — `ERR_DIST_002` (`FR-M10-12` · `schema/dealers.md` ④).
  ///
  /// ⚠️ **ويمنع التوزيع الجديد وتعديله وحدهما** — ★ **والإلغاء يبقى ممكناً**
  /// ⟵ **فلا يحبس تعطيلُ مقوتٍ توزيعةً خاطئة داخل النظام**، ★ **والقبض منه
  /// يبقى ممكناً** بنصّ الرسالة نفسها.
  static const CallableError dealerInactive = CallableError(
    code: 'ERR_DIST_002',
    status: 'FAILED_PRECONDITION',
    httpStatus: 400,
  );

  /// ⛔⛔★★★ **كتابة سعرٍ بلا مفتاحه** — `ERR_PRICE_001` (`FR-M10-10` · `ت-12`).
  ///
  /// ★★ **وهذا هو تنفيذ «إخفاء الحقل تسهيل واجهة لا حماية»** (`FR-M10-07` ·
  /// `AT-25`): ⟵ **حتى من أرسل سعراً من خارج التطبيق تُرفض كتابته.**
  ///
  /// ⚠️ **ورمزٌ واحد للمفاتيح الثلاثة** (`distributionPriceNow` /
  /// `Amend` / `Clear`) — ⛔ **ولا يُخترَع له نظير:** الكتالوج §3 القاعدة 5
  /// يجعل **نصّ أي رسالة جديدة قراراً لصاحب المشروع**، ★ **ونصّ هذا الرمز
  /// يُرشد للفعل نفسه في الثلاث** («ليس لديك صلاحية إدخال السعر … سيُسعَّر
  /// لاحقاً»).
  static const CallableError distributionPricingDenied = CallableError(
    code: 'ERR_PRICE_001',
    status: 'PERMISSION_DENIED',
    httpStatus: 403,
  );

  /// ⛔⛔★★ **إلغاء توزيعةٍ سُدِّد ضمارها** — `ERR_AMEND_005`
  /// (`FR-M10-18` · `E-15`).
  ///
  /// ★ **ونصّه يقول الفعل المطلوب:** «عالج السداد أولاً» — ⛔ **لا «ممنوع»
  /// بلا مخرج.**
  static const CallableError settledDebtBlocksCancel = CallableError(
    code: 'ERR_AMEND_005',
    status: 'FAILED_PRECONDITION',
    httpStatus: 400,
  );

  /// ★★ **مسار عملية غير معروف** — `ERR_CALL_404` (حسم `IQ-019`).
  ///
  /// ★ **رمزٌ تقني لا قاعدة عمل** — بنفس منطق `ERR_CALL_400`: ⛔ **لا سطر
  /// له في كتالوج الرسائل ولا نصّ معروض خاص به**، ⟵ **والتطبيق يعرضه
  /// بالرسالة العامة** كمصير كل رمز لا يعرفه (§3 القاعدة 1).
  ///
  /// ⛔★★ **ووجودُه هو القاعدة ② من `IQ-019` حرفياً:** «أي مسار غير معروف
  /// **يُرفض صراحةً بخطأ مناسب، ولا يُحوّل إلى معالج افتراضي**». ⟵ **فرفضٌ
  /// بـ404 يقول للعميل «هذه العملية غير موجودة»**، ⛔ **بينما تمريرُه إلى
  /// معالجٍ افتراضي كان سيُنفِّذ عمليةً لم تُطلَب.**
  static const CallableError unknownOperation = CallableError(
    code: 'ERR_CALL_404',
    status: 'NOT_FOUND',
    httpStatus: 404,
  );

  /// مدخلات الطلب غير صالحة — لا رمز كتالوج له، فهو خلل عميل لا قاعدة عمل.
  static const CallableError invalidArgument = CallableError(
    code: 'ERR_CALL_400',
    status: 'INVALID_ARGUMENT',
    httpStatus: 400,
  );

  /// تعارض تزامن — `ERR_CONC_001`.
  static const CallableError concurrency = CallableError(
    code: 'ERR_CONC_001',
    status: 'ABORTED',
    httpStatus: 409,
  );

  /// فشل غير متوقَّع — **رسالة عامة وتسجيل تفصيلي بلا بيانات حساسة**.
  static const CallableError internal = CallableError(
    code: 'ERR_CALL_500',
    status: 'INTERNAL',
    httpStatus: 500,
  );
}

/// طلب استدعاء مُفكَّك — **حمولته ورمز دخول مُستدعيه**.
final class CallableRequest {
  /// ينشئ طلباً.
  const CallableRequest({required this.data, required this.idToken});

  /// محتوى `data` كما أرسله التطبيق.
  final Map<String, Object?> data;

  /// رمز الدخول الخام — ⛔ **لا يُسجَّل ولا يُكتب في أي حقل** (سرّ فعلي).
  final String idToken;

  /// يقرأ نصّاً إلزامياً من الحمولة، أو `null` إن غاب أو كان فارغاً.
  String? readString(String key) {
    final Object? value = data[key];
    if (value is! String || value.trim().isEmpty) return null;
    return value.trim();
  }

  /// يقرأ قائمة نصوص، أو `null` إن لم تكن قائمة نصوص.
  List<String>? readStringList(String key) {
    final Object? value = data[key];
    if (value is! List<Object?>) return null;
    if (value.any((Object? e) => e is! String)) return null;
    return value.cast<String>();
  }
}

/// نتيجة فكّ الطلب — إما طلب صالح وإما خطأ جاهز للإرجاع.
sealed class CallableParse {
  const CallableParse();
}

/// الطلب صالح.
final class ParsedCallable extends CallableParse {
  /// ينشئ نتيجة نجاح الفكّ.
  const ParsedCallable(this.request);

  /// الطلب المُفكَّك.
  final CallableRequest request;
}

/// الطلب مرفوض قبل أي عمل.
final class RejectedCallable extends CallableParse {
  /// ينشئ نتيجة رفض.
  const RejectedCallable(this.error);

  /// سبب الرفض.
  final CallableError error;
}

/// يفكّ طلب استدعاء من طلب HTTP خام.
///
/// ⛔ **يرفض قبل أي عمل**: غير `POST` · بلا ترويسة اعتماد · بجسم ليس JSON ·
/// أو بلا حقل `data`. **والرفض المبكر مقصود** — فكل عمل بعده يفترض هوية.
Future<CallableParse> parseCallableRequest(Request request) async {
  if (request.method != 'POST') {
    return const RejectedCallable(CallableError.invalidArgument);
  }

  final String? idToken = _bearerToken(request);
  if (idToken == null) {
    // ★ غياب الرمز **جلسة لا مصادقة**، لا نقص صلاحية — والتمييز مهم لأن
    //   التطبيق يعالج الأولى بإعادة دخول والثانية برسالة منع.
    return const RejectedCallable(CallableError.sessionExpired);
  }

  // ⛔★★ **وقراءة الجسم نفسها قد ترمي** — ⚠️ **رُصد بالتشغيل الحقيقي على
  //    Cloud Run (2026-08-25):** جسمٌ ببايتات ليست UTF-8 صالحة يرمي
  //    `FormatException` **خارج أي `try`**، ⟵ **فيصل العميلَ «500 Internal
  //    Server Error» نصّاً خاماً بلا رمز كتالوج** — ⛔ **وهو ما يمنعه
  //    `error-handling-strategy.md` §3 القاعدة 1.**
  //    ★ **والنظام عربيٌّ كلّه**، فكل سببٍ ووصفٍ يعبر هنا بمحارف متعددة
  //    البايتات ⟵ **فبوابةٌ وسيطة تُعيد ترميزه تُسقِط العملية بلا تفسير.**
  final String body;
  try {
    body = await request.readAsString();
  } on FormatException {
    // ⛔ ليس ابتلاعاً: خللُ ترميزٍ في الطلب **خللُ عميل**، ⟵ ويصله رمزٌ صريح.
    return const RejectedCallable(CallableError.invalidArgument);
  }

  final Object? decoded = _tryDecodeJson(body);
  if (decoded is! Map<String, Object?>) {
    return const RejectedCallable(CallableError.invalidArgument);
  }
  final Object? data = decoded['data'];
  if (data is! Map<String, Object?>) {
    return const RejectedCallable(CallableError.invalidArgument);
  }

  return ParsedCallable(CallableRequest(data: data, idToken: idToken));
}

/// استجابة نجاح — `{"result": ...}`.
Response callableSuccess(Map<String, Object?> result) => Response.ok(
      jsonEncode(<String, Object?>{'result': result}),
      headers: _jsonHeaders,
    );

/// استجابة فشل — **بالرمز وحده بلا نص معروض**.
///
/// [detail] وصف تقني **للسجل لا للعرض**، ويُرسَل لأن التطبيق يسجّله كما هو
/// عند التشخيص. ⛔ **ولا يُمرَّر فيه أي مبلغ أو رقم هاتف** —
/// `coding-standards.md` §2.4.
Response callableFailure(CallableError error, {String? detail}) => Response(
      error.httpStatus,
      body: jsonEncode(<String, Object?>{
        'error': <String, Object?>{
          'status': error.status,
          // ⚠️ الرمز لا الرسالة — راجع ترويسة الملف.
          'message': error.code,
          'details': <String, Object?>{
            'code': error.code,
            'detail': ?detail,
          },
        },
      }),
      headers: _jsonHeaders,
    );

const Map<String, String> _jsonHeaders = <String, String>{
  'content-type': 'application/json; charset=utf-8',
};

String? _bearerToken(Request request) {
  final String? header = request.headers['authorization'];
  if (header == null) return null;
  const String prefix = 'Bearer ';
  if (!header.startsWith(prefix)) return null;
  final String token = header.substring(prefix.length).trim();
  return token.isEmpty ? null : token;
}

Object? _tryDecodeJson(String body) {
  if (body.isEmpty) return null;
  try {
    return jsonDecode(body);
  } on FormatException {
    // ⛔ ليس ابتلاعاً: العائد `null` يُترجَم فوراً إلى رفض صريح أعلاه.
    return null;
  }
}

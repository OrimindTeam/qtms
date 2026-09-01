/// السحبيات والخرجيات (`M22`) — **ما يخرج من المحل خارج دورة البيع**.
///
/// ★ **المصدر:** `FR-M22-01` … `FR-M22-20` · `outflow-design.md` ·
/// `schema/outflow-ledger.md` · `ADR-0005` (المصدر مفتاح تقسيم) ·
/// ★ `ADR-0019` (**موضع التقريب الثالث**) · `ADR-0015` (**كل مبلغ صحيح**).
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔★★ **ستُّ قواعد بنيوية يفرضها هذا الملف بنوعه لا بشرطٍ يُنسى:**
///
///   ① ⛔⛔★★★ **لا حركةَ في دفتر حسابات المقاوته إطلاقاً** (`FR-M22-04` ·
///      `GR-44`) — ⟵ **ولا حقلَ مقوتٍ واحد في أي نوعٍ هنا**: ★ **الغياب
///      البنيوي أقوى من شرطٍ يُفحَص**، ⛔ **فلا مسارٌ يُمرِّر مقوتاً سهواً.**
///      ★ **وهي القاعدة نفسُها التي يفرضها `cash_sale.dart`** — ⟵ **والفارق
///      أن البيع النقدي يُدخِل نقداً وهذه تُخرِجه.**
///   ② ⛔⛔★★★ **والمصدر إلزاميٌّ دائماً — حتى لسحبيات المالك الشخصية**
///      (`FR-M22-02` · `GR-42` · `E-28` · `ERR_OUT_001`): ⟵ **ولذلك
///      [OutflowInput.sourceId] **غيرُ قابلٍ للعدم**، ★ **والفراغ يُرفَض
///      نصّاً** ⛔ **ولا «مصدر افتراضي» يُملأ نيابةً عن المستخدم.**
///   ③ ⛔⛔★★★ **وسجلّان منفصلان تماماً** ([OutflowLedgerType]) — `FR-M22-03`
///      · `GR-43`: ★ **ترقيمٌ منفصل** (`WDR-` · `EXP-`) · **وإجمالياتٌ
///      منفصلة** · ★★ **وصلاحيةُ عرضٍ وإنشاءٍ منفصلة لكلٍّ منهما.**
///      ⟵ **والعلّة أمنية لا تصنيفية:** **سحبياتُ المالك بياناتٌ حسّاسة لا
///      يجوز أن يراها كلُّ من يسجّل مصروفاً تشغيلياً.**
///   ④ ★★★ **والسعر اختياريٌّ في سطر القات** (`FR-M22-07` · `E-27`) —
///      ⛔ **بخلاف البيع النقدي** (`FR-M11-04`): ⟵ **فالقات يخرج من المخزن
///      وإن لم يُسعَّر**، ★ **ويدخل البندُ مركزَ الإدخالات المعلّقة**
///      (`FR-SYS-08`) **ويبقى سعرُ الجونية «⏳ غير نهائي».**
///   ⑤ ⛔⛔★★★ **وتمييزٌ تاريخيٌّ لا يُخلَط** (`FR-M22-10` · `GR-49`):
///      ★ **الأثر المالي في تاريخ السند** — ★ **والأثر المخزني لبند القات
///      في تاريخ مخزون البضاعة**. ⟵ **وحقلان مستقلان لا حقلٌ واحد**،
///      ⛔ **والخلطُ بينهما يُنتج تقريراً مالياً صحيحاً بمخزونٍ خاطئ.**
///   ⑥ ⛔ **ولا تُجمع حبّةٌ مع كيلوجرام** (`FR-M22-11` · `GR-19` · `E-31`) —
///      ★ **إجماليان منفصلان دائماً** ([ValidatedOutflow.totalPieces]
///      و[ValidatedOutflow.totalWeight]).
/// ═══════════════════════════════════════════════════════════════════════
///
/// ⚠️⚠️ **ولا معادلةَ ثانية هنا:** ★ **قيمةُ سطر القات [outflowQatLineValue]
/// تُفوِّض إلى [distributionLineTotal]** — **الدالةِ الوحيدة الحاملة للموضع
/// الثالث للتقريب** (`ADR-0019`)، ★ **وتاريخُ السند يُفوِّض إلى
/// [validateReceiptDate]** — ⛔ **ونسخةٌ ثانية من أيٍّ منهما تفترق عن أصلها
/// عند أول تعديل** (`coding-standards.md` §2.2).
library;

import '../../../core/calendar_day.dart';
import '../../../core/document_number.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/money.dart';
import '../../../core/outcome.dart';
import '../../../core/quantity.dart';
import '../../inventory/domain/inventory.dart';
import '../../master_data/domain/master_data.dart'
    show ItemUnit, freeTextMaxLength;
import '../../sales_receivables/domain/distribution.dart'
    show computeDebtValue, distributionLineTotal;
import '../../sales_receivables/domain/receipt.dart' show validateReceiptDate;

/// مجموعة سندات السحبيات والخرجيات — `schema/outflow-ledger.md`.
///
/// ⛔⛔★★ **ومجموعةٌ واحدة للسجلَّين** — ★ **والفصلُ بحقل [OutflowLedgerType]
/// لا بمجموعتين**: ⟵ **وهو ما تفرضه قاعدةُ الحماية القائمة منذ `WU-026`**
/// (`match /outflows/{docId}` **تقرأ `resource.data.ledgerType` وتختار
/// `withdrawalView` أو `expenseView`**) — ⛔ **ومجموعةٌ ثانية كانت ستحتاج
/// قاعدةً ثانية وفهرساً ثانياً بلا فائدةٍ أمنية.**
const String outflowsCollection = 'outflows';

/// دفتر السحبيات والخرجيات — ★ **الدفتر الرابع** (`GR-04`).
const String outflowLedgerCollection = 'outflow_ledger';

/// ★ الحد الأدنى لعدد السطور — **سندٌ بلا سطر لا يُخرِج شيئاً فلا معنى له**.
const int outflowMinLines = 1;

// ═════════════════════════════════════════════════════════════════════════
// ★★★ السجلّان — `FR-M22-03` · `GR-43`
// ═════════════════════════════════════════════════════════════════════════

/// نوع السجل — ⛔⛔ **أساسُ فصل الإجماليات والتقارير والصلاحيات**.
enum OutflowLedgerType {
  /// **سحبية** — ما يسحبه المالك لنفسه · `WDR-YYYYMMDD-####`.
  ///
  /// ⛔⛔★★ **بياناتٌ حسّاسة** (`GR-43` · `E-29`) — ★ **ومن يملك «عرض
  /// الخرجيات» وحدها لا يراها في أي شاشة ولا تقرير ولا بطاقة.**
  withdrawal(DocumentKind.withdrawal),

  /// **خرجية** — ما يُنفَق على تشغيل العمل · `EXP-YYYYMMDD-####`.
  expense(DocumentKind.expense);

  const OutflowLedgerType(this.documentKind);

  /// نوع المستند المرقَّم — ★ **من `naming-conventions.md` §5** عبر
  /// [DocumentKind] ⛔ **ولا بادئةَ تُكتب هنا ثانيةً.**
  final DocumentKind documentKind;
}

/// حالة السند — ★ **حالتان لا أكثر** (بنفس `CashSaleStatus` حرفياً).
enum OutflowStatus {
  /// معتمد — ★ **الحالة الوحيدة للسند الحيّ**.
  approved,

  /// ملغى — ★ **بالوسم** (`FR-M22-18` · `GR-06` · `GR-07` · `A-14`).
  ///
  /// ⛔ **وليس حذفاً:** الحركاتُ تبقى مقروءةً مشطوبة **وتُستبعَد من كل رصيدٍ
  /// وتقرير** بلا حركاتٍ عكسية.
  cancelled,
}

/// فئة السند — `FR-M22-19`.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★ **وكلُّ فئةٍ مقيَّدةٌ بسجلِّها** ([ledgerType]) — ★ **فلا «شُقى
/// الشُقّات» في سحبيةٍ ولا «قات» فئةً لخرجية**: ⟵ **والقائمتان في `FR-M22-19`
/// منفصلتان نصّاً**، ⛔ **وقائمةٌ واحدة كانت ستُتيح تصنيفاً يُفسِد التقارير
/// المنفصلة التي وُجد السجلّان لأجلها** (`FR-M22-16`).
///
/// ⚠️★★ **و«حدٌّ أدنى قابل للتوسعة» بنصّ المتطلب** — ★ **والتوسعةُ من
/// التهيئة مرحلةٌ رابعة** (`requirements-traceability-matrix.md` §6):
/// ⛔ **فلا تُخترَع فئةٌ هنا اليوم**، ★ **والسبعُ منقولةٌ من `FR-M22-19`
/// حرفاً بحرف.**
/// ═══════════════════════════════════════════════════════════════════════
enum OutflowCategory {
  /// سحبية — **قات**.
  withdrawalQat(OutflowLedgerType.withdrawal, 'قات'),

  /// سحبية — **مبلغ مالي**.
  withdrawalCash(OutflowLedgerType.withdrawal, 'مبلغ مالي'),

  /// سحبية — **أخرى**.
  withdrawalOther(OutflowLedgerType.withdrawal, 'أخرى'),

  /// خرجية — **شُقى الشُقّات**.
  expenseShareCuts(OutflowLedgerType.expense, 'شُقى الشُقّات'),

  /// خرجية — **قات للشُقّات**.
  expenseQatForShares(OutflowLedgerType.expense, 'قات للشُقّات'),

  /// خرجية — **مبالغ مالية**.
  expenseCash(OutflowLedgerType.expense, 'مبالغ مالية'),

  /// خرجية — **مصروف تشغيلي آخر**.
  expenseOperating(OutflowLedgerType.expense, 'مصروف تشغيلي آخر');

  const OutflowCategory(this.ledgerType, this.label);

  /// السجل الذي تنتمي إليه هذه الفئة — ⛔ **ولا فئةَ في غير سجلِّها.**
  final OutflowLedgerType ledgerType;

  /// ★ الاسم المعروض — **عربيٌّ من نصّ المتطلب** (`ui-guidelines.md` §6).
  final String label;

  /// فئات سجلٍّ بعينه — **لقوائم الواجهة** ⛔ **بلا تصفيةٍ مكتوبةٍ في شاشة.**
  static List<OutflowCategory> of(OutflowLedgerType ledger) =>
      <OutflowCategory>[
        for (final OutflowCategory category in OutflowCategory.values)
          if (category.ledgerType == ledger) category,
      ];
}

/// نوع البند — `FR-M22-05` (**ثلاثة أنواع لا أكثر**).
enum OutflowLineKind {
  /// ① **قات** — ⟵ **خروجٌ مخزني + قيمتُه تدخل سعر الجونية** (`FR-M22-06`).
  qat,

  /// ② **مبلغ مالي** — ⟵ **خروجٌ نقدي بلا أثرٍ مخزني**.
  amount,

  /// ③ **أخرى** (وصف + مبلغ) — ⟵ **خروجٌ نقدي بلا أثرٍ مخزني**.
  ///
  /// ⛔★ **والوصف إلزاميٌّ فيها وحدها** — `FR-M22-05` ③ ينصّ عليه صراحةً
  /// («**وصف + مبلغ**») ⛔ **بخلاف [amount]** التي يذكرها المتطلب بلا وصف.
  other,
}

// ═════════════════════════════════════════════════════════════════════════
// ★★★ المعادلات — `outflow-design.md` §3 · `GR-42`
// ═════════════════════════════════════════════════════════════════════════

/// ★★★ **قيمة سطر القات** — `الكمية × سعر الوحدة` أو `null` لغير المسعَّر.
///
/// ⛔⛔★★★ **وتُفوِّض إلى [distributionLineTotal] ولا تُعيد كتابتها** —
/// ★ **تلك هي الدالةُ الوحيدة الحاملة للموضع الثالث للتقريب** (`ADR-0019`):
/// ⟵ **ونسخةٌ ثانية بمعادلةٍ مطابقة تفترق عن أصلها عند أول تعديل**
/// (`coding-standards.md` §2.2 · نصُّ `CLAUDE.md`).
///
/// ★ **والعدمُ هنا مقصود** (`FR-M22-07`) — ⛔ **بخلاف `cashSaleLineTotal`**:
/// ⟵ **فبندُ قاتٍ بلا سعرٍ يُحفَظ ويخرج من المخزن** ⛔ **ولا يدخل الإجمالي.**
Money? outflowQatLineValue({
  required StockQuantity quantity,
  required Money? unitPrice,
}) =>
    distributionLineTotal(quantity: quantity, unitPrice: unitPrice);

/// ★★★ **الإجمالي النهائي للسند** — `GR-42` · `AT-38`.
///
/// ```text
/// الإجمالي النهائي = إجمالي قيمة القات + إجمالي المبالغ
/// ```
///
/// ★ **ومثالُ `AT-38` حرفياً:** `5 حبات × 1,500` **+** `20,000 نقداً`
/// ⟹ **27,500**.
///
/// ⛔⛔★★ **والسطرُ غيرُ المسعَّر لا يدخل** (`FR-M22-07`) — ★ **ولا يُعامَل
/// صفراً**: ⟵ **وصفرٌ كان سيُظهر إجمالياً يبدو نهائياً وهو ناقص**،
/// ⛔ **بينما [ValidatedOutflow.unpricedItemCount] يُعلن النقصَ صراحةً.**
Money outflowGrandTotal({
  required Money totalQatValue,
  required Money totalCashValue,
}) =>
    totalQatValue + totalCashValue;

// ═════════════════════════════════════════════════════════════════════════
// التحقق — `error-handling-strategy.md` §3 (**تُرجَع نتيجةً لا تُرمى**)
// ═════════════════════════════════════════════════════════════════════════

/// ★★★ **تاريخ السند** — `FR-M22-09` · `BR-M22-06` · `AT-56`.
///
/// ```text
/// مستقبلي            ⟵ مرفوض دائماً بلا استثناء ولأي مستخدم
/// سابق بلا صلاحية    ⟵ مرفوض
/// سابق بصلاحية       ⟵ مقبول
/// اليوم              ⟵ مقبول
/// ```
///
/// ⛔⛔★★ **وتُفوِّض إلى [validateReceiptDate] حرفياً** — ★ **فالقاعدة واحدة
/// في `M12` و`M13` و`M22`**: ⟵ **وثلاثُ نسخٍ منها تفترق عند أول تعديل**،
/// ★ **والمُفارقُ الوحيد رمزُ القاعدة المُرجَع** فيُترجَم هنا ⛔ **لا يُعاد
/// بناء الشرط.**
Outcome<void> validateOutflowDate({
  required CalendarDay date,
  required CalendarDay today,
  required bool canBackdate,
}) {
  final Outcome<void> result = validateReceiptDate(
    date: date,
    today: today,
    canBackdate: canBackdate,
  );
  return switch (result) {
    // ★ **خطأُ الصلاحية يمرّ كما هو** — ⛔ **فلا رمزَ قاعدةٍ فيه أصلاً.**
    Failure<void>(error: PermissionError()) => result,
    Failure<void>() => const Failure<void>(ValidationError('BR-M22-06')),
    Success<void>() => result,
  };
}

/// ★ يفحص أن السند غير ملغى — `ERR_AMEND_006` (`FR-M22-18` · `A-14`).
///
/// ⛔ **والملغى لا يُعدَّل ولا يُلغى ثانيةً:** ⟵ **إعادةُ كميةٍ إلى الرصيد من
/// مستندٍ خرج من الحساب فسادُ رصيدٍ صامت.**
Outcome<void> validateOutflowNotCancelled(OutflowStatus status) =>
    status == OutflowStatus.cancelled
        ? const Failure<void>(ValidationError('FR-M22-18'))
        : const Success<void>(null);

// ═════════════════════════════════════════════════════════════════════════
// السطور والمستند
// ═════════════════════════════════════════════════════════════════════════

/// سطرُ **قات** كما يصل من الواجهة — **قبل أي تحقق**.
final class OutflowQatLineInput {
  /// ينشئ المدخلات.
  const OutflowQatLineInput({
    required this.itemId,
    required this.itemName,
    required this.unit,
    required this.quantity,
    this.unitPrice,
    this.sackId,
  });

  /// معرّف النوع — ★ **وهو `itemKey` في الدفتر** (نفس قاعدة `FR-M6-09`).
  final String itemId;

  /// اسم النوع المعروض — ★ **نسخةٌ مقصودة** (`naming-conventions.md` §4).
  final String itemName;

  /// وحدة النوع — ★ **مقروءةٌ من سجل النوع** ⛔ **لا مُدخَلة** (`FR-M5-03`).
  final ItemUnit unit;

  /// ★ الكمية **بوحدتها في النوع** — `GR-19` · `FR-M22-11`.
  final StockQuantity quantity;

  /// ★★★ سعر الوحدة — ⛔ **اختياريٌّ** (`FR-M22-07` · `E-27`).
  ///
  /// ⚠️⚠️ **وغيابُه ليس صفراً:** ⟵ **السطرُ يخرج من المخزن ولا يدخل
  /// الإجمالي**، ★ **ويُنشئ بنداً في مركز الإدخالات المعلّقة** (`FR-SYS-08`).
  final Money? unitPrice;

  /// ★ **الجونية التي ينتمي إليها النوع** أو `null` — `FR-M22-06` · `A-13`.
  ///
  /// ⚠️⚠️ **وغيابُه عن سطرٍ من جونية يُسقِط الجونيةَ من احتساب سعرها بصمت**
  /// — ★ **فقيمةُ السحبية تدخل سعرَ الجونية** فيستحق الرعوي ثمنَها (`E-26`).
  final String? sackId;
}

/// سطرُ **مبلغ** أو **أخرى** كما يصل من الواجهة.
final class OutflowCashLineInput {
  /// ينشئ المدخلات.
  const OutflowCashLineInput({
    required this.kind,
    required this.amount,
    this.description,
  });

  /// نوع البند — ⛔ **و[OutflowLineKind.qat] مرفوضٌ هنا**: له نوعُه.
  final OutflowLineKind kind;

  /// المبلغ الخارج — ⛔ **موجبٌ تماماً**.
  final Money amount;

  /// الوصف — ★ **إلزاميٌّ لـ[OutflowLineKind.other] وحدها** (`FR-M22-05` ③).
  final String? description;
}

/// سطرُ قاتٍ مُتحقَّق منه.
final class ValidatedOutflowQatLine {
  /// ينشئ السطر.
  const ValidatedOutflowQatLine({
    required this.itemId,
    required this.itemName,
    required this.quantity,
    required this.unitPrice,
    required this.sackId,
  });

  /// معرّف النوع.
  final String itemId;

  /// ★ **مفتاح النوع في الدفتر** — **المعرّف لا الاسم** (`FR-M5-01`).
  String get itemKey => itemId;

  /// الاسم المعروض لحظة الإدخال.
  final String itemName;

  /// الكمية بوحدتها.
  final StockQuantity quantity;

  /// السعر المُجمَّد أو `null` — `FR-M22-07`.
  final Money? unitPrice;

  /// الجونية أو `null`.
  final String? sackId;

  /// ★★ قيمة السطر أو `null` — **الدالة الوحيدة** ([outflowQatLineValue]).
  Money? get lineValue =>
      outflowQatLineValue(quantity: quantity, unitPrice: unitPrice);

  /// ★ هل السطر بلا سعر؟ — ⟵ **وهو ما يُنشئ بندَ المركز المعلّق.**
  bool get isUnpriced => unitPrice == null;
}

/// سطرُ مبلغٍ مُتحقَّق منه.
final class ValidatedOutflowCashLine {
  /// ينشئ السطر.
  const ValidatedOutflowCashLine({
    required this.kind,
    required this.amount,
    required this.description,
  });

  /// نوع البند — [OutflowLineKind.amount] أو [OutflowLineKind.other].
  final OutflowLineKind kind;

  /// المبلغ الخارج.
  final Money amount;

  /// الوصف أو `null` — ⛔ **والفارغ غيابٌ لا نصٌّ فارغ** (`ADR-0020`).
  final String? description;
}

/// مدخلات سندِ سحبيةٍ أو خرجية — ⛔ **بلا مقوتٍ ولا ذمّة**.
final class OutflowInput {
  /// ينشئ المدخلات.
  const OutflowInput({
    required this.ledgerType,
    required this.sourceId,
    required this.category,
    this.qatLines = const <OutflowQatLineInput>[],
    this.cashLines = const <OutflowCashLineInput>[],
    this.notes,
  });

  /// السجل — `FR-M22-03`.
  final OutflowLedgerType ledgerType;

  /// ★★★ المصدر — ⛔ **إلزاميٌّ دائماً** (`FR-M22-02` · `GR-42` · `E-28`).
  final String sourceId;

  /// الفئة — ⛔ **ومن فئات سجلِّها وحدها** (`FR-M22-19`).
  final OutflowCategory category;

  /// سطور القات — قد تكون فارغة.
  final List<OutflowQatLineInput> qatLines;

  /// سطور المبالغ — قد تكون فارغة.
  final List<OutflowCashLineInput> cashLines;

  /// بيان السند.
  final String? notes;
}

/// سندُ سحبيةٍ أو خرجية مُتحقَّق منه — **جاهز للكتابة كما هو**.
final class ValidatedOutflow {
  /// ينشئ السند.
  ValidatedOutflow({
    required this.ledgerType,
    required this.sourceId,
    required this.category,
    required this.notes,
    required List<ValidatedOutflowQatLine> qatLines,
    required List<ValidatedOutflowCashLine> cashLines,
  })  : qatLines = List<ValidatedOutflowQatLine>.unmodifiable(qatLines),
        cashLines = List<ValidatedOutflowCashLine>.unmodifiable(cashLines);

  /// السجل.
  final OutflowLedgerType ledgerType;

  /// المصدر.
  final String sourceId;

  /// الفئة.
  final OutflowCategory category;

  /// بيان السند أو `null`.
  final String? notes;

  /// سطور القات **مرتَّبةً بمفتاح النوع** — ★ **فنفس الإدخال يُنتج نفس
  /// المستند** في كل تشغيل (`coding-standards.md` §2.7).
  final List<ValidatedOutflowQatLine> qatLines;

  /// سطور المبالغ **بترتيب إدخالها** — ⛔ **ولا مفتاحَ لها يُرتَّب به.**
  final List<ValidatedOutflowCashLine> cashLines;

  /// ★ إجمالي الحبّات — ⛔ **ولا يُجمع مع [totalWeight] أبداً** (`GR-19`).
  PieceCount get totalPieces {
    PieceCount total = PieceCount.zero;
    for (final ValidatedOutflowQatLine line in qatLines) {
      if (line.quantity case PieceQuantity(:final PieceCount count)) {
        total = total + count;
      }
    }
    return total;
  }

  /// ★ إجمالي الأوزان — ⛔ **ولا يُجمع مع [totalPieces] أبداً** (`GR-19`).
  WeightKg get totalWeight {
    WeightKg total = WeightKg.zero;
    for (final ValidatedOutflowQatLine line in qatLines) {
      if (line.quantity case WeightQuantity(:final WeightKg weight)) {
        total = total + weight;
      }
    }
    return total;
  }

  /// ★★ **إجمالي قيمة القات** — ⛔ **والسطرُ غيرُ المسعَّر خارجَه** (`FR-M22-07`).
  Money get totalQatValue => computeDebtValue(<Money>[
        for (final ValidatedOutflowQatLine line in qatLines)
          if (line.lineValue case final Money value) value,
      ]);

  /// ★★ **إجمالي المبالغ** — ★ **نقدٌ يخرج بلا أثرٍ مخزني.**
  Money get totalCashValue => computeDebtValue(<Money>[
        for (final ValidatedOutflowCashLine line in cashLines) line.amount,
      ]);

  /// ★★★ **الإجمالي النهائي** — [outflowGrandTotal] (`GR-42` · `AT-38`).
  Money get grandTotal => outflowGrandTotal(
        totalQatValue: totalQatValue,
        totalCashValue: totalCashValue,
      );

  /// ★★ **عدد بنود القات بلا سعر** — ⟵ **وهو ما يُعلَن في المركز المعلّق**
  /// (`FR-SYS-08` · `AT-41`) ⛔ **ولا يُبتلَع في إجماليٍّ يبدو نهائياً.**
  int get unpricedItemCount => qatLines
      .where((ValidatedOutflowQatLine line) => line.isUnpriced)
      .length;

  /// ★ هل يمسّ السند المخزون؟ — ⟵ **سندُ مبالغَ خالصٍ لا يمسّه.**
  bool get touchesInventory => qatLines.isNotEmpty;
}

/// يفحص سندَ سحبيةٍ أو خرجية — `FR-M22-01` … `FR-M22-13`.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ★★ **ثمانية قيود تُفحَص هنا:**
///
///   ① ⛔⛔★★★ **المصدر إلزامي** (`FR-M22-02` · `E-28`) — ★ **حتى لسحبيات
///      المالك**: ⟵ **ورمزُه المستقل `ERR_OUT_001`** ⛔ **لا `ERR_CALL_400`
///      العام**: ★ **فالمستخدم يقرأ الحقل الذي عليه ملؤه.**
///   ② **سطرٌ واحد على الأقل** — قاتاً كان أو مبلغاً.
///   ③ ⛔ **والفئة من فئات سجلِّها** (`FR-M22-19`) — ★ **فلا «شُقى الشُقّات»
///      في سحبية.**
///   ④ ⛔ **لا سطران لنفس النوع** — ★ **والواجهة تدمجهما قبل أن تصل هنا.**
///   ⑤ ★★ **كمية القات موجبة تماماً** — ⛔ **والصفر ليس سحباً، والسالب
///      إدخالٌ لا سحب.**
///   ⑥ ⛔ **ووحدة الكمية = وحدة النوع** (`GR-19` · `E-31`) — ★ **فلا تُحوَّل
///      حبّةٌ إلى كيلوجرام صامتاً.**
///   ⑦ ★★ **والسعر — إن وُجد — موجبٌ تماماً**: ⛔ **والصفر ليس سعراً**،
///      ⟵ **وسطرٌ بصفر يُقيِّد خروجاً بقيمةٍ صفرية فيُفسِد سعر الجونية**
///      ⛔ **بينما غيابُ السعر يُعلَن نقصاً صريحاً** (`FR-M22-07`).
///   ⑧ ★★ **ومبلغ السطر النقدي موجبٌ تماماً** · ★ **والوصف إلزاميٌّ لـ
///      [OutflowLineKind.other] وحدها** (`FR-M22-05` ③).
/// ═══════════════════════════════════════════════════════════════════════
///
/// ⛔⛔★★ **ولا يُفحَص كفايةُ الرصيد هنا** — ★ **مرجعُه دفترُ المخزون**،
/// ⟵ **ويُقاس داخل المعاملة السحابية** (`FR-M22-12` · `GR-11`) ⛔ **لا من
/// قيمةٍ يُرسِلها الجهاز**: ★ **وإلا لكفى تعديلُ الحمولة لتجاوزه.**
Outcome<ValidatedOutflow> validateOutflow(OutflowInput input) {
  final String sourceId = input.sourceId.trim();
  // ① ⛔⛔★★★ **المصدر إلزامي — حتى لسحبيات المالك** (`GR-42` · `ERR_OUT_001`).
  if (sourceId.isEmpty) {
    return const Failure<ValidatedOutflow>(ValidationError('FR-M22-02'));
  }
  if (input.qatLines.length + input.cashLines.length < outflowMinLines) {
    return const Failure<ValidatedOutflow>(ValidationError('FR-M22-01'));
  }
  // ③ ⛔ **والفئة من فئات سجلِّها وحدها** — `FR-M22-19`.
  if (input.category.ledgerType != input.ledgerType) {
    return const Failure<ValidatedOutflow>(ValidationError('FR-M22-19'));
  }

  final Outcome<List<ValidatedOutflowQatLine>> qat =
      _validateQatLines(input.qatLines);
  if (qat case Failure<List<ValidatedOutflowQatLine>>(:final AppError error)) {
    return Failure<ValidatedOutflow>(error);
  }

  final Outcome<List<ValidatedOutflowCashLine>> cash =
      _validateCashLines(input.cashLines);
  if (cash case Failure<List<ValidatedOutflowCashLine>>(:final AppError error)) {
    return Failure<ValidatedOutflow>(error);
  }

  final Outcome<String?> notes = _optionalText(input.notes);
  if (notes case Failure<String?>(:final AppError error)) {
    return Failure<ValidatedOutflow>(error);
  }

  return Success<ValidatedOutflow>(
    ValidatedOutflow(
      ledgerType: input.ledgerType,
      sourceId: sourceId,
      category: input.category,
      notes: (notes as Success<String?>).value,
      qatLines: (qat as Success<List<ValidatedOutflowQatLine>>).value,
      cashLines: (cash as Success<List<ValidatedOutflowCashLine>>).value,
    ),
  );
}

Outcome<List<ValidatedOutflowQatLine>> _validateQatLines(
  List<OutflowQatLineInput> raw,
) {
  final Set<String> seen = <String>{};
  final List<ValidatedOutflowQatLine> validated = <ValidatedOutflowQatLine>[];

  for (final OutflowQatLineInput line in raw) {
    final String itemId = line.itemId.trim();
    if (itemId.isEmpty) {
      return const Failure<List<ValidatedOutflowQatLine>>(
        ValidationError('FR-M22-05'),
      );
    }
    // ④ ⛔ **لا سطران لنفس النوع** — ★ **والواجهة تدمجهما مع تنبيه.**
    if (!seen.add(itemId)) {
      return const Failure<List<ValidatedOutflowQatLine>>(
        ValidationError('BR-M10-15'),
      );
    }
    // ⑥ ⛔ **ووحدة الكمية = وحدة النوع** — `GR-19` · `E-31`.
    if (line.quantity.unit != line.unit) {
      return const Failure<List<ValidatedOutflowQatLine>>(
        ValidationError('GR-19'),
      );
    }
    // ⑤ ★★ **الكمية موجبة تماماً**.
    if (!line.quantity.isPositive) {
      return const Failure<List<ValidatedOutflowQatLine>>(
        ValidationError('BR-M22-09'),
      );
    }
    final String name = line.itemName.trim();
    if (name.isEmpty) {
      return const Failure<List<ValidatedOutflowQatLine>>(
        ValidationError('FR-M22-05'),
      );
    }
    // ⑦ ★★ **والسعر — إن وُجد — موجبٌ تماماً** — ⛔ **والغياب مقبولٌ**.
    final Money? unitPrice = line.unitPrice;
    if (unitPrice != null && unitPrice.riyals <= 0) {
      return const Failure<List<ValidatedOutflowQatLine>>(
        ValidationError('FR-M22-07'),
      );
    }

    validated.add(
      ValidatedOutflowQatLine(
        itemId: itemId,
        itemName: name,
        quantity: line.quantity,
        unitPrice: unitPrice,
        sackId: line.sackId,
      ),
    );
  }

  validated.sort(
    (ValidatedOutflowQatLine a, ValidatedOutflowQatLine b) =>
        a.itemKey.compareTo(b.itemKey),
  );
  return Success<List<ValidatedOutflowQatLine>>(validated);
}

Outcome<List<ValidatedOutflowCashLine>> _validateCashLines(
  List<OutflowCashLineInput> raw,
) {
  final List<ValidatedOutflowCashLine> validated = <ValidatedOutflowCashLine>[];

  for (final OutflowCashLineInput line in raw) {
    // ⛔ **و[OutflowLineKind.qat] له نوعُه المستقل** — ⟵ **فوصولُه هنا خللٌ
    //    في المُستدعي لا مُدخَلٌ من مستخدم.**
    if (line.kind == OutflowLineKind.qat) {
      return const Failure<List<ValidatedOutflowCashLine>>(
        ValidationError('FR-M22-05'),
      );
    }
    // ⑧ ★★ **المبلغ موجبٌ تماماً**.
    if (line.amount.isZero || line.amount.isNegative) {
      return const Failure<List<ValidatedOutflowCashLine>>(
        ValidationError('FR-M22-05'),
      );
    }
    final Outcome<String?> description = _optionalText(line.description);
    if (description case Failure<String?>(:final AppError error)) {
      return Failure<List<ValidatedOutflowCashLine>>(error);
    }
    final String? text = (description as Success<String?>).value;
    // ★ **والوصف إلزاميٌّ لـ«أخرى» وحدها** — `FR-M22-05` ③.
    if (line.kind == OutflowLineKind.other && text == null) {
      return const Failure<List<ValidatedOutflowCashLine>>(
        ValidationError('FR-M22-05'),
      );
    }

    validated.add(
      ValidatedOutflowCashLine(
        kind: line.kind,
        amount: line.amount,
        description: text,
      ),
    );
  }

  return Success<List<ValidatedOutflowCashLine>>(validated);
}

/// ★ نصٌّ اختياري — ⛔ **والفراغ غيابٌ لا نصٌّ فارغ** (`ADR-0020`).
Outcome<String?> _optionalText(String? value) {
  final String? text = value?.trim();
  if (text == null || text.isEmpty) return const Success<String?>(null);
  if (text.length > freeTextMaxLength) {
    return const Failure<String?>(ValidationError('GR-49'));
  }
  return Success<String?>(text);
}

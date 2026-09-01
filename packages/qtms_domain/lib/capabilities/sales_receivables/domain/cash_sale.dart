/// البيع النقدي المباشر (`M11`) — **نقدٌ فوري بلا مقوت وبلا دين**.
///
/// ★ **المصدر:** `FR-M11-01` … `FR-M11-15` · `distribution-design.md` §5 ·
/// `design-overview.md` §2.6 · `schema/cash-sales.md` ·
/// `ADR-0005` (المصدر مفتاح تقسيم) · ★ `ADR-0019` (**موضع التقريب الثالث**).
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔★★ **خمس قواعد بنيوية يفرضها هذا الملف بنوعه لا بشرطٍ يُنسى:**
///
///   ① ⛔⛔★★★ **لا حركةَ في دفتر حسابات المقاوته إطلاقاً** (`FR-M11-03` ·
///      `GR-33`) — ⟵ **ولا حقلَ مقوتٍ واحد في أي نوعٍ هنا**: ★ **الغياب
///      البنيوي أقوى من شرطٍ يُفحَص**، ⛔ **فلا مسارٌ يُمرِّر مقوتاً سهواً.**
///   ② ★★★ **السعر إلزاميٌّ في كل سطر** (`FR-M11-04`) — ⟵ **ولذلك
///      [CashSaleLineInput.unitPrice] **غيرُ قابلٍ للعدم**، ⛔ **بخلاف
///      التوزيع الذي يقبل «تسعيراً لاحقاً»** (`FR-M10-08`): ★ **«لا يوجد
///      بيع نقدي غير مسعَّر»** نصّاً.
///   ③ ⛔ **لا اسمَ مشترٍ ولا حقلَ خصم** (`FR-M11-12` · `ت-06`) — ★ **حقلان
///      غائبان قصداً**: **المشتري عابرٌ بلا حساب، والخصم يُدخَل بالسعر
///      النهائي مباشرةً.**
///   ④ ⛔ **لا تُجمع حبّةٌ مع كيلوجرام** (`GR-19` · `FR-M11-14`) — ★ **إجماليان
///      منفصلان دائماً** ([ValidatedCashSale.totalPieces] و[ValidatedCashSale.totalWeight]).
///   ⑤ ★★ **الحد الأدنى يُقاس من سعر اليوم المخزَّن** ([isBelowMinimumCashPrice])
///      — ⛔ **لا من قيمةٍ يُرسِلها الجهاز**، ★ **والتجاوز يشترط
///      `cashSaleBelowMinimum`** (`FR-M11-05` · `GR-34`).
/// ═══════════════════════════════════════════════════════════════════════
///
/// ⚠️⚠️ **ولا معادلةَ ثانية هنا:** ★ **قيمةُ السطر [cashSaleLineTotal]
/// تُفوِّض إلى [distributionLineTotal]** — **الدالةِ الوحيدة الحاملة للموضع
/// الثالث للتقريب** (`ADR-0019`)، ⛔ **ونسخةٌ ثانية منها كانت تفترق عنها عند
/// أول تعديل** (`coding-standards.md` §2.2).
library;

import '../../../core/errors/app_error.dart';
import '../../../core/money.dart';
import '../../../core/outcome.dart';
import '../../../core/quantity.dart';
import '../../inventory/domain/inventory.dart';
import '../../master_data/domain/master_data.dart' show ItemUnit, freeTextMaxLength;
import 'distribution.dart'
    show DistributionStatus, computeDebtValue, distributionLineTotal;

/// مجموعة سندات البيع النقدي — `schema/cash-sales.md`.
///
/// ★ **ومفتاحُها `documentNumber` نفسُه** (`CSH-YYYYMMDD-####`) — ⛔ **ولا
/// معرّفَ مركّب بخلاف التوزيعة**: ⟵ **لأن `GR-18` قيدُ ضمارٍ لمقوت**،
/// ★ **والبيعُ النقدي بلا مقوتٍ أصلاً** ⟹ **فلا وحدانيةَ تُفرَض على مفتاح.**
const String cashSalesCollection = 'cash_sales';

/// حالة سند البيع النقدي — ★ **حالتان لا أربع**.
///
/// ⛔⛔★★ **ولا «مسعَّر جزئياً» هنا** (بخلاف [DistributionStatus]) — `FR-M11-04`:
/// **التسعير إلزاميٌّ داخل المستند نفسه**، ⟵ **فسندٌ محفوظٌ سندٌ مسعَّرٌ
/// بالكامل** ⛔ **ولا حالةَ وسطى ممكنة.**
enum CashSaleStatus {
  /// معتمد — ★ **وهي الحالة الوحيدة للسند الحيّ**.
  approved,

  /// ملغى — ★ **بالوسم** (`FR-M11-13` · `GR-06` · `GR-07`).
  ///
  /// ⛔ **وليس حذفاً:** الحركاتُ تبقى مقروءةً مشطوبة، ⟵ **وتُستبعَد من كل
  /// رصيدٍ وتقرير** بلا حركاتٍ عكسية (`A-14`).
  cancelled,
}

// ═════════════════════════════════════════════════════════════════════════
// ★★★ المعادلة — `design-overview.md` §2.6
// ═════════════════════════════════════════════════════════════════════════

/// ★★★ **قيمة السطر** — `الكمية × سعر الوحدة` (`design-overview.md` §2.6).
///
/// ⛔⛔★★★ **وتُفوِّض إلى [distributionLineTotal] ولا تُعيد كتابتها** —
/// ★ **تلك هي الدالةُ الوحيدة الحاملة للموضع الثالث للتقريب** (`ADR-0019`):
/// ⟵ **ونسخةٌ ثانية بمعادلةٍ مطابقة تفترق عن أصلها عند أول تعديل**،
/// ⛔ **وهو ما يمنعه `coding-standards.md` §2.2 ونصُّ `CLAUDE.md` («لا تكرار
/// لأي معادلة خارج طبقة النطاق»).**
///
/// ★ **والفارقُ الوحيد عن التوزيع أن السعر هنا غيرُ قابلٍ للعدم** —
/// `FR-M11-04`: ⟵ **فالناتج غيرُ قابلٍ للعدم كذلك**، ⛔ **ولا يعبر `null`
/// إلى إجمالي سندٍ نقدي.**
Money cashSaleLineTotal({
  required StockQuantity quantity,
  required Money unitPrice,
}) =>
    distributionLineTotal(quantity: quantity, unitPrice: unitPrice)!;

/// ★★ **صافي المقبوض** — `Σ(قيم السطور)` (`design-overview.md` §2.6).
///
/// ★ **ويُفوِّض إلى [computeDebtValue]** — ⟵ **فموضعُ الجمع واحد**،
/// ⛔ **ولا حلقةُ جمعٍ ثانية.** ★ **والفارق أن كل سطرٍ هنا مسعَّرٌ حتماً**
/// (`FR-M11-04`) ⟹ **فلا سطرَ يسقط من الجمع** — ⛔ **بخلاف قيمة الضمار
/// التي تُسقِط غير المسعَّر** (`FR-M10-05`).
Money computeNetCashReceived(Iterable<Money> lineTotals) =>
    computeDebtValue(lineTotals);

/// ★★★ **هل السعر دون الحد الأدنى؟** — `FR-M11-05` · `GR-34`.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★ **والغياب ليس تجاوزاً** (`FR-M11-06`): ★ **نوعٌ بلا حدٍّ أدنى
/// مسجَّل يُباع بتنبيه** ⟵ **ويبقى في مركز الإدخالات المعلّقة**،
/// ⛔ **ولا يُعامَل «دون الحد» فيُطلَب له مفتاحُ تجاوز لا معنى له.**
///
/// ★★ **ودالةٌ واحدة لا شرطٌ يتكرر** — ⟵ **الشاشةُ تُنبِّه بها والسحابةُ
/// تحرس بها** (`coding-standards.md` §2.2): ⛔ **وشرطان متطابقان في موضعين
/// يفترقان عند أول حالةٍ حدّية** (المساواةُ بالحد تحديداً: ★ **«لا يقلّ عن»
/// ⟹ المساواةُ مقبولة**).
/// ═══════════════════════════════════════════════════════════════════════
bool isBelowMinimumCashPrice({
  required Money unitPrice,
  required Money? minCashPrice,
}) =>
    minCashPrice != null && unitPrice < minCashPrice;

// ═════════════════════════════════════════════════════════════════════════
// السطور والمستند
// ═════════════════════════════════════════════════════════════════════════

/// سطر بيعٍ نقدي كما يصل من الواجهة — **قبل أي تحقق**.
final class CashSaleLineInput {
  /// ينشئ المدخلات.
  const CashSaleLineInput({
    required this.itemId,
    required this.itemName,
    required this.unit,
    required this.quantity,
    required this.unitPrice,
    this.sackId,
    this.belowMinReason,
  });

  /// معرّف النوع — ★ **وهو `itemKey` في الدفتر** (نفس قاعدة `FR-M6-09`).
  final String itemId;

  /// اسم النوع المعروض — ★ **نسخةٌ مقصودة** (`naming-conventions.md` §4).
  final String itemName;

  /// وحدة النوع — ★ **مقروءةٌ من سجل النوع** ⛔ **لا مُدخَلة** (`FR-M5-03`).
  final ItemUnit unit;

  /// ★ الكمية **بوحدتها في النوع** — `GR-19` · `FR-M11-11`.
  final StockQuantity quantity;

  /// ★★★ سعر الوحدة — ⛔ **إلزاميٌّ ولا يقبل العدم** (`FR-M11-04`).
  final Money unitPrice;

  /// ★ **الجونية التي ينتمي إليها النوع** أو `null` — `FR-M11-09` · `A-13`.
  ///
  /// ⚠️⚠️ **وغيابُه عن سطرٍ من جونية يُسقِط الجونيةَ من احتساب سعرها بصمت**
  /// — ★ **فقيمةُ البيع النقدي تدخل سعرَ الجونية** فيستحق الرعوي ثمنَها.
  final String? sackId;

  /// ★ سبب البيع دون الحد الأدنى — ⛔ **اختياريٌّ** (`ADR-0020`).
  ///
  /// ⛔⛔★★ **والصلاحيةُ وحدها هي الحارس** (`cashSaleBelowMinimum`) —
  /// `error-codes-catalog.md`: **`ERR_PRICE_003` لم يعد يُصدَر**،
  /// ⟵ **ولا يُرفَض بيعٌ لغياب السبب** ⛔ **ولا يُعبَّأ نيابةً عن المستخدم.**
  final String? belowMinReason;
}

/// سطر بيعٍ نقدي مُتحقَّق منه.
final class ValidatedCashSaleLine {
  /// ينشئ السطر.
  const ValidatedCashSaleLine({
    required this.itemId,
    required this.itemName,
    required this.quantity,
    required this.unitPrice,
    required this.sackId,
    required this.belowMinReason,
  });

  /// معرّف النوع.
  final String itemId;

  /// ★ **مفتاح النوع في الدفتر** — **المعرّف لا الاسم** (`FR-M5-01`).
  String get itemKey => itemId;

  /// الاسم المعروض لحظة الإدخال.
  final String itemName;

  /// الكمية بوحدتها.
  final StockQuantity quantity;

  /// ★★★ السعر المُجمَّد — ⛔ **ولا يقبل العدم** (`FR-M11-04`).
  final Money unitPrice;

  /// الجونية أو `null`.
  final String? sackId;

  /// سبب البيع دون الحد الأدنى أو `null` — ⛔ **والفارغ غيابٌ لا نصٌّ فارغ**.
  final String? belowMinReason;

  /// ★★ قيمة السطر — **الدالة الوحيدة** ([cashSaleLineTotal]).
  Money get lineTotal =>
      cashSaleLineTotal(quantity: quantity, unitPrice: unitPrice);
}

/// مدخلات سند بيعٍ نقدي — ⛔ **بلا مقوتٍ ولا مشترٍ ولا خصم**.
final class CashSaleInput {
  /// ينشئ المدخلات.
  const CashSaleInput({
    required this.sourceId,
    required this.lines,
    this.notes,
  });

  /// المصدر — ★ **إلزامي، ومنه يُخصَم المخزون** (`FR-M11-02`).
  final String sourceId;

  /// سطور السند — ⛔ **ولا فارغة**.
  final List<CashSaleLineInput> lines;

  /// ملاحظات السند.
  final String? notes;
}

/// سند بيعٍ نقدي مُتحقَّق منه — **جاهز للكتابة كما هو**.
final class ValidatedCashSale {
  /// ينشئ السند.
  ValidatedCashSale({
    required this.sourceId,
    required this.notes,
    required List<ValidatedCashSaleLine> lines,
  }) : lines = List<ValidatedCashSaleLine>.unmodifiable(lines);

  /// المصدر.
  final String sourceId;

  /// ملاحظات السند أو `null`.
  final String? notes;

  /// السطور **مرتَّبةً بمفتاح النوع** — ★ **فنفس الإدخال يُنتج نفس المستند**
  /// في كل تشغيل (`coding-standards.md` §2.7 · إعادة المحاولة بلا أثر).
  final List<ValidatedCashSaleLine> lines;

  /// ★ إجمالي الحبّات — ⛔ **ولا يُجمع مع [totalWeight] أبداً** (`GR-19`).
  PieceCount get totalPieces {
    PieceCount total = PieceCount.zero;
    for (final ValidatedCashSaleLine line in lines) {
      if (line.quantity case PieceQuantity(:final PieceCount count)) {
        total = total + count;
      }
    }
    return total;
  }

  /// ★ إجمالي الأوزان — ⛔ **ولا يُجمع مع [totalPieces] أبداً** (`GR-19`).
  WeightKg get totalWeight {
    WeightKg total = WeightKg.zero;
    for (final ValidatedCashSaleLine line in lines) {
      if (line.quantity case WeightQuantity(:final WeightKg weight)) {
        total = total + weight;
      }
    }
    return total;
  }

  /// ★★ **صافي المقبوض نقداً** — [computeNetCashReceived] (`FR-M11-14`).
  Money get netCashReceived => computeNetCashReceived(
        <Money>[for (final ValidatedCashSaleLine line in lines) line.lineTotal],
      );
}

/// ★ الحدّ الأدنى لعدد السطور — **سندٌ بلا سطر لا يُنشئ حركة فلا معنى له**.
const int cashSaleMinLines = 1;

/// يفحص سند بيعٍ نقدي — `FR-M11-01` … `FR-M11-12`.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ★★ **ستة قيود تُفحَص هنا:**
///
///   ① **المصدر إلزامي** (`FR-M11-02`) — ⛔ **ولا خصمَ من مخزنٍ مجهول.**
///   ② **سطرٌ واحد على الأقل**.
///   ③ ⛔ **لا سطران لنفس النوع** — ★ **والواجهة تدمجهما قبل أن تصل هنا.**
///   ④ ★★ **الكمية موجبة تماماً** — ⛔ **والصفر ليس بيعاً، والسالب إرجاعٌ
///      لا بيع.**
///   ⑤ ⛔ **ووحدة الكمية = وحدة النوع** (`GR-19` · `E-31`) — ★ **فلا تُحوَّل
///      حبّةٌ إلى كيلوجرام صامتاً.**
///   ⑥ ★★★ **السعر موجبٌ تماماً** — ⛔ **والصفر ليس سعراً**: ⟵ **وسندٌ
///      بصفرٍ يُقيِّد بيعاً بلا مقبوض** ⛔ **وهو ما يمنعه `FR-M11-04`.**
/// ═══════════════════════════════════════════════════════════════════════
///
/// ⛔⛔★★ **ولا يُفحَص الحدّ الأدنى هنا** — ★ **مرجعُه سعرُ اليوم المخزَّن**
/// (`daily_prices`)، ⟵ **ويُقرأ داخل المعاملة السحابية** ([isBelowMinimumCashPrice])
/// ⛔ **لا من قيمةٍ يُرسِلها الجهاز**: ★ **وإلا لكفى تعديلُ الحمولة لتجاوزه.**
Outcome<ValidatedCashSale> validateCashSale(CashSaleInput input) {
  final String sourceId = input.sourceId.trim();
  if (sourceId.isEmpty) {
    return const Failure<ValidatedCashSale>(ValidationError('FR-M11-02'));
  }
  if (input.lines.length < cashSaleMinLines) {
    return const Failure<ValidatedCashSale>(ValidationError('FR-M11-01'));
  }

  final Outcome<List<ValidatedCashSaleLine>> lines = _validateLines(input.lines);
  if (lines case Failure<List<ValidatedCashSaleLine>>(:final AppError error)) {
    return Failure<ValidatedCashSale>(error);
  }

  final Outcome<String?> notes = _optionalText(input.notes);
  if (notes case Failure<String?>(:final AppError error)) {
    return Failure<ValidatedCashSale>(error);
  }

  return Success<ValidatedCashSale>(
    ValidatedCashSale(
      sourceId: sourceId,
      notes: (notes as Success<String?>).value,
      lines: (lines as Success<List<ValidatedCashSaleLine>>).value,
    ),
  );
}

Outcome<List<ValidatedCashSaleLine>> _validateLines(
  List<CashSaleLineInput> raw,
) {
  final Set<String> seen = <String>{};
  final List<ValidatedCashSaleLine> validated = <ValidatedCashSaleLine>[];

  for (final CashSaleLineInput line in raw) {
    final String itemId = line.itemId.trim();
    if (itemId.isEmpty) {
      return const Failure<List<ValidatedCashSaleLine>>(
        ValidationError('FR-M11-01'),
      );
    }
    // ③ ⛔ **لا سطران لنفس النوع** — ★ **والواجهة تدمجهما مع تنبيه.**
    if (!seen.add(itemId)) {
      return const Failure<List<ValidatedCashSaleLine>>(
        ValidationError('BR-M10-15'),
      );
    }
    // ⑤ ⛔ **ووحدة الكمية = وحدة النوع** — `GR-19`.
    if (line.quantity.unit != line.unit) {
      return const Failure<List<ValidatedCashSaleLine>>(
        ValidationError('GR-19'),
      );
    }
    // ④ ★★ **الكمية موجبة تماماً** — `FR-M11-07` · `E-01`.
    if (!line.quantity.isPositive) {
      return const Failure<List<ValidatedCashSaleLine>>(
        ValidationError('BR-M11-06'),
      );
    }
    final String name = line.itemName.trim();
    if (name.isEmpty) {
      return const Failure<List<ValidatedCashSaleLine>>(
        ValidationError('FR-M11-01'),
      );
    }
    // ⑥ ★★★ **السعر موجبٌ تماماً** — `FR-M11-04` · `ERR_PRICE_004`.
    if (line.unitPrice.riyals <= 0) {
      return const Failure<List<ValidatedCashSaleLine>>(
        ValidationError('FR-M11-04'),
      );
    }
    final Outcome<String?> reason = _optionalText(line.belowMinReason);
    if (reason case Failure<String?>(:final AppError error)) {
      return Failure<List<ValidatedCashSaleLine>>(error);
    }

    validated.add(
      ValidatedCashSaleLine(
        itemId: itemId,
        itemName: name,
        quantity: line.quantity,
        unitPrice: line.unitPrice,
        sackId: line.sackId,
        belowMinReason: (reason as Success<String?>).value,
      ),
    );
  }

  validated.sort(
    (ValidatedCashSaleLine a, ValidatedCashSaleLine b) =>
        a.itemKey.compareTo(b.itemKey),
  );
  return Success<List<ValidatedCashSaleLine>>(validated);
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

/// ★ يفحص أن السند غير ملغى — `ERR_AMEND_006` (`FR-M11-13` · `A-14`).
///
/// ⛔ **والملغى لا يُعدَّل ولا يُلغى ثانيةً:** ⟵ **إعادةُ كميةٍ إلى الرصيد من
/// مستندٍ خرج من الحساب فسادُ رصيدٍ صامت.**
Outcome<void> validateCashSaleNotCancelled(CashSaleStatus status) =>
    status == CashSaleStatus.cancelled
        ? const Failure<void>(ValidationError('FR-M11-13'))
        : const Success<void>(null);

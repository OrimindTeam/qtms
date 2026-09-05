/// الإتلاف (`M8` §الإتلاف) — **خروجٌ مخزنيٌّ بلا أثرٍ ماليٍّ إطلاقاً**.
///
/// ★ **المصدر:** `FR-M8-16` · `E-25` · `BR-M8-11` · `GR-29` ·
/// `inventory-design.md` §5 · `data-dictionary.md` §`disposals` ·
/// `design-overview.md` §2.2 و§2.10 · `ADR-0020` (**السبب اختياري**).
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔★★ **خمسُ قواعد بنيوية يفرضها هذا الملف بنوعه لا بشرطٍ يُنسى:**
///
///   ① ⛔⛔★★★ **ولا حقلَ ماليٍّ واحدٌ في أيِّ نوعٍ هنا** — `FR-M8-16` ·
///      `data-dictionary.md` §`disposals` («**لا `unitPrice` ولا
///      `lineTotal` ولا `amount` ولا `grandTotal`**): ⟵ **والغيابُ
///      البنيوي أقوى من شرطٍ يُفحَص**، ⛔ **فلا مسارٌ يُمرِّر مبلغاً سهواً**
///      — ★ **ولا يُستورَد `money.dart` في هذا الملف أصلاً.**
///   ② ⛔⛔★★★ **ولا يدخل سعرَ الجونية ولا استحقاقَ الرعوي** (`A-15` ·
///      `design-overview.md` §2.2 · `schema/supplier-ledger.md` §33):
///      ★ **والضمانةُ بنيويةٌ كذلك:** ⟵ **`readSackMovementDocuments`
///      تقرأ `distributions` و`cash_sales` و`outflows` وحدها**، ⛔ **ولا
///      مجموعةَ إتلافٍ فيها** — ★ **فما لا يُقرأ لا يُجمَع.**
///   ③ ⛔⛔★★ **ولا مقوتَ ولا ذمّة** — ★ **بنفس بنية `cash_sale.dart`
///      و`outflow.dart` حرفياً**: ⟵ **ولا حقلَ مقوتٍ يعبر هذا الملف.**
///   ④ ★★ **والمصدر إلزاميٌّ** — `data-dictionary.md` §`disposals`
///      (`sourceId` · `sourceName` **إلزامي**) · `ADR-0005`.
///   ⑤ ⛔ **ولا تُجمع حبّةٌ مع كيلوجرام** (`GR-19` · `E-31`) — ★ **إجماليان
///      منفصلان دائماً** ([ValidatedDisposal.totalPieces] و[ValidatedDisposal.totalWeight]).
/// ═══════════════════════════════════════════════════════════════════════
///
/// ⚠️⚠️★★ **وتاريخُ المخزون قد يكون سابقاً** — `data-dictionary.md`
/// §`disposals` (`stockDate`: «**يوم البضاعة المُتلَفة — قد يكون سابقاً في
/// تصريف المتبقي**») · `FR-M8-11`: ⟵ **والإتلافُ ثالثُ إجراءات التصريف**،
/// ★ **وحارسُه `agedClearanceRejection` نفسُه الذي يحرس التوزيعَ والبيع**
/// (`aged_remainder.dart` في السحابة) ⛔ **لا حارسٌ ثانٍ يُخترَع هنا.**
library;

import '../../../core/errors/app_error.dart';
import '../../../core/outcome.dart';
import '../../../core/quantity.dart';
import '../../master_data/domain/master_data.dart'
    show ItemUnit, freeTextMaxLength;
import 'inventory.dart';

/// مجموعة مستندات الإتلاف — `data-dictionary.md` §`disposals`.
///
/// ⛔⛔★★ **وقاعدتُها قائمةٌ منذ `WU-026`** (`firestore.rules` §22:
/// `allow create, update: if false`) — ⟵ **فكلُّ حقلٍ ماليٍّ مرفوضٌ بنيوياً
/// لأن العميل لا يكتب في هذه المجموعة حرفاً**، ★ **والكاتبُ الوحيد العمليةُ
/// المستدعاة بحساب خدمة** (`ADR-0013` القاعدة 2).
const String disposalsCollection = 'disposals';

/// ★ الحد الأدنى لعدد السطور — **مستندٌ بلا سطر لا يُتلِف شيئاً فلا معنى له**.
const int disposalMinLines = 1;

/// حالة مستند الإتلاف — ★ **حالتان لا أكثر** (بنفس `OutflowStatus` حرفياً).
enum DisposalStatus {
  /// معتمد — ★ **الحالة الوحيدة للمستند الحيّ**.
  approved,

  /// ملغى — ★ **بالوسم** (`GR-06` · `GR-07` · `A-14`).
  ///
  /// ⛔ **وليس حذفاً:** الحركاتُ تبقى مقروءةً مشطوبة **وتُستبعَد من كل رصيد**
  /// بلا حركاتٍ عكسية.
  cancelled,
}

// ═════════════════════════════════════════════════════════════════════════
// السطور والمستند
// ═════════════════════════════════════════════════════════════════════════

/// سطرُ إتلافٍ كما يصل من الواجهة — **قبل أي تحقق**.
final class DisposalLineInput {
  /// ينشئ المدخلات.
  const DisposalLineInput({
    required this.itemId,
    required this.itemName,
    required this.unit,
    required this.quantity,
    this.sackId,
  });

  /// معرّف النوع — ★ **وهو `itemKey` في الدفتر** (نفس قاعدة `FR-M6-09`).
  final String itemId;

  /// اسم النوع المعروض — ★ **نسخةٌ مقصودة** (`naming-conventions.md` §4).
  final String itemName;

  /// وحدة النوع — ★ **مقروءةٌ من سجل النوع** ⛔ **لا مُدخَلة** (`FR-M5-03`).
  final ItemUnit unit;

  /// ★ الكمية المُتلَفة **بوحدتها في النوع** — `GR-19`.
  final StockQuantity quantity;

  /// ★ **الجونية التي ينتمي إليها النوع** أو `null` — `ADR-0007` القاعدة 5.
  ///
  /// ⚠️⚠️ **ولا يُغيِّر سعرَ الجونية بحالٍ** (القاعدة ② في ترويسة الملف) —
  /// ★ **وإنما يبقى مرجعاً في الحركة** ⟵ **فتقريرُ `R-07` يُنسِب المُتلَف
  /// إلى جونيته** ⛔ **بلا أن يُنقِص إيرادَها.**
  final String? sackId;
}

/// سطرُ إتلافٍ مُتحقَّق منه.
final class ValidatedDisposalLine {
  /// ينشئ السطر.
  const ValidatedDisposalLine({
    required this.itemId,
    required this.itemName,
    required this.quantity,
    required this.sackId,
  });

  /// معرّف النوع.
  final String itemId;

  /// ★ **مفتاح النوع في الدفتر** — **المعرّف لا الاسم** (`FR-M5-01`).
  String get itemKey => itemId;

  /// الاسم المعروض لحظة الإدخال.
  final String itemName;

  /// الكمية المُتلَفة بوحدتها.
  final StockQuantity quantity;

  /// الجونية أو `null`.
  final String? sackId;
}

/// مدخلات مستند الإتلاف — ⛔ **بلا مبلغٍ ولا سعرٍ ولا مقوت**.
final class DisposalInput {
  /// ينشئ المدخلات.
  const DisposalInput({
    required this.sourceId,
    this.lines = const <DisposalLineInput>[],
    this.reason,
  });

  /// ★★★ المصدر — ⛔ **إلزاميٌّ** (القاعدة ④ في ترويسة الملف).
  final String sourceId;

  /// سطور الإتلاف — ⛔ **وسطرٌ واحدٌ على الأقل**.
  final List<DisposalLineInput> lines;

  /// ★★ السبب النصي — ⛔ **اختياريٌّ** (`ADR-0020` · `FR-M8-16`).
  ///
  /// ⚠️ **والفراغُ غيابٌ لا نصٌّ فارغ** — ⛔ **ولا يُعبِّئه التطبيق نيابةً
  /// عن المستخدم أبداً** (`ADR-0020` القاعدة الباقية).
  final String? reason;
}

/// مستندُ إتلافٍ مُتحقَّق منه — **جاهز للكتابة كما هو**.
final class ValidatedDisposal {
  /// ينشئ المستند.
  ValidatedDisposal({
    required this.sourceId,
    required this.reason,
    required List<ValidatedDisposalLine> lines,
  }) : lines = List<ValidatedDisposalLine>.unmodifiable(lines);

  /// المصدر.
  final String sourceId;

  /// السبب أو `null`.
  final String? reason;

  /// السطور **مرتَّبةً بمفتاح النوع** — ★ **فنفس الإدخال يُنتج نفس المستند**
  /// في كل تشغيل (`coding-standards.md` §2.7).
  final List<ValidatedDisposalLine> lines;

  /// ★ إجمالي الحبّات المُتلَفة — ⛔ **ولا يُجمع مع [totalWeight]** (`GR-19`).
  PieceCount get totalPieces {
    PieceCount total = PieceCount.zero;
    for (final ValidatedDisposalLine line in lines) {
      if (line.quantity case PieceQuantity(:final PieceCount count)) {
        total = total + count;
      }
    }
    return total;
  }

  /// ★ إجمالي الأوزان المُتلَفة — ⛔ **ولا يُجمع مع [totalPieces]** (`GR-19`).
  WeightKg get totalWeight {
    WeightKg total = WeightKg.zero;
    for (final ValidatedDisposalLine line in lines) {
      if (line.quantity case WeightQuantity(:final WeightKg weight)) {
        total = total + weight;
      }
    }
    return total;
  }
}

// ═════════════════════════════════════════════════════════════════════════
// التحقق — `error-handling-strategy.md` §3 (**تُرجَع نتيجةً لا تُرمى**)
// ═════════════════════════════════════════════════════════════════════════

/// يفحص مستندَ الإتلاف — `FR-M8-16` · `BR-M8-11`.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ★★ **ستة قيود تُفحَص هنا:**
///
///   ① ★★ **المصدر إلزامي** (`ADR-0005`) — ⛔ **ولا «مصدر افتراضي» يُملأ.**
///   ② **سطرٌ واحد على الأقل**.
///   ③ ⛔ **لا سطران لنفس النوع** — ★ **والواجهة تدمجهما قبل أن تصل هنا.**
///   ④ ★★ **الكمية موجبة تماماً** — ⛔ **والصفر ليس إتلافاً، والسالب إدخالٌ
///      لا إتلاف.**
///   ⑤ ⛔ **ووحدة الكمية = وحدة النوع** (`GR-19` · `E-31`).
///   ⑥ ★★ **والسبب — إن كُتب — نصٌّ غيرُ فارغ لا يتجاوز الحد** (`ADR-0020`).
/// ═══════════════════════════════════════════════════════════════════════
///
/// ⛔⛔★★ **ولا يُفحَص كفايةُ الرصيد هنا** — ★ **مرجعُه دفترُ المخزون**،
/// ⟵ **ويُقاس داخل المعاملة السحابية** (`FR-M8-01` · `GR-11`) ⛔ **لا من
/// قيمةٍ يُرسِلها الجهاز**: ★ **وإلا لكفى تعديلُ الحمولة لتجاوزه.**
Outcome<ValidatedDisposal> validateDisposal(DisposalInput input) {
  final String sourceId = input.sourceId.trim();
  // ① ★★ **المصدر إلزامي**.
  if (sourceId.isEmpty) {
    return const Failure<ValidatedDisposal>(ValidationError('BR-M8-11'));
  }
  // ② **سطرٌ واحد على الأقل**.
  if (input.lines.length < disposalMinLines) {
    return const Failure<ValidatedDisposal>(ValidationError('FR-M8-16'));
  }

  final Outcome<List<ValidatedDisposalLine>> lines = _validateLines(input.lines);
  if (lines case Failure<List<ValidatedDisposalLine>>(:final AppError error)) {
    return Failure<ValidatedDisposal>(error);
  }

  final Outcome<String?> reason = disposalOptionalText(input.reason);
  if (reason case Failure<String?>(:final AppError error)) {
    return Failure<ValidatedDisposal>(error);
  }

  return Success<ValidatedDisposal>(
    ValidatedDisposal(
      sourceId: sourceId,
      reason: (reason as Success<String?>).value,
      lines: (lines as Success<List<ValidatedDisposalLine>>).value,
    ),
  );
}

Outcome<List<ValidatedDisposalLine>> _validateLines(
  List<DisposalLineInput> raw,
) {
  final Set<String> seen = <String>{};
  final List<ValidatedDisposalLine> validated = <ValidatedDisposalLine>[];

  for (final DisposalLineInput line in raw) {
    final String itemId = line.itemId.trim();
    if (itemId.isEmpty) {
      return const Failure<List<ValidatedDisposalLine>>(
        ValidationError('FR-M8-16'),
      );
    }
    // ③ ⛔ **لا سطران لنفس النوع**.
    if (!seen.add(itemId)) {
      return const Failure<List<ValidatedDisposalLine>>(
        ValidationError('BR-M10-15'),
      );
    }
    // ⑤ ⛔ **ووحدة الكمية = وحدة النوع** — `GR-19` · `E-31`.
    if (line.quantity.unit != line.unit) {
      return const Failure<List<ValidatedDisposalLine>>(
        ValidationError('GR-19'),
      );
    }
    // ④ ★★ **الكمية موجبة تماماً**.
    if (!line.quantity.isPositive) {
      return const Failure<List<ValidatedDisposalLine>>(
        ValidationError('BR-M8-11'),
      );
    }
    final String name = line.itemName.trim();
    if (name.isEmpty) {
      return const Failure<List<ValidatedDisposalLine>>(
        ValidationError('FR-M8-16'),
      );
    }

    validated.add(
      ValidatedDisposalLine(
        itemId: itemId,
        itemName: name,
        quantity: line.quantity,
        sackId: line.sackId,
      ),
    );
  }

  validated.sort(
    (ValidatedDisposalLine a, ValidatedDisposalLine b) =>
        a.itemKey.compareTo(b.itemKey),
  );
  return Success<List<ValidatedDisposalLine>>(validated);
}

/// ★ نصٌّ اختياري — ⛔ **والفراغ غيابٌ لا نصٌّ فارغ** (`ADR-0020`).
Outcome<String?> disposalOptionalText(String? value) {
  final String? text = value?.trim();
  if (text == null || text.isEmpty) return const Success<String?>(null);
  if (text.length > freeTextMaxLength) {
    return const Failure<String?>(ValidationError('GR-49'));
  }
  return Success<String?>(text);
}

// ═════════════════════════════════════════════════════════════════════════
// ★★ مؤشّرُ الأداء — `design-overview.md` §2.10
// ═════════════════════════════════════════════════════════════════════════

/// ★★★ **نسبة الإتلاف ٪ = (الكمية المُتلَفة ÷ الوارد) × 100** — §2.10 حرفياً.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⚠️⚠️★★ **وللعرض فقط** — `design-overview.md` §2.11 (**النسب المئوية**):
/// ⛔ **لا تُخزَّن ولا يُبنى عليها مبلغ**، ★ **ولذلك تُرجَع `double`**
/// ⟵ **بخلاف كل مبلغٍ في النظام** (`ADR-0015`): **فهذه ليست مبلغاً.**
///
/// ★★ **و`null` لواردٍ صفري** — ⛔ **لا صفرٌ ولا لانهاية:** ⟵ **«لا وارد»
/// حالةٌ لا نسبةَ لها**، ★ **وصفرٌ كان يُقرأ «لا إتلاف» وهو معنى مختلف
/// تماماً** — ⛔ **ورقمٌ خاطئٌ بصمت** (نظيرُ `coveragePercent` في
/// `owner_ledger_summary.dart` حرفياً).
///
/// ⛔⛔ **والوحدتان لا تُجمعان** (`GR-19`) — ★ **فالنسبةُ تُحسَب داخل وحدةٍ
/// واحدة**: ⟵ **والمُستدعي يمرّر مُتلَفاً ووارداً من الوحدة نفسِها**،
/// ⛔ **وخلطُهما يُنتج نسبةً بلا معنى.**
/// ═══════════════════════════════════════════════════════════════════════
double? disposalRatePercent({
  required StockQuantity disposed,
  required StockQuantity incoming,
}) {
  if (disposed.unit != incoming.unit) return null;
  final double total = _amountOf(incoming);
  if (total <= 0) return null;
  return (_amountOf(disposed) / total) * 100;
}

double _amountOf(StockQuantity quantity) => switch (quantity) {
      PieceQuantity(:final PieceCount count) => count.pieces.toDouble(),
      WeightQuantity(:final WeightKg weight) => weight.kilograms,
    };

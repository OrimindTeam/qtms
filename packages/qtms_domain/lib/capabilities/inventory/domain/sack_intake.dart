/// الوارد جواني (`M7`) — ★★★ **أعقد وحدة في النظام وأدقّها صلاحيات**.
///
/// ★ **المصدر:** `FR-M7-01` … `FR-M7-29` · `schema/sacks.md` ·
/// `sack-intake-design.md` · `design-overview.md` §2.2 و§2.11 ·
/// `ADR-0007` (الاسم المركّب) · `ADR-0011` (عزل المالية) · `ADR-0015`.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔★★ **أربع قواعد بنيوية يفرضها هذا الملف بنوعه لا بشرطٍ يُنسى:**
///
///   ① **الأوزان ليست مبالغ** (`ADR-0015` القاعدة 9) — ★ **فـ[WeightKg]
///      عشريٌّ بثلاث خانات**، ⛔ **ولا يمرّ في [Money] ولا العكس.**
///   ② ★★ **جدول وزن الحبة بحالاته الثلاث يُنفَّذ حرفياً** — ⛔ **ولا
///      يُستنتَج وزن حبة نوعٍ وزني من الوزن الكلي في أي حال إطلاقاً**
///      (`FR-M7-14` · `E-08` · `E-09`)، ★ **والحالة تُقرَّر من [ItemNature]
///      لا من امتلاء الحقول.**
///   ③ **الوزن الضائع لا يُسجَّل إلا بتأكيدٍ صريح** (`FR-M7-19` · `BR-M7-12`)
///      — ★ **وقبله «وزنٌ غير مفسَّر»**، ⛔ **ولا تسجيل ضمني.**
///   ④ **الثلج والوزن الضائع لا يدخلان المخزن** (`design-overview.md` §2.2)
///      — ★ **والسكرب وحده يدخله فوراً** بوحدة الكيلوجرام (`FR-M7-09`).
/// ═══════════════════════════════════════════════════════════════════════
///
/// ⚠️⚠️ **والتقريب في موضعٍ واحد من هذه الوحدة لا أكثر:** **ضريبة الجونية**
/// (`design-overview.md` §2.11 الموضع ①) — ★ **وتمرّ بـ[Money.rounded]**،
/// ⛔ **ولا تقريب على وزنٍ ولا على وزن حبة** (`ADR-0015` القاعدة 4).
library;

import '../../../core/errors/app_error.dart';
import '../../../core/money.dart';
import '../../../core/outcome.dart';
import '../../../core/quantity.dart';
import '../../master_data/domain/master_data.dart'
    show ItemNature, ItemUnit, freeTextMaxLength, scrapItemName;
import 'inventory.dart';

// ═════════════════════════════════════════════════════════════════════════
// أسماء المجموعات والمسارات — `data-dictionary.md` · `schema/sacks.md`
// ═════════════════════════════════════════════════════════════════════════

/// مجموعة الجواني — ★ **لا يُحذف منها شيء أبداً**.
const String sacksCollection = 'sacks';

/// 🔒 **المجموعة الفرعية للحقول المالية** — `ADR-0011`.
///
/// ⛔★★ **ولماذا مستندٌ فرعي لا حقولٌ في الأب:** قاعدة الحماية **تمنح
/// المستند كاملاً ولا تُخفي حقلاً داخله** — ⟵ **فوجودُ الضريبة والسعر
/// والصافي في الأب يعني تسريبها لكل من يقرأ الجونية.**
const String sackFinanceSubcollection = 'finance';

/// معرّف مستند المالية الوحيد — `sacks/{id}/finance/current`.
const String sackFinanceDocumentId = 'current';

// ═════════════════════════════════════════════════════════════════════════
// الحالة ومصدر وزن الحبة
// ═════════════════════════════════════════════════════════════════════════

/// حالة مستند الجونية — `schema/sacks.md`.
enum SackStatus {
  /// معتمدة.
  approved,

  /// ★ ملغاة — **بالوسم لا بحركة عكسية** (`GR-06` · `A-14`).
  cancelled,
}

/// ★★ **مصدر وزن الحبة في السطر** — `sack-intake-design.md` §4.
///
/// ★ **حقلٌ توثيقي مهم لا زينة:** يجعل مصدر الرقم **قابلاً للتدقيق لاحقاً**،
/// ⟵ **ويكشف أي استنتاجٍ خاطئ لنوعٍ وزني** (`E-08`) — ⛔ **وهو بالضبط ما
/// لا يكشفه رقمٌ مجرَّد مخزَّن بلا مصدره.**
enum PieceWeightOrigin {
  /// من تهيئة النوع — ★ **يظهر تلقائياً وقابل للتعديل هنا فقط**.
  configured,

  /// أُدخل يدوياً — ★ **للوزني بلا وزن حبة في التهيئة**، أو تعديلاً محلياً.
  manual,

  /// ★ **مُستنتَج** — ⛔ **للعددي وحده** (`FR-M7-13`).
  inferred,
}

// ═════════════════════════════════════════════════════════════════════════
// الأسماء — ★ **مصدر حقيقة واحد** (`ADR-0007`)
// ═════════════════════════════════════════════════════════════════════════

/// ★★ **الاسم الظاهر للجونية** — `FR-M7-05`.
///
/// `{اسم الرعوي} - جونية رقم {N}` — أو `جونية رقم {N}` إن كان المصدر
/// **لا يشترط الرعوي**.
///
/// ⚠️ **ويُولَّد مرة واحدة لحظة الإنشاء** — ★ **وتعديله يتطلب صلاحية
/// `sackRenameDisplay`** ⛔ **ولا يمسّ الرقم المتسلسل اليومي أبداً**
/// (`ADR-0007` القاعدة 3).
String sackDisplayName({
  required int dailySequence,
  String? supplierName,
}) {
  _requirePositiveSequence(dailySequence);
  final String tail = 'جونية رقم $dailySequence';
  final String? supplier = _trimmedOrNull(supplierName);
  return supplier == null ? tail : '$supplier - $tail';
}

/// ★★★ **الاسم المركّب لنوعٍ داخل جونية** — `ADR-0007` · `FR-M7-16`.
///
/// `{اسم النوع} - {اسم الرعوي} - جونية رقم {N}`.
///
/// ⛔★★ **وهو مفتاح الرصيد لا مجرّد نصٍّ معروض** — `ADR-0007` الخيار 3:
/// ⟵ **فبه وحده تُردّ كل حبة خرجت إلى الجونية التي جاءت منها ورعويها**،
/// ★ **وعليه يُبنى سعر الجونية إيراداً فعلياً لا تقديرياً** (`A-13`).
///
/// ⚠️⚠️ **والفارق البنيوي عن الوارد عدداً مقصود:** `M6` **يدخل بالاسم
/// المجرَّد** (`BR-M6-10`) ⟵ **فلا يدخل احتساب سعر أي جونية**، وهذا **يدخله**.
String sackCompositeItemName({
  required String itemName,
  required int dailySequence,
  String? supplierName,
}) {
  final String name = itemName.trim();
  if (name.isEmpty) {
    throw ArgumentError.value(itemName, 'itemName', 'اسم النوع إلزامي');
  }
  return '$name - ${sackDisplayName(
    dailySequence: dailySequence,
    supplierName: supplierName,
  )}';
}

/// ★ **الاسم المركّب لسطر السكرب** — `FR-M7-09` · `ADR-0007`.
///
/// ★ **ويستدعي [sackCompositeItemName] ولا يعيد بناء الصيغة** —
/// `coding-standards.md` §2.2: ⟵ **ونسخةٌ ثانية منها تفترق عند أول تعديل.**
///
/// ⚠️⚠️ **افتراضٌ تنفيذي موثَّق — ولا يُطبَّق صامتاً:** `FR-M7-09` يكتب
/// الصيغة نثراً `سكرب - {الرعوي} - جونية رقم N` **بلا أداة تعريف**، بينما
/// **الاسم المخزَّن للنوع الافتراضي `السكرب`** بحسم `IQ-012`. ⟵ ★ **والمعتمد
/// هنا القاعدةُ العامة في `ADR-0007` حرفياً** — `{اسم النوع} - …` — **فيُبنى
/// من [scrapItemName] المخزَّن**، ⛔ **لا من نصّ النثر.**
///
/// ★★ **ولماذا هذا هو الصحيح لا مجرّد الأسهل:** الاسم المركّب **مفتاحُ رصيد
/// لا نصٌّ معروض** (`ADR-0007` الخيار 3)، ⟵ **فبناؤه من مصدر حقيقةٍ واحد
/// هو ما يضمن أن يُصيب الكاتبُ والقارئُ السجلَّ نفسه**؛ ⛔ **ونصٌّ محفور
/// مستقل عن سجل النوع كان يُنتج مفتاحين لنوعٍ واحد عند أول تعديل للاسم.**
String sackScrapCompositeName({
  required int dailySequence,
  String? supplierName,
}) =>
    sackCompositeItemName(
      itemName: scrapItemName,
      dailySequence: dailySequence,
      supplierName: supplierName,
    );

// ═════════════════════════════════════════════════════════════════════════
// أوزان الرأس — `FR-M7-06` … `FR-M7-08`
// ═════════════════════════════════════════════════════════════════════════

/// أوزان الجونية كما تصل من الواجهة — **قبل أي تحقق**.
final class SackWeightsInput {
  /// ينشئ المدخلات.
  const SackWeightsInput({
    required this.totalWeight,
    required this.iceWeight,
    required this.scrapWeight,
  });

  /// الوزن الكلي — ★ **بثلاث خانات عشرية** (`FR-M7-06`).
  final WeightKg totalWeight;

  /// وزن الثلج — ⛔ **ولا يدخل المخزن إطلاقاً** (`design-overview.md` §2.2).
  final WeightKg iceWeight;

  /// ★ وزن السكرب — **افتراضه صفر**، ⚙️ **ويدخل المخزن فوراً** (`FR-M7-09`).
  final WeightKg scrapWeight;
}

/// أوزان مُتحقَّق منها — ★ **والمطالب به مشتقٌّ منها لا مُدخَل**.
final class ValidatedSackWeights {
  /// ينشئ الأوزان.
  const ValidatedSackWeights({
    required this.totalWeight,
    required this.iceWeight,
    required this.scrapWeight,
  });

  /// الوزن الكلي.
  final WeightKg totalWeight;

  /// وزن الثلج.
  final WeightKg iceWeight;

  /// وزن السكرب.
  final WeightKg scrapWeight;

  /// ★★ **الوزن المطالب به** = الكلي − الثلج − السكرب (`FR-M7-08` · `AT-06`).
  ///
  /// ⛔ **محسوبٌ دائماً ولا يُخزَّن مُدخَلاً** — ★ **فلا موضع ينزلق فيه عن
  /// مكوّناته** (`coding-standards.md` §2.2).
  WeightKg get claimableWeight => totalWeight - iceWeight - scrapWeight;
}

/// ★★ يفحص أوزان الجونية — `FR-M7-06` · `FR-M7-07` · `ERR_INTAKE_003`.
///
/// ⛔★★ **والقيد `الكلي > الثلج + السكرب` صارم لا «≥»** — نصّ `FR-M7-07`:
/// «**الوزن الكلي > الثلج + السكرب دائماً**». ⟵ ★ **والمساواة تعني جونيةً
/// مطالبٌ بها صفرٌ** — ⛔ **وهي مستندٌ بلا معنى محاسبي، لا حالةٌ حدّية.**
///
/// ⚠️ **والوزن السالب مرفوض قبل ذلك** — ⛔ **ولا يُقاس عليه شيء**: وزنٌ سالب
/// **ليس قيمةً ناقصة بل قيمة خاطئة**، ★ **ويُنتج مطالباً به أكبر من الكلي.**
Outcome<ValidatedSackWeights> validateSackWeights(SackWeightsInput input) {
  for (final WeightKg weight in <WeightKg>[
    input.totalWeight,
    input.iceWeight,
    input.scrapWeight,
  ]) {
    if (!weight.kilograms.isFinite || weight.isNegative) {
      return const Failure<ValidatedSackWeights>(ValidationError('FR-M7-06'));
    }
  }

  // ⛔ **صفرُ الوزن الكلي ليس جونية** — ★ **والقيد أدناه يرفضه ضمناً**،
  //    ⟵ **والرفض الصريح هنا يُبقي رسالة `FR-M7-06` للمُدخَل الناقص.**
  if (input.totalWeight.kilograms == 0) {
    return const Failure<ValidatedSackWeights>(ValidationError('FR-M7-06'));
  }

  // ★★ `FR-M7-07` — ⛔ **صارمٌ لا «≥»** (راجع ترويسة الدالة).
  final WeightKg deducted = input.iceWeight + input.scrapWeight;
  if (!(input.totalWeight > deducted)) {
    return const Failure<ValidatedSackWeights>(ValidationError('BR-M7-07'));
  }

  return Success<ValidatedSackWeights>(
    ValidatedSackWeights(
      totalWeight: input.totalWeight,
      iceWeight: input.iceWeight,
      scrapWeight: input.scrapWeight,
    ),
  );
}

// ═════════════════════════════════════════════════════════════════════════
// سطر النوع — ★★★ **جدول الحالات الثلاث** (`FR-M7-13` · `FR-M7-14`)
// ═════════════════════════════════════════════════════════════════════════

/// سطر جونية كما يصل من الواجهة — **قبل أي تحقق**.
final class SackLineInput {
  /// ينشئ المدخلات.
  const SackLineInput({
    required this.itemId,
    required this.itemName,
    required this.nature,
    required this.unit,
    required this.quantity,
    this.configuredPieceWeightGrams,
    this.pieceWeightGrams,
    this.lineTotalWeight,
    this.distributionPrice,
    this.minCashPrice,
    this.note,
  });

  /// معرّف النوع.
  final String itemId;

  /// اسم النوع **المجرَّد** — ★ **والمركّب يُبنى عند الحفظ** (`ADR-0007`).
  final String itemName;

  /// ★ طبيعته — ⛔ **مقروءةٌ من سجل النوع** لا مُرسَلة (`FR-M5-03`).
  final ItemNature nature;

  /// وحدته — ★ **جزءٌ من هويته** (`FR-M5-04`).
  final ItemUnit unit;

  /// ★ العدد — **صحيحٌ موجب** (`GR-19`: ⛔ **ولا يُجمع مع وزن**).
  final int quantity;

  /// ★ وزن الحبة **من تهيئة النوع** — `null` إن لم يكن له وزن هناك.
  ///
  /// ⚠️ **ويُقرأ من سجل النوع** ⛔ **لا يُرسله الجهاز** — ★ **وإلا أعلن
  /// العميلُ تهيئةً لا وجود لها فتخطّى `E-08`.**
  final double? configuredPieceWeightGrams;

  /// ★ وزن الحبة المُدخَل في هذا السطر — **يعلو على التهيئة هنا فقط**.
  ///
  /// ⛔ **وتعديلُه لا يمسّ التهيئة أبداً** (`FR-M7-15` · `BR-M7-10`) —
  /// ★ **والقيمة مُجمَّدة داخل السطر لحظة الحفظ.**
  final double? pieceWeightGrams;

  /// ★ الوزن الكلي للسطر — ⛔ **للعددي وحده يُدخَل** (`FR-M7-13`).
  final double? lineTotalWeight;

  /// سعر التوزيع — 🔵 **قد يكون معلّقاً** (`FR-M7-21`).
  final Money? distributionPrice;

  /// الحد الأدنى للبيع النقدي — 🔵 **قد يكون معلّقاً**.
  final Money? minCashPrice;

  /// ملاحظة السطر.
  final String? note;
}

/// سطر جونية مُتحقَّق منه — **جاهز للكتابة كما هو**.
final class ValidatedSackLine {
  /// ينشئ السطر.
  const ValidatedSackLine({
    required this.itemId,
    required this.itemName,
    required this.nature,
    required this.unit,
    required this.quantity,
    required this.pieceWeightGrams,
    required this.pieceWeightOrigin,
    required this.lineTotalWeight,
    required this.distributionPrice,
    required this.minCashPrice,
    required this.note,
  });

  /// معرّف النوع.
  final String itemId;

  /// ★ اسم النوع **المجرَّد** كما هو مخزَّن لحظة الإدخال.
  ///
  /// ⚠️ **نسخةٌ مقصودة** (`ADR-0007` القاعدة 4) — ★ **فلا يتغيّر المعروض
  /// تاريخياً لو تغيّر اسم النوع لاحقاً.**
  final String itemName;

  /// طبيعته.
  final ItemNature nature;

  /// وحدته.
  final ItemUnit unit;

  /// العدد.
  final PieceCount quantity;

  /// ★ وزن الحبة بالجرام — **بعد تطبيق جدول الحالات الثلاث**.
  final double pieceWeightGrams;

  /// ★★ **مصدره** — راجع [PieceWeightOrigin].
  final PieceWeightOrigin pieceWeightOrigin;

  /// ★ الوزن الكلي للسطر بالكيلوجرام.
  final WeightKg lineTotalWeight;

  /// سعر التوزيع أو `null`.
  final Money? distributionPrice;

  /// الحد الأدنى أو `null`.
  final Money? minCashPrice;

  /// الملاحظة أو `null` — ⛔ **والفارغ غيابٌ لا نصٌّ فارغ**.
  final String? note;

  /// ★★ **مفتاح النوع في الدفتر** — **الاسم المركّب** (`ADR-0007`).
  ///
  /// ⚠️ **ويحتاج رقم الجونية واسم الرعوي**، ⟵ **فهو دالة لا حقل**:
  /// ★ **الرقم يُخصَّص في السحابة داخل المعاملة** (`FR-M7-04`)، ⛔ **فلا
  /// يمكن تجميده في السطر قبل ذلك.**
  String itemKeyIn({required int dailySequence, String? supplierName}) =>
      sackCompositeItemName(
        itemName: itemName,
        dailySequence: dailySequence,
        supplierName: supplierName,
      );

  /// ★ الكمية بوحدتها — **للدفتر**.
  ///
  /// ⚠️⚠️ **وبوحدة النوع المخزَّنة لا بالوزن** — `GR-19`: ★ **الحبّات تدخل
  /// حبّاتٍ**، ⛔ **ووزنُ السطر بيانٌ تفسيري للجونية لا رصيدٌ ثانٍ**؛
  /// ⟵ **وإدخالُه رصيداً كان سيُنتج رصيدين لنوعٍ واحد.**
  StockQuantity get stockQuantity => switch (unit) {
        ItemUnit.piece => PieceQuantity(quantity),
        ItemUnit.kilogram => WeightQuantity(lineTotalWeight),
      };
}

/// ★★★ **جدول وزن الحبة — الحالات الثلاث** (`FR-M7-13` · `sack-intake-design.md` §3).
///
/// | حالة النوع | وزن الحبة | الوزن الكلي للسطر |
/// |---|---|---|
/// | **وزني + وزن حبة في التهيئة** | تلقائي · قابل للتعديل **هنا فقط** | **محسوب** |
/// | **وزني بلا وزن حبة** | **يُدخَل يدوياً** | **محسوب** |
/// | **عددي** | **مقفل وفارغ · مُستنتَج** | **يُدخَل يدوياً** |
///
/// ```text
/// المحسوب  = (العدد × وزن الحبة بالجرام) ÷ 1000
/// المستنتَج = (الوزن الكلي للسطر × 1000) ÷ العدد
/// ```
///
/// ⛔★★★ **وأخطر ما يحرسه هذا الموضع:** `FR-M7-14` — «**لا يُستنتَج وزن حبة
/// نوعٍ وزني من الوزن الكلي في أي حال إطلاقاً**». ⟵ ★ **فالوزني بلا وزن حبة
/// يُرفَض بـ`E-08`** ⛔ **ولا يُستنتَج له وزنٌ من `lineTotalWeight` ولو
/// أُرسِل** — والخلط بين الحالتين الثانية والثالثة **يُنتج أوزاناً خاطئة
/// تُفسِد سعر الجونية وصافي الرعوي معاً** (`sack-intake-design.md` §3).
///
/// ⚠️ **ولا تقريب هنا** — `ADR-0015` القاعدة 4: **التقريب في نهاية سلسلة
/// الحساب**، ★ **والعرض يُظهر الكيلوجرام بثلاث خانات والجرام بخانتين**.
Outcome<ValidatedSackLine> resolveSackLine(SackLineInput input) {
  final String itemId = input.itemId.trim();
  final String itemName = input.itemName.trim();
  if (itemId.isEmpty || itemName.isEmpty) {
    return const Failure<ValidatedSackLine>(ValidationError('FR-M7-12'));
  }

  // ⛔ **العدد موجبٌ تماماً** — والصفر ليس سطراً، والسالب سحبٌ لا توريد.
  if (input.quantity <= 0) {
    return const Failure<ValidatedSackLine>(ValidationError('BR-M6-06'));
  }
  final PieceCount quantity = PieceCount(input.quantity);

  final Outcome<String?> note = _optionalNote(input.note);
  if (note case Failure<String?>(:final AppError error)) {
    return Failure<ValidatedSackLine>(error);
  }

  final double? pieceWeight;
  final PieceWeightOrigin origin;
  final WeightKg lineTotal;

  switch (input.nature) {
    // ═══ الحالتان ① و② — **وزني**: الوزن الكلي **محسوب دائماً** ═══
    case ItemNature.weightBased:
      // ⛔★★ **ولا يُقبَل وزنٌ كلي مُرسَل لنوعٍ وزني** — ★ **وهو ما يمنع
      //    الاستنتاج من الباب الخلفي**: قبولُه كان يجعل العميل يُرسل وزناً
      //    كلياً بلا وزن حبة ⟵ **فيُشتقّ منه ضمناً** (`FR-M7-14`).
      final double? manual = input.pieceWeightGrams;
      final double? configured = input.configuredPieceWeightGrams;
      if (manual != null) {
        // ★ **تعديلٌ محلي مُجمَّد في السطر** — ⛔ **ولا يمسّ التهيئة**
        //   (`FR-M7-15`). ★ **ويُعلَّم `manual` ولو طابق التهيئة**: الرقم
        //   نفسه، **والمصدر مختلف**، ⟵ **والتدقيق يقرأ المصدر لا الرقم.**
        if (!manual.isFinite || manual <= 0) {
          return const Failure<ValidatedSackLine>(ValidationError('E-08'));
        }
        pieceWeight = manual;
        origin = PieceWeightOrigin.manual;
      } else if (configured != null && configured.isFinite && configured > 0) {
        pieceWeight = configured;
        origin = PieceWeightOrigin.configured;
      } else {
        // ⛔★★★ **الحالة ② بلا وزن حبة** — `E-08` · `FR-M7-14`:
        //    ★ **يُرفَض ويُطلَب إدخاله يدوياً**، ⛔ **ولا يُستنتَج.**
        return const Failure<ValidatedSackLine>(ValidationError('E-08'));
      }
      // (العدد × الجرام) ÷ 1000 — `design-overview.md` §2.2.
      lineTotal = WeightKg(quantity.pieces * pieceWeight / 1000);

    // ═══ الحالة ③ — **عددي**: الحقل مقفل، والوزن الكلي **يدوي** ═══
    case ItemNature.countBased:
      // ⛔ **وزن حبةٍ مُرسَل لنوعٍ عددي يُرفَض** — `E-09`: «**الحقل مقفل**».
      //   ★ **ولا يُطرَح صامتاً**: طرحُه يجعل الواجهة تظنّ أنها خزّنت قيمة.
      if (input.pieceWeightGrams != null ||
          input.configuredPieceWeightGrams != null) {
        return const Failure<ValidatedSackLine>(ValidationError('E-09'));
      }
      final double? total = input.lineTotalWeight;
      if (total == null || !total.isFinite || total <= 0) {
        // `ERR_INTAKE_006` — «أدخل الوزن الكلي ليُستنتَج وزن الحبة».
        return const Failure<ValidatedSackLine>(ValidationError('FR-M7-13'));
      }
      lineTotal = WeightKg(total);
      // (الوزن الكلي × 1000) ÷ العدد — `AT-09`: 250 حبة و15.000 كجم ⟵ 60 جم.
      pieceWeight = total * 1000 / quantity.pieces;
      origin = PieceWeightOrigin.inferred;
  }

  return Success<ValidatedSackLine>(
    ValidatedSackLine(
      itemId: itemId,
      itemName: itemName,
      nature: input.nature,
      unit: input.unit,
      quantity: quantity,
      pieceWeightGrams: pieceWeight,
      pieceWeightOrigin: origin,
      lineTotalWeight: lineTotal,
      distributionPrice: input.distributionPrice,
      minCashPrice: input.minCashPrice,
      note: (note as Success<String?>).value,
    ),
  );
}

// ═════════════════════════════════════════════════════════════════════════
// حاسبة الوزن الحيّة — `FR-M7-17` · `FR-M7-29` · `sack-intake-design.md` §2
// ═════════════════════════════════════════════════════════════════════════

/// ★★ **حالة تفسير وزن الجونية** — آلة الحالة في `sack-intake-design.md` §2.
enum SackWeightState {
  /// ★ **مفسَّر بالكامل** — المتبقي = 0.
  fullyExplained,

  /// ⚠️ **وزنٌ غير مفسَّر** — ★ **ويُلاحقه المركز المعلّق** (`E-10`).
  unexplained,

  /// ★ **ضائعٌ مؤكَّد** — بزرٍّ صريح وحده (`FR-M7-19`).
  lostConfirmed,
}

/// ★★★ **نتيجة الحاسبة الحيّة** — ⛔ **ولا تُعاد كتابة معادلتها في شاشة**.
///
/// ⚠️⚠️ **وهي الحارس العملي لـ`ADR-0010` القاعدة 5:** «**الحاسبة تستدعي
/// دوال النطاق ولا تُعيد كتابة المعادلة**». ⟵ ★ **فالشاشة تُعيد الرسم مع
/// كل ضغطة مفتاح**، ⛔ **وحسابها بنفسها كان يجعل رقمَ الشاشة يفترق عن رقم
/// السحابة عند أول تعديل.**
final class SackWeightExplanation {
  /// ينشئ النتيجة.
  const SackWeightExplanation({
    required this.claimableWeight,
    required this.explainedWeight,
    required this.remainingWeight,
    required this.state,
  });

  /// الوزن المطالب به.
  final WeightKg claimableWeight;

  /// ★ Σ(الوزن الكلي لكل سطر) — **المُفسَّر**.
  final WeightKg explainedWeight;

  /// ★★ **الوزن النهائي المتبقي** = المطالب به − المُفسَّر (`FR-M7-17`).
  final WeightKg remainingWeight;

  /// الحالة.
  final SackWeightState state;

  /// ★ **الوزن الضائع** — ⛔ **صفرٌ ما لم يُؤكَّد صراحةً** (`BR-M7-12`).
  ///
  /// ⚠️⚠️ **ولا يُشتقّ من المتبقي بلا تأكيد**: `FR-M7-19` نصّاً — «**لا
  /// يُسجَّل إلا بضغط زر «تأكيد الوزن الضائع» صراحةً**». ⟵ ★ **فقبل التأكيد
  /// «وزنٌ غير مفسَّر»**، ⛔ **لا ضائع.**
  WeightKg get lostWeight => state == SackWeightState.lostConfirmed
      ? remainingWeight
      : WeightKg.zero;

  /// ★ **نسبة الوزن الضائع %** — ⛔ **للعرض فقط ولا تُخزَّن**
  /// (`design-overview.md` §2.2 و§2.11).
  ///
  /// ★ **وصفرُ المطالب به يُرجِع صفراً** — ⛔ **ولا قسمة على صفر**:
  /// [validateSackWeights] يمنعه أصلاً، ★ **والحارس هنا لمن يبني بلا فحص.**
  double get lostWeightPercentage => claimableWeight.kilograms == 0
      ? 0
      : (lostWeight.kilograms / claimableWeight.kilograms) * 100;
}

/// ★★★ **الحاسبة الحيّة** — `design-overview.md` §2.2 · `FR-M7-17`.
///
/// ```text
/// الوزن النهائي المتبقي = الوزن المطالب به − Σ(الوزن الكلي لكل سطر)
/// ```
///
/// [lostWeightConfirmed] هو **ضغطة الزر الصريحة** وحدها — ⛔ **ولا تُستنتَج**.
///
/// ⚠️ **ومقارنة الصفر بهامشٍ لا بالتساوي التام:** الجمع العشري **يُنتج
/// بقايا من رتبة `1e-15`** عند طرح محسوبين، ⟵ **ومقارنةٌ تامة كانت تُبقي
/// جونيةً مفسَّرةً بالكامل في حالة «غير مفسَّر» أبداً.** ★ **والهامش
/// نصفُ أصغر خانة معتمدة** (`WeightKg.decimals` = 3 ⟵ `0.0005`)،
/// ⛔ **فلا يبتلع فرقاً يراه المستخدم في ثلاث خانات.**
SackWeightExplanation explainSackWeight({
  required ValidatedSackWeights weights,
  required Iterable<ValidatedSackLine> lines,
  bool lostWeightConfirmed = false,
}) {
  WeightKg explained = WeightKg.zero;
  for (final ValidatedSackLine line in lines) {
    explained = explained + line.lineTotalWeight;
  }
  final WeightKg remaining = weights.claimableWeight - explained;
  final bool isZero = remaining.kilograms.abs() < weightEpsilonKg;

  return SackWeightExplanation(
    claimableWeight: weights.claimableWeight,
    explainedWeight: explained,
    remainingWeight: isZero ? WeightKg.zero : remaining,
    state: isZero
        ? SackWeightState.fullyExplained
        : lostWeightConfirmed
            ? SackWeightState.lostConfirmed
            : SackWeightState.unexplained,
  );
}

/// ★ هامش مقارنة الأوزان — **نصف أصغر خانة معتمدة** (`WeightKg.decimals`).
const double weightEpsilonKg = 0.0005;

// ═════════════════════════════════════════════════════════════════════════
// المستند المُتحقَّق منه
// ═════════════════════════════════════════════════════════════════════════

/// مدخلات جونية.
final class SackIntakeInput {
  /// ينشئ المدخلات.
  const SackIntakeInput({
    required this.sourceId,
    required this.sourceRequiresSupplier,
    required this.weights,
    this.supplierId,
    this.lines = const <SackLineInput>[],
    this.lostWeightConfirmed = false,
    this.lostWeightNote,
    this.notes,
  });

  /// المصدر — ★ **إلزامي، ومخزنُه وحده يتأثر** (`FR-M7-28` · `AT-05`).
  final String sourceId;

  /// ★ **هل المصدر مُعلَّم بـ«يجب اختيار الرعوي»؟** — `FR-M7-03`.
  ///
  /// ⚠️ **تُقرأ من سجل المصدر** ⛔ **لا تُرسَل من الجهاز**.
  final bool sourceRequiresSupplier;

  /// الأوزان الثلاثة.
  final SackWeightsInput weights;

  /// ★ الرعوي — **يظهر ويصير إلزامياً فقط إن اشترطه المصدر** (`FR-M7-03`).
  final String? supplierId;

  /// ★★ السطور — ⛔ **وقد تكون فارغة** (`E-06`).
  ///
  /// ⚠️⚠️ **والفارغة حالةٌ صحيحة لا نقص:** `E-06` نصّاً — «**جونية بأوزانها
  /// بلا أنواع وبلا ضريبة تُحفَظ · ويدخل السكرب المخزن فوراً**». ⟵ ★ **وهذا
  /// أهم فارقٍ عن الوارد عدداً** الذي يرفض مستنداً بلا سطر (`FR-M6-04`).
  final List<SackLineInput> lines;

  /// ★ **تأكيد الوزن الضائع** — ⛔ **بضغطة زرٍّ صريحة وحدها** (`FR-M7-19`).
  final bool lostWeightConfirmed;

  /// ملاحظة الوزن الضائع — **اختيارية** (`FR-M7-19`).
  final String? lostWeightNote;

  /// ملاحظات المستند.
  final String? notes;
}

/// جونية مُتحقَّق منها — **جاهزة للكتابة كما هي**.
final class ValidatedSackIntake {
  /// ينشئ الجونية.
  ValidatedSackIntake({
    required this.sourceId,
    required this.supplierId,
    required this.weights,
    required this.explanation,
    required this.lostWeightConfirmed,
    required this.lostWeightNote,
    required this.notes,
    required List<ValidatedSackLine> lines,
  }) : lines = List<ValidatedSackLine>.unmodifiable(lines);

  /// المصدر.
  final String sourceId;

  /// ★ الرعوي أو `null` — ⛔ **ولا يُخزَّن إن كان المصدر لا يشترطه**
  /// (`FR-M7-03`: «**وإلا لا يُعرض ولا يُخزَّن**»).
  final String? supplierId;

  /// الأوزان.
  final ValidatedSackWeights weights;

  /// ★★ نتيجة الحاسبة — **المطالب به والمُفسَّر والمتبقي والحالة**.
  final SackWeightExplanation explanation;

  /// هل أُكِّد الوزن الضائع؟
  final bool lostWeightConfirmed;

  /// ملاحظة الوزن الضائع أو `null`.
  final String? lostWeightNote;

  /// ملاحظات المستند أو `null`.
  final String? notes;

  /// ★ السطور **مرتَّبةً بمعرّف النوع** — ⟵ **فنفس الإدخال يُنتج نفس
  /// المستند في كل تشغيل** (`coding-standards.md` §2.7).
  final List<ValidatedSackLine> lines;

  /// ★ **إجمالي الحبّات** — ⛔ **ولا يُجمع مع وزن** (`GR-19`).
  ///
  /// ⚠️ **ويعدّ سطور الحبّة وحدها** — ★ **وأنواع المستخدم كلها بالحبّة**
  /// (`FR-M5-03`)، ⛔ **والسكرب لا يمرّ سطراً أصلاً** بل يُولَّد من الرأس.
  PieceCount get totalPieces {
    PieceCount total = PieceCount.zero;
    for (final ValidatedSackLine line in lines) {
      if (line.unit == ItemUnit.piece) total = total + line.quantity;
    }
    return total;
  }

  /// ★ **هل التسعير مكتمل؟** — مصدر وسم «⏳ سعر غير نهائي» (`schema/sacks.md`).
  ///
  /// ⚠️ **وجونيةٌ بلا سطور ليست مكتملة التسعير** — ⟵ **فلا وسمَ اكتمالٍ
  /// لمستندٍ لم تُدخَل أنواعُه بعد** (`E-06`: «ثلاثة بنود في المركز»).
  bool get isPricingComplete =>
      lines.isNotEmpty &&
      lines.every((ValidatedSackLine line) => line.distributionPrice != null);
}

/// ★★ يفحص جونية — `FR-M7-03` · `FR-M7-06` … `FR-M7-23`.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ★★ **ستة قيود تُفحَص هنا، وكلها كانت قواعدَ حماية قبل `WU-026`:**
///
///   ① **المصدر إلزامي** (`FR-M7-28`) — ⛔ ولا حركة بلا مخزن.
///   ② **الرعوي إلزامي إن اشترطه المصدر، ومرفوضٌ إن لم يشترطه** (`FR-M7-03`).
///   ③ **الأوزان الثلاثة والقيد `الكلي > الثلج + السكرب`** (`FR-M7-07`).
///   ④ ★★★ **جدول وزن الحبة الثلاثي** (`FR-M7-13` · `FR-M7-14`).
///   ⑤ **لا سطران لنفس النوع** (`FR-M7-23` · `ERR_INTAKE_008`).
///   ⑥ ★★ **Σ أوزان السطور ≤ المطالب به** (`FR-M7-18` · `E-07`).
/// ═══════════════════════════════════════════════════════════════════════
///
/// ⚠️⚠️ **والقيد ② في الاتجاهين لا في اتجاه واحد** — نفس منطق `FR-M6-03`:
/// ★ **رعويٌّ وصل لمصدرٍ لا يشترطه يُرفَض** ⛔ **ولا يُطرَح صامتاً.**
Outcome<ValidatedSackIntake> validateSackIntake(SackIntakeInput input) {
  final String sourceId = input.sourceId.trim();
  if (sourceId.isEmpty) {
    return const Failure<ValidatedSackIntake>(ValidationError('FR-M7-28'));
  }

  // ② الرعوي — في الاتجاهين معاً (`FR-M7-03`).
  final String? supplierId = _trimmedOrNull(input.supplierId);
  final bool hasSupplier = supplierId != null;
  if (input.sourceRequiresSupplier != hasSupplier) {
    return const Failure<ValidatedSackIntake>(ValidationError('BR-M7-03'));
  }

  // ③ الأوزان.
  final Outcome<ValidatedSackWeights> weights =
      validateSackWeights(input.weights);
  if (weights case Failure<ValidatedSackWeights>(:final AppError error)) {
    return Failure<ValidatedSackIntake>(error);
  }
  final ValidatedSackWeights checked =
      (weights as Success<ValidatedSackWeights>).value;

  // ④ و⑤ السطور.
  final Outcome<List<ValidatedSackLine>> lines = _validateLines(input.lines);
  if (lines case Failure<List<ValidatedSackLine>>(:final AppError error)) {
    return Failure<ValidatedSackIntake>(error);
  }
  final List<ValidatedSackLine> resolved =
      (lines as Success<List<ValidatedSackLine>>).value;

  final SackWeightExplanation explanation = explainSackWeight(
    weights: checked,
    lines: resolved,
    lostWeightConfirmed: input.lostWeightConfirmed,
  );

  // ⑥ ★★ **لا تجاوز للمطالب به** — `FR-M7-18` · `E-07` · `ERR_INTAKE_004`.
  //    ⟵ **والمتبقي السالب هو التجاوز نفسه**، ★ **فقيدٌ واحد يحرسهما.**
  if (explanation.remainingWeight.kilograms < -weightEpsilonKg) {
    return const Failure<ValidatedSackIntake>(ValidationError('BR-M7-08'));
  }

  final Outcome<String?> lostNote = _optionalNote(input.lostWeightNote);
  if (lostNote case Failure<String?>(:final AppError error)) {
    return Failure<ValidatedSackIntake>(error);
  }
  final Outcome<String?> notes = _optionalNote(input.notes);
  if (notes case Failure<String?>(:final AppError error)) {
    return Failure<ValidatedSackIntake>(error);
  }

  return Success<ValidatedSackIntake>(
    ValidatedSackIntake(
      sourceId: sourceId,
      supplierId: supplierId,
      weights: checked,
      explanation: explanation,
      // ★ **وتأكيدٌ بلا متبقٍّ ليس تأكيداً** — ⟵ **فجونيةٌ مفسَّرة بالكامل
      //   لا وزنَ ضائعَ فيها ولو ضُغط الزر**، ⛔ **ولا يُكتب وسمٌ كاذب.**
      lostWeightConfirmed:
          explanation.state == SackWeightState.lostConfirmed,
      lostWeightNote: (lostNote as Success<String?>).value,
      notes: (notes as Success<String?>).value,
      lines: resolved,
    ),
  );
}

Outcome<List<ValidatedSackLine>> _validateLines(List<SackLineInput> raw) {
  final Set<String> seen = <String>{};
  final List<ValidatedSackLine> validated = <ValidatedSackLine>[];

  for (final SackLineInput line in raw) {
    // ⑤ ⛔ **لا سطران لنفس النوع** — `FR-M7-23` · `ERR_INTAKE_008`.
    //    ★ **ويُرفَض الثاني ولا يُدمَج صامتاً**: الدمج يُخفي أن المستخدم
    //    أدخل رقمين مختلفين لوزن الحبة، ⟵ **وأحدهما كان سيُهمَل بلا إنذار.**
    if (!seen.add(line.itemId.trim())) {
      return const Failure<List<ValidatedSackLine>>(ValidationError('BR-M7-17'));
    }
    final Outcome<ValidatedSackLine> resolved = resolveSackLine(line);
    if (resolved case Failure<ValidatedSackLine>(:final AppError error)) {
      return Failure<List<ValidatedSackLine>>(error);
    }
    validated.add((resolved as Success<ValidatedSackLine>).value);
  }

  // ★ **ترتيبٌ ثابت** — راجع [ValidatedSackIntake.lines].
  validated.sort(
    (ValidatedSackLine a, ValidatedSackLine b) => a.itemId.compareTo(b.itemId),
  );
  return Success<List<ValidatedSackLine>>(validated);
}

// ═════════════════════════════════════════════════════════════════════════
// الضريبة — ★ **الموضع ① للتقريب** (`design-overview.md` §2.11)
// ═════════════════════════════════════════════════════════════════════════

/// ★★★ **ضريبة الجونية** — `FR-M7-11` · `BR-M7-14` · `AT-13`.
///
/// ```text
/// ضريبة الجونية = round(قيمة ضريبة الكيلو × الوزن الكلي للجونية)
/// ```
///
/// ⛔★★ **وعلى الوزن الكلي لا المطالب به ولا الصافي** — نصّ `FR-M7-11`
/// حرفياً. ⟵ ★ **والفرق ليس تفصيلاً**: الثلج والسكرب مخصومان من المطالب به،
/// **فاحتسابُها عليه يُنقِص ضريبةَ كل جونيةٍ فيها ثلج** ⛔ **بصمت.**
///
/// ★★ **وتُقرَّب لأقرب ريال ثم تُخزَّن `int`** (`ADR-0015` · الموضع ①):
/// `617.25 ⟵ 617` · `617.50 ⟵ 618` · و`25 × 45.000 = 1,125` بلا كسر.
///
/// ⚠️ **وضريبة الكيلو نفسها مبلغٌ صحيح** — ★ **فالكسرُ هنا ناتجُ ضربٍ في
/// وزنٍ بثلاث خانات وحده**، ⛔ **لا مُدخَلٌ من المستخدم** (`A-02`).
Money sackTax({
  required Money taxPerKilo,
  required WeightKg totalWeight,
}) =>
    Money.rounded(taxPerKilo.riyals * totalWeight.kilograms);

/// ★ يفحص قيمة ضريبة الكيلو — ⛔ **والسالب مرفوض** (`ADR-0015` القاعدة 8).
///
/// ⚠️ **والصفر مقبول** — ★ **مصدرٌ بلا ضريبة حالةٌ واقعية**، ⟵ **ورفضُه
/// كان يُجبر المستخدم على تركها معلّقة أبداً** (`FR-M7-10`).
Outcome<Money> validateSackTaxPerKilo(Money taxPerKilo) =>
    taxPerKilo.isNegative
        ? const Failure<Money>(ValidationError('BR-M7-14'))
        : Success<Money>(taxPerKilo);

// ═════════════════════════════════════════════════════════════════════════
// السكرب — ★★ **يدخل المخزن عند حفظ الرأس قبل أي نوع آخر** (`FR-M7-09`)
// ═════════════════════════════════════════════════════════════════════════

/// ★★★ **سطر مخزون السكرب المولَّد من الرأس** — `FR-M7-09` · `AT-07` · `E-06`.
///
/// ⚠️⚠️ **ولماذا نوعٌ مستقل لا [ValidatedSackLine]:** السكرب **ليس سطراً
/// يُدخله المستخدم** — ★ **يُولَّد من `scrapWeight` وحده**، **بوحدة
/// الكيلوجرام** (⛔ لا حبّات)، **وبلا وزن حبة ولا طبيعة ولا سعر**.
/// ⟵ **وحشرُه في نوع السطر كان يُلزمه بحقولٍ لا معنى لها فيه.**
final class SackScrapLine {
  /// ينشئ سطر السكرب.
  const SackScrapLine({
    required this.itemId,
    required this.compositeName,
    required this.weight,
  });

  /// ★ معرّف النوع الافتراضي «السكرب» — ⛅ **من `app_settings`** (`IQ-012`).
  final String itemId;

  /// ★ الاسم المركّب — `سكرب - {الرعوي} - جونية رقم N` (`ADR-0007`).
  final String compositeName;

  /// وزنه بالكيلوجرام.
  final WeightKg weight;

  /// ★ مفتاحه في الدفتر — **الاسم المركّب** كأي نوعٍ من الجونية.
  String get itemKey => compositeName;

  /// ★ كميته — **وزنٌ دائماً** (`FR-M5-03`: الكيلوجرام للسكرب وحده).
  StockQuantity get stockQuantity => WeightQuantity(weight);
}

/// ★★ يبني سطر السكرب من الرأس — أو `null` **إن كان وزنه صفراً**.
///
/// ⚠️⚠️ **وصفرُ السكرب لا يُنتج سطراً ولا سجل رصيد** — `ADR-0008` القاعدة 5:
/// «⛔ **لا يُنشأ سجل بصفر بلا داعٍ**». ⟵ ★ **وجونيةٌ بلا سكرب حالةٌ شائعة**
/// (`FR-M7-06`: «**السكرب افتراضي صفر**»)، ⛔ **وسجلٌّ صفريٌّ لكلٍّ منها
/// كان يُضخّم الدفتر بلا معلومة.**
SackScrapLine? buildSackScrapLine({
  required String scrapItemId,
  required WeightKg scrapWeight,
  required int dailySequence,
  String? supplierName,
}) {
  if (scrapWeight.kilograms <= 0) return null;
  return SackScrapLine(
    itemId: scrapItemId,
    compositeName: sackScrapCompositeName(
      dailySequence: dailySequence,
      supplierName: supplierName,
    ),
    weight: scrapWeight,
  );
}

// ═════════════════════════════════════════════════════════════════════════
// التعديل والإلغاء — ★ **على الحركة نفسها** ⛔ **بلا حركة عكسية** (`A-14`)
// ═════════════════════════════════════════════════════════════════════════

/// ★ يفحص أن الجونية ليست ملغاة قبل تعديلها — `ERR_AMEND_006`.
///
/// ⛔★★ **والملغاة لا تُعدَّل ولا تُلغى ثانيةً** — ★ **وتعديلُها يُعيد كمياتٍ
/// إلى الرصيد من مستندٍ خرج من الحساب**، ⟵ **وهو فسادُ رصيدٍ صامت.**
Outcome<void> validateSackNotCancelled(SackStatus status) =>
    status == SackStatus.cancelled
        ? const Failure<void>(ValidationError('ERR_AMEND_006'))
        : const Success<void>(null);

/// ★★ يفحص أن الرقم المتسلسل لم يُمَسّ — `FR-M7-05` · `ADR-0007` القاعدة 3.
///
/// ⛔★★★ **«لا يُعاد استخدامه ولا يتغيّر أبداً»** — حتى لو غُيِّر الاسم
/// الظاهر أو أُلغيت الجونية. ⟵ ★ **والاسم المركّب لكل سطرٍ مبنيٌّ عليه**،
/// **فتغييرُه يفصل حركاتِ الجونية عن رأسها** ⛔ **بلا أي أثر ظاهر.**
Outcome<void> validateSackSequenceUnchanged({
  required int storedSequence,
  required int incomingSequence,
}) =>
    storedSequence == incomingSequence
        ? const Success<void>(null)
        : const Failure<void>(ValidationError('BR-M7-05'));

// ═════════════════════════════════════════════════════════════════════════
// مساعدات داخلية
// ═════════════════════════════════════════════════════════════════════════

Outcome<String?> _optionalNote(String? value) {
  final String? text = _trimmedOrNull(value);
  if (text == null) return const Success<String?>(null);
  if (text.length > freeTextMaxLength) {
    return const Failure<String?>(ValidationError('FR-M7-12'));
  }
  return Success<String?>(text);
}

String? _trimmedOrNull(String? value) {
  final String? text = value?.trim();
  return (text == null || text.isEmpty) ? null : text;
}

void _requirePositiveSequence(int sequence) {
  if (sequence < 1) {
    // ⛔ **خللٌ في العدّاد لا قاعدة عمل مخالَفة** — ★ **فيُرمى ولا يُرجَع
    //   نتيجةً**: التسلسل **تُولِّده السحابة** (`FR-M7-04`)، ⟵ **وقيمةٌ
    //   دونه تعني عطباً في المُخصِّص لا مُدخَلاً من مستخدم.**
    throw ArgumentError.value(sequence, 'dailySequence', 'التسلسل يبدأ من ١');
  }
}

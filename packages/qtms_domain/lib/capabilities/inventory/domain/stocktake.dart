/// الجرد والتسويات (`M16`) — **القناة المشروعة الوحيدة لفرقٍ غير مفسَّر**.
///
/// ★ **المصدر:** `FR-M16-01` … `FR-M16-11` · `BR-M16-01` … `BR-M16-07` ·
/// `inventory-design.md` §7 · `data-dictionary.md` §`stocktakes` ·
/// `schema/stocktakes.md` · `AT-66` · `ADR-0020` (**السبب اختياري**).
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔★★ **خمسُ قواعد بنيوية يفرضها هذا الملف بنوعه لا بشرطٍ يُنسى:**
///
///   ① ⛔⛔★★★ **ولا حقلَ ماليٍّ واحدٌ في أيِّ نوعٍ هنا** — `BR-M16-03` ·
///      `AT-66` (**«لا تُحتسب في سعر أي جونية ولا في المبيعات»**):
///      ⟵ **والغيابُ البنيوي أقوى من شرطٍ يُفحَص**، ⛔ **فلا مسارٌ يُمرِّر
///      مبلغاً سهواً** — ★ **ولا يُستورَد `money.dart` في هذا الملف أصلاً**
///      (بنفس قاعدة `disposal.dart` حرفياً).
///   ② ⛔⛔★★★ **ولا مقوتَ ولا رعويَّ ولا ذمّة** — `BR-M16-03`: ⟵ **تسويةُ
///      الجرد تُخرِج قاتاً أو تُدخِله بلا أن يستحقّ أحدٌ عليه شيئاً**،
///      ★ **وهي مع الإتلاف والوزن الضائع خارجَ `A-15`.**
///   ③ ★★★ **والرصيدُ الدفتري يُجمَّد لحظة بدء الجرد** — `FR-M16-03` ·
///      `schema/stocktakes.md` (`bookBalance` 🧮 🔒): ⟵ **ولذلك مرحلتان
///      لا واحدة** ([StocktakeStatus.draft] ثم [StocktakeStatus.approved])،
///      ★ **والفرقُ يُحسَب على المُجمَّد** ⛔ **لا على رصيدٍ يُعاد قياسُه
///      لحظةَ الاعتماد**: ⟵ **وإلا ابتلعت التسويةُ كلَّ حركةٍ وقعت أثناء
///      العدّ** — ★ **فيصير الرصيدُ النهائي = العدَّ الفعلي وحده** ⛔ **وهو
///      خطأٌ صامت: البضاعةُ التي خرجت أثناء العدّ خرجت فعلاً.**
///   ④ ★★ **والمصدر واليومُ مفردان** — `FR-M16-02` · `BR-M16-04`:
///      ⟵ **ومستندٌ واحد لا يمسّ رصيدَ يومين ولا مصدرين.**
///   ⑤ ⛔ **ولا تُجمع حبّةٌ مع كيلوجرام** (`GR-19` · `E-31`) — ★ **والفرقُ
///      يُحسَب داخل الوحدة الواحدة** ([stocktakeDifference] **ترفض
///      الاختلاف**)، ⛔ **ولا إجماليَّ واحدٌ يجمعهما.**
/// ═══════════════════════════════════════════════════════════════════════
///
/// ⚠️⚠️★★ **وتاريخُ المخزون قد يكون سابقاً** — `FR-M16-08` · `BR-M16-07`:
/// ⟵ **«جرد يوم سابق مسموح بصلاحية … ويُعيد بناء ملخصات ذلك اليوم بأثر
/// رجعي»**، ★ **ومفتاحُه `stocktakePriorDay`** ⛔ **لا `agedRemainderClear`:**
/// ⟵ **ذاك يحرس إجراءاتِ التصريف الثلاثة** (`FR-M8-11`: توزيع · بيع ·
/// إتلاف) **وكلُّها تُخرِج البضاعةَ فعلاً**، ★ **والجردُ لا يُصرِّف شيئاً بل
/// يُصحِّح رقماً** — ⛔ **فمن يملك تصريفَ متأخرٍ ليس بالضرورة من يُصحِّح
/// دفترَ يومٍ أُقفِل.**
library;

import '../../../core/errors/app_error.dart';
import '../../../core/outcome.dart';
import '../../../core/quantity.dart';
import '../../master_data/domain/master_data.dart'
    show ItemUnit, freeTextMaxLength;
import 'inventory.dart';

/// مجموعة مستندات الجرد — `data-dictionary.md` §`stocktakes`.
///
/// ⛔⛔★★ **وقاعدتُها قائمةٌ منذ `WU-026`** (`firestore.rules` §21:
/// `allow create, update: if false`) — ⟵ **فكلُّ حقلٍ فيها يكتبه العمليةُ
/// المستدعاة بحساب خدمة** (`ADR-0013` القاعدة 2)، ★ **والقراءةُ وحدها
/// مباشرةٌ بشرطِ `stocktakeView` ونطاقِ المصادر.**
const String stocktakesCollection = 'stocktakes';

/// ★ الحد الأدنى لعدد الأنواع في مستند جرد — **مستندٌ بلا نوعٍ لا يجرد شيئاً**.
const int stocktakeMinLines = 1;

/// حالة مستند الجرد — ★★★ **ثلاثٌ لا اثنتان** (القاعدة ③ في ترويسة الملف).
///
/// ⚠️⚠️ **وهذا فارقُها البنيوي عن كل مستندٍ آخر في النظام** — ⟵ **الوارد
/// والتوزيعة والبيع والإتلاف كلُّها تُولَد معتمدةً**، ★ **والجردُ وحده يمرّ
/// بمسوّدةٍ لأن `FR-M16-03` يُجمِّد الرصيد «لحظة البدء»** ⛔ **و`FR-M16-09`
/// يجعل الاعتماد صلاحيةً مستقلة**: ⟵ **ومرحلةٌ واحدة تُلغي معنى النصّين معاً.**
enum StocktakeStatus {
  /// مسوّدة — ★ **الرصيدُ الدفتري مُجمَّد والعدُّ الفعلي لم يصل بعد**.
  ///
  /// ⛔⛔★★ **ولا حركةَ دفتريةَ واحدةٍ لها** — ★ **المسوّدةُ لا تمسّ رصيداً**:
  /// ⟵ **فجردٌ بُدئ ولم يُعتمَد لا يُغيِّر رقماً واحداً في المخزن.**
  draft,

  /// معتمد — ★ **وهنا وحدَها تُكتب حركاتُ التسوية** (`FR-M16-11`).
  approved,

  /// ملغى — ★ **بالوسم** (`GR-06` · `GR-07` · `A-14`) ⛔ **وليس حذفاً**.
  cancelled,
}

// ═════════════════════════════════════════════════════════════════════════
// المرحلة الأولى — بدء الجرد وتجميد الرصيد الدفتري
// ═════════════════════════════════════════════════════════════════════════

/// مدخلات **بدء** الجرد — ⛔ **بلا عدٍّ فعليٍّ ولا رصيدٍ من الجهاز**.
///
/// ⚠️⚠️★★★ **ولا يُرسِل الجهازُ رصيداً دفترياً إطلاقاً** — `FR-M16-01`
/// (`bookBalance` 🧮 🔒 **محسوبٌ ومقفل**): ⟵ **يُقاس من الدفتر داخل
/// المعاملة**، ⛔ **وإلا لكفى تعديلُ الحمولة لاختلاق فرقٍ لم يقع.**
final class StocktakeStartInput {
  /// ينشئ المدخلات.
  const StocktakeStartInput({
    required this.sourceId,
    this.itemIds = const <String>[],
  });

  /// ★★★ المصدر — ⛔ **إلزاميٌّ** (القاعدة ④ في ترويسة الملف · `ADR-0005`).
  final String sourceId;

  /// الأنواع المطلوب جردُها — ⛔ **ونوعٌ واحدٌ على الأقل**.
  final List<String> itemIds;
}

/// ★ بدءُ جردٍ مُتحقَّق منه — **قائمةُ أنواعٍ نظيفةٌ مرتَّبة**.
final class ValidatedStocktakeStart {
  /// ينشئ البدء.
  ValidatedStocktakeStart({
    required this.sourceId,
    required List<String> itemKeys,
  }) : itemKeys = List<String>.unmodifiable(itemKeys);

  /// المصدر.
  final String sourceId;

  /// مفاتيح الأنواع **مرتَّبةً** — ★ **فنفس الإدخال يُنتج نفس المستند**
  /// (`coding-standards.md` §2.7).
  final List<String> itemKeys;
}

/// يفحص طلب بدء الجرد — `FR-M16-02` · `BR-M16-04`.
///
/// ★★ **ثلاثة قيود تُفحَص هنا:** ① **المصدر إلزامي** · ② **نوعٌ واحدٌ على
/// الأقل** · ③ ⛔ **ولا نوعٌ مكرَّر** — ★ **والواجهة تُسقِط المختار من قائمة
/// إخوته قبل أن يصل هنا** (`design-system.md` §6.ب).
Outcome<ValidatedStocktakeStart> validateStocktakeStart(
  StocktakeStartInput input,
) {
  final String sourceId = input.sourceId.trim();
  if (sourceId.isEmpty) {
    return const Failure<ValidatedStocktakeStart>(ValidationError('BR-M16-04'));
  }

  final Set<String> seen = <String>{};
  final List<String> itemKeys = <String>[];
  for (final String raw in input.itemIds) {
    final String itemKey = raw.trim();
    if (itemKey.isEmpty) {
      return const Failure<ValidatedStocktakeStart>(
        ValidationError('FR-M16-01'),
      );
    }
    if (!seen.add(itemKey)) {
      return const Failure<ValidatedStocktakeStart>(
        ValidationError('BR-M10-15'),
      );
    }
    itemKeys.add(itemKey);
  }

  if (itemKeys.length < stocktakeMinLines) {
    return const Failure<ValidatedStocktakeStart>(ValidationError('FR-M16-01'));
  }

  itemKeys.sort();
  return Success<ValidatedStocktakeStart>(
    ValidatedStocktakeStart(sourceId: sourceId, itemKeys: itemKeys),
  );
}

/// ★★★ سطرُ جردٍ **بعد التجميد** — النوعُ ورصيدُه الدفتري المقفل.
///
/// ⚠️ **و[bookBalance] يُقرأ من الدفتر مرةً واحدةً عند البدء** (`FR-M16-03`)
/// — ⛔ **ولا يُعاد قياسُه عند الاعتماد** (القاعدة ③ في ترويسة الملف).
final class FrozenStocktakeLine {
  /// ينشئ السطر.
  const FrozenStocktakeLine({
    required this.itemKey,
    required this.itemName,
    required this.bookBalance,
  });

  /// مفتاح النوع — **المعرّف أو الاسم المركّب** (`FR-M5-01` · `ADR-0007`).
  final String itemKey;

  /// اسم النوع لحظة البدء — ★ **نسخةٌ مقصودة** (`naming-conventions.md` §4).
  final String itemName;

  /// 🔒 **الرصيد الدفتري المُجمَّد** بوحدة النوع.
  final StockQuantity bookBalance;
}

// ═════════════════════════════════════════════════════════════════════════
// المرحلة الثانية — العدُّ الفعلي والاعتماد
// ═════════════════════════════════════════════════════════════════════════

/// عدٌّ فعليٌّ كما يصل من الواجهة — **قبل أي تحقق**.
final class StocktakeCountInput {
  /// ينشئ المدخلات.
  const StocktakeCountInput({
    required this.itemId,
    required this.unit,
    required this.actualCount,
    this.differenceReason,
  });

  /// معرّف النوع — ★ **وهو `itemKey` في الدفتر**.
  final String itemId;

  /// وحدة النوع — ★ **مقروءةٌ من سجل النوع** ⛔ **لا مُدخَلة** (`FR-M5-03`).
  final ItemUnit unit;

  /// ★★ **العدُّ الفعلي** بوحدة النوع — `FR-M16-07` (**الحبّة والكيلوجرام**).
  ///
  /// ⚠️ **والصفرُ عدٌّ مشروع** — ⟵ **«لم يبقَ شيء» معلومةٌ لا غياب**،
  /// ⛔ **والسالبُ وحده مرفوض.**
  final StockQuantity actualCount;

  /// ★★ سببُ الفرق — ⛔ **اختياريٌّ** (`FR-M16-04` · [`ADR-0020`]).
  ///
  /// ⚠️⚠️ **وكان إلزامياً لكل فرق ≠ 0 حتى `ADR-0020`** (2026-08-27) —
  /// ★ **و`schema/stocktakes.md` لم يُحدَّث حينها فبقي يصفه «نصي إلزامي»**:
  /// ⟵ **والنافذُ `FR-M16-04` بنصّه بعد التعديل** ⛔ **ولا يُرفَض اعتمادٌ
  /// لغيابه.** ★ **والفراغُ غيابٌ لا نصٌّ فارغ** — ⛔ **ولا يُعبِّئه التطبيق
  /// نيابةً عن المستخدم أبداً.**
  final String? differenceReason;
}

/// عدٌّ فعليٌّ مُتحقَّق منه.
final class ValidatedStocktakeCount {
  /// ينشئ العدّ.
  const ValidatedStocktakeCount({
    required this.itemKey,
    required this.actualCount,
    required this.differenceReason,
  });

  /// مفتاح النوع.
  final String itemKey;

  /// العدّ الفعلي بوحدته.
  final StockQuantity actualCount;

  /// سبب الفرق أو `null`.
  final String? differenceReason;
}

/// مستندُ اعتمادٍ مُتحقَّق منه — **جاهز للمقابلة بالمُجمَّد**.
final class ValidatedStocktakeCounts {
  /// ينشئ المستند.
  ValidatedStocktakeCounts({
    required this.sourceId,
    required this.reason,
    required List<ValidatedStocktakeCount> counts,
  }) : counts = List<ValidatedStocktakeCount>.unmodifiable(counts);

  /// المصدر.
  final String sourceId;

  /// سببُ الجرد العام أو `null` — ⛔ **اختياريٌّ** ([`ADR-0020`]).
  final String? reason;

  /// الأعداد **مرتَّبةً بمفتاح النوع** — `coding-standards.md` §2.7.
  final List<ValidatedStocktakeCount> counts;
}

/// يفحص أعداد الجرد — `FR-M16-04` · `FR-M16-07` · `GR-19`.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ★★ **خمسة قيود تُفحَص هنا:**
///
///   ① ★★ **المصدر إلزامي** (`ADR-0005`) — ⛔ **ولا «مصدر افتراضي» يُملأ.**
///   ② **عدٌّ واحدٌ على الأقل**.
///   ③ ⛔ **لا عدّان لنفس النوع**.
///   ④ ★★ **العدُّ غيرُ سالب** — ★ **والصفر مشروع** (راجع
///      [StocktakeCountInput.actualCount]).
///   ⑤ ⛔ **ووحدة العدّ = وحدة النوع** (`GR-19` · `E-31`).
/// ═══════════════════════════════════════════════════════════════════════
///
/// ⛔⛔★★ **ولا يُفحَص الفرقُ ولا سببُه هنا** — ★ **الفرقُ يُحسَب مقابل
/// المُجمَّد في المستند المخزَّن** (`FR-M16-03`)، ⟵ **وهذه الدالةُ لا ترى
/// المخزَّن أصلاً** ⛔ **فلا تُقرِّر حكماً لا تملك بياناته.**
Outcome<ValidatedStocktakeCounts> validateStocktakeCounts({
  required String sourceId,
  required List<StocktakeCountInput> counts,
  String? reason,
}) {
  final String source = sourceId.trim();
  // ① ★★ **المصدر إلزامي**.
  if (source.isEmpty) {
    return const Failure<ValidatedStocktakeCounts>(
      ValidationError('BR-M16-04'),
    );
  }
  // ② **عدٌّ واحدٌ على الأقل**.
  if (counts.length < stocktakeMinLines) {
    return const Failure<ValidatedStocktakeCounts>(
      ValidationError('FR-M16-01'),
    );
  }

  final Set<String> seen = <String>{};
  final List<ValidatedStocktakeCount> validated = <ValidatedStocktakeCount>[];
  for (final StocktakeCountInput count in counts) {
    final String itemKey = count.itemId.trim();
    if (itemKey.isEmpty) {
      return const Failure<ValidatedStocktakeCounts>(
        ValidationError('FR-M16-01'),
      );
    }
    // ③ ⛔ **لا عدّان لنفس النوع**.
    if (!seen.add(itemKey)) {
      return const Failure<ValidatedStocktakeCounts>(
        ValidationError('BR-M10-15'),
      );
    }
    // ⑤ ⛔ **ووحدة العدّ = وحدة النوع** — `GR-19` · `E-31`.
    if (count.actualCount.unit != count.unit) {
      return const Failure<ValidatedStocktakeCounts>(ValidationError('GR-19'));
    }
    // ④ ★★ **العدُّ غيرُ سالب** — ★ **والصفر مشروع**.
    if (count.actualCount.isNegative) {
      return const Failure<ValidatedStocktakeCounts>(
        ValidationError('FR-M16-07'),
      );
    }

    final Outcome<String?> lineReason =
        stocktakeOptionalText(count.differenceReason);
    if (lineReason case Failure<String?>(:final AppError error)) {
      return Failure<ValidatedStocktakeCounts>(error);
    }

    validated.add(
      ValidatedStocktakeCount(
        itemKey: itemKey,
        actualCount: count.actualCount,
        differenceReason: (lineReason as Success<String?>).value,
      ),
    );
  }

  final Outcome<String?> documentReason = stocktakeOptionalText(reason);
  if (documentReason case Failure<String?>(:final AppError error)) {
    return Failure<ValidatedStocktakeCounts>(error);
  }

  validated.sort(
    (ValidatedStocktakeCount a, ValidatedStocktakeCount b) =>
        a.itemKey.compareTo(b.itemKey),
  );
  return Success<ValidatedStocktakeCounts>(
    ValidatedStocktakeCounts(
      sourceId: source,
      reason: (documentReason as Success<String?>).value,
      counts: validated,
    ),
  );
}

/// ★ نصٌّ اختياري — ⛔ **والفراغ غيابٌ لا نصٌّ فارغ** ([`ADR-0020`]).
Outcome<String?> stocktakeOptionalText(String? value) {
  final String? text = value?.trim();
  if (text == null || text.isEmpty) return const Success<String?>(null);
  if (text.length > freeTextMaxLength) {
    return const Failure<String?>(ValidationError('GR-49'));
  }
  return Success<String?>(text);
}

// ═════════════════════════════════════════════════════════════════════════
// ★★★ الفرق — **المعادلة الوحيدة في هذه الوحدة، وموضعُها هنا لا غير**
// ═════════════════════════════════════════════════════════════════════════

/// ★★★ **الفرق = العدُّ الفعلي − الرصيدُ الدفتري المُجمَّد** — `FR-M16-01`.
///
/// ⛔⛔★★ **وقد يكون سالباً** — ★ **وهو الحالُ الأشيع** (نقصٌ غير مفسَّر):
/// ⟵ **فالنوعُ المُرجَع ليس [StockQuantity] موجبةً بالضرورة**، ★ **والاتجاهُ
/// يُشتقّ منه بـ[stocktakeAdjustment]** ⛔ **لا يُرسَل من الجهاز.**
///
/// ⛔ **والوحدتان لا تُطرحان** (`GR-19` · `E-31`) — ★ **واختلافُهما رفضٌ
/// صريحٌ لا صفرٌ صامت.**
Outcome<StockQuantity> stocktakeDifference({
  required StockQuantity bookBalance,
  required StockQuantity actualCount,
}) {
  if (bookBalance.unit != actualCount.unit) {
    return const Failure<StockQuantity>(ValidationError('GR-19'));
  }
  return switch ((bookBalance, actualCount)) {
    (
      PieceQuantity(count: final PieceCount book),
      PieceQuantity(count: final PieceCount actual)
    ) =>
      Success<StockQuantity>(PieceQuantity(actual - book)),
    (
      WeightQuantity(weight: final WeightKg book),
      WeightQuantity(weight: final WeightKg actual)
    ) =>
      Success<StockQuantity>(WeightQuantity(actual - book)),
    // ⛔ **غيرُ بالغٍ** — الوحدتان فُحصتا أعلاه، ★ **والفرعُ للاكتمال وحده.**
    _ => const Failure<StockQuantity>(ValidationError('GR-19')),
  };
}

/// ★★★ حركةُ التسوية المقابلة لفرقٍ — **اتجاهُها وكميتُها المطلقة**.
///
/// | الفرق | الاتجاه | المعنى |
/// |---|---|---|
/// | **موجب** | [MovementDirection.incoming] | ★ **تسويةٌ بالزيادة** — العدُّ أكثر من الدفتر |
/// | **سالب** | [MovementDirection.outgoing] | ★ **تسويةٌ بالنقص** — الدفترُ أكثر من العدّ |
/// | **صفر** | `null` | ⛔ **ولا حركةَ أصلاً** — ★ **ودفترٌ يطابق الواقع لا يُصحَّح** |
///
/// ⚠️⚠️★★ **والصفرُ يُرجِع `null` عمداً لا حركةً بكميةٍ صفرية:** ⟵ **حركةٌ
/// صفريةٌ في الدفتر تُوهِم المدقّقَ أن تسويةً وقعت**، ⛔ **وهي ضجيجٌ في
/// الحافظ الوحيد للتاريخ** (`RISK-05`).
StocktakeAdjustment? stocktakeAdjustment(StockQuantity difference) {
  if (difference.isZero) return null;
  return switch (difference) {
    PieceQuantity(count: final PieceCount count) => StocktakeAdjustment(
        direction: count.isNegative
            ? MovementDirection.outgoing
            : MovementDirection.incoming,
        quantity: PieceQuantity(
          count.isNegative ? PieceCount(-count.pieces) : count,
        ),
      ),
    WeightQuantity(weight: final WeightKg weight) => StocktakeAdjustment(
        direction: weight.isNegative
            ? MovementDirection.outgoing
            : MovementDirection.incoming,
        quantity: WeightQuantity(
          weight.isNegative ? WeightKg(-weight.kilograms) : weight,
        ),
      ),
  };
}

/// حركةُ تسويةٍ مشتقّة — ★ **الاتجاهُ والكميةُ المطلقة**.
final class StocktakeAdjustment {
  /// ينشئ الحركة.
  const StocktakeAdjustment({required this.direction, required this.quantity});

  /// دخولٌ للزيادة وخروجٌ للنقص.
  final MovementDirection direction;

  /// ★ الكميةُ **المطلقة** — ⛔ **ولا حركةَ بكميةٍ سالبة في الدفتر.**
  final StockQuantity quantity;
}

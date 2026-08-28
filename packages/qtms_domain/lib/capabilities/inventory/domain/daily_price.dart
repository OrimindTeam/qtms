/// التسعير اليومي (`M9`) — ★ **سعران لكل (مصدر × نوع × يوم)**.
///
/// ★ **المصدر:** `FR-M9-01` … `FR-M9-13` · `schema/daily-prices.md` ·
/// `data-dictionary.md` · `inventory-design.md` §6 · `ADR-0015`.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔★★ **أربع قواعد بنيوية يفرضها هذا الملف بنوعه ومفتاحه لا بشرطٍ يُنسى:**
///
///   ① ★★ **التصفير اليومي** (`FR-M9-01` · `GR-31`) — **اليوم جزءٌ من
///      المفتاح** ([dailyPriceId])، ⟵ **فيومٌ جديد لا سجل له أصلاً**،
///      ⛔ **ولا حقل «سارٍ حتى» يُرحِّل سعر أمس صامتاً.**
///   ② ★★ **السعر يخصّ المصدر** (`FR-M9-03` · `A-01`) — **والمصدر جزءٌ من
///      المفتاح**، ⟵ **فتسعير نوعٍ في رداع لا يُسعِّره في ماوية.**
///   ③ ★★ **مصدر السعر واحد لا يتكرر** (`FR-M9-04` · `BR-M9-03`) — ⟵ **وما
///      يُدخَل هنا وما يُدخَل في سطر الجونية (`M7`) يكتبان هذا المستند
///      نفسه**، ⛔ **ولا مخزنَ سعرٍ ثانٍ.**
///   ④ ★ **وحدة السعر تتبع وحدة النوع** (`FR-M9-06` · `BR-M9-10`) —
///      **مقروءةً من سجل النوع** ⛔ **لا مُرسَلةً** (`FR-M5-03`).
/// ═══════════════════════════════════════════════════════════════════════
///
/// ⛔★★ **والسعر مبلغ فهو `int` بالريال** (`ADR-0015` القاعدة 1) — ⛔ **لا
/// فاصلة عائمة ولا أصغر وحدة**، ★ **والمُدخَل الكسري يُرفَض برسالة
/// `ERR_MONEY_001`** ⛔ **ولا يُقرَّب صامتاً** (القاعدة 3).
///
/// ⚠️⚠️ **وهذا الملف لا يُجمِّد سعراً ولا يقرأ مجمَّداً** — `FR-M9-09`
/// (`GR-32`) يجعل **التجميد نسخةً داخل سطر المستند لحظة اعتماده**، ★ **وموضعه
/// الزيادة التي تُنشئ ذلك المستند** (`WU-006` التوزيع · `WU-012` البيع
/// النقدي · `WU-014` السحبيات) — ⛔ **لا هنا**: تسعيرُ اليوم **مرجعٌ يُقترَح
/// منه**، ★ **والمُجمَّد لا يعود ينظر إليه أبداً** (`FR-M9-11`).
library;

import '../../../core/calendar_day.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/money.dart';
import '../../../core/outcome.dart';
import '../../master_data/domain/master_data.dart' show ItemUnit;

// ═════════════════════════════════════════════════════════════════════════
// المجموعة والمفتاح — `data-dictionary.md` · `naming-conventions.md` §4
// ═════════════════════════════════════════════════════════════════════════

/// ⛅ أسعار اليوم — **LIVING · يُصفَّر يومياً** (`schema/daily-prices.md`).
const String dailyPricesCollection = 'daily_prices';

/// معرّف سجل سعر — ★ **`{sourceId}_{itemKey}_{date}`**.
///
/// ⚠️ **وترتيب الأجزاء ثابت لا يُبدَّل** (`naming-conventions.md` §4):
/// «لأنه يحدد الفهارس وكفاءة الاستعلام». ★ **وهو نفس ترتيب
/// `itemDailyBalanceId`** — ⟵ **فالسجلان يُقرآن معاً في شاشة واحدة.**
///
/// ★★ **والمفتاح هو ما يُنفِّذ القاعدتين ① و② من ترويسة الملف** — ⟵ **فلا
/// شرطَ يُنسى في استعلام**: يومٌ آخر **مستندٌ آخر**، ومصدرٌ آخر **مستندٌ آخر**.
String dailyPriceId({
  required String sourceId,
  required String itemKey,
  required CalendarDay date,
}) {
  if (sourceId.isEmpty) {
    throw ArgumentError.value(sourceId, 'sourceId', 'المصدر إلزامي في كل سعر');
  }
  if (itemKey.isEmpty) {
    throw ArgumentError.value(itemKey, 'itemKey', 'مفتاح النوع إلزامي');
  }
  return '${sourceId}_${itemKey}_${date.format()}';
}

// ═════════════════════════════════════════════════════════════════════════
// حالة التسعير — `FR-M9-05`
// ═════════════════════════════════════════════════════════════════════════

/// ★★ **تعريف «تم التسعير»** — `FR-M9-05`: **سعر توزيع وحد أدنى معاً**.
///
/// ★★ **ولماذا دالةٌ واحدة لا شرطٌ يتكرر:** الحقل `isPricingComplete`
/// **يُكتب في السحابة** ويُقرأ في الشاشة وفي فلتر «حالة التسعير» وفي المركز
/// المعلّق (`FR-M9-10`) — ⟵ **وأربع نسخٍ من الشرط تفترق عند أول تغيير**
/// (`coding-standards.md` §2.2).
///
/// ⚠️ **و«معاً» تعني الاثنين لا أحدهما:** `FR-M9-10` يُبقي في المركز المعلّق
/// **«بلا سعر توزيع أو بلا حد أدنى»** — ⟵ **فنصفُ التسعير ليس تسعيراً.**
bool isPricingComplete({
  required Money? distributionPrice,
  required Money? minCashPrice,
}) =>
    distributionPrice != null && minCashPrice != null;

/// فلتر «حالة التسعير» في الشاشة — `FR-M9-05`.
enum PricingStatusFilter {
  /// الكل.
  all,

  /// ★ تم تسعيره — **السعران معاً**.
  priced,

  /// ★ لم يتم — **ينقصه أحدهما أو كلاهما**.
  unpriced;

  /// هل يقبل هذا الفلتر صفّاً بحالة [complete]؟
  bool accepts({required bool complete}) => switch (this) {
        PricingStatusFilter.all => true,
        PricingStatusFilter.priced => complete,
        PricingStatusFilter.unpriced => !complete,
      };
}

// ═════════════════════════════════════════════════════════════════════════
// المدخلات — ★ **بلا مصدرٍ ولا يومٍ في السطر**: كلاهما في الرأس
// ═════════════════════════════════════════════════════════════════════════

/// سطر تسعير كما يصل من الواجهة — **قبل أي تحقق**.
final class DailyPriceLineInput {
  /// ينشئ المدخلات.
  const DailyPriceLineInput({
    required this.itemId,
    required this.itemName,
    required this.unit,
    this.distributionPrice,
    this.minCashPrice,
  });

  /// معرّف النوع — ★ **وهو `itemKey` في مفتاح السعر**.
  ///
  /// ★★ **ولماذا المعرّف لا الاسم:** بنفس علّة `ValidatedCountedIntakeLine`
  /// في `counted_intake.dart` — **الاسم يتغيّر بالتعديل**
  /// (`FR-M5-01`) بينما المفتاح `{sourceId}_{itemKey}_{date}` **يجب أن
  /// يثبت**، ⟵ **واسمٌ متغيّر مفتاحاً كان يُنشئ سجل سعرٍ ثانياً بصمت.**
  final String itemId;

  /// اسم النوع المعروض — ★ **مقروءٌ من سجل النوع** ⛔ **لا مُرسَل**.
  final String itemName;

  /// وحدة النوع — ★ **مقروءةٌ من سجل النوع** ⛔ **لا مُدخَلة** (`FR-M5-03`).
  final ItemUnit unit;

  /// ★ سعر التوزيع — **اقتراح لا التزام** (`FR-M9-07`) · `null` = غير مُسعَّر.
  final Money? distributionPrice;

  /// ★ الحد الأدنى للبيع النقدي — **مُلزِم فعلاً** (`FR-M9-08` · `GR-34`).
  final Money? minCashPrice;
}

/// سطر تسعير مُتحقَّق منه.
final class ValidatedDailyPriceLine {
  /// ينشئ السطر.
  const ValidatedDailyPriceLine({
    required this.itemId,
    required this.itemName,
    required this.unit,
    required this.distributionPrice,
    required this.minCashPrice,
  });

  /// معرّف النوع.
  final String itemId;

  /// ★ **مفتاح النوع في سجل السعر** — راجع [DailyPriceLineInput.itemId].
  String get itemKey => itemId;

  /// الاسم المعروض لحظة الإدخال.
  final String itemName;

  /// ★ وحدة النوع — **سعر حبة أو سعر كيلو** (`FR-M9-06`).
  final ItemUnit unit;

  /// سعر التوزيع أو `null`.
  final Money? distributionPrice;

  /// الحد الأدنى أو `null`.
  final Money? minCashPrice;

  /// ★ **السعران معاً؟** — `FR-M9-05`.
  bool get complete => isPricingComplete(
        distributionPrice: distributionPrice,
        minCashPrice: minCashPrice,
      );

  /// ★ هل السطر تفريغٌ كامل؟ — **كلا السعرين غائب**.
  ///
  /// ⚠️ **والتفريغ فعلٌ مشروع لا سطرٌ فارغ:** `schema/daily-prices.md` يجعل
  /// الحقلين `number | null`، ⟵ **فمن سعّر خطأً يُعيد النوع «غير مسعَّر»**
  /// ⛔ **ولا يُجبَر على ترك رقمٍ خاطئ قائماً.**
  bool get isCleared => distributionPrice == null && minCashPrice == null;
}

/// مدخلات دفعة تسعير — ★ **مصدرٌ واحد ويومٌ واحد** (`FR-M9-03`).
final class DailyPriceBatchInput {
  /// ينشئ المدخلات.
  const DailyPriceBatchInput({required this.sourceId, required this.lines});

  /// المصدر — ★ **إلزامي، وأسعارُه وحده تتأثر** (`FR-M9-03` · `A-01`).
  final String sourceId;

  /// السطور — ⛔ **ولا فارغة**.
  ///
  /// ★ **ودفعةٌ لا سطرٌ واحد عمداً** — `FR-M9-13`: **«التسعير الجماعي لعدة
  /// أنواع دفعة واحدة»** ⟵ **فالحالة العامة هي الدفعة**، ★ **والسطر الواحد
  /// دفعةٌ من سطر** ⛔ **لا مسارٌ ثانٍ يفترق عنها.**
  final List<DailyPriceLineInput> lines;
}

/// دفعة تسعير مُتحقَّق منها — **جاهزة للكتابة كما هي**.
final class ValidatedDailyPriceBatch {
  /// ينشئ الدفعة.
  ValidatedDailyPriceBatch({
    required this.sourceId,
    required List<ValidatedDailyPriceLine> lines,
  }) : lines = List<ValidatedDailyPriceLine>.unmodifiable(lines);

  /// المصدر.
  final String sourceId;

  /// السطور **مرتَّبةً بمفتاح النوع** — ★ **فنفس الإدخال يُنتج نفس الدفعة**
  /// في كل تشغيل (`coding-standards.md` §2.7 · إعادة المحاولة بلا أثر).
  final List<ValidatedDailyPriceLine> lines;
}

/// ★ الحدّ الأدنى لعدد السطور — **دفعةٌ بلا سطر لا تكتب شيئاً فلا معنى لها**.
const int dailyPriceMinLines = 1;

// ═════════════════════════════════════════════════════════════════════════
// التحقق — `FR-M9-03` · `FR-M9-06` · `ADR-0015`
// ═════════════════════════════════════════════════════════════════════════

/// يفحص دفعة تسعير — `FR-M9-01` … `FR-M9-08`.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ★★ **أربعة قيود تُفحَص هنا:**
///
///   ① **المصدر إلزامي** (`FR-M9-03`) — ⛔ ولا سعرَ بلا مصدر يخصّه.
///   ② **لا سطران لنفس النوع في الدفعة** — ⟵ **وإلا كتب السطران المستند
///      نفسه فغلب آخرُهما أولَهما بصمت**، ★ **والمفتاح واحد** ([dailyPriceId]).
///   ③ ★★ **السعر موجبٌ تماماً** — راجع [_price] أدناه.
///   ④ **اسم النوع غير فارغ** — ★ **وهو نسخةٌ مقصودة** للعرض والطباعة
///      (`naming-conventions.md` §4).
/// ═══════════════════════════════════════════════════════════════════════
///
/// ⛔★★ **ولا يُفحَص هنا أن للنوع كميةً اليوم** (`FR-M9-02` · `E-33`) —
/// ★ **لأنه فحصٌ يحتاج الدفتر**: الرصيد **يُجمَع داخل المعاملة الذرّية**
/// ⛔ **لا من الملخص ولا من الجهاز** (`ADR-0008`)، ⟵ **وموضعُه العملية
/// السحابية** (`daily_pricing.dart`)، **وهذه الدالة نقيّة بلا قراءة.**
Outcome<ValidatedDailyPriceBatch> validateDailyPrices(
  DailyPriceBatchInput input,
) {
  final String sourceId = input.sourceId.trim();
  if (sourceId.isEmpty) {
    return const Failure<ValidatedDailyPriceBatch>(ValidationError('FR-M9-03'));
  }

  if (input.lines.length < dailyPriceMinLines) {
    return const Failure<ValidatedDailyPriceBatch>(ValidationError('FR-M9-01'));
  }

  final Set<String> seen = <String>{};
  final List<ValidatedDailyPriceLine> validated = <ValidatedDailyPriceLine>[];

  for (final DailyPriceLineInput line in input.lines) {
    final String itemId = line.itemId.trim();
    if (itemId.isEmpty) {
      return const Failure<ValidatedDailyPriceBatch>(
        ValidationError('FR-M9-01'),
      );
    }
    // ② ⛔ **لا سطران لنفس النوع** — راجع ترويسة الدالة.
    if (!seen.add(itemId)) {
      return const Failure<ValidatedDailyPriceBatch>(
        ValidationError('BR-M9-04'),
      );
    }

    final String name = line.itemName.trim();
    if (name.isEmpty) {
      return const Failure<ValidatedDailyPriceBatch>(
        ValidationError('FR-M9-01'),
      );
    }

    final Outcome<Money?> distribution = _price(line.distributionPrice);
    if (distribution case Failure<Money?>(:final AppError error)) {
      return Failure<ValidatedDailyPriceBatch>(error);
    }
    final Outcome<Money?> minimum = _price(line.minCashPrice);
    if (minimum case Failure<Money?>(:final AppError error)) {
      return Failure<ValidatedDailyPriceBatch>(error);
    }

    validated.add(
      ValidatedDailyPriceLine(
        itemId: itemId,
        itemName: name,
        unit: line.unit,
        distributionPrice: (distribution as Success<Money?>).value,
        minCashPrice: (minimum as Success<Money?>).value,
      ),
    );
  }

  // ★ **ترتيبٌ ثابت** — راجع [ValidatedDailyPriceBatch.lines].
  validated.sort(
    (ValidatedDailyPriceLine a, ValidatedDailyPriceLine b) =>
        a.itemKey.compareTo(b.itemKey),
  );

  return Success<ValidatedDailyPriceBatch>(
    ValidatedDailyPriceBatch(sourceId: sourceId, lines: validated),
  );
}

/// ★★ يفحص سعراً واحداً — **الغياب مقبول والسالب والصفر مرفوضان**.
///
/// ⚠️⚠️ **وموجبٌ تماماً قرارُ تنفيذٍ مُعلَن لا نصٌّ منقول:** `FR-M9` **لا
/// يذكر حدّاً أدنى للسعر نفسه**، ⟵ ★ **والقاعدة المُتَّبعة هنا هي قاعدة
/// المشروع نفسها في `validateCountedIntake` ③** («**موجبٌ تماماً** — والصفر
/// ليس توريداً»).
///
/// ★★ **ولماذا الصفر مرفوض تحديداً:** `FR-M9-08` يجعل الحد الأدنى **«مُلزِماً
/// فعلاً»** والبيعَ دونه **مرفوضاً إلا بصلاحية وسبب** (`GR-34`) — ⟵ ⛔ **وحدٌّ
/// أدنى بصفر يُسقِط ذلك الحارس كلَّه بصمت** بينما يبدو النوع «مسعَّراً»
/// في الشاشة وفي `isPricingComplete` معاً. ★ **والغياب (`null`) هو التعبير
/// الصحيح عن «بلا سعر»** ⛔ **لا الصفر** — والفرق بينهما ظاهرٌ للمستخدم:
/// النوع يبقى في المركز المعلّق (`FR-M9-10`).
///
/// ★ **والتراجع رخيص:** من أراد سعراً فعلياً يكتب `1` فأعلى، ⛔ **بينما
/// قبولُ الصفر كان يفتح ثغرةً لا تظهر إلا في أول بيعٍ بأقل من الحد.**
Outcome<Money?> _price(Money? value) {
  if (value == null) return const Success<Money?>(null);
  // ⛔ **السالب والصفر معاً** — راجع ترويسة الدالة.
  if (value.isNegative || value.isZero) {
    return const Failure<Money?>(ValidationError('BR-M9-06'));
  }
  return Success<Money?>(value);
}

// ═════════════════════════════════════════════════════════════════════════
// التعديل — ★ **سبب نصّي إلزامي** (`ADR-0004` · `CR-002`)
// ═════════════════════════════════════════════════════════════════════════

/// ★★ هل يُغيّر [line] سعراً **قائماً بالفعل**؟ — ⟵ **فيكون تعديلاً لا إنشاء**.
///
/// [stored] هو سجل السعر المخزَّن **مقروءاً داخل المعاملة**، و`null` تعني
/// **غيابه** ⟵ **فالسطر إنشاءٌ خالص.**
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⚠️⚠️ **ولماذا يلزم التمييز أصلاً — وهو أدقّ موضع في هذه الوحدة:**
///
/// `security-requirements.md` §1 يفرض على **«تعديل أي مستند أو حركة»** في
/// **«كل السجلات»**: **«الصلاحية + سبب نصي غير فارغ + قيد إجباري في سجل
/// التدقيق»**، **و`FR-M9-11` يخصّ التسعير بنصّه**: «**تعديل سعر بعد استخدامه
/// لا يمس أي عملية سابقة إطلاقاً ويُسجَّل بالقيمة قبل وبعد**».
///
/// ⟵ ⛔ **فلا يصح أن تُشترَط علّةُ تعديلٍ على تسعيرٍ أوّل** (وهو الحالة
/// الغالبة كل صباح — `FR-M9-01`: **كل يوم يبدأ بلا أسعار**)، ★ **ولا أن
/// يُسقَط الشرط عن تغييرِ سعرٍ قائم** فتضيع القيمة «قبل».
///
/// ★★ **والفحص على القيمة لا على وجود المستند:** إعادةُ إرسال **نفس
/// الأسعار** (بعد انقطاع شبكة مثلاً) **ليست تعديلاً** — ⟵ **فلا تُطالَب
/// بسبب**، ★ **وهو ما يجعل إعادة المحاولة بلا أثر جانبي** حرفياً
/// (`coding-standards.md` §2.7).
/// ═══════════════════════════════════════════════════════════════════════
bool changesStoredPrice({
  required ValidatedDailyPriceLine line,
  required Map<String, Object?>? stored,
}) {
  if (stored == null) return false;
  return !_sameMoney(stored['distributionPrice'], line.distributionPrice) ||
      !_sameMoney(stored['minCashPrice'], line.minCashPrice);
}

/// ★ يقارن مبلغاً مخزَّناً بمبلغٍ جديد — ⛔ **والغياب يساوي الغياب**.
///
/// ⚠️ **والقاعدة قد تُعيد العدد الصحيح عشرياً** (`1` و`1.0`) — ★ **فيُقرآن
/// سواءً**، ⛔ **وقراءةُ ذلك «تغييراً» تُطالِب بسببٍ بلا تغيّرٍ حقيقي.**
bool _sameMoney(Object? stored, Money? next) {
  final int? current = switch (stored) {
    final int value => value,
    final double value when value == value.roundToDouble() => value.toInt(),
    final String value => int.tryParse(value),
    _ => null,
  };
  return current == next?.riyals;
}

/// دفتر حركات المخزون — ★ **مصدر الحقيقة الوحيد لكل رصيد** (`GR-01`).
///
/// ★ **المصدر:** `FR-M8-*` · `inventory-design.md` §2 و§3 و§4 ·
/// `design-overview.md` §2.1 · `data-dictionary.md` §3 ·
/// `schema/inventory-ledger.md` · `ADR-0006` (التاريخان) · `ADR-0008`.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔★★ **ثلاث قواعد بنيوية يفرضها هذا الملف بنوعه لا بشرطٍ يُنسى:**
///
///   ① **لا تُجمع حبّةٌ مع كيلوجرام أبداً** (`GR-19` · `E-31`) — ★ **والكمية
///      تحمل وحدتها في النوع** ([StockQuantity])، ⟵ **فالخلط يُرفَض صراحةً
///      لا يُجمع صامتاً.**
///   ② **الحركة الملغاة لا تدخل أي جمع، والمعدَّلة تدخل بقيمتها الجديدة**
///      (`A-14` · `design-overview.md` §2.1) — ⛔ **ولا حركة عكسية إطلاقاً.**
///   ③ **الرصيد على `stockDate` لا `entryDate`** (`RISK-07`) — ★ **والنوعان
///      لا يقبل أحدهما مكان الآخر** (`coding-standards.md` §2.3).
/// ═══════════════════════════════════════════════════════════════════════
///
/// ⚠️⚠️ **والرصيد يُجمَع من الدفتر ⛔ لا يُقرأ من الملخص** — `ADR-0008`
/// نصّاً: «**تأخّر لحظي محتمل … غير مقبول للرصيد المخزني** الذي يُقرأ
/// **داخل المعاملة الذرّية نفسها** لا من الملخص». ⟵ **و`item_daily_balances`
/// مشتقٌّ يُكتب بعد الجمع** ⛔ **ولا يُقرأ ليُبنى عليه.**
library;

import '../../../core/calendar_day.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/outcome.dart';
import '../../../core/quantity.dart';
import '../../master_data/domain/master_data.dart' show ItemUnit;

// ═════════════════════════════════════════════════════════════════════════
// أسماء المجموعات — `data-dictionary.md` §2 و§3 و§4 · `naming-conventions.md`
// §4 (`snake_case` جمعاً). ★ **مصدر حقيقة واحد يشاركه التطبيق والسحابة.**
// ═════════════════════════════════════════════════════════════════════════

/// دفتر حركات المخزون — ★ **لا يُحذف منه شيء أبداً**.
const String inventoryLedgerCollection = 'inventory_ledger';

/// مستندات الوارد عدداً (`M6`).
const String incomingCountCollection = 'incoming_count';

/// ⛅ رصيد النوع في يوم — **ملخص مشتقّ** (`ADR-0008`).
///
/// ⚠️ **وغيابُ السجل يعني صفراً** — `ADR-0008` القاعدة 5:
/// «⛔ **لا يُنشأ سجل بصفر بلا داعٍ**».
const String itemDailyBalancesCollection = 'item_daily_balances';

// ═════════════════════════════════════════════════════════════════════════
// المفاتيح المركّبة — `naming-conventions.md` §4 (**ترتيبها ملزم**)
// ═════════════════════════════════════════════════════════════════════════

/// معرّف سجل رصيد النوع في يوم — `{sourceId}_{itemKey}_{stockDate}`.
///
/// ⚠️ **وترتيب الأجزاء ثابت لا يُبدَّل** (`naming-conventions.md` §4):
/// «لأنه يحدد الفهارس وكفاءة الاستعلام».
String itemDailyBalanceId({
  required String sourceId,
  required String itemKey,
  required CalendarDay stockDate,
}) {
  if (sourceId.isEmpty) {
    throw ArgumentError.value(sourceId, 'sourceId', 'المصدر إلزامي في كل سطر');
  }
  if (itemKey.isEmpty) {
    throw ArgumentError.value(itemKey, 'itemKey', 'مفتاح النوع إلزامي');
  }
  return '${sourceId}_${itemKey}_${stockDate.format()}';
}

/// ★ معرّف حركة دفترية — `{documentNumber}_{itemKey}`.
///
/// ★★ **ولماذا معرّفٌ مشتقٌّ لا عشوائي:** التعديل **يقع على الحركة نفسها**
/// (`FR-M6-11` · `A-14`) ⛔ **ولا يُنشئ حركة تصحيحية**، ⟵ **فلا بدّ من
/// مسارٍ يُصيبها مباشرةً بلا استعلام**. ★ **وهو كذلك ما يجعل إعادة الإرسال
/// تكتب فوق الحركة نفسها** ⛔ **لا حركةً ثانية بنفس الكمية.**
String stockMovementId({
  required String documentNumber,
  required String itemKey,
}) {
  if (documentNumber.isEmpty) {
    throw ArgumentError.value(documentNumber, 'documentNumber', 'الرقم إلزامي');
  }
  if (itemKey.isEmpty) {
    throw ArgumentError.value(itemKey, 'itemKey', 'مفتاح النوع إلزامي');
  }
  return '${documentNumber}_$itemKey';
}

// ═════════════════════════════════════════════════════════════════════════
// تصنيف الحركة — `schema/inventory-ledger.md`
// ═════════════════════════════════════════════════════════════════════════

/// اتجاه الحركة — `data-dictionary.md` §3 (`direction`).
enum MovementDirection {
  /// دخول: وارد عدداً · وارد جواني والسكرب · تسوية جرد بالزيادة.
  incoming,

  /// خروج: توزيع · بيع نقدي · سحبيات وخرجيات · إتلاف · تسوية جرد بالنقص.
  outgoing,
}

/// وسم الحركة — ★ **ويُستثنى منه ما لا يدخل المبيعات ولا سعر الجونية**.
enum MovementTag {
  /// عادية.
  normal,

  /// ★ **تسوية جرد** — `AT-66`: ⛔ **لا تُحتسب في سعر أي جونية ولا المبيعات**.
  adjustment,

  /// ★ **إتلاف** — `FR-M8-16`: ⛔ **بلا أي قيمة مالية ولا استحقاق للرعوي**.
  disposal,
}

/// نوع المستند المصدر للحركة — `data-dictionary.md` §3 (`sourceDocType`).
///
/// ⚠️ **ولا تُضاف قيمة هنا بلا مستندٍ يكتبها فعلاً** — ★ **والقائمة تُستكمل
/// في زيادة كل مستند**، ⛔ **ولا تُملأ استباقاً بقيمٍ لا كاتب لها.**
enum SourceDocumentType {
  /// وارد عدداً — `M6` (`WU-003`).
  countedIntake,

  /// ★ وارد جواني — `M7` (`WU-004`).
  ///
  /// ⚠️⚠️ **وحركاته تحمل `sackId` بخلاف [countedIntake]** — `ADR-0007`
  /// القاعدة 5 و`BR-M6-10`: ⟵ **وهو الحقل الذي يُبنى عليه سعر الجونية**،
  /// ★ **فأنواعُ الجونية تدخل احتسابه** ⛔ **والوارد عدداً لا يدخله.**
  sack,

  /// ★ توزيع — `M10` (`WU-006`).
  ///
  /// ⛔⛔★★ **وحركاته [MovementDirection.outgoing] دائماً** — `FR-M10-05`:
  /// «**الخصم المخزني فوري في كل الأحوال**» ⟵ **سُعِّرت السطور أم لا**.
  /// ★ **وتحمل `sackId` متى كان النوع من جونية** (`FR-M10-14` · `A-13`)،
  /// ⟵ **فتدخل إعادة احتساب سعر تلك الجونية** ⛔ **وغيابُه يُسقِطها بصمت.**
  ///
  /// ⚠️⚠️ **ودرسُ `sourceDocType` المحفور قائمٌ هنا** (`DEBT` 2026-08-26):
  /// ⛔ **لا يُفترَض ثابتٌ لأن كاتبه اليوم واحد** — ★ **فالقيمة تُمرَّر من
  /// العملية الكاتبة صراحةً** ⛔ **ولا تُحفَر في دالة الكتابة.**
  distribution,

  /// ★ بيع نقدي مباشر — `M11` (`WU-012`).
  ///
  /// ⛔⛔★★ **وحركاته [MovementDirection.outgoing] دائماً** — `FR-M11-02`:
  /// «**يخصم من المخزون فوراً**»، ★ **وتحمل `sackId` متى كان النوع من
  /// جونية** (`FR-M11-09` · `A-13`) ⟵ **فقيمةُ بيعه تدخل سعر تلك الجونية.**
  ///
  /// ⛔⛔★★★ **ولا قيدَ له في دفتر المقاوته إطلاقاً** (`FR-M11-03` · `GR-33`)
  /// — ★ **فهو الوحيد بين أنواع الصرف الذي يُخرِج مخزوناً بلا ذمّة**:
  /// ⟵ **والتمييزُ بهذه القيمة هو ما يجعل «الآجل» و«النقدي» سطرين مستقلّين
  /// في بطاقة ضمار المالك** (`design-overview.md` §2.8 البندان 1 و2).
  cashSale,

  /// ★★ **سحبية مالك** — `M22` (`WU-014`).
  ///
  /// ⛔⛔★★ **وحركاتُها [MovementDirection.outgoing] دائماً** — `FR-M22-06`:
  /// **بند «قات» يخرج من المخزون ويستحق الرعوي ثمنه**، ★ **وتحمل `sackId`
  /// متى كان النوع من جونية** (`E-26`) ⟵ **فقيمتُها تدخل سعر تلك الجونية.**
  ///
  /// ⛔⛔★★★ **ولا قيدَ لها في دفتر المقاوته إطلاقاً** (`FR-M22-04` · `GR-44`)
  /// — ★ **تشترك في ذلك مع [cashSale] وحدها**: ⟵ **والفارقُ أن البيع النقدي
  /// يُدخِل نقداً وهذه تُخرِجه.**
  ///
  /// ⛔⛔★★★ **وقيمةٌ مستقلة عن [expense] عمداً** — `FR-M22-03` · `GR-43`:
  /// ⟵ **فتقريرُ المصدر يفصل الإجماليين**، ★ **وحقلُ `ledgerType` في الدفتر
  /// الرابع يقابله هذا الحقلُ في دفتر المخزون** ⛔ **فلا يُستنتَج أحدهما من
  /// الآخر باستعلامٍ ثانٍ.**
  withdrawal,

  /// ★★★ **إتلاف** — `M8` (`WU-020` · `FR-M8-16`).
  ///
  /// ⛔⛔★★★ **وحركاتُه [MovementDirection.outgoing] دائماً ووسمُها
  /// [MovementTag.disposal]** — ★ **وهو الفارقُ الوحيد الذي يجعل هذا
  /// الخروجَ بلا استحقاقٍ للرعوي** (`A-15` · `schema/supplier-ledger.md`):
  /// ⟵ **فكلُّ خروجٍ آخر يستحق الرعوي ثمنَه**، ⛔ **والإتلافُ والوزنُ الضائع
  /// وحدهما خارجَ ذلك.**
  ///
  /// ⛔⛔★★★ **ولا يدخل سعرَ الجونية إطلاقاً** (`design-overview.md` §2.2) —
  /// ★ **والضمانةُ بنيويةٌ لا شرطيّة:** ⟵ **`readSackMovementDocuments`
  /// تقرأ `distributions` و`cash_sales` و`outflows` وحدها** ⛔ **ولا
  /// `disposals` فيها** — ★ **فما لا يُقرأ لا يُجمَع.**
  ///
  /// ⛔ **ولا قيدَ له في دفتر المقاوته ولا في ضمار المالك** — ★ **لا مبلغَ
  /// فيه أصلاً** (`FR-M8-16`).
  disposal,

  /// ★★ **خرجية تشغيلية** — `M22` (`WU-014`) — راجع [withdrawal].
  ///
  /// ⚠️⚠️ **ودرسُ `sourceDocType` المحفور يبلغ ذروته هنا** (2026-08-26):
  /// ⟵ **مسارُ الكود واحدٌ للسجلَّين** (`outflow-design.md` §2)، ⛔ **فقيمةٌ
  /// محفورةٌ في دالة الكتابة كانت ستَسِم كلَّ خرجيةٍ «سحبيةً»** — ★ **وهو
  /// بالضبط العطلُ الذي وَسَمَ حركاتِ الجواني «وارداً عدداً».**
  expense,

  /// ★★★ **جرد** — `M16` (`WU-022`) · `data-dictionary.md` §3 (**«جرد»**).
  ///
  /// ⛔⛔★★★ **وهو النوعُ الوحيد الذي تكون حركتُه دخولاً أو خروجاً** —
  /// ⟵ **فتسويةُ الزيادة تُدخِل وتسويةُ النقص تُخرِج** (`inventory-design.md`
  /// §3: **«تسوية جرد بالزيادة»** في الدخول **و«تسوية جرد بالنقص»** في
  /// الخروج)، ★ **والاتجاهُ يُشتقّ من إشارة الفرق** (`stocktakeAdjustment`)
  /// ⛔ **ولا يُرسَل من الجهاز.**
  ///
  /// ★★ **وحركتُه مَوْسومةٌ [MovementTag.adjustment] دائماً** — `BR-M16-03` ·
  /// `AT-66`: ⟵ **فتُستثنى من تقارير المبيعات ومن احتساب سعر الجونية ومن
  /// استحقاق الرعوي**، ⛔ **و[MovementTag.normal] هنا كان يُدخِل تصحيحَ
  /// خطأِ عدٍّ في إيرادِ جونيةٍ بصمت.**
  stocktake,
}

// ═════════════════════════════════════════════════════════════════════════
// الكمية — ★ **تحمل وحدتها في النوع** (`GR-19`)
// ═════════════════════════════════════════════════════════════════════════

/// كمية مخزنية بوحدتها — ⛔ **ولا عملية بين وحدتين مختلفتين إطلاقاً**.
///
/// ★★ **ولماذا نوعٌ مُغلَق لا `num` بحقل وحدة:** `coding-standards.md` §2.1
/// («كل كمية تحمل وحدتها معها في النوع») و`GR-19` — ⟵ **والمطابقة على
/// النوع المُغلَق تُلزم كل مُستدعٍ بمعالجة الوحدتين**، ⛔ **فلا يمرّ جمعٌ
/// مختلط في مراجعةٍ ولا في تشغيل.**
sealed class StockQuantity {
  /// ينشئ الكمية.
  const StockQuantity();

  /// ★ صفرُ الوحدة المطلوبة — **بداية كل تجميع**.
  factory StockQuantity.zeroOf(ItemUnit unit) => switch (unit) {
        ItemUnit.piece => const PieceQuantity(PieceCount.zero),
        ItemUnit.kilogram => const WeightQuantity(WeightKg.zero),
      };

  /// وحدة هذه الكمية.
  ItemUnit get unit;

  /// هل هي سالبة؟ — ★ **والرصيد السالب ممنوع تماماً** (`FR-M8-01`).
  bool get isNegative;

  /// هل هي صفر؟ — ⚠️ **والصفر لا يُنشأ له سجل رصيد** (`ADR-0008` القاعدة 5).
  bool get isZero;

  /// هل هي موجبة تماماً؟
  bool get isPositive => !isNegative && !isZero;
}

/// كمية معدودة بالحبّة — ⛔ **والكسور مرفوضة** (`BR-M6-06`).
final class PieceQuantity extends StockQuantity {
  /// ينشئ الكمية.
  const PieceQuantity(this.count);

  /// العدد.
  final PieceCount count;

  @override
  ItemUnit get unit => ItemUnit.piece;

  @override
  bool get isNegative => count.isNegative;

  @override
  bool get isZero => count.isZero;

  @override
  bool operator ==(Object other) =>
      other is PieceQuantity && other.count.pieces == count.pieces;

  @override
  int get hashCode => count.pieces.hashCode;

  @override
  String toString() => '${count.pieces} حبة';
}

/// كمية وزنية بالكيلوجرام — **بثلاث خانات عشرية**.
///
/// ⚠️ **ولا كاتبَ لها في `WU-003`:** الوارد عدداً **بلا أوزان إطلاقاً**
/// (`FR-M6-10`)، ★ **وأول كاتبٍ لها السكرب في `WU-004`** — ⟵ **والنوع
/// موجودٌ من الآن لأن وحدة النوع جزءٌ من هويته** (`FR-M5-03`)، ⛔ **فلا
/// دفترَ بوحدةٍ واحدة يُعاد بناؤه لاحقاً.**
final class WeightQuantity extends StockQuantity {
  /// ينشئ الكمية.
  const WeightQuantity(this.weight);

  /// الوزن بالكيلوجرام.
  final WeightKg weight;

  @override
  ItemUnit get unit => ItemUnit.kilogram;

  @override
  bool get isNegative => weight.isNegative;

  @override
  bool get isZero => weight.kilograms == 0;

  @override
  bool operator ==(Object other) =>
      other is WeightQuantity && other.weight.kilograms == weight.kilograms;

  @override
  int get hashCode => weight.kilograms.hashCode;

  @override
  String toString() => '${weight.formatted()} كجم';
}

// ═════════════════════════════════════════════════════════════════════════
// الحركة كما تُقرأ من الدفتر
// ═════════════════════════════════════════════════════════════════════════

/// سطر دفتري مقروء — **بما يلزم لجمع الرصيد وحده**.
///
/// ⛔ **ولا يحمل الحقول المرجعية كاملة عمداً** (المستخدم · وقت التعديل ·
/// السبب): ★ **الجمع لا يحتاجها**، ⟵ **وحملُها هنا يُغري بأن يُبنى عليها
/// قرارٌ في دالة الجمع.**
final class StockMovement {
  /// ينشئ الحركة.
  const StockMovement({
    required this.itemKey,
    required this.direction,
    required this.quantity,
    required this.isCancelled,
    this.movementTag = MovementTag.normal,
  });

  /// مفتاح النوع — **النوع المجرَّد أو الاسم المركّب**.
  final String itemKey;

  /// دخول أم خروج.
  final MovementDirection direction;

  /// الكمية بوحدتها.
  final StockQuantity quantity;

  /// ★ **الملغاة لا تدخل أي جمع** — ⛔ **وهي بديل الحركة العكسية** (`A-14`).
  final bool isCancelled;

  /// وسم الحركة.
  final MovementTag movementTag;
}

// ═════════════════════════════════════════════════════════════════════════
// المعادلة — `design-overview.md` §2.1
// ═════════════════════════════════════════════════════════════════════════

/// ★★ **رصيد النوع في (المصدر × تاريخ المخزون)** — `design-overview.md` §2.1:
///
/// ```text
/// رصيد النوع في اليوم = Σ(الداخل) − Σ(الخارج)   [للحركات غير الملغاة فقط]
/// ```
///
/// ⚠️ **و[unit] وحدة النوع المخزَّنة لا وحدةً تُستنتَج من الحركات:** ★ **وحدة
/// النوع جزءٌ من هويته ولا تتغيّر** (`FR-M5-03` · `FR-M5-04`)، ⟵ **فحركةٌ
/// بوحدةٍ أخرى فسادُ بياناتٍ يُرفَض صراحةً** ⛔ **لا يُجمَع صامتاً** (`GR-19`).
///
/// ★ **وغياب الحركات يعني صفراً** — ⛔ **لا خطأ**: يومٌ لم يرد فيه شيء
/// **حالةٌ طبيعية**، وهي بالضبط «رصيد بداية أي يوم = 0» (`FR-M8-09`).
Outcome<StockQuantity> computeItemBalance({
  required Iterable<StockMovement> movements,
  required ItemUnit unit,
}) {
  int pieces = 0;
  double kilograms = 0;

  for (final StockMovement movement in movements) {
    // ① ⛔ **الملغاة لا تدخل أي جمع** — `A-14` · `design-overview.md` §2.1.
    if (movement.isCancelled) continue;
    // ② ⛔ **ولا وحدة غريبة** — `GR-19` · `E-31`.
    if (movement.quantity.unit != unit) {
      return const Failure<StockQuantity>(ValidationError('GR-19'));
    }
    final int sign = movement.direction == MovementDirection.incoming ? 1 : -1;
    switch (movement.quantity) {
      case PieceQuantity(:final PieceCount count):
        pieces += sign * count.pieces;
      case WeightQuantity(:final WeightKg weight):
        kilograms += sign * weight.kilograms;
    }
  }

  return Success<StockQuantity>(
    switch (unit) {
      ItemUnit.piece => PieceQuantity(PieceCount(pieces)),
      // ⚠️ **بلا تقريب هنا** — `ADR-0015` القاعدة 4: **التقريب في نهاية
      //    سلسلة الحساب**، ★ **والعرض يُظهرها بثلاث خانات** (`WeightKg`).
      ItemUnit.kilogram => WeightQuantity(WeightKg(kilograms)),
    },
  );
}

/// ★ تدفّق النوع في يوم — **الوارد والصادر والرصيد معاً**.
///
/// ★★ **وهو محتوى `item_daily_balances` حرفياً** (`data-dictionary.md` §4:
/// «الوارد · الصادر · الرصيد · `unit`») — ⟵ **فالملخص يُبنى من دالةٍ واحدة**
/// ⛔ **ولا يُجمَع مرةً هنا ومرةً في الشاشة** (`coding-standards.md` §2.2).
final class ItemDailyFlow {
  /// ينشئ التدفّق.
  const ItemDailyFlow({
    required this.incoming,
    required this.outgoing,
    required this.balance,
  });

  /// إجمالي الداخل.
  final StockQuantity incoming;

  /// إجمالي الخارج.
  final StockQuantity outgoing;

  /// الرصيد — `Σ(الداخل) − Σ(الخارج)`.
  final StockQuantity balance;
}

/// ★★ يبني تدفّق النوع في يوم من الدفتر — **بنفس قواعد [computeItemBalance]**.
///
/// ⚠️ **والملغاة تُستثنى من الأعمدة الثلاثة معاً** — ⛔ **لا من الرصيد وحده**:
/// عمودُ وارد يعدّ حركةً ملغاة **يجعل الملخص يشهد بوارد لم يقع** (`A-14`).
///
/// ★★ **والرصيد من [computeItemBalance] لا يُعاد حسابه هنا** — معادلة §2.1
/// **لها دالة واحدة** (`coding-standards.md` §2.2)، ⟵ **ونسخةٌ ثانية منها
/// تفترق عند أول تعديل.** ★ **وما يُحسَب هنا مركّباتُه** (الوارد والصادر)
/// **لا هو.**
Outcome<ItemDailyFlow> computeItemDailyFlow({
  required Iterable<StockMovement> movements,
  required ItemUnit unit,
}) {
  int incomingPieces = 0;
  int outgoingPieces = 0;
  double incomingKilograms = 0;
  double outgoingKilograms = 0;

  for (final StockMovement movement in movements) {
    // ⛔ **الملغاة لا تدخل عموداً من الثلاثة** — راجع ترويسة الدالة.
    if (movement.isCancelled) continue;
    if (movement.quantity.unit != unit) {
      return const Failure<ItemDailyFlow>(ValidationError('GR-19'));
    }
    final bool isIncoming = movement.direction == MovementDirection.incoming;
    switch (movement.quantity) {
      case PieceQuantity(:final PieceCount count):
        if (isIncoming) {
          incomingPieces += count.pieces;
        } else {
          outgoingPieces += count.pieces;
        }
      case WeightQuantity(:final WeightKg weight):
        if (isIncoming) {
          incomingKilograms += weight.kilograms;
        } else {
          outgoingKilograms += weight.kilograms;
        }
    }
  }

  final Outcome<StockQuantity> balance =
      computeItemBalance(movements: movements, unit: unit);
  if (balance case Failure<StockQuantity>(:final AppError error)) {
    return Failure<ItemDailyFlow>(error);
  }

  StockQuantity of(int pieces, double kilograms) => switch (unit) {
        ItemUnit.piece => PieceQuantity(PieceCount(pieces)),
        // ⚠️ **بلا تقريب** — `ADR-0015` القاعدة 4.
        ItemUnit.kilogram => WeightQuantity(WeightKg(kilograms)),
      };

  return Success<ItemDailyFlow>(
    ItemDailyFlow(
      incoming: of(incomingPieces, incomingKilograms),
      outgoing: of(outgoingPieces, outgoingKilograms),
      balance: (balance as Success<StockQuantity>).value,
    ),
  );
}

/// ★★ **الرصيد السالب ممنوع تماماً** — `FR-M8-01` · `BR-M8-01` · `GR-11`.
///
/// ⚠️⚠️ **وهذه إحدى طبقتَي المنع لا كلتاهما:** `inventory-design.md` §4
/// يفرض **المعاملة الذرّية + قاعدة الحماية**. ⛔ **وبعد `WU-026` أُغلق مسار
/// الكتابة المباشر كلياً** (`allow write: if false` على الدفتر والأرصدة)،
/// ⟵ ★ **فصار هذا السطر داخل المعاملة هو الحارس العملي**، **والقاعدة تحرس
/// بالمنع المطلق لا بالشرط** — ⛔ **فإسقاطه ثغرة صامتة** (`DEBT-21` ①).
Outcome<void> validateNonNegativeBalance(StockQuantity balance) =>
    balance.isNegative
        ? const Failure<void>(InsufficientStockError())
        : const Success<void>(null);

/// ★ يضيف كميةً إلى رصيد — ⛔ **ويرفض اختلاف الوحدة** (`GR-19`).
///
/// ★★ **ولماذا دالةٌ لا عاملُ جمعٍ على [StockQuantity]:** عاملُ الجمع **يلزمه
/// أن يُرجِع كميةً**، ⟵ **فلا مخرج له عند اختلاف الوحدة إلا الرمي أو الطيّ
/// الصامت** — ⛔ **وكلاهما مرفوض هنا**: القاعدة نتيجةٌ لا استثناء
/// (`error-handling-strategy.md` §3 القاعدة 3).
Outcome<StockQuantity> addQuantity(StockQuantity a, StockQuantity b) {
  if (a.unit != b.unit) {
    return const Failure<StockQuantity>(ValidationError('GR-19'));
  }
  return Success<StockQuantity>(
    switch ((a, b)) {
      (PieceQuantity(count: final PieceCount x), PieceQuantity(count: final PieceCount y)) =>
        PieceQuantity(x + y),
      (WeightQuantity(weight: final WeightKg x), WeightQuantity(weight: final WeightKg y)) =>
        WeightQuantity(x + y),
      // ⟵ يستحيل بلوغه بعد فحص الوحدة أعلاه، ★ **والتصريف يُلزم بذكره.**
      _ => a,
    },
  );
}

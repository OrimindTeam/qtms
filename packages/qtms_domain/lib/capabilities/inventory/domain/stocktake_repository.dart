/// عقود مستودع الجرد — **قراءةً وكتابةً** (`M16` · `WU-022`).
///
/// ★ **الفصل مقصود ويطابق `ADR-0013`:** القراءة **مباشرة من القاعدة**
/// (القاعدة 4) **بشرطِ `stocktakeView` ونطاقِ المصادر**، **والكتابة عبر
/// عمليةٍ سحابيةٍ مستدعاة** تكتب المستند وحركاتِ تسويته وأرصدتَه **وقيدَ
/// تدقيقه في معاملة واحدة** (القاعدة 1).
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **ولا حقلَ ماليٍّ في أيِّ نوعٍ هنا** — `BR-M16-03` · `AT-66`:
/// ★ **بنفس القاعدة ① في `stocktake.dart`**، ⟵ **فبطاقةُ العرض نفسُها بلا
/// مبلغ** ⛔ **ولا شاشةَ تعرض «قيمة الفرق»** — ★ **إذ لا قيمةَ له أصلاً.**
///
/// ★★★ **وأربعُ عملياتٍ لا ثلاث** — ⟵ **لأن للجرد مرحلتين** (`FR-M16-03`
/// و`FR-M16-09`): **بدءٌ يُجمِّد** ثم **اعتمادٌ يُسوّي**، ★ **ولكلٍّ مفتاحُه.**
/// ═══════════════════════════════════════════════════════════════════════
library;

import '../../../core/calendar_day.dart';
import '../../../core/outcome.dart';
import 'inventory.dart' show StockQuantity;
import 'stocktake.dart';

/// سطرُ جردٍ مخزَّن كما يُقرأ للعرض.
final class StocktakeCardLine {
  /// ينشئ السطر.
  const StocktakeCardLine({
    required this.itemKey,
    required this.itemName,
    required this.bookBalance,
    this.actualCount,
    this.difference,
    this.differenceReason,
  });

  /// مفتاح النوع.
  final String itemKey;

  /// اسم النوع لحظة البدء — ★ **نسخةٌ مقصودة**.
  final String itemName;

  /// 🔒 الرصيد الدفتري المُجمَّد.
  final StockQuantity bookBalance;

  /// ★ العدّ الفعلي — و`null` **في المسوّدة قبل الاعتماد**.
  final StockQuantity? actualCount;

  /// ★ الفرق — و`null` **في المسوّدة**، ⛔ **وقد يكون سالباً بعد الاعتماد.**
  final StockQuantity? difference;

  /// سببُ الفرق — **اختياريٌّ** (`FR-M16-04` · [`ADR-0020`]).
  final String? differenceReason;
}

/// بطاقة مستند الجرد.
final class StocktakeCard {
  /// ينشئ البطاقة.
  StocktakeCard({
    required this.documentNumber,
    required this.stockDate,
    required this.sourceId,
    required this.status,
    required List<StocktakeCardLine> lines,
    this.sourceName,
    this.reason,
    this.cancelReason,
    this.amendCount = 0,
  }) : lines = List<StocktakeCardLine>.unmodifiable(lines);

  /// رقم المستند — `STK-…` **وهو معرّفه**.
  final String documentNumber;

  /// ★★ **تاريخ المخزون المجرود** — ★ **وقد يكون سابقاً بصلاحية**
  /// (`FR-M16-08`).
  final CalendarDay stockDate;

  /// ★★★ المصدر — ⛔ **إلزاميٌّ** (`BR-M16-04`).
  final String sourceId;

  /// اسم المصدر لحظة البدء — ★ **نسخةٌ مقصودة**.
  final String? sourceName;

  /// ★★★ الحالة — ⛔ **ثلاثٌ لا اثنتان** (راجع [StocktakeStatus]).
  final StocktakeStatus status;

  /// السطور.
  final List<StocktakeCardLine> lines;

  /// سببُ الجرد العام — **اختياريٌّ**.
  final String? reason;

  /// سبب الإلغاء — **اختياريٌّ**.
  final String? cancelReason;

  /// عدد التعديلات — ★ **مصدر شارة «مُعدَّل»**.
  final int amendCount;

  /// ★ هل هذا المستند **مسوّدةٌ قائمة**؟ — ⟵ **وهو ما يمنع جرداً ثانياً**
  /// على نفس المصدر واليوم (`FR-M16-06`).
  bool get isOpen => status == StocktakeStatus.draft;
}

/// دليل الجرد — **قراءةً فقط**.
abstract interface class StocktakeDirectory {
  /// ★ مستندات الجرد في مصدرٍ بعينه — الفهرس `sourceId ↑ · stockDate ↓`.
  ///
  /// ⛔⛔★★★ **و[sourceId] مُقيَّدٌ صراحةً ⛔ لا ضمنيّاً:** ★ **شرطُ قراءة
  /// `stocktakes` يقرأ `resource.data.sourceId` عبر `storedInScope()`** —
  /// ⟵ **واستعلامٌ لا يُقيّده يُرفَض كاملاً ولو كان نطاق المستخدم شاملاً**
  /// (`IQ-024` · `WU-008` · `DEBT-40` · `WU-016`).
  Stream<List<StocktakeCard>> watchStocktakes({
    required String sourceId,
    int limit,
  });
}

/// مستودع كتابة الجرد — **عبر العمليات المستدعاة حصراً**.
///
/// ⛔★★ **ولا كتابة مباشرة واحدة:** `stocktakes` و`inventory_ledger` و
/// `item_daily_balances` **كلها مغلقةٌ للكتابة** — ⟵ **فالواجهة تطلب ولا
/// تكتب** (`ADR-0013` القاعدة 2).
abstract interface class StocktakeAdminRepository {
  /// ★★★ **يبدأ جرداً** ويُرجِع **رقمه** — ★ **والرقم من السحابة** ⛔ **ولا
  /// يُولِّده الجهاز** (`naming-conventions.md` §5).
  ///
  /// ⛔⛔★★ **ولا يُرسِل الجهازُ رصيداً دفترياً** — `FR-M16-01`: ★ **يُقاس من
  /// الدفتر داخل المعاملة ويُجمَّد** (`FR-M16-03`).
  ///
  /// ★★ **و[stockDate] اختياريٌّ:** ⟵ **غيابُه يعني «مخزون اليوم»**،
  /// ★ **ووجودُه أقدمَ من اليوم يشترط `stocktakePriorDay`** (`FR-M16-08`)
  /// ⛔ **والمستقبليُّ مرفوضٌ للجميع بلا مفتاحٍ يفتحه.**
  Future<Outcome<String>> startStocktake({
    required String sourceId,
    List<String> itemIds,
    CalendarDay? stockDate,
    String? reason,
  });

  /// ★★★ **يعتمد الجرد بالعدّ الفعلي** — **بمفتاح «اعتماد الجرد»**
  /// (`FR-M16-09`) ⟵ **وتُكتب حركاتُ التسوية وقيدُ التدقيق** (`FR-M16-11`).
  Future<Outcome<void>> approveStocktake({
    required String documentNumber,
    required String sourceId,
    List<StocktakeCountInput> counts,
    String? reason,
  });

  /// ★ يعدّل جرداً معتمداً — **بمفتاح «تعديل الجرد» وسببٍ نصّي اختياري**
  /// ([`ADR-0020`]) ⟵ **وتُعاد الأرصدة احتساباً** (`A-14`).
  ///
  /// ⛔⛔★★ **والرصيدُ الدفتري المُجمَّد لا يُمَسّ في التعديل** —
  /// `FR-M16-03`: ⟵ **التعديلُ يُصحِّح العدَّ لا التجميد**، ★ **وإعادةُ
  /// التجميد كانت ستمحو الحدَّ الذي وقع الجردُ عنده.**
  Future<Outcome<void>> amendStocktake({
    required String documentNumber,
    required String sourceId,
    List<StocktakeCountInput> counts,
    String? amendReason,
  });

  /// ★ يُلغي مستنداً — **بمفتاح «إلغاء الجرد»** ⟵ **وتُلغى حركاتُ تسويته**
  /// ⛔ **بلا حركةٍ عكسية** (`A-14` · `GR-06`).
  ///
  /// ⛔ **والحذف مرفوض نهائياً** (`GR-07`) — ⟵ **فلا دالة حذف في هذا العقد.**
  Future<Outcome<void>> cancelStocktake({
    required String documentNumber,
    required String sourceId,
    String? cancelReason,
  });
}

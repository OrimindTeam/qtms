/// عقود مستودعات البيع النقدي — **قراءةً وكتابةً**.
///
/// ★ **الفصل مقصود ويطابق `ADR-0013`:** القراءة **مباشرة من القاعدة**
/// (القاعدة 4)، **والكتابة عبر دالة سحابية مستدعاة** تكتب المستند وحركاته
/// المخزنية وأرصدته **وقيدَ تدقيقه في معاملة واحدة** (القاعدة 1).
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **وبطاقةٌ واحدة لا بطاقتان — وهذا فارقٌ جوهري عن التوزيع:**
///
/// ★ **`ADR-0011` عزل أسعارَ التوزيعة لأن `ت-12` يُخفيها عمّن لا يملك
/// `distributionPriceView`** (`FR-M10-07`) — ⛔ **ولا نظير لذلك هنا:**
/// `FR-M11` **لا يعرف مفتاحَ «عرض أسعار البيع النقدي» أصلاً** (الكتالوج §2.3)،
/// ⟵ **والسعرُ جزءٌ من السند نفسِه** (`schema/cash-sales.md`: `lines[]` تحمل
/// `unitPrice` **إلزامياً**، **والإجماليات تحمل `netCashReceived`**).
///
/// ★★ **والسبب الجوهري:** ★ **قيمةُ الضمار دَينٌ على مقوتٍ بعينه** فيُقيَّد
/// عليه ولو لم يره المُدخِل — ★ **وصافي المقبوض نقدٌ في الصندوق الآن**،
/// ⟵ **ومن يُدخِل بيعاً نقدياً يقبض ثمنَه بيده** ⛔ **فإخفاؤه عنه لا معنى له.**
/// ═══════════════════════════════════════════════════════════════════════
library;

import '../../../core/calendar_day.dart';
import '../../../core/money.dart';
import '../../../core/outcome.dart';
import '../../../core/quantity.dart';
import 'cash_sale.dart';

/// بطاقة سند البيع النقدي — **المستند كاملاً بأسعاره**.
///
/// ⛔⛔★★ **ولا حقلَ مقوتٍ واحد فيها** (`FR-M11-03` · `GR-33`) — ★ **والغياب
/// البنيوي هو الحارس**: ⟵ **فلا شاشةَ تعرض «على من» ولا تقريرٌ يجمعه في
/// ذمّة**، ⛔ **ولا حقلَ اسمِ مشترٍ ولا خصم** (`FR-M11-12` · `ت-06`).
final class CashSaleCard {
  /// ينشئ البطاقة.
  CashSaleCard({
    required this.documentNumber,
    required this.sourceId,
    required this.stockDate,
    required this.entryDate,
    required this.status,
    required this.totalPieces,
    required this.totalWeight,
    required this.netCashReceived,
    required List<ValidatedCashSaleLine> lines,
    this.sourceName,
    this.notes,
    this.cancelReason,
    this.amendCount = 0,
  }) : lines = List<ValidatedCashSaleLine>.unmodifiable(lines);

  /// ★ رقم المستند — **وهو معرّفه في المجموعة** (`CSH-YYYYMMDD-####`).
  final String documentNumber;

  /// المصدر — ★ **ومنه خُصم المخزون** (`FR-M11-02`).
  final String sourceId;

  /// اسم المصدر لحظة الإنشاء.
  final String? sourceName;

  /// ★ **تاريخ المخزون** — 🔒 **يحدده النظام لا المستخدم** (`A-10` · `GR-14`).
  final CalendarDay stockDate;

  /// تاريخ الإدخال — ⚠️ **يختلف عن [stockDate] في التصريف المتأخر** (`E-24`).
  final DateTime entryDate;

  /// الحالة — معتمد أو ملغى.
  final CashSaleStatus status;

  /// ★ إجمالي الحبّات — ⛔ **ولا يُجمع مع [totalWeight]** (`GR-19`).
  final PieceCount totalPieces;

  /// ★ إجمالي الأوزان — ⛔ **ولا يُجمع مع [totalPieces]** (`GR-19`).
  final WeightKg totalWeight;

  /// ★★ **صافي المقبوض نقداً** — `Σ(قيم السطور)` (`design-overview.md` §2.6).
  final Money netCashReceived;

  /// السطور **بأسعارها** — راجع ترويسة الملف.
  final List<ValidatedCashSaleLine> lines;

  /// ملاحظات السند.
  final String? notes;

  /// سبب الإلغاء.
  final String? cancelReason;

  /// عدد التعديلات — ★ **مصدر شارة «مُعدَّل ×N»**.
  final int amendCount;

  /// هل المستند ملغى؟
  bool get isCancelled => status == CashSaleStatus.cancelled;
}

/// دليل البيع النقدي — **قراءةً فقط**.
///
/// ⛔⛔★★★ **واستعلامٌ مقيَّدٌ بالمصدر واليوم دائماً** — ★ **شرطُ القراءة
/// `isSignedIn() && storedInScope()` يعتمد `resource.data.sourceId`**
/// (`firestore.rules` §17)، ⟵ **واستعلامٌ لا يُقيّد `sourceId` يُرفَض كاملاً
/// ولو بنطاقٍ شامل** (`IQ-024` · `WU-008`) — ⛔ **والعلاج تقييدُ الحقل**
/// ★ **والفهرس `sourceId ↑ · stockDate ↓` قائمٌ فعلاً** (`firestore.indexes.json`).
abstract interface class CashSaleDirectory {
  /// ★ **سندات يومٍ واحد لمصدرٍ واحد** — الفهرس `sourceId ↑ · stockDate ↓`.
  Stream<List<CashSaleCard>> watchCashSales({
    required String sourceId,
    required CalendarDay stockDate,
  });
}

/// مستودع كتابة البيع النقدي — **عبر العمليات المستدعاة حصراً**.
///
/// ⛔★★ **ولا كتابة مباشرة واحدة:** `cash_sales` و`inventory_ledger` و
/// `item_daily_balances` **كلها `allow create, update: if false`** —
/// ⟵ **فالواجهة تطلب ولا تكتب**، **والمستندُ والحركةُ والأرصدةُ وقيدُ
/// التدقيق في معاملة سحابية واحدة** (`ADR-0013` القاعدة 1 · `GR-51`).
abstract interface class CashSaleAdminRepository {
  /// ينشئ سنداً ويُرجِع **رقمه** — ★ **والرقم من السحابة** ⛔ **ولا يُولِّده
  /// الجهاز** (`naming-conventions.md` §5).
  ///
  /// ⚙️ **وتاريخ المخزون من الخادم** (`A-10` · `GR-14`) — ⛔ **ولا يُرسَل
  /// أصلاً**، ★ **فما لا يُرسَل لا يُزوَّر.**
  ///
  /// ⛔⛔★★ **ويُرفَض إن كان سعرُ سطرٍ دون الحد الأدنى بلا
  /// `cashSaleBelowMinimum`** برمز `ERR_PRICE_002` (`FR-M11-05` · `GR-34`) —
  /// ★ **والحدّ يُقرأ من `daily_prices` داخل المعاملة** ⛔ **لا من الجهاز.**
  Future<Outcome<String>> createCashSale(ValidatedCashSale sale);

  /// ★ يعدّل سنداً معتمداً — **بصلاحية `cashSaleAmend` وسببٍ نصّي اختياري**
  /// (`FR-M11-13` · `ADR-0020`).
  ///
  /// ⛔ **ولا يُنشئ حركة تصحيحية:** الحركة **تُعدَّل في مكانها** ويُعاد بناء
  /// الرصيد من الدفتر (`A-14` · `AT-57`).
  Future<Outcome<void>> amendCashSale({
    required String documentNumber,
    required ValidatedCashSale sale,
    String? amendReason,
  });

  /// ★ يُلغي سنداً — **بصلاحية `cashSaleCancel` وسببٍ نصّي اختياري**.
  ///
  /// ⛔⛔★★ **ولا حارسَ تسويةٍ هنا بخلاف التوزيعة** (`E-15`) — ★ **لأن البيع
  /// النقدي لا يُنشئ ذمّةً تُسدَّد أصلاً** (`FR-M11-03`): ⟵ **فلا سدادَ
  /// يمنع إلغاءه**، ⛔ **والمانع الوحيد أن يكون ملغى سلفاً** (`ERR_AMEND_006`).
  ///
  /// ⛔ **والحذف مرفوض نهائياً** (`GR-07`) — ⟵ **فلا دالة حذف في هذا العقد.**
  Future<Outcome<void>> cancelCashSale({
    required String documentNumber,
    required String sourceId,
    String? cancelReason,
  });
}

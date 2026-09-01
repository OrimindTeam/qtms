/// عقود مستودعات السحبيات والخرجيات — **قراءةً وكتابةً**.
///
/// ★ **الفصل مقصود ويطابق `ADR-0013`:** القراءة **مباشرة من القاعدة**
/// (القاعدة 4)، **والكتابة عبر دالة سحابية مستدعاة** تكتب السند وحركاته
/// المخزنية وأرصدته **وسطرَ الدفتر الرابع وقيدَ تدقيقه في معاملة واحدة**
/// (القاعدة 1 · `FR-M22-13` · `GR-51`).
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **وعقدٌ واحد للسجلَّين ⛔ لا عقدان** — ★ **و[OutflowLedgerType]
/// وسيطٌ صريحٌ في كل دالة**: ⟵ **فآليتُهما واحدة تماماً والفارقُ في
/// الصلاحية والتصنيف** (`outflow-design.md` §2)، ⛔ **وعقدان متطابقان
/// كانا يفترقان عند أول تعديل** (`coding-standards.md` §2.2).
///
/// ⚠️⚠️ **والفصلُ الأمني لا يقع هنا بل في ثلاثة مواضع تحته:**
///   ① **قاعدةُ الحماية** — `match /outflows/{docId}` **تقرأ
///      `resource.data.ledgerType`** وتشترط `withdrawalView` أو `expenseView`.
///   ② **الدالةُ الكاتبة** — تختار المفتاح من [OutflowLedgerType] المخزَّن.
///   ③ **الشاشة** — `PermissionGate` ⚠️ **إخفاءٌ لا حماية** (`RISK-02`).
/// ═══════════════════════════════════════════════════════════════════════
library;

import '../../../core/calendar_day.dart';
import '../../../core/money.dart';
import '../../../core/outcome.dart';
import '../../inventory/domain/inventory.dart' show StockQuantity;
import 'outflow.dart';

/// سطرُ قاتٍ مخزَّن كما يُقرأ للعرض.
final class OutflowCardQatLine {
  /// ينشئ السطر.
  const OutflowCardQatLine({
    required this.itemKey,
    required this.itemName,
    required this.quantity,
    required this.unitPrice,
    required this.lineValue,
    this.sackId,
  });

  /// مفتاح النوع.
  final String itemKey;

  /// اسم النوع لحظة الإدخال — ★ **نسخةٌ مقصودة**.
  final String itemName;

  /// الكمية بوحدتها — `GR-19`.
  final StockQuantity quantity;

  /// السعر أو `null` — ★ **والعدم يعني «لم يُسعَّر بعد»** (`FR-M22-07`).
  final Money? unitPrice;

  /// قيمة السطر أو `null` — ⛔ **ولا تُقرأ صفراً عند غياب السعر.**
  final Money? lineValue;

  /// الجونية أو `null` — `E-26`.
  final String? sackId;
}

/// سطرُ مبلغٍ مخزَّن كما يُقرأ للعرض.
final class OutflowCardCashLine {
  /// ينشئ السطر.
  const OutflowCardCashLine({
    required this.kind,
    required this.amount,
    this.description,
  });

  /// نوع البند — **مبلغ** أو **أخرى**.
  final OutflowLineKind kind;

  /// المبلغ الخارج.
  final Money amount;

  /// الوصف أو `null`.
  final String? description;
}

/// بطاقة سند السحبية أو الخرجية.
final class OutflowCard {
  /// ينشئ البطاقة.
  OutflowCard({
    required this.documentNumber,
    required this.ledgerType,
    required this.category,
    required this.date,
    required this.stockDate,
    required this.sourceId,
    required this.totalQatValue,
    required this.totalCashValue,
    required this.grandTotal,
    required this.unpricedItemCount,
    required this.isCancelled,
    required List<OutflowCardQatLine> qatLines,
    required List<OutflowCardCashLine> cashLines,
    this.sourceName,
    this.notes,
    this.cancelReason,
    this.amendCount = 0,
  })  : qatLines = List<OutflowCardQatLine>.unmodifiable(qatLines),
        cashLines = List<OutflowCardCashLine>.unmodifiable(cashLines);

  /// رقم المستند — `WDR-…` أو `EXP-…` **وهو معرّفه**.
  final String documentNumber;

  /// ★★★ السجل — ⛔ **وهو ما تقرؤه قاعدةُ الحماية لتختار مفتاح العرض.**
  final OutflowLedgerType ledgerType;

  /// الفئة — `FR-M22-19`.
  final OutflowCategory category;

  /// ★★ **تاريخ السند** — **الأثر المالي** (`FR-M22-10` · `GR-49`).
  final CalendarDay date;

  /// ★★ **تاريخ المخزون** — **الأثر المخزني لبنود القات** (`GR-49`).
  ///
  /// ⚠️⚠️ **وقد يختلف عن [date]** — ★ **وهذا بيتُ القصيد في `FR-M22-10`**:
  /// ⟵ **قاتٌ من متبقٍّ متأخر خرج من مخزون يومه الأصلي بينما وقع المصروف
  /// اليوم**، ⛔ **والخلطُ يُنتج تقريراً مالياً صحيحاً بمخزونٍ خاطئ.**
  final CalendarDay stockDate;

  /// ★★★ المصدر — ⛔ **إلزاميٌّ دائماً** (`GR-42`).
  final String sourceId;

  /// اسم المصدر لحظة الإنشاء — ★ **نسخةٌ مقصودة**.
  final String? sourceName;

  /// سطور القات.
  final List<OutflowCardQatLine> qatLines;

  /// سطور المبالغ.
  final List<OutflowCardCashLine> cashLines;

  /// إجمالي قيمة القات — ⛔ **بلا السطور غير المسعَّرة**.
  final Money totalQatValue;

  /// إجمالي المبالغ.
  final Money totalCashValue;

  /// ★★★ الإجمالي النهائي — `GR-42` · `AT-38`.
  final Money grandTotal;

  /// ★★ عدد بنود القات بلا سعر — ⟵ **مصدرُ شارة «⏳ سعر غير نهائي».**
  final int unpricedItemCount;

  /// بيان السند.
  final String? notes;

  /// ★ ملغى — **بالوسم** ⛔ **بلا حركةٍ عكسية** (`A-14`).
  final bool isCancelled;

  /// سبب الإلغاء — **اختياريٌّ** (`ADR-0020`).
  final String? cancelReason;

  /// عدد التعديلات — ★ **مصدر شارة «مُعدَّل»**.
  final int amendCount;
}

/// دليل السحبيات والخرجيات — **قراءةً فقط**.
abstract interface class OutflowDirectory {
  /// ★ سندات سجلٍّ بعينه في مصدرٍ بعينه — الفهرس
  /// `sourceId ↑ · ledgerType ↑ · documentDate ↓`.
  ///
  /// ⛔⛔★★★ **و[sourceId] و[ledgerType] كلاهما مُقيَّدٌ صراحةً — ⛔ ولا واحدٌ
  /// منهما ضمنيّ:** ★ **شرطُ قراءة `outflows` يقرأ `resource.data.sourceId`
  /// (عبر `storedInScope()`) و`resource.data.ledgerType` معاً** — ⟵ **واستعلامٌ
  /// لا يُقيّدهما يُرفَض كاملاً ولو كان نطاق المستخدم شاملاً ومفاتيحُه كلَّها**
  /// (`IQ-024` · `WU-008` · `DEBT-40`).
  Stream<List<OutflowCard>> watchOutflows({
    required String sourceId,
    required OutflowLedgerType ledgerType,
    int limit,
  });
}

/// مستودع كتابة السحبيات والخرجيات — **عبر العمليات المستدعاة حصراً**.
///
/// ⛔★★ **ولا كتابة مباشرة واحدة:** `outflows` و`outflow_ledger` و
/// `inventory_ledger` و`item_daily_balances` **كلها مغلقةٌ للكتابة** —
/// ⟵ **فالواجهة تطلب ولا تكتب** (`ADR-0013` القاعدة 2).
abstract interface class OutflowAdminRepository {
  /// ينشئ سنداً ويُرجِع **رقمه** — ★ **والرقم من السحابة** ⛔ **ولا يُولِّده
  /// الجهاز** (`naming-conventions.md` §5).
  ///
  /// ⛔⛔★★★ **ولا وسيطَ مقوتٍ في هذا التوقيع إطلاقاً** (`FR-M22-04` ·
  /// `GR-44`) — ★ **غيابٌ بنيويٌّ**: ⟵ **فالشاشة لا تملك ما ترسله أصلاً.**
  Future<Outcome<String>> createOutflow({
    required OutflowLedgerType ledgerType,
    required String sourceId,
    required OutflowCategory category,
    required CalendarDay date,
    List<OutflowQatLineInput> qatLines,
    List<OutflowCashLineInput> cashLines,
    String? notes,
  });

  /// ★ يعدّل سنداً معتمداً — **بصلاحية السجل وسببٍ نصّي اختياري**
  /// (`FR-M22-18` · `ADR-0020`) ⟵ **وتُعاد الأرصدة وسعرُ الجونية احتساباً**.
  Future<Outcome<void>> amendOutflow({
    required String documentNumber,
    required String sourceId,
    required OutflowCategory category,
    List<OutflowQatLineInput> qatLines,
    List<OutflowCashLineInput> cashLines,
    String? notes,
    String? amendReason,
  });

  /// ★ يُلغي سنداً — **بصلاحية السجل** ⟵ **وتُعاد الكميات إلى الرصيد**
  /// ⛔ **بلا حركةٍ عكسية** (`A-14` · `GR-06`).
  ///
  /// ⛔ **والحذف مرفوض نهائياً** (`GR-07`) — ⟵ **فلا دالة حذف في هذا العقد.**
  Future<Outcome<void>> cancelOutflow({
    required String documentNumber,
    required String sourceId,
    String? cancelReason,
  });
}

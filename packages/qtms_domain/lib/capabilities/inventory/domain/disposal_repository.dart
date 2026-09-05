/// عقود مستودع الإتلاف — **قراءةً وكتابةً**.
///
/// ★ **الفصل مقصود ويطابق `ADR-0013`:** القراءة **مباشرة من القاعدة**
/// (القاعدة 4)، **والكتابة عبر دالة سحابية مستدعاة** تكتب المستند وحركاته
/// المخزنية وأرصدته **وقيدَ تدقيقه في معاملة واحدة** (القاعدة 1).
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **ولا حقلَ ماليٍّ في أيِّ نوعٍ هنا** — `FR-M8-16`: ★ **بنفس
/// القاعدة ① في `disposal.dart`**، ⟵ **فبطاقةُ العرض نفسُها بلا مبلغ**
/// ⛔ **ولا شاشةَ تعرض «قيمة المُتلَف»** — ★ **إذ لا قيمة له أصلاً.**
///
/// ⚠️⚠️ **وتاريخُ المخزون وحدَه لا تاريخان** — ⛔ **بخلاف `OutflowCard`:**
/// ★ **`data-dictionary.md` §`disposals` يُعرِّف `stockDate` و`entryDate`
/// وحدهما** ⟵ **ولا `documentDate` لأن لا أثرَ ماليَّ له يقع في يومٍ آخر.**
/// ═══════════════════════════════════════════════════════════════════════
library;

import '../../../core/calendar_day.dart';
import '../../../core/outcome.dart';
import 'disposal.dart';
import 'inventory.dart' show StockQuantity;

/// سطرُ إتلافٍ مخزَّن كما يُقرأ للعرض.
final class DisposalCardLine {
  /// ينشئ السطر.
  const DisposalCardLine({
    required this.itemKey,
    required this.itemName,
    required this.quantity,
    this.sackId,
  });

  /// مفتاح النوع.
  final String itemKey;

  /// اسم النوع لحظة الإدخال — ★ **نسخةٌ مقصودة**.
  final String itemName;

  /// الكمية المُتلَفة بوحدتها — `GR-19`.
  final StockQuantity quantity;

  /// الجونية أو `null`.
  final String? sackId;
}

/// بطاقة مستند الإتلاف.
final class DisposalCard {
  /// ينشئ البطاقة.
  DisposalCard({
    required this.documentNumber,
    required this.stockDate,
    required this.sourceId,
    required this.isCancelled,
    required List<DisposalCardLine> lines,
    this.sourceName,
    this.reason,
    this.cancelReason,
    this.amendCount = 0,
  }) : lines = List<DisposalCardLine>.unmodifiable(lines);

  /// رقم المستند — `DSP-…` **وهو معرّفه**.
  final String documentNumber;

  /// ★★ **تاريخ المخزون** — ★ **وقد يكون سابقاً في تصريف المتبقي المتأخر**
  /// (`FR-M8-11` · `data-dictionary.md` §`disposals`).
  final CalendarDay stockDate;

  /// ★★★ المصدر — ⛔ **إلزاميٌّ** (`ADR-0005`).
  final String sourceId;

  /// اسم المصدر لحظة الإنشاء — ★ **نسخةٌ مقصودة**.
  final String? sourceName;

  /// السطور.
  final List<DisposalCardLine> lines;

  /// السبب — **اختياريٌّ** (`ADR-0020`).
  final String? reason;

  /// ★ ملغى — **بالوسم** ⛔ **بلا حركةٍ عكسية** (`A-14`).
  final bool isCancelled;

  /// سبب الإلغاء — **اختياريٌّ** (`ADR-0020`).
  final String? cancelReason;

  /// عدد التعديلات — ★ **مصدر شارة «مُعدَّل»**.
  final int amendCount;
}

/// دليل الإتلاف — **قراءةً فقط**.
abstract interface class DisposalDirectory {
  /// ★ مستندات الإتلاف في مصدرٍ بعينه — الفهرس `sourceId ↑ · stockDate ↓`.
  ///
  /// ⛔⛔★★★ **و[sourceId] مُقيَّدٌ صراحةً ⛔ لا ضمنيّاً:** ★ **شرطُ قراءة
  /// `disposals` يقرأ `resource.data.sourceId` عبر `storedInScope()`** —
  /// ⟵ **واستعلامٌ لا يُقيّده يُرفَض كاملاً ولو كان نطاق المستخدم شاملاً**
  /// (`IQ-024` · `WU-008` · `DEBT-40` · `WU-016`).
  Stream<List<DisposalCard>> watchDisposals({
    required String sourceId,
    int limit,
  });
}

/// مستودع كتابة الإتلاف — **عبر العمليات المستدعاة حصراً**.
///
/// ⛔★★ **ولا كتابة مباشرة واحدة:** `disposals` و`inventory_ledger` و
/// `item_daily_balances` **كلها مغلقةٌ للكتابة** — ⟵ **فالواجهة تطلب ولا
/// تكتب** (`ADR-0013` القاعدة 2).
abstract interface class DisposalAdminRepository {
  /// ينشئ مستند إتلافٍ ويُرجِع **رقمه** — ★ **والرقم من السحابة** ⛔ **ولا
  /// يُولِّده الجهاز** (`naming-conventions.md` §5).
  ///
  /// ★★ **و[stockDate] اختياريٌّ:** ⟵ **غيابُه يعني «مخزون اليوم»**،
  /// ★ **ووجودُه أقدمَ من اليوم يشترط `agedRemainderClear`** (`FR-M8-11`)
  /// ⛔ **والمستقبليُّ مرفوضٌ للجميع بلا مفتاحٍ يفتحه.**
  Future<Outcome<String>> createDisposal({
    required String sourceId,
    List<DisposalLineInput> lines,
    CalendarDay? stockDate,
    String? reason,
  });

  /// ★ يعدّل مستنداً معتمداً — **بمفتاح «تعديل الإتلاف» وسببٍ نصّي اختياري**
  /// (`ADR-0020`) ⟵ **وتُعاد الأرصدة احتساباً**.
  Future<Outcome<void>> amendDisposal({
    required String documentNumber,
    required String sourceId,
    List<DisposalLineInput> lines,
    String? amendReason,
  });

  /// ★ يُلغي مستنداً — **بمفتاح «إلغاء الإتلاف»** ⟵ **وتُعاد الكميات إلى
  /// الرصيد** ⛔ **بلا حركةٍ عكسية** (`A-14` · `GR-06`).
  ///
  /// ⛔ **والحذف مرفوض نهائياً** (`GR-07`) — ⟵ **فلا دالة حذف في هذا العقد.**
  Future<Outcome<void>> cancelDisposal({
    required String documentNumber,
    required String sourceId,
    String? cancelReason,
  });
}

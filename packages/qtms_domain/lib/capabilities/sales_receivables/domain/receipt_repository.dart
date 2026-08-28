/// عقود مستودعات المقبوضات وحساب المقوت — **قراءةً وكتابةً**.
///
/// ★ **الفصل مقصود ويطابق `ADR-0013`:** القراءة **مباشرة من القاعدة**
/// (القاعدة 4)، **والكتابة عبر دالة سحابية مستدعاة** تكتب السند وحركاته
/// الدائنة وتسويةَ ضماراته وأرصدته **وقيدَ تدقيقه في معاملة واحدة**
/// (القاعدة 1 · `FR-M12-08` · `GR-51`).
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔★★★ **وبطاقتان لا واحدة — وهذا جوهر [`ADR-0017`] في هذه الوحدة:**
///
///   [ReceiptCard]        ← المستند الأب · **يقرؤه كل مصادَق**
///   [ReceiptDepositCard] ← 🔒 `deposit/current` · **بـ`receiptDepositView` وحدها**
///
/// ⟵ **ودمجُهما في نوعٍ واحد بحقولٍ اختيارية كان سيجعل `FR-M12-16` إخفاءَ
/// واجهة لا حماية**: ★ **النوعُ المنفصل يجعل غياب حالة الإيداع حالةً صريحة
/// في الكود** ⛔ **لا حقولاً `null` تُنسى في شاشةٍ ما فتُعرَض.**
/// ═══════════════════════════════════════════════════════════════════════
library;

import '../../../core/calendar_day.dart';
import '../../../core/money.dart';
import '../../../core/outcome.dart';
import 'receipt.dart';

/// سطر سندٍ مخزَّن كما يُقرأ للعرض.
final class ReceiptCardLine {
  /// ينشئ السطر.
  const ReceiptCardLine({
    required this.debtLotId,
    required this.sourceId,
    required this.remainingBefore,
    required this.amount,
    required this.remainingAfter,
    this.note,
  });

  /// الضمار المسدَّد.
  final String debtLotId;

  /// مصدر ذلك الضمار.
  final String sourceId;

  /// ★ المتبقي قبله — **محفوظٌ للعرض التاريخي** (`schema/receipts.md`).
  final Money remainingBefore;

  /// المبلغ الواصل.
  final Money amount;

  /// المتبقي بعده.
  final Money remainingAfter;

  /// بيان السطر.
  final String? note;
}

/// بطاقة سند القبض — **المستند الأب وحده** ⛔ **بلا حالة إيداع**.
///
/// ⛔⛔★★ **ولا حقل إيداعٍ واحد هنا** ([`ADR-0017`]): ★ **القاعدة تمنح
/// المستند كاملاً ولا تُخفي حقلاً داخله** — ⟵ **فأي حقل إيداعٍ في هذا النوع
/// يعني أن كل مصادَق يقرؤه**، ⛔ **و`FR-M12-16` ينصّ أن من لا يملك الصلاحية
/// «لا يرى العمود ولا الفلتر إطلاقاً».**
final class ReceiptCard {
  /// ينشئ البطاقة.
  ReceiptCard({
    required this.documentNumber,
    required this.date,
    required this.dealerId,
    required this.dealerName,
    required this.surplusAmount,
    required this.surplusScope,
    required this.totalDebtAtEntry,
    required this.isCancelled,
    required List<ReceiptCardLine> lines,
    required List<String> affectedSourceIds,
    this.sourceFilter,
    this.usedAutoAllocation = false,
    this.cancelReason,
    this.amendCount = 0,
  })  : lines = List<ReceiptCardLine>.unmodifiable(lines),
        affectedSourceIds = List<String>.unmodifiable(affectedSourceIds);

  /// رقم المستند — `RCP-YYYYMMDD-####` **وهو معرّفه**.
  final String documentNumber;

  /// ★ **تاريخ السند** — ⚠️ **«المقبوض في تاريخ»** ⛔ **لا تاريخ الضمار**
  /// (`GR-41`).
  final CalendarDay date;

  /// المقوت.
  final String dealerId;

  /// اسم المقوت لحظة الإنشاء — ★ **نسخةٌ مقصودة**.
  final String dealerName;

  /// ★ **المصدر المحدد أو `null` لـ«الكل»** — `FR-M12-04`.
  final String? sourceFilter;

  /// ★★ **المصادر التي مسّها السند فعلاً** — ⟵ **وعليها فهرسٌ قائم.**
  final List<String> affectedSourceIds;

  /// السطور.
  final List<ReceiptCardLine> lines;

  /// ★ الفائض المُدخَل في هذا السند.
  final Money surplusAmount;

  /// نطاق ذلك الفائض.
  final SurplusScope surplusScope;

  /// ★ إجمالي الديون لحظة الإدخال — **محفوظٌ للعرض التاريخي** (`FR-M12-03`).
  final Money totalDebtAtEntry;

  /// ★ هل استُخدم التوزيع التلقائي؟ — **للتدقيق وحده**.
  final bool usedAutoAllocation;

  /// ★ ملغى — **بالوسم** ⛔ **بلا حركةٍ عكسية** (`A-14`).
  final bool isCancelled;

  /// سبب الإلغاء — **اختياريٌّ** ([`ADR-0020`]).
  final String? cancelReason;

  /// عدد التعديلات — ★ **مصدر شارة «مُعدَّل»** (`FR-M17`).
  final int amendCount;

  /// ★ إجمالي المقبوض في هذا السند — **السطور والفائض معاً**.
  ///
  /// ⚠️⚠️ **وهو «المقبوض في تاريخ» لا «الواصل»** (`GR-41` · `FR-M12-20`):
  /// ★ **كلُّ ما دخل الصندوق بهذا السند** ⛔ **مهما كانت تواريخ ضماراته.**
  Money get totalReceived {
    Money total = surplusAmount;
    for (final ReceiptCardLine line in lines) {
      total = total + line.amount;
    }
    return total;
  }
}

/// 🔒 بطاقة حالة الإيداع البنكي — [`ADR-0017`] · `FR-M12-15` … `FR-M12-18`.
final class ReceiptDepositCard {
  /// ينشئ البطاقة.
  const ReceiptDepositCard({
    required this.state,
    this.note,
    this.depositedBy,
    this.depositedAt,
  });

  /// الحالة — ★ **تبدأ «لم يُودع»** دائماً.
  final DepositState state;

  /// ★ الملاحظة — **إلزامية عند التغيير** (`GR-38`).
  final String? note;

  /// مَن أكّد الإيداع.
  final String? depositedBy;

  /// متى.
  final DateTime? depositedAt;
}

/// دليل المقبوضات والضمارات المفتوحة — **قراءةً فقط**.
///
/// ★ **تدفّقات لا قراءات مفردة:** قبضٌ من جهازٍ آخر **يظهر فوراً**
/// (`ADR-0010`) — ⟵ **فلا يقبض اثنان من نفس الضمار وهما لا يريان بعضهما**،
/// ⛔ **والمبلغ يتجاوز المتبقي فيُرفَض في السحابة** (`BR-M12-02`).
abstract interface class ReceiptDirectory {
  /// ★★★ **الضمارات المفتوحة للمقوت** — `FR-M12-05`.
  ///
  /// ⚠️⚠️ **والمتبقي يُقرأ من `pricing/current`** (`IQ-027` الخيار أ) —
  /// ⟵ **فمن لا يملك `distributionPriceView` لا يرى مبلغاً أصلاً**،
  /// ★ **وهو المقصود** (`ت-12`): ⛔ **والقبض حينها لا يُعرَض له.**
  ///
  /// ⛔⛔★★★ **و[sourceIds] قائمةٌ صريحة دائماً — ⛔ ولا «كل المصادر» ضمنية:**
  ///
  /// ★ **شرطُ قراءة `distributions` هو `storedInScope()`** وهو **يقرأ
  /// `resource.data.sourceId`** — ⟵ **واستعلامٌ لا يُقيّد `sourceId` يُرفَض
  /// كاملاً ولو كان نطاق المستخدم شاملاً** (`IQ-024` · `WU-008` · `DEBT-40`
  /// — **مقيسٌ ثلاث مرات**). ⛔ **والعلاج تقييدُ الحقل وفهرسٌ ببادئته**
  /// ⛔ **لا تخفيفُ القاعدة.**
  ///
  /// ⟵ ★ **فـ«الكل» في `FR-M12-04` تعني «كل مصادر نطاق المستخدم» مُعدَّدةً**
  /// — **يبنيها المزوّد من الجلسة** ⛔ **ولا تصل الدليلَ غياباً.**
  Stream<List<OpenDebtLot>> watchOpenDebtLots({
    required String dealerId,
    required List<String> sourceIds,
  });

  /// ★ سندات مقوتٍ — الفهرس `dealerId ↑ · date ↓`.
  Stream<List<ReceiptCard>> watchReceipts({
    required String dealerId,
    int limit,
  });

  /// 🔒 **حالة إيداع سندٍ** — ⛔ **ولا تصل إلا لمن يملك `receiptDepositView`**.
  ///
  /// ⚠️ **ويُرجِع `null` عند المنع وعند الغياب معاً** — ★ **والتمييز بينهما
  /// لا يلزم الشاشة**: **كلاهما «لا تعرض عمود الإيداع»** (`FR-M12-16`).
  Stream<ReceiptDepositCard?> watchReceiptDeposit({
    required String documentNumber,
  });

  /// ★★ **رصيد المقوت في مصدرٍ** — ⛅ **مشتقٌّ يُقرأ للعرض** (`ADR-0008`).
  Stream<Money?> watchAvailableSurplus({
    required String dealerId,
    required SurplusScope scope,
    String? sourceId,
  });
}

/// مستودع كتابة المقبوضات — **عبر العمليات المستدعاة حصراً**.
///
/// ⛔★★ **ولا كتابة مباشرة واحدة:** `receipts` و`deposit/current` و
/// `dealer_ledger` و`dealer_balances` و`dealer_surplus` **كلها
/// `allow create, update: if false`** — ⟵ **فالواجهة تطلب ولا تكتب.**
abstract interface class ReceiptAdminRepository {
  /// ينشئ سند قبضٍ ويُرجِع **رقمه** — ★ **والرقم من السحابة** ⛔ **ولا
  /// يُولِّده الجهاز** (`naming-conventions.md` §5).
  ///
  /// ⚠️⚠️ **والتاريخ يُرسَل هنا بخلاف التوزيع** — `FR-M12-02`: **يقبل سابقاً
  /// بصلاحية `receiptBackdate`** ⛔ **ويرفض المستقبلي مطلقاً** (`E-14`)،
  /// ★ **ويُقابَل بيوم المنصّة داخل المعاملة.**
  Future<Outcome<String>> createReceipt({
    required String dealerId,
    required CalendarDay date,
    required List<ReceiptLineInput> lines,
    String? sourceFilter,
    Money surplusAmount,
    SurplusScope surplusScope,
    bool usedAutoAllocation,
  });

  /// ★ يعدّل سنداً معتمداً — **بصلاحية `receiptAmend` وسببٍ نصّي اختياري**
  /// ([`ADR-0020`]) ⟵ **وتُعاد حالة الضمارات احتساباً** (`FR-M12-21`).
  Future<Outcome<void>> amendReceipt({
    required String documentNumber,
    required String dealerId,
    required CalendarDay date,
    required List<ReceiptLineInput> lines,
    String? sourceFilter,
    Money surplusAmount,
    SurplusScope surplusScope,
    String? amendReason,
  });

  /// ★ يُلغي سنداً — **بصلاحية `receiptCancel`** ⟵ **ويردّ المسدَّد إلى
  /// ضماراته** ⛔ **بلا حركةٍ عكسية** (`A-14` · `GR-06`).
  ///
  /// ⛔ **والحذف مرفوض نهائياً** (`GR-07`) — ⟵ **فلا دالة حذف في هذا العقد.**
  Future<Outcome<void>> cancelReceipt({
    required String documentNumber,
    required String dealerId,
    String? cancelReason,
  });

  /// ★★ **يؤكّد الإيداع البنكي أو يتراجع عنه** — **مسارٌ مقيَّد بحقوله**
  /// (`FR-M12-18`) يشترط `receiptDepositConfirm` **و`receiptDepositView`**
  /// ⛔ **وملاحظةً غير فارغة في الاتجاهين** (`AT-36` · `FR-M12-17`).
  Future<Outcome<void>> setReceiptDeposit({
    required String documentNumber,
    required String dealerId,
    required bool isDeposited,
    required String note,
  });
}

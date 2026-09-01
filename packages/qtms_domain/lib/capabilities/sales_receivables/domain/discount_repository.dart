/// عقود مستودعات الخصومات — **قراءةً وكتابةً**.
///
/// ★ **الفصل مقصود ويطابق `ADR-0013`:** القراءة **مباشرة من القاعدة**
/// (القاعدة 4)، **والكتابة عبر دالة سحابية مستدعاة** تكتب السند وحركاته
/// الدائنة وتسويةَ ضماراته وأرصدته **وقيدَ تدقيقه في معاملة واحدة**
/// (القاعدة 1 · `FR-M13-11` · `GR-51`).
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **وبطاقةٌ واحدة لا اثنتان — وهذا فارقُها عن `ReceiptCard`:**
///
///   ⛔ **لا `ReceiptDepositCard` نظيرَ لها** — ★ **لا نقدَ دخل فلا شيءَ
///     يُودَع** (`FR-M13` §2)، ⟵ **فلا مجموعةَ فرعية ولا شرطَ قراءةٍ ثانٍ.**
///   ⛔ **ولا حقلَ فائضٍ فيها** — ★ **`FR-M13-05`**: ⟵ **غيابٌ بنيويٌّ من
///     النوع نفسِه**، ⛔ **لا حقلٌ اختياريٌّ يُترَك `null` فتُظهره شاشةٌ ما.**
/// ═══════════════════════════════════════════════════════════════════════
library;

import '../../../core/calendar_day.dart';
import '../../../core/money.dart';
import '../../../core/outcome.dart';
import 'discount.dart';
import 'receipt.dart' show OpenDebtLot;

/// سطر سند خصمٍ مخزَّن كما يُقرأ للعرض.
final class DiscountCardLine {
  /// ينشئ السطر.
  const DiscountCardLine({
    required this.debtLotId,
    required this.sourceId,
    required this.remainingBefore,
    required this.amount,
    required this.remainingAfter,
    this.note,
  });

  /// الضمار المخصوم منه.
  final String debtLotId;

  /// مصدر ذلك الضمار.
  final String sourceId;

  /// ★ المتبقي قبله — **محفوظٌ للعرض التاريخي** (`schema/discounts.md`).
  final Money remainingBefore;

  /// ★ **مبلغ الخصم** — ⛔ **لا «المبلغ الواصل»** (`FR-M15-06-أ`).
  final Money amount;

  /// المتبقي بعده.
  final Money remainingAfter;

  /// بيان السطر.
  final String? note;
}

/// بطاقة سند الخصم.
final class DiscountCard {
  /// ينشئ البطاقة.
  DiscountCard({
    required this.documentNumber,
    required this.date,
    required this.dealerId,
    required this.dealerName,
    required this.totalDebtAtEntry,
    required this.isCancelled,
    required List<DiscountCardLine> lines,
    required List<String> affectedSourceIds,
    this.sourceFilter,
    this.usedAutoAllocation = false,
    this.cancelReason,
    this.amendCount = 0,
  })  : lines = List<DiscountCardLine>.unmodifiable(lines),
        affectedSourceIds = List<String>.unmodifiable(affectedSourceIds);

  /// رقم المستند — `DSC-YYYYMMDD-####` **وهو معرّفه**.
  final String documentNumber;

  /// ★ **تاريخ السند** — `FR-M13-06`.
  final CalendarDay date;

  /// المقوت.
  final String dealerId;

  /// اسم المقوت لحظة الإنشاء — ★ **نسخةٌ مقصودة**.
  final String dealerName;

  /// ★ **المصدر المحدد أو `null` لـ«الكل»** — `FR-M13-01`.
  final String? sourceFilter;

  /// ★★ **المصادر التي مسّها السند فعلاً** — ⟵ **وعليها فهرسٌ قائم.**
  final List<String> affectedSourceIds;

  /// السطور.
  final List<DiscountCardLine> lines;

  /// ★ إجمالي الديون لحظة الإدخال — **محفوظٌ للعرض التاريخي** (`FR-M13-01`).
  final Money totalDebtAtEntry;

  /// ★ هل استُخدم التوزيع التلقائي؟ — **للتدقيق وحده**.
  final bool usedAutoAllocation;

  /// ★ ملغى — **بالوسم** ⛔ **بلا حركةٍ عكسية** (`A-14`).
  final bool isCancelled;

  /// سبب الإلغاء — **اختياريٌّ** ([`ADR-0020`]).
  final String? cancelReason;

  /// عدد التعديلات — ★ **مصدر شارة «مُعدَّل»** (`FR-M17`).
  final int amendCount;

  /// ★★ **إجمالي المخصوم في هذا السند**.
  ///
  /// ⛔⛔★★★ **وهو ليس «مقبوضاً» ولا يدخل الصندوق** (`FR-M15-06-أ` ·
  /// `schema/discounts.md` القاعدة 4) — ★ **يُعرَض في حركة النقد للعلم**
  /// ⛔ **ولا يُطرَح**: ⟵ **لم يدخل نقدٌ أصلاً.**
  Money get totalDiscounted {
    Money total = Money.zero;
    for (final DiscountCardLine line in lines) {
      total = total + line.amount;
    }
    return total;
  }
}

/// دليل الخصومات والضمارات المفتوحة — **قراءةً فقط**.
abstract interface class DiscountDirectory {
  /// ★★★ **الضمارات المفتوحة للمقوت** — `FR-M13-02`.
  ///
  /// ⛔⛔★★★ **و[sourceIds] قائمةٌ صريحة دائماً — ⛔ ولا «كل المصادر» ضمنية:**
  /// ★ **شرطُ قراءة `distributions` هو `storedInScope()`** وهو **يقرأ
  /// `resource.data.sourceId`** — ⟵ **واستعلامٌ لا يُقيّد `sourceId` يُرفَض
  /// كاملاً ولو كان نطاق المستخدم شاملاً** (`IQ-024` · `WU-008` · `DEBT-40`).
  Stream<List<OpenDebtLot>> watchOpenDebtLots({
    required String dealerId,
    required List<String> sourceIds,
  });

  /// ★ سندات خصمٍ لمقوت — الفهرس `dealerId ↑ · date ↓`.
  Stream<List<DiscountCard>> watchDiscounts({
    required String dealerId,
    int limit,
  });
}

/// مستودع كتابة الخصومات — **عبر العمليات المستدعاة حصراً**.
///
/// ⛔★★ **ولا كتابة مباشرة واحدة:** `discounts` و`dealer_ledger` و
/// `dealer_balances` **كلها `allow create, update: if false`** —
/// ⟵ **فالواجهة تطلب ولا تكتب.**
abstract interface class DiscountAdminRepository {
  /// ينشئ سند خصمٍ ويُرجِع **رقمه** — ★ **والرقم من السحابة** ⛔ **ولا
  /// يُولِّده الجهاز** (`naming-conventions.md` §5).
  ///
  /// ⛔⛔★★★ **ولا وسيطَ فائضٍ في هذا التوقيع إطلاقاً** (`FR-M13-05`) —
  /// ★ **غيابٌ بنيويٌّ**: ⟵ **فالشاشة لا تملك ما ترسله أصلاً.**
  Future<Outcome<String>> createDiscount({
    required String dealerId,
    required CalendarDay date,
    required List<DiscountLineInput> lines,
    String? sourceFilter,
    bool usedAutoAllocation,
  });

  /// ★ يعدّل سنداً معتمداً — **بصلاحية `discountAmend` وسببٍ نصّي اختياري**
  /// ([`ADR-0020`]) ⟵ **وتُعاد حالة الضمارات احتساباً** (`FR-M13-10`).
  Future<Outcome<void>> amendDiscount({
    required String documentNumber,
    required String dealerId,
    required CalendarDay date,
    required List<DiscountLineInput> lines,
    String? sourceFilter,
    String? amendReason,
  });

  /// ★ يُلغي سنداً — **بصلاحية `discountCancel`** ⟵ **ويردّ المخصوم إلى
  /// ضماراته** ⛔ **بلا حركةٍ عكسية** (`A-14` · `GR-06`).
  ///
  /// ⛔ **والحذف مرفوض نهائياً** (`GR-07`) — ⟵ **فلا دالة حذف في هذا العقد.**
  Future<Outcome<void>> cancelDiscount({
    required String documentNumber,
    required String dealerId,
    String? cancelReason,
  });
}

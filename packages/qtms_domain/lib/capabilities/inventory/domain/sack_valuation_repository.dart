/// عقود قراءة مالية الجواني وحساب الرعوي (`M14`) — **قراءةً فقط**.
///
/// ⛔★★ **ولا دالة كتابة واحدة في هذا الملف** — ★ **دفتر الرعية ورصيدُه
/// يكتبهما المُحتسِب السحابي حصراً** (`schema/supplier-ledger.md` القاعدة 5 ·
/// `firestore.rules`: `allow write: if false` على المجموعتين معاً):
/// ⟵ **فلا مستودعَ كتابةٍ هنا أصلاً** ⛔ **ولا عمليةَ تسديدٍ للرعوي في هذا
/// الإصدار** (`FR-M14-13` — **مؤجَّلة صراحةً للمرحلة الرابعة**).
///
/// ★★★ **وثلاثة تدفّقات/قراءات لا واحد — وهو نصّ `ADR-0011` مُطبَّقاً:**
/// شرطُ قراءة الجونية (`sackView`) **غيرُ** شرط قراءة ماليتها
/// (`sackFinanceView`) **غيرُ** شرط قراءة حساب الرعوي (`supplierFinanceView`).
/// ⟵ ★ **فدمجُها في عقدٍ واحد كان يُسقِط الشاشة كلَّها لمن يملك بعضَها.**
library;

import '../../../core/calendar_day.dart';
import '../../../core/money.dart';
import '../../../core/outcome.dart';
import 'sack_valuation.dart';

/// 🔒 سطرُ جونيةٍ في دفتر حسابات الرعية — `supplier_ledger/{sackId}`.
///
/// ⚠️ **ومحكومٌ كلُّه بـ`supplierFinanceView`** (`schema/supplier-ledger.md`).
final class SupplierLedgerRow {
  /// ينشئ السطر.
  const SupplierLedgerRow({
    required this.sackId,
    required this.supplierId,
    required this.sourceId,
    required this.sackRevenue,
    required this.recalcVersion,
    this.supplierName,
    this.sackDisplayName,
    this.sackTax,
    this.supplierNet,
    this.isRevenueFinal = true,
    this.isCancelled = false,
  });

  /// رقم الجونية — ★ **وهو معرّف السطر نفسُه** ([supplierLedgerEntryId]).
  final String sackId;

  /// الرعوي.
  final String supplierId;

  /// ★ المصدر — **إلزامي: لكل رعوي حساب في كل مصدر** (`A-11`).
  final String sourceId;

  /// سعر الجونية المحتسَب.
  final Money sackRevenue;

  /// ★★ **رقم إعادة الاحتساب المتزايد** — ⛔ **لأن الصافي رقم حيّ**.
  final int recalcVersion;

  /// اسم الرعوي كما كان لحظة الاحتساب.
  final String? supplierName;

  /// الاسم الظاهر للجونية.
  final String? sackDisplayName;

  /// 🔵 ضريبتها أو `null` **إن كانت معلّقة** (`FR-M7-10`).
  final Money? sackTax;

  /// ★ الصافي أو `null` **إن كانت الضريبة معلّقة** — ⛔ **ولا يُكتب صفراً**.
  final Money? supplierNet;

  /// ★ هل سعرها نهائي؟ — مصدر وسم «⏳ سعر غير نهائي» (`FR-M14-06`).
  final bool isRevenueFinal;

  /// ★ هل الجونية ملغاة؟ — ⛔ **والملغاة لا تدخل أي جمع** (`A-14`).
  final bool isCancelled;

  /// ★ السطر كما تقرؤه معادلة §2.5.
  SupplierSackRow get asTotalsRow => SupplierSackRow(
        sackId: sackId,
        sackRevenue: sackRevenue,
        sackTax: sackTax,
        isRevenueFinal: isRevenueFinal,
      );
}

/// ⛅ رصيد الرعوي في مصدر — `supplier_balances/{supplierId}_{sourceId}`.
///
/// ⚠️⚠️ **ملخّصٌ مشتقّ يُقرأ للعرض** (`ADR-0008`) — ⛔ **ولا يُبنى عليه قرارُ
/// كتابة**: ★ **مصدرُ الحقيقة دفترُ الرعية نفسُه.**
final class SupplierBalanceCard {
  /// ينشئ البطاقة.
  const SupplierBalanceCard({
    required this.supplierId,
    required this.sourceId,
    required this.totals,
  });

  /// الرعوي.
  final String supplierId;

  /// ★ المصدر — ⛔ **ولا حساب موحّد عبر المصادر** (`GR-21` · `ADR-0005`).
  final String sourceId;

  /// الإجماليات الثلاثة كما بُنيت من الدفتر.
  final SupplierSourceTotals totals;
}

/// دليل مالية الجواني وحساب الرعوي — **قراءةً فقط**.
abstract interface class SackValuationDirectory {
  /// 🔒 **حساب الرعوي في مصدر** — يشترط `supplierFinanceView`.
  ///
  /// ★ **تدفّقٌ لا قراءة مفردة:** توزيعةٌ من جهازٍ آخر تُغيّر الصافي
  /// **فيظهر فوراً** (`ADR-0010` · `FR-M14-05`).
  Stream<SupplierBalanceCard?> watchSupplierBalance({
    required String supplierId,
    required String sourceId,
  });

  /// 🔒 **سطور دفتر الرعية لجواني رعويٍّ في مصدر** — يشترط
  /// `supplierFinanceView`.
  ///
  /// ⛔⛔★★ **ويُقيِّد `sourceId` صراحةً في الاستعلام** — ★ **شرطُ القراءة
  /// يعتمد `resource.data`** (`IQ-024` · `WU-008` · `DEBT-40`): ⟵ **والشرط
  /// يُقيَّم على قيود الاستعلام لا على كل مستند**، ⛔ **فاستعلامٌ لا يُقيّده
  /// يُرفَض كاملاً ولو بنطاقٍ شامل.**
  Stream<List<SupplierLedgerRow>> watchSupplierLedger({
    required String supplierId,
    required String sourceId,
  });

  /// ★★★ **تفكيك سعر جونية** — كلُّ الحركات المكوِّنة له (`FR-M14-15`).
  ///
  /// ⚠️⚠️ **وقراءةٌ عند الطلب لا تدفّقٌ دائم** — ★ **التفكيك تفصيلٌ يُفتَح
  /// لجونيةٍ واحدة** (`ui-guidelines.md` §3 نمط 3): ⟵ **وتدفّقٌ دائم لكل
  /// جونيةٍ في الشاشة كان يفتح ثلاثة اشتراكات لكل صفّ** ⛔ **بلا أن يُنظَر
  /// إليها.**
  ///
  /// ★ **و[stockDate] مُدخَلٌ إلزامي لأن حركاتِ الجونية كلَّها عليه**
  /// (`GR-49` · `AT-53`: **التصريف المتأخر يُسجَّل على تاريخ مخزون بضاعته**)
  /// — ⟵ **فهو ما يجعل القراءة مُقيَّدةً بفهرسٍ قائم** ⛔ **لا مسحاً كاملاً.**
  Future<Outcome<List<SackRevenueContribution>>> loadSackContributions({
    required String sackId,
    required String sourceId,
    required CalendarDay stockDate,
  });
}

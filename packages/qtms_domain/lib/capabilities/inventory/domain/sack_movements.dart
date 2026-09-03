/// حركاتُ الجونية الخارجة **كما تُقرأ من مستنداتها** — مُطبَّعةً في شكلٍ واحد.
///
/// ★ **المصدر:** `sack-valuation-design.md` §2 الخطوتان ① و③ ·
/// `FR-M14-02` · `schema/distributions.md` · `schema/cash-sales.md` ·
/// `schema/outflow-ledger.md`.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **ولماذا شكلٌ واحدٌ مُطبَّع لا ثلاثةُ أشكالٍ في ثلاثة قرّاء:**
/// ★ **الثلاثة تُخزَّن مختلفةً فعلاً** — **أسعارُ التوزيعة في `pricing/current`
/// المعزول** (`ADR-0011`) · **وسعرُ البيع النقدي في السطر نفسِه**
/// (`schema/cash-sales.md` نصّاً: «⛔ **ولا مستندَ أسعارٍ فرعي هنا**») ·
/// **وقيمةُ بند القات في سطر السند** (`FR-M22-07`).
/// ⟵ ★ **والتطبيعُ في القارئ، والمعادلةُ بعده واحدة** — ⛔ **فلا ثلاثُ نسخٍ
/// من «ما يدخل سعر الجونية» تفترق عند أول تعديل** (`coding-standards.md` §2.2).
///
/// ★★ **ويشاركه التطبيق والسحابة معاً** (`ADR-0012`) — ⟵ **فرقمُ الشاشة هو
/// رقمُ السحابة حرفياً**، ⛔ **ولا تفكيكٌ يخالف الإجمالي المخزَّن.**
/// ═══════════════════════════════════════════════════════════════════════
library;

import '../../../core/money.dart';
import 'inventory.dart' show StockQuantity;
import 'sack_valuation.dart';

/// ★ سطرٌ واحدٌ في مستندِ صرف — **بقيمته المسجَّلة فيه**.
///
/// ⛔★★ **و[lineValue] يُقرأ ولا يُشتقّ** — راجع [SackRevenueContribution.lineValue]:
/// ⟵ **السطرُ الوزنيُّ مرَّ بالتقريب لحظةَ حفظِ مستنده** (`ADR-0019`).
final class SackMovementLine {
  /// ينشئ السطر.
  const SackMovementLine({
    required this.itemKey,
    required this.itemName,
    required this.quantity,
    this.sackId,
    this.unitPrice,
    this.lineValue,
  });

  /// مفتاح النوع — **النوع المجرَّد أو الاسم المركّب** (`ADR-0007`).
  final String itemKey;

  /// اسم النوع كما يُعرَض.
  final String itemName;

  /// الكمية بوحدتها.
  final StockQuantity quantity;

  /// ★★★ **مرجع الجونية** — ⛔ **و`null` تعني «ليس من جونية»**.
  ///
  /// ⚠️⚠️ **وتكتبه السحابةُ مشتقّاً من حركة الدخول** ([`DEBT-86`]) —
  /// ⛔ **ولا يُصدَّق من حمولة الجهاز**: ⟵ **وغيابُه يُسقِط الجونيةَ من
  /// إيرادها بصمت.**
  final String? sackId;

  /// 🔵 سعر الوحدة المسجَّل أو `null`.
  final Money? unitPrice;

  /// ★ قيمة السطر المسجَّلة أو `null` — ⛔ **والغياب ليس صفراً**.
  final Money? lineValue;
}

/// ★ مستندُ صرفٍ واحد **مُطبَّعاً** — توزيعةٌ أو بيعٌ نقدي أو سندُ سحبية/خرجية.
final class SackMovementDocument {
  /// ينشئ المستند.
  const SackMovementDocument({
    required this.documentNumber,
    required this.origin,
    required this.lines,
    this.isCancelled = false,
    this.isExcluded = false,
    this.counterpartyName,
  });

  /// رقمه — `DST-…` · `CSH-…` · `WDR-…` · `EXP-…`.
  final String documentNumber;

  /// نوعه.
  final SackRevenueSource origin;

  /// سطوره.
  final List<SackMovementLine> lines;

  /// ★ **الملغى لا يدخل أي جمع** (`A-14` · `GR-06`).
  final bool isCancelled;

  /// ⛔⛔★★★ **مستبعَدٌ بطبيعته: إتلافٌ أو تسويةُ جرد** (`FR-M14-08` ·
  /// `FR-M14-10` · `AT-54` · `AT-66`).
  ///
  /// ⚠️⚠️ **ولا كاتبَ له اليوم — والحارس مبنيٌّ قبل كاتبه عمداً:** ★ **الإتلاف
  /// (`WU-020`) والجرد (`WU-022`) لم يُبنيا بعد**، ⟵ **وهما بالضبط الكاتبان
  /// اللذان سيمرّان من هنا.** ⛔ **وبناؤه معهما كان يعني أن يتذكّر كاتبٌ
  /// جديدٌ قاعدةً كُتبت في وحدةٍ أخرى** — ★ **وهو حرفياً عطلُ `sourceDocType`
  /// المحفور** (2026-08-26): **«لا يُفترَض ثابتٌ لأن كاتبه اليوم واحد».**
  final bool isExcluded;

  /// الجهة المقابلة — **المقوت أو وصفُ الخرجية** (`FR-M14-15`).
  final String? counterpartyName;
}

/// ★★★ **مساهماتُ جونيةٍ بعينها** — الخطوة ① من `sack-valuation-design.md` §2.
///
/// ```text
/// ① تُجمع كل حركات الخروج المرتبطة بمعرّف تلك الجونية
/// ② تُستبعَد: الحركات الملغاة · الإتلاف · تسويات الجرد
/// ③ لكل حركة باقية يُقرأ سعرها الفعلي المسجَّل في مستندها
/// ```
///
/// ⛔⛔★★ **والانتماءُ بـ`sackId` وحده** — ⛔ **لا باسم النوع ولا بتاريخه:**
/// ⟵ **فنوعان بالاسم نفسِه من جونيتين مختلفتين لهما مفتاحان مركّبان
/// مختلفان** (`ADR-0007`)، ★ **والمرجعُ الصريح هو ما لا يلتبس.**
///
/// ★ **والملغى والمستبعَد يمرّان مَوسومَين لا مطروحَين** — ⟵ **فالتفكيك
/// يعرضهما مشطوبَين** (`FR-M14-15`)، ⛔ **و[computeSackRevenue] وحدَها من
/// يُسقِطهما من الجمع**: ★ **قرارُ الاستبعاد في موضعٍ واحد لا اثنين.**
List<SackRevenueContribution> contributionsForSack({
  required String sackId,
  required Iterable<SackMovementDocument> documents,
}) {
  final List<SackRevenueContribution> found = <SackRevenueContribution>[];
  for (final SackMovementDocument document in documents) {
    for (final SackMovementLine line in document.lines) {
      if (line.sackId != sackId) continue;
      found.add(
        SackRevenueContribution(
          itemKey: line.itemKey,
          itemName: line.itemName,
          origin: document.origin,
          documentNumber: document.documentNumber,
          quantity: line.quantity,
          unitPrice: line.unitPrice,
          lineValue: line.lineValue,
          counterpartyName: document.counterpartyName,
          isCancelled: document.isCancelled,
          isExcluded: document.isExcluded,
        ),
      );
    }
  }
  return found;
}

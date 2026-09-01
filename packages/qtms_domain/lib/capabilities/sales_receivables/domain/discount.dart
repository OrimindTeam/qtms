/// ═══════════════════════════════════════════════════════════════════════
/// **الخصومات** — `M13` · `FR-M13` · `settlement-design.md` §7.
///
/// ★★★ **وقاعدةٌ واحدة تحكم هذا الملف كلَّه**، وكلُّ ما تحته تفريعٌ عليها:
///
/// ⛔⛔★★★ **الخصمُ إسقاطُ دَينٍ بلا نقد** (`FR-M13-01` · `schema/discounts.md`
///   القاعدة 1) — ★ **فهو مطابقٌ للقبض في آليته**، ⛔ **ومختلفٌ عنه في أثره:**
///   ⟵ **حركةٌ دائنة تُنقِص الضمار** ⛔ **بلا أن يدخل الصندوق ريالٌ واحد.**
///
/// ⛔⛔★★★ **ولا فائضَ في الخصومات إطلاقاً** (`FR-M13-05` · `BR-M13-03`) —
/// ★ **والحقلُ غيرُ موجودٍ في هذا الملف أصلاً**، ⛔ **لا مُصفَّرٌ ولا مُتجاهَل:**
/// ⟵ **فغيابُه بنيويٌّ لا فحصٌ يُنسى** — ★ **والعمليةُ السحابية ترفضه صراحةً
/// لو أُرسل من خارج التطبيق** (`ERR_DIST_009`).
///
/// ⛔⛔★★★ **والخصمُ يُدخَل كخصم ولا يُدخَل إطلاقاً كمبلغٍ واصل**
/// (`FR-M15-06-أ` · `schema/discounts.md`) — ★ **مساران منفصلان بصلاحيتين
/// منفصلتين ومجموعتين منفصلتين**: ⟵ **لأن ما دفعه المقوت نقداً وما أسقطه
/// المالك عنه رقمان مختلفان**، ⛔ **وخلطُهما يُظهر المقوتَ وكأنه سدّد مالاً
/// لم يدفعه** فيُفسِد سجلَّ التزامه ويُفقِد المالكَ معرفةَ كم أسقط فعلاً.
///
/// ⚠️⚠️ **ولا معادلةَ جديدة هنا** (`ADR-0009` · `coding-standards.md` §2.2):
/// ★ **كلُّ دالةٍ أدناه تُفوِّض إلى نظيرتها في `receipt.dart` أو
/// `distribution.dart`** — ⟵ **فالمنطقُ واحدٌ في موضعٍ واحد**، ⛔ **ونسخةٌ
/// ثانيةٌ منه كانت ستفترق عن أصلها عند أول تصحيح.**
/// ═══════════════════════════════════════════════════════════════════════
library;

import '../../../core/calendar_day.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/money.dart';
import '../../../core/outcome.dart';
import 'distribution.dart';
import 'receipt.dart';

// ═════════════════════════════════════════════════════════════════════════
// أسماء المجموعات — `data-dictionary.md` · `naming-conventions.md` §4
// ═════════════════════════════════════════════════════════════════════════

/// سندات الخصم — `schema/discounts.md`.
///
/// ⛔⛔★★ **ومجموعةٌ منفصلة عن [receiptsCollection]** — `schema/discounts.md`:
/// «**الخصم يُكتب في هذه المجموعة حصراً ⛔ ولا يُكتب كسند قبض إطلاقاً**».
const String discountsCollection = 'discounts';

// ═════════════════════════════════════════════════════════════════════════
// المفاتيح المركّبة — `naming-conventions.md` §4 (**ترتيبها ملزم**)
// ═════════════════════════════════════════════════════════════════════════

/// ★ معرّف الحركة الدائنة لسطر خصم — `{documentNumber}_{debtLotId}`.
///
/// ★★ **ومعرّفٌ مشتقٌّ لا عشوائي** — نفس علّة [receiptLedgerEntryId] حرفياً:
/// **التعديل يقع على الحركة نفسها** ⛔ **ولا يُنشئ حركة عكسية** (`A-14` ·
/// `FR-M13-10`)، ⟵ **وإعادةُ الإرسال تكتب فوقها** ⛔ **لا حركةً ثانيةً
/// بنفس المبلغ** — وهي في دفتر ذمم **إسقاطُ دَينٍ صامت مرتين.**
///
/// ⚠️⚠️ **ولا تصادمَ مع [receiptLedgerEntryId] رغم تطابق الصيغة** — ★ **لأن
/// [documentNumber] يحمل بادئته**: `RCP-` **مقابل** `DSC-` (`document_number.dart`
/// — `DocumentKind`)، ⟵ **فالمعرّفان لا يلتقيان أبداً** ⛔ **ولا يكتب أحدهما
/// فوق الآخر في `dealer_ledger`.**
String discountLedgerEntryId({
  required String documentNumber,
  required String debtLotId,
}) =>
    receiptLedgerEntryId(
      documentNumber: documentNumber,
      debtLotId: debtLotId,
    );

// ═════════════════════════════════════════════════════════════════════════
// الأنواع — `FR-M13` §3
// ═════════════════════════════════════════════════════════════════════════

/// سطر خصم كما يصل من الواجهة — **قبل أي تحقق**.
final class DiscountLineInput {
  /// ينشئ المدخلات.
  const DiscountLineInput({
    required this.debtLotId,
    required this.amount,
    this.note,
  });

  /// الضمار المستهدَف.
  final String debtLotId;

  /// ★ **مبلغ الخصم** — `FR-M13-02` ⛔ **لا «المبلغ الواصل»**.
  final Money amount;

  /// بيان السطر — اختياري.
  final String? note;
}

/// سطر خصم مُتحقَّق منه — **بالمتبقي قبله وبعده محسوبَين**.
final class ValidatedDiscountLine {
  /// ينشئ السطر.
  const ValidatedDiscountLine({
    required this.debtLotId,
    required this.sourceId,
    required this.remainingBefore,
    required this.amount,
    required this.remainingAfter,
    required this.note,
  });

  /// الضمار المخصوم منه.
  final String debtLotId;

  /// ★ **مصدر ذلك الضمار** — ⛔ **مقروءٌ منه لا مُدخَل** (`E-35`).
  ///
  /// ⚠️⚠️ **وهو ما يجعل الحركة الدائنة تقع في مصدرها الصحيح** (`FR-M13-03`)
  /// — ⟵ **ومصدرٌ مُدخَلٌ من الواجهة كان يسمح بإسقاط دَينٍ في مصدرٍ لا ضمار
  /// له فيه.**
  final String sourceId;

  /// المتبقي على الضمار **قبل** هذا السطر.
  final Money remainingBefore;

  /// مبلغ الخصم.
  final Money amount;

  /// المتبقي **بعده** — `remainingBefore − amount`.
  final Money remainingAfter;

  /// بيان السطر.
  final String? note;
}

/// ★★ **اقتراح التوزيع التلقائي للخصم** — ⛔ **اقتراحٌ لا قرار** (`FR-M13-07`).
///
/// ⛔⛔★★ **ولا حقلَ فائضٍ فيه** — ★ **بخلاف [AutoAllocationProposal]**:
/// ⟵ **وما يزيد عن مجموع الديون [unallocated] «غيرُ موزَّع»** ⛔ **لا «فائض»**،
/// ★ **والفرق ليس تسمية:** **الفائض رصيدٌ يُحفَظ ويُسدَّد منه لاحقاً**
/// (`FR-M12-11`)، ⛔ **وهذا لا يُحفَظ إطلاقاً** — ⟵ **بل يُعرَض تنبيهاً بأن
/// المبلغ يتجاوز ما على المقوت**، ★ **فيُصحِّحه المستخدم قبل الحفظ.**
final class DiscountAllocationProposal {
  /// ينشئ الاقتراح.
  const DiscountAllocationProposal({
    required this.lines,
    required this.unallocated,
  });

  /// السطور المقترَحة **بترتيب الأقدم أولاً**.
  final List<DiscountLineInput> lines;

  /// ★★ **ما تعذّر توزيعه** — ⛔ **ولا يُحفَظ في أي مستند**.
  final Money unallocated;
}

// ═════════════════════════════════════════════════════════════════════════
// ★★★ المعادلات — **كلُّها تفويضٌ** (`ADR-0009` · `coding-standards.md` §2.2)
// ═════════════════════════════════════════════════════════════════════════

/// ★★★ **التوزيع التلقائي للخصم — بالأقدم أولاً** (`FR-M13-07` · `BR-M13-05`).
///
/// ```text
/// يُرتَّب المفتوح بالأقدم أولاً (stockDate) ثم يُخصَم من كلٍّ بالكامل
/// حتى ينفد المبلغ — والأخير قد يُخصَم منه جزئياً — وما يزيد غيرُ موزَّع.
/// ```
///
/// ⛔⛔★★★ **ولا تكتب هذه الدالة شيئاً** — نصّ `FR-M13-07` **حرفياً**:
/// «**بنفس منطق المقبوضات مع عرض النتيجة للمراجعة قبل الحفظ**»،
/// ⟵ **فهي تُرجِع [DiscountAllocationProposal]** ⛔ **لا سطوراً مُثبَتة.**
///
/// ★★ **وخوارزميتُها [allocateReceiptAutomatically] نفسُها بلا نسخة ثانية** —
/// ⟵ **فتصحيحٌ في الترتيب أو في «الأقدم أولاً» يسري على المسارين معاً**،
/// ⛔ **ولا يُصلَح أحدهما ويُنسى الآخر.**
DiscountAllocationProposal allocateDiscountAutomatically({
  required Money amount,
  required Iterable<OpenDebtLot> openLots,
}) {
  final AutoAllocationProposal proposal = allocateReceiptAutomatically(
    amount: amount,
    openLots: openLots,
  );
  return DiscountAllocationProposal(
    lines: <DiscountLineInput>[
      for (final ReceiptLineInput line in proposal.lines)
        DiscountLineInput(debtLotId: line.debtLotId, amount: line.amount),
    ],
    // ★ **ما فاض عن الديون «غيرُ موزَّع»** — ⛔ **لا فائضٌ يُحفَظ**.
    unallocated: proposal.surplus,
  );
}

/// ★★ **تسويةٌ جديدة بعد خصم** — `settlement-design.md` §3.
///
/// ```text
/// المتبقي على الضمار = قيمة الضمار − المسدَّد − المخصوم
/// ```
///
/// ⛔⛔★★ **والخصمُ يُضاف إلى [DebtSettlement.discountedAmount] وحدَه** —
/// ⛔ **لا إلى [DebtSettlement.settledAmount]**: ⟵ **وهذا هو `ت-04` بنيوياً**
/// (`FR-M13-08` · `GR-40`)، ★ **فبطاقةُ ضمار المالك تقرأ الرقمين منفصلين**
/// ⛔ **وجمعُهما في حقلٍ واحد كان يجعل «الواصل» يبتلع الخصم فيستحيل بعدها
/// معرفةُ كم أسقط المالك فعلاً** — ★ **وهو نصُّ `OQ-001` المحسوم.**
///
/// ⛔ **ولا نسخة ثانية من المعادلة** — ★ **تُستدعى [computeDebtSettlement]
/// نفسُها** (`ADR-0009`)، **حرفياً كـ[settlementAfterReceipt].**
DebtSettlement settlementAfterDiscount({
  required DebtSettlement current,
  required Money discounted,
}) =>
    computeDebtSettlement(
      debtValue: current.debtValue,
      settledAmount: current.settledAmount,
      discountedAmount: current.discountedAmount + discounted,
    );

// ═════════════════════════════════════════════════════════════════════════
// التحقق — `error-handling-strategy.md` §3 (**تُرجَع نتيجةً لا تُرمى**)
// ═════════════════════════════════════════════════════════════════════════

/// ★★★ **تاريخ سند الخصم** — `FR-M13-06` · `BR-M13-04` · `A-10`.
///
/// ```text
/// مستقبلي            ⟵ مرفوض دائماً بلا استثناء ولأي مستخدم
/// سابق بلا صلاحية    ⟵ مرفوض
/// سابق بصلاحية       ⟵ مقبول
/// اليوم              ⟵ مقبول
/// ```
///
/// ⛔⛔★★ **والمستقبلي مرفوضٌ للمالك نفسِه** — ★ **والفحص يسبق فحص الصلاحية
/// عمداً** ⛔ **فلا يُعطي مالكٌ لنفسه تاريخاً مستقبلياً بحُجّة أنه يملك كل
/// المفاتيح** (`AT-56`).
///
/// ★★ **ومنطقُه [validateReceiptDate] نفسُه** — ⛔ **بلا نسخة ثانية**:
/// ⟵ **ورمزُ القاعدة وحده يُعاد وسمُه** (`BR-M13-04` بدل `BR-M12-03`)،
/// ★ **فرسالةُ الخطأ تُنسَب لقاعدتها الصحيحة في المتطلب.**
Outcome<void> validateDiscountDate({
  required CalendarDay date,
  required CalendarDay today,
  required bool canBackdate,
}) {
  final Outcome<void> result = validateReceiptDate(
    date: date,
    today: today,
    canBackdate: canBackdate,
  );
  return switch (result) {
    // ★ **خطأُ الصلاحية يمرّ كما هو** — ⛔ **فلا رمزَ قاعدةٍ فيه أصلاً.**
    Failure<void>(error: PermissionError()) => result,
    Failure<void>() => const Failure<void>(ValidationError('BR-M13-04')),
    Success<void>() => result,
  };
}

/// ★★★ **سطر الخصم** — `FR-M13-04` · `BR-M13-02`.
///
/// ```text
/// مبلغ الخصم > 0   ولا يتجاوز المتبقي على ذلك الضمار
/// ```
///
/// ⛔★★ **والصفر مرفوضٌ لا مُتجاهَل** — ★ **فسطرٌ بصفر يكتب حركةً دائنة بلا
/// أثر** ⟵ **ويُلوِّث كشف الحساب بسطورٍ لا معنى لها** (`FR-M17`).
///
/// ⛔⛔★★ **و«لا يتجاوز المتبقي» تُقاس على المتبقي بعد الخصم السابق كذلك** —
/// ★ **لأن [OpenDebtLot.remaining] هو `القيمة − المسدَّد − المخصوم`**:
/// ⟵ **فخصمان متتاليان لا يتجاوزان معاً قيمة الضمار** ⛔ **ولا يُسقِطان ديناً
/// أكبر مما عليه.**
Outcome<ValidatedDiscountLine> validateDiscountLine({
  required DiscountLineInput line,
  required OpenDebtLot lot,
}) {
  final Outcome<ValidatedReceiptLine> result = validateReceiptLine(
    line: ReceiptLineInput(
      debtLotId: line.debtLotId,
      amount: line.amount,
      note: line.note,
    ),
    lot: lot,
  );
  return switch (result) {
    Failure<ValidatedReceiptLine>() =>
      const Failure<ValidatedDiscountLine>(ValidationError('BR-M13-02')),
    Success<ValidatedReceiptLine>(:final ValidatedReceiptLine value) =>
      Success<ValidatedDiscountLine>(
        ValidatedDiscountLine(
          debtLotId: value.debtLotId,
          // ★ **المصدر من الضمار المقروء** ⛔ **لا من الحمولة** (`E-35`).
          sourceId: value.sourceId,
          remainingBefore: value.remainingBefore,
          amount: value.amount,
          remainingAfter: value.remainingAfter,
          note: value.note,
        ),
      ),
  };
}

/// ★★★ **سند الخصم كاملاً** — `FR-M13-02` … `FR-M13-04`.
///
/// ⛔⛔★★ **وضمارٌ مكرَّر في سطرين يُرفَض** — ★ **وإلا لتحقّق كلُّ سطرٍ على
/// حدة مقابل **نفس** المتبقي فمرّا معاً**، ⟵ **والمجموع يتجاوز الضمار
/// فيُسقَط دَينٌ أكبر من قيمته** ⛔ **وهو بالضبط ما يمنعه `BR-M13-02`.**
///
/// ⛔⛔★★★ **وسندٌ بلا سطرٍ يُرفَض قطعاً** — ★ **وهنا يفترق عن [validateReceiptLines]
/// افتراقاً جوهرياً**: ⟵ **فسندُ القبض يُجيز «الفائضَ وحده» بلا سطر**
/// (`FR-M12-10`)، ⛔ **والخصمُ لا فائضَ فيه إطلاقاً** (`FR-M13-05`) —
/// ★ **فسندُ خصمٍ بلا سطرٍ سندٌ بلا أثر**، ⟵ **ولا معنى لحفظه.**
Outcome<List<ValidatedDiscountLine>> validateDiscountLines({
  required Iterable<DiscountLineInput> lines,
  required Map<String, OpenDebtLot> lotsById,
}) {
  final List<ValidatedDiscountLine> validated = <ValidatedDiscountLine>[];
  final Set<String> seen = <String>{};
  for (final DiscountLineInput line in lines) {
    if (!seen.add(line.debtLotId)) {
      return const Failure<List<ValidatedDiscountLine>>(
        ValidationError('BR-M13-02'),
      );
    }
    final OpenDebtLot? lot = lotsById[line.debtLotId];
    if (lot == null) {
      // ⛔ **ضمارٌ لم يُقرأ رفضٌ لا تخطٍّ** — ★ **فتخطّيه يحفظ سنداً بمبلغٍ
      //    أقل مما أقرّه المستخدم** ⟵ **ويبدو ناجحاً.**
      return const Failure<List<ValidatedDiscountLine>>(
        ValidationError('BR-M13-02'),
      );
    }
    switch (validateDiscountLine(line: line, lot: lot)) {
      case Failure<ValidatedDiscountLine>(:final AppError error):
        return Failure<List<ValidatedDiscountLine>>(error);
      case Success<ValidatedDiscountLine>(:final ValidatedDiscountLine value):
        validated.add(value);
    }
  }
  if (validated.isEmpty) {
    return const Failure<List<ValidatedDiscountLine>>(
      ValidationError('BR-M13-02'),
    );
  }
  return Success<List<ValidatedDiscountLine>>(validated);
}

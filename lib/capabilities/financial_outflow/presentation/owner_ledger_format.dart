/// ★★★ **تحويلُ ملخّصِ ضمار المالك إلى عقد العرض** — **الموضعُ الوحيد للتنسيق**.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **ولماذا ملفٌّ مستقلٌّ لا دالةٌ داخل الشاشة:**
/// ★ **له قارئان — بطاقةُ اليوم وسجلُّ الأيام السابقة** (`FR-M15-14`):
/// ⟵ **ونسختان للتنسيق تُنتجان رقمين مختلفين للحدث نفسه**
/// (`coding-standards.md` §2.2).
///
/// ⛔⛔ **ولا معادلةَ واحدة هنا** — ★ **البنودُ تصل محسوبةً من طبقة النطاق**
/// (`ADR-0012`)، ⟵ **وهذا يُنسِّقها نصّاً لا غير** (`design-system.md` §5.1).
///
/// ★★ **والتنسيقُ نفسُه [formatRiyals] الذي تكتب به الرسائلُ والمستنداتُ
/// المُصدَّرة** (`WU-010`) — ⟵ **فرقمُ الشاشة يطابق رقمَ الرسالة حرفياً**،
/// ⛔ **ولا فاصلةَ آلافٍ ثانية تُكتب هنا.**
/// ═══════════════════════════════════════════════════════════════════════
library;

import 'package:qtms_domain/qtms_domain.dart';

import '../../../core/ui/date_labels.dart';
import 'owner_ledger_card.dart';

/// وحدةُ العملة المعروضة — ★ **مصدرٌ واحد** (`ADR-0015`).
const String riyalLabel = 'ريال';

/// ★★★ يبني عقدَ البطاقة من إسقاطِ الملخّص على صلاحيات قارئه.
///
/// ⛔⛔ **والبندُ المحكومُ يصل `null` لمن لا يملكه** — ⛔ **لا صفراً**:
/// ⟵ **الصفرُ معلومةٌ في هذا النظام** (§9 · §10.1 القاعدة 2).
OwnerLedgerSummaryView ownerLedgerViewOf(
  OwnerLedgerProjection projection, {
  required String scopeLabel,
  required bool isLive,
  Money? previousNetFinal,
}) {
  final OwnerLedgerSummary s = projection.summary;
  return OwnerLedgerSummaryView(
    scopeLabel: scopeLabel,
    totalDebt: _riyals(s.totalDebt),
    credit: _riyals(s.credit),
    cash: _riyals(s.cash),
    settledOfDay: _riyals(s.settledOfDay),
    discounts: _riyals(s.discounts),
    remainingBeforeDiscount: _riyals(s.remainingBeforeDiscount),
    remainingAfterDiscount: _riyals(s.remainingAfterDiscount),
    tax: _riyals(s.tax),
    remainingAfterTax: _riyals(s.remainingAfterTax),
    // ★★ **والصافي من الإسقاط لا من المخزَّن** — §5: ⟵ **فرقمُه يختلف بين
    //   قارئين**، ★ **وهو سلوكٌ مقصود لا خلل.**
    netFinal: _riyals(projection.netFinal),
    withdrawals: projection.withdrawals == null
        ? null
        : _riyals(projection.withdrawals!),
    expenses:
        projection.expenses == null ? null : _riyals(projection.expenses!),
    currencyLabel: riyalLabel,
    deltaLabel: _deltaLabel(projection.netFinal, previousNetFinal),
    deltaIsPositive: previousNetFinal == null ||
        projection.netFinal >= previousNetFinal,
    retroUpdatedAtLabel: s.retroUpdatedAt == null
        ? null
        : 'مُحدَّث بأثر رجعي — ${timestampLabel(s.retroUpdatedAt!)}',
    isLive: isLive,
  );
}

/// ★ فرقُ اليوم عن أمس — `FR-M15-23` (**سهم ونسبة تغيّر**).
///
/// ⛔ **و`null` حين لا يوم أمس يُقاس عليه** — ★ **ولا «0٪» كاذبة**:
/// ⟵ **فغيابُ المقارنة معلومةٌ مختلفةٌ عن «لا تغيير»** (§9).
String? _deltaLabel(Money current, Money? previous) {
  if (previous == null) return null;
  final int difference = current.riyals - previous.riyals;
  if (difference == 0) return 'كما أمس';
  final String arrow = difference > 0 ? '▲' : '▼';
  final String amount = formatRiyals(Money(difference.abs()));
  if (previous.isZero) return '$arrow $amount';
  final int percent = ((difference.abs() * 100) / previous.riyals).round();
  return '$arrow $amount ($percent٪)';
}

String _riyals(Money amount) => formatRiyals(amount);

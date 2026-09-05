/// عقود مستودعات التوزيع والضمار — **قراءةً وكتابةً**.
///
/// ★ **الفصل مقصود ويطابق `ADR-0013`:** القراءة **مباشرة من القاعدة**
/// (القاعدة 4)، **والكتابة عبر دالة سحابية مستدعاة** تكتب المستند وحركاته
/// المخزنية وقيدَه المدين وأرصدته **وقيدَ تدقيقه في معاملة واحدة** (القاعدة 1).
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔★★★ **وبطاقتان لا واحدة — وهذا جوهر `ADR-0011` في هذه الوحدة:**
///
///   [DistributionCard]        ← المستند الأب · **يقرؤه كل مصادَق في نطاقه**
///   [DistributionPricingCard] ← 🔒 `pricing/current` · **بـ`distributionPriceView` وحدها**
///
/// ⟵ **ودمجُهما في نوعٍ واحد بحقولٍ اختيارية كان سيجعل `ت-12` إخفاءَ واجهة
/// لا حماية**: ★ **النوعُ المنفصل يجعل غياب الأسعار حالةً صريحة في الكود**
/// ⛔ **لا حقولاً `null` تُنسى في شاشةٍ ما فتُعرَض.**
/// ═══════════════════════════════════════════════════════════════════════
library;

import '../../../core/calendar_day.dart';
import '../../../core/money.dart';
import '../../../core/outcome.dart';
import '../../../core/quantity.dart';
import 'distribution.dart';

/// بطاقة مستند التوزيع — **المستند الأب وحده** ⛔ **بلا سعرٍ ولا إجمالي مالي**.
///
/// ⛔⛔★★ **ولا حقل سعرٍ واحد هنا** (`ADR-0011` · `data-dictionary.md`):
/// ★ **القاعدة تمنح المستند كاملاً ولا تُخفي حقلاً داخله** — ⟵ **فأي مبلغ
/// في هذا النوع يعني أن كل مصادَق في النطاق يقرؤه**، **ومنه `debtValue`
/// تحديداً** لأن الإجمالي يكشف المبلغ ولو أُخفيت مفرداته.
final class DistributionCard {
  /// ينشئ البطاقة.
  DistributionCard({
    required this.distributionId,
    required this.documentNumber,
    required this.sourceId,
    required this.dealerId,
    required this.dealerName,
    required this.stockDate,
    required this.entryDate,
    required this.status,
    required this.unpricedLineCount,
    required this.totalPieces,
    required this.totalWeight,
    required List<ValidatedDistributionLine> lines,
    this.sourceName,
    this.notes,
    this.cancelReason,
    this.amendCount = 0,
    this.settlementStatus,
  }) : lines = List<ValidatedDistributionLine>.unmodifiable(lines);

  /// ★ المعرّف المركّب — `{dealerId}_{sourceId}_{stockDate}` (`GR-18`).
  final String distributionId;

  /// رقم المستند — `DST-YYYYMMDD-####`.
  final String documentNumber;

  /// المصدر.
  final String sourceId;

  /// اسم المصدر لحظة الإنشاء.
  final String? sourceName;

  /// المقوت.
  final String dealerId;

  /// اسم المقوت لحظة الإنشاء — ★ **نسخةٌ مقصودة** (`naming-conventions.md` §4).
  final String dealerName;

  /// ★ **تاريخ المخزون** — 🔒 **يحدده النظام لا المستخدم** (`FR-M10-03`).
  final CalendarDay stockDate;

  /// تاريخ الإدخال — ⚠️ **يختلف عن [stockDate] في التصريف المتأخر** (`E-23`).
  final DateTime entryDate;

  /// الحالة.
  final DistributionStatus status;

  /// ★ عدد السطور غير المسعَّرة — 🧮 **عدد لا مبلغ**، ⟵ **ولذلك يعيش هنا.**
  final int unpricedLineCount;

  /// ★ إجمالي الحبّات — ⛔ **ولا يُجمع مع [totalWeight]** (`GR-19`).
  final PieceCount totalPieces;

  /// ★ إجمالي الأوزان — ⛔ **ولا يُجمع مع [totalPieces]** (`GR-19`).
  final WeightKg totalWeight;

  /// السطور — ⛔ **بلا سعرٍ فيها** (راجع ترويسة النوع).
  final List<ValidatedDistributionLine> lines;

  /// ملاحظات المستند.
  final String? notes;

  /// سبب الإلغاء.
  final String? cancelReason;

  /// عدد التعديلات — ★ **مصدر شارة «مُعدَّل ×N»** (`FR-M10-16`).
  final int amendCount;

  /// ★★ **حالةُ تسوية الضمار** — و`null` **لتوزيعةٍ بلا الحقل بعد**.
  ///
  /// ═════════════════════════════════════════════════════════════════════
  /// ⚠️⚠️ **ولماذا أُضيفت في `WU-011`:** ★ **`R-10` يفلتر «مفتوحة / مغلقة /
  /// الكل»** (`FR-M19` §2)، ⟵ **والحقلُ مكتوبٌ فعلاً منذ `WU-006`**
  /// (`distribution.dart` — `'settlementStatus': settlement.status.name`)
  /// **ويُحدَّث في `WU-007`** (`receipt.dart`) — ★ **فلا قيمةَ تُخترَع هنا**،
  /// ⛔ **ولا فهرسَ بلا كاتب.**
  ///
  /// ⛔⛔★★ **وهي حالةُ التسوية لا [status]** — ★ **وذاك حالةُ التسعير**
  /// (معتمد · مسعَّر جزئياً · مسعَّر · ملغى): ⟵ **وخلطُهما يُري المستخدم
  /// ضماراً «مغلقاً» وهو غيرُ مسعَّر أصلاً** ⛔ **وهما بُعدان مستقلان.**
  ///
  /// ★ **و`null` تعني «لم يُقرأ أو لم يُكتب بعد»** — ⛔ **ولا تُقرأ
  /// [SettlementStatus.open] احتياطاً**: ⟵ **فضمارٌ مُصفّى يُعرَض مفتوحاً
  /// يُطالِب مقوتاً بما سدَّده.**
  /// ═════════════════════════════════════════════════════════════════════
  final SettlementStatus? settlementStatus;

  /// ★ **وسم «⏳ سعر غير نهائي»** — يراه الجميع (`firestore.rules` §16).
  bool get hasUnpricedLines => unpricedLineCount > 0;

  /// هل المستند ملغى؟
  bool get isCancelled => status == DistributionStatus.cancelled;
}

/// 🔒 بطاقة أسعار التوزيعة — `distributions/{key}/pricing/current`.
///
/// ⛔⛔★★ **ولا تصل هذه البطاقة إلا لمن يملك `distributionPriceView`** —
/// ★ **والمنع في القاعدة نفسها** (`firestore.rules` §16 · `ADR-0011`)،
/// ⟵ **فغيابُها ليس خطأً بل الحالةَ الطبيعية لمن لا يملك الصلاحية**
/// (`ت-12` · `FR-M10-07`).
///
/// ⚠️⚠️ **وغيابُها لا يعني أن التوزيعة بلا سعر** — `FR-M10-07`: «**يُطبَّق
/// سعر التسعير اليومي تلقائياً وتُحتسب قيمة الضمار كاملة وتُقيَّد المديونية
/// بها — هو فقط لا يراها**». ⛔ **وهذا أكثر ما يُساء فهمه في هذه الوحدة**
/// (`distribution-design.md` §4).
final class DistributionPricingCard {
  /// ينشئ البطاقة.
  DistributionPricingCard({
    required this.sourceId,
    required this.debtValue,
    required List<Money?> unitPrices,
    required List<Money?> lineTotals,
  })  : unitPrices = List<Money?>.unmodifiable(unitPrices),
        lineTotals = List<Money?>.unmodifiable(lineTotals);

  /// ★ **نسخة من المصدر في الأب** — **لفحص النطاق بلا قراءة إضافية**.
  final String sourceId;

  /// ★ **قيمة الضمار** — `Σ(قيم السطور المسعَّرة فقط)`.
  final Money debtValue;

  /// الأسعار المُجمَّدة — ★ **موازية لترتيب `lines[]` في الأب**.
  final List<Money?> unitPrices;

  /// قيم السطور — ★ **موازية لترتيب `lines[]` في الأب**.
  final List<Money?> lineTotals;
}

/// ⛅ بطاقة رصيد المقوت في مصدر — `dealer_balances/{dealerId}_{sourceId}`.
///
/// ⚠️ **ملخصٌ مشتقّ** (`ADR-0008`) — ⛔ **ولا يُقرأ كمصدر حقيقة في معاملة**:
/// ★ **الرصيد يُجمَع من الدفتر داخلها** ([computeDealerBalance]).
final class DealerBalanceCard {
  /// ينشئ البطاقة.
  const DealerBalanceCard({
    required this.dealerId,
    required this.sourceId,
    required this.balance,
    required this.openDebtCount,
    this.oldestOpenDebtDate,
  });

  /// المقوت.
  final String dealerId;

  /// ★ المصدر — **والرصيد يخصّه وحده** (`GR-20`).
  final String sourceId;

  /// المدين والدائن والرصيد.
  final DealerAccountBalance balance;

  /// ★ عدد الضمارات المفتوحة — **أساس أعمار الديون** (`M20`).
  final int openDebtCount;

  /// تاريخ أقدم ضمار مفتوح — `null` إن لم يوجد.
  final CalendarDay? oldestOpenDebtDate;
}

/// دليل التوزيع — **قراءةً فقط**.
///
/// ★ **تدفّقات لا قراءات مفردة:** توزيعٌ من جهازٍ آخر **يظهر فوراً**
/// (`ADR-0010`) — ⟵ **فلا يوزّع اثنان لنفس المقوت وهما لا يريان بعضهما**،
/// ★ **والمعرّف المركّب يمنع الازدواج بنيوياً على أي حال** (`GR-18`).
abstract interface class DistributionDirectory {
  /// ★ **توزيعات يومٍ واحد لمصدرٍ واحد** — الفهرس `sourceId ↑ · stockDate ↓`.
  Stream<List<DistributionCard>> watchDistributions({
    required String sourceId,
    required CalendarDay stockDate,
  });

  // ⛔⛔★★★ **ولا قارئَ بالمعرّف المركّب هنا — وهذا حارسٌ لا نقص:**
  //
  // ⚠️⚠️ **رُصد حيّاً على المحاكي (2026-08-27):** قراءةُ
  // `distributions/{المعرّف المركّب}` **مباشرةً تُرفَض بـ`PERMISSION_DENIED`
  // ما دام المستند غائباً** — ★ **لأن شرط القراءة `storedInScope()` يقرأ
  // `resource.data.sourceId`**، ⟵ **والمستندُ الغائب بلا `resource` أصلاً
  // فيُقيَّم الشرط `false`.**
  //
  // ⛔ **والغياب هو الحالة الطبيعية قبل أول توزيعة**، ⟵ **فالمسار الذي
  // يحتاجه `E-04` كان يفشل في أكثر حالاته شيوعاً** — ★ **ولا اختبارَ آليٌّ
  // واحدٌ يكشفه**: البدائل تُرجِع `null` بلا رفض.
  //
  // ★★ **وهي بعينها مقايسةُ `IQ-024` و`WU-008` الثالثة** (`CLAUDE.md`):
  // **شرطٌ يعتمد `resource.data` يُقيَّد في الاستعلام** — ⟵ **فالوجود
  // يُستنتَج من [watchDistributions] المقيَّدة بـ`sourceId` و`stockDate`**
  // (الفهرس `sourceId ↑ · stockDate ↓`)، ⛔ **لا بقراءةٍ بالمعرّف.**
  //
  // ⛔ **والعلاج تقييدُ الاستعلام لا تخفيفُ القاعدة** — ★ **فالقاعدة سليمة.**

  /// 🔒 **أسعار توزيعةٍ** — ⛔ **ولا تصل إلا لمن يملك `distributionPriceView`**.
  ///
  /// ⚠️ **ويُرجِع `null` عند المنع وعند الغياب معاً** — ★ **والتمييز بينهما
  /// لا يلزم الشاشة**: **كلاهما «لا تعرض عمود السعر»** (`ت-12`)، ⛔ **وطلبُ
  /// التمييز كان سيُغري بعرض رسالة تكشف وجود مبلغ.**
  Stream<DistributionPricingCard?> watchDistributionPricing({
    required String distributionId,
  });

  /// 🔒 **رصيد المقوت في مصدر** — ⛔ **ولا يصل إلا لمن يملك `dealerBalanceView`**.
  ///
  /// ═══════════════════════════════════════════════════════════════════════
  /// ★★ **ولماذا لزم في `WU-010`:** `FR-M20-07` يجعل القالب ② يحمل **«ضمار
  /// اليوم والرصيد السابق والحالي»** — ⟵ **ولا مصدرَ للرصيد في التطبيق قبله.**
  ///
  /// ⛔⛔★★ **وقراءةٌ بالمعرّف هنا آمنةٌ بخلاف `distributions`:** ★ **شرط
  /// القراءة `perm('dealerBalanceView')` وحده** ⛔ **ولا يعتمد `resource.data`**
  /// (`firestore.rules` — `match /dealer_balances/{balanceId}`)، ⟵ **فالمستند
  /// الغائب لا يُرفَض بل يُقرأ `null`** — ★ **وهو عكسُ ما رُصد في `DEBT-40`.**
  ///
  /// ⚠️ **و`null` تعني «لا رصيد بعد» أو «لا أملك رؤيته» معاً** — ★ **والتمييز
  /// لا يلزم الشاشة**: ⟵ **كلاهما «لا يُعرَض القالب ②»**، ⛔ **وطلبُ التمييز
  /// كان سيُغري برسالةٍ تكشف وجود رصيد.**
  /// ═══════════════════════════════════════════════════════════════════════
  Stream<DealerBalanceCard?> watchDealerBalance({
    required String dealerId,
    required String sourceId,
  });
}

/// مستودع كتابة التوزيع — **عبر العمليات المستدعاة حصراً**.
///
/// ⛔★★ **ولا كتابة مباشرة واحدة:** `distributions` و`dealer_ledger` و
/// `dealer_balances` و`inventory_ledger` **كلها `allow write: if false`** —
/// ⟵ **فالواجهة تطلب ولا تكتب**، **والمستندُ والحركةُ والقيدُ والأرصدةُ
/// وقيدُ التدقيق في معاملة سحابية واحدة** (`FR-M10-13` · `GR-51`).
abstract interface class DistributionAdminRepository {
  /// ينشئ توزيعةً ويُرجِع **رقمها** — ★ **والرقم من السحابة** ⛔ **ولا
  /// يُولِّده الجهاز** (`naming-conventions.md` §5).
  ///
  /// ⚙️ **وتاريخ المخزون من الخادم** (`FR-M10-03` · `A-10` · `GR-14`) —
  /// ⛔ **ولا يُرسَل أصلاً**، ★ **فما لا يُرسَل لا يُزوَّر.**
  ///
  /// ⚠️⚠️ **ويُرفَض الإنشاء إن وُجدت توزيعةٌ بنفس المفتاح** برمز
  /// `ERR_DIST_001` (`GR-18` · `E-04`) — ★ **والواجهة تفتح الموجودة
  /// للتعديل** ⛔ **ولا تُنشئ ثانية.**
  /// ★★★ **و[stockDate] مسارُ التصريف المتأخر وحده** (`WU-019` · `FR-M8-11`):
  /// ⛔⛔ **وغيابُه هو الحالُ الأصلي** — `FR-M10-03`: **تاريخُ المخزون من
  /// المنصّة ولا يُغيَّر يدوياً**، ⟵ **ووجودُه بيومٍ أقدم يشترط
  /// `agedRemainderClear`** ⛔ **وبيومٍ أحدث مرفوضٌ للجميع** (`GR-13`).
  Future<Outcome<String>> createDistribution(
    ValidatedDistribution distribution, {
    CalendarDay? stockDate,
  });

  /// ★ يعدّل توزيعةً معتمدة — **بصلاحية `distributionAmend` وسببٍ نصّي
  /// إلزامي** (`FR-M10-16` · `ADR-0004`).
  ///
  /// ⛔ **ولا يُنشئ حركة تصحيحية:** الحركة والقيد **يُعدَّلان في مكانهما**
  /// ويُعاد احتساب **الرصيد وقيمة الضمار وحالة تسويته** (`A-14` · `AT-57`).
  Future<Outcome<void>> amendDistribution({
    required String documentNumber,
    required ValidatedDistribution distribution,
    String? amendReason,
  });

  /// ★ يُلغي توزيعةً — **بصلاحية `distributionCancel` وسببٍ نصّي إلزامي**.
  ///
  /// ⛔⛔ **ويُرفَض إن سُدِّد ضمارها كلياً أو جزئياً** برمز `ERR_AMEND_005`
  /// (`FR-M10-18` · `E-15`) — ★ **حتى تُعالَج المقبوضات والخصومات.**
  ///
  /// ⛔ **والحذف مرفوض نهائياً** (`GR-07`) — ⟵ **فلا دالة حذف في هذا العقد.**
  Future<Outcome<void>> cancelDistribution({
    required String documentNumber,
    required String sourceId,
    required String dealerId,
    String? cancelReason,
  });
}

/// المتبقي المتأخر — ★ **رصيدُ يومٍ سابقٍ لم يُصفَّر** (`WU-019` · `M8`).
///
/// ★ **المصدر:** `FR-M8-09` … `FR-M8-18` · `UC-004` ·
/// `inventory-design.md` §5 · `design-overview.md` §2.1 · `ADR-0006`
/// (التاريخان) · `ADR-0008` (المشتقّ يُبنى ولا يُقرأ مصدرَ حقيقة).
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔★★ **ثلاث قواعد بنيوية يفرضها هذا الملف:**
///
///   ① **بندٌ متبقٍّ ⟺ رصيدُ (مصدر × نوع × تاريخ مخزون) موجبٌ تماماً** —
///      `inventory-design.md` §5. ⟵ **والصفرُ ليس بنداً**، ⛔ **ولا يُنشأ له
///      سجل** (`ADR-0008` القاعدة 5).
///   ② ★★ **والعمرُ يُحسَب لحظةَ القراءة ⛔ لا يُخزَّن** — راجع
///      [agedRemainderAgeInDays]: **عمرٌ مخزَّنٌ يشيخ بلا كاتب**، ⟵ **وبندٌ
///      كُتب أمس يعرض «يومٌ واحد» بعد أسبوع** ⛔ **وهو رقمٌ خاطئٌ بصمت.**
///   ③ ★★ **و«متأخر» تعني `stockDate < اليوم` حصراً** — ⟵ **ورصيدُ اليوم
///      نفسِه ليس متأخراً** (`FR-M8-05`: **شاشةُ مخزون اليوم تعرضه**)،
///      ⛔ **والتمييزُ يقع عند القراءة لا عند الكتابة**: ★ **فبندُ اليوم يصير
///      متأخراً غداً بلا أن يكتبه أحد.**
/// ═══════════════════════════════════════════════════════════════════════
///
/// ⚠️⚠️ **ولماذا مجموعةٌ مبنيّةٌ مسبقاً أصلاً** (`aged_remainders`):
/// `indexing-strategy.md` §4 يَسِم استعلامَ المتبقي المتأخر بأنه **«يمسح
/// أرصدة كل الأيام السابقة»** ويفرض تخفيفَه بـ**«قائمة مبنية مسبقاً»**،
/// و`performance-requirements.md` §3 يكرّرها نصّاً. ⟵ **فالمجموعة تحمل
/// الأرصدةَ الموجبة وحدَها** ⛔ **لا نسخةً من كل يومٍ مضى.**
library;

import '../../../core/calendar_day.dart';
import '../../master_data/domain/master_data.dart' show ItemUnit;
import 'inventory.dart';
import 'sack_intake.dart' show ledgerItemDisplayName;

// ═════════════════════════════════════════════════════════════════════════
// المجموعة والمفتاح — `data-dictionary.md` §4 · `naming-conventions.md` §4
// ═════════════════════════════════════════════════════════════════════════

/// ⛅ قائمةُ المتبقي المتأخر المبنيّة مسبقاً — ⛅ **تكتبها السحابة حصراً**.
///
/// ⚠️ **وغيابُ السجل يعني «لا متبقٍّ»** — ★ **بنفس قاعدة `item_daily_balances`**
/// (`ADR-0008` القاعدة 5): ⛔ **ولا يُنشأ سجل بصفر بلا داعٍ.**
const String agedRemaindersCollection = 'aged_remainders';

/// معرّف بند المتبقي — `{sourceId}_{itemKey}_{stockDate}`.
///
/// ★★ **وهو معرّف [itemDailyBalanceId] نفسُه بترتيبه** — ⛔ **ولا يُبدَّل**:
/// ⟵ **فالبندُ ظلُّ سجلِ الرصيد**، ★ **ومعرّفٌ حتميٌّ مطابقٌ له يجعل المحوَ
/// عند التصفير كتابةً واحدةً بلا قراءةٍ سابقة** (نظيرُ `pendingEntryId`).
String agedRemainderId({
  required String sourceId,
  required String itemKey,
  required CalendarDay stockDate,
}) =>
    itemDailyBalanceId(
      sourceId: sourceId,
      itemKey: itemKey,
      stockDate: stockDate,
    );

// ═════════════════════════════════════════════════════════════════════════
// العمر وحدّته — `FR-M8-10` · `inventory-design.md` §5
// ═════════════════════════════════════════════════════════════════════════

/// ★★ **عمر البند بالأيام** — `inventory-design.md` §5:
/// «**عمر البند = تاريخ اليوم − تاريخ المخزون**».
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **ولا يُخزَّن في `aged_remainders` عمداً — والفرقُ ليس تحسيناً:**
/// ★ **العمرُ دالّةٌ في *اليوم الحالي*** ⟵ **فيتغيّر كل منتصف ليلٍ بلا أي
/// كتابةٍ تُطلِقه**، ⛔ **ولا مجدولةَ في هذا المكدّس تُحدِّثه** (`WU-016`
/// بنى الملخصات **داخل المعاملة** ⛔ **لا بمشغّل Eventarc ولا بجدولة**).
/// ⟹ ★ **فحقلٌ مخزَّنٌ للعمر يُصبح كاذباً بعد ساعاتٍ من كتابته**، ★ **ويُلوِّن
/// بندَ خمسةِ أيامٍ بلون «يوم–يومان»** — ⟵ **وهو بالضبط الرقمُ الخاطئ بصمت
/// الذي تمنعه قواعد هذا المشروع.**
///
/// ⚠️ **وهذا انحرافٌ معلَنٌ عن `data-dictionary.md` §4** (كان يَعُدّ «العمر
/// بالأيام» ضمن محتوى السجل) — ★ **صُحِّح المستندُ ليطابق المُنفَّذ**،
/// ⛔ **ولا يُترك ادّعاءُ حقلٍ لا كاتبَ له.**
/// ═══════════════════════════════════════════════════════════════════════
///
/// ⚠️ **ويُرجِع صفراً أو أقلّ لبندِ اليوم أو المستقبل** — ★ **والتصفيةُ
/// شرطُ [isAgedRemainder]** ⛔ **لا هذه الدالة**: ⟵ **الحسابُ حسابٌ والحكمُ
/// حكم** (`design-system.md` §5.1).
int agedRemainderAgeInDays({
  required CalendarDay today,
  required CalendarDay stockDate,
}) =>
    today.asUtcMidnight().difference(stockDate.asUtcMidnight()).inDays;

/// ★ هل هذا البند **متأخر** فعلاً؟ — ★ **`stockDate` أقدمُ من اليوم حصراً**.
///
/// ⛔★★ **ورصيدُ اليوم ليس متأخراً** — `FR-M8-17` (**لا يظهر في التسعير**)
/// و`E2` من `UC-004` (**ولا في مخزون اليوم**): ⟵ **والشاشتان تقتسمان
/// الرصيدَ بهذا الحدّ وحدَه** ⛔ **فلا بندَ يظهر فيهما معاً ولا يغيب عنهما معاً.**
bool isAgedRemainder({
  required CalendarDay today,
  required CalendarDay stockDate,
}) =>
    agedRemainderAgeInDays(today: today, stockDate: stockDate) > 0;

/// ★★ درجةُ حدّة المتبقي — `FR-M8-10`: **تدرّجٌ حسب العمر**.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ★ **الحدود من المتطلب حرفياً** — ⛔ **لا عتبةٌ مخترَعة:**
/// **يوم–يومان** · **3–4 أيام** · **5 أيامٍ فأكثر**.
///
/// ⛔⛔★★ **والدرجةُ تُحسَب هنا وتصل الشاشةَ جاهزة** — `design-system.md`
/// §5.1: «**مكوّنات العرض لا تحسب ولا تقرّر**»، ⟵ **ومقارنةُ الرقم بالحدّ
/// داخل مكوّنٍ تجعل القاعدة تعيش في موضعين.**
/// ═══════════════════════════════════════════════════════════════════════
enum AgedRemainderSeverity {
  /// ★ **يوم–يومان** — `FR-M8-10` 🟡.
  recent,

  /// ★ **3–4 أيام** — `FR-M8-10` 🟠.
  ageing,

  /// ★ **5 أيامٍ فأكثر** — `FR-M8-10` 🔴.
  overdue;

  /// ★ الدرجةُ الأشدُّ من درجتين — ★ **لتجميع بندٍ واحدٍ يمثّل قائمة**.
  AgedRemainderSeverity max(AgedRemainderSeverity other) =>
      index >= other.index ? this : other;
}

/// ★★ يشتقّ الدرجة من العمر بالأيام — ⛔ **والعمرُ يصل محسوباً لا مخزَّناً**.
///
/// ⚠️ **وعمرٌ ≤ 0 لا يبلغ هذه الدالة في المسار الصحيح** ([isAgedRemainder])،
/// ★ **ويُعامَل [AgedRemainderSeverity.recent] لو بلغها** — ⛔ **ولا يُرمى
/// استثناء**: ⟵ **بندٌ عمرُه صفرٌ خطأُ تصفيةٍ في المُستدعي لا حالةٌ حرجة
/// تُسقِط شاشة.**
AgedRemainderSeverity agedRemainderSeverityOf(int ageInDays) {
  if (ageInDays >= 5) return AgedRemainderSeverity.overdue;
  if (ageInDays >= 3) return AgedRemainderSeverity.ageing;
  return AgedRemainderSeverity.recent;
}

// ═════════════════════════════════════════════════════════════════════════
// البند كما يُقرأ
// ═════════════════════════════════════════════════════════════════════════

/// بندُ متبقٍّ متأخر — **بطاقةُ `aged_remainders/{المفتاح المركّب}`**.
final class AgedRemainderCard {
  /// ينشئ البطاقة.
  const AgedRemainderCard({
    required this.sourceId,
    required this.itemKey,
    required this.itemName,
    required this.stockDate,
    required this.remaining,
  });

  /// المصدر — ★ **وشرطُ القراءة `storedInScope()` يقرؤه** (`IQ-024`).
  final String sourceId;

  /// مفتاح النوع — **مجرَّداً أو مركّباً** (`ADR-0007`).
  final String itemKey;

  /// اسمُه كما كُتب في الدفتر — ★ **نسخةٌ تاريخيةٌ مقصودة**.
  final String itemName;

  /// ★ **تاريخ المخزون** — ⛔ **لا تاريخ الإدخال** (`RISK-07`).
  final CalendarDay stockDate;

  /// الكميةُ المتبقيةُ بوحدتها — ★ **موجبةٌ تماماً** (شرطُ وجود البند).
  final StockQuantity remaining;

  /// وحدةُ البند — ★ **وحدةُ رصيده** (`GR-19`).
  ItemUnit get unit => remaining.unit;

  /// ★ **الاسمُ المعروض** — ⛔ **المركّبُ لا المجرَّد** ([`DEBT-86`]).
  String get displayName =>
      ledgerItemDisplayName(itemKey: itemKey, itemName: itemName);

  /// عمرُ البند بالأيام **مقيساً على [today]**.
  int ageInDaysOn(CalendarDay today) =>
      agedRemainderAgeInDays(today: today, stockDate: stockDate);

  /// درجةُ حدّته **مقيسةً على [today]**.
  AgedRemainderSeverity severityOn(CalendarDay today) =>
      agedRemainderSeverityOf(ageInDaysOn(today));
}

/// ★★ يومٌ من أيام المتبقي — **بنودُه مجمَّعةً كما تعرضها الشاشة** (`UC-004` ②).
final class AgedRemainderDay {
  /// ينشئ اليوم.
  AgedRemainderDay({
    required this.stockDate,
    required this.ageInDays,
    required List<AgedRemainderCard> items,
  })  : items = List<AgedRemainderCard>.unmodifiable(items),
        severity = agedRemainderSeverityOf(ageInDays);

  /// تاريخ المخزون الذي تنتمي إليه هذه البنود.
  final CalendarDay stockDate;

  /// عمرُ اليوم بالأيام.
  final int ageInDays;

  /// درجةُ حدّته.
  final AgedRemainderSeverity severity;

  /// بنودُه — ★ **مرتّبةً بمصدرها ثم بمفتاح نوعها**.
  final List<AgedRemainderCard> items;
}

/// ★★★ يجمع البنودَ في أيامٍ مرتّبةً **من الأقدم إلى الأحدث** — `UC-004` ②.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★ **والأقدمُ أولاً عمداً** — ★ **الترتيبُ يحمل معنى** (`ui-guidelines.md`
/// §3 نمط 1 القرار 2: «**الترتيبُ هنا يحمل معنى، والحجمُ المتساوي يمحوه**»):
/// ⟵ **فأشدُّ البنود تأخّراً يقع أولَ الشاشة** ⛔ **لا آخرَها.**
///
/// ⛔ **ويُسقِط كلَّ بندٍ ليس متأخراً** ([isAgedRemainder]) — ★ **ورصيدُ اليوم
/// شأنُ شاشةِ مخزون اليوم** (`FR-M8-05`).
///
/// ⛔ **ويُسقِط كلَّ بندٍ رصيدُه غيرُ موجب** — ★ **حارسٌ ثانٍ فوق حتمية
/// المحو**: ⟵ **سجلٌّ بقي بصفرٍ لأي سببٍ لا يُعرَض بنداً يُطالِب بتصريف
/// عدم.**
/// ═══════════════════════════════════════════════════════════════════════
List<AgedRemainderDay> groupAgedRemainders({
  required Iterable<AgedRemainderCard> cards,
  required CalendarDay today,
}) {
  final Map<String, List<AgedRemainderCard>> byDay =
      <String, List<AgedRemainderCard>>{};
  final Map<String, CalendarDay> days = <String, CalendarDay>{};

  for (final AgedRemainderCard card in cards) {
    if (!card.remaining.isPositive) continue;
    if (!isAgedRemainder(today: today, stockDate: card.stockDate)) continue;
    final String key = card.stockDate.format();
    days[key] = card.stockDate;
    (byDay[key] ??= <AgedRemainderCard>[]).add(card);
  }

  final List<String> keys = byDay.keys.toList()..sort();
  return <AgedRemainderDay>[
    for (final String key in keys)
      AgedRemainderDay(
        stockDate: days[key]!,
        ageInDays:
            agedRemainderAgeInDays(today: today, stockDate: days[key]!),
        items: byDay[key]!
          ..sort((AgedRemainderCard a, AgedRemainderCard b) {
            final int bySource = a.sourceId.compareTo(b.sourceId);
            return bySource != 0 ? bySource : a.itemKey.compareTo(b.itemKey);
          }),
      ),
  ];
}

/// ★★ خلاصةُ التنبيه الدائم — `FR-M8-10`: **عددُ الأيام ودرجةُ أشدّها**.
///
/// ⛔⛔★★ **وعددُ الأيام لا عددُ البنود** — `UC-004` ① نصّاً: «**📦 متبقي
/// أيام سابقة: {العدد} أيام**»: ⟵ **والعددُ يجيب «كم يوماً لم يُقفَل؟»**،
/// ⛔ **لا «كم صنفاً بقي؟»** — ★ **وهما رقمان مختلفان يوماً فيه ثلاثةُ أنواع.**
final class AgedRemainderAlert {
  /// ينشئ الخلاصة.
  const AgedRemainderAlert({
    required this.dayCount,
    required this.itemCount,
    required this.severity,
    required this.oldestAgeInDays,
  });

  /// ★ خلاصةٌ هادئة — ⛔ **ولا تُخفى البطاقة** (`design-system.md` §7).
  static const AgedRemainderAlert clear = AgedRemainderAlert(
    dayCount: 0,
    itemCount: 0,
    severity: AgedRemainderSeverity.recent,
    oldestAgeInDays: 0,
  );

  /// عددُ الأيام التي فيها متبقٍّ.
  final int dayCount;

  /// عددُ البنود عبرها — ★ **للوصف لا للعدّاد.**
  final int itemCount;

  /// درجةُ أشدّ الأيام.
  final AgedRemainderSeverity severity;

  /// عمرُ أقدم يومٍ بالأيام.
  final int oldestAgeInDays;

  /// هل هناك ما يحتاج إجراءً؟
  bool get hasWork => dayCount > 0;
}

/// ★ يبني خلاصةَ التنبيه من الأيام المجمَّعة — ⛔ **بلا حسابٍ في الشاشة**.
AgedRemainderAlert summarizeAgedRemainders(List<AgedRemainderDay> days) {
  if (days.isEmpty) return AgedRemainderAlert.clear;
  AgedRemainderSeverity severity = AgedRemainderSeverity.recent;
  int items = 0;
  for (final AgedRemainderDay day in days) {
    severity = severity.max(day.severity);
    items += day.items.length;
  }
  return AgedRemainderAlert(
    dayCount: days.length,
    itemCount: items,
    severity: severity,
    // ★ **والأقدمُ أولاً** — [groupAgedRemainders] ترتّبها تصاعدياً بالتاريخ.
    oldestAgeInDays: days.first.ageInDays,
  );
}

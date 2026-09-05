/// ترقيم المستندات وأكواد الكيانات.
///
/// ★ **نقل حرفي لـ`naming-conventions.md` §5** — وهو مستند **STATIC**.
/// البادئات وعروض التسلسل أدناه **منقولة من جدوله كما هي**، ⛔ ولا واحدة
/// منها مخترَعة. لاحظ أن **`STK` بثلاث خانات و`SRC` بثلاث** بينما البقية
/// بأربع — وهذا ما ينصّ عليه الجدول حرفياً، لا سهو.
///
/// ★ **ولماذا يعيش هذا في طبقة النطاق المشتركة:** الرقم **تُولِّده السحابة
/// حصراً** (§5) بينما **يعرضه التطبيق ويبحث به**. فلو تكرّرت الصيغة في
/// الطرفين لافترقتا عند أول تعديل — وهو بالضبط ما بُني `ADR-0012` لمنعه.
library;

import 'calendar_day.dart';

/// أنواع المستندات المرقَّمة — البادئة وعرض التسلسل من `naming-conventions.md` §5.
enum DocumentKind {
  /// وارد عدداً — `INC-YYYYMMDD-####`.
  countedIntake('INC', 4),

  /// جونية — `SCK-YYYYMMDD-####`.
  sack('SCK', 4),

  /// توزيع — `DST-YYYYMMDD-####`.
  distribution('DST', 4),

  /// بيع نقدي — `CSH-YYYYMMDD-####`.
  cashSale('CSH', 4),

  /// سند قبض — `RCP-YYYYMMDD-####`.
  receipt('RCP', 4),

  /// سند خصم — `DSC-YYYYMMDD-####`.
  discount('DSC', 4),

  /// سحبية — `WDR-YYYYMMDD-####`.
  withdrawal('WDR', 4),

  /// خرجية — `EXP-YYYYMMDD-####`.
  expense('EXP', 4),

  /// جرد — `STK-YYYYMMDD-###` — ★ **بثلاث خانات لا أربع**.
  stocktake('STK', 3),

  /// ★★ إتلاف — `DSP-YYYYMMDD-####` (`WU-020` · `FR-M8-16`).
  ///
  /// ⚠️⚠️★★ **والبادئةُ مُشتقّةٌ لا مُخترَعة — ⛔ ولا تُقرأ سهواً:**
  /// ★ **`naming-conventions.md` §5 لا يذكر مستندَ الإتلاف** (**المصدرُ
  /// نفسُه لم يذكره**)، ⟵ **والاشتقاقُ بنفس خطوة `WU-000` حين أضاف مجموعةَ
  /// `disposals` إلى `data-dictionary.md`**: **معجمُ §2 يقول الإتلاف ⟵
  /// `disposal`**، ★ **والهيكلُ العظمي لحروفه `DSP`** ⟵ **وهي غيرُ
  /// مستعمَلةٍ في البادئات التسع القائمة** (⛔ **و`DIS` كانت تُلبَس بـ`DSC`
  /// و`DST`**). ★★ **وأربعُ خاناتٍ كبقية مستندات الحركة** — ⛔ **والثلاثُ
  /// استثناءُ الجرد وحده الموثَّق في §5.**
  disposal('DSP', 4);

  const DocumentKind(this.prefix, this.sequenceWidth);

  /// البادئة الحرفية من الجدول.
  final String prefix;

  /// عدد خانات التسلسل الأدنى.
  final int sequenceWidth;
}

/// أكواد الكيانات — `naming-conventions.md` §5.
enum EntityKind {
  /// مصدر — `SRC-001` — ★ **بثلاث خانات**.
  source('SRC', 3),

  /// رعوي (مورّد) — `SUP-0001`.
  supplier('SUP', 4),

  /// مقوت — `MQT-0001` — ★ البادئة `MQT` والمعرّف `dealer` (§2).
  dealer('MQT', 4),

  /// نوع (صنف) — `ITM-0001`.
  item('ITM', 4),

  /// مستخدم — `USR-0001`.
  user('USR', 4);

  const EntityKind(this.prefix, this.sequenceWidth);

  final String prefix;
  final int sequenceWidth;
}

/// يبني رقم مستند بالصيغة `{البادئة}-{YYYYMMDD}-{التسلسل}`.
///
/// [sequence] هو الرقم المتسلسل **الذي ولّدته السحابة** — ويبدأ من ١
/// (`naming-conventions.md` §5). ويرمي [ArgumentError] إن كان أقل من ١، لأن
/// ذلك **خلل في العدّاد لا قاعدة عمل مخالَفة**.
///
/// ⚠️ **[day] يُمرَّر من المُستدعي عمداً ولا يُقرأ من ساعة هنا** — لسببين:
/// «لا يُستخدَم وقت الجهاز في أي حقل يُخزَّن» (`coding-standards.md` §2.3)،
/// **وأي التاريخين يدخل الرقم قرارٌ يخصّ العملية المستدعية** لا الصيغة
/// (سند القبض مثلاً «يقبل سابقاً بصلاحية» — `data-dictionary.md` §`receipts`).
///
/// ★ **وعند تجاوز التسلسل عرضه المعتمد، يتّسع الرقم ولا يُقتطَع:** ٩٩٩٩ ثم
/// ١٠٠٠٠. **الاتساع مقصود** — الاقتطاع كان سينتج **رقمين متطابقين لمستندين
/// مختلفين**، وهو عطب صامت في نظام ذمم، بينما الرقم الأطول شذوذ ظاهر لا أكثر.
String formatDocumentNumber({
  required DocumentKind kind,
  required CalendarDay day,
  required int sequence,
}) {
  if (sequence < 1) {
    throw ArgumentError.value(sequence, 'sequence', 'التسلسل يبدأ من ١');
  }
  final String padded = sequence.toString().padLeft(kind.sequenceWidth, '0');
  return '${kind.prefix}-${day.format()}-$padded';
}

/// ★★ يستخرج **اليوم المحفور في رقم المستند** — أو `null` لرقمٍ غير صالح.
///
/// ★★ **ولماذا يلزم أصلاً (`WU-003`):** رصيد المخزون يُجمَع لكل
/// **(مصدر × نوع × تاريخ مخزون)**، ⟵ **فتعديلُ مستندٍ قائم أو إلغاؤه يحتاج
/// يومَه قبل أن يُقرأ المستند نفسه** — ⛔ **ولا يُؤخَذ من الجهاز.**
/// ★ **والرقم يحمله بالبناء** لأن [formatDocumentNumber] يحفره فيه،
/// **ويُتحقَّق منه بمقابلته بـ`stockDate` المخزَّن داخل المعاملة.**
///
/// ⚠️ **ويصف اليوم الذي يحمله الرقم لا تاريخ المستند بالضرورة** — راجع
/// [documentNumberDay]: **للأنواع التي تقبل تاريخاً سابقاً هما واحد**،
/// ⛔ **ولغيرها الرقم يحمل يوم الخادم** وهو نفسه تاريخ المخزون (`FR-M6-02`).
CalendarDay? parseDocumentNumberDay(String documentNumber) {
  final List<String> parts = documentNumber.trim().split('-');
  if (parts.length != 3) return null;
  final String digits = parts[1];
  if (digits.length != 8) return null;
  final int? year = int.tryParse(digits.substring(0, 4));
  final int? month = int.tryParse(digits.substring(4, 6));
  final int? day = int.tryParse(digits.substring(6, 8));
  if (year == null || month == null || day == null) return null;
  if (year < 1 || month < 1 || month > 12 || day < 1) return null;
  // ★ **الفحص قبل البناء ⛔ لا التقاطُ خطأ بعده** — `CalendarDay` يرمي
  //   [ArgumentError] لأن تمرير يومٍ غير موجود **خللٌ برمجي في المُستدعي**،
  //   ⟵ **ورقمٌ مشوَّه من الشبكة ليس خللاً برمجياً بل مُدخَلاً غير صالح**،
  //   ⛔ **فيُفحَص ويُرَدّ `null`** لا يُرمى ثم يُلتقَط.
  final DateTime probe = DateTime.utc(year, month, day);
  if (probe.year != year || probe.month != month || probe.day != day) {
    return null;
  }
  return CalendarDay(year, month, day);
}

/// هل يقبل هذا النوع تاريخاً أسبق من اليوم؟
///
/// ★ **التصنيف مشتقّ من `firestore.rules` حرفياً لا مخترَعاً** — وهي طبقة
/// التفويض الوحيدة (`ADR-0002`)، فما تقبله هو التعريف العملي للمسموح:
///
/// | النوع | شرط القاعدة | يقبل السابق؟ |
/// |---|---|:-:|
/// | `countedIntake` · `sack` | `todayStockDate()` **وحده** | ⛔ لا |
/// | `distribution` · `cashSale` · `disposal` | `todayStockDate() \|\| agedRemainderClear` | ✅ نعم |
/// | `receipt` | `notFutureDate('date')` + `receiptBackdate` | ✅ نعم |
/// | `discount` · `withdrawal` · `expense` | `notFutureDate('date')` | ✅ نعم |
/// | `stocktake` | **لا قيد تاريخ عند الإنشاء** — وجرد يوم سابق مقصود | ✅ نعم |
bool allowsBackdating(DocumentKind kind) => switch (kind) {
      DocumentKind.countedIntake || DocumentKind.sack => false,
      DocumentKind.distribution ||
      DocumentKind.cashSale ||
      // ★★ **والإتلافُ ثالثُ إجراءات تصريف المتبقي المتأخر** (`FR-M8-11`) —
      //    ⟵ **فرقمُه يحمل تاريخ المخزون لا يومَ الإدخال**، ★ **وحارسُه
      //    `agedClearanceRejection` نفسُه** (`WU-019`).
      DocumentKind.disposal ||
      DocumentKind.receipt ||
      DocumentKind.discount ||
      DocumentKind.withdrawal ||
      DocumentKind.expense ||
      DocumentKind.stocktake =>
        true,
    };

/// يختار **اليوم الذي يدخل رقم المستند** — الإجابة المعتمدة على `IQ-005`.
///
/// **القرار (2026-08-22 — الخيار ج):** «**تاريخ المستند للسندات التي تسمح
/// بتاريخ سابق، وتاريخ اليوم لما عداها**».
///
/// [documentDay] هو تاريخ المستند نفسه كما أدخله المستخدم، و[serverDay] هو
/// يوم الخادم. ⚠️ **ولا يُشتقّ أيٌّ منهما من ساعة الجهاز** — `coding-standards.md`
/// §2.3 (`GR-54` · `E-41`).
///
/// ★ **ولماذا دالة واحدة بدل شرط يتكرر عند كل مُستدعٍ:** لأن هذا **قرار
/// أعمال** لا تفصيلاً تقنياً، و`coding-standards.md` §2.2 يمنع تكراره «لا في
/// شاشة ولا مستودع ولا عملية سحابية». ونسختان منه تفترقان عند أول نوع جديد.
///
/// ⚠️ **وأثره أن عدّاد يوم سابق قد يُستهلَك بعد إغلاق ذلك اليوم** — وهو
/// مقبول لأن الرقم **«لا يُعاد استخدامه ولا يتغيّر»** (`naming-conventions.md`
/// §5)؛ فالعدّاد يواصل من حيث انتهى ولا يُعاد ترقيم شيء.
CalendarDay documentNumberDay({
  required DocumentKind kind,
  required CalendarDay documentDay,
  required CalendarDay serverDay,
}) =>
    allowsBackdating(kind) ? documentDay : serverDay;

/// يبني كود كيان بالصيغة `{البادئة}-{التسلسل}` — مثل `SRC-001` و`SUP-0001`.
///
/// يرمي [ArgumentError] إن كان [sequence] أقل من ١، ويتّسع عند التجاوز
/// بنفس منطق [formatDocumentNumber] وللسبب نفسه.
String formatEntityCode({
  required EntityKind kind,
  required int sequence,
}) {
  if (sequence < 1) {
    throw ArgumentError.value(sequence, 'sequence', 'التسلسل يبدأ من ١');
  }
  final String padded = sequence.toString().padLeft(kind.sequenceWidth, '0');
  return '${kind.prefix}-$padded';
}

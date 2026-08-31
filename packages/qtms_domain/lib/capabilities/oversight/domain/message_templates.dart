/// قوالب رسائل `M20` — ★★ **ثوابت نطاقٍ خالصة** (`FR-M20-06`).
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **`FR-M20-06` «حرجة» وتقول حرفياً:** «**قوالب الرسائل نصوص ثابتة
/// مبرمجة في التطبيق** — **لا تُقرأ من إعدادات ولا يعدّلها أحد من أي
/// واجهة**، وتغييرها يتطلب **إصدار نسخة جديدة من التطبيق**».
///
/// ★ **فالنصّ هنا ثابتُ كودٍ لا قيمةُ إعداد** — ⛔ **ولا مسار قراءةٍ له من
/// `app_settings` ولا من أي مجموعة**، ★ **والاستثناء الوحيد `{اسم المحل}`**
/// الذي **يُمرَّر** من الإعداد التأسيسي (`messaging-design.md` §3).
/// ═══════════════════════════════════════════════════════════════════════
///
/// ★★ **ومصدر النصّ قرارُ المالك في `IQ-031` (الخيار ب · 2026-08-30)** —
/// ⛔ **لا صياغةٌ من الأداة**: **المسودّة عُرضت عليه فأقرّها وحذف منها سطر
/// المصدر.** ⚠️⚠️ **وحذفُ سطر المصدر يخالف `FR-M20-09` نصّاً** — ★ **فلم
/// يُعدَّل المتطلب صامتاً**: ⟵ **`CR-004` مفتوحٌ ينتظر اعتماداً بشرياً**
/// (`UPDS-05` §4.3).
///
/// ★ **وموضعُه طبقةُ النطاق لا التطبيق** (`ADR-0012`): **دوالُّ تنسيقٍ خالصة
/// بلا استدعاء منصّة** ⟵ **تُختبَر بلا سحابة وبلا شاشة**، ⛔ **ولا نسخةَ
/// ثانيةً منها في `functions/` إن لزمت هناك يوماً.**
///
/// ★★ **وقواعد التنسيق الأربع مفروضةٌ بالبناء لا بالمراجعة:**
///   ① **فواصل الآلاف وبلا كسور للمبالغ** (`FR-M20-08`) — [formatRiyals]
///   ② **ثلاث خانات للأوزان** — [WeightKg.formatted]
///   ③ **الإجماليات تفصل الحبات عن الأوزان** (`FR-M20-10` · `GR-19`)
///   ④ **الترميز UTF-8 والأسطر الجديدة** (`FR-M20-11`) — ⛔ **بلا أي محرف
///      تحكّمٍ خفيّ**: ★ **الرسالة تعبر تطبيقاً آخر لا نتحكم في عرضه.**
library;

import '../../../core/calendar_day.dart';
import '../../../core/money.dart';
import '../../../core/quantity.dart';
import '../../inventory/domain/inventory.dart';

/// القوالب الأربعة المعتمدة — `FR-M20-07`.
///
/// ⛔ **ولا يُضاف قالبٌ هنا بلا سطرٍ في `FR-M20-07`** — نفس منطق `BR-M1-07`
/// في مفاتيح الصلاحيات: **القائمة المزدوجة تفترق عند أول إضافة.**
enum MessageTemplate {
  /// ① التوزيع فقط — **الأنواع والكميات بلا أسعار** (`messaging-design.md` §6).
  distributionOnly,

  /// ② التوزيع مع التسعير — **بضمار اليوم والرصيد السابق والحالي**.
  ///
  /// ⛔ **ولا يُختار إلا إذا كانت كل سطور المستند مسعَّرة** (`FR-M20-03` ·
  /// `AT-63`) — ★ **والحارس في طبقة العرض** لأنه قرارُ إتاحةِ خيار.
  distributionWithPricing,

  /// ③ سند قبض — **بالضمارات المسدَّدة والرصيد بعدها**.
  receiptVoucher,

  /// ④ سند خصم.
  ///
  /// ⏳★ **مكتوبٌ ومُختبَر، ⛔ وغيرُ موصولٍ بشاشة بعد** — ★ **لأن `M13`
  /// تُبنى في `WU-013`** (`IQ-031`). ⟵ **ووجودُه هنا نقلٌ لعقدٍ مكتوب**
  /// (`FR-M20-07` يسمّي أربعة) ⛔ **لا ملءٌ استباقي.**
  discountVoucher,
}

/// ★ هوية المحل كما تظهر في ترويسة كل رسالة — **الاستثناء الوحيد** في §3.
///
/// ⛔⛔★★ **ولا بصمةَ جهة التطوير في أي حقل هنا ولا في أي مخرَج من هذا
/// الملف** — `messaging-design.md` §8 · `FR-SYS-30`: **هذه مخرجات العميل
/// لعملائه هو، لا مساحة إعلانية.**
final class MessageBusiness {
  /// ينشئ هوية المحل.
  const MessageBusiness({
    required this.businessName,
    this.thousandsSeparator = ',',
  });

  /// اسم المحل — **من الإعداد التأسيسي** (`FR-M21-01`).
  final String businessName;

  /// فاصل الآلاف — **من الإعداد التأسيسي كذلك** (`app_settings`).
  ///
  /// ⚠️ **والفراغ يعني «بلا فاصل»** — ★ **قيمةٌ مسموحة في الإعداد**، ⛔ **ولا
  /// تُبدَّل بفاصلٍ افتراضي هنا.**
  final String thousandsSeparator;
}

/// سطرٌ واحد في رسالة توزيع.
final class MessageLine {
  /// ينشئ السطر.
  const MessageLine({
    required this.itemName,
    required this.quantity,
    this.unitPrice,
    this.lineTotal,
  });

  /// اسم النوع كما يقرؤه المقوت.
  final String itemName;

  /// الكمية **بوحدتها في النوع** (`GR-19`).
  final StockQuantity quantity;

  /// سعر الوحدة — و`null` تعني **«غير مسعَّر»** ⛔ **لا صفراً** (`FR-M10-08`).
  final Money? unitPrice;

  /// قيمة السطر المحسوبة في طبقة النطاق (`distributionLineTotal`).
  ///
  /// ⛔⛔ **ولا تُحسَب هنا** — ★ **الموضع الثالث للتقريب واحدٌ في النظام**
  /// (`ADR-0019`)، ⟵ **وحسابُها ثانيةً هنا نسخةٌ ثانية من معادلة مالية**
  /// ⛔ **وهو ما تمنعه قاعدة «لا تكرار لأي معادلة خارج طبقة النطاق».**
  final Money? lineTotal;
}

/// بيانات رسالة التوزيع — القالبان ① و②.
final class DistributionMessageData {
  /// ينشئ البيانات.
  const DistributionMessageData({
    required this.dealerName,
    required this.stockDate,
    required this.lines,
    required this.debtValue,
    required this.previousBalance,
    required this.currentBalance,
  });

  /// اسم المقوت المستلِم.
  final String dealerName;

  /// ★ **تاريخ المخزون لا تاريخ الإدخال** (`RISK-07` · `ADR-0006`).
  final CalendarDay stockDate;

  /// سطور التوزيعة.
  final List<MessageLine> lines;

  /// ★ ضمار اليوم — **قيمة التوزيعة** (`design-overview.md` §2.3).
  final Money debtValue;

  /// الرصيد قبل هذه التوزيعة.
  final Money previousBalance;

  /// الرصيد بعدها.
  final Money currentBalance;
}

/// سطرُ ضمارٍ مسدَّد في سند قبض.
final class SettledDebtLine {
  /// ينشئ السطر.
  const SettledDebtLine({
    required this.stockDate,
    required this.amount,
    required this.remainingAfter,
  });

  /// تاريخ مخزون الضمار المسدَّد.
  final CalendarDay stockDate;

  /// المبلغ المسدَّد على هذا الضمار.
  final Money amount;

  /// المتبقي على الضمار بعد السداد.
  final Money remainingAfter;
}

/// بيانات سند القبض — القالب ③.
final class ReceiptMessageData {
  /// ينشئ البيانات.
  const ReceiptMessageData({
    required this.dealerName,
    required this.documentNumber,
    required this.paidOn,
    required this.settledLines,
    required this.totalPaid,
    required this.balanceAfter,
  });

  /// اسم المقوت الدافع.
  final String dealerName;

  /// رقم السند — `RCP-YYYYMMDD-####`.
  final String documentNumber;

  /// تاريخ القبض.
  final CalendarDay paidOn;

  /// الضمارات المسدَّدة بهذا السند.
  final List<SettledDebtLine> settledLines;

  /// إجمالي المقبوض.
  final Money totalPaid;

  /// ★ **رصيد المقوت بعد السداد** (`FR-M12`).
  final Money balanceAfter;
}

/// بيانات سند الخصم — القالب ④.
final class DiscountMessageData {
  /// ينشئ البيانات.
  const DiscountMessageData({
    required this.dealerName,
    required this.documentNumber,
    required this.discountedOn,
    required this.discountedLines,
    required this.totalDiscount,
    required this.balanceAfter,
  });

  /// اسم المقوت.
  final String dealerName;

  /// رقم سند الخصم.
  final String documentNumber;

  /// تاريخ الخصم.
  final CalendarDay discountedOn;

  /// الضمارات المخصومة — **بنفس شكل سطر القبض**.
  final List<SettledDebtLine> discountedLines;

  /// إجمالي الخصم.
  ///
  /// ⛔⛔★★ **والخصم يُدخَل خصماً لا مبلغاً واصلاً** (`CLAUDE.md` · `M13`) —
  /// ★ **فالرسالة تسمّيه «خصم» صراحةً** ⛔ **ولا «مقبوض».**
  final Money totalDiscount;

  /// الرصيد بعد الخصم.
  final Money balanceAfter;
}

/// ★ ضمارٌ سُدِّد بسند قبض — **مدخلاتُ بناء القالب ③**.
final class ReceiptSettlementInput {
  /// ينشئ المدخلات.
  const ReceiptSettlementInput({
    required this.stockDate,
    required this.remainingBefore,
    required this.amount,
  });

  /// يوم الضمار — ⛔ **لا يوم الإدخال** (`ADR-0006`).
  final CalendarDay stockDate;

  /// المتبقي عليه **قبل** هذا السداد.
  final Money remainingBefore;

  /// المبلغ المسدَّد عليه الآن.
  final Money amount;
}

/// ★★★ يبني بيانات سند القبض — **والحساب كلُّه هنا** ⛔ **لا في شاشة**.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ★★ **و«الرصيد بعد السداد» يُقاس من الضمارات المفتوحة نفسِها** —
/// `Σ(المتبقي على كل ضمارٍ مفتوح) − Σ(المسدَّد الآن)` — ⛔ **لا من
/// `dealer_balances`.**
///
/// ⚠️⚠️ **ولماذا هذا الاختيار بالذات — وهو قرارٌ لا تفصيل:**
///   ① ★ **الضمارات المفتوحة مقروءةٌ أصلاً في شاشة القبض** (`FR-M12-05`)
///      ⟵ **فلا قراءةَ جديدة ولا مسارَ جديد.**
///   ② ⛔⛔★★ **وهي محكومةٌ بنطاق المصادر في قواعد الحماية أصلاً**، ★ **بينما
///      `dealer_balances` شرطُ قراءتها `perm('dealerBalanceView')` وحدَه بلا
///      نطاق** (`firestore.rules`) — ⟵ **فبناءُ الرقم عليها كان يُخرِج في
///      رسالةٍ مبلغاً من مصدرٍ خارج نطاق مُرسِلها** (`GR-23` · `DEBT-69`).
///   ③ ★ **والرقم يتبع فلتر السند نفسَه** — ⟵ **فسندُ مصدرٍ يعرض رصيد
///      ذلك المصدر، وسندُ «الكل» يعرض المجموع** ⛔ **بلا خلطٍ بينهما.**
///
/// ⛔ **والفائض لا يُنقِص الرصيد** (`FR-M12-11`) — ★ **نقدٌ دخل ولم يُنسَب
/// لضمارٍ بعد**: ⟵ **فيدخل «إجمالي المقبوض» ولا يخرج من «الرصيد بعد
/// السداد»**، ★ **ويُطبَّق على ضمارٍ قادم.**
/// ═══════════════════════════════════════════════════════════════════════
ReceiptMessageData buildReceiptMessageData({
  required String dealerName,
  required String documentNumber,
  required CalendarDay paidOn,
  required List<ReceiptSettlementInput> settled,
  required Money openRemainingBefore,
  Money surplusAmount = Money.zero,
}) {
  Money settledTotal = Money.zero;
  final List<SettledDebtLine> lines = <SettledDebtLine>[];
  for (final ReceiptSettlementInput input in settled) {
    settledTotal = settledTotal + input.amount;
    lines.add(
      SettledDebtLine(
        stockDate: input.stockDate,
        amount: input.amount,
        remainingAfter: input.remainingBefore - input.amount,
      ),
    );
  }
  return ReceiptMessageData(
    dealerName: dealerName,
    documentNumber: documentNumber,
    paidOn: paidOn,
    settledLines: lines,
    // ★ **والفائض جزءٌ من المقبوض** — `FR-M12-11`.
    totalPaid: settledTotal + surplusAmount,
    // ⛔ **ولا يخرج منه الفائض** — راجع الترويسة.
    balanceAfter: openRemainingBefore - settledTotal,
  );
}

/// ★ مجموع المتبقي على ضماراتٍ مفتوحة — ⛔ **ولا جمعَ في شاشة**.
Money totalOpenRemaining(Iterable<Money> remainders) {
  Money total = Money.zero;
  for (final Money remaining in remainders) {
    total = total + remaining;
  }
  return total;
}

/// ★★ الرصيد **قبل احتساب ضمار اليوم** — `الرصيد الحالي − ضمار اليوم`.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⚠️⚠️ **وافتراضٌ هندسيٌّ موثَّق لا نقلٌ حرفي — يُقال صراحةً:** `FR-M20-07`
/// يشترط أن يحمل القالب ② **«الرصيد السابق والحالي»** ⛔ **ولا يُعرِّف
/// «السابق»**. ★ **والمتاح في النظام رصيدٌ تراكميٌّ واحد** (`dealer_balances`)
/// ⛔ **لا لقطةُ أمسٍ محفوظة** — ⟵ **فالقراءة المعتمدة: «ما كان عليه قبل
/// هذه التوزيعة».**
///
/// ★ **ولماذا لم يُصعَّد بنداً `IQ`:** ⟵ **الرسالة إجراء واجهة لا يكتب شيئاً**
/// (`FR-M20-16`)، ⛔ **فخطأُ القراءة لا يُفسِد مالاً ولا مخزوناً** — ★ **والحدّ
/// الوحيد أن قبضاً وقع اليوم نفسِه يجعل «السابق» أقلَّ مما كان صباحاً**،
/// ★ **وهو أثرٌ مُعلَن مقبول** ⛔ **لا عطلٌ مكتوم.**
/// ═══════════════════════════════════════════════════════════════════════
Money balanceBeforeTodayDebt({
  required Money currentBalance,
  required Money todayDebt,
}) =>
    currentBalance - todayDebt;

// ═════════════════════════════════════════════════════════════════════════
// التنسيق — `FR-M20-08` · `FR-M20-10`
// ═════════════════════════════════════════════════════════════════════════

/// ★ المبلغ بفواصل الآلاف **وبلا كسور عشرية** — `FR-M20-08`.
///
/// ⛔★★ **ولا `NumberFormat` ولا حزمة تدويل:** ★ **`AM-003` يجعل اللغة
/// واحدةً والأرقام لاتينيةً قيمةً وحيدة ثابتة** ⟵ **فلا محلّية تُختار**،
/// ★ **و`dependency-management-policy.md` §1 البند 2 يرفض حزمةً توفّر أقل
/// من ~100 سطر بسيط.**
///
/// ★ **والسالب يُنسَّق بإشارته أمامه** — ⟵ **ورصيدٌ سالب يعني «للمقوت عندنا»**
/// ⛔ **ولا يُطوى إلى صفر ولا يُخفى.**
///
/// `1234567 ⟵ '1,234,567'` · `-2500 ⟵ '-2,500'` · `0 ⟵ '0'`.
String formatRiyals(Money amount, {String thousandsSeparator = ','}) {
  final bool negative = amount.riyals < 0;
  // ⚠️ **بلا `abs()` على الحدّ الأدنى**: `(-2^63).abs()` تفيض في Dart،
  //    ★ **والنصّ يُقلَب من التمثيل مباشرةً** فلا موضع فيضان أصلاً.
  final String digits = amount.riyals.toString().replaceFirst('-', '');
  if (thousandsSeparator.isEmpty) return negative ? '-$digits' : digits;
  final StringBuffer grouped = StringBuffer();
  for (int i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) grouped.write(thousandsSeparator);
    grouped.write(digits[i]);
  }
  return negative ? '-$grouped' : grouped.toString();
}

/// ★ الكمية بوحدتها — **«60 حبة» أو «0.500 كجم»**.
///
/// ⛔ **ولا دالة تعرض رقماً بلا وحدته** (`GR-19` · `design-overview.md` §2.11).
String formatQuantity(StockQuantity quantity) => switch (quantity) {
      PieceQuantity(:final PieceCount count) => '${count.pieces} حبة',
      WeightQuantity(:final WeightKg weight) => '${weight.formatted()} كجم',
    };

/// ★★ الإجمالي **بفصل الحبات عن الأوزان** — `FR-M20-10` · `E-31` · `GR-19`.
///
/// ⛔⛔ **ولا جمعَ بين وحدتين إطلاقاً** — ★ **والصفر يُعرَض إن كان الطرف
/// الآخر موجوداً**: ⟵ **«60 حبة + 0.000 كجم» تقول «لا وزن»**، ★ **وحذفُ
/// الطرف كان يقول «لم يُحسَب»** — ⛔ **وهما مختلفان.**
///
/// ★ **وإن خلا الطرفان معاً فالنصّ «0 حبة + 0.000 كجم»** — ⟵ **فالسطر
/// موجودٌ دائماً**، ⛔ **ولا رسالةَ بلا سطر إجمالي.**
String formatTotals(Iterable<StockQuantity> quantities) {
  int pieces = 0;
  double kilograms = 0;
  for (final StockQuantity quantity in quantities) {
    switch (quantity) {
      case PieceQuantity(:final PieceCount count):
        pieces += count.pieces;
      case WeightQuantity(:final WeightKg weight):
        kilograms += weight.kilograms;
    }
  }
  return '$pieces حبة + ${WeightKg(kilograms).formatted()} كجم';
}

// ═════════════════════════════════════════════════════════════════════════
// القوالب الأربعة — ★ **نصّها قرارُ المالك في `IQ-031`**
// ═════════════════════════════════════════════════════════════════════════

/// ★★ القالبان ① و② — **رسالة التوزيع**، مع التسعير أو بدونه.
///
/// ⛔⛔★★ **والترويسة بلا اسم المصدر** — ★ **بنصّ المالك في `IQ-031`**،
/// ⟵ **و`CR-004` يوثّق مخالفتَه لـ`FR-M20-09` وينتظر اعتماداً.**
///
/// ★ **و[MessageTemplate.distributionWithPricing] يضيف ثلاثة أشياء لا
/// واحداً** (`FR-M20-07`): **السعر وقيمة السطر** · **ضمار اليوم** ·
/// **الرصيد السابق والحالي**.
String renderDistributionMessage({
  required MessageBusiness business,
  required DistributionMessageData data,
  required MessageTemplate template,
}) {
  assert(
    template == MessageTemplate.distributionOnly ||
        template == MessageTemplate.distributionWithPricing,
    'قالب التوزيع وحده يُمرَّر هنا',
  );
  final bool priced = template == MessageTemplate.distributionWithPricing;
  final String separator = business.thousandsSeparator;
  final StringBuffer out = StringBuffer()
    ..writeln(business.businessName)
    ..writeln('تاريخ المخزون: ${data.stockDate.formatReadable()}')
    ..writeln('الأخ/ ${data.dealerName} — تفاصيل ما استلمته اليوم:')
    ..writeln();

  for (final MessageLine line in data.lines) {
    final String quantity = formatQuantity(line.quantity);
    if (!priced) {
      out.writeln('${line.itemName} — $quantity');
      continue;
    }
    final Money? unitPrice = line.unitPrice;
    final Money? lineTotal = line.lineTotal;
    if (unitPrice == null || lineTotal == null) {
      // ★ **«غير مسعَّر» نصّاً** ⛔ **لا صفراً** (`FR-M10-08` · `BR-M10-04`)
      //   — ⟵ **وصفرٌ هنا كان يقول للمقوت إن السطر مجّاني.**
      out.writeln('${line.itemName} — $quantity — غير مسعَّر');
      continue;
    }
    out.writeln(
      '${line.itemName} — $quantity × '
      '${formatRiyals(unitPrice, thousandsSeparator: separator)} = '
      '${formatRiyals(lineTotal, thousandsSeparator: separator)}',
    );
  }

  out.writeln(
    'الإجمالي: ${formatTotals(<StockQuantity>[
          for (final MessageLine line in data.lines) line.quantity,
        ])}',
  );

  if (priced) {
    out
      ..writeln('ضمار اليوم: '
          '${formatRiyals(data.debtValue, thousandsSeparator: separator)}')
      ..writeln('الرصيد السابق: '
          '${formatRiyals(data.previousBalance, thousandsSeparator: separator)}')
      ..writeln('الرصيد الحالي: '
          '${formatRiyals(data.currentBalance, thousandsSeparator: separator)}');
  }
  return out.toString().trimRight();
}

/// ★ القالب ③ — **سند القبض**.
String renderReceiptMessage({
  required MessageBusiness business,
  required ReceiptMessageData data,
}) {
  final String separator = business.thousandsSeparator;
  final StringBuffer out = StringBuffer()
    ..writeln(business.businessName)
    ..writeln('سند قبض رقم: ${data.documentNumber}')
    ..writeln('التاريخ: ${data.paidOn.formatReadable()}')
    ..writeln('الأخ/ ${data.dealerName} — تفاصيل ما سُدِّد:')
    ..writeln();

  for (final SettledDebtLine line in data.settledLines) {
    out.writeln(
      'ضمار ${line.stockDate.formatReadable()} — '
      'سُدِّد ${formatRiyals(line.amount, thousandsSeparator: separator)} — '
      'المتبقي ${formatRiyals(line.remainingAfter, thousandsSeparator: separator)}',
    );
  }

  out
    ..writeln('إجمالي المقبوض: '
        '${formatRiyals(data.totalPaid, thousandsSeparator: separator)}')
    ..writeln('الرصيد بعد السداد: '
        '${formatRiyals(data.balanceAfter, thousandsSeparator: separator)}');
  return out.toString().trimRight();
}

/// ★ القالب ④ — **سند الخصم**.
///
/// ⏳ **بلا شاشةٍ حتى `WU-013`** — راجع [MessageTemplate.discountVoucher].
String renderDiscountMessage({
  required MessageBusiness business,
  required DiscountMessageData data,
}) {
  final String separator = business.thousandsSeparator;
  final StringBuffer out = StringBuffer()
    ..writeln(business.businessName)
    ..writeln('سند خصم رقم: ${data.documentNumber}')
    ..writeln('التاريخ: ${data.discountedOn.formatReadable()}')
    ..writeln('الأخ/ ${data.dealerName} — تفاصيل الخصم:')
    ..writeln();

  for (final SettledDebtLine line in data.discountedLines) {
    out.writeln(
      'ضمار ${line.stockDate.formatReadable()} — '
      'خُصم ${formatRiyals(line.amount, thousandsSeparator: separator)} — '
      'المتبقي ${formatRiyals(line.remainingAfter, thousandsSeparator: separator)}',
    );
  }

  out
    ..writeln('إجمالي الخصم: '
        '${formatRiyals(data.totalDiscount, thousandsSeparator: separator)}')
    ..writeln('الرصيد بعد الخصم: '
        '${formatRiyals(data.balanceAfter, thousandsSeparator: separator)}');
  return out.toString().trimRight();
}

/// ★★ النسخة المختصرة — **الإجمالي والرصيد فقط** (`FR-M20-13`).
///
/// ★ **تُعرَض خياراً حين يتجاوز النصّ رسالةً واحدة** — ⛔ **ولا تُستبدَل
/// بالكاملة تلقائياً**: `FR-M20-13` يجعلها **خياراً يُسأل عنه المستخدم**،
/// ⟵ **والاختصار الصامت يُنقص معلومةً ظنّ المرسِل أنه أرسلها.**
String renderShortDistributionMessage({
  required MessageBusiness business,
  required DistributionMessageData data,
}) {
  final String separator = business.thousandsSeparator;
  return <String>[
    business.businessName,
    'تاريخ المخزون: ${data.stockDate.formatReadable()}',
    'الأخ/ ${data.dealerName}',
    'الإجمالي: ${formatTotals(<StockQuantity>[
          for (final MessageLine line in data.lines) line.quantity,
        ])}',
    'ضمار اليوم: ${formatRiyals(data.debtValue, thousandsSeparator: separator)}',
    'الرصيد الحالي: '
        '${formatRiyals(data.currentBalance, thousandsSeparator: separator)}',
  ].join('\n');
}

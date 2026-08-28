/// يوم تقويمي — **تاريخ بلا وقت وبلا منطقة زمنية**.
///
/// ★ **لماذا نوع مستقل بدل `DateTime`:** لأن `DateTime` يحمل وقتاً ومنطقة
/// زمنية، فتنسيق `YYYYMMDD` منه **يتغيّر بتغيّر المنطقة**: نفس اللحظة تُنتج
/// يومين مختلفين في جهازين. وفي هذا النظام اليوم التقويمي **مفتاح**: مفاتيح
/// `{sourceId}_{itemKey}_{stockDate}` و`{sourceId}_{date}`
/// (`naming-conventions.md` §4) والعدّاد اليومي للجواني كلها مبنية عليه —
/// فانزلاق يوم واحد **يكتب في دفتر يوم آخر بصمت**.
///
/// ⚠️ **وهذا النوع لا يحسم أي تاريخ يُستخدَم.** `coding-standards.md` §2.3:
/// «تاريخ المخزون وتاريخ الإدخال نوعان مختلفان لا يقبل أحدهما مكان الآخر»
/// (`RISK-07`) — والتمييز بينهما يُبنى في الزيادة التي تُنشئ أول دفتر، لا هنا.
library;

/// يوم تقويمي بالتقويم الميلادي.
final class CalendarDay implements Comparable<CalendarDay> {
  /// ينشئ يوماً تقويمياً، ويرفض أي تركيبة لا تمثّل يوماً حقيقياً.
  ///
  /// يرمي [ArgumentError] لأن تمرير يوم غير موجود **خلل برمجي في المُستدعي**
  /// لا قاعدة عمل مخالَفة — وقاعدة «النتيجة لا الاستثناء» تخصّ الثانية
  /// (`error-handling-strategy.md` §3 القاعدة 3).
  factory CalendarDay(int year, int month, int day) {
    if (year < 1) {
      throw ArgumentError.value(year, 'year', 'السنة يجب أن تكون موجبة');
    }
    if (month < 1 || month > 12) {
      throw ArgumentError.value(month, 'month', 'الشهر خارج المدى 1–12');
    }
    if (!_dayExists(year, month, day)) {
      throw ArgumentError.value(day, 'day', 'اليوم غير موجود في هذا الشهر');
    }
    return CalendarDay._(year, month, day);
  }

  const CalendarDay._(this.year, this.month, this.day);

  /// يشتقّ اليوم التقويمي من لحظة **بتوقيت الخادم المُحوَّل إلى UTC**.
  ///
  /// ⚠️ **لا يُستدعى بوقت الجهاز في أي مسار يُخزَّن** — `coding-standards.md`
  /// §2.3: «لا يُستخدَم وقت الجهاز في أي حقل يُخزَّن» (`GR-54` · `E-41`).
  factory CalendarDay.fromUtc(DateTime instant) {
    final DateTime utc = instant.toUtc();
    return CalendarDay._(utc.year, utc.month, utc.day);
  }

  final int year;
  final int month;
  final int day;

  /// الصيغة `YYYYMMDD` — وهي الصيغة المستخدَمة في أرقام المستندات
  /// (`naming-conventions.md` §5) وفي المفاتيح المركّبة (§4).
  String format() =>
      '${year.toString().padLeft(4, '0')}'
      '${month.toString().padLeft(2, '0')}'
      '${day.toString().padLeft(2, '0')}';

  /// ★★ **اللحظة التي تُخزَّن بها في القاعدة** — منتصف ليل هذا اليوم بالـUTC.
  ///
  /// ⚠️⚠️ **ولماذا منتصف ليل UTC تحديداً:** قواعد الحماية تُقارن تاريخ
  /// المخزون بـ`request.time.date()` (`todayStockDate()` في
  /// `firestore.rules` §4)، **و`date()` تقتطع الطابع إلى منتصف ليل UTC**.
  /// ⟵ ★ **فأيّ لحظةٍ أخرى تجعل القيمة المخزَّنة لا تساوي ما تتوقّعه
  /// القاعدة** ⛔ **فتُرفَض كتابةٌ صحيحة أو — أسوأ — تُقبَل بيومٍ مزاح.**
  ///
  /// ★ **وهذا هو الموضع الوحيد الذي يُترجم اليوم التقويمي إلى لحظة** —
  /// ⛔ **ولا يُبنى `DateTime` ليومٍ مخزني في أي مكان آخر**
  /// (`coding-standards.md` §2.2: مصدر حقيقة واحد).
  DateTime asUtcMidnight() => DateTime.utc(year, month, day);

  /// ★★ يقرأ يوماً مكتوباً بصيغة `YYYYMMDD` — ⛔ **ويُرجِع `null` لغير الصالح**.
  ///
  /// ⚠️⚠️ **ولماذا هنا لا في قارئ السجل:** [format] تعيش في هذا الملف،
  /// ⟵ **وقارئٌ يفكّ الصيغة بنفسه يصير مصدرَ حقيقةٍ ثانياً لها** فيفترق
  /// عنها عند أول تغيير (`coding-standards.md` §2.2).
  ///
  /// ★ **وأول مُستهلِك له سجل التدقيق** (`WU-008`): `AuditEntry.toFields`
  /// تكتب `stockDate` **نصّاً بهذه الصيغة** ⛔ **لا طابعاً زمنياً** — ⟵
  /// **فقراءتُه تحتاج نظيرَ الكاتب حرفياً.**
  ///
  /// ⛔ **والغياب نتيجةٌ لا استثناء:** قيدٌ قديم بلا `stockDate` **حالةٌ
  /// طبيعية** (الحقل اختياري في `data-dictionary.md` §5)، ⟵ **ورميُ
  /// استثناءٍ عليه كان سيُسقِط شاشةَ عرضٍ كاملة.**
  static CalendarDay? tryParseCompact(String value) {
    final String trimmed = value.trim();
    if (trimmed.length != 8) return null;
    final int? year = int.tryParse(trimmed.substring(0, 4));
    final int? month = int.tryParse(trimmed.substring(4, 6));
    final int? day = int.tryParse(trimmed.substring(6, 8));
    if (year == null || month == null || day == null) return null;
    // ⛔ **والفحص بنفس حارس المُنشئ لا بنسخةٍ منه** ([_dayExists]) — ⟵ **فلا
    //    يقبل هذا المسار يوماً يرفضه ذاك**، ★ **ولا يُلتقَط `Error` بديلاً
    //    عن الفحص** (`avoid_catching_errors`): ⛔ **الاستثناء إشارةُ خللٍ
    //    برمجي**، ★ **والمُدخَل المشوَّه هنا حالةٌ متوقَّعة لا خلل.**
    if (year < 1 || month < 1 || month > 12) return null;
    if (!_dayExists(year, month, day)) return null;
    return CalendarDay(year, month, day);
  }

  /// ★ اليوم السابق — **يوماً تقويمياً لا لحظة**.
  ///
  /// ⚠️ **ولماذا هنا لا في المُستدعي:** حساب «أمس» يعبر حدود الشهر والسنة
  /// **والسنة الكبيسة**، ⟵ **ونسخةٌ يدوية في شاشةٍ تُخطئ في 29 فبراير**
  /// أو في أول الشهر (`coding-standards.md` §2.2).
  ///
  /// ⛔★★ **ولا يُستعمل في مفتاحٍ يُكتب:** كل ما يُخزَّن **يومُه من المنصّة**
  /// (`GR-54` · `E-41`) — ★ **وهذا للقراءة والعرض وحدهما** (مثال: «نسخ
  /// أسعار أمس» — `FR-M9-13`).
  CalendarDay previousDay() {
    // ★ **عبر [asUtcMidnight] وحدها** — ⛔ **ولا `DateTime` يُبنى هنا**:
    //   فتبقى الترجمة بين اليوم واللحظة في موضعٍ واحد.
    final DateTime previous =
        asUtcMidnight().subtract(const Duration(days: 1));
    return CalendarDay.fromUtc(previous);
  }

  @override
  int compareTo(CalendarDay other) {
    if (year != other.year) return year.compareTo(other.year);
    if (month != other.month) return month.compareTo(other.month);
    return day.compareTo(other.day);
  }

  @override
  bool operator ==(Object other) =>
      other is CalendarDay &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => format();
}

/// ★ هل يمثّل الثلاثي يوماً حقيقياً؟ — ⛔ **ولا جدول أيامٍ مكتوب يدوياً.**
///
/// بناء تاريخ ثم مقارنته يكشف اليوم الزائد في الشهر (مثل 31 فبراير)،
/// ★ **و`DateTime.utc` وحده يُستخدَم فلا أثر لمنطقة زمنية.**
///
/// ⚠️ **ودالةٌ واحدة يشاركها المُنشئ و[CalendarDay.tryParseCompact]** —
/// ⟵ **فلا مسارَ يقبل ما يرفضه الآخر** (`coding-standards.md` §2.2).
bool _dayExists(int year, int month, int day) {
  final DateTime probe = DateTime.utc(year, month, day);
  return probe.year == year && probe.month == month && probe.day == day;
}

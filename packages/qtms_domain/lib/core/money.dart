/// المال — ★ **عدد صحيح بالريال في كل طبقة** (`ADR-0015`).
///
/// ⛔ **لا فاصلة عائمة ولا نوع عشري ولا تخزين بأصغر وحدة (فِلس)** —
/// ★ **والمبلغ المخزون هو المعروض حرفياً بلا تحويل** (القاعدتان 1 و2).
///
/// ★ **ولماذا نوعٌ لا `int` عارياً:** `coding-standards.md` §2.1 يجعل «مبلغ
/// بأي نوع غير `int`» **رفضاً تلقائياً في المراجعة**، ⟵ **والنوع يجعل
/// المخالفة خطأ تصريف لا ملاحظة مراجعة**. ★ **ويمنع بنيوياً أن يُجمع مبلغ
/// بكمية** — وهو ما يحرسه `GR-19` نصّاً وهذا الملف بناءً.
library;

/// مبلغ بالريال اليمني — **عدد صحيح دائماً** (`A-02` · `ADR-0015`).
extension type const Money(int riyals) implements Object {
  /// الصفر — بداية كل تجميع.
  static const Money zero = Money(0);

  /// ★ **التقريب الحسابي لأقرب ريال** — ⛔ **ولا يُستدعى إلا في مواضعه
  /// الثلاثة المعلومة وحدها:** ① **ضريبة الجونية** · ② **متوسط سعر الكيلو**
  /// · ★ ③ **قيمة سطرٍ وزنيّ** (`ADR-0019`)
  /// (`design-overview.md` §2.11 · `ADR-0015` القاعدتان 4 و5).
  ///
  /// ⚠️★★ **والموضع ③ أُضيف في 2026-08-27 بـ`ADR-0019`** (قرار المالك في
  /// `IQ-026` — الخيار أ): **الكمية بالكيلوجرام × سعر الوحدة الصحيح** في
  /// **التوزيع (`M10`) والبيع النقدي (`M11`) والسحبيات والخرجيات (`M22`)**.
  /// ⛔ **والسطر المعدود لا يمرّ به إطلاقاً** — `صحيح × صحيح = صحيح`.
  /// ⛔ **ولم يُعدَّل `ADR-0015`** — **الإحصاء وحده توسَّع، والقاعدة 5 نفسها
  /// هي المطبَّقة** (UPDS-05 §4.1).
  ///
  /// `617.25 ⟵ 617` · `617.50 ⟵ 618`.
  ///
  /// ⛔ **ويرفض السالب رفضاً صريحاً** — `ADR-0015` القاعدة 8: الموضعان **لا
  /// ينتجان سالباً**، ★ **وأي موضع تقريب جديد يُنتج سالباً يلزمه قرار صريح
  /// قبل بنائه ولا يُخمَّن.** ⟵ **فالرمي هنا حارسٌ للقرار لا تشدّد.**
  factory Money.rounded(double value) {
    if (value.isNaN || value.isInfinite) {
      throw ArgumentError.value(value, 'value', 'قيمة غير عددية');
    }
    if (value < 0) {
      throw ArgumentError.value(
        value,
        'value',
        'التقريب على سالب يحتاج قراراً صريحاً — ADR-0015 القاعدة 8',
      );
    }
    // ⟵ `round()` في Dart تُقرِّب النصف بعيداً عن الصفر، والمُدخَل موجب
    //    قطعاً بالحارس أعلاه — فهي «≥ 0.5 لأعلى» حرفياً.
    return Money(value.round());
  }

  /// المبلغ من نصّ **يرفض الكسر ولا يُقرِّبه** — `ADR-0015` القاعدة 3.
  ///
  /// يُرجِع `null` للمُدخَل غير الصالح، ⟵ **وطبقة العرض تُظهر
  /// `ERR_MONEY_001`** ⛔ **ولا تُقرِّب صامتاً ما كتبه إنسان.**
  static Money? tryParseInput(String input) {
    final String trimmed = input.trim();
    if (trimmed.isEmpty) return null;
    final int? parsed = int.tryParse(trimmed);
    return parsed == null ? null : Money(parsed);
  }

  Money operator +(Money other) => Money(riyals + other.riyals);
  Money operator -(Money other) => Money(riyals - other.riyals);

  /// المبلغ مضروباً في **عدد صحيح** — ⛔ ولا ضرب في كسر: الكسر لا يُنتَج إلا
  /// في موضعي التقريب، وهما يمرّان بـ[Money.rounded].
  Money operator *(int factor) => Money(riyals * factor);

  bool operator <(Money other) => riyals < other.riyals;
  bool operator >(Money other) => riyals > other.riyals;
  bool operator <=(Money other) => riyals <= other.riyals;
  bool operator >=(Money other) => riyals >= other.riyals;

  bool get isZero => riyals == 0;
  bool get isNegative => riyals < 0;
}

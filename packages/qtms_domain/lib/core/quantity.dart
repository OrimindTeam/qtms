/// الكميات — ★ **كل كمية تحمل وحدتها معها في النوع** (`GR-19`).
///
/// ★ **والقاعدة المفروضة بالبناء لا بالمراجعة:** ⛔ **لا توجد دالة تجمع
/// كميتين مختلفتي الوحدة أصلاً** — `design-overview.md` §2.11: «**لا تُجمع
/// كميات الحبات مع الأوزان أبداً — إجماليان منفصلان دائماً**».
/// ⟵ **فنوعان منفصلان بلا أي عملية بينهما، والخلط خطأ تصريف.**
///
/// ⚠️ **والأوزان ليست مبالغ** (`ADR-0015` القاعدة 9) — ⛔ **فلا يسري عليها
/// قرار العدد الصحيح**، وتبقى عشرية كما هي (`design-overview.md` §2.11).
library;

/// كمية معدودة بالحبّة — **عدد صحيح، والكسور مرفوضة** (`C-22` · `BR-M6-06`).
extension type const PieceCount(int pieces) implements Object {
  static const PieceCount zero = PieceCount(0);

  /// كمية معدودة من نصّ — ⛔ **يرفض الكسر** (`BR-M6-06`: «الكسور تُرفَض في
  /// النوع نفسه لا في التحقق فقط»)، ويُرجِع `null` لغير الصالح.
  static PieceCount? tryParseInput(String input) {
    final String trimmed = input.trim();
    if (trimmed.isEmpty) return null;
    final int? parsed = int.tryParse(trimmed);
    return parsed == null ? null : PieceCount(parsed);
  }

  PieceCount operator +(PieceCount other) => PieceCount(pieces + other.pieces);
  PieceCount operator -(PieceCount other) => PieceCount(pieces - other.pieces);

  bool operator <(PieceCount other) => pieces < other.pieces;
  bool operator >(PieceCount other) => pieces > other.pieces;

  bool get isZero => pieces == 0;
  bool get isNegative => pieces < 0;
}

/// كمية وزنية بالكيلوجرام — **بثلاث خانات عشرية** (`design-overview.md` §2.11).
///
/// ⚠️ **والقيمة تُحفَظ كما هي ولا تُقرَّب عند البناء** — `ADR-0015` القاعدة 4:
/// **التقريب في نهاية سلسلة الحساب لا في كل خطوة**. ★ **والثلاث خانات قاعدة
/// عرض وتخزين**، وتُطبَّق بـ[formatted] عند الإظهار.
extension type const WeightKg(double kilograms) implements Object {
  static const WeightKg zero = WeightKg(0);

  /// عدد الخانات العشرية المعتمد للكيلوجرام.
  static const int decimals = 3;

  /// وزن من نصّ — يقبل الكسر (بخلاف المعدود)، ويُرجِع `null` لغير الصالح.
  static WeightKg? tryParseInput(String input) {
    final String trimmed = input.trim();
    if (trimmed.isEmpty) return null;
    final double? parsed = double.tryParse(trimmed);
    if (parsed == null || parsed.isNaN || parsed.isInfinite) return null;
    return WeightKg(parsed);
  }

  WeightKg operator +(WeightKg other) => WeightKg(kilograms + other.kilograms);
  WeightKg operator -(WeightKg other) => WeightKg(kilograms - other.kilograms);

  bool operator <(WeightKg other) => kilograms < other.kilograms;
  bool operator >(WeightKg other) => kilograms > other.kilograms;

  bool get isNegative => kilograms < 0;

  /// النصّ المعروض بثلاث خانات — ⛔ **بلا تقريب للقيمة المخزَّنة نفسها.**
  String formatted() => kilograms.toStringAsFixed(decimals);
}

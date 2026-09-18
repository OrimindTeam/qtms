/// ★★★ **الصفرُ الابتدائي في حقلٍ رقمي** — `AM-027` ① (2026-09-17).
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **العطلُ الذي يعالجه — مقيسٌ في استعمال المالك لا مفترَض:**
///
/// ★ **حقلا «وزن الثلج» و«وزن السكرب» يبدآن بـ`0`** ⟵ **قيمةٌ ابتدائيةٌ
/// مقصودة**: ★ **فالميزانُ الحيُّ يقرأ صفراً لا فراغاً.** ⛔⛔ **لكنّ
/// `TextEditingController(text: …)` يترك التحديدَ عند `offset: -1`**:
/// ⟵ **فيقع المؤشّرُ قبل الصفر عند أول لمسة** ⟹ ⛔ **ومن أراد `4` كيلو
/// حصل على `40`**، ★ **فصار يحذف الصفرَ يدوياً في كل مرة.**
///
/// ✅ **والعلاج: حارسٌ على *التركيز* لا على الكتابة** — ★ **يعمل مرتين لا
/// أكثر: لحظةَ الدخول ولحظةَ الخروج**: ⟵ **وهما حرفياً لحظتا «القيمة
/// الابتدائية»** ⛔ **لا لحظاتُ الكتابة.**
///
/// ⛔⛔ **ولماذا لا `TextInputFormatter`:** ★ **المُنسِّقُ يعمل على كل ضغطة
/// مفتاح** ⟹ **فيحكم على رقمٍ *أثناء* كتابته** — ⛔ **ورقمٌ يُعدَّل تحت
/// الإصبع أسوأ من صفرٍ يُحذَف باليد.**
/// ═══════════════════════════════════════════════════════════════════════
///
/// ⛔⛔★★ **والشرطُ تطابقٌ تامٌّ مع `'0'`** — ⛔ **لا «يبدأ بصفر»**: ⟵ **فرقمٌ
/// كتبه المستخدم فعلاً (`0.5` · `0`) لا يُمَسّ بعد أن يكتبه**، ★ **والحارسُ
/// لا يعمل إلا على ما لم تلمسه يدٌ بعد.**
library;

import 'package:flutter/material.dart';

/// ★ نصُّ القيمة الابتدائية — ⛔ **ولا يُحفَر في موضعين.**
const String zeroPlaceholderText = '0';

/// ★★ نصُّ الحقل **عند اكتساب التركيز** — ⟵ **الصفرُ الابتدائي وحدَه يُفرَّغ.**
///
/// ⛔ **وأيُّ نصٍّ آخر يعود كما هو** — ★ **دالّةٌ نقيّةٌ تُختبَر وحدَها.**
String zeroPlaceholderOnFocus(String text) =>
    text == zeroPlaceholderText ? '' : text;

/// ★★ نصُّ الحقل **عند فقد التركيز** — ⟵ **والفراغُ يعود صفراً.**
///
/// ★ **فالحالةُ الساكنة لا تتغيّر عمّا كانت عليه قبل `AM-027`** — ⛔ **ولا
/// يُترك الحقلُ خاوياً بعد أن كان يعرض قيمةً.**
String zeroPlaceholderOnBlur(String text) =>
    text.trim().isEmpty ? zeroPlaceholderText : text;

/// ★★★ حقلٌ رقميٌّ **قيمتُه الابتدائية صفرٌ لا يلتصق بما يُكتب بعده**.
///
/// ⛔ **ولا نسخةَ ثانيةً من هذا السلوك في أي شاشة** — `design-system.md` §8
/// المحظور 11: ★ **كلُّ حقلٍ يبدأ بصفرٍ ابتدائيٍّ يستدعي هذا المكوّن.**
class QtmsZeroPlaceholderField extends StatefulWidget {
  /// ينشئ الحقل.
  const QtmsZeroPlaceholderField({
    required this.controller,
    required this.label,
    required this.onChanged,
    this.keyboardType,
    super.key,
  });

  /// ★ المتحكّم — ⛔ **يملكه المُنادي ويتخلّص منه**: ⟵ **فالقيمةُ حالةُ
  /// النموذج لا حالةُ الحقل.**
  final TextEditingController controller;

  /// تسمية الحقل.
  final String label;

  /// ★ يُستدعى مع كل تغيّرٍ في النصّ — **بما فيه تغيّرُ الحارس نفسِه**:
  /// ⟵ **فالحاسبةُ الحيّة فوقه تبقى مطابقةً لما يُعرَض.**
  final VoidCallback onChanged;

  /// نوع لوحة المفاتيح.
  final TextInputType? keyboardType;

  @override
  State<QtmsZeroPlaceholderField> createState() =>
      _QtmsZeroPlaceholderFieldState();
}

class _QtmsZeroPlaceholderFieldState extends State<QtmsZeroPlaceholderField> {
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _focus
      ..removeListener(_onFocusChanged)
      ..dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    final TextEditingController controller = widget.controller;
    final String next = _focus.hasFocus
        ? zeroPlaceholderOnFocus(controller.text)
        : zeroPlaceholderOnBlur(controller.text);
    if (next == controller.text) return;
    // ★ **والمؤشّرُ إلى آخر النصّ** — ⟵ **فالكتابةُ تُكمِل ولا تسبق.**
    controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) => TextField(
        controller: widget.controller,
        focusNode: _focus,
        keyboardType: widget.keyboardType,
        decoration: InputDecoration(labelText: widget.label),
        onChanged: (String _) => widget.onChanged(),
      );
}

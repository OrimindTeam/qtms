/// ★★ صفُّ مفتاح-قيمة — **عقدُ `design-system.md` §6.د حرفياً**.
///
/// ★ **العقد:** **المفتاح `textSecondary` عند البداية · والقيمة `textPrimary`
/// بوزن 600 عند النهاية** · ★ **وخيار `numeric` يفعّل الأرقام الجدولية
/// ويثبّت اتجاه القيمة.**
///
/// ⛔⛔★★ **ولماذا مكوّنٌ عام لا صفٌّ محلي في كل شاشة:** ★ **§5 البند 3
/// («مكوّن واحد لكل غرض») و§8 المحظور الحادي عشر** — ⟵ **وصفوفٌ محلية في
/// خمس شاشات تفترق في الحشو والوزن والمحاذاة** ⛔ **فتبدو الشاشاتُ من
/// تطبيقين** (`ui-guidelines.md` §7 السؤال الأول).
///
/// ⚠️ **وتثبيتُ اتجاه القيمة الرقمية ليس زينة** — `rtl-ltr-guidelines.md`:
/// ★ **رقمٌ لاتيني داخل جملةٍ عربية يتقلّب موضعُه بلا تثبيت**، ⟵ **فيُقرأ
/// «-2,500» أحياناً «2,500-»** ⛔ **وهي إشارةُ رصيدٍ لا زخرفة.**
library;

import 'package:flutter/material.dart';

import '../design/design_tokens.dart';

/// صفُّ مفتاح-قيمة.
class QtmsKeyValueRow extends StatelessWidget {
  /// ينشئ الصف.
  const QtmsKeyValueRow({
    required this.label,
    required this.value,
    this.numeric = false,
    super.key,
  });

  /// المفتاح — **عند بداية السطر**.
  final String label;

  /// القيمة **نصّاً جاهزاً** — ⛔ **ولا تُنسَّق هنا** (§5.1).
  final String value;

  /// ★ هل القيمة رقم؟ — **يفعّل الأرقام الجدولية ويثبّت الاتجاه**.
  final bool numeric;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          vertical: Spacing.space4,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Text(
                label,
                style: TypeScale.bodyMd
                    .copyWith(color: SemanticColors.textSecondary),
              ),
            ),
            const SizedBox(width: Spacing.space12),
            if (numeric)
              // ★★ **اتجاهٌ مثبَّت للقيمة الرقمية وحدها** — راجع ترويسة الملف.
              Directionality(
                textDirection: TextDirection.ltr,
                child: Text(
                  value,
                  style: TypeScale.numericSm
                      .copyWith(color: SemanticColors.textPrimary),
                ),
              )
            else
              Flexible(
                child: Text(
                  value,
                  style: TypeScale.bodyMd.copyWith(
                    color: SemanticColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.end,
                ),
              ),
          ],
        ),
      );
}

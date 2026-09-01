/// ★★ **الصورة الرمزية** — `design-system.md` §6.د.
///
/// ★ **أحرفٌ أولى على خلفيةٍ مشتقّة من تجزئة الاسم عبر العائلات الخمس**،
/// ★ **والتجزئة ثابتةٌ بين التشغيلات** — ⟵ **فيتعرّف المستخدم على بطاقته
/// باللون قبل أن يقرأ الاسم**، ⛔ **ولو تغيّر اللون كل تشغيلٍ لسقطت الفائدة.**
///
/// ⛔⛔★★ **والحرفُ الأول وحده** (`AM-008` ① و④) — ⛔ **لا حرفان ولا صورة.**
///
/// ⚠️ **واسمٌ فارغٌ حالةٌ واقعية لا عطل:** ★ **حسابٌ أُنشئ ولم يُكمَل اسمُه**
/// — ⟵ **ويُعرَض بعلامة استفهام**، ⛔ **لا بمربّعٍ فارغ يُقرأ خللاً في الرسم.**
library;

import 'package:flutter/material.dart';

import '../design/design_tokens.dart';
import '../design/theme_extensions.dart';

/// صورة رمزية دائرية بالحرف الأول.
class QtmsAvatar extends StatelessWidget {
  /// ينشئ الصورة الرمزية.
  const QtmsAvatar({
    required this.name,
    this.size = Sizes.avatarSm,
    super.key,
  });

  /// الاسم الذي يُشتقّ منه الحرف واللون.
  final String name;

  /// طول قطر الدائرة.
  final double size;

  /// ★ الحرف الأول غير الفراغي — ⛔ **و«؟» لاسمٍ فارغ.**
  static String initialOf(String name) {
    for (final int rune in name.runes) {
      final String glyph = String.fromCharCode(rune);
      if (glyph.trim().isNotEmpty) return glyph;
    }
    return '؟';
  }

  /// ★★ العائلة المشتقّة من الاسم — **تجزئةٌ ثابتة** (§6.د).
  ///
  /// ⛔ **ولا `hashCode`:** ★ **تجزئة السلاسل في Dart قد تختلف بين تشغيلين**،
  /// ⟵ **فلونُ الاسم نفسِه كان سيتبدّل**، ⛔ **وهو ما يمنعه العقد نصّاً.**
  static int familyIndexOf(String name) {
    int sum = 0;
    for (final int rune in name.runes) {
      sum = (sum + rune) % 5;
    }
    return sum;
  }

  @override
  Widget build(BuildContext context) {
    final QtmsCategoryColors families = context.categories;
    final ColorTriad triad = <ColorTriad>[
      families.identity,
      families.masterData,
      families.inventory,
      families.receivables,
      families.cash,
    ][familyIndexOf(name)];

    return Semantics(
      // ★ **قارئ الشاشة يسمع الاسم كاملاً** — ⛔ **لا حرفاً مجرَّداً.**
      label: name.trim().isEmpty ? 'مستخدم بلا اسم' : name,
      child: ExcludeSemantics(
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: triad.soft,
            shape: BoxShape.circle,
            border: Border.all(color: triad.border, width: Sizes.borderWidth),
          ),
          child: Text(
            initialOf(name),
            style: TypeScale.titleSm.copyWith(color: triad.ink),
          ),
        ),
      ),
    );
  }
}

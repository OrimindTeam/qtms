/// هوية المنتج البصرية — ★ **مصدر حقيقة واحد للاسم الظاهر ولشعار العميل**
/// (`AM-002` · `docs/19-assets/brand-guidelines.md` §3.1).
///
/// ★ **ولماذا ملفٌ مستقل لا قيمتان في شاشة:** ★ **هذه حرفياً قاعدة التوكنز
/// نفسها** — «الشاشات تستدعي الطبقة الدلالية ولا تلمس الأولية» — منقولةً إلى
/// الهوية. ★ **والقيمة المكرَّرة في عشرة مواضع تفترق عن نفسها عند أول تغيير.**
///
/// ⛔ **ولا علاقة لهذا الملف ببصمة جهة التطوير إطلاقاً** — تلك مصدرها
/// `assets/branding/developer-identity.json` وحده، ★ **ومواضعها الخمسة
/// محصورة في `docs/19-assets/developer-identity.md` §2** ⛔ **وليست منها
/// أيقونة التطبيق ولا شاشة البداية ولا شاشة الدخول** (§5 البندان 2 و3).
library;

import 'package:flutter/material.dart';

import 'design_tokens.dart';

/// الاسم الظاهر للتطبيق — ★ **هوية العميل حصراً** (`RD-002` بتنقيح `AM-002`).
///
/// ★ **وهو نفسه نصّاً** `android:label` في
/// `android/app/src/main/res/values/strings.xml` — ⛔ **وافتراقهما يعني اسمين
/// للتطبيق الواحد**: هذا في مبدّل المهام، وذاك على شاشة الجهاز.
const String appDisplayName = 'وكالة محمد المحامي';

/// مسار شعار العميل داخل الحزمة.
///
/// ★ **الطبقة الأمامية وحدها** — شفافةُ الخلفية، ★ **فتُركَّب على خلفية
/// الشاشة أياً كانت** ⛔ **بدل أن تحمل مربعاً أبيض مقصوصاً معها.**
///
/// ⛔ **ولا تُستورَد أيقونة المتجر هنا:** بلا شفافية بالتصميم (`RF-001`)،
/// ★ **ووجهتها المتجر لا الواجهة.**
const String brandLogoAsset = 'assets/icons/app-icon-foreground.png';

/// شعار العميل كعنصر واجهة — ★ **الموضع الوحيد الذي يعرف مسار الأصل.**
///
/// ★ **يُستعمَل في شاشة البداية وشاشة الدخول** (`ui-guidelines.md` نمط 8
/// و8-أ). ⛔ **ولا يُلَوَّن ولا يُقَصّ ولا يُشَوَّه**: هوية العميل تُعرَض كما
/// سُلِّمت (`brand-guidelines.md` §3).
class BrandLogo extends StatelessWidget {
  const BrandLogo({this.size = defaultSize, super.key});

  /// المقاس الافتراضي — ★ **ضِعف مقاس الرمز المحايد السابق (56)** لأن الشعار
  /// يحمل نصّاً يجب أن يُقرأ، ⛔ **لا رمزاً مجرّداً يكفيه التلميح.**
  static const double defaultSize = 112;

  /// طول ضلع المربع المرسوم فيه الشعار.
  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      brandLogoAsset,
      width: size,
      height: size,
      // ★ `contain` يحفظ النسبة — ⛔ ولا `cover` فتُقتطع أطراف النص.
      fit: BoxFit.contain,
      // ★ قارئ الشاشة يسمع اسم المنتج لا اسم ملف (`a11y-checklist.md`).
      semanticLabel: appDisplayName,
      // ⚠️ ★ وتعذُّر فكّ الأصل لا يُسقط الشاشة كلها: الشعار زينةُ هوية،
      //    ★ **والدخول يبقى ممكناً بدونه** — ⛔ ولا رمز بديل يوهم بهوية أخرى.
      errorBuilder: (BuildContext context, Object error, StackTrace? stack) =>
          SizedBox(height: size),
    );
  }
}

/// ★ فاصل بصري تحت الشعار — ★ **مقاس واحد لا يُعاد تقديره في كل شاشة.**
const double brandLogoGap = Spacing.space16;

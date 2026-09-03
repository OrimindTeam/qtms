/// ★★★ **طبقةُ الوصول الوحيدة لبصمة جهة التطوير** — `FR-SYS-29`.
///
/// ════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **ولا قيمةَ تواصلٍ محفورةٌ نصياً في أي شاشة أو مكوّن أو اختبار**
/// (`developer-identity.md` §6 · `developer-identity-placement.md` §6):
/// ★ **مصدرُ الحقيقة الوحيد داخل المشروع** [developerIdentityAssetPath]،
/// ⟵ **وكلُّ موضعٍ يقرأ منه عبر هذا الملف وحدَه.**
///
/// ★★ **وهذه حرفياً قاعدةُ التوكنز نفسُها** («**الشاشةُ تستدعي الطبقةَ
/// الدلالية ولا تلمس الأولية**») منقولةً إلى البصمة — ★ **وسببُها واحد:**
/// ⟵ **القيمةُ المكرَّرة في عشرة مواضع تفترق عن نفسها عند أول تغيير**،
/// ⛔ **ومعلوماتُ التواصل متغيّرةٌ بطبيعتها** (`phone` أكثرُها تغيّراً).
/// ════════════════════════════════════════════════════════════════════
///
/// ⚠️★★ **ووضعُ الظهور `discreet`** (`DI-001`) — ★ **ومواضعُه الخمسة
/// محصورةٌ في `docs/19-assets/developer-identity.md` §2**، ⛔ **ولا موضعَ
/// خارجها ولو بدا مناسباً.**
library;

import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

/// ★ **مسارُ مصدر الحقيقة داخل المشروع** — الطبقة 2 من الطبقات الثلاث
/// (`developer-identity-placement.md` §6).
///
/// ⛔ **ولا يُقرأ هذا المسار من شاشةٍ مباشرةً** — [DeveloperIdentity] وحدها.
const String developerIdentityAssetPath =
    'assets/branding/developer-identity.json';

/// ★ **مجلّدُ أصول البصمة داخل المشروع.**
///
/// ⛔⛔★★ **ولماذا يُعاد بناءُ المسار هنا ولا يُؤخَذ من `logo_files` كما هو:**
/// ★ **قيمُ `logo_files` نسبيةٌ إلى جذر المخزن المركزي** (`assets/logo-mark.png`)
/// ⛔ **لا إلى جذر المشروع** — ⟵ **فأخذُها حرفياً يُنتج مساراً لا وجودَ له
/// في حزمة الأصول**، ★ **والاسمُ الأخيرُ وحدَه هو المشترَك بين الطبقتين.**
const String _brandingAssetDir = 'assets/branding';

/// ★★★ **بصمةُ جهة التطوير — قيمٌ مقروءةٌ من مصدر الحقيقة الوحيد.**
///
/// ⛔ **ولا قيمةَ افتراضيةً لأي حقلٍ إلزامي** — ★ **الغيابُ خطأُ تحميلٍ
/// صريح** ⛔ **لا قيمةٌ مخترَعة**: ⟵ **ومنتَجٌ يعرض «`<اسم المطور>`» حرفياً
/// هو بالضبط الاختلاقُ الذي تمنعه هذه القاعدة.**
class DeveloperIdentity {
  /// ينشئ البصمة بقيمها.
  const DeveloperIdentity({
    required this.developerName,
    required this.website,
    required this.email,
    required this.attributionAr,
    required this.copyrightStartYear,
    required this.markLogoAssetPath,
    this.phone,
    this.phoneIsWhatsapp = false,
    this.social = const <String, String>{},
  });

  /// ★ الاسمُ المعروض لجهة التطوير — أساسُ كل نصِّ إسناد.
  final String developerName;

  /// ★ الموقعُ الإلكتروني.
  final String website;

  /// ★ بريدُ التواصل.
  final String email;

  /// ★ نصُّ الإسناد العربي — ★ **يُولَّد من الاسم إن غاب.**
  final String attributionAr;

  /// ★ سنةُ بدء الحقوق — أساسُ سطر الحقوق.
  final int copyrightStartYear;

  /// ★ **مسارُ شعار العلامة داخل حزمة أصول المشروع.**
  ///
  /// ⛔ **العلامةُ (`mark`) لا الشعارُ الكامل** — ★ **قاعدةُ التبعية البصرية
  /// تشترط `≤ 40٪` من شعار العميل** (`developer-identity.md` §4)، ⟵ **والعلامةُ
  /// المربّعة تحتمل التصغير** ⛔ **والشعارُ الكامل يصير غيرَ مقروءٍ عنده.**
  final String markLogoAssetPath;

  /// هاتف/واتساب — اختياري.
  final String? phone;

  /// هل [phone] رقمُ واتساب؟ — يحدد شكلَ الرابط المولَّد.
  final bool phoneIsWhatsapp;

  /// خريطةُ التواصل الاجتماعي — **مرنة**: منصةٌ جديدة بمفتاحٍ جديد
  /// ⛔ **بلا تعديل هذا الملف.**
  final Map<String, String> social;

  /// ★★ **سطرُ الحقوق** — يُبنى من السنة والاسم (الموضع 5).
  ///
  /// ★ **وسنةُ النهاية تُمرَّر ولا تُقرأ من ساعة الجهاز هنا:** ⛔ **مكوّنُ
  /// عرضٍ لا يقرّر** (`design-system.md` §5.1)، ⟵ **ولأن اختبارَ سطرٍ يعتمد
  /// ساعةَ التشغيل يصير أخضرَ اليومَ وأحمرَ في أول يناير.**
  String copyrightLine(int currentYear) {
    final String years = currentYear > copyrightStartYear
        ? '$copyrightStartYear–$currentYear'
        : '$copyrightStartYear';
    return '© $years $developerName';
  }

  /// ★ يبني البصمة من خريطة JSON مفكوكة.
  ///
  /// ⛔⛔★★ **وقيمةٌ على شكل `<...>` تُعامَل غائبةً لا مملوءة**
  /// (`developer-identity-placement.md` §8) — ★ **وبدون هذا يمرّ ملفٌ قالبيٌّ
  /// كأنه صالح فيُبنى منتَجٌ يحمل «`<اسم المطور>`» حرفياً.**
  factory DeveloperIdentity.fromJson(Map<String, dynamic> json) {
    final String name = _requireField(json, 'developer_name');
    final Map<String, dynamic> logos =
        (json['logo_files'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final String? markPng = _clean(logos['mark_png'] as String?) ??
        _clean(logos['full_png'] as String?);
    if (markPng == null) {
      throw const DeveloperIdentityException(
        'ملفُّ هوية جهة التطوير بلا شعارٍ نقطيّ (`mark_png` أو `full_png`).',
      );
    }
    final Map<String, dynamic> attribution =
        (json['attribution_text'] as Map<String, dynamic>?) ??
            <String, dynamic>{};
    final Map<String, dynamic> socialRaw =
        (json['social'] as Map<String, dynamic>?) ?? <String, dynamic>{};

    return DeveloperIdentity(
      developerName: name,
      website: _requireField(json, 'website'),
      email: _requireField(json, 'email'),
      attributionAr: _clean(attribution['ar'] as String?) ?? 'طُوِّر بواسطة $name',
      copyrightStartYear: (json['copyright_start_year'] as num?)?.toInt() ??
          DateTime.now().year,
      markLogoAssetPath: '$_brandingAssetDir/${markPng.split('/').last}',
      phone: _clean(json['phone'] as String?),
      phoneIsWhatsapp: (json['phone_is_whatsapp'] as bool?) ?? false,
      social: <String, String>{
        for (final MapEntry<String, dynamic> e in socialRaw.entries)
          if (_clean(e.value as String?) != null)
            e.key: _clean(e.value as String?)!,
      },
    );
  }

  /// ★ يقرأ البصمة من حزمة الأصول — **مرةً واحدة** عبر [load].
  static Future<DeveloperIdentity> loadFrom(AssetBundle bundle) async {
    final String raw = await bundle.loadString(developerIdentityAssetPath);
    final Object? decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const DeveloperIdentityException(
        'ملفُّ هوية جهة التطوير ليس كائنَ JSON.',
      );
    }
    return DeveloperIdentity.fromJson(decoded);
  }

  /// ★ يقرأ البصمة من حزمة أصول التطبيق.
  static Future<DeveloperIdentity> load() => loadFrom(rootBundle);

  static String _requireField(Map<String, dynamic> json, String key) {
    final String? value = _clean(json[key] as String?);
    if (value == null) {
      throw DeveloperIdentityException(
        'ملفُّ هوية جهة التطوير بلا الحقل الإلزامي «$key».',
      );
    }
    return value;
  }

  /// ★ يُرجع القيمة أو `null` إن كانت فارغةً **أو قالبيةً** (`<...>`).
  static String? _clean(String? value) {
    if (value == null) return null;
    final String trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.startsWith('<') && trimmed.endsWith('>')) return null;
    return trimmed;
  }
}

/// خطأُ تحميلِ بصمةِ جهة التطوير — ⛔ **ولا يُبتلَع بقيمةٍ افتراضية.**
class DeveloperIdentityException implements Exception {
  /// ينشئ الخطأ برسالته.
  const DeveloperIdentityException(this.message);

  /// الرسالة العربية.
  final String message;

  @override
  String toString() => message;
}

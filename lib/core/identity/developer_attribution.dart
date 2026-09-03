/// ★★★ **مكوّنُ إسناد جهة التطوير** — `FR-SYS-28` · وضع `discreet` (`DI-001`).
///
/// ════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **مكوّنٌ واحدٌ لكل موضعٍ معتمَد** — ★ **والتنويعُ بـ`variant` داخله**
/// (`design-system.md` §5 القاعدة 6) ⛔ **لا بنسخةٍ محلية في شاشة**: ⟵ **ونسخةٌ
/// ثانيةٌ تعني قاعدةَ تبعيةٍ بصريةٍ ثانية تفترق عن الأولى عند أول تعديل.**
///
/// ★★ **وقاعدةُ التبعية البصرية مُنفَّذةٌ في الكود لا موصوفةً في مستند**
/// (`developer-identity.md` §4):
///
/// | القاعدة | ★ أين تُنفَّذ هنا |
/// |---|---|
/// | **الشعار `≤ 40٪` من شعار العميل** | [developerMarkRatio] × [BrandLogo.defaultSize] |
/// | **اللون `textSecondary`** | ⛔ **لا `textPrimary` ولا لونٌ أساسي** |
/// | **الدرجة `caption`** | ★ **أصغرُ درجةٍ متاحة** |
/// | **مرةً واحدةً في الشاشة** | ★ **يحرسها اختبارُ الشاشة** |
/// | **أسفلَ المحتوى بعد فاصلٍ بصري** | [Divider] يسبق المحتوى دائماً |
///
/// ⛔⛔★★★ **وممنوعاتُ §5 ليست تعليقاً هنا بل بنية:** ★ **لا شيءَ في هذا
/// الملف يُستدعى من شريطٍ علوي ولا أيقونةٍ ولا شاشةِ بدايةٍ ولا دخول**،
/// ⛔ **ولا من أي مسارِ تصدير** (`pdf_document_renderer`): ⟵ **ومستنداتُ
/// المالك لمقاوته ليست مساحةً إعلانية** (§5 البند 6).
/// ════════════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';

import '../design/brand.dart';
import '../design/design_tokens.dart';
import 'developer_identity.dart';

/// ★★★ **نسبةُ شعار المطوّر إلى شعار العميل — الحدُّ الأقصى المعتمد.**
///
/// ⛔⛔ **ولا يُكتب المقاسُ رقماً محفوراً** — ★ **يُشتقُّ من شعار العميل نفسِه**:
/// ⟵ **فلو كبر شعارُ العميل غداً بقيت النسبةُ محفوظةً تلقائياً**، ⛔ **ورقمٌ
/// ثابتٌ كان سيصير 60٪ بصمت.** ★ **ويحرسُه اختبارٌ صريح** (`≤ 0.40`).
const double developerMarkRatio = 0.32;

/// ★ مقاسُ علامة المطوّر — **مشتقٌّ لا محفور.**
const double developerMarkSize = BrandLogo.defaultSize * developerMarkRatio;

/// ★★ **صيغةُ ظهور الإسناد** — الموضعان المعتمدان في وضع `discreet`.
enum DeveloperAttributionVariant {
  /// ★ **الموضع 1** — قسمٌ سفليٌّ منفصلٌ بعنوان في شاشة «حول التطبيق».
  section,

  /// ★ **الموضع 2** — تذييلُ شاشة الإعدادات بجوار رقم الإصدار.
  footer,
}

/// ★★★ **إسنادُ جهة التطوير** — ⛔ **ولا قيمةَ تواصلٍ محفورةٌ فيه.**
///
/// ★ **كلُّ ما يُعرَض يصل من [identity]** — ⟵ **والمكوّنُ لا يقرأ ملفاً ولا
/// يجلب** (`design-system.md` §5 القاعدة 4).
class DeveloperAttribution extends StatelessWidget {
  /// ينشئ الإسناد.
  const DeveloperAttribution({
    required this.identity,
    this.variant = DeveloperAttributionVariant.section,
    this.versionLabel,
    super.key,
  });

  /// البصمةُ المقروءة من مصدر الحقيقة الوحيد.
  final DeveloperIdentity identity;

  /// صيغةُ الظهور.
  final DeveloperAttributionVariant variant;

  /// ★ رقمُ الإصدار — **لصيغة [DeveloperAttributionVariant.footer] وحدها**
  /// («**تذييلُ الإعدادات بجوار رقم الإصدار**» — `FR-SYS-28`).
  final String? versionLabel;

  @override
  Widget build(BuildContext context) {
    return switch (variant) {
      DeveloperAttributionVariant.section => _buildSection(),
      DeveloperAttributionVariant.footer => _buildFooter(),
    };
  }

  /// ★ **قسمٌ سفليٌّ بعنوان** — الموضع 1.
  Widget _buildSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // ★ الفاصلُ البصري الذي تشترطه §4 («أسفلَ المحتوى بعد فاصلٍ واضح»).
        const Divider(height: Sizes.borderWidth),
        const SizedBox(height: Spacing.sectionGap),
        Text(
          developerSectionTitle,
          textAlign: TextAlign.center,
          style: TypeScale.label.copyWith(color: SemanticColors.textTertiary),
        ),
        const SizedBox(height: Spacing.space12),
        Center(
          // ⛔⛔★★★ **وبلونٍ محايدٍ ثانويٍّ لا بألوانه هو** — §4 («**بلون محايد
          //    ثانوي لا اللون الأساسي**») · `developer-identity-placement.md`
          //    §4 الفحص 3.
          //
          // ★★ **ولماذا يُصبَغ ولا يُعرَض كما هو — مقيسٌ على المحاكي:**
          //    ⟵ **علامةُ جهة التطوير متدرّجةٌ أزرقَ/بنفسجياً**، ⛔ **وهي
          //    لوحةٌ من خارج `DS-002` كلياً** (زيتوني/طيني/ذهبي على ورقيٍّ
          //    دافئ) — ⟹ **فعرضُها بألوانها يُدخِل مصدراً بصرياً ثانياً في
          //    شاشةٍ هويتُها للعميل**، ★ **وهو عينُ ما تمنعه §1** («**الأولويةُ
          //    للعميل دائماً · والبصمةُ ثانويةٌ دائماً**»).
          child: ColorFiltered(
            colorFilter: const ColorFilter.mode(
              SemanticColors.textSecondary,
              BlendMode.srcIn,
            ),
            child: Image.asset(
              identity.markLogoAssetPath,
              width: developerMarkSize,
              height: developerMarkSize,
              fit: BoxFit.contain,
              semanticLabel: identity.developerName,
              // ⚠️ ★ وتعذُّرُ فكِّ الأصل لا يُسقِط الشاشة — ★ **والنصُّ يبقى**:
              //    ⟵ **الإسنادُ نصُّه لا شعارُه** (§4: الشعار ثانويٌّ دائماً).
              errorBuilder:
                  (BuildContext c, Object e, StackTrace? s) =>
                      const SizedBox(height: developerMarkSize),
            ),
          ),
        ),
        const SizedBox(height: Spacing.space12),
        Text(
          identity.attributionAr,
          textAlign: TextAlign.center,
          style: TypeScale.caption.copyWith(color: SemanticColors.textSecondary),
        ),
        const SizedBox(height: Spacing.space8),
        // ⛔⛔★★ **والقيمُ تصل من الملف** — ⛔ **ولا حرفَ تواصلٍ مكتوبٌ هنا.**
        _contactLine(identity.website),
        _contactLine(identity.email),
        if (identity.phone != null) _contactLine(identity.phone!),
      ],
    );
  }

  /// ★ **تذييلٌ مضغوطٌ بجوار رقم الإصدار** — الموضع 2.
  Widget _buildFooter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const Divider(height: Sizes.borderWidth),
        const SizedBox(height: Spacing.space12),
        if (versionLabel != null)
          Text(
            versionLabel!,
            textAlign: TextAlign.center,
            style:
                TypeScale.caption.copyWith(color: SemanticColors.textTertiary),
          ),
        const SizedBox(height: Spacing.space4),
        Text(
          identity.attributionAr,
          textAlign: TextAlign.center,
          style: TypeScale.caption.copyWith(color: SemanticColors.textSecondary),
        ),
      ],
    );
  }

  Widget _contactLine(String value) => Padding(
        padding: const EdgeInsetsDirectional.only(top: Spacing.space2),
        child: Text(
          value,
          textAlign: TextAlign.center,
          // ★ **قيمةُ تواصلٍ لاتينيةُ المحارف داخل واجهةٍ عربية** — ★ **تُضبَط
          //   اتجاهياً صراحةً** (`rtl-ltr-guidelines`) ⛔ **وإلا انقلب ترتيبُ
          //   نقاطِ النطاق عند نهاية السطر.**
          textDirection: TextDirection.ltr,
          style: TypeScale.caption.copyWith(color: SemanticColors.textTertiary),
        ),
      );
}

/// ★ عنوانُ القسم السفلي — ⛔ **ولا نصٌّ محفورٌ في موضعين.**
const String developerSectionTitle = 'جهة التطوير';

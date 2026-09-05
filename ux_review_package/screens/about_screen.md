# حول التطبيق

| البند | القيمة |
|---|---|
| **اسم الكلاس** | `AboutScreen` (`ConsumerWidget`) |
| **مسار الملف** | `lib/capabilities/master_data/presentation/about_screen.dart` |
| **مكوّن الإسناد** | `lib/core/identity/developer_attribution.dart` — `DeveloperAttribution` |
| **المسار الملاحي** | `/home/about` — `aboutRoute` |
| **اسم الشاشة في الشريط** | `aboutScreenTitle` = «حول التطبيق» |
| **اسم اللقطة المتوقّع** | `about_screen.png` |

## الغرض
هويةُ المنتج ورقمُ إصداره، ثم — **بعد فاصلٍ وفي أسفل الشاشة** — بصمةُ جهة التطوير. وهي **الموضع الوحيد في التطبيق** الذي تظهر فيه قيمُ التواصل (الموقع · البريد · الهاتف)، وتُقرأ من `assets/branding/developer-identity.json` وحده ⛔ **لا محفورةً في أي شاشة.**

## العناصر

| # | الـ Widget class الفعلي | الحجم / اللون / الخط / المسافات | الظهور والتفاعل |
|:-:|---|---|---|
| 1 | `Scaffold` + `QtmsTopBar` | `screenTitle: 'حول التطبيق'` | |
| 2 | `ListView` | `padding: EdgeInsetsDirectional.all(16)` | جذر المحتوى. |
| 3 | `SizedBox` | `Spacing.sectionGap` = 24 | فراغٌ علويٌّ قبل الشعار. |
| 4 | `Center` > `BrandLogo` | **112×112** (`BrandLogo.defaultSize`) · `Image.asset('assets/icons/app-icon-foreground.png')` · `BoxFit.contain` · `semanticLabel = appDisplayName` · وعند تعذُّر فكّ الأصل `SizedBox(height: 112)` ⛔ **لا رمزَ بديل** | شعار العميل. |
| 5 | `SizedBox` | `brandLogoGap` = 16 | |
| 6 | `Text` — الاسم الظاهر | `appDisplayName` = «وكالة محمد المحامي» · `TypeScale.titleLg` (20 · w700) · `textPrimary` · `center` | من مصدر الحقيقة الواحد (`brand.dart`). |
| 7 | `Text` — الإصدار | `appVersionLabel` = «الإصدار 1.0.0» · `TypeScale.caption` (12 · w400) · `textTertiary` · `center` · يسبقه `SizedBox(4)` | |
| 8 | `SizedBox` | `Spacing.space40` = 40 | **فاصلٌ كبيرٌ مقصود** يعزل هوية العميل عن بصمة المطوّر. |
| 9 | `DeveloperAttribution` بصيغة `section` | تفاصيلها أدناه | **القسم السفلي.** |
| 10 | `QtmsErrorState` | أيقونة `error_outline` في `IconBadgeBox` 64 بثلاثية `danger` · عنوان «تعذّر عرض البيانات» · رسالة `developerIdentityErrorMessage` = «تعذّر عرض بيانات جهة التطوير.» · زرُّ «تفاصيل تقنية» يطوي/يفتح النصّ الخام | **بديل ⑨ عند الخطأ.** ⚠️ **بلا زرّ إعادة محاولة** (`onRetry` غير مُمرَّر). |
| 11 | `SkeletonTile` | بطاقةٌ هيكليةٌ واحدة بحدّ `border` و`Radii.card = 20` وحشو 16، بداخلها شريطان (`widthFactor` 0.45 و0.75) بوميض 1200ms | **بديل ⑨ أثناء التحميل.** |

### مكوّن `DeveloperAttribution` — صيغة `section`

| # | الـ Widget class | التفاصيل |
|:-:|---|---|
| أ | `Divider` | `height: 1` — **يسبق المحتوى دائماً** بنيوياً. |
| ب | `SizedBox` | `Spacing.sectionGap` = 24. |
| ج | `Text` «جهة التطوير» | `developerSectionTitle` · `TypeScale.label` (13 · w600) · `textTertiary` · `center`. |
| د | `Center` > `ColorFiltered` > `Image.asset` | **شعار المطوّر — محيَّدُ اللون قسراً:** `ColorFilter.mode(SemanticColors.textSecondary, BlendMode.srcIn)` ⟵ **فلا يعرض ألوانه هو في شاشةٍ هويتها للعميل.** المقاس `developerMarkSize = BrandLogo.defaultSize × 0.32` = **35.84px** — **مشتقٌّ لا محفور**، وهو ≤ 40٪ من شعار العميل قاعدةً. `BoxFit.contain` · `semanticLabel = identity.developerName` · وعند التعذُّر `SizedBox(height: 35.84)`. |
| هـ | `Text` — سطر الإسناد | `identity.attributionAr` · `TypeScale.caption` · `textSecondary` · `center` · يسبقه `SizedBox(12)`. |
| و | ثلاثة × `_contactLine` > `Text` | **الموقع ثم البريد ثم الهاتف** (الأخير شرطي إن وُجد). `TypeScale.caption` · `textTertiary` · `center` · **`textDirection: TextDirection.ltr` صريحاً** ⟵ فلا يرتّب RTL محارفَ عنوانٍ لاتيني ترتيباً خاطئاً. حشو علوي لكل سطر `Spacing.space2` = 2. |

## شجرة الـ Widget tree
```
Scaffold
├── appBar: QtmsTopBar («حول التطبيق»)
└── ListView (padding: 16)
    ├── SizedBox (24)
    ├── Center → BrandLogo (112×112)
    ├── SizedBox (16)
    ├── Text (appDisplayName — titleLg/center)
    ├── SizedBox (4)
    ├── Text (appVersionLabel — caption/textTertiary/center)
    ├── SizedBox (40)
    └── switch (developerIdentityProvider)
        ├── hasError → QtmsErrorState («تعذّر عرض بيانات جهة التطوير.»)
        ├── loading  → SkeletonTile
        └── data     → DeveloperAttribution (variant: section)
            ├── Divider (1px)
            ├── SizedBox (24)
            ├── Text «جهة التطوير» (label/textTertiary/center)
            ├── SizedBox (12)
            ├── Center → ColorFiltered → Image.asset (شعار محيَّد · 35.84px)
            ├── SizedBox (12)
            ├── Text (سطر الإسناد — caption/textSecondary/center)
            ├── SizedBox (8)
            ├── _contactLine (الموقع — ltr)
            ├── _contactLine (البريد — ltr)
            └── [شرطي] _contactLine (الهاتف — ltr)
```

## الحالات المُعالجة
| الحالة | الوضع |
|---|---|
| Loading | ✅ `SkeletonTile` مكانَ قسم الإسناد وحده — **وهوية المنتج أعلاه تُرسَم فوراً** ⟵ فلا تنتظر الشاشةُ كلُّها ملفَّ إسنادٍ ثانوياً. |
| Error | ✅ `QtmsErrorState` برسالةٍ خاصّةٍ بهذا القسم (لا رسالةٍ عامّة) + «تفاصيل تقنية» قابلة للطيّ. ⚠️ **بلا زرّ إعادة محاولة.** |
| Empty | لا ينطبق. |
| تعذُّر الأصول | ✅ **مُعالَجٌ في الطرفين:** شعار العميل وشعار المطوّر لكلٍّ منهما `errorBuilder` يُبقي فراغاً بمقاسه ⛔ **بلا رمزٍ بديلٍ يوهم بهويةٍ أخرى** ⟵ فلا يتزحزح التخطيط. |

## آلية التنقل
- **الدخول إليها:** **من `/home/settings` وحدها** — `ListTile` «حول التطبيق» في قسم «حول».
- **الخروج منها:** ⛔ **لا مسارَ خارجاً** — الرجوع بزرّ النظام، أو إلى «الملف الشخصي»/«الإعدادات» عبر ورقة الجلسة في الشريط العلوي.

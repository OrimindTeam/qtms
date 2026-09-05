# الإعداد التأسيسي

| البند | القيمة |
|---|---|
| **اسم الكلاس** | `FirstRunSetupScreen` (`ConsumerStatefulWidget`) |
| **مسار الملف** | `lib/capabilities/master_data/presentation/first_run_setup_screen.dart` |
| **المسار الملاحي** | `/setup` — `setupRoute` |
| **اسم الشاشة في الشريط** | «الإعداد التأسيسي» |
| **اسم اللقطة المتوقّع** | `first_run_setup_screen.png` |

## الغرض
شاشةٌ **تُعرَض مرةً واحدة في عمر التطبيق**: تكتب `app_settings` (اسم المحل · الهاتف · العنوان · رمز العملة · فاصل الآلاف) وتُنشئ معها نوع «السكرب» الافتراضي. والموجّه **يحصر المستخدم فيها** ما دام `requiresFirstRunSetupProvider` صحيحاً — ⛔ **فلا يُفلَت منها إلى `/home` قبل إتمامها.**

## العناصر

| # | الـ Widget class الفعلي | الحجم / اللون / الخط / المسافات | الظهور والتفاعل |
|:-:|---|---|---|
| 1 | `Scaffold` + `QtmsTopBar` | `screenTitle: 'الإعداد التأسيسي'` | ⚠️ **الشريط موجود** — بصورته الرمزية وورقة الجلسة، فالخروج ممكن منها. |
| 2 | `SafeArea` > `SingleChildScrollView` | `padding: EdgeInsets.all(Spacing.space16)` = 16 | جذر قابل للتمرير. |
| 3 | `_OnceOnlyWarning` > `QtmsInlineBanner` | `triad: SemanticTriads.warning` (تعبئة `#FBF0D6` · حدّ `#F0DCA6` · حبر `#946010`) · حشو 12 · `Radii.card = 20` | لافتةٌ ثابتةٌ أعلى الشاشة: «هذه القيم تُحفظ مرة واحدة ولا يمكن تغييرها لاحقاً. تصحيح أي خطأ بعد الحفظ يتطلب تدخّلاً على مستوى المشروع السحابي.» |
| 4 | `Text` «بيانات المنشأة» | `TypeScale.titleSm` (15 · w600) · يسبقه `SizedBox(24)` | عنوان القسم الأول. ⛔ **بلا `Divider`** — بخلاف أقسام «الإعدادات». |
| 5 | `MasterDataField` > `TextField` «اسم المحل» | `autofocus: true` · ارتفاع 52 من الثيم · تعبئة `surfaceSunken` · ⛔ بلا حدّ في السكون · حدّ `primary400` بعرض 2 عند التركيز | الحقل الإلزامي الوحيد فعلياً. |
| 6 | `MasterDataField` «الهاتف (اختياري)» | `keyboardType: TextInputType.phone` | فاصل 12 قبله. |
| 7 | `MasterDataField` «العنوان (اختياري)» | | فاصل 12. |
| 8 | `Text` «العملة والأرقام» | `titleSm` · يسبقه `SizedBox(24)` | عنوان القسم الثاني. |
| 9 | `MasterDataField` «رمز العملة» | **مُعبَّأ مسبقاً بـ`'ر.ي'`** | |
| 10 | `MasterDataField` «فاصل الآلاف» | **مُعبَّأ مسبقاً بـ`','`** | |
| 11 | `Text` تفسيري | `bodyMd` · `textSecondary` | «المبالغ أعداد صحيحة بالريال — بلا كسور عشرية.» |
| 12 | `CheckboxListTile` | `contentPadding: EdgeInsets.zero` · **`controlAffinity: ListTileControlAffinity.leading`** ⟵ المربّع في بداية السطر (يمين في RTL) · المربّع بتعبئة `primary500` عند التأشير و`Radii.xs = 8` | الإقرار: «أفهم أن هذه القيم تُحفظ مرة واحدة ولا يمكن تغييرها لاحقاً.» **وهو بوّابة الزرّ.** |
| 13 | `RejectionBanner` > `Container` | تعبئة `danger.soft` · حدّ `danger.border` · أيقونة `error_outline` 20 · نصّ `bodyMd` بـ`danger.ink` | **شرطي:** رفضٌ بنصٍّ من الكتالوج. |
| 14 | `FilledButton` «حفظ الإعداد نهائياً» | ارتفاع 52 · سطح `surfaceInverse` · **معطَّل** ما لم يُؤشَّر الإقرار ⑫، أو أثناء الإرسال | ⟵ **فالتأكيد شرطٌ بنيويٌّ لا تحذيرٌ يُقرأ ويُتجاوَز.** |
| 15 | `Text` تذييلي | `bodyMd` · `textSecondary` · `center` | «يُنشأ مع الإعداد نوع «السكرب» الافتراضي — وزني بالكيلوجرام، ولا يُعدَّل ولا يُحذف.» |

## شجرة الـ Widget tree
```
Scaffold
├── appBar: QtmsTopBar («الإعداد التأسيسي»)
└── SafeArea → SingleChildScrollView (padding: 16)
    └── Column (crossAxis: stretch)
        ├── _OnceOnlyWarning → QtmsInlineBanner (warning)
        ├── SizedBox (24)
        ├── Text «بيانات المنشأة» (titleSm)
        ├── MasterDataField «اسم المحل» (autofocus)
        ├── MasterDataField «الهاتف (اختياري)» (phone)
        ├── MasterDataField «العنوان (اختياري)»
        ├── SizedBox (24)
        ├── Text «العملة والأرقام» (titleSm)
        ├── MasterDataField «رمز العملة» (مبدئياً «ر.ي»)
        ├── MasterDataField «فاصل الآلاف» (مبدئياً «,»)
        ├── Text «المبالغ أعداد صحيحة بالريال…» (bodyMd/textSecondary)
        ├── SizedBox (24)
        ├── CheckboxListTile (الإقرار · leading)
        ├── [شرطي] RejectionBanner
        ├── FilledButton «حفظ الإعداد نهائياً» (معطَّل بلا إقرار)
        └── Text «يُنشأ مع الإعداد نوع السكرب…» (center)
```

## الحالات المُعالجة
| الحالة | الوضع |
|---|---|
| Loading | ⚠️ **جزئية:** `_submitting` يُعطِّل الزرّ ⛔ **بلا مؤشّر دوران ولا نصٍّ بديل** — والمستخدم لا يرى أن الحفظ جارٍ. |
| Error | ✅ `RejectionBanner` بنصٍّ من الكتالوج. ⚠️ **لكنّ فشلَ التحقق المحلي كلَّه يُختصَر في رسالةٍ واحدة عامّة** (`CatalogMessage.operationFailed`) ⛔ **بلا تحديد أيُّ حقلٍ رُفض** — بخلاف تغيير كلمة المرور في «الملف الشخصي». |
| Empty | لا ينطبق — نموذج إدخال. |
| النجاح | ⛔ **لا رسالة نجاح ولا ملاحة صريحة** — `Success` تُنهي الدالة بلا شيء، والموجّه هو الذي يُخرِج الشاشة تلقائياً إلى `/home` عند تغيُّر `requiresFirstRunSetupProvider`. |

## آلية التنقل
- **الدخول إليها:** **قسراً من `_redirect`** — لكلِّ `SessionActive` يشترط الإعداد التأسيسي، من أي مسار.
- **الخروج منها:** بالحفظ الناجح ⟶ `/home` تلقائياً · أو بتسجيل الخروج من ورقة الجلسة في الشريط العلوي.

# الإعدادات

| البند | القيمة |
|---|---|
| **اسم الكلاس** | `SettingsScreen` (`ConsumerWidget`) |
| **مسار الملف** | `lib/capabilities/master_data/presentation/settings_screen.dart` |
| **المسار الملاحي** | `/home/settings` — `settingsRoute` |
| **اسم الشاشة في الشريط** | `settingsScreenTitle` = «الإعدادات» |
| **اسم اللقطة المتوقّع** | `settings_screen.png` |

## الغرض
إعداداتُ **هذا الجهاز** وحدها. ومفتاحٌ واحدٌ فعلي فقط: إظهار وزن الحبة بجانب اسم النوع. ⛔ **ولا مبدِّل لغة ولا مبدِّل وضعٍ داكن ولا خيار أرقام** — لغةٌ واحدة (العربية RTL) ووضعٌ واحد (الفاتح) وأرقامٌ لاتينية، قيمةً وحيدةً ثابتة لا خياراً.

## العناصر

| # | الـ Widget class الفعلي | الحجم / اللون / الخط / المسافات | الظهور والتفاعل |
|:-:|---|---|---|
| 1 | `Scaffold` + `QtmsTopBar` | `screenTitle: 'الإعدادات'` | |
| 2 | `ListView` | `padding: EdgeInsetsDirectional.all(Spacing.screenPadding)` = 16 | جذر المحتوى. |
| 3 | `Text` «العرض» | `TypeScale.titleSm` (15 · w600) · `textPrimary` | عنوان القسم الأول. |
| 4 | `Divider` | `height: Sizes.borderWidth = 1` · لون `SemanticColors.divider` = `#EFEDDF` · يسبقه `SizedBox(8)` | |
| 5 | `SwitchListTile.adaptive` | `contentPadding: EdgeInsets.zero` · مسار المفتاح `primary500` والمقبض `surface` عند التفعيل · وفي السكون مسار `neutral200` ومقبض `neutral400` | العنوان `showPieceWeightToggleLabel` = «إظهار وزن الحبة بجانب اسم النوع». **يكتب فوراً بلا زرّ حفظ** (`showPieceWeightProvider.notifier.set`). النصُّ الثانوي طويلٌ ومقصود: «يظهر الاسم هكذا: «بطّوه وزن (200 جرام)». خيار عرض فقط — ولا يغيّر وحدة النوع ولا أي حساب، ويبقى العدّ بالحبة في كل الشاشات والتقارير.» |
| 6 | `Text` | `bodyMd` · `textSecondary` · يسبقه `SizedBox(8)` | «هذا الخيار محفوظ على هذا الجهاز وحده.» ⟵ **فلا يُتوقَّع أن يتبع المستخدمَ إلى جهازٍ آخر.** |
| 7 | `Text` «حول» | `titleSm` · `textPrimary` · يسبقه `SizedBox(Spacing.sectionGap)` = 24 | `settingsAboutGroupTitle` — عنوان القسم الثاني. |
| 8 | `Divider` | 1px · `divider` | |
| 9 | `ListTile` «حول التطبيق» | `leading: Icons.info_outline` · **`trailing: Icons.chevron_left`** ⟵ **سهمٌ يساراً هو «إلى الأمام» في RTL** · `contentPadding: EdgeInsets.zero` | **مدخل الملاحة الوحيد في الشاشة.** ⟶ `/home/about`. |
| 10 | `DeveloperAttribution` بصيغة `footer` | `Divider` + `SizedBox(12)` ثم **رقم الإصدار** (`appVersionLabel` = «الإصدار 1.0.0») بـ`TypeScale.caption` و`textTertiary` و`center`، ثم `SizedBox(4)`، ثم سطر الإسناد بـ`caption`/`textSecondary`/`center` | تذييلُ الشاشة — يسبقه `SizedBox(24)`. ⛔ **بلا شعار مطوّرٍ في هذه الصيغة** ⛔ **وبلا قيمة تواصل** (البريد والهاتف والموقع محصورة في صيغة `section` بشاشة «حول التطبيق»). |
| 11 | `_VersionOnlyFooter` | `Divider` + `SizedBox(12)` + رقم الإصدار بـ`caption`/`textTertiary`/`center` | **بديلٌ عند التحميل أو الخطأ:** إن لم تُقرأ بيانات جهة التطوير يُعرَض **رقمُ الإصدار وحده** ⟵ **فالتذييل لا يختفي ولا يقفز الارتفاع.** |

## شجرة الـ Widget tree
```
Scaffold
├── appBar: QtmsTopBar («الإعدادات»)
└── ListView (padding: 16)
    ├── Text «العرض» (titleSm)
    ├── SizedBox (8) + Divider (1px)
    ├── SwitchListTile.adaptive («إظهار وزن الحبة…» + نصّ ثانوي ثلاثي السطور)
    ├── SizedBox (8)
    ├── Text «هذا الخيار محفوظ على هذا الجهاز وحده.» (bodyMd/textSecondary)
    ├── SizedBox (24)
    ├── Text «حول» (titleSm)
    ├── SizedBox (8) + Divider (1px)
    ├── ListTile «حول التطبيق» (info_outline → chevron_left) ⟶ /home/about
    ├── SizedBox (24)
    └── switch (developerIdentityProvider)
        ├── data → DeveloperAttribution (variant: footer + versionLabel)
        └── _    → _VersionOnlyFooter (رقم الإصدار وحده)
```

## الحالات المُعالجة
| الحالة | الوضع |
|---|---|
| Loading | ✅ **مُعالَجة بأناقة:** بيانات جهة التطوير أثناء تحميلها تُعرَض بـ`_VersionOnlyFooter` — تذييلٌ صالحٌ لا هيكلٌ عظمي. والمفتاح ⑤ يُقرأ من تفضيلات الجهاز فورياً بلا حالة انتظار. |
| Error | ⚠️ **مُدمَجة في التحميل:** فشلُ قراءة بيانات جهة التطوير يُعطي **نفس** `_VersionOnlyFooter` ⛔ **بلا رسالة خطأ إطلاقاً** — بخلاف «حول التطبيق» التي تعرض `QtmsErrorState` صريحة. **وهو تفاوتٌ مقصود:** الإسناد في التذييل زينةٌ، وغيابه لا يستحق تحذيراً. |
| Empty | لا ينطبق. |

## آلية التنقل
- **الدخول إليها:** **من ورقة الجلسة وحدها** — `showQtmsSessionSheet` التي تفتحها الصورة الرمزية في `QtmsTopBar` من **أي شاشة** ⟶ `ListTile` «الإعدادات».
- **الخروج منها:** ⟶ `/home/about` عبر `ListTile` ⑨ · وإلى `/home/profile` عبر ورقة الجلسة · والرجوع بزرّ النظام.
- **تأثيرٌ متقاطع:** المفتاح ⑤ يغيّر اسمَ النوع المعروض في **كل** شاشة تعرض أنواعاً (`itemDisplayName`).

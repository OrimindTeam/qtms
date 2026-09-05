# التوزيع

| البند | القيمة |
|---|---|
| **اسم الكلاس** | `DistributionScreen` (`ConsumerStatefulWidget`) |
| **مسار الملف** | `lib/capabilities/sales_receivables/presentation/distribution_screen.dart` |
| **المسار الملاحي** | `/home/distribution` — `distributionRoute` |
| **اسم الشاشة في الشريط** | «التوزيع» |
| **أسماء اللقطات المتوقّعة** | `distribution_screen.png` · `distribution_form_sheet.png` · `distribution_details_sheet.png` · `send_document_sheet.png` · `cancel_distribution_sheet.png` |

## الغرض
العمليةُ الأساسيةُ في التطبيق — **وهي المدخلُ الوحيد الذي رُسِم زرّاً أساسياً (`isPrimary`) في «لوحة اليوم»**. تُخرِج مخزوناً إلى مقوتٍ فيُقيَّد على ضماره فوراً. **والسعرُ قد يُترَك فارغاً عن قصد** فيدخل السطرُ «مركز الإدخالات المعلّقة».

## العناصر — الشاشة

| # | الـ Widget class الفعلي | الحجم / اللون / الخط / المسافات | الظهور والتفاعل |
|:-:|---|---|---|
| 1 | `Scaffold` + `QtmsTopBar` | `screenTitle: 'التوزيع'` | |
| 2 | `FloatingActionButton.extended` «توزيعة جديدة» | `Icons.local_shipping_outlined` · خلفية `surfaceInverse` · `elevation: 0` | `PermissionGate(distributionCreate)` **ويغيب كلياً إن خلا النطاق من مصدر** (`sources.isEmpty ⟶ null`). **Trigger** لورقة النموذج. |
| 3 | `QtmsContextHeader` | سطح `surface` بحدٍّ سفلي · حشو أفقي 16 ورأسي 8 | **`allowAllSources: true`** ⟵ بندُ «كل المصادر» موجود. |
| 4 | `DropdownButtonFormField<String>` «المصدر» | `isDense` · `isExpanded` · `hint: 'اختر المصدر'` | منسدلٌ من مكانه. |
| 5 | `_LockedDay` | `Icons.lock_outline` 20 + التاريخ بأرقامٍ جدولية | تاريخُ اليوم مقفل. |
| 6 | `QtmsSearchField` > `TextField` «بحث بالمقوت» | حشو أفقي 16 ورأسي 8 · ارتفاع 52 · `prefixIcon: Icons.search` · `suffixIcon: IconButton(Icons.close)` بـ`tooltip: 'مسح البحث'` عند وجود نصّ | ★ **بحثٌ بـ`normalizeName`** (لا `contains` خام) ⟵ فيتجاوز فوارقَ الهمزة والتشكيل. |
| 7 | `ListView.separated` | حشو 16 · فاصل 8 | |
| 8 | `InventoryTile` > `EntityTile` | سطح `surface` · حدّ 1px · `Radii.card = 20` · حشو 16 · **`actionsPlacement` افتراضي = `stacked`** ⟵ صفٌّ سفليٌّ بارتفاع 48 يسبقه `Divider` | ⚠️ **العنوان اسمُ المقوت لا رقمُ المستند** — بخلاف بطاقات الوارد. |
| 9 | `Text` — الثانوي | `bodyMd` · `textSecondary` | «رقم المستند · [اسم المصدر في وضع «كل المصادر»] · N نوع». |
| 10 | `IconButton` (في `leading`) | سجل التدقيق للتوزيعة — بـ`sourceId`. **شرطي.** |
| 11 | `CancelledBadge` · `AmendedBadge` · `StatusPill` «سعر غير نهائي» | «ملغى» (`danger`) · «مُعدَّل» (`warning`) · «سعر غير نهائي» (`warning` + `Icons.hourglass_bottom_outlined`) | ثلاثُ شاراتٍ شرطية — والثالثةُ شرطُها `unpricedLineCount > 0`. |
| 12 | `IconButton` — عرض | `Icons.visibility_outlined` · `tooltip: 'عرض التوزيعة'` | ⛔ **بلا مفتاح صلاحية.** **Trigger** لورقة التفاصيل. |
| 13 | `_SendAction` > `IconButton` — إرسال | `Icons.send_outlined` · `tooltip: 'إرسال أو تصدير'` | **شرطي:** يظهر إن ملك المستخدم `messagingSend` **أو** `documentExport` — وإلّا يغيب. **Trigger** لورقة الإرسال. |
| 14 | `IconButton` — تعديل | `Icons.edit_outlined` · `tooltip: 'تعديل التوزيعة'` | `PermissionGate(distributionAmend)` **وشرط ألّا تكون ملغاة**. ⚠️ **يفتح النموذجَ بالمقوت والمصدر** ⟵ **والنموذجُ نفسُه يكتشف أن للمقوت توزيعةً اليوم فيفتحها للتعديل.** |
| 15 | `IconButton` — إلغاء | `Icons.block_outlined` · **`color: SemanticTriads.danger.ink`** صراحةً · `tooltip: 'إلغاء التوزيعة'` | `PermissionGate(distributionCancel)` **وشرط ألّا تكون ملغاة**. |

## ورقة التوزيعة — `DistributionFormSheet`
**Trigger:** الزرُّ العائم ② · زرُّ التعديل ⑭ · **أو الفتحُ التلقائي** (انظر «الوضعان الخاصّان» أدناه). البنيةُ ثلاثية: ترويسةٌ ثابتة + `Flexible` > `ListView` + `QtmsStickyActionBar`، بسقف **0.9** من ارتفاع الشاشة.

| # | الـ Widget class | التفاصيل |
|:-:|---|---|
| 1 | `Text` | «توزيعة جديدة» أو **«تعديل التوزيعة»** — `titleLg`. والحالةُ تُقرَّر تلقائياً بوجود توزيعةٍ للمقوت في هذا اليوم والمصدر. |
| 2 | `_DealerField` > `DropdownMenu<String>` «المقوت» | بعرض الحاوية · **`enableFilter` و`enableSearch` و`requestFocusOnTap`** ⟵ **بحثٌ داخل المنسدل** · `menuHeight = 72 × 4 = 288`. **تغييرُ المقوت يُفرِّغ كلَّ الأسطر.** |
| 3 | `DropdownButtonFormField<String>` «المصدر» | `isExpanded` · **معطَّلٌ في وضع التعديل وفي الوضع المتأخر** (`onChanged: null`). تغييرُه يُفرِّغ الأسطر. |
| 4 | `AgedClearanceBanner` | **شرطي — الوضع المتأخر:** تعبئة `warning.soft` · حدّ · `Radii.card` · `Icons.warning_amber_outlined` 20: «أنت تصرّف مخزون يوم {التاريخ} — سيُحتسب في ضمار ذلك اليوم لا في اليوم الحالي.» |
| 5 | `_ExistingBanner` > `Card` > `ListTile` | **شرطي — وضع التعديل.** ⚠️ **`Card` من الإطار بلون `surfaceSunken`** (المكوّن الوحيد الذي يستعمل `Card` مباشرةً في هذه الشاشة). العنوان رقمُ المستند بـ`bodyMd`، والثانوي **يُبنى تراكمياً**: «يوجد توزيع لهذا المقوت اليوم — فُتح للتعديل» + « · مُعدَّل ×N» إن عُدِّل + « · سعر غير نهائي» إن وُجدت سطورٌ بلا سعر. |
| 6 | `Text` بلون `danger.ink` | **شرطي:** «هذه التوزيعة ملغاة — لا يمكن تعديلها.» **ويحلّ محلّ كلِّ محرِّر الأسطر، ويُخفي شريطَ الإجراء اللاصق كاملاً.** |
| 7 | `Text` «الأنواع» | `TypeScale.label`/`textSecondary`. |
| 8 | `QtmsItemLineRow` لكل سطر | منسدلُ النوع (`DropdownMenu` ببحثٍ ومرشِّح) + `IconButton` حذفٍ (`remove_circle_outline` بـ`danger.ink` · 48×48) + **حقلٌ أو حقلان**. ★ **خياراتُ النوع من أرصدة دفتر اليوم** (`stockOptionsProvider`) لا من الكتالوج · والتسميةُ تحمل الرصيد · والمأخوذُ في سطرٍ آخر يُخفى. ⭐ **واختيارُ نوعٍ يُعبِّئ سعرَه المقترَح تلقائياً** من `suggestedDistributionPricesProvider` **إن كان الحقلُ فارغاً وكان المستخدم يرى الأسعار.** |
| 9 | `TextField` «الكمية» | ★ **لوحةُ المفاتيح والمُرشِّح يتغيّران بوحدة النوع:** للكيلوجرام `numberWithOptions(decimal: true)` و`FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))` · وللحبة `digitsOnly` ⟵ **فالكسرُ في العدّ يستحيل إدخالُه بنيوياً.** **و`suffixText`** = اسمُ الوحدة بعد اختيار النوع. |
| 10 | `TextField` «السعر» | **شرطي على `distributionPriceView`** ⟵ فمن لا يراه لا يرى الحقل، **ويُستعمَل السعرُ المقترَح نيابةً عنه عند الحفظ.** `digitsOnly` · **`suffixText: 'ريال'`** · **و`readOnly: true`** إن لم يملك `distributionPriceAmend` ولا `distributionPriceClear`. ★ **وتسميتُه تتغيّر بالصلاحية:** «السعر (أو اتركه لاحقاً)» لمن يملك `distributionPriceClear`، و«السعر» لغيره. |
| 11 | `Text` إرشادي | `TypeScale.caption`/`textSecondary` · **شرطي على `distributionPriceView` و`distributionPriceClear` معاً:** «اترك السعر فارغاً للتسعير لاحقاً — يدخل السطر مركز الإدخالات المعلّقة.» ⟵ **فالسلوكُ غيرُ البديهي مشروحٌ في مكانه.** |
| 12 | `Text` | **بديلٌ عند خلوّ المخزون:** «لا مخزون في هذا المصدر اليوم.» |
| 13 | `QtmsAddLineButton` > `OutlinedButton.icon` «إضافة نوع» | **معطَّل** إن لم يُختَر مقوتٌ بعد **أو** بلغ عددُ الأسطر عددَ الأنواع المتاحة. |
| 14 | `TextField` «سبب التعديل (اختياري)» | **وضع التعديل فقط** · `blankToNull`. |
| 15 | `QtmsStickyActionBar` | سطح `surface` بحدٍّ علويٍّ · `SafeArea(top: false)` · حشو 16. **يغيب كلياً إن كانت التوزيعةُ ملغاة.** |
| 16 | `QtmsLiveSummary` (في `summary`) | تعبئة `surfaceSunken` · حدّ · `Radii.card` · حشو 12. **ملخّصٌ حيٌّ:** «إجمالي الحبات: N حبة» + سطر «إجمالي الأوزان: X كجم» — ★ **إجماليّان منفصلان** — **وسطرٌ ثالثٌ شرطي: «سطورٌ بلا سعر — تُسعَّر لاحقاً»** إن وُجد سطرٌ بلا سعر. |
| 17 | `QtmsActionStatus` (في `status`) | **شرطي بحالتين:** رفضٌ بثلاثية `danger` وأيقونة `error_outline` · ونجاحٌ بثلاثية `success` وأيقونة `check_circle_outline` بنصّ «تم الحفظ.» |
| 18 | `FilledButton.icon` | `Icons.save_outlined` · «حفظ التوزيعة» أو «حفظ التعديل» · ارتفاع 52. **مُغلَّفٌ بـ`PermissionGate`** يتبدّل مفتاحُه بالحالة (`distributionAmend` تعديلاً و`distributionCreate` إنشاءً). **ومعطَّل** ما لم يُختَر مقوت. وعند النجاح تُغلَق الورقة. |

## ورقة تفاصيل التوزيعة — `DistributionDetailsSheet`
**Trigger:** زرُّ العرض ⑫. `SafeArea` > `SingleChildScrollView` بحشو 16.
- `Text` اسمُ المقوت (`titleLg`) · `QtmsKeyValueRow` للمستند وللمصدر (**بالاسم لا بالمعرّف**) · `QtmsKeyValueRow` لكل سطرٍ (اسمُ النوع ⟷ الكمية) · ثم «إجمالي الحبات» و«إجمالي الأوزان».
- ⭐ **و«قيمة الضمار» صفٌّ شرطيٌّ مزدوج:** يظهر فقط إن ملك المستخدم **`distributionPriceView`** **و**قُرِئت بطاقةُ التسعير ⟵ **فمن لا يرى الأسعار لا يرى قيمةَ الضمار.**
- ⚠️ **بلا حالة تحميل ولا خطأ** — التسعيرُ إن لم يُقرأ **يُختفي الصفُّ بصمت.**

## ورقة الإلغاء — `CancelDistributionSheet` > `QtmsDestructiveSheet`
**Trigger:** زرُّ الإلغاء ⑮. العنوان «إلغاء توزيعة {اسم المقوت}» · نصُّ الأثر **يذكر شرطَ الرفض صراحةً**: «الإلغاء يَسِم التوزيعة وحركاتها ولا يحذف شيئاً، فتُستبعَد من كل الأرصدة والتقارير. **ويُرفَض إن كان الضمار قد سُدِّد كلياً أو جزئياً.**» · سببٌ اختياري · `FilledButton.icon` بخلفية `danger.ink` وأيقونة `warning_amber_outlined` وتسمية «تأكيد الإلغاء» · و`TextButton` «تراجع». **والرفضُ يُعرَض داخل الورقة** فلا تُغلَق على خطأ.

## ورقة الإرسال والتصدير — `_SendSheet` (مشتركة)
**الملف:** `lib/capabilities/oversight/presentation/send_document_sheet.dart` — **تستعملها أيضاً «المقبوضات» و«كشف حساب المقوت»**. **Trigger:** زرُّ الإرسال ⑬. `SafeArea` > `SingleChildScrollView` بحشو 16.

| # | الـ Widget class | التفاصيل |
|:-:|---|---|
| أ | `Text` «إرسال التوزيعة» | `titleLg`. |
| ب | `_TemplateChoice` > **`RadioGroup<MessageTemplate>`** > `RadioListTile` × 2 | **شرطي على `offersTemplateChoice`.** الخيارَان: «التوزيع فقط» · **«التوزيع مع التسعير»** — والثاني **معطَّلٌ** إن لم تكن كلُّ السطور مسعَّرةً، **وحينها يظهر نصٌّ ثانويٌّ يفسّر التعطيل: «يتطلب أن تكون كل السطور مسعَّرة.»** |
| ج | `_MessagePreview` > `Container` | تعبئة `surfaceSunken` · `Radii.card = 20` · حشو 16 · نصٌّ بـ`bodyMd`/`textPrimary` · **بلا حدّ** | ⭐ **معاينةُ نصِّ الرسالة الفعلي قبل الإرسال** — تتغيّر مع كل تبديلٍ للقالب. |
| د | `SwitchListTile.adaptive` «إرسال نسخة مختصرة» | ⭐ **شرطيٌّ مزدوجٌ ذكيّ:** يظهر **فقط** إذا تجاوز طولُ النصّ **70 محرفاً** (`smsSingleMessageLength`) **و**كان للمستند نسخةٌ مختصرة. نصُّه الثانوي: «النص يتجاوز رسالة واحدة — والمختصرة تحمل الإجمالي والرصيد فقط.» ⟵ **فحدُّ الرسالة النصّية الواحدة مُراعىً عملياً.** |
| هـ | `QtmsActionStatus.rejection` | **شرطي:** يظهر إن ملك المستخدم الإرسالَ **ولا هاتفَ صحيحٌ للمستلم**: «لا يمكن الإرسال — لا يوجد رقم هاتف صحيح لهذا المستلم.» ⟵ **فالسببُ مكتوبٌ بدل زرٍّ ميّت.** |
| و | `FilledButton.icon` «فتح واتساب» | `Icons.chat_outlined` · **شرطي على `messagingSend` ووجودِ هاتف.** يفتح **تطبيق واتساب خارج التطبيق**. |
| ز | `OutlinedButton.icon` «فتح الرسائل» | `Icons.sms_outlined` · نفس الشرط. يفتح **تطبيق الرسائل في النظام**. |
| ح | `OutlinedButton.icon` «تصدير ملف ومشاركته» | `Icons.picture_as_pdf_outlined` · **شرطي على `documentExport`.** يُنتِج **PDF** ويفتح **ورقةَ مشاركة النظام** — ويُسجَّل التصديرُ في سجلٍّ. |
| ط | `QtmsActionStatus` | **شرطي:** نجاحاً («فُتحت المحادثة — أرسل الرسالة من هناك.») أو رفضاً. ★ **وأربعُ رسائلَ متمايزةٍ لفتح القناة:** غيرُ مثبَّت («تطبيق واتساب غير مثبَّت على الجهاز — **جرّب الإرسال عبر رسالة نصية**») · غيرُ متاح · لا هاتف · تعذُّرٌ عام. ⟵ **فكلُّ فشلٍ يحمل بديلَه.** |
| ي | `TextButton` «إغلاق» | معطَّلٌ أثناء العمل. |

## الوضعان الخاصّان — فتحٌ تلقائيٌّ للورقة
كلاهما يُنفَّذ في `addPostFrameCallback` عند بناء الشاشة، ويُستهلَك مرةً واحدة:

| الوضع | المصدر | السلوك |
|---|---|---|
| **تصريفُ متأخر** | `agedClearanceFocusProvider` (من «متبقي الأيام السابقة») | يُرشِّح المصدر، **ويفتح ورقةَ النموذج فوراً** بتاريخِ مخزونٍ مثبَّتٍ ونوعٍ مزروعٍ مسبقاً — **وترويسةُ المصدر مقفلة**، ولافتةُ `AgedClearanceBanner` ظاهرة. |
| **إدخالٌ معلَّق** | `pendingFocusProvider` (من «مركز الإدخالات المعلّقة») | ⚠️ **لا يفتح الورقة** — بل يُرشِّح المصدر **ويكتب اسمَ المقوت في حقل البحث** فيَظهر سطرُه في القائمة. **ويخرج بصمت** إن لم يُعرَف اسمُ المقوت. |

## شجرة الـ Widget tree
```
Scaffold
├── appBar: QtmsTopBar («التوزيع»)
├── floatingActionButton: [شرطي] PermissionGate(distributionCreate) → FAB.extended
└── Column
    ├── QtmsContextHeader (+ «كل المصادر»)
    │   ├── DropdownButtonFormField «المصدر»
    │   └── _LockedDay
    ├── Padding → QtmsSearchField («بحث بالمقوت» · normalizeName)
    └── Expanded
        ├── [لا مصادر] QtmsEmptyState (noSourceInScopeEmpty)
        └── _DistributionRecords → ValueListenableBuilder → InventoryAsyncView
            ├── hasError → QtmsErrorState
            ├── data []  → QtmsEmptyState («لا توزيعات اليوم»)
            ├── loading  → SkeletonList
            └── data → [بحثٌ بلا نتيجة] QtmsNoMatch («لا مقوت بهذا الاسم في نتائج اليوم.»)
                       [وإلا] ListView.separated
                       └── _DistributionTile → InventoryTile (stacked)
                           ├── leading: [شرطي] IconButton (سجل التدقيق)
                           ├── title: اسم المقوت · subtitle: المستند · [المصدر] · N نوع
                           ├── badges: [Cancelled] [Amended] [«سعر غير نهائي»]
                           └── actions:
                               ├── IconButton (visibility) → DistributionDetailsSheet
                               ├── _SendAction → IconButton (send) → _SendSheet
                               ├── PermissionGate(distributionAmend)  → IconButton (edit)
                               └── PermissionGate(distributionCancel) → IconButton (block · danger.ink)
```

## الحالات المُعالجة
| الحالة | الوضع |
|---|---|
| Loading | ✅ `SkeletonList` للقائمة. ⚠️ **وحالةٌ خفيّةٌ مُعالَجة:** زرعُ الأسطر في وضع التعديل **ينتظر تحميلَ بطاقة التسعير** (`if (pricing.isLoading) return`) ⟵ **فلا تُزرَع أسطرٌ بأسعارٍ فارغةٍ ثم تُدهَس.** وأثناء الحفظ يُعطَّل الزرّ ⛔ بلا مؤشّر. |
| Error | ✅ `QtmsErrorState` للقراءة · `QtmsActionStatus.rejection` في الورقة · **وأربعُ رسائلَ متمايزةٍ لفشل فتح قناة الإرسال.** ⚠️ **ورفضُ التحقق المحلي يُختصَر في `operationFailed` عامّة** ⛔ بلا تحديد السبب — بخلاف «الوارد عدداً» و«الجونية» اللتين تربطان كلَّ رمزِ قاعدةٍ برسالته. |
| Empty | ✅ **أربعُ حالاتٍ متمايزة:** لا مصدرَ في النطاق · «لا توزيعات اليوم» · `QtmsNoMatch` («لا مقوت بهذا الاسم في نتائج اليوم.») · و«لا مخزون في هذا المصدر اليوم.» داخل الورقة. |
| حالةُ الإلغاء | ✅ **مُعالَجةٌ بنيوياً:** الورقةُ تعرض نصَّ «ملغاة — لا يمكن تعديلها» **وتُخفي شريطَ الحفظ كلَّه** ⟵ فلا زرَّ حفظٍ يُضغَط فيُرفَض. |
| «سعر غير نهائي» | ✅ **مُعالَجٌ في أربعة مواضع متّسقة:** شارةٌ على البطاقة · سطرٌ في `_ExistingBanner` · سطرٌ في الملخّص الحيّ · وتعطيلُ قالبِ «التوزيع مع التسعير» في ورقة الإرسال بنصٍّ يفسّر. |

## آلية التنقل
- **الدخول إليها:** «لوحة اليوم» ⟶ «العمليات اليومية» ⟶ **«التوزيع» (الزرُّ الأساسي الوحيد)** بمفتاح `distributionCreate` · **ومن «متبقي الأيام السابقة»** بزرّ «توزيع» (فتحٌ تلقائيٌّ للورقة) · **ومن «مركز الإدخالات المعلّقة»** (ترشيحٌ وبحثٌ لا فتح).
- **الخروج منها:** ⛔ **لا مسارَ خارجاً** — أربعُ أوراقٍ سفلية هي العمق. **لكنّ ورقةَ الإرسال تُخرِج المستخدم إلى تطبيقاتٍ خارجية**: واتساب · تطبيقُ الرسائل · وورقةُ مشاركة النظام للـPDF.

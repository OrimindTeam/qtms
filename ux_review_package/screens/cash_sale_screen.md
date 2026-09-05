# البيع النقدي

| البند | القيمة |
|---|---|
| **اسم الكلاس** | `CashSaleScreen` (`ConsumerStatefulWidget`) |
| **مسار الملف** | `lib/capabilities/sales_receivables/presentation/cash_sale_screen.dart` |
| **المسار الملاحي** | `/home/cash-sales` — `cashSaleRoute` |
| **اسم الشاشة في الشريط** | «البيع النقدي» |
| **أسماء اللقطات المتوقّعة** | `cash_sale_screen.png` · `cash_sale_form_sheet.png` · `cash_sale_details_sheet.png` · `cancel_cash_sale_sheet.png` |

## الغرض
بيعٌ يُخصَم من المخزون ويُقبَض ثمنُه فوراً ⛔ **بلا ذمّة ولا مقوت.** ★ **وحُرَّاسُه المميّزُ هو «الحدُّ الأدنى للسعر النقدي»** المأخوذُ من «التسعير اليومي» — يُعرَض على الحقل، ويُوسَم خطأً، **ويُعطِّل زرَّ الحفظ.**

## العناصر — الشاشة

| # | الـ Widget class الفعلي | الحجم / اللون / الخط / المسافات | الظهور والتفاعل |
|:-:|---|---|---|
| 1 | `Scaffold` + `QtmsTopBar` | `screenTitle: 'البيع النقدي'` | |
| 2 | `FloatingActionButton.extended` «بيع نقدي جديد» | `Icons.point_of_sale_outlined` · خلفية `surfaceInverse` · `elevation: 0` | `PermissionGate(cashSaleCreate)` **ويغيب كلياً إن خلا النطاق من مصدر.** **Trigger** لورقة النموذج. |
| 3 | `QtmsContextHeader` | سطح `surface` بحدٍّ سفلي · حشو أفقي 16 ورأسي 8 | **`allowAllSources: true`** ⟵ بندُ «كل المصادر» موجود. |
| 4 | `DropdownButtonFormField<String>` «المصدر» + `_LockedDay` | منسدلٌ من مكانه · و`Icons.lock_outline` 20 مع التاريخ بأرقامٍ جدولية | |
| 5 | `QtmsSearchField` > `TextField` «بحث برقم السند» | حشو أفقي 16 ورأسي 8 · `prefixIcon: Icons.search` · `suffixIcon: IconButton(Icons.close)` عند وجود نصّ | ⚠️ **مطابقةٌ حرفيةٌ بـ`contains` على رقم المستند** ⛔ بلا `normalizeName` — وهو مناسبٌ لرقمٍ لا لاسم. |
| 6 | `ListView.separated` | حشو 16 · فاصل 8 | |
| 7 | `InventoryTile` > `EntityTile` | سطح `surface` · حدّ 1px · `Radii.card = 20` · حشو 16 · **`actionsPlacement` افتراضي = `stacked`** | العنوان = **رقمُ السند**. |
| 8 | `Text` — الثانوي | `bodyMd` · `textSecondary` | «[اسم المصدر في وضع «كل المصادر»] · N نوع · **{المبلغ} ريال**» ⟵ **فصافي المقبوض ظاهرٌ في القائمة.** |
| 9 | `IconButton` (في `leading`) | سجل التدقيق للسند — بـ`sourceId`. **شرطي.** |
| 10 | `CancelledBadge` · `AmendedBadge` | «ملغى» (`danger` + `cancel_outlined`) · «مُعدَّل» (`warning` + `history_edu_outlined`) | ⛔ **بلا شارةِ «سعر غير نهائي»** — البيعُ النقدي مسعَّرٌ دائماً بحكم بنائه. |
| 11 | `IconButton` — عرض | `Icons.visibility_outlined` · `tooltip: 'عرض السند'` | ⛔ بلا مفتاح صلاحية. **Trigger** لورقة التفاصيل. |
| 12 | `IconButton` — تعديل | `Icons.edit_outlined` · `tooltip: 'تعديل السند'` | `PermissionGate(cashSaleAmend)` **وشرط ألّا يكون ملغى**. **يمرّر `documentNumber`** ⟵ فالورقةُ تقرأ السندَ بعينه. |
| 13 | `IconButton` — إلغاء | `Icons.block_outlined` · **`color: SemanticTriads.danger.ink`** · `tooltip: 'إلغاء السند'` | `PermissionGate(cashSaleCancel)` **وشرط ألّا يكون ملغى**. |
| ⛔ | **بلا زرِّ إرسال** | — | ⚠️ **فارقٌ عن «التوزيع» و«المقبوضات»:** لا `_SendAction` هنا ⟵ **فلا إرسالَ واتساب ولا تصديرَ PDF لسندِ بيعٍ نقدي.** |

## ورقة البيع النقدي — `CashSaleFormSheet`
**Trigger:** الزرُّ العائم ② · زرُّ التعديل ⑫ · **أو الفتحُ التلقائي** من «متبقي الأيام السابقة». البنيةُ ثلاثية: ترويسةٌ ثابتة + `Flexible` > `ListView` + `QtmsStickyActionBar`، بسقف **0.9** من ارتفاع الشاشة.

| # | الـ Widget class | التفاصيل |
|:-:|---|---|
| 1 | `Text` | «بيع نقدي جديد» أو «تعديل السند» — `titleLg`. |
| 2 | `DropdownButtonFormField<String>` «المصدر» | `isExpanded` · **معطَّلٌ في وضع التعديل وفي الوضع المتأخر**. تغييرُه يُفرِّغ كلَّ الأسطر. |
| 3 | `AgedClearanceBanner` | **شرطي — الوضع المتأخر:** تعبئة `warning.soft` · `Radii.card` · `Icons.warning_amber_outlined` 20: «أنت تصرّف مخزون يوم {التاريخ} — سيُحتسب في ضمار ذلك اليوم لا في اليوم الحالي.» |
| 4 | `Text` بلون `danger.ink` | **شرطي:** «هذا السند ملغى — لا يمكن تعديله.» **ويحلّ محلّ محرِّر الأسطر ويُخفي شريطَ الإجراء اللاصق كلَّه.** ⛔ **ولا `_ExistingBanner` هنا** — بخلاف «التوزيع». |
| 5 | `Text` «الأنواع» | `TypeScale.label`/`textSecondary`. |
| 6 | `QtmsItemLineRow` لكل سطر | منسدلُ النوع (`DropdownMenu` ببحثٍ ومرشِّح · `menuHeight = 288`) + `IconButton` حذفٍ (`remove_circle_outline` بـ`danger.ink`) + **حقلان دائماً**. ★ **خياراتُ النوع من أرصدة دفتر اليوم** لا من الكتالوج · والتسميةُ تحمل الرصيد · والمأخوذُ في سطرٍ آخر يُخفى. ⭐ **واختيارُ نوعٍ يُعبِّئ الحدَّ الأدنى سعراً مبدئياً** إن كان الحقلُ فارغاً — ⟵ **فالافتراضُ آمنٌ لا صفرٌ.** |
| 7 | `TextField` «الكمية» | ★ **لوحةُ المفاتيح والمُرشِّح يتغيّران بوحدة النوع:** للكيلوجرام `decimal: true` مع `allow(RegExp(r'[0-9.]'))` · وللحبة `digitsOnly`. **و`suffixText`** = اسمُ الوحدة بعد اختيار النوع. |
| 8 | `TextField` «السعر» | `digitsOnly` · **`suffixText: 'ريال'`** · ⛔ **بلا مفتاح صلاحيةٍ يحجبه** (بخلاف «التوزيع») — فالسعرُ جوهرُ العملية. |
| 9 | **`helperText` على حقل السعر** | ⭐ **يقول الحدَّ لحظياً:** «الحد الأدنى {N}» إن وُجد سعرٌ في تسعير اليوم · و**«غير مسعَّر — لا حدَّ له»** إن لم يُسعَّر النوعُ ⟵ **فالفراغُ مفسَّرٌ لا غامض.** |
| 10 | **`errorText` على حقل السعر** | ⭐ **«أقل من الحد الأدنى»** — يظهر لحظياً بلونٍ `danger` وحدٍّ أحمر بعرض 2 عند التركيز، **مع كل ضغطة مفتاح.** |
| 11 | `Text` | **بديلٌ عند خلوّ المخزون:** «لا مخزون في هذا المصدر اليوم.» |
| 12 | `QtmsAddLineButton` > `OutlinedButton.icon` «إضافة نوع» | **معطَّل** عند بلوغ عددِ الأنواع المتاحة. ⚠️ **ولا يشترط شيئاً آخر** — بخلاف «التوزيع» الذي يشترط اختيارَ مقوتٍ أولاً. |
| 13 | `TextField` «سبب التعديل (اختياري)» | **وضع التعديل فقط** · `blankToNull`. |
| 14 | `Builder` > `QtmsStickyActionBar` | سطح `surface` بحدٍّ علويٍّ · `SafeArea(top: false)` · حشو 16. **يغيب كلياً إن كان السندُ ملغى.** ⚠️ **مُغلَّفٌ بـ`Builder`** لأن حسابَ «دون الحد الأدنى» يجري في مكان البناء. |
| 15 | `QtmsLiveSummary` (في `summary`) | تعبئة `surfaceSunken` · حدّ · `Radii.card` · حشو 12 | ⭐ **ملخّصٌ حيٌّ يتصدّره المبلغ:** «**صافي المقبوض: {N} ريال**» بـ`bodyMd`، ثم «إجمالي الحبات: N حبة» و«إجمالي الأوزان: X كجم» — ★ **إجماليّان منفصلان** — **وسطرٌ رابعٌ شرطي: «سطرٌ دون الحد الأدنى — يلزم تصريحٌ بالبيع دونه».** |
| 16 | `QtmsActionStatus.rejection` (في `status`) | تعبئة `danger.soft` · حدّ `danger.border` · أيقونة `error_outline` 20 · نصّ `bodyMd` بـ`danger.ink` | ⭐ **حالتان بترتيبِ أولوية:** رفضُ الخادم أولاً، **وإلّا** — إن وُجد سطرٌ دون الحدّ — رسالةُ `CatalogMessage.belowMinimumCashPrice`. ⛔ **ولا حالةَ نجاحٍ هنا** (بخلاف «التوزيع») لأن النجاح يُغلِق الورقة. |
| 17 | `FilledButton.icon` | `Icons.save_outlined` · «حفظ السند» أو «حفظ التعديل» · ارتفاع 52. **مُغلَّفٌ بـ`PermissionGate`** يتبدّل مفتاحُه (`cashSaleAmend` تعديلاً و`cashSaleCreate` إنشاءً). ★★ **ومعطَّلٌ قسراً إن وُجد سطرٌ دون الحد الأدنى** (`hasBelowMinimum`) ⟵ **فالحدُّ حرسٌ بنيويٌّ لا تحذيرٌ يُتجاوَز**، وسببُ التعطيل مكتوبٌ في ثلاثة مواضع فوق الزرّ (سطرُ الملخّص · سطرُ الحالة · `errorText` على الحقل نفسه). |

## ورقة تفاصيل السند — `CashSaleDetailsSheet`
**Trigger:** زرُّ العرض ⑪. `SafeArea` > `SingleChildScrollView` بحشو 16.
- `Text` رقمُ السند (`titleLg`) · `QtmsKeyValueRow` للمصدر (**بالاسم**).
- ★ **صفٌّ لكل سطرٍ يعرض المعادلةَ كاملةً:** «{اسم النوع}» ⟷ «**{الكمية} × {السعر} = {الإجمالي} ريال**» ⟵ **فالحسابُ مقروءٌ لا ناتجٌ مجرَّد.**
- ثم «إجمالي الحبات» و«إجمالي الأوزان» و**«صافي المقبوض»**.
- ⛔ **بلا مفتاح صلاحيةٍ على أي صفّ** — بخلاف «قيمة الضمار» في ورقة تفاصيل التوزيع.
- ⚠️ **بلا حالة تحميل ولا خطأ** — البطاقةُ مُمرَّرةٌ جاهزةً.

## ورقة الإلغاء — `CancelCashSaleSheet` > `QtmsDestructiveSheet`
**Trigger:** زرُّ الإلغاء ⑬. العنوان «إلغاء السند {الرقم}» · نصُّ الأثر **يذكر الأثرَ المزدوج**: «الإلغاء يَسِم السند وحركاته ولا يحذف شيئاً، **فتعود الكمية إلى رصيد اليوم ويُستبعَد المبلغ من مقبوضات النقد**.» · سببٌ اختياري · `FilledButton.icon` بخلفية `danger.ink` وأيقونة `warning_amber_outlined` وتسمية «تأكيد الإلغاء» · و`TextButton` «تراجع». **والرفضُ يُعرَض داخل الورقة.**

## الوضع الخاصّ — تصريفُ متأخر
في `addPostFrameCallback` تُقرأ `agedClearanceFocusProvider` وتُستهلَك مرةً واحدة (`take()`)، فيُرشَّح المصدر **وتُفتَح ورقةُ النموذج فوراً** بتاريخِ مخزونٍ مثبَّتٍ ونوعٍ مزروعٍ مسبقاً — **ومنتقي المصدر مقفل**، ولافتةُ `AgedClearanceBanner` ظاهرة. ⛔ **ولا وضعَ «إدخالٍ معلَّق» هنا** (بخلاف «التوزيع») لأن البيعَ النقدي لا يُترَك بلا سعر.

## شجرة الـ Widget tree
```
Scaffold
├── appBar: QtmsTopBar («البيع النقدي»)
├── floatingActionButton: [شرطي] PermissionGate(cashSaleCreate) → FAB.extended
└── Column
    ├── QtmsContextHeader (+ «كل المصادر»)
    │   ├── DropdownButtonFormField «المصدر»
    │   └── _LockedDay
    ├── Padding → QtmsSearchField («بحث برقم السند»)
    └── Expanded
        ├── [لا مصادر] QtmsEmptyState (noSourceInScopeEmpty)
        └── _CashSaleRecords → ValueListenableBuilder → InventoryAsyncView
            ├── hasError → QtmsErrorState
            ├── data []  → QtmsEmptyState («لا مبيعات نقدية اليوم»)
            ├── loading  → SkeletonList
            └── data → [بحثٌ بلا نتيجة] QtmsNoMatch («لا سند بهذا الرقم في نتائج اليوم.»)
                       [وإلا] ListView.separated
                       └── _CashSaleTile → InventoryTile (stacked)
                           ├── leading: [شرطي] IconButton (سجل التدقيق)
                           ├── title: رقم السند · subtitle: [المصدر] · N نوع · المبلغ
                           ├── badges: [CancelledBadge] [AmendedBadge]
                           └── actions:
                               ├── IconButton (visibility) → CashSaleDetailsSheet
                               ├── PermissionGate(cashSaleAmend)  → IconButton (edit)
                               └── PermissionGate(cashSaleCancel) → IconButton (block · danger.ink)
```

## الحالات المُعالجة
| الحالة | الوضع |
|---|---|
| Loading | ✅ `SkeletonList` للقائمة. وأثناء الحفظ يُعطَّل الزرّ ⛔ بلا مؤشّر ولا نصٍّ بديل. |
| Error | ✅ `QtmsErrorState` للقراءة · `QtmsActionStatus.rejection` في الورقة · **و`errorText` على الحقل نفسه** لخرق الحدّ الأدنى. ⚠️ **ورفضُ التحقق المحلي يُختصَر في `operationFailed` عامّة** ⛔ بلا تحديد القاعدة المخروقة. |
| Empty | ✅ **أربعُ حالاتٍ متمايزة:** لا مصدرَ في النطاق · «لا مبيعات نقدية اليوم» · `QtmsNoMatch` («لا سند بهذا الرقم…») · و«لا مخزون في هذا المصدر اليوم.» داخل الورقة. |
| حالةُ الإلغاء | ✅ **مُعالَجةٌ بنيوياً:** نصٌّ أحمر يحلّ محلّ المحرِّر، **وشريطُ الحفظ يغيب كلَّه.** |
| ★ حَرَسُ الحدّ الأدنى | ✅ **مُعالَجٌ في أربعة مستوياتٍ متّسقة:** `helperText` يقول الحدّ · `errorText` يوسم الخرق لحظياً · سطرٌ في الملخّص الحيّ · سطرُ حالةٍ فوق الزرّ · **والزرُّ معطَّلٌ فعلياً.** ⟵ **فالمنعُ لا يُكتشَف بعد الضغط.** |

## آلية التنقل
- **الدخول إليها:** «لوحة اليوم» ⟶ «العمليات اليومية» ⟶ «البيع النقدي» (بمفتاح `cashSaleCreate`) · **ومن «متبقي الأيام السابقة»** بزرّ «بيع نقدي» — **فتُفتَح الورقةُ تلقائياً في الوضع المتأخر.**
- **الخروج منها:** ⛔ **لا مسارَ خارجاً ولا تطبيقٍ خارجي** — ثلاثُ أوراقٍ سفلية هي كلُّ العمق. الرجوع بزرّ النظام.
- **تبعيةٌ متقاطعة:** الحدُّ الأدنى للسعر يُدخَل في [`daily_pricing_screen.md`](daily_pricing_screen.md) — **وبلا تسعيرِ اليوم يصير كلُّ نوعٍ «غير مسعَّر — لا حدَّ له».**

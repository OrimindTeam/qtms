# الجرد

| البند | القيمة |
|---|---|
| **اسم الكلاس** | `StocktakeScreen` (`ConsumerStatefulWidget`) — وجسمُه `_StocktakeBody` يوزّع بين `_StartForm` و`_CountForm` |
| **مسار الملف** | `lib/capabilities/inventory/presentation/stocktake_screen.dart` |
| **المسار الملاحي** | `/home/stocktake` — `stocktakeRoute` |
| **اسم الشاشة في الشريط** | «الجرد» |
| **أسماء اللقطات المتوقّعة** | `stocktake_start_form.png` · `stocktake_count_form.png` |

## الغرض
جردٌ على **مرحلتَين في شاشةٍ واحدة**: ① **البدء** — اختيارُ الأنواع فيُجمَّد رصيدُها الدفتري، ② **العدّ والاعتماد** — إدخالُ العدّ الفعلي فيُحسَب الفرقُ على الرصيد المُجمَّد. **والشاشةُ تختار مرحلتَها تلقائياً** بوجود مسوّدةٍ مفتوحة أو غيابها ⛔ **بلا تبويبٍ ولا زرِّ تبديل.**

## العناصر — الهيكل المشترك

| # | الـ Widget class الفعلي | الحجم / اللون / الخط / المسافات | الظهور والتفاعل |
|:-:|---|---|---|
| 1 | `Scaffold` + `QtmsTopBar` | `screenTitle: 'الجرد'` · ⛔ بلا زرٍّ عائم | |
| 2 | `QtmsEmptyState` — بلا صلاحية | `Icons.lock_outline` في `IconBadgeBox` 64 · «لا صلاحية» + «ليست لديك صلاحية تنفيذ الجرد — راجع مالك النظام.» | **بديلُ الشاشة كلِّها** عند غياب `stocktakeWrite`. |
| 3 | `_SourceHeader` > `DropdownButtonFormField<String>` «المصدر» | `key: Key('stocktake-source')` · حشو أفقي 16 ورأسي 8 | ⚠️ **منتقي مصدرٍ خاصٌّ بالشاشة** ⛔ **لا `QtmsContextHeader`.** |
| 4 | `Divider` | 1px بلون `divider` | |
| 5 | `QtmsEmptyState` — بلا مصدر | `Icons.store_outlined` · «اختر المصدر» + «الجرد يقع على مصدرٍ واحد ويومٍ واحد — والمخزون مستقلٌّ في كل مصدر.» | نصٌّ خاصٌّ بالشاشة. |
| 6 | `QtmsStickyActionBar` | سطح `surface` بحدٍّ علويٍّ `border` · `SafeArea(top: false)` · حشو 16 | **في كلتا المرحلتين** — يحمل ملخّصاً حياً وحالةً وزرّاً أساسياً. |

## المرحلة ① — `_StartForm` (بدء الجرد)

| # | الـ Widget class | التفاصيل |
|:-:|---|---|
| أ | `_FreezeNotice` > `_Notice` > `Container` | تعبئة `warning.soft` · حدّ `warning.border` · **`Radii.md = 14`** · حشو 12 · `Icons.lock_clock_outlined` 20 بـ`warning.ink`: «بدء الجرد يُجمِّد الرصيد الدفتري للأنواع المختارة — والفرق يُحسَب عليه لا على رصيدٍ يتغيّر أثناء العدّ.» |
| ب | `_PriorDayRow` > `Row` | **شرطي على `stocktakePriorDay`:** `Icons.event_outlined` + `Text` «تاريخ المخزون المجرود: {التاريخ}» بـ`bodyMd` + `TextButton` «تغيير» (`key: Key('stocktake-date')`). |
| ج | `showDatePicker` | **حوارُ تاريخٍ من الإطار** (Dialog). ★ **نطاقُه محدودٌ صراحةً:** `firstDate` = بداية العام الماضي · **`lastDate` = اليوم** ⟵ **فلا تاريخَ مستقبلي.** واختيارُ اليومِ نفسِه يُعيد الحالةَ إلى `null` (وضعُ اليوم العادي). |
| د | `Text` | **بديلُ ب لمن لا يملك المفتاح:** «تاريخ المخزون المجرود: {التاريخ}» — نصٌّ للقراءة وحده. |
| هـ | `Text` «الأنواع المطلوب جردها» | `TypeScale.titleSm`. |
| و | `Text` | **بديلٌ عند الفراغ:** «لا نوعَ بعد — أضف ما ستعدّه فعلياً في المخزن.» بـ`TypeScale.caption`. |
| ز | `QtmsItemLineRow` لكل سطر | ⚠️ **بلا حقولٍ إضافية إطلاقاً** (`fields` غير مُمرَّرة) ⟵ **فالمرحلةُ الأولى اختيارُ أنواعٍ فقط لا إدخالُ أعداد.** منسدلُ النوع + زرُّ حذفٍ (`remove_circle_outline` بـ`danger.ink`). |
| ح | خياراتُ النوع | ★ **من أرصدة الدفتر** (`stockOptionsProvider`) لا من الكتالوج · والتسميةُ تحمل الرصيد المتبقّي. **والمأخوذُ في سطرٍ آخر يُخفى** (`optionsForRow`). |
| ط | `QtmsAddLineButton` | `key: Key('stocktake-add-line')` · «إضافة نوع» · ⚠️ بلا حدٍّ أقصى. |
| ي | `TextField` «سبب الجرد» | `key: Key('stocktake-reason')` · `helperText: 'اختياري — ولا يُكتب نيابةً عنك'`. |
| ك | `QtmsLiveSummary` | «أنواعٌ مختارة: N» + سطران: «تاريخ المخزون: {التاريخ}» · «يُجمَّد الرصيد الدفتري لحظة البدء». |
| ل | `Text` (في `status`) | ⚠️ نصٌّ عارٍ بـ`bodyMd` — «✅ بدأ الجرد {الرقم}» أو «❌ اختر نوعاً واحداً على الأقل لجرده.» أو نصُّ الخطأ. |
| م | `FilledButton` | `key: Key('stocktake-start')` · نصُّه «بدء الجرد» ⟶ **«جارٍ البدء…»** أثناء الإرسال. |

## المرحلة ② — `_CountForm` (العدّ والاعتماد)

| # | الـ Widget class | التفاصيل |
|:-:|---|---|
| أ | `_OpenDraftBanner` > `_Notice` | تعبئة `warning.soft` · `Radii.md` · `Icons.pending_actions_outlined`: «جردٌ مفتوح {الرقم} بتاريخ مخزون {التاريخ} — أتمَّه أو ألغِه قبل بدء جردٍ آخر على هذا المصدر واليوم.» ⟵ **فالحصرُ مشروحٌ لا مفروضٌ بصمت.** |
| ب | `Text` «العدّ الفعلي» | `titleSm`. |
| ج | `_CountRow` لكل سطرٍ في المسوّدة | حشو سفلي 16 · **بلا حاويةٍ ولا حدٍّ** (⚠️ ليست بطاقة). |
| د | `Text` — اسم النوع | `bodyMd` · من `ledgerItemDisplayName` (**المفتاح المركّب**). |
| هـ | `Text` — الرصيد المُجمَّد | `TypeScale.caption` — «الرصيد الدفتري المُجمَّد: {الكمية}» ⟵ **معروضٌ بجوار الحقل** فلا يُحسَب الفرقُ في الرأس. |
| و | `TextField` «العدّ الفعلي» | `key: Key('stocktake-count-{itemKey}')` · `keyboardType: number` · يُعيد البناء مع كل ضغطة. **والكسرُ في نوعٍ عدديٍّ يُهمَل السطرُ** فيمنع الاعتماد. |
| ز | `Text` — الفرق | `caption` · **يظهر لحظياً بعد الإدخال:** «الفرق: مطابق» أو «الفرق: نقص {الكمية}» أو «الفرق: زيادة {الكمية}» ⟵ **فالمستخدم يرى النتيجةَ قبل الاعتماد.** |
| ح | `TextField` «سبب الفرق» | `key: Key('stocktake-diff-reason-{itemKey}')` · `helperText: 'اختياري — ولا يُكتب نيابةً عنك'` · **حقلٌ لكل سطرٍ مستقلاً.** |
| ط | `TextField` «ملاحظة على الجرد» | `key: Key('stocktake-approve-reason')` · حقلٌ واحدٌ للمستند كلِّه · اختياري. |
| ي | `TextButton` «إلغاء الجرد {الرقم}» | `key: Key('stocktake-cancel')` · **`foregroundColor: SemanticTriads.danger.ink`** · **شرطي على `stocktakeCancel`**. ⚠️★ **بلا ورقةِ تأكيدٍ إطلاقاً** ⛔ **لا `showQtmsDestructiveSheet`** — ضغطةٌ واحدةٌ تُلغي المسوّدة، بخلاف إلغاء الوارد والجونية. |
| ك | `QtmsLiveSummary` | «أنواعٌ مجرودة: N» + سطران: «تاريخ المخزون: {التاريخ}» · **«التسوية لا تدخل المبيعات ولا سعر الجونية ولا الرعوي»**. |
| ل | `FilledButton` | `key: Key('stocktake-approve')` · ★ **نصُّه رباعيُّ الحالات:** **«الاعتماد يحتاج صلاحية»** (بلا `stocktakeApprove` — ⟵ **فالتعطيلُ مفسَّرٌ في نصّ الزرّ نفسه**) · «جارٍ الاعتماد…» · «جارٍ الإلغاء…» · «اعتماد الجرد». **ويُعطَّل** إن لم يملك المفتاح أو أثناء أي عملٍ جارٍ (`_InFlight`). |
| م | حرسُ الاكتمال | ⚠️ الاعتمادُ يشترط **عدّاً فعلياً لكل سطر**؛ وإن نقص واحدٌ ظهر «❌ أدخل العدّ الفعلي لكل نوعٍ في هذا الجرد.» ⛔ **بلا إشارةٍ إلى أيِّ سطرٍ ناقص.** |

## شجرة الـ Widget tree
```
Scaffold (بلا FAB)
├── appBar: QtmsTopBar («الجرد»)
└── body
    ├── [بلا stocktakeWrite] QtmsEmptyState («لا صلاحية»)
    └── Column
        ├── _SourceHeader → DropdownButtonFormField «المصدر»
        ├── Divider (1px)
        └── Expanded
            ├── [بلا مصدر] QtmsEmptyState («اختر المصدر»)
            └── _StocktakeBody  ← يوزّع بحسب وجود مسوّدةٍ مفتوحة
                ├── hasError → QtmsErrorState
                ├── loading  → SkeletonList
                ├── [بلا مسوّدة] _StartForm → Column
                │   ├── Expanded → ListView (16)
                │   │   ├── _FreezeNotice (warning · lock_clock_outlined)
                │   │   ├── [شرطي stocktakePriorDay] _PriorDayRow → TextButton «تغيير» → showDatePicker
                │   │   │   [وإلا] Text (التاريخ للقراءة)
                │   │   ├── Text «الأنواع المطلوب جردها»
                │   │   ├── QtmsItemLineRow × N (منسدل النوع فقط · بلا حقول)
                │   │   ├── QtmsAddLineButton
                │   │   └── TextField «سبب الجرد»
                │   └── QtmsStickyActionBar
                │       ├── summary: QtmsLiveSummary («أنواعٌ مختارة: N» + سطران)
                │       ├── status:  [شرطي] Text (✅/❌)
                │       └── primary: FilledButton («بدء الجرد» | «جارٍ البدء…»)
                └── [مسوّدة مفتوحة] _CountForm → Column
                    ├── Expanded → ListView (16)
                    │   ├── _OpenDraftBanner (warning · pending_actions_outlined)
                    │   ├── Text «العدّ الفعلي»
                    │   ├── _CountRow × N
                    │   │   ├── Text (اسم النوع) + Text (الرصيد المُجمَّد — caption)
                    │   │   ├── TextField «العدّ الفعلي»
                    │   │   ├── [شرطي] Text «الفرق: مطابق | نقص … | زيادة …»
                    │   │   └── TextField «سبب الفرق»
                    │   ├── TextField «ملاحظة على الجرد»
                    │   └── [شرطي stocktakeCancel] TextButton «إلغاء الجرد …» (danger.ink · بلا تأكيد)
                    └── QtmsStickyActionBar
                        ├── summary: QtmsLiveSummary («أنواعٌ مجرودة: N» + سطران)
                        ├── status:  [شرطي] Text
                        └── primary: FilledButton (4 نصوص · «الاعتماد يحتاج صلاحية» عند غياب المفتاح)
```

## الحالات المُعالجة
| الحالة | الوضع |
|---|---|
| Loading | ✅ `SkeletonList` لقراءة الجرود، **ونصُّ الزرِّ المتغيّر** لكل عملٍ جارٍ («جارٍ البدء…» · «جارٍ الاعتماد…» · «جارٍ الإلغاء…») ⟵ **فالمستخدم يعرف أيَّ عملٍ ينتظر** لا مجرّد أن شيئاً يجري. |
| Error | ✅ `QtmsErrorState` للقراءة + سطرُ حالةٍ نصّيٍّ للكتابة. ⚠️ **بلا ثلاثيةِ لونٍ لسطر الحالة** (الرمز `✅`/`❌` وحده). |
| Empty | ✅ **ثلاثُ حالاتٍ متمايزة:** «لا صلاحية» · «اختر المصدر» · «لا نوعَ بعد» (نصٌّ داخليٌّ بـ`caption`). |
| منعٌ بالصلاحية | ✅ **على ثلاثة مستويات مختلفة:** الشاشةُ كلُّها (`stocktakeWrite`) · تغييرُ التاريخ (`stocktakePriorDay`) · الاعتمادُ (`stocktakeApprove` — **بنصٍّ في الزرّ**) · والإلغاءُ (`stocktakeCancel`). |
| ⚠️ **فجوةٌ في التأكيد** | ⛔ **إلغاءُ الجرد بلا أي ورقةِ تأكيد** — فعلٌ يمسّ مستنداً بضغطةٍ واحدة، بخلاف إلغاء الوارد والجونية اللذين يمرّان بـ`QtmsDestructiveSheet`. |

## آلية التنقل
- **الدخول إليها:** «لوحة اليوم» ⟶ «العمليات اليومية» ⟶ «الجرد» (بمفتاح `stocktakeWrite`).
- **الخروج منها:** ⛔ **لا مسارَ خارجاً ولا ورقةَ سفلية** — و`showDatePicker` هو الحوارُ الوحيد. الرجوع بزرّ النظام.

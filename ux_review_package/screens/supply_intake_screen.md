# التوريد مخزني (شاشة بتبويبَين)

| البند | القيمة |
|---|---|
| **اسم الكلاس** | `SupplyIntakeScreen` (`ConsumerStatefulWidget` + `SingleTickerProviderStateMixin`) |
| **مسار الملف** | `lib/capabilities/inventory/presentation/supply_intake_screen.dart` |
| **ملف التبويب الأول** | `lib/capabilities/inventory/presentation/counted_intake_screen.dart` — `CountedIntakeTab` |
| **ملف التبويب الثاني** | `lib/capabilities/inventory/presentation/sack_intake_screen.dart` — `SackIntakeTab` |
| **المسار الملاحي** | `/home/supply` — `supplyIntakeRoute` · **ويستقبل `state.extra` عدداً** لاختيار التبويب المبدئي |
| **اسم الشاشة في الشريط** | `supplyIntakeScreenTitle` = «التوريد مخزني» |
| **أسماء اللقطات المتوقّعة** | `supply_intake_counted_tab.png` · `supply_intake_sack_tab.png` · `counted_intake_form_sheet.png` · `sack_header_form_sheet.png` · `sack_lines_form_sheet.png` · `cancel_intake_sheet.png` |

## الغرض
مدخلُ الوارد بطريقتَيه في شاشةٍ واحدة: **«الوارد عدداً»** (حبّاتٌ تدخل المخزن مباشرةً) و**«الوارد جواني»** (رأسٌ بأوزانه أولاً، ثم أنواعه لاحقاً). والتبويبان يتشاركان **ترويسة سياقٍ واحدة** (المصدر + تاريخ اليوم المقفل) ⛔ **ولا يحمل كلٌّ منهما منتقيَ مصدرٍ خاصّاً به.**

## العناصر — هيكل الشاشة

| # | الـ Widget class الفعلي | الحجم / اللون / الخط / المسافات | الظهور والتفاعل |
|:-:|---|---|---|
| 1 | `Scaffold` + `QtmsTopBar` | `screenTitle: 'التوريد مخزني'` | |
| 2 | `QtmsContextHeader` | سطح `surface` بحدٍّ سفليٍّ `border` 1px · حشو أفقي 16 ورأسي 8 · سقف الارتفاع `kContextHeaderMaxHeight = 96` | ترويسةُ السياق أعلى التبويبات. |
| 3 | `DropdownButtonFormField<String>` — «المصدر» | `isDense: true` · `isExpanded: true` · النصّ بـ`ellipsis` · `hint: 'اختر المصدر'` | **منسدلٌ من مكانه.** `allowAllSources: true` هنا ⟵ **فأول بندٍ «كل المصادر»** يعرض وارد كل المصادر في نطاق المستخدم. |
| 4 | `_LockedDay` > `Row` | `Icons.lock_outline` 20 بـ`textSecondary` + التاريخ بـ`TypeScale.numeric` (أرقام جدولية) بـ`textSecondary` | **تاريخُ اليوم من الخادم، غيرُ قابلٍ للتغيير.** له `Semantics` يقول: «تاريخ اليوم … — من الخادم ولا يُغيَّر». |
| 5 | `_NoScopeNotice` | `Icons.info_outline` 20 + نصّ `bodyMd`/`textSecondary` · حشو 16 | **بديل الترويسة كلها** إذا خلا نطاقُ المستخدم من أي مصدر: «لا يوجد مصدر ضمن نطاقك. راجع المدير.» |
| 6 | `TabBar` | مؤشّرٌ **خطٌّ سفليٌّ** بلون `primary500` بعرض التبويب (`TabBarIndicatorSize.tab`) · **المؤشّر موجودٌ في الحالتين فلا تقفز التبويبات** · التسمية النشطة `titleSm`/`textPrimary` والخامدة `bodyMd`/`textSecondary` · فاصلٌ سفلي بلون `divider` | تبويبان: «الوارد عدداً» · «الوارد جواني». **والشكلُ كلُّه من الثيم لا من الشاشة.** |
| 7 | `Expanded` > `TabBarView` | — | يحمل `CountedIntakeTab` و`SackIntakeTab`. |
| 8 | `floatingActionButton` **متبادل** | — | ⚠️★ **الزرُّ العائم يتغيّر بتغيُّر التبويب:** `CountedIntakeFab` عند الفهرس 0 و`SackIntakeFab` عند 1 — بمستمعٍ على `TabController` يُعيد البناء. |

## التبويب الأول — «الوارد عدداً»

| # | الـ Widget class | التفاصيل |
|:-:|---|---|
| أ | `CountedIntakeFab` > `FloatingActionButton.extended` «وارد جديد» | `Icons.add_box_outlined` · خلفية `surfaceInverse` · `elevation: 0`. `PermissionGate(incomingCountWrite)`، **ويغيب كلياً إن خلا النطاق من مصدر.** يمرّر المصدرَ المرشَّح (المختارُ، أو أول مصدر عند «كل المصادر»). |
| ب | `InventoryAsyncView<CountedIntakeCard>` | موزّع الحالات بثلاثية `inventory` (cat3 بنفسجي). |
| ج | `ListView.separated` | حشو 16 · فاصل `Spacing.space8` = 8. |
| د | `InventoryTile` > `EntityTile` | العنوان = **رقم المستند**. الثانوي مركَّبٌ بفواصل ` · `: [اسم المصدر — **فقط في وضع «كل المصادر»**] · «N نوع» · إجمالي الحبّات. |
| هـ | `IconButton` (في `leading`) | سجل التدقيق للمستند — بـ`sourceId`. **شرطي.** |
| و | `CancelledBadge` / `AmendedBadge` > `StatusPill` | «ملغى» (`danger` + `cancel_outlined`) · «مُعدَّل» (`warning` + `history_edu_outlined`). **شرطيّان.** |
| ز | `IconButton` — تعديل | `Icons.edit_outlined` · `tooltip: 'تعديل الوارد'`. `PermissionGate(incomingCountAmend)` **وشرط ألّا يكون ملغى.** |
| ح | `IconButton` — إلغاء | `Icons.block_outlined` · `tooltip: 'إلغاء الوارد'`. `PermissionGate(incomingCountCancel)` **وشرط ألّا يكون ملغى.** |

### ورقة «وارد عدداً» — `CountedIntakeFormSheet`
**Trigger:** الزرُّ العائم أ (إنشاء) أو زرُّ التعديل ز. `showModalBottomSheet` بـ`isScrollControlled` · انحناء علوي 28 · حشو سفلي `viewInsets.bottom` · `SingleChildScrollView` بحشو 16.

| # | الـ Widget class | التفاصيل |
|:-:|---|---|
| 1 | `Text` | «وارد عدداً جديد» أو «تعديل وارد عدداً» — `titleLg`. |
| 2 | `LockedDayBanner` > `Container` | تعبئة `surfaceSunken` · حدّ `border` · `Radii.card = 20` · حشو 12 · هامش أفقي 16 · `Icons.lock_outline` 20 + «تاريخ اليوم … — من الخادم ولا يُغيَّر.» |
| 3 | `DropdownButtonFormField<String>` «المصدر» | `isExpanded` · **معطَّلٌ كلياً في وضع التعديل** (`onChanged: null`) ⟵ فلا يُنقَل مستندٌ بين مصدرَين. وتغييرُه إنشاءً **يُفرِّغ الرعوي وكل الأسطر** لأن الأنواع تختلف بالمصدر. |
| 4 | `Text` «الرعوي» + `Wrap` > `ChoiceChip` | **شرطي:** يظهر فقط إذا `source.requiresSupplierOnIntake`. الشريحة النشطة بتعبئة `primary50` وعلامة صحّ `primary700` · `StadiumBorder` · فاصل 8. |
| 5 | `Text` «الأنواع» | `TypeScale.label`/`textSecondary`. |
| 6 | `QtmsItemLineRow` لكل سطر | **صفٌّ مركَّب:** `DropdownMenu<String>` بعرض الحاوية (`enableFilter` و`enableSearch` و`requestFocusOnTap` · `menuHeight = 72 × 4 = 288`) **+ `IconButton` حذفٍ** (`Icons.remove_circle_outline` بلون `danger.ink` · `tooltip: 'حذف السطر'` · 48×48) **+ صفُّ حقول** أسفلَه. حشو سفلي للصفّ 12. |
| 7 | `TextField` «العدد» | `keyboardType: numberWithOptions()` — **صحيحٌ لا عشري.** |
| 8 | تسميةُ خيار النوع | **تحمل الرصيد المتبقّي:** `itemOptionLabel` يُنتج «بطّوه (120 حبة)». وتُخفي الأنواع المأخوذة في أسطرٍ أخرى (`optionsForRow`) ⟵ **فلا يُكرَّر نوعٌ في مستندٍ واحد.** |
| 9 | `QtmsAddLineButton` > `OutlinedButton.icon` «إضافة نوع» | `Icons.add` · مُحاذٍ للبداية. **معطَّل** عندما بلغ عددُ الأسطر عددَ الأنواع المتاحة. |
| 10 | `Text` | **بديلٌ عند غياب الأنواع:** «لا توجد أنواع مرتبطة بهذا المصدر.» |
| 11 | `TextField` «ملاحظات (اختياري)» | |
| 12 | `TextField` «سبب التعديل (اختياري)» | **تعديلاً فقط** · `blankToNull`. |
| 13 | `_Rejection` > `QtmsInlineBanner` (`danger`) | **شرطي.** ★ **ورسائلُه محدَّدةٌ بقاعدةٍ لا عامّة:** `FR-M6-03` ⟶ «الرعوي مطلوب لهذا المصدر» · `BR-M6-05` ⟶ «النوع مكرَّر في المستند» · `BR-M6-06` ⟶ «العدد لا يقبل كسراً». |
| 14 | `FilledButton` | «اعتماد» أو «حفظ التعديل» — ارتفاع 52. |

### ورقة إلغاء الوارد — `CancelIntakeSheet` > `QtmsDestructiveSheet`
**Trigger:** زرُّ الإلغاء ح. العنوان «إلغاء {رقم المستند}» · نصُّ الأثر «الإلغاء يَسِم المستند وحركاته ولا يحذف شيئاً، ويُشترط توفّر الكمية غير المصروفة.» · `reasonLabel: 'سبب الإلغاء (اختياري)'` ⛔ **بلا حقلٍ إلزامي** · زرُّ التأكيد `FilledButton.icon` بخلفية `danger.ink` وأيقونة `warning_amber_outlined` وتسمية «تأكيد الإلغاء» · وتحته `TextButton` «تراجع». **والرفضُ يُعرَض داخل الورقة نفسها** (`QtmsActionStatus.rejection`) ⛔ **فلا تُغلَق الورقة على خطأ.**

## التبويب الثاني — «الوارد جواني»

| # | الـ Widget class | التفاصيل |
|:-:|---|---|
| أ | `SackIntakeFab` > `FloatingActionButton.extended` «جونية جديدة» | `Icons.inventory_2_outlined`. `PermissionGate(sackCreate)`. |
| ب | `InventoryAsyncView<SackCard>` > `EntityList` | حشو أفقي متجاوب · سفلي 96 · فاصل 12. |
| ج | `InventoryTile` | العنوان = `sack.displayName`. الثانوي: [اسم المصدر] · رقم المستند · «المطالب به X كجم» · «N نوع». |
| د | **أربع شارات محتملة** | `CancelledBadge` · `AmendedBadge` · **`_WeightStateBadge`** (ثلاث حالات: «مفسَّر بالكامل» بثلاثية `primary` و`check_circle_outline` · «متبقٍ X كجم» بـ`warning` و`pending_outlined` · «ضائع X كجم» بـ`danger` و`report_problem_outlined`) · **`_PendingPriceBadge`** («سعر غير نهائي» بـ`warning` و`schedule_outlined`) — شرطُها ألّا يكون التسعير مكتملاً مع وجود أسطر. |
| هـ | `TextButton.icon` «الأنواع» | `Icons.list_alt_outlined` 20 — **نصٌّ مع أيقونة** بخلاف تبويب المعدود. `PermissionGate(sackLinesEnter)`. **Trigger** لورقة الأنواع. |
| و | `TextButton.icon` «إلغاء» | `Icons.block_outlined` 20 · **`foregroundColor: danger.ink`** صراحةً. `PermissionGate(sackCancel)`. |

### ورقة رأس الجونية — `SackHeaderFormSheet`
**Trigger:** الزرُّ العائم أ. **بنيةٌ ثلاثية ثابتة:** ترويسةٌ ثابتة + جسمٌ متمرّر (`Flexible` > `SingleChildScrollView`) + **شريطُ إجراءٍ لاصقٌ أسفل** (`QtmsStickyActionBar`) · و`ConstrainedBox(maxHeight: 0.9 × ارتفاع الشاشة)`.

| # | الـ Widget class | التفاصيل |
|:-:|---|---|
| 1 | `Text` «جونية جديدة» | `titleLg` — في الترويسة الثابتة. |
| 2 | `LockedDayBanner` | في الترويسة الثابتة. |
| 3 | `QtmsLiveSummary` — **ملخّصٌ حيٌّ** | تعبئة `surfaceSunken` · حدّ `border` · `Radii.card` · حشو 12. يقول «الوزن المطالب به: X كجم» **ويُحسَب مع كل ضغطة مفتاح** (كلُّ حقل وزنٍ يستدعي `setState`). وعند مخالفة منطق الأوزان يصير «الوزن المطالب به: —» **مع سطر رفضٍ داخله** (أيقونة `error_outline` 16 + نصّ `label` بـ`danger.ink`). |
| 4 | `DropdownButtonFormField<String>` «المصدر» | يسبقه `_FieldLabel('المصدر')`. تغييرُه يُفرِّغ الرعويّ. |
| 5 | `_FieldLabel` + `Wrap` > `ChoiceChip` — «الرعوي» | **شرطي** على `requiresSupplierOnIntake`. |
| 6 | `_FieldLabel('الأوزان (كجم)')` + ثلاثة × `_WeightField` > `TextField` | «الوزن الكلي» · «وزن الثلج» (مبدئياً `'0'`) · **«وزن السكرب»** (مبدئياً `'0'`) — والثالث **مُغلَّفٌ بـ`PermissionGate(sackScrapWeightEnter)`** فيغيب عمّن لا يملكه. `keyboardType: numberWithOptions(decimal: true)` · حشو سفلي 8 لكلٍّ. |
| 7 | `TextField` «ملاحظات (اختياري)» | |
| 8 | `Text` تفسيري | «يُحفَظ الرأس أولاً ويدخل السكرب المخزن فوراً، ثم تُدخَل الأنواع.» — `bodyMd`/`textSecondary`. |
| 9 | `QtmsStickyActionBar` | سطح `surface` بحدٍّ علويٍّ `border` · `SafeArea(top: false)` · حشو 16. يحمل `FilledButton` «حفظ الرأس»، وفوقه `QtmsActionStatus.rejection` عند الرفض. |

### ورقة أنواع الجونية — `SackLinesFormSheet`
**Trigger:** زرُّ «الأنواع» هـ. نفس البنية الثلاثية (ترويسة + جسم متمرّر + شريط لاصق) بسقف 0.9 من الشاشة.

| # | الـ Widget class | التفاصيل |
|:-:|---|---|
| 1 | `Text` «أنواع {displayName}» | `titleLg`. |
| 2 | `QtmsLiveSummary` — **ملخّصٌ حيٌّ بشريط تقدُّم** | «فُسِّر X من Y كجم» + **`LinearProgressIndicator`** بارتفاع 8 و`Radii.field` مقصوصاً، نسبتُه محسوبةٌ ومحدودة بين 0 و1 + **`StatusPill` بحالة الوزن الثلاثية** + **إجراءٌ شرطيٌّ داخل الملخّص**. |
| 3 | `OutlinedButton.icon` «تأكيد الوزن الضائع (X كجم)» | `Icons.report_problem_outlined`. **شرطيٌّ مزدوج:** يظهر **فقط** عندما تكون الحالة `unexplained` **و**يملك المستخدم `sackLostWeightConfirm`. ⟵ ★ **فالوزن الضائع لا يُسجَّل إلا بزرٍّ صريح** ⛔ **ولا يُستنتَج من فرق الأوزان.** |
| 4 | `_SackLineRow` > `QtmsItemLineRow` لكل سطر | منسدلُ النوع + زرُّ الحذف + **حقلان يتغيّران بطبيعة النوع**. |
| 5 | `TextField` «العدد» | `numberWithOptions()` — لكل الأسطر. |
| 6 | `TextField` «الوزن الكلي (كجم)» بـ`helperText: 'وزن الحبة يُستنتَج'` | **للنوع العدديّ فقط** (`countBased`) · عشري. |
| 7 | `TextField` «وزن الحبة (جم)» | **للنوع الوزنيّ فقط** · عشري · **مُغلَّفٌ بـ`PermissionGate(sackLinesEnter)`** · ومُعبَّأٌ مسبقاً بالوزن الافتراضي للنوع إن وُجد. ⛔★ **ولا يُستنتَج وزنُ حبةِ نوعٍ وزنيٍّ من الوزن الكلي إطلاقاً** — والحالة تُقرَّر من `ItemNature` لا من امتلاء الحقول. |
| 8 | `QtmsAddLineButton` | معطَّل عند بلوغ عدد الأنواع. |
| 9 | `TextField` «سبب التعديل (اختياري)» | `blankToNull`. |
| 10 | `QtmsStickyActionBar` | `FilledButton` «حفظ الأنواع» + سطرُ الرفض عند الحاجة. |
| 11 | تحقُّقٌ محلّيٌّ قبل الإرسال | ⚠️ إن تجاوز مجموعُ الأسطر الوزنَ المطالب به يُرفَض محلياً بـ`CatalogMessage.sackWeightExceeded` ⛔ **بلا نداء شبكة.** ★ **ورسائلُ الرفض كلُّها مربوطةٌ بقواعدها** (`sackRejectionMessage`): ثمانِ قواعدٍ لكلٍّ رسالتُها (`E-08` ⟶ «وزن الحبة مفقود» · `E-09`/`FR-M7-13` ⟶ «السطر العدديّ يحتاج وزناً كلياً» · `BR-M7-08` ⟶ «الوزن تجاوز المطالب به» …). |

### ورقة إلغاء الجونية — `CancelSackSheet` > `QtmsDestructiveSheet`
**Trigger:** زرُّ «إلغاء» و. العنوان «إلغاء {displayName}» · الأثر «الإلغاء يَسِم الجونية وحركاتها ولا يحذف شيئاً، ويُشترط توفّر الكمية غير المصروفة.» · سببٌ اختياري · تأكيدٌ أحمر «تأكيد الإلغاء» · والرفض يُعرَض داخل الورقة.

## شجرة الـ Widget tree
```
Scaffold
├── appBar: QtmsTopBar («التوريد مخزني»)
├── floatingActionButton: (index==0) ? CountedIntakeFab : SackIntakeFab
└── Column
    ├── QtmsContextHeader
    │   ├── DropdownButtonFormField «المصدر» (+ «كل المصادر»)
    │   ├── _LockedDay (lock_outline + التاريخ بأرقام جدولية)
    │   └── [بديل] _NoScopeNotice («لا يوجد مصدر ضمن نطاقك…»)
    ├── TabBar (خط سفلي primary500 · «الوارد عدداً» | «الوارد جواني»)
    └── Expanded → TabBarView
        ├── CountedIntakeTab
        │   ├── [لا مصادر] QtmsEmptyState (noSourceInScopeEmpty)
        │   └── _IntakeList → InventoryAsyncView → ListView.separated
        │       └── _IntakeTile → InventoryTile → EntityTile
        │           ├── leading: [شرطي] IconButton (سجل التدقيق)
        │           ├── title/subtitle: رقم المستند · [المصدر] · N نوع · الإجمالي
        │           ├── badges: [CancelledBadge] [AmendedBadge]
        │           └── actions: IconButton(edit) · IconButton(block)
        └── SackIntakeTab
            ├── [لا مصادر] QtmsEmptyState
            └── _SackList → InventoryAsyncView → EntityList
                └── _SackTile → InventoryTile
                    ├── badges: [Cancelled] [Amended] [_WeightStateBadge] [_PendingPriceBadge]
                    └── actions: TextButton.icon «الأنواع» · TextButton.icon «إلغاء» (أحمر)
```

## الحالات المُعالجة
| الحالة | الوضع |
|---|---|
| Loading | ✅ `SkeletonList` في كلا التبويبين (عبر `AsyncStateView`). وأثناء الإرسال تُعطَّل أزرارُ الأوراق ⛔ بلا مؤشّر دوران. |
| Error | ✅ `QtmsErrorState` برسالةٍ إرشاديةٍ موحّدة في المخزون: «تحقق من صلاحيتك ونطاق مصادرك، ثم أعد المحاولة.» + «تفاصيل تقنية». ⚠️ **بلا زرّ إعادة محاولة.** ★ **ورفضُ الأوراق محدَّدٌ بقاعدة لا عامّاً** — أحدَ عشرَ رمزَ قاعدةٍ لكلٍّ رسالتُه. |
| Empty | ✅ **ثلاث حالاتٍ فارغةٍ متمايزة:** «لا وارد اليوم» (تبويب المعدود) · «لا توجد جواني اليوم» (تبويب الجواني) · **و`noSourceInScopeEmpty`** («لا يوجد مصدر ضمن نطاقك») تسبقهما إن خلا النطاق. **وحالةٌ رابعةٌ داخل الأوراق:** «لا توجد أنواع مرتبطة بهذا المصدر.» |

## آلية التنقل
- **الدخول إليها:** «لوحة اليوم» ⟶ «العمليات اليومية» ⟶ «التوريد مخزني» (بمفتاح `incomingCountWrite` **أو** `sackCreate`) · **ومن «الإدخالات المعلّقة»** — `pendingScreenRoute(PendingScreen.sackIntake)` يعيد هذا المسار **ويمرّر التبويب المطلوب في `extra`**.
- **الخروج منها:** ⛔ **لا مسارَ خارجاً** — كلُّ العمل في خمس أوراقٍ سفلية. الرجوع بزرّ النظام.

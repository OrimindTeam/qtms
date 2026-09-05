# الإدخالات المعلّقة

| البند | القيمة |
|---|---|
| **اسم الكلاس** | `PendingEntriesScreen` (`ConsumerWidget`) |
| **مسار الملف** | `lib/capabilities/oversight/presentation/pending_entries_screen.dart` |
| **المسار الملاحي** | `/home/pending` — `pendingEntriesRoute` |
| **اسم الشاشة في الشريط** | «الإدخالات المعلّقة» |
| **اسم اللقطة المتوقّع** | `pending_entries_screen.png` |

## الغرض
**مركزُ تذكيرٍ لا مركزُ منع** — يجمع كلَّ قيمةٍ تُركت «لاحقاً» (سعرُ سطرِ توزيعٍ · تسعيرُ اليوم · بندُ جونية · بندُ قاتٍ في سحبية/خرجية) **ويفتح لكلٍّ منها الشاشةَ المناسبةَ بحالةٍ مهيَّأة.** ★ **ولا شيء فيه يوقف حفظاً ولا توزيعاً ولا تصديراً.** وهو مصدرُ الصفّ الأول في «لوحة اليوم».

## العناصر

| # | الـ Widget class الفعلي | الحجم / اللون / الخط / المسافات | الظهور والتفاعل |
|:-:|---|---|---|
| 1 | `Scaffold` + `QtmsTopBar` | `screenTitle: 'الإدخالات المعلّقة'` · ⛔ بلا زرٍّ عائم | |
| 2 | `_PendingFilterBar` > `QtmsFilterBar` | حشو أفقي 16 ورأسي 8 · `Wrap` بفاصل 8 أفقياً ورأسياً · شرائح بارتفاع 36 مرفوعاً إلى 48 · `StadiumBorder` · **النشطة بتعبئة `primary50` وعلامة صحّ `primary700`** | ⭐ **مجموعتان مرئيتان دائماً:** **① المصدر** (شريحةٌ لكل مصدرٍ من `pendingSourceOptionsProvider` — ⚠️ **بلا خيار «كل المصادر»** فمصدرٌ واحدٌ دائماً) · **② نوعُ المستند** («الكل» + كلُّ قيم `PendingDocumentKind`). |
| 3 | `QtmsFilterBar.notice` | نصٌّ `bodyMd`/`textSecondary` | **بديلُ الشريط كلِّه** إن خلا النطاق: «لا يوجد مصدر ضمن نطاقك. راجع المدير.» |
| 4 | `_RemindsNotEnforcesNotice` > `QtmsInlineBanner` | `triad: SemanticTriads.info` (تعبئة `#EAEEF2` · حدّ `#CBD6DE` · حبر `#3A4E5B`) · حشو 12 · `Radii.card = 20` · حشو أفقي 16 | ⭐★ **لافتةٌ ثابتةٌ تنزع الالتباسَ من أول سطر:** **«هذه الشاشة تذكّر ولا تمنع — لا شيء هنا يوقف حفظاً ولا توزيعاً ولا تصديراً.»** ⟵ **فالمستخدم لا يظنُّ أن عليه تصفيرَها قبل العمل.** |
| 5 | `AsyncStateView<PendingEntryCard>` | حشو أفقي 16 | موزّعُ الحالات. |
| 6 | `ListView.separated` | **`padding: EdgeInsets.only(bottom: Spacing.fabSafeBottom)` = 96** ⚠️ **مع أن الشاشة بلا زرٍّ عائم** · فاصل `Spacing.cardGap` = 12 | القائمة. |
| 7 | `_PendingTile` > `EntityTile` | سطح `surface` · حدّ `border` 1px · `Radii.card = 20` · حشو 16 · `minHeight: 56` · **`actionsPlacement` افتراضي = `stacked`** ⟵ صفٌّ سفليٌّ بارتفاع 48 يسبقه `Divider` | بطاقةُ بندٍ معلَّق. |
| 8 | `IconBadgeBox` (في `leading`) | **48×48** · `Icons.hourglass_bottom_outlined` بحجم `Sizes.iconLg = 24` · تعبئة `SemanticTriads.warning.soft` = `#FBF0D6` · حبر `#946010` · `Radii.field = 14` | رمزُ الانتظار — بثلاثية `warning` مثلَ صفِّ «لوحة اليوم». |
| 9 | `Text` — العنوان | `TypeScale.titleSm` (15 · w600) | `entry.readableTitle` — عنوانٌ مقروءٌ من طبقة النطاق. |
| 10 | `Text` — الثانوي | `TypeScale.bodyMd` · `textSecondary` | ⭐ **يُبنى بثلاث صيغ:** «{رقمُ المستند} · تاريخ المخزون {التاريخ}» · أو «تاريخ المخزون {التاريخ}» بلا رقم · أو **«بلا تاريخ»** إن لم يُعرَف التاريخ ⟵ **فالغيابُ مكتوبٌ لا فراغٌ.** |
| 11 | `StatusPill` — الحقلُ الناقص | `triad: SemanticTriads.warning` · `icon: Icons.hourglass_empty` بحجم `Sizes.iconSm = 16` · `Radii.pill` · `TypeScale.label` | ⭐★ **الشارةُ تقول أيُّ حقلٍ ناقصٌ بالاسم** (`entry.missingField`) ⛔ **لا «غير مكتمل» عامّة** ⟵ **فالمستخدم يعرف ما يُدخِله قبل أن يفتح الشاشة.** |
| 12 | `TextButton` «إدخال» | نصٌّ صِرْف بلون `primary700` · هدف لمس 48×48 من الثيم | **شرطي على `entry.hasDestination`.** ⛔ **بلا `PermissionGate`** — الشاشةُ الهدفُ هي التي تحرس. |
| 13 | `Text` — بديلُ الزرّ | `TypeScale.caption` · `textTertiary` | ⭐★ **بديلٌ حين لا وجهةَ معروفة:** **«حدِّث التطبيق لفتح هذا البند»** ⟵ **فبندٌ من إصدارٍ أحدثَ من التطبيق يُعرَض بسببٍ مفهوم** ⛔ **لا زرٌّ ميّتٌ ولا انهيار.** |
| 14 | `semanticLabel` | «{العنوان} — {الحقلُ الناقص}» | قارئُ الشاشة يسمع البندَ وناقصَه معاً. |
| 15 | ✅ `onRetry` | — | مُمرَّرٌ فعلاً (`ref.invalidate(pendingEntriesProvider)`) ⟵ فيظهر زرُّ «إعادة المحاولة» في حالة الخطأ. |

## آليةُ الفتح — تهيئةُ الشاشة الهدف
★★ **أدقُّ آليةِ تسليمٍ في التطبيق:** `_open` **لا تُبحِر فقط** — بل تُهيّئ حالةَ الهدف أولاً، ثم تُبحِر بمسارٍ (وربما بـ`extra`):

| نوعُ البند | التهيئةُ قبل الإبحار | الوجهة | `extra` |
|---|---|---|---|
| **`dailyPrice`** | يختار المصدر · **ويضبط مرشِّحَ التسعير على `PricingStatusFilter.unpriced`** ⟵ **فتُفتَح الشاشةُ على غير المسعَّر وحده** | `/home/pricing` | — |
| **`distribution`** | يختار المصدر · **ويكتب `PendingFocus` (النوع · المصدر · معرّفُ المستند · الحقل) في `pendingFocusProvider`** ⟵ **فشاشةُ التوزيع تُرشِّح المصدرَ وتكتب اسمَ المقوت في حقل البحث** | `/home/distribution` | — |
| **`sack`** | يختار المصدر وحده | `/home/supply` | ⭐ **`supplyIntakeSackTab`** ⟵ **فتُفتَح على تبويب «الوارد جواني» مباشرةً** لا على تبويب المعدود |
| **`outflow`** | يختار المصدر وحده | `/home/outflows` | — |

⚠️ **ولاحظ التفاوت:** بندُ التوزيع يُرشِّح ويبحث **ولا يفتح ورقةَ النموذج** (بخلاف مسار «متبقي الأيام السابقة» الذي يفتحها) · وبندُ الجونية والسحبية **يكتفيان باختيار المصدر** فيُترَك للمستخدم إيجادُ المستند بنفسه.

## شجرة الـ Widget tree
```
Scaffold (بلا FAB)
├── appBar: QtmsTopBar («الإدخالات المعلّقة»)
└── Column
    ├── _PendingFilterBar
    │   ├── [لا مصادر] QtmsFilterBar.notice («لا يوجد مصدر ضمن نطاقك…»)
    │   └── QtmsFilterBar (مجموعتان)
    │       ├── مجموعة المصدر (ChoiceChip × N — ⛔ بلا «كل المصادر»)
    │       └── مجموعة نوع المستند («الكل» + كل PendingDocumentKind)
    ├── _RemindsNotEnforcesNotice → QtmsInlineBanner (info — «تذكّر ولا تمنع…»)
    ├── SizedBox (8)
    └── Expanded → Padding(أفقي 16) → AsyncStateView<PendingEntryCard>
        ├── hasError → QtmsErrorState («تحقق من صلاحيتك ونطاق مصادرك…» + ⭐ زرّ «إعادة المحاولة»)
        ├── data []  → QtmsEmptyState («لا قيمة معلّقة في هذا المصدر» · ثلاثية success)
        ├── loading  → SkeletonList
        └── data → ListView.separated (حشو سفلي 96 · فاصل 12)
            └── _PendingTile × N → EntityTile (stacked)
                ├── leading: IconBadgeBox (hourglass_bottom_outlined · warning · 48)
                ├── title:   Text (readableTitle — titleSm)
                ├── subtitle:Text («{رقم المستند} · تاريخ المخزون {التاريخ}» | «بلا تاريخ»)
                ├── badges:  StatusPill (اسمُ الحقل الناقص · warning · hourglass_empty)
                └── actions:
                    ├── [بوجهة] TextButton «إدخال» → تهيئةُ الهدف ثم context.go
                    └── [بلا وجهة] Text «حدِّث التطبيق لفتح هذا البند» (caption/textTertiary)
```

## الحالات المُعالجة
| الحالة | الوضع |
|---|---|
| Loading | ✅ `SkeletonList` (أربعُ بطاقاتٍ هيكليةٍ بوميض 1200ms يتوقّف كلياً مع «تقليل الحركة»). **وشريطُ المرشِّحات واللافتةُ يبقيان ظاهرَين** فوقه. |
| Error | ✅★ **كاملة:** `QtmsErrorState` بالرسالة الإرشادية الموحّدة **مع `detail` تقنيٍّ قابلٍ للطيّ** **و⭐ زرِّ «إعادة المحاولة» الفعّال.** |
| Empty | ✅★ **حالةُ فراغٍ إيجابيةٌ بثلاثية `success`:** `Icons.task_alt_outlined` · «لا قيمة معلّقة في هذا المصدر» + **«كل ما حُفظ هنا مكتملُ القيم. وأي قيمة تُترك لاحقاً ستظهر في هذه الشاشة فوراً.»** ⟵ **فالفراغُ خبرٌ سارٌّ يشرح متى يعود الملء** — وهي إحدى حالتَي الفراغ الخضراوَين في التطبيق (مع «متبقي الأيام السابقة»). |
| بندٌ بلا وجهة | ✅ ★ **مُعالَجٌ صراحةً:** نصُّ «حدِّث التطبيق لفتح هذا البند» بدل زرٍّ ⟵ **فتوافقُ الإصدارات محسوبٌ في الواجهة.** |
| تاريخٌ غيرُ معروف | ✅ «بلا تاريخ» نصّاً في النصّ الثانوي. |

## آلية التنقل
- **الدخول إليها:** **من «لوحة اليوم»** — الصفُّ الأول `_PendingEntriesRow` (⛔ **بلا مفتاح صلاحيةٍ على المدخل**).
- **الخروج منها:** ⟶ **أربعُ وجهاتٍ بحالةٍ مهيَّأة:** `/home/pricing` (بمرشِّح «لم يتم») · `/home/distribution` (بترشيحٍ وبحثٍ بالاسم) · `/home/supply` (**على تبويب الجواني**) · `/home/outflows`. الرجوع بزرّ النظام.

# كشف حساب المقوت

| البند | القيمة |
|---|---|
| **اسم الكلاس** | `DealerStatementScreen` (`ConsumerWidget`) — والجسم `_StatementBody` |
| **مسار الملف** | `lib/capabilities/sales_receivables/presentation/dealer_statement_screen.dart` |
| **المسار الملاحي** | `/home/dealer-statement` — `dealerStatementRoute` |
| **اسم الشاشة في الشريط** | `dealerStatementScreenTitle` = «كشف حساب المقوت» |
| **أسماء اللقطات المتوقّعة** | `dealer_statement_lots_tab.png` · `dealer_statement_entries_tab.png` |

## الغرض
كشفُ حسابٍ **مبنيٌّ من دفتر الحركات** لا مقروءٌ من ملخّصٍ مخزَّن، بعرضَين متبادلَين: **«بالضمارات»** (تجميعاً بأعمار الذمّة) و**«بالحركات»** (سطراً سطراً). ويُصدَّر PDF ويُشارَك.

## العناصر — الترويسة

| # | الـ Widget class الفعلي | الحجم / اللون / الخط / المسافات | الظهور والتفاعل |
|:-:|---|---|---|
| 1 | `DefaultTabController(length: 2)` > `Scaffold` + `QtmsTopBar` | `screenTitle: 'كشف حساب المقوت'` · ⛔ بلا زرٍّ عائم | ⚠️ **`DefaultTabController` من الإطار** لا `TabController` يدويّ — بخلاف «التوريد مخزني». |
| 2 | `_StatementHeader` > `Column` | حشو أفقي 16 ورأسي 8 | ثلاثةُ عناصرَ رأسية. |
| 3 | `DropdownButtonFormField<String>` «المقوت» | ارتفاع 52 · تعبئة `surfaceSunken` · `Radii.field = 14` · حدّ `primary400` عرض 2 عند التركيز | يقرأ `dealersProvider` كاملاً (**فالمعطَّل يظهر** — وهو مقصودٌ لمتابعة ذمّته). |
| 4 | `DropdownButtonFormField<String?>` «المصدر» | يسبقه `SizedBox(8)` | ⭐★ **بندُ «كل المصادر» شرطيٌّ بصلاحية** — يظهر فقط إن كان `canViewAllSourcesStatementProvider` صحيحاً ⟵ **فمن لا يملك نطاقاً شاملاً لا يرى الخيار أصلاً** ⛔ لا يراه معطَّلاً. |
| 5 | `_PeriodRow` > `Wrap` | فاصل 8 أفقياً ورأسياً · `crossAxisAlignment: WrapCrossAlignment.center` | ⭐ **مدى الفترة قابلٌ للتحديد بطرفَيه.** يسبقه `SizedBox(8)`. |
| 6 | `Text` — الفترة | `TypeScale.bodyMd` | «تاريخ الإدخال: {نصُّ الفترة}» ⟵ ★ **«تاريخ الإدخال» صراحةً** لا «تاريخ المخزون» — والخلطُ بينهما ممنوع. |
| 7 | `TextButton` «تغيير البداية» + `TextButton` «تغيير النهاية» | لون `primary700` · هدف لمس 48×48 من الثيم | زرّان مستقلّان لطرفَي الفترة. |
| 8 | `showDatePicker` | **حوارُ تاريخٍ من الإطار.** ⭐★ **نطاقُه أوسعُ من كل شاشةٍ أخرى:** `firstDate` = **بداية العام قبل خمس سنوات** (`today.year - 5`) · و`lastDate` = اليوم ⟵ **فالكشفُ يُقرأ سنواتٍ إلى الوراء**، بينما الجردُ والمقبوضاتُ والخصمُ تقف عند سنةٍ واحدة. |
| 9 | `_StatementTabBar` > `TabBar` | مؤشّرٌ **خطٌّ سفليٌّ** بلون `primary500` بعرض التبويب · النشطة `titleSm`/`textPrimary` والخامدة `bodyMd`/`textSecondary` · فاصلٌ سفلي `divider` — **كلُّه من الثيم** | تبويبان: **«بالضمارات»** · **«بالحركات»**. ⚠️★ **بلا `TabBarView` إطلاقاً** — الاختيارُ يكتب في `statementViewProvider` **والجسمُ الواحدُ يُعاد بناؤه بتخطيطٍ مختلف** ⟵ فلا تمريرَ أفقيٌّ بين التبويبين. |

## العناصر — الجسم

| # | الـ Widget class الفعلي | الحجم / اللون / الخط / المسافات | الظهور والتفاعل |
|:-:|---|---|---|
| 10 | `ListView` | حشو أفقي 16 · علوي 8 · **سفلي `Spacing.sectionGap` = 24** | جذر الجسم. |
| 11 | `QtmsKeyValueRow` × ترويسةُ الجدول | التسمية `bodyMd`/`textSecondary` (يتمدّد) + القيمة `bodyMd` بوزن w600 مُحاذيةً للنهاية · حشو رأسي 4 | صفوفُ ترويسةٍ مُولَّدةٌ من `table.header` (اسمُ المقوت · الفترة · المصدر …). |
| 12 | `_ActionsRow` > `Wrap` | فاصل 8 أفقياً ورأسياً · `crossAxisAlignment: center` | صفُّ إجراءَين. |
| 13 | `FilledButton.icon` «تصدير ومشاركة» | `Icons.picture_as_pdf_outlined` بحجم `Sizes.iconMd = 20` · ارتفاع 52 · سطح `surfaceInverse` داكن · حبر `textOnInverse` | **شرطي على `documentExport`** ⟵ فمن لا يملكه لا يرى الزرّ. **معطَّلٌ أثناء العمل.** يُنتِج **PDF** ويفتح **ورقةَ مشاركة النظام**، ويُسجَّل التصديرُ في سجلٍّ. |
| 14 | `TextButton.icon` — تبديلُ الملغى | ⭐ **الأيقونةُ والنصُّ يتبادلان:** `Icons.visibility_off_outlined` + **«إخفاء الملغى»** إذا كان الملغى معروضاً · و`Icons.visibility_outlined` + **«عرض الملغى»** إذا كان مخفياً · بحجم 20 · لون `primary700` | ⛔ **بلا مفتاح صلاحية.** يبدّل `statementShowCancelledProvider`. |
| 15 | `QtmsEmptyState` — بلا حركة | `Icons.receipt_long_outlined` في `IconBadgeBox` 64 بثلاثية `neutral` · «لا حركة في هذه الفترة» + «لا يوجد في دفتر هذا المقوت ما يُعرَض بهذه الفترة وهذا المصدر. **وسّع الفترة أو بدّل المصدر.**» | ⭐ **تقترح إصلاحَين محدَّدَين** ⛔ لا «لا توجد بيانات» مجرَّدة. |
| 16 | `QtmsDataTable` | ★ **جدولٌ متجاوبٌ بنيوياً:** فوق عرض 360 ⟵ **جدولٌ حقيقيٌّ يتمرّر أفقياً** بترويسةٍ غائرة (`surfaceSunken`) بارتفاع 48 وصفوفٍ بارتفاع 48 مفصولةٍ بـ`divider`، وعرضُ العمود 120. **ودون 360 يتحوّل كلُّ صفٍّ إلى بطاقةٍ مستقلّة** (تسمية/قيمة بحدٍّ و`Radii.card`) ⛔ بلا تمريرٍ أفقي. | أعمدتُه وصفوفُه **مُولَّدةٌ من `buildDealerStatementTable`** بحسب التبويب النشط. **والأعمدةُ الرقمية** تُرسَم بـ`TypeScale.numericSm` (أرقامٌ جدولية). |
| 17 | `isStruck` على الصفّ | `TextDecoration.lineThrough` + لون `textTertiary` | ★ **الحركةُ الملغاة تُشطَب فعلياً** ⟵ **فتبقى ظاهرةً ويُقرأ استثناؤها** ⛔ ولا تُحجَب (عند تشغيل «عرض الملغى»). |
| 18 | `_StatementFooter` > `Container` | تعبئة `surfaceSunken` · حدّ `border` 1px · `Radii.card = 20` · حشو `Spacing.cardPadding` = 16 · يسبقه `SizedBox(16)` | بطاقةُ الإجماليات. |
| 19 | `QtmsKeyValueRow` × الإجماليات | القيمةُ الرقمية بـ`numericSm` داخل `Directionality(ltr)` صريحاً | ⭐★ **منطقُ `numeric` دقيقٌ ومقصود:** كلُّ صفٍّ رقميٌّ **إلّا** «الرصيد كتابةً» **وإلّا** ما يبدأ بـ`⚠️` ⟵ **فالرصيدُ المكتوبُ حروفاً لا يُرسَم بأرقامٍ جدوليةٍ ولا يُقلَب اتجاهُه.** |
| 20 | `QtmsInlineBanner` — ضمارات بلا تاريخ | `triad: SemanticTriads.warning` (تعبئة `#FBF0D6` · حدّ `#F0DCA6` · حبر `#946010`) · حشو 12 · `Radii.card` | ⭐★ **شرطي — ونزاهةٌ محاسبيةٌ صريحة:** «{N} ضمار بلا تاريخ مقروء — **مبالغه داخل الرصيد وخارج جدول الأعمار**.» ⟵ **فالتفاوتُ بين الرصيد والجدول مُعلَنٌ بسببه** ⛔ **ولا يُترَك ليُكتشَف حساباً.** |
| 21 | `QtmsInlineBanner` — حالةُ التصدير | **ثلاثيتُه تتبدّل:** `success` عند النجاح · `danger` عند الفشل · حشو 12 · `Radii.card` | **شرطي:** نتيجةُ التصدير بنصٍّ من `DocumentExportResult`. |

## شجرة الـ Widget tree
```
DefaultTabController(length: 2)
└── Scaffold (بلا FAB)
    ├── appBar: QtmsTopBar («كشف حساب المقوت»)
    └── Column
        ├── _StatementHeader
        │   ├── DropdownButtonFormField «المقوت»
        │   ├── DropdownButtonFormField «المصدر» (+ [شرطي بصلاحية] «كل المصادر»)
        │   └── _PeriodRow → Wrap
        │       ├── Text «تاريخ الإدخال: {الفترة}»
        │       ├── TextButton «تغيير البداية» → showDatePicker (5 سنوات → اليوم)
        │       └── TextButton «تغيير النهاية»  → showDatePicker
        ├── _StatementTabBar → TabBar («بالضمارات» | «بالحركات») ⛔ بلا TabBarView
        └── Expanded → switch (dealerStatementProvider)
            ├── isLoading → SkeletonList
            ├── error     → QtmsErrorState (+ زرّ «إعادة المحاولة» ← invalidate)
            ├── value null→ QtmsEmptyState («اختر المقوت»)
            └── data → _StatementBody → ListView
                ├── QtmsKeyValueRow × table.header
                ├── _ActionsRow → Wrap
                │   ├── [شرطي documentExport] FilledButton.icon «تصدير ومشاركة» → PDF + مشاركة النظام
                │   └── TextButton.icon («عرض الملغى» | «إخفاء الملغى»)
                ├── [صفوفٌ فارغة] QtmsEmptyState («لا حركة في هذه الفترة»)
                │   [وإلا] QtmsDataTable (أعمدةٌ مُولَّدة · الملغى مشطوب · متجاوبٌ دون 360)
                ├── _StatementFooter → Container → QtmsKeyValueRow × table.totals
                ├── [شرطي] QtmsInlineBanner (warning — «N ضمار بلا تاريخ مقروء…»)
                └── [شرطي] QtmsInlineBanner (success | danger — نتيجةُ التصدير)
```

## الحالات المُعالجة
| الحالة | الوضع |
|---|---|
| Loading | ✅ `SkeletonList` لبناء الكشف. **والترويسةُ والتبويباتُ تبقى ظاهرتَين** فوقه ⟵ **فيبقى تغييرُ المقوت والفترة ممكناً أثناء التحميل.** وأثناء التصدير يُعطَّل الزرّ (`busy`) ⛔ بلا مؤشّر. |
| Error | ✅★ **الأكملُ في التطبيق:** `QtmsErrorState` بنصّ `operationFailed` **مع `detail` تقنيٍّ قابلٍ للطيّ** **و⭐ زرُّ «إعادة المحاولة» فعّالٌ** (`onRetry: () => ref.invalidate(...)`) ⟵ **وهو من الشاشات القليلة التي تمرّر `onRetry`.** ✅ ونتيجةُ التصدير بلافتةٍ ملوّنةٍ (`success`/`danger`) لا نصّاً عارياً. |
| Empty | ✅ **حالتان متمايزتان:** «اختر المقوت» (حالةٌ ابتدائية) · **و«لا حركة في هذه الفترة»** التي **تقترح إصلاحَين محدَّدَين** (وسّع الفترة · بدّل المصدر) ⟵ **فالفراغُ قابلٌ للتصرّف.** |
| نزاهةُ البيانات | ✅ ★ **لافتةُ «ضمارات بلا تاريخ مقروء»** تُعلِن الفارقَ بين الرصيد وجدول الأعمار بعدده — ⟵ **فلا يبدو الجدولُ ناقصاً بلا تفسير.** |

## آلية التنقل
- **الدخول إليها:** «لوحة اليوم» ⟶ «العمليات اليومية» ⟶ «كشف حساب المقوت» (بمفتاح `dealerStatementView`).
- **الخروج منها:** ⛔ **لا مسارَ داخليٍّ خارجاً ولا ورقةَ سفلية** — و`showDatePicker` هو الحوارُ الوحيد. **لكنّ التصدير يفتح ورقةَ مشاركة النظام** لتسليم الـPDF. الرجوع بزرّ النظام.

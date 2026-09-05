# مالية الجواني

| البند | القيمة |
|---|---|
| **اسم الكلاس** | `SackFinanceScreen` (`ConsumerWidget`) |
| **مسار الملف** | `lib/capabilities/inventory/presentation/sack_finance_screen.dart` |
| **ملفّ البطاقات** | `lib/capabilities/inventory/presentation/sack_finance_cards.dart` |
| **ملفّا الورقتين** | `sack_breakdown_sheet.dart` · `sack_tax_sheet.dart` |
| **المسار الملاحي** | `/home/sack-finance` — `sackFinanceRoute` |
| **اسم الشاشة في الشريط** | `sackFinanceScreenTitle` = «مالية الجواني» |
| **أسماء اللقطات المتوقّعة** | `sack_finance_screen.png` · `sack_breakdown_sheet.png` · `sack_tax_sheet.png` |

## الغرض
ماليةُ جوانيِّ يومٍ واحدٍ في مصدرٍ واحد: **سعرُ الجونية** (بما تحقّق منها فعلياً) و**ضريبتُها** (على الوزن الكلي) و**صافي الرعوي**. ★ **والجونيةُ تُقيَّم بما خرج منها لا بما فيها** — والكميةُ الباقية في المخزن لا تُحتسب في سعرها.

## العناصر

| # | الـ Widget class الفعلي | الحجم / اللون / الخط / المسافات | الظهور والتفاعل |
|:-:|---|---|---|
| 1 | `Scaffold` + `QtmsTopBar` | `screenTitle: 'مالية الجواني'` · ⛔ بلا زرٍّ عائم | |
| 2 | `QtmsContextHeader` | سطح `surface` بحدٍّ سفلي · حشو أفقي 16 ورأسي 8 | ⛔ **بلا «كل المصادر»**. |
| 3 | `DropdownButtonFormField<String>` «المصدر» | `isDense` · `isExpanded` · `hint: 'اختر المصدر'` | منسدلٌ من مكانه. |
| 4 | `_LockedDay` | `Icons.lock_outline` 20 + التاريخ بأرقامٍ جدولية | تاريخُ اليوم مقفل. |
| 5 | `_FilterToggle` > `IconButton` | `Icons.tune_outlined` / `Icons.expand_less` بحجم 20 · 48×48 · **`Badge.count`** عند اختيار رعويٍّ · `tooltip: 'مرشِّحات (1)'` | **مرشِّحُ الرعية مطويٌّ افتراضياً.** |
| 6 | `_SupplierFilter` > `QtmsFilterBar` > `ChoiceChip` | `padded: false` · `Wrap` بفاصل 8 · ارتفاع 36→48 · `StadiumBorder` · النشطة بتعبئة `primary50` وصحّ `primary700` | «كل الرعية» + شريحةٌ لكل رعويٍّ **نشط**. |
| 7 | `QtmsEmptyState` — بلا مصدر | `IconBadgeBox` 64 + عنوان + رسالة بسقف 320 | `noSourceInScopeEmpty` أو `chooseSourceEmpty()`. |
| 8 | `ListView` | `padding: EdgeInsets.all(16)` | جذر المحتوى. |
| 9 | `SupplierAccountCard` > `SackFinancePanel` > `Container` | تعبئة `surfaceSunken` · حدّ `border` · `Radii.card = 20` · حشو 16 · حشو سفلي 16 · العنوان `titleSm` | ⭐ **شرطي — يظهر فقط عند اختيار رعويٍّ بعينه.** «حساب الرعوي في هذا المصدر»: أربعةُ صفوفٍ (إجمالي سعر الجواني · إجمالي الضريبة · صافي الرعوي · عدد الجواني). **ويغيب كلياً إن لم تُقرأ بطاقةُ الرصيد** (`SizedBox.shrink()`). |
| 10 | `QtmsKeyValueRow` | صفٌّ: التسمية بـ`bodyMd`/`textSecondary` (يتمدّد) + فاصل 12 + القيمة بـ**`TypeScale.numericSm` (أرقامٌ جدولية) داخل `Directionality(ltr)` صريحاً** · حشو رأسي 4 | ⟵ **فالرقمُ لا يُعاد ترتيبُه في سياقٍ عربي، والأعمدةُ لا ترتجّ.** كلُّ مبلغٍ بصيغة «N ريال». |
| 11 | `StatusPill` — «غير نهائي …» | `triad: SemanticTriads.warning` · `icon: Icons.hourglass_bottom_outlined` · حشو علوي 8 | ⭐ **شرطي داخل بطاقة الرعوي — ونصُّه ثلاثيُّ الصيغ:** «غير نهائي — N بضريبةٍ معلّقة وM بسعرٍ غير نهائي» · «… N جونية بضريبةٍ معلّقة» · «… M جونية بسعرٍ غير نهائي». ⟵ **فسببُ عدم النهائية مذكورٌ بعدده** لا وسمٌ غامض. |
| 12 | `SackDayTotals` > `SackFinancePanel` | نفس مواصفات ⑨ | «إجماليات اليوم في هذا المصدر»: عدد الجواني · إجمالي سعر الجواني · إجمالي الضريبة · الصافي لكل الجواني. ⚠️ **يحسبها من الجوانيِّ غير الملغاة فقط**، **ويغيب كلياً إن خلت الصفوف.** |
| 13 | `SackFinanceTile` > `InventoryTile` > `EntityTile` | سطح `surface` · حدّ 1px · `Radii.card = 20` · حشو 16 · **قابلٌ للنقر** · فاصل 8 بين البطاقات | العنوان = `sack.displayName` · `trailing` = **سعرُ الجونية** بأرقامٍ جدولية أو **«—»** إن لم يكن نهائياً. |
| 14 | `Text` — الثانوي | `bodyMd` · `textSecondary` | ★ **يقول حالةَ كلِّ رقمٍ صراحةً:** «الضريبة معلّقة» أو «الضريبة N ريال» · ثم ` · ` · «الصافي غير محتسَب» أو «الصافي N ريال». **وعند تعذُّر قراءة المالية:** «المالية غير متاحة». |
| 15 | `TextButton.icon` — الضريبة | `Icons.receipt_long_outlined` · مُحاذٍ للبداية · لون `primary700` | **مُغلَّفٌ بـ`AnyPermissionGate([sackTaxEnterNow, sackTaxEnterLater])`** **وشرط ألّا تكون الجونيةُ ملغاة**. ★ **نصُّه يتغيّر بالحالة:** «إدخال ضريبة الكيلو» إن لم تُدخَل، و**«تعديل ضريبة الكيلو»** إن أُدخِلت. **Trigger** لورقة الضريبة. |
| 16 | `showSackBreakdown` > `showModalBottomSheet` | `isScrollControlled` · خلفية `surface` · انحناء علوي 28 · مقبض سحب | **Trigger: النقرُ على بطاقة الجونية نفسها** (`onTap`) ⛔ **لا زرٌّ.** |
| 17 | `QtmsInlineBanner` — تذييل | `triad: SemanticTriads.info` (تعبئة `#EAEEF2` · حدّ `#CBD6DE` · حبر `#3A4E5B`) · حشو 12 · `Radii.card` | لافتةٌ ثابتةٌ في نهاية القائمة: **«الصافي يُعرَض ويُقيَّد فقط — ولا توجد عملية تسديد للرعوي في هذا الإصدار.»** ⟵ **فحدُّ النطاق مكتوبٌ في الشاشة** لا مفترَضاً. |

### ورقة تفكيك السعر — `SackBreakdownSheet`
**Trigger:** النقرُ على بطاقة الجونية ⑯.

| # | الـ Widget class | التفاصيل |
|:-:|---|---|
| أ | `SafeArea` > `Padding`(16) > `Column(min)` | جذر الورقة. |
| ب | `Text` «تفكيك سعر: {اسم الجونية}» | `TypeScale.titleMd` (17 · w600). |
| ج | `Flexible` > `ListView(shrinkWrap: true)` | الجسم. |
| د | `QtmsDataTable` | ★ **جدولٌ متجاوبٌ بنيوياً:** فوق عرض 360 ⟵ **جدولٌ حقيقيٌّ يتمرّر أفقياً** بترويسةٍ غائرة (`surfaceSunken`) بارتفاع 48 وصفوفٍ بارتفاع 48 مفصولةٍ بـ`divider`، وعرضُ العمود 120. **ودون 360 يتحوّل كلُّ صفٍّ إلى بطاقةٍ مستقلّة** (تسمية/قيمة) — ⛔ **بلا تمريرٍ أفقي.** |
| هـ | أعمدةُ الجدول الستة | «النوع» · «نوع الحركة» · «الجهة» · **«الكمية»** · **«السعر»** · **«القيمة»** — والثلاثةُ الأخيرة `numeric: true` فتُرسَم بـ`TypeScale.numericSm` (أرقامٌ جدولية). والخليةُ الفارغة تُكتَب «—». |
| و | `isStruck` على الصفّ | ★ **الصفُّ غيرُ المحتسَب يُشطَب فعلياً:** `TextDecoration.lineThrough` مع لون `textTertiary` ⟵ **فيبقى ظاهراً ويُقرأ استثناؤه** ⛔ **ولا يُحجَب.** |
| ز | `QtmsInlineBanner` — المجموع | **ثلاثيتُه تتغيّر بالنهائية:** `success` (أخضر) إن كان نهائياً بنصّ «مجموع الحركات المسعَّرة: N ريال» · و`warning` (ذهبي) إن لا، بنصّ «مجموع المسعَّر: N ريال — وM حركة بلا قيمة ظاهرة، فالسعر غير نهائي.» |
| ح | حالةٌ فارغةٌ خاصّة | `Icons.inbox_outlined` · «لم يخرج من هذه الجونية شيء بعد» + **«الجونية تُقيَّم بما تحقق منها — والكمية الباقية في المخزن لا تُحتسب في سعرها.»** ⟵ **فالقاعدةُ نفسُها مشروحةٌ في حالة الفراغ.** |
| ط | حالتا الخطأ | ⚠️ **خطآن مختلفان يُعرَضان برسالةٍ واحدة:** فشلُ القراءة (`hasError`) **و**`Failure` في النتيجة، كلاهما ⟶ `QtmsErrorState` بنصّ «تحقق من صلاحيتك ونطاق مصادرك، ثم أعد المحاولة.» ⛔ **بلا `detail` تقنيٍّ هنا** وبلا زرّ إعادة محاولة. والتحميل ⟶ `SkeletonList(count: 3)`. |

### ورقة ضريبة الكيلو — `SackTaxSheet`
**Trigger:** زرُّ «إدخال/تعديل ضريبة الكيلو» ⑮. `showModalBottomSheet` بـ`isScrollControlled` · حشو سفلي `viewInsetsOf(context).bottom` · حشو 16.

| # | الـ Widget class | التفاصيل |
|:-:|---|---|
| أ | `Text` «ضريبة الكيلو — {اسم الجونية}» | `TypeScale.titleMd`. |
| ب | `TextField` «قيمة ضريبة الكيلو» | `keyboardType: number` · **`inputFormatters: [FilteringTextInputFormatter.digitsOnly]`** ⟵ **فالكسرُ يستحيل إدخالُه** · **`suffixText: 'ريال'`** · ومُعبَّأٌ مسبقاً بالقيمة الحالية إن وُجدت. |
| ج | `QtmsInlineBanner` (`info`) — **حسابٌ حيّ** | ⭐ **يُحدَّث مع كل ضغطة مفتاح.** قبل الإدخال: «ضريبة الجونية = قيمة ضريبة الكيلو × الوزن الكلي ({X} كجم).» — **يشرح المعادلة**. وبعده: «ضريبة الجونية = {الناتج} ريال — **على الوزن الكلي لا المطالب به**.» ⟵ **فالفرقُ الحاسمُ بين الوزنَين مكتوبٌ في مكان القرار.** |
| د | `TextField` «سبب التعديل (اختياري)» | `blankToNull`. |
| هـ | `QtmsInlineBanner` (`danger`) | **شرطي:** رفضٌ بنصٍّ من الكتالوج. **ويُمحى تلقائياً عند أول تعديلٍ للحقل.** |
| و | `SizedBox(width: double.infinity)` > `FilledButton` | ارتفاع 52 · **معطَّل** ما لم تُدخَل قيمةٌ صالحة أو أثناء الإرسال. **ونصُّه يتغيّر:** «حفظ الضريبة» ⟶ **«جارٍ الحفظ…»**. وعند النجاح تُغلَق الورقة. |

## شجرة الـ Widget tree
```
Scaffold (بلا FAB)
├── appBar: QtmsTopBar («مالية الجواني»)
└── Column
    ├── QtmsContextHeader
    │   ├── DropdownButtonFormField «المصدر»
    │   ├── _LockedDay
    │   ├── _FilterToggle (+ Badge.count)
    │   └── [عند الفتح] _SupplierFilter → ChoiceChip («كل الرعية» + الرعية النشطون)
    └── Expanded
        ├── [بلا مصدر] QtmsEmptyState
        └── _SackFinanceBody → InventoryAsyncView<SackCard>
            ├── hasError → QtmsErrorState
            ├── data []  → QtmsEmptyState («لا جواني في هذا اليوم»)
            ├── loading  → SkeletonList
            └── data → ListView (16)
                ├── [شرطي: رعويٌّ مختار] SupplierAccountCard → SackFinancePanel
                │   ├── QtmsKeyValueRow × 4 (numeric)
                │   └── [شرطي] StatusPill «غير نهائي — …» (warning · hourglass)
                ├── [شرطي: صفوفٌ موجودة] SackDayTotals → SackFinancePanel
                │   └── QtmsKeyValueRow × 4 (numeric)
                ├── لكل جونية: SackFinanceTile → Column
                │   ├── InventoryTile (onTap → ورقة التفكيك)
                │   │   ├── title: displayName
                │   │   ├── subtitle: «الضريبة … · الصافي …»
                │   │   └── trailing: سعر الجونية | «—»
                │   └── [شرطي] AnyPermissionGate → TextButton.icon («إدخال|تعديل ضريبة الكيلو»)
                └── QtmsInlineBanner (info — «الصافي يُعرَض ويُقيَّد فقط…»)
```

## الحالات المُعالجة
| الحالة | الوضع |
|---|---|
| Loading | ✅ `SkeletonList` للقائمة و`SkeletonList(3)` داخل ورقة التفكيك. **ونصُّ زرٍّ متغيّر** («جارٍ الحفظ…») في ورقة الضريبة. ⚠️ **وحالةُ تحميلٍ صامتة:** بطاقةُ حساب الرعوي وإجمالياتُ اليوم **تغيبان بلا أثر** أثناء تحميلهما — ⛔ فلا هيكلَ ولا مؤشّر، بل قفزةٌ في التخطيط عند وصولهما. |
| Error | ✅ `QtmsErrorState` للقائمة (بـ«تفاصيل تقنية») و`QtmsErrorState` بلا تفاصيل في ورقة التفكيك، و`QtmsInlineBanner(danger)` في ورقة الضريبة. ✅ **وحالةٌ لطيفة:** «المالية غير متاحة» نصّاً في البطاقة عند تعذُّر قراءة مالية جونيةٍ بعينها. ⚠️ بلا زرّ إعادة محاولة في أيٍّ منها. |
| Empty | ✅ **حالتان متمايزتان:** «لا جواني في هذا اليوم» («لم يُورَّد لهذا المصدر جونيةٌ اليوم — سجّل جونية من التوريد.») **و**«لم يخرج من هذه الجونية شيء بعد» داخل الورقة — بنصٍّ يشرح قاعدةَ التقييم. |
| «غير نهائي» | ✅ ★ **مُعالَجٌ في أربعة مواضع متّسقة:** «—» مكانَ السعر · «الضريبة معلّقة»/«الصافي غير محتسَب» في النصّ الثانوي · `StatusPill` بعدده في بطاقة الرعوي · ولافتةٌ ذهبيةٌ بعدد الحركات في ورقة التفكيك. |

## آلية التنقل
- **الدخول إليها:** «لوحة اليوم» ⟶ قسم «المالية» ⟶ «مالية الجواني» (بمفتاح `sackView`).
- **الخروج منها:** ⛔ **لا مسارَ خارجاً** — ورقتان سفليتان هما العمق. الرجوع بزرّ النظام.

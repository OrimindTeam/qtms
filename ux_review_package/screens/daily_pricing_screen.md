# التسعير اليومي

| البند | القيمة |
|---|---|
| **اسم الكلاس** | `DailyPricingScreen` (`ConsumerWidget`) — والنموذج `_PricingForm` (`ConsumerStatefulWidget`) |
| **مسار الملف** | `lib/capabilities/inventory/presentation/daily_pricing_screen.dart` |
| **المسار الملاحي** | `/home/pricing` — `dailyPricingRoute` |
| **اسم الشاشة في الشريط** | «التسعير اليومي» |
| **اسم اللقطة المتوقّع** | `daily_pricing_screen.png` |

## الغرض
تسعيرُ كل نوعٍ في المخزون **مرتين لا مرة**: سعرُ التوزيع، والحدُّ الأدنى للبيع النقدي. **وهي نموذجُ حفظٍ جماعيٍّ واحد** ⛔ **لا سطرٌ يُحفَظ وحده** — والشاشةُ نفسُها تعرض القائمة وتحرّرها.

## العناصر

| # | الـ Widget class الفعلي | الحجم / اللون / الخط / المسافات | الظهور والتفاعل |
|:-:|---|---|---|
| 1 | `Scaffold` + `QtmsTopBar` | `screenTitle: 'التسعير اليومي'` · ⛔ بلا زرٍّ عائم | |
| 2 | `QtmsContextHeader` | سطح `surface` بحدٍّ سفلي · حشو أفقي 16 ورأسي 8 | ⛔ **بلا «كل المصادر»** — الأسعارُ خاصّةٌ بمصدر. |
| 3 | `DropdownButtonFormField<String>` «المصدر» | `isDense` · `isExpanded` · `hint: 'اختر المصدر'` | منسدلٌ من مكانه. |
| 4 | `_LockedDay` | `Icons.lock_outline` 20 + التاريخ بأرقامٍ جدولية | تاريخُ اليوم مقفل. |
| 5 | `_FilterToggle` > `IconButton` | `Icons.tune_outlined` (مطويّاً) / `Icons.expand_less` (مفتوحاً) بحجم 20 · هدف لمس 48×48 · **و`Badge.count` فوق الأيقونة عند وجود مرشِّحٍ نشط** · `tooltip: 'مرشِّحات (N)'` | ⭐ **زرُّ فتح/طيّ شريط المرشِّحات — والمرشِّحاتُ مطويّةٌ افتراضياً**، فلا تُزحِم الترويسة. `activeFilterCount` = 1 إلّا إذا كان المرشِّح «الكل». |
| 6 | `_PricingFilterBar` > `QtmsFilterBar` > `ChoiceChip` × 3 | `padded: false` (الترويسة تحشو) · شرائح في `Wrap` بفاصل 8 · ارتفاع 36 مرفوعاً إلى 48 بالحشو · `StadiumBorder` · **النشطة بتعبئة `primary50` وعلامة صحّ `primary700`** | **تظهر أسفل الترويسة عند فتح ⑤ فقط.** الخيارات: «الكل» · «تم التسعير» · «لم يتم». |
| 7 | `QtmsEmptyState` — بلا مصدر | `IconBadgeBox` 64 + عنوان `titleMd` + رسالة `bodyMd` بسقف 320 | حالتان: `noSourceInScopeEmpty` أو `chooseSourceEmpty()`. |
| 8 | `_BulkBar` > `QtmsBulkActionBar` | تعبئة `surfaceSunken` · **حدٌّ سفليٌّ** `border` 1px · حشو أفقي 16 ورأسي 8 | شريطُ تقدُّمٍ نصّي: «سُعِّر N من M» بـ`bodyMd`/`textSecondary`. |
| 9 | `_CopyYesterdayButton` > `OutlinedButton.icon` «نسخ أسعار أمس» | `Icons.content_copy_outlined` · ارتفاع ≥ 48 · سطح `surface` بحدّ | ⭐ **يغيب كلياً إن لم توجد أسعارٌ لليوم السابق** (`cards.isEmpty ⟶ SizedBox.shrink()`) ⟵ **فلا زرٌّ يُضغَط فلا يفعل شيئاً.** يُعبِّئ الحقلَين لكل نوعٍ له سعرُ أمس، ويترك الباقي كما هو. |
| 10 | `ListView.builder` | `padding: EdgeInsetsDirectional.all(16)` · **`itemCount: list.length + 1`** | ⚠️ **آخرُ عنصرٍ في القائمة ليس بطاقةً بل حقلَ سببٍ** — حيلةُ تخطيطٍ تجعل الحقلَ يتمرّر مع القائمة. |
| 11 | `_PricingTile` > `Container` | سطح `surface` · حدّ `border` · `Radii.card = 20` · حشو 16 · حشو سفلي بين البطاقات 8 | بطاقةُ تسعيرِ نوعٍ واحد. |
| 12 | `Text` — اسم النوع + `Text` — الرصيد | `titleSm` (يتمدّد) · `bodyMd` (في النهاية) | صفُّ العنوان. |
| 13 | صفٌّ من `_PriceField` × 2 > `TextField` | كلٌّ في `Expanded` بفاصل 8 · ارتفاع 52 · تعبئة `surfaceSunken` · حدّ `primary400` عرض 2 عند التركيز | التسميتان **تحملان الوحدة**: «سعر التوزيع لكل {حبة\|كيلوجرام}» و«الحد الأدنى لكل {الوحدة}». ★ **`inputFormatters: [FilteringTextInputFormatter.digitsOnly]`** ⟵ **فالكسرُ يستحيل إدخالُه بنيوياً** لا يُرفَض بعد الكتابة (كل مبلغٍ عددٌ صحيحٌ بالريال). |
| 14 | `TextField` «سبب التعديل (اختياري)» | **`maxLines: 2`** — الحقلُ الوحيد بسطرَين في الشاشة | آخرُ عنصرٍ في القائمة · `blankToNull`. |
| 15 | `QtmsStickyActionBar` | سطح `surface` بحدٍّ علويٍّ `border` · `SafeArea(top: false)` · حشو 16 | شريطٌ لاصقٌ أسفل الشاشة. |
| 16 | `FilledButton` «حفظ أسعار اليوم» | ارتفاع 52 · سطح `surfaceInverse` | **مُغلَّفٌ بـ`PermissionGate(dailyPriceWrite)`** ⟵ **فمن لا يملك المفتاح يرى الشاشةَ والحقولَ ولا يرى الزرَّ إطلاقاً.** ⚠️ **ملاحظة UX:** الحقولُ تبقى قابلةً للكتابة لمن لا يملك المفتاح. |
| 17 | `QtmsActionStatus` (في `status`) | **حالتان بثلاثيتَين:** الرفض بـ`danger.soft` وأيقونة `error_outline` 20 · والنجاح بـ`success.soft` وأيقونة `check_circle_outline` ونصّ «حُفظت أسعار اليوم.» · حشو 12 · `Radii.card` | **شرطي داخل الشريط اللاصق** — فالنتيجةُ تظهر بجوار الزرّ لا في `SnackBar` عابر. |

## شجرة الـ Widget tree
```
Scaffold (بلا FAB)
├── appBar: QtmsTopBar («التسعير اليومي»)
└── Column
    ├── QtmsContextHeader
    │   ├── DropdownButtonFormField «المصدر»
    │   ├── _LockedDay
    │   ├── _FilterToggle (IconButton + Badge.count عند وجود مرشِّح)
    │   └── [عند الفتح] _PricingFilterBar → QtmsFilterBar → ChoiceChip × 3
    └── Expanded
        ├── [بلا مصدر] QtmsEmptyState
        └── _PricingForm → InventoryAsyncView<PricingRow>
            ├── hasError → QtmsErrorState
            ├── data []  → QtmsEmptyState («لا شيء يُسعَّر بعد»)
            ├── loading  → SkeletonList
            └── data → Column
                ├── _BulkBar → QtmsBulkActionBar
                │   ├── Text «سُعِّر N من M»
                │   └── [شرطي] OutlinedButton.icon «نسخ أسعار أمس»
                ├── Expanded → ListView.builder (length + 1)
                │   ├── _PricingTile × N (Container)
                │   │   ├── Row: Text (اسم النوع) + Text (الرصيد)
                │   │   └── Row: _PriceField «سعر التوزيع» + _PriceField «الحد الأدنى»
                │   └── [العنصر الأخير] TextField «سبب التعديل» (maxLines: 2)
                └── QtmsStickyActionBar
                    ├── status: [شرطي] QtmsActionStatus (rejection | success)
                    └── primary: PermissionGate(dailyPriceWrite) → FilledButton «حفظ أسعار اليوم»
```

## الحالات المُعالجة
| الحالة | الوضع |
|---|---|
| Loading | ✅ `SkeletonList` للقائمة. وأثناء الحفظ يُعطَّل الزرّ ⛔ **بلا مؤشّر ولا نصٍّ بديل** («جارٍ الحفظ…» موجودٌ في «الإتلاف» و«الجرد» **ومفقودٌ هنا**). |
| Error | ✅ `QtmsErrorState` للقراءة، **و**`QtmsActionStatus.rejection` للكتابة داخل الشريط اللاصق. ★ **ورسالةُ الكسر محدَّدة:** أيُّ حقلٍ لا يُفهَم عدداً صحيحاً ⟶ `CatalogMessage.fractionalMoney` **قبل أي نداء شبكة**، ومثلُها `BR-M9-06` من الخادم. |
| Empty | ✅ «لا شيء يُسعَّر بعد» + «التسعير يتبع المخزون — سجّل وارداً أولاً ثم عُد لتسعيره.» ⚠️ **وحالةٌ غير مغطّاة:** إذا رشَّح المستخدم «لم يتم» وكان الكلُّ مسعَّراً تظهر **نفسُ** الحالة الفارغة برسالتها الأصلية ⛔ **بلا إشارةٍ إلى أن المرشِّح هو السبب.** |
| النجاح | ✅ `QtmsActionStatus.success` بنصٍّ صريح — **والشاشةُ لا تُغلَق** ولا تُفرَّغ الحقول، فتبقى المراجعةُ ممكنة. |

## آلية التنقل
- **الدخول إليها:** «لوحة اليوم» ⟶ «العمليات اليومية» ⟶ «التسعير اليومي» — ⛔ **بلا مفتاح صلاحيةٍ على المدخل** (المفتاحُ على زرِّ الحفظ وحده) · **ومن «الإدخالات المعلّقة»** عبر `pendingScreenRoute(PendingScreen.dailyPricing)`.
- **الخروج منها:** ⛔ **لا مسارَ خارجاً ولا ورقةَ سفلية** — الشاشةُ كلُّها نموذجٌ واحد. الرجوع بزرّ النظام.

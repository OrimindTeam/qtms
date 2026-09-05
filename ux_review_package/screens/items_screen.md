# الأنواع

| البند | القيمة |
|---|---|
| **اسم الكلاس** | `ItemsScreen` (`ConsumerWidget`) |
| **مسار الملف** | `lib/capabilities/master_data/presentation/items_screen.dart` |
| **المسار الملاحي** | `/home/items` — `itemsRoute` |
| **اسم الشاشة في الشريط** | «الأنواع» |
| **اسم اللقطة المتوقّع** | `items_screen.png` · وللورقة: `item_form_sheet.png` |

## الغرض
كتالوجُ الأنواع: يحدّد **الطبيعة** (عددي / وزني) و**الوحدة** (حبة / كيلوجرام) وربطَ النوع بمصادره. ⛔ **ولا حذف** — التعطيل بديلُه. **ونوع «السكرب» افتراضيٌّ نظامي: لا يُعدَّل ولا يُحذف** — فيغيب عنه زرُّ التعديل كلياً.

## العناصر

| # | الـ Widget class الفعلي | الحجم / اللون / الخط / المسافات | الظهور والتفاعل |
|:-:|---|---|---|
| 1 | `Scaffold` + `QtmsTopBar` | `screenTitle: 'الأنواع'` | |
| 2 | `FloatingActionButton.extended` — «نوع جديد» | `Icons.category_outlined` · خلفية `surfaceInverse` · `elevation: 0` | `PermissionGate(itemWrite)`. **Trigger** لورقة النموذج. |
| 3 | `MasterDataAsyncView<ItemCard>` | — | موزّع الحالات. |
| 4 | `EntityList` > `ListView.separated` | حشو أفقي متجاوب · سفلي 96 · فاصل 12 | |
| 5 | `MasterDataTile` > `EntityTile` | سطح `surface` · حدّ 1px · `Radii.card = 20` · حشو 16 | **`actionsPlacement` افتراضي = `stacked`** ⟵ **زرُّ التعديل في صفٍّ سفليٍّ مستقلٍّ يسبقه `Divider`** — ⚠️ **بخلاف الثلاث الأخريات في العائلة** (المصادر · الرعية · المقاوته) التي تستعمل `inline`. |
| 6 | `Text` — العنوان | `TypeScale.titleSm` | `itemCardDisplayName(...)` — **الاسمُ يتغيّر بإعداد الجهاز:** إن فُعِّل «إظهار وزن الحبة» في «الإعدادات» صار «بطّوه وزن (200 جرام)» بدل «بطّوه». |
| 7 | `Text` — الثانوي | `TypeScale.bodyMd` · `textSecondary` | `«الطبيعة · الوحدة»` — مثلاً «وزني · كيلوجرام» أو «عددي · حبة». |
| 8 | `IconButton` (في `leading`) — سجل التدقيق | من `auditTrailLeading(...)` بلا `sourceId` | **شرطي.** |
| 9 | `SystemDefaultBadge` > `StatusPill` | «افتراضي» · `triad: SemanticTriads.warning` · `icon: Icons.lock_outline` 16 | **شرطي:** عندما `item.isSystemDefault` (السكرب). |
| 10 | `DisabledBadge` > `StatusPill` | «معطَّل» · `triad: danger` · `icon: do_not_disturb_on_outlined` | **شرطي:** عندما `!item.isActive`. |
| 11 | `TextButton.icon` — «تعديل» | `Icons.edit_outlined` 20 · **نصٌّ مع الأيقونة** ⚠️ **بخلاف `IconButton` الصامت في شاشات العائلة الثلاث الأخرى** · لون النصّ `primary700` · هدف لمس 48×48 من الثيم | `PermissionGate(itemWrite)` **وشرط `!item.isSystemDefault`** ⟵ **فالسكرب بلا زرّ تعديلٍ أصلاً.** **Trigger** للورقة بوضع التعديل. |

### ورقة نموذج النوع — `ItemFormSheet`
**Trigger:** الزرُّ العائم ② أو زرُّ التعديل ⑪. `showModalBottomSheet` بـ`isScrollControlled: true` · انحناء علوي 28 · مقبض سحب · حشو سفلي `viewInsets.bottom` · `SingleChildScrollView` بحشو 16.

| # | الـ Widget class | التفاصيل |
|:-:|---|---|
| أ | `Text` | «نوع جديد» أو «تعديل نوع» — `TypeScale.titleLg`. |
| ب | `MasterDataField` «اسم النوع» | `autofocus: true`. |
| ج | `SourcesSelector` > `Wrap` > `FilterChip` | عنوانٌ «المصادر» بـ`TypeScale.label`/`textSecondary` ثم شرائح. **الشريحة:** ارتفاع `chipHeight = 36` مرفوعاً إلى 48 بحشو رأسي 8 · `StadiumBorder` · حدّ `border` · **النشطة بتعبئة `primary50` وعلامة صحّ `primary700`**. فاصل 8 أفقياً ورأسياً. ⚠️ **وشرائح «يتيمة»:** أيُّ `sourceId` مؤشَّرٍ لكنّه غير موجود في المصادر النشطة يُعرَض **بمعرّفه الخام** مؤشَّراً — فلا يُفقَد ربطٌ قائم بصمت. |
| د | `Text` «الطبيعة» | `TypeScale.label`/`textSecondary`. |
| هـ | `SegmentedButton<ItemNature>` | شريحتان: «عددي» · «وزني». **اختيارٌ واحد إلزامي** (لا حالة فارغة) — الافتراضي `countBased`. |
| و | `MasterDataField` «وزن الحبة بالجرام (اختياري)» | **شرطي:** يظهر فقط عندما `_nature == weightBased`. `keyboardType: numberWithOptions(decimal: true)` — **الحقل العشري الوحيد في التطبيق** (المبالغ كلُّها أعدادٌ صحيحة). |
| ز | `Text` تفسيري | `bodyMd`/`textSecondary` | **شرطي مع و:** «قيمة افتراضية للعرض — تعديلها لاحقاً لا يؤثر على أي جونية سابقة.» |
| ح | `SwitchListTile` «النوع نشط» | **تعديلاً فقط** · النصّ الثانوي «التعطيل بديل الحذف — ولا حذف للأنواع.» |
| ط | `MasterDataField` «سبب التعطيل» | **شرطيٌّ داخل الشرطي:** عند إطفاء مفتاح ح. |
| ي | `MasterDataField` «سبب التعديل (اختياري)» | **تعديلاً فقط** · `blankToNull`. |
| ك | `RejectionBanner` | **شرطي.** |
| ل | `FilledButton` | «إنشاء» أو «حفظ التعديل». ⛔ **بلا نصٍّ تذييلي.** |

## شجرة الـ Widget tree
```
Scaffold
├── appBar: QtmsTopBar («الأنواع»)
├── floatingActionButton: PermissionGate(itemWrite) → FloatingActionButton.extended
└── body: MasterDataAsyncView<ItemCard> → AsyncStateView
    ├── hasError → QtmsErrorState
    ├── data []  → QtmsEmptyState (category_outlined · ثلاثية masterData)
    ├── loading  → SkeletonList
    └── data     → EntityList → ListView.separated
        └── _ItemTile → MasterDataTile → EntityTile (stacked)
            ├── leading: [شرطي] IconButton (سجل التدقيق)
            ├── title: Text (الاسم — قد يحمل وزن الحبة بحسب إعداد الجهاز)
            ├── subtitle: Text «الطبيعة · الوحدة»
            ├── badges: [شرطي] SystemDefaultBadge · [شرطي] DisabledBadge
            └── actions (stacked · Divider + صف 48):
                └── [شرطي !isSystemDefault] PermissionGate(itemWrite) → TextButton.icon «تعديل»
```

## الحالات المُعالجة
| الحالة | الوضع |
|---|---|
| Loading | ✅ `SkeletonList`. وأثناء الإرسال يُعطَّل الزرّ ⛔ بلا مؤشّر. |
| Error | ✅ `QtmsErrorState` بتمييز `permission-denied` + «تفاصيل تقنية». ⚠️ بلا زرّ إعادة محاولة. |
| Empty | ✅ «لا توجد أنواع بعد» + «النوع يحدّد وحدة القياس وطريقة الوزن — أضف أول نوع قبل تسجيل الوارد.» ⚠️ **وعملياً لا تُرى هذه الحالة أبداً** — «السكرب» يُنشأ مع الإعداد التأسيسي. |

## آلية التنقل
- **الدخول إليها:** «لوحة اليوم» ⟶ «البيانات المرجعية» ⟶ «الأنواع» (بمفتاح `itemWrite`).
- **الخروج منها:** ⛔ **لا مسارَ خارجاً** — الرجوع بزرّ النظام.
- **تأثيرٌ متقاطع:** عرضُ الاسم في هذه الشاشة (وفي كل شاشة) يتحكّم به مفتاحٌ في [`settings_screen.md`](settings_screen.md).

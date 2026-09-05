# مخزون اليوم

| البند | القيمة |
|---|---|
| **اسم الكلاس** | `TodayStockScreen` (`ConsumerWidget`) |
| **مسار الملف** | `lib/capabilities/inventory/presentation/today_stock_screen.dart` |
| **المسار الملاحي** | `/home/stock` — `todayStockRoute` |
| **اسم الشاشة في الشريط** | «مخزون اليوم» |
| **أسماء اللقطات المتوقّعة** | `today_stock_screen.png` · وللورقة: `item_movements_sheet.png` |

## الغرض
رصيدُ كل نوعٍ في مصدرٍ واحدٍ لتاريخ اليوم، **مشتقٌّ من الدفتر** (وارد − صادر) ⛔ **لا مقروءاً من ملخّصٍ مبنيٍّ مسبقاً**. وهي شاشةُ قراءةٍ محضة: ⛔ **بلا زرٍّ عائم وبلا أي مفتاح صلاحيةٍ يحجبها** — ظاهرةٌ لكل من يدخل التطبيق.

## العناصر

| # | الـ Widget class الفعلي | الحجم / اللون / الخط / المسافات | الظهور والتفاعل |
|:-:|---|---|---|
| 1 | `Scaffold` + `QtmsTopBar` | `screenTitle: 'مخزون اليوم'` · ⛔ **بلا `floatingActionButton`** | |
| 2 | `QtmsContextHeader` | سطح `surface` بحدٍّ سفلي · حشو أفقي 16 ورأسي 8 | ⚠★ **`allowAllSources` غائبةٌ هنا (فهي `false`)** ⟵ **فلا بندَ «كل المصادر»**: رصيدُ كل نوعٍ مستقلٌّ في كل مصدر، وجمعُه عبر المصادر بلا معنى. |
| 3 | `DropdownButtonFormField<String>` — «المصدر» | `isDense` · `isExpanded` · `hint: 'اختر المصدر'` | **منسدلٌ من مكانه** أعلى الشاشة. |
| 4 | `_LockedDay` | `Icons.lock_outline` 20 + التاريخ بـ`TypeScale.numeric` (أرقامٌ جدولية) بـ`textSecondary` | تاريخُ اليوم من الخادم، مقفل. |
| 5 | `QtmsEmptyState` — بلا مصدرٍ مختار | `IconBadgeBox` 64 · العنوان `titleMd` · الرسالة `bodyMd` بسقف عرضٍ 320 · حشو 24 | **حالتان متمايزتان:** إن خلا النطاق ⟶ `noSourceInScopeEmpty` («لا يوجد مصدر ضمن نطاقك» بأيقونة `lock_outline`) · وإن وُجدت مصادر ولم يُختَر ⟶ `chooseSourceEmpty()` («اختر مصدراً لعرض بياناته» بأيقونة `warehouse_outlined`، ورسالتُه تشرح **لماذا**: «رصيد كل نوع وحساباته مستقلة في كل مصدر — فاختر المصدر أولاً من أعلى الشاشة.»). |
| 6 | `ListView` | `padding: EdgeInsets.all(16)` | جذر القائمة. |
| 7 | `_Totals` > `Container` | تعبئة `surfaceSunken` · حدّ `border` · `Radii.card = 20` · حشو 16 | **بطاقةُ إجماليَّين لا واحد** — ★ **لأن الحبّات والأوزان لا تُجمَع أبداً:** «إجمالي المعدود: N حبة» (`bodyLg`) ثم `SizedBox(4)` ثم «{scrapTotalLabel}: X كجم» (`bodyLg`). |
| 8 | `InventoryTile` > `EntityTile` لكل نوع | سطح `surface` · حدّ 1px · `Radii.card = 20` · حشو 16 · `minHeight: 56` · **قابلٌ للنقر** (`InkWell` بـ`minHeight: tileMinHeight`) · فاصل `SizedBox(8)` بين البطاقات | العنوان = `ledgerItemDisplayName(...)` — **المفتاح المركّب لا `itemName` المجرَّد** ⟵ فسطرُ الجونية يُقرأ بهويته. |
| 9 | `Text` — الثانوي | `bodyMd` · `textSecondary` | «وارد X · صادر Y» بوحدتَيهما (حبة أو كجم بحسب النوع). |
| 10 | `Text` — `trailing` | `TypeScale.numeric` (15 · w600 · **أرقامٌ جدولية**) | **الرصيد** — في نهاية الصفّ. ⟵ فالعمودُ لا يرتجّ عند التحديث اللحظي. |
| 11 | `showItemMovements` > `showModalBottomSheet` > `ItemMovementsSheet` | `isScrollControlled: true` · خلفية `surface` · انحناء علوي `Radii.sheet = 28` · مقبض سحب `neutral300` | **Trigger:** **النقرُ على بطاقة النوع نفسها** (`onTap`) — ⛔ **لا زرٌّ ولا أيقونةُ سهم**، فالبطاقةُ كلُّها هدفُ اللمس. |

### ورقة حركات النوع — `ItemMovementsSheet`

| # | الـ Widget class | التفاصيل |
|:-:|---|---|
| أ | `SafeArea` > `Padding` (16) > `Column(min)` | جذر الورقة. |
| ب | `Text` | «حركة {اسم النوع} — {تاريخ اليوم}» — `TypeScale.titleLg`. |
| ج | `ConstrainedBox` | **`maxHeight: 360`** — سقفٌ ثابتٌ محفورٌ في الشاشة (لا توكن)، فالورقة لا تطول بلا حدّ. |
| د | `InventoryAsyncView<StockMovementCard>` > `ListView.separated` | `shrinkWrap: true` · فاصل 8. |
| هـ | `_MovementTile` > `InventoryTile` | العنوان = **رقم المستند المصدري**. الثانوي «دخول X» أو «خروج X». `trailing` = **الرصيد بعد الحركة** بأرقامٍ جدولية ⟵ فيُقرأ الدفترُ سطراً سطراً. |
| و | `IconButton` (في `leading`) | سجل التدقيق للمستند — **ونوعُ الكيان يُشتقّ من `SourceDocumentType`** عبر `_entityTypeOf` الذي يغطّي **ثمانية أنواع مستندات** (وارد معدود · جونية · توزيع · بيع نقدي · سحبية · خرجية · إتلاف · جرد). **شرطي.** |
| ز | `CancelledBadge` / `AmendedBadge` | «ملغى» · «مُعدَّل». **شرطيّان** لكل حركة. |
| ح | حالةٌ فارغةٌ خاصّة | «لا حركات اليوم» + «لم تُسجَّل حركةٌ على هذا النوع في تاريخ اليوم.» بأيقونة `receipt_long_outlined`. |

## شجرة الـ Widget tree
```
Scaffold (بلا FAB)
├── appBar: QtmsTopBar («مخزون اليوم»)
└── Column
    ├── QtmsContextHeader (بلا «كل المصادر»)
    │   ├── DropdownButtonFormField «المصدر»
    │   └── _LockedDay (lock_outline + التاريخ)
    └── Expanded
        ├── [بلا مصدر] QtmsEmptyState (noSourceInScopeEmpty | chooseSourceEmpty)
        └── _StockList → InventoryAsyncView<ItemDailyBalanceCard>
            ├── hasError → QtmsErrorState («تحقق من صلاحيتك ونطاق مصادرك…»)
            ├── data []  → QtmsEmptyState («المخزن فارغ اليوم»)
            ├── loading  → SkeletonList
            └── data     → ListView (padding: 16)
                ├── _Totals (Container غائر: إجمالي المعدود + إجمالي السكرب)
                ├── SizedBox (16)
                └── لكل نوع:
                    ├── InventoryTile (onTap → ورقة الحركات)
                    │   ├── title: ledgerItemDisplayName
                    │   ├── subtitle: «وارد … · صادر …»
                    │   └── trailing: الرصيد (numeric جدولي)
                    └── SizedBox (8)

showModalBottomSheet → ItemMovementsSheet
├── Text «حركة {النوع} — {التاريخ}» (titleLg)
└── ConstrainedBox (maxHeight: 360)
    └── InventoryAsyncView<StockMovementCard> → ListView.separated
        └── _MovementTile → InventoryTile
            ├── leading: [شرطي] IconButton (سجل التدقيق · نوعه من SourceDocumentType)
            ├── title: رقم المستند · subtitle: «دخول/خروج …»
            ├── trailing: الرصيد بعد الحركة
            └── badges: [CancelledBadge] [AmendedBadge]
```

## الحالات المُعالجة
| الحالة | الوضع |
|---|---|
| Loading | ✅ `SkeletonList` للقائمة، **ومثلُه داخل ورقة الحركات**. |
| Error | ✅ `QtmsErrorState` برسالةٍ إرشاديةٍ لا تقنية («تحقق من صلاحيتك ونطاق مصادرك، ثم أعد المحاولة.») + «تفاصيل تقنية» قابلة للطيّ. ⚠️ **بلا زرّ إعادة محاولة.** |
| Empty | ✅ **أربع حالاتٍ متمايزة:** لا مصدر في النطاق · مصدرٌ غير مختار · «المخزن فارغ اليوم» («لم يدخل هذا المصدر وارد اليوم — سجّل وارداً أو جونية.») · «لا حركات اليوم» داخل الورقة. ⟵ **فلا حالةَ فراغٍ واحدةٌ عامّة تُغطّي أسباباً مختلفة.** |

## آلية التنقل
- **الدخول إليها:** «لوحة اليوم» ⟶ «العمليات اليومية» ⟶ «مخزون اليوم» — ⛔ **بلا مفتاح صلاحية.**
- **الخروج منها:** ⛔ **لا مسارَ خارجاً** — ورقةُ الحركات هي العمقُ الوحيد. الرجوع بزرّ النظام.

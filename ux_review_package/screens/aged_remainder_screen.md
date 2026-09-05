# متبقي الأيام السابقة

| البند | القيمة |
|---|---|
| **اسم الكلاس** | `AgedRemainderScreen` (`ConsumerStatefulWidget`) |
| **مسار الملف** | `lib/capabilities/inventory/presentation/aged_remainder_screen.dart` |
| **المسار الملاحي** | `/home/aged-remainder` — `agedRemainderRoute` |
| **اسم الشاشة في الشريط** | «متبقي الأيام السابقة» |
| **اسم اللقطة المتوقّع** | `aged_remainder_screen.png` |

## الغرض
كلُّ مخزونٍ من أيامٍ ماضية لم يُصرَّف بعد، **مجموعاً بأيامه ومرتَّباً بشدّة تقادُمه**، ومن كل بطاقةِ نوعٍ **ثلاثةُ مخارجَ للتصريف** تُفتَح على الشاشة المناسبة **بالنوع والتاريخ مثبَّتَين مسبقاً**. وهي مصدرُ الصفّ الثاني في «لوحة اليوم».

## سُلَّم الشدّة (`AgedRemainderSeverity`)
| الشدّة | الثلاثية | الأيقونة |
|---|---|---|
| `recent` | `SemanticTriads.warning` (ذهبي) | `Icons.schedule_outlined` |
| `ageing` | `SemanticTriads.danger` (طيني) | `Icons.warning_amber_outlined` |
| `overdue` | `SemanticTriads.danger` (طيني) | `Icons.error_outline` |
⚠️ **ملاحظة UX:** `ageing` و`overdue` **تتشاركان الثلاثيةَ نفسها** ولا يفرّقهما إلا الأيقونة ونصُّ العمر.

## العناصر

| # | الـ Widget class الفعلي | الحجم / اللون / الخط / المسافات | الظهور والتفاعل |
|:-:|---|---|---|
| 1 | `Scaffold` + `QtmsTopBar` | `screenTitle: 'متبقي الأيام السابقة'` · ⛔ بلا زرٍّ عائم | |
| 2 | `QtmsFilterBar` > `Wrap` > `ChoiceChip` | حشو أفقي 16 ورأسي 8 · فاصل 8 أفقياً ورأسياً · ارتفاع الشريحة 36 مرفوعاً إلى 48 · `StadiumBorder` · **النشطة بتعبئة `primary50` وعلامة صحّ `primary700`** | ⭐ **مرشِّحُ المصدر شرائحُ مرئيةٌ دائماً** ⛔ **لا `QtmsContextHeader` ولا منسدل** — بخلاف كل شاشات المخزون الأخرى. أولُ شريحةٍ **«كل المصادر»** ثم شريحةٌ لكل مصدر. |
| 3 | `QtmsFilterBar.notice` > `Text` | `bodyMd` · `textSecondary` | **بديلُ شريط الشرائح** إن خلا النطاق: «لا يوجد مصدر ضمن نطاقك. راجع المدير.» |
| 4 | `QtmsSearchField` > `TextField` | حشو أفقي 16 · ارتفاع 52 · تعبئة `surfaceSunken` · `prefixIcon: Icons.search` · `suffixIcon: IconButton(Icons.close)` بـ`tooltip: 'مسح البحث'` **يظهر عند وجود نصٍّ فقط** | «بحث في الأنواع» — **يُرشِّح داخل الأيام** ويحتفظ باليوم فقط إن طابق أحدُ أنواعه. ⚠️ **مطابقةٌ حرفيةٌ بـ`contains`** ⛔ **بلا `normalizeName`** — بخلاف شجرة الصلاحيات. |
| 5 | `ListView` | حشو أفقي 16 · **حشو سفلي `Spacing.fabSafeBottom` = 96** ⚠️ **مع أن الشاشة بلا زرٍّ عائم** | جذر القائمة. |
| 6 | `_DaySection` — ترويسةُ اليوم | صفٌّ من: `IconBadgeBox` 48×48 (أيقونةُ الشدّة بثلاثيتها · تعبئة `soft` و`Radii.field = 14`) + فاصل 12 + `Text` «مخزون يوم {التاريخ}» بـ`titleSm` (يتمدّد) + `StatusPill` بعمر اليوم | **مجموعةٌ لكل يوم**، بفاصل `SizedBox(16)` بين المجموعات و`SizedBox(8)` بعد الترويسة. |
| 7 | `StatusPill` — العمر | `Radii.pill` · `TypeScale.label` · بثلاثية الشدّة · ⛔ **بلا أيقونة** هنا | نصُّه من `agedAgeLabel`: **«منذ يوم» · «منذ يومين» · «منذ N أيام»** — ⟵ **صيغةُ المثنّى العربيةُ مُراعاةٌ صراحةً** لا «منذ 2 أيام». |
| 8 | `_RemainderTile` > `InventoryTile` > `EntityTile` | سطح `surface` · حدّ 1px · `Radii.card = 20` · حشو 16 · **`actionsPlacement` افتراضي = `stacked`** ⟵ الأزرار في صفٍّ سفليٍّ بارتفاع 48 يسبقه `Divider` · فاصل 8 بين البطاقات | بطاقةُ نوعٍ متبقٍّ. |
| 9 | `Text` — العنوان والثانوي و`trailing` | `titleSm` · `bodyMd`/`textSecondary` · `TypeScale.numeric` (أرقامٌ جدولية) | العنوان = اسمُ النوع المعروض · الثانوي = «المصدر: {اسم المصدر}» (**بالاسم لا بالمعرّف**، وإن لم يُوجَد فبالمعرّف) · النهاية = **الكمية المتبقّية**. |
| 10 | `TextButton` «توزيع» | نصٌّ صِرْف بلون `primary700` · هدف لمس 48×48 من الثيم | **شرطيٌّ مزدوج:** يحتاج `agedRemainderClear` **و**`distributionCreate`. ⟶ `/home/distribution`. |
| 11 | `TextButton` «بيع نقدي» | نفسها | يحتاج `agedRemainderClear` **و**`cashSaleCreate`. ⟶ `/home/cash-sales`. |
| 12 | `TextButton` «إتلاف» | نفسها | يحتاج `agedRemainderClear` **و**`disposalCreate`. ⟶ `/home/disposal`. |
| 13 | آليةُ التسليم | — | ★ **كلُّ زرٍّ يكتب `AgedClearanceFocus(sourceId, itemKey, stockDate)` في `agedClearanceFocusProvider` ثم يُبحِر.** والشاشةُ الهدفُ تستهلكه مرةً واحدة (`take()`) فتُثبِّت المصدرَ وتقفله، وتُثبِّت تاريخَ المخزون، **وتزرع سطراً أوّلَ بالنوع المقصود** — وتعرض `AgedClearanceBanner` تحذيراً بأن الحركةَ تُحتسَب في ضمار ذلك اليوم. |

## شجرة الـ Widget tree
```
Scaffold (بلا FAB)
├── appBar: QtmsTopBar («متبقي الأيام السابقة»)
└── Column
    ├── [لا مصادر] QtmsFilterBar.notice («لا يوجد مصدر ضمن نطاقك…»)
    │   [وإلا]     QtmsFilterBar → Wrap → ChoiceChip («كل المصادر» + شريحة لكل مصدر)
    ├── Padding(16) → QtmsSearchField («بحث في الأنواع»)
    ├── SizedBox (12)
    └── Expanded → AsyncStateView<AgedRemainderDay>
        ├── hasError → QtmsErrorState («تحقق من صلاحيتك ونطاق مصادرك…»)
        ├── data []  → QtmsEmptyState («لا متبقي من أيام سابقة» · ثلاثية success)
        ├── loading  → SkeletonList
        └── data → [بحثٌ بلا نتيجة] QtmsNoMatch («لا نوع يطابق البحث في المتبقي المتأخر.»)
                   [وإلا] ListView (حشو سفلي 96)
                   └── لكل يوم: _DaySection
                       ├── Row: IconBadgeBox(الشدّة) + Text «مخزون يوم …» + StatusPill(العمر)
                       └── لكل نوع: _RemainderTile → InventoryTile
                           ├── title/subtitle/trailing: النوع · «المصدر: …» · المتبقّي
                           └── actions (stacked): TextButton «توزيع» · «بيع نقدي» · «إتلاف»
```

## الحالات المُعالجة
| الحالة | الوضع |
|---|---|
| Loading | ✅ `SkeletonList`. |
| Error | ✅ `QtmsErrorState` بالرسالة الإرشادية الموحّدة + «تفاصيل تقنية». ⚠️ بلا زرّ إعادة محاولة. |
| Empty | ✅ **حالتان متمايزتان تماماً:** ⭐ **«لا متبقي من أيام سابقة» بثلاثية `success` (خضراء)** — ⟵ **فالفراغُ هنا خبرٌ سارٌّ لا نقصُ بيانات**، وهو الاستعمالُ الوحيد لثلاثية النجاح في حالةٍ فارغة في التطبيق. **و**`QtmsNoMatch` نصّاً بسيطاً عندما يُخفي البحثُ كلَّ النتائج ⟵ **فيُفرَّق بين «لا يوجد» و«بحثُك لم يطابق».** |

## آلية التنقل
- **الدخول إليها:** **من «لوحة اليوم»** — الصفُّ الثاني `_AgedRemainderRow` (⛔ **بلا مفتاح صلاحيةٍ على المدخل**).
- **الخروج منها:** ⟶ `/home/distribution` · `/home/cash-sales` · `/home/disposal` — **وكلُّها بحالةِ تركيزٍ مثبَّتة**، لا ملاحةً مجرَّدة. الرجوع بزرّ النظام.

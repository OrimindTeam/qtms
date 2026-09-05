# المصادر

| البند | القيمة |
|---|---|
| **اسم الكلاس** | `SourcesScreen` (`ConsumerWidget`) |
| **مسار الملف** | `lib/capabilities/master_data/presentation/sources_screen.dart` |
| **المسار الملاحي** | `/home/sources` — `sourcesRoute` |
| **اسم الشاشة في الشريط** | «المصادر» |
| **اسم اللقطة المتوقّع** | `sources_screen.png` · وللورقة: `source_form_sheet.png` |

## الغرض
إدارة **وحدة الفصل العليا في النظام**: كل رصيد وكل حساب مستقلٌّ في كل مصدر. ⛔ **ولا حذف للمصادر إطلاقاً** — التعطيل بديلُه. وهي إحدى أربع شاشات «البيانات المرجعية» التي تتشارك نمطاً واحداً (`MasterDataAsyncView` + `EntityList` + `MasterDataTile` + ورقة نموذج) — انظر [`design-system.md`](../design-system.md) §نمط شاشة البيانات المرجعية.

## العناصر

| # | الـ Widget class الفعلي | الحجم / اللون / الخط / المسافات | الظهور والتفاعل |
|:-:|---|---|---|
| 1 | `Scaffold` + `QtmsTopBar` | `screenTitle: 'المصادر'` | |
| 2 | `FloatingActionButton.extended` — «مصدر جديد» | `Icons.add_business_outlined` · خلفية `surfaceInverse` · `elevation: 0` · `Radii.field = 14` | `PermissionGate(sourceWrite)`. **Trigger** لورقة النموذج. |
| 3 | `MasterDataAsyncView<SourceCard>` > `AsyncStateView` | — | موزّع الحالات الثلاث (هيكل · خطأ · فارغ · بيانات). |
| 4 | `EntityList` > `ListView.separated` | حشو أفقي `Breakpoints.gutter(width)` · سفلي `fabSafeBottom = 96` · فاصل `cardGap = 12` | |
| 5 | `MasterDataTile` > `EntityTile` | سطح `surface` · حدّ `border` 1px · `Radii.card = 20` · حشو 16 · `minHeight: 56` | **`actionsPlacement: EntityActionsPlacement.inline`** ⟵ **زرُّ التعديل في صفّ العنوان نفسه**، لا في صفٍّ سفلي. |
| 6 | `Text` — العنوان | `TypeScale.titleSm` | اسم المصدر. |
| 7 | `Text` — الثانوي | `TypeScale.bodyMd` · `textSecondary` | **يقول القاعدة السارية لا وصفاً حرّاً:** «الرعوي إلزامي عند التوريد» أو «الرعوي غير مطلوب عند التوريد». |
| 8 | `IconButton` (في `leading`) — سجل التدقيق | من `auditTrailLeading(...)` بـ`sourceId` | **شرطي:** لمن يملك مفتاح عرض سجل الكيان. |
| 9 | `DisabledBadge` > `StatusPill` | «معطَّل» · `triad: danger` · `icon: Icons.do_not_disturb_on_outlined` 16 · `Radii.pill` | **شرطي:** عندما `!source.isActive`. **وأيقونةٌ مع اللون دائماً** ⟵ فلا معنى يُنقَل باللون وحده. |
| 10 | `IconButton` — تعديل | `Icons.edit_outlined` بحجم `Sizes.iconMd = 20` · `tooltip: 'تعديل'` · `constraints` صريحة 48×48 | `PermissionGate(sourceWrite)`. **Trigger** لورقة النموذج بوضع التعديل. |

### ورقة نموذج المصدر — `SourceFormSheet`
**Trigger:** الزرُّ العائم ② (إنشاء) أو زرُّ التعديل ⑩. `showModalBottomSheet` بـ`isScrollControlled: true` · خلفية `surface` · انحناء علوي `Radii.sheet = 28` · مقبض سحب `neutral300` · حشو سفلي `viewInsets.bottom` · جسمها `SingleChildScrollView` بحشو 16.

| # | الـ Widget class | التفاصيل |
|:-:|---|---|
| أ | `Text` | «مصدر جديد» أو «تعديل مصدر» — `TypeScale.titleLg`. |
| ب | `MasterDataField` «اسم المصدر» | `autofocus: true`. |
| ج | `SwitchListTile` «يجب اختيار الرعوي عند التوريد» | `contentPadding: zero` · النصّ الثانوي «لا يؤثر على المستندات السابقة — يُطبَّق على الجديدة فقط.» · مسار المفتاح `primary500` عند التفعيل. |
| د | `MasterDataField` «ملاحظات (اختياري)» | |
| هـ | `SwitchListTile` «المصدر نشط» | **تعديلاً فقط.** النصّ الثانوي «التعطيل بديل الحذف — ولا حذف للمصادر.» |
| و | `MasterDataField` «سبب التعطيل» | **شرطيٌّ داخل الشرطي:** يظهر فقط عند إطفاء مفتاح هـ. ⚠️ **وهو حقلٌ إلزاميٌّ منطقياً** (يفحصه `validateSource`) ⛔ **لكنّ الزرَّ لا يُعطَّل لغيابه** — يُرفَض بعد الضغط. |
| ز | `MasterDataField` «سبب التعديل (اختياري)» | **تعديلاً فقط** · `blankToNull` — الفراغ يُقرأ غياباً. |
| ح | `RejectionBanner` | **شرطي.** |
| ط | `FilledButton` | «إنشاء» أو «حفظ التعديل». |
| ي | `Text` تذييلي | **إنشاءً فقط:** «يُنشأ للمصدر تلقائياً حسابٌ لكل مقوت ولكل رعوي، ويُوصَل به نوع «السكرب».» — `bodyMd`/`textSecondary`/`center`. |

## شجرة الـ Widget tree
```
Scaffold
├── appBar: QtmsTopBar («المصادر»)
├── floatingActionButton: PermissionGate(sourceWrite) → FloatingActionButton.extended
└── body: MasterDataAsyncView<SourceCard> → AsyncStateView
    ├── hasError → QtmsErrorState (permission-denied مُميَّز · «تفاصيل تقنية» قابلة للطيّ)
    ├── data []  → QtmsEmptyState (warehouse_outlined · ثلاثية masterData = cat2 مائي)
    ├── loading  → SkeletonList (4 بطاقات)
    └── data     → EntityList → ListView.separated
        └── _SourceTile → MasterDataTile → EntityTile (inline)
            ├── leading: [شرطي] IconButton (سجل التدقيق)
            ├── title: Text (اسم المصدر)
            ├── subtitle: Text (قاعدة الرعوي)
            ├── badges: [شرطي] DisabledBadge
            └── actions inline: PermissionGate(sourceWrite) → IconButton (edit_outlined)
```

## الحالات المُعالجة
| الحالة | الوضع |
|---|---|
| Loading | ✅ `SkeletonList` — أربع بطاقات بوميض 1200ms يتوقّف كلياً مع «تقليل الحركة». وأثناء إرسال الورقة يُعطَّل الزرّ ⛔ بلا مؤشّر. |
| Error | ✅ `QtmsErrorState` — يُميّز `permission-denied` عن الفشل العام، أيقونة في `IconBadgeBox` 64 بثلاثية `danger`، وزرُّ «تفاصيل تقنية» بـ`AnimatedCrossFade`. ⚠️ **بلا زرّ «إعادة المحاولة»** (`onRetry` غير مُمرَّر). |
| Empty | ✅ «لا توجد مصادر بعد» + «المصدر وحدة الفصل العليا في النظام — أنشئ أول مصدر لتبدأ تسجيل حركاته.» — بثلاثية `masterData`. ⚠️ بلا زرّ إجراء داخلها. |

## آلية التنقل
- **الدخول إليها:** «لوحة اليوم» ⟶ «البيانات المرجعية» ⟶ «المصادر» (بمفتاح `sourceWrite`).
- **الخروج منها:** ⛔ **لا مسارَ خارجاً** — كلُّ العمل في ورقة سفلية. الرجوع بزرّ النظام.

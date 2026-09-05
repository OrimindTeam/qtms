# الرعية

| البند | القيمة |
|---|---|
| **اسم الكلاس** | `SuppliersScreen` (`ConsumerWidget`) |
| **مسار الملف** | `lib/capabilities/master_data/presentation/suppliers_screen.dart` |
| **المسار الملاحي** | `/home/suppliers` — `suppliersRoute` |
| **اسم الشاشة في الشريط** | «الرعية» |
| **اسم اللقطة المتوقّع** | `suppliers_screen.png` · وللورقة: `supplier_form_sheet.png` |

## الغرض
سجلُّ الرعية (مورّدو الجواني) لنسبة الجواني الواردة إليهم ومتابعة صافيهم. ⛔ **ولا حذف للرعية** — التعطيل بديلُه. من عائلة شاشات «البيانات المرجعية» الأربع بنمطها الواحد — انظر [`design-system.md`](../design-system.md) §نمط شاشة البيانات المرجعية.

## العناصر

| # | الـ Widget class الفعلي | الحجم / اللون / الخط / المسافات | الظهور والتفاعل |
|:-:|---|---|---|
| 1 | `Scaffold` + `QtmsTopBar` | `screenTitle: 'الرعية'` | |
| 2 | `FloatingActionButton.extended` — «رعوي جديد» | `Icons.person_add_alt_1_outlined` · خلفية `surfaceInverse` · `elevation: 0` | `PermissionGate(supplierWrite)`. **Trigger** لورقة النموذج. |
| 3 | `MasterDataAsyncView<SupplierCard>` | — | موزّع الحالات. |
| 4 | `EntityList` > `ListView.separated` | حشو أفقي متجاوب · سفلي 96 · فاصل 12 | |
| 5 | `MasterDataTile` > `EntityTile` | سطح `surface` · حدّ 1px · `Radii.card = 20` · حشو 16 | **`actionsPlacement: inline`** — زرُّ التعديل في صفّ العنوان. |
| 6 | `Text` — العنوان | `TypeScale.titleSm` | اسم الرعوي. |
| 7 | `Text` — الثانوي | `TypeScale.bodyMd` · `textSecondary` | **رقم الهاتف** (`supplier.phone`) — حقلٌ إلزاميٌّ في هذا الكيان فلا بديلَ نصّياً له. |
| 8 | `IconButton` (في `leading`) — سجل التدقيق | من `auditTrailLeading(...)` · ⛔ **بلا `sourceId`** — الرعوي كيانٌ مركزي لا يتبع مصدراً | **شرطي.** |
| 9 | `DisabledBadge` > `StatusPill` | «معطَّل» · `triad: danger` · `icon: do_not_disturb_on_outlined` | **شرطي:** عندما `!supplier.isActive`. |
| 10 | `IconButton` — تعديل | `Icons.edit_outlined` 20 · `tooltip: 'تعديل'` · هدف لمس 48×48 صريح | `PermissionGate(supplierWrite)`. **Trigger** للورقة بوضع التعديل. |

### ورقة نموذج الرعوي — `SupplierFormSheet`
**Trigger:** الزرُّ العائم ② أو زرُّ التعديل ⑩. `showModalBottomSheet` بـ`isScrollControlled: true` · انحناء علوي 28 · مقبض سحب · حشو سفلي `viewInsets.bottom` · `SingleChildScrollView` بحشو 16.

| # | الـ Widget class | التفاصيل |
|:-:|---|---|
| أ | `Text` | «رعوي جديد» أو «تعديل رعوي» — `TypeScale.titleLg`. |
| ب | `OutlinedButton.icon` «جلب من جهات الاتصال» | `Icons.contacts_outlined` · ارتفاع ≥ 48 · سطح `surface` بحدّ `border`. **شرطي:** يظهر فقط إن كان `contactPickerProvider` غير `null`. يفتح **منتقي جهات اتصال المنصّة** عبر `MethodChannel('dev.orimind.qtms/contacts')` — أي **واجهة نظام خارج التطبيق** لا حواراً داخلياً. عند النجاح يُعبِّئ الاسم (إن وُجد) والهاتف. |
| ج | `MasterDataField` «اسم الرعوي» | `autofocus: true`. |
| د | `MasterDataField` «رقم الهاتف» | `keyboardType: TextInputType.phone`. |
| هـ | `MasterDataField` «ملاحظات (اختياري)» | |
| و | `SwitchListTile` «الرعوي نشط» | **تعديلاً فقط** · النصّ الثانوي «التعطيل بديل الحذف — ولا حذف للرعية.» |
| ز | `MasterDataField` «سبب التعطيل» | **شرطيٌّ داخل الشرطي:** عند إطفاء مفتاح و. إلزاميٌّ منطقياً ⛔ **والزرُّ لا يُعطَّل لغيابه.** |
| ح | `MasterDataField` «سبب التعديل (اختياري)» | **تعديلاً فقط** · `blankToNull`. |
| ط | `RejectionBanner` | **شرطي.** |
| ي | `FilledButton` | «إنشاء» أو «حفظ التعديل». ⛔ **ولا نصَّ تذييليٍّ هنا** — بخلاف ورقتَي المصدر والمقوت. |

## شجرة الـ Widget tree
```
Scaffold
├── appBar: QtmsTopBar («الرعية»)
├── floatingActionButton: PermissionGate(supplierWrite) → FloatingActionButton.extended
└── body: MasterDataAsyncView<SupplierCard> → AsyncStateView
    ├── hasError → QtmsErrorState
    ├── data []  → QtmsEmptyState (agriculture_outlined · ثلاثية masterData)
    ├── loading  → SkeletonList
    └── data     → EntityList → ListView.separated
        └── _SupplierTile → MasterDataTile → EntityTile (inline)
            ├── leading: [شرطي] IconButton (سجل التدقيق)
            ├── title: Text (اسم الرعوي)
            ├── subtitle: Text (رقم الهاتف)
            ├── badges: [شرطي] DisabledBadge
            └── actions inline: PermissionGate(supplierWrite) → IconButton (edit_outlined)
```

## الحالات المُعالجة
| الحالة | الوضع |
|---|---|
| Loading | ✅ `SkeletonList`. وأثناء الإرسال يُعطَّل الزرّ ⛔ بلا مؤشّر. |
| Error | ✅ `QtmsErrorState` بتمييز `permission-denied` + «تفاصيل تقنية». ⚠️ بلا زرّ إعادة محاولة. **وفشلُ منتقي جهات الاتصال صامتٌ تماماً** (`PlatformException` و`MissingPluginException` تُرجَعان `null`) ⛔ **بلا رسالة للمستخدم.** |
| Empty | ✅ «لا يوجد رعية بعد» + «أضف أول رعوي لتنسب إليه الجواني الواردة وتتابع صافيه.» |

## آلية التنقل
- **الدخول إليها:** «لوحة اليوم» ⟶ «البيانات المرجعية» ⟶ «الرعية» (بمفتاح `supplierWrite`).
- **الخروج منها:** ⛔ **لا مسارَ داخليٍّ خارجاً** — لكنّ زرَّ «جلب من جهات الاتصال» يُخرِج المستخدم مؤقتاً إلى **تطبيق جهات الاتصال في النظام**. الرجوع بزرّ النظام.

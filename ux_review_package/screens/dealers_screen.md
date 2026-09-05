# المقاوته

| البند | القيمة |
|---|---|
| **اسم الكلاس** | `DealersScreen` (`ConsumerWidget`) |
| **مسار الملف** | `lib/capabilities/master_data/presentation/dealers_screen.dart` |
| **المسار الملاحي** | `/home/dealers` — `dealersRoute` |
| **اسم الشاشة في الشريط** | «المقاوته» |
| **اسم اللقطة المتوقّع** | `dealers_screen.png` · وللورقة: `dealer_form_sheet.png` |

## الغرض
سجلُّ المقاوته (المشترون على الذمّة) للتوزيع عليهم ومتابعة ذممهم. ⛔ **ولا حذف** — التعطيل بديلُه. **وهذه الشاشة تحمل الحقل الأصعب في عائلة البيانات المرجعية:** إقرارُ التعطيل رغم الرصيد. من عائلة الشاشات الأربع بنمطها الواحد — انظر [`design-system.md`](../design-system.md) §نمط شاشة البيانات المرجعية.

## العناصر

| # | الـ Widget class الفعلي | الحجم / اللون / الخط / المسافات | الظهور والتفاعل |
|:-:|---|---|---|
| 1 | `Scaffold` + `QtmsTopBar` | `screenTitle: 'المقاوته'` | |
| 2 | `FloatingActionButton.extended` — «مقوت جديد» | `Icons.person_add_alt_outlined` (⚠️ **يختلف عن أيقونة الرعوي** `person_add_alt_1_outlined`) · خلفية `surfaceInverse` · `elevation: 0` | `PermissionGate(dealerWrite)`. **Trigger** لورقة النموذج. |
| 3 | `MasterDataAsyncView<DealerCard>` | — | موزّع الحالات. |
| 4 | `EntityList` > `ListView.separated` | حشو أفقي متجاوب · سفلي 96 · فاصل 12 | |
| 5 | `MasterDataTile` > `EntityTile` | سطح `surface` · حدّ 1px · `Radii.card = 20` · حشو 16 | **`actionsPlacement: inline`**. |
| 6 | `Text` — العنوان | `TypeScale.titleSm` | اسم المقوت. |
| 7 | `Text` — الثانوي | `TypeScale.bodyMd` · `textSecondary` | رقم الهاتف. |
| 8 | `IconButton` (في `leading`) — سجل التدقيق | من `auditTrailLeading(...)` بلا `sourceId` | **شرطي.** |
| 9 | `DisabledBadge` > `StatusPill` | «معطَّل» · `triad: danger` · `icon: do_not_disturb_on_outlined` | **شرطي:** عندما `!dealer.isActive`. |
| 10 | `IconButton` — تعديل | `Icons.edit_outlined` 20 · `tooltip: 'تعديل'` · هدف لمس 48×48 | `PermissionGate(dealerWrite)`. **Trigger** للورقة بوضع التعديل. |
| ⛔ | **لا رصيد معروضٌ في البطاقة** | — | ⚠️ **ملاحظة UX:** ذمّةُ المقوت **لا تظهر في هذه الشاشة إطلاقاً** — مكانها «كشف حساب المقوت» (`/home/dealer-statement`). |

### ورقة نموذج المقوت — `DealerFormSheet`
**Trigger:** الزرُّ العائم ② أو زرُّ التعديل ⑩. `showModalBottomSheet` بـ`isScrollControlled: true` · انحناء علوي 28 · مقبض سحب · حشو سفلي `viewInsets.bottom` · `SingleChildScrollView` بحشو 16.

| # | الـ Widget class | التفاصيل |
|:-:|---|---|
| أ | `Text` | «مقوت جديد» أو «تعديل مقوت» — `TypeScale.titleLg`. |
| ب | `OutlinedButton.icon` «جلب من جهات الاتصال» | `Icons.contacts_outlined`. **شرطي** على `contactPickerProvider != null`. يفتح **منتقي جهات اتصال المنصّة** (قناة `dev.orimind.qtms/contacts`) — واجهة نظام خارج التطبيق. |
| ج | `MasterDataField` «اسم المقوت» | `autofocus: true`. |
| د | `MasterDataField` «رقم الهاتف» | `keyboardType: TextInputType.phone`. |
| هـ | `MasterDataField` «ملاحظات (اختياري)» | |
| و | `SwitchListTile` «المقوت نشط» | **تعديلاً فقط.** النصّ الثانوي **يقول أثراً دقيقاً لا شعاراً:** «المعطَّل لا يظهر في التوزيع الجديد — ويظهر في المقبوضات.» ⟵ **فالتعطيل لا يقطع تحصيل ذمّته.** |
| ز | `MasterDataField` «سبب التعطيل» | **شرطيٌّ داخل الشرطي:** عند إطفاء مفتاح و. |
| ح | `MasterDataField` «إقرار التعطيل رغم الرصيد (إن وُجد رصيد)» | **شرطيٌّ داخل الشرطي كذلك.** ⚠️★ **حقلٌ حاكم:** تعطيلُ مقوتٍ رصيده ≠ 0 يشترط ثلاثةً مجتمعة — مفتاحٌ مستقلٌّ (`dealerDisableWithBalance`) + **هذا الإقرار النصّي غير الفارغ** + رصيدٌ مقيسٌ في الخادم داخل المعاملة. ⛔ **والشاشة لا تعرف الرصيد ولا تقيسه** — فالحقل معروضٌ دائماً عند التعطيل بصيغةٍ شرطيةٍ في تسميته («إن وُجد رصيد»)، **والرفضُ يأتي من الخادم لا من الشاشة.** |
| ط | `MasterDataField` «سبب التعديل (اختياري)» | **تعديلاً فقط** · `blankToNull`. |
| ي | `RejectionBanner` | **شرطي.** |
| ك | `FilledButton` | «إنشاء» أو «حفظ التعديل». |
| ل | `Text` تذييلي | **إنشاءً فقط:** «يُنشأ للمقوت تلقائياً حسابٌ في كل مصدر قائم، وفي كل مصدر يُضاف مستقبلاً.» — `bodyMd`/`textSecondary`/`center`. |

## شجرة الـ Widget tree
```
Scaffold
├── appBar: QtmsTopBar («المقاوته»)
├── floatingActionButton: PermissionGate(dealerWrite) → FloatingActionButton.extended
└── body: MasterDataAsyncView<DealerCard> → AsyncStateView
    ├── hasError → QtmsErrorState
    ├── data []  → QtmsEmptyState (handshake_outlined · ثلاثية masterData)
    ├── loading  → SkeletonList
    └── data     → EntityList → ListView.separated
        └── _DealerTile → MasterDataTile → EntityTile (inline)
            ├── leading: [شرطي] IconButton (سجل التدقيق)
            ├── title: Text (اسم المقوت)
            ├── subtitle: Text (رقم الهاتف)
            ├── badges: [شرطي] DisabledBadge
            └── actions inline: PermissionGate(dealerWrite) → IconButton (edit_outlined)
```

## الحالات المُعالجة
| الحالة | الوضع |
|---|---|
| Loading | ✅ `SkeletonList`. وأثناء الإرسال يُعطَّل الزرّ ⛔ بلا مؤشّر. |
| Error | ✅ `QtmsErrorState` بتمييز `permission-denied` + «تفاصيل تقنية». ⚠️ بلا زرّ إعادة محاولة. **وفشلُ منتقي جهات الاتصال صامت.** |
| Empty | ✅ «لا يوجد مقاوته بعد» + «أضف أول مقوت لتتمكّن من التوزيع عليه ومتابعة ذمته.» |

## آلية التنقل
- **الدخول إليها:** «لوحة اليوم» ⟶ «البيانات المرجعية» ⟶ «المقاوته» (بمفتاح `dealerWrite`).
- **الخروج منها:** ⛔ **لا مسارَ داخليٍّ خارجاً** — وزرُّ جهات الاتصال يُخرِج مؤقتاً إلى تطبيق النظام. الرجوع بزرّ النظام.

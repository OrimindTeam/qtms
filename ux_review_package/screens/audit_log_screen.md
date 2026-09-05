# سجل التدقيق

| البند | القيمة |
|---|---|
| **اسم الكلاس** | `AuditLogScreen` (`ConsumerWidget`) |
| **مسار الملف** | `lib/capabilities/oversight/presentation/audit_log_screen.dart` |
| **مكوّن القائمة والبطاقة** | `lib/capabilities/oversight/presentation/audit_trail_view.dart` — `AuditTrailList` · `AuditEntryCardView` · `AuditTrailButton` |
| **المسار الملاحي** | `/home/audit` — `auditLogRoute` |
| **اسم الشاشة في الشريط** | «سجل التدقيق» |
| **أسماء اللقطات المتوقّعة** | `audit_log_screen.png` · وللورقة: `audit_trail_sheet.png` |

## الغرض
السجلُّ المركزيُّ لكل نشاطٍ في النظام — **للإضافة فقط، لا يُعدَّل ولا يُمسح منه شيءٌ ولا لأحدٍ بمن فيهم المالك.** ★ **ومكوّناتُه نفسُها تُستعمَل في ورقةٍ سفليةٍ صغيرةٍ (`AuditTrailButton`) على بطاقات المستخدمين والمصادر والرعية والمقاوته والأنواع والمستندات** ⟵ **فسجلُّ الكيان الواحد ليس شاشةً ثانيةً بل نفسُ المكوّن بنطاقٍ أضيق.**

## العناصر — الشاشة

| # | الـ Widget class الفعلي | الحجم / اللون / الخط / المسافات | الظهور والتفاعل |
|:-:|---|---|---|
| 1 | `Scaffold` + `QtmsTopBar` | `screenTitle: 'سجل التدقيق'` · ⛔ بلا زرٍّ عائم | |
| 2 | `_FilterBar` > `QtmsFilterBar` | حشو أفقي 16 ورأسي 8 · `Wrap` بفاصل 8 أفقياً ورأسياً · شرائح بارتفاع 36 مرفوعاً إلى 48 · `StadiumBorder` · **النشطة بتعبئة `primary50` وعلامة صحّ `primary700`** | ⭐ **مجموعتان مرئيتان دائماً** ⛔ لا مطويّتان: **① المصدر** (خياراتٌ من `auditSourceOptionsProvider`) · **② الفعل**. |
| 3 | مجموعةُ الأفعال | — | «كل الأفعال» ثم **سبعةُ أفعالٍ قابلةٍ للترشيح**: `create` · `amend` · `cancel` · `disable` · `permissionChange` · `delete` · `disposal`. ⚠️ **وهي أقلُّ من الأفعال المسجَّلة كلِّها** (`signIn` · `export` · `depositConfirm` · `lostWeightConfirm` · `agedRemainderClear` **تُسجَّل ولا تُرشَّح**) ⟵ فتظهر في القائمة تحت «كل الأفعال» فقط. |
| 4 | `QtmsFilterBar.notice` | نصٌّ `bodyMd`/`textSecondary` | **بديلُ الشريط كلِّه** إن خلا النطاق: «لا يوجد مصدر ضمن نطاقك. راجع المدير.» |
| 5 | `_AppendOnlyNotice` > `Container` | تعبئة `surfaceSunken` · حدّ `border` · `Radii.card = 20` · حشو 12 · هامشٌ أفقي 16 · `Icons.lock_outline` بحجم `Sizes.iconMd = 20` بـ`textSecondary` | ⭐★ **لافتةٌ ثابتةٌ تقول العقدَ نصّاً:** «هذا السجل للإضافة فقط — **لا يُعدَّل ولا يُمسح منه شيء، ولا لأحد بمن فيهم المالك**.» ⟵ **فقاعدةُ النزاهة مكتوبةٌ في الشاشة** لا مفترَضةً. |
| 6 | `AuditTrailList` > `AsyncStateView` | حشو أفقي 16 · **`shrinkWrap: false`** هنا (قائمةٌ كاملةُ الشاشة) · فاصل `Spacing.space8` = 8 | القائمةُ المركزية. |
| 7 | زرُّ إعادة المحاولة | — | ✅ **`onRetry` مُمرَّرٌ فعلاً** (`ref.invalidate(centralAuditLogProvider)`) ⟵ فيظهر `FilledButton` «إعادة المحاولة» داخل حالة الخطأ. |

## بطاقةُ القيد — `AuditEntryCardView`

| # | الـ Widget class | التفاصيل |
|:-:|---|---|
| أ | `Container` | سطح `surface` · حدّ `border` 1px · `Radii.card = 20` · حشو `Spacing.cardPadding` = 16. |
| ب | `StatusPill` — الفعل | ⭐★ **أيقونةٌ وثلاثيةٌ لكل فعل** — `Radii.pill` · `TypeScale.label`: **`create`** ⟶ `add_circle_outline` بثلاثية `success` · **`amend`** ⟶ `history_edu_outlined` بـ`warning` · **`cancel`** ⟶ `cancel_outlined` بـ`danger` · **`disable`** ⟶ `do_not_disturb_on_outlined` بـ`warning` · **`delete`** ⟶ `folder_delete_outlined` بـ`danger` · **`disposal`** ⟶ `delete_forever_outlined` بـ`danger` · **`signIn`** ⟶ `login_outlined` · **`export`** ⟶ `ios_share_outlined` · **`depositConfirm`** ⟶ `account_balance_outlined` · **`lostWeightConfirm`** ⟶ `scale_outlined` · **`permissionChange`** ⟶ `admin_panel_settings_outlined` · **`agedRemainderClear`** ⟶ `schedule_outlined` · **والمجهول** ⟶ `help_outline` — والخمسةُ الأخيرةُ وما لم يُذكَر بثلاثية `neutral`. ⟵ ★ **فالفعلُ يُقرأ بأيقونته ونصِّه ولونه معاً** ⛔ لا باللون وحده. |
| ج | `Text` — الطابعُ الزمني | `TypeScale.numericSm` (**أرقامٌ جدولية**) بـ`textSecondary` · في نهاية الصفّ بعد `Spacer` | من `timestampLabel` — **بتوقيت UTC** بصيغة «{التاريخ} {ساعة}:{دقيقة}». |
| د | `Text` — اسمُ الفاعل | `TypeScale.titleSm` (15 · w600) · يسبقه `SizedBox(8)` | **مَن فعل.** |
| هـ | `Text` — بريدُ الفاعل | `TypeScale.caption` · `textTertiary` · `maxLines: 1` + `ellipsis` · يسبقه `SizedBox(2)` | **شرطي.** |
| و | `Text` — سطرُ الهدف | `TypeScale.bodyMd` · `textSecondary` · يسبقه `SizedBox(4)` | «{نوعُ الكيان}: {رقمُ المستند أو معرّفُه}» — **ويزيد « · مخزون {التاريخ}»** إن كان للقيد تاريخُ مخزون ⟵ **فيُفرَّق تاريخُ الحدث من تاريخ المخزون.** |
| ز | `Divider` | `height: 1` بلون `divider` · حشو علوي 12 وسفلي 8 | **شرطي:** يفصل الترويسةَ عن جدول التغييرات إن وُجدت تغييرات. |
| ح | `_ChangeRow` > `Wrap` | فاصل 8 · `crossAxisAlignment: center` · حشو سفلي 4 | ⭐★ **سطرُ تغييرٍ بصيغة «قبل ⟶ بعد»:** تسميةُ الحقل بـ`label`/`textSecondary` · ثم **القيمةُ القديمة بـ`numericSm`/`textTertiary` مشطوبةً** (`lineThrough` — **وبلا شطبٍ إن كانت `null`**) · ثم **`Icons.arrow_forward` بحجم 16** بـ`textTertiary` · ثم القيمةُ الجديدة بـ`numericSm`/`textPrimary`. **و`Wrap` لا `Row`** ⟵ **فالسطرُ الطويل ينزل ولا يفيض.** |
| ط | تنسيقُ القيم (`_valueLabel`) | ⭐ **سبعُ حالاتٍ مقروءةٌ لا خامّة:** `null` ⟶ **«لا قيمة»** · `true` ⟶ «نعم» · `false` ⟶ «لا» · `DateTime` ⟶ طابعٌ زمنيٌّ مقروء · `List` ⟶ **«قائمة (N)»** · `Map` ⟶ **«حقول (N)»** · `String` ⟶ عبر `auditValueLabel` (فتُترجَم الرموزُ إلى عربية) · وما سواه ⟶ نصُّه. ⟵ **فلا يرى المستخدم JSON خاماً.** |
| ي | `Text` — السبب | `TypeScale.bodyMd` بـ`textPrimary` · يسبقه `SizedBox(8)` | ⭐ **شرطي:** «السبب: {النصّ}» — **ويغيب كلياً إن لم يكتب المستخدم سبباً** ⟵ ★ **فالسببُ اختياريٌّ في كل العمليات، وما لم يكتبه إنسانٌ لا يُخزَّن ولا يُعرَض.** |

## ورقةُ سجل الكيان — `showAuditTrailSheet`
**Trigger:** `AuditTrailButton` > `IconButton` بـ`Icons.history` (حجم 20 · هدف لمس 48×48 · `tooltip: 'سجل التغييرات'`) — **يظهر في خانة `leading` على بطاقات:** المستخدمين · المصادر · الرعية · المقاوته · الأنواع · الوارد عدداً · الجواني · التوزيعات · المبيعات النقدية · وحركاتِ «مخزون اليوم».

| البند | التفصيل |
|---|---|
| ظهورُ الزرّ | ⭐★ **ثلاثةُ شروطٍ مجتمعةٍ في `auditTrailLeading`:** ① `canViewAuditTrailProvider` ② `entityType` و`entityId` غيرُ فارغَين ③ `sourceId` غيرُ فارغ — **وإلّا يُرجَع `null`** فلا خانةَ `leading` أصلاً. |
| الورقة | `showModalBottomSheet` بـ`isScrollControlled` · خلفية `surface` · **`shape` مُمرَّرٌ صراحةً بانحناءٍ علويٍّ `Radii.sheet = 28`** · مقبضُ سحبٍ `neutral300` · `SafeArea` وحشو 16. |
| العنوان | `Text` «سجل التغييرات — {اسمُ الكيان}» بـ`TypeScale.titleMd` (17 · w600). |
| السقف | ⭐ **`ConstrainedBox(maxHeight: نصفُ ارتفاع الشاشة)`** ⟵ فلا تطول الورقةُ بلا حدّ. |
| المحتوى | نفسُ `AuditTrailList` — **لكن بـ`shrinkWrap: true` و`ClampingScrollPhysics`** ⟵ **فالقائمةُ تنكمش لمحتواها داخل الورقة.** |
| الفراغ | «لم يُسجَّل على هذا السجل أي تغيير بعد.» ⚠️ **بخلاف رسالةِ الشاشة المركزية.** |
| إعادةُ المحاولة | ✅ `onRetry` مُمرَّرٌ كذلك (`invalidate(entityAuditLogProvider(entity))`). |

## شجرة الـ Widget tree
```
Scaffold (بلا FAB)
├── appBar: QtmsTopBar («سجل التدقيق»)
└── Column
    ├── _FilterBar
    │   ├── [لا مصادر] QtmsFilterBar.notice («لا يوجد مصدر ضمن نطاقك…»)
    │   └── QtmsFilterBar (مجموعتان)
    │       ├── مجموعة المصدر (ChoiceChip × N)
    │       └── مجموعة الفعل («كل الأفعال» + 7 أفعال قابلة للترشيح)
    ├── _AppendOnlyNotice (surfaceSunken · lock_outline · «للإضافة فقط…»)
    ├── SizedBox (8)
    └── Expanded → Padding(أفقي 16) → AuditTrailList → AsyncStateView
        ├── hasError → QtmsErrorState (+ ⭐ زرّ «إعادة المحاولة» ← invalidate)
        ├── data []  → QtmsEmptyState («لا نشاط مُسجَّل» + «لا يوجد نشاط يطابق الفلتر
        │              الحالي — وسّع المدى أو أزل الفلتر.» · ثلاثية identity)
        ├── loading  → SkeletonList
        └── data → ListView.separated (shrinkWrap: false · فاصل 8)
            └── AuditEntryCardView × N → Container
                ├── Row: StatusPill (الفعل — أيقونة+ثلاثية) + Spacer + Text (الطابع الزمني)
                ├── Text (اسم الفاعل — titleSm)
                ├── [شرطي] Text (البريد — caption/textTertiary)
                ├── Text (سطر الهدف: «{نوع الكيان}: {المرجع} · مخزون {التاريخ}»)
                ├── [شرطي] Divider + _ChangeRow × N
                │   └── Wrap: تسمية + القيمة القديمة (مشطوبة) + arrow_forward + القيمة الجديدة
                └── [شرطي] Text «السبب: …»

AuditTrailButton (على بطاقات الكيانات) → showAuditTrailSheet
└── ورقة سفلية (Radii.sheet 28 · maxHeight نصف الشاشة)
    ├── Text «سجل التغييرات — {الكيان}» (titleMd)
    └── AuditTrailList (shrinkWrap: true · ClampingScrollPhysics)
```

## الحالات المُعالجة
| الحالة | الوضع |
|---|---|
| Loading | ✅ `SkeletonList`. **وشريطُ المرشِّحات ولافتةُ العقد يبقيان ظاهرَين** فوقه ⟵ فالترشيحُ ممكنٌ أثناء التحميل. |
| Error | ✅★ **كاملة:** `QtmsErrorState` بالرسالة الإرشادية الموحّدة («تحقق من صلاحيتك ونطاق مصادرك، ثم أعد المحاولة.») **مع `detail` تقنيٍّ قابلٍ للطيّ** **و⭐ زرِّ «إعادة المحاولة» الفعّال** — **في الشاشة والورقة معاً.** |
| Empty | ✅ **رسالتان متمايزتان لنفس المكوّن:** المركزيةُ تقول **«وسّع المدى أو أزل الفلتر»** (⟵ فتنسب الفراغَ إلى المرشِّح وتقترح إصلاحَين) · **والورقةُ تقول «لم يُسجَّل على هذا السجل أي تغيير بعد.»** (⟵ فتنسبه إلى الكيان). **وثلاثيتُها `identity` (cat1 أزرق فولاذي)** من عائلة الهوية والصلاحيات. |
| القيمُ الخام | ✅ ★ **مُعالَجةٌ بسبعِ حالاتٍ مقروءة** (`null` ⟶ «لا قيمة» · قائمة ⟶ «قائمة (N)» · حقول ⟶ «حقول (N)» …) ⛔ **فلا JSON ولا `Instance of` في وجه المستخدم.** |
| فعلٌ غيرُ معروف | ✅ `Icons.help_outline` بثلاثية `neutral` ونصٌّ من `auditActionLabelOrUnknown` ⟵ **فقيدٌ من إصدارٍ أحدث يُعرَض ولا يُسقِط الشاشة.** |

## آلية التنقل
- **الدخول إليها:** «لوحة اليوم» ⟶ قسم «الرقابة» ⟶ «سجل التدقيق» (بمفتاح `auditLogViewCentral`).
- **الخروج منها:** ⛔ **لا مسارَ خارجاً** — الرجوع بزرّ النظام.
- ★ **حضورُها المتفرّق:** الورقةُ نفسُها تُفتَح من **عشرِ شاشاتٍ أخرى** عبر `auditTrailLeading` — فهي أكثرُ مكوّنٍ رقابيٍّ انتشاراً في التطبيق.

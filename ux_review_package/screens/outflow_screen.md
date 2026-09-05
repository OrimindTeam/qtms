# السحبيات والخرجيات

| البند | القيمة |
|---|---|
| **اسم الكلاس** | `OutflowScreen` (`ConsumerStatefulWidget`) — والنموذج `_OutflowForm` |
| **مسار الملف** | `lib/capabilities/financial_outflow/presentation/outflow_screen.dart` |
| **المسار الملاحي** | `/home/outflows` — `outflowRoute` |
| **اسم الشاشة في الشريط** | «السحبيات والخرجيات» |
| **اسم اللقطة المتوقّع** | `outflow_screen.png` |

## الغرض
سجلَّان في شاشةٍ واحدة: **«سحبية»** (سحبُ المالك) و**«خرجية»** (مصروفٌ تشغيلي وشُقى الشُقّات). ★ **وكلٌّ منهما يقبل بنودَ قاتٍ وبنودَ مبالغَ معاً في مستندٍ واحد** ⛔ **ولا يمسّ حساباتَ المقاوته إطلاقاً.** وهي **شاشةُ نموذجٍ محضة** ⛔ بلا قائمةِ سنداتٍ سابقة وبلا زرٍّ عائم.

## العناصر

| # | الـ Widget class الفعلي | الحجم / اللون / الخط / المسافات | الظهور والتفاعل |
|:-:|---|---|---|
| 1 | `Scaffold` + `QtmsTopBar` | `screenTitle: 'السحبيات والخرجيات'` · ⛔ بلا زرٍّ عائم | |
| 2 | `QtmsEmptyState` — بلا صلاحية | `Icons.lock_outline` في `IconBadgeBox` 64 بثلاثية `neutral` · «لا صلاحية» + «ليست لديك صلاحية إضافة سحبية ولا خرجية — راجع مالك النظام.» | **بديلُ الشاشة كلِّها** إن لم يملك المستخدم `withdrawalCreate` ولا `expenseCreate`. |
| 3 | `_OutflowHeader` > `Column` | حشو أفقي 16 ورأسي 8 | منتقيان خاصّان بالشاشة ⛔ لا `QtmsContextHeader`. |
| 4 | `DropdownButtonFormField<OutflowLedgerType>` «السجل» | `key: Key('outflow-ledger-type')` · ارتفاع 52 · تعبئة `surfaceSunken` · `Radii.field = 14` | ★★ **بنودُه تُبنى من صلاحيات المستخدم لا من ثابتٍ:** «سحبية» تظهر بمفتاح `withdrawalCreate` · و«خرجية» بمفتاح `expenseCreate` ⟵ **فمن يملك واحداً يرى بنداً واحداً**، والافتراضيُّ أولُ ما يملك. |
| 5 | `DropdownButtonFormField<String>` «المصدر» | `key: Key('outflow-source')` · يسبقه `SizedBox(8)` | ⛔ **بلا بندِ «كل المصادر»** — المصدرُ إلزامي. |
| 6 | `Divider` | 1px بلون `divider` | |
| 7 | `QtmsEmptyState` — بلا مصدر | `Icons.store_outlined` · «اختر المصدر» + «المصدر إلزامي في كل سحبية وخرجية — **حتى سحبيات المالك الشخصية**.» | ⟵ **فالقاعدةُ الصارمة مشروحةٌ بمثالها.** |
| 8 | `ListView` | `padding: EdgeInsetsDirectional.all(16)` | جذر النموذج. |
| 9 | `_CategoryField` > `DropdownButtonFormField<OutflowCategory>` «الفئة» | `key: Key('outflow-category')` | ⭐ **بنودُه تتغيّر بتغيُّر السجل** (`OutflowCategory.of(ledgerType)`) ⟵ **ففئاتُ السحبية غيرُ فئات الخرجية.** |
| 10 | `_DateRow` > `Row` + `showDatePicker` | `Icons.event_outlined` + «تاريخ السند: {التاريخ}» بـ`bodyMd` + `TextButton` «تغيير» (`key: Key('outflow-date')`) | **تاريخُ السند قابلٌ للتغيير** · نطاقُ الحوار: من بداية العام الماضي **إلى اليوم** ⛔ بلا مستقبل. |
| 11 | `Text` «بنود القات» | `TypeScale.titleSm` | عنوانُ القسم الأول. |
| 12 | `Text` | `TypeScale.caption` | **بديلٌ عند الفراغ:** «لا بند قاتٍ بعد — أضف بنداً إن كان الخارج بضاعة.» |
| 13 | `QtmsItemLineRow` لكل بندِ قات | منسدلُ النوع (`DropdownMenu` ببحثٍ ومرشِّح · `menuHeight = 288`) + `IconButton` حذفٍ (`remove_circle_outline` بـ`danger.ink` · 48×48) + **حقلان** · حشو سفلي 12 | ★ **خياراتُ النوع من أرصدة دفتر اليوم** (`stockOptionsProvider`) لا من الكتالوج · والتسميةُ تحمل الرصيد · والمأخوذُ في بندٍ آخر يُخفى. |
| 14 | `TextField` «الكمية» | `key: Key('outflow-qty-N')` · `keyboardType: number` · **`suffixText`** = اسمُ الوحدة بعد اختيار النوع | ⚠️ **بلا `inputFormatters`** — بخلاف حقول الكمية في «التوزيع» و«البيع النقدي». |
| 15 | `TextField` «سعر الوحدة» | `key: Key('outflow-price-N')` · `digitsOnly` · **`enabled: _canPriceNow`** | ★★ **مفتاحُ التسعير يتبع السجل:** `withdrawalQatPriceNow` للسحبية و`expenseQatPriceNow` للخرجية. |
| 16 | **`helperText`** على «سعر الوحدة» | ⭐★ **يتبدّل بالصلاحية بدل أن يترك الحقلَ ميتاً:** «اختياري — يُسعَّر لاحقاً إن تُرك» لمن يملك المفتاح · و**«ليست لديك صلاحية التسعير الآن — سيُسعَّر لاحقاً»** لمن لا يملكه ⟵ **فتعطيلُ الحقل مفسَّرٌ في مكانه** ⛔ لا حقلٌ رماديٌّ بلا سبب. |
| 17 | `QtmsAddLineButton` > `OutlinedButton.icon` «إضافة نوع» | `key: Key('outflow-add-qat')` · `Icons.add` · مُحاذٍ للبداية | ⚠️ بلا حدٍّ أقصى. |
| 18 | `Text` «بنود المبالغ» | `TypeScale.titleSm` · يسبقه `SizedBox(16)` | عنوانُ القسم الثاني. |
| 19 | `_CashRow` > `Row` لكل بندِ مبلغ | حشو سفلي 12 · `crossAxisAlignment: start` | صفٌّ من حقلَين في `Expanded` بفاصل 8. |
| 20 | `DropdownButtonFormField<OutflowLineKind>` «النوع» | `key: Key('outflow-cash-kind-N')` | بندان ثابتان: **«مبلغ»** · **«أخرى»**. |
| 21 | `TextField` «المبلغ» | `key: Key('outflow-cash-amount-N')` · `keyboardType: number` · **`digitsOnly`** ⟵ فالكسرُ يستحيل | |
| 22 | `QtmsAddLineButton` «إضافة بند» | `key: Key('outflow-add-cash')` · **تسميةٌ مختلفةٌ عن الافتراضية** («إضافة نوع») ⟵ فالبندُ المالي ليس نوعاً | |
| 23 | `TextField` «البيان» | `key: Key('outflow-notes')` | ⚠️★ **تسميةٌ بلا كلمة «اختياري»** — بخلاف كل حقول السبب في التطبيق ⛔ **ومع ذلك لا يُشترَط ولا يُعطِّل الزرّ.** |
| 24 | `Text` — تنبيهُ البنود غير المسعَّرة | `TypeScale.bodyMd` · يسبقه `SizedBox(12)` | ⭐ **شرطي:** «⏳ {N} من بنود القات بلا سعر — **تُحفَظ ويخرج القات**، وتدخل مركز الإدخالات المعلّقة حتى تُسعَّر.» ⟵ **فالأثرُ المزدوج مُعلَنٌ قبل الحفظ.** ⚠️ **نصٌّ عارٍ بلا ثلاثيةِ لون.** |
| 25 | `QtmsStickyActionBar` | سطح `surface` بحدٍّ علويٍّ · `SafeArea(top: false)` · حشو 16 | شريطٌ لاصقٌ أسفل. |
| 26 | `QtmsLiveSummary` (في `summary`) | تعبئة `surfaceSunken` · حدّ · `Radii.card` · حشو 12 | ⭐ **ملخّصٌ حيٌّ رباعي:** «**الإجمالي النهائي: {N} ريال**» · «قيمة القات: {N}» · «المبالغ: {N}» · **«لا يمسّ حسابات المقاوته»** (⟵ القاعدةُ الحاكمةُ مكتوبةٌ في كل بناء) · **و`emphasis` شرطي: «بنود بلا سعر: {N}»** بـ`TypeScale.titleSm`. |
| 27 | `Text` (في `status`) | `TypeScale.bodyMd` | ⚠️ **حالةٌ نصّيةٌ عاريةٌ لا `QtmsActionStatus`:** «✅ حُفِظ السند {الرقم}» · «❌ أضف بنداً واحداً على الأقل — قاتاً أو مبلغاً.» · أو نصُّ الخطأ. |
| 28 | `FilledButton` | `key: Key('outflow-save')` · ارتفاع 52 | ★ **نصُّه ثلاثيُّ الحالات:** «**حفظ السحبية**» أو «**حفظ الخرجية**» بحسب السجل، و«جارٍ الحفظ…» أثناء الإرسال ⟵ **فالزرُّ يقول ما يفعله بدقّة.** ⛔ **بلا `PermissionGate`** — الحرسُ في منسدل السجل ④ نفسه. وعند النجاح تُفرَّغ كلُّ البنود والبيان. |

## شجرة الـ Widget tree
```
Scaffold (بلا FAB)
├── appBar: QtmsTopBar («السحبيات والخرجيات»)
└── body
    ├── [بلا صلاحية] QtmsEmptyState («لا صلاحية»)
    └── Column
        ├── _OutflowHeader
        │   ├── DropdownButtonFormField «السجل» (بنودُه من الصلاحيات: سحبية | خرجية)
        │   └── DropdownButtonFormField «المصدر» (⛔ بلا «كل المصادر»)
        ├── Divider (1px)
        └── Expanded
            ├── [بلا مصدر] QtmsEmptyState («اختر المصدر»)
            └── _OutflowForm → Column
                ├── Expanded → ListView (16)
                │   ├── _CategoryField → DropdownButtonFormField «الفئة» (بحسب السجل)
                │   ├── _DateRow → TextButton «تغيير» → showDatePicker
                │   ├── Text «بنود القات» (titleSm)
                │   ├── [فارغ] Text «لا بند قاتٍ بعد…» (caption)
                │   ├── QtmsItemLineRow × N
                │   │   ├── DropdownMenu (من أرصدة الدفتر)
                │   │   ├── IconButton (حذف · danger.ink)
                │   │   ├── TextField «الكمية» (+ suffixText بالوحدة)
                │   │   └── TextField «سعر الوحدة» (enabled بالصلاحية + helperText يفسّر)
                │   ├── QtmsAddLineButton «إضافة نوع»
                │   ├── Text «بنود المبالغ» (titleSm)
                │   ├── _CashRow × N → Row
                │   │   ├── DropdownButtonFormField «النوع» (مبلغ | أخرى)
                │   │   └── TextField «المبلغ» (digitsOnly)
                │   ├── QtmsAddLineButton «إضافة بند»
                │   ├── TextField «البيان»
                │   └── [شرطي] Text «⏳ N من بنود القات بلا سعر…»
                └── QtmsStickyActionBar
                    ├── summary: QtmsLiveSummary (الإجمالي · القات · المبالغ · «لا يمسّ المقاوته» · emphasis)
                    ├── status:  [شرطي] Text (✅/❌)
                    └── primary: FilledButton («حفظ السحبية» | «حفظ الخرجية» | «جارٍ الحفظ…»)
```

## الحالات المُعالجة
| الحالة | الوضع |
|---|---|
| Loading | ✅ **مُعالَجة بنصّ الزرّ** («جارٍ الحفظ…») مع تعطيله. ⛔ ولا هيكلَ عظمياً (لا قائمةَ تُقرأ). |
| Error | ✅ سطرُ حالةٍ نصّيٌّ بنصٍّ من الكتالوج. ⚠️ **بلا ثلاثيةِ لون** — الرمزُ `✅`/`❌` وحده يحمل الدلالة. |
| Empty | ✅ **ثلاثُ حالاتٍ متمايزة:** «لا صلاحية» · «اختر المصدر» · «لا بند قاتٍ بعد» (نصٌّ داخليٌّ بـ`caption`). ⚠️ **وقسمُ «بنود المبالغ» بلا نصِّ فراغٍ إطلاقاً** — يظهر عنوانُه وزرُّ الإضافة بلا شيءٍ بينهما. |
| منعٌ بالصلاحية | ✅ ★ **على ثلاثة مستوياتٍ متّسقة:** الشاشةُ كلُّها (لا سحبية ولا خرجية) · **بنودُ منسدل السجل** (كلُّ سجلٍّ بمفتاحه) · **وحقلُ السعر** (`enabled` + `helperText` يفسّر التعطيل). |
| التسعيرُ المؤجَّل | ✅ **مُعالَجٌ في موضعَين:** تنبيهٌ نصّيٌّ بعدد البنود وأثرِه المزدوج · **و`emphasis` في الملخّص الحيّ.** |
| النجاح | ✅ «✅ حُفِظ السند {الرقم}» **مع تفريغ النموذج** ⟵ فلا يُحفَظ مرتين سهواً. |

## آلية التنقل
- **الدخول إليها:** «لوحة اليوم» ⟶ «العمليات اليومية» ⟶ «السحبيات والخرجيات» (بمفتاح `withdrawalCreate` **أو** `expenseCreate`) · **ومن «مركز الإدخالات المعلّقة»** عبر `pendingScreenRoute(PendingScreen.outflow)`.
- **الخروج منها:** ⛔ **لا مسارَ خارجاً ولا ورقةَ سفلية** — و`showDatePicker` هو الحوارُ الوحيد. الرجوع بزرّ النظام.
- **أثرٌ ظاهرٌ في شاشةٍ أخرى:** السحبياتُ والخرجياتُ تظهران صفَّين في **«ضمار المالك»** (بندَين محكومَين بصلاحية) وفي **بطاقة حركة النقد** ضمن قسم «الخارج».

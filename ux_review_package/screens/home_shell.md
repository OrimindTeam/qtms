# لوحة اليوم (الصدَفة الرئيسية)

| البند | القيمة |
|---|---|
| **اسم الكلاس** | `HomeShell` (`ConsumerWidget`) |
| **مسار الملف** | `lib/capabilities/identity_access/presentation/home_shell.dart` |
| **المسار الملاحي** | `/home` — `homeRoute` |
| **اسم الشاشة في الشريط** | «لوحة اليوم» |
| **اسم اللقطة المتوقّع** | `home_shell.png` |

## الغرض
مركز الانطلاق الوحيد للتطبيق. صفّان علويان يقولان «ما يحتاج تصرُّفاً اليوم»، ثم ستّة أقسام من مداخل الأزرار مرتّبة وظيفياً. ⛔ **ولا تبويب سفلي ولا قائمة جانبية** — الملاحة كلها من هذه الشاشة بعمقٍ لا يتجاوز ثلاثة مستويات. وكلُّ مدخل مُغلَّف بـ`PermissionGate` فيغيب عمّن لا يملك مفتاحه (لا يُعطَّل بصرياً — يُحجَب تماماً).

## العناصر

| # | الـ Widget class الفعلي | الحجم / اللون / الخط / المسافات | الظهور والتفاعل |
|:-:|---|---|---|
| 1 | `Scaffold` | `appBar: QtmsTopBar(screenTitle: 'لوحة اليوم')` | الشريط العلوي الموحّد — راجع `design-system.md` §الشريط العلوي. |
| 2 | `ListView` | `padding: EdgeInsetsDirectional.all(Spacing.screenPadding)` = 16 | جذر المحتوى، قابل للتمرير. |
| 3 | `_PendingEntriesRow` > `QtmsNeedsActionRow` | `IconBadgeBox` 48×48 · `Icons.hourglass_bottom_outlined` · ثلاثية `warning` عند وجود معلّقات و`neutral` عند خلوّها · العدّاد `TypeScale.numeric` · `minHeight: Sizes.tileMinHeight = 56` · `padding: 16` · `Radii.card = 20` | صفٌّ قابل للنقر مباشرةً أعلى الشاشة. النقر ⟶ `/home/pending`. العدّاد نصّي عند الحالات الخاصة: «تعذّر» عند الخطأ · «—» أثناء التحميل · «لا شيء» عند الصفر. |
| 4 | `SizedBox` | `Spacing.space12` = 12 | |
| 5 | `_AgedRemainderRow` > `QtmsNeedsActionRow` | نفس المواصفات · الأيقونة والثلاثية **تتغيّران بشدّة التقادم** (`agedSeverityIcon` / `agedSeverityTriad`) · وعند الخلوّ `Icons.event_available_outlined` + `neutral` | النقر ⟶ `/home/aged-remainder`. النصّ الثانوي يذكر عمر الأقدم فعلياً. |
| 6 | `SizedBox` | `Spacing.space24` = 24 | |
| 7 | `QtmsHubSection` «العمليات اليومية» | العنوان `TypeScale.label` بـ`textSecondary` · فاصل بين الأبناء 8 · حشو سفلي للقسم 24 | ثلاثة عشر مدخلاً (انظر الجدول أدناه). |
| 8 | `QtmsHubSection` «البيانات المرجعية» | نفسها | المصادر · الرعية · المقاوته · الأنواع. |
| 9 | `QtmsHubSection` «الهوية والصلاحيات» | نفسها | إدارة المستخدمين · الأدوار. |
| 10 | `QtmsHubSection` «المالية» | نفسها | مالية الجواني. |
| 11 | `QtmsHubSection` «الرقابة» | نفسها | سجل التدقيق · التقارير. |
| 12 | `QtmsHubButton` | `FilledButton.icon` إن `isPrimary` (ارتفاع 52 · سطح `surfaceInverse` داكن) وإلا `OutlinedButton.icon` (ارتفاع ≥ 48 · سطح `surface` بحدّ `border`) | مدخل واحد فقط في التطبيق `isPrimary: true` وهو **«التوزيع»**. |
| 13 | `PermissionGate` / `AnyPermissionGate` | لا تُصيّر شيئاً — `SizedBox.shrink()` | مُغلِّف غير مرئي: المدخل يغيب كلياً عند غياب المفتاح. |

### مداخل «العمليات اليومية» بالترتيب الفعلي

| # | التسمية | الأيقونة | المفتاح المطلوب | الوجهة |
|:-:|---|---|---|---|
| 1 | التوزيع **(أساسي)** | `local_shipping_outlined` | `distributionCreate` | `/home/distribution` |
| 2 | البيع النقدي | `point_of_sale_outlined` | `cashSaleCreate` | `/home/cash-sales` |
| 3 | المقبوضات | `payments_outlined` | `receiptCreate` | `/home/receipts` |
| 4 | الخصومات | `percent_outlined` | `discountCreate` | `/home/discounts` |
| 5 | كشف حساب المقوت | `receipt_long_outlined` | `dealerStatementView` | `/home/dealer-statement` |
| 6 | ضمار المالك | `account_balance_wallet_outlined` | `ownerLedgerView` | `/home/owner-ledger` |
| 7 | السحبيات والخرجيات | `outbound_outlined` | `withdrawalCreate` **أو** `expenseCreate` | `/home/outflows` |
| 8 | التوريد (`supplyIntakeScreenTitle`) | `add_box_outlined` | `incomingCountWrite` **أو** `sackCreate` | `/home/supply` |
| 9 | مخزون اليوم | `inventory_2_outlined` | ⛔ **بلا بوابة** — ظاهر للجميع | `/home/stock` |
| 10 | التسعير اليومي | `sell_outlined` | ⛔ **بلا بوابة** — ظاهر للجميع | `/home/pricing` |
| 11 | الإتلاف | `no_food_outlined` | `disposalCreate` | `/home/disposal` |
| 12 | الجرد | `fact_check_outlined` | `stocktakeWrite` | `/home/stocktake` |

### مداخل الأقسام الباقية

| القسم | التسمية | الأيقونة | المفتاح | الوجهة |
|---|---|---|---|---|
| البيانات المرجعية | المصادر | `warehouse_outlined` | `sourceWrite` | `/home/sources` |
| البيانات المرجعية | الرعية | `agriculture_outlined` | `supplierWrite` | `/home/suppliers` |
| البيانات المرجعية | المقاوته | `handshake_outlined` | `dealerWrite` | `/home/dealers` |
| البيانات المرجعية | الأنواع | `category_outlined` | `itemWrite` | `/home/items` |
| الهوية والصلاحيات | إدارة المستخدمين | `group_outlined` | `userView` | `/home/users` |
| الهوية والصلاحيات | الأدوار | `badge_outlined` | `roleWrite` | `/home/roles` |
| المالية | مالية الجواني (`sackFinanceScreenTitle`) | `account_balance_wallet_outlined` | `sackView` | `/home/sack-finance` |
| الرقابة | سجل التدقيق | `fact_check_outlined` | `auditLogViewCentral` | `/home/audit` |
| الرقابة | التقارير | `assessment_outlined` | شرط مختلف: `visibleReportsProvider.isNotEmpty` (لا `PermissionGate`) | `/home/reports` |

## شجرة الـ Widget tree
```
Scaffold
├── appBar: QtmsTopBar («لوحة اليوم»)
└── ListView (padding: 16)
    ├── _PendingEntriesRow → QtmsNeedsActionRow
    ├── SizedBox (12)
    ├── _AgedRemainderRow → QtmsNeedsActionRow
    ├── SizedBox (24)
    ├── QtmsHubSection «العمليات اليومية»
    │   ├── Text (عنوان القسم — label/textSecondary)
    │   └── 13 × PermissionGate → QtmsHubButton (FilledButton.icon | OutlinedButton.icon)
    ├── QtmsHubSection «البيانات المرجعية»  (4 مداخل)
    ├── QtmsHubSection «الهوية والصلاحيات» (2)
    ├── QtmsHubSection «المالية»            (1)
    └── QtmsHubSection «الرقابة»            (2)
```

## الحالات المُعالجة
| الحالة | الوضع |
|---|---|
| Loading | ⚠️ **جزئية:** لا هيكل عظمي للشاشة. صفّا «يحتاج تصرُّفاً» يعرضان «—» في خانة العدّاد أثناء التحميل، وبقية الشاشة تُبنى فوراً. |
| Error | ⚠️ **جزئية ومقصودة:** خطأ العدّادين يُقرأ «تعذّر» في خانة العدّاد ⛔ **بلا رسالة ولا زرّ إعادة محاولة** — والشاشة تبقى صالحة للملاحة. |
| Empty | ✅ لكلٍّ من الصفّين نصٌّ خاصّ عند الخلوّ («كل مخزون الأيام الماضية صُرِّف بالكامل» · «المركز يذكّر بما تُرك لاحقاً — ولا يمنع شيئاً»). |
| بلا جلسة | `session == null` ⟶ `Scaffold(body: SizedBox.shrink())` — شاشة بيضاء صامتة لحظة إعادة التوجيه. |
| ⛔ **قسم فارغ** | `QtmsHubSection` يُرجِع `SizedBox.shrink()` إذا خلا من الأبناء — ⟵ **فلا عنوانَ قسمٍ معلَّقاً بلا مداخل** لمن لا يملك أيّاً من مفاتيحه. |

## آلية التنقل
- **الدخول إليها:** توجيه مركزي من `_redirect` عند `SessionActive` (وبعد إتمام الإعداد التأسيسي إن لزم) · ومن كل شاشة عبر `context.go(homeRoute)` غير المستعمل فعلياً — الرجوع بزرّ النظام.
- **الخروج منها:** **إلى 21 شاشة** — كل الوجهات في الجدولين أعلاه · وإلى `/home/profile` و`/home/settings` عبر ورقة الجلسة من الصورة الرمزية في الشريط العلوي.

# خريطة التنقّل — QTMS

> مستخرجةٌ من `lib/app/router.dart` (تعريفُ المسارات و`_redirect`) و`lib/app/top_bar.dart` (ورقةُ الجلسة) وكلِّ ملفات `presentation/`.

---

## 1. القواعدُ الحاكمةُ للملاحة

| القاعدة | التنفيذ |
|---|---|
| **توجيهٌ تصريحيٌّ بمسارٍ مُعرَّف** | `go_router` — `routerProvider` · ⛔ لا ملاحةٌ إجرائيةٌ بـ`MaterialPageRoute`. |
| ★★ **حارسٌ واحدٌ مركزيٌّ لا فحصٌ منسوخ** | `redirect: (_, state) => _redirect(ref, state.matchedLocation)` ⟵ **فلا شاشةَ عملٍ تُفتَح بجلسةٍ مرفوضة** ⛔ **ولا فحصُ جلسةٍ مكرَّرٌ في كل شاشة** يفترق عند أول تعديل. |
| **إعادةُ بناءٍ عند تغيُّر الجلسة** | `refreshListenable: _SessionRefreshNotifier` — يستمع إلى `sessionProvider` **و**`requiresFirstRunSetupProvider`. |
| **عمقٌ لا يتجاوز ثلاثة مستويات** | أقصى ما في التطبيق: `/home/users/:userId/permissions` و`/home/reports/:reportCode` و`/home/owner-ledger/history`. |
| ⛔ **لا تبويبٌ سفليٌّ ولا قائمةٌ جانبية** | **«لوحة اليوم» هي مركزُ الانطلاق الوحيد** — 21 مدخلاً في ستة أقسام. |
| ⛔ **لا زرَّ رجوعٍ في الشريط العلوي** | الرجوعُ بزرِّ النظام حصراً · **والخروجُ من ورقة الجلسة.** |
| **بلا شاشةِ 404** | رمزُ تقريرٍ غيرُ معروف ⟶ `ReportsScreen` نفسُها (`ReportId.tryParse` تُرجِع `null`). |

---

## 2. الحارسُ المركزي `_redirect` — منطقُه كاملاً

```
sessionProvider.value:
  null              (قيد التحميل) ⟶ /            (البداية)
  SessionSignedOut                ⟶ /login
  SessionRejected                 ⟶ /blocked
  SessionActive                   ⟶ /home
```
ثم ثلاثةُ استثناءاتٍ بالترتيب:
1. **`SessionActive` + `requiresFirstRunSetup`** ⟶ **`/setup` قسراً** من أي مسار (وإن كان فيه فلا تحويل) ⟵ **فلا يُفلَت من الإعداد التأسيسي.**
2. **`SessionActive` وهو في `/setup`** بعد إتمامه ⟶ `/home`.
3. **`SessionActive` وموقعُه يبدأ بـ`/home`** ⟶ **لا تحويل** ⟵ فالحركةُ داخل الصدَفة حرّة.

⚠️ **والنتيجةُ العملية:** `/login` و`/blocked` و`/` **لا يمكن الوصولُ إليها بجلسةٍ نشطة**، و`/home/**` لا يمكن الوصولُ إليها بغيرها.

---

## 3. جدولُ المسارات الكامل — 34 شاشة

### ما قبل الجلسة (ثلاثُ شاشاتٍ بلا شريطٍ علوي)
| المسار | الثابت | الشاشة | الملف |
|---|---|---|---|
| `/` | `splashRoute` | `_SplashScreen` (خاصٌّ داخل الموجّه) | [splash_screen.md](screens/splash_screen.md) |
| `/login` | `loginRoute` | `LoginScreen` | [login_screen.md](screens/login_screen.md) |
| `/blocked` | `blockedRoute` | `SessionBlockedScreen` | [session_blocked_screen.md](screens/session_blocked_screen.md) |

### الإعدادُ التأسيسي (مسارٌ جذريٌّ مستقل)
| المسار | الثابت | الشاشة | الملف |
|---|---|---|---|
| `/setup` | `setupRoute` | `FirstRunSetupScreen` | [first_run_setup_screen.md](screens/first_run_setup_screen.md) |

### الصدَفة ومداخلُها
| المسار | الثابت | الشاشة | المفتاحُ المطلوبُ للمدخل | الملف |
|---|---|---|---|---|
| `/home` | `homeRoute` | `HomeShell` | — | [home_shell.md](screens/home_shell.md) |
| `/home/users` | `usersRoute` | `UsersScreen` | `userView` | [users_screen.md](screens/users_screen.md) |
| `/home/users/:userId/permissions` | `permissionsRouteFor(id)` | `PermissionsScreen` | `permissionGrant` | [permissions_screen.md](screens/permissions_screen.md) |
| `/home/roles` | `rolesRoute` | `RolesScreen` | `roleWrite` | [roles_screen.md](screens/roles_screen.md) |
| `/home/profile` | `profileRoute` | `ProfileScreen` | — (ورقةُ الجلسة) | [profile_screen.md](screens/profile_screen.md) |
| `/home/settings` | `settingsRoute` | `SettingsScreen` | — (ورقةُ الجلسة) | [settings_screen.md](screens/settings_screen.md) |
| `/home/about` | `aboutRoute` | `AboutScreen` | — (من الإعدادات) | [about_screen.md](screens/about_screen.md) |
| `/home/sources` | `sourcesRoute` | `SourcesScreen` | `sourceWrite` | [sources_screen.md](screens/sources_screen.md) |
| `/home/suppliers` | `suppliersRoute` | `SuppliersScreen` | `supplierWrite` | [suppliers_screen.md](screens/suppliers_screen.md) |
| `/home/dealers` | `dealersRoute` | `DealersScreen` | `dealerWrite` | [dealers_screen.md](screens/dealers_screen.md) |
| `/home/items` | `itemsRoute` | `ItemsScreen` | `itemWrite` | [items_screen.md](screens/items_screen.md) |
| `/home/supply` | `supplyIntakeRoute` | `SupplyIntakeScreen` **(تبويبان)** | `incomingCountWrite` أو `sackCreate` | [supply_intake_screen.md](screens/supply_intake_screen.md) |
| `/home/stock` | `todayStockRoute` | `TodayStockScreen` | ⛔ **بلا مفتاح** | [today_stock_screen.md](screens/today_stock_screen.md) |
| `/home/aged-remainder` | `agedRemainderRoute` | `AgedRemainderScreen` | ⛔ **بلا مفتاح** | [aged_remainder_screen.md](screens/aged_remainder_screen.md) |
| `/home/disposal` | `disposalRoute` | `DisposalScreen` | `disposalCreate` | [disposal_screen.md](screens/disposal_screen.md) |
| `/home/stocktake` | `stocktakeRoute` | `StocktakeScreen` | `stocktakeWrite` | [stocktake_screen.md](screens/stocktake_screen.md) |
| `/home/pricing` | `dailyPricingRoute` | `DailyPricingScreen` | ⛔ **بلا مفتاح** (المفتاحُ على زرِّ الحفظ) | [daily_pricing_screen.md](screens/daily_pricing_screen.md) |
| `/home/distribution` | `distributionRoute` | `DistributionScreen` | `distributionCreate` | [distribution_screen.md](screens/distribution_screen.md) |
| `/home/cash-sales` | `cashSaleRoute` | `CashSaleScreen` | `cashSaleCreate` | [cash_sale_screen.md](screens/cash_sale_screen.md) |
| `/home/sack-finance` | `sackFinanceRoute` | `SackFinanceScreen` | `sackView` | [sack_finance_screen.md](screens/sack_finance_screen.md) |
| `/home/receipts` | `receiptRoute` | `ReceiptScreen` | `receiptCreate` | [receipt_screen.md](screens/receipt_screen.md) |
| `/home/dealer-statement` | `dealerStatementRoute` | `DealerStatementScreen` **(تبويبان)** | `dealerStatementView` | [dealer_statement_screen.md](screens/dealer_statement_screen.md) |
| `/home/discounts` | `discountRoute` | `DiscountScreen` | `discountCreate` | [discount_screen.md](screens/discount_screen.md) |
| `/home/outflows` | `outflowRoute` | `OutflowScreen` | `withdrawalCreate` أو `expenseCreate` | [outflow_screen.md](screens/outflow_screen.md) |
| `/home/owner-ledger` | `ownerLedgerRoute` | `OwnerLedgerScreen` | `ownerLedgerView` | [owner_ledger_screen.md](screens/owner_ledger_screen.md) |
| `/home/owner-ledger/history` | `ownerLedgerHistoryRoute` | `OwnerLedgerHistoryScreen` | — (من الشاشة الأمّ) | [owner_ledger_history_screen.md](screens/owner_ledger_history_screen.md) |
| `/home/audit` | `auditLogRoute` | `AuditLogScreen` | `auditLogViewCentral` | [audit_log_screen.md](screens/audit_log_screen.md) |
| `/home/pending` | `pendingEntriesRoute` | `PendingEntriesScreen` | ⛔ **بلا مفتاح** | [pending_entries_screen.md](screens/pending_entries_screen.md) |
| `/home/reports` | `reportsRoute` | `ReportsScreen` | `visibleReportsProvider.isNotEmpty` | [reports_screen.md](screens/reports_screen.md) |
| `/home/reports/:reportCode` | `reportRoute(report)` | `ReportViewScreen` | — (من الفهرس) | [report_view_screen.md](screens/report_view_screen.md) |

**المجموع: 30 مساراً · 34 ملفَّ توثيقِ شاشة** (والفرقُ: `SupplyIntakeScreen` تحمل تبويبَين موثَّقَين في ملفٍ واحد، و«الملف الشخصي» و«الإعدادات» و«حول» ليست مداخلَ من «لوحة اليوم»).

---

## 4. الرسمُ الشجري

```
/  (البداية — انتظارُ حالة الجلسة)
│
├── SessionSignedOut ──▶ /login  (الدخول)
│                          │ نجاحٌ ⟶ الموجّه يحوّل تلقائياً
├── SessionRejected ──▶ /blocked (الحساب المعطَّل) ──▶ signOut ──▶ /login
│
└── SessionActive
    ├── [يشترط الإعداد] ──▶ /setup (الإعداد التأسيسي) ──▶ /home تلقائياً
    │
    └── /home  ★ «لوحة اليوم» — مركزُ الانطلاق الوحيد
        │
        ├── صفّان أعلى الشاشة («يحتاج تصرُّفاً»)
        │   ├── /home/pending          الإدخالاتُ المعلّقة
        │   └── /home/aged-remainder   متبقي الأيام السابقة
        │
        ├── قسم «العمليات اليومية» (12 مدخلاً)
        │   ├── /home/distribution     ★ التوزيع (الزرُّ الأساسي الوحيد)
        │   ├── /home/cash-sales       البيع النقدي
        │   ├── /home/receipts         المقبوضات
        │   ├── /home/discounts        الخصومات
        │   ├── /home/dealer-statement كشف حساب المقوت  [تبويبان]
        │   ├── /home/owner-ledger     ضمار المالك
        │   │   └── /home/owner-ledger/history   سجلُّ الأيام السابقة
        │   ├── /home/outflows         السحبيات والخرجيات
        │   ├── /home/supply           التوريد مخزني  [تبويبان + extra]
        │   ├── /home/stock            مخزون اليوم
        │   ├── /home/pricing          التسعير اليومي
        │   ├── /home/disposal         الإتلاف
        │   └── /home/stocktake        الجرد
        │
        ├── قسم «البيانات المرجعية» (4)
        │   ├── /home/sources · /home/suppliers · /home/dealers · /home/items
        │
        ├── قسم «الهوية والصلاحيات» (2)
        │   ├── /home/users
        │   │   └── /home/users/:userId/permissions   تخصيصُ الصلاحيات
        │   └── /home/roles
        │
        ├── قسم «المالية» (1)
        │   └── /home/sack-finance     ماليةُ الجواني
        │
        ├── قسم «الرقابة» (2)
        │   ├── /home/audit            سجلُّ التدقيق
        │   └── /home/reports          فهرسُ التقارير
        │       └── /home/reports/:reportCode   عارضُ التقرير (25 تقريراً)
        │
        └── ورقةُ الجلسة (من الصورة الرمزية — متاحةٌ في كل شاشة)
            ├── /home/profile          الملفُّ الشخصي
            ├── /home/settings         الإعدادات
            │   └── /home/about        حول التطبيق
            └── تسجيلُ الخروج ⟶ /login
```

---

## 5. الانتقالاتُ الجانبية — بحالةٍ مهيَّأةٍ لا ملاحةً مجرَّدة

★★ **ثلاثُ آلياتِ تسليمٍ تُهيّئ الشاشةَ الهدفَ قبل الإبحار** — وهي أدقُّ ما في ملاحة التطبيق:

### أ. `agedClearanceFocusProvider` — من «متبقي الأيام السابقة»
| الزرّ | الوجهة | ما يُهيَّأ |
|---|---|---|
| «توزيع» | `/home/distribution` | يُرشِّح المصدر · **ويفتح ورقةَ النموذج فوراً** بتاريخِ مخزونٍ مثبَّتٍ ونوعٍ مزروع · ومنتقي المصدر **مقفل** · ولافتةُ `AgedClearanceBanner` ظاهرة |
| «بيع نقدي» | `/home/cash-sales` | **نفسُ السلوك تماماً** |
| «إتلاف» | `/home/disposal` | يُثبِّت المصدرَ **ويقفل منتقيه** · ويُثبِّت التاريخ · **ويزرع سطراً أوّلَ بالنوع** · واللافتةُ ظاهرة |

★ **ويُستهلَك مرةً واحدةً فقط** (`take()`) في `addPostFrameCallback` ⟵ فلا يُعاد تطبيقُه عند إعادة بناءٍ لاحقة.

### ب. `pendingFocusProvider` — من «الإدخالات المعلّقة»
| نوعُ البند | الوجهة | ما يُهيَّأ | `extra` |
|---|---|---|---|
| `dailyPrice` | `/home/pricing` | يختار المصدر · **ويضبط المرشِّح على «لم يتم»** | — |
| `distribution` | `/home/distribution` | يختار المصدر · **ويكتب اسمَ المقوت في حقل البحث** ⚠️ **ولا يفتح الورقة** | — |
| `sack` | `/home/supply` | يختار المصدر | ⭐ **`supplyIntakeSackTab`** ⟵ **يفتح على تبويب «الوارد جواني»** |
| `outflow` | `/home/outflows` | يختار المصدر | — |

### ج. `reportRequestProvider` — من «فهرس التقارير»
`ReportsScreen._open` **يكتب الطلبَ ثم يُبحِر** ⟵ فيجد `ReportViewScreen` طلبَه مهيَّأً. **و`initState` فيها تُصلِح الطلبَ** إن كان لتقريرٍ آخر ⟵ **فالدخولُ المباشر بالمسار (deep link) صحيح.**

---

## 6. المخارجُ إلى خارج التطبيق

| المخرَج | من أين | الآلية |
|---|---|---|
| **واتساب** | ورقةُ الإرسال في: [التوزيع](screens/distribution_screen.md) · [المقبوضات](screens/receipt_screen.md) | `MessageChannel.whatsapp` — **وإن لم يكن مثبَّتاً ظهرت رسالةٌ تقترح الرسالةَ النصّية** |
| **تطبيقُ الرسائل** | نفسُ الورقة | `MessageChannel.sms` — **ومفتاحُ «نسخةٍ مختصرة» يظهر إن تجاوز النصُّ 70 محرفاً** |
| **ورقةُ مشاركة النظام (PDF)** | ورقةُ الإرسال · [كشف حساب المقوت](screens/dealer_statement_screen.md) · [عارض التقرير](screens/report_view_screen.md) | `runDocumentExport` ⟶ يُنتِج PDF ⟶ `share_plus` — **ويُسجَّل التصديرُ في سجلٍّ** |
| **منتقي جهات الاتصال** | ورقتا [الرعية](screens/suppliers_screen.md) و[المقاوته](screens/dealers_screen.md) | `MethodChannel('dev.orimind.qtms/contacts')` — ⚠️ **وفشلُه صامتٌ تماماً** |
| **مصادقةُ البصمة** | [الدخول](screens/login_screen.md) · [الملف الشخصي](screens/profile_screen.md) | `local_auth` — حوارُ النظام |
| **حوارُ التاريخ** | الجرد · المقبوضات · الخصومات · السحبيات · كشفُ الحساب · عارضُ التقرير | `showDatePicker` — ⛔ **ولا تاريخَ مستقبلياً في أيٍّ منها** |

---

## 7. الأوراقُ السفليةُ والحوارات — 24 موضعاً

⛔ **لا شاشةَ نموذجٍ كاملةٍ في التطبيق** — كلُّ إدخالٍ منفصلٍ يجري في **ورقةٍ سفلية** (`showModalBottomSheet` بانحناءٍ علويٍّ 28 ومقبضِ سحبٍ وحاجزٍ `overlay`).

| الشاشةُ المُستدعية | الورقة | الـTrigger |
|---|---|---|
| كلُّ شاشةٍ (الشريط العلوي) | **ورقةُ الجلسة** | الصورةُ الرمزية |
| [الملف الشخصي](screens/profile_screen.md) | `_PasswordPrompt` | تشغيلُ مفتاح البصمة |
| [المستخدمون](screens/users_screen.md) | `UserFormSheet` · `showUserDisableSheet` | الزرُّ العائم/التعديل · زرُّ الحجب |
| [الأدوار](screens/roles_screen.md) | `RoleFormSheet` · `showRoleDeleteConfirmation` | الزرُّ العائم/التعديل · زرُّ الحذف |
| [المصادر](screens/sources_screen.md) | `SourceFormSheet` | الزرُّ العائم/التعديل |
| [الرعية](screens/suppliers_screen.md) | `SupplierFormSheet` | الزرُّ العائم/التعديل |
| [المقاوته](screens/dealers_screen.md) | `DealerFormSheet` | الزرُّ العائم/التعديل |
| [الأنواع](screens/items_screen.md) | `ItemFormSheet` | الزرُّ العائم/«تعديل» |
| [التوريد مخزني](screens/supply_intake_screen.md) | `CountedIntakeFormSheet` · `CancelIntakeSheet` · `SackHeaderFormSheet` · `SackLinesFormSheet` · `CancelSackSheet` | الزرُّ العائم المتبادل · أزرارُ البطاقة |
| [مخزون اليوم](screens/today_stock_screen.md) | `ItemMovementsSheet` | **النقرُ على بطاقة النوع** |
| [مالية الجواني](screens/sack_finance_screen.md) | `SackBreakdownSheet` · `SackTaxSheet` | **النقرُ على البطاقة** · زرُّ الضريبة |
| [التوزيع](screens/distribution_screen.md) | `DistributionFormSheet` · `DistributionDetailsSheet` · `CancelDistributionSheet` · **`_SendSheet`** | الزرُّ العائم · أزرارُ البطاقة |
| [البيع النقدي](screens/cash_sale_screen.md) | `CashSaleFormSheet` · `CashSaleDetailsSheet` · `CancelCashSaleSheet` | الزرُّ العائم · أزرارُ البطاقة |
| [المقبوضات](screens/receipt_screen.md) | **`_SendSheet`** | زرُّ الإرسال **بعد الحفظ** |
| عشرُ شاشات | **`showAuditTrailSheet`** | `AuditTrailButton` في `leading` |

★ **و`_SendSheet` مشتركةٌ بين التوزيع والمقبوضات** — بتكوينٍ مختلف: التوزيعُ يعرض `RadioGroup` للقوالب ومفتاحَ النسخة المختصرة، **والمقبوضاتُ لا تعرض أيّاً منهما.**

---

## 8. مصفوفةُ «من أين ⟵ إلى أين»

| الشاشة | تُدخَل من | تؤدّي إلى |
|---|---|---|
| البداية | تشغيلُ التطبيق (`initialLocation`) | `/login` · `/blocked` · `/home` · `/setup` — **كلُّها بالتوجيه المركزي** |
| الدخول | التوجيهُ المركزي | ⛔ لا ملاحةَ يدوية — النجاحُ يُحوِّل تلقائياً |
| الحساب المعطَّل | التوجيهُ المركزي | `/login` بعد `signOut` |
| الإعدادُ التأسيسي | **قسراً** من التوجيه المركزي | `/home` بالحفظ · أو الخروجُ من ورقة الجلسة |
| **لوحة اليوم** | التوجيهُ المركزي | **21 شاشة** + ورقةُ الجلسة |
| المستخدمون | لوحةُ اليوم | `/home/users/:id/permissions` |
| تخصيصُ الصلاحيات | المستخدمون (زرُّ المفتاح) | ⛔ لا مخرَج |
| الأدوار · المصادر · الرعية · المقاوته · الأنواع | لوحةُ اليوم | ⛔ لا مخرَج (أوراقٌ سفلية) |
| التوريد مخزني | لوحةُ اليوم · **الإدخالاتُ المعلّقة (بتبويب)** | ⛔ لا مخرَج |
| مخزون اليوم · التسعير · الجرد | لوحةُ اليوم (+ المعلّقة للتسعير) | ⛔ لا مخرَج |
| الإتلاف | لوحةُ اليوم · **متبقي الأيام السابقة** | ⛔ لا مخرَج |
| متبقي الأيام السابقة | لوحةُ اليوم (الصفُّ الثاني) | **التوزيع · البيعُ النقدي · الإتلاف** — بحالةِ تركيزٍ مثبَّتة |
| الإدخالاتُ المعلّقة | لوحةُ اليوم (الصفُّ الأول) | **التسعير · التوزيع · التوريد · السحبيات** — بحالةٍ مهيَّأة |
| التوزيع | لوحةُ اليوم · المتبقي · المعلّقة | ⛔ لا مسارَ داخلي · **⟶ واتساب · الرسائل · مشاركةُ PDF** |
| البيعُ النقدي | لوحةُ اليوم · المتبقي | ⛔ لا مخرَج |
| المقبوضات | لوحةُ اليوم | **⟶ واتساب · الرسائل · مشاركةُ PDF** |
| الخصومات | لوحةُ اليوم | ⛔ لا مخرَج |
| كشفُ حساب المقوت | لوحةُ اليوم | **⟶ مشاركةُ PDF** |
| ماليةُ الجواني | لوحةُ اليوم | ⛔ لا مخرَج (ورقتان) |
| السحبياتُ والخرجيات | لوحةُ اليوم · المعلّقة | ⛔ لا مخرَج |
| ضمارُ المالك | لوحةُ اليوم | **`/home/owner-ledger/history`** |
| سجلُّ الأيام السابقة | ضمارُ المالك | ⛔ لا مخرَج |
| سجلُّ التدقيق | لوحةُ اليوم | ⛔ لا مخرَج |
| فهرسُ التقارير | لوحةُ اليوم | **`/home/reports/:code`** لكلِّ بطاقة |
| عارضُ التقرير | فهرسُ التقارير (أو مسارٌ مباشر) | **⟶ مشاركةُ PDF** |
| الملفُّ الشخصي | **ورقةُ الجلسة** (من أي شاشة) | ⛔ لا مخرَج |
| الإعدادات | **ورقةُ الجلسة** (من أي شاشة) | **`/home/about`** |
| حولُ التطبيق | الإعدادات | ⛔ لا مخرَج |

---

## 9. ملاحظاتُ ملاحةٍ لمراجعة UX

| # | الملاحظة |
|:-:|---|
| 1 | **ثلاثُ شاشاتٍ بلا مفتاحِ صلاحيةٍ على مدخلها:** «مخزون اليوم» · «التسعير اليومي» · «متبقي الأيام السابقة» · و«الإدخالاتُ المعلّقة» ⟵ ظاهرةٌ لكل من يدخل التطبيق. **و«التسعير» تحرس زرَّ الحفظ وحده** — فالحقولُ قابلةٌ للكتابة لمن لا يملك المفتاح. |
| 2 | **لا مسارَ يعود إلى «لوحة اليوم» صراحةً** من أي شاشة — الرجوعُ بزرِّ النظام حصراً. **وورقةُ الجلسة تُبحِر بـ`context.go` لا `push`** ⟵ فالدخولُ إلى «الملف الشخصي» من شاشةِ عملٍ يستبدل الموقعَ ولا يُكدِّسه. |
| 3 | **تفاوتٌ في قوّة التسليم:** «متبقي الأيام السابقة» **يفتح ورقةَ النموذج** في التوزيع والبيع النقدي، بينما «الإدخالاتُ المعلّقة» **تُرشِّح وتبحث فقط** في التوزيع، **وتكتفي باختيار المصدر** في الجونية والسحبية. |
| 4 | **مسارٌ متفرّعٌ واحدٌ بلا مدخلٍ من «لوحة اليوم»:** `/home/owner-ledger/history` — **ومدخلُه شرطيٌّ** (يُستبدَل بلافتةٍ عند «كل المصادر»). |
| 5 | **«حول التطبيق» عمقٌ ثالثٌ خلف ورقةِ جلسةٍ ثم شاشةِ إعدادات** — وهو أعمقُ موضعٍ لبصمة جهة التطوير، وذلك مقصود. |

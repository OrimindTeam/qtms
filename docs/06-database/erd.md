# مخطط العلاقات بين الكيانات (ERD) — QTMS

| البند | القيمة |
|---|---|
| **الإلزامية** | **M** — **يُقرأ إلزامياً قبل أي تعديل بنيوي** |
| **الطبيعة** | **LIVING** — يُحدَّث بعد كل تغيير بنيوي |
| **المالك** | ARCH / DEV |

> ★ **دليل الأنواع في المخططات أدناه:**
> **`money`** = ★ **عدد صحيح بالريال (`int` 64 بتّة)** ⛔ **بلا كسور ولا
> تخزين بأصغر وحدة** (`ADR-0015`) · **`decimal`** = **وزن** بثلاث خانات
> للكيلوجرام وخانتين للجرام — ★ **وهو ليس مبلغاً فلا يسري عليه القيد** ·
> **`int`** = عدد صحيح غير مالي (كميات معدودة · عدّادات).
>
> ⚠️ **استثناء يجب الانتباه له:** ★ **`taxPerKilo` مبلغ لا وزن** — فنوعه
> **`money`** رغم اقترانه بالكيلوجرام (`ADR-0015` · `glossary.md`).

> ⚠️ **تنبيه على طبيعة القاعدة:** هذه **قاعدة مستندية لا علائقية** —
> **فالعلاقات أدناه منطقية لا مفروضة بقيود مفتاح أجنبي**. السلامة المرجعية
> **مسؤولية التصميم والعمليات السحابية** لا القاعدة.

---

## 1. الكيانات المرجعية والعلاقات المشتقّة

```mermaid
erDiagram
    SOURCE ||--o{ SUPPLIER_LINK : "يرتبط به"
    SOURCE ||--o{ ITEM_LINK : "يرتبط به"
    SOURCE ||--|| SCRAP_ITEM : "⚙️ نسخة سكرب تلقائية"
    SOURCE ||--o{ DEALER_BALANCE : "⚙️ حساب لكل مقوت"
    SOURCE ||--o{ SUPPLIER_BALANCE : "⚙️ حساب لكل رعوي"

    DEALER ||--o{ DEALER_BALANCE : "له حساب في كل مصدر"
    SUPPLIER ||--o{ SUPPLIER_BALANCE : "له حساب في كل مصدر"
    SUPPLIER ||--o{ SUPPLIER_LINK : ""
    ITEM ||--o{ ITEM_LINK : ""

    SOURCE {
        string sourceId PK
        string name
        string normalizedName UK
        bool requiresSupplierOnIntake
        bool isActive
    }
    SUPPLIER {
        string supplierId PK
        string name
        string normalizedPhone UK
        array sourceIds
        bool isActive
    }
    DEALER {
        string dealerId PK
        string name
        string normalizedPhone UK
        bool isActive
    }
    ITEM {
        string itemId PK
        string normalizedName UK
        enum nature
        enum unit
        bool isSystemDefault
        array sourceIds
    }
    DEALER_BALANCE {
        string key PK "dealerId_sourceId"
        money totalDebit
        money totalCredit
        money balance
    }
    SUPPLIER_BALANCE {
        string key PK "supplierId_sourceId"
        money totalRevenue
        money totalTax
        money net
    }
```

> **`DEALER` و`SUPPLIER` لا يحملان حقل مصدر إطلاقاً** — حساباتهما **سجلات
> مستقلة** مفتاحها مركّب. **وإضافة حقل مصدر للمقوت خطأ بنيوي يهدم `ADR-0005`.**

## 2. التوريد والمخزون

```mermaid
erDiagram
    SOURCE ||--o{ INCOMING_COUNT : "يورَّد إليه"
    SOURCE ||--o{ SACK : "يورَّد إليه"
    SUPPLIER ||--o{ SACK : "يورّد"
    SACK ||--o{ SACK_LINE : "يحوي (داخل المستند)"
    SACK ||--|| SCRAP_LINE : "⚙️ سطر سكرب تلقائي"

    INCOMING_COUNT ||--o{ INVENTORY_LEDGER : "يُولِّد دخولاً"
    SACK ||--o{ INVENTORY_LEDGER : "يُولِّد دخولاً"
    INVENTORY_LEDGER }o--|| ITEM_DAILY_BALANCE : "يُعيد بناءه"

    SACK {
        string sackId PK
        date stockDate "🔒 تلقائي"
        timestamp entryDate
        string sourceId FK
        string supplierId FK "مشروط"
        int dailySequence "⚙️ من السحابة · مستقل لكل مصدر"
        string displayName
        decimal totalWeight
        decimal iceWeight
        decimal scrapWeight
        money taxPerKilo "🔵 قد يكون فارغاً — ★ مبلغ لا وزن"
        decimal claimableWeight "🧮"
        decimal lostWeight
        bool lostWeightConfirmed
        money sackRevenue "🧮 من السحابة"
        money supplierNet "🧮"
        bool isPricingComplete
        enum status
    }
    SACK_LINE {
        string itemId FK
        string compositeName "★ اسم النوع - الرعوي - جونية رقم N"
        enum nature
        enum unit
        number quantity
        decimal pieceWeightGrams
        enum pieceWeightOrigin "تهيئة/يدوي/مستنتج"
        decimal lineTotalWeight
        money distributionPrice "🔵"
        money minCashPrice "🔵"
    }
    INVENTORY_LEDGER {
        string sourceId FK
        date stockDate "★ يوم الاحتساب"
        timestamp entryDate
        string itemKey "النوع أو الاسم المركّب"
        string sackId FK "إن كان من جونية"
        enum unit
        enum direction
        number quantity
        number balanceAfter
        enum movementTag "عادية/تسوية/إتلاف"
        bool isCancelled
        string amendReason
    }
    ITEM_DAILY_BALANCE {
        string key PK "sourceId_itemKey_stockDate"
        number incoming
        number outgoing
        number balance
        enum unit
    }
```

## 3. الصرف والذمم

```mermaid
erDiagram
    ITEM_DAILY_BALANCE ||--o{ DISTRIBUTION : "يُخصم منه"
    ITEM_DAILY_BALANCE ||--o{ CASH_SALE : "يُخصم منه"
    ITEM_DAILY_BALANCE ||--o{ OUTFLOW : "يُخصم منه"

    DEALER ||--o{ DISTRIBUTION : "يستلم"
    DISTRIBUTION ||--o{ DEALER_LEDGER : "مدين"
    RECEIPT ||--o{ DEALER_LEDGER : "دائن"
    DISCOUNT ||--o{ DEALER_LEDGER : "دائن"
    DEALER_LEDGER }o--|| DEALER_BALANCE : "يُعيد بناءه"

    RECEIPT ||--o{ DEALER_SURPLUS : "قد يُنشئ فائضاً"
    DEALER_SURPLUS ||--o{ DISTRIBUTION : "⚙️ يُطبَّق تلقائياً"

    DISTRIBUTION ||--|| DISTRIBUTION_PRICING : "🔒 ADR-0011"

    DISTRIBUTION_PRICING {
        string path PK "distributions/{key}/pricing/current"
        string sourceId "نسخة لفحص النطاق"
        array unitPrices "موازية لـ lines"
        array lineTotals
        money debtValue "🧮 المسعَّر فقط"
    }
    DISTRIBUTION {
        string key PK "★ dealerId_sourceId_stockDate"
        string documentNumber
        date stockDate "🔒"
        timestamp entryDate
        string sourceId FK
        string dealerId FK
        int unpricedLineCount "عدد لا مبلغ"
        number totalPieces
        decimal totalWeight
        money settledAmount "🧮 سحابة"
        money discountedAmount "🧮 سحابة"
        money remaining "🧮 سحابة"
        enum settlementStatus
        enum status
        int amendCount
    }
    RECEIPT {
        string receiptId PK
        date date "لا يقبل المستقبلي"
        string dealerId FK
        string sourceFilter "مصدر أو الكل"
        array affectedSourceIds "★ المصادر التي مسّها فعلاً"
        money surplusAmount
        string surplusScope "مصدر أو عام"
    }

    RECEIPT ||--|| RECEIPT_DEPOSIT : "🔒 ADR-0017"

    RECEIPT_DEPOSIT {
        string path PK "receipts/{receiptId}/deposit/current"
        bool isDeposited "🟡 تبدأ: لم يُودع"
        string depositNote "إلزامية عند التأكيد"
        string depositedBy FK
        timestamp depositedAt
    }
    DEALER_LEDGER {
        string dealerId FK
        string sourceId FK "★ إلزامي"
        string debtLotId FK
        enum direction
        money amount
        enum entryType "ضمار/قبض/خصم/تطبيق فائض"
        money balanceAfter
        bool isCancelled
    }
```

## 4. الجونية والرعوي والسحبيات

```mermaid
erDiagram
    SACK ||--o{ SUPPLIER_LEDGER : "يُولِّد صافياً"
    DISTRIBUTION }o--o{ SACK : "إيراد فعلي"
    CASH_SALE }o--o{ SACK : "إيراد فعلي"
    OUTFLOW }o--o{ SACK : "★ إيراد فعلي (الرعوي يستحق)"
    SUPPLIER_LEDGER }o--|| SUPPLIER_BALANCE : "يُعيد بناءه"

    SOURCE ||--o{ OUTFLOW : "★ إلزامي دائماً"
    OUTFLOW ||--o{ OUTFLOW_LEDGER : "يُقيَّد على المصدر"

    OUTFLOW {
        string outflowId PK
        enum ledgerType "★ سحبية / خرجية"
        date date
        string sourceId FK "★ إلزامي حتى لسحبيات المالك"
        string category
        money totalQatValue "🧮"
        money totalCashValue "🧮"
        money grandTotal "🧮"
        int unpricedItemCount
    }
    OUTFLOW_LEDGER {
        string sourceId FK "★ إلزامي"
        enum ledgerType
        date documentDate "★ الأثر المالي"
        date stockDate "★ الأثر المخزني (قد يختلف)"
        money amount
        bool isCancelled
    }
    SUPPLIER_LEDGER {
        string supplierId FK
        string sourceId FK "★ إلزامي"
        string sackId FK
        money sackRevenue
        money sackTax "★ مقرَّبة لأقرب ريال"
        money supplierNet
        int recalcVersion "★ يمنع تطبيق حساب قديم"
    }
```

> ⚠️ **`OUTFLOW` لا يرتبط بـ`DEALER` إطلاقاً** — لا مدين ولا دائن ولا ضمار
> (`GR-44`). **وأي علاقة بينهما خطأ بنيوي.**

## 5. الملخصات والرقابة

```mermaid
erDiagram
    DAILY_SUMMARY {
        string key PK "sourceId_date  ·  all_date"
        money credit "الآجل"
        money cash "النقدي"
        money totalDebt
        money settledOfDay "الواصل"
        money discounts "بند مستقل"
        money tax
        money withdrawals
        money expenses
        money netFinal
        timestamp retroUpdatedAt "⟳ مُحدَّث بأثر رجعي"
    }
    AUDIT_LOG {
        string id PK
        timestamp occurredAt "توقيت الخادم"
        string userId
        string userName "مُثبَّت وقت الحدث"
        enum action
        string entityType
        string entityId
        string sourceId
        date stockDate "لتمييز التصريف المتأخر"
        map valuesBefore
        map valuesAfter
        string reason "إلزامي للتعديل والإلغاء والإتلاف"
    }
    DOCUMENT_AMENDMENT {
        string entityType
        string entityId
        int amendSequence "★ شارة مُعدَّل ×N"
        string fieldName
        string valueBefore
        string valueAfter
        string reason "★ نصي إلزامي"
    }
    PENDING_ENTRY {
        string documentType
        string documentId
        string readableTitle
        string sourceId
        string missingField
        string navigationTarget
    }
    AGED_REMAINDER {
        string key PK "sourceId_itemKey_stockDate"
        number remainingQty
        enum unit
        int ageInDays
    }
```

## 6. قواعد العلاقات الملزمة

| # | القاعدة | المرجع |
|---|---|---|
| 1 | **كل مستند تشغيلي يحمل `sourceId` صراحةً** | `GR-20` |
| 2 | **كل حركة مخزون تحمل `stockDate` و`entryDate` معاً** | `GR-13` |
| 3 | **حساب المقوت والرعوي مفتاحه مركّب بالمصدر** | `GR-21` |
| 4 | **`{dealerId}_{sourceId}_{stockDate}` يفرض توزيعة واحدة** | `GR-18` |
| 5 | **أنواع الجونية تدخل المخزون بالاسم المركّب** — والوارد عدداً بالاسم المجرَّد | `GR-24` · `BR-M6-10` |
| 6 | **السحبيات والخرجيات لا تمسّ `dealer_ledger` إطلاقاً** | `GR-44` |
| 7 | **الأسماء مكرَّرة عمداً داخل السطور** — ولا تتغيّر تاريخياً | `§6.1` |
| 8 | **الأرصدة والملخصات مشتقّات** قابلة لإعادة البناء من الدفاتر | `ADR-0008` |
| 9 | **`recalcVersion` يمنع تطبيق حساب قديم فوق أحدث** | `sack-valuation-design` |
| 10 | **غياب سجل الرصيد يعني صفراً** — لا يُنشَأ سجل بصفر بلا داعٍ | `§6.3` |

## 7. الحفاظ على التزامن مع الكود

> **هذا المخطط `LIVING` ويُحدَّث بعد كل تغيير بنيوي** — ولا يُدمَج أي تغيير
> يمسّ البنية دون تحديثه **ضمن نفس الدمج** (Docs as Code · UPDS-03 §6).

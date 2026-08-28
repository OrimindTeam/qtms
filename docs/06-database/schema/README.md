# فهرس مخططات المجموعات

> **الطبيعة:** هذه الملفات **اختيارية (O)** في UPDS-02 — والمرجع الشامل
> لكل حقل هو [`../data-dictionary.md`](../data-dictionary.md)، والعلاقات في
> [`../erd.md`](../erd.md). **وما هنا تفصيل لكل مجموعة على حدة** بقواعدها
> وفهارسها وحدود الكتابة عليها.

## سجلات التهيئة
[`sources`](sources.md) · [`suppliers`](suppliers.md) · [`dealers`](dealers.md) · [`items`](items.md) · [`app-settings`](app-settings.md)

## المستندات التشغيلية
[`incoming-count`](incoming-count.md) · [`sacks`](sacks.md) · [`daily-prices`](daily-prices.md) · [`distributions`](distributions.md) · [`cash-sales`](cash-sales.md) · [`receipts`](receipts.md) · [`discounts`](discounts.md) · [`stocktakes`](stocktakes.md)

## ★ الدفاتر الأربعة
[`inventory-ledger`](inventory-ledger.md) · [`dealer-ledger`](dealer-ledger.md) · [`supplier-ledger`](supplier-ledger.md) · [`outflow-ledger`](outflow-ledger.md)

## الملخصات والرقابة
[`daily-summaries`](daily-summaries.md) · [`audit-log`](audit-log.md)

## مجموعات بلا ملف مفرد
| المجموعة | أين توثيقها |
|---|---|
| `users` · `roles` | [`../data-dictionary.md`](../data-dictionary.md) §1 · [`identity-access-design`](../../04-design/module-design/identity-access-design.md) |
| سجلات حراسة التفرد | [`../data-dictionary.md`](../data-dictionary.md) §1 · [`master-data-design`](../../04-design/module-design/master-data-design.md) |
| العدّادات | [`../data-dictionary.md`](../data-dictionary.md) §1 — ⛅ **السحابة فقط · والقراءة مرفوضة للجميع** |
| `item_daily_balances` · `dealer_balances` · `dealer_surplus` · `supplier_balances` | [`../data-dictionary.md`](../data-dictionary.md) §4 — **مشتقّات** |
| `pending_entries` · `aged_remainders` | [`pending-entries-design`](../../04-design/module-design/pending-entries-design.md) · [`inventory-design`](../../04-design/module-design/inventory-design.md) |
| `document_amendments` | [`audit-log-design`](../../04-design/module-design/audit-log-design.md) |
| `outflows` (المستند) | [`outflow-ledger`](outflow-ledger.md) · [`outflow-design`](../../04-design/module-design/outflow-design.md) |
| `disposals` (الإتلاف) | [`inventory-design`](../../04-design/module-design/inventory-design.md) §5 |

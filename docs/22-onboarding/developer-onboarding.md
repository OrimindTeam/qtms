# تأهيل المطوّر الجديد — QTMS

| البند | القيمة |
|---|---|
| **الإلزامية** | **M** |
| **الطبيعة** | LIVING |
| **المالك** | DEV |

> **للتشغيل السريع:** [`../07-development/getting-started.md`](../07-development/getting-started.md).
> **هذا المستند: الخريطة الكاملة — ماذا تقرأ ومتى ولماذا.**

---

## 1. ★ اقرأ هذا أولاً

> ★ **هذا ليس تطبيق إدارة عادياً.** ★ **هو نظام محاسبي يدير ذمماً ومخزوناً
> ونقداً حقيقياً** — ★ **وخطأ فيه لا يُنتج «سلوكاً غريباً» بل رقماً خاطئاً
> يثق به المالك ويبني عليه قراراً مالياً.**

**خمس حقائق تحكم كل سطر تكتبه:**

| # | الحقيقة |
|---|---|
| 1 | ★ **الحماية في السحابة لا في الواجهة** — ★ **وأي قاعدة عمل بلا مقابل في قواعد الحماية غير مُنفَّذة أمنياً** |
| 2 | ★ **لا حذف نهائياً — لأي مستخدم بمن فيهم المالك** · ★ **وسجل التدقيق للإضافة فقط** |
| 3 | ★ **الرصيد = مجموع حركات دفتره — دائماً** · ★ **والملخص لا يُقرأ كمصدر حقيقة** |
| 4 | ★ **كل مبلغ عدد صحيح بالريال — `int`** ⛔ **بلا كسور ولا «أصغر وحدة»** (`ADR-0015`) · ★ **ولا تُجمع الحبات مع الأوزان** |
| 5 | ★ **`stockDate` يوم المحاسبة و`entryDate` للتدقيق** — ⛔ **ولا يُخلَطان** |

## 2. ★ خريطة القراءة

### اليوم الأول — الفهم

| # | المستند | لماذا |
|:-:|---|---|
| 1 | [`../01-product/product-brief.md`](../01-product/product-brief.md) | ما هذا النظام ولماذا |
| 2 | ★ [`../00-governance/glossary.md`](../00-governance/glossary.md) | ★ **ملزم — ولا مرادف لأي مصطلح مجال** |
| 3 | [`../01-product/personas/`](../01-product/personas/) | لمن نبني |
| 4 | ★ **سيناريو §15 من المستند المصدر** | ★ **أسرع طريق لفهم ترابط النظام كله** |

### اليوم الثاني — البنية

| # | المستند |
|:-:|---|
| 5 | [`../03-architecture/architecture-overview.md`](../03-architecture/architecture-overview.md) |
| 6 | ★ [`../03-architecture/adr/`](../03-architecture/adr/) — ★ **لماذا بُني هكذا · يمنع إعادة فتح قرارات محسومة** |
| 7 | [`../06-database/erd.md`](../06-database/erd.md) · [`../06-database/data-dictionary.md`](../06-database/data-dictionary.md) |
| 8 | ★ [`../04-design/design-overview.md`](../04-design/design-overview.md) §2 — ★ **كل المعادلات** |

### اليوم الثالث — قبل أول سطر كود

| # | المستند |
|:-:|---|
| 9 | ★ [`../04-design/coding-standards.md`](../04-design/coding-standards.md) — ⚠️ **§3 يُقرأ مقروناً بـ`ADR-0012`** (البند 9-ب أدناه) |
| 9-ب | ★ [`../03-architecture/adr/ADR-0012-shared-domain-package.md`](../03-architecture/adr/ADR-0012-shared-domain-package.md) — ★ **موضع طبقة النطاق الفعلي** |
| 10 | ★ [`../04-design/naming-conventions.md`](../04-design/naming-conventions.md) — **المعجم الملزم** |
| 11 | ★ [`../09-security/security-requirements.md`](../09-security/security-requirements.md) — ★ **جدول التتبع: بند قبول لا توثيق** |
| 12 | [`../08-testing-and-qa/test-strategy.md`](../08-testing-and-qa/test-strategy.md) |
| 13 | [`../07-development/definition-of-done.md`](../07-development/definition-of-done.md) |

> ★ **ثلاث حزم Dart لا واحدة** — وهذا أول ما يربك القادم الجديد:
>
> | المسار | تُبنى بـ | ما فيها |
> |---|---|---|
> | الجذر `lib/` | **Flutter** | التطبيق: `application` · `infrastructure` · `presentation` |
> | `packages/qtms_domain/` | ★ **`dart` وحده** | ★ **طبقة النطاق** — الكيانات والمعادلات وواجهات المستودعات |
> | `functions/` | ★ **`dart` وحده** | العمليات السحابية — **تستورد حزمة النطاق نفسها** |
>
> ⛔ **ولا تُضِف `flutter` إلى الحزمتين الأخيرتين مهما بدا مغرياً** — ذلك
> ينقض `ADR-0012` **ويكسر بناء الحاوية**. ⚠️ **وانتبه:** `dart pub get` على
> جهازك **لن ينبّهك** لأن Flutter مثبَّت عندك؛ من يمسك ذلك هو
> `functions/test/no_flutter_dependency_test.dart` وبناء الحاوية.

### قبل برمجة أي وحدة

| # | المستند |
|:-:|---|
| 14 | ★ `04-design/module-design/<وحدتك>` |
| 15 | ★ `02-requirements/functional-requirements/FR-M<رقمك>` |
| 16 | [`../06-database/indexing-strategy.md`](../06-database/indexing-strategy.md) |

### قبل أول شاشة

| # | المستند |
|:-:|---|
| 17 | [`../18-ux-ui/design-tokens.md`](../18-ux-ui/design-tokens.md) |
| 18 | [`../18-ux-ui/design-system.md`](../18-ux-ui/design-system.md) |
| 19 | [`../18-ux-ui/ui-guidelines.md`](../18-ux-ui/ui-guidelines.md) |
| 20 | [`../16-accessibility/a11y-checklist.md`](../16-accessibility/a11y-checklist.md) |

## 3. ★ أخطاء يقع فيها كل قادم جديد

| # | الخطأ | لماذا هو خطأ |
|:-:|---|---|
| 1 | ★ **بناء الواجهة أولاً و«إضافة الحماية لاحقاً»** | ★ **يُنتج كوداً يفترض أنه مخوَّل ثم يفشل في الإنتاج** |
| 2 | ★ **حساب رصيد وتخزينه** | ★ **الرصيد مشتقّ لا مخزَّن** |
| 3 | ★ **تراكم على قيمة سابقة في إعادة الحساب** | ★ **يكسر idempotency** |
| 4 | ★ **استخدام نوع عشري عائم للمبالغ** | ★ **رفض تلقائي في المراجعة** |
| 5 | ★ **إضافة قيد عكسي لتصحيح خطأ** | ★ **لا قيود عكسية — التعديل مباشر بسبب نصّي** (`A-14`) |
| 6 | ★ **بناء تقرير مخزني على `entryDate`** | ★ **يُنتج يوماً خاطئاً بالكامل** |
| 7 | **إضافة استعلام بلا فهرس** | مسح كامل مكلف |
| 8 | ★ **تخمين قاعدة غامضة بدل فتح بند `OQ`** | ★ **الأخطر — التخمين يُنتج رقماً خاطئاً يبدو صحيحاً** |
| 9 | **كتابة لون أو مسافة يدوياً** | ترفضه بوابة التوكنز |
| 10 | ★ **افتراض أن الواجهة تحمي** | — |

## 4. ★ أول مهمة مقترحة

```text
⓪ افتح خطة التنفيذ واعرف أي زيادة (WU) جارية الآن
① اقرأ سيناريو §15 كاملاً وتتبّع رقماً واحداً عبر الدفاتر الأربعة
② شغّل المحاكي المحلي وشغّل اختبارات قواعد الحماية
③ اكتب اختبار وحدة لمعادلة واحدة — ★ بأرقام من المستند لا من الكود
④ افتح بند OQ لأي غموض واجهته  ⟵ ★ هذا مطلوب لا معيب
```

> ★ **خطة الزيادات وحالتها الحقيقية:**
> [`../00-governance/upds-workflow/implementation-plan.md`](../00-governance/upds-workflow/implementation-plan.md)
> — **26 زيادة**، وترتيبها ملزم بترتيب `product-roadmap.md`.

## 5. أين تسأل

| السؤال | المكان |
|---|---|
| «لماذا بُني هكذا؟» | [`../03-architecture/adr/`](../03-architecture/adr/) |
| «ماذا يعني هذا المصطلح؟» | [`../00-governance/glossary.md`](../00-governance/glossary.md) |
| «ما القاعدة هنا؟» | `FR-M*.md` + المستند المصدر |
| «كيف أختبر هذا؟» | [`../08-testing-and-qa/`](../08-testing-and-qa/) |
| «واجهت خطأً متكرراً» | [`../07-development/troubleshooting-guide.md`](../07-development/troubleshooting-guide.md) |
| «كيف تعمل الفرق؟» | [`team-handbook.md`](team-handbook.md) |
| ★ **«أي زيادة أعمل عليها الآن؟»** | [`../00-governance/upds-workflow/implementation-plan.md`](../00-governance/upds-workflow/implementation-plan.md) |
| ★ **«لا جواب له في `docs/`»** | ★ **بند في `open-questions.md` — ⛔ ولا تخمّن** |

## 6. المرتبطات

[`team-handbook.md`](team-handbook.md) ·
[`faq.md`](faq.md) ·
[`../07-development/getting-started.md`](../07-development/getting-started.md) ·
[`../README.md`](../README.md)

## ★★ تحديث 2026-08-24 — ما يجب أن تعرفه قبل لمس التفويض

| # | البند | لماذا يعنيك |
|:-:|---|---|
| ① | ⛔⛔ **لا تنشر `firestore.rules` قبل قراءة** [`RB-backfill-user-isactive.md`](../13-operations/runbooks/RB-backfill-user-isactive.md) | ★ **`perm()` صارت تشترط `isActive == true`** — **وبطاقةٌ بلا الحقل بطاقةٌ بلا صلاحية**، ⟵ **ونشرٌ قبل الترحيل يقفل المالك خارج نظامه** |
| ② | ★★ **كل دالة كاتبة تفرض `amendReason` غير فارغ على أي تعديل** | `ADR-0004` · `DEBT-21` ① · `CR-002` — ⛔ **وإسقاطه ثغرة صامتة لا نقصُ ميزة**، فالقاعدة لم تعد تحرسه بعد `WU-026` |
| ③ | ★ **قواعد إدارة المستخدمين في طبقة النطاق** [`user_administration.dart`](../../packages/qtms_domain/lib/capabilities/identity_access/domain/user_administration.dart) | **يشاركها التطبيق والسحابة** (`ADR-0012`) — ⛔ **ولا تُعاد كتابتها في أيٍّ منهما** |
| ④ | ★ **العمليات المستدعاة تُنادى بـ**[`callable_client.dart`](../../lib/core/callable/callable_client.dart) **وعنوانها من `QTMS_FUNCTIONS_BASE_URL`** — ✅ **وقيمتُه مُضمَّنةٌ في المستودع** (`config/qtms-public-defines.env` · `ADR-0022`) | ⚠️ **معرّف لا سرّ** · ★ **يُمرَّر بـ`--dart-define-from-file` قبل ملف `.secrets/`** · ⛔ **وبناءٌ بلا ضبطه لا يكتب شيئاً** (`DEBT-49`) |
| ⑤ | ⛔ **`deleteRole` غير موجودة** — راجع `IQ-018` | **تعارض ثلاثة مستندات معتمدة** ⟵ ⛔ **ولا تُخمَّن** |

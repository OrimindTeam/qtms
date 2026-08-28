# سياسة دورة حياة المستندات — QTMS

| البند | القيمة |
|---|---|
| **الطبيعة** | **STATIC** — تتغيّر نادراً وبقرار إداري |
| **المالك** | مدير المشروع (PM) |
| **الأساس المعياري** | UPDS-00 §2 · UPDS-01 · UPDS-03 · ISO/IEC/IEEE 15289 |

---

## 1. تصنيف كل مستند بأربعة أبعاد

كل مستند في `docs/` موصوف بأربعة أبعاد لا ثالث لها، وهي المذكورة في ترويسة
كل مستند:

| البعد | القيم الممكنة |
|---|---|
| **الإلزامية** | **M** إلزامي · **C** مشروط · **O** اختياري |
| **الطبيعة** | **STATIC** مرجع ثابت · **LIVING** حيّ يتغيّر باستمرار · **LOG** سجل تراكمي لا يُعدَّل بأثر رجعي |
| **آلية التحديث** | **AUTO** آلي · **MANUAL** يدوي · **HYBRID** يُنشئه Claude Code ويعتمده إنسان |
| **الأرشفة** | **VERSIONED** · **OVERWRITE** · **ARCHIVE-ON-DEPRECATE** |

---

## 2. متى يُنشأ كل مستند (خريطة المراحل)

مطابقة لـ UPDS-03، ومُسقَطة على خارطة الطريق في القسم 14 من المستند المصدر:

| المرحلة | ما يجب أن يكون مكتملاً قبل الانتقال منها |
|---|---|
| **قبل البدء** | `documentation-standard.md` · `glossary.md` · `ownership-raci-matrix.md` · `01-product/vision-and-mission.md` · `product-brief.md` · `21-project-management/project-charter.md` |
| **التحليل** | `srs.md` · `non-functional-requirements.md` · `constraints-and-assumptions.md` · `functional-requirements/FR-*.md` · `use-cases/` أو `user-stories/` · هيكل `requirements-traceability-matrix.md` |
| **التصميم المعماري** | `architecture-overview.md` · `architecture-principles.md` · `technology-stack.md` · `quality-attributes.md` · `c4-model/c1` و`c2` · `adr/` لكل قرار جوهري · `06-database/database-overview.md` و`erd.md` · `09-security/threat-model.md` |
| **التصميم التفصيلي** | `coding-standards.md` · `naming-conventions.md` · `error-handling-strategy.md` · `module-design/<وحدة>-design.md` **لكل وحدة قبل برمجتها** · `18-ux-ui/design-system.md` و`design-tokens.md` |
| **البرمجة** | تحديث `06-database/*` و`05-api/*` مع كل تغيير · `migrations-log.md` · تحديث عمود «الكود» في مصفوفة التتبع |
| **الاختبار** | `test-plan.md` · `test-cases/TC-*.md` · `bug-reports/` · `uat-signoff.md` (بوابة النشر) |
| **النشر** | `release-checklist.md` مكتملة · `rollback-procedures.md` جاهزة · `changelog.md` |
| **ما بعد النشر والصيانة** | `13-operations/*` · `15-monitoring-and-observability/*` · `14-maintenance/technical-debt-register.md` |

> **بوابة إضافية خاصة بـ QTMS:** لا تبدأ برمجة أي وحدة قبل اجتياز
> **الخطوة صفر** (القسم 14 من المصدر) — وأهم مخرجاتها التوثيقية:
> `09-security/security-requirements.md` (ترجمة جدول 9.6 كاملاً) و
> `06-database/indexing-strategy.md` (الفهارس المركّبة).

---

## 3. متى يُحدَّث كل مستند

| نوع الحدث | ما يُحدَّث فوراً |
|---|---|
| تغيّرت بنية بيانات (مجموعة/حقل) | `erd.md` · `data-dictionary.md` · `migrations-log.md` · `schema/<المجموعة>.md` |
| تغيّرت عملية سحابية أو صلاحية | `05-api/api-overview.md` · `09-security/security-requirements.md` · `authentication-and-authorization.md` |
| تغيّر قرار معماري | **ADR جديد** + `architecture-overview.md` + `c4-model/*` + `technology-stack.md` |
| تغيّر متطلب | `CR-*.md` أولاً → ثم `srs.md` و`FR-*.md` و`requirements-traceability-matrix.md` |
| تغيّرت واجهة | `design-system.md` · `design-tokens.md` · `wireframes/*` · `a11y-checklist.md` · `translation-glossary.md` |
| ظهر دَين تقني | `14-maintenance/technical-debt-register.md` |
| نُشر إصدار | `changelog.md` · `release-notes/vX.Y.Z.md` |

التفصيل الكامل لسلاسل التأثير في **UPDS-06**، ولا يُكرَّر هنا.

---

## 4. سياسة الأرشفة

1. **لا يُحذف أي مستند نهائياً** — هذه قاعدة غير قابلة للتفاوض (UPDS-05 §4.5).
2. الإلغاء يتم بـ**النقل** إلى `docs/99-archive/<سنة الإلغاء>/` بنفس اسم الملف.
3. يُضاف في **أعلى الملف المؤرشَف** صندوق بثلاثة أسطر: تاريخ الأرشفة · سبب
   الأرشفة · المستند الذي حلّ محله (إن وُجد).
4. **لا يُعدَّل محتوى أي ملف بعد أرشفته إطلاقاً.**
5. الأرشفة **قرار إداري** (PM/ARCH) لا قرار تقني — ولا تُنفَّذ إلا بطلب صريح.

---

## 5. المستندات ذات الطبيعة الخاصة في QTMS

| المستند | الخصوصية |
|---|---|
| `03-architecture/adr/ADR-*.md` | **LOG · Append-Only** — لا يُعدَّل معتمد أبداً. المراجعة بـ ADR جديد يشير للقديم كـ«مُستبدَل». |
| `02-requirements/srs.md` | بعد اعتماده يصبح **Baseline** — كل تغيير عبر `change-requests/CR-*.md` حصراً. |
| `08-testing-and-qa/uat-signoff.md` | **LOG** — لا يُعدَّل بعد توقيع العميل؛ أي تغيير جوهري يستلزم دورة UAT جديدة. |
| `06-database/migrations-log.md` | **LOG · Append-Only** — سطر جديد لكل تغيير بنيوي، ولا يُعدَّل سطر قديم. |
| `12-deployment-and-release/changelog.md` | **LOG · AUTO** — يُولَّد من رسائل الالتزام المصنَّفة. |
| `09-security/security-audit-log.md` | **LOG · Append-Only**. |
| المستندات الثابتة التسعة (UPDS-05 §5) | **STATIC** — أي طلب لتعديلها يُعامَل كقرار استثنائي ويحتاج تأكيداً واعياً صريحاً. |

---

## 6. مسؤولية الاتساق

> **مبدأ Docs as Code:** لا يُدمَج أي تغيير يمسّ سلوكاً موثَّقاً دون تحديث
> المستند المقابل **ضمن نفس الدمج** — التوثيق والكود يُدمجان معاً أو لا
> يُدمجان أبداً (UPDS-03 §6).

قائمة التحقق الملزمة عند إنهاء أي مهمة برمجية موجودة في
`docs/07-development/definition-of-done.md`.

<!-- UPDS-DOCGEN:BEGIN — كتلة يديرها upds-docgen آلياً. لا تُحرِّرها يدوياً؛ حرِّر مستندات docs/ وأعد التشغيل. -->

## سياق المشروع (يديره upds-docgen)

**المشروع:** QTMS — نظام محاسبي لإدارة المخزون والذمم والنقد في تجارة القات، على أندرويد بقاعدة سحابية مُدارة بلا خادم وسيط.
**المرحلة الحالية:** **التنفيذ** — ⛔ **والحالةُ التفصيلية كلُّها** (الوحدات · العدّادات · الديون · البنود المفتوحة) **في** `docs/00-governance/upds-workflow/implementation-plan.md` ⛔ **لا هنا.**
**منهجية التطوير:** تزايدية (Incremental) — وحدةُ العمل **زيادة** = شريحة رأسية كاملة تُنتج قدرة قابلة للاستخدام ⛔ لا طبقة أفقية → `docs/21-project-management/development-methodology.md`

## ⛔⛔★★★ اقرأ هذه قبل أي عمل — قواعد مُلزِمة تعيش خارج هذا الملف

- ⛔⛔★★★ **القراراتُ المعمارية (24 `ADR`) وقواعدُ الحَوْكمة والأمان المُلزِمة بنصِّها الكامل:** `.claude/rules/qtms-architecture-and-governance.md` — ★ **تُقرأ قبل تعديل أي كود أو مستند**، ⛔ **ولا تُعدَّل قاعدةٌ منها ولا `ADR` معتمد ولا `srs.md` بعد اعتماده** (الانحرافُ يحتاج `ADR` جديداً أو `change-requests/CR-*.md`) · ★ **وبصمةُ جهة التطوير في** `.claude/rules/developer-identity.md`
- ⛔⛔★★★ **وأيُّ شاشةٍ أو مكوّنِ عرض** — **قبل `module-design` لا بعده: `docs/18-ux-ui/design-system.md` و`design-tokens.md` و`ui-guidelines.md`** ⛔ **وصفرُ قيمةِ لونٍ أو حجمِ خطٍّ أو نصفِ قطرٍ خارج التوكنز.**
- ★ **المعادلاتُ المالية:** `docs/04-design/design-overview.md` §2 · **الأسلوبُ والتسمية:** `docs/04-design/coding-standards.md` و`naming-conventions.md` · **مبادئُ العمارة:** `docs/03-architecture/architecture-principles.md` · **تصميمُ الوحدة:** `docs/04-design/module-design/<module>-design.md`
- ★ **الصلاحيات:** `docs/09-security/security-requirements.md` · **الأسرار:** `docs/09-security/secrets-management-policy.md` · **التفرّعُ والالتزام:** `docs/07-development/branching-strategy.md` و`commit-message-conventions.md` · **تعريفُ «منجَز»:** `docs/07-development/definition-of-done.md` · **خارطةُ الدخول:** `docs/22-onboarding/developer-onboarding.md`
- ★ **دروسُ التنفيذ وعِبَرُه** (`DEBT-*` وما كشفه المحاكي): `docs/00-governance/upds-workflow/implementation-lessons.md` · ★ **ولا تخمّن قاعدة غامضة** — أنشئ بنداً في `implementation-questions.md`.

## الأوامر الفعلية

★ **قواعد الحماية — بلا سحابة وبلا إنترنت** (بوابةُ تغطيةِ الصلاحيات ثم اختباراتُ السلوك على المحاكي · ⚠️ **تحتاج Java 21+** · `DEBT-10` · `DEBT-60`):

```bash
cd test/security-rules && npm test
```

★ **ثلاث حزم Dart لا واحدة** (`ADR-0012`) — ⛔ **والأخيرتان لا تعتمدان `flutter`**:

```bash
cd packages/qtms_domain && dart analyze && dart test   # طبقة النطاق
cd functions          && dart analyze && dart test   # العمليات السحابية
```

★ **ومشروع Flutter** (⛔ **`analyze` صارم: التحذير يُعامَل خطأً** · ★★ **وبوابات التصميم ضمن `flutter test`** — `test/core/design/design_gates_test.dart`) ⛔ **ولا تُحرَّر `mipmap-*` يدوياً:**

```bash
flutter pub get && flutter analyze && flutter test
flutter build apk --flavor production --dart-define-from-file=config/qtms-production-defines.env
dart run flutter_launcher_icons         # عند تغيّر assets/icons/ لا في كل بناء
```

> ⚠️ **البناء يحتاج:** ① `android/app/google-services.json` (خارج المستودع عمداً) ② ★ **توجيه `TEMP` خارج `%LOCALAPPDATA%`** وإلا فشل Gradle بـ`Unable to establish loopback connection` (`DEBT-11`) — **التفاصيل والبدائل المقيسة:** `docs/07-development/build-and-run-instructions.md` §2.1 و§3.
> ⭐★★ **والعَلَم في أمر البناء نفسِه لا فوقه** (`IQ-041` · `AM-014`) — ⚠️ **و`config/qtms-production-defines.env` فارغٌ من القيم عمداً حتى تُنشَر خدمةُ الإنتاج** (`ADR-0022` القاعدة 6) ⛔⛔ **ولا يُنسَخ فيه عنوانُ التجريبية.**

## معرّفات المشروع المعتمدة

| البند | القيمة |
|---|---|
| مشروع الإنتاج · التجريبي | `qtms-orimind-c001` · `qtms-orimind-master` |
| موقع قاعدة البيانات | ★ **`me-central1` (الدوحة)** — نهائي لا رجعة فيه (`ADR-0014`) |
| معرّف التطبيق | `dev.orimind.qtms.c001` · التجريبي `.staging` |
| ★★ الاسم الظاهر | ★ **«وكالة محمد المحامي»** · التجريبي «… — تجريبي» (`AM-002`) — ⛔ **بلا بادئة `QTMS`** · ★ **مصدرُه `appDisplayName` و`app_name` معاً بحارسٍ آلي** |
| ★★ الخطّان المعتمَدان | **IBM Plex Sans Arabic** — الجسم والجداول ★ **وكلُّ رقم** · ★★ **Tajawal** (800/900) — **نصُّ العناوين الحرفي وحده** ⛔ **ولا رقمَ به** (`DS-002` · `docs/19-assets/fonts/README.md` §4) |
| ★★ خدمة العمليات المستدعاة | `qtms-callables` — **حاويةٌ واحدة توجّه بالمسار** (`IQ-019`) · ✅ **التجريبية فقط** ⛔⛔ **ولا تُنشَر بـ`--no-allow-unauthenticated`** · ⚠️★★ **وعددُ عملياتها ومراجعتُها يُقرآن بـ`describe`** ⛔ **لا من مستند** |
| ★ حالةُ البيئتين والقواعد المنشورة | `docs/11-devops-and-infrastructure/environments.md` §1.3 و§1.5 — ⛔ **ولا يُنقَل رقمٌ منها إلى هنا** |

## المكدس المعتمد

**Flutter/Dart** · **Cloud Firestore** · **قواعد الحماية = طبقة التفويض الوحيدة** · **Riverpod** · **`go_router`** · **`freezed` + `json_serializable`** · ★ **والعمليات السحابية بلغة Dart** في `functions/` بطبقة النطاق نفسها (`packages/qtms_domain/`) → `docs/03-architecture/technology-stack.md`

## حالة التنفيذ

★ **مصدرُ الحقيقة الوحيد:** `docs/00-governance/upds-workflow/implementation-plan.md` (حالةُ كل وحدة وأدلّةُ فحوصها) · **والتقاريرُ في** `implementation-report-*.md` · **والدروسُ في** `implementation-lessons.md`.

<!-- UPDS-DOCGEN:END -->

<!-- USER-ADDED (خارج نطاق upds-docgen — لا تُحرَّر ولا تُحذَف آلياً بأي تحديث للإضافة؛ فقط بطلب صريح من مالك المشروع) -->

## بروتوكول تشغيل إضافي لـ /upds-docgen:implement

عند تنفيذ `/upds-docgen:implement` في هذا المشروع تحديداً، اقرأ **أولاً
وقبل أي خطوة أخرى** — بالإضافة إلى كل ما يطلبه `SKILL.md` نفسه، لا بدلاً
عنه —:

`docs/00-governance/upds-workflow/implementation-run-protocol.md`

يحوي **سبع** قواعد تشغيل اعتمدها المالك لهذه المهارة هنا تحديداً: (أ) تسلسل
تشغيلات بالمرحلة الكاملة لا بالوحدة، (ب) حدود اعتماد ذاتي موسّعة للقرارات
التنفيذية الروتينية مع إبقاء `IQ` وكل بوابات UPDS-05 بلا تغيير، (ج) تسليم
فوري لأوامر البيئة المتعذّرة بدل التجريب، (د) **اختبار إلزامي على المحاكي
`Pixel_6_API_36`** لكل زيادة قبل تعليمها منجَزة، ثم شاملٌ للمشروع،
★ **(و) ⛔⛔ لا ادّعاء توثيقيّ مجرَّد**: كل قولٍ بأن أمراً
سُجِّل أو وُثِّق يُرفَق بمسار الملف ورقم السطر أو `diff` فعلي، ⛔⛔★★ **و(ز)
النشرُ وصلاحياتُ IAM حصرُ المالك — على الإنتاج وحده** (`AM-010` · 2026-09-01):
⛅ **فأوامرُ التجريبية تُنفَّذ ذاتياً وتُسجَّل بمخرَجها**، ⛔⛔ **ويقف كلُّ ما يمسّ
`qtms-orimind-c001` حتى تصل كلمةُ `اعتمد-النشر-الإنتاجي`** — ★ **وعند الشكّ في
البيئة يُعامَل إنتاجاً**، ⛔⛔★★★ **و(ح) أي تشغيل يمسّ شاشة يقرأ `18-ux-ui/design-system.md`
و`design-tokens.md` و`ui-guidelines.md` أولاً** (`DS-002` · `AM-007`) ⛔ **لا
`module-design` وحده.** **ولا تخالف ممنوعات UPDS-05 ولا تُضعف بوابة التحقق ولا `IQ` — بل تزيدها شرطاً.**

<!-- /USER-ADDED -->

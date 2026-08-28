# QTMS

نظام محاسبي لإدارة المخزون والذمم والنقد في تجارة القات — أندرويد بقاعدة
سحابية مُدارة بلا خادم وسيط.

- **خريطة الدخول الكاملة:** [`docs/22-onboarding/developer-onboarding.md`](docs/22-onboarding/developer-onboarding.md)
- **البناء والتشغيل:** [`docs/07-development/build-and-run-instructions.md`](docs/07-development/build-and-run-instructions.md)
- **قواعد العمل الملزِمة للأداة:** [`CLAUDE.md`](CLAUDE.md)

---

## ★★ إعداد البناء — ملفّان لا واحد

| الملف | في المستودع؟ | ما فيه |
|---|:-:|---|
| [`config/qtms-public-defines.env`](config/qtms-public-defines.env) | ✅ **نعم** | ★ **معرّفات لا أسرار** — `QTMS_FUNCTIONS_BASE_URL` |
| `.secrets/qtms-staging-qa-account.env` | ⛔ **لا** | **اعتماد حساب الاختبار التجريبي** (`AM-004`) |

```bash
flutter run --flavor staging -d emulator-5554 --dart-define-from-file=config/qtms-public-defines.env --dart-define-from-file=.secrets/qtms-staging-qa-account.env
```

> ✅★★★ **والملف العام احتياطيٌّ تلقائي:** ★ **يُستعمَل حين تغيب القيمة من
> `.secrets/`** — ⟵ **وهو المقصود منه**: **الملفُّ السرّي لا يصحب `git clone`**،
> ★ **فكانت كلُّ نسخةٍ جديدة من المشروع تبدأ بلا العنوان** ⛔ **فلا تكتب شيئاً
> ولا تُظهر سبباً** (`DEBT-49` — **وقع أربع مرات متتالية** · `DEBT-52`).
>
> ★ **والأخصُّ آخِراً** — ⟵ **فما في `.secrets/` يغلب الملفَّ العام عند
> التصادم** (`ADR-0022` القاعدة 4). ⛔⛔ **ولا يدخل الملفَّ العام سرٌّ أبداً:**
> **ما لم يُصنَّف «معرّفاً لا سرّاً» في `environments.md` §1.3 محلُّه
> `.secrets/`** ([`docs/09-security/secrets-management-policy.md`](docs/09-security/secrets-management-policy.md)).
>
> ⚠️ **ويبقى شرطا §2.1 كما هما:** `android/app/google-services.json`
> **خارج المستودع عمداً** · **وتوجيه `TEMP`** على الأجهزة المصابة بـ`DEBT-11`.

**القرار الحاكم:** [`ADR-0022`](docs/03-architecture/adr/ADR-0022-public-build-defines-in-repository.md)

---

## الأوامر الفعلية

```bash
flutter pub get && flutter analyze && flutter test
```

```bash
cd packages/qtms_domain && dart analyze && dart test
```

```bash
cd functions && dart analyze && dart test
```

```bash
cd test/security-rules && npm test
```

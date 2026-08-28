# تعليمات البناء والتشغيل — QTMS

| البند | القيمة |
|---|---|
| **الإلزامية** | **M** |
| **الطبيعة** | LIVING |
| **المالك** | DEV / DEVOPS |

---

## 1. المخرجات المطلوبة

| المخرج | الاستخدام |
|---|---|
| **حزمة تصحيح (Debug)** | التطوير المحلي |
| **حزمة ملف (APK)** | ★ **التوزيع المباشر** — راجع §6 |
| **حزمة متجر (AAB)** | النشر عبر متجر التطبيقات |
| **قواعد الحماية** | ★ **تُنشَر مع كل إصدار يمسّها** |
| **ملف الفهارس** | ★ **يُنشَر قبل الاستعلامات التي يخدمها** |
| **العمليات السحابية** | تُنشَر مع الإصدار المقابل |

## 2. التشغيل المحلي

```bash
# 1) الاعتماديات
flutter pub get

# 2) تحليل ساكن — قبل أي بناء
flutter analyze

# 3) الاختبارات
flutter test

# 4) التشغيل على جهاز/محاكٍ (⚠️ بخدمات Google Play)
flutter run
```

> ⚠️ **التشغيل يستهدف البيئة التجريبية دائماً.** الربط بالإنتاج من جهاز
> تطوير **ممنوع** — [`environment-setup.md`](environment-setup.md) §2.

### 2.1 ★ شرطان قبل أول بناء لأندرويد

**① ملف إعداد المنصة — خارج المستودع عمداً:**

ضع نسخة البيئة المطلوبة في `android/app/google-services.json`.
⛔ **الملف مستبعَد في `.gitignore` ولا يُلتزَم به إطلاقاً**
([`../09-security/secrets-management-policy.md`](../09-security/secrets-management-policy.md)).
وبدونه يفشل البناء برسالة صريحة `File google-services.json is missing` —
**وهو فشل صحيح لا عطل.**

**①-ب ★★ عنوان خدمة العمليات — ✅ مُضمَّنٌ في المستودع منذ 2026-08-28:**

★ **القيمة في ملفٍّ عامٍّ مُلتزَمٍ به** ⛔ **لا في `.secrets/`** (`ADR-0022`):
[`config/qtms-public-defines.env`](../../config/qtms-public-defines.env)

```bash
flutter run --flavor staging -d emulator-5554 --dart-define-from-file=config/qtms-public-defines.env --dart-define-from-file=.secrets/qtms-staging-qa-account.env
```

> ★ **والأخصُّ آخِراً** — ⟵ **فما في الملف السرّي يغلب عند التصادم**:
> **الملفُّ العام احتياطيٌّ لا حاكم** (`ADR-0022` القاعدة 4).
>
> ⛔⛔★★ **وبناءٌ بلا هذه القيمة لا يُخفق في البناء بل عند أول كتابة** —
> ★ **`_baseUrl` يصير فارغاً فيرتدّ `CallableClient.call` قبل `http.post`**:
> **لا طلبَ يُرسَل ولا سطرَ في سجل Cloud Run** (`DEBT-49` · `DEBT-52` ·
> [`troubleshooting-guide.md`](../13-operations/troubleshooting-guide.md) §1).

**② ★ توجيه `TEMP` قبل البناء — على الأجهزة المصابة بـ`DEBT-11` فقط:**

```bash
set TEMP=E:\Projects\qtms\.gradle-tmp && set TMP=E:\Projects\qtms\.gradle-tmp && flutter build apk --debug
```

> ★ **العلّة نفسها التي أعطبت المحاكي** (§3.2 و
> [`troubleshooting-guide.md`](troubleshooting-guide.md) §2-ب): Gradle يبني
> آلية إيقاظه على مقبس `AF_UNIX` داخل `TEMP`، وهو يفشل تحت `%LOCALAPPDATA%`
> على الجهاز المرصود — **فيتوقف البناء بـ`Unable to establish loopback
> connection` قبل أن يبدأ**. ⛔ **ولا علاقة للأمر بجدار حماية.**
> **رُصد فعلياً في 2026-08-22**، وبالتوجيه يمرّ البناء كاملاً.

## 2.2 ★ حزمة النطاق المشتركة والعمليات السحابية

★ **بنية المستودع بعد `ADR-0012`** — ثلاث حزم Dart لا واحدة:

| الحزمة | تُبنى بـ | الدور |
|---|---|---|
| الجذر (`lib/`) | **Flutter** | التطبيق |
| `packages/qtms_domain/` | ★ **`dart` وحده** | طبقة النطاق — يشاركها الطرفان |
| `functions/` | ★ **`dart` وحده** | العمليات السحابية |

```bash
# طبقة النطاق — ★ بلا Flutter عمداً، فهي أسرع وتعمل في أي بيئة
cd packages/qtms_domain && dart pub get && dart analyze && dart test
```

```bash
# العمليات السحابية
cd functions && dart pub get && dart analyze && dart test
```

> ⚠️ **`bin/server.dart` مولَّد** بـ`functions_framework_builder` من
> التعليقات التوضيحية في `lib/functions.dart` — ⛔ **لا يُحرَّر يدوياً**.
> أعِد توليده بعد أي تغيير في نقاط الدخول:
> ```bash
> cd functions && dart run build_runner build --delete-conflicting-outputs
> ```

### 2.2.1 ★ تشغيل عملية سحابية محلياً

`functions_framework` **يقرأ نوع التوقيع من البيئة**، وافتراضه `http`.
⛔ **فتشغيل مشغّل حدث بلا ضبطه يفشل فوراً** برسالة صريحة
(«`function type of cloudevent` … not compatible with … `http`»).

```bash
cd functions
PORT=8080 FUNCTION_SIGNATURE_TYPE=cloudevent GOOGLE_CLOUD_PROJECT=<المشروع>   dart run bin/server.dart
```

ثم يُرسَل حدث اختباري بترويسات CloudEvent (**الوضع الثنائي — وهو ما يرسله
Eventarc فعلاً**):

```bash
curl -X POST http://localhost:8080/ -H "Content-Type: application/json"   -H "ce-specversion: 1.0" -H "ce-id: probe-1"   -H "ce-source: //firestore.googleapis.com/projects/<المشروع>/databases/(default)"   -H "ce-type: google.cloud.firestore.document.v1.created"   -H "ce-subject: documents/sources/SRC-001"   -H "ce-time: 2026-08-22T10:15:30Z"   --data-binary @event.json
```

### 2.2.2 ★ بناء الحاوية — **سياقها جذر المستودع لا `functions/`**

```bash
docker build -f functions/Dockerfile -t qtms-functions .
```

> ⚠️ **السياق الأضيق يفشل البناء** — لأن `functions/` تعتمد
> `../packages/qtms_domain` بمسار محلي، ولا يرى Docker ما هو خارج سياقه.

> ★ **وهذا البناء هو ما يُنفِّذ القاعدة 1 من `ADR-0012` فعلياً:** الصورة
> `dart:` بلا Flutter، فأي تسرّب اعتمادية عليه **يفشل هنا**.
> ⚠️ **ولا يُغني عنه `dart pub get` محلياً:** جهاز التطوير فيه Flutter
> مثبَّت، **فيَحُلّ `sdk: flutter` بنجاح تام ولا ينبّه إلى شيء** — رُصد هذا
> عملياً في عيّنة `DEBT-09`. ولذلك يحرس الحالةَ محلياً اختبارٌ صريح:
> `functions/test/no_flutter_dependency_test.dart` يقرأ **الرسم المحلول
> كاملاً** (`pubspec.lock`) فيرى الاعتمادية غير المباشرة كما يرى المباشرة.

### 2.2.2-ب ★ الفحص ⑥ — التزامن على قاعدة حقيقية

الفحص السادس من «الخطوة صفر» (**«توليد رقمين متزامنين لجونيتين ينجح بلا
تكرار»** · `E-43`) **لا يُثبَت باختبار وحدة** — التكرار يقع في المعاملة لا في
المنطق. ولذلك له أداة تُشغَّل على بيئة حقيقية:

```bash
cd functions
GOOGLE_CLOUD_PROJECT=qtms-orimind-master dart run tool/check_six_concurrent_allocation.dart
```

تُطلق **12 تخصيصاً متزامناً** على العدّاد نفسه وتتحقق من: **لا تكرار · يبدأ
من ١ · بلا فجوة**. ⛔ **وترفض التشغيل على مشروع ينتهي بـ`-c001`** (الإنتاج).

> ⚠️ **وأهم ما تكشفه هذه الأداة أن إعادة المحاولة بلا تباعد لا تكفي:** رُصد
> فعلياً أن اثنتي عشرة محاولة متزامنة تفشل جميعاً بـ`Aborted due to
> cross-transaction contention` — لأن الخاسرين يعيدون المحاولة **في اللحظة
> نفسها فيتصادمون مجدداً**. والحل **تباعد أسّي بتشويش عشوائي**، وهو مُطبَّق
> في `CounterAllocator`.

### 2.2.3 ⚠️ صيغة حمولة مشغّل قاعدة البيانات — **protobuf إلزاماً**

★ **رُصد فعلياً على السحابة (2026-08-22):** أحداث قاعدة البيانات في Eventarc
**لا تقبل إلا `application/protobuf`**. وأي محاولة لإنشاء المشغّل بغيرها
تُرفَض عند الإنشاء برسالة صريحة:

```text
invalid value for trigger.event_data_content_type:
"application/json" is not supported by this event type
```

⛔ **وحذف الخيار لا يُصلح شيئاً** — القيمة الفارغة مرفوضة كذلك.

> ⚠️ **وهذا يعني أن فكّ الحمولة بلغة Dart يحتاج أنواع protobuf مولَّدة**
> لـ`google.events.cloud.firestore.v1.DocumentEventData` — **وهو عمل لم
> يُنجَز بعد**. ولا ينطبق القيد على **العمليات المستدعاة مباشرةً**
> (`api-overview.md` §3.1) فهي HTTP عادية بحمولة JSON.
>
> ★ **تصحيح لصياغة سابقة في هذا المستند:** كان مكتوباً هنا أن المشغّل
> يُنشَأ بـ`--event-data-content-type=application/json`. **وهو خطأ ثبت
> بالتجربة** — صُحِّح في نفس اليوم.

## 3. ★ المحاكي السحابي المحلي — إلزامي

```text
① تشغيل محاكي المنصة محلياً (قاعدة البيانات + العمليات السحابية)
② تشغيل اختبارات قواعد الحماية عليه
③ ⛔ لا يُدمَج تغيير في القواعد قبل مرور اختباراتها هنا
```

### 3.1 الأمر الفعلي

```bash
cd test/security-rules && npm install && npm test
```

`npm test` يشغّل بوابتين متتاليتين، **وكلتاهما شرط قبول**:

| # | البوابة | الأمر | يحتاج محاكياً؟ |
|:-:|---|---|:-:|
| ① | **تغطية الصلاحيات** — كل مفتاح في الكتالوج له شرط، ولا شرط على مفتاح خارجه | `npm run check:coverage` | ⛔ لا — تحليل نصي |
| ② | **سلوك القواعد** على المحاكي — **168 اختباراً**: 45 سلوكية (`rules.test.js`) + **122 مصفوفة صلاحيات** (`permission-matrix.test.js`) + حارس تطابق | `npm run test:rules` | ✅ نعم |

> ★ **البوابة ① لا تُغني عن ②:** نجاحها يُثبت أن **كل مفتاح مذكور**،
> ⛔ **لا أن الشرط صحيح منطقياً** — وهذا فرق أثبتته التجربة فعلياً:
> اختباران كانا يمرّان بالتغطية بينما كانا يفشلان سلوكياً.

### 3.2 المتطلبات المسبقة

| البند | القيمة | لماذا |
|---|---|---|
| **Java** | ★ **21 أو أحدث** | `firebase-tools` ≥ 15 **يرفض** ما قبله صراحةً |
| **Node** | 20 أو أحدث | `node --test` |
| **firebase-tools** | ≥ 15 | `firebase emulators:exec` |

يبحث [`run-rules-tests.mjs`](../../test/security-rules/run-rules-tests.mjs) عن
JDK صالح بهذا الترتيب ويطبع ما اختاره: `QTMS_JAVA_HOME` ← `JAVA_HOME` ←
`java` على المسار ← مواضع شائعة (منها JBR المرافق لـAndroid Studio).
ولتثبيت اختيار بعينه:

```bash
set QTMS_JAVA_HOME=C:\Program Files\Android\Android Studio\jbr
```

> ⚠️ **على Windows يوجّه المُشغِّل مجلد مقابس `AF_UNIX` خارج `%LOCALAPPDATA%`
> تلقائياً** — وبدونه لا يبدأ المحاكي إطلاقاً على بعض الأجهزة. التفصيل
> والسبب الجذري في [`troubleshooting-guide.md`](troubleshooting-guide.md) §2-ب،
> والدَّين المتبقي `DEBT-11`. ⛔ **ولا يُطلَب تعطيل أي حماية.**

> ★ **قواعد الحماية هي طبقة التفويض الوحيدة في هذا النظام** (لا خادم وسيط).
> **اختبارها ليس رفاهية بل بند قبول** — راجع
> [`../09-security/security-requirements.md`](../09-security/security-requirements.md).

## 4. البناء للإصدار

```bash
# حزمة المتجر
flutter build appbundle --release

# حزمة ملف مباشر
flutter build apk --release
```

| البند | القاعدة |
|---|---|
| **التوقيع** | ★ **شهادة التوقيع خارج المستودع دائماً** — [`../09-security/secrets-management-policy.md`](../09-security/secrets-management-policy.md) |
| **معرّف التطبيق** | ✅ **الإنتاج:** `dev.orimind.qtms.c001` · 🔶 **التجريبي:** `…​.staging` |
| **اسم العرض** | ✅ ★ **وكالة محمد المحامي** — `android:label="@string/app_name"` · 🔶 **التجريبي:** «… — تجريبي» (`AM-002`) |
| **رقم الإصدار** | وفق [`../00-governance/versioning-and-change-policy.md`](../00-governance/versioning-and-change-policy.md) |
| **الحد الأدنى** | **API 26** |
| **الأيقونة** | ✅ **مولَّدة من شعار العميل** — [`../19-assets/icons/`](../19-assets/icons/) · **§4.1 أدناه** |
| **الخط العربي** | ✅ **IBM Plex Sans Arabic** — [`../19-assets/fonts/`](../19-assets/fonts/) |

### 4.1 ★ إعادة توليد أيقونة التطبيق (`AM-002`)

```bash
dart run flutter_launcher_icons
```

| البند | القاعدة |
|---|---|
| **متى يُشغَّل** | ★ **عند تغيّر أي من ملفات `assets/icons/` وحده** — ⛔ **ولا يُشغَّل في كل بناء** |
| **مدخلاته** | `assets/icons/app-icon-foreground.png` · `app-icon-background.png` — من كتلة `flutter_launcher_icons` في `pubspec.yaml` |
| **مخرجاته** | `android/app/src/main/res/mipmap-*/ic_launcher*.png` · `mipmap-anydpi-v26/ic_launcher.xml` |
| ⛔ **ممنوع** | ★ **تحرير أي ملف داخل `mipmap-*` يدوياً** — مخرَجات مولَّدة يمحوها التشغيل التالي |
| ★ **شاشة الإقلاع الأصلية** | ⛔ **ليست من مخرجات المولّد** — `drawable-*/launch_image.png` تُشتقّ يدوياً من الطبقة الأمامية بخمس كثافات، ويشير إليها `launch_background.xml` |

> ★ **والأصل يبقى في `docs/19-assets/icons/`** — ★ **و`assets/icons/` نسخته
> التنفيذية داخل الحزمة**، بنفس آلية الخط حرفياً.

## 5. ترتيب النشر — ★ لا يُخالَف

```text
① الفهارس            ⟵ أولاً دائماً (وإلا فشلت الاستعلامات أو صارت مسحاً كاملاً)
② قواعد الحماية       ⟵ قبل الكود الذي يعتمد عليها
③ العمليات السحابية   ⟵ قبل الواجهة التي تستدعيها
④ التطبيق             ⟵ أخيراً
```

> ⚠️ **عكس الترتيب يفتح نافذة زمنية** إما **بلا حماية** أو **بواجهة تستدعي
> عملية غير موجودة**. التفصيل الكامل في
> [`../12-deployment-and-release/deployment-guide.md`](../12-deployment-and-release/deployment-guide.md).

## 6. ★ ملاحظة التوزيع المباشر

> **المصدر يذكر التوزيع المباشر للحزمة كخيار قائم.** وهذا يعني:
>
> | الأثر | الإلزام |
> |---|---|
> | **لا تحديث تلقائي** | ★ **آلية تنبيه داخل التطبيق للإصدار الإلزامي** |
> | **لا فحص متجر** | **مسؤولية الجودة كاملة على الفريق** |
> | **الحزمة تُوقَّع بنفس الشهادة دائماً** | **تغييرها يمنع التحديث فوق المثبَّت** |
> | **مصدر التنزيل يُتحقَّق منه** | **حزمة مُعدَّلة = تطبيق مالي مزوَّر** |

## 7. التحقق قبل الإصدار

| # | الفحص | إلزامي؟ |
|:-:|---|:-:|
| 1 | `flutter analyze` بلا أخطاء | ✅ |
| 2 | كل الاختبارات تمرّ | ✅ |
| 3 | ★ **اختبارات قواعد الحماية تمرّ على المحاكي** | ✅ |
| 4 | ★ **السيناريو المرجعي (§15) متوازن** | ✅ |
| 5 | **التخزين المؤقت المحلي مُعطَّل فعلياً** | ✅ |
| 6 | الواجهة **عربية RTL** بالكامل | ✅ |
| 7 | **تكبير النص 1.3×** بلا كسر | ✅ |
| 8 | ⛔ **لا سرّ داخل الحزمة** | ✅ |
| 9 | الفهارس والقواعد **منشورة قبل الحزمة** | ✅ |
| 10 | سطر في `migrations-log.md` إن مُسَّت البنية | ✅ |

## 8. المرتبطات

[`environment-setup.md`](environment-setup.md) ·
[`troubleshooting-guide.md`](troubleshooting-guide.md) ·
[`../11-devops-and-infrastructure/ci-cd-pipeline.md`](../11-devops-and-infrastructure/ci-cd-pipeline.md) ·
[`../12-deployment-and-release/deployment-guide.md`](../12-deployment-and-release/deployment-guide.md) ·
[`../12-deployment-and-release/release-checklist.md`](../12-deployment-and-release/release-checklist.md)

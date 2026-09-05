# شاشة البداية (Splash)

| البند | القيمة |
|---|---|
| **اسم الكلاس** | `_SplashScreen` (خاص، داخل الموجّه) |
| **مسار الملف** | `lib/app/router.dart` (السطور 589-601) |
| **المسار الملاحي** | `/` — `splashRoute` |
| **اسم اللقطة المتوقّع** | `splash_screen.png` |

## الغرض
شاشة انتظار قصيرة تُعرض بينما تُقرأ حالة الجلسة (`sessionProvider`). الموجّه يبقي المستخدم عليها ما دامت الحالة غير معروفة، ولا يُعامَل ذلك «خروجاً». تُكمل بصرياً ما بدأته شاشة الإقلاع الأصلية في أندرويد (`launch_background.xml`) بالشعار نفسه، بلا وميض هوية بين الاثنتين.

## العناصر

| # | الـ Widget class الفعلي | الوصف والمواصفات |
|:-:|---|---|
| 1 | `Scaffold` | جذر الشاشة — بلا `appBar` (قاعدة: لا شريط علوي في شاشات ما قبل الجلسة). |
| 2 | `Center` > `Column` | `mainAxisSize: MainAxisSize.min` — توسيط رأسي وأفقي. |
| 3 | `BrandLogo` | شعار العميل. الحجم الافتراضي `BrandLogo.defaultSize = 112` بكسل. `Image.asset('assets/icons/app-icon-foreground.png')` بـ `BoxFit.contain` و`semanticLabel = appDisplayName`. عند تعذّر فكّ الأصل يُستبدَل بـ `SizedBox(height: size)` — لا رمز بديل. |
| 4 | `SizedBox` | فاصل `height: Spacing.space24` = 24. |
| 5 | `CircularProgressIndicator` | مؤشّر الانتظار الافتراضي بلون الثيم الأساسي. |

**بلا نصّ إطلاقاً** — الشعار نفسه يحمل اسم العميل مرسوماً. **وبلا بصمة جهة التطوير** (ممنوعة هنا صراحةً).

## شجرة الـ Widget tree
```
Scaffold
└── Center
    └── Column (mainAxisSize: min)
        ├── BrandLogo (112×112)
        ├── SizedBox (h: 24)
        └── CircularProgressIndicator
```

## الحالات المُعالجة
| الحالة | الوضع |
|---|---|
| Loading | ✅ هي الشاشة نفسها بالكامل — لا حالة أخرى فيها. |
| Error | ❌ غير مُعالجة — خطأ قراءة الجلسة يبقي المستخدم على هذه الشاشة إلى الأبد بلا رسالة. |
| Empty | لا ينطبق. |

## آلية التنقل
- **الدخول إليها:** `initialLocation` — أول شاشة عند تشغيل التطبيق.
- **الخروج منها (بواسطة `_redirect` مركزياً):**
  - `SessionSignedOut` → `/login`
  - `SessionRejected` → `/blocked`
  - `SessionActive` → `/home` (أو `/setup` إن لزم الإعداد التأسيسي)
  - `null` (قيد التحميل) → تبقى هنا.

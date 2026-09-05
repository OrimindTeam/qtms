# شاشة تسجيل الدخول

| البند | القيمة |
|---|---|
| **اسم الكلاس** | `LoginScreen` (`ConsumerStatefulWidget`) |
| **مسار الملف** | `lib/capabilities/identity_access/presentation/login_screen.dart` |
| **المسار الملاحي** | `/login` — `loginRoute` |
| **اسم اللقطة المتوقّع** | `login_screen.png` |

## الغرض
مصادقة المستخدم بالبريد وكلمة المرور، أو بالبصمة إن فُعِّلت على هذا الجهاز. تتبع «نمط 8» من `ui-guidelines.md`: شعار ⟵ عنوان ⟵ حقول ⟵ زر أساسي عريض، برسائل خطأ محدَّدة لا «حدث خطأ» عامّة. لا منطق أعمال في الشاشة — تستدعي `loginControllerProvider` وتعرض حالته.

## العناصر

| # | الـ Widget class الفعلي | الحجم / اللون / الخط / المسافات | الظهور والتفاعل |
|:-:|---|---|---|
| 1 | `Scaffold` > `SafeArea` > `Center` > `SingleChildScrollView` | `padding: EdgeInsets.all(Spacing.space24)` = 24 | جذر قابل للتمرير عند ظهور لوحة المفاتيح. |
| 2 | `ConstrainedBox` | `maxWidth: 420` | يحدّ عرض النموذج على الشاشات العريضة. |
| 3 | `BrandLogo` | 112×112 · `BoxFit.contain` | شعار العميل مباشرة في أعلى العمود. |
| 4 | `SizedBox` | `brandLogoGap` = `Spacing.space16` = 16 | |
| 5 | `Text` «تسجيل الدخول» | `TypeScale.titleLg` (20px · w700 · height 1.35) · `SemanticColors.textPrimary` · `textAlign: center` | عنوان. |
| 6 | `SizedBox` | 24 | |
| 7 | `TextField` — البريد | `labelText: 'البريد الإلكتروني'` · `keyboardType: emailAddress` · `autofillHints: [username]` · `textInputAction: next` · ارتفاع الحقل من الثيم `Sizes.fieldHeight = 52` · `Radii.field = 14` | مباشر في الشاشة. `enabled: !submitting`. `onChanged` يُعيد البناء لتفعيل الزر. |
| 8 | `SizedBox` | `Spacing.space12` = 12 | |
| 9 | `TextField` — كلمة المرور | `labelText: 'كلمة المرور'` · `obscureText: !_passwordVisible` · `autofillHints: [password]` · `textInputAction: done` | مباشر. `onSubmitted` يُرسِل. |
| 10 | `IconButton` داخل `suffixIcon` | `Icons.visibility_outlined` / `Icons.visibility_off_outlined` · `size: Sizes.iconLg = 24` · `tooltip` يذكر الحالة | **Trigger:** نهاية حقل كلمة المرور. يبدّل إظهار/إخفاء النصّ. |
| 11 | `SizedBox` | 16 | |
| 12 | `FilledButton` «دخول» | عريض بعرض العمود · ارتفاع `Sizes.buttonPrimaryHeight = 52` من الثيم | الزر الأساسي. معطَّل ما لم يمتلئ الحقلان (`_canSubmit`). |
| 13 | `CircularProgressIndicator` داخل `SizedBox` داخل الزر | `20×20` (`Sizes.iconMd`) · `strokeWidth: Sizes.focusWidth = 2` · `color: SemanticColors.textOnInverse` | يحلّ محلّ نصّ الزر أثناء `LoginSubmitting` — بعرض ثابت فلا يقفز الزر. |
| 14 | `OutlinedButton.icon` «الدخول ببصمة الإصبع» | `icon: Icons.fingerprint` · ارتفاع `Sizes.buttonSecondaryHeight = 44` | **شرطي:** يظهر فقط إذا `biometricLoginEnabledProvider == true` (أي وُجدت بيانات محفوظة على هذا الجهاز). يسبقه `SizedBox(12)`. |
| 15 | `QtmsInlineBanner` — حالة البصمة | `triad: SemanticTriads.danger` (تعبئة `#FAE7E0` · حدّ `#EED6CC` · حبر `#9E3F27`) | **شرطي:** يظهر تحت الأزرار عند فشل محاولة البصمة. يسبقه `SizedBox(16)`. |
| 16 | `_RejectionBanner` > `QtmsInlineBanner` | `triad: SemanticTriads.danger` | **شرطي:** يظهر عند `LoginRejected`. نصّه من كتالوج الرسائل (`signInRejectionMessage`) لا مُصاغ في الشاشة. |

## شجرة الـ Widget tree
```
Scaffold (بلا appBar)
└── SafeArea
    └── Center
        └── SingleChildScrollView (padding: 24)
            └── ConstrainedBox (maxWidth: 420)
                └── Column (min · crossAxis: stretch)
                    ├── BrandLogo (112)
                    ├── SizedBox (16)
                    ├── Text «تسجيل الدخول» (titleLg)
                    ├── SizedBox (24)
                    ├── TextField (البريد الإلكتروني)
                    ├── SizedBox (12)
                    ├── TextField (كلمة المرور)
                    │   └── suffixIcon: IconButton (visibility toggle)
                    ├── SizedBox (16)
                    ├── FilledButton («دخول» | CircularProgressIndicator)
                    ├── [شرطي] SizedBox(12) + OutlinedButton.icon (بصمة)
                    ├── [شرطي] SizedBox(16) + QtmsInlineBanner (danger — تعذّر البصمة)
                    └── [شرطي] SizedBox(16) + _RejectionBanner (danger — رفض الدخول)
```

## الحالات المُعالجة
| الحالة | الوضع |
|---|---|
| Loading | ✅ `LoginSubmitting` → مؤشّر داخل الزر + تعطيل الحقلين. |
| Error | ✅ حالتان منفصلتان عمداً: `_RejectionBanner` لرفض المصادقة (نصّ من الكتالوج لكل سبب)، و`_biometricStatus` لتعذُّر البصمة قبل الإرسال (خمس رسائل مختلفة حسب `BiometricOutcome`). |
| Empty | لا ينطبق. |

## ملاحظة تشغيلية
`initState` يملأ الحقلين مسبقاً من `stagingQaCredentialsProvider` — محروس بـ `kDebugMode` وميت في بناء الإصدار. **قد يظهر هذا في لقطة المحاكي.**

## آلية التنقل
- **الدخول إليها:** توجيه مركزي من أي مسار عند `SessionSignedOut`.
- **الخروج منها:** لا ملاحة يدوية في الشاشة إطلاقاً — نجاح الدخول يُحدِّث `sessionProvider` فيُخرِج الموجّهُ الشاشةَ تلقائياً إلى `/home` أو `/setup` أو `/blocked`.

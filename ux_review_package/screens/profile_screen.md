# الملف الشخصي

| البند | القيمة |
|---|---|
| **اسم الكلاس** | `ProfileScreen` (`ConsumerWidget`) |
| **مسار الملف** | `lib/capabilities/identity_access/presentation/profile_screen.dart` |
| **المسار الملاحي** | `/home/profile` — `profileRoute` |
| **اسم الشاشة في الشريط** | `profileScreenTitle` = «الملف الشخصي» |
| **اسم اللقطة المتوقّع** | `profile_screen.png` · وللورقة: `profile_password_prompt_sheet.png` |

## الغرض
ما يملك المستخدم تغييره في حسابه وحده: **الدخول بالبصمة** و**كلمة المرور**. ⛔ **ولا اسم ولا بريد ولا دور ولا صلاحية تُعدَّل من هنا** — تلك من `/home/users` بمفاتيح إدارية. والاسم والبريد يُعرَضان قراءةً فقط.

## العناصر

| # | الـ Widget class الفعلي | الحجم / اللون / الخط / المسافات | الظهور والتفاعل |
|:-:|---|---|---|
| 1 | `Scaffold` + `QtmsTopBar` | `screenTitle: 'الملف الشخصي'` | |
| 2 | `ListView` | `padding: EdgeInsetsDirectional.all(16)` | جذر المحتوى. |
| 3 | `_IdentityHeader` > `QtmsAvatar` | `size: Sizes.avatarLg = 64` · دائرة بثلاثية تصنيفية **مشتقّة من حروف الاسم** (`familyIndexOf`) · الحرف الأول بـ`TypeScale.titleSm` | صورة رمزية غير قابلة للنقر. |
| 4 | `Text` — اسم المستخدم | `TypeScale.titleLg` (20 · w700) · `textPrimary` · `center` | من `session.displayName`. |
| 5 | `Text` — البريد | `TypeScale.bodyMd` · `textSecondary` · `center` · يسبقه `SizedBox(4)` | **شرطي:** يظهر إن كان للحساب بريد. |
| 6 | `SizedBox` | 24 | |
| 7 | `_Section` «الدخول ببصمة الإصبع» | العنوان `TypeScale.titleSm` + `Divider(height: 1)` + فاصل 12 | مُغلِّف قسم متكرر داخلي. |
| 8 | `SwitchListTile.adaptive` | `contentPadding: EdgeInsets.zero` · المفتاح: مسار `primary500` والمقبض `surface` عند التفعيل | العنوان «تفعيل الدخول بالبصمة». **معطَّل** ما لم تكن `BiometricAvailability.available`. النصُّ الثانوي يتغيّر بأربع حالات (متاح · لا بصمة مسجَّلة · الجهاز لا يدعم · «يجري التحقق…»). |
| 9 | `QtmsInlineBanner` — حالة البصمة | `triad: success` عند النجاح و`danger` عند الفشل · حشو 12 · `Radii.card = 20` | **شرطي:** بعد كل محاولة تفعيل/إيقاف. ستُّ رسائل مختلفة حسب `BiometricOutcome`. |
| 10 | `showModalBottomSheet` > `_PasswordPrompt` | `isScrollControlled: true` · خلفية `surface` · انحناء علوي `Radii.sheet = 28` · مقبض سحب `neutral300` · حشو سفلي = `viewInsets.bottom + 16` | **Trigger:** تشغيل مفتاح البصمة إلى «مُفعَّل» **فقط** (لا عند الإيقاف). ورقة سفلية تحوي: `Text` «تأكيد كلمة المرور» (`titleLg`) · `TextField` «كلمة المرور الحالية» بـ`autofocus` و`suffixIcon` لإظهار/إخفاء · `FilledButton` «متابعة» (معطَّل ما لم يُكتب شيء) · `TextButton` «إلغاء». |
| 11 | `_Section` «تغيير كلمة المرور» | نفسها | القسم الثالث. |
| 12 | ثلاثة × `_PasswordField` > `TextField` | `obscureText` مبدَّل لكل حقل **باستقلال** · `suffixIcon: IconButton` بـ`Icons.visibility_outlined`/`visibility_off_outlined` حجم `Sizes.iconLg = 24` · فاصل 12 بينها | التسميات: «كلمة المرور الحالية» · «كلمة المرور الجديدة (`initialPasswordMinLength` أحرف فأكثر)» · «تأكيد كلمة المرور الجديدة». |
| 13 | `QtmsInlineBanner` — حالة كلمة المرور | `success` / `danger` | **شرطي:** رسائل رفض محدَّدة من `PasswordChangeRejection` (خمس حالات: الحالية ناقصة · قصيرة · لا تطابق · هي نفسها الحالية · تعذُّر عام). |
| 14 | `FilledButton` «تغيير كلمة المرور» | ارتفاع 52 | يتحقّق محلياً بـ`validatePasswordChange` قبل أي نداء شبكة. وعند النجاح: يُفرِّغ الحقول الثلاثة **ويُحدِّث كلمة المرور المحفوظة للبصمة** (`refreshStoredPassword`) فلا تفترق الاثنتان. |

## شجرة الـ Widget tree
```
Scaffold
├── appBar: QtmsTopBar («الملف الشخصي»)
└── ListView (padding: 16)
    ├── _IdentityHeader
    │   ├── QtmsAvatar (64)
    │   ├── Text (الاسم — titleLg)
    │   └── [شرطي] Text (البريد — bodyMd/textSecondary)
    ├── SizedBox (24)
    ├── _BiometricSection → _Section «الدخول ببصمة الإصبع»
    │   ├── Text (titleSm) + Divider + SizedBox(12)
    │   ├── SwitchListTile.adaptive
    │   └── [شرطي] QtmsInlineBanner
    │       └── (Trigger عند التفعيل) showModalBottomSheet → _PasswordPrompt
    │           ├── Text «تأكيد كلمة المرور» (titleLg)
    │           ├── TextField (autofocus + suffixIcon visibility)
    │           ├── FilledButton «متابعة»
    │           └── TextButton «إلغاء»
    ├── SizedBox (24)
    └── _PasswordSection → _Section «تغيير كلمة المرور»
        ├── _PasswordField × 3 (TextField + IconButton visibility)
        ├── [شرطي] QtmsInlineBanner
        └── FilledButton «تغيير كلمة المرور»
```

## الحالات المُعالجة
| الحالة | الوضع |
|---|---|
| Loading | ⚠️ **جزئية:** لا هيكل عظمي. أثناء قراءة دعم البصمة يظهر النصُّ «يجري التحقق من دعم الجهاز…» والمفتاح معطَّل. وأثناء الإرسال تُعطَّل الأزرار (`_busy` / `_submitting`) ⛔ **بلا مؤشّر دوران** — الزرُّ يبدو ساكناً. |
| Error | ✅ **كاملة ومحدَّدة:** لافتات داخلية بنصٍّ لكل سبب — ستّة لنتائج البصمة وخمسة لرفض تغيير كلمة المرور ⛔ **بلا «حدث خطأ» عامّة.** |
| Empty | لا ينطبق. |
| بلا جلسة | `session == null` ⟶ `Scaffold` بالشريط العلوي و`SizedBox.shrink()` جسماً. |

## آلية التنقل
- **الدخول إليها:** **من ورقة الجلسة وحدها** — `showQtmsSessionSheet` التي تفتحها الصورة الرمزية في `QtmsTopBar` من **أي شاشة** ⟶ `ListTile` «الملف الشخصي».
- **الخروج منها:** ⛔ **لا مدخلَ ملاحةٍ واحداً في جسم الشاشة** — الرجوع بزرّ النظام، أو إلى `/home/settings` عبر ورقة الجلسة نفسها.

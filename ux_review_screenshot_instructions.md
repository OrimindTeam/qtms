# تعليمات التقاط لقطات الشاشة — QTMS

> ⚠️ **هذا الملفُّ خارجَ حزمة `ux_review_package/` عمداً** — وهو **ملفٌّ مؤقّتٌ للعمل**: احذفه بنفسك بعد إتمام اللقطات، ثم اضغط المجلّد.
>
> ★ **هذه أوّلُ جولةٍ تُنشأ فيها التعليمات** — فالجولةُ السابقة أنجزت شاشتين فقط (البداية والدخول) بلا لقطات. **ولذلك القائمةُ أدناه شاملةٌ لكل الشاشات.** وفي الجولات القادمة لن يُدرَج هنا إلا ما تغيّر بصرياً أو أُضيف.

---

## قبل أن تبدأ

### 1. الحالةُ الحاليةُ للمحاكي والتطبيق
| البند | الحال |
|---|---|
| المحاكي | ✅ **`Pixel_6_API_36` مُشغَّلٌ ومُقلِعٌ بالكامل** — معرّفُه `emulator-5554` |
| التطبيق | يُبنى ويُنصَّب بالأمر أدناه (نكهةُ `staging`) |

**وإن أُغلق المحاكي أو انقطع، أعِد تشغيله:**
```bash
"C:\Users\Abdulfatah\AppData\Local\Android\Sdk\emulator\emulator.exe" -avd Pixel_6_API_36
```

**ولإعادة تشغيل التطبيق بنفسك:**
```bash
flutter run --flavor staging --dart-define-from-file=config/qtms-public-defines.env -d emulator-5554
```

### 2. تحقّقٌ سريعٌ من الاتصال — نفّذه أولاً
```bash
& "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" devices
```
يجب أن يُخرِج `emulator-5554   device`. **وإن ظهر `offline` أو لا شيء فلا تُكمِل** — أعد تشغيل المحاكي.

### 3. ملاحظاتٌ تُوفّر عليك وقتاً
- ⛔ **لا تحتاج `sudo` ولا صلاحياتٍ خاصّة** — كلُّ الأوامر أدناه جاهزةٌ للنسخ والتنفيذ **كما هي**.
- ★ **كلُّ أمرٍ سطرٌ واحدٌ في PowerShell** يفعل أربعةَ أشياء: يلتقط ⟶ يسحب ⟶ يسمّي ⟶ يضع الملفَّ في مكانه الصحيح · **ثم يحذف الملفَّ المؤقّت من المحاكي.**
- ⚠️ **الشاشاتُ الأولى تحتاج حساباً على التجريبية.** وفي بناء `debug` **يُعبَّأ حقلا الدخول تلقائياً** إن كانت بيانات حساب الاختبار مُمرَّرةً في البناء — **فقد تظهر في لقطة `login_screen.png` بريدٌ وكلمةُ مرورٍ مُعبَّآن.** إن أردت لقطةً نظيفةً فأخلِ الحقلين قبل التصوير.
- ★ **اللقطاتُ الاختياريةُ مُوسَّمةٌ بـ`(اختياري)`** — التقطها إن أمكن، وتجاوزها إن لم تتوفّر بيانات.
- ⚠️ **الشاشاتُ التي تحتاج بياناتٍ مُدخَلةً مسبقاً مُوسَّمةٌ بـ`⚠️ تحتاج بيانات`** — إن كانت فارغةً فلقطةُ الحالة الفارغة **مفيدةٌ بذاتها** لمراجعة UX، فالتقطها كما هي.

---

## أ. شاشاتُ ما قبل الجلسة (٣ لقطات)

### 1. شاشةُ البداية — `splash_screen.png`
**افتح هذه الشاشة يدوياً على المحاكي:** هي أوّلُ ما يظهر لحظةَ تشغيل التطبيق (ثانيةٌ أو أقلّ). **الأسهلُ:** أغلق التطبيق تماماً ثم افتحه والتقط فوراً. **ثم نفّذ الأمر التالي:**
```bash
& "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell screencap -p /sdcard/qtms_shot.png; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" pull /sdcard/qtms_shot.png "E:\Projects\qtms\ux_review_package\screenshots\splash_screen.png"; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell rm /sdcard/qtms_shot.png
```

### 2. شاشةُ تسجيل الدخول — `login_screen.png`
**افتح هذه الشاشة يدوياً على المحاكي:** تظهر تلقائياً بعد البداية إن لم تكن مسجَّلَ الدخول (أو سجّل الخروج من ورقة الجلسة). **ثم نفّذ الأمر التالي:**
```bash
& "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell screencap -p /sdcard/qtms_shot.png; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" pull /sdcard/qtms_shot.png "E:\Projects\qtms\ux_review_package\screenshots\login_screen.png"; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell rm /sdcard/qtms_shot.png
```

### 3. شاشةُ الحساب المعطَّل — `session_blocked_screen.png` **(اختياري)**
**افتح هذه الشاشة يدوياً على المحاكي:** تحتاج حساباً معطَّلاً (`isActive: false`) — **تجاوزها إن لم يتوفّر.** **ثم نفّذ الأمر التالي:**
```bash
& "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell screencap -p /sdcard/qtms_shot.png; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" pull /sdcard/qtms_shot.png "E:\Projects\qtms\ux_review_package\screenshots\session_blocked_screen.png"; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell rm /sdcard/qtms_shot.png
```

---

## ب. الصدَفةُ وشاشاتُ الجلسة (٤ لقطات)

### 4. لوحةُ اليوم — `home_shell.png`
**افتح هذه الشاشة يدوياً على المحاكي:** هي أوّلُ شاشةٍ بعد الدخول. **مرِّر إلى الأعلى** فتظهر صفَّا «يحتاج تصرُّفاً» وأولُ قسم. **ثم نفّذ الأمر التالي:**
```bash
& "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell screencap -p /sdcard/qtms_shot.png; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" pull /sdcard/qtms_shot.png "E:\Projects\qtms\ux_review_package\screenshots\home_shell.png"; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell rm /sdcard/qtms_shot.png
```

### 5. ورقةُ الجلسة — `session_sheet.png`
**افتح هذه الشاشة يدوياً على المحاكي:** انقر **الصورةَ الرمزية** في أقصى نهاية الشريط العلوي (اليسار في RTL) فتُفتَح ورقةٌ سفليةٌ بثلاثة بنود. **ثم نفّذ الأمر التالي:**
```bash
& "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell screencap -p /sdcard/qtms_shot.png; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" pull /sdcard/qtms_shot.png "E:\Projects\qtms\ux_review_package\screenshots\session_sheet.png"; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell rm /sdcard/qtms_shot.png
```

### 6. الملفُّ الشخصي — `profile_screen.png`
**افتح هذه الشاشة يدوياً على المحاكي:** الصورةُ الرمزية ⟶ «الملف الشخصي». **ثم نفّذ الأمر التالي:**
```bash
& "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell screencap -p /sdcard/qtms_shot.png; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" pull /sdcard/qtms_shot.png "E:\Projects\qtms\ux_review_package\screenshots\profile_screen.png"; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell rm /sdcard/qtms_shot.png
```

### 7. ورقةُ تأكيد كلمة المرور — `profile_password_prompt_sheet.png`
**افتح هذه الشاشة يدوياً على المحاكي:** في «الملف الشخصي» **شغّل مفتاح «تفعيل الدخول بالبصمة»** فتُفتَح ورقةُ «تأكيد كلمة المرور». **ثم نفّذ الأمر التالي:**
```bash
& "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell screencap -p /sdcard/qtms_shot.png; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" pull /sdcard/qtms_shot.png "E:\Projects\qtms\ux_review_package\screenshots\profile_password_prompt_sheet.png"; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell rm /sdcard/qtms_shot.png
```

---

## ج. الإعدادات وحول التطبيق (٣ لقطات)

### 8. الإعدادات — `settings_screen.png`
**افتح هذه الشاشة يدوياً على المحاكي:** الصورةُ الرمزية ⟶ «الإعدادات». **ثم نفّذ الأمر التالي:**
```bash
& "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell screencap -p /sdcard/qtms_shot.png; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" pull /sdcard/qtms_shot.png "E:\Projects\qtms\ux_review_package\screenshots\settings_screen.png"; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell rm /sdcard/qtms_shot.png
```

### 9. حولُ التطبيق — `about_screen.png`
**افتح هذه الشاشة يدوياً على المحاكي:** «الإعدادات» ⟶ قسم «حول» ⟶ «حول التطبيق». ★ **ومرِّر لأسفل حتى يظهر قسمُ «جهة التطوير» كاملاً بقيم التواصل** — فهو موضعُ المراجعة الأهمّ في هذه الشاشة. **ثم نفّذ الأمر التالي:**
```bash
& "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell screencap -p /sdcard/qtms_shot.png; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" pull /sdcard/qtms_shot.png "E:\Projects\qtms\ux_review_package\screenshots\about_screen.png"; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell rm /sdcard/qtms_shot.png
```

### 10. الإعدادُ التأسيسي — `first_run_setup_screen.png` **(اختياري)**
**افتح هذه الشاشة يدوياً على المحاكي:** تظهر **مرةً واحدةً فقط** في مشروعٍ سحابيٍّ جديدٍ بلا `app_settings` — **تجاوزها إن كانت التجريبيةُ مُعَدَّةً سلفاً.** **ثم نفّذ الأمر التالي:**
```bash
& "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell screencap -p /sdcard/qtms_shot.png; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" pull /sdcard/qtms_shot.png "E:\Projects\qtms\ux_review_package\screenshots\first_run_setup_screen.png"; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell rm /sdcard/qtms_shot.png
```

---

## د. الهويّةُ والصلاحيات (٦ لقطات)

### 11. المستخدمون — `users_screen.png`
**افتح هذه الشاشة يدوياً على المحاكي:** «لوحة اليوم» ⟶ قسم «الهوية والصلاحيات» ⟶ «إدارة المستخدمين». **ثم نفّذ الأمر التالي:**
```bash
& "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell screencap -p /sdcard/qtms_shot.png; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" pull /sdcard/qtms_shot.png "E:\Projects\qtms\ux_review_package\screenshots\users_screen.png"; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell rm /sdcard/qtms_shot.png
```

### 12. ورقةُ نموذج المستخدم — `user_form_sheet.png`
**افتح هذه الشاشة يدوياً على المحاكي:** في «المستخدمون» انقر الزرَّ العائم «مستخدم جديد». **ثم نفّذ الأمر التالي:**
```bash
& "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell screencap -p /sdcard/qtms_shot.png; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" pull /sdcard/qtms_shot.png "E:\Projects\qtms\ux_review_package\screenshots\user_form_sheet.png"; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell rm /sdcard/qtms_shot.png
```

### 13. ورقةُ تعطيل المستخدم — `user_disable_sheet.png` **(اختياري)**
**افتح هذه الشاشة يدوياً على المحاكي:** على بطاقةِ مستخدمٍ **غيرِ حسابك** انقر أيقونةَ الحجب. **ثم نفّذ الأمر التالي:**
```bash
& "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell screencap -p /sdcard/qtms_shot.png; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" pull /sdcard/qtms_shot.png "E:\Projects\qtms\ux_review_package\screenshots\user_disable_sheet.png"; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell rm /sdcard/qtms_shot.png
```

### 14. تخصيصُ الصلاحيات — `permissions_screen.png`
**افتح هذه الشاشة يدوياً على المحاكي:** على بطاقةِ مستخدمٍ **غيرِ حسابك** انقر أيقونةَ المفتاح. ★ **ومرِّر قليلاً حتى تظهر شجرةُ الصلاحيات وشارتا «فوق الدور»/«دون الدور» إن وُجدتا.** **ثم نفّذ الأمر التالي:**
```bash
& "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell screencap -p /sdcard/qtms_shot.png; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" pull /sdcard/qtms_shot.png "E:\Projects\qtms\ux_review_package\screenshots\permissions_screen.png"; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell rm /sdcard/qtms_shot.png
```

### 15. الأدوار — `roles_screen.png`
**افتح هذه الشاشة يدوياً على المحاكي:** «لوحة اليوم» ⟶ «الهوية والصلاحيات» ⟶ «الأدوار». **ثم نفّذ الأمر التالي:**
```bash
& "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell screencap -p /sdcard/qtms_shot.png; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" pull /sdcard/qtms_shot.png "E:\Projects\qtms\ux_review_package\screenshots\roles_screen.png"; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell rm /sdcard/qtms_shot.png
```

### 16. ورقةُ نموذج الدور — `role_form_sheet.png`
**افتح هذه الشاشة يدوياً على المحاكي:** في «الأدوار» انقر الزرَّ العائم «دور جديد» — **وهي أطولُ ورقةٍ في التطبيق (سقفُها 85٪ من الشاشة).** **ثم نفّذ الأمر التالي:**
```bash
& "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell screencap -p /sdcard/qtms_shot.png; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" pull /sdcard/qtms_shot.png "E:\Projects\qtms\ux_review_package\screenshots\role_form_sheet.png"; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell rm /sdcard/qtms_shot.png
```

---

## هـ. البياناتُ المرجعية (٨ لقطات)

### 17. المصادر — `sources_screen.png`
**افتح هذه الشاشة يدوياً على المحاكي:** «لوحة اليوم» ⟶ «البيانات المرجعية» ⟶ «المصادر». **ثم نفّذ الأمر التالي:**
```bash
& "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell screencap -p /sdcard/qtms_shot.png; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" pull /sdcard/qtms_shot.png "E:\Projects\qtms\ux_review_package\screenshots\sources_screen.png"; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell rm /sdcard/qtms_shot.png
```

### 18. ورقةُ نموذج المصدر — `source_form_sheet.png`
**افتح هذه الشاشة يدوياً على المحاكي:** في «المصادر» انقر الزرَّ العائم «مصدر جديد». **ثم نفّذ الأمر التالي:**
```bash
& "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell screencap -p /sdcard/qtms_shot.png; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" pull /sdcard/qtms_shot.png "E:\Projects\qtms\ux_review_package\screenshots\source_form_sheet.png"; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell rm /sdcard/qtms_shot.png
```

### 19. الرعية — `suppliers_screen.png`
**افتح هذه الشاشة يدوياً على المحاكي:** «لوحة اليوم» ⟶ «البيانات المرجعية» ⟶ «الرعية». **ثم نفّذ الأمر التالي:**
```bash
& "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell screencap -p /sdcard/qtms_shot.png; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" pull /sdcard/qtms_shot.png "E:\Projects\qtms\ux_review_package\screenshots\suppliers_screen.png"; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell rm /sdcard/qtms_shot.png
```

### 20. ورقةُ نموذج الرعوي — `supplier_form_sheet.png`
**افتح هذه الشاشة يدوياً على المحاكي:** في «الرعية» انقر الزرَّ العائم «رعوي جديد» — ★ **وتحقّق هل يظهر زرُّ «جلب من جهات الاتصال» أعلى الورقة.** **ثم نفّذ الأمر التالي:**
```bash
& "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell screencap -p /sdcard/qtms_shot.png; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" pull /sdcard/qtms_shot.png "E:\Projects\qtms\ux_review_package\screenshots\supplier_form_sheet.png"; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell rm /sdcard/qtms_shot.png
```

### 21. المقاوته — `dealers_screen.png`
**افتح هذه الشاشة يدوياً على المحاكي:** «لوحة اليوم» ⟶ «البيانات المرجعية» ⟶ «المقاوته». **ثم نفّذ الأمر التالي:**
```bash
& "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell screencap -p /sdcard/qtms_shot.png; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" pull /sdcard/qtms_shot.png "E:\Projects\qtms\ux_review_package\screenshots\dealers_screen.png"; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell rm /sdcard/qtms_shot.png
```

### 22. ورقةُ نموذج المقوت — `dealer_form_sheet.png`
**افتح هذه الشاشة يدوياً على المحاكي:** في «المقاوته» انقر **تعديلَ** مقوتٍ قائم **ثم أطفئ مفتاح «المقوت نشط»** ⟵ فيظهر حقلا «سبب التعطيل» و«إقرار التعطيل رغم الرصيد» — **وهما موضعُ المراجعة الأهمّ.** **ثم نفّذ الأمر التالي:**
```bash
& "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell screencap -p /sdcard/qtms_shot.png; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" pull /sdcard/qtms_shot.png "E:\Projects\qtms\ux_review_package\screenshots\dealer_form_sheet.png"; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell rm /sdcard/qtms_shot.png
```

### 23. الأنواع — `items_screen.png`
**افتح هذه الشاشة يدوياً على المحاكي:** «لوحة اليوم» ⟶ «البيانات المرجعية» ⟶ «الأنواع» — ★ **وتحقّق من ظهور وسم «افتراضي» على نوع «السكرب» وغيابِ زرِّ تعديله.** **ثم نفّذ الأمر التالي:**
```bash
& "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell screencap -p /sdcard/qtms_shot.png; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" pull /sdcard/qtms_shot.png "E:\Projects\qtms\ux_review_package\screenshots\items_screen.png"; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell rm /sdcard/qtms_shot.png
```

### 24. ورقةُ نموذج النوع — `item_form_sheet.png`
**افتح هذه الشاشة يدوياً على المحاكي:** في «الأنواع» انقر الزرَّ العائم «نوع جديد» **ثم اختر الطبيعة «وزني»** ⟵ فيظهر حقلُ «وزن الحبة بالجرام». **ثم نفّذ الأمر التالي:**
```bash
& "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell screencap -p /sdcard/qtms_shot.png; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" pull /sdcard/qtms_shot.png "E:\Projects\qtms\ux_review_package\screenshots\item_form_sheet.png"; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell rm /sdcard/qtms_shot.png
```

---

## و. المخزون (١١ لقطة)

### 25. التوريد مخزني — تبويبُ «الوارد عدداً» — `supply_intake_counted_tab.png`
**افتح هذه الشاشة يدوياً على المحاكي:** «لوحة اليوم» ⟶ «العمليات اليومية» ⟶ «التوريد مخزني» (التبويبُ الأول افتراضياً). **ثم نفّذ الأمر التالي:**
```bash
& "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell screencap -p /sdcard/qtms_shot.png; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" pull /sdcard/qtms_shot.png "E:\Projects\qtms\ux_review_package\screenshots\supply_intake_counted_tab.png"; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell rm /sdcard/qtms_shot.png
```

### 26. التوريد مخزني — تبويبُ «الوارد جواني» — `supply_intake_sack_tab.png`
**افتح هذه الشاشة يدوياً على المحاكي:** في الشاشة نفسِها انقر تبويبَ «الوارد جواني» — ★ **ولاحظ أن الزرَّ العائم يتغيّر إلى «جونية جديدة».** **ثم نفّذ الأمر التالي:**
```bash
& "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell screencap -p /sdcard/qtms_shot.png; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" pull /sdcard/qtms_shot.png "E:\Projects\qtms\ux_review_package\screenshots\supply_intake_sack_tab.png"; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell rm /sdcard/qtms_shot.png
```

### 27. ورقةُ «وارد عدداً» — `counted_intake_form_sheet.png`
**افتح هذه الشاشة يدوياً على المحاكي:** في تبويب «الوارد عدداً» انقر «وارد جديد» **ثم أضف سطرَ نوعٍ واحداً** ⟵ فيظهر منسدلُ النوع وحقلُ العدد. **ثم نفّذ الأمر التالي:**
```bash
& "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell screencap -p /sdcard/qtms_shot.png; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" pull /sdcard/qtms_shot.png "E:\Projects\qtms\ux_review_package\screenshots\counted_intake_form_sheet.png"; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell rm /sdcard/qtms_shot.png
```

### 28. ورقةُ رأس الجونية — `sack_header_form_sheet.png`
**افتح هذه الشاشة يدوياً على المحاكي:** في تبويب «الوارد جواني» انقر «جونية جديدة» **ثم اكتب وزناً كلياً** ⟵ فيتحدّث الملخّصُ الحيُّ «الوزن المطالب به» لحظياً. **ثم نفّذ الأمر التالي:**
```bash
& "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell screencap -p /sdcard/qtms_shot.png; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" pull /sdcard/qtms_shot.png "E:\Projects\qtms\ux_review_package\screenshots\sack_header_form_sheet.png"; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell rm /sdcard/qtms_shot.png
```

### 29. ورقةُ أنواع الجونية — `sack_lines_form_sheet.png` **⚠️ تحتاج بيانات**
**افتح هذه الشاشة يدوياً على المحاكي:** على بطاقةِ جونيةٍ قائمة انقر «الأنواع» — ★ **وهي أغنى ورقةٍ في التطبيق: شريطُ تقدّمٍ + وسمُ حالة الوزن + زرُّ «تأكيد الوزن الضائع» إن كان هناك متبقٍّ.** **ثم نفّذ الأمر التالي:**
```bash
& "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell screencap -p /sdcard/qtms_shot.png; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" pull /sdcard/qtms_shot.png "E:\Projects\qtms\ux_review_package\screenshots\sack_lines_form_sheet.png"; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell rm /sdcard/qtms_shot.png
```

### 30. ورقةُ إلغاء الوارد — `cancel_intake_sheet.png` **(اختياري)**
**افتح هذه الشاشة يدوياً على المحاكي:** على بطاقةِ واردٍ قائم انقر أيقونةَ الحجب — **وهي نموذجُ `QtmsDestructiveSheet` القياسي.** **ثم نفّذ الأمر التالي:**
```bash
& "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell screencap -p /sdcard/qtms_shot.png; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" pull /sdcard/qtms_shot.png "E:\Projects\qtms\ux_review_package\screenshots\cancel_intake_sheet.png"; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell rm /sdcard/qtms_shot.png
```

### 31. مخزونُ اليوم — `today_stock_screen.png`
**افتح هذه الشاشة يدوياً على المحاكي:** «لوحة اليوم» ⟶ «العمليات اليومية» ⟶ «مخزون اليوم» **ثم اختر مصدراً** من منسدل الترويسة. **ثم نفّذ الأمر التالي:**
```bash
& "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell screencap -p /sdcard/qtms_shot.png; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" pull /sdcard/qtms_shot.png "E:\Projects\qtms\ux_review_package\screenshots\today_stock_screen.png"; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell rm /sdcard/qtms_shot.png
```

### 32. ورقةُ حركات النوع — `item_movements_sheet.png` **⚠️ تحتاج بيانات**
**افتح هذه الشاشة يدوياً على المحاكي:** في «مخزون اليوم» **انقر بطاقةَ نوعٍ** (البطاقةُ كلُّها هدفُ لمسٍ — لا زرَّ فيها). **ثم نفّذ الأمر التالي:**
```bash
& "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell screencap -p /sdcard/qtms_shot.png; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" pull /sdcard/qtms_shot.png "E:\Projects\qtms\ux_review_package\screenshots\item_movements_sheet.png"; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell rm /sdcard/qtms_shot.png
```

### 33. التسعيرُ اليومي — `daily_pricing_screen.png`
**افتح هذه الشاشة يدوياً على المحاكي:** «لوحة اليوم» ⟶ «التسعير اليومي» **ثم اختر مصدراً**. ★ **وافتح شريطَ المرشِّحات** بأيقونة `tune` في الترويسة ليظهر «الكل / تم التسعير / لم يتم». **ثم نفّذ الأمر التالي:**
```bash
& "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell screencap -p /sdcard/qtms_shot.png; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" pull /sdcard/qtms_shot.png "E:\Projects\qtms\ux_review_package\screenshots\daily_pricing_screen.png"; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell rm /sdcard/qtms_shot.png
```

### 34. الإتلاف — `disposal_screen.png`
**افتح هذه الشاشة يدوياً على المحاكي:** «لوحة اليوم» ⟶ «الإتلاف» **ثم اختر مصدراً وأضف سطرَ نوع** ⟵ فيتحدّث الملخّصُ الحيُّ أسفلَ الشاشة. **ثم نفّذ الأمر التالي:**
```bash
& "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell screencap -p /sdcard/qtms_shot.png; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" pull /sdcard/qtms_shot.png "E:\Projects\qtms\ux_review_package\screenshots\disposal_screen.png"; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell rm /sdcard/qtms_shot.png
```

### 35. الجرد — نموذجُ البدء — `stocktake_start_form.png`
**افتح هذه الشاشة يدوياً على المحاكي:** «لوحة اليوم» ⟶ «الجرد» **ثم اختر مصدراً** (وهذه هي الشاشةُ إن لم تكن هناك مسوّدةٌ مفتوحة). **ثم نفّذ الأمر التالي:**
```bash
& "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell screencap -p /sdcard/qtms_shot.png; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" pull /sdcard/qtms_shot.png "E:\Projects\qtms\ux_review_package\screenshots\stocktake_start_form.png"; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell rm /sdcard/qtms_shot.png
```

### 36. الجرد — نموذجُ العدّ — `stocktake_count_form.png` **⚠️ تحتاج بيانات**
**افتح هذه الشاشة يدوياً على المحاكي:** **ابدأ جرداً فعلياً** (اختر نوعاً ثم «بدء الجرد») ⟵ **فتتحوّل الشاشةُ تلقائياً إلى نموذج العدّ.** ★ **واكتب عدّاً فعلياً مختلفاً عن الرصيد ليظهر سطرُ «الفرق: نقص/زيادة».** **ثم نفّذ الأمر التالي:**
```bash
& "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell screencap -p /sdcard/qtms_shot.png; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" pull /sdcard/qtms_shot.png "E:\Projects\qtms\ux_review_package\screenshots\stocktake_count_form.png"; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell rm /sdcard/qtms_shot.png
```

### 37. متبقي الأيام السابقة — `aged_remainder_screen.png`
**افتح هذه الشاشة يدوياً على المحاكي:** «لوحة اليوم» ⟶ **الصفُّ الثاني «متبقي أيام سابقة»**. ⚠️ **وإن كان فارغاً فلقطةُ الحالة الفارغة الخضراء مفيدةٌ بذاتها** — التقطها كما هي. **ثم نفّذ الأمر التالي:**
```bash
& "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell screencap -p /sdcard/qtms_shot.png; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" pull /sdcard/qtms_shot.png "E:\Projects\qtms\ux_review_package\screenshots\aged_remainder_screen.png"; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell rm /sdcard/qtms_shot.png
```

---

## ز. ماليةُ الجواني (٣ لقطات)

### 38. ماليةُ الجواني — `sack_finance_screen.png`
**افتح هذه الشاشة يدوياً على المحاكي:** «لوحة اليوم» ⟶ قسم «المالية» ⟶ «مالية الجواني» **ثم اختر مصدراً**. **ثم نفّذ الأمر التالي:**
```bash
& "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell screencap -p /sdcard/qtms_shot.png; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" pull /sdcard/qtms_shot.png "E:\Projects\qtms\ux_review_package\screenshots\sack_finance_screen.png"; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell rm /sdcard/qtms_shot.png
```

### 39. ورقةُ تفكيك السعر — `sack_breakdown_sheet.png` **⚠️ تحتاج بيانات**
**افتح هذه الشاشة يدوياً على المحاكي:** في «مالية الجواني» **انقر بطاقةَ جونية** ⟵ فيظهر جدولٌ بستة أعمدة. ★ **وهو الموضعُ الأفضلُ لمعاينة `QtmsDataTable` وتحوُّلِه إلى بطاقاتٍ على الشاشات الضيّقة.** **ثم نفّذ الأمر التالي:**
```bash
& "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell screencap -p /sdcard/qtms_shot.png; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" pull /sdcard/qtms_shot.png "E:\Projects\qtms\ux_review_package\screenshots\sack_breakdown_sheet.png"; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell rm /sdcard/qtms_shot.png
```

### 40. ورقةُ ضريبة الكيلو — `sack_tax_sheet.png` **⚠️ تحتاج بيانات**
**افتح هذه الشاشة يدوياً على المحاكي:** على بطاقةِ جونيةٍ انقر «إدخال ضريبة الكيلو» **ثم اكتب قيمةً** ⟵ **فتتحدّث لافتةُ الحساب الحيّ** («ضريبة الجونية = … — على الوزن الكلي لا المطالب به»). **ثم نفّذ الأمر التالي:**
```bash
& "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell screencap -p /sdcard/qtms_shot.png; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" pull /sdcard/qtms_shot.png "E:\Projects\qtms\ux_review_package\screenshots\sack_tax_sheet.png"; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell rm /sdcard/qtms_shot.png
```

---

## ح. التوزيعُ والبيعُ النقدي (٧ لقطات)

### 41. التوزيع — `distribution_screen.png`
**افتح هذه الشاشة يدوياً على المحاكي:** «لوحة اليوم» ⟶ **«التوزيع» (الزرُّ الأساسيُّ الداكنُ الوحيد)**. **ثم نفّذ الأمر التالي:**
```bash
& "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell screencap -p /sdcard/qtms_shot.png; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" pull /sdcard/qtms_shot.png "E:\Projects\qtms\ux_review_package\screenshots\distribution_screen.png"; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell rm /sdcard/qtms_shot.png
```

### 42. ورقةُ التوزيعة — `distribution_form_sheet.png`
**افتح هذه الشاشة يدوياً على المحاكي:** انقر الزرَّ العائم «توزيعة جديدة» ⟶ **اختر مقوتاً** ⟶ **أضف سطرَ نوع** ⟵ **فيُعبَّأ السعرُ المقترَح تلقائياً** ويتحدّث الملخّصُ الحيّ. **ثم نفّذ الأمر التالي:**
```bash
& "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell screencap -p /sdcard/qtms_shot.png; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" pull /sdcard/qtms_shot.png "E:\Projects\qtms\ux_review_package\screenshots\distribution_form_sheet.png"; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell rm /sdcard/qtms_shot.png
```

### 43. ورقةُ تفاصيل التوزيعة — `distribution_details_sheet.png` **⚠️ تحتاج بيانات**
**افتح هذه الشاشة يدوياً على المحاكي:** على بطاقةِ توزيعةٍ قائمة انقر أيقونةَ **العين**. **ثم نفّذ الأمر التالي:**
```bash
& "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell screencap -p /sdcard/qtms_shot.png; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" pull /sdcard/qtms_shot.png "E:\Projects\qtms\ux_review_package\screenshots\distribution_details_sheet.png"; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell rm /sdcard/qtms_shot.png
```

### 44. ورقةُ الإرسال والتصدير — `send_document_sheet.png` **⚠️ تحتاج بيانات**
**افتح هذه الشاشة يدوياً على المحاكي:** على بطاقةِ توزيعةٍ قائمة انقر أيقونةَ **الإرسال** ⟵ فتظهر **معاينةُ نصِّ الرسالة** واختيارُ القالب وأزرارُ واتساب والرسائل والتصدير. **ثم نفّذ الأمر التالي:**
```bash
& "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell screencap -p /sdcard/qtms_shot.png; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" pull /sdcard/qtms_shot.png "E:\Projects\qtms\ux_review_package\screenshots\send_document_sheet.png"; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell rm /sdcard/qtms_shot.png
```

### 45. ورقةُ إلغاء التوزيعة — `cancel_distribution_sheet.png` **(اختياري)**
**افتح هذه الشاشة يدوياً على المحاكي:** على بطاقةِ توزيعةٍ قائمة انقر أيقونةَ الحجب الحمراء. **ثم نفّذ الأمر التالي:**
```bash
& "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell screencap -p /sdcard/qtms_shot.png; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" pull /sdcard/qtms_shot.png "E:\Projects\qtms\ux_review_package\screenshots\cancel_distribution_sheet.png"; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell rm /sdcard/qtms_shot.png
```

### 46. البيعُ النقدي — `cash_sale_screen.png`
**افتح هذه الشاشة يدوياً على المحاكي:** «لوحة اليوم» ⟶ «البيع النقدي». **ثم نفّذ الأمر التالي:**
```bash
& "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell screencap -p /sdcard/qtms_shot.png; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" pull /sdcard/qtms_shot.png "E:\Projects\qtms\ux_review_package\screenshots\cash_sale_screen.png"; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell rm /sdcard/qtms_shot.png
```

### 47. ورقةُ البيع النقدي — `cash_sale_form_sheet.png`
**افتح هذه الشاشة يدوياً على المحاكي:** انقر «بيع نقدي جديد» ⟶ أضف سطرَ نوع ⟶ ★★ **واكتب سعراً أقلَّ من الحدّ الأدنى المذكور في `helperText`** ⟵ **فيظهر `errorText` «أقل من الحد الأدنى» ويُعطَّل زرُّ الحفظ ويظهر سطرا تحذيرٍ في الملخّص** — **وهذه أهمُّ لقطةٍ في الشاشة.** **ثم نفّذ الأمر التالي:**
```bash
& "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell screencap -p /sdcard/qtms_shot.png; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" pull /sdcard/qtms_shot.png "E:\Projects\qtms\ux_review_package\screenshots\cash_sale_form_sheet.png"; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell rm /sdcard/qtms_shot.png
```

---

## ط. الذممُ والنقد (٥ لقطات)

### 48. المقبوضات — `receipt_screen.png` **⚠️ تحتاج بيانات**
**افتح هذه الشاشة يدوياً على المحاكي:** «لوحة اليوم» ⟶ «المقبوضات» **ثم اختر مقوتاً عليه ضمارٌ مفتوح** ⟵ فتظهر صفوفُ «المتبقي / الواصل / بعده» وزرُّ «توزيع تلقائي». **ثم نفّذ الأمر التالي:**
```bash
& "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell screencap -p /sdcard/qtms_shot.png; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" pull /sdcard/qtms_shot.png "E:\Projects\qtms\ux_review_package\screenshots\receipt_screen.png"; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell rm /sdcard/qtms_shot.png
```

### 49. المقبوضات بعد الحفظ — `receipt_screen_filled.png` **(اختياري · ⚠️ تحتاج بيانات)**
**افتح هذه الشاشة يدوياً على المحاكي:** **احفظ سندَ قبضٍ فعلياً** ⟵ **فيظهر زرُّ «إرسال أو تصدير»** أسفل النموذج (وهو لا يظهر قبل الحفظ إطلاقاً). **ثم نفّذ الأمر التالي:**
```bash
& "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell screencap -p /sdcard/qtms_shot.png; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" pull /sdcard/qtms_shot.png "E:\Projects\qtms\ux_review_package\screenshots\receipt_screen_filled.png"; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell rm /sdcard/qtms_shot.png
```

### 50. الخصومات — `discount_screen.png` **⚠️ تحتاج بيانات**
**افتح هذه الشاشة يدوياً على المحاكي:** «لوحة اليوم» ⟶ «الخصومات» **ثم اختر مقوتاً عليه ضمارٌ مفتوح** — ★ **ولاحظ الفرقَ عن «المقبوضات»: تسميةُ الحقل «الخصم» وحقلُ «مبلغ للتوزيع التلقائي» المستقلّ.** **ثم نفّذ الأمر التالي:**
```bash
& "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell screencap -p /sdcard/qtms_shot.png; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" pull /sdcard/qtms_shot.png "E:\Projects\qtms\ux_review_package\screenshots\discount_screen.png"; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell rm /sdcard/qtms_shot.png
```

### 51. كشفُ حساب المقوت — تبويبُ «بالضمارات» — `dealer_statement_lots_tab.png`
**افتح هذه الشاشة يدوياً على المحاكي:** «لوحة اليوم» ⟶ «كشف حساب المقوت» **ثم اختر مقوتاً**. **ثم نفّذ الأمر التالي:**
```bash
& "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell screencap -p /sdcard/qtms_shot.png; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" pull /sdcard/qtms_shot.png "E:\Projects\qtms\ux_review_package\screenshots\dealer_statement_lots_tab.png"; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell rm /sdcard/qtms_shot.png
```

### 52. كشفُ حساب المقوت — تبويبُ «بالحركات» — `dealer_statement_entries_tab.png`
**افتح هذه الشاشة يدوياً على المحاكي:** في الشاشة نفسِها انقر تبويبَ «بالحركات» — ★ **ومرِّر لأسفل حتى تظهر بطاقةُ الإجماليات.** **ثم نفّذ الأمر التالي:**
```bash
& "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell screencap -p /sdcard/qtms_shot.png; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" pull /sdcard/qtms_shot.png "E:\Projects\qtms\ux_review_package\screenshots\dealer_statement_entries_tab.png"; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell rm /sdcard/qtms_shot.png
```

---

## ي. السحبياتُ وضمارُ المالك (٣ لقطات)

### 53. السحبياتُ والخرجيات — `outflow_screen.png`
**افتح هذه الشاشة يدوياً على المحاكي:** «لوحة اليوم» ⟶ «السحبيات والخرجيات» ⟶ **اختر مصدراً** ⟶ **أضف بندَ قاتٍ وبندَ مبلغٍ معاً** ⟵ فيظهر الإجماليّان في الملخّص. ★ **وتحقّق من نصِّ `helperText` على حقل «سعر الوحدة».** **ثم نفّذ الأمر التالي:**
```bash
& "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell screencap -p /sdcard/qtms_shot.png; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" pull /sdcard/qtms_shot.png "E:\Projects\qtms\ux_review_package\screenshots\outflow_screen.png"; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell rm /sdcard/qtms_shot.png
```

### 54. ضمارُ المالك — `owner_ledger_screen.png`
**افتح هذه الشاشة يدوياً على المحاكي:** «لوحة اليوم» ⟶ «ضمار المالك». ★★ **وهذه أهمُّ لقطةٍ في الحزمة كلِّها** — فهي الموضعُ الوحيد للبطاقة الرئيسية (`hero`) وخطِّ Tajawal والرِباطِ الداكن ورمزِ العملية أمام كل بند. **مرِّر ببطءٍ ليظهر:** البطاقةُ الرئيسية ⟶ رسمُ الاتجاه ⟶ بطاقةُ حركة النقد ⟶ زرُّ سجل الأيام. **وإن لم تتسع الشاشةُ لها كلِّها فالتقط لقطتين وسمِّ الثانية `owner_ledger_screen_2.png`.** **ثم نفّذ الأمر التالي:**
```bash
& "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell screencap -p /sdcard/qtms_shot.png; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" pull /sdcard/qtms_shot.png "E:\Projects\qtms\ux_review_package\screenshots\owner_ledger_screen.png"; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell rm /sdcard/qtms_shot.png
```

### 55. سجلُّ الأيام السابقة — `owner_ledger_history_screen.png`
**افتح هذه الشاشة يدوياً على المحاكي:** في «ضمار المالك» **اختر مصدراً بعينه** (لا «كل المصادر») ⟵ **فيظهر زرُّ «سجل الأيام السابقة»** بدلاً من اللافتة الزرقاء — انقره. **ثم نفّذ الأمر التالي:**
```bash
& "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell screencap -p /sdcard/qtms_shot.png; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" pull /sdcard/qtms_shot.png "E:\Projects\qtms\ux_review_package\screenshots\owner_ledger_history_screen.png"; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell rm /sdcard/qtms_shot.png
```

---

## ك. الرقابةُ والتقارير (٥ لقطات)

### 56. الإدخالاتُ المعلّقة — `pending_entries_screen.png`
**افتح هذه الشاشة يدوياً على المحاكي:** «لوحة اليوم» ⟶ **الصفُّ الأول «الإدخالات المعلّقة»**. ⚠️ **وإن كان فارغاً فلقطةُ الحالة الفارغة الخضراء مفيدةٌ بذاتها.** **ثم نفّذ الأمر التالي:**
```bash
& "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell screencap -p /sdcard/qtms_shot.png; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" pull /sdcard/qtms_shot.png "E:\Projects\qtms\ux_review_package\screenshots\pending_entries_screen.png"; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell rm /sdcard/qtms_shot.png
```

### 57. سجلُّ التدقيق — `audit_log_screen.png`
**افتح هذه الشاشة يدوياً على المحاكي:** «لوحة اليوم» ⟶ قسم «الرقابة» ⟶ «سجل التدقيق». ★ **ومرِّر حتى تظهر بطاقةٌ فيها جدولُ «قبل ⟶ بعد»** إن وُجدت. **ثم نفّذ الأمر التالي:**
```bash
& "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell screencap -p /sdcard/qtms_shot.png; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" pull /sdcard/qtms_shot.png "E:\Projects\qtms\ux_review_package\screenshots\audit_log_screen.png"; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell rm /sdcard/qtms_shot.png
```

### 58. ورقةُ سجل الكيان — `audit_trail_sheet.png`
**افتح هذه الشاشة يدوياً على المحاكي:** في أي شاشةٍ فيها بطاقاتُ كياناتٍ (المستخدمون · المصادر · الأنواع …) انقر **أيقونةَ الساعة `history`** في بداية البطاقة. **ثم نفّذ الأمر التالي:**
```bash
& "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell screencap -p /sdcard/qtms_shot.png; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" pull /sdcard/qtms_shot.png "E:\Projects\qtms\ux_review_package\screenshots\audit_trail_sheet.png"; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell rm /sdcard/qtms_shot.png
```

### 59. فهرسُ التقارير — `reports_screen.png`
**افتح هذه الشاشة يدوياً على المحاكي:** «لوحة اليوم» ⟶ «الرقابة» ⟶ «التقارير». **ثم نفّذ الأمر التالي:**
```bash
& "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell screencap -p /sdcard/qtms_shot.png; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" pull /sdcard/qtms_shot.png "E:\Projects\qtms\ux_review_package\screenshots\reports_screen.png"; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell rm /sdcard/qtms_shot.png
```

### 60. عارضُ التقرير — `report_view_screen.png`
**افتح هذه الشاشة يدوياً على المحاكي:** في الفهرس انقر تقريراً **يكفيه المصدرُ والفترة** (مثلاً «المخزون الحالي» أو «المبيعات النقدية») ⟵ فيُبنى الجدولُ فوراً. **ثم نفّذ الأمر التالي:**
```bash
& "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell screencap -p /sdcard/qtms_shot.png; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" pull /sdcard/qtms_shot.png "E:\Projects\qtms\ux_review_package\screenshots\report_view_screen.png"; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell rm /sdcard/qtms_shot.png
```

### 61. عارضُ التقرير — حالةُ المرشِّح الناقص — `report_view_needs_filter.png` **(اختياري)**
**افتح هذه الشاشة يدوياً على المحاكي:** في الفهرس انقر **«حركة النوع»** أو **«تفكيك سعر الجونية»** ⟵ **فتظهر حالةُ «اختر ما يلزم لبناء التقرير» برسالةٍ تقول أيَّ مرشِّحٍ ناقص** — وهي أدقُّ حالةِ فراغٍ في التطبيق. **ثم نفّذ الأمر التالي:**
```bash
& "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell screencap -p /sdcard/qtms_shot.png; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" pull /sdcard/qtms_shot.png "E:\Projects\qtms\ux_review_package\screenshots\report_view_needs_filter.png"; & "C:\Users\Abdulfatah\AppData\Local\Android\Sdk\platform-tools\adb.exe" shell rm /sdcard/qtms_shot.png
```

---

## بعد الانتهاء

### 1. تحقّقٌ سريعٌ من اللقطات
```bash
Get-ChildItem "E:\Projects\qtms\ux_review_package\screenshots\*.png" | Select-Object Name, Length | Format-Table -AutoSize
```
⚠️ **وأيُّ ملفٍّ حجمُه صفرٌ أو أقلُّ من 10 كيلوبايت فاشلٌ** — أعد التقاطه.

### 2. احذف هذا الملفَّ بنفسك
```bash
Remove-Item "E:\Projects\qtms\ux_review_screenshot_instructions.md"
```

### 3. اضغط الحزمة بنفسك
```bash
Compress-Archive -Path "E:\Projects\qtms\ux_review_package\*" -DestinationPath "E:\Projects\qtms\ux_review_package.zip" -Force
```

---

## جدولُ التحقّق — ٦١ لقطة

| # | اسمُ الملف | الحال |
|:-:|---|:-:|
| 1 | `splash_screen.png` | ☐ |
| 2 | `login_screen.png` | ☐ |
| 3 | `session_blocked_screen.png` *(اختياري)* | ☐ |
| 4 | `home_shell.png` | ☐ |
| 5 | `session_sheet.png` | ☐ |
| 6 | `profile_screen.png` | ☐ |
| 7 | `profile_password_prompt_sheet.png` | ☐ |
| 8 | `settings_screen.png` | ☐ |
| 9 | `about_screen.png` | ☐ |
| 10 | `first_run_setup_screen.png` *(اختياري)* | ☐ |
| 11 | `users_screen.png` | ☐ |
| 12 | `user_form_sheet.png` | ☐ |
| 13 | `user_disable_sheet.png` *(اختياري)* | ☐ |
| 14 | `permissions_screen.png` | ☐ |
| 15 | `roles_screen.png` | ☐ |
| 16 | `role_form_sheet.png` | ☐ |
| 17 | `sources_screen.png` | ☐ |
| 18 | `source_form_sheet.png` | ☐ |
| 19 | `suppliers_screen.png` | ☐ |
| 20 | `supplier_form_sheet.png` | ☐ |
| 21 | `dealers_screen.png` | ☐ |
| 22 | `dealer_form_sheet.png` | ☐ |
| 23 | `items_screen.png` | ☐ |
| 24 | `item_form_sheet.png` | ☐ |
| 25 | `supply_intake_counted_tab.png` | ☐ |
| 26 | `supply_intake_sack_tab.png` | ☐ |
| 27 | `counted_intake_form_sheet.png` | ☐ |
| 28 | `sack_header_form_sheet.png` | ☐ |
| 29 | `sack_lines_form_sheet.png` ⚠️ | ☐ |
| 30 | `cancel_intake_sheet.png` *(اختياري)* | ☐ |
| 31 | `today_stock_screen.png` | ☐ |
| 32 | `item_movements_sheet.png` ⚠️ | ☐ |
| 33 | `daily_pricing_screen.png` | ☐ |
| 34 | `disposal_screen.png` | ☐ |
| 35 | `stocktake_start_form.png` | ☐ |
| 36 | `stocktake_count_form.png` ⚠️ | ☐ |
| 37 | `aged_remainder_screen.png` | ☐ |
| 38 | `sack_finance_screen.png` | ☐ |
| 39 | `sack_breakdown_sheet.png` ⚠️ | ☐ |
| 40 | `sack_tax_sheet.png` ⚠️ | ☐ |
| 41 | `distribution_screen.png` | ☐ |
| 42 | `distribution_form_sheet.png` | ☐ |
| 43 | `distribution_details_sheet.png` ⚠️ | ☐ |
| 44 | `send_document_sheet.png` ⚠️ | ☐ |
| 45 | `cancel_distribution_sheet.png` *(اختياري)* | ☐ |
| 46 | `cash_sale_screen.png` | ☐ |
| 47 | `cash_sale_form_sheet.png` **★ الأهمّ** | ☐ |
| 48 | `receipt_screen.png` ⚠️ | ☐ |
| 49 | `receipt_screen_filled.png` *(اختياري)* | ☐ |
| 50 | `discount_screen.png` ⚠️ | ☐ |
| 51 | `dealer_statement_lots_tab.png` | ☐ |
| 52 | `dealer_statement_entries_tab.png` | ☐ |
| 53 | `outflow_screen.png` | ☐ |
| 54 | `owner_ledger_screen.png` **★★ الأهمّ** | ☐ |
| 55 | `owner_ledger_history_screen.png` | ☐ |
| 56 | `pending_entries_screen.png` | ☐ |
| 57 | `audit_log_screen.png` | ☐ |
| 58 | `audit_trail_sheet.png` | ☐ |
| 59 | `reports_screen.png` | ☐ |
| 60 | `report_view_screen.png` | ☐ |
| 61 | `report_view_needs_filter.png` *(اختياري)* | ☐ |

**الإلزاميُّ منها: ٥٣ · والاختياريُّ: ٨.**

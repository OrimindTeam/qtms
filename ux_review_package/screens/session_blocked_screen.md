# شاشة الحساب المعطَّل

| البند | القيمة |
|---|---|
| **اسم الكلاس** | `SessionBlockedScreen` (`ConsumerWidget`) |
| **مسار الملف** | `lib/capabilities/identity_access/presentation/session_blocked_screen.dart` |
| **المسار الملاحي** | `/blocked` — `blockedRoute` |
| **اسم اللقطة المتوقّع** | `session_blocked_screen.png` |

## الغرض
مخرَجٌ واحدٌ لمستخدمٍ مصادَقٍ لكن حسابه معطَّل (`SessionRejected`). تقول السبب من كتالوج الرسائل وتُتيح الخروج وحده — ⛔ **ولا شريط علوي فيها** (شاشة ما قبل الجلسة العاملة)، ⛔ **ولا مدخلَ عملٍ واحد.**

## العناصر

| # | الـ Widget class الفعلي | الحجم / اللون / الخط / المسافات | الظهور والتفاعل |
|:-:|---|---|---|
| 1 | `Scaffold` > `SafeArea` > `Center` > `Padding` | `EdgeInsets.all(Spacing.space24)` = 24 | جذر مُوسَّط — ⛔ بلا `appBar`. |
| 2 | `Column` | `mainAxisSize: MainAxisSize.min` | |
| 3 | `Icon` | `Icons.lock_outline` · `size: Sizes.iconBox = 48` · `color: SemanticTriads.danger.ink` = `#9E3F27` | رمز الإغلاق. |
| 4 | `SizedBox` | 16 | |
| 5 | `Text` | نصُّه `catalogText(CatalogMessage.accountDisabled)` — **من الكتالوج لا مُصاغٌ في الشاشة** · `TypeScale.bodyLg` (15px · w400 · height 1.6) · `textPrimary` · `textAlign: center` | الرسالة الوحيدة. |
| 6 | `SizedBox` | 24 | |
| 7 | `FilledButton` «تسجيل الخروج» | ارتفاع 52 · سطح `surfaceInverse` (`#26301A`) · حبر `textOnInverse` | الإجراء الوحيد. يستدعي `authRepositoryProvider.signOut()` مباشرةً ⟶ فيُخرِج الموجّهُ الشاشةَ إلى `/login`. ⛔ **بلا تأكيد** — لا شيء يُفقَد. |

## شجرة الـ Widget tree
```
Scaffold (بلا appBar)
└── SafeArea
    └── Center
        └── Padding (24)
            └── Column (min)
                ├── Icon (lock_outline · 48 · danger.ink)
                ├── SizedBox (16)
                ├── Text (accountDisabled · bodyLg · center)
                ├── SizedBox (24)
                └── FilledButton («تسجيل الخروج»)
```

## الحالات المُعالجة
| الحالة | الوضع |
|---|---|
| Loading | لا ينطبق — الشاشة ثابتة بلا قراءة بيانات. |
| Error | لا ينطبق — لا استعلام فيها. ⚠️ **وفشلُ `signOut()` نفسه غير مُعالَج:** لا مؤشّر انتظار على الزرّ ولا رسالة عند التعذُّر. |
| Empty | لا ينطبق. |

## آلية التنقل
- **الدخول إليها:** توجيه مركزي من `_redirect` وحده عند `SessionRejected` — من أي مسار.
- **الخروج منها:** `signOut()` ⟶ `SessionSignedOut` ⟶ الموجّه يُحوِّل إلى `/login`. ⛔ **ولا مخرجَ آخر** — وزرُّ الرجوع لا يُفلِت منها لأن التوجيه يُعيدها.

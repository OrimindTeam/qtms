# المستخدمون

| البند | القيمة |
|---|---|
| **اسم الكلاس** | `UsersScreen` (`ConsumerWidget`) |
| **مسار الملف** | `lib/capabilities/identity_access/presentation/users_screen.dart` |
| **المسار الملاحي** | `/home/users` — `usersRoute` |
| **اسم الشاشة في الشريط** | «المستخدمون» |
| **اسم اللقطة المتوقّع** | `users_screen.png` · وللورقتين: `user_form_sheet.png` و`user_disable_sheet.png` |

## الغرض
قائمة المستخدمين وإدارتهم: إنشاء · تعديل · تخصيص صلاحيات · تعطيل. ⛔ **ولا حذف مستخدم إطلاقاً** (الحذف ممنوع في كل السجلات) — التعطيل بديلُه. وكل إجراء محروسٌ بمفتاحه، **ولا يُعطِّل المستخدمُ نفسَه ولا يُخصِّص صلاحيات حسابه**.

## العناصر

| # | الـ Widget class الفعلي | الحجم / اللون / الخط / المسافات | الظهور والتفاعل |
|:-:|---|---|---|
| 1 | `Scaffold` + `QtmsTopBar` | `screenTitle: 'المستخدمون'` | |
| 2 | `FloatingActionButton.extended` — «مستخدم جديد» | `Icons.person_add_alt` · خلفية `surfaceInverse` داكنة · `elevation: 0` في كل الحالات · `Radii.field = 14` · **أيقونة ونصّ معاً** ⛔ لا أيقونة صامتة | مُغلَّف بـ`PermissionGate(userCreate)` فيغيب كلياً عمّن لا يملكه. **Trigger** لورقة النموذج. |
| 3 | `EntityList` > `ListView.separated` | حشو أفقي `Breakpoints.gutter(width)` (12 دون 360 · 16 · 24 فوق 600) · حشو سفلي `Spacing.fabSafeBottom = 96` (فلا تختفي آخر بطاقة خلف الزر العائم) · فاصل `Spacing.cardGap = 12` | القائمة. ⛔ **بلا `RefreshIndicator`** هنا (`onRefresh` غير مُمرَّر). |
| 4 | `EntityTile` | سطح `surface` · حدّ `border` 1px · `Radii.card = 20` · حشو 16 · `minHeight: 56` · `clipBehavior: antiAlias` | بطاقة المستخدم. `actionsPlacement: EntityActionsPlacement.subtitleRow` ⟵ **الأزرار في سطر النصّ الثانوي لا في صفٍّ سفلي مستقل.** |
| 5 | `Text` — العنوان | `TypeScale.titleSm` (15 · w600) | صيغته `«الاسم : الدور»` — وعند غياب الدور `«الاسم : بلا دور»`. |
| 6 | `Text` — الثانوي | `TypeScale.bodyMd` · `textSecondary` · `maxLines: 1` + `ellipsis` | البريد، أو «بلا بريد». |
| 7 | `QtmsAvatar` (في `leading`) | `Sizes.avatarSm = 36` · ثلاثية تصنيفية مشتقّة من الاسم | |
| 8 | `StatusPill` «أنت» | `triad: SemanticTriads.info` (`#EAEEF2` / `#CBD6DE` / `#3A4E5B`) · `Radii.pill` · `TypeScale.label` | **شرطي:** على بطاقة المستخدم الحالي. |
| 9 | `StatusPill` «معطَّل» | `triad: SemanticTriads.danger` | **شرطي:** عندما `!user.isActive`. |
| 10 | `IconButton` — سجل التدقيق | من `auditTrailLeading(...)` · هدف لمس 48×48 من الثيم | **شرطي:** يظهر لمن يملك مفتاح عرض سجل الكيان. يفتح عرض أثر التدقيق للمستخدم. |
| 11 | `IconButton` — تعديل | `Icons.edit_outlined` · `tooltip: 'تعديل المستخدم'` | `PermissionGate(userAmend)`. **Trigger** لورقة النموذج بوضع التعديل. |
| 12 | `IconButton` — الصلاحيات | `Icons.key_outlined` · `tooltip: 'تخصيص الصلاحيات'` | `PermissionGate(permissionGrant)` **وشرط `!isSelf`**. ⟶ `/home/users/{userId}/permissions`. |
| 13 | `_DisableButton` > `IconButton` | `Icons.block` · `tooltip: 'تعطيل المستخدم'` | `PermissionGate(userDisable)` **وشرطا `!isSelf && user.isActive`**. **Trigger** لورقة التعطيل. |
| 14 | `showQtmsDestructiveSheet` (من `user_disable_sheet.dart`) | ورقة سفلية · العنوان `titleLg` · زرُّ التأكيد `FilledButton.icon` بخلفية `SemanticTriads.danger.ink` وأيقونة `warning_amber_outlined` · وتحته `TextButton` «تراجع» | **Trigger:** زرُّ ⑬. العنوان «تعطيل المستخدم» · نصُّ الأثر يذكر الاسم صراحةً («سيُمنع «X» من الدخول فوراً، وتبقى حركاته وقيوده كما هي») · **حقل «سبب التعطيل» إلزامي** (`requiredFieldLabel`) بـ`autofocus` — والزرُّ معطَّل ما لم يُكتب · ⛔ **و`reasonLabel: null`** فلا حقلَ سببٍ اختياريٍّ ثانٍ. |
| 15 | `showUserForm` > `showModalBottomSheet` > `UserFormSheet` | `isScrollControlled: true` · حشو سفلي `viewInsets.bottom` · جسمها `SingleChildScrollView` بحشو 16 | **Trigger:** الزرُّ العائم ② (إنشاء) أو زرُّ التعديل ⑪. تفاصيلها أدناه. |
| 16 | `ScaffoldMessenger` > `SnackBar` | خلفية `surfaceInverse` · `behavior: floating` · `Radii.field` | يظهر **لفشل التعطيل وحده** — بنصٍّ من كتالوج الأخطاء. |

### ورقة نموذج المستخدم — `UserFormSheet`

| # | الـ Widget class | التفاصيل |
|:-:|---|---|
| أ | `Text` | «مستخدم جديد» أو «تعديل مستخدم» — `TypeScale.titleLg`. |
| ب | `TextField` «الاسم» | `autofocus: true`. |
| ج | `TextField` «البريد الإلكتروني» | |
| د | `TextField` «الهاتف (اختياري)» | |
| هـ | `DropdownButtonFormField<String?>` «الدور» | `isExpanded: true` · أول بند «بلا دور» (بقيمة `null`) ثم كل الأدوار · النصّ بـ`ellipsis`. **منسدل من مكانه** لا حوار. |
| و | `TextField` «كلمة المرور الأولية» + «تأكيد كلمة المرور» | **إنشاءً فقط.** الأول يحمل `suffixIcon: IconButton` لإظهار/إخفاء **يبدّل الحقلين معاً**. |
| ز | `TextField` «سبب التعديل (اختياري)» | **تعديلاً فقط.** فارغُه يُقرأ غياباً لا نصّاً فارغاً (`blankToNull`). |
| ح | `QtmsInlineBanner` (`danger`) | **شرطي:** رفضٌ بنصٍّ من الكتالوج. |
| ط | `FilledButton` | «إنشاء» أو «حفظ التعديل» — معطَّل أثناء الإرسال. |
| ي | `Text` تذييلي | **إنشاءً فقط:** «ثمانية محارف على الأقل. يبلّغها المديرُ صاحبَها، وله تغييرها متى شاء.» — `bodyMd` · `textSecondary` · `center`. |

## شجرة الـ Widget tree
```
Scaffold
├── appBar: QtmsTopBar («المستخدمون»)
├── floatingActionButton: PermissionGate(userCreate) → FloatingActionButton.extended
└── body: switch (usersProvider)
    ├── hasError  → _ErrorState → QtmsErrorState (رسالة + «تفاصيل تقنية» قابلة للطيّ)
    ├── data []   → _EmptyState → QtmsEmptyState (أيقونة group_outlined بثلاثية identity)
    ├── data [..] → _UsersList → EntityList → ListView.separated
    │                └── EntityTile (لكل مستخدم)
    │                    ├── leading: QtmsAvatar (36)
    │                    ├── title: Text «الاسم : الدور»
    │                    ├── subtitleRow: Text (البريد) + الأزرار
    │                    │   ├── [شرطي] IconButton (سجل التدقيق)
    │                    │   ├── PermissionGate(userAmend)      → IconButton (edit_outlined)
    │                    │   ├── PermissionGate(permissionGrant)→ IconButton (key_outlined)
    │                    │   └── PermissionGate(userDisable)    → _DisableButton (block)
    │                    └── badges: [StatusPill «أنت»] [StatusPill «معطَّل»]
    └── loading   → SkeletonList (4 × SkeletonTile بوميض 1200ms)
```

## الحالات المُعالجة
| الحالة | الوضع |
|---|---|
| Loading | ✅ `SkeletonList` — أربع بطاقات هيكلية بوميض `Motion.shimmer` = 1200ms، **يتوقّف كلياً** عند تفعيل «تقليل الحركة» (لا يُبطَّأ). |
| Error | ✅ `QtmsErrorState` — يُميّز `permission-denied` عن الفشل العام برسالتين مختلفتين من الكتالوج، وأيقونة `error_outline` بثلاثية `danger` في `IconBadgeBox` 64، وزرّ «تفاصيل تقنية» يطوي/يفتح النصّ الخام بـ`AnimatedCrossFade`. ⚠️ **بلا زرّ «إعادة المحاولة»** — `onRetry` غير مُمرَّر هنا. |
| Empty | ✅ `QtmsEmptyState` — «لا يوجد مستخدمون بعد» + «أضف أول مستخدم ليتمكّن من الدخول والعمل ضمن نطاق مصادره». ⚠️ **بلا زرّ إجراء داخل الحالة الفارغة** — الزرُّ العائم هو المدخل. |

## آلية التنقل
- **الدخول إليها:** «لوحة اليوم» ⟶ قسم «الهوية والصلاحيات» ⟶ «إدارة المستخدمين» (بمفتاح `userView`).
- **الخروج منها:** ⟶ `/home/users/{userId}/permissions` (زرّ المفتاح) · والرجوع بزرّ النظام.

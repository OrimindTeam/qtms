# الأدوار

| البند | القيمة |
|---|---|
| **اسم الكلاس** | `RolesScreen` (`ConsumerWidget`) |
| **مسار الملف** | `lib/capabilities/identity_access/presentation/roles_screen.dart` |
| **المسار الملاحي** | `/home/roles` — `rolesRoute` |
| **اسم الشاشة في الشريط** | «الأدوار» |
| **اسم اللقطة المتوقّع** | `roles_screen.png` · وللورقتين: `role_form_sheet.png` و`role_delete_sheet.png` |

## الغرض
قوالبُ صلاحيات تُمنَح دفعةً واحدة بدل منحها مفتاحاً مفتاحاً لكل مستخدم. وهي **الاستثناء الوحيد المعتمد لقاعدة منع الحذف** — ويشترط أن يكون الدور **غير مُسنَد** لأي مستخدم، ويُقاس ذلك باستعلام فعلي (`assignedRoleIdsProvider`).

## العناصر

| # | الـ Widget class الفعلي | الحجم / اللون / الخط / المسافات | الظهور والتفاعل |
|:-:|---|---|---|
| 1 | `Scaffold` + `QtmsTopBar` | `screenTitle: 'الأدوار'` | |
| 2 | `FloatingActionButton.extended` — «دور جديد» | `Icons.add` · خلفية `surfaceInverse` · `elevation: 0` | `PermissionGate(roleWrite)`. **Trigger** لورقة النموذج. |
| 3 | `EntityList` > `ListView.separated` | حشو أفقي متجاوب · سفلي 96 · فاصل 12 | |
| 4 | `EntityTile` | سطح `surface` · حدّ 1px · `Radii.card = 20` · حشو 16 | **`actionsPlacement` افتراضي = `stacked`** ⟵ **الأزرار في صفٍّ سفليٍّ مستقلٍّ بارتفاع 48 يسبقه `Divider`** — بخلاف شاشة المستخدمين. |
| 5 | `Text` — العنوان | `TypeScale.titleSm` | اسم الدور. |
| 6 | `Text` — الثانوي | `TypeScale.bodyMd` · `textSecondary` | الوصف، أو «بلا وصف». |
| 7 | `StatusPill` «مُسنَد» | `triad: SemanticTriads.info` | **شرطي:** عندما `RoleAssignmentView.assigned`. ⚠️ **وحالة ثالثة `unknown`** (أثناء تحميل الإسنادات) لا تُظهر الوسم ولا تُخفي زرَّ الحذف. |
| 8 | `IconButton` — تعديل | `Icons.edit_outlined` · `tooltip: 'تعديل الدور'` | `PermissionGate(roleWrite)`. **Trigger** لورقة النموذج بوضع التعديل. معطَّل أثناء `_busy`. |
| 9 | `IconButton` — حذف | `Icons.delete_outline` · `tooltip: 'حذف الدور'` | `PermissionGate(roleDelete)` **وشرط `assignment != assigned`** ⟵ **فيغيب الزرُّ عن الدور المُسنَد بنيوياً.** **Trigger** لورقة الحذف. |
| 10 | لافتة الرفض داخل `EntityTile` | تعبئة `danger.soft` · حدّ `danger.border` · أيقونة `error_outline` 16 · نصّ `bodyMd` بـ`danger.ink` | **شرطي:** رفضُ الحذف يُعرَض **داخل بطاقة الدور نفسه** لا في `SnackBar` — فيبقى مرتبطاً بمَن رفضه. |
| 11 | `showQtmsDestructiveSheet` (حذف) | العنوان «حذف الدور» · الأثر «سيُحذف الدور «X» نهائياً ولا يمكن استرجاعه.» · `confirmLabel: 'حذف الدور'` · **`reasonLabel: 'سبب الحذف (اختياري)'`** ⛔ **ولا حقل إلزامي** (`requiredFieldLabel` غائب) — فالزرُّ مُفعَّل بلا شرط | **Trigger:** زرُّ ⑨. |

### ورقة نموذج الدور — `RoleFormSheet`
**مسار الملف:** `lib/capabilities/identity_access/presentation/role_form_screen.dart`

| # | الـ Widget class | التفاصيل |
|:-:|---|---|
| أ | `showModalBottomSheet` > `ConstrainedBox` | `isScrollControlled: true` · حشو سفلي `viewInsets.bottom` · `maxHeight: MediaQuery.size.height * 0.85` — **سقفٌ صريح** لأن شجرة الصلاحيات طويلة. |
| ب | `Text` | «دور جديد» أو «تعديل دور» — `TypeScale.titleLg`. |
| ج | `Flexible` > `ListView(shrinkWrap: true)` | الجسم القابل للتمرير داخل الورقة. |
| د | `RoleField` > `TextField` «اسم الدور» | `autofocus: true`. |
| هـ | `RoleField` > `TextField` «الوصف (اختياري)» | |
| و | `RoleField` > `TextField` «سبب التعديل (اختياري)» | **تعديلاً فقط** · فارغُه يُقرأ غياباً لا نصّاً فارغاً (`blankToNull`). |
| ز | `PermissionTree` | شجرة الصلاحيات الكاملة — تفاصيلها في [`permissions_screen.md`](permissions_screen.md). هنا **بلا `grantable` وبلا `roleTemplate`** ⟵ فكلُّ المفاتيح قابلة للتأشير ولا شارات فرق. |
| ح | `RoleRejectionBanner` > `QtmsInlineBanner` (`danger`) | **شرطي.** |
| ط | `FilledButton` | «إنشاء» أو «حفظ التعديل» — ثابتٌ أسفل الورقة **خارج** المنطقة القابلة للتمرير. |

## شجرة الـ Widget tree
```
Scaffold
├── appBar: QtmsTopBar («الأدوار»)
├── floatingActionButton: PermissionGate(roleWrite) → FloatingActionButton.extended
└── body: switch (rolesProvider)
    ├── hasError  → _RolesError → QtmsErrorState
    ├── data []   → _RolesEmpty → QtmsEmptyState (badge_outlined · ثلاثية identity)
    ├── data [..] → _RolesList → EntityList → ListView.separated
    │                └── _RoleTile → EntityTile
    │                    ├── title: Text (اسم الدور)
    │                    ├── subtitle: Text (الوصف | «بلا وصف»)
    │                    ├── badges: [شرطي] StatusPill «مُسنَد»
    │                    ├── rejection: [شرطي] لافتة danger داخلية
    │                    └── actions (stacked · Divider + صف 48):
    │                        ├── PermissionGate(roleWrite)  → IconButton (edit_outlined)
    │                        └── PermissionGate(roleDelete) → IconButton (delete_outline)
    └── loading   → SkeletonList
```

## الحالات المُعالجة
| الحالة | الوضع |
|---|---|
| Loading | ✅ `SkeletonList` للقائمة. وأثناء الحذف `_busy` يُعطِّل زرَّي البطاقة ⛔ **بلا مؤشّر دوران.** |
| Error | ✅ `QtmsErrorState` بتمييز `permission-denied` عن الفشل العام، **و**لافتة رفضٍ داخل البطاقة لفشل الحذف تحديداً. ⚠️ **بلا زرّ إعادة محاولة.** |
| Empty | ✅ «لا توجد أدوار بعد» + شرحٌ لماذا يفيد الدور. |

## آلية التنقل
- **الدخول إليها:** «لوحة اليوم» ⟶ «الهوية والصلاحيات» ⟶ «الأدوار» (بمفتاح `roleWrite`).
- **الخروج منها:** ⛔ **لا مسارَ خارجاً** — كلُّ عملها في أوراق سفلية. الرجوع بزرّ النظام.

# تخصيص الصلاحيات

| البند | القيمة |
|---|---|
| **اسم الكلاس** | `PermissionsScreen` (`ConsumerWidget`) — يستقبل `userId` |
| **مسار الملف** | `lib/capabilities/identity_access/presentation/permissions_screen.dart` |
| **مكوّن الشجرة** | `lib/capabilities/identity_access/presentation/permission_tree.dart` — `PermissionTree` |
| **المسار الملاحي** | `/home/users/:userId/permissions` — `permissionsRouteFor(userId)` |
| **اسم الشاشة في الشريط** | «تخصيص الصلاحيات» |
| **اسم اللقطة المتوقّع** | `permissions_screen.png` |

## الغرض
منحُ مستخدمٍ بعينه مفاتيحَه ونطاقَ مصادره. والقاعدة الحاكمة: **لا يملك أحدٌ منحَ ما لا يملك** (`grantable` = مفاتيح المانح)، **ولا يعدّل أحدٌ صلاحيات حسابه ولو كان المالك.**

## العناصر

| # | الـ Widget class الفعلي | الحجم / اللون / الخط / المسافات | الظهور والتفاعل |
|:-:|---|---|---|
| 1 | `Scaffold` + `QtmsTopBar` | `screenTitle: 'تخصيص الصلاحيات'` | |
| 2 | `ListView` | `padding: EdgeInsets.all(16)` | جذر المحرِّر. |
| 3 | `_Header` > `Container` | سطح `surface` · حدّ `border` · `Radii.card = 20` · حشو 16 | اسم المستخدم (`titleSm`) فوق اسم دوره أو «بلا دور» (`bodyMd`/`textSecondary`). |
| 4 | `_Helpers` > `Wrap` | فاصل 8 أفقياً ورأسياً | صفُّ مختصرَين. |
| 5 | `PopupMenuButton<UserCard>` | يُغلِّف `_HelperChip` (تعبئة `surfaceSunken` · حدّ `border` · `Radii.field = 14` · أيقونة `content_copy_outlined` بحجم **18** · نصّ `bodyMd`) | **قائمة منسدلة (Popup menu) تنبثق من مكان الشريحة نفسها** أعلى الشاشة تحت ترويسة الاسم. بنودها كل المستخدمين الآخرين. اختيار أحدهم **ينسخ صلاحياته كاملةً** إلى المحرِّر. **شرطي:** يظهر إن وُجد مستخدم آخر. |
| 6 | `InkWell` > `_HelperChip` «إعادة إلى قالب الدور» | أيقونة `restart_alt` | **شرطي:** يظهر إن كان للمستخدم دور. يُعيد التأشير إلى قالب الدور حرفياً. |
| 7 | `_ScopeEditor` > `Container` | سطح `surface` · حدّ · `Radii.card` · حشو 16 · العنوان «نطاق المصادر» بـ`titleSm`/`textSecondary` | محرِّر النطاق. |
| 8 | `CheckboxListTile` «كل المصادر» | مربّع بتعبئة `primary500` عند التأشير · حدّ `neutral400` · `Radii.xs = 8` | **شرطي:** يظهر **فقط** إن كان نطاق المانح `AllSources`. |
| 9 | `Text` تحذيري | `bodyMd` بلون `SemanticTriads.warning.ink` = `#946010` | **شرطي:** يظهر إذا كان نطاق الهدف الحالي `AllSources` والمانحُ أضيقُ منه — «نطاق هذا المستخدم الآن «كل المصادر»، وهو أوسع من نطاقك — والحفظ سيقصره على ما تختاره أدناه.» |
| 10 | `CheckboxListTile` لكل مصدر | العنوان **هو `sourceId` الخام** ⚠️ **لا اسم المصدر المقروء** | تأشيرٌ مستقلّ لكل معرّف. المرشَّحون = اتحاد نطاق المانح ونطاق الهدف، مرتّباً تصاعدياً. |
| 11 | `Text` | «لا مصادر متاحة ضمن نطاقك.» — `bodyMd`/`textSecondary` | **شرطي:** لا مرشَّح ولا صلاحية منح الكل. |
| 12 | `PermissionTree` | انظر التفصيل أدناه | شجرة المفاتيح مع `grantable: actor.permissions` و`roleTemplate: role?.permissionTemplate`. |
| 13 | `QtmsInlineBanner` (`danger`) | حشو 12 · `Radii.card` | **شرطي:** رفضٌ بنصٍّ من الكتالوج. |
| 14 | `QtmsInlineBanner` (`primary`) | تعبئة `primary50` · حدّ `primary200` · حبر `primary700` | **شرطي:** «✅ حُفظت الصلاحيات.» — يُلغى عند أول تعديل تالٍ (`_saved = false`). |
| 15 | `FilledButton` «حفظ الصلاحيات» | ارتفاع 52 | **معطَّل ما لم يُختَر نطاق** (`_scope == null`) أو أثناء الإرسال. |
| 16 | `Text` إرشادي | `bodyMd`/`textSecondary`/`center` | **شرطي:** «اختر نطاق المصادر قبل الحفظ.» — يظهر تحت الزرّ المعطَّل ⟵ **فيُفسِّر التعطيل بدل أن يتركه غامضاً.** |

### مكوّن `PermissionTree`

| # | الـ Widget class | التفاصيل |
|:-:|---|---|
| أ | `QtmsSearchField` > `TextField` | تسمية «بحث في الصلاحيات» · `prefixIcon: Icons.search` · و`suffixIcon: IconButton(Icons.close)` بـ`tooltip: 'مسح البحث'` **يظهر فقط عند وجود نصّ**. البحث على **التسمية العربية** بعد `normalizeName`. |
| ب | `QtmsNoMatch` > `Text` | «لا صلاحية بهذا الاسم.» — `bodyMd`/`textSecondary`/`center` · حشو 16. **بديل النتائج عند عدم التطابق.** |
| ج | `_Group` | لكل `PermissionGroup`: عنوانٌ `titleSm`/`textSecondary` بحشو رأسي 8، ثم صفوفه. حشو سفلي للمجموعة 16. **والمجموعة الخالية من نتائج البحث تُحجَب كلياً.** |
| د | `_PermissionRow` > `Row` | `Checkbox` + `Text` بـ`bodyMd` (لونه `textPrimary` إن كان مُفعَّلاً و`textTertiary` إن لا). |
| هـ | `Text` «لا تملكها» | `bodyMd`/`textTertiary` · حشو نهائي 8 | **شرطي:** يظهر بجوار كل مفتاح **لا يملكه المانح** — والمربّع معطَّل. ⟵ **فالسببُ مكتوبٌ لا مُستنتَج.** |
| و | `_DeltaBadge` > `Container` | «فوق الدور» بثلاثية `primary` · «دون الدور» بثلاثية `warning` · حشو 8/4 · `Radii.field` | **شرطي:** يظهر فقط عند الاختلاف عن قالب الدور (`sameAsRole` لا يُعرَض شيئاً). |
| ز | منطق `_toggle` | **التأشير يجرّ متطلَّباته صعوداً** (`grantPrerequisite` متسلسلاً)، **وإلغاؤه يُسقِط كل ما يتعلّق به** في حلقةٍ متكرّرة حتى الاستقرار ⟵ **فلا مفتاحَ يتيمٌ بلا شرطه.** |

## شجرة الـ Widget tree
```
Scaffold
├── appBar: QtmsTopBar («تخصيص الصلاحيات»)
└── body: switch (usersProvider)
    ├── hasError → _Notice (permissionMissing)
    ├── loading  → SkeletonList
    └── data     → _resolve(...)
        ├── الهدف غير موجود → _Notice (operationFailed)
        ├── الهدف = الفاعل   → _SelfNotice («لا يمكن لأي مستخدم تعديل صلاحيات حسابه — ولو كان المالك.»)
        └── _PermissionsEditor → ListView (padding: 16)
            ├── _Header (Container: الاسم + الدور)
            ├── _Helpers → Wrap
            │   ├── [شرطي] PopupMenuButton<UserCard> → _HelperChip «نسخ صلاحيات مستخدم»
            │   └── [شرطي] InkWell → _HelperChip «إعادة إلى قالب الدور»
            ├── _ScopeEditor (Container)
            │   ├── [شرطي] CheckboxListTile «كل المصادر»
            │   ├── [شرطي] Text تحذيري (warning.ink)
            │   └── CheckboxListTile × كل sourceId مرشَّح
            ├── PermissionTree
            │   ├── QtmsSearchField
            │   └── _Group × N → _PermissionRow (Checkbox + Text + [_DeltaBadge] + [«لا تملكها»])
            ├── [شرطي] QtmsInlineBanner (danger — رفض)
            ├── [شرطي] QtmsInlineBanner (primary — «✅ حُفظت الصلاحيات.»)
            ├── FilledButton «حفظ الصلاحيات»
            └── [شرطي] Text «اختر نطاق المصادر قبل الحفظ.»
```

## الحالات المُعالجة
| الحالة | الوضع |
|---|---|
| Loading | ✅ `SkeletonList` أثناء قراءة المستخدمين. وأثناء الحفظ يُعطَّل الزرّ ⛔ **بلا مؤشّر دوران.** |
| Error | ⚠️ **مبسَّطة عمداً:** `_Notice` = نصٌّ مُوسَّطٌ من الكتالوج ⛔ **بلا أيقونة ولا زرّ إعادة محاولة ولا تفاصيل تقنية** — بخلاف `QtmsErrorState` في بقية الشاشات. |
| Empty | لا ينطبق للشجرة (ثابتة دائماً). ✅ **ولحالتَين خاصّتَين نصٌّ صريح:** «لا مصادر متاحة ضمن نطاقك.» و«لا صلاحية بهذا الاسم.» |
| منعٌ منطقي | ✅ `_SelfNotice` — حالةٌ مستقلّةٌ كاملة لتعديل صلاحيات النفس. |

## آلية التنقل
- **الدخول إليها:** **من `/home/users` وحدها** — زرُّ `Icons.key_outlined` على بطاقة مستخدمٍ غير المستخدم الحالي، بمفتاح `permissionGrant`.
- **الخروج منها:** ⛔ **لا مسارَ خارجاً** — الرجوع بزرّ النظام. والحفظ لا يُغلِق الشاشة، بل يعرض لافتة النجاح ويبقيها مفتوحة.

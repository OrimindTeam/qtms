/// مزوّدات إدارة المستخدمين والأدوار (`IQ-015`).
///
/// ★ **بنفس نمط `session_providers.dart`:** المستودعات **تُحقَن في الجذر
/// ولا تُبنى هنا** (`ADR-0010` — حقن اعتمادية صريح)، ⟵ **فتُختبَر الشاشات
/// بلا سحابة ولا شبكة**.
///
/// ⚠️⚠️ **وكل ما هنا عرضٌ لا تفويض:** إخفاء الشاشة بـ`userView` **إخفاء لا
/// حماية** — ★ **وحمايتها الحقيقية شرطُ القراءة في `firestore.rules`**
/// (`RISK-02` · `ADR-0010` القاعدة 3). ⛔ **ولا يُكتفى بهذه المزوّدات أبداً.**
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qtms_domain/qtms_domain.dart';

/// دليل المستخدمين — ⛔ **يُحقَن في الجذر**.
final Provider<UserDirectoryRepository> userDirectoryProvider =
    Provider<UserDirectoryRepository>((Ref ref) {
  throw UnimplementedError('userDirectoryProvider يجب تجاوزه عند الجذر');
});

/// مستودع إدارة المستخدمين — ⛔ **يُحقَن في الجذر**.
final Provider<UserAdminRepository> userAdminProvider =
    Provider<UserAdminRepository>((Ref ref) {
  throw UnimplementedError('userAdminProvider يجب تجاوزه عند الجذر');
});

/// مستودع الأدوار — ⛔ **يُحقَن في الجذر**.
final Provider<RoleAdminRepository> roleAdminProvider =
    Provider<RoleAdminRepository>((Ref ref) {
  throw UnimplementedError('roleAdminProvider يجب تجاوزه عند الجذر');
});

/// قائمة المستخدمين الحيّة.
///
/// ★ **تدفّقٌ لا قراءة واحدة:** تعطيلُ مستخدمٍ من جهازٍ آخر **يظهر فوراً**.
///
/// ⚠️★★ **والرفض يصل هنا خطأً لا قائمةً فارغة** — ⟵ **فتُميِّز الشاشة بين
/// «لا مستخدمين» و«ممنوعٌ من الرؤية»**، ⛔ **وخلطُهما يجعل نقصَ الصلاحية
/// يبدو نظاماً فارغاً** فيبحث المدير عن عطلٍ لا وجود له.
final StreamProvider<List<UserCard>> usersProvider =
    StreamProvider<List<UserCard>>(
  (Ref ref) => ref.watch(userDirectoryProvider).watchAll(),
);

/// قائمة الأدوار الحيّة — ★ **مقروءة لكل مُصادَق** (لا تشترط صلاحية).
final StreamProvider<List<RoleCard>> rolesProvider =
    StreamProvider<List<RoleCard>>(
  (Ref ref) => ref.watch(roleAdminProvider).watchAll(),
);

/// ★★ **معرّفات الأدوار المُسنَدة — مشتقّةٌ من بيانات المستخدمين الفعلية**.
///
/// ⛔★★ **ولا تُقرأ من مستند الدور:** حسم `IQ-018` نصّاً — «**لا يعتمد على
/// قيمة مخزنة أو افتراض محلي**». ⟵ **فلا حقل `isAssigned` في `roles`**،
/// والإسناد **يُشتقّ ممّن يشير إلى الدور فعلاً.**
///
/// ⚠️⚠️ **وهذا عرضٌ لا حماية — والفارق جوهري هنا بالذات:** القائمة تحتاج
/// `userView`، ⟵ **فمن يملك `roleDelete` ولا يملك `userView` لا يعرف
/// الإسناد** وتصله القيمة `null`. ★ **والشاشة عندئذٍ تُتيح المحاولة**،
/// ⛔ **ولا تُخفي الزر فتمنع صاحبَ الحق** — **والحسم في السحابة** التي
/// تستعلم بامتيازها هي (`ADR-0013` القاعدة 3).
///
/// `null` تعني **«غير معروف»** ⛔ **لا «لا يوجد مُسنَد»** — ★ **والتمييز هو
/// ما يمنع الشاشةَ من الادّعاء بما لا تعلم.**
final Provider<Set<String>?> assignedRoleIdsProvider =
    Provider<Set<String>?>((Ref ref) {
  final AsyncValue<List<UserCard>> users = ref.watch(usersProvider);
  final List<UserCard>? list = users.value;
  // ⛔ **خطأ أو تحميل ⟵ «غير معروف»** — ★ **ولا يُقرأ الفشل «لا إسناد»**،
  //    فذلك كان سيجعل نقصَ `userView` يُظهر كل الأدوار قابلةً للحذف.
  if (users.hasError || list == null) return null;
  return <String>{
    for (final UserCard user in list)
      if (user.roleId case final String roleId when roleId.isNotEmpty) roleId,
  };
});

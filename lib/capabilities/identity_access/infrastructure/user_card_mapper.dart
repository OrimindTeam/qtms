/// تحويل مستند `users/{userId}` إلى بطاقة نطاق — ★ **طبقة البنية التحتية
/// وحدها تعرف شكل المستند** (`ADR-0009`: «تنفيذ المستودعات · حزم المنصة ·
/// التحويل»).
///
/// ★ **وأسماء الحقول نقلٌ حرفي لـ`data-dictionary.md` §1 (`users`)** —
/// ⛔ **ولا اسم مخترَع**: `naming-conventions.md` §3، والخطأ في اسم حقل
/// **خلل مالي صامت** (`ADR-0009` القاعدة 6).
library;

import 'package:qtms_domain/qtms_domain.dart';

/// أسماء حقول المستند كما في قاموس البيانات حرفياً.
const String userNameField = 'name';
const String userEmailField = 'email';
const String userRoleIdField = 'roleId';
const String userRoleNameField = 'roleName';
const String userPermissionsField = 'permissions';
const String userIsActiveField = 'isActive';
const String userSourceScopeField = 'sourceScope';
const String userDisableReasonField = 'disableReason';

/// يبني [UserCard] من حمولة المستند.
///
/// ⚠️ **والاتجاه الآمن مفروض في كل حقل غامض:**
/// ① **مفتاح صلاحية لا يعرفه الكتالوج يُتجاهَل** — ⟵ **فلا يمنح شيئاً**،
/// وهو أسلم من الرمي الذي يمنع الدخول كلياً بسبب حقل زائد.
/// ② **قيمة غير `true` لا تُمنَح** — `map<string,bool>` والقاعدة تقرأ
/// `permissions[key] == true` حرفياً.
/// ③ ★ **`isActive` الغائبة تُقرأ `false`** — ⛔ **لا `true`**: الرفض هو
/// الأصل والسماح استثناء صريح (`BR-M1-01` · `GR-10`).
UserCard mapUserCard({
  required String userId,
  required Map<String, Object?> document,
}) {
  final Object? rawName = document[userNameField];
  final Object? rawPermissions = document[userPermissionsField];

  return UserCard(
    userId: userId,
    name: rawName is String && rawName.trim().isNotEmpty
        ? rawName.trim()
        : userId,
    email: _stringOrNull(document[userEmailField]),
    roleId: _stringOrNull(document[userRoleIdField]),
    roleName: _stringOrNull(document[userRoleNameField]),
    permissions: _mapPermissions(rawPermissions),
    isActive: document[userIsActiveField] == true,
    disableReason: _stringOrNull(document[userDisableReasonField]),
    // ★ **نسخةٌ للعرض** — ⛔ **ولا يُقرَّر بها وصول** (`ADR-0016`).
    //   ★ **وتُقرأ بالدالة نفسها التي تقرأ المطالبة** — ⟵ **فلا تأويلان
    //   لقيمةٍ واحدة** يفترقان عند أول تعديل.
    sourceScope: parseSourceScopeClaim(document[userSourceScopeField]),
  );
}

String? _stringOrNull(Object? value) {
  if (value is! String) return null;
  final String trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

Set<Permission> _mapPermissions(Object? raw) {
  if (raw is! Map<Object?, Object?>) return const <Permission>{};

  final Map<String, Permission> byKey = <String, Permission>{
    for (final Permission permission in Permission.values)
      permission.name: permission,
  };

  return <Permission>{
    for (final MapEntry<Object?, Object?> entry in raw.entries)
      if (entry.value == true && byKey[entry.key] != null) byKey[entry.key]!,
  };
}

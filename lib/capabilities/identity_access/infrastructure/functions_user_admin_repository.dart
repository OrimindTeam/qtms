/// إدارة المستخدمين والأدوار عبر **العمليات السحابية المستدعاة** (`IQ-015`).
///
/// ⛔★★ **ولا كتابة مباشرة واحدة:** `users` و`roles` مغلقتان في القواعد
/// بـ`allow write: if false` (`ADR-0013` القاعدة 2 · `BR-M1-08`)، ⟵ **فكل
/// عملية هنا طلبٌ لا كتابة**، والقرار والقيد يقعان في السحابة **معاً في
/// معاملة واحدة**.
///
/// ★★ **و`requestId` مُولَّد على الجهاز لكل عملية** — وهو **معرّف قيد
/// التدقيق نفسه** (`api-overview.md` §4)، ⟵ **فإعادة الإرسال بعد انقطاع
/// تكتب فوق القيد ولا تُنشئ ثانياً.** ⛔ **ولا يُولَّد في السحابة**: مُولَّدٌ
/// هناك يتغيّر مع كل محاولة **فتصير كل إعادة إرسالٍ عمليةً جديدة**.
library;

import 'package:qtms_domain/qtms_domain.dart';

import '../../../core/callable/callable_client.dart';

/// مولّد معرّفات الطلبات — ★ **يُحقَن، فيُختبَر بقيمة ثابتة**.
typedef RequestIdFactory = String Function();

/// مستودع إدارة المستخدمين الحقيقي.
final class FunctionsUserAdminRepository implements UserAdminRepository {
  /// ينشئ المستودع.
  const FunctionsUserAdminRepository({
    required CallableClient client,
    required RequestIdFactory newRequestId,
  })  : _client = client,
        _newRequestId = newRequestId;

  final CallableClient _client;
  final RequestIdFactory _newRequestId;

  @override
  Future<Outcome<String>> create(
    ValidatedUserProfile profile, {
    required InitialPassword password,
  }) async {
    final Outcome<Map<String, Object?>> result = await _client.call(
      'createUser',
      <String, Object?>{
        'requestId': _newRequestId(),
        'name': profile.name,
        'email': profile.email,
        // ⛔ **الغائب لا يُرسَل مفتاحاً بقيمة فارغة** — فالحمولة تُفحَص
        //    مفاتيحُها مقابل الممنوعات، **والمفتاح الفارغ نيّةٌ لا غياب**.
        if (profile.phone != null) 'phone': profile.phone,
        if (profile.roleId != null) 'roleId': profile.roleId,
        // ⚠️★★★ **كلمةُ المرور الأولية** — `CR-005` (2026-08-31): ★ **تعبر
        //    إلى خدمة المصادقة وحدها**، ⛔ **ولا تُخزَّن في `users/{userId}`
        //    ولا في قيد التدقيق ولا تُرجَع في الردّ.**
        //
        // ⛔⛔★★★ **والمفتاح `initialPassword` لا `password`** — ★ **الأخيرُ
        //    ممنوعٌ ويُرفَض به الطلبُ كلُّه** (`FR-M1-02` · `forbiddenUserFields`):
        //    ⟵ **والحارس باقٍ بحرفه**، ★ **والمفتاح الجديد يُستثنى صراحةً
        //    في الدالة** ⛔ **لا بتخفيف قائمة الممنوعات.**
        //
        // ★★ **والتأكيد يُرسَل ليُفحَص هناك أيضاً** — `ADR-0013` القاعدة 3:
        //    **«القاعدة نفسها في الطرفين»**.
        'initialPassword': password.value,
        'initialPasswordConfirm': password.value,
        // ⛔★★ ولا `permissions` ولا `sourceScope` إطلاقاً —
        //    راجع ترويسة `functions/lib/src/user_admin.dart`.
      },
    );
    return switch (result) {
      Failure<Map<String, Object?>>(:final AppError error) =>
        Failure<String>(error),
      Success<Map<String, Object?>>(:final Map<String, Object?> value) =>
        _readUserId(value),
    };
  }

  @override
  Future<Outcome<void>> update({
    required String userId,
    required ValidatedUserProfile profile,
    String? amendReason,
  }) =>
      _voidCall('updateUser', <String, Object?>{
        'requestId': _newRequestId(),
        'userId': userId,
        'name': profile.name,
        'email': profile.email,
        if (profile.phone != null) 'phone': profile.phone,
        if (profile.roleId != null) 'roleId': profile.roleId,
        // ★★ **سبب التعديل إلزامي** — `ADR-0004` · `DEBT-21` ①.
        'amendReason': ?amendReason,
      });

  @override
  Future<Outcome<void>> disable({
    required String userId,
    required String reason,
  }) =>
      _voidCall('disableUser', <String, Object?>{
        'requestId': _newRequestId(),
        'userId': userId,
        // ★ **السبب النصي إلزامي** — `FR-M1-12`.
        'reason': reason,
      });

  @override
  Future<Outcome<void>> grantAccess({
    required String userId,
    required Set<Permission> permissions,
    required SourceScope scope,
  }) =>
      _voidCall('grantPermissions', <String, Object?>{
        'requestId': _newRequestId(),
        'userId': userId,
        // ★ الترتيب ثابت — فنفس المجموعة تُنتج نفس الحمولة في كل تشغيل
        //   (`coding-standards.md` §2.7).
        'permissions': (permissions.toList()
              ..sort((Permission a, Permission b) => a.index - b.index))
            .map((Permission p) => p.name)
            .toList(),
        'sourceScope': switch (scope) {
          AllSources() => allSourcesClaimValue,
          ScopedSources(:final Set<String> sourceIds) => sourceIds.toList()
            ..sort(),
        },
      });

  Future<Outcome<void>> _voidCall(
    String operation,
    Map<String, Object?> data,
  ) async {
    final Outcome<Map<String, Object?>> result =
        await _client.call(operation, data);
    return switch (result) {
      Failure<Map<String, Object?>>(:final AppError error) =>
        Failure<void>(error),
      Success<Map<String, Object?>>() => const Success<void>(null),
    };
  }

  static Outcome<String> _readUserId(Map<String, Object?> result) {
    final Object? userId = result['userId'];
    if (userId is String && userId.isNotEmpty) {
      return Success<String>(userId);
    }
    // ⚠️ **نجاحٌ بلا معرّف عطلٌ لا نجاح:** الشاشة تحتاجه لتفتح بطاقة من
    //    أُنشئ، ⛔ **وابتلاعُه يُظهر «تمّ» ثم لا يجد المستخدمَ أحدٌ.**
    return const Failure<String>(
      InfrastructureError('استجابة createUser بلا userId'),
    );
  }
}

/// مستودع الأدوار الحقيقي.
///
/// ✅★★ **و[delete] فُتحت بحسم `IQ-018`** — **حذفٌ فعلي للدور غير المُسنَد**.
/// ⛔★★ **ولا يفحص هذا المستودع الإسناد إطلاقاً:** القياس **استعلامٌ على
/// `users` داخل معاملة السحابة**، ⟵ **فلا كاشَ في الجهاز يُقرِّر مصير
/// مستند** (`IQ-018`: «لا يعتمد على قيمة مخزنة أو افتراض محلي»).
final class FunctionsRoleAdminRepository implements RoleAdminRepository {
  /// ينشئ المستودع.
  const FunctionsRoleAdminRepository({
    required CallableClient client,
    required RequestIdFactory newRequestId,
    required Stream<List<RoleCard>> roles,
  })  : _client = client,
        _newRequestId = newRequestId,
        _roles = roles;

  final CallableClient _client;
  final RequestIdFactory _newRequestId;
  final Stream<List<RoleCard>> _roles;

  @override
  Stream<List<RoleCard>> watchAll() => _roles;

  @override
  Future<Outcome<void>> create(ValidatedRole role) =>
      _write('createRole', role, roleId: _newRequestId(), amendReason: null);

  @override
  Future<Outcome<void>> update({
    required String roleId,
    required ValidatedRole role,
    String? amendReason,
  }) =>
      _write('updateRole', role, roleId: roleId, amendReason: amendReason);

  @override
  Future<Outcome<void>> delete({
    required String roleId,
    String? amendReason,
  }) async {
    final Outcome<Map<String, Object?>> result =
        await _client.call('deleteRole', <String, Object?>{
      'requestId': _newRequestId(),
      'roleId': roleId,
      // ★★ **سبب نصّي إلزامي** — والحذف لا رجعة فيه (`ADR-0004` · `CR-002`).
      'amendReason': ?amendReason,
      // ⛔★★ **ولا حقل «مُسنَد» يُرسَل هنا إطلاقاً** — إرسالُه كان سيجعل
      //    **الجهازَ** يُقرِّر ما تحسمه السحابة، وهو ما يمنعه `IQ-018` نصّاً.
    });
    return switch (result) {
      Failure<Map<String, Object?>>(:final AppError error) =>
        Failure<void>(error),
      Success<Map<String, Object?>>() => const Success<void>(null),
    };
  }

  Future<Outcome<void>> _write(
    String operation,
    ValidatedRole role, {
    required String roleId,
    required String? amendReason,
  }) async {
    final Outcome<Map<String, Object?>> result =
        await _client.call(operation, <String, Object?>{
      'requestId': _newRequestId(),
      'roleId': roleId,
      'name': role.name,
      if (role.description != null) 'description': role.description,
      // ★★ **قالب الصلاحيات** — `FR-M1-03`. ★ **بترتيب ثابت** فنفس المجموعة
      //   تُنتج نفس الحمولة في كل تشغيل (`coding-standards.md` §2.7).
      'permissionTemplate': (role.permissions.toList()
            ..sort((Permission a, Permission b) => a.index - b.index))
          .map((Permission p) => p.name)
          .toList(),
      'amendReason': ?amendReason,
    });
    return switch (result) {
      Failure<Map<String, Object?>>(:final AppError error) =>
        Failure<void>(error),
      Success<Map<String, Object?>>() => const Success<void>(null),
    };
  }
}

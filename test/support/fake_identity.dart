/// بدائل اختبارية للمستودعين — ★ **فلا اختبار يمسّ سحابة ولا شبكة**
/// (`ADR-0010`: حقن اعتمادية صريح · `test-strategy.md`).
library;

import 'dart:async';

import 'package:qtms/core/device/biometric_gateway.dart';
import 'package:qtms/core/device/credential_vault.dart';
import 'package:qtms/core/device/device_preferences.dart';
import 'package:qtms_domain/qtms_domain.dart';

/// مستودع مصادقة يُتحكَّم به من الاختبار.
final class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({SignInResult result = const SignInAccepted()})
      : _result = result;

  final StreamController<AuthenticatedIdentity?> _identities =
      StreamController<AuthenticatedIdentity?>.broadcast();

  /// ★ آخر قيمة — تُعاد للمُصغي الجديد أولاً.
  ///
  /// ⚠️ **بلا هذا يضيع أي حدث يسبق الاشتراك** (تدفّق البثّ لا يحفظ)،
  /// ⟵ **فيبقى الاختبار عالقاً على شاشة الانتظار بلا سبب ظاهر.**
  AuthenticatedIdentity? _current;

  SignInResult _result;

  /// عدد مرات استدعاء الخروج — يُثبت أن الزر يفعل شيئاً فعلاً.
  int signOutCalls = 0;

  /// آخر بريد وصل الدالة — يُثبت أن الشاشة تُمرِّر ما كتبه المستخدم.
  String? lastEmail;

  /// ★ آخر كلمة مرور وصلت الدالة — ★ **يُثبت أن البصمة تُمرِّر المحفوظة.**
  ///
  /// ⛔⛔ **وهي بيانةُ اختبارٍ محضة** — ★ **ولا نظيرَ لها في الكود الحقيقي**
  /// (`FakeAuthRepository` **لا يُبنى في بناء الإصدار أصلاً**).
  String? lastPassword;

  /// ★★ عددُ مرات تغيير كلمة المرور — ★ **يُثبت أن الشاشة تفعل شيئاً.**
  int changePasswordCalls = 0;

  /// ★ آخر كلمةٍ جديدة وصلت — ★ **يُثبت تحديثَ الخزنة بها.**
  String? lastNewPassword;

  /// ★ نتيجةُ تغيير كلمة المرور — تُضبَط من الاختبار.
  SignInResult changePasswordResult = const SignInAccepted();

  set result(SignInResult value) => _result = value;

  void emitIdentity(AuthenticatedIdentity? identity) {
    _current = identity;
    _identities.add(identity);
  }

  /// ⚠️ **يُغلِق بلا انتظار عمداً:** انتظار `close()` داخل `tearDown` **لا
  /// يعود أبداً** في اختبار الودجات — إتمامه يحتاج تفريغ المهام الصغرى،
  /// وهي لا تُفرَّغ خارج نبضة (`tester.pump`). ★ **مُجرَّب: علّق الاختبار
  /// 15 ثانية حتى انتهت المهلة.**
  void dispose() {
    unawaited(_identities.close());
  }

  @override
  Stream<AuthenticatedIdentity?> watchIdentity() async* {
    yield _current;
    yield* _identities.stream;
  }

  @override
  Future<SignInResult> signIn({
    required String email,
    required String password,
  }) async {
    lastEmail = email;
    lastPassword = password;
    return _result;
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    _identities.add(null);
  }

  @override
  Future<SignInResult> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    changePasswordCalls++;
    lastNewPassword = newPassword;
    return changePasswordResult;
  }
}

/// ★★★ **بوابةُ بصمةٍ يُتحكَّم بها من الاختبار** — [`ADR-0024`] · `AM-012`.
///
/// ⛔⛔★★ **وهي ما يجعل الشروط 2 و6 و7 و11 قابلةً للاختبار الآلي أصلاً** —
/// ★ **`local_auth` قناةُ منصّةٍ لا تعمل في اختبار ويدجت**، ⟵ **فبلا هذا
/// المزيَّف لا يبقى إلا القياسُ الحيّ على المحاكي** ⛔ **وهو لا يكفي.**
final class FakeBiometricGateway implements BiometricGateway {
  /// حالةُ الدعم المُعادة — تُضبَط من الاختبار.
  BiometricAvailability state = BiometricAvailability.available;

  /// هل تنجح المصادقة؟ — ★ **و`false` تُحاكي رفضاً أو إلغاءً.**
  bool accepts = true;

  /// عددُ مرات طلب المصادقة — ⛔ **يُثبت أنها طُلبت قبل القراءة.**
  int authenticateCalls = 0;

  /// آخرُ سببٍ عُرض على المستخدم.
  String? lastReason;

  @override
  Future<BiometricAvailability> availability() async => state;

  @override
  Future<bool> authenticate({required String reason}) async {
    authenticateCalls++;
    lastReason = reason;
    return accepts;
  }
}

/// ★★★ **خزنةٌ في الذاكرة يُتحكَّم بها من الاختبار** — [`ADR-0024`].
final class FakeCredentialVault implements CredentialVault {
  StoredCredentials? _stored;

  /// عددُ مرات القراءة — ⛔ **يُثبت ألّا تُقرأ قبل المصادقة** (الشرط 2).
  int readCalls = 0;

  /// عددُ مرات المسح — ★ **يُثبت الشرطين 6 و7.**
  int clearCalls = 0;

  /// ★ يزرع بياناتٍ محفوظة مسبقاً.
  void seed(StoredCredentials credentials) => _stored = credentials;

  /// ★ المحفوظُ الآن — **للفحص في الاختبار** ⛔ **لا للإنتاج.**
  StoredCredentials? get stored => _stored;

  @override
  Future<StoredCredentials?> readIfPresent() async {
    readCalls++;
    return _stored;
  }

  @override
  Future<void> save(StoredCredentials credentials) async {
    _stored = credentials;
  }

  @override
  Future<void> clear() async {
    clearCalls++;
    _stored = null;
  }

  @override
  Future<bool> hasCredentials() async => _stored != null;
}

/// ★★ **تفضيلاتُ عرضٍ في الذاكرة** — `AM-012` §4.4.
final class FakeDevicePreferences implements DevicePreferences {
  bool _showPieceWeight = false;

  /// عددُ مرات الكتابة — ★ **يُثبت أن الزرّ يفعل شيئاً.**
  int writeCalls = 0;

  /// ★ يزرع قيمةً مبدئية.
  void seedShowPieceWeight({required bool enabled}) =>
      _showPieceWeight = enabled;

  @override
  Future<bool> showPieceWeightWithItemName() async => _showPieceWeight;

  @override
  Future<void> setShowPieceWeightWithItemName({required bool enabled}) async {
    writeCalls++;
    _showPieceWeight = enabled;
  }
}

/// مستودع بطاقات يُتحكَّم به من الاختبار.
final class FakeUserCardRepository implements UserCardRepository {
  final Map<String, StreamController<UserCard?>> _controllers =
      <String, StreamController<UserCard?>>{};

  final Map<String, UserCard?> _current = <String, UserCard?>{};

  /// المعرّفات التي طُلبت — ★ **يُثبت أن التطبيق لا يقرأ بطاقة غير صاحبها.**
  final List<String> requestedUserIds = <String>[];

  void emitCard(String userId, UserCard? card) {
    _current[userId] = card;
    _controllerFor(userId).add(card);
  }

  /// ⚠️ **بلا انتظار** — للسبب نفسه في [FakeAuthRepository.dispose].
  void dispose() {
    for (final StreamController<UserCard?> controller in _controllers.values) {
      unawaited(controller.close());
    }
  }

  StreamController<UserCard?> _controllerFor(String userId) =>
      _controllers.putIfAbsent(
        userId,
        StreamController<UserCard?>.broadcast,
      );

  @override
  Stream<UserCard?> watchCard(String userId) async* {
    requestedUserIds.add(userId);
    yield _current[userId];
    yield* _controllerFor(userId).stream;
  }
}

/// بطاقة جاهزة للاختبارات.
UserCard testCard({
  String userId = 'U-001',
  String name = 'عبدالفتاح',
  bool isActive = true,
  Set<Permission> permissions = const <Permission>{Permission.sackView},
  String? roleId,
  SourceScope? sourceScope = const AllSources(),
}) =>
    UserCard(
      userId: userId,
      name: name,
      roleId: roleId,
      roleName: 'المالك',
      permissions: permissions,
      isActive: isActive,
      sourceScope: sourceScope,
    );

/// دور جاهز للاختبارات.
RoleCard testRole({
  String roleId = 'ROLE-1',
  String name = 'محاسب',
  Set<Permission> template = const <Permission>{},
}) =>
    RoleCard(roleId: roleId, name: name, permissionTemplate: template);

/// ★ دليل مستخدمين يُتحكَّم به — و**الخطأ يُبثّ كخطأ لا كقائمة فارغة**،
/// ⟵ فيُختبَر تمييز الشاشة بين «ممنوع» و«لا يوجد».
final class FakeUserDirectory implements UserDirectoryRepository {
  final StreamController<List<UserCard>> _users =
      StreamController<List<UserCard>>.broadcast();

  List<UserCard>? _current;
  Object? _error;

  void emit(List<UserCard> users) {
    _current = users;
    _error = null;
    _users.add(users);
  }

  /// يبثّ رفضاً — ★ **كما تفعل المنصّة حين ترفض القاعدة الاستعلام.**
  void emitError(Object error) {
    _error = error;
    _users.addError(error);
  }

  /// ⚠️ **بلا انتظار** — للسبب نفسه في [FakeAuthRepository.dispose].
  void dispose() {
    unawaited(_users.close());
  }

  @override
  Stream<List<UserCard>> watchAll() async* {
    final Object? error = _error;
    if (error != null) {
      // ★ **مطابقةً للواقع:** رفضُ القاعدة يُنهي تدفّق المنصّة بخطأ
      //   ⛔ **ولا يُتبعه ببيانات** — والمحاكاة الأمينة شرطُ اختبارٍ صادق.
      yield* Stream<List<UserCard>>.error(error);
      return;
    }
    yield _current ?? const <UserCard>[];
    yield* _users.stream;
  }
}

/// ★ مستودع إدارة يُتحكَّم به — **يسجّل ما وصله فيُثبَت أن الشاشة تُرسله**.
final class FakeUserAdmin implements UserAdminRepository {
  /// النتيجة التي تُرجِعها كل عملية — تُضبَط من الاختبار.
  Outcome<void> result = const Success<void>(null);

  /// آخر ملف وصل عملية الإنشاء.
  ValidatedUserProfile? createdProfile;

  /// آخر سبب تعديل وصل — ★ **يُثبت أن الشاشة تُمرِّره فعلاً** (`DEBT-21` ①).
  String? lastAmendReason;

  /// آخر سبب تعطيل وصل.
  String? lastDisableReason;

  /// ★★ آخر كلمة مرور أولية وصلت — ⛔ **قيمتُها لا تُطبَع ولا تُقارَن نصّاً**،
  /// ★ **والاختبار يسأل «هل وصلت» لا «ما هي»** (`CR-005`).
  InitialPassword? lastPassword;

  @override
  Future<Outcome<String>> create(
    ValidatedUserProfile profile, {
    required InitialPassword password,
  }) async {
    createdProfile = profile;
    lastPassword = password;
    return switch (result) {
      Failure<void>(:final AppError error) => Failure<String>(error),
      Success<void>() => const Success<String>('U-NEW'),
    };
  }

  @override
  Future<Outcome<void>> update({
    required String userId,
    required ValidatedUserProfile profile,
    String? amendReason,
  }) async {
    lastAmendReason = amendReason;
    return result;
  }

  @override
  Future<Outcome<void>> disable({
    required String userId,
    required String reason,
  }) async {
    lastDisableReason = reason;
    return result;
  }

  /// ★★ آخر منح وصل — **يُثبت أن الشاشة تُرسل ما اختاره المدير حرفياً**.
  Set<Permission>? lastGrantedPermissions;

  /// آخر نطاق وصل.
  SourceScope? lastGrantedScope;

  /// آخر مستخدم مستهدَف بالمنح.
  String? lastGrantTarget;

  @override
  Future<Outcome<void>> grantAccess({
    required String userId,
    required Set<Permission> permissions,
    required SourceScope scope,
  }) async {
    lastGrantTarget = userId;
    lastGrantedPermissions = permissions;
    lastGrantedScope = scope;
    return result;
  }
}

/// ★ مستودع أدوار يُتحكَّم به — **يسجّل ما وصله فيُثبَت أن الشاشة تُرسله**.
final class FakeRoleAdmin implements RoleAdminRepository {
  /// النتيجة التي تُرجِعها كل عملية — تُضبَط من الاختبار.
  Outcome<void> result = const Success<void>(null);

  final StreamController<List<RoleCard>> _roles =
      StreamController<List<RoleCard>>.broadcast();

  List<RoleCard>? _current;
  Object? _error;

  /// ★★ معرّفات الأدوار التي طُلب حذفها — ⛔ **والقائمة الفارغة تُثبت أن
  /// الشاشة لم ترسل شيئاً**، وهو ما يُختبَر في حالة الدور المُسنَد.
  final List<String> deletedRoleIds = <String>[];

  /// آخر سبب حذف وصل — ★ **يُثبت أن الشاشة تُمرِّره** (`ADR-0004`).
  String? lastDeleteReason;

  /// آخر دور أُنشئ.
  ValidatedRole? createdRole;

  /// آخر سبب تعديل وصل.
  String? lastAmendReason;

  void emit(List<RoleCard> roles) {
    _current = roles;
    _error = null;
    _roles.add(roles);
  }

  void emitError(Object error) {
    _error = error;
    _roles.addError(error);
  }

  /// ⚠️ **بلا انتظار** — للسبب نفسه في [FakeAuthRepository.dispose].
  void dispose() {
    unawaited(_roles.close());
  }

  @override
  Stream<List<RoleCard>> watchAll() async* {
    final Object? error = _error;
    if (error != null) {
      yield* Stream<List<RoleCard>>.error(error);
      return;
    }
    yield _current ?? const <RoleCard>[];
    yield* _roles.stream;
  }

  @override
  Future<Outcome<void>> create(ValidatedRole role) async {
    createdRole = role;
    return result;
  }

  @override
  Future<Outcome<void>> update({
    required String roleId,
    required ValidatedRole role,
    String? amendReason,
  }) async {
    lastAmendReason = amendReason;
    return result;
  }

  @override
  Future<Outcome<void>> delete({
    required String roleId,
    String? amendReason,
  }) async {
    deletedRoleIds.add(roleId);
    lastDeleteReason = amendReason;
    return result;
  }
}

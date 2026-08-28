/// تنفيذ عمليتَي مزامنة الصلاحيات — **الطرف الذي يلمس الشبكة**.
///
/// ★ **مفصول عن `permission_sync.dart` عمداً:** كل قرار تفويض هناك في دوال
/// خالصة تُختبَر بلا سحابة؛ وهنا **الترتيب والأثر** وحدهما.
///
/// ★ **وترتيب الأثر مقصود ولا يُعكَس:**
/// ① المعاملة الذرّية (بطاقة المستخدم **وقيد التدقيق معاً**) ثم ② المطالبات.
///
/// ⚠️ **ولماذا هذا الاتجاه بالذات:** لو كُتبت المطالبات أولاً ثم فشلت
/// المعاملة، **لسرت الصلاحية بلا قيد تدقيق** — وهو بالضبط ما يمنعه
/// `BR-M18-03`. وبالاتجاه المعتمد، فشلُ المطالبات يترك المستخدم بصلاحية
/// **أقل** مما سُجِّل — ⟵ **خلل في الاتجاه الآمن، وتُصلحه إعادة الاستدعاء
/// بنفس `requestId`** لأن الطرفين قابلان للتكرار بلا أثر جانبي.
library;

import 'package:qtms_domain/qtms_domain.dart';
import 'package:shelf/shelf.dart';

import 'audited_transaction.dart';
import 'callable.dart';
import 'identity_claims.dart';
import 'identity_gateway.dart';
import 'permission_sync.dart';

/// اسم حقل معرّف الطلب في الحمولة.
const String requestIdField = 'requestId';

/// اسم حقل المستخدم المستهدَف.
const String targetUserIdField = 'userId';

/// منفّذ عمليات المزامنة.
final class PermissionSyncHandler {
  /// ينشئ المنفّذ بتبعياته — ★ **تُحقَن، فيُختبَر بلا سحابة**.
  const PermissionSyncHandler({
    required IdentityGateway identity,
    required AuditedTransaction transaction,
  })  : _identity = identity,
        _transaction = transaction;

  final IdentityGateway _identity;
  final AuditedTransaction _transaction;

  /// ينفّذ [operation] على طلب HTTP خام.
  Future<Response> handle(
    Request httpRequest,
    PermissionSyncOperation operation,
  ) async {
    final CallableParse parsed = await parseCallableRequest(httpRequest);
    if (parsed is RejectedCallable) return callableFailure(parsed.error);
    final CallableRequest call = (parsed as ParsedCallable).request;

    try {
      return await _execute(call, operation);
    } on IdentityGatewayException catch (error) {
      return callableFailure(_mapIdentityFailure(error), detail: error.diagnostic);
    } on TransactionContentionException catch (error) {
      // ⛔ ليس ابتلاعاً: يصل المستخدم رمز تعارض صريح فيُعيد المحاولة.
      return callableFailure(CallableError.concurrency, detail: '$error');
    }
  }

  Future<Response> _execute(
    CallableRequest call,
    PermissionSyncOperation operation,
  ) async {
    final AccountRecord actor = await _identity.verifyIdToken(call.idToken);

    final String? targetUserId = call.readString(targetUserIdField);
    final String? requestId = call.readString(requestIdField);
    if (targetUserId == null || requestId == null) {
      return callableFailure(CallableError.invalidArgument);
    }

    final SourceScope? scope = _readScope(call);
    final Set<Permission>? permissions = _readPermissions(call, operation);
    if (scope == null || permissions == null) {
      return callableFailure(CallableError.invalidArgument);
    }

    final AccountRecord target = await _identity.lookupByUserId(targetUserId);
    final PermissionSyncPlan plan = planPermissionSync(
      PermissionSyncRequest(
        actor: actor,
        target: target,
        desired: DesiredAccess(permissions: permissions, scope: scope),
        requestId: requestId,
      ),
      operation,
    );

    return switch (plan) {
      PermissionSyncRejected(:final CallableError error) =>
        callableFailure(error),
      PermissionSyncAccepted() => await _apply(plan, target.userId),
    };
  }

  /// يلتزم بالمعاملة ثم يكتب المطالبات — **بهذا الترتيب حصراً**.
  Future<Response> _apply(
    PermissionSyncAccepted plan,
    String targetUserId,
  ) async {
    await _transaction.run<void>(
      // ⛔ لا قراءات: القيم «قبل» تأتي من خدمة المصادقة لا من الدفتر، فبطاقة
      //    المستخدم مشتقّة منها لا مصدراً لها.
      readPaths: const <String>[],
      plan: (TransactionReads reads) => AuditedWrite<void>(
        documents: <PendingDocument>[
          PendingDocument(
            collectionId: usersCollection,
            documentId: targetUserId,
            fields: plan.userFields,
            updateMask: plan.updateMask,
          ),
        ],
        entry: plan.entry,
        result: null,
      ),
    );

    await _identity.writeClaims(userId: targetUserId, claims: plan.claims);

    return callableSuccess(<String, Object?>{
      'userId': targetUserId,
      // ★★ `ADR-0016`: **السبب صار النطاق لا الصلاحيات.**
      //   الصلاحيات تسري فوراً (مصدرها `users/{userId}`)، ⚠️ **ونطاق
      //   المصادر وحده يبقى في المطالبات** — وهاتان العمليتان تكتبانه،
      //   فيلزم تحديث الرمز لسريانه. (`authentication-policy.md` §3)
      'tokenRefreshRequired': true,
    });
  }

  /// يقرأ النطاق من الحمولة — `'all'` أو قائمة غير فارغة.
  static SourceScope? _readScope(CallableRequest call) {
    final Object? raw = call.data[sourceScopeClaimKey];
    if (raw == allSourcesClaimValue) return const AllSources();
    final List<String>? ids = call.readStringList(sourceScopeClaimKey);
    if (ids == null || ids.isEmpty) return null;
    return ScopedSources(ids.toSet());
  }

  /// يقرأ الصلاحيات — ⛔ **صارم: مفتاح مجهول يُبطل الطلب كله**.
  ///
  /// ⚠️ **ولا يُتساهَل هنا كما يُتساهَل في فكّ الرمز:** قبول مفتاح مجهول في
  /// **الكتابة** يعني تخزين صلاحية لا سطر لها في الكتالوج — وهو ما يرفضه
  /// `BR-M1-07` نصّاً.
  static Set<Permission>? _readPermissions(
    CallableRequest call,
    PermissionSyncOperation operation,
  ) {
    if (operation == PermissionSyncOperation.setSourceScope) {
      // النطاق وحده — ولا تُقرأ الصلاحيات أصلاً فلا تُمَسّ.
      return const <Permission>{};
    }
    final List<String>? names = call.readStringList(permissionsClaimKey);
    if (names == null) return null;
    final Set<Permission> permissions = <Permission>{};
    for (final String name in names) {
      final Permission? key = _byName(name);
      if (key == null) return null;
      permissions.add(key);
    }
    return permissions;
  }

  static Permission? _byName(String name) {
    for (final Permission p in Permission.values) {
      if (p.name == name) return p;
    }
    return null;
  }

  static CallableError _mapIdentityFailure(IdentityGatewayException error) =>
      switch (error.failure) {
        IdentityFailure.invalidToken => CallableError.sessionExpired,
        IdentityFailure.accountNotFound => CallableError.invalidArgument,
        // ★ `IQ-008` — الحمولة تجاوزت حدّ المنصة. ⛔ ولا تُقتطَع صامتة.
        IdentityFailure.claimsTooLarge => CallableError.internal,
        // ⛔ **لا مسار لهذا هنا** — هذه العملية لا تُنشئ حساباً أصلاً. ★ وهي
        //    مذكورة صراحةً ⛔ **لا بنمطٍ شامل (`_`)**: النمط الشامل كان
        //    سيبتلع **أي تصنيف يُضاف غداً** بلا أن يُنبِّه أحداً، ⟵ فيصل
        //    المستخدمَ رمزٌ عام بدل رمزه الصحيح. **والتصريف هو الحارس.**
        IdentityFailure.emailAlreadyExists => CallableError.internal,
      };
}

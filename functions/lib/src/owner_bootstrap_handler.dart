/// تنفيذ إقلاع صلاحيات المالك — **الطرف الذي يلمس الشبكة**.
///
/// ★ **مفصول عن `owner_bootstrap.dart` عمداً**، بنفس منطق
/// `permission_sync_handler.dart`: كل قرار تفويض هناك في دوال خالصة تُختبَر
/// بلا سحابة؛ وهنا **الترتيب والأثر** وحدهما.
///
/// ★ **وترتيب الأثر نفسه ولا يُعكَس:** ① المعاملة الذرّية (البطاقة **وقيد
/// التدقيق معاً**) ثم ② المطالبات — فلو فشلت المطالبات بقي المالك بصلاحية
/// **أقل** مما سُجِّل، وهو الاتجاه الآمن، وتُصلحه إعادة الاستدعاء بنفس
/// `requestId`.
library;

import 'package:shelf/shelf.dart';

import 'audited_transaction.dart';
import 'callable.dart';
import 'identity_gateway.dart';
import 'owner_bootstrap.dart';
import 'permission_sync.dart';
// ★ لأجل `requestIdField` وحده — اسم الحقل يُكتب مرة واحدة فلا تفترق نسختان.
import 'permission_sync_handler.dart';

/// منفّذ إقلاع المالك.
final class OwnerBootstrapHandler {
  /// ينشئ المنفّذ بتبعياته — ★ **تُحقَن، فيُختبَر بلا سحابة**.
  const OwnerBootstrapHandler({
    required IdentityGateway identity,
    required AuditedTransaction transaction,
    required String registeredOwnerUserId,
  })  : _identity = identity,
        _transaction = transaction,
        _registeredOwnerUserId = registeredOwnerUserId;

  final IdentityGateway _identity;
  final AuditedTransaction _transaction;

  /// ★ **من إعداد البيئة لا من الحمولة** — راجع [OwnerBootstrapRequest].
  final String _registeredOwnerUserId;

  /// ينفّذ الإقلاع على طلب HTTP خام.
  Future<Response> handle(Request httpRequest) async {
    final CallableParse parsed = await parseCallableRequest(httpRequest);
    if (parsed is RejectedCallable) return callableFailure(parsed.error);
    final CallableRequest call = (parsed as ParsedCallable).request;

    try {
      return await _execute(call);
    } on IdentityGatewayException catch (error) {
      return callableFailure(
        _mapIdentityFailure(error),
        detail: error.diagnostic,
      );
    } on TransactionContentionException catch (error) {
      // ⛔ ليس ابتلاعاً: يصل المُستدعي رمز تعارض صريح فيُعيد المحاولة.
      return callableFailure(CallableError.concurrency, detail: '$error');
    }
  }

  Future<Response> _execute(CallableRequest call) async {
    final AccountRecord actor = await _identity.verifyIdToken(call.idToken);

    final String? requestId = call.readString(requestIdField);
    if (requestId == null) {
      return callableFailure(CallableError.invalidArgument);
    }

    final OwnerBootstrapPlan plan = planOwnerBootstrap(
      OwnerBootstrapRequest(
        actor: actor,
        registeredOwnerUserId: _registeredOwnerUserId,
        requestId: requestId,
      ),
    );

    return switch (plan) {
      OwnerBootstrapRejected(:final CallableError error) =>
        callableFailure(error),
      // ★ نجاح صريح يميّز «لم يتغيّر شيء» عن «مُنِح الآن» — فيرى المشغّل في
      //   الرَنبوك أيّهما حدث، ⛔ ولا يُخفى الفرق تحت نجاح واحد مبهم.
      OwnerBootstrapAlreadyDone() => callableSuccess(<String, Object?>{
          'userId': actor.userId,
          'alreadyBootstrapped': true,
          'tokenRefreshRequired': false,
        }),
      OwnerBootstrapAccepted() => await _apply(plan, actor.userId),
    };
  }

  /// يلتزم بالمعاملة ثم يكتب المطالبات — **بهذا الترتيب حصراً**.
  Future<Response> _apply(
    OwnerBootstrapAccepted plan,
    String ownerUserId,
  ) async {
    await _transaction.run<void>(
      // ⛔ لا قراءات: القيم «قبل» تأتي من خدمة المصادقة لا من الدفتر.
      readPaths: const <String>[],
      plan: (TransactionReads reads) => AuditedWrite<void>(
        documents: <PendingDocument>[
          PendingDocument(
            collectionId: usersCollection,
            documentId: ownerUserId,
            fields: plan.userFields,
            updateMask: plan.updateMask,
          ),
        ],
        entry: plan.entry,
        result: null,
      ),
    );

    await _identity.writeClaims(userId: ownerUserId, claims: plan.claims);

    return callableSuccess(<String, Object?>{
      'userId': ownerUserId,
      'alreadyBootstrapped': false,
      // ★★ `ADR-0016`: **لا يحتاج تحديث رمز** — الإقلاع يمنح **صلاحيات فقط**،
      //   ومصدرها `users/{userId}` تقرأه القاعدة عند كل عملية.
      //   ⛔ **ولا يمسّ نطاق المصادر** وهو وحده الباقي في المطالبات.
      //   ⟵ فالمطالبات المكتوبة مطابقة لما كانت، والسريان فوري.
      'tokenRefreshRequired': false,
    });
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

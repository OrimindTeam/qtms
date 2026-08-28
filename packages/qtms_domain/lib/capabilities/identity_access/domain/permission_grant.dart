/// قواعد منح الصلاحيات وسحبها — **قبل أي كتابة**.
///
/// ★ **المصدر:** `FR-M1-08` («لا يمكن لمستخدم منح نفسه صلاحية لا يملكها ولا
/// توسيع نطاق مصادره بنفسه» · `BR-M1-03`) · `authentication-policy.md` §3
/// («لا مستخدم يعدّل صلاحيات نفسه — **ولو كان المالك**») ·
/// `api-overview.md` §3.1 («**يُرفَض منح صلاحية لا يملكها المُنفِّذ**»).
///
/// ⚠️ **وهذه القواعد لا تُجيب عن سؤال «من يُصرَّح له بالمنح أصلاً»** — فذلك
/// **مُصعَّد في `IQ-007`** ولا مفتاح له في الكتالوج. ما هنا هو ما **يبقى
/// صحيحاً أياً كانت إجابته**: حتى لو صار زيدٌ مخوَّلاً بالمنح، **يظل ممنوعاً
/// من منح ما لا يملك ومن تعديل صلاحيات نفسه**.
library;

import '../../../core/errors/app_error.dart';
import '../../../core/outcome.dart';
import 'permission.dart';
import 'source_scope.dart';

/// طلب تعديل صلاحيات مستخدم.
final class PermissionGrantRequest {
  const PermissionGrantRequest({
    required this.actorUserId,
    required this.actorPermissions,
    required this.actorScope,
    required this.targetUserId,
    required this.requestedPermissions,
    required this.requestedScope,
  });

  /// مُنفِّذ العملية.
  final String actorUserId;
  final Set<Permission> actorPermissions;
  final SourceScope actorScope;

  /// المستخدم المستهدَف.
  final String targetUserId;
  final Set<Permission> requestedPermissions;
  final SourceScope requestedScope;
}

/// نتيجة الفحص عند القبول — **الصلاحيات والنطاق كما يُكتبان**.
final class ApprovedGrant {
  const ApprovedGrant({required this.permissions, required this.scope});

  final Set<Permission> permissions;
  final SourceScope scope;
}

/// يفحص طلب المنح مقابل قواعد `BR-M1-03` و`FR-M1-08`.
///
/// يُرجِع [Failure] بـ[PermissionError] عند أي مخالفة، ⛔ **ولا يرمي** —
/// `error-handling-strategy.md` §3 القاعدة 3.
///
/// ★ **الترتيب مقصود:** يُفحَص «لا يعدّل نفسه» **أولاً**، لأنه يمنع الطلب
/// كاملاً بغضّ النظر عن محتواه — فلا معنى لفحص محتوى طلبٍ مرفوض أصلاً.
Outcome<ApprovedGrant> validatePermissionGrant(PermissionGrantRequest request) {
  // ① `authentication-policy.md` §3: لا مستخدم يعدّل صلاحيات نفسه — ولو المالك.
  //    ★ ولا استثناء هنا إطلاقاً: الاستثناء للمالك كان سيجعل حسابه قادراً
  //      على منح نفسه كل شيء، فيسقط `BR-M1-03` من أصله.
  if (request.actorUserId == request.targetUserId) {
    return const Failure<ApprovedGrant>(PermissionError());
  }

  // ② `BR-M1-03`: يُرفَض منح صلاحية لا يملكها المُنفِّذ.
  final Set<Permission> beyondActor =
      request.requestedPermissions.difference(request.actorPermissions);
  if (beyondActor.isNotEmpty) {
    return const Failure<ApprovedGrant>(PermissionError());
  }

  // ③ `FR-M1-08`: ولا توسيع نطاق يتجاوز نطاق المُنفِّذ نفسه.
  if (!scopeIsWithin(request.requestedScope, request.actorScope)) {
    return const Failure<ApprovedGrant>(PermissionError());
  }

  return Success<ApprovedGrant>(
    ApprovedGrant(
      permissions: Set<Permission>.unmodifiable(request.requestedPermissions),
      scope: request.requestedScope,
    ),
  );
}

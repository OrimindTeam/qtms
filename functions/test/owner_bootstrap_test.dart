import 'dart:convert';

import 'package:qtms_domain/qtms_domain.dart';
import 'package:qtms_functions/src/callable.dart';
import 'package:qtms_functions/src/identity_claims.dart';
import 'package:qtms_functions/src/identity_gateway.dart';
import 'package:qtms_functions/src/owner_bootstrap.dart';
import 'package:qtms_functions/src/permission_sync.dart';
import 'package:test/test.dart';

/// معرّف المالك المسجَّل في هذه الاختبارات — يحاكي `QTMS_OWNER_UID`.
const String ownerUid = 'uid-owner';

/// حساب مُعدّ للاختبار — ⛔ بلا أي اتصال بخدمة المصادقة.
AccountRecord account({
  required String userId,
  Set<Permission> permissions = const <Permission>{},
  SourceScope? scope,
  bool disabled = false,
  String userName = 'المالك',
  bool? cardIsActive,
}) =>
    AccountRecord(
      userId: userId,
      userName: userName,
      claims: IdentityClaims(permissions: permissions, sourceScope: scope),
      disabled: disabled,
      // ★★ `IQ-017`: الافتراضي `null` = **بطاقةٌ بلا حقل حالة**، وهي حالة
      //    كل بطاقة كُتبت قبل هذا الحقل — ⛔ وليست حالة نظرية.
      cardIsActive: cardIsActive,
    );

OwnerBootstrapRequest request({
  AccountRecord? actor,
  String registeredOwner = ownerUid,
  String requestId = 'REQ-BOOT-0001',
}) =>
    OwnerBootstrapRequest(
      actor: actor ?? account(userId: ownerUid),
      registeredOwnerUserId: registeredOwner,
      requestId: requestId,
    );

CallableError? rejectionOf(OwnerBootstrapPlan plan) =>
    plan is OwnerBootstrapRejected ? plan.error : null;

OwnerBootstrapAccepted acceptedOf(OwnerBootstrapPlan plan) =>
    plan as OwnerBootstrapAccepted;

void main() {
  group('★ IQ-007 — كسر حلقة الإقلاع: الهوية وحدها هي التفويض', () {
    test('★ المالك المسجَّل **بلا صلاحية إطلاقاً** يُقبَل — وهذا جوهر الإقلاع',
        () {
      // ⚠️ الحالة الحقيقية لا النظرية: `environments.md` §1.3 — الحساب قائم
      //    بلا صلاحيات. ولو اشترطنا صلاحيةً هنا لأقفل النظام على نفسه أبداً.
      final OwnerBootstrapPlan plan = planOwnerBootstrap(request());
      expect(plan, isA<OwnerBootstrapAccepted>());
    });

    test('⛔ ومَن ليس المالكَ المسجَّل يُرفَض ولو ملك كل صلاحيات النظام', () {
      final OwnerBootstrapPlan plan = planOwnerBootstrap(
        request(
          actor: account(
            userId: 'uid-someone-else',
            permissions: Permission.values.toSet(),
          ),
        ),
      );
      expect(rejectionOf(plan), CallableError.permissionMissing);
    });

    test('⛔ ومعرّف مالك غير مضبوط يرفض الجميع — ولا يُخمَّن مالك', () {
      final OwnerBootstrapPlan plan =
          planOwnerBootstrap(request(registeredOwner: '   '));
      expect(rejectionOf(plan), CallableError.permissionMissing);
    });

    test('★ وحساب معطَّل يُرفَض ولو كان المالك — «التعطيل فوري ونافذ»', () {
      final OwnerBootstrapPlan plan = planOwnerBootstrap(
        request(actor: account(userId: ownerUid, disabled: true)),
      );
      expect(rejectionOf(plan), CallableError.accountDisabled);
    });

    test('⛔ ومعرّف طلب فارغ يُرفَض — بلا لاتكرارية لا كتابة', () {
      final OwnerBootstrapPlan plan = planOwnerBootstrap(
        request(requestId: '  '),
      );
      expect(rejectionOf(plan), CallableError.invalidArgument);
    });
  });

  group('★ ما يُمنَح بالضبط — التسعة الإدارية ولا شيء سواها', () {
    test('★ التسعة كلها تُمنَح — والمجموعة من طبقة النطاق لا مكرَّرة هنا', () {
      final OwnerBootstrapAccepted plan =
          acceptedOf(planOwnerBootstrap(request()));
      expect(
        plan.claims.permissions,
        containsAll(identityAccessAdminPermissions),
      );
      expect(identityAccessAdminPermissions, hasLength(9));
    });

    test(
      '★★★ IQ-023: ويُمنَح كلَّ مفاتيح الكتالوج — ⛔ لا التسعة الإدارية وحدها',
      () {
        // ⚠️⚠️ **انقلب القرار السابق («ولا صلاحية تشغيلية تتسرّب») بـ`IQ-023`
        //    الخيار (أ) — 2026-08-26.** ★ **والسبب مقيسٌ حيّاً:** `BR-M1-03`
        //    تسقُف المنح بصلاحيات المُنفِّذ ⟵ **فمالكٌ بالتسعة لا يمنح أحداً
        //    صلاحيةً تشغيلية أبداً**، ⛔ **ولا أحد غيره يملكها ليمنحها.**
        final OwnerBootstrapAccepted plan =
            acceptedOf(planOwnerBootstrap(request()));
        expect(plan.claims.permissions, hasLength(Permission.values.length));
        expect(plan.claims.permissions, containsAll(Permission.values));
      },
    );

    test('★★★ IQ-022: ونطاق المالك يُمنَح `all` مع التسعة — في المعاملة نفسها',
        () {
      // ⚠️⚠️ **انقلب القرار السابق («لا يُمَسّ النطاق») بـ`IQ-022` الخيار (أ)
      //    — 2026-08-26.** ★ **والسبب مقيسٌ حيّاً لا نظري:** تركُه فارغاً
      //    **يقفل البيئة على نفسها**: المنح يشترط نطاقاً للمُنفِّذ · والنطاق
      //    يُمنَح بعمليةٍ تشترطه أيضاً · ⛔ **والمالك لا يمنح نفسه**.
      final OwnerBootstrapAccepted plan =
          acceptedOf(planOwnerBootstrap(request()));
      expect(plan.claims.sourceScope, isA<AllSources>());
      // ★★ **ويُكتب في البطاقة فعلاً** — ⛔ **لا في المطالبات وحدها**، وإلا
      //    بقي الفحص ③ في `permission_sync.dart` يرفض (يقرأ البطاقة).
      expect(plan.userFields[sourceScopeField], allSourcesClaimValue);
      expect(
        plan.updateMask,
        <String>[permissionsField, sourceScopeField, userIsActiveField],
      );
      expect(plan.userFields[userIsActiveField], isTrue);
    });

    test(
      '⛔⛔★★★ IQ-022: بطاقةٌ بالتسعة و`isActive` ⛔ بلا نطاق ⟵ تُصلَح لا تُترَك',
      () {
        // ★★★ **هذا هو الحارس على الحلقة المغلقة نفسها.** ⚠️ **والحالة ليست
        //   نظرية:** بطاقة مالك التجريبية كانت بهذا الوصف حرفياً بعد إقلاع
        //   2026-08-26 — ⟵ **فرُفض منحُه لحساب الاختبار بـ`ERR_AUTH_001`**،
        //   ⛔ **ولو أُرجعت «تمّ سابقاً» لَما كُتب النطاق أبداً ولبقي القفل.**
        final OwnerBootstrapPlan plan = planOwnerBootstrap(
          request(
            actor: account(
              userId: ownerUid,
              permissions: identityAccessAdminPermissions,
              cardIsActive: true,
            ),
          ),
        );
        expect(plan, isA<OwnerBootstrapAccepted>());
        expect(acceptedOf(plan).claims.sourceScope, isA<AllSources>());
      },
    );

    test('★ وصلاحية سابقة للمالك تبقى — اتحاد لا استبدال', () {
      final OwnerBootstrapAccepted plan = acceptedOf(
        planOwnerBootstrap(
          request(
            actor: account(
              userId: ownerUid,
              permissions: <Permission>{Permission.sackView},
              scope: const AllSources(),
            ),
          ),
        ),
      );
      expect(plan.claims.permissions, contains(Permission.sackView));
      expect(plan.claims.sourceScope, isA<AllSources>());
    });
  });

  group('★ ADR-0013 القاعدة 1 — المستند وقيده معاً', () {
    test('★ قيد التدقيق يحمل معرّف الطلب نفسه — فلا قيد ثانٍ عند الإعادة', () {
      final OwnerBootstrapAccepted plan =
          acceptedOf(planOwnerBootstrap(request(requestId: 'REQ-BOOT-0042')));
      expect(plan.entry.id, 'REQ-BOOT-0042');
      expect(plan.entry.action, AuditAction.permissionChange);
    });

    test('★ والمالك هو الفاعل والمستهدَف معاً — وهو استثناء الإقلاع المعلَن',
        () {
      final OwnerBootstrapAccepted plan =
          acceptedOf(planOwnerBootstrap(request()));
      expect(plan.entry.actor.userId, ownerUid);
      expect(plan.entry.target.entityId, ownerUid);
      expect(plan.entry.target.entityType, userEntityType);
    });

    test('★ والقيد يوثّق «قبل» الفارغة و«بعد» التسعة — لا الحالة النهائية وحدها',
        () {
      final OwnerBootstrapAccepted plan =
          acceptedOf(planOwnerBootstrap(request()));
      expect(plan.entry.valuesBefore[permissionsField], isEmpty);
      // ★★ `IQ-023`: **«بعد» صارت كلَّ الكتالوج لا التسعة.**
      expect(
        (plan.entry.valuesAfter[permissionsField]! as Map<String, Object?>)
            .length,
        Permission.values.length,
      );
    });
  });

  group('★ قابلية التكرار بلا أثر جانبي — coding-standards §2.7', () {
    test('★ الاستدعاء الثاني بعد الإقلاع لا يكتب ولا يُسجِّل قيداً', () {
      // ⛔ قيدٌ بلا تغيير يُلوِّث السجل بضجيج يُخفي التغييرات الحقيقية.
      final OwnerBootstrapPlan plan = planOwnerBootstrap(
        request(
          actor: account(
            userId: ownerUid,
            // ★★ `IQ-023`: **بطاقةٌ مكتملة = كلُّ الكتالوج** لا التسعة.
            permissions: ownerBootstrapPermissions,
            // ★ **وحقلُ الحالة والنطاق كذلك** (`IQ-017` · `IQ-022`) —
            //   والثلاثة معاً وحدها تعني «تمّ سابقاً».
            cardIsActive: true,
            scope: const AllSources(),
          ),
        ),
      );
      expect(plan, isA<OwnerBootstrapAlreadyDone>());
    });

    test(
      '⚠️★★ IQ-017: بطاقةٌ بالصلاحيات التسع ⛔ بلا isActive ⟵ تُصلَح لا تُترَك',
      () {
        // ★★ **هذا الاختبار هو الحارس على قفل المالك خارج نظامه** — والحالة
        //   ليست نظرية: **بطاقة المالك في البيئتين اليوم بهذا الوصف حرفياً**
        //   (أُقلعت قبل وجود الحقل). ⛔ **ولو أُرجعت «تمّ سابقاً» لَما كُتب
        //   `isActive` أبداً**، وبعد تشديد `perm()` يصير مالكاً بكل
        //   الصلاحيات **ولا واحدة منها تسري** — ولا مسار لإصلاحه، لأن كل
        //   مسارات المنح تشترط صلاحيةً لا تسري له. ⟵ **حلقة إقلاع ثانية.**
        final OwnerBootstrapPlan plan = planOwnerBootstrap(
          request(
            actor: account(
              userId: ownerUid,
              permissions: identityAccessAdminPermissions,
            ),
          ),
        );
        expect(plan, isA<OwnerBootstrapAccepted>());
        final OwnerBootstrapAccepted accepted = acceptedOf(plan);
        expect(accepted.userFields[userIsActiveField], isTrue);
        expect(accepted.updateMask, contains(userIsActiveField));
      },
    );

    test(
      '★ IQ-017: وبطاقةٌ ناقصة الصلاحيات وبها isActive ⟵ تُقلَع كالمعتاد',
      () {
        final OwnerBootstrapPlan plan = planOwnerBootstrap(
          request(actor: account(userId: ownerUid, cardIsActive: true)),
        );
        expect(plan, isA<OwnerBootstrapAccepted>());
      },
    );

    test('★ ونفس الطلب يُنتج نفس الخطة حرفياً', () {
      final OwnerBootstrapAccepted first =
          acceptedOf(planOwnerBootstrap(request()));
      final OwnerBootstrapAccepted second =
          acceptedOf(planOwnerBootstrap(request()));
      expect('${first.userFields}', '${second.userFields}');
      expect(first.updateMask, second.updateMask);
    });

    test('★ ونقصُ صلاحية واحدة يُعيد الإقلاع لا يعتبره تامّاً', () {
      final Set<Permission> allButOne =
          identityAccessAdminPermissions.toSet()..remove(Permission.roleDelete);
      final OwnerBootstrapPlan plan = planOwnerBootstrap(
        request(
          actor: account(userId: ownerUid, permissions: allButOne),
        ),
      );
      expect(plan, isA<OwnerBootstrapAccepted>());
    });
  });

  group('★ IQ-008 — حمولة الإقلاع تحت حدّ المنصة', () {
    test('★ التسعة الإدارية تُرمَّز فعلاً ولا ترمي — فالإقلاع غير محجوب', () {
      // ⚠️ يُثبت أن `IQ-008` **لا يعطّل `WU-000`**: حمولة المالك بعد الإقلاع
      //    تسعُ صلاحيات وحدها، لا اثنتان وسبعون.
      final OwnerBootstrapAccepted plan =
          acceptedOf(planOwnerBootstrap(request()));
      expect(plan.claims.encode, returnsNormally);
      expect(
        utf8.encode(plan.claims.encode()).length,
        lessThan(maxCustomClaimsBytes),
      );
    });
  });
}

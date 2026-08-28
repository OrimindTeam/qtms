import 'package:qtms_domain/qtms_domain.dart';
import 'package:qtms_functions/src/callable.dart';
import 'package:qtms_functions/src/identity_claims.dart';
import 'package:qtms_functions/src/identity_gateway.dart';
import 'package:qtms_functions/src/permission_sync.dart';
import 'package:test/test.dart';

/// حساب مُعدّ للاختبار — ⛔ بلا أي اتصال بخدمة المصادقة.
AccountRecord account({
  required String userId,
  Set<Permission> permissions = const <Permission>{},
  SourceScope? scope = const AllSources(),
  bool disabled = false,
  String userName = 'مستخدم',
}) =>
    AccountRecord(
      userId: userId,
      userName: userName,
      claims: IdentityClaims(permissions: permissions, sourceScope: scope),
      disabled: disabled,
    );

/// مُنفِّذ مخوَّل بالكامل — الحالة المرجعية التي تنجح.
AccountRecord fullActor({SourceScope? scope = const AllSources()}) => account(
      userId: 'uid-actor',
      userName: 'المالك',
      permissions: <Permission>{
        Permission.permissionGrant,
        Permission.sourceScopeSet,
        Permission.sackView,
        Permission.itemWrite,
      },
      scope: scope,
    );

PermissionSyncRequest request({
  AccountRecord? actor,
  AccountRecord? target,
  Set<Permission> desired = const <Permission>{Permission.sackView},
  SourceScope desiredScope = const AllSources(),
  String requestId = 'REQ-0001',
}) =>
    PermissionSyncRequest(
      actor: actor ?? fullActor(),
      target: target ?? account(userId: 'uid-target'),
      desired: DesiredAccess(permissions: desired, scope: desiredScope),
      requestId: requestId,
    );

CallableError? rejectionOf(
  PermissionSyncPlan plan,
) =>
    plan is PermissionSyncRejected ? plan.error : null;

void main() {
  group('★ ADR-0013 القاعدة 3 — التفويض يُفحَص في الكود لا في القواعد', () {
    test('مُنفِّذ بلا `permissionGrant` يُرفَض — ERR_AUTH_001', () {
      final PermissionSyncPlan plan = planPermissionSync(
        request(
          actor: account(
            userId: 'uid-actor',
            permissions: <Permission>{Permission.sackView},
          ),
        ),
        PermissionSyncOperation.grantPermissions,
      );
      expect(rejectionOf(plan), CallableError.permissionMissing);
    });

    test('و`setSourceScope` تشترط مفتاحها هي لا مفتاح المنح', () {
      // ★ الخلط بينهما تصعيد امتياز صامت: من يملك المنح لا يملك بالضرورة
      //   «أخطر صلاحية في النظام».
      final AccountRecord granterOnly = account(
        userId: 'uid-actor',
        permissions: <Permission>{Permission.permissionGrant},
      );
      expect(
        rejectionOf(planPermissionSync(
          request(actor: granterOnly),
          PermissionSyncOperation.setSourceScope,
        )),
        CallableError.permissionMissing,
      );
      expect(
        planPermissionSync(
          request(actor: granterOnly, desired: <Permission>{}),
          PermissionSyncOperation.grantPermissions,
        ),
        isA<PermissionSyncAccepted>(),
      );
    });

    test('★ وحساب معطَّل يُرفَض فوراً — ERR_AUTH_004 لا انتظار انتهاء الجلسة', () {
      final PermissionSyncPlan plan = planPermissionSync(
        request(
          actor: account(
            userId: 'uid-actor',
            permissions: <Permission>{Permission.permissionGrant},
            disabled: true,
          ),
        ),
        PermissionSyncOperation.grantPermissions,
      );
      expect(rejectionOf(plan), CallableError.accountDisabled);
    });

    test('★ ومُنفِّذ بلا نطاق مصادر لا يمنح شيئاً — حال المالك قبل الإقلاع', () {
      final PermissionSyncPlan plan = planPermissionSync(
        request(actor: fullActor(scope: null)),
        PermissionSyncOperation.grantPermissions,
      );
      expect(rejectionOf(plan), CallableError.permissionMissing);
    });

    test('⛔ وطلب بلا معرّف يُرفَض — فلا لاتكرارية بلا مفتاح', () {
      for (final String id in <String>['', '   ']) {
        expect(
          rejectionOf(planPermissionSync(
            request(requestId: id),
            PermissionSyncOperation.grantPermissions,
          )),
          CallableError.invalidArgument,
        );
      }
    });
  });

  group('القيود الثلاثة من الكتالوج §2.10 — ولا استثناء لأحد', () {
    test('★ لا أحد يعدّل صلاحيات نفسه — ولو المالك', () {
      final AccountRecord owner = fullActor();
      final PermissionSyncPlan plan = planPermissionSync(
        PermissionSyncRequest(
          actor: owner,
          target: owner,
          desired: const DesiredAccess(
            permissions: <Permission>{Permission.sackView},
            scope: AllSources(),
          ),
          requestId: 'REQ-SELF',
        ),
        PermissionSyncOperation.grantPermissions,
      );
      expect(rejectionOf(plan), CallableError.permissionMissing);
    });

    test('★ ويُرفَض منح صلاحية لا يملكها المُنفِّذ — BR-M1-03 · ERR_AUTH_007', () {
      final PermissionSyncPlan plan = planPermissionSync(
        request(desired: <Permission>{Permission.disposalCreate}),
        PermissionSyncOperation.grantPermissions,
      );
      expect(rejectionOf(plan), CallableError.grantBeyondActor);
    });

    test('★ ولا توسيع نطاق فوق نطاق المُنفِّذ — FR-M1-08 · ERR_AUTH_002', () {
      final PermissionSyncPlan plan = planPermissionSync(
        request(
          actor: fullActor(scope: ScopedSources(<String>{'SRC-001'})),
          desiredScope: ScopedSources(<String>{'SRC-001', 'SRC-002'}),
        ),
        PermissionSyncOperation.grantPermissions,
      );
      expect(rejectionOf(plan), CallableError.sourceOutOfScope);
    });

    test('★ و`all` لا يقع داخل قائمة محدودة مهما طالت', () {
      // لأنه يشمل **ما سيُضاف مستقبلاً** — والقائمة لا تشمله أبداً (§4).
      final PermissionSyncPlan plan = planPermissionSync(
        request(
          actor: fullActor(scope: ScopedSources(<String>{'SRC-001', 'SRC-002'})),
        ),
        PermissionSyncOperation.grantPermissions,
      );
      expect(rejectionOf(plan), CallableError.sourceOutOfScope);
    });

    test('✅ والتضييق داخل نطاق المُنفِّذ مقبول', () {
      final PermissionSyncPlan plan = planPermissionSync(
        request(
          actor: fullActor(scope: ScopedSources(<String>{'SRC-001', 'SRC-002'})),
          desiredScope: ScopedSources(<String>{'SRC-001'}),
        ),
        PermissionSyncOperation.grantPermissions,
      );
      expect(plan, isA<PermissionSyncAccepted>());
    });
  });

  group('★ ADR-0013 القاعدة 1 — المستند وقيده معاً', () {
    late PermissionSyncAccepted accepted;

    setUp(() {
      accepted = planPermissionSync(
        request(desired: <Permission>{Permission.sackView, Permission.itemWrite}),
        PermissionSyncOperation.grantPermissions,
      ) as PermissionSyncAccepted;
    });

    test('لكل خطة مقبولة قيد تدقيق مقابل — ولا خطة بلا قيد', () {
      expect(accepted.entry.action, AuditAction.permissionChange);
      expect(accepted.entry.target.entityType, 'user');
      expect(accepted.entry.target.entityId, 'uid-target');
    });

    test('★ ومعرّف القيد هو معرّف الطلب — فإعادة الإرسال لا تُنشئ قيداً ثانياً', () {
      expect(accepted.entry.id, 'REQ-0001');
    });

    test('واسم المُنفِّذ منسوخ في القيد وقت الحدث', () {
      expect(accepted.entry.actor.userId, 'uid-actor');
      expect(accepted.entry.actor.userName, 'المالك');
    });

    test('★ والحقول المتغيرة وحدها في القيد — ⛔ لا نسخ للبطاقة كاملة', () {
      expect(accepted.entry.valuesAfter.keys.toSet(),
          <String>{'permissions', 'sourceScope'});
      expect(accepted.entry.valuesBefore.keys.toSet(),
          <String>{'permissions', 'sourceScope'});
    });

    test('★ وقناع الكتابة يحمي بقية حقول البطاقة من المحو', () {
      // ★★ `IQ-017`: **`isActive` انضمّ للقناع** — حقلُ مرآةٍ يُكتب مع كل
      //    كتابة صلاحيات، ⛔ **ولا يُكتب `permissions` بدونه** وإلا مُنِحت
      //    صلاحيةٌ لا تسري (`perm()` تشترطه). ⚠️ **والقناع ما يزال ضيّقاً:**
      //    ثلاثة حقول بأعيانها ⛔ **لا البطاقة كاملة** — والاسم والبريد
      //    خارجه كما كانا.
      expect(accepted.updateMask.toSet(),
          <String>{'permissions', 'sourceScope', 'isActive'});
      expect(accepted.userFields.keys.toSet(), accepted.updateMask.toSet());
      expect(accepted.userFields.containsKey('name'), isFalse);
      expect(accepted.userFields.containsKey('email'), isFalse);
    });

    test('★★ IQ-017: مستهدَفٌ حيٌّ في خدمة المصادقة ⟵ isActive تُكتب true', () {
      expect(accepted.userFields['isActive'], isTrue);
    });

    test(
      '⚠️★★ IQ-017: مستهدَفٌ معطَّل ⟵ ⛔ المنح لا يُعيد تفعيله',
      () {
        // ★ **أخطر حالة في هذا الحقل:** لو كُتبت `true` ثابتةً لَأعاد
        //   **منحُ صلاحيةٍ** تفعيلَ حسابٍ عُطِّل عمداً — ⛔ تصعيدُ امتيازٍ
        //   بأثرٍ جانبي، ★ **ولا إنذار يظهر** لأن العملية «نجحت».
        final PermissionSyncAccepted accepted = planPermissionSync(
          request(
            target: account(
              userId: 'uid-target',
              permissions: <Permission>{Permission.sackView},
              disabled: true,
            ),
          ),
          PermissionSyncOperation.grantPermissions,
        ) as PermissionSyncAccepted;
        expect(accepted.userFields['isActive'], isFalse);
      },
    );

    test('الصلاحيات تُخزَّن خريطةً بالممنوح وحده', () {
      expect(accepted.userFields['permissions'],
          <String, Object?>{'sackView': true, 'itemWrite': true});
    });

    test('والنطاق يُخزَّن `all` نصّاً كما تقرأه القاعدة', () {
      expect(accepted.userFields['sourceScope'], 'all');
    });
  });

  group('setSourceScope — النطاق وحده ولا يمسّ الصلاحيات', () {
    test('★ لا يُكتب حقل الصلاحيات إطلاقاً', () {
      final PermissionSyncAccepted accepted = planPermissionSync(
        request(
          target: account(
            userId: 'uid-target',
            permissions: <Permission>{Permission.sackView},
          ),
          desiredScope: ScopedSources(<String>{'SRC-001'}),
        ),
        PermissionSyncOperation.setSourceScope,
      ) as PermissionSyncAccepted;
      // ★ **الصلاحيات ما تزال غير مكتوبة إطلاقاً** — وهو جوهر الاختبار.
      //   ⚠️ **و`isActive` تُرافق كل كتابة بطاقة** (`IQ-017`) لا الصلاحيات
      //   وحدها، لأن بطاقةً بلا حقل حالة **بطاقةٌ بلا صلاحية تسري**.
      expect(accepted.updateMask, <String>['sourceScope', 'isActive']);
      expect(accepted.userFields.containsKey('permissions'), isFalse);
    });

    test('★ وصلاحيات المستهدَف تبقى كما هي في المطالبات الجديدة', () {
      final PermissionSyncAccepted accepted = planPermissionSync(
        request(
          target: account(
            userId: 'uid-target',
            permissions: <Permission>{Permission.sackView},
          ),
          desired: <Permission>{},
          desiredScope: ScopedSources(<String>{'SRC-001'}),
        ),
        PermissionSyncOperation.setSourceScope,
      ) as PermissionSyncAccepted;
      expect(accepted.claims.has(Permission.sackView), isTrue,
          reason: 'تحديد النطاق لا يسحب صلاحية — وإلا كان سحباً مقنَّعاً');
      expect(accepted.claims.sourceScope, ScopedSources(<String>{'SRC-001'}));
    });
  });

  group('قابلية التكرار بلا أثر جانبي — coding-standards §2.7', () {
    test('نفس الطلب يُنتج نفس الخطة حرفياً', () {
      final PermissionSyncAccepted first = planPermissionSync(
        request(desired: <Permission>{Permission.itemWrite, Permission.sackView}),
        PermissionSyncOperation.grantPermissions,
      ) as PermissionSyncAccepted;
      final PermissionSyncAccepted second = planPermissionSync(
        request(desired: <Permission>{Permission.sackView, Permission.itemWrite}),
        PermissionSyncOperation.grantPermissions,
      ) as PermissionSyncAccepted;
      expect(first.userFields.toString(), second.userFields.toString());
      expect(first.claims.encode(), second.claims.encode());
      expect(first.entry.id, second.entry.id);
    });
  });
}

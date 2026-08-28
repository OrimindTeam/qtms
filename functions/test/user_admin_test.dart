import 'package:qtms_domain/qtms_domain.dart';
import 'package:qtms_functions/src/callable.dart';
import 'package:qtms_functions/src/identity_claims.dart';
import 'package:qtms_functions/src/identity_gateway.dart';
import 'package:qtms_functions/src/permission_sync.dart';
import 'package:qtms_functions/src/user_admin.dart';
import 'package:test/test.dart';

const String ownerUid = 'uid-owner';
const String adminUid = 'uid-admin';
const String targetUid = 'uid-target';

AccountRecord account({
  required String userId,
  Set<Permission> permissions = const <Permission>{},
  bool disabled = false,
  bool? cardIsActive = true,
}) =>
    AccountRecord(
      userId: userId,
      userName: 'مدير',
      claims: IdentityClaims(
        permissions: permissions,
        sourceScope: const AllSources(),
      ),
      disabled: disabled,
      cardIsActive: cardIsActive,
    );

ValidatedUserProfile profile() =>
    (validateUserProfile(const UserProfileInput(
      name: 'أحمد',
      email: 'ahmed@example.com',
    )) as Success<ValidatedUserProfile>)
        .value;

UserAdminRequest request({
  AccountRecord? actor,
  String targetId = targetUid,
  String requestId = 'REQ-ADM-0001',
  String owner = ownerUid,
  ValidatedUserProfile? userProfile,
  String? disableReason,
  String? amendReason = 'تصحيح بيانات',
  ValidatedRole? role,
  RoleAssignmentCensus? census,
  Map<String, Object?>? roleBefore,
}) =>
    UserAdminRequest(
      actor: actor ??
          account(
            userId: adminUid,
            permissions: <Permission>{
              Permission.userCreate,
              Permission.userAmend,
              Permission.userDisable,
              Permission.roleWrite,
            },
          ),
      targetId: targetId,
      requestId: requestId,
      ownerUserId: owner,
      profile: userProfile,
      disableReason: disableReason,
      amendReason: amendReason,
      roleName: role,
      roleAssignment: census,
      roleBefore: roleBefore,
    );

/// ★ مُنفِّذ يملك `roleDelete` — ⛔ **ولا يملك `roleWrite`** ليُثبت أن الحذف
/// يُفحَص **بمفتاحه هو** لا بمفتاح مجاور ولا بحظر عام.
AccountRecord deleter() => account(
      userId: adminUid,
      permissions: <Permission>{Permission.roleDelete},
    );

/// ★ مستند الدور **كما يُقرأ من المعاملة** — ⛔ لا كما تظنّه الواجهة.
Map<String, Object?> roleDocument() => <String, Object?>{
      'name': 'محاسب',
      'normalizedName': normalizeName('محاسب'),
      'description': 'وصف',
    };

/// خطة حذف دور — بإحصاءٍ ومستندٍ يُمرَّران صراحةً.
UserAdminPlan deletionPlan({
  AccountRecord? actor,
  List<String>? assigned = const <String>[],
  Map<String, Object?>? before,
  String? amendReason = 'الدور لم يعد مستخدَماً',
}) =>
    planUserAdmin(
      request(
        actor: actor ?? deleter(),
        targetId: 'ROLE-1',
        amendReason: amendReason,
        census:
            assigned == null ? null : RoleAssignmentCensus.measured(assigned),
        roleBefore: before ?? roleDocument(),
      ),
      UserAdminOperation.deleteRole,
    );


UserAdminAccepted acceptedOf(UserAdminPlan plan) => plan as UserAdminAccepted;

String? codeOf(UserAdminPlan plan) => switch (plan) {
      UserAdminRejected(:final CallableError error) => error.code,
      UserAdminAccepted() => null,
    };

void main() {
  group('البوابة — الحالة قبل الصلاحية قبل المحتوى', () {
    test('⛔ المُنفِّذ المعطَّل يُرفَض — ولو ملك الصلاحية', () {
      // ★ «التعطيل فوري ونافذ» — `authentication-policy.md` §2 القاعدة 3.
      final UserAdminPlan plan = planUserAdmin(
        request(
          actor: account(
            userId: adminUid,
            permissions: <Permission>{Permission.userCreate},
            disabled: true,
          ),
          userProfile: profile(),
        ),
        UserAdminOperation.createUser,
      );
      expect(codeOf(plan), 'ERR_AUTH_004');
    });

    test('⛔★★ وبلا الصلاحية يُرفَض — وهذا السطر هو الحارس الوحيد', () {
      // ⚠️ **لا قاعدة حماية تحرس هذا المسار** (الكتالوج §2.10)، فالدالة
      //    تعمل بامتياز إداري يتجاوز القواعد — ⟵ **الكود هو الحارس**.
      for (final (UserAdminOperation op, Permission needed) in <(
        UserAdminOperation,
        Permission
      )>[
        (UserAdminOperation.createUser, Permission.userCreate),
        (UserAdminOperation.updateUser, Permission.userAmend),
        (UserAdminOperation.disableUser, Permission.userDisable),
        (UserAdminOperation.createRole, Permission.roleWrite),
        (UserAdminOperation.updateRole, Permission.roleWrite),
      ]) {
        // ★ **بكل الصلاحيات إلا المطلوبة** — فالرفض يُنسَب لغيابها هي
        //   ⛔ لا لفقرٍ عام في الصلاحيات.
        final Set<Permission> all = Permission.values.toSet()..remove(needed);
        final UserAdminPlan plan = planUserAdmin(
          request(
            actor: account(userId: adminUid, permissions: all),
            userProfile: profile(),
            disableReason: 'غادر',
            amendReason: 'تصحيح بيانات',
            role: (validateRole(name: 'محاسب') as Success<ValidatedRole>).value,
          ),
          op,
        );
        expect(codeOf(plan), 'ERR_AUTH_001', reason: op.name);
      }
    });

    test('⛔ ومعرّف الطلب الفارغ يُرفَض — فلا لاتكرارية بدونه', () {
      expect(
        codeOf(planUserAdmin(
          request(requestId: '  ', userProfile: profile()),
          UserAdminOperation.createUser,
        )),
        'ERR_CALL_400',
      );
    });
  });

  group('★ FR-M1-01 — إنشاء مستخدم', () {
    test('✅ يكتب البطاقة بحقولها، ★ و`isActive: true` معها (IQ-017)', () {
      final UserAdminAccepted plan = acceptedOf(planUserAdmin(
        request(userProfile: profile()),
        UserAdminOperation.createUser,
      ));
      expect(plan.collectionId, usersCollection);
      expect(plan.fields['name'], 'أحمد');
      expect(plan.fields['email'], 'ahmed@example.com');
      // ★★ بطاقةٌ بلا هذا الحقل بطاقةٌ بلا صلاحية تسري مهما مُنِحت لاحقاً.
      expect(plan.fields[userIsActiveField], isTrue);
    });

    test('⛔★★ ولا يمنح صلاحية واحدة — الخريطة فارغة عمداً', () {
      // ⚠️ **ولو مُنِحت هنا لَالتفّت على `BR-M1-03`** («لا يمنح المُنفِّذ ما
      //    لا يملك») — فهذه العملية لا تفحص تلك القاعدة أصلاً.
      final UserAdminAccepted plan = acceptedOf(planUserAdmin(
        request(userProfile: profile()),
        UserAdminOperation.createUser,
      ));
      expect(plan.fields[permissionsField], isEmpty);
    });

    test('⛔ ولا يكتب نطاق مصادر — مسارُه `setSourceScope` بقواعده', () {
      final UserAdminAccepted plan = acceptedOf(planUserAdmin(
        request(userProfile: profile()),
        UserAdminOperation.createUser,
      ));
      expect(plan.fields.containsKey(sourceScopeField), isFalse);
    });

    test('⛔★ ولا حقل كلمة مرور ولا معرّف جهاز — FR-M1-02', () {
      final UserAdminAccepted plan = acceptedOf(planUserAdmin(
        request(userProfile: profile()),
        UserAdminOperation.createUser,
      ));
      for (final String forbidden in <String>[
        'password',
        'passwordHash',
        'deviceId',
      ]) {
        expect(plan.fields.containsKey(forbidden), isFalse);
      }
    });

    test('★ والقيد فعلُ إنشاء بلا قيمة «قبل» مخترَعة', () {
      final UserAdminAccepted plan = acceptedOf(planUserAdmin(
        request(userProfile: profile()),
        UserAdminOperation.createUser,
      ));
      expect(plan.entry.action, AuditAction.create);
      expect(plan.entry.valuesBefore, isEmpty);
      expect(plan.entry.target.entityType, userEntityType);
    });

    test('⛔ وبلا ملف مستخدم يُرفَض', () {
      expect(
        codeOf(planUserAdmin(request(), UserAdminOperation.createUser)),
        'ERR_CALL_400',
      );
    });
  });

  group('★★ BR-M1-02 — حساب المالك', () {
    test('⛔★★ غيرُ المالك لا يعدّل حساب المالك — ولو ملك `userAmend`', () {
      // ⚠️ **وبدونه يصير `userAmend` طريقاً لتعطيل المالك ثم الاستيلاء.**
      expect(
        codeOf(planUserAdmin(
          request(targetId: ownerUid, userProfile: profile()),
          UserAdminOperation.updateUser,
        )),
        'ERR_AUTH_001',
      );
    });

    test('✅ والمالك يعدّل حسابه هو', () {
      final UserAdminPlan plan = planUserAdmin(
        request(
          actor: account(
            userId: ownerUid,
            permissions: <Permission>{Permission.userAmend},
          ),
          targetId: ownerUid,
          userProfile: profile(),
        ),
        UserAdminOperation.updateUser,
      );
      expect(plan, isA<UserAdminAccepted>());
    });

    test('⛔★★ ومعرّف مالكٍ غائب = منعٌ لا سماح', () {
      // ★ لو سُمح عند غياب المعرّف لصار **إسقاطُ الإعداد** التفافاً كاملاً.
      expect(
        codeOf(planUserAdmin(
          request(owner: '   ', targetId: 'uid-any', userProfile: profile()),
          UserAdminOperation.updateUser,
        )),
        'ERR_AUTH_001',
      );
    });

    test('★ والحارس لا يسري على الإنشاء — لا معنى لحساب مالكٍ لم يوجد بعد', () {
      final UserAdminPlan plan = planUserAdmin(
        request(targetId: ownerUid, userProfile: profile()),
        UserAdminOperation.createUser,
      );
      expect(plan, isA<UserAdminAccepted>());
    });
  });

  group('★ التعديل — ⛔ لا يمسّ حالة الحساب', () {
    test('⛔★★ تعديلُ اسمٍ لا يُعيد تفعيل معطَّل', () {
      // ⚠️ **أخطر ما يمكن أن يفعله التعديل:** لو كتب `isActive: true` لَصار
      //    **تعديلُ اسمٍ إعادةَ تفعيلٍ صامتة** — تصعيدُ امتيازٍ بأثرٍ جانبي.
      final UserAdminAccepted plan = acceptedOf(planUserAdmin(
        request(userProfile: profile()),
        UserAdminOperation.updateUser,
      ));
      expect(plan.fields.containsKey(userIsActiveField), isFalse);
      expect(plan.updateMask, isNot(contains(userIsActiveField)));
    });

    test('⛔ ولا يمسّ الصلاحيات', () {
      final UserAdminAccepted plan = acceptedOf(planUserAdmin(
        request(userProfile: profile()),
        UserAdminOperation.updateUser,
      ));
      expect(plan.fields.containsKey(permissionsField), isFalse);
    });

    test('★ والقناع يحمي بقية حقول البطاقة من المحو', () {
      final UserAdminAccepted plan = acceptedOf(planUserAdmin(
        request(userProfile: profile()),
        UserAdminOperation.updateUser,
      ));
      expect(plan.updateMask.toSet(), plan.fields.keys.toSet());
      expect(plan.updateMask, isNot(contains(permissionsField)));
    });
  });

  group('★★ FR-M1-12 · FR-M1-15 — التعطيل', () {
    UserAdminAccepted disabled() => acceptedOf(planUserAdmin(
          request(disableReason: 'غادر العمل'),
          UserAdminOperation.disableUser,
        ));

    test('✅ يكتب `isActive: false` وسببه النصّي', () {
      final UserAdminAccepted plan = disabled();
      expect(plan.fields[userIsActiveField], isFalse);
      expect(plan.fields[userDisableReasonField], 'غادر العمل');
    });

    test('⛔ وبلا سبب يُرفَض — FR-M1-12', () {
      expect(
        codeOf(planUserAdmin(
          request(disableReason: '   '),
          UserAdminOperation.disableUser,
        )),
        'ERR_CALL_400',
      );
    });

    test('★★ ويعطّل الحساب في خدمة المصادقة أيضاً — IQ-017 الخيار ج', () {
      // ★ **النافذتان تُغلقان معاً:** البطاقة تمنع الرمزَ القائم عند كل
      //   عملية، والخدمة تمنع إصدارَ الجديد. ⛔ **ولا يكفي أحدهما.**
      expect(disabled().setAccountDisabled, isTrue);
    });

    test('★ والقيد فعلُ تعطيل مستقل لا «تعديل»', () {
      // ⟵ فيُقرأ من السجل بذاته ⛔ ولا يختفي بين تعديلات الأسماء.
      expect(disabled().entry.action, AuditAction.disable);
    });

    test('⛔ ولا حذف — والمستند يبقى بمعرّفه', () {
      final UserAdminAccepted plan = disabled();
      expect(plan.documentId, targetUid);
      expect(plan.collectionId, usersCollection);
    });
  });

  group('★ FR-M1-03 — كتابة الدور', () {
    UserAdminAccepted role() => acceptedOf(planUserAdmin(
          request(
            targetId: 'ROL-001',
            role: (validateRole(name: 'محاسب', description: 'وصف')
                    as Success<ValidatedRole>)
                .value,
          ),
          UserAdminOperation.createRole,
        ));

    test('✅ يكتب الاسم والاسم المُطبَّع والوصف', () {
      final UserAdminAccepted plan = role();
      expect(plan.collectionId, rolesCollection);
      expect(plan.fields['name'], 'محاسب');
      expect(plan.fields['normalizedName'], normalizeName('محاسب'));
      expect(plan.fields['description'], 'وصف');
    });

    test('★ والقيد على كيان الدور لا المستخدم', () {
      expect(role().entry.target.entityType, roleEntityType);
    });

  });

  // ═══════════════════════════════════════════════════════════════════
  // ★★★ IQ-018 (الخيار ب) — `roleDelete` = حذفٌ فعلي للدور غير المُسنَد
  //
  // ⚠️⚠️ **وكل اختبار هنا يُثبت السببَ الصحيح لا النتيجةَ وحدها:** الرفض
  //    يُفحَص **برمزه** — `ERR_SETUP_012` للمُسنَد · `ERR_AUTH_001` لنقص
  //    الصلاحية · `ERR_CALL_500` لإحصاءٍ لم يُقَس. ⟵ **فاختبارٌ ينجح لسببٍ
  //    غير مقصود يسقط هنا** ولا يمرّ.
  //    ⛔★★ **و`ERR_AMEND_002` لغياب السبب سقط بـ`ADR-0020`** (2026-08-27).
  // ═══════════════════════════════════════════════════════════════════
  group('★★★ IQ-018 — حذف الدور', () {
    test('✅★★ دورٌ غير مُسنَد يُحذف حذفاً فعلياً — ⛔ لا تعطيلاً', () {
      final UserAdminAccepted plan = acceptedOf(deletionPlan());
      // ★★ **حذفٌ صريح** — وهو الفارق الجوهري بين الخيارين أ وب.
      expect(plan.deletesDocument, isTrue);
      expect(plan.collectionId, rolesCollection);
      expect(plan.documentId, 'ROLE-1');
      // ⛔★★ **ولا حقل حالة للدور إطلاقاً** — `IQ-018` نصّاً: «لا يُنشأ حقل
      //    `isActive` للدور ولا يتحول `roleDelete` إلى تعطيل».
      expect(plan.fields, isEmpty);
      expect(plan.updateMask, isEmpty);
    });

    test('⛔★★★ ولا تنفيذ بديل خفي يُعطِّل بدل أن يحذف', () {
      // ⚠️ **حارسٌ مباشر على بند صاحب القرار:** «عدم وجود تنفيذ بديل خفي
      //    يقوم بالتعطيل بدلاً من الحذف». ⟵ **فلو تسرّب أي حقل حالة إلى
      //    خطة الحذف لسقط هذا السطر.**
      final UserAdminAccepted plan = acceptedOf(deletionPlan());
      expect(plan.fields.keys, isNot(contains(userIsActiveField)));
      expect(plan.fields.keys, isNot(contains('isActive')));
      expect(plan.fields.keys, isNot(contains('active')));
      expect(plan.fields.keys, isNot(contains('deleted')));
      expect(plan.setAccountDisabled, isNull);
      expect(plan.entry.action, isNot(AuditAction.disable));
    });

    test('⛔★★ ودورٌ مُسنَد لمستخدم واحد يُرفَض بـERR_SETUP_012', () {
      expect(
        codeOf(deletionPlan(assigned: <String>['uid-1'])),
        'ERR_SETUP_012',
      );
    });

    test('⛔★★ ودورٌ مُسنَد لعدة مستخدمين يُرفَض بالرمز نفسه', () {
      expect(
        codeOf(deletionPlan(assigned: <String>['uid-1', 'uid-2', 'uid-3'])),
        'ERR_SETUP_012',
      );
    });

    test('⛔★★★ وإحصاءٌ لم يُقَس يُرفَض — ⛔ ولا يُقرأ «غير مُسنَد»', () {
      // ★★ **الرفض الافتراضي:** نسيانُ الاستعلام **يوقف العملية** ⛔ ولا
      //    يمرّ صامتاً فيحذف دوراً مُسنَداً.
      expect(codeOf(deletionPlan(assigned: null)), 'ERR_CALL_500');
    });

    test('⛔★★ ومن لا يملك `roleDelete` يُرفَض — ولو ملك `roleWrite`', () {
      expect(
        codeOf(
          deletionPlan(
            actor: account(
              userId: adminUid,
              // ★ **كل مفاتيح الأدوار المجاورة بلا `roleDelete`** — ⟵ **فالرفض
              //   يُثبت أن المفتاح المقصود هو الحارس** لا حظرٌ عام.
              permissions: <Permission>{
                Permission.roleWrite,
                Permission.roleAssign,
                Permission.userAmend,
                Permission.userView,
              },
            ),
          ),
        ),
        'ERR_AUTH_001',
      );
    });

    // ⛔⛔★★★ **ارتدادُ `ADR-0020`:** ★ **كان الحذف بلا سبب يُرفَض** —
    //   ⚠️★★ **وهو أشدُّ ما أسقطه القرار** (`IQ-018`: «المحذوف لا يبقى
    //   ليُراجَع») ⟵ **عُرِض على المالك نصّاً فاختار التعميم.**
    test('✅★★ ADR-0020: وحذفٌ بلا سبب نصّي يمرّ — والقيد بلا نصّ مخترَع', () {
      expect(acceptedOf(deletionPlan(amendReason: null)).entry.reason, isNull);
      expect(acceptedOf(deletionPlan(amendReason: '   ')).entry.reason, isNull);
    });

    test('⛔★ وحذف دورٍ لا مستند له يُرفَض — ⛔ ولا ينجح صامتاً', () {
      expect(codeOf(deletionPlan(before: <String, Object?>{})), 'ERR_CALL_400');
    });

    test('★★ والقيد يحمل الفعل `delete` وكيان الدور وقيمَه «قبل»', () {
      final AuditEntry entry = acceptedOf(deletionPlan()).entry;
      // ★ **فعلٌ مستقل** — ⛔ لا `cancel` (وسمٌ لا حذف) ولا `disable`.
      expect(entry.action, AuditAction.delete);
      expect(entry.target.entityType, roleEntityType);
      expect(entry.target.entityId, 'ROLE-1');
      // ★★ **السجل يحفظ ما ضاع** — ⟵ فالحذف يبقى قابلاً للمراجعة.
      expect(entry.valuesBefore['name'], 'محاسب');
      expect(entry.valuesBefore['description'], 'وصف');
      // ★ **و«بعد» علامةُ غيابٍ صريحة** ⛔ لا خريطة فارغة تُقرأ «لم يتغيّر».
      expect(entry.valuesAfter[roleDeletedMarker], isTrue);
      expect(entry.reason, 'الدور لم يعد مستخدَماً');
    });

    test('★★ وخطة الحذف لا تمسّ أي مستخدم — لا حقلاً ولا مستنداً', () {
      // ⚠️ **بند صاحب القرار: «حذف دور لا يؤثر على أي مستخدم آخر».**
      final UserAdminAccepted plan = acceptedOf(
        deletionPlan(assigned: const <String>[]),
      );
      expect(plan.collectionId, isNot(usersCollection));
      expect(plan.collectionId, rolesCollection);
      expect(plan.documentId, 'ROLE-1');
      expect(plan.fields, isEmpty);
    });

    test('⛔★★ ودورٌ لا مستند له أصلاً يُرفَض — ⛔ ولا «حُذف» كاذبة', () {
      // ⚠️ **حالةٌ حقيقية:** ضغطتان متسارعتان على «حذف» — ★ **والثانية تجد
      //    المستند غائباً**. ⛔ **ونجاحٌ صامت هنا يكتب قيداً بلا «قبل»**،
      //    فيشهد السجل على حذفٍ لا يُعرَف ماذا كان.
      final UserAdminPlan plan = planUserAdmin(
        request(
          actor: deleter(),
          targetId: 'ROLE-GONE',
          amendReason: 'الدور لم يعد مستخدَماً',
          census: const RoleAssignmentCensus.measured(<String>[]),
        ),
        UserAdminOperation.deleteRole,
      );
      expect(codeOf(plan), 'ERR_CALL_400');
    });

    test('★ ومفتاح `roleDelete` هو صلاحية العملية المُعلَنة', () {
      expect(
        UserAdminOperation.deleteRole.requiredPermission,
        Permission.roleDelete,
      );
    });

    test('★ قابلية التكرار — نفس الطلب يُنتج نفس الخطة حرفياً', () {
      final UserAdminAccepted a = acceptedOf(deletionPlan());
      final UserAdminAccepted b = acceptedOf(deletionPlan());
      expect(a.entry.id, b.entry.id);
      expect(a.entry.valuesBefore, b.entry.valuesBefore);
      expect(a.deletesDocument, b.deletesDocument);
    });
  });


  // ═══════════════════════════════════════════════════════════════════
  // ★★★ DEBT-21 ① · CR-002 — «تعديل بلا سبب يُرفَض»
  //
  // ⚠️⚠️ **بندُ قبولٍ مُلزِم لا اختبارٌ عادي:** كانت قواعد الحماية تفرض
  //    `nonEmpty('amendReason')` على كل تعديل، ⛔ **ثم أُغلقت الكتابة
  //    المباشرة بـ`WU-026` فلم يعد أحدٌ يفرضه في أي مكان**. ★ **و`CR-002`
  //    (مقبول) نقل إثباتَه إلى أول دالة كاتبة** — ⟵ **وهذه هي أولُها**،
  //    ⛔ **ولا يُحتسَب الفحص الرابع في `product-roadmap.md` §0 مستوفىً
  //    حتى تفشل فيها حالةُ «تعديل بلا سبب» فعلياً**، وهذه هي.
  // ═══════════════════════════════════════════════════════════════════
  // ⛔⛔★★★ **و`ADR-0020` (2026-08-27) رفع الشرطَ كلَّه** — ⟵ **فصارت هذه
  //   المجموعة اختبارَ ارتدادٍ في الاتجاه المعاكس:** ★ **تُثبت أن الغياب
  //   يمرّ** ⛔ **وأن لا نصَّ يُعبَّأ آلياً مكانه.** ★ **والتعليق أعلاه يبقى
  //   تاريخاً يُقرأ** ⛔ **لا مواصفةَ قبولٍ سارية.**
  group('★★★ ADR-0020 — تعديل بلا سبب يُقبَل', () {
    test('✅★★★ تعديل مستخدم بلا سبب نصّي يمرّ — والقيد بلا نصّ مخترَع', () {
      expect(
        acceptedOf(planUserAdmin(
          request(userProfile: profile(), amendReason: null),
          UserAdminOperation.updateUser,
        )).entry.reason,
        isNull,
      );
    });

    test('✅★★ والفراغات تمرّ وتُقرأ غياباً — ⛔ لا نصّاً فارغاً', () {
      expect(
        acceptedOf(planUserAdmin(
          request(userProfile: profile(), amendReason: '   '),
          UserAdminOperation.updateUser,
        )).entry.reason,
        isNull,
      );
    });

    test('✅★ وتعديل الدور كذلك — القاعدة على الفعل لا على الكيان', () {
      expect(
        acceptedOf(planUserAdmin(
          request(
            targetId: 'ROL-001',
            amendReason: '  ',
            role: (validateRole(name: 'محاسب') as Success<ValidatedRole>).value,
          ),
          UserAdminOperation.updateRole,
        )).entry.reason,
        isNull,
      );
    });

    test('✅ وبسببٍ صحيح يمرّ — والسبب في القيد نفسه لا في مكان آخر', () {
      final UserAdminAccepted plan = acceptedOf(planUserAdmin(
        request(userProfile: profile(), amendReason: '  تصحيح الاسم  '),
        UserAdminOperation.updateUser,
      ));
      // ★ **مقصوصاً** — فلا يُخزَّن سببٌ بفراغات تجعل المقارنة تخطئ.
      expect(plan.entry.reason, 'تصحيح الاسم');
      expect(plan.entry.action, AuditAction.amend);
    });

    test('★ ولا يسري على الإنشاء — ⛔ ولا «قبل» قبل الإنشاء أصلاً', () {
      // ⚠️ **والتمييز ليس تساهلاً:** القيد يوثّق «ماذا كان وماذا صار»،
      //    ⟵ **ولا «كان» عند الإنشاء** فلا معنى لسبب تغييرٍ لم يقع.
      final UserAdminAccepted plan = acceptedOf(planUserAdmin(
        request(userProfile: profile(), amendReason: null),
        UserAdminOperation.createUser,
      ));
      expect(plan.entry.action, AuditAction.create);
      expect(plan.entry.reason, isNull);
    });

    test('★★ وسبب التعطيل يصل القيد — ⛔ لا يُكتب في الحقل ويُغفَل هناك', () {
      // ⟵ وإلا صار السجل يقول «عُطِّل» بلا لماذا، وهو نصف قيد.
      final UserAdminAccepted plan = acceptedOf(planUserAdmin(
        request(disableReason: '  غادر العمل  '),
        UserAdminOperation.disableUser,
      ));
      expect(plan.entry.reason, 'غادر العمل');
    });
  });

  group('★ قابلية التكرار بلا أثر جانبي — coding-standards §2.7', () {
    test('نفس الطلب يُنتج نفس الخطة حرفياً', () {
      final UserAdminAccepted first = acceptedOf(planUserAdmin(
        request(userProfile: profile()),
        UserAdminOperation.createUser,
      ));
      final UserAdminAccepted second = acceptedOf(planUserAdmin(
        request(userProfile: profile()),
        UserAdminOperation.createUser,
      ));
      expect(first.fields, second.fields);
      expect(first.updateMask, second.updateMask);
      // ★ ومعرّف القيد هو معرّف الطلب — فإعادة الإرسال تكتب فوقه ولا تُنشئ.
      expect(first.entry.id, second.entry.id);
    });
  });
}

import 'package:qtms_domain/qtms_domain.dart';
import 'package:test/test.dart';

/// رمز القاعدة المخالَفة، أو `null` إن نجح الفحص.
String? ruleOf(Outcome<Object?> outcome) => switch (outcome) {
      Failure<Object?>(:final AppError error) =>
        error is ValidationError ? error.ruleCode : '<غير تحقق>',
      Success<Object?>() => null,
    };

UserProfileInput profile({
  String name = 'أحمد المقوت',
  String email = 'ahmed@example.com',
  String? phone,
  String? roleId,
  Set<String> extraFields = const <String>{},
}) =>
    UserProfileInput(
      name: name,
      email: email,
      phone: phone,
      roleId: roleId,
      extraFields: extraFields,
    );

void main() {
  group('FR-M1-02 — ⛔ لا حقل كلمة مرور ولا معرّف جهاز', () {
    test('★★ حقل كلمة مرور في الحمولة يُبطل الطلب كاملاً', () {
      // ⛔ **الرفض لا التجاهل الصامت:** التجاهل يجعل الواجهة تظنّ أن كلمة
      //    المرور حُفظت، ⟵ فيصير غيابها مفاجأةً وقت الحاجة.
      final Outcome<ValidatedUserProfile> result =
          validateUserProfile(profile(extraFields: <String>{'password'}));
      expect(ruleOf(result), 'FR-M1-02');
    });

    test('★ ومعرّف الجهاز كذلك', () {
      expect(
        ruleOf(validateUserProfile(profile(extraFields: <String>{'deviceId'}))),
        'FR-M1-02',
      );
    });

    test('★ والمقارنة لا تُخدَع بحالة الأحرف', () {
      // ⚠️ `Password` و`DeviceID` ممنوعان كـ`password` و`deviceId` سواءً.
      expect(
        ruleOf(validateUserProfile(profile(extraFields: <String>{'Password'}))),
        'FR-M1-02',
      );
      expect(
        ruleOf(validateUserProfile(profile(extraFields: <String>{'DeviceID'}))),
        'FR-M1-02',
      );
    });

    test('★★ ويُرفَض قبل فحص المحتوى — فطلبٌ ممنوعُ الحقل يُرفَض به لا بغيره',
        () {
      // ★ الاسم فارغ **والحقل ممنوع** — والرمز العائد يجب أن يكون
      //   `FR-M1-02` لا `FR-M1-01`، وإلا فترتيب الفحوص ليس كما وُثِّق.
      final Outcome<ValidatedUserProfile> result = validateUserProfile(
        profile(name: '', extraFields: <String>{'password'}),
      );
      expect(ruleOf(result), 'FR-M1-02');
    });

    test('✅ وحقل إضافي مشروع لا يُرفَض — القائمة محدَّدة لا شاملة', () {
      expect(
        ruleOf(validateUserProfile(profile(extraFields: <String>{'note'}))),
        isNull,
      );
    });
  });

  group('FR-M1-01 — حقول المستخدم', () {
    test('✅ ملف صحيح يمرّ، وقيمه مُطبَّعة كما تُكتب', () {
      final Outcome<ValidatedUserProfile> result = validateUserProfile(
        profile(name: '  أحمد  ', email: '  Ahmed@Example.COM  '),
      );
      expect(ruleOf(result), isNull);
      final ValidatedUserProfile value =
          (result as Success<ValidatedUserProfile>).value;
      expect(value.name, 'أحمد');
      // ★ البريد بحروف صغيرة — فلا يُنشأ حسابان بفارق حالة أحرف.
      expect(value.email, 'ahmed@example.com');
    });

    test('⛔ واسم أقصر من الحدّ يُرفَض', () {
      expect(ruleOf(validateUserProfile(profile(name: 'ا'))), 'FR-M1-01');
    });

    test('⛔ واسم أطول من الحدّ يُرفَض', () {
      expect(
        ruleOf(validateUserProfile(profile(name: 'ا' * 51))),
        'FR-M1-01',
      );
    });

    test('⛔ وبريد بلا علامة أو بلا نطاق يُرفَض', () {
      for (final String bad in <String>[
        'ahmed',
        'ahmed@',
        '@example.com',
        'ahmed@example',
        'ahmed@.com',
        'ahmed@example.',
        'a b@example.com',
        'a@b@c.com',
      ]) {
        expect(
          ruleOf(validateUserProfile(profile(email: bad))),
          'FR-M1-01',
          reason: 'البريد «$bad» كان يجب أن يُرفَض',
        );
      }
    });

    test('★ والهاتف اختياري — والفارغ غيابٌ لا نصٌّ فارغ يُخزَّن', () {
      final ValidatedUserProfile blank =
          (validateUserProfile(profile(phone: '   '))
              as Success<ValidatedUserProfile>)
          .value;
      expect(blank.phone, isNull);
    });

    test('★★ والهاتف يُطبَّع من مصدر الحقيقة الواحد — IQ-014', () {
      // ★ ولا نسخة تطبيع محلية هنا: القيمة المتوقَّعة **تُشتقّ من الدالة
      //   نفسها**، ⟵ فلو تغيّر التطبيع تغيّر الطرفان معاً ولا يفترقان.
      final ValidatedUserProfile value =
          (validateUserProfile(profile(phone: '٧٧٧١٢٣٤٥٦'))
              as Success<ValidatedUserProfile>)
          .value;
      expect(value.phone, normalizePhone('٧٧٧١٢٣٤٥٦'));
    });

    test('★ والاسم المُطبَّع من مصدر الحقيقة الواحد — IQ-013', () {
      final ValidatedUserProfile value =
          (validateUserProfile(profile(name: 'أحمد')) as Success<ValidatedUserProfile>)
              .value;
      expect(value.normalizedName, normalizeName('أحمد'));
    });

    test('★ والدور اختياري — FR-M1-04: الأدوار قوالب بداية لا قيود', () {
      final ValidatedUserProfile value =
          (validateUserProfile(profile()) as Success<ValidatedUserProfile>).value;
      expect(value.roleId, isNull);
    });
  });

  group('★★ BR-M1-02 · FR-M1-11 — حساب المالك', () {
    const String owner = 'uid-owner';

    test('⛔★★ غيرُ المالك لا يمسّ حساب المالك — ولو ملك كل صلاحية', () {
      // ⚠️ **قيدٌ يعلو على الصلاحية لا يُستبدَل بها** — وبدونه يصير
      //    `userAmend` طريقاً لتعطيل المالك ثم الاستيلاء على النظام.
      expect(
        ruleOf(validateOwnerAccountGuard(
          actorUserId: 'uid-admin',
          targetUserId: owner,
          ownerUserId: owner,
        )),
        'BR-M1-02',
      );
    });

    test('✅ والمالك يمسّ حسابه هو — الاستثناء الوحيد المنصوص عليه', () {
      expect(
        ruleOf(validateOwnerAccountGuard(
          actorUserId: owner,
          targetUserId: owner,
          ownerUserId: owner,
        )),
        isNull,
      );
    });

    test('✅ وحسابٌ آخر لا يحرسه هذا القيد', () {
      expect(
        ruleOf(validateOwnerAccountGuard(
          actorUserId: 'uid-admin',
          targetUserId: 'uid-other',
          ownerUserId: owner,
        )),
        isNull,
      );
    });

    test('⛔★★ ومعرّف مالكٍ غائب = منعٌ لا سماح', () {
      // ★ **الرفض الافتراضي:** لو سُمح عند غياب المعرّف لصار **إسقاطُ
      //   الإعداد** طريقاً للالتفاف على الحارس كله.
      expect(
        ruleOf(validateOwnerAccountGuard(
          actorUserId: 'uid-admin',
          targetUserId: 'uid-any',
          ownerUserId: '   ',
        )),
        'BR-M1-02',
      );
    });
  });

  group('★ FR-M1-12 — التعطيل بسبب نصّي', () {
    const String owner = 'uid-owner';

    UserDisableRequest disable({
      String actor = 'uid-admin',
      String target = 'uid-target',
      String reason = 'غادر العمل',
    }) =>
        UserDisableRequest(
          actorUserId: actor,
          targetUserId: target,
          ownerUserId: owner,
          reason: reason,
        );

    test('✅ تعطيل بسبب صحيح يمرّ، والسبب مقصوص كما يُكتب', () {
      final Outcome<ValidatedUserDisable> result =
          validateUserDisable(disable(reason: '  غادر العمل  '));
      expect(ruleOf(result), isNull);
      expect(
        (result as Success<ValidatedUserDisable>).value.reason,
        'غادر العمل',
      );
    });

    test('⛔ وبلا سبب يُرفَض', () {
      expect(ruleOf(validateUserDisable(disable(reason: ''))), 'FR-M1-12');
    });

    test('⛔ والفراغات وحدها ليست سبباً', () {
      expect(ruleOf(validateUserDisable(disable(reason: '   '))), 'FR-M1-12');
    });

    test('⛔★★ ولا مستخدم يعطّل نفسه — ولو المالك', () {
      // ★ **ولا يقاس على «لا يعدّل صلاحيات نفسه» فحسب:** تعطيل النفس يقفل
      //   الحساب فوراً بلا رجعة، ⟵ ولو كان آخرَ من يملك `userDisable`
      //   **لَقفل النظام على نفسه**. ★ وحساب المالك لا مسار لإعادة تفعيله.
      expect(
        ruleOf(validateUserDisable(disable(actor: 'uid-x', target: 'uid-x'))),
        'FR-M1-12',
      );
      expect(
        ruleOf(validateUserDisable(disable(actor: owner, target: owner))),
        'FR-M1-12',
      );
    });

    test('⛔★ وغيرُ المالك لا يعطّل المالك — BR-M1-02', () {
      expect(
        ruleOf(validateUserDisable(disable(target: owner))),
        'BR-M1-02',
      );
    });

    test('★ وترتيب الفحوص: تعطيل النفس يُرفَض قبل فحص السبب', () {
      // ★ طلبٌ بلا سبب **وعلى النفس** — والرمز يجب أن يكون رمز الأول.
      //   ⚠️ والاثنان هنا `FR-M1-12`، ⟵ فالتمييز بحساب المالك:
      final Outcome<ValidatedUserDisable> result = validateUserDisable(
        disable(actor: 'uid-admin', target: owner, reason: ''),
      );
      // ★ حارس المالك يسبق فحص السبب — فالرمز `BR-M1-02` لا `FR-M1-12`.
      expect(ruleOf(result), 'BR-M1-02');
    });
  });

  group('★ FR-M1-03 — الأدوار', () {
    test('⛔★ الدور المُسنَد لمستخدم واحد لا يُحذف', () {
      expect(
        ruleOf(
          validateRoleDeletion(
            const RoleAssignmentCensus.measured(<String>['USR-1']),
          ),
        ),
        'FR-M1-03',
      );
    });

    test('⛔★★ ولا المُسنَد لعدة مستخدمين — والضرر واحد', () {
      expect(
        ruleOf(
          validateRoleDeletion(
            const RoleAssignmentCensus.measured(<String>[
              'USR-1',
              'USR-2',
              'USR-3',
            ]),
          ),
        ),
        'FR-M1-03',
      );
    });

    test('✅★ وغيرُ المُسنَد يُحذف حذفاً فعلياً — IQ-018 الخيار ب', () {
      expect(
        ruleOf(
          validateRoleDeletion(const RoleAssignmentCensus.measured(<String>[])),
        ),
        isNull,
      );
    });

    test('⛔★★ ولا مُنشِئ للإحصاء بلا قياس — فلا «فارغ» افتراضي', () {
      // ⚠️ **هذا اختبار تصميم لا سلوك:** لو وُجد مُنشِئ افتراضي لصار نسيانُ
      //    الاستعلام يُنتج «غير مُسنَد» صامتاً. ★ **والاسم `measured` هو
      //    العقد**، وهذا السطر يُثبت أن القائمة تعبر منه حرفياً.
      const RoleAssignmentCensus census =
          RoleAssignmentCensus.measured(<String>['USR-9']);
      expect(census.assignedUserIds, <String>['USR-9']);
      expect(census.isAssigned, isTrue);
    });

    test('✅ ودورٌ باسم صحيح يمرّ، ووصفُه اختياري', () {
      final Outcome<ValidatedRole> result =
          validateRole(name: '  محاسب  ', description: '   ');
      expect(ruleOf(result), isNull);
      final ValidatedRole value = (result as Success<ValidatedRole>).value;
      expect(value.name, 'محاسب');
      // ★ **الوصف الفارغ غيابٌ** ⛔ لا نصٌّ فارغ يُخزَّن.
      expect(value.description, isNull);
      expect(value.normalizedName, normalizeName('محاسب'));
    });

    test('⛔ واسم دورٍ خارج الحدّ يُرفَض', () {
      expect(ruleOf(validateRole(name: 'م')), 'FR-M1-03');
      expect(ruleOf(validateRole(name: 'م' * 51)), 'FR-M1-03');
    });
  });
}

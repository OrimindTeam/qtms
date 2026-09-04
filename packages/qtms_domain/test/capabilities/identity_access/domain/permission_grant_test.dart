import 'package:qtms_domain/qtms_domain.dart';
import 'package:test/test.dart';

const String _owner = 'USR-0001';
const String _staff = 'USR-0002';

PermissionGrantRequest _request({
  String actor = _owner,
  Set<Permission> actorPermissions = const <Permission>{},
  SourceScope actorScope = const AllSources(),
  String target = _staff,
  Set<Permission> requested = const <Permission>{},
  SourceScope? requestedScope,
}) =>
    PermissionGrantRequest(
      actorUserId: actor,
      actorPermissions: actorPermissions,
      actorScope: actorScope,
      targetUserId: target,
      requestedPermissions: requested,
      requestedScope: requestedScope ?? const AllSources(),
    );

void main() {
  group('SourceScope — permissions-catalog §4', () {
    test('`all` يشمل أي مصدر — بما فيه ما يُضاف مستقبلاً', () {
      const SourceScope scope = AllSources();
      expect(scope.canAccessSource('SRC-001'), isTrue);
      expect(scope.canAccessSource('SRC-999-جديد-لاحقاً'), isTrue);
    });

    test('القائمة المحددة لا تشمل ما ليس فيها', () {
      final SourceScope scope = ScopedSources(<String>{'SRC-001', 'SRC-002'});
      expect(scope.canAccessSource('SRC-001'), isTrue);
      expect(scope.canAccessSource('SRC-003'), isFalse);
    });

    test('⛔ النطاق الفارغ مرفوض — تعطيل مقنَّع لا نطاق', () {
      expect(() => ScopedSources(<String>{}), throwsArgumentError);
    });

    test('القائمة غير قابلة للتعديل بعد الإنشاء', () {
      final ScopedSources scope = ScopedSources(<String>{'SRC-001'});
      expect(() => scope.sourceIds.add('SRC-002'), throwsUnsupportedError);
    });

    group('scopeIsWithin — أساس FR-M1-08', () {
      test('أي نطاق يقع داخل `all`', () {
        expect(scopeIsWithin(const AllSources(), const AllSources()), isTrue);
        expect(
          scopeIsWithin(ScopedSources(<String>{'SRC-001'}), const AllSources()),
          isTrue,
        );
      });

      test('★ و`all` لا يقع داخل قائمة محدودة مهما طالت', () {
        // ⚠️ لأن `all` يشمل **ما سيُضاف مستقبلاً** ولا تشمله أي قائمة.
        expect(
          scopeIsWithin(
            const AllSources(),
            ScopedSources(<String>{'SRC-001', 'SRC-002', 'SRC-003'}),
          ),
          isFalse,
        );
      });

      test('القائمة الأضيق تقع داخل الأوسع لا العكس', () {
        final SourceScope wide = ScopedSources(<String>{'SRC-001', 'SRC-002'});
        final SourceScope narrow = ScopedSources(<String>{'SRC-001'});
        expect(scopeIsWithin(narrow, wide), isTrue);
        expect(scopeIsWithin(wide, narrow), isFalse);
      });
    });
  });

  group('validatePermissionGrant — ما يجب أن يُرفَض', () {
    test('⛔ authentication-policy §3: لا أحد يعدّل صلاحيات نفسه — ولو المالك', () {
      final Outcome<ApprovedGrant> result = validatePermissionGrant(_request(
        actor: _owner,
        target: _owner, // نفسه
        actorPermissions: Permission.values.toSet(),
        requested: <Permission>{Permission.sackView},
      ));
      expect(result, isA<Failure<ApprovedGrant>>());
      expect((result as Failure<ApprovedGrant>).error, isA<PermissionError>());
    });

    test('⛔ BR-M1-03: يُرفَض منح صلاحية لا يملكها المُنفِّذ', () {
      final Outcome<ApprovedGrant> result = validatePermissionGrant(_request(
        actorPermissions: <Permission>{Permission.sackView},
        requested: <Permission>{Permission.sackView, Permission.ownerLedgerView},
      ));
      expect(result, isA<Failure<ApprovedGrant>>());
    });

    test('⛔ FR-M1-08: يُرفَض توسيع النطاق فوق نطاق المُنفِّذ', () {
      final Outcome<ApprovedGrant> result = validatePermissionGrant(_request(
        actorPermissions: <Permission>{Permission.sackView},
        actorScope: ScopedSources(<String>{'SRC-001'}),
        requested: <Permission>{Permission.sackView},
        requestedScope: ScopedSources(<String>{'SRC-001', 'SRC-002'}),
      ));
      expect(result, isA<Failure<ApprovedGrant>>());
    });

    test('⛔ ولا يمنح `all` من كان نطاقه قائمة', () {
      final Outcome<ApprovedGrant> result = validatePermissionGrant(_request(
        actorPermissions: <Permission>{Permission.sackView},
        actorScope: ScopedSources(<String>{'SRC-001'}),
        requested: <Permission>{Permission.sackView},
        requestedScope: const AllSources(),
      ));
      expect(result, isA<Failure<ApprovedGrant>>());
    });

    test('★ فحص «لا يعدّل نفسه» يسبق فحص المحتوى', () {
      // طلب فارغ تماماً على النفس — يجب أن يُرفض رغم خلوّه من أي تجاوز.
      final Outcome<ApprovedGrant> result = validatePermissionGrant(_request(
        actor: _owner,
        target: _owner,
        actorPermissions: Permission.values.toSet(),
      ));
      expect(result, isA<Failure<ApprovedGrant>>());
    });
  });

  group('validatePermissionGrant — ما يجب أن يُقبَل', () {
    test('منح مجموعة فرعية مما يملكه المُنفِّذ لمستخدم آخر', () {
      final Outcome<ApprovedGrant> result = validatePermissionGrant(_request(
        actorPermissions: <Permission>{
          Permission.sackView,
          Permission.ownerLedgerView,
          Permission.sackAmend,
        },
        requested: <Permission>{Permission.sackView, Permission.sackAmend},
      ));

      expect(result, isA<Success<ApprovedGrant>>());
      final ApprovedGrant granted = (result as Success<ApprovedGrant>).value;
      expect(granted.permissions,
          <Permission>{Permission.sackView, Permission.sackAmend});
      expect(granted.scope, const AllSources());
    });

    test('السحب الكامل مسموح — والمجموعة الفارغة رفض افتراضي لا خطأ', () {
      // §1 القاعدة 4: «القيمة bool دائماً — والغياب يعني false».
      final Outcome<ApprovedGrant> result = validatePermissionGrant(_request(
        actorPermissions: <Permission>{Permission.sackView},
      ));
      expect(result, isA<Success<ApprovedGrant>>());
      expect((result as Success<ApprovedGrant>).value.permissions, isEmpty);
    });

    test('نطاق أضيق من نطاق المُنفِّذ مقبول', () {
      final Outcome<ApprovedGrant> result = validatePermissionGrant(_request(
        actorPermissions: <Permission>{Permission.sackView},
        actorScope: ScopedSources(<String>{'SRC-001', 'SRC-002'}),
        requested: <Permission>{Permission.sackView},
        requestedScope: ScopedSources(<String>{'SRC-001'}),
      ));
      expect(result, isA<Success<ApprovedGrant>>());
    });

    test('الصلاحيات الممنوحة غير قابلة للتعديل بعد الفحص', () {
      final Outcome<ApprovedGrant> result = validatePermissionGrant(_request(
        actorPermissions: <Permission>{Permission.sackView},
        requested: <Permission>{Permission.sackView},
      ));
      final ApprovedGrant granted = (result as Success<ApprovedGrant>).value;
      expect(() => granted.permissions.add(Permission.ownerLedgerView),
          throwsUnsupportedError);
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  // ★★★ `IQ-040` — اشتراطُ ترتيبِ المنح
  // ═════════════════════════════════════════════════════════════════════
  group('validatePermissionGrant — اشتراطُ المانح المسبق (IQ-040)', () {
    test('⛔ يُرفَض `dealerStatementView` بلا `dealerBalanceView`', () {
      final Outcome<ApprovedGrant> result = validatePermissionGrant(_request(
        actorPermissions: Permission.values.toSet(),
        requested: <Permission>{Permission.dealerStatementView},
      ));
      expect(result, isA<Failure<ApprovedGrant>>());
      expect((result as Failure<ApprovedGrant>).error, isA<PermissionError>());
    });

    test('⛔ ويُرفَض `dealerStatementAllSources` بلا `dealerStatementView`', () {
      final Outcome<ApprovedGrant> result = validatePermissionGrant(_request(
        actorPermissions: Permission.values.toSet(),
        requested: <Permission>{
          Permission.dealerBalanceView,
          Permission.dealerStatementAllSources,
        },
      ));
      expect(result, isA<Failure<ApprovedGrant>>());
    });

    test('✅ وتُقبَل السلسلة كاملةً', () {
      final Outcome<ApprovedGrant> result = validatePermissionGrant(_request(
        actorPermissions: Permission.values.toSet(),
        requested: <Permission>{
          Permission.dealerBalanceView,
          Permission.dealerStatementView,
          Permission.dealerStatementAllSources,
        },
      ));
      expect(result, isA<Success<ApprovedGrant>>());
    });

    test('✅ ويُقبَل المانحُ المسبق وحدَه — الاشتراطُ اتجاهٌ واحد', () {
      final Outcome<ApprovedGrant> result = validatePermissionGrant(_request(
        actorPermissions: Permission.values.toSet(),
        requested: <Permission>{Permission.dealerBalanceView},
      ));
      expect(result, isA<Success<ApprovedGrant>>());
    });

    test('★ والسحبُ الكامل يبقى مسموحاً — لا اشتراطَ على مجموعةٍ فارغة', () {
      final Outcome<ApprovedGrant> result = validatePermissionGrant(_request(
        actorPermissions: Permission.values.toSet(),
      ));
      expect(result, isA<Success<ApprovedGrant>>());
    });

    // ⛔⛔★★ **حارسُ المعجم نفسِه** — ⟵ **فلا سلسلةَ اشتراطٍ دائرية ولا
    //    مانحٌ مسبقٌ لا وجود له**: ★ **خللٌ كان سيمنع المنحَ إلى الأبد.**
    test('★ ومعجمُ الاشتراط سليمٌ بنيوياً — بلا دورةٍ ولا مفتاحٍ مجهول', () {
      for (final Permission key in permissionGrantPrerequisites.keys) {
        final Set<Permission> seen = <Permission>{key};
        Permission? current = key.grantPrerequisite;
        while (current != null) {
          expect(Permission.values, contains(current));
          expect(seen.add(current), isTrue,
              reason: 'دورةٌ في سلسلة اشتراط ${key.name}');
          current = current.grantPrerequisite;
        }
      }
    });
  });
}

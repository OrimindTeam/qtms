import 'package:qtms_domain/qtms_domain.dart';
import 'package:test/test.dart';

void main() {
  _claimTests();
  const AuthenticatedIdentity identity = AuthenticatedIdentity(
    userId: 'U-001',
    sourceScope: AllSources(),
  );

  UserCard card({
    bool isActive = true,
    String userId = 'U-001',
    Set<Permission> permissions = const <Permission>{Permission.sackView},
  }) =>
      UserCard(
        userId: userId,
        name: 'عبدالفتاح',
        roleName: 'المالك',
        permissions: permissions,
        isActive: isActive,
      );

  group('بناء الجلسة — authentication-policy §7', () {
    test('★★ الصلاحيات من البطاقة والنطاق من الرمز — ADR-0016', () {
      final Outcome<AuthSession> outcome =
          resolveAuthSession(identity: identity, card: card());
      final AuthSession session = (outcome as Success<AuthSession>).value;

      expect(session.has(Permission.sackView), isTrue);
      expect(session.has(Permission.userCreate), isFalse);
      expect(session.canAccessSource('SRC-001'), isTrue);
      expect(session.displayName, 'عبدالفتاح');
      expect(session.roleName, 'المالك');
    });

    test('⛔ البند 2 — حساب معطَّل يُرفَض فوراً (FR-M1-15)', () {
      final Outcome<AuthSession> outcome =
          resolveAuthSession(identity: identity, card: card(isActive: false));
      expect(outcome, isA<Failure<AuthSession>>());
      expect((outcome as Failure<AuthSession>).error, isA<SessionError>());
    });

    test('★★ البند 7 — حساب بلا بطاقة يدخل بلا صلاحية ⛔ ولا يُرفَض', () {
      // ★ حالة المالك قبل رَنبوك الإقلاع حرفياً — والرفض كان سيمنع الإقلاع.
      final Outcome<AuthSession> outcome =
          resolveAuthSession(identity: identity, card: null);
      final AuthSession session = (outcome as Success<AuthSession>).value;

      expect(session.permissions, isEmpty);
      for (final Permission permission in Permission.values) {
        expect(session.has(permission), isFalse, reason: permission.name);
      }
    });

    test('⛔ وبطاقة بمعرّف مغاير للهوية تُرفَض', () {
      final Outcome<AuthSession> outcome =
          resolveAuthSession(identity: identity, card: card(userId: 'U-999'));
      expect(outcome, isA<Failure<AuthSession>>());
    });

    test('★ والنطاق المحدَّد يمنع مصدراً خارجه — FR-M1-07 · E-35', () {
      final Outcome<AuthSession> outcome = resolveAuthSession(
        identity: AuthenticatedIdentity(
          userId: 'U-001',
          sourceScope: ScopedSources(<String>{'SRC-RADAA'}),
        ),
        card: card(),
      );
      final AuthSession session = (outcome as Success<AuthSession>).value;

      expect(session.canAccessSource('SRC-RADAA'), isTrue);
      expect(session.canAccessSource('SRC-MAWIYA'), isFalse);
    });

    test('⛔ ومجموعة الصلاحيات غير قابلة للتعديل بعد البناء', () {
      final AuthSession session =
          (resolveAuthSession(identity: identity, card: card())
                  as Success<AuthSession>)
              .value;
      expect(
        () => session.permissions.add(Permission.userCreate),
        throwsUnsupportedError,
      );
    });
  });
}

void _claimTests() {
  group('مطالبة نطاق المصادر — مرآة firestore.rules', () {
    test("★ 'all' نصّاً ⟵ كل المصادر", () {
      expect(parseSourceScopeClaim('all'), isA<AllSources>());
      expect(parseSourceScopeClaim('all')!.canAccessSource('SRC-9'), isTrue);
    });

    test('★ قائمة ⟵ نطاق محدَّد', () {
      final SourceScope? scope =
          parseSourceScopeClaim(<Object?>['SRC-001', 'SRC-002']);
      expect(scope, isA<ScopedSources>());
      expect(scope!.canAccessSource('SRC-001'), isTrue);
      expect(scope.canAccessSource('SRC-003'), isFalse);
    });

    test('⛔★★ والمطالبة الغائبة ⟵ لا مصدر متاح ⛔ لا «كل المصادر»', () {
      // ★ هذا هو الفارق الأمني كله: الاتجاه الآمن عند الغياب.
      expect(parseSourceScopeClaim(null), isNull);
      expect(parseSourceScopeClaim(<Object?>[]), isNull);
      expect(parseSourceScopeClaim('ALL'), isNull);
      expect(parseSourceScopeClaim(<Object?>['  ']), isNull);
      expect(parseSourceScopeClaim(42), isNull);
    });

    test('★ وجلسة بلا نطاق لا تصل أي مصدر', () {
      final AuthSession session = AuthSession(
        userId: 'U-001',
        displayName: 'U-001',
        permissions: const <Permission>{Permission.sackView},
        sourceScope: parseSourceScopeClaim(null),
      );
      expect(session.has(Permission.sackView), isTrue);
      expect(session.canAccessSource('SRC-001'), isFalse);
    });
  });
}


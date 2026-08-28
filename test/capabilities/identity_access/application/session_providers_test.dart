/// تركيب الجلسة من مصدرَيها — ★ **بلا واجهة ولا سحابة** (`ADR-0009`).
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qtms/capabilities/identity_access/application/session_providers.dart';
import 'package:qtms/capabilities/identity_access/application/session_state.dart';
import 'package:qtms_domain/qtms_domain.dart';

import '../../../support/fake_identity.dart';

void main() {
  late FakeAuthRepository auth;
  late FakeUserCardRepository cards;
  late ProviderContainer container;

  setUp(() {
    auth = FakeAuthRepository();
    cards = FakeUserCardRepository();
    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        userCardRepositoryProvider.overrideWithValue(cards),
      ],
    );
  });

  tearDown(() {
    container.dispose();
    auth.dispose();
    cards.dispose();
  });

  Future<SessionState> nextState() async {
    final Completer<SessionState> completer = Completer<SessionState>();
    final ProviderSubscription<AsyncValue<SessionState>> subscription =
        container.listen<AsyncValue<SessionState>>(
      sessionProvider,
      (AsyncValue<SessionState>? previous, AsyncValue<SessionState> next) {
        final SessionState? value = next.value;
        if (value != null && !completer.isCompleted) completer.complete(value);
      },
      fireImmediately: true,
    );
    final SessionState state = await completer.future;
    subscription.close();
    return state;
  }

  test('بلا هوية ⟵ خارج الجلسة', () async {
    expect(await nextState(), isA<SessionSignedOut>());
  });

  test('★ هوية + بطاقة ⟵ جلسة قائمة بصلاحياتها', () async {
    auth.emitIdentity(
      const AuthenticatedIdentity(userId: 'U-001', sourceScope: AllSources()),
    );
    cards.emitCard('U-001', testCard());

    final SessionState state = await nextState();
    expect(state, isA<SessionActive>());
    final AuthSession session = (state as SessionActive).session;
    expect(session.has(Permission.sackView), isTrue);
    expect(session.canAccessSource('SRC-1'), isTrue);
  });

  test('⛔ بطاقة معطَّلة ⟵ جلسة مرفوضة', () async {
    auth.emitIdentity(
      const AuthenticatedIdentity(userId: 'U-001', sourceScope: AllSources()),
    );
    cards.emitCard('U-001', testCard(isActive: false));

    expect(await nextState(), isA<SessionRejected>());
  });

  test('★ بلا بطاقة ⟵ جلسة بلا صلاحية', () async {
    auth.emitIdentity(
      const AuthenticatedIdentity(userId: 'U-001', sourceScope: AllSources()),
    );

    final SessionState state = await nextState();
    expect(state, isA<SessionActive>());
    expect((state as SessionActive).session.permissions, isEmpty);
  });
}

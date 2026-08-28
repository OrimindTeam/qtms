/// مزوّدات الهوية والصلاحيات — ★ **مصدر واحد تقرأ منه كل شاشات النظام**
/// (`identity-access-design.md` §1 البند 2).
///
/// ★ **ولماذا مزوّد لا تمرير يدوي:** `ADR-0010` القاعدة 2 — «الصلاحيات تُقرأ
/// من نطاق واحد **ولا تُمرَّر يدوياً بين الشاشات**»، لأن **كل شاشة تقريباً**
/// تعتمد عليها في إظهار أو إخفاء عناصر بالكامل.
///
/// ⚠️ **وتغيّرٌ جوهري عن نصّ `identity-access-design.md` §6 الأصلي:** كان
/// يشترط «**قراءة محلية من الرمز لا رحلة شبكة**» — ★ **وقد نسخه `ADR-0016`
/// (معتمد)**: الصلاحيات صارت في `users/{userId}`. ⟵ **والبديل مُصغٍ حيّ
/// واحد لا رحلة لكل سؤال**: البطاقة تصل مرة وتُقرأ من الذاكرة، **ويُدفَع
/// تغييرها فوراً** — ✅ **فشرط «لا رحلة شبكة لكل قراءة» محفوظ**، ★ **ومعه
/// ربحٌ لم يكن: السحب يسري بلا إعادة دخول.**
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qtms_domain/qtms_domain.dart';

import 'session_state.dart';

/// مستودع المصادقة — ⛔ **يُحقَن في الجذر ولا يُبنى هنا**، فيبقى الاختبار
/// ممكناً بلا سحابة (`ADR-0010` — حقن اعتمادية صريح).
final Provider<AuthRepository> authRepositoryProvider =
    Provider<AuthRepository>((Ref ref) {
  throw UnimplementedError('authRepositoryProvider يجب تجاوزه عند الجذر');
});

/// مستودع بطاقة المستخدم — ★ **مصدر الصلاحيات بعد `ADR-0016`.**
final Provider<UserCardRepository> userCardRepositoryProvider =
    Provider<UserCardRepository>((Ref ref) {
  throw UnimplementedError('userCardRepositoryProvider يجب تجاوزه عند الجذر');
});

/// الجلسة الحيّة — ★ **تُجمَع من مصدرَيها معاً** (الهوية من الرمز، والبطاقة
/// من القاعدة)، ⟵ **فأي تغيّر في أيٍّ منهما يُعيد بناء الحالة.**
final StreamProvider<SessionState> sessionProvider =
    StreamProvider<SessionState>((Ref ref) {
  final AuthRepository auth = ref.watch(authRepositoryProvider);
  final UserCardRepository cards = ref.watch(userCardRepositoryProvider);

  return auth.watchIdentity().asyncExpand((AuthenticatedIdentity? identity) {
    if (identity == null) {
      return Stream<SessionState>.value(const SessionSignedOut());
    }
    // ★ `asyncExpand` تُلغي المُصغي الداخلي عند تبدّل الهوية — ⟵ فلا يبقى
    //   مُصغٍ على بطاقة مستخدم خرج، وهو تسريب صلاحيات لا مجرد تسريب موارد.
    return cards.watchCard(identity.userId).map((UserCard? card) {
      final Outcome<AuthSession> outcome =
          resolveAuthSession(identity: identity, card: card);
      return switch (outcome) {
        Success<AuthSession>(value: final AuthSession session) =>
          SessionActive(session),
        Failure<AuthSession>(error: final AppError error) =>
          SessionRejected(error),
      };
    });
  });
});

/// الجلسة القائمة أو `null` — اختصار تقرأه الشاشات.
final Provider<AuthSession?> currentSessionProvider =
    Provider<AuthSession?>((Ref ref) {
  final AsyncValue<SessionState> state = ref.watch(sessionProvider);
  final SessionState? value = state.value;
  return value is SessionActive ? value.session : null;
});

/// هل يملك المستخدم الحالي هذه الصلاحية؟
///
/// ⚠️ **سؤال عرض لا قرار تفويض** — `ADR-0010` القاعدة 3: «إخفاء العنصر
/// بالصلاحية يقع في طبقة العرض، **وحمايته الحقيقية في قواعد الحماية**،
/// ⛔ **ولا يجوز الاكتفاء بالأول أبداً**» (`RISK-02`).
final hasPermissionProvider = Provider.family<bool, Permission>(
  (Ref ref, Permission permission) =>
      ref.watch(currentSessionProvider)?.has(permission) ?? false,
);

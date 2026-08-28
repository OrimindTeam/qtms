/// حالة الجلسة في التطبيق — **حالة تطبيق لا حالة شاشة** (`ADR-0010`:
/// «المستخدم · الصلاحيات ونطاق المصادر · … طوال الجلسة»).
library;

import 'package:qtms_domain/qtms_domain.dart';

/// الحالات الثلاث التي يعيشها التطبيق.
sealed class SessionState {
  const SessionState();
}

/// لا جلسة — تُعرَض شاشة الدخول.
final class SessionSignedOut extends SessionState {
  const SessionSignedOut();
}

/// جلسة قائمة بصلاحياتها ونطاقها.
final class SessionActive extends SessionState {
  const SessionActive(this.session);

  final AuthSession session;
}

/// جلسة مرفوضة — ★ **حساب معطَّل** (`authentication-policy.md` §7 البند 2).
///
/// ⟵ **والتصرّف المُلزَم: إخراج فوري + رسالة** (`error-handling-strategy.md`
/// §2 · `FR-M1-15`: «تعطيل مستخدم يُبطل جلسته ورمز دخوله فوراً»).
final class SessionRejected extends SessionState {
  const SessionRejected(this.error);

  final AppError error;
}

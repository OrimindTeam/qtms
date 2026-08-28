/// تصنيف الأخطاء المعتمد.
///
/// ★ نقل حرفي لجدول `docs/04-design/error-handling-strategy.md` §2 — وهو مستند
/// **STATIC**. الفئات هنا هي فئاته التسع بأسمائها، لا تصنيف مخترَع.
///
/// ★ **ولا تحمل أي نص معروض للمستخدم عمداً.** القاعدة 2 في §3 من ذلك المستند:
/// «لا يُعرَض رمز تقني للمستخدم — الرسالة من كتالوج §11 حصراً». فربط الفئة
/// برسالتها المعتمدة **مسؤولية طبقة العرض**، وتُنفَّذ في الزيادة التي تبني
/// أول شاشة (`WU-001`) — ⛔ ولا تُخترَع رسالة هنا.
///
/// والقاعدة 3 في §3: **الأخطاء المتوقّعة تُرجَع كنتيجة لا تُرمى** في طبقة
/// النطاق — ولذلك هذه أنواع قيم لا استثناءات.
library;

/// الجذر المشترك لكل خطأ متوقَّع في النظام.
sealed class AppError {
  const AppError();
}

/// إدخال مخالف لقاعدة عمل — تنتجه طبقة النطاق، ولا يصل الشبكة أصلاً.
final class ValidationError extends AppError {
  const ValidationError(this.ruleCode);

  /// رمز القاعدة المخالَفة (مثال: `BR-M7-03`) — يُقرأ الكود مقابل المتطلب.
  final String ruleCode;
}

/// صلاحية مفقودة أو مصدر خارج النطاق — تنتجه قواعد الحماية.
final class PermissionError extends AppError {
  const PermissionError({this.sourceId});

  /// المصدر المرفوض إن كان الرفض بسبب النطاق لا الصلاحية.
  final String? sourceId;
}

/// تغيّرت البيانات المقروءة أثناء المعاملة — تُعاد المحاولة تلقائياً أولاً.
final class ConcurrencyError extends AppError {
  const ConcurrencyError();
}

/// الكمية تتجاوز المتاح.
final class InsufficientStockError extends AppError {
  const InsufficientStockError();
}

/// لا اتصال — والحفظ يُعطَّل، لأن التخزين المحلي مُعطَّل صراحةً (`ADR-0003`).
final class ConnectivityError extends AppError {
  const ConnectivityError();
}

/// انتهت الجلسة أو عُطِّل المستخدم.
final class SessionError extends AppError {
  const SessionError();
}

/// ★ خدمات المنصة غائبة على الجهاز — **رسالة صريحة لا فشل صامت**.
///
/// `C-04` · `FR-SYS-27` · `NFR-OPS-03`: الأجهزة بلا خدمات Google Play
/// **غير مدعومة**، ويجب إعلام المستخدم لا أن يتعطّل التطبيق بصمت.
final class PlatformUnavailableError extends AppError {
  const PlatformUnavailableError(this.diagnostic);

  /// وصف تقني **للسجل لا للعرض** — يُعين على التشخيص بلا بيانات حساسة.
  final String diagnostic;
}

/// واتساب غير مثبَّت · طابعة غير متصلة — ويُقترَح بديل.
final class IntegrationError extends AppError {
  const IntegrationError(this.diagnostic);

  final String diagnostic;
}

/// فشل غير متوقَّع — رسالة عامة + تسجيل تفصيلي **بلا بيانات حساسة**.
final class InfrastructureError extends AppError {
  const InfrastructureError(this.diagnostic);

  final String diagnostic;
}

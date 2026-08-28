/// نتيجة عملية نطاق — **نجاح بقيمة أو فشل بخطأ مصنَّف**.
///
/// ★ **لماذا نوع نتيجة لا استثناء:** `error-handling-strategy.md` §3 القاعدة 3
/// (مستند **STATIC**): «الأخطاء المتوقّعة **تُرجَع كنتيجة لا تُرمى**
/// كاستثناء في طبقة النطاق» — لأن القاعدة المخالَفة **نتيجة متوقّعة لا حالة
/// استثنائية**. و`naming-conventions.md` §3 يفرض الأثر نفسه على التسمية:
/// دوال `validate…` «**ترجع نتيجة لا ترمي**».
///
/// وأثره العملي أن المُستدعي **لا يستطيع تجاهل الفشل صامتاً**: النوع مُغلَق
/// (`sealed`) فالمطابقة عليه **تُلزمه بمعالجة الفرعين** وقت التصريف — وهو
/// إنفاذ بالبناء للقاعدة 1 من §3 («لا يُبتلَع استثناء صامتاً»).
library;

import 'errors/app_error.dart';

/// نتيجة عملية تُرجِع قيمة من النوع `T`.
sealed class Outcome<T> {
  const Outcome();
}

/// العملية نجحت وأنتجت [value].
final class Success<T> extends Outcome<T> {
  const Success(this.value);

  final T value;
}

/// العملية فشلت بخطأ مصنَّف من كتالوج `error-handling-strategy.md` §2.
final class Failure<T> extends Outcome<T> {
  const Failure(this.error);

  final AppError error;
}

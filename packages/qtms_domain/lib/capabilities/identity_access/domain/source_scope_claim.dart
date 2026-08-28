/// قراءة نطاق المصادر من مطالبات رمز الدخول — ★ **مرآةٌ حرفية لما تفعله
/// `firestore.rules`**، ⛔ **لا اجتهاد موازٍ.**
///
/// ★ **القاعدة المُحاكاة نصّاً:**
/// ```
/// function scope()   { return claims().get('sourceScope', []); }
/// function inScope(s){ return scope() == 'all' || (scope() is list && s in scope()); }
/// ```
/// ⟵ **فالمطالبة الغائبة تُقرأ قائمةً فارغة**، ★ **ومعناها: لا مصدر متاح
/// إطلاقاً** — ⛔ **لا «كل المصادر»**. ★ **والاتجاه الآمن مقصود:** الرفض هو
/// الأصل والسماح استثناء صريح (`BR-M1-01` · `GR-10`).
///
/// ⚠️ **ولماذا `null` لا [ScopedSources] فارغة:** النطاق الفارغ **يرمي عمداً**
/// في `source_scope.dart` لأنه «تعطيل مقنَّع لا نطاق». ⟵ **فغياب المطالبة
/// يُمثَّل بغياب النطاق نفسه**، وتُقرأ نتيجته `false` دائماً في
/// `AuthSession.canAccessSource`.
library;

import 'source_scope.dart';

/// اسم المطالبة كما تقرأه القاعدة حرفياً.
const String sourceScopeClaimKey = 'sourceScope';

/// القيمة النصّية لنطاق «كل المصادر» كما تقارنها القاعدة حرفياً.
const String allSourcesClaimValue = 'all';

/// يُحوِّل قيمة المطالبة إلى نطاق — و`null` تعني **لا مصدر متاح**.
SourceScope? parseSourceScopeClaim(Object? claim) {
  if (claim == allSourcesClaimValue) return const AllSources();
  if (claim is! List<Object?>) return null;

  final Set<String> sourceIds = claim
      .whereType<String>()
      .where((String id) => id.trim().isNotEmpty)
      .map((String id) => id.trim())
      .toSet();

  if (sourceIds.isEmpty) return null;
  return ScopedSources(sourceIds);
}

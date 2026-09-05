/// مزوّدات الجرد (`WU-022` · `M16` · `FR-M16`).
///
/// ★ **بنفس نمط `disposal_providers.dart`:** المستودعات **تُحقَن في الجذر
/// ولا تُبنى هنا** (`ADR-0010`) — ⟵ **فتُختبَر الشاشات بلا سحابة ولا شبكة**.
///
/// ⚠️⚠️ **وكل ما هنا عرضٌ لا تفويض:** إخفاءُ مدخل الجرد بـ`stocktakeWrite`
/// **إخفاء لا حماية** — ★ **والحمايةُ فحصُ المفتاح في الدالة السحابية**
/// (`ADR-0013` القاعدة 3 · `RISK-02`).
///
/// ⛔⛔★★★ **والاستعلامُ يُقيّد `sourceId` صراحةً** — ★ **لأن شرطَ قراءة
/// `stocktakes` يقرؤه** (`storedInScope()` **+ `stocktakeView`**): ⟵ **واستعلامٌ
/// لا يُقيّده يُرفَض كاملاً ولو بنطاقٍ شامل** (`IQ-024` · `DEBT-40` · `WU-016`).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qtms_domain/qtms_domain.dart';

/// دليل الجرد — ⛔ **يُحقَن في الجذر**.
final Provider<StocktakeDirectory> stocktakeDirectoryProvider =
    Provider<StocktakeDirectory>((Ref ref) {
  throw UnimplementedError('stocktakeDirectoryProvider يجب تجاوزه عند الجذر');
});

/// مستودع كتابة الجرد — ⛔ **يُحقَن في الجذر**.
final Provider<StocktakeAdminRepository> stocktakeAdminProvider =
    Provider<StocktakeAdminRepository>((Ref ref) {
  throw UnimplementedError('stocktakeAdminProvider يجب تجاوزه عند الجذر');
});

/// ⛅ مستنداتُ الجرد في مصدر — الفهرس `sourceId ↑ · stockDate ↓`.
final stocktakesProvider = StreamProvider.family<List<StocktakeCard>, String>(
  (Ref ref, String sourceId) =>
      ref.watch(stocktakeDirectoryProvider).watchStocktakes(sourceId: sourceId),
);

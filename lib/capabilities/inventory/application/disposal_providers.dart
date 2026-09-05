/// مزوّدات الإتلاف (`WU-020` · `M8` · `FR-M8-16`).
///
/// ★ **بنفس نمط `outflow_providers.dart`:** المستودعات **تُحقَن في الجذر
/// ولا تُبنى هنا** (`ADR-0010`) — ⟵ **فتُختبَر الشاشات بلا سحابة ولا شبكة**.
///
/// ⚠️⚠️ **وكل ما هنا عرضٌ لا تفويض:** إخفاءُ مدخل الإتلاف بـ`disposalCreate`
/// **إخفاء لا حماية** — ★ **والحمايةُ فحصُ المفتاح في الدالة السحابية**
/// (`ADR-0013` القاعدة 3 · `RISK-02`).
///
/// ⛔⛔★★★ **والاستعلامُ يُقيّد `sourceId` صراحةً** — ★ **لأن شرطَ قراءة
/// `disposals` يقرؤه** (`storedInScope()`): ⟵ **واستعلامٌ لا يُقيّده يُرفَض
/// كاملاً ولو بنطاقٍ شامل** (`IQ-024` · `WU-008` · `DEBT-40` · `WU-016`).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qtms_domain/qtms_domain.dart';

/// دليل الإتلاف — ⛔ **يُحقَن في الجذر**.
final Provider<DisposalDirectory> disposalDirectoryProvider =
    Provider<DisposalDirectory>((Ref ref) {
  throw UnimplementedError('disposalDirectoryProvider يجب تجاوزه عند الجذر');
});

/// مستودع كتابة الإتلاف — ⛔ **يُحقَن في الجذر**.
final Provider<DisposalAdminRepository> disposalAdminProvider =
    Provider<DisposalAdminRepository>((Ref ref) {
  throw UnimplementedError('disposalAdminProvider يجب تجاوزه عند الجذر');
});

/// ⛅ مستنداتُ الإتلاف في مصدر — الفهرس `sourceId ↑ · stockDate ↓`.
final disposalsProvider =
    StreamProvider.family<List<DisposalCard>, String>(
  (Ref ref, String sourceId) =>
      ref.watch(disposalDirectoryProvider).watchDisposals(sourceId: sourceId),
);

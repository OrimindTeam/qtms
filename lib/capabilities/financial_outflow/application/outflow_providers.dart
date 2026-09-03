/// مزوّدات السحبيات والخرجيات (`WU-014`).
///
/// ★ **بنفس نمط `discount_providers.dart`:** المستودعات **تُحقَن في الجذر
/// ولا تُبنى هنا** (`ADR-0010`) — ⟵ **فتُختبَر الشاشات بلا سحابة ولا شبكة**.
///
/// ⚠️⚠️ **وكل ما هنا عرضٌ لا تفويض:** إخفاءُ مدخلِ السحبيات بـ`withdrawalCreate`
/// **إخفاء لا حماية** — ★ **والحمايةُ فحصُ المفتاح في الدالة السحابية**
/// (`ADR-0013` القاعدة 3 · `RISK-02` · `FR-M22-03`).
///
/// ⛔⛔★★★ **والاستعلامُ يُقيّد `sourceId` و`ledgerType` معاً** — ★ **لأن
/// شرطَ قراءة `outflows` يعتمدهما كليهما**: ⟵ **واستعلامٌ لا يُقيّدهما
/// يُرفَض كاملاً ولو بنطاقٍ شامل** (`IQ-024` · `WU-008` · `DEBT-40`).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qtms_domain/qtms_domain.dart';


/// دليل السحبيات والخرجيات — ⛔ **يُحقَن في الجذر**.
final Provider<OutflowDirectory> outflowDirectoryProvider =
    Provider<OutflowDirectory>((Ref ref) {
  throw UnimplementedError('outflowDirectoryProvider يجب تجاوزه عند الجذر');
});

/// مستودع كتابة السحبيات والخرجيات — ⛔ **يُحقَن في الجذر**.
final Provider<OutflowAdminRepository> outflowAdminProvider =
    Provider<OutflowAdminRepository>((Ref ref) {
  throw UnimplementedError('outflowAdminProvider يجب تجاوزه عند الجذر');
});

/// ★★ **سؤالُ القائمة** — **مصدرٌ وسجلٌّ معاً** ⛔ **ولا واحدٌ منهما ضمنيّ**.
///
/// ⚠️⚠️ **ونوعُ قيمةٍ بمساواةٍ بنيوية** — ⟵ **فتبديلُ التبويب لا يُعيد بناء
/// التدفّق ما لم يتغيّر السؤال فعلاً**، ⛔ **ومساواةُ المرجع كانت تُنشئ
/// اشتراكاً جديداً في كل إعادة بناء.**
final class OutflowQuery {
  /// ينشئ السؤال.
  const OutflowQuery({required this.sourceId, required this.ledgerType});

  /// المصدر — ⛔ **إلزاميٌّ** (`GR-42`).
  final String sourceId;

  /// السجل — ⛔ **إلزاميٌّ** (`GR-43`).
  final OutflowLedgerType ledgerType;

  @override
  bool operator ==(Object other) =>
      other is OutflowQuery &&
      other.sourceId == sourceId &&
      other.ledgerType == ledgerType;

  @override
  int get hashCode => Object.hash(sourceId, ledgerType);
}

/// ⛅ سندات سجلٍّ في مصدر — الفهرس
/// `sourceId ↑ · ledgerType ↑ · documentDate ↓`.
final outflowsProvider =
    StreamProvider.family<List<OutflowCard>, OutflowQuery>(
  (Ref ref, OutflowQuery query) =>
      ref.watch(outflowDirectoryProvider).watchOutflows(
            sourceId: query.sourceId,
            ledgerType: query.ledgerType,
          ),
);

// ═════════════════════════════════════════════════════════════════════════
// ⛔⛔★★★ **ولا مزوّدَ أنواعٍ من الكتالوج هنا بعد [`DEBT-86`]** (2026-09-02)
//
// ★ **كان `outflowItemsProvider` يرشِّح `items` بالمصدر والحالة** — ⟹ ⛔⛔ **فلم
// يكن المفتاحُ المركّب للجونية يظهر في أي منسدل قطّ** (`ADR-0007`)، ★ **ولا
// رصيدَ يقابل معرّفَ النوع المجرَّد**: ⟵ **فتُرفَض العمليةُ بـ«الكمية غير
// كافية».** ★★ **والخياراتُ اليومَ من أرصدة الدفتر** —
// `inventory_providers.dart` · `stockOptionsProvider`: ⟵ **وفيه شرحُ العطل
// ولماذا الدفترُ هو المصدر** (`ADR-0008`).
// ═════════════════════════════════════════════════════════════════════════


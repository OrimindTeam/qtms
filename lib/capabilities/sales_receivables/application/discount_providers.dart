/// مزوّدات الخصومات (`WU-013`).
///
/// ★ **بنفس نمط `receipt_providers.dart`:** المستودعات **تُحقَن في الجذر
/// ولا تُبنى هنا** (`ADR-0010`) — ⟵ **فتُختبَر الشاشات بلا سحابة ولا شبكة**.
///
/// ⚠️⚠️ **وكل ما هنا عرضٌ لا تفويض:** إخفاءُ مدخلِ الخصم بـ`discountCreate`
/// **إخفاء لا حماية** — ★ **والحمايةُ فحصُ المفتاح في الدالة السحابية**
/// (`ADR-0013` القاعدة 3 · `RISK-02` · `FR-M13-09`).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qtms_domain/qtms_domain.dart';

import 'receipt_providers.dart' show OpenDebtQuery;

/// دليل الخصومات — ⛔ **يُحقَن في الجذر**.
final Provider<DiscountDirectory> discountDirectoryProvider =
    Provider<DiscountDirectory>((Ref ref) {
  throw UnimplementedError('discountDirectoryProvider يجب تجاوزه عند الجذر');
});

/// مستودع كتابة الخصومات — ⛔ **يُحقَن في الجذر**.
final Provider<DiscountAdminRepository> discountAdminProvider =
    Provider<DiscountAdminRepository>((Ref ref) {
  throw UnimplementedError('discountAdminProvider يجب تجاوزه عند الجذر');
});

/// ⛅ الضمارات المفتوحة للمقوت — `FR-M13-02`.
///
/// ⚠️⚠️ **ويُعاد استعمال [OpenDebtQuery] نفسِه** — ⛔ **لا نوعٌ ثانٍ بنفس
/// الحقول**: ★ **فالسؤال واحد** (**أي ضمارات هذا المقوت مفتوحة في هذه
/// المصادر؟**)، ⟵ **ونوعان متطابقان كانا سيفترقان في قاعدة المساواة
/// فيُكرَّر التدفّق مرتين لنفس المقوت.**
final openDiscountDebtLotsProvider =
    StreamProvider.family<List<OpenDebtLot>, OpenDebtQuery>(
  (Ref ref, OpenDebtQuery query) =>
      ref.watch(discountDirectoryProvider).watchOpenDebtLots(
            dealerId: query.dealerId,
            sourceIds: query.sourceIds,
          ),
);

/// ⛅ سندات الخصم للمقوت — الفهرس `dealerId ↑ · date ↓`.
final discountsProvider = StreamProvider.family<List<DiscountCard>, String>(
  (Ref ref, String dealerId) =>
      ref.watch(discountDirectoryProvider).watchDiscounts(dealerId: dealerId),
);

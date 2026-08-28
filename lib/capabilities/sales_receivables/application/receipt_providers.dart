/// مزوّدات المقبوضات وحساب المقوت (`WU-007`).
///
/// ★ **بنفس نمط `distribution_providers.dart`:** المستودعات **تُحقَن في
/// الجذر ولا تُبنى هنا** (`ADR-0010`) — ⟵ **فتُختبَر الشاشات بلا سحابة
/// ولا شبكة**.
///
/// ⚠️⚠️ **وكل ما هنا عرضٌ لا تفويض:** إخفاء عمود الإيداع بـ
/// `receiptDepositView` **إخفاء لا حماية** — ★ **والحماية شرطُ القراءة على
/// `deposit/current` في `firestore.rules` وفحصُ المفتاح في الدالة السحابية**
/// (`ADR-0013` القاعدة 3 · `RISK-02` · `FR-M12-16`).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qtms_domain/qtms_domain.dart';

/// دليل المقبوضات — ⛔ **يُحقَن في الجذر**.
final Provider<ReceiptDirectory> receiptDirectoryProvider =
    Provider<ReceiptDirectory>((Ref ref) {
  throw UnimplementedError('receiptDirectoryProvider يجب تجاوزه عند الجذر');
});

/// مستودع كتابة المقبوضات — ⛔ **يُحقَن في الجذر**.
final Provider<ReceiptAdminRepository> receiptAdminProvider =
    Provider<ReceiptAdminRepository>((Ref ref) {
  throw UnimplementedError('receiptAdminProvider يجب تجاوزه عند الجذر');
});

/// وسيط قراءة الضمارات المفتوحة لمقوت.
///
/// ⛔⛔★★★ **و[sourceIds] قائمةٌ مُعدَّدة دائماً ⛔ لا `null` تعني «الكل»:**
/// ★ **شرطُ قراءة `distributions` يعتمد `resource.data.sourceId`** —
/// ⟵ **واستعلامٌ لا يُقيّده يُرفَض كاملاً ولو بنطاقٍ شامل** (`IQ-024` ·
/// `WU-008` · `DEBT-40`). ★ **فـ«الكل» تُبنى هنا من مصادر المستخدم**
/// (`activeSourcesProvider`) ⛔ **ولا تصل الدليلَ غياباً.**
final class OpenDebtQuery {
  /// ينشئ الوسيط.
  OpenDebtQuery({required this.dealerId, required List<String> sourceIds})
      : sourceIds = List<String>.unmodifiable(sourceIds);

  /// المقوت.
  final String dealerId;

  /// ★ المصادر المطلوبة — **واحدٌ أو كلُّ مصادر المستخدم** (`FR-M12-04`).
  final List<String> sourceIds;

  @override
  bool operator ==(Object other) {
    if (other is! OpenDebtQuery) return false;
    if (other.dealerId != dealerId) return false;
    if (other.sourceIds.length != sourceIds.length) return false;
    for (int i = 0; i < sourceIds.length; i++) {
      if (other.sourceIds[i] != sourceIds[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(dealerId, Object.hashAll(sourceIds));
}

/// ⛅ الضمارات المفتوحة للمقوت — `FR-M12-05`.
final openDebtLotsProvider =
    StreamProvider.family<List<OpenDebtLot>, OpenDebtQuery>(
  (Ref ref, OpenDebtQuery query) =>
      ref.watch(receiptDirectoryProvider).watchOpenDebtLots(
            dealerId: query.dealerId,
            sourceIds: query.sourceIds,
          ),
);

/// ⛅ سندات القبض للمقوت — الفهرس `dealerId ↑ · date ↓`.
final receiptsProvider =
    StreamProvider.family<List<ReceiptCard>, String>(
  (Ref ref, String dealerId) =>
      ref.watch(receiptDirectoryProvider).watchReceipts(dealerId: dealerId),
);

/// 🔒 ⛅ حالة إيداع سندٍ — ⛔ **و`null` تعني «لا تعرض العمود»** (`FR-M12-16`).
final receiptDepositProvider =
    StreamProvider.family<ReceiptDepositCard?, String>(
  (Ref ref, String documentNumber) =>
      ref.watch(receiptDirectoryProvider).watchReceiptDeposit(
            documentNumber: documentNumber,
          ),
);

/// وسيط قراءة الفائض المتاح.
final class SurplusQuery {
  /// ينشئ الوسيط.
  const SurplusQuery({
    required this.dealerId,
    required this.scope,
    this.sourceId,
  });

  /// المقوت.
  final String dealerId;

  /// النطاق.
  final SurplusScope scope;

  /// المصدر — **إلزامي مع [SurplusScope.source]**.
  final String? sourceId;

  @override
  bool operator ==(Object other) =>
      other is SurplusQuery &&
      other.dealerId == dealerId &&
      other.scope == scope &&
      other.sourceId == sourceId;

  @override
  int get hashCode => Object.hash(dealerId, scope, sourceId);
}

/// ⛅ الفائض المتاح — ⛅ **مشتقٌّ يُقرأ للعرض** (`ADR-0008`).
final availableSurplusProvider =
    StreamProvider.family<Money?, SurplusQuery>(
  (Ref ref, SurplusQuery query) =>
      ref.watch(receiptDirectoryProvider).watchAvailableSurplus(
            dealerId: query.dealerId,
            scope: query.scope,
            sourceId: query.sourceId,
          ),
);

/// ★★★ **اقتراح التوزيع التلقائي** — ⛔ **اقتراحٌ لا قرار** (`FR-M12-14`).
///
/// ⛔⛔★★★ **ومزوّدٌ للعرض وحده لا للحفظ** — نصّ المتطلب: «**تُعرض نتيجة
/// التوزيع التلقائي للمراجعة والتعديل قبل الحفظ ولا تُحفظ تلقائياً —
/// والحساب يجري محلياً في التطبيق بلا كتابة**». ⟵ **فما يُحفَظ هو ما أقرّه
/// المستخدم في الشاشة** ⛔ **لا مخرَجُ هذا المزوّد مباشرةً.**
///
/// ★ **والمعادلة من طبقة النطاق** ([allocateReceiptAutomatically]) —
/// ⛔ **ولا نسخة ثانية منها في الشاشة** (`ADR-0009`).
AutoAllocationProposal proposeAutoAllocation({
  required Money amount,
  required List<OpenDebtLot> openLots,
}) =>
    allocateReceiptAutomatically(amount: amount, openLots: openLots);

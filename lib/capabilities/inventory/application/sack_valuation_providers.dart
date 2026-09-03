/// مزوّدات مالية الجواني وحساب الرعوي (`M14` · `WU-015`).
///
/// ★ **بنفس نمط `inventory_providers.dart`:** المستودعات **تُحقَن في الجذر
/// ولا تُبنى هنا** (`ADR-0010`) — ⟵ **فتُختبَر الشاشة بلا سحابة ولا شبكة**.
///
/// ⚠️⚠️ **وكل ما هنا عرضٌ لا تفويض:** إخفاء بطاقةٍ بـ`supplierFinanceView`
/// **إخفاء لا حماية** — ★ **والحماية شرطُ القراءة في `firestore.rules`**
/// (`RISK-02`).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qtms_domain/qtms_domain.dart';

/// دليل مالية الجواني — ⛔ **يُحقَن في الجذر**.
final Provider<SackValuationDirectory> sackValuationDirectoryProvider =
    Provider<SackValuationDirectory>((Ref ref) {
  throw UnimplementedError(
    'sackValuationDirectoryProvider يجب تجاوزه عند الجذر',
  );
});

/// ★ وسيط حساب الرعوي — **الرعوي والمصدر معاً** (`A-11`).
///
/// ⛔⛔ **ولا وسيطَ بلا مصدر** — `GR-21` · `ADR-0005`: ⟵ **فلكل رعوي حسابٌ
/// في كل مصدر**، ★ **والجمعُ عبر المصادر عرضٌ يبنيه المُستدعي** ⛔ **لا
/// استعلامٌ يُسقِط المصدر.**
final class SupplierAccountQuery {
  /// ينشئ الوسيط.
  const SupplierAccountQuery({
    required this.supplierId,
    required this.sourceId,
  });

  /// الرعوي.
  final String supplierId;

  /// المصدر.
  final String sourceId;

  @override
  bool operator ==(Object other) =>
      other is SupplierAccountQuery &&
      other.supplierId == supplierId &&
      other.sourceId == sourceId;

  @override
  int get hashCode => Object.hash(supplierId, sourceId);
}

/// ★ وسيط تفكيك سعر جونية — **الجونية ومصدرها ويومها** (`FR-M14-15`).
final class SackBreakdownQuery {
  /// ينشئ الوسيط.
  const SackBreakdownQuery({
    required this.sackId,
    required this.sourceId,
    required this.stockDate,
  });

  /// رقم الجونية.
  final String sackId;

  /// المصدر.
  final String sourceId;

  /// ★ تاريخ المخزون — ⛔ **لا تاريخ الإدخال** (`RISK-07`).
  final CalendarDay stockDate;

  @override
  bool operator ==(Object other) =>
      other is SackBreakdownQuery &&
      other.sackId == sackId &&
      other.sourceId == sourceId &&
      other.stockDate == stockDate;

  @override
  int get hashCode => Object.hash(sackId, sourceId, stockDate);
}

/// 🔒 **رصيد الرعوي في مصدر** — و`null` تعني **«لا حساب بعد أو لا صلاحية»**.
final supplierBalanceProvider =
    StreamProvider.family<SupplierBalanceCard?, SupplierAccountQuery>(
  (Ref ref, SupplierAccountQuery query) =>
      ref.watch(sackValuationDirectoryProvider).watchSupplierBalance(
            supplierId: query.supplierId,
            sourceId: query.sourceId,
          ),
);

/// 🔒 **سطور دفتر الرعية** — ★ **جوانيه في هذا المصدر عبر كل الأيام**.
final supplierLedgerProvider =
    StreamProvider.family<List<SupplierLedgerRow>, SupplierAccountQuery>(
  (Ref ref, SupplierAccountQuery query) =>
      ref.watch(sackValuationDirectoryProvider).watchSupplierLedger(
            supplierId: query.supplierId,
            sourceId: query.sourceId,
          ),
);

/// ★★★ **تفكيك سعر الجونية** — `FR-M14-15`.
///
/// ⚠️ **قراءةٌ عند الطلب لا تدفّقٌ دائم** — راجع
/// [SackValuationDirectory.loadSackContributions].
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **و`autoDispose` شرطُ صحةٍ لا تحسينُ ذاكرة** ([`DEBT-90`] ·
/// **مقيسٌ حيّاً 2026-09-03**): ★ **القراءةُ لمرةٍ واحدة تُخزَّن بمفتاح
/// العائلة ما دام لها مستمع** — ⟵ **ووسيطُها ثابتٌ** (الجونية والمصدر
/// واليوم)، ⟹ **ففتحُ الورقة بعد توزيعةٍ جديدة كان يُعيد لقطةً قديمة**:
/// ★ **الإجمالي المخزَّن 20000 والتفكيكُ يقول «لم يخرج منها شيء بعد».**
///
/// ⛔⛔ **وهذا يناقض `ADR-0008` في جوهره** — ★ **«الرصيد مشتقٌّ من الدفتر
/// دائماً»**: ⟵ **ولا يُعرَض رقمٌ لا يُعاد اشتقاقُه.** ★ **والورقةُ
/// مستمعُها الوحيد** ⟹ **فإغلاقُها يُسقِط الحالة وفتحُها يقرأ من جديد.**
/// ═══════════════════════════════════════════════════════════════════════
final sackBreakdownProvider = FutureProvider.autoDispose.family<
    Outcome<List<SackRevenueContribution>>, SackBreakdownQuery>(
  (Ref ref, SackBreakdownQuery query) =>
      ref.watch(sackValuationDirectoryProvider).loadSackContributions(
            sackId: query.sackId,
            sourceId: query.sourceId,
            stockDate: query.stockDate,
          ),
);

/// ★ الرعوي المختار في شاشة مالية الجواني — و`null` تعني **«كل الرعية»**.
///
/// ⚠️ **وخيار «الكل» مشروعٌ هنا بخلاف المصدر** — `FR-M14-01`: **المرشِّح
/// «الرعوي» اختياري**، ⟵ **والشاشةُ استعراضٌ لا عملية** (`AM-009` ③ يخصّ
/// **شاشات العمليات**). ⛔ **ولا يُجمَع بين مصدرين مهما كان المرشِّح.**
final NotifierProvider<SelectedSupplier, String?> selectedSupplierProvider =
    NotifierProvider<SelectedSupplier, String?>(SelectedSupplier.new);

/// حالة الرعوي المختار.
class SelectedSupplier extends Notifier<String?> {
  @override
  String? build() => null;

  /// يختار رعوياً أو يُعيد إلى «كل الرعية».
  void select(String? supplierId) => state = supplierId;
}

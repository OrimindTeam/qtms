/// مزوّدات البيع النقدي المباشر (`WU-012`).
///
/// ★ **بنفس نمط `distribution_providers.dart`:** المستودعات **تُحقَن في
/// الجذر ولا تُبنى هنا** (`ADR-0010`) — ⟵ **فتُختبَر الشاشات بلا سحابة.**
///
/// ⛔⛔★★★ **ولا مزوّدَ واحدٌ يمسّ مقوتاً ولا رصيدَ ذمّة** — `FR-M11-03`:
/// ★ **البيعُ النقدي لا يُنشئ ذمّةً على أحد**، ⟵ **فلا رصيدَ يُعرَض ولا
/// فائضَ يُطبَّق** ⛔ **ولا قائمةَ مقاوته تُقرأ في هذه الشاشة أصلاً.**
///
/// ⚠️⚠️ **وكل ما هنا عرضٌ لا تفويض** — ★ **والحماية في `planCashSale`**
/// (`ADR-0013` القاعدة 3 · `RISK-02`).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qtms_domain/qtms_domain.dart';

import '../../../core/state/combine_async.dart';
import '../../inventory/application/inventory_providers.dart';
import '../../master_data/application/master_data_providers.dart';

/// دليل البيع النقدي — ⛔ **يُحقَن في الجذر**.
final Provider<CashSaleDirectory> cashSaleDirectoryProvider =
    Provider<CashSaleDirectory>((Ref ref) {
  throw UnimplementedError('cashSaleDirectoryProvider يجب تجاوزه عند الجذر');
});

/// مستودع كتابة البيع النقدي — ⛔ **يُحقَن في الجذر**.
final Provider<CashSaleAdminRepository> cashSaleAdminProvider =
    Provider<CashSaleAdminRepository>((Ref ref) {
  throw UnimplementedError('cashSaleAdminProvider يجب تجاوزه عند الجذر');
});

/// وسيط قراءة سندات يومٍ لمصدر.
///
/// ⚠️ **ونوعٌ مستقل عن `StockQuery` و`DistributionQuery` عمداً** — ★ **وإن
/// تطابقت حقولها**: `coding-standards.md` §2.3 يمنع أن يقبل أحدها مكان
/// الآخر، ⟵ **فلا يُمرَّر وسيطُ توزيعٍ إلى استعلام بيعٍ نقدي بصمت.**
final class CashSaleQuery {
  /// ينشئ الوسيط.
  const CashSaleQuery({required this.sourceId, required this.stockDate});

  /// المصدر.
  final String sourceId;

  /// تاريخ المخزون — ⛔ **لا تاريخ الإدخال** (`RISK-07`).
  final CalendarDay stockDate;

  @override
  bool operator ==(Object other) =>
      other is CashSaleQuery &&
      other.sourceId == sourceId &&
      other.stockDate == stockDate;

  @override
  int get hashCode => Object.hash(sourceId, stockDate);
}

/// ⛅ سندات اليوم للمصدر المطلوب.
final cashSalesProvider =
    StreamProvider.family<List<CashSaleCard>, CashSaleQuery>(
  (Ref ref, CashSaleQuery query) =>
      ref.watch(cashSaleDirectoryProvider).watchCashSales(
            sourceId: query.sourceId,
            stockDate: query.stockDate,
          ),
);

/// ★★★ **سنداتُ اليوم — بمصدرٍ واحد أو بكل المصادر** (`AM-009` ③).
///
/// ⛔⛔★★★ **واستعلامٌ مقيَّدٌ لكل مصدرٍ ثم دمج** — راجع [combineAsyncLists]:
/// ⟵ **فشرطُ `storedInScope()` يقرأ `resource.data.sourceId`**، ★ **والشرط
/// يُقيَّم على قيود الاستعلام لا على كل مستند** ⛔ **فاستعلامٌ واحدٌ غيرُ
/// مقيَّد يُرفَض كاملاً** (`IQ-024` · `WU-008`).
///
/// ⛔⛔ **و«الكل» لا تخالف `A-01`:** ★ **`A-01` يمنع الجمع بين مصدرين في
/// *عملية*** ⟵ **وهذا *سرد***: **كلُّ صفٍّ يبقى سنداً في مصدره ويُسمّي
/// مصدرَه**، ⛔ **ولا رقمَ يُجمَع عبر مصدرين.**
final cashSaleListProvider =
    Provider.family<AsyncValue<List<CashSaleCard>>, SourceListQuery>(
  (Ref ref, SourceListQuery query) => combineAsyncLists<CashSaleCard>(
    <AsyncValue<List<CashSaleCard>>>[
      for (final String sourceId in listedSourceIds(ref, query))
        ref.watch(
          cashSalesProvider(
            CashSaleQuery(sourceId: sourceId, stockDate: query.stockDate),
          ),
        ),
    ],
    // ★ **وترتيبٌ ثابتٌ برقم المستند** — ⟵ **فهو عنوانُ السجلّ هنا**:
    //   ⛔ **ولا مشترٍ يُسمّى** (`FR-M11-12`).
    compare: (CashSaleCard a, CashSaleCard b) =>
        a.documentNumber.compareTo(b.documentNumber),
  ),
);

/// ★★★ سندُ بيعٍ نقدي بعينه من قائمة اليوم — و`null` تعني **غيابه**.
///
/// ⛔⛔★★ **ويُشتقّ من قائمة اليوم ⛔ لا يُقرأ بمعرّفه** — ★ **درسُ `DEBT-40`**:
/// **قراءةُ المستند بمعرّفه تُرفَض ما دام غائباً** لأن شرطها يعتمد
/// `resource.data.sourceId`، ⟵ **والقائمةُ مقيَّدةٌ بفهرسٍ قائم.**
final cashSaleByNumberProvider =
    Provider.family<AsyncValue<CashSaleCard?>, CashSaleDocumentQuery>(
  (Ref ref, CashSaleDocumentQuery query) => ref
      .watch(
        cashSalesProvider(
          CashSaleQuery(sourceId: query.sourceId, stockDate: query.stockDate),
        ),
      )
      .whenData((List<CashSaleCard> cards) {
    for (final CashSaleCard card in cards) {
      if (card.documentNumber == query.documentNumber) return card;
    }
    return null;
  }),
);

/// وسيط البحث عن سندٍ بعينه — **المصدر والرقم واليوم**.
final class CashSaleDocumentQuery {
  /// ينشئ الوسيط.
  const CashSaleDocumentQuery({
    required this.sourceId,
    required this.documentNumber,
    required this.stockDate,
  });

  /// المصدر.
  final String sourceId;

  /// رقم المستند.
  final String documentNumber;

  /// تاريخ المخزون.
  final CalendarDay stockDate;

  @override
  bool operator ==(Object other) =>
      other is CashSaleDocumentQuery &&
      other.sourceId == sourceId &&
      other.documentNumber == documentNumber &&
      other.stockDate == stockDate;

  @override
  int get hashCode => Object.hash(sourceId, documentNumber, stockDate);
}

/// ★ الأنواع المتاحة للبيع النقدي من مصدرٍ بعينه.
///
/// ⛔★★ **ولا يظهر فيها نوع غير مرتبط بالمصدر ولا معطَّل** (`FR-M5-10`).
///
/// ★★ **ويظهر فيها «السكرب»** — ⟵ **لأنه يُباع بالكيلوجرام** (`FR-M11-11`)،
/// ⛔ **وإنما لا يُورَّد من شاشة الوارد عدداً** (`design-overview.md` §2.2).
///
/// ⚠️⚠️ **وهذه تصفيةُ عرضٍ لا حماية** — ★ **والدالة السحابية تُعيد الفحص
/// نفسه على سجل النوع** (`cash_sale.dart` `_planSale`).
final cashSaleItemsProvider =
    Provider.family<List<ItemCard>, String>((Ref ref, String sourceId) {
  final List<ItemCard> all =
      ref.watch(itemsProvider).value ?? const <ItemCard>[];
  return <ItemCard>[
    for (final ItemCard item in all)
      if (item.isActive && item.sourceIds.contains(sourceId)) item,
  ];
});

/// ★★★ **الحدود الدنيا للبيع النقدي لأنواع اليوم** — `FR-M11-05` · `GR-34`.
///
/// ⚠️⚠️ **وقائمةٌ لا تحوي نوعاً تعني «لا حدَّ مسجَّلاً له»** (`FR-M11-06`)
/// ⛔ **لا حدّاً بصفر**: ⟵ **فالشاشة تُنبِّه «النوع غير مسعَّر»**،
/// ★ **والسحابة تسمح بالبيع** — ⛔ **ولا تطلب مفتاح تجاوزٍ لا معنى له.**
///
/// ⚠️ **وهو حدُّ عرضٍ لا حارس** — ★ **والرفضُ في `_minimumPriceGate` داخل
/// المعاملة** (`ADR-0013` القاعدة 3): ⟵ **فما هنا تنبيهٌ مبكّر لا أكثر.**
final minimumCashPricesProvider =
    Provider.family<Map<String, Money>, CashSaleQuery>(
  (Ref ref, CashSaleQuery query) {
    final List<DailyPriceCard> prices = ref
            .watch(
              dailyPricesProvider(
                PricingQuery(sourceId: query.sourceId, date: query.stockDate),
              ),
            )
            .value ??
        const <DailyPriceCard>[];
    return <String, Money>{
      for (final DailyPriceCard price in prices)
        if (price.minCashPrice case final Money value) price.itemKey: value,
    };
  },
);

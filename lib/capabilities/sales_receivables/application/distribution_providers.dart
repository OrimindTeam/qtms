/// مزوّدات التوزيع والضمار (`WU-006`).
///
/// ★ **بنفس نمط `inventory_providers.dart`:** المستودعات **تُحقَن في الجذر
/// ولا تُبنى هنا** (`ADR-0010`) — ⟵ **فتُختبَر الشاشات بلا سحابة ولا شبكة**.
///
/// ⚠️⚠️ **وكل ما هنا عرضٌ لا تفويض:** إخفاء عمود السعر بـ
/// `distributionPriceView` **إخفاء لا حماية** — ★ **والحماية شرطُ القراءة
/// على `pricing/current` في `firestore.rules` وفحصُ المفتاح في الدالة
/// السحابية** (`ADR-0013` القاعدة 3 · `RISK-02` · `ت-12`).
library;

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qtms_domain/qtms_domain.dart';

import '../../../core/state/combine_async.dart';
import '../../inventory/application/inventory_providers.dart';
import '../../master_data/application/master_data_providers.dart';

/// دليل التوزيع — ⛔ **يُحقَن في الجذر**.
final Provider<DistributionDirectory> distributionDirectoryProvider =
    Provider<DistributionDirectory>((Ref ref) {
  throw UnimplementedError(
    'distributionDirectoryProvider يجب تجاوزه عند الجذر',
  );
});

/// مستودع كتابة التوزيع — ⛔ **يُحقَن في الجذر**.
final Provider<DistributionAdminRepository> distributionAdminProvider =
    Provider<DistributionAdminRepository>((Ref ref) {
  throw UnimplementedError('distributionAdminProvider يجب تجاوزه عند الجذر');
});

/// وسيط قراءة توزيعات يومٍ لمصدر.
///
/// ⚠️ **ونوعٌ مستقل عن `StockQuery` عمداً** — ★ **وإن تطابقا حقلاً**:
/// `coding-standards.md` §2.3 يمنع أن يقبل أحدهما مكان الآخر، ⟵ **فلا
/// يُمرَّر وسيطُ مخزونٍ إلى استعلام توزيعات بصمت.**
final class DistributionQuery {
  /// ينشئ الوسيط.
  const DistributionQuery({required this.sourceId, required this.stockDate});

  /// المصدر.
  final String sourceId;

  /// تاريخ المخزون — ⛔ **لا تاريخ الإدخال** (`RISK-07`).
  final CalendarDay stockDate;

  @override
  bool operator ==(Object other) =>
      other is DistributionQuery &&
      other.sourceId == sourceId &&
      other.stockDate == stockDate;

  @override
  int get hashCode => Object.hash(sourceId, stockDate);
}

/// ⛅ توزيعات اليوم للمصدر المطلوب.
final distributionsProvider =
    StreamProvider.family<List<DistributionCard>, DistributionQuery>(
  (Ref ref, DistributionQuery query) =>
      ref.watch(distributionDirectoryProvider).watchDistributions(
            sourceId: query.sourceId,
            stockDate: query.stockDate,
          ),
);

/// ★★★ **توزيعاتُ اليوم — بمصدرٍ واحد أو بكل المصادر** (`AM-009` ③ · ⑦).
///
/// ⛔⛔★★★ **واستعلامٌ مقيَّدٌ لكل مصدرٍ ثم دمج** — راجع [combineAsyncLists]:
/// ⟵ **فشرطُ `storedInScope()` يقرأ `resource.data.sourceId`**، ★ **والشرط
/// يُقيَّم على قيود الاستعلام لا على كل مستند** ⛔ **فاستعلامٌ واحدٌ غيرُ
/// مقيَّد يُرفَض كاملاً** (`IQ-024` · `WU-008`).
final distributionListProvider =
    Provider.family<AsyncValue<List<DistributionCard>>, SourceListQuery>(
  (Ref ref, SourceListQuery query) => combineAsyncLists<DistributionCard>(
    <AsyncValue<List<DistributionCard>>>[
      for (final String sourceId in listedSourceIds(ref, query))
        ref.watch(
          distributionsProvider(
            DistributionQuery(sourceId: sourceId, stockDate: query.stockDate),
          ),
        ),
    ],
    // ★ **وترتيبٌ ثابتٌ باسم المقوت** — ⟵ **فهو عنوانُ السجلّ**،
    //   ⛔ **ولا ترتيبَ يتبع وصولَ التدفّقات.**
    compare: (DistributionCard a, DistributionCard b) =>
        a.dealerName.compareTo(b.dealerName),
  ),
);

/// وسيط البحث عن توزيعة مقوتٍ في يوم — **المصدر والمقوت واليوم**.
final class DealerDistributionQuery {
  /// ينشئ الوسيط.
  const DealerDistributionQuery({
    required this.sourceId,
    required this.dealerId,
    required this.stockDate,
  });

  /// المصدر.
  final String sourceId;

  /// المقوت.
  final String dealerId;

  /// تاريخ المخزون.
  final CalendarDay stockDate;

  @override
  bool operator ==(Object other) =>
      other is DealerDistributionQuery &&
      other.sourceId == sourceId &&
      other.dealerId == dealerId &&
      other.stockDate == stockDate;

  @override
  int get hashCode => Object.hash(sourceId, dealerId, stockDate);
}

/// ★★★ توزيعةُ المقوت اليوم — **مسار `E-04`**، و`null` تعني **غيابها**.
///
/// ⟵ **فالشاشة تعرف قبل الحفظ أن للمقوت توزيعةً اليوم فتفتحها للتعديل**،
/// ⛔ **ولا تُرسل إنشاءً يُرفَض** (`FR-M10-01`).
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **وتُشتقّ من قائمة اليوم ⛔ لا تُقرأ بمعرّفها المركّب** —
/// **عطلٌ رُصد حيّاً على المحاكي (2026-08-27):** ★ **قراءةُ المستند الغائب
/// بمعرّفه تُرفَض بـ`PERMISSION_DENIED`** لأن `storedInScope()` يقرأ
/// `resource.data.sourceId` **ولا `resource` لمستندٍ غائب** — ⟵ **فأشيعُ
/// حالات `E-04` (لا توزيعة بعد) كانت تُبقي الشاشة على الهيكل العظمي أبداً.**
///
/// ★★ **وهي مقايسةُ `IQ-024` و`WU-008` نفسها** (`CLAUDE.md`): **الشرط
/// يُقيَّد في الاستعلام** — ⟵ **و[distributionsProvider] مقيَّدةٌ بـ`sourceId`
/// و`stockDate` بفهرسٍ قائم**، ⛔ **والعلاج تقييدُ الاستعلام لا تخفيفُ
/// القاعدة.**
/// ═══════════════════════════════════════════════════════════════════════
final dealerDistributionProvider =
    Provider.family<AsyncValue<DistributionCard?>, DealerDistributionQuery>(
  (Ref ref, DealerDistributionQuery query) {
    final AsyncValue<List<DistributionCard>> day = ref.watch(
      distributionsProvider(
        DistributionQuery(
          sourceId: query.sourceId,
          stockDate: query.stockDate,
        ),
      ),
    );
    return day.whenData((List<DistributionCard> cards) {
      for (final DistributionCard card in cards) {
        if (card.dealerId == query.dealerId) return card;
      }
      // ★ **والغياب `null` ⛔ لا خطأ** — **وهو الحالة الطبيعية قبل أول
      //   توزيعة** لهذا (المقوت × المصدر × اليوم).
      return null;
    });
  },
);

/// 🔒 أسعار توزيعةٍ — ⛔ **ولا تصل إلا لمن يملك `distributionPriceView`**.
///
/// ⚠️ **و`null` تعني «لا أرى» أو «لا يوجد» معاً** — ★ **والشاشة لا تحتاج
/// التمييز**: **كلاهما «لا تعرض عمود السعر»** (`ت-12`).
final distributionPricingProvider =
    StreamProvider.family<DistributionPricingCard?, String>(
  (Ref ref, String distributionId) =>
      ref.watch(distributionDirectoryProvider).watchDistributionPricing(
            distributionId: distributionId,
          ),
);

/// ★ المقاوته المتاحون للتوزيع — `FR-M10-12` · `schema/dealers.md` ④.
///
/// ⛔★★ **ولا يظهر فيها مقوتٌ معطَّل** — ★ **ويظهر في المقبوضات والخصومات**،
/// ⟵ **فالتصفية هنا لا في سجل المقوت نفسه.**
///
/// ⚠️⚠️ **وهذه تصفيةُ عرضٍ لا حماية** — ★ **والدالة السحابية تُعيد الفحص
/// نفسه على سجل المقوت** (`distribution.dart` `_partiesGate`).
/// ★★ رصيد المقوت في مصدر — 🔒 **بـ`dealerBalanceView`** (`WU-010`).
///
/// ⚠️ **و`null` تعني «لا أرى» أو «لا يوجد» معاً** — ★ **والتمييز لا يلزم
/// الشاشة**: ⟵ **كلاهما «لا يُعرَض القالب ② للرسالة»** (`FR-M20-07`).
final dealerBalanceProvider =
    StreamProvider.family<DealerBalanceCard?, DealerBalanceQuery>(
  (Ref ref, DealerBalanceQuery query) =>
      ref.watch(distributionDirectoryProvider).watchDealerBalance(
            dealerId: query.dealerId,
            sourceId: query.sourceId,
          ),
);

/// مفتاح استعلام رصيد المقوت.
@immutable
final class DealerBalanceQuery {
  /// ينشئ المفتاح.
  const DealerBalanceQuery({required this.dealerId, required this.sourceId});

  /// المقوت.
  final String dealerId;

  /// ★ المصدر — **والرصيد يخصّه وحده** (`GR-20`).
  final String sourceId;

  @override
  bool operator ==(Object other) =>
      other is DealerBalanceQuery &&
      other.dealerId == dealerId &&
      other.sourceId == sourceId;

  @override
  int get hashCode => Object.hash(dealerId, sourceId);
}

final Provider<List<DealerCard>> distributionDealersProvider =
    Provider<List<DealerCard>>((Ref ref) {
  final List<DealerCard> all =
      ref.watch(dealersProvider).value ?? const <DealerCard>[];
  return <DealerCard>[
    for (final DealerCard dealer in all)
      if (dealer.isActive) dealer,
  ];
});

/// ★ الأنواع المتاحة للتوزيع من مصدرٍ بعينه.
///
/// ⛔★★ **ولا يظهر فيها نوع غير مرتبط بالمصدر ولا معطَّل** (`FR-M5-10`).
///
/// ★★ **ويظهر فيها «السكرب» بخلاف شاشة الوارد عدداً** — ⟵ **لأن السكرب
/// **يُوزَّع** بالكيلوجرام** (`FR-M10-15` · `AT-21`)، ⛔ **وإنما لا **يُورَّد**
/// من تلك الشاشة** (`design-overview.md` §2.2). ★ **والفرق مقصود.**
final distributionItemsProvider =
    Provider.family<List<ItemCard>, String>((Ref ref, String sourceId) {
  final List<ItemCard> all =
      ref.watch(itemsProvider).value ?? const <ItemCard>[];
  return <ItemCard>[
    for (final ItemCard item in all)
      if (item.isActive && item.sourceIds.contains(sourceId)) item,
  ];
});

/// ★ سعر التوزيع المقترح لنوعٍ من التسعير اليومي — `FR-M10-09`.
///
/// ⚠️⚠️ **واقتراحٌ لا التزام** (`FR-M9-07`) — ★ **والشاشة تملؤه تلقائياً**،
/// ⛔ **والمستخدم يملك تغييره بصلاحيته** (`distributionPriceAmend`).
///
/// ★★ **ويُطبَّق حتى على من لا يرى السعر** — `FR-M10-07`: «**يُطبَّق سعر
/// التسعير اليومي تلقائياً وتُحتسب قيمة الضمار كاملة**»، ⟵ **وهو أكثر ما
/// يُساء فهمه في هذه الوحدة.**
final suggestedDistributionPricesProvider =
    Provider.family<Map<String, Money>, DistributionQuery>(
  (Ref ref, DistributionQuery query) {
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
        if (price.distributionPrice case final Money value)
          price.itemKey: value,
    };
  },
);

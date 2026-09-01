/// مزوّدات المخزون (`WU-003`).
///
/// ★ **بنفس نمط `master_data_providers.dart`:** المستودعات **تُحقَن في الجذر
/// ولا تُبنى هنا** (`ADR-0010`) — ⟵ **فتُختبَر الشاشات بلا سحابة ولا شبكة**.
///
/// ⚠️⚠️ **وكل ما هنا عرضٌ لا تفويض:** إخفاء زرٍّ بـ`incomingCountWrite`
/// **إخفاء لا حماية** — ★ **والحماية إغلاقُ الكتابة في `firestore.rules`
/// وفحصُ المفتاح والنطاق في الدالة السحابية** (`ADR-0013` القاعدة 3 · `RISK-02`).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qtms_domain/qtms_domain.dart';

import '../../../core/state/combine_async.dart';
import '../../master_data/application/master_data_providers.dart';

/// دليل المخزون — ⛔ **يُحقَن في الجذر**.
final Provider<InventoryDirectory> inventoryDirectoryProvider =
    Provider<InventoryDirectory>((Ref ref) {
  throw UnimplementedError('inventoryDirectoryProvider يجب تجاوزه عند الجذر');
});

/// مستودع كتابة المخزون — ⛔ **يُحقَن في الجذر**.
final Provider<InventoryAdminRepository> inventoryAdminProvider =
    Provider<InventoryAdminRepository>((Ref ref) {
  throw UnimplementedError('inventoryAdminProvider يجب تجاوزه عند الجذر');
});

/// ★★ **اليوم الجاري** — `FR-M8-05`: **شاشة مخزون اليوم تعرض اليوم وحده 🔒**.
///
/// ⚠️⚠️ **وهو يوم UTC كما تعرّفه السحابة والقواعد** (`request.time.date()`)
/// — ⟵ **فما يُقرأ هنا يطابق ما كُتب هناك.** ⛔ **ولا يُخزَّن منه شيء:**
/// `GR-54` يمنع ساعة الجهاز في **حقلٍ يُخزَّن**، ★ **والقراءة ليست تخزيناً**؛
/// **وتاريخ المخزون المكتوب يأتي من المنصّة داخل المعاملة** (`inventory_handler.dart`).
///
/// ★ **ويُتجاوَز في الاختبار** ليُثبَّت اليوم — ⛔ **فلا اختبارَ ينكسر بمرور
/// منتصف الليل.**
final Provider<CalendarDay> todayProvider = Provider<CalendarDay>(
  (Ref ref) => CalendarDay.fromUtc(DateTime.now()),
);

/// ★ المصدر المختار في شاشات المخزون — و`null` تعني **لم يُختَر بعد**.
///
/// ⚠️ **ولماذا اختيارٌ صريح لا «كل المصادر»:** `FR-M8-04` (`A-01`): **رصيد
/// كل نوع مستقل في كل مصدر** ⛔ **ولا يُجمَع بين مصدرين في أي عملية** —
/// ⟵ **فشاشةٌ بلا مصدرٍ محدَّد كانت ستُغري بجمعٍ ممنوع.**
final NotifierProvider<SelectedSource, String?> selectedSourceProvider =
    NotifierProvider<SelectedSource, String?>(SelectedSource.new);

/// حالة المصدر المختار.
class SelectedSource extends Notifier<String?> {
  @override
  String? build() {
    final List<SourceCard> sources = ref.watch(activeSourcesProvider);
    if (sources.isEmpty) return null;
    // ★ **أول مصدرٍ في نطاق المستخدم افتراضاً** — ⟵ **فمن له مصدرٌ واحد
    //   لا يختار شيئاً**، ⛔ **ولا تُفتَح الشاشة فارغة بلا سبب ظاهر.**
    return sources.first.sourceId;
  }

  /// يختار مصدراً.
  void select(String sourceId) => state = sourceId;
}

/// وسيط قراءة مخزون اليوم — **المصدر والتاريخ معاً**.
final class StockQuery {
  /// ينشئ الوسيط.
  const StockQuery({required this.sourceId, required this.stockDate});

  /// المصدر.
  final String sourceId;

  /// تاريخ المخزون.
  final CalendarDay stockDate;

  @override
  bool operator ==(Object other) =>
      other is StockQuery &&
      other.sourceId == sourceId &&
      other.stockDate == stockDate;

  @override
  int get hashCode => Object.hash(sourceId, stockDate);
}

/// وسيط قراءة حركة نوع — **المصدر والنوع والتاريخ**.
final class MovementQuery {
  /// ينشئ الوسيط.
  const MovementQuery({
    required this.sourceId,
    required this.itemKey,
    required this.stockDate,
  });

  /// المصدر.
  final String sourceId;

  /// مفتاح النوع.
  final String itemKey;

  /// تاريخ المخزون.
  final CalendarDay stockDate;

  @override
  bool operator ==(Object other) =>
      other is MovementQuery &&
      other.sourceId == sourceId &&
      other.itemKey == itemKey &&
      other.stockDate == stockDate;

  @override
  int get hashCode => Object.hash(sourceId, itemKey, stockDate);
}

/// ⛅ أرصدة اليوم للمصدر المطلوب.
final todayStockProvider =
    StreamProvider.family<List<ItemDailyBalanceCard>, StockQuery>(
  (Ref ref, StockQuery query) =>
      ref.watch(inventoryDirectoryProvider).watchTodayStock(
            sourceId: query.sourceId,
            stockDate: query.stockDate,
          ),
);

/// سجل حركة نوعٍ في يوم — `FR-M8-06`.
final itemMovementsProvider =
    StreamProvider.family<List<StockMovementCard>, MovementQuery>(
  (Ref ref, MovementQuery query) =>
      ref.watch(inventoryDirectoryProvider).watchItemMovements(
            sourceId: query.sourceId,
            itemKey: query.itemKey,
            stockDate: query.stockDate,
          ),
);

/// ★★★ **مرشِّحُ المصدر في شاشات السرد** — `AM-009` ③، **و`null` تعني
/// «كل المصادر»**.
///
/// ⛔⛔★★★ **ومستقلٌّ عن [selectedSourceProvider] عمداً — والفرقُ ليس تجميلاً:**
/// ★ **`selectedSourceProvider` هو *سياقُ العملية*** — ⟵ **يجيب «على أي
/// مصدرٍ أكتب؟»**، ★ **و`null` فيه تعني «لا مصدرَ في النطاق» فتُوقِف الكتابة.**
/// ★ **وهذا *مرشِّحُ عرض*** — ⟵ **يجيب «أيَّ سجلاتٍ أرى؟»**، **و`null` فيه
/// تعني «كلَّها»**. ⛔ **ودمجُهما كان يجعل `null` تعني الشيءَ ونقيضَه.**
///
/// ★ **وافتراضُه «الكل»** — ⟵ **فأولُ ما يراه المستخدم يومُه كلُّه**،
/// ⛔ **لا مصدرٌ اختارته الأداةُ عنه فيظنّ القائمة كاملةً وهي مفلترة.**
final NotifierProvider<SourceListFilter, String?> sourceListFilterProvider =
    NotifierProvider<SourceListFilter, String?>(SourceListFilter.new);

/// حالة مرشِّح السرد.
class SourceListFilter extends Notifier<String?> {
  @override
  String? build() => null;

  /// يختار مصدراً — و`null` تعني **كل المصادر**.
  void select(String? sourceId) => state = sourceId;
}

/// ★ وسيطُ سردٍ بمصدرٍ **اختياري** — و`null` تعني **كل مصادر النطاق**.
final class SourceListQuery {
  /// ينشئ الوسيط.
  const SourceListQuery({required this.sourceId, required this.stockDate});

  /// المصدر — و`null` تعني **الكل**.
  final String? sourceId;

  /// تاريخ المخزون.
  final CalendarDay stockDate;

  @override
  bool operator ==(Object other) =>
      other is SourceListQuery &&
      other.sourceId == sourceId &&
      other.stockDate == stockDate;

  @override
  int get hashCode => Object.hash(sourceId, stockDate);
}

/// ★★ المصادر التي يشملها وسيطُ سردٍ — **واحدٌ أو كلُّ النطاق.**
List<String> listedSourceIds(Ref ref, SourceListQuery query) =>
    switch (query.sourceId) {
      final String id => <String>[id],
      null => <String>[
          for (final SourceCard source in ref.watch(activeSourcesProvider))
            source.sourceId,
        ],
    };

/// مستندات الوارد عدداً في اليوم.
final countedIntakesProvider =
    StreamProvider.family<List<CountedIntakeCard>, StockQuery>(
  (Ref ref, StockQuery query) =>
      ref.watch(inventoryDirectoryProvider).watchCountedIntakes(
            sourceId: query.sourceId,
            stockDate: query.stockDate,
          ),
);

/// ★★★ **الوارد عدداً في اليوم — بمصدرٍ واحد أو بكل المصادر** (`AM-009` ③).
///
/// ⛔⛔★★★ **واستعلامٌ مقيَّدٌ لكل مصدرٍ ثم دمج** — راجع [combineAsyncLists]:
/// ⟵ **فلا استعلامَ واحدٌ غيرُ مقيَّد يُرفَض كاملاً بشرط `storedInScope()`.**
final countedIntakeListProvider =
    Provider.family<AsyncValue<List<CountedIntakeCard>>, SourceListQuery>(
  (Ref ref, SourceListQuery query) => combineAsyncLists<CountedIntakeCard>(
    <AsyncValue<List<CountedIntakeCard>>>[
      for (final String sourceId in listedSourceIds(ref, query))
        ref.watch(
          countedIntakesProvider(
            StockQuery(sourceId: sourceId, stockDate: query.stockDate),
          ),
        ),
    ],
    // ★ **وترتيبٌ ثابتٌ بالمستند** — ⛔ **ولا ترتيبَ يتبع وصولَ التدفّقات**:
    //   ⟵ **فقائمةٌ تتبدّل مواضعُها بين إطارين تُفقِد المستخدم موضعَ إصبعه.**
    compare: (CountedIntakeCard a, CountedIntakeCard b) =>
        a.documentNumber.compareTo(b.documentNumber),
  ),
);

/// ★★★ **المتبقّي من كل نوعٍ في مصدرٍ اليوم** — `FR-M10-06`.
///
/// ⛔⛔★★ **وغيابُ النوع من الخريطة يعني صفراً** — `ADR-0008` القاعدة 5:
/// ★ **فقائمةٌ لا تحوي نوعاً تعني رصيدَه صفراً** ⛔ **لا أن النوع غير موجود.**
///
/// ⚠️ **وهو رصيدُ عرضٍ لا حارس** — ★ **والرفضُ على تجاوز المتاح في الدالة
/// السحابية داخل المعاملة** (`FR-M10-11` · `ADR-0013` القاعدة 3).
final remainingStockProvider =
    Provider.family<Map<String, StockQuantity>, StockQuery>(
  (Ref ref, StockQuery query) {
    final List<ItemDailyBalanceCard> balances =
        ref.watch(todayStockProvider(query)).value ??
            const <ItemDailyBalanceCard>[];
    return <String, StockQuantity>{
      for (final ItemDailyBalanceCard balance in balances)
        balance.itemKey: balance.balance,
    };
  },
);

/// ★ الأنواع المتاحة للتوريد من مصدرٍ بعينه — `FR-M6-05` · `BR-M6-04`.
///
/// ⛔★★ **ولا يظهر فيها نوع غير مرتبط بالمصدر** — ★ **ولا نوعٌ معطَّل**،
/// ⛔ **ولا «السكرب»**: وحدتُه كيلوجرام ومدخلُه الجونية لا هذه الشاشة
/// (`FR-M5-03` · `design-overview.md` §2.2).
///
/// ⚠️⚠️ **وهذا تصفيةُ عرضٍ لا حماية** — ★ **والدالة السحابية تُعيد الفحص
/// نفسه على سجل النوع** (`inventory.dart` `_planIntake`).
final intakeItemsProvider =
    Provider.family<List<ItemCard>, String>((Ref ref, String sourceId) {
  final List<ItemCard> all = ref.watch(itemsProvider).value ?? const <ItemCard>[];
  return <ItemCard>[
    for (final ItemCard item in all)
      if (item.isActive &&
          item.unit == ItemUnit.piece &&
          !item.isSystemDefault &&
          item.sourceIds.contains(sourceId))
        item,
  ];
});

/// ★★ الرعية المتاحون للتوريد — ⛔⛔ **بلا ترشيحٍ بالمصدر بعد `CR-006`**.
///
/// ⛔⛔★★★ **و`FR-M3-09` ساقطٌ بذلك الطلب** (2026-08-31) — ★ **الرعوي يتبع
/// كل المصادر الحالية والمستقبلية تلقائياً**، ⟵ **والمرشِّح الوحيد الباقي
/// حالتُه** (`FR-M3-07`: **المعطَّل لا يظهر في شاشات التوريد الجديدة**).
///
/// ⚠️★★ **والعائلة باقيةٌ بمعامل المصدر عمداً** — ⛔ **ولم تُحوَّل إلى مزوّدٍ
/// مفرد:** ★ **الشاشات تستدعيها بمصدرها المختار**، ⟵ **وتغييرُ توقيعها
/// كان يمسّ خمس شاشاتٍ بلا ربحٍ سلوكي**؛ ★ **والمعامل يبقى موضعَ الترشيح
/// إن عاد يوماً بطلبٍ صريح.**
// ignore: avoid_unused_constructor_parameters
final intakeSuppliersProvider =
    Provider.family<List<SupplierCard>, String>((Ref ref, String _) {
  final List<SupplierCard> all =
      ref.watch(suppliersProvider).value ?? const <SupplierCard>[];
  return <SupplierCard>[
    for (final SupplierCard supplier in all)
      if (supplier.isActive) supplier,
  ];
});

// ═════════════════════════════════════════════════════════════════════════
// التسعير اليومي (`WU-005` · `M9`)
// ═════════════════════════════════════════════════════════════════════════

/// دليل التسعير — ⛔ **يُحقَن في الجذر**.
final Provider<DailyPricingDirectory> dailyPricingDirectoryProvider =
    Provider<DailyPricingDirectory>((Ref ref) {
  throw UnimplementedError('dailyPricingDirectoryProvider يجب تجاوزه عند الجذر');
});

/// مستودع كتابة الأسعار — ⛔ **يُحقَن في الجذر**.
final Provider<DailyPricingRepository> dailyPricingRepositoryProvider =
    Provider<DailyPricingRepository>((Ref ref) {
  throw UnimplementedError('dailyPricingRepositoryProvider يجب تجاوزه عند الجذر');
});

/// وسيط قراءة أسعار يومٍ لمصدر — `FR-M9-03`.
///
/// ⚠️ **ونوعٌ مستقل عن [StockQuery] عمداً:** حقلُ التسعير اسمه `date`
/// وحقلُ المخزون `stockDate` — ★ **وهما اليوم نفسه قيمةً**، ⛔ **لكن
/// `coding-standards.md` §2.3 يمنع أن يقبل أحدهما مكان الآخر** (`RISK-07`).
final class PricingQuery {
  /// ينشئ الوسيط.
  const PricingQuery({required this.sourceId, required this.date});

  /// المصدر.
  final String sourceId;

  /// يوم السعر.
  final CalendarDay date;

  @override
  bool operator ==(Object other) =>
      other is PricingQuery &&
      other.sourceId == sourceId &&
      other.date == date;

  @override
  int get hashCode => Object.hash(sourceId, date);
}

/// ⛅ أسعار اليوم للمصدر المطلوب.
///
/// ⛔⛔★★★ **و`isAutoDispose` مقصودٌ — `DEBT-62`:** ★ **شاشةُ التسعير وحدَها
/// تشترك في هذه العائلة مرتين** (**اليوم وأمس**) ⟵ ⛅ **ومقيسٌ على
/// `Pixel_6_API_36` أن اشتراكَ أمس يُوقف رسمَ جسمِ الشاشة عند الدخول الثاني.**
/// ★ **والأثرُ محصورٌ في مفتاح أمس عملياً:** ⟵ **مفتاحُ اليوم يبقى حيّاً على
/// كل حال لأن [pricingRowsProvider] و`suggestedDistributionPricesProvider`
/// يراقبانه وهما دائمان** ⛔ **فلا يسقط بثٌّ يعتمد عليه أحد.**
/// ⛔ **ولا بياناتٍ بائتة:** ★ **ما دام له مستمعٌ فالبثُّ حيٌّ والتحديث فوري**،
/// ⟵ **وعند انقطاع آخر مستمع يُتخلَّص منه فيُعاد الاشتراك نظيفاً عند العودة.**
final dailyPricesProvider =
    StreamProvider.family<List<DailyPriceCard>, PricingQuery>(
  (Ref ref, PricingQuery query) =>
      ref.watch(dailyPricingDirectoryProvider).watchDailyPrices(
            sourceId: query.sourceId,
            date: query.date,
          ),
  isAutoDispose: true,
);

/// فلتر «حالة التسعير» المختار — `FR-M9-05`.
final NotifierProvider<PricingFilter, PricingStatusFilter>
    pricingFilterProvider =
    NotifierProvider<PricingFilter, PricingStatusFilter>(PricingFilter.new);

/// حالة فلتر التسعير.
class PricingFilter extends Notifier<PricingStatusFilter> {
  @override
  PricingStatusFilter build() => PricingStatusFilter.all;

  /// يختار فلتراً.
  void select(PricingStatusFilter filter) => state = filter;
}

/// ★★ صفٌّ في شاشة التسعير — **نوعٌ له كميةُ اليوم، وسعراه إن وُجدا**.
final class PricingRow {
  /// ينشئ الصفّ.
  const PricingRow({
    required this.itemKey,
    required this.itemName,
    required this.unit,
    required this.balance,
    required this.distributionPrice,
    required this.minCashPrice,
  });

  /// مفتاح النوع.
  final String itemKey;

  /// اسمه المعروض.
  final String itemName;

  /// وحدته — ★ **ووحدةُ سعره تتبعها** (`FR-M9-06`).
  final ItemUnit unit;

  /// ★ رصيدُه اليوم — **موجبٌ دائماً في هذه القائمة** (`FR-M9-02`).
  final StockQuantity balance;

  /// سعر التوزيع أو `null`.
  final Money? distributionPrice;

  /// الحد الأدنى أو `null`.
  final Money? minCashPrice;

  /// ★ **تم التسعير؟** — `FR-M9-05`.
  bool get complete => isPricingComplete(
        distributionPrice: distributionPrice,
        minCashPrice: minCashPrice,
      );
}

/// ★★★ صفوف شاشة التسعير — **دمجُ أرصدة اليوم بأسعاره**.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔★★ **والقائمة تبدأ من الرصيد لا من الأسعار ولا من قائمة الأنواع** —
/// `FR-M9-02` (`BR-M9-01`) نصّاً: «**الشاشة تعرض الأنواع التي لها كمية في
/// مخزون اليوم فقط**»، **و`E-33`: النوع الذي لا كمية له لا يظهر ولا يُطالَب
/// بتسعيره**. ⟵ ★ **فالرصيد هو المصدر، والسعر إثراءٌ عليه** — ⛔ **ولو
/// بُنيت من قائمة الأنواع لظهر كل نوعٍ في النظام** وطُولب بتسعيره.
///
/// ★★ **و`FR-M9-12` مُنفَّذ بالبناء لا بشرط:** الاستعلام على **تاريخ اليوم
/// وحده**، ⟵ **فمتبقي الأيام السابقة لا يبلغ هذه الشاشة أصلاً.**
///
/// ⚠️ **والرصيد الصفر ليس كمية** — ★ **ونوعٌ ورد ثم صُرف بالكامل يختفي**،
/// ⛔ **ولا يبقى صفّاً فارغاً يُطالَب بتسعيره** (وهو نفس ما تفرضه السحابة
/// في `_todayStockGate`).
/// ═══════════════════════════════════════════════════════════════════════
final pricingRowsProvider =
    Provider.family<AsyncValue<List<PricingRow>>, PricingQuery>(
        (Ref ref, PricingQuery query) {
  final AsyncValue<List<ItemDailyBalanceCard>> balances = ref.watch(
    todayStockProvider(
      StockQuery(sourceId: query.sourceId, stockDate: query.date),
    ),
  );
  final AsyncValue<List<DailyPriceCard>> prices =
      ref.watch(dailyPricesProvider(query));

  // ⚠️ **والخطأ يُنقَل كما هو ⛔ لا يُطوى في قائمة فارغة** — ⟵ **فيُميِّز
  //    المستخدم بين «لا مخزون اليوم» و«ممنوعٌ من الرؤية»** (`RISK-02`).
  if (balances.hasError) {
    return AsyncValue<List<PricingRow>>.error(
      balances.error!,
      balances.stackTrace ?? StackTrace.empty,
    );
  }
  if (prices.hasError) {
    return AsyncValue<List<PricingRow>>.error(
      prices.error!,
      prices.stackTrace ?? StackTrace.empty,
    );
  }
  final List<ItemDailyBalanceCard>? stock = balances.value;
  final List<DailyPriceCard>? priced = prices.value;
  if (stock == null || priced == null) {
    return const AsyncValue<List<PricingRow>>.loading();
  }

  final Map<String, DailyPriceCard> byItem = <String, DailyPriceCard>{
    for (final DailyPriceCard card in priced) card.itemKey: card,
  };

  return AsyncValue<List<PricingRow>>.data(<PricingRow>[
    for (final ItemDailyBalanceCard card in stock)
      // ⛔ **الصفر والسالب لا يظهران** — راجع ترويسة المزوّد.
      if (card.balance.isPositive)
        PricingRow(
          itemKey: card.itemKey,
          itemName: card.itemName,
          // ★ **وحدة الرصيد هي وحدة النوع** — `GR-19`.
          unit: card.unit,
          balance: card.balance,
          distributionPrice: byItem[card.itemKey]?.distributionPrice,
          minCashPrice: byItem[card.itemKey]?.minCashPrice,
        ),
  ]);
});

/// ★ صفوف التسعير بعد تطبيق الفلتر — `FR-M9-05`.
final filteredPricingRowsProvider =
    Provider.family<AsyncValue<List<PricingRow>>, PricingQuery>(
        (Ref ref, PricingQuery query) {
  final PricingStatusFilter filter = ref.watch(pricingFilterProvider);
  return ref.watch(pricingRowsProvider(query)).whenData(
        (List<PricingRow> rows) => <PricingRow>[
          for (final PricingRow row in rows)
            if (filter.accepts(complete: row.complete)) row,
        ],
      );
});

// ═════════════════════════════════════════════════════════════════════════
// الوارد جواني (`WU-004` · `M7`)
// ═════════════════════════════════════════════════════════════════════════

/// دليل الجواني — ⛔ **يُحقَن في الجذر**.
final Provider<SackDirectory> sackDirectoryProvider =
    Provider<SackDirectory>((Ref ref) {
  throw UnimplementedError('sackDirectoryProvider يجب تجاوزه عند الجذر');
});

/// مستودع كتابة الجواني — ⛔ **يُحقَن في الجذر**.
final Provider<SackAdminRepository> sackAdminProvider =
    Provider<SackAdminRepository>((Ref ref) {
  throw UnimplementedError('sackAdminProvider يجب تجاوزه عند الجذر');
});

/// ⛅ جواني اليوم للمصدر المطلوب.
final sacksProvider = StreamProvider.family<List<SackCard>, StockQuery>(
  (Ref ref, StockQuery query) => ref.watch(sackDirectoryProvider).watchSacks(
        sourceId: query.sourceId,
        stockDate: query.stockDate,
      ),
);

/// 🔒 مالية جونية — ★ **تدفّقٌ مستقل لأن شرط قراءته مستقل** (`ADR-0011`).
///
/// ⚠️ **و`null` تعني «لا مالية بعد **أو** لا صلاحية»** — ⛔ **ولا تُميَّز
/// الحالتان في الشاشة عمداً:** تمييزُهما **يُخبر من لا يملك `sackFinanceView`
/// بوجود بياناتٍ مُنع منها**، ★ **وهو تسريبُ وجودٍ يمنعه `ADR-0011` نفسه.**
final sackFinanceProvider =
    StreamProvider.family<SackFinanceCard?, String>((Ref ref, String sackId) =>
        ref.watch(sackDirectoryProvider).watchSackFinance(sackId: sackId));

/// ★★ الأنواع المتاحة لسطور الجونية من مصدرٍ بعينه — `FR-M7-22`.
///
/// ⚠️⚠️ **ويختلف عن [intakeItemsProvider] في بندٍ واحد جوهري:** ★ **الوزني
/// مسموحٌ هنا** — ⟵ **فجدول وزن الحبة الثلاثي كلُّه عن الأنواع الوزنية**
/// (`FR-M7-13`)، ⛔ **بينما الوارد عدداً «عمليةٌ كمية بحتة»** (`FR-M6-10`).
///
/// ⛔ **و«السكرب» مستثنى هنا كذلك** — ★ **يُولَّد من وزن الرأس** لا يُختار
/// سطراً (`FR-M7-09`).
///
/// ⚠️⚠️ **وهذا تصفيةُ عرضٍ لا حماية** — ★ **والدالة السحابية تُعيد الفحص.**
final sackLineItemsProvider =
    Provider.family<List<ItemCard>, String>((Ref ref, String sourceId) {
  final List<ItemCard> all =
      ref.watch(itemsProvider).value ?? const <ItemCard>[];
  return <ItemCard>[
    for (final ItemCard item in all)
      if (item.isActive &&
          !item.isSystemDefault &&
          item.sourceIds.contains(sourceId))
        item,
  ];
});

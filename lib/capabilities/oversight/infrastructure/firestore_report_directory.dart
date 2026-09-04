/// دليلُ قراءة التقارير — ★★ **قراءةً فقط ولا كتابةَ واحدة** (`ADR-0013`
/// القاعدة 4).
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **وكلُّ استعلامٍ هنا يُقيّد `sourceId` — درسٌ مقيسٌ ثلاث مرات:**
/// شروطُ قراءة هذه المجموعات تعتمد `resource.data`، ⟵ **والسردُ يُقيَّم على
/// قيود الاستعلام لا على كل مستند** ⟹ **`getDocs` بلا قيدٍ على `sourceId`
/// يُرفَض كاملاً — ولو بنطاقٍ شامل** (`IQ-024` · `WU-008` · `DEBT-40`).
///
/// ★★ **و«كل المصادر» يبنيها المزوّد استعلاماً لكل مصدرٍ ثم دمجاً محلياً**
/// (`report_providers.dart`) — ⛔ **ولا استعلامَ واحدٌ عابرٌ للمصادر.**
///
/// ⛔⛔★★★ **ولا تحويلَ يُكتب هنا من جديد:** ★ **كلُّ مُحوِّلٍ يُستدعى من
/// دليلِ وحدتِه نفسِه** (`FirestoreInventoryDirectory.movementOf` …)،
/// ⟵ **ونسخةٌ ثانية منه تفترق عند أول حقلٍ يُضاف** (`coding-standards.md`
/// §2.2) — ★ **وهو حرفياً ثالثُ أوجه `DEBT-37`.**
/// ═══════════════════════════════════════════════════════════════════════
///
/// ⚠️⚠️ **والرفضُ يُطوى حيث يكون «لا أملك رؤيته» حالةً طبيعية** — ★ **أسعارُ
/// التوزيع وحالةُ الإيداع وأرصدةُ المقاوته** (`ت-12` · `ADR-0017` ·
/// `dealerBalanceView`): ⟵ **فالعمودُ لا يُرسَم** ⛔ **ولا تسقط الشاشة**،
/// ★ **وما عداه يصعد خطأً صريحاً** — ⟵ **فيُميِّز المستخدمُ بين «لا بيانات»
/// و«ممنوعٌ من الرؤية»** (`FR-M18-12` — نفسُ مبدأ سجل التدقيق).
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qtms_domain/qtms_domain.dart';

import '../../financial_outflow/infrastructure/firestore_outflow_directory.dart';
import '../../financial_outflow/infrastructure/firestore_owner_ledger_directory.dart';
import '../../inventory/infrastructure/firestore_inventory_directory.dart';
import '../../inventory/infrastructure/firestore_sack_directory.dart';
import '../../inventory/infrastructure/firestore_sack_valuation_directory.dart';
import '../../sales_receivables/infrastructure/firestore_cash_sale_directory.dart';
import '../../sales_receivables/infrastructure/firestore_discount_directory.dart';
import '../../sales_receivables/infrastructure/firestore_distribution_directory.dart';
import '../../sales_receivables/infrastructure/firestore_receipt_directory.dart';
import 'firestore_pending_entries_directory.dart';

/// الدليل الحقيقي.
final class FirestoreReportDirectory implements ReportDirectory {
  /// ينشئ الدليل.
  const FirestoreReportDirectory(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Future<List<StockMovementCard>> itemMovements({
    required String sourceId,
    required String itemKey,
    required ReportPeriod period,
    int limit = reportPageSize,
  }) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _dayRange(
      _firestore
          .collection(inventoryLedgerCollection)
          .where('sourceId', isEqualTo: sourceId)
          .where('itemKey', isEqualTo: itemKey),
      field: 'stockDate',
      period: period,
    ).orderBy('stockDate', descending: true).limit(limit).get();

    return <StockMovementCard>[
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
          in snapshot.docs)
        FirestoreInventoryDirectory.movementOf(doc.id, doc.data()),
    ];
  }

  @override
  Future<List<ItemDailyBalanceCard>> dailyBalances({
    required String sourceId,
    required CalendarDay stockDate,
  }) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection(itemDailyBalancesCollection)
        .where('sourceId', isEqualTo: sourceId)
        .where(
          'stockDate',
          isEqualTo: Timestamp.fromDate(stockDate.asUtcMidnight()),
        )
        // ★ الفهرس القائم: `sourceId ↑ · stockDate ↑ · itemKey ↑`.
        .orderBy('itemKey')
        .get();

    return <ItemDailyBalanceCard>[
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
          in snapshot.docs)
        FirestoreInventoryDirectory.balanceOf(doc.data(), stockDate),
    ];
  }

  @override
  Future<List<CountedIntakeCard>> countedIntakes({
    required String sourceId,
    required ReportPeriod period,
    int limit = reportPageSize,
  }) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _dayRange(
      _firestore
          .collection(incomingCountCollection)
          .where('sourceId', isEqualTo: sourceId),
      field: 'stockDate',
      period: period,
    ).orderBy('stockDate', descending: true).limit(limit).get();

    return <CountedIntakeCard>[
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
          in snapshot.docs)
        FirestoreInventoryDirectory.intakeOf(doc.id, doc.data(), period.to),
    ];
  }

  @override
  Future<List<SackCard>> sacks({
    required String sourceId,
    required ReportPeriod period,
    int limit = reportPageSize,
  }) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _dayRange(
      _firestore
          .collection(sacksCollection)
          .where('sourceId', isEqualTo: sourceId),
      field: 'stockDate',
      period: period,
    ).orderBy('stockDate', descending: true).limit(limit).get();

    return <SackCard>[
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
          in snapshot.docs)
        FirestoreSackDirectory.sackOf(doc.id, doc.data(), period.to),
    ];
  }

  @override
  Future<List<DistributionCard>> distributions({
    required String sourceId,
    required ReportPeriod period,
    SettlementStatus? settlementStatus,
    int limit = reportPageSize,
  }) async {
    Query<Map<String, dynamic>> base = _firestore
        .collection(distributionsCollection)
        .where('sourceId', isEqualTo: sourceId);
    if (settlementStatus case final SettlementStatus status) {
      // ★ الفهرس: `sourceId ↑ · settlementStatus ↑ · stockDate ↓` (`WU-011`).
      base = base.where('settlementStatus', isEqualTo: status.name);
    }
    final QuerySnapshot<Map<String, dynamic>> snapshot =
        await _dayRange(base, field: 'stockDate', period: period)
            .orderBy('stockDate', descending: true)
            .limit(limit)
            .get();

    return <DistributionCard>[
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
          in snapshot.docs)
        FirestoreDistributionDirectory.cardOf(doc.id, doc.data(), period.to),
    ];
  }

  @override
  Future<Map<String, DistributionPricingCard>> distributionPricing({
    required List<String> distributionIds,
  }) async {
    final Map<String, DistributionPricingCard> pricing =
        <String, DistributionPricingCard>{};
    for (final String id in distributionIds) {
      final DistributionPricingCard? card = await _pricingOf(id);
      if (card != null) pricing[id] = card;
    }
    return pricing;
  }

  @override
  Future<List<ReceiptCard>> receipts({
    required String sourceId,
    required ReportPeriod period,
    int limit = reportPageSize,
  }) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _dayRange(
      _firestore
          .collection(receiptsCollection)
          // ★★ **فهرسُ احتواءِ مصفوفة** — `affectedSourceIds ⊃ · date ↓`:
          //    ⟵ **فسندُ «كل المصادر» يظهر في تقرير كلِّ مصدرٍ مسَّه**
          //    (`IQ-002` ③) ⛔ **ولا يسقط من جميعها.**
          .where('affectedSourceIds', arrayContains: sourceId),
      field: 'date',
      period: period,
    ).orderBy('date', descending: true).limit(limit).get();

    return <ReceiptCard>[
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
          in snapshot.docs)
        FirestoreReceiptDirectory.cardOf(doc.id, doc.data()),
    ];
  }

  @override
  Future<Map<String, DepositState>> receiptDeposits({
    required List<String> documentNumbers,
  }) async {
    final Map<String, DepositState> states = <String, DepositState>{};
    for (final String documentNumber in documentNumbers) {
      final DepositState? state = await _depositOf(documentNumber);
      if (state != null) states[documentNumber] = state;
    }
    return states;
  }

  @override
  Future<List<DealerBalanceCard>> dealerBalances({
    required String sourceId,
    int limit = reportPageSize,
  }) async {
    // ⚠️ **وشرطُ `dealer_balances` `perm('dealerBalanceView')` وحدَه** —
    //    ⛔ **ولا يعتمد `resource.data`** (`firestore.rules`)، ⟵ **فقيدُ
    //    `sourceId` هنا للدقة والفهرس** ⛔ **لا لتمرير القاعدة.**
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection(dealerBalancesCollection)
        .where('sourceId', isEqualTo: sourceId)
        .limit(limit)
        .get();

    return <DealerBalanceCard>[
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
          in snapshot.docs)
        FirestoreDistributionDirectory.balanceOf(
          _text(doc.data()['dealerId']) ?? doc.id,
          sourceId,
          doc.data(),
        ),
    ];
  }

  @override
  Future<List<DealerLedgerRowCard>> dealerStatement({
    required String dealerId,
    required String sourceId,
    required ReportPeriod period,
    int limit = reportPageSize,
  }) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _dayRange(
      _firestore
          .collection(dealerLedgerCollection)
          .where('dealerId', isEqualTo: dealerId)
          .where('sourceId', isEqualTo: sourceId),
      field: 'entryDate',
      period: period,
    ).orderBy('entryDate', descending: true).limit(limit).get();

    return <DealerLedgerRowCard>[
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
          in snapshot.docs)
        _ledgerRowOf(doc.id, doc.data()),
    ];
  }

  @override
  Future<List<PendingEntryCard>> pendingEntries({
    required String sourceId,
    required ReportPeriod period,
    int limit = reportPageSize,
  }) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _dayRange(
      _firestore
          .collection(pendingEntriesCollection)
          .where('sourceId', isEqualTo: sourceId),
      field: 'date',
      period: period,
    ).orderBy('date', descending: true).limit(limit).get();

    return <PendingEntryCard>[
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
          in snapshot.docs)
        FirestorePendingEntryDirectory.cardOf(doc.id, doc.data()),
    ];
  }

  // ═════════════════════════════════════════════════════════════════════
  // ★★ زيادةُ `WU-018` — تقاريرُ المرحلة الثانية
  // ═════════════════════════════════════════════════════════════════════

  @override
  Future<List<CashSaleCard>> cashSales({
    required String sourceId,
    required ReportPeriod period,
    int limit = reportPageSize,
  }) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _dayRange(
      _firestore
          .collection(cashSalesCollection)
          .where('sourceId', isEqualTo: sourceId),
      field: 'stockDate',
      period: period,
    ).orderBy('stockDate', descending: true).limit(limit).get();

    return <CashSaleCard>[
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
          in snapshot.docs)
        FirestoreCashSaleDirectory.cardOf(doc.id, doc.data(), period.to),
    ];
  }

  @override
  Future<List<DiscountCard>> discounts({
    required String sourceId,
    required ReportPeriod period,
    int limit = reportPageSize,
  }) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _dayRange(
      _firestore
          .collection(discountsCollection)
          // ★★ **فهرسُ احتواءِ مصفوفة** — `affectedSourceIds ⊃ · date ↓`:
          //    ⟵ **فسندُ «كل المصادر» يظهر في تقرير كلِّ مصدرٍ مسَّه**
          //    ⛔ **ولا يسقط من جميعها** (نظيرُ `R-14` حرفياً).
          .where('affectedSourceIds', arrayContains: sourceId),
      field: 'date',
      period: period,
    ).orderBy('date', descending: true).limit(limit).get();

    return <DiscountCard>[
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
          in snapshot.docs)
        FirestoreDiscountDirectory.cardOf(doc.id, doc.data()),
    ];
  }

  @override
  Future<List<OutflowCard>> outflows({
    required String sourceId,
    required OutflowLedgerType ledgerType,
    required ReportPeriod period,
    int limit = reportPageSize,
  }) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _dayRange(
      _firestore
          .collection(outflowsCollection)
          .where('sourceId', isEqualTo: sourceId)
          // ⛔⛔★★★ **و`ledgerType` مُقيَّدٌ صراحةً** — ★ **شرطُ القراءة
          //    يتفرّع عليه** ([`DEBT-89`]): ⟵ **واستعلامٌ لا يُقيّده يُرفَض
          //    كاملاً ولو ملك القارئُ المفتاحين معاً.**
          .where('ledgerType', isEqualTo: ledgerType.name),
      field: 'documentDate',
      period: period,
    ).orderBy('documentDate', descending: true).limit(limit).get();

    return <OutflowCard>[
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
          in snapshot.docs)
        FirestoreOutflowDirectory.cardOf(doc.id, doc.data()),
    ];
  }

  @override
  Future<List<OwnerLedgerSummary>> dailySummaries({
    required String sourceId,
    required ReportPeriod period,
    int limit = reportPageSize,
  }) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _dayRange(
      _firestore
          .collection(dailySummariesCollection)
          // ⛔⛔★★ **ولا يُقرأ مستندُ `all_{date}` هنا إطلاقاً** — ★ **قيدُ
          //    `sourceId` بمصدرٍ حقيقي يُخرجه من النتيجة أصلاً**: ⟵ **فلا
          //    يُشترَط `allSourcesCardView` ولا تُقرأ أرقامُ مصدرٍ خارج
          //    نطاق القارئ** (`E-36` · `FR-M15-09`).
          .where('sourceId', isEqualTo: sourceId),
      field: 'date',
      period: period,
    ).orderBy('date', descending: true).limit(limit).get();

    return <OwnerLedgerSummary>[
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
          in snapshot.docs)
        if (FirestoreOwnerLedgerDirectory.summaryOf(doc.data())
            case final OwnerLedgerSummary summary)
          summary,
    ];
  }

  @override
  Future<List<SupplierLedgerRow>> supplierLedger({
    required String sourceId,
    required ReportPeriod period,
    int limit = reportPageSize,
  }) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _dayRange(
      _firestore
          .collection(supplierLedgerCollection)
          .where('sourceId', isEqualTo: sourceId),
      // ⚠️⚠️ **والمدى على `entryDate`** — ★ **دفترُ الرعية دفترٌ مالي لا
      //    مخزني ولا `stockDate` في سطره أصلاً** (`schema/supplier-ledger.md`):
      //    ⟵ **وهو نفسُ ما فُعل في `R-19` حرفياً.**
      field: 'entryDate',
      period: period,
    ).orderBy('entryDate', descending: true).limit(limit).get();

    return <SupplierLedgerRow>[
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
          in snapshot.docs)
        FirestoreSackValuationDirectory.rowOf(doc.id, doc.data()),
    ];
  }

  // ═════════════════════════════════════════════════════════════════════
  // القراءاتُ المحكومةُ بشرطٍ مستقل — ⛔ **ورفضُها طيٌّ لا سقوط**
  // ═════════════════════════════════════════════════════════════════════

  /// 🔒 أسعارُ توزيعةٍ — و`null` **عند المنع وعند الغياب معاً**.
  ///
  /// ⚠️ **والتمييز لا يلزم التقرير** — ★ **كلاهما «لا يُعرَض عمود القيمة»**
  /// (`ت-12`)، ⟵ **وطلبُ التمييز كان سيُغري برسالةٍ تكشف وجود مبلغ.**
  Future<DistributionPricingCard?> _pricingOf(String distributionId) async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> doc = await _firestore
          .collection(distributionsCollection)
          .doc(distributionId)
          .collection(distributionPricingSubcollection)
          .doc(distributionPricingDocumentId)
          .get();
      final Map<String, dynamic>? data = doc.data();
      return data == null
          ? null
          : FirestoreDistributionDirectory.pricingOf(data);
    } on Object {
      return null;
    }
  }

  /// 🔒 حالةُ إيداع سندٍ — و`null` **عند المنع وعند الغياب معاً**
  /// (`ADR-0017` · `FR-M12-16`).
  Future<DepositState?> _depositOf(String documentNumber) async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> doc = await _firestore
          .collection(receiptsCollection)
          .doc(documentNumber)
          .collection(receiptDepositSubcollection)
          .doc(receiptDepositDocumentId)
          .get();
      final Map<String, dynamic>? data = doc.data();
      return data == null
          ? null
          : FirestoreReceiptDirectory.depositOf(data).state;
    } on Object {
      return null;
    }
  }

  // ═════════════════════════════════════════════════════════════════════
  // المدى الزمني — ★ **حدَّان شاملان على الحقل المرتَّب به نفسِه**
  // ═════════════════════════════════════════════════════════════════════

  /// ★★ يضيف حدَّي الفترة — ⛔ **والنهاية شاملةٌ ليومها كلِّه**.
  ///
  /// ⚠️⚠️ **وحدٌّ أعلى بمنتصف ليل يوم النهاية كان سيُسقِط ذلك اليوم كاملاً**
  /// — ★ **وهو خطأٌ صامت يبدو «لا بيانات»** (نفسُ ما عولج في
  /// `FirestoreAuditLogDirectory`).
  ///
  /// ★ **والحدُّ الأعلى `< منتصف ليل اليوم التالي`** — ⟵ **فيشمل طوابعَ
  /// اليوم كلِّها**، ⛔ **ويشمل `stockDate` المخزَّن منتصفَ ليلٍ كذلك.**
  static Query<Map<String, dynamic>> _dayRange(
    Query<Map<String, dynamic>> query, {
    required String field,
    required ReportPeriod period,
  }) =>
      query
          .where(
            field,
            isGreaterThanOrEqualTo:
                Timestamp.fromDate(period.from.asUtcMidnight()),
          )
          .where(
            field,
            isLessThan: Timestamp.fromDate(
              period.to.asUtcMidnight().add(const Duration(days: 1)),
            ),
          );

  // ═════════════════════════════════════════════════════════════════════
  // التحويل — ★ **ولا نظيرَ له في دليلٍ آخر** (دفترُ المقاوته يُقرأ هنا فقط)
  // ═════════════════════════════════════════════════════════════════════

  /// ★★ يبني صفَّ دفتر المقاوته من قيدٍ **كُتب فعلاً** — ⛔ **بلا رمي**.
  ///
  /// ⚠️⚠️ **والتسامح مقصود:** ★ **الدفترُ للإضافة فقط ولا يُهاجَر**،
  /// ⟵ **وقيدٌ كتبه إصدارٌ لاحق قد يحمل نوعاً لا يعرفه هذا الإصدار** —
  /// ★ **فيُعرَض «قيد غير معروف» بمبلغه وتاريخه** ⛔ **بدل أن يُسقِط كشفَ
  /// حسابٍ كاملاً** (`RISK-05` — نفسُ منطق سجل التدقيق).
  static DealerLedgerRowCard _ledgerRowOf(
    String id,
    Map<String, dynamic> data,
  ) =>
      DealerLedgerRowCard(
        entryId: id,
        dealerId: _text(data['dealerId']) ?? '',
        sourceId: _text(data['sourceId']) ?? '',
        // ⛔ **والاتجاهُ الوحيدُ الذي يُقرأ بافتراض** — ★ **وهو ثنائيٌّ
        //    مغلق**: ⟵ **و«دائن» الافتراضيةُ لا تُنشئ مطالبةً على أحد.**
        direction: data['direction'] == DealerLedgerDirection.debit.name
            ? DealerLedgerDirection.debit
            : DealerLedgerDirection.credit,
        entryType: _entryTypeOf(data['entryType']),
        amount: Money(_int(data['amount']) ?? 0),
        // ⛔⛔★★ **ولا يُقرأ `balanceAfter` المخزَّن** (`DEBT-75`) — ★ **كاتبُ
        //    القبض لا يكتبه أصلاً**، ⟵ **والرصيدُ الجاري يُشتقّ في البناء**
        //    (`ADR-0008`: **الرصيد مشتقٌّ من الدفتر دائماً**).
        isCancelled: data['isCancelled'] == true,
        entryDate: _instant(data['entryDate']),
        debtLotId: _text(data['debtLotId']),
        sourceDocNumber: _text(data['sourceDocNumber']),
        memo: _text(data['memo']),
        // ★★ **وأثرُ التعديل يُقرأ من الدفتر** — `FR-M17-05` (`WU-017`):
        //    ⟵ **فالحركةُ تُعدَّل في مكانها ولا يظهر لها سطرٌ مضاد** (`A-14`)،
        //    ⛔ **وبلا هذين الحقلين لا أثرَ في الكشف يدلّ المقوتَ عليها.**
        lastAmendedAt: _instant(data['lastAmendedAt']),
        amendedBy: _text(data['amendedBy']),
      );

  /// ★ نوعُ القيد — ⛔ **والمجهول `null` لا افتراضٌ صامت**.
  static DealerLedgerEntryType? _entryTypeOf(Object? raw) {
    for (final DealerLedgerEntryType type in DealerLedgerEntryType.values) {
      if (type.name == raw) return type;
    }
    return null;
  }

  static int? _int(Object? raw) => switch (raw) {
        final int value => value,
        final num value => value.toInt(),
        _ => null,
      };

  static DateTime? _instant(Object? raw) => switch (raw) {
        final Timestamp value => value.toDate().toUtc(),
        final DateTime value => value.toUtc(),
        _ => null,
      };

  static String? _text(Object? raw) {
    if (raw is! String) return null;
    final String trimmed = raw.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

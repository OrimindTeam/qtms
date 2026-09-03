/// دليل حركة النقد في تاريخ — **قراءةً فقط** (`ADR-0013` القاعدة 4).
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **ولماذا يُجمَع عند القراءة ولا يُبنى ملخّصاً مسبقاً:**
/// ★ **`daily_summaries` مُعرَّفٌ بالبنود العشرة وحدها** (`schema/
/// daily-summaries.md`) — ⛔ **ولا حقلَ فيه لحركة النقد**، ⟵ **وإضافةُ
/// حقولٍ إليه اختراعُ مخطَّطٍ لا يُقرّه مستند.** ★ **وتبريرُ البناء المسبق
/// في §8 نصُّه «البطاقة تُفتَح عشرات المرات يومياً»** — ⟵ **وهذه شاشةٌ
/// تُفتَح عند الطلب**، ★ **فالتجميعُ هنا اتساقٌ مع `ADR-0008`** ⛔ **لا
/// مخالفةٌ لقيد الأداء.**
///
/// ⚠️⚠️★★★ **وثلاثةُ تواريخَ مختلفةٍ في شاشةٍ واحدة — وهو أخطر ما فيها:**
///   ① **سندُ القبض بتاريخه** (`date`) — `GR-41`: ⛔ **لا بتاريخ الضمار.**
///   ② **البيعُ النقدي بتاريخ إدخاله** (`entryDate`) — `FR-M15-16` نصّاً:
///      «**المُدخلة في التاريخ … ومنها ما يخص مخزون أيام سابقة**»،
///      ⛔ **لا بـ`stockDate`**: ⟵ **وهو عكسُ ما تفعله بطاقةُ الضمار
///      بالضبط** (`schema/cash-sales.md` القاعدة 8).
///   ③ **السحبياتُ والخرجيات بتاريخ السند** (`documentDate`) — `GR-49`.
/// ⛔ **وخلطُ أيٍّ منها بالآخر يُنتج رقمَ صندوقٍ كاذباً.**
/// ═══════════════════════════════════════════════════════════════════════
///
/// ⛔⛔★★ **والفائضُ العام لا يُنسَب لمصدر** — `FR-M12-12`: ★ **`sourceId`
/// فيه `null` عمداً** (وهو نصُّ قاعدة `dealer_surplus` في `firestore.rules`)،
/// ⟵ **فيظهر في «كل المصادر» وحدها**، ⛔ **ونسبتُه لمصدرٍ مُخمَّن تُضخِّم
/// صندوقَه بمالٍ لا يخصّه.**
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qtms_domain/qtms_domain.dart';

/// الدليل الحقيقي.
final class FirestoreCashMovementDirectory implements CashMovementReader {
  /// ينشئ الدليل.
  const FirestoreCashMovementDirectory(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Future<CashMovementSummary> readCashMovement({
    required List<String> sourceIds,
    required bool includesUnscopedSurplus,
    required CalendarDay date,
    required bool readsDeposit,
  }) async {
    Money sameDay = Money.zero;
    Money previousDays = Money.zero;
    Money surplus = Money.zero;
    Money deposited = Money.zero;
    Money cashSales = Money.zero;
    Money withdrawals = Money.zero;
    Money expenses = Money.zero;
    Money discounts = Money.zero;

    for (final String sourceId in sourceIds) {
      final _Received received = await _readReceipts(
        sourceId: sourceId,
        date: date,
        includeGeneralSurplus: includesUnscopedSurplus,
        readsDeposit: readsDeposit,
      );
      sameDay = sameDay + received.sameDay;
      previousDays = previousDays + received.previousDays;
      surplus = surplus + received.surplus;
      deposited = deposited + received.deposited;
      cashSales = cashSales + await _readCashSales(sourceId, date);
      final _Outflows outflows = await _readOutflows(sourceId, date);
      withdrawals = withdrawals + outflows.withdrawals;
      expenses = expenses + outflows.expenses;
      discounts = discounts + await _readDiscounts(sourceId, date);
    }

    return computeCashMovement(
      date: date,
      contributions: CashMovementContributions(
        receivedForSameDayDebt: sameDay,
        receivedForPreviousDays: previousDays,
        receivedAsSurplus: surplus,
        cashSales: cashSales,
        withdrawals: withdrawals,
        expenses: expenses,
        discounts: discounts,
        deposited: deposited,
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════
  // ① المقبوض — بتاريخ السند (`GR-41`)
  // ═════════════════════════════════════════════════════════════════════

  Future<_Received> _readReceipts({
    required String sourceId,
    required CalendarDay date,
    required bool includeGeneralSurplus,
    required bool readsDeposit,
  }) async {
    final QuerySnapshot<Map<String, dynamic>> rows = await _firestore
        .collection(receiptsCollection)
        // ★ **والفهرس `affectedSourceIds CONTAINS · date ↓` قائمٌ لهذا.**
        .where('affectedSourceIds', arrayContains: sourceId)
        .where('date', isEqualTo: Timestamp.fromDate(date.asUtcMidnight()))
        .get();

    Money sameDay = Money.zero;
    Money previousDays = Money.zero;
    Money surplus = Money.zero;
    Money deposited = Money.zero;

    for (final QueryDocumentSnapshot<Map<String, dynamic>> row in rows.docs) {
      final Map<String, dynamic> data = row.data();
      if (data['status'] == 'cancelled') continue;

      Money receiptForSource = Money.zero;
      for (final Object? entry in (data['lines'] as List<dynamic>?) ?? const <Object?>[]) {
        if (entry is! Map<String, dynamic>) continue;
        if (entry['sourceId'] != sourceId) continue;
        final Money amount = _money(entry['amount']);
        receiptForSource = receiptForSource + amount;
        // ★★★ **ويومُ الضمار من معرّفه المركّب** — `{dealerId}_{sourceId}_{date}`
        //    ([distributionId]): ⟵ **فلا قراءةَ ثانية لكل سطر**، ⛔ **ولا
        //    يُخمَّن اليومُ من تاريخ السند** (`AT-49`: **الواصل ≠ المقبوض**).
        final CalendarDay? lotDay = _lotDayOf(entry['debtLotId']);
        if (lotDay == date) {
          sameDay = sameDay + amount;
        } else {
          previousDays = previousDays + amount;
        }
      }

      // ⛔⛔ **والفائضُ العام في «كل المصادر» وحدها** — راجع ترويسة الملف.
      final Money receiptSurplus = _money(data['surplusAmount']);
      if (!receiptSurplus.isZero) {
        final bool isSourceScoped =
            data['surplusScope'] == SurplusScope.source.name;
        if (isSourceScoped && data['sourceFilter'] == sourceId) {
          surplus = surplus + receiptSurplus;
        } else if (!isSourceScoped && includeGeneralSurplus) {
          surplus = surplus + receiptSurplus;
        }
      }

      if (readsDeposit && !receiptForSource.isZero) {
        final DocumentSnapshot<Map<String, dynamic>> state = await _firestore
            .collection(receiptsCollection)
            .doc(row.id)
            .collection(receiptDepositSubcollection)
            .doc(receiptDepositDocumentId)
            .get();
        // ★ **والغيابُ «لم يُودَع»** — ⛔ **لا مجهولٌ يُسقِط الشاشة.**
        if (state.data()?['isDeposited'] == true) {
          deposited = deposited + receiptForSource;
        }
      }
    }

    return _Received(
      sameDay: sameDay,
      previousDays: previousDays,
      surplus: surplus,
      deposited: deposited,
    );
  }

  // ═════════════════════════════════════════════════════════════════════
  // ② البيع النقدي — **بتاريخ الإدخال** (`FR-M15-16`)
  // ═════════════════════════════════════════════════════════════════════

  Future<Money> _readCashSales(String sourceId, CalendarDay date) async {
    final QuerySnapshot<Map<String, dynamic>> rows = await _firestore
        .collection(cashSalesCollection)
        .where('sourceId', isEqualTo: sourceId)
        // ★★ **مدىً على طابع الخادم** — ⟵ **فـ`entryDate` لحظةٌ لا يوم**،
        //   ★ **والفهرس `sourceId ↑ · entryDate ↑` قائمٌ لهذا.**
        .where(
          'entryDate',
          isGreaterThanOrEqualTo: Timestamp.fromDate(date.asUtcMidnight()),
          isLessThan: Timestamp.fromDate(
            date.asUtcMidnight().add(const Duration(days: 1)),
          ),
        )
        .get();
    Money total = Money.zero;
    for (final QueryDocumentSnapshot<Map<String, dynamic>> row in rows.docs) {
      if (row.data()['status'] == 'cancelled') continue;
      total = total + _money(row.data()['netCashReceived']);
    }
    return total;
  }

  // ═════════════════════════════════════════════════════════════════════
  // ③ الخارج — **بتاريخ السند** (`GR-49` · `GR-47`)
  // ═════════════════════════════════════════════════════════════════════

  Future<_Outflows> _readOutflows(String sourceId, CalendarDay date) async {
    Money withdrawals = Money.zero;
    Money expenses = Money.zero;
    // ⛔⛔★★★ **واستعلامان لا واحد** — ★ **شرطُ قراءة `outflows` يعتمد
    //    `resource.data.ledgerType`** ([`DEBT-89`]): ⟵ **واستعلامٌ لا
    //    يُقيّده يُرفَض كاملاً ولو ملك القارئُ المفتاحين معاً.**
    for (final OutflowLedgerType type in OutflowLedgerType.values) {
      final QuerySnapshot<Map<String, dynamic>> rows;
      try {
        rows = await _firestore
            .collection(outflowsCollection)
            .where('sourceId', isEqualTo: sourceId)
            .where('ledgerType', isEqualTo: type.name)
            .where(
              'documentDate',
              isEqualTo: Timestamp.fromDate(date.asUtcMidnight()),
            )
            .get();
      } on FirebaseException catch (_) {
        // ⛔⛔★★ **ورفضُ الصلاحية ليس خطأً هنا** — `E-29`: ★ **من لا يملك
        //    «عرض السحبيات» لا يرى بندَها**، ⟵ **والشاشةُ تُخفيه**
        //    ⛔ **ولا تسقط**. ★ **وهو نفسُ سلوك البطاقة تماماً** (§5).
        continue;
      }
      Money total = Money.zero;
      for (final QueryDocumentSnapshot<Map<String, dynamic>> row in rows.docs) {
        if (row.data()['status'] == 'cancelled') continue;
        total = total + _money(row.data()['grandTotal']);
      }
      if (type == OutflowLedgerType.withdrawal) {
        withdrawals = total;
      } else {
        expenses = total;
      }
    }
    return _Outflows(withdrawals: withdrawals, expenses: expenses);
  }

  // ═════════════════════════════════════════════════════════════════════
  // ④ الخصومات — **للعلم ولا تُطرح** (`FR-M15-20`)
  // ═════════════════════════════════════════════════════════════════════

  Future<Money> _readDiscounts(String sourceId, CalendarDay date) async {
    final QuerySnapshot<Map<String, dynamic>> rows = await _firestore
        .collection(discountsCollection)
        .where('affectedSourceIds', arrayContains: sourceId)
        .where('date', isEqualTo: Timestamp.fromDate(date.asUtcMidnight()))
        .get();
    Money total = Money.zero;
    for (final QueryDocumentSnapshot<Map<String, dynamic>> row in rows.docs) {
      final Map<String, dynamic> data = row.data();
      if (data['status'] == 'cancelled') continue;
      for (final Object? entry
          in (data['lines'] as List<dynamic>?) ?? const <Object?>[]) {
        if (entry is! Map<String, dynamic>) continue;
        if (entry['sourceId'] != sourceId) continue;
        total = total + _money(entry['amount']);
      }
    }
    return total;
  }

  // ═════════════════════════════════════════════════════════════════════
  // القراءة الآمنة
  // ═════════════════════════════════════════════════════════════════════

  /// ★★ يومُ الضمار من معرّفه المركّب — `{dealerId}_{sourceId}_{YYYYMMDD}`.
  ///
  /// ⛔ **و`null` لمعرّفٍ لا يطابق الشكل** — ⟵ **فيُحتسَب «لأيامٍ سابقة»**:
  /// ★ **الافتراضُ الآمن** ⛔ **إذ نسبتُه لليوم تُضخِّم «واصلَ» اليوم زوراً.**
  static CalendarDay? _lotDayOf(Object? raw) {
    if (raw is! String) return null;
    final int cut = raw.lastIndexOf('_');
    if (cut < 0) return null;
    return CalendarDay.tryParseCompact(raw.substring(cut + 1));
  }

  static Money _money(Object? raw) => switch (raw) {
        final int value => Money(value),
        final double value when value == value.roundToDouble() =>
          Money(value.toInt()),
        _ => Money.zero,
      };
}

final class _Received {
  const _Received({
    required this.sameDay,
    required this.previousDays,
    required this.surplus,
    required this.deposited,
  });

  final Money sameDay;
  final Money previousDays;
  final Money surplus;
  final Money deposited;
}

final class _Outflows {
  const _Outflows({required this.withdrawals, required this.expenses});

  final Money withdrawals;
  final Money expenses;
}

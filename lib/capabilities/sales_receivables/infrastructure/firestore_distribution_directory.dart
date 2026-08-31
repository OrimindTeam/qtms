/// دليل التوزيع — **قراءةً فقط** (`ADR-0013` القاعدة 4).
///
/// ⛔★★ **ولا كتابة واحدة هنا:** `distributions` و`pricing/current` **كلاهما
/// `allow create, update: if false`** — **والكتابة عبر العمليات المستدعاة**
/// (`functions_distribution_repository.dart`).
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **وتدفّقان لا واحد — وهذا جوهر `ADR-0011` في هذه الوحدة:**
///
///   `watchDistributions`                       ← **الأب**: يقرؤه كل مصادَق
///                                                  في نطاقه.
///   `watchDistributionPricing`                 ← 🔒 **الأسعار**: بـ
///                                                  `distributionPriceView`.
///
/// ⟵ **ودمجُهما في قراءةٍ واحدة كان سيجعل `ت-12` إخفاءَ واجهة لا حماية**:
/// ★ **الرفض يأتي من القاعدة نفسها** فيسقط تدفّقُ الأسعار وحده، ⛔ **ولا
/// يُسقِط الشاشة كلها.**
/// ═══════════════════════════════════════════════════════════════════════
///
/// ⚠️⚠️ **ورفضُ الأسعار يُطوى إلى `null` عمداً** — ★ **لأن «لا أرى السعر»
/// حالةٌ طبيعية لا عطل** (`FR-M10-07`)، ⟵ **وعرضُ رسالة خطأٍ عليها كان
/// سيكشف وجود مبلغٍ لمن لا يملك رؤيته.**
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qtms_domain/qtms_domain.dart';

/// الدليل الحقيقي.
final class FirestoreDistributionDirectory implements DistributionDirectory {
  /// ينشئ الدليل.
  const FirestoreDistributionDirectory(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Stream<List<DistributionCard>> watchDistributions({
    required String sourceId,
    required CalendarDay stockDate,
  }) =>
      _firestore
          .collection(distributionsCollection)
          .where('sourceId', isEqualTo: sourceId)
          // ★★ **يومٌ واحد** — ⛔ **ولا يُجمع يومان** (`RISK-07`).
          //    ★ **والفهرس المعتمد `sourceId ↑ · stockDate ↓`.**
          .where(
            'stockDate',
            isEqualTo: Timestamp.fromDate(stockDate.asUtcMidnight()),
          )
          .snapshots()
          .map((QuerySnapshot<Map<String, dynamic>> snapshot) {
            final List<DistributionCard> cards = <DistributionCard>[
              for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
                  in snapshot.docs)
                cardOf(doc.id, doc.data(), stockDate),
            ];
            // ★ **مرتَّبةً باسم المقوت** — ⟵ **فترتيب الشاشة ثابت**،
            //   ⛔ **ولا يقفز صفٌّ بتعديل كميته.**
            cards.sort(
              (DistributionCard a, DistributionCard b) =>
                  a.dealerName.compareTo(b.dealerName),
            );
            return cards;
          });

  @override
  Stream<DistributionPricingCard?> watchDistributionPricing({
    required String distributionId,
  }) =>
      _firestore
          .collection(distributionsCollection)
          .doc(distributionId)
          .collection(distributionPricingSubcollection)
          .doc(distributionPricingDocumentId)
          .snapshots()
          .map((DocumentSnapshot<Map<String, dynamic>> doc) {
            final Map<String, dynamic>? data = doc.data();
            return data == null ? null : pricingOf(data);
          })
          // ⛔⛔★★ **والرفض يُطوى إلى `null` عمداً** — راجع ترويسة الملف:
          //    ★ **«لا أرى السعر» حالةٌ طبيعية لا عطل** (`ت-12`).
          .handleError((Object _) {})
          .cast<DistributionPricingCard?>();

  @override
  Stream<DealerBalanceCard?> watchDealerBalance({
    required String dealerId,
    required String sourceId,
  }) =>
      _firestore
          .collection(dealerBalancesCollection)
          // ★ **المعرّف المركّب `{dealerId}_{sourceId}`** — ⛔ **ولا يُبنى
          //   هنا نصّاً**: ★ **موضعُ بنائه واحدٌ في طبقة النطاق.**
          .doc(dealerBalanceId(dealerId: dealerId, sourceId: sourceId))
          .snapshots()
          .map((DocumentSnapshot<Map<String, dynamic>> doc) {
            final Map<String, dynamic>? data = doc.data();
            return data == null ? null : balanceOf(dealerId, sourceId, data);
          })
          // ⛔⛔★★ **والرفض يُطوى إلى `null` عمداً** — ★ **«لا أرى الرصيد»
          //    حالةٌ طبيعية لمن لا يملك `dealerBalanceView`** (نفس منطق
          //    الأسعار أعلاه)، ⟵ **ولا تسقط الشاشة لأجلها.**
          .handleError((Object _) {})
          .cast<DealerBalanceCard?>();

  /// ★ يفكّ بطاقة الرصيد — ⛔ **والغائب صفرٌ لا خطأ**.
  ///
  /// ⚠️ **و`openDebtCount` و`oldestOpenDebtDate` لا يكتبهما `WU-006`** —
  /// ★ **فيُقرآن صفراً وغياباً** (`distribution.dart` — قناعُ الكتابة الضيّق)،
  /// ⛔ **ولا يُخترَع لهما حساب هنا** (`ADR-0008`).
  /// ★★ ومكشوفٌ لأن `FirestoreReportDirectory` يقرأ المجموعةَ نفسَها
  /// (`R-17` — `WU-011`) — ⛔ **ونسخةٌ ثانية تفترق عند أول حقل.**
  static DealerBalanceCard balanceOf(
    String dealerId,
    String sourceId,
    Map<String, dynamic> data,
  ) =>
      DealerBalanceCard(
        dealerId: dealerId,
        sourceId: sourceId,
        // ★ **والحقل الغائب صفرٌ لا خطأ** — ⛔ **ولا `as int` عارية** (`DEBT-24`).
        balance: DealerAccountBalance(
          totalDebit: Money(_int(data['totalDebit']) ?? 0),
          totalCredit: Money(_int(data['totalCredit']) ?? 0),
          balance: Money(_int(data['balance']) ?? 0),
        ),
        openDebtCount: _int(data['openDebtCount']) ?? 0,
      );


  // ═════════════════════════════════════════════════════════════════════
  // التحويل — ⛔ **والمجهول يُقرأ بالافتراض الآمن لا يُسقِط الشاشة**
  // ═════════════════════════════════════════════════════════════════════

  /// ★ يحوّل مستند توزيعةٍ خاماً إلى بطاقتها.
  ///
  /// ★★ **ومكشوفٌ لأن `FirestoreReportDirectory` يقرأ المجموعةَ نفسَها**
  /// (`R-08` · `R-10` — `WU-011`): ⟵ **ونسخةٌ ثانية من التحويل تفترق عن
  /// هذه عند أول حقلٍ يُضاف** ⛔ **وهو ما يمنعه `coding-standards.md` §2.2.**
  static DistributionCard cardOf(
    String id,
    Map<String, dynamic> data,
    CalendarDay? fallbackDay,
  ) {
    final List<ValidatedDistributionLine> lines = _linesOf(data['lines']);
    return DistributionCard(
      distributionId: id,
      documentNumber: _text(data['documentNumber']) ?? id,
      sourceId: _text(data['sourceId']) ?? '',
      sourceName: _text(data['sourceName']),
      dealerId: _text(data['dealerId']) ?? '',
      dealerName: _text(data['dealerName']) ?? _text(data['dealerId']) ?? '',
      stockDate: _dayOf(data['stockDate']) ??
          fallbackDay ??
          CalendarDay.fromUtc(DateTime.now().toUtc()),
      entryDate: _instant(data['entryDate']) ?? DateTime.utc(1970),
      status: _statusOf(data['status']),
      unpricedLineCount: _int(data['unpricedLineCount']) ??
          lines
              .where((ValidatedDistributionLine l) => !l.isPriced)
              .length,
      totalPieces: PieceCount(_int(data['totalPieces']) ?? 0),
      totalWeight: WeightKg(_double(data['totalWeight'])),
      lines: lines,
      notes: _text(data['notes']),
      cancelReason: _text(data['cancelReason']),
      amendCount: _int(data['amendCount']) ?? 0,
      // ★★ **حالةُ التسوية تُقرأ ولا تُفترَض** (`R-10` — `WU-011`):
      //    ⛔ **والمجهولُ `null` لا `open`** — ★ **فضمارٌ مُصفّى يُعرَض
      //    مفتوحاً يُطالِب مقوتاً بما سدَّده** (نفس منطق `AuditAction`).
      settlementStatus: _settlementOf(data['settlementStatus']),
    );
  }

  /// ★ حالةُ التسوية المقروءة — ⛔ **والمجهول `null` لا افتراضٌ صامت**.
  static SettlementStatus? _settlementOf(Object? raw) {
    for (final SettlementStatus status in SettlementStatus.values) {
      if (status.name == raw) return status;
    }
    return null;
  }

  /// ★ سطور المستند — ⛔ **بلا سعرٍ فيها** (`ADR-0011`).
  ///
  /// ⚠️⚠️ **والوحدة تُقرأ من السطر لا تُفترَض** — ★ **فسطرُ السكرب يُقرأ
  /// وزناً**، ⛔ **وقراءتُه حبّاتٍ كانت تُظهر «1 حبة» لِ`1.234 كجم`.**
  static List<ValidatedDistributionLine> _linesOf(Object? raw) {
    if (raw is! List<Object?>) return const <ValidatedDistributionLine>[];
    return <ValidatedDistributionLine>[
      for (final Object? entry in raw)
        if (entry is Map<String, dynamic>)
          ValidatedDistributionLine(
            itemId: _text(entry['itemId']) ?? _text(entry['itemKey']) ?? '',
            itemName: _text(entry['itemName']) ?? '',
            quantity: _quantityOf(entry['unit'], entry['quantity']),
            sackId: _text(entry['sackId']),
            // ⛔★★ **ولا سعرٌ في المستند الأب إطلاقاً** — `ADR-0011`.
            unitPrice: null,
            note: _text(entry['note']),
          ),
    ];
  }

  static StockQuantity _quantityOf(Object? unit, Object? quantity) =>
      unit == ItemUnit.kilogram.name
          ? WeightQuantity(WeightKg(_double(quantity)))
          : PieceQuantity(PieceCount(_int(quantity) ?? 0));

  /// 🔒 يحوّل مستند أسعارِ توزيعةٍ — ⛔ **ولا يصل إلا من يملك
  /// `distributionPriceView`** (`ADR-0011` · `ت-12`).
  ///
  /// ★★ **ومكشوفٌ لعمود القيمة في `R-10`** (`WU-011`).
  static DistributionPricingCard pricingOf(Map<String, dynamic> data) {
    final List<Money?> unitPrices = _moneyList(data['unitPrices']);
    return DistributionPricingCard(
      sourceId: _text(data['sourceId']) ?? '',
      debtValue: Money(_int(data['debtValue']) ?? 0),
      unitPrices: unitPrices,
      lineTotals: _moneyList(data['lineTotals']),
    );
  }

  /// ★ قائمة مبالغ — ⛔ **والكسر يُقرأ غياباً لا يُقرَّب** (`ADR-0015` ③).
  static List<Money?> _moneyList(Object? raw) {
    if (raw is! List<Object?>) return const <Money?>[];
    return <Money?>[
      for (final Object? value in raw)
        if (_int(value) case final int riyals) Money(riyals) else null,
    ];
  }

  static DistributionStatus _statusOf(Object? raw) {
    for (final DistributionStatus status in DistributionStatus.values) {
      if (status.name == raw) return status;
    }
    // ⛔ **والمجهول «معتمد»** — ★ **الافتراض الآمن هنا «مستندٌ حيّ»**:
    //   ⟵ **قراءتُه ملغىً كانت تُخفيه من الشاشة وهو قائم.**
    return DistributionStatus.approved;
  }

  static int? _int(Object? raw) => switch (raw) {
        final int value => value,
        final double value when value == value.roundToDouble() => value.toInt(),
        _ => null,
      };

  static double _double(Object? raw) => switch (raw) {
        final num value => value.toDouble(),
        _ => 0,
      };

  static CalendarDay? _dayOf(Object? raw) {
    final DateTime? instant = _instant(raw);
    return instant == null ? null : CalendarDay.fromUtc(instant);
  }

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

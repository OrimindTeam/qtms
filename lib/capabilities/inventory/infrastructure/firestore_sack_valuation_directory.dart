/// دليل مالية الجواني وحساب الرعوي — **قراءةً فقط** (`ADR-0013` القاعدة 4).
///
/// ⛔★★ **ولا كتابة واحدة هنا:** `supplier_ledger` و`supplier_balances`
/// **`allow write: if false`** — ★ **ويكتبهما المُحتسِب السحابي حصراً**
/// (`schema/supplier-ledger.md` القاعدة 5).
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **وكلُّ استعلامِ سردٍ هنا يُقيّد `sourceId` صراحةً** — ★ **شرطُ
/// القراءة يعتمد `resource.data`** (`IQ-024` · `WU-008` · `DEBT-40`):
/// ⟵ **والشرط يُقيَّم على قيود الاستعلام لا على كل مستند**، ⛔ **فاستعلامٌ
/// لا يُقيّده يُرفَض كاملاً ولو بنطاقٍ شامل.**
///
/// ⚠️⚠️ **وتفكيكُ السعر يُبنى بنفس دالة النطاق التي تبني المخزَّن**
/// (`contributionsForSack` · `computeSackRevenue`) — ⟵ **فرقمُ الشاشة رقمُ
/// السحابة حرفياً** (`ADR-0012` · `coding-standards.md` §2.2).
///
/// ⛔⛔ **ورفضُ قراءة أسعار التوزيعة يُقرأ «قيمةً لا يراها هذا المستخدم»**
/// — ★ **`distributionPriceView` شرطُ قراءةٍ مستقل** (`ADR-0011` · `ت-12`):
/// ⟵ **فالسطر يظهر بلا قيمته**، ⛔ **ولا يُطوى في صفرٍ يُنقِص المجموع**
/// — ★ **والإجمالي المعروض من `finance/current` لا من هذا الجمع.**
/// ═══════════════════════════════════════════════════════════════════════
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qtms_domain/qtms_domain.dart';

/// الدليل الحقيقي.
final class FirestoreSackValuationDirectory implements SackValuationDirectory {
  /// ينشئ الدليل.
  const FirestoreSackValuationDirectory(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Stream<SupplierBalanceCard?> watchSupplierBalance({
    required String supplierId,
    required String sourceId,
  }) =>
      _firestore
          .collection(supplierBalancesCollection)
          .doc(supplierBalanceId(supplierId: supplierId, sourceId: sourceId))
          .snapshots()
          .map(
            (DocumentSnapshot<Map<String, dynamic>> doc) => doc.exists
                ? _balanceOf(supplierId, sourceId, doc.data())
                : null,
          )
          // ⚠️ **ورفضُ القراءة يُطوى في `null`** — ★ **بنفس علّة
          //    `watchSackFinance`**: ⟵ **من لا يملك `supplierFinanceView`
          //    لا يُفترَض به أن يرى شيئاً**، ⛔ **ورسالةُ فشلٍ كانت تُخبره
          //    بوجود بياناتٍ مُنع منها.**
          .handleError(
            (Object _) {},
            test: (dynamic error) => error is FirebaseException,
          );

  @override
  Stream<List<SupplierLedgerRow>> watchSupplierLedger({
    required String supplierId,
    required String sourceId,
  }) =>
      _firestore
          .collection(supplierLedgerCollection)
          .where('supplierId', isEqualTo: supplierId)
          // ⛔⛔ **والمصدر مُقيَّدٌ صراحةً** — راجع ترويسة الملف.
          .where('sourceId', isEqualTo: sourceId)
          .snapshots()
          .map(
            (QuerySnapshot<Map<String, dynamic>> snapshot) => <SupplierLedgerRow>[
              for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
                  in snapshot.docs)
                rowOf(doc.id, doc.data()),
            ]..sort(
                (SupplierLedgerRow a, SupplierLedgerRow b) =>
                    b.sackId.compareTo(a.sackId),
              ),
          )
          .handleError(
            (Object _) {},
            test: (dynamic error) => error is FirebaseException,
          );

  @override
  Future<Outcome<List<SackRevenueContribution>>> loadSackContributions({
    required String sackId,
    required String sourceId,
    required CalendarDay stockDate,
  }) async {
    try {
      final List<SackMovementDocument> documents =
          await _readMovementDocuments(sourceId, stockDate);
      return Success<List<SackRevenueContribution>>(
        contributionsForSack(sackId: sackId, documents: documents),
      );
    } on FirebaseException catch (error) {
      // ⛔ **ولا يُبتلَع صامتاً** — `coding-standards.md` §2.5 القاعدة 1.
      return Failure<List<SackRevenueContribution>>(
        error.code == 'permission-denied'
            ? const PermissionError()
            : InfrastructureError(error.code),
      );
    }
  }

  Future<List<SackMovementDocument>> _readMovementDocuments(
    String sourceId,
    CalendarDay stockDate,
  ) async {
    final Timestamp day = Timestamp.fromDate(stockDate.asUtcMidnight());
    Query<Map<String, dynamic>> dayQuery(String collection) => _firestore
        .collection(collection)
        .where('sourceId', isEqualTo: sourceId)
        // ★★ **تاريخ المخزون لا تاريخ الإدخال** — `RISK-07`.
        .where('stockDate', isEqualTo: day);

    final QuerySnapshot<Map<String, dynamic>> distributions =
        await dayQuery(distributionsCollection).get();
    final QuerySnapshot<Map<String, dynamic>> cashSales =
        await dayQuery(cashSalesCollection).get();
    // ⛔⛔★★★ **و`ledgerType` مُقيَّدٌ صراحةً — استعلامان لا واحد:**
    //   ★ **شرطُ قراءة `outflows` يتفرّع على `resource.data.ledgerType`**
    //   (`firestore.rules` §`outflows`: `withdrawalView` أو `expenseView`)،
    //   ⟵ **والشرط يُقيَّم على قيود الاستعلام لا على كل مستند**:
    //   ⛔ **فاستعلامٌ لا يُقيّده يُرفَض كاملاً ولو ملك القارئ كل المفاتيح**
    //   (`IQ-024` · `WU-008` · **وثالثُ وجوهه مقيسٌ حيّاً على المحاكي
    //   2026-09-03: تفكيكُ السعر ردّ «تعذّر عرض البيانات» بحساب QA كامل**).
    //   ★ **والعلاج تقييدُ الحقل** ⛔ **لا تخفيفُ القاعدة.**
    //
    // ⚠️★★ **والقارئُ السحابي لم يكشفه** — ★ **يعمل بحساب خدمةٍ يتخطّى
    //   القواعد**: ⟹ **فالمخزَّن كان صحيحاً والشاشةُ وحدها تفشل**
    //   (`DEBT-37` — **اختبارُ الطبقة لا يُغني عن اختبار ما يعبر بينها**).
    final List<QueryDocumentSnapshot<Map<String, dynamic>>> outflows =
        <QueryDocumentSnapshot<Map<String, dynamic>>>[
      for (final OutflowLedgerType type in OutflowLedgerType.values)
        ...(await dayQuery(outflowsCollection)
                .where('ledgerType', isEqualTo: type.name)
                .get())
            .docs,
    ];

    return <SackMovementDocument>[
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
          in distributions.docs)
        _distributionOf(doc, await _pricingOf(doc.reference)),
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
          in cashSales.docs)
        _cashSaleOf(doc),
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in outflows)
        _outflowOf(doc),
    ];
  }

  /// 🔒 **أسعارُ التوزيعة** — و`null` تعني **«لا يراها هذا المستخدم أو لا
  /// وجود لها»** (`ADR-0011` · `ت-12`).
  Future<Map<String, dynamic>?> _pricingOf(
    DocumentReference<Map<String, dynamic>> distribution,
  ) async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> doc = await distribution
          .collection(distributionPricingSubcollection)
          .doc(distributionPricingDocumentId)
          .get();
      return doc.exists ? doc.data() : null;
    } on FirebaseException {
      // ★ **رفضُ القراءة غيابُ صلاحيةٍ لا خطأ يُعرَض** — راجع ترويسة الملف.
      return null;
    }
  }

  // ═════════════════════════════════════════════════════════════════════
  // التحويل — ⛔ **والمجهول يُقرأ غياباً لا قيمةً مخترَعة**
  // ═════════════════════════════════════════════════════════════════════

  static SupplierBalanceCard _balanceOf(
    String supplierId,
    String sourceId,
    Map<String, dynamic>? data,
  ) =>
      SupplierBalanceCard(
        supplierId: supplierId,
        sourceId: sourceId,
        totals: SupplierSourceTotals(
          totalRevenue: _money(data?['totalSackRevenue']) ?? Money.zero,
          totalTax: _money(data?['totalSackTax']) ?? Money.zero,
          sackCount: _int(data?['sackCount']) ?? 0,
          pendingTaxCount: _int(data?['pendingTaxCount']) ?? 0,
          unfinalRevenueCount: _int(data?['unfinalRevenueCount']) ?? 0,
        ),
      );

  /// ★ يبني سطرَ دفتر الرعية — ⛔ **والغائب `null` لا صفراً**.
  ///
  /// ★★ **ومكشوفٌّ لأنَّ `FirestoreReportDirectory` يقرأ المجموعةَ نفسَها**
  /// (`R-25` · `R-26` — `WU-018`) — ⛔ **ونسخةٌ ثانية تفترق عند أول حقل**
  /// (`coding-standards.md` §2.2) — ★ **بنفس ما فُعل بـ`FirestoreDistributionDirectory.balanceOf` حرفياً.**
  static SupplierLedgerRow rowOf(String id, Map<String, dynamic> data) =>
      SupplierLedgerRow(
        sackId: _text(data['sackId']) ?? id,
        supplierId: _text(data['supplierId']) ?? '',
        sourceId: _text(data['sourceId']) ?? '',
        sackRevenue: _money(data['sackRevenue']) ?? Money.zero,
        recalcVersion: _int(data['recalcVersion']) ?? 0,
        supplierName: _text(data['supplierName']),
        sackDisplayName: _text(data['sackDisplayName']),
        sackTax: _money(data['sackTax']),
        supplierNet: _money(data['supplierNet']),
        isRevenueFinal: data['isRevenueFinal'] != false,
        isCancelled: data['isCancelled'] == true,
      );

  static SackMovementDocument _distributionOf(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    Map<String, dynamic>? pricing,
  ) {
    final List<Object?> lines = _list(doc.data()['lines']);
    final List<Object?> unitPrices = _list(pricing?['unitPrices']);
    final List<Object?> lineTotals = _list(pricing?['lineTotals']);
    return SackMovementDocument(
      documentNumber: _text(doc.data()['documentNumber']) ?? doc.id,
      origin: SackRevenueSource.distribution,
      isCancelled: doc.data()['status'] == DistributionStatus.cancelled.name,
      counterpartyName: _text(doc.data()['dealerName']),
      lines: <SackMovementLine>[
        for (int index = 0; index < lines.length; index++)
          if (_map(lines[index]) case final Map<String, dynamic> line)
            _lineOf(
              line,
              unitPrice: _money(_at(unitPrices, index)),
              lineValue: _money(_at(lineTotals, index)),
            ),
      ],
    );
  }

  static SackMovementDocument _cashSaleOf(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) =>
      SackMovementDocument(
        documentNumber: _text(doc.data()['documentNumber']) ?? doc.id,
        origin: SackRevenueSource.cashSale,
        isCancelled: doc.data()['status'] == CashSaleStatus.cancelled.name,
        lines: <SackMovementLine>[
          for (final Object? entry in _list(doc.data()['lines']))
            if (_map(entry) case final Map<String, dynamic> line)
              _lineOf(
                line,
                unitPrice: _money(line['unitPrice']),
                lineValue: _money(line['lineTotal']),
              ),
        ],
      );

  static SackMovementDocument _outflowOf(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) =>
      SackMovementDocument(
        documentNumber: _text(doc.data()['documentNumber']) ?? doc.id,
        origin: doc.data()['ledgerType'] == OutflowLedgerType.expense.name
            ? SackRevenueSource.expense
            : SackRevenueSource.withdrawal,
        isCancelled: doc.data()['status'] == OutflowStatus.cancelled.name,
        lines: <SackMovementLine>[
          for (final Object? entry in _list(doc.data()['lines']))
            if (_map(entry) case final Map<String, dynamic> line)
              // ⛔ **وبندُ المبلغ لا نوعَ له ولا جونية** — `FR-M22-05`.
              if (line['itemType'] == OutflowLineKind.qat.name)
                _lineOf(
                  line,
                  unitPrice: _money(line['unitPrice']),
                  lineValue: _money(line['lineValue']),
                ),
        ],
      );

  static SackMovementLine _lineOf(
    Map<String, dynamic> line, {
    required Money? unitPrice,
    required Money? lineValue,
  }) {
    final String itemKey = _text(line['itemId']) ?? '';
    return SackMovementLine(
      itemKey: itemKey,
      itemName: _text(line['itemName']) ?? itemKey,
      quantity: _quantityOf(line),
      // ★★★ **ومرجعُ الجونية كما كتبته السحابة** — [`DEBT-86`].
      sackId: _text(line['sackId']),
      unitPrice: unitPrice,
      lineValue: lineValue,
    );
  }

  static StockQuantity _quantityOf(Map<String, dynamic> line) =>
      line['unit'] == ItemUnit.kilogram.name
          ? WeightQuantity(WeightKg(_double(line['quantity']) ?? 0))
          : PieceQuantity(PieceCount(_int(line['quantity']) ?? 0));

  static List<Object?> _list(Object? raw) =>
      raw is List<dynamic> ? raw : const <Object?>[];

  static Map<String, dynamic>? _map(Object? raw) =>
      raw is Map<String, dynamic> ? raw : null;

  static Object? _at(List<Object?> values, int index) =>
      index < values.length ? values[index] : null;

  static String? _text(Object? raw) {
    if (raw is! String) return null;
    final String trimmed = raw.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  /// ★ مبلغٌ مقروء أو `null` — ⛔ **والكسر ليس مبلغاً** (`ADR-0015`).
  static Money? _money(Object? raw) {
    final int? value = _int(raw);
    return value == null ? null : Money(value);
  }

  static int? _int(Object? raw) => switch (raw) {
        final int value => value,
        final double value when value == value.roundToDouble() => value.toInt(),
        _ => null,
      };

  static double? _double(Object? raw) => switch (raw) {
        final int value => value.toDouble(),
        final double value => value,
        _ => null,
      };
}

/// قراءةُ مستندات الصرف وتطبيعُها — **ثلاثةُ أشكالٍ مخزَّنة إلى شكلٍ واحد**.
///
/// ★ **مفصول عن `sack_valuation_handler.dart` عمداً** — ★ **لأن التطبيع وحده
/// نصفُ المُحتسِب حجماً**، ⟵ **وبقاؤهما معاً كان يتجاوز حدّ الملف**
/// (`coding-standards.md` §4: **≤ 400 سطر**).
///
/// ★★ **والشكل الواحد في طبقة النطاق** (`SackMovementDocument`) — ⛔ **ولا
/// معادلةَ هنا إطلاقاً**: ★ **هذا الملف قارئٌ ومُطبِّع لا حاسب.**
///
/// ⚠️⚠️ **ولماذا ثلاثةُ أشكال أصلاً:** **أسعارُ التوزيعة في `pricing/current`
/// المعزول** (`ADR-0011`) · **وسعرُ البيع النقدي في السطر نفسِه**
/// (`schema/cash-sales.md`) · **وقيمةُ بند القات في سطر السند** —
/// ⟵ **والفروقُ مقصودةٌ في كلٍّ منها**، ⛔ **فلا تُوحَّد في المخزَّن بل هنا.**
library;

import 'package:qtms_domain/qtms_domain.dart';

import 'firestore_value.dart' show DecimalValue;
import 'firestore_writer.dart';
import 'inventory.dart' show documentStatusField;

/// ★ يقرأ كل مستندات الصرف في (مصدر × تاريخ مخزون) **مُطبَّعةً**.
///
/// ⚠️ **وثلاثةُ استعلاماتٍ لا استعلامٌ لكل جونية** — `sack-valuation-design.md`
/// §6 القاعدة 1: ⟵ **فدفعةُ اليوم كلُّها تُقرأ مرةً واحدة.**
Future<List<SackMovementDocument>> readSackMovementDocuments(
  FirestoreWriter writer, {
  required String sourceId,
  required CalendarDay stockDate,
}) async {
  final Map<String, Object?> filter = <String, Object?>{
    'sourceId': sourceId,
    // ★★ **تاريخ المخزون لا تاريخ الإدخال** — `RISK-07`.
    'stockDate': stockDate.asUtcMidnight(),
  };
  final List<StoredDocument> distributions = await writer.queryDocuments(
    collectionId: distributionsCollection,
    equals: filter,
  );
  final List<StoredDocument> cashSales = await writer.queryDocuments(
    collectionId: cashSalesCollection,
    equals: filter,
  );
  final List<StoredDocument> outflows = await writer.queryDocuments(
    collectionId: outflowsCollection,
    equals: filter,
  );
  // 🔒 **وأسعارُ التوزيعة في مستندها المعزول** — `ADR-0011`.
  final Map<String, String> pricingPaths = <String, String>{
    for (final StoredDocument document in distributions)
      document.id: writer.documentPath(
        '$distributionsCollection/${document.id}/'
            '$distributionPricingSubcollection',
        distributionPricingDocumentId,
      ),
  };
  final Map<String, Map<String, Object?>?> pricing =
      await writer.readDocuments(pricingPaths.values);

  return <SackMovementDocument>[
    for (final StoredDocument document in distributions)
      distributionMovementOf(document, pricing[pricingPaths[document.id]]),
    for (final StoredDocument document in cashSales)
      cashSaleMovementOf(document),
    for (final StoredDocument document in outflows) outflowMovementOf(document),
  ];
}

/// ★ توزيعةٌ مُطبَّعة — **والأسعار من `pricing/current` بمحاذاة الترتيب**.
///
/// ⚠️⚠️ **والمحاذاة بالفهرس هي عقدُ المستند نفسِه** (`data-dictionary.md`
/// §`pricing/current`): `unitPrices[]` و`lineTotals[]` **موازيتان لترتيب
/// `lines[]`** — ⛔ **وقراءتُها بغير الفهرس تنسب سعراً لنوعٍ آخر**، ★ **وهو
/// ما يحذّر منه `_pricingWrite` في `distribution.dart` حرفياً.**
SackMovementDocument distributionMovementOf(
  StoredDocument document,
  Map<String, Object?>? pricing,
) {
  final List<Object?> lines = _list(document.fields['lines']);
  final List<Object?> unitPrices = _list(pricing?['unitPrices']);
  final List<Object?> lineTotals = _list(pricing?['lineTotals']);
  return SackMovementDocument(
    documentNumber: _text(document.fields['documentNumber']) ?? document.id,
    origin: SackRevenueSource.distribution,
    isCancelled: document.fields[documentStatusField] ==
        DistributionStatus.cancelled.name,
    counterpartyName: _text(document.fields['dealerName']),
    lines: <SackMovementLine>[
      for (int index = 0; index < lines.length; index++)
        if (_map(lines[index]) case final Map<String, Object?> line)
          _lineOf(
            line,
            unitPrice: _money(_at(unitPrices, index)),
            lineValue: _money(_at(lineTotals, index)),
          ),
    ],
  );
}

/// ★ بيعٌ نقديٌّ مُطبَّع — **والسعر في السطر نفسِه** (`schema/cash-sales.md`).
SackMovementDocument cashSaleMovementOf(StoredDocument document) =>
    SackMovementDocument(
      documentNumber: _text(document.fields['documentNumber']) ?? document.id,
      origin: SackRevenueSource.cashSale,
      isCancelled: document.fields[documentStatusField] ==
          CashSaleStatus.cancelled.name,
      lines: <SackMovementLine>[
        for (final Object? entry in _list(document.fields['lines']))
          if (_map(entry) case final Map<String, Object?> line)
            _lineOf(
              line,
              unitPrice: _money(line['unitPrice']),
              lineValue: _money(line['lineTotal']),
            ),
      ],
    );

/// ★★ سندُ سحبيةٍ أو خرجية مُطبَّعاً — **وبنودُ القات وحدها تُقرأ**.
///
/// ⛔★★ **والسجلُّ يُختار من `ledgerType` المخزَّن** — `GR-43`: ⟵ **فالسحبية
/// والخرجية إجماليان وتقريران وصلاحيتان منفصلتان**، ⛔ **ووسمُ أحدهما
/// بالآخر يخلط ما فُصل عمداً** (**درسُ `sourceDocType` المحفور** — 2026-08-26).
SackMovementDocument outflowMovementOf(StoredDocument document) =>
    SackMovementDocument(
      documentNumber: _text(document.fields['documentNumber']) ?? document.id,
      origin: document.fields['ledgerType'] == OutflowLedgerType.expense.name
          ? SackRevenueSource.expense
          : SackRevenueSource.withdrawal,
      isCancelled:
          document.fields[documentStatusField] == OutflowStatus.cancelled.name,
      lines: <SackMovementLine>[
        for (final Object? entry in _list(document.fields['lines']))
          if (_map(entry) case final Map<String, Object?> line)
            // ⛔ **وبندُ المبلغ لا نوعَ له ولا جونية** — `FR-M22-05`.
            if (line['itemType'] == OutflowLineKind.qat.name)
              _lineOf(
                line,
                unitPrice: _money(line['unitPrice']),
                lineValue: _money(line['lineValue']),
              ),
      ],
    );

SackMovementLine _lineOf(
  Map<String, Object?> line, {
  required Money? unitPrice,
  required Money? lineValue,
}) {
  final String itemKey = _text(line['itemId']) ?? '';
  return SackMovementLine(
    itemKey: itemKey,
    itemName: _text(line['itemName']) ?? itemKey,
    quantity: _quantityOf(line),
    // ★★★ **ومرجعُ الجونية كما كتبته السحابة** — [`DEBT-86`]:
    //    ⛔ **ولا يُشتقّ هنا من اسمٍ ولا تاريخ.**
    sackId: _text(line['sackId']),
    unitPrice: unitPrice,
    lineValue: lineValue,
  );
}

/// ★ الكمية بوحدتها — ⛔ **ولا وحدةَ تُستنتَج من شكل الرقم** (`GR-19`).
StockQuantity _quantityOf(Map<String, Object?> line) {
  final Object? raw = line['quantity'];
  if (line['unit'] == ItemUnit.kilogram.name) {
    return WeightQuantity(WeightKg(_double(raw) ?? 0));
  }
  return PieceQuantity(PieceCount(_int(raw) ?? 0));
}

// ═════════════════════════════════════════════════════════════════════════
// القراءة الآمنة — ⛔ **والمجهول يُقرأ غياباً لا قيمةً مخترَعة**
// ═════════════════════════════════════════════════════════════════════════

List<Object?> _list(Object? raw) =>
    raw is List<Object?> ? raw : const <Object?>[];

Map<String, Object?>? _map(Object? raw) =>
    raw is Map<String, Object?> ? raw : null;

Object? _at(List<Object?> values, int index) =>
    index < values.length ? values[index] : null;

String? _text(Object? raw) {
  if (raw is! String) return null;
  final String trimmed = raw.trim();
  return trimmed.isEmpty ? null : trimmed;
}

/// ★ مبلغٌ مقروء أو `null` — ⛔ **والكسر ليس مبلغاً** (`ADR-0015`).
Money? _money(Object? raw) {
  final int? value = _int(raw);
  return value == null ? null : Money(value);
}

int? _int(Object? raw) => switch (raw) {
      final int value => value,
      final double value when value == value.roundToDouble() => value.toInt(),
      _ => null,
    };

double? _double(Object? raw) => switch (raw) {
      final int value => value.toDouble(),
      final double value => value,
      final DecimalValue value => value.value,
      _ => null,
    };

/// ⛔⛔★★★ **اختبارُ ما يعبر بين الطبقتين** — **مُحتسِبُ مالية الجواني حيّاً**.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ★★★ **ولماذا على `SackValuationHandler` لا على `planSackValuation` وحدها:**
/// ★ **الخطةُ دالةٌ خالصة تستقبل مستنداتٍ مُطبَّعة جاهزة** — ⟵ **وكلُّ خطر
/// هذه الزيادة في التطبيع نفسِه**: **ثلاثةُ أشكالٍ مخزَّنة مختلفة**
/// (`pricing/current` المعزول · سعرٌ في السطر · قيمةٌ في بند القات).
/// ⛔ **واختبارُ الطبقة لا يُغني عن اختبار ما يعبر بينها** — `DEBT-37`.
///
/// ★ **ويفحص هذا الاختبار المخرَجَ المكتوب فعلاً** (أجسام `:commit`)
/// ⛔ **لا أن الدالة «نجحت»** — ★ **وهو نفسُ مبدأ «لا يُفترَض شكلُ مخرجات
/// مكتبة، يُقاس»** (`DEBT-24` · `DEBT-25`).
/// ═══════════════════════════════════════════════════════════════════════
library;

import 'dart:convert';

import 'package:googleapis/firestore/v1.dart' as firestore;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:qtms_domain/qtms_domain.dart';
import 'package:qtms_functions/src/firestore_writer.dart';
import 'package:qtms_functions/src/sack_valuation.dart';
import 'package:qtms_functions/src/sack_valuation_handler.dart';
import 'package:test/test.dart';

const String projectId = 'demo-qtms';
const String sourceA = 'SRC-001';
const String supplierA = 'SUP-0001';
const String sackA = 'SCK-20260903-0001';
const String itemKeyA = 'بطوة - الرعوي الأول - جونية رقم 1';
const String scrapKeyA = 'السكرب - الرعوي الأول - جونية رقم 1';

final CalendarDay day = CalendarDay.fromUtc(DateTime.utc(2026, 9, 3));

/// ما التزمت به الشبكةُ فعلاً — ★ **يُقرأ لا يُفترَض**.
final class _Committed {
  final List<Map<String, Object?>> writes = <Map<String, Object?>>[];

  /// ★ آخرُ كتابةٍ على مسارٍ ينتهي بـ[suffix].
  Map<String, Object?> onPath(String suffix) => writes.lastWhere(
        (Map<String, Object?> write) =>
            (((write['update']! as Map<String, Object?>)['name']! as String))
                .endsWith(suffix),
        orElse: () => throw StateError('لا كتابة على «$suffix»'),
      );

  bool hasPath(String suffix) => writes.any(
        (Map<String, Object?> write) =>
            (((write['update']! as Map<String, Object?>)['name']! as String))
                .endsWith(suffix),
      );

  /// ★ حقولُ كتابةٍ مفكوكةً إلى قيم Dart عادية.
  Map<String, Object?> fieldsOn(String suffix) {
    final Map<String, Object?> update =
        onPath(suffix)['update']! as Map<String, Object?>;
    final Map<String, Object?> raw =
        (update['fields'] ?? <String, Object?>{}) as Map<String, Object?>;
    return <String, Object?>{
      for (final MapEntry<String, Object?> entry in raw.entries)
        entry.key: _plain(entry.value! as Map<String, Object?>),
    };
  }

  List<String> transformsOn(String suffix) => <String>[
        for (final Object? raw
            in (onPath(suffix)['updateTransforms'] ?? <Object?>[])
                as List<Object?>)
          (raw! as Map<String, Object?>)['fieldPath']! as String,
      ];

  static Object? _plain(Map<String, Object?> value) {
    if (value.containsKey('nullValue')) return null;
    if (value['integerValue'] case final String number) return int.parse(number);
    if (value['stringValue'] case final String text) return text;
    if (value['booleanValue'] case final bool flag) return flag;
    if (value['doubleValue'] case final num number) return number.toDouble();
    return value;
  }
}

http.Response _json(Object? body) => http.Response(
      jsonEncode(body),
      200,
      headers: <String, String>{
        'content-type': 'application/json; charset=utf-8',
      },
    );

String _path(String tail) =>
    'projects/$projectId/databases/(default)/documents/$tail';

Map<String, Object?> _doc(String tail, Map<String, Object?> fields) =>
    <String, Object?>{
      'document': <String, Object?>{
        'name': _path(tail),
        'fields': fields,
      },
      'readTime': '2026-09-03T08:00:00.000000Z',
    };

Map<String, Object?> _str(String value) =>
    <String, Object?>{'stringValue': value};

Map<String, Object?> _int(int value) =>
    <String, Object?>{'integerValue': '$value'};

Map<String, Object?> _bool(bool value) =>
    <String, Object?>{'booleanValue': value};

Map<String, Object?> _map(Map<String, Object?> fields) => <String, Object?>{
      'mapValue': <String, Object?>{'fields': fields},
    };

Map<String, Object?> _array(List<Map<String, Object?>> values) =>
    <String, Object?>{
      'arrayValue': <String, Object?>{'values': values},
    };

/// ★ سطرُ توزيعةٍ كما يُخزَّن — ⛔ **بلا سعرٍ فيه** (`ADR-0011`).
Map<String, Object?> _distributionLine({String? sackId = sackA}) => _map(
      <String, Object?>{
        'itemId': _str(itemKeyA),
        'itemName': _str('بطوة'),
        'unit': _str(ItemUnit.piece.name),
        'quantity': _int(100),
        if (sackId != null) 'sackId': _str(sackId),
      },
    );

/// حالةُ القاعدة المزيّفة — ★ **تُبنى لكل اختبار على حدة**.
final class _Database {
  _Database({
    this.storedFinance,
    this.storedLedger,
    this.distributionPricing = const <String, Object?>{},
    this.cashSales = const <Object?>[],
    this.outflows = const <Object?>[],
    this.distributions,
    this.ledgerRows = const <Object?>[],
    this.sackCancelled = false,
    this.supplierId = supplierA,
  });

  final Map<String, Object?>? storedFinance;
  final Map<String, Object?>? storedLedger;
  final Map<String, Object?> distributionPricing;
  final List<Object?> cashSales;
  final List<Object?> outflows;
  final List<Object?>? distributions;
  final List<Object?> ledgerRows;
  final bool sackCancelled;
  final String? supplierId;
}

MockClient _client(_Database db, _Committed committed) =>
    MockClient((http.Request request) async {
      final String url = request.url.toString();

      if (url.contains(':runQuery')) {
        final Map<String, Object?> body =
            jsonDecode(request.body) as Map<String, Object?>;
        final Map<String, Object?> query =
            body['structuredQuery']! as Map<String, Object?>;
        final String collection = ((query['from']! as List<Object?>).first!
            as Map<String, Object?>)['collectionId']! as String;
        return _json(_queryResult(db, collection));
      }

      if (url.contains(':batchGet')) {
        final Map<String, Object?> body =
            jsonDecode(request.body) as Map<String, Object?>;
        return _json(<Object?>[
          for (final Object? raw in body['documents']! as List<Object?>)
            _batchElement(db, raw! as String),
        ]);
      }

      if (url.contains(':commit')) {
        final Map<String, Object?> body =
            jsonDecode(request.body) as Map<String, Object?>;
        for (final Object? raw in body['writes']! as List<Object?>) {
          committed.writes.add(raw! as Map<String, Object?>);
        }
        return _json(<String, Object?>{'writeResults': <Object?>[]});
      }

      return http.Response('مسارٌ غير متوقَّع: $url', 500);
    });

List<Object?> _queryResult(_Database db, String collection) =>
    switch (collection) {
      sacksCollection => <Object?>[
          _doc(
            '$sacksCollection/$sackA',
            <String, Object?>{
              'documentNumber': _str(sackA),
              'sourceId': _str(sourceA),
              'displayName': _str('الرعوي الأول - جونية رقم 1'),
              if (db.supplierId case final String supplierId)
                'supplierId': _str(supplierId),
              'supplierName': _str('الرعوي الأول'),
              'status': _str(
                db.sackCancelled
                    ? SackStatus.cancelled.name
                    : SackStatus.approved.name,
              ),
            },
          ),
        ],
      distributionsCollection => db.distributions ??
          <Object?>[
            _doc(
              '$distributionsCollection/MQT-0001_${sourceA}_20260903',
              <String, Object?>{
                'documentNumber': _str('DST-20260903-0001'),
                'sourceId': _str(sourceA),
                'dealerName': _str('المقوت الأول'),
                'status': _str(DistributionStatus.partiallyPriced.name),
                'lines': _array(<Map<String, Object?>>[_distributionLine()]),
              },
            ),
          ],
      cashSalesCollection => db.cashSales,
      outflowsCollection => db.outflows,
      supplierLedgerCollection => db.ledgerRows,
      _ => <Object?>[],
    };

Map<String, Object?> _batchElement(_Database db, String path) {
  if (path.endsWith('$sackFinanceSubcollection/$sackFinanceDocumentId')) {
    final Map<String, Object?>? finance = db.storedFinance;
    return finance == null
        ? <String, Object?>{'missing': path}
        : <String, Object?>{
            'found': <String, Object?>{'name': path, 'fields': finance},
          };
  }
  if (path.contains('/$supplierLedgerCollection/')) {
    final Map<String, Object?>? ledger = db.storedLedger;
    return ledger == null
        ? <String, Object?>{'missing': path}
        : <String, Object?>{
            'found': <String, Object?>{'name': path, 'fields': ledger},
          };
  }
  if (path.endsWith(
    '$distributionPricingSubcollection/$distributionPricingDocumentId',
  )) {
    return db.distributionPricing.isEmpty
        ? <String, Object?>{'missing': path}
        : <String, Object?>{
            'found': <String, Object?>{
              'name': path,
              'fields': db.distributionPricing,
            },
          };
  }
  return <String, Object?>{'missing': path};
}

SackValuationHandler _handler(_Database db, _Committed committed) =>
    SackValuationHandler(
      FirestoreWriter(
        projectId: projectId,
        api: firestore.FirestoreApi(_client(db, committed)),
      ),
    );

const String financeSuffix =
    '$sacksCollection/$sackA/$sackFinanceSubcollection/'
    '$sackFinanceDocumentId';
const String ledgerSuffix = '$supplierLedgerCollection/$sackA';
final String balanceSuffix = '$supplierBalancesCollection/'
    '${supplierBalanceId(supplierId: supplierA, sourceId: sourceA)}';

void main() {
  group('★★★ التطبيع الحيّ — توزيعةٌ وأسعارُها في مستندها المعزول', () {
    test('ADR-0011: السعر من pricing/current بمحاذاة ترتيب lines[]', () async {
      final _Committed committed = _Committed();
      final int written = await _handler(
        _Database(
          storedFinance: <String, Object?>{'sackTax': _int(1125)},
          distributionPricing: <String, Object?>{
            'unitPrices': _array(<Map<String, Object?>>[_int(373)]),
            'lineTotals': _array(<Map<String, Object?>>[_int(37300)]),
          },
        ),
        committed,
      ).revalueDay(sourceId: sourceA, stockDate: day);

      expect(written, 2);
      expect(committed.fieldsOn(financeSuffix)['sackRevenue'], 37300);
      expect(committed.fieldsOn(financeSuffix)['supplierNet'], 36175);
      expect(committed.fieldsOn(financeSuffix)['isRevenueFinal'], isTrue);
      expect(committed.transformsOn(financeSuffix), <String>['lastRevaluedAt']);
    });

    test('⛔ توزيعةٌ بلا مستند أسعار = سعرٌ غير نهائي لا صفرٌ نهائي', () async {
      final _Committed committed = _Committed();
      await _handler(
        _Database(storedFinance: <String, Object?>{'sackTax': _int(1125)}),
        committed,
      ).revalueDay(sourceId: sourceA, stockDate: day);

      expect(committed.fieldsOn(financeSuffix)['sackRevenue'], 0);
      expect(committed.fieldsOn(financeSuffix)['isRevenueFinal'], isFalse);
    });

    test('⛔⛔ وسطرٌ بلا sackId لا يدخل إيراد الجونية — DEBT-86', () async {
      final _Committed committed = _Committed();
      await _handler(
        _Database(
          storedFinance: <String, Object?>{'sackTax': _int(1125)},
          distributions: <Object?>[
            _doc(
              '$distributionsCollection/MQT-0002_${sourceA}_20260903',
              <String, Object?>{
                'documentNumber': _str('DST-20260903-0002'),
                'sourceId': _str(sourceA),
                'status': _str(DistributionStatus.partiallyPriced.name),
                'lines': _array(
                  <Map<String, Object?>>[_distributionLine(sackId: null)],
                ),
              },
            ),
          ],
          distributionPricing: <String, Object?>{
            'unitPrices': _array(<Map<String, Object?>>[_int(373)]),
            'lineTotals': _array(<Map<String, Object?>>[_int(37300)]),
          },
        ),
        committed,
      ).revalueDay(sourceId: sourceA, stockDate: day);

      expect(committed.fieldsOn(financeSuffix)['sackRevenue'], 0);
      expect(committed.fieldsOn(financeSuffix)['isRevenueFinal'], isTrue);
    });
  });

  group('★★ التطبيع الحيّ — البيع النقدي والسحبيات والخرجيات', () {
    test('ت-09: سكربٌ وزنيٌّ يُباع نقداً يدخل السعر بقيمته المسجَّلة', () async {
      final _Committed committed = _Committed();
      await _handler(
        _Database(
          storedFinance: <String, Object?>{'sackTax': _int(1125)},
          distributions: <Object?>[],
          cashSales: <Object?>[
            _doc(
              '$cashSalesCollection/CSH-20260903-0001',
              <String, Object?>{
                'documentNumber': _str('CSH-20260903-0001'),
                'sourceId': _str(sourceA),
                'status': _str(CashSaleStatus.approved.name),
                'lines': _array(<Map<String, Object?>>[
                  _map(<String, Object?>{
                    'itemId': _str(scrapKeyA),
                    'itemName': _str('السكرب'),
                    'unit': _str(ItemUnit.kilogram.name),
                    'quantity': <String, Object?>{'doubleValue': 0.5},
                    'unitPrice': _int(250),
                    'lineTotal': _int(125),
                    'sackId': _str(sackA),
                  }),
                ]),
              },
            ),
          ],
        ),
        committed,
      ).revalueDay(sourceId: sourceA, stockDate: day);

      expect(committed.fieldsOn(financeSuffix)['sackRevenue'], 125);
      expect(committed.fieldsOn(financeSuffix)['supplierNet'], -1000);
    });

    test('A-15 · E-26: سحبيةٌ بقاتٍ مسعَّر تستحق الرعوي ثمنها', () async {
      final _Committed committed = _Committed();
      await _handler(
        _Database(
          storedFinance: <String, Object?>{'sackTax': _int(100)},
          distributions: <Object?>[],
          outflows: <Object?>[
            _doc(
              '$outflowsCollection/WDR-20260903-0001',
              <String, Object?>{
                'documentNumber': _str('WDR-20260903-0001'),
                'sourceId': _str(sourceA),
                'ledgerType': _str(OutflowLedgerType.withdrawal.name),
                'status': _str(OutflowStatus.approved.name),
                'lines': _array(<Map<String, Object?>>[
                  _map(<String, Object?>{
                    'itemType': _str(OutflowLineKind.qat.name),
                    'itemId': _str(itemKeyA),
                    'itemName': _str('بطوة'),
                    'unit': _str(ItemUnit.piece.name),
                    'quantity': _int(5),
                    'unitPrice': _int(400),
                    'lineValue': _int(2000),
                    'sackId': _str(sackA),
                  }),
                  // ⛔ **وبندُ المبلغ لا نوعَ له ولا جونية** — `FR-M22-05`.
                  _map(<String, Object?>{
                    'itemType': _str(OutflowLineKind.amount.name),
                    'amount': _int(9999),
                  }),
                ]),
              },
            ),
          ],
        ),
        committed,
      ).revalueDay(sourceId: sourceA, stockDate: day);

      expect(committed.fieldsOn(financeSuffix)['sackRevenue'], 2000);
      expect(committed.fieldsOn(ledgerSuffix)['supplierNet'], 1900);
    });

    test('FR-M22-07: بندُ قاتٍ بلا قيمة يُبقي السعر غير نهائي', () async {
      final _Committed committed = _Committed();
      await _handler(
        _Database(
          storedFinance: <String, Object?>{'sackTax': _int(100)},
          distributions: <Object?>[],
          outflows: <Object?>[
            _doc(
              '$outflowsCollection/EXP-20260903-0001',
              <String, Object?>{
                'documentNumber': _str('EXP-20260903-0001'),
                'sourceId': _str(sourceA),
                'ledgerType': _str(OutflowLedgerType.expense.name),
                'status': _str(OutflowStatus.approved.name),
                'lines': _array(<Map<String, Object?>>[
                  _map(<String, Object?>{
                    'itemType': _str(OutflowLineKind.qat.name),
                    'itemId': _str(itemKeyA),
                    'itemName': _str('بطوة'),
                    'unit': _str(ItemUnit.piece.name),
                    'quantity': _int(3),
                    'sackId': _str(sackA),
                  }),
                ]),
              },
            ),
          ],
        ),
        committed,
      ).revalueDay(sourceId: sourceA, stockDate: day);

      expect(committed.fieldsOn(financeSuffix)['sackRevenue'], 0);
      expect(committed.fieldsOn(financeSuffix)['isRevenueFinal'], isFalse);
    });

    test('A-14: المستندُ الملغى لا يدخل الجمع', () async {
      final _Committed committed = _Committed();
      await _handler(
        _Database(
          storedFinance: <String, Object?>{'sackTax': _int(1125)},
          distributions: <Object?>[
            _doc(
              '$distributionsCollection/MQT-0001_${sourceA}_20260903',
              <String, Object?>{
                'documentNumber': _str('DST-20260903-0001'),
                'sourceId': _str(sourceA),
                'status': _str(DistributionStatus.cancelled.name),
                'lines': _array(<Map<String, Object?>>[_distributionLine()]),
              },
            ),
          ],
          distributionPricing: <String, Object?>{
            'unitPrices': _array(<Map<String, Object?>>[_int(373)]),
            'lineTotals': _array(<Map<String, Object?>>[_int(37300)]),
          },
        ),
        committed,
      ).revalueDay(sourceId: sourceA, stockDate: day);

      expect(committed.fieldsOn(financeSuffix)['sackRevenue'], 0);
      expect(committed.fieldsOn(financeSuffix)['isRevenueFinal'], isTrue);
    });
  });

  group('★★ رصيدُ الرعوي يُبنى بعد الالتزام من دفتره', () {
    test('§2.5: الإجماليات الثلاثة من سطور الدفتر لا من الدفعة', () async {
      final _Committed committed = _Committed();
      await _handler(
        _Database(
          storedFinance: <String, Object?>{'sackTax': _int(1125)},
          distributionPricing: <String, Object?>{
            'unitPrices': _array(<Map<String, Object?>>[_int(373)]),
            'lineTotals': _array(<Map<String, Object?>>[_int(37300)]),
          },
          // ★ **سطرٌ من يومٍ آخر يدخل الرصيد** — ⟵ **فالحساب عبر الأيام.**
          ledgerRows: <Object?>[
            _doc('$supplierLedgerCollection/$sackA', <String, Object?>{
              'supplierId': _str(supplierA),
              'sourceId': _str(sourceA),
              'sackRevenue': _int(37300),
              'sackTax': _int(1125),
              'isRevenueFinal': _bool(true),
            }),
            _doc(
              '$supplierLedgerCollection/SCK-20260902-0001',
              <String, Object?>{
                'supplierId': _str(supplierA),
                'sourceId': _str(sourceA),
                'sackRevenue': _int(20000),
                'sackTax': _int(500),
                'isRevenueFinal': _bool(true),
              },
            ),
          ],
        ),
        committed,
      ).revalueDay(sourceId: sourceA, stockDate: day);

      final Map<String, Object?> balance = committed.fieldsOn(balanceSuffix);
      expect(balance['totalSackRevenue'], 57300);
      expect(balance['totalSackTax'], 1625);
      expect(balance['supplierNet'], 55675);
      expect(balance['sackCount'], 2);
      expect(balance['sourceId'], sourceA);
      expect(committed.transformsOn(balanceSuffix), <String>['updatedAt']);
    });

    test('⛔ والملغاة لا تدخل رصيد الرعوي', () async {
      final _Committed committed = _Committed();
      await _handler(
        _Database(
          storedFinance: <String, Object?>{'sackTax': _int(1125)},
          distributionPricing: <String, Object?>{
            'unitPrices': _array(<Map<String, Object?>>[_int(373)]),
            'lineTotals': _array(<Map<String, Object?>>[_int(37300)]),
          },
          ledgerRows: <Object?>[
            _doc('$supplierLedgerCollection/$sackA', <String, Object?>{
              'supplierId': _str(supplierA),
              'sourceId': _str(sourceA),
              'sackRevenue': _int(37300),
              'sackTax': _int(1125),
              'isCancelled': _bool(true),
            }),
          ],
        ),
        committed,
      ).revalueDay(sourceId: sourceA, stockDate: day);

      expect(committed.fieldsOn(balanceSuffix)['totalSackRevenue'], 0);
      expect(committed.fieldsOn(balanceSuffix)['sackCount'], 0);
    });

    test('GR-06 · GR-07: الجونيةُ الملغاة تبقى سطراً موسوماً في الدفتر',
        () async {
      final _Committed committed = _Committed();
      await _handler(
        _Database(
          sackCancelled: true,
          storedFinance: <String, Object?>{'sackTax': _int(1125)},
          distributions: <Object?>[],
        ),
        committed,
      ).revalueDay(sourceId: sourceA, stockDate: day);

      expect(committed.fieldsOn(ledgerSuffix)['isCancelled'], isTrue);
      expect(committed.fieldsOn(ledgerSuffix)['sackRevenue'], 0);
      // ⛔ **ولا حذفَ لها** — ★ **والرصيدُ يُبنى من الدفتر فيُسقِطها.**
      expect(committed.hasPath(balanceSuffix), isTrue);
    });

    test('FR-M7-03: مصدرٌ بلا رعوي ⟵ لا سطرَ دفترٍ ولا رصيد', () async {
      final _Committed committed = _Committed();
      await _handler(
        _Database(
          supplierId: null,
          storedFinance: <String, Object?>{'sackTax': _int(1125)},
          distributionPricing: <String, Object?>{
            'unitPrices': _array(<Map<String, Object?>>[_int(373)]),
            'lineTotals': _array(<Map<String, Object?>>[_int(37300)]),
          },
        ),
        committed,
      ).revalueDay(sourceId: sourceA, stockDate: day);

      expect(committed.hasPath(financeSuffix), isTrue);
      expect(committed.hasPath(ledgerSuffix), isFalse);
      expect(committed.hasPath(balanceSuffix), isFalse);
    });
  });

  group('★★★ قابلٌ للتكرار بلا أثر جانبي — api-overview §3.3', () {
    test('⛔ تشغيلٌ ثانٍ بلا تغيير لا يكتب حرفاً', () async {
      final _Committed committed = _Committed();
      final int written = await _handler(
        _Database(
          storedFinance: <String, Object?>{
            'sackTax': _int(1125),
            'sackRevenue': _int(37300),
            'supplierNet': _int(36175),
            'isRevenueFinal': _bool(true),
          },
          storedLedger: <String, Object?>{recalcVersionField: _int(3)},
          distributionPricing: <String, Object?>{
            'unitPrices': _array(<Map<String, Object?>>[_int(373)]),
            'lineTotals': _array(<Map<String, Object?>>[_int(37300)]),
          },
        ),
        committed,
      ).revalueDay(sourceId: sourceA, stockDate: day);

      expect(written, 0);
      expect(committed.writes, isEmpty);
    });

    test('★ وتغيّرُ السعر يرفع recalcVersion واحداً لا أكثر', () async {
      final _Committed committed = _Committed();
      await _handler(
        _Database(
          storedFinance: <String, Object?>{
            'sackTax': _int(1125),
            'sackRevenue': _int(1000),
            'supplierNet': _int(-125),
            'isRevenueFinal': _bool(true),
          },
          storedLedger: <String, Object?>{recalcVersionField: _int(3)},
          distributionPricing: <String, Object?>{
            'unitPrices': _array(<Map<String, Object?>>[_int(373)]),
            'lineTotals': _array(<Map<String, Object?>>[_int(37300)]),
          },
        ),
        committed,
      ).revalueDay(sourceId: sourceA, stockDate: day);

      expect(committed.fieldsOn(ledgerSuffix)[recalcVersionField], 4);
      expect(committed.transformsOn(ledgerSuffix), <String>['lastAmendedAt']);
    });

    test('⛔ ويومٌ بلا جوانٍ لا يقرأ مستنداً ولا يكتب شيئاً', () async {
      final _Committed committed = _Committed();
      final SackValuationHandler handler = SackValuationHandler(
        FirestoreWriter(
          projectId: projectId,
          api: firestore.FirestoreApi(
            MockClient((http.Request request) async {
              if (request.url.toString().contains(':runQuery')) {
                return _json(<Object?>[]);
              }
              return http.Response('لا يُتوقَّع نداءٌ آخر', 500);
            }),
          ),
        ),
      );

      expect(
        await handler.revalueDay(sourceId: sourceA, stockDate: day),
        0,
      );
      expect(committed.writes, isEmpty);
    });
  });

  group('⛔⛔ فشلُ المُحتسِب لا يُبطل العملية الأصلية — §3.3', () {
    test('يُبتلَع الفشلُ في السجل ولا يصعد استثناءً', () async {
      final SackValuationHandler handler = SackValuationHandler(
        FirestoreWriter(
          projectId: projectId,
          api: firestore.FirestoreApi(
            MockClient((http.Request request) async =>
                http.Response('خطأ خادم', 500)),
          ),
        ),
      );

      await expectLater(
        revalueSacksAfterCommit(handler, sourceId: sourceA, stockDate: day),
        completes,
      );
    });

    test('و`null` مُحتسِباً تعني «لا احتساب» — ولا سقوط', () async {
      await expectLater(
        revalueSacksAfterCommit(null, sourceId: sourceA, stockDate: day),
        completes,
      );
    });
  });
}

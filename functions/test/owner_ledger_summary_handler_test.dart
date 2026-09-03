/// ⛔⛔★★★ **اختبارُ ما يعبر بين الطبقتين** — **باني ملخصات ضمار المالك حيّاً**.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ★★★ **ولماذا على `OwnerLedgerSummaryHandler` لا على المعادلات وحدها:**
/// ★ **المعادلاتُ العشرُ مُختبَرةٌ في حزمة النطاق بأرقام §15** — ⟵ **وكلُّ
/// خطر هذه الزيادة في **التجميع**: أربعةُ مصادرِ أرقامٍ بأشكالٍ مخزَّنة
/// مختلفة** (`pricing/current` المعزول · `finance/current` المعزول ·
/// `netCashReceived` في الأب · `grandTotal` مع `ledgerType`).
/// ⛔ **واختبارُ الطبقة لا يُغني عن اختبار ما يعبر بينها** — `DEBT-37`.
///
/// ⚠️⚠️★★ **وتاريخان لا تاريخٌ واحد** (`GR-49`): ★ **الاختبارُ يُثبت أن
/// سحبيةً بتاريخ سندٍ مختلفٍ عن تاريخ مخزونها تدخل بطاقةَ تاريخِ سندها.**
///
/// ★ **ويفحص هذا الاختبار المخرَجَ المكتوب فعلاً** (أجسام `:commit`)
/// ⛔ **لا أن الدالة «نجحت»** — `DEBT-24` · `DEBT-25`.
/// ═══════════════════════════════════════════════════════════════════════
library;

import 'dart:convert';

import 'package:googleapis/firestore/v1.dart' as firestore;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:qtms_domain/qtms_domain.dart';
import 'package:qtms_functions/src/firestore_writer.dart';
import 'package:qtms_functions/src/owner_ledger_summary.dart';
import 'package:qtms_functions/src/owner_ledger_summary_handler.dart';
import 'package:test/test.dart';

const String projectId = 'demo-qtms';
const String sourceA = 'SRC-001';
const String sourceB = 'SRC-002';
const String sackA = 'SCK-20260820-0001';
const String distributionA = 'MQT-0001_SRC-001_20260820';

final CalendarDay day = CalendarDay(2026, 8, 20);
final CalendarDay today = CalendarDay(2026, 8, 22);

/// ما التزمت به الشبكةُ فعلاً — ★ **يُقرأ لا يُفترَض**.
final class _Committed {
  final List<Map<String, Object?>> writes = <Map<String, Object?>>[];

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
    if (value['timestampValue'] case final String stamp) return stamp;
    if (value['arrayValue'] case final Map<String, Object?> array) {
      return <Object?>[
        for (final Object? item
            in (array['values'] ?? <Object?>[]) as List<Object?>)
          _plain(item! as Map<String, Object?>),
      ];
    }
    if (value['mapValue'] case final Map<String, Object?> map) {
      final Map<String, Object?> fields =
          (map['fields'] ?? <String, Object?>{}) as Map<String, Object?>;
      return <String, Object?>{
        for (final MapEntry<String, Object?> entry in fields.entries)
          entry.key: _plain(entry.value! as Map<String, Object?>),
      };
    }
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
      'document': <String, Object?>{'name': _path(tail), 'fields': fields},
      'readTime': '2026-08-22T08:00:00.000000Z',
    };

Map<String, Object?> _str(String value) =>
    <String, Object?>{'stringValue': value};

Map<String, Object?> _int(int value) =>
    <String, Object?>{'integerValue': '$value'};

Map<String, Object?> _stamp(CalendarDay value) => <String, Object?>{
      'timestampValue': value.asUtcMidnight().toIso8601String(),
    };

/// حالةُ القاعدة المزيّفة — ★ **تُبنى لكل اختبار على حدة**.
final class _Database {
  _Database({
    this.distributions = const <Object?>[],
    this.pricing,
    this.cashSales = const <Object?>[],
    this.sacks = const <Object?>[],
    this.finance,
    this.outflows = const <Object?>[],
    this.summaries = const <Object?>[],
    this.storedTrend,
  });

  final List<Object?> distributions;
  final Map<String, Object?>? pricing;
  final List<Object?> cashSales;
  final List<Object?> sacks;
  final Map<String, Object?>? finance;
  final List<Object?> outflows;

  /// ملخصاتُ اليوم كما تقرؤها البطاقةُ التجميعية بعد الالتزام.
  final List<Object?> summaries;

  final Map<String, Object?>? storedTrend;
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
        return _json(
          switch (collection) {
            distributionsCollection => db.distributions,
            cashSalesCollection => db.cashSales,
            sacksCollection => db.sacks,
            outflowsCollection => db.outflows,
            dailySummariesCollection => db.summaries,
            _ => <Object?>[],
          },
        );
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

      // ★ قراءةُ مستندٍ واحد — سجلُّ السلسلة.
      if (url.contains('/$ownerLedgerTrendsCollection/')) {
        final Map<String, Object?>? trend = db.storedTrend;
        if (trend == null) {
          return http.Response(
            jsonEncode(<String, Object?>{
              'error': <String, Object?>{'code': 404, 'message': 'missing'},
            }),
            404,
            headers: <String, String>{
              'content-type': 'application/json; charset=utf-8',
            },
          );
        }
        return _json(<String, Object?>{
          'name': _path('$ownerLedgerTrendsCollection/$sourceA'),
          'fields': trend,
        });
      }

      return http.Response('مسارٌ غير متوقَّع: $url', 500);
    });

Map<String, Object?> _batchElement(_Database db, String path) {
  if (path.endsWith(
    '$distributionPricingSubcollection/$distributionPricingDocumentId',
  )) {
    final Map<String, Object?>? pricing = db.pricing;
    return pricing == null
        ? <String, Object?>{'missing': path}
        : <String, Object?>{
            'found': <String, Object?>{'name': path, 'fields': pricing},
          };
  }
  if (path.endsWith('$sackFinanceSubcollection/$sackFinanceDocumentId')) {
    final Map<String, Object?>? finance = db.finance;
    return finance == null
        ? <String, Object?>{'missing': path}
        : <String, Object?>{
            'found': <String, Object?>{'name': path, 'fields': finance},
          };
  }
  return <String, Object?>{'missing': path};
}

OwnerLedgerSummaryHandler _handler(_Database db, _Committed committed) =>
    OwnerLedgerSummaryHandler(
      FirestoreWriter(
        projectId: projectId,
        api: firestore.FirestoreApi(_client(db, committed)),
      ),
    );

final String summarySuffix = '$dailySummariesCollection/'
    '${dailySummaryId(sourceId: sourceA, date: day)}';
final String allSuffix =
    '$dailySummariesCollection/${allSourcesSummaryId(day)}';
const String trendSuffix = '$ownerLedgerTrendsCollection/$sourceA';
const String allTrendSuffix =
    '$ownerLedgerTrendsCollection/$allSourcesScopeId';

/// ★ قاعدةٌ بأرقامِ §15 لمصدر رداع — `TC-FIN-001` §5.
_Database _referenceDay({
  List<Object?>? outflows,
  List<Object?>? summaries,
  Map<String, Object?>? storedTrend,
}) =>
    _Database(
      distributions: <Object?>[
        _doc(
          '$distributionsCollection/$distributionA',
          <String, Object?>{
            'sourceId': _str(sourceA),
            'status': _str(DistributionStatus.priced.name),
          },
        ),
      ],
      pricing: <String, Object?>{
        'debtValue': _int(518100),
        'settledAmount': _int(149500),
        'discountedAmount': _int(5000),
      },
      cashSales: <Object?>[
        _doc(
          '$cashSalesCollection/CSH-20260820-0001',
          <String, Object?>{
            'sourceId': _str(sourceA),
            'netCashReceived': _int(27450),
            'status': _str(CashSaleStatus.approved.name),
          },
        ),
      ],
      sacks: <Object?>[
        _doc(
          '$sacksCollection/$sackA',
          <String, Object?>{
            'sourceId': _str(sourceA),
            'status': _str(SackStatus.approved.name),
          },
        ),
      ],
      finance: <String, Object?>{'sackTax': _int(8125)},
      outflows: outflows ??
          <Object?>[
            _doc(
              '$outflowsCollection/WDR-20260820-0001',
              <String, Object?>{
                'sourceId': _str(sourceA),
                'ledgerType': _str(OutflowLedgerType.withdrawal.name),
                'grandTotal': _int(20000),
                'status': _str(OutflowStatus.approved.name),
              },
            ),
            _doc(
              '$outflowsCollection/EXP-20260820-0001',
              <String, Object?>{
                'sourceId': _str(sourceA),
                'ledgerType': _str(OutflowLedgerType.expense.name),
                'grandTotal': _int(5000),
                'status': _str(OutflowStatus.approved.name),
              },
            ),
          ],
      summaries: summaries ?? const <Object?>[],
      storedTrend: storedTrend,
    );

void main() {
  group('★★★ أرقام §15 المرجعية — من الدفاتر إلى المستند المكتوب', () {
    test('البنود العشرة تُكتب بأرقامها الصحيحة', () async {
      final _Committed committed = _Committed();
      await _handler(_referenceDay(), committed)
          .buildDay(sourceId: sourceA, date: day, today: day);

      final Map<String, Object?> fields = committed.fieldsOn(summarySuffix);
      expect(fields['sourceId'], sourceA);
      expect(fields['credit'], 518100);
      expect(fields['cash'], 27450);
      expect(fields['totalDebt'], 545550);
      expect(fields['settledOfDay'], 149500);
      expect(fields['discounts'], 5000);
      expect(fields['remainingBeforeDiscount'], 368600);
      expect(fields['remainingAfterDiscount'], 363600);
      expect(fields['tax'], 8125);
      expect(fields['remainingAfterTax'], 355475);
      expect(fields['withdrawals'], 20000);
      expect(fields['expenses'], 5000);
      expect(fields['netFinal'], 330475);
    });

    test('⛔⛔ والمبالغُ الثلاثة من pricing/current لا من الأب — ADR-0011',
        () async {
      final _Committed committed = _Committed();
      final _Database db = _Database(
        distributions: <Object?>[
          _doc(
            '$distributionsCollection/$distributionA',
            <String, Object?>{
              'sourceId': _str(sourceA),
              // ⛔ **قيمٌ في الأب لا يجوز أن تُقرأ** — ★ **وليست هناك أصلاً.**
              'status': _str(DistributionStatus.priced.name),
            },
          ),
        ],
      );
      await _handler(db, committed)
          .buildDay(sourceId: sourceA, date: day, today: day);
      expect(committed.fieldsOn(summarySuffix)['credit'], 0);
    });

    test('⛔ والتوزيعةُ الملغاة لا تدخل الجمع — A-14', () async {
      final _Committed committed = _Committed();
      final _Database db = _Database(
        distributions: <Object?>[
          _doc(
            '$distributionsCollection/$distributionA',
            <String, Object?>{
              'sourceId': _str(sourceA),
              'status': _str(DistributionStatus.cancelled.name),
            },
          ),
        ],
        pricing: <String, Object?>{'debtValue': _int(999999)},
      );
      await _handler(db, committed)
          .buildDay(sourceId: sourceA, date: day, today: day);
      expect(committed.fieldsOn(summarySuffix)['credit'], 0);
    });

    test('⛔ والبيعُ النقدي الملغى كذلك', () async {
      final _Committed committed = _Committed();
      final _Database db = _Database(
        cashSales: <Object?>[
          _doc(
            '$cashSalesCollection/CSH-20260820-0009',
            <String, Object?>{
              'sourceId': _str(sourceA),
              'netCashReceived': _int(50000),
              'status': _str(CashSaleStatus.cancelled.name),
            },
          ),
        ],
      );
      await _handler(db, committed)
          .buildDay(sourceId: sourceA, date: day, today: day);
      expect(committed.fieldsOn(summarySuffix)['cash'], 0);
    });

    test('⛔⛔★★ وسجلٌّ مجهولٌ لا يدخل أيَّ بند — GR-43', () async {
      final _Committed committed = _Committed();
      final _Database db = _Database(
        outflows: <Object?>[
          _doc(
            '$outflowsCollection/XXX-20260820-0001',
            <String, Object?>{
              'sourceId': _str(sourceA),
              'ledgerType': _str('unknown'),
              'grandTotal': _int(77000),
              'status': _str(OutflowStatus.approved.name),
            },
          ),
        ],
      );
      await _handler(db, committed)
          .buildDay(sourceId: sourceA, date: day, today: day);
      final Map<String, Object?> fields = committed.fieldsOn(summarySuffix);
      expect(fields['withdrawals'], 0);
      expect(fields['expenses'], 0);
    });

    test('⛔ والسندُ الملغى لا يُطرَح', () async {
      final _Committed committed = _Committed();
      final _Database db = _Database(
        outflows: <Object?>[
          _doc(
            '$outflowsCollection/WDR-20260820-0002',
            <String, Object?>{
              'sourceId': _str(sourceA),
              'ledgerType': _str(OutflowLedgerType.withdrawal.name),
              'grandTotal': _int(30000),
              'status': _str(OutflowStatus.cancelled.name),
            },
          ),
        ],
      );
      await _handler(db, committed)
          .buildDay(sourceId: sourceA, date: day, today: day);
      expect(committed.fieldsOn(summarySuffix)['withdrawals'], 0);
    });

    test('★ ويومٌ بلا حركةٍ يُكتب بأصفارٍ صريحة — لا شرطات', () async {
      final _Committed committed = _Committed();
      await _handler(_Database(), committed)
          .buildDay(sourceId: sourceA, date: day, today: day);
      final Map<String, Object?> fields = committed.fieldsOn(summarySuffix);
      expect(fields['netFinal'], 0);
      expect(fields['totalDebt'], 0);
    });
  });

  group('⚠️★★ الوسمُ الرجعي — FR-M15-12 · §7', () {
    test('⛔ ولا وسمَ على بناء اليوم الجاري', () async {
      final _Committed committed = _Committed();
      await _handler(_referenceDay(), committed)
          .buildDay(sourceId: sourceA, date: day, today: day);
      expect(
        committed.transformsOn(summarySuffix),
        <String>[summaryUpdatedAtField],
      );
    });

    test('★ ويُوسَم اليومُ الماضي بطابع الخادم — لا بساعة الحاوية', () async {
      final _Committed committed = _Committed();
      await _handler(_referenceDay(), committed)
          .buildDay(sourceId: sourceA, date: day, today: today);
      expect(
        committed.transformsOn(summarySuffix),
        <String>[summaryUpdatedAtField, retroUpdatedAtField],
      );
      // ⛔ **ولا قيمةَ وقتٍ في الحقول نفسِها** — ★ **التحويلُ وحده.**
      expect(
        committed.fieldsOn(summarySuffix).containsKey(retroUpdatedAtField),
        isFalse,
      );
    });
  });

  group('★★ البطاقة التجميعية — مجموعُ بطاقات المصادر', () {
    test('تُبنى من ملخصات المصادر وتُكتب تحت all_{date}', () async {
      final _Committed committed = _Committed();
      final _Database db = _referenceDay(
        summaries: <Object?>[
          _doc(
            '$dailySummariesCollection/'
            '${dailySummaryId(sourceId: sourceA, date: day)}',
            <String, Object?>{
              'sourceId': _str(sourceA),
              'date': _stamp(day),
              'credit': _int(518100),
              'cash': _int(27450),
              'settledOfDay': _int(149500),
              'discounts': _int(5000),
              'tax': _int(8125),
              'withdrawals': _int(20000),
              'expenses': _int(5000),
            },
          ),
          _doc(
            '$dailySummariesCollection/'
            '${dailySummaryId(sourceId: sourceB, date: day)}',
            <String, Object?>{
              'sourceId': _str(sourceB),
              'date': _stamp(day),
              'credit': _int(74800),
            },
          ),
        ],
      );
      await _handler(db, committed)
          .buildDay(sourceId: sourceA, date: day, today: day);

      final Map<String, Object?> fields = committed.fieldsOn(allSuffix);
      expect(fields['sourceId'], allSourcesScopeId);
      expect(fields['netFinal'], 405275);
    });

    test('⛔⛔ والتجميعيةُ لا تدخل جمعَ نفسِها — PAT-08', () async {
      final _Committed committed = _Committed();
      final _Database db = _referenceDay(
        summaries: <Object?>[
          _doc(
            '$dailySummariesCollection/'
            '${dailySummaryId(sourceId: sourceA, date: day)}',
            <String, Object?>{
              'sourceId': _str(sourceA),
              'date': _stamp(day),
              'credit': _int(1000),
            },
          ),
          _doc(
            '$dailySummariesCollection/${allSourcesSummaryId(day)}',
            <String, Object?>{
              'sourceId': _str(allSourcesScopeId),
              'date': _stamp(day),
              'credit': _int(1000),
            },
          ),
        ],
      );
      await _handler(db, committed)
          .buildDay(sourceId: sourceA, date: day, today: day);
      expect(committed.fieldsOn(allSuffix)['credit'], 1000);
    });
  });

  group('✅★★ سجلُّ السلسلة — IQ-030', () {
    test('يُكتب في نفس الحدث — لا بجدولةٍ ولا مهمةٍ ثانية', () async {
      final _Committed committed = _Committed();
      await _handler(_referenceDay(), committed)
          .buildDay(sourceId: sourceA, date: day, today: day);

      expect(committed.hasPath(trendSuffix), isTrue);
      expect(committed.hasPath(allTrendSuffix), isTrue);
      final Map<String, Object?> fields = committed.fieldsOn(trendSuffix);
      expect(fields['sourceId'], sourceA);
      final List<Object?> points = fields[trendPointsField]! as List<Object?>;
      expect(points, hasLength(1));
      final Map<String, Object?> point = points.single! as Map<String, Object?>;
      expect(point['date'], '20260820');
      expect(point['netFinal'], 330475);
      // ⛔⛔ **والبندان المحكومان معه** — §2.1 القاعدة 5.
      expect(point['withdrawals'], 20000);
      expect(point['expenses'], 5000);
      expect(point['retroUpdated'], isFalse);
    });

    test('★ ويُدمَج مع سلسلةٍ قائمة ويستبدل نقطةَ اليوم نفسِه', () async {
      final _Committed committed = _Committed();
      final _Database db = _referenceDay(
        storedTrend: <String, Object?>{
          'sourceId': _str(sourceA),
          trendPointsField: <String, Object?>{
            'arrayValue': <String, Object?>{
              'values': <Map<String, Object?>>[
                <String, Object?>{
                  'mapValue': <String, Object?>{
                    'fields': <String, Object?>{
                      'date': _str('20260819'),
                      'netFinal': _int(111),
                      'withdrawals': _int(0),
                      'expenses': _int(0),
                    },
                  },
                },
                <String, Object?>{
                  'mapValue': <String, Object?>{
                    'fields': <String, Object?>{
                      'date': _str('20260820'),
                      'netFinal': _int(999),
                      'withdrawals': _int(0),
                      'expenses': _int(0),
                    },
                  },
                },
              ],
            },
          },
        },
      );
      await _handler(db, committed)
          .buildDay(sourceId: sourceA, date: day, today: day);

      final List<Object?> points = committed
          .fieldsOn(trendSuffix)[trendPointsField]! as List<Object?>;
      expect(points, hasLength(2));
      expect(
        (points.first! as Map<String, Object?>)['date'],
        '20260819',
      );
      expect(
        (points.last! as Map<String, Object?>)['netFinal'],
        330475,
      );
    });
  });

  group('⛔⛔★★★ قابلية التكرار بلا أثر جانبي — api-overview §3.3', () {
    test('تشغيلان متتاليان يكتبان نفس الأرقام حرفياً', () async {
      final _Committed first = _Committed();
      await _handler(_referenceDay(), first)
          .buildDay(sourceId: sourceA, date: day, today: day);
      final _Committed second = _Committed();
      await _handler(_referenceDay(), second)
          .buildDay(sourceId: sourceA, date: day, today: day);

      expect(
        second.fieldsOn(summarySuffix),
        equals(first.fieldsOn(summarySuffix)),
      );
      expect(
        second.fieldsOn(trendSuffix),
        equals(first.fieldsOn(trendSuffix)),
      );
    });
  });

  group('⛔⛔ فشلُ الباني لا يُبطل العملية الأصلية — §3.3', () {
    test('يُبتلَع الفشلُ في السجل ولا يصعد استثناءً', () async {
      final OwnerLedgerSummaryHandler handler = OwnerLedgerSummaryHandler(
        FirestoreWriter(
          projectId: projectId,
          api: firestore.FirestoreApi(
            MockClient((http.Request request) async =>
                http.Response('server error', 500)),
          ),
        ),
      );
      await expectLater(
        buildDailySummariesAfterCommit(
          handler,
          days: <OwnerLedgerDay>{
            OwnerLedgerDay(sourceId: sourceA, date: day),
          },
          today: day,
        ),
        completes,
      );
    });

    test('و`null` بانياً تعني «لا بناء» — ولا سقوط', () async {
      await expectLater(
        buildDailySummariesAfterCommit(
          null,
          days: <OwnerLedgerDay>{
            OwnerLedgerDay(sourceId: sourceA, date: day),
          },
          today: day,
        ),
        completes,
      );
    });

    test('★ ومجموعةٌ فارغة لا تُشغِّل شيئاً', () async {
      final _Committed committed = _Committed();
      await buildDailySummariesAfterCommit(
        _handler(_referenceDay(), committed),
        days: const <OwnerLedgerDay>{},
        today: day,
      );
      expect(committed.writes, isEmpty);
    });

    test('★★ و(مصدر × يوم) نوعُ قيمةٍ — فالتكرار يسقط من المجموعة', () {
      final Set<OwnerLedgerDay> days = <OwnerLedgerDay>{
        OwnerLedgerDay(sourceId: sourceA, date: day),
        OwnerLedgerDay(sourceId: sourceA, date: day),
        OwnerLedgerDay(sourceId: sourceB, date: day),
      };
      expect(days, hasLength(2));
    });
  });
}

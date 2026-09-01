/// ⛔⛔★★★ **اختبارُ ارتدادٍ لـ`DEBT-77`** — **سندُ مبالغَ خالصٍ بلا استعلامٍ واحد**.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **ولماذا على `OutflowHandler` لا على `planOutflow`:**
/// ★ **`planOutflow` دالةٌ خالصة تستقبل `today` جاهزاً** ⛔ **ولا تمرّ بطبقة
/// القراءة أصلاً** — ⟵ **وهذا بالضبط سببُ أن 2069 اختباراً لم تكشف العطل**
/// (`DEBT-37` عاشرَ مرة). ★ **فالعطلُ كان بين الطبقتين لا داخل إحداهما:**
/// **سندٌ بلا `qatLines` ⟹ لا `inventoryLedgerQuery` ⟹ `queries` فارغة ⟹
/// `TransactionReads.readTime == null` ⟹ `platformDayOf` تردّ `null` ⟹
/// `AbortTransaction(internal)` ⟹ `ERR_CALL_500`.**
///
/// ⛔⛔ **ولا استعلامَ صوريّ في `outflow_handler` عِلاجاً** — ★ **العلاجُ في
/// `audited_transaction.dart`**: **`readTime` يُملأ من `batchGet` كذلك.**
/// ⟵ **ولذلك يفحص هذا الاختبار أن `runQuery` لم يُستدعَ ولا مرّة**، ★ **فلو
/// عاد أحدٌ فأضاف استعلاماً صورياً لَسقط الاختبار** ⛔ **ولم يمرّ صامتاً.**
/// ═══════════════════════════════════════════════════════════════════════
library;

import 'dart:convert';

import 'package:googleapis/firestore/v1.dart' as firestore;
import 'package:googleapis/identitytoolkit/v3.dart' as idtk;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:qtms_domain/qtms_domain.dart';
import 'package:qtms_functions/src/audited_transaction.dart';
import 'package:qtms_functions/src/identity_gateway.dart';
import 'package:qtms_functions/src/outflow.dart';
import 'package:qtms_functions/src/outflow_handler.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

const String projectId = 'demo-qtms';
const String actorUid = 'uid-owner';
const String sourceA = 'SRC-001';

/// ★ **زمنُ المنصّة المُعلَن** — ⛔ **ولا يُقرأ من ساعة الحاوية** (`GR-54`).
const String platformReadTime = '2026-09-01T10:15:30.000000Z';

/// ★ كل مفاتيح السحبيات — **فالاختبار عن القراءة لا عن التفويض**.
const Set<Permission> withdrawalPermissions = <Permission>{
  Permission.withdrawalCreate,
  Permission.withdrawalAmend,
  Permission.withdrawalCancel,
  Permission.withdrawalQatPriceNow,
  Permission.withdrawalBackdate,
};

/// سجلُّ ما لمسته الشبكةُ فعلاً — ★ **ليُفحَص ما لم يُستدعَ كذلك**.
final class _Calls {
  final List<String> paths = <String>[];

  bool get ranQuery => paths.any((String p) => p.contains(':runQuery'));

  int get batchGets => paths.where((String p) => p.contains(':batchGet')).length;

  int get commits => paths.where((String p) => p.contains(':commit')).length;
}

http.Response _json(Object? body) => http.Response(
      jsonEncode(body),
      200,
      headers: <String, String>{
        'content-type': 'application/json; charset=utf-8',
      },
    );

/// عميلٌ مزيّف يردّ على المصادقة وعلى Firestore معاً — ⛔ **بلا أي شبكة**.
MockClient _client(_Calls calls) => MockClient((http.Request request) async {
      final String url = request.url.toString();
      calls.paths.add(url);

      if (url.contains('identitytoolkit')) {
        return _json(<String, Object?>{
          'users': <Object?>[
            <String, Object?>{
              'localId': actorUid,
              'displayName': 'مالك النظام',
              // ★ النطاق من الرمز — والصلاحيات من البطاقة (`ADR-0016`).
              'customAttributes': jsonEncode(<String, Object?>{
                sourceScopeClaimKey: allSourcesClaimValue,
              }),
              'disabled': false,
            },
          ],
        });
      }

      if (url.contains(':beginTransaction')) {
        return _json(<String, Object?>{'transaction': 'tx-debt77'});
      }

      if (url.contains(':batchGet')) {
        final Map<String, Object?> body =
            jsonDecode(request.body) as Map<String, Object?>;
        final List<Object?> documents = body['documents']! as List<Object?>;
        return _json(<Object?>[
          for (final Object? raw in documents)
            if ((raw! as String).contains('/$sourcesCollection/'))
              <String, Object?>{
                'readTime': platformReadTime,
                'found': <String, Object?>{
                  'name': raw,
                  'fields': <String, Object?>{
                    'name': <String, Object?>{'stringValue': 'المصدر الأول'},
                    'isActive': <String, Object?>{'booleanValue': true},
                  },
                },
              }
            else
              // ★★ **وحتى الغائبُ يحمل زمناً** — ⟵ **وهو حالُ العدّاد أولَ يوم.**
              <String, Object?>{'readTime': platformReadTime, 'missing': raw},
        ]);
      }

      if (url.contains(':commit')) {
        return _json(<String, Object?>{'writeResults': <Object?>[]});
      }
      if (url.contains(':rollback')) return _json(<String, Object?>{});

      // ⛔ **أي مسارٍ آخر — ومنه `runQuery` — عطلٌ صريح لا صمت.**
      return http.Response('مسارٌ غير متوقَّع: $url', 500);
    });

OutflowHandler _handler(_Calls calls) {
  final MockClient client = _client(calls);
  return OutflowHandler(
    identity: IdentityGateway(
      api: idtk.IdentityToolkitApi(client),
      readUserCard: (String userId) async => const UserCardSnapshot(
        permissions: withdrawalPermissions,
        isActiveField: true,
      ),
    ),
    transaction: AuditedTransaction(
      projectId: projectId,
      api: firestore.FirestoreApi(client),
    ),
    // ★ ساعةُ الاقتراح وحدها — والحَكَمُ زمنُ المنصّة أعلاه.
    clock: () => DateTime.utc(2026, 9, 1, 10, 15, 30),
  );
}

Request _createRequest(Map<String, Object?> data) => Request(
      'POST',
      Uri.parse('https://callables.test/createOutflow'),
      headers: <String, String>{
        'authorization': 'Bearer id-token',
        'content-type': 'application/json',
      },
      body: jsonEncode(<String, Object?>{'data': data}),
    );

void main() {
  group('⛔⛔ DEBT-77 — سندٌ بمبالغَ فقط بلا استعلامٍ واحد', () {
    test('★★★ يُنشَأ ويعيد رقمَه ⛔ ولا يسقط بـERR_CALL_500', () async {
      final _Calls calls = _Calls();

      final Response response = await _handler(calls).handle(
        _createRequest(<String, Object?>{
          'requestId': 'req-debt77-1',
          'sourceId': sourceA,
          'ledgerType': OutflowLedgerType.withdrawal.name,
          'category': OutflowCategory.withdrawalCash.name,
          'date': '20260901',
          // ⛔⛔★★★ **بلا بندِ قاتٍ واحد** — ★ **وهو المتغيّرُ الوحيد.**
          'cashLines': <Object?>[
            <String, Object?>{
              'kind': OutflowLineKind.amount.name,
              'amount': 2000,
            },
          ],
        }),
        OutflowOperation.createOutflow,
      );

      final String body = await response.readAsString();
      expect(response.statusCode, 200, reason: 'الجسم: $body');

      final Map<String, Object?> decoded =
          jsonDecode(body) as Map<String, Object?>;
      final Map<String, Object?> result =
          decoded['result']! as Map<String, Object?>;
      expect(result['documentNumber'], 'WDR-20260901-0001');
      expect(result['documentDate'], '20260901');
      // ★★★ **ويومُ المخزون من زمنِ المنصّة** — ⛔ **لا من ساعة الحاوية.**
      expect(result['stockDate'], '20260901');

      // ⛔⛔★★★ **ولا استعلامَ واحداً** — ★ **وهذا شرطُ العطل نفسُه:**
      //    ⟵ **فلو مرّ الاختبار باستعلامٍ صوريّ لَما أثبت شيئاً.**
      expect(calls.ranQuery, isFalse);
      expect(calls.batchGets, 1);
      expect(calls.commits, 1);
    });

    test('★★ وزمنُ المنصّة يصل من قراءة المستندات وحدها', () async {
      final _Calls calls = _Calls();
      DateTime? observed;

      await AuditedTransaction(
        projectId: projectId,
        api: firestore.FirestoreApi(_client(calls)),
      ).run<void>(
        readPaths: <String>[
          'projects/$projectId/databases/(default)/documents/'
              '$sourcesCollection/$sourceA',
        ],
        plan: (TransactionReads reads) {
          observed = reads.readTime;
          return AuditedWrite<void>(
            documents: const <PendingDocument>[],
            auditOnly: true,
            entry: AuditEntry(
              id: 'AUD-debt77',
              action: AuditAction.export,
              actor: AuditActor(userId: actorUid, userName: 'مالك النظام'),
              target: AuditTarget(
                entityType: 'outflows',
                entityId: 'WDR-20260901-0001',
              ),
              occurredAt: DateTime.utc(2026, 9, 1),
            ),
            result: null,
          );
        },
      );

      expect(observed, isNotNull);
      expect(observed, DateTime.parse(platformReadTime).toUtc());
      expect(calls.ranQuery, isFalse);
    });
  });
}

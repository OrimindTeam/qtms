/// مستودع تسجيل التصدير — ★ **الحمولة والمسار**، ⛔ **بلا شبكة**.
///
/// ⚠️⚠️ **وما يُثبته:** أن **المسار `logExport` حرفياً** (⟵ **والموجّه لا
/// يتسامح مع حالة الأحرف** — `IQ-019` القاعدة ②)، وأن **الحمولة تحمل ما
/// تقرؤه العملية بالضبط** (`api-overview.md` §3.1-ط)، وأن **الرفض يعبر
/// خطأً مصنَّفاً لا استثناءً**.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:qtms/capabilities/oversight/infrastructure/functions_export_log_repository.dart';
import 'package:qtms/core/callable/callable_client.dart';
import 'package:qtms_domain/qtms_domain.dart';

final class FakeHttp extends http.BaseClient {
  FakeHttp(this.status, this.body);

  final int status;
  final String body;

  http.BaseRequest? lastRequest;
  List<int> lastBody = const <int>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    lastRequest = request;
    lastBody = await request.finalize().toBytes();
    return http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode(body)),
      status,
    );
  }
}

FunctionsExportLogRepository repository(http.Client client) =>
    FunctionsExportLogRepository(
      client: CallableClient(
        httpClient: client,
        readIdToken: () async => 'ID-TOKEN',
        baseUrl: 'https://example.invalid',
      ),
      newRequestId: () => 'req-1',
    );

Map<String, Object?> payloadOf(FakeHttp fake) =>
    (jsonDecode(utf8.decode(fake.lastBody)) as Map<String, Object?>)['data']!
        as Map<String, Object?>;

void main() {
  group('★ المسار والحمولة', () {
    test('★★ المسار `logExport` حرفياً — ⛔ ولا يُطبَّع حرفٌ منه', () async {
      final FakeHttp fake = FakeHttp(
        200,
        jsonEncode(<String, Object?>{'result': <String, Object?>{}}),
      );

      await repository(fake).logExport(
        sourceId: 'SRC-001',
        entityType: receiptEntityType,
        entityId: 'RCP-20260830-0007',
        format: ExportedFormat.pdf,
        documentNumber: 'RCP-20260830-0007',
      );

      expect(fake.lastRequest!.url.path, '/logExport');
    });

    test('★ والحمولة تحمل ما تقرؤه العملية بالضبط', () async {
      final FakeHttp fake = FakeHttp(
        200,
        jsonEncode(<String, Object?>{'result': <String, Object?>{}}),
      );

      await repository(fake).logExport(
        sourceId: 'SRC-001',
        entityType: distributionEntityType,
        entityId: 'MQT-0001_SRC-001_20260830',
        format: ExportedFormat.pdf,
      );

      expect(payloadOf(fake), <String, Object?>{
        'requestId': 'req-1',
        'sourceId': 'SRC-001',
        'entityType': 'distribution',
        'entityId': 'MQT-0001_SRC-001_20260830',
        'exportFormat': 'pdf',
        // ⛔★ **ورقمُ المستند يسقط حين يغيب** — ★ **ولا يُرسَل `null` صراحةً.**
      });
    });

    test('★ ورقم المستند يُرسَل حين يوجد', () async {
      final FakeHttp fake = FakeHttp(
        200,
        jsonEncode(<String, Object?>{'result': <String, Object?>{}}),
      );

      await repository(fake).logExport(
        sourceId: 'SRC-001',
        entityType: receiptEntityType,
        entityId: 'RCP-20260830-0007',
        format: ExportedFormat.pdf,
        documentNumber: 'RCP-20260830-0007',
      );

      expect(payloadOf(fake)['documentNumber'], 'RCP-20260830-0007');
    });

    test('★★ وقيمة الصيغة نظيرةُ `ExportFormat` في السحابة حرفياً', () async {
      // ⚠️ **نسختان بالضرورة لا بالسهو** — ★ **`functions/` حزمةٌ لا يعتمد
      //    عليها التطبيق**، ⟵ **والقيمة النصّية هي العقد بينهما.**
      expect(ExportedFormat.pdf.wireName, 'pdf');
      expect(ExportedFormat.values, hasLength(1));
    });
  });

  group('⛔ الرفض يعبر خطأً مصنَّفاً', () {
    test('★ 403 ⟵ `PermissionError` — ⛔ ولا استثناء', () async {
      final FakeHttp fake = FakeHttp(
        403,
        jsonEncode(<String, Object?>{
          'error': <String, Object?>{
            'status': 'PERMISSION_DENIED',
            'message': 'ERR_AUTH_001',
            'details': <String, Object?>{'code': 'ERR_AUTH_001'},
          },
        }),
      );

      final Outcome<void> outcome = await repository(fake).logExport(
        sourceId: 'SRC-001',
        entityType: receiptEntityType,
        entityId: 'RCP-1',
        format: ExportedFormat.pdf,
      );

      expect(outcome, isA<Failure<void>>());
      expect((outcome as Failure<void>).error, isA<PermissionError>());
    });
  });
}

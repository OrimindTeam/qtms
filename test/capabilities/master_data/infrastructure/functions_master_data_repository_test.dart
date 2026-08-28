/// حمولة عمليات البيانات المرجعية — ★★ **ما تُرسله الواجهة وما لا ترسله**.
///
/// ⚠️⚠️ **ولماذا اختبارٌ على الحمولة نفسها لا على النتيجة:** بعد إغلاق
/// الكتابة المباشرة، **الحمولةُ هي كل ما يصل السحابة** — ⟵ **وحقلٌ يتسلل
/// فيها يتجاوز نيّة المتطلب بلا أن يظهر في أي شاشة**: `unit` مشتقّة
/// (`FR-M5-03`) · `isSystemDefault` سحابيّ (`FR-M5-05`) · **وأي حقل سعر
/// مرفوض** (`FR-M5-09`) · و`decimalPlaces` صفرٌ حتماً (`ADR-0015`).
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:qtms/capabilities/master_data/infrastructure/functions_master_data_repository.dart';
import 'package:qtms/core/callable/callable_client.dart';
import 'package:qtms_domain/qtms_domain.dart';

/// عميل HTTP مزيّف — يسجّل المسار والحمولة ويردّ نجاحاً.
final class _FakeHttp extends http.BaseClient {
  _FakeHttp(this.body);

  final String body;

  String? lastPath;
  Map<String, Object?>? lastData;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    lastPath = request.url.path;
    final String raw = await (request as http.Request).finalize().bytesToString();
    final Object? decoded = jsonDecode(raw);
    if (decoded is Map<String, Object?> &&
        decoded['data'] is Map<String, Object?>) {
      lastData = decoded['data']! as Map<String, Object?>;
    }
    return http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode(body)),
      200,
    );
  }
}

(FunctionsMasterDataRepository, _FakeHttp) repository({String result = '{}'}) {
  final _FakeHttp fake = _FakeHttp('{"result": $result}');
  return (
    FunctionsMasterDataRepository(
      client: CallableClient(
        httpClient: fake,
        readIdToken: () async => 'ID-TOKEN',
        baseUrl: 'https://example.invalid',
      ),
      newRequestId: () => 'REQ-FIXED',
    ),
    fake,
  );
}

ValidatedItem countItem() => (validateItem(
      const ItemInput(
        sourceIds: <String>['SRC-001'],
        name: 'عود',
        nature: ItemNature.countBased,
      ),
    ) as Success<ValidatedItem>)
        .value;

void main() {
  test('★★ FR-M5: حمولة النوع بلا `unit` ولا `isSystemDefault` ولا سعر', () async {
    final (FunctionsMasterDataRepository repo, _FakeHttp fake) =
        repository(result: '{"itemId": "ITM-0002"}');
    await repo.createItem(countItem());

    expect(fake.lastPath, '/createItem');
    final Map<String, Object?> data = fake.lastData!;
    expect(data['name'], 'عود');
    expect(data['nature'], 'countBased');
    // ⛔★★ الحقول التي لا تُرسَل — وكلٌّ منها بمتطلبه.
    expect(data.containsKey('unit'), isFalse, reason: 'FR-M5-03');
    expect(data.containsKey('isSystemDefault'), isFalse, reason: 'FR-M5-05');
    for (final String forbidden in forbiddenItemFields) {
      expect(
        data.keys.map((String k) => k.toLowerCase()).contains(forbidden),
        isFalse,
        reason: 'FR-M5-09 — الحقل «$forbidden»',
      );
    }
    // ⛔ ووزن الحبة لا يُرسَل للعددي — `E-09`.
    expect(data.containsKey('pieceWeightGrams'), isFalse);
  });

  test('★★ ولا `normalizedName` يُرسَل — التطبيع يُعاد في السحابة', () async {
    final (FunctionsMasterDataRepository repo, _FakeHttp fake) =
        repository(result: '{"sourceId": "SRC-001"}');
    final ValidatedSource source = (validateSource(
      const SourceInput(name: 'رداع', requiresSupplierOnIntake: true),
    ) as Success<ValidatedSource>)
        .value;
    await repo.createSource(source);

    final Map<String, Object?> data = fake.lastData!;
    expect(data.containsKey('normalizedName'), isFalse);
    expect(data['requiresSupplierOnIntake'], true);
    // ★ ومعرّف الطلب هو معرّف قيد التدقيق — `api-overview.md` §4.
    expect(data['requestId'], 'REQ-FIXED');
  });

  test('⛔★★ ولا حقل مصدر في حمولة المقوت — FR-M4-04 · ADR-0005', () async {
    final (FunctionsMasterDataRepository repo, _FakeHttp fake) =
        repository(result: '{"dealerId": "MQT-0001"}');
    final ValidatedDealer dealer = (validateDealer(
      const DealerInput(name: 'مقوت مثال', phone: '0777123456'),
    ) as Success<ValidatedDealer>)
        .value;
    await repo.createDealer(dealer);

    final Map<String, Object?> data = fake.lastData!;
    expect(data.containsKey('sourceId'), isFalse);
    expect(data.containsKey('sourceIds'), isFalse);
    // ★ والهاتف يُرسَل كما كتبه المستخدم — والتطبيع مفتاحُ تفرّدٍ لا حقلُ عرض.
    expect(data['phone'], '0777123456');
    expect(data.containsKey('normalizedPhone'), isFalse);
  });

  test('★★ ADR-0015: حمولة الإعداد التأسيسي بلا `decimalPlaces`', () async {
    final (FunctionsMasterDataRepository repo, _FakeHttp fake) = repository();
    final ValidatedAppSettings settings = (validateAppSettings(
      const AppSettingsInput(
        businessName: 'وكالة محمد المحامي',
        currencySymbol: 'ر.ي',
      ),
    ) as Success<ValidatedAppSettings>)
        .value;
    await repo.writeAppSettings(settings);

    expect(fake.lastPath, '/writeAppSettings');
    expect(fake.lastData!.containsKey('decimalPlaces'), isFalse);
    expect(fake.lastData!['currencySymbol'], 'ر.ي');
  });

  test('★★ وسبب التعديل يُرسَل في كل تعديل — ADR-0004 · DEBT-21 ①', () async {
    final (FunctionsMasterDataRepository repo, _FakeHttp fake) = repository();
    await repo.updateItem(
      itemId: 'ITM-0002',
      item: countItem(),
      amendReason: 'تصحيح الاسم',
    );
    expect(fake.lastPath, '/updateItem');
    expect(fake.lastData!['amendReason'], 'تصحيح الاسم');
    expect(fake.lastData!['itemId'], 'ITM-0002');
  });

  test('⚠️ ونجاحٌ بلا معرّف يُعامَل فشلاً ⛔ لا نجاحاً صامتاً', () async {
    final (FunctionsMasterDataRepository repo, _FakeHttp _) =
        repository(result: '{"unrelated": true}');
    final Outcome<String> outcome = await repo.createItem(countItem());
    expect(outcome, isA<Failure<String>>());
  });
}

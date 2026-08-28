/// عميل العمليات السحابية — ★ **بروتوكولاً وتصنيفَ فشلٍ**، ⛔ **بلا شبكة**.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:qtms/core/callable/callable_client.dart';
import 'package:qtms_domain/qtms_domain.dart';

/// عميل HTTP مزيّف — يسجّل الطلب ويردّ ما يُملى عليه.
final class _FakeHttp extends http.BaseClient {
  _FakeHttp(this.status, this.body);

  final int status;
  final String body;

  http.BaseRequest? lastRequest;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    lastRequest = request;
    return http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode(body)),
      status,
    );
  }
}

/// عميل يرمي عند الإرسال — يحاكي انقطاع الشبكة.
final class _BrokenHttp extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      throw const SocketExceptionStub();
}

/// بديل بسيط لاستثناء المقبس — ⛔ بلا اعتماد `dart:io` في اختبار ودجات.
final class SocketExceptionStub implements Exception {
  const SocketExceptionStub();
}

CallableClient client(
  http.Client http_, {
  String? token = 'ID-TOKEN',
  String baseUrl = 'https://example.invalid',
}) =>
    CallableClient(
      httpClient: http_,
      readIdToken: () async => token,
      baseUrl: baseUrl,
    );

String errorBody(String code) => jsonEncode(<String, Object?>{
      'error': <String, Object?>{
        'status': 'PERMISSION_DENIED',
        'message': code,
        'details': <String, Object?>{'code': code},
      },
    });

void main() {
  group('★ البروتوكول — نقلٌ حرفي لما تُجيبه السحابة', () {
    test('✅ 200 بحقل result يُقرأ نجاحاً', () async {
      final _FakeHttp fake = _FakeHttp(
        200,
        jsonEncode(<String, Object?>{
          'result': <String, Object?>{'userId': 'U-9'},
        }),
      );
      final Outcome<Map<String, Object?>> result =
          await client(fake).call('createUser', <String, Object?>{'a': 1});

      expect(result, isA<Success<Map<String, Object?>>>());
      expect((result as Success<Map<String, Object?>>).value['userId'], 'U-9');
    });

    test('★ ويُرسَل الرمز في ترويسة الاعتماد والحمولة تحت `data`', () async {
      final _FakeHttp fake = _FakeHttp(
        200,
        jsonEncode(<String, Object?>{'result': <String, Object?>{}}),
      );
      await client(fake).call('disableUser', <String, Object?>{'userId': 'U-2'});

      expect(fake.lastRequest?.headers['authorization'], 'Bearer ID-TOKEN');
      expect(fake.lastRequest?.url.path, '/disableUser');
      final String body = (fake.lastRequest! as http.Request).body;
      expect(jsonDecode(body), <String, Object?>{
        'data': <String, Object?>{'userId': 'U-2'},
      });
    });

    test('⛔★★ و200 بلا حقل result ليست نجاحاً', () async {
      // ⚠️ **حالةٌ حقيقية:** وسيطٌ أو بوابةٌ قد تُرجِع 200 بجسمٍ ليس جسمنا.
      //    ★ **والنجاح الكاذب هنا شاشةٌ تقول «حُفِظ» ولا شيء حُفِظ.**
      final _FakeHttp fake = _FakeHttp(200, '<html>proxy</html>');
      final Outcome<Map<String, Object?>> result =
          await client(fake).call('createUser', <String, Object?>{});

      expect(result, isA<Failure<Map<String, Object?>>>());
    });
  });

  group('★★ تصنيف الفشل — كل رمز إلى نوعه', () {
    Future<AppError> failureFor(String code) async {
      final Outcome<Map<String, Object?>> result =
          await client(_FakeHttp(403, errorBody(code)))
              .call('op', <String, Object?>{});
      return (result as Failure<Map<String, Object?>>).error;
    }

    test('★ الجلسة تُميَّز في النوع — فالموجّه يُعيد للدخول', () async {
      expect(await failureFor('ERR_AUTH_003'), isA<SessionError>());
      expect(await failureFor('ERR_AUTH_004'), isA<SessionError>());
    });

    test('★ والصلاحية كذلك', () async {
      expect(await failureFor('ERR_AUTH_001'), isA<PermissionError>());
      expect(await failureFor('ERR_AUTH_007'), isA<PermissionError>());
    });

    test('★ والتزامن كذلك', () async {
      expect(await failureFor('ERR_CONC_001'), isA<ConcurrencyError>());
    });

    test('★★ وما بقي يُنقَل برمزه ⛔ لا يُبتلَع', () async {
      // ⟵ **فرمزٌ يُضيفه الخادم غداً يصل الشاشة برسالة عامة لا بصمت.**
      final AppError error = await failureFor('ERR_AMEND_002');
      expect(error, isA<InfrastructureError>());
      expect((error as InfrastructureError).diagnostic, 'ERR_AMEND_002');
    });

    test('★ وجسمٌ بلا رمز مقروء يصير ERR_CALL_500', () async {
      final Outcome<Map<String, Object?>> result =
          await client(_FakeHttp(500, 'not json'))
              .call('op', <String, Object?>{});
      final AppError error = (result as Failure<Map<String, Object?>>).error;
      expect((error as InfrastructureError).diagnostic, 'ERR_CALL_500');
    });
  });

  group('⛔ الحرّاس قبل أي رحلة شبكة', () {
    test('★★ إعدادٌ ناقص ⟵ فشل ظاهر ⛔ لا عنوان مخمَّن', () async {
      final _FakeHttp fake = _FakeHttp(200, '{}');
      final Outcome<Map<String, Object?>> result =
          await client(fake, baseUrl: '  ').call('op', <String, Object?>{});

      expect(result, isA<Failure<Map<String, Object?>>>());
      // ★ **ولا طلب أُرسل أصلاً** — وهو ما يجعل الفشل ظاهراً لا صامتاً.
      expect(fake.lastRequest, isNull);
    });

    test('★ وبلا رمز دخول ⟵ جلسة لا نقصَ صلاحية', () async {
      // ★ **والتمييز عملي:** الأولى تُعالَج بإعادة دخول، والثانية برسالة منع.
      final _FakeHttp fake = _FakeHttp(200, '{}');
      final Outcome<Map<String, Object?>> result =
          await client(fake, token: null).call('op', <String, Object?>{});

      expect((result as Failure<Map<String, Object?>>).error, isA<SessionError>());
      expect(fake.lastRequest, isNull);
    });

    test('★★ وانقطاع الشبكة `ConnectivityError` ⛔ لا فشلاً عاماً', () async {
      // ⟵ **فيصل المستخدمَ نصُّ `ERR_CONN_001` الذي يُرشده لفحص اتصاله**،
      //   ⛔ لا «تعذّر إتمام العملية» التي لا تُرشده لشيء.
      final Outcome<Map<String, Object?>> result =
          await client(_BrokenHttp()).call('op', <String, Object?>{});

      expect(
        (result as Failure<Map<String, Object?>>).error,
        isA<ConnectivityError>(),
      );
    });
  });
}

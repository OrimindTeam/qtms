/// عميل العمليات السحابية — ★ **بروتوكولاً وتصنيفَ فشلٍ**، ⛔ **بلا شبكة**.
library;

import 'dart:async';
import 'dart:convert';

import 'package:fake_async/fake_async.dart';
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

/// عميل لا يردّ أبداً — ★ **يحاكي انقطاعاً صامتاً لا يرمي** (`DEBT-57`).
///
/// ⛔ **وهو الحالة الحقيقية:** ★ **قطعُ الواي‑فاي أثناء نداءٍ قائم لا يُنهي
/// المقبس** — ⟵ **فالنداء يعلق حتى مهلة نظام التشغيل** (دقائقُ أو أبداً).
final class _SilentHttp extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      Completer<http.StreamedResponse>().future;
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
  Duration timeout = callableTimeout,
}) =>
    CallableClient(
      httpClient: http_,
      readIdToken: () async => token,
      baseUrl: baseUrl,
      timeout: timeout,
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

  group('⛔⛔★★★ المهلة — `DEBT-57`', () {
    test('★★★ نداءٌ لا يردّ أبداً يُخفق بالمهلة ⛔ لا يعلق', () {
      // ⛅ **القياس الحيّ الذي أنشأ الديْن:** قطعُ الشبكة أثناء «حذف الدور»
      //   ⟵ **الأزرارُ تُعطَّل أربع دقائق بلا رسالة ولا مخرج**، ⛔ **ولم
      //   يستأنف النداءُ ولم يُخفق حتى أُعيد بناءُ الشاشة.**
      // ★★ **والحارس المكتوب كان يُخدَع:** `ConnectivityError` مكتوبةٌ منذ
      //   اليوم الأول ⛔ **ولم تُنادَ قطّ** — ⟵ **والمهلة هي ما يُنادِيها.**
      fakeAsync((FakeAsync async) {
        Outcome<Map<String, Object?>>? outcome;
        client(_SilentHttp(), timeout: const Duration(seconds: 20))
            .call('deleteRole', <String, Object?>{'roleId': 'R-1'})
            .then((Outcome<Map<String, Object?>> r) => outcome = r);

        // ⛔ **وقبل المهلة لا شيء** — ★ **فالانتظار انتظارٌ حقيقي.**
        async.elapse(const Duration(seconds: 19));
        expect(outcome, isNull);

        async.elapse(const Duration(seconds: 2));
        expect(
          (outcome! as Failure<Map<String, Object?>>).error,
          isA<ConnectivityError>(),
        );
      });
    });

    test('★ والمهلة المعتمدة 20 ثانية ⛔ لا أقل — إقلاعُ الحاوية البارد', () {
      expect(callableTimeout, const Duration(seconds: 20));
    });

    test('★ ونداءٌ يردّ قبل المهلة لا تمسّه', () {
      fakeAsync((FakeAsync async) {
        Outcome<Map<String, Object?>>? outcome;
        client(
          _FakeHttp(200, jsonEncode(<String, Object?>{'result': <String, Object?>{}})),
        ).call('op', <String, Object?>{}).then(
          (Outcome<Map<String, Object?>> r) => outcome = r,
        );

        async.elapse(const Duration(seconds: 1));
        expect(outcome, isA<Success<Map<String, Object?>>>());
      });
    });
  });
}

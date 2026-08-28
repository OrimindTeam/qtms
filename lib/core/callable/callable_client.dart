/// عميل العمليات السحابية المستدعاة — **الطرف الذي يتكلّم البروتوكول**.
///
/// ★ **نقلٌ حرفي للبروتوكول الذي تُجيبه `functions/lib/src/callable.dart`:**
///
/// ```text
/// الطلب  : POST · {"data": {...}} · Authorization: Bearer <رمز الدخول>
/// النجاح : 200 · {"result": {...}}
/// الفشل  : رمز HTTP مطابق · {"error": {"status", "message", "details"}}
/// ```
///
/// ⛔★★ **ولا نصّ عربي واحد هنا:** ما يعبر الشبكة **رمز الكتالوج وحده**
/// (`ERR_AUTH_001` …)، **وربطُه برسالته مسؤولية طبقة العرض**
/// (`error-handling-strategy.md` §3 القاعدة 2) — ⟵ `callableErrorMessage`.
///
/// ⚠️⚠️ **وهذا العميل ليس طبقةَ تفويض ولا يُفترَض فيه ذلك:** كل قرار تفويض
/// يُتَّخذ **في السحابة** (`ADR-0013` القاعدة 3)، وكل ما هنا **نقلُ رفضٍ
/// وقع هناك**. ⛔ **فإخفاء زرٍّ في الواجهة لا يُغني عن رفض السحابة** —
/// `RISK-02` · `ADR-0010` القاعدة 3.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:qtms_domain/qtms_domain.dart';

/// عنوان قاعدة خدمات العمليات — ★ **يُحقَن وقت البناء** ⛔ **ولا يُحفَر**.
///
/// ⚠️ **ومعرّفٌ لا سرّ** — تماماً كـ`QTMS_OWNER_UID` الذي ينصّ
/// `environments.md` §1.3 على أنه «معرّف لا سرّ». ⟵ **فلا يدخل
/// `secrets-management-policy.md`**، ويُمرَّر:
///
/// ```bash
/// flutter build apk --dart-define=QTMS_FUNCTIONS_BASE_URL=https://<الخدمة>
/// ```
///
/// ⛔ **والفراغ ليس افتراضاً صالحاً:** [CallableClient] يرفض كل استدعاء
/// حينها **برمز صريح** ⟵ **فبناءٌ بلا إعداد يفشل ظاهراً لا صامتاً.**
const String functionsBaseUrl =
    String.fromEnvironment('QTMS_FUNCTIONS_BASE_URL');

/// ⛔⛔★★★ **مهلة كل نداءٍ مستدعى — `DEBT-57`.**
///
/// ★ **ولماذا مهلةٌ صريحة أصلاً:** `http.post` **بلا مهلةٍ ينتظر مهلة نظام
/// التشغيل** — ⟵ **وهي دقائقُ أو لا تنتهي**: ⛔ **فقطعُ الشبكة أثناء نداءٍ
/// كاتب كان يُجمِّد الإجراء أبداً** (`_busy = true` بلا رسالة ولا مخرج)،
/// ★ **وقيسَ حيّاً أربع دقائق بلا إخفاق ولا استئناف.**
///
/// ⛔⛔★★ **والحارس المكتوب كان يُخدَع:** ★ **[ConnectivityError] مكتوبةٌ في
/// [CallableClient] منذ اليوم الأول** — ⟵ **ولم تكن تُنادى قطّ لأن النداء
/// لا يرمي**: ★ **والمهلة هي ما يجعله يرمي فيُبلَغ الحارس فعلاً.**
///
/// ⚠️ **و20 ثانية لا أقل:** ★ **إقلاعُ حاويةٍ باردة على Cloud Run يبلغ
/// عشرة ثوانٍ** (`DEBT-56` من زاويته) — ⟵ **فمهلةٌ أقصر تُخفق نداءً سليماً**،
/// ⛔ **وهو أسوأ من انتظارٍ قصير**: ★ **والمستخدم يرى رسالةً خلالها لا بعدها.**
///
/// ⛔ **ولا تُطبَّق على انتظار رمز الدخول** — ★ **قراءتُه محلية بلا شبكة.**
const Duration callableTimeout = Duration(seconds: 20);

/// مزوّد رمز الدخول الحالي — ★ **يُقرأ عند كل استدعاء** ⛔ لا يُخزَّن.
///
/// ⚠️ **ولماذا لكل استدعاء:** الرمز ينتهي، **والمخزَّن يصير منتهياً بلا
/// أن يعلم أحد** ⟵ فيفشل الاستدعاء برمز جلسة وهي قائمة فعلاً.
typedef IdTokenReader = Future<String?> Function();

/// عميل الاستدعاء.
final class CallableClient {
  /// ينشئ العميل بتبعياته — ★ **تُحقَن، فيُختبَر بلا شبكة**.
  const CallableClient({
    required http.Client httpClient,
    required IdTokenReader readIdToken,
    String baseUrl = functionsBaseUrl,
    Duration timeout = callableTimeout,
  })  : _http = httpClient,
        _readIdToken = readIdToken,
        _baseUrl = baseUrl,
        _timeout = timeout;

  final http.Client _http;
  final IdTokenReader _readIdToken;
  final String _baseUrl;
  final Duration _timeout;

  /// يستدعي [operation] بحمولة [data].
  ///
  /// ★ **يُرجِع نتيجةً ولا يرمي** — `error-handling-strategy.md` §3 القاعدة 3.
  Future<Outcome<Map<String, Object?>>> call(
    String operation,
    Map<String, Object?> data,
  ) async {
    if (_baseUrl.trim().isEmpty) {
      // ⛔ **إعدادٌ ناقص ⟵ فشل ظاهر** — ولا يُخمَّن عنوان ولا يُبتلَع.
      return const Failure<Map<String, Object?>>(
        InfrastructureError('QTMS_FUNCTIONS_BASE_URL غير مضبوط في هذا البناء'),
      );
    }

    final String? idToken = await _readIdToken();
    if (idToken == null || idToken.isEmpty) {
      // ★ غياب الرمز **جلسة لا مصادقة** لا نقصَ صلاحية — والتمييز عملي:
      //   الأولى تُعالَج بإعادة دخول، والثانية برسالة منع.
      return const Failure<Map<String, Object?>>(SessionError());
    }

    final http.Response response;
    try {
      response = await _http
          .post(
            Uri.parse('${_baseUrl.trimRight()}/$operation'),
            headers: <String, String>{
              'content-type': 'application/json; charset=utf-8',
              // ⛔ **الرمز سرّ فعلي** — لا يُسجَّل ولا يُكتب في أي حقل.
              'authorization': 'Bearer $idToken',
            },
            body: jsonEncode(<String, Object?>{'data': data}),
          )
          // ⛔⛔★★★ **المهلة الصريحة — `DEBT-57`:** ★ **بدونها لا يرمي
          //   النداء أبداً** ⟵ **فالسطر التالي مكتوبٌ لا يُنادى.**
          .timeout(_timeout);
    } on Object catch (_) {
      // ★ **انقطاع الشبكة `ConnectivityError` لا فشلاً عاماً** — ⟵ فيصل
      //   المستخدمَ نصُّ `ERR_CONN_001` الذي يُرشده لفحص اتصاله،
      //   ⛔ لا «تعذّر إتمام العملية» التي لا تُرشده لشيء.
      //   ⚠️ **والحفظ معطَّل أصلاً بلا اتصال** (`ADR-0003`).
      //   ★★ **و[TimeoutException] تدخل من هنا كذلك** — ⟵ **فانقطاعٌ
      //   صامت وانقطاعٌ رامٍ يصلان المستخدمَ بالنصّ نفسه**، ⛔ **ولا فرق
      //   عملي بينهما عنده: كلاهما «تحقق من الاتصال ثم أعد المحاولة».**
      return const Failure<Map<String, Object?>>(ConnectivityError());
    }

    return _readResponse(response);
  }

  Outcome<Map<String, Object?>> _readResponse(http.Response response) {
    final Object? decoded = _tryDecode(response.body);
    if (response.statusCode == 200) {
      if (decoded is Map<String, Object?> &&
          decoded['result'] is Map<String, Object?>) {
        return Success<Map<String, Object?>>(
          decoded['result']! as Map<String, Object?>,
        );
      }
      // ⚠️ **حالةٌ حقيقية لا نظرية:** وسيطٌ أو بوابةٌ قد تُرجِع 200 بجسمٍ
      //    ليس جسمنا. ⛔ **ولا تُعامَل نجاحاً** — فالنجاح الكاذب هنا يعني
      //    شاشةً تقول «حُفِظ» ولا شيء حُفِظ.
      return const Failure<Map<String, Object?>>(
        InfrastructureError('استجابة 200 بلا حقل result'),
      );
    }

    final String code = _errorCode(decoded);
    return switch (code) {
      // ★ الجلسة تُميَّز في النوع لا في الرمز وحده — فالموجّه يُعيد للدخول.
      'ERR_AUTH_003' || 'ERR_AUTH_004' =>
        const Failure<Map<String, Object?>>(SessionError()),
      'ERR_AUTH_001' || 'ERR_AUTH_007' =>
        const Failure<Map<String, Object?>>(PermissionError()),
      'ERR_CONC_001' =>
        const Failure<Map<String, Object?>>(ConcurrencyError()),
      // ⛔ **وما بقي يُنقَل برمزه** — والعرض يترجمه بـ`callableErrorMessage`،
      //   ⟵ **فرمزٌ يُضيفه الخادم غداً يصل الشاشة برسالة عامة لا بصمت.**
      _ => Failure<Map<String, Object?>>(InfrastructureError(code)),
    };
  }

  /// رمز الكتالوج من جسم الخطأ، أو `ERR_CALL_500` إن تعذّرت قراءته.
  static String _errorCode(Object? decoded) {
    if (decoded is! Map<String, Object?>) return 'ERR_CALL_500';
    final Object? error = decoded['error'];
    if (error is! Map<String, Object?>) return 'ERR_CALL_500';
    final Object? details = error['details'];
    if (details is Map<String, Object?> && details['code'] is String) {
      return details['code']! as String;
    }
    final Object? message = error['message'];
    return message is String && message.isNotEmpty ? message : 'ERR_CALL_500';
  }

  static Object? _tryDecode(String body) {
    if (body.isEmpty) return null;
    try {
      return jsonDecode(body);
    } on FormatException {
      // ⛔ ليس ابتلاعاً: العائد `null` يُترجَم فوراً إلى `ERR_CALL_500`.
      return null;
    }
  }
}

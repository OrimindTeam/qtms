import 'package:googleapis/identitytoolkit/v3.dart' as idtk;
import 'package:qtms_functions/src/identity_gateway.dart';
import 'package:test/test.dart';

idtk.DetailedApiRequestError apiError(int status, String? message) =>
    idtk.DetailedApiRequestError(status, message);

void main() {
  group('★ تصنيف أخطاء خدمة المصادقة — رُصد بالتشغيل الحقيقي', () {
    test('★ `INVALID_ID_TOKEN` يُصنَّف رمزاً غير صالح لا عطلاً', () {
      // ⚠️ هذه بالضبط الحالة التي تسرّبت خاماً فأنتجت 500 بلا رمز كتالوج:
      //    استدعاء حقيقي برمز مزيّف ردّ `DetailedApiRequestError(400,
      //    INVALID_ID_TOKEN)` — ⛔ ولا اختبار وحدة كان ليكشفها.
      expect(
        classifyIdentityApiError(apiError(400, 'INVALID_ID_TOKEN')),
        IdentityFailure.invalidToken,
      );
    });

    test('★ والرمز المنتهي كذلك — وهي أشيع حالة واقعية', () {
      expect(
        classifyIdentityApiError(apiError(400, 'TOKEN_EXPIRED')),
        IdentityFailure.invalidToken,
      );
    });

    test('★ والرسالة تُطابَق بلا حساسية لحالة الأحرف ولو جاءت ضمن نصّ أطول', () {
      expect(
        classifyIdentityApiError(
          apiError(400, 'Bad Request: invalid_id_token (see docs)'),
        ),
        IdentityFailure.invalidToken,
      );
    });

    test('⛔ وعطل الخدمة (5xx) **لا يُصنَّف** — ولا يُقنَّع جلسةً منتهية', () {
      // ★ ولماذا هذا الاختبار أهم من الذي قبله: تصنيف العطل «جلسة منتهية»
      //   يُرسِل المستخدم ليُعيد الدخول بلا جدوى **ويُخفي العطل عن المراقبة**.
      expect(classifyIdentityApiError(apiError(503, 'BACKEND_ERROR')), isNull);
      expect(classifyIdentityApiError(apiError(500, 'INTERNAL')), isNull);
    });

    test('⛔ و400 برسالة غير معروفة لا يُصنَّف — القائمة صريحة لا شاملة', () {
      expect(
        classifyIdentityApiError(apiError(400, 'QUOTA_EXCEEDED')),
        isNull,
      );
    });

    test('⛔ ورسالة فارغة لا تُصنَّف', () {
      expect(classifyIdentityApiError(apiError(400, null)), isNull);
    });

    test('⛔ وخطأ ليس من نوع الواجهة أصلاً لا يُصنَّف', () {
      expect(classifyIdentityApiError(StateError('انقطاع شبكة')), isNull);
    });
  });
}

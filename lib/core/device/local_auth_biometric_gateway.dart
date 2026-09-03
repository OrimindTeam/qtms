/// ★ التنفيذ الحقيقي لبوابة البصمة — **`local_auth`** ([`ADR-0024`]).
///
/// ⛔⛔★★ **ولا منطقَ سياسةٍ هنا** (`ADR-0009`) — ★ **ترجمةُ حزمةٍ إلى واجهة
/// النطاق وحدها:** ⟵ **ومتى تُقرأ الخزنة، ومتى تُمسح، ومن يُسمح له — كلُّه
/// في `biometric_providers.dart`** حيث يُختبَر بلا جهاز.
library;

import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

import 'biometric_gateway.dart';

/// بوابةُ البصمة فوق `local_auth`.
final class LocalAuthBiometricGateway implements BiometricGateway {
  /// ينشئ البوابة.
  const LocalAuthBiometricGateway(this._auth);

  final LocalAuthentication _auth;

  @override
  Future<BiometricAvailability> availability() async {
    try {
      // ⛔⛔★★★ **والترتيب مقصود:** ★ **`isDeviceSupported` تُجيب «هل للجهاز
      //    عتادٌ أو قفلُ شاشة»**، ⟵ **فإن كانت `false` فلا حلَّ للمستخدم**
      //    ⛔ **ولا معنى لسؤال «هل سجّل بصمةً».**
      if (!await _auth.isDeviceSupported()) {
        return BiometricAvailability.unsupported;
      }
      // ★★ **ثم البصماتُ المسجَّلة فعلاً** — `getAvailableBiometrics`:
      //    ⟵ **وقائمةٌ فارغةٌ تعني «يدعم ولم يُسجَّل»** ★ **وهي حالةٌ يحلّها
      //    المستخدم في إعدادات جهازه** ⛔ **لا في التطبيق.**
      final List<BiometricType> enrolled = await _auth.getAvailableBiometrics();
      return enrolled.isEmpty
          ? BiometricAvailability.notEnrolled
          : BiometricAvailability.available;
    } on LocalAuthException {
      // ⛔⛔★★★ **وهذا نوعُ الاستثناء الفعلي في `local_auth` 3.x** —
      //    ⛔ **لا `PlatformException`**: ★ **مقيسٌ على المحاكي**
      //    (`DEBT-82`) ⟵ **وهو ثاني عشرَ أوجهِ `DEBT-37`:**
      //    ⛔ **لا يُفترَض شكلُ مخرجات مكتبة — يُقاس.**
      return BiometricAvailability.unsupported;
    } on PlatformException {
      // ⛔⛔★★ **وعطلُ المنصّة يُقرأ «غير مدعومة» لا يُرمى** — ★ **فالبصمةُ
      //    قدرةٌ اختيارية**: ⟵ **وشاشةُ الدخول تبقى عاملةً بكلمة المرور**،
      //    ⛔ **وإسقاطُ الشاشة على عطلِ مستشعرٍ يقفل النظام بلا سبب.**
      //    ★ **ويبقى حارساً ثانياً للإصدارات الأقدم من المُلحقات.**
      return BiometricAvailability.unsupported;
    }
  }

  @override
  Future<bool> authenticate({required String reason}) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        // ★★★ **بصمةٌ فقط** — ⛔ **ولا سقوطَ إلى رمز قفل الشاشة:**
        //    ⟵ **نصُّ الطلب «ببصمة إصبعه»**، ★ **ورمزُ القفل يعرفه من
        //    يمسك الجهاز غالباً** ⛔ **فلا يُثبت أنه صاحبُ الحساب.**
        biometricOnly: true,
        // ★ **ومعاملةٌ حسّاسة** — ⟵ **فتُطلَب تأكيدةٌ صريحة بعد التعرّف.**
        sensitiveTransaction: true,
      );
    } on LocalAuthException {
      // ⛔⛔★★★ **والإلغاءُ من المستخدم يصل هنا لا في `false`** — ★ **عقدُ
      //    `local_auth` 3.x نصّاً:** «**returns false … For other failures
      //    cases, throws a `LocalAuthException`**» ⟵ **و`userCanceled`
      //    منها.** ⛔⛔ **ومسكُ `PlatformException` وحدَه كان يُسرِّب
      //    الاستثناء إلى الشاشة** ⟹ **فيبقى المؤشّر دائراً والرسالةُ
      //    السابقة معروضةً بلا تحديث** (`DEBT-82` — **مقيسٌ على المحاكي
      //    2026-09-02**): ★ **وهو ما تمنعه هذه الواجهة صراحةً**
      //    (`biometric_gateway.dart`: «**`false` تعني لم تنجح … والإلغاءُ
      //    من المستخدم يقع فيها**»).
      return false;
    } on PlatformException {
      // ⛔ **والفشلُ `false` لا استثناء** — ★ **والمُستدعي لا يفتح شيئاً.**
      return false;
    }
  }
}

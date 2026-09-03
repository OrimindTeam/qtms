/// ★ التنفيذ الحقيقي للخزنة والتفضيلات — **`flutter_secure_storage`**
/// ([`ADR-0024`] الشرط 1).
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **والإصدارُ مثبَّتٌ على `10.0.0` بقيدِ بناءٍ مقيس — ⛔ لا بذوق:**
///
/// ★ **`11.0.0` يفرض `compileSdk = 37`** (قُرئ في `android/build.gradle` من
/// الحزمة) — ⟹ ⛔⛔ **فسقط البناءُ فعلاً:** `Failed to find target with hash
/// string 'android-37'` (رُصد لحظةَ التنفيذ لا افتراضاً).
/// ⛔⛔★★★ **ورفعُ `compileSdk` ممنوعٌ بنصِّ `AM-011`:** «**الحد الأقصى/
/// compileSdk/targetSdk يبقيان كما هما دون أي تغيير**» — ★ **قرارُ مالكٍ
/// صريح** ⛔ **لا يُنقَض لأجل حزمة.**
/// ⛔ **و`9.x` متعذّرٌ كذلك** — ★ **يتعارض مع `share_plus 13.x` عبر `win32`**
/// (فشلُ حلٍّ مقيسٌ من `pub`).
/// ⟹ ✅ **و`10.0.0` هو الوحيد الذي يجتمع فيه الثلاثة:** **`compileSdk 36`**
/// (مطابقٌ للمشروع) · **`minSdk 24`** (مطابقٌ لـ`AM-011`) · **وحلُّ تبعياتٍ
/// نظيفٌ مع `share_plus`.**
///
/// ★★ **المُنشئ الافتراضي `AndroidOptions()` يستعمل:**
/// **`AES/GCM/NoPadding` للبيانات، ومفتاحُها ملفوفٌ بـ`RSA/ECB/OAEP` داخل
/// `Android Keystore`** — ⟵ **فالمفتاحُ لا يغادر المخزنَ العتادي**،
/// ★ **وهو حرفياً شرطُ §6 من `authentication-policy.md`** («**بلا حماية
/// النظام**») ✅ **مستوفىً.**
///
/// ⚠️⚠️★★ **وراية `encryptedSharedPreferences` مهجورةٌ في `10.0.0` وتُتجاهَل**
/// — ★ **ولم تُسقَط الحمايةُ معها بل صارت الافتراض** (⟵ **والحزمةُ نفسُها
/// تُرحِّل البيانات القديمة إلى المُعمِّيات الجديدة عند أول قراءة**):
/// ⛔ **فلا تُكتَب هنا.**
///
/// ⚠️⚠️★★★ **و`AndroidOptions.biometric(enforceBiometrics: true)` مدروسةٌ
/// ومرفوضةٌ بقرارٍ مُعلَن — ⛔ لا سهو:**
///   ✅ **مكسبُها:** ★ **تفرض الشرط 2 من [`ADR-0024`] في العتاد نفسِه** —
///      ⟵ **فلا يُفَكّ التشفيرُ أصلاً بلا بصمة**، ★ **دفاعٌ في العمق.**
///   ⛔ **وكلفتُها قاطعة:** ⟵ **حوارُ بصمةٍ ثانٍ من `Keystore` بعد حوارِ
///      `local_auth`** — ★ **بصمتان لدخولٍ واحد**، ⛔ **وهو نقيضُ سببِ
///      الميزة كلِّها** («بدلاً من كتابة كلمة المرور في كل مرة»).
///   ⟹ ★ **والمعتمَد: حراسةُ القراءة في طبقة التطبيق** حيث **تُختبَر آلياً**
///      (`biometric_providers.dart`) ⛔ **لا في مخزنٍ لا يُختبَر بلا جهاز.**
/// ═══════════════════════════════════════════════════════════════════════
library;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'credential_vault.dart';
import 'device_preferences.dart';

/// ★★ خياراتُ أندرويد — ★ **الافتراضُ المستنِد إلى `Keystore`** (راجع الترويسة).
///
/// ⛔ **ونطاقٌ مُسمّىً صريح** — ⟵ **فمفاتيحُ هذا التطبيق لا تختلط بغيرها
/// على جهازٍ فيه تطبيقٌ آخر من الحزمة نفسِها.**
const AndroidOptions _androidOptions = AndroidOptions(
  sharedPreferencesName: 'dev.orimind.qtms.secure',
);

/// ★ مفاتيحُ التخزين — ⛔ **ولا نصَّ مفتاحٍ محفورٌ في موضعين.**
const String _emailKey = 'qtms.biometric.email';
const String _passwordKey = 'qtms.biometric.password';
const String _pieceWeightKey = 'qtms.display.pieceWeightWithItemName';

/// خزنةُ بيانات الدخول فوق `flutter_secure_storage`.
final class SecureCredentialVault implements CredentialVault {
  /// ينشئ الخزنة.
  const SecureCredentialVault(this._storage);

  final FlutterSecureStorage _storage;

  @override
  Future<StoredCredentials?> readIfPresent() async {
    final String? email =
        await _storage.read(key: _emailKey, aOptions: _androidOptions);
    final String? password =
        await _storage.read(key: _passwordKey, aOptions: _androidOptions);
    // ⛔⛔★★ **وأحدُهما بلا الآخر يُقرأ غياباً لا نصفَ بيانات** — ★ **وحالةٌ
    //    ناقصةٌ لا تُنتج دخولاً**: ⟵ **فإعادتُها كانت تُفشِل الدخول برسالة
    //    «بيانات غير صحيحة»** ⛔ **وهي تُتّهم كلمةَ المستخدم وهي سليمة.**
    if (email == null || password == null) return null;
    if (email.isEmpty || password.isEmpty) return null;
    return StoredCredentials(email: email, password: password);
  }

  @override
  Future<void> save(StoredCredentials credentials) async {
    await _storage.write(
      key: _emailKey,
      value: credentials.email,
      aOptions: _androidOptions,
    );
    await _storage.write(
      key: _passwordKey,
      value: credentials.password,
      aOptions: _androidOptions,
    );
  }

  @override
  Future<void> clear() async {
    // ⛔⛔★★★ **ومحوٌ فعليٌّ للمفتاحين معاً** — الشرط 6 في [`ADR-0024`]:
    //    ⟵ **ومحوُ أحدهما يترك السرَّ على القرص** ⛔ **بينما يقرأ المستخدم
    //    «أُوقفت البصمة».**
    await _storage.delete(key: _emailKey, aOptions: _androidOptions);
    await _storage.delete(key: _passwordKey, aOptions: _androidOptions);
  }

  @override
  Future<bool> hasCredentials() async {
    // ⛔⛔★★★ **ولا تُقرأ كلمةُ المرور للإجابة** — الشرط 2: ★ **البريدُ وحدَه
    //    كافٍ للسؤال**، ⟵ **وقراءةُ الكلمة بلا مصادقةٍ تخالف الشرط نصّاً.**
    final String? email =
        await _storage.read(key: _emailKey, aOptions: _androidOptions);
    return email != null && email.isNotEmpty;
  }
}

/// ★ تفضيلاتُ العرض فوق المخزن نفسِه — `AM-012` §4.4.
///
/// ⛔ **ولا حزمةَ ثالثة لقيمةٍ منطقيةٍ واحدة** — راجع [DevicePreferences].
final class SecureDevicePreferences implements DevicePreferences {
  /// ينشئ التفضيلات.
  const SecureDevicePreferences(this._storage);

  final FlutterSecureStorage _storage;

  @override
  Future<bool> showPieceWeightWithItemName() async {
    final String? value =
        await _storage.read(key: _pieceWeightKey, aOptions: _androidOptions);
    // ⛔ **والغيابُ `false`** — ★ **فالحالةُ القائمة اليوم هي الافتراض.**
    return value == 'true';
  }

  @override
  Future<void> setShowPieceWeightWithItemName({required bool enabled}) =>
      _storage.write(
        key: _pieceWeightKey,
        value: enabled ? 'true' : 'false',
        aOptions: _androidOptions,
      );
}

/// ★★★ **سياسةُ الدخول بالبصمة** — [`ADR-0024`] ⏳ **مقترح** · [`CR-012`] ⏳ ·
/// `AM-012` §5.2 و§6.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **وهنا تعيش الشروطُ الأحد عشر — لا في البنية التحتية ولا في شاشة:**
/// ★ **`core/device/` مخازنُ وقنواتٌ محضة** (`ADR-0009`)، **والشاشةُ عرضٌ بلا
/// منطق** (`ADR-0010` القاعدة 1) — ⟹ ★ **والسياسةُ في طبقة التطبيق**،
/// ⟵ **وهي الطبقةُ الوحيدة التي تُختبَر آلياً بلا جهازٍ ولا سحابة.**
/// ═══════════════════════════════════════════════════════════════════════
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qtms_domain/qtms_domain.dart';

import '../../../core/device/biometric_gateway.dart';
import '../../../core/device/credential_vault.dart';
import 'session_providers.dart';

/// بوابةُ البصمة — ⛔ **تُحقَن في الجذر.**
final Provider<BiometricGateway> biometricGatewayProvider =
    Provider<BiometricGateway>((Ref ref) {
  throw UnimplementedError('biometricGatewayProvider يجب تجاوزه عند الجذر');
});

/// خزنةُ بيانات الدخول — ⛔ **تُحقَن في الجذر.**
final Provider<CredentialVault> credentialVaultProvider =
    Provider<CredentialVault>((Ref ref) {
  throw UnimplementedError('credentialVaultProvider يجب تجاوزه عند الجذر');
});

/// ⛅ حالةُ دعم البصمة على هذا الجهاز — `AM-012` §5.2.
final FutureProvider<BiometricAvailability> biometricAvailabilityProvider =
    FutureProvider<BiometricAvailability>(
  (Ref ref) => ref.watch(biometricGatewayProvider).availability(),
);

/// ⛅ **هل الدخولُ السريع مُفعَّلٌ على هذا الجهاز؟**
///
/// ⛔⛔★★★ **ويُقاس بوجود البيانات المحفوظة فعلاً** — ⛔ **لا برايةٍ منطقية
/// مستقلة:** ⟵ **ورايةٌ تقول «مُفعَّل» بلا بياناتٍ تُنتج زرَّ بصمةٍ يفشل
/// أبداً**، ★ **وعكسُها يترك سرّاً على القرص وقد أُطفئ الزر** — ⛔ **وكلاهما
/// عطلٌ صامت.** ★ **فمصدرُ الحقيقة واحد: الخزنة.**
final FutureProvider<bool> biometricLoginEnabledProvider =
    FutureProvider<bool>(
  (Ref ref) => ref.watch(credentialVaultProvider).hasCredentials(),
);

/// ★ نتيجةُ محاولةِ تفعيلٍ أو دخولٍ بالبصمة — **مصنَّفةٌ لا نصّية.**
enum BiometricOutcome {
  /// ✅ نجحت.
  success,

  /// ⛔ الجهاز لا يدعم البصمة إطلاقاً.
  unsupported,

  /// ⚠️ يدعمها ولا بصمةَ مسجَّلة عليه.
  notEnrolled,

  /// ⛔ لم تُقبَل البصمة — **أو ألغى المستخدم**.
  rejected,

  /// ⛔ **كلمةُ المرور غير صحيحة** — **عند التفعيل وحده.**
  badPassword,

  /// ⛔⛔ **لا بياناتٍ محفوظة** — **عند الدخول وحده.**
  ///
  /// ★★ **وتقع بعد المسح التلقائي** (الشرط 7) — ⟵ **فيُوجَّه المستخدم إلى
  /// كلمة المرور صراحةً** ⛔ **بلا رسالةِ عطلٍ غامضة.**
  noCredentials,
}

/// ★★★ **متحكّمُ الدخول بالبصمة** — ★ **الشروطُ الأحد عشر مُنفَّذةٌ هنا.**
final Provider<BiometricLoginController> biometricLoginControllerProvider =
    Provider<BiometricLoginController>(BiometricLoginController.new);

/// متحكّمُ البصمة.
final class BiometricLoginController {
  /// ينشئ المتحكّم.
  const BiometricLoginController(this._ref);

  final Ref _ref;

  BiometricGateway get _gateway => _ref.read(biometricGatewayProvider);
  CredentialVault get _vault => _ref.read(credentialVaultProvider);

  /// ★★★ **يُفعِّل الدخول السريع** — `AM-012` §5.2 · الشرطان 4 و5.
  ///
  /// ═══════════════════════════════════════════════════════════════════════
  /// ⛔⛔★★★ **والترتيبُ عقدٌ لا تفصيل: كلمةُ المرور ثم البصمة** —
  /// ★ **بنصِّ الطلب: «يُطلب منه إدخال كلمة المرور أولاً، ثم تمرير بصمة
  /// الإصبع كتأكيد»**:
  ///   ★ **الكلمةُ تُثبت أنه صاحبُ الحساب** — ⛔ **وبصمةٌ وحدها تُفعِّل
  ///     الدخولَ لمن أمسك جهازاً مفتوحاً.**
  ///   ★★ **وتُتحقَّق بمصادقةٍ حيّةٍ على الخادم قبل الحفظ** (الشرط 5) —
  ///     ⛔ **ولا تُقبَل بلا تحقّق**: ⟵ **وإلا حُفظت كلمةٌ خاطئة يفشل بها
  ///     كلُّ دخولٍ لاحق** ★ **ولا يعرف المستخدم لماذا.**
  /// ═══════════════════════════════════════════════════════════════════════
  Future<BiometricOutcome> enable({
    required String email,
    required String password,
  }) async {
    // ① ⛔ **الدعمُ أولاً** — ⟵ **فلا يُطلَب سرٌّ لقدرةٍ لا تعمل أصلاً.**
    final BiometricAvailability availability = await _gateway.availability();
    switch (availability) {
      case BiometricAvailability.unsupported:
        return BiometricOutcome.unsupported;
      case BiometricAvailability.notEnrolled:
        return BiometricOutcome.notEnrolled;
      case BiometricAvailability.available:
        break;
    }

    // ② ★★ **مصادقةٌ حيّة بالكلمة** — الشرط 5.
    final SignInResult verified =
        await _ref.read(authRepositoryProvider).signIn(
              email: email,
              password: password,
            );
    if (verified is! SignInAccepted) return BiometricOutcome.badPassword;

    // ③ ★ **ثم البصمةُ تأكيداً** — ⛔ **ولا تُحفَظ قبلها.**
    final bool confirmed = await _gateway.authenticate(
      reason: 'أكّد بصمتك لتفعيل الدخول السريع',
    );
    if (!confirmed) return BiometricOutcome.rejected;

    await _vault.save(StoredCredentials(email: email, password: password));
    _ref.invalidate(biometricLoginEnabledProvider);
    return BiometricOutcome.success;
  }

  /// ⛔⛔★★★ **يُطفئ الدخول السريع ويمسح فوراً** — الشرط 6 · `AM-012` §5.2.
  ///
  /// ★ **بنصِّ الطلب: «عند الإيقاف تُمسح بيانات البصمة المحفوظة فوراً»** —
  /// ⛔ **ولا رايةٌ تُطفَأ والسرُّ باقٍ.**
  Future<void> disable() async {
    await _vault.clear();
    _ref.invalidate(biometricLoginEnabledProvider);
  }

  /// ★★★ **يُسجِّل الدخول بالبصمة** — `AM-012` §6 · الشروط 2 و7 و9 و11.
  ///
  /// ═══════════════════════════════════════════════════════════════════════
  /// ⛔⛔★★★ **والبصمةُ قبل القراءة لا بعدها** — الشرط 2: ★ **قراءةُ الخزنة
  /// بلا مصادقةٍ تجعل التخزينَ نفسَه هو الثغرة**، ⟵ **فالحارسُ في مسار
  /// القراءة** ⛔ **لا في مسار العرض.**
  ///
  /// ⛔⛔★★★ **والفشلُ يمسح** — الشرط 7: ★ **كلمةٌ لم تعد صالحة، أو حسابٌ
  /// عُطِّل** ⟹ **بياناتٌ لا تعمل تبقى عبئاً أمنياً بلا فائدة** — ⟵ **فتُمسَح
  /// ويُوجَّه المستخدم إلى كلمة المرور.**
  ///
  /// ⛔⛔★★★ **ولا صلاحيةَ تُشتقّ من هذا المسار** — الشرط 9: ★ **يُنتج جلسةً
  /// عاديةً تماماً**، ⟵ **والصلاحياتُ من `users/{userId}`** (`ADR-0016`)
  /// ⛔ **ولا مسارَ تصعيدِ امتياز.** ★★ **والحسابُ المعطَّل يُرفَض كما يُرفَض
  /// في المسار العادي** (الشرط 11) — ⟵ **الرفضُ في الخادم وفي `SessionRejected`.**
  /// ═══════════════════════════════════════════════════════════════════════
  Future<BiometricOutcome> signIn() async {
    final BiometricAvailability availability = await _gateway.availability();
    switch (availability) {
      case BiometricAvailability.unsupported:
        return BiometricOutcome.unsupported;
      case BiometricAvailability.notEnrolled:
        return BiometricOutcome.notEnrolled;
      case BiometricAvailability.available:
        break;
    }

    final bool confirmed = await _gateway.authenticate(
      reason: 'أكّد بصمتك للدخول',
    );
    if (!confirmed) return BiometricOutcome.rejected;

    // ★★ **ولا تُقرأ الخزنة إلا الآن** — الشرط 2.
    final StoredCredentials? stored = await _vault.readIfPresent();
    if (stored == null) {
      _ref.invalidate(biometricLoginEnabledProvider);
      return BiometricOutcome.noCredentials;
    }

    final SignInResult result = await _ref.read(authRepositoryProvider).signIn(
          email: stored.email,
          password: stored.password,
        );
    if (result is! SignInAccepted) {
      // ⛔⛔★★★ **والمسحُ فوريٌّ على الفشل** — الشرط 7.
      await _vault.clear();
      _ref.invalidate(biometricLoginEnabledProvider);
      return BiometricOutcome.badPassword;
    }
    return BiometricOutcome.success;
  }

  /// ★★ **يُحدِّث البيانات المحفوظة بعد تغيير كلمة المرور** — الشرط 8 ·
  /// `AM-012` §5.3.
  ///
  /// ★ **بنصِّ الطلب: «إذا كانت البصمة مفعّلة تُحدَّث بيانات الدخول السريع
  /// تلقائياً لتعمل مع الكلمة الجديدة»** — ⛔ **وإلا فشل الدخولُ السريع بعد
  /// كل تغيير** ★ **بلا سببٍ ظاهرٍ للمستخدم.**
  ///
  /// ⛔⛔★★★ **ولا تُنشئ حفظاً جديداً لمن لم يُفعِّل** — ★ **تُحدِّث القائم
  /// وحدَه:** ⟵ **وحفظُ كلمةِ من لم يطلب الميزة تخزينُ سرٍّ بلا إذنه**،
  /// ⛔ **وهو أخطر ما يمكن أن يفعله هذا الملف.**
  Future<void> refreshStoredPassword(String newPassword) async {
    final StoredCredentials? stored = await _vault.readIfPresent();
    if (stored == null) return;
    await _vault.save(
      StoredCredentials(email: stored.email, password: newPassword),
    );
  }
}

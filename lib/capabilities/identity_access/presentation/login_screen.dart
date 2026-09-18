/// شاشة الدخول — ★ **نمط 8** في `ui-guidelines.md` §3:
/// «شعار ⟵ عنوان ⟵ حقول ⟵ زر أساسي عريض. ★ **ورسائل خطأ محدَّدة لا
/// «حدث خطأ»**».
///
/// ⛔ **ولا منطق أعمال هنا** (`ADR-0009` · `ADR-0010` القاعدة 1) — الشاشة
/// تستدعي المتحكّم وتعرض حالته، **والتصنيف والرسائل من طبقاتهما.**
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qtms_domain/qtms_domain.dart';

import '../../../core/design/brand.dart';
import '../../../core/design/design_tokens.dart';
import '../../../core/messages/error_messages.dart';
import '../../../core/ui/inline_banner.dart';
import '../../../core/startup/staging_qa_credentials.dart';
import '../application/biometric_providers.dart';
import '../application/login_controller.dart';

/// ★★ **سطرُ تعريف النظام تحت الشعار** — `AM-018` · `ui-guidelines.md` نمط 8.
///
/// ⛔ **ولا نصٌّ محفورٌ في موضعين** — ★ **يقرؤه الاختبارُ من هنا.**
const String loginTaglineText =
    'إدارة المخزون والذمم والنقد في تجارة القات';

/// ★★ **سطرُ استرداد كلمة المرور** — `AM-018` · `CR-005` §2.2.
///
/// ⛔⛔ **نصٌّ ساكنٌ لا مسار** — ★ **يوجّه إلى مسؤول النظام** ⛔ **ولا يَعِد
/// بشاشةٍ لا وجود لها.**
const String passwordRecoveryHintText =
    'نسيت كلمة المرور؟ راجع مسؤول النظام لإعادة تعيينها';

/// شاشة تسجيل الدخول.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();

  @override
  void initState() {
    super.initState();
    // ★★ ملءٌ مسبق لاختبار المحاكي وحده (`AM-005` · `DEBT-31`) — محروسٌ
    //   بـ`kDebugMode` وبوجود الحقن معاً، ⟵ ⛔ **وميتٌ في بناء الإصدار.**
    //   ⛔ **ولا إرسال تلقائياً** — الملء يُهيّئ الحقلين والضغط يبقى صريحاً.
    final StagingQaCredentials? qa = ref.read(stagingQaCredentialsProvider);
    if (qa != null) {
      _email.text = qa.email;
      _password.text = qa.password;
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  /// ★ هل كلمةُ المرور ظاهرة الآن؟ — **حالةُ عرضٍ محلية بحتة.**
  bool _passwordVisible = false;

  /// ★★ **نصُّ تعذُّرِ الدخول بالبصمة** — ⛔ **ولا يُبتلَع.**
  ///
  /// ⚠️⚠️ **ومستقلٌّ عن [LoginRejected] عمداً:** ★ **ذاك رفضٌ من خدمة
  /// المصادقة على بياناتٍ أُرسلت**، ⟵ **وهذا تعذُّرٌ قبل الإرسال أصلاً**
  /// (بصمةٌ لم تُقبَل · جهازٌ لا يدعم · لا بياناتٍ محفوظة) — ⛔ **وخلطُهما
  /// كان يُري المستخدم «بيانات دخول غير صحيحة» وهو لم يُدخِل شيئاً.**
  String? _biometricStatus;

  /// ★ هل تجري محاولةُ بصمةٍ الآن؟
  bool _biometricBusy = false;

  bool get _canSubmit =>
      _email.text.trim().isNotEmpty && _password.text.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final LoginState state = ref.watch(loginControllerProvider);
    final bool submitting = state is LoginSubmitting;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Spacing.space24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  // ① الشعار — ★ **شعار العميل الفعلي** (`AM-002` ·
                  //   `ui-guidelines.md` نمط 8) ⛔ **لا رمزاً محايداً من
                  //   عائلة الإطار** كما كان قبل وصول الهوية البصرية.
                  const BrandLogo(),
                  const SizedBox(height: brandLogoGap),
                  // ①-ب ★★★ **سطرُ تعريف النظام** — `AM-018` · `ui-guidelines.md`
                  //    نمط 8: ⟵ **شعارٌ وحدَه لا يقول شيئاً لمن لم يُدرَّب
                  //    بعد**، ★ **وهذه أولُ شاشةٍ يراها مستخدمٌ جديد.**
                  //    ⛔ **وسطرٌ واحدٌ يصف الوظيفة** ⛔ **لا شعارٌ تسويقي.**
                  Text(
                    loginTaglineText,
                    textAlign: TextAlign.center,
                    style: TypeScale.caption
                        .copyWith(color: SemanticColors.textSecondary),
                  ),
                  const SizedBox(height: Spacing.space16),
                  // ② العنوان
                  Text(
                    'تسجيل الدخول',
                    textAlign: TextAlign.center,
                    style: TypeScale.titleLg
                        .copyWith(color: SemanticColors.textPrimary),
                  ),
                  const SizedBox(height: Spacing.space24),
                  // ③ الحقول
                  TextField(
                    controller: _email,
                    enabled: !submitting,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const <String>[AutofillHints.username],
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'البريد الإلكتروني',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: Spacing.space12),
                  TextField(
                    controller: _password,
                    enabled: !submitting,
                    obscureText: !_passwordVisible,
                    autofillHints: const <String>[AutofillHints.password],
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: 'كلمة المرور',
                      // ★★ **مبدّل الإظهار** — ⟵ **إدخالٌ أعمى على لوحةِ
                      //    هاتفٍ في ميدانٍ مستعجل يُنتج محاولةً فاشلة كل مرة**،
                      //    ★ **والاستخدام الميداني المستعجل أولويةٌ معلَنة**
                      //    (`ui-guidelines.md` §2).
                      suffixIcon: IconButton(
                        onPressed: () => setState(
                          () => _passwordVisible = !_passwordVisible,
                        ),
                        icon: Icon(
                          _passwordVisible
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: Sizes.iconLg,
                        ),
                        // ★ **وصفٌ دلالي يذكر الحالة** — §5 البند 3.
                        tooltip: _passwordVisible
                            ? 'إخفاء كلمة المرور'
                            : 'إظهار كلمة المرور',
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: Spacing.space16),
                  // ④ زر أساسي عريض
                  FilledButton(
                    onPressed: submitting || !_canSubmit ? null : _submit,
                    child: submitting
                        // ★ **مؤشّرٌ داخل الزر** — §6.ج: ⛔ **لا وسط الشاشة**،
                        //   ★ **والعرضُ ثابت فلا يقفز الزر** (منع القفز).
                        ? const SizedBox(
                            height: Sizes.iconMd,
                            width: Sizes.iconMd,
                            child: CircularProgressIndicator(
                              strokeWidth: Sizes.focusWidth,
                              color: SemanticColors.textOnInverse,
                            ),
                          )
                        : const Text('دخول'),
                  ),
                  // ④-ب ⛔⛔★★★ **سطرُ استرداد كلمة المرور — إعلانُ حدٍّ لا
                  //    مسارٌ يُفتَح** (`AM-018` · `CR-005` §2.2):
                  //    ⛔⛔ **نصٌّ ساكنٌ لا زرٌّ ولا رابط** — ⟵ **فلا مسارَ
                  //    استردادٍ داخل التطبيق أصلاً**، ★ **وإعادةُ التعيين من
                  //    المدير** («الإدارة تُعيد التعيين ولا تقرأ»):
                  //    ⛔⛔ **ورابطٌ يَعِد بما لا يقع أسوأُ من غيابه.**
                  const SizedBox(height: Spacing.space12),
                  Text(
                    passwordRecoveryHintText,
                    textAlign: TextAlign.center,
                    style: TypeScale.caption
                        .copyWith(color: SemanticColors.textTertiary),
                  ),
                  // ⑤ ★★★ **الدخولُ بالبصمة** — `AM-012` §6 · [`ADR-0024`].
                  //
                  // ⛔⛔★★★ **ولا يظهر إلا لمن فعّله على *هذا الجهاز*** —
                  //    ★ **والمقياسُ وجودُ بياناتٍ محفوظةٍ فعلاً**
                  //    (`biometricLoginEnabledProvider`): ⟵ **فزرٌّ يظهر بلا
                  //    بياناتٍ يفشل أبداً**، ⛔ **ويُعلِّم المستخدم أن الميزة
                  //    معطوبة وهي لم تُفعَّل أصلاً.**
                  //
                  // ⛔⛔★★★ **وهو بديلٌ لا اختصار:** ★ **حقلا البريد وكلمة
                  //    المرور باقيان كاملين فوقه** — ⟵ **فمن فشلت بصمتُه أو
                  //    بدّل حسابَه يدخل كما كان**، ⛔ **ولا مسارَ يُغلَق.**
                  if (ref.watch(biometricLoginEnabledProvider).value ?? false)
                    ...<Widget>[
                      const SizedBox(height: Spacing.space12),
                      OutlinedButton.icon(
                        onPressed: (submitting || _biometricBusy)
                            ? null
                            : _biometricSignIn,
                        icon: const Icon(Icons.fingerprint),
                        label: const Text('الدخول ببصمة الإصبع'),
                      ),
                    ],
                  if (_biometricStatus case final String message) ...<Widget>[
                    const SizedBox(height: Spacing.space16),
                    QtmsInlineBanner(
                      text: message,
                      triad: SemanticTriads.danger,
                    ),
                  ],
                  if (state is LoginRejected) ...<Widget>[
                    const SizedBox(height: Spacing.space16),
                    _RejectionBanner(reason: state.reason),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (!_canSubmit) return;
    ref.read(loginControllerProvider.notifier).submit(
          email: _email.text,
          password: _password.text,
        );
  }

  /// ★★★ **الدخولُ بالبصمة** — `AM-012` §6.
  ///
  /// ⛔⛔★★★ **ولا تُملأ الحقولُ بالمحفوظ إطلاقاً** — الشرط 3 في [`ADR-0024`]:
  /// ★ **البصمةُ تفتح دخولاً** ⛔ **لا تكشف سرّاً** — ⟵ **وحقلُ كلمةِ مرورٍ
  /// مملوءٌ بها يجعلها مقروءةً بضغطةٍ على «إظهار».**
  ///
  /// ⛔⛔ **والنجاحُ لا يُنقِل الشاشةَ يدوياً** — ★ **تدفّقُ الجلسة حيّ**،
  /// ⟵ **فالموجّه يُخرجها من تلقائه** (`router.dart`) ⛔ **بلا ملاحةٍ هنا.**
  Future<void> _biometricSignIn() async {
    setState(() {
      _biometricBusy = true;
      _biometricStatus = null;
    });
    final BiometricOutcome outcome =
        await ref.read(biometricLoginControllerProvider).signIn();
    if (!mounted) return;
    setState(() {
      _biometricBusy = false;
      _biometricStatus =
          outcome == BiometricOutcome.success ? null : _statusFor(outcome);
    });
  }

  /// ★ نصٌّ لكل تعذُّر — ⛔ **ولا رسالةَ واحدة لحالاتٍ مختلفة.**
  static String _statusFor(BiometricOutcome outcome) => switch (outcome) {
        BiometricOutcome.rejected => '❌ تعذّر التحقق من البصمة.',
        BiometricOutcome.notEnrolled =>
          '⚠️ لا توجد بصمة مسجَّلة على هذا الجهاز.',
        BiometricOutcome.unsupported =>
          '⚠️ هذا الجهاز لا يدعم بصمة الإصبع.',
        // ⛔⛔★★★ **والمسحُ وقع فعلاً قبل هذه الرسالة** — الشرطان 7 و[Outcome]:
        //    ★ **فالنصُّ يوجّه إلى كلمة المرور صراحةً** ⛔ **ولا يترك المستخدم
        //    يعيد المحاولة على بياناتٍ لم تعد موجودة.**
        BiometricOutcome.badPassword ||
        BiometricOutcome.noCredentials =>
          '❌ تعذّر الدخول ببيانات هذا الجهاز — أدخل بريدك وكلمة مرورك، '
              'ثم أعد تفعيل البصمة من الملف الشخصي.',
        BiometricOutcome.success => '',
      };
}

/// شريط الرفض — ★ **نصّه من الكتالوج حرفياً** ⛔ **ولا صياغة هنا.**
///
/// ✅★★ **وقد حُسم `IQ-016` (2026-08-24)** — فلكل حالة رفض نصٌّ معتمد الآن،
/// بما فيها **«بيانات دخول غير صحيحة»** (`ERR_AUTH_008`) و**«فشل غير
/// متوقَّع»** (`ERR_AUTH_009`). ⟵ ⛔ **ولا حالة صامتة بعد اليوم.**
class _RejectionBanner extends StatelessWidget {
  const _RejectionBanner({required this.reason});

  final SignInRejection reason;

  @override
  Widget build(BuildContext context) {
    final CatalogMessage message = signInRejectionMessage(reason);

    return QtmsInlineBanner(
      text: catalogText(message),
      triad: SemanticTriads.danger,
    );
  }
}

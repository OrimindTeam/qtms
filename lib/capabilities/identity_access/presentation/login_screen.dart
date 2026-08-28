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
import '../../../core/startup/staging_qa_credentials.dart';
import '../application/login_controller.dart';

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

    return Container(
      padding: const EdgeInsets.all(Spacing.space12),
      decoration: BoxDecoration(
        color: Primitives.dangerSoft,
        border: Border.all(color: Primitives.dangerBorder),
        borderRadius: BorderRadius.circular(Radii.card),
      ),
      child: Text(
        catalogText(message),
        style: TypeScale.bodyMd.copyWith(color: Primitives.dangerInk),
      ),
    );
  }
}

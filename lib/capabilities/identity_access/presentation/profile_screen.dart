/// ★★★ **شاشة «الملف الشخصي»** — `AM-012` §5 · [`CR-012`] ⏳ **مقترح**.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **وحدُّها قاطع: بياناتُ صاحب الجلسة وحدَه** — ⛔ **ولا تعرض ولا
/// تُعدِّل حسابَ أحدٍ سواه إطلاقاً:** ★ **وإدارةُ المستخدمين شاشتُها**
/// (`UsersScreen` · `FR-M1-01`…`FR-M1-11`) **بمفاتيحها هي** ⟵ **وخلطُهما
/// كان يجعل شاشةَ «ملفّي» طريقاً ثانياً لإدارة الحسابات** ⛔ **بلا مفاتيحها.**
///
/// ⛔⛔★★★ **ولا مفتاحَ صلاحيةٍ جديد لها** (`BR-M1-07`) — ★ **بياناتُ صاحب
/// الجلسة نفسِه ليست مورداً يُؤذَن فيه**: ⟵ **والكتالوجُ يبقى 85 مفتاحاً**،
/// ⛔ **ولا `firestore.rules` تُمَسّ** (`CR-012` §4).
/// ═══════════════════════════════════════════════════════════════════════
///
/// ★ **نمط 8** في `ui-guidelines.md` §3 مقلوباً: **هويةٌ ⟵ أقسامٌ ⟵ نماذج.**
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qtms_domain/qtms_domain.dart';

import '../../../app/top_bar.dart';
import '../../../core/design/design_tokens.dart';
import '../../../core/messages/error_messages.dart';
import '../../../core/device/biometric_gateway.dart';
import '../../../core/ui/avatar.dart';
import '../../../core/ui/inline_banner.dart';
import '../application/biometric_providers.dart';
import '../application/session_providers.dart';

/// ★ اسمُ الشاشة — ⛔ **ولا نصٌّ محفورٌ في موضعين.**
const String profileScreenTitle = 'الملف الشخصي';

/// شاشة الملف الشخصي.
class ProfileScreen extends ConsumerWidget {
  /// ينشئ الشاشة.
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AuthSession? session = ref.watch(currentSessionProvider);
    // ⛔ **ولا شاشةَ بلا جلسة** — ★ **والموجّه يمنع الوصول أصلاً.**
    if (session == null) {
      return const Scaffold(
        appBar: QtmsTopBar(screenTitle: profileScreenTitle),
        body: SizedBox.shrink(),
      );
    }

    return Scaffold(
      appBar: const QtmsTopBar(screenTitle: profileScreenTitle),
      body: ListView(
        padding: const EdgeInsetsDirectional.all(Spacing.screenPadding),
        children: <Widget>[
          _IdentityHeader(session: session),
          const SizedBox(height: Spacing.space24),
          const _BiometricSection(),
          const SizedBox(height: Spacing.space24),
          const _PasswordSection(),
        ],
      ),
    );
  }
}

/// ★★ **① أعلى الشاشة** — `AM-012` §5.1: **صورةٌ رمزية · الاسم · البريد.**
class _IdentityHeader extends StatelessWidget {
  const _IdentityHeader({required this.session});

  final AuthSession session;

  @override
  Widget build(BuildContext context) => Column(
        children: <Widget>[
          // ★ **والصورةُ الرمزية هي مكوّنُ الشريط نفسُه** — ⛔ **ولا نسخةَ
          //   ثانية** (§8 المحظور الحادي عشر): ⟵ **فالحرفُ واحدٌ في الموضعين.**
          QtmsAvatar(name: session.displayName, size: Sizes.avatarLg),
          const SizedBox(height: Spacing.space12),
          Text(
            session.displayName,
            style: TypeScale.titleLg.copyWith(color: SemanticColors.textPrimary),
            textAlign: TextAlign.center,
          ),
          // ⛔⛔★★ **والبريدُ يُعرَض إن وُجد وحدَه** — ★ **ولا «بلا بريد»:**
          //    ⟵ **حسابٌ بلا بريدٍ حالةٌ ممكنة في خدمة المصادقة**، ⛔ **ونصٌّ
          //    يُعلنها في شاشةِ «ملفّي» يُقلق صاحبَها بلا فائدة.**
          if (session.email case final String email) ...<Widget>[
            const SizedBox(height: Spacing.space4),
            Text(
              email,
              style: TypeScale.bodyMd
                  .copyWith(color: SemanticColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      );
}

/// ★★★ **② الدخول بالبصمة** — `AM-012` §5.2 · [`ADR-0024`].
class _BiometricSection extends ConsumerStatefulWidget {
  const _BiometricSection();

  @override
  ConsumerState<_BiometricSection> createState() => _BiometricSectionState();
}

class _BiometricSectionState extends ConsumerState<_BiometricSection> {
  bool _busy = false;
  String? _status;
  bool _statusIsSuccess = false;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<BiometricAvailability> availability =
        ref.watch(biometricAvailabilityProvider);
    final AsyncValue<bool> enabled = ref.watch(biometricLoginEnabledProvider);

    final BiometricAvailability? state = availability.value;
    final bool supported = state == BiometricAvailability.available;

    return _Section(
      title: 'الدخول ببصمة الإصبع',
      children: <Widget>[
        SwitchListTile.adaptive(
          value: enabled.value ?? false,
          // ⛔⛔★★ **ومعطَّلٌ على جهازٍ لا يدعمها** — `AM-012` §5.2 نصّاً:
          //    ★ **«يظهر المفتاح معطّلاً مع رسالة توضيحية»** ⟵ **فلا يُخفى**:
          //    ⛔ **وإخفاؤه كان يترك المستخدم يبحث عن ميزةٍ وُعد بها.**
          onChanged: (!supported || _busy) ? null : _toggle,
          title: const Text('تفعيل الدخول بالبصمة'),
          subtitle: Text(_subtitleFor(state)),
          contentPadding: EdgeInsets.zero,
        ),
        if (_status case final String message) ...<Widget>[
          const SizedBox(height: Spacing.space12),
          QtmsInlineBanner(
            text: message,
            triad: _statusIsSuccess
                ? SemanticTriads.success
                : SemanticTriads.danger,
          ),
        ],
      ],
    );
  }

  /// ★★★ **نصٌّ لكل حالة** — ⛔ **ولا رسالةَ واحدة لحالتين مختلفتين:**
  /// ⟵ **«الجهاز لا يدعم» لا حلَّ لها**، ★ **و«لا بصمةَ مسجَّلة» يحلّها
  /// المستخدم في إعدادات جهازه خلال دقيقة** — ⛔ **ورسالةٌ واحدة كانت تترك
  /// نصفَ المستخدمين يظنّون أجهزتهم عاجزة.**
  static String _subtitleFor(BiometricAvailability? state) => switch (state) {
        BiometricAvailability.available =>
          'يُطلب منك إدخال كلمة المرور ثم تمرير بصمتك تأكيداً.',
        BiometricAvailability.notEnrolled =>
          '⚠️ لا توجد بصمة مسجَّلة على هذا الجهاز — سجّلها في إعدادات الجهاز '
              'ثم عد إلى هنا.',
        BiometricAvailability.unsupported =>
          '⚠️ هذا الجهاز لا يدعم بصمة الإصبع.',
        // ★ **وقبل القياس لا يُقال شيء** — ⛔ **ولا تُدَّعى قدرةٌ لم تُقَس بعد**
        //   (نفسُ مبدأ `ADR-0003` في مؤشّر الاتصال).
        null => 'يجري التحقق من دعم الجهاز…',
      };

  Future<void> _toggle(bool value) async {
    if (!value) {
      setState(() => _busy = true);
      await ref.read(biometricLoginControllerProvider).disable();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _statusIsSuccess = true;
        _status = 'أُوقف الدخول بالبصمة ومُسحت بياناته من هذا الجهاز.';
      });
      return;
    }
    // ★★★ **والتفعيل يشترط كلمةَ المرور أولاً** — الشرط 4 في [`ADR-0024`].
    final String? password = await _askPassword(context);
    if (password == null || !mounted) return;

    final AuthSession? session = ref.read(currentSessionProvider);
    final String? email = session?.email;
    if (email == null || email.isEmpty) {
      setState(() {
        _statusIsSuccess = false;
        _status = '❌ لا يمكن تفعيل البصمة — لا بريد مرتبط بهذا الحساب.';
      });
      return;
    }

    setState(() => _busy = true);
    final BiometricOutcome outcome = await ref
        .read(biometricLoginControllerProvider)
        .enable(email: email, password: password);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _statusIsSuccess = outcome == BiometricOutcome.success;
      _status = _messageFor(outcome);
    });
  }

  static String _messageFor(BiometricOutcome outcome) => switch (outcome) {
        BiometricOutcome.success => 'فُعِّل الدخول بالبصمة على هذا الجهاز.',
        BiometricOutcome.badPassword => '❌ كلمة المرور غير صحيحة.',
        BiometricOutcome.rejected => '❌ تعذّر التحقق من البصمة.',
        BiometricOutcome.notEnrolled =>
          '⚠️ لا توجد بصمة مسجَّلة على هذا الجهاز.',
        BiometricOutcome.unsupported =>
          '⚠️ هذا الجهاز لا يدعم بصمة الإصبع.',
        BiometricOutcome.noCredentials =>
          '❌ لا توجد بيانات دخول محفوظة على هذا الجهاز.',
      };

  /// ★★ **ورقةُ كلمة المرور** — ⛔ **ولا تُملأ مسبقاً ولا تُحفَظ هنا.**
  Future<String?> _askPassword(BuildContext context) => showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        backgroundColor: SemanticColors.surface,
        builder: (BuildContext sheetContext) => const _PasswordPrompt(),
      );
}

/// ورقةُ تأكيدِ كلمة المرور قبل تفعيل البصمة.
class _PasswordPrompt extends StatefulWidget {
  const _PasswordPrompt();

  @override
  State<_PasswordPrompt> createState() => _PasswordPromptState();
}

class _PasswordPromptState extends State<_PasswordPrompt> {
  final TextEditingController _password = TextEditingController();
  bool _visible = false;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: Spacing.screenPadding,
            right: Spacing.screenPadding,
            top: Spacing.screenPadding,
            // ★ **فوق لوحة المفاتيح** — ⛔ **ولا حقلٌ يختفي تحتها.**
            bottom: MediaQuery.viewInsetsOf(context).bottom +
                Spacing.screenPadding,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Text('تأكيد كلمة المرور', style: TypeScale.titleLg),
              const SizedBox(height: Spacing.space12),
              TextField(
                controller: _password,
                obscureText: !_visible,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'كلمة المرور الحالية',
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _visible = !_visible),
                    tooltip: _visible ? 'إخفاء كلمة المرور' : 'إظهار كلمة المرور',
                    icon: Icon(
                      _visible
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: Sizes.iconLg,
                    ),
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: Spacing.space16),
              FilledButton(
                onPressed: _password.text.isEmpty
                    ? null
                    : () => Navigator.of(context).pop(_password.text),
                child: const Text('متابعة'),
              ),
              const SizedBox(height: Spacing.space8),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('إلغاء'),
              ),
            ],
          ),
        ),
      );
}

/// ★★★ **③ تغيير كلمة المرور** — `AM-012` §5.3 · [`CR-012`] `FR-M1-19`.
class _PasswordSection extends ConsumerStatefulWidget {
  const _PasswordSection();

  @override
  ConsumerState<_PasswordSection> createState() => _PasswordSectionState();
}

class _PasswordSectionState extends ConsumerState<_PasswordSection> {
  final TextEditingController _current = TextEditingController();
  final TextEditingController _next = TextEditingController();
  final TextEditingController _confirm = TextEditingController();

  bool _busy = false;
  String? _status;
  bool _statusIsSuccess = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _Section(
        title: 'تغيير كلمة المرور',
        children: <Widget>[
          _PasswordField(controller: _current, label: 'كلمة المرور الحالية'),
          const SizedBox(height: Spacing.space12),
          _PasswordField(
            controller: _next,
            // ★★★ **والحدُّ ثمانيةٌ لا ستّة** — [`CR-012`] §2.2:
            //    ⛔ **ونصُّ الحقل يقوله صراحةً** ⟵ **فلا يُفاجأ المستخدم برفض.**
            label: 'كلمة المرور الجديدة ($initialPasswordMinLength أحرف فأكثر)',
          ),
          const SizedBox(height: Spacing.space12),
          _PasswordField(
            controller: _confirm,
            label: 'تأكيد كلمة المرور الجديدة',
          ),
          if (_status case final String message) ...<Widget>[
            const SizedBox(height: Spacing.space12),
            QtmsInlineBanner(
              text: message,
              triad: _statusIsSuccess
                  ? SemanticTriads.success
                  : SemanticTriads.danger,
            ),
          ],
          const SizedBox(height: Spacing.space16),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: const Text('تغيير كلمة المرور'),
          ),
        ],
      );

  Future<void> _submit() async {
    // ① ★★ **الفحصُ في طبقة النطاق** — ⛔ **ولا شرطٌ مكتوبٌ في شاشة**
    //    (`ADR-0010` القاعدة 1).
    final Outcome<PasswordChange> validated = validatePasswordChange(
      currentPassword: _current.text,
      newPassword: _next.text,
      confirmation: _confirm.text,
    );
    if (validated case Failure<PasswordChange>(:final AppError error)) {
      setState(() {
        _statusIsSuccess = false;
        _status = _rejectionText(error);
      });
      return;
    }

    final PasswordChange change =
        (validated as Success<PasswordChange>).value;
    setState(() {
      _busy = true;
      _status = null;
    });

    final SignInResult result =
        await ref.read(authRepositoryProvider).changePassword(
              currentPassword: change.currentPassword,
              newPassword: change.newPassword,
            );
    if (!mounted) return;

    if (result is! SignInAccepted) {
      setState(() {
        _busy = false;
        _statusIsSuccess = false;
        _status = catalogText(
          signInRejectionMessage((result as SignInRejected).reason),
        );
      });
      return;
    }

    // ② ★★★ **وتُحدَّث بيانات الدخول السريع إن كانت مفعَّلة** — الشرط 8:
    //    ⛔ **ولا تُنشَأ لمن لم يُفعِّل** (راجع `refreshStoredPassword`).
    await ref
        .read(biometricLoginControllerProvider)
        .refreshStoredPassword(change.newPassword);
    if (!mounted) return;

    _current.clear();
    _next.clear();
    _confirm.clear();
    setState(() {
      _busy = false;
      _statusIsSuccess = true;
      _status = 'تغيّرت كلمة المرور.';
    });
  }

  /// ★ نصُّ الرفض — ⛔ **ولا رمزٌ تقنيٌّ يُعرَض للمستخدم**
  /// (`error-handling-strategy.md` §3 القاعدة 2).
  static String _rejectionText(AppError error) {
    final PasswordChangeRejection? reason = error is ValidationError
        ? passwordChangeRejectionOf(error.ruleCode)
        : null;
    return switch (reason) {
      PasswordChangeRejection.currentMissing => '❌ أدخل كلمة المرور الحالية.',
      PasswordChangeRejection.tooShort =>
        '❌ كلمة المرور الجديدة قصيرة جداً — '
            '$initialPasswordMinLength أحرف على الأقل.',
      PasswordChangeRejection.confirmationMismatch =>
        '❌ كلمة المرور الجديدة لا تطابق تأكيدها.',
      PasswordChangeRejection.unchanged =>
        '❌ كلمة المرور الجديدة هي نفسها الحالية.',
      null => '❌ تعذّر تنفيذ العملية.',
    };
  }
}

class _PasswordField extends StatefulWidget {
  const _PasswordField({required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) => TextField(
        controller: widget.controller,
        obscureText: !_visible,
        decoration: InputDecoration(
          labelText: widget.label,
          // ★★ **مبدّل الإظهار** — ★ **نفسُ سبب شاشة الدخول:** ⟵ **إدخالٌ
          //    أعمى على لوحةِ هاتفٍ يُنتج محاولةً فاشلة كل مرة.**
          suffixIcon: IconButton(
            onPressed: () => setState(() => _visible = !_visible),
            tooltip: _visible ? 'إخفاء كلمة المرور' : 'إظهار كلمة المرور',
            icon: Icon(
              _visible
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              size: Sizes.iconLg,
            ),
          ),
        ),
      );
}

/// ★ قسمٌ بعنوان — ⛔ **ولا بطاقةَ ثانيةٌ تُخترَع.**
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            title,
            style: TypeScale.titleSm.copyWith(color: SemanticColors.textPrimary),
          ),
          const SizedBox(height: Spacing.space8),
          const Divider(height: Sizes.borderWidth),
          const SizedBox(height: Spacing.space12),
          ...children,
        ],
      );
}

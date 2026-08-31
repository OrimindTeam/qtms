/// نموذج المستخدم — **نمط 4 (النموذج)** `ui-guidelines.md` §3.
///
/// ★ **ورقةٌ سفلية لا شاشة كاملة:** الحقول أربعة ⟵ **≤ 8** (نمط 4).
///
/// ★★ **وقاعدتان من نمط 4 مُنفَّذتان هنا حرفياً:**
/// ① **تحقّق فوري عند مغادرة الحقل** ⛔ لا عند الضغط فقط.
/// ② ★ **«التعديل على مستند معتمَد يفرض حقل سبب نصّي غير فارغ»** — ⟵ **حقل
///    السبب يظهر في التعديل وحده**، وهو نفسه `DEBT-21` ① و`ADR-0004`.
///
/// ⚠️⚠️ **وتحقّق الواجهة راحةٌ لا حماية:** نفس القواعد تُفحَص في السحابة
/// (`user_administration.dart` **مشتركةٌ بين الطرفين** — `ADR-0012`)، ⟵
/// **فلا يمرّ ما ترفضه السحابة ولو تجاوز أحدٌ هذه الشاشة.**
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qtms_domain/qtms_domain.dart';

import '../../../core/design/design_tokens.dart';
import '../../../core/messages/error_messages.dart';
import '../../../core/ui/inline_banner.dart';
import '../application/admin_providers.dart';
import '../../../core/ui/optional_reason.dart';

/// يفتح نموذج المستخدم — و[existing] `null` تعني **إنشاءً**.
Future<void> showUserForm(
  BuildContext context, {
  UserCard? existing,
}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: SemanticColors.surface,
      builder: (BuildContext context) => Padding(
        // ★ **الزر الأساسي فوق لوحة المفاتيح** — نمط 4 البند ④.
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: UserFormSheet(existing: existing),
      ),
    );

/// ورقة نموذج المستخدم.
class UserFormSheet extends ConsumerStatefulWidget {
  /// ينشئ الورقة.
  const UserFormSheet({this.existing, super.key});

  /// المستخدم المُعدَّل — و`null` تعني إنشاءً.
  final UserCard? existing;

  @override
  ConsumerState<UserFormSheet> createState() => _UserFormSheetState();
}

class _UserFormSheetState extends ConsumerState<UserFormSheet> {
  late final TextEditingController _name =
      TextEditingController(text: widget.existing?.name ?? '');
  late final TextEditingController _email =
      TextEditingController(text: widget.existing?.email ?? '');
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _amendReason = TextEditingController();

  /// ★ **رسالة الرفض من الكتالوج** — و`null` تعني **لا رفض بعد**.
  CatalogMessage? _rejection;

  /// ★ **تعطيل الحفظ أثناء الإرسال** — نمط 4، ⟵ **فلا إرسال مزدوج**
  /// يُنشئ مستخدمين اثنين بضغطتين متسارعتين.
  bool _submitting = false;

  bool get _isEdit => widget.existing != null;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _amendReason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.space16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              _isEdit ? 'تعديل مستخدم' : 'مستخدم جديد',
              style: TypeScale.titleLg,
            ),
            const SizedBox(height: Spacing.space16),
            _Field(controller: _name, label: 'الاسم', autofocus: true),
            const SizedBox(height: Spacing.space12),
            _Field(controller: _email, label: 'البريد الإلكتروني'),
            const SizedBox(height: Spacing.space12),
            _Field(controller: _phone, label: 'الهاتف (اختياري)'),
            if (_isEdit) ...<Widget>[
              const SizedBox(height: Spacing.space12),
              // ★★ **حقل السبب في التعديل وحده** — `ADR-0004` · `DEBT-21` ①.
              //   ⛔ **ولا يظهر في الإنشاء**: لا «قبل» قبل الإنشاء أصلاً.
              _Field(controller: _amendReason, label: 'سبب التعديل (اختياري)'),
            ],
            if (_rejection != null) ...<Widget>[
              const SizedBox(height: Spacing.space12),
              _RejectionBanner(message: _rejection!),
            ],
            const SizedBox(height: Spacing.space16),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: Text(_isEdit ? 'حفظ التعديل' : 'إنشاء'),
            ),
            // ⛔★★ **ولا حقل كلمة مرور هنا إطلاقاً** — `FR-M1-02`
            //    («لا يوجد حقل كلمة مرور في سجل المستخدم»)، ★ **ويضبطها
            //    صاحبُها برابط استرجاع** (`authentication-policy.md` §5:
            //    «الإدارة تُعيد التعيين لا تقرأ»).
            if (!_isEdit) ...<Widget>[
              const SizedBox(height: Spacing.space12),
              Text(
                'يصل المستخدمَ رابطٌ يضبط به كلمة مروره بنفسه.',
                style: TypeScale.bodyMd
                    .copyWith(color: SemanticColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    // ★ **القواعد من طبقة النطاق المشتركة** — ⛔ ولا تُعاد كتابتها هنا.
    final Outcome<ValidatedUserProfile> validated = validateUserProfile(
      UserProfileInput(
        name: _name.text,
        email: _email.text,
        phone: _phone.text,
      ),
    );
    if (validated is Failure<ValidatedUserProfile>) {
      // ⚠️ **رفضٌ محلي ⟵ ولا رحلة شبكة أصلاً** — نفس القاعدة التي سترفضه
      //    هناك ترفضه هنا، فيرى المستخدم النتيجة فوراً.
      setState(() => _rejection = CatalogMessage.operationFailed);
      return;
    }
    final ValidatedUserProfile profile =
        (validated as Success<ValidatedUserProfile>).value;

    setState(() {
      _submitting = true;
      _rejection = null;
    });

    final UserAdminRepository admin = ref.read(userAdminProvider);
    final Outcome<void> result = _isEdit
        ? await admin.update(
            userId: widget.existing!.userId,
            profile: profile,
            amendReason: blankToNull(_amendReason.text),
          )
        : _asVoid(await admin.create(profile));

    if (!mounted) return;
    switch (result) {
      case Failure<void>(:final AppError error):
        // ★ **الرفض يُعرَض ⛔ ولا يُبتلَع** — والورقة تبقى مفتوحة بمدخلاته،
        //   ⟵ **فلا يُعيد كتابتها من الصفر** بعد رفضٍ قابل للتصحيح.
        setState(() {
          _submitting = false;
          _rejection = appErrorMessage(error);
        });
      case Success<void>():
        Navigator.of(context).pop();
    }
  }

  static Outcome<void> _asVoid(Outcome<String> outcome) => switch (outcome) {
        Failure<String>(:final AppError error) => Failure<void>(error),
        Success<String>() => const Success<void>(null),
      };
}

/// شريط الرفض — ★ **نصّه من الكتالوج حرفياً** ⛔ **ولا صياغة هنا.**
class _RejectionBanner extends StatelessWidget {
  const _RejectionBanner({required this.message});

  final CatalogMessage message;

  @override
  Widget build(BuildContext context) => QtmsInlineBanner(
        text: catalogText(message),
        triad: SemanticTriads.danger,
      );
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String label;
  final bool autofocus;

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        // ★ **تركيز تلقائي على أول حقل** — نمط 4.
        autofocus: autofocus,
        decoration: InputDecoration(labelText: label),
      );
}

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

  /// ⚠️★★★ **كلمة المرور الأولية وتأكيدُها** — `CR-005` · **في الإنشاء وحده**.
  ///
  /// ⛔⛔ **ولا تُسجَّل ولا تُعرَض ولا تُنسَخ إلى أي حقلٍ آخر** — ★ **تُقرأ
  /// مرةً عند الإرسال وتُتلَف مع الورقة.**
  final TextEditingController _password = TextEditingController();
  final TextEditingController _passwordConfirm = TextEditingController();

  /// ★ هل تُعرَض الكلمة نصّاً ظاهراً؟ — ⛔ **والافتراض لا.**
  ///
  /// ★ **ولماذا يُتاح الكشف أصلاً:** ⟵ **المدير يكتب كلمةً سيُمليها على
  /// صاحبها**، ★ **ومنعُ الكشف يجعله يعيدها مرتين على الأعمى** ⛔ **فيُنشئ
  /// حساباً لا يُدخَل إليه.**
  bool _passwordVisible = false;

  /// ★★ **الدور المختار** — `AM-008` ③: **قائمة منسدلة** ⛔ **لا حقلَ نصّ.**
  ///
  /// ⚠️ **و`null` تعني «بلا دور» وهي قيمةٌ صحيحة** — `FR-M1-04`: **الأدوار
  /// قوالبُ بدايةٍ لا قيود** ⟵ **فمستخدمٌ بلا دورٍ حالةٌ مشروعة.**
  String? _roleId;

  /// ⛔★★ **ولا يُقرأ الدور القائم إلا مرةً واحدة** — ⟵ **فإعادةُ البناء
  /// أثناء الكتابة لا تُلغي اختيار المستخدم.**
  bool _roleInitialized = false;

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
    _password.dispose();
    _passwordConfirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<RoleCard> roles =
        ref.watch(rolesProvider).value ?? const <RoleCard>[];
    if (!_roleInitialized) {
      _roleInitialized = true;
      _roleId = widget.existing?.roleId;
    }
    // ⛔★★ **ودورٌ لا يقابله خيارٌ في القائمة يُعامَل «بلا دور»** — ⟵ **فلا
    //    ترمي القائمة المنسدلة على قيمةٍ لا خيار لها** (نفس علّة `_SourceField`
    //    في `context_header.dart`)، ★ **والحالة واقعية: دورٌ حُذف بينما
    //    الورقة مفتوحة** (`IQ-018`).
    final bool roleKnown =
        roles.any((RoleCard role) => role.roleId == _roleId);

    return SafeArea(
      // ★★ **والورقة تُمرَّر بالتمرير** — ⟵ **فحقول الإنشاء صارت سبعة**
      //    (`ui-guidelines.md` نمط 4: ≤ 8)، ⛔ **ولا تفيض على شاشةٍ قصيرة.**
      child: SingleChildScrollView(
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
            const SizedBox(height: Spacing.space12),
            // ★★★ **اختيار الدور بقائمة منسدلة** — `AM-008` ③:
            //    ⛔ **لا حقلَ نصٍّ ولا معرّفٌ يُكتب يدوياً**، ⟵ **ومعرّفٌ
            //    مكتوبٌ بحرفٍ ناقص كان يُنشئ مستخدماً بمرجعٍ ميت.**
            //
            // ★ **وتظهر في الإنشاء والتعديل معاً** — `FR-M1-01`.
            _RoleField(
              roles: roles,
              value: roleKnown ? _roleId : null,
              onChanged: (String? next) => setState(() => _roleId = next),
            ),
            // ⚠️★★★ **وكلمة المرور الأولية في الإنشاء وحده** — `CR-005`:
            //    ⛔⛔ **ولا تظهر في التعديل إطلاقاً** — ★ **«الإدارة لا تقرأ
            //    كلمةً قائمة»**، ⟵ **وحقلٌ فارغٌ في التعديل كان يُوهم بأن
            //    تركَه يُبقيها وملأَه يُغيّرها**، ⛔ **ولا مسارَ للثانية.**
            if (!_isEdit) ...<Widget>[
              const SizedBox(height: Spacing.space12),
              _Field(
                controller: _password,
                label: 'كلمة المرور الأولية',
                obscure: !_passwordVisible,
                onToggleVisibility: () =>
                    setState(() => _passwordVisible = !_passwordVisible),
                visible: _passwordVisible,
              ),
              const SizedBox(height: Spacing.space12),
              _Field(
                controller: _passwordConfirm,
                label: 'تأكيد كلمة المرور',
                obscure: !_passwordVisible,
              ),
            ],
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
            // ⚠️★★★ **وما يُقال للمدير بعد `CR-005`** — ⛔ **لا «يصل المستخدمَ
            //    رابط»**: ★ **الكلمةُ مضبوطةٌ بيده الآن**، ⟵ **ويبقى للمستخدم
            //    أن يغيّرها متى شاء** ⛔ **بلا إجبارٍ عند أول دخول وبلا مهلة**
            //    (§2.1 الحكم ③ من الطلب).
            //
            // ⛔⛔★★★ **ولا يُذكَر هنا حدُّ الطول رقماً بجانب الحقل ثم يُكرَّر
            //    في رسالة الرفض** — ★ **سطرٌ واحد يكفي**، ⛔ **ونصٌّ يصف
            //    القيمة المرفوضة يصف السرَّ جزئياً.**
            if (!_isEdit) ...<Widget>[
              const SizedBox(height: Spacing.space12),
              Text(
                'ثمانية محارف على الأقل. يبلّغها المديرُ صاحبَها، '
                'وله تغييرها متى شاء.',
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
        // ★★ **والدور من القائمة المنسدلة** — `AM-008` ③.
        roleId: _roleId,
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

    // ⚠️★★★ **وكلمة المرور الأولية تُفحَص محلياً بنفس دالة النطاق** —
    //    `CR-005` · `ADR-0012`: ⟵ **فلا رحلةَ شبكةٍ تنتهي برفضٍ كان يُعرَف
    //    قبلها**، ⛔ **والفحص يُعاد في الدالة السحابية ولا يُكتفى بهذا.**
    InitialPassword? password;
    if (!_isEdit) {
      final Outcome<InitialPassword> secret = validateInitialPassword(
        password: _password.text,
        confirmation: _passwordConfirm.text,
      );
      if (secret is Failure<InitialPassword>) {
        setState(() => _rejection = CatalogMessage.operationFailed);
        return;
      }
      password = (secret as Success<InitialPassword>).value;
    }

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
        // ⛔ **و`password!` آمنٌ بنيوياً هنا** — ★ **الفرع `!_isEdit` وحده
        //   يصل هذا السطر**، ⟵ **وقد أُسنِدت أعلاه في الفرع نفسِه.**
        : _asVoid(await admin.create(profile, password: password!));

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
    this.obscure = false,
    this.onToggleVisibility,
    this.visible = false,
  });

  final TextEditingController controller;
  final String label;
  final bool autofocus;

  /// ★ **يُخفي المُدخَل** — ⛔ **والافتراض لا** (`CR-005`).
  final bool obscure;

  /// ★ زرّ كشف الكلمة — و`null` تعني **لا زرّ** (حقلُ التأكيد يتبع الأول).
  final VoidCallback? onToggleVisibility;

  /// هل الكلمة مكشوفة الآن؟ — ★ **يُغيّر الأيقونة والوصف معاً.**
  final bool visible;

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        // ★ **تركيز تلقائي على أول حقل** — نمط 4.
        autofocus: autofocus,
        obscureText: obscure,
        // ⛔⛔★★ **ولا تعبئةً تلقائية ولا اقتراحاً ولا تصحيحاً على السرّ** —
        //    ★ **لوحاتُ المفاتيح تتعلّم ما يُكتب فيها**، ⟵ **وكلمةٌ تدخل
        //    قاموسَ الجهاز تظهر لاحقاً في حقلٍ آخر لمستخدمٍ آخر.**
        autocorrect: !obscure,
        enableSuggestions: !obscure,
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: switch (onToggleVisibility) {
            final VoidCallback toggle => IconButton(
                onPressed: toggle,
                icon: Icon(
                  visible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                ),
                tooltip: visible ? 'إخفاء كلمة المرور' : 'إظهار كلمة المرور',
              ),
            null => null,
          },
        ),
      );
}

/// ★★★ **حقل الدور — قائمة منسدلة** (`AM-008` ③).
///
/// ⛔⛔ **ولا حقلَ نصٍّ يُكتب فيه معرّفُ الدور** — ★ **حرفٌ ناقصٌ كان يُنشئ
/// مستخدماً بمرجعٍ ميت**، ⟵ **فتُعرَض أدوارُه فارغة وتنكسر «مقارنة المستخدم
/// بدوره»** (`FR-M1-16`).
///
/// ★★ **وخيار «بلا دور» صريحٌ في القائمة** — `FR-M1-04`: **الأدوار قوالبُ
/// بدايةٍ لا قيود** ⟵ **فالغياب اختيارٌ مشروع** ⛔ **لا نقصُ إدخال.**
class _RoleField extends StatelessWidget {
  const _RoleField({
    required this.roles,
    required this.value,
    required this.onChanged,
  });

  final List<RoleCard> roles;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String?>(
        initialValue: value,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'الدور'),
        items: <DropdownMenuItem<String?>>[
          const DropdownMenuItem<String?>(child: Text('بلا دور')),
          for (final RoleCard role in roles)
            DropdownMenuItem<String?>(
              value: role.roleId,
              child: Text(role.name, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: onChanged,
      );
}

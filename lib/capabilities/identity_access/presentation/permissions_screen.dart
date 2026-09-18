/// شاشة تخصيص الصلاحيات — `FR-M1-05` · `FR-M1-06` · `FR-M1-16`.
///
/// ★★ **وهي أخطر شاشة في التطبيق** — ولذلك كل قرار فيها مكتوبٌ مرتين:
/// **مرةً هنا للعرض، ومرةً في `validatePermissionGrant` للحسم** — ⛔ **والثانية
/// وحدها هي الحماية** (`ADR-0013` القاعدة 3 · الأثر السلبي المعلَن في الـADR).
///
/// **القيود الأربعة التي تعرضها هذه الشاشة ولا تفرضها:**
///
/// | القيد | مصدره | أين يُفرَض فعلاً |
/// |---|---|---|
/// | ⛔ **لا يعدّل صلاحيات نفسه — ولو المالك** | `authentication-policy.md` §3 | `validatePermissionGrant` ① |
/// | ⛔ **لا يمنح ما لا يملك** | `BR-M1-03` · `FR-M1-08` | `validatePermissionGrant` ② |
/// | ⛔ **لا يوسّع النطاق فوق نطاقه** | `FR-M1-08` | `validatePermissionGrant` ③ · `scopeIsWithin` |
/// | ⛔ **لا كتابة مباشرة على `users`** | `BR-M1-08` · `FR-M1-09` | `firestore.rules`: `allow write: if false` |
///
/// ⚠️⚠️ **فلو حُذفت هذه الشاشة كلها لبقيت القيود الأربعة نافذة** — ★ **وهو
/// المعيار الذي يُفرِّق الإخفاء عن الحماية** (`RISK-02`).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qtms_domain/qtms_domain.dart';

import '../../../app/top_bar.dart';

import '../../../core/design/design_tokens.dart';
import '../../../core/ui/inline_banner.dart';
import '../../../core/ui/skeleton.dart';
import '../../../core/messages/error_messages.dart';
import '../../master_data/application/master_data_providers.dart';
import '../application/admin_providers.dart';
import '../application/session_providers.dart';
import 'permission_tree.dart';

/// شاشة تخصيص صلاحيات مستخدم واحد.
class PermissionsScreen extends ConsumerWidget {
  /// ينشئ الشاشة لمستخدم بمعرّفه.
  const PermissionsScreen({required this.userId, super.key});

  /// المستخدم المستهدَف.
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<UserCard>> users = ref.watch(usersProvider);
    final AuthSession? actor = ref.watch(currentSessionProvider);

    return Scaffold(
      appBar: QtmsTopBar(screenTitle: 'تخصيص الصلاحيات'),
      body: switch (users) {
        AsyncValue<List<UserCard>>(hasError: true) =>
          const _Notice(message: CatalogMessage.permissionMissing),
        AsyncValue<List<UserCard>>(value: final List<UserCard> list?) =>
          _resolve(list, actor),
        // ⛔⛔★★★ **ولا مؤشّرَ دوّار وسط الشاشة** — `design-system.md` §هـ
        //    يمنعه نصّاً ويجعل **الهيكل العظمي حالةَ التحميل الوحيدة**:
        //    ⟵ **والدوّار لا يحجز مساحة**، ★ **فوصولُ البيانات يُقفِز
        //    التخطيط دفعةً واحدة** بينما الهيكل يحجز مكانَ المحتوى.
        _ => const SkeletonList(),
      },
    );
  }

  Widget _resolve(List<UserCard> users, AuthSession? actor) {
    if (actor == null) return const SizedBox.shrink();
    final UserCard? target = users
        .where((UserCard user) => user.userId == userId)
        .firstOrNull;
    // ⛔ **مستخدمٌ لا وجود له** — ⟵ ولا شاشة صامتة.
    if (target == null) {
      return const _Notice(message: CatalogMessage.operationFailed);
    }
    // ⛔★★ **ولا يعدّل أحدٌ صلاحيات نفسه — ولو المالك**
    //    (`authentication-policy.md` §3). ⚠️⚠️ **وهذا منعُ عرضٍ لا حماية**:
    //    الحارس الفعلي `validatePermissionGrant` ① يرفض الطلب نفسه.
    if (target.userId == actor.userId) {
      return const _SelfNotice();
    }
    return _PermissionsEditor(target: target, actor: actor, users: users);
  }
}

/// ★ إشعارٌ صريح بأن تعديل صلاحيات النفس ممنوع — ⛔ **لا شاشة فارغة**.
class _SelfNotice extends StatelessWidget {
  const _SelfNotice();

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.space24),
          child: Text(
            // ★ **نصٌّ يشرح القاعدة** — ⛔ لا رمز ولا رسالة عامة تُوهم بعطل.
            'لا يمكن لأي مستخدم تعديل صلاحيات حسابه — ولو كان المالك.',
            textAlign: TextAlign.center,
            style: TypeScale.bodyMd
                .copyWith(color: SemanticColors.textSecondary),
          ),
        ),
      );
}

class _Notice extends StatelessWidget {
  const _Notice({required this.message});

  final CatalogMessage message;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.space24),
          child: Text(
            catalogText(message),
            textAlign: TextAlign.center,
            style: TypeScale.bodyMd
                .copyWith(color: SemanticColors.textSecondary),
          ),
        ),
      );
}

class _PermissionsEditor extends ConsumerStatefulWidget {
  const _PermissionsEditor({
    required this.target,
    required this.actor,
    required this.users,
  });

  final UserCard target;
  final AuthSession actor;
  final List<UserCard> users;

  @override
  ConsumerState<_PermissionsEditor> createState() => _PermissionsEditorState();
}

class _PermissionsEditorState extends ConsumerState<_PermissionsEditor> {
  late Set<Permission> _selected = <Permission>{...widget.target.permissions};
  late SourceScope? _scope = widget.target.sourceScope;

  CatalogMessage? _rejection;

  /// ★ نجاحٌ ظاهر — ⛔ **ولا ورقةٌ تُغلَق بصمت** فيظنّ المدير أنه لم يُحفَظ.
  bool _saved = false;
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    final RoleCard? role = _roleOf(widget.target);
    return ListView(
      padding: const EdgeInsets.all(Spacing.space16),
      children: <Widget>[
        _Header(target: widget.target, role: role),
        const SizedBox(height: Spacing.space16),
        // ★★ **مساعدات `FR-M1-16`** — نسخُ صلاحيات مستخدم ومقارنةٌ بالدور.
        _Helpers(
          users: widget.users,
          target: widget.target,
          role: role,
          onCopy: _copyFrom,
          onApplyRole: role == null ? null : () => _applyRole(role),
        ),
        const SizedBox(height: Spacing.space16),
        _ScopeEditor(
          actorScope: widget.actor.sourceScope,
          value: _scope,
          candidates: _scopeCandidates(),
          onChanged: (SourceScope? scope) => setState(() {
            _scope = scope;
            _saved = false;
          }),
        ),
        const SizedBox(height: Spacing.space16),
        PermissionTree(
          selected: _selected,
          // ★★ **ما يجوز تبديله = ما يملكه المُنفِّذ** (`BR-M1-03`).
          //   ⚠️⚠️ **عرضٌ لا حماية** — راجع ترويسة `permission_tree.dart`.
          grantable: widget.actor.permissions,
          roleTemplate: role?.permissionTemplate,
          onChanged: (Set<Permission> next) => setState(() {
            _selected = next;
            _saved = false;
          }),
        ),
        if (_rejection case final CatalogMessage message) ...<Widget>[
          const SizedBox(height: Spacing.space12),
          QtmsInlineBanner(
            text: catalogText(message),
            triad: SemanticTriads.danger,
          ),
        ],
        if (_saved) ...<Widget>[
          const SizedBox(height: Spacing.space12),
          const QtmsInlineBanner(
            // ★ **حالة نجاح حقيقية** — ⛔ لا صمت بعد عملية نجحت فعلاً.
            text: '✅ حُفظت الصلاحيات.',
            triad: SemanticTriads.primary,
          ),
        ],
        const SizedBox(height: Spacing.space16),
        FilledButton(
          onPressed: _submitting || _scope == null ? null : _submit,
          child: const Text('حفظ الصلاحيات'),
        ),
        if (_scope == null)
          Padding(
            padding: const EdgeInsets.only(top: Spacing.space8),
            child: Text(
              // ⛔ **نطاق فارغ يمنع كل شيء** — راجع `ScopedSources`.
              'اختر نطاق المصادر قبل الحفظ.',
              textAlign: TextAlign.center,
              style: TypeScale.bodyMd
                  .copyWith(color: SemanticColors.textSecondary),
            ),
          ),
      ],
    );
  }

  RoleCard? _roleOf(UserCard user) {
    final String? roleId = user.roleId;
    if (roleId == null) return null;
    return ref
        .watch(rolesProvider)
        .value
        ?.where((RoleCard role) => role.roleId == roleId)
        .firstOrNull;
  }

  /// ★ مصادرُ يمكن عرضها — **من بيانات فعلية وحدها**.
  ///
  /// ⚠️ **وحدٌّ معلَن في هذه الزيادة:** مجموعة `sources` تُبنى في `WU-002`،
  /// ⟵ **فلا قائمة مصادر كاملة بعد**. ★ **والمعروض هنا نطاقُ المُنفِّذ نفسه
  /// ونطاقُ المستهدَف الحالي** — ⛔ **ولا معرّف مخترَع**، وهو ما يكفي
  /// لتضييق نطاقٍ قائم أو نقله ضمن حدود المُنفِّذ.
  Set<String> _scopeCandidates() => <String>{
        if (widget.actor.sourceScope case ScopedSources(
              :final Set<String> sourceIds,
            ))
          ...sourceIds,
        if (widget.target.sourceScope case ScopedSources(
              :final Set<String> sourceIds,
            ))
          ...sourceIds,
      };

  /// ★★ **نسخ صلاحيات مستخدم إلى آخر** — `FR-M1-16` البند ②.
  ///
  /// ⚠️ **والنسخ اقتراحٌ لا حفظ** — ⟵ **يملأ الشجرة ولا يُرسل شيئاً**،
  /// ★ **فيراجعه المدير قبل الحفظ** ⛔ ولا ينسخ صلاحيةً وهو لا يدري.
  void _copyFrom(UserCard source) => setState(() {
        _selected = <Permission>{...source.permissions};
        _saved = false;
      });

  /// ★ **إعادة المستخدم إلى قالب دوره** — `FR-M1-05` (إلغاء التخصيص الفردي).
  void _applyRole(RoleCard role) => setState(() {
        _selected = <Permission>{...role.permissionTemplate};
        _saved = false;
      });

  Future<void> _submit() async {
    final SourceScope? scope = _scope;
    if (scope == null) return;

    setState(() {
      _submitting = true;
      _rejection = null;
      _saved = false;
    });

    // ★★ **العملية السحابية المخصَّصة وحدها** — `FR-M1-09` · `BR-M1-08`.
    //   ⛔ **ولا كتابة مباشرة على `users`**: القاعدة `allow write: if false`.
    final Outcome<void> result = await ref.read(userAdminProvider).grantAccess(
          userId: widget.target.userId,
          permissions: _selected,
          scope: scope,
        );

    if (!mounted) return;
    switch (result) {
      case Failure<void>(:final AppError error):
        // ★★ **الرفض الحقيقي بنصّه** — ⟵ **فمن حاول منح ما لا يملك يرى
        //   `ERR_AUTH_007`** لا رسالةً عامة لا تُرشده.
        setState(() {
          _submitting = false;
          _rejection = appErrorMessage(error);
        });
      case Success<void>():
        setState(() {
          _submitting = false;
          _saved = true;
        });
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.target, required this.role});

  final UserCard target;
  final RoleCard? role;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(Spacing.space16),
        decoration: BoxDecoration(
          color: SemanticColors.surface,
          border: Border.all(color: SemanticColors.border),
          borderRadius: BorderRadius.circular(Radii.card),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(target.name, style: TypeScale.titleSm),
            const SizedBox(height: Spacing.space4),
            Text(
              role?.name ?? 'بلا دور',
              style: TypeScale.bodyMd
                  .copyWith(color: SemanticColors.textSecondary),
            ),
          ],
        ),
      );
}

/// مساعدات `FR-M1-16` — **النسخ والمقارنة**.
class _Helpers extends StatelessWidget {
  const _Helpers({
    required this.users,
    required this.target,
    required this.role,
    required this.onCopy,
    required this.onApplyRole,
  });

  final List<UserCard> users;
  final UserCard target;
  final RoleCard? role;
  final ValueChanged<UserCard> onCopy;
  final VoidCallback? onApplyRole;

  @override
  Widget build(BuildContext context) {
    final List<UserCard> others = <UserCard>[
      for (final UserCard user in users)
        if (user.userId != target.userId) user,
    ];
    return Wrap(
      spacing: Spacing.space8,
      runSpacing: Spacing.space8,
      children: <Widget>[
        if (others.isNotEmpty)
          PopupMenuButton<UserCard>(
            onSelected: onCopy,
            itemBuilder: (BuildContext context) => <PopupMenuEntry<UserCard>>[
              for (final UserCard user in others)
                PopupMenuItem<UserCard>(
                  value: user,
                  child: Text(user.name),
                ),
            ],
            child: const _HelperChip(
              icon: Icons.content_copy_outlined,
              label: 'نسخ صلاحيات مستخدم',
            ),
          ),
        if (onApplyRole != null)
          InkWell(
            onTap: onApplyRole,
            child: const _HelperChip(
              icon: Icons.restart_alt,
              label: 'إعادة إلى قالب الدور',
            ),
          ),
      ],
    );
  }
}

class _HelperChip extends StatelessWidget {
  const _HelperChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.space12,
          vertical: Spacing.space8,
        ),
        decoration: BoxDecoration(
          color: SemanticColors.surfaceSunken,
          border: Border.all(color: SemanticColors.border),
          borderRadius: BorderRadius.circular(Radii.field),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 18, color: SemanticColors.textSecondary),
            const SizedBox(width: Spacing.space8),
            Text(label, style: TypeScale.bodyMd),
          ],
        ),
      );
}

/// ★★ محرّر نطاق المصادر — `FR-M1-06` · `FR-M1-08`.
///
/// ⚠️⚠️ **وكل تضييق هنا عرضٌ لا حماية:** `scopeIsWithin` تُفرَض في
/// `validatePermissionGrant` ③، ⟵ **فتوسيعٌ يتجاوز نطاق المُنفِّذ يُرفَض
/// بـ`ERR_AUTH_002`** ولو تجاوز أحدٌ هذه الشاشة.
class _ScopeEditor extends ConsumerWidget {
  const _ScopeEditor({
    required this.actorScope,
    required this.value,
    required this.candidates,
    required this.onChanged,
  });

  final SourceScope? actorScope;
  final SourceScope? value;
  final Set<String> candidates;
  final ValueChanged<SourceScope?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ★ **«كل المصادر» لا تُعرَض إلا لمن يملكها** — `scopeIsWithin` ترفض
    //   `all` داخل قائمة محدودة مهما طالت، ⟵ **فعرضُها كان سيَعِد بما يُرفَض.**
    final bool canGrantAll = actorScope is AllSources;
    final List<String> sorted = candidates.toList()..sort();
    return Container(
      padding: const EdgeInsets.all(Spacing.space16),
      decoration: BoxDecoration(
        color: SemanticColors.surface,
        border: Border.all(color: SemanticColors.border),
        borderRadius: BorderRadius.circular(Radii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'نطاق المصادر',
            style: TypeScale.titleSm
                .copyWith(color: SemanticColors.textSecondary),
          ),
          if (canGrantAll)
            CheckboxListTile(
              // ⚠️ **القيمة من الحالة الحقيقية** — ⛔ ولا حالة محلية ثانية
              //    تفترق عنها فتعرض غير ما يُرسَل.
              value: value is AllSources,
              // ★ **وإطفاؤه يُفرغ النطاق لا يضيّقه ضمناً** — ⟵ **فيلزم
              //   اختيارٌ صريح**، ⛔ ولا نطاق يُخمَّن نيابةً عن المدير.
              onChanged: (bool? on) =>
                  onChanged(on ?? false ? const AllSources() : null),
              title: const Text('كل المصادر'),
            ),
          // ★★ **حالةٌ حقيقية لا نظرية:** مستهدَفٌ نطاقه «كل المصادر»
          //   ومُنفِّذٌ نطاقه محدود. ⟵ **فلا يستطيع إبقاء نطاقه كما هو**
          //   (`scopeIsWithin` ترفض `all` داخل قائمة)، ★ **ويجب أن يرى
          //   السبب ويرى ما يستطيع** — ⛔ **لا محرّرٌ فارغ يبدو عطلاً.**
          if (value is AllSources && !canGrantAll)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Spacing.space8),
              child: Text(
                'نطاق هذا المستخدم الآن «كل المصادر»، وهو أوسع من نطاقك — '
                'والحفظ سيقصره على ما تختاره أدناه.',
                style: TypeScale.bodyMd
                    .copyWith(color: SemanticTriads.warning.ink),
              ),
            ),
          // ⛔ **والقائمة المحدَّدة لا تُخلَط بـ«الكل»** — `AllSources` تشمل
          //    ما سيُضاف مستقبلاً، **والقائمة لا تشمله أبداً** (`FR-M1-06`).
          //    ★ **إلا حين يعجز المُنفِّذ عن منح «الكل» أصلاً** — فعندئذٍ
          //    القائمةُ هي كلُّ ما يملكه.
          if (value is! AllSources || !canGrantAll)
            for (final String sourceId in sorted)
              CheckboxListTile(
                value: value is ScopedSources &&
                    (value! as ScopedSources).sourceIds.contains(sourceId),
                onChanged: (bool? on) => onChanged(
                  _toggled(sourceId, on ?? false),
                ),
                // ⛔⛔★★★ **والمصدرُ باسمه لا بمعرّفه** — `AM-018` ·
                //   `design-system.md` §8 المحظور 13: ⟵ **ومعرّفٌ خامٌّ في
                //   أخطر شاشةٍ في التطبيق يجعل المديرَ يمنح نطاقاً لا يعرف
                //   ما هو.** ★ **وبالدالة نفسِها المستعملة في كشف حساب
                //   المقوت والتوزيع** ⛔ **لا نسخةٌ ثانية.**
                title: Text(_scopeLabel(ref, sourceId)),
              ),
          if (sorted.isEmpty && !canGrantAll)
            Padding(
              padding: const EdgeInsets.only(top: Spacing.space8),
              child: Text(
                // ⛔ **حدٌّ معلَن لا عطل صامت** — راجع `_scopeCandidates`.
                'لا مصادر متاحة ضمن نطاقك.',
                style: TypeScale.bodyMd
                    .copyWith(color: SemanticColors.textSecondary),
              ),
            ),
        ],
      ),
    );
  }

  /// ★★ **اسمُ المصدر المقروء** — `AM-018`.
  ///
  /// ⛔⛔ **وحيث يتعذّر إيجادُه: «مصدر غير معروف (المعرّف)»** — ⛔ **لا
  /// المعرّفُ عارياً**: ⟵ **فالمديرُ يعرف أن المصدرَ لم يعد في الكتالوج**،
  /// ★ **ويبقى المعرّفُ مذكوراً ليُتتبَّع** ⛔ **ولا يُخفى.**
  ///
  /// ⚠️★★ **والحالةُ واقعةٌ لا نظرية** — ★ **[_PermissionsEditorState._scopeCandidates]
  /// تجمع معرّفاتِ نطاقِ المُنفِّذ والمستهدَف معاً** ⛔ **لا من كتالوج المصادر**:
  /// ⟵ **فمعرّفٌ في نطاقِ مستخدمٍ قديمٍ قد لا يقابله مستندُ مصدرٍ مقروء.**
  ///
  /// ★ **و[sourceDisplayNameProvider] تقع على المعرّف عند الغياب** (`CR-004`
  /// — **معرّفٌ صادقٌ خيرٌ من فراغٍ في وثيقةٍ تُسلَّم**): ⟵ **فالتساوي هو
  /// مقياسُ «لم يُوجَد»** ⛔ **ولا يُغيَّر سلوكُ المزوّد للوثيقة المُصدَّرة.**
  String _scopeLabel(WidgetRef ref, String sourceId) {
    final String name = ref.watch(sourceDisplayNameProvider(sourceId));
    return name == sourceId ? 'مصدر غير معروف ($sourceId)' : name;
  }

  /// ★ يبني النطاق بعد التبديل — و`null` عند تفريغ القائمة.
  ///
  /// ⚠️ **ولا [ScopedSources] فارغة أبداً** — المُنشِئ يرمي عليها عمداً
  /// («النطاق الفارغ يمنع كل شيء»)، ⟵ **فالفارغ يُمثَّل بـ`null` ويمنع
  /// الحفظ** ⛔ **لا بانهيار الشاشة.**
  SourceScope? _toggled(String sourceId, bool on) {
    final Set<String> next = <String>{
      if (value case ScopedSources(:final Set<String> sourceIds)) ...sourceIds,
    };
    if (on) {
      next.add(sourceId);
    } else {
      next.remove(sourceId);
    }
    return next.isEmpty ? null : ScopedSources(next);
  }
}

// ⛔★★ **والشريطُ المحلي رُفِع إلى `lib/core/ui/inline_banner.dart`** (`AM-007`)
//    — ★ **كان منسوخاً في سبع شاشات ويستدعي الطبقة الأولية مباشرةً.**

/// شجرة الصلاحيات — ★ **بحثٌ فوري بالاسم العربي** (`FR-M1-16` البند ①).
///
/// ★★ **وهي عنصرٌ مشترك بين شاشتين عمداً:** قالب الدور (`FR-M1-03`)
/// وتخصيص الصلاحيات الفردية (`FR-M1-05`). ⟵ **فالمدير يرى الشجرة نفسها
/// بترتيبها نفسه في الموضعين**، ⛔ **ولا نسختان تفترقان عند أول إضافة مفتاح.**
///
/// ⚠️⚠️ **وكل إخفاء أو تعطيل هنا عرضٌ لا حماية** — `identity-access-design.md`
/// §6: «كل إخفاء **يجب أن يقابله شرط في قواعد الحماية**». ★ **والحارس
/// الحقيقي `validatePermissionGrant`** في طبقة النطاق، **تفرضه العملية
/// السحابية `grantPermissions`** (`BR-M1-03` · `ADR-0013` القاعدة 3).
/// ⟵ **فمن تجاوز هذه الشاشة يُرفَض هناك** بـ`ERR_AUTH_007`.
library;

import 'package:flutter/material.dart';
import 'package:qtms_domain/qtms_domain.dart';

import '../../../core/design/design_tokens.dart';
import '../../../core/messages/permission_labels.dart';
import '../../../core/ui/search_field.dart';

/// ★ حالة مفتاحٍ في المقارنة مع قالب الدور — `FR-M1-05` · `FR-M1-16` ③.
enum PermissionDelta {
  /// مطابق للقالب — ممنوحٌ فيه وممنوحٌ للمستخدم، أو غائبٌ عنهما.
  sameAsRole,

  /// ★ **منحٌ فردي فوق القالب** — `FR-M1-05` («منحاً»).
  grantedBeyondRole,

  /// ★ **سحبٌ فردي دون القالب** — `FR-M1-05` («أو سحباً»).
  revokedFromRole,
}

/// شجرة الصلاحيات القابلة للتحرير.
class PermissionTree extends StatefulWidget {
  /// ينشئ الشجرة.
  const PermissionTree({
    required this.selected,
    required this.onChanged,
    this.grantable,
    this.roleTemplate,
    this.readOnly = false,
    super.key,
  });

  /// المفاتيح المحدَّدة الآن.
  final Set<Permission> selected;

  /// يُستدعى بالمجموعة الجديدة بعد كل تبديل.
  final ValueChanged<Set<Permission>> onChanged;

  /// ★★ ما **يجوز للمُنفِّذ تبديله** — و`null` تعني **الكل** (قالب الدور).
  ///
  /// ⚠️⚠️ **وتعطيلُ ما سواه عرضٌ لا حماية:** `BR-M1-03` تُفرَض في السحابة،
  /// ⟵ **وهذا يمنع رحلةً تنتهي برفض** ⛔ **ولا يُغني عن الحارس هناك.**
  ///
  /// ★ **ولماذا تُعرَض المعطَّلة ولا تُخفى:** إخفاؤها يجعل المدير يظن أن
  /// الصلاحية **غير موجودة في النظام**، ⟵ **فيبحث عن عطل**؛ وعرضُها
  /// معطَّلةً يقول له الحقيقة: **هي موجودة وأنت لا تملكها فلا تمنحها.**
  final Set<Permission>? grantable;

  /// قالب دور المستخدم — لإظهار المقارنة (`FR-M1-16` ③). و`null` تعني **بلا دور**.
  final Set<Permission>? roleTemplate;

  /// عرضٌ فقط — ⛔ بلا تبديل.
  final bool readOnly;

  @override
  State<PermissionTree> createState() => _PermissionTreeState();
}

class _PermissionTreeState extends State<PermissionTree> {
  final TextEditingController _search = TextEditingController();

  /// نصّ البحث **مقصوصاً ومُطبَّعاً** — ★ **من مصدر التطبيع الواحد**
  /// (`IQ-013`) ⛔ **لا تطبيع محلي** يجعل «الإدخال» لا يطابق «الادخال».
  String _query = '';

  @override
  void initState() {
    super.initState();
    _search.addListener(
      () => setState(() => _query = normalizeName(_search.text)),
    );
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<PermissionGroup> visible = <PermissionGroup>[
      for (final PermissionGroup group in permissionGroups)
        if (_matching(group) case final List<Permission> keys
            when keys.isNotEmpty)
          PermissionGroup(title: group.title, permissions: keys),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // ★ **بحث فوري بالاسم العربي** — `FR-M1-16` ①.
        //
        // ★★ **وصياغتُه [QtmsSearchField]** (§5 «سرد» · `ADR-0021`) —
        //    ⛔ **ولا حقلَ بحثٍ محليٌّ بعد اليوم** (§8 المحظور الحادي عشر).
        QtmsSearchField(
          controller: _search,
          label: 'بحث في الصلاحيات',
        ),
        const SizedBox(height: Spacing.space12),
        if (visible.isEmpty)
          // ★ **حالة «لا نتيجة» صريحة** — ⛔ ولا شجرةٌ فارغة صامتة.
          const QtmsNoMatch(message: 'لا صلاحية بهذا الاسم.')
        else
          for (final PermissionGroup group in visible)
            _Group(
              group: group,
              selected: widget.selected,
              grantable: widget.grantable,
              roleTemplate: widget.roleTemplate,
              readOnly: widget.readOnly,
              onToggle: _toggle,
            ),
      ],
    );
  }

  List<Permission> _matching(PermissionGroup group) => <Permission>[
        for (final Permission permission in group.permissions)
          if (_query.isEmpty ||
              normalizeName(permissionLabel(permission)).contains(_query))
            permission,
      ];

  /// ★★★ يبدّل مفتاحاً — **ومعه سلسلةُ اشتراطه** (`IQ-040`).
  ///
  /// ═══════════════════════════════════════════════════════════════════
  /// ⛔⛔★★★ **ولماذا بنيوياً هنا لا رسالةَ خطأٍ بعد الحفظ:**
  /// ★ **`validatePermissionGrant` القاعدة ④ ترفض مجموعةً فيها مفتاحٌ بلا
  ///    مانحه المسبق** — ⟵ **ورفضُها `PermissionError` مجرَّدة**:
  ///    ⛔ **فمديرٌ يؤشّر «عرض كشف حساب المقوت» وحدَه يرى «ليست لديك صلاحية»
  ///    وهو يملكها فعلاً.** ★ **والعلاج أن تكون المجموعةُ المعروضة صحيحةً
  ///    دائماً** ⛔ **لا أن يُشرَح خطأٌ كان يمكن منعُه.**
  ///
  /// ⚠️ **والاتجاهان لازمان معاً:** ★ **التأشيرُ يجرّ المانحَ المسبق صعوداً**،
  ///    ★ **وإزالتُه تُسقِط ما يعتمد عليه نزولاً** — ⛔ **وإسقاطُ أحدهما يترك
  ///    الشاشةَ تبني مجموعةً ترفضها السحابة.**
  ///
  /// ⚠️⚠️ **وهذا تصحيحُ عرضٍ لا تخفيفُ حراسة** (`RISK-02`): ★ **الحارسُ يبقى
  ///    في طبقة النطاق وتفرضه العمليةُ الكاتبة** (`permission_sync.dart`).
  /// ═══════════════════════════════════════════════════════════════════
  void _toggle(Permission permission, bool on) {
    final Set<Permission> next = <Permission>{...widget.selected};
    if (on) {
      next.add(permission);
      // ① صعوداً — ★ **كلُّ مانحٍ مسبقٍ في السلسلة** ⛔ **لا الأقربَ وحدَه.**
      for (Permission? need = permission.grantPrerequisite;
          need != null;
          need = need.grantPrerequisite) {
        if (!next.add(need)) break; // ★ كان مؤشَّراً — فما فوقه مؤشَّرٌ كذلك.
      }
    } else {
      next.remove(permission);
      // ② نزولاً — ★ **حتى الاستقرار**: ⟵ **فسلسلةٌ من ثلاثةٍ تُسقَط كاملةً.**
      bool changed = true;
      while (changed) {
        changed = false;
        final Set<Permission> orphans = <Permission>{
          for (final Permission held in next)
            if (held.grantPrerequisite case final Permission need)
              if (!next.contains(need)) held,
        };
        for (final Permission orphan in orphans) {
          if (next.remove(orphan)) changed = true;
        }
      }
    }
    widget.onChanged(next);
  }
}

class _Group extends StatelessWidget {
  const _Group({
    required this.group,
    required this.selected,
    required this.grantable,
    required this.roleTemplate,
    required this.readOnly,
    required this.onToggle,
  });

  final PermissionGroup group;
  final Set<Permission> selected;
  final Set<Permission>? grantable;
  final Set<Permission>? roleTemplate;
  final bool readOnly;
  final void Function(Permission, bool) onToggle;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: Spacing.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Spacing.space8),
              child: Text(
                group.title,
                style: TypeScale.titleSm
                    .copyWith(color: SemanticColors.textSecondary),
              ),
            ),
            for (final Permission permission in group.permissions)
              _PermissionRow(
                permission: permission,
                checked: selected.contains(permission),
                // ★ `null` في [grantable] تعني **الكل قابل للتبديل**.
                enabled: !readOnly && (grantable?.contains(permission) ?? true),
                delta: _deltaOf(permission),
                onToggle: onToggle,
              ),
          ],
        ),
      );

  /// ★ المقارنة مع القالب — و`null` تعني **لا دور فلا مقارنة**.
  PermissionDelta? _deltaOf(Permission permission) {
    final Set<Permission>? template = roleTemplate;
    if (template == null) return null;
    final bool inTemplate = template.contains(permission);
    final bool granted = selected.contains(permission);
    if (inTemplate == granted) return PermissionDelta.sameAsRole;
    return granted
        ? PermissionDelta.grantedBeyondRole
        : PermissionDelta.revokedFromRole;
  }
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    required this.permission,
    required this.checked,
    required this.enabled,
    required this.delta,
    required this.onToggle,
  });

  final Permission permission;
  final bool checked;
  final bool enabled;
  final PermissionDelta? delta;
  final void Function(Permission, bool) onToggle;

  @override
  Widget build(BuildContext context) => Row(
        children: <Widget>[
          Checkbox(
            value: checked,
            onChanged: enabled
                ? (bool? on) => onToggle(permission, on ?? false)
                : null,
          ),
          Expanded(
            child: Text(
              // ★ **الاسم العربي من الكتالوج** — ⛔ ولا مفتاح تقني معروض.
              permissionLabel(permission),
              style: TypeScale.bodyMd.copyWith(
                color: enabled
                    ? SemanticColors.textPrimary
                    : SemanticColors.textTertiary,
              ),
            ),
          ),
          if (delta case final PermissionDelta value
              when value != PermissionDelta.sameAsRole)
            _DeltaBadge(delta: value),
          if (!enabled)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: Spacing.space8),
              child: Text(
                // ★ **سببُ التعطيل مكتوب** — ⟵ **فلا يظنّه المدير عطلاً**.
                'لا تملكها',
                style: TypeScale.bodyMd
                    .copyWith(color: SemanticColors.textTertiary),
              ),
            ),
        ],
      );
}

/// ★★ شارة الفرق عن قالب الدور — `FR-M1-05` («تظهر في مقارنة المستخدم بدوره»).
class _DeltaBadge extends StatelessWidget {
  const _DeltaBadge({required this.delta});

  final PermissionDelta delta;

  @override
  Widget build(BuildContext context) {
    final bool added = delta == PermissionDelta.grantedBeyondRole;
    // ★★ **ثلاثيةٌ واحدة تُختار ثم تُقرأ أطرافُها** (`AM-007` · §3.3) —
    //    ⛔ **لا ثلاثةُ شروطٍ منفصلة على ثلاث قيم**: ⟵ **الشرطُ المكرَّر ثلاثاً
    //    يسمح بخلط تعبئةٍ من عائلةٍ مع نصٍّ من أخرى بسهوٍ واحد.**
    final ColorTriad triad =
        added ? SemanticTriads.primary : SemanticTriads.warning;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.space8,
        vertical: Spacing.space4,
      ),
      decoration: BoxDecoration(
        color: triad.soft,
        border: Border.all(color: triad.border),
        borderRadius: BorderRadius.circular(Radii.field),
      ),
      child: Text(
        added ? 'فوق الدور' : 'دون الدور',
        style: TypeScale.bodyMd.copyWith(color: triad.ink),
      ),
    );
  }
}

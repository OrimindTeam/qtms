/// شاشة الأدوار — **نمط 2 (قائمة الكيانات)** `ui-guidelines.md` §3.
///
/// ★★ **وهي شطر `FR-M1-03` كاملاً بعد حسم `IQ-018` (الخيار ب):** إنشاء ·
/// تعديل · **وحذفٌ فعلي للدور غير المُسنَد وحده** — ⛔ **لا تعطيل، ولا حقل
/// حالة للدور.**
///
/// ⚠️⚠️ **وحالة «مُسنَد» هنا عرضٌ لا حماية:** تُشتقّ من بيانات المستخدمين
/// الفعلية (`assignedRoleIdsProvider`)، ⟵ **وقد تكون «غير معروفة»** لمن لا
/// يملك `userView`. ★ **والقرار الأمني يبقى في العملية السحابية** التي
/// تستعلم على `users` **داخل معاملة الحذف نفسها** (`ADR-0013` القاعدة 3 ·
/// `RISK-02`).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qtms_domain/qtms_domain.dart';

import '../../../core/design/design_tokens.dart';
import '../../../core/design/theme_extensions.dart';
import '../../../core/ui/async_state_view.dart';
import '../../../core/ui/entity_tile.dart';
import '../../../core/ui/skeleton.dart';
import '../../../core/messages/error_messages.dart';
import '../application/admin_providers.dart';
import 'permission_gate.dart';
import 'role_form_screen.dart';
import '../../../core/ui/optional_reason.dart';

/// قائمة الأدوار.
class RolesScreen extends ConsumerWidget {
  /// ينشئ الشاشة.
  const RolesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<RoleCard>> roles = ref.watch(rolesProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: SemanticColors.surface,
        title: const Text('الأدوار', style: TypeScale.titleSm),
      ),
      // ★★ **زر الإنشاء خلف `roleWrite`** — «الصلاحيات تُخفي لا تُعطِّل»
      //   (`ui-guidelines.md` §2). ⚠️⚠️ **وهذا إخفاء لا حماية**: الكتابة
      //   المباشرة على `roles` مغلقة بـ`allow write: if false`، **والفحص
      //   الحقيقي في `createRole`** (`ADR-0013` القاعدة 3).
      floatingActionButton: const PermissionGate(
        permission: Permission.roleWrite,
        child: _NewRoleButton(),
      ),
      // ★ **الحالات الأربع إلزامية** — `design-system.md` §هـ · نمط 2.
      //
      // ⚠️ **والخطأ يُفحَص أولاً ⛔ لا بـ`when` وحدها** — نفس عطل
      //    `users_screen.dart`: التدفّق المُخفِق يبقى `AsyncLoading` وهو
      //    يحمل الخطأ، ⟵ **فـ`when` تدور إلى الأبد ولا يُعرَض السبب.**
      body: switch (roles) {
        AsyncValue<List<RoleCard>>(hasError: true, :final Object? error) =>
          _RolesError(failure: error!),
        AsyncValue<List<RoleCard>>(value: final List<RoleCard> list?) =>
          list.isEmpty ? const _RolesEmpty() : _RolesList(roles: list),
        // ⛔⛔★★★ **ولا مؤشّرَ دوّار وسط الشاشة** — `design-system.md` §هـ
        //    يمنعه نصّاً ويجعل **الهيكل العظمي حالةَ التحميل الوحيدة**:
        //    ⟵ **والدوّار لا يحجز مساحة**، ★ **فوصولُ البيانات يُقفِز
        //    التخطيط دفعةً واحدة** بينما الهيكل يحجز مكانَ المحتوى.
        _ => const SkeletonList(),
      },
    );
  }
}

class _NewRoleButton extends StatelessWidget {
  const _NewRoleButton();

  @override
  Widget build(BuildContext context) => FloatingActionButton.extended(
        onPressed: () => showRoleForm(context),
        icon: const Icon(Icons.add),
        label: const Text('دور جديد'),
      );
}

/// ★ حالة الخطأ — ⛔ **ولا تُعرَض قائمةً فارغة**.
class _RolesError extends StatelessWidget {
  const _RolesError({required this.failure});

  final Object failure;

  @override
  Widget build(BuildContext context) => QtmsErrorState(
        message: catalogText(
          failure.toString().contains('permission-denied')
              ? CatalogMessage.permissionMissing
              : CatalogMessage.operationFailed,
        ),
        detail: failure.toString(),
      );
}

/// الحالة الفارغة — ★ **بسببها وخطوتها التالية** (`ui-guidelines.md` §6).
class _RolesEmpty extends StatelessWidget {
  const _RolesEmpty();

  @override
  Widget build(BuildContext context) => QtmsEmptyState(
        spec: EmptyStateSpec(
          // ★★ **بعائلة «الهوية والصلاحيات»** — `design-system.md` §4.
          triad: context.categories.identity,
          icon: Icons.badge_outlined,
          title: 'لا توجد أدوار بعد',
          message: 'أنشئ قالب دورٍ لتمنح صلاحياته دفعةً واحدة بدل منحها '
              'مفتاحاً مفتاحاً لكل مستخدم.',
        ),
      );
}

class _RolesList extends ConsumerWidget {
  const _RolesList({required this.roles});

  final List<RoleCard> roles;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ★★ **الإسناد من بيانات المستخدمين الفعلية** — و`null` **«غير معروف»**
    //   ⛔ لا «لا إسناد» (راجع `assignedRoleIdsProvider`).
    final Set<String>? assigned = ref.watch(assignedRoleIdsProvider);
    return EntityList(
      itemCount: roles.length,
      itemBuilder: (BuildContext context, int index) => _RoleTile(
        role: roles[index],
        assignment: switch (assigned) {
          null => RoleAssignmentView.unknown,
          final Set<String> ids when ids.contains(roles[index].roleId) =>
            RoleAssignmentView.assigned,
          _ => RoleAssignmentView.free,
        },
      ),
    );
  }
}

/// ★ حالة إسناد الدور **كما تعرفها الشاشة** — ⛔ **لا كما تحسمها السحابة**.
///
/// ⚠️ **وثلاث حالات لا اثنتان عمداً:** [unknown] موجودة لأن معرفة الإسناد
/// تحتاج `userView`، ⟵ **ومن يملك `roleDelete` وحده لا يعرفها**. ★ **وطيّها
/// في [free] كان سيُظهر كل الأدوار قابلةً للحذف**، **وطيّها في [assigned]
/// كان سيمنع صاحبَ الحق من حقّه.**
enum RoleAssignmentView {
  /// مُسنَد لمستخدم واحد على الأقل — ⟵ **ولا يُعرَض له خيار حذف**.
  assigned,

  /// غير مُسنَد — ⟵ **ويُعرَض له الحذف** (والسحابة تُعيد التحقق).
  free,

  /// ★ **غير معروف** — ⟵ **تُتاح المحاولة والسحابة تحسم**.
  unknown,
}

class _RoleTile extends ConsumerStatefulWidget {
  const _RoleTile({required this.role, required this.assignment});

  final RoleCard role;
  final RoleAssignmentView assignment;

  @override
  ConsumerState<_RoleTile> createState() => _RoleTileState();
}

class _RoleTileState extends ConsumerState<_RoleTile> {
  /// رسالة رفضٍ من السحابة — و`null` تعني **لا رفض**.
  CatalogMessage? _rejection;

  bool _busy = false;

  @override
  Widget build(BuildContext context) {
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
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(widget.role.name, style: TypeScale.titleSm),
                    if (widget.role.description case final String description)
                      Padding(
                        padding: const EdgeInsets.only(top: Spacing.space4),
                        child: Text(
                          description,
                          style: TypeScale.bodyMd.copyWith(
                            color: SemanticColors.textSecondary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (widget.assignment == RoleAssignmentView.assigned)
                const _AssignedBadge(),
              PermissionGate(
                permission: Permission.roleWrite,
                child: IconButton(
                  onPressed: _busy
                      ? null
                      : () => showRoleForm(context, existing: widget.role),
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'تعديل الدور',
                ),
              ),
              // ★★ **الحذف خلف `roleDelete`** — ⛔ **ولا يظهر للمُسنَد**
              //   (بند صاحب القرار: «لا تُظهر الواجهة خيار الحذف كأنه متاح
              //   إذا كان الدور مُسنَداً»). ⚠️⚠️ **وهذا إخفاء لا حماية**:
              //   السحابة تُعيد الاستعلام وترفض (`ERR_SETUP_012`).
              if (widget.assignment != RoleAssignmentView.assigned)
                PermissionGate(
                  permission: Permission.roleDelete,
                  child: IconButton(
                    onPressed: _busy ? null : _confirmDelete,
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'حذف الدور',
                  ),
                ),
            ],
          ),
          if (_rejection case final CatalogMessage message) ...<Widget>[
            const SizedBox(height: Spacing.space12),
            _Rejection(message: message),
          ],
        ],
      ),
    );
  }

  /// ★★ **تأكيدٌ قبل الحذف — والسبب اختياريٌّ فيه** (`ADR-0020`).
  ///
  /// ⚠️⚠️★★★ **والتأكيد نفسه صار الحارس الوحيد:** ★ **الحذف لا رجعة فيه**،
  /// ⛔ **ولم تعد السحابة ترفضه لغياب سبب** (كانت `ERR_AMEND_002`) — ⟵ **فلا
  /// شيء بعد هذه الورقة يسأل «لماذا».**
  ///
  /// ⛔ **و`null` تعني تراجعاً** — ★ **والنصُّ الفارغ تأكيدٌ بلا سبب.**
  Future<void> _confirmDelete() async {
    final String? reason = await showRoleDeleteConfirmation(
      context,
      role: widget.role,
    );
    if (reason == null || !mounted) return;

    setState(() {
      _busy = true;
      _rejection = null;
    });
    final Outcome<void> result = await ref.read(roleAdminProvider).delete(
          roleId: widget.role.roleId,
          amendReason: blankToNull(reason),
        );
    if (!mounted) return;
    switch (result) {
      case Failure<void>(:final AppError error):
        // ★★ **الرفض الحقيقي يُعرَض بنصّه** — ⟵ **فمن حاول حذف دورٍ مُسنَد
        //   يرى `ERR_SETUP_012`** لا رسالةً عامة تُرسله يبحث عن صلاحية.
        setState(() {
          _busy = false;
          _rejection = appErrorMessage(error);
        });
      case Success<void>():
        // ★ **ولا شيء يُحدَّث يدوياً** — القائمة تدفّقٌ حيّ، ⟵ **فاختفاء
        //   الدور من `roles` يُزيل هذه البطاقة من تلقائه.**
        setState(() => _busy = false);
    }
  }
}

/// ★ حبّة «مُسنَد» — ⟵ **فيفهم المدير لماذا لا يجد زر الحذف**.
///
/// ⛔ **ولا يُخفى الدور نفسه** — الإخفاء يجعله كالمحذوف في عين المدير.
class _AssignedBadge extends StatelessWidget {
  const _AssignedBadge();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.space8,
          vertical: Spacing.space4,
        ),
        decoration: BoxDecoration(
          color: SemanticColors.surfaceSunken,
          border: Border.all(color: SemanticColors.border),
          borderRadius: BorderRadius.circular(Radii.field),
        ),
        child: Text(
          'مُسنَد',
          style:
              TypeScale.bodyMd.copyWith(color: SemanticColors.textSecondary),
        ),
      );
}

/// شريط الرفض — ★ **نصّه من الكتالوج حرفياً** ⛔ **ولا صياغة هنا.**
class _Rejection extends StatelessWidget {
  const _Rejection({required this.message});

  final CatalogMessage message;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
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

/// شاشة إدارة المستخدمين — **نمط 2 (قائمة الكيانات)** `ui-guidelines.md` §3.
///
/// ★★ **وهي الشاشة التي فتحها `IQ-015`:** قبله كانت **مستحيلة تقنياً** لا
/// ناقصةً فحسب — القاعدة `allow read: if request.auth.uid == userId` **ترفض
/// استعلام المجموعة كاملاً**، ⟵ **فلا قائمة ولا مستخدم ثانٍ في النظام.**
///
/// ⚠️⚠️ **وإخفاؤها بـ`userView` إخفاءٌ لا حماية** — ★ **وحمايتها الحقيقية
/// شرطُ القراءة في `firestore.rules`** (`RISK-02` · `ADR-0010` القاعدة 3).
/// ⛔ **ولا يُكتفى بالبوابة هنا أبداً**، ولذلك تُختبَر القاعدة مستقلةً.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qtms_domain/qtms_domain.dart';

import '../../../app/router.dart';
import '../../../core/design/design_tokens.dart';
import '../../../core/design/theme_extensions.dart';
import '../../../core/ui/async_state_view.dart';
import '../../../core/ui/entity_tile.dart';
import '../../../core/ui/skeleton.dart';
import '../../../core/ui/status_pill.dart';
import '../../../core/messages/error_messages.dart';
import '../../oversight/presentation/audit_trail_view.dart';
import '../application/admin_providers.dart';
import '../application/session_providers.dart';
import 'permission_gate.dart';
import 'user_disable_sheet.dart';
import 'user_form_screen.dart';

/// قائمة المستخدمين.
class UsersScreen extends ConsumerWidget {
  /// ينشئ الشاشة.
  const UsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<UserCard>> users = ref.watch(usersProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: SemanticColors.surface,
        title: const Text('المستخدمون', style: TypeScale.titleSm),
      ),
      // ★★ **زر الإنشاء خلف `userCreate`** — «الصلاحيات تُخفي لا تُعطِّل».
      //   ⚠️⚠️ **وهذا إخفاء لا حماية:** `createUser` تفحص المفتاح **في
      //   الكود** (`ADR-0013` القاعدة 3)، ⛔ **و`users` مغلقة للكتابة.**
      floatingActionButton: const PermissionGate(
        permission: Permission.userCreate,
        child: _NewUserButton(),
      ),
      // ★ **الحالات الأربع إلزامية** — `design-system.md` §هـ · نمط 2.
      //   ⟵ **ولا حالة تُترك بلا مخرَج ظاهر.**
      //
      // ⚠️⚠️ **والخطأ يُفحَص أولاً ⛔ لا بـ`when` وحدها — وهذا عطلٌ رُصد
      //    بالاختبار لا بالقراءة:** حين يُخفق التدفّق تبقى الحالة
      //    `AsyncLoading` **وهي تحمل الخطأ** (`hasError == true`)، ⟵
      //    **فـ`when` تستدعي `loading` فتدور الدائرة إلى الأبد** ⛔ **ولا
      //    يرى الممنوعُ سببَ منعه أبداً**. ★ **وفحص `hasError` أولاً يعرض
      //    السبب فوراً**، ويعرضه أيضاً أثناء إعادة المحاولة — وهو الأصحّ.
      body: switch (users) {
        AsyncValue<List<UserCard>>(hasError: true, :final Object? error) =>
          _ErrorState(failure: error!),
        AsyncValue<List<UserCard>>(value: final List<UserCard> list?) =>
          list.isEmpty ? const _EmptyState() : _UsersList(users: list),
        // ⛔⛔★★★ **ولا مؤشّرَ دوّار وسط الشاشة** — `design-system.md` §هـ
        //    يمنعه نصّاً ويجعل **الهيكل العظمي حالةَ التحميل الوحيدة**:
        //    ⟵ **والدوّار لا يحجز مساحة**، ★ **فوصولُ البيانات يُقفِز
        //    التخطيط دفعةً واحدة** بينما الهيكل يحجز مكانَ المحتوى.
        _ => const SkeletonList(),
      },
    );
  }
}

/// ★★ حالة الخطأ — **وأشيع سببها نقصُ `userView` لا عطل**.
///
/// ⛔ **ولا تُعرَض كقائمة فارغة أبداً:** «لا مستخدمين» تجعل المديرَ يبحث عن
/// عطلٍ لا وجود له، ★ **بينما الحقيقة أنه ممنوعٌ من الرؤية**.
class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.failure});

  final Object failure;

  /// ★ **رفض القاعدة يصل استثناءً من المنصّة لا `AppError`** — ⟵ يُصنَّف
  /// برمزه، ⛔ **ولا يُعرَض نصّ المنصّة الخام** (§3 القاعدة 1).
  ///
  /// ⚠️ **والمجهول يُعرَض برسالة عامة ⛔ لا بصمت ولا بادّعاء نقص صلاحية**:
  /// اتهامُ صلاحيةٍ سليمة يُرسِل المديرَ ليمنح صلاحيةً ممنوحة أصلاً.
  CatalogMessage get _message =>
      failure.toString().contains('permission-denied')
          ? CatalogMessage.permissionMissing
          : CatalogMessage.operationFailed;

  @override
  Widget build(BuildContext context) => QtmsErrorState(
        message: catalogText(_message),
        detail: failure.toString(),
      );
}

/// الحالة الفارغة — ★ **بسببها وخطوتها التالية** (`ui-guidelines.md` §6).
///
/// ⛔ **ولا «لا توجد بيانات» عارية** — `design-system.md` §هـ: **«أيقونة +
/// عنوان + رسالة + إجراء أساسي»**، ⟵ **فالفراغُ يُشرَح لا يُعلَن.**
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => QtmsEmptyState(
        spec: EmptyStateSpec(
          // ★★ **بعائلة «الهوية والصلاحيات»** — `design-system.md` §4.
          triad: context.categories.identity,
          icon: Icons.group_outlined,
          title: 'لا يوجد مستخدمون بعد',
          message: 'أضف أول مستخدم ليتمكّن من الدخول والعمل ضمن نطاق مصادره.',
        ),
      );
}

class _UsersList extends ConsumerWidget {
  const _UsersList({required this.users});

  final List<UserCard> users;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AuthSession? session = ref.watch(currentSessionProvider);
    return EntityList(
      // ★ **بناء كسول** — نمط 2، فالقائمة تطول بعدد المستخدمين.
      itemCount: users.length,
      itemBuilder: (BuildContext context, int index) => _UserTile(
        user: users[index],
        // ★ **بطاقتك أنت مُعلَّمة** — ⟵ **فلا تُخطئ فتعطّل نفسك**، وهو ما
        //   ترفضه الدالة السحابية أصلاً (`FR-M1-12`).
        isSelf: users[index].userId == session?.userId,
      ),
    );
  }
}

class _NewUserButton extends StatelessWidget {
  const _NewUserButton();

  @override
  Widget build(BuildContext context) => FloatingActionButton.extended(
        onPressed: () => showUserForm(context),
        icon: const Icon(Icons.person_add_alt),
        label: const Text('مستخدم جديد'),
      );
}

class _UserTile extends ConsumerWidget {
  const _UserTile({required this.user, required this.isSelf});

  final UserCard user;
  final bool isSelf;

  @override
  Widget build(BuildContext context, WidgetRef ref) => EntityTile(
        title: user.name,
        // ★ الدور أوضح للمدير من البريد، ⛔ والبريد بديلٌ لا زينة.
        subtitle: user.roleName ?? user.email ?? 'بلا دور',
        // ★★ **أيقونة 🕘 مقدّمةً** — `FR-M18-10` · `FR-M18-11`
        //   («**المستخدمون**» آخرُ الشاشات المشمولة).
        //
        // ★★ **وكانت تُوضَع يدوياً أولَ صفٍّ مبنيٍّ في هذه الشاشة** —
        //   ⛔ **و[EntityTile.leading] تحمل الحالتين معاً**، ⟵ **فسقط
        //   المبررُ الذي كان يُبقي البطاقة خارج المكوّن.**
        leading: auditTrailLeading(
          ref,
          entityType: userEntityType,
          entityId: user.userId,
          title: user.name,
        ),
        badges: <Widget>[
          // ★★ **«أنت» حالةٌ لا قيمة** — ⟵ **فموضعُها سطرُ الحالات**،
          //   ⛔ **لا [EntityTile.trailing]** الذي يرسم **أرقاماً جدولية.**
          if (isSelf)
            const StatusPill(label: 'أنت', triad: SemanticTriads.info),
          // ★★ **حبّة حالة صريحة للمعطَّل** — ⟵ **فالمعطَّل يُرى في القائمة
          //   ولا يختفي**: `FR-M1-12` تمنع الحذف، **والإخفاء يجعله كالمحذوف
          //   في عين المدير** فيظنّه ذهب وهو باقٍ بقيوده في سجل التدقيق.
          //
          // ⛔⛔★★ **وكانت حبّةً مرسومةً محلياً** (`_DisabledBadge`) —
          //   ★ **أفلتت من بوابة §8 لأنها بـ`Radii.field` لا `Radii.pill`**
          //   (`DEBT-51`): ⟵ **والمشروعةُ واحدة.**
          if (!user.isActive)
            const StatusPill(label: 'معطَّل', triad: SemanticTriads.danger),
        ],
        actions: <Widget>[
          PermissionGate(
            permission: Permission.userAmend,
            child: IconButton(
              onPressed: () => showUserForm(context, existing: user),
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'تعديل المستخدم',
            ),
          ),
          // ★★ **مدخل تخصيص الصلاحيات** (`FR-M1-05`) — خلف `permissionGrant`.
          //
          // ⛔★ **ولا يظهر على بطاقتك أنت:** «لا مستخدم يعدّل صلاحيات نفسه
          //   — ولو المالك» (`authentication-policy.md` §3). ⚠️⚠️ **وهذا
          //   إخفاء لا حماية**: `validatePermissionGrant` ① ترفض الطلب نفسه.
          if (!isSelf)
            PermissionGate(
              permission: Permission.permissionGrant,
              child: IconButton(
                onPressed: () => context.go(permissionsRouteFor(user.userId)),
                icon: const Icon(Icons.key_outlined),
                tooltip: 'تخصيص الصلاحيات',
              ),
            ),
          // ★★ **التعطيل بديل الحذف** (`FR-M1-12`) — ⛔ **ولا يظهر على
          //   بطاقتك أنت ولا على معطَّلٍ أصلاً.**
          if (!isSelf && user.isActive)
            PermissionGate(
              permission: Permission.userDisable,
              child: _DisableButton(user: user),
            ),
        ],
      );
}

/// زر التعطيل — ★ **بسببٍ نصّي إلزامي** (`FR-M1-12`).
class _DisableButton extends ConsumerStatefulWidget {
  const _DisableButton({required this.user});

  final UserCard user;

  @override
  ConsumerState<_DisableButton> createState() => _DisableButtonState();
}

class _DisableButtonState extends ConsumerState<_DisableButton> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) => IconButton(
        onPressed: _busy ? null : _disable,
        icon: const Icon(Icons.block),
        tooltip: 'تعطيل المستخدم',
      );

  Future<void> _disable() async {
    final String? reason = await showUserDisableSheet(
      context,
      user: widget.user,
    );
    if (reason == null || !mounted) return;
    setState(() => _busy = true);
    final Outcome<void> result = await ref
        .read(userAdminProvider)
        .disable(userId: widget.user.userId, reason: reason);
    if (!mounted) return;
    setState(() => _busy = false);
    switch (result) {
      case Failure<void>(:final AppError error):
        // ★ **الرفض يُعرَض** — ⛔ ولا يُبتلَع فيظنّ المدير أنه عُطِّل.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(catalogText(appErrorMessage(error)))),
        );
      case Success<void>():
        // ★ **ولا شيء يُحدَّث يدوياً** — القائمة تدفّقٌ حيّ، ⟵ **فالحبّة
        //   «معطَّل» تظهر من تلقائها.**
        break;
    }
  }
}

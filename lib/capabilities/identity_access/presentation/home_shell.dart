/// صدَفة التطبيق بعد الدخول — **نمط `P1`** (`MASTER.md` §5b · `ADR-0021`).
///
/// ⚠️ **وحدّها معلَن:** ⛔ **ليست «اللوحة الافتتاحية»** — تلك تعرض **مؤشّرات
/// وبلاطات أقسام** لا وجود لبياناتها بعد (`ui-guidelines.md` §3).
/// ★ **وما تعرضه هنا: هويةُ المستخدم ودورُه ونطاقُ مصادره، ثم مداخلُ العمل.**
///
/// ⛔ **ولا رقم مالي هنا ولا مؤشّر** — ★ **الأرقام في شاشاتها**، ⟵ **فالصدَفة
/// بطاقةُ هويةٍ ومداخل** ⛔ **لا لوحةً افتتاحية.**
///
/// ★★★ **وثلاثةُ أعطالٍ عالجها `P1`** (جرد 2026-08-27):
/// ① ⛔ **ثلاثةَ عشرَ مدخلاً بوزنٍ واحد بلا عناوين أقسام** ⟵ **لا هرمَ ولا
///    حدودَ مجموعات**: ★ **«سجل التدقيق» بنفس بروز «التوزيع».**
/// ② ⛔⛔ **وترتيبٌ معكوسٌ مقابل التكرار اليومي** — ★ **التوزيعُ ثالثَ عشرَ
///    وهو أكثرُ العمليات تكراراً** (`FR-M10`: توزيعةٌ في أقل من 30 ثانية).
/// ③ ⛔⛔★★★ **وفجواتٌ مكدَّسة لمن لا يملك المفاتيح** — ★ **`PermissionGate`
///    تُرجِع `SizedBox.shrink` والفاصلُ الشقيقُ يبقى**: ⟵ **والعلاجُ بنيوي
///    في [QtmsHubSection]** — **الفواصلُ داخل المكوّن، والقسمُ يختفي كلُّه.**
///
/// ⚠️⚠️ **وكلُّ بوابةٍ هنا إخفاءٌ لا حماية** — ★ **ويقابلها شرطٌ في
/// `firestore.rules` أو فحصٌ في الدالة الكاتبة** (`RISK-02` · `ADR-0013`
/// القاعدة 3). ⛔ **فلا يُكتفى بإخفاء مدخل أبداً.**
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qtms_domain/qtms_domain.dart';

import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/design/brand.dart';
import '../../../core/design/design_tokens.dart';
import '../../../core/ui/hub_section.dart';
import '../../../core/ui/needs_action_row.dart';
import '../../oversight/application/pending_entries_providers.dart';
import '../../oversight/application/report_providers.dart';
import '../application/session_providers.dart';
import 'permission_gate.dart';

/// الشاشة الرئيسية بعد الدخول.
class HomeShell extends ConsumerWidget {
  /// ينشئ الصدَفة.
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AuthSession? session = ref.watch(currentSessionProvider);
    if (session == null) return const Scaffold(body: SizedBox.shrink());

    return Scaffold(
      appBar: AppBar(
        backgroundColor: SemanticColors.surface,
        // ★★ **شريطُ التطبيق: شعارُ العميل واسمُ المحل ثم اسمُ المستخدم**
        //    (`ui-guidelines.md` نمط 1 ①) — ⛔ **ولا نصَّ اسمٍ محفورٌ هنا:**
        //    ★ **`appDisplayName` و`BrandLogo` مصدرُ الحقيقة الواحد** (`AM-002`).
        //    ⚠️★ **ولا مؤشّرَ اتصالٍ بعد** — ★ **لا مصدرَ حالةِ شبكةٍ حيٌّ في
        //    التطبيق اليوم**، ⛔ **ووسمُ «متصل» بلا قياسٍ ادّعاءٌ لا معلومة**
        //    ⟵ **وهو ضدُّ ما وُجد المؤشّرُ لأجله** (`ADR-0003`).
        title: Row(
          children: <Widget>[
            const BrandLogo(size: Sizes.chipHeight),
            const SizedBox(width: Spacing.space8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    appDisplayName,
                    style: TypeScale.titleSm
                        .copyWith(color: SemanticColors.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    session.displayName,
                    style: TypeScale.caption
                        .copyWith(color: SemanticColors.textTertiary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
            icon: const Icon(Icons.logout),
            tooltip: 'تسجيل الخروج',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsetsDirectional.all(Spacing.screenPadding),
        children: <Widget>[
          // ② ★★ **شريطُ هويةٍ مضغوط** — §5b `P1`.
          //
          // ⛔⛔ **وكان ثلاثَ بطاقاتٍ تحتلّ الطيّة الأولى كاملة** — ★ **ومنها
          //    «عدد الصلاحيات» رقمٌ بلا فعل**: ⟵ **فصار سطرين، والمداخلُ
          //    تبدأ قبل نهاية الطيّة.**
          _IdentityStrip(session: session),
          const SizedBox(height: Spacing.space12),

          // ⏳★★★ **العدّاد الحيّ للإدخالات المعلّقة** — `FR-SYS-03` الموضع
          //    الرابع («**لوحة التحكم: بطاقة ⏳ الإدخالات المعلّقة بالعدد
          //    الإجمالي**») · `FR-SYS-21`.
          //
          // ⚠️⚠️ **وهو صفُّ «يحتاج إجراء» بعقده** (`design-system.md` §7) —
          //    ⛔ **لا بطاقةُ تنبيهٍ مربّعة**: `ui-guidelines.md` §3 نمط 1
          //    القرار 2 («**المربعاتُ المتساوية تُسوّي بين متبقٍّ عمرُه خمسةُ
          //    أيام وبين عدّادٍ للعلم**»).
          //
          // ⛔ **وبلا بوابة صلاحية** — ★ **لا مفتاح للمركز في الكتالوج §2**،
          //    ⟵ **والقاعدة تكتفي بالنطاق** (`pending_entries_providers.dart`).
          const _PendingEntriesRow(),
          const SizedBox(height: Spacing.space24),

          // ③ ⛔⛔★★★ **والترتيب بالتكرار اليومي لا بالتسلسل الإداري.**
          QtmsHubSection(
            title: 'العمليات اليومية',
            children: <Widget>[
              // ★ **المدخل الأساسي الوحيد في الشاشة** — §7.
              //
              // ⚠️⚠️ **وإخفاءٌ لا حماية** — ★ **والفحصُ في `distributionGate`**،
              //    ⛔ **ولا مفتاح «عرض التوزيعات» في الكتالوج §2.**
              PermissionGate(
                permission: Permission.distributionCreate,
                child: QtmsHubButton(
                  entry: QtmsHubEntry(
                    label: 'التوزيع',
                    icon: Icons.local_shipping_outlined,
                    onPressed: () => context.go(distributionRoute),
                    isPrimary: true,
                  ),
                ),
              ),
              // ⚠️⚠️ **وإخفاءٌ لا حماية** — ★ **والفحصُ في `receiptGate`**،
              //    ⛔ **ولا مفتاح «عرض المقبوضات» في الكتالوج §2.5**:
              //    ★ **الستةُ فيه مفاتيحُ فعلٍ لا عرض**، ⟵ **فمدخلُ الشاشة
              //    `receiptCreate`** ⛔ **ولا يُخترَع مفتاحٌ سابع** (`BR-M1-07`).
              PermissionGate(
                permission: Permission.receiptCreate,
                child: QtmsHubButton(
                  entry: QtmsHubEntry(
                    label: 'المقبوضات',
                    icon: Icons.payments_outlined,
                    onPressed: () => context.go(receiptRoute),
                  ),
                ),
              ),
              PermissionGate(
                permission: Permission.incomingCountWrite,
                child: QtmsHubButton(
                  entry: QtmsHubEntry(
                    label: 'الوارد عدداً',
                    icon: Icons.add_box_outlined,
                    onPressed: () => context.go(countedIntakeRoute),
                  ),
                ),
              ),
              // ⛔⛔★★★ **ومدخلُ الجواني `sackCreate` لا مفتاحٌ حقلي**
              //    (`IQ-021`) — ★ **إنشاءُ الرأس مدخلُ الوحدة كلها**،
              //    ⛔ **ولا يُغني عنه `sackLinesEnter` ولا `sackView`.**
              PermissionGate(
                permission: Permission.sackCreate,
                child: QtmsHubButton(
                  entry: QtmsHubEntry(
                    label: 'الوارد جواني',
                    icon: Icons.inventory_outlined,
                    onPressed: () => context.go(sackIntakeRoute),
                  ),
                ),
              ),
              // ★★ **ومخزونُ اليوم والتسعيرُ بلا بوابة** — ⛔ **ولا مفتاحَ
              //    عرضٍ لهما في الكتالوج**: ★ **والنطاقُ وحده يحكم في القاعدة**
              //    (`isSignedIn() && storedInScope()`) ⟵ **وبوابةٌ هنا كانت
              //    ستُخفي شاشةً تسمح بها القاعدة.**
              QtmsHubButton(
                entry: QtmsHubEntry(
                  label: 'مخزون اليوم',
                  icon: Icons.inventory_2_outlined,
                  onPressed: () => context.go(todayStockRoute),
                ),
              ),
              QtmsHubButton(
                entry: QtmsHubEntry(
                  label: 'التسعير اليومي',
                  icon: Icons.sell_outlined,
                  onPressed: () => context.go(dailyPricingRoute),
                ),
              ),
            ],
          ),

          // ⚠️⚠️ **والبياناتُ المرجعية كلُّها إخفاءٌ لا حماية** — ★ **الكتابة
          //    مغلقةٌ في القواعد والتفويضُ في الدالة** (`ADR-0013` القاعدة 3).
          //    ★ **والبوابةُ على مفتاح الكتابة عمداً:** ⟵ **فمن لا يكتب لا
          //    شأن له بشاشة تهيئة.**
          QtmsHubSection(
            title: 'البيانات المرجعية',
            children: <Widget>[
              PermissionGate(
                permission: Permission.sourceWrite,
                child: QtmsHubButton(
                  entry: QtmsHubEntry(
                    label: 'المصادر',
                    icon: Icons.warehouse_outlined,
                    onPressed: () => context.go(sourcesRoute),
                  ),
                ),
              ),
              PermissionGate(
                permission: Permission.supplierWrite,
                child: QtmsHubButton(
                  entry: QtmsHubEntry(
                    label: 'الرعية',
                    icon: Icons.agriculture_outlined,
                    onPressed: () => context.go(suppliersRoute),
                  ),
                ),
              ),
              PermissionGate(
                permission: Permission.dealerWrite,
                child: QtmsHubButton(
                  entry: QtmsHubEntry(
                    label: 'المقاوته',
                    icon: Icons.handshake_outlined,
                    onPressed: () => context.go(dealersRoute),
                  ),
                ),
              ),
              PermissionGate(
                permission: Permission.itemWrite,
                child: QtmsHubButton(
                  entry: QtmsHubEntry(
                    label: 'الأنواع',
                    icon: Icons.category_outlined,
                    onPressed: () => context.go(itemsRoute),
                  ),
                ),
              ),
            ],
          ),

          QtmsHubSection(
            title: 'الهوية والصلاحيات',
            children: <Widget>[
              // ⚠️⚠️ **وإخفاءٌ لا حماية** — ★ **ويقابله شرطُ قراءةٍ فعلي في
              //    `firestore.rules`** (`match /users/{userId}`) **مُختبَرٌ
              //    مستقلاً على المحاكي** (`RISK-02` · `FR-M1-10`).
              PermissionGate(
                permission: Permission.userView,
                child: QtmsHubButton(
                  entry: QtmsHubEntry(
                    label: 'إدارة المستخدمين',
                    icon: Icons.group_outlined,
                    onPressed: () => context.go(usersRoute),
                  ),
                ),
              ),
              // ★ **والبوابةُ على الكتابة لا الرؤية** — ⟵ **فمن لا يكتب دوراً
              //   ولا يحذفه لا شأن له بالشاشة أصلاً.**
              PermissionGate(
                permission: Permission.roleWrite,
                child: QtmsHubButton(
                  entry: QtmsHubEntry(
                    label: 'الأدوار',
                    icon: Icons.badge_outlined,
                    onPressed: () => context.go(rolesRoute),
                  ),
                ),
              ),
            ],
          ),

          QtmsHubSection(
            title: 'الرقابة',
            children: <Widget>[
              // ★★ **و`auditLogViewCentral` تحديداً** — `FR-M18-12`،
              //    ⛔ **بخلاف السجل السياقي** الذي يتبع صلاحية عرض وحدته.
              PermissionGate(
                permission: Permission.auditLogViewCentral,
                child: QtmsHubButton(
                  entry: QtmsHubEntry(
                    label: 'سجل التدقيق',
                    icon: Icons.fact_check_outlined,
                    onPressed: () => context.go(auditLogRoute),
                  ),
                ),
              ),
              // ⛔⛔★★ **ومدخلُ التقارير بستة مفاتيحَ لا بواحد** (`IQ-034`) —
              //    ★ **فلا تصلح [PermissionGate] وهي على مفتاحٍ واحد**:
              //    ⟵ **والشرطُ «يملك مفتاحَ عائلةٍ واحدةٍ على الأقل»**،
              //    ⛔ **ومَن لا يملك أياً منها لا يرى مدخلاً يفتح على فراغ.**
              if (ref.watch(visibleReportsProvider).isNotEmpty)
                QtmsHubButton(
                  entry: QtmsHubEntry(
                    label: 'التقارير',
                    icon: Icons.assessment_outlined,
                    onPressed: () => context.go(reportsRoute),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// ⏳★★★ **صفُّ الإدخالات المعلّقة الحيّ** — `FR-SYS-03` · `FR-SYS-21`.
///
/// ⛔⛔ **ولا يُخفى عند الصفر** — `ui-guidelines.md` §3 نمط 1: «**وفارغٌ «لا
/// يحتاج شيءٌ إجراءً» بأيقونةٍ هادئة ⛔ لا إخفاءَ البطاقة**»: ⟵ **فاختفاؤه
/// يجعل المستخدم يشكّ أهو صفرٌ أم عطل.**
///
/// ⚠️ **وأثناء التحميل يُعرَض بلا رقم** — ⛔ **ولا صفرٌ مؤقّت**: ★ **عدّادٌ
/// يقول «٠» ثم يصير «٧» يُقرأ عطلاً** (`pendingEntriesCountProvider`).
class _PendingEntriesRow extends ConsumerWidget {
  const _PendingEntriesRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<int> count = ref.watch(pendingEntriesCountProvider);
    final int? value = count.hasError ? null : count.value;
    final bool hasPending = value != null && value > 0;

    return QtmsNeedsActionRow(
      icon: Icons.hourglass_bottom_outlined,
      title: 'الإدخالات المعلّقة',
      destination: hasPending
          ? 'قيمٌ تُركت لاحقاً — افتح المركز لاستكمالها'
          : 'المركز يذكّر بما تُرك لاحقاً — ولا يمنع شيئاً',
      count: value ?? 0,
      // ★★ **الحدّةُ تصل ثلاثيةً جاهزة** — §5.1: ⛔ **ولا يقارن المكوّن رقماً.**
      triad:
          hasPending ? SemanticTriads.warning : SemanticTriads.neutral,
      countLabel: switch (value) {
        null when count.hasError => 'تعذّر',
        null => '—',
        0 => 'لا شيء',
        _ => null,
      },
      onTap: () => context.go(pendingEntriesRoute),
    );
  }
}

/// ★★ شريطُ الهوية المضغوط — **الدور ونطاق المصادر في سطرين**.
///
/// ⛔⛔ **ولا «عدد الصلاحيات»** — ★ **رقمٌ بلا فعلٍ كان يحتلّ بطاقةً كاملة في
/// الطيّة الأولى**، ⟵ **والمستخدمُ لا يفعل به شيئاً**؛ ★ **وتفصيلُ الصلاحيات
/// شاشتُه هي `PermissionsScreen`.**
class _IdentityStrip extends StatelessWidget {
  const _IdentityStrip({required this.session});

  final AuthSession session;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsetsDirectional.all(Spacing.cardPadding),
        decoration: BoxDecoration(
          // ★★ **وثلاثيةُ `primary` لا السطحُ المحايد** (`AM-007`): ⟵ **الدورُ
          //    ونطاقُ المصادر هويةُ الجلسة**، ★ **وهي أولُ ما يجب أن يُقرأ.**
          //    ⛔ **ولا لونٌ خارج الثلاثية** — §3.3.
          color: SemanticTriads.primary.soft,
          border: Border.all(
            color: SemanticTriads.primary.border,
            width: Sizes.borderWidth,
          ),
          borderRadius: BorderRadius.circular(Radii.card),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              session.roleName ?? 'بلا دور',
              style: TypeScale.titleSm
                  .copyWith(color: SemanticTriads.primary.ink),
            ),
            const SizedBox(height: Spacing.space4),
            Text(
              _scopeLabel(session.sourceScope),
              style: TypeScale.bodyMd
                  .copyWith(color: SemanticColors.textSecondary),
            ),
          ],
        ),
      );
}

/// ★ وصف النطاق بالعربية — ⛔ **ولا يُعرَض `all` نصّاً تقنياً**
/// (`ui-guidelines.md` §6: «لا مصطلح تقني في واجهة المستخدم»).
String _scopeLabel(SourceScope? scope) => switch (scope) {
      AllSources() => 'كل المصادر',
      ScopedSources(sourceIds: final Set<String> ids) => '${ids.length} مصدر',
      // ⚠️ لا نطاق في الرمز ⟵ **لا مصدر متاح** (`source_scope_claim.dart`).
      null => 'لا مصدر متاح',
    };

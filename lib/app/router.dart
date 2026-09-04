/// الملاحة — ★ **توجيه تصريحي بمسارات مُعرَّفة** (`technology-stack.md` §1 ·
/// `ADR-0009`)، **وعمق لا يتجاوز ثلاثة مستويات** (`ui-guidelines.md` §4).
///
/// ★ **والحارس واحد لا متكرر في الشاشات:** حالة الجلسة **تُعيد التوجيه
/// مركزياً** ⟵ **فلا شاشةَ عملٍ تُفتَح بجلسة مرفوضة**، ⛔ **ولا فحص جلسة
/// منسوخ في كل شاشة** يفترق عند أول تعديل.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qtms_domain/qtms_domain.dart';

import '../capabilities/identity_access/application/session_providers.dart';
import '../capabilities/identity_access/application/session_state.dart';
import '../capabilities/identity_access/presentation/home_shell.dart';
import '../capabilities/identity_access/presentation/login_screen.dart';
import '../capabilities/identity_access/presentation/permissions_screen.dart';
import '../capabilities/identity_access/presentation/profile_screen.dart';
import '../capabilities/identity_access/presentation/roles_screen.dart';
import '../capabilities/identity_access/presentation/session_blocked_screen.dart';
import '../capabilities/identity_access/presentation/users_screen.dart';
import '../capabilities/inventory/presentation/supply_intake_screen.dart';
import '../capabilities/inventory/presentation/daily_pricing_screen.dart';
import '../capabilities/inventory/presentation/sack_finance_screen.dart';
import '../capabilities/inventory/presentation/today_stock_screen.dart';
import '../capabilities/oversight/presentation/audit_log_screen.dart';
import '../capabilities/oversight/presentation/pending_entries_screen.dart';
import '../capabilities/oversight/presentation/report_view_screen.dart';
import '../capabilities/oversight/presentation/reports_screen.dart';
import '../capabilities/sales_receivables/presentation/cash_sale_screen.dart';
import '../capabilities/sales_receivables/presentation/dealer_statement_screen.dart';
import '../capabilities/financial_outflow/presentation/outflow_screen.dart';
import '../capabilities/financial_outflow/presentation/owner_ledger_history_screen.dart';
import '../capabilities/financial_outflow/presentation/owner_ledger_screen.dart';
import '../capabilities/sales_receivables/presentation/discount_screen.dart';
import '../capabilities/sales_receivables/presentation/distribution_screen.dart';
import '../capabilities/sales_receivables/presentation/receipt_screen.dart';
import '../capabilities/master_data/application/master_data_providers.dart';
import '../capabilities/master_data/presentation/about_screen.dart';
import '../capabilities/master_data/presentation/dealers_screen.dart';
import '../capabilities/master_data/presentation/first_run_setup_screen.dart';
import '../capabilities/master_data/presentation/items_screen.dart';
import '../capabilities/master_data/presentation/settings_screen.dart';
import '../capabilities/master_data/presentation/sources_screen.dart';
import '../capabilities/master_data/presentation/suppliers_screen.dart';
import '../core/design/brand.dart';
import '../core/design/design_tokens.dart';

/// مسار الانتظار حتى تُعرَف حالة الجلسة.
const String splashRoute = '/';

/// مسار شاشة الدخول.
const String loginRoute = '/login';

/// مسار الصدَفة بعد الدخول.
const String homeRoute = '/home';

/// مسار الجلسة المرفوضة (حساب معطَّل).
const String blockedRoute = '/blocked';

/// ★ مسار إدارة المستخدمين (`IQ-015`) — **مسار فرعي تحت الصدَفة**،
/// ⟵ **فالعمق مستويان** ⛔ ولا يتجاوز الثلاثة (`ui-guidelines.md` §4).
const String usersRoute = '/home/users';

/// ★ مسار الأدوار (`FR-M1-03`) — **مستويان** ⛔ ولا يتجاوز الثلاثة.
const String rolesRoute = '/home/roles';

/// ★★★ **مسار «الملف الشخصي»** — `AM-012` §5 · **مستويان**.
///
/// ⛔⛔★★ **ولا معامل مستخدمٍ في المسار إطلاقاً** — ★ **الشاشةُ لصاحب الجلسة
/// وحدَه** (`CR-012` `FR-M1-18`): ⟵ **ومسارٌ يقبل معرّفاً كان يُوحي بأن
/// ثمّة ملفّاً شخصياً لغيره يُفتَح** ⛔ **وهو ما تمنعه الشاشةُ نفسُها**،
/// ★ **وإدارةُ المستخدمين لها مسارُها ومفاتيحُها** (`usersRoute`).
const String profileRoute = '/home/profile';

/// ★★★ **مسار «الإعدادات»** — `AM-012` §4.4 · **مستويان**.
///
/// ⛔⛔ **وتفضيلاتُ عرضٍ محليةٌ وحدَها** — ★ **ولا صلةَ لها بـ`setupRoute`:**
/// ⟵ **تلك بوابةُ إعدادٍ تأسيسيٍّ لا رجعةَ فيها تُفتَح مرةً واحدة**
/// (`FR-M21-03`)، ★ **وهذه شاشةٌ تُفتَح متى شاء المستخدم.**
const String settingsRoute = '/home/settings';

/// ★★ **مسار «حول التطبيق»** — `FR-SYS-28` · **مستويان**.
///
/// ★ **ويُفتَح من صفِّ «حول التطبيق» في الإعدادات** — ⛔ **ولا مدخلَ له في
/// قائمة الجلسة**: ⟵ **تلك مداخلُ حسابٍ وجهاز** (`AM-012` §4.4)، ★ **و«حول»
/// صفٌّ من نمط الإعدادات المجمَّعة** (`ui-guidelines.md` §3 نمط 7).
const String aboutRoute = '/home/about';

/// ★★ مسار تخصيص صلاحيات مستخدم (`FR-M1-05`) — **ثلاثة مستويات وهو الحدّ**
/// (`ui-guidelines.md` §4)، ⟵ **فلا يُضاف تحته شيء.**
String permissionsRouteFor(String userId) => '/home/users/$userId/permissions';

/// ★ مسار المصادر (`FR-M2`) — **مستويان**.
const String sourcesRoute = '/home/sources';

/// ★ مسار الرعية (`FR-M3`).
const String suppliersRoute = '/home/suppliers';

/// ★ مسار المقاوته (`FR-M4`).
const String dealersRoute = '/home/dealers';

/// ★ مسار الأنواع (`FR-M5`).
const String itemsRoute = '/home/items';

/// ★★★ **مسار «التوريد مخزني»** (`FR-M6` + `FR-M7`) — **مستويان** ·
/// `AM-012` §2 (2026-09-02).
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **ومسارٌ واحدٌ حلّ محلّ `'/home/intake'` و`'/home/sacks'`** —
/// ★ **بطلب المالك: شاشةٌ واحدة بتبويبين** ([SupplyIntakeScreen]).
///
/// ⛔⛔ **ولا معاملَ تبويبٍ في المسار** — ★ **التبويبُ مُدخَلٌ في المُنشئ:**
/// ⟵ **ووجهةُ ملاحةٍ داخلية لا رابطٌ يُشارَك** (نفسُ علّة `auditLogRoute`
/// و`pendingEntriesRoute` أدناه حرفياً).
///
/// ⛔★★ **ولا معامل تاريخ ولا رقم متسلسل** — `FR-M6-02` · `FR-M7-02` ·
/// `FR-M7-04`: **كلُّها من الخادم**، ⟵ **ومسارٌ يقبل أياً منها كان يُوحي
/// بأنه يُختار.**
/// ═══════════════════════════════════════════════════════════════════════
const String supplyIntakeRoute = '/home/supply';

/// ★ مسار مخزون اليوم (`FR-M8` الشاشة الأولى) — **مستويان**.
///
/// ⛔★★ **ولا معامل تاريخ في المسار** — `FR-M8-05`: **اليوم الجاري فقط 🔒**،
/// ⟵ **ومسارٌ يقبل تاريخاً كان سيصير متصفّح تاريخٍ محذوفاً بقرار المالك**
/// (`BR-M8-06` · `GR-55`).
const String todayStockRoute = '/home/stock';

/// ★ مسار التسعير اليومي (`FR-M9`) — **مستويان**.
///
/// ⛔★★ **ولا معامل تاريخ في المسار** — `FR-M9-01` (`GR-31`): **التسعير
/// يخصّ اليوم وحده ويُصفَّر يومياً**، ⟵ **ومسارٌ يقبل تاريخاً كان سيُغري
/// بتسعير يومٍ مضى** ⛔ **وهو ما لا تقبله السحابة أصلاً** (يومُ المنصّة).
const String dailyPricingRoute = '/home/pricing';

/// ★ مسار التوزيع (`FR-M10`) — **مستويان**.
///
/// ⛔★★ **ولا معامل تاريخ ولا مقوت في المسار** — `FR-M10-03`: **تاريخ المخزون
/// يحدده النظام**، ⟵ **ومسارٌ يقبله كان يُوحي بأنه يُختار**؛ ★ **والمقوت
/// اختيارٌ داخل الشاشة** ⛔ **لا مستوىً ثالث** (`ui-guidelines.md` §4).
const String distributionRoute = '/home/distribution';

/// ★ مسار البيع النقدي (`M11` · `WU-012`) — **مستويان**.
///
/// ⛔★★ **ولا معامل تاريخٍ ولا مشترٍ في المسار** — ★ **تاريخ المخزون يحدده
/// النظام** (`A-10` · `GR-14`)، ⛔ **واسم المشتري حقلٌ غير موجود قصداً**
/// (`FR-M11-12`): ⟵ **فلا شيءَ يُمرَّر في الرابط أصلاً.**
const String cashSaleRoute = '/home/cash-sales';

/// ★ مسار المقبوضات (`M12` · `WU-007`) — **مستويان**.
///
/// ⛔★★ **ولا معامل مقوتٍ ولا تاريخٍ في المسار** — ★ **كلاهما اختيارٌ داخل
/// الشاشة** (`ui-guidelines.md` §4): ⟵ **ومسارٌ يحمل تاريخاً كان يُوحي بأن
/// «المقبوض في تاريخ» يُختار من الرابط**، ⛔ **وهو حقلُ سندٍ لا وجهةُ ملاحة.**
const String receiptRoute = '/home/receipts';

/// ★★ مسار **كشف حساب المقوت** (`M17` · `WU-017`) — **مستويان**.
///
/// ⛔⛔★★★ **ولا معامل مقوتٍ ولا مصدرٍ ولا فترةٍ في المسار** — ★ **الثلاثةُ
/// حالةٌ في التطبيق** (`statementDealerProvider` وأخواتها) ⛔ **لا رابطٌ
/// يُشارَك: ⟵ **ومسارٌ يحملها كان يصير طريقاً ثانياً لقراءة كشفِ ذمّةٍ**
/// بلا الشاشة التي تملك صلاحيته ونطاقه — ★ **بنفس علّة [auditLogRoute]
/// و[reportRoute] حرفياً.** ⚠️ **والكشفُ مستندٌ يُسلَّم للمقوت ويُبنى عليه
/// نزاعٌ محتمل**، ⟹ **فالحساسيةُ هنا أعلى لا أدنى.**
const String dealerStatementRoute = '/home/dealer-statement';

/// ★ مسار الخصومات (`M13` · `WU-013`) — **مستويان**.
///
/// ⛔⛔★★★ **ومسارٌ مستقلٌّ عن [receiptRoute] قطعاً** (`FR-M15-06-أ`) —
/// ★ **وهذا أولُ موضعٍ يراه المستخدم من الفصل**: ⟵ **شاشتان لا شاشةٌ
/// بمبدِّل**، ⛔ **ومبدِّلٌ بينهما كان يجعل الخلطَ خطأَ نقرةٍ واحدة.**
const String discountRoute = '/home/discounts';

/// ★ مسار السحبيات والخرجيات (`M22` · `WU-014`) — **مستويان**.
///
/// ⛔⛔★★★ **ومسارٌ واحدٌ للسجلَّين** — `FR-M22` §1 نصّاً («**سجلّان
/// منفصلان في شاشة واحدة**») ⛔ **بخلاف الخصم والقبض**: ⟵ **فآليتُهما
/// واحدة تماماً والفارقُ في الصلاحية والتصنيف** (`outflow-design.md` §2)،
/// ★ **والفصلُ الأمني في المفاتيح والقاعدة والدالة الكاتبة** ⛔ **لا في
/// المسار** (`GR-43`).
const String outflowRoute = '/home/outflows';

/// ★★★ **مسار ضمار المالك وحركة النقد** (`M15` · `WU-016`) — **مستويان**.
///
/// ⛔★★ **ولا معامل مصدرٍ ولا تاريخٍ في المسار** — ★ **كلاهما مرشِّحٌ داخل
/// الشاشة** (`FR-M15-22`): ⟵ **ومسارٌ يحمل مصدراً كان يصير طريقاً ثانياً
/// لقراءة بطاقةٍ ماليةٍ خارج نطاق قارئه** (نفسُ علّة `sackFinanceRoute`).
const String ownerLedgerRoute = '/home/owner-ledger';

/// ★★ **مسار سجل الأيام السابقة** (`FR-M15-14`) — **ثلاثة مستويات وهو الحدّ**
/// (`ui-guidelines.md` §4)، ⟵ **فلا يُضاف تحته شيء.**
///
/// ⛔ **ومصدرُه من حالة الشاشة الأمّ لا من المسار** — ★ **فالسجلُّ امتدادٌ
/// لبطاقةٍ مفتوحة** ⛔ **لا وجهةٌ مستقلة تُشارَك برابط.**
const String ownerLedgerHistoryRoute = '/home/owner-ledger/history';

/// ★★ **مسار مالية الجواني وحساب الرعوي** (`M14` · `WU-015`) — **مستويان**.
///
/// ⛔★★ **ولا معامل رعويٍّ ولا تاريخٍ في المسار** — ★ **كلاهما مرشِّحٌ داخل
/// الشاشة** (`FR-M14-01` · `ui-guidelines.md` §4): ⟵ **ومسارٌ يحمل رعوياً
/// كان يصير طريقاً ثانياً لقراءة حسابٍ ماليّ** بلا الشاشة التي تملك
/// صلاحيته وسياقه (بنفس علّة `auditLogRoute` أدناه).
const String sackFinanceRoute = '/home/sack-finance';

/// ★ مسار سجل التدقيق المركزي (`FR-M18-09`) — **مستويان**.
///
/// ⛔★★ **ولا معامل كيانٍ في المسار** — ★ **السجل السياقي ورقةٌ تُفتَح فوق
/// شاشته** (`FR-M18-10`) ⛔ **لا مسارٌ ثالث**: ⟵ **ومسارٌ يقبل كياناً كان
/// سيصير طريقاً ثانياً لقراءة السجل** بلا الشاشة التي تملك صلاحيته.
const String auditLogRoute = '/home/audit';

/// ★ مسار مركز الإدخالات المعلّقة (`FR-SYS-01`…`FR-SYS-10`) — **مستويان**.
///
/// ⛔★★ **ولا معامل مستندٍ ولا حقلٍ في المسار** — ★ **وجهةُ زر [ إدخال ]
/// حالةٌ في التطبيق** (`pendingFocusProvider`) ⛔ **لا رابطٌ يُشارَك**:
/// ⟵ **ومسارٌ يحمل معرّف بندٍ كان يصير طريقاً ثانياً لفتح مستند** بلا
/// الشاشة التي تملك صلاحيته وسياقه (بنفس علّة `auditLogRoute`).
const String pendingEntriesRoute = '/home/pending';

/// ★★★ **مسارُ الشاشة الأصلية لبندٍ معلّق** — `FR-SYS-04`.
///
/// ⛔⛔ **ولا شاشةَ إدخالٍ بديلة** (`pending-entries-design.md` §6) —
/// ★ **وطبقةُ النطاق تُسمّي الشاشة، والتطبيق وحده يعرف مسارَها**
/// (`ADR-0009`): ⟵ **فلا مسارٌ محفورٌ في `qtms_domain`.**
String pendingScreenRoute(PendingScreen screen) => switch (screen) {
      // ★★ **والجونيةُ تبويبٌ في «التوريد مخزني» منذ `AM-012` §2** — ★ **ويُفتَح
      //   على تبويبها بـ[supplyIntakeSackTab]** ⛔ **لا على التبويب الأول.**
      PendingScreen.sackIntake => supplyIntakeRoute,
      PendingScreen.dailyPricing => dailyPricingRoute,
      PendingScreen.distribution => distributionRoute,
      // ★★ **وشاشةٌ رابعة منذ `WU-014`** — ⟵ **وواحدةٌ للسجلَّين**
      //   (`FR-M22` §1): ★ **والسجلُّ المقصود يُقرأ من رقم المستند نفسِه**
      //   (`WDR-` · `EXP-`) ⛔ **لا من قيمةٍ ثانية في المعجم.**
      PendingScreen.outflow => outflowRoute,
    };

/// ★ مسار قائمة التقارير (`FR-M19`) — **مستويان**.
///
/// ⛔★★ **ولا معامل تقريرٍ هنا** — ★ **القائمةُ وجهةٌ والتقريرُ وجهةٌ تحتها**:
/// ⟵ **فيبقى العمق ثلاثةً وهو الحدّ** (`ui-guidelines.md` §4).
const String reportsRoute = '/home/reports';

/// ★★ مسارُ تقريرٍ بعينه — **ثلاثة مستويات وهو الحدّ** (`ui-guidelines.md` §4).
///
/// ⛔⛔★★ **ولا فلاترَ في المسار** — ★ **الفترةُ والمصدر حالةٌ في التطبيق**
/// (`reportRequestProvider`) ⛔ **لا رابطٌ يُشارَك**: ⟵ **ومسارٌ يحملها كان
/// يصير طريقاً ثانياً لقراءة أرقامٍ مالية** بلا الشاشة التي تملك صلاحيتها
/// (بنفس علّة `auditLogRoute` حرفياً).
String reportRoute(ReportId report) => '$reportsRoute/${report.code}';

/// ★★ مسار الإعداد التأسيسي (`FR-M21-04`) — **خارج الصدَفة عمداً**.
///
/// ⛔ **ولا يُدرَج تحت `/home`:** الشاشة **إلزامية لا تُتخطّى**، ⟵ **ووضعُها
/// تحت الصدَفة كان سيُتيح الرجوع إليها منها** فتُصبح خياراً لا بوابة.
const String setupRoute = '/setup';

/// موجّه التطبيق.
final Provider<GoRouter> routerProvider = Provider<GoRouter>((Ref ref) {
  final _SessionRefreshNotifier refresh = _SessionRefreshNotifier(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: splashRoute,
    refreshListenable: refresh,
    redirect: (BuildContext context, GoRouterState state) =>
        _redirect(ref, state.matchedLocation),
    routes: <RouteBase>[
      GoRoute(
        path: splashRoute,
        builder: (BuildContext context, GoRouterState state) => const _SplashScreen(),
      ),
      GoRoute(
        path: loginRoute,
        builder: (BuildContext context, GoRouterState state) => const LoginScreen(),
      ),
      GoRoute(
        path: homeRoute,
        builder: (BuildContext context, GoRouterState state) => const HomeShell(),
        routes: <RouteBase>[
          GoRoute(
            path: 'users',
            builder: (BuildContext context, GoRouterState state) =>
                const UsersScreen(),
            routes: <RouteBase>[
              GoRoute(
                path: ':userId/permissions',
                builder: (BuildContext context, GoRouterState state) =>
                    PermissionsScreen(
                  // ⛔ **معرّفٌ غائب ⟵ نصٌّ فارغ فتُظهر الشاشة تعذّراً
                  //    صريحاً** — ولا انهيار ولا شاشة بيضاء.
                  userId: state.pathParameters['userId'] ?? '',
                ),
              ),
            ],
          ),
          GoRoute(
            path: 'roles',
            builder: (BuildContext context, GoRouterState state) =>
                const RolesScreen(),
          ),
          // ── ★★★ الملفُّ الشخصي والإعدادات (`AM-012` §4.4 و§5) ──
          //
          // ⛔⛔ **وكلتاهما بلا بوابة صلاحية** — ★ **ولا مفتاحَ لهما في
          //    الكتالوج** (`BR-M1-07`): ⟵ **بياناتُ صاحب الجلسة نفسِه
          //    وتفضيلاتُ جهازه ليستا مورداً يُؤذَن فيه**، ⛔ **ولا تقرأ
          //    أيٌّ منهما مستندَ أحدٍ سواه.**
          GoRoute(
            path: 'profile',
            builder: (BuildContext context, GoRouterState state) =>
                const ProfileScreen(),
          ),
          GoRoute(
            path: 'settings',
            builder: (BuildContext context, GoRouterState state) =>
                const SettingsScreen(),
          ),
          GoRoute(
            path: 'about',
            builder: (BuildContext context, GoRouterState state) =>
                const AboutScreen(),
          ),
          // ── البيانات المرجعية (`WU-002`) — أربع قوائم بمستويين ──
          GoRoute(
            path: 'sources',
            builder: (BuildContext context, GoRouterState state) =>
                const SourcesScreen(),
          ),
          GoRoute(
            path: 'suppliers',
            builder: (BuildContext context, GoRouterState state) =>
                const SuppliersScreen(),
          ),
          GoRoute(
            path: 'dealers',
            builder: (BuildContext context, GoRouterState state) =>
                const DealersScreen(),
          ),
          GoRoute(
            path: 'items',
            builder: (BuildContext context, GoRouterState state) =>
                const ItemsScreen(),
          ),
          // ── ★★★ التوريد مخزني (`WU-003` + `WU-004` · `AM-012` §2) ──
          //
          // ⛔⛔ **وشاشةٌ واحدة بتبويبين** — ★ **حلّت محلّ `intake` و`sacks`:**
          //    ⟵ **والمساران القديمان لم يعودا يُعرَّفان**، ⛔ **فلا بابٌ
          //    ثانٍ يفتح نصفَ الشاشة بلا تبويبها الآخر.**
          GoRoute(
            path: 'supply',
            builder: (BuildContext context, GoRouterState state) =>
                SupplyIntakeScreen(
              // ★★ **والتبويبُ المطلوب حالةُ ملاحةٍ في التطبيق** — ⛔ **لا
              //    معاملٌ في الرابط:** ⟵ **يُمرَّر من `extra` عند الحاجة**
              //    (مركزُ الإدخالات المعلّقة)، ★ **وافتراضُه الأول.**
              initialTab: state.extra is int
                  ? state.extra! as int
                  : supplyIntakeCountedTab,
            ),
          ),
          // ── المخزون اليومي (`WU-003`) — شاشةٌ بمستويين ──
          GoRoute(
            path: 'stock',
            builder: (BuildContext context, GoRouterState state) =>
                const TodayStockScreen(),
          ),
          // ── التسعير اليومي (`WU-005`) — شاشةٌ بمستويين ──
          GoRoute(
            path: 'pricing',
            builder: (BuildContext context, GoRouterState state) =>
                const DailyPricingScreen(),
          ),
          // ── التوزيع والضمار (`WU-006`) — شاشةٌ بمستويين ──
          GoRoute(
            path: 'distribution',
            builder: (BuildContext context, GoRouterState state) =>
                const DistributionScreen(),
          ),
          // ── البيع النقدي (`WU-012`) — شاشةٌ بمستويين ──
          GoRoute(
            path: 'cash-sales',
            builder: (BuildContext context, GoRouterState state) =>
                const CashSaleScreen(),
          ),
          // ── مالية الجواني وحساب الرعوي (`WU-015`) — شاشةٌ بمستويين ──
          GoRoute(
            path: 'sack-finance',
            builder: (BuildContext context, GoRouterState state) =>
                const SackFinanceScreen(),
          ),
          // ── المقبوضات (`WU-007`) — شاشةٌ بمستويين ──
          GoRoute(
            path: 'receipts',
            builder: (BuildContext context, GoRouterState state) =>
                const ReceiptScreen(),
          ),
          // ── كشف حساب المقوت (`WU-017`) — شاشةٌ بمستويين وتبويبين ──
          GoRoute(
            path: 'dealer-statement',
            builder: (BuildContext context, GoRouterState state) =>
                const DealerStatementScreen(),
          ),
          // ── الخصومات (`WU-013`) — شاشةٌ بمستويين ──
          GoRoute(
            path: 'discounts',
            builder: (BuildContext context, GoRouterState state) =>
                const DiscountScreen(),
          ),
          // ── السحبيات والخرجيات (`WU-014`) — شاشةٌ بمستويين ──
          GoRoute(
            path: 'outflows',
            builder: (BuildContext context, GoRouterState state) =>
                const OutflowScreen(),
          ),
          // ── ضمار المالك وحركة النقد (`WU-016`) — بطاقةٌ وسجلٌّ تحتها ──
          GoRoute(
            path: 'owner-ledger',
            builder: (BuildContext context, GoRouterState state) =>
                const OwnerLedgerScreen(),
            routes: <RouteBase>[
              GoRoute(
                path: 'history',
                builder: (BuildContext context, GoRouterState state) =>
                    const OwnerLedgerHistoryScreen(),
              ),
            ],
          ),
          // ── سجل التدقيق (`WU-008`) — شاشةٌ بمستويين ──
          GoRoute(
            path: 'audit',
            builder: (BuildContext context, GoRouterState state) =>
                const AuditLogScreen(),
          ),
          // ── مركز الإدخالات المعلّقة (`WU-009`) — شاشةٌ بمستويين ──
          GoRoute(
            path: 'pending',
            builder: (BuildContext context, GoRouterState state) =>
                const PendingEntriesScreen(),
          ),
          // ── التقارير (`WU-011`) — قائمةٌ بمستويين وتقريرٌ بثلاثة ──
          GoRoute(
            path: 'reports',
            builder: (BuildContext context, GoRouterState state) =>
                const ReportsScreen(),
            routes: <RouteBase>[
              GoRoute(
                path: ':reportCode',
                builder: (BuildContext context, GoRouterState state) {
                  final ReportId? report =
                      ReportId.tryParse(state.pathParameters['reportCode']);
                  // ⛔⛔★★ **ورمزٌ لا يعرفه هذا الإصدار يعود للقائمة** —
                  //    ★ **ولا يُفتَح على تقريرٍ آخر** (`ReportId.tryParse`):
                  //    ⟵ **وفتحُ تقريرٍ غيرِ المقصود أسوأ من عدم فتحه**،
                  //    ⛔ **ولا شاشةَ بيضاء ولا انهيار.**
                  return report == null
                      ? const ReportsScreen()
                      : ReportViewScreen(report: report);
                },
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: setupRoute,
        builder: (BuildContext context, GoRouterState state) =>
            const FirstRunSetupScreen(),
      ),
      GoRoute(
        path: blockedRoute,
        builder: (BuildContext context, GoRouterState state) => const SessionBlockedScreen(),
      ),
    ],
  );
});

/// يُقرِّر الوجهة من حالة الجلسة وحدها.
///
/// ⚠️ **والحالة غير المعروفة تبقى على شاشة الانتظار** ⛔ **ولا تُعامَل
/// «خروجاً»**: إظهار شاشة الدخول لمستخدمٍ جلستُه قيد التحميل **يجعله يُدخل
/// بياناته بلا داعٍ**، وهو خطأ ميداني لا تجميلي.
String? _redirect(Ref ref, String location) {
  final AsyncValue<SessionState> async = ref.read(sessionProvider);
  final SessionState? session = async.value;

  final String target = switch (session) {
    null => splashRoute,
    SessionSignedOut() => loginRoute,
    SessionRejected() => blockedRoute,
    SessionActive() => homeRoute,
  };

  // ★★★ **بوابة الإعداد التأسيسي تعلو على كل مسار داخل الجلسة النشطة**
  //   (`FR-M21-04`: «شاشة إلزامية لا يمكن تخطّيها عند أول تشغيل بحساب
  //   المالك»). ⟵ **فلا شاشة عملٍ تُفتَح قبل كتابة البندين.**
  //
  // ⛔★★ **وتنطبق على من يملك `appSettingsWrite` وحده** — راجع
  //   `requiresFirstRunSetupProvider`: ★ **فمن لا يملكها لا مسار أمامه
  //   لإتمامها**، ⟵ **وحبسُه فيها يقفل عليه النظام بلا مخرَج.**
  if (session is SessionActive && ref.read(requiresFirstRunSetupProvider)) {
    return location == setupRoute ? null : setupRoute;
  }
  // ★ **وفور اكتمال الإعداد يُغادرها من تلقائه** — ⛔ ولا يبقى فيها.
  if (session is SessionActive && location == setupRoute) return homeRoute;

  // ★★ **الجلسة النشطة تبقى حيث هي داخل شجرة الصدَفة** — ⟵ **فلا يُطرَد
  //   المستخدم من شاشة فرعية إلى الرئيسية عند كل إعادة بناء**، وهو ما
  //   كان سيحدث لو قُورن الموضع بـ`homeRoute` حرفياً.
  // ⛔ **والحارس لم يُخفَّف:** ما دون الجلسة النشطة يُعاد توجيهه كما كان،
  //   ⟵ **فلا شاشة عملٍ تُفتَح بجلسة مرفوضة** (`FR-M1-15`).
  if (session is SessionActive && location.startsWith(homeRoute)) return null;

  return location == target ? null : target;
}

/// يُخطر الموجّه عند كل تبدّل في الجلسة.
class _SessionRefreshNotifier extends ChangeNotifier {
  _SessionRefreshNotifier(Ref ref) {
    ref.listen<AsyncValue<SessionState>>(
      sessionProvider,
      (AsyncValue<SessionState>? previous, AsyncValue<SessionState> next) =>
          notifyListeners(),
    );
    // ★★ **وبوابة الإعداد التأسيسي تُخطِر أيضاً** — ⟵ **فور كتابة البندين
    //   يخرج المالك من الشاشة الإلزامية من تلقائه**، ⛔ **بلا ملاحة يدوية
    //   في النموذج** (`first_run_setup_screen.dart`).
    ref.listen<bool>(
      requiresFirstRunSetupProvider,
      (bool? previous, bool next) => notifyListeners(),
    );
  }
}

/// شاشة انتظار قصيرة — ⛔ **بلا نصّ**: لا رسالة معتمدة لحالة الانتظار،
/// ★ **والمؤشّر وحده كافٍ** (`design-system.md` §هـ: الحالات إلزامية).
///
/// ★★ **وشعار العميل فوقه** (`AM-002` · `ui-guidelines.md` نمط 8-أ) —
/// ★ **فتُكمِل الشاشةُ ما بدأته شاشة الإقلاع الأصلية** (`launch_background.xml`
/// بالشعار نفسه) ⟵ **بلا وميض هوية بين الاثنتين.**
///
/// ⛔ **ولا نصّ أُضيف مع الشعار:** ★ **الشعار نفسه يحمل اسم العميل مرسوماً**،
/// ★ **فقاعدة «بلا نصّ» قائمة كما هي.**
/// ⛔ **ولا بصمة لجهة التطوير هنا إطلاقاً** — شاشة البداية مساحة هوية المنتج
/// حصراً (`developer-identity.md` §1 · §5 البند 3).
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              BrandLogo(),
              SizedBox(height: Spacing.space24),
              CircularProgressIndicator(),
            ],
          ),
        ),
      );
}

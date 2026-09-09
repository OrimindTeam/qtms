/// صدَفة التطبيق بعد الدخول — **نمط `P1`** (`MASTER.md` §5b · `ADR-0021`).
///
/// ⛔⛔★★★ **وحدُّها تغيّر بـ`AM-017`** — ★ **كان التعليق هنا يقول «⛔ لا رقم
/// مالي هنا ولا مؤشّر: الصدَفة بطاقةُ هويةٍ ومداخل لا لوحةً افتتاحية»**:
/// ⟵ **وذلك كان وصفَ المرحلة لا القرار** — ★ **و`ui-guidelines.md` §3 نمط 1
/// يصف «اللوحة الافتتاحية» ببنودها التسعة منذ `AM-007`**، ⛔ **وكان المنفَّذُ
/// منها الطبقةَ البصرية وحدها.** ✅ **وبـ`AM-017` رُكِّبت أربعةٌ منها فعلاً:**
/// ③ **بطاقةُ الضمار مطويّةً** · ④ **تفصيلٌ حسب المصدر** · ⑤ **بطاقةُ «يحتاج
/// إجراء»** · ⑥ **شبكةُ عمليات اليوم.**
///
/// ⛔ **وثلاثةٌ لم تُركَّب بعد: ⑦ حركة النقد · ⑧ مخزون اليوم · ⑨ أرصدة
/// المقاوته** — ★ **ويسبقها ② شريطُ نطاق المصدر** (`ui-guidelines.md` §3
/// نمط 1 القرار 5): ⟵ **فبلا مصدرٍ ظاهرٍ دائماً يصير كلُّ رقمٍ إضافيٍّ
/// غامضاً.**
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
/// ⛔⛔★★★ **ورابعٌ عالجه `AM-017`:** ★ **إحدى وعشرون وجهةً في عمودٍ واحدٍ من
/// أزرارٍ بعرضٍ كامل** — ⟵ **تمريرٌ يعادل أضعافَ ارتفاع الشاشة قبل بلوغ
/// «سجل التدقيق» و«التقارير»**: ✅ **فصارت شبكةَ بلاطاتٍ بعمودين.**
///
/// ⛔⛔★★★ **والبوابةُ هنا تسبق بناءَ المدخل** (`AM-017`) — ★ **الشاشةُ تقرأ
/// [hasPermissionProvider] وتبني [QtmsHubEntry] للمسموح به وحده**:
/// ⟵ **فيعرف [QtmsHubSection] عددَ بلاطاته قبل التخطيط** ⛔ **ولا يحسب خانةً
/// لمدخلٍ مخفيّ.** ⚠️⚠️ **وهو إخفاءٌ لا حماية كما كان** — ★ **ويقابله شرطٌ في
/// `firestore.rules` أو فحصٌ في الدالة الكاتبة** (`RISK-02` · `ADR-0013`
/// القاعدة 3). ⛔ **فلا يُكتفى بإخفاء مدخل أبداً.**
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qtms_domain/qtms_domain.dart';

import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/top_bar.dart';
import '../../../core/design/design_tokens.dart';
import '../../../core/messages/audit_labels.dart';
import '../../../core/ui/hub_section.dart';
import '../../../core/ui/needs_action_card.dart';
import '../../../core/ui/needs_action_row.dart';
import '../../../core/ui/status_pill.dart';
import '../../financial_outflow/application/owner_ledger_providers.dart';
import '../../financial_outflow/presentation/owner_ledger_card.dart';
import '../../financial_outflow/presentation/owner_ledger_format.dart';
import '../../financial_outflow/presentation/source_ledger_strip.dart';
import '../../inventory/application/aged_remainder_providers.dart';
import '../../inventory/application/inventory_providers.dart';
import '../../inventory/presentation/aged_remainder_screen.dart';
import '../../inventory/presentation/sack_finance_screen.dart';
import '../../inventory/presentation/supply_intake_screen.dart';
import '../../master_data/application/master_data_providers.dart';
import '../../oversight/application/audit_log_providers.dart';
import '../../oversight/application/pending_entries_providers.dart';
import '../../oversight/application/report_providers.dart';
import '../application/session_providers.dart';

/// الشاشة الرئيسية بعد الدخول.
class HomeShell extends ConsumerWidget {
  /// ينشئ الصدَفة.
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AuthSession? session = ref.watch(currentSessionProvider);
    if (session == null) return const Scaffold(body: SizedBox.shrink());

    return Scaffold(
      // ⛔⛔★★★ **الشريط العلوي الموحّد** — `ui-guidelines.md` §3-أ
      //    (`AM-008` ①): ★ **مكوّنٌ مركزيٌّ واحد لكل شاشة**، ⛔ **ولا `AppBar`
      //    مبنيٌّ هنا بعد اليوم.**
      //
      // ⛔⛔★★★ **ولا جرسَ تنبيهاتٍ فيه** (`AM-017` ⑤ · نمط 1 القرار 10):
      //    ★ **بطاقةُ «يحتاج إجراء» هي المصدرُ الوحيد لهذا النوع من
      //    المعلومة** — ⟵ **وجرسٌ يحمل العددَ نفسَه واجهةٌ ثانيةٌ لمصدرِ
      //    حقيقةٍ واحد** ⛔ **يُضعِف الوضوحَ ولا يقوّيه.**
      //
      // ⛔⛔★★★ **ولا أيقونةَ خروجٍ فيه بعد `AM-009` ①** — ★ **انتقلت إلى
      //    قائمة الجلسة على الصورة الرمزية** (`showQtmsSessionSheet`).
      appBar: const QtmsTopBar(screenTitle: 'لوحة اليوم'),
      body: Column(
        children: <Widget>[
          // ⛔⛔★★★ **مثبَّتةٌ خارج مساحة التمرير** — `ui-guidelines.md` §3
          //    نمط 1 القرار 9: ⟵ **فما يحتاج عملاً اليوم يبقى مرئياً طوال
          //    الجلسة** ⛔ **لا في أول ثانيةٍ وحدها.**
          const Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
              Spacing.screenPadding,
              Spacing.screenPadding,
              Spacing.screenPadding,
              Spacing.space12,
            ),
            child: _NeedsActionPanel(),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: Spacing.screenPadding,
              ),
              children: <Widget>[
                const _OwnerLedgerPanel(),
                for (final QtmsHubSection section in _sections(context, ref))
                  section,
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// ★★ **أقسامُ الصدَفة بمداخلها المسموح بها وحدها** — ⛔ **ولا بوابةَ
  /// تلفّ بلاطة**: ⟵ **فالقسمُ يعرف عددَه الحقيقي قبل التخطيط.**
  List<QtmsHubSection> _sections(BuildContext context, WidgetRef ref) {
    bool can(Permission permission) =>
        ref.watch(hasPermissionProvider(permission));
    bool canAny(List<Permission> permissions) => permissions.any(can);

    return <QtmsHubSection>[
      QtmsHubSection(
        title: 'العمليات اليومية',
        entries: <QtmsHubEntry>[
          // ★★ **الأساسيُّ الوحيد — وأكثرُ العمليات تكراراً** (`FR-M10`).
          if (can(Permission.distributionCreate))
            QtmsHubEntry(
              label: 'التوزيع',
              icon: Icons.local_shipping_outlined,
              onPressed: () => context.go(distributionRoute),
              isPrimary: true,
            ),
          // ★★ **ومؤكَّدان ثانويّان — الأكثرُ استخداماً يومياً بعد التوزيع**
          //    (`AM-017` المكسب السريع): ⛔ **ولا ثالثَ لهما في هذا القسم.**
          if (can(Permission.cashSaleCreate))
            QtmsHubEntry(
              label: 'البيع النقدي',
              icon: Icons.point_of_sale_outlined,
              onPressed: () => context.go(cashSaleRoute),
              isFrequent: true,
            ),
          if (can(Permission.receiptCreate))
            QtmsHubEntry(
              label: 'المقبوضات',
              icon: Icons.payments_outlined,
              onPressed: () => context.go(receiptRoute),
              isFrequent: true,
            ),
          if (can(Permission.discountCreate))
            QtmsHubEntry(
              label: 'الخصومات',
              icon: Icons.percent_outlined,
              onPressed: () => context.go(discountRoute),
            ),
          if (can(Permission.dealerStatementView))
            QtmsHubEntry(
              label: 'كشف حساب المقوت',
              icon: Icons.receipt_long_outlined,
              onPressed: () => context.go(dealerStatementRoute),
            ),
          if (can(Permission.ownerLedgerView))
            QtmsHubEntry(
              label: 'ضمار المالك',
              icon: Icons.account_balance_wallet_outlined,
              onPressed: () => context.go(ownerLedgerRoute),
            ),
          if (canAny(<Permission>[
            Permission.withdrawalCreate,
            Permission.expenseCreate,
          ]))
            QtmsHubEntry(
              label: 'السحبيات والخرجيات',
              icon: Icons.outbound_outlined,
              onPressed: () => context.go(outflowRoute),
            ),
          if (canAny(<Permission>[
            Permission.incomingCountWrite,
            Permission.sackCreate,
          ]))
            QtmsHubEntry(
              label: supplyIntakeScreenTitle,
              icon: Icons.add_box_outlined,
              onPressed: () => context.go(supplyIntakeRoute),
            ),
          QtmsHubEntry(
            label: 'مخزون اليوم',
            icon: Icons.inventory_2_outlined,
            onPressed: () => context.go(todayStockRoute),
          ),
          QtmsHubEntry(
            label: 'التسعير اليومي',
            icon: Icons.sell_outlined,
            onPressed: () => context.go(dailyPricingRoute),
          ),
          if (can(Permission.disposalCreate))
            QtmsHubEntry(
              label: 'الإتلاف',
              icon: Icons.no_food_outlined,
              onPressed: () => context.go(disposalRoute),
            ),
          if (can(Permission.stocktakeWrite))
            QtmsHubEntry(
              label: 'الجرد',
              icon: Icons.fact_check_outlined,
              onPressed: () => context.go(stocktakeRoute),
            ),
        ],
      ),
      QtmsHubSection(
        title: 'البيانات المرجعية',
        entries: <QtmsHubEntry>[
          if (can(Permission.sourceWrite))
            QtmsHubEntry(
              label: 'المصادر',
              icon: Icons.warehouse_outlined,
              onPressed: () => context.go(sourcesRoute),
            ),
          if (can(Permission.supplierWrite))
            QtmsHubEntry(
              label: 'الرعية',
              icon: Icons.agriculture_outlined,
              onPressed: () => context.go(suppliersRoute),
            ),
          if (can(Permission.dealerWrite))
            QtmsHubEntry(
              label: 'المقاوته',
              icon: Icons.handshake_outlined,
              onPressed: () => context.go(dealersRoute),
            ),
          if (can(Permission.itemWrite))
            QtmsHubEntry(
              label: 'الأنواع',
              icon: Icons.category_outlined,
              onPressed: () => context.go(itemsRoute),
            ),
        ],
      ),
      QtmsHubSection(
        title: 'الهوية والصلاحيات',
        entries: <QtmsHubEntry>[
          if (can(Permission.userView))
            QtmsHubEntry(
              label: 'إدارة المستخدمين',
              icon: Icons.group_outlined,
              onPressed: () => context.go(usersRoute),
            ),
          if (can(Permission.roleWrite))
            QtmsHubEntry(
              label: 'الأدوار',
              icon: Icons.badge_outlined,
              onPressed: () => context.go(rolesRoute),
            ),
        ],
      ),
      // ★★ **قسمُ المالية** — `ui-guidelines.md` §4-أ التبويب ④.
      //
      // ⛔⛔★★ **ومدخلٌ مستقلٌّ عن «الرعية» في البيانات المرجعية:**
      //    ★ **تلك تهيئةُ كياناتٍ بمفتاح `supplierWrite`**، ⟵ **وهذه
      //    حسابٌ ماليٌّ بمفتاحَي قراءةٍ آخرَين** (`sackFinanceView` ·
      //    `supplierFinanceView`) — ⛔ **ودمجُهما كان يُلزم من يقرأ
      //    الحساب بامتلاك صلاحية تعديل الرعية.**
      //
      // ★★ **والبوابةُ على `sackView`** — ⟵ **فبلا قراءةِ الجونية نفسِها
      //    لا سطرَ في الشاشة أصلاً**، ★ **والمبالغُ تُخفيها `sackFinanceView`
      //    داخلَها بندًا بندًا** (`ADR-0011`).
      QtmsHubSection(
        title: 'المالية',
        entries: <QtmsHubEntry>[
          if (can(Permission.sackView))
            QtmsHubEntry(
              label: sackFinanceScreenTitle,
              icon: Icons.account_balance_wallet_outlined,
              onPressed: () => context.go(sackFinanceRoute),
            ),
        ],
      ),
      QtmsHubSection(
        title: 'الرقابة',
        entries: <QtmsHubEntry>[
          // ★★ **و`auditLogViewCentral` تحديداً** — `FR-M18-12`،
          //    ⛔ **بخلاف السجل السياقي** الذي يتبع صلاحية عرض وحدته.
          if (can(Permission.auditLogViewCentral))
            QtmsHubEntry(
              label: 'سجل التدقيق',
              icon: Icons.fact_check_outlined,
              onPressed: () => context.go(auditLogRoute),
            ),
          // ⛔⛔★★ **ومدخلُ التقارير بستة مفاتيحَ لا بواحد** (`IQ-034`) —
          //    ★ **والشرطُ «يملك مفتاحَ عائلةٍ واحدةٍ على الأقل»**،
          //    ⛔ **ومَن لا يملك أياً منها لا يرى مدخلاً يفتح على فراغ.**
          if (ref.watch(visibleReportsProvider).isNotEmpty)
            QtmsHubEntry(
              label: 'التقارير',
              icon: Icons.assessment_outlined,
              onPressed: () => context.go(reportsRoute),
            ),
        ],
      ),
    ];
  }
}

// ═══════════════ ③ و④ — بطاقةُ الضمار وتفصيلُها حسب المصدر ═══════════════

/// ★★★ **بطاقةُ ضمار المالك مدمَجةً في اللوحة** — `AM-017` ①.
///
/// ⛔⛔ **مطويّةٌ افتراضاً** (`design-system.md` §7.1 القاعدة 8) — ⟵ **فاللوحةُ
/// تُمسَح مسحاً سريعاً، وتسعةُ بنودِ اشتقاقٍ فيها تدفع الشبكةَ خارج الشاشة.**
/// ⛔⛔ **ولا تُغني عن `/home/owner-ledger`** (القاعدة 9) — ★ **تلك تحمل
/// الرسمَ البياني وسجلَّ الأيام السابقة.**
class _OwnerLedgerPanel extends ConsumerWidget {
  const _OwnerLedgerPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ⚠️ **إخفاءٌ لا حماية** — ★ **والشرطُ في `firestore.rules`** (`RISK-02`).
    if (!ref.watch(hasPermissionProvider(Permission.ownerLedgerView))) {
      return const SizedBox.shrink();
    }

    final AsyncValue<OwnerLedgerProjection?> card =
        ref.watch(ownerLedgerCardProvider);
    final CalendarDay day = ref.watch(ownerLedgerDayProvider);
    final String? sourceId = ref.watch(ownerLedgerSourceProvider);
    final String scopeLabel = sourceId == null
        ? 'كل المصادر'
        : _sourceName(ref.watch(activeSourcesProvider), sourceId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        switch (card) {
          // ⛔ **والخطأُ يُقال ولا يُخفى** — §هـ.
          AsyncError<OwnerLedgerProjection?>() => _LedgerNotice(
              text: 'تعذّر عرض ضمار اليوم — افتح الشاشة لإعادة المحاولة',
              onTap: () => context.go(ownerLedgerRoute),
            ),
          // ★ **والهيكلُ العظمي وحدَه حالةَ تحميل** — ⛔ **لا مؤشّرَ دوّار.**
          AsyncLoading<OwnerLedgerProjection?>() => const _LedgerSkeleton(),
          AsyncValue<OwnerLedgerProjection?>(
            :final OwnerLedgerProjection? value
          ) =>
            OwnerLedgerCard(
              initiallyExpanded: false,
              summary: ownerLedgerViewOf(
                value ??
                    projectOwnerLedgerSummary(
                      computeOwnerLedgerSummary(
                        sourceId: sourceId ?? allSourcesScopeId,
                        date: day,
                        contributions: const OwnerLedgerContributions(),
                      ),
                      ref.watch(ownerLedgerVisibilityProvider),
                    ),
                scopeLabel: scopeLabel,
                isLive: true,
              ),
              onRowTap: (String label) =>
                  _openLedgerRowDetail(context, ref, label),
            ),
        },
        const SizedBox(height: Spacing.space16),
        const SourceLedgerStrip(),
        const SizedBox(height: Spacing.space24),
      ],
    );
  }

  String _sourceName(List<SourceCard> sources, String sourceId) {
    for (final SourceCard source in sources) {
      if (source.sourceId == sourceId) return source.name;
    }
    return sourceId;
  }

  /// ★★★ **تفكيكُ بندٍ إلى وجهته** — §7.1 القاعدة 5: **السهمُ وعدٌ بوجهة.**
  ///
  /// ⛔⛔ **ووجهةُ من لا يملك مفتاحَها هي شاشةُ الضمار نفسُها** — ⟵ **فلا
  /// وعدٌ يُخلَف ولا شاشةٌ تُفتَح على رفض** (`RISK-02`).
  void _openLedgerRowDetail(BuildContext context, WidgetRef ref, String label) {
    bool can(Permission permission) =>
        ref.read(hasPermissionProvider(permission));

    final String route = switch (label) {
      'إجمالي الضمار' when can(Permission.dealerStatementView) =>
        dealerStatementRoute,
      'الواصل' when can(Permission.receiptCreate) => receiptRoute,
      'الخصومات' when can(Permission.discountCreate) => discountRoute,
      'إجمالي الضريبة' when can(Permission.sackView) => sackFinanceRoute,
      'السحبيات' || 'الخرجيات' when can(Permission.withdrawalCreate) ||
              can(Permission.expenseCreate) =>
        outflowRoute,
      _ => ownerLedgerRoute,
    };
    context.go(route);
  }
}

class _LedgerSkeleton extends StatelessWidget {
  const _LedgerSkeleton();

  @override
  Widget build(BuildContext context) => Container(
        height: Sizes.listRowHeight * 2,
        decoration: BoxDecoration(
          color: SemanticColors.skeleton,
          borderRadius: BorderRadius.circular(Radii.hero),
        ),
      );
}

class _LedgerNotice extends StatelessWidget {
  const _LedgerNotice({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: SemanticTriads.danger.soft,
        borderRadius: BorderRadius.circular(Radii.card),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Radii.card),
          child: Padding(
            padding: const EdgeInsets.all(Spacing.cardPadding),
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.error_outline,
                  size: Sizes.iconMd,
                  color: SemanticTriads.danger.ink,
                ),
                const SizedBox(width: Spacing.space8),
                Expanded(
                  child: Text(
                    text,
                    style: TypeScale.bodyMd
                        .copyWith(color: SemanticTriads.danger.ink),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

// ═════════════════════ ⑤ — بطاقةُ «يحتاج إجراء» الموحّدة ═════════════════════

/// ★★★ **ثلاثةُ بنودٍ تحت ترويسةٍ واحدة وعدّادٍ إجمالي** — `AM-017` ③.
///
/// ⛔⛔ **بعد أن كانت صفَّين متجاورين بعدّادين منفصلين** — ⟵ **فلا جوابَ
/// لسؤالٍ واحد: «هل عليّ عملٌ اليوم أصلاً؟».**
class _NeedsActionPanel extends ConsumerWidget {
  const _NeedsActionPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<int> pending = ref.watch(pendingEntriesCountProvider);
    final AsyncValue<AgedRemainderAlert> aged =
        ref.watch(agedRemainderAlertProvider);
    final bool showsAmendments =
        ref.watch(hasPermissionProvider(Permission.auditLogViewCentral));
    final AsyncValue<List<AuditLogEntryCard>> amendments =
        ref.watch(todayAmendmentsProvider);

    // ⛔⛔ **وبندٌ لا يُرسَم لا يدخل الإجمالي** (`design-system.md` §7).
    final int? pendingCount = pending.hasError ? null : pending.value;
    final int? agedCount =
        aged.hasError ? null : aged.value?.dayCount;
    final int? amendCount = !showsAmendments
        ? 0
        : amendments.hasError
            ? null
            : amendments.value?.length;

    final bool isTotalKnown =
        pendingCount != null && agedCount != null && amendCount != null;

    return QtmsNeedsActionCard(
      isTotalKnown: isTotalKnown,
      total: (pendingCount ?? 0) + (agedCount ?? 0) + (amendCount ?? 0),
      rows: <Widget>[
        const _PendingEntriesRow(),
        const _AgedRemainderRow(),
        if (showsAmendments) const _TodayAmendmentsRow(),
      ],
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
    final AsyncValue<Map<PendingDocumentKind?, int>> breakdown =
        ref.watch(pendingEntriesBreakdownProvider);

    return QtmsNeedsActionRow(
      isFramed: false,
      icon: Icons.hourglass_bottom_outlined,
      title: 'الإدخالات المعلّقة',
      destination: hasPending
          ? 'قيمٌ تُركت لاحقاً — افتح المركز لاستكمالها'
          : 'المركز يذكّر بما تُرك لاحقاً — ولا يمنع شيئاً',
      count: value ?? 0,
      // ★★ **الحدّةُ تصل ثلاثيةً جاهزة** — §5.1: ⛔ **ولا يقارن المكوّن رقماً.**
      triad: hasPending ? SemanticTriads.warning : SemanticTriads.neutral,
      countLabel: switch (value) {
        null when count.hasError => 'تعذّر',
        null => '—',
        0 => 'لا شيء',
        _ => null,
      },
      chips: _chips(breakdown),
      onTap: () => context.go(pendingEntriesRoute),
    );
  }

  List<Widget> _chips(AsyncValue<Map<PendingDocumentKind?, int>> breakdown) {
    final Map<PendingDocumentKind?, int>? counts =
        breakdown.hasError ? null : breakdown.value;
    if (counts == null || counts.isEmpty) return const <Widget>[];
    return <Widget>[
      for (final MapEntry<PendingDocumentKind?, int> entry in counts.entries)
        StatusPill(
          label: '${entry.key?.label ?? 'أخرى'} ${entry.value}',
          triad: SemanticTriads.warning,
        ),
    ];
  }
}

/// ★★★ صفُّ المتبقي المتأخر — `FR-M8-10` (`WU-019`).
///
/// ⛔⛔★★ **والعدّادُ عددُ الأيام لا عددُ البنود** — `UC-004` ① نصّاً:
/// «**📦 متبقي أيام سابقة: {العدد} أيام**» — ⟵ **فالسؤالُ «كم يوماً لم
/// يُقفَل؟»** ⛔ **لا «كم صنفاً بقي؟»**، ★ **والصنفُ تفصيلُ الشاشة.**
///
/// ⛔⛔★★ **والحالةُ الهادئة تُعرَض ولا تُخفى** (`design-system.md` §7 ·
/// `ui-guidelines.md` §3 نمط 1): ★ **«لا متبقي من أيام سابقة» بأيقونةٍ
/// هادئة** — ⟵ **فاختفاءُ الصفّ يجعل المستخدم يشكّ: أهو صفرٌ أم عطل؟**
class _AgedRemainderRow extends ConsumerWidget {
  const _AgedRemainderRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<AgedRemainderAlert> alert =
        ref.watch(agedRemainderAlertProvider);
    final AgedRemainderAlert? value = alert.hasError ? null : alert.value;
    final bool hasWork = value != null && value.hasWork;
    final AsyncValue<List<AgedRemainderDay>> days =
        ref.watch(agedRemainderDaysProvider(null));

    return QtmsNeedsActionRow(
      isFramed: false,
      // ★ **والأيقونةُ تتبع الحدّة** — ⛔ **ولا لونَ وحده يحمل المعنى** (§8).
      icon: hasWork
          ? agedSeverityIcon(value.severity)
          : Icons.event_available_outlined,
      title: 'متبقي أيام سابقة',
      destination: hasWork
          ? '${agedAgeLabel(value.oldestAgeInDays)} لأقدمها — '
              'افتح الشاشة لتصريفه على يومه'
          : 'كل مخزون الأيام الماضية صُرِّف بالكامل',
      // ★★ **الحدّةُ تصل ثلاثيةً جاهزة** — §5.1: ⛔ **ولا يقارن المكوّن رقماً.**
      triad: hasWork ? agedSeverityTriad(value.severity) : SemanticTriads.neutral,
      count: value?.dayCount ?? 0,
      countLabel: switch (value?.dayCount) {
        null when alert.hasError => 'تعذّر',
        null => '—',
        0 => 'لا شيء',
        _ => null,
      },
      chips: _chips(days),
      onTap: () => context.go(agedRemainderRoute),
    );
  }

  List<Widget> _chips(AsyncValue<List<AgedRemainderDay>> days) {
    final List<AgedRemainderDay>? value = days.hasError ? null : days.value;
    if (value == null || value.isEmpty) return const <Widget>[];
    return <Widget>[
      for (final AgedRemainderDay day in value)
        StatusPill(
          label: agedAgeLabel(day.ageInDays),
          triad: agedSeverityTriad(day.severity),
        ),
    ];
  }
}

/// ★★★ **تعديلاتُ اليوم على مستنداتٍ معتمدة** — `AM-017` ③.
///
/// ★ **بندٌ استباقيٌّ يكشف ما قد يستحق مراجعةَ الإدارة** — ⟵ **مبنيٌّ من
/// بياناتٍ قائمةٍ أصلاً في سجل التدقيق** ⛔ **لا مصدرَ بياناتٍ جديد.**
///
/// ⛔⛔ **ولا يُرسَم لمن لا يملك `auditLogViewCentral`** — ★ **والبوابةُ في
/// [_NeedsActionPanel] قبل بنائه** ⛔ **لا داخلَه.**
class _TodayAmendmentsRow extends ConsumerWidget {
  const _TodayAmendmentsRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<AuditLogEntryCard>> amendments =
        ref.watch(todayAmendmentsProvider);
    final List<AuditLogEntryCard>? value =
        amendments.hasError ? null : amendments.value;
    final bool hasWork = value != null && value.isNotEmpty;

    return QtmsNeedsActionRow(
      isFramed: false,
      icon: Icons.edit_note_outlined,
      title: 'تعديلات على مستندات معتمدة اليوم',
      destination: hasWork
          ? 'افتح سجل التدقيق لمراجعتها'
          : 'لم يُعدَّل مستندٌ معتمدٌ اليوم',
      count: value?.length ?? 0,
      triad: hasWork ? SemanticTriads.info : SemanticTriads.neutral,
      countLabel: switch (value?.length) {
        null when amendments.hasError => 'تعذّر',
        null => '—',
        0 => 'لا شيء',
        _ => null,
      },
      chips: _chips(value),
      // ★★ **والوجهةُ مُصفّاةٌ لا عامّة** — ⟵ **فمن نقر على «تعديلاتُ اليوم»
      //    يجد سجلاً مفلتَراً بفعل «تعديل» وبيومه** ⛔ **لا سجلاً كاملاً
      //    يبحث فيه بنفسه.**
      onTap: () {
        final CalendarDay today = ref.read(todayProvider);
        ref.read(auditLogFilterProvider.notifier)
          ..byAction(AuditAction.amend)
          ..withRange(from: today, to: today);
        context.go(auditLogRoute);
      },
    );
  }

  List<Widget> _chips(List<AuditLogEntryCard>? entries) {
    if (entries == null || entries.isEmpty) return const <Widget>[];
    final Map<String, int> byType = <String, int>{};
    for (final AuditLogEntryCard entry in entries) {
      byType[entry.entityType] = (byType[entry.entityType] ?? 0) + 1;
    }
    return <Widget>[
      for (final MapEntry<String, int> entry in byType.entries)
        StatusPill(
          label: '${auditEntityTypeLabel(entry.key)} ${entry.value}',
          triad: SemanticTriads.info,
        ),
    ];
  }
}

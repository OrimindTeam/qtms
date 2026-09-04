/// شاشة **كشف حساب المقوت** (`M17` · `WU-017`) — **نمط 3** (`ui-guidelines.md`
/// §3): ★ **رأسٌ ثابت، ثم صفُّ إجراءات، ثم تبويبان، ثم جدولُ الحركات.**
///
/// ★ **المصدر:** `FR-M17-01` … `FR-M17-09` · `settlement-design.md` §9 ·
/// `design-system.md` · `design-tokens.md` · `ui-guidelines.md` **نمط 3**
/// (بروتوكول التشغيل §ح — **تُقرأ قبل الكتابة لا بعدها**).
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **خمسُ قواعدَ تحكم كلَّ رقمٍ في هذه الشاشة:**
///
///   ① ★★★ **صفرُ حسابٍ هنا** (`design-system.md` §5.1) — ⟵ **الكشفُ يُبنى
///      في طبقة النطاق** ([buildDealerStatement]) **ويُسقَط جدولاً هناك**
///      ([buildDealerStatementTable]): ★ **والشاشةُ تعرض نصوصاً جاهزة.**
///   ② ⛔⛔★★★ **والجدولُ المعروض هو الجدولُ المُصدَّر نفسُه** — ⟵ **فالملفُّ
///      يطابق الشاشةَ رقماً برقم** (معيار قبول `WU-010`)، ⛔ **ولا مسارَ
///      تنسيقٍ ثانٍ بينهما.**
///   ③ ⛔⛔ **والرأسُ لا يتحرك مع تبديل التبويب** (نمط 3 نصّاً) — ★ **ولا
///      تكرارَ للمعلومة بين التبويبين**: ⟵ **المقوتُ والمصدرُ والفترةُ فوق
///      الشريط**، ⛔ **لا نسخةٌ منها في كلٍّ منهما.**
///   ④ ⛔⛔ **والملغاةُ تُعرَض مشطوبةً ولا تدخل رقماً** (`FR-M17-06` · `A-14`)
///      — ★ **وخيارُ «عرض الملغى» يُظهرها وحسب**: ⟵ **والإجمالياتُ محسوبةٌ
///      قبله في النطاق** ⛔ **فلا يستطيع تغيير مبلغٍ ولو أراد.**
///   ⑤ ⚠️⚠️ **وكلُّ بوابةٍ هنا إخفاءٌ لا حماية** (`RISK-02`) — ★ **والحارسُ
///      الحقيقي `perm('dealerBalanceView')` + النطاق في `firestore.rules`**:
///      ⛔ **ومفتاحا `IQ-040` بوابتا شاشةٍ لا حارسا سريّةٍ للأرقام** (`DEBT-71`).
/// ═══════════════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qtms_domain/qtms_domain.dart';

import '../../../app/top_bar.dart';
import '../../../core/design/design_tokens.dart';
import '../../../core/messages/error_messages.dart';
import '../../../core/ui/async_state_view.dart';
import '../../../core/ui/data_table.dart';
import '../../../core/ui/inline_banner.dart';
import '../../../core/ui/key_value_row.dart';
import '../../../core/ui/skeleton.dart';
import '../../identity_access/application/session_providers.dart';
import '../../inventory/application/inventory_providers.dart';
import '../../master_data/application/master_data_providers.dart';
import '../../oversight/application/document_export_action.dart';
import '../../oversight/application/messaging_providers.dart';
import '../application/dealer_statement_providers.dart';

/// عنوان الشاشة — ★ **مصدرٌ واحد يقرؤه الشريطُ والمدخلُ والاختبار**.
const String dealerStatementScreenTitle = 'كشف حساب المقوت';

/// شاشة كشف حساب المقوت.
class DealerStatementScreen extends ConsumerWidget {
  /// ينشئ الشاشة.
  const DealerStatementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<DealerStatement?> statement =
        ref.watch(dealerStatementProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: const QtmsTopBar(screenTitle: dealerStatementScreenTitle),
        body: Column(
          children: <Widget>[
            // ① ★ الرأسُ فوق شريط التبويبات — ⛔ **فلا يتحرك مع التبديل**
            //    (نمط 3 · `AM-012` §2 حرفياً).
            const _StatementHeader(),
            const _StatementTabBar(),
            Expanded(
              child: switch (statement) {
                // ⛔⛔ **الهيكلُ العظمي وحده حالةً للتحميل** — ★ **بوابةُ
                //    الحِرفية البصرية** (§8): ⛔ **ولا مؤشّرَ دوّار.**
                AsyncValue<DealerStatement?>(isLoading: true) =>
                  const SkeletonList(),
                AsyncValue<DealerStatement?>(:final Object? error)
                    when error != null =>
                  QtmsErrorState(
                    message: catalogText(CatalogMessage.operationFailed),
                    detail: '$error',
                    onRetry: () => ref.invalidate(dealerStatementProvider),
                  ),
                AsyncValue<DealerStatement?>(value: null) =>
                  const QtmsEmptyState(
                    spec: EmptyStateSpec(
                      icon: Icons.person_search_outlined,
                      title: 'اختر المقوت',
                      message: 'اختر المقوت من الرأس أعلاه ليُبنى كشفُ حسابه '
                          'من دفتر حركاته.',
                    ),
                  ),
                AsyncValue<DealerStatement?>(:final DealerStatement? value) =>
                  _StatementBody(statement: value!),
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════
// ① الرأس — المقوت والمصدر والفترة (`FR-M17-01`)
// ═════════════════════════════════════════════════════════════════════════

class _StatementHeader extends ConsumerWidget {
  const _StatementHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<DealerCard> dealers =
        ref.watch(dealersProvider).value ?? const <DealerCard>[];
    final List<SourceCard> sources = ref.watch(activeSourcesProvider);
    final String? dealerId = ref.watch(statementDealerProvider);
    final String? sourceId = ref.watch(statementSourceProvider);
    final ReportPeriod period = ref.watch(effectiveStatementPeriodProvider);
    // ★★ **وخيارُ «كل المصادر» بمفتاحه المستقل** — `IQ-040` الخيار أ.
    final bool allSources = ref.watch(canViewAllSourcesStatementProvider);

    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: Spacing.screenPadding,
        vertical: Spacing.space8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          DropdownButtonFormField<String>(
            initialValue: dealerId,
            decoration: const InputDecoration(labelText: 'المقوت'),
            items: <DropdownMenuItem<String>>[
              for (final DealerCard dealer in dealers)
                DropdownMenuItem<String>(
                  value: dealer.dealerId,
                  child: Text(dealer.name),
                ),
            ],
            onChanged: (String? value) =>
                ref.read(statementDealerProvider.notifier).select(value),
          ),
          const SizedBox(height: Spacing.space8),
          DropdownButtonFormField<String?>(
            initialValue: sourceId,
            decoration: const InputDecoration(labelText: 'المصدر'),
            items: <DropdownMenuItem<String?>>[
              // ⛔⛔ **ومن لا يملك المفتاح لا يرى الخيار أصلاً** — ★ **«الصلاحيات
              //    تُخفي لا تُعطِّل»** (`ui-guidelines.md` §2).
              if (allSources)
                const DropdownMenuItem<String?>(child: Text('كل المصادر')),
              for (final SourceCard source in sources)
                DropdownMenuItem<String?>(
                  value: source.sourceId,
                  child: Text(source.name),
                ),
            ],
            onChanged: (String? value) =>
                ref.read(statementSourceProvider.notifier).select(value),
          ),
          const SizedBox(height: Spacing.space8),
          // ★★ **والتاريخُ مُصرَّحٌ بنوعه** — `ui-guidelines.md` §2:
          //    ⛔ **لا كلمة «التاريخ» وحدها.**
          _PeriodRow(period: period),
        ],
      ),
    );
  }
}

/// صفُّ الفترة — **على تاريخ الإدخال** (`schema/dealer-ledger.md`).
class _PeriodRow extends ConsumerWidget {
  const _PeriodRow({required this.period});

  final ReportPeriod period;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Wrap(
        spacing: Spacing.space8,
        runSpacing: Spacing.space8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          Text(
            'تاريخ الإدخال: ${period.label}',
            style: TypeScale.bodyMd,
          ),
          TextButton(
            onPressed: () => _pick(context, ref, isFrom: true),
            child: const Text('تغيير البداية'),
          ),
          TextButton(
            onPressed: () => _pick(context, ref, isFrom: false),
            child: const Text('تغيير النهاية'),
          ),
        ],
      );

  /// ★ يفتح التقويم — ⛔ **والمستقبلُ مرفوض**: ★ **لا حركةَ بعد اليوم.**
  Future<void> _pick(
    BuildContext context,
    WidgetRef ref, {
    required bool isFrom,
  }) async {
    final CalendarDay today = ref.read(todayProvider);
    final CalendarDay current = isFrom ? period.from : period.to;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: current.asUtcMidnight(),
      firstDate: DateTime.utc(today.year - 5),
      lastDate: today.asUtcMidnight(),
    );
    if (picked == null) return;
    final CalendarDay day = CalendarDay.fromUtc(picked);
    ref.read(statementPeriodProvider.notifier).select(
          from: isFrom ? day : period.from,
          to: isFrom ? period.to : day,
        );
  }
}

// ═════════════════════════════════════════════════════════════════════════
// ② التبويبان — `FR-M17-02` (⛔ نمطان لا ثالثَ لهما)
// ═════════════════════════════════════════════════════════════════════════

class _StatementTabBar extends ConsumerWidget {
  const _StatementTabBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) => TabBar(
        onTap: (int index) =>
            ref.read(statementViewProvider.notifier).select(
                  index == 0
                      ? DealerStatementLayout.lots
                      : DealerStatementLayout.entries,
                ),
        tabs: const <Widget>[
          Tab(text: 'بالضمارات'),
          Tab(text: 'بالحركات'),
        ],
      );
}

// ═════════════════════════════════════════════════════════════════════════
// ③ الجسم — الجدولُ ثم التذييل (`FR-M17-07`)
// ═════════════════════════════════════════════════════════════════════════

class _StatementBody extends ConsumerStatefulWidget {
  const _StatementBody({required this.statement});

  final DealerStatement statement;

  @override
  ConsumerState<_StatementBody> createState() => _StatementBodyState();
}

class _StatementBodyState extends ConsumerState<_StatementBody> {
  bool _busy = false;
  String? _status;
  bool _statusIsSuccess = false;

  @override
  Widget build(BuildContext context) {
    final DealerStatement statement = widget.statement;
    final DealerStatementLayout layout = ref.watch(statementViewProvider);
    final bool showCancelled = ref.watch(statementShowCancelledProvider);
    final ReportPeriod period = ref.watch(effectiveStatementPeriodProvider);

    // ★★ **الجدولُ يُبنى في النطاق** — ⛔ **ولا خلية تُنسَّق هنا** (§5.1).
    final ReportTable table = buildDealerStatementTable(
      statement: statement,
      period: period,
      layout: layout,
      showCancelled: showCancelled,
      sourceName: (String id) => ref.read(sourceDisplayNameProvider(id)),
    );

    return ListView(
      padding: const EdgeInsetsDirectional.only(
        start: Spacing.screenPadding,
        end: Spacing.screenPadding,
        top: Spacing.space8,
        bottom: Spacing.space24,
      ),
      children: <Widget>[
        // ① صفوفُ الرأس — **الاسمُ والكودُ والهاتفُ والمصدرُ والفترة**.
        for (final ExportField field in table.header)
          QtmsKeyValueRow(label: field.label, value: field.value),
        const SizedBox(height: Spacing.space12),
        // ② ★ صفُّ الإجراءات — **عرضُ الملغى ثم التصدير** (نمط 3 ②).
        _ActionsRow(
          showCancelled: showCancelled,
          busy: _busy,
          onToggleCancelled: () =>
              ref.read(statementShowCancelledProvider.notifier).toggle(),
          onExport: () => _export(table, statement),
        ),
        const SizedBox(height: Spacing.space12),
        // ③ الجدول — ⛔ **أو حالةٌ فارغة بسببها وخطوتها**.
        if (table.rows.isEmpty)
          const QtmsEmptyState(
            spec: EmptyStateSpec(
              icon: Icons.receipt_long_outlined,
              title: 'لا حركة في هذه الفترة',
              message: 'لا يوجد في دفتر هذا المقوت ما يُعرَض بهذه الفترة '
                  'وهذا المصدر. وسّع الفترة أو بدّل المصدر.',
            ),
          )
        else
          QtmsDataTable(
            columns: <QtmsTableColumn>[
              for (final ReportColumn column in table.columns)
                QtmsTableColumn(column.label, numeric: column.numeric),
            ],
            rows: <QtmsTableRow>[
              for (final ReportRow row in table.rows)
                QtmsTableRow(row.cells, isStruck: row.isCancelled),
            ],
          ),
        const SizedBox(height: Spacing.space16),
        // ④ ★★ التذييل — **الرصيد رقماً وكتابةً والفائضُ والأعمار**.
        _StatementFooter(totals: table.totals),
        if (statement.lotsWithoutAge.isNotEmpty) ...<Widget>[
          const SizedBox(height: Spacing.space12),
          // ⚠️ **ولا يُخمَّن عمرُ ضمارٍ لا يُقرأ تاريخُه** — ★ **يُعلَن.**
          QtmsInlineBanner(
            text: '${statement.lotsWithoutAge.length} ضمار بلا تاريخ مقروء — '
                'مبالغه داخل الرصيد وخارج جدول الأعمار.',
            triad: SemanticTriads.warning,
          ),
        ],
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

  /// ★★ يُصدِّر الكشف — **بالإجراء المشترك نفسِه** (`WU-010` · `FR-M17-08`).
  ///
  /// ⛔⛔ **والمصدرُ المُصدَّر هو ما وقع عليه الاستعلام** — ★ **و«كل المصادر»
  /// تُمرَّر بـ`auditAllSourcesId`**: ⟵ **و`canAccessSource('all')` لا تصدُق
  /// إلا لصاحب النطاق الشامل** (`export_log.dart`) ⛔ **فلا يتّسع القيد.**
  Future<void> _export(ReportTable table, DealerStatement statement) async {
    setState(() {
      _busy = true;
      _status = null;
    });
    final String sourceId =
        ref.read(statementSourceProvider) ?? auditAllSourcesId;
    final ReportPeriod period = ref.read(effectiveStatementPeriodProvider);
    final DocumentExportResult result = await runDocumentExport(
      document: buildReportExport(
        business: ref.read(messageBusinessProvider),
        table: table,
        sourceId: sourceId,
        sourceName: ref.read(sourceDisplayNameProvider(sourceId)),
        // ★★ **ومعرّفُ الكيان يحمل المقوتَ مع المدى** — ⟵ **فقيدُ «تصدير»
        //    يقول كشفَ *من* خرج وعن أي فترة** (`FR-M19-04`)، ⛔ **لا «تقرير»
        //    مجرَّدةً ولا رمزَ تقريرٍ بلا صاحبه.**
        entityId: '${table.report.code}:${statement.dealerCode ?? ''}'
            ':${period.compactRange}',
      ),
      renderer: ref.read(pdfRendererProvider),
      sharer: ref.read(documentShareProvider),
      exportLog: ref.read(exportLogRepositoryProvider),
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _statusIsSuccess = result.isSuccess;
      _status = result.message;
    });
  }
}

/// صفُّ الإجراءات — ★ **الأول أساسي والبقية ثانوية** (`design-system.md` §ج).
class _ActionsRow extends ConsumerWidget {
  const _ActionsRow({
    required this.showCancelled,
    required this.busy,
    required this.onToggleCancelled,
    required this.onExport,
  });

  final bool showCancelled;
  final bool busy;
  final VoidCallback onToggleCancelled;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ⛔⛔ **والتصديرُ بمفتاحه** — `IQ-032`: ★ **مفتاحٌ واحد للسندات والتقارير**،
    //    ⟵ **ومن لا يملكه لا يرى الزرَّ أصلاً** (`ui-guidelines.md` §2).
    final bool canExport =
        ref.watch(hasPermissionProvider(Permission.documentExport));
    return Wrap(
      spacing: Spacing.space8,
      runSpacing: Spacing.space8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        if (canExport)
          FilledButton.icon(
            onPressed: busy ? null : onExport,
            icon: const Icon(Icons.picture_as_pdf_outlined,
                size: Sizes.iconMd),
            label: const Text('تصدير ومشاركة'),
          ),
        // ★ **وخيارُ «عرض الملغى»** — `FR-M17-06`: ⛔ **ولا يُغيِّر رقماً.**
        TextButton.icon(
          onPressed: onToggleCancelled,
          icon: Icon(
            showCancelled ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            size: Sizes.iconMd,
          ),
          label: Text(showCancelled ? 'إخفاء الملغى' : 'عرض الملغى'),
        ),
      ],
    );
  }
}

/// تذييلُ الكشف — `FR-M17-07`.
class _StatementFooter extends StatelessWidget {
  const _StatementFooter({required this.totals});

  final List<ExportField> totals;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsetsDirectional.all(Spacing.cardPadding),
        decoration: BoxDecoration(
          color: SemanticColors.surfaceSunken,
          border: Border.all(
            color: SemanticColors.border,
            width: Sizes.borderWidth,
          ),
          borderRadius: BorderRadius.circular(Radii.card),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (final ExportField total in totals)
              QtmsKeyValueRow(
                label: total.label,
                value: total.value,
                // ⛔⛔ **و«الرصيد كتابةً» نصٌّ لا رقم** — ★ **فلا يُثبَّت
                //    اتجاهُه ولا تُطلَب له أرقامٌ جدولية**: ⟵ **وتثبيتُ
                //    اتجاه جملةٍ عربية يقلبها.**
                numeric: total.label != 'الرصيد كتابةً' &&
                    !total.label.startsWith('⚠️'),
              ),
          ],
        ),
      );
}

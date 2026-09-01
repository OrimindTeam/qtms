/// شاشةُ تقريرٍ واحد — **نمط 6** (`ui-guidelines.md` §3).
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **والتقريرُ يُبنى من الدفتر لا من ملخص** (`ADR-0008`) — ★ **وكلُّ
/// رقمٍ فيه يصل الشاشةَ نصّاً منسَّقاً من طبقة النطاق** (`report_builders`)،
/// ⛔ **ولا حسابَ ولا تنسيقَ هنا** (`design-system.md` §5.1).
///
/// ⛔⛔★★★ **والملفُّ المُصدَّر يُبنى من الجدول المعروض نفسِه**
/// ([buildReportExport]) — ⟵ **فيطابق الشاشةَ رقماً برقم** (معيارُ قبول
/// `WU-010` نفسُه): ⛔ **ولا يُعاد بناؤه من البيانات الخام.**
///
/// ⚠️⚠️ **وكلُّ تقريرٍ يُصرِّح بمصدره وفترته** — `FR-M19-02`
/// (`ui-guidelines.md` نمط 6): ⟵ **ورقمٌ بلا مصدره غيرُ مقروء** (`ADR-0005`).
/// ═══════════════════════════════════════════════════════════════════════
///
/// ⚠️ **والتحديثُ بسحبٍ صريح لا بمستمعٍ حيّ** — `reporting-design.md` §4:
/// «**لا مستمعين لحظيين على التقارير — قراءة عند الطلب فقط**».
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qtms_domain/qtms_domain.dart';

import '../../../app/top_bar.dart';

import '../../../core/design/design_tokens.dart';
import '../../../core/messages/error_messages.dart';
import '../../../core/ui/async_state_view.dart';
import '../../../core/ui/data_table.dart';
import '../../../core/ui/date_labels.dart';
import '../../../core/ui/filter_bar.dart';
import '../../../core/ui/inline_banner.dart';
import '../../../core/ui/key_value_row.dart';
import '../../../core/ui/skeleton.dart';
import '../../identity_access/application/session_providers.dart';
import '../../inventory/application/inventory_providers.dart';
import '../../master_data/application/master_data_providers.dart';
import '../application/document_export_action.dart';
import '../application/messaging_providers.dart';
import '../application/report_providers.dart';

/// شاشة عرض تقريرٍ واحد.
class ReportViewScreen extends ConsumerStatefulWidget {
  /// ينشئ الشاشة.
  const ReportViewScreen({required this.report, super.key});

  /// التقرير المعروض.
  final ReportId report;

  @override
  ConsumerState<ReportViewScreen> createState() => _ReportViewScreenState();
}

class _ReportViewScreenState extends ConsumerState<ReportViewScreen> {
  String? _status;
  bool _statusIsSuccess = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // ⛔⛔★★★ **والتهيئةُ بعد أول إطار لا داخل `initState`** — `DEBT-68`:
    //    ★ **الكتابةُ في مزوّدٍ أثناء بناء الشجرة تُسقِط الشاشة كاملةً**
    //    (`Tried to modify a provider while the widget tree was building`)،
    //    ⛅ **وكشفها المحاكي وحده بعد 1594 اختباراً ناجحاً.**
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      if (!mounted) return;
      final ReportRequest? current = ref.read(reportRequestProvider);
      if (current?.report != widget.report) {
        ref.read(reportRequestProvider.notifier).open(widget.report);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<Outcome<ReportTable?>> outcome =
        ref.watch(reportTableProvider);
    // ★ **والجدولُ لا يُقرأ إلا من نتيجةٍ ناجحة** — ⛔ **ولا من `value` خاماً.**
    //
    // ⛔⛔★★★ **ولا يُقرأ وهو قيد إعادة الحساب** (`DEBT-74`): ★ **`AsyncValue`
    //    تحتفظ بقيمة التقرير السابق أثناء التحديث**، ⟵ **فيُصدَّر جدولُ تقريرٍ
    //    آخر تحت اسم هذا** ⛔ **وهو رقمٌ خاطئ في مستندٍ يصل يدَ العميل.**
    final ReportTable? table = outcome.isLoading
        ? null
        : switch (outcome.value) {
            Success<ReportTable?>(:final ReportTable? value) => value,
            _ => null,
          };
    final bool canExport =
        ref.watch(hasPermissionProvider(Permission.documentExport));

    return Scaffold(
      // ★★ **اسمُ الشاشة هو عنوان التقرير نفسُه** — ⟵ **ديناميكيٌّ فعلاً**
      //    (`ui-guidelines.md` §3-أ العنصر ②)، ⛔ **لا «التقارير» لكلٍّ منها.**
      appBar: QtmsTopBar(screenTitle: widget.report.title),
      floatingActionButton: canExport && table != null
          ? FloatingActionButton.extended(
              onPressed: _busy ? null : () => _export(table),
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('تصدير ومشاركة'),
            )
          : null,
      body: ListView(
        padding: const EdgeInsetsDirectional.only(
          start: Spacing.screenPadding,
          end: Spacing.screenPadding,
          top: Spacing.space8,
          bottom: Spacing.fabSafeBottom,
        ),
        children: <Widget>[
          _ReportFilters(report: widget.report),
          const SizedBox(height: Spacing.space12),
          switch (outcome) {
            // ★★ **هياكلُ صفوفٍ لا قائمةٌ ثانية** — ⛔ **و`SkeletonList` ممرٌّ
            //    بذاته**: ⟵ **وممرٌّ داخل ممرٍّ يُسقِط التخطيط بارتفاعٍ غير
            //    محدود** (`Vertical viewport was given unbounded height`).
            // ⛔⛔★★★ **والتحميلُ يُقاس بـ`isLoading` لا بخلوّ `value`**
            //    (`DEBT-74` · **كشفه المحاكي وحده**): ★ **`AsyncValue` تُبقي
            //    قيمة التقرير السابق أثناء إعادة الحساب**، ⟵ **فيظهر جدولُ
            //    «التوزيعات» بإجمالياته تحت عنوان «الضمارات» ثوانيَ كاملة**
            //    ⛔ **بلا أي مؤشّرٍ أن الأرقام ليست لهذا التقرير بعد.**
            AsyncValue<Outcome<ReportTable?>>(isLoading: true) ||
            AsyncValue<Outcome<ReportTable?>>(value: null) =>
              const Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  SkeletonTile(),
                  SizedBox(height: Spacing.cardGap),
                  SkeletonTile(),
                  SizedBox(height: Spacing.cardGap),
                  SkeletonTile(),
                ],
              ),
            // ⛔⛔★★ **والرفضُ يُعرَض برسالة الكتالوج** — ⛔ **لا برمزٍ تقني**
            //    (`error-handling-strategy.md` §3 القاعدة 2).
            AsyncValue<Outcome<ReportTable?>>(
              value: Failure<ReportTable?>(:final AppError error)
            ) =>
              QtmsErrorState(
                message: catalogText(appErrorMessage(error)),
                onRetry: () => ref.invalidate(reportTableProvider),
              ),
            AsyncValue<Outcome<ReportTable?>>(
              value: Success<ReportTable?>(value: null)
            ) =>
              QtmsEmptyState(
                spec: EmptyStateSpec(
                  icon: Icons.filter_alt_outlined,
                  title: 'اختر ما يلزم لبناء التقرير',
                  message: _missingFilterMessage(widget.report),
                ),
              ),
            AsyncValue<Outcome<ReportTable?>>(
              value: Success<ReportTable?>(:final ReportTable? value)
            ) =>
              _ReportBody(table: value!),
          },
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
      ),
    );
  }

  /// ★★ يُصدِّر الجدول المعروض — **بالإجراء المشترك نفسِه** (`WU-010`).
  ///
  /// ⛔⛔ **والمصدر في الترويسة اسماً لا معرّفاً** — ★ **و«كل المصادر»
  /// تُمرَّر بـ[auditAllSourcesId]**: ⟵ **و`canAccessSource('all')` لا تصدُق
  /// إلا لصاحب النطاق الشامل** (`export_log.dart`) ⛔ **فلا يتّسع القيد.**
  Future<void> _export(ReportTable table) async {
    final ReportRequest? request = ref.read(reportRequestProvider);
    if (request == null) return;
    setState(() {
      _busy = true;
      _status = null;
    });

    // ★★ **والمصدرُ المُصدَّر هو ما وقع عليه الاستعلام** — ⛔ **لا ما في
    //    الطلب**: ⟵ **و«كل المصادر» تُمرَّر بـ[auditAllSourcesId].**
    final String sourceId =
        ref.read(selectedReportSource) ?? auditAllSourcesId;
    final DocumentExportResult result = await runDocumentExport(
      document: buildReportExport(
        business: ref.read(messageBusinessProvider),
        table: table,
        sourceId: sourceId,
        sourceName: ref.read(sourceDisplayNameProvider(sourceId)),
        // ★★ **رمزُ التقرير مع مداه** — ⟵ **فقيدُ «تصدير» يقول أيَّ تقريرٍ
        //    خرج وعن أي فترة** (`FR-M19-04`) ⛔ **لا «تقرير» مجرَّدة.**
        entityId: '${table.report.code}:${request.period.compactRange}',
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

  /// ★ ما ينقص لبناء التقرير — ⛔ **ولا «لا توجد بيانات» بلا سبب**.
  static String _missingFilterMessage(ReportId report) => switch (report) {
        ReportId.itemMovements =>
          'اختر النوع الذي تريد حركته من شريط التصفية أعلاه.',
        ReportId.dealerStatement =>
          'اختر المقوت الذي تريد كشف حسابه من شريط التصفية أعلاه.',
        _ => 'اختر مصدراً وفترة من شريط التصفية أعلاه.',
      };
}

// ═════════════════════════════════════════════════════════════════════════
// جسمُ التقرير — الترويسة ثم التحذير ثم الجدول ثم الإجماليات
// ═════════════════════════════════════════════════════════════════════════

class _ReportBody extends StatelessWidget {
  const _ReportBody({required this.table});

  final ReportTable table;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // ① ★ الترويسة — **الفترة وأي فلترٍ فعّال** (والمصدر في الشريط).
          for (final ExportField field in table.header)
            QtmsKeyValueRow(label: field.label, value: field.value),
          // ② ⚠️ **تحذيرُ النواقص بنصّه المعتمد** — `FR-M19-08`.
          if (table.incompleteWarning case final String warning) ...<Widget>[
            const SizedBox(height: Spacing.space8),
            QtmsInlineBanner(text: warning, triad: SemanticTriads.warning),
          ],
          const SizedBox(height: Spacing.space12),
          // ③ الجدول — ⛔ **أو حالةٌ فارغة بسببها وخطوتها**.
          if (table.rows.isEmpty)
            const QtmsEmptyState(
              spec: EmptyStateSpec(
                icon: Icons.inbox_outlined,
                title: 'لا حركة في هذا المدى',
                message: 'لا يوجد ما يُعرَض بهذه الفلاتر. '
                    'وسّع الفترة أو بدّل المصدر ثم أعد العرض.',
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
          // ④ ★★ الإجماليات — **والحبّاتُ والأوزانُ سطران لا سطر** (`GR-19`).
          Container(
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
                for (final ExportField total in table.totals)
                  QtmsKeyValueRow(
                    label: total.label,
                    value: total.value,
                    numeric: true,
                  ),
              ],
            ),
          ),
        ],
      );
}

// ═════════════════════════════════════════════════════════════════════════
// شريطُ التصفية — المصدر ثم الفترة ثم ما يخصّ التقرير
// ═════════════════════════════════════════════════════════════════════════

class _ReportFilters extends ConsumerWidget {
  const _ReportFilters({required this.report});

  final ReportId report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ReportRequest? request = ref.watch(reportRequestProvider);
    final List<ReportSourceOption> sources =
        ref.watch(reportSourceOptionsProvider);
    if (request == null) return const SizedBox.shrink();
    if (sources.isEmpty) {
      // ⚠️ **نطاقٌ فارغ حالةٌ حقيقية** — `E-35`: مستخدمٌ بلا مصدر.
      return const QtmsFilterBar.notice(
        message: 'لا يوجد مصدر ضمن نطاقك. راجع المدير.',
      );
    }

    final ReportRequestState controller =
        ref.read(reportRequestProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        QtmsFilterBar(
          padded: false,
          groups: <List<QtmsFilterOption>>[
            <QtmsFilterOption>[
              for (final ReportSourceOption option in sources)
                QtmsFilterOption(
                  label: option.label,
                  // ★★ **والمختارُ هو ما يقع عليه الاستعلام فعلاً** — ⛔ **لا
                  //    ما في الطلب وحده**: ⟵ **فالمصدرُ الافتراضي يُحَلّ في
                  //    [effectiveReportSources] عند وصول القائمة**،
                  //    ⛔ **وشريحةٌ لا تُضيء تُقرأ «لم يُختَر شيء».**
                  selected: option.sourceId == null
                      ? request.allSources
                      : !request.allSources &&
                          option.sourceId ==
                              ref.watch(selectedReportSource),
                  onSelected: () => controller.selectSource(option.sourceId),
                ),
            ],
            ..._reportFilterGroups(ref, request, controller),
          ],
        ),
        const SizedBox(height: Spacing.space8),
        _PeriodRow(request: request, controller: controller),
      ],
    );
  }

  /// ★★ مجموعاتُ التصفية الخاصة بكل تقرير — **من `FR-M19` §2**.
  ///
  /// ⛔ **ولا يُعرَض فلترٌ لا أثر له في التقرير الجاري** — ★ **فمجموعةٌ
  /// لا تُغيِّر النتيجة تُقرأ عطلاً.**
  List<List<QtmsFilterOption>> _reportFilterGroups(
    WidgetRef ref,
    ReportRequest request,
    ReportRequestState controller,
  ) =>
      switch (report) {
        ReportId.itemMovements => <List<QtmsFilterOption>>[
            <QtmsFilterOption>[
              for (final ItemCard item
                  in ref.watch(itemsProvider).value ?? const <ItemCard>[])
                QtmsFilterOption(
                  label: item.name,
                  selected: request.itemKey == item.itemId,
                  onSelected: () => controller.selectItem(item.itemId),
                ),
            ],
          ],
        ReportId.currentStock => <List<QtmsFilterOption>>[
            <QtmsFilterOption>[
              QtmsFilterOption(
                label: 'الكل',
                selected: request.availability == null,
                onSelected: () => controller.selectAvailability(null),
              ),
              for (final StockAvailability value in StockAvailability.values)
                QtmsFilterOption(
                  label: value.label,
                  selected: request.availability == value,
                  onSelected: () => controller.selectAvailability(value),
                ),
            ],
          ],
        ReportId.settlements => <List<QtmsFilterOption>>[
            <QtmsFilterOption>[
              QtmsFilterOption(
                label: 'الكل',
                selected: request.settlementStatus == null,
                onSelected: () => controller.selectSettlementStatus(null),
              ),
              for (final SettlementStatus value in SettlementStatus.values)
                QtmsFilterOption(
                  label: _settlementLabel(value),
                  selected: request.settlementStatus == value,
                  onSelected: () => controller.selectSettlementStatus(value),
                ),
            ],
          ],
        ReportId.receipts => <List<QtmsFilterOption>>[
            <QtmsFilterOption>[
              QtmsFilterOption(
                label: 'الكل',
                selected: request.depositState == null,
                onSelected: () => controller.selectDepositState(null),
              ),
              for (final DepositState value in DepositState.values)
                QtmsFilterOption(
                  label: _depositLabel(value),
                  selected: request.depositState == value,
                  onSelected: () => controller.selectDepositState(value),
                ),
            ],
          ],
        ReportId.dealerBalances => <List<QtmsFilterOption>>[
            <QtmsFilterOption>[
              QtmsFilterOption(
                label: 'الكل',
                selected: request.balanceState == null,
                onSelected: () => controller.selectBalanceState(null),
              ),
              for (final DealerBalanceState value
                  in DealerBalanceState.values)
                QtmsFilterOption(
                  label: value.label,
                  selected: request.balanceState == value,
                  onSelected: () => controller.selectBalanceState(value),
                ),
            ],
          ],
        ReportId.dealerStatement => <List<QtmsFilterOption>>[
            <QtmsFilterOption>[
              for (final DealerCard dealer
                  in ref.watch(dealersProvider).value ?? const <DealerCard>[])
                QtmsFilterOption(
                  label: dealer.name,
                  selected: request.dealerId == dealer.dealerId,
                  onSelected: () => controller.selectDealer(dealer.dealerId),
                ),
            ],
          ],
        ReportId.pendingEntries => <List<QtmsFilterOption>>[
            <QtmsFilterOption>[
              QtmsFilterOption(
                label: 'الكل',
                selected: request.pendingKind == null,
                onSelected: () => controller.selectPendingKind(null),
              ),
              for (final PendingDocumentKind value
                  in PendingDocumentKind.values)
                QtmsFilterOption(
                  label: value.label,
                  selected: request.pendingKind == value,
                  onSelected: () => controller.selectPendingKind(value),
                ),
            ],
          ],
        _ => const <List<QtmsFilterOption>>[],
      };

  static String _settlementLabel(SettlementStatus status) => switch (status) {
        SettlementStatus.open => 'مفتوح',
        SettlementStatus.partiallyOpen => 'مفتوح جزئياً',
        SettlementStatus.closed => 'مغلق',
      };

  static String _depositLabel(DepositState state) => switch (state) {
        DepositState.notDeposited => 'لم يُودع',
        DepositState.deposited => 'أُودع',
      };
}

/// ★★ صفُّ الفترة — **يومان أو يومٌ واحد بحسب التقرير**.
///
/// ⛔⛔ **والتاريخ مُصرَّحٌ بنوعه** — `ui-guidelines.md` §2: ★ **«كل شاشة تعرض
/// تاريخاً تُصرِّح أيّ تاريخ تعرض»** ⛔ **لا كلمة «التاريخ» وحدها.**
class _PeriodRow extends ConsumerWidget {
  const _PeriodRow({required this.request, required this.controller});

  final ReportRequest request;
  final ReportRequestState controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CalendarDay today = ref.watch(todayProvider);
    final bool singleDay = request.report == ReportId.currentStock ||
        request.report == ReportId.todayRemainder;
    // ★★ **والاسم يقول أيَّ تاريخ** — **مخزونٌ أم إدخال** (`ADR-0006`).
    final String label = switch (request.report) {
      ReportId.receipts || ReportId.dealerStatement => 'تاريخ الإدخال',
      _ => 'تاريخ المخزون',
    };

    return Wrap(
      spacing: Spacing.space8,
      runSpacing: Spacing.space8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        Text(
          singleDay
              ? '$label: ${dayLabel(request.period.to)}'
              : '$label: ${request.period.label}',
          style: TypeScale.bodyMd,
        ),
        if (!singleDay)
          TextButton(
            onPressed: () => _pick(context, ref, today, isFrom: true),
            child: const Text('تغيير البداية'),
          ),
        TextButton(
          onPressed: () => _pick(context, ref, today, isFrom: false),
          child: Text(singleDay ? 'تغيير التاريخ' : 'تغيير النهاية'),
        ),
      ],
    );
  }

  /// ★ يفتح التقويم — ⛔ **والمستقبلُ مرفوض**: ★ **لا حركةَ بعد اليوم.**
  Future<void> _pick(
    BuildContext context,
    WidgetRef ref,
    CalendarDay today, {
    required bool isFrom,
  }) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate:
          (isFrom ? request.period.from : request.period.to).asUtcMidnight(),
      firstDate: DateTime.utc(today.year - 1),
      lastDate: today.asUtcMidnight(),
    );
    if (picked == null) return;
    final CalendarDay day = CalendarDay.fromUtc(picked.toUtc());
    final bool singleDay = request.report == ReportId.currentStock ||
        request.report == ReportId.todayRemainder;
    if (singleDay) {
      controller.withPeriod(from: day, to: day);
      return;
    }
    controller.withPeriod(
      from: isFrom ? day : request.period.from,
      to: isFrom ? request.period.to : day,
    );
  }
}

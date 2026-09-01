/// شاشة **سجل التدقيق المركزي** (`M18`) — **نمط 2** (`ui-guidelines.md` §3).
///
/// ⛔⛔★★ **عرضٌ محض ولا مسارَ كتابةٍ فيها إطلاقاً** — `FR-M18-01`: **السجل
/// للإضافة فقط، لا تعديل ولا حذف لأي مستخدم بمن فيهم المالك** (`GR-08`)،
/// ★ **والعقد نفسه بلا دالة كتابة** (`audit_log_repository.dart`).
///
/// ★★ **وصلاحيتُها «عرض سجل التدقيق المركزي»** (`FR-M18-12`) — ⛔ **بخلاف
/// السجل السياقي** الذي يتبع صلاحية عرض وحدته.
///
/// ⚠️⚠️ **والبوابة على مدخلها إخفاءٌ لا حماية** — ★ **والمنع الحقيقي شرطُ
/// القراءة في `firestore.rules`** (`match /audit_log/{logId}`) **مُختبَراً
/// على المحاكي** (`RISK-02`).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qtms_domain/qtms_domain.dart';

import '../../../app/top_bar.dart';

import '../../../core/design/design_tokens.dart';
import '../../../core/messages/audit_labels.dart';
import '../../../core/ui/filter_bar.dart';
import '../application/audit_log_providers.dart';
import 'audit_trail_view.dart';

/// شاشة سجل التدقيق المركزي.
class AuditLogScreen extends ConsumerWidget {
  /// ينشئ الشاشة.
  const AuditLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<AuditLogEntryCard>> entries =
        ref.watch(centralAuditLogProvider);

    return Scaffold(
      appBar: QtmsTopBar(screenTitle: 'سجل التدقيق'),
      body: Column(
        children: <Widget>[
          const _FilterBar(),
          const _AppendOnlyNotice(),
          const SizedBox(height: Spacing.space8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.screenPadding,
              ),
              child: AuditTrailList(
                entries: entries,
                shrinkWrap: false,
                emptyMessage: 'لا يوجد نشاط يطابق الفلتر الحالي — '
                    'وسّع المدى أو أزل الفلتر.',
                onRetry: () => ref.invalidate(centralAuditLogProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ★★ شريطٌ يُعلن أن السجل للإضافة فقط — ⛔ **ولا يُخفى**.
///
/// ⚠️⚠️ **ولماذا يُعرَض دائماً:** `FR-M18-01` هو **«الشرط الوحيد الذي يجعل
/// التعديل المباشر على الدفاتر آمناً»** — ⟵ **وإعلانُه للمستخدم جزءٌ من
/// أثره**: ★ **من يعلم أن أثره باقٍ لا يُمحى يتصرّف بحسبه**، ⛔ **وشاشةٌ
/// صامتة تترك الانطباع بأن السجل قابلٌ للتنظيف كغيره.**
class _AppendOnlyNotice extends StatelessWidget {
  const _AppendOnlyNotice();

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(horizontal: Spacing.screenPadding),
        padding: const EdgeInsets.all(Spacing.space12),
        decoration: BoxDecoration(
          color: SemanticColors.surfaceSunken,
          border: Border.all(color: SemanticColors.border),
          borderRadius: BorderRadius.circular(Radii.card),
        ),
        child: Row(
          children: <Widget>[
            const Icon(
              Icons.lock_outline,
              size: Sizes.iconMd,
              color: SemanticColors.textSecondary,
            ),
            const SizedBox(width: Spacing.space8),
            Expanded(
              child: Text(
                'هذا السجل للإضافة فقط — لا يُعدَّل ولا يُمسح منه شيء، '
                'ولا لأحد بمن فيهم المالك.',
                style: TypeScale.bodyMd
                    .copyWith(color: SemanticColors.textSecondary),
              ),
            ),
          ],
        ),
      );
}

/// ★★ شريط الفلاتر — `FR-M18-09`: **المصدر · الإجراء · التاريخ**.
///
/// ⛔⛔★★★ **والمصدر أولاً وفي كل حال — قياسٌ حيٌّ لا اختيارُ ذوق:**
/// استعلامُ `audit_log` **بلا قيدٍ على `sourceId` يُرفَض من القاعدة كاملاً**
/// **ولو بنطاقٍ شامل** (مقيسٌ على المحاكي 2026-08-27 · راجع
/// [AuditLogFilter]) — ⟵ **فبطاقةُ «كل النشاط» كانت ستُنتج شاشةَ خطأٍ
/// دائمة** ⛔ **على مستخدمٍ يملك صلاحيتها.**
///
/// ★★ **وهذا يوافق مبدأ النظام:** `A-01` — **لا جمع بين مصدرين في أي
/// عملية** — ⟵ **والسجل يُقرأ كما تُقرأ كل شاشةٍ أخرى: بمصدرٍ محدَّد.**
///
/// ⛔ **وبُعدٌ ثانويٌّ واحد فوقه لا اثنان** — راجع [AuditFilterDimension].
class _FilterBar extends ConsumerWidget {
  const _FilterBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AuditLogFilter? filter = ref.watch(auditLogFilterProvider);
    final AuditLogFilterState controller =
        ref.read(auditLogFilterProvider.notifier);
    final List<AuditSourceOption> sources =
        ref.watch(auditSourceOptionsProvider);

    if (sources.isEmpty) {
      // ⚠️ **نطاقٌ فارغ حالةٌ حقيقية** — `E-35`: مستخدمٌ بلا مصدر.
      return const QtmsFilterBar.notice(
        message: 'لا يوجد مصدر ضمن نطاقك. راجع المدير.',
      );
    }

    // ★★ **وصياغتُه [QtmsFilterBar]** (§5b · `ADR-0021`) — ⛔ **ولا شريطَ
    //    شرائحَ محليٌّ بعد اليوم** (§8 المحظور الحادي عشر).
    return QtmsFilterBar(
      groups: <List<QtmsFilterOption>>[
        // ★★ **والمصادر المعروضة مصادرُ نطاقه وحدها** — ⟵ **فالفلتر
        //    لا يعرض مصدراً لا تسمح القاعدة بقراءة قيوده**
        //    (`FR-M18-14` · `GR-23`).
        <QtmsFilterOption>[
          for (final AuditSourceOption source in sources)
            QtmsFilterOption(
              label: source.label,
              selected: filter?.sourceId == source.sourceId,
              onSelected: () => controller.selectSource(source.sourceId),
            ),
        ],
        <QtmsFilterOption>[
          QtmsFilterOption(
            label: 'كل الأفعال',
            selected: filter?.dimension == AuditFilterDimension.none,
            onSelected: controller.clearDimension,
          ),
          // ★ **بُعد الإجراء** — الفهرس `sourceId ↑ · action ↑ · occurredAt ↓`.
          for (final AuditAction action in _filterableActions)
            QtmsFilterOption(
              label: auditActionLabel(action),
              selected: filter?.dimension == AuditFilterDimension.action &&
                  filter?.action == action,
              onSelected: () => controller.byAction(action),
            ),
        ],
      ],
    );
  }
}

/// ★ الأفعال المعروضة في الفلتر — ⛔ **ولا فعلٌ بلا كاتبٍ له اليوم**.
///
/// ⚠️⚠️ **ولماذا قائمةٌ منتقاة لا [AuditAction.values]:** ★ **الأفعال التي
/// لا كاتبَ لها بعد** (الإتلاف · التصريف المتأخر · تأكيد الإيداع · التصدير)
/// **تُنتج فلتراً يعرض فراغاً دائماً** — ⟵ **ويقرؤه المستخدم عطلاً في
/// الشاشة** لا غياباً للبيانات. ★ **وتُضاف كلٌّ منها في زيادتها**، بنفس
/// قاعدة `SourceDocumentType` في `inventory.dart` («⛔ لا تُملأ استباقاً
/// بقيمٍ لا كاتب لها»).
const List<AuditAction> _filterableActions = <AuditAction>[
  AuditAction.create,
  AuditAction.amend,
  AuditAction.cancel,
  AuditAction.disable,
  AuditAction.permissionChange,
  AuditAction.delete,
];

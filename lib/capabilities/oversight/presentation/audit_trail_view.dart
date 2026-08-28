/// ★★★ **الصيغة الموحّدة لعرض قيد التدقيق** — `audit-log-design.md` §5:
/// «**موحّدة في كل الوحدات** — أيقونة الإجراء · المستخدم · الوقت · الحقل ·
/// قبل/بعد · السبب».
///
/// ⛔⛔★★ **ومكوّنٌ واحد لخمس عشرة شاشة:** `FR-M18-11` يعدّ **أربع عشرة شاشة**
/// تحمل السجل السياقي، **والشاشة المركزية خامسةَ عشرةَ** — ⟵ **ونسخةٌ في
/// كلٍّ منها تفترق عند أول تعديل** (`design-system.md` §8 المحظور الحادي عشر
/// · `coding-standards.md` §2.2).
///
/// ⚠️⚠️ **وكل ما هنا عرضٌ لا حماية** — ★ **والقراءة محكومةٌ في
/// `firestore.rules` بـ`auditLogViewCentral || auditLogViewContextual`
/// والنطاق**، ⛔ **وبوابةُ الأيقونة إخفاءٌ لا منع** (`RISK-02`).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qtms_domain/qtms_domain.dart';

import '../../../core/design/design_tokens.dart';
import '../../../core/design/theme_extensions.dart';
import '../../../core/messages/audit_labels.dart';
import '../../../core/ui/async_state_view.dart';
import '../../../core/ui/date_labels.dart';
import '../../../core/ui/entity_tile.dart';
import '../../../core/ui/status_pill.dart';
import '../application/audit_log_providers.dart';

/// ★ أيقونة الإجراء — §5: «**أيقونة الإجراء** · المستخدم · الوقت…».
///
/// ⛔ **ولا لونَ وحده ينقل المعنى** (§8 المحظور الثاني عشر) — ★ **فالنصّ
/// من [auditActionLabelOrUnknown] يرافقها دائماً** ⛔ **ولا تقوم مقامه.**
IconData auditActionIcon(AuditAction? action) => switch (action) {
      AuditAction.create => Icons.add_circle_outline,
      AuditAction.amend => Icons.history_edu_outlined,
      AuditAction.cancel => Icons.cancel_outlined,
      AuditAction.disable => Icons.do_not_disturb_on_outlined,
      AuditAction.signIn => Icons.login_outlined,
      AuditAction.export => Icons.ios_share_outlined,
      AuditAction.depositConfirm => Icons.account_balance_outlined,
      AuditAction.lostWeightConfirm => Icons.scale_outlined,
      AuditAction.disposal => Icons.delete_forever_outlined,
      AuditAction.agedRemainderClear => Icons.schedule_outlined,
      AuditAction.permissionChange => Icons.admin_panel_settings_outlined,
      AuditAction.delete => Icons.folder_delete_outlined,
      // ⛔ **والمجهول لا يُخفى** — ★ **يُعرَض برمز سؤال** ⟵ **فيبقى القيد
      //    مقروءاً بوقته ومُنفِّذه وقيمه** (`schema/audit-log.md`: للإضافة فقط).
      null => Icons.help_outline,
    };

/// ★ الثلاثية اللونية للإجراء — **دلاليةٌ للحكم** (`design-system.md` §3.5).
///
/// ⚠️ **والحيادُ هو الأصل:** ⛔ **«لا لون بلا وظيفة»** (§2 المبدأ الأول) —
/// ★ **فالخطرُ للإلغاء والحذف والإتلاف وحدها**، **والتحذيرُ للتعديل**
/// (وهو ما يُطالِبه `ADR-0004` بسببٍ نصّي)، ⛔ **وما عداهما محايد.**
ColorTriad auditActionTriad(AuditAction? action) => switch (action) {
      AuditAction.cancel ||
      AuditAction.delete ||
      AuditAction.disposal =>
        SemanticTriads.danger,
      AuditAction.amend || AuditAction.disable => SemanticTriads.warning,
      AuditAction.create => SemanticTriads.success,
      _ => SemanticTriads.neutral,
    };

/// ★★ زرّ السجل السياقي — **أيقونة 🕘 في أول كل صف** (`FR-M18-10`).
///
/// ⛔ **ولا يُبنى مباشرةً في شاشة** — ★ **يُطلَب عبر [auditTrailLeading]**
/// ⟵ **فيبقى الإخفاء عند غياب الصلاحية بلا فراغٍ يزيح المحتوى.**
class AuditTrailButton extends StatelessWidget {
  /// ينشئ الزرّ.
  const AuditTrailButton({
    required this.entity,
    required this.title,
    super.key,
  });

  /// الكيان المفتوح سجلُّه.
  final AuditEntityRef entity;

  /// عنوانٌ مقروء للسجل — ★ **اسم المستند أو الكيان لا معرّفه الخام** (§6).
  final String title;

  @override
  Widget build(BuildContext context) => IconButton(
        // ★ **هدف لمسٍ كامل** — `design-system.md` §5 البند 3.
        constraints: const BoxConstraints(
          minWidth: Sizes.minTouch,
          minHeight: Sizes.minTouch,
        ),
        onPressed: () => showAuditTrailSheet(context, entity: entity, title: title),
        icon: const Icon(Icons.history, size: Sizes.iconMd),
        tooltip: 'سجل التغييرات',
      );
}

/// ★★ مقدّمة الصفّ إن كان للمستخدم أن يرى السجل — ⛔ **و`null` وإلا**.
///
/// ⚠️⚠️ **ولماذا `null` لا عنصرٌ فارغ:** [EntityTile] تُضيف فاصلاً بعد
/// المقدّمة متى وُجدت — ⟵ **فعنصرٌ بعرضٍ صفري كان يترك فجوةً تزيح النصّ
/// عند من لا يملك الصلاحية وحده**، ⛔ **فيصير الإخفاء ظاهراً بأثره.**
Widget? auditTrailLeading(
  WidgetRef ref, {
  required String entityType,
  required String entityId,
  required String title,
  String sourceId = auditAllSourcesId,
}) {
  if (!ref.watch(canViewAuditTrailProvider)) return null;
  // ⛔ **ومعرّفٌ فارغ لا يُفتَح له سجل** — ★ **والنوع يرفضه أصلاً**، ⟵
  //   **فالفحص هنا يمنع الرمي من صفٍّ ببيانات ناقصة.**
  if (entityType.trim().isEmpty || entityId.trim().isEmpty) return null;
  if (sourceId.trim().isEmpty) return null;
  return AuditTrailButton(
    entity: AuditEntityRef(
      entityType: entityType,
      entityId: entityId,
      // ⛔⛔★★ **والمصدر كما كتبه القيد لا كما تظنّه الشاشة** — راجع
      //    [AuditEntityRef]: ⟵ **قيمةٌ خاطئة تُنتج سجلاً فارغاً أبداً**
      //    ⛔ **لا خطأً ظاهراً.**
      sourceId: sourceId,
    ),
    title: title,
  );
}

/// ★★ يفتح السجل السياقي — **أحداث هذا السجل وحده** (`FR-M18-10`).
///
/// ⛔ **وعرضٌ محض:** `FR-M18-13` — **لا يكتب شيئاً ولا يُنشئ مجموعة.**
Future<void> showAuditTrailSheet(
  BuildContext context, {
  required AuditEntityRef entity,
  required String title,
}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: SemanticColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
      ),
      builder: (BuildContext sheetContext) =>
          _AuditTrailSheet(entity: entity, title: title),
    );

class _AuditTrailSheet extends ConsumerWidget {
  const _AuditTrailSheet({required this.entity, required this.title});

  final AuditEntityRef entity;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<AuditLogEntryCard>> entries =
        ref.watch(entityAuditLogProvider(entity));

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.space16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text('سجل التغييرات — $title', style: TypeScale.titleMd),
            const SizedBox(height: Spacing.space12),
            ConstrainedBox(
              // ★ **ارتفاعٌ محدود** — ⟵ **فالورقة لا تبتلع الشاشة** ولا
              //   تتمدّد بلا حدّ مع سجلٍّ طويل (`ui-guidelines.md` §5).
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height / 2,
              ),
              child: AuditTrailList(
                entries: entries,
                emptyMessage: 'لم يُسجَّل على هذا السجل أي تغيير بعد.',
                onRetry: () => ref.invalidate(entityAuditLogProvider(entity)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ★★★ قائمة القيود بالصيغة الموحّدة — ★ **يشاركها المركزي والسياقي**.
class AuditTrailList extends StatelessWidget {
  /// ينشئ القائمة.
  const AuditTrailList({
    required this.entries,
    required this.emptyMessage,
    this.onRetry,
    this.shrinkWrap = true,
    super.key,
  });

  /// التدفّق المعروض.
  final AsyncValue<List<AuditLogEntryCard>> entries;

  /// ★ نصّ الحالة الفارغة — **سببُ الفراغ لا وصفُه** (§هـ).
  final String emptyMessage;

  /// إعادة المحاولة عند الخطأ — §هـ تفرضها.
  final VoidCallback? onRetry;

  /// هل تنكمش القائمة على محتواها؟ — ★ **للورقة نعم، وللشاشة لا.**
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) => AsyncStateView<AuditLogEntryCard>(
        value: entries,
        onRetry: onRetry,
        empty: EmptyStateSpec(
          icon: Icons.history,
          title: 'لا نشاط مُسجَّل',
          message: emptyMessage,
          // ★ **عائلة الهوية والرقابة** — §4.
          triad: context.categories.identity,
        ),
        // ★ **الخطأ يُعرَض ولا يُطوى في «فارغ»** — ⟵ **فيُميِّز المستخدم بين
        //   «لا نشاط» و«ممنوعٌ من الرؤية»** (`FR-M18-12`).
        errorMessage: (Object _) =>
            'تحقق من صلاحيتك ونطاق مصادرك، ثم أعد المحاولة.',
        builder: (List<AuditLogEntryCard> items) => ListView.separated(
          shrinkWrap: shrinkWrap,
          physics: shrinkWrap ? const ClampingScrollPhysics() : null,
          itemCount: items.length,
          separatorBuilder: (BuildContext context, int index) =>
              const SizedBox(height: Spacing.space8),
          itemBuilder: (BuildContext _, int index) =>
              AuditEntryCardView(entry: items[index]),
        ),
      );
}

/// ★★★ **بطاقة القيد الواحد** — الصيغة الموحّدة حرفياً (§5).
class AuditEntryCardView extends StatelessWidget {
  /// ينشئ البطاقة.
  const AuditEntryCardView({required this.entry, super.key});

  /// القيد المعروض.
  final AuditLogEntryCard entry;

  @override
  Widget build(BuildContext context) {
    final List<AuditFieldChange> changes = describeAuditChanges(entry);

    return Container(
      padding: const EdgeInsets.all(Spacing.cardPadding),
      decoration: BoxDecoration(
        color: SemanticColors.surface,
        border: Border.all(color: SemanticColors.border),
        borderRadius: BorderRadius.circular(Radii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              // ① ★ **أيقونة الإجراء ونصُّه معاً** — ⛔ ولا لونَ وحده.
              StatusPill(
                label: auditActionLabelOrUnknown(entry.action),
                triad: auditActionTriad(entry.action),
                icon: auditActionIcon(entry.action),
              ),
              const Spacer(),
              // ③ ★ **الوقت بأرقامٍ جدولية** — §6.د.
              Text(
                timestampLabel(entry.occurredAt),
                style: TypeScale.numericSm
                    .copyWith(color: SemanticColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: Spacing.space8),
          // ② ★ **المستخدم مُثبَّتاً وقت الحدث** — §2 الشرط 4.
          Text(entry.userName, style: TypeScale.titleSm),
          const SizedBox(height: Spacing.space4),
          Text(
            _targetLine(entry),
            style: TypeScale.bodyMd
                .copyWith(color: SemanticColors.textSecondary),
          ),
          // ④ ★ **الحقل وقبل/بعد** — ⛔ **ولا يُخفى حقلٌ تغيّر فعلاً.**
          if (changes.isNotEmpty) ...<Widget>[
            const Padding(
              padding: EdgeInsetsDirectional.only(
                top: Spacing.space12,
                bottom: Spacing.space8,
              ),
              child: Divider(height: Sizes.borderWidth),
            ),
            for (final AuditFieldChange change in changes)
              _ChangeRow(change: change),
          ],
          // ⑤ ★★ **السبب** — `FR-M18-07`: **نصّي إلزامي للتعديل والإلغاء
          //    والإتلاف** ⟵ **وغيابُه على فعلٍ يفرضه علامةُ خللٍ يراها
          //    المدقّق** ⛔ **لا سطرٌ يُحذف بهدوء.**
          if (entry.reason case final String reason) ...<Widget>[
            const SizedBox(height: Spacing.space8),
            Text(
              'السبب: $reason',
              style: TypeScale.bodyMd.copyWith(color: SemanticColors.textPrimary),
            ),
          ],
        ],
      ),
    );
  }

  /// ★ سطر الهدف — **الكيان ورقم مستنده وتاريخ مخزونه إن وُجدا**.
  ///
  /// ⚠️ **وتاريخ المخزون يُذكَر متى وُجد** — `FR-M18-08` (`AT-52`): ⟵ **وهو
  /// ما يُميِّز التصريف المتأخر** عن حركةٍ وقعت اليوم.
  static String _targetLine(AuditLogEntryCard entry) {
    final StringBuffer buffer = StringBuffer(
      entry.documentNumber ?? entry.entityId,
    );
    if (entry.stockDate case final CalendarDay stockDate) {
      buffer.write(' · مخزون ${dayLabel(stockDate)}');
    }
    return buffer.toString();
  }
}

/// صفّ تغيّرٍ واحد — **الحقل · قبل · بعد**.
class _ChangeRow extends StatelessWidget {
  const _ChangeRow({required this.change});

  final AuditFieldChange change;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.only(bottom: Spacing.space4),
        child: Wrap(
          spacing: Spacing.space8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            Text(
              '${auditFieldLabel(change.field)}:',
              style: TypeScale.label
                  .copyWith(color: SemanticColors.textSecondary),
            ),
            Text(
              _valueLabel(change.before),
              style: TypeScale.numericSm.copyWith(
                color: SemanticColors.textTertiary,
                // ★ **«قبل» مشطوبةٌ لا محذوفة** — ⟵ **فالمدقّق يرى ما كان.**
                //
                // ⛔★★ **والشطبُ على قيمةٍ كانت وحدها** — ⟵ **وشطبُ «لا
                //    قيمة» يشطب نفيَ القيمة لا القيمة**، ★ **فيُقرأ عكسَ
                //    معناه** (رُصد على المحاكي 2026-08-27).
                decoration: change.before == null
                    ? TextDecoration.none
                    : TextDecoration.lineThrough,
              ),
            ),
            const Icon(
              // ⛔⛔★★★ **`arrow_forward` لا `arrow_back` — وعطلٌ رُصد حيّاً
              //    على المحاكي (2026-08-27):** ★ **كلا الرمزين
              //    `matchTextDirection: true` في Material**، ⟵ **فينقلبان مع
              //    RTL:** ⛔ **و`arrow_back` كان يُرسَم متجهاً يميناً** —
              //    ★ **أي من «بعد» إلى «قبل»**، ⟵ **فيقرأ المدقّق التغيير
              //    مقلوباً على مستندٍ مالي.** ★ **و«الأمام» في اتجاه القراءة
              //    هو ما نريده حرفياً:** من «قبل» إلى «بعد».
              //    ⛔ **ولا يُكتب رمزٌ ثابتُ الاتجاه** (`rtl-ltr-guidelines.md`).
              Icons.arrow_forward,
              size: Sizes.iconSm,
              color: SemanticColors.textTertiary,
            ),
            Text(
              _valueLabel(change.after),
              style: TypeScale.numericSm
                  .copyWith(color: SemanticColors.textPrimary),
            ),
          ],
        ),
      );

  /// ★ قيمةٌ مقروءة — ⛔ **والغياب نصٌّ صريح لا فراغ**.
  ///
  /// ⚠️⚠️ **ولماذا نصٌّ لا خانة فارغة:** ⟵ **فراغٌ في عمود «قبل» يُقرأ
  /// «لم أستطع القراءة» بينما معناه «لم يكن للحقل قيمة»** — ★ **والفرق
  /// جوهريٌّ في سجلٍّ يُحتَجّ به.**
  static String _valueLabel(Object? value) => switch (value) {
        null => 'لا قيمة',
        true => 'نعم',
        false => 'لا',
        final DateTime instant => timestampLabel(instant),
        final List<Object?> list => 'قائمة (${list.length})',
        final Map<Object?, Object?> map => 'حقول (${map.length})',
        // ⛔★★ **ورمزُ التعداد يُترجَم** — ★ **عطلٌ رُصد على المحاكي:**
        //    القيد يُخزِّن `weightBased` و`piece` بأسمائها، ⟵ **فكانت
        //    تُعرَض حرفياً** ⛔ **وهو مصطلحٌ تقني في الواجهة** (§6).
        final String text => auditValueLabel(text),
        _ => '$value',
      };
}

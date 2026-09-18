/// ★★★ **الصيغة الموحّدة لعرض قيد التدقيق** — `audit-log-design.md` §5:
/// «**موحّدة في كل الوحدات** — أيقونة الإجراء · المستخدم · الوقت · الحقل ·
/// قبل/بعد · السبب».
///
/// ⛔⛔★★ **ومكوّنٌ واحد لخمس عشرة شاشة:** `FR-M18-11` يعدّ **أربع عشرة شاشة**
/// تحمل السجل السياقي، **والشاشة المركزية خامسةَ عشرةَ** — ⟵ **ونسخةٌ في
/// كلٍّ منها تفترق عند أول تعديل** (`design-system.md` §8 المحظور الحادي عشر
/// · `coding-standards.md` §2.2).
///
/// ═══════════════════════════════════════════════════════════════════════
/// ★★★ **و`AM-012` §3 غيّر ثلاثة أشياء هنا** (2026-09-02) — ⛔ **في هذا
/// المكوّن وحدَه فتسري على الخمسَ عشرةَ شاشةً معاً** (§5: «**موحّدة في كل
/// الوحدات**»):
///
/// ① ⛔⛔ **الإنشاءُ بلا صفوف «قبل/بعد»** — ★ **والحارسُ في طبقة النطاق**
///    (`describeAuditChanges`) ⛔ **لا شرطٌ في الشاشة**: ⟵ **فالقاعدةُ
///    واحدةٌ للمركزي والسياقي بلا احتمال افتراق.**
/// ② ★★ **وبريدُ المُنفِّذ تحت اسمه بخطٍّ أصغر** — ⟵ **والاسمُ الظاهر ليس
///    فريداً** (`FR-M1-01`).
/// ③ ★★ **وسطرُ الهدف «اسم النوع: الرقم»** — ⛔ **لا رقمٌ مجرَّد.**
///
/// ⛔⛔★★ **وبقيةُ الصيغة كما هي حرفياً** (§5) — ★ **أيقونةُ الإجراء ونصُّه
/// والوقتُ والسببُ**: ⟵ **ولم يسقط عنصرٌ واحدٌ من العقد.**
/// ═══════════════════════════════════════════════════════════════════════
///
/// ═══════════════════════════════════════════════════════════════════════
/// ★★★ **و`AM-025` §2 غيّر ثلاثةً أخرى هنا** (2026-09-17) — ⛔ **في هذا
/// المكوّن وحدَه كذلك** (`audit-log-design.md` §5-ب):
///
/// ① ⛔⛔ **سطرُ البريد يُسقَط متى طابق اسمَ الفاعل حرفياً** — ⟵ **حسابٌ لا
///    اسمَ عرضٍ له منفصلاً عن بريده كان يُنتج السلسلةَ نفسَها مرتين في كلِّ
///    بطاقة**: ★ **والتمييزُ الذي بُني له السطرُ غائبٌ أصلاً حينئذ.**
/// ② ★★★ **ومرجعُ الهدف يُقرأ مقروءاً** — ⛔ **لا معرّفاً مركّباً خاماً**:
///    ★ **والترتيب في [_targetReference]** (§5-ب-1).
/// ③ ⛔⛔★★★ **والخريطةُ تُفرَد صفّاً لكلِّ مفتاحٍ فرعيّ** — ⛔ **لا
///    «حقول (N)»**: ★ **راجع [_expandChanges]** (§5-ب-2).
/// ═══════════════════════════════════════════════════════════════════════
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
import '../../../core/messages/error_messages.dart';
import '../../../core/ui/async_state_view.dart';
import '../../../core/ui/date_labels.dart';
import '../../../core/ui/entity_tile.dart';
import '../../../core/ui/status_pill.dart';
import '../../master_data/application/master_data_providers.dart';
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
            readRejectionMessage,
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

/// ★★★ **بطاقة القيد الواحد** — الصيغة الموحّدة حرفياً (§5 · §5-أ · §5-ب).
///
/// ⛔⛔★★★ **وصارت [ConsumerWidget] منذ `AM-025` §2** — ★ **لأن سطرَ الهدف
/// يقرأ مرجعاً مقروءاً من البيانات المرجعية** (§5-ب-1): ⟵ **والمزوّداتُ
/// تُقرأ بحسب نوع الكيان وحدَه** ⛔ **لا كلُّها في كل بطاقة**، ★ **فقيدُ
/// مستخدمٍ لا يفتح تدفّقَ المقاوته ولا الأنواع.**
class AuditEntryCardView extends ConsumerWidget {
  /// ينشئ البطاقة.
  const AuditEntryCardView({required this.entry, super.key});

  /// القيد المعروض.
  final AuditLogEntryCard entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<AuditFieldChange> changes = describeAuditChanges(entry);
    final List<_ResolvedChange> rows = _expandChanges(
      changes,
      _outerFieldLabel(ref, entry),
    );

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
          // ②-ب ★★★ **وبريدُه تحته بخطٍّ أصغر** — `AM-012` §3.1 و§3.2.
          //
          // ⛔⛔★★★ **ولماذا سطرٌ ثانٍ لا سطرٌ واحدٌ مركَّب:** ★ **الاسمُ
          //    الظاهر ليس فريداً في النظام** (`FR-M1-01` **يفرض التفرّد على
          //    البريد لا على الاسم**) ⟹ ⛔ **فمستخدمان باسم «محمد» يُنتجان
          //    قيدين لا يميّزهما المدقّق**، ★ **والبريدُ هو المميِّز.**
          //
          // ⛔⛔★★ **وغيابُه يُسقِط السطر بلا أثر** — ★ **ولا يُكتب «لا قيمة»**:
          //    ⟵ **كلُّ قيدٍ كُتب قبل 2026-09-02 يحمل الحقلَ غائباً**،
          //    ⛔ **و«لا قيمة» في موضع هوية تُقرأ «مستخدمٌ بلا بريد»**.
          //
          // ⛔⛔★★★ **وتطابقُه مع الاسم يُسقِطه كذلك** — `AM-025` §2 ①:
          //    ⚠️ **عطلٌ مقيسٌ بلقطتين:** ★ **حسابٌ لا اسمَ عرضٍ له منفصلاً
          //    عن بريده يُنتج «orimind@qtms.test» مرتين متتاليتين في كلِّ
          //    بطاقة** — ⟵ **سطرٌ بلا معلومةٍ واحدة يتكرّر في خمسَ عشرةَ
          //    شاشة**، ⛔ **والتمييزُ الذي بُني له السطرُ غائبٌ أصلاً حين
          //    تكون السلسلتان واحدة.** ★ **والتشذيبُ قبل المقارنة** ⟵ **فلا
          //    يُبقيه فراغٌ طرفيٌّ لا يراه أحد.**
          if (entry.userEmail case final String email)
            if (email.trim() != entry.userName.trim()) ...<Widget>[
              const SizedBox(height: Spacing.space2),
              Text(
                email,
                // ★ **أصغرُ درجةٍ في السلّم** — ⛔ **ولا حجمَ محفور** (`AM-007`).
                style: TypeScale.caption
                    .copyWith(color: SemanticColors.textTertiary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          const SizedBox(height: Spacing.space4),
          Text(
            _targetLine(ref, entry),
            style: TypeScale.bodyMd
                .copyWith(color: SemanticColors.textSecondary),
          ),
          // ④ ★ **الحقل وقبل/بعد** — ⛔ **ولا يُخفى حقلٌ تغيّر فعلاً.**
          if (rows.isNotEmpty) ...<Widget>[
            const Padding(
              padding: EdgeInsetsDirectional.only(
                top: Spacing.space12,
                bottom: Spacing.space8,
              ),
              child: Divider(height: Sizes.borderWidth),
            ),
            for (final _ResolvedChange row in rows) _ChangeRow(change: row),
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

  /// ★ سطر الهدف — **«اسم النوع: المرجع» وتاريخُ مخزونه إن وُجد**.
  ///
  /// ═══════════════════════════════════════════════════════════════════════
  /// ★★★ **والنوعُ يسبق المرجع منذ `AM-012` §3.3** (2026-09-02) — ⛔ **وكان
  /// رقماً مجرَّداً:**
  ///
  /// ```text
  /// قبل  ⟶  CNT-20260902-0007 · مخزون 2026/09/02
  /// بعد  ⟶  الوارد عدداً: CNT-20260902-0007 · مخزون 2026/09/02
  /// ```
  ///
  /// ⛔⛔★★★ **والحاجةُ مقيسةٌ في الشاشة المركزية:** ★ **تعرض قيودَ سبعةَ
  /// عشرَ نوعَ كيانٍ مختلطةً في قائمةٍ واحدة** (`FR-M18-09`) ⟵ **ومعرّفاتُها
  /// غيرُ متجانسة أصلاً**: **رقمُ مستندٍ ببادئة** (`RCP-` · `DSC-`) ·
  /// **ومعرّفٌ مركّب** (`{dealerId}_{sourceId}_{stockDate}` للتوزيعة) ·
  /// **ومعرّفُ حسابٍ خام** للمستخدم.
  ///
  /// ★★★ **والمرجعُ صار مقروءاً منذ `AM-025` §2 ②** (2026-09-17) —
  /// ⚠️ **وعطلٌ مقيسٌ بلقطةٍ فعلية:** ⛔ **«التوزيع: `MQT-0002_SRC-001_20260905`»**
  /// ⟵ **معرّفٌ تقنيٌّ مركّبٌ في موضعٍ يقرؤه المدقّق**، ★ **بينما شاشةُ التوزيع
  /// تعرض لنفس السجل «`DST-20260905-0002`»** — ⛔ **وهو «مصطلحٌ تقني في واجهة
  /// المستخدم» حرفياً** (`ui-guidelines.md` §6). ★ **والترتيبُ في [_targetReference].**
  ///
  /// ⛔ **والرقمُ الذي يكتبه القيدُ لا يُمَسّ** — ★ **يُعرَض كما هو حرفياً**
  /// (`AM-012` §3.3).
  /// ═══════════════════════════════════════════════════════════════════════
  ///
  /// ⚠️ **وتاريخ المخزون يُذكَر متى وُجد** — `FR-M18-08` (`AT-52`): ⟵ **وهو
  /// ما يُميِّز التصريف المتأخر** عن حركةٍ وقعت اليوم.
  static String _targetLine(WidgetRef ref, AuditLogEntryCard entry) {
    final StringBuffer buffer = StringBuffer(
      '${auditEntityTypeLabel(entry.entityType)}: '
      '${_targetReference(ref, entry)}',
    );
    if (entry.stockDate case final CalendarDay stockDate) {
      buffer.write(' · مخزون ${dayLabel(stockDate)}');
    }
    return buffer.toString();
  }
}

/// ★★★ **مرجعُ الهدف مقروءاً** — `audit-log-design.md` §5-ب-1 (`AM-025` §2 ②).
///
/// ═══════════════════════════════════════════════════════════════════════
/// ★★ **والترتيبُ مُلزِمٌ ولا يُعكَس:**
/// ① **رقمُ المستند إن كتبه القيدُ نفسُه** — ⛔ **ولا يُخترَع رقم.**
/// ② **وإلا فمرجعٌ مقروءٌ يُبنى من المعرّف ومن البيانات المرجعية المحمَّلة.**
/// ③ **وإلا فالمعرّفُ نفسُه** — ★ **معرّفٌ صادقٌ خيرٌ من فراغٍ ومن اسمٍ مُلفَّق.**
///
/// ⛔⛔★★ **ولا استعلامَ إضافيٌّ لكلِّ بطاقة** — ★ **كلُّ مزوّدٍ هنا يقرأ
/// قائمةً مرجعيةً محمَّلةً أصلاً في التطبيق**، ⟵ **ويُقرأ بحسب نوع الكيان
/// وحدَه** ⛔ **فلا تفتح بطاقةُ مستخدمٍ تدفّقَ المقاوته.**
///
/// ⚠️⚠️ **ورفضُ القراءة لا يُسقِط شيئاً** — ★ **المزوّداتُ تقع على المعرّف عند
/// غياب القائمة** (`.value ?? const []`): ⟵ **فمدقّقٌ لا يملك مفتاحَ عرضِ
/// المقاوته يرى المعرّف** ⛔ **لا شاشةَ خطأ.**
/// ═══════════════════════════════════════════════════════════════════════
String _targetReference(WidgetRef ref, AuditLogEntryCard entry) {
  if (entry.documentNumber case final String number) return number;
  final String id = entry.entityId;
  return switch (entry.entityType) {
    itemEntityType => ref.watch(itemDisplayNameProvider(id)),
    sourceEntityType => ref.watch(sourceDisplayNameProvider(id)),
    dealerEntityType => ref.watch(dealerDisplayNameProvider(id)),
    supplierEntityType => ref.watch(supplierDisplayNameProvider(id)),
    dailyPriceEntityType => _dailyPriceReference(ref, id),
    distributionEntityType => _distributionReference(ref, id),
    _ => id,
  };
}

/// ★★ مرجعُ دفعةِ تسعيرِ يوم — **`{sourceId}_{YYYYMMDD}`** (`daily_pricing.dart`).
///
/// ⛔ **والتاريخُ يُفكَّك بـ[CalendarDay.tryParseCompact]** — ★ **نظيرُ كاتبه
/// حرفياً** ⛔ **لا بصيغةٍ ثانية** (`coding-standards.md` §2.2): ⟵ **ومعرّفٌ
/// لا يوافق الصيغة يقع على نفسه** ⛔ **ولا يُفكَّك تخميناً.**
String _dailyPriceReference(WidgetRef ref, String entityId) {
  final int cut = entityId.lastIndexOf('_');
  if (cut <= 0) return entityId;
  final CalendarDay? day =
      CalendarDay.tryParseCompact(entityId.substring(cut + 1));
  if (day == null) return entityId;
  final String source =
      ref.watch(sourceDisplayNameProvider(entityId.substring(0, cut)));
  return '$source · ${dayLabel(day)}';
}

/// ★★ مرجعُ توزيعةٍ — **`{dealerId}_{sourceId}_{YYYYMMDD}`** (`distribution.dart`).
///
/// ⚠️⚠️ **ولا يصل هذا المسارَ قيدٌ كتبه إصدارٌ يحمل `documentNumber`** —
/// ★ **`AM-025` §2 ② جعل الكاتبَ يُمرِّره** ⟹ **فالبند ① في [_targetReference]
/// يلتقطه**: ⟵ **وهذا المسارُ للقيود السابقة وحدَها** (**السجلُّ للإضافة فقط
/// ولا يُهاجَر** — `schema/audit-log.md`) ⛔ **ولا يُملأ حقلٌ بأثرٍ رجعي.**
///
/// ⛔ **والتاريخُ لا يُكرَّر هنا** — ★ **لاحقةُ «· مخزون …» تحمله أصلاً.**
String _distributionReference(WidgetRef ref, String entityId) {
  final List<String> parts = entityId.split('_');
  if (parts.length != 3) return entityId;
  final String dealer = ref.watch(dealerDisplayNameProvider(parts[0]));
  final String source = ref.watch(sourceDisplayNameProvider(parts[1]));
  return '$dealer · $source';
}

/// ★★★ **اسمُ الحقل الخارجي في صفوف «قبل/بعد»** — `audit-log-design.md` §5-ب-2.
///
/// ⛔⛔★★ **وقيودُ التسعير اليومي وحدَها تُفتِّح مفاتيحَها أسماءَ أنواع** —
/// ★ **`daily_pricing.dart` يكتب `valuesBefore[itemKey]` خريطةَ سعرين**:
/// ⟵ **فمفتاحُها `ITM-0001` مفتاحُ سجلِ نوعٍ لا اسمُ حقل**، ⛔ **و[auditFieldLabel]
/// كانت تُرجِعه خاماً** لأنها لا تعرفه — ★ **وهو عينُ ما رصدته المراجعة.**
String Function(String) _outerFieldLabel(
  WidgetRef ref,
  AuditLogEntryCard entry,
) {
  if (entry.entityType != dailyPriceEntityType) return auditFieldLabel;
  return (String field) => ref.watch(itemDisplayNameProvider(field));
}

/// ★★★ **صفُّ تغيّرٍ مُفكَّك** — `audit-log-design.md` §5-ب-2 (`AM-025` §2 ③).
///
/// ⚠️ **وهو غير [AuditFieldChange] عمداً:** ★ **ذاك حقلٌ كما كتبه القيد**،
/// ⟵ **وهذا صفٌّ كما يُعرَض** — ★ **وقد يكون مفتاحاً فرعياً داخل خريطة.**
final class _ResolvedChange {
  const _ResolvedChange({
    required this.label,
    required this.before,
    required this.after,
  });

  /// الاسمُ المعروض — **مركَّبٌ بـ` · ` عند التفكيك**.
  final String label;

  /// القيمة قبل.
  final Object? before;

  /// القيمة بعد.
  final Object? after;
}

/// ★★ أقصى عمقِ تفكيكٍ — **ثلاثةُ مستويات** (§5-ب-2).
///
/// ⛔⛔ **وحدٌّ لا زينة** — ★ **قيمةُ القيد تصل من القاعدة بلا عقدٍ على عمقها**:
/// ⟵ **وبنيةٌ مُعشَّشةٌ بلا حدّ تُنتج حلقةً تُثقل البطاقة** ⛔ **في شاشةٍ
/// تعرض مئةَ قيد.** ★ **وما بعده يقع على «حقول (N)» كما كان.**
const int _maxChangeDepth = 3;

/// ★★★ **يُفكِّك الخرائط صفّاً لكلِّ مفتاحٍ فرعيّ** — §5-ب-2 (`AM-025` §2 ③).
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **والعطلُ الذي يعالجه مقيسٌ بلقطةٍ فعلية:** ★ **قيدُ تعديل التسعير
/// اليومي كان يعرض «`ITM-0001`: حقول (2) ← حقول (2)»** — ⟵ **أي «حقلان
/// تغيّرا إلى حقلين»**: ⛔⛔ **يقول إن شيئاً تغيّر ولا يقول ماذا**، ★ **وهو
/// يُفرِغ السجلَّ من غرضه الجوهري لهذه الفئة** (`FR-M18-03`: **«بالقيمة قبل
/// وبعد»**).
///
/// ⛔★★ **والمتساوي يُستبعَد بـ[sameAuditValue] نفسِها** — ⛔ **لا بمقارنةٍ
/// ثانية** (`coding-standards.md` §2.2): ⟵ **فمفتاحٌ يُعَدّ تغييراً هنا
/// يُعَدّ تغييراً في `describeAuditChanges` حرفياً.**
///
/// ★ **والقوائم لا تُفكَّك** — ⛔ **«قائمة (N)» باقيةٌ كما هي:** ⟵ **سطورُ
/// المستند تُقارَن بترتيبها فلا يقول صفٌّ برقمٍ فيها شيئاً للمدقّق.**
/// ═══════════════════════════════════════════════════════════════════════
List<_ResolvedChange> _expandChanges(
  List<AuditFieldChange> changes,
  String Function(String field) outerLabel,
) {
  final List<_ResolvedChange> rows = <_ResolvedChange>[];
  for (final AuditFieldChange change in changes) {
    _flattenChange(
      label: outerLabel(change.field),
      before: change.before,
      after: change.after,
      into: rows,
      depth: 0,
    );
  }
  return List<_ResolvedChange>.unmodifiable(rows);
}

/// ★ يُفكِّك قيمةً واحدة — **ويستدعي نفسَه للمستوى الأعمق**.
void _flattenChange({
  required String label,
  required Object? before,
  required Object? after,
  required List<_ResolvedChange> into,
  required int depth,
}) {
  final Map<String, Object?>? beforeMap = _asFieldMap(before);
  final Map<String, Object?>? afterMap = _asFieldMap(after);
  // ★★ **والخريطةُ تُفكَّك متى كان الطرفان خريطتين أو خريطةً مقابل غياب** —
  //    ⛔ **ولا تُفكَّك خريطةٌ صارت نصّاً أو رقماً**: ⟵ **فالتغيير عندها
  //    تغييرُ نوعٍ لا تغييرُ حقلٍ فرعيّ**، ★ **والصفُّ الواحد أصدقُ.**
  final bool expandable = (beforeMap != null || afterMap != null) &&
      (before == null || beforeMap != null) &&
      (after == null || afterMap != null);
  if (!expandable || depth >= _maxChangeDepth) {
    into.add(_ResolvedChange(label: label, before: before, after: after));
    return;
  }
  final List<String> keys = <String>{
    ...?beforeMap?.keys,
    ...?afterMap?.keys,
  }.toList()
    ..sort();
  // ⛔ **وخريطةٌ بلا مفاتيح تُعرَض «حقول (0)»** — ★ **ولا تختفي بصمت.**
  if (keys.isEmpty) {
    into.add(_ResolvedChange(label: label, before: before, after: after));
    return;
  }
  for (final String key in keys) {
    final Object? innerBefore = beforeMap?[key];
    final Object? innerAfter = afterMap?[key];
    if (sameAuditValue(innerBefore, innerAfter)) continue;
    _flattenChange(
      label: '$label · ${auditFieldLabel(key)}',
      before: innerBefore,
      after: innerAfter,
      into: into,
      depth: depth + 1,
    );
  }
}

/// ★ خريطةُ حقولٍ بمفاتيحَ نصّية — و`null` **لِما ليس خريطة**.
///
/// ⚠️ **والمفاتيحُ تُطبَّع نصّاً** — ★ **القاعدة تُرجِع `Map<String, dynamic>`**،
/// ⟵ **لكن العقدَ المحلي `Map<Object?, Object?>`**: ⛔ **فالفهرسةُ بمفتاحٍ
/// نصّيٍّ على خريطةٍ غيرِ نصّية المفاتيح كانت تُرجِع `null` بصمت.**
Map<String, Object?>? _asFieldMap(Object? value) {
  if (value is! Map<Object?, Object?>) return null;
  return <String, Object?>{
    for (final MapEntry<Object?, Object?> entry in value.entries)
      '${entry.key}': entry.value,
  };
}

/// صفّ تغيّرٍ واحد — **الحقل · قبل · بعد**.
class _ChangeRow extends StatelessWidget {
  const _ChangeRow({required this.change});

  final _ResolvedChange change;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.only(bottom: Spacing.space4),
        child: Wrap(
          spacing: Spacing.space8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            Text(
              '${change.label}:',
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
  ///
  /// ⚠️ **و«حقول (N)» لم تعد تصل الخرائطَ التي تُفكَّك** — `AM-025` §2 ③:
  /// ★ **تبقى للمستوى الذي يتجاوز [_maxChangeDepth]** ⛔ **ولخريطةٍ صار
  /// طرفُها الآخر نصّاً أو رقماً** (راجع [_flattenChange]).
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

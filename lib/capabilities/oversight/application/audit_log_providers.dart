/// مزوّدات سجل التدقيق (`WU-008`).
///
/// ★ **بنفس نمط `inventory_providers.dart`:** الدليل **يُحقَن في الجذر ولا
/// يُبنى هنا** (`ADR-0010`) — ⟵ **فتُختبَر الشاشات بلا سحابة ولا شبكة**.
///
/// ⚠️⚠️ **وكل ما هنا عرضٌ لا تفويض:** إخفاء مدخلٍ بـ`auditLogViewCentral`
/// **إخفاء لا حماية** — ★ **والحماية شرطُ القراءة في `firestore.rules`**
/// (`match /audit_log/{logId}`) **مُختبَراً على المحاكي** (`RISK-02`).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qtms_domain/qtms_domain.dart';

import '../../identity_access/application/session_providers.dart';
import '../../inventory/application/inventory_providers.dart';
import '../../master_data/application/master_data_providers.dart';

/// دليل سجل التدقيق — ⛔ **يُحقَن في الجذر**.
final Provider<AuditLogDirectory> auditLogDirectoryProvider =
    Provider<AuditLogDirectory>((Ref ref) {
  throw UnimplementedError('auditLogDirectoryProvider يجب تجاوزه عند الجذر');
});

/// ★★ المصادر القابلة للفلترة في الشاشة المركزية.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★ **ويُضاف [auditAllSourcesId] لصاحب النطاق الشامل وحده — ولماذا:**
///
/// قيودُ **تغيير الصلاحيات والدخول والمستخدمين والأدوار والرعية والمقاوته
/// والأنواع** تُكتب بـ`sourceId = 'all'` (`audit_entry.dart` ·
/// `master_data.dart` · `user_admin.dart`) — ★ **و`inScope('all')` لا تصدُق
/// إلا لمن نطاقه `all`.** ⟵ **فبطاقةٌ لهذا الخيار عند صاحب نطاقٍ محدود
/// كانت ستُنتج استعلاماً مرفوضاً دائماً** ⛔ **يقرؤه المستخدم عطلاً.**
///
/// ★ **وهذا أثرٌ موثَّق سلفاً لا قرارٌ جديد:** `audit_entry.dart` ينصّ أن
/// «قيود تغيير الصلاحيات **تضيق على أصحاب النطاق الكامل** ولا تتّسع».
/// ═══════════════════════════════════════════════════════════════════════
final Provider<List<AuditSourceOption>> auditSourceOptionsProvider =
    Provider<List<AuditSourceOption>>((Ref ref) {
  final bool allScope =
      ref.watch(currentSessionProvider)?.sourceScope is AllSources;
  return <AuditSourceOption>[
    for (final SourceCard source in ref.watch(activeSourcesProvider))
      AuditSourceOption(sourceId: source.sourceId, label: source.name),
    if (allScope)
      const AuditSourceOption(
        sourceId: auditAllSourcesId,
        // ⛔ **ولا يُعرَض `all` نصّاً تقنياً** — `ui-guidelines.md` §6.
        label: 'ما لا يخصّ مصدراً',
      ),
  ];
});

/// خيار مصدرٍ في فلتر السجل — **معرّفه ونصُّه المعروض**.
final class AuditSourceOption {
  /// ينشئ الخيار.
  const AuditSourceOption({required this.sourceId, required this.label});

  /// المعرّف كما يُقيَّد به الاستعلام.
  final String sourceId;

  /// النصّ المعروض.
  final String label;
}

/// ★ فلتر الشاشة المركزية — **بمصدرٍ إلزامي** (راجع [AuditLogFilter]).
///
/// ⛔ **و`null` تعني «لا مصدر متاح بعد»** — ⟵ **فالشاشة لا تستعلم أصلاً**،
/// ★ **ولا تُظهر خطأً على مستخدمٍ نطاقُه فارغ** (`E-35`).
final NotifierProvider<AuditLogFilterState, AuditLogFilter?>
    auditLogFilterProvider =
    NotifierProvider<AuditLogFilterState, AuditLogFilter?>(
  AuditLogFilterState.new,
);

/// حالة الفلتر — ★ **وتبديل البُعد يمسح قيمة سابقه**.
///
/// ⚠️⚠️ **ولماذا المسح إلزامي:** [AuditLogFilter] **يحمل بُعداً ثانوياً
/// واحداً**، ⟵ **وإبقاءُ `userId` قائماً بعد التحول إلى بُعد الإجراء كان
/// يُظهر للمستخدم فلتراً لا أثر له** ⛔ **فيقرأ نتيجةً على أنها مفلترة
/// وهي ليست كذلك.**
class AuditLogFilterState extends Notifier<AuditLogFilter?> {
  @override
  AuditLogFilter? build() {
    final List<AuditSourceOption> options =
        ref.watch(auditSourceOptionsProvider);
    if (options.isEmpty) return null;
    // ★ **أول مصدرٍ في نطاق المستخدم افتراضاً** — بنفس منطق `SelectedSource`
    //   في `inventory_providers.dart`، ⟵ **فمن له مصدرٌ واحد لا يختار شيئاً.**
    return AuditLogFilter(sourceId: options.first.sourceId);
  }

  /// يبدّل المصدر — ★ **ويُبقي البُعد الثانوي والمدى**.
  void selectSource(String sourceId) => state = AuditLogFilter(
        sourceId: sourceId,
        dimension: state?.dimension ?? AuditFilterDimension.none,
        userId: state?.userId,
        action: state?.action,
        from: state?.from,
        to: state?.to,
      );

  /// يفلتر بمستخدم داخل المصدر الجاري.
  void byUser(String userId) {
    final AuditLogFilter? current = state;
    if (current == null) return;
    state = AuditLogFilter(
      sourceId: current.sourceId,
      dimension: AuditFilterDimension.user,
      userId: userId,
      from: current.from,
      to: current.to,
    );
  }

  /// يفلتر بإجراء داخل المصدر الجاري.
  void byAction(AuditAction action) {
    final AuditLogFilter? current = state;
    if (current == null) return;
    state = AuditLogFilter(
      sourceId: current.sourceId,
      dimension: AuditFilterDimension.action,
      action: action,
      from: current.from,
      to: current.to,
    );
  }

  /// ★ يُلغي البُعد الثانوي ويُبقي المصدر والمدى.
  void clearDimension() {
    final AuditLogFilter? current = state;
    if (current == null) return;
    state = AuditLogFilter(
      sourceId: current.sourceId,
      from: current.from,
      to: current.to,
    );
  }

  /// ★ يضبط المدى الزمني — **بلا مساسٍ بالمصدر ولا بالبُعد القائم**.
  ///
  /// ⛔ **ومدىً مقلوب يُهمَل ولا يُطبَّق** — ★ **والنوع يرفضه أصلاً**،
  /// ⟵ **فالحارس هنا يمنع الرمي من منتقي تاريخٍ بترتيبٍ عكسي.**
  void withRange({CalendarDay? from, CalendarDay? to}) {
    final AuditLogFilter? current = state;
    if (current == null) return;
    if (from != null && to != null && from.compareTo(to) > 0) return;
    state = AuditLogFilter(
      sourceId: current.sourceId,
      dimension: current.dimension,
      userId: current.userId,
      action: current.action,
      from: from,
      to: to,
    );
  }
}

/// ⛅ قيود الشاشة المركزية بالفلتر الجاري.
///
/// ⛔ **وبلا مصدرٍ لا استعلام** — ★ **تدفّقٌ فارغ لا خطأ**: ⟵ **فمستخدمٌ
/// نطاقُه فارغ يرى «لا نشاط» لا «تعذّر العرض»** (`E-35`).
final StreamProvider<List<AuditLogEntryCard>> centralAuditLogProvider =
    StreamProvider<List<AuditLogEntryCard>>((Ref ref) {
  final AuditLogFilter? filter = ref.watch(auditLogFilterProvider);
  if (filter == null) {
    return Stream<List<AuditLogEntryCard>>.value(
      const <AuditLogEntryCard>[],
    );
  }
  return ref.watch(auditLogDirectoryProvider).watchCentralLog(filter: filter);
});

/// ⛅ قيود كيانٍ واحد — ★ **السجل السياقي** (`FR-M18-10`).
final entityAuditLogProvider =
    StreamProvider.family<List<AuditLogEntryCard>, AuditEntityRef>(
  (Ref ref, AuditEntityRef entity) =>
      ref.watch(auditLogDirectoryProvider).watchEntityLog(entity: entity),
);

/// ★★ هل يملك المستخدم رؤية السجل السياقي؟ — `FR-M18-12`.
///
/// ⚠️⚠️ **والشرط «أو» لا «و» — نقلاً عن القاعدة نفسها حرفياً:**
/// `firestore.rules` §`audit_log`: `perm('auditLogViewCentral') ||
/// perm('auditLogViewContextual')`. ⟵ ★ **فمن يملك المركزي يرى السياقي
/// بداهةً**، ⛔ **وبوابةٌ تشترط السياقي وحده كانت ستُخفي عن المدقّق ما
/// تسمح له القاعدة برؤيته** — ★ **وهو إخفاءٌ يبدو عطلاً.**
final Provider<bool> canViewAuditTrailProvider = Provider<bool>(
  (Ref ref) =>
      ref.watch(hasPermissionProvider(Permission.auditLogViewContextual)) ||
      ref.watch(hasPermissionProvider(Permission.auditLogViewCentral)),
);

// ══════════ ★★★ تعديلاتُ اليوم على المستندات المعتمدة — `AM-017` ③ ══════════

/// ★★★ **تعديلاتُ مصدرٍ واحدٍ اليومَ** — `AM-017` ③.
///
/// ⛔⛔★★ **والاستعلامُ مُقيَّدٌ بالمصدر إلزاماً** — ★ **شرطُ قراءة `audit_log`
/// يعتمد `resource.data.sourceId`** (`WU-008`): ⟵ **واستعلامٌ لا يُقيّده
/// يُرفَض كاملاً ولو ملك القارئ كلَّ المفاتيح.**
///
/// ✅★★ **ولا فهرسَ جديداً يلزم** — ★ **الشكلُ `sourceId + action + occurredAt`
/// مسجَّلٌ فعلاً في `firestore.indexes.json`**، ⟵ **وهو الشكلُ نفسُه الذي
/// تستعمله شاشةُ السجل عند الفلترة بفعلٍ ومدى.**
final todayAmendmentsForSourceProvider =
    StreamProvider.family<List<AuditLogEntryCard>, String>((
  Ref ref,
  String sourceId,
) {
  final CalendarDay today = ref.watch(todayProvider);
  return ref.watch(auditLogDirectoryProvider).watchCentralLog(
        filter: AuditLogFilter(
          sourceId: sourceId,
          dimension: AuditFilterDimension.action,
          action: AuditAction.amend,
          from: today,
          to: today,
        ),
      );
});

/// ★★★ **تعديلاتُ اليوم عبر مصادر النطاق كلِّها** — `AM-017` ③.
///
/// ⛔⛔ **ومن لا يملك `auditLogViewCentral` لا يستعلم أصلاً** — ★ **يُرجَع
/// فراغٌ فلا يُرسَم البند ولا يدخل الإجمالي** (`design-system.md` §7).
/// ⚠️ **وإخفاءٌ لا حماية** (`RISK-02`): ★ **والشرطُ في `firestore.rules`.**
///
/// ⚠️ **وأثناء التحميل تبقى `loading`** — ⛔ **ولا صفرٌ مؤقّت**: ★ **عدّادٌ
/// يقول «٠» ثم يصير «٣» يُقرأ عطلاً** (نمطُ `pendingEntriesCountProvider`).
final Provider<AsyncValue<List<AuditLogEntryCard>>> todayAmendmentsProvider =
    Provider<AsyncValue<List<AuditLogEntryCard>>>((Ref ref) {
  if (!ref.watch(hasPermissionProvider(Permission.auditLogViewCentral))) {
    return const AsyncValue<List<AuditLogEntryCard>>.data(
      <AuditLogEntryCard>[],
    );
  }

  final List<SourceCard> sources = ref.watch(activeSourcesProvider);
  if (sources.isEmpty) {
    return const AsyncValue<List<AuditLogEntryCard>>.data(
      <AuditLogEntryCard>[],
    );
  }

  final List<AuditLogEntryCard> all = <AuditLogEntryCard>[];
  for (final SourceCard source in sources) {
    final AsyncValue<List<AuditLogEntryCard>> entries =
        ref.watch(todayAmendmentsForSourceProvider(source.sourceId));
    if (entries.hasError) {
      return AsyncValue<List<AuditLogEntryCard>>.error(
        entries.error ?? Object(),
        entries.stackTrace ?? StackTrace.current,
      );
    }
    final List<AuditLogEntryCard>? value = entries.value;
    if (value == null) {
      return const AsyncValue<List<AuditLogEntryCard>>.loading();
    }
    all.addAll(value);
  }
  return AsyncValue<List<AuditLogEntryCard>>.data(all);
});

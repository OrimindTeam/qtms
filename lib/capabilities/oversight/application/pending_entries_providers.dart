/// مزوّدات مركز الإدخالات المعلّقة (`WU-009`).
///
/// ★ **بنفس نمط `audit_log_providers.dart`:** الدليل **يُحقَن في الجذر ولا
/// يُبنى هنا** (`ADR-0010`) — ⟵ **فتُختبَر الشاشات بلا سحابة ولا شبكة**.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **ولا بوابةَ صلاحيةٍ على المركز — وهذا نصُّ الكتالوج لا اجتهاد:**
/// ★ **لا مفتاح «عرض المركز المعلّق» في `permissions-catalog.md` §2**،
/// ⟵ **والقاعدة تكتفي بـ`isSignedIn() && storedInScope()`**
/// (`firestore.rules`: `match /pending_entries/{entryId}`) ·
/// `authentication-and-authorization.md`: «**معلّقات مصادره فقط**».
/// ⛔ **ولم يُخترَع مفتاح** (`BR-M1-07`) — ★ **وهو نفس ما فُعِل بمخزون اليوم
/// والتسعير في `home_shell.dart`**: **بوابةٌ هنا كانت ستُخفي شاشةً تسمح بها
/// القاعدة.**
/// ═══════════════════════════════════════════════════════════════════════
library;

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qtms_domain/qtms_domain.dart';

import '../../master_data/application/master_data_providers.dart';

/// دليل المركز — ⛔ **يُحقَن في الجذر**.
final Provider<PendingEntryDirectory> pendingEntryDirectoryProvider =
    Provider<PendingEntryDirectory>((Ref ref) {
  throw UnimplementedError('pendingEntryDirectoryProvider يجب تجاوزه عند الجذر');
});

/// ★★ المصادر التي يُفلتَر بها المركز — **مصادرُ نطاق المستخدم وحدها**.
///
/// ⛔ **ولا خيارَ «كل المصادر»** — ★ **بخلاف سجل التدقيق**: ⟵ **بنودُ المركز
/// كلُّها تحمل مصدرَ مستندها** (`PendingEntryDraft` يرفض مصدراً فارغاً)،
/// ⛔ **فلا قيودَ «لا تخصّ مصدراً» هنا أصلاً** — ★ **وخيارٌ لا مستندَ له
/// يُنتج شاشةً فارغةً دائماً يقرؤها المستخدم عطلاً.**
final Provider<List<SourceCard>> pendingSourceOptionsProvider =
    Provider<List<SourceCard>>((Ref ref) => ref.watch(activeSourcesProvider));

/// ★ فلتر الشاشة — ⛔ **بمصدرٍ إلزامي** (راجع [PendingEntryFilter]).
///
/// ⛔ **و`null` تعني «لا مصدر متاح بعد»** — ⟵ **فالشاشة لا تستعلم أصلاً**،
/// ★ **ولا تُظهر خطأً على مستخدمٍ نطاقُه فارغ** (`E-35`).
final NotifierProvider<PendingFilterState, PendingEntryFilter?>
    pendingFilterProvider =
    NotifierProvider<PendingFilterState, PendingEntryFilter?>(
  PendingFilterState.new,
);

/// حالة فلتر المركز — **المصدر ونوع المستند**.
class PendingFilterState extends Notifier<PendingEntryFilter?> {
  @override
  PendingEntryFilter? build() {
    final List<SourceCard> sources = ref.watch(pendingSourceOptionsProvider);
    if (sources.isEmpty) return null;
    // ★ **أول مصدرٍ في نطاق المستخدم افتراضاً** — بنفس منطق `SelectedSource`،
    //   ⟵ **فمن له مصدرٌ واحد لا يختار شيئاً.**
    return PendingEntryFilter(sourceId: sources.first.sourceId);
  }

  /// يبدّل المصدر — ★ **ويُبقي نوع المستند**.
  void selectSource(String sourceId) => state = PendingEntryFilter(
        sourceId: sourceId,
        kind: state?.kind,
      );

  /// يبدّل نوع المستند — و`null` **كل الأنواع**.
  void selectKind(PendingDocumentKind? kind) {
    final PendingEntryFilter? current = state;
    if (current == null) return;
    state = PendingEntryFilter(sourceId: current.sourceId, kind: kind);
  }
}

/// ⛅ بنود المركز بالفلتر الجاري.
///
/// ⛔ **وبلا مصدرٍ لا استعلام** — ★ **تدفّقٌ فارغ لا خطأ**: ⟵ **فمستخدمٌ
/// نطاقُه فارغ يرى «لا قيمة معلّقة» لا «تعذّر العرض»** (`E-35`).
final StreamProvider<List<PendingEntryCard>> pendingEntriesProvider =
    StreamProvider<List<PendingEntryCard>>((Ref ref) {
  final PendingEntryFilter? filter = ref.watch(pendingFilterProvider);
  if (filter == null) {
    return Stream<List<PendingEntryCard>>.value(const <PendingEntryCard>[]);
  }
  return ref.watch(pendingEntryDirectoryProvider).watchPending(filter: filter);
});

/// ⛅ بنود مصدرٍ واحد — ★ **لبناء العدّاد الحيّ عبر كل مصادر النطاق**.
final pendingEntriesForSourceProvider =
    StreamProvider.family<List<PendingEntryCard>, String>(
  (Ref ref, String sourceId) => ref
      .watch(pendingEntryDirectoryProvider)
      .watchPending(filter: PendingEntryFilter(sourceId: sourceId)),
);

/// ★★★ **العدّاد الحيّ الإجمالي** — `FR-SYS-03` الموضع الرابع (لوحة التحكم).
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⚠️⚠️★★★ **ولماذا تدفّقٌ لكل مصدر لا استعلامٌ واحد:** ★ **استعلامٌ بلا قيدٍ
/// على `sourceId` يُرفَض كاملاً من القاعدة — ولو بنطاقٍ شامل** (راجع
/// `FirestorePendingEntryDirectory`)، ⟵ **فالعدّ يجري مصدراً مصدراً ثم
/// يُجمَع**، ★ **وهو ما يوافق `A-01`** (لا جمع بين مصدرين في أي **عملية**)
/// ⛔ **ولا يخالفه:** العدُّ **عرضٌ لا عملية**.
///
/// ⚠️ **والعدد عددُ مصادرِ النطاق** — ★ **وهي وحداتُ الفصل العليا في نظامٍ
/// لمحلٍّ واحد**، ⟵ **فرتبتُها آحاد** ⛔ **لا مئات.**
///
/// ★ **والحالة تبقى `AsyncLoading` حتى يصل كلُّ مصدر** — ⛔ **ولا يُعرَض
/// مجموعٌ ناقص رقماً نهائياً**: ★ **عدّادٌ يقول «٣» ثم يصير «٧» يُقرأ عطلاً.**
/// ═══════════════════════════════════════════════════════════════════════
final Provider<AsyncValue<int>> pendingEntriesCountProvider =
    Provider<AsyncValue<int>>((Ref ref) {
  final List<SourceCard> sources = ref.watch(pendingSourceOptionsProvider);
  if (sources.isEmpty) return const AsyncValue<int>.data(0);

  int total = 0;
  for (final SourceCard source in sources) {
    final AsyncValue<List<PendingEntryCard>> entries =
        ref.watch(pendingEntriesForSourceProvider(source.sourceId));
    if (entries.hasError) {
      return AsyncValue<int>.error(
        entries.error ?? Object(),
        entries.stackTrace ?? StackTrace.current,
      );
    }
    final List<PendingEntryCard>? value = entries.value;
    if (value == null) return const AsyncValue<int>.loading();
    total += value.length;
  }
  return AsyncValue<int>.data(total);
});

// ═════════════════════════════════════════════════════════════════════════
// وجهةُ زر [ إدخال ] — `FR-SYS-04`
// ═════════════════════════════════════════════════════════════════════════

/// ★★ ما يطلبه المركز من الشاشة الأصلية أن تُظهره.
///
/// ⛔⛔ **ولا شاشةَ إدخالٍ بديلة** (`FR-SYS-04` · §6 من مستند الوحدة) —
/// ★ **هذا الكائن يُمرَّر إلى الشاشة الأصلية لتفتح على سياق البند نفسه**،
/// ⟵ **فيبقى مكانُ الإدخال واحداً** ⛔ **ولا مسارَ كتابةٍ ثانٍ.**
@immutable
class PendingFocus {
  /// ينشئ الوجهة.
  const PendingFocus({
    required this.kind,
    required this.sourceId,
    required this.documentId,
    required this.field,
  });

  /// نوع المستند — ★ **وهو ما يحدد الشاشة** ([PendingDocumentKind.screen]).
  final PendingDocumentKind kind;

  /// المصدر — ★ **يُضبَط في الشاشة قبل أي شيء** (`A-01`).
  final String sourceId;

  /// معرّف المستند المقصود.
  final String documentId;

  /// الحقل المقصود.
  final PendingMissingField field;

  /// ★★ معرّف المقوت من معرّف التوزيعة المركّب — `{dealerId}_{sourceId}_{date}`.
  ///
  /// ⚠️ **ويُقرأ بالبادئة لا بالتقسيم على `_`** — ★ **لأن معرّف المصدر نفسه
  /// قد يحوي شرطة سفلية**، ⛔ **وتقسيمٌ ساذج كان يُنتج مقوتاً خاطئاً.**
  /// ★ **و`null` لغير التوزيعة أو لمعرّفٍ لا يطابق الشكل.**
  String? get dealerId {
    if (kind != PendingDocumentKind.distribution) return null;
    final int cut = documentId.indexOf('_$sourceId' '_');
    return cut > 0 ? documentId.substring(0, cut) : null;
  }
}

/// ★ الوجهة المطلوبة الآن — و`null` **لا وجهة**.
///
/// ⚠️ **وتُستهلَك مرةً واحدة** ([PendingFocusState.take]) — ⟵ **فالشاشة لا
/// تُعيد فتح السياق نفسه في كل إعادة بناء**، ⛔ **ولا يعلق المستخدم فيه.**
final NotifierProvider<PendingFocusState, PendingFocus?> pendingFocusProvider =
    NotifierProvider<PendingFocusState, PendingFocus?>(PendingFocusState.new);

/// حالة الوجهة.
class PendingFocusState extends Notifier<PendingFocus?> {
  @override
  PendingFocus? build() => null;

  /// يطلب فتح سياق بندٍ في شاشته الأصلية.
  void request(PendingFocus focus) => state = focus;

  /// ★ يقرأ الوجهة **ويستهلكها** — ⟵ **فلا تُطبَّق مرتين.**
  PendingFocus? take() {
    final PendingFocus? current = state;
    state = null;
    return current;
  }
}

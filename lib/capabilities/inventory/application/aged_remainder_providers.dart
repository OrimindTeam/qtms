/// مزوّدات المتبقي المتأخر (`WU-019` · `M8` الشاشة الثانية).
///
/// ★ **بنفس نمط `pending_entries_providers.dart`:** الدليل **يُحقَن في الجذر
/// ولا يُبنى هنا** (`ADR-0010`) — ⟵ **فتُختبَر الشاشة بلا سحابة ولا شبكة**.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **ولا بوابةَ صلاحيةٍ على العرض — وهذا نصُّ الكتالوج لا اجتهاد:**
/// ★ **لا مفتاح «عرض المتبقي المتأخر» في `permissions-catalog.md` §2**،
/// ⟵ **والقاعدة تكتفي بـ`isSignedIn() && storedInScope()`**
/// (`firestore.rules`: `match /aged_remainders/{remainderId}`).
///
/// ★★ **والمقياسُ من داخل `FR-M8` §5 نفسِه:** ★ **يسمّي ستّاً** — «عرض
/// المخزون» · «عرض حركة النوع» · «عرض متبقي اليوم» · «عرض المتبقي المتأخر» ·
/// «تصريف المتبقي المتأخر» · «الإتلاف» — ⛔ **ولا مفتاحَ في الكتالوج لأولى
/// الثلاث إطلاقاً**، ★ **وقد شُحنت شاشةُ مخزون اليوم بـ`WU-003` على ذلك**
/// (`FR-M8-05`). ⟹ **فالثلاثُ الأولى وصفٌ لا مفاتيح، والرابعةُ منهنّ.**
/// ⛔ **ولم يُخترَع مفتاح** (`BR-M1-07`) — ★ **وإخفاءُ ما تسمح به القاعدة
/// إخفاءٌ بلا حماية يُوهِم بحارسٍ غير قائم** (`RISK-02`).
///
/// ⛔⛔★★ **والتصريفُ شيءٌ آخر** — ★ **`agedRemainderClear` مفتاحٌ قائمٌ في
/// §2.3**، ⟵ **وهو ما يحرس *الكتابة* في السحابة** (`agedClearanceRejection`)
/// ⛔ **لا القراءة.**
/// ═══════════════════════════════════════════════════════════════════════
library;

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qtms_domain/qtms_domain.dart';

import '../../master_data/application/master_data_providers.dart';
import 'inventory_providers.dart';

/// دليل المتبقي المتأخر — ⛔ **يُحقَن في الجذر**.
final Provider<AgedRemainderDirectory> agedRemainderDirectoryProvider =
    Provider<AgedRemainderDirectory>((Ref ref) {
  throw UnimplementedError(
    'agedRemainderDirectoryProvider يجب تجاوزه عند الجذر',
  );
});

/// ⛅ بنودُ مصدرٍ واحد **قبل اليوم** — ★ **والحدُّ في الاستعلام لا في العرض**.
final agedRemaindersForSourceProvider =
    StreamProvider.family<List<AgedRemainderCard>, String>(
  (Ref ref, String sourceId) =>
      ref.watch(agedRemainderDirectoryProvider).watchAgedRemainders(
            sourceId: sourceId,
            today: ref.watch(todayProvider),
          ),
);

/// ★★★ **أيامُ المتبقي مجمَّعةً** — و`null` مصدراً تعني **كل مصادر النطاق**.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⚠️⚠️★★★ **ولماذا تدفّقٌ لكل مصدر ثم دمجٌ في الذاكرة:** ★ **استعلامٌ بلا
/// قيدٍ على `sourceId` يُرفَض كاملاً من القاعدة — ولو بنطاقٍ شامل**
/// (`IQ-024` · `DEBT-40` · `WU-016`)، ⟵ **فالقراءةُ مصدراً مصدراً ثم تُدمَج.**
/// ★ **وهو ما يوافق `A-01`** (⛔ **لا جمعَ بين مصدرين في أي *عملية***)
/// ⛔ **ولا يخالفه:** ★ **العرضُ ليس عملية**، ⟵ **والتصريفُ يقع على بندٍ
/// واحدٍ بمصدره وتاريخه** (`FR-M8-12`).
///
/// ★ **والحالة تبقى `AsyncLoading` حتى يصل كلُّ مصدر** — ⛔ **ولا تُعرَض
/// قائمةٌ ناقصة**: ★ **«يومان» ثم «خمسة» تُقرأ عطلاً** (نظيرُ
/// `pendingEntriesCountProvider` حرفياً).
/// ═══════════════════════════════════════════════════════════════════════
final agedRemainderDaysProvider =
    Provider.family<AsyncValue<List<AgedRemainderDay>>, String?>(
        (Ref ref, String? sourceId) {
  final List<SourceCard> sources = ref.watch(activeSourcesProvider);
  final List<String> ids = switch (sourceId) {
    final String id => <String>[id],
    null => <String>[
        for (final SourceCard source in sources) source.sourceId,
      ],
  };
  if (ids.isEmpty) {
    return const AsyncValue<List<AgedRemainderDay>>.data(
      <AgedRemainderDay>[],
    );
  }

  final List<AgedRemainderCard> all = <AgedRemainderCard>[];
  for (final String id in ids) {
    final AsyncValue<List<AgedRemainderCard>> cards =
        ref.watch(agedRemaindersForSourceProvider(id));
    // ⚠️ **والخطأ يُنقَل كما هو ⛔ لا يُطوى في قائمة فارغة** — ⟵ **فيُميِّز
    //    المستخدم بين «لا متبقٍّ» و«ممنوعٌ من الرؤية»** (`RISK-02`).
    if (cards.hasError) {
      return AsyncValue<List<AgedRemainderDay>>.error(
        cards.error ?? Object(),
        cards.stackTrace ?? StackTrace.current,
      );
    }
    final List<AgedRemainderCard>? value = cards.value;
    if (value == null) {
      return const AsyncValue<List<AgedRemainderDay>>.loading();
    }
    all.addAll(value);
  }

  // ⛔⛔★★ **والتجميعُ في طبقة النطاق لا هنا** — `coding-standards.md` §2.2:
  //    ⟵ **فقاعدةُ «متأخر» وحدودُ الحدّة تعيشان في موضعٍ واحد** تشاركه
  //    الشاشةُ والاختبارُ معاً.
  return AsyncValue<List<AgedRemainderDay>>.data(
    groupAgedRemainders(cards: all, today: ref.watch(todayProvider)),
  );
});

/// ★★★ **خلاصةُ التنبيه الدائم** — `FR-M8-10` (`GR-16`).
///
/// ⛔ **وعبر كل مصادر النطاق** — ⟵ **فالبطاقةُ في الرئيسية لا تتبع مرشِّحَ
/// شاشةٍ أخرى**: ★ **«ينبّه حتى يُصرَّف بالكامل»** يعني **كلَّ ما لم يُصرَّف**
/// ⛔ **لا ما اختار المستخدمُ رؤيته.**
final Provider<AsyncValue<AgedRemainderAlert>> agedRemainderAlertProvider =
    Provider<AsyncValue<AgedRemainderAlert>>(
  (Ref ref) => ref
      .watch(agedRemainderDaysProvider(null))
      .whenData(summarizeAgedRemainders),
);

// ═════════════════════════════════════════════════════════════════════════
// وجهةُ التصريف — `FR-M8-11` · `FR-M8-12` · `UC-004` ③
// ═════════════════════════════════════════════════════════════════════════

/// ★★ ما تُثبِّته شاشةُ المتبقي على شاشة التصريف — `FR-M8-12`.
///
/// ⛔⛔★★★ **ولا شاشةَ تصريفٍ بديلة** (`FR-M8-11` · `UC-004` ③): ★ **الإجراءُ
/// يفتح `M10` أو `M11` نفسَها مثبَّتةً** — ⟵ **فيبقى مسارُ الكتابة واحداً**
/// ⛔ **ولا معادلةَ ضمارٍ ثانية ولا مسارُ خصمٍ ثانٍ.** ★ **وهو نظيرُ
/// `PendingFocus` حرفياً** (`FR-SYS-04`) ⛔ **لا آليةٌ جديدة تُخترَع.**
@immutable
class AgedClearanceFocus {
  /// ينشئ الوجهة.
  const AgedClearanceFocus({
    required this.sourceId,
    required this.itemKey,
    required this.stockDate,
  });

  /// المصدر — 🔒 **مثبَّت** (`FR-M8-12`).
  final String sourceId;

  /// مفتاح النوع — 🔒 **مثبَّت**.
  final String itemKey;

  /// ★★ **تاريخ المخزون القديم** — 🔒 **مثبَّت**، ⛔ **ولا يُغيَّر في الشاشة**.
  final CalendarDay stockDate;

  @override
  bool operator ==(Object other) =>
      other is AgedClearanceFocus &&
      other.sourceId == sourceId &&
      other.itemKey == itemKey &&
      other.stockDate == stockDate;

  @override
  int get hashCode => Object.hash(sourceId, itemKey, stockDate);
}

/// ★ الوجهة المطلوبة الآن — و`null` **لا وجهة**.
///
/// ⚠️ **وتُستهلَك مرةً واحدة** ([AgedClearanceFocusState.take]) — ⟵ **فالشاشة
/// لا تُعيد فتح السياق نفسه في كل إعادة بناء** (نظيرُ `pendingFocusProvider`).
final NotifierProvider<AgedClearanceFocusState, AgedClearanceFocus?>
    agedClearanceFocusProvider =
    NotifierProvider<AgedClearanceFocusState, AgedClearanceFocus?>(
  AgedClearanceFocusState.new,
);

/// حالة الوجهة.
class AgedClearanceFocusState extends Notifier<AgedClearanceFocus?> {
  @override
  AgedClearanceFocus? build() => null;

  /// يطلب فتح شاشة تصريفٍ مثبَّتة على بندٍ متأخر.
  void request(AgedClearanceFocus focus) => state = focus;

  /// ★ يقرأ الوجهة **ويستهلكها** — ⟵ **فلا تُطبَّق مرتين.**
  AgedClearanceFocus? take() {
    final AgedClearanceFocus? current = state;
    state = null;
    return current;
  }
}

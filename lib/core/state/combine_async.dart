/// ★★★ **دمجُ تدفّقاتِ عدّةِ مصادرَ في قائمةٍ واحدة** — `AM-009` ③.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **ولماذا دمجٌ في الذاكرة لا استعلامٌ واحدٌ غيرُ مقيَّد:**
///
/// ★ **شرطُ قراءة كل مجموعةٍ هنا يعتمد `resource.data.sourceId`**
/// (`storedInScope()` في `firestore.rules`) — ⟵ **والشرطُ يُقيَّم على قيود
/// الاستعلام لا على كل مستند**: ⛔ **فاستعلامٌ لا يُقيّد `sourceId` يُرفَض
/// كاملاً ولو كان نطاقُ المستخدم شاملاً.**
///
/// ★★ **وهي مقايسةُ `IQ-024` و`WU-008` نفسُها** (`CLAUDE.md`) — ★ **والعلاج
/// تقييدُ الحقل** ⛔ **لا تخفيفُ القاعدة**: ⟵ **فـ«كل المصادر» = استعلامٌ
/// مقيَّدٌ لكل مصدرٍ في نطاق المستخدم، ثم دمجٌ هنا.**
/// ═══════════════════════════════════════════════════════════════════════
///
/// ⛔ **ولا معادلةَ عملٍ هنا ولا جمعٌ لأرقام** — ★ **ضمُّ قوائمَ لا غير**
/// (`ADR-0010` القاعدة 5 · `A-01`): ⟵ **وكلُّ عنصرٍ يبقى مستنداً في مصدره.**
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// ★★ يضمّ عدّةَ [AsyncValue] لقوائمَ في واحدة.
///
/// ★ **وقواعدُ الحالة الثلاث صريحة:**
/// ① **خطأٌ في أيٍّ منها ⟵ خطأ** — ⛔ **ولا تُبتلَع نتيجةٌ ناقصة تُقرأ
///    قائمةً كاملة**: ⟵ **ومستخدمٌ يظنّ أنه رأى كلَّ توزيعات اليوم وقد
///    سقط مصدرٌ كامل عطلٌ صامت.**
/// ② **تحميلٌ في أيٍّ منها ⟵ تحميل** — ★ **فلا تظهر القائمة تنمو أمام
///    العين** ⛔ **ولا يُقرأ نصفُها «لا نتائج».**
/// ③ **واكتمالُ الكلّ ⟵ قائمةٌ واحدة** بترتيب [compare] إن مُرِّر.
AsyncValue<List<T>> combineAsyncLists<T>(
  List<AsyncValue<List<T>>> parts, {
  int Function(T a, T b)? compare,
}) {
  if (parts.isEmpty) return AsyncValue<List<T>>.data(<T>[]);
  for (final AsyncValue<List<T>> part in parts) {
    if (part.hasError) {
      return AsyncValue<List<T>>.error(
        part.error!,
        part.stackTrace ?? StackTrace.empty,
      );
    }
  }
  final List<T> merged = <T>[];
  for (final AsyncValue<List<T>> part in parts) {
    final List<T>? value = part.value;
    if (value == null) return AsyncValue<List<T>>.loading();
    merged.addAll(value);
  }
  if (compare != null) merged.sort(compare);
  return AsyncValue<List<T>>.data(merged);
}

/// ★★ ويضمّ عدّةَ [AsyncValue] لقيمٍ مفردة في قائمةٍ واحدة — **بنفس القواعد**.
///
/// ⚠️ **ولماذا نظيرٌ لـ[combineAsyncLists] لا توسعةٌ له:** ★ **ذاك يضمّ
/// *قوائم*** ⟵ **وهذا يضمّ *قيماً*** (**ملخّصُ مصدرٍ واحدٍ في يوم** —
/// `WU-016`): ⛔ **ودمجُهما في دالةٍ واحدة كان يحتاج تسطيحاً يُخفي الفرق.**
/// ★ **والقواعدُ الثلاث نفسُها حرفياً** — ⛔ **ولا تُخفَّف واحدةٌ منها:**
/// ⟵ **بطاقةُ «كل المصادر» الناقصةُ مصدراً رقمٌ ماليٌّ كاذب** (`A-01`).
AsyncValue<List<T>> combineAsync<T>(List<AsyncValue<T>> parts) {
  if (parts.isEmpty) return AsyncValue<List<T>>.data(<T>[]);
  for (final AsyncValue<T> part in parts) {
    if (part.hasError) {
      return AsyncValue<List<T>>.error(
        part.error!,
        part.stackTrace ?? StackTrace.empty,
      );
    }
  }
  final List<T> merged = <T>[];
  for (final AsyncValue<T> part in parts) {
    // ⛔★★ **والانتظارُ يُقاس بـ`hasValue` لا بـ`value != null`** — ⟵ **فقيمةُ
    //    `null` نتيجةٌ صحيحة هنا**: ★ **يومٌ بلا ملخّصٍ مكتوب** (§9).
    if (!part.hasValue) return const AsyncValue<Never>.loading();
    merged.add(part.value as T);
  }
  return AsyncValue<List<T>>.data(merged);
}

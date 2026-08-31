/// عقد تسجيل التصدير — ★ **يعرّفه النطاق وتُنفِّذه البنية التحتية**
/// (`ADR-0009` · `ADR-0010` القاعدة 2).
///
/// ⛔⛔★★ **ولا يكتبه التطبيق مباشرةً:** `audit_log` **`allow create, update,
/// delete: if false`** لكل مستخدم — ⟵ **فالتنفيذ نداءٌ للعملية السحابية
/// `logExport`** (`ADR-0013` · `IQ-032`).
library;

import '../../../core/outcome.dart';

/// صيغة الملف المُصدَّر — ★ **نظيرُ `ExportFormat` في العملية السحابية**.
///
/// ⚠️ **ونسختان بالضرورة لا بالسهو:** ★ **`functions/` حزمةٌ لا يعتمد عليها
/// التطبيق**، ⟵ **والقيمة النصّية هي العقد بينهما** ([wireName]) —
/// ⛔ **ويحرس التطابقَ اختبارٌ في الطرفين.**
enum ExportedFormat {
  /// ملف PDF.
  pdf;

  /// القيمة كما تعبر الشبكة — **مطابِقةٌ حرفياً لنظيرتها في السحابة**.
  String get wireName => name;
}

/// مستودع تسجيل التصدير.
abstract interface class ExportLogRepository {
  /// يسجّل تصدير مستندٍ في سجل التدقيق — `FR-M19-04`.
  ///
  /// ★ **يُرجِع نتيجةً ولا يرمي** (`error-handling-strategy.md` §3 القاعدة 3).
  Future<Outcome<void>> logExport({
    required String sourceId,
    required String entityType,
    required String entityId,
    required ExportedFormat format,
    String? documentNumber,
  });
}

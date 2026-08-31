/// دليل المركز المعلّق — ★★ **قراءةً فقط** (`ADR-0013` القاعدة 4 · `FR-SYS-09`).
///
/// ⛔⛔★★ **ولا كتابةَ واحدة هنا ولا مسارَ لها:** `pending_entries`
/// **`allow write: if false`** — ★ **والبنود تُنشئها وتحذفها السحابة حصراً**
/// (`FR-SYS-09`)، ⟵ **داخل معاملة مستندها نفسِها** (`pending_entries.dart`
/// في `functions/`).
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **وكل استعلامٍ هنا يُقيّد `sourceId` — درسٌ مقيسٌ ثلاث مرات:**
/// قاعدة `pending_entries` تشترط `storedInScope()` وهو شرطٌ على
/// `resource.data`، ⟵ **والسردُ يُقيَّم على قيود الاستعلام لا على كل مستند**
/// ⟹ **`getDocs` بلا قيدٍ على `sourceId` يُرفَض كاملاً — ولو بنطاقٍ شامل**
/// (`IQ-024` · `WU-008` · `DEBT-40`).
///
/// ★ **والفهرس المستعمَل** (`indexing-strategy.md`): `sourceId ↑ · date ↓`
/// — ⛔ **ولا قيدَ ثالث في الاستعلام**: ★ **نوعُ المستند يُفلتَر في الذاكرة**
/// (راجع [PendingEntryDirectory.watchPending]).
/// ═══════════════════════════════════════════════════════════════════════
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qtms_domain/qtms_domain.dart';

/// الدليل الحقيقي.
final class FirestorePendingEntryDirectory implements PendingEntryDirectory {
  /// ينشئ الدليل.
  const FirestorePendingEntryDirectory(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Stream<List<PendingEntryCard>> watchPending({
    required PendingEntryFilter filter,
    int limit = pendingEntriesPageSize,
  }) =>
      _firestore
          .collection(pendingEntriesCollection)
          // ⛔⛔ **المصدر أولاً وفي كل حال** — راجع ترويسة الملف.
          .where('sourceId', isEqualTo: filter.sourceId)
          .orderBy('date', descending: true)
          .limit(limit)
          .snapshots()
          .map(
            (QuerySnapshot<Map<String, dynamic>> snapshot) =>
                <PendingEntryCard>[
              for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
                  in snapshot.docs)
                if (cardOf(doc.id, doc.data()) case final PendingEntryCard card)
                  if (filter.accepts(card)) card,
            ],
          );

  /// ★★ يبني البطاقة من بندٍ **كُتب فعلاً** — ⛔ **بلا رمي إطلاقاً**.
  ///
  /// ★★ **ومكشوفٌ للاختبار وحده** — بنفس علّة `FirestoreAuditLogDirectory
  /// .cardOf`: ⟵ **التحويلُ هو موضعُ العطل المحتمل** (`DEBT-37`)، ★ **وحراستُه
  /// تحتاج اختباراً سلوكياً على المخرَج** ⛔ **لا تغطيةً نصّية.**
  ///
  /// ⚠️⚠️ **والتسامح مقصود:** المركز **مشتقٌّ ويُعاد بناؤه** (`PAT-07`)،
  /// ⟵ **وبندٌ كتبه إصدارٌ أحدث بحقلٍ لا يعرفه هذا الإصدار يبقى مقروءاً
  /// بلا وجهة** (`PendingEntryCard.hasDestination`) ⛔ **بدل أن يُسقِط
  /// الشاشة كلَّها** — ★ **وشاشةٌ تسقط تُخفي كلَّ ما ينقص لا بنداً واحداً.**
  static PendingEntryCard cardOf(String docId, Map<String, dynamic> data) =>
      PendingEntryCard(
        id: docId,
        kind: PendingDocumentKind.tryParse(data['documentType']),
        documentId: _text(data['documentId']) ?? '',
        // ★ **وعنوانٌ غائب يُقرأ بمعرّفه** — ⛔ **ولا يختفي البند**:
        //   ⟵ **بندٌ بلا عنوان أفضل من نقصٍ لا يُرى.**
        readableTitle: _text(data['readableTitle']) ??
            _text(data['documentId']) ??
            'بند بلا عنوان',
        sourceId: _text(data['sourceId']) ?? '',
        date: _dayOf(data['date']),
        missingField: _text(data['missingField']) ?? 'قيمة ناقصة',
        field: PendingMissingField.tryParse(data['missingFieldKey']),
        documentNumber: _text(data['documentNumber']),
      );

  static CalendarDay? _dayOf(Object? raw) => switch (raw) {
        final Timestamp value => CalendarDay.fromUtc(value.toDate().toUtc()),
        final DateTime value => CalendarDay.fromUtc(value.toUtc()),
        _ => null,
      };

  static String? _text(Object? raw) {
    if (raw is! String) return null;
    final String trimmed = raw.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

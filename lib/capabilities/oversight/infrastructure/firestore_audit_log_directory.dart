/// دليل سجل التدقيق — ★★ **قراءةً فقط** (`ADR-0013` القاعدة 4 · `FR-M18-13`).
///
/// ⛔⛔★★ **ولا كتابةَ واحدة هنا ولا مسارَ لها:** `audit_log` **`allow create,
/// update, delete: if false` للجميع بمن فيهم المالك** (`FR-M18-01` · `GR-08`)
/// — ★ **والقيد يُكتب داخل معاملة المستند نفسه في السحابة**
/// (`ADR-0013` القاعدة 1 · `audited_transaction.dart`).
///
/// ⚠️ **والرفض يصل كخطأ في التدفّق لا كقائمة فارغة** — ⟵ ★ **فتُميِّز الشاشة
/// بين «لا نشاط» و«ممنوعٌ من الرؤية»** (`FR-M18-12`).
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **وكل استعلامٍ هنا يُقيّد `sourceId` — قياساً حيّاً لا اجتهاداً:**
///
/// ★★ **قُيس على المحاكي (2026-08-27):** `getDocs` على `audit_log`
/// **بلا قيدٍ على `sourceId` يُرفَض — ولو بنطاقٍ شامل** (`false for 'list'`)،
/// ⟵ **لأن `storedInScope()` شرطٌ على `resource.data` والسردُ يُقيَّم على
/// قيود الاستعلام لا على كل مستند** (درس `IQ-024` نفسه).
///
/// ★ **والفهارس التي يستعملها هذا الملف** (`audit-log-design.md` §7):
///
///   • المصدر وحده ⟵ `sourceId ↑ · occurredAt ↓`.
///   • + المستخدم ⟵ `sourceId ↑ · userId ↑ · occurredAt ↓`.
///   • + الإجراء  ⟵ `sourceId ↑ · action ↑ · occurredAt ↓`.
///   • السياقي    ⟵ `sourceId ↑ · entityType ↑ · entityId ↑ · occurredAt ↓`.
///
/// ⛔ **ولا استعلامَ يجمع بُعدين ثانويين** — [AuditLogFilter] يمنعه بنوعه.
/// ═══════════════════════════════════════════════════════════════════════
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qtms_domain/qtms_domain.dart';

/// الدليل الحقيقي.
final class FirestoreAuditLogDirectory implements AuditLogDirectory {
  /// ينشئ الدليل.
  const FirestoreAuditLogDirectory(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Stream<List<AuditLogEntryCard>> watchCentralLog({
    required AuditLogFilter filter,
    int limit = auditLogPageSize,
  }) {
    // ⛔⛔ **المصدر أولاً وفي كل حال** — راجع ترويسة الملف.
    Query<Map<String, dynamic>> query = _firestore
        .collection(auditLogCollection)
        .where('sourceId', isEqualTo: filter.sourceId);

    query = switch (filter.dimension) {
      AuditFilterDimension.none => query,
      AuditFilterDimension.user =>
        query.where('userId', isEqualTo: filter.userId),
      AuditFilterDimension.action =>
        query.where('action', isEqualTo: filter.action!.name),
    };

    // ★★ **والمدى على الحقل المرتَّب به نفسه** — ⟵ **فلا فهرسَ إضافي.**
    if (filter.from case final CalendarDay from) {
      query = query.where(
        'occurredAt',
        isGreaterThanOrEqualTo: Timestamp.fromDate(from.asUtcMidnight()),
      );
    }
    if (filter.to case final CalendarDay to) {
      // ★ **والنهاية شاملةٌ لليوم كلّه** — ⟵ **فحدٌّ أعلى بمنتصف ليل ذلك
      //   اليوم كان سيُسقِط كل قيوده**، ⛔ **وهو خطأٌ صامت يبدو «لا نشاط».**
      query = query.where(
        'occurredAt',
        isLessThan: Timestamp.fromDate(to.asUtcMidnight().add(_oneDay)),
      );
    }

    return _watch(query, limit);
  }

  @override
  Stream<List<AuditLogEntryCard>> watchEntityLog({
    required AuditEntityRef entity,
    int limit = auditLogPageSize,
  }) =>
      _watch(
        _firestore
            .collection(auditLogCollection)
            // ⛔⛔ **والمصدر أولاً هنا كذلك** — ★ **قيسَ أن استعلام
            //    `entityType`+`entityId` وحدَه يُرفَض** ⟵ **فيبدو «لا تاريخ
            //    لهذا المستند»**، ⛔ **وهو أسوأ عطلٍ في الحافظ الوحيد للتاريخ.**
            .where('sourceId', isEqualTo: entity.sourceId)
            .where('entityType', isEqualTo: entity.entityType)
            .where('entityId', isEqualTo: entity.entityId),
        limit,
      );

  /// ★ الترتيب والحدّ معاً — ⛔ **ولا استعلامَ بلا أيٍّ منهما**.
  ///
  /// ⚠️ **والترتيب تنازليٌّ دائماً** — `FR-M18-10`: «**مرتبة زمنياً
  /// تنازلياً**»، ★ **وهو اتجاه الفهارس الأربعة كلها** (`occurredAt ↓`).
  Stream<List<AuditLogEntryCard>> _watch(
    Query<Map<String, dynamic>> query,
    int limit,
  ) =>
      query
          .orderBy('occurredAt', descending: true)
          .limit(limit)
          .snapshots()
          .map(
            (QuerySnapshot<Map<String, dynamic>> snapshot) =>
                <AuditLogEntryCard>[
              for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
                  in snapshot.docs)
                cardOf(doc.id, doc.data()),
            ],
          );

  // ═════════════════════════════════════════════════════════════════════
  // التحويل — ⛔ **والمجهول يُقرأ بالافتراض الآمن ولا يُسقِط الشاشة**
  // ═════════════════════════════════════════════════════════════════════

  /// ★★ يبني البطاقة من مستندٍ **كُتب فعلاً** — ⛔ **بلا رمي إطلاقاً**.
  ///
  /// ★★ **ومكشوفٌ للاختبار وحده** — بنفس علّة `FirestoreInventoryDirectory
  /// .movementOf`: ⟵ **التحويلُ هو موضعُ العطل المحتمل** (`DEBT-37`:
  /// «⛔ **فاختبارُ الطبقة لا يُغني عن اختبار ما يعبر بينها**»)، ★ **وحراستُه
  /// تحتاج اختباراً سلوكياً على المخرَج** ⛔ **لا تغطيةً نصّية.**
  ///
  /// ⚠️⚠️ **ولماذا التسامح هنا تحديداً:** السجل **للإضافة فقط ولا يُهاجَر**
  /// (`schema/audit-log.md`) — ⟵ **فقيدٌ كتبه إصدارٌ سابق أو لاحق قد ينقصه
  /// حقلٌ أو يحمل فعلاً لا يعرفه هذا الإصدار.** ★ **ورميُ استثناءٍ عليه
  /// كان يُسقِط شاشة التدقيق كاملةً بسبب قيدٍ واحد** — ⛔ **وهو أسوأ ما
  /// يقع لشاشةٍ هي الحافظ الوحيد للتاريخ** (`RISK-05`).
  static AuditLogEntryCard cardOf(String docId, Map<String, dynamic> data) =>
      AuditLogEntryCard(
        id: _text(data['id']) ?? docId,
        // ⚠️ **وغيابُ الوقت لا يُخفي القيد** — ★ **يُقرأ بحقبة صفرية فيقع
        //    في ذيل الترتيب**، ⛔ **بدل أن يختفي من شاشة تدقيق.**
        occurredAt: _instant(data['occurredAt']) ?? DateTime.utc(1970),
        userId: _text(data['userId']) ?? '',
        // ★ **الاسم منسوخٌ وقت الحدث** — ⛔ **ولا يُقرأ من بطاقة المستخدم الآن**
        //   (`audit-log-design.md` §2 الشرط 4).
        userName: _text(data['userName']) ?? 'مستخدم غير معروف',
        // ★★★ **والبريدُ منسوخٌ وقت الحدث كذلك** — `AM-012` §3.
        //
        // ⛔⛔★★★ **و`null` لا نصٌّ بديل** — ★ **بخلاف الاسم أعلاه عمداً:**
        //    ⟵ **الاسمُ حقلٌ إلزاميٌّ في كل قيدٍ منذ أول يوم فغيابُه عطلٌ
        //    يُعلَن**، ★ **والبريدُ حقلٌ أُضيف في 2026-09-02** ⟹ ⛔ **فغيابُه
        //    في قيدٍ أقدمَ هو الحالُ الطبيعي لا عطل** — ★ **و«بريد غير
        //    معروف» تحت اسمٍ صحيح كانت تُقرأ اتهاماً للبيانات.**
        //    ⟵ **والعرضُ يُسقِط السطر بلا أثر** (`audit_trail_view.dart`).
        userEmail: _text(data['userEmail']),
        action: _actionOf(data['action']),
        entityType: _text(data['entityType']) ?? '',
        entityId: _text(data['entityId']) ?? '',
        sourceId: _text(data['sourceId']) ?? auditAllSourcesId,
        documentNumber: _text(data['documentNumber']),
        // ★★ **مكتوبٌ نصّاً بصيغة `YYYYMMDD`** — `AuditEntry.toFields`،
        //   ⟵ **ويُفَكّ بنظير كاتبه حرفياً** ⛔ **لا بصيغةٍ ثانية.**
        stockDate: _dayOf(data['stockDate']),
        valuesBefore: _values(data['valuesBefore']),
        valuesAfter: _values(data['valuesAfter']),
        reason: _text(data['reason']),
        deviceInfo: _text(data['deviceInfo']),
      );

  /// ★ الفعل المقروء — ⛔ **والمجهول `null` لا افتراضٌ صامت**.
  ///
  /// ⚠️⚠️ **ولا يُقرأ «إنشاءً» احتياطاً:** ⟵ **قيدُ تعديلٍ يُعرَض إنشاءً
  /// يكذب على المدقّق**، ★ **والغياب الصريح يقول «لا أعرف» ويعرض البقية.**
  static AuditAction? _actionOf(Object? raw) {
    for (final AuditAction action in AuditAction.values) {
      if (action.name == raw) return action;
    }
    return null;
  }

  /// ★ خريطة القيم — ⛔ **وغير الخريطة تُقرأ فراغاً لا تُسقِط القيد**.
  static Map<String, Object?> _values(Object? raw) => raw is Map
      ? <String, Object?>{
          for (final MapEntry<Object?, Object?> entry in raw.entries)
            if (entry.key case final String key) key: _plain(entry.value),
        }
      : const <String, Object?>{};

  /// ★ قيمةٌ صالحةٌ للعرض والمقارنة — **والطوابع تصير لحظاتٍ صريحة**.
  ///
  /// ⚠️ **ولماذا يُنزَع نوع المنصّة هنا:** `sameAuditValue` تُقارن بالقيمة،
  /// ★ **وطابعان متساويان بمرجعين مختلفين كانا سيُقرآن «تغييراً»** ⟵ **فيمتلئ
  /// السجل بصفوفٍ لم يتغيّر فيها شيء.**
  static Object? _plain(Object? raw) => switch (raw) {
        final Timestamp value => value.toDate().toUtc(),
        final Map<Object?, Object?> value => <String, Object?>{
            for (final MapEntry<Object?, Object?> entry in value.entries)
              if (entry.key case final String key) key: _plain(entry.value),
          },
        final List<Object?> value => <Object?>[
            for (final Object? item in value) _plain(item),
          ],
        _ => raw,
      };

  static CalendarDay? _dayOf(Object? raw) =>
      raw is String ? CalendarDay.tryParseCompact(raw) : null;

  static DateTime? _instant(Object? raw) => switch (raw) {
        final Timestamp value => value.toDate().toUtc(),
        final DateTime value => value.toUtc(),
        _ => null,
      };

  static String? _text(Object? raw) {
    if (raw is! String) return null;
    final String trimmed = raw.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

/// ★ يومٌ واحد — ★ **لجعل حدّ المدى الأعلى شاملاً ليومه**.
const Duration _oneDay = Duration(days: 1);

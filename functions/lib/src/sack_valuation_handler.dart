/// تنفيذ مُحتسِب سعر الجونية وصافي الرعوي — **الطرف الذي يلمس الشبكة**.
///
/// ★ **مفصول عن `sack_valuation.dart` عمداً**، بنفس منطق
/// `account_provisioning_handler.dart`: كل قرارٍ هناك في **دوال خالصة
/// تُختبَر بلا سحابة**؛ **وهنا القراءة والتطبيع والالتزام** وحدها.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **ولماذا ليست معاملةً ذرّية واحدة — وهو أهم قرارٍ في هذا الملف:**
///
/// ★ **هذه عمليةٌ «مشغَّلة بالكتابة»** (`api-overview.md` §3.2 —
/// `recomputeSackRevenue`) **لا كتابةُ مستخدم**: ⟵ **و`ADR-0013` القاعدة 1
/// تحكم «المستند وقيدَه»**، ⛔ **وهذه لا مستندَ مستخدمٍ فيها ولا قيد.**
/// ★ **وهو حرفياً تعليلُ `account_provisioning_handler.dart`:** «**كل كتابة
/// مستقلة ومُشتقّة المعرّف، فالتشغيل الجزئي ثم إعادة التشغيل يُكملان الناقص
/// بلا ازدواج ولا تراكم**» — ⟵ **وهو معنى «قابلة للتكرار بلا أثر جانبي»**
/// (`api-overview.md` §3.3 · `coding-standards.md` §2.7).
///
/// ⛔⛔★★ **والقراءةُ على مرحلتين لا واحدة — وهي ما يمنع بناؤها داخل معاملة:**
/// ★ **المستنداتُ المساهِمة تُكتشَف بالاستعلام ثم تُقرأ أسعارُها المعزولة**
/// (`distributions/{id}/pricing/current` — `ADR-0011`)، ⟵ **و`AuditedTransaction`
/// تقرأ مساراتٍ معروفةً مقدَّماً** ⛔ **فلا تقبل مرحلةً ثانية.**
///
/// ⛔⛔★★★ **وفشلُ هذا المُحتسِب لا يُبطل العملية الأصلية** — `api-overview.md`
/// §3.3 نصّاً — ★ **ويُسجَّل صريحاً**: ⟵ **فالرقم يتأخّر ولا يُفقَد**،
/// ⛔ **وأولُ تشغيلٍ تالٍ على نفس اليوم يُصلحه** لأنه يُعيد البناء بالكامل.
/// ═══════════════════════════════════════════════════════════════════════
///
/// ⚠️ **وبتجميعٍ لا بعد كل حركة** (`sack-valuation-design.md` §6 القاعدة 1):
/// ★ **الوحدةُ هي (المصدر × تاريخ المخزون)** — ⟵ **فتوزيعةٌ تمسّ ثلاث جوانٍ
/// تُعيد احتسابها في قراءةٍ واحدة** ⛔ **لا ثلاث.**
library;

import 'dart:io' show stdout;

import 'package:qtms_domain/qtms_domain.dart';

import 'firestore_writer.dart';
import 'inventory.dart' show InventoryWrite, documentStatusField;
import 'sack_movement_reader.dart';
import 'sack_valuation.dart';

/// مُحتسِب مالية الجواني.
final class SackValuationHandler {
  /// ينشئ المُحتسِب — ★ **بتبعيةٍ واحدة تُحقَن، فيُختبَر بلا سحابة**.
  const SackValuationHandler(this._writer);

  final FirestoreWriter _writer;

  /// ★★★ **يُعيد احتساب كل جواني (مصدر × تاريخ مخزون)** — `FR-M14-05`.
  ///
  /// ★ **ويُرجِع عدد الجواني التي تغيّر رقمُها** — ⟵ **فالمُستدعي يُسجّله**،
  /// ⛔ **ولا يُعلن نجاحاً بلا رقمٍ يقابله** (بروتوكول التشغيل §و).
  Future<int> revalueDay({
    required String sourceId,
    required CalendarDay stockDate,
  }) async {
    final List<StoredDocument> sacks = await _writer.queryDocuments(
      collectionId: sacksCollection,
      equals: <String, Object?>{
        'sourceId': sourceId,
        // ★★ **تاريخ المخزون لا تاريخ الإدخال** — `RISK-07`.
        'stockDate': stockDate.asUtcMidnight(),
      },
    );
    if (sacks.isEmpty) return 0;

    final List<SackMovementDocument> documents =
        await readSackMovementDocuments(
      _writer,
      sourceId: sourceId,
      stockDate: stockDate,
    );
    final List<SackValuationState> states = await _readSackStates(sacks);

    final SackValuationPlan plan =
        planSackValuation(sacks: states, documents: documents);
    if (plan.isEmpty) return 0;

    await _writer.commitWrites(_committed(plan.writes));
    await _rebuildBalances(
      sourceId: sourceId,
      supplierIds: plan.touchedSupplierIds,
    );
    return plan.writes.length;
  }

  /// ★ يقرأ ماليةَ كل جونيةٍ وسطرَ دفترها **في نداءٍ واحد** — §6 القاعدة 1.
  Future<List<SackValuationState>> _readSackStates(
    List<StoredDocument> sacks,
  ) async {
    final Map<String, String> financePaths = <String, String>{
      for (final StoredDocument sack in sacks)
        sack.id: _writer.documentPath(
          '$sacksCollection/${sack.id}/$sackFinanceSubcollection',
          sackFinanceDocumentId,
        ),
    };
    final Map<String, String> ledgerPaths = <String, String>{
      for (final StoredDocument sack in sacks)
        sack.id: _writer.documentPath(
          supplierLedgerCollection,
          supplierLedgerEntryId(sackId: sack.id),
        ),
    };
    final Map<String, Map<String, Object?>?> reads = await _writer.readDocuments(
      <String>[...financePaths.values, ...ledgerPaths.values],
    );

    return <SackValuationState>[
      for (final StoredDocument sack in sacks)
        _stateOf(
          sack,
          finance: reads[financePaths[sack.id]],
          ledger: reads[ledgerPaths[sack.id]],
        ),
    ];
  }

  static SackValuationState _stateOf(
    StoredDocument sack, {
    required Map<String, Object?>? finance,
    required Map<String, Object?>? ledger,
  }) =>
      SackValuationState(
        sackId: sack.id,
        sourceId: _text(sack.fields['sourceId']) ?? '',
        displayName: _text(sack.fields['displayName']) ?? sack.id,
        supplierId: _text(sack.fields['supplierId']),
        supplierName: _text(sack.fields['supplierName']),
        isCancelled:
            sack.fields[documentStatusField] == SackStatus.cancelled.name,
        sackTax: _money(finance?['sackTax']),
        storedRevenue: _money(finance?['sackRevenue']),
        storedNet: _money(finance?['supplierNet']),
        storedRevenueFinal: finance?['isRevenueFinal'] as bool?,
        storedRecalcVersion: _int(ledger?[recalcVersionField]) ?? 0,
      );

  /// ★★ يُعيد بناء رصيد كل رعويٍّ تأثّر — **من دفتره بالكامل** (§2.5).
  ///
  /// ⛔★★ **وبعد الالتزام لا قبله** — ⟵ **فالاستعلام يقرأ السطورَ المكتوبةَ
  /// للتوّ**: ★ **والقاعدة متسقةٌ قراءةً بعد الكتابة**، ⛔ **وبناؤه قبلها
  /// كان يُنتج رصيداً متأخّراً بدورةٍ كاملة.**
  Future<void> _rebuildBalances({
    required String sourceId,
    required Set<String> supplierIds,
  }) async {
    final List<CommittedWrite> writes = <CommittedWrite>[];
    for (final String supplierId in supplierIds) {
      final List<StoredDocument> rows = await _writer.queryDocuments(
        collectionId: supplierLedgerCollection,
        equals: <String, Object?>{
          'supplierId': supplierId,
          // ★★ **والمصدر مُقيَّدٌ صراحةً** — ⛔ **ولا حساب موحّد** (`GR-21`).
          'sourceId': sourceId,
        },
      );
      writes.add(
        _committedOne(
          planSupplierBalance(
            supplierId: supplierId,
            sourceId: sourceId,
            rows: <SupplierSackRow>[
              for (final StoredDocument row in rows)
                // ⛔ **والملغاة لا تدخل الجمع** (`A-14`).
                if (row.fields['isCancelled'] != true)
                  SupplierSackRow(
                    sackId: row.id,
                    sackRevenue: _money(row.fields['sackRevenue']) ?? Money.zero,
                    sackTax: _money(row.fields['sackTax']),
                    isRevenueFinal: row.fields['isRevenueFinal'] != false,
                  ),
            ],
          ),
        ),
      );
    }
    if (writes.isNotEmpty) await _writer.commitWrites(writes);
  }

  // ═════════════════════════════════════════════════════════════════════
  // القراءة الآمنة — ⛔ **والمجهول يُقرأ غياباً لا قيمةً مخترَعة**
  // ═════════════════════════════════════════════════════════════════════

  static List<CommittedWrite> _committed(List<InventoryWrite> writes) =>
      <CommittedWrite>[for (final InventoryWrite write in writes) _committedOne(write)];

  static CommittedWrite _committedOne(InventoryWrite write) => CommittedWrite(
        collectionId: write.collectionId,
        documentId: write.documentId,
        fields: write.fields,
        updateMask: write.updateMask,
        serverTimestampFields: write.serverTimestampFields,
      );

  static String? _text(Object? raw) {
    if (raw is! String) return null;
    final String trimmed = raw.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  /// ★ مبلغٌ مقروء أو `null` — ⛔ **والكسر ليس مبلغاً** (`ADR-0015`).
  static Money? _money(Object? raw) {
    final int? value = _int(raw);
    return value == null ? null : Money(value);
  }

  static int? _int(Object? raw) => switch (raw) {
        final int value => value,
        final double value when value == value.roundToDouble() => value.toInt(),
        _ => null,
      };

}

/// ★★★ **يُطلق المُحتسِب بعد التزام العملية الأصلية** — ⛔ **ولا يُبطلها**.
///
/// ⚠️⚠️ **وهذا نصّ `api-overview.md` §3.3 حرفياً:** «**فشل عملية مشغَّلة لا
/// يُبطل الأصلية**» — ★ **والاستثناء الوحيد قيدُ التدقيق** (`BR-M18-03`)،
/// ⛔ **وهذه ليست قيداً.**
///
/// ★ **ويُسجَّل الفشل بنصّه** — ⟵ **فالتأخّر مرئيٌّ لا صامت**، ⛔ **ولا حمولةَ
/// ولا رمزَ دخولٍ في السجل** (`coding-standards.md` §2.4).
Future<void> revalueSacksAfterCommit(
  SackValuationHandler? handler, {
  required String sourceId,
  required CalendarDay stockDate,
}) async {
  if (handler == null) return;
  try {
    final int written = await handler.revalueDay(
      sourceId: sourceId,
      stockDate: stockDate,
    );
    if (written > 0) {
      stdout.writeln(
        'recomputeSackRevenue: $sourceId ⟵ ${stockDate.format()} '
        '— $written كتابة',
      );
    }
  } on Object catch (error) {
    // ⛔ **ولا يُبتلَع صامتاً** — `coding-standards.md` §2.5 القاعدة 1:
    //    ★ **يُبلَّغ في السجل**، ⟵ **والعملية الأصلية ملتزمةٌ سلفاً.**
    stdout.writeln(
      'recomputeSackRevenue: ⛔ تعذّر الاحتساب ⟵ $sourceId '
      '${stockDate.format()} — $error',
    );
  }
}

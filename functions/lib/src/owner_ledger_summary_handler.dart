/// تنفيذ باني الملخصات — **الطرف الذي يلمس الشبكة**.
///
/// ★ **مفصولٌ عن `owner_ledger_summary.dart` عمداً**، بنفس منطق
/// `sack_valuation_handler.dart`: كل قرارٍ هناك في **دوالَّ خالصةٍ تُختبَر
/// بلا سحابة**؛ **وهنا القراءةُ والتجميعُ والالتزام** وحدها.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **ولماذا ليست معاملةً ذرّية — نفسُ تعليل مُحتسِب الجواني حرفياً:**
///
/// ★ **هذه عمليةٌ «مشغَّلة بالكتابة»** (`api-overview.md` §3.2 —
/// `buildDailySummaries`) **لا كتابةُ مستخدم**: ⟵ **و`ADR-0013` القاعدة 1
/// تحكم «المستند وقيدَه»**، ⛔ **وهذه لا مستندَ مستخدمٍ فيها ولا قيد.**
/// ★ **وكلُّ كتابةٍ هنا مُشتقّةُ المعرّف** (`{sourceId}_{date}` · `{sourceId}`)
/// ⟵ **فالتشغيل الجزئي ثم إعادة التشغيل يُكملان الناقص بلا ازدواج ولا
/// تراكم** — ★ **وهو معنى «قابلة للتكرار بلا أثر جانبي»** (§3.3 · `PAT-08`).
///
/// ⛔⛔★★ **والقراءةُ على مرحلتين لا واحدة:** ★ **المستنداتُ المساهِمة
/// تُكتشَف بالاستعلام ثم تُقرأ مستنداتُها المعزولة** (`distributions/{id}/
/// pricing/current` و`sacks/{id}/finance/current` — `ADR-0011`)، ⟵ **و
/// `AuditedTransaction` تقرأ مساراتٍ معروفةً مقدَّماً** ⛔ **فلا تقبل مرحلةً
/// ثانية.**
///
/// ⛔⛔★★★ **وفشلُ هذا الباني لا يُبطل العملية الأصلية** — §3.3 نصّاً —
/// ★ **ويُسجَّل صريحاً**: ⟵ **فالرقم يتأخّر ولا يُفقَد**، ⛔ **وأولُ تشغيلٍ
/// تالٍ على نفس اليوم يُصلحه** لأنه يُعيد البناء بالكامل من الدفاتر.
/// ═══════════════════════════════════════════════════════════════════════
///
/// ⚠️⚠️★★ **وتاريخان لا تاريخٌ واحد** (`GR-49`): ★ **الضمارُ والنقديُّ
/// والضريبةُ على `stockDate`** · ⛔ **والسحبياتُ والخرجيات على `documentDate`**
/// — ⟵ **لأن أثرَهما ماليٌّ لا مخزني** (`design-overview.md` §2.9:
/// «**بتاريخ السند**»)، ★ **وخلطُهما يُدخِل سحبيةَ اليوم في بطاقةِ أمس.**
library;

import 'dart:io' show stdout;

import 'package:qtms_domain/qtms_domain.dart';

import 'firestore_writer.dart';
import 'inventory.dart' show InventoryWrite, documentStatusField;
import 'owner_ledger_summary.dart';

/// ⛔★★ حدُّ مستندات الاستعلام الواحد — **نظيرُ `DEBT-42` في مسار المقبوضات**.
///
/// ⚠️ **وبلوغُه يُسجَّل صراحةً** — ⟵ **فالبترُ الصامت يُنتج ملخّصاً ناقصاً**،
/// ⛔ **وهو رقمٌ يُبنى عليه قرارُ مالك.**
const int ownerLedgerQueryLimit = 500;

/// باني ملخصات ضمار المالك.
final class OwnerLedgerSummaryHandler {
  /// ينشئ الباني — ★ **بتبعيةٍ واحدة تُحقَن، فيُختبَر بلا سحابة**.
  const OwnerLedgerSummaryHandler(this._writer);

  final FirestoreWriter _writer;

  /// ★★★ **يُعيد بناء ملخّص (مصدر × يوم) ثم البطاقة التجميعية والسلسلتين.**
  ///
  /// ★ **ويُرجِع عدد الكتابات** — ⟵ **فالمُستدعي يُسجّله**، ⛔ **ولا يُعلن
  /// نجاحاً بلا رقمٍ يقابله** (بروتوكول التشغيل §و).
  Future<int> buildDay({
    required String sourceId,
    required CalendarDay date,
    required CalendarDay today,
  }) async {
    // ★ **الماضي وحده يُوسَم** — §7 · [planDailySummaryWrite].
    final bool markRetro = date.compareTo(today) < 0;

    final OwnerLedgerContributions contributions =
        await _collectContributions(sourceId: sourceId, date: date);
    final OwnerLedgerSummary summary = computeOwnerLedgerSummary(
      sourceId: sourceId,
      date: date,
      contributions: contributions,
    );

    final List<CommittedWrite> writes = <CommittedWrite>[
      _committed(planDailySummaryWrite(summary, markRetro: markRetro)),
      await _trendWrite(sourceId: sourceId, point: trendPointOf(summary, markRetro: markRetro)),
    ];
    await _writer.commitWrites(writes);

    // ⛔★★ **والتجميعيةُ بعد الالتزام لا قبله** — ⟵ **فاستعلامُها يقرأ ملخّصَ
    //    هذا المصدر المكتوبَ للتوّ**: ★ **القاعدة متسقةٌ قراءةً بعد الكتابة**،
    //    ⛔ **وبناؤها قبله كان يُنتج تجميعيةً متأخّرةً بدورةٍ كاملة**
    //    (نفسُ درس `_rebuildBalances` في `sack_valuation_handler.dart`).
    final int aggregated = await _rebuildAllSourcesCard(
      date: date,
      markRetro: markRetro,
    );
    return writes.length + aggregated;
  }

  // ═════════════════════════════════════════════════════════════════════
  // ★★★ التجميع من الدفاتر — ⛔ **ولا رقمَ يُقرأ من ملخّصٍ سابق**
  // ═════════════════════════════════════════════════════════════════════

  Future<OwnerLedgerContributions> _collectContributions({
    required String sourceId,
    required CalendarDay date,
  }) async {
    final DateTime stamp = date.asUtcMidnight();

    final List<StoredDocument> distributions = await _query(
      distributionsCollection,
      <String, Object?>{'sourceId': sourceId, 'stockDate': stamp},
    );
    final List<StoredDocument> cashSales = await _query(
      cashSalesCollection,
      <String, Object?>{'sourceId': sourceId, 'stockDate': stamp},
    );
    final List<StoredDocument> sacks = await _query(
      sacksCollection,
      <String, Object?>{'sourceId': sourceId, 'stockDate': stamp},
    );
    // ⑥ ★★★ **وبتاريخ السند** — `GR-49` · `design-overview.md` §2.9.
    final List<StoredDocument> outflows = await _query(
      outflowsCollection,
      <String, Object?>{'sourceId': sourceId, 'documentDate': stamp},
    );

    final _Settlements settlements = await _readSettlements(distributions);
    final Money tax = await _readSackTax(sacks);
    Money withdrawals = Money.zero;
    Money expenses = Money.zero;
    for (final StoredDocument outflow in outflows) {
      if (_isCancelled(outflow.fields)) continue;
      final Money amount = _money(outflow.fields['grandTotal']);
      if (outflow.fields['ledgerType'] == OutflowLedgerType.withdrawal.name) {
        withdrawals = withdrawals + amount;
      } else if (outflow.fields['ledgerType'] ==
          OutflowLedgerType.expense.name) {
        expenses = expenses + amount;
      }
      // ⛔ **وسجلٌّ مجهولٌ لا يدخل أيَّ بند** — ★ **فالبندان محكومان بصلاحيتين
      //    مختلفتين** (`GR-43`)، ⟵ **وإسنادُه لأحدهما تخمينٌ يُفسد رقماً.**
    }

    Money cash = Money.zero;
    for (final StoredDocument sale in cashSales) {
      if (_isCancelled(sale.fields)) continue;
      cash = cash + _money(sale.fields['netCashReceived']);
    }

    return OwnerLedgerContributions(
      credit: settlements.debtValue,
      cash: cash,
      settledOfDay: settlements.settled,
      discounts: settlements.discounted,
      tax: tax,
      withdrawals: withdrawals,
      expenses: expenses,
    );
  }

  /// ★★ يقرأ تسعيرَ كلِّ توزيعةٍ **في نداءٍ واحد** — `ADR-0011`.
  ///
  /// ⛔⛔★★ **والمبالغُ الثلاثة في `pricing/current` لا في الأب** (`IQ-027`
  /// الخيار أ) — ⟵ **فقراءةُ الأب وحده كانت تُنتج ملخّصاً بأصفارٍ صامتة.**
  Future<_Settlements> _readSettlements(List<StoredDocument> documents) async {
    final Map<String, String> paths = <String, String>{
      for (final StoredDocument document in documents)
        // ⛔ **والملغاة لا تدخل الجمع** (`A-14` · `GR-06`).
        if (!_isCancelled(document.fields))
          document.id: _writer.documentPath(
            '$distributionsCollection/${document.id}/'
            '$distributionPricingSubcollection',
            distributionPricingDocumentId,
          ),
    };
    if (paths.isEmpty) return const _Settlements();
    final Map<String, Map<String, Object?>?> reads =
        await _writer.readDocuments(paths.values);

    Money debtValue = Money.zero;
    Money settled = Money.zero;
    Money discounted = Money.zero;
    for (final String path in paths.values) {
      final Map<String, Object?>? pricing = reads[path];
      if (pricing == null) continue;
      debtValue = debtValue + _money(pricing['debtValue']);
      settled = settled + _money(pricing['settledAmount']);
      discounted = discounted + _money(pricing['discountedAmount']);
    }
    return _Settlements(
      debtValue: debtValue,
      settled: settled,
      discounted: discounted,
    );
  }

  /// ★ يقرأ ضريبةَ كلِّ جونيةٍ في اليوم — `FR-M15-08`.
  Future<Money> _readSackTax(List<StoredDocument> sacks) async {
    final List<String> paths = <String>[
      for (final StoredDocument sack in sacks)
        if (!_isCancelled(sack.fields))
          _writer.documentPath(
            '$sacksCollection/${sack.id}/$sackFinanceSubcollection',
            sackFinanceDocumentId,
          ),
    ];
    if (paths.isEmpty) return Money.zero;
    final Map<String, Map<String, Object?>?> reads =
        await _writer.readDocuments(paths);
    Money tax = Money.zero;
    for (final String path in paths) {
      tax = tax + _money(reads[path]?['sackTax']);
    }
    return tax;
  }

  // ═════════════════════════════════════════════════════════════════════
  // ★★ البطاقة التجميعية — **مجموعُ بطاقات المصادر عرضاً فقط** (`FR-M15-02`)
  // ═════════════════════════════════════════════════════════════════════

  /// ⛔⛔★★ **وتُبنى من ملخصات المصادر لا من الدفاتر ثانيةً** — ⟵ **فجمعُها
  /// من الدفاتر كان مصدرَ حقيقةٍ ثانياً يفترق عن المصادر في أول حالةٍ حدّية**،
  /// ★ **واختبارُ التوازن يفرض التطابق** (§11).
  Future<int> _rebuildAllSourcesCard({
    required CalendarDay date,
    required bool markRetro,
  }) async {
    final List<StoredDocument> stored = await _query(
      dailySummariesCollection,
      <String, Object?>{'date': date.asUtcMidnight()},
    );
    final List<OwnerLedgerSummary> sources = <OwnerLedgerSummary>[
      for (final StoredDocument document in stored)
        // ⛔⛔ **والتجميعيةُ نفسُها لا تدخل جمعَها** — ⟵ **وإلا تضاعف الرقمُ
        //    في كل بناء**: ★ **وهو بالضبط ما يمنعه `PAT-08`.**
        if (document.fields['sourceId'] != allSourcesScopeId)
          if (readDailySummary(document.fields) case final OwnerLedgerSummary s)
            s,
    ];
    final OwnerLedgerSummary all = aggregateOwnerLedgerSummaries(
      date: date,
      summaries: sources,
    );
    final List<CommittedWrite> writes = <CommittedWrite>[
      _committed(planDailySummaryWrite(all, markRetro: markRetro)),
      await _trendWrite(
        sourceId: allSourcesScopeId,
        point: trendPointOf(all, markRetro: markRetro),
      ),
    ];
    await _writer.commitWrites(writes);
    return writes.length;
  }

  // ═════════════════════════════════════════════════════════════════════
  // ✅★★ السلسلة — **تُحدَّث في نفس الحدث** (§2.1 القاعدة 1)
  // ═════════════════════════════════════════════════════════════════════

  Future<CommittedWrite> _trendWrite({
    required String sourceId,
    required OwnerLedgerTrendPoint point,
  }) async {
    final Map<String, Object?>? stored = await _writer.readDocument(
      collectionId: ownerLedgerTrendsCollection,
      documentId: ownerLedgerTrendId(sourceId),
    );
    return _committed(
      planOwnerLedgerTrendWrite(
        sourceId: sourceId,
        points: appendOwnerLedgerTrendPoint(
          readOwnerLedgerTrendPoints(stored),
          point,
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════
  // القراءة الآمنة — ⛔ **والمجهول يُقرأ غياباً لا قيمةً مخترَعة**
  // ═════════════════════════════════════════════════════════════════════

  Future<List<StoredDocument>> _query(
    String collectionId,
    Map<String, Object?> equals,
  ) async {
    final List<StoredDocument> rows = await _writer.queryDocuments(
      collectionId: collectionId,
      equals: equals,
      limit: ownerLedgerQueryLimit,
    );
    if (rows.length >= ownerLedgerQueryLimit) {
      // ⛔⛔ **ولا يُبتَر بصمت** — ★ **الرقمُ الناقص أخطرُ من غيابه.**
      stdout.writeln(
        'buildDailySummaries: ⚠️ بلغ الحدَّ $ownerLedgerQueryLimit '
        'في $collectionId — الملخّص قد يكون ناقصاً',
      );
    }
    return rows;
  }

  static bool _isCancelled(Map<String, Object?> fields) =>
      fields[documentStatusField] == 'cancelled' ||
      fields['isCancelled'] == true;

  static CommittedWrite _committed(InventoryWrite write) => CommittedWrite(
        collectionId: write.collectionId,
        documentId: write.documentId,
        fields: write.fields,
        updateMask: write.updateMask,
        serverTimestampFields: write.serverTimestampFields,
      );

  static Money _money(Object? raw) => switch (raw) {
        final int value => Money(value),
        final double value when value == value.roundToDouble() =>
          Money(value.toInt()),
        _ => Money.zero,
      };
}

/// مجاميعُ التسوية المقروءةُ من مستندات التسعير.
final class _Settlements {
  const _Settlements({
    this.debtValue = Money.zero,
    this.settled = Money.zero,
    this.discounted = Money.zero,
  });

  final Money debtValue;
  final Money settled;
  final Money discounted;
}

/// ★★★ **يُطلق الباني بعد التزام العملية الأصلية** — ⛔ **ولا يُبطلها**.
///
/// ⚠️⚠️ **وهذا نصّ `api-overview.md` §3.3 حرفياً:** «**فشل عملية مشغَّلة لا
/// يُبطل الأصلية**» — ★ **والاستثناء الوحيد قيدُ التدقيق** (`BR-M18-03`)،
/// ⛔ **وهذا ليس قيداً.**
///
/// ★ **ويقبل أزواجاً لا زوجاً واحداً** — ⟵ **فسندُ قبضٍ واحد قد يُسدِّد
/// ضماراتِ أيامٍ عدة في مصادرَ عدة** (`FR-M12-04`)، ★ **وكلُّ (مصدر × يوم)
/// منها بطاقةٌ مستقلة** ⛔ **ولا يُبنى أحدها ويُترَك الباقي.**
Future<void> buildDailySummariesAfterCommit(
  OwnerLedgerSummaryHandler? handler, {
  required Set<OwnerLedgerDay> days,
  required CalendarDay today,
}) async {
  if (handler == null || days.isEmpty) return;
  for (final OwnerLedgerDay day in days) {
    try {
      final int written = await handler.buildDay(
        sourceId: day.sourceId,
        date: day.date,
        today: today,
      );
      stdout.writeln(
        'buildDailySummaries: ${day.sourceId} ⟵ ${day.date.format()} '
        '— $written كتابة',
      );
    } on Object catch (error) {
      // ⛔ **ولا يُبتلَع صامتاً** — `coding-standards.md` §2.5 القاعدة 1:
      //    ★ **يُبلَّغ في السجل**، ⟵ **والعملية الأصلية ملتزمةٌ سلفاً.**
      stdout.writeln(
        'buildDailySummaries: ⛔ تعذّر البناء ⟵ ${day.sourceId} '
        '${day.date.format()} — $error',
      );
    }
  }
}

/// ★ (مصدر × يوم) — ★ **وحدةُ البطاقة** (`FR-M15-02` · `GR-20`).
///
/// ⚠️ **ونوعُ قيمةٍ بمساواةٍ بنيوية** — ⟵ **فمجموعةٌ منه تُسقِط التكرار**:
/// ★ **وسندٌ يمسّ ثلاثةَ ضماراتٍ في يومٍ واحد يبني بطاقتَه مرةً لا ثلاثاً.**
final class OwnerLedgerDay {
  /// ينشئ الزوج.
  const OwnerLedgerDay({required this.sourceId, required this.date});

  /// المصدر.
  final String sourceId;

  /// اليوم.
  final CalendarDay date;

  @override
  bool operator ==(Object other) =>
      other is OwnerLedgerDay &&
      other.sourceId == sourceId &&
      other.date == date;

  @override
  int get hashCode => Object.hash(sourceId, date);
}

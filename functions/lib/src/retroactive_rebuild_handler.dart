/// تنفيذ إعادة البناء بأثر رجعي — **الطرف الذي يلمس الشبكة** (`WU-021`).
///
/// ★ **مفصولٌ عن `retroactive_rebuild.dart` عمداً**، بنفس منطق
/// `owner_bootstrap_handler.dart`: **كلُّ قرارِ تفويضٍ هناك في دوالَّ خالصةٍ
/// تُختبَر بلا سحابة**؛ ⛔ **وهنا القراءةُ والترتيبُ والالتزام وحدها.**
///
/// ═══════════════════════════════════════════════════════════════════════
/// ★★★ **وترتيبُ الأثر ثلاثيٌّ ولا يُعكَس** — ⟵ **وهو ترتيبُ المعالِجات
/// السِّتّة نفسُه حرفياً** (`cash_sale_handler.dart` §بعد الالتزام):
///
///   ① **`recomputeSackRevenue`** ([SackValuationHandler.revalueDay]) —
///      سعرُ الجونية وصافي الرعوي (`FR-M14-05`).
///   ② **`buildDailySummaries`** ([OwnerLedgerSummaryHandler.buildDay]) —
///      بطاقةُ (مصدر × يوم) والتجميعيةُ والسلسلة، ★ **مَوْسومةً «⟳» متى كان
///      اليومُ ماضياً** (`FR-M8-15` · `FR-M15-12` · `FR-SYS-24` · `GR-17`).
///   ③ **مسحةُ المتبقي المتأخر** — [`DEBT-96`].
///
/// ⛔⛔★★ **والعكسُ يُنتج بطاقةً بسعرِ جونيةٍ قديم:** ★ **الملخّصُ يقرأ
/// `sacks/{id}/finance/current`** ⟵ **فبناؤه قبل الاحتساب يقرأ رقمَ الأمس**
/// (نفسُ درس `_rebuildAllSourcesCard` في `owner_ledger_summary_handler.dart`).
///
/// ⛔⛔★★★ **وفشلُ خطوةٍ لا يُسقِط ما قبلها ولا ما بعدها** — `api-overview.md`
/// §3.3: ★ **ويُسجَّل صريحاً برقمِه** (بروتوكول التشغيل §و)، ⟵ **فالمشغّلُ
/// يرى أيُّ مصدرٍ تعثّر** ⛔ **ولا يُعلَن نجاحٌ شاملٌ فوق فشلٍ جزئي.**
/// ═══════════════════════════════════════════════════════════════════════
///
/// ⚠️⚠️★★ **ووحدةُ الاستدعاء يومٌ واحد — ⛔ لا مدىً:** ★ **وهو نصُّ اسمِها**
/// (`rebuildDayRetroactively`) **ونصُّ `api-overview.md` §3.2** («**إعادة بناء
/// ملخص اليوم الأصلي**»). ⟵ **والمدى يدور في أداةِ التشغيل**
/// (`tools/staging/rebuild_day_retroactively.py`) ⛔ **لا في الحاوية**:
/// ★ **فلا عتبةُ مدىً تُخترَع بلا مستند** (`implementation-playbook.md` §5)،
/// ★ **ولا استدعاءٌ واحدٌ يبتلع مهلةَ الطلب في مدىً طويل.**
library;

import 'dart:io' show stdout;

import 'package:qtms_domain/qtms_domain.dart';
import 'package:shelf/shelf.dart';

import 'aged_remainder.dart';
import 'audited_transaction.dart' show PendingDocument;
import 'callable.dart';
import 'firestore_writer.dart';
import 'identity_gateway.dart';
import 'owner_ledger_summary_handler.dart';
import 'retroactive_rebuild.dart';
import 'sack_valuation_handler.dart';
// ★ لأجل `requestIdField` وحده — اسم الحقل يُكتب مرة واحدة فلا تفترق نسختان.
import 'permission_sync_handler.dart';

/// ★ حقلُ اليوم المستهدَف في الحمولة — **`YYYYMMDD`**.
const String rebuildDateField = 'date';

/// ★ حقلُ المصادر المستهدَفة — **وغيابُه يعني كلَّ المصادر**.
const String rebuildSourceIdsField = 'sourceIds';

/// منفّذ إعادة البناء بأثر رجعي.
final class RetroactiveRebuildHandler {
  /// ينشئ المنفّذ بتبعياته — ★ **تُحقَن، فيُختبَر بلا سحابة**.
  const RetroactiveRebuildHandler({
    required IdentityGateway identity,
    required FirestoreWriter store,
    required SackValuationHandler valuation,
    required OwnerLedgerSummaryHandler summaries,
    required String registeredOwnerUserId,
  })  : _identity = identity,
        _store = store,
        _valuation = valuation,
        _summaries = summaries,
        _registeredOwnerUserId = registeredOwnerUserId;

  final IdentityGateway _identity;
  final FirestoreWriter _store;
  final SackValuationHandler _valuation;
  final OwnerLedgerSummaryHandler _summaries;

  /// ★ **من إعداد البيئة لا من الحمولة** — راجع [RetroactiveRebuildRequest].
  final String _registeredOwnerUserId;

  /// ينفّذ إعادة البناء على طلب HTTP خام.
  Future<Response> handle(Request httpRequest) async {
    final CallableParse parsed = await parseCallableRequest(httpRequest);
    if (parsed is RejectedCallable) return callableFailure(parsed.error);
    final CallableRequest call = (parsed as ParsedCallable).request;

    try {
      return await _execute(call);
    } on IdentityGatewayException catch (error) {
      return callableFailure(
        _mapIdentityFailure(error),
        detail: error.diagnostic,
      );
    }
  }

  Future<Response> _execute(CallableRequest call) async {
    final AccountRecord actor = await _identity.verifyIdToken(call.idToken);

    // ★★★ **ساعةُ المنصّة تُقاس قبل التخطيط** — `GR-54`: ⟵ **والدالةُ الخالصة
    //    تحكم عليها** ⛔ **ولا تقيسها بنفسها** (فتبقى خالصةً تُختبَر).
    final DateTime? stamp =
        await _store.readPlatformTime(collectionId: sourcesCollection);

    final RetroactiveRebuildPlan plan = planRetroactiveRebuild(
      RetroactiveRebuildRequest(
        actor: actor,
        registeredOwnerUserId: _registeredOwnerUserId,
        requestId: call.readString(requestIdField) ?? '',
        date: call.readString(rebuildDateField) ?? '',
        platformToday: stamp == null ? null : CalendarDay.fromUtc(stamp),
        sourceIds: call.readStringList(rebuildSourceIdsField),
      ),
    );

    return switch (plan) {
      RetroactiveRebuildRejected(:final CallableError error) =>
        callableFailure(error),
      RetroactiveRebuildAccepted() => await _apply(
          plan,
          requestId: call.readString(requestIdField) ?? '',
        ),
    };
  }

  /// يُعيد البناء لكل مصدرٍ على حدة — ★ **ويُرجِع أرقاماً مقيسة لا ادّعاءً**.
  Future<Response> _apply(
    RetroactiveRebuildAccepted plan, {
    required String requestId,
  }) async {
    final List<String> sources =
        plan.sourceIds ?? await _store.listDocumentIds(sourcesCollection);

    int revalued = 0;
    int summaryWrites = 0;
    int agedWritten = 0;
    final List<String> failed = <String>[];

    for (final String sourceId in sources) {
      try {
        // ① سعرُ الجونية أولاً — راجع ترويسة الملف.
        revalued += await _valuation.revalueDay(
          sourceId: sourceId,
          stockDate: plan.date,
        );
        // ② ثم البطاقة — ★ **و«اليوم» يومُ المنصّة** فيصدُق `markRetro`.
        summaryWrites += await _summaries.buildDay(
          sourceId: sourceId,
          date: plan.date,
          today: plan.today,
        );
        // ③ ثم مسحةُ المتبقي المتأخر — [`DEBT-96`].
        agedWritten += await _sweepAgedRemainders(
          sourceId: sourceId,
          date: plan.date,
        );
      } on Object catch (error) {
        // ⛔ **ولا يُبتلَع صامتاً** — `coding-standards.md` §2.5 القاعدة 1:
        //    ★ **يُسجَّل باسم مصدره**، ⟵ **وبقيةُ المصادر تُبنى.**
        failed.add(sourceId);
        stdout.writeln(
          'rebuildDayRetroactively: ⛔ تعثّر $sourceId ⟵ '
          '${plan.date.format()} — $error',
        );
      }
    }

    stdout.writeln(
      'rebuildDayRetroactively: $requestId ⟵ ${plan.date.format()} — '
      '${sources.length} مصدراً · $revalued جونية · $summaryWrites كتابة ملخّص '
      '· $agedWritten بند متبقٍّ · ${failed.length} متعثّراً',
    );

    return callableSuccess(<String, Object?>{
      'date': plan.date.format(),
      'retroactive': plan.date.compareTo(plan.today) < 0,
      'sources': sources.length,
      'revaluedSacks': revalued,
      'summaryWrites': summaryWrites,
      'agedRemaindersWritten': agedWritten,
      // ⛔★★ **والمتعثّرُ يُعلَن بأسمائه** — ⟵ **فنجاحٌ جزئيٌّ يُقرأ جزئياً**،
      //    ⛔ **ولا يُخفى تحت رمزِ نجاحٍ واحدٍ مبهم.**
      'failedSources': failed,
    });
  }

  /// ★★★ مسحةُ المتبقي المتأخر ليومٍ ومصدر — **علاج [`DEBT-96`]**.
  ///
  /// ⛔⛔★★★ **وتكتب الموجبَ ولا تحذف شيئاً — والفارقُ ليس سهواً:**
  /// ★ **البندُ يُمحى في معاملة كتابة الرصيد نفسِها متى بلغ صفراً**
  /// (`agedRemaindersFromBalanceWrites`) — ⟵ **فبندٌ زائدٌ لا يمكن أن يبقى
  /// أصلاً**، ★ **والنقصُ وحده هو ما خلّفه الدَّين**: بنودٌ لرصيدٍ موجبٍ
  /// كُتب **قبل نشرِ الراصد** فلم يُلمَس بعده. ⛔ **فالمسحةُ تسدّ النقص**،
  /// ⛔ **ولا تُفتَح بها بوابةُ حذفٍ ثانية** (`PendingDeletion` §التحذير).
  Future<int> _sweepAgedRemainders({
    required String sourceId,
    required CalendarDay date,
  }) async {
    final List<StoredDocument> balances = await _store.queryDocuments(
      collectionId: itemDailyBalancesCollection,
      equals: <String, Object?>{
        'sourceId': sourceId,
        // ★★ **تاريخ المخزون لا تاريخ الإدخال** — `RISK-07`.
        'stockDate': date.asUtcMidnight(),
      },
      limit: ownerLedgerQueryLimit,
    );
    if (balances.isEmpty) return 0;

    final AgedRemainderSet set = agedRemaindersFromStoredBalances(balances);
    if (set.documents.isEmpty) return 0;

    await _store.commitWrites(<CommittedWrite>[
      for (final PendingDocument document in set.documents)
        CommittedWrite(
          collectionId: document.collectionId,
          documentId: document.documentId,
          fields: document.fields,
          // ★ **والقناعُ حاضرٌ دائماً من بانيها** — ⛔ **والاحتياطُ حقولُها
          //    نفسُها لا استبدالٌ كامل**: ⟵ **فلا يُمحى حقلٌ لم يُذكَر.**
          updateMask: document.updateMask ?? document.fields.keys.toList(),
          serverTimestampFields: document.serverTimestampFields,
        ),
    ]);
    return set.documents.length;
  }

  static CallableError _mapIdentityFailure(IdentityGatewayException error) =>
      switch (error.failure) {
        IdentityFailure.invalidToken => CallableError.sessionExpired,
        IdentityFailure.accountNotFound => CallableError.invalidArgument,
        // ⛔ **ولا مسارَ لهذين هنا** — ★ **وهذه العملية لا تمسّ مطالباتٍ ولا
        //    تُنشئ حساباً**: ⟵ **ومذكوران صراحةً ⛔ لا بنمطٍ شامل (`_`)**،
        //    ★ **فالتصريف يُنبِّه عند أي تصنيفٍ يُضاف غداً** (نصّ
        //    `owner_bootstrap_handler.dart` حرفياً).
        IdentityFailure.claimsTooLarge => CallableError.internal,
        IdentityFailure.emailAlreadyExists => CallableError.internal,
      };
}

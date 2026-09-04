/// دليل المقبوضات والضمارات المفتوحة — **قراءةً فقط** (`ADR-0013` القاعدة 4).
///
/// ⛔★★ **ولا كتابة واحدة هنا:** `receipts` و`deposit/current` و
/// `dealer_surplus` **كلها `allow create, update: if false`** — **والكتابة
/// عبر العمليات المستدعاة** (`functions_receipt_repository.dart`).
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **وتدفّقان منفصلان للسند — وهذا جوهر [`ADR-0017`]:**
///
///   `watchReceipts`        ← **الأب**: يقرؤه كل مصادَق.
///   `watchReceiptDeposit`  ← 🔒 **حالة الإيداع**: بـ`receiptDepositView`.
///
/// ⟵ **ودمجُهما في قراءةٍ واحدة كان سيجعل `FR-M12-16` إخفاءَ واجهة لا
/// حماية**: ★ **الرفض يأتي من القاعدة نفسها** فيسقط تدفّقُ الإيداع وحده،
/// ⛔ **ولا يُسقِط الشاشة كلها.**
/// ═══════════════════════════════════════════════════════════════════════
///
/// ⛔⛔★★★ **وكلُّ استعلامٍ يُقيّد الحقلَ الذي يعتمده شرطُ قراءته** —
/// **مقيسٌ ثلاث مرات في هذا المشروع** (`IQ-024` · `WU-008` · `DEBT-40`):
/// ⟵ **الشرط يُقيَّم على قيود الاستعلام لا على كل مستند**، ⛔ **فاستعلامٌ
/// لا يُقيّده يُرفَض كاملاً ولو بنطاقٍ شامل.**
library;

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qtms_domain/qtms_domain.dart';

/// الدليل الحقيقي.
final class FirestoreReceiptDirectory implements ReceiptDirectory {
  /// ينشئ الدليل.
  const FirestoreReceiptDirectory(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Stream<List<OpenDebtLot>> watchOpenDebtLots({
    required String dealerId,
    required List<String> sourceIds,
  }) {
    if (sourceIds.isEmpty) {
      return Stream<List<OpenDebtLot>>.value(const <OpenDebtLot>[]);
    }
    // ⛔⛔★★★ **استعلامٌ لكل مصدرٍ على حدة ⛔ لا استعلامٌ واحدٌ بلا `sourceId`:**
    //    ★ **شرطُ القراءة `storedInScope()` يقرأ `resource.data.sourceId`**
    //    ⟵ **واستعلامٌ لا يُقيّده يُرفَض كاملاً ولو بنطاقٍ شامل** (`IQ-024` ·
    //    `WU-008` · `DEBT-40`). ⛔ **والعلاج تقييدُ الحقل وفهرسٌ ببادئته.**
    //
    // ⚠️ **ولا `whereIn` على `sourceId` مع `whereIn` ثانٍ على الحالة** —
    //    ★ **فاجتماعُ فصلين يُضاعف حدود الاستعلام**، ⟵ **والتعديد أوضحُ
    //    وأقربُ للفهرس المركّب.**
    final List<Stream<List<OpenDebtLot>>> streams =
        <Stream<List<OpenDebtLot>>>[
      for (final String sourceId in sourceIds) _lotsOfSource(dealerId, sourceId),
    ];
    return _combineLots(streams);
  }

  Stream<List<OpenDebtLot>> _lotsOfSource(String dealerId, String sourceId) =>
      _firestore
          .collection(distributionsCollection)
          .where('dealerId', isEqualTo: dealerId)
          // ★ **المصدر مُقيَّد صراحةً** — راجع التعليق أعلاه.
          .where('sourceId', isEqualTo: sourceId)
          // ⛔⛔★★★ **والحالة مُقيَّدة كذلك** — ★ **وهي حقلٌ في الأب**
          //    (`IQ-027`) ⟵ **فالفهرس يغطّيها.**
          .where(
            'settlementStatus',
            whereIn: <String>[
              SettlementStatus.open.name,
              SettlementStatus.partiallyOpen.name,
            ],
          )
          .orderBy('stockDate')
          .snapshots()
          .asyncMap((QuerySnapshot<Map<String, dynamic>> snapshot) async {
            final List<OpenDebtLot> lots = <OpenDebtLot>[];
            for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
                in snapshot.docs) {
              final Map<String, dynamic> data = doc.data();
              final String? source = data['sourceId'] as String?;
              final CalendarDay? stockDate = _dayOf(data['stockDate']);
              if (source == null || stockDate == null) continue;
              // ⛔ **والملغاة ليست محلاً للسداد** — `A-14`.
              if (data['status'] == 'cancelled') continue;
              // ⛔⛔★★ **والمتبقي من `pricing/current` لا من الأب** (`IQ-027`)
              //    — ★ **ومن لا يملك `distributionPriceView` يُرفَض فيقرأ
              //    صفراً**، ⟵ **فلا يُعرَض له ضمارٌ يُقبَض منه** ⛔ **وهو
              //    المقصود** (`ت-12`).
              final Money remaining = await _remainingOf(doc.id);
              if (remaining.isZero || remaining.isNegative) continue;
              lots.add(
                OpenDebtLot(
                  debtLotId: doc.id,
                  sourceId: source,
                  stockDate: stockDate,
                  remaining: remaining,
                ),
              );
            }
            return lots;
          });

  /// ★★ يدمج تدفّقات المصادر — ⛔ **ولا يبثّ حتى يصل أولُ خبرٍ من كلٍّ منها.**
  ///
  /// ⚠️ **ومرتَّبةٌ بالأقدم أولاً بعد الدمج** — ⟵ **فترتيب «الأقدم أولاً»
  /// يعبر المصادر** (`FR-M12-13`)، ⛔ **ولا يبقى داخل كل مصدرٍ وحده**،
  /// ★ **والتساوي يُرجَّح بالمعرّف فيثبت الترتيب** (`coding-standards.md` §2.7).
  static Stream<List<OpenDebtLot>> _combineLots(
    List<Stream<List<OpenDebtLot>>> streams,
  ) {
    if (streams.length == 1) {
      return streams.single.map(_sorted);
    }
    final List<List<OpenDebtLot>?> latest =
        List<List<OpenDebtLot>?>.filled(streams.length, null);
    final StreamController<List<OpenDebtLot>> controller =
        StreamController<List<OpenDebtLot>>();
    final List<StreamSubscription<List<OpenDebtLot>>> subscriptions =
        <StreamSubscription<List<OpenDebtLot>>>[];

    controller.onListen = () {
      for (int i = 0; i < streams.length; i++) {
        final int index = i;
        subscriptions.add(
          streams[index].listen(
            (List<OpenDebtLot> value) {
              latest[index] = value;
              if (latest.every((List<OpenDebtLot>? v) => v != null)) {
                controller.add(
                  _sorted(<OpenDebtLot>[
                    for (final List<OpenDebtLot>? v in latest) ...v!,
                  ]),
                );
              }
            },
            // ⛔★★ **ورفضُ مصدرٍ لا يُسقِط البقية** — ★ **يُقرأ فارغاً**:
            //    ⟵ **فمصدرٌ خارج النطاق لا يُعطِّل شاشةَ القبض كلها.**
            onError: (Object _) {
              latest[index] = const <OpenDebtLot>[];
            },
          ),
        );
      }
    };
    controller.onCancel = () async {
      for (final StreamSubscription<List<OpenDebtLot>> sub in subscriptions) {
        await sub.cancel();
      }
    };
    return controller.stream;
  }

  static List<OpenDebtLot> _sorted(List<OpenDebtLot> lots) =>
      <OpenDebtLot>[...lots]..sort((OpenDebtLot a, OpenDebtLot b) {
          final int byDate = a.stockDate.compareTo(b.stockDate);
          return byDate != 0 ? byDate : a.debtLotId.compareTo(b.debtLotId);
        });

  Future<Money> _remainingOf(String distributionId) async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> pricing = await _firestore
          .collection(distributionsCollection)
          .doc(distributionId)
          .collection(distributionPricingSubcollection)
          .doc(distributionPricingDocumentId)
          .get();
      final Map<String, dynamic>? data = pricing.data();
      if (data == null) return Money.zero;
      final int debtValue = _intOf(data['debtValue']) ?? 0;
      final int settled = _intOf(data['settledAmount']) ?? 0;
      final int discounted = _intOf(data['discountedAmount']) ?? 0;
      // ★★ **والمعادلة من طبقة النطاق** — ⛔ **ولا نسخة ثانية منها هنا**
      //    (`ADR-0009` · `coding-standards.md` §2.2).
      return computeDebtSettlement(
        debtValue: Money(debtValue),
        settledAmount: Money(settled),
        discountedAmount: Money(discounted),
      ).remaining;
    } on Object {
      // ⛔★★ **والرفض يُطوى إلى صفر عمداً** — ★ **«لا أرى المبلغ» حالةٌ
      //    طبيعية لا عطل** (`ت-12`)، ⟵ **ورسالةُ خطأٍ عليها كانت ستكشف
      //    وجود ضمارٍ لمن لا يملك رؤية مبلغه.**
      return Money.zero;
    }
  }

  @override
  Stream<List<ReceiptCard>> watchReceipts({
    required String dealerId,
    int limit = 50,
  }) =>
      _firestore
          .collection(receiptsCollection)
          // ★ **الفهرس المعتمد `dealerId ↑ · date ↓`.**
          .where('dealerId', isEqualTo: dealerId)
          .orderBy('date', descending: true)
          .limit(limit)
          .snapshots()
          .map(
            (QuerySnapshot<Map<String, dynamic>> snapshot) => <ReceiptCard>[
              for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
                  in snapshot.docs)
                cardOf(doc.id, doc.data()),
            ],
          );

  @override
  Stream<ReceiptDepositCard?> watchReceiptDeposit({
    required String documentNumber,
  }) =>
      _firestore
          .collection(receiptsCollection)
          .doc(documentNumber)
          .collection(receiptDepositSubcollection)
          .doc(receiptDepositDocumentId)
          .snapshots()
          .map((DocumentSnapshot<Map<String, dynamic>> doc) {
            final Map<String, dynamic>? data = doc.data();
            return data == null ? null : depositOf(data);
          })
          // ⛔⛔★★ **والرفض يُطوى إلى `null` عمداً** — راجع ترويسة الملف.
          .handleError((Object _) {})
          .cast<ReceiptDepositCard?>();

  /// ⛅ الفائض المتاح — **باستعلامٍ مقيَّد** ⛔ **لا بقراءة المعرّف**.
  ///
  /// ═══════════════════════════════════════════════════════════════════
  /// ⛔⛔★★★ **ولماذا استعلامٌ لا `doc(id).snapshots()` — عطلٌ قِيس حيّاً على
  ///    المحاكي (2026-09-04 · `WU-017`):** ★ **شرطُ قراءة `dealer_surplus`
  ///    يعتمد `resource.data.sourceId`** — ⟵ **والمستندُ الغائب بلا
  ///    `resource` أصلاً**: ⟹ ⛔ **فقراءتُه بمعرّفه تُرفَض
  ///    `PERMISSION_DENIED`** ★ **ومقوتٌ بلا فائضٍ في مصدرٍ حالةٌ طبيعية لا
  ///    خطأ.** ⚠️⚠️ **وكان الرفضُ يُطوى صامتاً إلى `null`** ⟵ **فيُقرأ صفراً
  ///    على الشاشة**: ★ **الرقمُ صحيحٌ والمسارُ معطوب**، ⛔ **وهو أخطر ما
  ///    يكون** — ⟵ **يوم يصير الرفضُ حقيقياً لا يُميَّز عن الغياب.**
  ///
  /// ★★ **وهذه القاعدةُ نفسُها المسجَّلة في `WU-016`** ([`DEBT-91`]):
  ///    «**الغائبُ لا يُقرأ بمعرّفه بل باستعلامٍ مقيَّد يُرجِع صفراً**»،
  ///    ⛔ **والعلاجُ تقييدُ الحقل لا تخفيفُ القاعدة.**
  ///
  /// ⚠️ **والتقييدُ يطابق شقَّي الشرط:** ★ **`sourceId == null` لفائضٍ عام**
  ///    (⟵ **فالشقُّ الأول مُثبَت**) · ★ **و`sourceId == <مصدر>` لفائض مصدر**
  ///    (⟵ **فالشقُّ الثاني مُثبَت بالنطاق**) — ⛔ **ولا استعلامَ غيرَ مقيَّد.**
  /// ═══════════════════════════════════════════════════════════════════
  @override
  Stream<Money?> watchAvailableSurplus({
    required String dealerId,
    required SurplusScope scope,
    String? sourceId,
  }) {
    // ⛔ **ويُستدعى المعرّفُ للتحقق من تماسك المدخلات وحده** — ★ **فهو يرمي
    //    على «فائض مصدرٍ بلا مصدر»** (`E-13`): ⟵ **والحارسُ يبقى قائماً.**
    dealerSurplusId(dealerId: dealerId, scope: scope, sourceId: sourceId);
    final Query<Map<String, dynamic>> byDealer = _firestore
        .collection(dealerSurplusCollection)
        .where('dealerId', isEqualTo: dealerId);
    // ⛔⛔★★★ **و`isNull: true` لا `isEqualTo: null` — مقيسٌ على المحاكي:**
    //    ★ **`isEqualTo` معاملٌ اختياريٌّ قيمتُه الافتراضية `null`** —
    //    ⟹ **فتمريرُ `null` إليه يُقرأ «لم يُمرَّر» فيسقط الشرطُ بصمت**:
    //    ⛔ **وخرج الاستعلامُ مقيَّداً بـ`dealerId` وحده فرُفض كاملاً**
    //    (`dealer_surplus where dealerId==… ⟵ PERMISSION_DENIED`).
    //    ⚠️ **ولم يُخفِق البناءُ ولا التحليلُ ولا اختبارٌ واحد** — ★ **كشفه
    //    `adb logcat` وحدَه** (بروتوكول التشغيل §د).
    return (scope == SurplusScope.source
            ? byDealer.where('sourceId', isEqualTo: sourceId)
            : byDealer.where('sourceId', isNull: true))
        .limit(1)
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> snapshot) {
          if (snapshot.docs.isEmpty) return null;
          final Map<String, dynamic> data = snapshot.docs.first.data();
          // ⛅ **وهو مشتقٌّ يحمل «المتاح» مباشرةً** (`data-dictionary.md` §4)
          //    — ⛔ **ولا يُجمَع من مدفوعٍ ومُطبَّق هنا** (`ADR-0008`).
          final int? available = _intOf(data['availableAmount']);
          return available == null ? null : Money(available);
        })
        .handleError((Object _) {})
        .cast<Money?>();
  }

  // ═════════════════════════════════════════════════════════════════════
  // التحويل — ⛔ **والمجهول يُقرأ بالافتراض الآمن لا يُسقِط الشاشة**
  // ═════════════════════════════════════════════════════════════════════

  /// ★ يحوّل مستند سندِ قبضٍ خاماً إلى بطاقته.
  ///
  /// ★★ **ومكشوفٌ لأن `FirestoreReportDirectory` يقرأ المجموعةَ نفسَها**
  /// (`R-14` — `WU-011`) — ⛔ **ونسخةٌ ثانية تفترق عند أول حقل.**
  static ReceiptCard cardOf(String id, Map<String, dynamic> data) {
    final Object? rawLines = data['lines'];
    final List<ReceiptCardLine> lines = <ReceiptCardLine>[
      if (rawLines is List<dynamic>)
        for (final Object? entry in rawLines)
          if (entry is Map<String, dynamic>)
            if (entry['debtLotId'] case final String lotId)
              ReceiptCardLine(
                debtLotId: lotId,
                sourceId: entry['sourceId'] as String? ?? '',
                remainingBefore: Money(_intOf(entry['remainingBefore']) ?? 0),
                amount: Money(_intOf(entry['amount']) ?? 0),
                remainingAfter: Money(_intOf(entry['remainingAfter']) ?? 0),
                note: entry['note'] as String?,
              ),
    ];
    final Object? rawSources = data['affectedSourceIds'];
    return ReceiptCard(
      documentNumber: data['documentNumber'] as String? ?? id,
      date: _dayOf(data['date']) ?? CalendarDay(1970, 1, 1),
      dealerId: data['dealerId'] as String? ?? '',
      dealerName: data['dealerName'] as String? ?? '',
      sourceFilter: data['sourceFilter'] as String?,
      affectedSourceIds: <String>[
        if (rawSources is List<dynamic>)
          for (final Object? source in rawSources)
            if (source is String) source,
      ],
      lines: lines,
      surplusAmount: Money(_intOf(data['surplusAmount']) ?? 0),
      surplusScope: data['surplusScope'] == SurplusScope.source.name
          ? SurplusScope.source
          : SurplusScope.general,
      totalDebtAtEntry: Money(_intOf(data['totalDebtAtEntry']) ?? 0),
      usedAutoAllocation: data['usedAutoAllocation'] == true,
      // ⛔ **والملغى صراحةً وحده ملغى** — ★ **والافتراض الآمن «سندٌ حيّ»**:
      //   ⟵ **قراءةُ سندٍ حيٍّ ملغىً كانت تُخفي مبلغاً مقبوضاً.**
      isCancelled: data['status'] == 'cancelled',
      cancelReason: data['cancelReason'] as String?,
      amendCount: _intOf(data['amendCount']) ?? 0,
    );
  }

  /// 🔒 يحوّل مستند حالةِ الإيداع — ⛔ **ولا يصل إلا من يملك
  /// `receiptDepositView`** (`ADR-0017`).
  ///
  /// ★★ **ومكشوفٌ لعمود الإيداع في `R-14`** (`WU-011`).
  static ReceiptDepositCard depositOf(Map<String, dynamic> data) =>
      ReceiptDepositCard(
        // ★ **والافتراض «لم يُودع»** — `schema/receipts.md`: **تبدأ كذلك**.
        state: data['isDeposited'] == true
            ? DepositState.deposited
            : DepositState.notDeposited,
        note: data['depositNote'] as String?,
        depositedBy: data['depositedBy'] as String?,
        depositedAt: (data['depositedAt'] as Timestamp?)?.toDate(),
      );

  static CalendarDay? _dayOf(Object? raw) {
    if (raw is Timestamp) return CalendarDay.fromUtc(raw.toDate().toUtc());
    if (raw is DateTime) return CalendarDay.fromUtc(raw.toUtc());
    return null;
  }

  static int? _intOf(Object? raw) {
    if (raw is int) return raw;
    if (raw is num && raw == raw.roundToDouble()) return raw.toInt();
    return null;
  }
}

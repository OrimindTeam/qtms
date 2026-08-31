/// دليل المخزون — **قراءةً فقط** (`ADR-0013` القاعدة 4).
///
/// ⛔★★ **ولا كتابة واحدة هنا:** `incoming_count` · `inventory_ledger` ·
/// `item_daily_balances` **كلها مغلقة في القواعد** — **والكتابة عبر
/// العمليات المستدعاة** (`functions_inventory_repository.dart`).
///
/// ⚠️⚠️ **وكل استعلام على `stockDate` لا `entryDate`** — `coding-standards.md`
/// §5 البند 6 يجعل العكس **رفضاً تلقائياً في المراجعة**، ★ **و`RISK-07`
/// يُفسِّر لماذا:** التاريخان متساويان في 99٪ من الحالات ⟵ **فالخطأ لا يظهر
/// إلا في التصريف المتأخر، وقد أنتج تقارير خاطئة بصمت.**
///
/// ⚠️ **والرفض يصل كخطأ في التدفّق لا كقائمة فارغة** — ⟵ ★ **فتُميِّز
/// الشاشة بين «لا مخزون اليوم» و«ممنوعٌ من الرؤية»**.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qtms_domain/qtms_domain.dart';

/// الدليل الحقيقي.
final class FirestoreInventoryDirectory implements InventoryDirectory {
  /// ينشئ الدليل.
  const FirestoreInventoryDirectory(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Stream<List<ItemDailyBalanceCard>> watchTodayStock({
    required String sourceId,
    required CalendarDay stockDate,
  }) =>
      _firestore
          .collection(itemDailyBalancesCollection)
          .where('sourceId', isEqualTo: sourceId)
          // ★★ **تاريخ المخزون** — راجع ترويسة الملف.
          .where('stockDate', isEqualTo: Timestamp.fromDate(stockDate.asUtcMidnight()))
          // ★ الفهرس القائم: `sourceId ↑ · stockDate ↑ · itemKey ↑`.
          .orderBy('itemKey')
          .snapshots()
          .map(
            (QuerySnapshot<Map<String, dynamic>> snapshot) =>
                <ItemDailyBalanceCard>[
              for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
                  in snapshot.docs)
                balanceOf(doc.data(), stockDate),
            ],
          );

  @override
  Stream<List<StockMovementCard>> watchItemMovements({
    required String sourceId,
    required String itemKey,
    required CalendarDay stockDate,
  }) =>
      _firestore
          .collection(inventoryLedgerCollection)
          .where('sourceId', isEqualTo: sourceId)
          .where('itemKey', isEqualTo: itemKey)
          .where('stockDate', isEqualTo: Timestamp.fromDate(stockDate.asUtcMidnight()))
          .snapshots()
          .map((QuerySnapshot<Map<String, dynamic>> snapshot) {
            final List<StockMovementCard> cards = <StockMovementCard>[
              for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
                  in snapshot.docs)
                movementOf(doc.id, doc.data()),
            ];
            // ★ **مرتَّبةً زمنياً** — `FR-M8-06`. ⚠️ **والترتيب هنا لا في
            //   الاستعلام** لأن `entryDate` **لا يُفهرَس عمداً**
            //   (`schema/inventory-ledger.md`: «الفهرسة عليه تُغري ببناء
            //   تقرير خاطئ»)؛ ⟵ **والمجموعة يومٌ واحد لنوعٍ واحد فصغيرة.**
            cards.sort(
              (StockMovementCard a, StockMovementCard b) =>
                  a.entryDate.compareTo(b.entryDate),
            );
            return cards;
          });

  @override
  Stream<List<CountedIntakeCard>> watchCountedIntakes({
    required String sourceId,
    required CalendarDay stockDate,
  }) =>
      _firestore
          .collection(incomingCountCollection)
          .where('sourceId', isEqualTo: sourceId)
          .where('stockDate', isEqualTo: Timestamp.fromDate(stockDate.asUtcMidnight()))
          .snapshots()
          .map((QuerySnapshot<Map<String, dynamic>> snapshot) {
            final List<CountedIntakeCard> cards = <CountedIntakeCard>[
              for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
                  in snapshot.docs)
                intakeOf(doc.id, doc.data(), stockDate),
            ];
            // ★ الأحدث أولاً — ⛔ **بالرقم لا بتاريخ الإدخال**: الرقم
            //   **متسلسل داخل اليوم** فترتيبه ترتيبُ الإنشاء بلا فهرس.
            cards.sort(
              (CountedIntakeCard a, CountedIntakeCard b) =>
                  b.documentNumber.compareTo(a.documentNumber),
            );
            return cards;
          });

  // ═════════════════════════════════════════════════════════════════════
  // التحويل — ⛔ **والمجهول يُقرأ بالافتراض الآمن لا يُسقِط الشاشة**
  // ═════════════════════════════════════════════════════════════════════

  /// ★ يحوّل مستند رصيدٍ يوميٍّ خاماً إلى بطاقته.
  ///
  /// ★★ **ومكشوفٌ لأن `FirestoreReportDirectory` يقرأ المجموعةَ نفسَها**
  /// (`R-02` · `R-05` — `WU-011`): ⟵ **ونسخةٌ ثانية من التحويل تفترق عن
  /// هذه عند أول حقلٍ يُضاف** ⛔ **وهو حرفياً ما يمنعه `coding-standards.md`
  /// §2.2** (مصدر حقيقة واحد).
  static ItemDailyBalanceCard balanceOf(
    Map<String, dynamic> data,
    CalendarDay fallbackDay,
  ) {
    final ItemUnit unit = _unitOf(data['unit']);
    return ItemDailyBalanceCard(
      sourceId: _text(data['sourceId']) ?? '',
      itemKey: _text(data['itemKey']) ?? '',
      itemName: _text(data['itemName']) ?? _text(data['itemKey']) ?? '',
      stockDate: _dayOf(data['stockDate']) ?? fallbackDay,
      incoming: _quantityOf(data['incoming'], unit),
      outgoing: _quantityOf(data['outgoing'], unit),
      balance: _quantityOf(data['balance'], unit),
    );
  }

  /// يحوّل مستند حركةٍ خاماً إلى بطاقته.
  ///
  /// ★★ **مكشوفٌ لسببين لا لسبب** (تقرير `2026-08-26-run2` · بند التدقيق ①):
  /// ① **الاختبار** — ★ **لأن العطل الذي رُصد في `WU-004` كان في هذا التحويل
  /// نفسه**، ⟵ ⛔ **فحراسته تحتاج اختبار ارتدادٍ سلوكياً لا نصّياً.**
  /// ② ★★ **و`FirestoreReportDirectory` يقرأ الدفترَ نفسَه** (`R-01` —
  /// `WU-011`) — ⟵ **ولذلك سقطت `@visibleForTesting`**: ★ **فللدالة الآن
  /// مستهلكٌ إنتاجيٌّ حقيقي**، ⛔ **ونسخةٌ ثانية منها تفترق عند أول حقل.**
  static StockMovementCard movementOf(String id, Map<String, dynamic> data) {
    final ItemUnit unit = _unitOf(data['unit']);
    return StockMovementCard(
      movementId: id,
      itemKey: _text(data['itemKey']) ?? '',
      itemName: _text(data['itemName']) ?? '',
      direction: data['direction'] == MovementDirection.outgoing.name
          ? MovementDirection.outgoing
          : MovementDirection.incoming,
      quantity: _quantityOf(data['quantity'], unit),
      balanceAfter: _quantityOf(data['balanceAfter'], unit),
      // ⛔★★ **ويُقرأ من الحركة لا يُفترَض** — ★ **رُصد في `WU-004`:**
      //    كان محفوراً `countedIntake` حين لم يكن للدفتر كاتبٌ غيره،
      //    ⟵ **ثم صارت الجونية تكتب فيه** (`SourceDocumentType.sack`)،
      //    ⛔ **فبقاؤه محفوراً كان يَسِم حركاتِ الجواني «وارداً عدداً»**
      //    في سجل حركة النوع — ★ **خطأ عرضٍ صامت لا يُسقِط شيئاً.**
      sourceDocumentType: _docTypeOf(data['sourceDocType']),
      sourceDocumentNumber: _text(data['sourceDocNumber']) ?? '',
      // ⚠️ **الغياب لا يُسقِط السطر** — ★ **ويُقرأ أقدمَ ما يكون** فيبقى
      //    ترتيبه مستقراً بدل أن يقفز إلى رأس القائمة.
      entryDate: _instant(data['entryDate']) ?? DateTime.utc(1970),
      isCancelled: data['isCancelled'] == true,
      isAmended: data['lastAmendedAt'] != null,
      movementTag: _tagOf(data['movementTag']),
      userName: _text(data['amendedBy']),
      // ★★ **تاريخُ المخزون يُقرأ ولا يُشتقّ من `entryDate`** (`RISK-07`) —
      //    ⟵ **و`R-01` يمتدّ على فترة فيعرضه عموداً** (`WU-011`).
      stockDate: _dayOf(data['stockDate']),
    );
  }

  /// ★ يحوّل مستند وارد عدداً خاماً إلى بطاقته.
  ///
  /// ★★ **ومكشوفٌ لأن `FirestoreReportDirectory` يقرأ المجموعةَ نفسَها**
  /// (`R-03` — `WU-011`) — راجع [balanceOf].
  static CountedIntakeCard intakeOf(
    String id,
    Map<String, dynamic> data,
    CalendarDay fallbackDay,
  ) {
    final List<ValidatedCountedIntakeLine> lines =
        <ValidatedCountedIntakeLine>[];
    final Object? raw = data['lines'];
    if (raw is List<dynamic>) {
      for (final Object? line in raw) {
        if (line is! Map<dynamic, dynamic>) continue;
        final String? itemId = _text(line['itemId']) ?? _text(line['itemKey']);
        if (itemId == null) continue;
        lines.add(
          ValidatedCountedIntakeLine(
            itemId: itemId,
            itemName: _text(line['itemName']) ?? itemId,
            quantity: PieceCount(_int(line['quantity']) ?? 0),
            note: _text(line['note']),
          ),
        );
      }
    }
    return CountedIntakeCard(
      documentNumber: _text(data['documentNumber']) ?? id,
      sourceId: _text(data['sourceId']) ?? '',
      stockDate: _dayOf(data['stockDate']) ?? fallbackDay,
      entryDate: _instant(data['entryDate']) ?? DateTime.utc(1970),
      status: data['status'] == CountedIntakeStatus.cancelled.name
          ? CountedIntakeStatus.cancelled
          : CountedIntakeStatus.approved,
      totalQuantity: PieceCount(_int(data['totalQuantity']) ?? 0),
      lines: lines,
      supplierId: _text(data['supplierId']),
      notes: _text(data['notes']),
      cancelReason: _text(data['cancelReason']),
      amendCount: _int(data['amendCount']) ?? 0,
    );
  }

  /// ★ الكمية بوحدة النوع — ⛔ **ولا تُقرأ حبّةً لنوعٍ وزني** (`GR-19`).
  static StockQuantity _quantityOf(Object? raw, ItemUnit unit) =>
      switch (unit) {
        ItemUnit.piece => PieceQuantity(PieceCount(_int(raw) ?? 0)),
        ItemUnit.kilogram => WeightQuantity(WeightKg(_double(raw) ?? 0)),
      };

  static ItemUnit _unitOf(Object? raw) {
    for (final ItemUnit unit in ItemUnit.values) {
      if (unit.name == raw) return unit;
    }
    return ItemUnit.piece;
  }

  /// ★ نوع المستند المصدر — ⛔ **والمجهول «وارد عدداً»**.
  ///
  /// ⚠️ **والافتراض هنا لأقدم كاتبٍ للدفتر** — ★ **فحركاتُ `WU-003` كُتبت
  /// قبل أن يوجد هذا الحقل بقيمٍ أخرى**، ⟵ **وقراءتُها بالأحدث كانت
  /// ستَسِمها خطأً.**
  static SourceDocumentType _docTypeOf(Object? raw) {
    for (final SourceDocumentType type in SourceDocumentType.values) {
      if (type.name == raw) return type;
    }
    return SourceDocumentType.countedIntake;
  }

  static MovementTag _tagOf(Object? raw) {
    for (final MovementTag tag in MovementTag.values) {
      if (tag.name == raw) return tag;
    }
    return MovementTag.normal;
  }

  static CalendarDay? _dayOf(Object? raw) {
    final DateTime? instant = _instant(raw);
    return instant == null ? null : CalendarDay.fromUtc(instant);
  }

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

  static int? _int(Object? raw) => switch (raw) {
        final int value => value,
        final double value when value == value.roundToDouble() => value.toInt(),
        _ => null,
      };

  static double? _double(Object? raw) => switch (raw) {
        final int value => value.toDouble(),
        final double value => value,
        _ => null,
      };
}

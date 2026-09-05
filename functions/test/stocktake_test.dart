/// الجرد — ★★★ **حارس التفويض والنطاق والتجميد والتسوية** (`WU-022`).
///
/// ⚠️⚠️ **ولماذا يُختبَر بهذه الصرامة:** بعد إغلاق الكتابة المباشرة
/// (`ADR-0013` القاعدة 2) **لم يبقَ بين المستخدم والدفتر إلا هذا الكود** —
/// ⟵ **فكل شرطٍ كانت تفرضه `firestore.rules` صار بند قبولٍ هنا.**
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **وستةٌ تحرسها هذه الاختبارات:**
///
///   ① **`BR-M16-03` · `AT-66`:** ⛔⛔ **لا حقلَ ماليٍّ واحدٌ يُكتب** —
///      ⟵ **وحارسٌ يمسح كلَّ حقلٍ في كلِّ كتابةٍ بحثاً عن اسمٍ ماليّ.**
///   ② **`BR-M16-03`:** ⛔⛔ **ولا قيدَ في دفتر المقاوته ولا الرعوي** —
///      ★ **يُقاس بعدّ المجموعات المكتوبة** ⛔ **لا بقراءة الكود.**
///   ③ **`AT-66`:** ★★ **والحركةُ مَوْسومةٌ `adjustment`** — ⟵ **وهو ما
///      يُخرِجها من سعر الجونية ومن المبيعات ومن استحقاق الرعوي.**
///   ④ **`FR-M16-03`:** ★★★ **والفرقُ على الرصيد المُجمَّد** — ⛔ **لا على
///      رصيدٍ يُعاد قياسُه لحظةَ الاعتماد.**
///   ⑤ **`FR-M16-06`:** ⛔⛔ **ولا جردان مفتوحان على نفس المصدر واليوم.**
///   ⑥ **`FR-M16-08`:** ★★ **وتاريخُ مخزونٍ أقدمُ يشترط `stocktakePriorDay`**
///      · ⛔ **والمستقبليُّ مرفوضٌ للجميع بلا مفتاحٍ يفتحه.**
/// ═══════════════════════════════════════════════════════════════════════
library;

import 'package:qtms_domain/qtms_domain.dart';
import 'package:qtms_functions/src/callable.dart';
import 'package:qtms_functions/src/identity_claims.dart';
import 'package:qtms_functions/src/identity_gateway.dart';
import 'package:qtms_functions/src/inventory.dart';
import 'package:qtms_functions/src/stocktake.dart';
import 'package:test/test.dart';

const String actorUid = 'uid-owner';
const String sourceA = 'SRC-001';
const String sourceB = 'SRC-002';
const String itemA = 'ITM-0001';
const String documentNumber = 'STK-20260905-001';

final CalendarDay day = CalendarDay(2026, 9, 5);
final CalendarDay yesterday = CalendarDay(2026, 9, 4);
final CalendarDay tomorrow = CalendarDay(2026, 9, 6);

/// ★ مفاتيح الجرد الأربعة — **لاختبارات ما ليس تفويضاً**.
const Set<Permission> fullPermissions = <Permission>{
  Permission.stocktakeWrite,
  Permission.stocktakeApprove,
  Permission.stocktakeAmend,
  Permission.stocktakeCancel,
};

/// ⛔⛔★★★ **أسماءُ الحقول المالية الممنوعة** — `BR-M16-03` · `AT-66`.
const Set<String> forbiddenMoneyFields = <String>{
  'unitPrice',
  'lineTotal',
  'lineValue',
  'amount',
  'grandTotal',
  'totalValue',
  'totalQatValue',
  'totalCashValue',
  'debtValue',
  'price',
};

AccountRecord account({
  Set<Permission> permissions = fullPermissions,
  SourceScope scope = const AllSources(),
  bool disabled = false,
}) =>
    AccountRecord(
      userId: actorUid,
      userName: 'المالك',
      claims: IdentityClaims(permissions: permissions, sourceScope: scope),
      disabled: disabled,
      cardIsActive: true,
    );

ItemRead item({
  String itemId = itemA,
  ItemUnit unit = ItemUnit.piece,
  bool isActive = true,
  List<String> sourceIds = const <String>[sourceA],
}) =>
    ItemRead(
      itemId: itemId,
      name: 'عوارض',
      unit: unit,
      isActive: isActive,
      sourceIds: sourceIds,
    );

LedgerRead movement(
  String movementId,
  int quantity, {
  String itemKey = itemA,
  MovementDirection direction = MovementDirection.incoming,
  bool cancelled = false,
}) =>
    LedgerRead(
      movementId: movementId,
      movement: StockMovement(
        itemKey: itemKey,
        direction: direction,
        quantity: PieceQuantity(PieceCount(quantity)),
        isCancelled: cancelled,
      ),
    );

ValidatedStocktakeStart start({
  String sourceId = sourceA,
  List<String> itemIds = const <String>[itemA],
}) =>
    (validateStocktakeStart(
      StocktakeStartInput(sourceId: sourceId, itemIds: itemIds),
    ) as Success<ValidatedStocktakeStart>)
        .value;

ValidatedStocktakeCounts counts({
  String sourceId = sourceA,
  int actual = 78,
  String itemId = itemA,
  ItemUnit unit = ItemUnit.piece,
  String? differenceReason,
  String? reason,
}) =>
    (validateStocktakeCounts(
      sourceId: sourceId,
      counts: <StocktakeCountInput>[
        StocktakeCountInput(
          itemId: itemId,
          unit: unit,
          actualCount: switch (unit) {
            ItemUnit.piece => PieceQuantity(PieceCount(actual)),
            ItemUnit.kilogram => WeightQuantity(WeightKg(actual.toDouble())),
          },
          differenceReason: differenceReason,
        ),
      ],
      reason: reason,
    ) as Success<ValidatedStocktakeCounts>)
        .value;

/// ★★★ **مستندُ مسوّدةٍ مخزَّن** — ⟵ **برصيدٍ دفتريٍّ مُجمَّد.**
Map<String, Object?> storedDraft({
  String status = 'draft',
  int bookBalance = 80,
  String sourceId = sourceA,
  String itemKey = itemA,
  String unit = 'piece',
}) =>
    <String, Object?>{
      'documentNumber': documentNumber,
      'sourceId': sourceId,
      'status': status,
      'lines': <Object?>[
        <String, Object?>{
          'itemKey': itemKey,
          'itemName': 'عوارض',
          'unit': unit,
          'bookBalance': bookBalance,
        },
      ],
      'lineCount': 1,
    };

StocktakeRequest request({
  AccountRecord? actor,
  ValidatedStocktakeStart? startInput,
  ValidatedStocktakeCounts? countsInput,
  Map<String, Object?>? storedSource = const <String, Object?>{
    'isActive': true,
    'name': 'مصدر الاختبار',
  },
  Map<String, Object?>? storedDocument,
  Map<String, ItemRead>? items,
  Map<String, List<LedgerRead>>? ledger,
  Map<String, Map<String, Object?>>? sameDayDocuments,
  String? reason,
  String sourceId = sourceA,
  String number = documentNumber,
  CalendarDay? stockDate,
  CalendarDay? serverDay,
  String requestId = 'req-1',
}) =>
    StocktakeRequest(
      actor: actor ?? account(),
      requestId: requestId,
      sourceId: sourceId,
      documentNumber: number,
      stockDate: stockDate ?? day,
      serverDay: serverDay,
      start: startInput,
      counts: countsInput,
      storedSource: storedSource,
      storedDocument: storedDocument,
      items: items ?? <String, ItemRead>{itemA: item()},
      // ★ **مخزونٌ افتراضي 80 حبة** — ⟵ **فاختبارات التفويض تفشل على
      //   التفويض لا على نقص الرصيد.**
      ledger: ledger ??
          <String, List<LedgerRead>>{
            itemA: <LedgerRead>[movement('INC-1_$itemA', 80)],
          },
      sameDayDocuments: sameDayDocuments ?? const <String, Map<String, Object?>>{},
      reason: reason,
    );

StocktakeAccepted accept(StocktakePlan plan) {
  expect(plan, isA<StocktakeAccepted>(), reason: 'رُفض ما كان يجب قبوله');
  return plan as StocktakeAccepted;
}

CallableError reject(StocktakePlan plan) {
  expect(plan, isA<StocktakeRejected>(), reason: 'قُبل ما كان يجب رفضه');
  return (plan as StocktakeRejected).error;
}

Map<String, Object?> writeFor(
  StocktakeAccepted accepted,
  String collection,
) =>
    accepted.writes
        .firstWhere((InventoryWrite write) => write.collectionId == collection)
        .fields;

/// ★ خطةُ بدءٍ ناجحة — **للاختبارات التي تبني عليها**.
StocktakeAccepted acceptedStart({
  Map<String, List<LedgerRead>>? ledger,
  Map<String, ItemRead>? items,
  List<String> itemIds = const <String>[itemA],
}) =>
    accept(
      planStocktake(
        request(
          startInput: start(itemIds: itemIds),
          ledger: ledger,
          items: items,
        ),
        StocktakeOperation.startStocktake,
      ),
    );

void main() {
  group('★★★ BR-M16-03 — ولا حقلَ ماليٍّ واحدٌ في أي كتابة', () {
    test('⛔⛔★★★ لا اسمَ ماليٍّ في أي حقلٍ من كل كتابات البدء', () {
      for (final InventoryWrite write in acceptedStart().writes) {
        for (final String field in write.fields.keys) {
          expect(
            forbiddenMoneyFields.contains(field),
            isFalse,
            reason: 'حقلٌ ماليٌّ «$field» في ${write.collectionId}',
          );
        }
      }
    });

    test('⛔⛔★★★ ولا اسمَ ماليٍّ في أي حقلٍ من كل كتابات الاعتماد', () {
      final StocktakeAccepted accepted = accept(
        planStocktake(
          request(countsInput: counts(), storedDocument: storedDraft()),
          StocktakeOperation.approveStocktake,
        ),
      );
      for (final InventoryWrite write in accepted.writes) {
        for (final String field in write.fields.keys) {
          expect(
            forbiddenMoneyFields.contains(field),
            isFalse,
            reason: 'حقلٌ ماليٌّ «$field» في ${write.collectionId}',
          );
        }
      }
    });

    test('⛔⛔★★★ ولا سطرٌ يحمل مبلغاً في المستند', () {
      final StocktakeAccepted accepted = accept(
        planStocktake(
          request(countsInput: counts(), storedDocument: storedDraft()),
          StocktakeOperation.approveStocktake,
        ),
      );
      final Object? lines = writeFor(accepted, stocktakesCollection)['lines'];
      for (final Object? line in lines! as List<Object?>) {
        for (final String field in (line! as Map<String, Object?>).keys) {
          expect(forbiddenMoneyFields.contains(field), isFalse);
        }
      }
    });

    test('⛔⛔★★★ ولا قيدَ في دفتر المقاوته ولا الرعوي — مقيسٌ بعدّ المجموعات',
        () {
      final StocktakeAccepted accepted = accept(
        planStocktake(
          request(countsInput: counts(), storedDocument: storedDraft()),
          StocktakeOperation.approveStocktake,
        ),
      );
      expect(
        accepted.writes.map((InventoryWrite w) => w.collectionId).toSet(),
        <String>{
          stocktakesCollection,
          inventoryLedgerCollection,
          itemDailyBalancesCollection,
        },
      );
    });
  });

  group('★★★ FR-M16-03 — بدءُ الجرد يُجمِّد الرصيد الدفتري', () {
    test('★★★ يقرأ الرصيد من الدفتر ويكتبه `bookBalance` مُجمَّداً', () {
      final StocktakeAccepted accepted = acceptedStart(
        ledger: <String, List<LedgerRead>>{
          itemA: <LedgerRead>[
            movement('INC-1_$itemA', 100),
            movement(
              'DST-1_$itemA',
              20,
              direction: MovementDirection.outgoing,
            ),
          ],
        },
      );
      final Object? lines = writeFor(accepted, stocktakesCollection)['lines'];
      expect(
        ((lines! as List<Object?>).single as Map<String, Object?>)['bookBalance'],
        80,
      );
    });

    test('⛔⛔★★★ والمسوّدةُ لا تمسّ الدفتر ولا الرصيد — كتابةٌ واحدة', () {
      final StocktakeAccepted accepted = acceptedStart();
      expect(accepted.writes.length, 1);
      expect(accepted.writes.single.collectionId, stocktakesCollection);
      expect(accepted.status, StocktakeStatus.draft);
      expect(accepted.touchesLedger, isFalse);
    });

    test('★ والحركاتُ الملغاة لا تدخل التجميد — `A-14`', () {
      final StocktakeAccepted accepted = acceptedStart(
        ledger: <String, List<LedgerRead>>{
          itemA: <LedgerRead>[
            movement('INC-1_$itemA', 100),
            movement('INC-2_$itemA', 40, cancelled: true),
          ],
        },
      );
      final Object? lines = writeFor(accepted, stocktakesCollection)['lines'];
      expect(
        ((lines! as List<Object?>).single as Map<String, Object?>)['bookBalance'],
        100,
      );
    });

    test('★★★ والفرقُ يُحسَب على المُجمَّد لا على الدفتر الحيّ', () {
      // ⟵ **الدفترُ الآن 60 (خرجت 20 بعد التجميد)، والمُجمَّد 80، والعدُّ 78.**
      //    ★ **فالتسويةُ −2 لا +18** — ⛔ **وإلا ابتلعت التسويةُ خروجاً وقع.**
      final StocktakeAccepted accepted = accept(
        planStocktake(
          request(
            countsInput: counts(),
            storedDocument: storedDraft(),
            ledger: <String, List<LedgerRead>>{
              itemA: <LedgerRead>[
                movement('INC-1_$itemA', 80),
                movement(
                  'DST-1_$itemA',
                  20,
                  direction: MovementDirection.outgoing,
                ),
              ],
            },
          ),
          StocktakeOperation.approveStocktake,
        ),
      );
      final Map<String, Object?> ledgerWrite =
          writeFor(accepted, inventoryLedgerCollection);
      expect(ledgerWrite['direction'], MovementDirection.outgoing.name);
      expect(ledgerWrite['quantity'], 2);
      // ★ **والرصيدُ الناتج 58 = 80 − 20 − 2** ⛔ **لا 78.**
      expect(ledgerWrite['balanceAfter'], 58);
    });
  });

  group('★★★ AT-66 — الوسمُ والاتجاه', () {
    test('★★ حركةُ التسوية مَوْسومةٌ `adjustment` دائماً', () {
      final StocktakeAccepted accepted = accept(
        planStocktake(
          request(countsInput: counts(), storedDocument: storedDraft()),
          StocktakeOperation.approveStocktake,
        ),
      );
      expect(
        writeFor(accepted, inventoryLedgerCollection)['movementTag'],
        MovementTag.adjustment.name,
      );
      expect(
        writeFor(accepted, inventoryLedgerCollection)['sourceDocType'],
        SourceDocumentType.stocktake.name,
      );
    });

    test('★★ والنقصُ خروجٌ بكميةٍ مطلقة', () {
      final StocktakeAccepted accepted = accept(
        planStocktake(
          request(
            countsInput: counts(actual: 78),
            storedDocument: storedDraft(),
          ),
          StocktakeOperation.approveStocktake,
        ),
      );
      final Map<String, Object?> write =
          writeFor(accepted, inventoryLedgerCollection);
      expect(write['direction'], MovementDirection.outgoing.name);
      expect(write['quantity'], 2);
      expect(write['isCancelled'], isFalse);
    });

    test('★★ والزيادةُ دخولٌ — «تسوية جرد بالزيادة»', () {
      final StocktakeAccepted accepted = accept(
        planStocktake(
          request(
            countsInput: counts(actual: 83),
            storedDocument: storedDraft(),
          ),
          StocktakeOperation.approveStocktake,
        ),
      );
      final Map<String, Object?> write =
          writeFor(accepted, inventoryLedgerCollection);
      expect(write['direction'], MovementDirection.incoming.name);
      expect(write['quantity'], 3);
      expect(write['balanceAfter'], 83);
    });

    test('⛔⛔★★ والمطابقُ حركةٌ ملغاةٌ لا حركةٌ صفرية', () {
      final StocktakeAccepted accepted = accept(
        planStocktake(
          request(
            countsInput: counts(actual: 80),
            storedDocument: storedDraft(),
          ),
          StocktakeOperation.approveStocktake,
        ),
      );
      final Map<String, Object?> write =
          writeFor(accepted, inventoryLedgerCollection);
      expect(write['isCancelled'], isTrue);
      // ★ **والرصيدُ يبقى 80 كما كان** — ⛔ **فلا أثرَ لجردٍ مطابق.**
      expect(
        writeFor(accepted, itemDailyBalancesCollection)['balance'],
        80,
      );
    });

    test('⛔⛔★★★ ولا `sackId` في حركة التسوية — الفرقُ غيرُ مفسَّر', () {
      final StocktakeAccepted accepted = accept(
        planStocktake(
          request(countsInput: counts(), storedDocument: storedDraft()),
          StocktakeOperation.approveStocktake,
        ),
      );
      expect(
        writeFor(accepted, inventoryLedgerCollection).containsKey('sackId'),
        isFalse,
      );
    });
  });

  group('★★★ FR-M16-09 — المفاتيح الأربعة وحالةُ المستند', () {
    test('⛔ البدءُ بلا `stocktakeWrite` مرفوض', () {
      expect(
        reject(
          planStocktake(
            request(
              actor: account(permissions: const <Permission>{}),
              startInput: start(),
            ),
            StocktakeOperation.startStocktake,
          ),
        ),
        CallableError.permissionMissing,
      );
    });

    test('⛔⛔★★★ والاعتمادُ بمفتاح البدء وحده مرفوض — صلاحيةٌ مستقلة', () {
      expect(
        reject(
          planStocktake(
            request(
              actor: account(
                permissions: const <Permission>{Permission.stocktakeWrite},
              ),
              countsInput: counts(),
              storedDocument: storedDraft(),
            ),
            StocktakeOperation.approveStocktake,
          ),
        ),
        CallableError.permissionMissing,
      );
    });

    test('⛔ والإلغاءُ بمفتاح الاعتماد وحده مرفوض', () {
      expect(
        reject(
          planStocktake(
            request(
              actor: account(
                permissions: const <Permission>{Permission.stocktakeApprove},
              ),
              storedDocument: storedDraft(),
            ),
            StocktakeOperation.cancelStocktake,
          ),
        ),
        CallableError.permissionMissing,
      );
    });

    test('⛔⛔ واعتمادُ ما ليس مسوّدةً مرفوض — `ERR_STOCK_007`', () {
      expect(
        reject(
          planStocktake(
            request(
              countsInput: counts(),
              storedDocument: storedDraft(status: 'approved'),
            ),
            StocktakeOperation.approveStocktake,
          ),
        ),
        CallableError.stocktakeNotDraft,
      );
    });

    test('⛔⛔★★ وتعديلُ مسوّدةٍ مرفوض — ⛔ ولا يلتفّ التعديلُ على الاعتماد',
        () {
      expect(
        reject(
          planStocktake(
            request(
              countsInput: counts(),
              storedDocument: storedDraft(),
            ),
            StocktakeOperation.amendStocktake,
          ),
        ),
        CallableError.stocktakeNotApproved,
      );
    });

    test('★ وتعديلُ المعتمد مقبول', () {
      final StocktakeAccepted accepted = accept(
        planStocktake(
          request(
            countsInput: counts(actual: 79),
            storedDocument: storedDraft(status: 'approved'),
          ),
          StocktakeOperation.amendStocktake,
        ),
      );
      expect(writeFor(accepted, stocktakesCollection)['amendCount'], 1);
    });

    test('⛔ والملغى لا يُعتمَد ولا يُعدَّل ولا يُلغى ثانيةً', () {
      expect(
        reject(
          planStocktake(
            request(
              countsInput: counts(),
              storedDocument: storedDraft(status: 'cancelled'),
            ),
            StocktakeOperation.approveStocktake,
          ),
        ),
        CallableError.documentCancelled,
      );
    });

    test('★★ والحسابُ المعطَّل مرفوضٌ قبل كل شيء', () {
      expect(
        reject(
          planStocktake(
            request(actor: account(disabled: true), startInput: start()),
            StocktakeOperation.startStocktake,
          ),
        ),
        CallableError.accountDisabled,
      );
    });
  });

  group('★★★ GR-23 — نطاقُ المصادر يعلو على الصلاحية', () {
    test('⛔ مصدرٌ خارج النطاق مرفوضٌ ولو ملك كل المفاتيح', () {
      expect(
        reject(
          planStocktake(
            request(
              actor: account(scope: ScopedSources(const <String>{sourceB})),
              startInput: start(),
            ),
            StocktakeOperation.startStocktake,
          ),
        ),
        CallableError.sourceOutOfScope,
      );
    });

    test('⛔⛔★★ والمخزَّن هو الحَكَم لا المُرسَل', () {
      expect(
        reject(
          planStocktake(
            request(
              countsInput: counts(),
              storedDocument: storedDraft(sourceId: sourceB),
            ),
            StocktakeOperation.approveStocktake,
          ),
        ),
        CallableError.sourceOutOfScope,
      );
    });
  });

  group('★★★ FR-M16-06 — لا جردان مفتوحان على نفس المصدر واليوم', () {
    test('⛔⛔ مسوّدةٌ قائمةٌ تمنع بدءَ جردٍ ثانٍ — `ERR_STOCK_006`', () {
      expect(
        reject(
          planStocktake(
            request(
              startInput: start(),
              sameDayDocuments: <String, Map<String, Object?>>{
                'STK-20260905-000': storedDraft(),
              },
            ),
            StocktakeOperation.startStocktake,
          ),
        ),
        CallableError.stocktakeInProgress,
      );
    });

    test('★★ وجردٌ معتمدٌ لا يمنع جرداً ثانياً — العدُّ قد يُعاد', () {
      expect(
        planStocktake(
          request(
            startInput: start(),
            sameDayDocuments: <String, Map<String, Object?>>{
              'STK-20260905-000': storedDraft(status: 'approved'),
            },
          ),
          StocktakeOperation.startStocktake,
        ),
        isA<StocktakeAccepted>(),
      );
    });

    test('★ وجردٌ ملغى لا يمنع كذلك', () {
      expect(
        planStocktake(
          request(
            startInput: start(),
            sameDayDocuments: <String, Map<String, Object?>>{
              'STK-20260905-000': storedDraft(status: 'cancelled'),
            },
          ),
          StocktakeOperation.startStocktake,
        ),
        isA<StocktakeAccepted>(),
      );
    });
  });

  group('★★★ FR-M16-08 — جردُ يومٍ سابق بمفتاحه', () {
    test('★ يومُ المنصّة نفسُه مقبولٌ بلا مفتاحٍ إضافي', () {
      expect(
        planStocktake(
          request(startInput: start(), serverDay: day),
          StocktakeOperation.startStocktake,
        ),
        isA<StocktakeAccepted>(),
      );
    });

    test('⛔ ويومٌ أقدمُ بلا `stocktakePriorDay` مرفوض', () {
      expect(
        reject(
          planStocktake(
            request(
              startInput: start(),
              stockDate: yesterday,
              serverDay: day,
            ),
            StocktakeOperation.startStocktake,
          ),
        ),
        CallableError.permissionMissing,
      );
    });

    test('★★ ومعه مقبول', () {
      expect(
        planStocktake(
          request(
            actor: account(
              permissions: <Permission>{
                ...fullPermissions,
                Permission.stocktakePriorDay,
              },
            ),
            startInput: start(),
            stockDate: yesterday,
            serverDay: day,
          ),
          StocktakeOperation.startStocktake,
        ),
        isA<StocktakeAccepted>(),
      );
    });

    test('⛔⛔★★ ولا يُغني `agedRemainderClear` عنه — مفتاحان مختلفان', () {
      expect(
        reject(
          planStocktake(
            request(
              actor: account(
                permissions: <Permission>{
                  ...fullPermissions,
                  Permission.agedRemainderClear,
                },
              ),
              startInput: start(),
              stockDate: yesterday,
              serverDay: day,
            ),
            StocktakeOperation.startStocktake,
          ),
        ),
        CallableError.permissionMissing,
      );
    });

    test('⛔⛔★★★ والمستقبليُّ مرفوضٌ للجميع — ولا مفتاحَ يفتحه', () {
      expect(
        reject(
          planStocktake(
            request(
              actor: account(
                permissions: <Permission>{
                  ...fullPermissions,
                  Permission.stocktakePriorDay,
                },
              ),
              startInput: start(),
              stockDate: tomorrow,
              serverDay: day,
            ),
            StocktakeOperation.startStocktake,
          ),
        ),
        CallableError.invalidArgument,
      );
    });

    test('★★ ولا يُفحَص التاريخُ في الاعتماد — إتمامُ قائمٍ لا بدءُ جديد', () {
      // ⟵ **ولولا ذلك لَاستحال اعتمادُ جردِ أمسٍ بُدئ بشكلٍ مشروع.**
      expect(
        planStocktake(
          request(
            countsInput: counts(),
            storedDocument: storedDraft(),
            stockDate: yesterday,
            serverDay: day,
          ),
          StocktakeOperation.approveStocktake,
        ),
        isA<StocktakeAccepted>(),
      );
    });
  });

  group('★★ الإلغاء — بالوسم لا بحركةٍ عكسية', () {
    test('★★ يَسِم المستند وحركاته ملغاةً ويُعيد الرصيد', () {
      final StocktakeAccepted accepted = accept(
        planStocktake(
          request(
            storedDocument: storedDraft(status: 'approved'),
            ledger: <String, List<LedgerRead>>{
              itemA: <LedgerRead>[
                movement('INC-1_$itemA', 80),
                movement(
                  '${documentNumber}_$itemA',
                  2,
                  direction: MovementDirection.outgoing,
                ),
              ],
            },
          ),
          StocktakeOperation.cancelStocktake,
        ),
      );
      expect(
        writeFor(accepted, stocktakesCollection)['status'],
        StocktakeStatus.cancelled.name,
      );
      expect(
        writeFor(accepted, inventoryLedgerCollection)['isCancelled'],
        isTrue,
      );
      // ★ **والرصيدُ يعود 80** — ⛔ **بلا حركةٍ عكسية.**
      expect(writeFor(accepted, itemDailyBalancesCollection)['balance'], 80);
      expect(accepted.status, StocktakeStatus.cancelled);
    });

    test('★ وإلغاءُ مسوّدةٍ بلا حركاتٍ كتابةٌ واحدة', () {
      final StocktakeAccepted accepted = accept(
        planStocktake(
          request(
            storedDocument: storedDraft(),
            ledger: const <String, List<LedgerRead>>{},
          ),
          StocktakeOperation.cancelStocktake,
        ),
      );
      expect(accepted.writes.length, 1);
      expect(accepted.touchesLedger, isFalse);
    });

    test('★ والإلغاء مسموحٌ على مصدرٍ عُطِّل — ⛔ ولا يحبس التعطيلُ مستنداً', () {
      expect(
        planStocktake(
          request(
            storedDocument: storedDraft(status: 'approved'),
            storedSource: const <String, Object?>{'isActive': false},
          ),
          StocktakeOperation.cancelStocktake,
        ),
        isA<StocktakeAccepted>(),
      );
    });
  });

  group('★★ حرّاسٌ متفرّقة', () {
    test('⛔ عدٌّ لنوعٍ لم يُجمَّد مرفوض — ⛔ ولا تسويةٌ على صفرٍ مفترَض', () {
      expect(
        reject(
          planStocktake(
            request(
              countsInput: counts(itemId: 'ITM-OTHER'),
              storedDocument: storedDraft(),
            ),
            StocktakeOperation.approveStocktake,
          ),
        ),
        CallableError.invalidArgument,
      );
    });

    test('⛔ ونوعٌ خارج مصادر المستند مرفوضٌ عند البدء — `FR-M5-10`', () {
      expect(
        reject(
          planStocktake(
            request(
              startInput: start(),
              items: <String, ItemRead>{
                itemA: item(sourceIds: const <String>[sourceB]),
              },
            ),
            StocktakeOperation.startStocktake,
          ),
        ),
        CallableError.invalidArgument,
      );
    });

    test('⛔ ونوعٌ معطَّل مرفوضٌ عند البدء', () {
      expect(
        reject(
          planStocktake(
            request(
              startInput: start(),
              items: <String, ItemRead>{itemA: item(isActive: false)},
            ),
            StocktakeOperation.startStocktake,
          ),
        ),
        CallableError.invalidArgument,
      );
    });

    test('⛔ ومصدرٌ معطَّل يمنع البدء — `FR-M2-05`', () {
      expect(
        reject(
          planStocktake(
            request(
              startInput: start(),
              storedSource: const <String, Object?>{'isActive': false},
            ),
            StocktakeOperation.startStocktake,
          ),
        ),
        CallableError.sourceInactive,
      );
    });

    test('⛔ وسجلُّ مصدرٍ لم يُقرأ رفضٌ لا تجاوز', () {
      expect(
        reject(
          planStocktake(
            request(startInput: start(), storedSource: null),
            StocktakeOperation.startStocktake,
          ),
        ),
        CallableError.internal,
      );
    });

    test('⛔ ومعرّفُ طلبٍ فارغ مرفوض — فلا لاتكرارية بدونه', () {
      expect(
        reject(
          planStocktake(
            request(startInput: start(), requestId: '   '),
            StocktakeOperation.startStocktake,
          ),
        ),
        CallableError.invalidArgument,
      );
    });

    test('⛔ ورقمٌ يقابله مستندٌ قائمٌ عند البدء تصادمُ عدّاد', () {
      expect(
        reject(
          planStocktake(
            request(startInput: start(), storedDocument: storedDraft()),
            StocktakeOperation.startStocktake,
          ),
        ),
        CallableError.concurrency,
      );
    });

    test('★★ والوزنُ يمرّ بثلاث خانات — `FR-M16-07`', () {
      final StocktakeAccepted accepted = accept(
        planStocktake(
          request(
            countsInput: counts(actual: 1, unit: ItemUnit.kilogram),
            storedDocument: storedDraft(bookBalance: 2, unit: 'kilogram'),
            items: <String, ItemRead>{
              itemA: item(unit: ItemUnit.kilogram),
            },
            ledger: <String, List<LedgerRead>>{
              itemA: <LedgerRead>[
                LedgerRead(
                  movementId: 'INC-1_$itemA',
                  movement: StockMovement(
                    itemKey: itemA,
                    direction: MovementDirection.incoming,
                    quantity: const WeightQuantity(WeightKg(2)),
                    isCancelled: false,
                  ),
                ),
              ],
            },
          ),
          StocktakeOperation.approveStocktake,
        ),
      );
      final Map<String, Object?> write =
          writeFor(accepted, inventoryLedgerCollection);
      expect(write['direction'], MovementDirection.outgoing.name);
      expect(write['unit'], ItemUnit.kilogram.name);
    });
  });

  group('★★★ FR-M16-11 — قيدُ التدقيق', () {
    test('★★ قيدُ البدء «إنشاء» بنوع كيان الجرد ورقمه', () {
      final StocktakeAccepted accepted = acceptedStart();
      expect(accepted.entry.action, AuditAction.create);
      expect(accepted.entry.target.entityType, stocktakeEntityType);
      expect(accepted.entry.target.entityId, documentNumber);
      expect(accepted.entry.target.sourceId, sourceA);
    });

    test('★★ وقيدُ الاعتماد يحمل الأعدادَ والفروق في `valuesAfter`', () {
      final StocktakeAccepted accepted = accept(
        planStocktake(
          request(countsInput: counts(), storedDocument: storedDraft()),
          StocktakeOperation.approveStocktake,
        ),
      );
      expect(accepted.entry.action, AuditAction.amend);
      expect(accepted.entry.valuesAfter['status'], StocktakeStatus.approved.name);
      expect(accepted.entry.valuesAfter.containsKey('lines'), isTrue);
    });

    test('★ وقيدُ الإلغاء فعلٌ مستقل', () {
      final StocktakeAccepted accepted = accept(
        planStocktake(
          request(storedDocument: storedDraft(status: 'approved')),
          StocktakeOperation.cancelStocktake,
        ),
      );
      expect(accepted.entry.action, AuditAction.cancel);
    });

    test('⛔⛔★★★ ولا سببَ إلزاميٌّ في أي عملية — `ADR-0020`', () {
      for (final StocktakeAccepted accepted in <StocktakeAccepted>[
        acceptedStart(),
        accept(
          planStocktake(
            request(countsInput: counts(), storedDocument: storedDraft()),
            StocktakeOperation.approveStocktake,
          ),
        ),
        accept(
          planStocktake(
            request(storedDocument: storedDraft(status: 'approved')),
            StocktakeOperation.cancelStocktake,
          ),
        ),
      ]) {
        expect(accepted.entry.reason, isNull);
      }
    });
  });
}

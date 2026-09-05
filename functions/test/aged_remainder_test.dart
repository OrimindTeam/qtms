/// راصدُ المتبقي المتأخر وبوابةُ تصريفه — ★★★ **الطرف السحابي** (`WU-019`).
///
/// ⚠️⚠️ **ولماذا يُختبَر مستقلاً عن المعالِجات:** ★ **درسُ `DEBT-37` نصّاً**
/// — «⛔ **اختبارُ الطبقة لا يُغني عن اختبار ما يعبر بينها**»: ⟵ **وهذا
/// الملف هو ما يعبر بين خطةِ الكتابة وبين قائمة المتبقي وبوابةِ التاريخ.**
///
/// ⛔⛔★★★ **والبوابةُ هنا هي الحارسُ الوحيد:** ★ **مسارُ الكتابة مغلقٌ في
/// القواعد** (`ADR-0013` القاعدة 2)، ⟵ **فشرطُ «تاريخُ المخزون يومُ المنصّة»
/// لا تفرضه قاعدةٌ بل هذا الكود** — ★ **وحارسٌ لا يُختبَر حارسٌ غير مُختبَر.**
library;

import 'package:qtms_domain/qtms_domain.dart';
import 'package:qtms_functions/src/aged_remainder.dart';
import 'package:qtms_functions/src/audited_transaction.dart';
import 'package:qtms_functions/src/callable.dart';
import 'package:qtms_functions/src/cash_sale.dart';
import 'package:qtms_functions/src/distribution.dart';
import 'package:qtms_functions/src/firestore_value.dart';
import 'package:qtms_functions/src/identity_claims.dart';
import 'package:qtms_functions/src/identity_gateway.dart';
import 'package:qtms_functions/src/inventory.dart';
import 'package:test/test.dart';

const String sourceA = 'SRC-001';
const String itemA = 'ITM-0001';
const String scrapKey = 'السكرب - جونية رقم 1';

final CalendarDay serverDay = CalendarDay(2026, 9, 4);
final CalendarDay pastDay = CalendarDay(2026, 9, 1);
final CalendarDay futureDay = CalendarDay(2026, 9, 5);

AccountRecord account({Set<Permission> permissions = const <Permission>{}}) =>
    AccountRecord(
      userId: 'uid-seller',
      userName: 'بائع',
      claims: IdentityClaims(
        permissions: permissions,
        sourceScope: const AllSources(),
      ),
      disabled: false,
      cardIsActive: true,
    );

InventoryWrite balanceWrite({
  String itemKey = itemA,
  Object? balance = 40,
  String itemName = 'عوارض',
  String unit = 'piece',
  CalendarDay? stockDate,
}) =>
    InventoryWrite(
      collectionId: itemDailyBalancesCollection,
      documentId: itemDailyBalanceId(
        sourceId: sourceA,
        itemKey: itemKey,
        stockDate: stockDate ?? pastDay,
      ),
      fields: <String, Object?>{
        'sourceId': sourceA,
        'itemKey': itemKey,
        'itemName': itemName,
        'stockDate': (stockDate ?? pastDay).asUtcMidnight(),
        'unit': unit,
        'balance': balance,
      },
      updateMask: const <String>[],
    );

void main() {
  group('★★★ الراصد — من كتابات الرصيد نفسِها', () {
    test('★ رصيدٌ موجب ⟵ بندٌ بمعرّفٍ حتميٍّ مطابقٍ لسجل الرصيد', () {
      final AgedRemainderSet set =
          agedRemaindersFromBalanceWrites(<InventoryWrite>[balanceWrite()]);

      expect(set.deletions, isEmpty);
      final PendingDocument doc = set.documents.single;
      expect(doc.collectionId, agedRemaindersCollection);
      expect(
        doc.documentId,
        agedRemainderId(
          sourceId: sourceA,
          itemKey: itemA,
          stockDate: pastDay,
        ),
      );
      expect(doc.fields['sourceId'], sourceA);
      expect(doc.fields['itemKey'], itemA);
      expect(doc.fields['itemName'], 'عوارض');
      expect(doc.fields['stockDate'], pastDay.asUtcMidnight());
      expect(doc.fields['unit'], 'piece');
      expect(doc.fields['remaining'], 40);
      expect(doc.serverTimestampFields, <String>['updatedAt']);
      // ★ **والقناع كاملُ الحقول** — ⟵ **فحقلٌ قديم لا يبقى بقيمةٍ بائتة.**
      expect(doc.updateMask, doc.fields.keys.toList());
    });

    test('⛔⛔ ولا حقلَ للعمر إطلاقاً — العمرُ يُحسَب عند القراءة', () {
      final PendingDocument doc =
          agedRemaindersFromBalanceWrites(<InventoryWrite>[balanceWrite()])
              .documents
              .single;
      expect(doc.fields.keys, isNot(contains('ageInDays')));
      expect(doc.fields.keys, isNot(contains('age')));
    });

    test('★★ ورصيدُ الصفر يمحو البند — ولا يبقى يطالب بتصريف عدم', () {
      final AgedRemainderSet set = agedRemaindersFromBalanceWrites(
        <InventoryWrite>[balanceWrite(balance: 0)],
      );
      expect(set.documents, isEmpty);
      final PendingDeletion gone = set.deletions.single;
      expect(gone.collectionId, agedRemaindersCollection);
      expect(
        gone.documentId,
        agedRemainderId(sourceId: sourceA, itemKey: itemA, stockDate: pastDay),
      );
    });

    test('⛔⛔★★ والوزنُ الكسريُّ لا يُقرأ صفراً — فلا يُمحى بندٌ قائم', () {
      final AgedRemainderSet set = agedRemaindersFromBalanceWrites(
        <InventoryWrite>[
          balanceWrite(
            itemKey: scrapKey,
            itemName: 'السكرب',
            unit: 'kilogram',
            balance: DecimalValue(0.5),
          ),
        ],
      );
      expect(set.deletions, isEmpty);
      expect(set.documents.single.fields['remaining'], isA<DecimalValue>());
      expect(set.documents.single.fields['unit'], 'kilogram');
    });

    test('⛔ ولا تُقرأ كتابةٌ ليست كتابةَ رصيد', () {
      final AgedRemainderSet set = agedRemaindersFromBalanceWrites(
        <InventoryWrite>[
          const InventoryWrite(
            collectionId: inventoryLedgerCollection,
            documentId: 'x',
            fields: <String, Object?>{'balance': 10},
            updateMask: <String>[],
          ),
        ],
      );
      expect(set.documents, isEmpty);
      expect(set.deletions, isEmpty);
    });

    test('⛔ وكتابةٌ مشوَّهةٌ تُتخطّى — ولا تُسقِط معاملة', () {
      final AgedRemainderSet set = agedRemaindersFromBalanceWrites(
        <InventoryWrite>[
          const InventoryWrite(
            collectionId: itemDailyBalancesCollection,
            documentId: 'x',
            fields: <String, Object?>{'sourceId': '', 'balance': 5},
            updateMask: <String>[],
          ),
        ],
      );
      expect(set.documents, isEmpty);
      expect(set.deletions, isEmpty);
    });
  });

  group('★★★ بوابةُ التصريف المتأخر — `FR-M8-11` · `agedRemainderClear`', () {
    test('★ يومُ المنصّة نفسُه ⟵ قبولٌ بلا مفتاحٍ إضافي', () {
      expect(
        agedClearanceRejection(
          actor: account(),
          stockDate: serverDay,
          serverDay: serverDay,
        ),
        isNull,
      );
    });

    test('⛔⛔ ويومٌ أقدم بلا المفتاح ⟵ رفض', () {
      expect(
        agedClearanceRejection(
          actor: account(),
          stockDate: pastDay,
          serverDay: serverDay,
        ),
        CallableError.permissionMissing,
      );
    });

    test('✅ وبالمفتاح ⟵ قبول', () {
      expect(
        agedClearanceRejection(
          actor: account(
            permissions: <Permission>{Permission.agedRemainderClear},
          ),
          stockDate: pastDay,
          serverDay: serverDay,
        ),
        isNull,
      );
    });

    test('⛔⛔★★★ والمستقبليُّ مرفوضٌ للجميع — ولا مفتاحَ يفتحه', () {
      expect(
        agedClearanceRejection(
          actor: account(
            permissions: <Permission>{Permission.agedRemainderClear},
          ),
          stockDate: futureDay,
          serverDay: serverDay,
        ),
        CallableError.invalidArgument,
      );
    });

    test('★ ووسمُ «تصريفٌ متأخر» يتبع الفارق لا المفتاح', () {
      expect(
        isAgedClearanceOn(stockDate: pastDay, serverDay: serverDay),
        isTrue,
      );
      expect(
        isAgedClearanceOn(stockDate: serverDay, serverDay: serverDay),
        isFalse,
      );
      // ⛔ **ويومٌ مجهولٌ لا يُبنى عليه حكم** — مسارا التعديل والإلغاء.
      expect(isAgedClearanceOn(stockDate: pastDay), isFalse);
    });
  });

  group('★★★ التوزيع — البوابةُ في المُخطِّط الخالص لا في المنفِّذ', () {
    ValidatedDistribution payload() =>
        (validateDistribution(
          DistributionInput(
            sourceId: sourceA,
            dealerId: 'MQT-0001',
            lines: <DistributionLineInput>[
              DistributionLineInput(
                itemId: itemA,
                itemName: 'عوارض',
                unit: ItemUnit.piece,
                quantity: const PieceQuantity(PieceCount(10)),
                unitPrice: const Money(500),
              ),
            ],
          ),
        ) as Success<ValidatedDistribution>)
            .value;

    DistributionRequest requestOn({
      required CalendarDay stockDate,
      required Set<Permission> permissions,
      CalendarDay? platformDay,
    }) =>
        DistributionRequest(
          actor: account(permissions: permissions),
          requestId: 'req-1',
          sourceId: sourceA,
          dealerId: 'MQT-0001',
          documentNumber: 'DST-20260901-0001',
          stockDate: stockDate,
          serverDay: platformDay ?? serverDay,
          distribution: payload(),
          storedSource: const <String, Object?>{'isActive': true},
          storedDealer: const <String, Object?>{
            'isActive': true,
            'name': 'أحمد',
          },
          items: <String, ItemRead>{
            itemA: const ItemRead(
              itemId: itemA,
              name: 'عوارض',
              unit: ItemUnit.piece,
              isActive: true,
              sourceIds: <String>[sourceA],
            ),
          },
          ledger: <String, List<LedgerRead>>{
            itemA: <LedgerRead>[
              const LedgerRead(
                movementId: 'seed',
                movement: StockMovement(
                  itemKey: itemA,
                  direction: MovementDirection.incoming,
                  quantity: PieceQuantity(PieceCount(100)),
                  isCancelled: false,
                ),
              ),
            ],
          },
        );

    test('⛔⛔★★★ تاريخٌ أقدم بلا `agedRemainderClear` ⟵ رفضٌ صريح', () {
      final DistributionPlan plan = planDistribution(
        requestOn(
          stockDate: pastDay,
          permissions: <Permission>{
            Permission.distributionCreate,
            Permission.distributionPriceNow,
          },
        ),
        DistributionOperation.createDistribution,
      );
      expect(
        plan,
        isA<DistributionRejected>().having(
          (DistributionRejected r) => r.error,
          'error',
          CallableError.permissionMissing,
        ),
      );
    });

    test('✅★★★ وبالمفتاح يُقبَل — والقيدُ «تصريفٌ متأخر» بالتاريخين معاً', () {
      final DistributionPlan plan = planDistribution(
        requestOn(
          stockDate: pastDay,
          permissions: <Permission>{
            Permission.agedRemainderClear,
            Permission.distributionCreate,
            Permission.distributionPriceNow,
          },
        ),
        DistributionOperation.createDistribution,
      );
      final DistributionAccepted accepted = plan as DistributionAccepted;
      // ★★★ **فعلُ القيد باسمه** — `FR-M18-08`.
      expect(accepted.entry.action, AuditAction.agedRemainderClear);
      // ★★★ **وتاريخُ المخزون في هدف القيد** — `AT-52` · `FR-SYS-18`.
      expect(accepted.entry.target.stockDate, pastDay);
      // ★ **والحركةُ تُكتب على اليوم القديم** — ⛔ **لا على اليوم.**
      final InventoryWrite ledger = accepted.writes.firstWhere(
        (InventoryWrite w) => w.collectionId == inventoryLedgerCollection,
      );
      expect(ledger.fields['stockDate'], pastDay.asUtcMidnight());
    });

    test('★ ويومُ المنصّة نفسُه يبقى «إنشاءً» عادياً', () {
      final DistributionPlan plan = planDistribution(
        requestOn(
          stockDate: serverDay,
          permissions: <Permission>{
            Permission.distributionCreate,
            Permission.distributionPriceNow,
          },
        ),
        DistributionOperation.createDistribution,
      );
      expect((plan as DistributionAccepted).entry.action, AuditAction.create);
      expect(plan.entry.target.stockDate, serverDay);
    });

    test('⛔⛔ وتاريخٌ مستقبليٌّ مرفوضٌ ولو ملك المفتاح', () {
      final DistributionPlan plan = planDistribution(
        requestOn(
          stockDate: futureDay,
          permissions: <Permission>{
            Permission.agedRemainderClear,
            Permission.distributionCreate,
            Permission.distributionPriceNow,
          },
        ),
        DistributionOperation.createDistribution,
      );
      expect(
        plan,
        isA<DistributionRejected>().having(
          (DistributionRejected r) => r.error,
          'error',
          CallableError.invalidArgument,
        ),
      );
    });
  });

  group('★★★ البيع النقدي — نفسُ البوابة بلا نسخةٍ ثانية', () {
    ValidatedCashSale payload() => (validateCashSale(
          CashSaleInput(
            sourceId: sourceA,
            lines: <CashSaleLineInput>[
              CashSaleLineInput(
                itemId: itemA,
                itemName: 'عوارض',
                unit: ItemUnit.piece,
                quantity: const PieceQuantity(PieceCount(5)),
                unitPrice: const Money(600),
              ),
            ],
          ),
        ) as Success<ValidatedCashSale>)
            .value;

    CashSaleRequest requestOn({
      required CalendarDay stockDate,
      required Set<Permission> permissions,
    }) =>
        CashSaleRequest(
          actor: account(permissions: permissions),
          requestId: 'req-2',
          sourceId: sourceA,
          documentNumber: 'CSH-20260901-0001',
          stockDate: stockDate,
          serverDay: serverDay,
          sale: payload(),
          storedSource: const <String, Object?>{'isActive': true},
          items: <String, ItemRead>{
            itemA: const ItemRead(
              itemId: itemA,
              name: 'عوارض',
              unit: ItemUnit.piece,
              isActive: true,
              sourceIds: <String>[sourceA],
            ),
          },
          ledger: <String, List<LedgerRead>>{
            itemA: <LedgerRead>[
              const LedgerRead(
                movementId: 'seed',
                movement: StockMovement(
                  itemKey: itemA,
                  direction: MovementDirection.incoming,
                  quantity: PieceQuantity(PieceCount(100)),
                  isCancelled: false,
                ),
              ),
            ],
          },
        );

    test('⛔⛔ تاريخٌ أقدم بلا المفتاح ⟵ رفض', () {
      expect(
        planCashSale(
          requestOn(
            stockDate: pastDay,
            permissions: <Permission>{Permission.cashSaleCreate},
          ),
          CashSaleOperation.createCashSale,
        ),
        isA<CashSaleRejected>().having(
          (CashSaleRejected r) => r.error,
          'error',
          CallableError.permissionMissing,
        ),
      );
    });

    test('✅★★ وبالمفتاح يُقبَل — ويُحتسب في «نقدي» ذلك اليوم', () {
      final CashSalePlan plan = planCashSale(
        requestOn(
          stockDate: pastDay,
          permissions: <Permission>{
            Permission.agedRemainderClear,
            Permission.cashSaleCreate,
          },
        ),
        CashSaleOperation.createCashSale,
      );
      final CashSaleAccepted accepted = plan as CashSaleAccepted;
      expect(accepted.entry.action, AuditAction.agedRemainderClear);
      expect(accepted.entry.target.stockDate, pastDay);
      final InventoryWrite ledger = accepted.writes.firstWhere(
        (InventoryWrite w) => w.collectionId == inventoryLedgerCollection,
      );
      expect(ledger.fields['stockDate'], pastDay.asUtcMidnight());
    });
  });
}

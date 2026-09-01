/// السحبيات والخرجيات — ★★★ **حارس التفويض المزدوج والنطاق والتاريخ والرصيد**
/// (`WU-014`).
///
/// ⚠️⚠️ **ولماذا يُختبَر بهذه الصرامة:** بعد إغلاق الكتابة المباشرة
/// (`ADR-0013` القاعدة 2) **لم يبقَ بين المستخدم والدفتر إلا هذا الكود** —
/// ⟵ **فكل شرطٍ كانت تفرضه `firestore.rules` صار بند قبولٍ هنا.**
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **وأخطر ثلاثةٍ تحرسها هذه الاختبارات:**
///
///   ① **`FR-M22-04` (`GR-44`):** **لا تكتب قيداً واحداً في دفتر المقاوته
///      ولا في أرصدته** — ⟵ **وهو حارسٌ لا يُثبته إلا اختبارٌ يعدّ
///      المجموعات المكتوبة**، ⛔ **لأن الخطأ هنا يُنشئ ديناً على مقوتٍ لم
///      يشترِ شيئاً** (`outflow-design.md` §10: «**الخطأ الأخطر المتوقَّع**»).
///   ② **`GR-43`:** ⛔⛔ **من يملك مفاتيح الخرجيات وحدها لا يلمس سحبيةً
///      في أي عملية** — ★ **ولا حتى بادّعاء `ledgerType` في الحمولة**:
///      ⟵ **والسجلُّ المخزَّن هو الحَكَم.**
///   ③ **`GR-49`:** ★ **تاريخُ السند وتاريخُ المخزون حقلان مستقلان** —
///      ⟵ **وخلطُهما يُنتج تقريراً مالياً صحيحاً بمخزونٍ خاطئ.**
/// ═══════════════════════════════════════════════════════════════════════
library;

import 'package:qtms_domain/qtms_domain.dart';
import 'package:qtms_functions/src/callable.dart';
import 'package:qtms_functions/src/identity_claims.dart';
import 'package:qtms_functions/src/identity_gateway.dart';
import 'package:qtms_functions/src/inventory.dart';
import 'package:qtms_functions/src/outflow.dart';
import 'package:test/test.dart';

const String actorUid = 'uid-owner';
const String sourceA = 'SRC-001';
const String sourceB = 'SRC-002';
const String itemA = 'ITM-0001';
const String withdrawalNumber = 'WDR-20260901-0001';
const String expenseNumber = 'EXP-20260901-0001';

final CalendarDay day = CalendarDay(2026, 9, 1);

/// ★ كلُّ مفاتيح السجلَّين — **لاختبارات ما ليس تفويضاً**.
const Set<Permission> fullPermissions = <Permission>{
  Permission.withdrawalCreate,
  Permission.withdrawalAmend,
  Permission.withdrawalCancel,
  Permission.withdrawalQatPriceNow,
  Permission.withdrawalBackdate,
  Permission.expenseCreate,
  Permission.expenseAmend,
  Permission.expenseCancel,
  Permission.expenseQatPriceNow,
  Permission.expenseBackdate,
};

/// ⛔⛔★★★ **مفاتيح الخرجيات وحدها** — ★ **وهي جوهر `GR-43`**.
const Set<Permission> expenseOnly = <Permission>{
  Permission.expenseCreate,
  Permission.expenseAmend,
  Permission.expenseCancel,
  Permission.expenseQatPriceNow,
  Permission.expenseBackdate,
};

/// ⛔ **مفاتيح السحبيات وحدها.**
const Set<Permission> withdrawalOnly = <Permission>{
  Permission.withdrawalCreate,
  Permission.withdrawalAmend,
  Permission.withdrawalCancel,
  Permission.withdrawalQatPriceNow,
  Permission.withdrawalBackdate,
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

OutflowQatLineInput qatLine({
  String itemId = itemA,
  int quantity = 5,
  int? unitPrice = 1500,
  String? sackId,
}) =>
    OutflowQatLineInput(
      itemId: itemId,
      itemName: 'عوارض',
      unit: ItemUnit.piece,
      quantity: PieceQuantity(PieceCount(quantity)),
      unitPrice: unitPrice == null ? null : Money(unitPrice),
      sackId: sackId,
    );

OutflowCashLineInput cashLine({
  OutflowLineKind kind = OutflowLineKind.amount,
  int amount = 20000,
  String? description,
}) =>
    OutflowCashLineInput(
      kind: kind,
      amount: Money(amount),
      description: description,
    );

ValidatedOutflow payload({
  OutflowLedgerType ledgerType = OutflowLedgerType.withdrawal,
  String sourceId = sourceA,
  OutflowCategory? category,
  List<OutflowQatLineInput>? qatLines,
  List<OutflowCashLineInput> cashLines = const <OutflowCashLineInput>[],
}) =>
    (validateOutflow(
      OutflowInput(
        ledgerType: ledgerType,
        sourceId: sourceId,
        category: category ??
            (ledgerType == OutflowLedgerType.withdrawal
                ? OutflowCategory.withdrawalQat
                : OutflowCategory.expenseQatForShares),
        qatLines: qatLines ?? <OutflowQatLineInput>[qatLine()],
        cashLines: cashLines,
      ),
    ) as Success<ValidatedOutflow>)
        .value;

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

OutflowRequest request({
  AccountRecord? actor,
  ValidatedOutflow? outflow,
  OutflowLedgerType ledgerType = OutflowLedgerType.withdrawal,
  Map<String, Object?>? storedSource = const <String, Object?>{
    'isActive': true,
    'name': 'مصدر الاختبار',
  },
  Map<String, Object?>? storedDocument,
  Map<String, ItemRead>? items,
  Map<String, List<LedgerRead>>? ledger,
  String? reason,
  String sourceId = sourceA,
  String? number,
  CalendarDay? documentDate,
  CalendarDay? stockDate,
  CalendarDay? today,
}) =>
    OutflowRequest(
      actor: actor ?? account(),
      requestId: 'req-1',
      ledgerType: ledgerType,
      sourceId: sourceId,
      documentNumber: number ??
          (ledgerType == OutflowLedgerType.withdrawal
              ? withdrawalNumber
              : expenseNumber),
      documentDate: documentDate ?? day,
      stockDate: stockDate ?? day,
      today: today ?? day,
      outflow: outflow,
      storedSource: storedSource,
      storedDocument: storedDocument,
      items: items ?? <String, ItemRead>{itemA: item()},
      // ★ **مخزونٌ افتراضي وافر** — ⟵ **فاختبارات التفويض تفشل على التفويض
      //   لا على نقص الرصيد**، ⛔ **ونجاحٌ لسببٍ خاطئ أسوأ من فشل.**
      ledger: ledger ??
          <String, List<LedgerRead>>{
            itemA: <LedgerRead>[movement('seed-a', 1000)],
          },
      reason: reason,
    );

/// ★ مستندٌ مخزَّنٌ للتعديل والإلغاء.
Map<String, Object?> stored({
  OutflowLedgerType ledgerType = OutflowLedgerType.withdrawal,
  String sourceId = sourceA,
  String status = 'approved',
  int ledgerEntryCount = 1,
  String category = 'withdrawalQat',
}) =>
    <String, Object?>{
      'documentNumber': ledgerType == OutflowLedgerType.withdrawal
          ? withdrawalNumber
          : expenseNumber,
      'ledgerType': ledgerType.name,
      'category': category,
      'sourceId': sourceId,
      documentStatusField: status,
      'ledgerEntryCount': ledgerEntryCount,
    };

OutflowAccepted accept(OutflowPlan plan) {
  expect(plan, isA<OutflowAccepted>(), reason: 'كان يجب أن يُقبَل');
  return plan as OutflowAccepted;
}

CallableError rejection(OutflowPlan plan) {
  expect(plan, isA<OutflowRejected>(), reason: 'كان يجب أن يُرفَض');
  return (plan as OutflowRejected).error;
}

Set<String> collectionsOf(OutflowAccepted accepted) => <String>{
      for (final InventoryWrite write in accepted.writes) write.collectionId,
    };

List<InventoryWrite> writesIn(OutflowAccepted accepted, String collection) =>
    <InventoryWrite>[
      for (final InventoryWrite write in accepted.writes)
        if (write.collectionId == collection) write,
    ];

void main() {
  // ═══════════════════════════════════════════════════════════════════════
  // ⛔⛔★★★ `GR-43` — الفصلُ بين السجلَّين: أخطرُ ما في هذه الزيادة
  // ═══════════════════════════════════════════════════════════════════════
  group('GR-43 · FR-M22-03 — صلاحياتٌ منفصلة تماماً', () {
    test('⛔⛔★★★ حاملُ مفاتيح الخرجيات وحدها لا يُنشئ سحبية', () {
      expect(
        rejection(
          planOutflow(
            request(
              actor: account(permissions: expenseOnly),
              outflow: payload(),
            ),
            OutflowOperation.createOutflow,
          ),
        ),
        CallableError.permissionMissing,
      );
    });

    test('⛔⛔★★★ وحاملُ مفاتيح السحبيات وحدها لا يُنشئ خرجية', () {
      expect(
        rejection(
          planOutflow(
            request(
              actor: account(permissions: withdrawalOnly),
              ledgerType: OutflowLedgerType.expense,
              outflow: payload(ledgerType: OutflowLedgerType.expense),
            ),
            OutflowOperation.createOutflow,
          ),
        ),
        CallableError.permissionMissing,
      );
    });

    test('★ وكلٌّ يُنشئ في سجلِّه', () {
      expect(
        accept(
          planOutflow(
            request(
              actor: account(permissions: withdrawalOnly),
              outflow: payload(),
            ),
            OutflowOperation.createOutflow,
          ),
        ).ledgerType,
        OutflowLedgerType.withdrawal,
      );
      expect(
        accept(
          planOutflow(
            request(
              actor: account(permissions: expenseOnly),
              ledgerType: OutflowLedgerType.expense,
              outflow: payload(ledgerType: OutflowLedgerType.expense),
            ),
            OutflowOperation.createOutflow,
          ),
        ).ledgerType,
        OutflowLedgerType.expense,
      );
    });

    test(
      '⛔⛔★★★ ولا يُعدَّل سندُ سحبيةٍ بادّعاء «خرجية» — السجلُّ المخزَّن هو الحَكَم',
      () {
        // ★★★ **هذا أخطرُ مسارِ تصعيدِ امتيازٍ في الزيادة:** ⟵ **المُنفِّذ
        //    يملك `expenseAmend` فيجتاز البوابةَ المسبقة على السجل المُدَّعى**،
        //    ⛔ **ثم يُرفَض على السجل المخزَّن قبل أي كتابة.**
        expect(
          rejection(
            planOutflow(
              request(
                actor: account(permissions: expenseOnly),
                ledgerType: OutflowLedgerType.expense,
                number: expenseNumber,
                outflow: payload(ledgerType: OutflowLedgerType.expense),
                // ⛔ **والمخزَّن سحبيةٌ لا خرجية.**
                storedDocument: stored(),
              ),
              OutflowOperation.amendOutflow,
            ),
          ),
          CallableError.permissionMissing,
        );
      },
    );

    test('⛔⛔ ولا يُلغى سندُ سحبيةٍ بمفتاح إلغاء الخرجيات', () {
      expect(
        rejection(
          planOutflow(
            request(
              actor: account(permissions: expenseOnly),
              ledgerType: OutflowLedgerType.expense,
              number: expenseNumber,
              storedDocument: stored(),
              ledger: const <String, List<LedgerRead>>{},
            ),
            OutflowOperation.cancelOutflow,
          ),
        ),
        CallableError.permissionMissing,
      );
    });

    test('★★ وستةُ مفاتيحَ للعمليات الثلاث في السجلَّين — بلا تداخل', () {
      expect(
        outflowPermission(
          ledgerType: OutflowLedgerType.withdrawal,
          operation: OutflowOperation.createOutflow,
        ),
        Permission.withdrawalCreate,
      );
      expect(
        outflowPermission(
          ledgerType: OutflowLedgerType.expense,
          operation: OutflowOperation.cancelOutflow,
        ),
        Permission.expenseCancel,
      );
      expect(
        <Permission>{
          for (final OutflowLedgerType ledger in OutflowLedgerType.values)
            for (final OutflowOperation op in OutflowOperation.values)
              outflowPermission(ledgerType: ledger, operation: op),
        },
        hasLength(6),
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // ⛔⛔★★★ `FR-M22-04` · `GR-44` — لا مساس بدفتر المقاوته
  // ═══════════════════════════════════════════════════════════════════════
  group('GR-44 — ⛔ ولا قيدَ واحدٌ في دفتر المقاوته', () {
    test('⛔⛔★★★ الإنشاء لا يكتب في `dealer_ledger` ولا `dealer_balances`', () {
      final OutflowAccepted accepted = accept(
        planOutflow(
          request(
            outflow: payload(
              qatLines: <OutflowQatLineInput>[qatLine()],
              cashLines: <OutflowCashLineInput>[cashLine()],
            ),
          ),
          OutflowOperation.createOutflow,
        ),
      );
      expect(collectionsOf(accepted), isNot(contains(dealerLedgerCollection)));
      expect(
        collectionsOf(accepted),
        isNot(contains(dealerBalancesCollection)),
      );
    });

    test('★ والمجموعاتُ المكتوبة أربعٌ بالضبط — ⛔ ولا خامسة', () {
      final OutflowAccepted accepted = accept(
        planOutflow(
          request(outflow: payload()),
          OutflowOperation.createOutflow,
        ),
      );
      expect(
        collectionsOf(accepted),
        <String>{
          outflowsCollection,
          inventoryLedgerCollection,
          itemDailyBalancesCollection,
          outflowLedgerCollection,
        },
      );
    });

    test('⛔ والإلغاء كذلك لا يمسّ دفتر المقاوته', () {
      final OutflowAccepted accepted = accept(
        planOutflow(
          request(
            storedDocument: stored(),
            ledger: <String, List<LedgerRead>>{
              itemA: <LedgerRead>[
                movement(
                  stockMovementId(
                    documentNumber: withdrawalNumber,
                    itemKey: itemA,
                  ),
                  5,
                  direction: MovementDirection.outgoing,
                ),
                movement('seed-a', 1000),
              ],
            },
          ),
          OutflowOperation.cancelOutflow,
        ),
      );
      expect(collectionsOf(accepted), isNot(contains(dealerLedgerCollection)));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // ⛔⛔★★★ `GR-42` · `E-28` — المصدر إلزاميٌّ دائماً
  // ═══════════════════════════════════════════════════════════════════════
  group('GR-42 · FR-M22-02 · ERR_OUT_001 — المصدر إلزامي', () {
    test('⛔⛔ سندٌ بمصدرٍ فارغٍ يُرفَض برمزه المستقل', () {
      expect(
        rejection(
          planOutflow(
            request(sourceId: '   ', outflow: payload()),
            OutflowOperation.createOutflow,
          ),
        ),
        CallableError.outflowSourceMissing,
      );
    });

    test('★ ورمزُه `ERR_OUT_001` — ⛔ لا `ERR_CALL_400` العام', () {
      expect(CallableError.outflowSourceMissing.code, 'ERR_OUT_001');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // ★★ التفويض والنطاق والحالة
  // ═══════════════════════════════════════════════════════════════════════
  group('البوابة — الحساب والنطاق', () {
    test('⛔ حسابٌ معطَّل يُرفَض قبل كل شيء', () {
      expect(
        rejection(
          planOutflow(
            request(actor: account(disabled: true), outflow: payload()),
            OutflowOperation.createOutflow,
          ),
        ),
        CallableError.accountDisabled,
      );
    });

    test('⛔⛔ ومصدرٌ خارج النطاق يُرفَض ولو مُلكت كل المفاتيح — GR-23', () {
      expect(
        rejection(
          planOutflow(
            request(
              actor: account(scope: ScopedSources(<String>{sourceB})),
              outflow: payload(),
            ),
            OutflowOperation.createOutflow,
          ),
        ),
        CallableError.sourceOutOfScope,
      );
    });

    test('⛔ ومستندٌ مخزَّنٌ لمصدرٍ آخر يُرفَض — ⛔ والمخزَّن هو الحَكَم', () {
      expect(
        rejection(
          planOutflow(
            request(
              outflow: payload(),
              storedDocument: stored(sourceId: sourceB),
            ),
            OutflowOperation.amendOutflow,
          ),
        ),
        CallableError.sourceOutOfScope,
      );
    });

    test('⛔ ومصدرٌ معطَّل يمنع الإنشاء — ★ ولا يمنع الإلغاء', () {
      const Map<String, Object?> inactive = <String, Object?>{
        'isActive': false,
        'name': 'مصدر معطَّل',
      };
      expect(
        rejection(
          planOutflow(
            request(outflow: payload(), storedSource: inactive),
            OutflowOperation.createOutflow,
          ),
        ),
        CallableError.sourceInactive,
      );
      expect(
        planOutflow(
          request(
            storedSource: inactive,
            storedDocument: stored(),
            ledger: const <String, List<LedgerRead>>{},
          ),
          OutflowOperation.cancelOutflow,
        ),
        isA<OutflowAccepted>(),
      );
    });

    test('⛔ ومستندٌ ملغى لا يُعدَّل ولا يُلغى ثانيةً', () {
      expect(
        rejection(
          planOutflow(
            request(
              outflow: payload(),
              storedDocument: stored(status: 'cancelled'),
            ),
            OutflowOperation.amendOutflow,
          ),
        ),
        CallableError.documentCancelled,
      );
    });

    test('⛔ ورقمٌ مخصَّصٌ يقابله مستندٌ قائم تصادمُ عدّاد', () {
      expect(
        rejection(
          planOutflow(
            request(outflow: payload(), storedDocument: stored()),
            OutflowOperation.createOutflow,
          ),
        ),
        CallableError.concurrency,
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // ★★★ `FR-M22-08` · `ERR_OUT_002` — تسعير القات الآن بمفتاحه
  // ═══════════════════════════════════════════════════════════════════════
  group('FR-M22-08 · ERR_OUT_002 — مفتاحُ تسعير القات', () {
    test('⛔⛔ سعرٌ بلا مفتاحه يُرفَض برمزه المستقل', () {
      expect(
        rejection(
          planOutflow(
            request(
              actor: account(
                permissions: const <Permission>{Permission.withdrawalCreate},
              ),
              outflow: payload(),
            ),
            OutflowOperation.createOutflow,
          ),
        ),
        CallableError.outflowPricingNotAllowed,
      );
    });

    test('★★★ وبلا سعرٍ يُقبَل من الشخص نفسِه — ⛔ فالمنعُ للحقل لا للسند', () {
      final OutflowAccepted accepted = accept(
        planOutflow(
          request(
            actor: account(
              permissions: const <Permission>{Permission.withdrawalCreate},
            ),
            outflow: payload(
              qatLines: <OutflowQatLineInput>[qatLine(unitPrice: null)],
            ),
          ),
          OutflowOperation.createOutflow,
        ),
      );
      expect(accepted.unpricedItemCount, 1);
    });

    test('⛔⛔★★ ولا يُغني مفتاحُ سجلٍّ عن الآخر — GR-43', () {
      expect(
        rejection(
          planOutflow(
            request(
              // ★ **يملك تسعيرَ الخرجيات ويُنشئ سحبيةً مسعَّرة.**
              actor: account(
                permissions: const <Permission>{
                  Permission.withdrawalCreate,
                  Permission.expenseQatPriceNow,
                },
              ),
              outflow: payload(),
            ),
            OutflowOperation.createOutflow,
          ),
        ),
        CallableError.outflowPricingNotAllowed,
      );
    });

    test('⛔⛔★★★ والتعديلُ يُفحَص كذلك — ⛔ فلا بابَ خلفيّ', () {
      // ★★ **وإلا لأمكن حفظُ سندٍ بلا سعرٍ ثم تسعيرُه بتعديلٍ من غير مالك
      //    المفتاح** — ⟵ **وهو بابٌ خلفيٌّ للقاعدة كلِّها.**
      expect(
        rejection(
          planOutflow(
            request(
              actor: account(
                permissions: const <Permission>{Permission.withdrawalAmend},
              ),
              outflow: payload(),
              storedDocument: stored(),
            ),
            OutflowOperation.amendOutflow,
          ),
        ),
        CallableError.outflowPricingNotAllowed,
      );
    });

    test('★ ورمزُه `ERR_OUT_002` بحالة منعِ صلاحية', () {
      expect(CallableError.outflowPricingNotAllowed.code, 'ERR_OUT_002');
      expect(
        CallableError.outflowPricingNotAllowed.status,
        'PERMISSION_DENIED',
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // ★★★ `FR-M22-09` · `AT-56` — التاريخ
  // ═══════════════════════════════════════════════════════════════════════
  group('FR-M22-09 · AT-56 — تاريخ السند', () {
    test('⛔⛔ المستقبليُّ مرفوضٌ ولو مُلكت كلُّ المفاتيح', () {
      expect(
        rejection(
          planOutflow(
            request(
              outflow: payload(),
              documentDate: CalendarDay(2026, 9, 5),
              today: day,
            ),
            OutflowOperation.createOutflow,
          ),
        ),
        CallableError.invalidArgument,
      );
    });

    test('⛔ والسابقُ بلا مفتاحه يُرفَض بنقص صلاحية', () {
      expect(
        rejection(
          planOutflow(
            request(
              actor: account(
                permissions: const <Permission>{
                  Permission.withdrawalCreate,
                  Permission.withdrawalQatPriceNow,
                },
              ),
              outflow: payload(),
              documentDate: CalendarDay(2026, 8, 28),
              today: day,
            ),
            OutflowOperation.createOutflow,
          ),
        ),
        CallableError.permissionMissing,
      );
    });

    test('★ والسابقُ بمفتاحه يُقبَل', () {
      expect(
        accept(
          planOutflow(
            request(
              outflow: payload(),
              documentDate: CalendarDay(2026, 8, 28),
              today: day,
            ),
            OutflowOperation.createOutflow,
          ),
        ).documentNumber,
        withdrawalNumber,
      );
    });

    test('⛔⛔★★ ولا يُغني مفتاحُ سجلٍّ عن الآخر في التاريخ كذلك', () {
      expect(
        rejection(
          planOutflow(
            request(
              actor: account(
                permissions: const <Permission>{
                  Permission.withdrawalCreate,
                  Permission.withdrawalQatPriceNow,
                  Permission.expenseBackdate,
                },
              ),
              outflow: payload(),
              documentDate: CalendarDay(2026, 8, 28),
              today: day,
            ),
            OutflowOperation.createOutflow,
          ),
        ),
        CallableError.permissionMissing,
      );
    });

    test('★ ولا يُفحَص التاريخُ في الإلغاء — فالإلغاءُ لا يُغيِّره', () {
      expect(
        planOutflow(
          request(
            actor: account(permissions: withdrawalOnly),
            storedDocument: stored(),
            documentDate: CalendarDay(2026, 8, 1),
            today: day,
            ledger: const <String, List<LedgerRead>>{},
          ),
          OutflowOperation.cancelOutflow,
        ),
        isA<OutflowAccepted>(),
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // ⛔⛔★★★ `GR-49` — تاريخان مستقلان
  // ═══════════════════════════════════════════════════════════════════════
  group('GR-49 · FR-M22-10 — التمييز التاريخي', () {
    test('★★★ حركةُ المخزون على `stockDate` وسطرُ الدفتر على `documentDate`',
        () {
      final OutflowAccepted accepted = accept(
        planOutflow(
          request(
            outflow: payload(),
            documentDate: CalendarDay(2026, 8, 28),
            stockDate: day,
            today: day,
          ),
          OutflowOperation.createOutflow,
        ),
      );
      final InventoryWrite movementWrite =
          writesIn(accepted, inventoryLedgerCollection).single;
      final InventoryWrite ledgerWrite =
          writesIn(accepted, outflowLedgerCollection).single;

      expect(movementWrite.fields['stockDate'], day.asUtcMidnight());
      expect(
        ledgerWrite.fields['documentDate'],
        CalendarDay(2026, 8, 28).asUtcMidnight(),
      );
      // ★ **وسطرُ القات يحمل التاريخين معاً** — ⟵ **فيُقرأ مالياً ومخزنياً.**
      expect(ledgerWrite.fields['stockDate'], day.asUtcMidnight());
    });

    test('★★ والمستندُ نفسُه يحمل الحقلين مستقلَّين', () {
      final OutflowAccepted accepted = accept(
        planOutflow(
          request(
            outflow: payload(),
            documentDate: CalendarDay(2026, 8, 28),
            stockDate: day,
            today: day,
          ),
          OutflowOperation.createOutflow,
        ),
      );
      final InventoryWrite doc = writesIn(accepted, outflowsCollection).single;
      expect(
        doc.fields['documentDate'],
        CalendarDay(2026, 8, 28).asUtcMidnight(),
      );
      expect(doc.fields['stockDate'], day.asUtcMidnight());
    });

    test('⛔ وسطرُ المبلغ بلا `stockDate` — ★ فلا أثرَ مخزني له', () {
      final OutflowAccepted accepted = accept(
        planOutflow(
          request(
            outflow: payload(
              category: OutflowCategory.withdrawalCash,
              qatLines: const <OutflowQatLineInput>[],
              cashLines: <OutflowCashLineInput>[cashLine()],
            ),
          ),
          OutflowOperation.createOutflow,
        ),
      );
      final InventoryWrite ledgerWrite =
          writesIn(accepted, outflowLedgerCollection).single;
      expect(ledgerWrite.fields.containsKey('stockDate'), isFalse);
      expect(ledgerWrite.fields['amount'], 20000);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // ★★★ الدفتر الرابع — `GR-04` · `schema/outflow-ledger.md`
  // ═══════════════════════════════════════════════════════════════════════
  group('GR-04 — الدفتر الرابع', () {
    test('★★★ سطرٌ لكل بند — قاتاً كان أو مبلغاً', () {
      final OutflowAccepted accepted = accept(
        planOutflow(
          request(
            outflow: payload(
              qatLines: <OutflowQatLineInput>[qatLine()],
              cashLines: <OutflowCashLineInput>[
                cashLine(),
                cashLine(
                  kind: OutflowLineKind.other,
                  amount: 500,
                  description: 'أجرة نقل',
                ),
              ],
            ),
          ),
          OutflowOperation.createOutflow,
        ),
      );
      expect(writesIn(accepted, outflowLedgerCollection), hasLength(3));
    });

    test('★★★ وكلُّ سطرٍ يحمل مصدرَه وسجلَّه — GR-42 · GR-43', () {
      final OutflowAccepted accepted = accept(
        planOutflow(
          request(
            ledgerType: OutflowLedgerType.expense,
            outflow: payload(ledgerType: OutflowLedgerType.expense),
          ),
          OutflowOperation.createOutflow,
        ),
      );
      for (final InventoryWrite write
          in writesIn(accepted, outflowLedgerCollection)) {
        expect(write.fields['sourceId'], sourceA);
        expect(write.fields['ledgerType'], 'expense');
        expect(write.fields['category'], 'expenseQatForShares');
      }
    });

    test('⛔⛔★★ ونوعُ المستند يتبع السجل — درسُ `sourceDocType` المحفور', () {
      final OutflowAccepted withdrawal = accept(
        planOutflow(
          request(outflow: payload()),
          OutflowOperation.createOutflow,
        ),
      );
      final OutflowAccepted expense = accept(
        planOutflow(
          request(
            ledgerType: OutflowLedgerType.expense,
            outflow: payload(ledgerType: OutflowLedgerType.expense),
          ),
          OutflowOperation.createOutflow,
        ),
      );
      expect(
        writesIn(withdrawal, inventoryLedgerCollection)
            .single
            .fields['sourceDocType'],
        'withdrawal',
      );
      expect(
        writesIn(expense, inventoryLedgerCollection)
            .single
            .fields['sourceDocType'],
        'expense',
      );
    });

    test('⛔⛔ والسطرُ غيرُ المسعَّر بلا `lineValue` — ★ ولا يُكتب صفراً', () {
      final OutflowAccepted accepted = accept(
        planOutflow(
          request(
            outflow: payload(
              qatLines: <OutflowQatLineInput>[qatLine(unitPrice: null)],
            ),
          ),
          OutflowOperation.createOutflow,
        ),
      );
      final InventoryWrite ledgerWrite =
          writesIn(accepted, outflowLedgerCollection).single;
      expect(ledgerWrite.fields.containsKey('lineValue'), isFalse);
      expect(ledgerWrite.fields.containsKey('unitPrice'), isFalse);
    });

    test('★★★ والسطورُ الزائدة بعد التعديل تُوسَم ملغاة ⛔ ولا تُحذَف', () {
      // ★★ **سندٌ كان بثلاثة سطور فصار سطرين** — ⟵ **والثالثُ يُوسَم**،
      //    ⛔ **وإبقاؤه حيّاً كان يُبقي قيمتَه في تقرير المصدر إلى الأبد.**
      final OutflowAccepted accepted = accept(
        planOutflow(
          request(
            outflow: payload(),
            storedDocument: stored(ledgerEntryCount: 3),
          ),
          OutflowOperation.amendOutflow,
        ),
      );
      final List<InventoryWrite> ledgerWrites =
          writesIn(accepted, outflowLedgerCollection);
      expect(ledgerWrites, hasLength(3));
      expect(ledgerWrites[0].fields['isCancelled'], isFalse);
      expect(ledgerWrites[1].fields['isCancelled'], isTrue);
      expect(ledgerWrites[2].fields['isCancelled'], isTrue);
      expect(
        ledgerWrites[1].documentId,
        outflowLedgerEntryId(documentNumber: withdrawalNumber, index: 1),
      );
    });

    test('★★ والإلغاءُ يَسِم كلَّ سطورِ الدفتر', () {
      final OutflowAccepted accepted = accept(
        planOutflow(
          request(
            storedDocument: stored(ledgerEntryCount: 2),
            ledger: const <String, List<LedgerRead>>{},
          ),
          OutflowOperation.cancelOutflow,
        ),
      );
      final List<InventoryWrite> ledgerWrites =
          writesIn(accepted, outflowLedgerCollection);
      expect(ledgerWrites, hasLength(2));
      for (final InventoryWrite write in ledgerWrites) {
        expect(write.fields['isCancelled'], isTrue);
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // ★★ المخزون — `FR-M22-06` · `FR-M22-12` · `GR-11`
  // ═══════════════════════════════════════════════════════════════════════
  group('FR-M22-06 · FR-M22-12 — الأثر المخزني', () {
    test('★★★ بندُ القات يخرج من المخزون فعلاً', () {
      final OutflowAccepted accepted = accept(
        planOutflow(
          request(outflow: payload()),
          OutflowOperation.createOutflow,
        ),
      );
      final InventoryWrite movementWrite =
          writesIn(accepted, inventoryLedgerCollection).single;
      expect(movementWrite.fields['direction'], 'outgoing');
      expect(movementWrite.fields['quantity'], 5);
      expect(
        writesIn(accepted, itemDailyBalancesCollection).single.fields['balance'],
        995,
      );
    });

    test('⛔⛔ والكميةُ التي تتجاوز المتاح تُرفَض — GR-11', () {
      expect(
        rejection(
          planOutflow(
            request(
              outflow: payload(
                qatLines: <OutflowQatLineInput>[qatLine(quantity: 2000)],
              ),
            ),
            OutflowOperation.createOutflow,
          ),
        ),
        CallableError.insufficientStock,
      );
    });

    test('★ وسندُ المبالغِ الخالص لا يمسّ المخزون إطلاقاً', () {
      final OutflowAccepted accepted = accept(
        planOutflow(
          request(
            outflow: payload(
              category: OutflowCategory.withdrawalCash,
              qatLines: const <OutflowQatLineInput>[],
              cashLines: <OutflowCashLineInput>[cashLine()],
            ),
            ledger: const <String, List<LedgerRead>>{},
          ),
          OutflowOperation.createOutflow,
        ),
      );
      expect(
        collectionsOf(accepted),
        isNot(contains(inventoryLedgerCollection)),
      );
    });

    test('★★ و`sackId` يمرّ إلى الحركة — E-26 (سعرُ الجونية يستحقّ)', () {
      final OutflowAccepted accepted = accept(
        planOutflow(
          request(
            outflow: payload(
              qatLines: <OutflowQatLineInput>[qatLine(sackId: 'SCK-1')],
            ),
          ),
          OutflowOperation.createOutflow,
        ),
      );
      expect(
        writesIn(accepted, inventoryLedgerCollection).single.fields['sackId'],
        'SCK-1',
      );
    });

    test('⛔ ونوعٌ من مصدرٍ آخر يُرفَض — FR-M5-10', () {
      expect(
        rejection(
          planOutflow(
            request(
              outflow: payload(),
              items: <String, ItemRead>{
                itemA: item(sourceIds: const <String>[sourceB]),
              },
            ),
            OutflowOperation.createOutflow,
          ),
        ),
        CallableError.invalidArgument,
      );
    });

    test('⛔ ووحدةٌ تخالف وحدةَ النوع المخزَّنة تُرفَض — GR-19', () {
      expect(
        rejection(
          planOutflow(
            request(
              outflow: payload(),
              items: <String, ItemRead>{
                itemA: item(unit: ItemUnit.kilogram),
              },
            ),
            OutflowOperation.createOutflow,
          ),
        ),
        CallableError.itemUnitLocked,
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // ★★ المستند وإجمالياته — `GR-42` · `AT-38`
  // ═══════════════════════════════════════════════════════════════════════
  group('GR-42 · AT-38 — المستند وإجمالياته', () {
    test('★★★ سيناريو AT-38 حرفياً في المستند المكتوب', () {
      final OutflowAccepted accepted = accept(
        planOutflow(
          request(
            outflow: payload(
              qatLines: <OutflowQatLineInput>[
                qatLine(quantity: 5, unitPrice: 1500),
              ],
              cashLines: <OutflowCashLineInput>[cashLine(amount: 20000)],
            ),
          ),
          OutflowOperation.createOutflow,
        ),
      );
      final InventoryWrite doc = writesIn(accepted, outflowsCollection).single;
      expect(doc.fields['totalQatValue'], 7500);
      expect(doc.fields['totalCashValue'], 20000);
      expect(doc.fields['grandTotal'], 27500);
    });

    test('★★ وعددُ سطور الدفتر مُعلَنٌ في المستند — ⛔ بلا استعلامٍ ثانٍ', () {
      final OutflowAccepted accepted = accept(
        planOutflow(
          request(
            outflow: payload(
              qatLines: <OutflowQatLineInput>[qatLine()],
              cashLines: <OutflowCashLineInput>[cashLine(), cashLine()],
            ),
          ),
          OutflowOperation.createOutflow,
        ),
      );
      expect(
        writesIn(accepted, outflowsCollection).single.fields['ledgerEntryCount'],
        3,
      );
    });

    test('⛔⛔★★★ ومصفوفةٌ واحدة `lines[]` بحقل `itemType` — data-dictionary',
        () {
      // ⛔⛔★★ **وشكلُ المخزَّن عقدٌ لا تفصيلُ تنفيذ** — ★ **ونصُّ
      //    `data-dictionary.md` §`outflows` صريح**: ⟵ **ومصفوفتان كانتا
      //    تُجبران كلَّ قارئٍ لاحق** (تقاريرُ `WU-018`) **على معرفة أيِّهما
      //    يقرأ**، ⛔ **وهو انحرافٌ صامت عن المخطَّط المعتمد.**
      final OutflowAccepted accepted = accept(
        planOutflow(
          request(
            outflow: payload(
              qatLines: <OutflowQatLineInput>[qatLine()],
              cashLines: <OutflowCashLineInput>[cashLine()],
            ),
          ),
          OutflowOperation.createOutflow,
        ),
      );
      final Map<String, Object?> fields =
          writesIn(accepted, outflowsCollection).single.fields;
      expect(fields.containsKey('qatLines'), isFalse);
      expect(fields.containsKey('cashLines'), isFalse);

      final List<Object?> lines = fields['lines']! as List<Object?>;
      expect(lines, hasLength(2));
      expect(
        (lines[0]! as Map<String, Object?>)['itemType'],
        'qat',
      );
      expect(
        (lines[1]! as Map<String, Object?>)['itemType'],
        'amount',
      );
      // ★★ **وسطرُ القات يحمل تاريخَ مخزونه في السطر نفسِه** — `GR-49`.
      expect(
        (lines[0]! as Map<String, Object?>)['stockDate'],
        day.asUtcMidnight(),
      );
      // ⛔ **وسطرُ المبلغ بلا `stockDate`** — ★ **لا أثرَ مخزني له.**
      expect(
        (lines[1]! as Map<String, Object?>).containsKey('stockDate'),
        isFalse,
      );
    });

    test('⛔⛔ ولا حقلَ مقوتٍ في المستند المكتوب إطلاقاً — GR-44', () {
      final OutflowAccepted accepted = accept(
        planOutflow(
          request(outflow: payload()),
          OutflowOperation.createOutflow,
        ),
      );
      final Map<String, Object?> fields =
          writesIn(accepted, outflowsCollection).single.fields;
      expect(fields.containsKey('dealerId'), isFalse);
      expect(fields.containsKey('dealerName'), isFalse);
      expect(fields.containsKey('debtValue'), isFalse);
    });

    test('★ ورقمُ المستند هو معرّفه', () {
      final OutflowAccepted accepted = accept(
        planOutflow(
          request(outflow: payload()),
          OutflowOperation.createOutflow,
        ),
      );
      expect(
        writesIn(accepted, outflowsCollection).single.documentId,
        withdrawalNumber,
      );
    });

    test('★ والتعديلُ يزيد `amendCount` ⛔ ولا يُصفّره', () {
      final OutflowAccepted accepted = accept(
        planOutflow(
          request(
            outflow: payload(),
            storedDocument: <String, Object?>{
              ...stored(),
              'amendCount': 2,
            },
          ),
          OutflowOperation.amendOutflow,
        ),
      );
      expect(
        writesIn(accepted, outflowsCollection).single.fields['amendCount'],
        3,
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // ★★ قيد التدقيق — `FR-M18-04` · `GR-43`
  // ═══════════════════════════════════════════════════════════════════════
  group('قيد التدقيق', () {
    test('⛔⛔★★ ونوعُ الكيان يتبع السجل — ⛔ لا نوعٌ واحد بحقل تمييز', () {
      expect(
        accept(
          planOutflow(
            request(outflow: payload()),
            OutflowOperation.createOutflow,
          ),
        ).entry.target.entityType,
        withdrawalEntityType,
      );
      expect(
        accept(
          planOutflow(
            request(
              ledgerType: OutflowLedgerType.expense,
              outflow: payload(ledgerType: OutflowLedgerType.expense),
            ),
            OutflowOperation.createOutflow,
          ),
        ).entry.target.entityType,
        expenseEntityType,
      );
    });

    test('★ والنوعان مُدرَجان في معجم الأنواع', () {
      expect(auditEntityTypes, contains(withdrawalEntityType));
      expect(auditEntityTypes, contains(expenseEntityType));
    });

    test('★ والإلغاءُ فعلٌ مستقل في المعجم لا «تعديل»', () {
      expect(
        accept(
          planOutflow(
            request(
              storedDocument: stored(),
              ledger: const <String, List<LedgerRead>>{},
            ),
            OutflowOperation.cancelOutflow,
          ),
        ).entry.action,
        AuditAction.cancel,
      );
    });

    test('★★★ ADR-0020 — ولا رفضَ لغياب السبب في أي عملية', () {
      expect(
        planOutflow(
          request(outflow: payload(), storedDocument: stored()),
          OutflowOperation.amendOutflow,
        ),
        isA<OutflowAccepted>(),
      );
      expect(
        planOutflow(
          request(
            storedDocument: stored(),
            ledger: const <String, List<LedgerRead>>{},
          ),
          OutflowOperation.cancelOutflow,
        ),
        isA<OutflowAccepted>(),
      );
    });

    test('★ والفراغُ يُقرأ غياباً لا نصّاً فارغاً — blankToNull', () {
      expect(
        accept(
          planOutflow(
            request(
              outflow: payload(),
              storedDocument: stored(),
              reason: '   ',
            ),
            OutflowOperation.amendOutflow,
          ),
        ).entry.reason,
        isNull,
      );
    });

    test('★ ومعرّفُ الطلب هو معرّفُ القيد — لاتكراريةُ إعادة الإرسال', () {
      expect(
        accept(
          planOutflow(
            request(outflow: payload()),
            OutflowOperation.createOutflow,
          ),
        ).entry.id,
        'req-1',
      );
    });

    test('⛔ ومعرّفُ طلبٍ فارغٍ يُرفَض', () {
      expect(
        rejection(
          planOutflow(
            OutflowRequest(
              actor: account(),
              requestId: '   ',
              ledgerType: OutflowLedgerType.withdrawal,
              sourceId: sourceA,
              documentNumber: withdrawalNumber,
              documentDate: day,
              stockDate: day,
              today: day,
              outflow: payload(),
            ),
            OutflowOperation.createOutflow,
          ),
        ),
        CallableError.invalidArgument,
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // ★ قابلية التكرار بلا أثر جانبي — `coding-standards.md` §2.7
  // ═══════════════════════════════════════════════════════════════════════
  group('قابلية التكرار', () {
    test('★★ نفسُ الطلب يُنتج نفسَ الخطة حرفياً', () {
      final OutflowAccepted first = accept(
        planOutflow(
          request(outflow: payload()),
          OutflowOperation.createOutflow,
        ),
      );
      final OutflowAccepted second = accept(
        planOutflow(
          request(outflow: payload()),
          OutflowOperation.createOutflow,
        ),
      );
      expect(
        first.writes.map((InventoryWrite w) => w.documentId),
        second.writes.map((InventoryWrite w) => w.documentId),
      );
      expect(
        writesIn(first, outflowsCollection).single.fields.toString(),
        writesIn(second, outflowsCollection).single.fields.toString(),
      );
    });

    test('★ ومعرّفُ سطر الدفتر حتميٌّ من الرقم والترتيب', () {
      expect(
        outflowLedgerEntryId(documentNumber: withdrawalNumber, index: 0),
        '${withdrawalNumber}_000',
      );
      expect(
        outflowLedgerEntryId(documentNumber: expenseNumber, index: 12),
        '${expenseNumber}_012',
      );
    });
  });
}

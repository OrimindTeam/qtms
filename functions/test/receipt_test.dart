/// المقبوضات وحساب المقوت — ★★★ **حارس التفويض والنطاق والتسوية معاً**
/// (`WU-007`).
///
/// ⚠️⚠️ **ولماذا تُختبَر بهذه الصرامة:** بعد إغلاق الكتابة المباشرة
/// (`ADR-0013` القاعدة 2) **لم يبقَ بين المستخدم ودفتر الذمم إلا هذا الكود** —
/// ⟵ **فكل شرطٍ كانت تفرضه `firestore.rules` صار بند قبولٍ هنا.**
/// ★★ **ويزيد هنا شرطان لا نظير لهما في `WU-006`:**
/// **النطاق يُفحَص لكل مصدرٍ مسّه السند** (لأن «الكل» يمسّ مصادر عدة) ·
/// **والتاريخ يصل من الجهاز** (`FR-M12-02`) ⛔ **بخلاف يوم المخزون.**
library;

import 'package:qtms_domain/qtms_domain.dart';
import 'package:qtms_functions/src/callable.dart';
import 'package:qtms_functions/src/identity_claims.dart';
import 'package:qtms_functions/src/identity_gateway.dart';
import 'package:qtms_functions/src/inventory.dart';
import 'package:qtms_functions/src/receipt.dart';
import 'package:test/test.dart';

const String actorUid = 'uid-collector';
const String sourceA = 'SRC-001';
const String sourceB = 'SRC-002';
const String dealerA = 'MQT-0001';
const String docNumber = 'RCP-20260828-0001';
const String requestId = 'req-001';

final CalendarDay today = CalendarDay(2026, 8, 28);

const Set<Permission> fullPermissions = <Permission>{
  Permission.receiptCreate,
  Permission.receiptAmend,
  Permission.receiptCancel,
  Permission.receiptBackdate,
  Permission.receiptDepositView,
  Permission.receiptDepositConfirm,
};

AccountRecord account({
  Set<Permission> permissions = fullPermissions,
  SourceScope scope = const AllSources(),
  bool disabled = false,
}) =>
    AccountRecord(
      userId: actorUid,
      userName: 'محصِّل',
      claims: IdentityClaims(permissions: permissions, sourceScope: scope),
      disabled: disabled,
      cardIsActive: true,
    );

String lotIdOf(int stockDay, {String sourceId = sourceA}) => distributionId(
      dealerId: dealerA,
      sourceId: sourceId,
      stockDate: CalendarDay(2026, 8, stockDay),
    );

DebtLotRead lot(
  int stockDay, {
  String sourceId = sourceA,
  int debtValue = 30000,
  int settled = 0,
  int discounted = 0,
  bool isCancelled = false,
}) =>
    DebtLotRead(
      debtLotId: lotIdOf(stockDay, sourceId: sourceId),
      sourceId: sourceId,
      stockDate: CalendarDay(2026, 8, stockDay),
      settlement: computeDebtSettlement(
        debtValue: Money(debtValue),
        settledAmount: Money(settled),
        discountedAmount: Money(discounted),
      ),
      isCancelled: isCancelled,
    );

Map<String, DebtLotRead> lots(List<DebtLotRead> list) =>
    <String, DebtLotRead>{for (final DebtLotRead l in list) l.debtLotId: l};

ReceiptRequest request({
  AccountRecord? actor,
  CalendarDay? date,
  String? sourceFilter,
  List<ReceiptLineInput> lines = const <ReceiptLineInput>[],
  int surplus = 0,
  SurplusScope surplusScope = SurplusScope.general,
  Map<String, DebtLotRead>? storedLots,
  Map<String, Object?>? storedDealer = const <String, Object?>{'name': 'مقوت'},
  Map<String, Object?>? storedDocument,
  Map<String, Object?>? storedSurplus,
  List<ReceiptLedgerRead> dealerLedger = const <ReceiptLedgerRead>[],
  String? depositNote,
  DepositState? depositState,
  Map<String, Object?>? storedDeposit,
  String? reason,
  String documentNumber = docNumber,
  String id = requestId,
}) =>
    ReceiptRequest(
      actor: actor ?? account(),
      requestId: id,
      dealerId: dealerA,
      documentNumber: documentNumber,
      date: date ?? today,
      today: today,
      sourceFilter: sourceFilter,
      lines: lines,
      surplusAmount: Money(surplus),
      surplusScope: surplusScope,
      lots: storedLots ?? lots(<DebtLotRead>[lot(20)]),
      storedDealer: storedDealer,
      storedDocument: storedDocument,
      storedSurplus: storedSurplus,
      dealerLedger: dealerLedger,
      depositNote: depositNote,
      depositState: depositState,
      storedDeposit: storedDeposit,
      reason: reason,
    );

ReceiptAccepted accepted(ReceiptPlan plan) => plan as ReceiptAccepted;

CallableError rejection(ReceiptPlan plan) => (plan as ReceiptRejected).error;

Map<String, Object?> writeFor(
  ReceiptAccepted plan,
  String collectionId, {
  String? documentId,
}) =>
    plan.writes
        .firstWhere(
          (InventoryWrite w) =>
              w.collectionId == collectionId &&
              (documentId == null || w.documentId == documentId),
        )
        .fields;

Iterable<InventoryWrite> writesIn(ReceiptAccepted plan, String collectionId) =>
    plan.writes.where((InventoryWrite w) => w.collectionId == collectionId);

bool hasWrite(ReceiptAccepted plan, String collectionId) =>
    plan.writes.any((InventoryWrite w) => w.collectionId == collectionId);

void main() {
  // ═══════════════════════════════════════════════════════════════════════
  // ★★ البوابة
  // ═══════════════════════════════════════════════════════════════════════
  group('★★ البوابة — الحالة والصلاحية قبل أي معاملة', () {
    test('⛔ حسابٌ معطَّل يُرفض ولو ملك كل المفاتيح (`ERR_AUTH_004`)', () {
      expect(
        rejection(
          planReceipt(
            request(actor: account(disabled: true)),
            ReceiptOperation.createReceipt,
          ),
        ),
        CallableError.accountDisabled,
      );
    });

    test('⛔ وبلا `receiptCreate` يُرفض (`ERR_AUTH_001`)', () {
      expect(
        rejection(
          planReceipt(
            request(actor: account(permissions: const <Permission>{})),
            ReceiptOperation.createReceipt,
          ),
        ),
        CallableError.permissionMissing,
      );
    });

    test('⛔⛔★★ وتأكيد الإيداع يشترط رؤيتَه كذلك — صلاحيتان لا واحدة', () {
      expect(
        rejection(
          planReceipt(
            request(
              actor: account(
                permissions: const <Permission>{
                  Permission.receiptDepositConfirm,
                },
              ),
              depositNote: 'أُودع',
              depositState: DepositState.deposited,
              storedDocument: const <String, Object?>{'status': 'approved'},
            ),
            ReceiptOperation.confirmReceiptDeposit,
          ),
        ),
        CallableError.permissionMissing,
      );
    });

    test('⛔ ومعرّف طلبٍ فارغ يُرفض — ولا لاتكرارية بدونه', () {
      expect(
        rejection(
          planReceipt(request(id: '  '), ReceiptOperation.createReceipt),
        ),
        CallableError.invalidArgument,
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // ★★★ ② النطاق — لكل مصدرٍ مسّه السند
  // ═══════════════════════════════════════════════════════════════════════
  group('★★★ النطاق — `GR-23` · `E-35` لكل مصدرٍ على حدة', () {
    test('⛔⛔★★★ سندُ «الكل» يمسّ مصدراً خارج النطاق ⟵ يُرفَض كاملاً', () {
      // ★★ **الحارس الحقيقي:** ⟵ **المصدر الأول داخل النطاق والثاني خارجه**،
      //    ⛔ **وفحصُ الأول وحده كان يُسدِّد ديناً في مصدرٍ لا يراه المُنفِّذ.**
      final ReceiptPlan plan = planReceipt(
        request(
          actor: account(scope: ScopedSources(const <String>{sourceA})),
          storedLots: lots(<DebtLotRead>[
            lot(20),
            lot(21, sourceId: sourceB),
          ]),
          lines: <ReceiptLineInput>[
            ReceiptLineInput(debtLotId: lotIdOf(20), amount: Money(1000)),
            ReceiptLineInput(
              debtLotId: lotIdOf(21, sourceId: sourceB),
              amount: Money(1000),
            ),
          ],
        ),
        ReceiptOperation.createReceipt,
      );
      expect(rejection(plan), CallableError.sourceOutOfScope);
    });

    test('★ وضمن النطاق يمرّ', () {
      final ReceiptPlan plan = planReceipt(
        request(
          actor: account(scope: ScopedSources(const <String>{sourceA})),
          lines: <ReceiptLineInput>[
            ReceiptLineInput(debtLotId: lotIdOf(20), amount: Money(1000)),
          ],
        ),
        ReceiptOperation.createReceipt,
      );
      expect(plan, isA<ReceiptAccepted>());
    });

    test('⛔★★ وفلترُ مصدرٍ خارج النطاق مع فائضٍ وحده يُرفَض كذلك', () {
      // ⟵ **سندٌ بلا سطور لا مصادرَ متأثرة له** — ★ **فلولا فحصُ الفلتر
      //    لَمرّ فائضٌ يُقيَّد في مصدرٍ لا يملكه المُنفِّذ.**
      final ReceiptPlan plan = planReceipt(
        request(
          actor: account(scope: ScopedSources(const <String>{sourceA})),
          sourceFilter: sourceB,
          surplus: 5000,
          surplusScope: SurplusScope.source,
        ),
        ReceiptOperation.createReceipt,
      );
      expect(rejection(plan), CallableError.sourceOutOfScope);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // ★★★ ③ و④ التاريخ
  // ═══════════════════════════════════════════════════════════════════════
  group('★★★ التاريخ — `FR-M12-02` · `A-10`', () {
    test('⛔⛔★★★ مستقبليٌّ مرفوضٌ ولو ملك `receiptBackdate` (`ERR_DIST_006`)',
        () {
      expect(
        rejection(
          planReceipt(
            request(
              date: CalendarDay(2026, 8, 29),
              lines: <ReceiptLineInput>[
                ReceiptLineInput(debtLotId: lotIdOf(20), amount: Money(1000)),
              ],
            ),
            ReceiptOperation.createReceipt,
          ),
        ),
        CallableError.futureDateRejected,
      );
    });

    test('⛔ وسابقٌ بلا `receiptBackdate` ⟵ `ERR_DIST_007`', () {
      expect(
        rejection(
          planReceipt(
            request(
              actor: account(
                permissions: const <Permission>{Permission.receiptCreate},
              ),
              date: CalendarDay(2026, 8, 20),
              lines: <ReceiptLineInput>[
                ReceiptLineInput(debtLotId: lotIdOf(20), amount: Money(1000)),
              ],
            ),
            ReceiptOperation.createReceipt,
          ),
        ),
        CallableError.backdateDenied,
      );
    });

    test('★ وسابقٌ بمفتاحه يمرّ — `E-14`', () {
      expect(
        planReceipt(
          request(
            date: CalendarDay(2026, 8, 20),
            lines: <ReceiptLineInput>[
              ReceiptLineInput(debtLotId: lotIdOf(20), amount: Money(1000)),
            ],
          ),
          ReceiptOperation.createReceipt,
        ),
        isA<ReceiptAccepted>(),
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // ★★★ ⑤ حركة دائنة لكل سطر — AT-29
  // ═══════════════════════════════════════════════════════════════════════
  group('★★★ AT-29 — حركة دائنة لكل سطر بمصدرها الصحيح', () {
    ReceiptAccepted twoSources() => accepted(
          planReceipt(
            request(
              storedLots: lots(<DebtLotRead>[
                lot(20),
                lot(21, sourceId: sourceB, debtValue: 50000),
              ]),
              lines: <ReceiptLineInput>[
                ReceiptLineInput(debtLotId: lotIdOf(20), amount: Money(30000)),
                ReceiptLineInput(
                  debtLotId: lotIdOf(21, sourceId: sourceB),
                  amount: Money(20000),
                ),
              ],
            ),
            ReceiptOperation.createReceipt,
          ),
        );

    test('★★★ سطران ⟵ حركتان دائنتان ⛔ لا حركةٌ مجمّعة', () {
      final Iterable<InventoryWrite> entries =
          writesIn(twoSources(), dealerLedgerCollection);
      expect(entries.length, 2);
      for (final InventoryWrite entry in entries) {
        expect(entry.fields['direction'], DealerLedgerDirection.credit.name);
        expect(entry.fields['entryType'], DealerLedgerEntryType.receipt.name);
      }
    });

    test('★★★ وكلٌّ على مصدره ⛔ لا على مصدرٍ واحد', () {
      final Set<Object?> sources = <Object?>{
        for (final InventoryWrite w
            in writesIn(twoSources(), dealerLedgerCollection))
          w.fields['sourceId'],
      };
      expect(sources, <String>{sourceA, sourceB});
    });

    test('★★★ ورصيدٌ لكل مصدر ⛔ لا رصيدٌ جامع (`GR-20`)', () {
      final Iterable<InventoryWrite> balances =
          writesIn(twoSources(), dealerBalancesCollection);
      expect(balances.length, 2);
      expect(
        balances.map((InventoryWrite w) => w.documentId).toSet(),
        <String>{
          dealerBalanceId(dealerId: dealerA, sourceId: sourceA),
          dealerBalanceId(dealerId: dealerA, sourceId: sourceB),
        },
      );
    });

    test('★★ ومعرّفُ القيد مشتقٌّ ⟵ فإعادةُ الإرسال تكتب فوقه لا بجانبه', () {
      expect(
        writesIn(twoSources(), dealerLedgerCollection)
            .map((InventoryWrite w) => w.documentId)
            .toSet(),
        <String>{
          receiptLedgerEntryId(
            documentNumber: docNumber,
            debtLotId: lotIdOf(20),
          ),
          receiptLedgerEntryId(
            documentNumber: docNumber,
            debtLotId: lotIdOf(21, sourceId: sourceB),
          ),
        },
      );
    });

    test('★★ والرصيد يُجمَع من قيود مصدره وحدها', () {
      final ReceiptAccepted plan = accepted(
        planReceipt(
          request(
            lines: <ReceiptLineInput>[
              ReceiptLineInput(debtLotId: lotIdOf(20), amount: Money(10000)),
            ],
            dealerLedger: <ReceiptLedgerRead>[
              // ★ **ضمارٌ مدينٌ قائم في نفس المصدر** — ⟵ **يدخل الجمع.**
              const ReceiptLedgerRead(
                entryId: 'DST-1_debt',
                sourceId: sourceA,
                entry: DealerLedgerEntry(
                  direction: DealerLedgerDirection.debit,
                  amount: Money(30000),
                  isCancelled: false,
                ),
              ),
              // ⛔ **وقيدُ مصدرٍ آخر لا يدخل رصيد هذا المصدر** (`GR-20`).
              const ReceiptLedgerRead(
                entryId: 'DST-2_debt',
                sourceId: sourceB,
                entry: DealerLedgerEntry(
                  direction: DealerLedgerDirection.debit,
                  amount: Money(999999),
                  isCancelled: false,
                ),
              ),
            ],
          ),
          ReceiptOperation.createReceipt,
        ),
      );
      final Map<String, Object?> balance = writeFor(
        plan,
        dealerBalancesCollection,
        documentId: dealerBalanceId(dealerId: dealerA, sourceId: sourceA),
      );
      expect(balance['totalDebit'], 30000);
      expect(balance['totalCredit'], 10000);
      expect(balance['balance'], 20000);
    });

    test('⛔ والقيد الملغى لا يدخل الجمع — `A-14`', () {
      final ReceiptAccepted plan = accepted(
        planReceipt(
          request(
            lines: <ReceiptLineInput>[
              ReceiptLineInput(debtLotId: lotIdOf(20), amount: Money(10000)),
            ],
            dealerLedger: <ReceiptLedgerRead>[
              const ReceiptLedgerRead(
                entryId: 'DST-1_debt',
                sourceId: sourceA,
                entry: DealerLedgerEntry(
                  direction: DealerLedgerDirection.debit,
                  amount: Money(30000),
                  isCancelled: true,
                ),
              ),
            ],
          ),
          ReceiptOperation.createReceipt,
        ),
      );
      expect(
        writeFor(plan, dealerBalancesCollection)['totalDebit'],
        0,
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // ★★★ ⑥ و⑦ التسوية — IQ-027
  // ═══════════════════════════════════════════════════════════════════════
  group('★★★ التسوية — المبالغ في `pricing/current` والحالة في الأب', () {
    ReceiptAccepted settle(int amount) => accepted(
          planReceipt(
            request(
              lines: <ReceiptLineInput>[
                ReceiptLineInput(debtLotId: lotIdOf(20), amount: Money(amount)),
              ],
            ),
            ReceiptOperation.createReceipt,
          ),
        );

    test('★★★ المسدَّد والمتبقي في المستند الفرعي وحده (`IQ-027` الخيار أ)',
        () {
      final Map<String, Object?> pricing = writeFor(
        settle(10000),
        '$distributionsCollection/${lotIdOf(20)}'
        '/$distributionPricingSubcollection',
      );
      expect(pricing['settledAmount'], 10000);
      expect(pricing['remaining'], 20000);
      expect(pricing['discountedAmount'], 0);
    });

    test('⛔⛔★★★ ولا مبلغَ واحدٍ في الأب — الحارسُ الحقيقي', () {
      final Map<String, Object?> parent = writeFor(
        settle(10000),
        distributionsCollection,
        documentId: lotIdOf(20),
      );
      expect(parent.containsKey('settledAmount'), isFalse);
      expect(parent.containsKey('remaining'), isFalse);
      expect(parent.containsKey('discountedAmount'), isFalse);
      // ★ **والحالة وحدها هناك** — **حالةٌ لا رقم**.
      expect(parent['settlementStatus'], SettlementStatus.partiallyOpen.name);
    });

    test('★★ وسدادٌ كامل ⟵ «مغلق»', () {
      final Map<String, Object?> parent = writeFor(
        settle(30000),
        distributionsCollection,
        documentId: lotIdOf(20),
      );
      expect(parent['settlementStatus'], SettlementStatus.closed.name);
    });

    test('⛔★★ وقناعُ التسعير ضيّقٌ ⟵ فلا يُمحى `debtValue` ولا الأسعار', () {
      final InventoryWrite write = settle(10000).writes.firstWhere(
            (InventoryWrite w) => w.collectionId.endsWith(
              distributionPricingSubcollection,
            ),
          );
      expect(
        write.updateMask.toSet(),
        <String>{'settledAmount', 'discountedAmount', 'remaining'},
      );
    });

    test('⛔⛔ ومبلغٌ يتجاوز المتبقي ⟵ `ERR_DIST_004`', () {
      expect(
        rejection(
          planReceipt(
            request(
              lines: <ReceiptLineInput>[
                ReceiptLineInput(debtLotId: lotIdOf(20), amount: Money(30001)),
              ],
            ),
            ReceiptOperation.createReceipt,
          ),
        ),
        CallableError.receiptExceedsDebt,
      );
    });

    test('⛔★★ وضمارٌ ملغى ليس محلاً للسداد', () {
      expect(
        planReceipt(
          request(
            storedLots: lots(<DebtLotRead>[lot(20, isCancelled: true)]),
            lines: <ReceiptLineInput>[
              ReceiptLineInput(debtLotId: lotIdOf(20), amount: Money(1000)),
            ],
          ),
          ReceiptOperation.createReceipt,
        ),
        isA<ReceiptRejected>(),
      );
    });

    test('⛔⛔★★ وضمارٌ لم يُسعَّر متبقّيه صفر ⟵ لا يُسدَّد (`FR-M10-08`)', () {
      expect(
        rejection(
          planReceipt(
            request(
              storedLots: lots(<DebtLotRead>[lot(20, debtValue: 0)]),
              lines: <ReceiptLineInput>[
                ReceiptLineInput(debtLotId: lotIdOf(20), amount: Money(1)),
              ],
            ),
            ReceiptOperation.createReceipt,
          ),
        ),
        CallableError.receiptExceedsDebt,
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // ★★★ الفائض
  // ═══════════════════════════════════════════════════════════════════════
  group('★★★ الفائض — `FR-M12-09` … `FR-M12-12`', () {
    test('★★★ AT-30 — فائضٌ يُسجَّل بمفتاح نطاقه', () {
      final ReceiptAccepted plan = accepted(
        planReceipt(
          request(
            sourceFilter: sourceA,
            surplusScope: SurplusScope.source,
            surplus: 20000,
            lines: <ReceiptLineInput>[
              ReceiptLineInput(debtLotId: lotIdOf(20), amount: Money(30000)),
            ],
          ),
          ReceiptOperation.createReceipt,
        ),
      );
      final InventoryWrite surplus = plan.writes
          .firstWhere((InventoryWrite w) => w.collectionId ==
              dealerSurplusCollection);
      expect(surplus.documentId, 'MQT-0001_SRC-001');
      expect(surplus.fields['scope'], SurplusScope.source.name);
    });

    test('★★ والعامُّ بمفتاح `general`', () {
      final ReceiptAccepted plan = accepted(
        planReceipt(
          request(surplus: 20000),
          ReceiptOperation.createReceipt,
        ),
      );
      expect(
        writesIn(plan, dealerSurplusCollection).single.documentId,
        'MQT-0001_general',
      );
    });

    test('★★★ FR-M12-10 — فائضٌ وحده بلا سطر يُقبَل', () {
      expect(
        planReceipt(request(surplus: 20000), ReceiptOperation.createReceipt),
        isA<ReceiptAccepted>(),
      );
    });

    test('⛔ وسندٌ فارغٌ تماماً يُرفَض', () {
      expect(
        rejection(planReceipt(request(), ReceiptOperation.createReceipt)),
        CallableError.invalidArgument,
      );
    });

    test('⛔★★ ولا سجلَ فائضٍ بصفر (`ADR-0008` القاعدة 5)', () {
      final ReceiptAccepted plan = accepted(
        planReceipt(
          request(
            lines: <ReceiptLineInput>[
              ReceiptLineInput(debtLotId: lotIdOf(20), amount: Money(1000)),
            ],
          ),
          ReceiptOperation.createReceipt,
        ),
      );
      expect(hasWrite(plan, dealerSurplusCollection), isFalse);
    });

    test('★★★ والمتاح تراكمي — يُضاف إلى المخزَّن لا يستبدله', () {
      final ReceiptAccepted plan = accepted(
        planReceipt(
          request(
            surplus: 20000,
            storedSurplus: const <String, Object?>{'availableAmount': 5000},
          ),
          ReceiptOperation.createReceipt,
        ),
      );
      expect(
        writeFor(plan, dealerSurplusCollection)['availableAmount'],
        25000,
      );
    });

    test('⛔⛔★★★ وتعديلُ السند يطرح مساهمتَه القديمة — ⛔ لا يُراكمها مرتين',
        () {
      // ★★ **الحارس الحقيقي:** ⟵ **سندٌ فائضُه 20,000 صار 30,000**،
      //    ⛔ **والمتاح كان سيصير 50,000 لو أُضيف الجديد بلا طرح القديم** —
      //    ★ **فيصير للمقوت رصيدٌ لم يدفعه.**
      final ReceiptAccepted plan = accepted(
        planReceipt(
          request(
            surplus: 30000,
            storedSurplus: const <String, Object?>{'availableAmount': 20000},
            storedDocument: const <String, Object?>{
              'status': 'approved',
              'surplusAmount': 20000,
            },
          ),
          ReceiptOperation.amendReceipt,
        ),
      );
      expect(
        writeFor(plan, dealerSurplusCollection)['availableAmount'],
        30000,
      );
    });

    test('★★★ وإلغاءُ السند يسحب فائضَه ⟵ فلا يُسدَّد منه ضمارٌ بعده', () {
      final ReceiptAccepted plan = accepted(
        planReceipt(
          request(
            storedSurplus: const <String, Object?>{'availableAmount': 20000},
            storedDocument: const <String, Object?>{
              'status': 'approved',
              'surplusAmount': 20000,
              'lines': <Object?>[],
            },
            reason: 'خطأ',
          ),
          ReceiptOperation.cancelReceipt,
        ),
      );
      expect(writeFor(plan, dealerSurplusCollection)['availableAmount'], 0);
    });

    test('⛔ ولا يهبط المتاح تحت الصفر', () {
      final ReceiptAccepted plan = accepted(
        planReceipt(
          request(
            storedSurplus: const <String, Object?>{'availableAmount': 0},
            storedDocument: const <String, Object?>{
              'status': 'approved',
              'surplusAmount': 20000,
              'lines': <Object?>[],
            },
            reason: 'خطأ',
          ),
          ReceiptOperation.cancelReceipt,
        ),
      );
      expect(writeFor(plan, dealerSurplusCollection)['availableAmount'], 0);
    });

    test('⛔ وفائضٌ سالبٌ رفضٌ لا صفرٌ مُصحَّح', () {
      expect(
        rejection(
          planReceipt(
            ReceiptRequest(
              actor: account(),
              requestId: requestId,
              dealerId: dealerA,
              documentNumber: docNumber,
              date: today,
              today: today,
              surplusAmount: const Money(-5),
              lines: <ReceiptLineInput>[
                ReceiptLineInput(debtLotId: lotIdOf(20), amount: Money(1000)),
              ],
              lots: lots(<DebtLotRead>[lot(20)]),
              storedDealer: const <String, Object?>{'name': 'مقوت'},
            ),
            ReceiptOperation.createReceipt,
          ),
        ),
        CallableError.invalidArgument,
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // ★★ المستند وقيد التدقيق
  // ═══════════════════════════════════════════════════════════════════════
  group('★★ المستند وقيد التدقيق', () {
    ReceiptAccepted created() => accepted(
          planReceipt(
            request(
              sourceFilter: sourceA,
              lines: <ReceiptLineInput>[
                ReceiptLineInput(debtLotId: lotIdOf(20), amount: Money(10000)),
              ],
            ),
            ReceiptOperation.createReceipt,
          ),
        );

    test('★★ السطر يحمل المتبقي قبله وبعده — للعرض التاريخي', () {
      final Object? lines = writeFor(created(), receiptsCollection)['lines'];
      final Map<String, Object?> line =
          (lines! as List<Object?>).single! as Map<String, Object?>;
      expect(line['remainingBefore'], 30000);
      expect(line['amount'], 10000);
      expect(line['remainingAfter'], 20000);
      expect(line['sourceId'], sourceA);
    });

    test('★★★ و`affectedSourceIds` من الضمارات لا من الحمولة', () {
      expect(
        writeFor(created(), receiptsCollection)['affectedSourceIds'],
        <String>[sourceA],
      );
    });

    test('★★ و`totalDebtAtEntry` محفوظٌ للعرض التاريخي (`FR-M12-03`)', () {
      expect(writeFor(created(), receiptsCollection)['totalDebtAtEntry'], 30000);
    });

    test('★★★ وقيد التدقيق بمعرّف الطلب نفسه ⟵ لاتكرارية', () {
      expect(created().entry.id, requestId);
      expect(created().entry.target.entityType, receiptEntityType);
      expect(created().entry.target.entityId, docNumber);
    });

    test('★★ وسندُ «الكل» يُنسَب لـ`all` ⛔ لا لمصدرٍ منها', () {
      final ReceiptAccepted plan = accepted(
        planReceipt(
          request(
            lines: <ReceiptLineInput>[
              ReceiptLineInput(debtLotId: lotIdOf(20), amount: Money(1000)),
            ],
          ),
          ReceiptOperation.createReceipt,
        ),
      );
      expect(plan.entry.target.sourceId, auditAllSourcesId);
    });

    test('★★★ ADR-0020 — إنشاءٌ وتعديلٌ بلا سبب يُقبلان', () {
      expect(created().entry.reason, isNull);
      final ReceiptPlan amended = planReceipt(
        request(
          storedDocument: const <String, Object?>{'status': 'approved'},
          lines: <ReceiptLineInput>[
            ReceiptLineInput(debtLotId: lotIdOf(20), amount: Money(1000)),
          ],
        ),
        ReceiptOperation.amendReceipt,
      );
      expect(amended, isA<ReceiptAccepted>());
    });

    test('⛔★★ والفراغات تُقرأ غياباً لا نصّاً فارغاً', () {
      final ReceiptAccepted plan = accepted(
        planReceipt(
          request(
            reason: '   ',
            storedDocument: const <String, Object?>{'status': 'approved'},
            lines: <ReceiptLineInput>[
              ReceiptLineInput(debtLotId: lotIdOf(20), amount: Money(1000)),
            ],
          ),
          ReceiptOperation.amendReceipt,
        ),
      );
      expect(plan.entry.reason, isNull);
    });

    test('⛔ ومستندٌ ملغى لا يُعدَّل (`ERR_AMEND_006`)', () {
      expect(
        rejection(
          planReceipt(
            request(
              storedDocument: const <String, Object?>{'status': 'cancelled'},
              lines: <ReceiptLineInput>[
                ReceiptLineInput(debtLotId: lotIdOf(20), amount: Money(1000)),
              ],
            ),
            ReceiptOperation.amendReceipt,
          ),
        ),
        CallableError.documentCancelled,
      );
    });

    test('★ وسجلٌّ لم يُقرأ ⟵ رفضٌ داخلي لا تجاوز', () {
      expect(
        rejection(
          planReceipt(
            request(
              storedDealer: null,
              lines: <ReceiptLineInput>[
                ReceiptLineInput(debtLotId: lotIdOf(20), amount: Money(1000)),
              ],
            ),
            ReceiptOperation.createReceipt,
          ),
        ),
        CallableError.internal,
      );
    });

    test('★ قابلية التكرار بلا أثر جانبي — نفس الطلب نفسُ الخطة', () {
      List<String> ids() => accepted(
            planReceipt(
              request(
                lines: <ReceiptLineInput>[
                  ReceiptLineInput(debtLotId: lotIdOf(20), amount: Money(1000)),
                ],
              ),
              ReceiptOperation.createReceipt,
            ),
          ).writes.map((InventoryWrite w) => w.documentId).toList();
      expect(ids(), ids());
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // ★★★ الإلغاء — ويردّ المسدَّد
  // ═══════════════════════════════════════════════════════════════════════
  group('★★★ الإلغاء — `FR-M12-21` بالوسم ⛔ بلا حركةٍ عكسية', () {
    ReceiptAccepted cancelled() => accepted(
          planReceipt(
            request(
              storedLots: lots(<DebtLotRead>[lot(20, settled: 10000)]),
              storedDocument: <String, Object?>{
                'status': 'approved',
                'lines': <Object?>[
                  <String, Object?>{
                    'debtLotId': lotIdOf(20),
                    'sourceId': sourceA,
                    'amount': 10000,
                    'remainingBefore': 30000,
                    'remainingAfter': 20000,
                  },
                ],
              },
              reason: 'خطأ إدخال',
            ),
            ReceiptOperation.cancelReceipt,
          ),
        );

    test('★★ السند يُوسَم ملغى ⛔ ولا يُحذف', () {
      expect(
        writeFor(cancelled(), receiptsCollection)['status'],
        'cancelled',
      );
    });

    test('★★★ والمسدَّد يعود للضمار ⟵ فالدين يُفتَح ثانيةً', () {
      final Map<String, Object?> pricing = writeFor(
        cancelled(),
        '$distributionsCollection/${lotIdOf(20)}'
        '/$distributionPricingSubcollection',
      );
      expect(pricing['settledAmount'], 0);
      expect(pricing['remaining'], 30000);
    });

    test('★★ وحالة الضمار تعود «مفتوح»', () {
      expect(
        writeFor(
          cancelled(),
          distributionsCollection,
          documentId: lotIdOf(20),
        )['settlementStatus'],
        SettlementStatus.open.name,
      );
    });

    test('★★★ والحركة الدائنة تُوسَم ملغاة ⛔ لا حركةٌ مضادة', () {
      final Iterable<InventoryWrite> entries =
          writesIn(cancelled(), dealerLedgerCollection);
      expect(entries.length, 1);
      expect(entries.single.fields['isCancelled'], isTrue);
    });

    test('★ وقيد التدقيق فعلُ إلغاء', () {
      expect(cancelled().entry.action, AuditAction.cancel);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // ★★ ⑧ الإيداع البنكي — AT-36
  // ═══════════════════════════════════════════════════════════════════════
  group('★★ الإيداع البنكي — `FR-M12-15` … `FR-M12-18`', () {
    ReceiptPlan deposit({String? note, bool isDeposited = true}) => planReceipt(
          request(
            depositNote: note,
            depositState:
                isDeposited ? DepositState.deposited : DepositState.notDeposited,
            storedDocument: const <String, Object?>{'status': 'approved'},
            storedDeposit: const <String, Object?>{'isDeposited': false},
          ),
          ReceiptOperation.confirmReceiptDeposit,
        );

    test('⛔⛔★★ AT-36 — بلا ملاحظة يُرفَض (`ERR_DIST_008`)', () {
      expect(rejection(deposit()), CallableError.depositNoteMissing);
    });

    test('⛔ وفراغاتٌ تُقرأ غياباً', () {
      expect(rejection(deposit(note: '  ')), CallableError.depositNoteMissing);
    });

    test('★★★ وبملاحظة ⟵ يُكتب في المستند الفرعي وحده', () {
      final ReceiptAccepted plan = accepted(deposit(note: 'البنك الأهلي'));
      expect(plan.writes.length, 1);
      expect(
        plan.writes.single.collectionId,
        '$receiptsCollection/$docNumber/$receiptDepositSubcollection',
      );
      expect(plan.writes.single.documentId, receiptDepositDocumentId);
    });

    test('⛔⛔★★★ ولا حقلَ من الأب يُمَسّ — `FR-M12-18` الحارسُ الحقيقي', () {
      // ⟵ **فمن يملك تأكيد الإيداع لا يُعدِّل مبلغاً.**
      expect(
        hasWrite(accepted(deposit(note: 'البنك')), receiptsCollection),
        isFalse,
      );
      expect(
        hasWrite(accepted(deposit(note: 'البنك')), dealerLedgerCollection),
        isFalse,
      );
    });

    test('★★ والقيمة قبل وبعد في القيد — `FR-M12-17`', () {
      final ReceiptAccepted plan = accepted(deposit(note: 'البنك'));
      expect(plan.entry.valuesBefore['isDeposited'], isFalse);
      expect(plan.entry.valuesAfter['isDeposited'], isTrue);
    });

    test('★★ والتراجع يشترط ملاحظةً كذلك', () {
      expect(
        rejection(deposit(isDeposited: false)),
        CallableError.depositNoteMissing,
      );
      expect(
        accepted(deposit(note: 'تراجع بالخطأ', isDeposited: false))
            .writes
            .single
            .fields['isDeposited'],
        isFalse,
      );
    });
  });
}

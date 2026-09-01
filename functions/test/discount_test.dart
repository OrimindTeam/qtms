/// الخصومات — ★★★ **حارس التفويض والنطاق والفصل عن القبض معاً** (`WU-013`).
///
/// ⚠️⚠️ **ولماذا تُختبَر بهذه الصرامة:** بعد إغلاق الكتابة المباشرة
/// (`ADR-0013` القاعدة 2) **لم يبقَ بين المستخدم ودفتر الذمم إلا هذا الكود** —
/// ⟵ **فكل شرطٍ كانت تفرضه `firestore.rules` صار بند قبولٍ هنا.**
///
/// ★★★ **ويزيد هنا شرطٌ لا نظير له في `WU-007`: رفضُ الفائض صراحةً**
/// (`FR-M13-05` · `AT-35`) — ⛔ **وهو حارسٌ لا يُختبَر من الشاشة أصلاً**:
/// ★ **الحقلُ غيرُ موجودٍ فيها**، ⟵ **فوصولُه يعني طلباً من خارج التطبيق**،
/// ⛔ **ولا يكشفه إلا اختبارٌ يبعثه عمداً.**
library;

import 'package:qtms_domain/qtms_domain.dart';
import 'package:qtms_functions/src/callable.dart';
import 'package:qtms_functions/src/discount.dart';
import 'package:qtms_functions/src/identity_claims.dart';
import 'package:qtms_functions/src/identity_gateway.dart';
import 'package:qtms_functions/src/inventory.dart';
import 'package:qtms_functions/src/receipt.dart' show DebtLotRead, ReceiptLedgerRead;
import 'package:test/test.dart';

const String actorUid = 'uid-owner';
const String sourceA = 'SRC-001';
const String sourceB = 'SRC-002';
const String dealerA = 'MQT-0001';
const String docNumber = 'DSC-20260901-0001';
const String requestId = 'req-dsc-001';

final CalendarDay today = CalendarDay(2026, 9, 1);

const Set<Permission> fullPermissions = <Permission>{
  Permission.discountCreate,
  Permission.discountAmend,
  Permission.discountCancel,
  Permission.discountBackdate,
};

AccountRecord account({
  Set<Permission> permissions = fullPermissions,
  SourceScope scope = const AllSources(),
  bool disabled = false,
}) =>
    AccountRecord(
      userId: actorUid,
      userName: 'مالك',
      claims: IdentityClaims(permissions: permissions, sourceScope: scope),
      disabled: disabled,
      cardIsActive: true,
    );

String lotIdOf(int stockDay, {String sourceId = sourceA}) => distributionId(
      dealerId: dealerA,
      sourceId: sourceId,
      stockDate: CalendarDay(2026, 9, stockDay),
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
      stockDate: CalendarDay(2026, 9, stockDay),
      settlement: computeDebtSettlement(
        debtValue: Money(debtValue),
        settledAmount: Money(settled),
        discountedAmount: Money(discounted),
      ),
      isCancelled: isCancelled,
    );

Map<String, DebtLotRead> lots(List<DebtLotRead> list) =>
    <String, DebtLotRead>{for (final DebtLotRead l in list) l.debtLotId: l};

DiscountRequest request({
  AccountRecord? actor,
  CalendarDay? date,
  String? sourceFilter,
  List<DiscountLineInput> lines = const <DiscountLineInput>[],
  Map<String, DebtLotRead>? storedLots,
  Map<String, Object?>? storedDealer = const <String, Object?>{'name': 'مقوت'},
  Map<String, Object?>? storedDocument,
  List<ReceiptLedgerRead> dealerLedger = const <ReceiptLedgerRead>[],
  String? reason,
  bool surplusFieldPresent = false,
  String documentNumber = docNumber,
  String id = requestId,
}) =>
    DiscountRequest(
      actor: actor ?? account(),
      requestId: id,
      dealerId: dealerA,
      documentNumber: documentNumber,
      date: date ?? today,
      today: today,
      sourceFilter: sourceFilter,
      lines: lines,
      lots: storedLots ?? lots(<DebtLotRead>[lot(1)]),
      storedDealer: storedDealer,
      storedDocument: storedDocument,
      dealerLedger: dealerLedger,
      reason: reason,
      surplusFieldPresent: surplusFieldPresent,
    );

DiscountAccepted accepted(DiscountPlan plan) => plan as DiscountAccepted;

CallableError rejection(DiscountPlan plan) => (plan as DiscountRejected).error;

Map<String, Object?> writeFor(
  DiscountAccepted plan,
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

Iterable<InventoryWrite> writesIn(DiscountAccepted plan, String collectionId) =>
    plan.writes.where((InventoryWrite w) => w.collectionId == collectionId);

bool hasWrite(DiscountAccepted plan, String collectionId) =>
    plan.writes.any((InventoryWrite w) => w.collectionId == collectionId);

DiscountLineInput line(int stockDay, int amount, {String sourceId = sourceA}) =>
    DiscountLineInput(
      debtLotId: lotIdOf(stockDay, sourceId: sourceId),
      amount: Money(amount),
    );

void main() {
  // ═══════════════════════════════════════════════════════════════════════
  // ★★ البوابة
  // ═══════════════════════════════════════════════════════════════════════
  group('★★ البوابة — الحالة والصلاحية قبل أي معاملة', () {
    test('⛔ حسابٌ معطَّل يُرفض ولو ملك كل المفاتيح', () {
      expect(
        rejection(
          planDiscount(
            request(actor: account(disabled: true)),
            DiscountOperation.createDiscount,
          ),
        ),
        CallableError.accountDisabled,
      );
    });

    test('⛔⛔★★★ و`discountCreate` لا يُغني عنه `receiptCreate`', () {
      // ★ **صلاحيةٌ مستقلة لا تُمنَح افتراضياً** (`FR-M13-09`) — ⟵ **لأنها
      //   إسقاطُ دَينٍ حقيقي**، ⛔ **ومنحُها ضمناً مع القبض كان يجعل كلَّ
      //   قابضٍ يُسقِط ديوناً.**
      expect(
        rejection(
          planDiscount(
            request(
              actor: account(
                permissions: const <Permission>{
                  Permission.receiptCreate,
                  Permission.receiptAmend,
                  Permission.receiptCancel,
                  Permission.receiptBackdate,
                },
              ),
              lines: <DiscountLineInput>[line(1, 3000)],
            ),
            DiscountOperation.createDiscount,
          ),
        ),
        CallableError.permissionMissing,
      );
    });

    test('⛔ ولكل عمليةٍ مفتاحُها — التعديل لا يُنفَّذ بمفتاح الإنشاء', () {
      expect(
        rejection(
          planDiscount(
            request(
              actor: account(
                permissions: const <Permission>{Permission.discountCreate},
              ),
              lines: <DiscountLineInput>[line(1, 3000)],
              storedDocument: const <String, Object?>{'status': 'approved'},
            ),
            DiscountOperation.amendDiscount,
          ),
        ),
        CallableError.permissionMissing,
      );
    });

    test('⛔ ومعرّفُ الطلب إلزامي — وبدونه لا لاتكرارية', () {
      expect(
        rejection(
          planDiscount(
            request(id: '   ', lines: <DiscountLineInput>[line(1, 3000)]),
            DiscountOperation.createDiscount,
          ),
        ),
        CallableError.invalidArgument,
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // ⛔⛔★★★ الفائض — `FR-M13-05` · `AT-35` · `ERR_DIST_009`
  // ═══════════════════════════════════════════════════════════════════════
  group('⛔⛔★★★ رفضُ الفائض صراحةً — حارسٌ لا تراه الشاشة', () {
    test('⛔⛔★★★ `AT-35`: حقلُ فائضٍ في سند خصمٍ يُرفَض بـ`ERR_DIST_009`', () {
      final DiscountPlan plan = planDiscount(
        request(
          lines: <DiscountLineInput>[line(1, 3000)],
          surplusFieldPresent: true,
        ),
        DiscountOperation.createDiscount,
      );
      expect(rejection(plan), CallableError.discountSurplusRejected);
      expect(CallableError.discountSurplusRejected.code, 'ERR_DIST_009');
    });

    test('⛔⛔★★ ويُرفَض في التعديل كذلك — ⛔ فلا بابَ خلفيّ', () {
      expect(
        rejection(
          planDiscount(
            request(
              lines: <DiscountLineInput>[line(1, 3000)],
              storedDocument: const <String, Object?>{'status': 'approved'},
              surplusFieldPresent: true,
            ),
            DiscountOperation.amendDiscount,
          ),
        ),
        CallableError.discountSurplusRejected,
      );
    });

    test('⛔⛔★★★ ولا حقلَ فائضٍ في المستند المكتوب إطلاقاً', () {
      final DiscountAccepted plan = accepted(
        planDiscount(
          request(lines: <DiscountLineInput>[line(1, 3000)]),
          DiscountOperation.createDiscount,
        ),
      );
      final Map<String, Object?> fields =
          writeFor(plan, discountsCollection, documentId: docNumber);
      expect(fields.containsKey('surplusAmount'), isFalse);
      expect(fields.containsKey('surplusScope'), isFalse);
    });

    test('⛔⛔★★★ ولا سجلَّ فائضٍ يُكتب — بخلاف مسار القبض تماماً', () {
      final DiscountAccepted plan = accepted(
        planDiscount(
          request(lines: <DiscountLineInput>[line(1, 3000)]),
          DiscountOperation.createDiscount,
        ),
      );
      expect(hasWrite(plan, dealerSurplusCollection), isFalse);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // ⛔⛔★★★ الفصل عن القبض — `FR-M15-06-أ` · `ت-04` · `GR-40`
  // ═══════════════════════════════════════════════════════════════════════
  group('⛔⛔★★★ الخصمُ لا يُكتب كقبضٍ في أي موضع', () {
    test('⛔⛔★★★ والمستندُ في `discounts` لا في `receipts`', () {
      final DiscountAccepted plan = accepted(
        planDiscount(
          request(lines: <DiscountLineInput>[line(1, 3000)]),
          DiscountOperation.createDiscount,
        ),
      );
      expect(hasWrite(plan, discountsCollection), isTrue);
      expect(hasWrite(plan, receiptsCollection), isFalse);
    });

    test('⛔⛔★★★ ونوعُ القيد «خصم» لا «قبض»', () {
      final DiscountAccepted plan = accepted(
        planDiscount(
          request(lines: <DiscountLineInput>[line(1, 3000)]),
          DiscountOperation.createDiscount,
        ),
      );
      final Map<String, Object?> entry = writeFor(plan, dealerLedgerCollection);
      expect(entry['entryType'], DealerLedgerEntryType.discount.name);
      expect(entry['entryType'], isNot(DealerLedgerEntryType.receipt.name));
    });

    test('⛔⛔★★ و`sourceDocType` «discount» — درسُ النوع المحفور', () {
      final DiscountAccepted plan = accepted(
        planDiscount(
          request(lines: <DiscountLineInput>[line(1, 3000)]),
          DiscountOperation.createDiscount,
        ),
      );
      expect(
        writeFor(plan, dealerLedgerCollection)['sourceDocType'],
        discountEntityType,
      );
    });

    test('⛔⛔★★★ ونوعُ قيد التدقيق «discount» — فالسجلُّ يُفرِّق بينهما', () {
      final DiscountAccepted plan = accepted(
        planDiscount(
          request(lines: <DiscountLineInput>[line(1, 3000)]),
          DiscountOperation.createDiscount,
        ),
      );
      expect(plan.entry.target.entityType, discountEntityType);
      expect(plan.entry.target.entityType, isNot(receiptEntityType));
    });

    test('⛔⛔★★★ والمبلغُ يدخل `discountedAmount` ⛔ لا `settledAmount`', () {
      final DiscountAccepted plan = accepted(
        planDiscount(
          request(
            lines: <DiscountLineInput>[line(1, 3000)],
            storedLots: lots(<DebtLotRead>[lot(1, debtValue: 8000)]),
          ),
          DiscountOperation.createDiscount,
        ),
      );
      final Map<String, Object?> pricing = writeFor(
        plan,
        '$distributionsCollection/${lotIdOf(1)}'
        '/$distributionPricingSubcollection',
      );
      expect(pricing['discountedAmount'], 3000);
      // ⛔⛔ **وهذا هو `ت-04` بنيوياً** — ★ **فالواصلُ لا يبتلع الخصم.**
      expect(pricing['settledAmount'], 0);
      expect(pricing['remaining'], 5000);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // ★★★ التسوية والحركات — `AT-33` · `FR-M13-03`
  // ═══════════════════════════════════════════════════════════════════════
  group('★★★ حركةٌ دائنة لكل سطر — ⛔ لا واحدةٌ مجمّعة', () {
    test('★★★ سطران على ضمارين ⟵ حركتان دائنتان بمعرّفين مختلفين', () {
      final DiscountAccepted plan = accepted(
        planDiscount(
          request(
            lines: <DiscountLineInput>[line(1, 3000), line(2, 1000)],
            storedLots: lots(<DebtLotRead>[
              lot(1, debtValue: 8000),
              lot(2, debtValue: 5000),
            ]),
          ),
          DiscountOperation.createDiscount,
        ),
      );
      final List<InventoryWrite> entries =
          writesIn(plan, dealerLedgerCollection).toList();
      expect(entries, hasLength(2));
      expect(entries[0].documentId, isNot(entries[1].documentId));
      for (final InventoryWrite w in entries) {
        expect(w.fields['direction'], DealerLedgerDirection.credit.name);
      }
    });

    test('★★★ وكلُّ حركةٍ في مصدر ضمارها هو — `E-35` · `GR-20`', () {
      final DiscountAccepted plan = accepted(
        planDiscount(
          request(
            lines: <DiscountLineInput>[
              line(1, 3000),
              line(1, 1000, sourceId: sourceB),
            ],
            storedLots: lots(<DebtLotRead>[
              lot(1, debtValue: 8000),
              lot(1, sourceId: sourceB, debtValue: 5000),
            ]),
          ),
          DiscountOperation.createDiscount,
        ),
      );
      final Set<Object?> sources = <Object?>{
        for (final InventoryWrite w in writesIn(plan, dealerLedgerCollection))
          w.fields['sourceId'],
      };
      expect(sources, <String>{sourceA, sourceB});
    });

    test('★★ وسجلُّ رصيدٍ لكل مصدرٍ مسّه السند — ⛔ لا سجلٌّ جامع', () {
      final DiscountAccepted plan = accepted(
        planDiscount(
          request(
            lines: <DiscountLineInput>[
              line(1, 3000),
              line(1, 1000, sourceId: sourceB),
            ],
            storedLots: lots(<DebtLotRead>[
              lot(1, debtValue: 8000),
              lot(1, sourceId: sourceB, debtValue: 5000),
            ]),
          ),
          DiscountOperation.createDiscount,
        ),
      );
      expect(writesIn(plan, dealerBalancesCollection), hasLength(2));
    });

    test('⛔ ومبلغٌ يتجاوز المتبقي يُرفَض بـ`ERR_DIST_005`', () {
      final DiscountPlan plan = planDiscount(
        request(
          lines: <DiscountLineInput>[line(1, 8001)],
          storedLots: lots(<DebtLotRead>[lot(1, debtValue: 8000)]),
        ),
        DiscountOperation.createDiscount,
      );
      expect(rejection(plan), CallableError.discountExceedsDebt);
      expect(CallableError.discountExceedsDebt.code, 'ERR_DIST_005');
    });

    test('⛔★★ والمتبقي مقيسٌ بعد قبضٍ سابق — ⛔ لا قيمةُ الضمار', () {
      // ★ **ضمارٌ قيمتُه 8000 سُدِّد منه 6000** ⟵ **فالمتبقي 2000**،
      //   ⛔ **وخصمُ 3000 يُرفَض.**
      expect(
        rejection(
          planDiscount(
            request(
              lines: <DiscountLineInput>[line(1, 3000)],
              storedLots:
                  lots(<DebtLotRead>[lot(1, debtValue: 8000, settled: 6000)]),
            ),
            DiscountOperation.createDiscount,
          ),
        ),
        CallableError.discountExceedsDebt,
      );
    });

    test('⛔★★ وضمارٌ ملغى ليس محلاً للخصم', () {
      expect(
        rejection(
          planDiscount(
            request(
              lines: <DiscountLineInput>[line(1, 1000)],
              storedLots: lots(<DebtLotRead>[lot(1, isCancelled: true)]),
            ),
            DiscountOperation.createDiscount,
          ),
        ),
        CallableError.discountExceedsDebt,
      );
    });

    test('⛔⛔★★ وسندٌ بلا سطرٍ يُرفَض — ⛔ ولا فائضَ يُنقِذه', () {
      expect(
        rejection(
          planDiscount(request(), DiscountOperation.createDiscount),
        ),
        CallableError.discountExceedsDebt,
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // ★★★ النطاق — `GR-23` · `E-35`
  // ═══════════════════════════════════════════════════════════════════════
  group('★★★ النطاق — لكل مصدرٍ مسّه السند على حدة', () {
    test('⛔⛔★★★ وسندٌ يمسّ مصدرين ونطاقُ المُنفِّذ أحدُهما ⟵ يُرفَض كاملاً', () {
      expect(
        rejection(
          planDiscount(
            request(
              actor: account(scope: ScopedSources(<String>{sourceA})),
              lines: <DiscountLineInput>[
                line(1, 3000),
                line(1, 1000, sourceId: sourceB),
              ],
              storedLots: lots(<DebtLotRead>[
                lot(1, debtValue: 8000),
                lot(1, sourceId: sourceB, debtValue: 5000),
              ]),
            ),
            DiscountOperation.createDiscount,
          ),
        ),
        CallableError.sourceOutOfScope,
      );
    });

    test('★ ونطاقٌ يشمل المصدرَ يمرّ', () {
      expect(
        planDiscount(
          request(
            actor: account(scope: ScopedSources(<String>{sourceA})),
            lines: <DiscountLineInput>[line(1, 3000)],
          ),
          DiscountOperation.createDiscount,
        ),
        isA<DiscountAccepted>(),
      );
    });

    test('⛔ وفلترُ مصدرٍ خارج النطاق يُرفَض كذلك', () {
      expect(
        rejection(
          planDiscount(
            request(
              actor: account(scope: ScopedSources(<String>{sourceA})),
              sourceFilter: sourceB,
              lines: <DiscountLineInput>[line(1, 3000)],
            ),
            DiscountOperation.createDiscount,
          ),
        ),
        CallableError.sourceOutOfScope,
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // ★★★ التاريخ — `FR-M13-06` · `AT-56`
  // ═══════════════════════════════════════════════════════════════════════
  group('★★★ التاريخ — والمستقبلي يسبق الصلاحية', () {
    test('⛔⛔★★ ومستقبليٌّ مرفوضٌ ولو ملك كلَّ المفاتيح', () {
      expect(
        rejection(
          planDiscount(
            request(
              date: CalendarDay(2026, 9, 2),
              lines: <DiscountLineInput>[line(1, 3000)],
            ),
            DiscountOperation.createDiscount,
          ),
        ),
        CallableError.futureDateRejected,
      );
    });

    test('⛔ وسابقٌ بلا `discountBackdate` يُرفَض', () {
      expect(
        rejection(
          planDiscount(
            request(
              actor: account(
                permissions: const <Permission>{Permission.discountCreate},
              ),
              date: CalendarDay(2026, 8, 31),
              lines: <DiscountLineInput>[line(1, 3000)],
            ),
            DiscountOperation.createDiscount,
          ),
        ),
        CallableError.backdateDenied,
      );
    });

    test('⛔⛔★★★ و`receiptBackdate` لا يفتح تاريخَ خصمٍ سابق', () {
      // ★ **مفتاحان مستقلان** — ⟵ **فمن يُصحِّح تاريخ قبضٍ ليس بالضرورة
      //   من يُسقِط ديناً بأثرٍ رجعي.**
      expect(
        rejection(
          planDiscount(
            request(
              actor: account(
                permissions: const <Permission>{
                  Permission.discountCreate,
                  Permission.receiptBackdate,
                },
              ),
              date: CalendarDay(2026, 8, 31),
              lines: <DiscountLineInput>[line(1, 3000)],
            ),
            DiscountOperation.createDiscount,
          ),
        ),
        CallableError.backdateDenied,
      );
    });

    test('★ وسابقٌ بمفتاحه مقبول', () {
      expect(
        planDiscount(
          request(
            date: CalendarDay(2026, 8, 31),
            lines: <DiscountLineInput>[line(1, 3000)],
          ),
          DiscountOperation.createDiscount,
        ),
        isA<DiscountAccepted>(),
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // ★★ السبب النصّي — [`ADR-0020`]
  // ═══════════════════════════════════════════════════════════════════════
  group('★★ السببُ النصّي اختياريٌّ — ⛔ ولا يُعبَّأ آلياً', () {
    test('★★ تعديلٌ بلا سببٍ يمرّ — [`ADR-0020`]', () {
      expect(
        planDiscount(
          request(
            lines: <DiscountLineInput>[line(1, 3000)],
            storedDocument: const <String, Object?>{'status': 'approved'},
          ),
          DiscountOperation.amendDiscount,
        ),
        isA<DiscountAccepted>(),
      );
    });

    test('⛔⛔★★ وفراغاتٌ تُقرأ غياباً لا نصّاً فارغاً', () {
      final DiscountAccepted plan = accepted(
        planDiscount(
          request(
            reason: '   ',
            lines: <DiscountLineInput>[line(1, 3000)],
            storedDocument: const <String, Object?>{'status': 'approved'},
          ),
          DiscountOperation.amendDiscount,
        ),
      );
      expect(plan.entry.reason, isNull);
      expect(
        writeFor(plan, discountsCollection, documentId: docNumber)['amendReason'],
        isNull,
      );
    });

    test('★ وسببٌ مكتوبٌ يُحفظ كما كتبه الإنسان', () {
      final DiscountAccepted plan = accepted(
        planDiscount(
          request(
            reason: 'تسويةٌ متفقٌ عليها',
            lines: <DiscountLineInput>[line(1, 3000)],
            storedDocument: const <String, Object?>{'status': 'approved'},
          ),
          DiscountOperation.amendDiscount,
        ),
      );
      expect(plan.entry.reason, 'تسويةٌ متفقٌ عليها');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // ★★ الإلغاء — `GR-06` · `A-14`
  // ═══════════════════════════════════════════════════════════════════════
  group('★★ الإلغاءُ وسمٌ يردّ المخصوم — ⛔ بلا حركةٍ عكسية ولا حذف', () {
    Map<String, Object?> storedDoc({int amount = 3000}) => <String, Object?>{
          'status': 'approved',
          'date': today.asUtcMidnight(),
          'lines': <Object?>[
            <String, Object?>{
              'debtLotId': lotIdOf(1),
              'sourceId': sourceA,
              'remainingBefore': 8000,
              'amount': amount,
              'remainingAfter': 8000 - amount,
              'note': null,
            },
          ],
        };

    test('★★★ والإلغاءُ يطرح المخصوم فيعود الدينُ مفتوحاً', () {
      final DiscountAccepted plan = accepted(
        planDiscount(
          request(
            storedDocument: storedDoc(),
            storedLots: lots(
              <DebtLotRead>[lot(1, debtValue: 8000, discounted: 3000)],
            ),
          ),
          DiscountOperation.cancelDiscount,
        ),
      );
      final Map<String, Object?> pricing = writeFor(
        plan,
        '$distributionsCollection/${lotIdOf(1)}'
        '/$distributionPricingSubcollection',
      );
      expect(pricing['discountedAmount'], 0);
      expect(pricing['remaining'], 8000);
    });

    test('★★ وحركةُ الدفتر تُوسَم ملغاة ⛔ ولا حركةَ مضادة تُكتب', () {
      final DiscountAccepted plan = accepted(
        planDiscount(
          request(
            storedDocument: storedDoc(),
            storedLots: lots(
              <DebtLotRead>[lot(1, debtValue: 8000, discounted: 3000)],
            ),
          ),
          DiscountOperation.cancelDiscount,
        ),
      );
      final List<InventoryWrite> entries =
          writesIn(plan, dealerLedgerCollection).toList();
      expect(entries, hasLength(1));
      expect(entries.single.fields['isCancelled'], isTrue);
      // ★ **والمعرّفُ نفسُه** — ⟵ **فالحركةُ تُوسَم لا تُضاعَف.**
      expect(
        entries.single.documentId,
        discountLedgerEntryId(
          documentNumber: docNumber,
          debtLotId: lotIdOf(1),
        ),
      );
    });

    test('⛔ وسندٌ ملغىً لا يُلغى ثانيةً ولا يُعدَّل', () {
      expect(
        rejection(
          planDiscount(
            request(
              storedDocument: const <String, Object?>{'status': 'cancelled'},
            ),
            DiscountOperation.cancelDiscount,
          ),
        ),
        CallableError.documentCancelled,
      );
    });

    test('⛔⛔ ولا مسارَ حذفٍ في العمليات الثلاث أصلاً', () {
      expect(DiscountOperation.values, hasLength(3));
      expect(
        DiscountOperation.values.map((DiscountOperation o) => o.name),
        <String>['createDiscount', 'amendDiscount', 'cancelDiscount'],
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // ★★ قيد التدقيق — `ADR-0013` القاعدة 1
  // ═══════════════════════════════════════════════════════════════════════
  group('★★ قيدُ التدقيق يُكتب في المعاملة نفسِها', () {
    test('★ الإنشاءُ فعلُ «إنشاء» ومعرّفُه رقمُ المستند', () {
      final DiscountAccepted plan = accepted(
        planDiscount(
          request(lines: <DiscountLineInput>[line(1, 3000)]),
          DiscountOperation.createDiscount,
        ),
      );
      expect(plan.entry.action, AuditAction.create);
      expect(plan.entry.target.entityId, docNumber);
      expect(plan.entry.target.documentNumber, docNumber);
      expect(plan.entry.id, requestId);
    });

    test('★★ وسندُ «الكل» يُنسَب لكل المصادر ⛔ لا لأحدها دون البقية', () {
      final DiscountAccepted plan = accepted(
        planDiscount(
          request(lines: <DiscountLineInput>[line(1, 3000)]),
          DiscountOperation.createDiscount,
        ),
      );
      expect(plan.entry.target.sourceId, auditAllSourcesId);
    });

    test('★ وفلترُ مصدرٍ محدد يُنسَب إليه', () {
      final DiscountAccepted plan = accepted(
        planDiscount(
          request(
            sourceFilter: sourceA,
            lines: <DiscountLineInput>[line(1, 3000)],
          ),
          DiscountOperation.createDiscount,
        ),
      );
      expect(plan.entry.target.sourceId, sourceA);
    });

    test('★★ والتعديلُ يحمل القيمة قبل وبعد', () {
      final DiscountAccepted plan = accepted(
        planDiscount(
          request(
            lines: <DiscountLineInput>[line(1, 5000)],
            storedLots: lots(<DebtLotRead>[lot(1, debtValue: 8000)]),
            storedDocument: <String, Object?>{
              'status': 'approved',
              'lines': <Object?>[
                <String, Object?>{
                  'debtLotId': lotIdOf(1),
                  'sourceId': sourceA,
                  'remainingBefore': 8000,
                  'amount': 3000,
                  'remainingAfter': 5000,
                  'note': null,
                },
              ],
            },
          ),
          DiscountOperation.amendDiscount,
        ),
      );
      expect(plan.entry.action, AuditAction.amend);
      expect(plan.entry.valuesAfter.containsKey('lines'), isTrue);
      expect(plan.entry.valuesBefore.containsKey('lines'), isTrue);
    });
  });
}

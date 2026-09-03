/// التوزيع والضمار — ★★★ **حارس التفويض والنطاق والسعر والرصيد معاً**
/// (`WU-006`).
///
/// ⚠️⚠️ **ولماذا تُختبَر بهذه الصرامة:** بعد إغلاق الكتابة المباشرة
/// (`ADR-0013` القاعدة 2) **لم يبقَ بين المستخدم والدفترَين إلا هذا الكود** —
/// ⟵ **فكل شرطٍ كانت تفرضه `firestore.rules` صار بند قبولٍ هنا**
/// (`DEBT-21` ①). ★★ **ويزيد هنا شرطان لا نظير لهما في `WU-003`:**
/// **`GR-18` المعرّف المركّب** · **وحارس السعر `ت-12`** — ⟵ **وكلاهما
/// «إخفاءٌ في الواجهة» ما لم يُفرَض هنا.**
library;

import 'package:qtms_domain/qtms_domain.dart';
import 'package:qtms_functions/src/callable.dart';
import 'package:qtms_functions/src/distribution.dart';
import 'package:qtms_functions/src/identity_claims.dart';
import 'package:qtms_functions/src/identity_gateway.dart';
import 'package:qtms_functions/src/firestore_value.dart';
import 'package:qtms_functions/src/inventory.dart';
import 'package:test/test.dart';

const String actorUid = 'uid-seller';
const String sourceA = 'SRC-001';
const String sourceB = 'SRC-002';
const String dealerA = 'MQT-0001';
const String itemA = 'ITM-0001';
const String itemScrap = 'ITM-0002';
const String docNumber = 'DST-20260827-0001';

final CalendarDay day = CalendarDay(2026, 8, 27);
final String compositeA =
    distributionId(dealerId: dealerA, sourceId: sourceA, stockDate: day);

const Set<Permission> fullPermissions = <Permission>{
  Permission.distributionCreate,
  Permission.distributionAmend,
  Permission.distributionCancel,
  Permission.distributionPriceNow,
  Permission.distributionPriceAmend,
  Permission.distributionPriceClear,
  Permission.distributionPriceView,
};

AccountRecord account({
  Set<Permission> permissions = fullPermissions,
  SourceScope scope = const AllSources(),
  bool disabled = false,
}) =>
    AccountRecord(
      userId: actorUid,
      userName: 'بائع',
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
      name: itemId == itemScrap ? 'سكرب' : 'عوارض',
      unit: unit,
      isActive: isActive,
      sourceIds: sourceIds,
    );

ValidatedDistribution payload({
  String sourceId = sourceA,
  String dealerId = dealerA,
  List<DistributionLineInput>? lines,
}) =>
    (validateDistribution(
      DistributionInput(
        sourceId: sourceId,
        dealerId: dealerId,
        lines: lines ??
            <DistributionLineInput>[
              DistributionLineInput(
                itemId: itemA,
                itemName: 'عوارض',
                unit: ItemUnit.piece,
                quantity: const PieceQuantity(PieceCount(80)),
                unitPrice: const Money(1500),
              ),
            ],
      ),
    ) as Success<ValidatedDistribution>)
        .value;

DistributionLineInput pieceLine({
  String itemId = itemA,
  int quantity = 80,
  int? unitPrice = 1500,
  String? sackId,
}) =>
    DistributionLineInput(
      itemId: itemId,
      itemName: 'عوارض',
      unit: ItemUnit.piece,
      quantity: PieceQuantity(PieceCount(quantity)),
      sackId: sackId,
      unitPrice: unitPrice == null ? null : Money(unitPrice),
    );

DistributionLineInput weightLine({
  String itemId = itemScrap,
  double quantity = 1.234,
  int? unitPrice = 1501,
}) =>
    DistributionLineInput(
      itemId: itemId,
      itemName: 'سكرب',
      unit: ItemUnit.kilogram,
      quantity: WeightQuantity(WeightKg(quantity)),
      unitPrice: unitPrice == null ? null : Money(unitPrice),
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

/// ★ مخزونٌ وزنيٌّ وافر للسكرب — **لاختبارات السطر الوزني**.
LedgerRead scrapStock([double kilograms = 50]) => LedgerRead(
      movementId: 'seed-scrap',
      movement: StockMovement(
        itemKey: itemScrap,
        direction: MovementDirection.incoming,
        quantity: WeightQuantity(WeightKg(kilograms)),
        isCancelled: false,
      ),
    );

DistributionRequest request({
  AccountRecord? actor,
  ValidatedDistribution? distribution,
  Map<String, Object?>? storedSource = const <String, Object?>{'isActive': true},
  Map<String, Object?>? storedDealer = const <String, Object?>{
    'isActive': true,
    'name': 'أحمد',
  },
  Map<String, Object?>? storedDocument,
  Map<String, Money?> storedUnitPrices = const <String, Money?>{},
  bool hasStoredPricing = false,
  DebtSettlement? storedSettlement,
  Map<String, ItemRead>? items,
  Map<String, List<LedgerRead>>? ledger,
  List<DealerLedgerRead> dealerLedger = const <DealerLedgerRead>[],
  List<SurplusPoolRead> surplusPools = const <SurplusPoolRead>[],
  String? reason,
  String sourceId = sourceA,
  String dealerId = dealerA,
  String number = docNumber,
  CalendarDay? stockDate,
}) =>
    DistributionRequest(
      actor: actor ?? account(),
      requestId: 'req-1',
      sourceId: sourceId,
      dealerId: dealerId,
      documentNumber: number,
      stockDate: stockDate ?? day,
      distribution: distribution,
      storedSource: storedSource,
      storedDealer: storedDealer,
      storedDocument: storedDocument,
      storedUnitPrices: storedUnitPrices,
      hasStoredPricing: hasStoredPricing,
      storedSettlement: storedSettlement,
      items: items ?? <String, ItemRead>{itemA: item()},
      // ★ **مخزونٌ افتراضي وافر** — ⟵ **فاختبارات التفويض تفشل على التفويض
      //   لا على نقص الرصيد**، ⛔ **ونجاحٌ لسببٍ خاطئ أسوأ من فشل.**
      ledger: ledger ??
          <String, List<LedgerRead>>{
            itemA: <LedgerRead>[movement('seed-a', 1000)],
          },
      dealerLedger: dealerLedger,
      surplusPools: surplusPools,
      reason: reason,
    );

/// المستند المخزَّن كما تقرؤه المعاملة.
Map<String, Object?> stored({
  String status = 'approved',
  String sourceId = sourceA,
  String dealerId = dealerA,
  CalendarDay? stockDate,
  List<String> itemIds = const <String>[itemA],
}) =>
    <String, Object?>{
      'documentNumber': docNumber,
      'sourceId': sourceId,
      'dealerId': dealerId,
      'stockDate': (stockDate ?? day).asUtcMidnight(),
      'status': status,
      'lines': <Object?>[
        for (final String id in itemIds)
          <String, Object?>{'itemId': id, 'quantity': 80},
      ],
    };
// ⛔⛔★★ **ولا مبلغَ في الأب** (`ADR-0011` · `IQ-027` الخيار أ): **المسدَّد
//    والمخصوم والمتبقي في `pricing/current`** — ★ **وقراءتُها مُختبَرةٌ في
//    [`stored_settlement_test.dart`]**، ⛔ **وهنا تُمرَّر [DebtSettlement]
//    جاهزةً لأن هذا اختبارُ تخطيطٍ خالص.**

DistributionAccepted accepted(DistributionPlan plan) =>
    plan as DistributionAccepted;

CallableError rejection(DistributionPlan plan) =>
    (plan as DistributionRejected).error;

Map<String, Object?> writeFor(
  DistributionAccepted plan,
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

bool hasWrite(DistributionAccepted plan, String collectionId) =>
    plan.writes.any((InventoryWrite w) => w.collectionId == collectionId);

void main() {
  // ═══════════════════════════════════════════════════════════════════════
  // ① و② — الصلاحية والنطاق
  // ═══════════════════════════════════════════════════════════════════════
  group('★★ البوابة — الصلاحية والنطاق قبل أي معاملة', () {
    test('⛔ حسابٌ معطَّل يُرفض ولو ملك كل المفاتيح (ERR_AUTH_004)', () {
      final DistributionPlan plan = planDistribution(
        request(actor: account(disabled: true), distribution: payload()),
        DistributionOperation.createDistribution,
      );
      expect(rejection(plan), CallableError.accountDisabled);
    });

    test('⛔ بلا `distributionCreate` يُرفض الإنشاء (ERR_AUTH_001)', () {
      final DistributionPlan plan = planDistribution(
        request(
          actor: account(permissions: const <Permission>{}),
          distribution: payload(),
        ),
        DistributionOperation.createDistribution,
      );
      expect(rejection(plan), CallableError.permissionMissing);
    });

    test('⛔⛔ النطاق يعلو على الصلاحية — GR-23 (ERR_AUTH_002)', () {
      final DistributionPlan plan = planDistribution(
        request(
          actor: account(scope: ScopedSources(const <String>{sourceB})),
          distribution: payload(),
        ),
        DistributionOperation.createDistribution,
      );
      expect(rejection(plan), CallableError.sourceOutOfScope);
    });

    test('⛔ مفتاح التعديل لا يُغني عن مفتاح الإلغاء', () {
      final DistributionPlan plan = planDistribution(
        request(
          actor: account(
            permissions: const <Permission>{Permission.distributionAmend},
          ),
          storedDocument: stored(),
          reason: 'سبب',
        ),
        DistributionOperation.cancelDistribution,
      );
      expect(rejection(plan), CallableError.permissionMissing);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // ⑤ — السبب النصي اختياريٌّ (ADR-0020 — كان ADR-0004 · CR-002 · DEBT-21 ①)
  // ═══════════════════════════════════════════════════════════════════════
  group('★★★ ADR-0020 — التعديل والإلغاء يمرّان بلا سبب', () {
    // ⛔⛔★★★ **ارتدادُ `ADR-0020`:** ★ **كانت الثلاثة تُرفَض.**
    test('✅ تعديل بلا سبب يمرّ — ⛔ والقيد بلا نصّ مخترَع', () {
      final DistributionAccepted plan = planDistribution(
        request(distribution: payload(), storedDocument: stored()),
        DistributionOperation.amendDistribution,
      ) as DistributionAccepted;
      expect(plan.entry.reason, isNull);
    });

    test('✅ والفراغات تمرّ وتُقرأ غياباً — ⛔ لا نصّاً فارغاً', () {
      final DistributionAccepted plan = planDistribution(
        request(
          distribution: payload(),
          storedDocument: stored(),
          reason: '   ',
        ),
        DistributionOperation.amendDistribution,
      ) as DistributionAccepted;
      expect(plan.entry.reason, isNull);
    });

    test('✅ إلغاء بلا سبب يمرّ — والوسم يقع كما هو', () {
      final DistributionAccepted plan = planDistribution(
        request(storedDocument: stored()),
        DistributionOperation.cancelDistribution,
      ) as DistributionAccepted;
      expect(plan.entry.reason, isNull);
      expect(plan.entry.action, AuditAction.cancel);
    });

    test('★ ولا يسري على الإنشاء', () {
      final DistributionPlan plan = planDistribution(
        request(distribution: payload()),
        DistributionOperation.createDistribution,
      );
      expect(plan, isA<DistributionAccepted>());
    });

    // ★★ **وسببٌ مكتوبٌ يُخزَّن كاملاً** — `ADR-0020` القيد 3.
    test('✅★★ وسببٌ كتبه إنسانٌ يُحفَظ حرفياً — ⛔ ولا يُقتطَع ولا يُهمَل', () {
      final DistributionAccepted plan = planDistribution(
        request(
          distribution: payload(),
          storedDocument: stored(),
          reason: 'تصحيح كمية العوارض',
        ),
        DistributionOperation.amendDistribution,
      ) as DistributionAccepted;
      expect(plan.entry.reason, 'تصحيح كمية العوارض');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // ⑦ ★★★ GR-18 — المعرّف المركّب
  // ═══════════════════════════════════════════════════════════════════════
  group('★★★ GR-18 — توزيعة واحدة لكل (مقوت × مصدر × يوم)', () {
    test('⛔⛔ إنشاءٌ فوق قائم يُرفض بـERR_DIST_001 لا بخطأ طلب', () {
      final DistributionPlan plan = planDistribution(
        request(distribution: payload(), storedDocument: stored()),
        DistributionOperation.createDistribution,
      );
      expect(rejection(plan), CallableError.distributionExists);
      expect(rejection(plan).code, 'ERR_DIST_001');
    });

    test('★★ ومعرّف المستند هو المركّب لا رقم المستند', () {
      final DistributionAccepted plan = accepted(
        planDistribution(
          request(distribution: payload()),
          DistributionOperation.createDistribution,
        ),
      );
      expect(plan.distributionId, compositeA);
      expect(
        plan.writes
            .firstWhere(
              (InventoryWrite w) =>
                  w.collectionId == distributionsCollection,
            )
            .documentId,
        compositeA,
      );
    });

    test('★★ وقيد التدقيق يحمل المعرّف المركّب — فيُفتَح منه المستند', () {
      final DistributionAccepted plan = accepted(
        planDistribution(
          request(distribution: payload()),
          DistributionOperation.createDistribution,
        ),
      );
      expect(plan.entry.target.entityId, compositeA);
      expect(plan.entry.target.entityType, distributionEntityType);
      expect(plan.entry.target.sourceId, sourceA);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // ⑧ ★★★ ت-12 — حارس السعر (FR-M10-07 · FR-M10-10 · AT-25)
  // ═══════════════════════════════════════════════════════════════════════
  group('★★★ ت-12 — «إخفاء الحقل تسهيل واجهة لا حماية»', () {
    test('⛔⛔ AT-25: سعرٌ من بلا `distributionPriceNow` يُرفض', () {
      final DistributionPlan plan = planDistribution(
        request(
          actor: account(
            permissions: const <Permission>{Permission.distributionCreate},
          ),
          distribution: payload(),
        ),
        DistributionOperation.createDistribution,
      );
      expect(rejection(plan), CallableError.distributionPricingDenied);
      expect(rejection(plan).code, 'ERR_PRICE_001');
    });

    test('✅ ومستندٌ بلا سعرٍ يمرّ بـ`distributionCreate` وحدها', () {
      final DistributionPlan plan = planDistribution(
        request(
          actor: account(
            permissions: const <Permission>{Permission.distributionCreate},
          ),
          distribution: payload(
            lines: <DistributionLineInput>[pieceLine(unitPrice: null)],
          ),
        ),
        DistributionOperation.createDistribution,
      );
      expect(plan, isA<DistributionAccepted>());
    });

    test('⛔ تغييرُ سعرٍ قائم يشترط `distributionPriceAmend`', () {
      final DistributionPlan plan = planDistribution(
        request(
          actor: account(
            permissions: const <Permission>{
              Permission.distributionCreate,
              Permission.distributionAmend,
              Permission.distributionPriceNow,
            },
          ),
          distribution: payload(
            lines: <DistributionLineInput>[pieceLine(unitPrice: 1600)],
          ),
          storedDocument: stored(),
          storedUnitPrices: const <String, Money?>{itemA: Money(1500)},
          hasStoredPricing: true,
          reason: 'تصحيح سعر',
        ),
        DistributionOperation.amendDistribution,
      );
      expect(rejection(plan), CallableError.distributionPricingDenied);
    });

    test('⛔ تفريغُ سعرٍ قائم يشترط `distributionPriceClear`', () {
      final DistributionPlan plan = planDistribution(
        request(
          actor: account(
            permissions: const <Permission>{
              Permission.distributionCreate,
              Permission.distributionAmend,
              Permission.distributionPriceNow,
              Permission.distributionPriceAmend,
            },
          ),
          distribution: payload(
            lines: <DistributionLineInput>[pieceLine(unitPrice: null)],
          ),
          storedDocument: stored(),
          storedUnitPrices: const <String, Money?>{itemA: Money(1500)},
          hasStoredPricing: true,
          reason: 'إلغاء السعر',
        ),
        DistributionOperation.amendDistribution,
      );
      expect(rejection(plan), CallableError.distributionPricingDenied);
    });

    test('⛔⛔ وحذفُ سطرٍ مسعَّر تفريغٌ كذلك — ولا بابَ التفاف', () {
      final DistributionPlan plan = planDistribution(
        request(
          actor: account(
            permissions: const <Permission>{
              Permission.distributionCreate,
              Permission.distributionAmend,
              Permission.distributionPriceNow,
              Permission.distributionPriceAmend,
            },
          ),
          // ★ السطر المسعَّر `itemScrap` اختفى من الحمولة.
          distribution: payload(
            lines: <DistributionLineInput>[pieceLine(unitPrice: 1500)],
          ),
          storedDocument: stored(itemIds: <String>[itemA, itemScrap]),
          items: <String, ItemRead>{
            itemA: item(),
            itemScrap: item(itemId: itemScrap),
          },
          ledger: <String, List<LedgerRead>>{
            itemA: <LedgerRead>[movement('seed-a', 1000)],
            itemScrap: <LedgerRead>[movement('seed-b', 100, itemKey: itemScrap)],
          },
          storedUnitPrices: const <String, Money?>{
            itemA: Money(1500),
            itemScrap: Money(4000),
          },
          hasStoredPricing: true,
          reason: 'حذف سطر',
        ),
        DistributionOperation.amendDistribution,
      );
      expect(rejection(plan), CallableError.distributionPricingDenied);
    });

    test('✅★★ وإعادةُ إرسال السعر نفسه ليست «تعديلاً»', () {
      final DistributionPlan plan = planDistribution(
        request(
          actor: account(
            permissions: const <Permission>{
              Permission.distributionCreate,
              Permission.distributionAmend,
            },
          ),
          distribution: payload(
            lines: <DistributionLineInput>[pieceLine(unitPrice: 1500)],
          ),
          storedDocument: stored(),
          storedUnitPrices: const <String, Money?>{itemA: Money(1500)},
          hasStoredPricing: true,
          reason: 'تعديل كمية',
        ),
        DistributionOperation.amendDistribution,
      );
      expect(plan, isA<DistributionAccepted>());
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // ⑨ ★★★ ADR-0011 — الأسعار في مستندها الفرعي وحدها
  // ═══════════════════════════════════════════════════════════════════════
  group('★★★ ADR-0011 — ولا مبلغٌ واحد في المستند الأب', () {
    late DistributionAccepted plan;

    setUp(() {
      plan = accepted(
        planDistribution(
          request(
            distribution: payload(
              lines: <DistributionLineInput>[
                pieceLine(unitPrice: 1500),
                weightLine(),
              ],
            ),
            items: <String, ItemRead>{
              itemA: item(),
              itemScrap: item(itemId: itemScrap, unit: ItemUnit.kilogram),
            },
            ledger: <String, List<LedgerRead>>{
              itemA: <LedgerRead>[movement('seed-a', 1000)],
              itemScrap: <LedgerRead>[scrapStock()],
            },
          ),
          DistributionOperation.createDistribution,
        ),
      );
    });

    test('⛔ الأب بلا `debtValue` ولا `unitPrice` ولا `lineTotal`', () {
      final Map<String, Object?> parent =
          writeFor(plan, distributionsCollection);
      expect(parent.containsKey('debtValue'), isFalse);
      expect(parent.containsKey('unitPrices'), isFalse);
      expect(parent.containsKey('lineTotals'), isFalse);
      for (final Object? line in parent['lines']! as List<Object?>) {
        final Map<String, Object?> row = line! as Map<String, Object?>;
        expect(row.containsKey('unitPrice'), isFalse);
        expect(row.containsKey('lineTotal'), isFalse);
      }
    });

    test('★ والأب يحمل عدداً لا مبلغاً — `unpricedLineCount`', () {
      expect(writeFor(plan, distributionsCollection)['unpricedLineCount'], 0);
    });

    test('★★ والأسعار في `pricing/current` بمسارها المبنيّ من الثوابت', () {
      final String pricingPath =
          '$distributionsCollection/$compositeA/$distributionPricingSubcollection';
      expect(hasWrite(plan, pricingPath), isTrue);
      final Map<String, Object?> pricing = writeFor(plan, pricingPath);
      expect(pricing['sourceId'], sourceA);
      // 80 × 1,500 = 120,000  ·  1.234 كجم × 1,501 ⟵ 1,852 (ADR-0019)
      expect(pricing['unitPrices'], <Object?>[1500, 1501]);
      expect(pricing['lineTotals'], <Object?>[120000, 1852]);
      expect(pricing['debtValue'], 121852);
    });

    test('⛔ ومستندٌ بلا سعرٍ ولا سابقةٍ لا يُكتب له مستند أسعار', () {
      final DistributionAccepted unpriced = accepted(
        planDistribution(
          request(
            distribution: payload(
              lines: <DistributionLineInput>[pieceLine(unitPrice: null)],
            ),
          ),
          DistributionOperation.createDistribution,
        ),
      );
      final String pricingPath =
          '$distributionsCollection/$compositeA/$distributionPricingSubcollection';
      expect(hasWrite(unpriced, pricingPath), isFalse);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // ④ ★★★ FR-M10-05 — الخصم المخزني فوري والمديونية بالمسعَّر وحده
  // ═══════════════════════════════════════════════════════════════════════
  group('★★★ FR-M10-05 — الخصم فوري والمديونية بالمسعَّر وحده', () {
    test('AT-23: سطرٌ مسعَّر وآخر بلا سعر ⟵ الحركتان تخرجان والدين للمسعَّر', () {
      final DistributionAccepted plan = accepted(
        planDistribution(
          request(
            distribution: payload(
              lines: <DistributionLineInput>[
                pieceLine(unitPrice: 1500),
                pieceLine(itemId: itemScrap, quantity: 20, unitPrice: null),
              ],
            ),
            items: <String, ItemRead>{
              itemA: item(),
              itemScrap: item(itemId: itemScrap),
            },
            ledger: <String, List<LedgerRead>>{
              itemA: <LedgerRead>[movement('m1', 200)],
              itemScrap: <LedgerRead>[
                movement('m2', 50, itemKey: itemScrap),
              ],
            },
          ),
          DistributionOperation.createDistribution,
        ),
      );

      // ★ حركتا خروجٍ رغم أن أحد السطرين غير مسعَّر.
      final Iterable<InventoryWrite> movements = plan.writes.where(
        (InventoryWrite w) => w.collectionId == inventoryLedgerCollection,
      );
      expect(movements.length, 2);
      for (final InventoryWrite w in movements) {
        expect(w.fields['direction'], MovementDirection.outgoing.name);
        expect(w.fields['sourceDocType'], SourceDocumentType.distribution.name);
      }

      // ⛔ والمديونية بالمسعَّر وحده: 80 × 1,500 = 120,000.
      expect(
        writeFor(plan, dealerLedgerCollection)['amount'],
        120000,
      );
      expect(writeFor(plan, distributionsCollection)['status'],
          DistributionStatus.partiallyPriced.name);
    });

    test('★ ومستندٌ بلا سعرٍ إطلاقاً يُنشئ قيداً بصفر ينمو عند التسعير', () {
      final DistributionAccepted plan = accepted(
        planDistribution(
          request(
            distribution: payload(
              lines: <DistributionLineInput>[pieceLine(unitPrice: null)],
            ),
            ledger: <String, List<LedgerRead>>{
              itemA: <LedgerRead>[movement('m1', 200)],
            },
          ),
          DistributionOperation.createDistribution,
        ),
      );
      expect(writeFor(plan, dealerLedgerCollection)['amount'], 0);
      expect(writeFor(plan, distributionsCollection)['status'],
          DistributionStatus.approved.name);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // ⑥ — منع الرصيد السالب (FR-M8-01 · GR-11 · E-01)
  // ═══════════════════════════════════════════════════════════════════════
  group('★★ منع الرصيد السالب — مقيساً من الدفتر', () {
    test('⛔ E-01: توزيعٌ يتجاوز المتاح يُرفض (ERR_STOCK_001)', () {
      final DistributionPlan plan = planDistribution(
        request(
          distribution: payload(
            lines: <DistributionLineInput>[pieceLine(quantity: 120)],
          ),
          ledger: <String, List<LedgerRead>>{
            itemA: <LedgerRead>[movement('m1', 100)],
          },
        ),
        DistributionOperation.createDistribution,
      );
      expect(rejection(plan), CallableError.insufficientStock);
    });

    test('✅ وتوزيعٌ بالمتاح تماماً يمرّ', () {
      final DistributionPlan plan = planDistribution(
        request(
          distribution: payload(
            lines: <DistributionLineInput>[pieceLine(quantity: 100)],
          ),
          ledger: <String, List<LedgerRead>>{
            itemA: <LedgerRead>[movement('m1', 100)],
          },
        ),
        DistributionOperation.createDistribution,
      );
      expect(plan, isA<DistributionAccepted>());
    });

    test('⛔ والحركة الملغاة لا تُضيف رصيداً', () {
      final DistributionPlan plan = planDistribution(
        request(
          distribution: payload(
            lines: <DistributionLineInput>[pieceLine(quantity: 100)],
          ),
          ledger: <String, List<LedgerRead>>{
            itemA: <LedgerRead>[
              movement('m1', 100),
              movement('m2', 50, cancelled: true),
            ],
          },
        ),
        DistributionOperation.createDistribution,
      );
      expect(plan, isA<DistributionAccepted>());

      final DistributionPlan tooMuch = planDistribution(
        request(
          distribution: payload(
            lines: <DistributionLineInput>[pieceLine(quantity: 101)],
          ),
          ledger: <String, List<LedgerRead>>{
            itemA: <LedgerRead>[
              movement('m1', 100),
              movement('m2', 50, cancelled: true),
            ],
          },
        ),
        DistributionOperation.createDistribution,
      );
      expect(rejection(tooMuch), CallableError.insufficientStock);
    });

    test('★ ورمزُ التعديل مستقل — ERR_AMEND_003 لا ERR_STOCK_001', () {
      final DistributionPlan plan = planDistribution(
        request(
          distribution: payload(
            lines: <DistributionLineInput>[pieceLine(quantity: 500)],
          ),
          storedDocument: stored(),
          reason: 'زيادة',
          ledger: <String, List<LedgerRead>>{
            itemA: <LedgerRead>[movement('m1', 100)],
          },
        ),
        DistributionOperation.amendDistribution,
      );
      expect(rejection(plan), CallableError.amendReducesBelowIssued);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // الطرفان — المصدر والمقوت
  // ═══════════════════════════════════════════════════════════════════════
  group('★ المصدر والمقوت — FR-M10-12 · ERR_DIST_002 · ERR_DIST_003', () {
    test('⛔ مقوت معطَّل يُرفض في التوزيع الجديد', () {
      final DistributionPlan plan = planDistribution(
        request(
          distribution: payload(),
          storedDealer: const <String, Object?>{'isActive': false},
        ),
        DistributionOperation.createDistribution,
      );
      expect(rejection(plan), CallableError.dealerInactive);
      expect(rejection(plan).code, 'ERR_DIST_002');
    });

    test('⛔ مصدر معطَّل يُرفض كذلك', () {
      final DistributionPlan plan = planDistribution(
        request(
          distribution: payload(),
          storedSource: const <String, Object?>{'isActive': false},
        ),
        DistributionOperation.createDistribution,
      );
      expect(rejection(plan), CallableError.sourceInactive);
    });

    test('✅★★ والإلغاء يبقى ممكناً على مقوتٍ عُطِّل', () {
      final DistributionPlan plan = planDistribution(
        request(
          storedDocument: stored(),
          storedDealer: const <String, Object?>{'isActive': false},
          reason: 'إلغاء',
          ledger: <String, List<LedgerRead>>{
            itemA: <LedgerRead>[
              movement(
                stockMovementId(documentNumber: docNumber, itemKey: itemA),
                80,
                direction: MovementDirection.outgoing,
              ),
            ],
          },
        ),
        DistributionOperation.cancelDistribution,
      );
      expect(plan, isA<DistributionAccepted>());
    });

    test('⛔ سجلٌّ لم يُقرأ ⟵ رفضٌ داخلي لا تجاوز', () {
      final DistributionPlan plan = planDistribution(
        request(distribution: payload(), storedDealer: null),
        DistributionOperation.createDistribution,
      );
      expect(rejection(plan), CallableError.internal);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // ★★★ E-15 — إلغاء ضمارٍ سُدِّد
  // ═══════════════════════════════════════════════════════════════════════
  group('★★★ E-15 — لا إلغاء لضمارٍ سُدِّد كلياً أو جزئياً', () {
    DistributionPlan cancelWith({int? settled, int? discounted}) =>
        planDistribution(
          request(
            storedDocument: stored(),
            storedSettlement: (settled == null && discounted == null)
                ? null
                : computeDebtSettlement(
                    debtValue: const Money(120000),
                    settledAmount: Money(settled ?? 0),
                    discountedAmount: Money(discounted ?? 0),
                  ),
            reason: 'إلغاء',
            ledger: <String, List<LedgerRead>>{
              itemA: <LedgerRead>[
                movement(
                  stockMovementId(documentNumber: docNumber, itemKey: itemA),
                  80,
                  direction: MovementDirection.outgoing,
                ),
              ],
            },
          ),
          DistributionOperation.cancelDistribution,
        );

    test('⛔ سُدِّد جزئياً ⟵ ERR_AMEND_005', () {
      expect(
        rejection(cancelWith(settled: 1)).code,
        'ERR_AMEND_005',
      );
    });

    test('⛔ وخُصم منه ⟵ ERR_AMEND_005 كذلك', () {
      expect(
        rejection(cancelWith(discounted: 500)).code,
        'ERR_AMEND_005',
      );
    });

    test('✅★★ ولم يُمَسّ ⟵ يُلغى، وحركته وقيده يُوسَمان ملغيَين', () {
      final DistributionAccepted plan = accepted(cancelWith());
      expect(
        writeFor(plan, distributionsCollection)['status'],
        DistributionStatus.cancelled.name,
      );
      expect(
        writeFor(plan, inventoryLedgerCollection)['isCancelled'],
        isTrue,
      );
      expect(writeFor(plan, dealerLedgerCollection)['isCancelled'], isTrue);
      // ⛔ **ولا قيدٌ مضاد** — القيد نفسه يُوسَم.
      expect(
        plan.writes
            .where((InventoryWrite w) =>
                w.collectionId == dealerLedgerCollection)
            .length,
        1,
      );
    });

    test('★★ والإلغاء يُسقِط الدين من الرصيد — ⛔ بلا حركة عكسية', () {
      final DistributionAccepted plan = accepted(cancelWith());
      expect(writeFor(plan, dealerBalancesCollection)['balance'], 0);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // ★★ رصيد المقوت — design-overview §2.4 · GR-20
  // ═══════════════════════════════════════════════════════════════════════
  group('★★ رصيد المقوت — مجموعاً من الدفتر لا مراكماً', () {
    DealerLedgerRead entry(
      String id,
      int amount, {
      DealerLedgerDirection direction = DealerLedgerDirection.debit,
      bool cancelled = false,
    }) =>
        DealerLedgerRead(
          entryId: id,
          entry: DealerLedgerEntry(
            direction: direction,
            amount: Money(amount),
            isCancelled: cancelled,
          ),
        );

    test('★ الرصيد = المدين − الدائن من قيود هذا المصدر وحدها', () {
      final DistributionAccepted plan = accepted(
        planDistribution(
          request(
            distribution: payload(),
            dealerLedger: <DealerLedgerRead>[
              entry('old-debt', 50000),
              entry(
                'old-receipt',
                20000,
                direction: DealerLedgerDirection.credit,
              ),
            ],
          ),
          DistributionOperation.createDistribution,
        ),
      );
      // 50,000 − 20,000 + 120,000 = 150,000.
      expect(writeFor(plan, dealerBalancesCollection)['balance'], 150000);
      expect(writeFor(plan, dealerLedgerCollection)['balanceAfter'], 150000);
    });

    test('★★★ والتعديل يستبدل قيدي لا يُراكم عليه — قابلية التكرار', () {
      final String entryId = debtLedgerEntryId(documentNumber: docNumber);
      final DistributionAccepted plan = accepted(
        planDistribution(
          request(
            distribution: payload(),
            storedDocument: stored(),
            storedUnitPrices: const <String, Money?>{itemA: Money(1500)},
            hasStoredPricing: true,
            reason: 'تعديل',
            dealerLedger: <DealerLedgerRead>[entry(entryId, 999999)],
            ledger: <String, List<LedgerRead>>{
              itemA: <LedgerRead>[movement('m1', 500)],
            },
          ),
          DistributionOperation.amendDistribution,
        ),
      );
      // ⛔ **القيد القديم لا يُجمع مع الجديد** — الرصيد 120,000 لا 1,119,999.
      expect(writeFor(plan, dealerBalancesCollection)['balance'], 120000);
    });

    test('⛔ والقيود الملغاة لا تدخل الرصيد', () {
      final DistributionAccepted plan = accepted(
        planDistribution(
          request(
            distribution: payload(),
            dealerLedger: <DealerLedgerRead>[
              entry('gone', 999999, cancelled: true),
            ],
          ),
          DistributionOperation.createDistribution,
        ),
      );
      expect(writeFor(plan, dealerBalancesCollection)['balance'], 120000);
    });

    test('★★ وحقل `balance` بعينه هو ما يقرؤه حارس تعطيل المقوت', () {
      final DistributionAccepted plan = accepted(
        planDistribution(
          request(distribution: payload()),
          DistributionOperation.createDistribution,
        ),
      );
      final Map<String, Object?> balance =
          writeFor(plan, dealerBalancesCollection);
      expect(balance['balance'], isA<int>());
      expect(balance['sourceId'], sourceA);
      expect(balance['dealerId'], dealerA);
      // ⛔ **ولا `openDebtCount` ولا `oldestOpenDebtDate`** — لا كاتب لهما بعد.
      expect(balance.containsKey('openDebtCount'), isFalse);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // المستند وحقوله
  // ═══════════════════════════════════════════════════════════════════════
  group('★ حقول المستند — GR-19 · FR-M10-14 · التسوية', () {
    test('⛔ GR-19: إجماليان منفصلان دائماً', () {
      final DistributionAccepted plan = accepted(
        planDistribution(
          request(
            distribution: payload(
              lines: <DistributionLineInput>[
                pieceLine(quantity: 80, unitPrice: null),
                weightLine(quantity: 1.5, unitPrice: null),
              ],
            ),
            items: <String, ItemRead>{
              itemA: item(),
              itemScrap: item(itemId: itemScrap, unit: ItemUnit.kilogram),
            },
            ledger: <String, List<LedgerRead>>{
              itemA: <LedgerRead>[movement('seed-a', 1000)],
              itemScrap: <LedgerRead>[scrapStock()],
            },
          ),
          DistributionOperation.createDistribution,
        ),
      );
      final Map<String, Object?> parent =
          writeFor(plan, distributionsCollection);
      expect(parent['totalPieces'], 80);
      expect(parent['totalWeight'].toString(), contains('1.5'));
    });

    test('★★ FR-M10-14: `sackId` يصل حركة الدفتر فتُطلق احتساب الجونية', () {
      final DistributionAccepted plan = accepted(
        planDistribution(
          request(
            distribution: payload(
              lines: <DistributionLineInput>[
                pieceLine(sackId: 'SCK-20260827-0001'),
              ],
            ),
          ),
          DistributionOperation.createDistribution,
        ),
      );
      expect(
        writeFor(plan, inventoryLedgerCollection)['sackId'],
        'SCK-20260827-0001',
      );
    });

    test('⛔⛔ ولا حقل تسويةٍ واحد يكتبه WU-006', () {
      final Map<String, Object?> parent = writeFor(
        accepted(
          planDistribution(
            request(distribution: payload()),
            DistributionOperation.createDistribution,
          ),
        ),
        distributionsCollection,
      );
      expect(parent.containsKey('settledAmount'), isFalse);
      expect(parent.containsKey('discountedAmount'), isFalse);
      expect(parent.containsKey('remaining'), isFalse);
      expect(parent.containsKey('settlementStatus'), isFalse);
    });

    test('★ وشارة «مُعدَّل ×N» تنمو بالتعديل', () {
      final DistributionAccepted plan = accepted(
        planDistribution(
          request(
            distribution: payload(),
            storedDocument: <String, Object?>{...stored(), 'amendCount': 2},
            storedUnitPrices: const <String, Money?>{itemA: Money(1500)},
            hasStoredPricing: true,
            reason: 'تعديل',
          ),
          DistributionOperation.amendDistribution,
        ),
      );
      expect(writeFor(plan, distributionsCollection)['amendCount'], 3);
      expect(writeFor(plan, distributionsCollection)['amendReason'], 'تعديل');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // المخزَّن هو الحَكَم
  // ═══════════════════════════════════════════════════════════════════════
  group('★★★ المخزَّن هو الحَكَم لا المُرسَل', () {
    test('⛔ مستندٌ لمصدرٍ آخر يُرفض ولو كان النطاق شاملاً', () {
      final DistributionPlan plan = planDistribution(
        request(
          distribution: payload(),
          storedDocument: stored(sourceId: sourceB),
          reason: 'تعديل',
        ),
        DistributionOperation.amendDistribution,
      );
      expect(rejection(plan), CallableError.sourceOutOfScope);
    });

    test('⛔ ومستندٌ لمقوتٍ آخر يُرفض', () {
      final DistributionPlan plan = planDistribution(
        request(
          distribution: payload(),
          storedDocument: stored(dealerId: 'MQT-0009'),
          reason: 'تعديل',
        ),
        DistributionOperation.amendDistribution,
      );
      expect(rejection(plan), CallableError.invalidArgument);
    });

    test('⛔ ويومٌ مخزونٍ مختلف يُرفض', () {
      final DistributionPlan plan = planDistribution(
        request(
          distribution: payload(),
          storedDocument: stored(stockDate: CalendarDay(2026, 8, 26)),
          reason: 'تعديل',
        ),
        DistributionOperation.amendDistribution,
      );
      expect(rejection(plan), CallableError.invalidArgument);
    });

    test('⛔ والملغى لا يُعدَّل ولا يُلغى ثانيةً (ERR_AMEND_006)', () {
      final DistributionPlan plan = planDistribution(
        request(
          distribution: payload(),
          storedDocument: stored(status: 'cancelled'),
          reason: 'تعديل',
        ),
        DistributionOperation.amendDistribution,
      );
      expect(rejection(plan), CallableError.documentCancelled);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // الأنواع
  // ═══════════════════════════════════════════════════════════════════════
  group('★ الأنواع — نشطةٌ ومرتبطةٌ بالمصدر وبوحدتها', () {
    test('⛔ نوعٌ غير مرتبط بالمصدر يُرفض — FR-M5-10', () {
      final DistributionPlan plan = planDistribution(
        request(
          distribution: payload(),
          items: <String, ItemRead>{
            itemA: item(sourceIds: const <String>[sourceB]),
          },
        ),
        DistributionOperation.createDistribution,
      );
      expect(rejection(plan), CallableError.invalidArgument);
    });

    test('⛔ ونوعٌ معطَّل يُرفض', () {
      final DistributionPlan plan = planDistribution(
        request(
          distribution: payload(),
          items: <String, ItemRead>{itemA: item(isActive: false)},
        ),
        DistributionOperation.createDistribution,
      );
      expect(rejection(plan), CallableError.invalidArgument);
    });

    test('⛔⛔ ووحدةٌ تخالف وحدة النوع المخزَّنة تُرفض — GR-19', () {
      final DistributionPlan plan = planDistribution(
        request(
          distribution: payload(),
          items: <String, ItemRead>{
            itemA: item(unit: ItemUnit.kilogram),
          },
        ),
        DistributionOperation.createDistribution,
      );
      expect(rejection(plan), CallableError.itemUnitLocked);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // ⛔⛔★★★ ارتداد: ما يعبر بين الطبقتين — الترميز نفسه (DEBT-37 · 2026-08-27)
  // ═══════════════════════════════════════════════════════════════════════
  group('⛔⛔★★★ ارتداد: كل ما تُنتجه الخطة يمرّ بالمُرمِّز فعلاً', () {
    // ⚠️⚠️ **عطلٌ رُصد حيّاً على المحاكي:** الخطة كانت صحيحة الحقول
    //    **والالتزام يسقط كلُّه** لأن قيداً حمل `double` مجرَّداً — ★ **والمُرمِّز
    //    يرفضه رفضاً مقصوداً** (`ADR-0015` القاعدة 1). ⟵ **ولا اختبارَ خطةٍ
    //    واحدٌ يكشفه:** ⛔ **اختبارُ الطبقة لا يُغني عن اختبار ما يعبر بينها.**
    DistributionAccepted planWithWeight() => accepted(
          planDistribution(
            request(
              distribution: payload(
                lines: <DistributionLineInput>[pieceLine(), weightLine()],
              ),
              items: <String, ItemRead>{
                itemA: item(),
                itemScrap: item(itemId: itemScrap, unit: ItemUnit.kilogram),
              },
              ledger: <String, List<LedgerRead>>{
                itemA: <LedgerRead>[movement('seed-a', 1000)],
                itemScrap: <LedgerRead>[scrapStock()],
              },
            ),
            DistributionOperation.createDistribution,
          ),
        );

    test('★★ كل مستندٍ في الخطة يُرمَّز بلا رمي', () {
      for (final InventoryWrite write in planWithWeight().writes) {
        expect(
          () => encodeFirestoreFields(write.fields),
          returnsNormally,
          reason: '${write.collectionId}/${write.documentId} لا يُرمَّز',
        );
      }
    });

    test('⛔⛔★★★ وقيدُ التدقيق يُرمَّز كذلك — وهو موضع العطل', () {
      final AuditEntry entry = planWithWeight().entry;
      expect(() => encodeFirestoreFields(entry.valuesAfter), returnsNormally);
      expect(() => encodeFirestoreFields(entry.valuesBefore), returnsNormally);
    });

    test('★ والوزن يعبر [DecimalValue] لا `double` مجرَّداً', () {
      expect(
        planWithWeight().entry.valuesAfter['totalWeight'],
        isA<DecimalValue>(),
      );
    });

    test('⛔ والمجرَّد يُرفَض فعلاً — فالحارس ليس شكلياً', () {
      expect(
        () => encodeFirestoreFields(<String, Object?>{'x': 0.0}),
        throwsArgumentError,
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // قابلية التكرار بلا أثر جانبي — coding-standards §2.7
  // ═══════════════════════════════════════════════════════════════════════
  group('★ قابلية التكرار بلا أثر جانبي', () {
    test('نفس الطلب يُنتج نفس الخطة حرفياً', () {
      DistributionAccepted run() => accepted(
            planDistribution(
              request(
                distribution: payload(),
                ledger: <String, List<LedgerRead>>{
                  itemA: <LedgerRead>[movement('m1', 200)],
                },
              ),
              DistributionOperation.createDistribution,
            ),
          );
      final DistributionAccepted first = run();
      final DistributionAccepted second = run();
      expect(
        first.writes.map((InventoryWrite w) => w.documentId).toList(),
        second.writes.map((InventoryWrite w) => w.documentId).toList(),
      );
      expect(
        writeFor(first, dealerBalancesCollection)['balance'],
        writeFor(second, dealerBalancesCollection)['balance'],
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // ★★★ FR-M12-11 · AT-31 — تطبيق الفائض تلقائياً عند إنشاء ضمار جديد
  // ═══════════════════════════════════════════════════════════════════════
  group('★★★ AT-31 — الفائض يُطبَّق عند إنشاء الضمار (`FR-M12-11`)', () {
    SurplusPoolRead pool({
      SurplusScope scope = SurplusScope.general,
      String? sourceId,
      int available = 20000,
    }) =>
        SurplusPoolRead(
          surplusId: dealerSurplusId(
            dealerId: dealerA,
            scope: scope,
            sourceId: sourceId,
          ),
          scope: scope,
          paidOn: CalendarDay(2026, 8, 20),
          available: Money(available),
        );

    DistributionPlan create(List<SurplusPoolRead> pools) => planDistribution(
          request(distribution: payload(), surplusPools: pools),
          DistributionOperation.createDistribution,
        );

    test('★★★ فائضٌ عامّ ⟵ حركةٌ دائنة ببيانٍ آلي يذكر تاريخ الدفع', () {
      final DistributionAccepted plan =
          accepted(create(<SurplusPoolRead>[pool()]));
      final InventoryWrite entry = plan.writes.firstWhere(
        (InventoryWrite w) =>
            w.collectionId == dealerLedgerCollection &&
            w.fields['entryType'] ==
                DealerLedgerEntryType.surplusApplication.name,
      );
      expect(entry.fields['amount'], 20000);
      expect(
        entry.fields['memo'],
        'تسديد تلقائي من المبلغ المدفوع بتاريخ 2026/08/20',
      );
    });

    test('★★★ والمتاح يُخصَم من سجل الفائض', () {
      final DistributionAccepted plan =
          accepted(create(<SurplusPoolRead>[pool()]));
      final InventoryWrite surplus = plan.writes.firstWhere(
        (InventoryWrite w) => w.collectionId == dealerSurplusCollection,
      );
      expect(surplus.documentId, 'MQT-0001_general');
      expect(surplus.fields['availableAmount'], 0);
    });

    test('★★★ والتسوية تُكتب في `pricing/current` — والحالة في الأب', () {
      final DistributionAccepted plan =
          accepted(create(<SurplusPoolRead>[pool()]));
      final InventoryWrite pricing = plan.writes.lastWhere(
        (InventoryWrite w) =>
            w.collectionId.endsWith(distributionPricingSubcollection),
      );
      expect(pricing.fields['settledAmount'], 20000);
      // ★ **قيمة الضمار 80 × 1500 = 120,000** ⟵ **والمتبقي 100,000.**
      expect(pricing.fields['remaining'], 100000);
    });

    test('⛔⛔★★★ E-13 · AT-32 — فائضُ مصدرٍ آخر لا يُسدَّد منه شيء', () {
      final DistributionAccepted plan = accepted(
        create(<SurplusPoolRead>[
          pool(scope: SurplusScope.source, sourceId: sourceB),
        ]),
      );
      expect(
        plan.writes.any(
          (InventoryWrite w) => w.collectionId == dealerSurplusCollection,
        ),
        isFalse,
      );
    });

    test('⛔⛔★★★ ولا يُطبَّق عند التعديل — ⛔ فلا يُسحَب فائضٌ مرتين', () {
      final DistributionPlan plan = planDistribution(
        request(
          distribution: payload(),
          storedDocument: stored(),
          surplusPools: <SurplusPoolRead>[pool()],
          reason: 'تصحيح',
        ),
        DistributionOperation.amendDistribution,
      );
      expect(
        accepted(plan).writes.any(
              (InventoryWrite w) => w.collectionId == dealerSurplusCollection,
            ),
        isFalse,
      );
    });

    test('★★★ والرصيد يعكس الدائن في المعاملة نفسها', () {
      final DistributionAccepted plan =
          accepted(create(<SurplusPoolRead>[pool()]));
      final Map<String, Object?> balance =
          writeFor(plan, dealerBalancesCollection);
      expect(balance['totalDebit'], 120000);
      expect(balance['totalCredit'], 20000);
      expect(balance['balance'], 100000);
    });

    test('★★★ وسجلّان يُسدِّدان ضماراً واحداً ⟵ حركتان لا واحدة', () {
      final DistributionAccepted plan = accepted(
        create(<SurplusPoolRead>[
          pool(available: 50000),
          pool(scope: SurplusScope.source, sourceId: sourceA, available: 90000),
        ]),
      );
      final Iterable<InventoryWrite> entries = plan.writes.where(
        (InventoryWrite w) =>
            w.collectionId == dealerLedgerCollection &&
            w.fields['entryType'] ==
                DealerLedgerEntryType.surplusApplication.name,
      );
      expect(entries.length, 2);
      // ⛔⛔ **ومعرّفان مختلفان** — ★ **وإلّا كُتبت الثانيةُ فوق الأولى.**
      expect(
        entries.map((InventoryWrite w) => w.documentId).toSet().length,
        2,
      );
      expect(
        entries.map((InventoryWrite w) => w.fields['amount']).toList()
          ..sort((Object? a, Object? b) => (a! as int).compareTo(b! as int)),
        // ★ **والأقدم أولاً — وعند تساوي التاريخ يُرجَّح بمعرّف السجل**
        //   (`MQT-0001_SRC-001` قبل `MQT-0001_general`): ⟵ **فيُستهلَك
        //   فائضُ المصدر 90,000 كاملاً ثم 30,000 من العام** ⛔ **والترتيب
        //   مستقرٌّ لا يتبدّل بين تشغيلين.**
        <int>[30000, 90000],
      );
    });

    test(
      '⛔⛔★★★ DEBT-85: والتعديلُ يُعيد بناء المتبقّي ⛔ ولا يمحو قبضاً وصل',
      () {
        // ⛔⛔★★★ **وهذا أخطرُ ما في العلاج:** ★ **كتابةُ التسوية في كل
        // تعديلٍ كانت تُصفِّر `settledAmount` لو بُنيت من الصفر** —
        // ⟵ **فيعود دينٌ سُدِّد نصفُه كاملاً على المقوت.**
        final DistributionAccepted plan = planDistribution(
          request(
            distribution: payload(),
            storedDocument: stored(),
            storedSettlement: computeDebtSettlement(
              debtValue: const Money(120000),
              settledAmount: const Money(40000),
              discountedAmount: const Money(1852),
            ),
          ),
          DistributionOperation.amendDistribution,
        ) as DistributionAccepted;

        final InventoryWrite pricing = plan.writes.firstWhere(
          (InventoryWrite w) => w.fields.containsKey('remaining'),
        );
        // ★★ **المُسدَّد والمخصوم يُصانان كما هما.**
        expect(pricing.fields['settledAmount'], 40000);
        expect(pricing.fields['discountedAmount'], 1852);
        // ★ **والمتبقّي يُعاد بناؤه على القيمة الجديدة** — `ADR-0008`:
        //   ★ **80 حبة × 1,500 = 120,000** ⟵ **− 40,000 − 1,852.**
        expect(pricing.fields['remaining'], 120000 - 40000 - 1852);

        final InventoryWrite parent = plan.writes.firstWhere(
          (InventoryWrite w) => w.fields.containsKey('settlementStatus'),
        );
        expect(
          parent.fields['settlementStatus'],
          SettlementStatus.partiallyOpen.name,
        );
      },
    );

    test('⛔ ولا سجلَ فائض ⟵ لا حركةَ تطبيقٍ في دفتر المقوت', () {
      final DistributionAccepted plan =
          accepted(create(const <SurplusPoolRead>[]));
      expect(
        plan.writes.any(
          (InventoryWrite w) =>
              w.collectionId == dealerLedgerCollection &&
              w.fields['entryType'] ==
                  DealerLedgerEntryType.surplusApplication.name,
        ),
        isFalse,
      );
    });

    test(
      '⛔⛔★★★ DEBT-85: ومع ذلك تُكتَب التسوية — ⛔ وإلا لم يُقبَض من الضمار أبداً',
      () {
        // ═══════════════════════════════════════════════════════════════
        // ⛔⛔★★★ **وكان هذا الاختبار يؤكّد عكسَه حتى 2026-09-02** —
        // ★ **«⛔ ولا سجلَ فائض ⟵ لا كتابةَ تسوية إطلاقاً»**: ⟵ **فكان
        // يُثبِّت العطل لا يمنعه.**
        //
        // ★ **والعطلُ مقيسٌ على التجريبية:** **استعلامُ الضمارات المفتوحة
        // يُقيّد `settlementStatus whereIn [open, partiallyOpen]`**،
        // ⟵ **والحقلُ الغائب لا يطابق شرطاً** ⟹ ⛔⛔ **فضمارٌ أُنشئ عادةً
        // (بلا فائض) لا يظهر في شاشتَي المقبوضات والخصومات إطلاقاً**:
        // ★ **`dealer_balances` = 62,600 ريال بينما الشاشة تقول 350.**
        // ═══════════════════════════════════════════════════════════════
        final DistributionAccepted plan =
            accepted(create(const <SurplusPoolRead>[]));

        final InventoryWrite parent = plan.writes.firstWhere(
          (InventoryWrite w) => w.fields.containsKey('settlementStatus'),
        );
        expect(parent.collectionId, distributionsCollection);
        expect(parent.fields['settlementStatus'], SettlementStatus.open.name);

        // ★★ **والمبالغ في `pricing/current` وحدها** — [`ADR-0011`].
        final InventoryWrite pricing = plan.writes.firstWhere(
          (InventoryWrite w) => w.fields.containsKey('remaining'),
        );
        expect(pricing.fields['settledAmount'], 0);
        expect(pricing.fields['discountedAmount'], 0);
        // ⛔ **والمتبقّي كلُّ قيمة الضمار** — ★ **فلا شيء سُدِّد بعد.**
        expect(pricing.fields['remaining'], isA<int>());
        expect((pricing.fields['remaining']! as int) > 0, isTrue);
      },
    );
  });
}

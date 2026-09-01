/// البيع النقدي المباشر — ★★★ **حارس التفويض والنطاق والحدّ الأدنى والرصيد**
/// (`WU-012`).
///
/// ⚠️⚠️ **ولماذا يُختبَر بهذه الصرامة:** بعد إغلاق الكتابة المباشرة
/// (`ADR-0013` القاعدة 2) **لم يبقَ بين المستخدم والدفتر إلا هذا الكود** —
/// ⟵ **فكل شرطٍ كانت تفرضه `firestore.rules` صار بند قبولٍ هنا.**
///
/// ⛔⛔★★★ **وأخطر ما تحرسه هذه الاختبارات — `FR-M11-03` (`GR-33`):**
/// **البيع النقدي لا يكتب قيداً واحداً في دفتر المقاوته ولا في أرصدته.**
/// ⟵ ★ **وهو حارسٌ لا يُثبته إلا اختبارٌ يعدّ المجموعات المكتوبة**، ⛔ **لأن
/// الخطأ هنا لا يُسقِط عملية بل يُنشئ ديناً على مقوتٍ لم يشترِ شيئاً.**
library;

import 'package:qtms_domain/qtms_domain.dart';
import 'package:qtms_functions/src/callable.dart';
import 'package:qtms_functions/src/cash_sale.dart';
import 'package:qtms_functions/src/identity_claims.dart';
import 'package:qtms_functions/src/identity_gateway.dart';
import 'package:qtms_functions/src/firestore_value.dart';
import 'package:qtms_functions/src/inventory.dart';
import 'package:test/test.dart';

const String actorUid = 'uid-seller';
const String sourceA = 'SRC-001';
const String sourceB = 'SRC-002';
const String itemA = 'ITM-0001';
const String itemScrap = 'ITM-0002';
const String docNumber = 'CSH-20260901-0001';

final CalendarDay day = CalendarDay(2026, 9, 1);

const Set<Permission> fullPermissions = <Permission>{
  Permission.cashSaleCreate,
  Permission.cashSaleAmend,
  Permission.cashSaleCancel,
  Permission.cashSaleBelowMinimum,
};

/// ★ صلاحياتٌ بلا مفتاح التجاوز.
///
/// ⚠️ **وبعد [`CR-007`] لم يعد المفتاح يُغيّر شيئاً** — ★ **وتبقى المجموعة
/// لتُثبت أن الرفض لا يعتمد عليه في الاتجاهين**: ⟵ **يُرفَض بلا المفتاح
/// وبه معاً.**
const Set<Permission> withoutOverride = <Permission>{
  Permission.cashSaleCreate,
  Permission.cashSaleAmend,
  Permission.cashSaleCancel,
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

CashSaleLineInput pieceLine({
  String itemId = itemA,
  int quantity = 80,
  int unitPrice = 1500,
  String? sackId,
}) =>
    CashSaleLineInput(
      itemId: itemId,
      itemName: 'عوارض',
      unit: ItemUnit.piece,
      quantity: PieceQuantity(PieceCount(quantity)),
      unitPrice: Money(unitPrice),
      sackId: sackId,
    );

CashSaleLineInput weightLine({
  String itemId = itemScrap,
  double quantity = 0.700,
  int unitPrice = 3500,
  String? sackId,
}) =>
    CashSaleLineInput(
      itemId: itemId,
      itemName: 'سكرب',
      unit: ItemUnit.kilogram,
      quantity: WeightQuantity(WeightKg(quantity)),
      unitPrice: Money(unitPrice),
      sackId: sackId,
    );

ValidatedCashSale payload({
  String sourceId = sourceA,
  List<CashSaleLineInput>? lines,
}) =>
    (validateCashSale(
      CashSaleInput(
        sourceId: sourceId,
        lines: lines ?? <CashSaleLineInput>[pieceLine()],
      ),
    ) as Success<ValidatedCashSale>)
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

CashSaleRequest request({
  AccountRecord? actor,
  ValidatedCashSale? sale,
  Map<String, Object?>? storedSource = const <String, Object?>{
    'isActive': true,
    'name': 'مصدر الاختبار',
  },
  Map<String, Object?>? storedDocument,
  Map<String, ItemRead>? items,
  Map<String, List<LedgerRead>>? ledger,
  Map<String, Money?> minCashPrices = const <String, Money?>{},
  String? reason,
  String sourceId = sourceA,
  String number = docNumber,
  CalendarDay? stockDate,
}) =>
    CashSaleRequest(
      actor: actor ?? account(),
      requestId: 'req-1',
      sourceId: sourceId,
      documentNumber: number,
      stockDate: stockDate ?? day,
      sale: sale,
      storedSource: storedSource,
      storedDocument: storedDocument,
      items: items ?? <String, ItemRead>{itemA: item()},
      // ★ **مخزونٌ افتراضي وافر** — ⟵ **فاختبارات التفويض تفشل على التفويض
      //   لا على نقص الرصيد**، ⛔ **ونجاحٌ لسببٍ خاطئ أسوأ من فشل.**
      ledger: ledger ??
          <String, List<LedgerRead>>{
            itemA: <LedgerRead>[movement('seed-a', 1000)],
          },
      minCashPrices: minCashPrices,
      reason: reason,
    );

/// المستند المخزَّن كما تقرؤه المعاملة.
Map<String, Object?> stored({
  String status = 'approved',
  String sourceId = sourceA,
  CalendarDay? stockDate,
  List<String> itemIds = const <String>[itemA],
}) =>
    <String, Object?>{
      'documentNumber': docNumber,
      'sourceId': sourceId,
      'stockDate': (stockDate ?? day).asUtcMidnight(),
      'status': status,
      'lines': <Object?>[
        for (final String id in itemIds)
          <String, Object?>{'itemId': id, 'quantity': 80, 'unitPrice': 1500},
      ],
    };

CashSaleAccepted accepted(CashSalePlan plan) => plan as CashSaleAccepted;

CallableError rejection(CashSalePlan plan) =>
    (plan as CashSaleRejected).error;

Map<String, Object?> writeFor(
  CashSaleAccepted plan,
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

bool hasWrite(CashSaleAccepted plan, String collectionId) =>
    plan.writes.any((InventoryWrite w) => w.collectionId == collectionId);

void main() {
  // ═══════════════════════════════════════════════════════════════════════
  // ① و② — الصلاحية والنطاق
  // ═══════════════════════════════════════════════════════════════════════
  group('★★ البوابة — الصلاحية والنطاق قبل أي معاملة', () {
    test('⛔ حسابٌ معطَّل يُرفض ولو ملك كل المفاتيح (ERR_AUTH_004)', () {
      expect(
        rejection(
          planCashSale(
            request(actor: account(disabled: true), sale: payload()),
            CashSaleOperation.createCashSale,
          ),
        ),
        CallableError.accountDisabled,
      );
    });

    test('⛔ بلا `cashSaleCreate` يُرفض الإنشاء (ERR_AUTH_001)', () {
      expect(
        rejection(
          planCashSale(
            request(
              actor: account(permissions: const <Permission>{}),
              sale: payload(),
            ),
            CashSaleOperation.createCashSale,
          ),
        ),
        CallableError.permissionMissing,
      );
    });

    test('⛔⛔ النطاق يعلو على الصلاحية — GR-23 (ERR_AUTH_002)', () {
      expect(
        rejection(
          planCashSale(
            request(
              actor: account(scope: ScopedSources(const <String>{sourceB})),
              sale: payload(),
            ),
            CashSaleOperation.createCashSale,
          ),
        ),
        CallableError.sourceOutOfScope,
      );
    });

    test('⛔ ومعرّف الطلب إلزامي — وبدونه لا لاتكرارية عند إعادة الإرسال', () {
      final CashSalePlan plan = planCashSale(
        CashSaleRequest(
          actor: account(),
          requestId: '   ',
          sourceId: sourceA,
          documentNumber: docNumber,
          stockDate: day,
          sale: payload(),
        ),
        CashSaleOperation.createCashSale,
      );
      expect(rejection(plan), CallableError.invalidArgument);
    });

    test('⛔ ولكل عملية مفتاحُها — التعديل لا يمرّ بمفتاح الإنشاء', () {
      expect(
        rejection(
          planCashSale(
            request(
              actor: account(
                permissions: const <Permission>{Permission.cashSaleCreate},
              ),
              sale: payload(),
              storedDocument: stored(),
            ),
            CashSaleOperation.amendCashSale,
          ),
        ),
        CallableError.permissionMissing,
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // ⑥ ⛔⛔★★★ FR-M11-03 — ولا أثرَ على ذمم المقاوته إطلاقاً
  // ═══════════════════════════════════════════════════════════════════════
  group('⛔⛔★★★ FR-M11-03 — لا قيدَ ولا رصيدَ ولا فائضَ لمقوت', () {
    test('⛔⛔ ولا كتابةَ واحدة في `dealer_ledger` ولا `dealer_balances`', () {
      final CashSaleAccepted plan = accepted(
        planCashSale(
          request(sale: payload()),
          CashSaleOperation.createCashSale,
        ),
      );
      expect(hasWrite(plan, dealerLedgerCollection), isFalse);
      expect(hasWrite(plan, dealerBalancesCollection), isFalse);
      expect(hasWrite(plan, dealerSurplusCollection), isFalse);
    });

    test('★★ والمجموعاتُ المكتوبة ثلاثٌ لا أكثر — سند وحركة ورصيد نوع', () {
      final CashSaleAccepted plan = accepted(
        planCashSale(
          request(sale: payload()),
          CashSaleOperation.createCashSale,
        ),
      );
      expect(
        plan.writes.map((InventoryWrite w) => w.collectionId).toSet(),
        <String>{
          cashSalesCollection,
          inventoryLedgerCollection,
          itemDailyBalancesCollection,
        },
      );
    });

    test('⛔ ولا حقلَ مقوتٍ ولا مشترٍ ولا خصمٍ في المستند — FR-M11-12', () {
      final Map<String, Object?> document = writeFor(
        accepted(
          planCashSale(
            request(sale: payload()),
            CashSaleOperation.createCashSale,
          ),
        ),
        cashSalesCollection,
      );
      expect(document.containsKey('dealerId'), isFalse);
      expect(document.containsKey('dealerName'), isFalse);
      expect(document.containsKey('buyerName'), isFalse);
      expect(document.containsKey('discount'), isFalse);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // ⑧ ★★★ الحد الأدنى — FR-M11-05 · FR-M11-06 · GR-34
  // ═══════════════════════════════════════════════════════════════════════
  group('★★★ حارس الحد الأدنى — ERR_PRICE_002 (CR-007)', () {
    test('⛔⛔ سعرٌ دون الحد يُرفَض', () {
      expect(
        rejection(
          planCashSale(
            request(
              actor: account(permissions: withoutOverride),
              sale: payload(
                lines: <CashSaleLineInput>[pieceLine(unitPrice: 600)],
              ),
              minCashPrices: const <String, Money?>{itemA: Money(700)},
            ),
            CashSaleOperation.createCashSale,
          ),
        ),
        CallableError.belowMinimumCashPrice,
      );
    });

    test(
      '⛔⛔★★★ CR-007: ويُرفَض ولو ملك المُرسِل `cashSaleBelowMinimum` — '
      'فالحدُّ حدٌّ فعليٌّ لا اقتراحٌ بصلاحية',
      () {
        // ⚠️⚠️ **وهذا ارتدادُ قرارِ المالك (2026-09-01):** ★ **`FR-M11-05`
        //    الأصلي كان يستثني حاملَ المفتاح** — ⟵ **وأُلغي الاستثناء**،
        //    ⛔ **فلا مسارَ يمرّ بسعرٍ دون الحد إطلاقاً.**
        expect(
          rejection(
            planCashSale(
              request(
                // ★ **حسابٌ يملك كل المفاتيح — ومنها مفتاح التجاوز.**
                actor: account(),
                sale: payload(
                  lines: <CashSaleLineInput>[pieceLine(unitPrice: 600)],
                ),
                minCashPrices: const <String, Money?>{itemA: Money(700)},
              ),
              CashSaleOperation.createCashSale,
            ),
          ),
          CallableError.belowMinimumCashPrice,
        );
      },
    );

    test('✅ والمساواةُ بالحد تمرّ بلا مفتاح — «لا يقل عن»', () {
      expect(
        planCashSale(
          request(
            actor: account(permissions: withoutOverride),
            sale: payload(
              lines: <CashSaleLineInput>[pieceLine(unitPrice: 700)],
            ),
            minCashPrices: const <String, Money?>{itemA: Money(700)},
          ),
          CashSaleOperation.createCashSale,
        ),
        isA<CashSaleAccepted>(),
      );
    });

    test('✅★★ FR-M11-06: ونوعٌ بلا حدٍّ مسجَّل يُباع بلا مفتاح تجاوز', () {
      expect(
        planCashSale(
          request(
            actor: account(permissions: withoutOverride),
            sale: payload(
              lines: <CashSaleLineInput>[pieceLine(unitPrice: 1)],
            ),
            // ⛔ **ولا حدَّ في الخريطة** — ★ **وهو ما يعنيه «غير مسعَّر».**
            minCashPrices: const <String, Money?>{},
          ),
          CashSaleOperation.createCashSale,
        ),
        isA<CashSaleAccepted>(),
      );
    });

    test('⛔⛔★★ ويُفحَص على التعديل كذلك — ⛔ ولا بابَ خلفيّ', () {
      expect(
        rejection(
          planCashSale(
            request(
              actor: account(),
              sale: payload(
                lines: <CashSaleLineInput>[pieceLine(unitPrice: 600)],
              ),
              storedDocument: stored(),
              minCashPrices: const <String, Money?>{itemA: Money(700)},
            ),
            CashSaleOperation.amendCashSale,
          ),
        ),
        CallableError.belowMinimumCashPrice,
      );
    });

    test('⛔ ويكفي سطرٌ واحدٌ دون الحد ليُرفَض السند كلُّه', () {
      expect(
        rejection(
          planCashSale(
            request(
              actor: account(permissions: withoutOverride),
              sale: payload(
                lines: <CashSaleLineInput>[
                  pieceLine(unitPrice: 1500),
                  weightLine(unitPrice: 100),
                ],
              ),
              items: <String, ItemRead>{
                itemA: item(),
                itemScrap: item(
                  itemId: itemScrap,
                  unit: ItemUnit.kilogram,
                ),
              },
              ledger: <String, List<LedgerRead>>{
                itemA: <LedgerRead>[movement('seed-a', 1000)],
                itemScrap: <LedgerRead>[scrapStock()],
              },
              minCashPrices: const <String, Money?>{
                itemA: Money(700),
                itemScrap: Money(3000),
              },
            ),
            CashSaleOperation.createCashSale,
          ),
        ),
        CallableError.belowMinimumCashPrice,
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // ⑤ منع الرصيد السالب — FR-M8-01 · GR-11 · E-01
  // ═══════════════════════════════════════════════════════════════════════
  group('★★ الرصيد — مقيسٌ من الدفتر داخل المعاملة', () {
    test('⛔ ERR_STOCK_001: بيعٌ يتجاوز المتاح يُرفَض', () {
      expect(
        rejection(
          planCashSale(
            request(
              sale: payload(
                lines: <CashSaleLineInput>[pieceLine(quantity: 200)],
              ),
              ledger: <String, List<LedgerRead>>{
                itemA: <LedgerRead>[movement('seed-a', 100)],
              },
            ),
            CashSaleOperation.createCashSale,
          ),
        ),
        CallableError.insufficientStock,
      );
    });

    test('★ والرصيد يُجمَع لا يُراكَم — نفس الطلب يُنتج نفس الرقم', () {
      final Map<String, Object?> first = writeFor(
        accepted(
          planCashSale(
            request(sale: payload()),
            CashSaleOperation.createCashSale,
          ),
        ),
        itemDailyBalancesCollection,
      );
      final Map<String, Object?> second = writeFor(
        accepted(
          planCashSale(
            request(sale: payload()),
            CashSaleOperation.createCashSale,
          ),
        ),
        itemDailyBalancesCollection,
      );
      expect(first['balance'], second['balance']);
      expect(first['balance'], 920);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // ★★★ الحركة المخزنية — خروجٌ دائماً بوسم المستند الصحيح
  // ═══════════════════════════════════════════════════════════════════════
  group('★★★ الحركة — خروجٌ بوسم `cashSale`', () {
    test('⛔⛔★★ و`sourceDocType` يُمرَّر صراحةً — درسُ الوسم المحفور', () {
      final Map<String, Object?> movementFields = writeFor(
        accepted(
          planCashSale(
            request(sale: payload()),
            CashSaleOperation.createCashSale,
          ),
        ),
        inventoryLedgerCollection,
      );
      expect(movementFields['sourceDocType'], 'cashSale');
      expect(movementFields['direction'], 'outgoing');
      expect(movementFields['sourceDocNumber'], docNumber);
      expect(movementFields['isCancelled'], false);
    });

    test('★★ و`sackId` يعبر — FR-M11-09: قيمةُ البيع تدخل سعر الجونية', () {
      final Map<String, Object?> movementFields = writeFor(
        accepted(
          planCashSale(
            request(
              sale: payload(
                lines: <CashSaleLineInput>[
                  weightLine(sackId: 'SCK-20260901-0001'),
                ],
              ),
              items: <String, ItemRead>{
                itemScrap: item(itemId: itemScrap, unit: ItemUnit.kilogram),
              },
              ledger: <String, List<LedgerRead>>{
                itemScrap: <LedgerRead>[scrapStock()],
              },
            ),
            CashSaleOperation.createCashSale,
          ),
        ),
        inventoryLedgerCollection,
      );
      expect(movementFields['sackId'], 'SCK-20260901-0001');
    });

    test('★★ والوزن يمرّ بـ DecimalValue — ⛔ لا double مجرَّد (DEBT-41)', () {
      final Map<String, Object?> movementFields = writeFor(
        accepted(
          planCashSale(
            request(
              sale: payload(
                lines: <CashSaleLineInput>[weightLine()],
              ),
              items: <String, ItemRead>{
                itemScrap: item(itemId: itemScrap, unit: ItemUnit.kilogram),
              },
              ledger: <String, List<LedgerRead>>{
                itemScrap: <LedgerRead>[scrapStock()],
              },
            ),
            CashSaleOperation.createCashSale,
          ),
        ),
        inventoryLedgerCollection,
      );
      expect(movementFields['quantity'], isA<DecimalValue>());
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // ★★ المستند — الحقول والإجماليات وصافي المقبوض
  // ═══════════════════════════════════════════════════════════════════════
  group('★★ المستند — design-overview.md §2.6', () {
    test('★★ صافي المقبوض من طبقة النطاق — ⛔ لا حساب هنا', () {
      final Map<String, Object?> document = writeFor(
        accepted(
          planCashSale(
            request(
              sale: payload(
                lines: <CashSaleLineInput>[
                  // 80 × 1,500 = 120,000
                  pieceLine(),
                  // 0.700 × 3,500 = 2,450
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
            CashSaleOperation.createCashSale,
          ),
        ),
        cashSalesCollection,
      );
      expect(document['netCashReceived'], 122450);
      // ⛔ **والإجماليان منفصلان دائماً** — `GR-19`.
      expect(document['totalPieces'], 80);
      expect(document['totalWeight'], isA<DecimalValue>());
    });

    test('★★★ والسعرُ في السطر نفسِه — ⛔ ولا مستندَ أسعارٍ فرعي', () {
      final CashSaleAccepted plan = accepted(
        planCashSale(
          request(sale: payload()),
          CashSaleOperation.createCashSale,
        ),
      );
      final Map<String, Object?> document =
          writeFor(plan, cashSalesCollection);
      final List<Object?> lines = document['lines']! as List<Object?>;
      final Map<String, Object?> line = lines.single as Map<String, Object?>;
      expect(line['unitPrice'], 1500);
      expect(line['lineTotal'], 120000);
      // ⛔ **ولا مجموعةَ `pricing` فرعية** — `ت-12` قاعدةُ التوزيع وحده.
      expect(
        plan.writes.any(
          (InventoryWrite w) => w.collectionId.contains('pricing'),
        ),
        isFalse,
      );
    });

    test('★ ومعرّفُ المستند رقمُه — ⛔ ولا معرّفَ مركّب', () {
      final CashSaleAccepted plan = accepted(
        planCashSale(
          request(sale: payload()),
          CashSaleOperation.createCashSale,
        ),
      );
      expect(
        plan.writes
            .firstWhere(
              (InventoryWrite w) => w.collectionId == cashSalesCollection,
            )
            .documentId,
        docNumber,
      );
    });

    test('★ وتاريخ المخزون من الطلب لا من الحمولة — A-10 · GR-14', () {
      final Map<String, Object?> document = writeFor(
        accepted(
          planCashSale(
            request(sale: payload()),
            CashSaleOperation.createCashSale,
          ),
        ),
        cashSalesCollection,
      );
      expect(document['stockDate'], day.asUtcMidnight());
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // ★★ الأنواع والمصدر
  // ═══════════════════════════════════════════════════════════════════════
  group('★★ الأنواع والمصدر — بواباتٌ لا تُخفَّف', () {
    test('⛔ FR-M5-10: نوعٌ لا ينتمي للمصدر يُرفَض — والواجهة تُخفي فقط', () {
      expect(
        rejection(
          planCashSale(
            request(
              sale: payload(),
              items: <String, ItemRead>{
                itemA: item(sourceIds: const <String>[sourceB]),
              },
            ),
            CashSaleOperation.createCashSale,
          ),
        ),
        CallableError.invalidArgument,
      );
    });

    test('⛔ ونوعٌ معطَّل يُرفَض', () {
      expect(
        rejection(
          planCashSale(
            request(
              sale: payload(),
              items: <String, ItemRead>{itemA: item(isActive: false)},
            ),
            CashSaleOperation.createCashSale,
          ),
        ),
        CallableError.invalidArgument,
      );
    });

    test('⛔ ERR_DIST_003: ومصدرٌ معطَّل يمنع البيع الجديد', () {
      expect(
        rejection(
          planCashSale(
            request(
              sale: payload(),
              storedSource: const <String, Object?>{'isActive': false},
            ),
            CashSaleOperation.createCashSale,
          ),
        ),
        CallableError.sourceInactive,
      );
    });

    test('⛔ ومصدرٌ لم يُقرأ ⟵ رفضٌ افتراضي لا تجاوز', () {
      expect(
        rejection(
          planCashSale(
            request(sale: payload(), storedSource: null),
            CashSaleOperation.createCashSale,
          ),
        ),
        CallableError.internal,
      );
    });

    test('✅ والإلغاء يمرّ على مصدرٍ عُطِّل — فلا يُحبَس سندٌ خاطئ', () {
      expect(
        planCashSale(
          request(
            storedSource: const <String, Object?>{'isActive': false},
            storedDocument: stored(),
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
          CashSaleOperation.cancelCashSale,
        ),
        isA<CashSaleAccepted>(),
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // ★★ الوجود والحالة
  // ═══════════════════════════════════════════════════════════════════════
  group('★★ الوجود والحالة', () {
    test('⛔ تعديلُ مستندٍ غائب يُرفَض', () {
      expect(
        rejection(
          planCashSale(
            request(sale: payload(), storedDocument: null),
            CashSaleOperation.amendCashSale,
          ),
        ),
        CallableError.invalidArgument,
      );
    });

    test('⛔⛔ والمخزَّن هو الحَكَم — سندُ مصدرٍ آخر يُرفَض بـ GR-23', () {
      expect(
        rejection(
          planCashSale(
            request(
              sale: payload(),
              storedDocument: stored(sourceId: sourceB),
            ),
            CashSaleOperation.amendCashSale,
          ),
        ),
        CallableError.sourceOutOfScope,
      );
    });

    test('⛔ ERR_AMEND_006: والملغى لا يُعدَّل', () {
      expect(
        rejection(
          planCashSale(
            request(
              sale: payload(),
              storedDocument: stored(status: 'cancelled'),
            ),
            CashSaleOperation.amendCashSale,
          ),
        ),
        CallableError.documentCancelled,
      );
    });

    test('⛔ ولا يُلغى الملغى ثانيةً', () {
      expect(
        rejection(
          planCashSale(
            request(storedDocument: stored(status: 'cancelled')),
            CashSaleOperation.cancelCashSale,
          ),
        ),
        CallableError.documentCancelled,
      );
    });

    test('⛔ وإنشاءٌ فوق رقمٍ قائم يُرفَض تصادماً — ⛔ ولا يمحو سنداً حيّاً', () {
      expect(
        rejection(
          planCashSale(
            request(sale: payload(), storedDocument: stored()),
            CashSaleOperation.createCashSale,
          ),
        ),
        CallableError.concurrency,
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // ★★ الإلغاء — بالوسم لا بالحذف (GR-06 · GR-07)
  // ═══════════════════════════════════════════════════════════════════════
  group('★★ الإلغاء — وسمٌ لا حذف', () {
    CashSaleAccepted cancelled() => accepted(
          planCashSale(
            request(
              storedDocument: stored(),
              reason: 'أُلغيت الصفقة',
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
            CashSaleOperation.cancelCashSale,
          ),
        );

    test('★ يَسِم السند «ملغى» بقناعٍ ضيّق — ⛔ فلا يمحو سطوره', () {
      final CashSaleAccepted plan = cancelled();
      final InventoryWrite document = plan.writes.firstWhere(
        (InventoryWrite w) => w.collectionId == cashSalesCollection,
      );
      expect(document.fields['status'], 'cancelled');
      expect(document.updateMask, isNot(contains('lines')));
      expect(document.updateMask, isNot(contains('stockDate')));
    });

    test('★★ وتعود الكمية إلى الرصيد — الحركة تُوسَم ملغاة', () {
      final CashSaleAccepted plan = cancelled();
      expect(
        writeFor(plan, inventoryLedgerCollection)['isCancelled'],
        isTrue,
      );
      expect(writeFor(plan, itemDailyBalancesCollection)['balance'], 0);
    });

    test('★ والفعل «إلغاء» في السجل لا «تعديل»', () {
      expect(cancelled().entry.action, AuditAction.cancel);
    });

    test('★★ ADR-0020: ويمرّ الإلغاء بلا سبب — ⛔ ولا رفضَ لغيابه', () {
      expect(
        planCashSale(
          request(
            storedDocument: stored(),
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
          CashSaleOperation.cancelCashSale,
        ),
        isA<CashSaleAccepted>(),
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // ★★ قيد التدقيق
  // ═══════════════════════════════════════════════════════════════════════
  group('★★ قيد التدقيق — في المعاملة نفسها', () {
    test('★ يحمل نوع الكيان ورقمَ السند ومصدرَه', () {
      final AuditEntry entry = accepted(
        planCashSale(
          request(sale: payload()),
          CashSaleOperation.createCashSale,
        ),
      ).entry;
      expect(entry.target.entityType, cashSaleEntityType);
      expect(entry.target.entityId, docNumber);
      expect(entry.target.sourceId, sourceA);
      expect(entry.action, AuditAction.create);
      expect(entry.id, 'req-1');
    });

    test('★★ والتعديل يُسجِّل المتغيّر وحده — ⛔ لا المستند كلَّه', () {
      final AuditEntry entry = accepted(
        planCashSale(
          request(
            sale: payload(
              lines: <CashSaleLineInput>[pieceLine(quantity: 40)],
            ),
            storedDocument: stored(),
            reason: 'تصحيح كمية',
          ),
          CashSaleOperation.amendCashSale,
        ),
      ).entry;
      expect(entry.action, AuditAction.amend);
      expect(entry.reason, 'تصحيح كمية');
      // ★ **والمصدرُ لم يتغيّر فلا يظهر في «بعد»** — ⟵ **فالسجل يُقرأ.**
      expect(entry.valuesAfter.containsKey('sourceId'), isFalse);
      expect(entry.valuesAfter.containsKey('lines'), isTrue);
    });

    test('⛔⛔ ADR-0020: ولا يُعبَّأ سببٌ نيابةً عن المستخدم', () {
      final AuditEntry entry = accepted(
        planCashSale(
          request(
            sale: payload(
              lines: <CashSaleLineInput>[pieceLine(quantity: 40)],
            ),
            storedDocument: stored(),
            reason: '   ',
          ),
          CashSaleOperation.amendCashSale,
        ),
      ).entry;
      expect(entry.reason, isNull);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // ★ قابلية التكرار بلا أثر جانبي — coding-standards §2.7
  // ═══════════════════════════════════════════════════════════════════════
  group('★ قابلية التكرار', () {
    test('★ نفس الطلب يُنتج نفس الخطة حرفياً', () {
      final CashSaleAccepted first = accepted(
        planCashSale(
          request(sale: payload()),
          CashSaleOperation.createCashSale,
        ),
      );
      final CashSaleAccepted second = accepted(
        planCashSale(
          request(sale: payload()),
          CashSaleOperation.createCashSale,
        ),
      );
      expect(
        first.writes.map((InventoryWrite w) => w.documentId).toList(),
        second.writes.map((InventoryWrite w) => w.documentId).toList(),
      );
      expect(
        writeFor(first, cashSalesCollection)['netCashReceived'],
        writeFor(second, cashSalesCollection)['netCashReceived'],
      );
    });
  });
}

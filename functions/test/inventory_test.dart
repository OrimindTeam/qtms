/// المخزون — ★★ **حارس التفويض والنطاق والرصيد معاً** (`WU-003`).
///
/// ⚠️⚠️ **ولماذا تُختبَر بهذه الصرامة:** بعد إغلاق الكتابة المباشرة
/// (`ADR-0013` القاعدة 2) **لم يبقَ بين المستخدم والدفتر إلا هذا الكود** —
/// ⟵ **فكل شرطٍ كانت تفرضه `firestore.rules` صار بند قبولٍ هنا**
/// (`DEBT-21` ①): الصلاحية · **نطاق المصادر** · تاريخ المخزون · وقت الخادم ·
/// السبب النصي · **ومنع الرصيد السالب** · ومنع الحذف.
library;

import 'package:qtms_domain/qtms_domain.dart';
import 'package:qtms_functions/src/callable.dart';
import 'package:qtms_functions/src/identity_claims.dart';
import 'package:qtms_functions/src/identity_gateway.dart';
import 'package:qtms_functions/src/inventory.dart';
import 'package:test/test.dart';

const String actorUid = 'uid-keeper';
const String sourceA = 'SRC-001';
const String sourceB = 'SRC-002';
const String itemA = 'ITM-0001';
const String docNumber = 'INC-20260825-0001';

final CalendarDay day = CalendarDay(2026, 8, 25);

AccountRecord account({
  Set<Permission> permissions = const <Permission>{
    Permission.incomingCountWrite,
    Permission.incomingCountAmend,
    Permission.incomingCountCancel,
  },
  SourceScope scope = const AllSources(),
  bool disabled = false,
}) =>
    AccountRecord(
      userId: actorUid,
      userName: 'أمين المخزن',
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

ValidatedCountedIntake intake({
  String sourceId = sourceA,
  Map<String, int> quantities = const <String, int>{itemA: 120},
  String? supplierId,
  bool requiresSupplier = false,
}) =>
    (validateCountedIntake(
      CountedIntakeInput(
        sourceId: sourceId,
        sourceRequiresSupplier: requiresSupplier,
        supplierId: supplierId,
        lines: <CountedIntakeLineInput>[
          for (final MapEntry<String, int> e in quantities.entries)
            CountedIntakeLineInput(
              itemId: e.key,
              itemName: 'عوارض',
              unit: ItemUnit.piece,
              quantity: e.value,
            ),
        ],
      ),
    ) as Success<ValidatedCountedIntake>)
        .value;

LedgerRead movement(
  String movementId,
  int quantity, {
  MovementDirection direction = MovementDirection.incoming,
  bool cancelled = false,
}) =>
    LedgerRead(
      movementId: movementId,
      movement: StockMovement(
        itemKey: itemA,
        direction: direction,
        quantity: PieceQuantity(PieceCount(quantity)),
        isCancelled: cancelled,
      ),
    );

InventoryRequest request({
  AccountRecord? actor,
  ValidatedCountedIntake? payload,
  Map<String, Object?>? storedSource = const <String, Object?>{
    'isActive': true,
    'requiresSupplierOnIntake': false,
  },
  Map<String, Object?>? storedDocument,
  Map<String, ItemRead>? items,
  Map<String, List<LedgerRead>> ledger = const <String, List<LedgerRead>>{},
  List<String>? supplierSourceIds,
  String? supplierName,
  String? reason,
  String sourceId = sourceA,
  String number = docNumber,
  CalendarDay? stockDate,
}) =>
    InventoryRequest(
      actor: actor ?? account(),
      requestId: 'req-1',
      sourceId: sourceId,
      documentNumber: number,
      stockDate: stockDate ?? day,
      intake: payload,
      storedSource: storedSource,
      storedDocument: storedDocument,
      items: items ?? <String, ItemRead>{itemA: item()},
      ledger: ledger,
      storedSupplierSourceIds: supplierSourceIds,
      storedSupplierName: supplierName,
      reason: reason,
    );

/// المستند المخزَّن كما تقرؤه المعاملة — ★ **بمصدره وتاريخ مخزونه**.
Map<String, Object?> stored({
  String status = 'approved',
  String sourceId = sourceA,
  CalendarDay? stockDate,
  Map<String, int> lines = const <String, int>{itemA: 120},
}) =>
    <String, Object?>{
      'documentNumber': docNumber,
      'sourceId': sourceId,
      'stockDate': (stockDate ?? day).asUtcMidnight(),
      'status': status,
      'lines': <Object?>[
        for (final MapEntry<String, int> e in lines.entries)
          <String, Object?>{'itemKey': e.key, 'quantity': e.value},
      ],
    };

InventoryWrite writeIn(InventoryAccepted plan, String collection) =>
    plan.writes.firstWhere(
      (InventoryWrite w) => w.collectionId == collection,
    );

void main() {
  // ═══════════════════════════════════════════════════════════════════════
  group('البوابة — الصلاحية والنطاق والحالة', () {
    test('★ يرفض حساباً معطَّلاً — ERR_AUTH_004', () {
      final InventoryPlan plan = planInventory(
        request(actor: account(disabled: true), payload: intake()),
        InventoryOperation.createCountedIntake,
      );
      expect(
        (plan as InventoryRejected).error.code,
        CallableError.accountDisabled.code,
      );
    });

    test('★ يرفض من لا يملك incomingCountWrite — ERR_AUTH_001', () {
      final InventoryPlan plan = planInventory(
        request(
          actor: account(permissions: const <Permission>{}),
          payload: intake(),
        ),
        InventoryOperation.createCountedIntake,
      );
      expect(
        (plan as InventoryRejected).error.code,
        CallableError.permissionMissing.code,
      );
    });

    test('★★ GR-23: يرفض مصدراً خارج النطاق ولو ملك الصلاحية — ERR_AUTH_002', () {
      final InventoryPlan plan = planInventory(
        request(
          actor: account(scope: ScopedSources(const <String>{sourceB})),
          payload: intake(),
        ),
        InventoryOperation.createCountedIntake,
      );
      expect(
        (plan as InventoryRejected).error.code,
        CallableError.sourceOutOfScope.code,
      );
    });

    test('★ ولا نطاق إطلاقاً ⟵ منع لا سماح', () {
      final InventoryPlan plan = planInventory(
        request(
          actor: AccountRecord(
            userId: actorUid,
            userName: 'بلا نطاق',
            claims: IdentityClaims(
              permissions: const <Permission>{Permission.incomingCountWrite},
              sourceScope: null,
            ),
            disabled: false,
          ),
          payload: intake(),
        ),
        InventoryOperation.createCountedIntake,
      );
      expect(
        (plan as InventoryRejected).error.code,
        CallableError.sourceOutOfScope.code,
      );
    });

    test('⛔ مصدرٌ لم يُقرأ ⟵ رفضٌ داخلي لا تجاوز', () {
      final InventoryPlan plan = planInventory(
        request(payload: intake(), storedSource: null),
        InventoryOperation.createCountedIntake,
      );
      expect(
        (plan as InventoryRejected).error.code,
        CallableError.internal.code,
      );
    });

    test('★ ERR_DIST_003: يرفض التوريد من مصدر معطَّل', () {
      final InventoryPlan plan = planInventory(
        request(
          payload: intake(),
          storedSource: const <String, Object?>{'isActive': false},
        ),
        InventoryOperation.createCountedIntake,
      );
      expect(
        (plan as InventoryRejected).error.code,
        CallableError.sourceInactive.code,
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('الإنشاء — FR-M6-01 … FR-M6-10', () {
    test('★★ يكتب المستند والحركة والرصيد وقيد التدقيق معاً', () {
      final InventoryAccepted plan = planInventory(
        request(payload: intake()),
        InventoryOperation.createCountedIntake,
      ) as InventoryAccepted;

      expect(plan.documentNumber, docNumber);
      expect(
        plan.writes.map((InventoryWrite w) => w.collectionId).toSet(),
        <String>{
          incomingCountCollection,
          inventoryLedgerCollection,
          itemDailyBalancesCollection,
        },
      );
      expect(plan.entry.action, AuditAction.create);
      expect(plan.entry.target.sourceId, sourceA);
      expect(plan.entry.target.entityId, docNumber);
    });

    test('★★ FR-M6-02: تاريخ المخزون في المستند والحركة والرصيد واحد', () {
      final InventoryAccepted plan = planInventory(
        request(payload: intake()),
        InventoryOperation.createCountedIntake,
      ) as InventoryAccepted;

      final DateTime expected = day.asUtcMidnight();
      for (final InventoryWrite write in plan.writes) {
        expect(write.fields['stockDate'], expected, reason: write.collectionId);
      }
    });

    test('★★ ⛅ وقت الخادم لا ساعة الحاوية — createdAt · entryDate', () {
      final InventoryAccepted plan = planInventory(
        request(payload: intake()),
        InventoryOperation.createCountedIntake,
      ) as InventoryAccepted;

      expect(
        writeIn(plan, incomingCountCollection).serverTimestampFields,
        <String>['createdAt', 'entryDate'],
      );
      expect(
        writeIn(plan, inventoryLedgerCollection).serverTimestampFields,
        <String>['entryDate'],
      );
      // ⛔ ولا يدخل حقلُ وقتٍ خادمي في الحقول ولا في القناع.
      for (final InventoryWrite write in plan.writes) {
        for (final String stamp in write.serverTimestampFields) {
          expect(write.fields.containsKey(stamp), isFalse);
          expect(write.updateMask.contains(stamp), isFalse);
        }
      }
    });

    test('★★ AT-05: الرصيد يقع في مخزن المصدر المحدد وحده', () {
      final InventoryAccepted plan = planInventory(
        request(payload: intake()),
        InventoryOperation.createCountedIntake,
      ) as InventoryAccepted;

      final InventoryWrite balance = writeIn(plan, itemDailyBalancesCollection);
      expect(
        balance.documentId,
        itemDailyBalanceId(sourceId: sourceA, itemKey: itemA, stockDate: day),
      );
      expect(balance.fields['sourceId'], sourceA);
      expect(balance.fields['balance'], 120);
      expect(balance.fields['incoming'], 120);
      expect(balance.fields['outgoing'], 0);
    });

    test('★★ الرصيد يُجمَع من الدفتر لا يُراكَم — §2.7', () {
      // 40 دخلت سابقاً و10 خرجت ⟵ الرصيد بعد 120 جديدة = 150.
      final InventoryAccepted plan = planInventory(
        request(
          payload: intake(),
          ledger: <String, List<LedgerRead>>{
            itemA: <LedgerRead>[
              movement('SCK-x_ITM-0001', 40),
              movement(
                'DST-x_ITM-0001',
                10,
                direction: MovementDirection.outgoing,
              ),
            ],
          },
        ),
        InventoryOperation.createCountedIntake,
      ) as InventoryAccepted;

      final InventoryWrite balance = writeIn(plan, itemDailyBalancesCollection);
      expect(balance.fields['balance'], 150);
      expect(balance.fields['incoming'], 160);
      expect(balance.fields['outgoing'], 10);
      expect(
        writeIn(plan, inventoryLedgerCollection).fields['balanceAfter'],
        150,
      );
    });

    test('★ A-14: الحركة الملغاة لا تدخل الرصيد', () {
      final InventoryAccepted plan = planInventory(
        request(
          payload: intake(),
          ledger: <String, List<LedgerRead>>{
            itemA: <LedgerRead>[movement('OLD_ITM-0001', 500, cancelled: true)],
          },
        ),
        InventoryOperation.createCountedIntake,
      ) as InventoryAccepted;
      expect(
        writeIn(plan, itemDailyBalancesCollection).fields['balance'],
        120,
      );
    });

    test('★★ FR-M6-09: لا sackId في الحركة ⟵ فلا تدخل سعر أي جونية', () {
      final InventoryAccepted plan = planInventory(
        request(payload: intake()),
        InventoryOperation.createCountedIntake,
      ) as InventoryAccepted;
      final InventoryWrite ledger = writeIn(plan, inventoryLedgerCollection);
      expect(ledger.fields.containsKey('sackId'), isFalse);
      expect(ledger.fields['itemKey'], itemA);
      expect(ledger.fields['movementTag'], MovementTag.normal.name);
      expect(ledger.fields['sourceDocType'], 'countedIntake');
    });

    test('★★ FR-M6-10: لا حقل وزن ولا ضريبة ولا سعر في المستند', () {
      final InventoryAccepted plan = planInventory(
        request(payload: intake()),
        InventoryOperation.createCountedIntake,
      ) as InventoryAccepted;
      final Set<String> keys =
          writeIn(plan, incomingCountCollection).fields.keys.toSet();
      for (final String forbidden in <String>[
        'weight',
        'totalWeight',
        'taxPerKilo',
        'price',
        'sackTax',
      ]) {
        expect(keys.contains(forbidden), isFalse, reason: forbidden);
      }
    });

    test('★ الأسماء المكرَّرة عمداً تُنسَخ في المستند — naming-conventions §4', () {
      final InventoryAccepted plan = planInventory(
        request(
          payload: intake(supplierId: 'SUP-0001', requiresSupplier: true),
          storedSource: const <String, Object?>{
            'isActive': true,
            'requiresSupplierOnIntake': true,
            'name': 'رداع',
          },
          supplierSourceIds: const <String>[sourceA],
          supplierName: 'رعوي مثال',
        ),
        InventoryOperation.createCountedIntake,
      ) as InventoryAccepted;

      final Map<String, Object?> fields =
          writeIn(plan, incomingCountCollection).fields;
      expect(fields['sourceName'], 'رداع');
      expect(fields['supplierName'], 'رعوي مثال');
      // ★ **وسطور المستند بحقول القاموس حرفياً** — ⛔ ولا حقل زائد.
      final Map<String, Object?> line =
          (fields['lines']! as List<Object?>).single! as Map<String, Object?>;
      expect(
        line.keys.toSet(),
        <String>{'itemId', 'itemName', 'unit', 'quantity'},
      );
    });

    test('⛔ ولا اسم رعوي يُكتب لمستندٍ بلا رعوي', () {
      final InventoryAccepted plan = planInventory(
        request(payload: intake()),
        InventoryOperation.createCountedIntake,
      ) as InventoryAccepted;
      expect(
        writeIn(plan, incomingCountCollection).fields.containsKey('supplierName'),
        isFalse,
      );
    });

    test('★★ FR-M6-05 · BR-M6-04: يرفض نوعاً غير مرتبط بالمصدر', () {
      final InventoryPlan plan = planInventory(
        request(
          payload: intake(),
          items: <String, ItemRead>{
            itemA: item(sourceIds: const <String>[sourceB]),
          },
        ),
        InventoryOperation.createCountedIntake,
      );
      expect(plan, isA<InventoryRejected>());
    });

    test('★ يرفض نوعاً معطَّلاً', () {
      final InventoryPlan plan = planInventory(
        request(
          payload: intake(),
          items: <String, ItemRead>{itemA: item(isActive: false)},
        ),
        InventoryOperation.createCountedIntake,
      );
      expect(plan, isA<InventoryRejected>());
    });

    test('★★ ERR_SETUP_009: يرفض نوعاً وحدتُه كيلوجرام — لا وزن هنا', () {
      final InventoryPlan plan = planInventory(
        request(
          payload: intake(),
          items: <String, ItemRead>{
            itemA: item(unit: ItemUnit.kilogram),
          },
        ),
        InventoryOperation.createCountedIntake,
      );
      expect(
        (plan as InventoryRejected).error.code,
        CallableError.itemUnitLocked.code,
      );
    });

    test('⛔ إنشاءٌ فوق مستندٍ قائم مرفوض', () {
      final InventoryPlan plan = planInventory(
        request(payload: intake(), storedDocument: stored()),
        InventoryOperation.createCountedIntake,
      );
      expect(plan, isA<InventoryRejected>());
    });

    test('★★ FR-M6-03: الرعوي المُرسَل يجب أن ينتمي للمصدر — ERR_INTAKE_001', () {
      final InventoryPlan plan = planInventory(
        request(
          payload: intake(supplierId: 'SUP-0001', requiresSupplier: true),
          supplierSourceIds: const <String>[sourceB],
        ),
        InventoryOperation.createCountedIntake,
      );
      expect(
        (plan as InventoryRejected).error.code,
        CallableError.supplierRequired.code,
      );
    });

    test('★ ويُخزَّن الرعوي إن انتمى للمصدر', () {
      final InventoryAccepted plan = planInventory(
        request(
          payload: intake(supplierId: 'SUP-0001', requiresSupplier: true),
          supplierSourceIds: const <String>[sourceA],
        ),
        InventoryOperation.createCountedIntake,
      ) as InventoryAccepted;
      expect(
        writeIn(plan, incomingCountCollection).fields['supplierId'],
        'SUP-0001',
      );
    });

    test('⛔ ومستندٌ بلا رعوي لا يحمل المفتاح أصلاً — لا قيمةً فارغة', () {
      final InventoryAccepted plan = planInventory(
        request(payload: intake()),
        InventoryOperation.createCountedIntake,
      ) as InventoryAccepted;
      expect(
        writeIn(plan, incomingCountCollection).fields.containsKey('supplierId'),
        isFalse,
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('التعديل — FR-M6-11 · FR-M6-12', () {
    // ⛔⛔★★★ **ارتدادُ `ADR-0020`:** ★ **كان يُرفَض بـ`ERR_AMEND_002`.**
    test('✅★★ ADR-0020: يقبل التعديل بلا سببٍ نصّي — ⛔ والقيد بلا نصّ مخترَع',
        () {
      final InventoryAccepted plan = planInventory(
        request(payload: intake(), storedDocument: stored()),
        InventoryOperation.amendCountedIntake,
      ) as InventoryAccepted;
      expect(plan.entry.reason, isNull);
    });

    test('✅★ والفراغات تمرّ وتُقرأ غياباً — ⛔ لا نصّاً فارغاً', () {
      final InventoryAccepted plan = planInventory(
        request(payload: intake(), storedDocument: stored(), reason: '   '),
        InventoryOperation.amendCountedIntake,
      ) as InventoryAccepted;
      expect(plan.entry.reason, isNull);
    });

    test('★★ A-14: يُعدِّل الحركة نفسها ⛔ ولا يُنشئ حركة تصحيحية', () {
      final InventoryAccepted plan = planInventory(
        request(
          payload: intake(quantities: const <String, int>{itemA: 80}),
          storedDocument: stored(),
          reason: 'خطأ عدّ',
          ledger: <String, List<LedgerRead>>{
            itemA: <LedgerRead>[movement('${docNumber}_$itemA', 120)],
          },
        ),
        InventoryOperation.amendCountedIntake,
      ) as InventoryAccepted;

      final List<InventoryWrite> ledgerWrites = plan.writes
          .where((InventoryWrite w) => w.collectionId == inventoryLedgerCollection)
          .toList();
      expect(ledgerWrites.length, 1);
      expect(ledgerWrites.single.documentId, '${docNumber}_$itemA');
      expect(ledgerWrites.single.fields['quantity'], 80);
      expect(ledgerWrites.single.fields['isCancelled'], isFalse);
      expect(
        writeIn(plan, itemDailyBalancesCollection).fields['balance'],
        80,
      );
      expect(plan.entry.action, AuditAction.amend);
      expect(plan.entry.reason, 'خطأ عدّ');
    });

    test('★★★ FR-M6-12 · ERR_AMEND_003: يرفض تخفيضاً لكمية صُرفت', () {
      // 120 دخلت و100 صُرفت ⟵ تخفيضها إلى 80 يُنتج −20.
      final InventoryPlan plan = planInventory(
        request(
          payload: intake(quantities: const <String, int>{itemA: 80}),
          storedDocument: stored(),
          reason: 'تصحيح',
          ledger: <String, List<LedgerRead>>{
            itemA: <LedgerRead>[
              movement('${docNumber}_$itemA', 120),
              movement(
                'DST-1_ITM-0001',
                100,
                direction: MovementDirection.outgoing,
              ),
            ],
          },
        ),
        InventoryOperation.amendCountedIntake,
      );
      expect(
        (plan as InventoryRejected).error.code,
        CallableError.amendReducesBelowIssued.code,
      );
    });

    test('★ ويقبل تخفيضاً يُبقي الرصيد صفراً', () {
      final InventoryPlan plan = planInventory(
        request(
          payload: intake(quantities: const <String, int>{itemA: 100}),
          storedDocument: stored(),
          reason: 'تصحيح',
          ledger: <String, List<LedgerRead>>{
            itemA: <LedgerRead>[
              movement('${docNumber}_$itemA', 120),
              movement(
                'DST-1_ITM-0001',
                100,
                direction: MovementDirection.outgoing,
              ),
            ],
          },
        ),
        InventoryOperation.amendCountedIntake,
      );
      expect(plan, isA<InventoryAccepted>());
    });

    test('★★ سطرٌ حُذف من التعديل يُوسَم ملغى ⛔ ولا يُحذف', () {
      final InventoryAccepted plan = planInventory(
        request(
          payload: intake(quantities: const <String, int>{itemA: 50}),
          storedDocument: stored(lines: const <String, int>{itemA: 50, 'ITM-0002': 10}),
          reason: 'حذف سطر',
          items: <String, ItemRead>{
            itemA: item(),
            'ITM-0002': item(itemId: 'ITM-0002'),
          },
          ledger: <String, List<LedgerRead>>{
            itemA: <LedgerRead>[movement('${docNumber}_$itemA', 50)],
            'ITM-0002': <LedgerRead>[
              LedgerRead(
                movementId: '${docNumber}_ITM-0002',
                movement: const StockMovement(
                  itemKey: 'ITM-0002',
                  direction: MovementDirection.incoming,
                  quantity: PieceQuantity(PieceCount(10)),
                  isCancelled: false,
                ),
              ),
            ],
          },
        ),
        InventoryOperation.amendCountedIntake,
      ) as InventoryAccepted;

      final InventoryWrite dropped = plan.writes.firstWhere(
        (InventoryWrite w) =>
            w.collectionId == inventoryLedgerCollection &&
            w.documentId == '${docNumber}_ITM-0002',
      );
      expect(dropped.fields['isCancelled'], isTrue);
      expect(dropped.fields['quantity'], 10);
    });

    test('★★★ يرفض التعديل على مستند مصدرٍ آخر — تصعيدُ امتيازٍ صامت', () {
      final InventoryPlan plan = planInventory(
        request(
          payload: intake(),
          storedDocument: stored(sourceId: sourceB),
          reason: 'محاولة',
        ),
        InventoryOperation.amendCountedIntake,
      );
      expect(
        (plan as InventoryRejected).error.code,
        CallableError.sourceOutOfScope.code,
      );
    });

    test('★★★ يرفض يوماً لا يطابق تاريخ المخزون المخزَّن — RISK-07', () {
      final InventoryPlan plan = planInventory(
        request(
          payload: intake(),
          storedDocument: stored(stockDate: CalendarDay(2026, 8, 24)),
          reason: 'محاولة',
        ),
        InventoryOperation.amendCountedIntake,
      );
      expect(plan, isA<InventoryRejected>());
    });

    test('⛔ تعديلُ ما لا يوجد مرفوض', () {
      final InventoryPlan plan = planInventory(
        request(payload: intake(), reason: 'سبب'),
        InventoryOperation.amendCountedIntake,
      );
      expect(plan, isA<InventoryRejected>());
    });

    test('★★ ERR_AMEND_006: لا يُعدَّل مستندٌ ملغى', () {
      final InventoryPlan plan = planInventory(
        request(
          payload: intake(),
          storedDocument: stored(status: 'cancelled'),
          reason: 'سبب',
        ),
        InventoryOperation.amendCountedIntake,
      );
      expect(
        (plan as InventoryRejected).error.code,
        CallableError.documentCancelled.code,
      );
    });

    test('★ ويُسجَّل القيد بالقيمة قبل وبعد للحقول المتغيّرة وحدها', () {
      final InventoryAccepted plan = planInventory(
        request(
          payload: intake(quantities: const <String, int>{itemA: 80}),
          storedDocument: stored(),
          reason: 'خطأ عدّ',
          ledger: <String, List<LedgerRead>>{
            itemA: <LedgerRead>[movement('${docNumber}_$itemA', 120)],
          },
        ),
        InventoryOperation.amendCountedIntake,
      ) as InventoryAccepted;

      expect(plan.entry.valuesAfter['totalQuantity'], 80);
      expect(plan.entry.valuesBefore.containsKey('totalQuantity'), isTrue);
      // ⛔ ولا يُنسَخ المستند كاملاً — `audit-log-design.md` §8.
      expect(plan.entry.valuesAfter.containsKey('documentNumber'), isFalse);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('الإلغاء — FR-M6-13 · GR-06', () {
    test('★★ يَسِم المستند وحركاته «ملغى» ⛔ ولا يحذف شيئاً', () {
      final InventoryAccepted plan = planInventory(
        request(
          storedDocument: stored(),
          reason: 'دفعة مكررة',
          ledger: <String, List<LedgerRead>>{
            itemA: <LedgerRead>[movement('${docNumber}_$itemA', 120)],
          },
        ),
        InventoryOperation.cancelCountedIntake,
      ) as InventoryAccepted;

      final InventoryWrite document = writeIn(plan, incomingCountCollection);
      expect(document.fields['status'], 'cancelled');
      expect(document.fields['cancelReason'], 'دفعة مكررة');
      // ★ قناعٌ ضيّق — ⛔ فلا يمحو الإلغاءُ سطوراً ولا تاريخ مخزون.
      expect(document.updateMask.contains('lines'), isFalse);
      expect(document.updateMask.contains('stockDate'), isFalse);

      final InventoryWrite ledger = writeIn(plan, inventoryLedgerCollection);
      expect(ledger.fields['isCancelled'], isTrue);
      expect(
        writeIn(plan, itemDailyBalancesCollection).fields['balance'],
        0,
      );
      expect(plan.entry.action, AuditAction.cancel);
    });

    test('★★★ FR-M6-13 · ERR_STOCK_001: يرفض إلغاء كميةٍ صُرفت', () {
      final InventoryPlan plan = planInventory(
        request(
          storedDocument: stored(),
          reason: 'إلغاء',
          ledger: <String, List<LedgerRead>>{
            itemA: <LedgerRead>[
              movement('${docNumber}_$itemA', 120),
              movement(
                'DST-1_ITM-0001',
                30,
                direction: MovementDirection.outgoing,
              ),
            ],
          },
        ),
        InventoryOperation.cancelCountedIntake,
      );
      expect(
        (plan as InventoryRejected).error.code,
        CallableError.insufficientStock.code,
      );
    });

    // ⛔⛔★★★ **ارتدادُ `ADR-0020`:** ★ **كان يُرفَض بـ`ERR_AMEND_004`.**
    test('✅★ ADR-0020: يقبل الإلغاء بلا سببٍ نصّي — والوسم يقع كما هو', () {
      final InventoryAccepted plan = planInventory(
        request(storedDocument: stored()),
        InventoryOperation.cancelCountedIntake,
      ) as InventoryAccepted;
      expect(plan.entry.reason, isNull);
      expect(plan.entry.action, AuditAction.cancel);
    });

    test('★ ويُسمَح الإلغاء على مصدرٍ عُطِّل — فلا يُحبَس مستندٌ خاطئ', () {
      final InventoryPlan plan = planInventory(
        request(
          storedDocument: stored(),
          reason: 'إلغاء',
          storedSource: const <String, Object?>{'isActive': false},
          ledger: <String, List<LedgerRead>>{
            itemA: <LedgerRead>[movement('${docNumber}_$itemA', 120)],
          },
        ),
        InventoryOperation.cancelCountedIntake,
      );
      expect(plan, isA<InventoryAccepted>());
    });

    test('★★ ERR_AMEND_006: ولا يُلغى الملغى ثانيةً', () {
      final InventoryPlan plan = planInventory(
        request(storedDocument: stored(status: 'cancelled'), reason: 'إلغاء'),
        InventoryOperation.cancelCountedIntake,
      );
      expect(
        (plan as InventoryRejected).error.code,
        CallableError.documentCancelled.code,
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('⛔ الحذف — FR-M6-14 · GR-07', () {
    test('★★ لا عملية حذف في الكتالوج أصلاً', () {
      expect(
        InventoryOperation.values
            .map((InventoryOperation o) => o.name)
            .any((String name) => name.toLowerCase().contains('delete')),
        isFalse,
      );
    });

    test('★★ ولا خطةٌ تحمل حذفاً — الكتابات وحدها', () {
      final InventoryAccepted plan = planInventory(
        request(
          storedDocument: stored(),
          reason: 'إلغاء',
          ledger: <String, List<LedgerRead>>{
            itemA: <LedgerRead>[movement('${docNumber}_$itemA', 120)],
          },
        ),
        InventoryOperation.cancelCountedIntake,
      ) as InventoryAccepted;
      expect(plan.writes, isNotEmpty);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('★★ الصلاحيات الثلاث مستقلة — permissions-catalog.md §2', () {
    test('التعديل لا يُغني عنه مفتاح الإنشاء', () {
      final InventoryPlan plan = planInventory(
        request(
          actor: account(
            permissions: const <Permission>{Permission.incomingCountWrite},
          ),
          payload: intake(),
          storedDocument: stored(),
          reason: 'سبب',
        ),
        InventoryOperation.amendCountedIntake,
      );
      expect(
        (plan as InventoryRejected).error.code,
        CallableError.permissionMissing.code,
      );
    });

    test('والإلغاء لا يُغني عنه مفتاح التعديل', () {
      final InventoryPlan plan = planInventory(
        request(
          actor: account(
            permissions: const <Permission>{Permission.incomingCountAmend},
          ),
          storedDocument: stored(),
          reason: 'سبب',
        ),
        InventoryOperation.cancelCountedIntake,
      );
      expect(
        (plan as InventoryRejected).error.code,
        CallableError.permissionMissing.code,
      );
    });
  });
}

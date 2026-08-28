/// التسعير اليومي — ★★ **حارس التفويض والنطاق والرصيد والسبب معاً** (`WU-005`).
///
/// ⚠️⚠️ **ولماذا تُختبَر بهذه الصرامة:** `daily_prices` **`allow create,
/// update: if false`** (`ADR-0013` القاعدة 2) — ⟵ **فلم يبقَ بين المستخدم
/// وسجل السعر إلا هذا الكود**، **وكل شرطٍ كانت تفرضه `firestore.rules`
/// صار بند قبولٍ هنا** (`DEBT-21` ①).
library;

import 'package:qtms_domain/qtms_domain.dart';
import 'package:qtms_functions/src/callable.dart';
import 'package:qtms_functions/src/daily_pricing.dart';
import 'package:qtms_functions/src/identity_claims.dart';
import 'package:qtms_functions/src/identity_gateway.dart';
import 'package:qtms_functions/src/inventory.dart';
import 'package:test/test.dart';

const String actorUid = 'uid-pricer';
const String sourceA = 'SRC-001';
const String sourceB = 'SRC-002';
const String itemA = 'ITM-0001';
const String scrapItem = 'ITM-0002';
const String requestId = 'req-price-1';

final CalendarDay day = CalendarDay(2026, 8, 25);

AccountRecord account({
  Set<Permission> permissions = const <Permission>{Permission.dailyPriceWrite},
  SourceScope scope = const AllSources(),
  bool disabled = false,
}) =>
    AccountRecord(
      userId: actorUid,
      userName: 'المسعِّر',
      claims: IdentityClaims(permissions: permissions, sourceScope: scope),
      disabled: disabled,
      cardIsActive: true,
    );

ItemRead item({
  String itemId = itemA,
  String name = 'عوارض',
  ItemUnit unit = ItemUnit.piece,
  bool isActive = true,
  List<String> sourceIds = const <String>[sourceA],
}) =>
    ItemRead(
      itemId: itemId,
      name: name,
      unit: unit,
      isActive: isActive,
      sourceIds: sourceIds,
    );

/// حركة دخولٍ حيّة — ★ **فيصير للنوع رصيدٌ اليوم** (`FR-M9-02`).
LedgerRead movement(
  String movementId, {
  String itemKey = itemA,
  StockQuantity quantity = const PieceQuantity(PieceCount(120)),
  MovementDirection direction = MovementDirection.incoming,
  bool cancelled = false,
}) =>
    LedgerRead(
      movementId: movementId,
      movement: StockMovement(
        itemKey: itemKey,
        direction: direction,
        quantity: quantity,
        isCancelled: cancelled,
      ),
    );

ValidatedDailyPriceBatch batch({
  String sourceId = sourceA,
  List<DailyPriceLineInput>? lines,
}) =>
    (validateDailyPrices(
      DailyPriceBatchInput(
        sourceId: sourceId,
        lines: lines ??
            <DailyPriceLineInput>[
              const DailyPriceLineInput(
                itemId: itemA,
                itemName: 'عوارض',
                unit: ItemUnit.piece,
                distributionPrice: Money(1200),
                minCashPrice: Money(1000),
              ),
            ],
      ),
    ) as Success<ValidatedDailyPriceBatch>)
        .value;

DailyPricingRequest request({
  AccountRecord? actor,
  String sourceId = sourceA,
  ValidatedDailyPriceBatch? priced,
  Map<String, Object?>? storedSource = const <String, Object?>{
    'name': 'رداع',
    'isActive': true,
  },
  Map<String, ItemRead>? items,
  Map<String, List<LedgerRead>>? ledger,
  Map<String, Map<String, Object?>?> storedPrices =
      const <String, Map<String, Object?>?>{},
  String? reason,
  String id = requestId,
}) =>
    DailyPricingRequest(
      actor: actor ?? account(),
      requestId: id,
      sourceId: sourceId,
      date: day,
      batch: priced ?? batch(sourceId: sourceId),
      storedSource: storedSource,
      items: items ?? <String, ItemRead>{itemA: item()},
      ledger: ledger ??
          <String, List<LedgerRead>>{
            itemA: <LedgerRead>[movement('mov-1')],
          },
      storedPrices: storedPrices,
      reason: reason,
    );

DailyPricingPlan plan(DailyPricingRequest r) =>
    planDailyPricing(r, DailyPricingOperation.writeDailyPrices);

CallableError errorOf(DailyPricingPlan p) =>
    (p as DailyPricingRejected).error;

DailyPricingAccepted acceptedOf(DailyPricingPlan p) =>
    p as DailyPricingAccepted;

void main() {
  group('البوابة — الصلاحية والنطاق والحالة (ADR-0013 القاعدة 3)', () {
    test('✅ يقبل بصلاحية dailyPriceWrite ونطاقٍ يشمل المصدر', () {
      expect(plan(request()), isA<DailyPricingAccepted>());
    });

    test('⛔ ERR_AUTH_001: بلا dailyPriceWrite يُرفَض', () {
      expect(
        errorOf(plan(request(actor: account(permissions: const <Permission>{})))),
        CallableError.permissionMissing,
      );
    });

    test('⛔★★ GR-23: النطاق قيدٌ يعلو على الصلاحية — مصدرٌ خارجه يُرفَض', () {
      expect(
        errorOf(
          plan(
            request(
              actor: account(scope: ScopedSources(<String>{sourceB})),
            ),
          ),
        ),
        CallableError.sourceOutOfScope,
      );
    });

    test('⛔ ERR_AUTH_004: التعطيل فوري ونافذ — يُرفَض قبل كل شيء', () {
      expect(
        errorOf(plan(request(actor: account(disabled: true)))),
        CallableError.accountDisabled,
      );
    });

    test('⛔ ومعرّف الطلب إلزامي — وبدونه لا لاتكرارية عند إعادة الإرسال', () {
      expect(
        errorOf(plan(request(id: '   '))),
        CallableError.invalidArgument,
      );
    });

    test('⛔ ومصدرُ الدفعة يجب أن يطابق المصدر المفحوص نطاقُه', () {
      expect(
        errorOf(plan(request(priced: batch(sourceId: sourceB)))),
        CallableError.invalidArgument,
      );
    });
  });

  group('المصدر — موجودٌ ونشط', () {
    test('⛔ مصدرٌ لم يُقرأ ⟵ رفضٌ افتراضي (internal)', () {
      expect(
        errorOf(plan(request(storedSource: null))),
        CallableError.internal,
      );
    });

    test('⛔ ERR_DIST_003: ولا يُسعَّر مصدرٌ عُطِّل — التسعير فعلٌ أماميّ', () {
      expect(
        errorOf(
          plan(
            request(
              storedSource: const <String, Object?>{
                'name': 'رداع',
                'isActive': false,
              },
            ),
          ),
        ),
        CallableError.sourceInactive,
      );
    });
  });

  group('النوع — قائمٌ ونشطٌ ومرتبطٌ بالمصدر ووحدتُه المخزَّنة', () {
    test('⛔ نوعٌ لم يُقرأ يُرفَض', () {
      expect(
        errorOf(plan(request(items: const <String, ItemRead>{}))),
        CallableError.invalidArgument,
      );
    });

    test('⛔ ونوعٌ معطَّل يُرفَض', () {
      expect(
        errorOf(
          plan(
            request(
              items: <String, ItemRead>{itemA: item(isActive: false)},
            ),
          ),
        ),
        CallableError.invalidArgument,
      );
    });

    test('⛔★ FR-M5-10: ونوعٌ لا ينتمي للمصدر يُرفَض — والواجهة تُخفي فقط', () {
      expect(
        errorOf(
          plan(
            request(
              items: <String, ItemRead>{
                itemA: item(sourceIds: const <String>[sourceB]),
              },
            ),
          ),
        ),
        CallableError.invalidArgument,
      );
    });

    test('⛔★★ ERR_SETUP_009: ووحدةٌ مُرسَلة تخالف المخزَّنة تُرفَض', () {
      // ★ الدفعة تحمل «حبة» بينما سجل النوع «كيلوجرام» — `FR-M9-06`.
      expect(
        errorOf(
          plan(
            request(
              items: <String, ItemRead>{
                itemA: item(unit: ItemUnit.kilogram),
              },
              ledger: <String, List<LedgerRead>>{
                itemA: <LedgerRead>[
                  movement(
                    'mov-1',
                    quantity: const WeightQuantity(WeightKg(12.5)),
                  ),
                ],
              },
            ),
          ),
        ),
        CallableError.itemUnitLocked,
      );
    });
  });

  group('★★★ FR-M9-02 · E-33 — لا يُسعَّر نوعٌ لا كمية له في مخزون اليوم', () {
    test('⛔ ERR_STOCK_001: دفترٌ فارغ ⟵ رصيدٌ صفر ⟵ رفض', () {
      expect(
        errorOf(
          plan(
            request(
              ledger: <String, List<LedgerRead>>{itemA: <LedgerRead>[]},
            ),
          ),
        ),
        CallableError.insufficientStock,
      );
    });

    test('⛔★★ وحركةٌ ملغاة لا تُنشئ رصيداً — A-14 حرفياً', () {
      expect(
        errorOf(
          plan(
            request(
              ledger: <String, List<LedgerRead>>{
                itemA: <LedgerRead>[movement('mov-1', cancelled: true)],
              },
            ),
          ),
        ),
        CallableError.insufficientStock,
      );
    });

    test('⛔★★ ونوعٌ ورد ثم صُرف بالكامل رصيدُه صفر — والصفر ليس كمية', () {
      expect(
        errorOf(
          plan(
            request(
              ledger: <String, List<LedgerRead>>{
                itemA: <LedgerRead>[
                  movement('mov-1'),
                  movement(
                    'mov-2',
                    direction: MovementDirection.outgoing,
                  ),
                ],
              },
            ),
          ),
        ),
        CallableError.insufficientStock,
      );
    });

    test('✅ ورصيدٌ موجب يُقبَل — ولو بقي جزءٌ منه فقط', () {
      expect(
        plan(
          request(
            ledger: <String, List<LedgerRead>>{
              itemA: <LedgerRead>[
                movement('mov-1'),
                movement(
                  'mov-2',
                  quantity: const PieceQuantity(PieceCount(20)),
                  direction: MovementDirection.outgoing,
                ),
              ],
            },
          ),
        ),
        isA<DailyPricingAccepted>(),
      );
    });

    test('✅★★ FR-M9-06: والسكرب يُسعَّر بالكيلو — ورصيدُه وزنٌ لا حبّات', () {
      final DailyPricingPlan result = plan(
        request(
          priced: batch(
            lines: <DailyPriceLineInput>[
              const DailyPriceLineInput(
                itemId: scrapItem,
                itemName: 'السكرب',
                unit: ItemUnit.kilogram,
                distributionPrice: Money(700),
                minCashPrice: Money(600),
              ),
            ],
          ),
          items: <String, ItemRead>{
            scrapItem: item(
              itemId: scrapItem,
              name: 'السكرب',
              unit: ItemUnit.kilogram,
            ),
          },
          ledger: <String, List<LedgerRead>>{
            scrapItem: <LedgerRead>[
              movement(
                'mov-scrap',
                itemKey: scrapItem,
                quantity: const WeightQuantity(WeightKg(12.5)),
              ),
            ],
          },
        ),
      );
      final InventoryWrite write = acceptedOf(result).writes.single;
      expect(write.fields['unit'], ItemUnit.kilogram.name);
      expect(write.documentId, 'SRC-001_ITM-0002_20260825');
    });
  });

  group('★★ السبب النصي اختياريٌّ — ADR-0020 (كان ADR-0004 · CR-002)', () {
    Map<String, Object?> stored({int distribution = 1200, int minimum = 1000}) =>
        <String, Object?>{
          'distributionPrice': distribution,
          'minCashPrice': minimum,
        };

    test('✅★ تسعيرٌ أوّل لا يُطالَب بعلّة — FR-M9-01: كل يوم يبدأ بلا أسعار',
        () {
      final DailyPricingAccepted accepted = acceptedOf(plan(request()));
      expect(accepted.entry.action, AuditAction.create);
      expect(accepted.entry.reason, isNull);
    });

    // ⛔⛔★★★ **ارتدادُ `ADR-0020`:** ★ **كان هذا يُرفَض بـ`ERR_AMEND_002`.**
    test('✅★★ ADR-0020: وتغييرُ سعرٍ قائم بلا سبب يمرّ — والقيد بلا نصّ مخترَع',
        () {
      final DailyPricingAccepted accepted = acceptedOf(
        plan(
          request(
            storedPrices: <String, Map<String, Object?>?>{
              itemA: stored(distribution: 1100),
            },
          ),
        ),
      );
      expect(accepted.entry.action, AuditAction.amend);
      // ★★ **الحارس الباقي:** ⛔ **لا سببَ مُعبَّأ آلياً.**
      expect(accepted.entry.reason, isNull);
    });

    test('✅ وبسببٍ صحيح يمرّ — والقيد يصير «تعديلاً» بقيمتيه قبل وبعد', () {
      final DailyPricingAccepted accepted = acceptedOf(
        plan(
          request(
            storedPrices: <String, Map<String, Object?>?>{
              itemA: stored(distribution: 1100),
            },
            reason: 'تصحيح سعر السوق',
          ),
        ),
      );
      expect(accepted.entry.action, AuditAction.amend);
      expect(accepted.entry.reason, 'تصحيح سعر السوق');
      expect(
        (accepted.entry.valuesBefore[itemA]! as Map<String, Object?>)['distributionPrice'],
        1100,
      );
      expect(
        (accepted.entry.valuesAfter[itemA]! as Map<String, Object?>)['distributionPrice'],
        1200,
      );
    });

    test('✅★★★ §2.7: وإعادةُ إرسال نفس الأسعار ليست تعديلاً فلا تُطالَب بسبب',
        () {
      final DailyPricingAccepted accepted = acceptedOf(
        plan(
          request(
            storedPrices: <String, Map<String, Object?>?>{itemA: stored()},
          ),
        ),
      );
      expect(accepted.entry.action, AuditAction.create);
      expect(accepted.entry.valuesAfter, isEmpty);
    });

    test('✅★★ والتفريغ تعديلٌ يُسجَّل — ⛔ ولا يشترط سبباً بعد ADR-0020', () {
      final DailyPricingAccepted accepted = acceptedOf(
        plan(
          request(
            priced: batch(
              lines: <DailyPriceLineInput>[
                const DailyPriceLineInput(
                  itemId: itemA,
                  itemName: 'عوارض',
                  unit: ItemUnit.piece,
                ),
              ],
            ),
            storedPrices: <String, Map<String, Object?>?>{itemA: stored()},
          ),
        ),
      );
      expect(accepted.entry.action, AuditAction.amend);
      expect(accepted.entry.reason, isNull);
    });

    // ★★ **والفراغات تُقرأ غياباً لا نصّاً** — ⟵ **فلا يُخزَّن حقلٌ يبدو
    //   مملوءاً وهو خالٍ** (`ADR-0020` القيد 3).
    test('✅★★ وسببٌ من فراغات يمرّ ويُقرأ غياباً — ⛔ لا نصّاً فارغاً', () {
      final DailyPricingAccepted accepted = acceptedOf(
        plan(
          request(
            storedPrices: <String, Map<String, Object?>?>{
              itemA: stored(distribution: 1100),
            },
            reason: '   ',
          ),
        ),
      );
      expect(accepted.entry.reason, isNull);
    });
  });

  group('الكتابة — المفتاح والحقول والقيد', () {
    test('★ FR-M9-03: المفتاح {sourceId}_{itemKey}_{date} بترتيبه الملزم', () {
      expect(
        acceptedOf(plan(request())).writes.single.documentId,
        'SRC-001_ITM-0001_20260825',
      );
    });

    test('★ والحقول من سجل النوع لا من الحمولة — الاسم والوحدة', () {
      final InventoryWrite write = acceptedOf(plan(request())).writes.single;
      expect(write.collectionId, dailyPricesCollection);
      expect(write.fields['itemName'], 'عوارض');
      expect(write.fields['unit'], ItemUnit.piece.name);
      expect(write.fields['sourceId'], sourceA);
      expect(write.fields['date'], day.asUtcMidnight());
      expect(write.fields['distributionPrice'], 1200);
      expect(write.fields['minCashPrice'], 1000);
      expect(write.fields['isPricingComplete'], isTrue);
      expect(write.serverTimestampFields, contains('lastModifiedAt'));
    });

    test('★★ والتفريغ يكتب null صريحاً في القناع — ⛔ لا مفتاحاً غائباً', () {
      final InventoryWrite write = acceptedOf(
        plan(
          request(
            priced: batch(
              lines: <DailyPriceLineInput>[
                const DailyPriceLineInput(
                  itemId: itemA,
                  itemName: 'عوارض',
                  unit: ItemUnit.piece,
                ),
              ],
            ),
            storedPrices: <String, Map<String, Object?>?>{
              itemA: <String, Object?>{
                'distributionPrice': 1200,
                'minCashPrice': 1000,
              },
            },
            reason: 'أُدخل خطأً',
          ),
        ),
      ).writes.single;
      expect(write.updateMask, contains('distributionPrice'));
      expect(write.updateMask, contains('minCashPrice'));
      expect(write.fields['distributionPrice'], isNull);
      expect(write.fields['minCashPrice'], isNull);
      expect(write.fields['isPricingComplete'], isFalse);
    });

    test('★ FR-M9-05: ونصفُ التسعير يُكتب isPricingComplete = false', () {
      final InventoryWrite write = acceptedOf(
        plan(
          request(
            priced: batch(
              lines: <DailyPriceLineInput>[
                const DailyPriceLineInput(
                  itemId: itemA,
                  itemName: 'عوارض',
                  unit: ItemUnit.piece,
                  distributionPrice: Money(1200),
                ),
              ],
            ),
          ),
        ),
      ).writes.single;
      expect(write.fields['isPricingComplete'], isFalse);
      expect(write.fields['minCashPrice'], isNull);
    });

    test('★ والقيد يحمل المصدر ونوع الكيان ومعرّف دفعة اليوم', () {
      final AuditEntry entry = acceptedOf(plan(request())).entry;
      expect(entry.id, requestId);
      expect(entry.target.entityType, dailyPriceEntityType);
      expect(entry.target.entityId, 'SRC-001_20260825');
      expect(entry.target.sourceId, sourceA);
      expect(entry.actor.userId, actorUid);
    });

    test('★ ودفعةٌ بعدة أنواع تُنتج كتابةً لكلٍّ منها', () {
      final DailyPricingAccepted accepted = acceptedOf(
        plan(
          request(
            priced: batch(
              lines: <DailyPriceLineInput>[
                const DailyPriceLineInput(
                  itemId: itemA,
                  itemName: 'عوارض',
                  unit: ItemUnit.piece,
                  distributionPrice: Money(1200),
                  minCashPrice: Money(1000),
                ),
                const DailyPriceLineInput(
                  itemId: scrapItem,
                  itemName: 'السكرب',
                  unit: ItemUnit.kilogram,
                  distributionPrice: Money(700),
                  minCashPrice: Money(600),
                ),
              ],
            ),
            items: <String, ItemRead>{
              itemA: item(),
              scrapItem: item(
                itemId: scrapItem,
                name: 'السكرب',
                unit: ItemUnit.kilogram,
              ),
            },
            ledger: <String, List<LedgerRead>>{
              itemA: <LedgerRead>[movement('mov-1')],
              scrapItem: <LedgerRead>[
                movement(
                  'mov-scrap',
                  itemKey: scrapItem,
                  quantity: const WeightQuantity(WeightKg(9)),
                ),
              ],
            },
          ),
        ),
      );
      expect(accepted.writes.length, 2);
      expect(
        accepted.writes.map((InventoryWrite w) => w.documentId).toList(),
        <String>['SRC-001_ITM-0001_20260825', 'SRC-001_ITM-0002_20260825'],
      );
    });

    test('★ coding-standards §2.7: نفس الطلب يُنتج نفس الخطة حرفياً', () {
      List<String> idsOf(DailyPricingPlan p) =>
          acceptedOf(p).writes.map((InventoryWrite w) => w.documentId).toList();
      expect(idsOf(plan(request())), idsOf(plan(request())));
    });
  });
}

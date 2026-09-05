/// الإتلاف — ★★★ **حارس التفويض والنطاق وتاريخ المخزون والرصيد** (`WU-020`).
///
/// ⚠️⚠️ **ولماذا يُختبَر بهذه الصرامة:** بعد إغلاق الكتابة المباشرة
/// (`ADR-0013` القاعدة 2) **لم يبقَ بين المستخدم والدفتر إلا هذا الكود** —
/// ⟵ **فكل شرطٍ كانت تفرضه `firestore.rules` صار بند قبولٍ هنا.**
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **وأخطر أربعةٍ تحرسها هذه الاختبارات:**
///
///   ① **`FR-M8-16`:** ⛔⛔ **لا حقلَ ماليٍّ واحدٌ يُكتب** — ⟵ **وحارسٌ
///      يمسح كلَّ حقلٍ في كلِّ كتابةٍ بحثاً عن اسمٍ ماليّ**، ★ **فالخطأ هنا
///      يُدخِل المُتلَف في إيرادٍ لم يقع.**
///   ② **`A-15` · `GR-29`:** ⛔⛔ **ولا قيدَ في دفتر المقاوته ولا الرعوي** —
///      ★ **يُقاس بعدّ المجموعات المكتوبة** ⛔ **لا بقراءة الكود.**
///   ③ **`design-overview.md` §2.2:** ★★ **والحركةُ مَوْسومةٌ `disposal`** —
///      ⟵ **وهو ما يُخرِجها من سعر الجونية ومن المبيعات.**
///   ④ **`FR-M8-11`:** ★★ **وتاريخُ مخزونٍ أقدمُ يشترط `agedRemainderClear`**
///      · ⛔ **والمستقبليُّ مرفوضٌ للجميع بلا مفتاحٍ يفتحه.**
/// ═══════════════════════════════════════════════════════════════════════
library;

import 'package:qtms_domain/qtms_domain.dart';
import 'package:qtms_functions/src/callable.dart';
import 'package:qtms_functions/src/disposal.dart';
import 'package:qtms_functions/src/identity_claims.dart';
import 'package:qtms_functions/src/identity_gateway.dart';
import 'package:qtms_functions/src/inventory.dart';
import 'package:test/test.dart';

const String actorUid = 'uid-owner';
const String sourceA = 'SRC-001';
const String sourceB = 'SRC-002';
const String itemA = 'ITM-0001';
const String documentNumber = 'DSP-20260904-0001';

final CalendarDay day = CalendarDay(2026, 9, 4);
final CalendarDay yesterday = CalendarDay(2026, 9, 3);
final CalendarDay tomorrow = CalendarDay(2026, 9, 5);

/// ★ مفاتيح الإتلاف الثلاثة — **لاختبارات ما ليس تفويضاً**.
const Set<Permission> fullPermissions = <Permission>{
  Permission.disposalCreate,
  Permission.disposalAmend,
  Permission.disposalCancel,
};

/// ⛔⛔★★★ **أسماءُ الحقول المالية الممنوعة** — `FR-M8-16` ·
/// `data-dictionary.md` §`disposals`.
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

DisposalLineInput line({
  String itemId = itemA,
  int quantity = 5,
  String? sackId,
}) =>
    DisposalLineInput(
      itemId: itemId,
      itemName: 'عوارض',
      unit: ItemUnit.piece,
      quantity: PieceQuantity(PieceCount(quantity)),
      sackId: sackId,
    );

ValidatedDisposal payload({
  String sourceId = sourceA,
  List<DisposalLineInput>? lines,
  String? reason,
}) =>
    (validateDisposal(
      DisposalInput(
        sourceId: sourceId,
        lines: lines ?? <DisposalLineInput>[line()],
        reason: reason,
      ),
    ) as Success<ValidatedDisposal>)
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

DisposalRequest request({
  AccountRecord? actor,
  ValidatedDisposal? disposal,
  Map<String, Object?>? storedSource = const <String, Object?>{
    'isActive': true,
    'name': 'مصدر الاختبار',
  },
  Map<String, Object?>? storedDocument,
  Map<String, ItemRead>? items,
  Map<String, List<LedgerRead>>? ledger,
  String? reason,
  String sourceId = sourceA,
  String number = documentNumber,
  CalendarDay? stockDate,
  CalendarDay? serverDay,
  String requestId = 'req-1',
}) =>
    DisposalRequest(
      actor: actor ?? account(),
      requestId: requestId,
      sourceId: sourceId,
      documentNumber: number,
      stockDate: stockDate ?? day,
      serverDay: serverDay,
      disposal: disposal,
      storedSource: storedSource,
      storedDocument: storedDocument,
      items: items ?? <String, ItemRead>{itemA: item()},
      // ★ **مخزونٌ افتراضي وافر** — ⟵ **فاختبارات التفويض تفشل على التفويض
      //   لا على نقص الرصيد**، ⛔ **ونجاحٌ لسببٍ خاطئ أسوأ من فشل.**
      ledger: ledger ??
          <String, List<LedgerRead>>{
            itemA: <LedgerRead>[movement('INC-1_$itemA', 100)],
          },
      reason: reason,
    );

DisposalAccepted accept(DisposalPlan plan) {
  expect(plan, isA<DisposalAccepted>(), reason: 'رُفض ما كان يجب قبوله');
  return plan as DisposalAccepted;
}

CallableError reject(DisposalPlan plan) {
  expect(plan, isA<DisposalRejected>(), reason: 'قُبل ما كان يجب رفضه');
  return (plan as DisposalRejected).error;
}

Map<String, Object?> writeFor(
  DisposalAccepted accepted,
  String collection,
) =>
    accepted.writes
        .firstWhere(
          (InventoryWrite write) => write.collectionId == collection,
        )
        .fields;

void main() {
  group('★★★ FR-M8-16 — ولا حقلَ ماليٍّ واحدٌ في أي كتابة', () {
    test('⛔⛔★★★ لا اسمَ ماليٍّ في أي حقلٍ من كل الكتابات', () {
      final DisposalAccepted accepted = accept(
        planDisposal(
          request(disposal: payload()),
          DisposalOperation.createDisposal,
        ),
      );

      for (final InventoryWrite write in accepted.writes) {
        for (final String field in write.fields.keys) {
          expect(
            forbiddenMoneyFields.contains(field),
            isFalse,
            reason: 'الحقل «$field» ماليٌّ وقد كُتب في ${write.collectionId}',
          );
        }
      }
    });

    test('⛔⛔★★ ولا سطرَ في المستند يحمل سعراً ولا قيمة', () {
      final DisposalAccepted accepted = accept(
        planDisposal(
          request(disposal: payload()),
          DisposalOperation.createDisposal,
        ),
      );
      final Object? lines = writeFor(accepted, disposalsCollection)['lines'];
      expect(lines, isA<List<Object?>>());
      for (final Object? entry in lines! as List<Object?>) {
        final Map<String, Object?> row = entry! as Map<String, Object?>;
        for (final String field in row.keys) {
          expect(forbiddenMoneyFields.contains(field), isFalse);
        }
      }
    });
  });

  group('★★★ A-15 · GR-29 — ولا قيدَ في دفتر المقاوته ولا الرعوي', () {
    test('⛔⛔★★★ المجموعاتُ المكتوبة ثلاثٌ لا أكثر', () {
      final DisposalAccepted accepted = accept(
        planDisposal(
          request(disposal: payload()),
          DisposalOperation.createDisposal,
        ),
      );
      expect(
        accepted.writes
            .map((InventoryWrite write) => write.collectionId)
            .toSet(),
        <String>{
          disposalsCollection,
          inventoryLedgerCollection,
          itemDailyBalancesCollection,
        },
      );
    });

    test('⛔⛔★★★ ولا `dealer_ledger` ولا `supplier_ledger` ولا أرصدتهما', () {
      final DisposalAccepted accepted = accept(
        planDisposal(
          request(disposal: payload()),
          DisposalOperation.createDisposal,
        ),
      );
      for (final InventoryWrite write in accepted.writes) {
        expect(
          <String>[
            dealerLedgerCollection,
            supplierLedgerCollection,
            dealerBalancesCollection,
            supplierBalancesCollection,
          ],
          isNot(contains(write.collectionId)),
        );
      }
    });
  });

  group('★★★ design-overview §2.2 — الوسم يُخرِجه من سعر الجونية', () {
    test('★★★ حركةُ الدفتر مَوْسومةٌ `disposal` ⛔ لا `normal`', () {
      final DisposalAccepted accepted = accept(
        planDisposal(
          request(disposal: payload()),
          DisposalOperation.createDisposal,
        ),
      );
      final Map<String, Object?> ledger =
          writeFor(accepted, inventoryLedgerCollection);
      expect(ledger['movementTag'], MovementTag.disposal.name);
      expect(ledger['direction'], MovementDirection.outgoing.name);
      expect(ledger['sourceDocType'], SourceDocumentType.disposal.name);
    });

    test('★★ ومرجعُ الجونية يبقى في الحركة — ⛔ بلا أثرٍ في سعرها', () {
      final DisposalAccepted accepted = accept(
        planDisposal(
          request(
            disposal: payload(
              lines: <DisposalLineInput>[line(sackId: 'SCK-20260904-0001')],
            ),
          ),
          DisposalOperation.createDisposal,
        ),
      );
      expect(
        writeFor(accepted, inventoryLedgerCollection)['sackId'],
        'SCK-20260904-0001',
      );
    });
  });

  group('★★★ التفويض — ثلاثةُ مفاتيح مستقلة', () {
    test('⛔ الإنشاء بلا `disposalCreate` يُرفَض', () {
      expect(
        reject(
          planDisposal(
            request(
              actor: account(permissions: <Permission>{
                Permission.disposalAmend,
                Permission.disposalCancel,
              }),
              disposal: payload(),
            ),
            DisposalOperation.createDisposal,
          ),
        ),
        CallableError.permissionMissing,
      );
    });

    test('⛔★★ ومن يُنشئ لا يُلغي — `disposalCancel` مفتاحٌ مستقل', () {
      expect(
        reject(
          planDisposal(
            request(
              actor: account(
                permissions: <Permission>{Permission.disposalCreate},
              ),
              storedDocument: <String, Object?>{'sourceId': sourceA},
            ),
            DisposalOperation.cancelDisposal,
          ),
        ),
        CallableError.permissionMissing,
      );
    });

    test('⛔★★ والتعديل مفتاحُه ثالثٌ — `disposalAmend`', () {
      expect(
        reject(
          planDisposal(
            request(
              actor: account(
                permissions: <Permission>{Permission.disposalCreate},
              ),
              disposal: payload(),
              storedDocument: <String, Object?>{'sourceId': sourceA},
            ),
            DisposalOperation.amendDisposal,
          ),
        ),
        CallableError.permissionMissing,
      );
    });

    test('⛔⛔★★ والحسابُ المعطَّل يُرفَض ولو ملك المفاتيح — التعطيل فوري', () {
      expect(
        reject(
          planDisposal(
            request(actor: account(disabled: true), disposal: payload()),
            DisposalOperation.createDisposal,
          ),
        ),
        CallableError.accountDisabled,
      );
    });
  });

  group('★★★ GR-23 — النطاق يعلو على كل صلاحية', () {
    test('⛔⛔ مصدرٌ خارج النطاق يُرفَض ولو ملك كلَّ المفاتيح', () {
      expect(
        reject(
          planDisposal(
            request(
              actor: account(scope: ScopedSources(<String>{sourceB})),
              disposal: payload(),
            ),
            DisposalOperation.createDisposal,
          ),
        ),
        CallableError.sourceOutOfScope,
      );
    });

    test('⛔⛔★★ والمخزَّن هو الحَكَم في التعديل — لا المُرسَل', () {
      expect(
        reject(
          planDisposal(
            request(
              disposal: payload(),
              storedDocument: <String, Object?>{'sourceId': sourceB},
            ),
            DisposalOperation.amendDisposal,
          ),
        ),
        CallableError.sourceOutOfScope,
      );
    });
  });

  group('★★★ FR-M8-11 — تاريخُ المخزون وبوابةُ التصريف المتأخر', () {
    test('✅ اليومُ نفسُه يمرّ بلا مفتاحٍ إضافي', () {
      accept(
        planDisposal(
          request(disposal: payload(), stockDate: day, serverDay: day),
          DisposalOperation.createDisposal,
        ),
      );
    });

    test('⛔★★ وأقدمُ بلا `agedRemainderClear` يُرفَض', () {
      expect(
        reject(
          planDisposal(
            request(
              disposal: payload(),
              stockDate: yesterday,
              serverDay: day,
            ),
            DisposalOperation.createDisposal,
          ),
        ),
        CallableError.permissionMissing,
      );
    });

    test('✅★★ وأقدمُ بالمفتاح يمرّ — والإتلافُ ثالثُ إجراءات التصريف', () {
      accept(
        planDisposal(
          request(
            actor: account(
              permissions: <Permission>{
                ...fullPermissions,
                Permission.agedRemainderClear,
              },
            ),
            disposal: payload(),
            stockDate: yesterday,
            serverDay: day,
          ),
          DisposalOperation.createDisposal,
        ),
      );
    });

    test('⛔⛔★★★ والمستقبليُّ مرفوضٌ ولمن يملك المفتاح نفسَه', () {
      expect(
        reject(
          planDisposal(
            request(
              actor: account(
                permissions: <Permission>{
                  ...fullPermissions,
                  Permission.agedRemainderClear,
                },
              ),
              disposal: payload(),
              stockDate: tomorrow,
              serverDay: day,
            ),
            DisposalOperation.createDisposal,
          ),
        ),
        CallableError.invalidArgument,
      );
    });

    test('★★ وحركةُ الدفتر تقع على تاريخ المخزون لا على يوم المنصّة', () {
      final DisposalAccepted accepted = accept(
        planDisposal(
          request(
            actor: account(
              permissions: <Permission>{
                ...fullPermissions,
                Permission.agedRemainderClear,
              },
            ),
            disposal: payload(),
            stockDate: yesterday,
            serverDay: day,
          ),
          DisposalOperation.createDisposal,
        ),
      );
      expect(
        writeFor(accepted, inventoryLedgerCollection)['stockDate'],
        yesterday.asUtcMidnight(),
      );
    });

    test('★ ولا يُفحَص التاريخ في الإلغاء — وإلا استحال إلغاءُ إتلافِ أمس', () {
      accept(
        planDisposal(
          request(
            stockDate: yesterday,
            serverDay: day,
            storedDocument: <String, Object?>{'sourceId': sourceA},
            ledger: <String, List<LedgerRead>>{
              itemA: <LedgerRead>[
                movement('INC-1_$itemA', 100),
                movement(
                  '${documentNumber}_$itemA',
                  5,
                  direction: MovementDirection.outgoing,
                ),
              ],
            },
          ),
          DisposalOperation.cancelDisposal,
        ),
      );
    });
  });

  group('★★★ FR-M8-01 · GR-11 — منع الرصيد السالب', () {
    test('⛔ إتلافٌ يتجاوز الرصيد يُرفَض بـ`insufficientStock`', () {
      expect(
        reject(
          planDisposal(
            request(
              disposal:
                  payload(lines: <DisposalLineInput>[line(quantity: 120)]),
            ),
            DisposalOperation.createDisposal,
          ),
        ),
        CallableError.insufficientStock,
      );
    });

    test('★ والرصيدُ بعد الحركة مقيسٌ من الدفتر لا من الحمولة', () {
      final DisposalAccepted accepted = accept(
        planDisposal(
          request(disposal: payload(lines: <DisposalLineInput>[line(quantity: 30)])),
          DisposalOperation.createDisposal,
        ),
      );
      expect(writeFor(accepted, inventoryLedgerCollection)['balanceAfter'], 70);
      final Map<String, Object?> balance =
          writeFor(accepted, itemDailyBalancesCollection);
      expect(balance['incoming'], 100);
      expect(balance['outgoing'], 30);
      expect(balance['balance'], 70);
    });
  });

  group('★★★ الإلغاء — بالوسم ⛔ بلا حركةٍ عكسية ولا حذف', () {
    test('★★ الإلغاءُ يُعيد الكمية إلى الرصيد بوسم الحركة ملغاةً', () {
      final DisposalAccepted accepted = accept(
        planDisposal(
          request(
            storedDocument: <String, Object?>{'sourceId': sourceA},
            ledger: <String, List<LedgerRead>>{
              itemA: <LedgerRead>[
                movement('INC-1_$itemA', 100),
                movement(
                  '${documentNumber}_$itemA',
                  5,
                  direction: MovementDirection.outgoing,
                ),
              ],
            },
          ),
          DisposalOperation.cancelDisposal,
        ),
      );
      expect(accepted.isCancelled, isTrue);
      expect(
        writeFor(accepted, inventoryLedgerCollection)['isCancelled'],
        isTrue,
      );
      expect(writeFor(accepted, itemDailyBalancesCollection)['balance'], 100);
      expect(
        writeFor(accepted, disposalsCollection)[documentStatusField],
        DisposalStatus.cancelled.name,
      );
    });

    test('⛔★★ والملغى لا يُلغى ثانيةً ولا يُعدَّل', () {
      expect(
        reject(
          planDisposal(
            request(
              storedDocument: <String, Object?>{
                'sourceId': sourceA,
                documentStatusField: DisposalStatus.cancelled.name,
              },
            ),
            DisposalOperation.cancelDisposal,
          ),
        ),
        CallableError.documentCancelled,
      );
    });
  });

  group('★★★ قيدُ التدقيق — الفعلُ «إتلاف» باسمه', () {
    test('★★★ الإنشاءُ يكتب `AuditAction.disposal` ⛔ لا `create`', () {
      final DisposalAccepted accepted = accept(
        planDisposal(
          request(disposal: payload()),
          DisposalOperation.createDisposal,
        ),
      );
      expect(accepted.entry.action, AuditAction.disposal);
      expect(accepted.entry.target.entityType, disposalEntityType);
      expect(accepted.entry.target.entityId, documentNumber);
      expect(accepted.entry.target.sourceId, sourceA);
    });

    test('★ والإلغاءُ فعلٌ مستقلٌّ في المعجم', () {
      final DisposalAccepted accepted = accept(
        planDisposal(
          request(
            storedDocument: <String, Object?>{'sourceId': sourceA},
            ledger: <String, List<LedgerRead>>{
              itemA: <LedgerRead>[movement('INC-1_$itemA', 100)],
            },
          ),
          DisposalOperation.cancelDisposal,
        ),
      );
      expect(accepted.entry.action, AuditAction.cancel);
    });

    test('✅★★★ ADR-0020 — وبلا سببٍ يمرّ، والقيدُ بلا نصٍّ مخترَع', () {
      final DisposalAccepted accepted = accept(
        planDisposal(
          request(disposal: payload()),
          DisposalOperation.createDisposal,
        ),
      );
      expect(accepted.entry.reason, isNull);
      expect(
        writeFor(accepted, disposalsCollection).containsKey('reason'),
        isFalse,
      );
    });

    test('✅★★ والفراغاتُ تُقرأ غياباً لا نصّاً فارغاً', () {
      final DisposalAccepted accepted = accept(
        planDisposal(
          request(
            disposal: payload(),
            reason: '   ',
            storedDocument: <String, Object?>{'sourceId': sourceA},
          ),
          DisposalOperation.amendDisposal,
        ),
      );
      expect(accepted.entry.reason, isNull);
      expect(
        writeFor(accepted, disposalsCollection)['amendReason'],
        isNull,
      );
    });
  });

  group('★★★ الأنواع والمصدر والوجود', () {
    test('⛔ نوعٌ غير مرتبطٍ بالمصدر يُرفَض — `FR-M5-10`', () {
      expect(
        reject(
          planDisposal(
            request(
              disposal: payload(),
              items: <String, ItemRead>{
                itemA: item(sourceIds: const <String>[sourceB]),
              },
            ),
            DisposalOperation.createDisposal,
          ),
        ),
        CallableError.invalidArgument,
      );
    });

    test('⛔ ووحدةُ السطر تخالف وحدةَ النوع تُرفَض — `GR-19`', () {
      expect(
        reject(
          planDisposal(
            request(
              disposal: payload(),
              items: <String, ItemRead>{
                itemA: item(unit: ItemUnit.kilogram),
              },
            ),
            DisposalOperation.createDisposal,
          ),
        ),
        CallableError.itemUnitLocked,
      );
    });

    test('⛔ ومصدرٌ معطَّل يمنع الإنشاء — `FR-M2-05`', () {
      expect(
        reject(
          planDisposal(
            request(
              disposal: payload(),
              storedSource: const <String, Object?>{'isActive': false},
            ),
            DisposalOperation.createDisposal,
          ),
        ),
        CallableError.sourceInactive,
      );
    });

    test('★ والإلغاء مسموحٌ على مصدرٍ عُطِّل — فلا يُحبَس مستندٌ خاطئ', () {
      accept(
        planDisposal(
          request(
            storedSource: const <String, Object?>{'isActive': false},
            storedDocument: <String, Object?>{'sourceId': sourceA},
            ledger: <String, List<LedgerRead>>{
              itemA: <LedgerRead>[movement('INC-1_$itemA', 100)],
            },
          ),
          DisposalOperation.cancelDisposal,
        ),
      );
    });

    test('⛔ ورقمٌ قائمٌ عند الإنشاء تصادمُ عدّاد — `concurrency`', () {
      expect(
        reject(
          planDisposal(
            request(
              disposal: payload(),
              storedDocument: <String, Object?>{'sourceId': sourceA},
            ),
            DisposalOperation.createDisposal,
          ),
        ),
        CallableError.concurrency,
      );
    });

    test('⛔ ومعرّفُ طلبٍ فارغ يُرفَض — لا لاتكرارية بلا معرّف', () {
      expect(
        reject(
          planDisposal(
            request(disposal: payload(), requestId: '  '),
            DisposalOperation.createDisposal,
          ),
        ),
        CallableError.invalidArgument,
      );
    });
  });

  group('★ قابلية التكرار بلا أثر جانبي — coding-standards §2.7', () {
    test('★ نفس الطلب يُنتج نفس الخطة حرفياً', () {
      final DisposalAccepted first = accept(
        planDisposal(
          request(disposal: payload()),
          DisposalOperation.createDisposal,
        ),
      );
      final DisposalAccepted second = accept(
        planDisposal(
          request(disposal: payload()),
          DisposalOperation.createDisposal,
        ),
      );
      expect(
        first.writes.map((InventoryWrite w) => w.documentId).toList(),
        second.writes.map((InventoryWrite w) => w.documentId).toList(),
      );
      expect(
        writeFor(first, itemDailyBalancesCollection)['balance'],
        writeFor(second, itemDailyBalancesCollection)['balance'],
      );
    });
  });
}

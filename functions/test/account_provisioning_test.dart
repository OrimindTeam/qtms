import 'package:qtms_functions/src/account_provisioning.dart';
import 'package:qtms_functions/src/callable.dart';
import 'package:qtms_functions/src/firestore_event.dart';
import 'package:test/test.dart';

/// طلب مُعدّ للاختبار — ⛔ بلا أي قراءة من قاعدة بيانات.
AccountProvisioningRequest request({
  required ProvisioningTrigger trigger,
  required String entityId,
  List<String> dealerIds = const <String>[],
  List<String> supplierIds = const <String>[],
  List<String> sourceIds = const <String>[],
  Set<String> existingDealers = const <String>{},
  Set<String> existingSuppliers = const <String>{},
  ScrapItemSnapshot? scrap,
}) =>
    AccountProvisioningRequest(
      trigger: trigger,
      entityId: entityId,
      dealerIds: dealerIds,
      supplierIds: supplierIds,
      sourceIds: sourceIds,
      existingDealerBalanceKeys: existingDealers,
      existingSupplierBalanceKeys: existingSuppliers,
      scrapItem: scrap,
    );

AccountProvisioningAccepted accepted(AccountProvisioningPlan plan) {
  expect(plan, isA<AccountProvisioningAccepted>(),
      reason: 'الخطة ليست مقبولة: $plan');
  return plan as AccountProvisioningAccepted;
}

ProvisioningWrite writeAt(AccountProvisioningAccepted plan, String path) =>
    plan.writes.firstWhere(
      (ProvisioningWrite w) => w.path == path,
      orElse: () => throw StateError('لا كتابة على المسار $path'),
    );

void main() {
  group('إضافة مصدر — حساب لكل طرف + نسخة السكرب (api-overview §3.2)', () {
    test('يُهيَّأ حساب لكل مقوت ولكل رعوي في المصدر الجديد', () {
      final AccountProvisioningAccepted plan = accepted(planAccountProvisioning(
        request(
          trigger: ProvisioningTrigger.sourceAdded,
          entityId: 'SRC-002',
          dealerIds: <String>['DLR-001', 'DLR-002'],
          supplierIds: <String>['SUP-001'],
          scrap: const ScrapItemSnapshot(
            itemId: 'ITM-0001',
            sourceIds: <String>['SRC-001'],
          ),
        ),
      ));

      expect(
        plan.writes.map((ProvisioningWrite w) => w.path),
        containsAll(<String>[
          'dealer_balances/DLR-001_SRC-002',
          'dealer_balances/DLR-002_SRC-002',
          'supplier_balances/SUP-001_SRC-002',
        ]),
      );
    });

    test('★ ولا مبلغ إلا عدداً صحيحاً — ADR-0015', () {
      final AccountProvisioningAccepted plan = accepted(planAccountProvisioning(
        request(
          trigger: ProvisioningTrigger.sourceAdded,
          entityId: 'SRC-002',
          dealerIds: <String>['DLR-001'],
          supplierIds: <String>['SUP-001'],
          scrap: const ScrapItemSnapshot(itemId: 'ITM-0001', sourceIds: <String>[]),
        ),
      ));

      for (final ProvisioningWrite w in plan.writes) {
        for (final MapEntry<String, Object?> f in w.fields.entries) {
          if (f.value is num) {
            expect(f.value, isA<int>(),
                reason: '${w.path}.${f.key} ليس عدداً صحيحاً');
          }
        }
      }
    });

    test('★ وحساب الرعوي يحمل sourceId صريحاً — وإلا لم يقرأه أحد', () {
      // قاعدة قراءة supplier_balances تستدعي storedInScope()،
      // وهي تشترط 'sourceId' in resource.data.
      final AccountProvisioningAccepted plan = accepted(planAccountProvisioning(
        request(
          trigger: ProvisioningTrigger.supplierAdded,
          entityId: 'SUP-009',
          sourceIds: <String>['SRC-001'],
        ),
      ));

      final ProvisioningWrite w =
          writeAt(plan, 'supplier_balances/SUP-009_SRC-001');
      expect(w.fields['sourceId'], 'SRC-001');
      expect(w.updateMask, contains('sourceId'));
    });

    test('★ والسكرب يُوصَل بالمصدر الجديد — اتحاداً لا استبدالاً', () {
      final AccountProvisioningAccepted plan = accepted(planAccountProvisioning(
        request(
          trigger: ProvisioningTrigger.sourceAdded,
          entityId: 'SRC-003',
          scrap: const ScrapItemSnapshot(
            itemId: 'ITM-0001',
            sourceIds: <String>['SRC-001', 'SRC-002'],
          ),
        ),
      ));

      expect(plan.scrapLinked, isTrue);
      final ProvisioningWrite w = writeAt(plan, 'items/ITM-0001');
      // ★ المصادر السابقة باقية — وفقدُها يفصل النوع عن كل مصدر قديم.
      expect(w.fields['sourceIds'], <String>['SRC-001', 'SRC-002', 'SRC-003']);
      expect(w.updateMask, <String>['sourceIds']);
    });

    test('★ ولا يُوصَل مرتين — المصدر المرتبط أصلاً لا يُكتب', () {
      final AccountProvisioningPlan plan = planAccountProvisioning(
        request(
          trigger: ProvisioningTrigger.sourceAdded,
          entityId: 'SRC-001',
          scrap: const ScrapItemSnapshot(
            itemId: 'ITM-0001',
            sourceIds: <String>['SRC-001'],
          ),
        ),
      );

      expect(plan, isA<AccountProvisioningNothingToDo>());
    });

    test('★★ والسكرب الغائب يُبلَّغ عنه ⛔ ولا يُخترَع', () {
      final AccountProvisioningAccepted plan = accepted(planAccountProvisioning(
        request(
          trigger: ProvisioningTrigger.sourceAdded,
          entityId: 'SRC-002',
          scrap: null,
        ),
      ));

      expect(plan.scrapMissing, isTrue);
      expect(plan.scrapLinked, isFalse);
      // ⛔ ولا كتابة واحدة على مجموعة الأنواع.
      expect(
        plan.writes.where((ProvisioningWrite w) => w.path.startsWith('items/')),
        isEmpty,
      );
    });
  });

  group('إضافة طرف — حساب له في كل المصادر القائمة', () {
    test('المقوت الجديد يُهيَّأ له حساب في كل مصدر', () {
      final AccountProvisioningAccepted plan = accepted(planAccountProvisioning(
        request(
          trigger: ProvisioningTrigger.dealerAdded,
          entityId: 'DLR-007',
          sourceIds: <String>['SRC-001', 'SRC-002'],
        ),
      ));

      expect(
        plan.writes.map((ProvisioningWrite w) => w.path),
        <String>[
          'dealer_balances/DLR-007_SRC-001',
          'dealer_balances/DLR-007_SRC-002',
        ],
      );
    });

    test('⛔ ولا يمسّ الطرفُ الجديد مجموعةَ الرعوية', () {
      final AccountProvisioningAccepted plan = accepted(planAccountProvisioning(
        request(
          trigger: ProvisioningTrigger.dealerAdded,
          entityId: 'DLR-007',
          sourceIds: <String>['SRC-001'],
        ),
      ));

      expect(
        plan.writes.where(
          (ProvisioningWrite w) => w.path.startsWith('supplier_balances/'),
        ),
        isEmpty,
      );
    });
  });

  group('★★★ التهيئة تُنشئ الناقص ولا تلمس القائم — وهي أخطر قاعدة هنا', () {
    test('★★ حساب قائم لا يُكتب فوقه — فلا يُمحى رصيد حقيقي', () {
      final AccountProvisioningAccepted plan = accepted(planAccountProvisioning(
        request(
          trigger: ProvisioningTrigger.sourceAdded,
          entityId: 'SRC-002',
          dealerIds: <String>['DLR-001', 'DLR-002'],
          existingDealers: <String>{'DLR-001_SRC-002'},
          scrap: const ScrapItemSnapshot(
            itemId: 'ITM-0001',
            sourceIds: <String>['SRC-002'],
          ),
        ),
      ));

      expect(
        plan.writes.map((ProvisioningWrite w) => w.path),
        <String>['dealer_balances/DLR-002_SRC-002'],
        reason: '⛔ الحساب القائم DLR-001 كُتب فوقه — وهذا محوُ رصيد',
      );
    });

    test('★ وإعادة التشغيل بلا نقص لا تُنتج كتابة إطلاقاً', () {
      final AccountProvisioningPlan plan = planAccountProvisioning(
        request(
          trigger: ProvisioningTrigger.sourceAdded,
          entityId: 'SRC-002',
          dealerIds: <String>['DLR-001'],
          supplierIds: <String>['SUP-001'],
          existingDealers: <String>{'DLR-001_SRC-002'},
          existingSuppliers: <String>{'SUP-001_SRC-002'},
          scrap: const ScrapItemSnapshot(
            itemId: 'ITM-0001',
            sourceIds: <String>['SRC-002'],
          ),
        ),
      );

      expect(plan, isA<AccountProvisioningNothingToDo>());
    });

    test('★ ونفس الطلب يُنتج نفس الخطة حرفياً — coding-standards §2.7', () {
      final AccountProvisioningRequest r = request(
        trigger: ProvisioningTrigger.sourceAdded,
        entityId: 'SRC-002',
        dealerIds: <String>['DLR-002', 'DLR-001'],
        supplierIds: <String>['SUP-001'],
        scrap: const ScrapItemSnapshot(itemId: 'ITM-0001', sourceIds: <String>[]),
      );

      final AccountProvisioningAccepted a = accepted(planAccountProvisioning(r));
      final AccountProvisioningAccepted b = accepted(planAccountProvisioning(r));

      expect(
        b.writes.map((ProvisioningWrite w) => '${w.path}|${w.fields}'),
        a.writes.map((ProvisioningWrite w) => '${w.path}|${w.fields}'),
      );
    });

    test('★ والمعرّف المكرّر في القائمة لا يُنتج كتابتين', () {
      final AccountProvisioningAccepted plan = accepted(planAccountProvisioning(
        request(
          trigger: ProvisioningTrigger.sourceAdded,
          entityId: 'SRC-002',
          dealerIds: <String>['DLR-001', 'DLR-001', ' DLR-001 '],
          scrap: const ScrapItemSnapshot(
            itemId: 'ITM-0001',
            sourceIds: <String>['SRC-002'],
          ),
        ),
      ));

      expect(plan.writes.length, 1);
    });
  });

  group('الرفض', () {
    test('معرّف الكيان الفارغ يُرفض ⛔ ولا يُخطَّط له شيء', () {
      final AccountProvisioningPlan plan = planAccountProvisioning(
        request(
          trigger: ProvisioningTrigger.sourceAdded,
          entityId: '   ',
          dealerIds: <String>['DLR-001'],
        ),
      );

      expect(plan, isA<AccountProvisioningRejected>());
      expect(
        (plan as AccountProvisioningRejected).error,
        CallableError.invalidArgument,
      );
    });
  });

  group('★★ DEBT-16 لا يحجب هذه العملية — سمات الحدث تكفيها', () {
    test('★ المُشغِّل يُشتقّ من المجموعة وحدها', () {
      expect(ProvisioningTrigger.fromCollection('sources'),
          ProvisioningTrigger.sourceAdded);
      expect(ProvisioningTrigger.fromCollection('dealers'),
          ProvisioningTrigger.dealerAdded);
      expect(ProvisioningTrigger.fromCollection('suppliers'),
          ProvisioningTrigger.supplierAdded);
      expect(ProvisioningTrigger.fromCollection('receipts'), isNull);
    });

    test('★★ وحدثٌ بحمولة غير مفكوكة يكفي لمعرفة ماذا نُهيِّئ', () {
      // ★ هذا هو البرهان: `payloadDecoded == false` ومع ذلك نعرف
      //   **أي مستند أُنشئ** — وهو كل ما تحتاجه التهيئة.
      final FirestoreDocumentEvent? event =
          FirestoreDocumentEvent.tryParseAttributesOnly(
        eventType: 'google.cloud.firestore.document.v1.created',
        subject: 'documents/sources/SRC-002',
      );

      expect(event, isNotNull);
      expect(event!.payloadDecoded, isFalse);
      expect(event.documentPath, 'sources/SRC-002');
      expect(event.kind, DocumentChangeKind.created);

      final String collection = event.documentPath.split('/').first;
      final String entityId = event.documentPath.split('/').last;
      expect(ProvisioningTrigger.fromCollection(collection),
          ProvisioningTrigger.sourceAdded);

      final AccountProvisioningAccepted plan = accepted(planAccountProvisioning(
        request(
          trigger: ProvisioningTrigger.fromCollection(collection)!,
          entityId: entityId,
          dealerIds: <String>['DLR-001'],
          scrap: const ScrapItemSnapshot(
            itemId: 'ITM-0001',
            sourceIds: <String>['SRC-002'],
          ),
        ),
      ));

      expect(writeAt(plan, 'dealer_balances/DLR-001_SRC-002').fields['balance'],
          0);
    });
  });
}

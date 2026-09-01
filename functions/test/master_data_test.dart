/// البيانات المرجعية — ★★ **حارس التفويض والتفرد والقيد معاً** (`WU-002`).
///
/// ⚠️⚠️ **ولماذا تُختبَر بهذه الصرامة:** بعد إغلاق الكتابة المباشرة
/// (`ADR-0013` القاعدة 2) **لم يبقَ بين المستخدم والقاعدة إلا هذا الكود** —
/// ⟵ **فكل شرطٍ كانت تفرضه `firestore.rules` صار بند قبولٍ هنا**
/// (`DEBT-21` ①): السبب النصي · وقت الخادم · التفرّد · منع حقول السعر ·
/// حصانة النوع الافتراضي · الكتابة الواحدة للإعداد التأسيسي.
library;

import 'package:qtms_domain/qtms_domain.dart';
import 'package:qtms_functions/src/callable.dart';
import 'package:qtms_functions/src/firestore_value.dart';
import 'package:qtms_functions/src/identity_claims.dart';
import 'package:qtms_functions/src/identity_gateway.dart';
import 'package:qtms_functions/src/master_data.dart';
import 'package:test/test.dart';

const String actorUid = 'uid-admin';

AccountRecord account({
  Set<Permission> permissions = const <Permission>{
    Permission.sourceWrite,
    Permission.supplierWrite,
    Permission.dealerWrite,
    Permission.itemWrite,
    Permission.appSettingsWrite,
  },
  bool disabled = false,
}) =>
    AccountRecord(
      userId: actorUid,
      userName: 'مدير',
      claims: IdentityClaims(
        permissions: permissions,
        sourceScope: const AllSources(),
      ),
      disabled: disabled,
      cardIsActive: true,
    );

ValidatedSource source({
  String name = 'مصدر أ',
  bool requiresSupplier = true,
  bool isActive = true,
  String? disableReason,
}) =>
    (validateSource(
      SourceInput(
        name: name,
        requiresSupplierOnIntake: requiresSupplier,
        isActive: isActive,
        disableReason: disableReason,
      ),
    ) as Success<ValidatedSource>)
        .value;

ValidatedDealer dealer({
  String name = 'مقوت مثال',
  String phone = '777123456',
  bool isActive = true,
  String? disableReason,
}) =>
    (validateDealer(
      DealerInput(
        name: name,
        phone: phone,
        isActive: isActive,
        disableReason: disableReason,
      ),
    ) as Success<ValidatedDealer>)
        .value;

ValidatedItem item({String name = 'عود'}) => (validateItem(
      ItemInput(
        sourceIds: const <String>['SRC-001'],
        name: name,
        nature: ItemNature.countBased,
      ),
    ) as Success<ValidatedItem>)
        .value;

UniquenessGuardRead guard({
  required String collectionId,
  required String key,
  String? owner,
}) =>
    UniquenessGuardRead(
      collectionId: collectionId,
      key: key,
      stored: owner == null
          ? null
          : <String, Object?>{guardEntityIdField: owner, guardNormalizedField: key},
    );

MasterDataRequest sourceRequest({
  AccountRecord? actor,
  String entityId = 'SRC-001',
  ValidatedSource? value,
  UniquenessGuardRead? uniqueness,
  Map<String, Object?>? stored,
  String? amendReason = 'تصحيح الاسم',
}) {
  final ValidatedSource resolved = value ?? source();
  return MasterDataRequest(
    actor: actor ?? account(),
    entityId: entityId,
    requestId: 'REQ-MD-0001',
    source: resolved,
    amendReason: amendReason,
    guard: uniqueness ??
        guard(
          collectionId: uniqueSourceNamesCollection,
          key: resolved.normalizedName,
        ),
    stored: stored,
  );
}

void main() {
  group('★★ البوابة — التفويض في الكود لا في القاعدة (ADR-0013 القاعدة 3)', () {
    test('⛔ حساب معطَّل يُرفَض قبل أي شيء — ERR_AUTH_004', () {
      final MasterDataPlan plan = planMasterData(
        sourceRequest(actor: account(disabled: true)),
        MasterDataOperation.createSource,
      );
      expect(
        (plan as MasterDataRejected).error,
        CallableError.accountDisabled,
      );
    });

    test('⛔ نقصُ المفتاح يُرفَض — ERR_AUTH_001', () {
      final MasterDataPlan plan = planMasterData(
        sourceRequest(actor: account(permissions: const <Permission>{})),
        MasterDataOperation.createSource,
      );
      expect(
        (plan as MasterDataRejected).error,
        CallableError.permissionMissing,
      );
    });

    test('★ ومفتاحُ كيانٍ آخر لا يُغني — أقلّ امتياز', () {
      final MasterDataPlan plan = planMasterData(
        sourceRequest(
          actor: account(permissions: const <Permission>{Permission.itemWrite}),
        ),
        MasterDataOperation.createSource,
      );
      expect(
        (plan as MasterDataRejected).error,
        CallableError.permissionMissing,
      );
    });

    test('⛔ طلبٌ بلا `requestId` يُرفَض — فلا لاتكرارية بدونه', () {
      final MasterDataPlan plan = planMasterData(
        MasterDataRequest(
          actor: account(),
          entityId: 'SRC-001',
          requestId: '   ',
          source: source(),
          guard: guard(
            collectionId: uniqueSourceNamesCollection,
            key: source().normalizedName,
          ),
        ),
        MasterDataOperation.createSource,
      );
      expect(
        (plan as MasterDataRejected).error,
        CallableError.invalidArgument,
      );
    });
  });

  group('★★★ ADR-0020 — تعديل بلا سبب يُقبَل (كان DEBT-21 ① · CR-002)', () {
    // ⛔⛔★★★ **ارتدادُ `ADR-0020`:** ★ **كان يُرفَض بـ`ERR_AMEND_002`.**
    test('✅★★★ تعديل مصدر بلا سبب نصّي يمرّ — ⛔ والقيد بلا نصّ مخترَع', () {
      final MasterDataPlan plan = planMasterData(
        sourceRequest(
          amendReason: null,
          stored: <String, Object?>{'name': 'قديم'},
        ),
        MasterDataOperation.updateSource,
      );
      expect(plan, isA<MasterDataAccepted>());
      expect((plan as MasterDataAccepted).entry.reason, isNull);
    });

    // ★★ **والفراغات تُقرأ غياباً لا نصّاً** — `ADR-0020` القيد 3.
    test('✅★★ والفراغات تمرّ وتُقرأ غياباً — ⛔ لا نصّاً فارغاً في القيد', () {
      final MasterDataPlan plan = planMasterData(
        sourceRequest(
          amendReason: '   ',
          stored: <String, Object?>{'name': 'قديم'},
        ),
        MasterDataOperation.updateSource,
      );
      expect(plan, isA<MasterDataAccepted>());
      expect((plan as MasterDataAccepted).entry.reason, isNull);
    });

    test('★ ولا يسري على الإنشاء — ⛔ ولا «قبل» قبل الإنشاء أصلاً', () {
      final MasterDataPlan plan = planMasterData(
        sourceRequest(amendReason: null),
        MasterDataOperation.createSource,
      );
      expect(plan, isA<MasterDataAccepted>());
      expect((plan as MasterDataAccepted).entry.reason, isNull);
      expect(plan.entry.valuesBefore, isEmpty);
    });

    test('✅ وبسببٍ صحيح يمرّ — والسبب في القيد نفسه', () {
      final MasterDataPlan plan = planMasterData(
        sourceRequest(
          amendReason: 'تصحيح إملائي',
          stored: <String, Object?>{'name': 'مصدر ب'},
        ),
        MasterDataOperation.updateSource,
      );
      expect((plan as MasterDataAccepted).entry.reason, 'تصحيح إملائي');
      expect(plan.entry.action, AuditAction.amend);
    });
  });

  group('★★ حارس التفرد — داخل المعاملة نفسها (master-data-design §3)', () {
    test('⛔ اسم مصدر محجوز لكيانٍ آخر ⟵ ERR_SETUP_004', () {
      final ValidatedSource value = source();
      final MasterDataPlan plan = planMasterData(
        sourceRequest(
          value: value,
          uniqueness: guard(
            collectionId: uniqueSourceNamesCollection,
            key: value.normalizedName,
            owner: 'SRC-099',
          ),
        ),
        MasterDataOperation.createSource,
      );
      expect(
        (plan as MasterDataRejected).error,
        CallableError.duplicateSourceName,
      );
    });

    test('★ ومحجوزٌ لنفس الكيان ليس تكراراً — إعادة إرسال', () {
      final ValidatedSource value = source();
      final MasterDataPlan plan = planMasterData(
        sourceRequest(
          value: value,
          stored: <String, Object?>{'name': 'مصدر أ'},
          uniqueness: guard(
            collectionId: uniqueSourceNamesCollection,
            key: value.normalizedName,
            owner: 'SRC-001',
          ),
        ),
        MasterDataOperation.updateSource,
      );
      expect(plan, isA<MasterDataAccepted>());
    });

    test('⛔★★ وحارسٌ لم يُقرأ ⟵ رفضٌ لا تجاوز', () {
      final MasterDataPlan plan = planMasterData(
        MasterDataRequest(
          actor: account(),
          entityId: 'SRC-001',
          requestId: 'REQ-MD-0001',
          source: source(),
          // ⛔ **بلا حارس** — مسارٌ نسي القراءة.
        ),
        MasterDataOperation.createSource,
      );
      expect((plan as MasterDataRejected).error, CallableError.internal);
    });

    test('★ وسجل الحراسة يُكتب في المعاملة نفسها بمعرّف صاحبه', () {
      final ValidatedSource value = source();
      final MasterDataAccepted plan = planMasterData(
        sourceRequest(value: value),
        MasterDataOperation.createSource,
      ) as MasterDataAccepted;
      final MasterDataWrite guardWrite = plan.writes.firstWhere(
        (MasterDataWrite w) => w.collectionId == uniqueSourceNamesCollection,
      );
      expect(guardWrite.documentId, value.normalizedName);
      expect(guardWrite.fields[guardEntityIdField], 'SRC-001');
    });

    test('★★ التطبيع الكامل يجعل صيغتين مختلفتين مفتاحاً واحداً — IQ-013', () {
      final ValidatedSource plain = source(name: 'مؤسسة');
      final ValidatedSource decorated = source(name: 'موسسه');
      expect(plain.normalizedName, decorated.normalizedName);
    });
  });

  group('★★ وجود المستند — ⛔ ولا إنشاء فوق قائم ولا تعديل لغائب', () {
    test('⛔ إنشاء فوق مستندٍ قائم يُرفَض', () {
      final MasterDataPlan plan = planMasterData(
        sourceRequest(stored: <String, Object?>{'name': 'قائم'}),
        MasterDataOperation.createSource,
      );
      expect(
        (plan as MasterDataRejected).error,
        CallableError.invalidArgument,
      );
    });

    test('⛔ وتعديل ما لا يوجد يُرفَض', () {
      final MasterDataPlan plan = planMasterData(
        sourceRequest(),
        MasterDataOperation.updateSource,
      );
      expect(
        (plan as MasterDataRejected).error,
        CallableError.invalidArgument,
      );
    });
  });

  group('★★ القيد — الحقول المتغيرة فقط (audit-log-design §8)', () {
    test('★ التعديل يسجّل ما تغيّر وحده', () {
      final MasterDataAccepted plan = planMasterData(
        sourceRequest(
          value: source(name: 'مصدر ج', requiresSupplier: true),
          stored: <String, Object?>{
            'name': 'مصدر ب',
            'normalizedName': 'مصدر ب',
            'requiresSupplierOnIntake': true,
            'notes': null,
            'isActive': true,
            'disableReason': null,
          },
        ),
        MasterDataOperation.updateSource,
      ) as MasterDataAccepted;
      expect(plan.entry.valuesAfter.keys, <String>{'name', 'normalizedName'});
      expect(plan.entry.valuesBefore['name'], 'مصدر ب');
      expect(plan.entry.valuesAfter['name'], 'مصدر ج');
      // ⛔ والحقول التي لم تتغيّر لا تدخل القيد.
      expect(plan.entry.valuesAfter.containsKey('isActive'), isFalse);
    });

    // ⚠️★★ **وانتقل هذا الاختبار من الرعوي إلى النوع بـ`CR-006`** —
    //    ⟵ **لأن الرعوي لم يعد يحمل `sourceIds`**، ★ **والسلوك المُختبَر
    //    (مقارنةُ القائمة عنصراً بعنصر لا مرجعاً) واحدٌ في المسارين**
    //    ⛔ **فلا تسقط تغطيتُه.**
    test('★ والقائمة تُقارَن عنصراً بعنصر لا مرجعاً', () {
      final ValidatedItem value = (validateItem(
        const ItemInput(
          sourceIds: <String>['SRC-002', 'SRC-001'],
          name: 'عود',
          nature: ItemNature.countBased,
        ),
      ) as Success<ValidatedItem>)
          .value;
      final MasterDataAccepted plan = planMasterData(
        MasterDataRequest(
          actor: account(),
          entityId: 'ITM-0001',
          requestId: 'REQ-MD-0002',
          item: value,
          amendReason: 'تعديل',
          guard: guard(
            collectionId: uniqueItemNamesCollection,
            key: value.normalizedName,
            owner: 'ITM-0001',
          ),
          stored: <String, Object?>{
            'sourceIds': <String>['SRC-001', 'SRC-002'],
            'name': 'عود',
            'normalizedName': value.normalizedName,
            'nature': value.nature.name,
            'unit': value.unit.name,
            'pieceWeightGrams': value.pieceWeightGrams,
            'isSystemDefault': false,
            'isActive': true,
            'disableReason': null,
          },
        ),
        MasterDataOperation.updateItem,
      ) as MasterDataAccepted;
      // ⛔ **لا تغيير** — والقائمتان متطابقتان محتوًى وترتيباً بعد الفرز.
      expect(plan.entry.valuesAfter, isEmpty);
    });

    // ⛔⛔★★★ **وحارسٌ صريح لـ`CR-006`** — ★ **خطةُ كتابة الرعوي لا تحمل
    //    `sourceIds`** ⛔ **لا فارغةً ولا محذوفةً بقناع.**
    test('⛔★★★ وخطةُ الرعوي بلا حقل مصدرٍ إطلاقاً — CR-006', () {
      final ValidatedSupplier value = (validateSupplier(
        const SupplierInput(name: 'رعوي مثال', phone: '777123456'),
      ) as Success<ValidatedSupplier>)
          .value;
      final MasterDataAccepted plan = planMasterData(
        MasterDataRequest(
          actor: account(),
          entityId: 'SUP-0001',
          requestId: 'REQ-MD-0003',
          supplier: value,
          guard: guard(
            collectionId: uniqueSupplierPhonesCollection,
            key: value.normalizedPhone,
          ),
        ),
        MasterDataOperation.createSupplier,
      ) as MasterDataAccepted;
      for (final MasterDataWrite write in plan.writes) {
        expect(write.fields.containsKey('sourceIds'), isFalse);
        expect(write.updateMask.contains('sourceIds'), isFalse);
      }
      expect(plan.entry.valuesAfter.containsKey('sourceIds'), isFalse);
    });

    test('★ قيد المصدر يحمل معرّفه ليُفلتَر بالنطاق — FR-M18-14', () {
      final MasterDataAccepted plan = planMasterData(
        sourceRequest(),
        MasterDataOperation.createSource,
      ) as MasterDataAccepted;
      expect(plan.entry.target.sourceId, 'SRC-001');
    });

    test('★★ ومعرّف القيد هو `requestId` — فإعادة الإرسال لا تُنشئ ثانياً', () {
      final MasterDataAccepted plan = planMasterData(
        sourceRequest(),
        MasterDataOperation.createSource,
      ) as MasterDataAccepted;
      expect(plan.entry.id, 'REQ-MD-0001');
    });
  });

  group('⛅ وقت الخادم — DEBT-21 ① · GR-54', () {
    test('★★ الإنشاء يكتب `createdAt` بتحويل المنصة ⛔ لا بساعة الحاوية', () {
      final MasterDataAccepted plan = planMasterData(
        sourceRequest(),
        MasterDataOperation.createSource,
      ) as MasterDataAccepted;
      final MasterDataWrite entity = plan.writes.first;
      expect(entity.serverTimestampFields, contains('createdAt'));
      // ⛔ ولا يُذكَر في الحقول ولا في القناع.
      expect(entity.fields.containsKey('createdAt'), isFalse);
      expect(entity.updateMask.contains('createdAt'), isFalse);
      expect(entity.fields['createdBy'], actorUid);
    });

    test('⛔ والتعديل لا يمسّ `createdAt` إطلاقاً', () {
      final MasterDataAccepted plan = planMasterData(
        sourceRequest(stored: <String, Object?>{'name': 'قديم'}),
        MasterDataOperation.updateSource,
      ) as MasterDataAccepted;
      expect(plan.writes.first.serverTimestampFields, isEmpty);
      expect(plan.writes.first.fields.containsKey('createdBy'), isFalse);
    });
  });

  group('★★ المقوت — FR-M4-04 · FR-M4-09 · E-39', () {
    MasterDataRequest dealerRequest({
      bool isActive = false,
      String? acknowledgement,
      DealerBalanceCensus? census,
      Map<String, Object?>? stored,
      // ★★ `IQ-020` الخيار أ — **والافتراض `false`** ⛔ **لا `true`**:
      //    فاختبارٌ ينسى ذكرَه يقع في الحالة **الأقلّ صلاحية** لا الأوسع.
      bool canDisableWithBalance = false,
    }) {
      final ValidatedDealer value = dealer(
        isActive: isActive,
        disableReason: isActive ? null : 'ترك العمل',
      );
      return MasterDataRequest(
        actor: account(
          permissions: <Permission>{
            Permission.dealerWrite,
            if (canDisableWithBalance) Permission.dealerDisableWithBalance,
          },
        ),
        entityId: 'MQT-0001',
        requestId: 'REQ-MD-0003',
        dealer: value,
        amendReason: 'تعطيل',
        balanceAcknowledgement: acknowledgement,
        dealerBalances: census,
        guard: guard(
          collectionId: uniqueDealerPhonesCollection,
          key: value.normalizedPhone,
          owner: 'MQT-0001',
        ),
        stored: stored ??
            <String, Object?>{'name': 'مقوت مثال', 'isActive': true},
      );
    }

    test('⛔★★ رصيدٌ لم يُقَس ⟵ رفض — الرفض الافتراضي', () {
      final MasterDataPlan plan = planMasterData(
        dealerRequest(),
        MasterDataOperation.updateDealer,
      );
      expect((plan as MasterDataRejected).error, CallableError.internal);
    });

    test('⛔ ورصيدٌ غير صفري بلا إقرار ⟵ ERR_SETUP_006 — ★ والمفتاح ممنوح '
        'فالمتغيّر واحد', () {
      final MasterDataPlan plan = planMasterData(
        dealerRequest(
          census: const DealerBalanceCensus.measured(<String, int>{
            'SRC-001': 4200,
          }),
          canDisableWithBalance: true,
        ),
        MasterDataOperation.updateDealer,
      );
      expect(
        (plan as MasterDataRejected).error,
        CallableError.dealerBalanceBlocksDisable,
      );
    });

    test('✅ ورصيدٌ صفري يمرّ بلا إقرار', () {
      final MasterDataPlan plan = planMasterData(
        dealerRequest(
          census: const DealerBalanceCensus.measured(<String, int>{
            'SRC-001': 0,
          }),
        ),
        MasterDataOperation.updateDealer,
      );
      expect(plan, isA<MasterDataAccepted>());
    });

    test('✅ وبالمفتاح المستقل والإقرار معاً يمرّ ولو كان عليه رصيد', () {
      final MasterDataPlan plan = planMasterData(
        dealerRequest(
          census: const DealerBalanceCensus.measured(<String, int>{
            'SRC-001': 4200,
          }),
          acknowledgement: 'أقرّ بالمتابعة',
          canDisableWithBalance: true,
        ),
        MasterDataOperation.updateDealer,
      );
      expect(plan, isA<MasterDataAccepted>());
    });

    test('⛔★★★ ولا يكفي الإقرار بلا `dealerDisableWithBalance` ⟵ ERR_AUTH_001',
        () {
      // ★★ **الشطر الذي كان `DEBT-26`** — `IQ-020` الخيار أ (2026-08-25).
      //    ⛔ **و`dealerWrite` وحده لا يفتحه**: الطلب يحمله بالفعل.
      final MasterDataPlan plan = planMasterData(
        dealerRequest(
          census: const DealerBalanceCensus.measured(<String, int>{
            'SRC-001': 4200,
          }),
          acknowledgement: 'أقرّ بالمتابعة',
        ),
        MasterDataOperation.updateDealer,
      );
      expect(
        (plan as MasterDataRejected).error,
        CallableError.permissionMissing,
        reason: '⛔ «ليست لك» تُميَّز عن «اكتب إقراراً»',
      );
    });

    test('★★ ورصيدُ الصفر لا يشترط المفتاح المستقل — ⛔ فليس بديلاً عن '
        '`dealerWrite`', () {
      final MasterDataPlan plan = planMasterData(
        dealerRequest(
          census: const DealerBalanceCensus.measured(<String, int>{
            'SRC-001': 0,
            'SRC-002': 0,
          }),
        ),
        MasterDataOperation.updateDealer,
      );
      expect(plan, isA<MasterDataAccepted>());
    });

    test('★ والتعطيل فعلٌ مستقل في السجل لا «تعديل»', () {
      final MasterDataAccepted plan = planMasterData(
        dealerRequest(
          census: const DealerBalanceCensus.measured(<String, int>{}),
        ),
        MasterDataOperation.updateDealer,
      ) as MasterDataAccepted;
      expect(plan.entry.action, AuditAction.disable);
    });

    test('★ ولا يُقاس الرصيد على مقوتٍ يبقى نشطاً — ⛔ ولا قراءة بلا داعٍ', () {
      final MasterDataPlan plan = planMasterData(
        dealerRequest(isActive: true),
        MasterDataOperation.updateDealer,
      );
      expect(plan, isA<MasterDataAccepted>());
      expect((plan as MasterDataAccepted).entry.action, AuditAction.amend);
    });

    test('⛔★★ ولا حقل مصدر في مستند المقوت — FR-M4-04 · ADR-0005', () {
      final MasterDataAccepted plan = planMasterData(
        dealerRequest(isActive: true),
        MasterDataOperation.updateDealer,
      ) as MasterDataAccepted;
      final Map<String, Object?> fields = plan.writes.first.fields;
      expect(fields.containsKey('sourceId'), isFalse);
      expect(fields.containsKey('sourceIds'), isFalse);
    });
  });

  group('★★ النوع — FR-M5-05 · FR-M5-04 · FR-M5-09', () {
    MasterDataRequest itemRequest({
      Map<String, Object?>? stored,
      ValidatedItem? value,
    }) {
      final ValidatedItem resolved = value ?? item();
      return MasterDataRequest(
        actor: account(),
        entityId: 'ITM-0002',
        requestId: 'REQ-MD-0004',
        item: resolved,
        amendReason: 'تصحيح',
        guard: guard(
          collectionId: uniqueItemNamesCollection,
          key: resolved.normalizedName,
          owner: stored == null ? null : 'ITM-0002',
        ),
        stored: stored,
      );
    }

    test(
      '⛔⛔★★★ DEBT-33: حقولُ النوع الوزني **تُرمَّز فعلاً** — ⛔ ولا `500` خام',
      () {
        // ★★★ **هذا اختبارُ ارتدادٍ لعطلٍ وقع فعلاً على التجريبية (2026-08-26):**
        //    `_itemFields` كانت تمرّر `pieceWeightGrams` **`double` خاماً**،
        //    ⟵ **والمُرمِّز يرفض `double` المجرَّد عمداً** ⟹ ⛔ **كلُّ نوعٍ
        //    وزنيٍّ بوزن حبةٍ كان يسقط بـ`500` بلا رمز كتالوج.**
        //
        // ⚠️⚠️ **ولماذا لم يكشفه اختبارٌ قائم:** كلُّها تفحص **الخطة**
        //    ⛔ **ولا واحد يمرّرها بالمُرمِّز** — ★ **فالفجوة كانت بين
        //    الطبقتين تماماً**، وهو درسُ `DEBT-25` حرفياً.
        final ValidatedItem weighted = (validateItem(
              ItemInput(
                sourceIds: const <String>['SRC-001'],
                name: 'عتود',
                nature: ItemNature.weightBased,
                pieceWeightGrams: 200.0,
              ),
            ) as Success<ValidatedItem>)
            .value;

        final MasterDataPlan plan = planMasterData(
          itemRequest(value: weighted),
          MasterDataOperation.createItem,
        );
        final MasterDataAccepted accepted = plan as MasterDataAccepted;

        // ⛔ **الفحص الحقيقي: الترميز نفسه** — لا شكلُ الخطة.
        for (final MasterDataWrite write in accepted.writes) {
          expect(() => encodeFirestoreFields(write.fields), returnsNormally);
        }
        final MasterDataWrite itemWrite = accepted.writes.firstWhere(
          (MasterDataWrite w) => w.fields.containsKey('pieceWeightGrams'),
        );
        expect(
          encodeFirestoreFields(itemWrite.fields)['pieceWeightGrams'],
          <String, Object?>{'doubleValue': 200.0},
        );
      },
    );

    test('⛔★★ «السكرب» لا يُعدَّل ولو ملك المُنفِّذ `itemWrite` — ERR_SETUP_008',
        () {
      final MasterDataPlan plan = planMasterData(
        itemRequest(
          stored: <String, Object?>{
            'name': scrapItemName,
            'isSystemDefault': true,
            'unit': 'kilogram',
          },
        ),
        MasterDataOperation.updateItem,
      );
      expect((plan as MasterDataRejected).error, CallableError.systemDefaultItem);
    });

    test('⛔★★ وتغيير الوحدة يُرفَض — ERR_SETUP_009 · GR-19', () {
      final MasterDataPlan plan = planMasterData(
        itemRequest(
          stored: <String, Object?>{
            'name': 'عود',
            'isSystemDefault': false,
            'unit': 'kilogram',
          },
        ),
        MasterDataOperation.updateItem,
      );
      expect((plan as MasterDataRejected).error, CallableError.itemUnitLocked);
    });

    test('⛔★★ ولا حقل سعر واحد في مستند النوع — FR-M5-09', () {
      final MasterDataAccepted plan = planMasterData(
        itemRequest(),
        MasterDataOperation.createItem,
      ) as MasterDataAccepted;
      final Map<String, Object?> fields = plan.writes.first.fields;
      for (final String forbidden in forbiddenItemFields) {
        expect(
          fields.keys.map((String k) => k.toLowerCase()).contains(forbidden),
          isFalse,
          reason: 'الحقل «$forbidden» ظهر في مستند النوع',
        );
      }
    });

    test('★ ووحدة نوع المستخدم «حبة» في المستند المكتوب', () {
      final MasterDataAccepted plan = planMasterData(
        itemRequest(),
        MasterDataOperation.createItem,
      ) as MasterDataAccepted;
      expect(plan.writes.first.fields['unit'], 'piece');
      expect(plan.writes.first.fields['isSystemDefault'], false);
    });
  });

  group('★★★ الإعداد التأسيسي — FR-M21-03 · AT-65 · IQ-012', () {
    MasterDataRequest settingsRequest({
      bool businessExists = false,
      bool formattingExists = false,
      String? scrapOwner,
    }) =>
        MasterDataRequest(
          actor: account(),
          entityId: appSettingsBusinessDocId,
          requestId: 'REQ-MD-0005',
          settings: (validateAppSettings(
            const AppSettingsInput(
              businessName: 'وكالة محمد المحامي',
              currencySymbol: 'ر.ي',
            ),
          ) as Success<ValidatedAppSettings>)
              .value,
          businessSettingsExist: businessExists,
          formattingSettingsExist: formattingExists,
          scrapItemId: 'ITM-0001',
          guard: guard(
            collectionId: uniqueItemNamesCollection,
            key: normalizeName(scrapItemName),
            owner: scrapOwner,
          ),
        );

    test('★★ الكتابة الأولى تُنتج أربعة مستندات وقيداً واحداً', () {
      final MasterDataAccepted plan = planMasterData(
        settingsRequest(),
        MasterDataOperation.writeAppSettings,
      ) as MasterDataAccepted;
      expect(
        plan.writes.map((MasterDataWrite w) => '${w.collectionId}/${w.documentId}'),
        <String>[
          '$appSettingsCollection/$appSettingsBusinessDocId',
          '$appSettingsCollection/$appSettingsFormattingDocId',
          '$itemsCollection/ITM-0001',
          '$uniqueItemNamesCollection/${normalizeName(scrapItemName)}',
        ],
      );
      expect(plan.entry.action, AuditAction.create);
    });

    test('★★ والنوع الافتراضي «السكرب» بالكيلوجرام ومحصَّن', () {
      final MasterDataAccepted plan = planMasterData(
        settingsRequest(),
        MasterDataOperation.writeAppSettings,
      ) as MasterDataAccepted;
      final MasterDataWrite scrap = plan.writes.firstWhere(
        (MasterDataWrite w) => w.collectionId == itemsCollection,
      );
      expect(scrap.fields['name'], scrapItemName);
      expect(scrap.fields['unit'], 'kilogram');
      expect(scrap.fields['nature'], 'weightBased');
      expect(scrap.fields['isSystemDefault'], true);
      // ★ **وبلا مصادر** — الوصل يقع مع كل مصدر يُضاف (`FR-M21-09` ④).
      expect(scrap.fields['sourceIds'], isEmpty);
    });

    test('★★ decimalPlaces صفر في المستند المكتوب — ADR-0015', () {
      final MasterDataAccepted plan = planMasterData(
        settingsRequest(),
        MasterDataOperation.writeAppSettings,
      ) as MasterDataAccepted;
      final MasterDataWrite formatting = plan.writes[1];
      expect(formatting.fields['decimalPlaces'], 0);
    });

    test('⛔★★★ AT-65: الكتابة الثانية تُرفَض ولو من المالك — ERR_SETUP_010', () {
      for (final (bool business, bool formatting) in <(bool, bool)>[
        (true, false),
        (false, true),
        (true, true),
      ]) {
        final MasterDataPlan plan = planMasterData(
          settingsRequest(
            businessExists: business,
            formattingExists: formatting,
          ),
          MasterDataOperation.writeAppSettings,
        );
        expect(
          (plan as MasterDataRejected).error,
          CallableError.appSettingsAlreadyWritten,
        );
      }
    });

    test('⛔ واسم «السكرب» محجوزاً لنوعٍ آخر يُرفَض — ERR_SETUP_003', () {
      final MasterDataPlan plan = planMasterData(
        settingsRequest(scrapOwner: 'ITM-0099'),
        MasterDataOperation.writeAppSettings,
      );
      expect(
        (plan as MasterDataRejected).error,
        CallableError.duplicateItemName,
      );
    });
  });

  group('★ قابلية التكرار بلا أثر جانبي — coding-standards §2.7', () {
    test('نفس الطلب يُنتج نفس الخطة حرفياً', () {
      final MasterDataAccepted first = planMasterData(
        sourceRequest(),
        MasterDataOperation.createSource,
      ) as MasterDataAccepted;
      final MasterDataAccepted second = planMasterData(
        sourceRequest(),
        MasterDataOperation.createSource,
      ) as MasterDataAccepted;
      expect(
        first.writes.map((MasterDataWrite w) => w.fields.toString()),
        second.writes.map((MasterDataWrite w) => w.fields.toString()),
      );
      expect(first.entry.id, second.entry.id);
    });
  });
}

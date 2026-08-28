/// الوارد جواني — ★★ **حارس التفويض والمسارات السبعة والرصيد معاً** (`WU-004`).
///
/// ⚠️⚠️ **ولماذا تُختبَر بهذه الصرامة:** `firestore.rules` §`sacks` تنصّ
/// `allow create, update: if false` (`ADR-0013` القاعدة 2) — ⟵ **فلم يبقَ
/// بين المستخدم والجونية إلا هذا الكود**، ★ **وكل شرطٍ كانت تفرضه القاعدة
/// صار بند قبولٍ هنا** (`DEBT-21` ①).
///
/// ★★★ **وأخصُّ ما يحرسه هذا الملف — `IQ-021` الخيار أ:** **`sackCreate`
/// مفتاحٌ مستقل**، ⛔ **ولا يُغني عنه مفتاحٌ حقلي ولا `sackView`.**
library;

import 'package:qtms_domain/qtms_domain.dart';
import 'package:qtms_functions/src/callable.dart';
import 'package:qtms_functions/src/identity_claims.dart';
import 'package:qtms_functions/src/identity_gateway.dart';
import 'package:qtms_functions/src/inventory.dart';
import 'package:qtms_functions/src/firestore_value.dart';
import 'package:qtms_functions/src/sack_intake.dart';
import 'package:test/test.dart';

const String actorUid = 'uid-keeper';
const String sourceA = 'SRC-001';
const String sourceB = 'SRC-002';
const String supplierA = 'SUP-0001';
const String supplierName = 'عبدالفتاح';
const String scrapId = 'ITM-0001';
const String itemA = 'ITM-0002';
const String docNumber = 'SCK-20260826-0001';
const int sequence = 1;

final CalendarDay day = CalendarDay(2026, 8, 26);

/// ★ كل مفاتيح الجونية — **والاختبار يُسقِط منها ما يفحص غيابه**.
const Set<Permission> allSackPermissions = <Permission>{
  Permission.sackCreate,
  Permission.sackView,
  Permission.sackLinesEnter,
  Permission.sackTaxEnterNow,
  Permission.sackTaxEnterLater,
  Permission.sackRenameDisplay,
  Permission.sackScrapWeightEnter,
  Permission.sackLostWeightConfirm,
  Permission.sackAmend,
  Permission.sackCancel,
};

AccountRecord account({
  Set<Permission> permissions = allSackPermissions,
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

ValidatedSackIntake intake({
  String sourceId = sourceA,
  double total = 45,
  double ice = 6.5,
  double scrap = 1.2,
  bool requiresSupplier = true,
  String? supplierId = supplierA,
  List<SackLineInput> lines = const <SackLineInput>[],
  bool lostConfirmed = false,
}) =>
    (validateSackIntake(
      SackIntakeInput(
        sourceId: sourceId,
        sourceRequiresSupplier: requiresSupplier,
        supplierId: supplierId,
        weights: SackWeightsInput(
          totalWeight: WeightKg(total),
          iceWeight: WeightKg(ice),
          scrapWeight: WeightKg(scrap),
        ),
        lines: lines,
        lostWeightConfirmed: lostConfirmed,
      ),
    ) as Success<ValidatedSackIntake>)
        .value;

ValidatedSackLine line({
  String itemId = itemA,
  String itemName = 'بطوة',
  int quantity = 100,
  double pieceWeight = 200,
}) =>
    (resolveSackLine(
      SackLineInput(
        itemId: itemId,
        itemName: itemName,
        nature: ItemNature.weightBased,
        unit: ItemUnit.piece,
        quantity: quantity,
        pieceWeightGrams: pieceWeight,
      ),
    ) as Success<ValidatedSackLine>)
        .value;

StoredSack storedSack({
  String sourceId = sourceA,
  double total = 45,
  double ice = 6.5,
  double scrap = 1.2,
  List<ValidatedSackLine> lines = const <ValidatedSackLine>[],
  SackStatus status = SackStatus.approved,
  String? scrapItemKey,
  bool lostConfirmed = false,
  int amendCount = 0,
}) =>
    StoredSack(
      sourceId: sourceId,
      stockDate: day,
      dailySequence: sequence,
      displayName: sackDisplayName(
        dailySequence: sequence,
        supplierName: supplierName,
      ),
      weights: ValidatedSackWeights(
        totalWeight: WeightKg(total),
        iceWeight: WeightKg(ice),
        scrapWeight: WeightKg(scrap),
      ),
      lines: lines,
      status: status,
      amendCount: amendCount,
      lostWeightConfirmed: lostConfirmed,
      supplierId: supplierA,
      supplierName: supplierName,
      scrapItemKey: scrapItemKey ??
          (scrap > 0
              ? sackScrapCompositeName(
                  dailySequence: sequence,
                  supplierName: supplierName,
                )
              : null),
    );

SackRequest request({
  AccountRecord? actor,
  String sourceId = sourceA,
  String documentNumber = docNumber,
  int? dailySequence,
  ValidatedSackIntake? sack,
  List<ValidatedSackLine>? lines,
  StoredSack? stored,
  Map<String, List<LedgerRead>> ledger = const <String, List<LedgerRead>>{},
  List<String>? supplierSources = const <String>[sourceA],
  String? scrapItemId = scrapId,
  Money? taxPerKilo,
  String? displayName,
  WeightKg? scrapWeight,
  String? reason,
  bool sourceActive = true,
  bool sourceMissing = false,
}) =>
    SackRequest(
      actor: actor ?? account(),
      requestId: 'req-1',
      sourceId: sourceId,
      documentNumber: documentNumber,
      stockDate: day,
      dailySequence: dailySequence,
      intake: sack,
      lines: lines,
      stored: stored,
      ledger: ledger,
      storedSource: sourceMissing
          ? null
          : <String, Object?>{'name': 'رداع', 'isActive': sourceActive},
      storedSupplierSourceIds: supplierSources,
      storedSupplierName: supplierName,
      scrapItemId: scrapItemId,
      taxPerKilo: taxPerKilo,
      displayName: displayName,
      scrapWeight: scrapWeight,
      reason: reason,
    );

SackAccepted accept(SackPlan plan) {
  expect(plan, isA<SackAccepted>(),
      reason: 'توقّعنا قبولاً — والرفض هنا يعني قيداً فُرض خطأً');
  return plan as SackAccepted;
}

CallableError rejectionOf(SackPlan plan) {
  expect(plan, isA<SackRejected>(), reason: 'توقّعنا رفضاً');
  return (plan as SackRejected).error;
}

InventoryWrite writeIn(SackAccepted plan, String collectionId) =>
    plan.writes.firstWhere(
      (InventoryWrite w) => w.collectionId == collectionId,
      orElse: () => throw StateError('لا كتابة في «$collectionId»'),
    );

Iterable<InventoryWrite> writesIn(SackAccepted plan, String collectionId) =>
    plan.writes.where((InventoryWrite w) => w.collectionId == collectionId);

void main() {
  // ═══════════════════════════════════════════════════════════════════════
  group('★★★ IQ-021 — `sackCreate` مفتاحٌ مستقل', () {
    test('✅ من يملكه يُنشئ', () {
      final SackPlan plan = planSack(
        request(sack: intake(), dailySequence: sequence),
        SackOperation.createSack,
      );
      expect(accept(plan).documentNumber, docNumber);
    });

    test('⛔★★★ ومن لا يملكه يُرفَض بـERR_AUTH_001 — ولو ملك كل ما عداه', () {
      // ★★ **هذا هو الاختبار الذي يُثبت أن المفتاح ليس زينة:** المُنفِّذ
      //    يملك **تسعة مفاتيح** من العشرة، ⛔ **والرفض مع ذلك صحيح.**
      final Set<Permission> allButCreate = <Permission>{...allSackPermissions}
        ..remove(Permission.sackCreate);
      final SackPlan plan = planSack(
        request(
          actor: account(permissions: allButCreate),
          sack: intake(),
          dailySequence: sequence,
        ),
        SackOperation.createSack,
      );
      expect(rejectionOf(plan), CallableError.permissionMissing);
    });

    test('⛔★★ ولا يُغني عنه `sackView` — صلاحيةُ قراءةٍ لا إذنٌ كتابي', () {
      final SackPlan plan = planSack(
        request(
          actor: account(permissions: <Permission>{Permission.sackView}),
          sack: intake(),
          dailySequence: sequence,
        ),
        SackOperation.createSack,
      );
      expect(rejectionOf(plan), CallableError.permissionMissing);
    });

    test('⛔★★ ولا `sackLinesEnter` — مسارٌ يقتصر على مصفوفة السطور', () {
      final SackPlan plan = planSack(
        request(
          actor: account(permissions: <Permission>{Permission.sackLinesEnter}),
          sack: intake(),
          dailySequence: sequence,
        ),
        SackOperation.createSack,
      );
      expect(rejectionOf(plan), CallableError.permissionMissing);
    });

    test('★ والمفتاح المُعلَن للعملية هو `sackCreate` حرفياً', () {
      expect(
        SackOperation.createSack.requiredPermission,
        Permission.sackCreate,
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('★★ GR-23 — النطاق قيدٌ يعلو على الصلاحية', () {
    test('⛔ مصدرٌ خارج النطاق يُرفَض ولو مُلكت كل المفاتيح', () {
      final SackPlan plan = planSack(
        request(
          actor: account(scope: ScopedSources(<String>{sourceB})),
          sack: intake(),
          dailySequence: sequence,
        ),
        SackOperation.createSack,
      );
      expect(rejectionOf(plan), CallableError.sourceOutOfScope);
    });

    test('⛔ وحسابٌ معطَّل يُرفَض فوراً — «التعطيل فوري ونافذ»', () {
      final SackPlan plan = planSack(
        request(
          actor: account(disabled: true),
          sack: intake(),
          dailySequence: sequence,
        ),
        SackOperation.createSack,
      );
      expect(rejectionOf(plan), CallableError.accountDisabled);
    });

    test('⛔★★★ والمصدر المخزَّن هو الحَكَم لا المُرسَل', () {
      // ⟵ **وإلا أمكن فحصُ النطاق على مصدرٍ ثم العملُ على مستند مصدرٍ آخر.**
      final SackPlan plan = planSack(
        request(
          stored: storedSack(sourceId: sourceB),
          displayName: 'اسم جديد',
          reason: 'تصحيح',
        ),
        SackOperation.renameSack,
      );
      expect(rejectionOf(plan), CallableError.sourceOutOfScope);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('★★★ FR-M7-09 · AT-07 · E-06 — السكرب يدخل المخزن عند حفظ الرأس', () {
    test('★★ الإنشاء يكتب حركة السكرب ورصيده — قبل أي نوع آخر', () {
      final SackAccepted plan = accept(
        planSack(
          request(sack: intake(), dailySequence: sequence),
          SackOperation.createSack,
        ),
      );

      final InventoryWrite movement =
          writeIn(plan, inventoryLedgerCollection);
      final String expectedKey = sackScrapCompositeName(
        dailySequence: sequence,
        supplierName: supplierName,
      );
      expect(movement.fields['itemKey'], expectedKey);
      expect(movement.fields['unit'], ItemUnit.kilogram.name);
      expect(movement.fields['isScrapLine'], isTrue);
      // ★★ **و`sackId` حاضرٌ بخلاف الوارد عدداً** — `ADR-0007` القاعدة 5.
      expect(movement.fields['sackId'], docNumber);
      expect(writesIn(plan, itemDailyBalancesCollection), hasLength(1));
    });

    test('★★ E-06: جونية بأوزانها بلا أنواع تُقبَل — والسكرب يدخل', () {
      final SackAccepted plan = accept(
        planSack(
          request(sack: intake(), dailySequence: sequence),
          SackOperation.createSack,
        ),
      );
      final InventoryWrite document = writeIn(plan, sacksCollection);
      expect(document.fields['lines'], isEmpty);
      expect(writesIn(plan, inventoryLedgerCollection), hasLength(1));
    });

    test('⛔★★ ADR-0008 القاعدة 5: صفرُ السكرب لا يُنتج حركةً ولا رصيداً', () {
      final SackAccepted plan = accept(
        planSack(
          request(sack: intake(scrap: 0), dailySequence: sequence),
          SackOperation.createSack,
        ),
      );
      expect(writesIn(plan, inventoryLedgerCollection), isEmpty);
      expect(writesIn(plan, itemDailyBalancesCollection), isEmpty);
      expect(writeIn(plan, sacksCollection).fields['scrapItemKey'], isNull);
    });

    test('⛔★★ ونوعٌ افتراضي لم يُقرأ ⟵ لا حركة سكرب — ولا تُخمَّن', () {
      final SackAccepted plan = accept(
        planSack(
          request(sack: intake(), dailySequence: sequence, scrapItemId: null),
          SackOperation.createSack,
        ),
      );
      expect(writesIn(plan, inventoryLedgerCollection), isEmpty);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('★★★ FR-M7-04 · E-44 — الترقيم اليومي المستقل لكل مصدر', () {
    test('★★ التسلسل يدخل المستند واسمه الظاهر معاً', () {
      final SackAccepted plan = accept(
        planSack(
          request(sack: intake(), dailySequence: 3),
          SackOperation.createSack,
        ),
      );
      final InventoryWrite document = writeIn(plan, sacksCollection);
      expect(document.fields['dailySequence'], 3);
      expect(document.fields['displayName'], '$supplierName - جونية رقم 3');
    });

    test('⛔ وتسلسلٌ غائب أو دون ١ يُرفَض — ⛔ ولا يُكتب «جونية رقم 0»', () {
      expect(
        rejectionOf(
          planSack(
            request(sack: intake(), dailySequence: null),
            SackOperation.createSack,
          ),
        ),
        CallableError.invalidArgument,
      );
      expect(
        rejectionOf(
          planSack(
            request(sack: intake(), dailySequence: 0),
            SackOperation.createSack,
          ),
        ),
        CallableError.invalidArgument,
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('⛔★★★ ADR-0011 — ولا حقل مالي في مستند الجونية', () {
    test('⛔ لا `taxPerKilo` ولا `sackTax` ولا `sackRevenue` ولا `supplierNet`',
        () {
      final SackAccepted plan = accept(
        planSack(
          request(sack: intake(), dailySequence: sequence),
          SackOperation.createSack,
        ),
      );
      final Map<String, Object?> fields = writeIn(plan, sacksCollection).fields;
      for (final String forbidden in <String>[
        'taxPerKilo',
        'sackTax',
        'sackRevenue',
        'supplierNet',
      ]) {
        expect(fields.containsKey(forbidden), isFalse,
            reason: '⛔ $forbidden يعيش في finance/current وحده — ADR-0011');
      }
    });

    test('★★ والضريبة تُكتب في `sacks/{id}/finance` وحدها', () {
      final SackAccepted plan = accept(
        planSack(
          request(
            stored: storedSack(),
            taxPerKilo: const Money(25),
            reason: 'إدخال الضريبة',
          ),
          SackOperation.enterSackTax,
        ),
      );
      final InventoryWrite finance = plan.writes.single;
      expect(finance.collectionId, '$sacksCollection/$docNumber/finance');
      expect(finance.documentId, sackFinanceDocumentId);
      // ★★★ AT-13 — 25 × 45.000 = 1,125 عدداً صحيحاً (`ADR-0015`).
      expect(finance.fields['sackTax'], 1125);
      expect(finance.fields['taxPerKilo'], 25);
      // ★ نسخة المصدر — ليُفحَص النطاق بلا قراءة الأب.
      expect(finance.fields['sourceId'], sourceA);
    });

    test('⛔★★ والضريبة لا تكتب حرفاً في مستند الجونية نفسه', () {
      final SackAccepted plan = accept(
        planSack(
          request(
            stored: storedSack(),
            taxPerKilo: const Money(25),
            reason: 'إدخال الضريبة',
          ),
          SackOperation.enterSackTax,
        ),
      );
      expect(writesIn(plan, sacksCollection), isEmpty);
    });

    test('★★ ومفتاحان مقبولان للمسار — والبديل يشترط رفيقه', () {
      // ✅ «الآن» وحده يكفي.
      expect(
        planSack(
          request(
            actor: account(permissions: <Permission>{
              Permission.sackTaxEnterNow,
            }),
            stored: storedSack(),
            taxPerKilo: const Money(25),
            reason: 'ضريبة',
          ),
          SackOperation.enterSackTax,
        ),
        isA<SackAccepted>(),
      );
      // ✅ و«لاحقاً» **مع `sackView`**.
      expect(
        planSack(
          request(
            actor: account(permissions: <Permission>{
              Permission.sackTaxEnterLater,
              Permission.sackView,
            }),
            stored: storedSack(),
            taxPerKilo: const Money(25),
            reason: 'ضريبة',
          ),
          SackOperation.enterSackTax,
        ),
        isA<SackAccepted>(),
      );
      // ⛔★★ **و«لاحقاً» وحده بلا `sackView` يُرفَض** — الكتالوج §2.2.
      expect(
        rejectionOf(
          planSack(
            request(
              actor: account(permissions: <Permission>{
                Permission.sackTaxEnterLater,
              }),
              stored: storedSack(),
              taxPerKilo: const Money(25),
              reason: 'ضريبة',
            ),
            SackOperation.enterSackTax,
          ),
        ),
        CallableError.permissionMissing,
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('★★★ FR-M7-27 — المسارات منفصلة وأقنعتها ضيّقة', () {
    test('★★ مسار الاسم يكتب `displayName` وحده — ⛔ ولا وزناً ولا سطراً', () {
      final SackAccepted plan = accept(
        planSack(
          request(
            stored: storedSack(),
            displayName: 'جونية المعالم',
            reason: 'تصحيح الاسم',
          ),
          SackOperation.renameSack,
        ),
      );
      final InventoryWrite write = plan.writes.single;
      expect(write.fields['displayName'], 'جونية المعالم');
      for (final String untouched in <String>[
        'totalWeight',
        'iceWeight',
        'scrapWeight',
        'lines',
        'dailySequence',
      ]) {
        expect(write.updateMask, isNot(contains(untouched)),
            reason: '⛔ قناعٌ واسع يمحو ما لم يُقصَد — FR-M7-27');
      }
    });

    test('⛔★★★ ADR-0007 القاعدة 3: التسمية لا تمسّ الرقم المتسلسل', () {
      final SackPlan plan = planSack(
        request(
          stored: storedSack(),
          dailySequence: 99,
          displayName: 'اسم',
          reason: 'تصحيح',
        ),
        SackOperation.renameSack,
      );
      expect(rejectionOf(plan), CallableError.invalidArgument);
    });

    test('⛔ وكلُّ مسارٍ يشترط مفتاحه هو — ولا يُقبَل مفتاح مسارٍ آخر', () {
      final List<(SackOperation, Permission)> paths =
          <(SackOperation, Permission)>[
        (SackOperation.enterSackLines, Permission.sackLinesEnter),
        (SackOperation.renameSack, Permission.sackRenameDisplay),
        (SackOperation.enterSackScrapWeight, Permission.sackScrapWeightEnter),
        (SackOperation.confirmSackLostWeight, Permission.sackLostWeightConfirm),
        (SackOperation.amendSack, Permission.sackAmend),
        (SackOperation.cancelSack, Permission.sackCancel),
      ];
      for (final (SackOperation operation, Permission key) in paths) {
        expect(operation.requiredPermission, key);
        // ⛔ **ومن يملك كل المفاتيح إلا هذا يُرفَض** — ★ **فالمفتاح فعّال.**
        final Set<Permission> without = <Permission>{...allSackPermissions}
          ..remove(key);
        final SackPlan plan = planSack(
          request(
            actor: account(permissions: without),
            stored: storedSack(),
            lines: const <ValidatedSackLine>[],
            displayName: 'اسم',
            scrapWeight: const WeightKg(1),
            reason: 'سبب',
          ),
          operation,
        );
        expect(rejectionOf(plan), CallableError.permissionMissing,
            reason: '⛔ ${operation.name} مرّ بلا ${key.name}');
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('★★ ADR-0020 — السبب اختياريٌّ في كل مسارات الجونية', () {
    // ⛔⛔★★★ **ارتدادُ `ADR-0020`:** ★ **كانت الثلاثة تُرفَض** بـ
    //   `ERR_AMEND_002` و`ERR_AMEND_004`.
    test('✅ التعديل بلا سبب يمرّ — ⛔ والقيد بلا نصّ مخترَع', () {
      final SackAccepted plan = accept(
        planSack(
          request(stored: storedSack(), displayName: 'اسم'),
          SackOperation.renameSack,
        ),
      );
      expect(plan.entry.reason, isNull);
    });

    test('✅ والإلغاء بلا سبب يمرّ — والوسم يقع كما هو', () {
      final SackAccepted plan = accept(
        planSack(
          request(stored: storedSack()),
          SackOperation.cancelSack,
        ),
      );
      expect(plan.entry.reason, isNull);
      expect(plan.entry.action, AuditAction.cancel);
    });

    test('✅ والفراغات تمرّ وتُقرأ غياباً — ⛔ لا نصّاً فارغاً', () {
      final SackAccepted plan = accept(
        planSack(
          request(
            stored: storedSack(),
            displayName: 'اسم',
            reason: '   ',
          ),
          SackOperation.renameSack,
        ),
      );
      expect(plan.entry.reason, isNull);
    });

    test('✅★★ وسببٌ كتبه إنسانٌ يُحفَظ حرفياً', () {
      final SackAccepted plan = accept(
        planSack(
          request(
            stored: storedSack(),
            displayName: 'اسم',
            reason: 'تصحيح الاسم الظاهر',
          ),
          SackOperation.renameSack,
        ),
      );
      expect(plan.entry.reason, 'تصحيح الاسم الظاهر');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('★★★ ADR-0018 (مُستوعَبٌ في ADR-0020) — التعبئة المؤجَّلة', () {
    // ⛔⛔★★★ **`requiresReason` لم تعد موجودة** — `ADR-0020` حذفها ومعها
    //   عَلَمَ `isDeferredEntry`. ✅★★ **وما بقي من `ADR-0018` نافذاً هنا هو
    //   «التعبئة الأولى ليست تعديلاً»** — ⛔ **لا `amendCount` ولا شارة**،
    //   ★ **وهو محمولٌ على `isFirstEntry` لا على عَلَمِ الإعفاء**، ⟵ **فلم
    //   يسقط بسقوطه.** ★ **والاختبارات أدناه تحرسه.**

    test('✅ إدخالُ السطور بلا سبب يُقبَل — ⛔ ولا ERR_AMEND_002', () {
      final SackAccepted plan = accept(
        planSack(
          request(stored: storedSack(), lines: <ValidatedSackLine>[line()]),
          SackOperation.enterSackLines,
        ),
      );
      // ⛔⛔★★★ **ولا سببَ مخترَعاً** — **جوهرُ `IQ-025`:** ★ **حقلٌ فارغ
      //    يبقى فارغاً**، ⟵ **فلا يقرأ المدقّق نصَّ آلةٍ يظنّه نصَّ إنسان.**
      expect(plan.entry.reason, isNull);
      expect(
        writeIn(plan, sacksCollection).fields.containsKey('amendReason'),
        isFalse,
      );
    });

    test('✅ وإدخالُ الضريبة بلا سبب يُقبَل كذلك', () {
      final SackAccepted plan = accept(
        planSack(
          request(stored: storedSack(), taxPerKilo: const Money(25)),
          SackOperation.enterSackTax,
        ),
      );
      final InventoryWrite finance =
          writeIn(plan, '$sacksCollection/$docNumber/finance');
      expect(plan.entry.reason, isNull);
      expect(finance.fields.containsKey('amendReason'), isFalse);
      // ★★ **والقناع يبقى شاملاً له** — ⟵ **فإدخالٌ جديد بلا سبب يمحو
      //    سببَ إدخالٍ سابق**، ⛔ **ولا يتركه ملتصقاً بقيمةٍ ليس سبباً لها.**
      expect(finance.updateMask, contains('amendReason'));
    });

    test('★★ وسببٌ كتبه إنسانٌ يصل القيد كما هو', () {
      final SackAccepted plan = accept(
        planSack(
          request(
            stored: storedSack(),
            lines: <ValidatedSackLine>[line()],
            reason: 'تصحيح عدد الحبات',
          ),
          SackOperation.enterSackLines,
        ),
      );
      expect(plan.entry.reason, 'تصحيح عدد الحبات');
    });

    test('⛔★★★ وأوّلُ تعبئةٍ ليست تعديلاً — ⛔ ولا شارة «مُعدَّل»', () {
      final SackAccepted plan = accept(
        planSack(
          request(stored: storedSack(), lines: <ValidatedSackLine>[line()]),
          SackOperation.enterSackLines,
        ),
      );
      final InventoryWrite sack = writeIn(plan, sacksCollection);
      // ⛔⛔ **والشارة تُقرأ من `amendCount > 0`** — ⟵ **فكتابتُه ١ هنا
      //    كانت تَسِم جونيةً لم يمسّها أحدٌ بعد إنشائها.**
      expect(sack.fields.containsKey('amendCount'), isFalse);
      expect(sack.fields.containsKey('amendedBy'), isFalse);
      expect(sack.serverTimestampFields, isNot(contains('lastAmendedAt')));
      expect(sack.updateMask, isNot(contains('amendCount')));
      // ★ **والقيد يقول الحقيقة:** إكمالُ إدخالٍ مؤجَّل (`E-06` · `FR-M7-12`).
      expect(plan.entry.action, AuditAction.create);
    });

    test('⛔★★★ DEBT-39: تعديلٌ بلا سبب يمحو سببَ تعديلٍ سابق', () {
      final SackAccepted plan = accept(
        planSack(
          request(
            stored: storedSack(
              lines: <ValidatedSackLine>[line()],
              amendCount: 2,
            ),
            lines: <ValidatedSackLine>[line(quantity: 70)],
          ),
          SackOperation.enterSackLines,
        ),
      );
      final InventoryWrite sack = writeIn(plan, sacksCollection);
      // ⛔⛔ **القيمة لا تُكتَب** — ★ **والحقلُ في القناع** ⟵ **فيُمحى
      //    المخزَّن**، ⛔ **ولا يبقى نصُّ تعديلٍ سابقٍ عالقاً على هذا.**
      expect(sack.fields.containsKey('amendReason'), isFalse);
      expect(sack.updateMask, contains('amendReason'));
    });

    test('★★ وأوّلُ تعبئةٍ لا تمسّ الحقل أصلاً — ⛔ ولا تمحوه', () {
      final SackAccepted plan = accept(
        planSack(
          request(stored: storedSack(), lines: <ValidatedSackLine>[line()]),
          SackOperation.enterSackLines,
        ),
      );
      // ★ **فرقٌ مقصود:** ⛔ **لا وجودَ لتعديلٍ سابقٍ يُمحى سببُه**،
      //    ⟵ **والحقل خارج القناع كلياً.**
      expect(
        writeIn(plan, sacksCollection).updateMask,
        isNot(contains('amendReason')),
      );
    });

    test('★★ وتغييرُ سطورٍ قائمة تعديلٌ كامل الوسم — والعدّاد يتراكم', () {
      final SackAccepted plan = accept(
        planSack(
          request(
            stored: storedSack(
              lines: <ValidatedSackLine>[line()],
              amendCount: 1,
            ),
            lines: <ValidatedSackLine>[line(quantity: 90)],
          ),
          SackOperation.enterSackLines,
        ),
      );
      final InventoryWrite sack = writeIn(plan, sacksCollection);
      expect(sack.fields['amendCount'], 2);
      expect(sack.fields['amendedBy'], isNotNull);
      expect(sack.serverTimestampFields, contains('lastAmendedAt'));
      expect(plan.entry.action, AuditAction.amend);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('★★★ FR-M7-19 · BR-M7-12 — الوزن الضائع بالتأكيد الصريح وحده', () {
    test('★★ التأكيد يكتب الوزن الضائع ووسمه — ⛔ ولا يلمس الدفتر', () {
      final SackAccepted plan = accept(
        planSack(
          request(
            stored: storedSack(lines: <ValidatedSackLine>[line()]),
          ),
          SackOperation.confirmSackLostWeight,
        ),
      );
      final InventoryWrite write = plan.writes.single;
      expect(write.collectionId, sacksCollection);
      expect(write.fields['lostWeightConfirmed'], isTrue);
      // ⛔★★ FR-M7-20 — ولا يدخل المخزون.
      expect(writesIn(plan, inventoryLedgerCollection), isEmpty);
      expect(writesIn(plan, itemDailyBalancesCollection), isEmpty);
    });

    test('⛔★ وتأكيدٌ بلا متبقٍّ يُرفَض — ⛔ ولا وسمٌ كاذب', () {
      // المطالب به 37.300 · و186 حبة × 200.538جم ≈ 37.300 — نستعمل سطراً
      // يُفسِّر الوزن بالكامل بدل حسابٍ تقريبي.
      final ValidatedSackLine full = (resolveSackLine(
        SackLineInput(
          itemId: itemA,
          itemName: 'بطوة',
          nature: ItemNature.countBased,
          unit: ItemUnit.piece,
          quantity: 100,
          lineTotalWeight: WeightKg(45 - 6.5 - 1.2).kilograms,
        ),
      ) as Success<ValidatedSackLine>)
          .value;

      expect(
        rejectionOf(
          planSack(
            request(stored: storedSack(lines: <ValidatedSackLine>[full])),
            SackOperation.confirmSackLostWeight,
          ),
        ),
        CallableError.invalidArgument,
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('★★★ ADR-0007 — الاسم المركّب مفتاحُ الرصيد', () {
    test('★★ FR-M7-16: السطر يدخل الدفتر باسمه المركّب لا بمعرّفه', () {
      final SackAccepted plan = accept(
        planSack(
          request(
            stored: storedSack(),
            lines: <ValidatedSackLine>[line()],
            reason: 'إدخال الأنواع',
          ),
          SackOperation.enterSackLines,
        ),
      );
      final InventoryWrite movement =
          writesIn(plan, inventoryLedgerCollection).single;
      expect(movement.fields['itemKey'], 'بطوة - $supplierName - جونية رقم 1');
      // ⛔ **ولا يدخل بمعرّف النوع** — وهو الفارق البنيوي عن `M6`.
      expect(movement.fields['itemKey'], isNot(itemA));
      expect(movement.fields['sackId'], docNumber);
    });

    test('★★ والكمية حبّاتٌ لا وزن — GR-19', () {
      final SackAccepted plan = accept(
        planSack(
          request(
            stored: storedSack(),
            lines: <ValidatedSackLine>[line(quantity: 100)],
            reason: 'إدخال الأنواع',
          ),
          SackOperation.enterSackLines,
        ),
      );
      final InventoryWrite movement =
          writesIn(plan, inventoryLedgerCollection).single;
      expect(movement.fields['quantity'], 100);
      expect(movement.fields['unit'], ItemUnit.piece.name);
      // ★ **ووزن السطر بيانٌ تفسيري لا رصيد.**
      expect(movement.fields['lineTotalWeight'], isNotNull);
    });

    test('⛔★★ E-07: سطورٌ تتجاوز المطالب به تُرفَض بـERR_INTAKE_004', () {
      expect(
        rejectionOf(
          planSack(
            request(
              stored: storedSack(),
              // 500 حبة × 200جم = 100.000 كجم · والمطالب به 37.300.
              lines: <ValidatedSackLine>[line(quantity: 500)],
              reason: 'إدخال الأنواع',
            ),
            SackOperation.enterSackLines,
          ),
        ),
        CallableError.sackWeightExceeded,
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('الإلغاء — ★ بالوسم ⛔ بلا حذف ولا حركة عكسية', () {
    test('★★ GR-06: الإلغاء يَسِم المستند وكل حركاته', () {
      final String key = 'بطوة - $supplierName - جونية رقم 1';
      final SackAccepted plan = accept(
        planSack(
          request(
            stored: storedSack(lines: <ValidatedSackLine>[line()]),
            ledger: <String, List<LedgerRead>>{
              key: <LedgerRead>[
                LedgerRead(
                  movementId: stockMovementId(
                    documentNumber: docNumber,
                    itemKey: key,
                  ),
                  movement: StockMovement(
                    itemKey: key,
                    direction: MovementDirection.incoming,
                    quantity: const PieceQuantity(PieceCount(100)),
                    isCancelled: false,
                  ),
                ),
              ],
            },
            reason: 'إدخال خاطئ',
          ),
          SackOperation.cancelSack,
        ),
      );

      expect(
        writeIn(plan, sacksCollection).fields['status'],
        SackStatus.cancelled.name,
      );
      expect(
        writesIn(plan, inventoryLedgerCollection).single.fields['isCancelled'],
        isTrue,
      );
      // ★ **والفعل مستقل في المعجم** — ⛔ لا «تعديل».
      expect(plan.entry.action, AuditAction.cancel);
    });

    test('⛔ ERR_AMEND_006: الملغاة لا تُعدَّل ولا تُلغى ثانيةً', () {
      expect(
        rejectionOf(
          planSack(
            request(
              stored: storedSack(status: SackStatus.cancelled),
              reason: 'مرة أخرى',
            ),
            SackOperation.cancelSack,
          ),
        ),
        CallableError.documentCancelled,
      );
    });

    test('⛔ ولا مسار حذف في هذا الملف أصلاً — GR-07', () {
      // ★ **حارسٌ بنيوي:** أي عملية تحمل معنى الحذف تُسقِط هذا الاختبار.
      expect(
        SackOperation.values.map((SackOperation o) => o.name),
        isNot(anyElement(contains('delete'))),
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('المصدر والرعوي', () {
    test('⛔ ERR_DIST_003: مصدرٌ معطَّل يمنع التوريد الجديد', () {
      expect(
        rejectionOf(
          planSack(
            request(
              sack: intake(),
              dailySequence: sequence,
              sourceActive: false,
            ),
            SackOperation.createSack,
          ),
        ),
        CallableError.sourceInactive,
      );
    });

    test('★ والإلغاء يبقى ممكناً على مصدرٍ عُطِّل — فلا تُحبَس مستنداته', () {
      expect(
        planSack(
          request(
            stored: storedSack(),
            sourceActive: false,
            reason: 'إلغاء',
          ),
          SackOperation.cancelSack,
        ),
        isA<SackAccepted>(),
      );
    });

    test('⛔ ومصدرٌ لم يُقرأ ⟵ رفضٌ داخلي — الرفض هو الافتراض الآمن', () {
      expect(
        rejectionOf(
          planSack(
            request(
              sack: intake(),
              dailySequence: sequence,
              sourceMissing: true,
            ),
            SackOperation.createSack,
          ),
        ),
        CallableError.internal,
      );
    });

    test('⛔ FR-M3-09: رعويٌّ لا ينتمي للمصدر يُرفَض', () {
      expect(
        rejectionOf(
          planSack(
            request(
              sack: intake(),
              dailySequence: sequence,
              supplierSources: const <String>[sourceB],
            ),
            SackOperation.createSack,
          ),
        ),
        CallableError.supplierRequired,
      );
    });

    test('⛔★★ ورعويٌّ بلا اسمٍ مقروء يُرفَض — فالاسم جزءٌ من مفتاح الرصيد', () {
      final SackPlan plan = planSack(
        SackRequest(
          actor: account(),
          requestId: 'req-1',
          sourceId: sourceA,
          documentNumber: docNumber,
          stockDate: day,
          dailySequence: sequence,
          intake: intake(),
          storedSource: const <String, Object?>{
            'name': 'رداع',
            'isActive': true,
          },
          storedSupplierSourceIds: const <String>[sourceA],
          // ⛔ بلا اسم.
          scrapItemId: scrapId,
        ),
        SackOperation.createSack,
      );
      expect(rejectionOf(plan), CallableError.internal);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('★ قابلية التكرار — coding-standards §2.7', () {
    test('نفس الطلب يُنتج نفس الخطة حرفياً', () {
      SackAccepted planned() => accept(
            planSack(
              request(sack: intake(), dailySequence: sequence),
              SackOperation.createSack,
            ),
          );
      final SackAccepted first = planned();
      final SackAccepted second = planned();
      expect(first.writes.length, second.writes.length);
      for (int i = 0; i < first.writes.length; i++) {
        expect(first.writes[i].documentId, second.writes[i].documentId);
        expect(
          first.writes[i].fields.keys.toList(),
          second.writes[i].fields.keys.toList(),
        );
      }
      expect(first.entry.id, second.entry.id);
    });

    test('★★ والقيد يحمل الكيان والمصدر — فيُفلتَر السجل بالنطاق', () {
      final SackAccepted plan = accept(
        planSack(
          request(sack: intake(), dailySequence: sequence),
          SackOperation.createSack,
        ),
      );
      expect(plan.entry.target.entityType, sackEntityType);
      expect(plan.entry.target.entityId, docNumber);
      expect(plan.entry.target.sourceId, sourceA);
      expect(plan.entry.action, AuditAction.create);
    });

    test(
      '⛔⛔★★★ DEBT-35: قيدُ الجونية **يُرمَّز فعلاً** — ⛔ ولا `500` خام',
      () {
        // ★★★ **اختبارُ ارتدادٍ لعطلٍ حقيقي رُصد على المحاكي (2026-08-26):**
        //    كان القيد **يُسطِّح `DecimalValue` إلى `double` خام**، ⟵ **ثم
        //    يُرمِّزه `_auditWrite` فيرفضه المُرمِّز** (`ADR-0015`) ⟹ ⛔ **كلُّ
        //    إنشاء جونية يسقط بـ`500` بلا رمز كتالوج** — ★ **والزيادة كلها
        //    معطَّلة من طرف إلى طرف.**
        //
        // ⚠️⚠️ **ولم يكشفه اختبارٌ قائم:** ★ **الاختبار السابق كان يؤكّد
        //    التسطيح نفسه** (`expect(valuesAfter['totalWeight'], 45.0)`)
        //    ⛔ **ولا واحدَ يُمرِّر القيد بالمُرمِّز** — ⟵ **فكان يحرس العطل
        //    لا يمنعه.** ★★ **وهو درسُ `DEBT-33` حرفياً.**
        final SackAccepted plan = accept(
          planSack(
            request(sack: intake(), dailySequence: sequence),
            SackOperation.createSack,
          ),
        );

        // ⛔ **الفحص الحقيقي: الترميز نفسه** — لا شكلُ القيمة.
        expect(
          () => encodeFirestoreFields(plan.entry.toFields()),
          returnsNormally,
        );
        // ★ **والمخزَّن رقمٌ عادي** — ⟵ **فالغايةُ المكتوبة متحققة:**
        //   القيد يُقرأ رقماً، ⛔ **ولا يحمل نوعَ ترميزٍ في القاعدة.**
        final Map<String, Object?> encoded =
            encodeFirestoreFields(plan.entry.toFields());
        final Map<String, Object?> after =
            (encoded['valuesAfter']! as Map<String, Object?>)['mapValue']!
                as Map<String, Object?>;
        final Map<String, Object?> fields =
            after['fields']! as Map<String, Object?>;
        expect(fields['totalWeight'], <String, Object?>{'doubleValue': 45.0});
      },
    );
  });
}

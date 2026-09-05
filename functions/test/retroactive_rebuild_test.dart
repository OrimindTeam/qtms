import 'package:qtms_domain/qtms_domain.dart';
import 'package:qtms_functions/src/aged_remainder.dart';
import 'package:qtms_functions/src/audited_transaction.dart' show PendingDocument;
import 'package:qtms_functions/src/callable.dart';
import 'package:qtms_functions/src/firestore_value.dart' show DecimalValue;
import 'package:qtms_functions/src/firestore_writer.dart';
import 'package:qtms_functions/src/identity_claims.dart';
import 'package:qtms_functions/src/identity_gateway.dart';
import 'package:qtms_functions/src/retroactive_rebuild.dart';
import 'package:test/test.dart';

/// معرّف المالك المسجَّل في هذه الاختبارات — يحاكي `QTMS_OWNER_UID`.
const String ownerUid = 'uid-owner';

/// يومُ المنصّة في هذه الاختبارات — ★ **ثابتٌ مقيسٌ لا `DateTime.now()`**.
final CalendarDay today = CalendarDay(2026, 9, 5);

/// حساب مُعدّ للاختبار — ⛔ بلا أي اتصال بخدمة المصادقة.
AccountRecord account({
  required String userId,
  Set<Permission> permissions = const <Permission>{},
  bool disabled = false,
}) =>
    AccountRecord(
      userId: userId,
      userName: 'المالك',
      claims: IdentityClaims(permissions: permissions, sourceScope: null),
      disabled: disabled,
      cardIsActive: true,
    );

RetroactiveRebuildRequest request({
  AccountRecord? actor,
  String registeredOwner = ownerUid,
  String requestId = 'REQ-RBLD-0001',
  String date = '20260830',
  CalendarDay? platformToday,
  List<String>? sourceIds,
  bool clearToday = false,
}) =>
    RetroactiveRebuildRequest(
      actor: actor ?? account(userId: ownerUid),
      registeredOwnerUserId: registeredOwner,
      requestId: requestId,
      date: date,
      platformToday: clearToday ? null : (platformToday ?? today),
      sourceIds: sourceIds,
    );

CallableError? rejectionOf(RetroactiveRebuildPlan plan) =>
    plan is RetroactiveRebuildRejected ? plan.error : null;

RetroactiveRebuildAccepted acceptedOf(RetroactiveRebuildPlan plan) =>
    plan as RetroactiveRebuildAccepted;

/// مستندُ رصيدٍ مقروءٌ كما تكتبه `_balanceWrite` حرفياً — ⛔ لا شكلٌ مخترَع.
StoredDocument balance({
  String sourceId = 'SRC-001',
  String itemKey = 'ITM-01|جونية 3',
  String itemName = 'جونية 3',
  CalendarDay? stockDate,
  Object balanceValue = 12,
}) {
  final CalendarDay day = stockDate ?? CalendarDay(2026, 8, 30);
  return StoredDocument(
    id: itemDailyBalanceId(
      sourceId: sourceId,
      itemKey: itemKey,
      stockDate: day,
    ),
    fields: <String, Object?>{
      'sourceId': sourceId,
      'itemKey': itemKey,
      'itemName': itemName,
      'stockDate': day.asUtcMidnight(),
      'unit': ItemUnit.piece.name,
      'incoming': 20,
      'outgoing': 8,
      'balance': balanceValue,
    },
  );
}

void main() {
  group('★★★ التفويض — هويةُ المالك المسجَّل وحدها (⛔ لا مفتاح كتالوج)', () {
    test('★ المالك المسجَّل يُقبَل — ولو بلا مفتاحٍ واحدٍ في بطاقته', () {
      // ⚠️ **وهذا ليس تساهلاً:** `permissions-catalog.md` §3 يُدرِج «كتابةَ
      //    الأرصدة والملخصات» في **ما ليس صلاحية** — ⟵ **فلا مفتاحَ يُفحَص**،
      //    ★ **واختلاقُ واحدٍ مخالفةُ §6 من الكتالوج.**
      expect(
        planRetroactiveRebuild(request()),
        isA<RetroactiveRebuildAccepted>(),
      );
    });

    test('⛔ ومَن ليس المالكَ المسجَّل يُرفَض ولو ملك كل صلاحيات النظام', () {
      final RetroactiveRebuildPlan plan = planRetroactiveRebuild(
        request(
          actor: account(
            userId: 'uid-someone-else',
            permissions: Permission.values.toSet(),
          ),
        ),
      );
      expect(rejectionOf(plan), CallableError.permissionMissing);
    });

    test('⛔ ومالكٌ معطَّل يُرفَض قبل أي فحصٍ آخر — التعطيل فوريٌّ نافذ', () {
      final RetroactiveRebuildPlan plan = planRetroactiveRebuild(
        request(actor: account(userId: ownerUid, disabled: true)),
      );
      expect(rejectionOf(plan), CallableError.accountDisabled);
    });

    test('⛔ ومعرّفُ مالكٍ غائبٌ من البيئة يُرفَض — ولا يُخمَّن مالك', () {
      // ⚠️ **الفخُّ الذي يحرسه هذا:** `registeredOwnerUserId` فارغاً مع
      //    `actor.userId` فارغاً كان سيتساويان — ⟵ **فيُقبَل أيُّ مجهول.**
      final RetroactiveRebuildPlan plan = planRetroactiveRebuild(
        request(registeredOwner: '   '),
      );
      expect(rejectionOf(plan), CallableError.permissionMissing);
    });
  });

  group('★★ اليوم المستهدَف — ⛔ ولا يومَ يُخمَّن', () {
    test('⛔ يومٌ مشوَّه يُرفَض طلباً غيرَ صالح', () {
      expect(
        rejectionOf(planRetroactiveRebuild(request(date: '2026-08-30'))),
        CallableError.invalidArgument,
      );
      expect(
        rejectionOf(planRetroactiveRebuild(request(date: '20260231'))),
        CallableError.invalidArgument,
      );
      expect(
        rejectionOf(planRetroactiveRebuild(request(date: ''))),
        CallableError.invalidArgument,
      );
    });

    test('⛔⛔ ويومٌ مستقبليٌّ مرفوضٌ مطلقاً — ★ ولا مفتاحَ يفتحه', () {
      expect(
        rejectionOf(planRetroactiveRebuild(request(date: '20260906'))),
        CallableError.futureDateRejected,
      );
    });

    test('✅ ويومُ المنصّة نفسُه مقبولٌ — ★ وبناءٌ غيرُ رجعي', () {
      final RetroactiveRebuildAccepted plan =
          acceptedOf(planRetroactiveRebuild(request(date: '20260905')));
      expect(plan.date, today);
      // ★★ **الوسمُ يُشتقّ من المقارنة** — ⛔ **ولا حقلَ يطلبه المُستدعي.**
      expect(plan.date.compareTo(plan.today) < 0, isFalse);
    });

    test('✅ ويومٌ ماضٍ مقبولٌ — ★ وهو حالةُ «⟳ مُحدَّث بأثر رجعي»', () {
      final RetroactiveRebuildAccepted plan =
          acceptedOf(planRetroactiveRebuild(request(date: '20260830')));
      expect(plan.date.compareTo(plan.today) < 0, isTrue);
    });

    test('⛔★★★ وتعذّرُ قياس ساعة المنصّة رفضٌ — ⛔ ولا ساعةَ حاوية بديلة', () {
      // ⚠️⚠️ **وهذا حارسُ `GR-54` هنا:** ⟵ **حاويةٌ منزاحةُ الساعة كانت
      //    ستَسِم بطاقةَ اليوم الجاري رجعيةً** — ★ **رقمٌ خاطئٌ بصمت.**
      expect(
        rejectionOf(planRetroactiveRebuild(request(clearToday: true))),
        CallableError.internal,
      );
    });
  });

  group('★★ المصادر — ⛔ والفارغةُ ليست «الكل»', () {
    test('★ غيابُ الحقل يعني كلَّ المصادر — تُقرأ في المنفّذ لا هنا', () {
      expect(acceptedOf(planRetroactiveRebuild(request())).sourceIds, isNull);
    });

    test('⛔⛔ وقائمةٌ فارغة تُرفَض — ⛔ ولا تُوسَّع إلى «الكل»', () {
      // ⚠️ **الفخُّ الذي يحرسه هذا:** خطأٌ مطبعيٌّ في أداةٍ يُرسِل `[]`،
      //    ⟵ **وطيُّه في «الكل» يُعيد بناءَ النظام كلِّه بلا طلب.**
      expect(
        rejectionOf(planRetroactiveRebuild(request(sourceIds: <String>[]))),
        CallableError.invalidArgument,
      );
    });

    test('⛔ ومصدرٌ فارغُ الاسم يُرفَض — ⛔ ولا يُتخطّى صامتاً', () {
      expect(
        rejectionOf(
          planRetroactiveRebuild(request(sourceIds: <String>['SRC-001', ' '])),
        ),
        CallableError.invalidArgument,
      );
    });

    test('★ والمكرَّرُ يُطوى مرةً واحدة — ⛔ فلا يُبنى مصدرٌ مرتين', () {
      final RetroactiveRebuildAccepted plan = acceptedOf(
        planRetroactiveRebuild(
          request(sourceIds: <String>['SRC-001', ' SRC-001 ', 'SRC-002']),
        ),
      );
      expect(plan.sourceIds, <String>['SRC-001', 'SRC-002']);
    });
  });

  group('★★★ مسحةُ المتبقي المتأخر — علاج `DEBT-96`', () {
    test('★ رصيدٌ موجبٌ يُنتج بندَه بمعرّفٍ حتمي', () {
      final AgedRemainderSet set =
          agedRemaindersFromStoredBalances(<StoredDocument>[balance()]);
      expect(set.documents, hasLength(1));
      final PendingDocument document = set.documents.single;
      expect(document.collectionId, agedRemaindersCollection);
      expect(
        document.documentId,
        agedRemainderId(
          sourceId: 'SRC-001',
          itemKey: 'ITM-01|جونية 3',
          stockDate: CalendarDay(2026, 8, 30),
        ),
      );
      expect(document.fields['remaining'], 12);
      expect(document.fields['sourceId'], 'SRC-001');
      // ★★ **تاريخ المخزون لا تاريخ الإدخال** — `RISK-07`.
      expect(document.fields['stockDate'], DateTime.utc(2026, 8, 30));
    });

    test('⛔ ورصيدٌ صفرٌ أو سالب لا يُكتب له بند', () {
      expect(
        agedRemaindersFromStoredBalances(<StoredDocument>[
          balance(balanceValue: 0),
          balance(itemKey: 'ITM-02|قات', balanceValue: -3),
        ]).documents,
        isEmpty,
      );
    });

    test('★★ والتشغيلُ مرتين يُنتج نفس المعرّفات — ★ قابليةُ التكرار', () {
      // ⚠️⚠️ **وهذا شرطُ صحةٍ لا تحسين** (`api-overview.md` §3.3): ⟵ **بندٌ
      //    يُكتب بمعرّفٍ جديدٍ في كل تشغيل كان سيُضاعف قائمةَ التنبيه.**
      final List<StoredDocument> rows = <StoredDocument>[
        balance(),
        balance(itemKey: 'ITM-02|قات', itemName: 'قات', balanceValue: 4),
      ];
      List<String> idsOf(AgedRemainderSet set) => <String>[
            for (final PendingDocument document in set.documents)
              document.documentId,
          ];
      expect(
        idsOf(agedRemaindersFromStoredBalances(rows)),
        idsOf(agedRemaindersFromStoredBalances(rows)),
      );
    });

    test('⛔⛔★★★ ورصيدٌ وزنيٌّ يعود في `DecimalValue` — ★ عطلٌ رصده التشغيل الحيّ',
        () {
      // ⚠️⚠️★★★ **مقيسٌ لا مفترَض (2026-09-05):** ★ **مسحةُ 2026-08-30 على
      //    التجريبية ردّت** «`الفاصلة العائمة مرفوضة … 10.0`» ⟵ **فأسقطت
      //    `SRC-001` في أربعة أيامٍ من عشرة** (**أيامُ السكرب وحدها**).
      // ★★ **والسببُ لا-تماثلٌ مقصود:** **الكاتبُ يُغلِّف الكسر**
      //    (`ADR-0015` القاعدة 9) **والقارئُ يفكُّه `double` عارياً** —
      //    ⟵ **وهذا المسارُ أولُ من يقرأ ثم يكتب القيمة نفسَها.**
      final PendingDocument document = agedRemaindersFromStoredBalances(
        <StoredDocument>[
          balance(
            itemKey: 'السكرب - جونية رقم 1',
            itemName: 'السكرب - جونية رقم 1',
            balanceValue: 10.0,
          ),
        ],
      ).documents.single;
      // ★ **يعود إلى الغلاف الذي كُتب به** — ⛔ **بلا تقريبٍ يفقد الكسر.**
      expect(document.fields['remaining'], DecimalValue(10));
    });

    test('★ والكسرُ غيرُ الصحيح يُلَفّ كذلك — ⛔ ولا يُقرَّب إلى صفر', () {
      final PendingDocument document = agedRemaindersFromStoredBalances(
        <StoredDocument>[balance(balanceValue: 0.7)],
      ).documents.single;
      expect(document.fields['remaining'], DecimalValue(0.7));
    });

    test('⛔⛔ والصحيحُ يبقى `int` — ★ فرصيدُ الحبّة لا يُكتب عشرياً', () {
      // ⚠️ **`ADR-0015`:** ⛔ **ولفُّ عددٍ صحيحٍ كان سيكتب الحبّةَ كسراً.**
      final PendingDocument document = agedRemaindersFromStoredBalances(
        <StoredDocument>[balance()],
      ).documents.single;
      expect(document.fields['remaining'], 12);
      expect(document.fields['remaining'], isA<int>());
    });

    test('⛔ ومستندُ رصيدٍ مشوَّه يُتخطّى ولا يُسقِط المسحة', () {
      // ★ **الراصدُ ينبّه ولا يمنع** (`aged_remainder.dart` §الترويسة) —
      //   ⟵ **فمستندٌ ناقصُ الحقول لا يُوقف بقيةَ اليوم.**
      final AgedRemainderSet set =
          agedRemaindersFromStoredBalances(<StoredDocument>[
        const StoredDocument(id: 'broken', fields: <String, Object?>{}),
        balance(),
      ]);
      expect(set.documents, hasLength(1));
    });
  });
}

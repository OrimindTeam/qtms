import 'package:qtms_domain/qtms_domain.dart';
import 'package:test/test.dart';

const String _dealer = 'DLR-0001';
const String _source = 'SRC-001';
const String _other = 'SRC-002';

CalendarDay _day(int y, int m, int d) => CalendarDay(y, m, d);

/// ★ معرّفُ ضمارٍ بعقده المعتمد — `{dealerId}_{sourceId}_{stockDate}`.
String _lot(CalendarDay stockDate, {String source = _source}) =>
    distributionId(dealerId: _dealer, sourceId: source, stockDate: stockDate);

DealerLedgerRowCard _row({
  required String entryId,
  required DealerLedgerDirection direction,
  required int amount,
  required DealerLedgerEntryType? type,
  String? lotId,
  String sourceId = _source,
  DateTime? at,
  bool cancelled = false,
  String? docNumber,
  DateTime? amendedAt,
  String? amendedBy,
}) =>
    DealerLedgerRowCard(
      entryId: entryId,
      dealerId: _dealer,
      sourceId: sourceId,
      direction: direction,
      entryType: type,
      amount: Money(amount),
      isCancelled: cancelled,
      entryDate: at,
      debtLotId: lotId,
      sourceDocNumber: docNumber,
      lastAmendedAt: amendedAt,
      amendedBy: amendedBy,
    );

void main() {
  group('debtLotStockDate — الاشتقاق من المعرّف لا من قراءةٍ ثانية', () {
    test('★ يشتقّ يومَ الضمار من معرّفه المعتمد', () {
      expect(debtLotStockDate(_lot(_day(2026, 9, 1))), _day(2026, 9, 1));
    });

    test('⛔ ومعرّفٌ لا يطابق العقد يُرجِع null ولا يُخمَّن يومُه', () {
      expect(debtLotStockDate('معرّف-قديم-بلا-تاريخ'), isNull);
      expect(debtLotStockDate('DLR_SRC_'), isNull);
      expect(debtLotStockDate('DLR_SRC_20261332'), isNull);
    });
  });

  group('debtAgeBucketOf — FR-M17-07 بحدوده المنصوصة', () {
    test('الحدودُ الأربعة عند أطرافها بالضبط', () {
      expect(debtAgeBucketOf(0), DebtAgeBucket.upToSeven);
      expect(debtAgeBucketOf(7), DebtAgeBucket.upToSeven);
      expect(debtAgeBucketOf(8), DebtAgeBucket.upToFifteen);
      expect(debtAgeBucketOf(15), DebtAgeBucket.upToFifteen);
      expect(debtAgeBucketOf(16), DebtAgeBucket.upToThirty);
      expect(debtAgeBucketOf(30), DebtAgeBucket.upToThirty);
      expect(debtAgeBucketOf(31), DebtAgeBucket.overThirty);
    });

    test('★ والسالبُ يقع في الأولى — ⛔ لا شريحةٌ خامسة', () {
      expect(debtAgeBucketOf(-3), DebtAgeBucket.upToSeven);
    });
  });

  group('buildDealerStatement — FR-M17-03 يُبنى من الدفتر حصراً', () {
    test('★★ الرصيدُ = المدين − الدائن، والرصيدُ الجاري مشتقٌّ لا مقروء', () {
      final CalendarDay lotDay = _day(2026, 9, 1);
      final DealerStatement statement = buildDealerStatement(
        dealerName: 'فلان',
        sourceIds: const <String>[_source],
        issuedOn: _day(2026, 9, 4),
        ledger: <DealerLedgerRowCard>[
          _row(
            entryId: 'E1',
            direction: DealerLedgerDirection.debit,
            amount: 50000,
            type: DealerLedgerEntryType.debt,
            lotId: _lot(lotDay),
            at: DateTime.utc(2026, 9, 1),
          ),
          _row(
            entryId: 'E2',
            direction: DealerLedgerDirection.credit,
            amount: 200,
            type: DealerLedgerEntryType.receipt,
            lotId: _lot(lotDay),
            at: DateTime.utc(2026, 9, 2),
          ),
        ],
      );

      expect(statement.totalDebit, const Money(50000));
      expect(statement.totalCredit, const Money(200));
      expect(statement.balance, const Money(49800));
      // ★★ **والرصيدُ الختامي هو رصيدُ آخر حركة** — `DEBT-75`.
      expect(statement.entries.last.runningBalance, const Money(49800));
      expect(statement.entries.first.runningBalance, const Money(50000));
    });

    test('⛔⛔ الملغاةُ تُعرَض ولا تدخل رقماً واحداً — FR-M17-06', () {
      final CalendarDay lotDay = _day(2026, 9, 1);
      final DealerStatement statement = buildDealerStatement(
        dealerName: 'فلان',
        sourceIds: const <String>[_source],
        issuedOn: _day(2026, 9, 4),
        ledger: <DealerLedgerRowCard>[
          _row(
            entryId: 'E1',
            direction: DealerLedgerDirection.debit,
            amount: 10000,
            type: DealerLedgerEntryType.debt,
            lotId: _lot(lotDay),
            at: DateTime.utc(2026, 9, 1),
          ),
          _row(
            entryId: 'E2',
            direction: DealerLedgerDirection.credit,
            amount: 4000,
            type: DealerLedgerEntryType.receipt,
            lotId: _lot(lotDay),
            at: DateTime.utc(2026, 9, 2),
            cancelled: true,
          ),
        ],
      );

      // ★ **معروضةٌ** — ⛔ **ولا محذوفة.**
      expect(statement.entries, hasLength(2));
      expect(statement.entries.last.isCancelled, isTrue);
      // ⛔ **ولا تدخل الرصيد** — ★ **ورصيدُها هو رصيدُ ما قبلها.**
      expect(statement.totalCredit, Money.zero);
      expect(statement.balance, const Money(10000));
      expect(statement.entries.last.runningBalance, const Money(10000));
      // ⛔ **ولا تُنقِص من الضمار.**
      expect(statement.lots.single.settled, Money.zero);
      expect(statement.lots.single.remaining, const Money(10000));
    });

    test('★★ حالةُ الضمار الثلاثية — settlement-design §3', () {
      DealerStatement build(int settled, int discounted) =>
          buildDealerStatement(
            dealerName: 'فلان',
            sourceIds: const <String>[_source],
            issuedOn: _day(2026, 9, 4),
            ledger: <DealerLedgerRowCard>[
              _row(
                entryId: 'E1',
                direction: DealerLedgerDirection.debit,
                amount: 1000,
                type: DealerLedgerEntryType.debt,
                lotId: _lot(_day(2026, 9, 1)),
                at: DateTime.utc(2026, 9, 1),
              ),
              if (settled > 0)
                _row(
                  entryId: 'E2',
                  direction: DealerLedgerDirection.credit,
                  amount: settled,
                  type: DealerLedgerEntryType.receipt,
                  lotId: _lot(_day(2026, 9, 1)),
                  at: DateTime.utc(2026, 9, 2),
                ),
              if (discounted > 0)
                _row(
                  entryId: 'E3',
                  direction: DealerLedgerDirection.credit,
                  amount: discounted,
                  type: DealerLedgerEntryType.discount,
                  lotId: _lot(_day(2026, 9, 1)),
                  at: DateTime.utc(2026, 9, 3),
                ),
            ],
          );

      expect(build(0, 0).lots.single.status, DebtLotStatus.open);
      expect(build(400, 0).lots.single.status, DebtLotStatus.partiallyOpen);
      expect(build(600, 400).lots.single.status, DebtLotStatus.closed);
      // ★ **والخصمُ خانةٌ مستقلة عن المسدَّد** — `GR-41` · `M13`.
      expect(build(600, 400).lots.single.settled, const Money(600));
      expect(build(600, 400).lots.single.discounted, const Money(400));
    });

    test('★ وتطبيقُ الفائض يُسدِّد الضمار — نوعٌ مستقلٌّ عن القبض', () {
      final DealerStatement statement = buildDealerStatement(
        dealerName: 'فلان',
        sourceIds: const <String>[_source],
        issuedOn: _day(2026, 9, 4),
        ledger: <DealerLedgerRowCard>[
          _row(
            entryId: 'E1',
            direction: DealerLedgerDirection.debit,
            amount: 1000,
            type: DealerLedgerEntryType.debt,
            lotId: _lot(_day(2026, 9, 1)),
            at: DateTime.utc(2026, 9, 1),
          ),
          _row(
            entryId: 'E2',
            direction: DealerLedgerDirection.credit,
            amount: 1000,
            type: DealerLedgerEntryType.surplusApplication,
            lotId: _lot(_day(2026, 9, 1)),
            at: DateTime.utc(2026, 9, 2),
          ),
        ],
      );
      expect(statement.lots.single.status, DebtLotStatus.closed);
      expect(statement.lots.single.settled, const Money(1000));
    });

    test('⛔⛔ ونوعٌ لا يعرفه الإصدار لا يُنسَب لخانةٍ بالتخمين', () {
      final DealerStatement statement = buildDealerStatement(
        dealerName: 'فلان',
        sourceIds: const <String>[_source],
        issuedOn: _day(2026, 9, 4),
        ledger: <DealerLedgerRowCard>[
          _row(
            entryId: 'E1',
            direction: DealerLedgerDirection.debit,
            amount: 1000,
            type: DealerLedgerEntryType.debt,
            lotId: _lot(_day(2026, 9, 1)),
            at: DateTime.utc(2026, 9, 1),
          ),
          _row(
            entryId: 'E2',
            direction: DealerLedgerDirection.credit,
            amount: 300,
            type: null, // ★ نوعٌ من إصدارٍ أحدث.
            lotId: _lot(_day(2026, 9, 1)),
            at: DateTime.utc(2026, 9, 2),
          ),
        ],
      );
      // ★ **يدخل الرصيدَ لأن اتجاهه معروف** — ⛔ **ولا يُنسَب لخانةِ ضمار.**
      expect(statement.totalCredit, const Money(300));
      expect(statement.lots.single.settled, Money.zero);
      expect(statement.lots.single.discounted, Money.zero);
      expect(dealerLedgerEntryTypeLabel(null), 'نوع غير معروف');
    });

    test('★★ الأعمارُ بالمتبقي على الضمارات المفتوحة — FR-M17-07', () {
      final DealerStatement statement = buildDealerStatement(
        dealerName: 'فلان',
        sourceIds: const <String>[_source],
        issuedOn: _day(2026, 9, 30),
        ledger: <DealerLedgerRowCard>[
          // عمرُه 29 يوماً ⟵ الشريحة الثالثة.
          _row(
            entryId: 'E1',
            direction: DealerLedgerDirection.debit,
            amount: 1000,
            type: DealerLedgerEntryType.debt,
            lotId: _lot(_day(2026, 9, 1)),
            at: DateTime.utc(2026, 9, 1),
          ),
          // عمرُه 5 أيام ⟵ الشريحة الأولى.
          _row(
            entryId: 'E2',
            direction: DealerLedgerDirection.debit,
            amount: 700,
            type: DealerLedgerEntryType.debt,
            lotId: _lot(_day(2026, 9, 25)),
            at: DateTime.utc(2026, 9, 25),
          ),
          // ★ ضمارٌ مُصفّى ⟵ ⛔ **لا يدخل الأعمار.**
          _row(
            entryId: 'E3',
            direction: DealerLedgerDirection.debit,
            amount: 500,
            type: DealerLedgerEntryType.debt,
            lotId: _lot(_day(2026, 9, 20)),
            at: DateTime.utc(2026, 9, 20),
          ),
          _row(
            entryId: 'E4',
            direction: DealerLedgerDirection.credit,
            amount: 500,
            type: DealerLedgerEntryType.receipt,
            lotId: _lot(_day(2026, 9, 20)),
            at: DateTime.utc(2026, 9, 21),
          ),
        ],
      );

      expect(statement.aging[DebtAgeBucket.upToSeven], const Money(700));
      expect(statement.aging[DebtAgeBucket.upToFifteen], Money.zero);
      expect(statement.aging[DebtAgeBucket.upToThirty], const Money(1000));
      expect(statement.aging[DebtAgeBucket.overThirty], Money.zero);
      expect(statement.openRemaining, const Money(1700));
      expect(statement.lotsWithoutAge, isEmpty);
    });

    test('⛔ وضمارٌ بمعرّفٍ لا يُشتقّ يومُه يُعلَن ولا يُخمَّن عمرُه', () {
      final DealerStatement statement = buildDealerStatement(
        dealerName: 'فلان',
        sourceIds: const <String>[_source],
        issuedOn: _day(2026, 9, 30),
        ledger: <DealerLedgerRowCard>[
          _row(
            entryId: 'E1',
            direction: DealerLedgerDirection.debit,
            amount: 900,
            type: DealerLedgerEntryType.debt,
            lotId: 'ضمارٌ-قديمٌ-بلا-عقد',
            at: DateTime.utc(2026, 9, 1),
          ),
        ],
      );
      // ★ **باقٍ في الكشف وفي الرصيد** — ⛔ **وخارج الأعمار وحدها.**
      expect(statement.balance, const Money(900));
      expect(statement.lots, hasLength(1));
      expect(statement.lotsWithoutAge, hasLength(1));
      for (final Money bucket in statement.aging.values) {
        expect(bucket, Money.zero);
      }
    });

    test('★★ الفصلُ بالمصدر — كلُّ سطرٍ يُسمّي مصدرَه (FR-M17-04)', () {
      final DealerStatement statement = buildDealerStatement(
        dealerName: 'فلان',
        sourceIds: const <String>[_source, _other],
        issuedOn: _day(2026, 9, 4),
        ledger: <DealerLedgerRowCard>[
          _row(
            entryId: 'E1',
            direction: DealerLedgerDirection.debit,
            amount: 1000,
            type: DealerLedgerEntryType.debt,
            lotId: _lot(_day(2026, 9, 1)),
            at: DateTime.utc(2026, 9, 1),
          ),
          _row(
            entryId: 'E2',
            direction: DealerLedgerDirection.debit,
            amount: 2000,
            type: DealerLedgerEntryType.debt,
            lotId: _lot(_day(2026, 9, 1), source: _other),
            sourceId: _other,
            at: DateTime.utc(2026, 9, 2),
          ),
        ],
      );

      expect(statement.sourceIds, <String>[_source, _other]);
      expect(statement.lots.map((DealerStatementLot l) => l.sourceId),
          <String>[_source, _other]);
      // ★ **ضماران مستقلان** — ⛔ **ولا ضمارٌ موحّدٌ يُنشأ.**
      expect(statement.lots, hasLength(2));
    });

    // ⛔⛔★★ **رُصد على المحاكي (2026-09-04)** — ★ **كان كلُّ سطرِ ضمارٍ
    //    يعرض «بلا مستند» بينما الرقمُ في الدفتر**: ⟵ **وسطرٌ بلا سنده
    //    لا يُراجَع.**
    test('★★ رقمُ مستند الضمار من قيده المدين — ⛔ لا من قيد قبضٍ أو خصم', () {
      final DealerStatement statement = buildDealerStatement(
        dealerName: 'فلان',
        sourceIds: const <String>[_source],
        issuedOn: _day(2026, 9, 4),
        ledger: <DealerLedgerRowCard>[
          _row(
            entryId: 'E1',
            direction: DealerLedgerDirection.debit,
            amount: 1000,
            type: DealerLedgerEntryType.debt,
            lotId: _lot(_day(2026, 9, 1)),
            at: DateTime.utc(2026, 9, 1),
            docNumber: 'DST-20260901-0001',
          ),
          _row(
            entryId: 'E2',
            direction: DealerLedgerDirection.credit,
            amount: 400,
            type: DealerLedgerEntryType.receipt,
            lotId: _lot(_day(2026, 9, 1)),
            at: DateTime.utc(2026, 9, 2),
            docNumber: 'RCP-20260902-0007',
          ),
        ],
      );
      expect(statement.lots.single.documentNumber, 'DST-20260901-0001');
    });

    test('★ وضمارٌ بلا رقمٍ في قيده يبقى «بلا مستند» ⛔ ولا يُخترَع له رقم', () {
      final DealerStatement statement = buildDealerStatement(
        dealerName: 'فلان',
        sourceIds: const <String>[_source],
        issuedOn: _day(2026, 9, 4),
        ledger: <DealerLedgerRowCard>[
          _row(
            entryId: 'E1',
            direction: DealerLedgerDirection.debit,
            amount: 1000,
            type: DealerLedgerEntryType.debt,
            lotId: _lot(_day(2026, 9, 1)),
            at: DateTime.utc(2026, 9, 1),
          ),
        ],
      );
      expect(statement.lots.single.documentNumber, isNull);
    });

    test('★★ شارةُ «مُعدَّل» مقيسةٌ من الدفتر — FR-M17-05', () {
      final DealerStatement statement = buildDealerStatement(
        dealerName: 'فلان',
        sourceIds: const <String>[_source],
        issuedOn: _day(2026, 9, 4),
        ledger: <DealerLedgerRowCard>[
          _row(
            entryId: 'E1',
            direction: DealerLedgerDirection.debit,
            amount: 1000,
            type: DealerLedgerEntryType.debt,
            lotId: _lot(_day(2026, 9, 1)),
            at: DateTime.utc(2026, 9, 1),
            amendedAt: DateTime.utc(2026, 9, 3),
            amendedBy: 'USR-0007',
          ),
          _row(
            entryId: 'E2',
            direction: DealerLedgerDirection.credit,
            amount: 100,
            type: DealerLedgerEntryType.receipt,
            lotId: _lot(_day(2026, 9, 1)),
            at: DateTime.utc(2026, 9, 2),
          ),
        ],
      );
      final DealerStatementEntry amended = statement.entries
          .firstWhere((DealerStatementEntry e) => e.entryId == 'E1');
      expect(amended.isAmended, isTrue);
      expect(amended.amendedBy, 'USR-0007');
      expect(amended.lastAmendedAt, DateTime.utc(2026, 9, 3));
      // ⛔ **وغيرُ المعدَّلة لا تحمل الشارة** — ★ **وإلا صارت زينةً.**
      expect(
        statement.entries
            .firstWhere((DealerStatementEntry e) => e.entryId == 'E2')
            .isAmended,
        isFalse,
      );
    });

    test('★ والفائضُ بيانٌ يُعرَض ⛔ ولا يُطرح من الرصيد', () {
      final DealerStatement statement = buildDealerStatement(
        dealerName: 'فلان',
        sourceIds: const <String>[_source],
        issuedOn: _day(2026, 9, 4),
        availableSurplus: const Money(3000),
        ledger: <DealerLedgerRowCard>[
          _row(
            entryId: 'E1',
            direction: DealerLedgerDirection.debit,
            amount: 10000,
            type: DealerLedgerEntryType.debt,
            lotId: _lot(_day(2026, 9, 1)),
            at: DateTime.utc(2026, 9, 1),
          ),
        ],
      );
      expect(statement.availableSurplus, const Money(3000));
      expect(statement.balance, const Money(10000));
    });

    test('★ والرصيدُ بالكتابة العربية جزءٌ من الكشف — FR-M17-07', () {
      final DealerStatement statement = buildDealerStatement(
        dealerName: 'فلان',
        sourceIds: const <String>[_source],
        issuedOn: _day(2026, 9, 4),
        ledger: <DealerLedgerRowCard>[
          _row(
            entryId: 'E1',
            direction: DealerLedgerDirection.debit,
            amount: 49800,
            type: DealerLedgerEntryType.debt,
            lotId: _lot(_day(2026, 9, 1)),
            at: DateTime.utc(2026, 9, 1),
          ),
        ],
      );
      expect(statement.balanceInWords, 'تسعة وأربعون ألفاً وثمانمئة ريال');
    });

    test('★ وقيدٌ بلا طابعٍ يُؤخَّر ⛔ ولا يُقحَم في وسط السلسلة', () {
      final DealerStatement statement = buildDealerStatement(
        dealerName: 'فلان',
        sourceIds: const <String>[_source],
        issuedOn: _day(2026, 9, 4),
        ledger: <DealerLedgerRowCard>[
          _row(
            entryId: 'E-بلا-طابع',
            direction: DealerLedgerDirection.debit,
            amount: 100,
            type: DealerLedgerEntryType.debt,
            lotId: _lot(_day(2026, 9, 3)),
          ),
          _row(
            entryId: 'E1',
            direction: DealerLedgerDirection.debit,
            amount: 200,
            type: DealerLedgerEntryType.debt,
            lotId: _lot(_day(2026, 9, 1)),
            at: DateTime.utc(2026, 9, 1),
          ),
        ],
      );
      expect(statement.entries.first.entryId, 'E1');
      expect(statement.entries.last.entryId, 'E-بلا-طابع');
    });

    test('★ ودفترٌ فارغ يُنتج كشفاً بأصفارٍ صريحة ⛔ لا انهياراً', () {
      final DealerStatement statement = buildDealerStatement(
        dealerName: 'فلان',
        sourceIds: const <String>[_source],
        issuedOn: _day(2026, 9, 4),
        ledger: const <DealerLedgerRowCard>[],
      );
      expect(statement.balance, Money.zero);
      expect(statement.balanceInWords, 'صفر ريال');
      expect(statement.lots, isEmpty);
      expect(statement.entries, isEmpty);
      expect(statement.aging.values.every((Money m) => m.isZero), isTrue);
    });

    test('★ ومجموعاتُ الكشف غير قابلة للتعديل بعد البناء', () {
      final DealerStatement statement = buildDealerStatement(
        dealerName: 'فلان',
        sourceIds: const <String>[_source],
        issuedOn: _day(2026, 9, 4),
        ledger: const <DealerLedgerRowCard>[],
      );
      expect(() => statement.lots.add(
            const DealerStatementLot(
              debtLotId: 'x',
              sourceId: _source,
              value: Money.zero,
              settled: Money.zero,
              discounted: Money.zero,
              status: DebtLotStatus.open,
            ),
          ), throwsUnsupportedError);
      expect(() => statement.sourceIds.add('x'), throwsUnsupportedError);
    });
  });
}

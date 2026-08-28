import 'package:qtms_domain/qtms_domain.dart';
import 'package:test/test.dart';

/// حركة مختصرة للاختبار — ★ **بالحبّة ما لم يُذكر خلاف ذلك**.
StockMovement _in(int pieces, {bool cancelled = false}) => StockMovement(
      itemKey: 'ITM-0001',
      direction: MovementDirection.incoming,
      quantity: PieceQuantity(PieceCount(pieces)),
      isCancelled: cancelled,
    );

StockMovement _out(int pieces, {bool cancelled = false}) => StockMovement(
      itemKey: 'ITM-0001',
      direction: MovementDirection.outgoing,
      quantity: PieceQuantity(PieceCount(pieces)),
      isCancelled: cancelled,
    );

void main() {
  group('computeItemBalance — design-overview.md §2.1', () {
    test('رصيد النوع = Σ(الداخل) − Σ(الخارج)', () {
      final Outcome<StockQuantity> outcome = computeItemBalance(
        movements: <StockMovement>[_in(120), _in(30), _out(50)],
        unit: ItemUnit.piece,
      );
      expect(
        (outcome as Success<StockQuantity>).value,
        const PieceQuantity(PieceCount(100)),
      );
    });

    test('★ A-14: الحركة الملغاة لا تدخل أي جمع', () {
      final Outcome<StockQuantity> outcome = computeItemBalance(
        movements: <StockMovement>[_in(120), _out(50, cancelled: true)],
        unit: ItemUnit.piece,
      );
      expect(
        (outcome as Success<StockQuantity>).value,
        const PieceQuantity(PieceCount(120)),
      );
    });

    test('★ FR-M8-09: رصيد بداية أي يوم = 0 — ولا حركات يعني صفراً', () {
      final Outcome<StockQuantity> outcome = computeItemBalance(
        movements: const <StockMovement>[],
        unit: ItemUnit.piece,
      );
      expect(
        (outcome as Success<StockQuantity>).value,
        const PieceQuantity(PieceCount.zero),
      );
    });

    test('★★ GR-19 · E-31: يرفض حركةً بوحدةٍ غير وحدة النوع ولا يجمعها', () {
      final Outcome<StockQuantity> outcome = computeItemBalance(
        movements: <StockMovement>[
          _in(10),
          const StockMovement(
            itemKey: 'ITM-0001',
            direction: MovementDirection.incoming,
            quantity: WeightQuantity(WeightKg(2.5)),
            isCancelled: false,
          ),
        ],
        unit: ItemUnit.piece,
      );
      expect(outcome, isA<Failure<StockQuantity>>());
      expect(
        ((outcome as Failure<StockQuantity>).error as ValidationError).ruleCode,
        'GR-19',
      );
    });

    test('يجمع الأوزان بوحدتها بلا تقريب — ADR-0015 القاعدة 4', () {
      final Outcome<StockQuantity> outcome = computeItemBalance(
        movements: const <StockMovement>[
          StockMovement(
            itemKey: 'ITM-SCRAP',
            direction: MovementDirection.incoming,
            quantity: WeightQuantity(WeightKg(2.125)),
            isCancelled: false,
          ),
          StockMovement(
            itemKey: 'ITM-SCRAP',
            direction: MovementDirection.outgoing,
            quantity: WeightQuantity(WeightKg(0.125)),
            isCancelled: false,
          ),
        ],
        unit: ItemUnit.kilogram,
      );
      final WeightQuantity balance =
          (outcome as Success<StockQuantity>).value as WeightQuantity;
      expect(balance.weight.formatted(), '2.000');
    });

    test('★ الرصيد قد يخرج سالباً من الجمع — والمنع فحصٌ مستقل', () {
      // ⚠️ الجمع يصف الدفتر كما هو؛ **والرفض قرارُ [validateNonNegativeBalance]**.
      final Outcome<StockQuantity> outcome = computeItemBalance(
        movements: <StockMovement>[_in(10), _out(15)],
        unit: ItemUnit.piece,
      );
      expect((outcome as Success<StockQuantity>).value.isNegative, isTrue);
    });
  });

  group('computeItemDailyFlow — أعمدة `item_daily_balances`', () {
    test('يفصل الوارد عن الصادر ويُعطي الرصيد', () {
      final Outcome<ItemDailyFlow> outcome = computeItemDailyFlow(
        movements: <StockMovement>[_in(120), _in(30), _out(50)],
        unit: ItemUnit.piece,
      );
      final ItemDailyFlow flow = (outcome as Success<ItemDailyFlow>).value;
      expect(flow.incoming, const PieceQuantity(PieceCount(150)));
      // ★ **الصادر بمقداره موجباً** — ⛔ لا بسالبه.
      expect(flow.outgoing, const PieceQuantity(PieceCount(50)));
      expect(flow.balance, const PieceQuantity(PieceCount(100)));
    });

    test('★★ A-14: حركةُ دخولٍ ملغاة لا تدخل عمود الوارد ولا الرصيد', () {
      final Outcome<ItemDailyFlow> outcome = computeItemDailyFlow(
        movements: <StockMovement>[_in(120), _in(500, cancelled: true)],
        unit: ItemUnit.piece,
      );
      final ItemDailyFlow flow = (outcome as Success<ItemDailyFlow>).value;
      expect(flow.incoming, const PieceQuantity(PieceCount(120)));
      expect(flow.balance, const PieceQuantity(PieceCount(120)));
    });

    test('★★★ A-14: وحركةُ خروجٍ ملغاة لا تدخل عمود الصادر ولا الرصيد', () {
      // ⚠️⚠️ **كشفَ هذه الحالةَ اختبارُ طفرة:** الفلترة كانت في موضعين،
      //    ⟵ **فطفرةٌ على أحدهما بقيت حيّة** لأن الاختبار الوحيد كان على
      //    حركةِ **دخولٍ** ملغاة. ★ **والخروج الملغى هو ما كان يُنقِص
      //    الرصيد ظلماً** فيُظهر مخزوناً أقل من الحقيقة.
      final Outcome<ItemDailyFlow> outcome = computeItemDailyFlow(
        movements: <StockMovement>[_in(120), _out(90, cancelled: true)],
        unit: ItemUnit.piece,
      );
      final ItemDailyFlow flow = (outcome as Success<ItemDailyFlow>).value;
      expect(flow.outgoing, const PieceQuantity(PieceCount.zero));
      expect(flow.balance, const PieceQuantity(PieceCount(120)));
    });

    test('★★ GR-19: ويرفض وحدةً غريبة في أي عمود', () {
      final Outcome<ItemDailyFlow> outcome = computeItemDailyFlow(
        movements: const <StockMovement>[
          StockMovement(
            itemKey: 'ITM-0001',
            direction: MovementDirection.outgoing,
            quantity: WeightQuantity(WeightKg(1)),
            isCancelled: false,
          ),
        ],
        unit: ItemUnit.piece,
      );
      expect(outcome, isA<Failure<ItemDailyFlow>>());
    });
  });

  group('validateNonNegativeBalance — FR-M8-01 · GR-11', () {
    test('★★ يرفض الرصيد السالب', () {
      final Outcome<void> outcome = validateNonNegativeBalance(
        const PieceQuantity(PieceCount(-1)),
      );
      expect(outcome, isA<Failure<void>>());
      expect(
        (outcome as Failure<void>).error,
        isA<InsufficientStockError>(),
      );
    });

    test('يقبل الصفر — والصفر ليس سالباً', () {
      expect(
        validateNonNegativeBalance(const PieceQuantity(PieceCount.zero)),
        isA<Success<void>>(),
      );
    });
  });

  group('addQuantity — GR-19', () {
    test('يجمع كميتين بنفس الوحدة', () {
      final Outcome<StockQuantity> outcome = addQuantity(
        const PieceQuantity(PieceCount(3)),
        const PieceQuantity(PieceCount(4)),
      );
      expect(
        (outcome as Success<StockQuantity>).value,
        const PieceQuantity(PieceCount(7)),
      );
    });

    test('★★ يرفض جمع حبّةٍ مع كيلوجرام ولا يطويه صامتاً', () {
      expect(
        addQuantity(
          const PieceQuantity(PieceCount(3)),
          const WeightQuantity(WeightKg(1)),
        ),
        isA<Failure<StockQuantity>>(),
      );
    });
  });

  group('المفاتيح المركّبة — naming-conventions.md §4', () {
    test('itemDailyBalanceId بترتيب {sourceId}_{itemKey}_{stockDate}', () {
      expect(
        itemDailyBalanceId(
          sourceId: 'SRC-001',
          itemKey: 'ITM-0007',
          stockDate: CalendarDay(2026, 8, 20),
        ),
        'SRC-001_ITM-0007_20260820',
      );
    });

    test('⛔ ويرفض مصدراً فارغاً — «المصدر إلزامي في كل سطر»', () {
      expect(
        () => itemDailyBalanceId(
          sourceId: '',
          itemKey: 'ITM-0007',
          stockDate: CalendarDay(2026, 8, 20),
        ),
        throwsArgumentError,
      );
    });

    test('★ stockMovementId مشتقٌّ من رقم المستند ومفتاح النوع', () {
      expect(
        stockMovementId(
          documentNumber: 'INC-20260820-0001',
          itemKey: 'ITM-0007',
        ),
        'INC-20260820-0001_ITM-0007',
      );
    });
  });

  group('StockQuantity — الوحدة جزءٌ من النوع', () {
    test('صفرُ كل وحدة بوحدتها', () {
      expect(StockQuantity.zeroOf(ItemUnit.piece).unit, ItemUnit.piece);
      expect(StockQuantity.zeroOf(ItemUnit.kilogram).unit, ItemUnit.kilogram);
      expect(StockQuantity.zeroOf(ItemUnit.piece).isZero, isTrue);
    });

    test('الموجب ليس صفراً ولا سالباً', () {
      const PieceQuantity q = PieceQuantity(PieceCount(5));
      expect(q.isPositive, isTrue);
      expect(q.isZero, isFalse);
      expect(q.isNegative, isFalse);
    });
  });
}

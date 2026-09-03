/// ★★★ **خياراتُ الصرف — من أرصدة الدفتر لا من كتالوج الأنواع.**
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **ولماذا وُجد هذا الملف — [`DEBT-86`] مقيسٌ على `Pixel_6_API_36`
/// (2026-09-02):** ★ **سطرُ الجونية يدخل المخزن بمفتاحٍ مركّب**
/// (`سلة - جونية رقم 1` — [`ADR-0007`]) ⛔ **لا بمعرّف سجل نوع**، ★ **ومنسدلاتُ
/// التوزيع والبيع النقدي والسحبيات كانت تُبنى من `items`** ⟹ ⛔⛔ **فما دخل
/// المخزنَ من جونية لم يكن يُوزَّع ولا يُباع ولا يُصرَف إطلاقاً.**
///
/// ⛔⛔★★★ **ولم يكشفه 2151 اختباراً آلياً** — ★ **ولماذا بالضبط:** **كلُّ
/// اختبارِ شاشةٍ كان يبثّ نوعاً في الكتالوج ويقرأ منه**، ⟵ **فلم يقع اختبارٌ
/// واحدٌ على مفتاحٍ في الدفتر بلا سجلٍّ يقابله** — ★ **وهو حالُ كلِّ جونية.**
/// ⟹ **وهذا الملف يُثبت المسارَ من طرفه:** **مفتاحٌ مركّبٌ في الدفتر ⟵ خيارٌ
/// في القائمة.**
/// ═══════════════════════════════════════════════════════════════════════
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qtms/capabilities/inventory/application/inventory_providers.dart';
import 'package:qtms/capabilities/master_data/application/master_data_providers.dart';
import 'package:qtms_domain/qtms_domain.dart';

import '../../../support/fake_inventory.dart';
import '../../../support/fake_master_data.dart';

/// ★ **اليوم مثبَّت** — ⛔ **فلا اختبارَ ينكسر بمرور منتصف الليل.**
final CalendarDay fixedDay = CalendarDay(2026, 9, 2);

void main() {
  late FakeInventoryDirectory inventory;
  late FakeMasterDataDirectory masterData;
  late ProviderContainer container;

  setUp(() {
    inventory = FakeInventoryDirectory();
    masterData = FakeMasterDataDirectory();
    container = ProviderContainer(
      overrides: [
        inventoryDirectoryProvider.overrideWithValue(inventory),
        masterDataDirectoryProvider.overrideWithValue(masterData),
        todayProvider.overrideWithValue(fixedDay),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(inventory.dispose);
    addTearDown(masterData.dispose);
  });

  /// ★ يقرأ الخيارات بعد أن تستقرّ التدفّقات.
  Future<List<StockOption>> options() async {
    final ProviderSubscription<List<StockOption>> sub = container.listen(
      stockOptionsProvider(
        StockQuery(sourceId: 'SRC-001', stockDate: fixedDay),
      ),
      (_, _) {},
    );
    addTearDown(sub.close);
    // ★ **تدفّقان مستقلّان** (الأرصدة والكتالوج) — ⟵ **ومهلةٌ واحدة لا تكفي
    //   لاستقرارهما معاً**: ⛔ **والقراءةُ قبل استقرارهما تقيس السباق لا القاعدة.**
    await Future<void>.delayed(const Duration(milliseconds: 20));
    return sub.read();
  }

  group('⛔⛔★★★ DEBT-86 — المفتاح المركّب خيارٌ في القائمة', () {
    test('✅★★★ مفتاحُ جونيةٍ لا سجلَ نوعٍ له يظهر خياراً باسمه المركّب',
        () async {
      // ★★ **الكتالوجُ يحمل «سلة» بمعرّفها** — ⛔ **والدفترُ يحمل المركّب**:
      //    ⟵ **وهو حرفياً ما وقع حيّاً** (`SCK-20260902-0001`).
      masterData.emitItems(<ItemCard>[testItem(itemId: 'ITM-0002', name: 'سلة')]);
      inventory.emitStock(<ItemDailyBalanceCard>[
        // ⛔⛔★★★ **والشكلُ المخزَّن الحقيقي:** **المفتاحُ مركّبٌ والاسمُ
        //    مجرَّد** — ★ **مقيسٌ على التجريبية** (`SRC-001_عتود - جونية رقم
        //    1_20260902` ⟵ `itemName: "عتود"`)، ⛔ **ولا يُفترَض.**
        testBalance(
          itemKey: 'سلة - جونية رقم 1',
          itemName: 'سلة',
          incoming: 100,
          outgoing: 0,
        ),
      ]);

      final List<StockOption> result = await options();

      expect(result, hasLength(1));
      expect(result.single.itemKey, 'سلة - جونية رقم 1');
      // ★★★ **والمعروضُ المركّب** — [`ADR-0007`]: ⛔ **لا «سلة» المجرَّدة**،
      //    ⟵ **وإلا عادت جونيتان خيارين متطابقين.**
      expect(result.single.itemName, 'سلة - جونية رقم 1');
      expect(result.single.balance, PieceQuantity(const PieceCount(100)));
    });

    test('⛔⛔★★★ ونوعٌ في الكتالوج بلا رصيدٍ في الدفتر لا يظهر', () async {
      // ⛔ **وهو عكسُ العطل** — ★ **لا يُعرَض ما لا يُمكن صرفُه** (`ADR-0008`
      //   القاعدة 5: **الغياب صفرٌ**)، ⟵ **وكان يُعرَض ثم تردّ السحابةُ
      //   «الكمية غير كافية»** ⛔ **بعد أن يكتب المستخدم كميةً كاملة.**
      masterData.emitItems(<ItemCard>[testItem(itemId: 'ITM-0009', name: 'عتود')]);
      inventory.emitStock(const <ItemDailyBalanceCard>[]);

      expect(await options(), isEmpty);
    });

    test('★★ ورصيدُ الصفر يبقى خياراً — ⛔ فنموذجُ التعديل لا يفقد نوعَه',
        () async {
      // ⚠️⚠️ **وهو حارسُ [`DEBT-88`] هنا:** ★ **تعديلُ مستندٍ استنفد رصيدَ
      //    نوعه يجعل رصيدَ اليوم صفراً بالضبط** (الداخل = الخارج)، ⟹ ⛔⛔
      //    **وإسقاطُه كان يفتح النموذجَ بحقلٍ يبدو فارغاً والنوعُ مختار.**
      masterData.emitItems(<ItemCard>[testItem()]);
      inventory.emitStock(<ItemDailyBalanceCard>[
        testBalance(incoming: 40, outgoing: 40),
      ]);

      final List<StockOption> result = await options();
      expect(result, hasLength(1));
      expect(result.single.balance.isZero, isTrue);
    });

    test('⛔★★ ونوعٌ معطَّلٌ في الكتالوج لا يظهر — FR-M5-10', () async {
      masterData.emitItems(<ItemCard>[testItem(isActive: false)]);
      inventory.emitStock(<ItemDailyBalanceCard>[testBalance()]);

      expect(await options(), isEmpty);
    });

    test('★★ والوحدةُ من الرصيد لا من الكتالوج — GR-19', () async {
      // ★★★ **والسكربُ وزنيٌّ** — ⟵ **ووحدتُه تصل بلا سجلِ نوعٍ يقابل
      //    مفتاحَه المركّب**، ⛔ **وافتراضُ «حبّة» كان يُنتج كميةً مرفوضة.**
      masterData.emitItems(const <ItemCard>[]);
      inventory.emitStock(<ItemDailyBalanceCard>[
        testWeightBalance(itemKey: 'السكرب - جونية رقم 1'),
      ]);

      final List<StockOption> result = await options();
      expect(result.single.unit, ItemUnit.kilogram);
    });

    test('★ ووزنُ الحبة يأتي من سجل النوع متى وُجد — AM-012 §4.4', () async {
      masterData.emitItems(<ItemCard>[
        testItem(itemId: 'ITM-0002', name: 'عود', pieceWeightGrams: 200),
      ]);
      inventory.emitStock(<ItemDailyBalanceCard>[testBalance()]);

      final List<StockOption> result = await options();
      expect(result.single.pieceWeightGrams, 200);
    });
  });
}

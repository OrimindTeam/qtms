/// عقود مستودع التسعير اليومي — **قراءةً وكتابةً**.
///
/// ★ **الفصل مقصود ويطابق `ADR-0013`:** القراءة **مباشرة من القاعدة**
/// (القاعدة 4 — `daily_prices` تسمح `allow read: if isSignedIn() &&
/// storedInScope()`)، **والكتابة عبر دالة سحابية مستدعاة** تكتب السجلات
/// **وقيدَ تدقيقها في معاملة واحدة** (القاعدة 1).
///
/// ⛔★★ **ولا كتابة مباشرة واحدة:** `daily_prices` **`allow create, update:
/// if false`** في `firestore.rules` — ⟵ **فالواجهة تطلب ولا تكتب.**
library;

import '../../../core/calendar_day.dart';
import '../../../core/money.dart';
import '../../../core/outcome.dart';
import '../../master_data/domain/master_data.dart' show ItemUnit;
import 'daily_price.dart';

/// ⛅ بطاقة سعر نوعٍ في يوم — مستند `daily_prices/{المفتاح المركّب}`.
///
/// ⚠️⚠️ **وغيابُ السجل يعني «غير مسعَّر»** ⛔ **لا «صفر»** — ★ **وهو نفس
/// منطق `ItemDailyBalanceCard`** (`ADR-0008` القاعدة 5): **لا يُنشأ سجل
/// بلا داعٍ.** ⟵ **فنوعٌ له كميةُ اليوم ولا بطاقة سعرٍ له يظهر في شاشة
/// التسعير بحقلين فارغين** (`FR-M9-01`: **كل يوم يبدأ بلا أسعار**)،
/// **وفي المركز المعلّق** (`FR-M9-10`).
final class DailyPriceCard {
  /// ينشئ البطاقة.
  const DailyPriceCard({
    required this.sourceId,
    required this.itemKey,
    required this.itemName,
    required this.unit,
    required this.date,
    this.distributionPrice,
    this.minCashPrice,
    this.lastModifiedAt,
    this.modifiedBy,
  });

  /// المصدر — ★ **والسعر يخصّه وحده** (`FR-M9-03`).
  final String sourceId;

  /// مفتاح النوع.
  final String itemKey;

  /// الاسم المعروض.
  final String itemName;

  /// ★ وحدة النوع — **سعر حبة أو سعر كيلو** (`FR-M9-06`).
  final ItemUnit unit;

  /// ★ **يوم السعر** — ⛔ **ولا يُرحَّل إلى الغد** (`FR-M9-01` · `GR-31`).
  final CalendarDay date;

  /// سعر التوزيع أو `null` — **اقتراح لا التزام** (`FR-M9-07`).
  final Money? distributionPrice;

  /// الحد الأدنى أو `null` — **مُلزِم فعلاً** (`FR-M9-08`).
  final Money? minCashPrice;

  /// آخر تعديل.
  final DateTime? lastModifiedAt;

  /// من عدّله.
  final String? modifiedBy;

  /// ★ **السعران معاً؟** — `FR-M9-05`.
  ///
  /// ⚠️ **ويُحسَب هنا ⛔ ولا يُقرأ من الحقل المخزَّن:** الحقل
  /// `isPricingComplete` **مشتقٌّ تكتبه السحابة للفلترة والفهرسة**
  /// (`schema/daily-prices.md`: فهرس `sourceId ↑ · date ↑ ·
  /// isPricingComplete ↑`)، ⟵ ★ **والقيمة المعروضة تُشتقّ من السعرين
  /// نفسيهما** — ⛔ **فلا تعرض الشاشة «مسعَّر» لسجلٍ حقلُه المشتقّ متأخر.**
  bool get complete => isPricingComplete(
        distributionPrice: distributionPrice,
        minCashPrice: minCashPrice,
      );
}

/// دليل التسعير — **قراءةً فقط**.
///
/// ★ **تدفّقٌ لا قراءة مفردة:** تسعيرٌ من جهازٍ آخر **يظهر فوراً**
/// (`ADR-0010`) — ⟵ **فلا يُسعِّر اثنان نوعاً واحداً وهما لا يريان بعضهما.**
abstract interface class DailyPricingDirectory {
  /// ★ **أسعار يومٍ واحد لمصدرٍ واحد** — `FR-M9-03`.
  ///
  /// ⛔ **ولا استعلام يجمع يومين ولا مصدرين** — ★ **والمفتاح المركّب يجعل
  /// ذلك بنيوياً** ([dailyPriceId])، **والفهرس المعتمد `sourceId ↑ ·
  /// date ↑ · isPricingComplete ↑`.**
  Stream<List<DailyPriceCard>> watchDailyPrices({
    required String sourceId,
    required CalendarDay date,
  });
}

/// مستودع كتابة الأسعار — **عبر العملية المستدعاة حصراً**.
abstract interface class DailyPricingRepository {
  /// ★ يكتب دفعة تسعير لليوم — **بصلاحية `dailyPriceWrite` ونطاق المصدر**.
  ///
  /// ⚙️ **واليوم من المنصّة داخل المعاملة** (`GR-54` · `E-41`) — ⛔ **ولا
  /// يُرسَل أصلاً**، ★ **فما لا يُرسَل لا يُزوَّر.**
  ///
  /// ⚠️⚠️ **و[amendReason] إلزامي إذا — وإذا فقط — غيّرت الدفعة سعراً
  /// قائماً** (`ADR-0004` · `CR-002` · `FR-M9-11`): ⟵ **فالتسعير الأول
  /// كل صباح لا يُطالَب بعلّة**، ★ **وتغييرُ سعرٍ قائم يُسجَّل بقيمته قبل
  /// وبعد.** ⛔ **والحَكَم في ذلك السجلُّ المقروء داخل المعاملة** لا هذا
  /// الوسيط (راجع [changesStoredPrice]).
  Future<Outcome<void>> writeDailyPrices({
    required ValidatedDailyPriceBatch batch,
    String? amendReason,
  });
}

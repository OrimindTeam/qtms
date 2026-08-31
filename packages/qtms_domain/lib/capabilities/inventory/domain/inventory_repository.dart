/// عقود مستودعات المخزون — **قراءةً وكتابةً**.
///
/// ★ **الفصل مقصود ويطابق `ADR-0013`:** القراءة **مباشرة من القاعدة**
/// (القاعدة 4)، **والكتابة عبر دالة سحابية مستدعاة** تكتب المستند وحركاته
/// وأرصدته **وقيدَ تدقيقه في معاملة واحدة** (القاعدة 1).
///
/// ⛔★★ **ولا مستودعَ واحدٍ يجمعهما:** `inventory_ledger` و
/// `item_daily_balances` **`allow write: if false` للجميع** بينما القراءة
/// مسموحة بالنطاق — ⟵ **ودمجُهما يُخفي أن أحدهما ممكن والآخر مستحيل من
/// الجهاز.**
library;

import '../../../core/calendar_day.dart';
import '../../../core/outcome.dart';
import '../../../core/quantity.dart';
import '../../master_data/domain/master_data.dart' show ItemUnit;
import 'counted_intake.dart';
import 'inventory.dart';

/// ⛅ بطاقة رصيد نوع في يوم — مستند `item_daily_balances/{المفتاح المركّب}`.
///
/// ⚠️ **وغيابُ السجل يعني صفراً** (`ADR-0008` القاعدة 5) — ⟵ **فقائمةٌ
/// لا تحوي نوعاً تعني رصيده صفر**، ⛔ **لا أن النوع غير موجود.**
final class ItemDailyBalanceCard {
  /// ينشئ البطاقة.
  const ItemDailyBalanceCard({
    required this.sourceId,
    required this.itemKey,
    required this.itemName,
    required this.stockDate,
    required this.incoming,
    required this.outgoing,
    required this.balance,
  });

  /// المصدر.
  final String sourceId;

  /// مفتاح النوع.
  final String itemKey;

  /// الاسم المعروض.
  final String itemName;

  /// ★ **تاريخ المخزون** — ⛔ **لا تاريخ الإدخال** (`RISK-07`).
  final CalendarDay stockDate;

  /// إجمالي الداخل.
  final StockQuantity incoming;

  /// إجمالي الخارج.
  final StockQuantity outgoing;

  /// الرصيد — ★ **`Σ(الداخل) − Σ(الخارج)`** (`design-overview.md` §2.1).
  final StockQuantity balance;

  /// وحدة النوع — ★ **وهي وحدة الأعمدة الثلاثة معاً** (`GR-19`).
  ItemUnit get unit => balance.unit;
}

/// سطر في **سجل حركة النوع** — `FR-M8-06`.
final class StockMovementCard {
  /// ينشئ السطر.
  const StockMovementCard({
    required this.movementId,
    required this.itemKey,
    required this.itemName,
    required this.direction,
    required this.quantity,
    required this.balanceAfter,
    required this.sourceDocumentType,
    required this.sourceDocumentNumber,
    required this.entryDate,
    required this.isCancelled,
    required this.isAmended,
    this.movementTag = MovementTag.normal,
    this.userName,
    this.stockDate,
  });

  /// معرّف الحركة.
  final String movementId;

  /// مفتاح النوع.
  final String itemKey;

  /// اسم النوع.
  final String itemName;

  /// الاتجاه.
  final MovementDirection direction;

  /// الكمية بوحدتها.
  final StockQuantity quantity;

  /// ★ **الرصيد التراكمي بعد الحركة** — `FR-M8-06`.
  final StockQuantity balanceAfter;

  /// نوع المستند المصدر.
  final SourceDocumentType sourceDocumentType;

  /// رقم المستند المصدر.
  final String sourceDocumentNumber;

  /// ★ **تاريخ الإدخال** — للتدقيق وحده ⛔ **ولا يُبنى عليه رصيد** (`RISK-07`).
  final DateTime entryDate;

  /// هل هي ملغاة؟ — ★ **وتُعرَض مشطوبةً ولا تختفي** (`A-14`).
  final bool isCancelled;

  /// ★ **شارة «مُعدَّل»** — `FR-M8-06`.
  final bool isAmended;

  /// وسم الحركة.
  final MovementTag movementTag;

  /// اسم المستخدم — `FR-M8-02`.
  final String? userName;

  /// ★★ **تاريخ المخزون** — و`null` **لحركةٍ قديمة بلا الحقل**.
  ///
  /// ═════════════════════════════════════════════════════════════════════
  /// ⚠️⚠️ **ولماذا أُضيف في `WU-011` ولم يكن لازماً قبله:** ★ **شاشةُ حركة
  /// النوع تستعلم بيومٍ واحدٍ مثبَّت** (`FR-M8-06`)، ⟵ **فاليومُ معلومٌ خارج
  /// البطاقة.** ★ **وتقريرُ `R-01` يمتدّ على فترة** — ⟵ **فبلا هذا الحقل
  /// يُعرَض عمودُ تاريخٍ مبنيٌّ على `entryDate`**، ⛔ **وهو بالضبط خلطُ
  /// التاريخين الذي يُنتج أرقاماً خاطئة بصمت** (`RISK-07` · `ADR-0006`).
  ///
  /// ⛔ **واختياريٌّ لا إلزامي** — ★ **فالحقل مكتوبٌ في الدفتر منذ `WU-003`**،
  /// ⟵ **والغيابُ هنا يعني «لم يُطلَب في هذا الاستعلام»** ⛔ **لا «لا تاريخ
  /// مخزون للحركة».**
  /// ═════════════════════════════════════════════════════════════════════
  final CalendarDay? stockDate;
}

/// بطاقة مستند وارد عدداً — مستند `incoming_count/{documentNumber}`.
final class CountedIntakeCard {
  /// ينشئ البطاقة.
  CountedIntakeCard({
    required this.documentNumber,
    required this.sourceId,
    required this.stockDate,
    required this.entryDate,
    required this.status,
    required this.totalQuantity,
    required List<ValidatedCountedIntakeLine> lines,
    this.supplierId,
    this.notes,
    this.cancelReason,
    this.amendCount = 0,
  }) : lines = List<ValidatedCountedIntakeLine>.unmodifiable(lines);

  /// رقم المستند — `INC-YYYYMMDD-####`.
  final String documentNumber;

  /// المصدر.
  final String sourceId;

  /// ★ تاريخ المخزون — 🔒 **من الخادم ولا يُغيَّر** (`FR-M6-02`).
  final CalendarDay stockDate;

  /// تاريخ الإدخال.
  final DateTime entryDate;

  /// الحالة.
  final CountedIntakeStatus status;

  /// إجمالي الحبّات.
  final PieceCount totalQuantity;

  /// السطور.
  final List<ValidatedCountedIntakeLine> lines;

  /// الرعوي إن اشترطه المصدر.
  final String? supplierId;

  /// ملاحظات المستند.
  final String? notes;

  /// سبب الإلغاء.
  final String? cancelReason;

  /// عدد التعديلات — ★ **مصدر شارة «مُعدَّل»** (`FR-M8-06`).
  final int amendCount;
}

/// دليل المخزون — **قراءةً فقط**.
///
/// ★ **تدفّقات لا قراءات مفردة:** توريدٌ من جهازٍ آخر **يظهر فوراً** في شاشة
/// مخزون اليوم (`ADR-0010`).
abstract interface class InventoryDirectory {
  /// ★ **مخزون اليوم لمصدر واحد** — `FR-M8-05`: **اليوم الجاري فقط 🔒**.
  ///
  /// ⛔ **ولا متصفّح تاريخ للقراءة** — والاطلاع التاريخي وظيفة تقارير `M19`
  /// (`BR-M8-06` · `GR-55`).
  Stream<List<ItemDailyBalanceCard>> watchTodayStock({
    required String sourceId,
    required CalendarDay stockDate,
  });

  /// ★ **سجل حركة نوعٍ في يوم** — `FR-M8-06`: مرتَّبةً زمنياً بالرصيد
  /// التراكمي بعد كل حركة.
  Stream<List<StockMovementCard>> watchItemMovements({
    required String sourceId,
    required String itemKey,
    required CalendarDay stockDate,
  });

  /// مستندات الوارد عدداً في يوم لمصدر.
  Stream<List<CountedIntakeCard>> watchCountedIntakes({
    required String sourceId,
    required CalendarDay stockDate,
  });
}

/// مستودع كتابة المخزون — **عبر العمليات المستدعاة حصراً**.
///
/// ⛔★★ **ولا كتابة مباشرة واحدة:** `incoming_count` و`inventory_ledger` و
/// `item_daily_balances` **كلها مغلقة في القواعد** — ⟵ **فالواجهة تطلب ولا
/// تكتب**، والحركةُ والرصيدُ وقيدُ التدقيق **في معاملة سحابية واحدة**.
abstract interface class InventoryAdminRepository {
  /// ينشئ مستند وارد عدداً ويُرجِع **رقمه** — ★ **والرقم من السحابة**
  /// (`naming-conventions.md` §5) ⛔ **ولا يُولِّده الجهاز أبداً**.
  ///
  /// ⚙️ **وتاريخ المخزون من الخادم** (`FR-M6-02`) — ⛔ **ولا يُرسَل أصلاً.**
  Future<Outcome<String>> createCountedIntake(ValidatedCountedIntake intake);

  /// ★ يعدّل مستنداً معتمداً — **بصلاحية `incomingCountAmend` وسببٍ نصّي
  /// إلزامي** (`FR-M6-11` · `ADR-0004`).
  ///
  /// ⛔ **ولا يُنشئ حركة تصحيحية:** الحركة **تُعدَّل في مكانها** ويُعاد
  /// احتساب الرصيد (`A-14`).
  Future<Outcome<void>> amendCountedIntake({
    required String documentNumber,
    required ValidatedCountedIntake intake,
    String? amendReason,
  });

  /// ★ يُلغي مستنداً — **بصلاحية `incomingCountCancel` وسببٍ نصّي إلزامي**
  /// (`FR-M6-13`).
  ///
  /// ⛔ **والحذف مرفوض نهائياً لكل المستخدمين بمن فيهم المالك** (`FR-M6-14`
  /// · `GR-07`) — ⟵ **فلا دالة حذف في هذا العقد أصلاً.**
  ///
  /// ⚠️ **و[sourceId] يُرسَل لفحص النطاق قبل فتح المعاملة** — ★ **والمصدر
  /// المخزَّن في المستند هو الحَكَم داخلها**، ⛔ **فلا يُصدَّق المُرسَل.**
  Future<Outcome<void>> cancelCountedIntake({
    required String documentNumber,
    required String sourceId,
    String? cancelReason,
  });
}

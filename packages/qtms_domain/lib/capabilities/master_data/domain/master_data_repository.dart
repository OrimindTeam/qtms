/// عقود مستودعات البيانات المرجعية — **قراءةً وكتابةً**.
///
/// ★ **الفصل مقصود ويطابق `ADR-0013`:** القراءة **مباشرة من القاعدة**
/// (القاعدة 4: «لا يمسّ هذا القرار القراءة إطلاقاً»)، **والكتابة عبر دالة
/// سحابية مستدعاة** تكتب المستند وقيدَه في معاملة واحدة.
///
/// ⛔★★ **ولا مستودعَ واحدٍ يجمعهما:** شرطاهما في `firestore.rules`
/// مختلفان — القراءة `isSignedIn()` (والمصادر مع النطاق)، والكتابة
/// `if false` للجميع. ⟵ **ودمجُهما يُخفي أن أحدهما ممكن والآخر مستحيل
/// من الجهاز.**
library;

import '../../../core/outcome.dart';
import 'master_data.dart';

/// بطاقة مصدر — مستند `sources/{sourceId}`.
final class SourceCard {
  /// ينشئ البطاقة.
  const SourceCard({
    required this.sourceId,
    required this.name,
    required this.requiresSupplierOnIntake,
    required this.isActive,
    this.notes,
    this.disableReason,
  });

  /// معرّف المصدر — `SRC-001`.
  final String sourceId;

  /// اسمه.
  final String name;

  /// ★ إلزامية الرعوي عند التوريد — `FR-M2-02`.
  final bool requiresSupplierOnIntake;

  /// الحالة.
  final bool isActive;

  /// الملاحظات.
  final String? notes;

  /// سبب التعطيل.
  final String? disableReason;
}

/// بطاقة رعوي — مستند `suppliers/{supplierId}`.
final class SupplierCard {
  /// ينشئ البطاقة.
  SupplierCard({
    required this.supplierId,
    required this.name,
    required this.phone,
    required this.isActive,
    List<String> sourceIds = const <String>[],
    this.notes,
    this.disableReason,
  }) : sourceIds = List<String>.unmodifiable(sourceIds);

  /// معرّفه — `SUP-0001`.
  final String supplierId;

  /// ★ مصادره — `FR-M3-09`: **لا يظهر في مصدر ليس ضمن مصادره**.
  final List<String> sourceIds;

  /// اسمه.
  final String name;

  /// هاتفه.
  final String phone;

  /// الحالة.
  final bool isActive;

  /// الملاحظات.
  final String? notes;

  /// سبب التعطيل.
  final String? disableReason;
}

/// بطاقة مقوت — مستند `dealers/{dealerId}`.
///
/// ⛔★★ **ولا حقل مصدر فيها** — `FR-M4-04` · `master-data-design.md` §7.
final class DealerCard {
  /// ينشئ البطاقة.
  const DealerCard({
    required this.dealerId,
    required this.name,
    required this.phone,
    required this.isActive,
    this.notes,
    this.disableReason,
  });

  /// معرّفه — `MQT-0001`.
  final String dealerId;

  /// اسمه.
  final String name;

  /// هاتفه.
  final String phone;

  /// الحالة.
  final bool isActive;

  /// الملاحظات.
  final String? notes;

  /// سبب التعطيل — ★ **إلزامي عند التعطيل**.
  final String? disableReason;
}

/// بطاقة نوع — مستند `items/{itemId}`.
final class ItemCard {
  /// ينشئ البطاقة.
  ItemCard({
    required this.itemId,
    required this.name,
    required this.nature,
    required this.unit,
    required this.isActive,
    required this.isSystemDefault,
    List<String> sourceIds = const <String>[],
    this.pieceWeightGrams,
    this.disableReason,
  }) : sourceIds = List<String>.unmodifiable(sourceIds);

  /// معرّفه — `ITM-0001`.
  final String itemId;

  /// ★ مصادره — `FR-M5-10`: **لا يظهر في مصدر غير مرتبط به إطلاقاً**.
  final List<String> sourceIds;

  /// اسمه.
  final String name;

  /// طبيعته.
  final ItemNature nature;

  /// وحدة رصيده — 🔒.
  final ItemUnit unit;

  /// وزن الحبة أو `null`.
  final double? pieceWeightGrams;

  /// الحالة.
  final bool isActive;

  /// ★★ هل هو «السكرب»؟ — ويظهر في القائمة بعلامة 🔒 (`FR-M5-05`).
  final bool isSystemDefault;

  /// سبب التعطيل.
  final String? disableReason;
}

/// الإعداد التأسيسي كما هو مخزَّن — **البندان معاً**.
final class AppSettingsCard {
  /// ينشئ البطاقة.
  const AppSettingsCard({
    required this.businessName,
    required this.currencySymbol,
    required this.decimalPlaces,
    required this.thousandsSeparator,
    this.logo,
    this.phone,
    this.address,
  });

  /// اسم المحل.
  final String businessName;

  /// الشعار.
  final String? logo;

  /// الهاتف.
  final String? phone;

  /// العنوان.
  final String? address;

  /// رمز العملة.
  final String currencySymbol;

  /// ★ **صفر حتماً** — `ADR-0015`.
  final int decimalPlaces;

  /// فاصل الآلاف.
  final String thousandsSeparator;
}

/// دليل البيانات المرجعية — **قراءةً فقط**.
///
/// ★ **تدفّقات لا قراءات مفردة:** تعطيلُ مصدرٍ من جهازٍ آخر **يظهر فوراً**
/// في كل شاشة تعتمده (`ADR-0010`).
abstract interface class MasterDataDirectory {
  /// تدفّق المصادر — ⚠️ **ويحترم نطاق المستخدم بشرط القراءة في القاعدة**.
  Stream<List<SourceCard>> watchSources();

  /// تدفّق الرعية.
  Stream<List<SupplierCard>> watchSuppliers();

  /// تدفّق المقاوته.
  Stream<List<DealerCard>> watchDealers();

  /// تدفّق الأنواع.
  Stream<List<ItemCard>> watchItems();

  /// ★ الإعداد التأسيسي، أو `null` إن لم يُكتب بعد — `FR-M21-04`.
  ///
  /// ⚠️ **و`null` تعني «لم يُكتب»** ⟵ **فتفتح شاشة الإعداد الإلزامية**،
  /// ⛔ **ولا تُقرأ «فشل قراءة»**: الفشل يصل خطأً في التدفّق.
  Stream<AppSettingsCard?> watchAppSettings();
}

/// مستودع كتابة البيانات المرجعية — **عبر العمليات المستدعاة حصراً**.
///
/// ⛔★★ **ولا كتابة مباشرة واحدة:** كل مجموعة هنا `allow create, update:
/// if false` بعد `WU-002` — ⟵ **فالواجهة تطلب ولا تكتب**، والقرارُ وقيدُ
/// التدقيقِ وحارسُ التفرّد **في معاملة سحابية واحدة** (`ADR-0013` القاعدة 1).
abstract interface class MasterDataAdminRepository {
  /// ينشئ مصدراً ويُرجِع كوده — ★ **والكود من السحابة** (`naming-conventions.md` §5).
  ///
  /// ⚙️ **وإنشاؤه يُطلِق تهيئة الحسابات** — حساب لكل مقوت ولكل رعوي
  /// **ووصل السكرب به** (`FR-M2-04` · `AT-37`).
  Future<Outcome<String>> createSource(ValidatedSource source);

  /// يعدّل مصدراً — ★ **بسببٍ نصّي إلزامي** (`ADR-0004` · `FR-M2-03`).
  Future<Outcome<void>> updateSource({
    required String sourceId,
    required ValidatedSource source,
    String? amendReason,
  });

  /// ينشئ رعوياً — ⚙️ **ويُهيَّأ له حساب في كل مصدر قائم** (`FR-M3-04`).
  Future<Outcome<String>> createSupplier(ValidatedSupplier supplier);

  /// يعدّل رعوياً — ★ **بسببٍ نصّي إلزامي** (`FR-M3-13`).
  Future<Outcome<void>> updateSupplier({
    required String supplierId,
    required ValidatedSupplier supplier,
    String? amendReason,
  });

  /// ينشئ مقوتاً — ⚙️ **ويُهيَّأ له حساب في كل مصدر قائم** (`FR-M4-05`).
  Future<Outcome<String>> createDealer(ValidatedDealer dealer);

  /// يعدّل مقوتاً — ★ **بسببٍ نصّي إلزامي** (`FR-M4-13`).
  ///
  /// [balanceAcknowledgement] ★ **إقرار نصّي يُشترط عند تعطيل مقوت له
  /// رصيد** (`FR-M4-09` · `E-39`) — ⛔ **والرصيد يُقاس في السحابة** لا في
  /// الجهاز.
  Future<Outcome<void>> updateDealer({
    required String dealerId,
    required ValidatedDealer dealer,
    String? amendReason,
    String? balanceAcknowledgement,
  });

  /// ينشئ نوعاً — ⛔ **ولا يُنشئ «السكرب»**: من السحابة فقط (`FR-M5-05`).
  Future<Outcome<String>> createItem(ValidatedItem item);

  /// يعدّل نوعاً — ⛔ **ويُرفَض على «السكرب»** (`FR-M5-05`).
  Future<Outcome<void>> updateItem({
    required String itemId,
    required ValidatedItem item,
    String? amendReason,
  });

  /// ★★ يكتب الإعداد التأسيسي — **مرة واحدة ومن المالك حصراً** (`FR-M21-03`).
  ///
  /// ⚙️ **وينشئ معه النوع الافتراضي «السكرب»** في المعاملة نفسها
  /// (`IQ-012` — الخيار أ: **الإنشاء مسؤولية `M21`**).
  Future<Outcome<void>> writeAppSettings(ValidatedAppSettings settings);
}

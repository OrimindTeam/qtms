/// بدائل اختبارية للبيانات المرجعية — ★ **فلا اختبار يمسّ سحابة ولا شبكة**
/// (`ADR-0010`: حقن اعتمادية صريح · `test-strategy.md`).
library;

import 'dart:async';

import 'package:qtms/capabilities/master_data/infrastructure/contact_picker.dart';
import 'package:qtms_domain/qtms_domain.dart';

/// دليل بيانات مرجعية يُتحكَّم به — ★ **والخطأ يُبثّ كخطأ لا كقائمة فارغة**،
/// ⟵ **فيُختبَر تمييز الشاشة بين «ممنوع» و«لا يوجد».**
final class FakeMasterDataDirectory implements MasterDataDirectory {
  final StreamController<List<SourceCard>> _sources =
      StreamController<List<SourceCard>>.broadcast();
  final StreamController<List<SupplierCard>> _suppliers =
      StreamController<List<SupplierCard>>.broadcast();
  final StreamController<List<DealerCard>> _dealers =
      StreamController<List<DealerCard>>.broadcast();
  final StreamController<List<ItemCard>> _items =
      StreamController<List<ItemCard>>.broadcast();
  final StreamController<AppSettingsCard?> _settings =
      StreamController<AppSettingsCard?>.broadcast();

  List<SourceCard>? _currentSources;
  List<SupplierCard>? _currentSuppliers;
  List<DealerCard>? _currentDealers;
  List<ItemCard>? _currentItems;
  AppSettingsCard? _currentSettings;
  bool _settingsEmitted = false;
  Object? _sourcesError;

  /// يبثّ المصادر.
  void emitSources(List<SourceCard> value) {
    _currentSources = value;
    _sources.add(value);
  }

  /// ★ يبثّ رفضاً — ⛔ **لا قائمة فارغة**.
  void emitSourcesError(Object error) {
    _sourcesError = error;
    _sources.addError(error);
  }

  /// يبثّ الرعية.
  void emitSuppliers(List<SupplierCard> value) {
    _currentSuppliers = value;
    _suppliers.add(value);
  }

  /// يبثّ المقاوته.
  void emitDealers(List<DealerCard> value) {
    _currentDealers = value;
    _dealers.add(value);
  }

  /// يبثّ الأنواع.
  void emitItems(List<ItemCard> value) {
    _currentItems = value;
    _items.add(value);
  }

  /// يبثّ الإعداد التأسيسي — و`null` تعني **لم يُكتب**.
  void emitSettings(AppSettingsCard? value) {
    _currentSettings = value;
    _settingsEmitted = true;
    _settings.add(value);
  }

  /// ⚠️ **يُغلِق بلا انتظار عمداً** — بنفس سبب `FakeAuthRepository.dispose`.
  void dispose() {
    unawaited(_sources.close());
    unawaited(_suppliers.close());
    unawaited(_dealers.close());
    unawaited(_items.close());
    unawaited(_settings.close());
  }

  @override
  Stream<List<SourceCard>> watchSources() async* {
    if (_sourcesError case final Object error) {
      yield* Stream<List<SourceCard>>.error(error);
    }
    if (_currentSources case final List<SourceCard> value) yield value;
    yield* _sources.stream;
  }

  @override
  Stream<List<SupplierCard>> watchSuppliers() async* {
    if (_currentSuppliers case final List<SupplierCard> value) yield value;
    yield* _suppliers.stream;
  }

  @override
  Stream<List<DealerCard>> watchDealers() async* {
    if (_currentDealers case final List<DealerCard> value) yield value;
    yield* _dealers.stream;
  }

  @override
  Stream<List<ItemCard>> watchItems() async* {
    if (_currentItems case final List<ItemCard> value) yield value;
    yield* _items.stream;
  }

  @override
  Stream<AppSettingsCard?> watchAppSettings() async* {
    if (_settingsEmitted) yield _currentSettings;
    yield* _settings.stream;
  }
}

/// مستودع كتابة يُتحكَّم به — ★ **يسجّل ما أُرسل حرفياً**.
final class FakeMasterDataAdmin implements MasterDataAdminRepository {
  /// آخر مصدر أُرسل.
  ValidatedSource? lastSource;

  /// آخر رعوي أُرسل.
  ValidatedSupplier? lastSupplier;

  /// آخر مقوت أُرسل.
  ValidatedDealer? lastDealer;

  /// آخر نوع أُرسل.
  ValidatedItem? lastItem;

  /// آخر إعداد أُرسل.
  ValidatedAppSettings? lastSettings;

  /// آخر سبب تعديل أُرسل — ★ **يُثبت أن الشاشة تُمرِّره كما هو**.
  String? lastAmendReason;

  /// ★★ آخر إقرار رصيد أُرسل — `FR-M4-09`.
  String? lastBalanceAcknowledgement;

  /// عدد الاستدعاءات — يُثبت أن الزر يفعل شيئاً.
  int calls = 0;

  /// النتيجة المُعادة — ★ **يُضبَط لاختبار عرض الرفض**.
  AppError? failure;

  Outcome<String> _id(String value) => failure == null
      ? Success<String>(value)
      : Failure<String>(failure!);

  Outcome<void> get _void =>
      failure == null ? const Success<void>(null) : Failure<void>(failure!);

  @override
  Future<Outcome<String>> createSource(ValidatedSource source) async {
    calls++;
    lastSource = source;
    return _id('SRC-001');
  }

  @override
  Future<Outcome<void>> updateSource({
    required String sourceId,
    required ValidatedSource source,
    String? amendReason,
  }) async {
    calls++;
    lastSource = source;
    lastAmendReason = amendReason;
    return _void;
  }

  @override
  Future<Outcome<String>> createSupplier(ValidatedSupplier supplier) async {
    calls++;
    lastSupplier = supplier;
    return _id('SUP-0001');
  }

  @override
  Future<Outcome<void>> updateSupplier({
    required String supplierId,
    required ValidatedSupplier supplier,
    String? amendReason,
  }) async {
    calls++;
    lastSupplier = supplier;
    lastAmendReason = amendReason;
    return _void;
  }

  @override
  Future<Outcome<String>> createDealer(ValidatedDealer dealer) async {
    calls++;
    lastDealer = dealer;
    return _id('MQT-0001');
  }

  @override
  Future<Outcome<void>> updateDealer({
    required String dealerId,
    required ValidatedDealer dealer,
    String? amendReason,
    String? balanceAcknowledgement,
  }) async {
    calls++;
    lastDealer = dealer;
    lastAmendReason = amendReason;
    lastBalanceAcknowledgement = balanceAcknowledgement;
    return _void;
  }

  @override
  Future<Outcome<String>> createItem(ValidatedItem item) async {
    calls++;
    lastItem = item;
    return _id('ITM-0002');
  }

  @override
  Future<Outcome<void>> updateItem({
    required String itemId,
    required ValidatedItem item,
    String? amendReason,
  }) async {
    calls++;
    lastItem = item;
    lastAmendReason = amendReason;
    return _void;
  }

  @override
  Future<Outcome<void>> writeAppSettings(ValidatedAppSettings settings) async {
    calls++;
    lastSettings = settings;
    return _void;
  }
}

/// ★ مُنتقي جهات اتصال مزيّف — **فيُختبَر الزر بلا جهاز**.
final class FakeContactPicker implements ContactPicker {
  /// ينشئ المُنتقي بجهته.
  FakeContactPicker([this.contact]);

  /// ما يُعيده — و`null` تعني **إلغاءً أو تعذّراً**.
  PickedContact? contact;

  /// عدد مرات الفتح.
  int opens = 0;

  @override
  Future<PickedContact?> pickOne() async {
    opens++;
    return contact;
  }
}

/// مصدر جاهز للاختبارات.
SourceCard testSource({
  String sourceId = 'SRC-001',
  String name = 'مصدر رداع',
  bool requiresSupplierOnIntake = true,
  bool isActive = true,
}) =>
    SourceCard(
      sourceId: sourceId,
      name: name,
      requiresSupplierOnIntake: requiresSupplierOnIntake,
      isActive: isActive,
    );

/// نوع جاهز للاختبارات.
ItemCard testItem({
  String itemId = 'ITM-0002',
  String name = 'عود',
  ItemNature nature = ItemNature.countBased,
  ItemUnit unit = ItemUnit.piece,
  bool isSystemDefault = false,
  bool isActive = true,
  // ★ **وزن الحبة من التهيئة** — ⛔ **للوزني وحده** (`FR-M5-02` · `E-09`)،
  //   ★ **وهو ما يفصل الحالة ① عن الحالة ②** في جدول `FR-M7-13`.
  double? pieceWeightGrams,
}) =>
    ItemCard(
      itemId: itemId,
      name: name,
      nature: nature,
      unit: unit,
      isActive: isActive,
      isSystemDefault: isSystemDefault,
      sourceIds: const <String>['SRC-001'],
      pieceWeightGrams: pieceWeightGrams,
    );

/// مقوت جاهز للاختبارات.
DealerCard testDealer({
  String dealerId = 'MQT-0001',
  String name = 'مقوت مثال',
  String phone = '777123456',
  bool isActive = true,
}) =>
    DealerCard(
      dealerId: dealerId,
      name: name,
      phone: phone,
      isActive: isActive,
    );

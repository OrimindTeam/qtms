/// قواعد البيانات المرجعية — **قبل أي كتابة**.
///
/// ★ **المصدر:** `FR-M2-*` (المصادر) · `FR-M3-*` (الرعية) · `FR-M4-*`
/// (المقاوته) · `FR-M5-*` (الأنواع) · `FR-M21-*` (الإعداد التأسيسي) ·
/// `master-data-design.md` §2 و§5 و§6 · `data-dictionary.md` §1.
///
/// ★★ **ولماذا في طبقة النطاق لا في الدالة السحابية (`ADR-0012`):** هذه
/// **قواعد عمل** لا تفاصيل نقل — ★ **ويستهلكها التطبيق أيضاً** ليمنع
/// الإرسالَ المرفوض سلفاً بدل رحلة شبكة تنتهي برفض. ⛔ **ونسختان تفترقان
/// عند أول تعديل**، فتصير الواجهة تسمح بما ترفضه السحابة أو العكس.
///
/// ⚠️ **وهي لا تُجيب عن «من يُصرَّح له بالكتابة أصلاً»** — ذاك مفاتيح
/// الكتالوج الخمسة (`sourceWrite` · `supplierWrite` · `dealerWrite` ·
/// `itemWrite` · `appSettingsWrite`)، **وتُفحَص في الدالة السحابية صراحةً**
/// (`ADR-0013` القاعدة 3). ما هنا **يبقى صحيحاً أياً كان صاحب الصلاحية**.
///
/// ★★ **واستثناءٌ واحد مقصود:** [validateDealerDeactivation] **تقرأ صلاحيةً
/// سادسة** — `dealerDisableWithBalance` (`IQ-020` الخيار أ) — ⛔ **لا لأنها
/// تُفوِّض الكتابة**، بل لأن `FR-M4-09` يجعل امتلاكها **جزءاً من قاعدة
/// العمل نفسها**: شرطُ التعطيل ثلاثيٌّ لا يتجزأ. ★ **وتُمرَّر قيمةً
/// `bool`** ⛔ **لا تُقرأ من بطاقةٍ ولا من شبكة داخل النطاق.**
library;

import '../../../core/errors/app_error.dart';
import '../../../core/outcome.dart';
import '../../../core/text_normalization.dart';

// ═════════════════════════════════════════════════════════════════════════
// أسماء المجموعات — `data-dictionary.md` §1 · `naming-conventions.md` §4
// (`snake_case` جمعاً). ★ **مصدر حقيقة واحد يشاركه التطبيق والسحابة.**
// ═════════════════════════════════════════════════════════════════════════

/// مجموعة المصادر.
const String sourcesCollection = 'sources';

/// مجموعة الرعية (الموردين).
const String suppliersCollection = 'suppliers';

/// مجموعة المقاوته.
const String dealersCollection = 'dealers';

/// مجموعة الأنواع — ★ وفيها النوع الافتراضي «السكرب».
const String itemsCollection = 'items';

/// مجموعة الإعداد التأسيسي — **بندان فقط · كتابة واحدة**.
const String appSettingsCollection = 'app_settings';

/// حراسة تفرد أسماء المصادر — **معرّفها هو الاسم المُطبَّع نفسه**.
const String uniqueSourceNamesCollection = 'unique_source_names';

/// حراسة تفرد هواتف الرعية.
const String uniqueSupplierPhonesCollection = 'unique_supplier_phones';

/// حراسة تفرد هواتف المقاوته.
const String uniqueDealerPhonesCollection = 'unique_dealer_phones';

/// حراسة تفرد أسماء الأنواع — **على مستوى النظام كله**.
const String uniqueItemNamesCollection = 'unique_item_names';

/// أرصدة المقاوته — `{dealerId}_{sourceId}` (`naming-conventions.md` §4).
const String dealerBalancesCollection = 'dealer_balances';

/// أرصدة الرعية — `{supplierId}_{sourceId}`.
const String supplierBalancesCollection = 'supplier_balances';

// ═════════════════════════════════════════════════════════════════════════
// معرّفا مستندَي الإعداد التأسيسي — ⛔ **ولا مفتاح ثالث** (`FR-M21-05`).
// ═════════════════════════════════════════════════════════════════════════

/// البند الأول: بيانات المنشأة (`FR-M21-01`).
const String appSettingsBusinessDocId = 'business';

/// البند الثاني: العملة والأرقام (`FR-M21-02`).
const String appSettingsFormattingDocId = 'formatting';

/// ★ **المفتاحان وحدهما** — `FR-M21-05`: «**لا يوجد في الإعدادات أي مفتاح
/// ثالث**، وقاعدة الحماية ترفض إنشاء أي مفتاح آخر».
const Set<String> appSettingsDocIds = <String>{
  appSettingsBusinessDocId,
  appSettingsFormattingDocId,
};

// ═════════════════════════════════════════════════════════════════════════
// حدود الأطوال — `data-dictionary.md` §1
// ═════════════════════════════════════════════════════════════════════════

/// أدنى طول لاسم رعوي أو مقوت — `data-dictionary.md`: `string(3–80)`.
const int partyNameMinLength = 3;

/// أقصى طول لاسم رعوي أو مقوت.
const int partyNameMaxLength = 80;

/// أدنى طول لاسم نوع — `data-dictionary.md` §`items`: `string(2–50)`.
const int itemNameMinLength = 2;

/// أقصى طول لاسم نوع.
const int itemNameMaxLength = 50;

/// أدنى طول لاسم مصدر.
///
/// ⚠️ **افتراض موثَّق لا نقلٌ عن مستند:** `data-dictionary.md` §`sources`
/// **لا يذكر حدّاً لطول الاسم** بينما يذكره للرعية والمقاوته والأنواع.
/// ★ **والحدّ هنا مشتقّ منهما لا مخترَعاً**: الأدنى من الأنواع (2) والأقصى
/// من الأطراف (80). ⟵ **فلا اسم بحرفٍ واحد ولا اسم بلا سقف**، ⛔ **وأثره
/// محصور في رفض إدخالٍ شاذّ** لا في أي معادلة ولا رصيد.
const int sourceNameMinLength = itemNameMinLength;

/// أقصى طول لاسم مصدر — راجع [sourceNameMinLength].
const int sourceNameMaxLength = partyNameMaxLength;

/// أقصى طول لنصّ حرّ اختياري (الملاحظات · العنوان).
const int freeTextMaxLength = 500;

// ═════════════════════════════════════════════════════════════════════════
// النوع: الطبيعة والوحدة
// ═════════════════════════════════════════════════════════════════════════

/// طبيعة النوع — `data-dictionary.md` §`items` (`nature`).
enum ItemNature {
  /// عددي — الوزن الكلي **يدوي** ووزن الحبة **مُستنتج** (`FR-M5-07`).
  countBased,

  /// وزني — وزن الحبة من التهيئة أو يدوي، والوزن الكلي **محسوب**.
  weightBased,
}

/// وحدة رصيد النوع — `data-dictionary.md` §`items` (`unit`) — ⚙️ 🔒.
enum ItemUnit {
  /// حبة — **لكل الأنواع التي يُنشئها المستخدم** (`FR-M5-03`).
  piece,

  /// كيلوجرام — **للنوع الافتراضي «السكرب» وحده** (`FR-M5-03` · `FR-M5-05`).
  kilogram,
}

/// ★ **الوحدة مشتقّة لا مُدخَلة** — `FR-M5-03` · `data-dictionary.md` (⚙️).
///
/// ⚠️ **ولماذا دالة لا حقل يرسله المُرسِل:** الوحدة **جزء من هوية النوع**
/// و«**لا تتغيّر بعد أول حركة**» (`FR-M5-04` · `BR-M5-11`). ⟵ **فلو
/// أُخِذت من الحمولة لأمكن إنشاء نوعِ مستخدمٍ بالكيلوجرام**، ★ **وعندها
/// تُجمَع كمياتُه مع السكرب** — وهو ما يمنعه `E-31` نصّاً («جمع كميات
/// بالحبة مع كميات بالكيلو **ممنوع**»).
ItemUnit unitOfItem({required bool isSystemDefault}) =>
    isSystemDefault ? ItemUnit.kilogram : ItemUnit.piece;

/// ★★ اسم النوع الافتراضي كما يُخزَّن — `IQ-012` · معجم `naming-conventions.md` §2.
const String scrapItemName = 'السكرب';

// ═════════════════════════════════════════════════════════════════════════
// المصدر — `FR-M2`
// ═════════════════════════════════════════════════════════════════════════

/// مدخلات مصدر كما تصل من الواجهة — **قبل أي تحقق**.
final class SourceInput {
  /// ينشئ المدخلات.
  const SourceInput({
    required this.name,
    required this.requiresSupplierOnIntake,
    this.notes,
    this.isActive = true,
    this.disableReason,
  });

  /// الاسم المعروض.
  final String name;

  /// ★ **«يجب اختيار الرعوي عند التوريد»** — `FR-M2-01` · `FR-M2-02`.
  final bool requiresSupplierOnIntake;

  /// ملاحظات اختيارية.
  final String? notes;

  /// الحالة — ★ **والتعطيل بديل الحذف** (`FR-M2-05`).
  final bool isActive;

  /// ★ **إقرار التعطيل النصي** — `FR-M2-07`، ويُشترط عند [isActive] `false`.
  final String? disableReason;
}

/// مصدر مُتحقَّق منه — **بقيمه المُطبَّعة كما تُكتب**.
final class ValidatedSource {
  /// ينشئ المصدر المُتحقَّق منه.
  const ValidatedSource({
    required this.name,
    required this.normalizedName,
    required this.requiresSupplierOnIntake,
    required this.notes,
    required this.isActive,
    required this.disableReason,
  });

  /// الاسم مقصوص الأطراف.
  final String name;

  /// ★ الاسم المُطبَّع — **وعليه وحده يجري فحص التفرد** (`FR-M2-01`).
  final String normalizedName;

  /// إلزامية الرعوي عند التوريد.
  final bool requiresSupplierOnIntake;

  /// الملاحظات، أو `null` — ⛔ **والفارغ غيابٌ لا نصٌّ فارغ يُخزَّن**.
  final String? notes;

  /// الحالة.
  final bool isActive;

  /// سبب التعطيل، أو `null` إن كان نشطاً.
  final String? disableReason;
}

/// يفحص مصدراً عند الإنشاء أو التعديل — `FR-M2-01` · `FR-M2-07`.
Outcome<ValidatedSource> validateSource(SourceInput input) {
  final String name = input.name.trim();
  if (name.length < sourceNameMinLength || name.length > sourceNameMaxLength) {
    return const Failure<ValidatedSource>(ValidationError('FR-M2-01'));
  }
  final String normalized = normalizeName(name);
  // ⛔ **اسمٌ يخلو من أي محرف دالّ بعد التطبيع لا يصلح مفتاح تفرّد** — ★
  //    فمعرّف مستند الحراسة **هو القيمة المُطبَّعة نفسها**، والفارغ منها
  //    مسارٌ غير صالح أصلاً (`master-data-design.md` §3).
  if (normalized.isEmpty) {
    return const Failure<ValidatedSource>(ValidationError('FR-M2-01'));
  }

  final Outcome<String?> notes = _optionalText(input.notes, 'FR-M2-01');
  if (notes case Failure<String?>(:final AppError error)) {
    return Failure<ValidatedSource>(error);
  }

  final Outcome<String?> reason = _disableReason(
    isActive: input.isActive,
    reason: input.disableReason,
    ruleCode: 'FR-M2-07',
  );
  if (reason case Failure<String?>(:final AppError error)) {
    return Failure<ValidatedSource>(error);
  }

  return Success<ValidatedSource>(
    ValidatedSource(
      name: name,
      // ★ **من مصدر الحقيقة الواحد** (`IQ-013`) — ⛔ ولا تطبيع محلي هنا.
      normalizedName: normalized,
      requiresSupplierOnIntake: input.requiresSupplierOnIntake,
      notes: (notes as Success<String?>).value,
      isActive: input.isActive,
      disableReason: (reason as Success<String?>).value,
    ),
  );
}

// ═════════════════════════════════════════════════════════════════════════
// الرعوي — `FR-M3`
// ═════════════════════════════════════════════════════════════════════════

/// مدخلات رعوي.
final class SupplierInput {
  /// ينشئ المدخلات.
  const SupplierInput({
    required this.name,
    required this.phone,
    this.notes,
    this.isActive = true,
    this.disableReason,
  });

  /// الاسم.
  final String name;

  /// رقم الهاتف — ★ **وتفرّده على المُطبَّع** (`FR-M3-02`).
  final String phone;

  /// ملاحظات اختيارية.
  final String? notes;

  /// الحالة.
  final bool isActive;

  /// سبب التعطيل.
  final String? disableReason;
}

/// رعوي مُتحقَّق منه.
final class ValidatedSupplier {
  /// ينشئ الرعوي المُتحقَّق منه.
  ValidatedSupplier({
    required this.name,
    required this.normalizedName,
    required this.phone,
    required this.normalizedPhone,
    required this.notes,
    required this.isActive,
    required this.disableReason,
  });

  /// الاسم مقصوصاً.
  final String name;

  /// الاسم المُطبَّع — **للبحث لا للتفرد**؛ تفرّد الرعوي على الهاتف.
  final String normalizedName;

  /// الهاتف كما أُدخل.
  final String phone;

  /// ★ الهاتف المُطبَّع — **مفتاح التفرد** (`IQ-014`).
  final String normalizedPhone;

  /// الملاحظات أو `null`.
  final String? notes;

  /// الحالة.
  final bool isActive;

  /// سبب التعطيل أو `null`.
  final String? disableReason;
}

/// يفحص رعوياً — `FR-M3-01` · `FR-M3-02` · `FR-M3-06`.
Outcome<ValidatedSupplier> validateSupplier(SupplierInput input) {
  // ⛔⛔★★★ **ولا فحصَ مصادرَ هنا إطلاقاً** — `CR-006` (2026-08-31):
  //    ★ **الرعوي يتبع كل المصادر الحالية والمستقبلية تلقائياً**، ⟵ **تماماً
  //    كالمقوت** (`FR-M4-04`). ⛔ **وكان الفحص `_requiredSourceIds` يرفض
  //    رعوياً بلا مصدر**، ★ **وهو الشرط الذي أسقطه الطلب.**
  //
  // ⚠️★★ **وهذا لا يجمع حساباته:** `FR-M3-05` قائمٌ بحرفه — **حسابُه في كل
  //    مصدرٍ مستقل** بمفتاح `{supplierId}_{sourceId}` (`ADR-0005`).
  final String name = input.name.trim();
  if (name.length < partyNameMinLength || name.length > partyNameMaxLength) {
    return const Failure<ValidatedSupplier>(ValidationError('FR-M3-01'));
  }

  final Outcome<_Phone> phone = _requiredPhone(input.phone, 'FR-M3-02');
  if (phone case Failure<_Phone>(:final AppError error)) {
    return Failure<ValidatedSupplier>(error);
  }

  final Outcome<String?> notes = _optionalText(input.notes, 'FR-M3-01');
  if (notes case Failure<String?>(:final AppError error)) {
    return Failure<ValidatedSupplier>(error);
  }

  final Outcome<String?> reason = _disableReason(
    isActive: input.isActive,
    reason: input.disableReason,
    ruleCode: 'FR-M3-06',
  );
  if (reason case Failure<String?>(:final AppError error)) {
    return Failure<ValidatedSupplier>(error);
  }

  return Success<ValidatedSupplier>(
    ValidatedSupplier(
      name: name,
      normalizedName: normalizeName(name),
      phone: (phone as Success<_Phone>).value.raw,
      normalizedPhone: phone.value.normalized,
      notes: (notes as Success<String?>).value,
      isActive: input.isActive,
      disableReason: (reason as Success<String?>).value,
    ),
  );
}

// ═════════════════════════════════════════════════════════════════════════
// المقوت — `FR-M4`
// ═════════════════════════════════════════════════════════════════════════

/// مدخلات مقوت.
///
/// ⚠️⚠️ **ولا حقل مصدر فيها إطلاقاً** — `FR-M4-04` نصّاً: «**لا يُختار
/// للمقوت مصدر عند إنشائه إطلاقاً**». ★ **وحساباته سجلات مستقلة** مفتاحها
/// `{dealerId}_{sourceId}`، ⛔ **وإضافة حقل مصدر هنا خطأ بنيوي يهدم
/// `ADR-0005`** (`master-data-design.md` §7).
final class DealerInput {
  /// ينشئ المدخلات.
  const DealerInput({
    required this.name,
    required this.phone,
    this.notes,
    this.isActive = true,
    this.disableReason,
  });

  /// الاسم.
  final String name;

  /// الهاتف — ★ **فريد بين المقاوته بعد التطبيع** (`FR-M4-02`).
  final String phone;

  /// ملاحظات اختيارية.
  final String? notes;

  /// الحالة.
  final bool isActive;

  /// ★ **سبب التعطيل** — `data-dictionary.md` §`dealers`: **إلزامي عند
  /// التعطيل**.
  final String? disableReason;
}

/// مقوت مُتحقَّق منه.
final class ValidatedDealer {
  /// ينشئ المقوت المُتحقَّق منه.
  const ValidatedDealer({
    required this.name,
    required this.normalizedName,
    required this.phone,
    required this.normalizedPhone,
    required this.notes,
    required this.isActive,
    required this.disableReason,
  });

  /// الاسم مقصوصاً.
  final String name;

  /// الاسم المُطبَّع — للبحث.
  final String normalizedName;

  /// الهاتف كما أُدخل.
  final String phone;

  /// الهاتف المُطبَّع — **مفتاح التفرد**.
  final String normalizedPhone;

  /// الملاحظات أو `null`.
  final String? notes;

  /// الحالة.
  final bool isActive;

  /// سبب التعطيل أو `null`.
  final String? disableReason;
}

/// يفحص مقوتاً — `FR-M4-01` · `FR-M4-02` · `FR-M4-04`.
Outcome<ValidatedDealer> validateDealer(DealerInput input) {
  final String name = input.name.trim();
  if (name.length < partyNameMinLength || name.length > partyNameMaxLength) {
    return const Failure<ValidatedDealer>(ValidationError('FR-M4-01'));
  }

  final Outcome<_Phone> phone = _requiredPhone(input.phone, 'FR-M4-02');
  if (phone case Failure<_Phone>(:final AppError error)) {
    return Failure<ValidatedDealer>(error);
  }

  final Outcome<String?> notes = _optionalText(input.notes, 'FR-M4-01');
  if (notes case Failure<String?>(:final AppError error)) {
    return Failure<ValidatedDealer>(error);
  }

  final Outcome<String?> reason = _disableReason(
    isActive: input.isActive,
    reason: input.disableReason,
    ruleCode: 'FR-M4-09',
  );
  if (reason case Failure<String?>(:final AppError error)) {
    return Failure<ValidatedDealer>(error);
  }

  return Success<ValidatedDealer>(
    ValidatedDealer(
      name: name,
      normalizedName: normalizeName(name),
      phone: (phone as Success<_Phone>).value.raw,
      normalizedPhone: phone.value.normalized,
      notes: (notes as Success<String?>).value,
      isActive: input.isActive,
      disableReason: (reason as Success<String?>).value,
    ),
  );
}

// ═════════════════════════════════════════════════════════════════════════
// النوع — `FR-M5`
// ═════════════════════════════════════════════════════════════════════════

/// ⛔★★ الحقول التي **لا وجود لها في سجل النوع إطلاقاً** — `FR-M5-09`.
///
/// ★ **ولماذا قائمة تُرفَض لا حقولٌ تُتجاهَل بصمت:** نصّ المتطلب أن
/// «**قاعدة الحماية ترفض أي حقل سعر** على سجل الأنواع». ⟵ **والرفض
/// الصريح يكشف الخلل عند أول محاولة**، ⛔ **بينما التجاهل الصامت يجعل
/// الواجهة تُرسل سعراً فتظنّ أنه حُفظ.**
///
/// ⚠️ **والمقارنة تُطبَّع حالةَ الأحرف** — فـ`Price` مرفوض كـ`price` سواء.
const Set<String> forbiddenItemFields = <String>{
  'price',
  'distributionprice',
  'mincashprice',
};

/// مدخلات نوع.
final class ItemInput {
  /// ينشئ المدخلات.
  const ItemInput({
    required this.sourceIds,
    required this.name,
    required this.nature,
    this.pieceWeightGrams,
    this.isActive = true,
    this.disableReason,
    this.isSystemDefault = false,
    this.extraFields = const <String>{},
  });

  /// ★ **المصادر (اختيار متعدد)** — `FR-M5-01` · `FR-M5-10`.
  final List<String> sourceIds;

  /// الاسم — ★ **فريد على مستوى النظام بعد التطبيع** (`FR-M5-01`).
  final String name;

  /// عددي أم وزني.
  final ItemNature nature;

  /// ★ **وزن الحبة بالجرام — للوزني فقط واختياري** (`FR-M5-02` · `E-08`).
  ///
  /// ⛔ **وللعددي يُرفَض** — `E-09`: «نوع عددي أُدخل له وزن حبة يدوياً
  /// **يُرفَض** — الحقل مقفل».
  final double? pieceWeightGrams;

  /// الحالة.
  final bool isActive;

  /// سبب التعطيل.
  final String? disableReason;

  /// ★★ **النوع الافتراضي «السكرب»** — ⛅ **من السحابة فقط** (`FR-M5-05`).
  final bool isSystemDefault;

  /// ★ أسماء أي حقول إضافية وصلت في الحمولة — **تُفحَص مقابل الممنوعات**.
  final Set<String> extraFields;
}

/// نوع مُتحقَّق منه.
final class ValidatedItem {
  /// ينشئ النوع المُتحقَّق منه.
  ValidatedItem({
    required List<String> sourceIds,
    required this.name,
    required this.normalizedName,
    required this.nature,
    required this.pieceWeightGrams,
    required this.unit,
    required this.isSystemDefault,
    required this.isActive,
    required this.disableReason,
  }) : sourceIds = List<String>.unmodifiable(sourceIds);

  /// المصادر مرتبةً ومنزوعة التكرار.
  final List<String> sourceIds;

  /// الاسم مقصوصاً.
  final String name;

  /// ★ الاسم المُطبَّع — **مفتاح التفرد على مستوى النظام**.
  final String normalizedName;

  /// الطبيعة.
  final ItemNature nature;

  /// وزن الحبة أو `null`.
  final double? pieceWeightGrams;

  /// ★ الوحدة — **مشتقّة لا مُدخَلة** (راجع [unitOfItem]).
  final ItemUnit unit;

  /// هل هو النوع الافتراضي؟
  final bool isSystemDefault;

  /// الحالة.
  final bool isActive;

  /// سبب التعطيل أو `null`.
  final String? disableReason;
}

/// يفحص نوعاً — `FR-M5-01` · `FR-M5-02` · `FR-M5-09` · `E-08` · `E-09`.
Outcome<ValidatedItem> validateItem(ItemInput input) {
  // ① ⛔ **حقول السعر أولاً** — `FR-M5-09`: وجودُ أيٍّ منها يُبطل الطلب
  //    كاملاً بغضّ النظر عن صحة بقيته.
  for (final String field in input.extraFields) {
    if (forbiddenItemFields.contains(field.trim().toLowerCase())) {
      return const Failure<ValidatedItem>(ValidationError('FR-M5-09'));
    }
  }

  final Outcome<List<String>> sources =
      _requiredSourceIds(input.sourceIds, 'FR-M5-01');
  if (sources case Failure<List<String>>(:final AppError error)) {
    return Failure<ValidatedItem>(error);
  }

  final String name = input.name.trim();
  if (name.length < itemNameMinLength || name.length > itemNameMaxLength) {
    return const Failure<ValidatedItem>(ValidationError('FR-M5-01'));
  }
  final String normalized = normalizeName(name);
  if (normalized.isEmpty) {
    return const Failure<ValidatedItem>(ValidationError('FR-M5-01'));
  }

  // ② ★ **وزن الحبة للوزني وحده** — `FR-M5-02` · `E-09`.
  final double? weight = input.pieceWeightGrams;
  if (weight != null) {
    if (input.nature != ItemNature.weightBased) {
      return const Failure<ValidatedItem>(ValidationError('E-09'));
    }
    // ⛔ **وزنٌ غير موجب ليس قيمة ناقصة بل قيمة خاطئة** — والصفر يُنتج
    //    وزناً كلياً صفرياً لكل جونية، ⟵ **فسادُ حسابٍ صامت.**
    if (!weight.isFinite || weight <= 0) {
      return const Failure<ValidatedItem>(ValidationError('FR-M5-02'));
    }
  }

  final Outcome<String?> reason = _disableReason(
    isActive: input.isActive,
    reason: input.disableReason,
    ruleCode: 'FR-M5-12',
  );
  if (reason case Failure<String?>(:final AppError error)) {
    return Failure<ValidatedItem>(error);
  }

  return Success<ValidatedItem>(
    ValidatedItem(
      sourceIds: (sources as Success<List<String>>).value,
      name: name,
      normalizedName: normalized,
      nature: input.nature,
      pieceWeightGrams: weight,
      // ★ **مشتقّة لا مُدخَلة** — راجع [unitOfItem].
      unit: unitOfItem(isSystemDefault: input.isSystemDefault),
      isSystemDefault: input.isSystemDefault,
      isActive: input.isActive,
      disableReason: (reason as Success<String?>).value,
    ),
  );
}

/// ★★ يفحص أن التعديل لا يمسّ النوع الافتراضي — `FR-M5-05` · `BR-M5-10`.
///
/// ⚠️ **قيدٌ يعلو على الصلاحية لا يُستبدَل بها:** من يملك `itemWrite` يعدّل
/// كل نوع **إلا السكرب**. ⟵ ★ **«لا يُنشئه المستخدم ولا يحذفه ولا يُعطِّله
/// من أي واجهة»** — والإنشاء **من السحابة فقط** (`master-data-design.md` §5).
Outcome<void> validateSystemDefaultGuard({required bool storedIsSystemDefault}) =>
    storedIsSystemDefault
        ? const Failure<void>(ValidationError('FR-M5-05'))
        : const Success<void>(null);

/// ★★ يفحص أن وحدة النوع لم تُمَسّ — `FR-M5-04` · `BR-M5-11` · `GR-19`.
///
/// ⚠️ **ولماذا مطلقاً لا «بعد أول حركة»:** الوحدة **مشتقّة من
/// [ItemUnit]** لا مُدخَلة، ⟵ **فتغيّرها يعني تغيّر `isSystemDefault`**
/// وهو ممنوع أصلاً. ★ **والفحص هنا حزامٌ ثانٍ يكشف الانزلاق البرمجي**
/// قبل أن يفسد رصيداً تاريخياً.
Outcome<void> validateItemUnitUnchanged({
  required ItemUnit stored,
  required ItemUnit incoming,
}) =>
    stored == incoming
        ? const Success<void>(null)
        : const Failure<void>(ValidationError('FR-M5-04'));

// ═════════════════════════════════════════════════════════════════════════
// حرّاس التعطيل المقيسة — ⛔ **لا قيمةٌ مخزَّنة ولا كاش**
// ═════════════════════════════════════════════════════════════════════════

/// ★★ **إحصاءٌ مقيس لأرصدة المقوت** — `FR-M4-09` · `E-39`.
///
/// ⛔★★ **ولا مُنشِئ افتراضي له ولا قيمة صفرية جاهزة** — بنفس منطق
/// `RoleAssignmentCensus`: لو أمكن بناؤه «فارغاً» لصار **نسيانُ القياس**
/// طريقاً صامتاً إلى تعطيل مقوتٍ عليه دين. ⟵ ★ **فالمُنشِئ الوحيد اسمُه
/// [DealerBalanceCensus.measured]**، وهو **يُلزم مُستدعيه بأن يذكر من أين
/// جاءت الأرقام.**
final class DealerBalanceCensus {
  /// ينشئ الإحصاء من **قراءةٍ فعلية** لمستندات `dealer_balances`.
  ///
  /// [balancesBySource] الرصيد لكل مصدر كما قُرئ — ★ **بالريال عدداً
  /// صحيحاً** (`ADR-0015`).
  const DealerBalanceCensus.measured(this.balancesBySource);

  /// الأرصدة المقروءة بمفتاح مصدرها.
  final Map<String, int> balancesBySource;

  /// ★ هل له رصيد غير صفري في أي مصدر؟ — `FR-M4-09` («رصيده ≠ 0 **في أي
  /// مصدر**»)، ⛔ **ولا يُجمَع بين المصادر** (`FR-M4-06`).
  bool get hasNonZeroBalance =>
      balancesBySource.values.any((int balance) => balance != 0);

  /// المصادر ذات الرصيد غير الصفري — **لعرضها في رسالة الرفض** (`E-39`).
  List<String> get sourcesWithBalance => <String>[
        for (final MapEntry<String, int> entry in balancesBySource.entries)
          if (entry.value != 0) entry.key,
      ]..sort();
}

/// ★ يفحص تعطيل مقوت — `FR-M4-09` **بشطريه معاً**.
///
/// ✅★★★ **واكتمل بحسم `IQ-020` الخيار أ (2026-08-25):** أُضيف المفتاح
/// المستقل `dealerDisableWithBalance` إلى `permissions-catalog.md` §2.1،
/// ⟵ **فزال الانحراف المعلَن و`DEBT-26` سُدِّد** — ⛔ **ولم يُعدَّل
/// `FR-M4-09` ولا أُنشئ `CR`**: القرار **استكمالُ الكتالوج لتنفيذ المتطلب
/// كما هو**.
///
/// ⛔⛔★★ **وتعطيلُ مقوتٍ رصيدُه ≠ 0 يشترط ثلاثةً معاً — ولا يكفي اثنان:**
/// ① [canDisableWithBalance] — **امتلاك المفتاح المستقل** · ② إقرارٌ نصّي
/// غير فارغ · ③ [census] **مقيسٌ من `dealer_balances` داخل المعاملة**
/// ⛔ **لا قيمةٌ مرسلة من الجهاز** (يحرسه [DealerBalanceCensus.measured]).
///
/// ★★ **وترتيب الفحص مقصود: الرصيد أولاً.** ⟵ **فمقوتٌ رصيدُه صفر لا
/// يُشترَط له المفتاح إطلاقاً** — ⛔ **والمفتاح ليس بديلاً عن `dealerWrite`
/// في التعطيل العادي**، بل **شرطٌ إضافي** على الحالة الاستثنائية وحدها.
///
/// ★ **ويفترقان في نوع الخطأ لا في رمزٍ واحد جامع:** نقصُ الصلاحية
/// [PermissionError] · ونقصُ الإقرار [ValidationError] — ⟵ **فالمستدعي
/// يُميّز «ليست لك» من «اكتب إقراراً»** ⛔ **ولا يُخفي أحدَهما الآخر.**
Outcome<void> validateDealerDeactivation({
  required DealerBalanceCensus census,
  required String? acknowledgement,
  required bool canDisableWithBalance,
}) {
  if (!census.hasNonZeroBalance) return const Success<void>(null);
  if (!canDisableWithBalance) {
    return const Failure<void>(PermissionError());
  }
  final String? text = acknowledgement?.trim();
  if (text == null || text.isEmpty) {
    return const Failure<void>(ValidationError('FR-M4-09'));
  }
  return const Success<void>(null);
}

// ═════════════════════════════════════════════════════════════════════════
// الإعداد التأسيسي — `FR-M21`
// ═════════════════════════════════════════════════════════════════════════

/// مدخلات الإعداد التأسيسي — **البندان معاً في كتابة واحدة**.
final class AppSettingsInput {
  /// ينشئ المدخلات.
  const AppSettingsInput({
    required this.businessName,
    required this.currencySymbol,
    this.logo,
    this.phone,
    this.address,
    this.thousandsSeparator = ',',
  });

  /// اسم المحل — `FR-M21-01`.
  final String businessName;

  /// رمز العملة — **الريال اليمني** (`A-02` · `FR-M21-02`).
  final String currencySymbol;

  /// مرجع الشعار — اختياري.
  final String? logo;

  /// هاتف المنشأة — اختياري.
  final String? phone;

  /// عنوان المنشأة — اختياري.
  final String? address;

  /// فاصل الآلاف.
  final String thousandsSeparator;
}

/// إعداد تأسيسي مُتحقَّق منه.
final class ValidatedAppSettings {
  /// ينشئ الإعداد المُتحقَّق منه.
  const ValidatedAppSettings({
    required this.businessName,
    required this.currencySymbol,
    required this.logo,
    required this.phone,
    required this.address,
    required this.thousandsSeparator,
  });

  /// اسم المحل.
  final String businessName;

  /// رمز العملة.
  final String currencySymbol;

  /// الشعار أو `null`.
  final String? logo;

  /// الهاتف مُطبَّعاً أو `null`.
  final String? phone;

  /// العنوان أو `null`.
  final String? address;

  /// فاصل الآلاف.
  final String thousandsSeparator;

  /// ★★ **بلا كسور عشرية للمبالغ — حتماً** (`FR-M21-02` · `ADR-0015`).
  ///
  /// ⛔★★ **وليست حقلاً يُدخِله المستخدم:** `ADR-0015` يجعل كل مبلغ **عدداً
  /// صحيحاً بالريال**، ⟵ **فقيمةٌ غير الصفر هنا كانت ستَعِد بعرضٍ لا
  /// يقابله تخزين** — ★ **وهي «إعداد عرض لا يُغيّر التخزين»**
  /// (`data-dictionary.md` §`app_settings`). ⛔ **فثابتة لا خيار.**
  int get decimalPlaces => 0;

  /// حقول مستند بيانات المنشأة.
  Map<String, Object?> get businessFields => <String, Object?>{
        'businessName': businessName,
        'logo': logo,
        'phone': phone,
        'address': address,
      };

  /// حقول مستند العملة والأرقام.
  Map<String, Object?> get formattingFields => <String, Object?>{
        'currencySymbol': currencySymbol,
        'decimalPlaces': decimalPlaces,
        'thousandsSeparator': thousandsSeparator,
      };
}

/// ★★★ **سببُ رفضِ الإعداد التأسيسي — مُصنَّفٌ بحقلِه** (`AM-018`).
///
/// ⛔⛔★★★ **ولماذا مُصنَّفٌ ولا تكفي رسالةٌ عامة:** ★ **شاشةُ الإعداد
/// التأسيسي لا رجعةَ فيها** (`FR-M21-03`: «**مرة واحدة فقط، والتعديل والحذف
/// مرفوضان نهائياً**») — ⟵ **ومستخدمٌ رُفض إدخالُه برسالةٍ واحدةٍ أمام خمسةِ
/// حقولٍ لا يعرف أيَّها يُصحِّح**، ★ **فيعبث بالصحيح ويترك المعيب.**
///
/// ★ **وهو نظيرُ `PasswordChangeRejection` حرفياً** — ⛔ **ولا آليةٌ موازية.**
enum AppSettingsRejection {
  /// ⛔ اسمُ المحل خارج الحدّين — `FR-M21-01`.
  businessName,

  /// ⛔ رمزُ العملة فارغٌ أو أطولُ من ثمانية محارف — `FR-M21-02`.
  currencySymbol,

  /// ⛔ فاصلُ الآلاف بأكثر من محرفٍ واحد — `FR-M21-02`.
  ///
  /// ⚠️ **والفراغُ خيارٌ صحيح** («بلا فاصل») — ★ **فالمرفوضُ الطولُ لا الفراغ.**
  thousandsSeparator,

  /// ⛔ العنوانُ الاختياري خارج حدّه — `FR-M21-01`.
  address,

  /// ⛔ مسارُ الشعار الاختياري خارج حدّه — `FR-M21-01`.
  logo,
}

/// ★ يقرأ سببَ الرفض من رمز القاعدة — و`null` لما ليس من هذه العائلة.
AppSettingsRejection? appSettingsRejectionOf(String code) => switch (code) {
      'AppSettingsRejection.businessName' => AppSettingsRejection.businessName,
      'AppSettingsRejection.currencySymbol' =>
        AppSettingsRejection.currencySymbol,
      'AppSettingsRejection.thousandsSeparator' =>
        AppSettingsRejection.thousandsSeparator,
      'AppSettingsRejection.address' => AppSettingsRejection.address,
      'AppSettingsRejection.logo' => AppSettingsRejection.logo,
      _ => null,
    };

/// يفحص الإعداد التأسيسي — `FR-M21-01` · `FR-M21-02`.
///
/// ★★ **ورمزُ الرفض يُسمّي حقلَه** منذ `AM-018` — راجع [AppSettingsRejection].
Outcome<ValidatedAppSettings> validateAppSettings(AppSettingsInput input) {
  final String businessName = input.businessName.trim();
  if (businessName.length < sourceNameMinLength ||
      businessName.length > sourceNameMaxLength) {
    return const Failure<ValidatedAppSettings>(
      ValidationError('AppSettingsRejection.businessName'),
    );
  }

  final String currency = input.currencySymbol.trim();
  if (currency.isEmpty || currency.length > 8) {
    return const Failure<ValidatedAppSettings>(
      ValidationError('AppSettingsRejection.currencySymbol'),
    );
  }

  final String separator = input.thousandsSeparator;
  // ⛔ **فاصلٌ بأكثر من محرف واحد يكسر تنسيق كل مبلغ في النظام** — والفراغ
  //    خيارٌ صحيح («بلا فاصل»)، ★ **فالمرفوض هو الطول لا الفراغ.**
  if (separator.length > 1) {
    return const Failure<ValidatedAppSettings>(
      ValidationError('AppSettingsRejection.thousandsSeparator'),
    );
  }

  final Outcome<String?> address =
      _optionalText(input.address, 'AppSettingsRejection.address');
  if (address case Failure<String?>(:final AppError error)) {
    return Failure<ValidatedAppSettings>(error);
  }
  final Outcome<String?> logo =
      _optionalText(input.logo, 'AppSettingsRejection.logo');
  if (logo case Failure<String?>(:final AppError error)) {
    return Failure<ValidatedAppSettings>(error);
  }

  final String? rawPhone = input.phone?.trim();
  return Success<ValidatedAppSettings>(
    ValidatedAppSettings(
      businessName: businessName,
      currencySymbol: currency,
      logo: (logo as Success<String?>).value,
      phone: (rawPhone == null || rawPhone.isEmpty)
          ? null
          : normalizePhone(rawPhone),
      address: (address as Success<String?>).value,
      thousandsSeparator: separator,
    ),
  );
}

/// ★★ يفحص أن الإعداد **لم يُكتب من قبل** — `FR-M21-03` · `AT-65`.
///
/// ⚠️ **والفحص على وجود أيٍّ من المستندين لا كليهما:** كتابةٌ جزئية سابقة
/// (نجح أحدهما وفشل الآخر) **حالةٌ لا يجوز أن تُكمَّل بكتابةٍ ثانية**، ⟵
/// **فالمعاملة ذرّية أصلاً** ⛔ **ووجودُ أحدهما يعني أن الكتابة الأولى تمّت.**
Outcome<void> validateAppSettingsUnwritten({
  required bool businessExists,
  required bool formattingExists,
}) =>
    (businessExists || formattingExists)
        ? const Failure<void>(ValidationError('FR-M21-03'))
        : const Success<void>(null);

// ═════════════════════════════════════════════════════════════════════════
// مشتركات
// ═════════════════════════════════════════════════════════════════════════

/// نتيجة تطبيع هاتف — الخام والمُطبَّع معاً.
final class _Phone {
  const _Phone({required this.raw, required this.normalized});

  final String raw;
  final String normalized;
}

Outcome<_Phone> _requiredPhone(String value, String ruleCode) {
  final String raw = value.trim();
  if (raw.isEmpty) return Failure<_Phone>(ValidationError(ruleCode));
  final String normalized = normalizePhone(raw);
  // ⛔ **رقمٌ يخلو من أي خانة بعد التطبيع لا يصلح مفتاح تفرّد** — ومعرّف
  //    مستند الحراسة **هو القيمة المُطبَّعة نفسها**.
  if (normalized.isEmpty) return Failure<_Phone>(ValidationError(ruleCode));
  return Success<_Phone>(_Phone(raw: raw, normalized: normalized));
}

/// ★ يفحص قائمة المصادر — **غير فارغة، مرتبة، منزوعة التكرار**.
///
/// ⚠️ **والترتيب ونزع التكرار ليسا تجميلاً:** المستند يُقارَن بقيده في سجل
/// التدقيق، ⟵ **وقائمةٌ بترتيبٍ مختلف تُقرأ «تغيّرت» وهي لم تتغيّر.**
Outcome<List<String>> _requiredSourceIds(List<String> raw, String ruleCode) {
  final Set<String> unique = <String>{
    for (final String id in raw)
      if (id.trim().isNotEmpty) id.trim(),
  };
  if (unique.isEmpty) {
    return Failure<List<String>>(ValidationError(ruleCode));
  }
  return Success<List<String>>(unique.toList()..sort());
}

/// ★ نصّ اختياري مقصوصاً، أو `null` — ⛔ **والفارغ غيابٌ لا نصٌّ فارغ**.
Outcome<String?> _optionalText(String? value, String ruleCode) {
  final String? text = value?.trim();
  if (text == null || text.isEmpty) return const Success<String?>(null);
  if (text.length > freeTextMaxLength) {
    return Failure<String?>(ValidationError(ruleCode));
  }
  return Success<String?>(text);
}

/// ★★ **سبب التعطيل إلزامي عند التعطيل وحده** — `data-dictionary.md`
/// §`dealers` («**إلزامي عند التعطيل**») · `FR-M2-07` · `FR-M4-09`.
///
/// ⛔ **والسجل النشط لا يحمل سبباً** — ★ **فسببٌ باقٍ بعد إعادة التفعيل
/// يجعل السجل يقول «معطَّل لأن…» وهو نشط.**
Outcome<String?> _disableReason({
  required bool isActive,
  required String? reason,
  required String ruleCode,
}) {
  if (isActive) return const Success<String?>(null);
  final String? text = reason?.trim();
  if (text == null || text.isEmpty) {
    return Failure<String?>(ValidationError(ruleCode));
  }
  if (text.length > freeTextMaxLength) {
    return Failure<String?>(ValidationError(ruleCode));
  }
  return Success<String?>(text);
}

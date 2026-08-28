/// الوارد عدداً (`M6`) — ★ **أسرع مسار توريد: عملية كمية بحتة**.
///
/// ★ **المصدر:** `FR-M6-01` … `FR-M6-16` · `schema/incoming-count.md` ·
/// `data-dictionary.md` §2 · `inventory-design.md` §2.
///
/// ⛔★★ **ولا وزن ولا ضريبة ولا سعر في هذه الوحدة إطلاقاً** (`FR-M6-10`) —
/// ★ **ولا يُنشئ حساباً للرعوي**، ⟵ **والرعوي هنا مجرّد إسنادٍ مشروط**
/// (`FR-M6-03`) ⛔ **لا طرفٌ مالي.**
///
/// ⛔★★ **ويدخل المخزون بالاسم المجرَّد لا المركّب** (`FR-M6-09` · `BR-M6-10`)
/// — ⟵ ★ **فلا يدخل احتساب سعر أي جونية**: `sackId` **غائبٌ عن حركاته**،
/// وهو الحقل الذي يُبنى عليه سعر الجونية (`schema/inventory-ledger.md`).
///
/// ⚠️⚠️ **وتاريخ التوريد تاريخُ اليوم من الخادم، مقفلٌ لا يُغيَّر إطلاقاً —
/// لا للمالك ولا لغيره** (`FR-M6-02` · `BR-M6-02` · `A-10` · `GR-14`).
/// ⟵ **ولذلك لا حقل تاريخ في [CountedIntakeInput] أصلاً**: ★ **ما لا يُدخَل
/// لا يُزوَّر** — ⛔ **والحقل الغائب أقوى من الحقل المرفوض.**
library;

import '../../../core/errors/app_error.dart';
import '../../../core/outcome.dart';
import '../../../core/quantity.dart';
import '../../master_data/domain/master_data.dart' show ItemUnit, freeTextMaxLength;
import 'inventory.dart';

/// حالة مستند الوارد — `data-dictionary.md` §2 (`status`).
enum CountedIntakeStatus {
  /// معتمد — ★ **ولا مسودّات في هذه الوحدة** (`FR-M6-08`: الاعتماد يُنشئ الحركة).
  approved,

  /// ★ ملغى — **بالوسم لا بحركة عكسية** (`FR-M6-13` · `GR-06`).
  cancelled,
}

/// سطر وارد كما يصل من الواجهة — **قبل أي تحقق**.
final class CountedIntakeLineInput {
  /// ينشئ المدخلات.
  const CountedIntakeLineInput({
    required this.itemId,
    required this.itemName,
    required this.unit,
    required this.quantity,
    this.note,
  });

  /// معرّف النوع — ★ **وهو `itemKey` في الدفتر** (راجع [ValidatedCountedIntakeLine.itemKey]).
  final String itemId;

  /// اسم النوع المعروض — ★ **نسخةٌ مقصودة** (`naming-conventions.md` §4).
  final String itemName;

  /// وحدة النوع — ★ **مقروءةٌ من سجل النوع** ⛔ **لا مُدخَلة** (`FR-M5-03`).
  final ItemUnit unit;

  /// ★ **العدد — صحيحٌ موجب فقط** (`FR-M6-06` · `BR-M6-06`).
  final int quantity;

  /// ملاحظة السطر — اختيارية.
  final String? note;
}

/// سطر وارد مُتحقَّق منه.
final class ValidatedCountedIntakeLine {
  /// ينشئ السطر.
  const ValidatedCountedIntakeLine({
    required this.itemId,
    required this.itemName,
    required this.quantity,
    required this.note,
  });

  /// معرّف النوع.
  final String itemId;

  /// ★ **مفتاح النوع في الدفتر** — `FR-M6-09`: **الاسم المجرَّد لا المركّب**.
  ///
  /// ★★ **ولماذا المعرّف لا الاسم:** الاسم **يتغيّر بالتعديل** (`FR-M5-01`)
  /// بينما مفتاح الرصيد `{sourceId}_{itemKey}_{stockDate}` **يجب أن يثبت**،
  /// ⟵ **فاسمٌ متغيّر مفتاحاً كان يُنشئ رصيداً ثانياً لنفس النوع بصمت.**
  String get itemKey => itemId;

  /// الاسم المعروض لحظة الإدخال.
  final String itemName;

  /// ★ الكمية — **حبّاتٌ دائماً في هذه الوحدة** (راجع [validateCountedIntake]).
  final PieceCount quantity;

  /// الملاحظة أو `null` — ⛔ **والفارغ غيابٌ لا نصٌّ فارغ**.
  final String? note;

  /// الكمية بوحدتها — **للدفتر**.
  StockQuantity get stockQuantity => PieceQuantity(quantity);
}

/// مدخلات مستند وارد عدداً.
final class CountedIntakeInput {
  /// ينشئ المدخلات.
  const CountedIntakeInput({
    required this.sourceId,
    required this.sourceRequiresSupplier,
    required this.lines,
    this.supplierId,
    this.notes,
  });

  /// المصدر — ★ **إلزامي، ومخزنُه وحده يتأثر** (`FR-M6-08` · `AT-05`).
  final String sourceId;

  /// ★ **هل المصدر مُعلَّم بـ«يجب اختيار الرعوي»؟** — `FR-M2-02`.
  ///
  /// ⚠️ **تُقرأ من سجل المصدر ⛔ لا تُرسَل من الجهاز** — راجع
  /// [validateCountedIntake].
  final bool sourceRequiresSupplier;

  /// سطور المستند — ★ **بلا حدّ أعلى** (`FR-M6-04`) ⛔ **ولا فارغة**.
  final List<CountedIntakeLineInput> lines;

  /// ★ الرعوي — **يُخزَّن فقط إن كان المصدر يشترطه** (`FR-M6-03`).
  final String? supplierId;

  /// ملاحظات المستند.
  final String? notes;
}

/// مستند وارد مُتحقَّق منه — **جاهز للكتابة كما هو**.
final class ValidatedCountedIntake {
  /// ينشئ المستند.
  ValidatedCountedIntake({
    required this.sourceId,
    required this.supplierId,
    required this.notes,
    required List<ValidatedCountedIntakeLine> lines,
  }) : lines = List<ValidatedCountedIntakeLine>.unmodifiable(lines);

  /// المصدر.
  final String sourceId;

  /// ★ الرعوي أو `null` — ⛔ **ولا يُخزَّن إن كان المصدر لا يشترطه**
  /// (`FR-M6-03`: «**وإلا لا يُعرض ولا يُخزَّن أصلاً**»).
  final String? supplierId;

  /// ملاحظات المستند أو `null`.
  final String? notes;

  /// السطور **مرتَّبةً بمفتاح النوع** — ★ **فنفس الإدخال يُنتج نفس المستند**
  /// في كل تشغيل (`coding-standards.md` §2.7 · إعادة المحاولة بلا أثر).
  final List<ValidatedCountedIntakeLine> lines;

  /// ★ إجمالي الحبّات — `data-dictionary.md` §2 (`totalQuantity` 🧮).
  ///
  /// ⛔★★ **ولا إجمالي مختلط:** كل سطور هذه الوحدة **بالحبّة** (راجع
  /// [validateCountedIntake])، ⟵ **فالإجمالي الواحد صحيحٌ هنا بلا استثناء**
  /// ⛔ **ولا يُقاس عليه مستندٌ يخلط الوحدتين** (`FR-M8-07` · `GR-19`).
  PieceCount get totalQuantity {
    PieceCount total = PieceCount.zero;
    for (final ValidatedCountedIntakeLine line in lines) {
      total = total + line.quantity;
    }
    return total;
  }
}

/// ★ الحدّ الأدنى لعدد السطور — **مستندٌ بلا سطر لا يُنشئ حركة فلا معنى له**.
const int countedIntakeMinLines = 1;

/// يفحص مستند وارد عدداً — `FR-M6-03` … `FR-M6-10`.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ★★ **خمسة قيود تُفحَص هنا، وكلها كانت قواعدَ حماية قبل `WU-026`:**
///
///   ① **المصدر إلزامي** (`FR-M6-08`) — ⛔ ولا حركة بلا مخزن.
///   ② **الرعوي إلزامي إن اشترطه المصدر، ومرفوضٌ إن لم يشترطه** (`FR-M6-03`).
///   ③ **العدد صحيحٌ موجب** (`FR-M6-06`) — ⛔ **والكسر مرفوض في النوع نفسه**.
///   ④ **لا سطران لنفس النوع** (`FR-M6-07`) — ★ **والرسالة `ERR_INTAKE_008`.**
///   ⑤ ⛔ **ولا وحدةَ غير الحبّة** — `FR-M6-10` («لا وزن إطلاقاً») ×
///      `FR-M5-03` (**الكيلوجرام للسكرب وحده**) ⟵ **والسكرب يدخل من الجونية
///      لا من هنا** (`design-overview.md` §2.2).
/// ═══════════════════════════════════════════════════════════════════════
///
/// ⚠️⚠️ **والقيد ② في الاتجاهين لا في اتجاه واحد:** نصّ `FR-M6-03`
/// «**وإلا لا يُعرض ولا يُخزَّن أصلاً**» — ⟵ ★ **فرعويٌّ وصل لمصدرٍ لا
/// يشترطه يُرفَض** ⛔ **ولا يُطرَح صامتاً**: طرحُه الصامت يجعل الواجهة تظنّ
/// أنها خزّنت إسناداً لم يُخزَّن.
Outcome<ValidatedCountedIntake> validateCountedIntake(
  CountedIntakeInput input,
) {
  final String sourceId = input.sourceId.trim();
  if (sourceId.isEmpty) {
    return const Failure<ValidatedCountedIntake>(ValidationError('FR-M6-08'));
  }

  // ② الرعوي — في الاتجاهين معاً.
  final String? supplierId = input.supplierId?.trim();
  final bool hasSupplier = supplierId != null && supplierId.isNotEmpty;
  if (input.sourceRequiresSupplier && !hasSupplier) {
    return const Failure<ValidatedCountedIntake>(ValidationError('FR-M6-03'));
  }
  if (!input.sourceRequiresSupplier && hasSupplier) {
    return const Failure<ValidatedCountedIntake>(ValidationError('FR-M6-03'));
  }

  if (input.lines.length < countedIntakeMinLines) {
    return const Failure<ValidatedCountedIntake>(ValidationError('FR-M6-04'));
  }

  final Outcome<List<ValidatedCountedIntakeLine>> lines =
      _validateLines(input.lines);
  if (lines case Failure<List<ValidatedCountedIntakeLine>>(:final AppError error)) {
    return Failure<ValidatedCountedIntake>(error);
  }

  final Outcome<String?> notes = _optionalNote(input.notes);
  if (notes case Failure<String?>(:final AppError error)) {
    return Failure<ValidatedCountedIntake>(error);
  }

  return Success<ValidatedCountedIntake>(
    ValidatedCountedIntake(
      sourceId: sourceId,
      supplierId: hasSupplier ? supplierId : null,
      notes: (notes as Success<String?>).value,
      lines: (lines as Success<List<ValidatedCountedIntakeLine>>).value,
    ),
  );
}

Outcome<List<ValidatedCountedIntakeLine>> _validateLines(
  List<CountedIntakeLineInput> raw,
) {
  final Set<String> seen = <String>{};
  final List<ValidatedCountedIntakeLine> validated =
      <ValidatedCountedIntakeLine>[];

  for (final CountedIntakeLineInput line in raw) {
    final String itemId = line.itemId.trim();
    if (itemId.isEmpty) {
      return const Failure<List<ValidatedCountedIntakeLine>>(
        ValidationError('FR-M6-04'),
      );
    }
    // ④ ⛔ **لا سطران لنفس النوع** — `FR-M6-07` · `BR-M6-05` · `ERR_INTAKE_008`.
    if (!seen.add(itemId)) {
      return const Failure<List<ValidatedCountedIntakeLine>>(
        ValidationError('BR-M6-05'),
      );
    }
    // ⑤ ⛔ **ولا وحدة غير الحبّة في هذه الوحدة** — راجع ترويسة الدالة.
    if (line.unit != ItemUnit.piece) {
      return const Failure<List<ValidatedCountedIntakeLine>>(
        ValidationError('FR-M6-10'),
      );
    }
    // ③ ⛔ **موجبٌ تماماً** — والصفر ليس توريداً، والسالب سحبٌ لا وارد.
    if (line.quantity <= 0) {
      return const Failure<List<ValidatedCountedIntakeLine>>(
        ValidationError('BR-M6-06'),
      );
    }

    final String name = line.itemName.trim();
    if (name.isEmpty) {
      return const Failure<List<ValidatedCountedIntakeLine>>(
        ValidationError('FR-M6-04'),
      );
    }

    final Outcome<String?> note = _optionalNote(line.note);
    if (note case Failure<String?>(:final AppError error)) {
      return Failure<List<ValidatedCountedIntakeLine>>(error);
    }

    validated.add(
      ValidatedCountedIntakeLine(
        itemId: itemId,
        itemName: name,
        quantity: PieceCount(line.quantity),
        note: (note as Success<String?>).value,
      ),
    );
  }

  // ★ **ترتيبٌ ثابت** — راجع [ValidatedCountedIntake.lines].
  validated.sort(
    (ValidatedCountedIntakeLine a, ValidatedCountedIntakeLine b) =>
        a.itemKey.compareTo(b.itemKey),
  );
  return Success<List<ValidatedCountedIntakeLine>>(validated);
}

Outcome<String?> _optionalNote(String? value) {
  final String? text = value?.trim();
  if (text == null || text.isEmpty) return const Success<String?>(null);
  if (text.length > freeTextMaxLength) {
    return const Failure<String?>(ValidationError('FR-M6-04'));
  }
  return Success<String?>(text);
}

// ═════════════════════════════════════════════════════════════════════════
// التعديل والإلغاء — ★ **على الحركة نفسها** ⛔ **بلا حركة عكسية** (`A-14`)
// ═════════════════════════════════════════════════════════════════════════

/// ★★ **يفحص أن التغيير لا يُنتج رصيداً سالباً** — `FR-M6-12` · `FR-M6-13`.
///
/// ★ **قاعدةٌ واحدة تُغطّي الحالتين، وليس صدفةً:** التخفيض والإلغاء **كلاهما
/// يسحب كمية دخلت**، ⟵ **والسؤال في الاثنين واحد: هل بقي في مخزون ذلك اليوم
/// ما يكفي؟** ⛔ **ونسختان من الفحص كانتا ستفترقان** (`coding-standards.md` §2.2).
///
/// [balanceAfterChange] هو الرصيد **بعد تطبيق التغيير**، مجموعاً من الدفتر
/// داخل المعاملة ⛔ **لا من الملخص ولا من الجهاز** (`ADR-0008`).
///
/// ⚠️ **والفرق بين الحالتين في رمز الرسالة لا في القاعدة:** التخفيض يُبلَّغ
/// بـ`ERR_AMEND_003` والإلغاء بـ`ERR_STOCK_001` — ★ **والتمييز مسؤولية
/// المُستدعي** لأنه وحده يعرف أيَّ فعلٍ طلب المستخدم.
Outcome<void> validateStockChangeKeepsBalance(
  StockQuantity balanceAfterChange,
) =>
    validateNonNegativeBalance(balanceAfterChange);

/// ★ يفحص أن المستند ليس ملغى قبل تعديله — `ERR_AMEND_006`.
///
/// ⛔★★ **والملغى لا يُعدَّل ولا يُلغى ثانيةً:** الإلغاء **نهائي بالوسم**
/// (`FR-M6-13`)، ⟵ **وتعديلُ ملغىً يُعيد كميةً إلى الرصيد من مستندٍ خرج
/// من الحساب** — ★ **وهو فسادُ رصيدٍ صامت.**
Outcome<void> validateNotCancelled(CountedIntakeStatus status) =>
    status == CountedIntakeStatus.cancelled
        ? const Failure<void>(ValidationError('ERR_AMEND_006'))
        : const Success<void>(null);

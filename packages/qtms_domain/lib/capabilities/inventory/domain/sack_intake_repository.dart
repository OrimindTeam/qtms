/// عقود مستودعات الجواني (`M7`) — **قراءةً وكتابةً**.
///
/// ★ **الفصل مقصود ويطابق `ADR-0013`:** القراءة **مباشرة من القاعدة**
/// (القاعدة 4)، **والكتابة عبر دالة سحابية مستدعاة** تكتب المستند وحركاته
/// وأرصدته **وقيدَ تدقيقه في معاملة واحدة** (القاعدة 1).
///
/// ⛔★★ **و`sacks` مغلقة للكتابة تماماً** — `firestore.rules` §`sacks`:
/// `allow create, update: if false` — ⟵ **فكل دالة هنا طلبٌ لا كتابة.**
///
/// ═══════════════════════════════════════════════════════════════════════
/// ★★★ **ولماذا سبع دوال كتابة لا واحدة — وهو أهم ما في هذا الملف:**
/// `FR-M7-27` نصّاً: «**مسارات كتابة منفصلة لكل مجموعة حقول** (الاسم الظاهر ·
/// الضريبة · السطور · وزن الحبة · الأسعار · الوزن الضائع) — **كل منها يشترط
/// صلاحيته المطابقة**». ⟵ ★ **فدالةٌ جامعة كانت تُلزم من يُدخل الضريبة
/// بامتلاك صلاحية إدخال الأنواع**، ⛔ **وهو توسيعُ امتيازٍ يخالف التفكيك
/// المقصود في `§9.6`.**
/// ═══════════════════════════════════════════════════════════════════════
library;

import '../../../core/calendar_day.dart';
import '../../../core/money.dart';
import '../../../core/outcome.dart';
import '../../../core/quantity.dart';
import 'sack_intake.dart';

/// 🔒 **مالية الجونية** — مستند `sacks/{id}/finance/current` (`ADR-0011`).
///
/// ⚠️⚠️ **ونوعٌ مستقل عن [SackCard] عمداً لا تجميلاً:** قراءتُه محكومة
/// بـ`sackFinanceView` **وحدها**، ⟵ **ودمجُه في بطاقة الجونية كان يجعل
/// الشاشة تفترض أنها تملكه** ⛔ **ثم تُفاجَأ برفض القراءة عند التشغيل.**
final class SackFinanceCard {
  /// ينشئ البطاقة.
  const SackFinanceCard({
    required this.sackId,
    required this.sourceId,
    this.taxPerKilo,
    this.sackTax,
    this.sackRevenue,
    this.supplierNet,
  });

  /// رقم الجونية.
  final String sackId;

  /// ★ نسخة المصدر — **ليُفحَص النطاق بلا قراءة إضافية للأب** (القواعد).
  final String sourceId;

  /// 🔵 قيمة ضريبة الكيلو — ⛔ **و`null` تعني «معلّقة»** (`FR-M7-10`).
  final Money? taxPerKilo;

  /// ★ ضريبة الجونية المحسوبة والمخزَّنة عدداً صحيحاً (`FR-M7-11`).
  final Money? sackTax;

  /// ⛅ **الإيراد الفعلي المتحقق** — ⛔ **ولا كاتبَ له في `WU-004`**
  /// (`M14` — المرحلة الثانية).
  final Money? sackRevenue;

  /// ★ صافي الرعوي = السعر − الضريبة — ⛔ **ولا كاتبَ له في `WU-004`**.
  final Money? supplierNet;

  /// ★ **هل الضريبة معلّقة؟** — مصدر بند المركز المعلّق (`FR-M7-10`).
  bool get isTaxPending => taxPerKilo == null;
}

/// بطاقة جونية — مستند `sacks/{documentNumber}`.
///
/// ⛔★★ **وبلا أي حقل مالي** — `ADR-0011`: **الحقول المالية معزولة في
/// [SackFinanceCard]**، ⟵ **وقاعدة الحماية ترفض أياً منها في الأب.**
final class SackCard {
  /// ينشئ البطاقة.
  SackCard({
    required this.documentNumber,
    required this.sourceId,
    required this.stockDate,
    required this.entryDate,
    required this.dailySequence,
    required this.displayName,
    required this.status,
    required this.weights,
    required this.explanation,
    required this.lostWeightConfirmed,
    required List<ValidatedSackLine> lines,
    this.supplierId,
    this.supplierName,
    this.scrapItemKey,
    this.notes,
    this.lostWeightNote,
    this.cancelReason,
    this.isPricingComplete = false,
    this.amendCount = 0,
  }) : lines = List<ValidatedSackLine>.unmodifiable(lines);

  /// رقم المستند — `SCK-YYYYMMDD-####`.
  final String documentNumber;

  /// المصدر.
  final String sourceId;

  /// ★ تاريخ المخزون — 🔒 **من الخادم ولا يُغيَّر** (`FR-M7-02`).
  final CalendarDay stockDate;

  /// تاريخ الإدخال.
  final DateTime entryDate;

  /// ★★ **الرقم المتسلسل اليومي** — ⛅ **من السحابة · مستقل لكل مصدر**.
  ///
  /// ⛔★★ **«لا يُعاد استخدامه ولا يتغيّر أبداً»** (`ADR-0007` القاعدة 3)
  /// — حتى لو غُيِّر [displayName] أو أُلغيت الجونية.
  final int dailySequence;

  /// ★ الاسم الظاهر — **قابل للتعديل بصلاحية `sackRenameDisplay`**.
  final String displayName;

  /// الحالة.
  final SackStatus status;

  /// الأوزان الثلاثة والمطالب به.
  final ValidatedSackWeights weights;

  /// ★★ نتيجة الحاسبة — **المُفسَّر والمتبقي والحالة**.
  final SackWeightExplanation explanation;

  /// هل أُكِّد الوزن الضائع صراحةً؟ (`FR-M7-19`).
  final bool lostWeightConfirmed;

  /// السطور — ⛔ **وقد تكون فارغة** (`E-06`).
  final List<ValidatedSackLine> lines;

  /// الرعوي إن اشترطه المصدر.
  final String? supplierId;

  /// ★ اسم الرعوي **كما كان لحظة الإنشاء** — ⚠️ **نسخةٌ مقصودة**
  /// (`ADR-0007` القاعدة 4): ⛔ **ولا يتغيّر بتغيّر اسم الرعوي لاحقاً.**
  final String? supplierName;

  /// ★ مفتاح سطر السكرب في الدفتر أو `null` **إن كان وزنه صفراً**.
  final String? scrapItemKey;

  /// ملاحظات المستند.
  final String? notes;

  /// ملاحظة الوزن الضائع.
  final String? lostWeightNote;

  /// سبب الإلغاء.
  final String? cancelReason;

  /// ★ مصدر وسم «⏳ سعر غير نهائي» (`FR-M7-24`).
  final bool isPricingComplete;

  /// عدد التعديلات — ★ **مصدر شارة «مُعدَّل»** (`FR-M8-06`).
  final int amendCount;

  /// هل هي ملغاة؟
  bool get isCancelled => status == SackStatus.cancelled;

  /// ★ **إجمالي الحبّات** — ⛔ **ولا يُجمع مع وزن** (`GR-19`).
  PieceCount get totalPieces {
    PieceCount total = PieceCount.zero;
    for (final ValidatedSackLine line in lines) {
      total = total + line.quantity;
    }
    return total;
  }
}

/// دليل الجواني — **قراءةً فقط**.
///
/// ★ **تدفّقات لا قراءات مفردة:** جونيةٌ أُنشئت من جهازٍ آخر **تظهر فوراً**
/// (`ADR-0010`).
abstract interface class SackDirectory {
  /// جواني يومٍ لمصدر — ★ **مرتَّبةً بالرقم المتسلسل**.
  Stream<List<SackCard>> watchSacks({
    required String sourceId,
    required CalendarDay stockDate,
  });

  /// 🔒 **مالية جونية** — ★ **تدفّق مستقل** لأن شرط قراءته مستقل.
  ///
  /// ⚠️⚠️ **ورفضُ القراءة ليس خطأً يُعرَض بل غيابُ صلاحية** — ⟵ ★ **فالتدفق
  /// يُنتج `null`**، **والشاشة تُخفي البطاقة** ⛔ **ولا تعرض رسالة فشل لمن
  /// لا يملك `sackFinanceView` أصلاً** (`ADR-0011`).
  Stream<SackFinanceCard?> watchSackFinance({required String sackId});
}

/// مستودع كتابة الجواني — **عبر العمليات المستدعاة حصراً**.
///
/// ⛔★★ **ولا كتابة مباشرة واحدة** — راجع ترويسة الملف.
abstract interface class SackAdminRepository {
  /// ★★★ **ينشئ رأس الجونية** ويُرجِع **رقمها** — يشترط `sackCreate`
  /// (`FR-M7-01` · `IQ-021` الخيار أ).
  ///
  /// ⚙️ **والرقم المتسلسل اليومي من السحابة** (`FR-M7-04`) — ⛔ **ولا
  /// يُولِّده الجهاز أبداً**، ⚙️ **وتاريخ المخزون من الخادم** (`FR-M7-02`).
  ///
  /// ⚠️⚠️ **ويُورَّد السكرب في المعاملة نفسها — قبل أي نوع آخر**
  /// (`FR-M7-09` · `AT-07` · `E-06`): ⟵ ★ **فمن يؤجّل توريده لمرحلة إدخال
  /// الأنواع يكسر `AT-07` و`E-06` معاً.**
  Future<Outcome<String>> createSack(ValidatedSackIntake intake);

  /// ★ **يُدخل أنواع الجونية** — يشترط `sackLinesEnter` (`FR-M7-12`).
  ///
  /// ⛔ **مسارٌ يقتصر على مصفوفة السطور** (`§9.6`) — ⛔ **ولا يمسّ الأوزان
  /// ولا الاسم ولا الضريبة.**
  Future<Outcome<void>> enterSackLines({
    required String documentNumber,
    required String sourceId,
    required List<ValidatedSackLine> lines,
    String? amendReason,
  });

  /// ★ **يُدخل قيمة ضريبة الكيلو** — يشترط `sackTaxEnterNow` **أو**
  /// `sackTaxEnterLater` مع `sackView` (`FR-M7-10` · القواعد §`sacks/finance`).
  ///
  /// ⛔ **ويكتب في `finance/current` لا في الأب** (`ADR-0011`).
  Future<Outcome<void>> enterSackTax({
    required String documentNumber,
    required String sourceId,
    required Money taxPerKilo,
    String? amendReason,
  });

  /// ★ **يعدّل الاسم الظاهر** — يشترط `sackRenameDisplay` (`FR-M7-05`).
  ///
  /// ⛔★★ **ولا يمسّ الرقم المتسلسل إطلاقاً** (`ADR-0007` القاعدة 3).
  Future<Outcome<void>> renameSack({
    required String documentNumber,
    required String sourceId,
    required String displayName,
    String? amendReason,
  });

  /// ★ **يُدخل وزن السكرب** — يشترط `sackScrapWeightEnter` (`FR-M7-09`).
  ///
  /// ⚙️ **ويُعيد توليد سطر مخزون السكرب** — ⛔ **ويُعيد بناء رصيده من
  /// الدفتر** لا يُراكم عليه (`coding-standards.md` §2.7).
  Future<Outcome<void>> enterSackScrapWeight({
    required String documentNumber,
    required String sourceId,
    required WeightKg scrapWeight,
    String? amendReason,
  });

  /// ★★ **يؤكّد الوزن الضائع** — يشترط `sackLostWeightConfirm` (`FR-M7-19`).
  ///
  /// ⛔★★ **وهو الفعل الصريح الوحيد الذي يُسجّله** — `BR-M7-12`: ⟵ **وقبله
  /// يبقى «وزناً غير مفسَّر» يُلاحقه المركز المعلّق** (`E-10`).
  /// ⛔ **ولا يدخل المخزون ولا يُقيَّد له أي قيمة** (`FR-M7-20`).
  Future<Outcome<void>> confirmSackLostWeight({
    required String documentNumber,
    required String sourceId,
    String? lostWeightNote,
  });

  /// ★ **يعدّل جونية معتمدة** — يشترط `sackAmend` **وسبباً نصياً إلزامياً**
  /// (`FR-M7-26` · `ADR-0004`).
  ///
  /// ⛔ **ولا يُنشئ حركة تصحيحية:** الحركة **تُعدَّل في مكانها** ويُعاد
  /// احتساب الرصيد (`A-14`).
  Future<Outcome<void>> amendSack({
    required String documentNumber,
    required ValidatedSackIntake intake,
    String? amendReason,
  });

  /// ★ **يُلغي جونية** — يشترط `sackCancel` **وسبباً نصياً إلزامياً**.
  ///
  /// ⛔ **والحذف مرفوض نهائياً لكل المستخدمين بمن فيهم المالك** (`GR-07`) —
  /// ⟵ **فلا دالة حذف في هذا العقد أصلاً.**
  Future<Outcome<void>> cancelSack({
    required String documentNumber,
    required String sourceId,
    String? cancelReason,
  });
}

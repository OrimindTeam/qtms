/// كتابة الجواني عبر **العمليات السحابية المستدعاة** (`WU-004`).
///
/// ⛔★★ **ولا كتابة مباشرة واحدة:** `sacks` و`sacks/{id}/finance` مغلقتان في
/// القواعد — ⟵ **فكل عملية هنا طلبٌ لا كتابة**، والمستندُ وحركاتُه وأرصدتُه
/// **وقيدُ تدقيقه في السحابة معاً في معاملة واحدة** (`ADR-0013` القاعدة 1).
///
/// ⛔★★ **ولا يُرسَل تاريخ مخزونٍ ولا رقمٌ متسلسل إطلاقاً** — `FR-M7-02`
/// (**التاريخ من الخادم مقفلاً**) و`FR-M7-04` (**الترقيم تُولِّده السحابة**).
/// ⟵ ★ **وما لا يُرسَل لا يُزوَّر.**
///
/// ★★ **و`requestId` مُولَّد على الجهاز لكل عملية** — وهو **معرّف قيد
/// التدقيق نفسه** (`api-overview.md` §4)، ⟵ **فإعادة الإرسال بعد انقطاع
/// تكتب فوق القيد ولا تُنشئ ثانياً.**
library;

import 'package:qtms_domain/qtms_domain.dart';

import '../../../core/callable/callable_client.dart';
import '../../identity_access/infrastructure/functions_user_admin_repository.dart'
    show RequestIdFactory;

/// مستودع كتابة الجواني الحقيقي.
final class FunctionsSackRepository implements SackAdminRepository {
  /// ينشئ المستودع.
  const FunctionsSackRepository({
    required CallableClient client,
    required RequestIdFactory newRequestId,
  })  : _client = client,
        _newRequestId = newRequestId;

  final CallableClient _client;
  final RequestIdFactory _newRequestId;

  @override
  Future<Outcome<String>> createSack(ValidatedSackIntake intake) async {
    final Outcome<Map<String, Object?>> result = await _client.call(
      'createSack',
      <String, Object?>{
        'requestId': _newRequestId(),
        'sourceId': intake.sourceId,
        'supplierId': ?intake.supplierId,
        // ★★ **الأوزان الثلاثة وحدها** — ⛔ **ولا مطالبٌ به ولا متبقٍّ**:
        //    كلاهما **محسوب** (`FR-M7-08` · `FR-M7-17`)، ⟵ **وإرسالُه
        //    يفتح باباً لقيمةٍ لا تطابق مكوّناتها.**
        'totalWeight': intake.weights.totalWeight.kilograms,
        'iceWeight': intake.weights.iceWeight.kilograms,
        'scrapWeight': intake.weights.scrapWeight.kilograms,
        'notes': ?intake.notes,
        // ⛔★★ **ولا سطور في الإنشاء** — ★ **مسارها وصلاحيتها منفصلان**
        //    (`FR-M7-27`)، ⟵ **وهو نصّ آلة الحالة**: الرأس والسكرب أولاً.
      },
    );
    return switch (result) {
      Failure<Map<String, Object?>>(:final AppError error) =>
        Failure<String>(error),
      Success<Map<String, Object?>>(:final Map<String, Object?> value) =>
        _readNumber(value, 'createSack'),
    };
  }

  @override
  Future<Outcome<void>> enterSackLines({
    required String documentNumber,
    required String sourceId,
    required List<ValidatedSackLine> lines,
    String? amendReason,
  }) =>
      _voidCall('enterSackLines', <String, Object?>{
        'requestId': _newRequestId(),
        'sourceId': sourceId,
        'documentNumber': documentNumber,
        // ⛔⛔★★★ **ولا سببَ مُعبَّأً آلياً** (`IQ-025` · `ADR-0018`):
        //    ★ **ما لم يكتبه إنسانٌ لا يُرسَل**، ⟵ **فقيدُ التدقيق لا يحمل
        //    نصّاً يظنّه المدقّق سببَ إنسانٍ وهو سببُ آلة.**
        'reason': ?amendReason,
        'lines': <Object?>[
          for (final ValidatedSackLine line in lines) _lineFields(line),
        ],
      });

  @override
  Future<Outcome<void>> enterSackTax({
    required String documentNumber,
    required String sourceId,
    required Money taxPerKilo,
    String? amendReason,
  }) =>
      _voidCall('enterSackTax', <String, Object?>{
        'requestId': _newRequestId(),
        'sourceId': sourceId,
        'documentNumber': documentNumber,
        // ★ **مبلغٌ صحيح بالريال** — `ADR-0015`.
        'taxPerKilo': taxPerKilo.riyals,
        // ⛔★★ **ولا سببَ مُعبَّأً آلياً** — راجع [enterSackLines].
        'reason': ?amendReason,
      });

  @override
  Future<Outcome<void>> renameSack({
    required String documentNumber,
    required String sourceId,
    required String displayName,
    String? amendReason,
  }) =>
      _voidCall('renameSack', <String, Object?>{
        'requestId': _newRequestId(),
        'sourceId': sourceId,
        'documentNumber': documentNumber,
        'displayName': displayName,
        'reason': ?amendReason,
        // ⛔★★ **ولا `dailySequence` إطلاقاً** — `ADR-0007` القاعدة 3:
        //    ⟵ **وما لا يُرسَل لا يُغيَّر**، ★ **والسحابة تحرسه فوق ذلك.**
      });

  @override
  Future<Outcome<void>> enterSackScrapWeight({
    required String documentNumber,
    required String sourceId,
    required WeightKg scrapWeight,
    String? amendReason,
  }) =>
      _voidCall('enterSackScrapWeight', <String, Object?>{
        'requestId': _newRequestId(),
        'sourceId': sourceId,
        'documentNumber': documentNumber,
        'scrapWeight': scrapWeight.kilograms,
        'reason': ?amendReason,
      });

  @override
  Future<Outcome<void>> confirmSackLostWeight({
    required String documentNumber,
    required String sourceId,
    String? lostWeightNote,
  }) =>
      _voidCall('confirmSackLostWeight', <String, Object?>{
        'requestId': _newRequestId(),
        'sourceId': sourceId,
        'documentNumber': documentNumber,
        // ★ **والملاحظة اختيارية** — `FR-M7-19` نصّاً.
        'lostWeightNote': ?lostWeightNote,
      });

  @override
  Future<Outcome<void>> amendSack({
    required String documentNumber,
    required ValidatedSackIntake intake,
    String? amendReason,
  }) =>
      _voidCall('amendSack', <String, Object?>{
        'requestId': _newRequestId(),
        'sourceId': intake.sourceId,
        'documentNumber': documentNumber,
        'totalWeight': intake.weights.totalWeight.kilograms,
        'iceWeight': intake.weights.iceWeight.kilograms,
        'scrapWeight': intake.weights.scrapWeight.kilograms,
        'notes': ?intake.notes,
        'lostWeightConfirmed': intake.lostWeightConfirmed,
        'lines': <Object?>[
          for (final ValidatedSackLine line in intake.lines) _lineFields(line),
        ],
        // ★★ **السبب النصي إلزامي** — `ADR-0004` · `FR-M7-26`.
        'reason': ?amendReason,
      });

  @override
  Future<Outcome<void>> cancelSack({
    required String documentNumber,
    required String sourceId,
    String? cancelReason,
  }) =>
      _voidCall('cancelSack', <String, Object?>{
        'requestId': _newRequestId(),
        // ⚠️ **المصدر يُرسَل لفحص النطاق قبل المعاملة** — ★ **والمخزَّن هو
        //   الحَكَم داخلها** (`_existenceGate`)، ⛔ **فلا يُصدَّق المُرسَل.**
        'sourceId': sourceId,
        'documentNumber': documentNumber,
        'reason': ?cancelReason,
      });

  /// ★★ حقول السطر كما تعبر الشبكة.
  ///
  /// ⛔★★★ **و`nature` تُرسَل لأنها تختار الحالة من الثلاث** — ⚠️ **والسحابة
  /// لا تُصدِّقها:** `sack_intake_handler.dart` **يُعيد تمريرها على
  /// `resolveSackLine`** الذي يفرض الجدول حرفياً، ⟵ **فعميلٌ يُعلن وزنياً
  /// «عددياً» يُرفَض سطرُه هناك** ⛔ **ولا يُستنتَج له وزن حبة** (`FR-M7-14`).
  ///
  /// ⛔ **ولا يُرسَل `pieceWeightOrigin`:** **مشتقٌّ من الحالة** لا مُدخَل —
  /// ⟵ **وإرسالُه كان يجعل الجهاز يُملي مصدرَ رقمٍ لم يُشتقّه.**
  ///
  /// ⛔⛔★★★ **ولذلك يُرسَل وزنُ الحبة في حقلِ حالتِه لا في حقلٍ واحد**
  /// (`DEBT-37`): **رقمٌ جاء من التهيئة يُرسَل `configuredPieceWeightGrams`**،
  /// **ورقمٌ كتبه المستخدم يُرسَل `pieceWeightGrams`** — ⟵ **فيُعيد
  /// `resolveSackLine` في السحابة اشتقاقَ المصدر نفسه حرفياً.**
  /// ⚠️⚠️ **وإرسالُهما في حقلٍ واحد كان يَسِم كلَّ سطرٍ وزني «يدوياً»**
  /// ⟵ ⛔ **فحالةُ «تهيئة» لم تكن تُكتَب قط**، **وهي أحد ثلاثة يوثّقها
  /// `sack-intake-design.md` §4** ⟵ **والتدقيق يقرأ المصدر لا الرقم.**
  static Map<String, Object?> _lineFields(ValidatedSackLine line) =>
      <String, Object?>{
        'itemId': line.itemId,
        'itemName': line.itemName,
        'nature': line.nature.name,
        'quantity': line.quantity.pieces,
        // ★ **للوزني وحده** — ⛔ **والعددي حقلُه مقفل** (`E-09`).
        if (line.nature == ItemNature.weightBased)
          ...switch (line.pieceWeightOrigin) {
            PieceWeightOrigin.configured => <String, Object?>{
                'configuredPieceWeightGrams': line.pieceWeightGrams,
              },
            // ⚠️ **والمستنتَج لا يقع هنا** — ★ **حالتُه عدديةٌ حصراً**،
            //    ⟵ **فيُعامَل كاليدوي احتياطاً لا اشتقاقاً من الوزن الكلي.**
            PieceWeightOrigin.manual ||
            PieceWeightOrigin.inferred =>
              <String, Object?>{'pieceWeightGrams': line.pieceWeightGrams},
          },
        // ★ **وللعددي وحده** — ⛔ **والوزني محسوب** (`FR-M7-13`).
        if (line.nature == ItemNature.countBased)
          'lineTotalWeight': line.lineTotalWeight.kilograms,
        'distributionPrice': ?line.distributionPrice?.riyals,
        'minCashPrice': ?line.minCashPrice?.riyals,
        'note': ?line.note,
      };

  Future<Outcome<void>> _voidCall(
    String operation,
    Map<String, Object?> data,
  ) async {
    final Outcome<Map<String, Object?>> result =
        await _client.call(operation, data);
    return switch (result) {
      Failure<Map<String, Object?>>(:final AppError error) =>
        Failure<void>(error),
      Success<Map<String, Object?>>() => const Success<void>(null),
    };
  }

  /// ⚠️ **نجاحٌ بلا رقم عطلٌ لا نجاح** — الشاشة تحتاجه لتعرض ما أُنشئ،
  /// ⛔ **وابتلاعُه يُظهر «تمّ» ثم لا يجد المستخدمُ جونيته.**
  static Outcome<String> _readNumber(
    Map<String, Object?> result,
    String operation,
  ) {
    final Object? number = result['documentNumber'];
    if (number is String && number.isNotEmpty) return Success<String>(number);
    return Failure<String>(
      InfrastructureError('استجابة $operation بلا documentNumber'),
    );
  }
}

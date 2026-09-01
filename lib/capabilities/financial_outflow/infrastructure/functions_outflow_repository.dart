/// كتابة السحبيات والخرجيات عبر **العمليات السحابية المستدعاة الثلاث**
/// (`WU-014`).
///
/// ⛔★★ **ولا كتابة مباشرة:** `outflows` و`outflow_ledger` و`inventory_ledger`
/// و`item_daily_balances` **كلها مغلقة في القواعد** — ⟵ **فكل عملية هنا
/// طلبٌ لا كتابة**، **والسندُ وسطورُ دفتره وحركاتُه وأرصدتُه وقيدُ تدقيقه في
/// معاملة واحدة** (`ADR-0013` القاعدة 1 · `FR-M22-13` · `GR-51`).
///
/// ⛔⛔★★★ **ولا حقلَ مقوتٍ يُرسَل في أي عملية** (`FR-M22-04` · `GR-44`) —
/// ★ **غيابٌ بنيويٌّ من الحمولة نفسِها**: ⟵ **فما لا يُرسَل لا يُكتَب.**
///
/// ⛔⛔★★★ **و`ledgerType` وسيطٌ إلزاميٌّ في الإنشاء وحده** — ★ **وفي التعديل
/// والإلغاء يُقرأ من *بادئة رقم المستند*** (`WDR-` · `EXP-`): ⟵ **فلا يُرسِل
/// التطبيق ادّعاءً يخالف المستند**، ★ **والحَكَمُ النهائي `ledgerType`
/// المخزَّن في السحابة** ⛔ **لا هذا السطر** (`GR-43`).
///
/// ⚠️⚠️ **والتاريخ يُرسَل هنا كسند القبض والخصم** — `FR-M22-09`: **يقبل
/// سابقاً بمفتاح سجلِّه** ⛔ **ويرفض المستقبلي مطلقاً**، ★ **ويُقابَل بيوم
/// المنصّة داخل المعاملة** ⛔ **فلا يُصدَّق كما ورد.**
///
/// ⛔★★ **ولا يُرسَل اسمُ نوعٍ ولا وحدةٌ ولا قيمةُ سطر** — ★ **كلُّها من
/// سجلات الأنواع المقروءة داخل المعاملة**، ⟵ **فما لا يُرسَل لا يُزوَّر.**
///
/// ⛔⛔★★★ **ولا يُعبَّأ سببٌ نيابةً عن المستخدم** ([`ADR-0020`]) — ★ **ما لم
/// يكتبه إنسانٌ لا يُرسَل**، **والفراغات تُقرأ غياباً لا نصّاً فارغاً.**
library;

import 'package:qtms_domain/qtms_domain.dart';

import '../../../core/callable/callable_client.dart';
import '../../identity_access/infrastructure/functions_user_admin_repository.dart'
    show RequestIdFactory;

/// مستودع كتابة السحبيات والخرجيات الحقيقي.
final class FunctionsOutflowRepository implements OutflowAdminRepository {
  /// ينشئ المستودع.
  const FunctionsOutflowRepository({
    required CallableClient client,
    required RequestIdFactory newRequestId,
  })  : _client = client,
        _newRequestId = newRequestId;

  final CallableClient _client;
  final RequestIdFactory _newRequestId;

  @override
  Future<Outcome<String>> createOutflow({
    required OutflowLedgerType ledgerType,
    required String sourceId,
    required OutflowCategory category,
    required CalendarDay date,
    List<OutflowQatLineInput> qatLines = const <OutflowQatLineInput>[],
    List<OutflowCashLineInput> cashLines = const <OutflowCashLineInput>[],
    String? notes,
  }) async {
    final Outcome<Map<String, Object?>> result = await _client.call(
      'createOutflow',
      <String, Object?>{
        'requestId': _newRequestId(),
        'ledgerType': ledgerType.name,
        'sourceId': sourceId,
        'category': category.name,
        // ★ **الصيغة المُدمَجة `YYYYMMDD`** — ★ **وهي صيغة المشروع القائمة**
        //   (`naming-conventions.md` §4 و§5).
        'date': date.format(),
        'qatLines': _qatOf(qatLines),
        'cashLines': _cashOf(cashLines),
        'notes': ?_blankToNull(notes),
      },
    );
    return switch (result) {
      Failure<Map<String, Object?>>(:final AppError error) =>
        Failure<String>(error),
      Success<Map<String, Object?>>(:final Map<String, Object?> value) =>
        Success<String>(value['documentNumber'] as String? ?? ''),
    };
  }

  @override
  Future<Outcome<void>> amendOutflow({
    required String documentNumber,
    required String sourceId,
    required OutflowCategory category,
    List<OutflowQatLineInput> qatLines = const <OutflowQatLineInput>[],
    List<OutflowCashLineInput> cashLines = const <OutflowCashLineInput>[],
    String? notes,
    String? amendReason,
  }) async {
    final Outcome<Map<String, Object?>> result = await _client.call(
      'amendOutflow',
      <String, Object?>{
        'requestId': _newRequestId(),
        'documentNumber': documentNumber,
        // ★★ **والسجلُّ من بادئة الرقم** — ⛔ **لا من حالةِ شاشةٍ قد تكون
        //   بُدِّلت بعد فتح السند**: ⟵ **والسحابة تُقابله بالمخزَّن.**
        'ledgerType': ledgerTypeOf(documentNumber).name,
        'sourceId': sourceId,
        'category': category.name,
        'qatLines': _qatOf(qatLines),
        'cashLines': _cashOf(cashLines),
        'notes': ?_blankToNull(notes),
        // ⛔★★ **ويُرسَل غائباً إن لم يكتبه إنسان** ([`ADR-0020`]).
        'reason': ?_blankToNull(amendReason),
      },
    );
    return _voidOf(result);
  }

  @override
  Future<Outcome<void>> cancelOutflow({
    required String documentNumber,
    required String sourceId,
    String? cancelReason,
  }) async {
    final Outcome<Map<String, Object?>> result = await _client.call(
      'cancelOutflow',
      <String, Object?>{
        'requestId': _newRequestId(),
        'documentNumber': documentNumber,
        'ledgerType': ledgerTypeOf(documentNumber).name,
        'sourceId': sourceId,
        'reason': ?_blankToNull(cancelReason),
      },
    );
    return _voidOf(result);
  }

  /// ★★ **السجلُّ من بادئة رقم المستند** — `WDR-` · `EXP-`.
  ///
  /// ⚠️⚠️ **والافتراضُ عند الغموض «خرجية» عمداً** — ⛔ **لا «سحبية»:**
  /// ⟵ **فالسحبيات هي السجلُّ الحسّاس** (`GR-43`)، ★ **ورقمٌ مشوَّه يُرسَل
  /// «خرجيةً» تردّه السحابةُ بنقص صلاحية أو باختلاف المخزَّن** — ⛔ **بينما
  /// افتراضُ «سحبية» كان يجعل الغموضَ يميل نحو السجل الأخطر.**
  static OutflowLedgerType ledgerTypeOf(String documentNumber) =>
      documentNumber
              .startsWith('${DocumentKind.withdrawal.prefix}-')
          ? OutflowLedgerType.withdrawal
          : OutflowLedgerType.expense;

  static Outcome<void> _voidOf(Outcome<Map<String, Object?>> result) =>
      switch (result) {
        Failure<Map<String, Object?>>(:final AppError error) =>
          Failure<void>(error),
        Success<Map<String, Object?>>() => const Success<void>(null),
      };

  static List<Map<String, Object?>> _qatOf(List<OutflowQatLineInput> lines) =>
      <Map<String, Object?>>[
        for (final OutflowQatLineInput line in lines)
          <String, Object?>{
            'itemId': line.itemId,
            'quantity': switch (line.quantity) {
              PieceQuantity(:final PieceCount count) => count.pieces,
              WeightQuantity(:final WeightKg weight) => weight.kilograms,
            },
            // ★★★ **والسعرُ يُحذَف إن غاب** — `FR-M22-07`: ⛔ **ولا يُرسَل
            //   صفراً**: ⟵ **وصفرٌ كان يُقيِّد خروجاً بقيمةٍ صفرية فيُفسِد
            //   سعرَ الجونية** ⛔ **بدل أن يُعلَن نقصاً في المركز المعلّق.**
            'unitPrice': ?line.unitPrice?.riyals,
            'sackId': ?line.sackId,
          },
      ];

  static List<Map<String, Object?>> _cashOf(List<OutflowCashLineInput> lines) =>
      <Map<String, Object?>>[
        for (final OutflowCashLineInput line in lines)
          <String, Object?>{
            'kind': line.kind.name,
            'amount': line.amount.riyals,
            'description': ?_blankToNull(line.description),
          },
      ];

  /// ★ **الفراغات تُقرأ غياباً لا نصّاً فارغاً** — ([`ADR-0020`] · الطرفان).
  static String? _blankToNull(String? value) {
    if (value == null) return null;
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

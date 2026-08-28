/// كتابة المقبوضات عبر **العمليات السحابية المستدعاة الأربع** (`WU-007`).
///
/// ⛔★★ **ولا كتابة مباشرة:** `receipts` و`deposit/current` و`dealer_ledger`
/// و`dealer_balances` و`dealer_surplus` **كلها مغلقة في القواعد** —
/// ⟵ **فكل عملية هنا طلبٌ لا كتابة**، **والسندُ وحركاتُه الدائنة وتسويةُ
/// ضماراته وأرصدتُه وقيدُ تدقيقه في معاملة واحدة** (`ADR-0013` القاعدة 1 ·
/// `FR-M12-08` · `GR-51`).
///
/// ⚠️⚠️ **والتاريخ يُرسَل هنا بخلاف التوزيع** — `FR-M12-02`: **يقبل سابقاً
/// بصلاحية `receiptBackdate`** (`E-14`) ⛔ **ويرفض المستقبلي مطلقاً**،
/// ★ **ويُقابَل بيوم المنصّة داخل المعاملة** ⛔ **فلا يُصدَّق كما ورد.**
///
/// ⛔★★ **ولا يُرسَل مصدرُ سطرٍ ولا متبقٍّ ولا اسمُ مقوت** — ★ **كلُّها من
/// المستندات المقروءة داخل المعاملة** (`E-35`)، ⟵ **فما لا يُرسَل لا يُزوَّر.**
///
/// ⛔⛔★★★ **ولا يُعبَّأ سببٌ نيابةً عن المستخدم** ([`ADR-0020`]) — ★ **ما لم
/// يكتبه إنسانٌ لا يُرسَل**، **والفراغات تُقرأ غياباً لا نصّاً فارغاً.**
library;

import 'package:qtms_domain/qtms_domain.dart';

import '../../../core/callable/callable_client.dart';
import '../../identity_access/infrastructure/functions_user_admin_repository.dart'
    show RequestIdFactory;

/// مستودع كتابة المقبوضات الحقيقي.
final class FunctionsReceiptRepository implements ReceiptAdminRepository {
  /// ينشئ المستودع.
  const FunctionsReceiptRepository({
    required CallableClient client,
    required RequestIdFactory newRequestId,
  })  : _client = client,
        _newRequestId = newRequestId;

  final CallableClient _client;
  final RequestIdFactory _newRequestId;

  @override
  Future<Outcome<String>> createReceipt({
    required String dealerId,
    required CalendarDay date,
    required List<ReceiptLineInput> lines,
    String? sourceFilter,
    Money surplusAmount = Money.zero,
    SurplusScope surplusScope = SurplusScope.general,
    bool usedAutoAllocation = false,
  }) async {
    final Outcome<Map<String, Object?>> result = await _client.call(
      'createReceipt',
      <String, Object?>{
        'requestId': _newRequestId(),
        'dealerId': dealerId,
        // ★ **الصيغة المُدمَجة `YYYYMMDD`** — ★ **وهي صيغة المشروع القائمة**
        //   في أرقام المستندات والمفاتيح (`naming-conventions.md` §4 و§5).
        'date': date.format(),
        'sourceFilter': ?sourceFilter,
        'lines': _linesOf(lines),
        'surplusAmount': surplusAmount.riyals,
        'surplusScope': surplusScope.name,
        'usedAutoAllocation': usedAutoAllocation,
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
  Future<Outcome<void>> amendReceipt({
    required String documentNumber,
    required String dealerId,
    required CalendarDay date,
    required List<ReceiptLineInput> lines,
    String? sourceFilter,
    Money surplusAmount = Money.zero,
    SurplusScope surplusScope = SurplusScope.general,
    String? amendReason,
  }) async {
    final Outcome<Map<String, Object?>> result = await _client.call(
      'amendReceipt',
      <String, Object?>{
        'requestId': _newRequestId(),
        'documentNumber': documentNumber,
        'dealerId': dealerId,
        'date': date.format(),
        'sourceFilter': ?sourceFilter,
        'lines': _linesOf(lines),
        'surplusAmount': surplusAmount.riyals,
        'surplusScope': surplusScope.name,
        // ⛔★★ **ويُرسَل غائباً إن لم يكتبه إنسان** ([`ADR-0020`]).
        'reason': ?_blankToNull(amendReason),
      },
    );
    return _voidOf(result);
  }

  @override
  Future<Outcome<void>> cancelReceipt({
    required String documentNumber,
    required String dealerId,
    String? cancelReason,
  }) async {
    final Outcome<Map<String, Object?>> result = await _client.call(
      'cancelReceipt',
      <String, Object?>{
        'requestId': _newRequestId(),
        'documentNumber': documentNumber,
        'dealerId': dealerId,
        'reason': ?_blankToNull(cancelReason),
      },
    );
    return _voidOf(result);
  }

  @override
  Future<Outcome<void>> setReceiptDeposit({
    required String documentNumber,
    required String dealerId,
    required bool isDeposited,
    required String note,
  }) async {
    final Outcome<Map<String, Object?>> result = await _client.call(
      'confirmReceiptDeposit',
      <String, Object?>{
        'requestId': _newRequestId(),
        'documentNumber': documentNumber,
        'dealerId': dealerId,
        'isDeposited': isDeposited,
        // ⛔⛔★★ **والملاحظة تُرسَل كما كتبها المستخدم** — ★ **وهي إلزامية
        //    خارج [`ADR-0020`]** (`GR-38`): ⟵ **والسحابة ترفض الفارغة**،
        //    ⛔ **ولا يُعبِّئها التطبيق نيابةً عنه.**
        'depositNote': note,
      },
    );
    return _voidOf(result);
  }

  static Outcome<void> _voidOf(Outcome<Map<String, Object?>> result) =>
      switch (result) {
        Failure<Map<String, Object?>>(:final AppError error) =>
          Failure<void>(error),
        Success<Map<String, Object?>>() => const Success<void>(null),
      };

  static List<Map<String, Object?>> _linesOf(List<ReceiptLineInput> lines) =>
      <Map<String, Object?>>[
        for (final ReceiptLineInput line in lines)
          <String, Object?>{
            'debtLotId': line.debtLotId,
            'amount': line.amount.riyals,
            'note': ?_blankToNull(line.note),
          },
      ];

  /// ★ **الفراغات تُقرأ غياباً لا نصّاً فارغاً** — ([`ADR-0020`] · الطرفان).
  static String? _blankToNull(String? value) {
    if (value == null) return null;
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

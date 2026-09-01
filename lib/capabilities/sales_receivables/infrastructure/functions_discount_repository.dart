/// كتابة الخصومات عبر **العمليات السحابية المستدعاة الثلاث** (`WU-013`).
///
/// ⛔★★ **ولا كتابة مباشرة:** `discounts` و`dealer_ledger` و`dealer_balances`
/// **كلها مغلقة في القواعد** — ⟵ **فكل عملية هنا طلبٌ لا كتابة**،
/// **والسندُ وحركاتُه الدائنة وتسويةُ ضماراته وأرصدتُه وقيدُ تدقيقه في معاملة
/// واحدة** (`ADR-0013` القاعدة 1 · `FR-M13-11` · `GR-51`).
///
/// ⛔⛔★★★ **ولا حقلَ فائضٍ يُرسَل في أي عملية** (`FR-M13-05` · `AT-35`) —
/// ★ **غيابٌ بنيويٌّ من الحمولة نفسِها**، ⛔ **لا صفرٌ يُرسَل**:
/// ⟵ **والسحابة ترفض *وجود* المفتاح بـ`ERR_DIST_009`** — ★ **فإرسالُ صفرٍ
/// «تأدّباً» كان سيُفشِل كلَّ سندٍ يكتبه التطبيق نفسُه.**
///
/// ⚠️⚠️ **والتاريخ يُرسَل هنا كسند القبض** — `FR-M13-06`: **يقبل سابقاً
/// بصلاحية `discountBackdate`** ⛔ **ويرفض المستقبلي مطلقاً**،
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

/// مستودع كتابة الخصومات الحقيقي.
final class FunctionsDiscountRepository implements DiscountAdminRepository {
  /// ينشئ المستودع.
  const FunctionsDiscountRepository({
    required CallableClient client,
    required RequestIdFactory newRequestId,
  })  : _client = client,
        _newRequestId = newRequestId;

  final CallableClient _client;
  final RequestIdFactory _newRequestId;

  @override
  Future<Outcome<String>> createDiscount({
    required String dealerId,
    required CalendarDay date,
    required List<DiscountLineInput> lines,
    String? sourceFilter,
    bool usedAutoAllocation = false,
  }) async {
    final Outcome<Map<String, Object?>> result = await _client.call(
      'createDiscount',
      <String, Object?>{
        'requestId': _newRequestId(),
        'dealerId': dealerId,
        // ★ **الصيغة المُدمَجة `YYYYMMDD`** — ★ **وهي صيغة المشروع القائمة**
        //   في أرقام المستندات والمفاتيح (`naming-conventions.md` §4 و§5).
        'date': date.format(),
        'sourceFilter': ?sourceFilter,
        'lines': _linesOf(lines),
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
  Future<Outcome<void>> amendDiscount({
    required String documentNumber,
    required String dealerId,
    required CalendarDay date,
    required List<DiscountLineInput> lines,
    String? sourceFilter,
    String? amendReason,
  }) async {
    final Outcome<Map<String, Object?>> result = await _client.call(
      'amendDiscount',
      <String, Object?>{
        'requestId': _newRequestId(),
        'documentNumber': documentNumber,
        'dealerId': dealerId,
        'date': date.format(),
        'sourceFilter': ?sourceFilter,
        'lines': _linesOf(lines),
        // ⛔★★ **ويُرسَل غائباً إن لم يكتبه إنسان** ([`ADR-0020`]).
        'reason': ?_blankToNull(amendReason),
      },
    );
    return _voidOf(result);
  }

  @override
  Future<Outcome<void>> cancelDiscount({
    required String documentNumber,
    required String dealerId,
    String? cancelReason,
  }) async {
    final Outcome<Map<String, Object?>> result = await _client.call(
      'cancelDiscount',
      <String, Object?>{
        'requestId': _newRequestId(),
        'documentNumber': documentNumber,
        'dealerId': dealerId,
        'reason': ?_blankToNull(cancelReason),
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

  static List<Map<String, Object?>> _linesOf(List<DiscountLineInput> lines) =>
      <Map<String, Object?>>[
        for (final DiscountLineInput line in lines)
          <String, Object?>{
            'debtLotId': line.debtLotId,
            // ★ **«مبلغ الخصم» اسمُه على السلك `amount`** —
            //   `schema/discounts.md`: **التسميةُ فرقُ عرضٍ لا فرقُ مخطَّط.**
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

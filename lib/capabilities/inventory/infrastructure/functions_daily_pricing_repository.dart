/// كتابة الأسعار عبر **العملية السحابية المستدعاة** (`WU-005`).
///
/// ⛔★★ **ولا كتابة مباشرة:** `daily_prices` **مغلقة في القواعد** — ⟵ **فكل
/// عملية هنا طلبٌ لا كتابة**، والسجلاتُ وقيدُ التدقيق **في السحابة معاً في
/// معاملة واحدة** (`ADR-0013` القاعدة 1).
///
/// ⛔★★ **ولا يُرسَل تاريخٌ إطلاقاً** — `FR-M9-03` يجعل السعر ليومٍ بعينه،
/// ★ **واليوم من المنصّة داخل المعاملة** (`GR-54` · `E-41`). ⟵ ★ **وما لا
/// يُرسَل لا يُزوَّر.**
///
/// ⛔★★ **ولا يُرسَل اسمُ نوعٍ ولا وحدتُه** — ★ **كلاهما من سجل النوع**
/// (`FR-M5-03` · `FR-M9-06`)، ⟵ **فلا يُسعِّر عميلٌ بوحدةٍ ليست وحدة النوع.**
library;

import 'package:qtms_domain/qtms_domain.dart';

import '../../../core/callable/callable_client.dart';
import '../../identity_access/infrastructure/functions_user_admin_repository.dart'
    show RequestIdFactory;

/// مستودع كتابة الأسعار الحقيقي.
final class FunctionsDailyPricingRepository implements DailyPricingRepository {
  /// ينشئ المستودع.
  const FunctionsDailyPricingRepository({
    required CallableClient client,
    required RequestIdFactory newRequestId,
  })  : _client = client,
        _newRequestId = newRequestId;

  final CallableClient _client;
  final RequestIdFactory _newRequestId;

  @override
  Future<Outcome<void>> writeDailyPrices({
    required ValidatedDailyPriceBatch batch,
    String? amendReason,
  }) async {
    final Outcome<Map<String, Object?>> result = await _client.call(
      'writeDailyPrices',
      <String, Object?>{
        // ★★ **معرّفٌ لكل عملية وهو معرّف قيد التدقيق نفسه**
        //    (`api-overview.md` §4) — ⟵ **فإعادة الإرسال بعد انقطاع تكتب
        //    فوق القيد ولا تُنشئ ثانياً.**
        'requestId': _newRequestId(),
        'sourceId': batch.sourceId,
        // ★ **يُرسَل إن وُجد فقط** — ⛔ **ولا يُرسَل نصّاً فارغاً**:
        //    السحابة تُميّز الغياب من الفراغ وترفض كليهما على التعديل.
        if (amendReason case final String reason) 'reason': reason,
        'lines': <Object?>[
          for (final ValidatedDailyPriceLine line in batch.lines)
            <String, Object?>{
              'itemId': line.itemId,
              // ⛔★★ **والمفتاح حاضرٌ بقيمة `null` صريحة عند التفريغ** —
              //    ⟵ **فالسحابة تُميّز «فرِّغ» من «لا تمسّ»**، ★ **ومفتاحٌ
              //    محذوف كان يُبقي السعر القديم قائماً بصمت** (`FR-M9-07`).
              'distributionPrice': line.distributionPrice?.riyals,
              'minCashPrice': line.minCashPrice?.riyals,
            },
        ],
      },
    );
    return switch (result) {
      Failure<Map<String, Object?>>(:final AppError error) =>
        Failure<void>(error),
      Success<Map<String, Object?>>() => const Success<void>(null),
    };
  }
}

/// إعادة البناء بأثر رجعي — **التخطيط الخالص** (`WU-021` · `DEBT-01`).
///
/// ★ **مفصولٌ عن `retroactive_rebuild_handler.dart` عمداً**، بنفس منطق
/// `owner_bootstrap.dart`: **كلُّ قرارِ تفويضٍ وتحقّقٍ هنا في دوالَّ خالصةٍ
/// تُختبَر بلا سحابة**؛ ⛔ **وهناك القراءةُ والالتزام وحدهما.**
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **ولماذا عمليةٌ تشغيليةٌ لا ميزةُ مستخدم — ثلاثةُ نصوصٍ لا رأي:**
///
///   ① `permissions-catalog.md` §3: **«كتابة الأرصدة والملخصات ⟵ السحابة
///      أو المعاملة الذرّية فقط»** — ⟵ **بندٌ في «ما *ليس* صلاحية»**،
///      ⛔ **فلا مفتاحَ يُخترَع لها** (⛔ **واختلاقُ مفتاحٍ مخالفةُ §6**).
///   ② `api-overview.md` §3.2 يُدرِج **`rebuildDayRetroactively`** ضمن
///      **العمليات المشغَّلة بالكتابة** — ⛔ **لا في §3.1 التي يستدعيها
///      التطبيق**، ⟵ **فلا شاشةَ لها ولا زرّ.**
///   ③ `risks-and-technical-debt-register.md`: **`DEBT-01`** «أداةُ إعادة
///      بناءٍ شاملة للملخصات من الدفاتر — **لازمةٌ لعلاج `RISK-08` ولأي
///      هجرة**»، ★ **ومالكُ `RISK-08` هو `DEVOPS`** لا المستخدم.
///
/// ⟹ ★★ **فحارسُها هويةُ المالك المسجَّل وحدها** — **نظيرُ
/// `bootstrapOwnerPermissions` حرفياً** (`api-overview.md` §3.1: «⛔ **ولا
/// تُستدعى من التطبيق ولا تُعرَض في أي شاشة** — إجراءٌ تشغيليٌّ موثَّق»)،
/// ⛔ **ولا صلاحيةَ من الكتالوج تُفحَص** لأنه لا مفتاحَ لها فيه أصلاً.
/// ═══════════════════════════════════════════════════════════════════════
///
/// ⛔⛔★★★ **ولا تكتب هذه العمليةُ قيدَ تدقيقٍ — والفارقُ عن الإقلاع مقصود:**
/// ★ **الإقلاعُ يُغيّر بطاقةَ مستخدم** (بيانٌ مصدرُ حقيقةٍ) **فيلزمه قيد**
/// (`ADR-0013` القاعدة 1)؛ ⛔ **وهذه لا تُغيّر بياناً واحداً مصدرَ حقيقة**:
/// ⟵ **تُعيد اشتقاقَ المشتقّ من دفترِه** (`ADR-0008`). ★ **وقيدُ التدقيق
/// يوثّق تغييراً**، ⛔ **وقيدٌ بلا تغييرٍ يُلوِّث السجل بضجيجٍ يُخفي
/// التغييرات الحقيقية** (نصّ `owner_bootstrap.dart` حرفياً). ★ **وأثرُها
/// يُسجَّل بمخرَجٍ فعليٍّ مرقَّم** — بروتوكول التشغيل §و و§ز.5.
library;

import 'package:qtms_domain/qtms_domain.dart';

import 'aged_remainder.dart';
import 'callable.dart';
import 'firestore_value.dart' show DecimalValue;
import 'firestore_writer.dart';
import 'identity_gateway.dart';
import 'inventory.dart' show InventoryWrite;

/// طلب إعادة بناءٍ بأثر رجعي مُتحقَّق من هوية مُنفِّذه.
final class RetroactiveRebuildRequest {
  /// ينشئ الطلب.
  const RetroactiveRebuildRequest({
    required this.actor,
    required this.registeredOwnerUserId,
    required this.requestId,
    required this.date,
    required this.platformToday,
    this.sourceIds,
  });

  /// المُستدعي **بحالته الآن من خدمة المصادقة** لا من الرمز الذي أرسله.
  final AccountRecord actor;

  /// معرّف المالك المسجَّل **من إعداد البيئة لا من الحمولة**.
  ///
  /// ⛔ **ولا يُقرأ من الطلب إطلاقاً** — ★ **نفسُ حارس `OwnerBootstrapRequest`
  /// حرفياً**: ⟵ **لو جاء من الحمولة لصار أيُّ مُستدعٍ قادراً على تسمية
  /// نفسه مالكاً**، ★ **وهو تصعيدُ امتيازٍ كاملٌ بسطرٍ واحد.**
  final String registeredOwnerUserId;

  /// ★ معرّف الطلب — **يُسجَّل مع المخرَج** فيُربَط التشغيلُ برَنبوكه.
  ///
  /// ⚠️ **وليس معرّفَ قيدِ تدقيق هنا** — ⛔ **فلا قيدَ لهذه العملية** (راجع
  /// ترويسة الملف). ★ **واللاتكراريةُ لا تعتمد عليه أصلاً**: ⟵ **كلُّ كتابةٍ
  /// تُنتجها مشتقّةُ المعرّف تماماً**، ★ **فالتشغيلُ مرتين يُنتج نفس الحالة.**
  final String requestId;

  /// اليوم المستهدَف **بصيغة `YYYYMMDD`** كما وصل — ⛔ **بلا تحليلٍ بعد**.
  final String date;

  /// ★★★ **يومُ المنصّة** — ⛔ **لا ساعةُ الحاوية ولا قيمةٌ من الجهاز**
  /// (`GR-54` · `E-41`).
  ///
  /// ⚠️ **و`null` تعني «تعذّر قياسُه»** — ★ **فيُرفَض الطلب** ⛔ **ولا
  /// يُستعاض عنه بساعةٍ محلية**: ⟵ **ووسمُ «⟳» يُشتقّ من المقارنة به**،
  /// ★ **فيومٌ مزاحٌ يَسِم بطاقةَ اليوم الجاري رجعيةً أو يترك الماضيَ بلا وسم.**
  final CalendarDay? platformToday;

  /// المصادر المستهدَفة — و`null` تعني **كلَّ المصادر**.
  ///
  /// ★ **والقائمةُ الفارغة ليست «الكل»** — ⛔ **بل طلبٌ غيرُ صالح**: ⟵ **فلا
  /// يُوسِّع خطأٌ مطبعيٌّ في أداةٍ نطاقَ تشغيلٍ من مصدرٍ إلى كل المصادر.**
  final List<String>? sourceIds;
}

/// نتيجة تخطيط إعادة البناء.
sealed class RetroactiveRebuildPlan {
  const RetroactiveRebuildPlan();
}

/// رُفض الطلب قبل أي قراءة أو كتابة.
final class RetroactiveRebuildRejected extends RetroactiveRebuildPlan {
  /// ينشئ رفضاً.
  const RetroactiveRebuildRejected(this.error);

  /// رمز الرفض من كتالوج الأخطاء.
  final CallableError error;
}

/// قُبل الطلب — وهذا يومُه ومصادرُه.
final class RetroactiveRebuildAccepted extends RetroactiveRebuildPlan {
  /// ينشئ خطة مقبولة.
  const RetroactiveRebuildAccepted({
    required this.date,
    required this.today,
    required this.sourceIds,
  });

  /// اليوم المستهدَف **بعد تحليله**.
  final CalendarDay date;

  /// يومُ المنصّة كما قيس — ★ **ومنه يُشتقّ وسمُ «⟳»** داخل الباني.
  final CalendarDay today;

  /// المصادر المطلوبة صراحةً — و`null` تعني **كلَّ المصادر** (تُقرأ لاحقاً).
  final List<String>? sourceIds;
}

/// يخطّط إعادةَ البناء — **دالة خالصة، وهي حارس التفويض الفعلي**.
///
/// ★ **ترتيب الفحوص مقصود:** الحالة ثم الهوية ثم محتوى الطلب — ⟵ **فلا
/// يُفحَص محتوى طلبٍ مرفوضٍ أصلاً** (نفسُ ترتيب `planOwnerBootstrap`).
RetroactiveRebuildPlan planRetroactiveRebuild(
  RetroactiveRebuildRequest request,
) {
  // ① «التعطيل فوري ونافذ» — `authentication-policy.md` §2 القاعدة 3.
  if (request.actor.disabled) {
    return const RetroactiveRebuildRejected(CallableError.accountDisabled);
  }

  // ② ★★★ **الهوية وحدها هي التفويض هنا** — راجع ترويسة الملف: ⛔ **لا مفتاحَ
  //    في الكتالوج لهذه العملية**، ★ **وهذا السطر هو الحارس كلُّه.**
  final String registered = request.registeredOwnerUserId.trim();
  if (registered.isEmpty || request.actor.userId != registered) {
    return const RetroactiveRebuildRejected(CallableError.permissionMissing);
  }

  // ③ معرّف الطلب إلزامي — ★ **فمخرَجُ التشغيل يُربَط برَنبوكه** (§و).
  if (request.requestId.trim().isEmpty) {
    return const RetroactiveRebuildRejected(CallableError.invalidArgument);
  }

  // ④ ★★★ يومُ المنصّة — ⛔ **وتعذّرُ قياسه رفضٌ لا افتراض** (راجع الحقل).
  final CalendarDay? today = request.platformToday;
  if (today == null) {
    return const RetroactiveRebuildRejected(CallableError.internal);
  }

  // ⑤ اليوم المستهدَف — ⛔ **والمشوَّه طلبٌ غيرُ صالح لا يومٌ يُخمَّن.**
  final CalendarDay? date = CalendarDay.tryParseCompact(request.date);
  if (date == null) {
    return const RetroactiveRebuildRejected(CallableError.invalidArgument);
  }

  // ⑥ ⛔⛔★★★ **والمستقبليُّ مرفوضٌ مطلقاً** — ★ **نظيرُ `agedClearanceRejection`
  //    حرفياً** (`aged_remainder.dart`): ⟵ **ولا دفترَ ليومٍ لم يأتِ**،
  //    ★ **وبناءُ بطاقتِه يكتب أصفاراً تُقرأ حقيقةً.**
  if (date.compareTo(today) > 0) {
    return const RetroactiveRebuildRejected(CallableError.futureDateRejected);
  }

  // ⑦ المصادر — ★ **`null` كلُّ المصادر**، ⛔ **والفارغةُ رفض** (راجع الحقل).
  final List<String>? requested = request.sourceIds;
  if (requested != null) {
    if (requested.isEmpty) {
      return const RetroactiveRebuildRejected(CallableError.invalidArgument);
    }
    if (requested.any((String id) => id.trim().isEmpty)) {
      return const RetroactiveRebuildRejected(CallableError.invalidArgument);
    }
  }

  return RetroactiveRebuildAccepted(
    date: date,
    today: today,
    // ★ **مُشذَّبةٌ ومُزالُ التكرار** — ⟵ **فمصدرٌ مذكورٌ مرتين لا يُبنى مرتين.**
    sourceIds: requested == null
        ? null
        : <String>{for (final String id in requested) id.trim()}.toList(),
  );
}

/// ★★★ يبني بنودَ المتبقي المتأخر **من أرصدةٍ مقروءةٍ** لا من كتابةٍ جارية.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **ولماذا يُعاد استعمالُ [agedRemaindersFromBalanceWrites] نفسِها:**
/// ★ **الثابتُ واحد** — «**بندُ متبقٍّ قائمٌ ⟺ رصيدُ (مصدر × نوع × تاريخ
/// مخزون) موجبٌ تماماً**» — ⟵ **ونسخةٌ ثانيةٌ منه هنا كانت ستفترق عن
/// أصلها عند أول تعديل** (`coding-standards.md` §2.2). ★ **فهذه الدالة
/// *مُحوِّلُ شكلٍ* لا حاسبة**: تُلبِس مستندَ الرصيد المقروء ثوبَ
/// [InventoryWrite] ⛔ **ولا تقرأ حقلاً واحداً بنفسها.**
///
/// ⚠️⚠️★★ **وهذا هو علاجُ [`DEBT-96`] حرفياً** (سجل الديون): «**العلاجُ
/// مسحةٌ تُشغَّل مرةً واحدة تقرأ `item_daily_balances` بأرصدةٍ موجبة وتكتب
/// بندَها**» — ★ **وهي جزءٌ طبيعيٌّ من مُعيد البناء وأداةِ تشغيله.**
/// ⟵ **فالبنودُ السابقةُ لنشرِ الراصد لا تظهر حتى تُلمَس**، ⛔ **وهذه تلمسها.**
/// ═══════════════════════════════════════════════════════════════════════
AgedRemainderSet agedRemaindersFromStoredBalances(
  Iterable<StoredDocument> balances,
) =>
    agedRemaindersFromBalanceWrites(<InventoryWrite>[
      for (final StoredDocument balance in balances)
        InventoryWrite(
          collectionId: itemDailyBalancesCollection,
          documentId: balance.id,
          fields: _rewrapDecimals(balance.fields),
          // ⛔ **ولا قناعَ هنا** — ★ **القناعُ للكتابة، وهذه قراءةٌ مُلبَسة**:
          //    ⟵ **و[agedRemaindersFromBalanceWrites] لا تقرؤه أصلاً.**
          updateMask: const <String>[],
        ),
    ]);

/// ★★★ يُعيد لفَّ الكسور المقروءة في [DecimalValue] — **قبل أن تُكتب ثانيةً**.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **ولماذا لزمت — عطلٌ حقيقيٌّ رصده التشغيل الحيّ لا المراجعة
/// (2026-09-05):** ★ **مسحةُ 2026-08-30 ردّت**
/// «`الفاصلة العائمة مرفوضة — المبلغ عدد صحيح بالريال (ADR-0015): 10.0`»
/// ⟵ **وأسقطت `SRC-001` في أربعة أيامٍ من عشرة** (⛔ **وهي أيامُ السكرب
/// وحدها**: `26` · `28` · `30` · `02`).
///
/// ★★ **والسببُ لا-تماثلٌ مقصودٌ بين طرفَي الرحلة** — ⛔ **لا خللٌ في أيٍّ
/// منهما**: **الكاتبُ يُغلِّف كلَّ كسرٍ في [DecimalValue] بوعي** (`ADR-0015`
/// القاعدة 9: **الفاصلة العائمة مرفوضةٌ إلا بغلافٍ صريح**)، **والقارئُ
/// يفكُّه إلى `double` عارٍ** (`firestore_decode.dart`) ⟵ **لأن قارئَه
/// الأصليَّ يحسب ولا يُعيد الكتابة.** ⛔ **وهذا المسار أولُ من يقرأ ثم يكتب
/// القيمةَ نفسَها**، ★ **فظهر السقوطُ عنده أولاً.**
///
/// ⛔⛔ **ولم يُخفَّف الحارسُ ولا الترميز** — ★ **العلاجُ في الطرف الذي
/// أحدث اللا-تماثل**: ⟵ **الرقمُ يعود إلى الغلاف الذي كُتب به** ⛔ **بلا
/// تقريبٍ ولا تحويلٍ يفقد الكسر** (`ADR-0015` القاعدة 4).
///
/// ⚠️ **والصحيحُ يبقى صحيحاً** — ★ **فالحبّةُ `int` والوزنُ كسر**: ⛔ **ولفُّ
/// عددٍ صحيحٍ كان سيكتب رصيدَ الحبّة عشرياً** فيُخالف `ADR-0015`.
/// ═══════════════════════════════════════════════════════════════════════
Map<String, Object?> _rewrapDecimals(Map<String, Object?> fields) =>
    <String, Object?>{
      for (final MapEntry<String, Object?> field in fields.entries)
        field.key: switch (field.value) {
          final double number => DecimalValue(number),
          final Object? other => other,
        },
    };

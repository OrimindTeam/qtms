/// التسعير اليومي — **التخطيط الخالص** لعملية `WU-005` (`M9`).
///
/// ★ **مفصول عن الشبكة بنفس منطق `inventory.dart`:** `ADR-0013` القاعدة 3
/// تجعل **فحص التفويض في الكود** هو الحارس الوحيد لهذا المسار، فالدالة تعمل
/// بامتياز إداري يتجاوز قواعد الحماية. ★ **وحارسٌ لا يُختبَر بلا سحابة
/// حارسٌ غير مُختبَر** — فكل قرار هنا **دالة خالصة**.
///
/// ★ **وكل قاعدة من طبقة النطاق لا من هنا** (`qtms_domain`) —
/// ⛔ **ولا تُعاد كتابتها** (`coding-standards.md` §2.2).
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔★★ **ستة قيود بندُ قبولٍ هنا** — ★ **و`daily_prices` `allow create,
/// update: if false`** (`ADR-0013` القاعدة 2 · `DEBT-21` ①):
///
///   ① **الصلاحية** `dailyPriceWrite` — ⛔ **ولا قاعدة حماية تحرس هذا المسار.**
///   ② ★★ **نطاق المصادر** — `inScope(sourceId)`: ⛔ **قيدٌ يعلو على كل
///      صلاحية** (`GR-23`)، ★ **وإسقاطه يُسعِّر مخزن مصدرٍ لمن لا يراه.**
///   ③ ★★ **لا يُسعَّر نوعٌ لا كمية له في مخزون اليوم** (`FR-M9-02` · `E-33`)
///      — ★ **مقيساً من الدفتر داخل المعاملة** ⛔ **لا من الملخص ولا من
///      الجهاز** (`ADR-0008`).
///   ④ ★ **وحدة السعر وحدةُ النوع المخزَّنة** (`FR-M9-06` · `FR-M5-03`) —
///      ⛔ **لا وحدةٌ مُرسَلة.**
///   ⑤ ★★ **سبب نصّي غير فارغ لكل تغييرٍ لسعرٍ قائم** (`ADR-0004` ·
///      `CR-002` · `FR-M9-11`) — ⛔ **ولا يُشترَط على تسعيرٍ أوّل.**
///   ⑥ **اليوم من المنصّة** — `FR-M9-03` · `GR-54` · `E-41`.
/// ═══════════════════════════════════════════════════════════════════════
///
/// ⛔★★ **ولا مسار حذفٍ في هذا الملف إطلاقاً** (`GR-07`) — ★ **و«تفريغ
/// السعر» كتابةُ `null` في الحقلين** ⛔ **لا حذفُ المستند**: المستند يحمل
/// **من فرَّغ ومتى** (`FR-M9-11`)، ⟵ **وحذفُه يمحو ذلك الأثر.**
library;

import 'package:qtms_domain/qtms_domain.dart';

import 'callable.dart';
import 'identity_gateway.dart';
import 'inventory.dart' show InventoryWrite, ItemRead, LedgerRead;

/// نوع عملية تسعير — ويحدد الصلاحية التي لا تُنفَّذ بدونها.
///
/// ⚠️ **وعمليةٌ واحدة لا ثلاث:** `FR-M9` **لا يعرف «إلغاء تسعير»** — ★ **بل
/// «تفريغاً» يكتب `null`** — ⛔ **ولا يعرف مساراً منفصلاً للتعديل**: نفس
/// الشاشة تُدخل وتُعدِّل (`FR-M9-11`). ⟵ ★ **والتمييز بين الإنشاء والتعديل
/// يقع على السطر لا على العملية** (راجع [planDailyPricing]).
enum DailyPricingOperation {
  /// `writeDailyPrices` — يشترط `dailyPriceWrite` (`FR-M9-01` … `FR-M9-08`).
  writeDailyPrices(Permission.dailyPriceWrite);

  const DailyPricingOperation(this.requiredPermission);

  /// الصلاحية التي لا تُنفَّذ العملية بدونها.
  final Permission requiredPermission;
}

/// نتيجة التخطيط — إما خطة كتابة وإما رفض مصنَّف.
sealed class DailyPricingPlan {
  /// ينشئ النتيجة.
  const DailyPricingPlan();
}

/// رُفض الطلب قبل أي كتابة.
final class DailyPricingRejected extends DailyPricingPlan {
  /// ينشئ رفضاً.
  const DailyPricingRejected(this.error);

  /// رمز الرفض من كتالوج الأخطاء.
  final CallableError error;
}

/// قُبل الطلب — وهذه كتاباته وقيده.
final class DailyPricingAccepted extends DailyPricingPlan {
  /// ينشئ خطة مقبولة.
  const DailyPricingAccepted({required this.writes, required this.entry});

  /// المستندات المكتوبة — ⛔ **ولا تكون فارغة**.
  final List<InventoryWrite> writes;

  /// قيد التدقيق — **يُكتب في المعاملة نفسها** (`ADR-0013` القاعدة 1).
  final AuditEntry entry;
}

/// طلب تسعير مُتحقَّق من هوية مُنفِّذه.
final class DailyPricingRequest {
  /// ينشئ الطلب.
  const DailyPricingRequest({
    required this.actor,
    required this.requestId,
    required this.sourceId,
    required this.date,
    this.batch,
    this.storedSource,
    this.items = const <String, ItemRead>{},
    this.ledger = const <String, List<LedgerRead>>{},
    this.storedPrices = const <String, Map<String, Object?>?>{},
    this.reason,
    this.deviceInfo,
  });

  /// المُنفِّذ **بحالته الآن من خدمة المصادقة**.
  final AccountRecord actor;

  /// ★ معرّف الطلب — **وهو معرّف قيد التدقيق نفسه** (`api-overview.md` §4).
  final String requestId;

  /// المصدر المستهدف.
  final String sourceId;

  /// ★★ **يوم السعر** — ⛔ **من زمن المنصّة داخل المعاملة** لا من الجهاز
  /// ولا من ساعة الحاوية (`GR-54` · `E-41`).
  final CalendarDay date;

  /// الدفعة المُتحقَّق منها.
  final ValidatedDailyPriceBatch? batch;

  /// سجل المصدر كما قُرئ — ⛔ **و`null` رفضٌ لا تجاوز**.
  final Map<String, Object?>? storedSource;

  /// سجلات الأنواع المطلوبة بمعرّفاتها.
  final Map<String, ItemRead> items;

  /// ★★ **حركات الدفتر لكل نوع في هذا اليوم** — **مقروءةً داخل المعاملة**
  /// (`ADR-0008`)، ★ **ومنها يُقاس أن للنوع كميةً اليوم** (`FR-M9-02`).
  final Map<String, List<LedgerRead>> ledger;

  /// ★ سجلات الأسعار القائمة بمفتاح النوع — `null` تعني **غيابها**.
  ///
  /// ★★ **وغيابُها «غير مسعَّر» لا «صفر»** — ⟵ **وهو ما يجعل السطر إنشاءً
  /// لا تعديلاً**، ⛔ **فلا يُطالَب بعلّة** (راجع `changesStoredPrice`).
  final Map<String, Map<String, Object?>?> storedPrices;

  /// ★ سبب التعديل — **إلزامي إذا غيّرت الدفعة سعراً قائماً** (`ADR-0004`).
  final String? reason;

  /// وصف الجهاز للسجل — ⛔ بلا بيانات حساسة.
  final String? deviceInfo;
}

/// ★★ فحوص الحالة والصلاحية والنطاق — **تُستدعى قبل فتح المعاملة**.
///
/// ⚠️ **ولماذا مُصدَّرة:** التخطيط يحتاج **قراءةً داخل معاملة** قبل أن
/// يكتمل، ⟵ **وفتحُ معاملةٍ لطلبٍ يرفضه نقصُ الصلاحية هدرٌ وقفلٌ بلا داعٍ**.
/// ★ **والفحص يُعاد كاملاً** في [planDailyPricing] ⛔ **فلا مسار يتخطّاه.**
DailyPricingRejected? dailyPricingGate(
  DailyPricingRequest request,
  DailyPricingOperation operation,
) {
  // ① «التعطيل فوري ونافذ» — `authentication-policy.md` §2 القاعدة 3.
  if (request.actor.disabled) {
    return const DailyPricingRejected(CallableError.accountDisabled);
  }
  // ② الصلاحية — ⛔ ولا قاعدة حماية تحرس هذا المسار.
  if (!request.actor.claims.has(operation.requiredPermission)) {
    return const DailyPricingRejected(CallableError.permissionMissing);
  }
  // ③ ★★ **النطاق — قيدٌ يعلو على الصلاحية** (`GR-23`).
  //    ⛔ **والغياب منعٌ لا سماح** (`canAccessSource` يُرجِع `false`).
  if (!request.actor.claims.canAccessSource(request.sourceId)) {
    return const DailyPricingRejected(CallableError.sourceOutOfScope);
  }
  // ④ معرّف الطلب إلزامي — وبدونه لا تتحقق اللاتكرارية عند إعادة الإرسال.
  if (request.requestId.trim().isEmpty) {
    return const DailyPricingRejected(CallableError.invalidArgument);
  }
  return null;
}

/// يخطّط عملية تسعير — **دالة خالصة، وهي حارس التفويض الفعلي**.
DailyPricingPlan planDailyPricing(
  DailyPricingRequest request,
  DailyPricingOperation operation,
) {
  final DailyPricingRejected? gate = dailyPricingGate(request, operation);
  if (gate != null) return gate;

  final ValidatedDailyPriceBatch? batch = request.batch;
  if (batch == null || batch.sourceId != request.sourceId) {
    return const DailyPricingRejected(CallableError.invalidArgument);
  }

  // ★ **سجل المصدر — موجودٌ ونشط.**
  final Map<String, Object?>? source = request.storedSource;
  // ⛔ **مصدرٌ لم يُقرأ ⟵ رفض** — الرفض الافتراضي.
  if (source == null) {
    return const DailyPricingRejected(CallableError.internal);
  }
  // ⚠️ **والتسعير فعلٌ أماميّ لا تصحيحُ ماضٍ** — ★ **فيُمنَع على مصدرٍ
  //    عُطِّل** بنفس منطق `_sourceGate` في `inventory.dart` («المنع على
  //    التوريد الجديد»)، ⛔ **ولا استثناءَ إلغاءٍ هنا** لأن لا إلغاء أصلاً.
  if (source['isActive'] == false) {
    return const DailyPricingRejected(CallableError.sourceInactive);
  }

  final String? reason = _trimmed(request.reason);
  bool amendsExisting = false;

  final List<InventoryWrite> writes = <InventoryWrite>[];
  final Map<String, Object?> before = <String, Object?>{};
  final Map<String, Object?> after = <String, Object?>{};

  for (final ValidatedDailyPriceLine line in batch.lines) {
    final ItemRead? item = request.items[line.itemKey];
    // ★ **النوع موجودٌ ونشط ومرتبطٌ بالمصدر** — `FR-M5-10` · `BR-M9-01`.
    if (item == null || !item.isActive) {
      return const DailyPricingRejected(CallableError.invalidArgument);
    }
    if (!item.sourceIds.contains(request.sourceId)) {
      return const DailyPricingRejected(CallableError.invalidArgument);
    }
    // ④ ★ **وحدة السعر وحدةُ النوع المخزَّنة** — ⛔ **لا المُرسَلة.**
    if (item.unit != line.unit) {
      return const DailyPricingRejected(CallableError.itemUnitLocked);
    }

    // ③ ★★★ **لا يُسعَّر نوعٌ لا كمية له في مخزون اليوم** — راجع أدناه.
    final DailyPricingRejected? stock = _todayStockGate(request, item);
    if (stock != null) return stock;

    final Map<String, Object?>? stored = request.storedPrices[line.itemKey];
    if (changesStoredPrice(line: line, stored: stored)) {
      amendsExisting = true;
      before[line.itemKey] = _priceValues(
        distribution: stored?['distributionPrice'],
        minimum: stored?['minCashPrice'],
      );
      after[line.itemKey] = _priceValues(
        distribution: line.distributionPrice?.riyals,
        minimum: line.minCashPrice?.riyals,
      );
    } else if (stored == null) {
      after[line.itemKey] = _priceValues(
        distribution: line.distributionPrice?.riyals,
        minimum: line.minCashPrice?.riyals,
      );
    }

    writes.add(_priceWrite(request: request, line: line, item: item));
  }

  // ⛔⛔★★★ **حارسُ السبب حُذف بـ`ADR-0020` (2026-08-27)** — ★ **السبب
  //    اختياريٌّ في كل عملية**، ⟵ **ولا رفضَ لغيابه.** ⛔ **ولا يُعبَّأ
  //    آلياً:** ★ **ما لم يكتبه إنسانٌ لا يُخزَّن.**

  return DailyPricingAccepted(
    writes: writes,
    entry: AuditEntry(
      id: request.requestId.trim(),
      // ⚠️ قيمة مبدئية لا تُكتب — الكاتب يستبدلها بوقت المنصة.
      occurredAt: DateTime.utc(1970),
      actor: AuditActor(
        userId: request.actor.userId,
        userName: request.actor.userName,
      ),
      // ★ **إنشاءٌ ما لم تُغيَّر قيمةٌ قائمة** — `FR-M9-01`: **كل يوم يبدأ
      //   بلا أسعار**، ⟵ **فالتسعير الأول إنشاءٌ لا تعديل.**
      action: amendsExisting ? AuditAction.amend : AuditAction.create,
      reason: reason,
      target: AuditTarget(
        entityType: dailyPriceEntityType,
        // ★★ **دفعةُ يومٍ لمصدر — لا مستندٌ مرقَّم:** `daily_prices` **بلا
        //   `documentNumber`** (`schema/daily-prices.md`)، ⟵ **ومعرّفها
        //   `{sourceId}_{date}` بنفس ترتيب `naming-conventions.md` §4**،
        //   ★ **وتفصيلُ كل نوعٍ في `valuesBefore`/`valuesAfter`** بمفتاحه.
        entityId: '${request.sourceId}_${request.date.format()}',
        // ★ **المصدر في القيد** — ⟵ **فيُفلتَر السجل بالنطاق** (`FR-M18-14`).
        sourceId: request.sourceId,
      ),
      valuesBefore: before,
      valuesAfter: after,
      deviceInfo: request.deviceInfo,
    ),
  );
}

/// ★★★ **لا يُسعَّر نوعٌ لا كمية له في مخزون اليوم** — `FR-M9-02` · `E-33`.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⚠️⚠️ **ولماذا يُقاس من الدفتر لا من `item_daily_balances`:** `ADR-0008`
/// يجعل الملخص **مشتقّاً لا مصدرَ حقيقة**، ونصُّه أن الرصيد **«يُقرأ داخل
/// المعاملة الذرّية نفسها»** — ⟵ **وملخصٌ متأخرٌ لحظةً كان سيسمح بتسعير
/// نوعٍ فرغ مخزنُه، أو يمنع تسعير نوعٍ ورد للتوّ.**
///
/// ★★ **والقياس بـ`computeItemBalance` نفسها** التي يبني بها `WU-003` كل
/// رصيد — ⛔ **ولا معادلة ثانية** (`coding-standards.md` §2.2).
///
/// ⚠️ **و«له كمية» تعني موجباً تماماً** — `BR-M9-01` نصّاً: «**الأنواع التي
/// لها كمية في مخزون اليوم**»، ★ **والصفر ليس كمية**: نوعٌ ورد ثم صُرف
/// بالكامل **رصيده صفر**، ⟵ **ولا يبقى ما يُسعَّر.**
/// ═══════════════════════════════════════════════════════════════════════
DailyPricingRejected? _todayStockGate(
  DailyPricingRequest request,
  ItemRead item,
) {
  final List<LedgerRead> reads =
      request.ledger[item.itemId] ?? const <LedgerRead>[];
  final Outcome<StockQuantity> balance = computeItemBalance(
    movements: <StockMovement>[
      for (final LedgerRead read in reads) read.movement,
    ],
    unit: item.unit,
  );
  if (balance case Failure<StockQuantity>()) {
    // ⛔ **وحدةٌ غريبة في الدفتر ⟵ فسادُ بيانات** — `GR-19`.
    return const DailyPricingRejected(CallableError.itemUnitLocked);
  }
  final StockQuantity quantity = (balance as Success<StockQuantity>).value;
  if (!quantity.isPositive) {
    // ⛔ **ورمزُه «كمية غير كافية»** — ★ **رمزٌ قائم في الكتالوج يصف الحالة
    //   حرفياً** (`ERR_STOCK_001`)، ⛔ **ولا يُخترَع رمزٌ جديد**
    //   (`error-codes-catalog.md` §3 القاعدتان 4 و5).
    return const DailyPricingRejected(CallableError.insufficientStock);
  }
  return null;
}

/// ★ كتابة سجل سعرٍ واحد — **بمفتاحه المركّب** ([dailyPriceId]).
InventoryWrite _priceWrite({
  required DailyPricingRequest request,
  required ValidatedDailyPriceLine line,
  required ItemRead item,
}) {
  final Map<String, Object?> fields = <String, Object?>{
    'sourceId': request.sourceId,
    'itemKey': line.itemKey,
    // ★ **الاسم من سجل النوع لا من الحمولة** — `naming-conventions.md` §4
    //   (النسخ المقصودة)، ⟵ **فالسجل يُقرأ ويُطبَع بلا قراءةٍ ثانية.**
    'itemName': item.name,
    // ④ ★ **الوحدة المخزَّنة** — `FR-M9-06` · `FR-M5-03`.
    'unit': item.unit.name,
    'date': request.date.asUtcMidnight(),
    // ⛔★★ **والقيمة `null` صريحة لا مفتاحٌ غائب:** «التفريغ» **فعلٌ مقصود**
    //    (`schema/daily-prices.md`: `number | null`)، ⟵ **ومفتاحٌ محذوف
    //    من القناع كان يُبقي السعر القديم قائماً بصمت.**
    'distributionPrice': line.distributionPrice?.riyals,
    'minCashPrice': line.minCashPrice?.riyals,
    // ★ **مشتقٌّ للفلترة والفهرسة** — `schema/daily-prices.md` (الفهرس
    //   `sourceId ↑ · date ↑ · isPricingComplete ↑`) · `FR-M9-05`.
    'isPricingComplete': line.complete,
    'modifiedBy': request.actor.userId,
  };
  return InventoryWrite(
    collectionId: dailyPricesCollection,
    documentId: dailyPriceId(
      sourceId: request.sourceId,
      itemKey: line.itemKey,
      date: request.date,
    ),
    fields: fields,
    // ★ **قناعٌ يشمل الحقلين المالية** — ⟵ **فالتفريغ يمحو فعلاً.**
    updateMask: fields.keys.toList(),
    serverTimestampFields: const <String>['lastModifiedAt'],
  );
}

/// ★ زوج السعرين كما يدخل قيد التدقيق — ⛔ **والغياب `null` صريح**.
Map<String, Object?> _priceValues({
  required Object? distribution,
  required Object? minimum,
}) =>
    <String, Object?>{
      'distributionPrice': distribution,
      'minCashPrice': minimum,
    };

String? _trimmed(String? value) {
  final String? text = value?.trim();
  return (text == null || text.isEmpty) ? null : text;
}

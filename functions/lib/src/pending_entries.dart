/// ★★★ **باني المركز المعلّق** — الطرف السحابي (`WU-009` · `FR-SYS-09`).
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **والبنود تُنشئها وتحذفها السحابة حصراً** (`FR-SYS-09` ·
/// `database-overview.md` §2 · `firestore.rules`: `pending_entries` **`allow
/// write: if false`**) — ★ **ولذلك لا مسارَ لها في التطبيق إطلاقاً.**
///
/// ★★★ **وتُكتب داخل معاملة مستندها نفسِها** — ⛔ **لا بمشغّلٍ بعد الالتزام:**
/// ⟵ **بنفس علّة `ADR-0013` القاعدة 1 حرفياً** (قيدُ التدقيق): **المشغّل يصل
/// بعد أن التزمت الكتابة فعلاً، فلا شيء بقي ليُبطَل** — ★ **ومركزٌ يتأخّر
/// لحظةً عن مستنده يُظهر نقصاً أُدخِل أو يُخفي نقصاً وقع**، ⛔ **وكلاهما
/// يُفقِد الشاشةَ غرضَها الوحيد** (`GR-50`: يلاحق ويذكّر).
///
/// ⚠️⚠️ **وهذا هو نفسُ ما تعنيه `c3-component-diagram.md` §3 بوضع «باني
/// المركز المعلّق» في «مشغَّلة بالكتابة»** — ★ **الكتابةُ هي المُطلِق**،
/// ⟵ **وتنفيذُه في المعاملة نفسها هو الصورة التي اعتمدها هذا المشروع لكل
/// مشتقّاته** (`dealer_balances` · `item_daily_balances` · سجل التدقيق).
///
/// ⛔⛔★★★ **ولا دالةَ هنا ترفض شيئاً ولا تُوقِف معاملة** — `FR-SYS-06`
/// (**حرجة**): **المركز لا يمنع أي عملية.** ⟵ **وكل ما يُنتجه هذا الملف
/// كتاباتٌ وحذوفات** ⛔ **ولا رمزَ خطأٍ واحد.**
/// ═══════════════════════════════════════════════════════════════════════
library;

import 'package:qtms_domain/qtms_domain.dart';

import 'audited_transaction.dart';
import 'firestore_value.dart';
import 'inventory.dart' show InventoryWrite;

/// ★ كتابات البنود القائمة — **مستندٌ لكل بند بمعرّفه الحتمي**.
///
/// ⚠️ **والقناع كاملُ الحقول** — ⟵ **فبندٌ كُتب أمس بنصٍّ ثم تغيّر نصُّه
/// اليوم** (سعرُ توزيعٍ أُدخِل وبقي الحدُّ الأدنى) **يُستبدَل بالكامل**،
/// ⛔ **ولا يبقى نصٌّ قديم يصف نقصاً غير القائم.**
List<PendingDocument> pendingEntryDocuments(PendingEntrySet set) =>
    <PendingDocument>[
      for (final PendingEntryDraft draft in set.drafts)
        () {
          final Map<String, Object?> fields = draft.toFields();
          return PendingDocument(
            collectionId: pendingEntriesCollection,
            documentId: draft.entryId,
            fields: fields,
            updateMask: fields.keys.toList(),
            // ★ **ووقت الرصد من المنصّة** — `GR-54`: ⛔ **ولا ساعةَ حاوية**،
            //   ⟵ **وهو ما يجعل «منذ متى وهذا ناقص؟» سؤالاً له جواب.**
            serverTimestampFields: const <String>['detectedAt'],
          );
        }(),
    ];

/// ★★ حذوفات البنود التي زالت — §7: **«يختفي فور الإدخال الفعلي»**.
///
/// ⛔⛔★★ **وهذا هو الحذف الثاني المسموح به في النظام كله** — ★ **بعد قالب
/// الدور غير المُسنَد** (`IQ-018`)، ⛔ **ولا يُقاس عليهما ثالث:**
/// ⟵ **`security-requirements.md` §2 البند 1 يمنع الحذف في **السجلات
/// والحركات**، ★ **وبند المركز ليس سجلاً ولا حركة**: **مشتقٌّ بالكامل قابل
/// لإعادة البناء من مستنداته** (`PAT-07` · `backup-and-recovery-policy.md`:
/// «**مشتقّة بالكامل**»). ⟵ **فلا مرجعٌ ينكسر ولا تاريخٌ يضيع** —
/// ★ **والتاريخُ محفوظٌ في سجل التدقيق للمستند نفسه لا في بنده المعلّق.**
///
/// ⚠️ **والحذف على مستندٍ غائب عديمُ الأثر** — ⟵ **فلا قراءةَ سابقة له**،
/// ★ **وهو ما تُتيحه حتميّةُ [pendingEntryId].**
List<PendingDeletion> pendingEntryDeletions(PendingEntrySet set) =>
    <PendingDeletion>[
      for (final String id in set.clearedIds)
        PendingDeletion(
          collectionId: pendingEntriesCollection,
          documentId: id,
        ),
    ];

// ═════════════════════════════════════════════════════════════════════════
// `M7` — من حالة الجونية بعد الكتابة
// ═════════════════════════════════════════════════════════════════════════

/// ★★★ بنود `M7` **من حالة الجونية كما ستصير بعد هذه العملية**.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ★★ **والحالة مخزَّنةٌ في المستند أصلاً** — `sack-intake-design.md` §5:
/// «**`remainingWeight` · `lostWeightConfirmed` · `taxPerKilo`**» ⟵ **فلا
/// شيء يُستنتَج هنا**: ★ **تُقرأ الحالةُ المخزَّنة ثم تُغطّى بما تكتبه هذه
/// العملية** (`after`)، ⛔ **ولا يُقرأ المستند بعد الالتزام** — ★ **فالبند
/// يجب أن يُكتب في المعاملة نفسها.**
///
/// ⛔⛔ **والضريبة في `finance/current` وحدها** (`ADR-0011`) — ⟵ **فلا
/// تُقرأ من كتابة المستند الأب أبداً**: ★ **[hasTax] يمرّرها المُنادي من
/// المستند الفرعي أو من العملية الجارية.**
///
/// ⚠️ **و[SackWeightState] يُشتقّ بـ`sackWeightStateOf` وحدها** — ⛔ **ولا
/// نسخةَ ثانية من شرط الهامش** (`coding-standards.md` §2.2).
/// ═══════════════════════════════════════════════════════════════════════
PendingEntrySet pendingFromSackState({
  required Iterable<InventoryWrite> writes,
  required String sackId,
  required String sourceId,
  required CalendarDay stockDate,
  required String storedDisplayName,
  required bool storedHasLines,
  required double storedRemainingKilograms,
  required bool storedLostWeightConfirmed,
  required bool hasTax,
  bool isCancelled = false,
}) {
  final Map<String, Object?> after = _sackDocumentFields(writes);

  final Object? lines = after['lines'];
  final bool hasLines =
      lines is List<Object?> ? lines.isNotEmpty : storedHasLines;

  final double remaining = after.containsKey('remainingWeight')
      ? _numberOf(after['remainingWeight'])
      : storedRemainingKilograms;
  final bool confirmed = after['lostWeightConfirmed'] is bool
      ? after['lostWeightConfirmed']! as bool
      : storedLostWeightConfirmed;

  final Object? name = after['displayName'];
  final Object? status = after['status'];

  return describeSackPending(
    sackId: sackId,
    sourceId: sourceId,
    stockDate: stockDate,
    displayName:
        name is String && name.trim().isNotEmpty ? name : storedDisplayName,
    documentNumber: sackId,
    hasTax: hasTax,
    hasLines: hasLines,
    weightState: sackWeightStateOf(
      remainingKilograms: remaining,
      lostWeightConfirmed: confirmed,
    ),
    // ★ **والإلغاء يُقرأ من الكتابة نفسها إن وقع فيها** — ⟵ **فلا يُمرَّر
    //   مرتين ولا يُنسى في مسار.**
    isCancelled: isCancelled || status == SackStatus.cancelled.name,
  );
}

/// ★ حقول مستند الجونية في هذه الكتابة — **وفارغةٌ إن لم تُكتَب**.
Map<String, Object?> _sackDocumentFields(Iterable<InventoryWrite> writes) {
  for (final InventoryWrite write in writes) {
    if (write.collectionId == sacksCollection) return write.fields;
  }
  return const <String, Object?>{};
}

// ═════════════════════════════════════════════════════════════════════════
// `M9` — من كتابة الرصيد الناتجة
// ═════════════════════════════════════════════════════════════════════════

/// ★★★ بنود `M9` **مشتقّةً من كتابات الرصيد التي أنتجتها المعاملة نفسها**.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⚠️⚠️★★★ **ولماذا من كتابة الرصيد لا من الحمولة ولا من قراءةٍ سابقة:**
/// `FR-M9-10` يشترط **«له كمية في مخزون اليوم»**، ⟵ **والكميةُ المقصودة هي
/// الرصيد *بعد* هذه العملية لا قبلها**: ★ **توريدٌ يُنشئ البند، وتوزيعٌ
/// يستنفد الرصيد يُزيله** (`pending-entries-design.md` §9: «**نوع نفد رصيده
/// اليوم ⟵ يختفي بند تسعيره**»).
///
/// ★★★ **وكل مُخطِّطٍ يكتب رصيداً يحسبه أصلاً** (`ItemDailyFlow.balance` —
/// `computeItemDailyFlow`) ⟵ **فالقراءة من كتابته هي قراءةُ الرقم نفسه**،
/// ⛔ **ولا معادلةَ ثانية هنا** (`coding-standards.md` §2.2) ⛔ **ولا رصيدٌ
/// يُقاس مرتين فيفترق.**
///
/// ⛔⛔★★ **ويُتخطّى كل رصيدٍ ليوم غير [date]** — ★ **والتسعير يخصّ اليوم
/// وحده ويُصفَّر يومياً** (`FR-M9-01` · `GR-31`)، ⟵ **فبندٌ ليومٍ مضى
/// لا شاشةَ تُدخِله**: ⛔ **مطالبةٌ بلا وجهة.** ★ **ويُعاد النظر فيه مع
/// مسار تصريف المتبقي المتأخر** (`WU-019`) ⛔ **لا قبله.**
/// ═══════════════════════════════════════════════════════════════════════
PendingEntrySet pendingFromBalanceWrites({
  required Iterable<InventoryWrite> writes,
  required String sourceId,
  required CalendarDay date,
  Map<String, Map<String, Object?>?> storedPrices =
      const <String, Map<String, Object?>?>{},
  PendingPricingMode mode = PendingPricingMode.exact,
}) =>
    mergePendingSets(<PendingEntrySet>[
      for (final InventoryWrite write in writes)
        if (write.collectionId == itemDailyBalancesCollection)
          if (_balanceOf(write) case final _BalanceRow row)
            if (row.stockDate == date)
              if (mode == PendingPricingMode.exact || row.balance <= 0)
                describeItemPricingPending(
                  sourceId: sourceId,
                  itemKey: row.itemKey,
                  itemName: row.itemName,
                  date: date,
                  hasStock: row.balance > 0,
                  distributionPrice:
                      _priceOf(storedPrices[row.itemKey], 'distributionPrice'),
                  minCashPrice:
                      _priceOf(storedPrices[row.itemKey], 'minCashPrice'),
                ),
    ]);

/// ★★★ **دقّةُ ما يعرفه المُنادي عن السعر المخزَّن** — ⛔ **لا خيارُ أداء**.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ★★ **الثابتُ الذي يحفظه الوضعان معاً:** **بندُ `M9` قائمٌ ⟺ (رصيدٌ موجب
/// **و** تسعيرٌ ناقص)**. ⟵ **ويُحفَظ بثلاثة مواضعَ متكاملة:**
///
///   ① `writeDailyPrices` **يعرف الطرفين يقيناً** (الأسعار الجديدة، والرصيد
///      الموجب مضمونٌ ببوابة `_todayStockGate`) ⟵ **فيُنشئ ويمحو بدقّة.**
///   ② **أولُ رصيدٍ لمفتاحٍ لم يكن له رصيد** — ★ **وسعرُه غائبٌ يقيناً لا
///      افتراضاً:** ⟵ **`FR-M9-02` يمنع تسعير نوعٍ لا كمية له** (`E-33` ·
///      `_todayStockGate`)، **فمفتاحٌ بلا رصيدٍ يستحيل أن يحمل سعراً.**
///      ★ **وهو نظيرُ ما يقوله `sack_intake_handler._create` حرفياً**
///      («مفاتيح هذه الجونية تحمل تسلسلها الذي خُصِّص للتوّ … فلا حركة
///      سابقة يمكن أن تحمل المفتاح نفسه»).
///   ③ **ما سوى ذلك — رصيدٌ يتغيّر لمفتاحٍ قائم** ⟵ ★ **والبند إن وجب
///      وجودُه فهو موجودٌ أصلاً من ①/②**: ⛔ **فلا يُنشَأ ثانيةً بسعرٍ
///      مجهول** (فيُطالِب بما أُدخِل)، ★ **ويُمحى عند نفاد الرصيد وحده**
///      (`pending-entries-design.md` §9).
/// ═══════════════════════════════════════════════════════════════════════
enum PendingPricingMode {
  /// ★ السعر المخزَّن **معلومٌ أو غائبٌ يقيناً** — ⟵ **إنشاءٌ ومحوٌ بالدقة
  /// نفسها** (الحالتان ① و②).
  exact,

  /// ★★ السعر **مجهول** — ⟵ **محوٌ عند نفاد الرصيد وحده** (الحالة ③)،
  /// ⛔ **ولا إنشاء.**
  clearOnEmptyOnly,
}

/// ★★★ بنود `M9` **من الأسعار التي تكتبها هذه العملية نفسها** —
/// `AT-16`: «**ويختفي فور التسعير**».
///
/// ⚠️⚠️ **والرصيد الموجب مضمونٌ هنا بلا قياسٍ ثانٍ:** `_todayStockGate` في
/// `planDailyPricing` **يرفض تسعير نوعٍ لا كمية له** (`FR-M9-02` · `E-33`)
/// ⟵ **فكلُّ سطرٍ بلغ هذه النقطة له رصيدٌ موجب**، ⛔ **ولا يُعاد قياسه**
/// (`coding-standards.md` §2.2).
PendingEntrySet pendingFromPricedLines({
  required ValidatedDailyPriceBatch batch,
  required CalendarDay date,
}) =>
    mergePendingSets(<PendingEntrySet>[
      for (final ValidatedDailyPriceLine line in batch.lines)
        describeItemPricingPending(
          sourceId: batch.sourceId,
          itemKey: line.itemKey,
          // ★ **الاسم من السطر المُتحقَّق منه** — ★ **وهو مأخوذٌ من سجل
          //   النوع لا من الحمولة** (`daily_pricing_handler._validate`).
          itemName: line.itemName,
          date: date,
          hasStock: true,
          distributionPrice: line.distributionPrice,
          minCashPrice: line.minCashPrice,
        ),
    ]);

/// ★ صفُّ رصيدٍ مقروءٌ من كتابته — و`null` لكتابةٍ لا تصلح.
final class _BalanceRow {
  const _BalanceRow({
    required this.itemKey,
    required this.itemName,
    required this.stockDate,
    required this.balance,
  });

  final String itemKey;
  final String itemName;
  final CalendarDay stockDate;
  final double balance;
}

/// ★ يقرأ صفَّ الرصيد من حقول كتابته — ⛔ **ولا يرمي على شكلٍ غير متوقَّع**.
///
/// ⚠️ **والفشلُ هنا يعني «لا بند»** — ⛔ **لا معاملةً تسقط**: ★ **المركز
/// يذكّر ولا يمنع** (`FR-SYS-06`)، ⟵ **وإسقاطُ توزيعةٍ لأن بندَ تذكيرٍ
/// تعذّر بناؤه هو بالضبط ما يمنعه `GR-50`.**
_BalanceRow? _balanceOf(InventoryWrite write) {
  final Object? itemKey = write.fields['itemKey'];
  final Object? itemName = write.fields['itemName'];
  final Object? stockDate = write.fields['stockDate'];
  if (itemKey is! String || itemKey.isEmpty) return null;
  if (stockDate is! DateTime) return null;
  return _BalanceRow(
    itemKey: itemKey,
    itemName: itemName is String && itemName.isNotEmpty ? itemName : itemKey,
    stockDate: CalendarDay.fromUtc(stockDate.toUtc()),
    balance: _numberOf(write.fields['balance']),
  );
}

/// ★★ الكمية كما كُتبت — **صحيحٌ للحبّة و[DecimalValue] للوزن**.
///
/// ⛔ **ولا تُقرأ بـ`readInt` وحدها** — ★ **فرصيدٌ وزنيٌّ 0.5 كجم كان
/// سيُقرأ صفراً** ⟵ **فيختفي بندُ تسعيره وله كميةٌ فعلاً.**
double _numberOf(Object? raw) => switch (raw) {
      final DecimalValue value => value.value,
      final num value => value.toDouble(),
      _ => 0,
    };

/// ★ سعرٌ مخزَّن — و`null` **غيابٌ لا صفر** (`FR-M9-07`: التفريغ يكتب `null`).
Money? _priceOf(Map<String, Object?>? stored, String field) {
  if (stored == null) return null;
  final Object? raw = stored[field];
  return switch (raw) {
        final int value => Money(value),
        final double value when value == value.roundToDouble() =>
          Money(value.toInt()),
        _ => null,
      };
}

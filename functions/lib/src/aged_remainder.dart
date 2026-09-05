/// ★★★ **راصد المتبقي المتأخر** — الطرف السحابي (`WU-019` · `FR-M8-09`).
///
/// ★ **موضعُه المعلَن في المعمار:** `c3-component-diagram.md` §3 يُدرِج
/// **«راصد المتبقي المتأخر»** ضمن العمليات المشغَّلة بالكتابة، و`ADR-0009`
/// §القدرات يسمّيه بالاسم نفسِه.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **والبنودُ تُنشئها وتحذفها السحابةُ حصراً** — `firestore.rules`:
/// `aged_remainders` **`allow write: if false`** للجميع، ⟵ **فلا مسارَ لها
/// في التطبيق إطلاقاً** ⛔ **ولا زرَّ «إخفاء بند».**
///
/// ★★★ **وتُكتب داخل معاملة الحركة نفسِها** — ⛔ **لا بمشغّلٍ بعد الالتزام
/// ولا بجدولةٍ ليلية:** ⟵ **بنفس علّة `pending_entries.dart` حرفياً**
/// (`ADR-0013` القاعدة 1): **المشغّل يصل بعد أن التزمت الكتابة فلا شيء بقي
/// ليُبطَل**، ★ **وقائمةٌ تتأخّر لحظةً عن دفترها تُبقي بنداً صُرِّف للتوّ
/// أو تُخفي متبقياً وقع** — ⛔ **وكلاهما ينقض `GR-16`** («**ينبّه حتى
/// يُصرَّف بالكامل**»).
///
/// ⛔⛔★★★ **ولا دالةَ هنا ترفض شيئاً ولا تُوقِف معاملة** — ★ **نظيرُ
/// `FR-SYS-06` في المركز المعلّق**: ⟵ **التنبيهُ يلاحق ولا يمنع**،
/// ★ **وكلُّ ما يُنتجه هذا الملف كتاباتٌ وحذوفات** ⛔ **ولا رمزَ خطأٍ واحد.**
/// ═══════════════════════════════════════════════════════════════════════
///
/// ⚠️⚠️★★ **والبندُ يُكتب ليومِ الحركة أياً كان — ⛔ ولا يُفلتَر بـ«أمس»:**
/// ★ **«متأخر» صفةُ *قراءةٍ* لا صفةُ *كتابة*** — ⟵ **فرصيدُ اليوم الموجب
/// يصير متأخراً غداً بلا أن يكتبه أحد**، ⛔ **ولا مجدولةَ في هذا المكدّس
/// تكتبه عند منتصف الليل.** ★ **فالراصدُ يعكس الرصيدَ الموجبَ كما هو،
/// والحدُّ الزمني في الاستعلام والتجميع** ([isAgedRemainder]).
library;

import 'package:qtms_domain/qtms_domain.dart';

import 'audited_transaction.dart';
import 'callable.dart';
import 'identity_gateway.dart';
import 'firestore_value.dart';
import 'inventory.dart' show InventoryWrite;

/// ★ ما يُكتب وما يُمحى من قائمة المتبقي في هذه المعاملة.
final class AgedRemainderSet {
  /// ينشئ المجموعة.
  const AgedRemainderSet({
    this.documents = const <PendingDocument>[],
    this.deletions = const <PendingDeletion>[],
  });

  /// ★ لا شيء — **لمعاملةٍ لا تمسّ رصيداً**.
  static const AgedRemainderSet empty = AgedRemainderSet();

  /// البنودُ القائمة — **مستندٌ لكل (مصدر × نوع × تاريخ مخزون)**.
  final List<PendingDocument> documents;

  /// البنودُ التي زالت — ★ **رصيدُها بلغ صفراً فمُحيت**.
  final List<PendingDeletion> deletions;
}

/// ★★★ يبني قائمةَ المتبقي **من كتابات الرصيد التي أنتجتها المعاملة نفسها**.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⚠️⚠️★★★ **ولماذا من كتابة الرصيد لا من قراءةٍ سابقة ولا من الحمولة:**
/// ★ **كلُّ مُخطِّطٍ يكتب رصيداً يحسبه أصلاً** (`computeItemDailyFlow`) —
/// ⟵ **فالقراءة من كتابته قراءةُ الرقم نفسه**، ⛔ **ولا معادلةَ ثانية**
/// (`coding-standards.md` §2.2) ⛔ **ولا رصيدٌ يُقاس مرتين فيفترق.**
/// ★★ **وهو حرفياً نمطُ `pendingFromBalanceWrites`** — ⛔ **لا آليةٌ موازية
/// تُخترَع لغرضٍ مشابه.**
///
/// ★★ **والثابتُ الذي تحفظه هذه الدالة:** **بندُ متبقٍّ قائمٌ ⟺ رصيدُ
/// (مصدر × نوع × تاريخ مخزون) موجبٌ تماماً** — ⟵ **وكلُّ كتابةِ رصيدٍ تُعيد
/// تقرير الطرفين معاً**: ★ **موجبٌ ⟵ يُكتب البند بقيمته الجديدة**،
/// ★ **صفرٌ أو أقلّ ⟵ يُمحى** (⛔ **ولا يبقى بندٌ يطالب بتصريف عدم**).
///
/// ⚠️ **والمحوُ على مستندٍ غائبٍ عديمُ الأثر** — ⟵ **فلا قراءةَ سابقة له**،
/// ★ **وهو ما تُتيحه حتميّةُ [agedRemainderId]** (نظيرُ `pendingEntryId`).
/// ═══════════════════════════════════════════════════════════════════════
AgedRemainderSet agedRemaindersFromBalanceWrites(
  Iterable<InventoryWrite> writes,
) {
  final List<PendingDocument> documents = <PendingDocument>[];
  final List<PendingDeletion> deletions = <PendingDeletion>[];

  for (final InventoryWrite write in writes) {
    if (write.collectionId != itemDailyBalancesCollection) continue;
    final _RemainderRow? row = _rowOf(write);
    if (row == null) continue;

    final String documentId = agedRemainderId(
      sourceId: row.sourceId,
      itemKey: row.itemKey,
      stockDate: row.stockDate,
    );

    if (row.balance <= 0) {
      deletions.add(
        PendingDeletion(
          collectionId: agedRemaindersCollection,
          documentId: documentId,
        ),
      );
      continue;
    }

    final Map<String, Object?> fields = <String, Object?>{
      // ★★ **`sourceId` حقلٌ صريح** — ⛔ **والمفتاحُ المركّب لا يُفهرَس**:
      //    ⟵ **وشرطُ `storedInScope()` يقرؤه** (`IQ-024` · `DEBT-40`).
      'sourceId': row.sourceId,
      'itemKey': row.itemKey,
      // ★ **الاسمُ كما كُتب في الدفتر** — ★ **نسخةٌ تاريخيةٌ مقصودة**
      //   (`ADR-0007` القاعدة 4)، ⛔ **ولا يُقرأ من كتالوج الأنواع.**
      'itemName': row.itemName,
      // ★★ **تاريخ المخزون** — ⛔ **لا تاريخ الإدخال** (`RISK-07`).
      'stockDate': row.stockDate.asUtcMidnight(),
      'unit': row.unit,
      // ★ **الكميةُ المتبقية بترميز كتابتها نفسِه** — ⟵ **صحيحٌ للحبّة
      //   و[DecimalValue] للوزن**، ⛔ **ولا تحويلَ يفقد الكسر.**
      'remaining': row.remainingValue,
      // ⛔⛔★★★ **ولا حقلَ للعمر** — ★ **العمرُ دالّةٌ في اليوم الحالي
      //    يُحسَب عند القراءة** ([agedRemainderAgeInDays]): ⟵ **وحقلٌ
      //    مخزَّنٌ له يشيخ بلا كاتبٍ يُحدِّثه** ⛔ **فيُلوِّن بندَ خمسةِ
      //    أيامٍ بلون «يوم–يومان»** — ★ **رقمٌ خاطئٌ بصمت.**
    };

    documents.add(
      PendingDocument(
        collectionId: agedRemaindersCollection,
        documentId: documentId,
        fields: fields,
        updateMask: fields.keys.toList(),
        // ★ **ووقتُ الرصد من المنصّة** — `GR-54`: ⛔ **ولا ساعةَ حاوية.**
        serverTimestampFields: const <String>['updatedAt'],
      ),
    );
  }

  return AgedRemainderSet(documents: documents, deletions: deletions);
}

/// ★ صفُّ رصيدٍ مقروءٌ من كتابته — و`null` لكتابةٍ لا تصلح.
final class _RemainderRow {
  const _RemainderRow({
    required this.sourceId,
    required this.itemKey,
    required this.itemName,
    required this.stockDate,
    required this.unit,
    required this.balance,
    required this.remainingValue,
  });

  final String sourceId;
  final String itemKey;
  final String itemName;
  final CalendarDay stockDate;
  final String unit;
  final double balance;
  final Object? remainingValue;
}

/// ★ يقرأ الصفَّ من حقول كتابة الرصيد — ⛔ **ولا يرمي على شكلٍ غير متوقَّع**.
///
/// ⚠️ **والفشلُ هنا يعني «لا بند»** — ⛔ **لا معاملةً تسقط**: ★ **الراصدُ
/// ينبّه ولا يمنع** (راجع ترويسة الملف)، ⟵ **وإسقاطُ توزيعةٍ لأن بندَ
/// تنبيهٍ تعذّر بناؤه هو بعينه ما يمنعه `GR-16`.**
_RemainderRow? _rowOf(InventoryWrite write) {
  final Object? sourceId = write.fields['sourceId'];
  final Object? itemKey = write.fields['itemKey'];
  final Object? itemName = write.fields['itemName'];
  final Object? stockDate = write.fields['stockDate'];
  final Object? unit = write.fields['unit'];
  if (sourceId is! String || sourceId.isEmpty) return null;
  if (itemKey is! String || itemKey.isEmpty) return null;
  if (stockDate is! DateTime) return null;
  final Object? balance = write.fields['balance'];
  return _RemainderRow(
    sourceId: sourceId,
    itemKey: itemKey,
    itemName: itemName is String && itemName.isNotEmpty ? itemName : itemKey,
    stockDate: CalendarDay.fromUtc(stockDate.toUtc()),
    // ⛔ **والوحدةُ من الكتابة لا من سجل نوع** — ★ **فالمفتاحُ المركّب لا
    //   سجلَّ له** (`ADR-0007`)، ⟵ **والمجهولُ حبّةٌ كما في بقية المسارات.**
    unit: unit is String && unit.isNotEmpty ? unit : ItemUnit.piece.name,
    balance: _numberOf(balance),
    remainingValue: balance,
  );
}

/// ★★ الكمية كما كُتبت — **صحيحٌ للحبّة و[DecimalValue] للوزن**.
///
/// ⛔ **ولا تُقرأ عدداً صحيحاً وحده** — ★ **فرصيدٌ وزنيٌّ 0.5 كجم كان سيُقرأ
/// صفراً** ⟵ **فيُمحى بندُه وله كميةٌ فعلاً** (نظيرُ `pending_entries._numberOf`).
double _numberOf(Object? raw) => switch (raw) {
      final DecimalValue value => value.value,
      final num value => value.toDouble(),
      _ => 0,
    };

// ═════════════════════════════════════════════════════════════════════════
// ★★★ بوابةُ التصريف المتأخر — `FR-M8-11` · `UC-004` · `permissions-catalog`
//     §2.3 (`agedRemainderClear`: **المسارُ الوحيد الذي يقبل `stockDate`
//     أقدم من اليوم**).
// ═════════════════════════════════════════════════════════════════════════

/// ★★★ يحكم على تاريخ مخزونٍ مطلوبٍ مقابل يوم المنصّة — و`null` **قبول**.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **ثلاثةُ أحكامٍ لا اثنان — والفرقُ بينها ليس شكلياً:**
///
/// | [stockDate] مقابل [serverDay] | الحكم | المرجع |
/// |---|---|---|
/// | **مساوٍ** | ✅ **قبولٌ بلا مفتاحٍ إضافي** — ★ **توزيعةُ اليوم المعتادة** | `FR-M10-03` |
/// | **أقدم** | ★ **يشترط `agedRemainderClear`** — ⛔ **وبدونه رفض** | `FR-M8-11` · `AA` §5 |
/// | **أحدث (مستقبلي)** | ⛔⛔ **مرفوضٌ مطلقاً للجميع** — ★ **ولا مفتاحَ يفتحه** | `firestore.rules` `notFutureDate` |
///
/// ★★ **والمستقبليُّ يُرفَض قبل فحص المفتاح عمداً** — ⟵ **فلا يُوهِم رمزُ
/// «نقص صلاحية» أن مفتاحاً ما يفتح باباً مغلقاً على الجميع** (`GR-13`).
///
/// ⛔⛔★★★ **و[serverDay] يومُ المنصّة المقروءُ داخل المعاملة** — ⛔ **لا
/// ساعةُ الحاوية ولا قيمةٌ من الجهاز** (`GR-54` · `E-41`): ⟵ **فالحدُّ الذي
/// يفصل «اليوم» عن «المتأخر» هو نفسُه الحدُّ الذي تراه القاعدة.**
///
/// ★★ **ودالةٌ واحدة يشاركها التوزيعُ والبيعُ النقدي** — `coding-standards.md`
/// §2.2: ⟵ **ونسختان منها تفترقان عند أول تعديل**، ⛔ **فيقبل أحدُ المسارين
/// ما يرفضه الآخر** — ★ **وكلاهما يخصم من نفس الدفتر.**
/// ═══════════════════════════════════════════════════════════════════════
CallableError? agedClearanceRejection({
  required AccountRecord actor,
  required CalendarDay stockDate,
  required CalendarDay serverDay,
}) {
  final int comparison = stockDate.compareTo(serverDay);
  if (comparison == 0) return null;
  if (comparison > 0) return CallableError.invalidArgument;
  return actor.claims.has(Permission.agedRemainderClear)
      ? null
      : CallableError.permissionMissing;
}

/// ★ هل هذه العملية **تصريفُ متبقٍّ متأخر**؟ — ★ **`stockDate` أقدمُ من اليوم**.
///
/// ⚠️ **و[serverDay] `null` تعني «غيرُ معلوم»** — ⟵ **فلا حكمَ يُبنى عليه**:
/// ★ **وهو حالُ مسارَي التعديل والإلغاء** حيث اليومُ محفورٌ في رقم المستند
/// ولا يُعاد تقريرُه، ⛔ **ولا يُخمَّن حكمٌ من غياب.**
bool isAgedClearanceOn({
  required CalendarDay stockDate,
  CalendarDay? serverDay,
}) =>
    serverDay != null && stockDate.compareTo(serverDay) < 0;

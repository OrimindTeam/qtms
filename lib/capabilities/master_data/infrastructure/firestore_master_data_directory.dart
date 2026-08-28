/// دليل البيانات المرجعية — **قراءةً فقط** (`ADR-0013` القاعدة 4).
///
/// ⛔★★ **ولا كتابة واحدة هنا:** `sources` · `suppliers` · `dealers` ·
/// `items` · `app_settings` **كلها** `allow create, update: if false` بعد
/// `WU-002` — **والكتابة عبر العمليات المستدعاة**
/// (`functions_master_data_repository.dart`).
///
/// ⚠️ **والرفض يصل كخطأ في التدفّق لا كقائمة فارغة** — ⟵ ★ **فتُميِّز
/// الشاشة بين «لا مصادر» و«ممنوعٌ من الرؤية»**، ⛔ **وخلطُهما يجعل نقصَ
/// النطاق يبدو نظاماً فارغاً** فيبحث المستخدم عن عطلٍ لا وجود له.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qtms_domain/qtms_domain.dart';

/// الدليل الحقيقي.
final class FirestoreMasterDataDirectory implements MasterDataDirectory {
  /// ينشئ الدليل.
  const FirestoreMasterDataDirectory(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Stream<List<SourceCard>> watchSources() => _watch(
        sourcesCollection,
        (String id, Map<String, dynamic> d) => SourceCard(
          sourceId: id,
          name: _text(d['name']) ?? id,
          requiresSupplierOnIntake: d['requiresSupplierOnIntake'] == true,
          isActive: d['isActive'] != false,
          notes: _text(d['notes']),
          disableReason: _text(d['disableReason']),
        ),
      );

  @override
  Stream<List<SupplierCard>> watchSuppliers() => _watch(
        suppliersCollection,
        (String id, Map<String, dynamic> d) => SupplierCard(
          supplierId: id,
          sourceIds: _texts(d['sourceIds']),
          name: _text(d['name']) ?? id,
          phone: _text(d['phone']) ?? '',
          isActive: d['isActive'] != false,
          notes: _text(d['notes']),
          disableReason: _text(d['disableReason']),
        ),
      );

  @override
  Stream<List<DealerCard>> watchDealers() => _watch(
        dealersCollection,
        (String id, Map<String, dynamic> d) => DealerCard(
          dealerId: id,
          name: _text(d['name']) ?? id,
          phone: _text(d['phone']) ?? '',
          isActive: d['isActive'] != false,
          notes: _text(d['notes']),
          disableReason: _text(d['disableReason']),
        ),
      );

  @override
  Stream<List<ItemCard>> watchItems() => _watch(
        itemsCollection,
        (String id, Map<String, dynamic> d) => ItemCard(
          itemId: id,
          sourceIds: _texts(d['sourceIds']),
          name: _text(d['name']) ?? id,
          // ⛔ **قيمةٌ مجهولة لا تُسقِط الشاشة** — تُقرأ بالافتراض الأشيع
          //    ⟵ **فمستندٌ قديمٌ واحد لا يُخفي القائمة كلها.**
          nature: _natureOf(d['nature']),
          unit: _unitOf(d['unit']),
          pieceWeightGrams: _number(d['pieceWeightGrams']),
          isActive: d['isActive'] != false,
          isSystemDefault: d['isSystemDefault'] == true,
          disableReason: _text(d['disableReason']),
        ),
      );

  /// ★ الإعداد التأسيسي — **المستندان يُقرآن معاً**، و`null` تعني «لم يُكتب».
  ///
  /// ⚠️ **والمستندُ الواحد لا يكفي:** الكتابة ذرّية، ⟵ **فوجودُ أحدهما بلا
  /// الآخر شذوذٌ يُقرأ «غير مكتوب»** فتُعاد المحاولة، ⛔ **ولا يُبنى عليه
  /// عرضٌ ناقص.**
  @override
  Stream<AppSettingsCard?> watchAppSettings() => _firestore
      .collection(appSettingsCollection)
      .snapshots()
      .map((QuerySnapshot<Map<String, dynamic>> snapshot) {
        Map<String, dynamic>? business;
        Map<String, dynamic>? formatting;
        for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
            in snapshot.docs) {
          if (doc.id == appSettingsBusinessDocId) business = doc.data();
          if (doc.id == appSettingsFormattingDocId) formatting = doc.data();
        }
        if (business == null || formatting == null) return null;
        return AppSettingsCard(
          businessName: _text(business['businessName']) ?? '',
          logo: _text(business['logo']),
          phone: _text(business['phone']),
          address: _text(business['address']),
          currencySymbol: _text(formatting['currencySymbol']) ?? '',
          // ★ **صفر حتماً** — `ADR-0015`؛ والقيمة المخزَّنة تُقرأ للتشخيص لا
          //   للاعتماد، ⛔ **ولا يُبنى تنسيقٌ على غير الصفر.**
          decimalPlaces: 0,
          thousandsSeparator: _text(formatting['thousandsSeparator']) ?? '',
        );
      });

  Stream<List<T>> _watch<T>(
    String collection,
    T Function(String id, Map<String, dynamic> data) map,
  ) =>
      _firestore
          .collection(collection)
          // ★ **الترتيب من الخادم لا في الذاكرة** — فالصفحة الأولى صحيحة
          //   قبل وصول البقية، ⛔ ولا تقفز الأسماء أمام المستخدم وهي تُحمَّل.
          .orderBy('name')
          .snapshots()
          .map((QuerySnapshot<Map<String, dynamic>> snapshot) => snapshot.docs
              .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                  map(doc.id, doc.data()))
              .toList());

  static String? _text(Object? raw) {
    if (raw is! String) return null;
    final String trimmed = raw.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static List<String> _texts(Object? raw) => raw is List<dynamic>
      ? <String>[
          for (final Object? item in raw)
            if (item is String && item.trim().isNotEmpty) item.trim(),
        ]
      : const <String>[];

  static double? _number(Object? raw) => switch (raw) {
        final int value => value.toDouble(),
        final double value => value,
        _ => null,
      };

  static ItemNature _natureOf(Object? raw) {
    for (final ItemNature nature in ItemNature.values) {
      if (nature.name == raw) return nature;
    }
    return ItemNature.countBased;
  }

  static ItemUnit _unitOf(Object? raw) {
    for (final ItemUnit unit in ItemUnit.values) {
      if (unit.name == raw) return unit;
    }
    return ItemUnit.piece;
  }
}

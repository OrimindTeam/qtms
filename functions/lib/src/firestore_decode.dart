/// فكّ قيم Firestore **من نموذج `googleapis` المُصنَّف** — ⛔ لا من JSON خام.
///
/// ⚠️⚠️⚠️ **وُلد هذا الملف من عطلٍ حقيقي رُصد بالنشر (2026-08-25)، ولم يكشفه
/// اختبارٌ واحد:** كل عملية سحابية كانت تقرأ **صفر صلاحيات** من بطاقة تحمل
/// تسعاً — ⟵ **فرُفض كل استدعاء إداري بـ`ERR_AUTH_001`** والبطاقة سليمة.
///
/// ★★★ **والسبب أن `Value.toJson()` في `googleapis` سطحيٌّ لا متعدٍّ:**
///
/// ```text
/// Value.fromJson({'mapValue': {'fields': {...}}}).toJson()
///   ⟵ {'mapValue': Instance of 'MapValue'}   ⛔ لا خريطة JSON عادية
/// ```
///
/// ⟵ **فأي فحص `is Map` على القيمة المتداخلة يسقط**، ★ **ويعود `null`
/// صامتاً** — ⛔ **بلا استثناء ولا سجل ولا أي أثر يدلّ على السبب.**
///
/// ★ **ولذلك يقرأ هذا الملف الحقول المُصنَّفة مباشرةً** (`value.mapValue`
/// · `value.arrayValue` …) ⛔ **ولا يمرّ بـ`toJson()` إطلاقاً** — ⟵ **فالمترجم
/// نفسه يحرس البنية**، ولا يعتمد الفكّ على شكلٍ نصّي قد يتغيّر بترقية مكتبة.
///
/// ⚠️ **و`firestore_value.dart` يبقى لِما يصل JSON خاماً فعلاً** (حمولات
/// الأحداث) — ⛔ **ولا يُستعمَل لقراءة المستندات بعد اليوم.**
library;

import 'package:googleapis/firestore/v1.dart' as firestore;

/// يفكّ حقول مستند إلى خريطة Dart عادية.
Map<String, Object?> decodeDocumentFields(
  Map<String, firestore.Value>? fields,
) {
  if (fields == null) return <String, Object?>{};
  return <String, Object?>{
    for (final MapEntry<String, firestore.Value> entry in fields.entries)
      entry.key: decodeTypedValue(entry.value),
  };
}

/// يفكّ قيمة واحدة — ★ **بالترتيب نفسه الذي يعتمده `firestore_value.dart`**.
///
/// ⛔ **ولا نمط شامل يبتلع نوعاً جديداً** — ما لا يُعرَف يعود `null` صراحةً،
/// ★ **وهو الرفض الافتراضي**: قيمةٌ لا نفهمها **لا تُؤوَّل تخميناً**.
Object? decodeTypedValue(firestore.Value value) {
  if (value.nullValue != null) return null;
  if (value.stringValue case final String text) return text;
  if (value.booleanValue case final bool flag) return flag;
  // ⚠️ العدد الصحيح يصل **نصّاً** في هذه الواجهة — راجع `firestore_value.dart`.
  if (value.integerValue case final String number) return int.parse(number);
  if (value.doubleValue case final double number) return number;
  if (value.timestampValue case final String stamp) {
    return DateTime.parse(stamp).toUtc();
  }
  if (value.referenceValue case final String reference) return reference;
  if (value.arrayValue case final firestore.ArrayValue array) {
    return <Object?>[
      for (final firestore.Value element in array.values ?? const [])
        decodeTypedValue(element),
    ];
  }
  if (value.mapValue case final firestore.MapValue map) {
    return decodeDocumentFields(map.fields);
  }
  return null;
}

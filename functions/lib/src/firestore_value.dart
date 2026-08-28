/// ترميز وفكّ ترميز قيم قاعدة البيانات بصيغة واجهة REST الرسمية.
///
/// ★ **لماذا يدوياً:** لا يوجد **SDK إداري رسمي بلغة Dart** لقاعدة البيانات،
/// والمسار المعتمد في `ADR-0009` ② هو `functions_framework` على Cloud Run —
/// فالوصول عبر واجهة REST (`googleapis`). وتلك الواجهة تُغلّف كل قيمة بنوعها
/// (`{"stringValue": "..."}`)، فيلزم محوّل صريح في الاتجاهين.
///
/// ⚠️ **مزلق حقيقي كلّف غيرنا:** الأعداد الصحيحة تصل **نصّاً** لا رقماً
/// (`{"integerValue": "42"}`) لأن الواجهة تحمل `int64` والذي لا يتّسع له
/// رقم JSON. فقراءتها كرقم مباشرةً **تُنتج `null` صامتاً** — لا خطأ.
///
/// ⚠️ **ولا يُمرَّر مبلغ عبر `doubleValue` إطلاقاً** — `ADR-0015`
/// و`coding-standards.md` §2.1: **كل مبلغ عدد صحيح بالريال (`int` 64 بتّة)**،
/// فيمرّ من هنا كـ`integerValue` لا غير.
/// ⛔ **ولا تخزين بأصغر وحدة (فِلس)** — الرقم المخزون هو المعروض حرفياً.
///
/// ★★ **والأوزان تمرّ بـ[DecimalValue] وحدها** (`WU-004`) — `ADR-0015`
/// القاعدة 9: **«الأوزان ليست مبالغ»**. ⛔ **و`double` المجرَّد يبقى
/// مرفوضاً** — ★ **فالتصريح شرطُ المرور لا صيغةٌ اختيارية.**
library;

/// ★★★ **قيمةٌ عشرية مُصرَّحٌ بها صراحةً** — ⛔ **والوحيدة التي تُكتب كذلك**.
///
/// ⚠️⚠️ **ولماذا غلافٌ لا قبولُ `double` مباشرةً — وهو جوهر هذا النوع:**
/// المُرمِّز **لا يعرف أمبلغٌ هو أم وزن**، ⟵ **فيرفض الاثنين ويُلزم
/// المُستدعي بالتصريح** (راجع ترويسة الملف). ★ **والتصريح هنا هو الغلاف
/// نفسه:** من يكتب [DecimalValue] **يقول صراحةً «هذه ليست مبلغاً»**،
/// ⛔ **ومبلغٌ مرّ من هنا مخالفةٌ ظاهرة في المراجعة لا انزلاقٌ صامت.**
///
/// ★★ **وأول كاتبٍ لها الجونية في `WU-004`** — `ADR-0015` القاعدة 9:
/// «**الأوزان ليست مبالغ … تبقى عشرية كما هي**» (`design-overview.md` §2.11)
/// — ⟵ **والوزن بثلاث خانات ووزن الحبة بخانتين.**
///
/// ⛔★★ **ورفضُ `double` المجرَّد يبقى كما هو بعد هذا النوع** — ★ **وهو
/// المقصود:** لو قُبِل المجرَّد لَما بقي للتصريح معنى، ⟵ **ولَعاد المُرمِّز
/// يكتب المبالغ عشريةً بلا أن يعترض أحد** (`ADR-0015` القاعدة 1).
final class DecimalValue {
  /// ينشئ القيمة — ⛔ **ويرفض غير العددي رفضاً صريحاً**.
  ///
  /// ★ **والرفض عند البناء لا عند الترميز** — ⟵ **فالقيمة الشاذّة تُوقَف
  /// عند مصدرها**، ⛔ **لا بعد أن تعبر طبقاتٍ تفترض صحتها.**
  DecimalValue(this.value) {
    if (!value.isFinite) {
      throw ArgumentError.value(value, 'value', 'قيمة عشرية غير عددية');
    }
  }

  /// القيمة كما تُكتب — ⛔ **بلا تقريب** (`ADR-0015` القاعدة 4).
  final double value;

  @override
  bool operator ==(Object other) =>
      other is DecimalValue && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'DecimalValue($value)';
}

/// يفكّ قيمة واحدة مغلَّفة بنوعها إلى قيمة Dart عادية.
///
/// يُرجِع `null` للقيمة الفارغة وللأنواع غير المدعومة معاً — والتمييز بينهما
/// لا يلزم هنا لأن المستدعي يقرأ حقولاً معلومة النوع من قاموس البيانات.
/// ⚠️⚠️⚠️ **قاعدة مُلزِمة في هذا الملف — رُصدت بعطلٍ حقيقي (2026-08-25):**
/// **كل فحص نوعٍ على خريطة أو قائمة متداخلة يكون `is Map` و`is List`
/// مجرَّدين** — ⛔ **لا `is Map<String, Object?>` ولا `is List<Object?>`.**
///
/// ★★ **والسبب أن `googleapis` تُنتج أنواعاً أضيق مما نتوقّع:**
/// `Value.toJson()` يُعيد الخرائط المتداخلة بأنواع مثل
/// `Map<String, Map<String, dynamic>>`، ⟵ **فيفشل الفحص الأضيق على الطبقة
/// الداخلية ويعود `null` صامتاً.**
///
/// ⛔★★★ **وأثرُه كان كارثياً وصامتاً:** بطاقة المالك تحمل **تسع صلاحيات**،
/// **وكل عملية سحابية تقرؤها صفراً** ⟵ **فتُرفَض كل عملية إدارية بـ
/// `ERR_AUTH_001`** — ★ **بلا استثناء ولا سجل ولا أي أثر يدلّ على السبب.**
/// ⚠️ **ولم يكشفه اختبارٌ واحد** لأن الاختبارات كانت تبني خرائط يدوية
/// بالنوع الواسع — ★ **وكشفه أول استدعاء حقيقي على Cloud Run.**
Object? decodeFirestoreValue(Map<String, Object?> wrapped) {
  if (wrapped.containsKey('nullValue')) return null;

  final Object? stringValue = wrapped['stringValue'];
  if (stringValue is String) return stringValue;

  final Object? booleanValue = wrapped['booleanValue'];
  if (booleanValue is bool) return booleanValue;

  // ⚠️ يصل نصّاً — راجع ترويسة الملف.
  final Object? integerValue = wrapped['integerValue'];
  if (integerValue is String) return int.parse(integerValue);
  if (integerValue is int) return integerValue;

  final Object? doubleValue = wrapped['doubleValue'];
  if (doubleValue is num) return doubleValue.toDouble();

  final Object? timestampValue = wrapped['timestampValue'];
  if (timestampValue is String) return DateTime.parse(timestampValue).toUtc();

  final Object? referenceValue = wrapped['referenceValue'];
  if (referenceValue is String) return referenceValue;

  // ⛔★★★ **`is Map` لا `is Map<String, Object?>`** — راجع ترويسة الملف.
  final Object? arrayValue = wrapped['arrayValue'];
  if (arrayValue is Map) {
    final Object? values = arrayValue['values'];
    if (values is! List) return <Object?>[];
    return <Object?>[
      for (final Object? element in values)
        if (element is Map) decodeFirestoreValue(_asWrapped(element)),
    ];
  }

  final Object? mapValue = wrapped['mapValue'];
  if (mapValue is Map) {
    return decodeFirestoreFields(mapValue['fields']);
  }

  return null;
}

/// يوحّد خريطةً أياً كانت وسائطها النوعية إلى `Map<String, Object?>`.
///
/// ★ **ولا يُسقِط مفتاحاً غير نصّي بصمت** — لا وجود له في JSON أصلاً،
/// ⟵ **ووجودُه يعني أن المُدخَل ليس استجابةَ Firestore**، فالإسقاط أسلم.
Map<String, Object?> _asWrapped(Map<Object?, Object?> raw) =>
    <String, Object?>{
      for (final MapEntry<Object?, Object?> entry in raw.entries)
        if (entry.key case final String key) key: entry.value,
    };

/// يفكّ خريطة حقول مستند كاملة (`fields`) إلى خريطة Dart عادية.
Map<String, Object?> decodeFirestoreFields(Object? fields) {
  // ⛔★★★ **`is! Map` لا `is! Map<String, Object?>`** — راجع ترويسة الملف.
  if (fields is! Map) return <String, Object?>{};
  final Map<String, Object?> decoded = <String, Object?>{};
  for (final MapEntry<Object?, Object?> entry in fields.entries) {
    final Object? key = entry.key;
    final Object? wrapped = entry.value;
    if (key is String && wrapped is Map) {
      decoded[key] = decodeFirestoreValue(_asWrapped(wrapped));
    }
  }
  return decoded;
}

/// يغلّف قيمة Dart بنوعها كما تتوقّعها واجهة REST.
///
/// يرمي [ArgumentError] عند نوع غير مدعوم بدل تحويله صامتاً — لأن كتابة حقل
/// بنوع خاطئ في دفتر مالي **عطب لا يُكتشَف إلا متأخراً**.
Map<String, Object?> encodeFirestoreValue(Object? value) {
  if (value == null) return <String, Object?>{'nullValue': null};
  if (value is String) return <String, Object?>{'stringValue': value};
  if (value is bool) return <String, Object?>{'booleanValue': value};
  // ⚠️ يُرسَل نصّاً — وإرساله رقماً يجعله `doubleValue` عند الخادم.
  if (value is int) {
    return <String, Object?>{'integerValue': value.toString()};
  }
  if (value is DateTime) {
    return <String, Object?>{
      'timestampValue': value.toUtc().toIso8601String(),
    };
  }
  if (value is List<Object?>) {
    return <String, Object?>{
      'arrayValue': <String, Object?>{
        'values': value.map(encodeFirestoreValue).toList(),
      },
    };
  }
  if (value is Map<String, Object?>) {
    return <String, Object?>{
      'mapValue': <String, Object?>{'fields': encodeFirestoreFields(value)},
    };
  }
  // ★★★ **العشريُّ المُصرَّح به وحده يمرّ** — راجع [DecimalValue].
  //    ⚠️ **وقبل رفض `double` المجرَّد أدناه عمداً**: الترتيب هو ما يجعل
  //    التصريح مساراً حقيقياً، ⛔ لا استثناءً يُلتفّ به على القاعدة.
  if (value is DecimalValue) {
    return <String, Object?>{'doubleValue': value.value};
  }
  if (value is double) {
    // ★ رفض مقصود لا نقص في التغطية — `ADR-0015` و`coding-standards.md`
    //   §2.1 و§5 البند 1: **كل مبلغ عدد صحيح بالريال**. ولأن المُرمِّز لا
    //   يعرف أمبلغٌ هذا أم وزن، **يرفض الاثنين** ويُلزم المُستدعي بالتصريح:
    //   المبالغ `int` بالريال، والأوزان بقرار موثَّق عند أول دفتر يكتبها.
    throw ArgumentError.value(
      value,
      'value',
      'الفاصلة العائمة مرفوضة — المبلغ عدد صحيح بالريال (ADR-0015)',
    );
  }
  throw ArgumentError.value(
    value,
    'value',
    'نوع غير مدعوم في ترميز قاعدة البيانات — ولا يُحوَّل صامتاً',
  );
}

/// يغلّف خريطة Dart كاملة إلى `fields` بصيغة الواجهة.
Map<String, Object?> encodeFirestoreFields(Map<String, Object?> data) {
  return data.map(
    (String key, Object? value) =>
        MapEntry<String, Object?>(key, encodeFirestoreValue(value)),
  );
}

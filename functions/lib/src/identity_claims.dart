/// المطالبات المخصّصة في رمز الدخول — **ترميزها وفكّها**.
///
/// ★★ **الصيغة بعد `ADR-0016` (2026-08-24)** — والصلاحيات **ليست فيها**:
///
/// ```json
/// { "role": "<معرّف الدور>",
///   "sourceScope": "all" | ["<sourceId>", "..."] }
/// ```
///
/// ⛔ **و`permissions` خرجت إلى `users/{userId}`** لأن حمولتها **1707 بايت
/// والحدّ 1000**، فكان مستخدمٌ واسع الصلاحية **يستحيل إصدار رمزه** (`IQ-008`).
///
/// ⛔ **ولا يجوز تغيير هذه الصيغة من هنا:** `firestore.rules` تقرأ
/// `claims().get('sourceScope', [])` حرفياً، **وتقرأ الصلاحيات من البطاقة**
/// بـ`get()` واحدة. فالترميز هنا **تابع للقواعد لا حاكم عليها**.
///
/// ★ **والغياب يعني `false`** — الرفض الافتراضي (`permissions-catalog.md` §1
/// القاعدة 4).
library;

import 'dart:convert';

import 'package:qtms_domain/qtms_domain.dart';

/// ⚠️ **حدّ المنصة المعلَن لحمولة المطالبات المخصّصة — بالبايت.**
///
/// ★ **ليس اختياراً منّا بل قيد خارجي**: خدمة المصادقة ترفض أي حمولة تتجاوزه.
/// ⛔ **ولا يُرفَع بتعديل هذا الثابت** — الثابت يعكس القيد ولا يصنعه.
///
/// ✅ **وقد زال سببُ تجاوزه بـ`ADR-0016`:** كانت حمولة الـ72 مفتاحاً **1707
/// بايت** فيستحيل إصدار الرمز؛ **وبإخراج الصلاحيات صارت الحمولة عشرات
/// البايتات** مهما كبر الكتالوج.
///
/// ⚠️ **ويبقى الفحص قائماً عمداً** — حارساً لما قد يكبر لاحقاً (نطاق مصادر
/// طويل مثلاً). ⛔ **والرمي عند التجاوز أفضل من اقتطاع صامت.**
const int maxCustomClaimsBytes = 1000;

/// مفاتيح المطالبات الثلاثة — تُكتب مرة واحدة فلا تنزلق نسخة عن أخرى.
const String roleClaimKey = 'role';

/// مفتاح خريطة الصلاحيات في الرمز.
const String permissionsClaimKey = 'permissions';

// ⚠️ ★ **`sourceScopeClaimKey` و`allSourcesClaimValue` لم يعودا مُعرَّفين هنا**
//    (2026-08-24 · `WU-001`): صارا في طبقة النطاق المشتركة
//    (`source_scope_claim.dart`) ⟵ **فيقرؤهما التطبيق والسحابة من موضع واحد**.
//    ★ **وتعريفهما مرتين كان ينتظر أن يفترقا**، وهو ما يمنعه `P-10` نصّاً.
//    ✅ **ويصلان من `package:qtms_domain/qtms_domain.dart` المستورد أعلاه.**

/// مطالبات مستخدم واحد كما تُقرأ من الرمز أو تُكتب إليه.
final class IdentityClaims {
  /// ينشئ مطالبات بصلاحيات ونطاق.
  IdentityClaims({
    required Set<Permission> permissions,
    required this.sourceScope,
    this.roleId,
  }) : permissions = Set<Permission>.unmodifiable(permissions);

  /// مطالبات حساب **بلا صلاحيات إطلاقاً** — حال حساب المالك الأول قبل الإقلاع.
  ///
  /// ★ **ونطاقه قائمة فارغة لا `all`** — لأن الافتراض الآمن هو المنع
  /// (`permissions-catalog.md` §1 القاعدة 4). ⛔ **ولا يُبنى بـ[ScopedSources]**
  /// لأنه يرفض القائمة الفارغة عمداً؛ وهذا **غياب نطاق** لا نطاق فارغ.
  static const IdentityClaims none = IdentityClaims._empty();

  const IdentityClaims._empty()
      : permissions = const <Permission>{},
        sourceScope = null,
        roleId = null;

  /// الصلاحيات الممنوحة فعلاً — **والغائب مرفوض**.
  final Set<Permission> permissions;

  /// نطاق المصادر، أو `null` إن لم يُمنَح بعد.
  final SourceScope? sourceScope;

  /// معرّف الدور — **قالب بداية لا مصدر تفويض** (`data-dictionary.md` §1).
  final String? roleId;

  /// هل يملك [permission] فعلاً؟
  bool has(Permission permission) => permissions.contains(permission);

  /// هل يقع [sourceId] داخل نطاقه؟ — ⛔ والغياب منع لا سماح.
  bool canAccessSource(String sourceId) =>
      sourceScope?.canAccessSource(sourceId) ?? false;

  /// يفكّ المطالبات من نصّ `customAttributes` كما تُرجِعه خدمة المصادقة.
  ///
  /// ★ **متساهل في القراءة صارم في الكتابة:** أي مفتاح لا يعرفه الكتالوج
  /// **يُتجاهَل** بدل أن يُفشِل فكّ الرمز كله — لأن رمزاً قديماً بمفتاح ملغى
  /// كان سيقفل الحساب نهائياً. ⛔ **وليس ابتلاعاً صامتاً**: المفاتيح المجهولة
  /// تُرجَع في `ClaimsDecoding.legacyKeys` ليُبلَّغ عنها المُستدعي.
  static ClaimsDecoding decode(String? customAttributes) {
    if (customAttributes == null || customAttributes.trim().isEmpty) {
      return const ClaimsDecoding(IdentityClaims.none, <String>{});
    }
    final Object? parsed = jsonDecode(customAttributes);
    if (parsed is! Map<String, Object?>) {
      throw const FormatException('المطالبات المخصّصة ليست كائن JSON');
    }

    // ★★ ADR-0016: **أي صلاحية في الرمز تُتجاهَل تماماً** — ⛔ ولا تُقرأ.
    //   ⚠️ **والتجاهل هنا قرار أمني لا تنظيف:** رموزٌ أُصدرت قبل الترحيل ما
    //   تزال تحمل الخريطة القديمة، **وقراءتها كانت ستفتح بالضبط المسار الذي
    //   أغلقته القاعدة** — فيصير الرمز مصدرَ تفويضٍ موازياً لبطاقة المستخدم.
    //   ★ ومصدر الصلاحية الآن `users/{userId}` وحده.
    //   ⛔ وليس ابتلاعاً صامتاً: المفتاح يُبلَّغ في [ClaimsDecoding.legacyKeys].
    final Set<String> legacy = <String>{};
    final Object? rawPermissions = parsed[permissionsClaimKey];
    if (rawPermissions is Map<String, Object?>) {
      legacy.addAll(rawPermissions.keys);
    }

    return ClaimsDecoding(
      IdentityClaims(
        // ⛔ فارغة دائماً — تُملأ من البطاقة في `IdentityGateway`.
        permissions: const <Permission>{},
        sourceScope: _decodeScope(parsed[sourceScopeClaimKey]),
        roleId: parsed[roleClaimKey] as String?,
      ),
      legacy,
    );
  }

  /// يبني نصّ `customAttributes` — ⛔ **ويرمي إن تجاوز حدّ المنصة**.
  ///
  /// ★ **الرمي مقصود ولا بديل عنه:** الاقتطاع الصامت كان سيُنتج مستخدماً
  /// يظنّ أن له صلاحية **بينما رمزه لا يحملها**، وهو أسوأ من الفشل الظاهر
  /// (`coding-standards.md` §2.5).
  String encode() {
    // ★★ ADR-0016: **الصلاحيات لا تُكتب في الرمز إطلاقاً** — بل في
    //    `users/{userId}.permissions`، وتقرأها القاعدة بـ`get()` واحدة.
    //    ⛔ وكتابتها هنا كانت **هي المشكلة نفسها**: 72 مفتاحاً = 1707 بايت
    //    والحدّ 1000، فيستحيل إصدار رمز مستخدمٍ واسع الصلاحية (`IQ-008`).
    //    ⟵ وبإخراجها صارت الحمولة عشرات البايتات مهما كبر الكتالوج.
    final Map<String, Object?> payload = <String, Object?>{
      if (roleId != null) roleClaimKey: roleId,
      if (sourceScope != null) sourceScopeClaimKey: _encodeScope(sourceScope!),
    };
    final String encoded = jsonEncode(payload);
    final int size = utf8.encode(encoded).length;
    if (size > maxCustomClaimsBytes) {
      throw ClaimsTooLargeException(
        byteSize: size,
        permissionCount: permissions.length,
      );
    }
    return encoded;
  }

  static SourceScope? _decodeScope(Object? raw) {
    if (raw == allSourcesClaimValue) return const AllSources();
    if (raw is List<Object?>) {
      final Set<String> ids = raw.whereType<String>().toSet();
      // ★ القائمة الفارغة **غياب نطاق لا نطاق فارغ** — و`ScopedSources`
      //   يرفضها عمداً، فلا تُبنى بها.
      return ids.isEmpty ? null : ScopedSources(ids);
    }
    return null;
  }

  static Object _encodeScope(SourceScope scope) => switch (scope) {
        AllSources() => allSourcesClaimValue,
        ScopedSources(:final Set<String> sourceIds) => sourceIds.toList()..sort(),
      };
}

/// نتيجة فكّ المطالبات — القيم **وما تُجوهِل منها**.
final class ClaimsDecoding {
  /// ينشئ نتيجة فكّ.
  const ClaimsDecoding(this.claims, this.legacyKeys);

  /// المطالبات المفهومة — ⛔ **وصلاحياتها فارغة دائماً بعد `ADR-0016`**.
  final IdentityClaims claims;

  /// ★ مفاتيح صلاحيات وُجدت **في الرمز** — من رمزٍ أُصدر قبل الترحيل.
  ///
  /// ⛔ **تُتجاهَل ولا تُمنَح**، ✅ **وتُبلَّغ ولا تُبتلَع** — فظهورها إشارة
  /// إلى رمز قديم يحتاج تحديثاً، لا إلى صلاحية قائمة.
  final Set<String> legacyKeys;
}

/// حمولة المطالبات تجاوزت حدّ المنصة — ⛔ **ولا تُقتطَع صامتةً**.
final class ClaimsTooLargeException implements Exception {
  /// ينشئ الاستثناء بحجمه وعدد صلاحياته.
  const ClaimsTooLargeException({
    required this.byteSize,
    required this.permissionCount,
  });

  /// الحجم الفعلي بالبايت.
  final int byteSize;

  /// عدد الصلاحيات التي أنتجته.
  final int permissionCount;

  @override
  String toString() =>
      'ClaimsTooLargeException: $byteSize بايت لـ$permissionCount صلاحية '
      '— الحدّ $maxCustomClaimsBytes (IQ-008)';
}

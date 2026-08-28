/// نطاق المصادر — **قيد يعلو على كل صلاحية، لا صلاحية بذاته**.
///
/// ★ **نقل حرفي لـ`permissions-catalog.md` §4:** «امتلاك `distributionCreate`
/// **لا يكفي** إن كان `sourceId` في المستند خارج النطاق — والرفض من القاعدة
/// لا من الواجهة» (`GR-23`).
///
/// و`FR-M1-07`: «**نطاق المصادر يُطبَّق على كل الصلاحيات بلا استثناء**» —
/// بما فيها التقارير وبطاقات ضمار المالك والسحبيات وسجل التدقيق.
library;

/// نطاق المصادر المسموح لمستخدم.
sealed class SourceScope {
  const SourceScope();

  /// هل يقع [sourceId] داخل هذا النطاق؟
  bool canAccessSource(String sourceId);
}

/// كل المصادر — ★ **وأي مصدر يُضاف مستقبلاً تلقائياً** (§4).
final class AllSources extends SourceScope {
  const AllSources();

  @override
  bool canAccessSource(String sourceId) => true;

  @override
  bool operator ==(Object other) => other is AllSources;

  @override
  int get hashCode => (AllSources).hashCode;

  @override
  String toString() => 'all';
}

/// قائمة مصادر محدَّدة.
///
/// ⚠️ **والمصدر الجديد لا يُضاف إليها** — يحتاج منحاً صريحاً (§4 · `§9.4`).
/// ★ **وهذا فرق أمني جوهري عن [AllSources]، لا تفصيل تنفيذ**: مستخدم بقائمة
/// محددة **لا يرى مصدراً أُنشئ بعد منحه** حتى يُمنَح إياه صراحةً.
final class ScopedSources extends SourceScope {
  /// ينشئ نطاقاً بقائمة محدَّدة.
  ///
  /// يرمي [ArgumentError] على القائمة الفارغة — لأن نطاقاً بلا مصدر واحد
  /// **يعني منع كل شيء**، وهو تعطيل مقنَّع لا نطاق. والتعطيل له مساره
  /// الخاص (`isActive` · `FR-M1-12`)، ⛔ **ولا يُعبَّر عنه بنطاق فارغ صامت**.
  factory ScopedSources(Set<String> sourceIds) {
    if (sourceIds.isEmpty) {
      throw ArgumentError.value(
        sourceIds,
        'sourceIds',
        'النطاق الفارغ يمنع كل شيء — والتعطيل مساره `isActive` لا نطاق فارغ',
      );
    }
    return ScopedSources._(Set<String>.unmodifiable(sourceIds));
  }

  const ScopedSources._(this.sourceIds);

  /// المصادر المسموح بها — **غير قابلة للتعديل بعد الإنشاء**.
  final Set<String> sourceIds;

  @override
  bool canAccessSource(String sourceId) => sourceIds.contains(sourceId);

  @override
  bool operator ==(Object other) =>
      other is ScopedSources &&
      other.sourceIds.length == sourceIds.length &&
      other.sourceIds.containsAll(sourceIds);

  @override
  int get hashCode => Object.hashAllUnordered(sourceIds);

  @override
  String toString() => (sourceIds.toList()..sort()).join(', ');
}

/// هل [narrower] **لا يتجاوز** [wider]؟
///
/// ★ **أساس `FR-M1-08`:** «لا يمكن لمستخدم … **توسيع نطاق مصادره بنفسه**».
/// فيُستخدَم للتحقق أن النطاق المطلوب منحه لا يتعدّى نطاق المُنفِّذ نفسه.
bool scopeIsWithin(SourceScope narrower, SourceScope wider) => switch (wider) {
      AllSources() => true,
      ScopedSources(:final Set<String> sourceIds) => switch (narrower) {
          // ⛔ `all` لا يقع داخل قائمة محدودة مهما طالت — لأنه يشمل **ما
          //    سيُضاف مستقبلاً** أيضاً، وهو ما لا تشمله القائمة أبداً (§4).
          AllSources() => false,
          ScopedSources(sourceIds: final Set<String> inner) =>
            sourceIds.containsAll(inner),
        },
    };

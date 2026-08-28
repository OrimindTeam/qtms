/// بوابة الكتابة — ★ **`FR-SYS-14`: «عند عودة الاتصال يُعيد التطبيق قراءة
/// الأرصدة قبل السماح بأي عملية»**.
///
/// ★ **ولماذا آلة حالة نقية لا فحص اتصال مباشر:** القاعدة نفسها **قرار
/// أعمال** ⟵ **فتُختبَر بلا شبكة ولا جهاز** (`ADR-0009`). ⛔ **والشاشة لا
/// تُقرِّر متى يُسمح بالحفظ** — تسأل البوابة (`ADR-0010` القاعدة 1).
///
/// ⚠️ **وحدّ هذا الإصدار معلَن:** ⛔ **لا مصدر اتصال موصولاً بها بعد ولا
/// أرصدة تُقرأ** — ★ **فالأرصدة تظهر أولَ مرة في `WU-003`**، وعندها يُوصَل
/// [WriteGate.onConnectionRestored] بمصدر الاتصال و[WriteGate.onDataRefreshed]
/// بإعادة القراءة. ⟵ **والقاعدة مكتوبة ومُختبَرة من الآن** ⛔ **ولا تُدَّعى
/// موصولة.**
library;

/// حالة البوابة.
enum WriteGateStatus {
  /// الكتابة مسموحة.
  open,

  /// لا اتصال — ★ **والحفظ معطَّل فعلياً لا تحذيراً** (`ui-guidelines.md` §2 ·
  /// `ADR-0003`: التخزين المحلي مُعطَّل، فالكتابة بلا اتصال **وهمُ نجاح**).
  blockedOffline,

  /// ★ **عاد الاتصال ولم تُعَد قراءة الأرصدة بعد** — `FR-SYS-14`.
  ///
  /// ⚠️ **وهذه أخطر الحالات الثلاث لأنها تبدو سليمة:** الشبكة تعمل، والشاشة
  /// تعرض **أرقاماً قديمة** من قبل الانقطاع. ⟵ ⛔ **والكتابة عليها تبني
  /// قراراً مالياً على رصيد بائت.**
  blockedAwaitingRefresh,
}

/// بوابة الكتابة — قيمة ثابتة، وكل انتقال يُنتج قيمة جديدة.
extension type const WriteGate(WriteGateStatus status) implements Object {
  /// البداية: مسموح — والتطبيق لا يُقلع إلا بمنصة مهيّأة (`app_startup.dart`).
  static const WriteGate open = WriteGate(WriteGateStatus.open);

  /// انقطع الاتصال.
  WriteGate onConnectionLost() => const WriteGate(WriteGateStatus.blockedOffline);

  /// ★ **عاد الاتصال — ولا تُفتَح البوابة**، بل تنتظر إعادة القراءة.
  ///
  /// ⛔ **والانتقال إلى `open` مباشرةً هو بالضبط ما يمنعه `FR-SYS-14`.**
  WriteGate onConnectionRestored() =>
      const WriteGate(WriteGateStatus.blockedAwaitingRefresh);

  /// أُعيدت قراءة البيانات — ⛔ **ولا تفتح البوابة إن كان الانقطاع قائماً.**
  WriteGate onDataRefreshed() => switch (status) {
        WriteGateStatus.blockedAwaitingRefresh => WriteGate.open,
        WriteGateStatus.blockedOffline => this,
        WriteGateStatus.open => this,
      };

  /// هل يُسمح بالحفظ الآن؟
  bool get allowsWrite => status == WriteGateStatus.open;
}

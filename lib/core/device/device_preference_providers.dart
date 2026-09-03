/// ★★★ **مزوّداتُ تفضيلات العرض** — `AM-012` §4.4.
///
/// ⛔⛔★★★ **وموضعُها `core` لا قدرةٌ بعينها** — ★ **يقرؤها كلُّ ما يعرض اسمَ
/// نوع:** ⟵ **الأنواعُ والمخزونُ والتوريدُ والتوزيعُ والبيعُ النقدي**،
/// ⛔ **فلا تنتمي إلى واحدةٍ منها** (`ADR-0009`).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'device_preferences.dart';

/// تفضيلاتُ الجهاز — ⛔ **تُحقَن في الجذر.**
final Provider<DevicePreferences> devicePreferencesProvider =
    Provider<DevicePreferences>((Ref ref) {
  throw UnimplementedError('devicePreferencesProvider يجب تجاوزه عند الجذر');
});

/// ⛅ **هل يظهر وزنُ الحبة بجانب اسم النوع؟** — `AM-012` §4.4.
///
/// ⛔⛔★★★ **ويُقرأ متزامناً لا `AsyncValue`** — ★ **قرارٌ تنفيذيٌّ مُعلَن:**
/// ⟵ **يُستدعى في كلِّ صفٍّ من كل قائمةٍ تعرض نوعاً**، ⛔ **و`AsyncValue`
/// هناك كانت تُدخِل حالةَ تحميلٍ على *اسمِ صنف*** — ★ **فيومض الاسمُ في كل
/// صفٍّ عند كل بناء.**
///
/// ★★ **والقيمةُ تُقرأ من القرص مرةً واحدة قبل `runApp`** — ★ **وتُحقَن
/// عبر [initialShowPieceWeightProvider]:** ⟵ **فالقراءةُ بعدها من الذاكرة**،
/// ⛔ **ولا وصولَ إلى القرص في بناء ويدجت.**
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **ولماذا حقنُ قيمةٍ مبدئية لا قراءةٌ داخل [Notifier.build]:**
///
/// ★ **قراءةُ [devicePreferencesProvider] هنا كانت تجعل *كلَّ شاشةٍ تعرض
/// اسمَ نوع* تعتمد على حقنِ مخزنٍ حقيقي** — ⟹ ⛔⛔ **فسقطت عشراتُ اختبارات
/// الشاشات دفعةً واحدة بـ`UnimplementedError`** (رُصد فعلاً لحظةَ التنفيذ)،
/// ★ **وهي شاشاتٌ لا شأنَ لها بهذا التفضيل أصلاً.**
///
/// ⟹ ★ **والصوابُ أن تكون القيمةُ المبدئية *مُدخَلاً* لا *أثراً جانبياً*:**
/// ⟵ **فالافتراض `false` بلا أي حقن** ⛔ **ولا يلزم اختباراً لا يعنيه**،
/// ★ **والإنتاجُ وحدَه يُبدِّلها بما قرأه من القرص** (`main.dart`).
///
/// ⛔⛔★★ **وهو نفسُ درس `DEBT-68` من زاويةٍ أخرى:** ★ **هناك كانت الكتابةُ
/// في `initState` تُسقِط الشاشة**، ⟵ **وهنا كانت القراءةُ في `build` تُسقِط
/// الاختبار** — ★ **والقاعدةُ واحدة: دورةُ حياةِ المزوّد ليست موضعَ عملٍ
/// جانبيّ.**
/// ═══════════════════════════════════════════════════════════════════════
final NotifierProvider<ShowPieceWeightPreference, bool>
    showPieceWeightProvider =
    NotifierProvider<ShowPieceWeightPreference, bool>(
  ShowPieceWeightPreference.new,
);

/// ★★ **القيمةُ المبدئية للتفضيل** — ⛔ **يتجاوزها الجذرُ بما قرأه من القرص.**
///
/// ★ **وافتراضُها `false`** — ★ **فالحالةُ القائمة اليوم هي ما يراه من لم
/// يطلب شيئاً** (`AM-012` §4.4: «عند التعطيل يظهر اسم النوع فقط»).
final Provider<bool> initialShowPieceWeightProvider =
    Provider<bool>((Ref ref) => false);

/// حالةُ تفضيل إظهار وزن الحبة.
class ShowPieceWeightPreference extends Notifier<bool> {
  @override
  bool build() => ref.watch(initialShowPieceWeightProvider);

  /// ★ يضبط التفضيل ويكتبه على الجهاز — ⛔ **ولا يكتفي بأحدهما.**
  ///
  /// ⛔⛔★★ **والحالةُ تتغيّر أولاً ثم تُكتَب** — ★ **فالزرُّ يستجيب فوراً**:
  /// ⟵ **وانتظارُ القرص قبل تحديث الشاشة يجعل المبدِّل يبدو معطَّلاً**،
  /// ⛔ **وهو خيارُ عرضٍ لا يستحق حالةَ انتظار.**
  Future<void> set({required bool enabled}) async {
    state = enabled;
    await ref
        .read(devicePreferencesProvider)
        .setShowPieceWeightWithItemName(enabled: enabled);
  }
}

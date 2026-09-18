/// مزوّدات البيانات المرجعية (`WU-002`).
///
/// ★ **بنفس نمط `admin_providers.dart`:** المستودعات **تُحقَن في الجذر ولا
/// تُبنى هنا** (`ADR-0010` — حقن اعتمادية صريح)، ⟵ **فتُختبَر الشاشات بلا
/// سحابة ولا شبكة**.
///
/// ⚠️⚠️ **وكل ما هنا عرضٌ لا تفويض:** إخفاء زرٍّ بـ`sourceWrite` **إخفاء لا
/// حماية** — ★ **والحماية الحقيقية إغلاقُ الكتابة في `firestore.rules`
/// وفحصُ المفتاح في الدالة السحابية** (`ADR-0013` القاعدة 3 · `RISK-02`).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qtms_domain/qtms_domain.dart';

import '../../identity_access/application/session_providers.dart';
import '../infrastructure/contact_picker.dart';

/// دليل البيانات المرجعية — ⛔ **يُحقَن في الجذر**.
final Provider<MasterDataDirectory> masterDataDirectoryProvider =
    Provider<MasterDataDirectory>((Ref ref) {
  throw UnimplementedError('masterDataDirectoryProvider يجب تجاوزه عند الجذر');
});

/// مستودع كتابة البيانات المرجعية — ⛔ **يُحقَن في الجذر**.
final Provider<MasterDataAdminRepository> masterDataAdminProvider =
    Provider<MasterDataAdminRepository>((Ref ref) {
  throw UnimplementedError('masterDataAdminProvider يجب تجاوزه عند الجذر');
});

/// ★ مُنتقي جهات الاتصال — `FR-M3-03` · `FR-M4-03`.
///
/// ⛔★ **والافتراض `null` عمداً:** الزر **إثراءٌ لا مسار إلزامي**، ⟵
/// **فبيئةٌ بلا مُنتقٍ (اختبار · سطح مكتب) تُخفي الزر** ⛔ **ولا تُسقِط
/// النموذج ولا تمنع الإدخال اليدوي.**
final Provider<ContactPicker?> contactPickerProvider =
    Provider<ContactPicker?>((Ref ref) => null);

/// قائمة المصادر الحيّة.
///
/// ⚠️ **وتحترم نطاق المستخدم بشرط القراءة في القاعدة** — ⟵ **فالمستخدم
/// المحدود النطاق يرى مصادره وحدها**، ⛔ **ولا تُصفّى في الجهاز.**
final StreamProvider<List<SourceCard>> sourcesProvider =
    StreamProvider<List<SourceCard>>(
  (Ref ref) => ref.watch(masterDataDirectoryProvider).watchSources(),
);

/// قائمة الرعية الحيّة.
final StreamProvider<List<SupplierCard>> suppliersProvider =
    StreamProvider<List<SupplierCard>>(
  (Ref ref) => ref.watch(masterDataDirectoryProvider).watchSuppliers(),
);

/// قائمة المقاوته الحيّة.
final StreamProvider<List<DealerCard>> dealersProvider =
    StreamProvider<List<DealerCard>>(
  (Ref ref) => ref.watch(masterDataDirectoryProvider).watchDealers(),
);

/// قائمة الأنواع الحيّة.
final StreamProvider<List<ItemCard>> itemsProvider =
    StreamProvider<List<ItemCard>>(
  (Ref ref) => ref.watch(masterDataDirectoryProvider).watchItems(),
);

/// ★ الإعداد التأسيسي — و`null` تعني **لم يُكتب بعد**.
final StreamProvider<AppSettingsCard?> appSettingsProvider =
    StreamProvider<AppSettingsCard?>(
  (Ref ref) => ref.watch(masterDataDirectoryProvider).watchAppSettings(),
);

/// ★★ **هل يجب فتح شاشة الإعداد التأسيسي الإلزامية؟** — `FR-M21-04`.
///
/// ⛔★★ **والشرطان معاً لا أحدهما:** «**شاشة إلزامية لا يمكن تخطّيها عند
/// أول تشغيل بحساب المالك**» — ⟵ ★ **فالموظف الذي لا يملك `appSettingsWrite`
/// لا تُفتَح له**: ⛔ **إذ لا مسار أمامه لإتمامها فيبقى محبوساً في شاشة لا
/// يستطيع مغادرتها ولا إكمالها.**
///
/// ⚠️ **والحالة غير المعروفة (تحميل أو خطأ) ⟵ لا تُفتَح** — ★ **الافتراض
/// الآمن هنا عكسُ المعتاد:** فتحُ الشاشة على خطأ قراءةٍ عابر **يعرض على
/// المالك نموذجاً لا رجعة فيه** بينما الإعداد مكتوبٌ أصلاً، ⛔ **وكتابةٌ
/// ثانيةٌ مرفوضة أصلاً** فلا يجني إلا الحيرة.
final Provider<bool> requiresFirstRunSetupProvider = Provider<bool>((Ref ref) {
  final bool canWrite =
      ref.watch(hasPermissionProvider(Permission.appSettingsWrite));
  if (!canWrite) return false;
  final AsyncValue<AppSettingsCard?> settings = ref.watch(appSettingsProvider);
  if (settings.hasError || !settings.hasValue) return false;
  return settings.value == null;
});

/// ★ المصادر النشطة وحدها — **لاختيارها في نماذج الرعية والأنواع**.
///
/// ⛔★★ **والمعطَّل لا يظهر في اختيارٍ جديد** (`FR-M2-06`) — ★ **ويبقى في
/// القوائم التاريخية**، ⟵ **فالتصفية هنا على مدخلات الإنشاء وحدها**
/// ⛔ **لا على العرض.**
final Provider<List<SourceCard>> activeSourcesProvider =
    Provider<List<SourceCard>>((Ref ref) {
  final List<SourceCard> all =
      ref.watch(sourcesProvider).value ?? const <SourceCard>[];
  return <SourceCard>[
    for (final SourceCard source in all)
      if (source.isActive) source,
  ];
});

/// ★★ اسمُ المصدر للعرض في مستندٍ مُصدَّر — **نطاق `CR-004` المُعتمَد**.
///
/// ★ **والمعطَّل يُسمّى كالنشط** — ⟵ **فالمستند التاريخي يُقرأ بعد تعطيل
/// مصدره** (`FR-M2-06`): ⛔ **والتصفيةُ على مدخلات الإنشاء وحدها.**
///
/// ⛔⛔★★ **ولا اسمَ يُخترَع عند الغياب** — ★ **يقع على المعرّف نفسِه**
/// (`SRC-001`): ⟵ **معرّفٌ صادقٌ خيرٌ من فراغٍ يُقرأ «بلا مصدر»**، ⛔ **ومن
/// اسمٍ مُلفَّق.** ★ **و[auditAllSourcesId] وحدها تُترجَم «كل المصادر»** —
/// **كما ينسُبها كاتبُ القيد** (`audit_entry.dart`).
// ⚠️ **ونوعُه مُستنتَجٌ لا مكتوب** — ★ **كما في `dealerBalanceProvider`**:
// ⟵ **`Provider.family` لا تُصرَّح باسمِ صنفٍ عامٍّ في Riverpod 3.**
final sourceDisplayNameProvider =
    Provider.family<String, String>((Ref ref, String sourceId) {
  if (sourceId == auditAllSourcesId) return 'كل المصادر';
  final List<SourceCard> all =
      ref.watch(sourcesProvider).value ?? const <SourceCard>[];
  for (final SourceCard source in all) {
    if (source.sourceId == sourceId) return source.name;
  }
  return sourceId;
});

/// ★★★ اسمُ النوع للعرض — **نظيرُ [sourceDisplayNameProvider] حرفياً** (`AM-025` ②).
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **ويمرّ بـ[ledgerItemDisplayName] لا بالاسم المخزَّن وحدَه** —
/// [`ADR-0007`] · [`DEBT-86`] · `ui-guidelines.md` §6: ⟵ **فمفتاحٌ مركّبٌ
/// («بطوة - جونية رقم 2») يُعرَض بتمامه**، ★ **ومفتاحُ سجلِ نوعٍ (`ITM-0001`)
/// يُعرَض باسمه المخزَّن** — ⛔ **ولا صيغةَ ثانيةٌ تفترق عن بقية الشاشات.**
///
/// ⛔⛔★★ **ولا اسمَ يُخترَع عند الغياب** — ★ **يقع على المفتاح نفسِه:**
/// ⟵ **مفتاحٌ صادقٌ خيرٌ من فراغٍ ومن اسمٍ مُلفَّق** (نفسُ قاعدة المصدر).
///
/// ⚠️ **والمعطَّل يُسمّى كالنشط** — ⟵ **فالقيدُ التاريخي يُقرأ بعد تعطيل نوعه**
/// ⛔ **والتصفيةُ على مدخلات الإنشاء وحدها.**
/// ═══════════════════════════════════════════════════════════════════════
final itemDisplayNameProvider =
    Provider.family<String, String>((Ref ref, String itemKey) {
  final List<ItemCard> all =
      ref.watch(itemsProvider).value ?? const <ItemCard>[];
  for (final ItemCard item in all) {
    if (item.itemId == itemKey) {
      return ledgerItemDisplayName(itemKey: itemKey, itemName: item.name);
    }
  }
  return ledgerItemDisplayName(itemKey: itemKey, itemName: itemKey);
});

/// ★★ اسمُ المقوت للعرض — **نظيرُ [sourceDisplayNameProvider]** (`AM-025` ②).
///
/// ⛔ **ولا اسمَ يُخترَع عند الغياب** — ★ **يقع على المعرّف نفسِه** (`MQT-0002`).
final dealerDisplayNameProvider =
    Provider.family<String, String>((Ref ref, String dealerId) {
  final List<DealerCard> all =
      ref.watch(dealersProvider).value ?? const <DealerCard>[];
  for (final DealerCard dealer in all) {
    if (dealer.dealerId == dealerId) return dealer.name;
  }
  return dealerId;
});

/// ★★ اسمُ الرعوي للعرض — **نظيرُ [sourceDisplayNameProvider]** (`AM-025` ②).
///
/// ⛔ **ولا اسمَ يُخترَع عند الغياب** — ★ **يقع على المعرّف نفسِه** (`SUP-0001`).
final supplierDisplayNameProvider =
    Provider.family<String, String>((Ref ref, String supplierId) {
  final List<SupplierCard> all =
      ref.watch(suppliersProvider).value ?? const <SupplierCard>[];
  for (final SupplierCard supplier in all) {
    if (supplier.supplierId == supplierId) return supplier.name;
  }
  return supplierId;
});

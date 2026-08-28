/// جسر جهات الاتصال — `FR-M3-03` · `FR-M4-03`.
///
/// ═══════════════════════════════════════════════════════════════════════
/// ★★★ **قرار تنفيذي موثَّق: قناة منصّة مكتوبة بأيدينا ⛔ لا حزمة طرفٍ ثالث.**
///
/// ★ **وهو تطبيقٌ حرفي لسياسة الاعتماديات لا اجتهاد** — `dependency-management-policy.md`:
///
///   | # | السؤال | الجواب هنا |
///   |:-:|---|---|
///   | 1 | هل يُغني عنها الإطار؟ | ✅ **نعم** — قناة منصّة + نيّة النظام |
///   | 2 | كم سطراً توفّر؟ | **أقل من 100** ⟵ «**اكتبه بنفسك**» |
///   | 5 | هل تقرأ بيانات؟ | ⚠️ **نعم — تدقيق إلزامي**، ⟵ **وتفاديناه** |
///
/// ★★ **والأهم أنه أقلّ امتيازاً:** الحزم الشائعة تطلب إذن **قراءة كل جهات
/// الاتصال** (`READ_CONTACTS`)، ⛔ **بينما مُنتقي النظام يُعيد جهةً واحدة
/// اختارها المستخدم بنفسه بلا أي إذن.** ⟵ **فالبيانات الشخصية لا تُقرأ
/// أصلاً** (`security-requirements.md` §2 · مبدأ أقلّ امتياز).
/// ═══════════════════════════════════════════════════════════════════════
///
/// ⚠️ **وهذا الملف يعرّف العقد وتنفيذه على المنصّة** — ⛔ **ولا يستدعيه
/// نموذجٌ مباشرةً**: الشاشات تقرأ `contactPickerProvider`، ⟵ **فيُختبَر
/// النموذج بمُنتقٍ مزيّف بلا جهاز.**
library;

import 'package:flutter/services.dart';

/// جهة اتصال مختارة — **الاسم والرقم معاً بضغطة واحدة** (`FR-M3-03`).
final class PickedContact {
  /// ينشئ الجهة.
  const PickedContact({required this.name, required this.phone});

  /// الاسم المعروض كما في جهاز المستخدم.
  final String name;

  /// الرقم كما هو — ★ **ويُطبَّع في طبقة النطاق** (`normalizePhone`)،
  /// ⛔ **ولا يُطبَّع هنا**: نسخةٌ ثانية من القاعدة تفترق عند أول تعديل.
  final String phone;
}

/// عقد انتقاء جهة اتصال — ★ **يُحقَن، فتُختبَر الشاشة بلا جهاز**.
abstract interface class ContactPicker {
  /// يفتح مُنتقي النظام ويُعيد الجهة المختارة، أو `null` إن ألغى المستخدم.
  ///
  /// ⚠️ **ويُرجِع `null` عند التعذّر أيضاً** — ★ **والزر إثراءٌ لا مسار
  /// إلزامي**، ⟵ **فتعذّرُه لا يمنع الإدخال اليدوي** ولا يُسقِط النموذج.
  Future<PickedContact?> pickOne();
}

/// ★ التنفيذ على المنصّة — عبر قناة واحدة مسمّاة.
///
/// ⛔ **ولا يطلب إذناً ولا يقرأ قائمةً** — راجع ترويسة الملف.
final class PlatformContactPicker implements ContactPicker {
  /// ينشئ المُنتقي.
  const PlatformContactPicker([
    this.channel = const MethodChannel(contactPickerChannel),
  ]);

  /// القناة المستخدَمة — ★ **تُحقَن في الاختبار**.
  final MethodChannel channel;

  @override
  Future<PickedContact?> pickOne() async {
    final Map<Object?, Object?>? result;
    try {
      result = await channel.invokeMapMethod<Object?, Object?>('pickContact');
    } on PlatformException {
      // ⛔ **ليس ابتلاعاً لخطأ مؤثِّر:** الانتقاء **إثراءٌ لا مسار حفظ**،
      //    ⟵ **وتعذّرُه يترك الحقول فارغة للإدخال اليدوي** ⛔ ولا يُسقِط
      //    عمليةً مالية ولا يُخفي فشل حفظ.
      return null;
    } on MissingPluginException {
      // ★ **منصّة بلا تنفيذ** (اختبار أو سطح مكتب) — ⟵ **الزر بلا أثر**
      //   ⛔ ولا انهيار.
      return null;
    }
    if (result == null) return null;
    final Object? name = result['name'];
    final Object? phone = result['phone'];
    // ⛔ **جهةٌ بلا رقم لا تُملأ** — ★ **والرقم هو مفتاح التفرّد** (`FR-M3-02`)،
    //    ⟵ **فملءُ الاسم وحده يترك النموذج ناقصاً بلا أن يعلم المستخدم لماذا.**
    if (phone is! String || phone.trim().isEmpty) return null;
    return PickedContact(
      name: name is String ? name.trim() : '',
      phone: phone.trim(),
    );
  }
}

/// اسم القناة — ★ **يُكتب مرة واحدة ويُشاركه الطرفان** (Dart وKotlin).
const String contactPickerChannel = 'dev.orimind.qtms/contacts';

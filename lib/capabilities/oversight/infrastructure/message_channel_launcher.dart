/// فتحُ قناة الإرسال — ★★ **يفتح المحادثة ولا يُرسِل** (`FR-M20` §1).
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **المبدأ الحاكم — ولا يُخالَف بحال:** «**النظام يفتح المحادثة ولا
/// يرسل تلقائياً. المستخدم هو من يضغط زر الإرسال داخل واتساب/الرسائل**»
/// (`FR-M20` §1 · `messaging-design.md` §2).
///
/// ⟵ ★ **ونتيجةٌ مباشرة مكتوبة في المستند نفسه:** **النظام لا يعرف إن وصلت
/// الرسالة، ولا يُسجَّل أي أثر للإرسال إطلاقاً** (`FR-M20-15` · `AT-64`).
/// ⛔⛔ **فلا مجموعةَ سجلٍّ ولا حقلَ متابعةٍ ولا نداءَ عمليةٍ سحابية من هنا.**
/// ═══════════════════════════════════════════════════════════════════════
///
/// ★ **والرقم بصيغتين لا واحدة** (`FR-M20-11`): **دوليةٌ لواتساب ومحليةٌ
/// للرسائل** — ⟵ **و[normalizePhone] تُنتج المحليَّ المجرَّد** (`IQ-014`
/// الخيار ب)، ★ **والدوليُّ يُبنى بإضافة مفتاح اليمن إليه.**
library;

import 'package:qtms_domain/qtms_domain.dart';
import 'package:url_launcher/url_launcher.dart';

/// مفتاح الدولة اليمني — ★ **أرقام هذا النظام يمنية دائماً** (`IQ-014`).
///
/// ⚠️ **وأثرٌ معلَنٌ للخيار ب:** ★ **رقمٌ غير يمني يُخزَّن بأرقامه كما كُتبت**
/// ⟵ **فيُبنى له رابطٌ دوليٌّ بمفتاحٍ خاطئ** — ★ **وهو حدٌّ معلومٌ من قرار
/// `IQ-014` نفسِه** ⛔ **لا عطلٌ جديد.**
const String yemenDialCode = '967';

/// نتيجة محاولة الفتح — ★ **مصنَّفة لا `bool`**.
enum ChannelLaunchOutcome {
  /// فُتحت القناة.
  opened,

  /// ★ **التطبيق غير مثبَّت** — `FR-M20-12`.
  channelUnavailable,

  /// ⛔ **لا رقم صالح** — `FR-M20-02`.
  noPhone,

  /// تعذّر الفتح لسببٍ آخر.
  failed,
}

/// قناة الإرسال.
enum MessageChannel {
  /// واتساب — ★ **بالرقم الدولي**.
  whatsapp,

  /// الرسائل النصية — ★ **بالرقم المحلي**.
  sms,
}

/// فاتح قنوات الإرسال.
final class MessageChannelLauncher {
  /// ينشئ الفاتح — ★ **ودالتا الفتح تُحقَنان، فيُختبَر بلا جهاز**.
  const MessageChannelLauncher({
    Future<bool> Function(Uri)? canLaunch,
    Future<bool> Function(Uri)? launch,
  })  : _canLaunch = canLaunch ?? canLaunchUrl,
        _launch = launch ?? launchUrl;

  final Future<bool> Function(Uri) _canLaunch;
  final Future<bool> Function(Uri) _launch;

  /// يفتح [channel] برقم [phone] ونصّ [message] جاهزاً في حقل الكتابة.
  Future<ChannelLaunchOutcome> open({
    required MessageChannel channel,
    required String phone,
    required String message,
  }) async {
    final String local = normalizePhone(phone);
    // ⛔★ **ولا يُفتَح شيءٌ برقمٍ فارغ** — `FR-M20-02`: **الزران لا يظهران
    //   أصلاً بلا رقم**، ★ **وهذا حارسٌ ثانٍ لا بديلٌ عن ذاك.**
    if (local.isEmpty) return ChannelLaunchOutcome.noPhone;

    final Uri uri = switch (channel) {
      // ⛔⛔★★★ **مخطَّط `whatsapp:` لا `https://wa.me` — عطلٌ مقيسٌ لا احتياط:**
      //
      // ★ **رُصد حيّاً على `Pixel_6_API_36` (2026-08-30):** ⟵ **`wa.me` رابطٌ
      //   `https`**، **ومتصفّحُ النظام يعالج كلَّ رابط `https` دائماً** —
      //   ⟹ ⛔ **`canLaunchUrl` تصدُق أبداً**، ★ **فرعُ «واتساب غير مثبَّت»
      //   الذي يفرضه `FR-M20-12` **لا يقع أبداً**، ⟵ **ويُفتَح المتصفحُ بدل
      //   واتساب فيظنّ المستخدم أن الإرسال تمّ.**
      //
      // ✅ **والمخطَّط `whatsapp://` لا يعالجه إلا واتساب نفسُه** — ⟵ **فغيابُه
      //   يُقاس فعلاً**، ★ **ويُعرَض اقتراحُ الرسائل النصية كما ينصّ المتطلب.**
      //   ⚠️ **ويلزمه إعلانُ رؤيةٍ في المانفست** (`<data android:scheme="whatsapp"/>`)
      //   ⛔ **وبدونه تُرجِع `canLaunchUrl` كذباً على أندرويد 11+.**
      MessageChannel.whatsapp => Uri.parse(
          'whatsapp://send?phone=$yemenDialCode$local'
          '&text=${Uri.encodeComponent(message)}',
        ),
      // ★ **`sms:` بالرقم المحلي** — `FR-M20-11`.
      //   ⚠️ **و`body` بدل `?body=` في الاستعلام:** ★ **`Uri` تُرمِّز القيمة**،
      //   ⛔ **والأسطر الجديدة تعبر مرمَّزةً لا مقطوعة.**
      MessageChannel.sms =>
        Uri(scheme: 'sms', path: local, queryParameters: <String, String>{
          'body': message,
        }),
    };

    try {
      if (!await _canLaunch(uri)) {
        return ChannelLaunchOutcome.channelUnavailable;
      }
      final bool launched = await _launch(uri);
      return launched
          ? ChannelLaunchOutcome.opened
          : ChannelLaunchOutcome.failed;
    } on Object {
      // ⛔ **ولا يُرمى إلى الشاشة** — `error-handling-strategy.md` §3 القاعدة 3.
      return ChannelLaunchOutcome.failed;
    }
  }
}

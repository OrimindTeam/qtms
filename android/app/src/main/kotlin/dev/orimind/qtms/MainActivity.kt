package dev.orimind.qtms

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.ContactsContract
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * نقطة الدخول على أندرويد — ★ وقناة **جسر جهات الاتصال** وحدها.
 *
 * ═══════════════════════════════════════════════════════════════════════
 * ★★★ ولماذا مُنتقي النظام لا قراءة جهات الاتصال:
 *
 *   FR-M3-03 و FR-M4-03 يطلبان «جلب من جهات الاتصال يملأ **الاسم والرقم
 *   معاً** بضغطة واحدة» — ⛔ ولا يطلبان قراءة القائمة كلها.
 *
 *   ★ و ACTION_PICK يفتح واجهة النظام، **فيختار المستخدم بنفسه جهةً واحدة**،
 *     ⟵ ويعود التطبيق بحقّ قراءةٍ مؤقت لتلك الجهة وحدها.
 *   ⛔ فلا إذن READ_CONTACTS في المانفست ولا طلب إذن وقت التشغيل.
 *
 *   ⚠️ وهذا **أقلّ امتيازاً** من أي حزمة جاهزة، وهو المطلوب في نظامٍ يحمل
 *      بيانات شخصية لرعية ومقاوته (security-requirements.md §2).
 * ═══════════════════════════════════════════════════════════════════════
 */
/**
 * ★★★ AM-012 §5.2 و§6 (ADR-0024 ⏳ مقترح) — ولماذا FlutterFragmentActivity:
 *
 *   ⛔⛔ `local_auth` تفرضه صراحةً في README الرسمي للحزمة:
 *     BiometricPrompt من AndroidX تحتاج FragmentManager، ⟵ ولا يملكه
 *     FlutterActivity العادي.
 *
 *   ⚠️⚠️ والعطلُ صامتٌ لا فشلُ بناء: ★ التطبيقُ يُبنى ويعمل،
 *     ⟵ ثم يرمي عند أول استدعاءٍ لمصادقةٍ بيومترية وحده — ⛔ أي في
 *     يد المستخدم لا في المترجم.
 *
 *   ✅ ولا أثرَ على ما كان: ★ FlutterFragmentActivity يرث FlutterActivity
 *     في سلوك المحرّك كلِّه، ⟵ وجسرُ جهات الاتصال أدناه يعمل كما هو
 *     (startActivityForResult و onActivityResult متاحتان في كليهما).
 */
class MainActivity : FlutterFragmentActivity() {

    /** المُستدعي المعلَّق حتى تعود نتيجة المُنتقي — ⛔ وواحدٌ لا قائمة. */
    private var pending: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result -> onCall(call, result) }
    }

    private fun onCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "pickContact") {
            result.notImplemented()
            return
        }
        // ⛔ طلبٌ ثانٍ والأول معلَّق ⟵ يُنهى الأول بلا نتيجة، ★ ولا يُترك
        //    معلَّقاً إلى الأبد فتبقى الشاشة تنتظر ما لا يأتي.
        pending?.success(null)
        pending = result
        val intent = Intent(Intent.ACTION_PICK, ContactsContract.Contacts.CONTENT_URI)
        try {
            startActivityForResult(intent, REQUEST_PICK_CONTACT)
        } catch (error: android.content.ActivityNotFoundException) {
            // ⛔⛔★★★ AM-020 — خطأٌ صريحٌ لا null صامتة:
            //   ★ جهازٌ بلا تطبيق جهات اتصال (أو بلا إذنٍ لفتحه) ⟵ يصل
            //     الطرفَ الآخر PlatformException، ★ فتعرضه الورقةُ شريطَ
            //     تحذيرٍ يقول للمستخدم ما يفعل.
            //   ⛔ و null هنا كانت تعني «ألغى المستخدم» في العقد نفسِه،
            //     ⟵ فكان الفشلُ يُقرأ إلغاءً ولا يُعرَض شيءٌ إطلاقاً.
            //   ⚠️ والزرُّ يبقى إثراءً لا مسارَ حفظ — ★ والإدخالُ اليدوي
            //     باقٍ، ⛔ ولا انهيار.
            pending = null
            result.error(ERR_NO_CONTACT_PICKER, error.message, null)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != REQUEST_PICK_CONTACT) return
        val reply = pending ?: return
        pending = null
        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            // ★ الإلغاء ليس خطأً — null صريحة.
            reply.success(null)
            return
        }
        reply.success(readContact(data.data!!))
    }

    /**
     * يقرأ الاسم والرقم للجهة المختارة وحدها.
     *
     * ⚠️ وقد لا تحمل الجهة رقماً — ⟵ ويُعاد null، ★ فالرقم مفتاح التفرّد
     *    (FR-M3-02 · FR-M4-02) وملءُ الاسم وحده يترك النموذج ناقصاً.
     */
    private fun readContact(uri: Uri): Map<String, String>? {
        val projection = arrayOf(
            ContactsContract.Contacts._ID,
            ContactsContract.Contacts.DISPLAY_NAME,
            ContactsContract.Contacts.HAS_PHONE_NUMBER,
        )
        contentResolver.query(uri, projection, null, null, null).use { cursor ->
            if (cursor == null || !cursor.moveToFirst()) return null
            val contactId = cursor.getString(0)
            val name = cursor.getString(1) ?: ""
            val hasPhone = cursor.getInt(2) > 0
            if (!hasPhone) return null
            val phone = readFirstPhone(contactId) ?: return null
            return mapOf("name" to name, "phone" to phone)
        }
    }

    private fun readFirstPhone(contactId: String): String? {
        contentResolver.query(
            ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
            arrayOf(ContactsContract.CommonDataKinds.Phone.NUMBER),
            "${ContactsContract.CommonDataKinds.Phone.CONTACT_ID} = ?",
            arrayOf(contactId),
            null,
        ).use { cursor ->
            if (cursor == null || !cursor.moveToFirst()) return null
            return cursor.getString(0)
        }
    }

    private companion object {
        /** ★ نفس النصّ في `contact_picker.dart` — ⛔ ولا نسخة ثالثة. */
        const val CHANNEL = "dev.orimind.qtms/contacts"
        const val REQUEST_PICK_CONTACT = 7301

        /** ★ رمزُ تعذّرِ فتح المُنتقي — ⛔ لا يُعرَض للمستخدم (AM-020). */
        const val ERR_NO_CONTACT_PICKER = "ERR_NO_CONTACT_PICKER"
    }
}

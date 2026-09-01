/// ★★★ **قياس الاتصال من بثِّ قاعدة البيانات نفسِه** — `AM-008` ①.
///
/// ⛔⛔★★★ **ولماذا هذا المقياس دون غيره:** ★ **السؤال الذي يهمّ المستخدم
/// ليس «هل للجهاز شبكة؟» بل «هل ستنجح كتابتي؟»** — ⟵ **وجهازٌ على واجهة
/// شبكةٍ بلا نفاذٍ إلى الخادم يُوسَم «متصل» زوراً بأي مقياسٍ يقيس الواجهة**،
/// ★ **وهو أسوأ من غياب المؤشّر أصلاً** (`ADR-0003`).
///
/// ★★ **والآلية: `snapshots(includeMetadataChanges: true)` على مستندٍ واحد**
/// ⟵ **و`metadata.isFromCache` تصير `true` متى انقطع المُصغي عن الخادم**،
/// **و`false` متى وصل بثٌّ منه.** ⛔ **ولا استطلاعٌ دوري ولا نبضةُ كتابة:**
/// ★ **الكتابة تُنشئ قيداً، والاستطلاع يستهلك قراءاتٍ بلا معلومة جديدة.**
///
/// ★ **والمستند المُراقَب بطاقةُ صاحب الجلسة** — ⟵ **يقرؤها بلا صلاحية**
/// (`allow read: if isSignedIn() && request.auth.uid == userId`)،
/// ⛔ **فلا يُخطئ المؤشّر «انقطاعاً» على مَن ينقصه مفتاح.**
///
/// ⚠️ **ولا مُصغيَ ثانياً على المستند نفسِه بلا فائدة:** ★ **Firestore
/// يشارك المُصغيات على المستند الواحد**، ⟵ **فالكلفة لقطةٌ واحدة لا اثنتان.**
library;

import 'package:cloud_firestore/cloud_firestore.dart';

import 'connection_status.dart';

/// اسم مجموعة المستخدمين — ★ **كما في `data-dictionary.md` §1.**
const String connectionProbeCollection = 'users';

/// مراقب الاتصال الحقيقي.
final class FirestoreConnectionMonitor implements ConnectionMonitor {
  /// ينشئ المراقب بمُعرِّف صاحب الجلسة — ★ **يُعاد بناؤه عند تبدّل الهوية.**
  const FirestoreConnectionMonitor({
    required FirebaseFirestore firestore,
    required Stream<String?> userIds,
  })  : _firestore = firestore,
        _userIds = userIds;

  final FirebaseFirestore _firestore;

  /// ★ بثُّ معرّف صاحب الجلسة — و`null` تعني **لا جلسة**.
  final Stream<String?> _userIds;

  /// ⛔⛔★★★ **و`distinct` ليست تحسيناً — عطلٌ رُصد على المحاكي (2026-08-31):**
  /// ★ **`authStateChanges` تُصدِر عند كل تجديدٍ للرمز بنفس المعرّف** —
  /// ⟵ **و`asyncExpand` تهدم المُصغي وتبنيه**، ★ **وأولُ لقطةٍ بعد إعادة
  /// البناء تأتي من الذاكرة** (`isFromCache: true`): ⟵ ⛔ **فيومض المؤشّر
  /// «غير متصل» أحمرَ ثم يعود** بلا أن ينقطع شيء. ★ **وإنذارٌ كاذبٌ متكرر
  /// يُفقِد المؤشّرَ مصداقيتَه**، ⟵ **فيتجاهله المستخدم حين يصدق.**
  @override
  Stream<ConnectionStatus> watch() =>
      _userIds.distinct().asyncExpand((String? userId) {
        // ⛔ **بلا جلسةٍ لا قياس** — ★ **ولا شريطَ علوياً أصلاً قبل الدخول**
        //    (`ui-guidelines.md` §3-أ الاستثناءان)، ⟵ **فلا يُدَّعى شيء.**
        if (userId == null || userId.isEmpty) {
          return Stream<ConnectionStatus>.value(ConnectionStatus.unknown);
        }
        return _firestore
            .collection(connectionProbeCollection)
            .doc(userId)
            .snapshots(includeMetadataChanges: true)
            .map(
              (DocumentSnapshot<Map<String, dynamic>> snapshot) =>
                  snapshot.metadata.isFromCache
                      ? ConnectionStatus.offline
                      : ConnectionStatus.online,
            );
        // ⛔⛔ **ولا يُبتلَع فشل المُصغي هنا** — ★ **يُترَك يصعد فيقرؤه
        //    `connectionStatusProvider` انقطاعاً** (وفيه شرحُ لماذا التحفّظ
        //    هو الصواب)، ⛔ **ولا `handleError` تُسقطه فيبقى آخرُ وسمٍ معروضاً
        //    وهو كاذب.**
      });
}

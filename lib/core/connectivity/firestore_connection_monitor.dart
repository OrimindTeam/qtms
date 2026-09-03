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

  /// ★ **المسبارُ الحقيقي وحدَه هنا** — ⛔ **ومنطقُ التبديل والتحفّظ في
  /// [watchProbes]** (وفيه شرحُ `distinct` و`DEBT-83`).
  @override
  Stream<ConnectionStatus> watch() => watchProbes(
        userIds: _userIds,
        probe: (String userId) => _firestore
            .collection(connectionProbeCollection)
            .doc(userId)
            .snapshots(includeMetadataChanges: true)
            .map(
              (DocumentSnapshot<Map<String, dynamic>> snapshot) =>
                  snapshot.metadata.isFromCache
                      ? ConnectionStatus.offline
                      : ConnectionStatus.online,
            ),
      );
}

/// ★★★ **منطقُ التبديل والتحفّظ وحدَه** — ⛔ **بلا `Firestore`.**
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **ولماذا فُصل — `DEBT-83` مقيسٌ على المحاكي (2026-09-02):**
/// ★ **تسجيلُ الخروج يُفشِل مُصغيَ `users/{uid}` بـ`PERMISSION_DENIED`**
/// (⟵ **القاعدة تشترط `request.auth.uid == userId`**)، ★ **والخطأُ كان
/// يصعد من `asyncExpand` فيقتل البثَّ الخارجي كلَّه** ⟹ ⛔⛔ **فيبقى
/// المؤشّر «غير متصل» إلى آخر عمر العملية ولو عاد المستخدم ودخل** —
/// **مقيسٌ: بدايةٌ نظيفة ⟵ «متصل»، وبعد خروجٍ ودخولٍ في العملية نفسِها
/// ⟵ «غير متصل» أبداً بينما البيانات تُقرأ من الخادم فعلاً.**
///
/// ⛔⛔★★★ **وهو أسوأُ ما يمكن أن يصيب هذا المؤشّر بالذات:** ★ **وُجد
/// ليمنع ادّعاءً كاذباً** (`ADR-0003` · `AM-008` ①) — ⟵ **فصار هو نفسُه
/// يكذب في الاتجاه الآخر**، ⛔ **ومؤشّرٌ عالقٌ يتجاهله المستخدم حين يصدق.**
///
/// ★★ **والعلاجُ لا يُبدِّل الدلالة المعتمدة:** ★ **فشلُ المُصغي يبقى
/// يُقرأ «انقطاعاً»** ⛔ **ولا يُوسَم «متصلاً»** — ★ **لكنه يُبَثّ قيمةً
/// لا يُنهي المراقب**: ⟹ **فأولُ تبدّلٍ في الهوية يُعيد بناء المُصغي**،
/// ★ **ويتعافى المؤشّر بلا إعادة تشغيل التطبيق.**
/// ═══════════════════════════════════════════════════════════════════════
///
/// ⛔⛔★★★ **و`distinct` ليست تحسيناً — عطلٌ رُصد على المحاكي (2026-08-31):**
/// ★ **`authStateChanges` تُصدِر عند كل تجديدٍ للرمز بنفس المعرّف** —
/// ⟵ **و`asyncExpand` تهدم المُصغي وتبنيه**، ★ **وأولُ لقطةٍ بعد إعادة
/// البناء تأتي من الذاكرة** (`isFromCache: true`): ⟵ ⛔ **فيومض المؤشّر
/// «غير متصل» أحمرَ ثم يعود** بلا أن ينقطع شيء. ★ **وإنذارٌ كاذبٌ متكرر
/// يُفقِد المؤشّرَ مصداقيتَه**، ⟵ **فيتجاهله المستخدم حين يصدق.**
Stream<ConnectionStatus> watchProbes({
  required Stream<String?> userIds,
  required Stream<ConnectionStatus> Function(String userId) probe,
}) =>
    userIds.distinct().asyncExpand((String? userId) {
      // ⛔ **بلا جلسةٍ لا قياس** — ★ **ولا شريطَ علوياً أصلاً قبل الدخول**
      //    (`ui-guidelines.md` §3-أ الاستثناءان)، ⟵ **فلا يُدَّعى شيء.**
      if (userId == null || userId.isEmpty) {
        return Stream<ConnectionStatus>.value(ConnectionStatus.unknown);
      }
      return _guarded(probe(userId));
    });

/// ★ يُحوِّل فشلَ المُصغي إلى **وسمِ انقطاعٍ** ⛔ **لا إلى موتِ المراقب.**
Stream<ConnectionStatus> _guarded(Stream<ConnectionStatus> probe) async* {
  try {
    // ⛔⛔★★ **و`await for` لا `yield*`** — ★ **مقيسٌ باختبارٍ فاشل:**
    //    ⟵ **`yield*` تُمرِّر خطأ البثِّ الداخلي إلى الخارج مباشرةً**
    //    ⛔ **فلا يمرّ بـ`catch` أصلاً**، ★ **فيسقط الوسمُ المتحفّظ.**
    await for (final ConnectionStatus status in probe) {
      yield status;
    }
  } on Object {
    // ⛔⛔ **ولا يُبتلَع الفشل صامتاً** — ★ **يُقرأ انقطاعاً صراحةً**،
    //    ⟵ **وهي نفسُ دلالة `connectionStatusProvider` عند الخطأ**
    //    (وفيه شرحُ لماذا التحفّظ هو الصواب).
    yield ConnectionStatus.offline;
  }
}

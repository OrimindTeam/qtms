/// اعتماد حساب اختبار (QA) التجريبي — ★ **يُحقَن وقت البناء** ⛔ **ولا يُحفَر.**
///
/// ★ **الغرض الوحيد:** تمكين **اختبار المحاكي الوظيفي** (بروتوكول التشغيل
/// §د.2 · §د.3 · §د.4) من تجاوز شاشة الدخول **بلا أن تمرّ قيمةُ الاعتماد في
/// أمرٍ مكتوب ولا في أي مستند** — `AM-004` · `AM-005` ·
/// `environments.md` §1.5 · `RB-staging-qa-account` §5.
///
/// ```bash
/// flutter run --flavor staging \
///   --dart-define-from-file=.secrets/qtms-staging-qa-account.env
/// ```
///
/// ⛔⛔★★ **وحارسان مستقلان يمنعان وصول هذا المسار إلى حزمة إنتاج:**
///
/// | # | الحارس | لماذا يكفي وحده |
/// |:-:|---|---|
/// | 1 | `kDebugMode` | ★ **ثابتُ تصريف** — ⟵ **في بناء الإصدار يصير الفرع كودًا ميتاً يُقتلع بالكامل** |
/// | 2 | القيمتان غير فارغتين | ★ **`String.fromEnvironment` تعود فارغة ما لم تُمرَّر صراحةً** — ⛔ **وبناءُ الإنتاج لا يُمرِّرها** |
///
/// ★ **ويحرسهما بوابةٌ آلية** في `test/core/design/design_gates_test.dart`
/// («بوابة خُطّاف الاختبار») — ⛔ **فإسقاط أحدهما يُفشِل `flutter test`.**
///
/// ⚠️★★ **ولا تسجيلَ دخولٍ تلقائياً:** الخُطّاف **يملأ الحقلين فقط**
/// ⛔ **ولا يضغط «دخول»** — ★ **فيبقى الإرسال فعلاً صريحاً**، ★ **وتبقى كلمةُ
/// المرور خارج سياق الأداة ومخرجاتها في كل الأحوال.**
library;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// بريد حساب الاختبار — ⛔ **فارغٌ ما لم يُمرَّر وقت البناء.**
const String qtmsStagingQaEmail =
    String.fromEnvironment('QTMS_STAGING_QA_EMAIL');

/// كلمة مرور حساب الاختبار — ⛔ **فارغةٌ ما لم تُمرَّر وقت البناء.**
///
/// ⛔⛔ **ولا تُطبَع ولا تُسجَّل ولا تُعرَض في أي رسالة خطأ** — ★ **مسارها
/// الوحيد: هذا الثابت ⟵ حقلُ الإدخال.**
const String qtmsStagingQaPassword =
    String.fromEnvironment('QTMS_STAGING_QA_PASSWORD');

/// اعتمادُ حساب اختبارٍ جاهزٌ للملء المسبق.
final class StagingQaCredentials {
  /// ينشئ الاعتماد — ★ **يُبنى من [resolveStagingQaCredentials] وحدها.**
  const StagingQaCredentials({required this.email, required this.password});

  /// البريد.
  final String email;

  /// كلمة المرور.
  final String password;

  /// ⛔ **لا تكشف القيمتين في أي مخرَج تشخيصي.**
  @override
  String toString() => 'StagingQaCredentials(<محجوب>)';
}

/// يُرجِع الاعتماد **إن سُمح به فعلاً** — ⛔ **و`null` فيما عدا ذلك.**
///
/// ★ **الوسائط للاختبار وحده** — ★ **وقيمها الافتراضية ثوابتُ تصريف**،
/// ⟵ ⛔ **فلا يُغيَّر السلوك الحقيقي بتمرير شيء وقت التشغيل.**
StagingQaCredentials? resolveStagingQaCredentials({
  bool debugMode = kDebugMode,
  String email = qtmsStagingQaEmail,
  String password = qtmsStagingQaPassword,
}) {
  // ① الحارس الأول — ⛔ بناءُ الإصدار لا يصل هنا إطلاقاً.
  if (!debugMode) {
    return null;
  }
  // ② الحارس الثاني — ⛔ وبناءٌ بلا حقن لا يملأ شيئاً.
  final String trimmedEmail = email.trim();
  if (trimmedEmail.isEmpty || password.isEmpty) {
    return null;
  }
  return StagingQaCredentials(email: trimmedEmail, password: password);
}

/// مزوّد الاعتماد — ★ **يُستبدَل في الاختبار** ⛔ **ولا يُقرأ الثابت مباشرةً
/// من الشاشة.**
final Provider<StagingQaCredentials?> stagingQaCredentialsProvider =
    Provider<StagingQaCredentials?>((Ref ref) => resolveStagingQaCredentials());

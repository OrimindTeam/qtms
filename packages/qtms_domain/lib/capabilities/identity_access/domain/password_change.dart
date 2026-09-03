/// ★★★ **تغييرُ كلمة المرور من صاحبها** — [`CR-012`] ⏳ **مقترح** ·
/// `authentication-policy.md` §5 بعد [`CR-005`].
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **والحقُّ مُقرَّرٌ في السياسة منذ `CR-005` ولم يكن له منفِّذ:**
/// «**كلمةٌ أوليةٌ يضبطها المدير عند الإنشاء، ثم تغييرُها من صاحبها متى
/// شاء**» — ⟵ ⛔ **ولا شاشةَ ولا مسارَ في النظام يفعل ذلك حتى `AM-012`.**
///
/// ★★ **وموضعُ الفحص طبقةُ النطاق لا الشاشة** (`ADR-0012`) — ⟵ **فحصٌ خالصٌ
/// بلا استدعاء منصّة** ⛔ **يُختبَر بلا سحابةٍ وبلا شاشة**، ★ **ولا نسخةَ
/// ثانية منه في `functions/`** (⛔ **ولا لزوم: التغييرُ يقع في خدمة
/// المصادقة لا في `Firestore`**).
/// ═══════════════════════════════════════════════════════════════════════
///
/// ⛔⛔★★★ **ولا تُخزَّن كلمةٌ في أي دفترٍ ولا قيدِ تدقيقٍ ولا تُرجَع في ردّ:**
/// `FR-M1-02` قائمٌ بلا مساس — **لا حقل كلمة مرور في سجل المستخدم**،
/// ★ **وقاعدةُ «لا كلمة مرور في أي مستند ولا كود ولا رسالة» مطلقةٌ كما هي.**
library;

import '../../../core/errors/app_error.dart';
import '../../../core/outcome.dart';
import 'user_administration.dart';

/// ★ رمزُ رفضٍ لتغيير كلمة المرور — ★ **مصنَّفٌ لا نصّي**
/// (`error-handling-strategy.md` §3).
enum PasswordChangeRejection {
  /// ⛔ **الجديدةُ أقصرُ من الحدّ** — [initialPasswordMinLength].
  tooShort,

  /// ⛔ **الجديدةُ لا تطابق تأكيدَها** — ★ **خطأٌ مطبعيٌّ يقفل الحساب.**
  confirmationMismatch,

  /// ⛔ **الحاليةُ فارغة** — ★ **وإعادةُ المصادقة شرطٌ لا خيار.**
  currentMissing,

  /// ⛔⛔★★ **والجديدةُ نفسُ الحالية** — ★ **ليس تغييراً.**
  ///
  /// ⚠️ **ولماذا يُرفَض بدل أن يمرّ بلا أثر:** ⟵ **خدمةُ المصادقة تقبله
  /// وتُرجِع نجاحاً**، ⛔ **فيقرأ المستخدم «تغيّرت» وهي لم تتغيّر** —
  /// ★ **وهو أسوأ من رفضٍ صريح**، ⚠️ **خصوصاً إن غيّرها ظنّاً أن أحداً
  /// اطّلع عليها.**
  unchanged,
}

/// ★★ كلمةُ مرورٍ جديدة مُتحقَّق منها — ⛔ **ولا تُبنى إلا من [validatePasswordChange]**.
///
/// ⛔⛔★★★ **و[toString] لا تكشف القيمة أبداً** — ★ **نفسُ حارس
/// [InitialPassword] حرفياً:** ⟵ **رسائلُ الأخطاء وسجلاتُ التشخيص تستدعيها
/// ضمناً**، ⛔ **فسلسلةٌ عارية كانت تتسرّب إلى سجلٍّ بلا أن يقصد أحد.**
final class PasswordChange {
  const PasswordChange._(this.currentPassword, this.newPassword);

  /// ★ الحالية — **لإعادة المصادقة وحدها** ⛔ **ولا تُخزَّن.**
  final String currentPassword;

  /// ★ الجديدة — **تُمرَّر لخدمة المصادقة** ⛔ **ولا تُقرأ لغير ذلك.**
  final String newPassword;

  /// ⛔⛔★★★ **ولا تكشف أياً منهما.**
  @override
  String toString() => 'PasswordChange(***)';
}

/// ★★★ يفحص طلبَ تغيير كلمة المرور — [`CR-012`] `FR-M1-19` المقترح.
///
/// ★ **والترتيب مقصود:** **الحالية ⟵ الطول ⟵ التطابق ⟵ عدمُ التغيّر** —
/// ⟵ **فيُخبَر المستخدمُ بأقربِ عائقٍ إليه أولاً**، ⛔ **ولا يُرفَض لسببٍ
/// لاحقٍ بينما الأولُ قائم.**
///
/// ⚠️⚠️ **ولا تُقصّ الأطراف** — ★ **نفسُ قاعدة [validateInitialPassword]:**
/// **الفراغُ محرفٌ صالح في كلمة المرور**، ⟵ **وقصُّه يجعل ما يُرسَل غيرَ
/// ما كتبه المستخدم** ⛔ **فيفشل الدخول بعدها.**
///
/// ⛔⛔★★★ **والحدُّ ثمانيةٌ لا ستّة** — ★ **رغم أن طلب المالك يقول «6 أحرف
/// على الأقل»** ([`CR-012`] §2.2): ⟵ **`authentication-policy.md` §5 بعد
/// `CR-005` يُثبِّته عند ثمانية نصّاً**، ★ **و`validateInitialPassword`
/// تفرضه فعلاً على الكلمة الأولية** ⟹ ⛔⛔ **فستّةٌ هنا كانت تجعل النظام
/// يقبل في شاشةٍ ما يرفضه في أخرى للسرِّ نفسِه** — ★ **والقرارُ مُعلَنٌ في
/// `CR-012` §2.2** ⛔ **لا مطبَّقٌ صامتاً.**
Outcome<PasswordChange> validatePasswordChange({
  required String currentPassword,
  required String newPassword,
  required String confirmation,
}) {
  if (currentPassword.isEmpty) {
    return const Failure<PasswordChange>(
      ValidationError('PasswordChangeRejection.currentMissing'),
    );
  }
  if (newPassword.length < initialPasswordMinLength) {
    return const Failure<PasswordChange>(
      ValidationError('PasswordChangeRejection.tooShort'),
    );
  }
  if (newPassword != confirmation) {
    return const Failure<PasswordChange>(
      ValidationError('PasswordChangeRejection.confirmationMismatch'),
    );
  }
  if (newPassword == currentPassword) {
    return const Failure<PasswordChange>(
      ValidationError('PasswordChangeRejection.unchanged'),
    );
  }
  return Success<PasswordChange>(
    PasswordChange._(currentPassword, newPassword),
  );
}

/// ★ سببُ الرفض من رمزه — ⛔ **والمجهول `null` لا افتراضٌ صامت.**
PasswordChangeRejection? passwordChangeRejectionOf(String code) =>
    switch (code) {
      'PasswordChangeRejection.tooShort' => PasswordChangeRejection.tooShort,
      'PasswordChangeRejection.confirmationMismatch' =>
        PasswordChangeRejection.confirmationMismatch,
      'PasswordChangeRejection.currentMissing' =>
        PasswordChangeRejection.currentMissing,
      'PasswordChangeRejection.unchanged' => PasswordChangeRejection.unchanged,
      _ => null,
    };

/// ★★★ **تغييرُ كلمة المرور من صاحبها** — [`CR-012`] · `AM-012` §5.3.
library;

import 'package:qtms_domain/qtms_domain.dart';
import 'package:test/test.dart';

/// ★ رمزُ الرفض من النتيجة — ⛔ **ولا يُقرأ نصٌّ حرّ.**
PasswordChangeRejection? rejectionOf(Outcome<PasswordChange> outcome) =>
    switch (outcome) {
      Failure<PasswordChange>(error: final ValidationError error) =>
        passwordChangeRejectionOf(error.ruleCode),
      _ => null,
    };

void main() {
  group('★★★ `CR-012` — فحصُ تغيير كلمة المرور', () {
    test('✅ الحالةُ السعيدة — ثلاثةُ حقولٍ صحيحة', () {
      final Outcome<PasswordChange> result = validatePasswordChange(
        currentPassword: 'oldPass123',
        newPassword: 'newPass456',
        confirmation: 'newPass456',
      );
      expect(result, isA<Success<PasswordChange>>());
      final PasswordChange change = (result as Success<PasswordChange>).value;
      expect(change.currentPassword, 'oldPass123');
      expect(change.newPassword, 'newPass456');
    });

    test('⛔ والحاليةُ الفارغة تُرفَض — إعادةُ المصادقة شرطٌ لا خيار', () {
      expect(
        rejectionOf(
          validatePasswordChange(
            currentPassword: '',
            newPassword: 'newPass456',
            confirmation: 'newPass456',
          ),
        ),
        PasswordChangeRejection.currentMissing,
      );
    });

    test('⛔⛔★★★ والحدُّ ثمانيةٌ لا ستّة — `CR-012` §2.2', () {
      // ★★★ **وطلبُ المالك يقول «6 أحرف»** — ⛔ **ولم يُنفَّذ بستّة:**
      //    ⟵ **`authentication-policy.md` §5 بعد `CR-005` يُثبِّته عند
      //    ثمانية**، ★ **و`validateInitialPassword` تفرضه فعلاً** ⟹
      //    ⛔ **فستّةٌ هنا كانت تجعل النظام يقبل في شاشةٍ ما يرفضه في أخرى.**
      expect(initialPasswordMinLength, 8);
      expect(
        rejectionOf(
          validatePasswordChange(
            currentPassword: 'oldPass123',
            newPassword: 'abc123',
            confirmation: 'abc123',
          ),
        ),
        PasswordChangeRejection.tooShort,
      );
      // ★ **وثمانيةٌ بالضبط تمرّ** — ⛔ **والحدُّ «أقلّ من» لا «أقلّ أو يساوي».**
      expect(
        validatePasswordChange(
          currentPassword: 'oldPass123',
          newPassword: 'abcd1234',
          confirmation: 'abcd1234',
        ),
        isA<Success<PasswordChange>>(),
      );
    });

    test('⛔★★ وعدمُ التطابق يُرفَض — خطأٌ مطبعيٌّ يقفل الحساب', () {
      expect(
        rejectionOf(
          validatePasswordChange(
            currentPassword: 'oldPass123',
            newPassword: 'newPass456',
            confirmation: 'newPass457',
          ),
        ),
        PasswordChangeRejection.confirmationMismatch,
      );
    });

    test('⛔⛔★★ والجديدةُ نفسُ الحالية تُرفَض — ليست تغييراً', () {
      // ⚠️ **وخدمةُ المصادقة تقبلها وتُرجِع نجاحاً** — ⟵ **فيقرأ المستخدم
      //    «تغيّرت» وهي لم تتغيّر**، ⛔ **وهو أسوأ من رفضٍ صريح.**
      expect(
        rejectionOf(
          validatePasswordChange(
            currentPassword: 'samePass123',
            newPassword: 'samePass123',
            confirmation: 'samePass123',
          ),
        ),
        PasswordChangeRejection.unchanged,
      );
    });

    test('⛔⛔★★★ ولا تُقصّ الأطراف — الفراغُ محرفٌ صالح', () {
      // ★ **وقصُّه يجعل ما يُرسَل غيرَ ما كتبه المستخدم** ⛔ **فيفشل الدخول.**
      final Outcome<PasswordChange> result = validatePasswordChange(
        currentPassword: ' old pass ',
        newPassword: ' new pass ',
        confirmation: ' new pass ',
      );
      final PasswordChange change = (result as Success<PasswordChange>).value;
      expect(change.newPassword, ' new pass ');
      expect(change.currentPassword, ' old pass ');
    });

    test('⛔⛔★★★ و`toString` لا تكشف أياً من الكلمتين', () {
      // ★★ **نفسُ حارس [InitialPassword]** — ⟵ **ورسائلُ الأخطاء وسجلاتُ
      //    التشخيص تستدعيها ضمناً.**
      final PasswordChange change = (validatePasswordChange(
        currentPassword: 'secretOld1',
        newPassword: 'secretNew1',
        confirmation: 'secretNew1',
      ) as Success<PasswordChange>)
          .value;
      expect(change.toString(), 'PasswordChange(***)');
      expect(change.toString(), isNot(contains('secret')));
    });

    test('★ ورمزٌ مجهولٌ يُقرأ `null` — ⛔ ولا افتراضٌ صامت', () {
      expect(passwordChangeRejectionOf('something.else'), isNull);
    });
  });
}

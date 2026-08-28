/// تصنيف أخطاء خدمة المصادقة — ★ **بالرمز لا بالنصّ** (خلافاً لـ`DEBT-19`).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:qtms/capabilities/identity_access/infrastructure/firebase_auth_repository.dart';
import 'package:qtms_domain/qtms_domain.dart';

void main() {
  group('mapSignInError', () {
    test('★ الرموز المعروفة تُصنَّف أسباباً', () {
      expect(
        mapSignInError('invalid-credential'),
        SignInRejection.invalidCredentials,
      );
      expect(
        mapSignInError('wrong-password'),
        SignInRejection.invalidCredentials,
      );
      expect(mapSignInError('user-disabled'), SignInRejection.accountDisabled);
      expect(mapSignInError('too-many-requests'), SignInRejection.lockedOut);
      expect(
        mapSignInError('network-request-failed'),
        SignInRejection.noConnection,
      );
    });

    test('⛔★ وما لا يُعرَف يبقى «غير متوقَّع» ⟵ ولا يُقنَّع اعتماداً خاطئاً', () {
      // ★ الاتجاه الآمن: العطل يبقى ظاهراً، ⛔ ولا يُقال للمستخدم إن كلمته
      //   خاطئة بينما العطل في المنصة.
      expect(mapSignInError('internal-error'), SignInRejection.unexpected);
      expect(mapSignInError(''), SignInRejection.unexpected);
    });
  });
}

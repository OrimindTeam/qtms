/// ★★ اختبارات خُطّاف اعتماد حساب الاختبار — `AM-005` · `DEBT-31`.
///
/// ⚠️⚠️ **ولماذا اختبارٌ لكل حارسٍ على حدة:** ★ **الحارسان مستقلان عمداً**،
/// ⟵ **فاختبارٌ يمرّ لأن الآخر فعّالٌ لا يُثبت شيئاً عن المُختبَر.**
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:qtms/core/startup/staging_qa_credentials.dart';

void main() {
  group('★★ حارسا خُطّاف اختبار المحاكي', () {
    test('⛔ بناءُ الإصدار لا يُرجِع اعتماداً — ولو كان الحقن كاملاً', () {
      expect(
        resolveStagingQaCredentials(
          debugMode: false,
          email: 'qa@example.test',
          password: 'x',
        ),
        isNull,
      );
    });

    test('⛔ وبناءُ التصحيح بلا حقن لا يُرجِع اعتماداً', () {
      expect(
        resolveStagingQaCredentials(debugMode: true, email: '', password: ''),
        isNull,
      );
    });

    test('⛔ وبريدٌ بفراغاتٍ وحدها ليس بريداً', () {
      expect(
        resolveStagingQaCredentials(
          debugMode: true,
          email: '   ',
          password: 'x',
        ),
        isNull,
      );
    });

    test('⛔ وكلمةُ مرورٍ فارغةٍ تُبطِل الاعتماد ولو صحّ البريد', () {
      expect(
        resolveStagingQaCredentials(
          debugMode: true,
          email: 'qa@example.test',
          password: '',
        ),
        isNull,
      );
    });

    test('✅ والحارسان معاً مستوفَيان ⟵ يُرجِع الاعتماد مُشذَّب البريد', () {
      final StagingQaCredentials? qa = resolveStagingQaCredentials(
        debugMode: true,
        email: '  qa@example.test  ',
        password: '  كلمةٌ بمسافات  ',
      );
      expect(qa, isNotNull);
      expect(qa!.email, 'qa@example.test');
      // ⛔ كلمة المرور لا تُشذَّب — ★ **فالمسافة فيها قيمةٌ معنوية.**
      expect(qa.password, '  كلمةٌ بمسافات  ');
    });

    test('⛔ ولا تكشف `toString` قيمةً — ولو في مخرَجٍ تشخيصي', () {
      final StagingQaCredentials qa = resolveStagingQaCredentials(
        debugMode: true,
        email: 'qa@example.test',
        password: 'سرٌّ لا يظهر',
      )!;
      final String rendered = qa.toString();
      expect(rendered.contains('qa@example.test'), isFalse);
      expect(rendered.contains('سرٌّ لا يظهر'), isFalse);
    });

    test('★ والقيمتان الحقيقيتان فارغتان ما لم تُمرَّرا وقت البناء', () {
      // ⟵ **قياسٌ لا افتراض:** الاختبارات تُبنى بلا `--dart-define`،
      //   ★ **فبقاؤهما فارغتين يُثبت أن لا قيمة محفورة في المستودع.**
      expect(qtmsStagingQaEmail, isEmpty);
      expect(qtmsStagingQaPassword, isEmpty);
    });
  });
}

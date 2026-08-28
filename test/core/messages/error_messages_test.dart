/// ★★★ **معبر الرسائل — `DEBT-52`:** ⛔ **لا يبتلع تشخيصاً موجوداً.**
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:qtms/core/messages/error_messages.dart';
import 'package:qtms_domain/qtms_domain.dart';

void main() {
  group('⛔⛔ رمزٌ خارج الكتالوج يصل بنصّه — `DEBT-52`', () {
    test('★★ رمزٌ مجهول يُعرَض برمزه ⛔ لا بالرسالة العامة المطلقة', () {
      // ⟵ **وهو عينُ ما كلّف `DEBT-49` أربع جولات تشخيص.**
      final String text = catalogText(callableErrorMessage('ERR_CALL_400'));

      expect(text, contains('ERR_CALL_400'));
      expect(text, isNot(catalogText(CatalogMessage.operationFailed)));
    });

    test('★ والنوع نفسه يُميَّز — `DiagnosticMessage` لا مدخل كتالوج', () {
      expect(callableErrorMessage('ERR_WHAT_999'), isA<DiagnosticMessage>());
      expect(callableErrorMessage('ERR_AUTH_001'), isA<CatalogEntry>());
    });

    test('★★ و`InfrastructureError` المحلية تصل بنصّها كاملاً', () {
      // ★ **«QTMS_FUNCTIONS_BASE_URL غير مضبوط…» كان يُطوى تماماً.**
      const String diagnostic = 'QTMS_FUNCTIONS_BASE_URL غير مضبوط في هذا البناء';
      final String text =
          catalogText(appErrorMessage(const InfrastructureError(diagnostic)));

      expect(text, contains(diagnostic));
    });

    test('⛔ ولا «أعد المحاولة» في النصّ التشخيصي — فعلٌ لا ينجح', () {
      final String text = catalogText(const DiagnosticMessage('ERR_CALL_400'));

      expect(text, isNot(contains('أعد المحاولة')));
    });

    test('★ والفارغ وحده يسقط إلى الرسالة العامة ⛔ فلا شاشة بلا نصّ', () {
      expect(
        catalogText(const DiagnosticMessage('   ')),
        catalogText(CatalogMessage.operationFailed),
      );
    });

    test('★ والطويل يُقصّ بعلامة قطع ⛔ لا يُحذف كلّه', () {
      final String text = catalogText(DiagnosticMessage('x' * 400));

      expect(text, contains('…'));
      expect(text.length, lessThan(400));
      expect(text, contains('xxx'));
    });
  });

  group('✅ ومداخل الكتالوج لم تُمَسّ', () {
    test('★ كل رمز معروف يبقى على نصّه حرفاً بحرف', () {
      expect(
        catalogText(callableErrorMessage('ERR_AUTH_001')),
        '❌ ليس لديك صلاحية تنفيذ هذه العملية.',
      );
      expect(
        catalogText(callableErrorMessage('ERR_MONEY_001')),
        catalogText(CatalogMessage.fractionalMoney),
      );
    });

    test('★ وأخطاء النطاق المصنَّفة تبقى على مداخلها', () {
      expect(
        appErrorMessage(const ConnectivityError()),
        CatalogMessage.noConnection,
      );
      expect(
        appErrorMessage(const PermissionError()),
        CatalogMessage.permissionMissing,
      );
    });
  });
}

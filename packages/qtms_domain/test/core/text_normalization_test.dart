import 'package:qtms_domain/qtms_domain.dart';
import 'package:test/test.dart';

void main() {
  group('تطبيع الاسم — IQ-013 الخيار أ (تطبيع عربي كامل)', () {
    test('① التاء المربوطة تُوحَّد إلى الهاء — «فاطمة» ⟷ «فاطمه»', () {
      expect(normalizeName('فاطمة'), normalizeName('فاطمه'));
      expect(normalizeName('فاطمة'), 'فاطمه');
    });

    test('② الألف المقصورة تُوحَّد إلى الياء — «يحيى» ⟷ «يحيي»', () {
      expect(normalizeName('يحيى'), normalizeName('يحيي'));
      expect(normalizeName('يحيى'), 'يحيي');
    });

    test('③ التشكيل يُحذف — «السُّكرب» ⟷ «السكرب»', () {
      expect(normalizeName('السُّكْرَب'), normalizeName('السكرب'));
      // ★ ومُدخَلٌ كلُّه تشكيل يذوب فيعود فارغاً — فلا يصلح مفتاح تفرّد.
      expect(normalizeName('ًٌٍَُِّْ'), '');
    });

    test('④ التطويل يُحذف — «السكــرب» ⟷ «السكرب»', () {
      expect(normalizeName('السكـــرب'), normalizeName('السكرب'));
      expect(normalizeName('ســـما'), 'سما');
    });

    test('★ وحوامل الهمزة كلها لا ألفاتها وحدها', () {
      expect(normalizeName('أحمد'), 'احمد');
      expect(normalizeName('إحمد'), 'احمد');
      expect(normalizeName('آحمد'), 'احمد');
      expect(normalizeName('ٱحمد'), 'احمد');
      expect(normalizeName('مؤمن'), 'مومن');
      expect(normalizeName('رئيس'), 'رييس');
      expect(normalizeName('سماء'), 'سما');
    });

    test('★ والصيغة المُركَّبة تلتقي المُدمَجة على المفتاح نفسه', () {
      // ا + U+0654 (همزة فوق) ⟵ يجب أن تساوي «أ» المدمجة.
      const String composed = 'أحمد';
      expect(normalizeName(composed), normalizeName('أحمد'));
    });

    test('⑤ المسافات الزائدة تُزال — بالطرفين وبالداخل', () {
      expect(normalizeName('  عود   ممتاز  '), 'عود ممتاز');
      expect(normalizeName('عود\tممتاز'), 'عود ممتاز');
      expect(normalizeName('   '), '');
      expect(normalizeName(''), '');
    });

    test('⑥ حالة الأحرف تُوحَّد — للاتينية', () {
      expect(normalizeName('Ali  KHAN'), 'ali khan');
      expect(normalizeName('SCRAP'), normalizeName('scrap'));
    });

    test('★★ والدالة ثابتة عند إعادة التطبيق (Idempotent)', () {
      const List<String> samples = <String>[
        'فاطمة',
        'يحيى',
        'السُّكْـرَب',
        '  عود   ممتاز  ',
        'مؤمنة',
        'Ali KHAN',
      ];
      for (final String sample in samples) {
        final String once = normalizeName(sample);
        expect(normalizeName(once), once, reason: 'ثبات التطبيع: $sample');
      }
    });

    test('⛔ ولا تدمج أسماءً مختلفة فعلاً', () {
      expect(normalizeName('عود'), isNot(normalizeName('شامي')));
      expect(normalizeName('السكرب'), isNot(normalizeName('السكري')));
      expect(normalizeName('محمد'), isNot(normalizeName('محمود')));
    });

    test('★ والقيمة المُطبَّعة هي مفتاح التفرّد — الحالة التي كشفها IQ-013', () {
      expect(normalizeName('مؤسسة اليمن'), normalizeName('موسسه اليمن'));
    });
  });

  group('تطبيع الهاتف — IQ-014 الخيار ب (المحلي المجرَّد)', () {
    const String key = '777123456';

    test('★★ خمس صيغ لرقم واحد تُنتج مفتاحاً واحداً', () {
      expect(normalizePhone('777123456'), key);
      expect(normalizePhone('0777123456'), key);
      expect(normalizePhone('+967777123456'), key);
      expect(normalizePhone('00967777123456'), key);
      expect(normalizePhone('967777123456'), key);
    });

    test('★ والأرقام العربية الهندية رقمٌ واحد لا مفتاحان', () {
      // لوحة المفاتيح العربية تكتب هذه، واللاتينية تكتب تلك.
      expect(normalizePhone('٧٧٧١٢٣٤٥٦'), key);
      expect(normalizePhone('۷۷۷۱۲۳۴۵۶'), key); // الصيغة الفارسية كذلك
      expect(normalizePhone('+٩٦٧ ٧٧٧ ١٢٣ ٤٥٦'), key);
    });

    test('① كل ما ليس رقماً يُسقَط — مسافات وشرطات وأقواس و+', () {
      expect(normalizePhone(' 777-123-456 '), key);
      expect(normalizePhone('(0777) 123 456'), key);
      expect(normalizePhone('+967-777-123-456'), key);
    });

    test('② الأصفار البادئة تُحذف — والثابت كالمحمول', () {
      expect(normalizePhone('01234567'), '1234567');
      expect(normalizePhone('0001234567'), '1234567');
    });

    test('★ والصيغة الدولية والمحلية تلتقيان على المفتاح نفسه', () {
      // ⛔ ولا يُدَّعى أن ترتيب الخطوتين شرط صحّة — الطفرة أثبتت عكسه.
      expect(normalizePhone('00967777123456'), normalizePhone('0777123456'));
    });

    test('⛔ وحارس الطول يمنع بتر مُدخَل قصير', () {
      // ⛔ لا يُقرأ «967» مفتاحَ دولة هنا — فما بعده أقصر من رقم محلي.
      expect(normalizePhone('9671'), '9671');
      expect(normalizePhone('967'), '967');
    });

    test('★★ والدالة ثابتة عند إعادة التطبيق (Idempotent)', () {
      const List<String> samples = <String>[
        '+967777123456',
        '00967777123456',
        '0777123456',
        '٧٧٧١٢٣٤٥٦',
        '01234567',
        '9671',
      ];
      for (final String sample in samples) {
        final String once = normalizePhone(sample);
        expect(normalizePhone(once), once, reason: 'ثبات التطبيع: $sample');
      }
    });

    test('⛔ ولا تدمج رقمين مختلفين', () {
      expect(normalizePhone('777123456'), isNot(normalizePhone('777123457')));
      expect(normalizePhone('771234560'), isNot(normalizePhone('777123456')));
    });

    test('★ ومُدخَل بلا أرقام يعود فارغاً — فلا يصلح مفتاحاً', () {
      expect(normalizePhone(''), '');
      expect(normalizePhone('  --  '), '');
      expect(normalizePhone('لا رقم هنا'), '');
    });

    test('⚠️ ورقم غير يمني يُحفظ بأرقامه — أثرٌ معلَن للخيار ب', () {
      // القرار: الأرقام يمنية دائماً ⟵ فلا يُحذف مفتاح دولة آخر.
      expect(normalizePhone('+966555123456'), '966555123456');
    });
  });
}

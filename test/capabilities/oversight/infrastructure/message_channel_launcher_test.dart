/// فاتح قنوات الإرسال — `M20` (`WU-010`).
///
/// ⚠️⚠️ **وما تُثبته هذه الاختبارات:** أن **الرابط يُبنى بالرقم الصحيح
/// وبالنصّ مرمَّزاً**، وأن **الرقم الدولي لواتساب والمحلي للرسائل**
/// (`FR-M20-11`)، وأن **غياب التطبيق يُميَّز عن الفشل** (`FR-M20-12`)،
/// وأن **الرقم الفارغ يُرفَض** (`FR-M20-02`).
///
/// ⛔⛔ **ولا تُثبت أن الرسالة وصلت** — ★ **والنظام لا يعرف ذلك أصلاً**
/// (`FR-M20-15` · `AT-64`): ⟵ **يفتح المحادثة ولا يُرسِل.**
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:qtms/capabilities/oversight/infrastructure/message_channel_launcher.dart';

void main() {
  late List<Uri> opened;
  late List<Uri> probed;

  MessageChannelLauncher launcher({
    bool available = true,
    bool launches = true,
    bool throws = false,
  }) =>
      MessageChannelLauncher(
        canLaunch: (Uri uri) async {
          if (throws) throw StateError('قناة غير متاحة');
          probed.add(uri);
          return available;
        },
        launch: (Uri uri) async {
          opened.add(uri);
          return launches;
        },
      );

  setUp(() {
    opened = <Uri>[];
    probed = <Uri>[];
  });

  group('FR-M20-11 — الرقم الدولي لواتساب والمحلي للرسائل', () {
    test('★★ واتساب: مخطَّط `whatsapp:` بمفتاح اليمن والنصّ مرمَّزاً', () async {
      final ChannelLaunchOutcome outcome = await launcher().open(
        channel: MessageChannel.whatsapp,
        phone: '0771234567',
        message: 'سطر\nثانٍ',
      );

      expect(outcome, ChannelLaunchOutcome.opened);
      expect(opened.single.scheme, 'whatsapp');
      // ★ **والرقم المحلي المجرَّد بعد `normalizePhone`** (`IQ-014`)
      //   **مسبوقاً بمفتاح الدولة** (`FR-M20-11`).
      expect(opened.single.queryParameters['phone'], '967771234567');
      expect(opened.single.queryParameters['text'], 'سطر\nثانٍ');
    });

    test('⛔⛔★★★ ولا رابطَ `https` في مسار واتساب — حارسُ ارتدادٍ مقيس', () async {
      // ═══════════════════════════════════════════════════════════════════
      // ⚠️⚠️ **عطلٌ رُصد حيّاً على `Pixel_6_API_36` (2026-08-30):** ★ **كان
      //    المسار `https://wa.me/…`** — ⟵ **ومتصفّحُ النظام يعالج كلَّ رابط
      //    `https`**، ⟹ ⛔ **`canLaunchUrl` تصدُق أبداً** ★ **فرعُ «واتساب غير
      //    مثبَّت» الذي يفرضه `FR-M20-12` لا يقع أبداً**، ⟵ **ويُفتَح المتصفّحُ
      //    بدل واتساب فيظنّ المستخدمُ أن الرسالة في طريقها.**
      //
      // ⛔ **ولم يكشفه اختبارٌ آليٌّ واحد** — ★ **لأن البديل يُجيب `true`
      //    دائماً**: ⟹ **وهو الوجهُ السادس لدرس `DEBT-37`.**
      // ═══════════════════════════════════════════════════════════════════
      await launcher().open(
        channel: MessageChannel.whatsapp,
        phone: '771234567',
        message: 'نص',
      );
      expect(opened.single.scheme, isNot('https'));
      expect(opened.single.toString(), isNot(contains('wa.me')));
    });

    test('★ الرسائل: `sms:` بالرقم المحلي ⛔ بلا مفتاح دولة', () async {
      await launcher().open(
        channel: MessageChannel.sms,
        phone: '+967 771 234 567',
        message: 'إجمالي: 1,000',
      );

      expect(opened.single.scheme, 'sms');
      expect(opened.single.path, '771234567');
      expect(opened.single.queryParameters['body'], 'إجمالي: 1,000');
    });

    test('★★ والأسطر الجديدة تعبر مرمَّزةً ⛔ لا مقطوعة', () async {
      await launcher().open(
        channel: MessageChannel.whatsapp,
        phone: '771234567',
        message: 'أ\nب\nج',
      );
      // ⛔ **ولا يُقاس النصّ الخام بل المفكوك** — ★ **فالترميز هو المطلوب.**
      expect(opened.single.toString(), isNot(contains('\n')));
      expect(opened.single.queryParameters['text'], 'أ\nب\nج');
    });
  });

  group('⛔ حالات التعذّر — مصنَّفةٌ لا `bool`', () {
    test('★ FR-M20-12: التطبيق غير مثبَّت ⟵ [channelUnavailable]', () async {
      final ChannelLaunchOutcome outcome =
          await launcher(available: false).open(
        channel: MessageChannel.whatsapp,
        phone: '771234567',
        message: 'نص',
      );
      expect(outcome, ChannelLaunchOutcome.channelUnavailable);
      // ⛔ **ولا يُفتَح شيء** — ★ **فالفحص يسبق الفتح.**
      expect(opened, isEmpty);
    });

    test('⛔ FR-M20-02: رقمٌ بلا أرقام ⟵ [noPhone] ⛔ ولا فحصَ قناة', () async {
      final ChannelLaunchOutcome outcome = await launcher().open(
        channel: MessageChannel.sms,
        phone: '   ',
        message: 'نص',
      );
      expect(outcome, ChannelLaunchOutcome.noPhone);
      expect(probed, isEmpty);
      expect(opened, isEmpty);
    });

    test('★ وفشلُ الفتح يُميَّز عن غياب التطبيق', () async {
      final ChannelLaunchOutcome outcome = await launcher(launches: false).open(
        channel: MessageChannel.sms,
        phone: '771234567',
        message: 'نص',
      );
      expect(outcome, ChannelLaunchOutcome.failed);
    });

    test('⛔⛔ والاستثناء لا يعبر إلى الشاشة — §3 القاعدة 3', () async {
      final ChannelLaunchOutcome outcome = await launcher(throws: true).open(
        channel: MessageChannel.whatsapp,
        phone: '771234567',
        message: 'نص',
      );
      expect(outcome, ChannelLaunchOutcome.failed);
    });
  });
}

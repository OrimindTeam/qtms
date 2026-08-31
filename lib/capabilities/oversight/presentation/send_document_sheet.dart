/// ★★★ ورقة الإرسال والتصدير — `M20` (`WU-010`).
///
/// ★ **نمط الشاشة: ورقة سفلية** (`ui-guidelines.md` §3 نمط 4 · §4:
/// «**المهام القصيرة: ورقة سفلية بدل شاشة كاملة**»).
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **المبدأ الحاكم — يفتح المحادثة ولا يُرسِل** (`FR-M20` §1):
/// ★ **المستخدم هو من يضغط زر الإرسال داخل واتساب/الرسائل** — ⟵ **والنظام
/// لا يعرف إن وصلت**، ⛔ **ولا يُسجَّل أي أثر للإرسال إطلاقاً**
/// (`FR-M20-15` · `AT-64`).
///
/// ⚠️ **والتصدير فعلٌ آخر يُسجَّل** (`FR-M19-04`) — ★ **وهما لا يُخلطان.**
/// ═══════════════════════════════════════════════════════════════════════
///
/// ⚠️⚠️ **وكل إخفاءٍ هنا عرضٌ لا حماية** (`RISK-02`): ★ **`messagingSend`
/// تُخفي زرَّي الإرسال** — ⛔ **ولا حارسَ لهما في السحابة أصلاً لأنهما لا
/// يكتبان شيئاً** · ★ **و`documentExport` تُخفي زرَّ التصدير**، **والحارس
/// الحقيقي في `logExport`** (`ADR-0013` القاعدة 3).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qtms_domain/qtms_domain.dart';

import '../../../core/design/design_tokens.dart';
import '../../../core/ui/sticky_action_bar.dart';
import '../../identity_access/application/session_providers.dart';
import '../application/document_export_action.dart';
import '../application/messaging_providers.dart';
import '../infrastructure/message_channel_launcher.dart';

/// ★★ حدُّ الرسالة النصية الواحدة بالترميز العربي — **`UCS-2` = 70 محرفاً**.
///
/// ⛔★ **وليست قيمةً مخترَعة:** ★ **معيار `GSM 03.38` يجعل الرسالة الواحدة
/// 160 محرفاً بالترميز اللاتيني و70 بـ`UCS-2`** — ⟵ **والعربية `UCS-2`
/// دائماً.** ★ **و`FR-M20-13` يشترط التنبيه «إذا تجاوز النص عدة رسائل»**،
/// ⛔ **ولا يذكر رقماً** — ★ **فالرقم من المعيار لا من التقدير.**
const int smsSingleMessageLength = 70;

/// ★ ما يمكن إرساله أو تصديره — **تبنيه الشاشةُ المالكة للبيانات**.
///
/// ⛔⛔★★ **ولا تحسب الورقةُ شيئاً منه** (`design-system.md` §5.1): ★ **النصوص
/// تصلها جاهزةً من طبقة النطاق**، ⟵ **فالرسالةُ والملفُّ يخرجان من مصدرٍ
/// واحد** ⛔ **ولا يفترقان رقماً واحداً** (معيار قبول `WU-010`).
@immutable
final class SendableDocument {
  /// ينشئ الوصف.
  const SendableDocument({
    required this.title,
    required this.renderMessage,
    required this.renderShortMessage,
    required this.buildExport,
    required this.phone,
    required this.offersTemplateChoice,
    required this.pricedTemplateAvailable,
  });

  /// عنوان الورقة — «إرسال التوزيعة» · «إرسال سند القبض».
  final String title;

  /// نصُّ الرسالة الكاملة للقالب المختار.
  final String Function(MessageTemplate template) renderMessage;

  /// ★ النسخة المختصرة — **الإجمالي والرصيد فقط** (`FR-M20-13`).
  ///
  /// ⛔ **و`null` لمستندٍ لا نسخةَ مختصرة له** — ★ **فلا يُعرَض الخيار.**
  final String Function()? renderShortMessage;

  /// المستند المُصدَّر للقالب المختار.
  final ExportableDocument Function(MessageTemplate template) buildExport;

  /// رقم المستلِم — ⛔ **و`null` تُخفي زرَّي الإرسال** (`FR-M20-02`).
  final String? phone;

  /// ★★ **هل كل السطور مسعَّرة؟** — `FR-M20-03` · `AT-63`.
  ///
  /// ⛔ **وحين تكون `false` يبقى خيار «مع التسعير» معروضاً معطَّلاً** — ★ **لا
  /// مخفياً**: ⟵ **فيعرف المستخدم أن الخيار موجودٌ وسببَ تعذّره**،
  /// ⛔ **ولا يظنّه غير موجودٍ في النظام** (نفس منطق شجرة الصلاحيات).
  final bool pricedTemplateAvailable;

  /// ★ هل تُعرَض قائمةُ القوالب؟
  ///
  /// ★ **قالبٌ واحد للسندات** — ⟵ **فلا يُعرَض اختيارٌ من واحد** (§5 من
  /// `messaging-design.md`: **الخياران للتوزيع وحده**).
  final bool offersTemplateChoice;
}

/// ★★★ يفتح ورقة الإرسال والتصدير.
Future<void> showQtmsSendSheet(
  BuildContext context, {
  required SendableDocument document,
}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: SemanticColors.surface,
      builder: (BuildContext sheetContext) =>
          _SendSheet(document: document),
    );

class _SendSheet extends ConsumerStatefulWidget {
  const _SendSheet({required this.document});

  final SendableDocument document;

  @override
  ConsumerState<_SendSheet> createState() => _SendSheetState();
}

class _SendSheetState extends ConsumerState<_SendSheet> {
  /// ★ القالب المختار — **«التوزيع فقط» افتراضاً** (`messaging-design.md` §5).
  MessageTemplate _template = MessageTemplate.distributionOnly;

  /// ★ إرسال النسخة المختصرة — `FR-M20-13`.
  bool _short = false;

  /// نصُّ الحالة المعروض داخل الورقة — ⛔ **ولا تُغلَق على رفضٍ لا يراه أحد.**
  String? _status;

  /// ★ نجاحٌ لا رفض — ⟵ **فاللون واللفظ يتبعان المعنى.**
  bool _statusIsSuccess = false;

  bool _busy = false;

  SendableDocument get _document => widget.document;

  String get _message => _short && _document.renderShortMessage != null
      ? _document.renderShortMessage!()
      : _document.renderMessage(_template);

  @override
  Widget build(BuildContext context) {
    final bool canSend =
        ref.watch(hasPermissionProvider(Permission.messagingSend));
    final bool canExport =
        ref.watch(hasPermissionProvider(Permission.documentExport));
    final bool hasPhone = (_document.phone ?? '').trim().isNotEmpty;
    final bool longForSms = _message.length > smsSingleMessageLength;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.all(Spacing.screenPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(_document.title, style: TypeScale.titleLg),
            const SizedBox(height: Spacing.space16),
            // ① ★★ اختيار القالب — **للتوزيع وحده** (`FR-M20-03`).
            if (_document.offersTemplateChoice) ...<Widget>[
              _TemplateChoice(
                selected: _template,
                pricedAvailable: _document.pricedTemplateAvailable,
                onChanged: (MessageTemplate value) =>
                    setState(() => _template = value),
              ),
              const SizedBox(height: Spacing.space16),
            ],
            // ② معاينة النصّ — ★ **ما سيصل المقوت حرفياً.**
            _MessagePreview(text: _message),
            // ③ ★ تنبيه طول الرسالة **مع خيار النسخة المختصرة** (`FR-M20-13`).
            if (longForSms && _document.renderShortMessage != null) ...<Widget>[
              const SizedBox(height: Spacing.space12),
              SwitchListTile.adaptive(
                value: _short,
                onChanged: (bool value) => setState(() => _short = value),
                title: const Text('إرسال نسخة مختصرة'),
                subtitle: const Text(
                  'النص يتجاوز رسالة واحدة — والمختصرة تحمل الإجمالي والرصيد فقط.',
                ),
              ),
            ],
            const SizedBox(height: Spacing.space16),
            // ④ ⛔ **لا رقم ⟵ لا زرَّي إرسال** (`FR-M20-02`).
            if (canSend && !hasPhone)
              QtmsActionStatus.rejection(
                'لا يمكن الإرسال — لا يوجد رقم هاتف صحيح لهذا المستلم.',
              ),
            if (canSend && hasPhone) ...<Widget>[
              FilledButton.icon(
                onPressed: _busy
                    ? null
                    : () => _open(MessageChannel.whatsapp),
                icon: const Icon(Icons.chat_outlined),
                label: const Text('فتح واتساب'),
              ),
              const SizedBox(height: Spacing.space8),
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _open(MessageChannel.sms),
                icon: const Icon(Icons.sms_outlined),
                label: const Text('فتح الرسائل'),
              ),
            ],
            // ⑤ ★ التصدير — **صلاحيةٌ مستقلة** (`documentExport` · `IQ-032`).
            if (canExport) ...<Widget>[
              const SizedBox(height: Spacing.space8),
              OutlinedButton.icon(
                onPressed: _busy ? null : _export,
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('تصدير ملف ومشاركته'),
              ),
            ],
            if (_status case final String message) ...<Widget>[
              const SizedBox(height: Spacing.space12),
              if (_statusIsSuccess)
                QtmsActionStatus.success(message)
              else
                QtmsActionStatus.rejection(message),
            ],
            const SizedBox(height: Spacing.space8),
            TextButton(
              onPressed: _busy ? null : () => Navigator.of(context).pop(),
              child: const Text('إغلاق'),
            ),
          ],
        ),
      ),
    );
  }

  /// ★ يفتح القناة — ⛔ **ولا يُرسِل ولا يُسجِّل** (`FR-M20-15`).
  Future<void> _open(MessageChannel channel) async {
    setState(() {
      _busy = true;
      _status = null;
    });
    final ChannelLaunchOutcome outcome =
        await ref.read(messageChannelProvider).open(
              channel: channel,
              phone: _document.phone ?? '',
              message: _message,
            );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _statusIsSuccess = outcome == ChannelLaunchOutcome.opened;
      _status = switch (outcome) {
        // ★ **ولا رسالةَ نجاحٍ تُوهم بالوصول** — ⟵ **«فُتحت» لا «أُرسلت»**:
        //   ⛔ **والنظام لا يعرف إن وصلت** (`messaging-design.md` §2).
        ChannelLaunchOutcome.opened => 'فُتحت المحادثة — أرسل الرسالة من هناك.',
        // `FR-M20-12` — ★ **واقتراحُ البديل جزءٌ من نصّ المتطلب.**
        ChannelLaunchOutcome.channelUnavailable =>
          channel == MessageChannel.whatsapp
              ? 'تطبيق واتساب غير مثبَّت على الجهاز — جرّب الإرسال عبر رسالة نصية.'
              : 'تطبيق الرسائل غير متاح على هذا الجهاز.',
        ChannelLaunchOutcome.noPhone =>
          'لا يمكن الإرسال — لا يوجد رقم هاتف صحيح لهذا المستلم.',
        ChannelLaunchOutcome.failed => 'تعذّر فتح المحادثة. أعد المحاولة.',
      };
    });
  }

  /// ★★ يُصدِّر الملف ويشاركه **ثم يُسجِّل** — `FR-M19-04` · `FR-M20-14`.
  ///
  /// ⛔⛔★★ **والترتيب مقصود:** ★ **الملف يصل المستخدم أولاً**، ⟵ **ورفضُ
  /// التسجيل يُعرَض ولا يُلغي مخرَجاً صار بيده أصلاً** — ★ **ولا يُبتلَع.**
  Future<void> _export() async {
    setState(() {
      _busy = true;
      _status = null;
    });
    // ★★ **والتسلسلُ في إجراءٍ واحدٍ يشاركه كل مُصدِّر** — ⛔ **ولا نسخةَ
    //    ثانية منه في شاشة التقارير** (`document_export_action.dart`).
    final DocumentExportResult result = await runDocumentExport(
      document: _document.buildExport(_template),
      renderer: ref.read(pdfRendererProvider),
      sharer: ref.read(documentShareProvider),
      exportLog: ref.read(exportLogRepositoryProvider),
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _statusIsSuccess = result.isSuccess;
      _status = result.message;
    });
  }
}

/// ★ اختيار القالب — **خياران لا أكثر** (`FR-M20-07` ① و②).
class _TemplateChoice extends StatelessWidget {
  const _TemplateChoice({
    required this.selected,
    required this.pricedAvailable,
    required this.onChanged,
  });

  final MessageTemplate selected;
  final bool pricedAvailable;
  final ValueChanged<MessageTemplate> onChanged;

  @override
  Widget build(BuildContext context) => RadioGroup<MessageTemplate>(
        groupValue: selected,
        onChanged: (MessageTemplate? value) {
          if (value != null) onChanged(value);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const RadioListTile<MessageTemplate>(
              value: MessageTemplate.distributionOnly,
              title: Text('التوزيع فقط'),
            ),
            RadioListTile<MessageTemplate>(
              value: MessageTemplate.distributionWithPricing,
              // ⛔⛔★★ **معطَّلٌ ما لم تكن كل السطور مسعَّرة** — `AT-63`.
              //    ★ **ويبقى معروضاً** ⛔ **لا مخفياً**: ⟵ **فيعرف المستخدم
              //    أن الخيار موجودٌ وسببَ تعذّره.**
              enabled: pricedAvailable,
              title: const Text('التوزيع مع التسعير'),
              subtitle: pricedAvailable
                  ? null
                  // ★ **وسببُ التعطيل مكتوب** — ⟵ **فلا يظنّه المستخدم عطلاً.**
                  : const Text('يتطلب أن تكون كل السطور مسعَّرة.'),
            ),
          ],
        ),
      );
}

/// ★ معاينة النصّ — **ما سيصل المستلِم حرفياً** ⛔ **لا ملخّصٌ عنه.**
class _MessagePreview extends StatelessWidget {
  const _MessagePreview({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsetsDirectional.all(Spacing.cardPadding),
        decoration: BoxDecoration(
          color: SemanticColors.surfaceSunken,
          borderRadius: BorderRadius.circular(Radii.card),
        ),
        child: Text(
          text,
          style: TypeScale.bodyMd.copyWith(color: SemanticColors.textPrimary),
        ),
      );
}

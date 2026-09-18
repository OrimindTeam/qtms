/// شاشة الإعداد التأسيسي — **إلزامية لا تُتخطّى** (`FR-M21-04`).
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⚠️⚠️⚠️ **أخطر نموذج في النظام كله — والسبب أنه لا رجعة فيه:**
/// `FR-M21-03`: «يُسمح بإنشاء البندين **مرة واحدة فقط ومن المالك حصراً**،
/// **والتعديل والحذف مرفوضان نهائياً لكل المستخدمين بمن فيهم المالك**».
/// ⟵ ★ **ولذلك تحذيرٌ صريح قبل الحفظ النهائي** (`FR-M21-04`)، ⛔ **ولا زر
/// «تخطّي».**
///
/// ★★ **ومعه يُنشأ النوع الافتراضي «السكرب»** في المعاملة نفسها — حسم
/// `IQ-012` (الخيار أ): «**إنشاء النوع مسؤولية `M21` لا التهيئة**».
/// ═══════════════════════════════════════════════════════════════════════
///
/// ⛔ **ولا مفتاح ثالث في الإعدادات** (`FR-M21-05`)، ★ **ولا منطق تشغيلي
/// أو أمني يقرأ منها** (`FR-M21-06`) — ⟵ **فلا يمكن تعطيل أي حماية بتعديل
/// إعداد.**
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qtms_domain/qtms_domain.dart';

import '../../../app/top_bar.dart';

import '../../../core/design/design_tokens.dart';
import '../../../core/messages/error_messages.dart';
import '../../../core/ui/inline_banner.dart';
import '../application/master_data_providers.dart';
import 'master_data_widgets.dart';

/// ★ نصُّ زرّ الحفظ — ⛔ **ولا نصٌّ محفورٌ في موضعين.**
const String firstRunSetupSaveLabel = 'حفظ الإعداد نهائياً';

/// ★ نصُّ الزر أثناء النداء — `design-system.md` §6-ي البند ②.
const String firstRunSetupSavingLabel = 'جارٍ الحفظ…';

/// ★★ **نصُّ نجاح الحفظ** — `AM-018`.
const String firstRunSetupSavedMessage = 'تم حفظ إعداد المنشأة';

/// شاشة الإعداد التأسيسي.
class FirstRunSetupScreen extends ConsumerStatefulWidget {
  /// ينشئ الشاشة.
  const FirstRunSetupScreen({super.key});

  @override
  ConsumerState<FirstRunSetupScreen> createState() =>
      _FirstRunSetupScreenState();
}

class _FirstRunSetupScreenState extends ConsumerState<FirstRunSetupScreen> {
  final TextEditingController _businessName = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _address = TextEditingController();
  // ★ **الريال اليمني** — `A-02` · `FR-M21-02`. ★ **قيمة مبدئية قابلة
  //   للتعديل** ⛔ لا محفورة، فالحقل من البندين المُقفلَين بعد الحفظ.
  final TextEditingController _currency = TextEditingController(text: 'ر.ي');
  final TextEditingController _separator = TextEditingController(text: ',');

  /// ★★ **إقرار الفهم قبل الحفظ** — `FR-M21-04` («تحذير صريح قبل الحفظ»).
  ///
  /// ⛔ **وليس زخرفة:** الحفظ **لا رجعة فيه**، ⟵ **وضغطةٌ عابرة على زر
  /// الحفظ تُقفل بيانات المنشأة على خطأ إملائي إلى الأبد** — وتصحيحُه
  /// **يتطلب تدخّل المالك على مستوى المشروع السحابي** (`FR-M21-07`).
  bool _acknowledged = false;

  /// ★★ **نصُّ الرفض — يُسمّي حقلَه** (`AM-018`) ⛔ **لا رسالةٌ عامة.**
  String? _rejection;

  /// ★ شريطُ النجاح — ⛔ **ولا شاشةٌ تختفي فجأةً بلا خبر.**
  bool _saved = false;

  bool _submitting = false;

  @override
  void dispose() {
    _businessName.dispose();
    _phone.dispose();
    _address.dispose();
    _currency.dispose();
    _separator.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        // ⛔★★ **ولا زر رجوع ولا تخطٍّ** — `FR-M21-04`: «شاشة إلزامية لا
        //    يمكن تخطّيها». ★ **والشاشة خارج الصدَفة أصلاً فلا مسارَ يُرجَع
        //    إليه**، ⟵ **فلا `leading` يُبنى لها.**
        appBar: const QtmsTopBar(screenTitle: 'الإعداد التأسيسي'),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Spacing.space16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const _OnceOnlyWarning(),
                const SizedBox(height: Spacing.space24),
                Text('بيانات المنشأة', style: TypeScale.titleSm),
                // ★ **فاصلٌ تحت عنوان القسم** — `AM-018`: ⟵ **مطابقٌ لشاشة
                //   الإعدادات** (`ui-guidelines.md` نمط 7)، ⛔ **ولا قسمٌ
                //   بعنوانٍ عائمٍ بلا حدٍّ يفصله عمّا قبله.**
                const SizedBox(height: Spacing.space8),
                const Divider(height: Sizes.borderWidth),
                const SizedBox(height: Spacing.space12),
                MasterDataField(
                  controller: _businessName,
                  label: 'اسم المحل',
                  autofocus: true,
                ),
                const SizedBox(height: Spacing.space12),
                MasterDataField(
                  controller: _phone,
                  label: 'الهاتف (اختياري)',
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: Spacing.space12),
                MasterDataField(
                  controller: _address,
                  label: 'العنوان (اختياري)',
                ),
                const SizedBox(height: Spacing.space24),
                Text('العملة والأرقام', style: TypeScale.titleSm),
                const SizedBox(height: Spacing.space8),
                const Divider(height: Sizes.borderWidth),
                const SizedBox(height: Spacing.space12),
                MasterDataField(controller: _currency, label: 'رمز العملة'),
                const SizedBox(height: Spacing.space12),
                MasterDataField(
                  controller: _separator,
                  label: 'فاصل الآلاف',
                ),
                const SizedBox(height: Spacing.space8),
                Text(
                  // ★★ `ADR-0015` — ⛔ **ولا حقل لعدد الخانات العشرية**:
                  //   كل مبلغ **عدد صحيح بالريال**، ⟵ **فحقلٌ يَعِد بغير
                  //   الصفر يَعِد بعرضٍ لا يقابله تخزين.**
                  'المبالغ أعداد صحيحة بالريال — بلا كسور عشرية.',
                  style: TypeScale.bodyMd
                      .copyWith(color: SemanticColors.textSecondary),
                ),
                const SizedBox(height: Spacing.space24),
                CheckboxListTile(
                  value: _acknowledged,
                  onChanged: (bool? on) =>
                      setState(() => _acknowledged = on ?? false),
                  title: const Text(
                    'أفهم أن هذه القيم تُحفظ مرة واحدة ولا يمكن تغييرها لاحقاً.',
                  ),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                // ⛔⛔★★★ **والرفضُ يُسمّي حقلَه** — `AM-018` ·
                //    `master-data-design.md` §1: ⟵ **والشاشةُ لا رجعةَ فيها**
                //    (`FR-M21-03`)، ★ **فمن رُئي له «تعذّر تنفيذ العملية»
                //    أمام خمسةِ حقولٍ لا يعرف أيَّها يُصحِّح** ⛔ **فيعبث
                //    بالصحيح ويترك المعيب.**
                if (_rejection case final String message) ...<Widget>[
                  const SizedBox(height: Spacing.space12),
                  QtmsInlineBanner(
                    text: message,
                    triad: SemanticTriads.danger,
                  ),
                ],
                // ★★ **ونجاحٌ يُرى قبل خروج الشاشة** — ⛔ **ولا اختفاءٌ فجائي.**
                if (_saved) ...<Widget>[
                  const SizedBox(height: Spacing.space12),
                  const QtmsInlineBanner(
                    text: firstRunSetupSavedMessage,
                    triad: SemanticTriads.success,
                  ),
                ],
                const SizedBox(height: Spacing.space16),
                // ★★ **زرٌّ ثنائي الحالة** — `design-system.md` §6-ي:
                //    ★ **نصٌّ بديلٌ أثناء النداء** ⛔ **لا تعطيلٌ صامت.**
                FilledButton(
                  // ⛔ **الحفظ معطَّل حتى يُقرّ المستخدم صراحةً.**
                  onPressed:
                      (_submitting || !_acknowledged) ? null : _submit,
                  child: Text(
                    _submitting
                        ? firstRunSetupSavingLabel
                        : firstRunSetupSaveLabel,
                  ),
                ),
                const SizedBox(height: Spacing.space12),
                Text(
                  // ⚙️ `IQ-012` — أثرٌ يجب أن يعرفه المالك قبل الحفظ.
                  'يُنشأ مع الإعداد نوع «السكرب» الافتراضي — وزني بالكيلوجرام، '
                  'ولا يُعدَّل ولا يُحذف.',
                  style: TypeScale.bodyMd
                      .copyWith(color: SemanticColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );

  Future<void> _submit() async {
    final Outcome<ValidatedAppSettings> validated = validateAppSettings(
      AppSettingsInput(
        businessName: _businessName.text,
        currencySymbol: _currency.text,
        phone: _phone.text,
        address: _address.text,
        thousandsSeparator: _separator.text,
      ),
    );
    if (validated case Failure<ValidatedAppSettings>(:final AppError error)) {
      setState(() {
        _saved = false;
        _rejection = _rejectionText(error);
      });
      return;
    }

    setState(() {
      _submitting = true;
      _rejection = null;
      _saved = false;
    });

    final Outcome<void> result = await ref
        .read(masterDataAdminProvider)
        .writeAppSettings((validated as Success<ValidatedAppSettings>).value);

    if (!mounted) return;
    switch (result) {
      case Failure<void>(:final AppError error):
        setState(() {
          _submitting = false;
          _rejection = catalogText(appErrorMessage(error));
        });
      case Success<void>():
        // ★★ **وشريطُ النجاح يُعرَض ثم تُترَك مهلةٌ قصيرةٌ ليُقرأ** —
        //   `AM-018`: ⟵ **والشاشةُ كانت تختفي فجأةً فلا يعلم المستخدم
        //   أنجح الحفظُ أم انهار شيء.**
        //
        // ⛔⛔★★ **ولا ملاحةَ يدوية** — ★ **التدفّق حيّ والموجّه يُخرج
        //   الشاشة من تلقائه** (`router.dart`): ⟵ **وملاحةٌ هنا تتسابق معه.**
        setState(() {
          _submitting = false;
          _saved = true;
        });
        // ★ **والمدّةُ من التوكنز** — ⛔ **ولا رقمٌ في شاشة** (§9).
        await Future<void>.delayed(Motion.confirmDwell);
    }
  }

  /// ★ يترجم رفضَ طبقة النطاق إلى نصّه — ⛔ **ولا تُصاغ قاعدةٌ في الشاشة**
  /// (`ADR-0010` القاعدة 1) ⛔ **ولا رمزٌ تقنيٌّ يُعرَض للمستخدم**
  /// (`error-handling-strategy.md` §3 القاعدة 2).
  static String _rejectionText(AppError error) {
    final AppSettingsRejection? reason = error is ValidationError
        ? appSettingsRejectionOf(error.ruleCode)
        : null;
    return switch (reason) {
      AppSettingsRejection.businessName =>
        '❌ اسم المحل مطلوب — ولا يقلّ عن $sourceNameMinLength أحرف.',
      AppSettingsRejection.currencySymbol =>
        '❌ رمز العملة مطلوب — ولا يزيد عن ثمانية محارف.',
      AppSettingsRejection.thousandsSeparator =>
        '❌ فاصل الآلاف محرف واحد على الأكثر — واتركه فارغاً إن لم ترده.',
      AppSettingsRejection.address => '❌ العنوان أطول من الحدّ المسموح.',
      AppSettingsRejection.logo => '❌ مسار الشعار أطول من الحدّ المسموح.',
      null => catalogText(appErrorMessage(error)),
    };
  }
}

/// ★★ التحذير الصريح قبل الحفظ — `FR-M21-04`.
class _OnceOnlyWarning extends StatelessWidget {
  const _OnceOnlyWarning();

  @override
  Widget build(BuildContext context) => const QtmsInlineBanner(
        text: 'هذه القيم تُحفظ مرة واحدة ولا يمكن تغييرها لاحقاً. '
            'تصحيح أي خطأ بعد الحفظ يتطلب تدخّلاً على مستوى المشروع السحابي.',
        triad: SemanticTriads.warning,
      );
}

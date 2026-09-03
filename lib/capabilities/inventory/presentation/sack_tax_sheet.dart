/// ★★★ **ورقةُ إدخال ضريبة الكيلو** — `FR-M7-10` · `FR-M7-11` · **نمط 4**
/// (`ui-guidelines.md` §3: **ورقة سفلية لما هو ≤ 8 حقول**).
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **ولماذا تُبنى هنا لا في `WU-004`:** ★ **`enterSackTax` عمليةٌ
/// سحابية منذ `WU-004`** — ⛔ **ولا واجهةَ لها قطّ**، ⟵ **فبقيت غير مُختبَرةٍ
/// حيّاً** (`CLAUDE.md` — أثرا `WU-004` المعلَنان). ★ **ونطاقُ `WU-015`
/// يشمل «**وضريبة الجونية**» نصّاً** (`implementation-plan.md`)، ⟵ **وهي
/// المدخَلُ الذي بلا صافي الرعوي لا يُحتسب أصلاً** (`FR-M14-04`).
///
/// ⛔⛔★★ **والمسارُ مقيَّدٌ بحقلٍ واحد** — `FR-M7-27` · الكتالوج §2.2:
/// **`taxPerKilo` وحده** ⛔ **ولا يمسّ وزناً ولا اسماً ولا سطراً**:
/// ⟵ **فمن يُدخل الضريبة لا يُلزَم بصلاحية إدخال الأنواع.**
///
/// ★★ **والمعروضُ حيّاً ناتجُ دالة النطاق نفسِها** (`sackTax`) — **الموضع ①
/// للتقريب** (`design-overview.md` §2.11): ⟵ **فما يراه المستخدم قبل الحفظ
/// هو ما تكتبه السحابة بعده حرفياً**، ⛔ **لا تقديرٌ في شاشة.**
/// ═══════════════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qtms_domain/qtms_domain.dart';

import '../../../core/design/design_tokens.dart';
import '../../../core/messages/error_messages.dart';
import '../../../core/ui/inline_banner.dart';
import '../../../core/ui/optional_reason.dart';
import '../application/inventory_providers.dart';

/// يفتح **ورقة ضريبة الكيلو**.
Future<void> showSackTaxSheet(
  BuildContext context, {
  required SackCard sack,
  Money? currentTaxPerKilo,
}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: SemanticColors.surface,
      builder: (BuildContext context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SackTaxSheet(sack: sack, currentTaxPerKilo: currentTaxPerKilo),
      ),
    );

/// ورقةُ إدخال ضريبة الكيلو.
class SackTaxSheet extends ConsumerStatefulWidget {
  /// ينشئ الورقة.
  const SackTaxSheet({required this.sack, this.currentTaxPerKilo, super.key});

  /// الجونية.
  final SackCard sack;

  /// 🔵 القيمة المخزَّنة أو `null` **إن كانت معلّقة** (`FR-M7-10`).
  final Money? currentTaxPerKilo;

  @override
  ConsumerState<SackTaxSheet> createState() => _SackTaxSheetState();
}

class _SackTaxSheetState extends ConsumerState<SackTaxSheet> {
  late final TextEditingController _tax = TextEditingController(
    text: widget.currentTaxPerKilo?.riyals.toString() ?? '',
  );
  final TextEditingController _reason = TextEditingController();
  bool _submitting = false;
  String? _rejection;

  @override
  void dispose() {
    _tax.dispose();
    _reason.dispose();
    super.dispose();
  }

  /// ★ القيمة المُدخَلة أو `null` — ⛔ **والكسر يُرفض ولا يُقرَّب** (`ADR-0015`).
  Money? get _value => Money.tryParseInput(_tax.text);

  @override
  Widget build(BuildContext context) {
    final Money? entered = _value;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.space16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'ضريبة الكيلو — ${widget.sack.displayName}',
              style: TypeScale.titleMd,
            ),
            const SizedBox(height: Spacing.space12),
            TextField(
              controller: _tax,
              keyboardType: TextInputType.number,
              // ⛔★★ **ولا فاصلةَ ولا إشارة** — ★ **المبلغ عددٌ صحيح موجب**
              //   (`ADR-0015`): ⟵ **والمنعُ في لوحة المفاتيح قبل الرسالة.**
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
              ],
              decoration: const InputDecoration(
                labelText: 'قيمة ضريبة الكيلو',
                suffixText: 'ريال',
              ),
              onChanged: (String _) => setState(() => _rejection = null),
            ),
            const SizedBox(height: Spacing.space12),
            // ★★ **المعاينة الحيّة بدالة النطاق** — راجع ترويسة الملف.
            QtmsInlineBanner(
              triad: SemanticTriads.info,
              text: entered == null
                  ? 'ضريبة الجونية = قيمة ضريبة الكيلو × الوزن الكلي '
                      '(${widget.sack.weights.totalWeight.formatted()} كجم).'
                  : 'ضريبة الجونية = '
                      '${sackTax(taxPerKilo: entered, totalWeight: widget.sack.weights.totalWeight).riyals}'
                      ' ريال — على الوزن الكلي لا المطالب به.',
            ),
            const SizedBox(height: Spacing.space12),
            TextField(
              controller: _reason,
              // ★★ **والسبب اختياريٌّ ويُوسَم صراحةً** (`ADR-0020`).
              decoration: const InputDecoration(
                labelText: 'سبب التعديل (اختياري)',
              ),
            ),
            if (_rejection case final String message) ...<Widget>[
              const SizedBox(height: Spacing.space12),
              QtmsInlineBanner(text: message, triad: SemanticTriads.danger),
            ],
            const SizedBox(height: Spacing.space16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                // ⛔ **ولا حفظَ أثناء الإرسال ولا بقيمةٍ غير صالحة** —
                //   `ui-guidelines.md` §3 نمط 4.
                onPressed: _submitting || entered == null ? null : _submit,
                child: Text(_submitting ? 'جارٍ الحفظ…' : 'حفظ الضريبة'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final Money? entered = _value;
    if (entered == null) return;
    setState(() {
      _submitting = true;
      _rejection = null;
    });

    final Outcome<void> result = await ref.read(sackAdminProvider).enterSackTax(
          documentNumber: widget.sack.documentNumber,
          sourceId: widget.sack.sourceId,
          taxPerKilo: entered,
          // ⛔⛔ **وما تركه المستخدم فارغاً يُرسَل غياباً** — `ADR-0020`.
          amendReason: blankToNull(_reason.text),
        );

    if (!mounted) return;
    switch (result) {
      case Success<void>():
        Navigator.of(context).pop();
      case Failure<void>(:final AppError error):
        setState(() {
          _submitting = false;
          _rejection = catalogText(appErrorMessage(error));
        });
    }
  }
}

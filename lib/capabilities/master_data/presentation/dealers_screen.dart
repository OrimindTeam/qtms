/// شاشة المقاوته — **نمط 2** `ui-guidelines.md` §3.
///
/// ⛔★★ **ولا حقل مصدر في نموذج المقوت إطلاقاً** — `FR-M4-04` نصّاً، ★
/// **وحساباته سجلات مستقلة** مفتاحها `{dealerId}_{sourceId}`، ⟵ **وإضافة
/// حقل مصدر هنا خطأ بنيوي يهدم `ADR-0005`** (`master-data-design.md` §7).
///
/// ★★ **وتعطيل مقوتٍ له رصيد يشترط إقراراً نصّياً مكتوباً** (`FR-M4-09` ·
/// `E-39`) — ⚠️⚠️ **والرصيد يُقاس في السحابة داخل المعاملة** ⛔ **لا في
/// الجهاز**، ⟵ **فالإقرار يُرسَل والقرار هناك.**
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qtms_domain/qtms_domain.dart';

import '../../../app/router.dart';
import '../../../app/top_bar.dart';

import '../../../core/design/design_tokens.dart';
import '../../../core/ui/entity_tile.dart';
import '../../../core/messages/error_messages.dart';
import '../../identity_access/presentation/permission_gate.dart';
import '../../oversight/presentation/audit_trail_view.dart';
import '../../sales_receivables/application/dealer_statement_providers.dart';
import '../application/master_data_providers.dart';
import '../infrastructure/contact_picker.dart';
import 'master_data_widgets.dart';
import '../../../core/ui/optional_reason.dart';

/// قائمة المقاوته.
class DealersScreen extends ConsumerWidget {
  /// ينشئ الشاشة.
  const DealersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<DealerCard>> dealers = ref.watch(dealersProvider);

    return Scaffold(
      appBar: QtmsTopBar(screenTitle: 'المقاوته'),
      floatingActionButton: const PermissionGate(
        permission: Permission.dealerWrite,
        child: _NewDealerButton(),
      ),
      body: MasterDataAsyncView<DealerCard>(
        value: dealers,
        emptyIcon: Icons.handshake_outlined,
        emptyTitle: 'لا يوجد مقاوته بعد',
        emptyLabel: 'أضف أول مقوت لتتمكّن من التوزيع عليه ومتابعة ذمته.',
        builder: (List<DealerCard> items) => EntityList(
          itemCount: items.length,
          itemBuilder: (BuildContext context, int index) =>
              _DealerTile(dealer: items[index]),
        ),
      ),
    );
  }
}

class _NewDealerButton extends StatelessWidget {
  const _NewDealerButton();

  @override
  Widget build(BuildContext context) => FloatingActionButton.extended(
        onPressed: () => showDealerForm(context),
        icon: const Icon(Icons.person_add_alt_outlined),
        label: const Text('مقوت جديد'),
      );
}

class _DealerTile extends ConsumerWidget {
  const _DealerTile({required this.dealer});

  final DealerCard dealer;

  @override
  Widget build(BuildContext context, WidgetRef ref) => MasterDataTile(
        // ⛔⛔★★★ **الإجراء في صفّ الاسم نفسِه** — `AM-008` ⑥.
        actionsPlacement: EntityActionsPlacement.inline,
        title: dealer.name,
        // ★★ **أيقونة 🕘 في أول الصفّ** — `FR-M18-10` · `FR-M18-11`.
        leading: auditTrailLeading(
          ref,
          entityType: dealerEntityType,
          entityId: dealer.dealerId,
          title: dealer.name,
        ),
        // ⛔ **ولا رصيد هنا:** «عرض أرصدة المقاوته» صلاحية مستقلة وبياناتها
        //    تُبنى في `WU-006`/`WU-007` — ★ **ولا تُدَّعى موجودة.**
        subtitle: dealer.phone,
        badges: <Widget>[
          if (!dealer.isActive) const DisabledBadge(),
        ],
        actions: <Widget>[
          // ⛅★★★ **مدخلٌ مباشرٌ إلى كشف حسابه** — `AM-020` (**مراجعةُ تجربة
          //    الاستخدام** · `dealers_screen.md`): ⟵ **ويختصر خطوتين**
          //    (**فتحُ الكشف ثم اختيارُ المقوت من قائمةٍ منسدلة**) **إلى ضغطة.**
          //
          // ⛔⛔★★★ **ولا رصيدَ يُعرَض على هذه البطاقة** — ★ **البياناتُ
          //    المرجعيةُ لا تحمل رقماً مالياً** (`FR-M4` · ترويسةُ الملف):
          //    ⟵ **فالفجوةُ تُسَدّ بوجهةٍ لا بخلطِ الاهتمامين في بطاقةٍ واحدة.**
          //
          // ⛔⛔ **والمعرّفُ يُمرَّر حالةً في التطبيق لا معاملاً في المسار** —
          //    ★ **`dealerStatementRoute` يمنع ذلك بنصّه** (`router.dart`):
          //    ⟵ **ومسارٌ يحمل معرّفَ مقوتٍ يصير طريقاً ثانياً لقراءة ذمّةٍ
          //    بلا الشاشة التي تملك صلاحيتَه ونطاقَه.**
          //
          // ⚠️⚠️ **والبوابةُ مفتاحُ الشاشة نفسِه** (`dealerStatementView`) —
          //    ★ **كما في لوحة اليوم حرفياً** (`home_shell.dart`): ⟵ **فلا
          //    زرَّ يَعِد بوجهةٍ تُفتَح على رفض** (`RISK-02`).
          PermissionGate(
            permission: Permission.dealerStatementView,
            child: IconButton(
              onPressed: () {
                ref
                    .read(statementDealerProvider.notifier)
                    .select(dealer.dealerId);
                context.go(dealerStatementRoute);
              },
              icon: const Icon(Icons.receipt_long_outlined, size: Sizes.iconMd),
              tooltip: 'كشف الحساب',
              constraints: const BoxConstraints(
                minWidth: Sizes.minTouch,
                minHeight: Sizes.minTouch,
              ),
            ),
          ),
          PermissionGate(
            permission: Permission.dealerWrite,
            // ⛔⛔★★★ **وزرٌّ أيقونيٌّ في صفّ الاسم نفسِه** — `AM-008` ⑥:
            //    ★ **بدل صفٍّ مستقلٍّ بفاصلٍ شعريٍّ لزرٍّ واحد**، ⟵ **وكان
            //    يُطيل البطاقة نصفَ ارتفاعها بلا معلومة.**
            //
            // ⚠️★★ **والنصّ سقط من الزرّ لا من الواجهة:** ★ **يبقى في
            //    `tooltip` لقارئ الشاشة وللضغط المطوّل** — ⛔ **وإبقاؤه
            //    مرسوماً كان يعصر اسمَ الكيان عند تكبير الخط**، ★ **وهو
            //    عطلُ `DEBT-48` بعينه** (`context_header.dart`).
            //    ⛔ **وقاعدةُ «لا أيقونة صامتة» في §6.ج على الزرّ العائم**،
            //    ★ **وبطاقاتُ المستخدمين على هذا النهج منذ `WU-001`.**
            child: IconButton(
              onPressed: () => showDealerForm(context, existing: dealer),
              icon: const Icon(Icons.edit_outlined, size: Sizes.iconMd),
              tooltip: 'تعديل',
              constraints: const BoxConstraints(
                minWidth: Sizes.minTouch,
                minHeight: Sizes.minTouch,
              ),
            ),
          ),
        ],
      );
}

/// يفتح نموذج المقوت — و[existing] `null` تعني **إنشاءً**.
Future<void> showDealerForm(
  BuildContext context, {
  DealerCard? existing,
}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: SemanticColors.surface,
      builder: (BuildContext context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: DealerFormSheet(existing: existing),
      ),
    );

/// ورقة نموذج المقوت.
class DealerFormSheet extends ConsumerStatefulWidget {
  /// ينشئ الورقة.
  const DealerFormSheet({this.existing, super.key});

  /// المقوت المُعدَّل.
  final DealerCard? existing;

  @override
  ConsumerState<DealerFormSheet> createState() => _DealerFormSheetState();
}

class _DealerFormSheetState extends ConsumerState<DealerFormSheet> {
  late final TextEditingController _name =
      TextEditingController(text: widget.existing?.name ?? '');
  late final TextEditingController _phone =
      TextEditingController(text: widget.existing?.phone ?? '');
  late final TextEditingController _notes =
      TextEditingController(text: widget.existing?.notes ?? '');
  final TextEditingController _amendReason = TextEditingController();
  final TextEditingController _disableReason = TextEditingController();

  /// ★★ **إقرار تعطيل مقوت له رصيد** — `FR-M4-09` · `E-39`.
  final TextEditingController _balanceAck = TextEditingController();

  late bool _isActive = widget.existing?.isActive ?? true;

  CatalogMessage? _rejection;
  bool _submitting = false;

  /// ★ **تعذّرَ فتحُ مُنتقي جهات الاتصال** — `AM-020`.
  bool _pickerFailed = false;

  bool get _isEdit => widget.existing != null;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _notes.dispose();
    _amendReason.dispose();
    _disableReason.dispose();
    _balanceAck.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ContactPicker? picker = ref.watch(contactPickerProvider);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Spacing.space16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              _isEdit ? 'تعديل مقوت' : 'مقوت جديد',
              style: TypeScale.titleLg,
            ),
            const SizedBox(height: Spacing.space16),
            if (picker != null) ...<Widget>[
              OutlinedButton.icon(
                onPressed: () => _fillFromContacts(picker),
                icon: const Icon(Icons.contacts_outlined),
                label: const Text('جلب من جهات الاتصال'),
              ),
              // ⛔⛔★★★ **والتعذّرُ يُقال تحت زرِّه مباشرةً** (`AM-020`) —
              //    ★ **حيث وقع الفعل** ⛔ **لا في رسالةٍ عامةٍ أسفل الورقة.**
              if (_pickerFailed) ...<Widget>[
                const SizedBox(height: Spacing.space12),
                const ContactPickerFailureBanner(),
              ],
              const SizedBox(height: Spacing.space12),
            ],
            MasterDataField(
              controller: _name,
              label: 'اسم المقوت',
              autofocus: true,
            ),
            const SizedBox(height: Spacing.space12),
            MasterDataField(
              controller: _phone,
              label: 'رقم الهاتف',
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: Spacing.space12),
            MasterDataField(controller: _notes, label: 'ملاحظات (اختياري)'),
            // ⛔★★ **ولا حقل مصدر هنا** — `FR-M4-04`: «لا يُختار للمقوت مصدر
            //    عند إنشائه إطلاقاً» · **والحقل غير موجود**.
            if (_isEdit) ...<Widget>[
              const SizedBox(height: Spacing.space12),
              SwitchListTile(
                value: _isActive,
                onChanged: (bool on) => setState(() => _isActive = on),
                title: const Text('المقوت نشط'),
                subtitle: const Text(
                  'المعطَّل لا يظهر في التوزيع الجديد — ويظهر في المقبوضات.',
                ),
                contentPadding: EdgeInsets.zero,
              ),
              if (!_isActive) ...<Widget>[
                const SizedBox(height: Spacing.space12),
                MasterDataField(
                  controller: _disableReason,
                  label: 'سبب التعطيل',
                ),
                const SizedBox(height: Spacing.space12),
                // ★★ **الإقرار النصي** — ⚠️ **ويُطلَب دائماً عند التعطيل
                //   ولا يُخفى**: الرصيد **يُقاس في السحابة** لا هنا، ⟵
                //   **فإخفاؤه بناءً على ظنّ الجهاز يجعل الطلب يُرفَض بلا
                //   أن يعرف المستخدم ما ينقصه.**
                MasterDataField(
                  controller: _balanceAck,
                  label: 'إقرار التعطيل رغم الرصيد (إن وُجد رصيد)',
                ),
              ],
              const SizedBox(height: Spacing.space12),
              MasterDataField(controller: _amendReason, label: 'سبب التعديل (اختياري)'),
            ],
            if (_rejection != null) ...<Widget>[
              const SizedBox(height: Spacing.space12),
              RejectionBanner(message: _rejection!),
            ],
            const SizedBox(height: Spacing.space16),
            // ⛔⛔★★★ **والزرُّ يُعطَّل لغياب سبب التعطيل** (`AM-020`) —
            //    ★ **الدالةُ المشتركةُ نفسُها في النماذج الأربعة**
            //    (`design-system.md` §6-ط ④).
            MasterDataSubmitButton(
              label: _isEdit ? 'حفظ التعديل' : 'إنشاء',
              submitting: _submitting,
              requiresDisableReason: _isEdit && !_isActive,
              disableReason: _disableReason,
              onSubmit: _submit,
            ),
            if (!_isEdit) ...<Widget>[
              const SizedBox(height: Spacing.space12),
              Text(
                // ⚙️ `FR-M4-05` — أثرٌ يجب أن يعرفه المستخدم قبل الحفظ.
                'يُنشأ للمقوت تلقائياً حسابٌ في كل مصدر قائم، وفي كل مصدر '
                'يُضاف مستقبلاً.',
                style: TypeScale.bodyMd
                    .copyWith(color: SemanticColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// ⛔⛔★★★ **والتعذّرُ يُعرَض ولا يُبتلَع** (`AM-020`) — ★ **الاستثناءان
  /// يُلتقطان هنا** (`PlatformException` **لرفض الإذن أو غياب تطبيق جهات
  /// اتصال**، و`MissingPluginException` **لمنصّةٍ بلا تنفيذ**) ⟵ **فيُرفَع
  /// شريطُ تحذيرٍ يقول للمستخدم ما يفعل**: ⛔ **وزرٌّ يُضغَط بلا أثرٍ ولا
  /// رسالةٍ يترك المستخدمَ يظنّ التطبيقَ معطَّلاً.**
  Future<void> _fillFromContacts(ContactPicker picker) async {
    // ★ **ومحاولةٌ جديدة تمسح تحذيرَ السابقة** — ⟵ **فلا يبقى تحذيرٌ معلَّقاً
    //   بعد أن زال سببُه** (منحُ الإذن · تثبيتُ تطبيق جهات اتصال).
    if (_pickerFailed) setState(() => _pickerFailed = false);
    final PickedContact? contact;
    try {
      contact = await picker.pickOne();
    } on PlatformException {
      if (mounted) setState(() => _pickerFailed = true);
      return;
    } on MissingPluginException {
      if (mounted) setState(() => _pickerFailed = true);
      return;
    }
    if (contact == null || !mounted) return;
    setState(() {
      _pickerFailed = false;
      if (contact!.name.isNotEmpty) _name.text = contact.name;
      _phone.text = contact.phone;
    });
  }

  Future<void> _submit() async {
    final Outcome<ValidatedDealer> validated = validateDealer(
      DealerInput(
        name: _name.text,
        phone: _phone.text,
        notes: _notes.text,
        isActive: !_isEdit || _isActive,
        disableReason: _disableReason.text,
      ),
    );
    if (validated is Failure<ValidatedDealer>) {
      setState(() => _rejection = CatalogMessage.operationFailed);
      return;
    }
    final ValidatedDealer dealer = (validated as Success<ValidatedDealer>).value;

    setState(() {
      _submitting = true;
      _rejection = null;
    });

    final MasterDataAdminRepository admin = ref.read(masterDataAdminProvider);
    final String acknowledgement = _balanceAck.text.trim();
    final Outcome<void> result = _isEdit
        ? await admin.updateDealer(
            dealerId: widget.existing!.dealerId,
            dealer: dealer,
            amendReason: blankToNull(_amendReason.text),
            balanceAcknowledgement:
                acknowledgement.isEmpty ? null : acknowledgement,
          )
        : switch (await admin.createDealer(dealer)) {
            Failure<String>(:final AppError error) => Failure<void>(error),
            Success<String>() => const Success<void>(null),
          };

    if (!mounted) return;
    switch (result) {
      case Failure<void>(:final AppError error):
        setState(() {
          _submitting = false;
          _rejection = appErrorMessage(error);
        });
      case Success<void>():
        Navigator.of(context).pop();
    }
  }
}

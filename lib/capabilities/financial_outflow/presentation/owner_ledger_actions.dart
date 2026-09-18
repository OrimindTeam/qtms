/// ★★★ **إجراءا بطاقة ضمار المالك — التفكيكُ والمشاركة** (`AM-023`).
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **ولماذا ملفٌّ مشتركٌ لا دالّتان في كل شاشة:** ★ **البطاقةُ تُرسَم
/// في موضعين — «لوحة اليوم» وشاشتُها `/home/owner-ledger`** (`AM-017` ① ·
/// `design-system.md` §7.1 القاعدتان 9 و10): ⟵ **وخريطتا وجهاتٍ منفصلتان
/// تفترقان عند أول تعديل** ⛔ **فيفتح السهمُ نفسُه وجهتين مختلفتين**
/// (`coding-standards.md` §2.2).
///
/// ⛔⛔★★★ **والوجهةُ مشروطةٌ بمفتاح قارئها دائماً** — ★ **ومن لا يملك المفتاح
/// تُفتَح له شاشةُ الضمار نفسُها**: ⟵ **فلا وعدٌ يُخلَف ولا شاشةٌ تُفتَح على
/// رفض.** ⚠️⚠️ **وهذا إخفاءٌ لا حماية** — ★ **والحمايةُ شرطُ القراءة في
/// `firestore.rules`** (`RISK-02`).
///
/// ⛔⛔ **وصفر حسابٍ هنا** (`design-system.md` §5.1) — ★ **نصُّ المشاركة يُبنى
/// في [ownerLedgerShareText] من حقولٍ منسَّقةٍ جاهزة** ⛔ **لا من أعدادٍ خام.**
/// ═══════════════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qtms_domain/qtms_domain.dart';

import '../../../app/router.dart';
import '../../../core/ui/date_labels.dart';
import '../../identity_access/application/session_providers.dart';
import '../../oversight/application/messaging_providers.dart';
import '../../oversight/infrastructure/document_share_service.dart';
import 'owner_ledger_card.dart';
import 'owner_ledger_format.dart';

/// ★★★ **خريطةُ وجهاتِ صفوف البطاقة** — ⛔ **مصدرٌ واحدٌ للموضعين.**
///
/// ★ **التسميةُ هي المفتاح** — ⟵ **لأن المكوّن يُمرِّر تسميةَ الصفّ نفسَها**
/// (`OwnerLedgerCard.onRowTap`)، ★ **وهي نصٌّ ثابتٌ في `_Ledger`.**
/// ⛔ **وما لا مدخلَ له يقع على شاشة الضمار** — ⟵ **فلا سهمَ بلا وجهة.**
String ownerLedgerRowRoute(
  String rowLabel, {
  required bool Function(Permission) can,
}) =>
    switch (rowLabel) {
      'إجمالي الضمار' when can(Permission.dealerStatementView) =>
        dealerStatementRoute,
      'الواصل' when can(Permission.receiptCreate) => receiptRoute,
      'الخصومات' when can(Permission.discountCreate) => discountRoute,
      'إجمالي الضريبة' when can(Permission.sackView) => sackFinanceRoute,
      'السحبيات' || 'الخرجيات' when can(Permission.withdrawalCreate) ||
              can(Permission.expenseCreate) =>
        outflowRoute,
      _ => ownerLedgerRoute,
    };

/// ★★★ **تفكيكُ بندٍ إلى وجهته** — §7.1 القاعدة 5: **السهمُ وعدٌ بوجهة.**
void openOwnerLedgerRow(
  BuildContext context,
  WidgetRef ref,
  String rowLabel,
) =>
    context.go(
      ownerLedgerRowRoute(
        rowLabel,
        can: (Permission permission) =>
            ref.read(hasPermissionProvider(permission)),
      ),
    );

/// ★ **رسالةُ تعذّرِ فتح ورقة المشاركة** — ⛔ **ولا نصَّ استثناءٍ خام.**
const String ownerLedgerShareFailureMessage =
    'تعذّر فتح ورقة المشاركة. أعد المحاولة.';

/// ★★★ **مشاركةُ ملخّص اليوم نصّاً** — §7.1 القاعدة 10.
///
/// ⛔⛔ **ولا تُعرَض رسالةُ نجاح** — ★ **ورقةُ النظام نفسُها هي التغذيةُ
/// الراجعة**: ⟵ **ورسالةٌ فوقها ضجيجٌ يؤكّد ما رآه المستخدم بعينه.**
/// ★ **والفشلُ وحدَه يُقال** (`design-system.md` §6-ز: **الحدثُ العابر حبّة**).
Future<void> shareOwnerLedgerSummary(
  BuildContext context,
  WidgetRef ref, {
  required OwnerLedgerSummaryView view,
  required CalendarDay day,
}) async {
  final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(context);
  final DocumentShareOutcome outcome =
      await ref.read(documentShareProvider).shareText(
            text: ownerLedgerShareText(view, dayLabel: dayLabel(day)),
            subject: 'ضمار المالك — ${dayLabel(day)}',
          );
  if (outcome == DocumentShareOutcome.shared) return;
  messenger?.showSnackBar(
    const SnackBar(content: Text(ownerLedgerShareFailureMessage)),
  );
}

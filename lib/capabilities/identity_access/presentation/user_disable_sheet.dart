/// ورقة تعطيل المستخدم — ★ **بسببٍ نصّي إلزامي** (`FR-M1-12`).
///
/// ★★ **والتعطيل بديل الحذف لا مرادفٌ له:** «المستخدم صاحب حركات **لا يُحذف
/// نهائياً بل يُعطَّل فقط**» — ⟵ **فلا زر حذف في شاشة المستخدمين إطلاقاً**،
/// ⛔ **ولا يُخفى المعطَّل من القائمة** فيبدو كالمحذوف.
///
/// ⚠️⚠️ **وطلب السبب هنا راحةٌ لا حماية:** `validateUserDisable` ترفض السبب
/// الفارغ **في طبقة النطاق المشتركة**، **وتستدعيها `disableUser` في السحابة**
/// (`ADR-0012` · `ADR-0013` القاعدة 3). ⟵ **فمن تجاوز هذه الورقة يُرفَض هناك.**
///
/// ⛔⛔★★★ **و`disableReason` خارج `ADR-0020` صراحةً** — ★ **إلزاميٌّ كما كان**:
/// ⟵ **فموضعُه ④ «الحقل الإلزامي» في `P6` لا ⑤ «السبب (اختياري)»**،
/// ⛔ **ولا حقلَ سببٍ ثانٍ هنا**: ★ **`disable({userId, reason})` لا تقبله**،
/// ⟵ **وحقلٌ تُهمَل قيمتُه أسوأ من غيابه.**
///
/// ★★ **والورقةُ اليومَ `QtmsDestructiveSheet`** (`MASTER.md` §5b `P6` ·
/// `ADR-0021`) — ⛔ **ولا نسخةَ ثانية منها هنا.**
library;

import 'package:flutter/material.dart';
import 'package:qtms_domain/qtms_domain.dart';

import '../../../core/ui/destructive_sheet.dart';

/// يطلب سبب التعطيل — ويُرجِعه، أو `null` عند التراجع.
Future<String?> showUserDisableSheet(
  BuildContext context, {
  required UserCard user,
}) async {
  final DestructiveConfirmation? confirmation =
      await showQtmsDestructiveSheet(
    context,
    title: 'تعطيل المستخدم',
    // ★ **يُسمّى المستخدم صراحةً** — ⟵ فلا يُعطَّل غيرُ المقصود.
    impact: 'سيُمنع «${user.name}» من الدخول فوراً، '
        'وتبقى حركاته وقيوده كما هي.',
    confirmLabel: 'تعطيل',
    reasonLabel: null,
    requiredFieldLabel: 'سبب التعطيل',
  );
  // ★ **و`null` تراجُعٌ** — ⛔ **ولا يُنفَّذ التعطيل حينها.**
  return confirmation?.requiredValue;
}

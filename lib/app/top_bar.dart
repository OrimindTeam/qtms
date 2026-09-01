/// ⛔⛔★★★ **الشريط العلوي الموحّد — الصورة الموصولة** (`AM-008` ①).
///
/// ★★ **وهو المكوّن الذي تستدعيه كلُّ شاشة**: ⟵ **يقرأ الجلسةَ وحالةَ الاتصال
/// واليومَ من مزوّداتها**، ★ **ويُسلِّمها إلى `QtmsTopBarView` العرضي المحض.**
///
/// ⛔ **ولماذا في طبقة `app` لا في `core`:** ★ **`core` لا تعتمد على قدرةٍ
/// بعينها** (`ADR-0009`)، ⟵ **وقراءةُ الجلسة تعتمد على `identity-access`**؛
/// ★ **وطبقةُ `app` هي جذرُ التركيب أصلاً** (`router.dart` بجانبه).
///
/// ⛔⛔ **ولا شريطَ في شاشات ما قبل الجلسة** — `ui-guidelines.md` §3-أ:
/// **الدخول والبداية والجلسة المرفوضة** ⟵ **لا مستخدمَ بعدُ فلا صورةَ رمزية.**
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qtms_domain/qtms_domain.dart';

import '../capabilities/identity_access/application/session_providers.dart';
import '../capabilities/inventory/application/inventory_providers.dart';
import '../core/connectivity/connection_providers.dart';
import '../core/design/design_tokens.dart';
import '../core/ui/app_top_bar.dart';

/// الشريط العلوي الموحّد — ★ **اسم الشاشة مُدخَلٌ إلزامي.**
class QtmsTopBar extends ConsumerWidget implements PreferredSizeWidget {
  /// ينشئ الشريط.
  const QtmsTopBar({
    required this.screenTitle,
    this.actions = const <Widget>[],
    super.key,
  });

  /// ★★ **اسم الشاشة الحالية** — ⛔ **ديناميكيٌّ لا ثابتٌ في المكوّن.**
  final String screenTitle;

  /// إجراءاتٌ إضافية عند نهاية الشريط.
  final List<Widget> actions;

  @override
  Size get preferredSize => const Size.fromHeight(kTopBarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AuthSession? session = ref.watch(currentSessionProvider);
    return QtmsTopBarView(
      screenTitle: screenTitle,
      // ★★★ **قائمةُ الجلسة على الصورة الرمزية** — `AM-009` ①.
      onAvatarTap: () => showQtmsSessionSheet(context, ref),
      // ⚠️ **وجلسةٌ لم تصل بعدُ حالةٌ لحظية لا عطل** — ★ **والصورة الرمزية
      //    تعرض «؟»** ⛔ **ولا اسمَ يُخترَع.**
      userName: session?.displayName ?? '',
      today: ref.watch(todayProvider),
      connection: ref.watch(connectionStatusProvider),
      actions: actions,
    );
  }
}

/// ★★★ **قائمةُ الجلسة** — `AM-009` ①.
///
/// ⛔⛔★★★ **وهي الموضعُ الوحيد لتسجيل الخروج بعد اليوم:** ★ **أُزيلت
/// أيقونةُ الخروج من الشريط العلوي بطلب المالك** — ⟵ **وكانت المخرَجَ
/// الوحيد في التطبيق كلِّه** (`session_blocked_screen` تخصّ جلسةً مرفوضة
/// لا جلسةً عاملة)، ⛔ **فإسقاطُها بلا بديلٍ كان يترك المستخدم حبيسَ
/// حسابه** — ★ **ولا تبديلَ حسابٍ ولا تسليمَ جهازٍ ولا معالجةَ دورٍ تغيّر.**
///
/// ⛔ **ولا يُنفَّذ الخروج بلمسةٍ واحدة** — ★ **ورقةٌ صريحة بعنصرٍ مُسمّى**:
/// ⟵ **والصورةُ الرمزية هدفُ لمسٍ في زاوية الإبهام**، ⛔ **وخروجٌ فوريٌّ
/// منها كان يقع سهواً في كل جلسة.**
Future<void> showQtmsSessionSheet(BuildContext context, WidgetRef ref) =>
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: SemanticColors.surface,
      builder: (BuildContext sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('تسجيل الخروج'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                ref.read(authRepositoryProvider).signOut();
              },
            ),
          ],
        ),
      ),
    );

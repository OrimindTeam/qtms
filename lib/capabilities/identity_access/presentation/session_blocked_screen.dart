/// شاشة الجلسة المرفوضة — ★ **حساب معطَّل** (`FR-M1-15` · `ERR_AUTH_004`).
///
/// ⟵ **ولا شيء خلفها:** المستخدم لا يصل أي شاشة عمل حتى يخرج، وهو أثر
/// «**التعطيل فوري ونافذ**» في الواجهة (`authentication-policy.md` §2 القاعدة 3).
/// ⚠️ **والإنفاذ الحقيقي في القواعد لا هنا** — راجع `IQ-017`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/design_tokens.dart';
import '../../../core/messages/error_messages.dart';
import '../../../core/ui/inline_banner.dart';
import '../application/session_providers.dart';

/// ★ نصُّ الزر في حالته الساكنة — ⛔ **ولا نصٌّ محفورٌ في موضعين.**
const String signOutLabel = 'تسجيل الخروج';

/// ★ نصُّ الزر أثناء النداء — `design-system.md` §6-ي البند ②.
const String signOutBusyLabel = 'جارٍ الخروج…';

/// ★★ **نصُّ تعذُّر الخروج** — ⛔ **ولا يُبتلَع الفشل.**
const String signOutFailureMessage =
    '❌ تعذّر تسجيل الخروج — تحقّق من الاتصال ثم أعد المحاولة.';

/// تعرض رسالة الحساب المعطَّل وزر الخروج وحدهما.
class SessionBlockedScreen extends ConsumerStatefulWidget {
  /// ينشئ الشاشة.
  const SessionBlockedScreen({super.key});

  @override
  ConsumerState<SessionBlockedScreen> createState() =>
      _SessionBlockedScreenState();
}

class _SessionBlockedScreenState extends ConsumerState<SessionBlockedScreen> {
  /// ★ هل يجري نداءُ الخروج الآن؟
  bool _busy = false;

  /// ★ نصُّ الفشل — و`null` تعني **لا فشل**.
  String? _failure;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(Spacing.space24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.lock_outline,
                  size: Sizes.iconBox,
                  // ★ **المقدّمة من الثلاثية** — §3.3: **نصّاً وأيقونةً معاً.**
                  //   ⚠️ **و`const` تسقط هنا بحكم اللغة** — ★ **الوصولُ إلى
                  //   حقلِ كائنٍ ثابتٍ ليس تعبيراً ثابتاً** ⛔ **ولا يُعالَج
                  //   بنسخِ القيمة الخام** ⟵ **فذلك يعيد المخالفة نفسها.**
                  color: SemanticTriads.danger.ink,
                ),
                const SizedBox(height: Spacing.space16),
                Text(
                  catalogText(CatalogMessage.accountDisabled),
                  textAlign: TextAlign.center,
                  style: TypeScale.bodyLg
                      .copyWith(color: SemanticColors.textPrimary),
                ),
                const SizedBox(height: Spacing.space24),
                // ⛔⛔★★★ **زرٌّ ثنائي الحالة** — `design-system.md` §6-ي:
                //    ⟵ **وهو أخطرُ موضعٍ يُبتلَع فيه الفشل في التطبيق كلِّه**
                //    — ★ **لا شيءَ خلف هذا الزر إطلاقاً**: ⛔ **فمن تعذّر
                //    خروجُه بلا رسالةٍ يبقى في شاشةٍ واحدةٍ إلى الأبد**،
                //    ★ **ويظنّ التطبيقَ معطوباً لا اتصالَه.**
                FilledButton(
                  onPressed: _busy ? null : _signOut,
                  child: Text(_busy ? signOutBusyLabel : signOutLabel),
                ),
                // ★★ **والفشلُ يُعرَض ثم يُعاد تفعيلُ الزر** — §6-ي البند ④:
                //    ⛔ **وزرٌّ يبقى معطَّلاً بعد الفشل يُغلق الشاشةَ بلا مخرج.**
                if (_failure case final String message) ...<Widget>[
                  const SizedBox(height: Spacing.space16),
                  QtmsInlineBanner(
                    text: message,
                    triad: SemanticTriads.danger,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// ★★ **الخروج** — ⛔ **ولا ملاحةَ بعده:** ★ **تدفّقُ الجلسة حيّ**،
  /// ⟵ **فالموجّه يُخرج الشاشةَ من تلقائه** (`router.dart`).
  Future<void> _signOut() async {
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      await ref.read(authRepositoryProvider).signOut();
      // ⛔ **ولا `setState` بعد نجاحٍ يُخرِج الشاشة** — ★ **والموجّه أسرعُ
      //   من إعادة البناء عادةً**، ⟵ **و`mounted` تحرس الحالتين معاً.**
      if (!mounted) return;
      setState(() => _busy = false);
    } on Object {
      // ★ **ولا يُعرَض نصُّ المنصّة الخام** — `error-handling-strategy.md`
      //   §3 القاعدة 1.
      if (!mounted) return;
      setState(() {
        _busy = false;
        _failure = signOutFailureMessage;
      });
    }
  }
}

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
import '../application/session_providers.dart';

/// تعرض رسالة الحساب المعطَّل وزر الخروج وحدهما.
class SessionBlockedScreen extends ConsumerWidget {
  const SessionBlockedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                FilledButton(
                  onPressed: () =>
                      ref.read(authRepositoryProvider).signOut(),
                  child: const Text('تسجيل الخروج'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

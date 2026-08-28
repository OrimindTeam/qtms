/// بوابة الصلاحية في الواجهة — ★ **«الحقل الممنوع لا يظهر أصلاً»**
/// (`ui-guidelines.md` §2: «الصلاحيات تُخفي لا تُعطِّل»).
///
/// ⚠️⚠️ **وهذا إخفاء لا حماية** — `identity-access-design.md` §6:
/// «كل إخفاء هنا **يجب أن يقابله شرط قراءة أو كتابة في قواعد الحماية** —
/// وإلا فالصلاحية **غير مُنفَّذة أمنياً**» (`RISK-02` · `ADR-0010` القاعدة 3).
/// ⛔ **فلا يُكتفى بهذه البوابة أبداً.**
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qtms_domain/qtms_domain.dart';

import '../application/session_providers.dart';

/// يُظهر [child] إن كان المستخدم يملك [permission] — ⛔ **ولا يعرض بديلاً
/// يكشف وجود الميزة**، فالممنوع **لا يظهر أصلاً**.
class PermissionGate extends ConsumerWidget {
  const PermissionGate({
    required this.permission,
    required this.child,
    super.key,
  });

  final Permission permission;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool allowed = ref.watch(hasPermissionProvider(permission));
    return allowed ? child : const SizedBox.shrink();
  }
}

/// يُظهر [child] إن كان [sourceId] ضمن نطاق المستخدم — `FR-M1-07` · `E-35`.
class SourceScopeGate extends ConsumerWidget {
  const SourceScopeGate({
    required this.sourceId,
    required this.child,
    super.key,
  });

  final String sourceId;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool allowed =
        ref.watch(currentSessionProvider)?.canAccessSource(sourceId) ?? false;
    return allowed ? child : const SizedBox.shrink();
  }
}

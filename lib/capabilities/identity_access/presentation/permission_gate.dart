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

/// ★★ يُظهر [child] إن ملك المستخدم **أيَّ مفتاحٍ** من [permissions]
/// (`WU-014`).
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **ولماذا لزم بوابةٌ ثانية بدل تكرار [PermissionGate]:** ★ **`M22`
/// أولُ وحدةٍ لها *مفتاحا إنشاءٍ مستقلان لشاشةٍ واحدة*** — `GR-43`
/// (`withdrawalCreate` · `expenseCreate`): ⟵ **ومدخلُها يجب أن يظهر لمن
/// يملك أحدهما**، ⛔ **وبوابتان متتاليتان كانتا تعرضان مدخلين لشاشةٍ
/// واحدة** ★ **أو تُخفيان المدخلَ عمّن يملك الثاني وحده.**
///
/// ⚠️⚠️ **وهي إخفاءٌ لا حماية كأختها** (`RISK-02`) — ★ **والحارس الحقيقي
/// في `firestore.rules` وفي `outflowPermission` داخل الدالة الكاتبة**:
/// ⟵ **وكلُّ مفتاحٍ يُفحَص هناك على السجل الذي يخصّه وحده.**
/// ═══════════════════════════════════════════════════════════════════════
class AnyPermissionGate extends ConsumerWidget {
  /// ينشئ البوابة.
  const AnyPermissionGate({
    required this.permissions,
    required this.child,
    super.key,
  });

  /// المفاتيح — ★ **ويكفي واحدٌ منها** ⛔ **ولا تُجمع بـ«و».**
  final List<Permission> permissions;

  /// المحتوى المحروس.
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    for (final Permission permission in permissions) {
      if (ref.watch(hasPermissionProvider(permission))) return child;
    }
    return const SizedBox.shrink();
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

/// ★★★ **شاشة «الإعدادات»** — `AM-012` §4.4 (2026-09-02).
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **ولماذا شاشةٌ جديدة ولم تُضَف الخيارُ إلى «الإعداد التأسيسي»:**
///
/// ★ **`FR-M21-03`:** «يُسمح بإنشاء البندين **مرة واحدة فقط**، **والتعديل
/// والحذف مرفوضان نهائياً لكل المستخدمين بمن فيهم المالك**» — ⟹ ⛔⛔ **فمفتاحُ
/// تبديلٍ هناك لا يُبدَّل أبداً بعد أول حفظ**، ★ **ويصير زرَّاً معطَّلاً إلى
/// الأبد** ⛔ **وهو نقيضُ ما طُلب.**
/// ★ **و`FR-M21-05` يمنع «مفتاحاً ثالثاً في الإعدادات» أصلاً.**
///
/// ⟹ ★★ **وطُرح السؤال على المالك ولم يُحسَم اجتهاداً** (`AM-012` §2 السؤال ③)،
/// ⛅ **فاختار شاشةَ إعداداتٍ جديدة مستقلة.**
///
/// ⛔⛔★★★ **وحدُّها قاطع: تفضيلاتُ عرضٍ محليةٌ على هذا الجهاز وحدَه** —
/// ⛔ **ولا تكتب في `app_settings` ولا في `users/{userId}` ولا في أي مجموعة**:
/// ⟵ **فلا قاعدةَ حمايةٍ تُمَسّ**، ⛔ **ولا مفتاحَ صلاحيةٍ يُضاف** (`BR-M1-07`).
/// ═══════════════════════════════════════════════════════════════════════
///
/// ⏳★★ **وهي الموضعُ المُعَدُّ لبصمة جهة التطوير لاحقاً** — `FR-SYS-28`
/// («**تذييل شاشة الإعدادات بجوار رقم الإصدار**») ⛔ **ولم يُبنَ بعد**،
/// ★ **ويُبنى في الزيادة التي تحمل `FR-SYS-28`** ⛔ **لا استباقاً هنا.**
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/top_bar.dart';
import '../../../core/app_version.dart';
import '../../../core/design/design_tokens.dart';
import '../../../core/device/device_preference_providers.dart';
import '../../../core/identity/developer_attribution.dart';
import '../../../core/identity/developer_identity.dart';
import '../../../core/identity/developer_identity_providers.dart';
import 'about_screen.dart';

/// ★ اسمُ الشاشة — ⛔ **ولا نصٌّ محفورٌ في موضعين.**
const String settingsScreenTitle = 'الإعدادات';

/// ★★ **نصُّ زرِّ إظهار وزن الحبة** — `AM-012` §4.4 حرفياً.
const String showPieceWeightToggleLabel = 'إظهار وزن الحبة بجانب اسم النوع';

/// ★ عنوانُ مجموعة «حول» — `ui-guidelines.md` §3 نمط 7.
const String settingsAboutGroupTitle = 'حول';

/// شاشة الإعدادات.
class SettingsScreen extends ConsumerWidget {
  /// ينشئ الشاشة.
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool showPieceWeight = ref.watch(showPieceWeightProvider);
    final AsyncValue<DeveloperIdentity> identity =
        ref.watch(developerIdentityProvider);

    return Scaffold(
      appBar: const QtmsTopBar(screenTitle: settingsScreenTitle),
      body: ListView(
        padding: const EdgeInsetsDirectional.all(Spacing.screenPadding),
        children: <Widget>[
          Text(
            'العرض',
            style: TypeScale.titleSm.copyWith(color: SemanticColors.textPrimary),
          ),
          const SizedBox(height: Spacing.space8),
          const Divider(height: Sizes.borderWidth),
          SwitchListTile.adaptive(
            value: showPieceWeight,
            onChanged: (bool value) =>
                ref.read(showPieceWeightProvider.notifier).set(enabled: value),
            title: const Text(showPieceWeightToggleLabel),
            // ⛔⛔★★★ **والنصُّ يُعلن حدَّ الخيار صراحةً** — `AM-012` §4.4:
            //    ★ **«تجميلي/عرضي فقط، ولا يؤثر إطلاقاً على الطبيعة العددية
            //    للنوع»** ⟵ **ومبدِّلٌ في شاشةِ إعداداتٍ بلا نصٍّ يُوهم
            //    بأنه يغيّر وحدةَ الحساب** ⛔ **وهو أخطر التباسٍ ممكن هنا.**
            subtitle: const Text(
              'يظهر الاسم هكذا: «بطّوه وزن (200 جرام)». '
              'خيار عرض فقط — ولا يغيّر وحدة النوع ولا أي حساب، '
              'ويبقى العدّ بالحبة في كل الشاشات والتقارير.',
            ),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: Spacing.space8),
          Text(
            // ★★ **وإفصاحٌ عن محلّية التفضيل** — ⛔ **ولا يُترك يُكتشَف:**
            //    ⟵ **فمن يبدّله على هاتفٍ ثم يفتح آخر لا يظنّه عطلاً.**
            'هذا الخيار محفوظ على هذا الجهاز وحده.',
            style:
                TypeScale.bodyMd.copyWith(color: SemanticColors.textSecondary),
          ),
          const SizedBox(height: Spacing.sectionGap),
          // ★★ **مجموعةُ «حول»** — `ui-guidelines.md` §3 نمط 7 يذكرها صراحةً
          //    ضمن مجموعات الإعدادات المتوقَّعة.
          Text(
            settingsAboutGroupTitle,
            style: TypeScale.titleSm.copyWith(color: SemanticColors.textPrimary),
          ),
          const SizedBox(height: Spacing.space8),
          const Divider(height: Sizes.borderWidth),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text(aboutScreenTitle),
            trailing: const Icon(Icons.chevron_left),
            onTap: () => context.go(aboutRoute),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: Spacing.sectionGap),
          // ★★★ **تذييلُ الإصدار والإسناد** — `FR-SYS-28` الموضع 2.
          //
          // ⛔⛔ **ومرةً واحدةً في هذه الشاشة** (`developer-identity.md` §4) —
          //    ★ **يحرسُه اختبارُ الشاشة.**
          switch (identity) {
            AsyncValue<DeveloperIdentity>(
              value: final DeveloperIdentity value?
            ) =>
              DeveloperAttribution(
                identity: value,
                variant: DeveloperAttributionVariant.footer,
                versionLabel: appVersionLabel,
              ),
            // ⚠️★★ **وتعذُّرُ البصمة لا يُسقِط شاشةَ الإعدادات ولا يعترض**
            //    (§5 البند 8: «**بصمةٌ تعترض المستخدم**» ممنوعة) — ★ **يبقى
            //    رقمُ الإصدار وحدَه**: ⟵ **وهو بيانُ المنتج لا بيانُ المطوّر.**
            _ => const _VersionOnlyFooter(),
          },
        ],
      ),
    );
  }
}

/// ★ تذييلٌ برقم الإصدار وحده — عند تعذُّر قراءة البصمة أو أثناء تحميلها.
class _VersionOnlyFooter extends StatelessWidget {
  const _VersionOnlyFooter();

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Divider(height: Sizes.borderWidth),
          const SizedBox(height: Spacing.space12),
          Text(
            appVersionLabel,
            textAlign: TextAlign.center,
            style:
                TypeScale.caption.copyWith(color: SemanticColors.textTertiary),
          ),
        ],
      );
}

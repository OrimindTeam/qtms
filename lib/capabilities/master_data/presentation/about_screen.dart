/// ★★★ **شاشة «حول التطبيق»** — `FR-SYS-28` · الموضع 1 في وضع `discreet`
/// (`developer-identity.md` §2 · `DI-001`).
///
/// ════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **وليست «شاشةَ المطوّر»** — ★ **وهو ممنوعٌ صريحٌ** (§5 البند 5:
/// «**شاشةٌ مستقلةٌ اسمها المطوّر — وجودٌ شكليٌّ بلا قيمة**»): ⟵ **الشاشةُ
/// شاشةُ المنتج**، ★ **هويةُ العميل في صدرها وبمقاسها الكامل**، ⛔ **وبصمةُ
/// جهة التطوير قسمٌ سفليٌّ واحدٌ بعد فاصل.**
///
/// ★★ **والاختبارُ العملي الذي تقيسه** (§4): ⟵ **«لو نظر مستخدمٌ للشاشة
/// ثانيةً واحدة، يجب أن يرى هويةَ المنتج لا بصمةَ المطوّر»** — ★ **ولذلك
/// شعارُ العميل 112 والعلامةُ 35.84** (`developerMarkRatio`).
/// ════════════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/top_bar.dart';
import '../../../core/app_version.dart';
import '../../../core/design/brand.dart';
import '../../../core/design/design_tokens.dart';
import '../../../core/identity/developer_attribution.dart';
import '../../../core/identity/developer_identity.dart';
import '../../../core/identity/developer_identity_providers.dart';
import '../../../core/ui/async_state_view.dart';
import '../../../core/ui/skeleton.dart';

/// ★ اسمُ الشاشة — ⛔ **ولا نصٌّ محفورٌ في موضعين.**
const String aboutScreenTitle = 'حول التطبيق';

/// ★ رسالةُ تعذُّر قراءة بصمة جهة التطوير — ⛔ **ولا «حدث خطأ» عارية.**
const String developerIdentityErrorMessage = 'تعذّر عرض بيانات جهة التطوير.';


/// شاشةُ «حول التطبيق».
class AboutScreen extends ConsumerWidget {
  /// ينشئ الشاشة.
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<DeveloperIdentity> identity =
        ref.watch(developerIdentityProvider);

    return Scaffold(
      appBar: const QtmsTopBar(screenTitle: aboutScreenTitle),
      body: ListView(
        padding: const EdgeInsetsDirectional.all(Spacing.screenPadding),
        children: <Widget>[
          const SizedBox(height: Spacing.sectionGap),
          // ★★★ **هويةُ المنتج أولاً وبمقاسها الكامل** — §1: «**الأولويةُ
          //    الأعلى دائماً**».
          const Center(child: BrandLogo()),
          const SizedBox(height: brandLogoGap),
          Text(
            appDisplayName,
            textAlign: TextAlign.center,
            style: TypeScale.titleLg.copyWith(color: SemanticColors.textPrimary),
          ),
          const SizedBox(height: Spacing.space4),
          Text(
            appVersionLabel,
            textAlign: TextAlign.center,
            style:
                TypeScale.caption.copyWith(color: SemanticColors.textTertiary),
          ),
          const SizedBox(height: Spacing.space40),
          // ★★ **والقسمُ السفلي وحده** — ⛔ **ولا تكرارَ للبصمة في الشاشة**
          //    (§4: «**مرةً واحدةً فقط**») — ★ **يحرسُه اختبارُ الشاشة.**
          switch (identity) {
            // ⛔⛔★★ **والخطأُ يُعرَض ولا يُبتلَع** — ★ **وبلا إعادة محاولة:**
            //    ⟵ **مصدرُ الحقيقة أصلٌ مُحزَّمٌ في التطبيق لا نداءُ شبكة**،
            //    ★ **فتعذُّرُ قراءته عطلُ حزمةٍ لا عارضٌ يزول بضغطة.**
            AsyncValue<DeveloperIdentity>(hasError: true, :final Object? error) =>
              QtmsErrorState(
                message: developerIdentityErrorMessage,
                detail: error?.toString(),
              ),
            AsyncValue<DeveloperIdentity>(value: final DeveloperIdentity value?) =>
              DeveloperAttribution(identity: value),
            // ⛔⛔★★★ **وهيكلٌ مفردٌ لا `SkeletonList`** — ★ **تلك `ListView`**:
            //    ⟵ **وقائمةٌ داخل قائمةٍ بلا ارتفاعٍ محدود تُسقِط التخطيط**
            //    (`Vertical viewport was given unbounded height`) — ★ **وهو
            //    نظيرُ [`DEBT-63`] حرفياً: قيدٌ غيرُ محدودٍ يُسقِط الرسم**،
            //    ⛔ **ولا يظهر إلا في لحظة التحميل** ⟵ **فيمرّ من كل فحصٍ
            //    ساكن.** ★ **كشفه اختبارُ الشاشة قبل المحاكي.**
            _ => const SkeletonTile(),
          },
        ],
      ),
    );
  }
}

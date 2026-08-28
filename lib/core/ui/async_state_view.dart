/// ★★★ **مبدّل الحالات الأربع** — `design-system.md` §هـ.
///
/// ★ **«مكوّنٌ واحد يفرض تنفيذ الحالات الأربع ويمنع نسيان إحداها»** نصّاً —
/// ⟵ **وكان في التطبيق مبدِّلان متطابقان** (`InventoryAsyncView` و
/// `MasterDataAsyncView`) ⛔ **وهو ما يمنعه §8 المحظور الحادي عشر.**
///
/// ⚠️⚠️ **وثلاثٌ من حالاته الأربع كانت مخالفةً للعقد صراحةً:**
/// ① **التحميل** مؤشّرٌ دوّار وسط الشاشة — ⛔ **يمنعه §هـ نصّاً** ⟵ صار هيكلاً.
/// ② **الفارغة** سطرٌ رمادي وحده — ★ **والعقد يفرض «أيقونة + عنوان + رسالة
///    + إجراء أساسي»** و⛔ **يمنع «لا توجد بيانات بلا سبب ولا إجراء».**
/// ③ **الخطأ** سطرٌ رمادي وحده — ★ **والعقد يفرض «أيقونة `danger` + رسالة
///    بشرية + سبب تقني مطويّ + إعادة محاولة».**
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/design_tokens.dart';
import 'skeleton.dart';
import 'status_pill.dart';

/// ★ عارض تدفّق بالحالات الأربع — **تحميل · خطأ · فارغ · بيانات**.
///
/// ⚠️⚠️ **والخطأ يُفحَص أولاً ⛔ لا بـ`when` وحدها** — عطلٌ رُصد في `WU-001`:
/// حين يُخفق التدفّق تبقى الحالة `AsyncLoading` **وهي تحمل الخطأ**، ⟵
/// **فتدور الدائرة إلى الأبد ولا يرى الممنوعُ سببَ منعه أبداً.**
class AsyncStateView<T> extends StatelessWidget {
  /// ينشئ العارض.
  const AsyncStateView({
    required this.value,
    required this.empty,
    required this.errorMessage,
    required this.builder,
    this.onRetry,
    this.skeletonCount = 4,
    super.key,
  });

  /// التدفّق المعروض.
  final AsyncValue<List<T>> value;

  /// ★ **الحالة الفارغة مصمَّمة** — ⛔ **لا نصّاً عارياً.**
  final EmptyStateSpec empty;

  /// ★ **رسالة الخطأ البشرية** — ★ **من الكتالوج** ⛔ **ولا صياغةَ هنا.**
  final String Function(Object failure) errorMessage;

  /// باني القائمة عند وجود بيانات.
  final Widget Function(List<T> items) builder;

  /// ★ إعادة المحاولة — §هـ يفرضها في حالة الخطأ.
  final VoidCallback? onRetry;

  /// عدد الهياكل أثناء التحميل.
  final int skeletonCount;

  @override
  Widget build(BuildContext context) => switch (value) {
        AsyncValue<List<T>>(hasError: true, :final Object? error) =>
          QtmsErrorState(
            message: errorMessage(error ?? Object()),
            detail: error?.toString(),
            onRetry: onRetry,
          ),
        AsyncValue<List<T>>(value: final List<T> items?) => items.isEmpty
            ? QtmsEmptyState(spec: empty)
            : builder(items),
        _ => SkeletonList(count: skeletonCount),
      };
}

/// ★ وصفُ حالةٍ فارغة — **أيقونة + عنوان + رسالة + إجراء** (§هـ).
///
/// ⛔⛔ **ولا حقلَ اختياريّ في الثلاثة الأولى:** ★ **جعلُها مطلوبةً في النوع
/// نفسه هو ما يمنع «لا توجد بيانات» من العودة** — ⟵ **وقاعدةٌ تُفرَض في
/// التوقيع لا تُنسى في مراجعة.**
@immutable
class EmptyStateSpec {
  /// ينشئ الوصف.
  const EmptyStateSpec({
    required this.icon,
    required this.title,
    required this.message,
    this.triad,
    this.actionLabel,
    this.onAction,
  });

  /// الأيقونة.
  final IconData icon;

  /// ★★ **العائلة التصنيفية لمجموعة الشاشة** — `design-system.md` §4.
  ///
  /// ★ **وهو أحدُ ثلاثة مواضع يجيزها العقد للّون التصنيفي**: «**حاويات
  /// أيقوناتها الداخلية**». ⟵ **فالفراغُ يحمل هويةَ مجموعته بدل رماديٍّ
  /// محايد**، ⛔ **ولا يُستعمَل خلفيةً كبيرة ولا لوناً لزرٍّ أساسي.**
  /// ★ **و`null` تعني المحايد** — ⟵ **«لا لون بلا وظيفة»** (§2 المبدأ الأول).
  final ColorTriad? triad;

  /// ★ **العنوان** — سببُ الفراغ لا وصفُه.
  final String title;

  /// ★ **الرسالة** — الخطوة التالية (`ui-guidelines.md` §6).
  final String message;

  /// نصّ الإجراء الأساسي — `null` حين لا يملك المستخدم إجراءً هنا.
  final String? actionLabel;

  /// الإجراء الأساسي.
  final VoidCallback? onAction;
}

/// الحالة الفارغة المرسومة.
class QtmsEmptyState extends StatelessWidget {
  /// ينشئ الحالة.
  const QtmsEmptyState({required this.spec, super.key});

  /// الوصف.
  final EmptyStateSpec spec;

  @override
  Widget build(BuildContext context) => _CenteredState(
        icon: spec.icon,
        triad: spec.triad ?? SemanticTriads.neutral,
        title: spec.title,
        message: spec.message,
        actionLabel: spec.actionLabel,
        onAction: spec.onAction,
      );
}

/// ★★ حالة الخطأ — **أيقونة `danger` + رسالة بشرية + سبب تقني مطويّ**.
///
/// ⚠️ **والسبب التقني مطويٌّ عمداً** — ★ **المستخدم الميداني لا يقرؤه**،
/// ⛔ **وإخفاؤه كلياً يترك من يساعده بلا شيء.**
class QtmsErrorState extends StatefulWidget {
  /// ينشئ الحالة.
  const QtmsErrorState({
    required this.message,
    this.detail,
    this.onRetry,
    super.key,
  });

  /// الرسالة البشرية — ★ **من الكتالوج.**
  final String message;

  /// السبب التقني — يُعرَض مطويّاً.
  final String? detail;

  /// إعادة المحاولة.
  final VoidCallback? onRetry;

  @override
  State<QtmsErrorState> createState() => _QtmsErrorStateState();
}

class _QtmsErrorStateState extends State<QtmsErrorState> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) => _CenteredState(
        icon: Icons.error_outline,
        triad: SemanticTriads.danger,
        title: 'تعذّر عرض البيانات',
        message: widget.message,
        actionLabel: widget.onRetry == null ? null : 'إعادة المحاولة',
        onAction: widget.onRetry,
        extra: widget.detail == null
            ? null
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextButton(
                    onPressed: () => setState(() => _expanded = !_expanded),
                    child: Text(
                      _expanded ? 'إخفاء التفاصيل التقنية' : 'تفاصيل تقنية',
                    ),
                  ),
                  // ★ **الطيّ متحرّك ويحترم تقليل الحركة** — §9.
                  AnimatedCrossFade(
                    firstChild: const SizedBox.shrink(),
                    secondChild: Padding(
                      padding: const EdgeInsets.only(top: Spacing.space8),
                      child: Text(
                        widget.detail!,
                        textAlign: TextAlign.center,
                        style: TypeScale.caption.copyWith(
                          color: SemanticColors.textTertiary,
                        ),
                      ),
                    ),
                    crossFadeState: _expanded
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    duration: Motion.of(context, Motion.fast),
                    sizeCurve: Motion.standard,
                  ),
                ],
              ),
      );
}

/// ★ الهيكل المشترك للحالتين — ⛔ **ولا نسخةٌ ثانية منه.**
class _CenteredState extends StatelessWidget {
  const _CenteredState({
    required this.icon,
    required this.triad,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.extra,
  });

  final IconData icon;
  final ColorTriad triad;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? extra;

  @override
  Widget build(BuildContext context) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Spacing.space24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              IconBadgeBox(icon: icon, triad: triad, size: Sizes.avatarLg),
              const SizedBox(height: Spacing.space16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TypeScale.titleMd
                    .copyWith(color: SemanticColors.textPrimary),
              ),
              const SizedBox(height: Spacing.space8),
              // ★ **قياسُ السطر محدود** — `ui-guidelines.md` §5: ⟵ **فالنصّ
              //   لا يمتدّ من حافةٍ لحافة على الأجهزة الواسعة.**
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TypeScale.bodyMd
                      .copyWith(color: SemanticColors.textSecondary),
                ),
              ),
              if (actionLabel case final String label) ...<Widget>[
                const SizedBox(height: Spacing.space24),
                FilledButton(onPressed: onAction, child: Text(label)),
              ],
              if (extra case final Widget widget) ...<Widget>[
                const SizedBox(height: Spacing.space8),
                widget,
              ],
            ],
          ),
        ),
      );
}

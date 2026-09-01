/// ⛔⛔★★★ **الشريط العلوي الموحّد** — `ui-guidelines.md` §3-أ (`AM-008` ①).
///
/// ★★★ **عقدٌ يعلو الأنماط التسعة:** ⟵ **كلُّ شاشةٍ في التطبيق تستدعي هذا
/// المكوّن**، ⛔ **ولا `AppBar` مبنيٌّ يدوياً في أي شاشة بعد اليوم.**
///
/// ⛔⛔★★★ **ولماذا مكوّنٌ واحد — وهو عطلٌ مقيسٌ لا احتياط:** ★ **كانت
/// `home_shell` وحدها تعرض الشعار واسم المحل، والتسعَ عشرةَ شاشةً الباقية
/// تعرض عنواناً نصّياً عارياً** — ⟵ **بنيةٌ واحدة كُتبت عشرين مرة فافترقت
/// فعلاً**، ⛔ **وهو حرفياً ما يمنعه `design-system.md` §8 المحظور الحادي عشر.**
///
/// ★ **الترتيب من البداية (اليمين في RTL) إلى النهاية:**
/// **الشعار ⟵ اسم التطبيق فوق اسم الشاشة ⟵ التاريخ وحالة الاتصال ⟵
/// الصورة الرمزية.**
///
/// ⛔ **ولا يقرأ هذا المكوّن مزوّداً واحداً** — ★ **تُمرَّر إليه الحالة**
/// (§5.1 «فصل العرض عن المنطق»)، ⟵ **فطبقةُ `core` لا تعتمد على قدرةٍ بعينها**
/// (`ADR-0009`) **ويُختبَر بلا جلسةٍ ولا سحابة.**
library;

import 'package:flutter/material.dart';
import 'package:qtms_domain/qtms_domain.dart';

import '../connectivity/connection_status.dart';
import '../design/brand.dart';
import '../design/design_tokens.dart';
import 'avatar.dart';

/// ★★ **ارتفاع الشريط** — **سطران للهوية داخل هدف لمسٍ واحد.**
///
/// ⚠️⚠️★★ **وسقفٌ بنيوي لا قصٌّ قسري — والفرق مقصود** (نفس منطق
/// `context_header.dart`): ★ **§8 يفرض احترام `textScaler` عند 200٪ بلا
/// فيضان**، ⟵ **والقصُّ كان سيُخفي اسم الشاشة عمّن كبّر الخط.**
const double kTopBarHeight = Sizes.minTouch + Sizes.avatarSm;

/// الشريط العلوي — ★ **عرضٌ محض** ⛔ **بلا مزوّدات.**
class QtmsTopBarView extends StatelessWidget implements PreferredSizeWidget {
  /// ينشئ الشريط.
  const QtmsTopBarView({
    required this.screenTitle,
    required this.userName,
    required this.today,
    required this.connection,
    this.actions = const <Widget>[],
    this.onAvatarTap,
    super.key,
  });

  /// ★★ **اسم الشاشة الحالية** — ⛔⛔ **مُدخَلٌ إلزامي في التوقيع**:
  /// ⟵ **فالعقد يُفرَض عند الكتابة لا عند المراجعة**، ⛔ **ولا نصَّ ثابتٌ
  /// داخل المكوّن** (§3-أ: «اسم الشاشة ديناميكي لا نصٌّ ثابت»).
  final String screenTitle;

  /// اسم صاحب الجلسة — ★ **منه يُشتقّ حرف الصورة الرمزية.**
  final String userName;

  /// ★ تاريخ اليوم.
  final CalendarDay today;

  /// ★★ حالة الاتصال **مقيسةً** — ⛔ **ولا تُدَّعى** (`ADR-0003`).
  final ConnectionStatus connection;

  /// ★ إجراءاتٌ إضافية عند نهاية الشريط — **قبل الصورة الرمزية**.
  final List<Widget> actions;

  /// ★★★ **قائمةُ الجلسة على الصورة الرمزية** — `AM-009` ①.
  ///
  /// ⛔⛔★★★ **ولماذا انتقل الخروجُ إليها:** ★ **أُزيلت أيقونةُ الخروج من
  /// الشريط بطلب المالك**، ⟵ **وإسقاطُ القدرة معها كان يترك التطبيق بلا
  /// مخرجٍ واحدٍ لتسجيل الخروج** ⛔ **فلا تبديلَ حسابٍ ولا تسليمَ جهاز.**
  /// ★ **والصورةُ الرمزية هي عنصرُ الهوية في الشريط** — ⟵ **فقائمةُ الجلسة
  /// موضعُها الطبيعي**، ⛔ **ولا أيقونةَ سادسة تُضاف.**
  ///
  /// ⚠️ **و`null` تعني صورةً غير قابلة للنقر** — ★ **وهي حالةُ العرض المحض
  /// في الاختبار** ⛔ **لا حالةَ شاشةٍ حيّة.**
  final VoidCallback? onAvatarTap;

  // ⛔⛔★★★ **ولا زرَّ رجوعٍ في أي شاشة** — `AM-009` ①: ★ **والانحرافُ الذي
  //    قُبل في `AM-008` أُسقط بطلب المالك**، ⟵ **فالشريطُ يبدأ بالشعار في
  //    العشرين شاشةً بلا استثناء** ⛔ **ولا `leading` مُستنتَجٌ من الملاحة.**
  //    ★ **والرجوعُ يبقى بإيماءة النظام وزرِّه على أندرويد** — ⟵ **فلا قدرةَ
  //    تسقط**، ★ **وترتيبُ العناصر الأربعة صار واحداً في كل شاشة فعلاً.**

  @override
  Size get preferredSize => const Size.fromHeight(kTopBarHeight);

  @override
  Widget build(BuildContext context) => AppBar(
        backgroundColor: SemanticColors.surface,
        toolbarHeight: kTopBarHeight,
        // ⛔⛔★★★ **ولا زرَّ رجوعٍ مُستنتَج** — راجع الملاحظة أعلاه (`AM-009` ①).
        automaticallyImplyLeading: false,
        // ⛔ **ولا حشوَ افتراضي يُزيح الشعار عن حافة الشاشة.**
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: Spacing.screenPadding,
          ),
          child: Row(
            children: <Widget>[
              // ① ★ **شعار العميل عند البداية** — ⛔ **ولا مسارَ أصلٍ هنا.**
              const BrandLogo(size: Sizes.chipHeight),
              const SizedBox(width: Spacing.space8),
              // ② ★★ **الهوية سطران: الاسم الظاهر فوق اسم الشاشة.**
              Expanded(child: _Identity(screenTitle: screenTitle)),
              const SizedBox(width: Spacing.space8),
              // ③ ★★ **التاريخ وحالة الاتصال.**
              _DayAndConnection(today: today, connection: connection),
              const SizedBox(width: Spacing.space8),
              ...actions,
              // ④ ★★ **الصورة الرمزية عند النهاية** — ★★★ **وهي مدخلُ قائمة
              //    الجلسة بعد `AM-009`** (راجع [onAvatarTap]).
              _AvatarSlot(userName: userName, onTap: onAvatarTap),
            ],
          ),
        ),
      );
}

/// ★★★ **موضعُ الصورة الرمزية** — **قابلٌ للنقر متى وُجدت قائمةُ جلسة.**
///
/// ⛔⛔★★ **وهدفُ اللمس كاملٌ لا قطرُ الدائرة** — `design-system.md` §8:
/// ★ **قطرُ `avatarSm` دون الحد الأدنى للمس**، ⟵ **فيُحاط بمربّعٍ بمقاسه.**
///
/// ⛔⛔★★★ **ولا `Size.fromHeight` هنا** — `DEBT-63`: ★ **الموضعُ ابنٌ غيرُ
/// مرنٍ في `Row`**، ⟵ **وعرضٌ لا نهائي كان يُنتج قيداً مستحيلاً فلا يُخطَّط.**
class _AvatarSlot extends StatelessWidget {
  const _AvatarSlot({required this.userName, required this.onTap});

  final String userName;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Widget avatar = QtmsAvatar(name: userName);
    if (onTap == null) return avatar;
    return IconButton(
      onPressed: onTap,
      // ★ **وصفٌ دلالي صريح** — ⛔ **ولا أيقونةَ بلا اسمٍ مقروء.**
      tooltip: 'قائمة الجلسة',
      icon: avatar,
      // ⛔ **ولا حشوَ افتراضي يُضخّم الموضع** — ★ **والمقاسُ من التوكنز.**
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(
        minWidth: Sizes.minTouch,
        minHeight: Sizes.minTouch,
      ),
    );
  }
}

/// ★★ هوية التطبيق — **الاسم الظاهر فوق اسم الشاشة**.
class _Identity extends StatelessWidget {
  const _Identity({required this.screenTitle});

  final String screenTitle;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            // ★ **مصدر الحقيقة الواحد** (`AM-002`) — ⛔ **لا نصٌّ محفور.**
            appDisplayName,
            style:
                TypeScale.titleSm.copyWith(color: SemanticColors.textPrimary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            screenTitle,
            style:
                TypeScale.caption.copyWith(color: SemanticColors.textTertiary),
            // ⛔⛔★★ **وهو وحده ما يُقصّ عند الضيق** — §3-أ القاعدة 4:
            //    ★ **ترتيبُ الإسقاط مقصود، والأقلُّ حسماً أولاً.**
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      );
}

/// ★★ التاريخ وحالة الاتصال — **في عمودٍ واحد بعرضٍ لا يتمدّد.**
class _DayAndConnection extends StatelessWidget {
  const _DayAndConnection({required this.today, required this.connection});

  final CalendarDay today;
  final ConnectionStatus connection;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Semantics(
            label: 'تاريخ اليوم ${today.formatReadable()}',
            child: ExcludeSemantics(
              // ⛔⛔★★ **واتجاه الرقم مثبَّتٌ داخل الجملة العربية** — ★ **قاعدة
              //    «ضبط اتجاه الرقم داخل الجملة»** (`rtl-ltr-guidelines.md`):
              //    ⟵ **وبدونها يقلب المحرّك طرفَي الشرطة المائلة فيُقرأ
              //    الشهرُ يوماً** — ⛔ **والتباسٌ في تاريخٍ لا يُغتفَر هنا.**
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Text(
                  dayMonthLabel(today),
                  // ★★ **أرقامٌ جدولية** — ⟵ **فعرضُ التاريخ لا يهتزّ بين
                  //    يومٍ وآخر** فيُزيح ما بجانبه (§6.د).
                  style: TypeScale.numeric
                      .copyWith(color: SemanticColors.textPrimary),
                ),
              ),
            ),
          ),
          const SizedBox(height: Spacing.space2),
          ConnectionIndicator(status: connection),
        ],
      );
}

/// ★ **يوم / شهر** — ★ **بصيغة الصورة المرجعية حرفياً** (`AM-008` ①).
///
/// ⛔ **وبصفرٍ بادئ دائماً** — ⟵ **فعرضُ النصّ ثابتٌ طوال الشهر.**
String dayMonthLabel(CalendarDay day) =>
    '${_twoDigits(day.day)} / ${_twoDigits(day.month)}';

String _twoDigits(int value) => value.toString().padLeft(2, '0');

/// ★★★ **مؤشّر الاتصال — نقطةٌ ونصٌّ معاً** (§3-أ العنصر ③).
///
/// ⛔⛔★★★ **ولا معنى باللون وحده** — `design-system.md` §8: ⟵ **فالنقطة
/// تُلوَّن والنصُّ يقول الحالة صراحةً**، ★ **ومن لا يميّز الأحمر من الأخضر
/// يقرأ «غير متصل» كما يقرؤها غيره.**
class ConnectionIndicator extends StatelessWidget {
  /// ينشئ المؤشّر.
  const ConnectionIndicator({required this.status, super.key});

  /// الحالة المقيسة.
  final ConnectionStatus status;

  /// ★ **قطر النقطة** — ⛔ **ولا رقمَ محفور: من سلّم المسافات.**
  static const double dotSize = Spacing.space8;

  /// ★ نصُّ الحالة — ⛔ **و«متصل» لا تُقال قبل قياس** (`ADR-0003`).
  static String labelOf(ConnectionStatus status) => switch (status) {
        ConnectionStatus.online => 'متصل',
        ConnectionStatus.offline => 'غير متصل',
        ConnectionStatus.unknown => 'يتحقق',
      };

  /// ★ الثلاثية اللونية — **دلاليةٌ لأنها حكمٌ لا هوية** (§3.5).
  static ColorTriad triadOf(ConnectionStatus status) => switch (status) {
        ConnectionStatus.online => SemanticTriads.success,
        ConnectionStatus.offline => SemanticTriads.danger,
        ConnectionStatus.unknown => SemanticTriads.neutral,
      };

  @override
  Widget build(BuildContext context) {
    final ColorTriad triad = triadOf(status);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: dotSize,
          height: dotSize,
          decoration: BoxDecoration(color: triad.ink, shape: BoxShape.circle),
        ),
        const SizedBox(width: Spacing.space4),
        Text(
          labelOf(status),
          style: TypeScale.caption.copyWith(color: triad.ink),
          maxLines: 1,
        ),
      ],
    );
  }
}

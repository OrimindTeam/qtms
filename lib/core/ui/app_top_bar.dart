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

/// ★★ **فائضُ هدف اللمس حول الصورة الرمزية** — **نصفُه على كل جانب**.
///
/// ⛔ **ومشتقٌّ لا محفور** — ⟵ **فلو تغيّر أيُّ مقاسٍ منهما بقيت المحاذاةُ
/// صحيحة** ⛔ **ولا رقمَ يتخلّف عن التوكنز.**
/// ★★ **سقفُ عرضِ عمود التاريخ وحالة الاتصال** — **نسبةً من عرض الشاشة.**
///
/// ⚠️⚠️★★ **ورقمٌ تنفيذيٌّ مُعلَن لا منقولٌ عن مستند:** ★ **العمودُ يحمل
/// `2026 / 09 / 20` و«غير متصل»** — ⟵ **ويحتاج نحو 40٪ من عرضِ هاتفٍ ضيّق
/// عند تكبير الخط 200٪**، ★ **و42٪ تترك للهوية ما يكفي لحرفين على الأقل**
/// ⛔ **ولا تُقصّ في الاستعمال العادي إطلاقاً** (مقيسٌ على 320 و360 و800).
///
/// ⛔ **وأثرُ الخطأ فيه محصورٌ في تقلّصٍ بصريّ** — ⛔ **لا رقمَ ولا قيمة.**
const double _dayColumnMaxWidthRatio = 0.42;

const double _avatarSlack = (Sizes.minTouch - Sizes.avatarSm) / 2;

/// ★★★ **حشوُ الشريط عند النهاية** — **مطروحاً منه فائضُ هدف اللمس.**
///
/// ⛔⛔ **ولا يقلّ عن صفر** — ★ **حارسٌ لو صار هدفُ اللمس أصغرَ من الصورة
/// يوماً**: ⟵ **فحشوٌ سالب يرمي في التخطيط** ⛔ **لا يُصلح شيئاً.**
const double _avatarEdgeInset =
    Spacing.screenPadding > _avatarSlack ? Spacing.screenPadding - _avatarSlack : 0;

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
          // ⛔⛔★★★ **وحشوٌ غيرُ متماثل عمداً — وهو محاذاةٌ بصرية لا خطأ**
          //    (`AM-012` §الإصلاح · 2026-09-02):
          //
          // ★ **الشعارُ عند البداية يلامس حدَّ الحشو مباشرةً** (36 بكسلاً)،
          //    ⟵ **بينما الصورةُ الرمزية محاطةٌ بهدف لمسٍ 48** (§5 البند 3)
          //    ⟹ ⛔ **فتقع الدائرةُ 36 في وسطه بستّة بكسلات على كل جانب.**
          //
          // ⟹ ⛔⛔ **فكان الفراغُ عند النهاية 22 بكسلاً مقابل 16 عند البداية**
          //    — ★ **رآه المالكُ على الجهاز وسمّاه «مسافة فارغة»**، ⛔ **وهو
          //    عطلٌ بصريٌّ حقيقي لا وهم:** ⟵ **الشريطُ يبدو غيرَ متّزنٍ على
          //    طرفيه.**
          //
          // ✅ **والعلاج طرحُ فائض هدف اللمس من حشو النهاية** — ⟵ **فتتساوى
          //    المسافةُ *المرئية* على الطرفين** ⛔ **بلا تصغير هدف اللمس**:
          //    ★ **وهو ما تمنعه §5 البند 3 قطعاً** (48 حدٌّ أدنى لا يُنقَص).
          padding: const EdgeInsetsDirectional.only(
            start: Spacing.screenPadding,
            end: _avatarEdgeInset,
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

/// ★★ التاريخ وحالة الاتصال — **في عمودٍ واحد.**
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **ويتقلّص ولا يفيض ولا يُقصّ** — `AM-012` ① · `design-system.md` §8.
///
/// ⚠️⚠️ **وهو عطلٌ مقيسٌ وقع فعلاً لحظةَ إضافة السنة، لا احتياطٌ نظري:**
/// ★ **الحقلُ الثالث زاد عرضَ العمود** ⟹ ⛔ **`RenderFlex overflowed by 18px`
/// على عرض 320، و`49px` عند `textScaler` 2.0** — ★ **رصدهما اختبارا التجاوب
/// القائمان قبل أي مراجعة.**
///
/// ⛔⛔⛔★★★ **وتصحيحٌ ثانٍ رآه المالكُ على الجهاز (2026-09-02) — والخطأ
/// كان في علاجي الأول لا في الشريط:**
///
/// ★ **عالجتُ الفيضانَ أولاً بـ[Flexible] حول هذا العمود** — ⟹ ⛔⛔ **فصار
/// ابناً مرناً يحجز حصّةً من الفراغ الحر ولا يُعيد فائضَها:** ⟵ **والهويةُ
/// [Expanded] تأخذ حصّتَها وحدَها**، ★ **فيتقاسمان الفراغَ نصفين** ⟹
/// **ويبقى ما لم يستعمله العمودُ فراغاً ميتاً يضعه `MainAxisAlignment.start`
/// عند النهاية** — ⛔ **أي بين الصورة الرمزية وحافة الشاشة.**
///
/// ⚠️⚠️ **ومقيسٌ لا مُستنتَج:** ★ **`Row` من 10 إلى 784، والصورةُ الرمزية
/// عند 133** ⟹ ⛔ **123 بكسلاً فراغاً ميتاً** — ★ **وهو حرفياً ما رآه المالك
/// وسمّاه «مسافة فارغة».**
///
/// ✅★★★ **والعلاجُ الصحيح: عمودٌ غيرُ مرن بسقفِ عرضٍ صريح** — ⟵ **فلا
/// يحجز حصّةً أصلاً** ⟹ **والهويةُ [Expanded] تبتلع الفراغَ الحرَّ كلَّه**
/// ⛔ **فلا يبقى فراغٌ ميت**، ★ **والسقفُ يمنح [FittedBox] حدّاً تتقلّص
/// إليه عند تكبير الخط.**
///
/// ⛔⛔★★ **ودرسٌ يُكتب صريحاً:** ★ **[Flexible] بـ`FlexFit.loose` تحجز
/// حصّةً كاملة وتستعمل ما تحتاجه وحدَه** — ⟵ **والفائضُ لا يُعاد توزيعُه**،
/// ⛔ **فهي ليست «تتقلّص عند الحاجة» بل «تأخذ حصّةً وقد تُهدر بعضَها».**
///
/// ★★★ **والعلاج [FittedBox] بـ`scaleDown` لا قصٌّ ولا إخفاء — والفرق مقصود:**
///   ① ⛔ **القصُّ (`ellipsis`) على تاريخٍ يُنتج «02 / 09 / 20…»** — ⟵ **سنةٌ
///      مبتورة أسوأُ من غياب السنة كلِّه**، ★ **وهو ما جئنا نُصلحه.**
///   ② ⛔ **والإخفاءُ يخالف §3-أ القاعدة 4 نصّاً** — ★ **اسمُ الشاشة وحدَه
///      هو ما يُقصّ عند الضيق**، ⛔ **ولا تختفي حالةُ الاتصال ولا التاريخ.**
///   ③ ✅ **والتقلّصُ يُبقي المعلومة كاملةً مقروءةً** — ⟵ **وهو الوحيد الذي
///      يحترم `textScaler` بلا أن يُسقط شيئاً.**
///
/// ★ **والسقفُ شرطٌ لازم للعلاج لا زينة:** ⟵ **ابنٌ غيرُ مرنٍ في `Row`
/// يُخطَّط بعرضٍ غير محدود**، ⛔ **فـ[FittedBox] بلا حدٍّ لا تتقلّص أبداً** —
/// ★ **وهو نفسُ درسِ `DEBT-63`: القيدُ هو ما يحكم لا الويدجت.**
/// ═══════════════════════════════════════════════════════════════════════
class _DayAndConnection extends StatelessWidget {
  const _DayAndConnection({required this.today, required this.connection});

  final CalendarDay today;
  final ConnectionStatus connection;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
        // ★★ **سقفٌ نسبيٌّ لا رقمٌ محفور** — ⟵ **فيصحّ على كل عرضِ شاشة.**
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * _dayColumnMaxWidthRatio,
        ),
        child: Column(
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
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerEnd,
                    child: Text(
                      topBarDayLabel(today),
                      // ★★ **أرقامٌ جدولية** — ⟵ **فعرضُ التاريخ لا يهتزّ بين
                      //    يومٍ وآخر** فيُزيح ما بجانبه (§6.د).
                      // ⛔ **ولا يُلفّ التاريخ سطرين** — ★ **حقلٌ واحدٌ يُقرأ
                      //    مرةً واحدة.**
                      maxLines: 1,
                      softWrap: false,
                      style: TypeScale.numeric
                          .copyWith(color: SemanticColors.textPrimary),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: Spacing.space2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerEnd,
              child: ConnectionIndicator(status: connection),
            ),
          ],
        ),
      );
}

/// ★★★ **يوم ثم شهر ثم سنة — في اتجاه القراءة العربية** (`AM-012` ①).
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **والنصُّ يُبنى `سنة / شهر / يوم` عمداً — ⛔ ولا تُقلَب هذه السطور:**
///
/// ★★★ **الشريطُ يُقرأ من اليمين** — ⟵ **فأولُ ما تقع عليه العينُ هو الطرفُ
/// الأيمن**: ⟹ **ووضعُ اليوم هناك يعني كتابتَه *آخرَ* النصّ** داخل اتجاهٍ
/// لاتينيٍّ مفروض.
///
/// ⚠️⚠️★★★ **وهذا تصحيحُ خطأٍ وقع فعلاً في `AM-012` وأبلغ عنه المالك
/// (2026-09-02):** ★ **نُفِّذ أولاً `02 / 09 / 2026`** — ⟵ **فرأى المالكُ
/// على الجهاز أن **السنةَ تظهر أولاً**، ⛔ **لأن قراءتَه تبدأ من اليمين
/// حيث تقع `2026`.** ⟹ ★ **والخطأ كان في افتراضي أن «الأول» هو الطرفُ
/// الأيسر** ⛔ **لا في ترتيب الحقول نفسِه.**
///
/// ⛔⛔ **ولا يُقاس على هذا [CalendarDay.formatReadable]** — ★ **تلك
/// `YYYY/MM/DD` مقصودةٌ كذلك**: ⟵ **صيغةٌ مرتّبةٌ تُقرأ ويُفرَز بها**،
/// ⛔ **ولها قارئٌ سحابيٌّ يكتبها نصّاً مخزَّناً** (`FR-M12-11`).
///
/// ⛔⛔★★★ **وكانت `يوم / شهر` بلا سنة قبل `AM-012` — وهو عطلُ قراءةٍ مقيسٌ
/// لا ذوق:**
///
/// ★ **بقيةُ التطبيق كلُّها تعرض `YYYY/MM/DD`** ([CalendarDay.formatReadable]
/// — سجلُّ التدقيق والرسائلُ والمستنداتُ المُصدَّرة) ⟵ **أي «الأكبرُ أولاً».**
/// ★ **وكان الشريطُ وحدَه يعرض حقلين اثنين بالترتيب المعاكس** (`DD / MM`)
/// ⟹ ⛔⛔ **فالقارئُ الذي تعوّد النمطَ الأول يقرأ الحقلَ الأول شهراً**،
/// ⟵ **و«05 / 01» تُقرأ «يناير الخامس» بينما هي «الخامسُ من يناير»** —
/// ★ **وهو التباسٌ في تاريخٍ لا يُغتفَر في نظامٍ ماليّ** (`RISK-05`).
///
/// ✅ **والعلاجُ حقلٌ ثالث لا تبديلُ الحقلين:** ⟵ **ثلاثةُ حقولٍ لا تحتمل
/// إلا قراءةً واحدة**، ⛔ **بينما حقلان يحتملان قراءتين.**
///
/// ⛔⛔★★★ **و[CalendarDay.formatReadable] لم تُمَسّ بحرف** — ★ **بقرارِ
/// المالك الصريح في `AM-012` §2 السؤال ①**: ⟵ **لأن لها قارئاً ثانياً خارج
/// الشاشة** — **العمليةُ السحابية تكتب بها بيانَ تطبيق الفائض نصّاً
/// مخزَّناً** (`FR-M12-11`) ⛔ **وتغييرُها كان يجعل نصّاً كُتب أمسِ يُقرأ
/// اليوم بصيغةٍ أخرى.**
///
/// ⚠️⚠️ **وثمنُه معلَنٌ لا مكتوم: صيغتان للتاريخ في التطبيق** — ★ **مقبولٌ
/// هنا لأن الشريطَ يعرض «اليوم» لا تاريخَ حدثٍ يُقارَن بغيره**، ⟵ **فلا
/// موضعَ يُوضَع فيه الرقمان جنباً إلى جنب.**
/// ═══════════════════════════════════════════════════════════════════════
///
/// ⛔ **وبصفرٍ بادئ في اليوم والشهر دائماً** — ⟵ **فعرضُ النصّ ثابتٌ طوال
/// الشهر** ⛔ **ولا يهتزّ ما بجانبه.**
String topBarDayLabel(CalendarDay day) => '${day.year} / '
    '${_twoDigits(day.month)} / ${_twoDigits(day.day)}';

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

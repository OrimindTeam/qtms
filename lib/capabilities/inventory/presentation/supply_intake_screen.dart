/// ★★★ **شاشة «التوريد مخزني»** — `AM-012` §2 (2026-09-02).
///
/// ═══════════════════════════════════════════════════════════════════════
/// ⛔⛔★★★ **شاشةٌ واحدة بتبويبين حلّت محلّ شاشتين مستقلتين** — **بطلب
/// المالك نصّاً:** «**تُدمج شاشة الوارد عدداً وشاشة الوارد جواني في شاشة
/// جديدة واحدة باسم التوريد مخزني**».
///
/// ★★ **والتبويبان [CountedIntakeTab] و[SackIntakeTab]** — ★ **بكامل
/// محتواهما ووظائفهما** ⛔ **بلا نقصان** (نصُّ الطلب حرفياً).
///
/// ⛔⛔★★★ **ومرشِّحُ المصدر واحدٌ للتبويبين** — **بنصِّ الطلب:** «**تغييرُه
/// من أيٍّ منهما ينعكس على الآخر فوراً، ولا يوجد فلتر مصدر مستقل لكل
/// تبويب**». ⟵ ★ **والتنفيذُ بنيويٌّ لا مزامنة:** **مزوّدٌ واحد
/// `sourceListFilterProvider` يقرؤه التبويبان** ⛔ **ولا حالةَ ثانية
/// تُنسَخ ثم تفترق** (`coding-standards.md` §2.2).
///
/// ★★★ **ورأسُ السياق فوق شريط التبويبات لا داخله** — `ui-guidelines.md`
/// §3 نمط 3: «★ **الرأس لا يتحرك مع تبديل التبويب**» ⟵ **فالمرشِّحُ يبقى
/// في موضعه بصرياً**، ⛔ **ولا يقفز بين التبويبين فيبدو مرشِّحَين.**
///
/// ⚠️⚠️★★ **وسؤالٌ حُسم قبل التنفيذ ولم يُخمَّن** (`AM-012` §2 السؤال ②):
/// ★ **الشاشتان كانتا تستعملان مرشِّحَي مصدرٍ مختلفَي الدلالة قصداً** —
/// «عدداً» يقبل «كل المصادر» (`AM-009` ③) و«جواني» يمنعها (`A-01`).
/// ⟹ ★ **وقرارُ المالك: «الكل» في التبويبين + حقلُ مصدرٍ في نموذج الجونية**
/// ⛔ **لا إسقاطَ «الكل» من التبويب الأول.**
/// ═══════════════════════════════════════════════════════════════════════
///
/// ⚠️⚠️ **وكل بوابة صلاحية هنا إخفاءٌ لا حماية** — ★ **والرفض في السحابة**
/// (`ADR-0013` القاعدة 3 · `RISK-02`).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qtms_domain/qtms_domain.dart';

import '../../../app/top_bar.dart';
import '../../../core/ui/context_header.dart';
import '../../master_data/application/master_data_providers.dart';
import '../application/inventory_providers.dart';
import 'counted_intake_screen.dart';
import 'sack_intake_screen.dart';

/// ★★ **اسمُ الشاشة كما يقرؤه المستخدم** — ⛔ **ولا نصٌّ محفورٌ في موضعين.**
///
/// ★ **يقرؤه الشريطُ العلوي ومدخلُ الصدَفة معاً** — ⟵ **فلا يفترقان عند
/// أول تعديل** (`coding-standards.md` §2.2).
const String supplyIntakeScreenTitle = 'التوريد مخزني';

/// ★ عنوانُ التبويب الأول — `AM-012` §2.
const String countedIntakeTabTitle = 'الوارد عدداً';

/// ★ عنوانُ التبويب الثاني — `AM-012` §2.
const String sackIntakeTabTitle = 'الوارد جواني';

/// ★★ **رقمُ تبويب «الوارد عدداً»** — ⛔ **ولا رقمٌ محفورٌ في مُستدعٍ.**
const int supplyIntakeCountedTab = 0;

/// ★★ **رقمُ تبويب «الوارد جواني»** — ★ **يقرؤه مركزُ الإدخالات المعلّقة.**
///
/// ⛔⛔ **ولا `1` عارية في `pending_entries_screen.dart`** — ★ **ورقمٌ محفورٌ
/// في مُستدعٍ يفترق عن ترتيب التبويبات عند أول إعادة ترتيب**، ⟵ **فيُفتَح
/// البندُ على تبويبٍ لا يخصّه** ⛔ **بلا خطأٍ ظاهر** (`coding-standards.md` §2.2).
const int supplyIntakeSackTab = 1;

/// شاشة التوريد المخزني — تبويبان بمرشِّحٍ مشترك.
class SupplyIntakeScreen extends ConsumerStatefulWidget {
  /// ينشئ الشاشة.
  const SupplyIntakeScreen({
    this.initialTab = supplyIntakeCountedTab,
    super.key,
  });

  /// ★★ **التبويبُ المفتوح عند الدخول** — ⛔ **و`0` هو «الوارد عدداً».**
  ///
  /// ⚠️★★ **ولماذا مُدخَلٌ لا معاملٌ في المسار:** ★ **مركزُ الإدخالات
  /// المعلّقة يفتح الشاشة على تبويب الجواني** (`PendingScreen.sackIntake`)
  /// — ⟵ **وهي *وجهةُ ملاحةٍ داخلية* لا رابطٌ يُشارَك**، ⛔ **ومعاملٌ في
  /// المسار كان يصير طريقاً ثانياً لفتح الشاشة** (نفسُ علّة `auditLogRoute`
  /// و`pendingEntriesRoute` في `router.dart`).
  final int initialTab;

  @override
  ConsumerState<SupplyIntakeScreen> createState() => _SupplyIntakeScreenState();
}

class _SupplyIntakeScreenState extends ConsumerState<SupplyIntakeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(
    length: 2,
    vsync: this,
    initialIndex: widget.initialTab,
  )..addListener(_onTabChanged);

  @override
  void dispose() {
    _tabs
      ..removeListener(_onTabChanged)
      ..dispose();
    super.dispose();
  }

  /// ⛔⛔★★ **وزرُّ الإضافة يتبدّل مع التبويب** — ★ **ولا زرَّ واحدٌ لعمليتين:**
  /// ⟵ **«وارد عدداً جديد» و«جونية جديدة» مستندان مختلفان بصلاحيتين
  /// مختلفتين** (`incomingCountWrite` مقابل `sackCreate` · `IQ-021`)،
  /// ⛔ **وزرٌّ واحدٌ يفتح أحدهما بحسب تبويبٍ خفيّ كان يُنتج مستنداً غير
  /// المقصود بنقرةٍ واحدة.**
  void _onTabChanged() {
    // ★ **ولا إعادةَ بناءٍ أثناء الانزلاق** — ⟵ **فالزرُّ يتبدّل مرةً واحدة
    //   عند استقرار التبويب** ⛔ **لا مع كل إطارِ حركة.**
    if (_tabs.indexIsChanging) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final CalendarDay today = ref.watch(todayProvider);
    // ★★★ **مرشِّحٌ واحدٌ للتبويبين** — `AM-012` §2 · و`null` تعني «الكل».
    final String? filterId = ref.watch(sourceListFilterProvider);
    final List<SourceCard> sources = ref.watch(activeSourcesProvider);

    return Scaffold(
      appBar: const QtmsTopBar(screenTitle: supplyIntakeScreenTitle),
      // ⛔ **والزرُّ يتبع التبويب** — راجع [_onTabChanged].
      floatingActionButton:
          _tabs.index == 0 ? const CountedIntakeFab() : const SackIntakeFab(),
      body: Column(
        children: <Widget>[
          // ★★★ **رأسُ السياق مشتركٌ فوق التبويبات** — ⛔ **ولا نسخةَ في كل
          //    تبويب:** ⟵ **«لا تكرار للمعلومة بين التبويبات»**
          //    (`ui-guidelines.md` §3 نمط 3) — ★ **والمرشِّحُ واحدٌ فعلاً
          //    لا اثنان مُتزامنان.**
          QtmsContextHeader(
            sources: sources,
            selectedSourceId: filterId,
            // ★★★ **وخيارُ «كل المصادر» في التبويبين معاً** — `AM-012` §2
            //    (قرارُ المالك في §2 السؤال ②).
            allowAllSources: true,
            onSourceSelected: (String? id) =>
                ref.read(sourceListFilterProvider.notifier).select(id),
            day: today,
          ),
          // ★★ **مؤشّرٌ بخطٍّ سفلي** — `design-system.md` §7 (التبويبات):
          //    «★ **يبقى موجوداً في الحالتين فلا تقفز التبويبات**».
          // ⛔⛔★★★ **ولا قيمةَ لونٍ ولا حجمِ خطٍّ هنا إطلاقاً** — ★ **الشكلُ
          //    كلُّه في `tabBarTheme`** (`app_theme.dart`): ⟵ **فالشاشةُ لا
          //    تعرف مصدرَ لونها** (`design-tokens.md` §1)، ⛔ **واستدعاءُ
          //    الطبقة الأولية من شاشةٍ تُسقِطه بوابةٌ آلية** (`AM-007`).
          TabBar(
            controller: _tabs,
            tabs: const <Widget>[
              Tab(text: countedIntakeTabTitle),
              Tab(text: sackIntakeTabTitle),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: const <Widget>[
                CountedIntakeTab(),
                SackIntakeTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

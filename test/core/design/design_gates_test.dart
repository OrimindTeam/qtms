/// ★★ **بوابات التصميم الآلية** — `ui-guidelines.md` §8 · `design-tokens.md` §11.
///
/// ⚠️⚠️ **ولماذا اختبارٌ لا فقرةٌ في مستند:** ★ **المستند كان يقول «فحص آلي
/// يرفض أي قيمة يدوية» منذ أول يوم** — ⛔ **ولم يكن هناك فحص.** ★ **والنصّ
/// يصف نيّة، والاختبار وحده يفرضها**؛ وهذا حرفياً ما يحذّر منه المستند نفسه:
/// «**بلا هذه البوابة تتسرّب القيم اليدوية خلال أسابيع ويسقط النظام إلى مجرد
/// توصية**».
///
/// ★★ **والبوابتان الجديدتان (`AM-003`) تحرسان قراري المالك:**
/// **وضعٌ واحد فاتح** · **ولغةٌ واحدة عربية باتجاه RTL ثابت** — ★ **فالعودة
/// إليهما تحتاج إسقاط اختبار، لا مجرد سطرٍ يمرّ في مراجعة.**
library;

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qtms/core/design/app_theme.dart';
import 'package:qtms/core/design/design_tokens.dart';
import 'package:qtms/core/design/theme_extensions.dart';

// ═══════════════════════════ أدوات القراءة ═══════════════════════════

/// ملف Dart مقروءاً بثلاث صور — ★ **لأن كل بوابة تحتاج صورةً مختلفة.**
///
/// ⚠️ ★ **ولماذا لا يكفي `grep` على النصّ الخام:** ★ **التعليقات في هذا
/// المشروع تذكر `ThemeMode` و`Color(0x` وهي تشرح لماذا مُنعا** — ⟵ **فبحثٌ
/// خام يرفض الشرح نفسه.** ★ **ولذلك تُنزَع التعليقات أولاً.**
class _Source {
  _Source(this.path, this.withLiterals, this.code, this.literals);

  /// المسار كما يُعرَض في رسالة الفشل.
  final String path;

  /// بلا تعليقات — ★ **مع إبقاء محتوى النصوص** (للبحث عن `Locale('ar')`).
  final String withLiterals;

  /// بلا تعليقات وبلا محتوى نصوص — ★ **للبحث عن القيم البصرية وحدها.**
  final String code;

  /// النصوص الحرفية بأسطرها.
  final List<_Literal> literals;
}

/// نصّ حرفي واحد بموضعه.
class _Literal {
  _Literal(this.value, this.line, this.onDirective);

  final String value;
  final int line;

  /// هل هو على سطر `import` / `export` / `part`؟ ⟵ **مسار حزمة لا نصّ واجهة.**
  final bool onDirective;
}

/// ★ **مُحلِّل صغير**: ينزع التعليقات، ويجمع النصوص، ويُفرغ محتواها من الكود.
///
/// ⛔ **لا يفهم Dart كاملة** — ★ **ولا يحتاج**: يكفي أن يميّز التعليق من النصّ
/// من الكود، ★ **وأن يتعامل مع `${...}` بعدّ الأقواس** كي لا ينكسر على
/// `'${a.b(1)}'`.
_Source _scan(String path) {
  final String raw = File(path).readAsStringSync().replaceAll('\r\n', '\n');
  final StringBuffer withLiterals = StringBuffer();
  final StringBuffer code = StringBuffer();
  final List<_Literal> literals = <_Literal>[];

  int i = 0;
  int line = 1;
  while (i < raw.length) {
    final String ch = raw[i];

    if (ch == '\n') {
      line++;
      withLiterals.write('\n');
      code.write('\n');
      i++;
      continue;
    }

    // تعليق سطري.
    if (ch == '/' && i + 1 < raw.length && raw[i + 1] == '/') {
      while (i < raw.length && raw[i] != '\n') {
        i++;
      }
      continue;
    }

    // تعليق كتلي.
    if (ch == '/' && i + 1 < raw.length && raw[i + 1] == '*') {
      i += 2;
      while (i + 1 < raw.length && !(raw[i] == '*' && raw[i + 1] == '/')) {
        if (raw[i] == '\n') {
          line++;
          withLiterals.write('\n');
          code.write('\n');
        }
        i++;
      }
      i += 2;
      continue;
    }

    if (ch == "'" || ch == '"') {
      final int startLine = line;
      final String quote = ch;
      final bool triple = raw.startsWith(quote * 3, i);
      final String closer = triple ? quote * 3 : quote;
      i += closer.length;

      final StringBuffer value = StringBuffer();
      while (i < raw.length && !raw.startsWith(closer, i)) {
        if (raw[i] == '\\') {
          value.write(raw.substring(i, (i + 2).clamp(0, raw.length)));
          i += 2;
          continue;
        }
        // ★ تعبير مُدمَج: يُنسَخ كما هو بعدّ الأقواس — ⛔ فلا تُخلَط اقتباساته.
        if (raw[i] == r'$' && i + 1 < raw.length && raw[i + 1] == '{') {
          int depth = 0;
          final int open = i;
          while (i < raw.length) {
            if (raw[i] == '{') {
              depth++;
            } else if (raw[i] == '}') {
              depth--;
              if (depth == 0) {
                i++;
                break;
              }
            } else if (raw[i] == '\n') {
              line++;
            }
            i++;
          }
          value.write(raw.substring(open, i));
          continue;
        }
        if (raw[i] == '\n') {
          line++;
        }
        value.write(raw[i]);
        i++;
      }
      i += closer.length;

      final String text = value.toString();
      literals.add(
        _Literal(text, startLine, _isDirectiveLine(raw, startLine)),
      );
      withLiterals.write("'$text'");
      // ⛔ الكود يرى نصّاً فارغاً — ★ فلا يُحسَب محتواه قيمةً بصرية.
      code.write("''");
      continue;
    }

    withLiterals.write(ch);
    code.write(ch);
    i++;
  }

  return _Source(path, withLiterals.toString(), code.toString(), literals);
}

bool _isDirectiveLine(String raw, int lineNumber) {
  final List<String> lines = raw.split('\n');
  if (lineNumber - 1 >= lines.length) {
    return false;
  }
  final String text = lines[lineNumber - 1].trimLeft();
  return text.startsWith('import ') ||
      text.startsWith('export ') ||
      text.startsWith('part ');
}

/// كل ملفات Dart تحت `lib/`.
List<_Source> _libSources() {
  final Directory dir = Directory('lib');
  if (!dir.existsSync()) {
    // ⛔ لا `expect` هنا — ★ **تُستدعى الدالة خارج جسم اختبار.**
    throw StateError('مجلد lib غائب — يُشغَّل الاختبار من جذر المشروع');
  }
  return dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((File f) => f.path.endsWith('.dart'))
      .map((File f) => _scan(f.path))
      .toList()
    ..sort((_Source a, _Source b) => a.path.compareTo(b.path));
}

/// مسارٌ مطبَّع بشرطةٍ أمامية — ★ **موضعٌ واحد** ⛔ **لا تعبيرٌ مكرَّر.**
String _slash(String path) => path.replaceAll(r'\', '/');

/// هل المسار داخل طبقة التوكنز نفسها؟ ⟵ **وهي وحدها التي تملك القيم الخام.**
bool _isTokenLayer(String path) =>
    path.replaceAll(r'\', '/').contains('lib/core/design/');

// ═══════════════════════ حساب التباين — WCAG 2.1 ═══════════════════════

/// ★★ نسبةُ تباينٍ فعلية بين لونين — ⛔ **لا تقديرٌ بالعين.**
///
/// ⚠️⚠️ **ولماذا تُحسَب هنا لا تُكتَب رقماً في مستند** (`AM-007`): ★ **المستند
/// كان يقول «كل أزواج `soft × ink` مصمَّمة لتجاوز 4.5:1» منذ أول يوم** —
/// ⛔ **ولم يكن هناك حساب.** ⟵ **فأيُّ إعادةِ اشتقاقٍ للهوية** (وقد حدثت
/// مرتين: `AM-003` ثم `AM-007`) **كانت تمرّ بلا فحصٍ واحد.**
double _contrast(Color a, Color b) {
  final double la = _relativeLuminance(a);
  final double lb = _relativeLuminance(b);
  final double hi = la > lb ? la : lb;
  final double lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

double _relativeLuminance(Color color) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(color.r) +
      0.7152 * channel(color.g) +
      0.0722 * channel(color.b);
}

/// ★★ لونٌ شفّافٌ **مخلوطٌ فعلياً** مع خلفيته.
///
/// ⛔⛔★★★ **ولا يُقاس نصٌّ شفّافٌ بلونه الاسمي** (`design-tokens.md` §11.1):
/// ★ **`onTie` بشفافية 78٪ فوق طرف التدرّج الفاتح ليس `onTie`** — ⟵ **وفرقُ
/// القراءة بينهما هو فرقُ النجاح والفشل** (5.54 مقابل 4.08).
Color _flatten(Color foreground, Color background) => Color.fromARGB(
      255,
      ((foreground.r * foreground.a + background.r * (1 - foreground.a)) * 255)
          .round(),
      ((foreground.g * foreground.a + background.g * (1 - foreground.a)) * 255)
          .round(),
      ((foreground.b * foreground.a + background.b * (1 - foreground.a)) * 255)
          .round(),
    );

/// ★ ألوانُ تدرّجٍ خطّي — **لقياس أسوأ طرفٍ فيه.**
///
/// ⛔⛔ **ولا يُقاس زوجٌ بطرفِ تدرّجٍ واحد:** ★ **الرِباطُ داكنٌ إلى أفتح**،
/// ⟵ **والنصُّ الفاتح يفي بالحدّ على الطرف الداكن ويسقط على الفاتح.**
List<Color> _stops(Gradient gradient) => (gradient as LinearGradient).colors;

/// هل الملف من طبقة العرض أو من كتالوجات الرسائل؟
bool _isUserFacing(String path) {
  final String p = path.replaceAll(r'\', '/');
  // ⚠️⚠️ **و`lib/core/ui/` مشمولةٌ عمداً** — ★ **مكوّناتُ الواجهة
  //    المشتركة تحمل نصّاً عربياً معروضاً** («تعذّر عرض البيانات»)، ⟵ **وتركُها
  //    خارج البوابة كان يفتح باباً لنصٍّ لاتيني يعبر بلا فحص.**
  return p.contains('/presentation/') ||
      p.contains('lib/core/ui/') ||
      p.contains('lib/core/messages/');
}

/// يُبلّغ عن كل مخالفة بمسارها وسطرها — ⛔ **لا عن الأولى وحدها.**
void _expectNoMatches(
  Iterable<_Source> sources,
  String Function(_Source) view,
  Map<String, RegExp> rules,
) {
  final List<String> hits = <String>[];
  for (final _Source source in sources) {
    final List<String> lines = view(source).split('\n');
    for (int n = 0; n < lines.length; n++) {
      for (final MapEntry<String, RegExp> rule in rules.entries) {
        if (rule.value.hasMatch(lines[n])) {
          hits.add('${source.path}:${n + 1} ⟵ ${rule.key} :: ${lines[n].trim()}');
        }
      }
    }
  }
  expect(hits, isEmpty, reason: '\n${hits.join('\n')}\n');
}

/// نصّ بلا تعبيراته المُدمَجة — ★ **فالقيمة المحسوبة ليست نصّ واجهة.**
String _withoutInterpolation(String value) =>
    value.replaceAll(RegExp(r'\$\{[^}]*\}'), '').replaceAll(
          RegExp(r'\$[A-Za-z_][A-Za-z0-9_]*'),
          '',
        );

final RegExp _latin = RegExp('[A-Za-z]');
final RegExp _arabic = RegExp('[؀-ۿ]');

/// ★ **أسماء أعلام لا مقابل عربي لها** — `rtl-ltr-guidelines.md` §5.
///
/// ⛔ **والقائمة مغلقة عمداً:** ★ **استثناءٌ مفتوح يُبطل البوابة بهدوء.**
const Set<String> _properNouns = <String>{'Google Play'};

void main() {
  final List<_Source> lib = _libSources();

  // ══════════════════ ① بوابة التوكنز — `design-tokens.md` §11 ══════════════

  group('★ بوابة التوكنز', () {
    final Iterable<_Source> outsideTokens =
        lib.where((_Source s) => !_isTokenLayer(s.path));

    test('⛔ لا لون ولا حجم خط ولا نصف قطر ولا ظل خارج طبقة التوكنز', () {
      _expectNoMatches(outsideTokens, (_Source s) => s.code, <String, RegExp>{
        'لون خام': RegExp(r'Color\(\s*0x'),
        'لون من عائلة الإطار': RegExp(r'\bColors\.'),
        'حجم خط مكتوب مباشرة': RegExp(r'\bfontSize\s*:'),
        'ظل مكتوب يدوياً': RegExp(r'\bBoxShadow\s*\('),
        'نصف قطر برقم': RegExp(r'BorderRadius\.\w+\(\s*[\d.]'),
      });
    });

    test('⛔ ولا قيمة حشو أو هامش خارج سلّم المسافات', () {
      // ★ الرقم العاري وحده هو المرفوض — ★ و`Spacing.space8` رقمُه جزءُ اسم.
      final RegExp bareNumber = RegExp(r'(^|[^\w.])\d');
      final List<String> hits = <String>[];
      for (final _Source source in outsideTokens) {
        for (final Match m
            in RegExp(r'EdgeInsets(?:Directional)?\.\w+\(').allMatches(source.code)) {
          final String args = _balanced(source.code, m.end - 1);
          if (bareNumber.hasMatch(args)) {
            hits.add('${source.path} ⟵ EdgeInsets بقيمة عارية :: $args');
          }
        }
      }
      expect(hits, isEmpty, reason: '\n${hits.join('\n')}\n');
    });

    test('★★ وقيم `primary` مطابقة لـ`design-tokens.md` §2.2 حرفياً', () {
      // ⚠️ ★ يقرأ المستند نفسه ⛔ لا نسخةً منه — بنفس منطق حارس الصلاحيات:
      //    ★ تعديلُ المستند بلا تعديل الكود يُسقِط الاختبار، والعكس كذلك.
      final Map<String, String> doc = _documentedPrimaries();
      expect(doc.length, 10, reason: 'جدول §2.2 يجب أن يحمل عشر درجات');

      final Map<String, Color> implemented = <String, Color>{
        'primary50': Primitives.primary50,
        'primary200': Primitives.primary200,
        'primary400': Primitives.primary400,
        'primary500': Primitives.primary500,
        'primary700': Primitives.primary700,
      };

      for (final MapEntry<String, Color> entry in implemented.entries) {
        expect(
          doc.containsKey(entry.key),
          isTrue,
          reason: '${entry.key} غير موجود في §2.2',
        );
        expect(
          _hex(entry.value),
          doc[entry.key],
          reason: '★ ${entry.key} يخالف المستند',
        );
      }
    });

    test('⛔★★★ ولا استدعاءَ للطبقة الأولية خارج طبقة التوكنز — §1', () {
      // ⚠️⚠️ **وهذه ثغرةٌ كانت مفتوحةً حتى `AM-007`:** ★ **البوابةُ ترفض
      //    `Color(0x…)` و`Colors.*`** ⛔ **ولا ترفض `Primitives.dangerSoft`**،
      //    ⟵ **وهي مخالفةٌ لنفس القاعدة بحرفها**: §1 يقول «**الطبقة الأولية
      //    لا تُستدعى خارج ملف التوكنز إطلاقاً**». ★ **وكانت مخالَفةً في
      //    عشرة مواضع فعلاً** (سبعُ نسخٍ من شريطٍ واحد).
      _expectNoMatches(outsideTokens, (_Source s) => s.code, <String, RegExp>{
        'استدعاءُ الطبقة الأولية': RegExp(r'\bPrimitives\s*\.'),
      });
    });

    test('★★ و`focusRing` مشتقّ من `primary400` فعلاً لا قيمةً محفورة', () {
      // ⛔ **لو بقيت القيمة القديمة لظلّت حلقةُ التركيز كحلية بعد خضرة الأساس**
      //    — ★ وهي أكثر ما يفوت المراجعة البصرية لأنها تظهر لحظةً واحدة.
      expect(
        _hex(SemanticColors.focusRing).substring(2),
        _hex(Primitives.primary400).substring(2),
        reason: '★ focusRing يجب أن يحمل درجة primary400 نفسها',
      );
      expect(
        SemanticColors.focusRing.a,
        closeTo(0.40, 0.01),
        reason: '§3 يفرض شفافية 40٪',
      );
    });
  });

  // ═══════ ①-ب بوابة التباين — `design-tokens.md` §11.1 (`AM-007`) ═══════

  group('★★★ بوابة التباين', () {
    const QtmsHeroColors hero = QtmsHeroColors.standard();
    const QtmsCategoryColors cats = QtmsCategoryColors.standard();

    void expectAtLeast(String label, Color fg, Color bg, double minimum) {
      final double value = _contrast(fg, bg);
      expect(
        value,
        greaterThanOrEqualTo(minimum),
        reason: '★ $label — القياس ${value.toStringAsFixed(2)}:1 '
            'والحدّ ${minimum.toStringAsFixed(1)}:1',
      );
    }

    test('⛔★★★ كل زوج `soft × ink` لا يقل عن 4.5:1', () {
      final Map<String, ColorTriad> triads = <String, ColorTriad>{
        'success': SemanticTriads.success,
        'danger': SemanticTriads.danger,
        'warning': SemanticTriads.warning,
        'info': SemanticTriads.info,
        'primary': SemanticTriads.primary,
        'neutral': SemanticTriads.neutral,
        // ★ **والتصنيفيةُ الخمسُ مشمولةٌ عمداً** — ★ **بقيت بلا تغيير في
        //   `AM-007` بفحصٍ لا بافتراض**، ⟵ **والفحصُ هو هذا.**
        'cat1/identity': cats.identity,
        'cat2/masterData': cats.masterData,
        'cat3/inventory': cats.inventory,
        'cat4/receivables': cats.receivables,
        'cat5/cash': cats.cash,
      };
      for (final MapEntry<String, ColorTriad> e in triads.entries) {
        expectAtLeast('${e.key} soft×ink', e.value.ink, e.value.soft, 4.5);
      }
    });

    test('★★ والنصُّ على كل سطحٍ فاتح — 7:1 للرئيسي و4.5:1 لما دونه', () {
      final Map<String, Color> surfaces = <String, Color>{
        'surface': SemanticColors.surface,
        'bg': SemanticColors.background,
        'surfaceSunken': SemanticColors.surfaceSunken,
        // ★ **وطرفا تدرّج جسم البطاقة الرئيسية** — ⟵ **فالبطاقةُ فاتحةٌ الآن**
        //   ⛔ **ولا يكفي قياسُ `surface` وحده.**
        'heroSurface/start': _stops(hero.surfaceGradient).first,
        'heroSurface/end': _stops(hero.surfaceGradient).last,
      };
      for (final MapEntry<String, Color> s in surfaces.entries) {
        expectAtLeast(
            'textPrimary على ${s.key}', SemanticColors.textPrimary, s.value, 7);
        expectAtLeast('textSecondary على ${s.key}',
            SemanticColors.textSecondary, s.value, 4.5);
        expectAtLeast('textTertiary على ${s.key}', SemanticColors.textTertiary,
            s.value, 4.5);
      }
    });

    test('⛔★★★ والنصُّ على الرِباط يُقاس على أسوأ طرفٍ من تدرّجه', () {
      for (final Color stop in _stops(hero.tieGradient)) {
        expectAtLeast('onTie', hero.onTie, stop, 4.5);
        // ⛔⛔ **والتسميةُ بشفافيتها مخلوطةً فعلياً** — §11.1.
        expectAtLeast(
            'onTieLabel @${hero.labelOpacity}', _flatten(hero.onTieLabel, stop), stop, 4.5);
        expectAtLeast('successOnTie', hero.successOnTie, stop, 4.5);
        expectAtLeast('dangerOnTie', hero.dangerOnTie, stop, 4.5);
      }
    });

    test('★ والنصُّ على الأسطح الداكنة والأزرار الأساسية', () {
      expectAtLeast('textOnPrimary على primary500', SemanticColors.textOnPrimary,
          Primitives.primary500, 4.5);
      expectAtLeast('textOnInverse على surfaceInverse',
          SemanticColors.textOnInverse, SemanticColors.surfaceInverse, 4.5);
    });

    test('★ والأيقوناتُ والحدودُ الدالّة لا تقل عن 3:1 على السطح', () {
      final Map<String, Color> bases = <String, Color>{
        'successBase': Primitives.successBase,
        'dangerBase': Primitives.dangerBase,
        'warningBase': Primitives.warningBase,
        // ★★ **و`infoBase` أُدرِج بـ`IQ-028`** (الخيار ب · 2026-08-29): ⟵ **صار
        //    لوناً دالاًّ فعلياً لا محايداً ورقياً**، ★ **فيلزمه حدُّ الأيقونات**
        //    ⛔ **ولا يُستثنى لأنه استثناءُ `DS-003`** — ★ **الاستثناءُ في
        //    مصدر اللون لا في بوابته.**
        'infoBase': Primitives.infoBase,
        'primary400': Primitives.primary400,
        'primary500': Primitives.primary500,
      };
      for (final MapEntry<String, Color> b in bases.entries) {
        expectAtLeast('${b.key} على surface', b.value, SemanticColors.surface, 3);
      }
    });
  });

  // ═════ ①-ج بوابة خط العرض الثاني — `design-tokens.md` §5-أ (`AM-007`) ═════

  group('★★★ بوابة خط العرض', () {
    test('⛔⛔★★★ ولا رقمَ بخط `Tajawal` — أرقامه متغيّرة العرض وبلا `tnum`', () {
      // ★ **الفحصُ بنيويٌّ لا نصّي:** ★ **أيُّ نمطٍ يحمل عائلةَ خط العرض
      //   يجب أن يخلو من ميزةِ الأرقام الجدولية**، ⟵ **لأن حملَه لها ادّعاءٌ
      //   لا مفعول له** ⛔ **يُتجاهَل بصمت فيرتجّ العمود.**
      const Map<String, TextStyle> displayTokens = <String, TextStyle>{
        'displayTitleLg': TypeScale.displayTitleLg,
        'displayTitleSm': TypeScale.displayTitleSm,
      };
      for (final MapEntry<String, TextStyle> e in displayTokens.entries) {
        expect(
          e.value.fontFamily,
          qtmsDisplayFontFamily,
          reason: '★ ${e.key} يجب أن يحمل عائلة خط العرض صريحةً',
        );
        expect(
          e.value.fontFeatures ?? const <FontFeature>[],
          isEmpty,
          reason: '⛔ ${e.key} لا يحمل ميزةَ أرقامٍ — الخط لا يدعمها',
        );
      }
    });

    test('★★ وكلُّ نمطٍ رقميٍّ على خط الجسم — ⛔ ولا عائلةَ عرضٍ فيه', () {
      const Map<String, TextStyle> numeric = <String, TextStyle>{
        'numeric': TypeScale.numeric,
        'numericSm': TypeScale.numericSm,
        'numericDisplay': TypeScale.numericDisplay,
      };
      for (final MapEntry<String, TextStyle> e in numeric.entries) {
        expect(
          e.value.fontFamily,
          isNot(qtmsDisplayFontFamily),
          reason: '⛔ ${e.key} لا يُسنَد لخط العرض إطلاقاً',
        );
        expect(
          e.value.fontFeatures,
          TypeScale.tabular,
          reason: '★ ${e.key} أرقامٌ جدولية إلزاماً — §5',
        );
      }
    });

    test('★ والوزنان المضمَّنان في `pubspec.yaml` هما 800 و900 فقط', () {
      // ⚠️ **يقرأ `pubspec.yaml` نفسه** ⛔ **لا نسخةً منه:** ★ **طلبُ وزنٍ غير
      //    مضمَّن يقع على أقربه بلا إنذار** — ⟵ **فيبدو العنوانُ أثقلَ مما
      //    يقصد التوكن.** ★ **والعائلةُ لا تحمل 600 أصلاً.**
      final String pubspec = File('pubspec.yaml').readAsStringSync();
      final int start = pubspec.indexOf('- family: $qtmsDisplayFontFamily');
      expect(start, isNot(-1), reason: '★ عائلةُ خط العرض غير مسجَّلة');
      final String block = pubspec.substring(start);
      final List<String> weights = RegExp(r'weight:\s*(\d+)')
          .allMatches(block)
          .map((Match m) => m.group(1)!)
          .toList();
      expect(weights, <String>['800', '900']);

      for (final String file in <String>[
        'assets/fonts/Tajawal-ExtraBold.ttf',
        'assets/fonts/Tajawal-Black.ttf',
        // ★ **ورخصتُه ملفٌّ مستقل** — ⛔ **لا تُدمَج مع رخصةِ خطِّ الجسم:**
        //   ★ **مالكا حقوقٍ مختلفان ودمجُهما يُفقد أحدَ الإسنادين.**
        'assets/fonts/OFL-Tajawal.txt',
      ]) {
        expect(
          File(file).existsSync(),
          isTrue,
          reason: '★ الأصلُ $file مفقود',
        );
      }
    });

    test('★★ والوزنان مطابقان لجدول §5 من مستند الخطوط', () {
      expect(TypeScale.displayTitleLg.fontWeight, FontWeight.w900);
      expect(TypeScale.displayTitleSm.fontWeight, FontWeight.w800);
    });
  });

  // ══════════════════ ② بوابة الاتجاه — `rtl-ltr-guidelines.md` §1 ═══════════

  test('★ بوابة الاتجاه — ⛔ لا قيمة موضعية بـ«يمين/يسار»', () {
    _expectNoMatches(lib, (_Source s) => s.code, <String, RegExp>{
      'حشو/هامش بـ left أو right': RegExp(
        r'EdgeInsets\.only\(\s*(left|right)\s*:',
      ),
      'حشو بأربع قيم موضعية': RegExp(r'EdgeInsets\.fromLTRB\s*\('),
      'محاذاة غير اتجاهية': RegExp(r'Alignment\.\w*(Left|Right)\b'),
      'محاذاة نصّ غير اتجاهية': RegExp(r'TextAlign\.(left|right)\b'),
      'نصف قطر لزاوية غير اتجاهية': RegExp(
        r'BorderRadius\.only\([^)]*(topLeft|topRight|bottomLeft|bottomRight)',
      ),
      'موضع مطلق غير اتجاهي': RegExp(r'Positioned\(\s*(left|right)\s*:'),
    });
  });

  // ══════════════════ ③ بوابة الوضع الواحد — `AM-003` ═══════════════════════

  test('★★ بوابة الوضع الواحد — ⛔ ولا أثر حيّ لوضع داكن', () {
    // ⚠️ ★ التعليقات منزوعة قبل الفحص — ★ **فشرحُ المنع لا يُحسَب مخالفة**،
    //    ⛔ وإلا لصار الاختبار يمنع توثيق سبب المنع.
    _expectNoMatches(lib, (_Source s) => s.code, <String, RegExp>{
      'اختيار وضع': RegExp(r'\bThemeMode\b'),
      'سمة داكنة': RegExp(r'\bdarkTheme\b'),
      'سمة جاهزة داكنة': RegExp(r'\bThemeData\.dark\b'),
      'طقم ألوان داكن': RegExp(r'ColorScheme\.dark\b'),
      'سطوع داكن': RegExp(r'Brightness\.dark\b'),
      'قراءة تفضيل النظام': RegExp(r'\bplatformBrightness\b'),
    });
  });

  // ══════════════════ ④ بوابة اللغة الواحدة — `AM-003` ══════════════════════

  group('★★ بوابة اللغة الواحدة', () {
    test('⛔ لا لغة غير العربية ولا آلية اختيار لغة', () {
      final List<String> hits = <String>[];
      for (final _Source source in lib) {
        for (final Match m
            in RegExp(r"Locale\(\s*'([^']*)'").allMatches(source.withLiterals)) {
          if (m.group(1) != 'ar') {
            hits.add("${source.path} ⟵ لغة غير العربية: '${m.group(1)}'");
          }
        }
      }
      expect(hits, isEmpty, reason: '\n${hits.join('\n')}\n');

      _expectNoMatches(lib, (_Source s) => s.code, <String, RegExp>{
        'اشتقاق لغة من النظام': RegExp(r'localeR?e?solutionCallback|localeListResolutionCallback'),
        'تجاوز محلّي للغة': RegExp(r'Localizations\.override'),
        'قراءة لغة الجهاز': RegExp(r'PlatformDispatcher\.\w+\.locales?\b'),
      });
    });

    test('★ و`main.dart` يثبّت العربية قيمةً وحيدة', () {
      final String main = _scan('lib/main.dart').withLiterals;
      // ⛔ قائمةٌ بأكثر من لغة = بابُ إعدادٍ مفتوح، ولو لم تُعرَض واجهةُ اختيار.
      for (final Match m in RegExp(
        r'supportedLocales:\s*const\s*<Locale>\[([^\]]*)\]',
      ).allMatches(main)) {
        final int count = RegExp(r"Locale\(").allMatches(m.group(1)!).length;
        expect(count, 1, reason: '★ لغة واحدة فقط في supportedLocales');
      }
      expect(
        RegExp(r"locale:\s*const\s+Locale\('ar'\)").hasMatch(main),
        isTrue,
        reason: '★ العربية مثبَّتة صراحةً — ⛔ لا مشتقّةً من الجهاز',
      );
    });

    test('⛔ ولا نصّ واجهة لاتيني في أي شاشة أو كتالوج رسائل', () {
      final List<String> hits = <String>[];
      for (final _Source source in lib.where((_Source s) => _isUserFacing(s.path))) {
        for (final _Literal literal in source.literals) {
          if (literal.onDirective) {
            continue;
          }
          final String text = _withoutInterpolation(literal.value);
          if (!_arabic.hasMatch(text)) {
            // ⟵ ليس نصّ واجهة أصلاً: مفتاح بيانات · رمز كتالوج · مسار.
            continue;
          }
          String residue = text;
          for (final String noun in _properNouns) {
            residue = residue.replaceAll(noun, '');
          }
          if (_latin.hasMatch(residue)) {
            hits.add('${source.path}:${literal.line} ⟵ «${literal.value}»');
          }
        }
      }
      expect(hits, isEmpty, reason: '\n${hits.join('\n')}\n');
    });
  });

  // ══════ ⑤ بوابة الحِرفية البصرية — `design-system.md` §هـ و§8 ══════
  //
  // ⚠️⚠️ **ولماذا بوابةٌ لا مراجعة:** ★ **العقود أدناه مكتوبةٌ في المستند منذ
  //    أول يوم** — ⛔ **وكلُّها كانت مخالَفةً في الكود:** مؤشّرٌ دوّار في خمس
  //    شاشات · وبطاقتان متطابقتان · وستُّ حبّاتٍ منسوخة.
  //    ★ **والنصّ يصف نيّة، والاختبار وحده يفرضها.**

  group('★★ بوابة الحِرفية البصرية', () {
    final Iterable<_Source> screens =
        lib.where((_Source s) => _isUserFacing(s.path));

    test('⛔★★★ ولا مؤشّرَ دوّار حالةً للتحميل — §هـ: الهيكل العظمي وحده', () {
      // ★ **واستثناءان موثَّقان لا أكثر:**
      //   ① **شاشة البداية** (نمط 8-أ نصّاً: «شعار العميل وحده فوق مؤشّر
      //      انتظار») · ② **داخل الزر أثناء الإرسال** (§6.ج نصّاً).
      const Set<String> allowed = <String>{
        'app/router.dart',
        'presentation/login_screen.dart',
      };
      final List<String> hits = <String>[];
      for (final _Source source in lib) {
        final String path = _slash(source.path);
        if (allowed.any(path.endsWith)) {
          continue;
        }
        if (RegExp(r'CircularProgressIndicator\s*\(').hasMatch(source.code)) {
          hits.add('${source.path} ⟵ مؤشّر دوّار خارج الاستثناءين');
        }
      }
      expect(hits, isEmpty, reason: '\n${hits.join('\n')}\n');
    });

    test('⛔★★★ ولا حالةَ فارغة بلا سبب ولا إجراء — §هـ', () {
      // ★ **الحالة الفارغة تُبنى بـ`EmptyStateSpec` وحده** — ⟵ **ونوعُه يفرض
      //   الأيقونة والعنوان والرسالة معاً**، ⛔ **فلا «لا توجد بيانات» عارية.**
      final List<String> hits = <String>[];
      for (final _Source source in screens) {
        for (final _Literal literal in source.literals) {
          final String text = literal.value.trim();
          if (text == 'لا توجد بيانات' || text == 'لا توجد بيانات.') {
            hits.add('${source.path}:${literal.line} ⟵ فراغٌ بلا سبب');
          }
        }
      }
      expect(hits, isEmpty, reason: '\n${hits.join('\n')}\n');
    });

    test('⛔★★★ ولا حبّةَ حالة مرسومة محلياً — §8 المحظور الحادي عشر', () {
      // ⚠️ **العلامة الفارقة:** ★ **حاويةٌ بـ`radiusPill` مرسومةٌ في شاشة**
      //    ⟵ **نسخةٌ محلية من حبّة الحالة**، ★ **والمشروعةُ واحدة.**
      final List<String> hits = <String>[];
      for (final _Source source in screens) {
        if (_slash(source.path).endsWith('core/ui/status_pill.dart')) {
          continue;
        }
        if (RegExp(r'BorderRadius\.circular\(Radii\.pill\)')
            .hasMatch(source.code)) {
          hits.add('${source.path} ⟵ حبّةٌ مرسومة محلياً');
        }
      }
      expect(hits, isEmpty, reason: '\n${hits.join('\n')}\n');
    });

    test('★★ وكل مدّة حركة من توكنز §9 — ⛔ ولا `Duration` مكتوبة في شاشة', () {
      _expectNoMatches(screens, (_Source s) => s.code, <String, RegExp>{
        'مدّة حركة مكتوبة يدوياً': RegExp(
          r'Duration\s*\(\s*(milliseconds|seconds)\s*:',
        ),
      });
    });
  });

  // ═════════ ⑥ بوابة خُطّاف الاختبار — `AM-005` · `DEBT-31` ═════════

  // ═════════════════════════════════════════════════════════════════════
  // ⛔⛔★★★ بوابةُ `minimumSize` — `DEBT-63`
  // ═════════════════════════════════════════════════════════════════════
  //
  // ★★ **ما تحرسه:** `Size.fromHeight(h)` **هي `Size(double.infinity, h)`**
  // ⟵ **فتجعل `minWidth` لا نهائياً.** ⛔⛔ **وابنُ `Row` غيرُ المرن يُخطَّط
  // بعرضٍ غير محدود** ⟹ **قيدٌ مستحيل: الزرُّ يُبنى ويُربَط ولا يُخطَّط أبداً**
  // (`hasSize=false`) ⛔ **ولا يُرسَم ولا يُخطئ بصوتٍ مسموع.**
  //
  // ⛅★★ **وهذا هو سببُ `DEBT-63` مقيساً على `Pixel_6_API_36`:** ★ **زرُّ
  // «نسخ أسعار أمس» كان الضحيّة الظاهرة** ⟵ **والعطلُ كان يعمّ كلَّ زرٍّ
  // محاطٍ بعرضٍ غير محدود في التطبيق كلِّه.**
  //
  // ⚠️★★ **و`filledButtonTheme` مستثنىً عمداً:** ★ **`Size.fromHeight` فيه
  // مقصودة** — **الزرُّ الأساسي يملأ العرض** ⟵ **وموضعُه دائماً محدودُ العرض**
  // (`QtmsStickyActionBar`). ⛔ **ولو وُضع في `Row` لسقط السقوطَ نفسَه.**
  group('⛔⛔★★★ بوابة minimumSize — DEBT-63', () {
    test('★ الزرُّ المحاط: `minimumSize` بعرضٍ محدود ⛔ لا لا نهائي', () {
      final ThemeData theme = buildQtmsTheme();
      final Size? min = theme.outlinedButtonTheme.style?.minimumSize
          ?.resolve(<WidgetState>{});
      expect(min, isNotNull, reason: '⛔ لا حدَّ أدنى معرَّفاً للزرّ المحاط');
      expect(
        min!.width.isFinite,
        isTrue,
        reason: '⛔⛔ `Size.fromHeight` تُعطي `minWidth = infinity` — '
            'فلا يُخطَّط الزرُّ داخل `Row` أبداً (DEBT-63)',
      );
      // ★ **والمقصودُ هدفُ لمسٍ 48×48** — §5 البند 3.
      expect(min.width, Sizes.minTouch);
      expect(min.height, Sizes.minTouch);
    });

    test('★★ ونظائرُه النصّي والأيقوني على القاعدة نفسِها', () {
      final ThemeData theme = buildQtmsTheme();
      for (final (String name, Size? size) in <(String, Size?)>[
        (
          'textButton',
          theme.textButtonTheme.style?.minimumSize?.resolve(<WidgetState>{}),
        ),
        (
          'iconButton',
          theme.iconButtonTheme.style?.minimumSize?.resolve(<WidgetState>{}),
        ),
      ]) {
        expect(size?.width.isFinite, isTrue, reason: '⛔ $name بعرضٍ لا نهائي');
      }
    });
  });

  group('★★ بوابة خُطّاف اختبار المحاكي', () {
    const String hookPath = 'lib/core/startup/staging_qa_credentials.dart';

    test('★ اعتماد الاختبار محصورٌ في ملفٍ واحد — ⛔ ولا يُقرأ ثابتُه من شاشة',
        () {
      final List<String> hits = <String>[];
      for (final _Source source in lib) {
        if (source.path.replaceAll(r'\', '/').endsWith(hookPath)) {
          continue;
        }
        // ⟵ الصورة `withLiterals` تُبقي محتوى النصوص وتُسقط التعليقات،
        //   ⟵ فشرحُ القاعدة في تعليقٍ لا يُحسَب مخالفةً لها.
        if (source.withLiterals.contains('QTMS_STAGING_QA_')) {
          hits.add('${source.path} ⟵ يقرأ ثابت الاعتماد مباشرةً');
        }
      }
      expect(hits, isEmpty, reason: '\n${hits.join('\n')}\n');
    });

    test('⛔ ولا يسقط أحد الحارسين — `kDebugMode` وفراغُ القيمتين معاً', () {
      final String hook = _scan(hookPath).code;
      expect(
        RegExp(r'if\s*\(\s*!\s*debugMode\s*\)').hasMatch(hook),
        isTrue,
        reason: '★ الحارس الأول: بناءُ الإصدار لا يصل المسار إطلاقاً',
      );
      expect(
        RegExp(r'debugMode\s*=\s*kDebugMode').hasMatch(hook),
        isTrue,
        reason: '★ وقيمتُه الافتراضية ثابتُ التصريف — ⛔ لا رايةٌ وقت تشغيل',
      );
      expect(
        RegExp(r'trimmedEmail\.isEmpty\s*\|\|\s*password\.isEmpty')
            .hasMatch(hook),
        isTrue,
        reason: '★ الحارس الثاني: بناءٌ بلا حقنٍ لا يملأ شيئاً',
      );
    });

    test('⛔ ولا إرسال تلقائياً من شاشة الدخول — الملء يُهيّئ والضغط صريح', () {
      final String screen = _scan(
        'lib/capabilities/identity_access/presentation/login_screen.dart',
      ).code;
      final int start = screen.indexOf('void initState()');
      final int end = screen.indexOf('void dispose()');
      expect(start, greaterThan(-1), reason: '★ الخُطّاف يعيش في initState');
      expect(end, greaterThan(start), reason: '★ وترتيب العضوين ثابت');
      expect(
        screen.substring(start, end).contains('_submit'),
        isFalse,
        reason: '⛔ لا استدعاء لـ_submit من الملء المسبق',
      );
    });
  });
}

// ═══════════════════════════ مساعدات ═══════════════════════════

/// نصّ ما بين قوسين متوازنين ابتداءً من `(` عند [openIndex].
String _balanced(String text, int openIndex) {
  int depth = 0;
  for (int i = openIndex; i < text.length; i++) {
    if (text[i] == '(') {
      depth++;
    } else if (text[i] == ')') {
      depth--;
      if (depth == 0) {
        return text.substring(openIndex + 1, i);
      }
    }
  }
  return '';
}

/// درجات `primary` كما هي في `design-tokens.md` §2.2 — **مقروءةً من المستند**.
Map<String, String> _documentedPrimaries() {
  final String doc =
      File('docs/18-ux-ui/design-tokens.md').readAsStringSync();
  final int start = doc.indexOf('### 2.2 ');
  expect(start, isNot(-1), reason: 'القسم §2.2 غائب عن المستند');
  final int end = doc.indexOf('### 2.3 ', start);
  final String section = doc.substring(start, end == -1 ? doc.length : end);

  final Map<String, String> values = <String, String>{};
  for (final Match m in RegExp(
    r'\|\s*`(primary\d+)`\s*\|\s*`#([0-9A-Fa-f]{6})`\s*\|',
  ).allMatches(section)) {
    values[m.group(1)!] = 'FF${m.group(2)!.toUpperCase()}';
  }
  return values;
}

/// تمثيل `ARGB` بثماني خانات — ⛔ **بلا `Color.value` المهجورة.**
String _hex(Color color) =>
    color.toARGB32().toRadixString(16).toUpperCase().padLeft(8, '0');

/// مشاركة الملف المُصدَّر — ★ **ورقةُ المشاركة النظامية** (`FR-M20-14`).
///
/// ★ **«كل السندات قابلة للتصدير PDF ومشاركتها كملف عبر واتساب»** — ⟵ **وورقةُ
/// النظام هي الآلية الوحيدة لذلك على أندرويد** ⛔ **بلا إذنِ جهازٍ إضافي**
/// (`dependency-management-policy.md` §3).
///
/// ⚠️⚠️ **والملف مؤقت لا دائم:** ★ **يُكتب في مجلد المؤقتات ويُسلَّم للنظام**
/// — ⛔ **ولا يُنشئ التطبيق أرشيفاً محلياً للمستندات**: ⟵ **`ADR-0003`
/// يمنع التخزين المحلي**، ★ **ونسخةٌ محليةٌ قديمةٌ تُقرأ حقيقةً وهي ليست كذلك.**
///
/// ⛔★★ **ولا اسمَ ملفٍ يحمل بيانات المقوت:** ★ **الاسم من نوع المستند
/// ومعرّفه** — ⟵ **فاسمُ الملف يظهر في قوائم المشاركة وسجلّات النظام**،
/// ⛔ **وإدراجُ اسم عميلٍ فيه تسريبٌ خارج التطبيق** (`messaging-design.md` §8).
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:qtms_domain/qtms_domain.dart';
import 'package:share_plus/share_plus.dart';

/// نتيجة محاولة المشاركة.
enum DocumentShareOutcome {
  /// فُتحت ورقة المشاركة.
  shared,

  /// تعذّر إنشاء الملف أو فتح الورقة.
  failed,
}

/// ★ عقدُ مشاركة المستند — **يعرّفه هذا الملف وتحقنه الشاشة**.
///
/// ⛔★★ **ولماذا واجهةٌ لا صنفٌ مباشر:** ★ **اختبارُ الشاشة لا يجوز أن يكتب
/// ملفاً حقيقياً** — ⟵ **وكتابةُ القرص عمليةٌ لا يحصرها `pumpAndSettle`**
/// (⚠️ **رُصد فعلاً**: الاختبار كان يقرأ القائمةَ فارغةً قبل أن تكتمل
/// الكتابة)، ★ **فيُحقَن بديلٌ في الذاكرة**، **وصحّةُ الكتابة نفسِها تُقاس
/// في اختبار الخدمة وحده.**
abstract interface class DocumentSharer {
  /// يكتب الملف ويفتح ورقة المشاركة.
  Future<DocumentShareOutcome> sharePdf({
    required ExportableDocument document,
    required Uint8List bytes,
  });

  /// ★★ يفتح ورقة المشاركة بنصٍّ جاهز — ⛔ **بلا ملفٍّ ولا قرص** (`AM-023`).
  ///
  /// ⛔⛔★★★ **ولماذا في هذه البوابة لا في الشاشة:** ★ **ورقةُ النظام مصدرُ
  /// حقيقةٍ واحدٌ في التطبيق كلِّه** — ⟵ **واستدعاءُ `SharePlus` من شاشةٍ
  /// يجعل الشاشةَ تلمس المنصّة مباشرةً**، ⛔ **فيتعذّر اختبارُها بلا جهاز**
  /// (نفسُ علّة [sharePdf] حرفاً بحرف).
  ///
  /// ⛔⛔ **والنصُّ يصل جاهزاً بلا حسابٍ ولا تنسيق** — ★ **بانيه طبقةُ التنسيق**
  /// (`design-system.md` §5.1): ⟵ **فلا رقمَ يُبنى هنا.**
  Future<DocumentShareOutcome> shareText({
    required String text,
    required String subject,
  });
}

/// خدمة مشاركة المستندات المُصدَّرة.
final class DocumentShareService implements DocumentSharer {
  /// ينشئ الخدمة — ★ **وتبعياتها تُحقَن، فتُختبَر بلا نظام ملفات**.
  DocumentShareService({
    Future<Directory> Function()? temporaryDirectory,
    Future<void> Function(String path, String subject)? shareFile,
    Future<void> Function(String text, String subject)? shareRawText,
  })  : _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory,
        _shareFile = shareFile ?? _shareWithSystem,
        _shareRaw = shareRawText ?? _shareRawText;

  final Future<Directory> Function() _temporaryDirectory;
  final Future<void> Function(String path, String subject) _shareFile;
  final Future<void> Function(String text, String subject) _shareRaw;

  /// يكتب [bytes] ملفاً مؤقتاً ثم يفتح ورقة المشاركة.
  @override
  Future<DocumentShareOutcome> sharePdf({
    required ExportableDocument document,
    required Uint8List bytes,
  }) async {
    try {
      final Directory directory = await _temporaryDirectory();
      // ★ **مسارٌ محايد للمنصّة** — ⛔ **ولا فاصلَ مسارٍ مكتوبٌ نصّاً.**
      final File file = File(
        '${directory.path}${Platform.pathSeparator}${_fileNameOf(document)}',
      );
      await file.writeAsBytes(bytes, flush: true);
      await _shareFile(file.path, document.title);
      return DocumentShareOutcome.shared;
    } on Object {
      // ⛔ **ولا يُرمى إلى الشاشة** — `error-handling-strategy.md` §3 القاعدة 3:
      //   ★ **نتيجةٌ مصنَّفة تُترجَم إلى رسالة كتالوج**، ⛔ **لا استثناءٌ عارٍ.**
      return DocumentShareOutcome.failed;
    }
  }

  /// يفتح ورقة المشاركة بنصٍّ جاهز — ⛔ **ولا يكتب ملفاً.**
  @override
  Future<DocumentShareOutcome> shareText({
    required String text,
    required String subject,
  }) async {
    try {
      await _shareRaw(text, subject);
      return DocumentShareOutcome.shared;
    } on Object {
      // ⛔ **ولا يُرمى إلى الشاشة** — `error-handling-strategy.md` §3 القاعدة 3.
      return DocumentShareOutcome.failed;
    }
  }

  /// ★ اسم الملف — **نوعُ المستند ومعرّفه وحدهما** ⛔ **بلا اسم عميل.**
  static String _fileNameOf(ExportableDocument document) {
    final String id = (document.documentNumber ?? document.entityId)
        .replaceAll(RegExp('[^A-Za-z0-9_-]'), '-');
    return '${document.entityType}-$id.pdf';
  }

  static Future<void> _shareWithSystem(String path, String subject) =>
      SharePlus.instance.share(
        ShareParams(
          files: <XFile>[XFile(path, mimeType: 'application/pdf')],
          subject: subject,
        ),
      );

  static Future<void> _shareRawText(String text, String subject) =>
      SharePlus.instance.share(ShareParams(text: text, subject: subject));
}

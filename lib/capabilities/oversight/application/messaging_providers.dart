/// مزوّدات الإرسال والتصدير (`WU-010` · `M20`).
///
/// ★ **بنفس نمط `audit_log_providers.dart`:** الخدمات **تُحقَن في الجذر ولا
/// تُبنى هنا** (`ADR-0010` — حقن اعتمادية صريح) — ⟵ **فتُختبَر الشاشات بلا
/// نظام ملفاتٍ ولا شبكةٍ ولا جهاز.**
///
/// ⚠️⚠️ **وكل ما هنا عرضٌ لا تفويض:** إخفاء زرٍّ بـ`messagingSend` أو
/// `documentExport` **إخفاء لا حماية** — ★ **والحارس الحقيقي في العملية
/// السحابية `logExport`** (`ADR-0013` القاعدة 3 · `RISK-02`).
///
/// ⛔⛔★★ **ولا مزوّدَ لتسجيل الإرسال ولا لحالته** — `FR-M20-15` نفيٌ صريح
/// (`AT-64`): **لا مجموعةَ سجلٍّ ولا حقلَ متابعة.**
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qtms_domain/qtms_domain.dart';

import '../../master_data/application/master_data_providers.dart';
import '../infrastructure/document_share_service.dart';
import '../infrastructure/message_channel_launcher.dart';
import '../infrastructure/pdf_document_renderer.dart';

/// مستودع تسجيل التصدير — ⛔ **يُحقَن في الجذر**.
final Provider<ExportLogRepository> exportLogRepositoryProvider =
    Provider<ExportLogRepository>((Ref ref) {
  throw UnimplementedError('exportLogRepositoryProvider يجب تجاوزه عند الجذر');
});

/// راسم المستندات — ⛔ **يُحقَن في الجذر**.
final Provider<DocumentRenderer> pdfRendererProvider =
    Provider<DocumentRenderer>((Ref ref) {
  throw UnimplementedError('pdfRendererProvider يجب تجاوزه عند الجذر');
});

/// خدمة المشاركة — ⛔ **تُحقَن في الجذر**.
final Provider<DocumentSharer> documentShareProvider =
    Provider<DocumentSharer>((Ref ref) {
  throw UnimplementedError('documentShareProvider يجب تجاوزه عند الجذر');
});

/// فاتح قنوات الإرسال — ⛔ **يُحقَن في الجذر**.
final Provider<MessageChannelLauncher> messageChannelProvider =
    Provider<MessageChannelLauncher>((Ref ref) {
  throw UnimplementedError('messageChannelProvider يجب تجاوزه عند الجذر');
});

/// ★★ هوية المحل في كل رسالةٍ ومستند — **من الإعداد التأسيسي وحده**.
///
/// ★ **وهو الاستثناء الوحيد في `messaging-design.md` §3:** «**`{اسم المحل}`
/// يُقرأ من الإعداد التأسيسي**» — ⛔ **وبقية القالب ثوابتُ كود.**
///
/// ⚠️ **والغياب قبل الإعداد التأسيسي حالةٌ ممكنة** — ★ **فيُعرَض اسمٌ فارغ**
/// ⛔ **ولا يُخترَع اسمٌ بديل**: ⟵ **واسمٌ مُخترَع في رسالةٍ تصل مقوتاً
/// هو أسوأ من ترويسةٍ ناقصة.**
final Provider<MessageBusiness> messageBusinessProvider =
    Provider<MessageBusiness>((Ref ref) {
  final AppSettingsCard? settings = ref.watch(appSettingsProvider).value;
  return MessageBusiness(
    businessName: settings?.businessName ?? '',
    thousandsSeparator: settings?.thousandsSeparator ?? '',
  );
});

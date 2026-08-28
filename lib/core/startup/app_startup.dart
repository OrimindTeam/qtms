/// إقلاع التطبيق — المخرَج 9 من «الخطوة صفر».
///
/// مسؤوليتان اثنتان لا ثالث لهما:
///   ① ★ **تعطيل التخزين المحلي صراحةً** (`ADR-0003`).
///   ② **التحقق من توفر خدمات المنصة** وإرجاع خطأ مصنَّف عند غيابها
///      (`C-04` · `FR-SYS-27`) — ⛔ **لا فشل صامت**.
///
/// ★ **لماذا الاعتماديات مُمرَّرة لا مستدعاة مباشرةً:** كي يكون الإقلاع
/// **قابلاً للاختبار بلا جهاز ولا سحابة**. وهذا مطلب عملي لا تجميلي: بدونه
/// لا يمكن إثبات أن التخزين المحلي مُعطَّل إلا بتشغيل يدوي على هاتف.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:qtms_domain/qtms_domain.dart';

/// دالة تهيئة المنصة — تُستبدَل في الاختبار.
typedef PlatformInitializer = Future<void> Function();

/// دالة تطبيق إعدادات قاعدة البيانات — تُستبدَل في الاختبار.
typedef FirestoreConfigurator = void Function(Settings settings);

/// ★ الإعداد المعتمد لقاعدة البيانات — **والتخزين المحلي مُعطَّل فيه**.
///
/// `ADR-0003` و`technology-stack.md` §1: «متصل دائماً — التخزين المحلي
/// **مُعطَّل صراحةً**». والسبب ليس أداءً بل سلامة: الكتابة التي تنجح محلياً
/// ثم تُرفَض سحابياً **تُري المستخدم نجاحاً لم يحدث** — وهو أخطر سيناريو
/// ممكن في نظام ذمم.
const Settings qtmsFirestoreSettings = Settings(persistenceEnabled: false);

/// نتيجة محاولة الإقلاع.
sealed class StartupOutcome {
  const StartupOutcome();
}

/// الإقلاع نجح والمنصة متوفرة.
final class StartupReady extends StartupOutcome {
  const StartupReady();
}

/// الإقلاع فشل بخطأ مصنَّف — يُعرَض للمستخدم برسالة الكتالوج في طبقة العرض.
final class StartupFailed extends StartupOutcome {
  const StartupFailed(this.error);

  final AppError error;
}

/// يُهيّئ المنصة ويعطّل التخزين المحلي، ويُصنّف أي فشل بدل ابتلاعه.
///
/// يُرجِع [StartupReady] عند النجاح، و[StartupFailed] حاملاً
/// [PlatformUnavailableError] إن تعذّرت تهيئة المنصة — وهي الحالة التي تعني
/// عملياً **غياب خدمات Google Play أو تعطّلها** على الجهاز.
Future<StartupOutcome> bootstrapQtms({
  required PlatformInitializer initializePlatform,
  required FirestoreConfigurator configureFirestore,
}) async {
  try {
    await initializePlatform();
  } on Object catch (error) {
    // ⛔ لا يُبتلَع استثناء صامتاً (coding-standards §2.5).
    //    والوصف للسجل لا للعرض — بلا أي بيانات حساسة (§2.4).
    return StartupFailed(PlatformUnavailableError(error.runtimeType.toString()));
  }

  try {
    configureFirestore(qtmsFirestoreSettings);
  } on Object catch (error) {
    return StartupFailed(InfrastructureError(error.runtimeType.toString()));
  }

  return const StartupReady();
}

/// الاعتماديات الحقيقية — تُستخدَم في `main` وحدها، ولا تدخل الاختبارات.
Future<void> initializeFirebasePlatform() => Firebase.initializeApp();

/// يطبّق الإعدادات على المثيل الحقيقي لقاعدة البيانات.
void applyFirestoreSettings(Settings settings) {
  FirebaseFirestore.instance.settings = settings;
}

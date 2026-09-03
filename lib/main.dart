/// نقطة دخول التطبيق.
///
/// ★ **مسؤوليتها: الإقلاع ثم الحقن ثم التسليم للموجّه** — ⛔ **ولا منطق
/// أعمال ولا بناء مستودعات داخل الشاشات** (`ADR-0009` · `ADR-0010`).
library;

import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'
    show LicenseEntryWithLineBreaks, LicenseRegistry;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

import 'app/router.dart';
import 'capabilities/identity_access/application/admin_providers.dart';
import 'capabilities/financial_outflow/application/outflow_providers.dart';
import 'capabilities/financial_outflow/application/owner_ledger_providers.dart';
import 'capabilities/financial_outflow/infrastructure/firestore_cash_movement_directory.dart';
import 'capabilities/financial_outflow/infrastructure/firestore_owner_ledger_directory.dart';
import 'capabilities/financial_outflow/infrastructure/firestore_outflow_directory.dart';
import 'capabilities/financial_outflow/infrastructure/functions_outflow_repository.dart';
import 'capabilities/identity_access/application/session_providers.dart';
import 'capabilities/identity_access/infrastructure/firebase_auth_repository.dart';
import 'capabilities/identity_access/infrastructure/firestore_user_card_repository.dart';
import 'capabilities/identity_access/infrastructure/firestore_user_directory_repository.dart';
import 'capabilities/identity_access/infrastructure/functions_user_admin_repository.dart';
import 'capabilities/inventory/application/inventory_providers.dart';
import 'capabilities/inventory/application/sack_valuation_providers.dart';
import 'capabilities/inventory/infrastructure/firestore_daily_pricing_directory.dart';
import 'capabilities/inventory/infrastructure/firestore_inventory_directory.dart';
import 'capabilities/inventory/infrastructure/firestore_sack_directory.dart';
import 'capabilities/inventory/infrastructure/firestore_sack_valuation_directory.dart';
import 'capabilities/inventory/infrastructure/functions_daily_pricing_repository.dart';
import 'capabilities/inventory/infrastructure/functions_inventory_repository.dart';
import 'capabilities/inventory/infrastructure/functions_sack_repository.dart';
import 'capabilities/master_data/application/master_data_providers.dart';
import 'capabilities/master_data/infrastructure/contact_picker.dart';
import 'capabilities/master_data/infrastructure/firestore_master_data_directory.dart';
import 'capabilities/master_data/infrastructure/functions_master_data_repository.dart';
import 'capabilities/oversight/application/audit_log_providers.dart';
import 'capabilities/oversight/application/messaging_providers.dart';
import 'capabilities/oversight/application/pending_entries_providers.dart';
import 'capabilities/oversight/application/report_providers.dart';
import 'capabilities/oversight/infrastructure/document_share_service.dart';
import 'capabilities/oversight/infrastructure/firestore_audit_log_directory.dart';
import 'capabilities/oversight/infrastructure/firestore_pending_entries_directory.dart';
import 'capabilities/oversight/infrastructure/firestore_report_directory.dart';
import 'capabilities/oversight/infrastructure/functions_export_log_repository.dart';
import 'capabilities/oversight/infrastructure/message_channel_launcher.dart';
import 'capabilities/oversight/infrastructure/pdf_document_renderer.dart';
import 'capabilities/sales_receivables/application/cash_sale_providers.dart';
import 'capabilities/sales_receivables/application/distribution_providers.dart';
import 'capabilities/sales_receivables/infrastructure/firestore_cash_sale_directory.dart';
import 'capabilities/sales_receivables/infrastructure/firestore_distribution_directory.dart';
import 'capabilities/sales_receivables/infrastructure/functions_cash_sale_repository.dart';
import 'capabilities/sales_receivables/infrastructure/functions_distribution_repository.dart';
import 'capabilities/sales_receivables/application/discount_providers.dart';
import 'capabilities/sales_receivables/infrastructure/firestore_discount_directory.dart';
import 'capabilities/sales_receivables/infrastructure/functions_discount_repository.dart';
import 'capabilities/sales_receivables/application/receipt_providers.dart';
import 'capabilities/sales_receivables/infrastructure/firestore_receipt_directory.dart';
import 'capabilities/sales_receivables/infrastructure/functions_receipt_repository.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

import 'capabilities/identity_access/application/biometric_providers.dart';
import 'core/device/device_preference_providers.dart';
import 'core/device/local_auth_biometric_gateway.dart';
import 'core/device/secure_credential_vault.dart';
import 'core/callable/callable_client.dart';
import 'core/connectivity/connection_providers.dart';
import 'core/connectivity/firestore_connection_monitor.dart';
import 'core/design/app_theme.dart';
import 'core/design/brand.dart';
import 'core/design/design_tokens.dart';
import 'core/messages/error_messages.dart';
import 'core/startup/app_startup.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _registerFontLicense();

  final StartupOutcome outcome = await bootstrapQtms(
    initializePlatform: initializeFirebasePlatform,
    configureFirestore: applyFirestoreSettings,
  );

  // ★★★ **تفضيلُ العرض يُقرأ من القرص مرةً واحدة قبل `runApp`** — `AM-012` §4.4.
  //
  // ⛔⛔★★★ **وقبلَه لا بعده** — ★ **فالقوائمُ تُبنى بالقيمة الصحيحة من أول
  //    إطار**: ⟵ **وقراءتُه بعد الإقلاع كانت تُعيد بناءَ كلِّ قائمةٍ تعرض
  //    اسمَ نوعٍ مرةً ثانية** ⛔ **فيومض الاسمُ أمام المستخدم عند كل فتح.**
  //
  // ⚠️ **وفشلُ القراءة يُقرأ `false`** — ⛔ **ولا يُوقِف الإقلاع:** ★ **تفضيلُ
  //    عرضٍ تجميليٌّ لا يستحق شاشةَ خطأ**، ⟵ **والمستخدم يُبدِّله من الإعدادات.**
  const FlutterSecureStorage secureStorage = FlutterSecureStorage();
  const SecureDevicePreferences preferences =
      SecureDevicePreferences(secureStorage);
  bool showPieceWeight = false;
  if (outcome is StartupReady) {
    try {
      showPieceWeight = await preferences.showPieceWeightWithItemName();
    } on Object {
      // ⛔ ولا يُبتلَع صامتاً بلا سبب — القيمة الافتراضية مُعلَنة أعلاه.
      showPieceWeight = false;
    }
  }

  runApp(
    ProviderScope(
      // ★ الحقن عند الجذر وحده — فالاختبار يستبدل المستودعين بلا سحابة.
      overrides: outcome is StartupReady
          ? [
              authRepositoryProvider.overrideWithValue(
                FirebaseAuthRepository(FirebaseAuth.instance),
              ),
              // ★★★ **بوابةُ البصمة وخزنةُ الجهاز وتفضيلاتُه** — [`ADR-0024`]
              //    ⏳ **مقترح** · `AM-012` §4.4 و§5.2 و§6.
              //
              // ⛔⛔★★ **ومخزنٌ واحدٌ للثلاثة** — ★ **ولا حزمةَ ثالثة لقيمةٍ
              //    منطقيةٍ واحدة** (`dependency-management-policy.md` §1
              //    البند 2): ⟵ **والتشفيرُ على تفضيلِ عرضٍ فائضٌ لا ضارّ.**
              biometricGatewayProvider.overrideWithValue(
                LocalAuthBiometricGateway(LocalAuthentication()),
              ),
              credentialVaultProvider.overrideWithValue(
                const SecureCredentialVault(secureStorage),
              ),
              devicePreferencesProvider.overrideWithValue(preferences),
              // ★ **والقيمةُ المقروءة تُحقَن مبدئيةً** — راجع أعلاه.
              initialShowPieceWeightProvider
                  .overrideWithValue(showPieceWeight),
              userCardRepositoryProvider.overrideWithValue(
                FirestoreUserCardRepository(FirebaseFirestore.instance),
              ),
              // ★★★ `AM-008` ① — **حالة الاتصال مقيسةً من بثّ القاعدة نفسِه.**
              //   ⛔ **ولا حزمةَ فحصِ شبكةٍ تُضاف:** ★ **وجودُ واجهة شبكةٍ لا
              //   يعني بلوغَ الخادم**، ⟵ **والسؤال الذي يهمّ المستخدم «هل
              //   ستنجح كتابتي؟»** (`ADR-0003`).
              connectionMonitorProvider.overrideWithValue(
                FirestoreConnectionMonitor(
                  firestore: FirebaseFirestore.instance,
                  userIds: FirebaseAuth.instance
                      .authStateChanges()
                      .map((User? user) => user?.uid),
                ),
              ),
              // ★★ `IQ-015` — دليل المستخدمين وإدارتهم.
              userDirectoryProvider.overrideWithValue(
                FirestoreUserDirectoryRepository(FirebaseFirestore.instance),
              ),
              userAdminProvider.overrideWithValue(
                FunctionsUserAdminRepository(
                  client: _callableClient(),
                  newRequestId: _newRequestId,
                ),
              ),
              roleAdminProvider.overrideWithValue(
                FunctionsRoleAdminRepository(
                  client: _callableClient(),
                  newRequestId: _newRequestId,
                  roles:
                      FirestoreRoleDirectory(FirebaseFirestore.instance)
                          .watchAll(),
                ),
              ),
              // ★★ `WU-002` — البيانات المرجعية: **القراءة مباشرة والكتابة
              //   عبر العمليات المستدعاة** (`ADR-0013` القاعدتان 2 و4).
              masterDataDirectoryProvider.overrideWithValue(
                FirestoreMasterDataDirectory(FirebaseFirestore.instance),
              ),
              masterDataAdminProvider.overrideWithValue(
                FunctionsMasterDataRepository(
                  client: _callableClient(),
                  newRequestId: _newRequestId,
                ),
              ),
              // ★ **مُنتقي جهات الاتصال على المنصّة** — `FR-M3-03` · `FR-M4-03`.
              //   ⛔ **ولا إذن `READ_CONTACTS`**: مُنتقي النظام يُعيد جهةً
              //   واحدة اختارها المستخدم بنفسه (`contact_picker.dart`).
              contactPickerProvider
                  .overrideWithValue(const PlatformContactPicker()),
              // ★★ `WU-003` — المخزون: **القراءة مباشرة والكتابة عبر
              //   العمليات المستدعاة** (`ADR-0013` القاعدتان 2 و4).
              inventoryDirectoryProvider.overrideWithValue(
                FirestoreInventoryDirectory(FirebaseFirestore.instance),
              ),
              inventoryAdminProvider.overrideWithValue(
                FunctionsInventoryRepository(
                  client: _callableClient(),
                  newRequestId: _newRequestId,
                ),
              ),
              // ★★ `WU-004` — الجواني: **القراءة مباشرة والكتابة عبر
              //   العمليات المستدعاة السبع** (`ADR-0013` القاعدتان 2 و4).
              //   ⛔★★ **ولا كتابة مباشرة على `sacks` ولا على ماليتها.**
              // ⛅★★ **دليلُ مالية الجواني** (`WU-015`) — ★ **قراءةً فقط**:
              //    ⛔ **ولا مستودعَ كتابةٍ له** — **يكتبه المُحتسِب السحابي**
              //    (`schema/supplier-ledger.md` القاعدة 5).
              sackValuationDirectoryProvider.overrideWithValue(
                FirestoreSackValuationDirectory(FirebaseFirestore.instance),
              ),
              sackDirectoryProvider.overrideWithValue(
                FirestoreSackDirectory(FirebaseFirestore.instance),
              ),
              sackAdminProvider.overrideWithValue(
                FunctionsSackRepository(
                  client: _callableClient(),
                  newRequestId: _newRequestId,
                ),
              ),
              // ★★ `WU-005` — التسعير اليومي: **القراءة مباشرة والكتابة عبر
              //   العملية المستدعاة** (`ADR-0013` القاعدتان 2 و4).
              dailyPricingDirectoryProvider.overrideWithValue(
                FirestoreDailyPricingDirectory(FirebaseFirestore.instance),
              ),
              dailyPricingRepositoryProvider.overrideWithValue(
                FunctionsDailyPricingRepository(
                  client: _callableClient(),
                  newRequestId: _newRequestId,
                ),
              ),
              // ★★ `WU-006` — التوزيع والضمار: **القراءة مباشرة والكتابة عبر
              //   العمليات المستدعاة الثلاث** (`ADR-0013` القاعدتان 2 و4).
              //   ⛔★★ **ولا كتابة مباشرة على `distributions` ولا على
              //   أسعارها ولا على دفتر المقاوته ولا أرصدته.**
              distributionDirectoryProvider.overrideWithValue(
                FirestoreDistributionDirectory(FirebaseFirestore.instance),
              ),
              distributionAdminProvider.overrideWithValue(
                FunctionsDistributionRepository(
                  client: _callableClient(),
                  newRequestId: _newRequestId,
                ),
              ),
              // ★★ `WU-012` — البيع النقدي: **القراءة مباشرة والكتابة عبر
              //   العمليات المستدعاة الثلاث** (`ADR-0013` القاعدتان 2 و4).
              //   ⛔⛔★★★ **ولا مستودعَ ذمّةٍ هنا إطلاقاً** — `FR-M11-03`:
              //   ★ **البيعُ النقدي لا يمسّ دفتر المقاوته ولا أرصدته**،
              //   ⟵ **فلا مزوّدَ لهما في هذه الوحدة أصلاً.**
              cashSaleDirectoryProvider.overrideWithValue(
                FirestoreCashSaleDirectory(FirebaseFirestore.instance),
              ),
              cashSaleAdminProvider.overrideWithValue(
                FunctionsCashSaleRepository(
                  client: _callableClient(),
                  newRequestId: _newRequestId,
                ),
              ),
              // ★★ `WU-013` — الخصومات: **القراءة مباشرة والكتابة عبر
              //   العمليات المستدعاة الثلاث** (`ADR-0013` القاعدتان 2 و4).
              //   ⛔⛔★★★ **ومستودعٌ منفصلٌ عن المقبوضات قطعاً**
              //   (`FR-M15-06-أ`): ★ **مجموعةٌ وصلاحيةٌ ونوعُ قيدٍ منفصلة**،
              //   ⟵ **فما دفعه المقوت نقداً وما أسقطه المالك عنه رقمان
              //   مختلفان لا يجوز خلطهما.**
              discountDirectoryProvider.overrideWithValue(
                FirestoreDiscountDirectory(FirebaseFirestore.instance),
              ),
              discountAdminProvider.overrideWithValue(
                FunctionsDiscountRepository(
                  client: _callableClient(),
                  newRequestId: _newRequestId,
                ),
              ),
              // ★★ `WU-014` — السحبيات والخرجيات: **القراءة مباشرة والكتابة
              //   عبر العمليات المستدعاة الثلاث** (`ADR-0013` القاعدتان 2 و4).
              //   ⛔⛔★★★ **ومستودعٌ واحدٌ للسجلَّين** — ★ **والفصلُ الأمني
              //   في ثمانية مفاتيح وفي `resource.data.ledgerType` بالقاعدة
              //   وفي `outflowPermission` بالدالة الكاتبة** (`GR-43`):
              //   ⟵ **ومستودعان متطابقان كانا يفترقان عند أول تعديل.**
              outflowDirectoryProvider.overrideWithValue(
                FirestoreOutflowDirectory(FirebaseFirestore.instance),
              ),
              outflowAdminProvider.overrideWithValue(
                FunctionsOutflowRepository(
                  client: _callableClient(),
                  newRequestId: _newRequestId,
                ),
              ),
              // ⛅★★★ `WU-016` — ضمار المالك وحركة النقد: **قراءةٌ مباشرة
              //   وحدها** (`ADR-0013` القاعدة 4). ⛔⛔ **ولا نظيرَ كاتبٍ له
              //   هنا ولا في أي مكان**: `daily_summaries` و`owner_ledger_trends`
              //   **`allow write: if false` للجميع** — ★ **والملخصاتُ تبنيها
              //   `buildDailySummaries` داخل حاوية العمليات بعد كل التزام**
              //   (`api-overview.md` §3.2).
              ownerLedgerDirectoryProvider.overrideWithValue(
                FirestoreOwnerLedgerDirectory(FirebaseFirestore.instance),
              ),
              cashMovementReaderProvider.overrideWithValue(
                FirestoreCashMovementDirectory(FirebaseFirestore.instance),
              ),
              // ★★ `WU-007` — المقبوضات: **القراءة مباشرة والكتابة عبر
              //   العمليات المستدعاة الأربع** (`ADR-0013` القاعدتان 2 و4).
              //   ⛔★★ **ولا كتابة مباشرة على `receipts` ولا على حالة
              //   إيداعها ولا على دفتر المقاوته ولا أرصدته ولا فائضه.**
              receiptDirectoryProvider.overrideWithValue(
                FirestoreReceiptDirectory(FirebaseFirestore.instance),
              ),
              receiptAdminProvider.overrideWithValue(
                FunctionsReceiptRepository(
                  client: _callableClient(),
                  newRequestId: _newRequestId,
                ),
              ),
              // ★★ `WU-008` — سجل التدقيق: **قراءةٌ مباشرة وحدها**
              //   (`ADR-0013` القاعدة 4). ⛔⛔ **ولا نظيرَ كاتبٍ له هنا
              //   ولا في أي مكان**: `audit_log` **`allow create, update,
              //   delete: if false` للجميع** (`FR-M18-01` · `FR-M18-04`)،
              //   ★ **والقيد يُكتب داخل معاملة مستنده في السحابة.**
              auditLogDirectoryProvider.overrideWithValue(
                FirestoreAuditLogDirectory(FirebaseFirestore.instance),
              ),
              // ⏳★★ `WU-009` — مركز الإدخالات المعلّقة: **قراءةٌ مباشرة
              //   وحدها** (`ADR-0013` القاعدة 4). ⛔⛔ **ولا نظيرَ كاتبٍ له
              //   هنا ولا في أي مكان**: `pending_entries` **`allow write:
              //   if false`** (`FR-SYS-09`)، ★ **والبنود تُكتب وتُمحى داخل
              //   معاملة مستندها في السحابة.**
              pendingEntryDirectoryProvider.overrideWithValue(
                FirestorePendingEntryDirectory(FirebaseFirestore.instance),
              ),
              // ★★ `WU-010` — الإرسال والتصدير (`M20`).
              //
              // ⛔⛔★★ **والإرسال بلا مستودعٍ ولا كاتبٍ عمداً** — `FR-M20-15`
              //   و`FR-M20-16`: **إجراء واجهة فقط، ولا تسجيل لمحاولاته**
              //   (`AT-64`). ⟵ **فما يُحقَن هنا فاتحُ قناةٍ لا مُرسِل.**
              //
              // ★ **والتصدير وحده يكتب** — **قيدَ تدقيقٍ عبر `logExport`**
              //   (`FR-M19-04` · `IQ-032`)، ⛔ **ولا كتابة مباشرة على
              //   `audit_log` مطلقاً.**
              exportLogRepositoryProvider.overrideWithValue(
                FunctionsExportLogRepository(
                  client: _callableClient(),
                  newRequestId: _newRequestId,
                ),
              ),
              pdfRendererProvider.overrideWithValue(PdfDocumentRenderer()),
              documentShareProvider.overrideWithValue(DocumentShareService()),
              messageChannelProvider
                  .overrideWithValue(const MessageChannelLauncher()),
              // ★★ `WU-011` — التقارير (`M19`): **قراءةٌ مباشرة وحدها**
              //   (`ADR-0013` القاعدة 4). ⛔⛔ **ولا نظيرَ كاتبٍ له إطلاقاً**:
              //   ★ **التقريرُ مشتقٌّ يُبنى عند الطلب ولا يُخزَّن** (`ADR-0008`)،
              //   ⟵ **والأثرُ الوحيد الذي يكتبه تصديرُه** — **قيدُ «تصدير»
              //   عبر `logExport` أعلاه** (`FR-M19-04`) ⛔ **لا مستندَ تقرير.**
              reportDirectoryProvider.overrideWithValue(
                FirestoreReportDirectory(FirebaseFirestore.instance),
              ),
            ]
          : const [],
      child: QtmsApp(outcome: outcome),
    ),
  );
}

/// يُسجِّل رخصة الخط في سجل الرخص — `third-party-assets-licenses.md`
/// (SIL OFL 1.1 تشترط مرافقة نصّ الرخصة للتوزيع).
void _registerFontLicense() {
  LicenseRegistry.addLicense(() async* {
    final String license = await rootBundle.loadString('assets/fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(
      const <String>['IBM Plex Sans Arabic'],
      license,
    );
  });
}

/// جذر التطبيق.
class QtmsApp extends ConsumerWidget {
  const QtmsApp({required this.outcome, super.key});

  final StartupOutcome outcome;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ⛔ منصة غائبة ⟵ لا تطبيق أصلاً: `ERR_CONN_002` صريحة لا فشل صامت
    //    (`C-04` · `FR-SYS-27` · ✅ **والنصّ صار معتمداً** — راجع `DEBT-13`).
    if (outcome is StartupFailed) {
      return const _StartupFailureApp();
    }

    final GoRouter router = ref.watch(routerProvider);
    return MaterialApp.router(
      // ★ AM-002: العنوان يظهر في مبدّل مهام أندرويد — ⛔ فلا 'QTMS' فيه،
      //   والمصدر واحد مشترك مع `android:label`.
      title: appDisplayName,
      debugShowCheckedModeBanner: false,
      theme: buildQtmsTheme(),
      // ★ العربية اللغة الوحيدة المدعومة (`supported-languages.md`)،
      //   و`MaterialApp` يشتقّ اتجاه RTL منها — فلا `Directionality` يدوي.
      locale: const Locale('ar'),
      supportedLocales: const <Locale>[Locale('ar')],
      localizationsDelegates: const <LocalizationsDelegate<Object>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
    );
  }
}

/// تطبيق بديل عند تعذّر الإقلاع — **رسالة الكتالوج وحدها.**
class _StartupFailureApp extends StatelessWidget {
  const _StartupFailureApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: appDisplayName,
      debugShowCheckedModeBanner: false,
      theme: buildQtmsTheme(),
      locale: const Locale('ar'),
      supportedLocales: const <Locale>[Locale('ar')],
      localizationsDelegates: const <LocalizationsDelegate<Object>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(Spacing.space24),
              child: Text(
                catalogText(CatalogMessage.platformUnavailable),
                textAlign: TextAlign.center,
                style: TypeScale.bodyLg
                    .copyWith(color: SemanticColors.textPrimary),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// عميل الاستدعاء — ★ **يقرأ الرمز عند كل استدعاء** ⛔ لا يخزّنه.
CallableClient _callableClient() => CallableClient(
      httpClient: http.Client(),
      // ⚠️ **بلا `forceRefresh`:** المنصّة تُجدّد الرمز المنتهي تلقائياً،
      //    ★ **والإجبار في كل استدعاء رحلةُ شبكة زائدة** لكل عملية إدارية.
      readIdToken: () async =>
          FirebaseAuth.instance.currentUser?.getIdToken(),
    );

/// ★★ معرّف طلب فريد لكل عملية — وهو **معرّف قيد التدقيق نفسه**.
///
/// ⚠️ **ولماذا الوقت والعشوائية معاً:** الوقت وحده **يتكرر** بين ضغطتين في
/// الميلي ثانية نفسها ⟵ **فيكتب الثاني فوق قيد الأول**، والعشوائية وحدها
/// تجعل القيود **غير مرتَّبة زمنياً** في السجل. ★ **واجتماعهما يُعطي تفرّداً
/// وترتيباً معاً.**
///
/// ⛔ **ولا يُولَّد في السحابة:** مُولَّدٌ هناك يتغيّر مع كل محاولة، ⟵ **فتصير
/// كل إعادة إرسالٍ عمليةً جديدة** بدل أن تكتب فوق قيدها (`api-overview.md` §4).
String _newRequestId() {
  final int now = DateTime.now().microsecondsSinceEpoch;
  final int noise = Random().nextInt(0xFFFFFF);
  return 'REQ-$now-${noise.toRadixString(16)}';
}

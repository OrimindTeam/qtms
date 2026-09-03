/// نقاط دخول العمليات السحابية.
///
/// ★ يولّد `functions_framework_builder` من التعليقات التوضيحية هنا الملف
/// `bin/server.dart` — ⛔ **ولا يُحرَّر ذلك الملف يدوياً**.
///
/// **الحالة الآن:** ★★ **إحدى وأربعون عمليةً مستدعاة خلف نقطة دخول واحدة**
/// (`callables` — حسم `IQ-019` الخيار أ) ★★ **وعمليتان مشغَّلتان بالكتابة**
/// من §3.2 (`provisionAccountsOnSourceAdd` · `provisionAccountsOnPartyAdd`).
/// بقية الدوال تُبنى في زياداتها، كما يفرض `ADR-0009` ②.
///
/// ★★★ **وثلاثة أهداف لا إحدى وأربعون** (`FUNCTION_TARGET`): `callables` +
/// المُشغَّلتان. ⟵ ⛔ **والعمليات المستدعاة ليست أهدافاً مستقلة** — ★ **لأن
/// `FUNCTION_TARGET` هدفٌ واحد لكل حاوية ولا يوجّه بالمسار**، ⟵ **فنشرُها
/// أهدافاً منفصلة كان يعني مضيفاً لكل عملية**، وهو ما رفضه `IQ-019`.
///
/// ✅ ★ **وأُزيلت عيّنة إثبات `DEBT-09` بعد أن أدّت غرضها** (`DEBT-14`):
/// أثبتت أن المسار يُبنى ويُنشَر ويستقبل ويكتب بـDart وحده، ⛔ **ولا يبقى
/// كودٌ مؤقت في مسار الإنتاج.**
library;

import 'dart:io' show Platform, stdout;

import 'package:functions_framework/functions_framework.dart';
import 'src/firestore_writer.dart';
import 'package:qtms_domain/qtms_domain.dart';
import 'package:shelf/shelf.dart';

import 'src/account_provisioning_handler.dart';
import 'src/audited_transaction.dart';
import 'src/callable.dart';
import 'src/callable_router.dart';
import 'src/cash_sale.dart';
import 'src/cash_sale_handler.dart';
import 'src/daily_pricing.dart';
import 'src/daily_pricing_handler.dart';
import 'src/discount.dart';
import 'src/discount_handler.dart';
import 'src/distribution.dart';
import 'src/distribution_handler.dart';
import 'src/export_log.dart';
import 'src/export_log_handler.dart';
import 'src/identity_gateway.dart';
import 'src/inventory.dart';
import 'src/inventory_handler.dart';
import 'src/outflow.dart';
import 'src/outflow_handler.dart';
import 'src/owner_ledger_summary_handler.dart';
import 'src/owner_bootstrap_handler.dart';
import 'src/permission_sync.dart';
import 'src/receipt.dart';
import 'src/receipt_handler.dart';
import 'src/sack_intake.dart';
import 'src/sack_intake_handler.dart';
import 'src/sack_valuation_handler.dart';
import 'src/permission_sync_handler.dart';
import 'src/master_data.dart';
import 'src/master_data_handler.dart';
import 'src/user_admin.dart';
import 'src/user_admin_handler.dart';

/// متغيّر البيئة الذي تضعه المنصة تلقائياً — ⛔ **وليس سرّاً**.
const String _projectIdVariable = 'GOOGLE_CLOUD_PROJECT';

/// ★ معرّف حساب المالك الأول لهذه البيئة — `environments.md` §1.3.
///
/// ⚠️ **معرّف لا سرّ** (كما ينصّ `environments.md` §1.3 حرفياً)، فيُضبَط
/// كمتغيّر بيئة عند النشر ولا يدخل `secrets-management-policy.md`.
/// ★ **ولماذا من البيئة لا من قاعدة البيانات:** مستند الإعداد التأسيسي
/// (`app_settings`) يُكتب في `WU-002` ولا وجود له لحظة الإقلاع — فلا يصلح
/// مصدراً لهوية المالك في اللحظة التي يوجد فيها المالك وحده.
const String _ownerUserIdVariable = 'QTMS_OWNER_UID';

/// تضعه المنصة تلقائياً على Cloud Run، ويُضبَط محلياً قبل التشغيل.
String? _resolveProjectId() {
  final String? value = Platform.environment[_projectIdVariable];
  return (value == null || value.isEmpty) ? null : value;
}

// ═══════════════════════════════════════════════════════════════════════
// العمليات المستدعاة — `api-overview.md` §3.1 · `ADR-0013`
// ═══════════════════════════════════════════════════════════════════════

/// ★ **تبعيات مبنيّة مرة واحدة لكل حاوية** — ⛔ لا في كل طلب.
///
/// ⚠️ **ولماذا كسولة لا في أعلى الملف:** بناؤها يفتح اتصالاً ويطلب بيانات
/// اعتماد، وذلك **يفشل في بيئة الاختبار** التي لا تملكها. والتهيئة عند أول
/// طلب فعلي تُبقي الملف قابلاً للاستيراد في اختبار وحدة عادي.
Future<PermissionSyncHandler>? _syncHandler;
Future<SackIntakeHandler>? _sackHandler;
Future<OwnerBootstrapHandler>? _bootstrapHandler;
Future<AccountProvisioningHandler>? _provisioningHandler;
Future<UserAdminHandler>? _userAdminHandler;
Future<MasterDataHandler>? _masterDataHandler;
Future<InventoryHandler>? _inventoryHandler;
Future<DailyPricingHandler>? _dailyPricingHandler;
Future<DistributionHandler>? _distributionHandler;
Future<CashSaleHandler>? _cashSaleHandler;
Future<ReceiptHandler>? _receiptHandler;
Future<DiscountHandler>? _discountHandler;
Future<OutflowHandler>? _outflowHandler;
Future<ExportLogHandler>? _exportLogHandler;

/// ★★★ **`callables` — نقطة الدخول الوحيدة للعمليات المستدعاة** (`IQ-019`).
///
/// ★ **حاويةٌ واحدة تحملها كلها، والمسار يختار المعالج** — ⟵ **فالتطبيق
/// يعرف عنواناً واحداً لكل بيئة** (`QTMS_FUNCTIONS_BASE_URL`)، ⛔ **ولا
/// اسم خدمة ولا بصمة نشر ولا معرّف Cloud Run يدخل بناءه.**
///
/// ⛔★★ **والتصريف هنا شاملٌ بلا نمط `_`** — ★ **فالتصريف هو الحارس:**
/// عمليةٌ تُضاف إلى [CallableOperation] بلا سطر هنا **تُسقِط البناء**،
/// ⛔ **ولا تصل الشبكةَ بمعالجٍ خاطئ.**
///
/// ⚠️⚠️ **والموجّه لا يفحص مصادقةً ولا تفويضاً ولا يكتب قيداً** — ★ **كلٌّ
/// من ذلك في معالجه** (`ADR-0013` القاعدة 3 · القاعدة ④ من `IQ-019`).
/// ⟵ **فلا موضع ثانٍ يُفترَض أنه يحرس، ولا حارسٌ يُظنّ أنه هنا فيُسقَط هناك.**
@CloudFunction()
Future<Response> callables(Request request) async {
  final CallableOperation? operation =
      resolveCallableOperation(request.requestedUri.path);
  if (operation == null) {
    // ⛔★★ **رفضٌ صريح** — القاعدة ② من `IQ-019`: ⛔ **ولا معالج افتراضي.**
    //    ★ **والمسار يُسجَّل** لأن مساراً مجهولاً يتكرر **عطلُ عميلٍ يُشخَّص**
    //    لا هجوم — ⛔ **ولا حمولة ولا رمز دخول في السجل** (§2.4).
    stdout.writeln('callables: ⛔ مسار غير معروف ⟵ ${request.requestedUri.path}');
    return callableFailure(
      CallableError.unknownOperation,
      detail: 'مسار غير معروف',
    );
  }

  return switch (operation) {
    CallableOperation.grantPermissions => grantPermissions(request),
    CallableOperation.setSourceScope => setSourceScope(request),
    CallableOperation.bootstrapOwnerPermissions =>
      bootstrapOwnerPermissions(request),
    CallableOperation.createUser => createUser(request),
    CallableOperation.updateUser => updateUser(request),
    CallableOperation.disableUser => disableUser(request),
    CallableOperation.createRole => createRole(request),
    CallableOperation.updateRole => updateRole(request),
    CallableOperation.deleteRole => deleteRole(request),
    CallableOperation.createSource =>
      _masterData(request, MasterDataOperation.createSource),
    CallableOperation.updateSource =>
      _masterData(request, MasterDataOperation.updateSource),
    CallableOperation.createSupplier =>
      _masterData(request, MasterDataOperation.createSupplier),
    CallableOperation.updateSupplier =>
      _masterData(request, MasterDataOperation.updateSupplier),
    CallableOperation.createDealer =>
      _masterData(request, MasterDataOperation.createDealer),
    CallableOperation.updateDealer =>
      _masterData(request, MasterDataOperation.updateDealer),
    CallableOperation.createItem =>
      _masterData(request, MasterDataOperation.createItem),
    CallableOperation.updateItem =>
      _masterData(request, MasterDataOperation.updateItem),
    CallableOperation.writeAppSettings =>
      _masterData(request, MasterDataOperation.writeAppSettings),
    CallableOperation.createCountedIntake =>
      _inventory(request, InventoryOperation.createCountedIntake),
    CallableOperation.amendCountedIntake =>
      _inventory(request, InventoryOperation.amendCountedIntake),
    CallableOperation.cancelCountedIntake =>
      _inventory(request, InventoryOperation.cancelCountedIntake),
    CallableOperation.writeDailyPrices =>
      _dailyPricing(request, DailyPricingOperation.writeDailyPrices),
    CallableOperation.createSack => _sack(request, SackOperation.createSack),
    CallableOperation.enterSackLines =>
      _sack(request, SackOperation.enterSackLines),
    CallableOperation.enterSackTax =>
      _sack(request, SackOperation.enterSackTax),
    CallableOperation.renameSack => _sack(request, SackOperation.renameSack),
    CallableOperation.enterSackScrapWeight =>
      _sack(request, SackOperation.enterSackScrapWeight),
    CallableOperation.confirmSackLostWeight =>
      _sack(request, SackOperation.confirmSackLostWeight),
    CallableOperation.amendSack => _sack(request, SackOperation.amendSack),
    CallableOperation.cancelSack => _sack(request, SackOperation.cancelSack),
    CallableOperation.createDistribution =>
      _distribution(request, DistributionOperation.createDistribution),
    CallableOperation.amendDistribution =>
      _distribution(request, DistributionOperation.amendDistribution),
    CallableOperation.cancelDistribution =>
      _distribution(request, DistributionOperation.cancelDistribution),
    CallableOperation.createCashSale =>
      _cashSale(request, CashSaleOperation.createCashSale),
    CallableOperation.amendCashSale =>
      _cashSale(request, CashSaleOperation.amendCashSale),
    CallableOperation.cancelCashSale =>
      _cashSale(request, CashSaleOperation.cancelCashSale),
    CallableOperation.createReceipt =>
      _receipt(request, ReceiptOperation.createReceipt),
    CallableOperation.amendReceipt =>
      _receipt(request, ReceiptOperation.amendReceipt),
    CallableOperation.cancelReceipt =>
      _receipt(request, ReceiptOperation.cancelReceipt),
    CallableOperation.confirmReceiptDeposit =>
      _receipt(request, ReceiptOperation.confirmReceiptDeposit),
    CallableOperation.createDiscount =>
      _discount(request, DiscountOperation.createDiscount),
    CallableOperation.amendDiscount =>
      _discount(request, DiscountOperation.amendDiscount),
    CallableOperation.cancelDiscount =>
      _discount(request, DiscountOperation.cancelDiscount),
    CallableOperation.createOutflow =>
      _outflow(request, OutflowOperation.createOutflow),
    CallableOperation.amendOutflow =>
      _outflow(request, OutflowOperation.amendOutflow),
    CallableOperation.cancelOutflow =>
      _outflow(request, OutflowOperation.cancelOutflow),
    CallableOperation.logExport =>
      _exportLog(request, ExportLogOperation.logExport),
  };
}

/// ★ مسار تسجيل التصدير (`WU-010`).
///
/// ⛔★★ **ولا يحتاج `QTMS_OWNER_UID`:** حارس المالك (`BR-M1-02`) يخصّ
/// **حسابات المستخدمين** وحدها — ★ **وتفويض التصدير مفتاحُه `documentExport`
/// مع نطاق المصادر**، ويُفحَصان في `exportLogGate`.
Future<Response> _exportLog(
  Request request,
  ExportLogOperation operation,
) async {
  final ExportLogHandler handler =
      await (_exportLogHandler ??= _buildExportLog());
  return handler.handle(request, operation);
}

Future<ExportLogHandler> _buildExportLog() async {
  final (IdentityGateway identity, AuditedTransaction transaction) =
      await _connectDependencies();
  return ExportLogHandler(identity: identity, transaction: transaction);
}

/// ★ المسار المشترك لعمليات التوزيع الثلاث (`WU-006`).
///
/// ⛔★★ **ولا يحتاج `QTMS_OWNER_UID`:** حارس المالك (`BR-M1-02`) يخصّ
/// **حسابات المستخدمين** وحدها — ★ **وتفويض التوزيع مفاتيحُه الستة**
/// (`distributionCreate` · `Amend` · `Cancel` · `PriceNow` · `PriceAmend` ·
/// `PriceClear`) **مع نطاق المصادر**، وتُفحَص في `distributionGate`
/// و`_priceGate`.
Future<Response> _distribution(
  Request request,
  DistributionOperation operation,
) async {
  final DistributionHandler handler =
      await (_distributionHandler ??= _buildDistribution());
  return handler.handle(request, operation);
}

/// ★ المسار المشترك لعمليات البيع النقدي الثلاث (`WU-012`).
///
/// ⛔★★ **ولا يحتاج `QTMS_OWNER_UID`:** حارس المالك (`BR-M1-02`) يخصّ
/// **حسابات المستخدمين** وحدها — ★ **وتفويض البيع النقدي مفاتيحُه الأربعة**
/// (`cashSaleCreate` · `cashSaleBelowMinimum` · `cashSaleAmend` ·
/// `cashSaleCancel`) **مع نطاق المصادر**، وتُفحَص في `cashSaleGate`
/// و`planCashSale`.
Future<Response> _cashSale(
  Request request,
  CashSaleOperation operation,
) async {
  final CashSaleHandler handler =
      await (_cashSaleHandler ??= _buildCashSale());
  return handler.handle(request, operation);
}

Future<CashSaleHandler> _buildCashSale() async {
  final (
    IdentityGateway identity,
    AuditedTransaction transaction,
    SackValuationHandler valuation,
    OwnerLedgerSummaryHandler summaries,
  ) = await _connectWritingDependencies();
  return CashSaleHandler(
    identity: identity,
    transaction: transaction,
    valuation: valuation,
    summaries: summaries,
  );
}

/// ★ المسار المشترك لعمليات السحبيات والخرجيات الثلاث (`WU-014`).
///
/// ⛔★★ **ولا يحتاج `QTMS_OWNER_UID`:** حارس المالك (`BR-M1-02`) يخصّ
/// **حسابات المستخدمين** وحدها — ★★ **وتفويضُ هذه العمليات ثمانيةُ مفاتيح
/// موزَّعةٌ على سجلَّين** (`withdrawalCreate` · `withdrawalAmend` ·
/// `withdrawalCancel` · `withdrawalQatPriceNow` · `withdrawalBackdate` ·
/// ونظائرُها الأربعة للخرجيات) **مع نطاق المصادر** — ⟵ **ويختارها
/// `outflowPermission` من `ledgerType`**، وتُفحَص في `outflowGate`
/// و`planOutflow`.
Future<Response> _outflow(Request request, OutflowOperation operation) async {
  final OutflowHandler handler = await (_outflowHandler ??= _buildOutflow());
  return handler.handle(request, operation);
}

Future<OutflowHandler> _buildOutflow() async {
  final (
    IdentityGateway identity,
    AuditedTransaction transaction,
    SackValuationHandler valuation,
    OwnerLedgerSummaryHandler summaries,
  ) = await _connectWritingDependencies();
  return OutflowHandler(
    identity: identity,
    transaction: transaction,
    valuation: valuation,
    summaries: summaries,
  );
}

/// ★ المسار المشترك لعمليات القبض الأربع (`WU-007`).
///
/// ⛔★★ **ولا يحتاج `QTMS_OWNER_UID`:** حارس المالك (`BR-M1-02`) يخصّ
/// **حسابات المستخدمين** وحدها — ★ **وتفويض القبض مفاتيحُه الستة**
/// (`receiptCreate` · `receiptAmend` · `receiptCancel` · `receiptBackdate` ·
/// `receiptDepositView` · `receiptDepositConfirm`) **مع نطاق المصادر**،
/// وتُفحَص في `receiptGate` و`planReceipt`.
Future<Response> _receipt(Request request, ReceiptOperation operation) async {
  final ReceiptHandler handler = await (_receiptHandler ??= _buildReceipt());
  return handler.handle(request, operation);
}

Future<ReceiptHandler> _buildReceipt() async {
  final (
    IdentityGateway identity,
    AuditedTransaction transaction,
    OwnerLedgerSummaryHandler summaries,
  ) = await _connectSettlementDependencies();
  return ReceiptHandler(
    identity: identity,
    transaction: transaction,
    summaries: summaries,
  );
}

/// ★ المسار المشترك لعمليات الخصم الثلاث (`WU-013`).
///
/// ⛔★★ **ولا يحتاج `QTMS_OWNER_UID`:** حارس المالك (`BR-M1-02`) يخصّ
/// **حسابات المستخدمين** وحدها — ★ **وتفويض الخصم مفاتيحُه الأربعة**
/// (`discountCreate` · `discountBackdate` · `discountAmend` ·
/// `discountCancel`) **مع نطاق المصادر**، وتُفحَص في `discountGate`
/// و`planDiscount`.
Future<Response> _discount(Request request, DiscountOperation operation) async {
  final DiscountHandler handler =
      await (_discountHandler ??= _buildDiscount());
  return handler.handle(request, operation);
}

Future<DiscountHandler> _buildDiscount() async {
  final (
    IdentityGateway identity,
    AuditedTransaction transaction,
    OwnerLedgerSummaryHandler summaries,
  ) = await _connectSettlementDependencies();
  return DiscountHandler(
    identity: identity,
    transaction: transaction,
    summaries: summaries,
  );
}

/// ★ المسار المشترك لعمليات المخزون الثلاث (`WU-003`).
///
/// ⛔★★ **ولا يحتاج `QTMS_OWNER_UID`:** حارس المالك (`BR-M1-02`) يخصّ
/// **حسابات المستخدمين** وحدها — ★ **وتفويض المخزون مفاتيحُه الثلاثة**
/// (`incomingCountWrite` · `Amend` · `Cancel`) **مع نطاق المصادر**،
/// وتُفحَص كلها في `inventoryGate`.
Future<Response> _inventory(
  Request request,
  InventoryOperation operation,
) async {
  final InventoryHandler handler =
      await (_inventoryHandler ??= _buildInventory());
  return handler.handle(request, operation);
}

/// ★ المسار المشترك لعمليات الجواني السبع (`WU-004`).
///
/// ⛔★★ **ولا يحتاج `QTMS_OWNER_UID`:** حارس المالك (`BR-M1-02`) يخصّ
/// **حسابات المستخدمين** وحدها — ★ **وتفويض الجواني مفاتيحُه السبعة**
/// (`sackCreate` · `sackLinesEnter` · `sackTaxEnterNow`/`Later` ·
/// `sackRenameDisplay` · `sackScrapWeightEnter` · `sackLostWeightConfirm` ·
/// `sackAmend` · `sackCancel`) **مع نطاق المصادر**، وتُفحَص في `sackGate`.
Future<Response> _sack(Request request, SackOperation operation) async {
  final SackIntakeHandler handler = await (_sackHandler ??= _buildSack());
  return handler.handle(request, operation);
}

/// ★ مسار التسعير اليومي (`WU-005`).
///
/// ⛔★★ **ولا يحتاج `QTMS_OWNER_UID`:** حارس المالك (`BR-M1-02`) يخصّ
/// **حسابات المستخدمين** وحدها — ★ **وتفويض التسعير مفتاحُه `dailyPriceWrite`
/// مع نطاق المصادر**، ويُفحَصان في `dailyPricingGate`.
Future<Response> _dailyPricing(
  Request request,
  DailyPricingOperation operation,
) async {
  final DailyPricingHandler handler =
      await (_dailyPricingHandler ??= _buildDailyPricing());
  return handler.handle(request, operation);
}

/// ★ المسار المشترك لعمليات البيانات المرجعية التسع.
///
/// ⛔★★ **ولا يحتاج `QTMS_OWNER_UID`:** حارس المالك (`BR-M1-02`) يخصّ
/// **حسابات المستخدمين** وحدها، ⟵ **والبيانات المرجعية لا مالك لها**؛
/// ★ **وتفويضها مفاتيحُ الكتالوج الخمسة** تُفحَص في `masterDataGate`.
Future<Response> _masterData(
  Request request,
  MasterDataOperation operation,
) async {
  final MasterDataHandler handler =
      await (_masterDataHandler ??= _buildMasterData());
  return handler.handle(request, operation);
}

/// `grantPermissions` — يمنح صلاحيات مستخدماً آخر.
///
/// ★ **يشترط `permissionGrant` على مُنفِّذه** — ويُفحَص **في الكود** صراحةً
/// (`ADR-0013` القاعدة 3)، ⛔ **ولا يتّكل على قواعد الحماية** لأن هذا المسار
/// يعمل بامتياز إداري يتجاوزها.
Future<Response> grantPermissions(Request request) async {
  final PermissionSyncHandler handler = await (_syncHandler ??= _buildSync());
  return handler.handle(request, PermissionSyncOperation.grantPermissions);
}

/// `setSourceScope` — يحدّد نطاق مصادر مستخدم.
///
/// ★ **يشترط `sourceScopeSet`** — ★ **«أخطر صلاحية في النظام»**
/// (`api-overview.md` §3.1).
Future<Response> setSourceScope(Request request) async {
  final PermissionSyncHandler handler = await (_syncHandler ??= _buildSync());
  return handler.handle(request, PermissionSyncOperation.setSourceScope);
}

/// `bootstrapOwnerPermissions` — ★ **يكسر حلقة إقلاع `IQ-007`**.
///
/// ⛔ **لا يُستدعى من التطبيق** — إجراء تشغيلي موثَّق لمرة واحدة:
/// `docs/13-operations/runbooks/RB-bootstrap-owner-permissions.md`.
Future<Response> bootstrapOwnerPermissions(Request request) async {
  final String? ownerUserId = _resolveOwnerUserId();
  if (ownerUserId == null) {
    // ★ الإعداد ناقص — ⛔ ولا يُخمَّن مالك. والرفض هو الافتراض الآمن.
    return callableFailure(
      CallableError.internal,
      detail: 'متغيّر $_ownerUserIdVariable غائب — تعذّر تحديد المالك المسجَّل',
    );
  }
  final OwnerBootstrapHandler handler =
      await (_bootstrapHandler ??= _buildBootstrap(ownerUserId));
  return handler.handle(request);
}

/// `createUser` — ★ **ينشئ حساباً وبطاقة** (`FR-M1-01` · `IQ-015`).
///
/// ⛔★★ **ولا يمنح صلاحيةً ولا نطاقاً ولا كلمة مرور:** المنح مسارُه
/// `grantPermissions` **بقواعده** (`BR-M1-03`)، وكلمة المرور **يضبطها
/// صاحبُها** برابط استرجاع (`authentication-policy.md` §5).
Future<Response> createUser(Request request) =>
    _userAdmin(request, UserAdminOperation.createUser);

/// `updateUser` — يعدّل بيانات مستخدم. ★ **ولا يمسّ حساب المالك من غيره**
/// (`BR-M1-02` · `FR-M1-11`).
Future<Response> updateUser(Request request) =>
    _userAdmin(request, UserAdminOperation.updateUser);

/// `disableUser` — ★★ **يعطّل في البطاقة وفي خدمة المصادقة معاً**
/// (`IQ-017` الخيار ج · `FR-M1-12` · `FR-M1-15`). ⛔ **ولا حذف إطلاقاً.**
Future<Response> disableUser(Request request) =>
    _userAdmin(request, UserAdminOperation.disableUser);

/// `createRole` — ينشئ دوراً (`FR-M1-03`).
Future<Response> createRole(Request request) =>
    _userAdmin(request, UserAdminOperation.createRole);

/// `updateRole` — يعدّل دوراً. ★ **بسببٍ نصّي إلزامي** (`ADR-0004`).
Future<Response> updateRole(Request request) =>
    _userAdmin(request, UserAdminOperation.updateRole);

/// ★★ `deleteRole` — **يحذف قالب دورٍ غير مُسنَد حذفاً فعلياً**
/// (`IQ-018` الخيار ب · `FR-M1-03`).
///
/// ★★ **وهي العملية الوحيدة في النظام التي تحذف مستنداً** — ⛔ **ولا يُقاس
/// عليها مستخدمٌ ولا حركة ولا قيد تدقيق**: تلك سجلات ذات تاريخ، **وهذا قالبٌ
/// لا يشير إليه أحد** (`security-requirements.md` §2 البند 1 واستثناؤه).
///
/// ⛔★★ **والإسناد يُقاس باستعلامٍ فعلي على `users` داخل المعاملة** — ⟵
/// **لا حقل `isAssigned` في مستند الدور، ولا كاش في التطبيق، ولا قيمة
/// مُرسَلة في الحمولة يُوثَق بها.**
Future<Response> deleteRole(Request request) =>
    _userAdmin(request, UserAdminOperation.deleteRole);

Future<Response> _userAdmin(
  Request request,
  UserAdminOperation operation,
) async {
  final String? ownerUserId = _resolveOwnerUserId();
  if (ownerUserId == null) {
    // ★ **الإعداد ناقص ⟵ رفض** — ⛔ ولا يُخمَّن مالك. ⚠️ **والحارس يلزم
    //   هنا كما يلزم في الإقلاع**: بلا معرّف المالك **يسقط `BR-M1-02`
    //   صامتاً** فيصير حساب المالك قابلاً للتعديل والتعطيل من أي مدير.
    return callableFailure(
      CallableError.internal,
      detail: 'متغيّر $_ownerUserIdVariable غائب — تعذّر تطبيق حارس المالك',
    );
  }
  final UserAdminHandler handler =
      await (_userAdminHandler ??= _buildUserAdmin(ownerUserId));
  return handler.handle(request, operation);
}

// ═══════════════════════════════════════════════════════════════════════
// العمليات المشغَّلة بالكتابة — `api-overview.md` §3.2
// ═══════════════════════════════════════════════════════════════════════

/// `provisionAccountsOnSourceAdd` — **إضافة مصدر** ⟵ حساب لكل مقوت ولكل
/// رعوي **+ نسخة السكرب** (`api-overview.md` §3.2).
///
/// ★★ **ولا يحتاج فكّ حمولة الحدث** (`DEBT-16`): المسار ونوع التغيير يصلان
/// في `subject` و`type` **خارج الحمولة**، وهما كل ما تحتاجه التهيئة.
@CloudFunction()
Future<void> provisionAccountsOnSourceAdd(CloudEvent event) =>
    _provision('provisionAccountsOnSourceAdd', event);

/// `provisionAccountsOnPartyAdd` — **إضافة مقوت أو رعوي** ⟵ حساب له في
/// **كل** المصادر القائمة (`api-overview.md` §3.2).
///
/// ⚠️ **ولماذا نقطتا دخول ومنطقهما واحد:** العقد في `api-overview.md` §3.2
/// **يسمّيهما عمليتين بمُشغِّلين مختلفين**، ⛔ **فلا تُدمجان في اسم واحد**.
/// ★ **ومشغّلات Eventarc تُنشَأ لكل مجموعة على حدة أصلاً** — فالفصل هنا
/// **مطابقة للعقد بلا كلفة**، والمنطق مشترك في [AccountProvisioningHandler].
@CloudFunction()
Future<void> provisionAccountsOnPartyAdd(CloudEvent event) =>
    _provision('provisionAccountsOnPartyAdd', event);

/// المسار المشترك — ★ **وأيّ نقطة دخول تتصرّف بحسب مسار المستند لا باسمها**،
/// ⟵ فمشغّلٌ مُوجَّه خطأً يُنتج «تجاهلاً» صريحاً لا سلوكاً خاطئاً.
///
/// ⛔ **ولا يُبتلَع فشل:** أي استثناء يصعد فيفشل التسليم، **فيعيد Eventarc
/// المحاولة** — والعملية قابلة للتكرار بلا أثر جانبي فلا ضرر في الإعادة.
Future<void> _provision(String operation, CloudEvent event) async {
  final AccountProvisioningHandler handler =
      await (_provisioningHandler ??= _buildProvisioning());
  final ProvisioningOutcome outcome = await handler.handleEvent(
    eventType: event.type,
    subject: event.subject,
  );
  // ★ سجلٌّ بالمعرّفات وحدها — ⛔ ولا قيمة حساسة (`coding-standards.md` §2.4).
  stdout.writeln('$operation: ${event.subject} ⟵ $outcome');
  if (outcome.scrapMissing) {
    // ⚠️ شذوذ تشغيلي يُرصَد ولا يُبتلَع: مصدر أُضيف ولا نوع افتراضي في
    //    النظام بعد — ولا تخترع التهيئةُ النوعَ (اختصاص `M5`).
    stdout.writeln(
      '$operation: ⚠️ لا نوع افتراضي «سكرب» في النظام — لم يُوصَل المصدر',
    );
  }
}

Future<AccountProvisioningHandler> _buildProvisioning() async {
  final String? projectId = _resolveProjectId();
  if (projectId == null) {
    throw StateError('متغيّر $_projectIdVariable غائب — تعذّر تحديد المشروع');
  }
  return AccountProvisioningHandler(
    FirestoreProvisioningStore(
      await FirestoreWriter.connect(projectId: projectId),
    ),
  );
}

Future<PermissionSyncHandler> _buildSync() async {
  final (IdentityGateway identity, AuditedTransaction transaction) =
      await _connectDependencies();
  return PermissionSyncHandler(identity: identity, transaction: transaction);
}

Future<UserAdminHandler> _buildUserAdmin(String ownerUserId) async {
  final (IdentityGateway identity, AuditedTransaction transaction) =
      await _connectDependencies();
  return UserAdminHandler(
    identity: identity,
    transaction: transaction,
    ownerUserId: ownerUserId,
  );
}

Future<InventoryHandler> _buildInventory() async {
  final (IdentityGateway identity, AuditedTransaction transaction) =
      await _connectDependencies();
  return InventoryHandler(identity: identity, transaction: transaction);
}

Future<DailyPricingHandler> _buildDailyPricing() async {
  final (IdentityGateway identity, AuditedTransaction transaction) =
      await _connectDependencies();
  return DailyPricingHandler(identity: identity, transaction: transaction);
}

Future<DistributionHandler> _buildDistribution() async {
  final (
    IdentityGateway identity,
    AuditedTransaction transaction,
    SackValuationHandler valuation,
    OwnerLedgerSummaryHandler summaries,
  ) = await _connectWritingDependencies();
  return DistributionHandler(
    identity: identity,
    transaction: transaction,
    valuation: valuation,
    summaries: summaries,
  );
}

Future<SackIntakeHandler> _buildSack() async {
  final (
    IdentityGateway identity,
    AuditedTransaction transaction,
    SackValuationHandler valuation,
    OwnerLedgerSummaryHandler summaries,
  ) = await _connectWritingDependencies();
  return SackIntakeHandler(
    identity: identity,
    transaction: transaction,
    valuation: valuation,
    summaries: summaries,
  );
}

Future<MasterDataHandler> _buildMasterData() async {
  final (IdentityGateway identity, AuditedTransaction transaction) =
      await _connectDependencies();
  return MasterDataHandler(identity: identity, transaction: transaction);
}

Future<OwnerBootstrapHandler> _buildBootstrap(String ownerUserId) async {
  final (IdentityGateway identity, AuditedTransaction transaction) =
      await _connectDependencies();
  return OwnerBootstrapHandler(
    identity: identity,
    transaction: transaction,
    registeredOwnerUserId: ownerUserId,
  );
}

/// يفتح بوابة الهوية ومُنفِّذ المعاملات معاً — ★ **ببيانات الاعتماد الافتراضية**.
/// ⛅★★★ **تبعيات العمليات التي تمسّ جونية** — ★ **ومعها المُحتسِب** (`WU-015`).
///
/// ⚠️ **وأربعُ عملياتٍ وحدها تحتاجه:** **التوزيع** و**البيع النقدي**
/// و**السحبيات والخرجيات** و**الجواني نفسُها** — ⟵ **وهي كلُّ ما يُغيّر
/// سعرَ جونيةٍ أو ضريبتَها** (`FR-M14-05`). ⛔ **والباقي لا يُحمَّل مُحتسِباً
/// لا يستدعيه** (`api-overview.md` §3.2).
///
/// ★ **ويشارك المُحتسِبُ نفسَ [FirestoreWriter]** الذي تُبنى عليه بوابةُ
/// الهوية — ⛔ **فلا جلسةَ اعتمادٍ ثالثة** (نفسُ منطق `CounterAllocator`).
Future<
    (
      IdentityGateway,
      AuditedTransaction,
      SackValuationHandler,
      OwnerLedgerSummaryHandler,
    )> _connectWritingDependencies() async {
  final String? projectId = _resolveProjectId();
  if (projectId == null) {
    throw StateError('متغيّر $_projectIdVariable غائب — تعذّر تحديد المشروع');
  }
  final FirestoreWriter store =
      await FirestoreWriter.connect(projectId: projectId);
  return (
    await IdentityGateway.connect(
      readUserCard: (String userId) => _readUserCard(store, userId),
    ),
    await AuditedTransaction.connect(projectId: projectId),
    SackValuationHandler(store),
    OwnerLedgerSummaryHandler(store),
  );
}

/// ⛅★★★ **تبعيات العمليات التي تمسّ ضماراً بلا جونية** — **القبضُ والخصم**.
///
/// ⚠️ **ولا مُحتسِبَ جوانٍ معها** — ★ **فالقبضُ والخصمُ لا يُغيّران وزناً ولا
/// سعرَ جونية** (`FR-M14-05`)، ⛔ **وتحميلُها مُحتسِباً لا تستدعيه كلفةُ
/// اتصالٍ بلا مقابل** (`api-overview.md` §3.2).
Future<(IdentityGateway, AuditedTransaction, OwnerLedgerSummaryHandler)>
    _connectSettlementDependencies() async {
  final String? projectId = _resolveProjectId();
  if (projectId == null) {
    throw StateError('متغيّر $_projectIdVariable غائب — تعذّر تحديد المشروع');
  }
  final FirestoreWriter store =
      await FirestoreWriter.connect(projectId: projectId);
  return (
    await IdentityGateway.connect(
      readUserCard: (String userId) => _readUserCard(store, userId),
    ),
    await AuditedTransaction.connect(projectId: projectId),
    OwnerLedgerSummaryHandler(store),
  );
}

Future<(IdentityGateway, AuditedTransaction)> _connectDependencies() async {
  final String? projectId = _resolveProjectId();
  if (projectId == null) {
    throw StateError('متغيّر $_projectIdVariable غائب — تعذّر تحديد المشروع');
  }
  // ★★ ADR-0016: الصلاحيات من بطاقة المستخدم لا من الرمز — فتُحقَن البوابةُ
  //    قارئاً يقرأ `users/{userId}.permissions`، **تماماً كما تقرأها القاعدة**.
  //    ⛔ والغياب «بلا صلاحية» لا رجوعاً إلى الرمز (`ADR-0013` القاعدة 3:
  //    النسختان يجب أن تتطابقا).
  final FirestoreWriter store =
      await FirestoreWriter.connect(projectId: projectId);
  return (
    await IdentityGateway.connect(
      readUserCard: (String userId) => _readUserCard(store, userId),
    ),
    await AuditedTransaction.connect(projectId: projectId),
  );
}

/// يقرأ بطاقة المستخدم — ⛔ والغياب لقطةٌ فارغة لا خطأ.
///
/// ★★ **ويقرأ `isActive` كما هو حرفياً (`IQ-017`)** — ⛔ **ولا يطوي غيابَه
/// في `false` ولا في `true`**: الغياب يعني «بطاقة تسبق الحقل ⟵ تحتاج
/// ترحيلاً»، و`false` يعني «تعطيل صريح يُحترَم». ★ **وطيُّهما يجعل الترحيل
/// يُعيد تفعيل معطَّل** — راجع [UserCardSnapshot.isActiveField].
Future<UserCardSnapshot> _readUserCard(
  FirestoreWriter store,
  String userId,
) async {
  final Map<String, Object?>? card = await store.readDocument(
    collectionId: usersCollection,
    documentId: userId,
  );
  if (card == null) return UserCardSnapshot.absent;
  final Object? raw = card[permissionsField];
  final Set<Permission> granted = <Permission>{};
  if (raw is Map<String, Object?>) {
    for (final MapEntry<String, Object?> e in raw.entries) {
      if (e.value != true) continue;
      for (final Permission p in Permission.values) {
        if (p.name == e.key) granted.add(p);
      }
    }
  }
  final Object? state = card[userIsActiveField];
  return UserCardSnapshot(
    permissions: granted,
    // ⛔ **ما ليس `bool` فهو غائب** — ولا يُؤوَّل نصٌّ ولا رقمٌ حالةَ حساب.
    isActiveField: state is bool ? state : null,
  );
}

String? _resolveOwnerUserId() {
  final String? value = Platform.environment[_ownerUserIdVariable];
  return (value == null || value.trim().isEmpty) ? null : value.trim();
}

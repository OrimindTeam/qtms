/// طبقة النطاق المشتركة لـQTMS.
///
/// ★ **`ADR-0012`:** حزمة Dart **نقية** يستوردها **التطبيق** و**العمليات
/// السحابية** معاً — فتُكتب كل معادلة **مرة واحدة** ويستحيل أن يفترق رقم
/// يعرضه التطبيق عن رقم تبنيه السحابة، لأنهما **نفس الدالة حرفياً**.
///
/// ⛔ **لا تعتمد هذه الحزمة `flutter` ولا أي حزمة منصة سحابية** — والقيد
/// **مفروض بالبناء لا بالمراجعة**: الحزمة تُصرَّف بـ`dart` وحده، فأي استيراد
/// من هذا النوع **يفشل التصريف**. وبه صار البند 4 من `coding-standards.md`
/// §5 («استيراد حزمة منصة داخل طبقة النطاق» — رفض تلقائي) **خطأ تصريف**.
library;

export 'capabilities/identity_access/domain/auth_repository.dart';
export 'capabilities/identity_access/domain/auth_session.dart';
export 'capabilities/identity_access/domain/permission.dart';
export 'capabilities/identity_access/domain/permission_grant.dart';
export 'capabilities/identity_access/domain/source_scope.dart';
export 'capabilities/identity_access/domain/source_scope_claim.dart';
export 'capabilities/identity_access/domain/password_change.dart';
export 'capabilities/identity_access/domain/user_administration.dart';
export 'capabilities/financial_outflow/domain/outflow.dart';
export 'capabilities/financial_outflow/domain/outflow_repository.dart';
export 'capabilities/financial_outflow/domain/owner_ledger_summary.dart';
export 'capabilities/financial_outflow/domain/owner_ledger_repository.dart';
export 'capabilities/inventory/domain/counted_intake.dart';
export 'capabilities/inventory/domain/daily_price.dart';
export 'capabilities/inventory/domain/daily_price_repository.dart';
export 'capabilities/inventory/domain/inventory.dart';
export 'capabilities/inventory/domain/inventory_repository.dart';
export 'capabilities/inventory/domain/sack_intake.dart';
export 'capabilities/inventory/domain/sack_intake_repository.dart';
export 'capabilities/inventory/domain/sack_movements.dart';
export 'capabilities/inventory/domain/sack_valuation.dart';
export 'capabilities/inventory/domain/sack_valuation_repository.dart';
export 'capabilities/master_data/domain/master_data.dart';
export 'capabilities/master_data/domain/master_data_repository.dart';
export 'capabilities/oversight/domain/audit_action.dart';
export 'capabilities/oversight/domain/audit_entity_types.dart';
export 'capabilities/oversight/domain/audit_entry.dart';
export 'capabilities/oversight/domain/audit_log_repository.dart';
export 'capabilities/oversight/domain/export_documents.dart';
export 'capabilities/oversight/domain/export_log_repository.dart';
export 'capabilities/oversight/domain/message_templates.dart';
export 'capabilities/oversight/domain/pending_entry.dart';
export 'capabilities/oversight/domain/pending_entry_builder.dart';
export 'capabilities/oversight/domain/report_builders.dart';
export 'capabilities/oversight/domain/report_catalog.dart';
export 'capabilities/oversight/domain/report_repository.dart';
export 'capabilities/oversight/domain/report_table.dart';
export 'capabilities/sales_receivables/domain/cash_sale.dart';
export 'capabilities/sales_receivables/domain/cash_sale_repository.dart';
export 'capabilities/sales_receivables/domain/dealer_statement.dart';
export 'capabilities/sales_receivables/domain/discount.dart';
export 'capabilities/sales_receivables/domain/discount_repository.dart';
export 'capabilities/sales_receivables/domain/distribution.dart';
export 'capabilities/sales_receivables/domain/distribution_repository.dart';
export 'capabilities/sales_receivables/domain/receipt.dart';
export 'capabilities/sales_receivables/domain/receipt_repository.dart';
export 'core/arabic_numerals.dart';
export 'core/calendar_day.dart';
export 'core/counter_key.dart';
export 'core/document_number.dart';
export 'core/errors/app_error.dart';
export 'core/money.dart';
export 'core/outcome.dart';
export 'core/quantity.dart';
export 'core/text_normalization.dart';

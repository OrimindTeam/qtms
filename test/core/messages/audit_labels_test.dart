/// حارس أسماء أفعال سجل التدقيق — ★★ **وقراءةٌ فعلية للمستند**.
///
/// ⚠️⚠️ **ولماذا يقرأ `audit-log-design.md` نفسه لا قائمةً منسوخة:** قائمةٌ
/// منسوخة **تفترق عن مصدرها عند أول تعديل**، ⟵ **فيصير الحارسُ يحرس نسختَه
/// هو**. ★ **وقراءةُ المستند تجعل تعديلَه يُسقِط الاختبار** حين لا يُتبَع
/// بتعديل الكود — وهو نفس منطق `permission_labels_test.dart`.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qtms/capabilities/master_data/presentation/items_screen.dart';
import 'package:qtms/core/messages/audit_labels.dart';
import 'package:qtms_domain/qtms_domain.dart';

/// أفعال §3 كما يعدّدها المستند — **بترتيبه هو**.
List<String> documentedActions() {
  final String design =
      File('docs/04-design/module-design/audit-log-design.md').readAsStringSync();
  // ★ صفُّ `action` في جدول §3 — **وهو الصفّ الوحيد الذي يبدأ بـ`**`action`**`**.
  final RegExp row = RegExp(r'^\|\s*\*\*`action`\*\*\s*\|(.+?)\|\s*$', multiLine: true);
  final RegExpMatch? match = row.firstMatch(design);
  expect(match, isNotNull, reason: '★ صفّ `action` غائب عن §3');

  return match!
      .group(1)!
      // ⟵ **تُنزَع الإشارات والتوكيد والمراجع بين قوسين**، ★ **فيبقى الاسم.**
      .replaceAll(RegExp(r'\([^)]*\)'), '')
      .replaceAll(RegExp(r'[*`★⛔⚠️✅⟵·]'), '·')
      .split('·')
      .map((String part) => part.trim())
      .where((String part) => part.isNotEmpty)
      .toList();
}

void main() {
  group('★★ أفعال سجل التدقيق — نقلٌ حرفي لـaudit-log-design.md §3', () {
    test('★ كل فعلٍ في المستند له اسمٌ مطابق في الكود', () {
      final Set<String> inCode = <String>{
        for (final AuditAction action in AuditAction.values)
          auditActionLabel(action),
      };
      for (final String documented in documentedActions()) {
        expect(
          inCode,
          contains(documented),
          reason: '⛔ «$documented» في §3 بلا اسمٍ مطابق في الكود',
        );
      }
    });

    test('★ والعدد نفسه — ⛔ فلا فعلٌ في الكود بلا سطرٍ في المستند', () {
      expect(
        AuditAction.values.length,
        documentedActions().length,
        reason: '★ القائمة المزدوجة تفترق عند أول إضافة',
      );
    });

    test('⛔ ولا اسمين متطابقين لفعلين — فالسجل يُقرأ لا يُخمَّن', () {
      final Set<String> labels = <String>{
        for (final AuditAction action in AuditAction.values)
          auditActionLabel(action),
      };
      expect(labels.length, AuditAction.values.length);
    });

    test('⛔ ولا اسمٍ لاتيني ولا فارغ — ui-guidelines.md §6', () {
      for (final AuditAction action in AuditAction.values) {
        final String label = auditActionLabel(action);
        expect(label.trim(), isNotEmpty);
        expect(
          RegExp('[A-Za-z]').hasMatch(label),
          isFalse,
          reason: '⛔ «$label» يحمل حروفاً لاتينية',
        );
      }
    });

    test('★★ والفعل المجهول يُسمّى صراحةً — ⛔ ولا يُقرأ فراغاً', () {
      // ⟵ **قيدٌ كتبه إصدارٌ أحدث يبقى مقروءاً** — ★ **واختفاؤه من شاشة
      //   تدقيق أسوأ من عرضه بفعلٍ غير مترجَم.**
      expect(auditActionLabelOrUnknown(null).trim(), isNotEmpty);
      expect(
        auditActionLabelOrUnknown(AuditAction.amend),
        auditActionLabel(AuditAction.amend),
      );
    });
  });

  group('★ أسماء الحقول — من المعجم لا مُخترَعة', () {
    test('★ الحقول المكتوبة فعلاً لها أسماءٌ عربية', () {
      // ⚠️ **قائمةٌ مقصودة لا شاملة:** ★ **هذه حقولٌ يكتبها كُتّابُ اليوم
      //    فعلاً** (`inventory.dart` · `master_data.dart` · `sack_intake.dart`
      //    · `daily_pricing.dart` · `user_admin.dart`) — ⟵ **وأيُّ واحدٍ منها
      //    بلا اسمٍ يظهر للمدقّق بمفتاحه التقني.**
      const List<String> written = <String>[
        'documentNumber',
        'status',
        'stockDate',
        'amendCount',
        'amendReason',
        'cancelReason',
        'name',
        'isActive',
        'sourceIds',
        'unit',
        'quantity',
        'totalQuantity',
        'supplierId',
        'itemName',
        'distributionPrice',
        'minCashPrice',
        'taxPerKilo',
        'claimableWeight',
        'lostWeightConfirmed',
        'roleId',
        'permissionsGranted',
        'disableReason',
        'deleted',
      ];
      for (final String field in written) {
        expect(
          auditFieldLabel(field),
          isNot(field),
          reason: '⛔ الحقل «$field» يُعرَض بمفتاحه التقني',
        );
      }
    });

    test('⛔⛔★★ ولا رمزُ تعدادٍ يُعرَض خاماً — عطلٌ رُصد على المحاكي', () {
      // ⟵ **القيد يُخزِّن `weightBased` و`piece` بأسمائها**، ★ **وكانت
      //   الشاشة تعرضهما حرفياً** ⛔ **وهو مصطلحٌ تقني في الواجهة** (§6).
      for (final String token in <String>[
        'countBased',
        'weightBased',
        'piece',
        'kilogram',
        'incoming',
        'outgoing',
        'countedIntake',
        'sack',
        'approved',
        'cancelled',
      ]) {
        expect(
          auditValueLabel(token),
          isNot(token),
          reason: '⛔ الرمز «$token» يُعرَض خاماً',
        );
      }
    });

    test('★★ وترجمةُ الوحدة والطبيعة هي نفسها المعتمدة في شاشتها', () {
      // ⛔ **ولا صياغة ثانية** — ★ **فالقيمة تُقرأ بالنصّ نفسه أينما ظهرت.**
      expect(auditValueLabel('weightBased'), natureLabel(ItemNature.weightBased));
      expect(auditValueLabel('countBased'), natureLabel(ItemNature.countBased));
      expect(auditValueLabel('piece'), unitLabel(ItemUnit.piece));
      expect(auditValueLabel('kilogram'), unitLabel(ItemUnit.kilogram));
    });

    test('★ والقيمة المجهولة تُعرَض كما هي — بنفس مبدأ أسماء الحقول', () {
      expect(auditValueLabel('someFutureToken'), 'someFutureToken');
    });

    test('★★ والمجهول يُعرَض بمفتاحه — ⛔ ولا يُخفى تغييرٌ وقع فعلاً', () {
      // ⟵ **إخفاءُ حقلٍ تغيّر يُسقِط مبرر `ADR-0004` كلَّه** (`RISK-05`)،
      // ★ **بينما مصطلحٌ تقني ظاهر عيبُ عرضٍ يُصلَح بسطر.**
      expect(auditFieldLabel('someFutureField'), 'someFutureField');
    });
  });
}

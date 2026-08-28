/// ★★ حارس قراءة قيد التدقيق — **ما يعبر بين الكاتب والقارئ**.
///
/// ⚠️⚠️ **ولماذا اختبارٌ مستقل للتحويل:** `DEBT-37` نصّاً — «⛔ **فاختبارُ
/// الطبقة لا يُغني عن اختبار ما يعبر بينها**». ★ **والكاتب هنا
/// `AuditEntry.toFields` في السحابة، والقارئ `cardOf` في التطبيق** —
/// ⟵ **وحرفٌ مختلف بينهما لا يُنتج خطأً بل سجلاً فارغاً أو قيمةً مقلوبة**،
/// ⛔ **وهو أخطر ما يقع للحافظ الوحيد للتاريخ** (`RISK-05`).
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qtms/capabilities/oversight/infrastructure/firestore_audit_log_directory.dart';
import 'package:qtms_domain/qtms_domain.dart';

/// ★★★ **مستندٌ كتبه الكاتب الحقيقي** — ⛔ **لا خريطةٌ مكتوبة يدوياً.**
///
/// ★ **يُبنى بـ`AuditEntry.toFields()` نفسها** التي تستعملها السحابة، ⟵
/// **فأيُّ تغيير في أسماء حقول الكاتب يُسقِط هذا الاختبار** ⛔ **بدل أن
/// يُنتج شاشةً فارغة بهدوء.**
Map<String, dynamic> writtenDoc({
  AuditAction action = AuditAction.amend,
  String? reason = 'تصحيح كمية',
  CalendarDay? stockDate,
  Map<String, Object?> before = const <String, Object?>{},
  Map<String, Object?> after = const <String, Object?>{},
}) {
  final AuditEntry entry = AuditEntry(
    id: 'REQ-9',
    occurredAt: DateTime.utc(2026, 8, 27, 9, 15, 30, 750),
    actor: AuditActor(userId: 'U-001', userName: 'عبدالفتاح'),
    action: action,
    reason: reason,
    target: AuditTarget(
      entityType: countedIntakeEntityType,
      entityId: 'INC-20260827-0001',
      sourceId: 'SRC-001',
      documentNumber: 'INC-20260827-0001',
      stockDate: stockDate,
    ),
    valuesBefore: before,
    valuesAfter: after,
  );
  return <String, dynamic>{
    for (final MapEntry<String, Object?> field in entry.toFields().entries)
      // ⚙️ **والطابع الزمني يعبر كما تُخزّنه المنصّة** — ★ **فالقارئ يُختبَر
      //   على شكلٍ حقيقي** ⛔ **لا على `DateTime` لا يصل منها أبداً.**
      field.key: field.value is DateTime
          ? Timestamp.fromDate(field.value! as DateTime)
          : field.value,
  };
}

void main() {
  group('★★★ رحلةُ الكاتب إلى القارئ — ⛔ ولا حرفَ ينزلق', () {
    test('★ كل حقلٍ يكتبه الكاتب يصل البطاقة بقيمته', () {
      final AuditLogEntryCard card = FirestoreAuditLogDirectory.cardOf(
        'doc-1',
        writtenDoc(
          before: <String, Object?>{'quantity': 100},
          after: <String, Object?>{'quantity': 95},
        ),
      );

      expect(card.id, 'REQ-9');
      expect(card.userId, 'U-001');
      expect(card.userName, 'عبدالفتاح');
      expect(card.action, AuditAction.amend);
      expect(card.entityType, countedIntakeEntityType);
      expect(card.entityId, 'INC-20260827-0001');
      expect(card.documentNumber, 'INC-20260827-0001');
      expect(card.sourceId, 'SRC-001');
      expect(card.reason, 'تصحيح كمية');
      expect(card.valuesBefore['quantity'], 100);
      expect(card.valuesAfter['quantity'], 95);
    });

    test('★★ والوقت يُقرأ بدقة الثانية كما كُتب — ⛔ بلا كسور', () {
      final AuditLogEntryCard card =
          FirestoreAuditLogDirectory.cardOf('doc-1', writtenDoc());
      expect(card.occurredAt, DateTime.utc(2026, 8, 27, 9, 15, 30));
      expect(card.occurredAt.isUtc, isTrue);
    });

    test('★★★ وتاريخ المخزون يعبر نصّاً ويعود يوماً — RISK-07', () {
      final AuditLogEntryCard card = FirestoreAuditLogDirectory.cardOf(
        'doc-1',
        writtenDoc(stockDate: CalendarDay(2026, 8, 26)),
      );
      expect(card.stockDate, CalendarDay(2026, 8, 26));
      expect(
        card.occurredAt.day,
        27,
        reason: '⛔ ولا يُخلَط يومُ المخزون بوقت الحدث',
      );
    });

    test('★ وكلُّ فعلٍ في المعجم يُقرأ قيمتَه هو — ⛔ ولا واحد ينزلق', () {
      for (final AuditAction action in AuditAction.values) {
        final AuditLogEntryCard card = FirestoreAuditLogDirectory.cardOf(
          'doc-${action.name}',
          writtenDoc(action: action),
        );
        expect(card.action, action, reason: '★ الفعل ${action.name}');
      }
    });
  });

  group('⛔ قراءةٌ لا تُسقِط الشاشة — قيدٌ ناقصٌ أو من إصدارٍ آخر', () {
    test('★★ فعلٌ لا يعرفه هذا الإصدار يُقرأ null ويبقى القيد مقروءاً', () {
      final Map<String, dynamic> doc = writtenDoc()
        ..['action'] = 'someFutureAction';
      final AuditLogEntryCard card =
          FirestoreAuditLogDirectory.cardOf('doc-1', doc);
      expect(card.action, isNull);
      expect(card.userName, 'عبدالفتاح', reason: '★ وبقيةُ القيد سليمة');
    });

    test('⛔ ولا يُقرأ «إنشاءً» احتياطاً — فذلك يكذب على المدقّق', () {
      final Map<String, dynamic> doc = writtenDoc()..remove('action');
      expect(FirestoreAuditLogDirectory.cardOf('doc-1', doc).action, isNull);
    });

    test('★ ومستندٌ خالٍ تماماً يُقرأ بلا رمي', () {
      final AuditLogEntryCard card =
          FirestoreAuditLogDirectory.cardOf('doc-1', <String, dynamic>{});
      expect(card.id, 'doc-1', reason: '★ ومعرّف المستند بديلٌ للحقل الغائب');
      expect(card.occurredAt, DateTime.utc(1970));
      expect(card.sourceId, auditAllSourcesId);
      expect(card.valuesBefore, isEmpty);
    });

    test('⛔ وتاريخ مخزونٍ مشوَّه غيابٌ لا انهيار', () {
      final Map<String, dynamic> doc = writtenDoc()..['stockDate'] = '2026-08';
      expect(FirestoreAuditLogDirectory.cardOf('doc-1', doc).stockDate, isNull);
    });

    test('⛔ وخريطةُ قيمٍ مشوَّهة تُقرأ فراغاً لا تُسقِط القيد', () {
      final Map<String, dynamic> doc = writtenDoc()..['valuesAfter'] = 'نصّ';
      expect(FirestoreAuditLogDirectory.cardOf('doc-1', doc).valuesAfter, isEmpty);
    });
  });

  group('★★ الطوابع تُنزَع من نوع المنصّة — وإلا امتلأ السجل بتغييرٍ وهمي', () {
    test('★ طابعان متساويان يُقرآن قيمةً واحدة فلا يُعَدّان تغييراً', () {
      final Map<String, dynamic> doc = writtenDoc()
        ..['valuesBefore'] = <String, Object?>{
          'date': Timestamp.fromDate(DateTime.utc(2026, 8, 26)),
        }
        ..['valuesAfter'] = <String, Object?>{
          'date': Timestamp.fromDate(DateTime.utc(2026, 8, 26)),
        };
      final AuditLogEntryCard card =
          FirestoreAuditLogDirectory.cardOf('doc-1', doc);

      expect(card.valuesBefore['date'], isA<DateTime>());
      expect(
        describeAuditChanges(card),
        isEmpty,
        reason: '⛔ فرقُ مرجعٍ ليس تغييراً',
      );
    });

    test('★ ويُنزَع من داخل القوائم والخرائط المتداخلة كذلك', () {
      final Map<String, dynamic> doc = writtenDoc()
        ..['valuesAfter'] = <String, Object?>{
          'lines': <Object?>[
            <String, Object?>{
              'stockDate': Timestamp.fromDate(DateTime.utc(2026, 8, 26)),
            },
          ],
        };
      final AuditLogEntryCard card =
          FirestoreAuditLogDirectory.cardOf('doc-1', doc);
      final Object? line = (card.valuesAfter['lines']! as List<Object?>).single;
      expect((line! as Map<String, Object?>)['stockDate'], isA<DateTime>());
    });
  });
}

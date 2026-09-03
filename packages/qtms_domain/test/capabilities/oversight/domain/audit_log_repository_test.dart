/// حارس عقد قراءة سجل التدقيق (`WU-008`) — `FR-M18-09` … `FR-M18-14`.
///
/// ⚠️⚠️ **وأهمُّ ما يحرسه ليس دالةً بل غيابَ دالة:** `FR-M18-01` يمنع التعديل
/// والحذف **لأي مستخدم بمن فيهم المالك** — ★ **وأول اختبارٍ هنا يُثبت أن
/// العقد نفسه لا يحمل مساراً لهما**، ⟵ **فالمنع بنيويٌّ لا شرطٌ يُنسى.**
library;

import 'dart:io';

import 'package:qtms_domain/qtms_domain.dart';
import 'package:test/test.dart';

/// بطاقة قيدٍ صالحة بأقل ما يلزم — تُعدَّل في كل اختبار حسب حاجته.
AuditLogEntryCard buildCard({
  AuditAction? action = AuditAction.amend,
  Map<String, Object?> before = const <String, Object?>{},
  Map<String, Object?> after = const <String, Object?>{},
  CalendarDay? stockDate,
  String? reason = 'تصحيح كمية',
}) =>
    AuditLogEntryCard(
      id: 'REQ-1',
      occurredAt: DateTime.utc(2026, 8, 27, 9, 15),
      userId: 'uid-actor',
      userName: 'عبدالفتاح',
      action: action,
      entityType: 'countedIntake',
      entityId: 'INC-20260827-0001',
      sourceId: 'SRC-001',
      valuesBefore: before,
      valuesAfter: after,
      stockDate: stockDate,
      reason: reason,
    );

void main() {
  group('⛔ العقد بلا كاتب — FR-M18-01 · FR-M18-04', () {
    test('★★ لا دالة كتابة ولا تعديل ولا حذف في AuditLogDirectory', () {
      // ⚠️ **ولا انعكاس في Dart بلا `dart:mirrors`** (وهو ممنوع في هذه
      //    الحزمة) — ★ **فالحارس على النصّ المصدري نفسه**، وهو المعيار
      //    الذي تعتمده بوابات المشروع الأخرى (`design_gates_test.dart`).
      final String source = _directorySource();

      // ① ★ **عضوان اثنان لا ثالث** — ⟵ **فدالةٌ تُضاف غداً تُسقِط الاختبار.**
      final List<String> members = <String>[
        for (final RegExpMatch match
            in RegExp(r'^  \w[^;{\n]*?\b(\w+)\(', multiLine: true)
                .allMatches(source))
          match.group(1)!,
      ];
      expect(
        members,
        <String>['watchCentralLog', 'watchEntityLog'],
        reason: '★ العقد قراءةٌ محضة — ⛔ ولا عضوَ ثالث',
      );

      // ② ⛔ **ولا فعلَ كتابةٍ في أي اسمٍ داخل العقد** — ★ **حارسٌ ثانٍ
      //    مستقل بمعناه لا بعدده**: ⟵ **فاسمٌ يمرّ من ① يسقط هنا.**
      for (final String verb in <String>[
        'create',
        'write',
        'update',
        'amend',
        'delete',
        'remove',
        'save',
      ]) {
        expect(
          _declarations(source),
          isNot(contains(verb)),
          reason: '⛔ فعلُ كتابةٍ في عقدٍ للقراءة وحدها',
        );
      }
    });
  });

  group('★★ describeAuditChanges — الصيغة الموحّدة (audit-log-design §5)', () {
    test('يجمع مفاتيح الخريطتين اتحاداً لا تقاطعاً', () {
      final List<AuditFieldChange> rows = describeAuditChanges(
        buildCard(
          before: <String, Object?>{'quantity': 100},
          after: <String, Object?>{'quantity': 95, 'notes': 'تصحيح'},
        ),
      );
      expect(
        rows.map((AuditFieldChange row) => row.field).toList(),
        <String>['notes', 'quantity'],
        reason: '★ حقلٌ في إحدى الخريطتين وحدها لا يسقط',
      );
    });

    test('★ الترتيب أبجديٌّ ثابت — فلا يقفز صفٌّ بين فتحةٍ وأخرى', () {
      final List<AuditFieldChange> rows = describeAuditChanges(
        buildCard(after: <String, Object?>{'zeta': 1, 'alpha': 2, 'mid': 3}),
      );
      expect(
        rows.map((AuditFieldChange row) => row.field).toList(),
        <String>['alpha', 'mid', 'zeta'],
      );
    });

    test('⛔ والمتساوي لا يُعرَض — القيمة التي لم تتغيّر ليست تغييراً', () {
      final List<AuditFieldChange> rows = describeAuditChanges(
        buildCard(
          before: <String, Object?>{'quantity': 100, 'unit': 'piece'},
          after: <String, Object?>{'quantity': 100, 'unit': 'kilogram'},
        ),
      );
      expect(rows.length, 1);
      expect(rows.single.field, 'unit');
    });

    test('★ والعدد الصحيح يساوي نظيره العشري — القاعدة تُرجِع 1 و1.0 معاً', () {
      final List<AuditFieldChange> rows = describeAuditChanges(
        buildCard(
          before: <String, Object?>{'amount': 1200},
          after: <String, Object?>{'amount': 1200.0},
        ),
      );
      expect(rows, isEmpty, reason: '⛔ فرقُ تمثيلٍ ليس تغييراً');
    });

    test(
      '⛔⛔★★★ والإنشاءُ بلا صفٍّ واحد — AM-012 §3.1 (2026-09-02)',
      () {
        // ★★★ **وكان يعرض «بعد» وحدها بـ«قبل» فارغة** — ⟵ **أي «لا قيمة ⟵ س»
        //    لكل حقل**: ⛔ **وهو تكرارُ محتوى المستند بصيغةِ تغييرٍ لم يقع.**
        final List<AuditFieldChange> rows = describeAuditChanges(
          buildCard(
            action: AuditAction.create,
            after: <String, Object?>{
              'documentNumber': 'INC-20260827-0001',
              'quantity': 60,
            },
          ),
        );
        expect(rows, isEmpty);
      },
    );

    test(
      '⛔⛔★★ و`valuesAfter` تبقى مخزَّنةً كما هي — إسقاطُ عرضٍ لا تخزين',
      () {
        // ★★ **فالتحقيقُ يقرأ لقطةَ الإنشاء كاملةً من القاعدة** — ⟵ **والشاشةُ
        //    وحدَها هي ما تغيّر** (`AM-012` §3.1).
        final AuditLogEntryCard card = buildCard(
          action: AuditAction.create,
          after: <String, Object?>{'documentNumber': 'INC-20260827-0001'},
        );
        expect(card.valuesAfter, <String, Object?>{
          'documentNumber': 'INC-20260827-0001',
        });
      },
    );

    test(
      '★★ وبقيةُ الأفعال بلا مساس — التعديلُ يعرض ما تغيّر فعلاً وحدَه',
      () {
        // ⛔⛔ **والحدُّ على الفعل `create` وحدَه** — ★ **ولا يُقاس عليه غيرُه:**
        //    ⟵ **`AM-012` §3.2 يفرض عرضَ الحقول المتغيّرة في «بقية الأحداث».**
        final List<AuditFieldChange> rows = describeAuditChanges(
          buildCard(
            action: AuditAction.amend,
            before: <String, Object?>{'quantity': 60, 'note': 'ثابت'},
            after: <String, Object?>{'quantity': 80, 'note': 'ثابت'},
          ),
        );
        expect(rows.single.field, 'quantity');
        expect(rows.single.before, 60);
        expect(rows.single.after, 80);
      },
    );

    test('★★ وحذفُ قالب الدور يعرض «قبل» كاملةً — IQ-018', () {
      final List<AuditFieldChange> rows = describeAuditChanges(
        buildCard(
          action: AuditAction.delete,
          before: <String, Object?>{
            'name': 'محاسب',
            'permissions': <String>['x'],
          },
          after: <String, Object?>{'deleted': true},
        ),
      );
      expect(
        rows.map((AuditFieldChange row) => row.field).toList(),
        <String>['deleted', 'name', 'permissions'],
        reason: '★ فالسجل يحفظ ما ضاع',
      );
    });

    test('⛔ والقوائم والخرائط تُقارَن عنصراً بعنصر لا بالمرجع', () {
      expect(sameAuditValue(<Object?>[1, 'أ'], <Object?>[1, 'أ']), isTrue);
      expect(
        sameAuditValue(<String, Object?>{'a': 1}, <String, Object?>{'a': 2}),
        isFalse,
      );
    });

    test('★ والنتيجة غير قابلة للتعديل — فلا تُغيَّر من الشاشة', () {
      final List<AuditFieldChange> rows = describeAuditChanges(
        buildCard(after: <String, Object?>{'a': 1}),
      );
      expect(
        () => rows.add(
          const AuditFieldChange(field: 'x', before: null, after: null),
        ),
        throwsUnsupportedError,
      );
    });
  });

  group('★★ AuditLogFilter — المصدر إلزامي وبُعدٌ ثانويٌّ واحد', () {
    test('⛔⛔★★★ ولا فلترَ بلا مصدر — واستعلامُه يُرفَض كاملاً من القاعدة', () {
      // ★★ **مقيسٌ على المحاكي (2026-08-27):** `getDocs` بلا قيدٍ على
      //    `sourceId` **يُرفَض ولو بنطاقٍ شامل** — ⟵ **فالنوع يمنع بناءه.**
      expect(() => AuditLogFilter(sourceId: ''), throwsArgumentError);
      expect(() => AuditLogFilter(sourceId: '   '), throwsArgumentError);
    });

    test('★ والمصدر وحده هو «كل نشاط هذا المصدر»', () {
      expect(AuditLogFilter(sourceId: 'SRC-001').isSourceOnly, isTrue);
    });

    test('⛔ بُعدٌ ثانويٌّ بلا قيمته يُرفَض — لأن استعلامه فراغٌ صامت', () {
      expect(
        () => AuditLogFilter(
          sourceId: 'SRC-001',
          dimension: AuditFilterDimension.user,
        ),
        throwsArgumentError,
      );
      expect(
        () => AuditLogFilter(
          sourceId: 'SRC-001',
          dimension: AuditFilterDimension.action,
        ),
        throwsArgumentError,
      );
    });

    test('⛔ ومدىً مقلوب يُرفَض — فلا يبدو «لا أحداث» وسؤالُه مستحيل', () {
      expect(
        () => AuditLogFilter(
          sourceId: 'SRC-001',
          from: CalendarDay(2026, 8, 27),
          to: CalendarDay(2026, 8, 20),
        ),
        throwsArgumentError,
      );
    });

    test('★ والمدى وحده يُخرِجه من «المصدر وحده» — فالتاريخ قيدٌ فعلي', () {
      final AuditLogFilter filter = AuditLogFilter(
        sourceId: 'SRC-001',
        from: CalendarDay(2026, 8, 20),
      );
      expect(filter.isSourceOnly, isFalse);
      expect(filter.dimension, AuditFilterDimension.none);
    });

    test('★ والتساوي بالقيمة — فالمزوّد لا يُعيد الاستعلام بلا تغيّر', () {
      expect(
        AuditLogFilter(
          sourceId: 'SRC-001',
          dimension: AuditFilterDimension.action,
          action: AuditAction.amend,
        ),
        AuditLogFilter(
          sourceId: 'SRC-001',
          dimension: AuditFilterDimension.action,
          action: AuditAction.amend,
        ),
      );
    });

    test('⛔ ومصدرٌ آخر فلترٌ آخر — فلا يُعاد استعمال نتيجةٍ لمصدر غيره', () {
      expect(
        AuditLogFilter(sourceId: 'SRC-001'),
        isNot(AuditLogFilter(sourceId: 'SRC-002')),
      );
    });

    test('★ والقيم تُشذَّب — فمسافةٌ زائدة لا تُنتج فلتراً ثانياً', () {
      expect(AuditLogFilter(sourceId: ' SRC-001 ').sourceId, 'SRC-001');
    });
  });

  group('★ AuditEntityRef — مفتاح السجل السياقي', () {
    test('⛔ الكيان المجهول يُرفَض — والسجل بلا هدف لا يُفتَح', () {
      expect(
        () => AuditEntityRef(entityType: '', entityId: 'X'),
        throwsArgumentError,
      );
      expect(
        () => AuditEntityRef(entityType: 'sack', entityId: '  '),
        throwsArgumentError,
      );
    });

    test('★ والنوع جزءٌ من المفتاح — فلا يتصادم معرّفان من مجموعتين', () {
      expect(
        AuditEntityRef(entityType: 'sack', entityId: 'X'),
        isNot(AuditEntityRef(entityType: 'user', entityId: 'X')),
      );
    });

    test('★★ والمصدر جزءٌ منه — فاستعلامٌ بلا قيدٍ عليه يُرفَض كاملاً', () {
      expect(
        AuditEntityRef(
          entityType: 'source',
          entityId: 'SRC-001',
          sourceId: 'SRC-001',
        ),
        isNot(AuditEntityRef(entityType: 'source', entityId: 'SRC-001')),
      );
    });

    test('★ وافتراضُه «ما لا يخصّ مصدراً» — وهو ما يكتبه كاتبُ المستخدم والدور', () {
      expect(
        AuditEntityRef(entityType: 'user', entityId: 'U-1').sourceId,
        auditAllSourcesId,
      );
    });

    test('⛔ ومصدرٌ فارغ يُرفَض صراحةً', () {
      expect(
        () => AuditEntityRef(
          entityType: 'user',
          entityId: 'U-1',
          sourceId: '  ',
        ),
        throwsArgumentError,
      );
    });
  });

  group('★ AuditLogEntryCard — قراءةٌ متسامحة لقيدٍ كُتب فعلاً', () {
    test('★★ فعلٌ غير معروف يُقرأ null ولا يُسقِط الشاشة', () {
      // ⟵ **قيدٌ كتبه إصدارٌ أحدث بفعلٍ جديد يبقى مقروءاً** — ★ **واختفاؤه
      //   من شاشة تدقيق أسوأ من عرضه بفعلٍ غير مترجَم.**
      expect(buildCard(action: null).action, isNull);
    });

    test('⛔ والخريطتان غير قابلتين للتعديل بعد البناء', () {
      final AuditLogEntryCard card = buildCard(after: <String, Object?>{'a': 1});
      expect(() => card.valuesAfter['b'] = 2, throwsUnsupportedError);
    });

    test('★ وتاريخ المخزون يبقى يوماً تقويمياً لا لحظة — RISK-07', () {
      final AuditLogEntryCard card =
          buildCard(stockDate: CalendarDay(2026, 8, 26));
      expect(card.stockDate!.format(), '20260826');
      expect(card.occurredAt.day, 27, reason: '★ وقتُ الحدث غيرُ يوم المخزون');
    });
  });
}

/// النصّ المصدري للعقد — ★ **مقروءاً من القسم الذي يعرّف الدليل وحده.**
String _directorySource() {
  const String path =
      'lib/capabilities/oversight/domain/audit_log_repository.dart';
  final String all = File(path).readAsStringSync().replaceAll('\r\n', '\n');
  final int start = all.indexOf('abstract interface class AuditLogDirectory');
  expect(start, isNot(-1), reason: '★ الدليل غائب عن الملف');
  return all.substring(start);
}

/// ★ سطور التصريح وحدها — ⛔ **بلا التعليقات**: ⟵ **فشرحُ المنع لا يُحسَب
/// مخالفةً له**، وهو نفس مبدأ `design_gates_test.dart`.
String _declarations(String source) => source
    .split('\n')
    .where((String line) => !line.trimLeft().startsWith('//'))
    .join('\n')
    .toLowerCase();

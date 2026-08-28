import 'package:qtms_domain/qtms_domain.dart';
import 'package:test/test.dart';

/// قيد صالح بأقل ما يلزم — يُبنى مرة ويُعدَّل عند الحاجة في كل اختبار.
AuditEntry buildEntry({
  AuditAction action = AuditAction.create,
  String? reason,
  AuditTarget? target,
  DateTime? occurredAt,
}) =>
    AuditEntry(
      id: 'AUD-1',
      occurredAt: occurredAt ?? DateTime.utc(2026, 8, 22, 10, 30, 15, 750),
      actor: AuditActor(userId: 'uid-actor', userName: 'عبدالفتاح'),
      action: action,
      target: target ??
          AuditTarget(entityType: 'user', entityId: 'uid-target'),
      reason: reason,
    );

void main() {
  group('AuditEntry — الشروط الأربعة في audit-log-design.md §2', () {
    test('الحقول تُكتب بأسماء data-dictionary.md §5 حرفياً', () {
      final Map<String, Object?> fields = buildEntry().toFields();
      expect(
        fields.keys.toSet(),
        <String>{
          'id',
          'occurredAt',
          'userId',
          'userName',
          'action',
          'entityType',
          'entityId',
          'documentNumber',
          'sourceId',
          'stockDate',
          'valuesBefore',
          'valuesAfter',
          'reason',
          'deviceInfo',
        },
        reason: 'انزلاق اسم حقل يكسر فهارس §7 بصمت',
      );
    });

    test('★ الوقت يُقتطَع لدقة الثانية — لا كسور', () {
      final Object? occurredAt = buildEntry().toFields()['occurredAt'];
      expect(occurredAt, DateTime.utc(2026, 8, 22, 10, 30, 15));
      expect((occurredAt! as DateTime).millisecond, 0);
    });

    test('⛔ ويُرفَض وقت غير UTC — فلا تنزلق منطقة الحاوية إلى الدفتر', () {
      expect(
        () => buildEntry(occurredAt: DateTime(2026, 8, 22, 10, 30)),
        throwsArgumentError,
      );
    });

    test('★ والمُنفِّذ إلزامي — ⛔ لا قيد مجهول', () {
      expect(
        () => AuditActor(userId: '', userName: 'مجهول'),
        throwsArgumentError,
      );
    });

    test('اسم المُنفِّذ منسوخ في القيد لا مرجعاً إليه', () {
      expect(buildEntry().toFields()['userName'], 'عبدالفتاح');
    });
  });

  group('★★★ ADR-0020 — السبب اختياريٌّ في كل الأفعال بلا استثناء', () {
    // ⛔⛔★★★ **ارتدادُ `ADR-0020` (2026-08-27):** ★ **كانت هذه الأفعال
    //   الأربعة ترمي `ArgumentError` بلا سبب** (`amend` · `cancel` ·
    //   `disposal` · `delete`) — ⟵ **وقد حُذف الحارس ومعه `requiresReason`
    //   وعَلَمُ `isDeferredEntry`.**
    for (final AuditAction action in AuditAction.values) {
      test('✅ ${action.name} بلا سبب يُقبَل — ولا استثناء لفعل', () {
        expect(buildEntry(action: action).toFields()['reason'], isNull);
        // ★★ **والفراغات تُقرأ غياباً لا نصّاً** — ⛔ **فلا حقلٌ يبدو
        //   مملوءاً وهو خالٍ.**
        expect(
          buildEntry(action: action, reason: '   ').toFields()['reason'],
          isNull,
        );
      });
    }

    test('★★ وسببٌ كتبه إنسانٌ يُحفَظ مقصوصاً — ADR-0020 القيد 3', () {
      expect(
        buildEntry(
          action: AuditAction.amend,
          reason: '  تصحيح عدد الحبات  ',
        ).toFields()['reason'],
        'تصحيح عدد الحبات',
      );
    });

    test('السبب يُقلَّم قبل الكتابة فلا يُخزَّن بفراغات طرفية', () {
      final AuditEntry entry =
          buildEntry(action: AuditAction.amend, reason: '  تصحيح إدخال  ');
      expect(entry.toFields()['reason'], 'تصحيح إدخال');
    });
  });

  group('AuditTarget — النطاق وتاريخ المخزون', () {
    test('★ sourceId الافتراضي `all` — وإلا لم يقرأ القيدَ أحد', () {
      // قاعدة قراءة audit_log تشترط storedInScope()، وهي تفشل على مستند
      // بلا الحقل أصلاً — فالغياب يعني قيداً غير مقروء لا قيداً مفتوحاً.
      expect(buildEntry().toFields()['sourceId'], 'all');
      expect(auditAllSourcesId, 'all');
    });

    test('ويُذكَر المصدر صراحةً حين يخصّ القيد مصدراً', () {
      final AuditEntry entry = buildEntry(
        target: AuditTarget(
          entityType: 'distribution',
          entityId: 'DST-1',
          sourceId: 'SRC-001',
          documentNumber: 'DST-20260822-0001',
        ),
      );
      expect(entry.toFields()['sourceId'], 'SRC-001');
      expect(entry.toFields()['documentNumber'], 'DST-20260822-0001');
    });

    test('★ تاريخ المخزون يُكتب بصيغة اليوم لا بوقت — RISK-07', () {
      final AuditEntry entry = buildEntry(
        target: AuditTarget(
          entityType: 'distribution',
          entityId: 'DST-1',
          stockDate: CalendarDay(2026, 8, 21),
        ),
      );
      expect(entry.toFields()['stockDate'], '20260821');
    });

    test('⛔ ويُرفَض هدف بلا نوع أو بلا معرّف', () {
      expect(
        () => AuditTarget(entityType: '', entityId: 'x'),
        throwsArgumentError,
      );
      expect(
        () => AuditTarget(entityType: 'user', entityId: ''),
        throwsArgumentError,
      );
    });
  });

  group('عدم القابلية للتغيير — الشرط 1 في §2', () {
    test('⛔ خرائط القيم لا تُعدَّل بعد الإنشاء', () {
      final AuditEntry entry = buildEntry(
        target: AuditTarget(entityType: 'user', entityId: 'uid-target'),
      );
      expect(
        () => entry.valuesAfter['injected'] = true,
        throwsUnsupportedError,
      );
    });

    test('★ ولا قيد بلا معرّف', () {
      expect(
        () => AuditEntry(
          id: '',
          occurredAt: DateTime.utc(2026, 8, 22),
          actor: AuditActor(userId: 'u', userName: 'n'),
          action: AuditAction.create,
          target: AuditTarget(entityType: 'user', entityId: 'x'),
        ),
        throwsArgumentError,
      );
    });
  });

  group('AuditAction — نقل حرفي لـ§3 ولا زيادة صامتة', () {
    test('الإجراءات الاثنا عشر المذكورة في المستند', () {
      // ★★ **أحد عشر من `audit-log-design.md` §3 الأصلي، والثاني عشر
      //    `delete` أُضيف بحسم `IQ-018` (2026-08-24) بسطره في المستند
      //    نفسه** — ⛔ **ولا زيادة صامتة**: القائمة المزدوجة تفترق عند أول
      //    إضافة بلا سطر مقابل، وهذا الاختبار هو ما يمنعها.
      expect(AuditAction.values.length, 12);
      expect(
        AuditAction.values.map((AuditAction a) => a.name).toSet(),
        <String>{
          'create',
          'amend',
          'cancel',
          'disable',
          'signIn',
          'export',
          'depositConfirm',
          'lostWeightConfirm',
          'disposal',
          'agedRemainderClear',
          'permissionChange',
          'delete',
        },
      );
    });

    // ⛔⛔★★★ **كان `IQ-018` يشترط سبباً على الحذف** — ★ **وسقط بـ`ADR-0020`
    //   بعد أن عُرِضت حجّتُه («المحذوف لا يبقى ليُراجَع») على المالك نصّاً.**
    //   ⟵ ✅★★ **والفعل `delete` نفسُه باقٍ في المعجم** — **وهو ما يُحرَس هنا.**
    test('★★ IQ-018: الفعل delete باقٍ في المعجم — وسببُه اختياري', () {
      expect(
        buildEntry(action: AuditAction.delete).toFields()['action'],
        'delete',
      );
      expect(buildEntry(action: AuditAction.delete).toFields()['reason'], isNull);
    });

    test('اسم القيمة هو ما يُكتب في الحقل — فلا جدول تحويل', () {
      expect(
        buildEntry(action: AuditAction.permissionChange).toFields()['action'],
        'permissionChange',
      );
    });
  });
}

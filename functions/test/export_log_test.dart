/// تسجيل التصدير — ★★ **حارس التفويض والنطاق ونوع الكيان** (`WU-010`).
///
/// ⚠️⚠️ **ولماذا يُختبَر بهذه الصرامة:** `audit_log` **`allow create, update,
/// delete: if false`** لكل مستخدم بلا استثناء — ⟵ **فلم يبقَ بين المستخدم
/// وقيدِ التصدير إلا هذا الكود**، ★ **ولا قاعدةَ حماية واحدة تحرس هذا
/// المسار** (الكتالوج §2.8 · `ADR-0013` القاعدة 3).
///
/// ⛔⛔★★★ **وهي أولُ عمليةٍ تكتب قيداً بلا مستند** — ★ **فالاختبار يحرس
/// العَلَم نفسَه** (`auditOnly`) ⛔ **لا الأثرَ وحده.**
library;

import 'package:qtms_domain/qtms_domain.dart';
import 'package:qtms_functions/src/audited_transaction.dart';
import 'package:qtms_functions/src/callable.dart';
import 'package:qtms_functions/src/export_log.dart';
import 'package:qtms_functions/src/identity_claims.dart';
import 'package:qtms_functions/src/identity_gateway.dart';
import 'package:test/test.dart';

const String actorUid = 'uid-exporter';
const String sourceA = 'SRC-001';
const String sourceB = 'SRC-002';
const String requestId = 'req-export-1';

final DateTime platformNow = DateTime.utc(2026, 8, 30, 9, 15, 42);

AccountRecord account({
  Set<Permission> permissions = const <Permission>{Permission.documentExport},
  SourceScope scope = const AllSources(),
  bool disabled = false,
}) =>
    AccountRecord(
      userId: actorUid,
      userName: 'المُصدِّر',
      claims: IdentityClaims(permissions: permissions, sourceScope: scope),
      disabled: disabled,
      cardIsActive: true,
    );

ExportLogRequest request({
  AccountRecord? actor,
  String id = requestId,
  String sourceId = sourceA,
  String entityType = receiptEntityType,
  String entityId = 'RCP-20260830-0007',
  String? documentNumber = 'RCP-20260830-0007',
  CalendarDay? stockDate,
  String? deviceInfo,
}) =>
    ExportLogRequest(
      actor: actor ?? account(),
      requestId: id,
      sourceId: sourceId,
      entityType: entityType,
      entityId: entityId,
      format: ExportFormat.pdf,
      occurredAt: platformNow,
      documentNumber: documentNumber,
      stockDate: stockDate,
      deviceInfo: deviceInfo,
    );

ExportLogPlan plan(ExportLogRequest input) =>
    planExportLog(input, ExportLogOperation.logExport);

AuditEntry acceptedEntry(ExportLogRequest input) =>
    (plan(input) as ExportLogAccepted).entry;

CallableError rejection(ExportLogRequest input) =>
    (plan(input) as ExportLogRejected).error;

void main() {
  group('⛔★★ البوابة — الصلاحية وحدها لا تكفي ولا يُغني عنها شيء', () {
    test('✅ من يملك `documentExport` ونطاق المصدر يُقبَل', () {
      expect(plan(request()), isA<ExportLogAccepted>());
    });

    test('⛔ ومن لا يملكها يُرفَض بـ`ERR_AUTH_001` — ولو كان نطاقه الكل', () {
      expect(
        rejection(request(actor: account(permissions: const <Permission>{}))),
        CallableError.permissionMissing,
      );
    });

    test('⛔⛔ و`messagingSend` لا تُغني عن `documentExport`', () {
      // ★ **وصفُ `messagingSend` في الكتالوج «الإرسال» لا التصدير** —
      //   ⟵ **وهما فعلان مختلفان**: الأول لا أثر له، والثاني يكتب قيداً.
      expect(
        rejection(
          request(
            actor: account(
              permissions: const <Permission>{Permission.messagingSend},
            ),
          ),
        ),
        CallableError.permissionMissing,
      );
    });

    test('⛔★★ والنطاق قيدٌ يعلو على الصلاحية — `GR-23` · `FR-M19-02`', () {
      expect(
        rejection(
          request(
            actor: account(scope: ScopedSources(<String>{sourceB})),
          ),
        ),
        CallableError.sourceOutOfScope,
      );
    });

    test('⛔★★ وتقريرُ «كل المصادر» يضيق على صاحب النطاق الجزئي', () {
      // ★ `canAccessSource('all')` لا تصدُق إلا لمن نطاقه `all` — ⟵ **فالقيد
      //   يضيق ولا يتّسع**، ⛔ **ولا يُسرَّب مصدرٌ خارج النطاق في تقرير.**
      expect(
        rejection(
          request(
            actor: account(scope: ScopedSources(<String>{sourceA})),
            sourceId: auditAllSourcesId,
            entityType: distributionEntityType,
            entityId: 'DEALER_SRC-001_20260830',
            documentNumber: null,
          ),
        ),
        CallableError.sourceOutOfScope,
      );
      expect(
        plan(
          request(
            sourceId: auditAllSourcesId,
            entityType: distributionEntityType,
            entityId: 'DEALER_SRC-001_20260830',
            documentNumber: null,
          ),
        ),
        isA<ExportLogAccepted>(),
      );
    });

    test('⛔ والحساب المعطَّل يُرفَض فوراً — «التعطيل فوري ونافذ»', () {
      expect(
        rejection(request(actor: account(disabled: true))),
        CallableError.accountDisabled,
      );
    });

    test('⛔ ومعرّف الطلب الفارغ يُرفَض — فلا لاتكرارية بلاه', () {
      expect(rejection(request(id: '   ')), CallableError.invalidArgument);
    });
  });

  group('⛔★★ نوع الكيان — من القائمة المعتمدة حصراً', () {
    test('⛔ ونصٌّ حرٌّ يُرفَض — ولو كان مفهوماً للإنسان', () {
      // ⚠️ **الأثر لو قُبل صامتاً:** السجل السياقي 🕘 يستعلم بـ`entityType`
      //    (`FR-M18-10`) — ⟵ **فقيمةٌ لا يعرفها القارئ تُنتج سجلاً فارغاً
      //    أبداً يبدو «لا تاريخ لهذا المستند»**، ★ **وهو أسوأ عطلٍ ممكن.**
      expect(
        rejection(request(entityType: 'sanad')),
        CallableError.invalidArgument,
      );
      // ⚠️★★ **وكان المثال هنا `'report'` حتى `WU-010`** — ★ **وصار نوعاً
      //    معتمَداً في `WU-011`** (`reportEntityType`): ⟵ **فاستُبدل بنصٍّ
      //    لا كاتبَ له**، ⛔ **ولم يُحذف الفحص** — ★ **والدرسُ أن مثالَ
      //    «النصّ الحر» يجب أن يبقى خارج القائمة فعلاً لا بالذاكرة.**
      expect(
        rejection(request(entityType: 'taqreer')),
        CallableError.invalidArgument,
      );
      expect(
        rejection(request(entityType: '')),
        CallableError.invalidArgument,
      );
    });

    test('✅ وكل نوعٍ في القائمة المعتمدة يُقبَل', () {
      for (final String entityType in auditEntityTypes) {
        expect(
          plan(request(entityType: entityType, entityId: 'X-1')),
          isA<ExportLogAccepted>(),
          reason: entityType,
        );
      }
    });

    test('⛔ ومعرّف كيانٍ فارغ يُرفَض — ولا قيدَ بلا هدف', () {
      expect(
        rejection(request(entityId: '   ')),
        CallableError.invalidArgument,
      );
    });
  });

  group('★★ القيد المكتوب — `FR-M19-04` · `audit-log-design.md` §3', () {
    test('★ الفعل «تصدير» لا غيرُه', () {
      expect(acceptedEntry(request()).action, AuditAction.export);
    });

    test('★ والهدف يحمل نوع الكيان ومعرّفه ومصدره ورقمه', () {
      final AuditEntry entry = acceptedEntry(
        request(stockDate: CalendarDay(2026, 8, 29)),
      );
      expect(entry.target.entityType, receiptEntityType);
      expect(entry.target.entityId, 'RCP-20260830-0007');
      expect(entry.target.sourceId, sourceA);
      expect(entry.target.documentNumber, 'RCP-20260830-0007');
      expect(entry.target.stockDate, CalendarDay(2026, 8, 29));
    });

    test('★ واسم المُنفِّذ منسوخ لا مرجع — الشرط 4 في §2', () {
      final AuditEntry entry = acceptedEntry(request());
      expect(entry.actor.userId, actorUid);
      expect(entry.actor.userName, 'المُصدِّر');
    });

    test('★★ و`valuesBefore` فارغة قطعاً — التصدير لا يُغيِّر حقلاً', () {
      expect(acceptedEntry(request()).valuesBefore, isEmpty);
    });

    test('★★ و`valuesAfter` علامةُ صيغةٍ صريحة — بنفس سابقة `delete`', () {
      // ⛔ **وخريطةٌ فارغةٌ تماماً كانت تُقرأ «لم يتغيّر شيء»** بلا أن تقول
      //    ماذا خرج من النظام — راجع `audit-log-design.md` §3.
      expect(
        acceptedEntry(request()).valuesAfter,
        <String, Object?>{'exportFormat': 'pdf'},
      );
    });

    test('⛔⛔★★ ولا سببَ يُعبَّأ نيابةً عن المستخدم — `ADR-0020`', () {
      // ★ **القاعدة الوحيدة الباقية بعد `ADR-0020`:** ما لم يكتبه إنسان
      //   لا يُرسَل ولا يُخزَّن — ⟵ **ولا مسارَ سببٍ في هذه العملية أصلاً.**
      expect(acceptedEntry(request()).reason, isNull);
    });

    test('★ ومعرّف القيد هو معرّف الطلب — فتُعاد المحاولة بلا تكرار', () {
      expect(acceptedEntry(request(id: 'req-x')).id, 'req-x');
    });

    test('★ ووصف الجهاز يعبر كما هو حين يُرسَل', () {
      expect(
        acceptedEntry(request(deviceInfo: 'Pixel 6 · Android 16')).deviceInfo,
        'Pixel 6 · Android 16',
      );
    });
  });

  group('⛔⛔★★★ حارس «قيدٌ بلا مستند» — العَلَم يُقرأ ولا يُخمَّن', () {
    AuditEntry entryWith(AuditAction action) => AuditEntry(
          id: 'req-guard',
          occurredAt: platformNow,
          actor: AuditActor(userId: actorUid, userName: 'المُصدِّر'),
          action: action,
          target: AuditTarget(
            entityType: receiptEntityType,
            entityId: 'RCP-1',
            sourceId: sourceA,
          ),
        );

    test('✅ خطةُ تصديرٍ بلا مستندٍ وبالعَلَم مرفوعاً — مقبولة بنيوياً', () {
      final AuditedWrite<void> write = AuditedWrite<void>(
        documents: const <PendingDocument>[],
        auditOnly: true,
        entry: entryWith(AuditAction.export),
        result: null,
      );
      expect(write.documents, isEmpty);
      expect(write.auditOnly, isTrue);
      expect(write.entry.action, AuditAction.export);
    });

    test('★ والعَلَم مطفأٌ افتراضياً — ⛔ فلا يُنال بالسهو', () {
      // ⚠️⚠️ **وهذا جوهر القرار:** الحارس يمنع خطأً برمجياً حقيقياً —
      //    **خطةٌ نسيت مستنداتها فتكتب قيداً يوثّق تغييراً لم يقع.**
      //    ⟵ **وإسقاطُه للجميع كان يجعل ذلك يمرّ صامتاً في كل عملية كاتبة.**
      final AuditedWrite<void> write = AuditedWrite<void>(
        documents: const <PendingDocument>[],
        entry: entryWith(AuditAction.create),
        result: null,
      );
      expect(write.auditOnly, isFalse);
    });
  });

  group('⛔⛔ ولا مسارَ تسجيلٍ للإرسال — `FR-M20-15` · `AT-64`', () {
    test('العمليةُ الوحيدة هنا هي التصدير', () {
      // ★ **حارسٌ على العقد نفسه:** `FR-M20-15` نفيٌ صريح («**لا يوجد في
      //   النظام تسجيل لمحاولات الإرسال**») — ⟵ **وعمليةٌ ثانية هنا تعني
      //   أن النفي سقط بلا `CR`.**
      expect(ExportLogOperation.values, <ExportLogOperation>[
        ExportLogOperation.logExport,
      ]);
      expect(
        ExportLogOperation.logExport.requiredPermission,
        Permission.documentExport,
      );
    });
  });
}

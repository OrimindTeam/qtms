import 'package:qtms_domain/qtms_domain.dart';
import 'package:test/test.dart';

/// يوم قياسي لكل الاختبارات — ⛔ ولا `DateTime.now()` في أي منها.
final CalendarDay day = CalendarDay(2026, 8, 30);

PendingEntryDraft buildDraft({
  PendingDocumentKind kind = PendingDocumentKind.sack,
  String documentId = 'SCK-1',
  PendingMissingField field = PendingMissingField.sackTax,
  String readableTitle = 'عبد الفتاح - جونية رقم ١',
  String sourceId = 'SRC-001',
  String? documentNumber,
  String? missingField,
}) =>
    PendingEntryDraft(
      kind: kind,
      documentId: documentId,
      field: field,
      readableTitle: readableTitle,
      sourceId: sourceId,
      date: day,
      documentNumber: documentNumber,
      missingField: missingField,
    );

void main() {
  group('PendingEntryDraft — عقد البند كما يُكتَب', () {
    test('الحقول تُكتب بأسماء data-dictionary.md حرفياً', () {
      expect(
        buildDraft(documentNumber: 'SCK-20260830-0001').toFields().keys.toSet(),
        <String>{
          'documentType',
          'documentId',
          'documentNumber',
          'readableTitle',
          'sourceId',
          'date',
          'missingField',
          'navigationScreen',
          'navigationField',
          'missingFieldKey',
        },
        reason: 'انزلاق اسم حقل يكسر القراءة والفهرس بصمت',
      );
    });

    test('★ ولا حقل رقم مستند لِما لا رقم له — daily_prices', () {
      final Map<String, Object?> fields = buildDraft(
        kind: PendingDocumentKind.dailyPrice,
        documentId: 'SRC-001_ITM-1_20260830',
        field: PendingMissingField.itemPricing,
        readableTitle: 'قات بلدي',
      ).toFields();
      expect(fields.containsKey('documentNumber'), isFalse);
    });

    test('★★ التاريخ منتصفُ ليلٍ عالمي — تاريخ مخزون لا لحظة إدخال', () {
      expect(buildDraft().toFields()['date'], day.asUtcMidnight());
    });

    test('★★ وجهة زر [إدخال] شاشةٌ وحقل معاً — FR-SYS-04', () {
      final Map<String, Object?> fields = buildDraft().toFields();
      expect(fields['navigationScreen'], PendingScreen.sackIntake.name);
      expect(fields['navigationField'], 'taxPerKilo');
    });

    test('⛔ مصدرٌ فارغ يُرفَض — بندٌ لا يقرؤه أحد أسوأ من غيابه', () {
      expect(
        () => buildDraft(sourceId: '  '),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('⛔ عنوانٌ فارغ يُرفَض — §3 يفرض عنواناً يُفهَم بلا فتح المستند', () {
      expect(
        () => buildDraft(readableTitle: '   '),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('★ النصّ الافتراضي للحقل يُستعمَل حين لا يُمرَّر نصّ', () {
      expect(buildDraft().missingField, 'ضريبة الكيلو');
    });

    test('★ ونصٌّ مُمرَّر يغلب الافتراضي', () {
      expect(
        buildDraft(missingField: 'الحد الأدنى').missingField,
        'الحد الأدنى',
      );
    });
  });

  group('pendingEntryId — حتميٌّ فيُمحى بلا قراءة', () {
    test('★★ نفس المستند ونفس الحقل ⟵ نفس المعرّف دائماً', () {
      final String first = pendingEntryId(
        kind: PendingDocumentKind.sack,
        documentId: 'SCK-1',
        field: PendingMissingField.sackTax,
      );
      final String second = pendingEntryId(
        kind: PendingDocumentKind.sack,
        documentId: 'SCK-1',
        field: PendingMissingField.sackTax,
      );
      expect(first, second);
      expect(first, 'sack_SCK-1_sackTax');
    });

    test('★ وحقلان في مستندٍ واحد معرّفان مختلفان', () {
      expect(
        pendingEntryId(
          kind: PendingDocumentKind.sack,
          documentId: 'SCK-1',
          field: PendingMissingField.sackTax,
        ),
        isNot(
          pendingEntryId(
            kind: PendingDocumentKind.sack,
            documentId: 'SCK-1',
            field: PendingMissingField.sackLines,
          ),
        ),
      );
    });

    test('⛔ معرّف مستندٍ فارغ يُرفَض', () {
      expect(
        () => pendingEntryId(
          kind: PendingDocumentKind.sack,
          documentId: '',
          field: PendingMissingField.sackTax,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('★ ومعرّف البند في المسودّة هو نفسه', () {
      expect(buildDraft().entryId, 'sack_SCK-1_sackTax');
    });
  });

  group('PendingEntryFilter — ⛔ ولا استعلامَ بلا مصدر', () {
    test('⛔ مصدرٌ فارغ يُرفَض في النوع نفسه — درس IQ-024', () {
      expect(
        () => PendingEntryFilter(sourceId: ''),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('★ وبلا نوعٍ يقبل كل الأنواع', () {
      final PendingEntryFilter filter = PendingEntryFilter(sourceId: 'SRC-001');
      expect(
        filter.accepts(
          const PendingEntryCard(
            id: 'x',
            kind: PendingDocumentKind.distribution,
            documentId: 'd',
            readableTitle: 't',
            sourceId: 'SRC-001',
            date: null,
            missingField: 'm',
          ),
        ),
        isTrue,
      );
    });

    test('★ وبنوعٍ يرفض ما سواه', () {
      final PendingEntryFilter filter = PendingEntryFilter(
        sourceId: 'SRC-001',
        kind: PendingDocumentKind.sack,
      );
      expect(
        filter.accepts(
          const PendingEntryCard(
            id: 'x',
            kind: PendingDocumentKind.distribution,
            documentId: 'd',
            readableTitle: 't',
            sourceId: 'SRC-001',
            date: null,
            missingField: 'm',
          ),
        ),
        isFalse,
      );
    });
  });

  group('PendingEntryCard — القراءة المتسامحة', () {
    test('★★ نوعٌ مجهول ⟵ بلا وجهة، ويُعرَض ولا يُخفى', () {
      const PendingEntryCard card = PendingEntryCard(
        id: 'x',
        kind: null,
        documentId: 'd',
        readableTitle: 'بند من إصدارٍ أحدث',
        sourceId: 'SRC-001',
        date: null,
        missingField: 'قيمة',
      );
      expect(card.hasDestination, isFalse);
      expect(card.readableTitle, isNotEmpty);
    });

    test('★ ونوعٌ وحقلٌ معروفان ⟵ وجهةٌ صالحة', () {
      const PendingEntryCard card = PendingEntryCard(
        id: 'x',
        kind: PendingDocumentKind.sack,
        documentId: 'd',
        readableTitle: 'جونية',
        sourceId: 'SRC-001',
        date: null,
        missingField: 'ضريبة الكيلو',
        field: PendingMissingField.sackTax,
      );
      expect(card.hasDestination, isTrue);
    });

    test('★ تحليل النوع والحقل من قيمةٍ مخزَّنة', () {
      expect(PendingDocumentKind.tryParse('sack'), PendingDocumentKind.sack);
      // ✅★★ **`outflow` صار معروفاً في `WU-014`** — ⛔ **وكان `isNull`
      //    حتى 2026-09-01.** ★ **والنوعُ المجهول يبقى مُختبَراً أدناه**:
      //    ⟵ **فالتسامح مع المجهول قاعدةٌ باقية** ⛔ **لا سطرٌ سقط.**
      expect(
        PendingDocumentKind.tryParse('outflow'),
        PendingDocumentKind.outflow,
      );
      expect(PendingDocumentKind.tryParse('somethingNew'), isNull);
      expect(
        PendingMissingField.tryParse('itemPricing'),
        PendingMissingField.itemPricing,
      );
      expect(PendingMissingField.tryParse('somethingNew'), isNull);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // ✅★★ **M22 أُضيف في `WU-014` (2026-09-01) — والحارس انقلب من نفيٍ إلى
  //    إثبات** ⛔ **ولم يُحذَف:** ★ **بنفس ما فعله `IQ-007` بحارس المفاتيح
  //    الإدارية حرفياً** — ⟵ **فالعدد يبقى مفحوصاً عمداً**، ⛔ **ولا تتّسع
  //    القائمةُ صامتةً بقيمةٍ لا كاتبَ لها.**
  // ═══════════════════════════════════════════════════════════════════════
  group('✅ M22 حاضرٌ الآن — وله كاتبٌ فعليٌّ في WU-014', () {
    test('★ أربعةُ أنواعٍ لا ثلاثة — والسحبياتُ آخرُها', () {
      expect(PendingDocumentKind.values, hasLength(4));
      expect(
        PendingDocumentKind.values.map((PendingDocumentKind k) => k.name),
        <String>['sack', 'dailyPrice', 'distribution', 'outflow'],
      );
    });

    test('★ وستةُ حقولٍ لا خمسة — راجع ترويسة PendingMissingField', () {
      expect(PendingMissingField.values, hasLength(6));
      expect(
        PendingMissingField.outflowLinePricing.fieldKey,
        'unitPrice',
      );
    });

    test('★ ووجهتُه شاشةُ السحبيات — ⛔ لا شاشةَ إدخالٍ بديلة', () {
      expect(
        PendingDocumentKind.outflow.screen,
        PendingScreen.outflow,
      );
    });

    test('⛔⛔ ومعرّفُ بندِه لا يلتبس ببندِ توزيعةٍ بنفس الرقم', () {
      // ★★ **والحقلُ `unitPrice` نفسُه في النوعين** — ⟵ **فالتمييزُ من
      //    [PendingDocumentKind] وحده**: ⛔ **ولولاه لتصادم المعرّفان.**
      expect(
        pendingEntryId(
          kind: PendingDocumentKind.outflow,
          documentId: 'WDR-20260901-0001',
          field: PendingMissingField.outflowLinePricing,
        ),
        isNot(
          pendingEntryId(
            kind: PendingDocumentKind.distribution,
            documentId: 'WDR-20260901-0001',
            field: PendingMissingField.distributionLinePricing,
          ),
        ),
      );
    });
  });
}

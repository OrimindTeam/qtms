import 'package:qtms_domain/qtms_domain.dart';
import 'package:test/test.dart';

void main() {
  final CalendarDay day = CalendarDay(2026, 8, 22);

  group('formatDocumentNumber — naming-conventions.md §5', () {
    test('البادئات التسع منقولة حرفياً من الجدول', () {
      // ★ المتوقَّع هنا **من المستند لا من تشغيل الكود** — test-strategy §3
      //   القاعدة 1: «سجّل ما أخرجه البرنامج كمتوقَّع» يُثبّت الخطأ لا يكشفه.
      final Map<DocumentKind, String> expected = <DocumentKind, String>{
        DocumentKind.countedIntake: 'INC-20260822-0007',
        DocumentKind.sack: 'SCK-20260822-0007',
        DocumentKind.distribution: 'DST-20260822-0007',
        DocumentKind.cashSale: 'CSH-20260822-0007',
        DocumentKind.receipt: 'RCP-20260822-0007',
        DocumentKind.discount: 'DSC-20260822-0007',
        DocumentKind.withdrawal: 'WDR-20260822-0007',
        DocumentKind.expense: 'EXP-20260822-0007',
        // ★ الجرد بثلاث خانات وحده.
        DocumentKind.stocktake: 'STK-20260822-007',
      };

      for (final MapEntry<DocumentKind, String> entry in expected.entries) {
        expect(
          formatDocumentNumber(kind: entry.key, day: day, sequence: 7),
          entry.value,
          reason: 'البادئة أو عرض التسلسل لـ${entry.key.name} خالف §5',
        );
      }

      // حارس: كل نوع مستند مذكور في الجدول أعلاه — فإن أُضيف نوع بلا اختبار
      // فشل هذا السطر بدل أن يمرّ بلا تغطية.
      expect(expected.keys.toSet(), DocumentKind.values.toSet());
    });

    test('التسلسل يبدأ من ١ ويُحشى بأصفار إلى عرضه المعتمد', () {
      expect(
        formatDocumentNumber(
            kind: DocumentKind.sack, day: day, sequence: 1),
        'SCK-20260822-0001',
      );
      expect(
        formatDocumentNumber(
            kind: DocumentKind.sack, day: day, sequence: 9999),
        'SCK-20260822-9999',
      );
    });

    test('يرفض تسلسلاً أقل من ١ — خلل عدّاد لا قاعدة عمل', () {
      expect(
        () => formatDocumentNumber(
            kind: DocumentKind.sack, day: day, sequence: 0),
        throwsArgumentError,
      );
      expect(
        () => formatDocumentNumber(
            kind: DocumentKind.sack, day: day, sequence: -1),
        throwsArgumentError,
      );
    });

    test('عند تجاوز العرض يتّسع الرقم ولا يُقتطَع — لا رقمان متطابقان', () {
      // ⚠️ الاقتطاع كان سينتج 'SCK-20260822-0000' لـ10000 فيصطدم برقم قائم.
      expect(
        formatDocumentNumber(
            kind: DocumentKind.sack, day: day, sequence: 10000),
        'SCK-20260822-10000',
      );
      expect(
        formatDocumentNumber(
            kind: DocumentKind.stocktake, day: day, sequence: 1000),
        'STK-20260822-1000',
      );
    });

    test('التاريخ يتبع اليوم المُمرَّر لا ساعة الجهاز', () {
      expect(
        formatDocumentNumber(
          kind: DocumentKind.receipt,
          day: CalendarDay(2026, 1, 3),
          sequence: 12,
        ),
        'RCP-20260103-0012',
      );
    });
  });

  group('IQ-005: أي يوم يدخل رقم المستند', () {
    final CalendarDay documentDay = CalendarDay(2026, 8, 20); // تاريخ سابق
    final CalendarDay serverDay = CalendarDay(2026, 8, 22); // اليوم

    test('التصنيف مطابق لما تقبله `firestore.rules` — لا اجتهاد', () {
      // ⛔ اليوم وحده — القاعدة تفرض `todayStockDate()` بلا بديل.
      expect(allowsBackdating(DocumentKind.countedIntake), isFalse);
      expect(allowsBackdating(DocumentKind.sack), isFalse);

      // ✅ يقبل السابق — إمّا بصلاحية تصريف متأخر أو بـ`notFutureDate`.
      for (final DocumentKind kind in <DocumentKind>[
        DocumentKind.distribution,
        DocumentKind.cashSale,
        DocumentKind.receipt,
        DocumentKind.discount,
        DocumentKind.withdrawal,
        DocumentKind.expense,
        DocumentKind.stocktake,
      ]) {
        expect(allowsBackdating(kind), isTrue, reason: kind.name);
      }
    });

    test('الخيار ج: تاريخ المستند لما يقبل السابق، واليوم لما عداه', () {
      // سند قبض بتاريخ سابق ⟵ يحمل رقم ذلك اليوم لا رقم اليوم.
      expect(
        formatDocumentNumber(
          kind: DocumentKind.receipt,
          day: documentNumberDay(
            kind: DocumentKind.receipt,
            documentDay: documentDay,
            serverDay: serverDay,
          ),
          sequence: 3,
        ),
        'RCP-20260820-0003',
      );

      // وارد عدداً ⟵ اليوم دائماً، ولو مُرِّر تاريخ سابق.
      expect(
        formatDocumentNumber(
          kind: DocumentKind.countedIntake,
          day: documentNumberDay(
            kind: DocumentKind.countedIntake,
            documentDay: documentDay,
            serverDay: serverDay,
          ),
          sequence: 3,
        ),
        'INC-20260822-0003',
      );
    });

    test('حين يتطابق التاريخان لا فرق بين النوعين', () {
      for (final DocumentKind kind in DocumentKind.values) {
        expect(
          documentNumberDay(
            kind: kind,
            documentDay: serverDay,
            serverDay: serverDay,
          ),
          serverDay,
          reason: kind.name,
        );
      }
    });
  });

  group('formatEntityCode — أكواد الكيانات §5', () {
    test('الأكواد الخمسة منقولة حرفياً — والمصدر بثلاث خانات', () {
      final Map<EntityKind, String> expected = <EntityKind, String>{
        EntityKind.source: 'SRC-001',
        EntityKind.supplier: 'SUP-0001',
        EntityKind.dealer: 'MQT-0001',
        EntityKind.item: 'ITM-0001',
        EntityKind.user: 'USR-0001',
      };

      for (final MapEntry<EntityKind, String> entry in expected.entries) {
        expect(
          formatEntityCode(kind: entry.key, sequence: 1),
          entry.value,
          reason: 'كود ${entry.key.name} خالف §5',
        );
      }

      expect(expected.keys.toSet(), EntityKind.values.toSet());
    });

    test('يرفض تسلسلاً أقل من ١', () {
      expect(
        () => formatEntityCode(kind: EntityKind.source, sequence: 0),
        throwsArgumentError,
      );
    });
  });
}

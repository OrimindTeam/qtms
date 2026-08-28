/// حمولة سطور الجونية — ★★ **في أي حقلٍ يعبر وزنُ الحبة الشبكة**.
///
/// ⚠️⚠️ **ولماذا اختبارٌ على الحمولة لا على النتيجة:** السحابة **تُعيد
/// اشتقاق `pieceWeightOrigin` من الحقل الذي وصلها** (`resolveSackLine`) —
/// ⟵ **فالحقلُ هو الرسالة**، ⛔ **وإرسالُ رقم التهيئة في حقل «اليدوي»
/// يَسِم السطر «يدوياً» بلا أن تُخطئ سطراً واحداً في النطاق ولا في السحابة**
/// (`DEBT-37` · `sack-intake-design.md` §4).
///
/// ⛔★★ **ولا يُرسَل `pieceWeightOrigin` نفسه** — ★ **مشتقٌّ لا مُدخَل**،
/// ⟵ **والاختبار يُثبت أنه لم يتسلّل إلى الحمولة.**
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:qtms/capabilities/inventory/infrastructure/functions_sack_repository.dart';
import 'package:qtms/core/callable/callable_client.dart';
import 'package:qtms_domain/qtms_domain.dart';

/// عميل HTTP مزيّف — يسجّل المسار والحمولة ويردّ نجاحاً.
final class _FakeHttp extends http.BaseClient {
  Map<String, Object?>? lastData;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final String raw =
        await (request as http.Request).finalize().bytesToString();
    final Object? decoded = jsonDecode(raw);
    if (decoded is Map<String, Object?> &&
        decoded['data'] is Map<String, Object?>) {
      lastData = decoded['data']! as Map<String, Object?>;
    }
    return http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode('{"result": {}}')),
      200,
    );
  }
}

(FunctionsSackRepository, _FakeHttp) repository() {
  final _FakeHttp fake = _FakeHttp();
  return (
    FunctionsSackRepository(
      client: CallableClient(
        httpClient: fake,
        readIdToken: () async => 'ID-TOKEN',
        baseUrl: 'https://example.invalid',
      ),
      newRequestId: () => 'REQ-FIXED',
    ),
    fake,
  );
}

ValidatedSackLine line(SackLineInput input) =>
    (resolveSackLine(input) as Success<ValidatedSackLine>).value;

Future<Map<String, Object?>> sendOne(SackLineInput input) async {
  final (FunctionsSackRepository repo, _FakeHttp fake) = repository();
  await repo.enterSackLines(
    documentNumber: 'SCK-20260826-0001',
    sourceId: 'SRC-001',
    lines: <ValidatedSackLine>[line(input)],
    amendReason: 'سبب',
  );
  return (fake.lastData!['lines']! as List<Object?>).single!
      as Map<String, Object?>;
}

void main() {
  group('★★★ DEBT-37 — وزنُ الحبة يعبر في حقل حالته', () {
    test('★★★ ① التهيئة ⟵ `configuredPieceWeightGrams` وحده', () async {
      final Map<String, Object?> sent = await sendOne(
        const SackLineInput(
          itemId: 'ITM-0002',
          itemName: 'بطوة',
          nature: ItemNature.weightBased,
          unit: ItemUnit.piece,
          quantity: 100,
          configuredPieceWeightGrams: 200,
        ),
      );

      expect(sent['configuredPieceWeightGrams'], 200);
      // ⛔★★★ **وإرسالُه في حقل «اليدوي» يَسِم السطر يدوياً في السحابة.**
      expect(sent.containsKey('pieceWeightGrams'), isFalse);
      expect(sent.containsKey('pieceWeightOrigin'), isFalse);
    });

    test('★★ ② اليدوي ⟵ `pieceWeightGrams` وحده', () async {
      final Map<String, Object?> sent = await sendOne(
        const SackLineInput(
          itemId: 'ITM-0003',
          itemName: 'معالم',
          nature: ItemNature.weightBased,
          unit: ItemUnit.piece,
          quantity: 50,
          pieceWeightGrams: 180,
        ),
      );

      expect(sent['pieceWeightGrams'], 180);
      expect(sent.containsKey('configuredPieceWeightGrams'), isFalse);
      expect(sent.containsKey('pieceWeightOrigin'), isFalse);
    });

    test('⛔★★★ ③ العددي ⟵ الوزن الكلي وحده ولا وزنَ حبةٍ بأي اسم', () async {
      final Map<String, Object?> sent = await sendOne(
        const SackLineInput(
          itemId: 'ITM-0004',
          itemName: 'عود',
          nature: ItemNature.countBased,
          unit: ItemUnit.piece,
          quantity: 250,
          lineTotalWeight: 15,
        ),
      );

      expect(sent['lineTotalWeight'], 15);
      // ⛔★★★ **الحقل مقفل** — `E-09`: ⟵ **ولا يُرسَل بأي من اسميه.**
      expect(sent.containsKey('pieceWeightGrams'), isFalse);
      expect(sent.containsKey('configuredPieceWeightGrams'), isFalse);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  group('★★★ IQ-025 · ADR-0018 — ⛔ ولا سببَ يُعبِّئه التطبيق', () {
    test('⛔★★★ حقلٌ تركه المستخدم فارغاً لا يُرسَل سبباً إطلاقاً', () async {
      final (FunctionsSackRepository repo, _FakeHttp fake) = repository();
      await repo.enterSackLines(
        documentNumber: 'SCK-20260826-0001',
        sourceId: 'SRC-001',
        lines: <ValidatedSackLine>[
          line(
            const SackLineInput(
              itemId: 'ITM-0001',
              itemName: 'بطوة',
              nature: ItemNature.weightBased,
              unit: ItemUnit.piece,
              quantity: 100,
              pieceWeightGrams: 200,
            ),
          ),
        ],
      );
      // ⛔⛔★★★ **جوهرُ `IQ-025`:** ★ **الحمولة تخلو من الحقل رأساً** —
      //    ⟵ **فلا نصَّ آلةٍ يستقرّ في قيد التدقيق يقرؤه المدقّق سببَ
      //    إنسان** (`ADR-0004` · `audit-log-design.md` §3).
      expect(fake.lastData!.containsKey('reason'), isFalse);
    });

    test('⛔★★ والضريبة كذلك — ولا فرق بين المسارين', () async {
      final (FunctionsSackRepository repo, _FakeHttp fake) = repository();
      await repo.enterSackTax(
        documentNumber: 'SCK-20260826-0001',
        sourceId: 'SRC-001',
        taxPerKilo: const Money(25),
      );
      expect(fake.lastData!.containsKey('reason'), isFalse);
      expect(fake.lastData!['taxPerKilo'], 25);
    });

    test('✅ وسببٌ كتبه إنسانٌ يعبر كما هو', () async {
      final (FunctionsSackRepository repo, _FakeHttp fake) = repository();
      await repo.enterSackTax(
        documentNumber: 'SCK-20260826-0001',
        sourceId: 'SRC-001',
        taxPerKilo: const Money(25),
        amendReason: 'تصحيح قيمة الضريبة',
      );
      expect(fake.lastData!['reason'], 'تصحيح قيمة الضريبة');
    });
  });
}

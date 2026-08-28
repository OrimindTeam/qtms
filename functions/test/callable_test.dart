/// بروتوكول الاستدعاء — ★ **فكّ الطلب ورفضُه المبكر**.
library;

import 'dart:convert';

import 'package:qtms_functions/src/callable.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

Request post(Object body, {String? contentType}) => Request(
      'POST',
      Uri.parse('https://x.invalid/createRole'),
      headers: <String, String>{
        'authorization': 'Bearer TOKEN',
        'content-type': ?contentType,
      },
      body: body,
    );

void main() {
  group('★★ ترميز الجسم — حارسٌ رُصد بالتشغيل الحقيقي (2026-08-25)', () {
    test('✅ جسمٌ عربي صحيح يُفكّ كما هو — ⛔ ولا تشويه', () async {
      // ★★ **والنظام عربيٌّ كلّه:** كل سبب ووصف واسم يعبر هنا بمحارف
      //    متعددة البايتات، ⟵ **فتشويهُ بايتٍ واحد يُفسد قيد تدقيق.**
      final CallableParse parsed = await parseCallableRequest(
        post(
          utf8.encode(
            jsonEncode(<String, Object?>{
              'data': <String, Object?>{'amendReason': 'الدور لم يعد مستخدَماً'},
            }),
          ),
          contentType: 'application/json; charset=utf-8',
        ),
      );
      expect(parsed, isA<ParsedCallable>());
      expect(
        (parsed as ParsedCallable).request.readString('amendReason'),
        'الدور لم يعد مستخدَماً',
      );
    });

    test('⛔★★★ وجسمٌ ببايتات ليست UTF-8 يُرفَض برمزه ⛔ لا بـ500 خام', () async {
      // ⚠️⚠️ **رُصد على Cloud Run لا في الاختبار:** `readAsString()` كانت
      //    ترمي `FormatException` **خارج أي `try`**، ⟵ **فيصل العميلَ
      //    «Internal Server Error» نصّاً خاماً بلا رمز كتالوج** —
      //    ⛔ **وهو ما يمنعه `error-handling-strategy.md` §3 القاعدة 1.**
      final CallableParse parsed = await parseCallableRequest(
        // ⛔ `0xD8` بادئةُ محرفٍ عربي **بلا بايت متابعة** — مُدخَل حقيقي
        //    تُنتجه بوابةٌ وسيطة تُعيد الترميز.
        post(<int>[123, 34, 100, 34, 58, 0xD8, 34, 125],
            contentType: 'application/json; charset=utf-8'),
      );
      expect(parsed, isA<RejectedCallable>());
      expect(
        (parsed as RejectedCallable).error.code,
        CallableError.invalidArgument.code,
      );
    });

    test('⛔ وجسمٌ ليس JSON يُرفَض كذلك', () async {
      final CallableParse parsed =
          await parseCallableRequest(post('<html>proxy</html>'));
      expect(parsed, isA<RejectedCallable>());
    });

    test('⛔ وبلا ترويسة اعتماد ⟵ جلسة لا نقصَ صلاحية', () async {
      final Request request = Request(
        'POST',
        Uri.parse('https://x.invalid/createRole'),
        body: jsonEncode(<String, Object?>{'data': <String, Object?>{}}),
      );
      final CallableParse parsed = await parseCallableRequest(request);
      expect(
        (parsed as RejectedCallable).error.code,
        CallableError.sessionExpired.code,
      );
    });
  });
}

import 'dart:convert';

import 'package:qtms_domain/qtms_domain.dart';
import 'package:qtms_functions/src/identity_claims.dart';
import 'package:test/test.dart';

void main() {
  group('صيغة المطالبات — نقل حرفي لـauthentication-and-authorization §3', () {
    test('المفاتيح الثلاثة بأسمائها كما تقرأها قواعد الحماية', () {
      final IdentityClaims claims = IdentityClaims(
        permissions: <Permission>{Permission.sackView},
        sourceScope: const AllSources(),
        roleId: 'ROL-1',
      );
      final Map<String, Object?> decoded =
          jsonDecode(claims.encode()) as Map<String, Object?>;
      // ★★ ADR-0016: مفتاحان لا ثلاثة — `permissions` خرجت من الرمز.
      expect(decoded.keys.toSet(), <String>{'role', 'sourceScope'});
      expect(decoded.containsKey('permissions'), isFalse);
      expect(roleClaimKey, 'role');
      expect(permissionsClaimKey, 'permissions');
      expect(sourceScopeClaimKey, 'sourceScope');
    });

    test('★★ ADR-0016: لا صلاحية تُكتب في الرمز مهما مُنِحت', () {
      // ⚠️ كان هذا الاختبار يتحقق من **شكل** خريطة الصلاحيات في الرمز.
      //    ★ وبعد ADR-0016 لا خريطة أصلاً — فصار يتحقق من **غيابها**،
      //    وهو الشرط الذي يجعل حمولة الرمز ثابتة مهما كبر الكتالوج.
      final IdentityClaims claims = IdentityClaims(
        permissions: <Permission>{Permission.sackView, Permission.itemWrite},
        sourceScope: const AllSources(),
      );
      final Map<String, Object?> decoded =
          jsonDecode(claims.encode()) as Map<String, Object?>;
      expect(decoded.containsKey('permissions'), isFalse,
          reason: 'الصلاحيات مصدرها users/{userId} لا الرمز');
      expect(decoded['sourceScope'], 'all');
    });

    test('★ `all` نصّاً لا قائمة — كما تقارنها القاعدة حرفياً', () {
      final IdentityClaims claims = IdentityClaims(
        permissions: <Permission>{},
        sourceScope: const AllSources(),
      );
      expect(
        (jsonDecode(claims.encode()) as Map<String, Object?>)['sourceScope'],
        'all',
      );
      expect(allSourcesClaimValue, 'all');
    });

    test('والقائمة تُرتَّب — فنفس المجموعة تُنتج نفس النصّ دائماً', () {
      final IdentityClaims a = IdentityClaims(
        permissions: <Permission>{Permission.itemWrite, Permission.sackView},
        sourceScope: ScopedSources(<String>{'SRC-002', 'SRC-001'}),
      );
      final IdentityClaims b = IdentityClaims(
        permissions: <Permission>{Permission.sackView, Permission.itemWrite},
        sourceScope: ScopedSources(<String>{'SRC-001', 'SRC-002'}),
      );
      expect(a.encode(), b.encode());
      expect(
        (jsonDecode(a.encode()) as Map<String, Object?>)['sourceScope'],
        <String>['SRC-001', 'SRC-002'],
      );
    });
  });

  group('الفكّ — متساهل في القراءة ولا يبتلع المجهول', () {
    test('رمز بلا مطالبات يعني حساباً بلا صلاحيات ولا نطاق', () {
      for (final String? raw in <String?>[null, '', '   ']) {
        final ClaimsDecoding decoded = IdentityClaims.decode(raw);
        expect(decoded.claims.permissions, isEmpty);
        expect(decoded.claims.sourceScope, isNull);
        expect(decoded.claims.canAccessSource('SRC-001'), isFalse,
            reason: 'غياب النطاق منع لا سماح');
      }
    });

    test('★★ ADR-0016: صلاحية في الرمز **تُتجاهَل ولا تُمنَح** — وتُبلَّغ', () {
      // ⚠️ رمزٌ أُصدر قبل الترحيل ما يزال يحمل الخريطة القديمة. ⛔ وقراءتها
      //    كانت ستفتح بالضبط المسار الذي أغلقته القاعدة.
      final ClaimsDecoding decoded = IdentityClaims.decode(
        jsonEncode(<String, Object?>{
          'permissions': <String, Object?>{'sackView': true, 'ghostKey': true},
        }),
      );
      expect(decoded.claims.has(Permission.sackView), isFalse);
      expect(decoded.claims.permissions, isEmpty);
      expect(decoded.legacyKeys, <String>{'sackView', 'ghostKey'});
    });

    test('والقيمة غير `true` لا تُعَدّ منحاً', () {
      final ClaimsDecoding decoded = IdentityClaims.decode(
        jsonEncode(<String, Object?>{
          'permissions': <String, Object?>{
            'sackView': false,
            'itemWrite': 'true',
          },
        }),
      );
      expect(decoded.claims.permissions, isEmpty);
    });

    test('القائمة الفارغة ليست نطاقاً — بل غياب نطاق', () {
      final ClaimsDecoding decoded = IdentityClaims.decode(
        jsonEncode(<String, Object?>{'sourceScope': <String>[]}),
      );
      expect(decoded.claims.sourceScope, isNull);
    });

    test('ذهاب وإياب: الدور والنطاق يُفكّان كما هما — ⛔ ولا صلاحيات', () {
      final IdentityClaims original = IdentityClaims(
        permissions: <Permission>{Permission.receiptCreate, Permission.sackView},
        sourceScope: ScopedSources(<String>{'SRC-003'}),
        roleId: 'ROL-9',
      );
      final IdentityClaims back =
          IdentityClaims.decode(original.encode()).claims;
      // ★★ ADR-0016: الصلاحيات **لا تعبر الرمز** ذهاباً ولا إياباً.
      expect(back.permissions, isEmpty);
      expect(back.sourceScope, original.sourceScope);
      expect(back.roleId, 'ROL-9');
      expect(back.canAccessSource('SRC-003'), isTrue);
      expect(back.canAccessSource('SRC-004'), isFalse);
    });

    test('⛔ ونصّ ليس كائن JSON يُرفَض صراحةً لا صامتاً', () {
      expect(() => IdentityClaims.decode('[1,2]'), throwsFormatException);
    });
  });

  group('★★ ADR-0016 — القيد الذي أوجد IQ-008 زال بالقياس لا بالادعاء', () {
    test('★★ الاثنتان والسبعون **لم تعد تتجاوز الحدّ** — لأنها ليست في الرمز', () {
      // ⚠️ هذا الاختبار كان يؤكّد العكس تماماً قبل ADR-0016 (يرمي
      //    ClaimsTooLargeException). ★ وانقلابه **هو الدليل** أن القرار
      //    نُفِّذ فعلاً وأن سبب IQ-008 زال من جذره.
      final IdentityClaims claims = IdentityClaims(
        permissions: Permission.values.toSet(),
        sourceScope: const AllSources(),
        roleId: 'ROL-OWNER',
      );
      expect(claims.encode, returnsNormally);
    });

    test('★ والحجم المقيس تحت الحدّ بفارق واسع — رقم مرصود لا مُقدَّر', () {
      final String encoded = IdentityClaims(
        permissions: Permission.values.toSet(),
        sourceScope: const AllSources(),
        roleId: 'ROL-OWNER',
      ).encode();
      final int size = utf8.encode(encoded).length;
      expect(size, lessThan(maxCustomClaimsBytes));
      // ★ والحدّ نفسه لم يُرفَع — القيد الخارجي كما هو، والحلّ كان بالمحتوى.
      expect(maxCustomClaimsBytes, 1000);
    });

    test('⛔ والفحص يبقى حارساً: نطاق مصادر ضخم يتجاوز الحدّ فيُرمى', () {
      // ★ يُثبت أن إزالة الصلاحيات **لم تُعطِّل الحارس** بل أزالت سببَ إطلاقه.
      final IdentityClaims claims = IdentityClaims(
        permissions: const <Permission>{},
        sourceScope: ScopedSources(<String>{
          for (int i = 0; i < 200; i++) 'SRC-${i.toString().padLeft(6, '0')}',
        }),
      );
      expect(claims.encode, throwsA(isA<ClaimsTooLargeException>()));
    });
  });
}

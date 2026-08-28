/// تحويل مستند المستخدم — ★ **الاتجاه الآمن في كل حقل غامض.**
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:qtms/capabilities/identity_access/infrastructure/user_card_mapper.dart';
import 'package:qtms_domain/qtms_domain.dart';

void main() {
  group('mapUserCard — data-dictionary §1', () {
    test('★ يقرأ الحقول بأسمائها الموثَّقة', () {
      final UserCard card = mapUserCard(
        userId: 'U-001',
        document: <String, Object?>{
          'name': ' عبدالفتاح ',
          'email': 'owner@example.com',
          'roleId': 'R-001',
          'roleName': 'المالك',
          'isActive': true,
          'permissions': <String, Object?>{
            'sackView': true,
            'userCreate': false,
          },
        },
      );

      expect(card.name, 'عبدالفتاح');
      expect(card.email, 'owner@example.com');
      expect(card.roleName, 'المالك');
      expect(card.isActive, isTrue);
      expect(card.permissions, <Permission>{Permission.sackView});
    });

    test('⛔★★ `isActive` الغائبة تُقرأ false — الرفض هو الأصل', () {
      final UserCard card = mapUserCard(
        userId: 'U-001',
        document: const <String, Object?>{'name': 'ب'},
      );
      expect(card.isActive, isFalse);
      expect(card.permissions, isEmpty);
    });

    test('⛔ ومفتاح صلاحية لا يعرفه الكتالوج يُتجاهَل ولا يمنح شيئاً', () {
      final UserCard card = mapUserCard(
        userId: 'U-001',
        document: const <String, Object?>{
          'name': 'ب',
          'isActive': true,
          'permissions': <String, Object?>{
            'superAdmin': true,
            'sackView': true,
          },
        },
      );
      expect(card.permissions, <Permission>{Permission.sackView});
    });

    test('⛔ وقيمة غير `true` لا تمنح — والقاعدة تقارن `== true` حرفياً', () {
      final UserCard card = mapUserCard(
        userId: 'U-001',
        document: const <String, Object?>{
          'name': 'ب',
          'isActive': true,
          'permissions': <String, Object?>{
            'sackView': 'true',
            'itemWrite': 1,
            'dealerWrite': null,
          },
        },
      );
      expect(card.permissions, isEmpty);
    });

    test('★ والاسم الفارغ يسقط إلى المعرّف — فلا شاشة بلا عنوان', () {
      final UserCard card = mapUserCard(
        userId: 'U-001',
        document: const <String, Object?>{'name': '   ', 'isActive': true},
      );
      expect(card.name, 'U-001');
      expect(card.email, isNull);
      expect(card.roleName, isNull);
    });
  });
}

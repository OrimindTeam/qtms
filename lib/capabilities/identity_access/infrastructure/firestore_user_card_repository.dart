/// تنفيذ مستودع بطاقة المستخدم على قاعدة البيانات.
///
/// ⛔ **ولا يقرأ إلا بطاقة صاحب الجلسة** — القاعدة نفسها ترفض غيرها:
/// `allow read: if isSignedIn() && request.auth.uid == userId`.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qtms_domain/qtms_domain.dart';

import 'user_card_mapper.dart';

/// اسم مجموعة المستخدمين كما في `data-dictionary.md` §1.
const String usersCollection = 'users';

/// مستودع البطاقة الحقيقي.
final class FirestoreUserCardRepository implements UserCardRepository {
  FirestoreUserCardRepository(this._firestore);

  final FirebaseFirestore _firestore;

  /// ★ **مُصغٍ حيّ لا قراءة واحدة:** سحب صلاحية أو تعطيل حساب **يصل الواجهة
  /// بلا إعادة دخول** (`ADR-0016` · `FR-M1-15`).
  @override
  Stream<UserCard?> watchCard(String userId) => _firestore
      .collection(usersCollection)
      .doc(userId)
      .snapshots()
      .map((DocumentSnapshot<Map<String, dynamic>> snapshot) {
        final Map<String, dynamic>? data = snapshot.data();
        if (!snapshot.exists || data == null) return null;
        return mapUserCard(userId: userId, document: data);
      });
}

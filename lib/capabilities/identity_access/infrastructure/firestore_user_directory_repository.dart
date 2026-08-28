/// دليل المستخدمين والأدوار — **قراءةً فقط** (`IQ-015`).
///
/// ⛔★★ **ولا كتابة واحدة هنا:** `users` و`roles` مغلقتان بـ
/// `allow write: if false`، **والكتابة كلها عبر العمليات المستدعاة**
/// (`ADR-0013` · `functions_user_admin_repository.dart`).
///
/// ⚠️ **واستعلام المجموعة كلها يُرفَض بلا `userView`** — والرفض يصل
/// **كخطأ في التدفّق** لا كقائمة فارغة، ⟵ ★ **فتعرض الشاشة حالةَ منعٍ
/// صريحة** ⛔ لا «لا يوجد مستخدمون» المضلِّلة.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qtms_domain/qtms_domain.dart';

import 'firestore_user_card_repository.dart';
import 'user_card_mapper.dart';

/// اسم مجموعة الأدوار كما في `data-dictionary.md` §`roles`.
const String rolesCollection = 'roles';

/// حقل اسم الدور.
const String roleNameField = 'name';

/// حقل وصف الدور — **اختياري**.
const String roleDescriptionField = 'description';

/// ★★ حقل قالب صلاحيات الدور — `data-dictionary.md` §`roles`.
const String rolePermissionTemplateField = 'permissionTemplate';

/// دليل المستخدمين الحقيقي.
final class FirestoreUserDirectoryRepository
    implements UserDirectoryRepository {
  /// ينشئ المستودع.
  FirestoreUserDirectoryRepository(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Stream<List<UserCard>> watchAll() => _firestore
      .collection(usersCollection)
      // ★ **الترتيب من الخادم لا في الذاكرة** — فالصفحة الأولى صحيحة قبل
      //   وصول البقية، ⛔ ولا تقفز الأسماء أمام المستخدم وهي تُحمَّل.
      .orderBy(userNameField)
      .snapshots()
      .map((QuerySnapshot<Map<String, dynamic>> snapshot) => snapshot.docs
          .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
              mapUserCard(userId: doc.id, document: doc.data()))
          .toList());
}

/// دليل الأدوار الحقيقي — **قراءةً فقط**.
final class FirestoreRoleDirectory {
  /// ينشئ الدليل.
  FirestoreRoleDirectory(this._firestore);

  final FirebaseFirestore _firestore;

  /// تدفّق الأدوار — ★ **مقروء لكل مُصادَق** (`allow read: if isSignedIn()`).
  Stream<List<RoleCard>> watchAll() => _firestore
      .collection(rolesCollection)
      .orderBy(roleNameField)
      .snapshots()
      .map((QuerySnapshot<Map<String, dynamic>> snapshot) => snapshot.docs
          .map(_toRole)
          .toList());

  static RoleCard _toRole(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final Map<String, dynamic> data = doc.data();
    final Object? rawName = data[roleNameField];
    final Object? rawDescription = data[roleDescriptionField];
    return RoleCard(
      roleId: doc.id,
      // ⛔ اسمٌ غائب لا يُخفي الدور — **يُعرَض بمعرّفه** فيبقى قابلاً للإصلاح.
      name: rawName is String && rawName.trim().isNotEmpty
          ? rawName.trim()
          : doc.id,
      description: rawDescription is String && rawDescription.trim().isNotEmpty
          ? rawDescription.trim()
          : null,
      // ★★ **قالب الصلاحيات** — وعليه تقوم «مقارنة المستخدم بدوره»
      //   (`FR-M1-05` · `FR-M1-16`).
      permissionTemplate: _readTemplate(data[rolePermissionTemplateField]),
      // ⛔★★ **ولا يُقرأ «مُسنَد» من مستند الدور** — `IQ-018`: «لا يعتمد على
      //    قيمة مخزنة أو افتراض محلي». ★ **والإسناد يُشتقّ من `users`
      //    نفسها** في `assignedRoleIdsProvider`، ⟵ **فلا حقلَ يكذب.**
    );
  }

  /// ★ يقرأ القالب — ⛔ **والمفتاح المجهول يُتجاهَل ولا يُسقِط الشاشة**.
  ///
  /// ⚠️ **ولا يُقاس التساهل هنا على صرامة الكتابة:** الكتابة ترفض المجهول
  /// (`BR-M1-07`)، ★ **والقراءة عرضٌ لا تفويض** — ⟵ **وإسقاطُ شاشة الأدوار
  /// كلها بسبب مفتاحٍ قديم في مستندٍ واحد ضررٌ بلا مقابل.**
  static Set<Permission> _readTemplate(Object? raw) {
    if (raw is! Map<String, dynamic>) return const <Permission>{};
    final Set<Permission> template = <Permission>{};
    for (final MapEntry<String, dynamic> entry in raw.entries) {
      if (entry.value != true) continue;
      for (final Permission p in Permission.values) {
        if (p.name == entry.key) template.add(p);
      }
    }
    return template;
  }
}

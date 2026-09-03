/// ★ مزوّدُ بصمة جهة التطوير — **طبقةُ الوصول الواحدة** (`FR-SYS-29`).
///
/// ⛔⛔★★ **ولا يقرأ أي موضعٍ ملفَّ الهوية بنفسه** — ★ **هذا المزوّد وحدَه
/// يقرؤه، ومرةً واحدةً لكل تشغيل**: ⟵ **فقراءةُ حزمة الأصول عملُ إدخالٍ
/// وإخراج**، ⛔ **وتكرارُها في كل بناءِ شاشةٍ يُبطئ فتحَها بلا مقابل.**
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'developer_identity.dart';

/// ⏳ بصمةُ جهة التطوير — تُقرأ من حزمة الأصول مرةً واحدة.
///
/// ⛔ **ولا قيمةَ احتياطيةً عند الفشل** — ★ **الخطأُ يُعرَض كخطأ**
/// (`AsyncStateView`)، ⛔ **ولا يُعرَض اسمٌ مخترَع.**
final FutureProvider<DeveloperIdentity> developerIdentityProvider =
    FutureProvider<DeveloperIdentity>((Ref ref) => DeveloperIdentity.load());

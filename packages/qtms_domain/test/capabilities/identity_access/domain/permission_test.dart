@TestOn('vm')
library;

import 'dart:io';

import 'package:qtms_domain/qtms_domain.dart';
import 'package:test/test.dart';

/// يستخرج المفاتيح من §2 في كتالوج الصلاحيات — **المصدر الوحيد للمفاتيح**.
///
/// ★ **لماذا يُقرأ المستند بدل نسخ القائمة هنا:** لأن نسخة ثانية من القائمة
/// **تفترق عن المستند عند أول إضافة** — وهو بالضبط ما يمنعه `BR-M1-07`.
/// فالحارس يقرأ الحقيقة من مكانها، ولا يُصدِّق نسخة.
Set<String> _catalogKeys() {
  final File file = File('../../docs/09-security/permissions-catalog.md');
  expect(file.existsSync(), isTrue,
      reason: 'كتالوج الصلاحيات غير موجود في ${file.path}');
  final String text = file.readAsStringSync();

  final int start = text.indexOf('## 2. الكتالوج المعتمد');
  final int end = text.indexOf('## 3. ما **ليس**');
  expect(start, greaterThan(-1), reason: '§2 غير موجود');
  expect(end, greaterThan(start), reason: '§3 غير موجود');
  final String section = text.substring(start, end);

  final Set<String> keys = <String>{};
  // §2.1…§2.8 — المفتاح في العمود الأول.
  final RegExp single = RegExp(r'^\|\s*`([a-z][a-zA-Z0-9]*)`\s*\|');
  // §2.9 — عمود عربي ثم مفتاحا التعديل والإلغاء.
  final RegExp pair =
      RegExp(r'^\|[^|`]+\|\s*`([a-z][a-zA-Z0-9]*)`\s*\|\s*`([a-z][a-zA-Z0-9]*)`\s*\|');

  for (final String line in section.split('\n')) {
    if (!line.startsWith('|')) continue;
    final RegExpMatch? one = single.firstMatch(line);
    if (one != null) {
      keys.add(one.group(1)!);
      continue;
    }
    final RegExpMatch? two = pair.firstMatch(line);
    if (two != null) {
      keys..add(two.group(1)!)..add(two.group(2)!);
    }
  }
  return keys;
}

void main() {
  group('BR-M1-07: تطابق المفاتيح مع الكتالوج — في الاتجاهين', () {
    late Set<String> catalog;

    setUpAll(() => catalog = _catalogKeys());

    test('الحارس نفسه ليس فارغاً — وإلا نجح بلا أن يفحص شيئاً', () {
      // ★ حارس على الحارس: لو انكسر التحليل لعادت مجموعة فارغة **فنجح
      //   الفحصان أدناه دائماً**. هذا يمنع ذلك.
      // ★★ **81 ⟵ 82 في `WU-013`** — ★ **وفُحص عمداً كما يطلب هذا الحارس:**
      //    ⟵ **`discountBackdate` مفتاحٌ يُسمّيه `FR-M13-06` صراحةً**
      //    («**بصلاحية «خصم بتاريخ سابق»**») **ويُدرِجه `FR-M13` §4**،
      //    ⛔ **ولم يكن في الكتالوج.** ★ **ونظيرُه `receiptBackdate` قائمٌ
      //    منذ `WU-007`**: ⛔ **ولا يُغني عنه** — ⟵ **فمن يُصحِّح تاريخ
      //    قبضٍ ليس بالضرورة من يُسقِط ديناً بأثرٍ رجعي.**
      // ★★★ **و82 ⟵ 85 في `WU-014`** — ★ **وثلاثتُها يُسمّيها `FR-M22`
      //    نصّاً** ⛔ **ولا واحدةٌ منها مخترَعة:** **`expenseQatPriceNow`**
      //    (§3 و`FR-M22-08`) · **`withdrawalBackdate` و`expenseBackdate`**
      //    (`FR-M22-09` حرفياً). ★ **والعلّةُ الحاكمة `GR-43`:** «**صلاحياتُ
      //    عرضٍ وإنشاءٍ منفصلة**» للسجلَّين — ⟵ **فمفتاحٌ واحدٌ يخدمهما معاً
      //    كان يُسقِط الفصلَ الذي وُجد السجلّان لأجله.**
      expect(catalog.length, 85,
          reason: 'الكتالوج يعلن 85 مفتاحاً — فإن تغيّر العدد فُحص عمداً');
      expect(catalog, contains('sackView'));
      // ★ `IQ-021` الخيار أ — ⛔ ولا يُقاس عليه مفتاحٌ حقلي.
      expect(catalog, contains('sackCreate'));
      expect(catalog, contains('disposalCancel'));
      // ★ `IQ-032` الخيار أ — مفتاح التصدير الواحد للسندات والتقارير معاً.
      expect(catalog, contains('documentExport'));
      // ★★ **وثلاثةُ `WU-014` بأسمائها** — ⛔ **فلا يمرّ العدد وحده:**
      //    ⟵ **عددٌ صحيحٌ بمفاتيحَ خاطئة يُنجِح الحارس بلا أن يفحص شيئاً.**
      expect(catalog, contains('expenseQatPriceNow'));
      expect(catalog, contains('withdrawalBackdate'));
      expect(catalog, contains('expenseBackdate'));
    });

    test('⟵ لا مفتاح في الكود بلا سطر في المستند', () {
      expect(allPermissionKeys.difference(catalog), isEmpty);
    });

    test('⟶ ولا سطر في المستند بلا مفتاح في الكود', () {
      expect(catalog.difference(allPermissionKeys), isEmpty);
    });

    test('اسم قيمة التعداد هو المفتاح حرفياً — فلا جدول تحويل', () {
      expect(Permission.sackView.name, 'sackView');
      expect(Permission.distributionPriceView.name, 'distributionPriceView');
      // ★ **85 بعد ثلاثة `WU-014`** (`expenseQatPriceNow` ·
      //   `withdrawalBackdate` · `expenseBackdate`) — راجع الحارس أعلاه.
      expect(Permission.values.length, 85);
    });

    test('★ المفاتيح الإدارية التسعة موجودة — `IQ-007` الخيار أ', () {
      // ★ الاختبار السابق كان ينفي وجودها لأن `IQ-007` كان مفتوحاً. وقد حُسم
      //   (2026-08-22) بالخيار أ، فانقلب الفحص من نفي إلى إثبات — ⛔ ولم
      //   يُحذَف: نفس الموضع يحرس نفس الحقيقة، بعد أن تغيّرت الحقيقة نفسها.
      expect(
        identityAccessAdminPermissions.map((Permission p) => p.name).toSet(),
        <String>{
          'userView',
          'userCreate',
          'userAmend',
          'userDisable',
          'roleAssign',
          'permissionGrant',
          'sourceScopeSet',
          'roleWrite',
          'roleDelete',
        },
      );
      expect(catalog.containsAll(identityAccessAdminPermissions
          .map((Permission p) => p.name)), isTrue);
    });

    test('⛔ ولا مفتاح إداري خارج التسعة — فلا تتسع الفتحة صامتةً', () {
      // ★ نفس منطق الحارس الأصلي: أي مفتاح يحمل دلالة إدارة هوية **ولا يقع
      //   في المجموعة المسمّاة** يعني توسيعاً غير موثَّق لأخطر مسار في النظام.
      final Set<String> adminNames =
          identityAccessAdminPermissions.map((Permission p) => p.name).toSet();
      final Iterable<String> stray = allPermissionKeys.where(
        (String k) =>
            !adminNames.contains(k) &&
            (k.contains('user') ||
                k.contains('role') ||
                k.contains('permission') ||
                k.contains('scope') ||
                k.contains('grant')),
      );
      expect(stray, isEmpty,
          reason: 'مفتاح إداري خارج §2.10 — يحتاج سطراً في الكتالوج وقراراً');
    });

    test('★ والتسعة وحدها بلا شرط في قواعد الحماية — استثناء موثَّق', () {
      // ⛔ حارس على الاستثناء نفسه: عددها ثابت تسعة. أي زيادة صامتة تعني
      //   مفتاحاً جديداً هرب من بوابة التغطية بلا مبرر مكتوب.
      expect(identityAccessAdminPermissions.length, 9);
    });
  });
}

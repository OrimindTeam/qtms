/// موجّه المسارات — ★★ **حارسٌ حقيقي لا تفصيل نقل** (`IQ-019` الخيار أ).
///
/// ⚠️⚠️ **ولماذا يُختبَر بهذه الصرامة:** خطأٌ هنا **لا يُسقِط الطلب بل
/// يُسلّمه لمعالجٍ آخر** — ⟵ **فيصل «احذف الدور» إلى «امنح الصلاحيات»
/// ويردّ نجاحاً**. ★ **وهو أخطر عطلٍ ممكن في هذه الطبقة**، لأنه **ينجح
/// ظاهرياً.**
library;

import 'package:qtms_functions/src/callable.dart';
import 'package:qtms_functions/src/callable_router.dart';
import 'package:test/test.dart';

void main() {
  group('★★ IQ-019 — كل مسار معروف يرتبط بمعالجٍ واحد محدد', () {
    test('✅ كل عملية تُحلّ من مسارها حرفياً', () {
      for (final CallableOperation operation in CallableOperation.values) {
        expect(
          resolveCallableOperation('/${operation.name}'),
          operation,
          reason: 'المسار /${operation.name} لم يُحلّ إلى عمليته',
        );
      }
    });

    test('★★ والسبع والثلاثون كلها موجودة — ⛔ ولا عملية سقطت من الجدول', () {
      // ⚠️ **حارسٌ على الحارس:** جدولٌ ناقص يجعل بقية الاختبارات تنجح على
      //    مجموعة أصغر — ⟵ **ونجاحٌ لسببٍ خاطئ.**
      expect(
        CallableOperation.values.map((CallableOperation o) => o.name).toSet(),
        <String>{
          // ── الهوية والوصول (`IQ-007` · `IQ-015` · `IQ-018`) ──
          'grantPermissions',
          'setSourceScope',
          'bootstrapOwnerPermissions',
          'createUser',
          'updateUser',
          'disableUser',
          'createRole',
          'updateRole',
          'deleteRole',
          // ── البيانات المرجعية (`WU-002`) — `api-overview.md` §3.1-د ──
          'createSource',
          'updateSource',
          'createSupplier',
          'updateSupplier',
          'createDealer',
          'updateDealer',
          'createItem',
          'updateItem',
          'writeAppSettings',
          // ── المخزون والتوريد (`WU-003`) — `api-overview.md` §3.1-هـ ──
          'createCountedIntake',
          'amendCountedIntake',
          'cancelCountedIntake',
          // ── التسعير اليومي (`WU-005`) — `api-overview.md` §3.1-و ──
          'writeDailyPrices',
          // ── الوارد جواني (`WU-004`) — `api-overview.md` §3.1-ز ──
          // ★★ **سبع عمليات لا واحدة** — `FR-M7-27`: **مسار كتابةٍ منفصل
          //    لكل مجموعة حقول، ولكلٍّ صلاحيته المطابقة.**
          'createSack',
          'enterSackLines',
          'enterSackTax',
          'renameSack',
          'enterSackScrapWeight',
          'confirmSackLostWeight',
          'amendSack',
          'cancelSack',
          // ── التوزيع والضمار (`WU-006`) — `api-overview.md` §3.1 ──
          // ★★ **ثلاث عمليات** — والإلغاء **مسارٌ مستقل** لأن حارسه غير
          //    حارس التعديل: `E-15` **يمنع إلغاء ضمارٍ سُدِّد**.
          'createDistribution',
          'amendDistribution',
          'cancelDistribution',
          // ── المقبوضات وحساب المقوت (`WU-007`) — `api-overview.md` §3.1 ──
          // ★★ **أربع عمليات** — ★ **والإيداع مسارٌ مستقل تماماً** لأن
          //    `FR-M12-18` ينصّ: «**حقول الإيداع بمسار كتابة منفصل**»،
          //    ⟵ **فمن يملك تأكيد الإيداع لا يُعدِّل مبلغاً** ⛔ **والعكس.**
          'createReceipt',
          'amendReceipt',
          'cancelReceipt',
          'confirmReceiptDeposit',
        },
      );
    });

    test('★ واسم القيمة هو المسار — ⛔ فلا جدول تحويل ينزلق', () {
      expect(CallableOperation.deleteRole.path, '/deleteRole');
      expect(CallableOperation.grantPermissions.path, '/grantPermissions');
    });

    test('★ ولا عمليتان تتقاسمان مساراً', () {
      final Set<String> paths =
          CallableOperation.values.map((CallableOperation o) => o.path).toSet();
      expect(paths.length, CallableOperation.values.length);
    });
  });

  group('⛔★★★ IQ-019 القاعدة ② — المسار المجهول يُرفَض ⛔ بلا معالج افتراضي', () {
    test('⛔ مسارٌ لا وجود له', () {
      expect(resolveCallableOperation('/deleteUser'), isNull);
      expect(resolveCallableOperation('/purgeEverything'), isNull);
    });

    test('⛔★★ والجذر ليس عمليةً افتراضية', () {
      // ★★ **الحالة الأخطر:** لو ردّ الجذرُ أول عملية في القائمة **لَصار
      //    `POST <base>/` يُنفِّذ `grantPermissions`** — ⟵ **منحُ صلاحيات
      //    بطلبٍ لم يسمِّ عمليةً أصلاً.**
      expect(resolveCallableOperation('/'), isNull);
      expect(resolveCallableOperation(''), isNull);
      expect(resolveCallableOperation('///'), isNull);
    });

    test('⛔★★★ ولا يُقتطَع آخرُ مقطع من مسارٍ مركّب', () {
      // ⚠️⚠️ **وهذا بالضبط ما يمنعه نصّ القرار: «ولا يوجد توجيه ضمني».**
      //    ★ **لو اقتُطع آخرُ مقطع لَصار `/anything/deleteRole` يحذف دوراً**،
      //    ⟵ **فيصير أي بادئة مقبولة** وتضيع المطابقة التامة.
      expect(resolveCallableOperation('/v1/deleteRole'), isNull);
      expect(resolveCallableOperation('/admin/deleteRole'), isNull);
      expect(resolveCallableOperation('/deleteRole/extra'), isNull);
    });

    test('⛔★★ ولا تُطبَّع حالة الأحرف — فالمختلف مجهول', () {
      // ★ **التطبيع كان سيُخفي خطأً برمجياً في العميل** بدل أن يكشفه.
      expect(resolveCallableOperation('/deleterole'), isNull);
      expect(resolveCallableOperation('/DELETEROLE'), isNull);
      expect(resolveCallableOperation('/DeleteRole'), isNull);
    });

    test('⛔ ولا مسارٌ يحمل اسم عمليةٍ داخله', () {
      expect(resolveCallableOperation('/xdeleteRole'), isNull);
      expect(resolveCallableOperation('/deleteRoleNow'), isNull);
    });
  });

  group('★ وما يُتسامَح معه صراحةً — شرطتا الطرفين وحدهما', () {
    test('✅ بلا شرطة بادئة', () {
      expect(resolveCallableOperation('createUser'), CallableOperation.createUser);
    });

    test('✅ وبشرطة زائدة', () {
      expect(
        resolveCallableOperation('/createUser/'),
        CallableOperation.createUser,
      );
      expect(
        resolveCallableOperation('//createUser//'),
        CallableOperation.createUser,
      );
    });
  });

  group('★ رمز الرفض — ERR_CALL_404 ⛔ لا 400 ولا 500', () {
    test('★★ رمزٌ مستقل يقول «هذه العملية غير موجودة»', () {
      // ⚠️ **والتمييز عملي:** `ERR_CALL_400` تعني «حمولتك خاطئة» ⟵ **فيراجع
      //    المطوّرُ الحمولة**، **و404 تعني «المسار خاطئ»** ⟵ **فيراجع
      //    العنوان.** ⛔ **وخلطُهما يُضيّع ساعات تشخيص.**
      expect(CallableError.unknownOperation.code, 'ERR_CALL_404');
      expect(CallableError.unknownOperation.httpStatus, 404);
      expect(CallableError.unknownOperation.status, 'NOT_FOUND');
      expect(
        CallableError.unknownOperation.code,
        isNot(CallableError.invalidArgument.code),
      );
      expect(
        CallableError.unknownOperation.code,
        isNot(CallableError.internal.code),
      );
    });
  });
}

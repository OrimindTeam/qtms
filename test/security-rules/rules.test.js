/**
 * اختبارات قواعد الحماية — QTMS
 *
 * ★ قواعد الحماية هي طبقة التفويض الوحيدة (ADR-0002)، فاختبارها بند قبول
 *   لا طبقة مساعدة (test-strategy.md §2).
 *
 * ★ كل اختبار هنا **يتجاوز الواجهة ويكتب مباشرة** — لأن هذا ما يفعله المهاجم
 *   فعلاً، وهو وحده ما يُثبت أن الحماية سحابية (test-strategy.md §4 بند 6).
 *
 * يعمل على المحاكي المحلي بمعرّف مشروع وهمي `demo-qtms` — ⛔ بلا أي مشروع
 * سحابي وبلا اعتماد.
 *
 * المستندات الحاكمة:
 *   docs/01-product/product-roadmap.md §0        — الفحوص الستة
 *   docs/09-security/security-requirements.md §2 — القواعد العشر
 *   docs/09-security/permissions-catalog.md      — مفاتيح الصلاحيات
 */

import { before, after, beforeEach, describe, it } from 'node:test';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} from '@firebase/rules-unit-testing';
import {
  doc,
  collection,
  setDoc,
  updateDoc,
  deleteDoc,
  getDoc,
  getDocs,
  query,
  where,
  serverTimestamp,
} from 'firebase/firestore';

// مسارات محايدة للمنصّة — البيئة Windows وقد يعمل هذا في CI على Linux.
const HERE = dirname(fileURLToPath(import.meta.url));
const PROJECT_ROOT = join(HERE, '..', '..');

let testEnv;

/** تاريخ اليوم بتوقيت UTC عند منتصف الليل — يطابق `request.time.date()`. */
function todayUtc() {
  const n = new Date();
  return new Date(Date.UTC(n.getUTCFullYear(), n.getUTCMonth(), n.getUTCDate()));
}

function daysAgoUtc(days) {
  const d = todayUtc();
  d.setUTCDate(d.getUTCDate() - days);
  return d;
}

function tomorrowUtc() {
  const d = todayUtc();
  d.setUTCDate(d.getUTCDate() + 1);
  return d;
}

/**
 * مستخدم بصلاحيات ونطاق مصادر محددين.
 *
 * ★ ADR-0016: **الصلاحيات تُزرَع في بطاقة المستخدم لا في الرمز** — لأن
 *   `perm()` صارت تقرأ من `users/{uid}`. و`sourceScope` **يبقى في الرمز**.
 * ⚠️ ولهذا صارت الدالة `async`: زرع البطاقة كتابةٌ فعلية على المحاكي.
 */
async function as(permissions, sourceScope = ['SRC-001']) {
  await seedUserCard('USR-0001', permissions);
  return testEnv
    .authenticatedContext('USR-0001', { sourceScope })
    .firestore();
}

/** المالك: كل الصلاحيات + كل المصادر. لإثبات أن الممنوع ممنوع حتى عليه. */
async function asOwner() {
  return await asOwnerWith(allPermissionsMap());
}

/** المالك بقائمة صلاحيات صريحة. */
async function asOwnerWith(permissions) {
  await seedUserCard('USR-OWNER', permissions);
  return testEnv
    .authenticatedContext('USR-OWNER', { sourceScope: 'all' })
    .firestore();
}

/**
 * ★ يزرع بطاقة المستخدم متجاوزاً القواعد — تحضير لا اختبار.
 * ⛔ `users` مغلقة للكتابة تماماً (`allow write: if false`)، فلا سبيل غيره.
 */
async function seedUserCard(uid, permissions, isActive = true) {
  await seed(async (db) => {
    await setDoc(doc(db, 'users', uid), {
      permissions: permissions ?? {},
      // ★★ IQ-017: `perm()` تشترط `isActive == true`، ⟵ **فالبطاقة بلا هذا
      //    الحقل بطاقةٌ بلا صلاحية إطلاقاً**. والافتراضي هنا `true` لأن
      //    الغالبية العظمى من الاختبارات تختبر مستخدماً **حيّاً**؛
      //    ⛔ **والحالة المعطَّلة تُمرَّر صراحةً** فلا تمرّ سهواً.
      isActive,
    });
  });
}

/**
 * ★ كل مفاتيح الكتالوج مضبوطة `true` — بديل `Proxy` الذي كان يعمل في
 *   المطالبات ولا يعمل في مستند حقيقي.
 * ⚠️ تُقرأ من الكتالوج نفسه لا مكتوبة يدوياً — فلا تفترق نسختان.
 */
function allPermissionsMap() {
  const md = readFileSync(
    join(PROJECT_ROOT, 'docs', '09-security', 'permissions-catalog.md'),
    'utf8',
  );
  const section = md.split('## 2. الكتالوج المعتمد')[1].split('\n## 3.')[0];
  const map = {};
  let inAmendTable = false;
  for (const line of section.split('\n')) {
    if (line.startsWith('### ')) inAmendTable = line.includes('2.9');
    if (!line.trim().startsWith('|')) continue;
    const cells = line.split('|').map((c) => c.trim());
    for (const cell of inAmendTable ? [cells[2], cells[3]] : [cells[1]]) {
      const m = /^`([a-z][a-zA-Z0-9]*)`$/.exec(cell ?? '');
      if (m) map[m[1]] = true;
    }
  }
  return map;
}

function anonymous() {
  return testEnv.unauthenticatedContext().firestore();
}

/** زرع بيانات بتجاوز القواعد — للتحضير فقط، لا للاختبار. */
async function seed(fn) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await fn(ctx.firestore());
  });
}

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'demo-qtms',
    firestore: {
      rules: readFileSync(join(PROJECT_ROOT, 'firestore.rules'), 'utf8'),
      host: '127.0.0.1',
      port: 8080,
    },
  });
});

after(async () => {
  await testEnv?.cleanup();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
});

// ===========================================================================
// أولاً — الفحوص الستة من «الخطوة صفر» (product-roadmap.md §0)
//         ★ كلها من خارج التطبيق.
// ===========================================================================

describe('الخطوة صفر — معيار الاجتياز: الفحوص الستة', () => {
  it('فحص ①: كتابة مستند بلا صلاحية تُرفض', async () => {
    const db = await as({}); // لا صلاحية إطلاقاً
    await assertFails(
      setDoc(doc(db, 'sources/SRC-001'), {
        name: 'رداع',
        normalizedName: 'رداع',
        isActive: true,
        createdAt: serverTimestamp(),
      }),
    );
  });

  it('فحص ②: كتابة رصيد (تعديل مباشر على الأرصدة) تُرفض — حتى للمالك', async () => {
    await seed(async (db) => {
      await setDoc(doc(db, 'item_daily_balances/SRC-001_ITM-0001_2026-08-21'), {
        sourceId: 'SRC-001',
        balance: 10,
        unit: 'piece',
      });
    });
    // ⛅ الأرصدة تكتبها المعاملة الذرّية أو السحابة — لا التطبيق، ولو رصيداً موجباً.
    const db = await asOwnerWith({ sourceWrite: true, itemWrite: true });
    await assertFails(
      updateDoc(
        doc(db, 'item_daily_balances/SRC-001_ITM-0001_2026-08-21'),
        { balance: -5 },
      ),
    );
    await assertFails(
      updateDoc(
        doc(db, 'item_daily_balances/SRC-001_ITM-0001_2026-08-21'),
        { balance: 99 },
      ),
    );
  });

  it('فحص ③: كتابة مستند بمصدر خارج النطاق تُرفض', async () => {
    const db = await as({ incomingCountWrite: true }, ['SRC-001']);
    await assertFails(
      setDoc(doc(db, 'incoming_count/INC-1'), {
        sourceId: 'SRC-999', // خارج النطاق
        stockDate: todayUtc(),
        entryDate: serverTimestamp(),
        lines: [],
        status: 'approved',
      }),
    );
  });

  it('فحص ⑤: حذف حركة يُرفض — لأي مستخدم بمن فيهم المالك', async () => {
    await seed(async (db) => {
      await setDoc(doc(db, 'incoming_count/INC-1'), { sourceId: 'SRC-001' });
      await setDoc(doc(db, 'inventory_ledger/L-1'), { sourceId: 'SRC-001' });
      await setDoc(doc(db, 'distributions/MQT-0001_SRC-001_2026-08-21'), {
        sourceId: 'SRC-001',
      });
      await setDoc(doc(db, 'audit_log/A-1'), { sourceId: 'SRC-001' });
    });
    const owner = await asOwnerWith({
      incomingCountCancel: true,
      distributionCancel: true,
      auditLogViewCentral: true,
    });
    await assertFails(deleteDoc(doc(owner, 'incoming_count/INC-1')));
    await assertFails(deleteDoc(doc(owner, 'inventory_ledger/L-1')));
    await assertFails(
      deleteDoc(doc(owner, 'distributions/MQT-0001_SRC-001_2026-08-21')),
    );
    await assertFails(deleteDoc(doc(owner, 'audit_log/A-1')));
  });

  it('فحص ⑥: التطبيق لا يكتب الترقيم — الرقم المتسلسل للجونية سحابي حصراً', async () => {
    const db = await as({ incomingCountWrite: true, sackView: true });
    // محاولة حجز رقم من الجهاز ⟵ مرفوضة (وهي جذر تكرار الرقم عند التزامن E-43)
    await assertFails(
      setDoc(doc(db, 'sacks/SCK-1'), {
        sourceId: 'SRC-001',
        stockDate: todayUtc(),
        entryDate: serverTimestamp(),
        dailySequence: 1, // ⛅ سحابي
        totalWeight: 100,
      }),
    );
    await assertFails(
      setDoc(doc(db, 'sacks/SCK-2'), {
        sourceId: 'SRC-001',
        stockDate: todayUtc(),
        entryDate: serverTimestamp(),
        documentNumber: 'SCK-20260821-0001', // ⛅ سحابي
        totalWeight: 100,
      }),
    );
    // ⛔ وقراءة العدّادات مرفوضة للجميع
    await assertFails(getDoc(doc(db, 'daily_sack_counters/SRC-001_2026-08-21')));
    await assertFails(getDoc(doc(db, 'document_counters/sack')));
  });
});

// ===========================================================================
// ثانياً — القواعد العشر السارية على كل السجلات
//          (security-requirements.md §2)
// ===========================================================================

describe('القواعد العشر السارية على كل السجلات', () => {
  it('القاعدة 6: الرفض الافتراضي — مسار غير معرَّف مرفوض', async () => {
    const db = await asOwnerWith({ sourceWrite: true });
    await assertFails(getDoc(doc(db, 'anything_unknown/X-1')));
    await assertFails(setDoc(doc(db, 'anything_unknown/X-1'), { a: 1 }));
  });

  it('القاعدة 7: غير المصادَق مرفوض في كل شيء', async () => {
    const db = anonymous();
    await assertFails(getDoc(doc(db, 'sources/SRC-001')));
    await assertFails(setDoc(doc(db, 'sources/SRC-001'), { name: 'x' }));
    await assertFails(getDoc(doc(db, 'audit_log/A-1')));
  });

  it('القاعدة 3: وقت الجهاز مرفوض — ★★ والإنفاذ انتقل إلى الدالة الكاتبة', async () => {
    // ⚠️⚠️ **تغيّر موضع الإنفاذ لا التزامُ القاعدة (WU-002):** كانت القاعدة
    //    تفرض `serverTime('createdAt')` على `sources`، ⛔ **ثم أُغلقت
    //    الكتابة المباشرة** فلم يعد للقاعدة ما تفحصه. ★ **والشرط نفسه صار
    //    بند قبولٍ في `master_data.dart`** — `serverTimestampFields` بتحويل
    //    `REQUEST_TIME` (اختباره: `functions/test/master_data_test.dart`).
    //
    // ⛔ **وما يبقى للقاعدة إثباتُه هنا: لا وقتَ جهازٍ يمرّ لأن لا كتابة تمرّ.**
    const db = await as({ sourceWrite: true });
    await assertFails(
      setDoc(doc(db, 'sources/SRC-002'), {
        name: 'ذمار',
        normalizedName: 'ذمار',
        isActive: true,
        createdAt: new Date(2020, 0, 1),
      }),
    );
    // ★★ **وحتى بتوقيت الخادم يُرفَض** — ⟵ **فالمسار مغلق لا مشروط.**
    await assertFails(
      setDoc(doc(db, 'sources/SRC-002'), {
        name: 'ذمار',
        normalizedName: 'ذمار',
        isActive: true,
        createdAt: serverTimestamp(),
      }),
    );
  });

  it('القاعدة 8: منح الصلاحيات من التطبيق ممنوع — ولو للمالك', async () => {
    await seed(async (db) => {
      await setDoc(doc(db, 'users/USR-0002'), {
        name: 'موظف',
        permissions: { sourceWrite: false },
        sourceScope: ['SRC-001'],
      });
    });
    const owner = await asOwnerWith({ appSettingsWrite: true, sourceWrite: true });
    await assertFails(
      updateDoc(doc(owner, 'users/USR-0002'), {
        permissions: { sourceWrite: true },
      }),
    );
    await assertFails(
      updateDoc(doc(owner, 'users/USR-0002'), { sourceScope: 'all' }),
    );
    await assertFails(setDoc(doc(owner, 'roles/ROLE-1'), { name: 'مدير' }));
  });

  it('القاعدة 2 + القاعدة 10: سجل التدقيق لا يُكتب ولا يُعدَّل ولا يُمسح', async () => {
    await seed(async (db) => {
      await setDoc(doc(db, 'audit_log/A-1'), {
        sourceId: 'SRC-001',
        action: 'create',
        reason: 'أصلي',
      });
    });
    const owner = await asOwnerWith({
      auditLogViewCentral: true,
      auditLogViewContextual: true,
    });
    // القراءة بصلاحيتها ⟵ مقبولة
    await assertSucceeds(getDoc(doc(owner, 'audit_log/A-1')));
    // ⛔ والكتابة والتعديل والمسح مرفوضة مطلقاً
    await assertFails(setDoc(doc(owner, 'audit_log/A-2'), { action: 'x' }));
    await assertFails(updateDoc(doc(owner, 'audit_log/A-1'), { reason: 'مزوَّر' }));
    await assertFails(deleteDoc(doc(owner, 'audit_log/A-1')));
  });

  it('سجل تعديلات المستندات لا يُكتب من التطبيق', async () => {
    const owner = await asOwnerWith({ auditLogViewCentral: true });
    await assertFails(
      setDoc(doc(owner, 'document_amendments/AM-1'), {
        sourceId: 'SRC-001',
        reason: 'سبب',
      }),
    );
  });
});

// ===========================================================================
// ثالثاً — نطاق المصادر: قيد يعلو على كل صلاحية (GR-23)
// ===========================================================================

describe('نطاق المصادر — قيد أمني لا فلتر عرض', () => {
  beforeEach(async () => {
    await seed(async (db) => {
      await setDoc(doc(db, 'distributions/MQT-0001_SRC-999_2026-08-21'), {
        sourceId: 'SRC-999',
        dealerId: 'MQT-0001',
        // ⛔ لا debtValue في الأب — ADR-0011. البذرة تتخطّى القواعد، فلا
        //    تُفشِل الاختبار، لكن شكلها يجب أن يطابق المخطَّط المعتمد.
      });
      await setDoc(doc(db, 'inventory_ledger/L-999'), { sourceId: 'SRC-999' });
    });
  });

  it('قراءة مستند خارج النطاق تُرفض ولو ملك كل الصلاحيات', async () => {
    const db = await as(
      { distributionCreate: true, distributionPriceView: true },
      ['SRC-001'],
    );
    await assertFails(
      getDoc(doc(db, 'distributions/MQT-0001_SRC-999_2026-08-21')),
    );
    await assertFails(getDoc(doc(db, 'inventory_ledger/L-999')));
  });

  it("sourceScope = 'all' يقرأ أي مصدر — بما فيه الجديد", async () => {
    const db = await as({ distributionCreate: true }, 'all');
    await assertSucceeds(
      getDoc(doc(db, 'distributions/MQT-0001_SRC-999_2026-08-21')),
    );
  });

  it('القائمة المحددة لا يُضاف لها المصدر الجديد تلقائياً', async () => {
    const db = await as({ distributionCreate: true }, ['SRC-001', 'SRC-002']);
    await assertFails(
      getDoc(doc(db, 'distributions/MQT-0001_SRC-999_2026-08-21')),
    );
  });
});

// ===========================================================================
// رابعاً — المسارات المقيَّدة: الصلاحية على الحقل لا على المستند
//          (security-requirements.md §3)
// ===========================================================================

describe('المسارات المقيَّدة على الجونية', () => {
  beforeEach(async () => {
    await seed(async (db) => {
      await setDoc(doc(db, 'sacks/SCK-1'), {
        sourceId: 'SRC-001',
        documentNumber: 'SCK-20260821-0001',
        dailySequence: 7,
        displayName: 'جونية رقم 7',
        stockDate: todayUtc(),
        entryDate: new Date(),
        totalWeight: 100,
        iceWeight: 2,
        scrapWeight: 3,
        lines: [],
        status: 'approved',
      });
    });
  });

  it('⛔ ADR-0011: المستند الأب يرفض أي حقل مالي', async () => {
    const db = await as({ sackView: true, sackTaxEnterNow: true, sackAmend: true });
    for (const field of ['taxPerKilo', 'sackTax', 'sackRevenue', 'supplierNet']) {
      await assertFails(
        updateDoc(doc(db, 'sacks/SCK-1'), {
          [field]: 50,
          amendReason: 'محاولة كتابة حقل مالي في الأب',
        }),
      );
    }
  });

  it('★ من يملك إدخال الضريبة لا يستطيع تعديل اسم الجونية', async () => {
    const db = await as({ sackView: true, sackTaxEnterNow: true });
    await assertFails(
      updateDoc(doc(db, 'sacks/SCK-1'), { displayName: 'اسم آخر' }),
    );
  });

  it('★ من يملك إدخال الضريبة لا يستطيع تعديل السطور', async () => {
    const db = await as({ sackView: true, sackTaxEnterNow: true });
    await assertFails(
      updateDoc(doc(db, 'sacks/SCK-1'), { lines: [{ itemId: 'ITM-0001' }] }),
    );
  });

  it('قراءة الجونية تحتاج صلاحية عرض الجواني', async () => {
    await assertFails(getDoc(doc(await as({}), 'sacks/SCK-1')));
    await assertSucceeds(getDoc(doc(await as({ sackView: true }), 'sacks/SCK-1')));
  });
});

// ===========================================================================
// خامساً — صلاحيات العرض تُخفي لا تُعطّل (security-requirements.md §4)
// ===========================================================================

describe('صلاحيات العرض — شرط قراءة في القاعدة لا في الواجهة', () => {
  beforeEach(async () => {
    await seed(async (db) => {
      await setDoc(doc(db, 'outflow_ledger/OL-W'), {
        sourceId: 'SRC-001',
        ledgerType: 'withdrawal',
        amount: 5000,
      });
      await setDoc(doc(db, 'outflow_ledger/OL-E'), {
        sourceId: 'SRC-001',
        ledgerType: 'expense',
        amount: 3000,
      });
      await setDoc(doc(db, 'supplier_balances/SUP-0001_SRC-001'), {
        sourceId: 'SRC-001',
        net: 120000,
      });
      await setDoc(doc(db, 'dealer_balances/MQT-0001_SRC-001'), {
        balance: 88000,
      });
      await setDoc(doc(db, 'daily_summaries/SRC-001_2026-08-21'), {
        sourceId: 'SRC-001',
        date: todayUtc(),
      });
      await setDoc(doc(db, 'daily_summaries/all_2026-08-21'), {
        sourceId: 'all',
        date: todayUtc(),
      });
    });
  });

  it('★ من لا يملك عرض السحبيات لا يقرأ سطر سحبية — ولو من خارج التطبيق', async () => {
    const db = await as({ expenseView: true }); // يملك الخرجيات فقط
    await assertFails(getDoc(doc(db, 'outflow_ledger/OL-W')));
    await assertSucceeds(getDoc(doc(db, 'outflow_ledger/OL-E')));
  });

  it('عرض مالية الرعوي شرط قراءة مستقل', async () => {
    await assertFails(
      getDoc(doc(await as({}), 'supplier_balances/SUP-0001_SRC-001')),
    );
    await assertSucceeds(
      getDoc(
        doc(await as({ supplierFinanceView: true }), 'supplier_balances/SUP-0001_SRC-001'),
      ),
    );
  });

  it('عرض أرصدة المقاوته شرط قراءة مستقل', async () => {
    await assertFails(getDoc(doc(await as({}), 'dealer_balances/MQT-0001_SRC-001')));
    await assertSucceeds(
      getDoc(doc(await as({ dealerBalanceView: true }), 'dealer_balances/MQT-0001_SRC-001')),
    );
  });

  it('★ بطاقة «كل المصادر» تحتاج صلاحيتها المستقلة', async () => {
    const partial = await as({ ownerLedgerView: true }, 'all');
    await assertSucceeds(getDoc(doc(partial, 'daily_summaries/SRC-001_2026-08-21')));
    await assertFails(getDoc(doc(partial, 'daily_summaries/all_2026-08-21')));

    const full = await as({ ownerLedgerView: true, allSourcesCardView: true }, 'all');
    await assertSucceeds(getDoc(doc(full, 'daily_summaries/all_2026-08-21')));
  });
});

// ===========================================================================
// خامساً-ب — ADR-0011: عزل الحقول الحسّاسة في مستندات فرعية
//            ★ هذا ما يجعل «الحقول لا تظهر أصلاً» حقيقةً في القاعدة
//              لا تجميلاً في الواجهة (security-requirements.md §4).
// ===========================================================================

describe('ADR-0011 — عزل الحقول المالية بشرط قراءة مستقل', () => {
  beforeEach(async () => {
    await seed(async (db) => {
      await setDoc(doc(db, 'distributions/MQT-0001_SRC-001_2026-08-21'), {
        dealerId: 'MQT-0001',
        sourceId: 'SRC-001',
        stockDate: todayUtc(),
        lines: [{ itemKey: 'ITM-0001', quantity: 10, unit: 'piece' }],
        unpricedLineCount: 0,
        totalPieces: 10,
        status: 'priced',
      });
      await setDoc(
        doc(db, 'distributions/MQT-0001_SRC-001_2026-08-21/pricing/current'),
        { sourceId: 'SRC-001', unitPrices: [500], lineTotals: [5000], debtValue: 5000 },
      );
      await setDoc(doc(db, 'sacks/SCK-9'), {
        sourceId: 'SRC-001',
        dailySequence: 3,
        stockDate: todayUtc(),
        totalWeight: 100,
        lines: [],
      });
      await setDoc(doc(db, 'sacks/SCK-9/finance/current'), {
        sourceId: 'SRC-001',
        taxPerKilo: 50,
        sackTax: 5000,
        sackRevenue: 120000,
        supplierNet: 115000,
      });
    });
  });

  const P = 'distributions/MQT-0001_SRC-001_2026-08-21';

  it('★ من يقرأ التوزيعة بلا صلاحية السعر لا يرى الأسعار إطلاقاً', async () => {
    const db = await as({ distributionCreate: true }); // بلا distributionPriceView
    // الكميات مقروءة
    await assertSucceeds(getDoc(doc(db, P)));
    // ⛔ والأسعار لا — ولو كتب المسار مباشرةً متجاوزاً الواجهة
    await assertFails(getDoc(doc(db, `${P}/pricing/current`)));
  });

  it('ومن يملكها يقرأ الأسعار', async () => {
    const db = await as({ distributionCreate: true, distributionPriceView: true });
    await assertSucceeds(getDoc(doc(db, `${P}/pricing/current`)));
  });

  it('★ صلاحية السعر لا تتجاوز نطاق المصادر', async () => {
    const db = await as({ distributionPriceView: true }, ['SRC-002']);
    await assertFails(getDoc(doc(db, `${P}/pricing/current`)));
  });

  it('⛔ المستند الأب يرفض debtValue — وإلا سُرِّب المبلغ ضمناً', async () => {
    const db = await as({ distributionCreate: true, distributionAmend: true });
    await assertFails(
      updateDoc(doc(db, P), { debtValue: 5000, amendReason: 'محاولة تسريب' }),
    );
  });

  it('★ مالية الجونية لا تُقرأ إلا بصلاحيتها — وعرض الجونية لا يكفي', async () => {
    const viewOnly = await as({ sackView: true });
    await assertSucceeds(getDoc(doc(viewOnly, 'sacks/SCK-9')));
    await assertFails(getDoc(doc(viewOnly, 'sacks/SCK-9/finance/current')));

    const finance = await as({ sackView: true, sackFinanceView: true });
    await assertSucceeds(getDoc(doc(finance, 'sacks/SCK-9/finance/current')));
  });

  it('⛔ والإيراد والصافي لا يكتبهما التطبيق ولو في مستند المالية', async () => {
    const db = await as({ sackView: true, sackTaxEnterNow: true, sackFinanceView: true });
    await assertFails(
      updateDoc(doc(db, 'sacks/SCK-9/finance/current'), { sackRevenue: 999999 }),
    );
    await assertFails(
      updateDoc(doc(db, 'sacks/SCK-9/finance/current'), { supplierNet: 999999 }),
    );
  });

  it('⛔ ولا حذف لأي من المستندين الفرعيين', async () => {
    const owner = await asOwnerWith({
      distributionPriceView: true,
      distributionPriceClear: true,
      sackFinanceView: true,
      sackTaxEnterNow: true,
    });
    await assertFails(deleteDoc(doc(owner, `${P}/pricing/current`)));
    await assertFails(deleteDoc(doc(owner, 'sacks/SCK-9/finance/current')));
  });
});

// ===========================================================================
// سادساً — قواعد عمل مُنفَّذة في طبقة الحماية
// ===========================================================================

describe('قواعد عمل مفروضة في القاعدة لا في الواجهة', () => {
  it('⛔ التاريخ المستقبلي مرفوض مطلقاً — لأي صلاحية', async () => {
    const db = await as({ receiptCreate: true, receiptBackdate: true });
    await assertFails(
      setDoc(doc(db, 'receipts/RCP-1'), {
        dealerId: 'MQT-0001',
        date: tomorrowUtc(),
        lines: [],
        isDeposited: false,
      }),
    );
  });

  it('★ المصدر إلزامي في السحبيات — حتى لسحبيات المالك', async () => {
    const db = await as({ withdrawalCreate: true, withdrawalQatPriceNow: true }, 'all');
    await assertFails(
      setDoc(doc(db, 'outflows/WDR-2'), {
        ledgerType: 'withdrawal',
        date: todayUtc(),
        lines: [],
        unpricedItemCount: 0,
      }),
    );
  });

  it('⛅ النوع: لا سعر ولا تغيير وحدة — ★ والإنفاذ في الدالة الكاتبة', async () => {
    // ★ **ما تفرضه القاعدة اليوم: لا كتابة أصلاً** — ⟵ **فسعرٌ ووحدةٌ
    //   وسكربٌ كلها مرفوضة بالتبعية.** ★ **وتفصيلها مُختبَر في**
    //   `functions/test/master_data_test.dart` (`ERR_SETUP_008` · `009`).
    await seed(async (db) => {
      await setDoc(doc(db, 'items/ITM-0002'), {
        name: 'عادي', normalizedName: 'عادي', nature: 'countBased',
        unit: 'piece', isActive: true,
      });
    });
    const db = await as({ itemWrite: true });
    await assertFails(
      setDoc(doc(db, 'items/ITM-0001'), {
        name: 'سكرب',
        normalizedName: 'سكرب',
        nature: 'weightBased',
        unit: 'kilogram',
        distributionPrice: 100, // ⛔
      }),
    );
    // ★★ **وحمولةٌ سليمة تماماً تُرفَض كذلك** — ⟵ **فالإغلاق لا الشرط.**
    await assertFails(
      setDoc(doc(db, 'items/ITM-0003'), {
        name: 'عادي2', normalizedName: 'عادي2', nature: 'countBased',
        unit: 'piece', isActive: true,
      }),
    );
    await assertFails(updateDoc(doc(db, 'items/ITM-0002'), { unit: 'kilogram' }));
    // ✅ **والقراءة لم تُمَسّ** — `ADR-0013` القاعدة 4.
    await assertSucceeds(getDoc(doc(db, 'items/ITM-0002')));
  });

  it('⛅ الإعداد التأسيسي: لا كتابة من التطبيق · والقراءة متاحة (FR-M21-10)', async () => {
    await seed(async (db) => {
      await setDoc(doc(db, 'app_settings/business'), { businessName: 'وكالة محمد المحامي' });
    });
    const db = await as({ appSettingsWrite: true }, 'all');
    // ⛔★★ **حتى المفتاحان المعتمدان مرفوضان** — «مرة واحدة» تفرضها الدالة
    //    داخل معاملةٍ تقرأ المستندين، ⛔ **ولا تفرضها القاعدة** (`AT-65`).
    await assertFails(
      setDoc(doc(db, 'app_settings/formatting'), { currencySymbol: 'ر.ي' }),
    );
    await assertFails(setDoc(doc(db, 'app_settings/other'), { x: 1 }));
    await assertFails(
      updateDoc(doc(db, 'app_settings/business'), { businessName: 'اسم آخر' }),
    );
    // ✅ **والقراءة متاحة للجميع** — `FR-M21-10`.
    await assertSucceeds(getDoc(doc(db, 'app_settings/business')));
  });
});

// ===========================================================================
// ★ ADR-0015 — كل مبلغ عدد صحيح بالريال
//    القاعدة هي الإنفاذ الحقيقي (ADR-0002)، فالتحقق في التطبيق وحده
//    ⬛️ لا يُعتبر تنفيذاً. وهذه الاختبارات تكتب مباشرةً متجاوزةً الواجهة.
// ===========================================================================

describe('★ ADR-0015 — المبالغ أعداد صحيحة، والقاعدة ترفض الكسر', () => {
});

// ===========================================================================
// ★ ADR-0016 — الصلاحيات خرجت من الرمز إلى بطاقة المستخدم
//   ⛔ هذه الاختبارات تُثبت أن التحويل **فعلي لا شكلي**.
// ===========================================================================

describe('★ ADR-0016 — مصدر الصلاحية هو `users/{uid}` لا رمز الدخول', () => {
  const PATH = 'incoming_count/INC-ADR16';

  function payload() {
    return {
      sourceId: 'SRC-001',
      stockDate: todayUtc(),
      entryDate: serverTimestamp(),
      itemId: 'ITM-1',
      quantity: 5,
    };
  }

  it('★★ صلاحية في الرمز وحده **لم تعد تُقبل** — وهذا دليل التحويل', async () => {
    // ⚠️ النموذج القديم حرفياً: المفتاح في المطالبات ولا بطاقة للمستخدم.
    //    لو بقي مقبولاً لكان ADR-0016 غير مُنفَّذ فعلياً.
    const db = testEnv
      .authenticatedContext('USR-CLAIMS-ONLY', {
        permissions: { incomingCountWrite: true },
        sourceScope: ['SRC-001'],
      })
      .firestore();
    await assertFails(setDoc(doc(db, PATH), payload()));
  });

  it('⛔ وغياب بطاقة المستخدم أصلاً = لا صلاحية إطلاقاً', async () => {
    // ★ التبعية المعلَنة في ADR-0016: حذف البطاقة يُسقِط كل الصلاحيات فوراً.
    const db = testEnv
      .authenticatedContext('USR-NO-CARD', { sourceScope: ['SRC-001'] })
      .firestore();
    await assertFails(setDoc(doc(db, PATH), payload()));
  });

  it('⛔ وبطاقة بلا حقل `permissions` تُعامَل رفضاً لا سماحاً', async () => {
    await seed(async (db) => {
      await setDoc(doc(db, 'users', 'USR-0001'), { name: 'بلا صلاحيات' });
    });
    const db = testEnv
      .authenticatedContext('USR-0001', { sourceScope: ['SRC-001'] })
      .firestore();
    await assertFails(setDoc(doc(db, PATH), payload()));
  });

  it('✅ والبطاقة الصحيحة تسمح — فالمسار الجديد يعمل لا يمنع كل شيء', async () => {
    // ⚠️⚠️ **على شرط قراءةٍ حقيقي بعد WU-002:** لم تبقَ مجموعةٌ مفتوحة
    //    الكتابة للتطبيق إطلاقاً، ⟵ **فالضابط الموجب الوحيد الباقي قراءةٌ
    //    تشترط مفتاحاً**. ★ **وهو يُثبت المطلوب نفسه:** البطاقة تمنح فعلاً
    //    ⛔ **ولا تمنع كل شيء.**
    await seed(async (d) => {
      await setDoc(doc(d, 'dealer_balances/MQT-0001_SRC-001'), {
        dealerId: 'MQT-0001', sourceId: 'SRC-001', balance: 0,
      });
    });
    const db = await as({ dealerBalanceView: true }, ['SRC-001']);
    await assertSucceeds(getDoc(doc(db, 'dealer_balances/MQT-0001_SRC-001')));
  });

  it('★ و`sourceScope` ما يزال يُقرأ من الرمز — لم يُمَسّ (ADR-0016)', async () => {
    // ★ **على القراءة بعد WU-002** — والنطاق شرطٌ في `match /sources`.
    await seed(async (d) => {
      await setDoc(doc(d, 'sources/SRC-001'), { name: 'مصدر' });
    });
    // ⛔ خارج النطاق ⟵ حتى القراءة تُرفَض.
    const outside = await as({ sourceWrite: true }, ['SRC-999']);
    await assertFails(getDoc(doc(outside, 'sources/SRC-001')));
    // ✅ وداخله ⟵ تُقبل. ⟵ **فالفرق هو النطاق وحده لا شيء آخر.**
    const inside = await as({ sourceWrite: true }, ['SRC-001']);
    await assertSucceeds(getDoc(doc(inside, 'sources/SRC-001')));
  });

  it('⛔⛔★★★ IQ-024 — سردُ `sources` يعمل لصاحب النطاق الشامل (لا `get` وحده)', async () => {
    // ★★★ **اختبارُ ارتدادٍ لعطلٍ حقيقي رُصد على المحاكي (2026-08-26):**
    //    الشرط كان `allow read: … inScope(sourceId)` ⟵ **يعمل لمستندٍ واحد
    //    ويسقط للاستعلام**، ⛔ **فكان منتقي المصدر فارغاً دائماً في كل شاشة.**
    //
    // ⚠️⚠️ **ولم يكشفه 226 اختباراً:** ★ **كلُّ اختبارات `sources` كانت
    //    `getDoc`** ⛔ **ولا واحدَ `getDocs`** — ⟵ **فالفجوة بين ما تختبره
    //    القواعد وما يفعله التطبيق فعلاً** (`watchSources()` استعلامُ مجموعة).
    await seed(async (d) => {
      await setDoc(doc(d, 'sources/SRC-001'), { name: 'مصدر' });
      await setDoc(doc(d, 'sources/SRC-002'), { name: 'مصدر ثانٍ' });
    });

    // ✅ النطاق الشامل ⟵ السرد يمرّ.
    const all = await as({ sourceWrite: true }, 'all');
    await assertSucceeds(getDocs(collection(all, 'sources')));

    // ⛔ والنطاق المحدود ⟵ السرد يبقى مرفوضاً (كحاله — ولا انحدار).
    const scoped = await as({ sourceWrite: true }, ['SRC-001']);
    await assertFails(getDocs(collection(scoped, 'sources')));
    // ★ **ومستندُه داخل نطاقه يبقى مقروءاً** — ⟵ فالفصل لم يكسر `get`.
    await assertSucceeds(getDoc(doc(scoped, 'sources/SRC-001')));
    // ⛔ **وخارجَه يبقى مرفوضاً** — ★ **فالنطاق ما يزال هو الحارس.**
    await assertFails(getDoc(doc(scoped, 'sources/SRC-002')));
  });
});

// ===========================================================================
// ★★ ADR-0013 القاعدة 2 — الكتابة المباشرة مغلقة على كل مجموعة تمسّ المال
//    أو المخزون. والكتابة تمرّ حصراً عبر دالة سحابية تكتب المستند وقيد
//    التدقيق **في معاملة واحدة**.
//
// ⚠️⚠️ ما فُقد من هذا الملف ولماذا — يُقال صراحةً ولا يُدفَن:
//    ستة عشر اختباراً كانت تُثبت **قواعد عمل على مسار الكتابة** (السبب النصي ·
//    `GR-18` المعرّف المركّب · التاريخ السابق · المسارات المقيَّدة على الجونية ·
//    الحقول الفائضة · ★ **و`ADR-0015` أن كل مبلغ عدد صحيح**) — أُزيلت لأن
//    القاعدة **لم تعد تفرض أياً منها**، وإبقاؤها كان سيجعلها تنجح **لسبب
//    خاطئ**: كل كتابة مرفوضة الآن، فالاختبار يمرّ بلا أن يختبر شيئاً.
//
// ⛔ **وهذه ليست تغطية أُسقطت بل تغطية انتقلت:** القيود كلها مواصفةُ قبولٍ
//    مُلزِمة لكل دالة كاتبة في `DEBT-21` — ونصّها محفوظ تعليقاً داخل
//    `firestore.rules` نفسه في مواضعه.
// ===========================================================================

describe('★★ ADR-0013 — الكتابة مغلقة في القواعد على مجموعات المال والمخزون', () => {
  // مجموعة → حمولة إنشاء معقولة. المحتوى لا يهمّ: المسار مغلق أياً كان.
  const CLOSED = {
    incoming_count: { sourceId: 'SRC-001', quantity: 5 },
    sacks: { sourceId: 'SRC-001', displayName: 'جونية' },
    daily_prices: { sourceId: 'SRC-001', pricePerKilo: 1200 },
    distributions: { sourceId: 'SRC-001', dealerId: 'MQT-0001' },
    cash_sales: { sourceId: 'SRC-001', amount: 500 },
    receipts: { dealerId: 'MQT-0001', amount: 500 },
    discounts: { dealerId: 'MQT-0001', amount: 100 },
    outflows: { sourceId: 'SRC-001', ledgerType: 'withdrawal' },
    stocktakes: { sourceId: 'SRC-001', reason: 'جرد' },
    disposals: { sourceId: 'SRC-001', reason: 'تلف' },
    // ★★ WU-002 — البيانات المرجعية وسجلات حراسة تفرّدها.
    sources: { name: 'مصدر', normalizedName: 'مصدر' },
    suppliers: { name: 'رعوي', normalizedPhone: '777000111' },
    dealers: { name: 'مقوت', normalizedPhone: '777000222' },
    items: { name: 'نوع', normalizedName: 'نوع', unit: 'piece' },
    app_settings: { businessName: 'وكالة' },
    unique_source_names: { entityId: 'SRC-001' },
    unique_supplier_phones: { entityId: 'SUP-0001' },
    unique_dealer_phones: { entityId: 'MQT-0001' },
    unique_item_names: { entityId: 'ITM-0001' },
  };

  for (const [coll, data] of Object.entries(CLOSED)) {
    it(`⛅ ${coll} — الإنشاء مرفوض ولو بكل الصلاحيات ونطاق كل المصادر`, async () => {
      // ★ المالك بكل المفاتيح: لو بقي مسارٌ مفتوح لظهر هنا.
      const owner = await asOwner();
      await assertFails(setDoc(doc(owner, `${coll}/DOC-CLOSED-1`), data));
    });

    it(`⛅ ${coll} — والتعديل مرفوض كذلك`, async () => {
      await seed(async (db) => {
        await setDoc(doc(db, `${coll}/DOC-CLOSED-2`), data);
      });
      const owner = await asOwner();
      await assertFails(
        updateDoc(doc(owner, `${coll}/DOC-CLOSED-2`), { touched: true }),
      );
    });
  }

  it('★ والمجموعتان الماليتان الفرعيتان مغلقتان أيضاً (ADR-0011)', async () => {
    const owner = await asOwner();
    await assertFails(
      setDoc(doc(owner, 'sacks/SCK-1/finance/current'), { sackTax: 100 }),
    );
    await assertFails(
      setDoc(doc(owner, 'distributions/D-1/pricing/current'), { debtValue: 100 }),
    );
  });

  it('✅⛔ والقراءة لم تُمَسّ — فالإغلاق على الكتابة وحدها (ADR-0013 القاعدة 4)', async () => {
    // ⚠️⚠️ **هذا هو الضابط الذي يمنع نجاحاً لسبب خاطئ بعد WU-002:** لمّا
    //    أُغلقت كل مسارات الكتابة صار «كلُّ شيء مرفوض» تفسيراً محتملاً
    //    لنجاح الاختبارات أعلاه. ⟵ ★ **وهذا يُثبت أن الرفض على الكتابة
    //    وحدها**، ⛔ **وأن القراءة تعمل فعلاً كما ينصّ `ADR-0013` القاعدة 4**
    //    («لا يمسّ هذا القرار القراءة إطلاقاً»).
    await seed(async (db) => {
      await setDoc(doc(db, 'items/ITM-OPEN'), {
        name: 'نوع', normalizedName: 'نوع-مفتوح', unit: 'piece',
      });
      await setDoc(doc(db, 'sources/SRC-001'), { name: 'مصدر' });
      await setDoc(doc(db, 'unique_item_names/g-open'), { entityId: 'ITM-OPEN' });
    });
    const db = await as({ itemWrite: true }, ['SRC-001']);
    await assertSucceeds(getDoc(doc(db, 'items/ITM-OPEN')));
    await assertSucceeds(getDoc(doc(db, 'sources/SRC-001')));
    // ★ وسجل الحراسة مقروء عمداً — لتسبق الواجهةُ الرحلةَ برسالة «مسجَّل
    //   مسبقاً»، ⛔ **وهي راحةُ عرضٍ لا حماية.**
    await assertSucceeds(getDoc(doc(db, 'unique_item_names/g-open')));
  });
});

// ===========================================================================
// ★ ADR-0017 — حالة الإيداع البنكي معزولة بشرط قراءة مستقل
//   ⛔ فجوة كشفها WU-026 ولم يُنشئها (IQ-010).
// ===========================================================================

describe('★ ADR-0017 — عزل حالة الإيداع البنكي', () => {
  const PARENT = 'receipts/RCP-DEP';
  const DEPOSIT = 'receipts/RCP-DEP/deposit/current';

  async function seedBoth() {
    await seed(async (db) => {
      await setDoc(doc(db, PARENT), {
        dealerId: 'MQT-0001', sourceId: 'SRC-001', amount: 500,
      });
      await setDoc(doc(db, DEPOSIT), {
        isDeposited: true, depositNote: 'أُودع', depositedBy: 'USR-0001',
      });
    });
  }

  it('✅ من يملك `receiptDepositView` يقرأ حالة الإيداع', async () => {
    await seedBoth();
    const db = await as({ receiptDepositView: true });
    await assertSucceeds(getDoc(doc(db, DEPOSIT)));
  });

  it('★★ ⛔ ومن لا يملكها **يُمنَع** — وهذا ما لم يكن مُنفَّذاً قبل ADR-0017', async () => {
    // ⚠️ قبل هذا القرار كان أي مصادَق يقرأ الحالة، لأن المفتاح كان يظهر
    //    في مسار الكتابة وحده فتمرّ بوابة التغطية وتظنّه مُنفَّذاً.
    await seedBoth();
    const db = await as({ receiptCreate: true }); // صلاحيات أخرى ولا عرض إيداع
    await assertFails(getDoc(doc(db, DEPOSIT)));
  });

  it('★ والسند الأب يبقى مقروءاً كما هو — العزل مُستهدَف لا شامل', async () => {
    await seedBoth();
    const db = await as({});
    await assertSucceeds(getDoc(doc(db, PARENT)));
  });

  it('⛅ والكتابة على مستند الإيداع مغلقة — ولو بكل الصلاحيات', async () => {
    await seedBoth();
    const owner = await asOwner();
    await assertFails(
      setDoc(doc(owner, 'receipts/RCP-DEP2/deposit/current'), {
        isDeposited: true,
      }),
    );
    await assertFails(
      updateDoc(doc(owner, DEPOSIT), { depositNote: 'تعديل' }),
    );
  });

  it('★ ولا يُحذف مستند الإيداع — ولو للمالك', async () => {
    await seedBoth();
    const owner = await asOwner();
    await assertFails(deleteDoc(doc(owner, DEPOSIT)));
  });
});

// ═══════════════════════════════════════════════════════════════════════
// ★★ IQ-017 · DEBT-22 — تعطيل الحساب مُنفَّذ في طبقة التفويض الوحيدة
//
// ⚠️ **ولماذا مجموعة مستقلة:** كان التعطيل مُنفَّذاً **في التطبيق وحده**،
//    وهو بالضبط نمط `RISK-02`: إخفاءٌ يبدو حمايةً وليس بها. ★ **وأداة
//    خارجية برمز صالح تتجاوز الواجهة كلها** (`E-42`) — فما لا تفرضه هذه
//    الاختبارات **غير مفروض إطلاقاً**.
// ═══════════════════════════════════════════════════════════════════════
describe('★★ IQ-017 — الحساب المعطَّل لا يملك صلاحية في القاعدة نفسها', () => {
  const AUDIT = 'audit_log/AUD-IQ17';

  // ⚠️★★ **ولماذا القراءة لا الكتابة في كل ما يلي:** الكتابة المباشرة مغلقة
  //    أصلاً على مجموعات المال والمخزون (`ADR-0013` القاعدة 2 · `DEBT-20`)،
  //    ⟵ **فاختبارُ كتابةٍ هناك ينجح لسببٍ آخر تماماً ولا يُثبت شيئاً عن
  //    `isActive`**. ★ **وقد وقعتُ في هذا فعلاً في أول صياغة لهذه المجموعة:**
  //    «المعطَّل يُرفَض» نجحت بينما «النشط يُسمَح له» فشلت — **والاثنتان
  //    كانتا تقيسان الإغلاق لا التعطيل.** ⟵ **فالقراءة وحدها هي المسار
  //    الذي تحرسه `perm()` فعلاً اليوم.**

  /** مستخدم ببطاقة صريحة الحالة — ★ والصلاحيات نفسها في كل الحالات. */
  async function reader(uid, isActive) {
    await seedUserCard(uid, { auditLogViewCentral: true }, isActive);
    return testEnv
      .authenticatedContext(uid, { sourceScope: ['SRC-001'] })
      .firestore();
  }

  async function seedAudit() {
    await seed(async (db) => {
      await setDoc(doc(db, AUDIT), {
        sourceId: 'SRC-001',
        action: 'create',
      });
    });
  }

  it('✅ المستخدم النشط بصلاحيته يقرأ — الضبط الموجب', async () => {
    // ★ **بلا هذا الاختبار لا معنى للذي بعده:** رفضُ المعطَّل لا يُثبت شيئاً
    //   إن كان النشط مرفوضاً أيضاً — عندها الشرط يرفض الجميع لا المعطَّلين.
    await seedAudit();
    const db = await reader('USR-ACTIVE-17', true);
    await assertSucceeds(getDoc(doc(db, AUDIT)));
  });

  it('⛔★★ والمعطَّل يُرفَض — ولو كانت صلاحيته في بطاقته صحيحة', async () => {
    // ⚠️ **هذه هي الثغرة التي أغلقها `IQ-017` حرفياً:** `isActive: false`
    //    مع `auditLogViewCentral: true` كان **يمرّ** من القاعدة قبل التشديد،
    //    ★ **والتطبيق وحده يمنعه** — وهو ما لا تراه أداة خارجية (`E-42`).
    await seedAudit();
    const db = await reader('USR-DISABLED-17', false);
    await assertFails(getDoc(doc(db, AUDIT)));
  });

  it('⛔★ والبطاقة بلا حقل `isActive` تُرفَض — الغياب تعطيلٌ لا سماح', async () => {
    // ★★ **هذا ما يفرض ترتيب النشر** (`RB-backfill-user-isactive.md`):
    //    البطاقة القديمة بلا الحقل **بطاقةٌ بلا صلاحية**. ⟵ فالترحيل
    //    ليس تنظيفاً مؤجَّلاً بل **شرط نشرٍ مُلزِم**، وهذا الاختبار دليله.
    await seedAudit();
    await seed(async (db) => {
      await setDoc(doc(db, 'users', 'USR-LEGACY-17'), {
        permissions: { auditLogViewCentral: true },
      });
    });
    const db = testEnv
      .authenticatedContext('USR-LEGACY-17', { sourceScope: ['SRC-001'] })
      .firestore();
    await assertFails(getDoc(doc(db, AUDIT)));
  });

  it('✅ وبطاقته تبقى مقروءة له — التعطيل يمنع الصلاحية لا الهوية', async () => {
    // ★ **تمييز مقصود:** قراءة المستخدم بطاقتَه شرطُها `request.auth.uid`
    //   ⛔ **لا `perm()`** — فيبقى التطبيق قادراً على رؤية `isActive: false`
    //   و`disableReason` ليعرض شاشة «الحساب معطَّل» بدل شاشة فارغة مبهمة.
    //   ⟵ **ولولا ذلك لَما أمكن للمعطَّل أن يعرف لماذا لا يرى شيئاً.**
    await seedUserCard('USR-DIS-SELF-17', { itemView: true }, false);
    const db = testEnv
      .authenticatedContext('USR-DIS-SELF-17', { sourceScope: ['SRC-001'] })
      .firestore();
    await assertSucceeds(getDoc(doc(db, 'users/USR-DIS-SELF-17')));
  });
});

// ═══════════════════════════════════════════════════════════════════════
// ★★ IQ-015 (الخيار أ) — قراءة بطاقة مستخدم آخر تحتاج `userView`
//
// ★ **قبل هذا كان المسار مسدوداً تماماً:** `request.auth.uid == userId`
//   وحده، ⟵ **فاستعلام مجموعة `users` يُرفَض كاملاً ولا شاشة إدارة ممكنة**،
//   و`userView` مفتاحٌ في الكتالوج **بلا مقابل في أي قاعدة** — وهو ما
//   يسمّيه `FR-M1-10` «غير مُنفَّذ أمنياً».
// ═══════════════════════════════════════════════════════════════════════
describe('★★ IQ-015 — قراءة بطاقة غيرك بـ`userView`', () => {
  /** بطاقة هدفٍ ثابتة يقرؤها الآخرون — ★ وتحمل خريطة صلاحيات فعلية. */
  async function seedTarget() {
    await seed(async (db) => {
      await setDoc(doc(db, 'users', 'USR-TARGET-15'), {
        name: 'مستخدم آخر',
        permissions: { itemView: true },
        isActive: true,
      });
    });
  }

  it('✅ من يملك `userView` يقرأ بطاقة غيره', async () => {
    await seedTarget();
    const db = await as({ userView: true });
    await assertSucceeds(getDoc(doc(db, 'users/USR-TARGET-15')));
  });

  it('⛔ ومن لا يملكها يُرفَض — ولو كان يملك صلاحيات أخرى', async () => {
    await seedTarget();
    const db = await as({ itemView: true, sackView: true });
    await assertFails(getDoc(doc(db, 'users/USR-TARGET-15')));
  });

  it('✅ ويقرأ بطاقته هو دائماً — ⛔ بلا `userView`', async () => {
    // ★★ **شرطٌ بلا صلاحية عمداً، وهو ما يمنع حلقة إقلاع ثالثة:** لو
    //   اشتُرطت `userView` على قراءة النفس **لَما استطاع أحدٌ قراءة
    //   صلاحياته إلا بصلاحية قراءتها**، ⟵ ولا يُقلِع النظام أصلاً.
    const db = await as({});
    await assertSucceeds(getDoc(doc(db, 'users/USR-0001')));
  });

  it('⛔★ والمعطَّل لا يقرأ بطاقة غيره — ولو كانت `userView` في بطاقته', async () => {
    // ★ **تقاطع `IQ-015` مع `IQ-017`:** الشرط الجديد يمرّ عبر `perm()`،
    //   ⟵ **فيرث اشتراط `isActive` تلقائياً** ⛔ ولا يحتاج سطراً ثانياً.
    await seedTarget();
    await seedUserCard('USR-DIS-VIEW-15', { userView: true }, false);
    const db = testEnv
      .authenticatedContext('USR-DIS-VIEW-15', { sourceScope: ['SRC-001'] })
      .firestore();
    await assertFails(getDoc(doc(db, 'users/USR-TARGET-15')));
  });

  it('⛅ والكتابة تبقى مغلقة تماماً — ولو بـ`userView` و`userCreate`', async () => {
    // ⛔ **`userView` صلاحية قراءة ولا تفتح كتابةً بحال** — ومسار الإنشاء
    //   والتعديل والتعطيل **عمليات مستدعاة** (`ADR-0013`) لا كتابة مباشرة.
    const db = await as({ userView: true, userCreate: true, userAmend: true });
    await assertFails(
      setDoc(doc(db, 'users/USR-NEW-15'), { name: 'جديد', isActive: true }),
    );
    await assertFails(
      updateDoc(doc(db, 'users/USR-TARGET-15'), { name: 'تعديل' }),
    );
  });
});

// ═════════════════════════════════════════════════════════════════════════
// ★★★ IQ-018 — `roleDelete` حذفٌ فعلي، ⛔ **ومسارُه سحابيٌّ لا قاعدي**
//
// ⚠️⚠️ **وما تُثبته هذه المجموعة بدقة:** أن **مفتاح `roleDelete` لا يفتح
//    حذفاً مباشراً في القاعدة** — ★ **فالحذف يمرّ بالعملية `deleteRole`**
//    التي **تستعلم على `users` داخل معاملتها** قبل أن تحذف (`ADR-0013`
//    القاعدة 2 و3). ⟵ **ولو فُتحت الكتابة هنا لَصار الجهازُ قادراً على
//    حذف دورٍ مُسنَد** متجاوزاً الاستعلام كله.
//
// ⛔★★ **ولا يُقبَل هنا اختبارٌ ينجح بحظرٍ عام غير مقصود:** كل رفضٍ يقابله
//    **ضابطٌ موجب على المسار نفسه** — القراءة تنجح ⟵ **فالمجموعة موجودة
//    ومطابقة**، والرفضُ رفضُ الكتابة وحدها لا غيابُ قاعدة.
// ═════════════════════════════════════════════════════════════════════════
describe('★★★ IQ-018 — حذف الدور مسارُه سحابي لا قاعدي', () => {
  const ROLE = 'roles/ROLE-IQ018';

  /** يزرع دوراً متجاوزاً القواعد — تحضير لا اختبار. */
  async function seedRole() {
    await seed(async (db) => {
      await setDoc(doc(db, ROLE), {
        name: 'محاسب',
        normalizedName: 'محاسب',
        permissionTemplate: { itemView: true },
      });
    });
  }

  it('✅ الضابط الموجب — كل مُصادَق يقرأ الأدوار', async () => {
    // ★★ **وهذا الضابط هو ما يجعل الرفض أدناه ذا معنى:** لو كانت القراءة
    //   تفشل أيضاً **لَدلَّ ذلك على غياب القاعدة أو خطأ في المسار**،
    //   ⟵ **ولَنجحت اختبارات الرفض لسببٍ غير مقصود.**
    await seedRole();
    const db = await as({});
    await assertSucceeds(getDoc(doc(db, ROLE)));
  });

  it('⛔★★★ ومن يملك `roleDelete` لا يحذف الدور من الجهاز', async () => {
    // ★★ **المفتاح ممنوحٌ فعلاً في البطاقة** — ⟵ **فالرفض ليس نقصَ صلاحية**
    //   بل **إغلاقَ المسار القاعدي كلّه** (`ADR-0013` القاعدة 2).
    await seedRole();
    const db = await as({ roleDelete: true, roleWrite: true, userView: true });
    await assertFails(deleteDoc(doc(db, ROLE)));
    // ★ **وقراءته ما تزال ناجحة بالبطاقة نفسها** — ⟵ **فالمنع منعُ الحذف
    //   وحده**، ⛔ لا حجبٌ عامّ للمستخدم ولا فشلٌ في تهيئة الاختبار.
    await assertSucceeds(getDoc(doc(db, ROLE)));
  });

  it('⛔★★ ولا المالكُ بكل الصلاحيات يحذفه', async () => {
    // ★ **إثباتُ أن الإغلاق على المسار لا على المستخدم** — `BR-M1-08`.
    await seedRole();
    const owner = await asOwner();
    await assertFails(deleteDoc(doc(owner, ROLE)));
    await assertSucceeds(getDoc(doc(owner, ROLE)));
  });

  it('⛔★ ولا إنشاء دورٍ ولا تعديلَه من الجهاز', async () => {
    // ★ **الحذف ليس استثناءً مفتوحاً** — `createRole` و`updateRole`
    //   عمليتان مستدعاتان أيضاً، ⟵ **فالمجموعة مغلقة للكتابة كاملةً.**
    await seedRole();
    const db = await as({ roleWrite: true, roleDelete: true });
    await assertFails(setDoc(doc(db, 'roles/ROLE-NEW-18'), { name: 'جديد' }));
    await assertFails(updateDoc(doc(db, ROLE), { name: 'تعديل' }));
  });

  it('⛔★★ ولا يُحذف مستخدمٌ بحال — والفرق بين المسارين مقصود', async () => {
    // ⚠️⚠️ **حارسٌ على أن استثناء `IQ-018` لم يتسرّب إلى غيره:** الاستثناء
    //   **قالبُ دورٍ غير مُسنَد وحده**، ⛔ **والمستخدم صاحب حركات لا يُحذف
    //   أبداً** (`FR-M1-12`) — ★ **ولا في القاعدة ولا في السحابة.**
    await seedUserCard('USR-DEL-18', { itemView: true });
    const owner = await asOwner();
    await assertFails(deleteDoc(doc(owner, 'users/USR-DEL-18')));
    await assertSucceeds(getDoc(doc(owner, 'users/USR-DEL-18')));
  });
});

// ===========================================================================
// ★★★ WU-008 — قراءة سجل التدقيق كما يقرؤه التطبيق فعلاً (`getDocs` لا `getDoc`)
//
// ⚠️⚠️ **وهذا تطبيقٌ مباشر لدرس `IQ-024`:** ★ **كلُّ اختبارات `audit_log`
//    السابقة كانت `getDoc`** ⛔ **ولا واحدَ `getDocs`** — ★ **بينما شاشتا
//    `WU-008` (المركزية والسياقية) استعلامان على المجموعة لا قراءةُ مستند.**
//    ⟵ **فالفجوة بين ما تختبره القواعد وما يفعله التطبيق** هي بالضبط ما
//    ترك منتقيَ المصدر فارغاً في كل شاشة حتى 2026-08-26.
// ===========================================================================

describe('★★★ WU-008 — سجل التدقيق: الاستعلام لا المستند الواحد', () => {
  beforeEach(async () => {
    await seed(async (db) => {
      await setDoc(doc(db, 'audit_log/AUD-W8-1'), {
        sourceId: 'SRC-001',
        entityType: 'countedIntake',
        entityId: 'INC-1',
        userId: 'USR-0001',
        action: 'amend',
        occurredAt: todayUtc(),
      });
      await setDoc(doc(db, 'audit_log/AUD-W8-2'), {
        sourceId: 'SRC-999',
        entityType: 'countedIntake',
        entityId: 'INC-2',
        userId: 'USR-0001',
        action: 'create',
        occurredAt: todayUtc(),
      });
      await setDoc(doc(db, 'audit_log/AUD-W8-3'), {
        sourceId: 'all',
        entityType: 'user',
        entityId: 'USR-0002',
        userId: 'USR-OWNER',
        action: 'permissionChange',
        occurredAt: todayUtc(),
      });
    });
  });

  it('⛔⛔★★★ سردٌ بلا قيدٍ على `sourceId` يُرفَض — ولو بنطاقٍ شامل', async () => {
    // ★★★ **هذا هو القياس الذي أعاد تشكيل `AuditLogFilter`:** ⟵ **شرطُ
    //    `storedInScope()` على `resource.data` لا يُقيَّم لكل مستند في
    //    السرد**، ⛔ **فاستعلامٌ لا يُقيّد الحقل لا يُثبِته فيُرفَض كاملاً.**
    //    ★ **وهو درس `IQ-024` نفسه** — ⟵ **ولولا `getDocs` هنا لَمرَّت
    //    الزيادة بشاشةِ خطأٍ دائمة على مستخدمٍ يملك صلاحيتها.**
    const all = await asOwnerWith({ auditLogViewCentral: true });
    await assertFails(getDocs(collection(all, 'audit_log')));

    const scoped = await as({ auditLogViewCentral: true }, ['SRC-001']);
    await assertFails(getDocs(collection(scoped, 'audit_log')));
  });

  it('★★ ويمرّ متى قُيّد بمصدرٍ داخل النطاق — الفهرس `sourceId ↑ · occurredAt ↓`', async () => {
    const scoped = await as({ auditLogViewCentral: true }, ['SRC-001']);
    await assertSucceeds(
      getDocs(
        query(collection(scoped, 'audit_log'), where('sourceId', '==', 'SRC-001')),
      ),
    );
  });

  it('⛔ وخارجَ نطاقه يُرفَض ولو حمل الصلاحية — GR-23 · FR-M18-14', async () => {
    const scoped = await as({ auditLogViewCentral: true }, ['SRC-001']);
    await assertFails(
      getDocs(
        query(collection(scoped, 'audit_log'), where('sourceId', '==', 'SRC-999')),
      ),
    );
  });

  it('★ وبُعد الإجراء فوق المصدر — `sourceId ↑ · action ↑ · occurredAt ↓`', async () => {
    const scoped = await as({ auditLogViewCentral: true }, ['SRC-001']);
    await assertSucceeds(
      getDocs(
        query(
          collection(scoped, 'audit_log'),
          where('sourceId', '==', 'SRC-001'),
          where('action', '==', 'amend'),
        ),
      ),
    );
  });

  it('★ وبُعد المستخدم فوق المصدر — `sourceId ↑ · userId ↑ · occurredAt ↓`', async () => {
    const scoped = await as({ auditLogViewCentral: true }, ['SRC-001']);
    await assertSucceeds(
      getDocs(
        query(
          collection(scoped, 'audit_log'),
          where('sourceId', '==', 'SRC-001'),
          where('userId', '==', 'USR-0001'),
        ),
      ),
    );
  });

  it('★★ والسجل السياقي بـ`auditLogViewContextual` وحدها — الشرط «أو»', async () => {
    // ★ **نقلٌ حرفي لشرط القاعدة:** `perm(central) || perm(contextual)` —
    //   ⟵ **وهو ما تبني عليه `canViewAuditTrailProvider` بوابةَ الأيقونة.**
    const contextual = await as({ auditLogViewContextual: true }, ['SRC-001']);
    await assertSucceeds(
      getDocs(
        query(
          collection(contextual, 'audit_log'),
          where('sourceId', '==', 'SRC-001'),
          where('entityType', '==', 'countedIntake'),
          where('entityId', '==', 'INC-1'),
        ),
      ),
    );
  });

  it("★★ وقيود «ما لا يخصّ مصدراً» (`sourceId = 'all'`) لصاحب النطاق الشامل وحده", async () => {
    // ★ **أثرٌ موثَّق سلفاً في `audit_entry.dart`:** «قيود تغيير الصلاحيات
    //   **تضيق على أصحاب النطاق الكامل** ولا تتّسع» — ⟵ **ولذلك لا يُعرَض
    //   خيارُها في الفلتر إلا لهم** (`auditSourceOptionsProvider`).
    const all = await asOwnerWith({ auditLogViewCentral: true });
    await assertSucceeds(
      getDocs(
        query(collection(all, 'audit_log'), where('sourceId', '==', 'all')),
      ),
    );

    const scoped = await as({ auditLogViewCentral: true }, ['SRC-001']);
    await assertFails(
      getDocs(
        query(collection(scoped, 'audit_log'), where('sourceId', '==', 'all')),
      ),
    );
  });

  it('⛔ ومن لا يملك أياً من المفتاحين يُرفَض — ولو بنطاقٍ شامل', async () => {
    const none = await asOwnerWith({ incomingCountWrite: true });
    await assertFails(
      getDocs(
        query(collection(none, 'audit_log'), where('sourceId', '==', 'SRC-001')),
      ),
    );
    await assertFails(getDoc(doc(none, 'audit_log/AUD-W8-1')));
  });

  it('⛔⛔ ولا كتابةَ ولا تعديلَ ولا حذفَ من مسار الاستعلام نفسه', async () => {
    // ★ **حارسٌ على أن `WU-008` لم تفتح شيئاً** — ⟵ **الزيادة قراءةٌ محضة.**
    const all = await asOwnerWith({
      auditLogViewCentral: true,
      auditLogViewContextual: true,
    });
    await assertFails(setDoc(doc(all, 'audit_log/AUD-W8-9'), { action: 'x' }));
    await assertFails(
      updateDoc(doc(all, 'audit_log/AUD-W8-1'), { reason: 'مزوَّر' }),
    );
    await assertFails(deleteDoc(doc(all, 'audit_log/AUD-W8-1')));
  });
});

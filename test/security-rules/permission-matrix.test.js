/**
 * مصفوفة تغطية مفاتيح الصلاحيات — QTMS
 *
 * ★ تُغلق البند 4 من بوابة `docs/09-security/permissions-catalog.md` §5:
 *   **لكل مفتاح اختبار سماح واختبار منع.** (`DEBT-12`)
 *
 * ★ **تصميم الاختبار — عزل متغيّر واحد:** لكل مفتاح صفٌّ واحد يحمل عملية
 *   واحدة. يُشتقّ منه اختباران **لا يختلفان إلا في المفتاح المُختبَر**:
 *
 *     • السماح : `{ ...المفاتيح المساعدة, [المفتاح]: true }` ⟵ يجب أن ينجح
 *     • المنع  : `{ ...المفاتيح المساعدة }` بلا المفتاح      ⟵ يجب أن يُرفض
 *
 * ⛔ **ولهذا العزل قيمة برهانية:** لو فشل طرف السماح لسبب آخر (حقل ناقص،
 *    نطاق خاطئ) لَظهر فوراً بوصفه فشلاً — فلا يمرّ اختبار منعٍ «ناجح لسبب
 *    خاطئ». وهذا بالضبط العيب الذي رُصد في `rules.test.js` وصُحِّح: تأكيد
 *    منعٍ كان يمرّ بسبب حقل مالي فائض لا بسبب القاعدة المقصودة.
 *
 * ★ العمليات هنا **مشتقّة من `firestore.rules` نفسها** لا مخترَعة — كل حمولة
 *   تستوفي بقية شروط مسارها حرفياً.
 *
 * المستندات الحاكمة:
 *   docs/09-security/permissions-catalog.md §2 — المفاتيح الـ63 وسجلاتها
 *   docs/09-security/security-requirements.md  — القواعد العشر
 *   docs/06-database/data-dictionary.md        — أشكال المستندات
 */

import { before, after, beforeEach, describe, it } from 'node:test';
import assert from 'node:assert/strict';
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
  setDoc,
  updateDoc,
  getDoc,
  serverTimestamp,
} from 'firebase/firestore';

const HERE = dirname(fileURLToPath(import.meta.url));
const PROJECT_ROOT = join(HERE, '..', '..');

/** المفاتيح المستثناة بمبرر موثَّق — نفس استثناءات بوابة التغطية. */
const EXCLUDED = new Set(['sourceNetImpactView', 'messagingSend']);

/** ★ التعليق ليس إنفاذاً — تُزال التعليقات قبل أي مسح نصي للقواعد. */
function stripRuleComments(text) {
  return text
    .split('\n')
    .map((l) => { const i = l.indexOf('//'); return i === -1 ? l : l.slice(0, i); })
    .join('\n');
}

let testEnv;

function todayUtc() {
  const n = new Date();
  return new Date(Date.UTC(n.getUTCFullYear(), n.getUTCMonth(), n.getUTCDate()));
}

function daysAgoUtc(days) {
  const d = todayUtc();
  d.setUTCDate(d.getUTCDate() - days);
  return d;
}

/**
 * ★ ADR-0016: الصلاحيات تُزرَع في بطاقة المستخدم لا في الرمز.
 * و`sourceScope` يبقى في الرمز.
 *
 * ★★ IQ-017: و`isActive: true` معها — فـ`perm()` تشترطها، ⟵ **وبطاقةٌ
 *    بلا هذا الحقل بطاقةٌ بلا صلاحية إطلاقاً**. ⚠️ **وهذه المصفوفة تختبر
 *    «هل المفتاح يعمل؟» لا «هل التعطيل يعمل؟»** — فالمستخدم فيها **حيٌّ
 *    دائماً**، وحالةُ التعطيل مكانُها مجموعتها المستقلة في `rules.test.js`.
 */
async function as(permissions, sourceScope = ['SRC-001']) {
  await seed(async (db) => {
    await setDoc(doc(db, 'users', 'USR-0001'), {
      permissions,
      isActive: true,
    });
  });
  return testEnv
    .authenticatedContext('USR-0001', { sourceScope })
    .firestore();
}

async function seed(fn) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await fn(ctx.firestore());
  });
}

/**
 * ★ ADR-0013 القاعدة 2 — المجموعات التي أُغلقت كتابتها في القواعد.
 *
 * ⚠️ تُشتقّ الحالة **من المسار** لا بوسم يدوي لكل صفّ — فصفٌّ جديد على
 *    مجموعة مغلقة يُعامَل صحيحاً تلقائياً، ولا يعتمد على تذكّر أحد.
 */
const CLOSED_COLLECTIONS = new Set([
  'incoming_count', 'sacks', 'daily_prices', 'distributions', 'cash_sales',
  'receipts', 'discounts', 'outflows', 'stocktakes', 'disposals',
  // ★★ WU-002 — البيانات المرجعية وسجلات حراسة تفرّدها.
  //   ⚠️ **والسبب ليس «تمسّ المال»** بل أن التعديل عليها **يُسجَّل بالقيمة
  //   قبل وبعد** (`FR-M2-03` · `FR-M3-13` · `FR-M4-13`)، **وسجل التدقيق
  //   سحابيٌّ حصراً** (`FR-M18-04`)، **والمستند وقيده معاً أو لا شيء**
  //   (`ADR-0013` القاعدة 1). ⟵ **فالكتابة المباشرة تعديلٌ بلا قيد.**
  'sources', 'suppliers', 'dealers', 'items', 'app_settings',
  'unique_source_names', 'unique_supplier_phones',
  'unique_dealer_phones', 'unique_item_names',
]);

/** هل مسار هذا الصفّ داخل مجموعة أُغلقت كتابتها؟ (يشمل المجموعات الفرعية) */
function isClosedPath(path) {
  return CLOSED_COLLECTIONS.has(path.split('/')[0]);
}

/** صفّ كتابة على مجموعة مغلقة — لم يعد للقواعد ما تفرضه فيه. */
function isClosedWriteRow(row) {
  return row.mode !== 'read' && isClosedPath(row.path);
}

const SRC = 'SRC-001';
const DIST_ID = 'MQT-0001_SRC-001_D1';

// ===========================================================================
// المصفوفة — صفٌّ لكل مفتاح مُنفَّذ في القواعد (61 مفتاحاً)
//
//   key    : المفتاح المُختبَر — وهو **الفرق الوحيد** بين السماح والمنع
//   mode   : create | update | read
//   path   : مسار المستند
//   extra  : مفاتيح مساعدة يفرضها المسار نفسه (تُمنَح في الحالتين)
//   seed   : المستند المزروع مسبقاً (لـ update و read) — يتخطّى القواعد
//   data   : حمولة الإنشاء أو رقعة التعديل
// ===========================================================================

const MATRIX = [
  // ---- 2.1 البيانات الأساسية (5) ----
  {
    key: 'sourceWrite', mode: 'create', path: `sources/${SRC}`,
    data: () => ({ name: 'مصدر', createdAt: serverTimestamp() }),
  },
  {
    key: 'supplierWrite', mode: 'create', path: 'suppliers/SUP-001',
    data: () => ({ name: 'رعوي', normalizedPhone: '777000111' }),
  },
  {
    key: 'dealerWrite', mode: 'create', path: 'dealers/MQT-0001',
    data: () => ({ name: 'مقوت', normalizedPhone: '777000222' }),
  },
  // ★★★ IQ-020 الخيار أ — والصفّ هنا يُثبت **ما لا يفعله المفتاح**:
  //   ⛔ لا يفتح كتابةً مباشرة على `dealers` ولو مُنح. ★ وإنفاذه الحقيقي
  //   في الدالة الكاتبة — `functions/test/master_data_test.dart`.
  {
    key: 'dealerDisableWithBalance', mode: 'update', path: 'dealers/MQT-0001',
    seed: () => ({ name: 'مقوت', isActive: true }),
    extra: { dealerWrite: true },
    data: () => ({ isActive: false, disableReason: 'ترك العمل' }),
  },
  {
    key: 'itemWrite', mode: 'create', path: 'items/ITM-001',
    data: () => ({ name: 'نوع', normalizedName: 'نوع', unit: 'piece' }),
  },
  {
    key: 'appSettingsWrite', mode: 'create', path: 'app_settings/business',
    data: () => ({ businessName: 'QTMS' }),
  },

  // ---- 2.2 التوريد (9) ----
  // ★★★ IQ-021 الخيار أ — والصفّ هنا يُثبت **ما لا يفعله المفتاح**:
  //   ⛔ لا يفتح إنشاءً مباشراً على `sacks` ولو مُنح. ★ وإنفاذه الحقيقي
  //   في الدالة الكاتبة — `functions/test/sack_intake_test.dart`.
  {
    key: 'sackCreate', mode: 'create', path: 'sacks/SCK-20260101-0001',
    data: () => ({
      sourceId: SRC, stockDate: todayUtc(), dailySequence: 1,
      displayName: 'جونية رقم 1', totalWeight: 45, iceWeight: 6.5,
      scrapWeight: 1.2,
    }),
  },
  {
    key: 'incomingCountWrite', mode: 'create', path: 'incoming_count/IC-001',
    data: () => ({
      sourceId: SRC, stockDate: todayUtc(), entryDate: serverTimestamp(),
      itemKey: 'ITM-001', quantity: 10,
    }),
  },
  {
    // ★★ IQ-015: صار له شرط قراءة حقيقي في `match /users/{userId}` بعد أن
    //    كان مستثنى بمبرِّر يخصّ الكتابة ⛔ لا ينطبق على مفتاح قراءة.
    // ⚠️ **والهدف مستخدمٌ آخر عمداً** — فبطاقة `USR-0001` نفسه مقروءة له
    //    بلا صلاحية، ⟵ **واختبارها هنا كان سيمرّ في الحالتين ولا يُثبت شيئاً.**
    key: 'userView', mode: 'read', path: 'users/USR-OTHER-MTX',
    seed: () => ({ name: 'مستخدم آخر', permissions: {}, isActive: true }),
  },
  {
    key: 'sackView', mode: 'read', path: 'sacks/SCK-001',
    seed: () => ({ sourceId: SRC, displayName: 'جونية' }),
  },
  {
    key: 'sackTaxEnterNow', mode: 'create', path: 'sacks/SCK-001/finance/current',
    seedParent: { path: 'sacks/SCK-001', data: { sourceId: SRC } },
    data: () => ({ sourceId: SRC, taxPerKilo: 10, sackTax: 100 }),
  },
  {
    // ★ يشترط `sackView` معاً — فهو مفتاح مساعد في الحالتين.
    key: 'sackTaxEnterLater', mode: 'create', extra: { sackView: true },
    path: 'sacks/SCK-001/finance/current',
    seedParent: { path: 'sacks/SCK-001', data: { sourceId: SRC } },
    data: () => ({ sourceId: SRC, taxPerKilo: 10, sackTax: 100 }),
  },
  {
    key: 'sackRenameDisplay', mode: 'update', path: 'sacks/SCK-001',
    seed: () => ({ sourceId: SRC, displayName: 'قديم' }),
    data: () => ({ displayName: 'جديد' }),
  },
  {
    key: 'sackLinesEnter', mode: 'update', path: 'sacks/SCK-001',
    seed: () => ({ sourceId: SRC, lines: [] }),
    data: () => ({ lines: [{ itemKey: 'ITM-001', weight: 5 }], linesWeightSum: 5 }),
  },
  {
    key: 'sackScrapWeightEnter', mode: 'update', path: 'sacks/SCK-001',
    seed: () => ({ sourceId: SRC, scrapWeight: 0 }),
    data: () => ({ scrapWeight: 3, claimableWeight: 97 }),
  },
  {
    key: 'sackLostWeightConfirm', mode: 'update', path: 'sacks/SCK-001',
    seed: () => ({ sourceId: SRC, lostWeight: 0 }),
    data: () => ({ lostWeight: 2, lostWeightConfirmed: true, lostWeightNote: 'تأكيد' }),
  },

  // ---- 2.3 التسعير والصرف (9) ----
  {
    key: 'dailyPriceWrite', mode: 'create', path: 'daily_prices/SRC-001_D1',
    data: () => ({ sourceId: SRC, prices: [], lastModifiedAt: serverTimestamp() }),
  },
  {
    key: 'distributionCreate', mode: 'create', path: `distributions/${DIST_ID}`,
    data: () => ({
      dealerId: 'MQT-0001', sourceId: SRC, stockDate: todayUtc(),
      entryDate: serverTimestamp(), lines: [], unpricedLineCount: 0,
    }),
  },
  {
    key: 'distributionPriceNow', mode: 'create', extra: { distributionCreate: true },
    path: `distributions/${DIST_ID}/pricing/current`,
    seedParent: { path: `distributions/${DIST_ID}`, data: { sourceId: SRC } },
    data: () => ({ sourceId: SRC, unitPrices: [500], lineTotals: [5000], debtValue: 5000 }),
  },
  {
    key: 'distributionPriceAmend', mode: 'update', extra: { distributionCreate: true },
    path: `distributions/${DIST_ID}/pricing/current`,
    seedParent: { path: `distributions/${DIST_ID}`, data: { sourceId: SRC } },
    seed: () => ({ sourceId: SRC, unitPrices: [500], lineTotals: [5000], debtValue: 5000 }),
    data: () => ({ unitPrices: [600], lineTotals: [6000], debtValue: 6000 }),
  },
  {
    key: 'distributionPriceClear', mode: 'update',
    path: `distributions/${DIST_ID}/pricing/current`,
    seedParent: { path: `distributions/${DIST_ID}`, data: { sourceId: SRC } },
    seed: () => ({ sourceId: SRC, unitPrices: [500], lineTotals: [5000], debtValue: 5000 }),
    data: () => ({ unitPrices: [], lineTotals: [], debtValue: 0 }),
  },
  {
    key: 'distributionPriceView', mode: 'read',
    path: `distributions/${DIST_ID}/pricing/current`,
    seedParent: { path: `distributions/${DIST_ID}`, data: { sourceId: SRC } },
    seed: () => ({ sourceId: SRC, unitPrices: [500], debtValue: 5000 }),
  },
  {
    key: 'cashSaleCreate', mode: 'create', path: 'cash_sales/CS-001',
    data: () => ({
      sourceId: SRC, stockDate: todayUtc(), entryDate: serverTimestamp(),
      lines: [], netAmount: 1000,
    }),
  },
  {
    key: 'cashSaleBelowMinimum', mode: 'create', extra: { cashSaleCreate: true },
    path: 'cash_sales/CS-002',
    data: () => ({
      sourceId: SRC, stockDate: todayUtc(), entryDate: serverTimestamp(),
      lines: [], netAmount: 1000,
      hasBelowMinLine: true, belowMinReason: 'موافقة المالك',
    }),
  },
  {
    // ★ المسار الوحيد الذي يقبل `stockDate` أقدم من اليوم.
    key: 'agedRemainderClear', mode: 'create', extra: { distributionCreate: true },
    path: 'distributions/MQT-0001_SRC-001_OLD',
    data: () => ({
      dealerId: 'MQT-0001', sourceId: SRC, stockDate: daysAgoUtc(3),
      entryDate: serverTimestamp(), lines: [], unpricedLineCount: 0,
    }),
  },

  // ---- 2.4 الإتلاف والجرد (2) ----
  {
    key: 'disposalCreate', mode: 'create', path: 'disposals/DSP-001',
    data: () => ({ sourceId: SRC, stockDate: todayUtc(), reason: 'تلف طبيعي', lines: [] }),
  },
  {
    key: 'stocktakeWrite', mode: 'create', path: 'stocktakes/ST-001',
    data: () => ({ sourceId: SRC, stockDate: todayUtc(), lines: [] }),
  },

  // ---- 2.5 التحصيل والذمم (6) ----
  {
    key: 'receiptCreate', mode: 'create', path: 'receipts/RCP-001',
    data: () => ({ dealerId: 'MQT-0001', sourceId: SRC, date: todayUtc(), amount: 500 }),
  },
  {
    key: 'receiptBackdate', mode: 'create', extra: { receiptCreate: true },
    path: 'receipts/RCP-002',
    data: () => ({ dealerId: 'MQT-0001', sourceId: SRC, date: daysAgoUtc(2), amount: 500 }),
  },
  {
    // ★ ADR-0017: صار **شرط قراءة فعلياً** على المستند الفرعي المعزول،
    //   بعد أن كان يظهر في مسار الكتابة وحده فتمرّ البوابة زوراً (IQ-010).
    key: 'receiptDepositView', mode: 'read',
    path: 'receipts/RCP-001/deposit/current',
    seed: () => ({
      isDeposited: true, depositNote: 'أُودع', depositedBy: 'USR-0001',
    }),
  },
  {
    key: 'receiptDepositConfirm', mode: 'update', extra: { receiptDepositView: true },
    path: 'receipts/RCP-001',
    seed: () => ({ dealerId: 'MQT-0001', sourceId: SRC, amount: 500, isDeposited: false }),
    data: () => ({
      isDeposited: true, depositNote: 'أُودع', depositedBy: 'USR-0001',
      depositedAt: serverTimestamp(),
    }),
  },
  {
    key: 'discountCreate', mode: 'create', path: 'discounts/DSC-001',
    data: () => ({ dealerId: 'MQT-0001', sourceId: SRC, date: todayUtc(), amount: 200 }),
  },
  {
    key: 'dealerBalanceView', mode: 'read', path: 'dealer_balances/MQT-0001',
    seed: () => ({ dealerId: 'MQT-0001', balance: 1000 }),
  },

  // ---- 2.6 السحبيات والخرجيات (5) ----
  {
    key: 'withdrawalCreate', mode: 'create', path: 'outflows/OF-W1',
    data: () => ({
      sourceId: SRC, date: todayUtc(), ledgerType: 'withdrawal',
      lines: [], unpricedItemCount: 1,
    }),
  },
  {
    key: 'expenseCreate', mode: 'create', path: 'outflows/OF-E1',
    data: () => ({
      sourceId: SRC, date: todayUtc(), ledgerType: 'expense',
      lines: [], unpricedItemCount: 1,
    }),
  },
  {
    // ★ حمولة بلا أصناف غير مسعَّرة ⟵ السعر حاضر، فيلزم مفتاح تسعيره.
    key: 'withdrawalQatPriceNow', mode: 'create', extra: { withdrawalCreate: true },
    path: 'outflows/OF-W2',
    data: () => ({
      sourceId: SRC, date: todayUtc(), ledgerType: 'withdrawal',
      lines: [], unpricedItemCount: 0, totalQatValue: 500,
    }),
  },
  {
    key: 'withdrawalView', mode: 'read', path: 'outflows/OF-W1',
    seed: () => ({ sourceId: SRC, ledgerType: 'withdrawal', grandTotal: 500 }),
  },
  {
    key: 'expenseView', mode: 'read', path: 'outflows/OF-E1',
    seed: () => ({ sourceId: SRC, ledgerType: 'expense', grandTotal: 300 }),
  },

  // ---- 2.7 المالية والرقابة (6 مُنفَّذة) ----
  {
    key: 'sackFinanceView', mode: 'read', path: 'sacks/SCK-001/finance/current',
    seedParent: { path: 'sacks/SCK-001', data: { sourceId: SRC } },
    seed: () => ({ sourceId: SRC, taxPerKilo: 10, sackRevenue: 5000 }),
  },
  {
    key: 'supplierFinanceView', mode: 'read', path: 'supplier_balances/SUP-001',
    seed: () => ({ sourceId: SRC, supplierId: 'SUP-001', balance: 900 }),
  },
  {
    key: 'ownerLedgerView', mode: 'read', path: 'daily_summaries/SRC-001_D1',
    seed: () => ({ sourceId: SRC, netCash: 100 }),
  },
  {
    // ★ بطاقة «كل المصادر» — صلاحية مستقلة فوق `ownerLedgerView`.
    key: 'allSourcesCardView', mode: 'read', extra: { ownerLedgerView: true },
    path: 'daily_summaries/all_D1',
    seed: () => ({ sourceId: 'all', netCash: 500 }),
  },
  {
    key: 'auditLogViewCentral', mode: 'read', path: 'audit_log/LOG-001',
    seed: () => ({ sourceId: SRC, action: 'create' }),
  },
  {
    key: 'auditLogViewContextual', mode: 'read', path: 'audit_log/LOG-001',
    seed: () => ({ sourceId: SRC, action: 'create' }),
  },

  // ---- 2.9 التعديل والإلغاء — لكل وحدة على حدة (20) ----
  ...amendPair('incomingCount', 'incoming_count/IC-001', { sourceId: SRC, quantity: 5 }),
  ...amendPair('sack', 'sacks/SCK-001', { sourceId: SRC, note: 'قديم' }),
  ...amendPair('distribution', `distributions/${DIST_ID}`,
    { sourceId: SRC, dealerId: 'MQT-0001', note: 'قديم' }),
  ...amendPair('cashSale', 'cash_sales/CS-001', { sourceId: SRC, netAmount: 100 }),
  ...amendPair('receipt', 'receipts/RCP-001', { sourceId: SRC, amount: 100 }),
  ...amendPair('discount', 'discounts/DSC-001', { sourceId: SRC, amount: 50 }),
  ...amendPair('withdrawal', 'outflows/OF-W1',
    { sourceId: SRC, ledgerType: 'withdrawal', grandTotal: 100 }),
  ...amendPair('expense', 'outflows/OF-E1',
    { sourceId: SRC, ledgerType: 'expense', grandTotal: 100 }),
  ...amendPair('stocktake', 'stocktakes/ST-001', { sourceId: SRC, note: 'قديم' },
    { stocktakeWrite: true }),
  ...amendPair('disposal', 'disposals/DSP-001', { sourceId: SRC, reason: 'تلف' }),
];

/**
 * يولّد صفَّي «تعديل» و«إلغاء» لوحدة واحدة — الشرط المزدوج في الحالتين:
 * الصلاحية **وسبب نصي غير فارغ** (`permissions-catalog.md` §2.9).
 */
function amendPair(unit, path, seedData, extra = undefined) {
  return [
    {
      key: `${unit}Amend`, mode: 'update', path, extra,
      seed: () => ({ ...seedData }),
      data: () => ({ note: 'محدَّث', amendReason: 'تصحيح إدخال' }),
    },
    {
      key: `${unit}Cancel`, mode: 'update', path, extra,
      seed: () => ({ ...seedData }),
      data: () => ({ status: 'cancelled', cancelReason: 'أُلغي بطلب المالك' }),
    },
  ];
}

// ===========================================================================

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

/** يزرع ما يلزم الصفَّ من مستندات (الأب ثم المستند نفسه). */
async function prepare(row) {
  if (!row.seedParent && !row.seed) return;
  await seed(async (db) => {
    if (row.seedParent) {
      await setDoc(doc(db, row.seedParent.path), row.seedParent.data);
    }
    if (row.seed) await setDoc(doc(db, row.path), row.seed());
  });
}

/** ينفّذ عملية الصفّ بصلاحيات محددة ويعيد الوعد كما هو. */
async function run(row, permissions) {
  const db = await as(permissions);
  const ref = doc(db, row.path);
  if (row.mode === 'read') return getDoc(ref);
  if (row.mode === 'update') return updateDoc(ref, row.data());
  return setDoc(ref, row.data());
}

describe('مصفوفة الصلاحيات — لكل مفتاح اختبار سماح واختبار منع', () => {
  for (const row of MATRIX) {
    const extra = row.extra ?? {};

    if (isClosedWriteRow(row)) {
      // ★ ADR-0013 القاعدة 2: لا سماح يُختبَر هنا — المسار مغلق تماماً.
      //   ⛔ والاختبار الوحيد المفيد أن **المفتاح نفسه لا يفتحه**.
      it(`⛅ ${row.key} — الكتابة مغلقة في القواعد ولو مع المفتاح`, async () => {
        await prepare(row);
        await assertFails(run(row, { ...extra, [row.key]: true }));
      });

      it(`⛅ ${row.key} — ومغلقة كذلك بلا المفتاح`, async () => {
        await prepare(row);
        await assertFails(run(row, { ...extra }));
      });
      continue;
    }

    it(`✅ ${row.key} — يسمح بالعملية`, async () => {
      await prepare(row);
      await assertSucceeds(run(row, { ...extra, [row.key]: true }));
    });

    it(`⛔ ${row.key} — بدونه تُرفض العملية نفسها`, async () => {
      await prepare(row);
      await assertFails(run(row, { ...extra }));
    });
  }

  // ★ حارس المصفوفة: لو أُضيف مفتاح إلى القواعد ولم يُضَف صفّ هنا، يفشل هذا
  //   الاختبار — فلا تتآكل التغطية بصمت.
  //
  // ★ لماذا يُقاس على `firestore.rules` لا على الكتالوج: `check:coverage`
  //   يضمن أصلاً تطابق الكتالوج والقواعد **في الاتجاهين**، فالقياس على
  //   القواعد يكافئ القياس على الكتالوج **ويقيس سطح التنفيذ الفعلي**.
  it('★ المصفوفة تغطي كل مفتاح تفرضه القواعد', () => {
    // ★ التعليق ليس إنفاذاً — تُزال التعليقات قبل المسح (نفس منطق بوابة التغطية).
    const rules = stripRuleComments(
      readFileSync(join(PROJECT_ROOT, 'firestore.rules'), 'utf8'),
    );

    // مسح بأقواس متوازنة — الوسيط قد يكون تعبيراً شرطياً يحوي أقواساً:
    //   canCancel(isWithdrawal() ? 'withdrawalCancel' : 'expenseCancel')
    const enforced = new Set();
    const CALL = /\b(?:perm2?|canAmend|canCancel)\(/g;
    let m;
    while ((m = CALL.exec(rules)) !== null) {
      let depth = 1;
      let i = m.index + m[0].length;
      const start = i;
      while (i < rules.length && depth > 0) {
        const ch = rules[i];
        if (ch === '(') depth++;
        else if (ch === ')') depth--;
        i++;
      }
      for (const lit of rules.slice(start, i - 1).matchAll(/'([a-z][a-zA-Z0-9]*)'/g)) {
        enforced.add(lit[1]);
      }
    }

    const covered = MATRIX.map((r) => r.key);
    const missing = [...enforced].filter((k) => !covered.includes(k) && !EXCLUDED.has(k));
    assert.deepEqual(missing, [], `مفاتيح تفرضها القواعد بلا صفّ: ${missing}`);

    // ولا صفّ على مفتاح لا تفرضه القواعد — وإلا فالصفّ يختبر وهماً.
    // ★ إلا صفوف المجموعات المغلقة: مفاتيحها **لم تعد في القواعد عمداً**
    //   (ADR-0013 القاعدة 2)، وتفويضها انتقل إلى الدالة الكاتبة (DEBT-21).
    const closedKeys = new Set(
      MATRIX.filter(isClosedWriteRow).map((r) => r.key),
    );
    const stray = covered.filter((k) => !enforced.has(k) && !closedKeys.has(k));
    assert.deepEqual(stray, [], `صفوف على مفاتيح لا تفرضها القواعد: ${stray}`);

    // ★★ والاتجاه المعاكس يُثبت أن الإغلاق فعلي: مفتاحُ مجموعةٍ مغلقة
    //    ⛔ **يجب ألا يبقى له شرط كتابة في القواعد**. ولو عاد أحدهم يفتح
    //    المسار، يسقط هذا الفحص فوراً.
    const reopened = [...closedKeys].filter((k) => enforced.has(k));
    assert.deepEqual(
      reopened, [],
      `مفاتيح لمجموعات مغلقة عادت تظهر في القواعد: ${reopened}`,
    );

    // ولا تكرار — التكرار يُضخِّم عدد الاختبارات بلا تغطية إضافية.
    assert.equal(new Set(covered).size, covered.length, 'مفتاح مكرَّر في المصفوفة');
  });
});

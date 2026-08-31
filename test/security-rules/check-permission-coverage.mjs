/**
 * فحص تغطية الصلاحيات — QTMS
 *
 * ★ ينفّذ البندين 3 و5 من بوابة `docs/09-security/permissions-catalog.md` §5،
 *   والبند 4 من بوابة `docs/09-security/security-requirements.md` §5:
 *
 *     ③ كل مفتاح في الكتالوج له شرط في `firestore.rules`
 *     ⑤ لا شرط في القواعد على مفتاح غير مذكور في الكتالوج
 *
 * ⛔ الاتجاهان معاً إلزاميان: مفتاح بلا قاعدة = صلاحية غير مُنفَّذة أمنياً
 *    (BR-M1-07) · وقاعدة على مفتاح غير مُعرَّف = شرط يُقرأ `null` فيسقط الفحص
 *    بصمت — وهي أخطر الحالتين لأنها لا تُنتج خطأً ظاهراً.
 *
 * ★ يعمل بلا محاكي وبلا شبكة — تحليل نصي بحت.
 * الخروج بغير صفر يُفشِل البناء.
 */

import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const HERE = dirname(fileURLToPath(import.meta.url));
const ROOT = join(HERE, '..', '..');

const RULES_PATH = join(ROOT, 'firestore.rules');
const CATALOG_PATH = join(ROOT, 'docs', '09-security', 'permissions-catalog.md');

/**
 * مفاتيح الكتالوج من §2.
 * ⚠️ عمود المفتاح وحده — لا عمود «السجل المحمي» الذي يحمل أسماء مجموعات
 *    بنفس الصيغة (`sources` · `items` …). وجدول §2.9 عموده الأول نصّ عربي
 *    ومفتاحاه في العمودين الثاني والثالث.
 */
function readCatalogKeys(md) {
  const keys = new Set();
  const section = md.split('## 2. الكتالوج المعتمد')[1]?.split('\n## 3.')[0];
  if (!section) throw new Error('تعذّر العثور على §2 في كتالوج الصلاحيات');

  const IDENT = /^`([a-z][a-zA-Z0-9]*)`$/;
  let inAmendTable = false;

  for (const line of section.split('\n')) {
    if (line.startsWith('### ')) inAmendTable = line.includes('2.9');
    if (!line.trim().startsWith('|')) continue;
    const cells = line.split('|').map((c) => c.trim());
    // cells[0] فارغة دائماً (الشرطة الأولى)
    const candidates = inAmendTable ? [cells[2], cells[3]] : [cells[1]];
    for (const cell of candidates) {
      if (!cell) continue;
      const m = IDENT.exec(cell);
      if (m) keys.add(m[1]);
    }
  }
  return keys;
}

/**
 * المفاتيح المستخدَمة فعلاً في القواعد.
 * مسح بأقواس متوازنة لأن الوسيط قد يكون تعبيراً شرطياً يحوي أقواساً:
 *   canCancel(isWithdrawal() ? 'withdrawalCancel' : 'expenseCancel')
 */
/**
 * ★ يُزيل تعليقات القواعد قبل أي مسح.
 *
 * ⚠️ **إصلاح خلل حقيقي:** المسح النصي كان يحتسب `perm('x')` **داخل تعليق**
 *    إنفاذاً قائماً. ⛔ والتعليق ليس إنفاذاً — وهذا بالضبط الفرق بين
 *    «الشرط مذكور» و«الشرط يُنفَّذ» الذي تقوم عليه هذه البوابة.
 */
function stripComments(text) {
  return text
    .split('\n')
    .map((l) => { const i = l.indexOf('//'); return i === -1 ? l : l.slice(0, i); })
    .join('\n');
}

function readRuleKeys(rules) {
  rules = stripComments(rules);
  const keys = new Set();
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
    const args = rules.slice(start, i - 1);
    for (const lit of args.matchAll(/'([a-z][a-zA-Z0-9]*)'/g)) keys.add(lit[1]);
  }
  return keys;
}

const rules = readFileSync(RULES_PATH, 'utf8');
const catalog = readFileSync(CATALOG_PATH, 'utf8');

const catalogKeys = readCatalogKeys(catalog);
const ruleKeys = readRuleKeys(rules);

/**
 * ★ المفاتيح الإدارية — الكتالوج §2.10 (`IQ-007`).
 * ⚠️ تُكتب مرة واحدة هنا ثم تُحقَن في جدول الاستثناء أدناه، فلا تفترق نسختان.
 *
 * ★★ **وصارت ثمانية لا تسعة بحسم `IQ-015` (2026-08-24):** خرج منها
 *    **`userView`** لأن مبرِّر الاستثناء («`users` مرفوضة للكتابة») ⛔ **لا
 *    ينطبق على مفتاح قراءة أصلاً** — وقد صار له شرط قراءة حقيقي في
 *    `match /users/{userId}`. ⟵ ★ **فيُفحَص الآن كأي مفتاح عرضٍ آخر**،
 *    ولو أُسقط الشرط من القاعدة **لَفشلت هذه البوابة**.
 */
const ADMIN_KEYS = [
  'userCreate',
  'userAmend',
  'userDisable',
  'roleAssign',
  'permissionGrant',
  'sourceScopeSet',
  'roleWrite',
  'roleDelete',
];

/**
 * ★ ADR-0013 القاعدة 2 — مفاتيح **انتقل إنفاذها إلى الدالة الكاتبة**.
 *
 * ⛔ ليست فجوة: مسارها في القواعد **مغلق تماماً** (`allow create, update:
 *    if false`)، فلا كتابة تمرّ بلا دالة. والدالة تفحص المفتاح **في الكود**
 *    صراحةً (ADR-0013 القاعدة 3).
 *
 * ⚠️⚠️ **وهذا يُضعِف هذه البوابة عمداً ويجب أن يُقال صراحةً:** التغطية النصية
 *    هنا لم تعد تُثبت شيئاً عن هذه الـ44 — إثباتها **في اختبارات الدالة
 *    الكاتبة**، وهو بند قبول لكل دالة (`DEBT-21`).
 */
const MOVED_TO_CLOUD_WRITE = [
  'incomingCountWrite',
  'sackTaxEnterNow',
  'sackTaxEnterLater',
  'sackRenameDisplay',
  'sackLinesEnter',
  'sackScrapWeightEnter',
  'sackLostWeightConfirm',
  'dailyPriceWrite',
  'distributionCreate',
  'distributionPriceNow',
  'distributionPriceAmend',
  'distributionPriceClear',
  'cashSaleCreate',
  'cashSaleBelowMinimum',
  'agedRemainderClear',
  'disposalCreate',
  'stocktakeWrite',
  'receiptCreate',
  'receiptBackdate',
  'receiptDepositConfirm',
  'discountCreate',
  'withdrawalCreate',
  'expenseCreate',
  'withdrawalQatPriceNow',
  'incomingCountAmend',
  'incomingCountCancel',
  'sackAmend',
  'sackCancel',
  'distributionAmend',
  'distributionCancel',
  'cashSaleAmend',
  'cashSaleCancel',
  'receiptAmend',
  'receiptCancel',
  'discountAmend',
  'discountCancel',
  'withdrawalAmend',
  'withdrawalCancel',
  'expenseAmend',
  'expenseCancel',
  'stocktakeAmend',
  'stocktakeCancel',
  'disposalAmend',
  'disposalCancel',
  // ★★ WU-002 — البيانات المرجعية الخمسة انضمّت بنفس المنطق تماماً.
  //
  // ⚠️⚠️ **والسبب هنا ليس «تمسّ المال أو المخزون»** — بل أن ثلاثة نصوص
  //    مجتمعةً لا تتحقق إلا بمعاملة سحابية واحدة: `FR-M2-03`/`FR-M3-13`/
  //    `FR-M4-13` (تعديلٌ يُسجَّل بالقيمة قبل وبعد) + `FR-M18-04`
  //    (سجل التدقيق سحابيٌّ حصراً) + `ADR-0013` القاعدة 1 (المستند وقيده
  //    معاً أو لا شيء). ⟵ **فالكتابة المباشرة كانت ستُنتج تعديلاً بلا قيد.**
  //
  // ⛔ **وإثباتها في `functions/test/master_data_test.dart`** لا هنا.
  'sourceWrite',
  'supplierWrite',
  'dealerWrite',
  'itemWrite',
  'appSettingsWrite',
  // ★★★ IQ-021 الخيار أ (2026-08-26) — مفتاح إنشاء رأس الجونية.
  //   ⛔ ولا شرط له في القواعد: مسار `sacks` مغلق أصلاً
  //   (allow create, update: if false — ADR-0013 القاعدة 2)،
  //   ⟵ فإنفاذه في `functions/lib/src/sack_intake.dart` حصراً.
  'sackCreate',
  // ★★★ IQ-020 الخيار أ (2026-08-25) — صلاحية مستقلة لا بديل عن dealerWrite.
  //   ⛔ ولا شرط لها في القواعد لسببين معاً: مسار الكتابة على `dealers`
  //   مغلق أصلاً · وشرطُها **ثلاثي** (المفتاح + إقرار نصي + رصيد مقيس داخل
  //   المعاملة) — ★ **والقاعدة لا تقرأ استعلاماً على مجموعة أخرى** أصلاً.
  //   ⟵ فإنفاذها في `functions/lib/src/master_data.dart` حصراً.
  'dealerDisableWithBalance',
];

// مفاتيح لا بيانات لها تُحمى أصلاً — الاستثناء موثَّق في الكتالوج §3.
// ⚠️ كل سطر هنا يحتاج مبرراً يصمد للمراجعة الأمنية، لا تسكيتاً للفحص.
const NOT_ENFORCED_IN_RULES = new Map([
  ['messagingSend', 'إجراء واجهة فقط — لا كتابة ولا قراءة ولا تسجيل إرسال (الكتالوج §2.8)'],
  // ★★★ IQ-032 الخيار أ (2026-08-30) — مفتاح تصدير السندات والتقارير.
  //   ⛔ وليست فجوة: `audit_log` مغلقة للكتابة للجميع بلا استثناء
  //      (allow create, update, delete: if false)، فلا مسار قاعدي يُشترَط
  //      عليه المفتاح. ⟵ وإنفاذه في العملية السحابية `logExport` صراحةً
  //      (ADR-0013 القاعدة 3) — functions/lib/src/export_log.dart.
  //   ⚠️ وإثباتُه في functions/test/export_log_test.dart لا هنا.
  [
    'documentExport',
    'IQ-032 — audit_log مغلقة للكتابة للجميع، وقيد «تصدير» تكتبه العملية'
      + ' السحابية logExport وحدها بفحص المفتاح والنطاق في الكود'
      + ' (ADR-0013 القاعدة 3 · الكتالوج §2.8).',
  ],
  // ★★★ IQ-034 الخيار ب (2026-08-30) — ستةُ مفاتيحِ عائلاتِ التقارير.
  //   ⛔ وليست فجوة: لا مجموعةَ مستقلةَ لتقريرٍ تُحمى — كلُّ تقريرٍ مُجمَّعٌ
  //      من مجموعاتٍ لها شرطُ قراءتها ونطاقُها أصلاً. وهو مبرِّر
  //      sourceNetImpactView نفسُه حرفياً (ADR-0011 §5 · الكتالوج §2.11).
  //   ⚠️⚠️ ومخاطرةٌ متبقية معلَنة — DEBT-71: العائلتان المخزنية والرقابية
  //      تقرآن مجموعاتٍ شرطُها النطاقُ وحده، فمفتاحُهما إخفاءُ شاشةٍ لا
  //      منعُ قراءة. ⛔ ولا يُدَّعى غيرُ ذلك (RISK-02).
  ...[
    'reportInventoryView',
    'reportSalesView',
    'reportFinancialView',
    'reportOutflowView',
    'reportSupplierView',
    'reportOversightView',
  ].map((k) => [
    k,
    'IQ-034 — لا مجموعةَ مستقلةَ لتقريرٍ تُحمى: التقرير مُجمَّعٌ من مجموعاتٍ'
      + ' لها شرطُ قراءتها ونطاقُها أصلاً (الكتالوج §2.11 · DEBT-71).',
  ]),
  [
    'sourceNetImpactView',
    'ADR-0011 §5 — تقرير R-23 مُجمَّع من outflow_ledger المحكوم أصلاً بـ'
      + ' withdrawalView/expenseView + النطاق. لا مجموعة مستقلة له تُحمى.',
  ],
  // ★ التسعة الإدارية — IQ-007 الخيار أ · الكتالوج §2.10 و§5.
  // ⛔ ليست فجوة: users/roles مرفوضتان للكتابة أصلاً (allow write: if false)،
  //    فلا مسار قاعدي تُشترَط عليه. وتُفحَص في الدالة السحابية صراحةً
  //    (ADR-0013 القاعدة 3) — functions/lib/src/permission_sync.dart.
  ...ADMIN_KEYS.map((k) => [
    k,
    'IQ-007 — مسار سحابي لا قاعدي: users/roles مغلقتان للكتابة، والفحص في'
      + ' الدالة المستدعاة (ADR-0013 القاعدة 3 · الكتالوج §2.10).',
  ]),
  // ★ WU-026 — الكتابة أُغلقت في القواعد، والإنفاذ في الدالة الكاتبة.
  ...MOVED_TO_CLOUD_WRITE.map((k) => [
    k,
    'ADR-0013 القاعدة 2 — مسار الكتابة مغلق في القواعد (if false)،'
      + ' والتفويض يُفحَص في الدالة الكاتبة (DEBT-21).',
  ]),
]);

// ⚠️ فجوات حقيقية محجوبة على قرار معماري لم يُعتمَد بعد.
// ⛔ لا تُعامَل استثناءً: الفحص يبقى فاشلاً حتى تُغلق — وإخفاؤها هنا
//    يعني بالضبط ادّعاء حماية غير موجودة (RISK-02).
// ⚠️ فجوات حقيقية محجوبة على قرار معماري لم يُعتمَد بعد.
// ⛔ لا تُعامَل استثناءً: الفحص يبقى فاشلاً حتى تُغلق — وإخفاؤها هنا
//    يعني بالضبط ادّعاء حماية غير موجودة (RISK-02).
//
// ✅ ★ وأُفرغت في 2026-08-24: `receiptDepositView` كان البند الوحيد فيها،
//    و★ **أُغلق فعلاً بـADR-0017** — عُزلت حقول الإيداع في
//    `receipts/{id}/deposit/current` بشرط قراءة حقيقي. ⛔ ولم يُسكَّت الفحص.
const PENDING_DECISION = new Map();

const exempted = [...catalogKeys].filter((k) => NOT_ENFORCED_IN_RULES.has(k));

const pending = [...catalogKeys].filter(
  (k) => !ruleKeys.has(k) && PENDING_DECISION.has(k),
);

const missingInRules = [...catalogKeys]
  .filter((k) => !ruleKeys.has(k))
  .filter((k) => !NOT_ENFORCED_IN_RULES.has(k) && !PENDING_DECISION.has(k));

const unknownInCatalog = [...ruleKeys].filter((k) => !catalogKeys.has(k));

console.log('فحص تغطية الصلاحيات — QTMS');
console.log('='.repeat(60));
console.log(`مفاتيح الكتالوج (§2)        : ${catalogKeys.size}`);
console.log(`مفاتيح مستخدَمة في القواعد  : ${ruleKeys.size}`);
console.log(`مستثناة بمبرر موثَّق        : ${exempted.length}`);
for (const k of exempted) console.log(`   • ${k} — ${NOT_ENFORCED_IN_RULES.get(k)}`);
console.log('-'.repeat(60));

let failed = false;

if (pending.length) {
  failed = true;
  console.error(
    `\nGAP — ${pending.length} صلاحية عرض بلا شرط قراءة، محجوبة على قرار معماري:`,
  );
  for (const k of pending) console.error(`   • ${k} — ${PENDING_DECISION.get(k)}`);
  console.error(
    '   ⛔ السبب التقني: قواعد الحماية تمنح أو تمنع المستند كاملاً ولا تُخفي\n' +
      '      حقلاً داخله — فالإخفاء اليوم واجهة لا حماية (RISK-02).\n' +
      '   ⚠️ هذا بند القبول 7 في security-requirements.md §5 — لا يُنشَر بدونه.',
  );
}

if (missingInRules.length) {
  failed = true;
  console.error(
    `\nFAIL ③ — ${missingInRules.length} مفتاح في الكتالوج بلا شرط في القواعد:`,
  );
  for (const k of missingInRules) console.error(`   • ${k}`);
  console.error('   ⛔ صلاحية بلا قاعدة = غير مُنفَّذة أمنياً (BR-M1-07).');
} else {
  console.log('PASS ③ — كل مفتاح في الكتالوج له شرط في القواعد.');
}

if (unknownInCatalog.length) {
  failed = true;
  console.error(
    `\nFAIL ⑤ — ${unknownInCatalog.length} شرط في القواعد على مفتاح غير مُعرَّف:`,
  );
  for (const k of unknownInCatalog) console.error(`   • ${k}`);
  console.error('   ⛔ شرط على مفتاح غير موجود يُقرأ null فيسقط الفحص بصمت.');
} else {
  console.log('PASS ⑤ — لا شرط في القواعد على مفتاح خارج الكتالوج.');
}

console.log('='.repeat(60));
if (failed) {
  console.error('النتيجة: فشل — عالِج ما سبق قبل أي دمج.');
  process.exit(1);
}
console.log('النتيجة: نجح — التغطية متطابقة في الاتجاهين.');

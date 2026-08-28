/**
 * قياس أثر `perm()` على زمن الاستجابة — على **قاعدة حقيقية**
 * ★ معيار القبول 5 في `WU-026`، الشطر الثاني: «على المحاكي **والقاعدة
 *   الحقيقية**» — والرقم المطلوب هو **③-ب** في
 *   `ADR-0016` §«كلفة القراءة».
 *
 * ═══════════════════════════════════════════════════════════════════════
 * ★ **تصميم القياس — زوج مضبوط في القواعد المنشورة نفسها**
 *
 *   الذراع أ:  receipts/{id}                 ← `allow read: if isSignedIn()`
 *   الذراع ب:  receipts/{id}/deposit/current ← `allow read: if perm(...)`
 *
 *   ⟵ نفس القاعدة، نفس الشجرة، نفس الرحلة الشبكية. ★ **والفارق الوحيد
 *     بينهما هو `perm()`** — فطرحُ الوسيطين يعزل كلفتها **عارية**.
 *
 * ═══════════════════════════════════════════════════════════════════════
 * ⛔ **طريق مسدود جُرِّب فوُثِّق — فلا يُعاد** (2026-08-24):
 *   واجهة اختبار القواعد الرسمية (`firebaserules.projects.test`)
 *   **لا تُقيّم على القاعدة الحقيقية**؛ فأي `exists()`/`get()` فيها يفشل بـ
 *   `Function not found error: Name: [exists]` ما لم تُمرَّر `functionMocks`.
 *   ⟵ ★ **فهي لا تصلح بديلاً عن جلسة مصادَقة بحال.**
 *
 * ═══════════════════════════════════════════════════════════════════════
 * ⚠️ **يُشغَّل على التجريبية وحدها** — ⛔ ولا يُشغَّل على الإنتاج.
 *
 * التشغيل:
 *     node measure-real-read-cost.mjs [projectId]
 *
 * المتطلبات: `gcloud` و`firebase` مسجّلا الدخول · Node 18+.
 * ★ والأداة **تُنظّف أثرها بنفسها** في النهاية (بطاقة الفحص وحسابه).
 */

import { execFileSync } from 'node:child_process';

const PROJECT = process.argv[2] ?? 'qtms-orimind-master';
const PROBE_UID = 'WU026-LATENCY-PROBE';
const SAMPLES = Number(process.env.SAMPLES ?? 40);

if (PROJECT.includes('c001')) {
  console.error('⛔ توقّف: هذه الأداة لا تُشغَّل على الإنتاج.');
  process.exit(1);
}

const sh = (cmd) => execFileSync(cmd, { encoding: 'utf8', shell: true }).trim();

const adminToken = () => sh('gcloud auth print-access-token');

/** طلب JSON مع رفع الخطأ نصّاً مفهوماً. */
async function api(url, { method = 'GET', headers = {}, body } = {}) {
  const res = await fetch(url, {
    method,
    headers: { 'Content-Type': 'application/json', ...headers },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await res.text();
  let json;
  try { json = JSON.parse(text); } catch { json = { raw: text }; }
  return { status: res.status, json };
}

console.log(`قياس أثر \`perm()\` على زمن الاستجابة — ${PROJECT}`);
console.log('='.repeat(72));

// ── ① مفتاح الواجهة — يُقرأ وقت التشغيل ⛔ ولا يُكتب في الكود ──────────
// ⚠️ ولا يُمرَّر بلا تطبيق مُحدَّد — وإلا سأل `firebase` تفاعلياً فتعلّق.
const apps = JSON.parse(sh(`firebase apps:list --project ${PROJECT} --json`)).result;
const app = apps.find((a) => a.platform === 'ANDROID') ?? apps[0];
if (!app) throw new Error('لا تطبيق مسجَّل في هذا المشروع.');
const cfg = JSON.parse(
  sh(`firebase apps:sdkconfig ${app.platform} ${app.appId} --project ${PROJECT} --json`),
).result;
// ★ الشكل الفعلي: `result.fileContents` نصّ `google-services.json`.
const gsj = JSON.parse(cfg.fileContents);
const apiKey = gsj.client?.[0]?.api_key?.[0]?.current_key;
if (!apiKey) throw new Error('تعذّر استخراج مفتاح الواجهة من إعداد التطبيق.');

// ── ② رمز مخصّص ⟵ رمز هوية (⛔ بلا كلمة مرور ولا إنشاء حساب يدوي) ─────
const SA = `firebase-adminsdk-fbsvc@${PROJECT}.iam.gserviceaccount.com`;
const now = Math.floor(Date.now() / 1000);
const payload = JSON.stringify({
  iss: SA, sub: SA,
  aud: 'https://identitytoolkit.googleapis.com/google.identity.identitytoolkit.v1.IdentityToolkit',
  iat: now, exp: now + 3600,
  uid: PROBE_UID,
  claims: { sourceScope: 'SRC-001' },
});
const signed = await api(
  `https://iamcredentials.googleapis.com/v1/projects/-/serviceAccounts/${SA}:signJwt`,
  { method: 'POST',
    headers: { Authorization: `Bearer ${adminToken()}`, 'x-goog-user-project': PROJECT },
    body: { payload } },
);
if (!signed.json.signedJwt) {
  console.error('⛔ تعذّر توقيع الرمز المخصّص:', JSON.stringify(signed.json).slice(0, 300));
  process.exit(1);
}
const signIn = await api(
  `https://identitytoolkit.googleapis.com/v1/accounts:signInWithCustomToken?key=${apiKey}`,
  { method: 'POST', body: { token: signed.json.signedJwt, returnSecureToken: true } },
);
const idToken = signIn.json.idToken;
if (!idToken) {
  console.error('⛔ تعذّر تبديل الرمز المخصّص برمز هوية:',
    JSON.stringify(signIn.json).slice(0, 300));
  process.exit(1);
}
console.log(`① جلسة مصادَقة جاهزة — uid=${PROBE_UID}`);

// ── ③ بطاقة الفحص: بها وحدها تُنفَّذ `get()` فعلاً بعد `exists()` ──────
const DOCS = `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents`;
const CARD = `${DOCS}/users/${PROBE_UID}`;
const adminHdr = () => ({
  Authorization: `Bearer ${adminToken()}`, 'x-goog-user-project': PROJECT,
});

let seeded = false;
async function cleanup() {
  if (seeded) {
    await api(CARD, { method: 'DELETE', headers: adminHdr() });
  }
  await api(`https://identitytoolkit.googleapis.com/v1/accounts:delete?key=${apiKey}`,
    { method: 'POST', body: { idToken } });
  console.log('⑤ نُظِّف الأثر — بطاقة الفحص وحسابه أُزيلا.');
}

try {
  const put = await api(CARD, {
    method: 'PATCH',
    headers: adminHdr(),
    body: { fields: { permissions: { mapValue: { fields: {
      receiptDepositView: { booleanValue: true },
    } } } } },
  });
  seeded = put.status === 200;
  console.log(`② بطاقة الفحص: ${seeded ? 'مزروعة ⟵ get() ستُنفَّذ فعلاً'
    : '⚠️ تعذّر زرعها — فالقياس يشمل exists() وحدها'}`);

  // ── ④ القياس — ذراعان متداخلان لإلغاء انجراف الشبكة ─────────────────
  const ARMS = [
    { key: 'أ', label: 'receipts/{id}          — isSignedIn() · صفر استدعاء',
      url: `${DOCS}/receipts/WU026-PROBE` },
    { key: 'ب', label: 'receipts/{id}/deposit  — perm() · استدعاءا وصول',
      url: `${DOCS}/receipts/WU026-PROBE/deposit/current` },
  ];
  const samples = { 'أ': [], 'ب': [] };
  const statuses = { 'أ': new Set(), 'ب': new Set() };

  process.stdout.write(`③ القياس — ${SAMPLES} عيّنة لكل ذراع: `);
  for (let i = 0; i < SAMPLES; i++) {
    for (const arm of ARMS) {
      const t0 = process.hrtime.bigint();
      // eslint-disable-next-line no-await-in-loop
      const r = await api(arm.url, { headers: { Authorization: `Bearer ${idToken}` } });
      samples[arm.key].push(Number(process.hrtime.bigint() - t0) / 1e6);
      statuses[arm.key].add(r.status);
    }
    if ((i + 1) % 5 === 0) process.stdout.write('.');
  }
  console.log(' تمّ');

  const med = (xs) => { const s = [...xs].sort((a, b) => a - b); const m = s.length >> 1;
    return s.length % 2 ? s[m] : (s[m - 1] + s[m]) / 2; };
  const pc = (xs, p) => [...xs].sort((a, b) => a - b)[Math.floor((xs.length - 1) * p)];

  console.log('-'.repeat(72));
  console.log('الذراع |  الوسيط |    p90  | الرمز | الوصف');
  for (const arm of ARMS) {
    const s = samples[arm.key];
    console.log(`   ${arm.key}   | ${med(s).toFixed(1).padStart(6)}ms | ` +
      `${pc(s, 0.9).toFixed(1).padStart(6)}ms | ${[...statuses[arm.key]].join(',')}` +
      `   | ${arm.label}`);
  }

  // ★★ فحص صحّة لا تجميل: الذراع ب يجب أن يكون **مسموحاً** (404 = القاعدة
  //    مرّت والمستند غائب). ⛔ فلو كان 403 لَتوقّف التقييم عند `perm()`
  //    ولَقِسنا رفضاً لا كلفةَ قراءة — ★ والرقم حينها بلا معنى.
  const armB = [...statuses['ب']];
  const bAllowed = armB.every((c) => c === 404);
  console.log('-'.repeat(72));
  console.log(`★ صحّة القياس: الذراع ب ${bAllowed
    ? 'مسموح (404) ⟵ perm() نُفِّذت كاملةً: exists() ثم get() على بطاقة موجودة'
    : `⛔ رموزه ${armB.join(',')} — فإن كان 403 فالقياس رفضٌ لا قراءة`}`);

  // ★★ الإحصاء المُقترَن — لا فارق وسيطين. كل عيّنة (ب−أ) في نفس اللحظة،
  //    ⟵ فانجراف الشبكة يُلغى **داخل الزوج** لا بالمتوسط.
  const pairs = samples['ب'].map((b, i) => b - samples['أ'][i]);
  const dPaired = med(pairs);
  const dMedians = med(samples['ب']) - med(samples['أ']);
  const spread = pc(samples['أ'], 0.9) - med(samples['أ']);

  console.log('-'.repeat(72));
  console.log(`★★ ③-ب — كلفة \`perm()\` [الفارق المُقترَن، وهو الأدقّ] : ${dPaired.toFixed(1)}ms`);
  console.log(`   وللمقارنة: فارق الوسيطين                            : ${dMedians.toFixed(1)}ms`);
  console.log(`   نطاق الفوارق المُقترَنة p10…p90                      : ` +
    `${pc(pairs, 0.1).toFixed(1)}ms … ${pc(pairs, 0.9).toFixed(1)}ms`);
  console.log('-'.repeat(72));
  console.log(`⚠️ أرضية الضجيج: تشتّت الذراع أ وحده (p90 − الوسيط) = ${spread.toFixed(1)}ms`);
  console.log(`   ⟵ ${Math.abs(dPaired) < spread
    ? '★ والكلفة **أصغر من تشتّت الشبكة نفسه** — فتُقرأ رتبةَ مقدار لا رقماً دقيقاً.'
    : 'والكلفة أكبر من التشتّت ⟵ إشارة معتبرة.'}`);
  console.log(`   (${SAMPLES} عيّنة متداخلة على قاعدة حقيقية)`);
  console.log('='.repeat(72));
} finally {
  await cleanup();
}

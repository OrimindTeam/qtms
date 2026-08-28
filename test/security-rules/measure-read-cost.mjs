/**
 * قياس كلفة قراءة بطاقة المستخدم — ★ معيار القبول 5 في `WU-026`
 *
 * ★ **الغرض:** قياس الرقمين ① و② من `ADR-0016` §«كلفة القراءة» **بالتشغيل
 *   لا بالادّعاء**:
 *
 *     ① الحدّ الفعلي لاستدعاءات الوصول للمستندات في تقييم قاعدة واحد.
 *     ② هل `get()` المكرّرة على **نفس المسار** تُحتسَب مرة واحدة؟
 *
 * ★ **لماذا هذا قياسٌ حقيقي لا اختبار شكلي:** القاعدة نفسها هي المقياس.
 *   إن لم يكن هناك تخزين مؤقت، فـ`perm()` المكرّرة N مرة تستهلك ~2N استدعاء
 *   وصول، **فتتجاوز الحدّ وتفشل**. ⟵ **فنجاحها عند N كبيرة برهانٌ قاطع على
 *   التخزين المؤقت**، وفشل الحالة المقابلة (مسارات مختلفة) يُعطي الحدّ نفسه.
 *
 * ⛔ **ولا يقيس الرقم ③** (الفوترة وزمن الاستجابة) — يحتاج قاعدة حقيقية.
 *
 * يعمل داخل `firebase emulators:exec` عبر:
 *     node run-rules-tests.mjs "node measure-read-cost.mjs"
 */

import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc } from 'firebase/firestore';

const HERE = dirname(fileURLToPath(import.meta.url));

/** يبني قواعد فحص: قراءة `probe/x` تستدعي `get()` بعدد وشكل محددين. */
function probeRules({ calls, samePath }) {
  const conditions = Array.from({ length: calls }, (_, i) => {
    const path = samePath
      ? "/databases/$(database)/documents/users/$(request.auth.uid)"
      : `/databases/$(database)/documents/probe_src/D${i}`;
    return `get(${path}).data.n == ${samePath ? 1 : i}`;
  }).join('\n        && ');

  return `rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /probe/{docId} {
      allow read: if ${conditions};
    }
    match /{document=**} {
      allow read, write: if false;
    }
  }
}`;
}

/** يحاول قراءة `probe/x` بقواعد معطاة — ويعيد true إن سُمح. */
async function attempt({ calls, samePath }) {
  const env = await initializeTestEnvironment({
    projectId: 'demo-qtms',
    firestore: {
      rules: probeRules({ calls, samePath }),
      host: '127.0.0.1',
      port: 8080,
    },
  });
  try {
    await env.clearFirestore();
    await env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(doc(db, 'users', 'U1'), { n: 1 });
      await setDoc(doc(db, 'probe', 'x'), { v: 1 });
      for (let i = 0; i < calls; i++) {
        await setDoc(doc(db, 'probe_src', `D${i}`), { n: i });
      }
    });
    const db = env.authenticatedContext('U1').firestore();
    await getDoc(doc(db, 'probe', 'x'));
    return true;
  } catch {
    return false;
  } finally {
    await env.cleanup();
  }
}

console.log('قياس كلفة قراءة بطاقة المستخدم — ADR-0016 §«كلفة القراءة»');
console.log('='.repeat(64));

// ── ① الحدّ الفعلي: مسارات مختلفة، فلا تخزين مؤقت يُخفّف ──────────────
let limit = 0;
for (let n = 1; n <= 24; n++) {
  // eslint-disable-next-line no-await-in-loop
  if (await attempt({ calls: n, samePath: false })) limit = n;
  else break;
}
console.log(`① الحدّ الفعلي لاستدعاءات الوصول (مسارات مختلفة) : ${limit}`);

// ── ② التخزين المؤقت: نفس المسار، بعدد يتجاوز الحدّ بكثير ─────────────
const SAME = 40;
const cached = await attempt({ calls: SAME, samePath: true });
console.log(`② ${SAME} استدعاءً على **نفس المسار**                   : ` +
  `${cached ? 'نجح ⟵ يُحتسَب مرة واحدة' : 'فشل ⟵ لا تخزين مؤقت'}`);

console.log('-'.repeat(64));
console.log(`★ الخلاصة: التخزين المؤقت ${cached ? 'مُثبَت' : 'غير مُثبَت'}` +
  ` · والحدّ ${limit} استدعاءً.`);
console.log(`★ و\`perm()\` تستهلك **استدعاءين ثابتين** (exists + get) مهما` +
  ` تكرّرت — فالهامش المتبقي ${limit - 2} استدعاءً.`);
console.log('⛔ والرقم ③ (الفوترة وزمن الاستجابة) يحتاج قاعدة حقيقية.');
console.log('='.repeat(64));

if (!cached) {
  console.error('⛔ فشل: لا تخزين مؤقت — وADR-0016 §«كلفة القراءة» بُني عليه.');
  process.exit(1);
}

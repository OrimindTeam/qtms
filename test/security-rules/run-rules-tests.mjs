/**
 * مُشغِّل اختبارات قواعد الحماية — QTMS
 *
 * ★ الغرض: تشغيل `firebase emulators:exec` بمحيط تشغيل صالح على كل منصّة،
 *   ومعالجة عائقين حقيقيين رُصدا على جهاز التطوير (`DEBT-10`):
 *
 *     ① **إصدار Java** — `firebase-tools` ≥ 15 يرفض أي إصدار قبل 21.
 *     ② ★ **مجلد مقابس `AF_UNIX`** — منذ JDK 16 يبني `Selector.open()`
 *        آلية إيقاظه على مقبس `AF_UNIX` يُنشَأ داخل `TEMP`. وعلى هذا الجهاز
 *        ينجح `bind` ويفشل `connect` بـ`Invalid argument` لكل مسار تحت
 *        `%LOCALAPPDATA%` — وإليه يشير `TEMP` افتراضياً — فلا يبدأ المحاكي
 *        إطلاقاً برسالة `Unable to establish loopback connection`.
 *
 * ⛔ العلّة ليست جدار حماية ولا حجب اتصال محلي: اتصال `TCP` على `127.0.0.1`
 *    ينجح، و`AF_UNIX` نفسه ينجح خارج `%LOCALAPPDATA%`. ولذلك الحل هنا
 *    **توجيه مجلد المقابس** لا تعطيل أي حماية.
 *
 * ★ التوجيه يُطبَّق على Windows فقط، ولا يُغيَّر شيء على المنصّات الأخرى —
 *   فيبقى سلوك CI على Linux كما هو تماماً.
 *
 * المراجع: `docs/07-development/build-and-run-instructions.md` §3 ·
 *          `docs/07-development/troubleshooting-guide.md` ·
 *          `docs/03-architecture/risks-and-technical-debt-register.md` `DEBT-10`
 */

import { spawn, spawnSync } from 'node:child_process';
import { existsSync, mkdirSync, readdirSync, rmSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const HERE = dirname(fileURLToPath(import.meta.url));
const ROOT = join(HERE, '..', '..');

/** الحد الأدنى الذي يفرضه `firebase-tools` ≥ 15. */
const MIN_JAVA_MAJOR = 21;

/**
 * يقرأ الإصدار الأكبر لـJava من مسار جذر JDK (أو من `java` على المسار).
 * يعيد `null` إن تعذّر التشغيل أو تعذّرت قراءة الإصدار.
 */
function javaMajor(javaHome) {
  const bin = javaHome ? join(javaHome, 'bin', 'java') : 'java';
  const res = spawnSync(bin, ['-version'], { encoding: 'utf8' });
  if (res.error || res.status !== 0) return null;
  // `java -version` يكتب على stderr في كل الإصدارات.
  const m = /version "(\d+)(?:\.(\d+))?/.exec(`${res.stderr}${res.stdout}`);
  if (!m) return null;
  const major = Number(m[1]);
  // صيغة 1.8 القديمة: الرقم الفعلي في المجموعة الثانية.
  return major === 1 ? Number(m[2]) : major;
}

/**
 * يختار JDK بإصدار كافٍ. الأولوية صريحة ومطبوعة، بلا اختيار صامت:
 *   ① `QTMS_JAVA_HOME` ② `JAVA_HOME` ③ `java` على المسار ④ مواضع شائعة.
 */
function resolveJava() {
  const candidates = [
    ['QTMS_JAVA_HOME', process.env.QTMS_JAVA_HOME],
    ['JAVA_HOME', process.env.JAVA_HOME],
    ['PATH', null],
  ];

  if (process.platform === 'win32') {
    candidates.push(
      ['Android Studio JBR', 'C:\\Program Files\\Android\\Android Studio\\jbr'],
      ['JetBrains Toolbox JBR', join(process.env.LOCALAPPDATA ?? '', 'Programs', 'Android Studio', 'jbr')],
    );
  }

  for (const [label, home] of candidates) {
    if (label !== 'PATH' && !home) continue;
    if (home && !existsSync(home)) continue;
    const major = javaMajor(home);
    if (major !== null && major >= MIN_JAVA_MAJOR) {
      return { label, home, major };
    }
  }
  return null;
}

/**
 * ★ مجلد مقابس `AF_UNIX` — خارج `%LOCALAPPDATA%` عمداً (البند ② أعلاه).
 * يُنظَّف من مقابس التشغيلات السابقة حتى لا يتراكم فيه شيء.
 */
function prepareSocketDir() {
  const dir = join(HERE, '.tmp');
  mkdirSync(dir, { recursive: true });
  for (const name of readdirSync(dir)) {
    if (name.startsWith('socket_')) {
      try {
        rmSync(join(dir, name), { force: true });
      } catch {
        // مقبس ما زال مستخدَماً من عملية أخرى — يُترَك، ولا يمنع التشغيل.
      }
    }
  }
  return dir;
}

const java = resolveJava();
if (!java) {
  console.error(
    `\n⛔ لم يُعثر على Java ${MIN_JAVA_MAJOR}+ — و\`firebase-tools\` يرفض ما قبله.\n` +
      '   عيّن `QTMS_JAVA_HOME` أو `JAVA_HOME` على جذر JDK 21 أو أحدث.\n',
  );
  process.exit(1);
}

const env = { ...process.env };
if (java.home) {
  env.JAVA_HOME = java.home;
  env.PATH = `${join(java.home, 'bin')}${process.platform === 'win32' ? ';' : ':'}${env.PATH ?? ''}`;
}

let socketDir = null;
if (process.platform === 'win32') {
  socketDir = prepareSocketDir();
  // ★ الجذر: JDK يقرأ مجلد مقابس AF_UNIX من متغيّري البيئة لا من
  //   `java.io.tmpdir` ولا من `jdk.nio.channels.unixdomain.tmpdir` — جُرِّب
  //   الثلاثة، ووحدهما `TEMP`/`TMP` غيّرا السلوك فعلياً.
  env.TEMP = socketDir;
  env.TMP = socketDir;
}

console.log(`Java   : ${java.major} (من ${java.label})`);
if (socketDir) console.log(`مقابس : ${socketDir}`);
console.log('');

// ⛔ `--test-concurrency=1` إلزامي: كل ملف اختبار يعمل في عملية مستقلة
//    ويستدعي `clearFirestore()` قبل كل اختبار على **المحاكي نفسه** — فتشغيل
//    ملفين بالتوازي يمسح أحدهما بيانات الآخر تحت قدميه.
// ★ يقبل أمراً داخلياً بديلاً كوسيط — ليُعاد استخدام نفس محيط التشغيل
//   (Java 21 + توجيه مقابس AF_UNIX) لأدوات القياس لا للاختبارات وحدها.
//   ⛔ وبلا وسيط يبقى السلوك الافتراضي كما هو تماماً.
const inner = process.argv[2]
  ?? 'node --test --test-concurrency=1 rules.test.js permission-matrix.test.js';
const args = [
  'emulators:exec',
  '--only', 'firestore',
  '--project', 'demo-qtms',
  '--config', join(ROOT, 'firebase.json'),
  inner,
];

// ★ على Windows يلزم `shell` ليُعثر على `firebase.cmd`، لكن الغلاف يدمج
//   الوسائط بلا اقتباس — فيلتهم `emulators:exec` وسائطَ الأمر الداخلي
//   (`--test`) بوصفها وسائطه هو. لذلك يُقتبَس هنا صراحةً.
const isWin = process.platform === 'win32';
const child = isWin
  ? spawn(['firebase', ...args.map((a) => (a.includes(' ') ? `"${a}"` : a))].join(' '), {
      cwd: HERE,
      env,
      stdio: 'inherit',
      shell: true,
    })
  : spawn('firebase', args, { cwd: HERE, env, stdio: 'inherit' });

child.on('error', (err) => {
  console.error(`\n⛔ تعذّر تشغيل \`firebase\`: ${err.message}\n`);
  process.exit(1);
});
child.on('exit', (code) => process.exit(code ?? 1));

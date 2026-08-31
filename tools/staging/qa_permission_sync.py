# -*- coding: utf-8 -*-
"""مزامنةُ صلاحيات حساب QA التجريبي — تنفيذُ `RB-staging-qa-account` §4.

★ **التشغيل من جذر المستودع:**

    python tools/staging/qa_permission_sync.py

⛅ **التجريبية `qtms-orimind-master` حصراً** (`AM-004`) — ⛔⛔ **ولا نظير له
على الإنتاج.**

⛔⛔★★★ **ولا قيمةَ سرٍّ تُطبَع ولا تُعاد إطلاقاً:** ★ **الاعتماد يُقرأ داخل
هذه العملية وحدها** من `.secrets/qtms-staging-owner.env` **ومفتاحُ العميل من
`android/app/google-services.json`** — ⟵ **والمطبوعُ رموزُ حالةٍ وأعدادٌ
وقيمٌ منطقية لا غير**، ★ **ومع ذلك يمرّ كلُّ مخرَجٍ على [safe] حزاماً ثانياً.**

★★ **ولماذا يُقلِع المالكُ أولاً:** `BR-M1-03` **تسقُف المنح بصلاحيات
المُنفِّذ** — ⟵ **فمفتاحٌ جديدٌ في الكتالوج لا يملكه أحد**، ⛔ **ولا يمنحه
أحدٌ لأحد**: ★ **و`bootstrapOwnerPermissions` هو الجذر الوحيد الذي يُدخِله
النظام** (`IQ-023` الخيار أ). ⛔⛔ **ولا يُمنَح الحسابُ نفسَه**
(`authentication-policy.md` §3) — ★ **فالفاعل المالك والمستهدَف حسابُ QA.**
"""
import io, json, os, re, sys, urllib.request, urllib.error, uuid

sys.stdout.reconfigure(encoding='utf-8')

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
QA_UID = 'mjmK8owk4ZaciYT2yj1711jRgWB3'
OWNER_UID = 'fj7BDnSxHkfiSwU7SjNXp7gKgXv2'   # ★ معرّف لا سرّ — environments.md §1.3
PROJECT = 'qtms-orimind-master'

SECRET_TOKENS = []          # ⛔ كلُّ ما لا يجوز أن يظهر في أي مخرَج


def env_of(path):
    out = {}
    with io.open(path, encoding='utf-8') as fh:
        for line in fh:
            line = line.strip()
            if not line or line.startswith('#') or '=' not in line:
                continue
            k, v = line.split('=', 1)
            out[k.strip()] = v.strip().strip('"').strip("'")
    return out


def safe(text):
    """يُنقّي أي مخرَج من كل قيمةٍ سرّية قبل طباعته — حزامٌ ثانٍ لا وحيد."""
    for tok in SECRET_TOKENS:
        if tok and len(tok) > 3:
            text = text.replace(tok, '<محجوب>')
    return text


def post(url, payload, token=None):
    body = json.dumps(payload).encode('utf-8')
    headers = {'Content-Type': 'application/json'}
    if token:
        headers['Authorization'] = 'Bearer ' + token
    req = urllib.request.Request(url, data=body, headers=headers, method='POST')
    try:
        with urllib.request.urlopen(req, timeout=90) as resp:
            return resp.status, resp.read().decode('utf-8')
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode('utf-8')


def get(url, token):
    req = urllib.request.Request(url, headers={'Authorization': 'Bearer ' + token})
    try:
        with urllib.request.urlopen(req, timeout=90) as resp:
            return resp.status, resp.read().decode('utf-8')
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode('utf-8')


# ── ① الاعتماد والمعرّفات — تُقرأ ولا تُطبَع ─────────────────────────────
owner = env_of(os.path.join(ROOT, '.secrets/qtms-staging-owner.env'))
email = next(v for k, v in owner.items() if 'EMAIL' in k.upper())
password = next(v for k, v in owner.items() if 'PASSWORD' in k.upper())
SECRET_TOKENS += [email, password]

# ⛔⛔★★★ **ونكهةُ التجريبية وحدها** — ★ **`android/app/google-services.json`
#    هو ملفُّ الإنتاج `qtms-orimind-c001`**: ⟵ **ورمزٌ صادرٌ عنه يُرفَض من
#    خدمة التجريبية بـ`INVALID_ID_TOKEN`** (**مقيسٌ لا مفترَض · 2026-08-30**)،
#    ⛔⛔ **والأسوأ أنه يوجّه تسجيل الدخول إلى الإنتاج بلا قصد.**
GS = os.path.join(ROOT, 'android/app/src/staging/google-services.json')
with io.open(GS, encoding='utf-8') as fh:
    gs = json.load(fh)
if gs['project_info']['project_id'] != PROJECT:
    print('ABORT — ملفُّ الإعداد لا يخصّ التجريبية:', gs['project_info']['project_id'])
    sys.exit(1)
api_key = gs['client'][0]['api_key'][0]['current_key']
SECRET_TOKENS.append(api_key)

base = env_of(os.path.join(ROOT, 'config/qtms-public-defines.env'))['QTMS_FUNCTIONS_BASE_URL'].rstrip('/')

# ── ② تسجيل دخول المالك — ★ الرمزُ لا يُطبَع ────────────────────────────
status, raw = post(
    'https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=' + api_key,
    {'email': email, 'password': password, 'returnSecureToken': True},
)
if status != 200:
    print('signIn FAILED', status, safe(raw)[:300])
    sys.exit(1)
auth = json.loads(raw)
id_token = auth['idToken']
SECRET_TOKENS.append(id_token)
SECRET_TOKENS.append(auth.get('refreshToken', ''))
print('① signIn -> 200 · uid_matches_registered_owner =', auth['localId'] == OWNER_UID)
if auth['localId'] != OWNER_UID:
    # ⛔⛔ **ولا خطوةَ بعدها** — ★ **`bootstrapOwnerPermissions` تُقاس بالهوية
    #    وحدها**، ⟵ **ونداؤها بحسابٍ آخر «حادثة أمنية P0» بنصّ الرَنبوك §7.**
    print('ABORT — الحساب الداخل ليس مالكَ التجريبية المسجَّل')
    sys.exit(1)

# ── ③ إقلاع المالك — ★ الجذرُ الوحيد الذي يملك المفتاح الجديد ──────────
status, raw = post(base + '/bootstrapOwnerPermissions',
                   {'data': {'requestId': 'qa-sync-' + str(uuid.uuid4())}},
                   token=id_token)
print('② bootstrapOwnerPermissions ->', status, safe(raw)[:400])

# ── ④ المجموعة الكاملة من §2 — تُشتقّ من `Permission` لحظةَ التنفيذ ─────
src = io.open(os.path.join(ROOT, 'packages/qtms_domain/lib/capabilities/identity_access/domain/permission.dart'),
              encoding='utf-8').read()
body = src[src.index('enum Permission {'):]
body = body[:body.index('\n}')]
keys = re.findall(r'^\s{2}([a-z][A-Za-z]*)[,;]\s*$', body, re.M)
print('③ catalog keys =', len(keys), '· documentExport =', 'documentExport' in keys)

# ── ⑤ المنح — المجموعة كاملةً لا فرقاً (`RB` §0 البند ④) ───────────────
status, raw = post(base + '/grantPermissions',
                   {'data': {'requestId': 'qa-sync-' + str(uuid.uuid4()),
                             'userId': QA_UID,
                             'permissions': keys,
                             'sourceScope': 'all'}},
                   token=id_token)
print('④ grantPermissions ->', status, safe(raw)[:400])

# ── ⑥ التحقق — قراءةُ بطاقة الحساب من التجريبية ────────────────────────
status, raw = get(
    'https://firestore.googleapis.com/v1/projects/{}/databases/(default)/documents/users/{}'.format(PROJECT, QA_UID),
    id_token)
if status != 200:
    print('⑤ read users/QA ->', status, safe(raw)[:300])
else:
    doc = json.loads(raw)['fields']
    perms = doc.get('permissions', {}).get('mapValue', {}).get('fields', {})
    granted = sorted(k for k, v in perms.items() if v.get('booleanValue') is True)
    print('⑤ users/QA -> 200 · permissions_true =', len(granted),
          '· documentExport =', 'documentExport' in granted,
          '· isActive =', doc.get('isActive', {}).get('booleanValue'),
          '· sourceScope =', doc.get('sourceScope', {}).get('stringValue'))

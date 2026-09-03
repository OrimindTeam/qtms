# -*- coding: utf-8 -*-
"""قراءةُ بطاقةِ رصيدِ نوعٍ في يوم من التجريبية — **للقراءة فقط**.

★ **التشغيل من جذر المستودع:**

    python tools/staging/read_item_daily_balance.py SRC-001 ITM-0003 20260901

⛅ **التجريبية `qtms-orimind-master` حصراً** — ⛔⛔ **ولا نظير له على الإنتاج.**

═══════════════════════════════════════════════════════════════════════════
⛔⛔★★★ **ولماذا لزم — مقيسٌ لا نظري:** ★ **الإلغاء يَسِم الحركة `isCancelled`
ثم يُعيد بناءَ الرصيد** (`ADR-0008` · `A-14`) — ⟵ **والشاشةُ تعرض مجموعَ
اليوم**، ⛔ **ولا تعرض مستندَ `item_daily_balances` نفسَه بحقوله**: ★ **فبقي
«أُعيد بناؤه» ادّعاءً حتى يُقرأ المستند** (بروتوكول التشغيل §و).

⛔⛔★★★ **وقراءةٌ محضة — ⛔ ولا كتابةَ حرفٍ واحد:** ★ **`GET` وحدها**،
⟵ **ولا `POST` إلا لتسجيل الدخول.**

⛔⛔★★★ **ولا قيمةَ سرٍّ تُطبَع ولا تُعاد إطلاقاً** — ★ **بنفس ضمانات
`verify_outflow_write.py` حرفياً** (`AM-004` · `environments.md` §1.5).
═══════════════════════════════════════════════════════════════════════════
"""
import io, json, os, sys, urllib.request, urllib.error

sys.stdout.reconfigure(encoding='utf-8')

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PROJECT = 'qtms-orimind-master'
DB = 'https://firestore.googleapis.com/v1/projects/%s/databases/(default)/documents' % PROJECT

SECRET_TOKENS = []


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
    for tok in SECRET_TOKENS:
        if tok and len(tok) > 3:
            text = text.replace(tok, '<محجوب>')
    return text


def post(url, payload):
    body = json.dumps(payload).encode('utf-8')
    req = urllib.request.Request(
        url, data=body, headers={'Content-Type': 'application/json'}, method='POST'
    )
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


def plain(value):
    """يفكّ تغليف Firestore إلى قيمةٍ مقروءة — ⛔ بلا تفسيرٍ ولا تقريب."""
    if not isinstance(value, dict):
        return value
    for key in ('stringValue', 'booleanValue', 'timestampValue'):
        if key in value:
            return value[key]
    if 'integerValue' in value:
        return int(value['integerValue'])
    if 'doubleValue' in value:
        return value['doubleValue']
    if 'nullValue' in value:
        return None
    if 'arrayValue' in value:
        return [plain(v) for v in value['arrayValue'].get('values', [])]
    if 'mapValue' in value:
        return {k: plain(v) for k, v in value['mapValue'].get('fields', {}).items()}
    return value



source_id = sys.argv[1] if len(sys.argv) > 1 else 'SRC-001'
compact = sys.argv[2] if len(sys.argv) > 2 else '20260903'

# ── ① اعتمادُ حساب QA — يُقرأ ولا يُطبَع ──────────────────────────────
qa = env_of(os.path.join(ROOT, '.secrets/qtms-staging-qa-account.env'))
email = next(v for k, v in qa.items() if 'EMAIL' in k.upper())
password = next(v for k, v in qa.items() if 'PASSWORD' in k.upper())
SECRET_TOKENS += [email, password]

GS = os.path.join(ROOT, 'android/app/src/staging/google-services.json')
with io.open(GS, encoding='utf-8') as fh:
    gs = json.load(fh)
# ⛔⛔ **فخُّ `google-services.json` — يُقاس ولا يُظنّ** (بروتوكول التشغيل §ز.3).
if gs['project_info']['project_id'] != PROJECT:
    print('ABORT — ملفُّ الإعداد لا يخصّ التجريبية:', gs['project_info']['project_id'])
    sys.exit(1)
api_key = gs['client'][0]['api_key'][0]['current_key']
SECRET_TOKENS.append(api_key)

status, raw = post(
    'https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=' + api_key,
    {'email': email, 'password': password, 'returnSecureToken': True},
)
if status != 200:
    print('signIn FAILED', status, safe(raw)[:300])
    sys.exit(1)
token = json.loads(raw)['idToken']
SECRET_TOKENS.append(token)
print('signIn (QA) -> 200')


def show(path, label):
    status, raw = get('%s/%s' % (DB, path), token)
    print('%s  %s -> %s' % (label, path, status))
    if status != 200:
        print('   ', safe(raw)[:300])
        return None
    doc = {k: plain(v) for k, v in json.loads(raw)['fields'].items()}
    for key in sorted(doc):
        print('   %-24s = %s' % (key, safe(json.dumps(doc[key], ensure_ascii=False))))
    return doc


show('daily_summaries/%s_%s' % (source_id, compact), '①')
show('daily_summaries/all_%s' % compact, '②')
show('owner_ledger_trends/%s' % source_id, '③')
show('owner_ledger_trends/all', '④')

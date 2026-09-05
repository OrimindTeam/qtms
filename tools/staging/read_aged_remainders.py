# -*- coding: utf-8 -*-
"""قراءةُ قائمةِ المتبقي المتأخر وأرصدةِ الأيام من التجريبية — **للقراءة فقط**.

★ **التشغيل من جذر المستودع:**

    python tools/staging/read_aged_remainders.py SRC-001

⛅ **التجريبية `qtms-orimind-master` حصراً** — ⛔⛔ **ولا نظير له على الإنتاج.**

═══════════════════════════════════════════════════════════════════════════
⛔⛔★★★ **ولماذا لزم — مقيسٌ لا نظري** (`WU-019` · بروتوكول التشغيل §و):
★ **بندُ `aged_remainders` مشتقٌّ تكتبه السحابة داخل معاملة الحركة**،
⟵ **والشاشةُ تعرض مجموعَه مجمَّعاً بالأيام** ⛔ **ولا تعرض المستندَ بحقوله**:
★ **فيبقى «كُتب البند» أو «مُحي» ادّعاءً حتى يُقرأ المستند نفسُه.**

⛔⛔★★★ **وقراءةٌ محضة — ⛔ ولا كتابةَ حرفٍ واحد:** ★ **`GET` و`runQuery`
وحدهما**، ⟵ **ولا `POST` إلا لتسجيل الدخول وللاستعلام المقيَّد.**

⛔⛔★★★ **ولا قيمةَ سرٍّ تُطبَع ولا تُعاد إطلاقاً** — ★ **بنفس ضمانات
`read_item_daily_balance.py` حرفياً** (`AM-004` · `environments.md` §1.5).
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
print('① signIn (QA) -> 200')


def run_query(collection, order_field):
    """★ استعلامٌ **مقيَّدٌ بالمصدر** — ⛔ ولا سردَ غير مقيَّد (`IQ-024`)."""
    body = {
        'structuredQuery': {
            'from': [{'collectionId': collection}],
            'where': {
                'fieldFilter': {
                    'field': {'fieldPath': 'sourceId'},
                    'op': 'EQUAL',
                    'value': {'stringValue': source_id},
                }
            },
            # ★ **وترتيبٌ اختياري** — ⛔ **وبلا فهرسٍ مركّبٍ يقابله يُرفَض
            #   الاستعلام** (`indexing-strategy.md` §3 القاعدة 4): ⟵ **فما
            #   لا فهرسَ لترتيبه يُقرأ بترتيب المعرّف.**
            'orderBy': (
                [{'field': {'fieldPath': order_field}, 'direction': 'ASCENDING'}]
                if order_field
                else []
            ),
            'limit': 200,
        }
    }
    status, raw = post(DB + ':runQuery', body, token)
    if status != 200:
        print('   runQuery %s -> %s %s' % (collection, status, safe(raw)[:300]))
        return []
    rows = []
    for entry in json.loads(raw):
        document = entry.get('document')
        if not document:
            continue
        fields = {k: plain(v) for k, v in document.get('fields', {}).items()}
        fields['__id'] = document['name'].rsplit('/', 1)[-1]
        rows.append(fields)
    return rows


# ── ② قائمةُ المتبقي المتأخر المبنيّة مسبقاً ──────────────────────────
aged = run_query('aged_remainders', 'stockDate')
print('② aged_remainders (%s) -> %d مستنداً' % (source_id, len(aged)))
for row in aged:
    print(
        '   %-40s %s  %s %s'
        % (
            row['__id'],
            str(row.get('stockDate'))[:10],
            row.get('remaining'),
            row.get('unit'),
        )
    )

# ── ③ أرصدةُ الأيام كلِّها — للمقابلة ────────────────────────────────
balances = run_query('item_daily_balances', None)
print('③ item_daily_balances (%s) -> %d مستنداً' % (source_id, len(balances)))
for row in balances:
    print(
        '   %-40s %s  رصيد=%s %s'
        % (
            row['__id'],
            str(row.get('stockDate'))[:10],
            row.get('balance'),
            row.get('unit'),
        )
    )

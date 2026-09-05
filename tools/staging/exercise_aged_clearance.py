# -*- coding: utf-8 -*-
"""تشغيلُ **تصريفِ متبقٍّ متأخر** على التجريبية — `WU-019` (`FR-M8-11`).

★ **التشغيل من جذر المستودع:**

    python tools/staging/exercise_aged_clearance.py SRC-001 "عتود - جونية رقم 1" 20260902 MQT-0001

⛅ **التجريبية `qtms-orimind-master` حصراً** — ⛔⛔ **ولا نظير له على الإنتاج.**

═══════════════════════════════════════════════════════════════════════════
⚠️⚠️★★★ **ولماذا يلزم سكربتٌ أصلاً — حدٌّ مُعلَنٌ لا التفاف:** ★ **قائمةُ
`aged_remainders` مبنيّةٌ مسبقاً تكتبها السحابةُ عند كل كتابةِ رصيد**،
⟵ **وأرصدةُ الأيام السابقة على التجريبية كُتبت *قبل* نشر الراصد**:
⟹ ⛔ **فلا بندَ في القائمة يفتح الشاشةُ عليه، والشاشةُ لا تكتب شيئاً بنفسها.**
★ **فيُشغَّل هنا أولُ تصريفٍ لبذر القائمة**، ⟵ **ثم تُقاس بقيةُ المسار من
الواجهة نفسِها على المحاكي** (بروتوكول التشغيل §د.2).

⛔⛔★★★ **ويُشغَّل كما يُشغِّله التطبيق حرفياً:** **نفسُ العنوان ونفسُ الحمولة
ونفسُ رمزِ الدخول** — ⛔ **ولا امتيازَ إداريٌّ ولا التفافٌ على حارس**:
★ **فالبوابةُ `agedClearanceRejection` تُقيَّم على هذا الطلب كما تُقيَّم على
طلب الشاشة.**

⛔⛔★★★ **وحالاتُ الرفضِ تُقاس هنا كذلك** — ⟵ **تاريخٌ مستقبليٌّ يُرفَض للجميع**،
★ **وهو ما لا تبلغه الشاشةُ أصلاً** (لا حقلَ تاريخٍ فيها).
═══════════════════════════════════════════════════════════════════════════

⛔⛔★★★ **ولا قيمةَ سرٍّ تُطبَع** — ★ **بنفس ضمانات `qa_permission_sync.py`.**
"""
import io, json, os, sys, urllib.request, urllib.error, uuid

sys.stdout.reconfigure(encoding='utf-8')

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PROJECT = 'qtms-orimind-master'
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
        with urllib.request.urlopen(req, timeout=120) as resp:
            return resp.status, resp.read().decode('utf-8')
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode('utf-8')


withdrawal = sys.argv[1] if len(sys.argv) > 1 else 'WDR-20260901-0001'
expense = sys.argv[2] if len(sys.argv) > 2 else 'EXP-20260901-0001'

qa = env_of(os.path.join(ROOT, '.secrets/qtms-staging-qa-account.env'))
email = next(v for k, v in qa.items() if 'EMAIL' in k.upper())
password = next(v for k, v in qa.items() if 'PASSWORD' in k.upper())
SECRET_TOKENS += [email, password]

GS = os.path.join(ROOT, 'android/app/src/staging/google-services.json')
with io.open(GS, encoding='utf-8') as fh:
    gs = json.load(fh)
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
base = env_of(os.path.join(ROOT, 'config/qtms-public-defines.env'))['QTMS_FUNCTIONS_BASE_URL'].rstrip('/')
print('① signIn (QA) -> 200 · base =', base)

rid = lambda: 'wu019-' + str(uuid.uuid4())

source_id = sys.argv[1] if len(sys.argv) > 1 else 'SRC-001'
item_key = sys.argv[2] if len(sys.argv) > 2 else 'عتود - جونية رقم 1'
stock_date = sys.argv[3] if len(sys.argv) > 3 else '20260902'
dealer_id = sys.argv[4] if len(sys.argv) > 4 else 'MQT-0001'
quantity = int(sys.argv[5]) if len(sys.argv) > 5 else 10
unit_price = int(sys.argv[6]) if len(sys.argv) > 6 else 700

line = {'itemId': item_key, 'quantity': quantity, 'unitPrice': unit_price}

# ── ② ✅ التصريفُ المتأخر بمفتاحه — ★ والتاريخُ في الحمولة ─────────────
status, raw = post(base + '/createDistribution', {'data': {
    'requestId': rid(),
    'sourceId': source_id,
    'dealerId': dealer_id,
    'stockDate': stock_date,
    'lines': [line],
}}, token=token)
print('② createDistribution(stockDate=%s) ->' % stock_date, status, safe(raw)[:300])

# ── ③ ⛔⛔ تاريخٌ مستقبليٌّ — مرفوضٌ لمن يملك كلَّ المفاتيح ──────────────
status, raw = post(base + '/createDistribution', {'data': {
    'requestId': rid(),
    'sourceId': source_id,
    'dealerId': dealer_id,
    'stockDate': '29991231',
    'lines': [line],
}}, token=token)
print('③ createDistribution بتاريخٍ مستقبلي ->', status, safe(raw)[:200])

# ── ④ ⛔ تاريخٌ مشوَّه — رفضُ مُدخَلٍ لا سقوطٌ صامتٌ إلى «اليوم» ─────────
status, raw = post(base + '/createDistribution', {'data': {
    'requestId': rid(),
    'sourceId': source_id,
    'dealerId': dealer_id,
    'stockDate': '2026-09-02',
    'lines': [line],
}}, token=token)
print('④ createDistribution بتاريخٍ مشوَّه ->', status, safe(raw)[:200])

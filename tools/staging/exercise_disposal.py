# -*- coding: utf-8 -*-
"""تشغيلُ **الإتلاف** على التجريبية — `WU-020` (`FR-M8-16` · `FR-M8-11`).

★ **التشغيل من جذر المستودع:**

    python tools/staging/exercise_disposal.py SRC-001 20260904

═══════════════════════════════════════════════════════════════════════════
⚠️⚠️★★★ **ولماذا يلزم سكربتٌ أصلاً — حدٌّ مُعلَنٌ لا التفاف:**

  ① ★★ **بذرُ مخزونِ اليوم** — ⟵ **خياراتُ شاشة الإتلاف من *أرصدة دفتر
     اليوم*** ([`DEBT-86`])، ⛔ **ويومُ التجريبية بلا وارد**: ⟹ **فالمنسدل
     فارغٌ ولا سبيلَ لقياس المسار من الواجهة أصلاً.**
  ② ⛔⛔ **ومساراتُ الرفضِ لا تبلغها الشاشة** — ★ **لا حقلَ تاريخٍ فيها**:
     ⟵ **فتُقاس هنا** (**مستقبليٌّ · مشوَّه · بلا مفتاح التصريف**).

⛔⛔★★★ **ويُشغَّل كما يُشغِّله التطبيق حرفياً:** **نفسُ العنوان ونفسُ الحمولة
ونفسُ رمزِ الدخول** — ⛔ **ولا امتيازَ إداريٌّ ولا التفافٌ على حارس.**

⛅ **التجريبية `qtms-orimind-master` حصراً** — ⛔⛔ **ولا نظير له على الإنتاج**
(بروتوكول التشغيل §ز).

⛔⛔★★★ **ولا قيمةَ سرٍّ تُطبَع** — ★ **بنفس ضمانات `qa_permission_sync.py`.**
═══════════════════════════════════════════════════════════════════════════
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


source_id = sys.argv[1] if len(sys.argv) > 1 else 'SRC-001'
today = sys.argv[2] if len(sys.argv) > 2 else '20260904'
item_id = sys.argv[3] if len(sys.argv) > 3 else 'ITM-0003'
seed_quantity = int(sys.argv[4]) if len(sys.argv) > 4 else 60

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
base = env_of(
    os.path.join(ROOT, 'config/qtms-public-defines.env')
)['QTMS_FUNCTIONS_BASE_URL'].rstrip('/')
print('① signIn (QA) -> 200 · base =', base)

rid = lambda: 'wu020-' + str(uuid.uuid4())

# ── ② بذرُ مخزونِ اليوم — ⟵ فخياراتُ الشاشة من الدفتر لا من الكتالوج ──
supplier_id = sys.argv[5] if len(sys.argv) > 5 else None
status, raw = post(base + '/createCountedIntake', {'data': {
    'requestId': rid(),
    'sourceId': source_id,
    'lines': [{'itemId': item_id, 'quantity': seed_quantity}],
    **({'supplierId': supplier_id} if supplier_id else {}),
}}, token=token)
print('② createCountedIntake(%s × %d) ->' % (item_id, seed_quantity), status,
      safe(raw)[:200])

# ── ③ ⛔⛔ تاريخُ مخزونٍ مستقبليٌّ — مرفوضٌ لمن يملك كلَّ المفاتيح ───────
status, raw = post(base + '/createDisposal', {'data': {
    'requestId': rid(),
    'sourceId': source_id,
    'stockDate': '29991231',
    'lines': [{'itemId': item_id, 'quantity': 1}],
}}, token=token)
print('③ createDisposal بتاريخٍ مستقبلي ->', status, safe(raw)[:200])

# ── ④ ⛔ تاريخٌ مشوَّه — رفضُ مُدخَلٍ لا سقوطٌ صامتٌ إلى «اليوم» ─────────
status, raw = post(base + '/createDisposal', {'data': {
    'requestId': rid(),
    'sourceId': source_id,
    'stockDate': '2026-09-04',
    'lines': [{'itemId': item_id, 'quantity': 1}],
}}, token=token)
print('④ createDisposal بتاريخٍ مشوَّه ->', status, safe(raw)[:200])

# ── ⑤ ⛔ كميةٌ تتجاوز الرصيد — `FR-M8-01` · `GR-11` (`ERR_STOCK_001`) ───
status, raw = post(base + '/createDisposal', {'data': {
    'requestId': rid(),
    'sourceId': source_id,
    'lines': [{'itemId': item_id, 'quantity': 999999}],
}}, token=token)
print('⑤ createDisposal بكميةٍ تتجاوز الرصيد ->', status, safe(raw)[:200])

# ── ⑥ ⛔ مصدرٌ خارج النطاق مستحيلٌ على QA (نطاقُه شامل) — فيُقاس مصدرٌ
#      لا وجودَ له: ★ والرفضُ يقع قبل أي كتابة.
status, raw = post(base + '/createDisposal', {'data': {
    'requestId': rid(),
    'sourceId': 'SRC-NOT-REAL',
    'lines': [{'itemId': item_id, 'quantity': 1}],
}}, token=token)
print('⑥ createDisposal بمصدرٍ لا وجودَ له ->', status, safe(raw)[:200])

# ── ⑦ ⛔ مستندٌ بلا سطر — لا يُتلِف شيئاً فلا معنى له ───────────────────
status, raw = post(base + '/createDisposal', {'data': {
    'requestId': rid(),
    'sourceId': source_id,
    'lines': [],
}}, token=token)
print('⑦ createDisposal بلا سطرٍ واحد ->', status, safe(raw)[:200])

print('\n★ بُذر مخزونُ اليوم — والمسارُ الناجح يُقاس من الواجهة على المحاكي '
      '(بروتوكول التشغيل §د.2).')

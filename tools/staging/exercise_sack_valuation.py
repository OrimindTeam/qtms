# -*- coding: utf-8 -*-
"""تمرينُ مُحتسِب مالية الجواني على التجريبية (`WU-015`) — **كتابةٌ ثم قراءة**.

★ **التشغيل من جذر المستودع:**

    python tools/staging/exercise_sack_valuation.py SCK-20260902-0001 SRC-001 25

⛅ **التجريبية `qtms-orimind-master` حصراً** — ⛔⛔ **ولا نظير له على الإنتاج.**

═══════════════════════════════════════════════════════════════════════════
⛔⛔★★★ **وما يُثبته هذا السكربت وما لا يُثبته — يُقرأ قبل الاعتماد عليه:**

✅ **يُثبت:** أن **الخدمة المنشورة** (`callables:wu015`) **تُطلق المُحتسِب بعد
التزام العملية الأصلية فعلاً**، وأنه **يكتب `finance/current` و
`supplier_ledger` و`supplier_balances` بالأرقام الصحيحة** — ⛅ **مقروءةً من
القاعدة بعد الكتابة** ⛔ **لا من استجابة النداء.**

⛔⛔ **ولا يُثبت:** أن **الشاشة** تعرضها — ★ **ذاك اختبارُ المحاكي §د.2**،
⛔ **ولا يُغني عنه هذا** (بروتوكول التشغيل §د: «**لا استدعاء دوالّ من داخل
اختبار**» — ★ **وهذا نداءٌ حقيقيٌّ على الخدمة الحيّة لا استدعاءُ دالة**،
⟵ **لكنه يبقى دون الواجهة**).
═══════════════════════════════════════════════════════════════════════════

⛔⛔★★★ **ولا قيمةَ سرٍّ تُطبَع** — ★ **بنفس ضمانات `verify_outflow_write.py`**
(`AM-004` · `environments.md` §1.5).
"""
import io, json, os, sys, time, urllib.request, urllib.error

sys.stdout.reconfigure(encoding='utf-8')

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PROJECT = 'qtms-orimind-master'
DB = 'https://firestore.googleapis.com/v1/projects/%s/databases/(default)/documents' % PROJECT
CALLABLES = 'https://qtms-callables-7stgg3ngga-ww.a.run.app'
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


def get(url, token):
    req = urllib.request.Request(url, headers={'Authorization': 'Bearer ' + token})
    try:
        with urllib.request.urlopen(req, timeout=90) as resp:
            return resp.status, resp.read().decode('utf-8')
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode('utf-8')


def plain(value):
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


def fields_of(raw):
    return {k: plain(v) for k, v in json.loads(raw).get('fields', {}).items()}


sack_id = sys.argv[1] if len(sys.argv) > 1 else 'SCK-20260902-0001'
source_id = sys.argv[2] if len(sys.argv) > 2 else 'SRC-001'
tax_per_kilo = int(sys.argv[3]) if len(sys.argv) > 3 else 25

# ── ① اعتمادُ حساب QA — يُقرأ ولا يُطبَع ──────────────────────────────
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
print('① signIn (QA) -> 200')

# ── ② `enterSackTax` — المسارُ المقيَّد بحقلٍ واحد (`FR-M7-27`) ───────
status, raw = post(
    '%s/enterSackTax' % CALLABLES,
    {'data': {
        'requestId': 'wu015-%d' % int(time.time()),
        'sourceId': source_id,
        'documentNumber': sack_id,
        'taxPerKilo': tax_per_kilo,
    }},
    token=token,
)
print('② POST /enterSackTax ->', status)
print('   ', safe(raw)[:300])
if status != 200:
    sys.exit(1)

# ★ **مهلةٌ قصيرة** — ⟵ **المُحتسِب يعمل بعد الالتزام داخل نفس الطلب**،
#   ⛔ **لكن القراءة تلي الاستجابة فيُترَك هامشٌ للاتّساق.**
time.sleep(2)

# ── ③ 🔒 ماليةُ الجونية بعد الاحتساب ──────────────────────────────────
status, raw = get('%s/sacks/%s/finance/current' % (DB, sack_id), token)
print('③ finance/current ->', status)
finance = {}
if status == 200:
    finance = fields_of(raw)
    print('   ', json.dumps(
        {k: finance.get(k) for k in ('taxPerKilo', 'sackTax', 'sackRevenue',
                                     'supplierNet', 'isRevenueFinal')
         if k in finance}, ensure_ascii=False))
else:
    print('   ', safe(raw)[:200])

# ── ④ 🔒 سطرُ دفتر الرعية ─────────────────────────────────────────────
status, raw = get('%s/supplier_ledger/%s' % (DB, sack_id), token)
print('④ supplier_ledger/%s ->' % sack_id, status)
ledger = {}
if status == 200:
    ledger = fields_of(raw)
    print('   ', json.dumps(
        {k: ledger.get(k) for k in ('supplierId', 'sourceId', 'sackRevenue',
                                    'sackTax', 'supplierNet', 'recalcVersion',
                                    'isRevenueFinal', 'isCancelled')
         if k in ledger}, ensure_ascii=False))
else:
    # ⛔★★ **وغيابُه مشروعٌ لجونيةٍ بلا رعوي** — `FR-M7-03`: ★ **مصدرٌ لا
    #    يشترط الرعوي لا حسابَ رعويٍّ فيه**، ⟵ **و`403` هنا غيابُ مستند**
    #    لا نقصُ صلاحية (`DEBT-40`).
    print('   ', safe(raw)[:160].replace('\n', ' '))

# ── ⑤ ⛅ رصيدُ الرعوي ─────────────────────────────────────────────────
supplier_id = ledger.get('supplierId')
if supplier_id:
    balance_id = '%s_%s' % (supplier_id, source_id)
    status, raw = get('%s/supplier_balances/%s' % (DB, balance_id), token)
    print('⑤ supplier_balances/%s ->' % balance_id, status)
    if status == 200:
        bal = fields_of(raw)
        print('   ', json.dumps(
            {k: bal.get(k) for k in ('supplierId', 'sourceId',
                                     'totalSackRevenue', 'totalSackTax',
                                     'supplierNet', 'sackCount',
                                     'pendingTaxCount', 'unfinalRevenueCount')
             if k in bal}, ensure_ascii=False))
    else:
        print('   ', safe(raw)[:160].replace('\n', ' '))
else:
    print('⑤ supplier_balances — ⛔ لا رعويَّ لهذه الجونية (FR-M7-03)')

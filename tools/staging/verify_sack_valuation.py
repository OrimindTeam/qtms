# -*- coding: utf-8 -*-
"""تحقُّقٌ **للقراءة فقط** من أثر مُحتسِب مالية الجواني على التجريبية (`WU-015`).

★ **التشغيل من جذر المستودع:**

    python tools/staging/verify_sack_valuation.py SRC-001 20260902

⛅ **التجريبية `qtms-orimind-master` حصراً** — ⛔⛔ **ولا نظير له على الإنتاج.**

═══════════════════════════════════════════════════════════════════════════
⛔⛔★★★ **ولماذا لزم — بروتوكول التشغيل §و:** ★ **`supplier_ledger` و
`supplier_balances` لا تعرضهما شاشةٌ بتفصيلهما اليوم**، ⟵ **فلا سبيل لرؤية
`recalcVersion` ولا `isRevenueFinal` بالعين من التطبيق**، ⛔ **والاكتفاء بأن
الشاشة عرضت رقماً ليس قياساً للمخزَّن.**
═══════════════════════════════════════════════════════════════════════════

⛔⛔ **وقراءةٌ محضة — ولا كتابةَ حرفٍ واحد:** ★ **`GET` و`runQuery` وحدهما**،
⟵ **ولا `POST` إلا لتسجيل الدخول.**

⛔⛔★★★ **ولا قيمةَ سرٍّ تُطبَع** — ★ **بنفس ضمانات `verify_outflow_write.py`
حرفياً** (`AM-004` · `environments.md` §1.5).
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


def fields_of(raw):
    return {k: plain(v) for k, v in json.loads(raw).get('fields', {}).items()}


source_id = sys.argv[1] if len(sys.argv) > 1 else 'SRC-001'
day = sys.argv[2] if len(sys.argv) > 2 else '20260902'
stock_date = '%s-%s-%sT00:00:00Z' % (day[0:4], day[4:6], day[6:8])

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

# ── ② جواني اليوم في هذا المصدر ───────────────────────────────────────
#
# ⛔⛔ **والاستعلام يُقيّد `sourceId` صراحةً** — `IQ-024` · `DEBT-40`.
status, raw = post('%s:runQuery' % DB, {
    'structuredQuery': {
        'from': [{'collectionId': 'sacks'}],
        'where': {'compositeFilter': {'op': 'AND', 'filters': [
            {'fieldFilter': {'field': {'fieldPath': 'sourceId'}, 'op': 'EQUAL',
                             'value': {'stringValue': source_id}}},
            {'fieldFilter': {'field': {'fieldPath': 'stockDate'}, 'op': 'EQUAL',
                             'value': {'timestampValue': stock_date}}},
        ]}},
    },
}, token=token)
print('② sacks [sourceId + stockDate] ->', status)
if status != 200:
    print(safe(raw)[:400])
    sys.exit(1)
sacks = [r['document'] for r in json.loads(raw) if 'document' in r]
print('   عددُ جواني اليوم =', len(sacks))

suppliers = set()
for doc in sacks:
    sack_id = doc['name'].rsplit('/', 1)[-1]
    f = {k: plain(v) for k, v in doc['fields'].items()}
    if f.get('supplierId'):
        suppliers.add(f['supplierId'])
    print('   ·', sack_id, '→', json.dumps(
        {k: f.get(k) for k in ('supplierId', 'supplierName', 'displayName',
                               'status', 'isPricingComplete') if k in f},
        ensure_ascii=False))

    # ── ③ 🔒 ماليتُها — `sacks/{id}/finance/current` (`ADR-0011`) ──
    status, raw = get('%s/sacks/%s/finance/current' % (DB, sack_id), token)
    print('   ③ finance/current ->', status)
    if status == 200:
        fin = fields_of(raw)
        print('      ', json.dumps(
            {k: fin.get(k) for k in ('taxPerKilo', 'sackTax', 'sackRevenue',
                                     'supplierNet', 'isRevenueFinal')
             if k in fin}, ensure_ascii=False))
    else:
        print('      ', safe(raw)[:200])

    # ── ④ 🔒 سطرُ دفتر الرعية — `supplier_ledger/{sackId}` ──
    status, raw = get('%s/supplier_ledger/%s' % (DB, sack_id), token)
    print('   ④ supplier_ledger ->', status)
    if status == 200:
        row = fields_of(raw)
        print('      ', json.dumps(
            {k: row.get(k) for k in ('supplierId', 'sourceId', 'sackRevenue',
                                     'sackTax', 'supplierNet', 'recalcVersion',
                                     'isRevenueFinal', 'isCancelled')
             if k in row}, ensure_ascii=False))
    else:
        print('      ', safe(raw)[:200])

# ── ⑤ ⛅ رصيدُ كل رعويٍّ في هذا المصدر ─────────────────────────────────
for supplier_id in sorted(suppliers):
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
        print('   ', safe(raw)[:200])

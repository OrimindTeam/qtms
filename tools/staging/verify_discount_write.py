# -*- coding: utf-8 -*-
"""تحقُّقٌ **للقراءة فقط** من أثر سندِ خصمٍ على التجريبية — `M13` · `WU-013`.

★ **التشغيل من جذر المستودع:**

    python tools/staging/verify_discount_write.py DSC-20260901-0001

⛅ **التجريبية `qtms-orimind-master` حصراً** — ⛔⛔ **ولا نظير له على الإنتاج.**

═══════════════════════════════════════════════════════════════════════════
⛔⛔★★★ **ولماذا لزم — مقيسٌ لا نظري:** ★ **معيارُ قبول `WU-013` ينصّ أن
«الخصم قيدٌ دائن يخفض الضمار *فعلاً*»** — ⟵ **وحركةُ `dealer_ledger` بنوع
«خصم» ومستندُ `distributions/{id}/pricing/current` لا تعرضهما شاشةٌ واحدة
اليوم**، ⛔ **فبقي البندُ ادّعاءً حتى يُقرأ المخزَّن** (بروتوكول التشغيل §و).

⛔⛔★★★ **وكلُّ استعلامٍ يُقيّد الحقلَ الذي يعتمده شرطُ قراءته** (`DEBT-40`):
★ **`dealer_ledger` تُقيَّد بـ`sourceId`** — ⟵ **واستعلامٌ لا يُقيّده يُرفَض
كاملاً** ⛔ **و`403` ليست «صفرَ نتائج».**

⛔⛔★★★ **وقراءةٌ محضة — ⛔ ولا كتابةَ حرفٍ واحد** · ⛔⛔ **ولا قيمةَ سرٍّ
تُطبَع** (`AM-004` · `environments.md` §1.5).
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


number = sys.argv[1] if len(sys.argv) > 1 else 'DSC-20260901-0001'

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

# ── ② سندُ الخصم نفسُه ─────────────────────────────────────────────────
status, raw = get('%s/discounts/%s' % (DB, number), token)
print('② GET discounts/%s -> %s' % (number, status))
if status != 200:
    print(safe(raw)[:400])
    sys.exit(1)
doc = {k: plain(v) for k, v in json.loads(raw)['fields'].items()}
for key in sorted(doc):
    print('   %-20s = %s' % (key, safe(json.dumps(doc[key], ensure_ascii=False))))

# ⛔⛔★★★ **حارسُ `AT-35`** — ★ **ولا حقلَ فائضٍ في المخزَّن** ⛔ **ولو بصفر.**
surplus = [k for k in doc if 'surplus' in k.lower()]
print('   ⛔ حقولُ فائضٍ في السند = %s' % (surplus if surplus else 'لا شيء ✅'))

# ── ③ حركةُ دفتر المقاوته — ★ **مُقيَّدةٌ بـ`sourceId`** (`DEBT-40`) ────
lines = doc.get('lines') or []
source_ids = sorted({l.get('sourceId') for l in lines if isinstance(l, dict) and l.get('sourceId')})
if not source_ids and doc.get('sourceFilter'):
    source_ids = [doc['sourceFilter']]
for source_id in source_ids:
    status, raw = post(
        '%s:runQuery' % DB,
        {
            'structuredQuery': {
                'from': [{'collectionId': 'dealer_ledger'}],
                'where': {
                    'fieldFilter': {
                        'field': {'fieldPath': 'sourceId'},
                        'op': 'EQUAL',
                        'value': {'stringValue': source_id},
                    }
                },
                'limit': 300,
            }
        },
        token,
    )
    print('③ dealer_ledger [sourceId=%s] -> %s' % (source_id, status))
    if status != 200:
        print(safe(raw)[:400])
        continue
    hits = 0
    for element in json.loads(raw):
        found = element.get('document')
        if not found:
            continue
        fields = {k: plain(v) for k, v in found['fields'].items()}
        # ★ **واسمُ الحقل `sourceDocNumber`** — ⛔ **لا يُخمَّن** (`discount.dart`).
        if number not in (fields.get('sourceDocNumber'), fields.get('sourceDocId')):
            continue
        hits += 1
        doc_id = found['name'].split('/')[-1]
        shown = {k: fields[k] for k in sorted(fields) if k in (
            'entryType', 'direction', 'amount', 'dealerId', 'sourceId',
            'debtLotId', 'sourceDocType', 'sourceDocNumber', 'isCancelled',
        )}
        print('   · %s → %s' % (doc_id, json.dumps(shown, ensure_ascii=False)))
    print('   عددُ حركاتِ هذا السند = %d' % hits)

# ── ④ تسويةُ الضمار — `pricing/current` ────────────────────────────────
for line in lines:
    if not isinstance(line, dict):
        continue
    lot = line.get('debtLotId')
    if not lot:
        continue
    status, raw = get('%s/distributions/%s/pricing/current' % (DB, lot), token)
    print('④ GET distributions/%s/pricing/current -> %s' % (lot, status))
    if status != 200:
        print(safe(raw)[:400])
        continue
    pricing = {k: plain(v) for k, v in json.loads(raw)['fields'].items()}
    for key in ('debtValue', 'settledAmount', 'discountedAmount', 'remaining'):
        if key in pricing:
            print('   %-20s = %s' % (key, pricing[key]))
    status, raw = get('%s/distributions/%s' % (DB, lot), token)
    if status == 200:
        parent = {k: plain(v) for k, v in json.loads(raw)['fields'].items()}
        print('   %-20s = %s' % ('settlementStatus', parent.get('settlementStatus')))

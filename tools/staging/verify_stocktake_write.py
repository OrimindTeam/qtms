# -*- coding: utf-8 -*-
"""قراءةُ مستند جردٍ من التجريبية **حقلاً بحقل** — `WU-022` (`FR-M16`).

★ **التشغيل من جذر المستودع:**

    python tools/staging/verify_stocktake_write.py STK-20260902-001

═══════════════════════════════════════════════════════════════════════════
⛔⛔★★★ **ولماذا لا تكفي رسالةُ الشاشة «✅ اعتُمد الجرد»:** ★ **الشاشةُ تقرأ
ردَّ العملية لا المخزَّن** — ⟵ **وخمسةُ أحكامٍ لا تُرى منها إطلاقاً:**

  ① ⛔⛔ **لا حقلَ ماليٍّ في المستند ولا في سطوره** (`BR-M16-03` · `AT-66`).
  ② ★★★ **الرصيدُ الدفتري مُجمَّدٌ في السطر** (`FR-M16-03`) — ⟵ **والفرقُ
     محسوبٌ عليه** ⛔ **لا على رصيدٍ يُعاد قياسُه.**
  ③ ★★ **حركةُ الدفتر مَوْسومةٌ `adjustment`** — ⟵ **وهو ما يُخرِجها من سعر
     الجونية ومن المبيعات ومن استحقاق الرعوي** (`AT-66`).
  ④ ⛔⛔ **ولا قيدَ في دفتر المقاوته ولا في دفتر الرعوي** (`BR-M16-03`).
  ⑤ ★ **والرصيدُ أُعيد بناؤه من الدفتر** (`ADR-0008`).

⛔⛔★★★ **و`403` ليست «صفرَ حركات»** — ★ **والحارسُ الذي يمرّ لأن القراءة
فشلت أسوأ من غياب حارس** (playbook §7 البند 3): ⟵ **فيُطبَع الحكمُ معلَّقاً
لا سالباً.**

⚠️ **ويدخل بحساب QA لا المالك** — ★ **فالمقصود إثباتُ ما يراه المستخدم
الحقيقي بصلاحياته وشرطِ قراءته** (⟵ **ومنها `stocktakeView` الجديد**).
═══════════════════════════════════════════════════════════════════════════
"""

import io, json, os, sys, urllib.parse, urllib.request, urllib.error

sys.stdout.reconfigure(encoding='utf-8')

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PROJECT = 'qtms-orimind-master'
DB = 'https://firestore.googleapis.com/v1/projects/%s/databases/(default)/documents' % PROJECT

SECRET_TOKENS = []

# ⛔⛔★★★ **أسماءُ الحقول المالية الممنوعة** — `data-dictionary.md` §`disposals`.
FORBIDDEN_MONEY = (
    'unitPrice', 'lineTotal', 'lineValue', 'amount', 'grandTotal',
    'totalValue', 'totalQatValue', 'totalCashValue', 'debtValue', 'price',
)


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


number = sys.argv[1] if len(sys.argv) > 1 else 'STK-20260902-001'

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

# ── ② المستند نفسُه ────────────────────────────────────────────────────
status, raw = get('%s/stocktakes/%s' % (DB, number), token)
print('② GET stocktakes/%s -> %s' % (number, status))
if status != 200:
    print(safe(raw)[:400])
    sys.exit(1)
doc = {k: plain(v) for k, v in json.loads(raw)['fields'].items()}
for key in ('documentNumber', 'sourceId', 'sourceName', 'stockDate', 'status',
            'lineCount', 'reason', 'createdBy', 'approvedBy', 'amendCount'):
    if key in doc:
        print('   %-16s = %s' % (key, doc[key]))
print('   lines            =', json.dumps(doc.get('lines'), ensure_ascii=False))

# ⛔⛔★★★ **حارسُ `FR-M8-16` مقيساً على المخزَّن نفسِه** — ⛔ لا على النية.
money = [k for k in doc if k in FORBIDDEN_MONEY]
for line in (doc.get('lines') or []):
    money += ['lines.' + k for k in line if k in FORBIDDEN_MONEY]
print('   ⛔ حقولٌ مالية    =', money if money else 'لا شيء ✅')
dealer_fields = [k for k in doc if k in ('dealerId', 'dealerName', 'debtValue')]
print('   ⛔ حقولُ مقوت    =', dealer_fields if dealer_fields else 'لا شيء ✅')


def rows_of(collection, source_id, doc_number, extra_filters=()):
    filters = [{'fieldFilter': {'field': {'fieldPath': 'sourceId'},
                                'op': 'EQUAL',
                                'value': {'stringValue': source_id}}}]
    filters += list(extra_filters)
    status, raw = post('%s:runQuery' % DB, {
        'structuredQuery': {
            'from': [{'collectionId': collection}],
            'where': {'compositeFilter': {'op': 'AND', 'filters': filters}},
        },
    }, token=token)
    if status != 200:
        return status, None
    docs = [r['document'] for r in json.loads(raw) if 'document' in r]
    kept = []
    for row in docs:
        f = {k: plain(v) for k, v in row['fields'].items()}
        if f.get('sourceDocNumber') == doc_number:
            kept.append((row['name'].rsplit('/', 1)[-1], f))
    return status, kept


source_id = doc.get('sourceId')

# ── ③ حركةُ المخزون التي كتبها المستند ────────────────────────────────
status, moves = rows_of('inventory_ledger', source_id, number)
print('③ inventory_ledger [sourceId] ->', status)
if moves is None:
    print('   ⛔ لم تُقرأ — والحكمُ معلَّق لا سالب')
else:
    print('   عددُ حركاتِ هذا المستند =', len(moves))
    for name, f in moves:
        print('   ·', name, '→', json.dumps(
            {k: f.get(k) for k in
             ('itemKey', 'itemName', 'direction', 'quantity', 'balanceAfter',
              'movementTag', 'sourceDocType', 'stockDate',
              'isCancelled') if k in f},
            ensure_ascii=False))
        bad = [k for k in f if k in FORBIDDEN_MONEY]
        print('     ⛔ حقولٌ مالية في الحركة =', bad if bad else 'لا شيء ✅')
        print('     ★ الوسم =', f.get('movementTag'),
              '✅' if f.get('movementTag') == 'adjustment' else '⛔⛔ مخالفة!')
        # ⛔⛔★★★ **ولا `sackId` في حركة التسوية** — ★ **الفرقُ غيرُ مفسَّر.**
        print('     ⛔ sackId =',
              'لا شيء ✅' if 'sackId' not in f else '⛔⛔ مخالفة! %s' % f['sackId'])

# ── ④ ⛔⛔ ولا قيدَ في دفتر المقاوته ولا في دفتر الرعوي — `A-15` · `GR-29` ──
for ledger, rule in (('dealer_ledger', 'BR-M16-03'),
                     ('supplier_ledger', 'BR-M16-03')):
    status, rows = rows_of(ledger, source_id, number)
    if rows is None:
        print('④ %s -> %s · ⛔⛔ لم تُقرأ — فالحارسُ *لم يُفحَص*'
              % (ledger, status))
    else:
        print('④ %s -> %s · عددُ قيودِ هذا المستند = %d %s'
              % (ledger, status, len(rows),
                 '✅ %s مقيسٌ على الدفتر نفسِه' % rule if not rows
                 else '⛔⛔ مخالفة!'))

# ── ⑤ الرصيدُ بعد الحركة — أُعيد بناؤه من الدفتر (`ADR-0008`) ──────────
# ★★★ **ومفتاحُ السطر `itemKey` هنا** — ⛔ **لا `itemId`** (بخلاف الإتلاف).
line_keys = [l.get('itemKey') for l in (doc.get('lines') or []) if l.get('itemKey')]
stock_day = (doc.get('stockDate') or '')[:10].replace('-', '')
for item_key in line_keys:
    balance_id = '%s_%s_%s' % (source_id, item_key, stock_day)
    # ★ **والمفتاحُ المركّب يحمل مسافاتٍ وعربية** — ⟵ **فيُرمَّز في المسار**،
    #   ⛔ **وبدونه يسقط الطلبُ قبل أن يُرسَل** (رُصد 2026-09-05).
    status, raw = get(
        '%s/item_daily_balances/%s' % (DB, urllib.parse.quote(balance_id, safe='')),
        token,
    )
    print('⑤ GET item_daily_balances/%s -> %s' % (balance_id, status))
    if status == 200:
        b = {k: plain(v) for k, v in json.loads(raw)['fields'].items()}
        for key in ('incoming', 'outgoing', 'balance', 'unit'):
            print('   %-10s = %s' % (key, b.get(key)))

# ── ⑥ قيدُ التدقيق — قيدٌ كاملٌ عند الاعتماد (`FR-M16-11`) ─────────────
status, raw = post('%s:runQuery' % DB, {
    'structuredQuery': {
        'from': [{'collectionId': 'audit_log'}],
        'where': {'compositeFilter': {'op': 'AND', 'filters': [
            {'fieldFilter': {'field': {'fieldPath': 'sourceId'},
                             'op': 'EQUAL',
                             'value': {'stringValue': source_id}}},
            {'fieldFilter': {'field': {'fieldPath': 'entityId'},
                             'op': 'EQUAL',
                             'value': {'stringValue': number}}},
        ]}},
    },
}, token=token)
print('⑥ audit_log [sourceId + entityId] ->', status)
if status == 200:
    for row in [r['document'] for r in json.loads(raw) if 'document' in r]:
        f = {k: plain(v) for k, v in row['fields'].items()}
        print('   ·', json.dumps(
            {k: f.get(k) for k in ('action', 'entityType', 'entityId',
                                   'reason', 'occurredAt') if k in f},
            ensure_ascii=False))
else:
    print('   ⛔ لم يُقرأ — والحكمُ معلَّق لا سالب:', safe(raw)[:200])

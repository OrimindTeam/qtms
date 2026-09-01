# -*- coding: utf-8 -*-
"""تحقُّقٌ **للقراءة فقط** من أثر سندِ سحبيةٍ أو خرجية على التجريبية.

★ **التشغيل من جذر المستودع:**

    python tools/staging/verify_outflow_write.py WDR-20260901-0001

⛅ **التجريبية `qtms-orimind-master` حصراً** — ⛔⛔ **ولا نظير له على الإنتاج.**

═══════════════════════════════════════════════════════════════════════════
⛔⛔★★★ **ولماذا لزم هذا الملف — مقيسٌ لا نظري:** ★ **بروتوكول التشغيل §و
يمنع الادّعاء غير المتحقَّق** («**الشاشة قالت حُفِظ ليست إثباتاً**») —
⟵ **وسطرُ `outflow_ledger` لا تعرضه أي شاشة اليوم** (**تقريرُه `R-23` موضعُه
`WU-018`)، ⛔ **فلا سبيل لرؤيته بالعين من التطبيق.**

★★ **والبديلُ المرفوض:** **الاكتفاءُ بأن قيدَ التدقيق كُتب** ⟹ **فالمعاملة
التزمت كلُّها** (`ADR-0013` القاعدة 1) — ⚠️ **استنتاجٌ صحيحٌ بنيوياً**،
⛔ **لكنه ليس قياساً**: ★ **وهو بالضبط صنفُ «الادّعاء المجرَّد» الذي أنشأ
§و بعد حادثة 2026-08-27.**
═══════════════════════════════════════════════════════════════════════════

⛔⛔★★★ **وقراءةٌ محضة — ⛔ ولا كتابةَ حرفٍ واحد:** ★ **`GET` وحدها على
`documents:runQuery` و`documents/{path}`**، ⟵ **ولا `POST` إلا لتسجيل الدخول.**

⛔⛔★★★ **ولا قيمةَ سرٍّ تُطبَع ولا تُعاد إطلاقاً** — ★ **بنفس ضمانات
`qa_permission_sync.py` حرفياً** (`AM-004` · `environments.md` §1.5):
**الاعتماد يُقرأ داخل هذه العملية وحدها**، ⟵ **والمطبوعُ حقولٌ وأعدادٌ
وقيمٌ منطقية لا غير**، ★ **ومع ذلك يمرّ كلُّ مخرَجٍ على [safe] حزاماً ثانياً.**

⚠️ **ويدخل بحساب QA لا المالك** — ★ **فالمقصود إثباتُ ما يراه المستخدم
الحقيقي بصلاحياته وشرطِ قراءته**، ⛔ **لا ما يراه امتيازٌ إداري.**
"""
import io, json, os, re, sys, urllib.request, urllib.error

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


number = sys.argv[1] if len(sys.argv) > 1 else 'WDR-20260901-0001'

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

# ── ② المستند نفسُه ────────────────────────────────────────────────────
status, raw = get('%s/outflows/%s' % (DB, number), token)
print('② GET outflows/%s -> %s' % (number, status))
if status != 200:
    print(safe(raw)[:400])
    sys.exit(1)
doc = {k: plain(v) for k, v in json.loads(raw)['fields'].items()}
for key in ('documentNumber', 'ledgerType', 'category', 'sourceId', 'sourceName',
            'documentDate', 'stockDate', 'status', 'totalQatValue',
            'totalCashValue', 'grandTotal', 'unpricedItemCount',
            'ledgerEntryCount', 'totalPieces', 'totalWeight', 'createdBy'):
    if key in doc:
        print('   %-18s = %s' % (key, doc[key]))
print('   lines              =', json.dumps(doc.get('lines'), ensure_ascii=False))
# ⛔⛔★★★ **حارسُ `GR-44` مقيساً على المخزَّن نفسِه** — ⛔ لا على النية.
forbidden = [k for k in doc if k in ('dealerId', 'dealerName', 'debtValue',
                                     'settledAmount', 'discountedAmount')]
print('   ⛔ حقولُ مقوتٍ في المستند =', forbidden if forbidden else 'لا شيء ✅')

# ── ③ سطورُ الدفتر الرابع ──────────────────────────────────────────────
#
# ⛔⛔★★★ **وكلُّ استعلامٍ هنا يُقيّد الحقلَ الذي يعتمده شرطُ قراءته** —
#    `DEBT-40` (`IQ-024` · `WU-008`): ⟵ **والشرطُ يُقيَّم على قيود الاستعلام
#    لا على كل مستند**، ⛔ **فاستعلامٌ بـ`sourceDocNumber` وحده يُرفَض `403`
#    كاملاً ولو ملك القارئُ كلَّ مفتاح.**
#    ⚠️⚠️ **ورُصد على هذا السكربت نفسِه (2026-09-01)** — ★ **الرابعةَ في هذا
#    المشروع**: ⟵ **والتصفيةُ برقم المستند تقع *بعد* الجلب** ⛔ **لا فيه.**
def rows_of(collection, extra_filters, source_id, doc_number, token):
    """يجلب سطورَ مجموعةٍ بقيودِ شرطِ قراءتها ثم يُصفّي برقم المستند محلياً."""
    filters = [{'fieldFilter': {'field': {'fieldPath': 'sourceId'},
                                'op': 'EQUAL',
                                'value': {'stringValue': source_id}}}]
    filters += extra_filters
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
ledger_type = doc.get('ledgerType')

status, rows = rows_of(
    'outflow_ledger',
    [{'fieldFilter': {'field': {'fieldPath': 'ledgerType'},
                      'op': 'EQUAL',
                      'value': {'stringValue': ledger_type}}}],
    source_id, number, token)
print('③ outflow_ledger [sourceId + ledgerType] ->', status)
if rows is None:
    print('   ⛔ لم تُقرأ — والحكمُ معلَّق لا سالب')
else:
    print('   عددُ سطورِ هذا السند =', len(rows))
    for name, f in rows:
        print('   ·', name, '→', json.dumps(
            {k: f.get(k) for k in
             ('ledgerType', 'category', 'itemType', 'sourceId', 'itemKey',
              'quantity', 'unitPrice', 'lineValue', 'amount', 'documentDate',
              'stockDate', 'sourceDocType', 'isCancelled') if k in f},
            ensure_ascii=False))

# ── ④ حركةُ المخزون التي كتبها السند ──────────────────────────────────
status, moves = rows_of('inventory_ledger', [], source_id, number, token)
print('④ inventory_ledger [sourceId] ->', status)
if moves is None:
    print('   ⛔ لم تُقرأ — والحكمُ معلَّق لا سالب')
else:
    print('   عددُ حركاتِ هذا السند =', len(moves))
    for name, f in moves:
        print('   ·', name, '→', json.dumps(
            {k: f.get(k) for k in
             ('sourceId', 'itemKey', 'direction', 'quantity', 'balanceAfter',
              'sourceDocType', 'stockDate', 'isCancelled') if k in f},
            ensure_ascii=False))

# ── ⑤ ⛔⛔ حارسُ `GR-44` — ولا حركةَ في دفتر المقاوته لهذا السند ────────
#
# ⛔⛔★★★ **و`403` ليست «صفرَ حركات»** — ★ **وهذا خطأٌ وقع في أول نسخةٍ من
#    هذا السكربت فطبع ✅ لسببٍ خاطئ**: ⟵ **والحارسُ الذي يمرّ لأن القراءة
#    فشلت أسوأ من غياب حارس** (`playbook` §7 البند 3).
status, dealer = rows_of('dealer_ledger', [], source_id, number, token)
if dealer is None:
    print('⑤ dealer_ledger [sourceId] ->', status,
          '· ⛔⛔ لم تُقرأ — فالحارسُ *لم يُفحَص* ⛔ ولا يُقال «نجح»')
else:
    print('⑤ dealer_ledger [sourceId] -> %s · عددُ حركاتِ هذا السند = %d %s'
          % (status, len(dealer),
             '✅ GR-44 مقيسٌ على الدفتر نفسِه' if not dealer else '⛔⛔ مخالفة!'))

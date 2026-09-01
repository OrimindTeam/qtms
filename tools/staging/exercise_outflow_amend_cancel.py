# -*- coding: utf-8 -*-
"""تشغيلُ **تعديلِ وإلغاءِ** سندِ سحبيةٍ أو خرجية على التجريبية — `WU-014`.

★ **التشغيل من جذر المستودع:**

    python tools/staging/exercise_outflow_amend_cancel.py WDR-… EXP-…

⛅ **التجريبية `qtms-orimind-master` حصراً** — ⛔⛔ **ولا نظير له على الإنتاج.**

═══════════════════════════════════════════════════════════════════════════
⚠️⚠️★★★ **ولماذا من المسار السحابي لا من الشاشة — حدٌّ مُعلَنٌ لا التفاف:**
★ **شاشةُ `M22` اليومَ نموذجُ إنشاءٍ وحده** — ⛔ **ولا قائمةَ سنداتٍ فيها
تُفتَح على سندٍ ليُعدَّل أو يُلغى**: ⟵ **تلك `FR-M22-13` وموضعُها `WU-018`**
(بنفس قرار `FR-M13-13` في `WU-013`).
⟹ ★ **فمسارا `amendOutflow` و`cancelOutflow` لا يمكن بلوغُهما من الواجهة
اليوم أصلاً** — ⛔ **وتركُهما بلا قياسٍ حيٍّ كان يعني إعلانَ الزيادة منجَزةً
بمسارين لم يُشغَّلا قط**، ★ **وهو ما تمنعه بوابةُ التحقق** (`playbook` §7).
⟵ **وهذا السكربت يُشغِّلهما كما يُشغِّلهما التطبيق حرفياً:** **نفسُ العنوان
ونفسُ الحمولة ونفسُ رمزِ الدخول** — ⛔ **ولا امتيازَ إداريٌّ ولا التفافٌ على
حارس.**
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

rid = lambda: 'wu014-' + str(uuid.uuid4())

# ── ② التعديل — ★ 5 حبات ⟵ 8، وبندُ مبلغٍ يُضاف ──────────────────────
#    ⟵ **فيُختبَر معاً:** إعادةُ بناء الرصيد · ونموُّ سطور الدفتر · و`amendCount`.
status, raw = post(base + '/amendOutflow', {'data': {
    'requestId': rid(),
    'documentNumber': withdrawal,
    'ledgerType': 'withdrawal',
    'sourceId': 'SRC-001',
    'category': 'withdrawalQat',
    'date': '20260901',
    'qatLines': [{'itemId': 'ITM-0003', 'quantity': 8, 'unitPrice': 1500}],
    'cashLines': [{'kind': 'other', 'amount': 2000, 'description': 'أجرة نقل'}],
    'reason': 'تصحيح الكمية بعد الجرد',
}}, token=token)
print('② amendOutflow(%s) ->' % withdrawal, status, safe(raw)[:200])

# ── ③ ⛔⛔ حارسُ `GR-43` حيّاً — ادّعاءُ سجلٍّ يخالف المخزَّن ──────────
#    ★ **الحسابُ يملك كلَّ المفاتيح** ⟹ **فالرفضُ إن وقع سببُه المخزَّنُ وحده.**
status, raw = post(base + '/amendOutflow', {'data': {
    'requestId': rid(),
    'documentNumber': withdrawal,
    'ledgerType': 'expense',          # ⛔ **ادّعاءٌ يخالف المستند**
    'sourceId': 'SRC-001',
    'category': 'expenseShareCuts',
    'date': '20260901',
    'qatLines': [{'itemId': 'ITM-0003', 'quantity': 1, 'unitPrice': 1500}],
}}, token=token)
print('③ amendOutflow بادّعاء «خرجية» على سندِ سحبية ->', status, safe(raw)[:200])

# ── ④ ⛔⛔ حارسُ `ERR_OUT_001` — سندٌ بلا مصدر ────────────────────────
status, raw = post(base + '/createOutflow', {'data': {
    'requestId': rid(),
    'ledgerType': 'withdrawal',
    'sourceId': '   ',
    'category': 'withdrawalCash',
    'date': '20260901',
    'cashLines': [{'kind': 'amount', 'amount': 100}],
}}, token=token)
print('④ createOutflow بلا مصدر ->', status, safe(raw)[:200])

# ── ⑤ ⛔⛔ حارسُ التاريخ المستقبلي — مرفوضٌ لمن يملك كلَّ المفاتيح ─────
status, raw = post(base + '/createOutflow', {'data': {
    'requestId': rid(),
    'ledgerType': 'withdrawal',
    'sourceId': 'SRC-001',
    'category': 'withdrawalCash',
    'date': '20261231',
    'cashLines': [{'kind': 'amount', 'amount': 100}],
}}, token=token)
print('⑤ createOutflow بتاريخٍ مستقبلي ->', status, safe(raw)[:200])

# ── ⑥ الإلغاء — ★ ويُعيد الكمية ويُخلي بندَ المركز المعلّق ───────────
status, raw = post(base + '/cancelOutflow', {'data': {
    'requestId': rid(),
    'documentNumber': expense,
    'ledgerType': 'expense',
    'sourceId': 'SRC-001',
    'reason': 'خرجية سُجِّلت بالخطأ',
}}, token=token)
print('⑥ cancelOutflow(%s) ->' % expense, status, safe(raw)[:200])

# ── ⑦ ⛔ والملغى لا يُلغى ثانيةً ──────────────────────────────────────
status, raw = post(base + '/cancelOutflow', {'data': {
    'requestId': rid(),
    'documentNumber': expense,
    'ledgerType': 'expense',
    'sourceId': 'SRC-001',
}}, token=token)
print('⑦ cancelOutflow مرةً ثانية ->', status, safe(raw)[:200])

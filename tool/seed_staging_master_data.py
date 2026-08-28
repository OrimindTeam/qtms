# -*- coding: utf-8 -*-
"""تهيئة بيانات `WU-004` المرجعية على التجريبية — ★ **عبر العمليات المستدعاة
نفسها التي يستدعيها التطبيق** (`ADR-0013`)، ⛔ **لا بكتابة مباشرة على القاعدة.**

⚠️ **ولماذا سكربت لا شاشات:** محاكي `Pixel_6_API_36` **بلا محرّر إدخال عربي**
(`ime list` يُظهر اللاتينية والصوت وحدهما · و`input text` يرمي على غير ASCII)،
⟵ ★ **فتعذّر إدخالُ الأسماء العربية من الواجهة.** ⛔ **والأثر محصورٌ في
البيانات المرجعية** (`WU-002`/`WU-005` — **وقد اختُبرتا سابقاً**) — ★ **وسيناريوهات
`WU-004` الإحدى عشر تبقى من الواجهة كاملةً** لأن مدخلاتها **أرقامٌ واختيارات.**
"""
import io, json, sys, time, urllib.request, urllib.error

URL = 'https://qtms-callables-7stgg3ngga-ww.a.run.app'

def load(p):
    d = {}
    for L in io.open(p, encoding='utf-8'):
        L = L.strip()
        if L and not L.startswith('#') and '=' in L:
            k, v = L.split('=', 1)
            d[k.strip()] = v.strip().strip('"').strip("'")
    return d

gs = json.load(io.open('android/app/src/staging/google-services.json', encoding='utf-8'))
assert gs['project_info']['project_id'] == 'qtms-orimind-master'
KEY = gs['client'][0]['api_key'][0]['current_key']
qa = load('.secrets/qtms-staging-qa-account.env')

def signin():
    for _ in range(4):
        try:
            r = urllib.request.Request(
                'https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=' + KEY,
                data=json.dumps({'email': qa['QTMS_STAGING_QA_EMAIL'],
                                 'password': qa['QTMS_STAGING_QA_PASSWORD'],
                                 'returnSecureToken': True}).encode(),
                headers={'Content-Type': 'application/json'})
            return json.load(urllib.request.urlopen(r, timeout=45))['idToken']
        except urllib.error.HTTPError as h:
            sys.exit('signin rejected: ' + json.load(h).get('error', {}).get('message', '?'))
        except Exception:
            time.sleep(2)
    sys.exit('signin transport failed')

TOKEN = signin()

def call(op, data, tries=3):
    for i in range(tries):
        try:
            r = urllib.request.Request(URL + '/' + op,
                data=json.dumps({'data': data}).encode(),
                headers={'Content-Type': 'application/json',
                         'Authorization': 'Bearer ' + TOKEN})
            resp = urllib.request.urlopen(r, timeout=60)
            return resp.status, json.load(resp)
        except urllib.error.HTTPError as e:
            try: return e.code, json.load(e)
            except Exception: return e.code, {}
        except Exception:
            time.sleep(2)
    return 0, {'transport': 'failed'}

def show(label, code, body):
    print('%-34s %s  %s' % (label, code, json.dumps(body, ensure_ascii=False)[:150]))

# ① إعدادات التطبيق — يُنهي «الإعداد التأسيسي»
show('writeAppSettings', *call('writeAppSettings', {
    'requestId': 'seed-settings-001',
    'businessName': 'وكالة محمد المحامي',
    'currencySymbol': 'ر.ي',
    'thousandsSeparator': ',',
}))

# ② مصدران — لإثبات استقلال التسلسل لكل مصدر (AT-14 · AT-15)
for i, name in ((1, 'مصدر الاختبار الأول'), (2, 'مصدر الاختبار الثاني')):
    show('createSource %d' % i, *call('createSource', {
        'requestId': 'seed-source-00%d' % i, 'name': name, 'isActive': True}))

# ③ رعوي
show('createDealer', *call('createDealer', {
    'requestId': 'seed-dealer-001', 'name': 'رعوي الاختبار',
    'phone': '770000001', 'isActive': True}))

# ④ الأنواع — ★ واحدٌ لكل حالةٍ تحتاجها سيناريوهات §11
SRCS = ['SRC-001', 'SRC-002']
items = [
    # وزنيٌّ بوزن حبةٍ مهيّأ — للسيناريو 4 (100 حبة × 200جم = 20.000)
    ('seed-item-001', 'عتود', 'weightBased', 200.0),
    # عدديٌّ — للسيناريو 5 (250 حبة · 15.000 كجم ⟵ وزن الحبة يُستنتَج 60جم)
    ('seed-item-002', 'سلة', 'countBased', None),
    # ⛔ وزنيٌّ بلا وزن حبة — للسيناريو 9 (`ERR_INTAKE_005`)
    ('seed-item-003', 'مشقر', 'weightBased', None),
]
for rid, name, nature, pw in items:
    payload = {'requestId': rid, 'name': name, 'nature': nature,
               'sourceIds': SRCS, 'isActive': True}
    if pw is not None:
        payload['pieceWeightGrams'] = pw
    show('createItem %s' % name, *call('createItem', payload))

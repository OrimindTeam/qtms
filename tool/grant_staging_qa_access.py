# -*- coding: utf-8 -*-
"""منحُ حساب اختبار (QA) التجريبي صلاحياتِه كاملةً — `RB-staging-qa-account` §3.2.

★ **يقرأ الاعتمادَين من ملفّيهما المحليَّين مباشرةً** ⛔ **ولا يطبع بريداً ولا
كلمةَ مرور ولا رمزاً إطلاقاً** — ★ **ولا تمرّ أيُّ قيمة في سياق الأداة**
(`AM-004` · `secrets-management-policy.md` §3).

⛔⛔ **التجريبية حصراً** — ★ **ويرفض العملَ إن لم يكن المشروع
`qtms-orimind-master`.**

الاستخدام:
    python tool/grant_staging_qa_access.py --owner-env <مسار ملف اعتماد المالك>

★ **ملفّ المالك بنفس بنية ملف الاختبار:**
    QTMS_STAGING_OWNER_EMAIL=...
    QTMS_STAGING_OWNER_PASSWORD=...
"""
import argparse, io, json, re, sys, urllib.request, urllib.error

STAGING_PROJECT = 'qtms-orimind-master'
SERVICE = 'https://qtms-callables-7stgg3ngga-ww.a.run.app'
QA_ENV = '.secrets/qtms-staging-qa-account.env'
GS = 'android/app/src/staging/google-services.json'
PERM_SRC = 'packages/qtms_domain/lib/capabilities/identity_access/domain/permission.dart'


def load_env(path):
    out = {}
    for line in io.open(path, encoding='utf-8'):
        line = line.strip()
        if line and not line.startswith('#') and '=' in line:
            k, v = line.split('=', 1)
            out[k.strip()] = v.strip().strip('"').strip("'")
    return out


def post(url, payload, token=None):
    headers = {'Content-Type': 'application/json'}
    if token:
        headers['Authorization'] = 'Bearer ' + token
    req = urllib.request.Request(url, data=json.dumps(payload).encode(), headers=headers)
    try:
        # ⛔★★ **طلبٌ واحد لا اثنان** — ★ **فتحُ الطلب مرتين يُرسِل الكتابة مرتين.**
        resp = urllib.request.urlopen(req, timeout=60)
        return resp.status, json.load(resp)
    except urllib.error.HTTPError as e:
        try:
            return e.code, json.load(e)
        except Exception:
            return e.code, {'raw': e.read().decode('utf-8', 'replace')[:300]}


def sign_in(api_key, email, password):
    """يُعيد (uid, idToken) — ⛔ ولا يطبع شيئاً منهما."""
    req = urllib.request.Request(
        'https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=' + api_key,
        data=json.dumps({'email': email, 'password': password,
                         'returnSecureToken': True}).encode(),
        headers={'Content-Type': 'application/json'})
    try:
        r = json.load(urllib.request.urlopen(req, timeout=30))
    except urllib.error.HTTPError as e:
        msg = json.load(e).get('error', {}).get('message', '?')
        sys.exit('⛔ فشل تسجيل الدخول: ' + msg)
    return r['localId'], r['idToken']


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--owner-env', required=True)
    ap.add_argument('--request-id', default='qa-access-0001')
    args = ap.parse_args()

    gs = json.load(io.open(GS, encoding='utf-8'))
    if gs['project_info']['project_id'] != STAGING_PROJECT:
        sys.exit('⛔ ليس المشروع التجريبي — أُوقِف')
    api_key = gs['client'][0]['api_key'][0]['current_key']

    keys = re.findall(r'^\s{2}([a-z][A-Za-z0-9]*)\s*[,;]\s*$',
                      re.search(r'enum Permission\s*\{(.*?)\n\}',
                                io.open(PERM_SRC, encoding='utf-8').read(), re.S).group(1), re.M)
    print('★ مفاتيح §2 المشتقّة الآن من الكتالوج:', len(keys))

    qa = load_env(QA_ENV)
    owner = load_env(args.owner_env)
    o_email = owner.get('QTMS_STAGING_OWNER_EMAIL') or owner.get('QTMS_STAGING_QA_EMAIL')
    o_pass = owner.get('QTMS_STAGING_OWNER_PASSWORD') or owner.get('QTMS_STAGING_QA_PASSWORD')
    if not o_email or not o_pass:
        sys.exit('⛔ ملف المالك لا يحوي QTMS_STAGING_OWNER_EMAIL/PASSWORD')

    qa_uid, _ = sign_in(api_key, qa['QTMS_STAGING_QA_EMAIL'], qa['QTMS_STAGING_QA_PASSWORD'])
    owner_uid, owner_token = sign_in(api_key, o_email, o_pass)
    print('★ معرّف حساب الاختبار:', qa_uid)
    print('★ معرّف المالك المُنفِّذ:', owner_uid)

    # ① الإقلاع — ★ لا يضرّ تكرارُه (يردّ alreadyBootstrapped)
    code, body = post(SERVICE + '/bootstrapOwnerPermissions',
                      {'data': {'requestId': args.request_id + '-boot'}}, owner_token)
    print('① bootstrapOwnerPermissions ⟵', code, json.dumps(body, ensure_ascii=False)[:160])

    # ⛔★★ **ولا تجديد للرمز هنا** — ★ **`verifyIdToken` تقرأ الصلاحيات من
    #   بطاقة `users/{uid}` لا من مطالبات الرمز** (`ADR-0016`)، ⟵ **فالصلاحية
    #   تسري في العملية التالية مباشرةً** (`RB-bootstrap-owner-permissions` §6:
    #   «`tokenRefreshRequired: false`»). ★ **وقراءةُ الاعتماد مرةً واحدة أقلّ
    #   ملامسةً للسرّ.**

    # ② المنح الكامل + النطاق
    code, body = post(SERVICE + '/grantPermissions',
                      {'data': {'requestId': args.request_id,
                                'userId': qa_uid,
                                'permissions': keys,
                                'sourceScope': 'all'}}, owner_token)
    print('② grantPermissions ⟵', code, json.dumps(body, ensure_ascii=False)[:220])
    if code != 200:
        sys.exit('⛔ توقّف — المنح لم ينجح')
    print('✅ تمّ — شغّل بعدها فحص التحقق')


if __name__ == '__main__':
    main()

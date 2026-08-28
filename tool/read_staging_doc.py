# -*- coding: utf-8 -*-
"""قراءةُ مستندٍ من التجريبية بحساب الاختبار — **للتحقّق الميداني وحده**.

★ **يقرأ الاعتماد من ملفّه المحلي مباشرةً** ⛔ **ولا يطبع بريداً ولا كلمةَ
مرور ولا رمزاً إطلاقاً** (`AM-004` · `secrets-management-policy.md` §3).

⛔⛔ **التجريبية حصراً** — ★ **ويرفض العملَ إن لم يكن المشروع
`qtms-orimind-master`.** ⛔ **وقراءةٌ فقط — لا كتابة فيه إطلاقاً.**

الاستخدام:
    python tool/read_staging_doc.py sacks/SCK-20260826-0001
"""
import io, json, sys, urllib.request, urllib.error, urllib.parse

STAGING_PROJECT = 'qtms-orimind-master'
QA_ENV = '.secrets/qtms-staging-qa-account.env'
GS = 'android/app/src/staging/google-services.json'


def load_env(path):
    out = {}
    for line in io.open(path, encoding='utf-8'):
        line = line.strip()
        if line and not line.startswith('#') and '=' in line:
            k, v = line.split('=', 1)
            out[k.strip()] = v.strip().strip('"').strip("'")
    return out


def sign_in(api_key, email, password):
    """يُعيد idToken — ⛔ ولا يطبع منه شيئاً."""
    req = urllib.request.Request(
        'https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=' + api_key,
        data=json.dumps({'email': email, 'password': password,
                         'returnSecureToken': True}).encode(),
        headers={'Content-Type': 'application/json'})
    try:
        return json.load(urllib.request.urlopen(req, timeout=30))['idToken']
    except urllib.error.HTTPError as e:
        sys.exit('⛔ فشل تسجيل الدخول: ' + json.load(e).get('error', {}).get('message', '?'))


def main():
    # ★ وضعان: مستندٌ واحد · أو **سردُ مجموعةٍ** بـ`--list N` (قراءةٌ فقط).
    #   ⛔ ولا كتابةَ في أيٍّ منهما إطلاقاً.
    args = sys.argv[1:]
    limit = None
    if '--list' in args:
        i = args.index('--list')
        limit = int(args[i + 1])
        del args[i:i + 2]
    if len(args) != 1:
        sys.exit('الاستخدام: python tool/read_staging_doc.py <مسار> [--list N]')
    path = args[0].strip('/')

    gs = json.load(io.open(GS, encoding='utf-8'))
    project = gs['project_info']['project_id']
    if project != STAGING_PROJECT:
        sys.exit('⛔ التجريبية حصراً — المشروع المقروء: ' + project)
    api_key = gs['client'][0]['api_key'][0]['current_key']

    qa = load_env(QA_ENV)
    token = sign_in(api_key, qa['QTMS_STAGING_QA_EMAIL'], qa['QTMS_STAGING_QA_PASSWORD'])

    url = ('https://firestore.googleapis.com/v1/projects/%s/databases/(default)/documents/%s'
           % (project, path))
    if limit is not None:
        url += '?pageSize=%d&orderBy=%s' % (limit, urllib.parse.quote('occurredAt desc'))
    req = urllib.request.Request(url, headers={'Authorization': 'Bearer ' + token})
    try:
        doc = json.load(urllib.request.urlopen(req, timeout=30))
    except urllib.error.HTTPError as e:
        sys.exit('⛔ فشلت القراءة (%s): %s' % (e.code, e.read().decode('utf-8', 'replace')[:300]))

    if limit is not None:
        for d in doc.get('documents', []):
            print(d['name'].rsplit('/', 1)[-1])
            print(json.dumps(d.get('fields', {}), ensure_ascii=False, indent=2))
            print('---')
        return
    print(json.dumps(doc.get('fields', {}), ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()

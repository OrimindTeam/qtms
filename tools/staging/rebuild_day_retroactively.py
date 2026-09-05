# -*- coding: utf-8 -*-
"""أداةُ إعادة البناء بأثر رجعي — تنفيذُ `RB-rebuild-summaries` (`WU-021`).

★ **التشغيل من جذر المستودع:**

    python tools/staging/rebuild_day_retroactively.py --from 20260830 --to 20260904
    python tools/staging/rebuild_day_retroactively.py --date 20260830 --source SRC-001

⛅ **التجريبية `qtms-orimind-master` حصراً** — ⛔⛔ **ولا نظير له على الإنتاج
بلا كلمة `اعتمد-النشر-الإنتاجي`** (بروتوكول التشغيل §ز.2).

★★★ **والمدى يدور هنا لا في الحاوية** (`retroactive_rebuild_handler.dart`
§الترويسة): ⟵ **فالعمليةُ وحدتُها يومٌ واحد** — ★ **وهو نصُّ اسمِها**
(`rebuildDayRetroactively`) — ⛔ **ولا عتبةُ مدىً تُخترَع في السحابة بلا
مستند** (`implementation-playbook.md` §5)، ⛔ **ولا استدعاءٌ واحدٌ يبتلع
مهلةَ الطلب.**

⛔⛔★★★ **ولا قيمةَ سرٍّ تُطبَع ولا تُعاد إطلاقاً:** ★ **الاعتماد يُقرأ داخل
هذه العملية وحدها** من `.secrets/qtms-staging-owner.env` **ومفتاحُ العميل من
نكهة التجريبية** — ⟵ **والمطبوعُ رموزُ حالةٍ وأعدادٌ لا غير**، ★ **ومع ذلك
يمرّ كلُّ مخرَجٍ على [safe] حزاماً ثانياً** (نفسُ `qa_permission_sync.py`).

★★ **ولماذا المالك هو الداخل:** حارسُ هذه العملية **هويةُ المالك المسجَّل
وحدها** (`retroactive_rebuild.dart` §الترويسة) — ⛔ **ولا مفتاحَ في الكتالوج
لها**: ⟵ **فحسابُ QA لا يصلح لها** ⛔ **ولو ملك كلَّ مفاتيح §2.**
"""
import argparse, datetime, io, json, os, sys, urllib.request, urllib.error, uuid

sys.stdout.reconfigure(encoding='utf-8')

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OWNER_UID = 'fj7BDnSxHkfiSwU7SjNXp7gKgXv2'   # ★ معرّف لا سرّ — environments.md §1.3
PROJECT = 'qtms-orimind-master'

SECRET_TOKENS = []          # ⛔ كلُّ ما لا يجوز أن يظهر في أي مخرَج


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
    """يُنقّي أي مخرَج من كل قيمةٍ سرّية قبل طباعته — حزامٌ ثانٍ لا وحيد."""
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
        with urllib.request.urlopen(req, timeout=180) as resp:
            return resp.status, resp.read().decode('utf-8')
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode('utf-8')


def days_between(start, end):
    """★ أيامُ المدى شاملةً طرفيه — ⛔ ولا يُقبَل مدىً مقلوب."""
    first = datetime.datetime.strptime(start, '%Y%m%d').date()
    last = datetime.datetime.strptime(end, '%Y%m%d').date()
    if last < first:
        raise SystemExit('ABORT — مدىً مقلوب: النهاية قبل البداية')
    out, cursor = [], first
    while cursor <= last:
        out.append(cursor.strftime('%Y%m%d'))
        cursor += datetime.timedelta(days=1)
    return out


parser = argparse.ArgumentParser(add_help=True)
parser.add_argument('--date', help='يومٌ واحد بصيغة YYYYMMDD')
parser.add_argument('--from', dest='start', help='بداية المدى YYYYMMDD')
parser.add_argument('--to', dest='end', help='نهاية المدى YYYYMMDD')
parser.add_argument('--source', action='append', dest='sources',
                    help='مصدرٌ بعينه — ويُكرَّر العَلَم لأكثر من مصدر · وغيابه يعني كلَّ المصادر')
args = parser.parse_args()

if args.date:
    days = [args.date]
elif args.start and args.end:
    days = days_between(args.start, args.end)
else:
    raise SystemExit('ABORT — مرّر --date أو (--from و--to) معاً')

# ── ① الاعتماد والمعرّفات — تُقرأ ولا تُطبَع ─────────────────────────────
owner = env_of(os.path.join(ROOT, '.secrets/qtms-staging-owner.env'))
email = next(v for k, v in owner.items() if 'EMAIL' in k.upper())
password = next(v for k, v in owner.items() if 'PASSWORD' in k.upper())
SECRET_TOKENS += [email, password]

# ⛔⛔★★★ **ونكهةُ التجريبية وحدها** — ★ **ملفُّ الجذر إنتاجيّ**
#    (`RB-staging-qa-account` §4.1): ⟵ **واستعمالُه هنا يوجّه الدخولَ إلى
#    الإنتاج بلا قصد** ⛔ **وهو بالضبط ما تمنعه §ز.3 («عند الشكّ: إنتاج»).**
GS = os.path.join(ROOT, 'android/app/src/staging/google-services.json')
with io.open(GS, encoding='utf-8') as fh:
    gs = json.load(fh)
if gs['project_info']['project_id'] != PROJECT:
    print('ABORT — ملفُّ الإعداد لا يخصّ التجريبية:', gs['project_info']['project_id'])
    sys.exit(1)
api_key = gs['client'][0]['api_key'][0]['current_key']
SECRET_TOKENS.append(api_key)

base = env_of(os.path.join(ROOT, 'config/qtms-public-defines.env'))['QTMS_FUNCTIONS_BASE_URL'].rstrip('/')

# ── ② تسجيل دخول المالك — ★ الرمزُ لا يُطبَع ────────────────────────────
status, raw = post(
    'https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=' + api_key,
    {'email': email, 'password': password, 'returnSecureToken': True},
)
if status != 200:
    print('signIn FAILED', status, safe(raw)[:300])
    sys.exit(1)
auth = json.loads(raw)
id_token = auth['idToken']
SECRET_TOKENS.append(id_token)
SECRET_TOKENS.append(auth.get('refreshToken', ''))
print('① signIn -> 200 · uid_matches_registered_owner =', auth['localId'] == OWNER_UID)
if auth['localId'] != OWNER_UID:
    # ⛔⛔ **ولا خطوةَ بعدها** — ★ **العمليةُ تُقاس بالهوية وحدها.**
    print('ABORT — الحساب الداخل ليس مالكَ التجريبية المسجَّل')
    sys.exit(1)

# ── ③ إعادة البناء يوماً يوماً — ★ وكلُّ يومٍ بمخرَجه الفعلي ─────────────
payload_sources = {'sourceIds': args.sources} if args.sources else {}
# ★ **ثلاثةُ عدّاداتٍ تُجمَع عبر الأيام** — ⛔ **و`sources` ليس منها**:
#   ⟵ **عددُ مصادرِ اليوم نفسُه في كل يوم**، ★ **وجمعُه يُنتج رقماً بلا معنى.**
totals = {'revaluedSacks': 0, 'summaryWrites': 0, 'agedRemaindersWritten': 0}
failed_days = []

for day in days:
    status, raw = post(
        base + '/rebuildDayRetroactively',
        {'data': dict({'requestId': 'rebuild-' + str(uuid.uuid4()), 'date': day},
                      **payload_sources)},
        token=id_token,
    )
    print('②', day, '->', status, safe(raw)[:400])
    if status != 200:
        failed_days.append(day)
        continue
    result = json.loads(raw).get('result', {})
    for key in totals:
        totals[key] += result.get(key, 0)
    # ⛔ **والمتعثّرُ داخل اليوم يُعلَن كذلك** — ★ **فنجاحٌ جزئيٌّ يُقرأ جزئياً.**
    if result.get('failedSources'):
        print('   ⛔ مصادر متعثّرة:', result['failedSources'])

# ── ④ الخلاصة — ★ أرقامٌ مقيسة لا ادّعاء (بروتوكول التشغيل §و) ──────────
print('③ الخلاصة:',
      len(days), 'يوماً ·',
      totals['revaluedSacks'], 'جونية ·',
      totals['summaryWrites'], 'كتابة ملخّص ·',
      totals['agedRemaindersWritten'], 'بند متبقٍّ ·',
      len(failed_days), 'يوماً متعثّراً')
if failed_days:
    print('   ⛔ الأيام المتعثّرة:', failed_days)
    sys.exit(1)

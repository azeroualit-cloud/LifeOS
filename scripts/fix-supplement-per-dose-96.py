"""SUPPLEMENT-UNIT-2026-11-27 («it still shows Omega-3 Fish Oil 5,5 mg [...] its one capsule»): a supplement without a
saved unit counts per dose in the app (values per 100 doses), but the site saved what was typed per capsule as if it
were per 100 g, i.e. 100 times too small. This one-off repair, through the app gateway:
  1. finds supplements whose name contains «omega», counted per dose (no gram/millilitre unit), whose stored values
     are clearly per capsule (EPA+DHA under 50 mg and energy under 1 kcal per capsule after the app's division);
  2. multiplies energy, macros and every micronutrient of those foods by 100 (site saveFood, app extras untouched);
  3. multiplies by 100 the micronutrients and macros of the diary meals of the last 30 days that use them (same id,
     newer revision, so the phone applies the edit and rewrites Apple Health).
Logs only counts (public repository).
"""
import os, json, time, datetime, urllib.request, urllib.error, http.cookiejar

ORIGIN = 'https://lifeos-native-test.a-zeroual-it.workers.dev'
client = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()))
MASS = {'gram', 'millilitre'}


def post(path, payload):
    r = urllib.request.Request(ORIGIN + path, data=json.dumps(payload).encode(), method='POST',
        headers={'Origin': ORIGIN, 'Content-Type': 'application/json', 'User-Agent': 'LifeOS-Supplement-Fix/1.0'})
    with client.open(r, timeout=120) as resp: return json.loads(resp.read())


def api(method, args, tries=4):
    for attempt in range(tries):
        try: return post('/api/' + method, args)
        except urllib.error.HTTPError as e:
            if e.code < 500 or attempt == tries - 1: raise
            time.sleep(3 + attempt * 4)


def x100(v):
    return None if v is None else round(float(v) * 100, 4)


def main():
    post('/auth/login', {'user': 'nas', 'password': os.environ['LIFEOS_TEST_PASSWORD']})
    foods = api('listFoods', []).get('foods', [])
    targets = []
    for f in foods:
        app = f.get('app') if isinstance(f.get('app'), dict) else {}
        unit = app.get('supplementUnit') or 'legacyServing'
        if f.get('family') != 'supplement' or unit in MASS or 'omega' not in str(f.get('name', '')).lower(): continue
        micro = f.get('micro') or {}
        omega = float(micro.get('epa') or 0) + float(micro.get('dha') or 0)
        per_capsule_omega, per_capsule_kcal = omega / 100, float(f.get('kcal') or 0) / 100
        if 0 < per_capsule_omega < 50 and per_capsule_kcal < 1: targets.append(f)
    print('SUPPLEMENT_FIX_CANDIDATES omega_supplements_per_dose_too_small=%d' % len(targets))
    fixed_ids = set()
    for f in targets:
        payload = {'id': f['id'], 'name': f['name'], 'brand': f.get('brand') or '', 'family': 'supplement', 'basis': f.get('basis') or 'g',
                   'notDeclared': bool(f.get('notDeclared')), 'kcal': x100(f.get('kcal')), 'protein': x100(f.get('protein')),
                   'carbs': x100(f.get('carbs')), 'fat': x100(f.get('fat')), 'fibre': x100(f.get('fibre')),
                   'micro': {k: x100(v) for k, v in (f.get('micro') or {}).items() if isinstance(v, (int, float))},
                   'aliases': f.get('aliases') or [], 'note': f.get('note') or ''}
        api('saveFood', [payload]); fixed_ids.add(f['id'])
    names = {str(f['name']).strip().lower() for f in targets}
    since = (datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(days=30)).date().isoformat()
    meals = [e for e in api('listFoodDiary', [0]).get('entries', []) if not e.get('deleted') and str(e.get('day', '')) >= since]
    updated = 0
    for e in meals:
        app = e.get('app') if isinstance(e.get('app'), dict) else {}
        if app.get('foodID') not in fixed_ids and str(e.get('name', '')).strip().lower() not in names: continue
        values = app.get('nutrientValues') if isinstance(app.get('nutrientValues'), dict) else {}
        app = dict(app)
        app['nutrientValues'] = {k: {**v, 'amount': x100(v.get('amount'))} for k, v in values.items() if isinstance(v, dict) and isinstance(v.get('amount'), (int, float))}
        for key in ('protein', 'carbohydrate', 'fat', 'fibre', 'labelCalories'):
            if isinstance(app.get(key), (int, float)): app[key] = x100(app[key])
        now = int(time.time() * 1000)
        row = {'id': e['id'], 'at': e['at'], 'name': e.get('name', ''), 'grams': e.get('grams'), 'ml': e.get('ml'),
               'kcal': x100(e.get('kcal')), 'protein': x100(e.get('protein')), 'carbs': x100(e.get('carbs')), 'fat': x100(e.get('fat')),
               'fibre': x100(e.get('fibre')), 'revision': int(e.get('revision') or 0) + 1, 'modified': now, 'app': app}
        if app: row['app']['revision'] = row['revision']
        if api('saveFoodDiaryEntry', [row]).get('saved'): updated += 1
        time.sleep(0.2)
    print('SUPPLEMENT_FIX_DONE foods=%d meals_last_30_days=%d' % (len(fixed_ids), updated))


if __name__ == '__main__':
    main()

"""DIARY-MICRO-2026-11-27, user request: «delete and readd all the meals of the last 3 days and today to be sure
micronutrients carry over». Through the app gateway (same login as the food reset script):
  1. reads the diary and the food list; keeps the meals of today and the 3 days before (Europe/Rome), not deleted;
  2. for each meal builds a new entry (new id, same time, name, quantity and macros). The app part is kept when it
     already has micronutrients (meals logged on the iPhone); otherwise it is rebuilt from the food (linked id, then
     exact name) with the micronutrients scaled to the quantity, like the site now does;
  3. saves the new entry first, then deletes the old one (soft delete: the old row stays as a tombstone). If the
     delete fails, the new entry is deleted again, so nothing is doubled or lost.
Logs only counts: no meal or food names, quantities or values (public repository).
"""
import os, json, time, uuid, datetime, urllib.request, urllib.error, http.cookiejar
from zoneinfo import ZoneInfo

ORIGIN = 'https://lifeos-native-test.a-zeroual-it.workers.dev'
client = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()))
APPLE_EPOCH = 978307200  # 2001-01-01, the app's JSON dates


def post(path, payload):
    r = urllib.request.Request(ORIGIN + path, data=json.dumps(payload).encode(), method='POST',
        headers={'Origin': ORIGIN, 'Content-Type': 'application/json', 'User-Agent': 'LifeOS-Diary-Refresh/1.0'})
    with client.open(r, timeout=120) as resp: return json.loads(resp.read())


def api(method, args, tries=4):
    for attempt in range(tries):
        try: return post('/api/' + method, args)
        except urllib.error.HTTPError as e:
            if e.code < 500 or attempt == tries - 1: raise
            time.sleep(3 + attempt * 4)


def app_part(entry, new_id, food, at_seconds):
    app = entry.get('app') if isinstance(entry.get('app'), dict) else {}
    micro = app.get('nutrientValues') if isinstance(app.get('nutrientValues'), dict) else {}
    kept = bool(micro)
    if not kept and food is not None:
        quantity = entry.get('ml') if food.get('basis') == 'ml' else entry.get('grams')
        if quantity and quantity > 0:
            k = float(quantity) / 100
            micro = {key: {'amount': round(float(v) * k, 4), 'estimateSource': None}
                     for key, v in (food.get('micro') or {}).items() if isinstance(v, (int, float)) and v >= 0}
    out = dict(app)
    out.update({'id': new_id, 'revision': 0, 'confirmed': False, 'deletionPending': None, 'modifiedAt': None,
                'protein': entry.get('protein') or 0, 'carbohydrate': entry.get('carbs') or 0, 'fat': entry.get('fat') or 0})
    out.setdefault('date', at_seconds - APPLE_EPOCH)
    out['date'] = at_seconds - APPLE_EPOCH
    if entry.get('fibre') is not None: out['fibre'] = entry['fibre']
    if entry.get('kcal') is not None: out['labelCalories'] = entry['kcal']
    if micro: out['nutrientValues'] = micro
    if food is not None:
        out['foodID'] = food['id']; out.setdefault('foodName', food.get('name'))
    if entry.get('grams'): out['portionGrams'] = entry['grams']
    if entry.get('ml'): out['portionMillilitres'] = entry['ml']
    out = {k: v for k, v in out.items() if v is not None}
    return out, kept, bool(micro)


def main():
    post('/auth/login', {'user': 'nas', 'password': os.environ['LIFEOS_TEST_PASSWORD']})
    rome = ZoneInfo('Europe/Rome')
    today = datetime.datetime.now(rome).date()
    days = {(today - datetime.timedelta(days=n)).isoformat() for n in range(4)}
    entries = [e for e in api('listFoodDiary', [0]).get('entries', []) if not e.get('deleted') and e.get('day') in days]
    foods = api('listFoods', []).get('foods', [])
    by_id = {f['id']: f for f in foods}
    by_name = {}
    for f in foods: by_name.setdefault(str(f.get('name', '')).strip().lower(), f)
    print('DIARY_REFRESH_PLAN days=%d meals=%d foods=%d' % (len(days), len(entries), len(foods)))
    stats = dict(moved=0, kept_app_micro=0, rebuilt_micro=0, no_food=0, food_without_micro=0, failed=0, rolled_back=0)
    for entry in entries:
        app = entry.get('app') if isinstance(entry.get('app'), dict) else {}
        food = by_id.get(app.get('foodID') or '') or by_name.get(str(entry.get('name', '')).strip().lower())
        new_id = str(uuid.uuid4()).upper()
        at = datetime.datetime.fromisoformat(str(entry['at']).replace('Z', '+00:00'))
        part, kept, has_micro = app_part(entry, new_id, food, at.timestamp())
        now = int(time.time() * 1000)
        fresh = {'id': new_id, 'at': entry['at'], 'name': entry.get('name', ''), 'grams': entry.get('grams'), 'ml': entry.get('ml'),
                 'kcal': entry.get('kcal'), 'protein': entry.get('protein'), 'carbs': entry.get('carbs'), 'fat': entry.get('fat'),
                 'fibre': entry.get('fibre'), 'revision': 0, 'modified': now, 'app': part}
        try:
            saved = api('saveFoodDiaryEntry', [fresh])
            if not saved.get('saved'): raise RuntimeError('not saved')
        except Exception:
            stats['failed'] += 1; continue
        try:
            gone = api('deleteFoodDiaryEntry', [entry['id'], now + 1])
            if not gone.get('deleted'): raise RuntimeError('not deleted')
        except Exception:
            try: api('deleteFoodDiaryEntry', [new_id, now + 2]); stats['rolled_back'] += 1
            except Exception: pass
            stats['failed'] += 1; continue
        stats['moved'] += 1
        if kept: stats['kept_app_micro'] += 1
        elif has_micro: stats['rebuilt_micro'] += 1
        elif food is None: stats['no_food'] += 1
        else: stats['food_without_micro'] += 1
        time.sleep(0.2)
    after = [e for e in api('listFoodDiary', [0]).get('entries', []) if not e.get('deleted') and e.get('day') in days]
    with_micro = sum(1 for e in after if isinstance(e.get('app'), dict) and e['app'].get('nutrientValues'))
    print('DIARY_REFRESH_DONE ' + ' '.join('%s=%d' % kv for kv in stats.items()))
    print('DIARY_REFRESH_AFTER meals=%d with_micronutrients=%d' % (len(after), with_micro))
    if stats['failed']: raise SystemExit(1)


if __name__ == '__main__':
    main()
